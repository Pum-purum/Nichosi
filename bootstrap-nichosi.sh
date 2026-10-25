#!/usr/bin/env bash
# Nichosi project scaffold for Claude Code (backend-go + frontend-svelte agents).
# Usage: bash bootstrap-nichosi.sh [path-to-Nichosi-folder] [github-user]
# Safe to re-run: existing files are never overwritten.
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
set -euo pipefail

ROOT="${1:-.}"
GH_USER="${2:-YOUR_GITHUB_USER}"
cd "$ROOT"
MOD="github.com/${GH_USER}/nichosi"

mkdir -p .claude/agents .github/workflows api deploy/seed \
  docs/design docs/decisions \
  backend/cmd/nichosi backend/internal/driver backend/internal/service \
  backend/internal/httpapi backend/internal/store \
  frontend

write() { # write <path>  (content from stdin, never overwrites)
  if [ -e "$1" ]; then echo "skip    $1 (exists)"; cat >/dev/null
  else cat >"$1"; echo "created $1"; fi
}

# ---------------------------------------------------------------- root files
write .gitignore <<'EOF'
node_modules/
dist/
bin/
*.db
*.log
.env
.env.*
.DS_Store
.claude/settings.local.json
backend/internal/web/dist/
EOF

write README.md <<'EOF'
# Nichosi

Open-source database client with a modern dark UI: connections, table editing
with a reviewable ChangeSet, relations graph (real and inferred links), statistics.

Status: early development.

See `CLAUDE.md` for contributor/agent rules and `docs/architecture.md` for design.
EOF

write CLAUDE.md <<'EOF'
# Nichosi

Open-source database client. MySQL/MariaDB first, then PostgreSQL and SQLite.
Dark IDE-style UI. Four features: connections, table editing, relations view, statistics.
Primary delivery: a web app in a Docker image. Later: a desktop binary for Ubuntu (Wails),
reusing the same core and frontend.

## Language
- Talk to the maintainer in Russian.
- Code, comments, identifiers, commit messages, docs: English.

## Repo map
- `api/openapi.yaml` - THE contract between backend and frontend. Single source of truth.
- `backend/`  - Go. See `backend/CLAUDE.md`.
- `frontend/` - Svelte + TypeScript + Vite. See `frontend/CLAUDE.md`.
- `deploy/`   - Dockerfile, docker-compose (test MySQL with a Bitrix-like schema, no FKs).
- `docs/architecture.md` - design and Driver interface. `docs/design/` - UI reference images.
- `docs/decisions/` - short ADRs (one file per decision, numbered).

## Non-negotiable rules
1. Contract first. API changes start in `api/openapi.yaml`; code and TS types follow.
2. All SQL is parameterized. Identifiers go through `Driver.QuoteIdent`. No string-built values.
3. Never log or return passwords/DSNs. Secrets only via env or the encrypted store.
4. Edits from the UI go through a ChangeSet: preview SQL, then apply in one transaction.
   Tables without PK/unique key are read-only in the UI.
5. Connections tagged `prod` are read-only by default.
6. Every query from the UI has a default row limit and a timeout.
7. No cgo. Static binaries only (SQLite via modernc).
8. Do not add telemetry or network calls other than to the user's databases.
9. Do not copy third-party branding, icons or assets. Icons: Lucide or Tabler (check license).

## Working with agents
Project subagents live in `.claude/agents/`:
- `backend-go` - owns `backend/`, `deploy/`, and implements `api/openapi.yaml`.
- `frontend-svelte` - owns `frontend/`. Develops against a mock server built from the contract.
- `code-reviewer` - read-only review of diffs.

Subagents cannot spawn other subagents, so the MAIN session orchestrates:
1. Agree the contract (main session, plan mode). Commit it.
2. Delegate backend and frontend work in parallel ONLY when the file sets do not overlap.
3. Ask `code-reviewer` before merging anything non-trivial.
4. If an agent needs a contract change, it edits `api/openapi.yaml` minimally and reports it
   explicitly; the main session decides whether the other side must adapt.

## Commands (see Makefile)
`make db-up`, `make be-run`, `make be-test`, `make fe-dev`, `make gen-types`, `make mock`,
`make docker-build`.

## Git
Small commits, imperative messages (`Add keyset pagination for MySQL driver`).
Never push, force-push or rewrite history without being asked.

