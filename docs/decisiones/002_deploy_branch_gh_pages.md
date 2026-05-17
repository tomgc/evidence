# 002 — Deploy a branch `gh-pages` huérfana

**Fecha:** 2026-05-17
**Estado:** vigente

## Contexto

GitHub Pages permite servir un sitio estático desde tres orígenes: branch `main` raíz, branch `main` `/docs`, o branch separada (típicamente `gh-pages`). Hay que elegir uno.

## Tensión

El principio D reserva `docs/` para **documentación viva** del proyecto (`docs/decisiones/`, `docs/traspaso/`), no para servir el sitio. Esto colisiona con la convención de GitHub Pages `/docs`.

## Alternativas

1. **Servir desde `main:/`** — choca con la convención: `main` contiene `R/`, `scripts/`, `data/raw/`, etc., que no deben ser públicos como sitio.
2. **Servir desde `main:/docs`** — choca con el principio D, que reserva esa carpeta para documentación.
3. **Branch separada `gh-pages` huérfana** — sólo contiene los artefactos servidos; historia descartable (es deploy, no work).

## Decisión

Opción 3: **branch `gh-pages` huérfana, generada por `scripts/02_deploy.sh` o por `.github/workflows/deploy.yml`**, force-pushed en cada deploy.

## Justificación

- Mantiene `docs/` libre para su rol real (documentación viva).
- Separa el contenido del repo (fuente + pipeline) del contenido del sitio (output).
- La historia de `gh-pages` no aporta valor — es output reproducible desde `main` en cualquier momento. El force-push es intencional y correcto en deploy branches.

## Consecuencias

- El deploy es explícito (`bash scripts/02_deploy.sh`) o automático (CI).
- Para reproducir el sitio localmente: `python3 -m http.server 4322 --directory site` (sin pasar por `gh-pages`).
- El `.nojekyll` se genera en `gh-pages` (vía la GH Action o el script bash) para evitar el procesamiento Jekyll.
