# smart-typst-tables

`smart-typst-tables` is a Quarto extension and small R helper for producing
high-quality native Typst PDF tables from data frames, with minimal table-by-table
formatting.

The main target is Quarto documents rendered with `format: typst`.

## Installation

Install the extension from GitHub:

```bash
quarto add OWNER/smart-typst-tables
```

Replace `OWNER` with the GitHub account or organization that hosts this
repository.

## Minimal usage

In a Quarto document:

````markdown
---
format: typst
filters:
  - smart-typst-tables
---

```{r}
#| output: asis
source("R/smart_table.R")

transactions |>
  smart_table()
```
````

If you installed the extension with `quarto add`, source the installed helper:

````markdown
```{r}
#| output: asis
source("_extensions/smart-typst-tables/smart_table.R")
```
````

With a caption and explicit profile:

````markdown
```{r}
#| output: asis
transactions |>
  smart_table(
    caption = "Données",
    profile = "academic",
    width = "100%",
    auto_widths = TRUE
  )
```
````

The function returns raw Typst wrapped as Quarto raw output via
`knitr::asis_output()`.

## What it does

`smart_table()`:

- infers date, currency, numeric, percentage, categorical, text, and long-text columns;
- aligns text left, dates centered by default, and numeric-like columns right;
- computes column widths as a mix of `auto`, fixed `em` widths, and `fr` tracks;
- wraps long headers across two or three balanced lines without breaking words;
- emits native Typst `table()` code using repeatable `table.header()`;
- uses local table typography so wide tables do not inherit oversized document
  body text;
- uses an academic default style: no vertical rules, strong headers, a shaded
  header, a horizontal rule under the header, and compact cell insets;
- optionally supports striped rows, light row rules, notes, and `figure()` captions.

## Advanced options

```r
smart_table(
  transactions,
  caption = "Transactions",
  width = "100%",
  auto_widths = TRUE,
  align_dates = "left",
  header_breaks = list(
    "Date d'effet de police" = c("Date d'effet", "de police")
  ),
  notes = "Source: example data.",
  striped = TRUE,
  row_rules = TRUE,
  font_size = "8.5pt"
)
```

Built-in profiles:

- `academic`: default booktabs-like style for course notes.
- `compact`: smaller text and tighter insets for dense appendices.
- `teaching`: slightly more visual contrast for handouts.
- `spacious`: larger type and insets for short tables.

Use `col_widths` and `header_breaks` only when you need a known layout:

```r
smart_table(
  comparison,
  auto_widths = FALSE,
  col_widths = c("1.2fr", "1fr", "1.2fr", "2.6fr"),
  header_breaks = list("Temps de préparation" = c("Temps de", "préparation"))
)
```

Useful lower-level functions are also exposed from `R/smart_table.R`:

- `infer_column_types(data)`
- `infer_alignment(data, types)`
- `compute_widths(data, types, headers)`
- `wrap_headers(headers, max_lines = 3)`
- `escape_typst(x)`
- `as_typst_table(data, spec)`

## Why widths are computed in R

Typst tables support `auto`, fixed lengths, percentages, and `fr` track sizing.
They do not currently provide a native full-width layout algorithm equivalent to
“auto plus intelligent stretch” for arbitrary data frames.

This extension therefore computes a practical layout before Typst sees the table.
The R-side heuristic estimates the width need of each column from header length,
maximum cell length, median cell length, inferred column type, and number of
columns. Compact columns such as dates and currencies get fixed widths; short ID
or categorical columns can use `auto`; long text columns absorb remaining space
with `fr` tracks.

The heuristic is intentionally isolated in `compute_widths()` so it can be
improved without changing the public API.

## Customizing global table style

The extension injects `_extensions/smart-typst-tables/smart-typst-tables.typ`
for Typst output. At the moment the R generator emits the native table structure
directly and the Typst resource provides shared helpers such as note styling.

To customize global style, edit the Typst helper file in your installed extension
copy, or fork the repository and change:

```typst
#let smart-table-note(body) = {
  v(3pt)
  set text(size: 8.5pt, fill: luma(35%))
  body
}
```

For deeper styling changes, edit `as_typst_table()` in `R/smart_table.R`.

## Non-Typst output

For non-Typst formats, `smart_table()` emits a warning and falls back to a
Markdown table. The high-quality layout features are only available for Typst
because the function emits native Typst code.

## Example

Render the included example:

```bash
quarto render examples/example.qmd
```

It reproduces a policy transaction table with French headers, currency-like
columns, dates, and a long transaction-type column without manually specifying
column widths.

## Limitations

- Widths are heuristic, not a formal text-measurement engine.
- The generator optimizes for academic PDF tables, not heavily decorated tables.
- Very wide tables may still require a smaller page font, landscape page, or
  domain-specific width overrides.
- Complex cell content such as nested lists or rich Markdown is treated as plain
  text.
