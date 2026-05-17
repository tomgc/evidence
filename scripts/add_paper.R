#!/usr/bin/env Rscript
# scripts/add_paper.R
# Crea un nuevo paper desde DOI, arXiv ID, URL o PDF local.
# Resuelve metadata vía CrossRef/arXiv, genera slug, escribe el .md y
# regenera papers.json. Si la fuente es OA (arXiv), descarga el PDF.
#
# Uso:
#   Rscript scripts/add_paper.R "10.48550/arXiv.1706.03762"
#   Rscript scripts/add_paper.R "1706.03762"
#   Rscript scripts/add_paper.R "https://arxiv.org/abs/1706.03762"
#   Rscript scripts/add_paper.R "/ruta/al/paper.pdf"

# --- Verificación e instalación de paquetes -----------------------------------
paquetes_requeridos <- c("here", "httr2", "xml2", "pdftools", "stringi",
                        "yaml", "jsonlite", "purrr")
paquetes_faltantes <- paquetes_requeridos[
  !sapply(paquetes_requeridos, requireNamespace, quietly = TRUE)
]
if (length(paquetes_faltantes) > 0) install.packages(paquetes_faltantes)

# --- Carga --------------------------------------------------------------------
library(here)
library(httr2)
library(xml2)
library(stringi)

`%||%` <- function(x, y) if (is.null(x) || (length(x) == 1 && is.na(x))) y else x

# --- Constantes ---------------------------------------------------------------
UA <- "evidence/0.1 (https://github.com/tomgc/evidence; mailto:tgonzalez@gmail.com)"
STOPWORDS <- c(
  "a", "an", "the", "of", "in", "on", "to", "is", "are", "and", "or",
  "for", "with", "by", "from", "as", "at", "be", "this", "that",
  "el", "la", "los", "las", "un", "una", "de", "del", "en", "y", "o",
  "con", "para", "por", "al"
)

# --- Limpieza -----------------------------------------------------------------
clean_html <- function(s) {
  if (is.null(s) || is.na(s)) return("")
  s <- gsub("<[^>]+>", "", s)            # tags HTML/JATS
  s <- gsub("&amp;", "&", s, fixed = TRUE)
  s <- gsub("&lt;", "<", s, fixed = TRUE)
  s <- gsub("&gt;", ">", s, fixed = TRUE)
  s <- gsub("&quot;", '"', s, fixed = TRUE)
  s <- gsub("\\s+", " ", s)
  trimws(s)
}

