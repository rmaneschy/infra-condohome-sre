#!/bin/bash
# =====================================================
# CondoHome Platform - Kong Gateway Provisioning
# Registra services, routes e plugins via Admin API
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

# Carregar variaveis de ambiente
load_env() {
    # Se ENV não estiver configurado, define o padrão como desenvolvimento
    export ENV="${ENV:-desenvolvimento}"
    
    # Mapeia 'desenvolvimento' para 'local' para manter compatibilidade com os arquivos existentes
    local env_suffix="$ENV"
    if [ "$ENV" = "desenvolvimento" ]; then
        env_suffix="local"
    fi
    
    local env_file="$SRE_DIR/configs/envs/.env.${env_suffix}"
    
    if [ -f "$env_file" ]; then
        set -a
        source "$env_file"
        set +a
    fi
}

load_env

KONG_ADMIN_URL="${KONG_ADMIN_URL:-http://localhost:8001}"

# =====================================================
# Microserviços CondoHome
# =====================================================
declare -A SERVICES
SERVICES=(
    ["register"]="condohome-register:8081"
    ["billing"]="condohome-billing:8082"
    ["documents"]="condohome-documents:8083"
    ["ai-assistant"]="condohome-ai-assistant:8085"
    ["notification"]="condohome-notification:8086"
    ["booking"]="condohome-booking:8087"
    ["finance"]="condohome-finance:8088"
)

# =====================================================
# Funções auxiliares
# =====================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${CYAN}========================================${NC}"; echo -e "${CYAN} $1${NC}"; echo -e "${CYAN}========================================${NC}"; }

wait_for_kong() {
    log_info "Aguardando Kong ficar disponivel em $KONG_ADMIN_URL..."
    local retries=0
    local max_retries=30
    while [ $retries -lt $max_retries ]; do
        if curl -s "$KONG_ADMIN_URL/status" > /dev/null 2>&1; then
            log_ok "Kong esta disponivel!"
            return 0
        fi
        retries=$((retries + 1))
        echo -n "."
        sleep 2
    done
    echo ""
    log_error "Kong nao respondeu apos $((max_retries * 2))s"
    exit 1
}

kong_api() {
    local method="$1"
    local endpoint="$2"
    local data="$3"

    if [ -n "$data" ]; then
        curl -s -X "$method" "$KONG_ADMIN_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data"
    else
        curl -s -X "$method" "$KONG_ADMIN_URL$endpoint"
    fi
}

create_service() {
    local name="$1"
    local host="$2"
    local port="$3"
    local path="${4:-/}"
    local connect_timeout="${5:-10000}"
    local read_timeout="${6:-30000}"

    log_info "Criando service: $name -> http://$host:$port"

    local result
    result=$(kong_api PUT "/services/$name" "{
        \"name\": \"$name\",
        \"host\": \"$host\",
        \"port\": $port,
        \"protocol\": \"http\",
        \"path\": \"$path\",
        \"connect_timeout\": $connect_timeout,
        \"write_timeout\": $read_timeout,
        \"read_timeout\": $read_timeout,
        \"retries\": 3
    }")

    if echo "$result" | grep -q '"id"'; then
        log_ok "Service '$name' criado/atualizado"
    else
        log_error "Falha ao criar service '$name': $result"
        return 1
    fi
}

create_route() {
    local service_name="$1"
    local route_name="$2"
    local paths="$3"
    local strip_path="${4:-false}"
    local methods="${5:-}"

    log_info "Criando route: $route_name -> $paths"

    local data="{
        \"name\": \"$route_name\",
        \"paths\": $paths,
        \"strip_path\": $strip_path,
        \"preserve_host\": false,
        \"protocols\": [\"http\", \"https\"]"

    if [ -n "$methods" ]; then
        data="$data, \"methods\": $methods"
    fi

    data="$data}"

    local result
    result=$(kong_api PUT "/services/$service_name/routes/$route_name" "$data")

    if echo "$result" | grep -q '"id"'; then
        log_ok "Route '$route_name' criada/atualizada"
    else
        log_error "Falha ao criar route '$route_name': $result"
        return 1
    fi
}

