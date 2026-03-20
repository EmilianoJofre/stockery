# Deploy en AWS Lightsail — Stockery

Guía completa para desplegar `stockery.cl` desde cero en una instancia Lightsail.

---

## Prerequisitos

| Herramienta | Versión mínima |
|-------------|---------------|
| Docker       | 24+           |
| Docker Compose plugin | 2.20+ |
| Git          | 2.x           |
| Acceso SSH a la instancia | — |
| Dominio `stockery.cl` apuntando a la IP de Lightsail | — |

---

## 1. Crear instancia Lightsail

1. En la consola AWS Lightsail → **Create instance**
2. Plataforma: **Linux/Unix**
3. Blueprint: **OS Only → Ubuntu 22.04 LTS**
4. Plan: mínimo **$10/mes** (2 GB RAM) para producción
5. Nombre: `stockery-prod`
6. Crear y descargar el par de claves SSH (`lightsail.pem`)

```bash
chmod 400 ~/.ssh/lightsail.pem
```

---

## 2. IP estática

1. Lightsail → **Networking → Create static IP**
2. Adjuntarla a la instancia `stockery-prod`
3. Anotar la IP (ej. `18.x.x.x`)

---

## 3. Firewall de la instancia

En Lightsail → instancia → **Networking → Firewall**, asegura que estén abiertos:

| Puerto | Protocolo | Descripción |
|--------|-----------|-------------|
| 22     | TCP       | SSH         |
| 80     | TCP       | HTTP (Caddy redirige a HTTPS) |
| 443    | TCP       | HTTPS       |
| 443    | UDP       | HTTP/3      |

---

## 4. DNS en tu proveedor de dominio

Agrega estos registros en el DNS de `stockery.cl`:

| Tipo  | Nombre | Valor          | TTL  |
|-------|--------|----------------|------|
| A     | @      | `<IP_ESTATICA>` | 300  |
| CNAME | www    | stockery.cl    | 300  |

Espera 5-30 min para propagación. Verifica con:

```bash
dig stockery.cl +short
dig www.stockery.cl +short
```

---

## 5. Conectarse a la instancia

```bash
ssh -i ~/.ssh/lightsail.pem ubuntu@<IP_ESTATICA>
```

---

## 6. Bootstrap del servidor (primera vez)

En la instancia:

```bash
# Descarga el script de bootstrap del repo
curl -fsSL https://raw.githubusercontent.com/GITHUB_OWNER/stockery/main/scripts/bootstrap.sh -o bootstrap.sh

# O clona el repo directamente si ya tienes acceso SSH configurado
git clone git@github.com:GITHUB_OWNER/stockery.git /opt/stockery

# Ejecuta el bootstrap
REPO_URL=git@github.com:GITHUB_OWNER/stockery.git bash bootstrap.sh
```

Reinicia la sesión SSH para activar permisos de Docker:

```bash
exit
ssh -i ~/.ssh/lightsail.pem ubuntu@<IP_ESTATICA>
```

---

## 7. Configurar variables de entorno

```bash
cd /opt/stockery
cp .env.production.example .env.production
nano .env.production
```

Edita **todos** los valores marcados como `CAMBIAR_POR_*`. Valores mínimos:

```env
APP_DOMAIN=stockery.cl
LETSENCRYPT_EMAIL=tu@email.com
JWT_SECRET=$(openssl rand -hex 64)
POSTGRES_PASSWORD=$(openssl rand -hex 24)
RAILS_MASTER_KEY=<ver stockify-api/config/master.key>
DATABASE_URL=postgresql://stockify:<PASSWORD>@postgres:5432/stockify_production
```

> **RAILS_MASTER_KEY**: copia el contenido de `stockify-api/config/master.key` (archivo local, NO en git). Si no existe, genera con `cd stockify-api && EDITOR=cat bundle exec rails credentials:edit`.

---

## 8. Deploy inicial

```bash
cd /opt/stockery
bash scripts/deploy.sh
```

Esto:
1. Descarga cambios (`git pull`)
2. Construye las imágenes (`docker compose build`)
3. Levanta los servicios (`docker compose up -d`)
4. Caddy obtiene certificado TLS automáticamente de Let's Encrypt

Verifica:

```bash
docker compose -f docker/compose.prod.yml ps
curl -I https://stockery.cl
```

---

## 9. Redeploy (actualizaciones)

Desde tu máquina local:

```bash
git push origin main
```

En el servidor:

```bash
cd /opt/stockery && bash scripts/deploy.sh
```

O bien, configura un webhook/pipeline CI/CD para automatizarlo.

---

## 10. Rollback

```bash
# Volver al commit anterior
bash scripts/rollback.sh

# Volver a un commit específico
bash scripts/rollback.sh abc1234
```

---

## 11. Backup de la base de datos

```bash
bash scripts/backup-db.sh
# Backups en /opt/stockery/backups/ (últimos 7 retenidos)
```

Cron sugerido (cada día a las 3 AM):

```bash
crontab -e
# Agregar:
0 3 * * * /opt/stockery/scripts/backup-db.sh >> /var/log/stockery-backup.log 2>&1
```

---

## Troubleshooting

### Caddy no obtiene certificado TLS

- Verificar que el DNS ya propagó: `dig stockery.cl +short`
- Verificar que los puertos 80 y 443 están abiertos en el firewall de Lightsail
- Ver logs de Caddy: `docker compose -f docker/compose.prod.yml logs web`

### La API no responde

```bash
docker compose -f docker/compose.prod.yml logs api
docker compose -f docker/compose.prod.yml exec api ./bin/rails runner "puts User.count"
```

### La base de datos no inicia

```bash
docker compose -f docker/compose.prod.yml logs postgres
docker compose -f docker/compose.prod.yml exec postgres pg_isready -U stockify
```

### Reiniciar un servicio

```bash
docker compose -f docker/compose.prod.yml restart api
docker compose -f docker/compose.prod.yml restart web
```

### Ver todos los logs en tiempo real

```bash
docker compose -f docker/compose.prod.yml logs -f
```
