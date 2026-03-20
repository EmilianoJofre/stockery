#!/usr/bin/env bash
# deploy.sh — Desplegar / actualizar Stockery en producción
# Uso: bash scripts/deploy.sh [--no-build]
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/stockery}"
COMPOSE="docker compose -f docker/compose.prod.yml --env-file .env.production"

cd "$DEPLOY_DIR"

echo "▶ Descargando últimos cambios..."
git pull --ff-only

if [[ "${1:-}" != "--no-build" ]]; then
  echo "▶ Construyendo imágenes..."
  $COMPOSE build --pull
fi

echo "▶ Iniciando servicios (sin tiempo de inactividad)..."
$COMPOSE up -d --remove-orphans

echo "▶ Esperando que los servicios estén healthy..."
sleep 10
$COMPOSE ps

echo "▶ Limpiando imágenes huérfanas..."
docker image prune -f

echo "✅ Deploy completado. Visita https://$(grep APP_DOMAIN .env.production | cut -d= -f2)"
