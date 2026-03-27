# CondoHome Platform - SRE & Infrastructure

Este repositório centraliza toda a infraestrutura, provisionamento e orquestração da plataforma **CondoHome**. Ele foi desenhado para simplificar o desenvolvimento local e padronizar o deploy em ambientes de nuvem (Hostinger, DigitalOcean, Azure).

## Estrutura do Repositório

A infraestrutura está organizada por domínios e ferramentas:

| Diretório | Descrição |
|---|---|
| `docker/` | Configurações do Docker Compose separadas por microserviço e infra compartilhada |
| `kubernetes/` | Manifestos Kustomize (base e overlays para local, staging, production) |
| `scripts/` | Scripts de automação para dev local, cloud provisioning e secrets |
| `configs/` | Templates de variáveis de ambiente (`.env`) e configurações do Nginx |
| `Makefile` | Atalhos rápidos para os comandos mais utilizados |

## Desenvolvimento Local

O ambiente local utiliza Docker Compose com profiles para permitir subir apenas o necessário.

### Pré-requisitos
- Docker e Docker Compose
- Java 21 e Maven (para compilar os serviços)
- Make (opcional, mas recomendado)

### Configuração Inicial

1. Copie o template de variáveis de ambiente:
   ```bash
   cp configs/envs/.env.local .env.local
   ```
2. (Opcional) Edite o `.env.local` com suas chaves de API (Asaas, OpenAI, etc).

### Comandos Principais (via Makefile)

| Comando | Ação |
|---|---|
| `make infra` | Sobe apenas PostgreSQL e Redis |
| `make tools` | Sobe infra + pgAdmin e Redis Commander |
| `make backend` | Sobe infra + todos os microserviços Spring Boot |
| `make full` | Sobe a plataforma completa (incluindo N8N) |
| `make stop` | Para todos os containers |
| `make clean` | Para tudo e **remove os volumes** (bancos de dados) |
| `make build` | Compila todos os microserviços localmente |

*Alternativa sem Make:* Você pode usar diretamente `./scripts/local/start.sh <comando>`.

## Provisionamento em Nuvem (Cloud)

O repositório inclui scripts automatizados para provisionar a infraestrutura em diferentes provedores.

### Hostinger (VPS)
Provisiona uma VPS Ubuntu com Docker, Nginx e Certbot.
```bash
./scripts/cloud/hostinger/provision.sh
```

### DigitalOcean
Suporta tanto Droplets (VPS) quanto DOKS (Kubernetes Gerenciado).
```bash
./scripts/cloud/digitalocean/provision.sh droplet
./scripts/cloud/digitalocean/provision.sh kubernetes
```

### Azure
Suporta Máquinas Virtuais, AKS (Kubernetes) e ACR (Container Registry).
```bash
./scripts/cloud/azure/provision.sh vm
./scripts/cloud/azure/provision.sh aks
```

## Kubernetes

A arquitetura Kubernetes utiliza **Kustomize** para gerenciar múltiplos ambientes sem duplicação de código.

- **Base:** Manifestos comuns a todos os ambientes (`kubernetes/base/`)
- **Overlays:** Configurações específicas por ambiente (`kubernetes/overlays/`)
  - `local`: Recursos reduzidos para testes (Minikube/Kind)
  - `staging`: Tags de imagem `staging`, réplicas simples
  - `production`: Alta disponibilidade, limites de recursos maiores

### Deploy

```bash
# Deploy em ambiente local
make k8s-local

# Deploy em produção
make k8s-prod
```

## Gestão de Secrets

Nunca commite arquivos `.env` com credenciais reais. Utilize o gerenciador de secrets incluído:

```bash
# Validar se todas as secrets estão preenchidas no arquivo
make secrets-validate ENV=production

# Sincronizar secrets do .env para os repositórios no GitHub (requer GitHub CLI)
make secrets-github ENV=production

# Criar secrets no cluster Kubernetes a partir do .env
./scripts/secrets/manage-secrets.sh k8s-create production configs/envs/.env.production
```

---
*Desenvolvido por Debug Software*