# --- Fetch: CrossRef ----------------------------------------------------------
fetch_crossref <- function(doi) {
  resp <- request("https://api.crossref.org/works/") |>
    req_url_path_append(utils::URLencode(doi, reserved = TRUE)) |>
    req_user_agent(UA) |>
    req_retry(max_tries = 3) |>
    req_timeout(20) |>
    req_perform()
  d <- resp_body_json(resp)$message

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

# --- Fetch: arXiv -------------------------------------------------------------
fetch_arxiv <- function(arxiv_id) {
  arxiv_id <- sub("v\\d+$", "", arxiv_id)  # quitar versión
  url <- paste0("http://export.arxiv.org/api/query?id_list=", arxiv_id)
  resp <- request(url) |>
    req_user_agent(UA) |>
    req_timeout(20) |>
    req_perform()
  doc <- read_xml(resp_body_string(resp))
  ns <- c(atom = "http://www.w3.org/2005/Atom",
          arxiv = "http://arxiv.org/schemas/atom")
  entry <- xml_find_first(doc, ".//atom:entry", ns)
  if (inherits(entry, "xml_missing")) {
    stop(sprintf("arXiv no devolvió entry para id: %s", arxiv_id))
  }

  title <- clean_html(xml_text(xml_find_first(entry, ".//atom:title", ns)))
  abstract <- clean_html(xml_text(xml_find_first(entry, ".//atom:summary", ns)))
  published <- xml_text(xml_find_first(entry, ".//atom:published", ns))
  author_nodes <- xml_find_all(entry, ".//atom:author/atom:name", ns)
  authors <- vapply(author_nodes, function(n) {
    full <- trimws(xml_text(n))
    parts <- strsplit(full, "\\s+")[[1]]
    if (length(parts) < 2) return(full)
    apellido <- parts[length(parts)]
    nombre <- paste(parts[-length(parts)], collapse = " ")
    paste0(apellido, ", ", nombre)
  }, character(1))

  doi_node <- xml_find_first(entry, ".//arxiv:doi", ns)
  doi <- if (inherits(doi_node, "xml_missing")) {
    paste0("10.48550/arXiv.", arxiv_id)
  } else xml_text(doi_node)

  journal_node <- xml_find_first(entry, ".//arxiv:journal_ref", ns)
  journal <- if (inherits(journal_node, "xml_missing")) "arXiv preprint"
             else clean_html(xml_text(journal_node))

  list(
    title    = title,
    authors  = authors,
    year     = as.integer(substr(published, 1, 4)),
    journal  = journal,
    doi      = doi,
    url      = paste0("https://arxiv.org/abs/", arxiv_id),
    abstract = abstract,
    source   = "paper",
    pdf_url  = paste0("https://arxiv.org/pdf/", arxiv_id, ".pdf")
  )
}

# --- Fetch: desde PDF ---------------------------------------------------------
fetch_from_pdf <- function(pdf_path) {
  if (!file.exists(pdf_path)) stop("Archivo no existe: ", pdf_path)
  text <- paste(pdftools::pdf_text(pdf_path), collapse = "\n")
  m <- regmatches(text, regexpr("10\\.\\d{4,9}/[-._;()/:A-Za-z0-9]+", text))
  if (length(m) == 0 || nchar(m[1]) == 0) {
    stop("No se encontró DOI en el PDF. Pásale el DOI o arXiv ID directamente.")
  }
  doi <- gsub("[.,;]+$", "", m[1])
  message("  DOI detectado en PDF: ", doi)
  meta <- fetch_crossref(doi)
  meta$pdf_path <- pdf_path
  meta
}

# --- Dispatcher ---------------------------------------------------------------
dispatch <- function(input) {
  # PDF local
  if (file.exists(input) && tolower(tools::file_ext(input)) == "pdf") {
    message("→ Input detectado: PDF local")
    return(fetch_from_pdf(input))
  }
  # arXiv ID puro (ej: 1706.03762, 2401.12345v2)
  if (grepl("^\\d{4}\\.\\d{4,5}(v\\d+)?$", input)) {
    message("→ Input detectado: arXiv ID")
    return(fetch_arxiv(input))
  }
  # arXiv URL
  m <- regmatches(input, regexpr("arxiv\\.org/(abs|pdf)/(\\d{4}\\.\\d{4,5}(v\\d+)?)",
                                 input, perl = TRUE))
  if (length(m) > 0) {
    id <- sub("^.*/", "", m[1])
    message("→ Input detectado: arXiv URL → id ", id)
    return(fetch_arxiv(id))
  }
  # DOI URL
  m <- regmatches(input, regexpr("(?<=doi\\.org/)10\\.\\d{4,9}/\\S+",
                                 input, perl = TRUE))
  if (length(m) > 0) {
    message("→ Input detectado: DOI URL")
    return(fetch_crossref(m[1]))
  }
  # DOI bare
  if (grepl("^10\\.\\d{4,9}/", input)) {
    message("→ Input detectado: DOI")
    return(fetch_crossref(input))
  }
  stop("Input no reconocido. Usa DOI, arXiv ID, URL de DOI/arXiv, o path a PDF.")
}

# --- Slug ---------------------------------------------------------------------
generar_slug <- function(authors, year, title) {
  primer <- authors[1] %||% "unknown"
  apellido <- if (grepl(",", primer, fixed = TRUE)) {
    trimws(strsplit(primer, ",", fixed = TRUE)[[1]][1])
  } else {
    parts <- strsplit(trimws(primer), "\\s+")[[1]]
    parts[length(parts)]
  }
  apellido <- stri_trans_general(apellido, "Latin-ASCII")
  apellido <- tolower(gsub("[^a-z]", "", tolower(apellido)))

  titulo <- stri_trans_general(title %||% "", "Latin-ASCII")
  titulo <- tolower(titulo)
  palabras <- strsplit(titulo, "[^a-z0-9]+")[[1]]
  palabras <- palabras[nchar(palabras) > 0 & !palabras %in% STOPWORDS]
  primeras <- head(palabras, 3)

  paste(c(apellido, year, primeras), collapse = "_")
}

# --- Escritura del .md --------------------------------------------------------
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
  abstract_block <- if (nchar(abstract) > 0) {
    # Split por anchura razonable (no estrictamente necesario, YAML soporta líneas largas).
    paste0("  ", abstract)
  } else "  "

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

# --- Main ---------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Uso: Rscript scripts/add_paper.R <DOI | arxiv_id | URL | pdf_path>")
}
input <- args[1]

message("→ Resolviendo metadata para: ", input)
meta <- dispatch(input)
message(sprintf("  Título: %s", meta$title))
message(sprintf("  Autores: %s%s",
        paste(head(meta$authors, 3), collapse = "; "),
        if (length(meta$authors) > 3) " ..." else ""))
message(sprintf("  Año: %s | DOI: %s", meta$year, meta$doi %||% "(sin DOI)"))

slug <- generar_slug(meta$authors, meta$year, meta$title)
message("→ Slug: ", slug)

md_path <- here("data", "raw", "papers", paste0(slug, ".md"))
if (file.exists(md_path)) {
  stop(sprintf("Ya existe: %s. Borra el archivo si quieres regenerarlo.", md_path))
}

write_paper_md(meta, md_path)
message("→ Escrito: ", md_path)

# Descarga / copia de PDF
pdf_dest <- here("data", "raw", "pdfs", paste0(slug, ".pdf"))
if (!is.null(meta$pdf_url) && !file.exists(pdf_dest)) {
  message("→ Descargando PDF: ", meta$pdf_url)
  tryCatch({
    utils::download.file(meta$pdf_url, pdf_dest, mode = "wb", quiet = TRUE)
    message("  Guardado: ", pdf_dest)
  }, error = function(e) {
    message("  ⚠ No se pudo descargar el PDF: ", e$message)
  })
} else if (!is.null(meta$pdf_path) && !file.exists(pdf_dest)) {
  file.copy(meta$pdf_path, pdf_dest, overwrite = FALSE)
  message("→ PDF copiado: ", pdf_dest)
}

# Re-build
message("→ Re-construyendo papers.json...")
source(here("scripts", "01_build_data.R"))

message("\n✓ Listo. Edita el archivo para tus notas y key_findings:")
message("  ", md_path)
