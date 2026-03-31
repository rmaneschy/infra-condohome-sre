#!/bin/bash
# =====================================================
# CondoHome Platform - Requirements Validator
# Valida pré-requisitos de acordo com o ambiente
# e retorna instruções de como resolver apontamentos
#
# Uso:
#   bash scripts/validate-requirements.sh local
#   bash scripts/validate-requirements.sh vps
#   bash scripts/validate-requirements.sh k8s
#   bash scripts/validate-requirements.sh ci
#
# Autor: Debug Software
# =====================================================
set -euo pipefail

# =====================================================
# Cores e formatação
# =====================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# =====================================================
# Detecção de SO
# =====================================================
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if grep -qi microsoft /proc/version 2>/dev/null; then
            OS="wsl"
            OS_LABEL="WSL (Windows Subsystem for Linux)"
        elif [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                ubuntu|debian) OS="debian" ; OS_LABEL="$PRETTY_NAME" ;;
                fedora|rhel|centos|rocky|alma) OS="rhel" ; OS_LABEL="$PRETTY_NAME" ;;
                arch|manjaro) OS="arch" ; OS_LABEL="$PRETTY_NAME" ;;
                alpine) OS="alpine" ; OS_LABEL="$PRETTY_NAME" ;;
                *) OS="linux" ; OS_LABEL="$PRETTY_NAME" ;;
            esac
        else
            OS="linux"
            OS_LABEL="Linux (desconhecido)"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        OS_LABEL="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
    else
        OS="unknown"
        OS_LABEL="Sistema Operacional não identificado"
    fi
}

# =====================================================
# Funções de log
# =====================================================
log_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}$1${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
}

log_section() {
    echo ""
    echo -e "${BLUE}── $1 ──${NC}"
}

log_pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo -e "  ${GREEN}✓${NC} $1"
}

log_warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    echo -e "  ${YELLOW}⚠${NC} $1"
}

log_fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo -e "  ${RED}✗${NC} $1"
}

log_fix() {
    echo -e "    ${YELLOW}→ Solução:${NC} $1"
}

log_fix_multi() {
    echo -e "    ${YELLOW}→ Solução:${NC}"
    while IFS= read -r line; do
        echo -e "      $line"
    done <<< "$1"
}

# =====================================================
# Funções de verificação de comandos
# =====================================================
check_command() {
    local cmd="$1"
    local label="${2:-$cmd}"
    local min_version="${3:-}"

    if ! command -v "$cmd" &>/dev/null; then
        log_fail "$label não encontrado"
        install_instructions "$cmd"
        return 1
    fi

    if [ -n "$min_version" ]; then
        local current_version
        current_version=$(get_version "$cmd")
        if [ -n "$current_version" ]; then
            if version_lt "$current_version" "$min_version"; then
                log_warn "$label encontrado (v$current_version), mas versão mínima é v$min_version"
                install_instructions "$cmd"
                return 1
            fi
            log_pass "$label v$current_version (>= v$min_version)"
        else
            log_pass "$label encontrado (versão não detectada)"
        fi
    else
        log_pass "$label encontrado"
    fi
    return 0
}

get_version() {
    local cmd="$1"
    case "$cmd" in
        docker)
            docker version --format '{{.Server.Version}}' 2>/dev/null || \
            docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        "docker compose")
            docker compose version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        make)
            make --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+' | head -1
            ;;
        bash)
            bash --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        curl)
            curl --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        python3)
            python3 --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        git)
            git --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        kubectl)
            kubectl version --client --short 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || \
            kubectl version --client -o json 2>/dev/null | grep -oP '"gitVersion":\s*"v\K[\d.]+' | head -1
            ;;
        node)
            node --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        java)
            java -version 2>&1 | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1 || \
            java -version 2>&1 | head -1 | grep -oP '"(\d+)' | tr -d '"' | head -1
            ;;
        gh)
            gh --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        nginx)
            nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        certbot)
            certbot --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        *)
            echo ""
            ;;
    esac
}

