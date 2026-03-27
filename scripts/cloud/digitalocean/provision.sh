#!/bin/bash
# =====================================================
# CondoHome Platform - DigitalOcean Provisioning
# Provisiona um Droplet ou cluster DOKS para a plataforma
# =====================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLUSTER_NAME="${CLUSTER_NAME:-condohome-k8s}"
REGION="${REGION:-nyc1}"
NODE_SIZE="${NODE_SIZE:-s-2vcpu-4gb}"
NODE_COUNT="${NODE_COUNT:-2}"

usage() {
    echo -e "${BLUE}CondoHome - DigitalOcean Provisioning${NC}"
    echo ""
    echo "Uso: $0 <modo>"
    echo ""
    echo "Modos:"
    echo "  droplet     Provisionar Droplet (VPS) com Docker Compose"
    echo "  kubernetes  Provisionar cluster DOKS (Kubernetes)"
    echo ""
    echo "Pré-requisitos:"
    echo "  - doctl CLI instalado e autenticado"
    echo "  - Token de API do DigitalOcean configurado"
    echo ""
}

provision_droplet() {
    echo -e "${BLUE}Criando Droplet DigitalOcean...${NC}"

    # Criar Droplet
    doctl compute droplet create condohome-server \
        --image ubuntu-22-04-x64 \
        --size "$NODE_SIZE" \
        --region "$REGION" \
        --ssh-keys "$(doctl compute ssh-key list --format ID --no-header | head -1)" \
        --tag-name condohome \
        --user-data-file "$(dirname "$0")/../hostinger/provision.sh" \
        --wait

    DROPLET_IP=$(doctl compute droplet get condohome-server --format PublicIPv4 --no-header)
    echo -e "${GREEN}Droplet criado! IP: $DROPLET_IP${NC}"
    echo ""
    echo -e "Próximos passos:"
    echo -e "  1. SSH: ssh root@$DROPLET_IP"
    echo -e "  2. Execute o script de provisioning manualmente se user-data falhou"
    echo -e "  3. Configure DNS: api.condohome.com.br -> $DROPLET_IP"
}

provision_kubernetes() {
    echo -e "${BLUE}Criando cluster Kubernetes (DOKS)...${NC}"

    # Criar cluster
    doctl kubernetes cluster create "$CLUSTER_NAME" \
        --region "$REGION" \
        --size "$NODE_SIZE" \
        --count "$NODE_COUNT" \
        --tag condohome \
        --wait

    # Configurar kubeconfig
    doctl kubernetes cluster kubeconfig save "$CLUSTER_NAME"

    echo -e "${GREEN}Cluster criado!${NC}"

    # Instalar Nginx Ingress Controller
    echo -e "${BLUE}Instalando Nginx Ingress Controller...${NC}"
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/do/deploy.yaml

    # Instalar cert-manager
    echo -e "${BLUE}Instalando cert-manager...${NC}"
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml

    echo ""
    echo -e "${GREEN}Cluster Kubernetes pronto!${NC}"
    echo -e "Próximos passos:"
    echo -e "  1. Configure secrets: ./scripts/secrets/manage-secrets.sh k8s-create production .env.production"
    echo -e "  2. Deploy: kubectl apply -k kubernetes/overlays/production"
    echo -e "  3. Configure DNS para o Load Balancer IP"
}

case "${1:-}" in
    droplet)    provision_droplet ;;
    kubernetes) provision_kubernetes ;;
    *)          usage ;;
esac
