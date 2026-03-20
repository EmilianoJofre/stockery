#!/bin/bash
set -e

cd /rails

echo "[api-start] Ejecutando db:prepare..."
./bin/rails db:prepare

echo "[api-start] Verificando datos semilla..."
if ! ./bin/rails runner "exit(User.exists? ? 0 : 1)" 2>/dev/null; then
  echo "[api-start] Cargando datos semilla..."
  ./bin/rails db:seed
fi

echo "[api-start] Iniciando servidor Rails..."
exec ./bin/rails server -b 0.0.0.0 -p 3000
