# infra-condohome-sre

Infraestrutura e operações da plataforma **CondoHome**. Centraliza Docker Compose, Kubernetes manifests, scripts de provisionamento e gestão de secrets integrada com **GitHub Environments**.

**Desenvolvido por:** Debug Software

---

## Visão Geral

Este repositório fornece toda a infraestrutura necessária para rodar a plataforma CondoHome em 3 cenários:

| Cenário | Ferramenta | Uso |
|---|---|---|
| **Desenvolvimento Local** | Docker Compose | Desenvolvedor sobe tudo com `make full` |
| **Kubernetes** | Kustomize (base + overlays) | Deploy em cluster K8s (local, staging, prod) |
| **Cloud VPS** | Scripts de provisionamento | Hostinger, DigitalOcean, Azure |

📚 **Documentação Completa de Operacionalização:** Consulte o [Guia Prático de Operacionalização](docs/operationalization.md) para o passo a passo detalhado de provisionamento em cada ambiente (Local, VPS e Kubernetes).

---

## Estrutura do Repositório

```text
infra-condohome-sre/
├── docker/                       # Docker Compose por domínio
│   ├── shared/                   # PostgreSQL + Redis + init scripts
│   ├── register/                 # ms-condohome-register (:8081)
│   ├── billing/                  # ms-condohome-billing (:8082)
│   ├── documents/                # ms-condohome-documents (:8083)
│   ├── ai-assistant/             # ms-condohome-ai-assistant (:8085)
│   ├── notification/             # ms-condohome-notification (:8086)
│   ├── booking/                  # ms-condohome-booking (:8087)
│   ├── finance/                  # ms-condohome-finance (:8088)
│   ├── kong/                     # Kong API Gateway (:8000)
│   ├── portal-web/               # portal-condohome-web (:3000)
│   ├── assistente-portaria/      # assistente-portaria (:3001)
│   └── n8n/                      # N8N (:5678)
├── kubernetes/                   # Manifestos Kubernetes
│   ├── base/                     # Recursos base por domínio
│   └── overlays/                 # Customizações por ambiente (local, staging, prod)
├── configs/
│   ├── envs/                     # Templates de variáveis de ambiente (.env.*.example)
│   ├── kong/                     # Configuração declarativa do Kong (kong.yml)
│   └── nginx/                    # Reverse proxy para produção
├── scripts/
│   ├── validate-requirements.sh  # Validador de pré-requisitos por ambiente
│   ├── local/                    # Scripts para ambiente local (start, build)
│   ├── kong/                     # Scripts de gestão e provisionamento do Kong
│   ├── secrets/                  # Gestão de secrets (GitHub Envs + K8s)
│   └── cloud/                    # Scripts de bootstrap para VPS/Cloud
├── docs/
│   ├── kong-gateway.md           # Documentação detalhada do Kong Gateway
│   └── operationalization.md     # Guia passo a passo de operacionalização
├── docker-compose.yml            # Master compose (orquestra tudo)
└── Makefile                      # Atalhos rápidos
```

---

## Validação de Requisitos

Antes de iniciar o provisionamento em qualquer ambiente, é altamente recomendado rodar o script de validação. Ele verifica se todas as ferramentas, portas, recursos e configurações necessárias estão disponíveis, e fornece instruções de correção específicas para o seu Sistema Operacional (Linux, macOS, WSL).

```bash
# Validar ambiente local (Docker Compose)
bash scripts/validate-requirements.sh local

# Validar ambiente VPS (Hostinger, DigitalOcean, Azure)
bash scripts/validate-requirements.sh vps

# Validar ambiente Kubernetes
bash scripts/validate-requirements.sh k8s

# Validar ambiente CI/CD (GitHub Actions)
bash scripts/validate-requirements.sh ci
```

---

## Quick Start - Desenvolvimento Local

```bash
# 1. Validar requisitos locais
bash scripts/validate-requirements.sh local

# 2. Subir apenas infraestrutura (PostgreSQL + Redis + Kong)
make infra

# 3. Provisionar o Kong Gateway
make kong-provision

# 4. Subir infra + todos os microserviços
make backend

# 5. Subir infra + Kong + frontends
make frontend

# 6. Subir tudo (infra + backend + frontend + N8N)
make full

# 7. Verificar status
make status

# 8. Ver logs de um serviço
make logs SERVICE=register

# 9. Parar tudo
make stop

# 10. Reset total (remove volumes)
make clean
```

---

## Kong API Gateway

O Kong Gateway atua como API Gateway centralizado, fornecendo roteamento, rate limiting, CORS, autenticação, logging e métricas para todos os microserviços. Ele está integrado à infraestrutura base e sobe automaticamente com o comando `make infra`.

Para documentação completa de arquitetura, plugins e troubleshooting, consulte [docs/kong-gateway.md](docs/kong-gateway.md).

### Comandos Rápidos do Kong

