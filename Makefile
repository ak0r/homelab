SHELL := /usr/bin/env bash
DC := docker compose

# Compose files
CLOUD := -f compose.cloud.yml
HOME  := -f compose.home.yml

# Env files
ENV_GLOBAL := env/global.env
ENV_CLOUD  := env/cloud/.cloud.env
ENV_HOME   := env/home/.home.env

NETWORK_DEFS := \
  "edge:172.20.0.0/24:172.20.0.1" \
  "service:172.21.0.0/24:172.21.0.1" \


.PHONY: help init networks cloud-up cloud-down home-up home-down \
        validate-cloud validate-home logs-cloud logs-home ps-cloud ps-home \
        prepare-cloud prepare-home fix-permissions clean

help:
	@echo "Homelab Management - offhourlab.dev"
	@echo ""
	@echo "Setup:"
	@echo "  setup             Initial setup (run once)"
	@echo "  init              Create directory structure"
	@echo "  networks          Create Docker networks"
	@echo ""
	@echo "Cloud Plane (Oracle):"
	@echo "  cloud-up          Start cloud services"
	@echo "  cloud-down        Stop cloud services"
	@echo "  cloud-restart     Restart cloud services"
	@echo "  logs-cloud        View cloud logs"
	@echo "  ps-cloud          Show cloud containers"
	@echo ""
	@echo "Home Plane:"
	@echo "  home-up           Start home services"
	@echo "  home-down         Stop home services"
	@echo "  home-restart      Restart home services"
	@echo "  logs-home         View home logs"
	@echo "  ps-home           Show home containers"
	@echo ""
	@echo "Utilities:"
	@echo "  validate-cloud    Validate cloud compose"
	@echo "  validate-home     Validate home compose"
	@echo "  fix-permissions   Fix data directory ownership"
	@echo "  clean             Remove all containers and networks"

## ---------- Initial Setup ----------
setup:
	@echo "Setting up homelab..."
	@if [ ! -f env/.cloud.env ]; then \
		cp env/.cloud.env.example env/.cloud.env; \
		echo "✓ Created env/.cloud.env from template"; \
		echo "⚠️  Edit env/.cloud.env and fill in secrets!"; \
	else \
		echo "⚠️  env/.cloud.env already exists, skipping"; \
	fi
	@$(MAKE) init
	@$(MAKE) networks
	@echo ""
	@echo "✅ Setup complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Edit env/.cloud.env and fill in all secrets"
	@echo "2. Run: make prepare-cloud"
	@echo "3. Run: make cloud-up"

## ---------- Networks ----------
networks:
	@echo "Creating Docker networks..."
	@docker network inspect edge >/dev/null 2>&1 || docker network create edge \
		--driver bridge --subnet 172.20.0.0/24 --gateway 172.20.0.1
	@docker network inspect service >/dev/null 2>&1 || docker network create service \
		--driver bridge --subnet 172.21.0.0/24 --gateway 172.21.0.1
	@echo "✓ Networks created"

## ---------- Directory Initialization ----------
init:
	@echo "Creating directory structure..."
	@mkdir -p data/cloud/{traefik/acme,tailscale/state,adguard/{work,conf}}
	@mkdir -p data/home/{traefik/{acme},tailscale/state,nextcloud,immich}
	@mkdir -p logs/{cloud,home}/{traefik,adguard}
	@echo "✓ Directory structure created"

## ---------- Cloud Plane ----------
prepare-cloud:
	@echo "Preparing cloud data directories..."
	@set -a; . env/global.env; . env/cloud/.cloud.env; set +a; \
	mkdir -p "$${APP_DATA_ROOT}/traefik/acme" \
					 "$${APP_DATA_ROOT}/tailscale/state" \
	         "$${APP_DATA_ROOT}/adguard/"{work,conf} \
	         "$${APP_LOGS_ROOT}/"{traefik,adguard}; \
	touch "$${APP_DATA_ROOT}/traefik/acme/acme.json"; \
	chmod 600 "$${APP_DATA_ROOT}/traefik/acme/acme.json"; \
	chown -R $(shell id -u):$(shell id -g) "$${APP_DATA_ROOT}" "$${APP_LOGS_ROOT}" 2>/dev/null || true; \
	echo "✓ Cloud data directories prepared"

cloud-up: networks prepare-cloud
	@echo "Starting cloud services..."
	$(DC) $(ENV_CLOUD) $(CLOUD) up -d
	@echo "✓ Cloud services started"
	@echo ""
	@echo "Access your services:"
	@echo "  Traefik: https://traefik.cloud.offhourlab.dev"
	@echo "  AdGuard: https://adguard.cloud.offhourlab.dev"

cloud-down:
	@echo "Stopping cloud services..."
	$(DC) $(ENV_CLOUD) $(CLOUD) down
	@echo "✓ Cloud services stopped"

