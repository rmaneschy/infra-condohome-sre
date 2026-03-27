#!/bin/bash
# =====================================================
# CondoHome Platform - Hostinger VPS Provisioning
# Provisiona uma VPS Hostinger para rodar a plataforma
# Requisitos: Ubuntu 22.04+, 4GB RAM mínimo
# =====================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="${DOMAIN:-condohome.com.br}"
EMAIL="${EMAIL:-admin@condohome.com.br}"

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}  CondoHome - Hostinger VPS Provisioning${NC}"
echo -e "${BLUE}=================================================${NC}"

# 1. Atualizar sistema
echo -e "\n${BLUE}[1/7] Atualizando sistema...${NC}"
sudo apt-get update -y && sudo apt-get upgrade -y

# 2. Instalar Docker
echo -e "\n${BLUE}[2/7] Instalando Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    echo -e "${GREEN}Docker instalado!${NC}"
else
    echo -e "${GREEN}Docker já instalado.${NC}"
fi

# 3. Instalar Docker Compose
echo -e "\n${BLUE}[3/7] Instalando Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
    sudo apt-get install -y docker-compose-plugin
    echo -e "${GREEN}Docker Compose instalado!${NC}"
else
    echo -e "${GREEN}Docker Compose já instalado.${NC}"
fi

# 4. Instalar Nginx
echo -e "\n${BLUE}[4/7] Instalando Nginx...${NC}"
sudo apt-get install -y nginx
sudo systemctl enable nginx

# 5. Instalar Certbot (SSL)
echo -e "\n${BLUE}[5/7] Instalando Certbot...${NC}"
sudo apt-get install -y certbot python3-certbot-nginx

# 6. Configurar Firewall
echo -e "\n${BLUE}[6/7] Configurando Firewall...${NC}"
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# 7. Criar diretórios
echo -e "\n${BLUE}[7/7] Criando diretórios...${NC}"
sudo mkdir -p /opt/condohome
sudo chown $USER:$USER /opt/condohome

echo -e "\n${GREEN}=================================================${NC}"
echo -e "${GREEN}  Provisionamento concluído!${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""
echo -e "Próximos passos:"
echo -e "  1. Clone o repositório SRE: git clone https://github.com/rmaneschy/infra-condohome-sre.git /opt/condohome/sre"
echo -e "  2. Configure o .env: cp /opt/condohome/sre/configs/envs/.env.production /opt/condohome/.env"
echo -e "  3. Edite as credenciais: nano /opt/condohome/.env"
echo -e "  4. Copie o nginx config: sudo cp /opt/condohome/sre/configs/nginx/condohome.conf /etc/nginx/sites-available/"
echo -e "  5. Ative o site: sudo ln -s /etc/nginx/sites-available/condohome.conf /etc/nginx/sites-enabled/"
echo -e "  6. Gere SSL: sudo certbot --nginx -d api.${DOMAIN} -d n8n.${DOMAIN} --email ${EMAIL}"
echo -e "  7. Inicie: cd /opt/condohome/sre && ./scripts/local/start.sh full"
