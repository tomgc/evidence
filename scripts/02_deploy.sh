#!/usr/bin/env bash
# scripts/02_deploy.sh
# Publica el sitio estático en la branch 'gh-pages' del remoto origin.
#
# Flujo:
#   1. Corre el pipeline R (scripts/01_build_data.R) para asegurar que
#      site/data/papers.json y site/data/pdfs/ estén al día.
#   2. Copia site/ a un repo git temporal con una branch huérfana 'gh-pages'.
#   3. Force-pushea esa branch al remoto. La historia de gh-pages se sobrescribe
#      intencionalmente (es una branch deploy, no de trabajo).
#
# Uso: bash scripts/02_deploy.sh   (desde la raíz del proyecto)

set -euo pipefail

# Verificar que corremos desde la raíz del repo
if [[ ! -f "evidence.Rproj" ]]; then
  echo "Error: ejecutar desde la raíz del proyecto evidence." >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
SITE_DIR="$REPO_ROOT/site"
REMOTE_URL="$(git remote get-url origin)"

# 1. Build de datos
echo "→ Construyendo datos (Rscript scripts/01_build_data.R)..."
Rscript scripts/01_build_data.R

if [[ ! -f "$SITE_DIR/data/papers.json" ]]; then
  echo "Error: $SITE_DIR/data/papers.json no existe tras el build." >&2
  exit 1
fi

# 2. Preparar repo temporal
TMP="$(mktemp -d -t evidence-deploy-XXXX)"
trap 'rm -rf "$TMP"' EXIT

echo "→ Preparando deploy en $TMP..."
cp -R "$SITE_DIR"/. "$TMP/"
# .nojekyll evita que GitHub Pages procese con Jekyll (preserva paths que
# arrancan con _ y acelera el deploy).
touch "$TMP/.nojekyll"

cd "$TMP"
git init -q -b gh-pages
git add -A
git commit -q -m "deploy: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 3. Push forzado a gh-pages
echo "→ Push forzado a origin/gh-pages..."
git remote add origin "$REMOTE_URL"
git push -f -q origin gh-pages

echo ""
echo "✓ Deploy completado."
echo "  URL: https://tomgc.github.io/evidence/"
echo "  (puede tardar 1-2 minutos en propagarse la primera vez)"
