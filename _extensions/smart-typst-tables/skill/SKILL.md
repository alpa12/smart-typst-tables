---
name: use-smart-typst-tables
description: Use when authoring or revising Quarto documents that render to Typst PDF and need better ordinary table layout with the smart-typst-tables extension. This skill helps an AI agent activate the extension, write eligible Pandoc tables, configure document and table options, avoid unsupported table constructs, and diagnose unchanged fallback tables.
---

# Smart Typst Tables

Use this skill when a Quarto document targets `format: typst` and the user wants
ordinary Markdown, grid, or computational Pandoc tables to render as polished
Typst PDF tables.

Do not use this extension for HTML output, CSS-driven table styling, or as an R
table package. The extension is a Quarto Lua filter that rewrites eligible Pandoc
`Table` nodes into native Typst `table()` code.

## Activation

For an installed extension, prefer this filter order:

```yaml
format: typst
filters:
  - quarto
  - smart-typst-tables
```

For a local checkout, use a relative path to the Lua filter:

```yaml
format: typst
filters:
  - ../_extensions/smart-typst-tables/smart-typst-tables.lua
```

Use the `quarto` sentinel when available so Quarto normalizes captions and
cross-references before this filter runs.

Render with:

```bash
quarto render path/to/document.qmd --to typst
```

## Table Authoring Rules

Write tables that Quarto/Pandoc can represent as `Table` nodes:

- Markdown pipe tables.
- Grid tables.
- Computational output that becomes a Pandoc table, such as many
  `knitr::kable()` outputs with `#| output: asis`.

Keep eligible cells simple. The filter currently supports cells whose content is
plain text or one paragraph containing plain strings, spaces, soft breaks, or
line breaks. Avoid spans, inline formatting, math, raw HTML, multiple blocks,
lists, images, code blocks, row spans, and column spans inside tables that should
be optimized.

Do not rely on HTML/CSS width rules for Typst tables. Use this extension's
metadata and table attributes instead.

## Document Options

Configure the extension with `smart-tables`:

```yaml
smart-tables:
  profile: academic
  text-size: auto
  optimize-widths: true
  wrap-headers: balanced
  repeat-header: true
  stripe: false
  row-rules: true
  table-width: natural
  align: center
  diagnostics: false
```

Supported profiles:

- `academic`: default booktabs-like styling.
- `compact`: dense tables for appendices, handouts, and space-constrained pages.
- `exam`: slightly larger and clearer tables.
- `plain`: optimized layout with minimal decoration.

Useful layout choices:

- `text-size: auto` keeps the selected profile's default text size.
- `text-size: 0.88em` or `text-size: 9pt` overrides table text size.
- `table-width: natural` keeps short tables close to their content width.
- `align: center` centers natural-width tables.
- `table-width: full` allocates remaining width to free-text or mixed columns.
- `stripe: true` adds alternating row fill.
- `repeat-header: true` repeats table headers across pages.
- `diagnostics: true` logs why a table was skipped.

The filter also accepts `smart_typst_tables` as an alternate metadata key, but
prefer `smart-tables` in new documents.

## Table-Level Overrides

Wrap a single table in a Div to override selected options:

```markdown
::: {smart-tables-profile="compact" smart-tables-stripe="false"}
| Critere | Poids | Attente |
|---|---:|---|
| Definition | 20% | Definit clairement les termes. |
:::
```

Supported table attributes:

- `smart-tables="false"` or `smart-tables="off"`: leave the table unchanged.
- `smart-tables-profile="academic|compact|exam|plain"`.
- `smart-tables-text-size="0.88em"`.
- `smart-tables-stripe="true|false"`.
- `smart-tables-row-rules="true|false"`.
- `smart-tables-repeat-header="true|false"`.
- `smart-tables-optimize-widths="true|false"`.
- `smart-tables-width="natural|full"`.
- `smart-tables-align="left|center|right|none"`.

For a captioned and cross-referenceable table, wrap the table in a Div with an
identifier and place the caption text after the table:

```markdown
::: {#tbl-transactions}
| Segment | Polices | Prime moyenne |
|---|---:|---:|
| Nouvelles ventes | 128 | 1 240 $ |

Transactions d'assurance.
:::

See @tbl-transactions.
```

## Widths and Alignment

The layout engine infers column types from headers and values:

- dates: centered, fixed width;
- currency, percentages, and numeric values: right-aligned, fixed width;
- identifiers and short categorical values: usually `auto`;
- long free text: fixed width, or `fr` tracks when `table-width: full`.

Source alignments in Markdown are respected when they are explicit right or
center alignments. Otherwise the inferred type determines alignment.

Explicit source widths, such as `tbl-colwidths` or nonzero Pandoc column widths,
are treated as user intent. By default, those tables are left unchanged. Use
`explicit-widths: optimize` only when the user explicitly wants this filter to
override source widths.

## Fallbacks

The filter leaves a table unchanged when optimization would be risky. Common
skip reasons:

- target output is not Typst;
- no columns or more than 14 columns;
- row spans or column spans;
- complex cell content;
- explicit source widths with the default `explicit-widths: respect`;
- `optimize-widths: false`;
- fixed-width columns exceed the safe page width for wide tables.

When a table does not change and the reason is unclear, set:

```yaml
smart-tables:
  diagnostics: true
```

Then re-render and inspect the Quarto log for `[smart-typst-tables]` messages.

## Good Agent Workflow

1. Confirm the document renders to Typst, not HTML.
2. Add or preserve the filter in the right order.
3. Convert styling-heavy or HTML-like tables into ordinary Pandoc tables when
   possible.
4. Use document-level `smart-tables` defaults for broad behavior.
5. Use Div attributes for table-specific exceptions.
6. Render with Quarto and inspect unchanged tables with `diagnostics: true`.
7. If a table needs unsupported content, leave it out of the extension with
   `smart-tables="false"` rather than forcing a fragile conversion.
