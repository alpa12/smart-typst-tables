# Testing and fixtures

Run the full check from the repository root:

```bash
Rscript --vanilla tests/test-rendering.R
```

It renders HTML and Revealjs fixtures with Quarto and checks structural HTML
markers. Add fixtures for behavior that depends on captions, Div attributes,
list-tables, spans, rich cells, explicit widths, raw HTML, columns, and
Revealjs containers.

For a fast filter-only HTML inspection, bypass Quarto's HTML theme pipeline:

```bash
quarto pandoc examples/html.qmd \
  --lua-filter=_extensions/smart-typst-tables/smart-typst-tables.lua \
  -t html -o /private/tmp/smart-tables-check.html
```

Inspect classes, `<col>` proportions, inline natural width, captions, IDs,
`rowspan`/`colspan`, and `data-smart-tables-processed`. This command is not a
replacement for a Quarto render: it does not inject the extension CSS or test
the theme cascade.

Some macOS environments have a Quarto Dart Sass crash while rendering. Record
the failure, use the direct structural check above, and rely on Linux CI for
the full render. Always run `git diff --check`.
