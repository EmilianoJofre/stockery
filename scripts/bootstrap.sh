#!/usr/bin/env bash
# bootstrap.sh — Preparar instancia Lightsail (Ubuntu 22.04) para Stockery
# Uso: bash scripts/bootstrap.sh
set -euo pipefail

echo "▶ Actualizando paquetes..."
sudo apt-get update -qq && sudo apt-get upgrade -y

echo "▶ Instalando dependencias..."
sudo apt-get install -y git curl ca-certificates gnupg

echo "▶ Instalando Docker..."
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"

echo "▶ Instalando Docker Compose plugin..."
sudo apt-get install -y docker-compose-plugin

echo "▶ Habilitando Docker al inicio..."
sudo systemctl enable --now docker

echo "▶ Clonando repositorio..."
REPO_URL="${REPO_URL:-git@github.com:GITHUB_OWNER/stockery.git}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/stockery}"
sudo git clone "$REPO_URL" "$DEPLOY_DIR"
sudo chown -R "$USER":"$USER" "$DEPLOY_DIR"

echo "▶ Creando archivo de entorno de producción..."
cp "$DEPLOY_DIR/.env.production.example" "$DEPLOY_DIR/.env.production"
echo ""
echo "⚠  IMPORTANTE: Edita $DEPLOY_DIR/.env.production con tus valores reales antes de continuar."
echo "   nano $DEPLOY_DIR/.env.production"
echo ""
echo "✅ Bootstrap completado. Reinicia la sesión SSH para activar el grupo docker."
echo "   Luego ejecuta: scripts/deploy.sh"
