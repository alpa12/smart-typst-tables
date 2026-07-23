# smart-typst-tables

`smart-typst-tables` is a Quarto extension that improves ordinary Pandoc tables
when rendering to Typst PDF, HTML pages, and revealjs presentations.

It is not an R table package. Users should be able to keep writing Markdown
tables or generating tables with tools such as `knitr::kable()`.

## Why this exists

Typst supports `auto`, fixed lengths, percentages, and `fr` tracks for table
columns, but it does not currently provide an intelligent automatic table layout
algorithm comparable to browser tables, Word, or LaTeX `tabularx`.

Quarto can translate some HTML/CSS styling to Typst, but layout-critical CSS such
as min/max widths, table layout, word breaking, and overflow behavior cannot be
relied on for high-quality Typst PDF tables.

This extension therefore analyzes Pandoc `Table` nodes before output and applies
format-specific rendering:

- for Typst, it generates native Typst `table()` code with better column tracks,
  header wrapping, alignment, and academic styling;
- for HTML and revealjs, it preserves native Pandoc/Quarto tables and adds
  classes, header wrapping, inferred alignment, responsive wrappers, and CSS
  profiles.

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

The same filter can be used with HTML and revealjs:

```yaml
format: html
filters:
  - quarto
  - smart-typst-tables
```

For HTML and revealjs, the extension keeps Pandoc's native table structure and
adds conservative classes and responsive wrappers. Rich cell content, merged
cells, captions, identifiers, and source widths remain available to the browser.
For ordinary tables, inferred column weights reserve more width for descriptive
text and less for numeric values; declared `tbl-colwidths` and list-table
`widths` remain authoritative.

```yaml
format: revealjs
filters:
  - quarto
  - smart-typst-tables
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
  header-lines: auto
  repeat-header: true
  stripe: false
  diagnostics: false
```

| Option | Default | Values | Effect |
|---|---:|---|---|
| `profile` | `academic` | `academic`, `compact`, `exam`, `plain` | Selects the visual profile: font size, cell insets, header fill, row rules, and spacing. |
| `text-size` | `auto` | `auto`, a size such as `0.88em` or `9pt`, or a number interpreted as `em` | Overrides the profile's table text size. Use `auto` to keep the selected profile's default size. |
| `table-width` | `natural` | `natural`, `full` | Controls the overall width strategy. `natural` keeps the table close to its content width; `full` wraps the table in a full-width block and lets free-text or mixed columns receive flexible `fr` tracks. |
| `align` | `center` | `left`, `center`, `right`, `none` | Aligns the whole rendered table or table figure. This is separate from per-column alignment, which is inferred from source alignment and column type. |
| `optimize-widths` | `true` | `true`, `false` | Enables the layout engine. When `false`, the table is left unchanged because no column plan is produced. |
| `wrap-headers` | `balanced` | `balanced` | Enables balanced header line breaking. The current implementation uses balanced wrapping. |
| `header-lines` | `auto` | `auto`, positive integer | In `auto`, long labels normally use two balanced lines and only very long labels use more, up to `max-header-lines`. Set an integer to force that number of lines when the header has enough words. |
| `repeat-header` | `true` | `true`, `false` | In Typst, emits a repeatable `table.header()`. In HTML/revealjs, marks the table for repeated headers in print CSS where supported. |
| `stripe` | `false` | `true`, `false` | Adds alternating row fill for even body rows using the selected profile's stripe color. |
| `diagnostics` | `false` | `true`, `false` | Logs skip reasons with the `[smart-typst-tables]` prefix while rendering. Use this when a table is unexpectedly unchanged. |

Revealjs accepts a nested configuration block. When no profile is set,
Revealjs automatically uses the readable `reveal` profile.

```yaml
smart-tables:
  revealjs:
    max-width: 100%
    max-height: 70vh
    overflow: auto
    font-size: auto
```