cloud-restart: cloud-down cloud-up

validate-cloud:
	@echo "Validating cloud compose..."
	@$(DC) $(ENV_CLOUD) $(CLOUD) config -q && echo "✓ Cloud compose is valid"

logs-cloud:
	$(DC) $(ENV_CLOUD) $(CLOUD) logs -f

ps-cloud:
	$(DC) $(ENV_CLOUD) $(CLOUD) ps

## ---------- Home Plane ----------
prepare-home:
	@echo "Preparing home data directories..."
	@set -a; . env/global.env; . env/.env.home; set +a; \
	mkdir -p "$${APP_DATA_ROOT}/tailscale/state" \
	         "$${APP_DATA_ROOT}/nextcloud" \
	         "$${APP_DATA_ROOT}/immich"; \
	echo "✓ Home data directories prepared"

home-up: networks prepare-home
	@echo "Starting home services..."
	$(DC) $(ENV_HOME) $(HOME) up -d
	@echo "✓ Home services started"

home-down:
	@echo "Stopping home services..."
	$(DC) $(ENV_HOME) $(HOME) down
	@echo "✓ Home services stopped"

home-restart: home-down home-up

validate-home:
	@echo "Validating home compose..."
	@$(DC) $(ENV_HOME) $(HOME) config -q && echo "✓ Home compose is valid"

logs-home:
	$(DC) $(ENV_HOME) $(HOME) logs -f

ps-home:
	$(DC) $(ENV_HOME) $(HOME) ps

## ---------- Utilities ----------
fix-permissions:
	@echo "Fixing permissions..."
	@sudo chown -R $(shell id -u):$(shell id -g) data logs 2>/dev/null || \
		chown -R $(shell id -u):$(shell id -g) data logs
	@chmod 700 data/cloud/traefik/acme data/home/traefik/acme 2>/dev/null || true
	@chmod 600 data/cloud/traefik/acme/acme.json data/home/traefik/acme/acme.json 2>/dev/null || true
	@echo "✓ Permissions fixed"

clean:
	@echo "⚠️  This will remove all containers and networks"
	@read -p "Are you sure? (y/N) " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(MAKE) cloud-down || true; \
		$(MAKE) home-down || true; \
		docker network rm edge service 2>/dev/null || true; \
		echo "✓ Cleanup complete"; \
	fi

# --------------------------------------
# Service orchestration (modular)
# --------------------------------------
SERVICE ?=
SERVICES ?=

.PHONY: check-global check-cloud-service
check-global:
	@test -f "$(ENV_GLOBAL)" || (echo "Error: $(ENV_GLOBAL) not found at repo root." && exit 1)

check-cloud-service:
	@test -n "$(SERVICE)" || (echo "Error: SERVICE not set. Use SERVICE=name" && exit 1)
	@test -d "services/cloud/$(SERVICE)" || (echo "Error: services/cloud/$(SERVICE) not found." && exit 1)
	@test -f "services/cloud/$(SERVICE)/compose.yml" || (echo "Error: compose.yml missing in services/cloud/$(SERVICE)" && exit 1)
	@test -f "env/cloud/.cloud.env" || (echo "Error: .cloud.env missing in env/cloud/" && exit 1)
	@test -f "env/cloud/.$(SERVICE).env" || (echo "Error: .$(SERVICE).env missing in env/cloud/" && exit 1)

.PHONY: cloud-service-up cloud-service-down cloud-service-logs cloud-service-ps
cloud-service-up: check-global check-cloud-service networks
	$(DC) \
	  --env-file ${ENV_GLOBAL} \
	  --env-file ${ENV_CLOUD} \
	  --env-file env/cloud/.$(SERVICE).env \
	  -f services/cloud/$(SERVICE)/compose.yml \
	  up -d

cloud-service-down: check-global check-cloud-service
	$(DC) \
	  --env-file ${ENV_GLOBAL} \
	  --env-file ${ENV_CLOUD} \
	  --env-file env/cloud/.$(SERVICE).env \
	  -f services/cloud/$(SERVICE)/compose.yml \
	  down
cloud-service-logs: check-global check-cloud-service
	$(DC) \
	  --env-file ${ENV_GLOBAL} \
	  --env-file ${ENV_CLOUD} \
	  --env-file env/cloud/.$(SERVICE).env \
	  -f services/cloud/$(SERVICE)/compose.yml \
	  logs -f

cloud-service-ps: check-global check-cloud-service
	$(DC) \
	  --env-file ${ENV_GLOBAL} \
	  --env-file ${ENV_CLOUD} \
	  --env-file env/cloud/.$(SERVICE).env \
	  -f services/cloud/$(SERVICE)/compose.yml \
	  ps