---
name: selfhosting
description: >
  Guidelines for maintaining the selfhosting Ansible project. Covers the mandatory
  checklist for adding, modifying, and removing container services so that no file
  is ever missed, and explains the data-driven services list that controls deployment.
---

# Selfhosting Ansible Project – Skill Guide

## Project Layout

```
Selfhosting/
├── quadlets/               # Podman Quadlet .container / .network files (Jinja2 templates)
├── vars/
│   ├── config.yml          # Non-secret config: domain, ports, volumes, services list
│   └── secrets.yml         # Vault-encrypted secrets (use secrets-template.yml as reference)
├── roles/
│   ├── podman/tasks/main.yml   # Installs Podman, creates volumes, deploys quadlets
│   ├── services/tasks/main.yml # Starts / enables systemd units, health-checks ports
│   └── nginx/tasks/main.yml    # Deploys & enables nginx vhost configs + Certbot
├── roles/nginx/templates/  # Jinja2 .conf.j2 nginx vhost templates
├── playbooks/bootstrap.yml # Master playbook (role order: podman → nginx → services)
├── scripts/deploy.sh       # Runs the bootstrap playbook
└── Makefile                # make deploy / make check / make backup
```

> **Role execution order matters**: `podman` (copies quadlets → `/etc/containers/systemd/`,
> systemd daemon-reload runs via handler) **must run before** `services` (starts the
> generated `.service` units). Never reorder these roles.

---

## The `services` List — Central Toggle

All three roles (`podman`, `services`, `nginx`) are data-driven off a single `services`
list in `vars/config.yml`. **To disable a service entirely, set `enabled: false`.**
No other files need touching.

```yaml
# vars/config.yml
services:
  - name: hedgedoc
    enabled: false   # ← quadlets not deployed, volumes not created, nginx skipped
    quadlets: [hedgedoc-db.container, hedgedoc.container]
    volumes: [{name: hedgedoc-db}, {name: hedgedoc}]
    systemd: [hedgedoc-db.service, hedgedoc.service]
    health_port: 3000
    subdomain: docs  # omit this key entirely if no nginx vhost is needed
```

Each entry's fields:

| Field | Type | Purpose |
|-------|------|---------|
| `name` | string | Human label |
| `enabled` | bool | Master toggle — `false` skips everything |
| `quadlets` | list[str] | Quadlet filenames under `quadlets/` |
| `volumes` | list[{name, owner?}] | Volume dir names under `volumes.base`; `owner` sets UID/GID |
| `systemd` | list[str] | systemd unit names to start/enable |
| `health_port` | int | Port to wait on after start (omit if not applicable) |
| `subdomain` | str | nginx template slug + subdomain (omit if no vhost needed) |

---

## Checklist: Adding a New Service

| # | File | What to do |
|---|------|------------|
| 1 | `quadlets/<name>.container` | Create the Quadlet file (Jinja2 variables allowed) |
| 2 | `vars/config.yml` → `services:` | Add a new entry with all fields; set `enabled: true` |
| 3 | `vars/config.yml` → `ports:` | Add internal port (informational — used in docs/scripts) |

**If the service is web-facing (has an nginx vhost):**

| # | File | What to do |
|---|------|------------|
| 4 | `roles/nginx/templates/<subdomain>.conf.j2` | Create nginx vhost template |
| 5 | Service entry in `vars/config.yml` | Add `subdomain: <slug>` — the roles pick it up automatically |

**If the service needs secrets:**

| # | File | What to do |
|---|------|------------|
| 6 | `vars/secrets-template.yml` | Document the new secret keys |
| 7 | `vars/secrets.yml` (vault) | Add actual values: `ansible-vault edit vars/secrets.yml` |

That's it. The `podman`, `services`, and `nginx` roles loop over the `services` list
automatically — no changes needed inside the role files.

---

## Checklist: Removing a Service

1. Set `enabled: false` in `vars/config.yml` (safe, non-destructive — redeploy skips it)
2. To fully remove: delete the service entry from `vars/config.yml`
3. Delete `quadlets/<name>.container`
4. Delete `roles/nginx/templates/<subdomain>.conf.j2` if it existed
5. Remove any secret keys from `vars/secrets-template.yml` and `vars/secrets.yml`
6. Delete server-side volumes if no longer needed:
   ```bash
   ssh root@<server> 'rm -rf /var/lib/containers/storage/volumes/<name>'
   ```

---

## Common Gotchas

### "Could not find the requested service X.service: host"
**Cause**: The quadlet file was not deployed to `/etc/containers/systemd/` — either the
service entry is missing from `vars/config.yml` or `enabled` is `false`.

**Fix**: Ensure the service entry exists with `enabled: true` and `quadlets` lists the
correct filename, then re-run `make deploy`.

### Quadlet file uses Jinja2 variables
All files under `quadlets/` are passed through Ansible's `template` module, so
`{{ variable }}` syntax works. Variables must exist in `vars/config.yml` or
`vars/secrets.yml` before deployment.

### Services start before secrets are configured
The `ignore_errors: yes` on the service start loop is intentional — at first run,
vault secrets may not be populated. After adding secrets, run the services role again:
```bash
ansible-playbook playbooks/bootstrap.yml --tags services
```

### nginx vhost slug vs service name
The `subdomain` field in the service entry must exactly match the `.conf.j2` filename:
`roles/nginx/templates/<subdomain>.conf.j2`.

### Stale volume entries in vars/config.yml
`vars/config.yml` still contains a legacy `volumes:` dict with per-volume full paths.
These are no longer used by any role (roles now derive paths as `volumes.base/<name>`)
but are harmless. Remove them for hygiene when convenient.

---

## Deployment Commands

```bash
# Full deploy
make deploy
# or: ./scripts/deploy.sh

# Test connectivity only
make check

# Run a specific role only
ansible-playbook playbooks/bootstrap.yml --tags podman
ansible-playbook playbooks/bootstrap.yml --tags services
ansible-playbook playbooks/bootstrap.yml --tags nginx

# Edit encrypted secrets
ansible-vault edit vars/secrets.yml

# Check service status on server
ssh root@<server> 'systemctl status hedgedoc.service'

# Force systemd to regenerate units from quadlets (if quadlets changed manually)
ssh root@<server> 'systemctl daemon-reload'
```

---

## Active Services (as of 2026-03-16)

| Service | Quadlet file | Nginx slug | Internal port |
|---------|-------------|------------|---------------|
| Joplin DB | `joplin-db.container` | — | 5433 |
| Joplin | `joplin.container` | `notes` | 22300 |
| Transmission | `transmission.container` | `torrent` | 8082 |
| Nextcloud DB | `nextcloud-db.container` | — | 5432 |
| Nextcloud | `nextcloud.container` | `cloud` | 8083 |
| n8n | `n8n.container` | `automation` | 5678 |
| Evolution API | `evolution-api.container` | — | 8080 |
| HedgeDoc DB | `hedgedoc-db.container` | — | — |
| HedgeDoc | `hedgedoc.container` | `docs` | 3000 |
| Jellyfin | `jellyfin.container` | `media` | 8096 |
