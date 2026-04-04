#!/bin/bash
# =====================================================
# CondoHome Platform - Test Environment Defaults
# Testa se a lógica de ambiente padrão está funcionando
# =====================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRE_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0

log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }

# =====================================================
# Testes
# =====================================================

test_env_variable_default() {
    log_test "Testando variável ENV com padrão 'desenvolvimento'"
    
    # Teste 1: ENV não definido
    local env_value="${ENV:-desenvolvimento}"
    if [ "$env_value" = "desenvolvimento" ]; then
        log_pass "ENV não definido retorna 'desenvolvimento'"
    else
        log_fail "ENV não definido deveria retornar 'desenvolvimento', obteve: $env_value"
    fi
    
    # Teste 2: ENV definido como production
    ENV="production" env_value="${ENV:-desenvolvimento}"
    if [ "$env_value" = "production" ]; then
        log_pass "ENV definido como 'production' é respeitado"
    else
        log_fail "ENV definido como 'production' deveria ser respeitado, obteve: $env_value"
    fi
}

test_env_file_loading() {
    log_test "Testando carregamento de arquivo .env"
    
    # Verificar se os arquivos .env existem
    if [ -f "$SRE_DIR/configs/envs/.env.local.example" ]; then
        log_pass "Arquivo .env.local.example existe"
    else
        log_fail "Arquivo .env.local.example não encontrado"
    fi
    
    if [ -f "$SRE_DIR/configs/envs/.env.production.example" ]; then
        log_pass "Arquivo .env.production.example existe"
    else
        log_fail "Arquivo .env.production.example não encontrado"
    fi
    
    if [ -f "$SRE_DIR/configs/envs/.env.staging.example" ]; then
        log_pass "Arquivo .env.staging.example existe"
    else
        log_fail "Arquivo .env.staging.example não encontrado"
    fi
}

test_env_variable_in_files() {
    log_test "Testando se ENV está definido nos arquivos .env"
    
    # Verificar .env.local.example
    if grep -q "^ENV=desenvolvimento" "$SRE_DIR/configs/envs/.env.local.example"; then
        log_pass ".env.local.example contém ENV=desenvolvimento"
    else
        log_fail ".env.local.example não contém ENV=desenvolvimento"
    fi
    
    # Verificar .env.production.example
    if grep -q "^ENV=production" "$SRE_DIR/configs/envs/.env.production.example"; then
        log_pass ".env.production.example contém ENV=production"
    else
        log_fail ".env.production.example não contém ENV=production"
    fi
    
    # Verificar .env.staging.example
    if grep -q "^ENV=staging" "$SRE_DIR/configs/envs/.env.staging.example"; then
        log_pass ".env.staging.example contém ENV=staging"
    else
        log_fail ".env.staging.example não contém ENV=staging"
    fi
}

test_makefile_env_default() {
    log_test "Testando ENV padrão no Makefile"
    
    if grep -q "^ENV ?= desenvolvimento" "$SRE_DIR/Makefile"; then
        log_pass "Makefile contém ENV ?= desenvolvimento"
    else
        log_fail "Makefile não contém ENV ?= desenvolvimento"
    fi
}

test_scripts_env_handling() {
    log_test "Testando se scripts lidam com ENV padrão"
    
    # Verificar start.sh
    if grep -q 'export ENV="\${ENV:-desenvolvimento}"' "$SRE_DIR/scripts/local/start.sh"; then
        log_pass "scripts/local/start.sh trata ENV padrão"
    else
        log_fail "scripts/local/start.sh não trata ENV padrão corretamente"
    fi
    
    # Verificar manage.sh
    if grep -q 'export ENV="\${ENV:-desenvolvimento}"' "$SRE_DIR/scripts/kong/manage.sh"; then
        log_pass "scripts/kong/manage.sh trata ENV padrão"
    else
        log_fail "scripts/kong/manage.sh não trata ENV padrão corretamente"
    fi
    
    # Verificar provision.sh
    if grep -q 'export ENV="\${ENV:-desenvolvimento}"' "$SRE_DIR/scripts/kong/provision.sh"; then
        log_pass "scripts/kong/provision.sh trata ENV padrão"
    else
        log_fail "scripts/kong/provision.sh não trata ENV padrão corretamente"
    fi
    
    # Verificar validate-requirements.sh
    if grep -q 'local env="\${1:-\${ENV:-local}}"' "$SRE_DIR/scripts/validate-requirements.sh"; then
        log_pass "scripts/validate-requirements.sh trata ENV padrão"
    else
        log_fail "scripts/validate-requirements.sh não trata ENV padrão corretamente"
    fi
}

test_env_mapping() {
    log_test "Testando mapeamento de 'desenvolvimento' para 'local'"
    
    # Verificar se o mapeamento existe em start.sh
    if grep -q 'if \[ "\$ENV" = "desenvolvimento" \]; then' "$SRE_DIR/scripts/local/start.sh"; then
        log_pass "scripts/local/start.sh mapeia 'desenvolvimento' para 'local'"
    else
        log_fail "scripts/local/start.sh não mapeia 'desenvolvimento' para 'local'"
    fi
}

# =====================================================
# Main
# =====================================================

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  CondoHome - Environment Defaults Test  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

test_env_variable_default
echo ""

test_env_file_loading
echo ""

test_env_variable_in_files
echo ""

test_makefile_env_default
echo ""

test_scripts_env_handling
echo ""

test_env_mapping
echo ""

# =====================================================
# Resumo
# =====================================================

echo -e "${CYAN}════════════════════════════════════════${NC}"
echo -e "${CYAN} Resumo dos Testes${NC}"
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo -e "  ${GREEN}✓ Passou:${NC}   $PASS"
echo -e "  ${RED}✗ Falhou:${NC}   $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}${BOLD}Todos os testes passaram!${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}Alguns testes falharam. Revise os itens acima.${NC}"
    exit 1
fi
