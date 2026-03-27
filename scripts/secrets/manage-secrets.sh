#!/bin/bash
# =====================================================
# CondoHome Platform - Secrets Management
# Gerencia secrets para diferentes ambientes
# Suporta: GitHub Secrets, Kubernetes Secrets, .env files
# =====================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

GITHUB_ORG="rmaneschy"

REPOS=(
    "ms-condohome-register"
    "ms-condohome-billing"
    "ms-condohome-documents"
    "ms-condohome-booking"
    "ms-condohome-notification"
    "ms-condohome-finance"
    "ms-condohome-ai-assistant"
    "ms-condohome-gateway"
)

usage() {
    echo -e "${BLUE}CondoHome - Secrets Manager${NC}"
    echo ""
    echo "Uso: $0 <comando> [opções]"
    echo ""
    echo "Comandos:"
    echo "  github-set <env_file>       Configurar GitHub Secrets a partir de .env"
    echo "  github-list                 Listar GitHub Secrets de todos os repos"
    echo "  k8s-create <env> <env_file> Criar Kubernetes Secrets"
    echo "  k8s-rotate <env>            Rotacionar secrets no Kubernetes"
    echo "  validate <env_file>         Validar se todas as secrets estão preenchidas"
    echo "  template                    Gerar template de .env com todas as variáveis"
    echo ""
}

validate_env() {
    local env_file="$1"
    if [ ! -f "$env_file" ]; then
        echo -e "${RED}Arquivo não encontrado: $env_file${NC}"
        exit 1
    fi

    echo -e "${BLUE}Validando secrets em: $env_file${NC}"
    local missing=0

    while IFS='=' read -r key value; do
        # Ignorar comentários e linhas vazias
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue

        key=$(echo "$key" | tr -d ' ')
        value=$(echo "$value" | tr -d ' ')

        if [ -z "$value" ] || [ "$value" = "CHANGE_ME" ] || [ "$value" = "CHANGE_ME_STAGING" ] || [ "$value" = "CHANGE_ME_PRODUCTION" ]; then
            echo -e "  ${RED}[MISSING] $key${NC}"
            ((missing++))
        else
            echo -e "  ${GREEN}[OK]      $key${NC}"
        fi
    done < "$env_file"

    echo ""
    if [ $missing -gt 0 ]; then
        echo -e "${RED}$missing secrets não configuradas!${NC}"
        return 1
    else
        echo -e "${GREEN}Todas as secrets estão configuradas.${NC}"
        return 0
    fi
}

github_set_secrets() {
    local env_file="$1"
    if [ ! -f "$env_file" ]; then
        echo -e "${RED}Arquivo não encontrado: $env_file${NC}"
        exit 1
    fi

    echo -e "${BLUE}Configurando GitHub Secrets a partir de: $env_file${NC}"

    for repo in "${REPOS[@]}"; do
        echo -e "\n${BLUE}--- $repo ---${NC}"
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ ]] && continue
            [[ -z "$key" ]] && continue

            key=$(echo "$key" | tr -d ' ')
            value=$(echo "$value" | tr -d ' ')

            if [ -n "$value" ] && [ "$value" != "CHANGE_ME" ]; then
                if gh secret set "$key" --body "$value" --repo "$GITHUB_ORG/$repo" 2>/dev/null; then
                    echo -e "  ${GREEN}[SET] $key${NC}"
                else
                    echo -e "  ${RED}[ERR] $key${NC}"
                fi
            fi
        done < "$env_file"
    done
}

github_list_secrets() {
    echo -e "${BLUE}GitHub Secrets por repositório:${NC}"
    for repo in "${REPOS[@]}"; do
        echo -e "\n${BLUE}--- $repo ---${NC}"
        gh secret list --repo "$GITHUB_ORG/$repo" 2>/dev/null || echo -e "  ${YELLOW}Sem acesso ou repo não encontrado${NC}"
    done
}

