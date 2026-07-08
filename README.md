# smart-typst-tables

`smart-typst-tables` is a Quarto extension that improves ordinary Pandoc tables
when rendering to Typst PDF.

It is not an R table package. Users should be able to keep writing Markdown
tables or generating tables with tools such as `knitr::kable()`.

## Why this exists

Typst supports `auto`, fixed lengths, percentages, and `fr` tracks for table
columns, but it does not currently provide an intelligent automatic table layout
algorithm comparable to browser tables, Word, or LaTeX `tabularx`.

Quarto can translate some HTML/CSS styling to Typst, but layout-critical CSS such
as min/max widths, table layout, word breaking, and overflow behavior cannot be
relied on for high-quality Typst PDF tables.

This extension therefore analyzes Pandoc `Table` nodes before Typst output and
generates native Typst `table()` code with better column tracks, header wrapping,
alignment, and academic styling.

## Installation

```bash
quarto add OWNER/smart-typst-tables
```

## Usage

```yaml
format: typst
filters:
  - quarto
  - smart-typst-tables
```

The `quarto` sentinel asks Quarto to run this filter after Quarto's built-in
normalization, which is important for captions and references.

Then write ordinary tables:

```markdown
| Team | Open tasks | Monthly cost | On-time rate |
|---|---:|---:|---:|
| Platform | 42 | 1 240 $ | 91.0% |
| Design | 18 | 980 $ | 94.2% |
```

## Configuration

Set document-level defaults with `smart-tables`:

```yaml
smart-tables:
  profile: academic
  text-size: auto
  table-width: natural
  align: center
  optimize-widths: true
  wrap-headers: balanced
  repeat-header: true
  stripe: false
  diagnostics: false
```

| Option | Default | Values | Effect |
|---|---:|---|---|
| `profile` | `academic` | `academic`, `compact`, `exam`, `plain` | Selects the visual profile used by the Typst helper: font size, cell insets, header fill, row rules, and spacing. |
| `text-size` | `auto` | `auto`, a Typst size such as `0.88em` or `9pt`, or a number interpreted as `em` | Overrides the profile's table text size. Use `auto` to keep the selected profile's default size. |
| `table-width` | `natural` | `natural`, `full` | Controls the overall width strategy. `natural` keeps the table close to its content width; `full` wraps the table in a full-width block and lets free-text or mixed columns receive flexible `fr` tracks. |
| `align` | `center` | `left`, `center`, `right`, `none` | Aligns the whole rendered table or table figure. This is separate from per-column alignment, which is inferred from source alignment and column type. |
| `optimize-widths` | `true` | `true`, `false` | Enables the layout engine. When `false`, the table is left unchanged because no column plan is produced. |
| `wrap-headers` | `balanced` | `balanced` | Enables balanced header line breaking. The current implementation uses balanced wrapping. |
| `repeat-header` | `true` | `true`, `false` | Emits a Typst `table.header()` with `repeat:` set to this value, so headers can repeat across page breaks. |
| `stripe` | `false` | `true`, `false` | Adds alternating row fill for even body rows using the selected profile's stripe color. |
| `diagnostics` | `false` | `true`, `false` | Logs skip reasons with the `[smart-typst-tables]` prefix while rendering. Use this when a table is unexpectedly unchanged. |

Additional document-level options are available for advanced cases:

| Option | Default | Values | Effect |
|---|---:|---|---|
| `enabled` | `true` | `true`, `false` | Turns the filter behavior on or off for the document. |
| `row-rules` | `true` | `true`, `false` | Adds horizontal rules between body rows using the selected profile's row stroke. |
| `fallback` | `unchanged` | `unchanged` | Reserved fallback policy. Current behavior is to leave unsupported or risky tables unchanged. |
| `max-header-lines` | `3` | Positive integer | Maximum number of lines used when wrapping long column headers. |
| `explicit-widths` | `respect` | `respect`, `optimize` | Controls tables with explicit source widths such as `tbl-colwidths` or nonzero Pandoc column widths. `respect` leaves them unchanged; `optimize` lets this extension override them. |

Use table-level attributes for local overrides:

```markdown
::: {smart-tables="false"}
| A | B |
|---|---|
| 1 | 2 |
:::
```

| Attribute | Values | Effect |
|---|---|---|
| `smart-tables="false"` | `false`, `off` | Leaves this table unchanged. |
| `smart-tables-profile="compact"` | `academic`, `compact`, `exam`, `plain` | Overrides `profile` for this table. |
| `smart-tables-text-size="0.88em"` | `auto`, a Typst size such as `0.88em` or `9pt`, or a number interpreted as `em` | Overrides `text-size` for this table. |
| `smart-tables-stripe="true"` | `true`, `false` | Overrides `stripe` for this table. |
| `smart-tables-row-rules="false"` | `true`, `false` | Overrides `row-rules` for this table. |
| `smart-tables-repeat-header="false"` | `true`, `false` | Overrides `repeat-header` for this table. |
| `smart-tables-max-header-lines="2"` | Positive integer | Overrides `max-header-lines` for this table. |
| `smart-tables-optimize-widths="false"` | `true`, `false` | Overrides `optimize-widths` for this table. |
| `smart-tables-width="full"` | `natural`, `full` | Overrides `table-width` for this table. Use `full` when remaining width should be allocated to text-heavy columns. |
| `smart-tables-align="left"` | `left`, `center`, `right`, `none` | Overrides whole-table alignment for this table. |

## Profiles

| Profile | Use case | Styling |
|---|---|---|
| `academic` | Default professional PDF tables. | Booktabs-like table with modest font size, light header fill, row rules, and moderate spacing. |
| `compact` | Dense course notes, appendices, and space-constrained reports. | Noticeably smaller text, tight insets, tight leading, compact gutters, darker header fill, and subtle row rules. |
| `exam` | Exams, assignments, and documents where readability matters more than density. | Larger text, generous insets, stronger header fill, heavier header rule, and clearer row separation. |
| `plain` | Documents that need layout optimization with minimal decoration. | No header or stripe fill, no body row rules, lighter header rule, and restrained spacing. |

## Examples

```bash
quarto render examples/example.qmd
```

## Current limitations

- Complex cell blocks, math, raw HTML, and spans fall back unchanged.
- Explicit source widths are treated as user intent and are not overridden by
  default.
- The layout engine is heuristic, not a font measurement engine.
- The filter currently targets Typst only.

See [DESIGN.md](DESIGN.md) for the architecture and roadmap.
