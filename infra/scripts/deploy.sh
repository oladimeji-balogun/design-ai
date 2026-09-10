#!/usr/bin/env bash
#
# deploy.sh — build and run the design-ai stack on the VPS, over Tailscale.
#
# Handles the two things that are easy to get wrong by hand:
#   1. The plugin's websocket URL comes from WS_URI (derived from
#      PENPOT_MCP_SERVER_ADDRESS), read at container start when the plugin is
#      rebuilt on boot. This script refuses to proceed unless that host is the
#      tailnet hostname (not localhost), so the plugin is reachable from a
#      remote browser. Applying a change is a recreate, not an image rebuild.
#   2. Published ports must bind to the tailnet IP (not 127.0.0.1) to be reachable
#      over Tailscale. This script sets TS_BIND from `tailscale ip -4` and selects
#      the vps overlay, while NOT loading the localhost override.
#
# Run from infra/ on the VPS (root/sudo needed for docker):
#   sudo bash scripts/deploy.sh
#
# Prereqs: provision.sh has run, `tailscale up` done, infra/.env filled in.

set -euo pipefail

cd "$(dirname "$0")/.."   # -> infra/

# --- checks ---
command -v tailscale >/dev/null || { echo "tailscale not installed; run provision.sh"; exit 1; }
command -v docker >/dev/null || { echo "docker not installed; run provision.sh"; exit 1; }
[[ -f .env ]] || { echo "infra/.env missing. cp .env.example .env and fill it in."; exit 1; }

# tailnet IP (for port binding) and require Tailscale to be up
TS_BIND="$(tailscale ip -4 2>/dev/null | head -1 || true)"
if [[ -z "${TS_BIND}" ]]; then
  echo "Could not get a Tailscale IPv4. Is 'tailscale up' done? Run: sudo tailscale up" >&2
  exit 1
fi
export HOST_BIND="${TS_BIND}"
echo "==> Tailnet bind IP: ${TS_BIND} (ports bind here, reachable over tailnet only)"

# read specific values from .env for validation WITHOUT sourcing the file.
# sourcing would execute it, and values with unquoted spaces (e.g. PENPOT_FLAGS)
# would be misread as commands. this reads only the keys we check.
envval() {
  # last matching KEY=VALUE wins; strips surrounding quotes; ignores comments.
  grep -E "^${1}=" .env | tail -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}
PENPOT_MCP_SERVER_ADDRESS="$(envval PENPOT_MCP_SERVER_ADDRESS)"
PENPOT_PUBLIC_URI="$(envval PENPOT_PUBLIC_URI)"

# --- guard against the #1 footgun: plugin pointed at the wrong host ---
if [[ -z "${PENPOT_MCP_SERVER_ADDRESS:-}" || "${PENPOT_MCP_SERVER_ADDRESS}" == "localhost" ]]; then
  cat >&2 <<EOF
ERROR: PENPOT_MCP_SERVER_ADDRESS is empty or 'localhost' in infra/.env.

On the VPS this MUST be the box's tailnet hostname (no port), e.g.
  PENPOT_MCP_SERVER_ADDRESS=your-vps.tailnet-name.ts.net

It becomes the browser plugin's WS_URI (bridge URL); a remote browser
cannot reach a plugin pointed at 'localhost'. Fix .env, then re-run.

Your tailnet hostname:
  $(tailscale status --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | head -1 | sed 's/.*:"//; s/\.$//' || echo '(run: tailscale status)')
EOF
  exit 1
fi
echo "==> Plugin will connect the browser to host: ${PENPOT_MCP_SERVER_ADDRESS}:4402"

# sanity: PENPOT_PUBLIC_URI should point at the same tailnet host on :9001
if [[ "${PENPOT_PUBLIC_URI:-}" != *"${PENPOT_MCP_SERVER_ADDRESS}"* ]]; then
  echo "WARNING: PENPOT_PUBLIC_URI (${PENPOT_PUBLIC_URI:-unset}) does not contain the tailnet host ${PENPOT_MCP_SERVER_ADDRESS}." >&2
  echo "         Penpot may misbehave if the public URI doesn't match how the browser reaches it." >&2
fi

# Only the base file. NOT docker-compose.override.yml (that's the local/localhost
# overlay, auto-merged only on a bare `docker compose` — naming the file
# explicitly here excludes it). HOST_BIND (exported above) moves the port
# bindings from loopback to the tailnet IP.
COMPOSE_FILES=(-f docker-compose.yml)

# build the MCP image if it doesn't exist yet (first deploy). WS_URI is applied
# at container start (runtime), not here, so this build is only about the image
# itself, not the plugin's ws target.
echo "==> Building MCP image if needed"
docker compose "${COMPOSE_FILES[@]}" build penpot-mcp-server

# --force-recreate ensures the container restarts with the current WS_URI so the
# boot rebuild bakes the right host into the plugin, even if the image is cached.
echo "==> Starting the stack (ports bound to ${TS_BIND}, WS_URI applied on recreate)"
docker compose "${COMPOSE_FILES[@]}" up -d --force-recreate

echo "==> Waiting for services to settle..."
sleep 8
docker compose "${COMPOSE_FILES[@]}" ps

cat <<EOF

==> Deploy complete. Over Tailscale, reach:
  Penpot UI      : http://${PENPOT_MCP_SERVER_ADDRESS}:9001
  Plugin manifest: http://${PENPOT_MCP_SERVER_ADDRESS}:4400/manifest.json
  MCP endpoint   : http://${PENPOT_MCP_SERVER_ADDRESS}:4401/mcp

Register an AI client:
  claude mcp add penpot --transport http http://${PENPOT_MCP_SERVER_ADDRESS}:4401/mcp

Notes:
  - After (re)deploying, hard-refresh the Penpot tab so the browser loads the
    freshly built plugin before clicking Connect.
  - If you change PENPOT_MCP_SERVER_ADDRESS later, re-run this script. WS_URI is
    runtime, so a container recreate applies it (no full image rebuild needed).
EOF