version_lt() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ] && [ "$1" != "$2" ]
}

# =====================================================
# Instruções de instalação por SO
# =====================================================
install_instructions() {
    local tool="$1"

    case "$tool" in
        docker)
            case "$OS" in
                debian|wsl)
                    log_fix_multi "$(cat <<'EOF'
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
EOF
)"
                    ;;
                rhel)
                    log_fix_multi "$(cat <<'EOF'
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl start docker && sudo systemctl enable docker
sudo usermod -aG docker $USER
EOF
)"
                    ;;
                arch)
                    log_fix_multi "$(cat <<'EOF'
sudo pacman -S docker docker-compose docker-buildx
sudo systemctl start docker && sudo systemctl enable docker
sudo usermod -aG docker $USER
EOF
)"
                    ;;
                macos)
                    log_fix "brew install --cask docker  # ou baixe Docker Desktop em https://www.docker.com/products/docker-desktop"
                    ;;
                alpine)
                    log_fix_multi "$(cat <<'EOF'
sudo apk add docker docker-cli-compose
sudo rc-update add docker default
sudo service docker start
sudo addgroup $USER docker
EOF
)"
                    ;;
                *)
                    log_fix "Acesse https://docs.docker.com/engine/install/ para instruções de instalação"
                    ;;
            esac
            ;;

        "docker compose")
            case "$OS" in
                debian|wsl)
                    log_fix "sudo apt-get install -y docker-compose-plugin"
                    ;;
                rhel)
                    log_fix "sudo dnf install -y docker-compose-plugin"
                    ;;
                macos)
                    log_fix "Docker Compose já vem incluído no Docker Desktop. Atualize o Docker Desktop."
                    ;;
                *)
                    log_fix "Acesse https://docs.docker.com/compose/install/ para instruções"
                    ;;
            esac
            ;;

        make)
            case "$OS" in
                debian|wsl) log_fix "sudo apt-get install -y make" ;;
                rhel) log_fix "sudo dnf install -y make" ;;
                arch) log_fix "sudo pacman -S make" ;;
                macos) log_fix "xcode-select --install  # ou: brew install make" ;;
                alpine) log_fix "sudo apk add make" ;;
                *) log_fix "Instale o GNU Make para seu sistema operacional" ;;
            esac
            ;;

        bash)
            case "$OS" in
                macos) log_fix "brew install bash  # macOS vem com Bash 3.x, recomendamos 5.x" ;;
                *) log_fix "Bash geralmente já vem instalado. Verifique sua instalação do sistema." ;;
            esac
            ;;

        curl)
            case "$OS" in
                debian|wsl) log_fix "sudo apt-get install -y curl" ;;
                rhel) log_fix "sudo dnf install -y curl" ;;
                arch) log_fix "sudo pacman -S curl" ;;
                alpine) log_fix "sudo apk add curl" ;;
                macos) log_fix "brew install curl" ;;
                *) log_fix "Instale curl para seu sistema operacional" ;;
            esac
            ;;

        python3)
            case "$OS" in
                debian|wsl) log_fix "sudo apt-get install -y python3" ;;
                rhel) log_fix "sudo dnf install -y python3" ;;
                arch) log_fix "sudo pacman -S python" ;;
                alpine) log_fix "sudo apk add python3" ;;
                macos) log_fix "brew install python3" ;;
                *) log_fix "Instale Python 3.x para seu sistema operacional" ;;
            esac
            ;;

        git)
            case "$OS" in
                debian|wsl) log_fix "sudo apt-get install -y git" ;;
                rhel) log_fix "sudo dnf install -y git" ;;
                arch) log_fix "sudo pacman -S git" ;;
                alpine) log_fix "sudo apk add git" ;;
                macos) log_fix "brew install git  # ou: xcode-select --install" ;;
                *) log_fix "Acesse https://git-scm.com/downloads para instruções" ;;
            esac
            ;;

        gh)
            case "$OS" in
                debian|wsl)
                    log_fix_multi "$(cat <<'EOF'
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update && sudo apt-get install -y gh
EOF
)"
                    ;;
                rhel) log_fix "sudo dnf install -y gh" ;;
                arch) log_fix "sudo pacman -S github-cli" ;;
                macos) log_fix "brew install gh" ;;
                *) log_fix "Acesse https://cli.github.com/ para instruções" ;;
            esac
            ;;

        kubectl)
            case "$OS" in
                debian|wsl)
                    log_fix_multi "$(cat <<'EOF'
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
EOF
)"
                    ;;
                rhel)
                    log_fix_multi "$(cat <<'EOF'
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
EOF
)"
                    ;;
                macos) log_fix "brew install kubectl" ;;
                *) log_fix "Acesse https://kubernetes.io/docs/tasks/tools/ para instruções" ;;
            esac
            ;;

        node)
            case "$OS" in
                debian|wsl)
                    log_fix_multi "$(cat <<'EOF'
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
EOF
)"
                    ;;
                rhel)
                    log_fix_multi "$(cat <<'EOF'
curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
sudo dnf install -y nodejs
EOF
)"
                    ;;
                macos) log_fix "brew install node@22" ;;
                *) log_fix "Acesse https://nodejs.org/ para instruções" ;;
            esac
            ;;

        java)
            case "$OS" in
                debian|wsl) log_fix "sudo apt-get install -y openjdk-21-jdk" ;;
                rhel) log_fix "sudo dnf install -y java-21-openjdk-devel" ;;
                arch) log_fix "sudo pacman -S jdk21-openjdk" ;;
                macos) log_fix "brew install openjdk@21" ;;
                alpine) log_fix "sudo apk add openjdk21" ;;
                *) log_fix "Acesse https://adoptium.net/ para instruções" ;;
            esac
            ;;

        nginx)
            case "$OS" in
                debian|wsl) log_fix "sudo apt-get install -y nginx" ;;
                rhel) log_fix "sudo dnf install -y nginx" ;;
                macos) log_fix "brew install nginx" ;;
                alpine) log_fix "sudo apk add nginx" ;;
                *) log_fix "Acesse https://nginx.org/en/linux_packages.html para instruções" ;;
            esac
            ;;

        certbot)
            case "$OS" in
                debian|wsl) log_fix "sudo apt-get install -y certbot python3-certbot-nginx" ;;
                rhel) log_fix "sudo dnf install -y certbot python3-certbot-nginx" ;;
                macos) log_fix "brew install certbot" ;;
                *) log_fix "Acesse https://certbot.eff.org/ para instruções" ;;
            esac
            ;;

        jq)
            case "$OS" in
                debian|wsl) log_fix "sudo apt-get install -y jq" ;;
                rhel) log_fix "sudo dnf install -y jq" ;;
                arch) log_fix "sudo pacman -S jq" ;;
                macos) log_fix "brew install jq" ;;
                alpine) log_fix "sudo apk add jq" ;;
                *) log_fix "Acesse https://jqlang.github.io/jq/download/ para instruções" ;;
            esac
            ;;

        *)
            log_fix "Instale '$tool' manualmente para seu sistema operacional"
            ;;
    esac
}

# =====================================================
# Verificações específicas
# =====================================================
check_docker_running() {
    if docker info &>/dev/null; then
        log_pass "Docker daemon está rodando"
    else
        log_fail "Docker daemon não está rodando"
        case "$OS" in
            debian|rhel|linux)
                log_fix "sudo systemctl start docker && sudo systemctl enable docker"
                ;;
            wsl)
                log_fix_multi "$(cat <<'EOF'
