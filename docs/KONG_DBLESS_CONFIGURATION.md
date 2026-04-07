# Kong Gateway - Configuração DB-less

## Visão Geral

O Kong Gateway foi migrado de um modelo **DB-backed** (com PostgreSQL) para um modelo **DB-less** (sem banco de dados). Esta mudança simplifica a operacionalização, reduz complexidade de infraestrutura e melhora o desempenho em ambientes de desenvolvimento e staging.

**Data da Migração:** 2026-04-07  
**Desenvolvido por:** Debug Software

---

## Arquitetura Anterior vs. Nova

### Antes (DB-backed)

```
Kong Container
    ↓
PostgreSQL (kong-database)
    ↓
Services, Routes, Plugins, Consumers armazenados no banco
```

**Problemas:**
- Requer PostgreSQL dedicado apenas para Kong
- Necessário executar migrations (`kong migrations bootstrap`)
- Provisionamento em duas etapas (migrations + provision.sh)
- Difícil de versionar configurações (estavam no banco)
- Sincronização manual entre ambientes

### Depois (DB-less)

```
Kong Container
    ↓
kong.yml (arquivo declarativo)
    ↓
Services, Routes, Plugins, Consumers carregados do arquivo
```

**Benefícios:**
- Sem dependência de PostgreSQL para Kong
- Configuração versionada no Git (`configs/kong/kong.yml`)
- Provisionamento em uma única etapa (carrega o arquivo)
- Fácil replicação entre ambientes
- Melhor para CI/CD e Infrastructure as Code

---

## Arquivos de Configuração

### 1. `configs/kong/kong.conf`

Arquivo de configuração centralizado do Kong. Define parâmetros globais como portas, logging, plugins e o caminho para o arquivo declarativo.

```conf
# Database
database = off
declarative_config = /etc/kong/kong.yml

# Proxy
proxy_listen = 0.0.0.0:8000, 0.0.0.0:8443 ssl
admin_listen = 0.0.0.0:8001, 0.0.0.0:8444 ssl
admin_gui_listen = 0.0.0.0:8002

# Logging
proxy_access_log = /dev/stdout
admin_access_log = /dev/stdout
proxy_error_log = /dev/stderr
admin_error_log = /dev/stderr
log_level = info

# Plugins
plugins = bundled

# DNS
dns_resolver = 127.0.0.11:53

# Security
trusted_ips = 0.0.0.0/0,::/0
real_ip_header = X-Forwarded-For
real_ip_recursive = on
```

**Variáveis de Ambiente Importantes:**

| Variável | Valor | Descrição |
|---|---|---|
| `KONG_DATABASE` | `off` | Ativa modo DB-less |
| `KONG_DECLARATIVE_CONFIG` | `/etc/kong/kong.yml` | Caminho do arquivo de configuração |
| `KONG_LOG_LEVEL` | `info` | Nível de logging |
| `KONG_PLUGINS` | `bundled` | Plugins inclusos no Kong |

### 2. `configs/kong/kong.yml`

Arquivo declarativo que define toda a configuração do Kong: services, routes, plugins globais, plugins por serviço e consumers.

**Estrutura Principal:**

```yaml
_format_version: "3.0"
_transform: true

services:
  - name: register-service
    url: http://condohome-register:8081
    routes:
      - name: register-route
        paths:
          - /api/register

plugins:
  - name: cors
    config:
      origins:
        - http://localhost:3000
        - https://condohome.com.br

consumers:
  - username: portal-web
    keyauth_credentials:
      - key: ${KONG_PORTAL_API_KEY:-condohome-portal-key}
```

---

## Docker Compose

### Configuração Principal (`docker-compose.yml`)

O serviço Kong agora monta os arquivos de configuração como volumes:

```yaml
kong:
  image: kong:${KONG_VERSION:-3.9}
  container_name: condohome-kong
  environment:
    KONG_DATABASE: "off"
    KONG_DECLARATIVE_CONFIG: /etc/kong/kong.yml
    KONG_PROXY_LISTEN: 0.0.0.0:8000, 0.0.0.0:8443 ssl
    KONG_ADMIN_LISTEN: 0.0.0.0:8001, 0.0.0.0:8444 ssl
    KONG_ADMIN_GUI_LISTEN: 0.0.0.0:8002
    KONG_PLUGINS: bundled
  volumes:
    - ./configs/kong/kong.conf:/etc/kong/kong.conf
    - ./configs/kong/kong.yml:/etc/kong/kong.yml
  ports:
    - "${KONG_PROXY_PORT:-8000}:8000"
    - "${KONG_ADMIN_PORT:-8001}:8001"
    - "${KONG_ADMIN_GUI_PORT:-8002}:8002"
  networks:
    - condohome-net
  healthcheck:
    test: ["CMD", "kong", "health"]
    interval: 15s
    timeout: 10s
    retries: 5
    start_period: 30s
  restart: unless-stopped
```

**Mudanças Principais:**

- ✅ Removido `kong-database` (PostgreSQL dedicado)
- ✅ Removido `kong-migrations` (não necessário)
- ✅ Adicionado volumes para `kong.conf` e `kong.yml`
- ✅ Definido `KONG_DATABASE: "off"`
- ✅ Removido `depends_on` (não há dependências)

---

## Scripts de Operacionalização

### Validação de Migrações (`scripts/kong/validate-migrations.sh`)

Atualizado para validar a configuração DB-less:

```bash
# Antes
validate_kong_database()  # Verificava PostgreSQL

# Depois
validate_kong_database()  # Apenas confirma modo DB-less
```

**Execução:**

```bash
bash scripts/kong/validate-migrations.sh
```

