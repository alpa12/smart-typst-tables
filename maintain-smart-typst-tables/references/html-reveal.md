# HTML and Revealjs maintenance

HTML eligibility intentionally accepts rich cells, multiple header rows, spans,
explicit widths, and wide tables. The transformer must decorate existing
`th`/`td` cells; do not reconstruct rich inlines or blocks.

## Width and wrapper contract

For ordinary tables without author-specified widths:

1. `html_transformer.lua` infers a natural per-column width from type, header
   lines, unbreakable content, and text length.
2. It applies a semantic bias: compact structural columns yield room to
   `free_text` and mixed columns.
3. It writes proportional colspecs and an intrinsic `em` width.
4. It emits `smart-table-scroll > smart-table-wrap > table`.

The outer scroll container is `width: 100%`, `max-width: 100%`, and owns
`overflow-x: auto`. The inner wrapper and table use the planned intrinsic width
to resist theme rules such as `table { width: 100% }`. Do not remove inline
important widths without replacing that protection. In Quarto `.columns`,
ensure the scroll container can shrink (`min-width: 0`) so overflow remains
scrollable rather than clipped.

Explicit `tbl-colwidths`, list-table `widths`, and Pandoc widths remain source
intent. Do not synthesize planned widths for them unless configuration opts in.

## Cell and header rules

Apply inferred classes directly to table cells so attributes and rich content
survive. Use logical columns from `table_ast.logical_rows` rather than physical
cell indices for spans. Reconstruct header content only for simple text cells.
For those headers, preserve the chosen explicit `LineBreak`s with the inner
`.smart-table-header-lines` class and its `white-space: nowrap` CSS.

For grouped header rows, avoid a line between intermediate header rows; retain
the final header separator and ensure a rowspan cell reaches it.

Raw HTML (`data-smart-tables-raw="true"`, HTML kable, `gt`, `kableExtra`) must
not acquire wrappers or `smart-table` classes.