Opção 1 (Docker Desktop): Abra o Docker Desktop no Windows
Opção 2 (dockerd nativo): sudo service docker start
EOF
)"
                ;;
            macos)
                log_fix "Abra o Docker Desktop ou execute: open -a Docker"
                ;;
        esac
        return 1
    fi
}

check_docker_compose_plugin() {
    if docker compose version &>/dev/null; then
        local version
        version=$(docker compose version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
        if [ -n "$version" ]; then
            if version_lt "$version" "2.20.0"; then
                log_warn "Docker Compose v$version encontrado, recomendado >= v2.20.0"
                install_instructions "docker compose"
                return 1
            fi
            log_pass "Docker Compose Plugin v$version (>= v2.20.0)"
        else
            log_pass "Docker Compose Plugin encontrado"
        fi
    else
        log_fail "Docker Compose Plugin não encontrado"
        install_instructions "docker compose"
        return 1
    fi
}

check_ports() {
    local ports=("$@")
    for port in "${ports[@]}"; do
        if ss -tlnp 2>/dev/null | grep -q ":${port} " || \
           netstat -tlnp 2>/dev/null | grep -q ":${port} " || \
           lsof -i ":${port}" &>/dev/null; then
            log_warn "Porta $port já está em uso"
            log_fix "Verifique qual processo usa a porta: sudo lsof -i :$port"
        else
            log_pass "Porta $port disponível"
        fi
    done
}

check_env_file() {
    local env="$1"
    local env_file=""

    case "$env" in
        local) env_file="configs/envs/.env.local" ;;
        staging) env_file="configs/envs/.env.staging" ;;
        production) env_file="configs/envs/.env.production" ;;
    esac

    if [ -z "$env_file" ]; then
        return 0
    fi

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local sre_dir
    sre_dir="$(dirname "$script_dir")"

    local full_path="$sre_dir/$env_file"
    local example_path="${full_path}.example"

    if [ ! -f "$full_path" ]; then
        log_fail "Arquivo de ambiente não encontrado: $env_file"
        if [ -f "$example_path" ]; then
            log_fix "cp $env_file.example $env_file && nano $env_file"
        else
            log_fix "Crie o arquivo $env_file baseado no template .env.local.example"
        fi
        return 1
    fi

    log_pass "Arquivo de ambiente encontrado: $env_file"

    # Verificar variáveis obrigatórias
    local required_vars=("POSTGRES_USER" "POSTGRES_PASSWORD")
    local warn_vars=("ASAAS_API_KEY" "OPENAI_API_KEY")

    for var in "${required_vars[@]}"; do
        local val
        val=$(grep "^${var}=" "$full_path" 2>/dev/null | cut -d'=' -f2-)
        if [ -z "$val" ] || [ "$val" = "CHANGE_ME" ] || [ "$val" = "CHANGE_ME_POSTGRES_PASSWORD" ]; then
            log_fail "Variável obrigatória '$var' não configurada em $env_file"
            log_fix "Edite $env_file e preencha o valor de $var"
        fi
    done

    for var in "${warn_vars[@]}"; do
        local val
        val=$(grep "^${var}=" "$full_path" 2>/dev/null | cut -d'=' -f2-)
        if [ -z "$val" ] || [[ "$val" == CHANGE_ME* ]]; then
            log_warn "Variável '$var' não configurada em $env_file (funcionalidade limitada)"
        fi
    done
}