k8s_create_secrets() {
    local env="$1"
    local env_file="$2"

    if [ ! -f "$env_file" ]; then
        echo -e "${RED}Arquivo não encontrado: $env_file${NC}"
        exit 1
    fi

    echo -e "${BLUE}Criando Kubernetes Secrets para ambiente: $env${NC}"

    # Extrair variáveis de banco
    local db_user=$(grep "^POSTGRES_USER=" "$env_file" | cut -d'=' -f2)
    local db_pass=$(grep "^POSTGRES_PASSWORD=" "$env_file" | cut -d'=' -f2)

    kubectl create secret generic condohome-db-secret \
        --namespace=condohome \
        --from-literal=username="$db_user" \
        --from-literal=password="$db_pass" \
        --dry-run=client -o yaml | kubectl apply -f -

    echo -e "${GREEN}condohome-db-secret criado/atualizado${NC}"

    # Extrair variáveis de API
    local asaas_key=$(grep "^ASAAS_API_KEY=" "$env_file" | cut -d'=' -f2)
    local openai_key=$(grep "^OPENAI_API_KEY=" "$env_file" | cut -d'=' -f2)
    local mail_user=$(grep "^MAIL_USERNAME=" "$env_file" | cut -d'=' -f2)
    local mail_pass=$(grep "^MAIL_PASSWORD=" "$env_file" | cut -d'=' -f2)
    local evolution_key=$(grep "^EVOLUTION_API_KEY=" "$env_file" | cut -d'=' -f2)
    local n8n_pass=$(grep "^N8N_PASSWORD=" "$env_file" | cut -d'=' -f2)

    kubectl create secret generic condohome-api-secrets \
        --namespace=condohome \
        --from-literal=asaas-api-key="${asaas_key:-}" \
        --from-literal=openai-api-key="${openai_key:-}" \
        --from-literal=mail-username="${mail_user:-}" \
        --from-literal=mail-password="${mail_pass:-}" \
        --from-literal=evolution-api-key="${evolution_key:-}" \
        --from-literal=n8n-password="${n8n_pass:-}" \
        --dry-run=client -o yaml | kubectl apply -f -

    echo -e "${GREEN}condohome-api-secrets criado/atualizado${NC}"
}

generate_template() {
    echo -e "${BLUE}Gerando template de variáveis de ambiente...${NC}"
    cat <<'EOF'
# =====================================================
# CondoHome Platform - Environment Variables Template
# Preencha os valores e salve como .env.<ambiente>
# =====================================================

# --- PostgreSQL ---
POSTGRES_USER=condohome
POSTGRES_PASSWORD=CHANGE_ME
POSTGRES_PORT=5432

# --- Redis ---
REDIS_PORT=6379

# --- Service Ports ---
GATEWAY_PORT=8080
REGISTER_PORT=8081
BILLING_PORT=8082
DOCUMENTS_PORT=8083
AI_ASSISTANT_PORT=8085
NOTIFICATION_PORT=8086
BOOKING_PORT=8087
FINANCE_PORT=8088
N8N_PORT=5678

# --- Docker Image Tag ---
TAG=latest

# --- Billing (Asaas) ---
ASAAS_API_KEY=CHANGE_ME
ASAAS_ENVIRONMENT=sandbox

# --- AI Assistant (OpenAI) ---
OPENAI_API_KEY=CHANGE_ME

# --- Notification (Email SMTP) ---
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=CHANGE_ME
MAIL_PASSWORD=CHANGE_ME

# --- Notification (WhatsApp Evolution API) ---
EVOLUTION_API_URL=CHANGE_ME
EVOLUTION_API_KEY=CHANGE_ME
EVOLUTION_INSTANCE=CHANGE_ME

# --- N8N ---
N8N_USER=admin
N8N_PASSWORD=CHANGE_ME

# --- CORS ---
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173
EOF
}

# Main
case "${1:-}" in
    github-set)   github_set_secrets "$2" ;;
    github-list)  github_list_secrets ;;
    k8s-create)   k8s_create_secrets "$2" "$3" ;;
    validate)     validate_env "$2" ;;
    template)     generate_template ;;
    *)            usage ;;
esac
