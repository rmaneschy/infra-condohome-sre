#!/bin/bash
# =====================================================
# CondoHome Platform - Secrets Management
# Gerencia secrets para diferentes ambientes
# Suporta: GitHub Environment Secrets, Kubernetes Secrets,
#          Repository Secrets, .env files
# =====================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    "n8n-nodes-condohome"
    "portal-condohome-web"
    "infra-condohome-sre"
    "infra-condohome-cicd"
)

ENVIRONMENTS=("development" "staging" "production")

usage() {
    echo -e "${BLUE}CondoHome - Secrets Manager (GitHub Environments)${NC}"
    echo ""
    echo "Uso: $0 <comando> [opções]"
    echo ""
    echo -e "${CYAN}GitHub Environment Secrets:${NC}"
    echo "  env-set <environment> <secrets_file>   Definir secrets em um GitHub Environment"
    echo "  env-list <environment>                 Listar secrets de um Environment"
    echo "  env-set-repo <repo> <env> <file>       Definir secrets em um repo específico"
    echo ""
    echo -e "${CYAN}GitHub Repository Secrets (global):${NC}"
    echo "  repo-set <secrets_file>                Definir secrets globais (todos os repos)"
    echo "  repo-list                              Listar secrets globais de todos os repos"
    echo ""
    echo -e "${CYAN}Kubernetes:${NC}"
    echo "  k8s-create <environment> <env_file>    Criar Kubernetes Secrets"
    echo "  k8s-rotate <environment>               Rotacionar secrets no Kubernetes"
    echo ""
    echo -e "${CYAN}Utilitários:${NC}"
    echo "  validate <secrets_file>                Validar se todas as secrets estão preenchidas"
    echo "  template                               Gerar template de secrets"
    echo "  audit                                  Auditar secrets em todos os repos e environments"
    echo ""
    echo -e "${YELLOW}Melhores Práticas:${NC}"
    echo "  - Use Environment Secrets para valores que variam por ambiente"
    echo "  - Use Repository Secrets apenas para valores compartilhados"
    echo "  - NUNCA commite arquivos .secrets no repositório"
    echo "  - Rotacione secrets a cada 90 dias"
    echo ""
}

# =====================================================
# GitHub Environment Secrets
# =====================================================
env_set_secrets() {
    local env_name="$1"
    local secrets_file="$2"

    if [ ! -f "$secrets_file" ]; then
        echo -e "${RED}Arquivo não encontrado: $secrets_file${NC}"
        exit 1
    fi

    # Validar environment
    local valid_env=false
    for e in "${ENVIRONMENTS[@]}"; do
        [ "$e" = "$env_name" ] && valid_env=true
    done
    if [ "$valid_env" = false ]; then
        echo -e "${RED}Environment inválido: $env_name (use: development, staging, production)${NC}"
        exit 1
    fi

    echo -e "${BLUE}Configurando Environment Secrets para '$env_name'...${NC}"
    echo ""

    for repo in "${REPOS[@]}"; do
        echo -e "${CYAN}--- $repo ---${NC}"
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ ]] && continue
            [[ -z "$key" ]] && continue

            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)

            if [ -n "$value" ] && [ "$value" != "CHANGE_ME" ]; then
                echo -n "  $key ... "
                if gh secret set "$key" \
                    --repo "$GITHUB_ORG/$repo" \
                    --env "$env_name" \
                    --body "$value" 2>/dev/null; then
                    echo -e "${GREEN}OK${NC}"
                else
                    echo -e "${RED}FAIL${NC}"
                fi
            fi
        done < "$secrets_file"
        echo ""
    done
}

env_set_repo_secrets() {
    local repo="$1"
    local env_name="$2"
    local secrets_file="$3"

    if [ ! -f "$secrets_file" ]; then
        echo -e "${RED}Arquivo não encontrado: $secrets_file${NC}"
        exit 1
    fi

    echo -e "${BLUE}Configurando Environment Secrets para '$env_name' em $repo...${NC}"

    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue

        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        if [ -n "$value" ] && [ "$value" != "CHANGE_ME" ]; then
            echo -n "  $key ... "
            if gh secret set "$key" \
                --repo "$GITHUB_ORG/$repo" \
                --env "$env_name" \
                --body "$value" 2>/dev/null; then
                echo -e "${GREEN}OK${NC}"
            else
                echo -e "${RED}FAIL${NC}"
            fi
        fi
    done < "$secrets_file"
}

env_list_secrets() {
    local env_name="$1"

    echo -e "${BLUE}Environment Secrets para '$env_name':${NC}"
    echo ""

    for repo in "${REPOS[@]}"; do
        echo -e "${CYAN}--- $repo ---${NC}"
        gh secret list --repo "$GITHUB_ORG/$repo" --env "$env_name" 2>/dev/null \
            || echo -e "  ${YELLOW}Sem acesso, environment não existe, ou sem secrets${NC}"
        echo ""
    done
}

