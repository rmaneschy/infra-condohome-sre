# Kong Gateway - Configuração Completa do CondoHome Platform

**Versão:** 1.0  
**Data:** 05 de Abril de 2026  
**Autor:** Debug Software  
**Status:** Documentação Oficial

---

## Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura do Kong](#arquitetura-do-kong)
3. [Configuração de Services](#configuração-de-services)
4. [Configuração de Routes](#configuração-de-routes)
5. [Plugins Globais](#plugins-globais)
6. [Plugins por Service](#plugins-por-service)
7. [Consumers e Autenticação](#consumers-e-autenticação)
8. [Operacionalização](#operacionalização)
9. [Troubleshooting](#troubleshooting)

---

## Visão Geral

O **Kong Gateway** é um API Gateway de código aberto que funciona como ponto de entrada único para todos os microserviços do CondoHome Platform. Ele fornece roteamento inteligente, autenticação, rate limiting, CORS, logging e muito mais.

### Benefícios da Adoção do Kong

| Benefício | Descrição |
|---|---|
| **Roteamento Inteligente** | Direciona requisições para o microserviço correto baseado em paths, métodos HTTP e headers |
| **Segurança** | Plugins de autenticação, rate limiting, IP restriction e proteção contra bots |
| **Performance** | Caching, compressão e otimização de requisições |
| **Observabilidade** | Métricas Prometheus, logging estruturado e correlation IDs |
| **Escalabilidade** | Suporta múltiplas instâncias do Kong em cluster |
| **Flexibilidade** | Plugins customizáveis e configuração declarativa |

### Componentes do Kong

```
┌─────────────────────────────────────────────────────────┐
│                    Kong Gateway                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │          Proxy (Porta 8000/8443)                │  │
│  │  - Recebe requisições dos clientes              │  │
│  │  - Aplica plugins (CORS, rate-limit, etc)       │  │
│  │  - Roteia para o microserviço correto           │  │
│  └──────────────────────────────────────────────────┘  │
│                          ↓                              │
│  ┌──────────────────────────────────────────────────┐  │
│  │          Admin API (Porta 8001/8444)            │  │
│  │  - Gerencia Services, Routes, Plugins           │  │
│  │  - Usado por scripts de provisionamento         │  │
│  └──────────────────────────────────────────────────┘  │
│                          ↓                              │
│  ┌──────────────────────────────────────────────────┐  │
│  │          Kong Manager (Porta 8002)              │  │
│  │  - Interface Web para gerenciamento             │  │
│  │  - Dashboard e visualização de métricas         │  │
│  └──────────────────────────────────────────────────┘  │
│                          ↓                              │
│  ┌──────────────────────────────────────────────────┐  │
│  │          PostgreSQL Database                    │  │
│  │  - Armazena configuração do Kong                │  │
│  │  - Persiste dados de plugins e consumers        │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Arquitetura do Kong

### Entidades Principais

O Kong utiliza as seguintes entidades para configurar o roteamento:

#### 1. **Service**

Um Service representa um microserviço backend. Cada service define:

- **Nome único** para identificação
- **URL do backend** (host:port)
- **Timeouts** de conexão, leitura e escrita
- **Retry policy** para falhas
- **Protocolo** (HTTP/HTTPS)

**Exemplo:**
```yaml
services:
  - name: register-service
    url: http://condohome-register:8081
    connect_timeout: 10000
    write_timeout: 30000
    read_timeout: 30000
    retries: 3
```

#### 2. **Route**

Uma Route define como as requisições chegam ao Kong e são roteadas para um Service.

- **Paths**: URLs que a rota aceita (ex: `/api/register`)
- **Methods**: Métodos HTTP permitidos (GET, POST, PUT, DELETE, etc)
- **Protocols**: HTTP, HTTPS, gRPC, etc
- **Strip Path**: Remove o path da rota ao encaminhar para o backend
- **Preserve Host**: Mantém o header Host original

**Exemplo:**
```yaml
routes:
  - name: register-route
    paths:
      - /api/register
    strip_path: false
    preserve_host: false
    protocols:
      - http
      - https
```

#### 3. **Plugin**

Plugins adicionam funcionalidades ao Kong:

- **Escopo Global**: Aplica-se a todas as requisições
- **Escopo de Service**: Aplica-se apenas a um service específico
- **Escopo de Route**: Aplica-se apenas a uma rota específica
- **Escopo de Consumer**: Aplica-se apenas a um consumer específico

**Exemplo:**
```yaml
plugins:
  - name: cors
    config:
      origins:
        - http://localhost:3000
        - https://condohome.com.br
      methods:
        - GET
        - POST
        - PUT
        - DELETE
```

#### 4. **Consumer**

Um Consumer representa um cliente que acessa as APIs (aplicação web, app mobile, etc).

- **Username**: Identificador único
- **Custom ID**: ID externo para rastreamento
- **Credenciais**: API keys, OAuth tokens, etc

**Exemplo:**
```yaml
consumers:
  - username: portal-web
    custom_id: portal-web-client
    keyauth_credentials:
      - key: condohome-portal-key
```

---

## Configuração de Services

### Services do CondoHome Platform

O projeto utiliza os seguintes microserviços:

| Service | Porta | Path | Timeout Leitura | Descrição |
|---|---|---|---|---|
| `register-service` | 8081 | `/api/register` | 30s | Gestão de unidades, blocos, pessoas e perfis |
| `billing-service` | 8082 | `/api/billing` | 30s | Cobrança, taxa condominial e PIX |
| `documents-service` | 8083 | `/api/documents` | 30s | Atas, regimento, convenção, balancetes |
| `ai-assistant-service` | 8085 | `/api/ai` | 60s | Assistente IA com RAG e guardrails |
| `notification-service` | 8086 | `/api/notification` | 30s | WhatsApp, email, push notifications |
| `booking-service` | 8087 | `/api/booking` | 30s | Reserva de espaços (churrasqueira, piscina, etc) |
| `finance-service` | 8088 | `/api/finance` | 30s | Prestação de contas, centros de custo |

### Configuração de Timeouts

Os timeouts são críticos para evitar travamentos:

```yaml
connect_timeout: 10000    # 10 segundos para conectar
write_timeout: 30000      # 30 segundos para enviar dados
read_timeout: 30000       # 30 segundos para receber resposta
```

**Exceções:**
- **AI Assistant**: `read_timeout: 60000` (60s) - Processamento de IA é mais lento
- **Booking**: Pode precisar de timeout maior em períodos de pico

### Retry Policy

O Kong tenta novamente em caso de falha:

```yaml
retries: 3  # Tenta até 3 vezes
```

---

## Configuração de Routes

### Padrão de Rotas

Todas as rotas seguem o padrão `/api/<servico>`:

```
GET    /api/register/units
POST   /api/billing/charges
PUT    /api/documents/statutes
DELETE /api/booking/reservations
```

### Strip Path vs Preserve Host

#### Strip Path = false (Padrão)

O path é **mantido** ao encaminhar para o backend:

```
Cliente:  GET /api/register/units
Kong:     GET /api/register/units  → Backend
```

#### Strip Path = true

O path é **removido** ao encaminhar:

```
Cliente:  GET /api/register/units
Kong:     GET /units  → Backend (se strip_path: true)
```

**Recomendação:** Manter `strip_path: false` para consistência.

---

## Plugins Globais

Os plugins globais aplicam-se a **todas as requisições** que passam pelo Kong.

### 1. CORS (Cross-Origin Resource Sharing)

Permite que aplicações web em diferentes domínios acessem as APIs.

```yaml
plugins:
  - name: cors
    config:
      origins:
        - http://localhost:3000          # Frontend local
        - http://localhost:5173          # Vite dev server
        - https://condohome.com.br       # Produção
        - https://portaria.condohome.com.br  # Portaria
      methods:
        - GET
        - POST
        - PUT
        - PATCH
        - DELETE
        - OPTIONS
        - HEAD
      headers:
        - Accept
        - Accept-Version
        - Authorization
        - Content-Length
        - Content-Type
        - X-Requested-With
        - X-Condominium-Id
        - X-Unit-Id
      exposed_headers:
        - X-Auth-Token
        - X-Total-Count
        - X-Page-Number
        - X-Page-Size
      credentials: true
      max_age: 3600
      preflight_continue: false
```

### 2. Rate Limiting

Limita o número de requisições por cliente para evitar abuso.

```yaml
plugins:
  - name: rate-limiting
    config:
      minute: 120        # 120 requisições por minuto
      hour: 3600         # 3600 requisições por hora
      policy: local      # Política local (sem Redis)
      fault_tolerant: true  # Continua se Kong falhar
      error_code: 429    # Código HTTP de limite excedido
      error_message: "Limite de requisições excedido. Tente novamente mais tarde."
```

### 3. Request Size Limiting

Limita o tamanho de payloads para evitar ataques de negação de serviço.

```yaml
plugins:
  - name: request-size-limiting
    config:
      allowed_payload_size: 50  # 50 MB
      size_unit: megabytes
      require_content_length: false
```

### 4. Correlation ID

Adiciona um ID único a cada requisição para rastreamento em logs.

```yaml
plugins:
  - name: correlation-id
    config:
      header_name: X-Request-ID
      generator: uuid#counter
      echo_downstream: true  # Retorna o ID na resposta
```

### 5. Prometheus Metrics

Coleta métricas para monitoramento e observabilidade.

```yaml
plugins:
  - name: prometheus
    config:
      status_code_metrics: true
      latency_metrics: true
      bandwidth_metrics: true
      upstream_health_metrics: true
```

### 6. Bot Detection

Detecta e bloqueia requisições de bots maliciosos.

```yaml
plugins:
  - name: bot-detection
    config:
      deny: []  # Vazio = permite todos (configurar em produção)
```

### 7. Response Transformer

Remove headers internos para não expor informações sensíveis.

```yaml
plugins:
  - name: response-transformer
    config:
      remove:
        headers:
          - X-Powered-By
          - Server
```

---

## Plugins por Service

### AI Assistant Service - Rate Limiting Restritivo

O serviço de IA é mais caro computacionalmente, então tem limite menor:

```yaml
plugins:
  - name: rate-limiting
    service: ai-assistant-service
    config:
      minute: 30         # 30 requisições por minuto (vs 120 global)
      hour: 500          # 500 requisições por hora
      policy: local
      fault_tolerant: true
      error_code: 429
      error_message: "Limite de requisições do assistente IA excedido."
```

### Billing Service - Request Transformer

Adiciona headers de segurança para requisições de cobrança:

```yaml
plugins:
  - name: request-transformer
    service: billing-service
    config:
      add:
        headers:
          - X-Internal-Service:kong-gateway
```

---

## Consumers e Autenticação

### Consumers Configurados

O Kong define os seguintes consumers (clientes autorizados):

```yaml
consumers:
  - username: portal-web
    custom_id: portal-web-client
    keyauth_credentials:
      - key: ${KONG_PORTAL_API_KEY:-condohome-portal-key}

  - username: portaria-app
    custom_id: portaria-app-client
    keyauth_credentials:
      - key: ${KONG_PORTARIA_API_KEY:-condohome-portaria-key}

  - username: n8n-orchestrator
    custom_id: n8n-orchestrator-client
    keyauth_credentials:
      - key: ${KONG_N8N_API_KEY:-condohome-n8n-key}

  - username: mobile-app
    custom_id: mobile-app-client
    keyauth_credentials:
      - key: ${KONG_MOBILE_API_KEY:-condohome-mobile-key}
```

### Autenticação com API Key

Para usar a API, o cliente deve enviar a API key no header:

```bash
curl -X GET http://localhost:8000/api/register/units \
  -H "apikey: condohome-portal-key"
```

### Variáveis de Ambiente

As API keys são configuradas via variáveis de ambiente:

```bash
export KONG_PORTAL_API_KEY="seu-portal-key"
export KONG_PORTARIA_API_KEY="seu-portaria-key"
export KONG_N8N_API_KEY="seu-n8n-key"
export KONG_MOBILE_API_KEY="seu-mobile-key"
```

---

## Operacionalização

### Iniciar o Kong

#### 1. Usando Docker Compose

```bash
docker compose up -d kong kong-database
```

#### 2. Usando Script de Provisionamento

```bash
# Provisionar tudo (services, routes, plugins, consumers)
./scripts/kong/provision.sh all

# Ou provisionar partes específicas
./scripts/kong/provision.sh services
./scripts/kong/provision.sh routes
./scripts/kong/provision.sh plugins
./scripts/kong/provision.sh consumers
```

### Verificar Status do Kong

```bash
# Verificar se Kong está rodando
curl http://localhost:8001/status

# Listar services
curl http://localhost:8001/services

# Listar routes
curl http://localhost:8001/routes

# Listar plugins
curl http://localhost:8001/plugins

# Listar consumers
curl http://localhost:8001/consumers
```

### Acessar Kong Manager (UI)

Abra no navegador:

```
http://localhost:8002
```

### Exportar Configuração

```bash
# Exportar como YAML (usando deck)
./scripts/kong/provision.sh export

# Exportar via Admin API
curl http://localhost:8001/services > services.json
curl http://localhost:8001/routes > routes.json
curl http://localhost:8001/plugins > plugins.json
```

### Resetar Configuração (CUIDADO!)

```bash
# Remove TODAS as configurações
./scripts/kong/provision.sh reset
```

---

## Troubleshooting

### Kong não responde

**Sintoma:** `curl: (7) Failed to connect to localhost port 8001`

**Solução:**
```bash
# Verificar se Kong está rodando
docker ps | grep kong

# Reiniciar Kong
docker restart condohome-kong

# Verificar logs
docker logs condohome-kong
```

### Erro ao criar route: "Cannot parse JSON body"

**Sintoma:** `{"message":"Cannot parse JSON body"}`

**Solução:**
```bash
# Verificar sintaxe JSON do script
# Certifique-se de que arrays estão com formato correto:
# ✓ Correto:   '[\"/api/register\"]'
# ✗ Incorreto: '[/api/register]'

# Testar manualmente
curl -X PUT http://localhost:8001/services/register-service/routes/register-route \
  -H "Content-Type: application/json" \
  -d '{
    "name": "register-route",
    "paths": ["/api/register"],
    "strip_path": false,
    "protocols": ["http", "https"]
  }'
```

### Rate limiting não funciona

**Sintoma:** Requisições não são limitadas mesmo com plugin configurado

**Solução:**
```bash
# Verificar se plugin está ativo
curl http://localhost:8001/plugins | grep rate-limiting

# Testar rate limiting
for i in {1..150}; do
  curl -s http://localhost:8000/api/register/units
done

# Deve retornar 429 após 120 requisições
```

### CORS não funciona

**Sintoma:** Erro `Access-Control-Allow-Origin` no navegador

**Solução:**
```bash
# Verificar se plugin CORS está ativo
curl http://localhost:8001/plugins | grep cors

# Testar preflight request
curl -X OPTIONS http://localhost:8000/api/register/units \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET" \
  -v

# Deve retornar headers Access-Control-*
```

### Microserviço não responde

**Sintoma:** `502 Bad Gateway`

**Solução:**
```bash
# Verificar se microserviço está rodando
docker ps | grep condohome-register

# Verificar conectividade do Kong para o microserviço
docker exec condohome-kong curl -v http://condohome-register:8081/health

# Verificar logs do microserviço
docker logs condohome-register

# Verificar configuração do service
curl http://localhost:8001/services/register-service
```

---

## Referências

- [Kong Gateway Documentation](https://docs.konghq.com/gateway/)
- [Kong Admin API](https://docs.konghq.com/gateway/latest/admin-api/)
- [Kong Plugins](https://docs.konghq.com/hub/)
- [decK - Declarative Configuration](https://docs.konghq.com/deck/)
- [Kong Manager](https://docs.konghq.com/gateway/latest/kong-manager/)

---

## Contato e Suporte

Para dúvidas ou problemas com Kong Gateway, entre em contato com a equipe de SRE.

**Autor:** Debug Software  
**Última Atualização:** 05 de Abril de 2026

