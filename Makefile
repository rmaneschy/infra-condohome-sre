# =====================================================
# CondoHome Platform - Makefile
# Atalhos para comandos comuns de infraestrutura
# =====================================================

.PHONY: help infra tools backend full stop status logs clean build secrets-validate k8s-local k8s-staging k8s-prod

help: ## Exibir ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# =====================================================
# Docker Compose - Desenvolvimento Local
# =====================================================

infra: ## Subir infraestrutura (PostgreSQL + Redis)
	@bash scripts/local/start.sh infra

tools: ## Subir infra + ferramentas (pgAdmin, Redis Commander)
	@bash scripts/local/start.sh tools

backend: ## Subir infra + todos os microserviços
	@bash scripts/local/start.sh backend

full: ## Subir tudo (infra + backend + N8N)
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
# Secrets
# =====================================================

secrets-validate: ## Validar secrets (uso: make secrets-validate ENV=local)
	@bash scripts/secrets/manage-secrets.sh validate configs/envs/.env.$(ENV)

secrets-github: ## Configurar GitHub Secrets (uso: make secrets-github ENV=production)
	@bash scripts/secrets/manage-secrets.sh github-set configs/envs/.env.$(ENV)

secrets-template: ## Gerar template de variáveis
	@bash scripts/secrets/manage-secrets.sh template

# =====================================================
# Kubernetes
# =====================================================

k8s-local: ## Deploy no Kubernetes local (minikube/kind)
	kubectl apply -k kubernetes/overlays/local

k8s-staging: ## Deploy no Kubernetes staging
	kubectl apply -k kubernetes/overlays/staging

k8s-prod: ## Deploy no Kubernetes production
	kubectl apply -k kubernetes/overlays/production

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