```bash
# Iniciar Kong + provisionar tudo
make kong-start

# Verificar status
make kong-status

# Health check completo (Kong + microserviços)
make kong-health

# Ver logs
make kong-logs

# Parar
make kong-stop

# Re-provisionar (após alterar configurações)
make kong-provision
```

---

## Gestão de Secrets com GitHub Environments

A gestão de secrets está integrada com o sistema de **GitHub Environments** do repositório `infra-condohome-cicd`.

### Comandos de Secrets

```bash
# Definir secrets em um GitHub Environment
make secrets-env-set ENV=staging FILE=path/to/staging.secrets

# Listar secrets de um Environment
make secrets-env-list ENV=production

# Definir secrets globais (Repository level)
make secrets-repo-set FILE=path/to/global.secrets

# Listar secrets globais
make secrets-repo-list

# Auditar secrets em todos os repos e environments
make secrets-audit

# Validar se um arquivo de secrets está completo
make secrets-validate FILE=path/to/secrets

# Gerar template de secrets
make secrets-template

# Criar Kubernetes secrets a partir de arquivo
make k8s-secrets ENV=staging FILE=path/to/staging.secrets
```

---

## Kubernetes

### Deploy por ambiente

```bash
# Local (minikube/kind)
make k8s-local

# Staging
make k8s-staging

# Production
make k8s-prod

# Criar secrets no K8s
make k8s-secrets ENV=staging FILE=configs/envs/staging.secrets

# Status
make k8s-status

# Logs
make k8s-logs POD=register
```

---

## Cloud Provisioning

### Hostinger VPS

```bash
make provision-hostinger
```

Instala Docker, Docker Compose, configura firewall, Nginx reverse proxy e SSL com Let's Encrypt.

### DigitalOcean

```bash
make provision-do-droplet    # Droplet (VPS)
make provision-do-k8s        # DOKS (Kubernetes gerenciado)
```

### Azure

```bash
make provision-azure-vm      # VM com Docker
make provision-azure-aks     # AKS (Kubernetes gerenciado)
```

---

## Portas dos Serviços

| Serviço | Porta | Descrição |
|---|---|---|
| Register | 8081 | Cadastros |
| Billing | 8082 | Cobranças |
| Documents | 8083 | Documentos |
| AI Assistant | 8085 | Assistente IA |
| Notification | 8086 | Notificações |
| Booking | 8087 | Reservas |
| Finance | 8088 | Financeiro |
| **Portal Web** | **3000** | **Frontend Admin** |
| **Assistente Portaria** | **3001** | **Frontend Portaria** |
| **Kong Proxy** | **8000** | **API Gateway (Kong)** |
| Kong Admin | 8001 | Admin API do Kong |
| Kong Manager | 8002 | GUI do Kong |
| PostgreSQL | 5432 | Banco de dados |
| Kong PostgreSQL | 5433 | Banco do Kong |
| Redis | 6379 | Cache |
| N8N | 5678 | Orquestração |
| pgAdmin | 5050 | Admin DB (dev) |
| Redis Commander | 8090 | Admin Redis (dev) |

---

## Todos os Comandos

```bash
make help                    # Lista todos os comandos disponíveis

# Docker Compose
make infra                   # Subir PostgreSQL + Redis + Kong
make tools                   # Subir infra + ferramentas
make backend                 # Subir infra + microserviços
make frontend                # Subir infra + Kong + frontends
make full                    # Subir tudo
make stop                    # Parar containers
make status                  # Status dos containers
make logs SERVICE=register   # Ver logs
make clean                   # Reset total

# Build
make build                   # Compilar todos os microserviços

# Secrets (GitHub Environments)
make secrets-env-set         # Definir Environment Secrets
make secrets-env-list        # Listar Environment Secrets
make secrets-repo-set        # Definir Repository Secrets
make secrets-repo-list       # Listar Repository Secrets
make secrets-audit           # Auditar todos os secrets
make secrets-validate        # Validar arquivo de secrets
make secrets-template        # Gerar template

# Kubernetes
make k8s-local               # Deploy local
make k8s-staging             # Deploy staging
make k8s-prod                # Deploy production
make k8s-secrets             # Criar K8s secrets
make k8s-status              # Status dos pods
make k8s-logs POD=register   # Logs de um pod

# Kong API Gateway
make kong-start              # Iniciar Kong + provisionar
make kong-stop               # Parar Kong
make kong-restart             # Reiniciar Kong
make kong-status              # Status do Kong
make kong-health              # Health check completo
make kong-logs                # Ver logs
make kong-provision           # Re-provisionar configs
make kong-reset               # Remover todas as configs
make kong-export              # Exportar configuração
make kong-shell               # Shell no container
make kong-clean               # Reset total (remove volumes)

# Cloud
make provision-hostinger     # Provisionar Hostinger VPS
make provision-do-droplet    # Provisionar DigitalOcean Droplet
make provision-do-k8s        # Provisionar DigitalOcean K8s
make provision-azure-vm      # Provisionar Azure VM
make provision-azure-aks     # Provisionar Azure AKS
```
