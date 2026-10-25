#!/usr/bin/env bash
# Nichosi project scaffold for the Go backend and Svelte frontend.
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

See `AGENTS.md` for contributor rules and `docs/architecture.md` for design.
EOF

write AGENTS.md <<'EOF'
# Nichosi

Открытый клиент для работы с базами данных. В первую очередь MySQL/MariaDB, затем PostgreSQL и SQLite.
Основные функции: подключения, редактирование таблиц, просмотр связей и статистика.
Основной формат поставки — веб-приложение в Docker-образе. Позже планируется настольная версия для Ubuntu на Wails,
использующая то же ядро и фронтенд.

## Язык
- Общайтесь с сопровождающим проекта на русском языке.
- Код, комментарии, идентификаторы, сообщения коммитов и документация должны быть на английском языке.

## Структура репозитория
- `api/openapi.yaml` — единый контракт между backend и frontend, единственный источник истины.
- `backend/` — Go; правила находятся в `backend/AGENTS.md`.
- `frontend/` — Svelte + TypeScript + Vite; правила находятся в `frontend/AGENTS.md`.
- `deploy/` — Dockerfile и docker-compose с тестовой MySQL и схемой без внешних ключей.
- `docs/architecture.md` — архитектура и интерфейс Driver. `docs/design/` — оригинальное направление дизайна.
- `docs/decisions/` — короткие пронумерованные ADR.

## Обязательные правила
1. Сначала обновляйте контракт: изменения API начинаются в `api/openapi.yaml`, затем обновляются код и типы TypeScript.
2. Все значения SQL передавайте параметрами. Идентификаторы обрабатывайте через `Driver.QuoteIdent`.
3. Не журналируйте и не возвращайте пароли и DSN. Секреты храните только в окружении или зашифрованном хранилище.
4. Изменения интерфейса проводите через ChangeSet: предварительный просмотр SQL, затем применение одной транзакцией. Таблицы без первичного или уникального ключа доступны только для чтения.
5. Подключения с тегом `prod` по умолчанию доступны только для чтения.
6. Для каждого запроса из интерфейса задавайте лимит строк и тайм-аут.
7. Не используйте cgo. Сборки статические; SQLite — через modernc.
8. Не добавляйте телеметрию или сетевые вызовы, кроме обращений к базам данных пользователя.
9. Не копируйте брендинг и материалы третьих лиц. Используйте Lucide или Tabler и проверяйте лицензии.

## Работа с агентами
Профили проектных агентов находятся в `.claude/agents/`:
- `backend-go` отвечает за `backend/`, `deploy/` и реализацию контракта `api/openapi.yaml`.
- `frontend-svelte` отвечает за `frontend/` и разрабатывает его с mock-сервером по контракту.
- `code-reviewer` проверяет изменения только для чтения.

Агенты не создают дочерние сессии, поэтому главная сессия координирует работу:
1. Сначала согласуйте контракт и зафиксируйте его.
2. Делегируйте backend и frontend параллельно только при непересекающихся наборах файлов.
3. Перед слиянием существенных изменений попросите `code-reviewer` выполнить проверку.
4. Если агенту требуется изменить контракт, он вносит минимальное изменение в `api/openapi.yaml` и явно сообщает об этом. Главная сессия решает, нужно ли адаптировать другую часть приложения.

## Команды (см. Makefile)
`make db-up`, `make be-run`, `make be-test`, `make fe-dev`, `make gen-types`, `make mock`,
`make docker-build`.

## Git
Делайте небольшие коммиты с повелительным сообщением на английском языке (`Add keyset pagination for MySQL driver`).
Не отправляйте изменения, не используйте force-push и не переписывайте историю без просьбы пользователя.

## Критерии готовности
Сборка и тесты проходят; `go vet` и `npm run check` завершаются без ошибок; контракт согласован с кодом;
при изменении поведения обновлена документация.
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
description: Инженер Go-backend для Nichosi. Используйте для задач в backend/ и deploy/, реализации api/openapi.yaml, драйверов MySQL/PostgreSQL/SQLite, генерации SQL, ChangeSet, связей, статистики и Go-тестов.
tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
---

Вы — инженер Go-backend проекта Nichosi, открытого клиента для баз данных.

Перед началом прочитайте: /AGENTS.md, /backend/AGENTS.md, /docs/architecture.md, /api/openapi.yaml.

## Область ответственности
- Можно изменять `backend/`, `deploy/`, `Makefile` и минимально `api/openapi.yaml`.
- Нельзя изменять `frontend/`; если он тоже требует изменений, сообщите об этом в отчёте.

## Порядок работы
- Следуйте контракту. Если он ошибочен или неполон, внесите минимальное изменение и явно укажите это в отчёте.
- Размещайте диалектный SQL только в реализациях `internal/driver`.
- Пишите табличные тесты; интеграционные тесты пропускайте, если MySQL из `make db-up` недоступна.
- Перед отчётом выполните `gofmt`, `go vet ./...`, `go test ./...`.
- Не журналируйте секреты и не собирайте значения SQL конкатенацией строк.

## Краткий отчёт
1. Что изменено (по одной строке на файл).
2. Изменения контракта или «нет».
3. Как проверить (точные команды).
4. Открытые вопросы и риски.
EOF

write .claude/agents/frontend-svelte.md <<'EOF'
---
name: frontend-svelte
description: Инженер Svelte + TypeScript для frontend проекта Nichosi. Используйте для задач в frontend/: таблица данных, ChangeSet, граф связей, статистика, SQL-редактор, темы и тесты. Разработка по mock-серверу api/openapi.yaml.
tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
---

