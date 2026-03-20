#!/usr/bin/env bash
# backup-db.sh — Backup de la base de datos PostgreSQL de producción
# Uso: bash scripts/backup-db.sh
# El backup queda en /opt/stockery/backups/
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/stockery}"
BACKUP_DIR="$DEPLOY_DIR/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/stockery_$TIMESTAMP.sql.gz"

# Leer credenciales desde el archivo de entorno
set -a; source "$DEPLOY_DIR/.env.production"; set +a

mkdir -p "$BACKUP_DIR"

echo "▶ Creando backup: $BACKUP_FILE"
docker compose -f "$DEPLOY_DIR/docker/compose.prod.yml" \
  --env-file "$DEPLOY_DIR/.env.production" \
  exec -T postgres \
  pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" \
  | gzip > "$BACKUP_FILE"

echo "✅ Backup creado: $BACKUP_FILE ($(du -sh "$BACKUP_FILE" | cut -f1))"

# Retener últimos 7 backups
ls -t "$BACKUP_DIR"/*.sql.gz | tail -n +8 | xargs -r rm --
echo "   Backups retenidos: $(ls "$BACKUP_DIR"/*.sql.gz | wc -l)"
