.RECIPEPREFIX = >
.PHONY: help db-up db-down be-run be-test be-vet fe-install fe-dev gen-types gen-go-types mock docker-build

help:
> @grep -E '^[a-z-]+:.*##' Makefile | sed 's/:.*##/ -/'

db-up: ## build and start Nichosi and test MySQL on loopback ports
> docker compose --env-file .env -f deploy/docker-compose.yml up -d --build

db-down: ## stop Nichosi and test MySQL, preserving database data
> docker compose --env-file .env -f deploy/docker-compose.yml down

be-run: ## run backend on 127.0.0.1:8080
> cd backend && go run ./cmd/nichosi

be-test: ## backend tests
> cd backend && go test ./...

be-vet: ## backend static checks
> cd backend && go vet ./...

fe-install: ## install frontend deps
> cd frontend && corepack pnpm install

fe-dev: ## frontend dev server
> cd frontend && corepack pnpm dev

gen-types: ## generate TS types from the OpenAPI contract
> cd frontend && npx openapi-typescript ../api/openapi.yaml -o src/lib/api/schema.d.ts

gen-go-types: ## generate Go models from the OpenAPI contract
> cd backend && go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@v2.4.1 -generate types -package main -o cmd/nichosi/api.gen.go ../api/openapi.yaml

mock: ## mock API server from the contract (for frontend work without backend)
> npx @stoplight/prism-cli mock api/openapi.yaml -p 4010

docker-build: ## build the production image
> docker build -f deploy/Dockerfile -t nichosi:dev .
