#!/bin/bash
# WireGuard Key Generator Script
# Run this to generate server and client keypairs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SERVER_IP=$(grep 'ansible_host:' "$REPO_ROOT/inventory/hosts.yml" | awk '{print $2}')

echo "===================================="
echo "WireGuard Key Generator"
echo "===================================="
echo ""

# Generate server keys
echo "Generating SERVER keys..."
SERVER_PRIVATE_KEY=$(wg genkey)
SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)

echo ""
echo "SERVER Keys:"
echo "------------"
echo "Private Key: $SERVER_PRIVATE_KEY"
echo "Public Key:  $SERVER_PUBLIC_KEY"
echo ""

# Generate client keys
echo "Generating CLIENT keys..."
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

echo ""
echo "CLIENT Keys:"
echo "------------"
echo "Private Key: $CLIENT_PRIVATE_KEY"
echo "Public Key:  $CLIENT_PUBLIC_KEY"
echo ""

# Display configuration instructions
echo "===================================="
echo "Configuration Instructions"
echo "===================================="
echo ""
echo "1. Add to vars/secrets.yml (encrypted with ansible-vault):"
echo "   wireguard_server_private_key: \"$SERVER_PRIVATE_KEY\""
echo ""
echo "   wireguard_peers:"
echo "     - name: \"My Laptop\""
echo "       public_key: \"$CLIENT_PUBLIC_KEY\""
echo "       allowed_ips: 10.200.0.2/32"
echo ""
echo "2. Create client config file (save as wg-client.conf):"
echo ""
echo "[Interface]"
echo "PrivateKey = $CLIENT_PRIVATE_KEY"
echo "Address = 10.200.0.2/32"
echo "DNS = 1.1.1.1"
echo ""
echo "[Peer]"
echo "PublicKey = $SERVER_PUBLIC_KEY"
echo "Endpoint = ${SERVER_IP}:51820"
echo "AllowedIPs = 10.200.0.0/24, 127.0.0.1/32"
echo "PersistentKeepalive = 25"
echo ""
echo "3. Import wg-client.conf to your WireGuard client app"
echo ""
echo "===================================="
