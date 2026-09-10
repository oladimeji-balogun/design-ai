# Setup & Run Guide

How to set up the AI-assisted design pipeline from scratch, and how to run it end
to end once a Claude plan is available. Written against the local (Mac) setup;
the VPS deploy follows the same shape with tailnet hostnames instead of
`localhost` (see [`infra/README.md`](./infra/README.md)).

Architecture in one line: you prompt an AI agent (Claude Code) → it talks to the
Penpot MCP server → the server drives the live Penpot canvas through the browser
plugin. The prompt lives in the agent, not inside Penpot; the plugin panel is only
the bridge.

---

## Part A — One-time machine setup

Prerequisites already assumed: git, Docker (or OrbStack), Node v22.

1. Install tooling:
   ```bash
   brew install gh tailscale
   brew install --cask claude-code
   ```

2. Authenticate GitHub:
   ```bash
   gh auth login
   ```

3. Join Tailscale (only needed for the VPS path; the local run does not require it).
   Sign up at tailscale.com, then on this machine:
   ```bash
   sudo tailscale up      # opens a browser to authenticate
   tailscale status       # confirm this machine has a 100.x.x.x IP
   ```
   Use the same login on the VPS later so both land on the same tailnet.

---

## Part B — First-time stack bring-up (local)

Run from the `infra/` directory.

1. Create the local env file and a real secret:
   ```bash
   cd infra
   cp .env.local.example .env
   # generate PENPOT_SECRET_KEY and paste it into .env:
   python3 -c "import secrets; print(secrets.token_urlsafe(64))"
   ```
   `.env.local.example` already sets `localhost` URLs, `PENPOT_VERSION=2.14.1`,
   registration enabled, and `disable-email-verification` (local has no SMTP, so
   this activates accounts immediately — never carry that flag to a shared/real
   instance).

2. Build the MCP image (from source) and start everything:
   ```bash
   docker compose build penpot-mcp-server   # first time; builds from penpot/penpot @ 2.14.1
   docker compose up -d
   docker compose ps                         # all 6 services should be Up
   ```
   Note: the MCP image builds both the MCP server (4401) AND the plugin web
   server (4400). The community sebathi image does NOT serve 4400, which is why
   we build from source — without 4400 there is no plugin manifest to load.

3. Create your Penpot account:
   - Open `http://localhost:9001`, register, log in.
   - Because email verification is disabled locally, the account is active
     immediately. (If an account ever gets stuck inactive, activate it directly:
     `docker compose exec -T penpot-postgres psql -U penpot -d penpot -c "update profile set is_active=true where email='YOUR_EMAIL';"`)

4. Register the MCP server with Claude Code (once):
   ```bash
   claude mcp add penpot --transport http http://localhost:4401/mcp
   claude mcp list        # penpot: ... ✔ Connected
   ```

---

## Part C — End-to-end run (each session, subscription ready)

If the stack is already up, skip to step 3.

1. Start the stack (from `infra/`):
   ```bash
   docker compose up -d
   docker compose ps
   ```

2. Sanity-check endpoints:
   ```bash
   curl -s -o /dev/null -w "ui       %{http_code}\n" http://localhost:9001/
   curl -s -o /dev/null -w "plugin   %{http_code}\n" http://localhost:4400/manifest.json
   curl -s -o /dev/null -w "mcp      %{http_code}\n" http://localhost:4401/mcp   # 406 = alive
   ```

3. Load the plugin in Penpot (browser — use **Firefox**; newer Chromium browsers
   block local plugin connections by default):
   - Open `http://localhost:9001`, log in, open a design file.
   - Plugins menu (Cmd+Alt+P) → paste `http://localhost:4400/manifest.json` →
     Install → open the plugin.
   - Click **Connect to MCP server** → wait for **"Connected"**.
   - Keep the plugin panel open and the tab active for the whole session; closing
     it drops the connection.

4. Authenticate Claude Code (first time after subscribing):
   ```bash
   claude            # prompts you to log in / authenticate on first launch
   ```

5. Read-only test first (the M1 milestone) — in the `claude` session:
   > list the boards on this page

   Expected: it calls the Penpot tools and describes the canvas. Nothing is
   modified.

6. Small write test:
   > add a 1440×900 board called "Home"

   Expected: a new board appears live in Penpot. Claude Code may ask you to
   approve the write — allow it.

7. Real workflow: pull a PRD section (from ClickUp, or pasted in) and prompt the
   agent to sketch the flow as native Penpot boards, reusing existing tokens and
   components. Review and refine by hand in Penpot.

Keep the `claude` terminal and the Penpot browser tab side by side: you prompt in
the terminal, the design changes in the browser.

---

## Notes & gotchas

- Version lockstep: `PENPOT_VERSION` (in `.env`) drives all four images —
  frontend, backend, exporter, and the from-source MCP image. It must be a real
  `penpot/penpot` release tag (e.g. `2.14.1`), not an `mcp-prod-*` branch (those
  don't exist). A mismatch triggers an in-plugin warning.
- Plugin WebSocket URL: the plugin's `ws://` bridge URL comes from the `WS_URI`
  runtime env var (derived from `PENPOT_MCP_SERVER_ADDRESS`). The container's
  `start` script rebuilds the plugin on boot and reads `WS_URI` then, so it's a
  runtime value, not a build arg. Changing the host needs a container recreate
  (not an image rebuild). It must be reachable from the designer's browser: the
  tailnet host on the VPS, `localhost` only for a local run. Symptom of getting it
  wrong: plugin shows "Connected" but tool calls report "no plugin connected."
- Container start-up: the MCP container runs `corepack` on start, which downloads
  the pinned pnpm on first boot (needs outbound network, adds a little latency).
- Billing: Claude Code needs a paid plan (Pro/Max) or Anthropic API credits. The
  free Claude.ai chat plan does not include Claude Code. Steps 1-4 above work
  without billing; only steps 5+ (actual prompts) require it.
- Teardown when done: `docker compose down` (add `-v` to also wipe the local
  Penpot data volumes).

## Verified so far (without a subscription)

- Penpot stack healthy at 2.14.1 (UI, API, exporter).
- Plugin served on 4400; loads in Penpot and shows "Connected" (WebSocket logged
  server-side).
- Claude Code → MCP server: Connected.
- Raw MCP `initialize` handshake returns a session id and the full Penpot toolset.

The only unproven step is an actual prompt executing a design, which is gated
solely by Claude billing, not by this setup.
