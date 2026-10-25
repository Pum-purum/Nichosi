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
