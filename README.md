# Self-Hosting Infrastructure

Declarative infrastructure-as-code for a Rocky Linux VPS using Ansible, Podman Quadlets, and Nginx.

## Architecture

All services run as rootless Podman containers managed by systemd Quadlets. Nginx acts as a reverse proxy with automated Let's Encrypt SSL. Firewalld restricts external access to ports 80, 443, and 51413 (torrents) only. A WireGuard VPN provides direct access to the server.

### Services

| Service | Subdomain | Purpose | Internal Port |
|---------|-----------|---------|---------------|
| Joplin Server | `notes.<your-domain>` | Note-taking and sync | 22300 |
| Jellyfin | `media.<your-domain>` | Media streaming | 8096 |
| Nextcloud | `cloud.<your-domain>` | Files, calendar, tasks | 8083 |
| n8n | `automation.<your-domain>` | Workflow automation | 5678 |
| HedgeDoc | `docs.<your-domain>` | Collaborative markdown | 3000 |
| Transmission | `torrent.<your-domain>` | Torrent client | 8082 |
| Evolution API | *(no vhost)* | WhatsApp API | 8080 |

Each service can be individually enabled or disabled — see [Enabling / Disabling Services](#enabling--disabling-services).

## Prerequisites

- Ansible 2.9+ and `ansible-vault` on your local machine
- SSH key access to the server (`ssh-copy-id root@<server>`)
- DNS A records pointing to your server IP:

```
notes.<your-domain>       → <your-server-ip>
media.<your-domain>       → <your-server-ip>
cloud.<your-domain>       → <your-server-ip>
automation.<your-domain>  → <your-server-ip>
docs.<your-domain>        → <your-server-ip>
torrent.<your-domain>     → <your-server-ip>
```

## First-Time Setup

### 1. Configure inventory

```bash
cp inventory/hosts.example.yml inventory/hosts.yml
```

Edit `inventory/hosts.yml` and set your server IP.

### 2. Configure secrets

```bash
cp vars/secrets-template.yml vars/secrets.yml
# Edit vars/secrets.yml — fill in all values including domain, passwords, WireGuard keys
ansible-vault encrypt vars/secrets.yml
```

See `vars/secrets-template.yml` for all required fields.

### 3. Deploy

```bash
make deploy
```

Or step by step:

```bash
make check          # test SSH connectivity first
./scripts/deploy.sh
```

## Enabling / Disabling Services

Edit the `services` list in `vars/config.yml` and set `enabled: true/false`:

```yaml
services:
  - name: hedgedoc
    enabled: false   # skips quadlet deploy, volumes, nginx, and SSL cert
    ...
```

Re-run `make deploy` to apply.

## Management

### Run only a specific role

```bash
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml --tags podman
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml --tags nginx
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml --tags services
```

### Edit secrets

```bash
ansible-vault edit vars/secrets.yml
```

### View service logs

```bash
journalctl -u joplin.service -f
journalctl -u hedgedoc.service -f
# etc.
```

### Restart a service

```bash
systemctl restart nextcloud.service
```

### Update all container images

Podman auto-update runs on a systemd timer. To trigger it manually:

```bash
podman auto-update
```

## Backup & Restore

### Backup

```bash
make backup
```

Backups are stored at `/var/backups/selfhosting/` on the server (7-day retention).

### Restore

1. Copy backup archive to the server
2. Extract to the appropriate volume path under `/var/lib/containers/storage/volumes/`
3. `systemctl restart <service>.service`

## Security

- **Firewalld**: Only ports 80, 443, and 51413 exposed externally
- **WireGuard**: VPN for direct server access without exposing extra ports
- **SSL/TLS**: Automated Let's Encrypt certificates with auto-renewal
- **Fail2ban**: Brute-force protection
- **Rootless Podman**: Containers run without root privileges
- **Ansible Vault**: All secrets (domain, passwords, keys) encrypted at rest
- **No plaintext secrets in git**: `inventory/hosts.yml` and `vars/secrets.yml` are gitignored

## Troubleshooting

### Service won't start

```bash
systemctl status <service>.service
journalctl -u <service>.service -n 50

# If quadlet wasn't deployed (unit not found):
systemctl daemon-reload
systemctl start <service>.service
```

### SSL certificate issues

```bash
certbot --nginx -d subdomain.<your-domain>   # manually request
certbot certificates                          # check expiry
certbot renew --force-renewal                 # force renewal
```

### Nginx

```bash
nginx -t
systemctl reload nginx
```

### Firewall

```bash
firewall-cmd --list-all
firewall-cmd --reload
```

### Container networking

```bash
podman ps -a
podman logs <container-name>
ss -tlnp | grep <port>
```

## Adding a New Service

1. Create `quadlets/<name>.container`
2. Add a service entry to `vars/config.yml` → `services:`
3. If web-facing: create `roles/nginx/templates/<subdomain>.conf.j2`
4. If secrets needed: add to `vars/secrets-template.yml` and `ansible-vault edit vars/secrets.yml`
5. `make deploy`

## Resources

- [Podman Quadlets](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Ansible Documentation](https://docs.ansible.com/)
- [Certbot Documentation](https://eff-certbot.readthedocs.io/)
- [Rocky Linux Firewalld Guide](https://docs.rockylinux.org/guides/security/firewalld/)