check_disk_space() {
    local min_gb="${1:-5}"
    local available_gb
    available_gb=$(df -BG / 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G')

    if [ -n "$available_gb" ] && [ "$available_gb" -lt "$min_gb" ]; then
        log_warn "Espaço em disco baixo: ${available_gb}GB disponível (mínimo recomendado: ${min_gb}GB)"
        log_fix "Libere espaço: docker system prune -a --volumes"
    else
        log_pass "Espaço em disco: ${available_gb:-?}GB disponível (mínimo: ${min_gb}GB)"
    fi
}

check_memory() {
    local min_mb="${1:-2048}"
    local available_mb
    available_mb=$(free -m 2>/dev/null | awk '/^Mem:/ {print $7}')

    if [ -n "$available_mb" ]; then
        if [ "$available_mb" -lt "$min_mb" ]; then
            log_warn "Memória disponível: ${available_mb}MB (mínimo recomendado: ${min_mb}MB)"
            log_fix "Feche aplicações desnecessárias ou aumente a memória da VM/WSL"
        else
            log_pass "Memória disponível: ${available_mb}MB (mínimo: ${min_mb}MB)"
        fi
    fi
}

check_line_endings() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local sre_dir
    sre_dir="$(dirname "$script_dir")"

    local crlf_count=0
    while IFS= read -r -d '' file; do
        if file "$file" | grep -q "CRLF"; then
            crlf_count=$((crlf_count + 1))
        fi
    done < <(find "$sre_dir/scripts" -type f -name "*.sh" -print0 2>/dev/null)

    if [ "$crlf_count" -gt 0 ]; then
        log_fail "$crlf_count script(s) com final de linha CRLF (Windows)"
        case "$OS" in
            debian|wsl|rhel|arch)
                log_fix_multi "$(cat <<'EOF'
sudo apt-get install -y dos2unix  # ou: sudo dnf install dos2unix
find scripts/ -name "*.sh" -exec dos2unix {} \;
EOF
)"
                ;;
            macos)
                log_fix_multi "$(cat <<'EOF'
brew install dos2unix
find scripts/ -name "*.sh" -exec dos2unix {} \;
EOF
)"
                ;;
            *)
                log_fix "Converta os scripts para LF: sed -i 's/\r$//' scripts/**/*.sh"
                ;;
        esac
    else
        log_pass "Todos os scripts usam final de linha LF (Unix)"
    fi
}

check_git_config() {
    if git config --global core.autocrlf &>/dev/null; then
        local autocrlf
        autocrlf=$(git config --global core.autocrlf)
        if [ "$autocrlf" = "true" ]; then
            log_warn "git core.autocrlf=true pode causar problemas de CRLF"
            log_fix "git config --global core.autocrlf input"
        else
            log_pass "git core.autocrlf=$autocrlf"
        fi
    fi

    if [ -f ".gitattributes" ]; then
        log_pass ".gitattributes presente no repositório"
    else
        log_warn ".gitattributes não encontrado"
        log_fix "Adicione: echo '* text=auto eol=lf' > .gitattributes && git add .gitattributes"
    fi
}

# =====================================================
# Validações por ambiente
# =====================================================
validate_local() {
    log_header "Validação: Ambiente LOCAL (Desenvolvimento)"
    echo -e "  SO detectado: ${BOLD}$OS_LABEL${NC}"

    log_section "Ferramentas Essenciais"
    check_command "docker" "Docker Engine" "24.0.0"
    check_docker_running
    check_docker_compose_plugin
    check_command "make" "GNU Make"
    check_command "bash" "Bash" "4.0.0"
    check_command "curl" "cURL"
    check_command "python3" "Python 3" "3.8.0"
    check_command "git" "Git" "2.30.0"
    check_command "jq" "jq (JSON processor)"

    log_section "Ferramentas Opcionais (Build Local)"
    check_command "java" "JDK (para build dos microserviços)" "21.0.0" || true
    check_command "node" "Node.js (para build do frontend)" "20.0.0" || true
    check_command "gh" "GitHub CLI" || true

    log_section "Portas Críticas"
    check_ports 5432 6379 5433 8000 8001 8002 8080

    log_section "Recursos do Sistema"
    check_disk_space 10
    check_memory 4096

    log_section "Configuração de Ambiente"
    check_env_file "local"
    check_line_endings
    check_git_config
}

