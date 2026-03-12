# Stockify

Stockify is a monorepo SaaS MVP for inventory and retail management with a Rails API backend and a React/Vite frontend.

## Apps

- `stockify-api`: Rails 7.1 API, PostgreSQL, JWT auth in `httpOnly` cookies, seeded demo accounts.
- `stockify-web`: React 18 + Vite + Tailwind dashboard with responsive sidebar, demo login, CRUD flows, and reports.
- `docker/`: local orchestration for PostgreSQL, API, and web.

## Demo Accounts

All demo users use the same password: `Stockify123!`

- Admin: `admin@demo.stockify.app`
- Manager: `manager@demo.stockify.app`
- Clerk: `clerk@demo.stockify.app`

## Local Development

### API

```bash
cd stockify-api
bundle install
bundle exec rails db:prepare
bundle exec rails db:seed
bundle exec rails server
```

### Web

```bash
cd stockify-web
npm install
npm run dev
```

The frontend proxies `/api` requests in development. Outside Docker it defaults to `http://localhost:3000`; in Docker Compose the proxy target is set to `http://api:3000`.

## Docker

```bash
docker compose -f docker/compose.yml up --build
```

Services:

- Web: `http://127.0.0.1:5174`
- API: `http://127.0.0.1:3001`
- PostgreSQL: `localhost:5432`

The API startup script prepares the database and seeds demo data only when no users exist yet.
