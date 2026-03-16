# Makefile for VPS infrastructure management

.PHONY: help deploy check backup clean

help:
	@echo "VPS Infrastructure Management"
	@echo "=============================="
	@echo ""
	@echo "Available targets:"
	@echo "  make check      - Test connection and verify prerequisites"
	@echo "  make deploy     - Deploy full infrastructure"
	@echo "  make backup     - Create backup of all services"
	@echo "  make quickstart - Run first-time setup wizard"
	@echo "  make clean      - Clean temporary files"
	@echo ""

check:
	@echo "Checking prerequisites..."
	@ansible all -m ping -i inventory/hosts.yml
	@echo "Connection test passed!"

deploy:
	@./scripts/deploy.sh

backup:
	@SERVER_IP=$$(grep 'ansible_host:' inventory/hosts.yml | awk '{print $$2}') && \
	 SERVER_USER=$$(grep 'ansible_user:' inventory/hosts.yml | awk '{print $$2}') && \
	 ssh $$SERVER_USER@$$SERVER_IP 'bash /opt/selfhosting/backup.sh'
	@echo "Backup complete on server at /var/backups/selfhosting/"

quickstart:
	@./scripts/quickstart.sh

clean:
	@find . -name "*.retry" -delete
	@echo "Cleaned temporary files"
