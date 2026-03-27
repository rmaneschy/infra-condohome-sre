#!/bin/bash
# =====================================================
# CondoHome Platform - Build All Microservices
# Compila todos os projetos Spring Boot e gera JARs
# =====================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVICES=(
    "ms-condohome-register"
    "ms-condohome-billing"
    "ms-condohome-documents"
    "ms-condohome-booking"
    "ms-condohome-notification"
    "ms-condohome-finance"
    "ms-condohome-ai-assistant"
    "ms-condohome-gateway"
)

SKIP_TESTS="${SKIP_TESTS:-true}"
PARALLEL="${PARALLEL:-false}"

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}  CondoHome Platform - Build All${NC}"
echo -e "${BLUE}  Skip Tests: $SKIP_TESTS${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

PASS=0
FAIL=0

build_service() {
    local service="$1"
    local service_dir="$PLATFORM_DIR/$service"

    if [ ! -d "$service_dir" ]; then
        echo -e "${YELLOW}[SKIP] $service - diretório não encontrado${NC}"
        return 1
    fi

    echo -e "${BLUE}[BUILD] $service...${NC}"

    local mvn_args="clean package"
    if [ "$SKIP_TESTS" = "true" ]; then
        mvn_args="$mvn_args -DskipTests"
    fi

    if cd "$service_dir" && ./mvnw $mvn_args -q 2>&1; then
        echo -e "${GREEN}[OK] $service${NC}"
        return 0
    else
        echo -e "${RED}[FAIL] $service${NC}"
        return 1
    fi
}

for service in "${SERVICES[@]}"; do
    if build_service "$service"; then
        ((PASS++))
    else
        ((FAIL++))
    fi
done

echo ""
echo -e "${BLUE}=================================================${NC}"
echo -e "  ${GREEN}Sucesso: $PASS${NC}  |  ${RED}Falha: $FAIL${NC}"
echo -e "${BLUE}=================================================${NC}"

if [ $FAIL -gt 0 ]; then
    exit 1
fi