## Definition of done
Builds, tests pass, `go vet` / `npm run check` clean, contract and code agree,
docs updated if behavior changed.
EOF

write Makefile <<'EOF'
.RECIPEPREFIX = >
.PHONY: help db-up db-down be-run be-test be-vet fe-install fe-dev gen-types mock docker-build

help:
> @grep -E '^[a-z-]+:.*##' Makefile | sed 's/:.*##/ -/'

db-up: ## start test MySQL (Bitrix-like schema without FKs) on :3307
> docker compose -f deploy/docker-compose.yml up -d

db-down: ## stop test MySQL and drop its data
> docker compose -f deploy/docker-compose.yml down -v

be-run: ## run backend on 127.0.0.1:8080
> cd backend && go run ./cmd/nichosi

be-test: ## backend tests
> cd backend && go test ./...

be-vet: ## backend static checks
> cd backend && go vet ./...

fe-install: ## install frontend deps
> cd frontend && npm install

fe-dev: ## frontend dev server
> cd frontend && npm run dev

gen-types: ## generate TS types from the OpenAPI contract
> cd frontend && npx openapi-typescript ../api/openapi.yaml -o src/lib/api/schema.d.ts

mock: ## mock API server from the contract (for frontend work without backend)
> npx @stoplight/prism-cli mock api/openapi.yaml -p 4010

docker-build: ## build the production image
> docker build -f deploy/Dockerfile -t nichosi:dev .
EOF

# ---------------------------------------------------------------- claude config
write .claude/settings.json <<'EOF'
{
  "permissions": {
    "allow": [
      "Bash(go build:*)",
      "Bash(go test:*)",
      "Bash(go vet:*)",
      "Bash(go mod tidy)",
      "Bash(gofmt:*)",
      "Bash(npm install)",
      "Bash(npm run:*)",
      "Bash(npx openapi-typescript:*)",
      "Bash(make:*)",
      "Bash(git status)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)"
    ],
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Bash(git push:*)",
      "Bash(rm -rf:*)"
    ]
  }
}
EOF

write .claude/agents/backend-go.md <<'EOF'
---
name: backend-go
description: Go backend engineer for Nichosi. Use proactively for anything under backend/ or deploy/, for implementing endpoints from api/openapi.yaml, database drivers (MySQL, PostgreSQL, SQLite), SQL generation, the ChangeSet logic, relation inference, statistics, and Go tests.
tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
---

You are the Go backend engineer on Nichosi, an open-source database client.

Before starting, read: /CLAUDE.md, /backend/CLAUDE.md, /docs/architecture.md, /api/openapi.yaml.

Scope
- You may edit: backend/, deploy/, Makefile, api/openapi.yaml (minimal changes only).
- You must NOT edit frontend/. If the frontend must change, say so in your report.

How you work
- Implement exactly what the contract says. If the contract is wrong or incomplete, make the
  smallest possible edit to api/openapi.yaml and flag it at the top of your report.
- Put dialect-specific SQL only inside internal/driver implementations.
- Write table-driven tests. Integration tests use the MySQL from `make db-up` and must be
  skipped (not failed) when it is unavailable.
- Run `gofmt`, `go vet ./...`, `go test ./...` before reporting.
- Never log secrets. Never build SQL values by string concatenation.

Report format (keep it short)
1. What changed (files, one line each)
2. Contract changes (or "none")
3. How to verify (exact commands)
4. Open questions / risks
EOF

write .claude/agents/frontend-svelte.md <<'EOF'
---
name: frontend-svelte
description: Svelte + TypeScript frontend engineer for Nichosi. Use proactively for anything under frontend/: the data grid, ChangeSet UI, relations graph, statistics views, SQL editor, theming, and frontend tests. Works against the mock server built from api/openapi.yaml.
tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
---

You are the frontend engineer on Nichosi, an open-source database client.

Before starting, read: /CLAUDE.md, /frontend/CLAUDE.md, /api/openapi.yaml, and look at the
reference images in /docs/design/ (the target look and layout).

Scope
- You may edit: frontend/ only.
- You must NOT edit backend/ or api/openapi.yaml. If the contract blocks you, stop and report
  exactly what is missing or wrong.

