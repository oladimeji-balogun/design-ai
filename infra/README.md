# VPS deployment: self-hosted Penpot + MCP bridge

Stands up a second, self-hosted Penpot instance and the official Penpot MCP server
on a single VPS, in one Docker Compose stack, reachable by the team over Tailscale.

This is the shared, always-on version of the design AI pipeline. It replaces the
per-laptop local setup described in the project plan. See
[`../ai-design-automation-plan.md`](../ai-design-automation-plan.md) for the why.

## Why this shape (decisions worth defending)

- Second Penpot instance, self-hosted on our own VPS. The existing Penpot is on
  Elestio (managed), which does not let us add an MCP sidecar cleanly. Our own VPS
  gives us that control.
- Tailscale, not public + reverse proxy. The MCP bridge lets an AI agent execute
  arbitrary code in the Penpot plugin environment. Keeping it off the public
  internet is the single biggest risk reduction for a two-person pilot. If we later
  need access for people who cannot install a VPN client, revisit a public proxy
  with TLS and auth then.
- Multi-user mode on from day one. The designer works while a second person tests
  with their own designs, concurrently. `MULTI_USER=true` enables that (and
  auto-enables remote mode, which disables local filesystem access on the server).
- Penpot must be >= 2.13.1. MCP support was introduced in Penpot 2.13.1. The MCP
  image tag must match the Penpot version to avoid the plugin's version-mismatch
  warning.

## Prerequisites

- A VPS with Docker and the Docker Compose plugin installed
- Tailscale installed on the VPS and on each team member's machine, all on the same
  tailnet
- The VPS's tailnet hostname (Tailscale admin console, or `tailscale status`)

## Deploy

1. Copy this `infra/` directory to the VPS (or clone the repo there).

2. Create the real env file from the template and fill it in:

   ```bash
   cp .env.example .env
   ```

   - `PENPOT_SECRET_KEY`: generate a long random value
     (`python3 -c "import secrets; print(secrets.token_urlsafe(64))"`)
   - `PENPOT_DATABASE_PASSWORD`: a strong generated password
   - `PENPOT_PUBLIC_URI`: the VPS tailnet URL, e.g.
     `http://your-vps.tailnet-name.ts.net:9001`
   - `PENPOT_MCP_IMAGE_TAG`: the Penpot version, >= `2.13.1`, e.g. `2.13.3`
   - `PENPOT_MCP_SERVER_ADDRESS`: the VPS tailnet hostname (no port)

   `.env` is gitignored and must never be committed.

3. Bring the stack up:

   ```bash
   docker compose up -d
   ```

4. Confirm the services are healthy:

   ```bash
   docker compose ps
   docker compose logs penpot-mcp-server
   ```

All services bind to `127.0.0.1` on the VPS. Nothing is published to the public
internet. Team members reach the box over Tailscale.

## First-time Penpot setup

1. Over Tailscale, open `http://your-vps.tailnet-name.ts.net:9001` in a browser.
2. Create the team accounts (registration is disabled by default via
   `PENPOT_FLAGS`; enable it temporarily to create the first accounts, then disable
   again, or create accounts via the Penpot CLI).
3. In Penpot, each user generates a personal access token under
   your account -> integrations -> personal access tokens.

## How a designer connects (per person, in their browser)

Hosting removes the per-laptop Node install. It does not remove the browser step,
that is inherent to how Penpot exposes design operations.

1. Be on the tailnet (Tailscale running).
2. Open the target design file in Penpot (the tailnet URL above).
3. Plugins menu -> Load plugin from URL. Use the plugin URL served by your Penpot
   version. Confirm the exact path against your Penpot release before onboarding
   the team (see "Unverified" below).
4. In the plugin panel, click Connect to MCP server. Wait for "Connected".
5. Register the server with the AI client, pointing at the VPS tailnet hostname:

   ```bash
   claude mcp add penpot --transport http http://your-vps.tailnet-name.ts.net:4401/mcp
   ```

6. Keep the plugin panel open and the Penpot tab active for the whole session.
   Closing the panel drops the connection.
7. Run a read-only prompt first (e.g. "list the boards on this page") before writes.

## Unverified / confirm before relying on this

Called out honestly so no one trusts these blind:

- MCP image source. The compose file uses the community image
  `sebathi/penpot-mcp-docker`, which packages the official Penpot MCP server from
  source. Confirm it is current for your Penpot version, or build your own image
  from the `mcp/` directory of `penpot/penpot` at the matching tag. Do not run this
  in production without confirming the image is one you trust and have reviewed.
- Multi-user without external Redis. The upstream docs mention a Redis URI for
  horizontal scaling across multiple server instances. This single-instance setup
  relies on `MULTI_USER=true` alone. Fine for two concurrent users on one instance;
  if you scale to multiple server instances later, add Redis task routing.
- Plugin load URL. With a hosted setup the plugin manifest is served by Penpot
  itself, not a separate localhost plugin server. Confirm the exact manifest URL
  for your Penpot version during the M1 read-only test.
- Penpot compose baseline. The Penpot service definitions here are a minimal,
  standard single-node setup. Diff against the official Penpot `docker-compose.yaml`
  for your target version in case env vars or images have changed.
