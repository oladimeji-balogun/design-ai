# Designer Guide — Using the AI Design Pipeline (Nehso)

How to actually create designs day to day, once you've done the one-time setup in
[`DESIGNER-SETUP.md`](./DESIGNER-SETUP.md).

The short version: **you** turn a PRD into a clear, scoped prompt; the **AI agent**
does the tedious drawing in Penpot as native, on-brand elements; **you** review and
refine. The agent is a fast pair of hands, not the designer — you're still the one
making the design decisions.

---

## Start-of-session checklist

Every time you sit down to design, get these three lined up (order matters):

1. **Tailscale running** — `tailscale status` shows `nehso-design-ai`.
2. **Penpot open in Firefox**, in the file you want to design in, with:
   - the **"Nehso Tokens"** library connected (Assets → Libraries), and
   - the **plugin connected** (Plugins → the MCP plugin → "Connected"), panel left
     open, tab kept active.
3. **Claude Code running from the project folder**:
   ```bash
   cd ~/design-ai
   claude
   ```
   Type `/mcp` and confirm `penpot-vps` is connected.

Then run a quick sanity prompt before real work:
> list the boards on this page

If it describes your canvas correctly, you're live.

---

## The workflow

1. **Pick ONE screen.** Not a whole feature — one screen (or one flow step). The
   agent does much better, faster, and cheaper work on a tightly-scoped screen than
   on "build the whole billing area."
2. **Refine the PRD into requirements.** Pull the relevant PRD section (from ClickUp)
   and distill it into exactly what this screen shows: sections, fields, states,
   copy. This is your judgement call — the PRD is the source, but you decide the
   layout and what belongs on the screen.
3. **Write the prompt** (see the prompting recipe below).
4. **Run it and watch the canvas** fill in section by section.
5. **Review and refine** — either with follow-up prompts ("tighten the spacing in
   the wallet table", "make the header use the large heading style") or by hand in
   Penpot. Refining by hand is often faster for small tweaks.

---

## Writing a good prompt (the recipe)

A strong prompt has these parts. The more specific you are, the less the agent
guesses (and the faster it finishes):

1. **The board**: size + a clear name. e.g. "a new 1440×900 board named
   'Billing — Plan Selection'".
2. **The purpose**, one line from the PRD.
3. **The sections/elements**, in order, with the real copy and any numbers.
4. **States** to show (empty / active / error / etc.) if relevant — name the exact
   one you want on this board.
5. **Design-system instructions** (see the next section — this is the important part).
6. **Housekeeping**: "name and group every section; work section by section; then
   summarize what you built."

Keep each prompt to one screen. If you need five screens, that's five prompts — it's
faster overall and each result is cleaner.

---

## Design system: how to get on-brand results (read this)

The agent builds into files that have the **Nehso Tokens** library connected, and a
`CLAUDE.md` in the project already tells it the house rules (use our components, use
our real colors/fonts, never invent styles). But there's one real limitation you
need to work with:

**The agent cannot "bind" design tokens to shapes.** Penpot's plugin interface
doesn't allow it. What the agent *can* do is read a token's value and apply that
value directly (the right teal, the right Urbanist size, the right spacing). So:

- The screen will **look** correct and on-brand.
- But the shapes are **not live-linked** to tokens — if a token value changes later,
  these shapes won't auto-update.
- **You re-bind tokens by hand in Penpot** where you want that live link. The Penpot
  UI does this fine; it's only the AI that can't.

**What this means for your prompts:**
- **Name the tokens/components you want**, and include their values when it helps.
  e.g. "use the primary teal (`color.semantic.primary.default`, #05c7b6) for the
  button", "labels use the `form.fieldLabel` type style", "use the `Web Buttons`
  component". Naming them saves the agent lookup time (faster) and pins down exactly
  what you mean (better).
- **Ask it to reuse components**, not redraw them: "instantiate the `Input Field
  Desktop` component for the code field", "use the `chip-main` component for the
  status pills".
- Don't expect pixel-perfect adherence on the first pass — treat the output as a
  solid first draft in the right visual language, then refine.

Our real system, for reference:
- **Primary/brand**: teal, `color.semantic.primary.default` = `#05c7b6`.
- **Fonts**: Urbanist (base), Mona Sans (secondary). Never Inter.
- **Feedback colors**: success (green), info (teal), warning (amber), error (red) —
  under `color.semantic.*` / `color.alias.feedback.*`.
- **Spacing / radius / shadow**: use the `spacing.*`, `radius.*`, `elevation.*`
  scales rather than arbitrary numbers.
- **36 components** exist (buttons, inputs desktop+mobile, nav, dropdown, modal,
  date-picker, chips, badges, toasts, switch, progress loader, timeline, etc.) — ask
  the agent to inventory them any time: "list the components in the Nehso Tokens
  library".

---

## Keeping the session healthy

- **Keep the Penpot tab active and the plugin panel open** the whole time. If the tab
  is backgrounded/sleeps, the connection silently drops and prompts fail with "no
  plugin connected." If that happens: bring the tab to the front, reconnect the
  plugin, tell the agent "continue."
- **The first prompt of a session is slow** (a minute or two) while the agent loads
  the Penpot API. This is normal — after that it's quicker.
- **Building is methodical**, the agent places elements one at a time over the
  network, so a full screen takes several minutes. That's expected for real,
  editable native output (as opposed to a flat image).
- **It's fine to interrupt** and redirect. If it's going the wrong way, stop it and
  clarify rather than letting it finish something wrong.

---

## Prompt starters (adapt these)

Read-only / safe:
> list the boards on this page
> list the components in the Nehso Tokens library
> describe the layout of the currently selected board

Building a screen:
> On a new 1440×900 board named "…", build the [screen] from this PRD section:
> [paste the distilled requirements]. Use the Nehso design system — instantiate our
> components where they fit (name them), and apply our real token values for color,
> type, spacing, radius, shadow (primary = teal #05c7b6, fonts Urbanist/Mona Sans).
> Name and group each section. Work section by section, then summarize.

Refining:
> On the "…" board, increase the vertical spacing between the stat cards and the
> table to 24px, and change the page title to the display/large heading style.
> Reuse the existing shapes; don't rebuild the board.

---

## When to ask Oladimeji vs. handle it yourself

- **You handle**: prompting, refining designs, connecting the plugin, re-binding
  tokens by hand, day-to-day Penpot work.
- **Ask Oladimeji**: anything about the shared VPS, the design-system library setup,
  Tailscale/account access, or if the pipeline is broken server-side (plugin won't
  connect for anyone, the VPS URL is unreachable, etc.).