validate_vps() {
    log_header "Validação: Ambiente VPS (Staging/Production)"
    echo -e "  SO detectado: ${BOLD}$OS_LABEL${NC}"

    log_section "Ferramentas Essenciais"
    check_command "docker" "Docker Engine" "24.0.0"
    check_docker_running
    check_docker_compose_plugin
    check_command "bash" "Bash"
    check_command "curl" "cURL"
    check_command "python3" "Python 3"
    check_command "git" "Git"

    log_section "Ferramentas de Servidor"
    check_command "nginx" "Nginx (reverse proxy)"
    check_command "certbot" "Certbot (SSL/TLS)"

    log_section "Portas Críticas"
    check_ports 80 443 5432 6379 5433 8000 8001

    log_section "Recursos do Sistema"
    check_disk_space 20
    check_memory 4096

    log_section "Segurança"
    if command -v ufw &>/dev/null; then
        if ufw status 2>/dev/null | grep -q "active"; then
            log_pass "Firewall (UFW) está ativo"
            # Verificar se portas essenciais estão abertas
            for port in 22 80 443; do
                if ufw status 2>/dev/null | grep -q "$port"; then
                    log_pass "Porta $port permitida no firewall"
                else
                    log_warn "Porta $port pode não estar aberta no firewall"
                    log_fix "sudo ufw allow $port"
                fi
            done
        else
            log_warn "Firewall (UFW) não está ativo"
            log_fix_multi "$(cat <<'EOF'
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
EOF
)"
        fi
    else
        log_warn "UFW não encontrado"
        case "$OS" in
            debian|wsl) log_fix "sudo apt-get install -y ufw" ;;
            *) log_fix "Configure o firewall do seu sistema operacional" ;;
        esac
    fi

    log_section "Configuração de Ambiente"
    check_env_file "production"
    check_line_endings

    log_section "Docker Registry"
    if docker info 2>/dev/null | grep -q "ghcr.io"; then
        log_pass "Autenticado no GitHub Container Registry (GHCR)"
    else
        log_warn "Não autenticado no GHCR"
        log_fix 'echo $CR_PAT | docker login ghcr.io -u SEU_USUARIO --password-stdin'
    fi
}

validate_k8s() {
    log_header "Validação: Ambiente KUBERNETES"
    echo -e "  SO detectado: ${BOLD}$OS_LABEL${NC}"

    log_section "Ferramentas Essenciais"
    check_command "kubectl" "kubectl" "1.26.0"
    check_command "bash" "Bash"
    check_command "curl" "cURL"
    check_command "git" "Git"

    log_section "Conexão com Cluster"
    if kubectl cluster-info &>/dev/null; then
        log_pass "Conectado ao cluster Kubernetes"
        local server
        server=$(kubectl cluster-info 2>/dev/null | head -1 | grep -oP 'https?://[^\s]+' || echo "desconhecido")
        echo -e "    Cluster: $server"
    else
        log_fail "Não conectado a nenhum cluster Kubernetes"
        log_fix_multi "$(cat <<'EOF'
Verifique o arquivo ~/.kube/config
Para AKS:  az aks get-credentials --resource-group RG --name CLUSTER
Para DOKS: doctl kubernetes cluster kubeconfig save CLUSTER
Para EKS:  aws eks update-kubeconfig --name CLUSTER
EOF
)"
    fi

    log_section "Componentes do Cluster"
    # Verificar namespace
    if kubectl get namespace condohome &>/dev/null; then
        log_pass "Namespace 'condohome' existe"
    else
        log_warn "Namespace 'condohome' não existe"
        log_fix "kubectl create namespace condohome"
    fi

    # Verificar Ingress Controller
    if kubectl get pods -n ingress-nginx 2>/dev/null | grep -q "Running"; then
        log_pass "NGINX Ingress Controller rodando"
    elif kubectl get pods -A 2>/dev/null | grep -qi "ingress.*running"; then
        log_pass "Ingress Controller encontrado"
    else
        log_warn "Ingress Controller não encontrado"
        log_fix_multi "$(cat <<'EOF'
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml
EOF
)"
    fi

    # Verificar Cert-Manager
    if kubectl get pods -n cert-manager 2>/dev/null | grep -q "Running"; then
        log_pass "Cert-Manager rodando"
    else
        log_warn "Cert-Manager não encontrado (necessário para SSL automático)"
        log_fix_multi "$(cat <<'EOF'
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
EOF
)"
    fi

    log_section "Secrets"
    if kubectl get secrets -n condohome 2>/dev/null | grep -q "condohome"; then
        log_pass "Secrets do CondoHome configurados no namespace"
    else
        log_warn "Secrets do CondoHome não encontrados no namespace"
        log_fix "make k8s-secrets ENV=staging FILE=staging.secrets"
    fi
}

