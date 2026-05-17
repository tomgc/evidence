#!/usr/bin/env Rscript
# scripts/03_process_inbox.R
# Procesa PDFs sueltos en data/raw/pdfs/inbox/:
#   1. Extrae el DOI del texto del PDF.
#   2. Consulta CrossRef para los metadatos.
#   3. Escribe data/raw/papers/<slug>.md con frontmatter prefillado.
#   4. Mueve el PDF a data/raw/pdfs/<slug>.pdf (out of inbox).
#   5. Re-construye papers.json al final.
#
# Ideal para migrar tu carpeta de PDFs existente: los sueltas en
# data/raw/pdfs/inbox/ y corres este script.
#
# Errores por PDF individual no detienen el batch (C.9): se reportan y se sigue.
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
ruta_inbox  <- here("data", "raw", "pdfs", "inbox")
ruta_pdfs   <- here("data", "raw", "pdfs")
ruta_papers <- here("data", "raw", "papers")

# --- Flujo -------------------------------------------------------------------
pdfs <- list.files(ruta_inbox, pattern = "\\.pdf$", full.names = TRUE,
                   ignore.case = TRUE)
if (length(pdfs) == 0) {
  message("Inbox vacío: ", ruta_inbox)
  message("Suelta PDFs en esa carpeta y vuelve a correr este script.")
  quit(status = 0)
}

message(sprintf("Procesando %d PDF(s) en %s\n", length(pdfs), ruta_inbox))

resultados <- list(ok = character(), fallidos = list())

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

    md_path <- file.path(ruta_papers, paste0(slug, ".md"))
    pdf_dest <- file.path(ruta_pdfs, paste0(slug, ".pdf"))

    if (file.exists(md_path)) {
      stop(sprintf("ya existe %s — duplicado", basename(md_path)))
    }
    if (file.exists(pdf_dest)) {
      stop(sprintf("ya existe %s — duplicado", basename(pdf_dest)))
    }

    write_paper_md(meta, md_path)
    file.rename(pdf, pdf_dest)
    message("  ✓ ", basename(md_path), " + PDF movido")
    list(status = "ok", slug = slug)
  }, error = function(e) {
    message("  ✗ ", conditionMessage(e))
    list(status = "error", error = conditionMessage(e))
  })

  if (resultado$status == "ok") {
    resultados$ok <- c(resultados$ok, resultado$slug)
  } else {
    resultados$fallidos[[nombre]] <- resultado$error
  }
  message("")
}

# --- Resumen -----------------------------------------------------------------
message(sprintf("Resumen: %d OK, %d fallidos.",
                length(resultados$ok), length(resultados$fallidos)))

if (length(resultados$fallidos) > 0) {
  message("\nFallidos (los PDFs siguen en inbox/):")
  for (nombre in names(resultados$fallidos)) {
    message(sprintf("  - %s: %s", nombre, resultados$fallidos[[nombre]]))
  }
}

if (length(resultados$ok) > 0) {
  message("\n→ Re-construyendo papers.json...")
  source(here("scripts", "01_build_data.R"))
  message("\nLos nuevos papers quedaron con status='toread' y sin tags/notas.")
  message("Edítalos en data/raw/papers/ para completar.")
}
