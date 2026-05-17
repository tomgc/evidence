# CLAUDE.md — evidence

Instrucciones permanentes para este repositorio.

## Flujo de trabajo

- Después de cada cambio significativo, commit y push a `main` sin pedir confirmación.
- Agrupa cambios relacionados en un solo commit; no fragmentes artificialmente.
- Mensajes de commit en español, formato conventional (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`).
- No pidas confirmación para operaciones git rutinarias: add, commit, push a main, branch, checkout, pull.
- Solo pregunta antes de operaciones destructivas o irreversibles (force-push, reset --hard, borrar branches, cambiar visibilidad del repo).

## Principios de desarrollo

Este proyecto sigue los Principios de Desarrollo personales en `/Users/tomgc/Desktop/principios_desarrollo_v3.md`. Resumen aplicable:

- Datos crudos inmutables en `data/raw/`.
- Pipeline reproducible e idempotente.
- `here::here()` para todo path.
- Identificadores (DOI, slugs) como string.
- JSON con claves ordenadas alfabéticamente.
- Nombres de archivos sin tildes, ñ ni espacios.

## Workflows del proyecto

- **Agregar paper:** copia `data/raw/papers/_template.md` con un slug nuevo, completa frontmatter + cuerpo, corre `Rscript scripts/01_build_data.R`.
- **Preview local:** `python3 -m http.server 4322 --directory site` → http://localhost:4322
- **Deploy:** `bash scripts/02_deploy.sh` (force-pushea a `gh-pages`; el repo es público y Pages ya está activo).

## Decisiones de diseño ya tomadas

- Schema YAML del frontmatter: ver `data/raw/papers/_template.md`.
- Color de acento: teal `#0f766e` (en `site/styles.css` como `--accent`).
- UI bilingüe ES/EN (toggle persistente en localStorage).
- Branch `gh-pages` huérfana, historia descartable, force-push intencional.
