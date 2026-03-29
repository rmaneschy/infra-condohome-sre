#!/bin/bash
# =====================================================
# CondoHome Platform - Kong Health Check
# Verifica saude do Kong e dos upstreams
# Uso em cron jobs ou monitoring
# =====================================================

KONG_ADMIN_URL="${KONG_ADMIN_URL:-http://localhost:8001}"
KONG_PROXY_URL="${KONG_PROXY_URL:-http://localhost:8000}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

EXIT_CODE=0

check() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")

    if [ "$http_code" = "$expected_code" ]; then
        echo -e "${GREEN}[PASS]${NC} $name (HTTP $http_code)"
    else
        echo -e "${RED}[FAIL]${NC} $name (HTTP $http_code, esperado $expected_code)"
        EXIT_CODE=1
    fi
}

echo "=== Kong Gateway Health Check ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Kong Admin API
check "Kong Admin API"     "$KONG_ADMIN_URL/"
check "Kong Admin Status"  "$KONG_ADMIN_URL/status"

# Kong Proxy
check "Kong Proxy"         "$KONG_PROXY_URL/" "404"

# Services via proxy
echo ""
echo "--- Services (via proxy) ---"
check "Register Service"     "$KONG_PROXY_URL/api/register/actuator/health"
check "Billing Service"      "$KONG_PROXY_URL/api/billing/actuator/health"
check "Documents Service"    "$KONG_PROXY_URL/api/documents/actuator/health"
check "AI Assistant Service" "$KONG_PROXY_URL/api/ai/actuator/health"
check "Notification Service" "$KONG_PROXY_URL/api/notification/actuator/health"
check "Booking Service"      "$KONG_PROXY_URL/api/booking/actuator/health"
check "Finance Service"      "$KONG_PROXY_URL/api/finance/actuator/health"

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}Todos os checks passaram!${NC}"
else
    echo -e "${RED}Alguns checks falharam!${NC}"
fi

exit $EXIT_CODE
