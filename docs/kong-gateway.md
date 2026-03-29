# Kong API Gateway - CondoHome Platform

## Visao Geral

O Kong Gateway atua como API Gateway centralizado da plataforma CondoHome, substituindo (ou complementando) o Spring Cloud Gateway. Ele fornece roteamento, rate limiting, CORS, autenticacao, logging, metricas e circuit breaker para todos os microservicos.

## Arquitetura

```
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

## Quick Start

### 1. Iniciar Kong (integrado com microservicos)

O Kong faz parte do `docker-compose.yml` principal (projeto `condohome-platform`), na mesma rede `condohome-net` dos microservicos. Isso permite que o Kong resolva os nomes dos containers diretamente.

```bash
# Iniciar Kong + provisionar (recomendado)
make kong-start

# Ou subir tudo junto (infra + backend + Kong)
make backend

# Ou subir a plataforma completa
make full
```

O `make kong-start` executa:
1. Sobe o PostgreSQL dedicado do Kong (porta 5433)
2. Executa as migrations do Kong
3. Inicia o Kong Gateway
4. Provisiona services, routes, plugins e consumers

### Modo Standalone (Kong isolado)

Para testar o Kong sem subir os microservicos:

```bash
KONG_STANDALONE=true make kong-start
```

Isso usa o compose em `docker/kong/docker-compose.yml` com rede externa.

### 2. Verificar status

```bash
make kong-status
make kong-health
```

### 3. Parar Kong

```bash
make kong-stop
```

## Comandos Makefile

| Comando | Descricao |
|---------|-----------|
| `make kong-start` | Iniciar Kong + provisionar tudo |
| `make kong-stop` | Parar Kong Gateway |
| `make kong-restart` | Reiniciar Kong Gateway |
| `make kong-status` | Verificar status dos containers |
| `make kong-health` | Health check completo (Kong + services) |
| `make kong-logs` | Ver logs do Kong |
| `make kong-provision` | Re-provisionar services, routes e plugins |
| `make kong-reset` | Remover TODAS as configuracoes |
| `make kong-export` | Exportar configuracao atual |
| `make kong-shell` | Abrir shell no container do Kong |
| `make kong-clean` | Parar e remover volumes |

## Portas

| Servico | Porta | Descricao |
|---------|-------|-----------|
| Kong Proxy HTTP | 8000 | Porta principal para requisicoes |
| Kong Proxy HTTPS | 8443 | Proxy com SSL |
| Kong Admin API | 8001 | API de administracao |
| Kong Admin SSL | 8444 | Admin API com SSL |
| Kong Manager GUI | 8002 | Interface web de gerenciamento |
| Kong PostgreSQL | 5433 | Banco dedicado do Kong |

## Services e Routes

Todos os microservicos sao registrados automaticamente pelo script de provisionamento:

| Service | Route Path | Upstream |
|---------|-----------|----------|
| register-service | `/api/register` | `condohome-register:8081` |
| billing-service | `/api/billing` | `condohome-billing:8082` |
| documents-service | `/api/documents` | `condohome-documents:8083` |
| ai-assistant-service | `/api/ai` | `condohome-ai-assistant:8085` |
| notification-service | `/api/notification` | `condohome-notification:8086` |
| booking-service | `/api/booking` | `condohome-booking:8087` |
| finance-service | `/api/finance` | `condohome-finance:8088` |

## Plugins

### Plugins Globais

| Plugin | Descricao |
|--------|-----------|
| `cors` | CORS com origens permitidas (localhost:3000, localhost:5173, condohome.com.br) |
| `rate-limiting` | 120 req/min, 3600 req/hora (global) |
| `request-size-limiting` | Maximo 50MB por requisicao |
| `correlation-id` | Header `X-Request-ID` para rastreamento |
| `prometheus` | Metricas para monitoramento |
| `bot-detection` | Deteccao de bots maliciosos |
| `response-transformer` | Remove headers internos (X-Powered-By, Server) |

### Plugins por Service

| Service | Plugin | Configuracao |
|---------|--------|-------------|
| ai-assistant | `rate-limiting` | 30 req/min, 500 req/hora (mais restritivo) |
| billing | `request-transformer` | Adiciona header `X-Internal-Service` |

## Consumers e Autenticacao

Consumers pre-configurados para autenticacao via API Key:

| Consumer | Custom ID | Uso |
|----------|-----------|-----|
| portal-web | portal-web-client | Portal administrativo |
| portaria-app | portaria-app-client | Assistente de portaria |
| n8n-orchestrator | n8n-orchestrator-client | Orquestrador N8N |
| mobile-app | mobile-app-client | App mobile (React Native) |

Para ativar autenticacao por API Key em uma rota, adicione o plugin `key-auth`:

```bash
curl -X POST http://localhost:8001/routes/register-api/plugins \
  -H "Content-Type: application/json" \
  -d '{"name": "key-auth", "config": {"key_names": ["apikey", "X-API-Key"]}}'
