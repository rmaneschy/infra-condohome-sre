# Kong API Gateway - CondoHome Platform

## Visão Geral

O Kong Gateway atua como API Gateway centralizado da plataforma CondoHome, substituindo completamente o Spring Cloud Gateway legado. Ele fornece roteamento, rate limiting, CORS, autenticação, logging, métricas e circuit breaker para todos os microserviços.

## Arquitetura

```text
                    +------------------+
                    |   Portal Web     |
                    |   (port 3000)    |
                    +--------+---------+
                             |
                    +--------v---------+
                    |  Kong Gateway    |
                    |  Proxy: 8000     |
                    |  Admin: 8001     |
                    |  Manager: 8002   |
                    +--------+---------+
                             |
        +--------------------+--------------------+
        |          |         |         |          |
   +----v---+ +---v----+ +--v-----+ +-v------+ +-v--------+
   |Register| |Billing | |Booking | |Finance | |Documents |
   | :8081  | | :8082  | | :8087  | | :8088  | |  :8083   |
   +--------+ +--------+ +--------+ +--------+ +----------+
        |          |         |         |          |
   +----v---+ +---v----+
   |  AI    | |Notific.|
   | :8085  | | :8086  |
   +--------+ +--------+
```

## Integração com Docker Compose

O Kong está definido no `docker-compose.yml` principal **sem profile** (infraestrutura compartilhada), assim como PostgreSQL e Redis. Isso significa que ele é considerado parte da infraestrutura base da plataforma.

- `docker compose up -d` sobe a infra completa: PostgreSQL + Redis + Kong
- `docker compose --profile backend up -d` sobe infra + microserviços
- `docker compose --profile full up -d` sobe tudo (infra + backend + frontend + N8N)
- `make kong-start` sobe apenas os 3 serviços do Kong (kong-database, kong-migrations, kong) e executa o provisionamento
- `make infra` sobe PostgreSQL + Redis + Kong

Os serviços do Kong compartilham a rede `condohome-net` com todos os microserviços, permitindo que as rotas do Kong apontem para os container names (ex: `condohome-register:8081`).

## Configurações Detalhadas

### Portas Expostas

| Serviço | Porta | Descrição |
|---------|-------|-----------|
| Kong Proxy HTTP | 8000 | Porta principal para requisições de clientes |
| Kong Proxy HTTPS | 8443 | Proxy com suporte a SSL/TLS |
| Kong Admin API | 8001 | API de administração (interna) |
| Kong Admin SSL | 8444 | Admin API com SSL |
| Kong Manager GUI | 8002 | Interface web de gerenciamento visual |
| Kong PostgreSQL | 5433 | Banco de dados dedicado do Kong |

### Services e Routes Provisionados

O script `scripts/kong/provision.sh` registra automaticamente os seguintes serviços e rotas na inicialização:

| Service | Route Path | Upstream (Container) |
|---------|-----------|----------|
| register-service | `/api/register` | `condohome-register:8081` |
| billing-service | `/api/billing` | `condohome-billing:8082` |
| documents-service | `/api/documents` | `condohome-documents:8083` |
| ai-assistant-service | `/api/ai` | `condohome-ai-assistant:8085` |
| notification-service | `/api/notification` | `condohome-notification:8086` |
| booking-service | `/api/booking` | `condohome-booking:8087` |
| finance-service | `/api/finance` | `condohome-finance:8088` |

### Plugins Configurados

O Kong utiliza plugins para estender suas funcionalidades. Eles são aplicados globalmente ou por serviço.

#### Plugins Globais

| Plugin | Descrição e Configuração |
|--------|-----------|
| `cors` | Permite requisições de `localhost:3000`, `localhost:5173` e domínios de produção. Expõe headers de paginação. |
| `rate-limiting` | Limita requisições a 120/minuto e 3600/hora por IP. Retorna HTTP 429 se excedido. |
| `request-size-limiting` | Bloqueia payloads maiores que 50MB para evitar ataques de exaustão de recursos. |
| `correlation-id` | Injeta o header `X-Request-ID` (UUID) em todas as requisições para rastreabilidade distribuída. |
| `prometheus` | Expõe métricas de latência, banda e status HTTP no endpoint `/metrics` da Admin API. |
| `bot-detection` | Identifica e bloqueia bots maliciosos conhecidos baseados no User-Agent. |
| `response-transformer` | Remove headers internos (`X-Powered-By`, `Server`) por segurança. |

#### Plugins por Service

| Service | Plugin | Configuração |
|---------|--------|-------------|
| ai-assistant | `rate-limiting` | Mais restritivo: 30 req/min, 500 req/hora (devido a custos de API externa). |
| billing | `request-transformer` | Adiciona header interno `X-Internal-Service:kong-gateway` para validação no backend. |

### Consumers e Autenticação (API Keys)

Consumers representam clientes ou aplicações que consomem a API. O provisionamento cria os seguintes consumers com suporte a autenticação via API Key:

| Consumer | Custom ID | Uso |
|----------|-----------|-----|
| portal-web | portal-web-client | Portal administrativo (React) |
| portaria-app | portaria-app-client | Assistente de portaria |
| n8n-orchestrator | n8n-orchestrator-client | Orquestrador N8N (Automações) |
| mobile-app | mobile-app-client | App mobile (React Native) |

