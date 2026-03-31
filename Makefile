# =====================================================
# CondoHome Platform - SRE Makefile
# Atalhos para comandos comuns de infraestrutura
# =====================================================

.PHONY: help validate infra tools backend frontend full stop status logs clean build \
	kong-start kong-stop kong-restart kong-status kong-health kong-logs \
	kong-provision kong-reset kong-export kong-shell kong-clean

help: ## Exibir ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

validate: ## Validar requisitos do ambiente (uso: make validate ENV=local)
	@bash scripts/validate-requirements.sh $(ENV)

# =====================================================
# Docker Compose - Desenvolvimento Local
# =====================================================

infra: ## Subir infraestrutura (PostgreSQL + Redis)
	@bash scripts/local/start.sh infra

tools: ## Subir infra + ferramentas (pgAdmin, Redis Commander)
	@bash scripts/local/start.sh tools

backend: ## Subir infra + todos os microserviços
	@bash scripts/local/start.sh backend

frontend: ## Subir infra + gateway + frontends (portal-web, portaria)
	@bash scripts/local/start.sh frontend

full: ## Subir tudo (infra + backend + frontend + N8N)
	@bash scripts/local/start.sh full

stop: ## Parar todos os containers
	@bash scripts/local/start.sh stop

status: ## Verificar status dos containers
	@bash scripts/local/start.sh status

logs: ## Ver logs (uso: make logs SERVICE=register)
	@bash scripts/local/start.sh logs $(SERVICE)

clean: ## Parar e remover volumes (RESET TOTAL)
	@bash scripts/local/start.sh clean

# =====================================================
# Build
# =====================================================

build: ## Compilar todos os microserviços
	@bash scripts/local/build-all.sh

# =====================================================
# Secrets - GitHub Environments
# =====================================================

secrets-validate: ## Validar secrets (uso: make secrets-validate FILE=path/to/secrets)
	@bash scripts/secrets/manage-secrets.sh validate $(FILE)

secrets-env-set: ## Definir Environment Secrets (uso: make secrets-env-set ENV=staging FILE=path/to/secrets)
	@bash scripts/secrets/manage-secrets.sh env-set $(ENV) $(FILE)

secrets-env-list: ## Listar Environment Secrets (uso: make secrets-env-list ENV=staging)
	@bash scripts/secrets/manage-secrets.sh env-list $(ENV)

secrets-repo-set: ## Definir Repository Secrets globais (uso: make secrets-repo-set FILE=path/to/secrets)
	@bash scripts/secrets/manage-secrets.sh repo-set $(FILE)

secrets-repo-list: ## Listar Repository Secrets globais
	@bash scripts/secrets/manage-secrets.sh repo-list

secrets-audit: ## Auditar secrets em todos os repos e environments
	@bash scripts/secrets/manage-secrets.sh audit

secrets-template: ## Gerar template de secrets
	@bash scripts/secrets/manage-secrets.sh template

# =====================================================
# Kong API Gateway
# =====================================================

kong-start: ## Iniciar Kong Gateway + provisionar tudo
	@bash scripts/kong/manage.sh quick-start

kong-stop: ## Parar Kong Gateway
	@bash scripts/kong/manage.sh stop

kong-restart: ## Reiniciar Kong Gateway
	@bash scripts/kong/manage.sh restart

kong-status: ## Verificar status do Kong
	@bash scripts/kong/manage.sh status

kong-health: ## Health check do Kong e microservicos
	@bash scripts/kong/healthcheck.sh

kong-logs: ## Ver logs do Kong
	@bash scripts/kong/manage.sh logs

kong-provision: ## Re-provisionar services, routes e plugins
	@bash scripts/kong/provision.sh all

kong-reset: ## Remover TODAS as configuracoes do Kong
	@bash scripts/kong/provision.sh reset

kong-export: ## Exportar configuracao atual do Kong
	@bash scripts/kong/provision.sh export

kong-shell: ## Abrir shell no container do Kong
	@bash scripts/kong/manage.sh shell

kong-clean: ## Parar Kong e remover volumes (RESET TOTAL)
	@bash scripts/kong/manage.sh clean

# =====================================================
# Kubernetes
# =====================================================

k8s-local: ## Deploy no Kubernetes local (minikube/kind)
	kubectl apply -k kubernetes/overlays/local

k8s-staging: ## Deploy no Kubernetes staging
	kubectl apply -k kubernetes/overlays/staging

k8s-prod: ## Deploy no Kubernetes production
	kubectl apply -k kubernetes/overlays/production

k8s-secrets: ## Criar K8s secrets (uso: make k8s-secrets ENV=staging FILE=path/to/secrets)
	@bash scripts/secrets/manage-secrets.sh k8s-create $(ENV) $(FILE)

k8s-status: ## Status dos pods no Kubernetes
	kubectl get pods -n condohome -o wide

k8s-logs: ## Logs de um pod (uso: make k8s-logs POD=register)
	kubectl logs -n condohome -l app=$(POD) --tail=100 -f

# =====================================================
# Cloud Provisioning
# =====================================================

provision-hostinger: ## Provisionar VPS Hostinger
	@bash scripts/cloud/hostinger/provision.sh

provision-do-droplet: ## Provisionar Droplet DigitalOcean
	@bash scripts/cloud/digitalocean/provision.sh droplet

provision-do-k8s: ## Provisionar DOKS DigitalOcean
	@bash scripts/cloud/digitalocean/provision.sh kubernetes

provision-azure-vm: ## Provisionar VM Azure
	@bash scripts/cloud/azure/provision.sh vm

provision-azure-aks: ## Provisionar AKS Azure
	@bash scripts/cloud/azure/provision.sh aks