create_plugin() {
    local scope="$1"       # "global" ou "service:<name>" ou "route:<name>"
    local plugin_name="$2"
    local config="$3"

    local endpoint="/plugins"
    local scope_desc="global"

    if [[ "$scope" == service:* ]]; then
        local svc_name="${scope#service:}"
        endpoint="/services/$svc_name/plugins"
        scope_desc="service:$svc_name"
    elif [[ "$scope" == route:* ]]; then
        local rt_name="${scope#route:}"
        endpoint="/routes/$rt_name/plugins"
        scope_desc="route:$rt_name"
    fi

    log_info "Criando plugin: $plugin_name ($scope_desc)"

    local data="{\"name\": \"$plugin_name\", \"config\": $config}"

    local result
    result=$(kong_api POST "$endpoint" "$data")

    if echo "$result" | grep -q '"id"'; then
        log_ok "Plugin '$plugin_name' criado ($scope_desc)"
    elif echo "$result" | grep -q "unique constraint"; then
        log_warn "Plugin '$plugin_name' ja existe ($scope_desc) - ignorando"
    else
        log_error "Falha ao criar plugin '$plugin_name': $result"
        return 1
    fi
}

create_consumer() {
    local username="$1"
    local custom_id="$2"

    log_info "Criando consumer: $username"

    local result
    result=$(kong_api PUT "/consumers/$username" "{
        \"username\": \"$username\",
        \"custom_id\": \"$custom_id\"
    }")

    if echo "$result" | grep -q '"id"'; then
        log_ok "Consumer '$username' criado/atualizado"
    else
        log_error "Falha ao criar consumer '$username': $result"
        return 1
    fi
}

create_consumer_key() {
    local username="$1"
    local key="$2"

    log_info "Criando API key para consumer: $username"

    local result
    result=$(kong_api POST "/consumers/$username/key-auth" "{\"key\": \"$key\"}")

    if echo "$result" | grep -q '"id"'; then
        log_ok "API key criada para '$username'"
    elif echo "$result" | grep -q "unique constraint"; then
        log_warn "API key ja existe para '$username' - ignorando"
    else
        log_error "Falha ao criar API key para '$username': $result"
    fi
}

# =====================================================
# Provisionamento
# =====================================================

provision_services() {
    log_section "Registrando Services"

    for svc_name in "${!SERVICES[@]}"; do
        local host_port="${SERVICES[$svc_name]}"
        local host="${host_port%%:*}"
        local port="${host_port##*:}"

        if [ "$svc_name" = "ai-assistant" ]; then
            create_service "${svc_name}-service" "$host" "$port" "/" 10000 60000
        else
            create_service "${svc_name}-service" "$host" "$port"
        fi
    done
}

provision_routes() {
    log_section "Registrando Routes"

    create_route "register-service"     "register-api"      '[\"/api/register\"]'
    create_route "billing-service"      "billing-api"       '[\"/api/billing\"]'
    create_route "documents-service"    "documents-api"     '[\"/api/documents\"]'
    create_route "ai-assistant-service" "ai-assistant-api"  '[\"/api/ai\"]'
    create_route "notification-service" "notification-api"  '[\"/api/notification\"]'
    create_route "booking-service"      "booking-api"       '[\"/api/booking\"]'
    create_route "finance-service"      "finance-api"       '[\"/api/finance\"]'
}

