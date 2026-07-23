---
name: maintain-smart-typst-tables
description: Use when developing, debugging, reviewing, or testing this smart-typst-tables Quarto extension. Covers the Lua Pandoc filter, separate Typst and HTML/Revealjs backends, table layout and type inference, CSS styling hooks, fixtures, documentation, and regression-safe changes.
---

# Maintain Smart Typst Tables

Treat Typst and HTML/Revealjs as separate rendering backends sharing a model,
type inference, header wrapping, and layout plan. Preserve that boundary:

- Typst is native-code generation and must retain conservative fallbacks.
- HTML/Revealjs decorates native Pandoc tables, preserves rich content and
  spans, and must not transform raw HTML tables.

Read [references/architecture.md](references/architecture.md) before changing
filter flow, model extraction, shared planning, or configuration.

## Select the work path

- For HTML, Revealjs, CSS variables, responsive wrappers, width allocation,
  spans, rich cells, or raw HTML behavior, read
  [references/html-reveal.md](references/html-reveal.md).
- For Typst native output, eligibility, column tracks, and header layout, read
  [references/typst.md](references/typst.md).
- For fixtures, validation, and the known local Quarto Sass issue, read
  [references/testing.md](references/testing.md).

## Standard workflow

1. Inspect the source table's Pandoc representation and existing fixtures
   before changing heuristics.
2. Make the narrowest backend-specific change; do not relax Typst fallback
   merely because HTML can support a structure.
3. Add or update a fixture in `tests/fixtures` and an assertion in
   `tests/test-rendering.R` for every regression.
4. Keep `examples/html.qmd` and `examples/revealjs.qmd` representative when a
   user-facing behavior changes.
5. Update README and the embedded user skill when options, hooks, or semantics
   change.
6. Run `git diff --check`; then run the rendering checks when Quarto can render
   locally. Use the direct Pandoc command in the testing reference for a fast
   Lua/HTML structural check if local Sass blocks Quarto.

## Invariants

- Preserve captions, IDs, source attributes, cell attributes, accessibility,
  rich cell contents, `rowspan`, and `colspan` in HTML/Revealjs.
- Preserve raw HTML and `data-smart-tables-raw="true"` unchanged.
- Mark processed tables and do not transform them twice.
- Keep `.smart-table-scroll` outside `.smart-table-wrap`; it owns overflow,
  while the inner wrapper owns intrinsic natural width.
- Keep `smart-table-header-lines` non-wrapping so a calculated two-line header
  cannot become three browser-wrapped lines.
- Respect explicit source widths by default.
