#!/bin/bash
# =====================================================
# CondoHome Platform - Kong Gateway Management
# Start, stop, restart e health check do Kong
#
# Por padrao, usa o docker-compose.yml principal (condohome-platform)
# para que o Kong fique na mesma rede dos microservicos.
#
# Para uso standalone (Kong isolado):
#   KONG_STANDALONE=true bash scripts/kong/manage.sh start
# =====================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Compose principal (Kong integrado com microservicos)
MAIN_COMPOSE="$SRE_DIR/docker-compose.yml"
# Compose standalone (Kong isolado)
STANDALONE_COMPOSE="$SRE_DIR/docker/kong/docker-compose.yml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Carregar variaveis de ambiente
load_env() {
    local env_file="$SRE_DIR/configs/envs/.env.local"
    if [ -f "$env_file" ]; then
        set -a
        source "$env_file"
        set +a
    fi
}

# Determinar qual compose usar
get_compose_cmd() {
    if [ "${KONG_STANDALONE:-false}" = "true" ]; then
        log_info "Modo standalone (Kong isolado)"
        # Standalone precisa da rede externa
        if ! docker network inspect condohome-net > /dev/null 2>&1; then
            log_info "Criando rede condohome-net..."
            docker network create condohome-net
        fi
        echo "docker compose -f $STANDALONE_COMPOSE"
    else
        echo "docker compose -f $MAIN_COMPOSE"
    fi
}

# Servicos Kong no compose principal (filtrar apenas Kong)
KONG_SERVICES="kong-database kong-migrations kong"

usage() {
    echo -e "${BLUE}CondoHome - Kong Gateway Management${NC}"
    echo ""
    echo "Uso: $0 [COMANDO]"
    echo ""
    echo "Comandos:"
    echo "  start        Iniciar Kong Gateway (database + migrations + gateway)"
    echo "  stop         Parar Kong Gateway"
    echo "  restart      Reiniciar Kong Gateway"
    echo "  status       Verificar status dos containers"
    echo "  logs         Ver logs do Kong"
    echo "  health       Verificar saude do Kong"
    echo "  shell        Abrir shell no container do Kong"
    echo "  clean        Parar e remover volumes (RESET TOTAL)"
    echo "  provision    Provisionar services, routes e plugins"
    echo "  quick-start  Start + provision (setup completo)"
    echo ""
    echo "Variaveis de ambiente:"
    echo "  KONG_STANDALONE=true   Usar compose standalone (Kong isolado)"
    echo ""
}

start() {
    log_info "Iniciando Kong Gateway..."
    load_env

    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    if [ "${KONG_STANDALONE:-false}" = "true" ]; then
        $compose_cmd up -d
    else
        # No compose principal, subir apenas os servicos do Kong
        $compose_cmd --profile backend up -d $KONG_SERVICES
    fi

    log_info "Aguardando Kong ficar saudavel..."
    local retries=0
    while [ $retries -lt 30 ]; do
        if docker exec condohome-kong kong health > /dev/null 2>&1; then
            log_ok "Kong Gateway iniciado!"
            echo -e "  Proxy HTTP:  http://localhost:${KONG_PROXY_PORT:-8000}"
            echo -e "  Proxy HTTPS: https://localhost:${KONG_PROXY_SSL_PORT:-8443}"
            echo -e "  Admin API:   http://localhost:${KONG_ADMIN_PORT:-8001}"
            echo -e "  Manager GUI: http://localhost:${KONG_ADMIN_GUI_PORT:-8002}"
            return 0
        fi
        retries=$((retries + 1))
        echo -n "."
        sleep 2
    done
    echo ""
    log_error "Kong nao ficou saudavel apos 60s"
    docker logs condohome-kong --tail 20
    exit 1
}

stop() {
    log_info "Parando Kong Gateway..."
    load_env

    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    if [ "${KONG_STANDALONE:-false}" = "true" ]; then
        $compose_cmd down
    else
        # No compose principal, parar apenas os servicos do Kong
        $compose_cmd stop $KONG_SERVICES
        $compose_cmd rm -f $KONG_SERVICES
    fi
    log_ok "Kong Gateway parado"
}

