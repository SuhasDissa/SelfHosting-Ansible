# VPS Self-Hosting Infrastructure

Declarative infrastructure-as-code for bootstrapping a Rocky Linux VPS with self-hosted services using Ansible, Podman Quadlets, and Nginx reverse proxy.

## 🏗️ Architecture

All services run as rootless Podman containers managed by systemd Quadlets. Nginx acts as a reverse proxy with automated SSL/TLS certificates from Let's Encrypt. Firewalld restricts external access to only ports 80 and 443.

### Services

| Service | Subdomain | Purpose | Port (Internal) |
|---------|-----------|---------|-----------------|
| Joplin Server | notes.<your-domain> | Note-taking and sync | 22300 |
| FreshRSS | rss.<your-domain> | RSS feed reader | 80 |
| Full-Text-RSS | ftr.<your-domain> | Full article extraction | 80 |
| Transmission | torrent.<your-domain> | Torrent client | 9091 |
| Jellyfin | media.<your-domain> | Media streaming | 8096 |
| Nextcloud | cloud.<your-domain> | Calendar, tasks, files | 80 |
| n8n | automation.<your-domain> | Workflow automation | 5678 |

## 📋 Prerequisites

### DNS Records
Create A records pointing to your server IP (<your-server-ip>):
```
notes.<your-domain>       → <your-server-ip>
rss.<your-domain>         → <your-server-ip>
ftr.<your-domain>         → <your-server-ip>
torrent.<your-domain>     → <your-server-ip>
media.<your-domain>       → <your-server-ip>
cloud.<your-domain>       → <your-server-ip>
automation.<your-domain>  → <your-server-ip>
```

### Local Setup
- Ansible 2.9+ installed
- SSH key access to the server
- Python 3.8+ on the control machine

## 🚀 Initial Deployment

### 1. Configure Secrets
Create and encrypt the secrets file:
```bash
ansible-vault create vars/secrets.yml
```

Add the following content (replace with your own values):
```yaml
# Database passwords
nextcloud_db_password: "your-secure-password"

# Joplin database credentials
joplin_db_user: "joplin"
joplin_db_password: "your-secure-password"
joplin_db_name: "joplin"

# SSL certificate email
certbot_email: "your-email@example.com"
```

### 2. Review Configuration
Edit `vars/config.yml` to adjust any non-sensitive settings (paths, ports, etc.)

### 3. Test Connection
```bash
ansible all -m ping -i inventory/hosts.yml
```

### 4. Deploy
Run the bootstrap playbook:
```bash
./scripts/deploy.sh
```

Or manually:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml --ask-vault-pass
```

### 5. Post-Deployment
After successful deployment:
- Access each service via its subdomain (HTTPS)
- Complete service-specific setup (e.g., Nextcloud wizard, n8n credentials)
- Configure Joplin desktop/mobile apps with `https://notes.<your-domain>`

## 🔧 Management

### Update a Service
1. Edit the Quadlet file in `quadlets/`
2. Run the deployment:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml --tags=services --ask-vault-pass
```

### Add a New Service
1. Create Quadlet file in `quadlets/`
2. Create Nginx site config in `nginx/sites/`
3. Add subdomain to `vars/config.yml`
4. Update firewalld rules if needed in `roles/firewalld/tasks/main.yml`
5. Deploy

### View Service Logs
SSH into the server and use systemd:
```bash
journalctl -u joplin.service -f
journalctl -u miniflux.service -f
# etc.
```

### Restart a Service
```bash
systemctl restart joplin.service
```

## 💾 Backup & Restore

### Backup
Run the backup script:
```bash
ssh root@<your-server-ip> '/opt/selfhosting/backup.sh'
```

This creates backups in `/var/backups/selfhosting/`

### Restore
1. Copy backup to server
2. Extract to appropriate volume locations
3. Restart services

## 🔒 Security

- **Firewalld**: Only ports 80/443 exposed externally
- **SSL/TLS**: Automated Let's Encrypt certificates with auto-renewal
- **Fail2ban**: Protects against brute-force attacks
- **Rootless Podman**: Services run without root privileges
- **Ansible Vault**: Sensitive data encrypted at rest

## 🐛 Troubleshooting

### Service Won't Start
```bash
# Check service status
systemctl status service-name.service

# View logs
journalctl -u service-name.service -n 50

# Verify Quadlet syntax
podman-system-service --dry-run
```

### SSL Certificate Issues
```bash
# Manually request certificate
certbot --nginx -d subdomain.<your-domain>

# Check certificate expiry
certbot certificates

# Force renewal
certbot renew --force-renewal
```

### Nginx Configuration Test
```bash
nginx -t
systemctl reload nginx
```

### Firewall Debugging
```bash
# List all rules
firewall-cmd --list-all

# Check if port is open
firewall-cmd --query-port=443/tcp

# Reload firewall
firewall-cmd --reload
```

### Container Networking
```bash
# List containers
podman ps -a

# Inspect container
podman inspect container-name

# Check if port is listening
ss -tlnp | grep 8080
```

## 📁 Directory Structure

```
/var/lib/containers/storage/volumes/  # Podman volumes
├── joplin/
├── joplin-db/
├── miniflux-db/
├── qbittorrent-config/
├── qbittorrent-downloads/
├── jellyfin-config/
├── jellyfin-media/
├── nextcloud/
├── nextcloud-db/
└── n8n/
```

## 🔄 Updates

### Update All Containers
```bash
# SSH to server
ssh root@<your-server-ip>

# Pull latest images and restart
for service in joplin joplin-db miniflux qbittorrent jellyfin nextcloud n8n; do
    systemctl restart ${service}.service
done
```

## 📚 Resources

- [Podman Quadlets Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Ansible Documentation](https://docs.ansible.com/)
- [Rocky Linux Firewalld Guide](https://docs.rockylinux.org/guides/security/firewalld/)
- [Certbot Documentation](https://eff-certbot.readthedocs.io/)

## 📝 License

MIT License - Feel free to use and modify for your own infrastructure.
