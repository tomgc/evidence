# 003 — Dependencias en `DESCRIPTION`, no en `renv` (por ahora)

**Fecha:** 2026-05-17
**Estado:** vigente, revisar si suman colaboradores

## Contexto

C.12 (Gestión Explícita de Dependencias) pide declarar todas las librerías necesarias y, para proyectos de larga vida, **considerar `renv`** para un lock estricto.

## Alternativas

1. **`renv::init()`** — lock estricto por versión, library aislada del usuario, restauración exacta con `renv::restore()`. Estado del arte para reproducibilidad R.
2. **Archivo `DESCRIPTION`** — declara dependencias por nombre sin pinearlas a versión. Estándar de la comunidad R; reconocido por `r-lib/actions/setup-r-dependencies@v2`.
3. **Nada formal** — sólo el patrón install-if-missing dentro de cada script (estado anterior a esta decisión).

## Decisión

Opción 2: **`DESCRIPTION` con `Imports:` listando las dependencias**.

## Justificación (declarando excepción a la sugerencia de renv en C.12)

| Criterio | `renv` | `DESCRIPTION` |
|---|---|---|
| Captura de intent | sí | sí |
| Reproducibilidad exacta de versiones | **sí** | no |
| Costo de mantenimiento del lockfile | alto | nulo |
| Acoplamiento al `.Rprofile` del proyecto | sí (renv lo activa siempre) | no |
| Velocidad de CI cold | lento (cachear `renv/library`) | medio |
| Valor para proyecto single-user | bajo (rara vez hay drift que rompa) | adecuado |

El proyecto es de un solo usuario, sobre un stack R estable (paquetes maduros: `here`, `yaml`, `jsonlite`, `purrr`, `httr2`, `xml2`, `pdftools`, `stringi`). El costo operativo de mantener `renv.lock` actualizado supera el beneficio actual.

## Revisión gatillada

Migrar a `renv` cuando aparezca **alguno** de:
- Un segundo colaborador que vaya a correr el pipeline localmente.
- Drift detectado: una versión nueva de un paquete rompe el build.
- Cambio del runner de CI a una imagen distinta.

## Consecuencias

- `DESCRIPTION` es la fuente de verdad para "qué necesito instalado".
- `.github/workflows/deploy.yml` puede usar `r-lib/actions/setup-r-dependencies@v2` directamente sin lista hardcoded de paquetes (lee el `DESCRIPTION`).
- Los scripts mantienen el install-if-missing como red de seguridad para correr localmente sin pasos previos.
