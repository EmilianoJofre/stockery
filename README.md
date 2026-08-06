# Stockify

Stockify es un MVP SaaS en monorepo para gestion de inventario y retail, con backend Rails API y frontend React/Vite.

## Aplicaciones

- `stockify-api`: API en Rails 7.1, PostgreSQL, autenticacion JWT en cookies `httpOnly` y cuentas demo precargadas.
- `stockify-web`: dashboard en React 18 + Vite + Tailwind con sidebar responsive, ingreso demo, flujos CRUD y reportes.
- `docker/`: orquestacion local para PostgreSQL, API y frontend.

## Cuentas Demo

Todas las cuentas demo usan la misma contrasena: `Stockify123!`

- Administrador: `admin@demo.stockify.app`
- Gerente: `manager@demo.stockify.app`
- Operador: `clerk@demo.stockify.app`

## Desarrollo Local

### API

```bash
cd stockify-api
bundle install
bundle exec rails db:prepare
bundle exec rails db:seed
bundle exec rails server
```

### Frontend

```bash
cd stockify-web
npm install
npm run dev
```

### Tests

```bash
cd stockify-api
RAILS_ENV=test bundle exec rails db:prepare   # solo la primera vez
bundle exec rails test
```

Cubre el nucleo critico: consumo FEFO de lotes, devolucion al lote de origen,
asignacion de folios (incluida la concurrencia), inmutabilidad de un DTE
emitido, calculo de neto/IVA/exento, notas de credito totales y parciales, y el
esquema del SII para boleta vs factura.

Dos cosas a saber si se agregan pruebas:

- El adaptador de ActiveJob en test es `:test`: los jobs se encolan pero no
  corren. Con `:async` los hilos usan otras conexiones, no ven los datos sin
  commitear del test y cuelgan la suite.
- Las pruebas que usan varios hilos sobre la misma tabla necesitan
  `self.use_transactional_tests = false` y limpieza manual, por la misma razon.
  Ver `test/models/caf_range_concurrency_test.rb`.

El frontend proxy-a las rutas `/api` en desarrollo. Fuera de Docker usa por defecto `http://localhost:3000`; en Docker Compose el target del proxy queda configurado como `http://api:3000`.

## Docker

```bash
docker compose -f docker/compose.yml up --build
```

Servicios:

- Frontend: `http://127.0.0.1:5174`
- API: `http://127.0.0.1:3001`
- PostgreSQL: `localhost:5432`

El script de arranque de la API prepara la base de datos y carga datos demo solo cuando aun no existen usuarios.

## Produccion en Lightsail

El stack de produccion despliega en una sola instancia Lightsail con:

- **Dominio**: `https://stockery.cl` (www redirige al apex)
- **Proxy / TLS**: Caddy 2 (certificados Let's Encrypt automaticos)
- **API**: Rails en `/api` (same-origin, sin problemas de CORS/cookies)
- **Frontend**: build estatico de Vite servido por Caddy en `/`
- **Base de datos**: PostgreSQL 16 con volumen persistente

### Deploy rapido (servidor ya configurado)

```bash
cd /opt/stockery
bash scripts/deploy.sh
```

### Primer deploy (instancia nueva)

```bash
# 1. Conectar a la instancia
ssh -i ~/.ssh/lightsail.pem ubuntu@<IP>

# 2. Bootstrap (instala Docker, clona repo)
REPO_URL=git@github.com:GITHUB_OWNER/stockery.git bash scripts/bootstrap.sh

# 3. Configurar variables de entorno
cp .env.production.example .env.production && nano .env.production

# 4. Deploy
bash scripts/deploy.sh
```

Ver guia completa: [docs/deploy-lightsail.md](docs/deploy-lightsail.md)

### Scripts disponibles

| Script | Descripcion |
|--------|-------------|
| `scripts/bootstrap.sh` | Prepara el servidor Lightsail (Docker, repo, env) |
| `scripts/deploy.sh` | Pull + build + up en produccion |
| `scripts/rollback.sh [SHA]` | Vuelve al commit anterior o a un SHA especifico |
| `scripts/backup-db.sh` | Dump comprimido de PostgreSQL (retiene ultimos 7) |

### Variables de entorno

Copia `.env.production.example` a `.env.production` y completa todos los valores. **Nunca commitear `.env.production`**.
