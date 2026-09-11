# Working notes for the AI agent (Penpot MCP design pipeline)

This project drives a self-hosted Penpot via the Penpot MCP server. When you (the
AI agent) build designs through the `penpot` / `penpot-vps` MCP tools, read this
first. It captures Penpot Plugin API quirks already discovered the hard way, so
you don't rediscover them mid-build (which wastes ~20+ minutes and many tool calls).

## How to work

- Build screens section by section; name and group every element for the layers
  panel (e.g. "Sidebar", "Top Bar", "Current Plan Card").
- Prefer `penpotUtils` helpers (`findShapes`, `shapeStructure`, `setParentXY`)
  over reimplementing shape logic.
- Use `export_shape` to visually verify, but treat one-off export glitches as
  transient: if a shape's data looks correct, a blank/partial export is usually a
  stale render, re-export before "fixing" a non-problem.

## Penpot Plugin API gotchas (confirmed on Penpot 2.14.1)

These are real, verified behaviors, not guesses. Apply them proactively.

### Z-order / stacking
- `insertChild(children.length, shape)` does **not** reliably append. In practice
  it can PREPEND (new shape lands at the bottom, visually hidden behind others).
- `bringToFront()` / `sendToBack()` were observed to be **no-ops** in this context.
- `setParentIndex(index)` (0-based) works **reliably**. After creating a shape,
  force its z-order explicitly with `setParentIndex` instead of trusting insert
  order or bring/send helpers.
- Practical rule: create background shapes first, then foreground; after each
  creation, set the parent index explicitly so stacking is deterministic.

### Grouping
- `penpot.group(shapes)` preserves the shapes' existing relative z-order (it does
  not re-sort them). Combined with the insert quirk above, a card's background can
  end up on top of its contents, hiding them. Fix the z-order of the members
  BEFORE grouping, or set indices after.
- When a newly created group must sit above its siblings, set its parent index to
  the top after creating it.

### Strokes / borders
- `strokeAlignment: "inside"` is an **invalid enum** — Penpot silently drops the
  entire stroke array, so the border just doesn't appear. The correct value is
  **`"inner"`** (also valid: `"center"`, `"outer"`).
- Thin strokes (e.g. 1.5px accent borders) render very faintly in `export_shape`
  PNG previews due to scaling/compression. The live editor shows them correctly —
  don't thicken a border just because the export looks faint.

### Timing / async
- Width/height reads right after creating or resizing a shape can be stale. If a
  computed width/position looks wrong, wait ~100ms and re-read before acting.
- Some tool calls (export especially) occasionally need a longer in-call poll;
  a transient failure is often resolved by retrying, not by rebuilding.

### Text
- `width`/`height` are read-only; use `resize(w, h)`, but note `resize` sets
  `growType` to "fixed" — set it back to "auto-width"/"auto-height" for text that
  should size to its content.
- Font substitution in PNG exports (e.g. a serif look when you specified Inter) is
  an export-renderer artifact; the shape data still references the correct font.

## Project constraints

- Designs are Nehso product screens driven by PRDs in ClickUp (fetched via the
  ClickUp MCP). Respect PRD scope boundaries — build only what the PRD's
  "UI/UX Design Agent Readiness" section lists, and honor its "do NOT include"
  exclusions.
- Output is a first draft for a human designer to review and refine, not final
  craft. Favor correct structure, naming, and grouping over pixel perfection.

## Design system (Nehso) — USE THIS, do not invent styles

There is a real, mature design system in this Penpot instance. Earlier drafts that
used arbitrary values (e.g. `#6C63FF`, Inter) were OFF-SYSTEM and wrong. Every
screen must be built from the system below.

Source of truth: the shared library **"Nehso Tokens"** (36 components, 56 colors,
1 typography asset, and **353 design tokens across 10 sets**, all active). Ensure
this library is connected to the working file before designing:
`penpot.library.connected` should include "Nehso Tokens".

