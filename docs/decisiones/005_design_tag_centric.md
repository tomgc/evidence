# 005 — Diseño tag-centric como sitio definitivo

**Fecha:** 2026-05-20
**Estado:** vigente

## Contexto

El sitio MVP original tenía 3 columnas: sidebar (filtros) | lista densa (papers) | panel detalle (al click). Durante exploración se prototiparon dos alternativas en `site-variants/`:

1. **minimal:** una columna serif, expand-inline tipo bibliografía impresa.
2. **tag-centric:** navegación primero por tema (cards grandes para temas top + chips para el resto), drill-down al tema → grid de paper-cards → modal de detalle.

## Decisión

Se promueve `tag-centric` a `site/`. El diseño anterior (sidebar + panel) se descarta. `minimal/` se mantiene en `site-variants/` como exploración alternativa por si en el futuro tiene sentido revisitarla.

## Justificación

- La unidad principal de búsqueda en una librería personal de evidencia es el **tema**, no el paper individual. La pregunta "¿qué tengo sobre X?" llega antes que "¿qué dice este paper?". El landing por temas refleja esa jerarquía.
- Las cards grandes para los top-N temas dan una "biblioteca visual" comprensible en un golpe de vista.
- Los chips de tags en el header funcionan como atajos cuando ya sabes qué buscas — sin volver al landing.
- El modal de detalle (centrado, ~700px) es más legible para notas largas que el panel lateral, que quedaba muy estrecho.

## Paleta y tipografía

- Fondo blanco puro `#ffffff` (el usuario explícito sobre default white).
- Brand "evidence" en azul `#0062a0` (color de interacción).
- Headings de sección en púrpura `#4a2746` (carácter sin gritar).
- Texto cuerpo casi-negro `#1a1a1a`.
- Estado activo de chip: azul sólido + texto blanco.
- Coral, oliva y tan reservados en `:root` para roles futuros (warn, success, warm).

## Consecuencias

- `site-variants/tag-centric/` eliminado (se fusionó en `site/`).
- `site-variants/minimal/` se mantiene; preview server en `:4325` queda activo.
- Decisión revisable cuando la librería crezca a 50+ papers — si la navegación por tema queda saturada, agregar taxonomía curada (`docs/taxonomy.yaml`) en vez de ranking automático por frecuencia.
- La iteración de paleta y simplificación de chips (eliminar coral de la jerarquía visual, dejar sólo blanco + azul activo) reduce el ruido cromático que tenía el primer intento.
