# Handoff: continuing on a new machine

Written to pick up development of the AI-assisted design automation project on a
different workstation (a new MacBook). Read this top to bottom before starting.

## What this project is

Connects our PRD source (ClickUp), self-hosted Penpot, and AI agents so a designer can
create and edit native Penpot designs from prompts. Full context is in
[`ai-design-automation-plan.md`](./ai-design-automation-plan.md); the shared-service
architecture decision is in section 2a of that file.

## Where the work is right now

Done and merged to `main`:

- Git repo with a clean history. `main` only ever received merge commits, never direct
  commits, so the no-direct-commits-to-main rule holds. Feature branches were deleted
  after merging.
- Repo scaffolding: `README.md`, `.gitignore`, root `.env.example`, the project plan.
- Shared VPS infrastructure under `infra/`: a Docker Compose stack (self-hosted Penpot
  + official Penpot MCP server in multi-user mode), a deploy guide, and an env template.

Not done yet:

- The VPS is not provisioned. Nothing has been deployed. The compose file was validated
  with `docker compose config` only; it has never been run against a real VPS.
- Tailscale is not set up on any machine or the VPS.
- No end-to-end test has happened (M1 read-only test still pending).
- ClickUp connector work has not started.

## Decisions already made (do not relitigate without reason)

- Shared VPS over per-machine local setup. One VPS runs a second self-hosted Penpot
  plus the MCP server. The existing Elestio Penpot stays as-is.
- Access over Tailscale (VPN), not a public reverse proxy, because the MCP bridge runs
  arbitrary code in the Penpot plugin environment and should not be public for a pilot.
- Multi-user mode on from day one so a designer and a tester can prompt concurrently.
- Penpot must be >= 2.13.1 (first release with MCP); the MCP image tag must match the
  Penpot version.

## Still unverified (confirm before trusting in production)

These are called out honestly in `infra/README.md` too:

- MCP container image source (`sebathi/penpot-mcp-docker`). Confirm you trust it or
  build your own from the `mcp/` dir of `penpot/penpot` at the matching tag.
- Whether single-instance multi-user needs an external Redis.
- The exact plugin manifest URL for the hosted Penpot version.

## Setting up the new MacBook

1. Install prerequisites:

   ```bash
   # homebrew, then:
   brew install git gh
   # node via nvm, matching the project (v22)
   ```

2. Authenticate the GitHub CLI and clone:

   ```bash
   gh auth login
   git clone https://github.com/oladimeji-balogun/design-ai.git
   cd design-ai
   ```

3. Secrets do not travel through git. Both `.env` files are gitignored and were never
   committed. On the new machine, recreate them from the templates when needed:

   ```bash
   cp .env.example .env               # if working with the local bridge
   cp infra/.env.example infra/.env   # only on/for the vps deploy
   ```

   The real Penpot access token and any generated secrets must be re-entered by hand.
   Do not paste real secret values into git, chat, or any committed file.

4. Confirm the repo state matches this doc:

   ```bash
   git log --oneline --graph
   git status
   ```

## Suggested next steps (in order)

1. Provision the VPS (Docker + Compose plugin installed).
2. Install Tailscale on the VPS and the MacBook; join the same tailnet.
3. Fill in `infra/.env` on the VPS and run `docker compose up -d`.
4. Create Penpot accounts and generate a personal access token per user.
5. Run the M1 read-only test: load the plugin in the browser, connect to the MCP
   server, register the agent, and prompt "list the boards on this page" before any
   write actions.

## Notes for the next session

- `.vscode/settings.json` is intentionally left untracked. Decide whether to
  standardize it for the team before committing it.
- There is no CI yet. When code (not just config) lands, add a linter/formatter step
  per the project's language and enforce it in CI.
