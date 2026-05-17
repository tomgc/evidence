# evidence

Biblioteca personal de papers y evidencia relevante para mi trabajo. Sitio estático bilingüe (ES/EN) servido por GitHub Pages.

**Estado:** en construcción — Fase 0 (scaffolding).

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

- **Fase 0** *(actual)*: scaffolding del repo.
- **Fase 1**: pipeline R que parsea `data/raw/papers/*.md` y genera `data/processed/papers.json` validado.
- **Fase 2**: sitio MVP — listado, búsqueda full-text, filtros por tag, vista de detalle, citación copiable (APA + BibTeX).
- **Fase 3**: deploy automatizado a branch `gh-pages`.

## Convenciones

Sigue los Principios de Desarrollo personales del autor. Resumen operativo:

- Datos crudos inmutables en `data/raw/` (C.1).
- Todo path se construye con `here::here()` (C.7).
- Identificadores (DOI, slugs) siempre como string (C.6).
- JSON serializado con claves ordenadas alfabéticamente para diffs limpios (C.10).
- Nombres de archivos sin tildes, ñ ni espacios (D).
