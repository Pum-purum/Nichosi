# Nichosi

Nichosi is an open-source database workspace for exploring, querying, and understanding
MySQL/MariaDB first, with PostgreSQL and SQLite planned next.

The current Docker preview runs Nichosi with a seeded MySQL database. The bundled test
connection and additional saved profiles are loaded from a host-side `connections.json`
file on each app start. The JSON file contains passwords in plain text, so keep it local;
it is ignored by Git and mounted read-only into the app container.

## Run the local Docker preview

1. Copy `.env.example` to `.env` and replace each placeholder with a unique random value.
   `NICHOSI_ADMIN_TOKEN` must be at least 24 characters. Keep `.env` private; it is ignored by Git.
2. Run `make db-up` to build and start the app and seeded MySQL database. On first run,
   it copies `connections.example.json` to the ignored local `connections.json`.
3. Copy `MYSQL_PASSWORD` from `.env` into the `password` field in `connections.json`.
4. Restart Nichosi with `docker compose --env-file .env -f deploy/docker-compose.yml restart nichosi`.
5. Open <http://127.0.0.1:8080> and unlock the workspace with `NICHOSI_ADMIN_TOKEN`;
   the test database connection is loaded from the file.
6. For a desktop SQL client on the host, use `127.0.0.1:3307`.

Add other profiles to the `connections` array and enter each password in its `password`
field. Restart Nichosi after changing the file so it reloads the profiles. The app shows
an example profile and restart command from its connection help screen.

The app and database ports are bound to loopback only. The MySQL seed creates a small
Bitrix-like schema without foreign keys. The app reads `connections.json` directly from the
host; it is bind-mounted read-only and excluded from the image build. `make db-down` stops the
containers and preserves the MySQL volume; use Docker Desktop to inspect or remove it.

See `AGENTS.md` and the backend/frontend `AGENTS.md` files for contributor rules.
See `docs/architecture.md` for the planned system design.
See `docs/design/README.md` for the original visual direction and asset guidance.