How you work
- Types come from the contract: run `make gen-types`, never hand-write API types.
- Develop against `make mock` (Prism) so you never wait for the backend.
- Large tables must be virtualized. Cell edits go into a ChangeSet store, not straight to the API.
- Dark theme first, using CSS variables so a light theme can be added later.
- Do not copy third-party icons or branding. Use Lucide or Tabler.
- Run `npm run check` and `npm run build` (and tests if present) before reporting.

Report format (keep it short)
1. What changed (files, one line each)
2. Contract gaps found (or "none")
3. How to verify (exact commands)
4. Open questions / risks
EOF

write .claude/agents/code-reviewer.md <<'EOF'
---
name: code-reviewer
description: Read-only reviewer for Nichosi changes. Use after backend or frontend work, before committing or merging. Checks SQL safety, secret handling, contract drift, error handling, and test coverage.
tools: Read, Grep, Glob, Bash
model: inherit
---

You review code for Nichosi. You never modify files.

Run `git diff` (and `git diff --staged`) to see the change, then check:
1. SQL safety: parameterized values, identifiers quoted via the driver, row limits and timeouts.
2. Secrets: no passwords/DSNs in logs, errors, responses, fixtures, or committed files.
3. Contract drift: code and frontend usage match api/openapi.yaml.
4. Edit safety: ChangeSet applies in one transaction; prod/read-only rules respected.
5. Errors and context cancellation handled; no goroutine leaks.
6. Tests exist for new behavior.

Output: a list of findings ordered by severity (blocker / should fix / nit), each with
file:line and a concrete suggestion. If there are no blockers, say so plainly.
EOF

# ---------------------------------------------------------------- backend
write backend/CLAUDE.md <<'EOF'
# Backend (Go)

- Go, standard library first: `net/http` with the Go 1.22+ pattern mux, `log/slog`, `context` everywhere.
- Drivers: `go-sql-driver/mysql`, `pgx`, `modernc.org/sqlite` (no cgo).
- Server types/stubs are generated from `../api/openapi.yaml` (use oapi-codegen; check its current
  docs for options). Do not hand-write request/response types that the contract defines.
- Layout:
  - `cmd/nichosi`        entrypoint (config from env, wiring only)
  - `internal/driver`    `Driver` interface + per-dialect implementations (ALL dialect SQL lives here)
  - `internal/service`   ConnService, SchemaService, DataService, RelationService, StatsService, ChangeSet
  - `internal/httpapi`   HTTP handlers, auth middleware, error mapping
  - `internal/store`     local SQLite: profiles, history, manual relations, stats cache; encrypted secrets
- Config via env: `NICHOSI_ADDR` (default `127.0.0.1:8080`), `NICHOSI_DATA_DIR`, `NICHOSI_SECRET_KEY`.
- Binding to 0.0.0.0 must be an explicit choice. Admin auth is required before any non-loopback bind.
- Errors: wrap with `%w`, map to the contract's Error schema at the HTTP edge only.
- Tests: table-driven; integration tests use `make db-up` and skip when unavailable.
EOF

write backend/cmd/nichosi/main.go <<'EOF'
package main

import (
	"log"
	"net/http"
	"os"
)

