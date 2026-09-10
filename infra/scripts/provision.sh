#!/usr/bin/env bash
#
# provision.sh — prepare a fresh Ubuntu 22.04/24.04 VPS to run the design-ai stack.
# Installs Docker Engine + the Compose plugin and Tailscale. Idempotent-ish: safe
# to re-run; it skips what's already present.
#
# Run as root (or with sudo) on the VPS:
#   curl -fsSL <raw-url>/provision.sh | sudo bash
# or copy the repo up and run:
#   sudo bash infra/scripts/provision.sh
#
# After this, run `sudo tailscale up` to join the tailnet, then deploy.sh.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must run as root (use sudo)." >&2
  exit 1
fi

echo "==> Updating apt and installing prerequisites"
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates curl gnupg lsb-release git ufw

# --- Docker Engine + Compose plugin (official repo) ---
if command -v docker >/dev/null 2>&1; then
  echo "==> Docker already installed: $(docker --version)"
else
  echo "==> Installing Docker Engine + Compose plugin"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
fi

echo "==> Docker: $(docker --version)"
echo "==> Compose: $(docker compose version)"

# --- Tailscale ---
if command -v tailscale >/dev/null 2>&1; then
  echo "==> Tailscale already installed: $(tailscale version | head -1)"
else
  echo "==> Installing Tailscale"
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# --- Host firewall: default-deny inbound, allow SSH + Tailscale ---
# Nothing in this stack is published on the public interface (ports bind to the
# tailnet IP), but a default-deny firewall is defense in depth. Tailscale traffic
# rides its own encrypted interface and is allowed.
echo "==> Configuring ufw (allow SSH + Tailscale, deny other inbound)"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow in on tailscale0
ufw --force enable
ufw status verbose

cat <<'EOF'

==> Provisioning complete.

Next steps:
  1. Join the tailnet (interactive, opens an auth URL):
       sudo tailscale up
     Use the SAME Tailscale account/tailnet as your other machines.

  2. Note this box's tailnet hostname + IP:
       tailscale status
       tailscale ip -4

  3. Deploy the stack:
       cd <repo>/infra
       cp .env.example .env      # fill in secrets + PENPOT_MCP_SERVER_ADDRESS
       sudo bash scripts/deploy.sh
EOF
