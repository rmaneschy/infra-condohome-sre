# Operacionalização Prática - CondoHome Platform

Este documento detalha o passo a passo prático para provisionar e operar a infraestrutura da plataforma CondoHome em diferentes ambientes.

## Premissas Globais

Independentemente do ambiente, os seguintes requisitos são necessários:
- Acesso ao repositório `infra-condohome-sre`
- Credenciais de acesso aos repositórios de código (para build local) ou ao GitHub Container Registry (GHCR) para pull de imagens
- Arquivos de ambiente (`.env`) configurados corretamente

---

## 1. Ambiente Local (Desenvolvimento)

O ambiente local utiliza Docker Compose para orquestrar toda a stack.

### Pré-requisitos
- Docker Engine (v24+)
- Docker Compose Plugin (v2.20+)
- GNU Make
- Bash
- Curl & Python3 (para scripts de provisionamento do Kong)

### Passo a Passo de Provisionamento

1. **Clonar o repositório:**
   ```bash
   git clone https://github.com/rmaneschy/infra-condohome-sre.git
   cd infra-condohome-sre
   ```

2. **Configurar Variáveis de Ambiente:**
   ```bash
   cp configs/envs/.env.local.example configs/envs/.env.local
   # Edite o arquivo .env.local e preencha chaves de API (OpenAI, Asaas, etc.)
   nano configs/envs/.env.local
   ```

3. **Validar Requisitos:**
   Execute o script de validação para garantir que seu ambiente local tem tudo o que precisa:
   ```bash
   bash scripts/validate-requirements.sh local
   ```

4. **Subir a Infraestrutura Base (PostgreSQL, Redis, Kong):**
   ```bash
   make infra
   ```

5. **Provisionar o Kong Gateway:**
   ```bash
   make kong-provision
   ```

6. **Subir os Microserviços (Backend):**
   ```bash
   make backend
   ```

7. **Subir os Frontends:**
   ```bash
   make frontend
   ```

*(Alternativa rápida: `make full` sobe toda a stack de uma vez, mas é recomendado subir a infra e provisionar o Kong primeiro na primeira execução).*

### Operações Comuns (Local)
- **Ver logs de um serviço:** `make logs SERVICE=billing`
- **Derrubar tudo:** `make stop`
- **Resetar banco de dados e volumes:** `make clean`

---

## 2. Ambiente Cloud VPS (Hostinger / DigitalOcean / Azure)

Para ambientes de produção simples ou staging baseados em máquinas virtuais (VPS).

### Pré-requisitos
- Uma VM com Ubuntu 22.04 LTS ou superior
- Acesso SSH root ou usuário com privilégios sudo
- Domínio apontado para o IP da VM (ex: `api.condohome.com.br`)

### Passo a Passo de Provisionamento

1. **Acessar a VM via SSH:**
   ```bash
   ssh root@seu_ip_aqui
   ```

2. **Executar o Script de Bootstrap:**
   O repositório contém scripts que instalam Docker, Nginx, Certbot e preparam o ambiente.
   Para Hostinger:
   ```bash
   curl -sSL https://raw.githubusercontent.com/rmaneschy/infra-condohome-sre/master/scripts/cloud/hostinger/provision.sh | bash
   ```

3. **Configurar o Ambiente na VM:**
   Após o bootstrap, o diretório `/opt/condohome` será criado.
   ```bash
   cd /opt/condohome
   git clone https://github.com/rmaneschy/infra-condohome-sre.git .
   cp configs/envs/.env.production.example configs/envs/.env.production
   # Preencha as variáveis de produção
   nano configs/envs/.env.production
   ```

4. **Autenticar no GHCR (GitHub Container Registry):**
   Para baixar as imagens privadas:
   ```bash
   echo $CR_PAT | docker login ghcr.io -u SEU_USUARIO --password-stdin
   ```

5. **Subir a Stack:**
   ```bash
   docker compose --env-file configs/envs/.env.production --profile full up -d
   ```

6. **Provisionar o Kong:**
   ```bash
   bash scripts/kong/provision.sh all
   ```

7. **Configurar SSL (Let's Encrypt):**
   ```bash
   certbot --nginx -d api.condohome.com.br -d condohome.com.br
   ```

---

## 3. Ambiente Kubernetes (Staging / Production)

Para ambientes escaláveis utilizando Kubernetes (AKS, DOKS, EKS, etc).

### Pré-requisitos
- Cluster Kubernetes rodando (v1.26+)
- `kubectl` configurado localmente com contexto do cluster
- Ingress Controller (ex: NGINX Ingress) instalado no cluster
- Cert-Manager instalado (para SSL automático)

### Passo a Passo de Provisionamento

1. **Validar Requisitos do Cluster:**
   ```bash
   bash scripts/validate-requirements.sh k8s
   ```

2. **Criar Namespace:**
   ```bash
   kubectl apply -f kubernetes/base/shared/namespace.yaml
   ```

3. **Configurar Secrets:**
   Crie um arquivo local `staging.secrets` (NÃO commite este arquivo) com o formato `CHAVE=VALOR`.
   ```bash
   make k8s-secrets ENV=staging FILE=staging.secrets
   ```

4. **Aplicar a Infraestrutura Base (PostgreSQL, Redis):**
   ```bash
   kubectl apply -k kubernetes/base/shared/
   ```

5. **Aplicar o Overlay do Ambiente:**
   Isso fará o deploy de todos os microserviços com as configurações específicas do ambiente (réplicas, resources, etc).
   ```bash
   # Para Staging
   make k8s-staging
   
   # Para Produção
   make k8s-prod
   ```

6. **Verificar o Status:**
   ```bash
   make k8s-status
   ```

### Operações Comuns (Kubernetes)
- **Ver logs de um pod:** `make k8s-logs POD=billing`
- **Forçar restart de um deployment:** `kubectl rollout restart deployment/condohome-billing -n condohome`
- **Escalar manualmente:** `kubectl scale deployment/condohome-ai-assistant --replicas=3 -n condohome`
