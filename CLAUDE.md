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
