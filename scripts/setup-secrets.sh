#!/bin/bash
set -e

echo "==================================="
echo "Homelab Secrets Setup"
echo "==================================="
echo ""

# Check if .env.cloud exists
if [ -f "env/.env.cloud" ]; then
    echo "⚠️  env/.env.cloud already exists!"
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing file. Exiting."
        exit 0
    fi
fi

# Copy template
cp env/.env.cloud.example env/.env.cloud

echo ""
echo "✅ Created env/.env.cloud from template"
echo ""
echo "📝 Now you need to edit env/.env.cloud and fill in these secrets:"
echo ""
echo "1. ACME_EMAIL - Your email for Let's Encrypt"
echo "2. TAILSCALE_AUTHKEY - From https://login.tailscale.com/admin/settings/keys"
echo "3. TRAEFIK_BASIC_AUTH - Generate with:"
echo "   echo \$(htpasswd -nb admin yourpassword) | sed -e s/\\\\\$/\\\\\$\\\\\$/g"
echo ""
echo "After editing, run:"
echo "  make cloud-up"
echo ""