# Homelab - offhourlab.dev

Hybrid cloud/home infrastructure with Traefik, Tailscale, and self-hosted services.

## Architecture

### Cloud Plane (Oracle VPS)
- Traefik (reverse proxy with SSL)
- AdGuard Home (DNS-based ad blocking)
- Tailscale (VPN mesh networking)
- Uptime Kuma (monitoring)

### Home Plane
- Tailscale (VPN mesh networking)
- Nextcloud (file storage)
- Immich (photo management)

## Quick Start

### 1. Initial Setup
```bash
# Run setup (creates .env.cloud from template)
make setup

# Edit secrets
nano env/.env.cloud
# Fill in:
# - ACME_EMAIL
# - TAILSCALE_AUTHKEY
# - TRAEFIK_BASIC_AUTH
```

### 2. Generate Secrets
```bash
# Traefik basic auth
sudo apt install apache2-utils
echo $(htpasswd -nb admin yourpassword) | sed -e s/\\$/\\$\\$/g

# Tailscale auth key
# Visit: https://login.tailscale.com/admin/settings/keys
# Create a reusable key
```

### 3. Configure DNS

Add these DNS records for your domain:
```
Type    Name        Value                   TTL
A       cloud       <Oracle-VPS-IP>         300
A       *.cloud     <Oracle-VPS-IP>         300
A       home        <Oracle-VPS-IP>         300
A       *.home      <Oracle-VPS-IP>         300
```

### 4. Deploy Cloud Services
```bash
# Start cloud services
make cloud-up

# Check status
make ps-cloud

# View logs
make logs-cloud
```

## Commands

### Cloud Plane
- `make cloud-up` - Start all cloud services
- `make cloud-down` - Stop all cloud services
- `make cloud-restart` - Restart all cloud services
- `make logs-cloud` - View logs
- `make ps-cloud` - Show running containers

### Home Plane
- `make home-up` - Start all home services
- `make home-down` - Stop all home services

### Utilities
- `make validate-cloud` - Validate compose configuration
- `make fix-permissions` - Fix data directory ownership
- `make clean` - Remove all containers and networks

## Access Services

- Traefik Dashboard: https://traefik.cloud.offhourlab.dev
- AdGuard Home: https://adguard.cloud.offhourlab.dev

## Directory Structure
```
homelab/
├── compose.cloud.yml      # Cloud orchestration
├── compose.home.yml       # Home orchestration
├── cloud/                 # Cloud services
├── home/                  # Home services
├── env/                   # Environment configs
├── data/                  # Persistent data
└── logs/                  # Service logs
```

## Troubleshooting

### Port 53 already in use
```bash
sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
```

### Permission denied
```bash
make fix-permissions
```

### SSL certificate errors
```bash
# Check Traefik logs
docker logs traefik

# Verify DNS is pointing to server
dig traefik.cloud.offhourlab.dev
```