# =====================================================
# GitHub Repository Secrets (global)
# =====================================================
repo_set_secrets() {
    local secrets_file="$1"

    if [ ! -f "$secrets_file" ]; then
        echo -e "${RED}Arquivo não encontrado: $secrets_file${NC}"
        exit 1
    fi

    echo -e "${BLUE}Configurando Repository Secrets (globais)...${NC}"
    echo ""

    for repo in "${REPOS[@]}"; do
        echo -e "${CYAN}--- $repo ---${NC}"
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ ]] && continue
            [[ -z "$key" ]] && continue

            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)

            if [ -n "$value" ] && [ "$value" != "CHANGE_ME" ]; then
                echo -n "  $key ... "
                if gh secret set "$key" \
                    --repo "$GITHUB_ORG/$repo" \
                    --body "$value" 2>/dev/null; then
                    echo -e "${GREEN}OK${NC}"
                else
                    echo -e "${RED}FAIL${NC}"
                fi
            fi
        done < "$secrets_file"
        echo ""
    done
}

repo_list_secrets() {
    echo -e "${BLUE}Repository Secrets (globais) por repositório:${NC}"
    echo ""
    for repo in "${REPOS[@]}"; do
        echo -e "${CYAN}--- $repo ---${NC}"
        gh secret list --repo "$GITHUB_ORG/$repo" 2>/dev/null \
            || echo -e "  ${YELLOW}Sem acesso ou repo não encontrado${NC}"
        echo ""
    done
}

# =====================================================
# Kubernetes Secrets
# =====================================================
k8s_create_secrets() {
    local env="$1"
    local env_file="$2"

    if [ ! -f "$env_file" ]; then
        echo -e "${RED}Arquivo não encontrado: $env_file${NC}"
        exit 1
    fi

    local namespace="condohome-${env}"
    echo -e "${BLUE}Criando Kubernetes Secrets para ambiente: $env (namespace: $namespace)${NC}"

    # Criar namespace se não existir
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -

    # Database secrets
    local db_user=$(grep "^POSTGRES_USER=" "$env_file" | cut -d'=' -f2 | xargs)
    local db_pass=$(grep "^POSTGRES_PASSWORD=" "$env_file" | cut -d'=' -f2 | xargs)
    local db_password="${db_pass:-$(grep "^DB_PASSWORD=" "$env_file" | cut -d'=' -f2 | xargs)}"

    kubectl create secret generic condohome-db-secret \
        --namespace="$namespace" \
        --from-literal=username="${db_user:-condohome}" \
        --from-literal=password="${db_password}" \
        --dry-run=client -o yaml | kubectl apply -f -
    echo -e "${GREEN}condohome-db-secret criado/atualizado${NC}"

    # API secrets
    local asaas_key=$(grep "^ASAAS_API_KEY=" "$env_file" | cut -d'=' -f2 | xargs)
    local openai_key=$(grep "^OPENAI_API_KEY=" "$env_file" | cut -d'=' -f2 | xargs)
    local mail_user=$(grep "^MAIL_USERNAME=" "$env_file" | cut -d'=' -f2 | xargs)
    local mail_pass=$(grep "^MAIL_PASSWORD=" "$env_file" | cut -d'=' -f2 | xargs)
    local evolution_key=$(grep "^EVOLUTION_API_KEY=" "$env_file" | cut -d'=' -f2 | xargs)
    local evolution_url=$(grep "^EVOLUTION_API_URL=" "$env_file" | cut -d'=' -f2 | xargs)
    local n8n_pass=$(grep "^N8N_PASSWORD=" "$env_file" | cut -d'=' -f2 | xargs)
    local jwt_secret=$(grep "^JWT_SECRET=" "$env_file" | cut -d'=' -f2 | xargs)

    kubectl create secret generic condohome-api-secrets \
        --namespace="$namespace" \
        --from-literal=asaas-api-key="${asaas_key:-}" \
        --from-literal=openai-api-key="${openai_key:-}" \
        --from-literal=mail-username="${mail_user:-}" \
        --from-literal=mail-password="${mail_pass:-}" \
        --from-literal=evolution-api-key="${evolution_key:-}" \
        --from-literal=evolution-api-url="${evolution_url:-}" \
        --from-literal=n8n-password="${n8n_pass:-}" \
        --from-literal=jwt-secret="${jwt_secret:-}" \
        --dry-run=client -o yaml | kubectl apply -f -
    echo -e "${GREEN}condohome-api-secrets criado/atualizado${NC}"
}

