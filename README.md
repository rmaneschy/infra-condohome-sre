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

---

## Estrutura do Repositório

```
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
│   ├── gateway/                  # ms-condohome-gateway (:8080)
│   ├── portal-web/               # portal-condohome-web (:3000)
│   ├── assistente-portaria/      # assistente-portaria (:3001)
│   └── n8n/                      # N8N (:5678)
├── kubernetes/                   # Manifestos Kubernetes
│   ├── base/                     # Recursos base por domínio
│   │   ├── shared/               # Namespace, PostgreSQL, Redis, Secrets
│   │   ├── register/             # Deployment + Service
│   │   ├── billing/
│   │   ├── documents/
│   │   ├── booking/
│   │   ├── notification/
│   │   ├── finance/
│   │   ├── ai-assistant/
│   │   ├── gateway/              # + Ingress
│   │   ├── portal-web/           # + Ingress (condohome.com.br)
│   │   ├── assistente-portaria/  # + Ingress (portaria.condohome.com.br)
│   │   └── n8n/
│   └── overlays/                 # Customizações por ambiente
│       ├── local/                # Replicas: 1, resources mínimos
│       ├── staging/              # Replicas: 1-2, resources médios
│       └── production/           # Replicas: 2-3, resources altos
├── configs/
│   ├── envs/
│   │   ├── .env.local            # Variáveis para dev local
│   │   ├── .env.staging          # Variáveis para staging
│   │   └── .env.production       # Variáveis para production
│   └── nginx/
│       └── condohome.conf        # Reverse proxy para produção
├── scripts/
│   ├── local/
│   │   ├── start.sh              # Gerenciar ambiente local
│   │   └── build-all.sh          # Compilar todos os microserviços
│   ├── secrets/
│   │   └── manage-secrets.sh     # Gestão de secrets (GitHub Envs + K8s)
│   └── cloud/
│       ├── hostinger/provision.sh
│       ├── digitalocean/provision.sh
│       └── azure/provision.sh
├── docker-compose.yml            # Master compose (orquestra tudo)
└── Makefile                      # Atalhos rápidos
```

---

## Quick Start - Desenvolvimento Local

```bash
# 1. Subir apenas infraestrutura (PostgreSQL + Redis)
make infra

# 2. Subir infra + ferramentas (pgAdmin, Redis Commander)
make tools

# 3. Subir infra + todos os microserviços
make backend

# 4. Subir infra + gateway + frontends
make frontend

# 5. Subir tudo (infra + backend + frontend + N8N)
make full

# 6. Verificar status
make status

# 7. Ver logs de um serviço
make logs SERVICE=register

# 8. Parar tudo
make stop

# 9. Reset total (remove volumes)
make clean
```

---

## Gestão de Secrets com GitHub Environments

A gestão de secrets está integrada com o sistema de **GitHub Environments** do repositório `infra-condohome-cicd`.

### Hierarquia de Secrets (GitHub)

```
┌─────────────────────────────────────────────┐
│  Organization Secrets (compartilhados)      │  ← Menor prioridade
├─────────────────────────────────────────────┤
│  Repository Secrets (por repo)              │
├─────────────────────────────────────────────┤
│  Environment Secrets (por ambiente)         │  ← Maior prioridade
└─────────────────────────────────────────────┘
```

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

### Boas Práticas de Secrets

1. **Environment Secrets** para credenciais que variam por ambiente (DB_PASSWORD, API keys)
2. **Repository Secrets** apenas para valores compartilhados entre ambientes
3. **Nunca commitar** arquivos `.secrets` no repositório
4. **Rotacionar** credenciais a cada 90 dias
5. **Auditar** regularmente com `make secrets-audit`

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

### Overlays

| Overlay | Replicas | CPU Request | Memory Request |
|---|---|---|---|
| `local` | 1 | 100m | 256Mi |
| `staging` | 1-2 | 250m | 512Mi |
| `production` | 2-3 | 500m | 1Gi |

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
| Gateway | 8080 | Ponto de entrada único |
| Register | 8081 | Cadastros |
| Billing | 8082 | Cobranças |
| Documents | 8083 | Documentos |
| AI Assistant | 8085 | Assistente IA |
| Notification | 8086 | Notificações |
| Booking | 8087 | Reservas |
| Finance | 8088 | Financeiro |
| **Portal Web** | **3000** | **Frontend Admin** |
| **Assistente Portaria** | **3001** | **Frontend Portaria** |
| PostgreSQL | 5432 | Banco de dados |
| Redis | 6379 | Cache |
| N8N | 5678 | Orquestração |
| pgAdmin | 5050 | Admin DB (dev) |
| Redis Commander | 8090 | Admin Redis (dev) |

---

## Todos os Comandos

```bash
make help                    # Lista todos os comandos disponíveis

# Docker Compose
make infra                   # Subir PostgreSQL + Redis
make tools                   # Subir infra + ferramentas
make backend                 # Subir infra + microserviços
make frontend                # Subir infra + gateway + frontends
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

# Cloud
make provision-hostinger     # Provisionar Hostinger VPS
make provision-do-droplet    # Provisionar DigitalOcean Droplet
make provision-do-k8s        # Provisionar DigitalOcean K8s
make provision-azure-vm      # Provisionar Azure VM
make provision-azure-aks     # Provisionar Azure AKS
```
