.PHONY: help init networks cloud-up cloud-down logs ps clean

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

help: ## Show this help
	@echo "$(BLUE)Homelab Management - offhourlab.dev$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

init: ## Initialize directory structure
	@echo "$(BLUE)Creating directory structure...$(NC)"
	@mkdir -p data/{traefik/{config/dynamic,certs},adguard/{work,conf},tailscale/state}
	@mkdir -p logs/{traefik,adguard}
	@mkdir -p secrets/{traefik,adguard}
	@chmod 600 data/traefik/certs || true
	@echo "$(GREEN)✓ Directory structure created$(NC)"

networks: ## Create Docker networks
	@echo "$(BLUE)Creating Docker networks...$(NC)"
	@docker network inspect edge >/dev/null 2>&1 || docker network create edge \
		--driver bridge \
		--subnet 172.20.0.0/24 \
		--gateway 172.20.0.1 \
		--opt com.docker.network.bridge.name=br-edge
	@docker network inspect service >/dev/null 2>&1 || docker network create service \
		--driver bridge \
		--subnet 172.21.0.0/24 \
		--gateway 172.21.0.1 \
		--opt com.docker.network.bridge.name=br-service
	@echo "$(GREEN)✓ Networks created$(NC)"

cloud-up: networks init ## Start all cloud services
	@echo "$(BLUE)Starting cloud services...$(NC)"
	@cd services/cloud/tailscale && docker compose --env-file ../../../global.env --env-file ../../../cloud.env up -d
	@sleep 5
	@cd services/cloud/traefik && docker compose --env-file ../../../global.env --env-file ../../../cloud.env up -d
	@sleep 3
	@cd services/cloud/adguard && docker compose --env-file ../../../global.env --env-file ../../../cloud.env up -d
	@echo "$(GREEN)✓ Cloud services started$(NC)"
	@echo ""
	@echo "$(YELLOW)Access your services at:$(NC)"
	@echo "  Traefik: https://traefik.cloud.offhourlab.dev"
	@echo "  AdGuard: https://adguard.cloud.offhourlab.dev"

cloud-down: ## Stop all cloud services
	@echo "$(BLUE)Stopping cloud services...$(NC)"
	@cd services/cloud/adguard && docker compose down
	@cd services/cloud/traefik && docker compose down
	@cd services/cloud/tailscale && docker compose down
	@echo "$(GREEN)✓ Cloud services stopped$(NC)"

logs: ## Show all logs
	@docker compose logs -f

traefik-logs: ## View Traefik logs
	@docker logs -f traefik

adguard-logs: ## View AdGuard logs
	@docker logs -f adguard

tailscale-status: ## Check Tailscale status
	@docker exec tailscale-cloud tailscale status

ps: ## Show running containers
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

restart: cloud-down cloud-up ## Restart all cloud services

clean: ## Clean up everything (DANGEROUS)
	@echo "$(RED)⚠ This will remove all containers and networks$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(MAKE) cloud-down; \
		docker network rm edge service 2>/dev/null || true; \
		echo "$(GREEN)✓ Cleanup complete$(NC)"; \
	fi