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
- Single-user remote mode for the pilot (not multi-user). Multi-user *remote*
  deployment is still "in progress" upstream, so we deliberately run single-user
  (`PENPOT_MCP_REMOTE_MODE=true`, no multi-user flag) to stay on the supported,
  documented path. For a two-person pilot the practical cost is turn-taking:
  effectively one active MCP session at a time. Multi-user is a fast-follow once
  upstream firms it up (rebuild with the multi-user build/start variant).
- MCP server is built from source, not a community image. We build the official
  Penpot MCP workspace (`penpot/penpot` `mcp/`) via `infra/mcp/Dockerfile`. The
  community `sebathi/penpot-mcp-docker` image only runs the MCP server + websocket
  bridge; it does NOT serve the browser plugin on port 4400, without which there
  is no manifest URL to load into Penpot and the bridge can never connect. Our
  image runs both the MCP server and the plugin server.
- Penpot must be >= 2.13.1. MCP support was introduced in Penpot 2.13.1. All four
  images (frontend, backend, exporter, and the from-source mcp image) are pinned
  to a single `PENPOT_VERSION` so they can never drift apart; the plugin warns
  in-UI on a version mismatch. `PENPOT_VERSION` must be a real `penpot/penpot`
  release **tag** (e.g. `2.14.1`) — the "mcp-prod-*" branches referenced in some
  npm docs do not exist in the repo.

## Prerequisites

- A VPS with Docker and the Docker Compose plugin installed
- Tailscale installed on the VPS and on each team member's machine, all on the same
  tailnet
- The VPS's tailnet hostname (Tailscale admin console, or `tailscale status`)

## Run locally first (recommended before the VPS)

You can run this exact stack on your own machine before provisioning a VPS. It
needs only Docker, not Tailscale and not the VPS. Doing this validates the images,
the version pinning, and the MCP wiring locally, and surfaces the plugin-loading
question (below) cheaply.

A `docker-compose.override.yml` in this directory is auto-merged by Compose and
swaps the tailnet hostnames for `localhost`. Use the local env template:

```bash
cp .env.local.example .env      # localhost values, registration enabled
# fill PENPOT_SECRET_KEY (python3 -c "import secrets; print(secrets.token_urlsafe(64))")
docker compose up -d
docker compose ps
```

