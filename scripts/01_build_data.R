# scripts/01_build_data.R
# Lee data/raw/papers/*.md, valida, genera data/processed/papers.json.
#
# Proyecto: evidence
# Autor: Tom Gonzalez
# Fecha: 2026-05-17

# --- Verificación e instalación de paquetes -----------------------------------
paquetes_requeridos <- c("here", "yaml", "jsonlite", "purrr")
paquetes_faltantes <- paquetes_requeridos[
  !sapply(paquetes_requeridos, requireNamespace, quietly = TRUE)
]
if (length(paquetes_faltantes) > 0) {
  install.packages(paquetes_faltantes)
}

# --- Carga de paquetes --------------------------------------------------------
library(here)
library(yaml)
library(jsonlite)
library(purrr)

# --- Rutas --------------------------------------------------------------------
ruta_papers_md   <- here("data", "raw", "papers")
ruta_pdfs        <- here("data", "raw", "pdfs")
ruta_processed   <- here("data", "processed")
ruta_papers_json <- file.path(ruta_processed, "papers.json")
ruta_papers_tmp  <- file.path(ruta_processed, "papers.json.tmp")
# Copia para servir el sitio (single source en data/processed; site/data/ es derivado).
ruta_site_data        <- here("site", "data")
ruta_site_papers_json <- file.path(ruta_site_data, "papers.json")
ruta_site_pdfs        <- file.path(ruta_site_data, "pdfs")

# --- Constantes ---------------------------------------------------------------
# Centralizadas en R/constants.R (PREFIJO_TEMPLATE, vocabularios, rangos).
source(here("R", "constants.R"))

# --- Funciones ----------------------------------------------------------------
source(here("R", "parse_papers.R"))

# Serializa la lista de papers a JSON con claves ordenadas alfabéticamente (C.10).
papers_to_json <- function(papers) {
  papers_kord <- lapply(papers, function(p) p[sort(names(p))])
  papers_kord <- papers_kord[order(vapply(papers_kord, `[[`, character(1), "slug"))]
  jsonlite::toJSON(
    papers_kord,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null",
    na = "null"
  )
}

# Escritura atómica: write → rename (C.4).
escribir_atomico <- function(contenido, ruta_final, ruta_tmp) {
  con <- file(ruta_tmp, open = "wb")
  writeLines(enc2utf8(contenido), con, useBytes = TRUE)
  close(con)
  if (!file.rename(ruta_tmp, ruta_final)) {
    stop(sprintf("file.rename falló: %s → %s", ruta_tmp, ruta_final))
  }
}

# --- Flujo principal ----------------------------------------------------------
message("Leyendo papers desde: ", ruta_papers_md)
archivos_md <- list.files(ruta_papers_md, pattern = "\\.md$", full.names = TRUE)
archivos_md <- archivos_md[!startsWith(basename(archivos_md), PREFIJO_TEMPLATE)]
message(sprintf("Encontrados %d archivos .md (excluyendo plantillas).", length(archivos_md)))

if (length(archivos_md) == 0) {
  warning("No hay papers para procesar. Se generará un papers.json vacío.")
}

papers <- purrr::map(archivos_md, ~ read_paper_md(.x, pdfs_dir = ruta_pdfs))

# Validación (C.8): acumula errores y reporta antes de fallar.
errores_por_paper <- purrr::map(papers, validate_paper)
n_errores <- sum(lengths(errores_por_paper))

if (n_errores > 0) {
  for (i in seq_along(papers)) {
    if (length(errores_por_paper[[i]]) > 0) {
      message(sprintf("[%s]", papers[[i]]$slug))
      for (err in errores_por_paper[[i]]) message("  - ", err)
    }
  }
  stop(sprintf(
    "Validación falló: %d error(es) en %d paper(s).",
    n_errores, sum(lengths(errores_por_paper) > 0)
  ))
}

if (!dir.exists(ruta_processed)) dir.create(ruta_processed, recursive = TRUE)

json_text <- papers_to_json(papers)
escribir_atomico(json_text, ruta_papers_json, ruta_papers_tmp)

# Copia derivada para el sitio (no commiteada; ver .gitignore).
if (!dir.exists(ruta_site_data)) dir.create(ruta_site_data, recursive = TRUE)
file.copy(ruta_papers_json, ruta_site_papers_json, overwrite = TRUE)

# Espeja PDFs locales al sitio (idempotente).
if (!dir.exists(ruta_site_pdfs)) dir.create(ruta_site_pdfs, recursive = TRUE)
pdfs_raw <- list.files(ruta_pdfs, pattern = "\\.pdf$", full.names = TRUE)
for (p in pdfs_raw) {
  file.copy(p, file.path(ruta_site_pdfs, basename(p)), overwrite = TRUE)
}

# Si existe site-variants/, replica papers.json + pdfs/ a cada variante.
# Diseños alternativos en exploración; no afectan el sitio principal.
ruta_variants <- here("site-variants")
if (dir.exists(ruta_variants)) {
  for (v in list.dirs(ruta_variants, recursive = FALSE)) {
    v_data <- file.path(v, "data")
    v_pdfs <- file.path(v_data, "pdfs")
    if (!dir.exists(v_data)) dir.create(v_data, recursive = TRUE)
    if (!dir.exists(v_pdfs)) dir.create(v_pdfs, recursive = TRUE)
    file.copy(ruta_papers_json, file.path(v_data, "papers.json"), overwrite = TRUE)
    for (p in pdfs_raw) {
      file.copy(p, file.path(v_pdfs, basename(p)), overwrite = TRUE)
    }
  }
}

# --- Resumen ------------------------------------------------------------------
con_pdf <- sum(vapply(papers, `[[`, logical(1), "has_pdf"))
message(sprintf("\n[OK] %d papers escritos en %s", length(papers), ruta_papers_json))
message(sprintf("     copia para el sitio: %s", ruta_site_papers_json))
message(sprintf("     %d con PDF local, %d solo enlace.", con_pdf, length(papers) - con_pdf))
