# AI-Assisted Design Automation

Connects our PRD source (ClickUp), our design tool (self-hosted Penpot), and AI agents
so a designer can create and edit native Penpot designs directly from prompts, instead
of manually rebuilding AI output inside Penpot.

The full project plan, architecture, workflow, and open questions live in
[`ai-design-automation-plan.md`](./ai-design-automation-plan.md).

## How it fits together

```
ClickUp (PRDs)  ->  AI agent (Claude Code / Cursor)  ->  Penpot MCP bridge  ->  live Penpot canvas
```

The AI agent talks to a local Penpot MCP server, which drives the live Penpot canvas
through a browser plugin. Everything on the MCP side currently runs locally, per machine.

## Prerequisites

- Self-hosted Penpot instance you can log into
- Node.js v22 (managed via `nvm`)
- A Penpot personal access token (Penpot: your account -> integrations -> personal access tokens)
- An AI agent that speaks MCP (Claude Code or Cursor)

## Local setup

1. Clone the official Penpot MCP repo and install dependencies:

   ```bash
   git clone https://github.com/penpot/penpot-mcp
   cd penpot-mcp
   npm install
   ```

2. Copy the environment template and fill in real values:

   ```bash
   cp .env.example .env
   ```

   Fill in `PENPOT_ACCESS_TOKEN` and `PENPOT_BASE_URL`. The three local URLs already
   default to the values `npm run bootstrap` prints. Never commit `.env`.

3. Start the local bridge:

   ```bash
   npm run bootstrap
   ```

   Confirm three servers come up:
   - MCP server: `http://localhost:4401/mcp`
   - Plugin server: `http://localhost:4400`
   - WebSocket bridge: `ws://localhost:4402`

## Connecting the bridge (M1)

1. Open the self-hosted Penpot instance in the browser and open the target design file.
2. Plugins menu -> Load plugin from URL -> `http://localhost:4400/manifest.json`
3. In the plugin panel, click Connect to MCP server. Wait for "Connected to MCP server".
4. Register the server with your agent, e.g. Claude Code:

   ```bash
   claude mcp add penpot -t http http://localhost:4401/mcp
   ```

5. Confirm the Penpot tools appear in the agent's tool list.
6. Run a read-only test first before any writes:

   > list the boards on this page

## Known constraints

- Local, per-machine setup. Each teammate runs their own MCP server and loads the plugin.
- The Penpot plugin panel must stay open in the browser, closing it disconnects the bridge.
- ChatGPT's ClickUp connector has known reliability issues (as of Sept 2026), test on a
  non-critical account before relying on it.
- Claude Design output cannot round-trip into Penpot (flat files only). Keep it out of the
  core pipeline.

See the [project plan](./ai-design-automation-plan.md) for the full breakdown.