**Saída Esperada:**

```
✓ Kong Admin API está respondendo
✓ Kong configurado em modo DB-less (KONG_DATABASE=off)
✓ Service 'register-service' encontrado
✓ Route 'register-api' encontrada
✓ Plugin 'cors' está configurado
✓ Consumer 'portal-web' encontrado
✓ Kong Proxy está respondendo corretamente
✓ Todas as validações passaram!
```

### Provisionamento (`scripts/kong/provision.sh`)

O script de provisionamento agora **não é mais necessário** em modo DB-less, pois a configuração é carregada diretamente do arquivo `kong.yml`.

**Uso (se necessário para atualizar configurações):**

```bash
# Não mais necessário em modo DB-less
# Mas mantido para compatibilidade com modo DB-backed
bash scripts/kong/provision.sh all
```

---

## Fluxo de Operacionalização

### Desenvolvimento Local

```bash
# 1. Validar requisitos
make validate

# 2. Subir infraestrutura (Kong + PostgreSQL + Redis)
make infra

# 3. Validar configuração do Kong
bash scripts/kong/validate-migrations.sh

# 4. Kong já está pronto para usar!
# Não é necessário executar provision.sh
```

### Atualizar Configuração

Se precisar adicionar/modificar services, routes ou plugins:

1. **Editar `configs/kong/kong.yml`**
2. **Reiniciar Kong:**

```bash
make kong-restart
```

3. **Validar:**

```bash
bash scripts/kong/validate-migrations.sh
```

---

## Versionamento e Git

### Fluxo de Trabalho

```bash
# 1. Fazer alterações em configs/kong/kong.yml
nano configs/kong/kong.yml

# 2. Testar localmente
make kong-restart
bash scripts/kong/validate-migrations.sh

# 3. Commitar com conventional commits
git add configs/kong/kong.yml
git commit -m "feat(kong): adicionar nova rota para finance-service"

# 4. Push
git push origin feature/kong-finance-route
```

### Exemplo de Commit

```
feat(kong): adicionar rota para finance-service

- Adiciona service finance-service apontando para http://condohome-finance:8088
- Cria route finance-api com path /api/finance
- Configura rate-limiting específico para finance (100 req/min)
- Adiciona documentação em KONG_DBLESS_CONFIGURATION.md

Closes #123
```

---

## Comparação: DB-backed vs. DB-less

| Aspecto | DB-backed | DB-less |
|---|---|---|
| **Banco de Dados** | PostgreSQL (kong-database) | Nenhum |
| **Arquivo de Config** | Não versionado | Versionado (kong.yml) |
| **Migrations** | Necessário (`kong migrations bootstrap`) | Não necessário |
| **Provisionamento** | 2 etapas (migrations + provision) | 1 etapa (carrega arquivo) |
| **Restart** | Rápido | Rápido |
| **Escalabilidade** | Horizontal (múltiplas instâncias) | Horizontal (múltiplas instâncias) |
| **Ambiente Local** | Mais complexo | Mais simples |
| **CI/CD** | Difícil de versionar | Fácil (tudo no Git) |
| **Produção** | Recomendado | Alternativa viável |

---

## Troubleshooting

### Kong não inicia

**Erro:** `KONG_DECLARATIVE_CONFIG file not found`

**Solução:**

```bash
# Verificar se o arquivo existe
ls -la configs/kong/kong.yml

# Verificar permissões
chmod 644 configs/kong/kong.yml

# Reiniciar Kong
make kong-restart
```

### Rotas não aparecem

**Erro:** Routes não aparecem na validação

**Solução:**

1. Verificar se `kong.yml` está bem formado:

```bash
# Validar YAML
python3 -c "import yaml; yaml.safe_load(open('configs/kong/kong.yml'))"
```

2. Verificar logs do Kong:

```bash
make kong-logs
```

3. Recarregar configuração:

```bash
make kong-restart
```

### Admin API não responde

**Erro:** `Kong Admin API não está respondendo`

**Solução:**

```bash
# Verificar se Kong está rodando
docker ps | grep kong

# Verificar health
curl http://localhost:8001/status

# Reiniciar
make kong-restart
```

---

## Migração de DB-backed para DB-less

Se você tem uma instalação anterior com DB-backed:

### Passo 1: Exportar Configuração Atual

```bash
# Exportar via Admin API
bash scripts/kong/provision.sh export > configs/kong/kong-backup.yml
```

### Passo 2: Converter para Declarativo

O arquivo exportado pode precisar de ajustes para o formato declarativo. Exemplo:

```yaml
# Formato exportado (Admin API)
{
  "data": [
    {
      "id": "...",
      "name": "register-service",
      "url": "http://..."
    }
  ]
}

# Formato declarativo (kong.yml)
services:
  - name: register-service
    url: http://...
```

### Passo 3: Atualizar Docker Compose

Seguir as mudanças descritas na seção "Docker Compose" acima.

### Passo 4: Testar

```bash
make infra
bash scripts/kong/validate-migrations.sh
```

---

## Referências

- [Kong Official Documentation - DB-less](https://docs.konghq.com/gateway/latest/production/deployment-topologies/db-less-and-declarative-config/)
- [Kong Declarative Configuration](https://docs.konghq.com/gateway/latest/reference/declarative-config/)
- [Kong Configuration Reference](https://docs.konghq.com/gateway/latest/reference/configuration/)

---

## Suporte

Para dúvidas ou problemas:

1. Consulte [docs/kong-gateway.md](kong-gateway.md) para documentação detalhada
2. Verifique [docs/operationalization.md](operationalization.md) para operacionalização
3. Abra uma issue no repositório com logs e contexto
