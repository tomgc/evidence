# CLAUDE.md — evidence

Librería personal de papers y evidencia relevante para el trabajo del autor. Sitio estático bilingüe servido por GitHub Pages, alimentado por pipeline R que parsea un `.md` por paper.

## Stack

- **R 4.5+** — pipeline (`scripts/01_build_data.R`, `add_paper.R`, `03_process_inbox.R`).
- **Paquetes R:** here, yaml, jsonlite, purrr, httr2, xml2, pdftools, stringi (en `DESCRIPTION`).
- **Web estático:** HTML/CSS/JS plano, sin frameworks. `marked@12` vendoreado local para markdown.
- **CI/CD:** GitHub Actions → branch `gh-pages` → GitHub Pages.
- **APIs externas:** CrossRef (metadata por DOI), arXiv (metadata + PDF OA).

## Estructura de archivos relevantes

```
evidence/
├── R/                       constants.R, parse_papers.R, fetchers.R
├── scripts/                 01_build_data.R, 02_deploy.sh, add_paper.R, 03_process_inbox.R
├── data/raw/papers/         <slug>.md (frontmatter YAML + cuerpo markdown)
├── data/raw/pdfs/           <slug>.pdf (canonical, tracked)
├── data/processed/          papers.json (canonical, regenerado)
├── inbox/                   PDFs sueltos en transit (gitignored)
├── site/                    HTML/CSS/JS del sitio
├── docs/decisiones/         registros metodológicos (001, 002, 003, 004)
├── .github/workflows/       deploy.yml (CI)
└── DESCRIPTION              deps R
```

## Instrucciones permanentes para este repositorio.

## Flujo de trabajo

- Después de cada cambio significativo, commit y push a `main` sin pedir confirmación. CI deploya automáticamente.
- Agrupa cambios relacionados en un solo commit; no fragmentes artificialmente.
- Mensajes de commit en español, formato conventional (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`).
- No pidas confirmación para operaciones git rutinarias: add, commit, push a main, branch, checkout, pull.
- Solo pregunta antes de operaciones destructivas o irreversibles (force-push, reset --hard, borrar branches, cambiar visibilidad del repo).

## Principios de desarrollo

Sigue `/Users/tomgc/Desktop/principios_desarrollo_v3.md`. Resumen aplicable:

- Datos crudos inmutables en `data/raw/`.
- Pipeline reproducible e idempotente.
- `here::here()` para todo path.
- Identificadores (DOI, slugs) como string.
- JSON con claves ordenadas alfabéticamente.
- Nombres de archivos sin tildes, ñ ni espacios.

## Schema actual de un paper

Campos del frontmatter YAML (ver `data/raw/papers/_template.md`):

- `title`, `authors`, `year`, `source`, `journal`, `url`, `doi` — metadata bibliográfica.
- `tags` — array; las propongo yo desde abstract+título cuando ingresta, el usuario edita.
- `added_on` — fecha YAML.
- `read` — boolean. `true` = leído, `false` = pendiente. No usar otros valores.
- `abstract`, `key_findings` — contenido del paper.
- Cuerpo (debajo del frontmatter): markdown libre con TL;DR + notas largas.

**Campos eliminados intencionalmente:** `relevance`, `status` (lifecycle de 4 valores), `my_takeaway`. No revivirlos.

## Trigger: "procesa el inbox" (y variantes)

Cuando el usuario diga **"procesa el inbox"**, **"hay papers nuevos"**, **"ingest"**, **"agrega los del inbox"** o equivalente:

1. Correr `Rscript scripts/03_process_inbox.R`.
2. Mostrar al usuario la lista de slugs nuevos (con título, año, primer autor).
3. Para cada paper nuevo: **leer el abstract + título y proponer 3-5 tags**. Mostrar la propuesta en bloque ("vaswani_2017: deep-learning, attention, transformers"). Preguntar una vez si quiere ajustar tags / agregar notas / marcar `read: true`.
4. Aplicar los cambios al `.md` y rebuild.
5. Commit + push (CI redeploya).

Si hay PDFs en `inbox/_failed/`, listarlos al final con la razón del error y sugerir resolución (DOI manual via `scripts/add_paper.R`, OCR si es escaneado).

## Trigger: "lo leí" (curación post-ingesta)

Cuando el usuario diga que leyó un paper (ej. "leí el AlphaFold, notas: ..."):

1. Cambiar `read: true` en el `.md`.
2. Agregar las notas al cuerpo (debajo del frontmatter, antes de `## Notas` si existe, o crear esa sección).
3. Si el usuario pasa `key_findings` estructurados, actualizar el YAML.
4. Rebuild + commit + push.

## Workflows del proyecto

- **Agregar 1 paper (DOI/arXiv/URL):** `Rscript scripts/add_paper.R "<input>"`.
- **Agregar muchos PDFs en batch:** soltar en `inbox/`, correr `Rscript scripts/03_process_inbox.R` (o decir "procesa el inbox").
- **Preview local:** `python3 -m http.server 4322 --directory site` → http://localhost:4322
- **Deploy automático:** push a main → GitHub Actions → gh-pages.
- **Deploy manual:** `bash scripts/02_deploy.sh`.

## Decisiones de diseño ya tomadas

- Schema: ver `data/raw/papers/_template.md` y `docs/decisiones/001_formato_metadata.md`.
- Color de acento: teal `#0f766e` (en `site/styles.css` como `--accent`).
- UI bilingüe ES/EN (toggle persistente en localStorage).
- Branch `gh-pages` huérfana, historia descartable, force-push intencional.
- Dependencias en `DESCRIPTION`, no `renv` (ver `docs/decisiones/003_*`).
- Inbox de PDFs vive en `inbox/` (raíz, gitignored), no en `data/raw/pdfs/inbox/`.

## Últimos cambios (más recientes primero)

1. **Schema simplificado:** eliminado `relevance` y `my_takeaway`; `status` → `read` boolean; tags ahora las propongo yo desde abstract+título al ingestar.
2. **Inbox top-level + verbal trigger:** `inbox/` en raíz, errores aislados en `inbox/_failed/`, trigger "procesa el inbox" documentado.
3. **Refactor C.11/C.12/D.R:** `R/constants.R` centraliza constantes nombradas; `DESCRIPTION` declara deps; rutas centralizadas en `add_paper.R`; `docs/decisiones/001-003`.
4. **Fases 4-9 implementadas:** `add_paper.R` (Crossref/arXiv/PDF), markdown rendering, GH Actions CI deploy, URL state, inbox processor, visor PDF inline.
5. **Scaffolding inicial (fases 0-3):** estructura canónica, pipeline R `.md → papers.json`, sitio MVP bilingüe, deploy a `gh-pages`.
