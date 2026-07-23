# Architecture

The entry point is `_extensions/smart-typst-tables/smart-typst-tables.lua`.
It loads configuration, detects the target, extracts a model, chooses an
eligibility path, creates a shared plan, and dispatches to a renderer.

| File | Responsibility |
|---|---|
| `modules/config.lua` | Defaults, metadata, target defaults, and table-level overrides. |
| `modules/table_ast.lua` | Pandoc table model, logical columns through spans, features, and eligibility. |
| `modules/type_inference.lua` | Detects numeric, French-formatted numeric, date, duration, code, categorical, and free-text columns. |
| `modules/header_wrap.lua` | Balanced word-based header line selection and forced line counts. |
| `modules/layout_engine.lua` | Shared column plan: inferred types, alignment, header lines, Typst-oriented tracks, profile, and table options. |
| `modules/typst_writer.lua` | Native Typst table source. |
| `modules/html_transformer.lua` | Conservative Pandoc HTML decoration, natural-width weights, and responsive wrappers. |
| `smart-tables.html` | HTML/Revealjs profiles, structural CSS, variables, and diagnostics styling. |
| `smart-typst-tables.typ` | Typst helper definitions. |

The filter first visits option-bearing Divs. A captioned Quarto table is a Div
with both a Table and caption blocks; pass smart-table attributes to its one
contained table while retaining the Div ID for cross-references. Tables are
then visited normally; the processed marker prevents a second transformation.

Do not merge backend implementation details into `layout_engine.lua` unless
both renderers genuinely need the decision. HTML can use `plan.types`,
`plan.header_lines`, and alignment while applying its own browser-width policy.
