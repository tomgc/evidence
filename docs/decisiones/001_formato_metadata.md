# 001 — Markdown por paper con frontmatter YAML

**Fecha:** 2026-05-17
**Estado:** vigente

## Contexto

Necesito una fuente de verdad para la metadata + notas de cada paper de la librería. El formato debe ser editable a mano, versionable en git con diffs limpios, parseable por un pipeline reproducible y compatible con notas largas en prosa.

## Alternativas evaluadas

1. **Export de Zotero (BibTeX / CSL-JSON / RIS)** — un único archivo regenerado periódicamente.
2. **CSV / Excel** — una fila por paper.
3. **Markdown por paper** (un `.md` por entrada, frontmatter YAML + cuerpo libre).

## Decisión

Opción 3: **un `.md` por paper en `data/raw/papers/<slug>.md`**.

## Justificación

| Criterio | Zotero export | CSV | MD per paper |
|---|---|---|---|
| Diff git por cambio | malo (archivo grande mutado) | regular | **bueno (1 archivo, 1 cambio)** |
| Fuente atómica e inmutable (C.1) | no — re-export sobrescribe | parcial | **sí** |
| Notas largas en prosa | mal (campo "notes" en una celda) | mal | **bueno (cuerpo libre markdown)** |
| Tags multi-valor robustos | bien | mal (strings con separador) | **bien (YAML array)** |
| Independencia de herramienta externa | mal (atado a Zotero) | bueno | **bueno** |
| Búsqueda full-text sobre notas | mal | mal | **bueno** |
| Escalable a cientos de papers | bueno | regular | **bueno (un archivo por entrada)** |

## Consecuencias

- El pipeline R (`scripts/01_build_data.R`) parsea todos los `.md`, valida frontmatter y genera `data/processed/papers.json` (canonical) + `site/data/papers.json` (copia para servir).
- Cada paper es una unidad de PR/commit independiente.
- Permite migración futura desde Zotero u otros formatos vía script (ej. `scripts/03_process_inbox.R` para PDFs).
- Costo: el usuario edita YAML a mano (mitigado por `scripts/add_paper.R` que pre-rellena el frontmatter desde DOI/arXiv).
