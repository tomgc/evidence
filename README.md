# evidence

Biblioteca personal de papers y evidencia relevante para mi trabajo. Sitio estático bilingüe (ES/EN) servido por GitHub Pages.

**Live:** https://tomgc.github.io/evidence/

## Cómo correrlo

### Agregar un paper (automático)

```bash
Rscript scripts/add_paper.R "<DOI | arXiv ID | URL | path a PDF>"
```

Ejemplos:

```bash
Rscript scripts/add_paper.R "10.1038/s41586-021-03819-2"
Rscript scripts/add_paper.R "1706.03762"
Rscript scripts/add_paper.R "https://arxiv.org/abs/1706.03762"
Rscript scripts/add_paper.R "~/Downloads/un_paper.pdf"
```

El script resuelve metadata vía CrossRef o arXiv API, genera el slug, escribe el `.md` con el frontmatter pre-rellenado, descarga el PDF si la fuente es OA (arXiv), y regenera `papers.json`. Después solo queda editar el archivo para agregar `tags`, `key_findings`, marcar `read: true` cuando lo hayas leído, y agregar notas en el cuerpo markdown.

### Agregar un paper (manual)

1. Copiar `data/raw/papers/_template.md` con un slug nuevo (snake_case ASCII, sin tildes ni espacios).
2. Completar el frontmatter YAML y agregar notas largas en el cuerpo (soportan markdown completo: headings, listas, código, blockquotes, links).
3. (Opcional) Colocar el PDF en `data/raw/pdfs/<slug>.pdf`.
4. Correr el pipeline.

### Pipeline de datos

```bash
Rscript scripts/01_build_data.R
```

Lee todos los `.md` de `data/raw/papers/`, valida el frontmatter, y genera `data/processed/papers.json` (canonical) + `site/data/papers.json` (copia para servir).

### Preview local

```bash
python3 -m http.server 4322 --directory site
# → http://localhost:4322
```

### Procesar lote de PDFs (inbox)

Si tienes una carpeta con PDFs que quieres migrar:

```bash
cp ~/mi_carpeta_de_papers/*.pdf data/raw/pdfs/inbox/
Rscript scripts/03_process_inbox.R
```

Para cada PDF: extrae el DOI del texto, consulta CrossRef, genera el `.md` con frontmatter y mueve el PDF al destino final con el slug correspondiente. Errores en PDFs individuales no detienen el batch (los PDFs fallidos quedan en `inbox/` para revisión manual).

### Deploy a GitHub Pages

**Automático:** cada push a `main` dispara `.github/workflows/deploy.yml`, que regenera `papers.json` y publica a la branch `gh-pages`.

**Manual (para deploys ad-hoc sin esperar CI):**

```bash
bash scripts/02_deploy.sh
```

GitHub Pages sirve `gh-pages` en https://tomgc.github.io/evidence/.

## Estructura

```
evidence/
├── data/
│   ├── raw/
│   │   ├── papers/      # un .md por paper (frontmatter YAML + notas)
│   │   └── pdfs/        # PDFs locales, mismo slug que el .md
│   └── processed/       # papers.json generado por el pipeline R
├── R/                   # funciones reutilizables (source())
├── scripts/             # pipeline ejecutable
├── site/                # sitio estático (HTML/CSS/JS sin dependencias)
├── docs/
│   ├── decisiones/      # registro de decisiones metodológicas
│   └── traspaso/        # cierres de sesión
├── tmp/                 # temporales (gitignored)
├── evidence.Rproj
├── README.md
└── .gitignore
```

## Roadmap

- ~~**Fase 0**: scaffolding del repo.~~ ✓
- ~~**Fase 1**: pipeline R que parsea `data/raw/papers/*.md` y genera `data/processed/papers.json` validado.~~ ✓
- ~~**Fase 2**: sitio MVP — listado, búsqueda full-text, filtros por tag, vista de detalle, citación copiable (APA + BibTeX).~~ ✓
- ~~**Fase 3**: deploy a branch `gh-pages`.~~ ✓

**Próximos pasos (no comprometidos):** render de markdown en notas; tema oscuro; renvio automático en push (GitHub Actions).

## Dependencias

Las dependencias R están listadas en `DESCRIPTION` (`Imports:`). Para instalarlas en un entorno limpio:

```r
install.packages("pak")
pak::pak()   # instala desde DESCRIPTION
```

Cada script tiene además un bloque install-if-missing como red de seguridad para correr sin pasos previos.

La decisión de usar `DESCRIPTION` y no `renv` está documentada en [docs/decisiones/003_dependencias_description_no_renv.md](docs/decisiones/003_dependencias_description_no_renv.md).

## Convenciones

Sigue los Principios de Desarrollo personales del autor. Resumen operativo:

- Datos crudos inmutables en `data/raw/` (C.1).
- Todo path se construye con `here::here()` (C.7).
- Identificadores (DOI, slugs) siempre como string (C.6).
- JSON serializado con claves ordenadas alfabéticamente para diffs limpios (C.10).
- Nombres de archivos sin tildes, ñ ni espacios (D).