func main() {
	addr := os.Getenv("NICHOSI_ADDR")
	if addr == "" {
		addr = "127.0.0.1:8080"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/api/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})

	log.Printf("nichosi listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}
EOF

if [ ! -f backend/go.mod ]; then
  if command -v go >/dev/null 2>&1; then
    (cd backend && go mod init "$MOD") && echo "created backend/go.mod ($MOD)"
  else
    printf 'module %s\n' "$MOD" >backend/go.mod
    echo "created backend/go.mod (Go not found; run 'go mod tidy' later)"
  fi
fi

# ---------------------------------------------------------------- frontend
write frontend/CLAUDE.md <<'EOF'
# Frontend (Svelte + TypeScript)

- Svelte + Vite + TypeScript (strict). The app is created by the frontend agent as its first
  task (`npm create vite@latest . -- --template svelte-ts`), then dependencies are added.
- API types are generated: `make gen-types` -> `src/lib/api/schema.d.ts`. Use a thin typed client
  (e.g. openapi-fetch). Never hand-write types for contract objects.
- Work against `make mock` (Prism on :4010); switch the dev proxy to the real backend later.
- Libraries: CodeMirror 6 (SQL editor), Cytoscape.js (relations graph), a virtualized grid
  (write a small one or use a maintained library; check its license).
- Layout reference: `../docs/design/*.png` (dark IDE style: tree left, grid center, inspector right,
  bottom "Changes" panel with SQL preview and Apply/Discard).
- Theme: CSS variables on `:root`; dark first.
- State: Svelte stores. Cell edits accumulate in a ChangeSet store; Apply sends the whole set.
- Accessibility: keyboard navigation in the grid, visible focus, no color-only meaning.
- Scripts expected: `dev`, `build`, `check`, `test`.
EOF

# ---------------------------------------------------------------- api contract
write api/openapi.yaml <<'EOF'
openapi: 3.0.3
info:
  title: Nichosi API
  version: 0.1.0
  description: >
    Contract between the Go backend and the Svelte frontend.
    Change it deliberately and report every change.
servers:
  - url: http://127.0.0.1:8080
paths:
  /api/health:
    get:
      operationId: getHealth
      responses:
        "200":
          description: OK
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Health" }
  /api/connections:
    get:
      operationId: listConnections
      responses:
        "200":
          description: Saved connection profiles
          content:
            application/json:
              schema:
                type: array
                items: { $ref: "#/components/schemas/Connection" }
    post:
      operationId: createConnection
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/ConnectionInput" }
      responses:
        "201":
          description: Created
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Connection" }
        default: { $ref: "#/components/responses/Error" }
  /api/connections/{connId}/schema:
    get:
      operationId: getSchema
      parameters: [ { $ref: "#/components/parameters/ConnId" } ]
      responses:
        "200":
          description: Databases and tables
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Schema" }
        default: { $ref: "#/components/responses/Error" }
  /api/connections/{connId}/tables/{table}/rows:
    post:
      operationId: queryRows
      description: Keyset-paginated rows with structured filters (never raw SQL).
      parameters:
        - { $ref: "#/components/parameters/ConnId" }
        - { $ref: "#/components/parameters/Table" }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/RowsQuery" }
      responses:
        "200":
          description: A page of rows
          content:
            application/json:
              schema: { $ref: "#/components/schemas/RowsPage" }
        default: { $ref: "#/components/responses/Error" }
  /api/connections/{connId}/tables/{table}/changes/preview:
    post:
      operationId: previewChanges
      parameters:
        - { $ref: "#/components/parameters/ConnId" }
        - { $ref: "#/components/parameters/Table" }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/ChangeSet" }
      responses:
        "200":
          description: Generated SQL, nothing executed
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ChangePreview" }
        default: { $ref: "#/components/responses/Error" }
  /api/connections/{connId}/tables/{table}/changes/apply:
    post:
      operationId: applyChanges
      description: Applies the whole ChangeSet in one transaction; rolls back on any error.
      parameters:
        - { $ref: "#/components/parameters/ConnId" }
        - { $ref: "#/components/parameters/Table" }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/ChangeSet" }
      responses:
        "200":
          description: Result
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ApplyResult" }
        default: { $ref: "#/components/responses/Error" }
  /api/connections/{connId}/relations:
    get:
      operationId: getRelations
      parameters:
        - { $ref: "#/components/parameters/ConnId" }
        - { name: table, in: query, required: true, schema: { type: string } }
        - { name: depth, in: query, schema: { type: integer, minimum: 1, maximum: 3, default: 1 } }
      responses:
        "200":
          description: Graph around the table
          content:
            application/json:
              schema: { $ref: "#/components/schemas/RelationGraph" }
        default: { $ref: "#/components/responses/Error" }
  /api/connections/{connId}/stats/tables:
    get:
      operationId: getTableStats
      parameters: [ { $ref: "#/components/parameters/ConnId" } ]
      responses:
        "200":
          description: Sizes per table
          content:
            application/json:
              schema: { $ref: "#/components/schemas/TableStatsList" }
        default: { $ref: "#/components/responses/Error" }
  /api/connections/{connId}/stats/columns:
    get:
      operationId: getColumnProfile
      parameters:
        - { $ref: "#/components/parameters/ConnId" }
        - { name: table, in: query, required: true, schema: { type: string } }
        - { name: column, in: query, required: true, schema: { type: string } }
      responses:
        "200":
          description: Column profile (sampled)
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ColumnProfile" }
        default: { $ref: "#/components/responses/Error" }
components:
  parameters:
    ConnId: { name: connId, in: path, required: true, schema: { type: string } }
    Table: { name: table, in: path, required: true, schema: { type: string } }
  responses:
    Error:
      description: Error
      content:
        application/json:
          schema: { $ref: "#/components/schemas/Error" }
  schemas:
    Health:
      type: object
      required: [status]
      properties: { status: { type: string } }
    Error:
      type: object
      required: [code, message]
      properties:
        code: { type: string }
        message: { type: string }
    Environment:
      type: string
      enum: [dev, stage, prod]
    Connection:
      type: object
      required: [id, name, driver, host, port, user, database, environment, readOnly]
      properties:
        id: { type: string }
        name: { type: string }
        driver: { type: string, enum: [mysql, postgres, sqlite] }
        host: { type: string }
        port: { type: integer }
        user: { type: string }
        database: { type: string }
        environment: { $ref: "#/components/schemas/Environment" }
        readOnly: { type: boolean }
    ConnectionInput:
      type: object
      required: [name, driver, host, port, user, password, database, environment]
      properties:
        name: { type: string }
        driver: { type: string, enum: [mysql, postgres, sqlite] }
        host: { type: string }
        port: { type: integer }
        user: { type: string }
        password: { type: string, writeOnly: true }
        database: { type: string }
        environment: { $ref: "#/components/schemas/Environment" }
    ForeignRef:
      type: object
      required: [table, column]
      properties:
        table: { type: string }
        column: { type: string }
    Column:
      type: object
      required: [name, type, nullable, primaryKey]
      properties:
        name: { type: string }
        type: { type: string }
        nullable: { type: boolean }
        primaryKey: { type: boolean }
        foreignKey:
          allOf: [ { $ref: "#/components/schemas/ForeignRef" } ]
          nullable: true
    TableInfo:
      type: object
      required: [name, rowsEstimate, columns]
      properties:
        name: { type: string }
        rowsEstimate: { type: integer, format: int64 }
        columns:
          type: array
          items: { $ref: "#/components/schemas/Column" }
    Schema:
      type: object
      required: [tables]
      properties:
        tables:
          type: array
          items: { $ref: "#/components/schemas/TableInfo" }
    Filter:
      type: object
      required: [column, op]
      properties:
        column: { type: string }
        op: { type: string, enum: [eq, ne, lt, lte, gt, gte, like, in, isNull, notNull] }
        value: {}
    OrderBy:
      type: object
      required: [column]
      properties:
        column: { type: string }
        direction: { type: string, enum: [asc, desc], default: asc }
    RowsQuery:
      type: object
      properties:
        filters:
          type: array
          items: { $ref: "#/components/schemas/Filter" }
        orderBy:
          type: array
          items: { $ref: "#/components/schemas/OrderBy" }
        cursor: { type: string, nullable: true }
        limit: { type: integer, minimum: 1, maximum: 1000, default: 200 }
    RowsPage:
      type: object
      required: [columns, rows, editable]
      properties:
        columns:
          type: array
          items: { $ref: "#/components/schemas/Column" }
        rows:
          type: array
          description: Row values in column order. JSON null is SQL NULL.
          items:
            type: array
            items: {}
        nextCursor: { type: string, nullable: true }
        editable: { type: boolean }
        readOnlyReason: { type: string, nullable: true }
    Change:
      type: object
      required: [op]
      properties:
        op: { type: string, enum: [insert, update, delete] }
        key:
          type: object
          description: Primary/unique key column to value (update and delete).
          additionalProperties: {}
        values:
          type: object
          description: Column to new value (insert and update).
          additionalProperties: {}
    ChangeSet:
      type: object
      required: [changes]
      properties:
        changes:
          type: array
          items: { $ref: "#/components/schemas/Change" }
    ChangePreview:
      type: object
      required: [statements, warnings]
      properties:
        statements: { type: array, items: { type: string } }
        warnings: { type: array, items: { type: string } }
    ApplyResult:
      type: object
      required: [applied, rolledBack]
      properties:
        applied: { type: integer }
        rolledBack: { type: boolean }
    RelationNode:
      type: object
      required: [table, rowsEstimate]
      properties:
        table: { type: string }
        rowsEstimate: { type: integer, format: int64 }
    RelationEdge:
      type: object
      required: [fromTable, fromColumn, toTable, toColumn, kind]
      properties:
        fromTable: { type: string }
        fromColumn: { type: string }
        toTable: { type: string }
        toColumn: { type: string }
        kind: { type: string, enum: [foreignKey, inferred, manual] }
        confidence: { type: number, minimum: 0, maximum: 1 }
        orphanRatio: { type: number, nullable: true, minimum: 0, maximum: 1 }
    RelationGraph:
      type: object
      required: [nodes, edges]
      properties:
        nodes: { type: array, items: { $ref: "#/components/schemas/RelationNode" } }
        edges: { type: array, items: { $ref: "#/components/schemas/RelationEdge" } }
    TableStats:
      type: object
      required: [name, dataBytes, indexBytes, rowsEstimate]
      properties:
        name: { type: string }
        dataBytes: { type: integer, format: int64 }
        indexBytes: { type: integer, format: int64 }
        rowsEstimate: { type: integer, format: int64 }
    TableStatsList:
      type: object
      required: [tables]
      properties:
        tables: { type: array, items: { $ref: "#/components/schemas/TableStats" } }
    ColumnProfile:
      type: object
      required: [nullRatio, distinct, top]
      properties:
        nullRatio: { type: number }
        distinct: { type: integer, format: int64 }
        min: {}
        max: {}
        top:
          type: array
          items:
            type: object
            required: [value, count]
            properties:
              value: {}
              count: { type: integer, format: int64 }
        histogram:
          type: array
          items:
            type: object
            required: [bucket, count]
            properties:
              bucket: { type: string }
              count: { type: integer, format: int64 }
EOF

# ---------------------------------------------------------------- docs
write docs/architecture.md <<'EOF'
# Architecture

## Delivery
1. Docker image (primary): Go binary with the built frontend embedded (`embed`), served over HTTP.
2. Desktop binary for Ubuntu (later): Wails shell around the same core and frontend.

## Layers
UI (Svelte) -> JSON API (`api/openapi.yaml`) -> services -> `Driver` interface -> MySQL / Postgres / SQLite.
Local store (SQLite): connection profiles, query history, manual relations, cached stats.

## Driver interface (the only place dialect SQL lives)
```go
type Driver interface {
    Connect(ctx context.Context, cfg ConnConfig) error
    Databases(ctx context.Context) ([]string, error)
    Tables(ctx context.Context, db string) ([]Table, error)
    Columns(ctx context.Context, db, table string) ([]Column, error)
    Indexes(ctx context.Context, db, table string) ([]Index, error)
    ForeignKeys(ctx context.Context, db string) ([]FK, error)
    Page(ctx context.Context, q PageQuery) (Rows, error) // keyset pagination
    Exec(ctx context.Context, tx Tx, stmt Stmt) (Result, error)
    Stats(ctx context.Context, db string) (DBStats, error)
    QuoteIdent(s string) string
}
```

## Features
- Connections: profiles, env tag (dev/stage/prod), prod read-only by default, SSH tunnel, TLS, cancel query.
- Editing: virtualized grid, keyset pagination, ChangeSet (preview SQL, one transaction), PK-only editing.
- Relations: real FKs, inferred links by naming plus data check (orphan ratio), manual links; graph depth 1-3.
- Statistics: table sizes, column profile (sampled), unused/duplicate indexes, processlist, slow queries.

## Security
Loopback bind by default; admin auth before any other bind; secrets encrypted at rest with a key from env;
parameterized SQL only; row limit and timeout on every UI query; audit log of write operations.

## Milestones
1. MVP: connect, schema tree, read-only grid with filters and pagination.
2. Editing with ChangeSet.
3. Relations graph and inference.
4. Statistics.
5. Polish: SSH tunnel, PostgreSQL, Docker image on Docker Hub and ghcr.io, desktop build.
EOF

write docs/design/README.md <<'EOF'
Put the UI reference images here (for example `db-editor-datagrip-style.png`).
The frontend agent uses them as the target look and layout.
EOF

# ---------------------------------------------------------------- deploy
write deploy/docker-compose.yml <<'EOF'
services:
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: devpassword   # development only
      MYSQL_DATABASE: bitrix_test
    ports:
      - "3307:3306"
    volumes:
      - ./seed:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "127.0.0.1", "-uroot", "-pdevpassword"]
      interval: 5s
      timeout: 3s
      retries: 20