### Golden rules
1. **Reuse components, don't redraw them.** For anything the library provides
   (buttons, inputs, nav, modal, dropdown, etc.), find it and instantiate:
   `const c = lib.components.find(x => x.name === "Web Buttons"); const inst = c.instance();`
   Only hand-build primitives that genuinely don't exist as a component.
2. **Apply tokens, don't hardcode values.** Use `applyToken` / reference tokens by
   name for color, spacing, radius, shadow, and typography. Never paste a raw hex,
   px, or shadow when a token exists. Prefer the **alias/semantic** tiers (they
   carry intent) over Foundation raw values.
3. **Do not use the raw color assets** — they are filed under "Obsolete Colors".
   Colors come from tokens.
4. Fonts are **Urbanist** (base) and **Mona Sans** (secondary). Never Inter/serif.

### Token architecture (3 tiers — target the higher tiers)
- **Foundation** (raw): `color.{gold|green|grey|red|teal}.{50..950}`, `color.white`;
  `spacing.{0,2,4,8,12,16,24,32,40,48,64}`; `radius.{0,2,4,8,12,16,24,full}`;
  `elevation.0..6`; `size.*`; `typography.font.{family,size,weight}.*`,
  `typography.lineHeight.*`, letterSpacing.
- **Semantic** (roles — prefer these): `color.semantic.{primary,secondary,text,
  background,surface,border,divider,icon,link,focus,disabled,success,warning,
  error,info,overlay,...}.*`; `typography.{display,heading,body,label,caption,
  accent}.*`; `radius.{none,xs,sm,md,lg,xl,2xl,absolute}`;
  `elevation.surface.{none,low,medium,high}`, `elevation.overlay.{low,medium,high}`;
  `size.{none,xs,lg,xl,2xl,..}`, `size.icon.*`, `size.avatar.*`, `size.height.*`.
- **Alias** (use-case naming — also good to target): `color.alias.{action,brand,
  text,icon,surface,border,divider,focus,link,container,feedback}.*`;
  `typography.alias.{display,marketing,form,component,caption,accent}.*`.

### Key values to reach for (from the inventory)
- Primary/brand color: `color.semantic.primary.default` → `{color.teal.500}` = `#05c7b6`.
  (Use the token, not the hex.) Action colors live under `color.alias.action.*`.
- Text: `color.semantic.text.primary` → `{color.grey.900}`.
- Error/success/warning/info: `color.semantic.{error,success,warning,info}.default`.
- Overlays: `color.semantic.overlay.default` = `rgba(0,0,0,0.72)`.
- Type roles: page title → `typography.alias.display.pageTitle` (h1);
  field label → `typography.alias.form.fieldLabel` (label.medium);
  button label → `typography.alias.component.buttonLabelLarge`;
  stat/metric → `typography.alias.accent.statValue` / `accent.metricValue`;
  helper text → `typography.alias.caption.helperText`.
- Spacing rhythm and radii/shadows all have tokens — use `spacing.*`, `radius.*`,
  `elevation.*` rather than magic numbers.

### Components available to instantiate (36)
Nav Bar, Dashboard-menu / Dashboard-menu-icons / dashboard-menu, Web Buttons,
Mobile Button, Input Field Desktop, Input Field Mobile, Search, Drop-down /
Drop-down item / items, Checkbox / Checkbox-only, Radio Button / Radio-large,
Switch, Toast-alert, Alert, Badge, chip-main, Modal, Date-picker, Calendar,
Progress loader, Upload file, Social Sign Up, Onboarding timeline / Timeline /
Timeline - Z / Timeline-component / TImeline-icons, country-flag, Icons, Info,
context. (Names as-is; match against `lib.components` at runtime, some names are
inconsistent/typo'd in the library.)

### Workflow for an on-system screen
1. Connect/confirm "Nehso Tokens" is in `penpot.library.connected`.
2. For each UI element, first check if a component exists → instantiate it, then
   set its content/props. Fall back to hand-built shapes only for true one-offs.
3. Apply semantic/alias tokens for all color, type, spacing, radius, shadow.
4. Keep everything named and grouped by section.
5. It's still a first draft for the designer to review — but it must look like it
   belongs to the Nehso system, not a generic template.
