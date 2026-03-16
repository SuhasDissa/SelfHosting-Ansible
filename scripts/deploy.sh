#!/bin/bash
#
# Deploy script for VPS infrastructure
# Usage: ./deploy.sh [--tags TAG1,TAG2]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"

echo "=================================================="
echo "VPS Infrastructure Deployment"
echo "=================================================="
echo ""

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "ERROR: ansible-playbook not found. Please install Ansible."
    exit 1
fi

# Check if inventory exists
if [ ! -f "inventory/hosts.yml" ]; then
    echo "ERROR: inventory/hosts.yml not found."
    exit 1
fi

# Check if secrets file exists
if [ ! -f "vars/secrets.yml" ]; then
    echo "WARNING: vars/secrets.yml not found."
    echo "Please create it from vars/secrets-template.yml and encrypt with:"
    echo "  cp vars/secrets-template.yml vars/secrets.yml"
    echo "  # Edit vars/secrets.yml with your actual values"
    echo "  ansible-vault encrypt vars/secrets.yml"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Parse command line arguments
TAGS=""
if [ "$1" == "--tags" ] && [ -n "$2" ]; then
    TAGS="--tags $2"
fi

# Test connection first
echo "Testing connection to server..."
ansible all -m ping -i inventory/hosts.yml

if [ $? -ne 0 ]; then
    echo "ERROR: Cannot connect to server. Check your SSH configuration."
    exit 1
fi

echo ""
echo "Connection successful!"
echo ""

# Run the playbook
echo "Starting deployment..."
echo ""

if [ -f ".vault_pass" ]; then
    echo "Using .vault_pass file for vault password"
    ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml $TAGS
else
    echo "Enter vault password when prompted"
    ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml --ask-vault-pass $TAGS
fi

echo ""
echo "=================================================="
echo "Deployment complete!"
echo "=================================================="
echo ""
DOMAIN=$(grep 'domain:' inventory/hosts.yml | head -1 | awk '{print $2}')

echo "Next steps:"
echo "1. Verify DNS records are pointing to your server"
echo "2. Access services via their subdomains:"
echo "   - https://notes.${DOMAIN} (Joplin Server)"
echo "   - https://media.${DOMAIN} (Jellyfin)"
echo "   - https://cloud.${DOMAIN} (Nextcloud)"
echo "   - https://automation.${DOMAIN} (n8n)"
echo "   - https://docs.${DOMAIN} (HedgeDoc)"
echo "3. Complete service-specific setup wizards"
echo ""