validate_ci() {
    log_header "Validação: Ambiente CI/CD"
    echo -e "  SO detectado: ${BOLD}$OS_LABEL${NC}"

    log_section "Ferramentas Essenciais"
    check_command "docker" "Docker Engine"
    check_docker_running
    check_docker_compose_plugin
    check_command "git" "Git"
    check_command "curl" "cURL"

    log_section "Ferramentas de Build"
    check_command "java" "JDK" "21.0.0" || true
    check_command "node" "Node.js" "20.0.0" || true
    check_command "gh" "GitHub CLI"

    log_section "Autenticação"
    if gh auth status &>/dev/null; then
        log_pass "GitHub CLI autenticado"
    else
        log_warn "GitHub CLI não autenticado"
        log_fix "gh auth login"
    fi
}

# =====================================================
# Resumo final
# =====================================================
print_summary() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${BOLD} Resumo da Validação${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}✓ Passou:${NC}   $PASS_COUNT"
    echo -e "  ${YELLOW}⚠ Avisos:${NC}   $WARN_COUNT"
    echo -e "  ${RED}✗ Falhou:${NC}   $FAIL_COUNT"
    echo ""

    if [ "$FAIL_COUNT" -eq 0 ] && [ "$WARN_COUNT" -eq 0 ]; then
        echo -e "  ${GREEN}${BOLD}Ambiente pronto para uso!${NC}"
    elif [ "$FAIL_COUNT" -eq 0 ]; then
        echo -e "  ${YELLOW}${BOLD}Ambiente funcional, mas com avisos. Revise os itens acima.${NC}"
    else
        echo -e "  ${RED}${BOLD}Ambiente com problemas. Corrija os itens marcados com ✗ antes de prosseguir.${NC}"
    fi
    echo ""
}

# =====================================================
# Main
# =====================================================
usage() {
    echo "Uso: $0 <ambiente>"
    echo ""
    echo "Ambientes disponíveis:"
    echo "  local    - Desenvolvimento local (Docker Compose)"
    echo "  vps      - Servidor VPS (Hostinger, DigitalOcean, Azure VM)"
    echo "  k8s      - Kubernetes (AKS, DOKS, EKS, etc)"
    echo "  ci       - Pipeline CI/CD (GitHub Actions)"
    echo ""
    echo "Exemplos:"
    echo "  $0 local"
    echo "  $0 vps"
    echo "  $0 k8s"
}

main() {
    local env="${1:-}"

    if [ -z "$env" ]; then
        usage
        exit 1
    fi

    detect_os

    case "$env" in
        local|dev|development)
            validate_local
            ;;
        vps|server|staging|production|prod)
            validate_vps
            ;;
        k8s|kubernetes|cluster)
            validate_k8s
            ;;
        ci|cicd|pipeline)
            validate_ci
            ;;
        *)
            echo -e "${RED}Ambiente desconhecido: $env${NC}"
            echo ""
            usage
            exit 1
            ;;
    esac

    print_summary

    if [ "$FAIL_COUNT" -gt 0 ]; then
        exit 1
    fi
    exit 0
}

main "$@"
