#!/bin/bash
# =====================================================
# CondoHome Platform - Kong Migrations Validator
# Valida se as migrations do Kong foram executadas
# e se as configurações estão corretas
# =====================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

KONG_ADMIN_URL="${KONG_ADMIN_URL:-http://localhost:8001}"
KONG_PG_HOST="${KONG_PG_HOST:-localhost}"
KONG_PG_PORT="${KONG_PG_PORT:-5433}"
KONG_PG_USER="${KONG_PG_USER:-kong}"
KONG_PG_DATABASE="${KONG_PG_DATABASE:-kong}"

EXIT_CODE=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${CYAN}========================================${NC}"; echo -e "${CYAN} $1${NC}"; echo -e "${CYAN}========================================${NC}"; }

# =====================================================
# Validações
# =====================================================

validate_kong_running() {
    log_section "Validando Kong"
    
    if curl -s "$KONG_ADMIN_URL/status" > /dev/null 2>&1; then
        log_ok "Kong Admin API está respondendo"
    else
        log_error "Kong Admin API não está respondendo em $KONG_ADMIN_URL"
        EXIT_CODE=1
        return 1
    fi
}

validate_kong_database() {
    log_section "Validando Banco de Dados do Kong"
    
    # Verificar conexão com banco
    if PGPASSWORD="${KONG_PG_PASSWORD:-kong123}" psql -h "$KONG_PG_HOST" -p "$KONG_PG_PORT" -U "$KONG_PG_USER" -d "$KONG_PG_DATABASE" -c "SELECT version();" > /dev/null 2>&1; then
        log_ok "Conexão com banco de dados do Kong OK"
    else
        log_error "Não foi possível conectar ao banco de dados do Kong"
        EXIT_CODE=1
        return 1
    fi
    
    # Verificar tabelas
    log_info "Verificando tabelas do Kong..."
    local tables=$(PGPASSWORD="${KONG_PG_PASSWORD:-kong123}" psql -h "$KONG_PG_HOST" -p "$KONG_PG_PORT" -U "$KONG_PG_USER" -d "$KONG_PG_DATABASE" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" 2>/dev/null)
    
    if [ "$tables" -gt 0 ]; then
        log_ok "Banco de dados do Kong inicializado com $tables tabelas"
    else
        log_error "Banco de dados do Kong não foi inicializado corretamente"
        EXIT_CODE=1
        return 1
    fi
}

validate_services() {
    log_section "Validando Services Provisionados"
    
    local services=("register-service" "billing-service" "documents-service" "ai-assistant-service" "notification-service" "booking-service" "finance-service")
    
    for service in "${services[@]}"; do
        local response=$(curl -s "$KONG_ADMIN_URL/services/$service" 2>/dev/null || echo "{}")
        
        if echo "$response" | grep -q '"id"'; then
            local url=$(echo "$response" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)
            log_ok "Service '$service' encontrado -> $url"
        else
            log_warn "Service '$service' não encontrado"
            EXIT_CODE=1
        fi
    done
}

validate_routes() {
    log_section "Validando Routes Provisionadas"
    
    local routes=("register-api" "billing-api" "documents-api" "ai-assistant-api" "notification-api" "booking-api" "finance-api")
    
    for route in "${routes[@]}"; do
        local response=$(curl -s "$KONG_ADMIN_URL/routes/$route" 2>/dev/null || echo "{}")
        
        if echo "$response" | grep -q '"id"'; then
            local paths=$(echo "$response" | grep -o '"paths":\[[^]]*\]' | head -1)
            log_ok "Route '$route' encontrada -> $paths"
        else
            log_warn "Route '$route' não encontrada"
            EXIT_CODE=1
        fi
    done
}

validate_plugins() {
    log_section "Validando Plugins Globais"
    
    local required_plugins=("cors" "rate-limiting" "request-size-limiting" "correlation-id" "prometheus")
    
    local response=$(curl -s "$KONG_ADMIN_URL/plugins" 2>/dev/null || echo "{}")
    local plugin_names=$(echo "$response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | sort -u)
    
    for plugin in "${required_plugins[@]}"; do
        if echo "$plugin_names" | grep -q "^$plugin$"; then
            log_ok "Plugin '$plugin' está configurado"
        else
            log_warn "Plugin '$plugin' não encontrado"
            EXIT_CODE=1
        fi
    done
}

validate_cors() {
    log_section "Validando Configuração CORS"
    
    local cors_response=$(curl -s "$KONG_ADMIN_URL/plugins" 2>/dev/null | grep -A 50 '"name":"cors"' | head -60)
    
    if echo "$cors_response" | grep -q '"origins"'; then
        log_ok "CORS está configurado"
        
        # Verificar origins específicos
        if echo "$cors_response" | grep -q "localhost:3000"; then
            log_ok "  ✓ localhost:3000 permitido"
        fi
        
        if echo "$cors_response" | grep -q "condohome.com.br"; then
            log_ok "  ✓ condohome.com.br permitido"
        fi
        
        if echo "$cors_response" | grep -q "portaria.condohome.com.br"; then
            log_ok "  ✓ portaria.condohome.com.br permitido"
        fi
    else
        log_error "CORS não está configurado"
        EXIT_CODE=1
    fi
}

validate_consumers() {
    log_section "Validando Consumers e API Keys"
    
    local consumers=("portal-web" "portaria-app" "n8n-orchestrator" "mobile-app")
    
    for consumer in "${consumers[@]}"; do
        local response=$(curl -s "$KONG_ADMIN_URL/consumers/$consumer" 2>/dev/null || echo "{}")
        
        if echo "$response" | grep -q '"id"'; then
            log_ok "Consumer '$consumer' encontrado"
        else
            log_warn "Consumer '$consumer' não encontrado"
            EXIT_CODE=1
        fi
    done
}

validate_no_gateway_service() {
    log_section "Validando Remoção do Gateway Legado"
    
    local response=$(curl -s "$KONG_ADMIN_URL/services/gateway-service" 2>/dev/null || echo "{}")
    
    if echo "$response" | grep -q '"id"'; then
        log_error "Service 'gateway-service' ainda existe! Deve ser removido."
        EXIT_CODE=1
    else
        log_ok "Service 'gateway-service' foi removido corretamente"
    fi
}

validate_proxy_health() {
    log_section "Validando Saúde do Proxy Kong"
    
    local proxy_url="${KONG_PROXY_URL:-http://localhost:8000}"
    
    # Kong proxy retorna 404 para root
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$proxy_url/" 2>/dev/null || echo "000")
    
    if [ "$http_code" = "404" ]; then
        log_ok "Kong Proxy está respondendo corretamente (HTTP 404 em root)"
    else
        log_error "Kong Proxy não está respondendo corretamente (HTTP $http_code)"
        EXIT_CODE=1
    fi
}

# =====================================================
# Main
# =====================================================

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  CondoHome - Kong Migrations Validator  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

validate_kong_running || exit 1
validate_kong_database
validate_services
validate_routes
validate_plugins
validate_cors
validate_consumers
validate_no_gateway_service
validate_proxy_health

echo ""
log_section "Resultado Final"

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Todas as validações passaram!${NC}"
    echo -e "${GREEN}✓ Kong está corretamente configurado${NC}"
    echo -e "${GREEN}✓ Migrations foram executadas com sucesso${NC}"
    echo ""
    echo -e "${BLUE}URLs disponíveis:${NC}"
    echo -e "  Kong Proxy:   http://localhost:8000"
    echo -e "  Kong Admin:   http://localhost:8001"
    echo -e "  Kong Manager: http://localhost:8002"
else
    echo -e "${RED}✗ Algumas validações falharam!${NC}"
    echo -e "${RED}✗ Verifique os erros acima${NC}"
fi

exit $EXIT_CODE
