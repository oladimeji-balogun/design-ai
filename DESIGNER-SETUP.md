# Designer Setup Guide — AI-Assisted Design (Nehso)

This is the one-time setup to start creating Penpot designs from prompts. It takes
about 30–45 minutes. You do **not** need to run any servers or touch infrastructure —
that's already hosted for you on a shared machine. You're just connecting to it.

If anything here doesn't match what you see, stop and ask Oladimeji rather than
guessing — a couple of steps depend on account/network details that are easy to get
wrong.

---

## What you're setting up (the big picture)

```
You type a prompt  ->  Claude Code (on your Mac)  ->  MCP server (shared VPS)  ->  Penpot plugin (your browser)  ->  the design appears on the Penpot canvas
```

Three things live on **your machine**: Tailscale (private network), a browser, and
Claude Code (the prompt tool). Everything else (Penpot + the AI bridge) runs on the
shared VPS you connect to over Tailscale.

You'll need from Oladimeji before starting:
- An invite to the **Tailscale tailnet** (same network as the VPS).
- The VPS address (currently `nehso-design-ai.tailcb21c6.ts.net`).
- A **Penpot account** on the hosted instance (he creates it for you).
- A **Claude seat** (Team plan) so Claude Code can log in.

---

## Step 1 — Install the tools

Open the Terminal app and install Homebrew if you don't have it (check with
`brew --version`). Then:

```bash
brew install --cask claude-code    # the AI prompt tool
brew install tailscale             # the private-network client
```

Use **Firefox** as your browser for this work. Chrome mostly works too, but Firefox
avoids a "private network access" block that can silently break the plugin
connection. If you don't have it: `brew install --cask firefox`.

---

## Step 2 — Join the Tailscale network

Tailscale is a private VPN that lets your Mac reach the shared VPS securely. The VPS
is not on the public internet — Tailscale is the only way in.

1. Ask Oladimeji to invite your email to the tailnet (he does this from the
   Tailscale admin console).
2. Accept the invite (check your email), which creates/links your Tailscale account.
3. In Terminal:
   ```bash
   sudo tailscale up
   ```
   This opens a browser to sign in. Use the **same account** the invite went to.
4. Confirm you're connected and can see the VPS:
   ```bash
   tailscale status
   ```
   You should see your Mac **and** a machine named `nehso-design-ai` in the list.
   If you don't see `nehso-design-ai`, you're not on the right tailnet — ask
   Oladimeji to confirm the invite.

Quick reachability check:
```bash
ping -c 2 nehso-design-ai.tailcb21c6.ts.net
```
If it replies, you're good.

---

## Step 3 — Log into Penpot (the design tool)

1. In Firefox, open:
   `http://nehso-design-ai.tailcb21c6.ts.net:9001`
2. Log in with the account Oladimeji created for you.
   (Registration is closed on this instance, so there's no "sign up" — if you can't
   log in, ask him to create/reset your account.)
3. You should land in the dashboard. Look for the **team** that holds the
   **"Nehso Tokens"** design-system library and the design files. If you only see an
   empty personal space, ask Oladimeji to add you to the right team.

---

## Step 4 — Set up Claude Code (the prompt tool)

Claude Code is what you actually type prompts into. It connects to the AI bridge on
the VPS.

1. You need the project folder on your Mac (it holds the settings that point Claude
   at the right servers). Ask Oladimeji for the repo, then:
   ```bash
   git clone https://github.com/oladimeji-balogun/design-ai.git
   cd design-ai
   ```
   (If `git clone` asks for a login, install `gh` with `brew install gh`, run
   `gh auth login`, then clone again.)

2. **Always launch Claude Code from inside this folder.** This matters — the folder
   contains the connection to the VPS design server AND a `CLAUDE.md` file that
   teaches the agent how to work with our design system. Launch from anywhere else
   and neither loads.
   ```bash
   cd ~/design-ai      # or wherever you cloned it
   claude
   ```

3. First launch will ask you to log in — do it with your **Claude Team** account
   (the seat Oladimeji assigned you).

4. Register the design server with Claude Code (run once, from the project folder):
   ```bash
   claude mcp add penpot-vps --transport http http://nehso-design-ai.tailcb21c6.ts.net:4401/mcp
   ```

5. Verify it connected — inside a `claude` session, type:
   ```
   /mcp
   ```
   You should see **`penpot-vps` — connected**. If it's not there, make sure you
   launched `claude` from the project folder and that Tailscale is running.

---

## Step 5 — Connect the plugin in Penpot (do this each work session)

This is the live link between Penpot and the AI. It's not permanent — you reconnect
it whenever you start designing.

1. In Firefox, open the Penpot file you want to design in (over the tailnet URL).
2. Make sure the file has the **"Nehso Tokens"** library connected
   (Assets panel → Libraries). If it's a fresh file, add it there.
3. Open the **Plugins** menu (or press `Ctrl/Cmd + Alt + P`).
4. In "Write a plugin URL", paste:
   ```
   http://nehso-design-ai.tailcb21c6.ts.net:4400/manifest.json
   ```
   Click **Install**, then open the plugin.
5. Click **Connect to MCP server**. Wait for **"Connected"**.
6. **Keep this plugin panel open and the Penpot tab active while you work.** If you
   close the panel or the tab goes to sleep, the connection drops and the AI can't
   reach the canvas.

---

## You're set up

To confirm end-to-end, do the quick test in the **Designer Guide** (`DESIGNER-GUIDE.md`):
open a file, connect the plugin, and prompt "list the boards on this page". If it
answers with what's on your canvas, everything works.

## Troubleshooting quick reference

- **`/mcp` doesn't show penpot-vps** → you launched `claude` from the wrong folder,
  or Tailscale isn't up. `cd` into the project folder; check `tailscale status`.
- **Can't open the Penpot URL** → Tailscale not running, or you're on the wrong
  tailnet. Run `sudo tailscale up`, re-check `tailscale status`.
- **Plugin won't connect / "host not allowed"** → use Firefox; if on Chrome, approve
  the private-network prompt. If it still fails, tell Oladimeji (it may need a
  server-side refresh).
- **Plugin says Connected but the AI says "no plugin connected"** → the tab likely
  went to sleep. Bring the Penpot tab to the front, reconnect the plugin, try again.
- Anything server-side (the VPS, deploys, the design system library) → that's
  Oladimeji's side, not something you fix locally.
