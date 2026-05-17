# R/fetchers.R
# Funciones de resolución de metadata desde CrossRef, arXiv o PDF local,
# más generación de slug y escritura de .md. Reutilizadas por:
#   - scripts/add_paper.R       (un paper por input explícito)
#   - scripts/03_process_inbox.R (procesa todos los PDFs en data/raw/pdfs/inbox/)
#
# Convención: ninguna función toca disco fuera de los paths que recibe; ningún
# print/message debe afectar el control de flujo del caller.

source(here::here("R", "constants.R"))

`%||%` <- function(x, y) if (is.null(x) || (length(x) == 1 && is.na(x))) y else x

# User-Agent declarado para CrossRef etiquette (recomiendan email contacto).
UA <- "evidence/0.1 (https://github.com/tomgc/evidence; mailto:tgonzalez@gmail.com)"

# --- Limpieza ----------------------------------------------------------------
clean_html <- function(s) {
  if (is.null(s) || is.na(s)) return("")
  s <- gsub("<[^>]+>", "", s)
  s <- gsub("&amp;", "&", s, fixed = TRUE)
  s <- gsub("&lt;", "<", s, fixed = TRUE)
  s <- gsub("&gt;", ">", s, fixed = TRUE)
  s <- gsub("&quot;", '"', s, fixed = TRUE)
  s <- gsub("\\s+", " ", s)
  trimws(s)
}

# --- CrossRef ----------------------------------------------------------------
fetch_crossref <- function(doi) {
  resp <- httr2::request("https://api.crossref.org/works/") |>
    httr2::req_url_path_append(utils::URLencode(doi, reserved = TRUE)) |>
    httr2::req_user_agent(UA) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_timeout(20) |>
    httr2::req_perform()
  d <- httr2::resp_body_json(resp)$message

  authors_raw <- d$author %||% list()
  authors <- vapply(authors_raw, function(a) {
    if (!is.null(a$family)) paste0(a$family, ", ", a$given %||% "")
    else a$name %||% ""
  }, character(1))

  year <- tryCatch(
    as.integer(d$issued$`date-parts`[[1]][[1]][[1]]),
    error = function(e) NA_integer_
  )

  list(
    title    = clean_html(unlist(d$title)[1]),
    authors  = authors,
    year     = year,
    journal  = clean_html(unlist(d$`container-title`)[1] %||% ""),
    doi      = d$DOI,
    url      = d$URL %||% paste0("https://doi.org/", d$DOI),
    abstract = clean_html(d$abstract %||% ""),
    source   = "paper"
  )
}

# --- arXiv -------------------------------------------------------------------
fetch_arxiv <- function(arxiv_id) {
  arxiv_id <- sub("v\\d+$", "", arxiv_id)
  url <- paste0("https://export.arxiv.org/api/query?id_list=", arxiv_id)
  resp <- httr2::request(url) |>
    httr2::req_user_agent(UA) |>
    httr2::req_timeout(30) |>
    httr2::req_perform()
  doc <- xml2::read_xml(httr2::resp_body_string(resp))
  ns <- c(atom = "http://www.w3.org/2005/Atom",
          arxiv = "http://arxiv.org/schemas/atom")
  entry <- xml2::xml_find_first(doc, ".//atom:entry", ns)
  if (inherits(entry, "xml_missing")) {
    stop(sprintf("arXiv no devolvió entry para id: %s", arxiv_id))
  }

  title <- clean_html(xml2::xml_text(xml2::xml_find_first(entry, ".//atom:title", ns)))
  abstract <- clean_html(xml2::xml_text(xml2::xml_find_first(entry, ".//atom:summary", ns)))
  published <- xml2::xml_text(xml2::xml_find_first(entry, ".//atom:published", ns))

  author_nodes <- xml2::xml_find_all(entry, ".//atom:author/atom:name", ns)
  authors <- vapply(author_nodes, function(n) {
    full <- trimws(xml2::xml_text(n))
    parts <- strsplit(full, "\\s+")[[1]]
    if (length(parts) < 2) return(full)
    apellido <- parts[length(parts)]
    nombre <- paste(parts[-length(parts)], collapse = " ")
    paste0(apellido, ", ", nombre)
  }, character(1))

  doi_node <- xml2::xml_find_first(entry, ".//arxiv:doi", ns)
  doi <- if (inherits(doi_node, "xml_missing")) {
    paste0("10.48550/arXiv.", arxiv_id)
  } else xml2::xml_text(doi_node)

  journal_node <- xml2::xml_find_first(entry, ".//arxiv:journal_ref", ns)
  journal <- if (inherits(journal_node, "xml_missing")) "arXiv preprint"
             else clean_html(xml2::xml_text(journal_node))

  list(
    title    = title,
    authors  = authors,
    year     = as.integer(substr(published, 1, 4)),
    journal  = journal,
    doi      = doi,
    url      = paste0("https://arxiv.org/abs/", arxiv_id),
    abstract = abstract,
    source   = "paper",
    pdf_url  = paste0("https://arxiv.org/pdf/", arxiv_id)
  )
}

