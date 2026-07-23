---
name: use-smart-typst-tables
description: Use when authoring or revising Quarto documents with the smart-typst-tables extension for Typst PDF, HTML, or Revealjs. Activate the filter, author compatible Pandoc tables, configure layout and header wrapping, style transformed HTML/Revealjs tables, and diagnose tables left unchanged.
---

# Use Smart Typst Tables

Use ordinary Pandoc tables: Markdown pipe or grid tables, list-tables, or
`knitr::kable(..., format = "pipe" | "markdown")` emitted with
`#| output: asis`. Put Quarto's filter before this one:

```yaml
filters:
  - quarto
  - smart-typst-tables
```

Use a relative path to `smart-typst-tables.lua` for a local checkout. Do not
expect `kable(format = "html")`, `kableExtra`, `gt`, or handcrafted HTML to be
transformed; those are deliberately left native.

## Configure the document

Start with document-level defaults and use table-level attributes only for
exceptions:

```yaml
smart-tables:
  profile: academic
  table-width: natural
  align: center
  header-lines: auto
  max-header-lines: 3
  stripe: false
  row-rules: true
```

- Use `profile: compact`, `exam`, or `plain` for the supplied visual variants.
  Revealjs chooses `reveal` automatically unless `profile` is explicit.
- Use `table-width: natural` for content-sized tables; use `full` only when a
  text-heavy table should consume available width.
- Use `header-lines: 2` or
  `smart-tables-header-lines="2"` to force two deliberate header rows when
  enough words exist. A single-word label remains one line.
- Use `diagnostics: true` when a table is unexpectedly unchanged.
- Use `smart-tables-column-types="identifier,date,numeric"` or
  `smart-tables-column-2="formula"` when a column's semantics are known.
  Formulae are right-aligned with tabular figures and are never inferred as
  currency merely because of their header.
- Use `smart-tables-nowrap="none"` to let every body column wrap, or retain
  `auto` (the default) to protect only consistently compact values.

For a local exception, wrap the table in a Div:

```markdown
::: {smart-tables-profile="compact" smart-tables-header-lines="2"}
| Measure label | Current value |
|---|---:|
| Retention rate | 91.0% |
:::
```

For a caption and reference, keep the identifier and options on the outer Div:

```markdown
::: {#tbl-kpi smart-tables-header-lines="2"}
| Measure label | Current value |
|---|---:|
| Retention rate | 91.0% |

Key performance indicators.
:::

See @tbl-kpi.
```

## Choose the output path

- For Typst-specific eligibility, native column tracks, or fallbacks, read
  [references/typst.md](references/typst.md).
- For HTML/Revealjs custom colors, fonts, spacing, and responsive-table hooks,
  read [references/html-reveal-styling.md](references/html-reveal-styling.md).

## Work safely

Preserve declared `tbl-colwidths` and list-table `widths` unless the author
explicitly chooses `explicit-widths: optimize`. Do not remove the HTML
`.smart-table-scroll` wrapper or globally force transformed tables to
`width: 100%`: both defeat the responsive natural-width layout.