EOF

write deploy/seed/001_bitrix_like.sql <<'EOF'
-- Bitrix-style schema: relations exist by naming convention only, no FOREIGN KEYs.
CREATE TABLE b_user (
  ID INT AUTO_INCREMENT PRIMARY KEY,
  LOGIN VARCHAR(50) NOT NULL,
  NAME VARCHAR(100)
) ENGINE=InnoDB;

CREATE TABLE b_iblock (
  ID INT AUTO_INCREMENT PRIMARY KEY,
  NAME VARCHAR(255) NOT NULL,
  CODE VARCHAR(50)
) ENGINE=InnoDB;

CREATE TABLE b_iblock_element (
  ID INT AUTO_INCREMENT PRIMARY KEY,
  NAME VARCHAR(255) NOT NULL,
  IBLOCK_ID INT NOT NULL,
  ACTIVE CHAR(1) NOT NULL DEFAULT 'Y',
  SORT INT NULL,
  DATE_CREATE DATETIME NOT NULL,
  CREATED_BY INT NULL,
  KEY ix_iblock (IBLOCK_ID)
) ENGINE=InnoDB;

CREATE TABLE b_iblock_element_property (
  ID INT AUTO_INCREMENT PRIMARY KEY,
  IBLOCK_ELEMENT_ID INT NOT NULL,
  VALUE VARCHAR(255)
) ENGINE=InnoDB;