# --- Desde PDF ---------------------------------------------------------------
extract_doi_from_pdf <- function(pdf_path) {
  text <- paste(pdftools::pdf_text(pdf_path), collapse = "\n")
  m <- regmatches(text, regexpr("10\\.\\d{4,9}/[-._;()/:A-Za-z0-9]+", text))
  if (length(m) == 0 || nchar(m[1]) == 0) return(NA_character_)
  gsub("[.,;]+$", "", m[1])
}

fetch_from_pdf <- function(pdf_path) {
  if (!file.exists(pdf_path)) stop("Archivo no existe: ", pdf_path)
  doi <- extract_doi_from_pdf(pdf_path)
  if (is.na(doi)) {
    stop("No se encontró DOI en el PDF: ", basename(pdf_path))
  }
  meta <- fetch_crossref(doi)
  meta$pdf_path <- pdf_path
  meta
}

# --- Dispatcher --------------------------------------------------------------
dispatch_input <- function(input) {
  if (file.exists(input) && tolower(tools::file_ext(input)) == "pdf") {
    return(fetch_from_pdf(input))
  }
  if (grepl("^\\d{4}\\.\\d{4,5}(v\\d+)?$", input)) {
    return(fetch_arxiv(input))
  }
  m <- regmatches(input, regexpr("arxiv\\.org/(abs|pdf)/(\\d{4}\\.\\d{4,5}(v\\d+)?)",
                                 input, perl = TRUE))
  if (length(m) > 0) {
    id <- sub("^.*/", "", m[1])
    return(fetch_arxiv(id))
  }
  m <- regmatches(input, regexpr("(?<=doi\\.org/)10\\.\\d{4,9}/\\S+",
                                 input, perl = TRUE))
  if (length(m) > 0) return(fetch_crossref(m[1]))
  if (grepl("^10\\.\\d{4,9}/", input)) return(fetch_crossref(input))
  stop("Input no reconocido. Usa DOI, arXiv ID, URL o path a PDF.")
}

# --- Slug --------------------------------------------------------------------
generar_slug <- function(authors, year, title) {
  primer <- authors[1] %||% "unknown"
  apellido <- if (grepl(",", primer, fixed = TRUE)) {
    trimws(strsplit(primer, ",", fixed = TRUE)[[1]][1])
  } else {
    parts <- strsplit(trimws(primer), "\\s+")[[1]]
    parts[length(parts)]
  }
  apellido <- stringi::stri_trans_general(apellido, "Latin-ASCII")
  apellido <- tolower(gsub("[^a-z]", "", tolower(apellido)))

  titulo <- stringi::stri_trans_general(title %||% "", "Latin-ASCII")
  titulo <- tolower(titulo)
  palabras <- strsplit(titulo, "[^a-z0-9]+")[[1]]
  palabras <- palabras[nchar(palabras) > 0 & !palabras %in% STOPWORDS_SLUG]
  primeras <- head(palabras, 3)

  paste(c(apellido, year, primeras), collapse = "_")
}

# --- Escritura del .md -------------------------------------------------------
escape_yaml <- function(s) {
  if (is.null(s) || is.na(s)) return("")
  s <- gsub("\\", "\\\\", s, fixed = TRUE)
  s <- gsub('"', '\\"', s, fixed = TRUE)
  s
}

write_paper_md <- function(meta, path) {
  authors_yaml <- paste(
    sprintf('  - "%s"', vapply(meta$authors, escape_yaml, character(1))),
    collapse = "\n"
  )

  abstract <- meta$abstract %||% ""
  abstract_block <- if (nchar(abstract) > 0) paste0("  ", abstract) else "  "

  lineas <- c(
    "---",
    sprintf('title: "%s"', escape_yaml(meta$title %||% "")),
    "authors:",
    authors_yaml,
    sprintf("year: %s", meta$year %||% ""),
    sprintf('source: "%s"', meta$source %||% "paper"),
    sprintf('journal: "%s"', escape_yaml(meta$journal %||% "")),
    sprintf('url: "%s"', meta$url %||% ""),
    sprintf('doi: "%s"', meta$doi %||% ""),
    "tags: []",
    sprintf("added_on: %s", format(Sys.Date())),
    "relevance:",
    "status: toread",
    "abstract: |",
    abstract_block,
    "key_findings:",
    '  - ""',
    "my_takeaway: |",
    "  ",
    "---",
    "",
    "## Notas",
    ""
  )

  con <- file(path, open = "wb")
  writeLines(enc2utf8(lineas), con, useBytes = TRUE)
  close(con)
}

# --- Helper: descargar/copiar PDF al destino canónico ------------------------
guardar_pdf <- function(meta, pdf_dest) {
  if (file.exists(pdf_dest)) return(invisible(FALSE))
  if (!is.null(meta$pdf_url)) {
    tryCatch({
      utils::download.file(meta$pdf_url, pdf_dest, mode = "wb", quiet = TRUE)
      return(invisible(TRUE))
    }, error = function(e) {
      message("  ⚠ No se pudo descargar el PDF: ", e$message)
      return(invisible(FALSE))
    })
  } else if (!is.null(meta$pdf_path) && file.exists(meta$pdf_path)) {
    file.copy(meta$pdf_path, pdf_dest, overwrite = FALSE)
    return(invisible(TRUE))
  }
  invisible(FALSE)
}