provision_global_plugins() {
    log_section "Registrando Global Plugins"

    # CORS
    create_plugin "global" "cors" '{
        "origins": ["http://localhost:3000", "http://localhost:5173", "https://condohome.com.br", "https://www.condohome.com.br", "https://portaria.condohome.com.br"],
        "methods": ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"],
        "headers": ["Accept", "Accept-Version", "Authorization", "Content-Length", "Content-Type", "X-Requested-With", "X-Condominium-Id", "X-Unit-Id"],
        "exposed_headers": ["X-Auth-Token", "X-Total-Count", "X-Page-Number", "X-Page-Size"],
        "credentials": true,
        "max_age": 3600,
        "preflight_continue": false
    }'

    # Rate Limiting (global)
    create_plugin "global" "rate-limiting" '{
        "minute": 120,
        "hour": 3600,
        "policy": "local",
        "fault_tolerant": true,
        "hide_client_headers": false,
        "error_code": 429,
        "error_message": "Limite de requisicoes excedido. Tente novamente mais tarde."
    }'

    # Request Size Limiting
    create_plugin "global" "request-size-limiting" '{
        "allowed_payload_size": 50,
        "size_unit": "megabytes",
        "require_content_length": false
    }'

    # Correlation ID
    create_plugin "global" "correlation-id" '{
        "header_name": "X-Request-ID",
        "generator": "uuid#counter",
        "echo_downstream": true
    }'

    # Prometheus Metrics
    create_plugin "global" "prometheus" '{
        "status_code_metrics": true,
        "latency_metrics": true,
        "bandwidth_metrics": true,
        "upstream_health_metrics": true
    }'

    # Bot Detection
    create_plugin "global" "bot-detection" '{
        "deny": []
    }'

    # IP Restriction (desabilitado por padrao - descomentar para produção)
    # create_plugin "global" "ip-restriction" '{
    #     "allow": ["0.0.0.0/0"]
    # }'
}

provision_service_plugins() {
    log_section "Registrando Service-level Plugins"

    # Rate limiting mais restritivo para AI Assistant (custa mais)
    create_plugin "service:ai-assistant-service" "rate-limiting" '{
        "minute": 30,
        "hour": 500,
        "policy": "local",
        "fault_tolerant": true,
        "error_code": 429,
        "error_message": "Limite de requisicoes do assistente IA excedido."
    }'

    # Request/Response Transformer para billing (adicionar headers de segurança)
    create_plugin "service:billing-service" "request-transformer" '{
        "add": {
            "headers": ["X-Internal-Service:kong-gateway"]
        }
    }'

    # Response Transformer global - remover headers internos
    create_plugin "global" "response-transformer" '{
        "remove": {
            "headers": ["X-Powered-By", "Server"]
        }
    }'
}

provision_consumers() {
    log_section "Registrando Consumers"

    create_consumer "portal-web"       "portal-web-client"
    create_consumer "portaria-app"     "portaria-app-client"
    create_consumer "n8n-orchestrator" "n8n-orchestrator-client"
    create_consumer "mobile-app"       "mobile-app-client"

    # API Keys (usar variáveis de ambiente em produção)
    create_consumer_key "portal-web"       "${KONG_PORTAL_API_KEY:-condohome-portal-key}"
    create_consumer_key "portaria-app"     "${KONG_PORTARIA_API_KEY:-condohome-portaria-key}"
    create_consumer_key "n8n-orchestrator" "${KONG_N8N_API_KEY:-condohome-n8n-key}"
    create_consumer_key "mobile-app"       "${KONG_MOBILE_API_KEY:-condohome-mobile-key}"
}

# =====================================================
# Comandos
# =====================================================

usage() {
    echo -e "${BLUE}CondoHome - Kong Gateway Provisioning${NC}"
    echo ""
    echo "Uso: $0 [COMANDO]"
    echo ""
    echo "Comandos:"
    echo "  all          Provisionar tudo (services, routes, plugins, consumers)"
    echo "  services     Registrar apenas services"
    echo "  routes       Registrar apenas routes"
    echo "  plugins      Registrar apenas plugins (global + service-level)"
    echo "  consumers    Registrar apenas consumers e API keys"
    echo "  status       Verificar status do Kong e listar configuracoes"
    echo "  reset        Remover TODAS as configuracoes (CUIDADO!)"
    echo "  export       Exportar configuracao atual como YAML"
    echo ""
}

show_status() {
    log_section "Kong Status"

    echo -e "\n${CYAN}Info:${NC}"
    kong_api GET "/status" | python3 -m json.tool 2>/dev/null || kong_api GET "/status"

    echo -e "\n${CYAN}Services:${NC}"
    kong_api GET "/services" | python3 -m json.tool 2>/dev/null || kong_api GET "/services"

    echo -e "\n${CYAN}Routes:${NC}"
    kong_api GET "/routes" | python3 -m json.tool 2>/dev/null || kong_api GET "/routes"

    echo -e "\n${CYAN}Plugins:${NC}"
    kong_api GET "/plugins" | python3 -m json.tool 2>/dev/null || kong_api GET "/plugins"

    echo -e "\n${CYAN}Consumers:${NC}"
    kong_api GET "/consumers" | python3 -m json.tool 2>/dev/null || kong_api GET "/consumers"
}

