#!/usr/bin/env Rscript
# scripts/add_paper.R
# Crea un paper desde DOI, arXiv ID, URL o PDF local.
#
# Uso:
#   Rscript scripts/add_paper.R "10.48550/arXiv.1706.03762"
#   Rscript scripts/add_paper.R "1706.03762"
#   Rscript scripts/add_paper.R "https://arxiv.org/abs/1706.03762"
#   Rscript scripts/add_paper.R "/ruta/al/paper.pdf"

# --- Verificación e instalación de paquetes ----------------------------------
paquetes_requeridos <- c("here", "httr2", "xml2", "pdftools", "stringi",
                         "yaml", "jsonlite", "purrr")
paquetes_faltantes <- paquetes_requeridos[
  !sapply(paquetes_requeridos, requireNamespace, quietly = TRUE)
]
if (length(paquetes_faltantes) > 0) install.packages(paquetes_faltantes)

library(here)
source(here("R", "fetchers.R"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Uso: Rscript scripts/add_paper.R <DOI | arxiv_id | URL | pdf_path>")
}
input <- args[1]

message("→ Resolviendo metadata para: ", input)
meta <- dispatch_input(input)
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

pdf_dest <- here("data", "raw", "pdfs", paste0(slug, ".pdf"))
if (guardar_pdf(meta, pdf_dest)) message("→ PDF guardado: ", pdf_dest)

message("→ Re-construyendo papers.json...")
source(here("scripts", "01_build_data.R"))

message("\n✓ Listo. Edita el archivo para tus notas y key_findings:")
message("  ", md_path)
