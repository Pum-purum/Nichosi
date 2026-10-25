# Nichosi

Nichosi is an open-source database workspace for exploring, querying, and understanding
MySQL/MariaDB first, with PostgreSQL and SQLite planned next.

The Docker image contains only the Nichosi application. Database connections are loaded
from the host-side `connections.json` file. This file can contain passwords in plain text,
so keep it local; it is ignored by Git and mounted read-only into the app container.

## Run Nichosi in Docker

1. Run `make app-up` to build and start the application. If `connections.json` does not
   exist, the command copies `connections.example.json` to the ignored local file.
2. Edit the example profile or add profiles to the `connections` array. Enter each database
   password in its `password` field.
3. Open <http://127.0.0.1:8080>. Restart the app after changing `connections.json` to reload
   profiles.
4. Run `make app-down` to stop the application.

The app port is bound to loopback only. The connections file is excluded from the image
build and bind-mounted read-only.

See `AGENTS.md` and the backend/frontend `AGENTS.md` files for contributor rules.
See `docs/architecture.md` for the planned system design.
See `docs/design/README.md` for the original visual direction and asset guidance.