First run builds the MCP image from source (a few minutes). Once up:
- Penpot UI: `http://localhost:9001`
- MCP endpoint: `http://localhost:4401/mcp`
- Plugin manifest (load this in Penpot's Plugins dialog):
  `http://localhost:4400/manifest.json`

When you later deploy to the VPS, either remove the override file there or run
`docker compose -f docker-compose.yml up -d` to ignore it and use the tailnet
values from `.env`.

## Deploy

Two helper scripts in `scripts/` do the fiddly parts. Recommended path:

1. Provision the box (fresh Ubuntu 22.04/24.04). Copies/clones the repo, then:

   ```bash
   sudo bash infra/scripts/provision.sh   # installs docker, compose, tailscale, ufw
   sudo tailscale up                      # join the SAME tailnet as your other machines
   tailscale status                       # note this box's tailnet hostname + IP
   ```

2. Create the env file and fill it in (`cd infra && cp .env.example .env`):

   - `PENPOT_SECRET_KEY`: a long random value
     (`python3 -c "import secrets; print(secrets.token_urlsafe(64))"`)
   - `PENPOT_DATABASE_PASSWORD`: a strong generated password
   - `PENPOT_PUBLIC_URI`: the VPS tailnet URL, e.g.
     `http://your-vps.tailnet-name.ts.net:9001`
   - `PENPOT_VERSION`: a real Penpot release tag (>= `2.13.1`), e.g. `2.14.1`.
     Not an "mcp-prod-*" branch.
   - `PENPOT_MCP_SERVER_ADDRESS`: the VPS tailnet **hostname** (no port). This is
     baked into the plugin — it must be the tailnet host, never `localhost`.

   `.env` is gitignored and must never be committed.

3. Deploy:

   ```bash
   sudo bash scripts/deploy.sh
   ```

   The script: reads the tailnet IP, refuses to build if `PENPOT_MCP_SERVER_ADDRESS`
   is missing/localhost, builds the MCP image (baking the tailnet host into the
   plugin), binds published ports to the tailnet IP via `HOST_BIND`, and brings the
   stack up. It prints the URLs and the `claude mcp add` command at the end.

### How the network binding works

The base compose binds published ports to `${HOST_BIND:-127.0.0.1}`. Locally that
default keeps everything on loopback. On the VPS, `deploy.sh` sets `HOST_BIND` to
the box's tailnet IP (`tailscale ip -4`), so the ports are reachable over the
tailnet **only** — never on the public interface. `provision.sh` also sets a
default-deny `ufw` firewall as defense in depth.

We deliberately do NOT use `tailscale serve` (which fronts services as HTTPS on
443 by path): the MCP plugin opens a direct `ws://<host>:4402` socket baked at
build time, and the stack is intentionally http/ws, so serve's TLS/path model
would cause mixed-content and port-vs-path failures. Raw tailnet ports are the fit.

### The build-time gotcha (read this)

The plugin's WebSocket target (`ws://<PENPOT_MCP_SERVER_ADDRESS>:4402`) is compiled
into the plugin at **build time**. If you ever change `PENPOT_MCP_SERVER_ADDRESS`,
re-run `deploy.sh` — a plain restart will not update the baked URL. Building with
`localhost` (e.g. copied from a local run) leaves the plugin unreachable from a
remote browser. `deploy.sh` guards against the localhost case.

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
3. Plugins menu -> "Write a plugin URL" -> the plugin manifest served by our MCP
   container on port 4400:
   - locally: `http://localhost:4400/manifest.json`
   - on the VPS: `http://your-vps.tailnet-name.ts.net:4400/manifest.json`
4. In the plugin panel, click Connect to MCP server. Wait for "Connected".
5. Register the server with the AI client, pointing at the VPS tailnet hostname:

   ```bash
   claude mcp add penpot --transport http http://your-vps.tailnet-name.ts.net:4401/mcp
   ```

6. Keep the plugin panel open and the Penpot tab active for the whole session.
   Closing the panel drops the connection.
7. Run a read-only prompt first (e.g. "list the boards on this page") before writes.

Browser note (important): newer Chromium browsers (Chrome, Edge, Vivaldi, Brave)
block a web app from reaching a local/private-network plugin server by default. If
Penpot refuses to load the manifest or connect, either approve the "private network
access" prompt, or use **Firefox**, which does not enforce this. Standardize the
pilot on Firefox to avoid the friction.

## Unverified / confirm before relying on this

Called out honestly so no one trusts these blind:

- MCP image source. RESOLVED: we build from official source (`infra/mcp/Dockerfile`,
  sparse-clone of `penpot/penpot` `mcp/` at the `PENPOT_VERSION` tag), not a
  community image. No third-party image trust question. Re-review the Dockerfile
  when bumping `PENPOT_VERSION`.
- Plugin load URL / plugin server. RESOLVED: our from-source image runs the plugin
  web server on port 4400 alongside the MCP server. Verified locally: 4400 serves
  the real "Penpot MCP Plugin" `manifest.json`. Load it in Penpot per "How a
  designer connects" above.
- Multi-user without external Redis. RESOLVED (and now moot for the pilot): the
  official MCP docs confirm `PENPOT_MCP_REDIS_URI` is only for multi-INSTANCE
  horizontal scaling via pub/sub. We run single-instance single-user, so no
  external Redis is needed. (Separate from Penpot's own required `penpot-redis`.)
- Multi-user remote. OPEN by choice: not enabled for the pilot because upstream
  multi-user remote is still in progress. Revisit with the `build:multi-user` /
  `start:multi-user` workspace variants when it stabilizes.
- Plugin build-time address. GOTCHA: `PENPOT_MCP_SERVER_ADDRESS` is baked into the
  plugin at build time (the plugin's `ws://` bridge URL). Build on the VPS with the
  tailnet hostname; rebuild if it changes. See Deploy step 3.
- Container start-up. NOTE: the MCP container runs `corepack` at start, which
  downloads the pinned `pnpm` on first boot (needs outbound network, adds a little
  latency). Fine for a VPS with internet; flag it if the box is network-restricted.
- Penpot compose baseline. The Penpot service definitions here are a minimal,
  standard single-node setup. Diff against the official Penpot `docker-compose.yaml`
  for your target version in case env vars or images have changed.