INSERT INTO b_user (LOGIN, NAME) VALUES ('admin', 'Administrator'), ('editor', 'Editor');
INSERT INTO b_iblock (NAME, CODE) VALUES ('Catalog', 'catalog'), ('News', 'news');
INSERT INTO b_iblock_element (NAME, IBLOCK_ID, ACTIVE, SORT, DATE_CREATE, CREATED_BY) VALUES
  ('Catalog A', 1, 'Y', 100, NOW(), 1),
  ('Catalog B', 1, 'Y', 200, NOW(), 2),
  ('Service',   1, 'N', NULL, NOW(), 1),
  ('Delivery',  1, 'Y', 300, NOW(), 99),  -- orphan: user 99 does not exist
  ('Press',     2, 'Y', 100, NOW(), 2);
INSERT INTO b_iblock_element_property (IBLOCK_ELEMENT_ID, VALUE) VALUES
  (1, 'red'), (1, 'large'), (2, 'blue'), (5, 'headline');
EOF

write deploy/Dockerfile <<'EOF'
# Skeleton: finalize after the frontend exists and the backend embeds frontend/dist.
FROM node:22-alpine AS web
WORKDIR /src/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
COPY api/ /src/api/
RUN npm run build

FROM golang:1.25-alpine AS build
WORKDIR /src/backend
COPY backend/go.mod backend/go.sum* ./
RUN go mod download
COPY backend/ ./
COPY --from=web /src/frontend/dist ./internal/web/dist
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/nichosi ./cmd/nichosi \
 && mkdir -p /out/data

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/nichosi /nichosi
COPY --from=build --chown=65532:65532 /out/data /data
ENV NICHOSI_ADDR=0.0.0.0:8080 NICHOSI_DATA_DIR=/data
EXPOSE 8080
VOLUME ["/data"]
ENTRYPOINT ["/nichosi"]
EOF

write .github/workflows/ci.yml <<'EOF'
name: ci
on:
  push:
  pull_request:

jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        if: ${{ hashFiles('backend/go.sum') != '' }}
        with:
          go-version: stable
      - name: vet and test
        if: ${{ hashFiles('backend/go.sum') != '' }}
        working-directory: backend
        run: |
          go vet ./...
          go test ./...

  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        if: ${{ hashFiles('frontend/package.json') != '' }}
        with:
          node-version: 22
      - name: check and build
        if: ${{ hashFiles('frontend/package.json') != '' }}
        working-directory: frontend
        run: |
          npm ci
          npm run check
          npm run build
EOF

# ---------------------------------------------------------------- git
if [ ! -d .git ]; then
  git init -b main >/dev/null 2>&1 || git init >/dev/null
  echo "initialized git repository"
fi

cat <<EOF

Done. Next steps:
  1. Copy your UI mockup PNGs into docs/design/
  2. Review CLAUDE.md and api/openapi.yaml, then: git add -A && git commit -m "Scaffold project"
  3. Start Claude Code in this folder (run: claude) and check /agents shows backend-go,
     frontend-svelte and code-reviewer.
EOF
