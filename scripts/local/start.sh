#!/bin/bash
# =====================================================
# CondoHome Platform - Start Local Environment
# Inicia a infraestrutura e os serviços selecionados
# =====================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo -e "${BLUE}CondoHome Platform - Local Environment Manager${NC}"
    echo ""
    echo "Uso: $0 [OPCAO]"
    echo ""
    echo "Opcoes:"
    echo "  infra       Subir apenas infraestrutura (PostgreSQL, Redis, Kong)"
    echo "  tools       Subir infra + ferramentas (pgAdmin, Redis Commander)"
    echo "  backend     Subir infra + todos os microservicos backend"
    echo "  frontend    Subir infra + gateway + frontends (portal-web, portaria)"
    echo "  full        Subir tudo (infra + backend + frontend + N8N)"
    echo "  service     Subir infra + um servico especifico"
    echo "  stop        Parar todos os containers"
    echo "  status      Verificar status dos containers"
    echo "  logs        Ver logs de um servico"
    echo "  clean       Parar e remover volumes (RESET TOTAL)"
    echo ""
    echo "Exemplos:"
    echo "  $0 infra                  # PostgreSQL + Redis + Kong"
    echo "  $0 backend                # Infra + todos os servicos"
    echo "  $0 service register       # Infra + ms-condohome-register"
    echo "  $0 logs billing           # Logs do ms-condohome-billing"
    echo ""
}

load_env() {
    local env_file="$SRE_DIR/configs/envs/.env.local"
    if [ -f "$env_file" ]; then
        set -a
        source "$env_file"
        set +a
        echo -e "${GREEN}Ambiente local carregado${NC}"
    else
        echo -e "${YELLOW}Arquivo .env.local nao encontrado. Usando valores padrao.${NC}"
    fi
}

start_infra() {
    echo -e "${BLUE}Iniciando infraestrutura (PostgreSQL + Redis + Kong)...${NC}"
    cd "$SRE_DIR"
    docker compose up -d postgres redis kong-database kong-migrations kong
    echo -e "${GREEN}Infraestrutura iniciada!${NC}"
    echo -e "  PostgreSQL:   localhost:${POSTGRES_PORT:-5432}"
    echo -e "  Redis:        localhost:${REDIS_PORT:-6379}"
    echo -e "  Kong Proxy:   http://localhost:${KONG_PROXY_PORT:-8000}"
    echo -e "  Kong Admin:   http://localhost:${KONG_ADMIN_PORT:-8001}"
    echo -e "  Kong Manager: http://localhost:${KONG_ADMIN_GUI_PORT:-8002}"
}

start_tools() {
    start_infra
    echo -e "${BLUE}Iniciando ferramentas...${NC}"
    cd "$SRE_DIR"
    docker compose --profile tools up -d
    echo -e "${GREEN}Ferramentas iniciadas!${NC}"
    echo -e "  pgAdmin:         http://localhost:${PGADMIN_PORT:-5050}"
    echo -e "  Redis Commander: http://localhost:${REDIS_COMMANDER_PORT:-8090}"
}

start_backend() {
    echo -e "${BLUE}Iniciando plataforma completa (backend)...${NC}"
    cd "$SRE_DIR"
    docker compose --profile backend up -d
    echo -e "${GREEN}Backend iniciado!${NC}"
    print_services
}

start_frontend() {
    start_infra
    echo -e "${BLUE}Iniciando frontend (gateway + portal-web + assistente-portaria)...${NC}"
    cd "$SRE_DIR"
    docker compose up -d gateway
    docker compose --profile frontend up -d
    echo -e "${GREEN}Frontend iniciado!${NC}"
    echo -e "  Gateway:             http://localhost:${GATEWAY_PORT:-8080}"
    echo -e "  Portal Web (Admin):  http://localhost:${PORTAL_WEB_PORT:-3000}"
    echo -e "  Assistente Portaria: http://localhost:${PORTARIA_PORT:-3001}"
}

start_full() {
    echo -e "${BLUE}Iniciando plataforma completa (full)...${NC}"
    cd "$SRE_DIR"
    docker compose --profile full up -d
    echo -e "${GREEN}Plataforma completa iniciada!${NC}"
    print_services
}

start_service() {
    local service="$1"
    if [ -z "$service" ]; then
        echo -e "${RED}Especifique o servico. Ex: $0 service register${NC}"
        exit 1
    fi
    start_infra
    echo -e "${BLUE}Iniciando servico: $service...${NC}"
    cd "$SRE_DIR"
    docker compose up -d "$service"
    echo -e "${GREEN}Servico $service iniciado!${NC}"
}

stop_all() {
    echo -e "${YELLOW}Parando todos os containers...${NC}"
    cd "$SRE_DIR"
    docker compose --profile full --profile tools down
    echo -e "${GREEN}Todos os containers parados.${NC}"
}

show_status() {
    echo -e "${BLUE}Status dos containers CondoHome:${NC}"
    docker ps --filter "name=condohome-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

show_logs() {
    local service="$1"
    if [ -z "$service" ]; then
        echo -e "${RED}Especifique o servico. Ex: $0 logs register${NC}"
        exit 1
    fi
    cd "$SRE_DIR"
    docker compose logs -f "$service"
}

clean_all() {
    echo -e "${RED}ATENCAO: Isso ira remover TODOS os dados (volumes, bancos, etc.)${NC}"
    read -p "Tem certeza? (y/N): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        cd "$SRE_DIR"
        docker compose --profile full --profile tools down -v
        echo -e "${GREEN}Ambiente limpo com sucesso.${NC}"
    else
        echo -e "${YELLOW}Operacao cancelada.${NC}"
    fi
}

print_services() {
    echo ""
    echo -e "${BLUE}Servicos disponiveis:${NC}"
    echo -e "  Kong Proxy:    http://localhost:${KONG_PROXY_PORT:-8000}"
    echo -e "  Kong Admin:    http://localhost:${KONG_ADMIN_PORT:-8001}"
    echo -e "  Kong Manager:  http://localhost:${KONG_ADMIN_GUI_PORT:-8002}"
    echo -e "  Gateway:       http://localhost:${GATEWAY_PORT:-8080}"
    echo -e "  Register:      http://localhost:${REGISTER_PORT:-8081}"
    echo -e "  Billing:       http://localhost:${BILLING_PORT:-8082}"
    echo -e "  Documents:     http://localhost:${DOCUMENTS_PORT:-8083}"
    echo -e "  AI Assistant:  http://localhost:${AI_ASSISTANT_PORT:-8085}"
    echo -e "  Notification:  http://localhost:${NOTIFICATION_PORT:-8086}"
    echo -e "  Booking:       http://localhost:${BOOKING_PORT:-8087}"
    echo -e "  Finance:       http://localhost:${FINANCE_PORT:-8088}"
    echo -e "  N8N:           http://localhost:${N8N_PORT:-5678}"
    echo ""
    echo -e "${BLUE}Frontend:${NC}"
    echo -e "  Portal Web:    http://localhost:${PORTAL_WEB_PORT:-3000}"
    echo -e "  Portaria:      http://localhost:${PORTARIA_PORT:-3001}"
}

# Main
load_env

case "${1:-}" in
    infra)    start_infra ;;
    tools)    start_tools ;;
    backend)  start_backend ;;
    frontend) start_frontend ;;
    full)     start_full ;;
    service)  start_service "$2" ;;
    stop)     stop_all ;;
    status)   show_status ;;
    logs)     show_logs "$2" ;;
    clean)    clean_all ;;
    *)        usage ;;
esac
