# Typst authoring and fallback

The Typst backend generates native `table()` code and is intentionally more
conservative than the HTML backend. Keep cells simple for optimized Typst:
one `Plain` or `Para` block made of text, spaces, and line breaks.

Typst leaves a table unchanged when it has spans, rich inline content (links,
emphasis, math, code, raw HTML), multiple blocks, explicit source widths under
`explicit-widths: respect`, more than 14 columns, or unsafe fixed-width tracks.
Use `diagnostics: true` and inspect Quarto's
`[smart-typst-tables]` messages to identify the reason.

Use metadata and attributes, not CSS, to control Typst tables. The most useful
choices are `profile`, `text-size`, `table-width`, `align`, `stripe`,
`row-rules`, `header-lines`, and `max-header-lines`. Use
`smart-tables="false"` to preserve a special table rather than weakening it to
fit the optimizer.

Use `tbl-colwidths` only when the author owns the column proportions. They are
respected by default. Set `explicit-widths: optimize` only when the source
widths are intentionally disposable.
