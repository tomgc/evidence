# R/parse_papers.R
# Funciones para leer y validar papers desde data/raw/papers/*.md.
# Cada paper es un .md con frontmatter YAML + cuerpo de notas en markdown.

source(here::here("R", "constants.R"))

# Coalesce nulo: devuelve y si x es NULL.
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Extrae el frontmatter YAML y el cuerpo de un .md
#'
#' @param path ruta absoluta al archivo .md
#' @return lista con $meta (lista del YAML parseado) y $body (texto markdown)
extract_frontmatter <- function(path) {
  lineas <- readLines(path, encoding = "UTF-8", warn = FALSE)
  if (length(lineas) < 3 || lineas[1] != "---") {
    stop(sprintf("Frontmatter ausente o no empieza con '---' en %s", basename(path)))
  }
  cierres <- which(lineas == "---")
  if (length(cierres) < 2) {
    stop(sprintf("Frontmatter sin cierre '---' en %s", basename(path)))
  }
  fin <- cierres[2]
  yaml_text <- paste(lineas[2:(fin - 1)], collapse = "\n")
  body_text <- if (fin < length(lineas)) {
    paste(lineas[(fin + 1):length(lineas)], collapse = "\n")
  } else {
    ""
  }
  list(
    meta = yaml::yaml.load(yaml_text),
    body = trimws(body_text)
  )
}

#' Lee un paper desde su .md y construye su representación normalizada.
#'
#' @param path ruta absoluta al .md
#' @param pdfs_dir ruta absoluta a la carpeta de PDFs locales
#' @return lista nombrada con los campos del paper más slug, notes, has_pdf
read_paper_md <- function(path, pdfs_dir) {
  slug <- tools::file_path_sans_ext(basename(path))
  parsed <- extract_frontmatter(path)
  m <- parsed$meta %||% list()

  list(
    slug         = slug,
    title        = m$title %||% NA_character_,
    authors      = as.character(m$authors %||% character()),
    year         = if (is.null(m$year)) NA_integer_ else as.integer(m$year),
    source       = m$source %||% NA_character_,
    journal      = m$journal %||% NA_character_,
    url          = m$url %||% NA_character_,
    doi          = as.character(m$doi %||% NA_character_),
    tags         = as.character(m$tags %||% character()),
    added_on     = as.character(m$added_on %||% NA_character_),
    relevance    = if (is.null(m$relevance)) NA_integer_ else as.integer(m$relevance),
    status       = m$status %||% NA_character_,
    abstract     = m$abstract %||% NA_character_,
    key_findings = as.character(m$key_findings %||% character()),
    my_takeaway  = m$my_takeaway %||% NA_character_,
    notes        = parsed$body,
    has_pdf      = file.exists(file.path(pdfs_dir, paste0(slug, ".pdf")))
  )
}

# Helper: ¿el valor está "vacío" (NULL, NA, string vacío)?
.es_vacio <- function(x) {
  is.null(x) || (length(x) == 1 && (is.na(x) || (is.character(x) && x == "")))
}

#' Valida un paper. Acumula errores en lugar de detenerse.
#'
#' @param paper lista normalizada de read_paper_md
#' @return character vector con descripciones de error (vacío si pasa)
validate_paper <- function(paper) {
  errores <- character()

  # relevance es opcional: muchos papers entran como "toread" sin rating todavía.
  for (campo in c("title", "year", "source", "url", "added_on", "status")) {
    if (.es_vacio(paper[[campo]])) {
      errores <- c(errores, sprintf("campo requerido vacío: %s", campo))
    }
  }
  if (length(paper$authors) == 0) {
    errores <- c(errores, "authors vacío (debe ser lista YAML con al menos 1)")
  }
  if (!is.na(paper$year) && (paper$year < YEAR_MIN || paper$year > YEAR_MAX)) {
    errores <- c(errores, sprintf("year fuera de rango [%d, %d]: %s",
                                  YEAR_MIN, YEAR_MAX, paper$year))
  }
  if (!is.na(paper$relevance) &&
      !(paper$relevance %in% RELEVANCE_MIN:RELEVANCE_MAX)) {
    errores <- c(errores, sprintf("relevance debe ser entero %d-%d: %s",
                                  RELEVANCE_MIN, RELEVANCE_MAX, paper$relevance))
  }
  if (!is.na(paper$status) && !(paper$status %in% STATUS_VALIDOS)) {
    errores <- c(errores, sprintf(
      "status inválido: '%s' (válidos: %s)",
      paper$status, paste(STATUS_VALIDOS, collapse = ", ")
    ))
  }
  if (!grepl(SLUG_PATTERN, paper$slug)) {
    errores <- c(errores, sprintf(
      "slug inválido (patrón %s): %s", SLUG_PATTERN, paper$slug
    ))
  }
  errores
}
