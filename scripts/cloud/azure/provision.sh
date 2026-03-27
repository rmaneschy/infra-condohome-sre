#!/bin/bash
# =====================================================
# CondoHome Platform - Azure Provisioning
# Provisiona recursos no Azure (VM ou AKS)
# =====================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

RESOURCE_GROUP="${RESOURCE_GROUP:-condohome-rg}"
LOCATION="${LOCATION:-brazilsouth}"
CLUSTER_NAME="${CLUSTER_NAME:-condohome-aks}"
VM_SIZE="${VM_SIZE:-Standard_B2ms}"
NODE_COUNT="${NODE_COUNT:-2}"

usage() {
    echo -e "${BLUE}CondoHome - Azure Provisioning${NC}"
    echo ""
    echo "Uso: $0 <modo>"
    echo ""
    echo "Modos:"
    echo "  vm          Provisionar VM com Docker Compose"
    echo "  aks         Provisionar cluster AKS (Kubernetes)"
    echo "  acr         Criar Azure Container Registry"
    echo ""
    echo "Pré-requisitos:"
    echo "  - Azure CLI (az) instalado e autenticado"
    echo ""
}

create_resource_group() {
    echo -e "${BLUE}Criando Resource Group: $RESOURCE_GROUP...${NC}"
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
}

provision_vm() {
    create_resource_group

    echo -e "${BLUE}Criando VM Azure...${NC}"

    az vm create \
        --resource-group "$RESOURCE_GROUP" \
        --name condohome-server \
        --image Ubuntu2204 \
        --size "$VM_SIZE" \
        --admin-username azureuser \
        --generate-ssh-keys \
        --public-ip-sku Standard \
        --tags project=condohome

    # Abrir portas
    az vm open-port --resource-group "$RESOURCE_GROUP" --name condohome-server --port 80,443,8080

    VM_IP=$(az vm show -d --resource-group "$RESOURCE_GROUP" --name condohome-server --query publicIps -o tsv)
    echo -e "${GREEN}VM criada! IP: $VM_IP${NC}"
    echo ""
    echo -e "Próximos passos:"
    echo -e "  1. SSH: ssh azureuser@$VM_IP"
    echo -e "  2. Execute: bash provision-hostinger.sh (mesmo script funciona)"
    echo -e "  3. Configure DNS: api.condohome.com.br -> $VM_IP"
}

provision_aks() {
    create_resource_group

    echo -e "${BLUE}Criando cluster AKS...${NC}"

    az aks create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --node-count "$NODE_COUNT" \
        --node-vm-size "$VM_SIZE" \
        --enable-managed-identity \
        --generate-ssh-keys \
        --tags project=condohome

    # Configurar kubeconfig
    az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME"

    echo -e "${GREEN}Cluster AKS criado!${NC}"

    # Instalar Nginx Ingress
    echo -e "${BLUE}Instalando Nginx Ingress Controller...${NC}"
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml

    # Instalar cert-manager
    echo -e "${BLUE}Instalando cert-manager...${NC}"
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml

    echo ""
    echo -e "${GREEN}AKS pronto!${NC}"
    echo -e "Próximos passos:"
    echo -e "  1. Configure secrets: ./scripts/secrets/manage-secrets.sh k8s-create production .env.production"
    echo -e "  2. Deploy: kubectl apply -k kubernetes/overlays/production"
}

provision_acr() {
    create_resource_group

    echo -e "${BLUE}Criando Azure Container Registry...${NC}"

    az acr create \
        --resource-group "$RESOURCE_GROUP" \
        --name condohomecr \
        --sku Basic

    echo -e "${GREEN}ACR criado: condohomecr.azurecr.io${NC}"
    echo -e "Login: az acr login --name condohomecr"
}

case "${1:-}" in
    vm)   provision_vm ;;
    aks)  provision_aks ;;
    acr)  provision_acr ;;
    *)    usage ;;
esac