Вы — frontend-инженер проекта Nichosi, открытого клиента для баз данных.

Перед началом прочитайте: /AGENTS.md, /frontend/AGENTS.md, /api/openapi.yaml и направление дизайна в /docs/design/.

## Область ответственности
- Можно изменять только `frontend/`.
- Нельзя изменять `backend/` и `api/openapi.yaml`. Если контракт мешает работе, точно укажите, чего не хватает или что неверно.

## Порядок работы
- Генерируйте типы API через `make gen-types`, не описывайте их вручную.
- Разрабатывайте через `make mock` (Prism); большие таблицы виртуализируйте.
- Изменения ячеек накапливайте в ChangeSet store, а не отправляйте напрямую в API.
- Следуйте оригинальному направлению дизайна. Не копируйте сторонние значки, интерфейсы или брендинг; используйте Lucide или Tabler и проверяйте лицензии.
- Перед отчётом выполните `npm run check` и `npm run build`.

## Краткий отчёт
1. Что изменено (по одной строке на файл).
2. Проблемы контракта или «нет».
3. Как проверить (точные команды).
4. Открытые вопросы и риски.
EOF

write .claude/agents/code-reviewer.md <<'EOF'
---
name: code-reviewer
description: Рецензент изменений Nichosi с доступом только для чтения. Проверяет безопасность SQL, секреты, соответствие контракту, обработку ошибок и тесты.
tools: Read, Grep, Glob, Bash
model: inherit
---

Вы проверяете код Nichosi и никогда не изменяете файлы.

Просмотрите `git diff` и `git diff --staged`, затем проверьте:
1. SQL: значения передаются параметрами, идентификаторы экранируются драйвером, заданы лимиты и тайм-ауты.
2. Секреты: пароли и DSN отсутствуют в журналах, ошибках, ответах, фикстурах и коммитах.
3. Контракт: код согласован с `api/openapi.yaml`.
4. Изменения: ChangeSet применяется одной транзакцией; соблюдаются правила `prod` и read-only.
5. Обрабатываются ошибки и отмена контекста; нет утечек горутин.
6. Для нового поведения есть тесты.

Выведите замечания по убыванию серьёзности (блокер / следует исправить / мелочь), укажите `файл:строка` и конкретное предложение. Если блокеров нет, скажите об этом прямо.
EOF

# ---------------------------------------------------------------- backend
write backend/AGENTS.md <<'EOF'
# Backend (Go)

- В первую очередь используйте стандартную библиотеку Go: `net/http` с маршрутизатором Go 1.22+, `log/slog` и `context`.
- Драйверы: `go-sql-driver/mysql`, `pgx`, `modernc.org/sqlite` (без cgo).
- Типы и заглушки сервера генерируются из `../api/openapi.yaml` через oapi-codegen. Не пишите вручную типы запросов и ответов, определённые контрактом.
- Структура: `cmd/nichosi` — точка входа; `internal/driver` — интерфейс `Driver` и весь диалектный SQL; `internal/service` — сервисы и ChangeSet; `internal/httpapi` — обработчики и middleware; `internal/store` — локальная SQLite и зашифрованные секреты.
- Конфигурация через `NICHOSI_ADDR` (по умолчанию `127.0.0.1:8080`), `NICHOSI_DATA_DIR`, `NICHOSI_SECRET_KEY`.
- Привязка к `0.0.0.0` должна быть явным выбором. До привязки к адресу вне loopback требуется аутентификация администратора.
- Оборачивайте ошибки с `%w`; преобразуйте их в схему `Error` из контракта только на HTTP-границе.
- Пишите табличные тесты. Интеграционные тесты используют MySQL из `make db-up` и пропускаются, если база недоступна.
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
write frontend/AGENTS.md <<'EOF'
# Frontend (Svelte + TypeScript)

- Используйте Svelte, Vite и TypeScript в строгом режиме.
- Типы API генерируются командой `make gen-types` в `src/lib/api/schema.d.ts`. Не описывайте вручную типы объектов контракта.
- Разрабатывайте через `make mock` (Prism на `:4010`); позднее переключите прокси на backend.
- Используйте CodeMirror 6 для SQL-редактора, Cytoscape.js для графа связей и виртуализированную таблицу; проверяйте лицензии зависимостей.
- Следуйте оригинальному направлению дизайна из `../docs/design/README.md`. Не копируйте интерфейсы, брендинг, значки и материалы других продуктов.
- Сначала реализуйте тёмную тему на CSS-переменных. Изменения ячеек накапливайте в ChangeSet store.
- Обеспечьте навигацию с клавиатуры, видимый фокус и передачу значения не только цветом.
- Необходимые скрипты: `dev`, `build`, `check`, `test`.
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
Nichosi uses an original visual identity designed for this project. Do not use screenshots,
logos, product names, or distinctive layouts from other database tools as design targets.

The interface direction is a quiet, local-first workspace: deep forest charcoal surfaces,
soft sage highlights, generous spacing, restrained motion, and clear data hierarchy. Use
licensed icon libraries (Lucide or Tabler) and check the relevant package license before
redistributing bundled assets. Do not imply a database feature works until it is connected
to the API.
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

Готово. Далее:
  1. Если есть собственные макеты интерфейса, поместите их в docs/design/.
  2. Проверьте AGENTS.md и api/openapi.yaml.
  3. Продолжайте разработку, опираясь на инструкции выбранного помощника.
EOF
