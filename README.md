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
| Segment | Polices | Prime moyenne | Ratio de conversion |
|---|---:|---:|---:|
| Nouvelles ventes | 128 | 1 240 $ | 42.5% |
| Renouvellements | 94 | 980 $ | 71.0% |
```

## Configuration

```yaml
smart-tables:
  profile: academic
  table-width: natural
  align: center
  optimize-widths: true
  wrap-headers: balanced
  repeat-header: true
  stripe: false
  diagnostics: false
```

Table-level opt-out:

```markdown
::: {smart-tables="false"}
| A | B |
|---|---|
| 1 | 2 |
:::
```

`table-width: natural` keeps the table close to its content width instead of
stretching across the page. `align: center` centers the natural-width table
horizontally. Use `smart-tables-width="full"` on a specific table only when you
want remaining width to be allocated to text columns.

## Profiles

- `academic`: default booktabs-like tables.
- `compact`: dense course notes and appendices.
- `exam`: slightly larger, clear tables for exams.
- `plain`: layout optimization with minimal decoration.

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
