#!/usr/bin/env bash
# rollback.sh — Volver al commit anterior en producción
# Uso: bash scripts/rollback.sh [COMMIT_SHA]
# Si no se pasa COMMIT_SHA, vuelve al commit anterior (HEAD~1).
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/stockery}"
COMPOSE="docker compose -f docker/compose.prod.yml --env-file .env.production"

cd "$DEPLOY_DIR"

TARGET="${1:-HEAD~1}"
echo "▶ Revertiendo a $TARGET..."
git checkout "$TARGET"

echo "▶ Reconstruyendo y reiniciando..."
$COMPOSE build
$COMPOSE up -d --remove-orphans

echo "✅ Rollback a $TARGET completado."
echo "   Para volver a la rama principal: git checkout main && bash scripts/deploy.sh"
