#!/bin/bash
#
# Quick start guide for first-time setup
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT"

SERVER_IP=$(grep 'ansible_host:' inventory/hosts.yml | awk '{print $2}')
DOMAIN=$(grep 'domain:' inventory/hosts.yml | head -1 | awk '{print $2}')
SERVER_USER=$(grep 'ansible_user:' inventory/hosts.yml | awk '{print $2}')

echo "=================================================="
echo "VPS Infrastructure - Quick Start"
echo "=================================================="
echo ""
echo "This script will help you get started with deploying your VPS infrastructure."
echo ""

# Step 1: Create secrets file
if [ ! -f "vars/secrets.yml" ]; then
    echo "Step 1: Creating secrets file..."
    cp vars/secrets-template.yml vars/secrets.yml
    echo "Please edit vars/secrets.yml and update all CHANGE_ME values with strong passwords."
    echo ""
    read -p "Press Enter after you've edited vars/secrets.yml..."
    
    # Encrypt the secrets file
    echo "Encrypting secrets file..."
    ansible-vault encrypt vars/secrets.yml
    echo "Secrets file encrypted successfully!"
else
    echo "Step 1: Secrets file already exists (skipping)"
fi

echo ""

# Step 2: Test SSH connection
echo "Step 2: Testing SSH connection to server ($SERVER_USER@$SERVER_IP)..."
ssh -o ConnectTimeout=5 "$SERVER_USER@$SERVER_IP" "echo 'Connection successful!'" || {
    echo "ERROR: Cannot connect to server"
    echo "Please ensure:"
    echo "  1. Your SSH key is added: ssh-copy-id $SERVER_USER@$SERVER_IP"
    echo "  2. The server is accessible from your network"
    exit 1
}

echo ""

# Step 3: Check DNS
echo "Step 3: Verifying DNS records..."
for subdomain in notes torrent media cloud automation docs; do
    IP=$(dig +short ${subdomain}.${DOMAIN} | head -n 1)
    if [ "$IP" == "$SERVER_IP" ]; then
        echo "  ✓ ${subdomain}.${DOMAIN} → $IP"
    else
        echo "  ✗ ${subdomain}.${DOMAIN} → $IP (expected $SERVER_IP)"
        echo "    WARNING: SSL certificate generation may fail for this subdomain"
    fi
done

echo ""

# Step 4: Deploy
echo "Step 4: Ready to deploy!"
echo ""
echo "Run the deployment with:"
echo "  ./scripts/deploy.sh"
echo ""
read -p "Deploy now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./scripts/deploy.sh
fi
