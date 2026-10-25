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
