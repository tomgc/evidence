# 004 — Schema simplificado del paper

**Fecha:** 2026-05-17
**Estado:** vigente, reemplaza la versión inicial del schema en `_template.md`

## Contexto

El schema inicial (Fase 4) incluía 4 campos de curación: `relevance`, `status`, `my_takeaway`, `tags`. En uso, dos de ellos generaron fricción real (decisiones que el usuario no tenía interés en tomar paper por paper) y uno se reveló redundante con el cuerpo markdown.

## Cambios

| Campo | Antes | Ahora | Motivo |
|---|---|---|---|
| `relevance` | int 1-5 (opcional) | **eliminado** | El usuario explicitó que no le interesa rankear papers en una escala numérica. Genera fricción sin valor. |
| `status` | enum `toread`/`reading`/`read`/`archived` | `read: true/false` | 4 valores requerían microdecisiones (¿es "reading" o "toread"?). El boolean captura el caso que sí importa (leído vs. pendiente) sin sobre-modelar. |
| `my_takeaway` | bloque YAML literal | **eliminado** | Duplicaba función del cuerpo markdown del `.md`. Lo que el usuario quiera escribir va al cuerpo, con las primeras 1-2 líneas como TL;DR convencional. |
| `tags` | array vacío al ingestar | array vacío + **propuesta automática** | Antes el usuario tenía que detenerse a pensar tags por paper. Ahora yo propongo 3-5 tags desde abstract+título cuando se procesa, y el usuario confirma/edita. |

## Justificación

Aplicación de B.2 (simplicidad primero): "Si escribes 200 líneas y el problema se resuelve en 50, reescribe." Aquí: si tienes 4 campos de curación y 2 no aportan valor para tu usuario, elimínalos. El schema no es la oportunidad para mostrar capacidades; es la mínima información que necesita la lectura.

Aplicación de B.3 (cambios quirúrgicos): el rediseño elimina campos sin agregar nuevos. La UI pierde el filtro de status (4 valores) y gana uno equivalente más simple (3 opciones: todos/no leídos/leídos).

## Consecuencias

- **Schema canónico vivo:** ver `data/raw/papers/_template.md`.
- **Migración de los 2 papers existentes:** `vaswani` (read: true, takeaway al cuerpo) y `jumper` (read: false, sin takeaway). Sin pérdida de información.
- **Sort de la lista:** cambia de `relevance desc → year desc → título asc` a `year desc → título asc`.
- **Sin tag taxonomy fija (por ahora):** ver decisión gatillada — si después de ~30 papers detectamos drift en los tags, consolidamos en `docs/tags.md` y migramos. Por ahora libertad total.

## Revisión gatillada

Re-evaluar este schema si aparece alguno de:
- Acumular 50+ papers sin poder priorizar lectura → considerar recuperar algún tipo de prioridad (más simple: una tag `#leer-pronto`).
- Necesidad de distinguir "leyendo a medias" de "no empezado" → recuperar el estado intermedio.
- Tags inconsistentes (`deep-learning` vs `deep_learning` vs `neural-networks`) → consolidar en vocabulario controlado.