The wrapper uses `max-width`, `max-height`, and `overflow`; `font-size`
overrides the profile only for Revealjs tables. Tables in `columns` receive a
smaller height cap, while scrollable slides keep their native scrolling.

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
| `smart-tables-text-size="0.88em"` | `auto`, a size such as `0.88em` or `9pt`, or a number interpreted as `em` | Overrides `text-size` for this table. |
| `smart-tables-stripe="true"` | `true`, `false` | Overrides `stripe` for this table. |
| `smart-tables-row-rules="false"` | `true`, `false` | Overrides `row-rules` for this table. |
| `smart-tables-repeat-header="false"` | `true`, `false` | Overrides `repeat-header` for this table. |
| `smart-tables-max-header-lines="2"` | Positive integer | Overrides `max-header-lines` for this table. |
| `smart-tables-header-lines="2"` | `auto`, positive integer | Forces the number of balanced header lines for this table. |
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
| `reveal` | Default for Revealjs when no profile is configured. | Readable slide-sized text, high-contrast header, airy rows, and browser wrapping. |

## Customizing HTML and Revealjs styling

The extension supplies the structure, responsive wrapper, inferred alignment,
and a small set of CSS custom properties. Override those properties in your
own stylesheet to apply a visual identity without forking the extension.
This styling layer applies to HTML and Revealjs only: Typst tables are native
Typst output and do not consume browser CSS.

Register a stylesheet after the extension in your document or project:

```yaml
format:
  html:
    css: styles.scss
  revealjs:
    css: styles.scss
```

Scope an override to a table container. This keeps the extension defaults for
the rest of the document and works for a captioned table as well:

```markdown
::: {#tbl-kpis .table-brand}
| Indicator | Current value | Note |
|---|---:|---|
| Retention | 91.0% | Above the quarterly target. |

Key performance indicators.
:::
```

```scss
/* Stylesheet loaded by Quarto after smart-typst-tables. */
.table-brand .smart-table-wrap {
  --smart-table-font-size: 0.95em;
  --smart-table-leading: 1.35;
  --smart-table-inset-x: 0.7em;
  --smart-table-inset-y: 0.45em;
  --smart-table-header-fill: #123b5d;
  --smart-table-stripe-fill: #edf5fb;
  --smart-table-header-stroke: #123b5d;
  --smart-table-row-stroke: #bfd0dd;
  --smart-table-header-stroke-width: 2px;
  --smart-table-row-stroke-width: 1px;
}

.table-brand .smart-table thead th {
  color: #fff;
  font-family: "Aptos Display", sans-serif;
  letter-spacing: 0.01em;
}

.table-brand .smart-table td {
  font-family: "Aptos", sans-serif;
}

.table-brand .smart-table td.smart-table-type-percentage {
  color: #075f46;
  font-variant-numeric: tabular-nums;
}
```

### Styling hooks

Use the following hooks rather than targeting Quarto's generic `table`, `th`,
or `td` selectors. They only affect tables transformed by this extension.

| Hook | Purpose |
|---|---|
| `.smart-table-scroll` | Full available-width responsive and horizontal-scroll container. Set margins or scroll-bar appearance here; keep `overflow-x: auto` for wide tables. |
| `.smart-table-wrap` | Intrinsic-width inner wrapper and CSS-variable host. Set the properties below here. |
| `.smart-table` | The native `<table>` element. Use it for borders, `border-collapse`, shadows, or a conservative background. |
| `.smart-table thead th` / `.smart-table td` | Header and body cell typography, colors, and padding. |
| `.smart-table-profile-academic`, `.smart-table-profile-compact`, `.smart-table-profile-exam`, `.smart-table-profile-plain`, `.smart-table-profile-reveal` | Target one extension profile without affecting the others. |
| `.smart-table-type-numeric`, `.smart-table-type-currency`, `.smart-table-type-percentage`, `.smart-table-type-date`, `.smart-table-type-duration`, `.smart-table-type-free_text` | Target inferred semantic column types. The class is present on both headers and cells. |
| `.smart-table-align-left`, `.smart-table-align-center`, `.smart-table-align-right` | Target inferred or explicit alignment when a visual adjustment is needed. |
| `.smart-table-header-lines` | The inner span containing deliberate header line breaks. Avoid overriding its `white-space: nowrap`; doing so can introduce an unintended third line. |