reset_all() {
    log_section "Resetando TODAS as configuracoes do Kong"

    log_warn "ATENCAO: Isso vai remover TODOS os services, routes, plugins e consumers!"
    read -p "Tem certeza? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Operacao cancelada."
        return 0
    fi

    # Remover plugins
    log_info "Removendo plugins..."
    for id in $(kong_api GET "/plugins" | python3 -c "import sys,json; [print(p['id']) for p in json.load(sys.stdin).get('data',[])]" 2>/dev/null); do
        kong_api DELETE "/plugins/$id" > /dev/null
        log_ok "Plugin $id removido"
    done

    # Remover routes
    log_info "Removendo routes..."
    for id in $(kong_api GET "/routes" | python3 -c "import sys,json; [print(r['id']) for r in json.load(sys.stdin).get('data',[])]" 2>/dev/null); do
        kong_api DELETE "/routes/$id" > /dev/null
        log_ok "Route $id removida"
    done

    # Remover services
    log_info "Removendo services..."
    for id in $(kong_api GET "/services" | python3 -c "import sys,json; [print(s['id']) for s in json.load(sys.stdin).get('data',[])]" 2>/dev/null); do
        kong_api DELETE "/services/$id" > /dev/null
        log_ok "Service $id removido"
    done

    # Remover consumers
    log_info "Removendo consumers..."
    for id in $(kong_api GET "/consumers" | python3 -c "import sys,json; [print(c['id']) for c in json.load(sys.stdin).get('data',[])]" 2>/dev/null); do
        kong_api DELETE "/consumers/$id" > /dev/null
        log_ok "Consumer $id removido"
    done

    log_ok "Reset completo!"
}

export_config() {
    log_section "Exportando configuracao do Kong"

    local output_file="${1:-$SRE_DIR/configs/kong/kong-export-$(date +%Y%m%d-%H%M%S).yml}"

    log_info "Exportando para: $output_file"

    # Usar deck se disponível, senão exportar via API
    if command -v deck &> /dev/null; then
        deck gateway dump --kong-addr "$KONG_ADMIN_URL" -o "$output_file"
    else
        log_warn "deck CLI nao encontrado. Exportando via Admin API..."
        echo "# Kong Export - $(date)" > "$output_file"
        echo "# Services:" >> "$output_file"
        kong_api GET "/services" | python3 -m json.tool >> "$output_file" 2>/dev/null
        echo "# Routes:" >> "$output_file"
        kong_api GET "/routes" | python3 -m json.tool >> "$output_file" 2>/dev/null
        echo "# Plugins:" >> "$output_file"
        kong_api GET "/plugins" | python3 -m json.tool >> "$output_file" 2>/dev/null
    fi

    log_ok "Configuracao exportada para: $output_file"
}

# =====================================================
# Main
# =====================================================

case "${1:-all}" in
    all)
        wait_for_kong
        provision_services
        provision_routes
        provision_global_plugins
        provision_service_plugins
        provision_consumers
        log_section "Provisionamento completo!"
        echo -e "${GREEN}Kong Gateway configurado com sucesso!${NC}"
        echo -e "  Proxy:     http://localhost:${KONG_PROXY_PORT:-8000}"
        echo -e "  Admin API: http://localhost:${KONG_ADMIN_PORT:-8001}"
        echo -e "  Manager:   http://localhost:${KONG_ADMIN_GUI_PORT:-8002}"
        ;;
    services)
        wait_for_kong
        provision_services
        ;;
    routes)
        wait_for_kong
        provision_routes
        ;;
    plugins)
        wait_for_kong
        provision_global_plugins
        provision_service_plugins
        ;;
    consumers)
        wait_for_kong
        provision_consumers
        ;;
    status)
        wait_for_kong
        show_status
        ;;
    reset)
        wait_for_kong
        reset_all
        ;;
    export)
        wait_for_kong
        export_config "$2"
        ;;
    *)
        usage
        exit 1
        ;;
esac