```

## Configuracao Declarativa (DB-less)

Para ambientes onde nao se deseja usar banco de dados, existe uma configuracao declarativa em `configs/kong/kong.yml`. Para usar:

1. Altere no docker-compose:
   ```yaml
   environment:
     KONG_DATABASE: "off"
     KONG_DECLARATIVE_CONFIG: /etc/kong/kong.yml
   volumes:
     - ../../configs/kong/kong.yml:/etc/kong/kong.yml:ro
   ```

2. Remova os services `kong-database` e `kong-migrations`

## Variaveis de Ambiente

Adicione ao seu `.env.local`:

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

# --- Kong API Keys (producao) ---
KONG_PORTAL_API_KEY=
KONG_PORTARIA_API_KEY=
KONG_N8N_API_KEY=
KONG_MOBILE_API_KEY=
```

## Monitoramento

### Prometheus

O Kong expoe metricas no endpoint `/metrics` da Admin API:

```bash
curl http://localhost:8001/metrics
```

### Health Check Automatizado

```bash
bash scripts/kong/healthcheck.sh
```

Este script verifica:
- Kong Admin API
- Kong Proxy
- Cada microservico via proxy (actuator/health)

## Integracao com Docker Compose

O Kong esta definido no `docker-compose.yml` principal com os profiles `backend` e `full`:

- `docker compose --profile backend up -d` sobe infra + Kong + microservicos
- `docker compose --profile full up -d` sobe tudo (infra + Kong + backend + frontend + N8N)
- `make kong-start` sobe apenas os 3 servicos do Kong (kong-database, kong-migrations, kong)

Os servicos do Kong compartilham a rede `condohome-net` com todos os microservicos, permitindo que as rotas do Kong apontem para os container names (ex: `condohome-register:8081`).

## Producao

Para producao, considere:

1. **SSL/TLS**: Configure certificados no Kong ou use um load balancer externo
2. **Rate Limiting com Redis**: Mude `policy` de `local` para `redis` e configure o Redis
3. **API Keys**: Gere chaves seguras e armazene como secrets
4. **IP Restriction**: Ative o plugin para restringir IPs de origem
5. **Logging**: Configure o plugin `file-log` ou `http-log` para enviar logs para um agregador
6. **Backup**: Exporte a configuracao periodicamente com `make kong-export`

## Troubleshooting

### Kong nao inicia

```bash
# Verificar logs
make kong-logs

# Verificar se a porta 5433 esta livre
lsof -i :5433

# Recriar do zero
make kong-clean
make kong-start
```

### Routes nao funcionam

```bash
# Verificar se os services estao registrados
curl http://localhost:8001/services | python3 -m json.tool

# Verificar se as routes estao corretas
curl http://localhost:8001/routes | python3 -m json.tool

# Testar diretamente via proxy
curl -v http://localhost:8000/api/register/actuator/health
```

### Rate limiting muito restritivo

```bash
# Verificar headers de rate limit na resposta
curl -v http://localhost:8000/api/register/actuator/health 2>&1 | grep -i ratelimit

# Ajustar via Admin API
curl -X PATCH http://localhost:8001/plugins/{plugin-id} \
  -H "Content-Type: application/json" \
  -d '{"config": {"minute": 300}}'
```