restart() {
    stop
    start
}

status() {
    echo -e "${CYAN}Kong Gateway Containers:${NC}"
    docker ps --filter "name=condohome-kong" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    echo ""
    if curl -s "http://localhost:${KONG_ADMIN_PORT:-8001}/status" > /dev/null 2>&1; then
        echo -e "${GREEN}Kong Admin API: ONLINE${NC}"
        curl -s "http://localhost:${KONG_ADMIN_PORT:-8001}/status" | python3 -m json.tool 2>/dev/null
    else
        echo -e "${RED}Kong Admin API: OFFLINE${NC}"
    fi
}

logs() {
    local service="${1:-kong}"
    docker logs -f "condohome-${service}" 2>/dev/null || docker logs -f "condohome-kong" 2>/dev/null
}

health() {
    echo -e "${CYAN}Kong Health Check:${NC}"

    # Container health
    local container_status
    container_status=$(docker inspect --format='{{.State.Health.Status}}' condohome-kong 2>/dev/null || echo "not running")
    echo -e "  Container: $container_status"

    # Admin API
    if curl -s "http://localhost:${KONG_ADMIN_PORT:-8001}/" > /dev/null 2>&1; then
        local version
        version=$(curl -s "http://localhost:${KONG_ADMIN_PORT:-8001}/" | python3 -c "import sys,json; print(json.load(sys.stdin).get('version','unknown'))" 2>/dev/null)
        echo -e "  Admin API: ${GREEN}OK${NC} (Kong v$version)"
    else
        echo -e "  Admin API: ${RED}OFFLINE${NC}"
    fi

    # Database
    local db_status
    db_status=$(curl -s "http://localhost:${KONG_ADMIN_PORT:-8001}/status" | python3 -c "import sys,json; d=json.load(sys.stdin).get('database',{}); print(f\"reachable={d.get('reachable','?')}\")" 2>/dev/null || echo "unknown")
    echo -e "  Database: $db_status"

    # Services count
    local svc_count
    svc_count=$(curl -s "http://localhost:${KONG_ADMIN_PORT:-8001}/services" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('data',[])))" 2>/dev/null || echo "?")
    echo -e "  Services: $svc_count"

    # Routes count
    local rt_count
    rt_count=$(curl -s "http://localhost:${KONG_ADMIN_PORT:-8001}/routes" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('data',[])))" 2>/dev/null || echo "?")
    echo -e "  Routes: $rt_count"

    # Plugins count
    local pl_count
    pl_count=$(curl -s "http://localhost:${KONG_ADMIN_PORT:-8001}/plugins" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('data',[])))" 2>/dev/null || echo "?")
    echo -e "  Plugins: $pl_count"
}

open_shell() {
    docker exec -it condohome-kong /bin/sh
}

clean() {
    log_warn "ATENCAO: Isso vai remover todos os containers E volumes do Kong!"
    read -p "Tem certeza? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Operacao cancelada."
        return 0
    fi

    load_env
    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    if [ "${KONG_STANDALONE:-false}" = "true" ]; then
        $compose_cmd down -v
    else
        # Parar e remover containers Kong
        docker stop condohome-kong condohome-kong-database condohome-kong-migrations 2>/dev/null || true
        docker rm -f condohome-kong condohome-kong-database condohome-kong-migrations 2>/dev/null || true
        # Remover volume do Kong
        docker volume rm condohome-platform_kong_postgres_data 2>/dev/null || true
    fi
    log_ok "Kong Gateway removido com volumes"
}

provision() {
    bash "$SCRIPT_DIR/provision.sh" "${@:-all}"
}

quick_start() {
    start
    echo ""
    provision
}

# =====================================================
# Main
# =====================================================

case "${1:-help}" in
    start)       start ;;
    stop)        stop ;;
    restart)     restart ;;
    status)      status ;;
    logs)        logs "$2" ;;
    health)      health ;;
    shell)       open_shell ;;
    clean)       clean ;;
    provision)   shift; provision "$@" ;;
    quick-start) quick_start ;;
    help|*)      usage ;;
esac
