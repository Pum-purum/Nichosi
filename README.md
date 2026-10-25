# Nichosi

Nichosi is an open-source database workspace for exploring, querying, and understanding
MySQL/MariaDB first, with PostgreSQL and SQLite planned next.

The current Docker preview runs Nichosi with a seeded MySQL database. It supports MySQL
connection checks and a connection list; passwords are kept in memory for the lifetime
of the container and are not persisted.

## Run the local Docker preview

1. Copy `.env.example` to `.env` and replace each placeholder with a unique random value.
   `NICHOSI_ADMIN_TOKEN` must be at least 24 characters. Keep `.env` private; it is ignored by Git.
2. Run `make db-up` to build and start the app and seeded MySQL database.
3. Open <http://127.0.0.1:8080> and unlock the workspace with `NICHOSI_ADMIN_TOKEN`.
4. In Nichosi, connect using host `mysql`, port `3306`, database `bitrix_test`, and the MySQL
   user and password from `.env`. For a desktop SQL client on the host, use `127.0.0.1:3307`.

The app and database ports are bound to loopback only. The MySQL seed creates a small
Bitrix-like schema without foreign keys. `make db-down` stops the containers and preserves
the named database volume; use Docker Desktop to inspect or remove that volume.

See `AGENTS.md` and the backend/frontend `AGENTS.md` files for contributor rules.
See `docs/architecture.md` for the planned system design.
See `docs/design/README.md` for the original visual direction and asset guidance.