The variables exposed by `.smart-table-wrap` are `--smart-table-font-size`,
`--smart-table-leading`, `--smart-table-inset-x`, `--smart-table-inset-y`,
`--smart-table-header-fill`, `--smart-table-stripe-fill`,
`--smart-table-header-stroke`, `--smart-table-row-stroke`,
`--smart-table-header-stroke-width`, and `--smart-table-row-stroke-width`.

For Revealjs, scope slide-specific rules with `.reveal` and prefer the
configuration block for geometry:

```yaml
smart-tables:
  revealjs:
    max-width: 100%
    max-height: 60vh
    overflow: auto
    font-size: 0.84em
```

```scss
.reveal .table-brand .smart-table-wrap {
  --smart-table-header-fill: #182b49;
  --smart-table-stripe-fill: #f0f4f8;
}
```

### Preserve layout behavior

Do not globally force `.smart-table` to `width: 100%`, change
`.smart-table-wrap` to `display: block`, or remove the nested
`.smart-table-scroll` container: those rules undo natural-width sizing or hide
wide columns. Use `smart-tables-width="full"` when a particular table should
occupy the available width. Respect explicit source widths (`tbl-colwidths` or
list-table `widths`) unless the author has chosen `explicit-widths: optimize`.

Raw HTML tables and `knitr::kable(format = "html")` are deliberately not
transformed. Style those with their own classes; they do not receive
`smart-table` hooks.

## Agent skills

The extension ships a concise authoring skill at
[`_extensions/smart-typst-tables/skill`](./_extensions/smart-typst-tables/skill).
It covers activation, table options, Typst eligibility, and HTML/Revealjs
styling hooks. Repository contributors can use the separate maintainer skill at
[`maintain-smart-typst-tables`](./maintain-smart-typst-tables), whose references
cover architecture, the two backend contracts, and regression testing.

## R tables and compatibility

The portable R route is a Markdown/Pandoc table. A small helper makes that
intent explicit:

```r
smart_kable <- function(x, caption = NULL, format = "pipe") {
  knitr::kable(x, caption = caption, format = format)
}
```

Use it in a chunk with `#| output: asis`; Quarto can then preserve labels,
captions, and references before the filter runs. `knitr::kable(format = "html")`
is deliberately left untouched, as are `kableExtra`, `gt`, and custom HTML.
When a Quarto pipeline normalizes an HTML table into a Pandoc table, preserve it
explicitly with `table.attr = 'data-smart-tables-raw="true"'`.

| Source | HTML / Revealjs | Typst optimization |
|---|---|---|
| Markdown pipe or grid table | Supported | Supported |
| Simple list-table | Supported | Supported |
| List-table with spans or rich cells | Supported conservatively | Left unchanged |
| `kable(format = "pipe" | "markdown")` | Supported when represented as a Pandoc table | Supported when eligible |
| `kable(format = "html")`, `kableExtra`, `gt` | Left native | Not transformed |

## Examples

```bash
quarto render examples/example.qmd
quarto render examples/html.qmd
quarto render examples/revealjs.qmd
```

## Current limitations

- Typst keeps a conservative fallback for complex cell blocks, math, raw HTML,
  and spans. HTML and Revealjs preserve those constructs natively.
- Explicit source widths are treated as user intent and are not overridden by
  default.
- The layout engine is heuristic, not a font measurement engine.
- HTML/revealjs support preserves Quarto's native table markup instead of
  generating raw HTML. This protects captions and cross-references, but means
  browser layout remains responsible for final column sizing.
- `repeat-header` is meaningful for Typst page breaks and may help print HTML;
  it does not repeat table headers during revealjs slide navigation.

See [DESIGN.md](DESIGN.md) for the architecture and roadmap.