Para ativar a autenticação por API Key em uma rota específica, adicione o plugin `key-auth`:

```bash
curl -X POST http://localhost:8001/routes/register-api/plugins \
  -H "Content-Type: application/json" \
  -d '{"name": "key-auth", "config": {"key_names": ["apikey", "X-API-Key"]}}'
```

## Operacionalização Prática

### 1. Iniciar e Provisionar (Local)

O fluxo padrão para desenvolvimento local é:

```bash
# Inicia a infraestrutura (PostgreSQL, Redis, Kong) e provisiona o Kong
make kong-start
```

O comando acima executa:
1. Sobe o PostgreSQL dedicado do Kong (porta 5433)
2. Executa as migrations do Kong (`kong migrations bootstrap`)
3. Inicia o Kong Gateway
4. Aguarda o Kong ficar saudável
5. Executa `scripts/kong/provision.sh` para registrar services, routes, plugins e consumers.

### 2. Modo Standalone (Kong Isolado)

Para testar o Kong sem subir o resto da infraestrutura do `docker-compose.yml` principal:

```bash
KONG_STANDALONE=true make kong-start
```

Isso utiliza o arquivo `docker/kong/docker-compose.yml` com uma rede externa.

### 3. Comandos de Gerenciamento (Makefile)

| Comando | Descrição |
|---------|-----------|
| `make kong-start` | Iniciar Kong + provisionar tudo |
| `make kong-stop` | Parar Kong Gateway |
| `make kong-restart` | Reiniciar Kong Gateway |
| `make kong-status` | Verificar status dos containers do Kong |
| `make kong-health` | Health check completo (Kong + upstreams) |
| `make kong-logs` | Ver logs do Kong |
| `make kong-provision` | Re-provisionar services, routes e plugins |
| `make kong-reset` | Remover TODAS as configurações do Kong via Admin API |
| `make kong-export` | Exportar configuração atual (requer `deck`) |
| `make kong-shell` | Abrir shell interativo no container do Kong |
| `make kong-clean` | Parar Kong e remover volumes de dados |

### 4. Configuração Declarativa (DB-less)

Para ambientes onde não se deseja usar banco de dados (ex: CI/CD rápido ou edge nodes), existe uma configuração declarativa em `configs/kong/kong.yml`.

Para usar o modo DB-less:
1. Altere o `docker-compose.yml`:
   ```yaml
   environment:
     KONG_DATABASE: "off"
     KONG_DECLARATIVE_CONFIG: /etc/kong/kong.yml
   volumes:
     - ./configs/kong/kong.yml:/etc/kong/kong.yml:ro
   ```
2. Remova os serviços `kong-database` e `kong-migrations`.

## Monitoramento e Health Checks

### Prometheus

O Kong expõe métricas no formato Prometheus no endpoint `/metrics` da Admin API:

```bash
curl http://localhost:8001/metrics
```

### Health Check Automatizado

O repositório inclui um script para validar a saúde de toda a malha de roteamento:

```bash
make kong-health
# ou
bash scripts/kong/healthcheck.sh
```

Este script verifica:
1. Disponibilidade da Kong Admin API
2. Disponibilidade do Kong Proxy
3. Cada microserviço através do proxy (acessando `/api/{service}/actuator/health`)

## Variáveis de Ambiente

As seguintes variáveis devem estar presentes no seu `.env.local` (ou `.env.production`):

```bash
# --- Kong Gateway ---
KONG_VERSION=3.9
KONG_PROXY_PORT=8000
KONG_PROXY_SSL_PORT=8443
KONG_ADMIN_PORT=8001
KONG_ADMIN_SSL_PORT=8444
KONG_ADMIN_GUI_PORT=8002
KONG_PG_PORT=5433
KONG_PG_USER=kong
KONG_PG_PASSWORD=kong123
KONG_PG_DATABASE=kong
KONG_LOG_LEVEL=info

# --- Kong API Keys (produção) ---
KONG_PORTAL_API_KEY=sua_chave_segura_aqui
KONG_PORTARIA_API_KEY=sua_chave_segura_aqui
KONG_N8N_API_KEY=sua_chave_segura_aqui
KONG_MOBILE_API_KEY=sua_chave_segura_aqui
```

## Troubleshooting

### Kong não inicia ou fica em "restarting"

**Causa comum:** A porta 5433 (PostgreSQL do Kong) ou 8000/8001 já está em uso.
**Solução:**
```bash
# Verificar logs
make kong-logs

# Verificar portas em uso
lsof -i :5433
lsof -i :8000

# Recriar do zero (apaga dados)
make kong-clean
make kong-start
```

### Rotas retornam 404 Not Found

**Causa comum:** O provisionamento não rodou ou falhou.
**Solução:**
```bash
# Verificar se os services estão registrados
curl -s http://localhost:8001/services | grep name

# Rodar o provisionamento manualmente
make kong-provision
```

### Rate limiting muito restritivo (Erro 429)

**Causa comum:** O limite global de 120 req/min foi atingido durante testes de carga.
**Solução:**
Ajustar via Admin API:
```bash
curl -X PATCH http://localhost:8001/plugins/{plugin-id} \
  -H "Content-Type: application/json" \
  -d '{"config": {"minute": 300}}'
```
*(Você pode obter o `{plugin-id}` acessando `http://localhost:8001/plugins`)*
