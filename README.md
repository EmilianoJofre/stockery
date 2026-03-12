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
