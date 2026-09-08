# AI-Assisted Design Automation — Project Plan

## 1. Goal

Automate and accelerate our design process for the current project by connecting our PRD source (ClickUp), our design tool (self-hosted Penpot), and AI agents, so our designer can **create and edit native Penpot designs directly using prompts** — instead of manually rebuilding AI output inside Penpot.

Secondary goal: use ChatGPT for general AI chat and for prototyping micro-interactions (interactive behavior that Penpot itself can't represent), while keeping Claude available as an alternate agent where useful.

## 2. Current State — What's Already Working

- [x] Self-hosted Penpot instance running, team already designing in it
- [x] Personal access token generated in Penpot (Integrations → Personal access tokens)
- [x] Node.js upgraded to v22 (via `nvm`) on the designer's workstation
- [x] Official Penpot MCP repo cloned (`github.com/penpot/penpot-mcp`) and `npm install` completed
- [x] `npm run bootstrap` run successfully — three local servers confirmed live:
  - MCP server: `http://localhost:4401/mcp` (modern) / `http://localhost:4401/sse` (legacy)
  - Plugin server: `http://localhost:4400`
  - WebSocket bridge: `ws://localhost:4402`

## 3. Target Architecture

```
ClickUp (PRDs, source of truth)
      │
      ├──► ChatGPT (official ClickUp app/connector)
      │        — general chat, PRD Q&A, summarization
      │        — micro-interaction prototyping (HTML/CSS/JS)
      │
      └──► Manually pasted / summarized into ──┐
                                                  ▼
                                    AI Agent (Claude Code or Cursor)
                                                  │
                                     connected via Penpot MCP
                                                  │
                                                  ▼
                                Live, native Penpot canvas (self-hosted)
                                                  ▲
                                                  │
                                    Designer prompts + manual edits
```

Claude Design is **not** part of this core pipeline — its output (HTML/PDF/PPTX) is flat and cannot be imported back into Penpot as editable native files. It may still be used standalone for quick, disposable concept pitches, but nothing from it should be expected to land inside Penpot automatically.

## 4. Tools & Roles

| Tool | Role in this pipeline | Notes |
|---|---|---|
| ClickUp | Source of truth for PRDs | Also where tasks live |
| Penpot (self-hosted) | Source of truth for design files | Native, editable, layered files |
| Penpot MCP server (official, local) | Bridges an AI agent to the live Penpot canvas | Runs locally per machine, not a shared team service (yet) |
| Claude Code / Cursor | The prompt interface the designer talks to | Reads/writes real Penpot elements via MCP |
| ChatGPT | General chat + ClickUp PRD lookup + micro-interaction prototyping | Via ClickUp's official app/connector inside ChatGPT |
| Claude Design | Optional, disposable early concepting only | Flat output, no path back into Penpot |

## 5. Setup Checklist

- [x] Self-hosted Penpot running
- [x] Personal access token generated
- [x] Node.js v22 installed
- [x] `penpot-mcp` repo cloned, `npm install` run
- [x] `npm run bootstrap` — MCP (4401), plugin server (4400), websocket (4402) confirmed live
- [ ] Open the self-hosted Penpot instance in the browser (the team's normal login URL) and open the target design file
- [ ] In Penpot: Plugins menu → **Load plugin from URL** → `http://localhost:4400/manifest.json`
- [ ] Click **Connect to MCP server** inside the plugin panel; confirm status changes to "Connected to MCP server"
- [ ] Register the server with the chosen AI agent, e.g. for Claude Code: `claude mcp add penpot -t http http://localhost:4401/mcp`
- [ ] Confirm Penpot tools appear in the agent's tool list
- [ ] Run a read-only test prompt first (e.g. "list the boards on this page") before allowing write actions
- [ ] Set up the official ChatGPT ↔ ClickUp connector (admin enables the app in Workspace settings → Apps; each teammate authorizes individually)
- [ ] Draft a prompt cheat sheet for the designer (see §7)
- [ ] Run one full pilot: pull a real PRD section → prompt the agent to sketch the flow natively in Penpot → designer reviews/refines

## 6. Ideal End-to-End Workflow

1. PRD lives and is maintained in ClickUp.
2. Designer/PM asks ChatGPT (connected to ClickUp) to summarize or fetch the relevant PRD section — or pastes the relevant text manually into the agent session.
3. Designer opens the target Penpot file and the AI agent's chat (Claude Code or Cursor) side by side, with the Penpot MCP plugin connected and the panel left open.
4. Designer prompts the agent — grounded in the PRD content — to create initial screens/flows as **native Penpot elements** (boards, components), reusing existing design tokens where possible.
5. Designer reviews and refines the result by hand directly in Penpot — the agent's job is fast first drafts, not final craft.
6. For behavior that needs demonstrating to engineering (transitions, micro-interactions), the designer feeds the finished HiFi Penpot screens (via export or Claude Design's web capture) into ChatGPT (or Claude Design) to produce an interactive HTML/CSS/JS prototype.
7. Handoff to engineering includes **both**: the native Penpot file (exact layout, components, tokens) and the interactive prototype (behavior/motion reference).

## 7. Prompt Cheat Sheet (starter — expand with real examples once piloted)

- "Create a board 1440×900 for [screen name], using our existing [component] tokens."
- "Add a card component with a title, image, and button, matching our current design system."
- "Duplicate this board and adjust the copy/layout for [variant, e.g. dark mode / mobile]."
- "List/describe the components currently on this page." *(read-only — good first test)*
- "Rename these layers to match our naming convention: [describe convention]."

## 8. Known Constraints (flag to Kiro)

- **Local, per-machine setup.** Each teammate who wants to prompt-edit Penpot directly needs to run their own local MCP server + load the plugin themselves. This is not a shared/remote team service in its current form. If a shared, always-on setup becomes a priority, self-hosted Penpot's native MCP panel (under *Your account → Integrations → MCP Server*) is the path — but that requires an infra upgrade (adding the MCP service to the Penpot docker-compose stack, enabling a feature flag) rather than the local approach used here.
- **Claude Design output can't round-trip into Penpot.** It exports flat files only (HTML/PDF/PPTX/Canva) — no native, layered format. Keep it out of the core pipeline.
- **ChatGPT's ClickUp connector has known reliability issues** as of Sept 2026 — reported OAuth `invalid_client` errors, dropped custom-field values, and rate-limiting on larger workspaces. Test on a non-critical account before relying on it.
- **The Penpot plugin panel must stay open** in the browser while using MCP — closing it disconnects the bridge.
- **HTTPS + localhost:** if the self-hosted Penpot instance is served over HTTPS, the browser may prompt for "private network access" permission to reach `localhost` — expected behavior, not an error.

## 9. Open Questions for the Team

- Is this a single designer's workflow for now, or should we plan for a shared/remote MCP setup to support multiple people sooner rather than later?
- Should ChatGPT's ClickUp connector auto-pull PRD content into the agent session, or is manual copy/paste acceptable for the pilot phase?
- Do we keep Claude Design in the toolkit at all (for early pitch concepts only), or drop it entirely to reduce tool sprawl?

## 10. Milestones

- **M1** — MCP bridge fully connected and verified (read-only test passes)
- **M2** — First AI-assisted native Penpot screen created from a real PRD section, reviewed by the designer
- **M3** — ChatGPT ↔ ClickUp connector live and tested for the team
- **M4** — Full pilot: one feature flow, PRD → native Penpot file → interactive prototype → engineering handoff
- **M5** — Documented prompt cheat sheet + onboarding guide, ready for a second designer to adopt
