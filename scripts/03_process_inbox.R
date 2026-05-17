#!/usr/bin/env Rscript
# scripts/03_process_inbox.R
# Procesa PDFs sueltos en inbox/ (raíz del repo):
#   1. Extrae el DOI del texto del PDF.
#   2. Consulta CrossRef para los metadatos.
#   3. Escribe data/raw/papers/<slug>.md con frontmatter prefillado.
#   4. Mueve el PDF a data/raw/pdfs/<slug>.pdf (out of inbox).
#   5. Re-construye papers.json al final.
#
# Errores por PDF individual no detienen el batch (C.9):
#   - PDFs procesados OK → data/raw/pdfs/<slug>.pdf
#   - PDFs fallidos → inbox/_failed/<original>.pdf + <original>.error.txt
#
# Uso:
#   Rscript scripts/03_process_inbox.R

# --- Verificación e instalación de paquetes ----------------------------------
paquetes_requeridos <- c("here", "httr2", "xml2", "pdftools", "stringi",
                         "yaml", "jsonlite", "purrr")
paquetes_faltantes <- paquetes_requeridos[
  !sapply(paquetes_requeridos, requireNamespace, quietly = TRUE)
]
if (length(paquetes_faltantes) > 0) install.packages(paquetes_faltantes)

library(here)
source(here("R", "fetchers.R"))

# --- Rutas -------------------------------------------------------------------
ruta_inbox    <- here("inbox")
ruta_failed   <- here("inbox", "_failed")
ruta_pdfs     <- here("data", "raw", "pdfs")
ruta_papers   <- here("data", "raw", "papers")
ruta_build    <- here("scripts", "01_build_data.R")

# --- Setup -------------------------------------------------------------------
if (!dir.exists(ruta_inbox))  dir.create(ruta_inbox, recursive = TRUE)
if (!dir.exists(ruta_failed)) dir.create(ruta_failed, recursive = TRUE)

# --- Flujo -------------------------------------------------------------------
pdfs <- list.files(ruta_inbox, pattern = "\\.pdf$", full.names = TRUE,
                   ignore.case = TRUE, recursive = FALSE)
# Excluir lo que ya está en _failed/.
pdfs <- pdfs[dirname(pdfs) == ruta_inbox]

if (length(pdfs) == 0) {
  message("Inbox vacío: ", ruta_inbox)
  message("Suelta PDFs en esa carpeta y vuelve a correr este script.")
  quit(status = 0)
}

message(sprintf("Procesando %d PDF(s) en %s\n", length(pdfs), ruta_inbox))

resultados <- list(ok = list(), fallidos = list())

mover_a_failed <- function(pdf, razon) {
  destino <- file.path(ruta_failed, basename(pdf))
  error_file <- paste0(destino, ".error.txt")
  file.rename(pdf, destino)
  writeLines(c(
    sprintf("Archivo: %s", basename(pdf)),
    sprintf("Fecha:   %s", format(Sys.time())),
    sprintf("Razón:   %s", razon),
    "",
    "Resolución sugerida:",
    "  - Si conoces el DOI/arXiv ID, usa scripts/add_paper.R directamente:",
    "      Rscript scripts/add_paper.R \"<DOI>\"",
    "    y luego borra este archivo + el PDF de _failed/.",
    "  - Si el PDF está escaneado sin OCR, córrele OCR antes de reintentar."
  ), error_file, useBytes = TRUE)
}

for (pdf in pdfs) {
  nombre <- basename(pdf)
  message(sprintf("[%s]", nombre))

  resultado <- tryCatch({
    doi <- extract_doi_from_pdf(pdf)
    if (is.na(doi)) stop("no se encontró DOI en el texto del PDF")
    message("  DOI: ", doi)

    meta <- fetch_crossref(doi)
    slug <- generar_slug(meta$authors, meta$year, meta$title)
    message("  Slug: ", slug)

    md_path  <- file.path(ruta_papers, paste0(slug, ".md"))
    pdf_dest <- file.path(ruta_pdfs,   paste0(slug, ".pdf"))

    if (file.exists(md_path))  stop(sprintf("duplicado: ya existe %s", basename(md_path)))
    if (file.exists(pdf_dest)) stop(sprintf("duplicado: ya existe %s", basename(pdf_dest)))

    write_paper_md(meta, md_path)
    file.rename(pdf, pdf_dest)
    message("  ✓ ", basename(md_path), " + PDF movido a data/raw/pdfs/")
    list(status = "ok", slug = slug, title = meta$title, year = meta$year,
         authors = meta$authors)
  }, error = function(e) {
    razon <- conditionMessage(e)
    message("  ✗ ", razon)
    mover_a_failed(pdf, razon)
    message("  → movido a inbox/_failed/")
    list(status = "error", nombre = nombre, error = razon)
  })

  if (resultado$status == "ok") {
    resultados$ok[[length(resultados$ok) + 1]] <- resultado
  } else {
    resultados$fallidos[[length(resultados$fallidos) + 1]] <- resultado
  }
  message("")
}

# --- Resumen -----------------------------------------------------------------
message(sprintf("Resumen: %d OK, %d fallidos.",
                length(resultados$ok), length(resultados$fallidos)))

if (length(resultados$ok) > 0) {
  message("\nNuevos papers ingestados (pendientes de tags/notas):")
  for (r in resultados$ok) {
    primer_autor <- if (length(r$authors) > 0) sub(",.*", "", r$authors[1]) else "?"
    etc <- if (length(r$authors) > 1) " et al." else ""
    message(sprintf("  - %s", r$slug))
    message(sprintf("    %s (%s) — %s%s", r$title, r$year, primer_autor, etc))
  }
}

if (length(resultados$fallidos) > 0) {
  message("\nFallidos (revisar en inbox/_failed/):")
  for (r in resultados$fallidos) {
    message(sprintf("  - %s: %s", r$nombre, r$error))
  }
}

if (length(resultados$ok) > 0) {
  message("\n→ Re-construyendo papers.json...")
  source(ruta_build)
}
