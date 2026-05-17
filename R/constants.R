# R/constants.R
# Constantes nombradas del proyecto (C.11): umbrales, rangos válidos,
# vocabularios cerrados, patrones. Cualquier script que valide o filtre
# debe consumir desde aquí, nunca usar literales sueltos en el flujo.

# --- Validación de campos del paper ------------------------------------------
YEAR_MIN <- 1900L
YEAR_MAX <- 2100L

RELEVANCE_MIN <- 1L
RELEVANCE_MAX <- 5L

# Vocabulario cerrado del lifecycle de lectura de un paper.
STATUS_VALIDOS <- c("toread", "reading", "read", "archived")

# Slug: ASCII en minúscula con guiones bajos.
# Justificación: garantiza portabilidad de paths entre OS y limpieza del JSON.
SLUG_PATTERN <- "^[a-z0-9_]+$"

# --- Pipeline ----------------------------------------------------------------
# Archivos en data/raw/papers/ que empiezan con este prefijo son plantillas
# (no se procesan en el build).
PREFIJO_TEMPLATE <- "_"

# --- Generación de slug ------------------------------------------------------
# Stopwords ES + EN para podar las "3 palabras del título" del slug.
STOPWORDS_SLUG <- c(
  "a", "an", "the", "of", "in", "on", "to", "is", "are", "and", "or",
  "for", "with", "by", "from", "as", "at", "be", "this", "that",
  "el", "la", "los", "las", "un", "una", "de", "del", "en", "y", "o",
  "con", "para", "por", "al"
)
