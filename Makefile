SHELL := /bin/bash

COMPOSE_DEV  := -f compose.yml -f compose.dev.yml
COMPOSE_PROD := -f compose.yml -f compose.prod.yml

.PHONY: help dev prod down down-prod logs logs-prod ps config-dev config-prod reset-dev

help:
	@echo "Fixges - comandos disponibles:"
	@echo ""
	@echo "  make dev          Levanta desarrollo con hot reload (http://localhost:80)"
	@echo "  make prod         Compila y levanta producción en segundo plano"
	@echo "  make down         Baja los contenedores de desarrollo"
	@echo "  make down-prod    Baja los contenedores de producción"
	@echo "  make logs         Sigue los logs de desarrollo"
	@echo "  make logs-prod    Sigue los logs de producción"
	@echo "  make ps           Muestra el estado de desarrollo"
	@echo "  make config-dev   Valida y muestra la configuración de desarrollo"
	@echo "  make config-prod  Valida y muestra la configuración de producción"
	@echo "  make reset-dev    Baja desarrollo y BORRA el volumen de PostgreSQL"

dev:
	@test -f .env.dev || cp .env.dev.example .env.dev
	docker compose --env-file .env.dev $(COMPOSE_DEV) up --build

prod:
	@test -f .env.prod || { echo "Falta .env.prod: copia .env.prod.example y cambia POSTGRES_PASSWORD."; exit 1; }
	@if grep -q 'CAMBIAR_ESTA_CLAVE' .env.prod; then echo "Cambia POSTGRES_PASSWORD en .env.prod antes de desplegar."; exit 1; fi
	docker compose --env-file .env.prod $(COMPOSE_PROD) up -d --build

down:
	@test -f .env.dev || cp .env.dev.example .env.dev
	docker compose --env-file .env.dev $(COMPOSE_DEV) down

down-prod:
	@test -f .env.prod || { echo "Falta .env.prod."; exit 1; }
	docker compose --env-file .env.prod $(COMPOSE_PROD) down

logs:
	@test -f .env.dev || cp .env.dev.example .env.dev
	docker compose --env-file .env.dev $(COMPOSE_DEV) logs -f

logs-prod:
	@test -f .env.prod || { echo "Falta .env.prod."; exit 1; }
	docker compose --env-file .env.prod $(COMPOSE_PROD) logs -f

ps:
	@test -f .env.dev || cp .env.dev.example .env.dev
	docker compose --env-file .env.dev $(COMPOSE_DEV) ps

config-dev:
	@test -f .env.dev || cp .env.dev.example .env.dev
	docker compose --env-file .env.dev $(COMPOSE_DEV) config

config-prod:
	@test -f .env.prod || { echo "Falta .env.prod."; exit 1; }
	docker compose --env-file .env.prod $(COMPOSE_PROD) config

reset-dev:
	@test -f .env.dev || cp .env.dev.example .env.dev
	docker compose --env-file .env.dev $(COMPOSE_DEV) down -v