k8s_rotate_secrets() {
    local env="$1"
    local namespace="condohome-${env}"

    echo -e "${BLUE}Rotacionando secrets no namespace: $namespace${NC}"
    echo -e "${YELLOW}Listando secrets atuais:${NC}"
    kubectl get secrets -n "$namespace" 2>/dev/null || echo -e "${RED}Namespace não encontrado${NC}"
    echo ""
    echo -e "${YELLOW}Para rotacionar, execute:${NC}"
    echo "  $0 k8s-create $env <novo_arquivo_secrets>"
}

# =====================================================
# Utilitários
# =====================================================
validate_env() {
    local env_file="$1"
    if [ ! -f "$env_file" ]; then
        echo -e "${RED}Arquivo não encontrado: $env_file${NC}"
        exit 1
    fi

    echo -e "${BLUE}Validando secrets em: $env_file${NC}"
    local missing=0
    local total=0

    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue

        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        ((total++))

        if [ -z "$value" ] || [ "$value" = "CHANGE_ME" ]; then
            echo -e "  ${RED}[MISSING] $key${NC}"
            ((missing++))
        else
            echo -e "  ${GREEN}[OK]      $key${NC}"
        fi
    done < "$env_file"

    echo ""
    echo -e "Total: $total | Configuradas: $((total - missing)) | Faltando: $missing"
    if [ $missing -gt 0 ]; then
        echo -e "${RED}$missing secrets não configuradas!${NC}"
        return 1
    else
        echo -e "${GREEN}Todas as secrets estão configuradas.${NC}"
        return 0
    fi
}

audit_secrets() {
    echo -e "${BLUE}Auditoria de Secrets - GitHub Environments${NC}"
    echo ""

    printf "%-35s %-15s %-15s %-15s %-15s\n" "REPOSITÓRIO" "Repo Secrets" "development" "staging" "production"
    printf "%-35s %-15s %-15s %-15s %-15s\n" "---" "---" "---" "---" "---"

    for repo in "${REPOS[@]}"; do
        local repo_count=$(gh secret list --repo "$GITHUB_ORG/$repo" 2>/dev/null | wc -l)
        local dev_count=$(gh secret list --repo "$GITHUB_ORG/$repo" --env development 2>/dev/null | wc -l)
        local stg_count=$(gh secret list --repo "$GITHUB_ORG/$repo" --env staging 2>/dev/null | wc -l)
        local prd_count=$(gh secret list --repo "$GITHUB_ORG/$repo" --env production 2>/dev/null | wc -l)

        printf "%-35s %-15s %-15s %-15s %-15s\n" "$repo" "$repo_count" "$dev_count" "$stg_count" "$prd_count"
    done
}

generate_template() {
    echo -e "${BLUE}Gerando template de secrets...${NC}"
    cat <<'EOF'
# =====================================================
# CondoHome Platform - Secrets Template
# Copie para <environment>.secrets e preencha os valores
# NUNCA commite este arquivo com valores reais!
#
# Hierarquia de secrets (GitHub):
#   1. Environment Secrets  -> Específicos por ambiente
#   2. Repository Secrets   -> Compartilhados no repo
#   3. Organization Secrets -> Compartilhados na org
#
# Recomendação:
#   - DB_PASSWORD, API keys -> Environment Secrets
#   - GITHUB_TOKEN          -> Automático (não precisa configurar)
# =====================================================

# --- Database ---
DB_PASSWORD=CHANGE_ME

# --- Billing (Asaas) ---
ASAAS_API_KEY=CHANGE_ME

# --- AI Assistant (OpenAI) ---
OPENAI_API_KEY=CHANGE_ME

# --- Notification (Email SMTP) ---
MAIL_USERNAME=CHANGE_ME
MAIL_PASSWORD=CHANGE_ME

# --- Notification (WhatsApp Evolution API) ---
EVOLUTION_API_URL=CHANGE_ME
EVOLUTION_API_KEY=CHANGE_ME
EVOLUTION_INSTANCE=CHANGE_ME

# --- Notification (WhatsApp Meta Cloud API) ---
META_WHATSAPP_TOKEN=CHANGE_ME
META_WHATSAPP_PHONE_ID=CHANGE_ME

# --- Notification (Firebase Push) ---
FIREBASE_CREDENTIALS_JSON=CHANGE_ME

# --- N8N ---
N8N_PASSWORD=CHANGE_ME

# --- JWT / Auth ---
JWT_SECRET=CHANGE_ME
EOF
}

# Main
case "${1:-}" in
    env-set)       env_set_secrets "$2" "$3" ;;
    env-set-repo)  env_set_repo_secrets "$2" "$3" "$4" ;;
    env-list)      env_list_secrets "$2" ;;
    repo-set)      repo_set_secrets "$2" ;;
    repo-list)     repo_list_secrets ;;
    k8s-create)    k8s_create_secrets "$2" "$3" ;;
    k8s-rotate)    k8s_rotate_secrets "$2" ;;
    validate)      validate_env "$2" ;;
    audit)         audit_secrets ;;
    template)      generate_template ;;
    *)             usage ;;
esac
