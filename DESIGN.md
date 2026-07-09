# smart-typst-tables v2 design

This document defines the v2 architecture from first principles. The previous
prototype is intentionally ignored. The goal is not to preserve an API or code
path; the goal is to design the best Quarto extension for professional Typst
tables from ordinary Quarto authoring.

## 1. Objective

The extension should make ordinary Quarto tables render as noticeably better
Typst PDF tables, with minimal author effort.

The primary authoring workflows are:

- Markdown pipe tables and grid tables.
- Pandoc `Table` elements produced by Quarto.
- Computational tables that become Pandoc tables, such as many `knitr::kable()`
  outputs.
- Simple table-like output from supported engines when Quarto/Pandoc can
  represent it as a `Table`.

The user should not need to call an R function such as `smart_table()`. A manual
API can exist later for hard cases, but it must not be the central workflow.

## 2. Research findings

### 2.1 Quarto rendering pipeline

Quarto uses Pandoc as the document conversion core. A document is parsed into the
Pandoc abstract syntax tree, filters transform that tree, then a writer emits the
target format. Quarto filter extensions are Pandoc Lua filters packaged under
`_extensions/<extension-name>/`. Quarto recommends Lua filters for this kind of
AST transformation because they avoid external dependencies and process startup
overhead.

Quarto user filters normally run before Quarto's built-in filters unless the
user explicitly positions them relative to the `quarto` sentinel in the
`filters` list. This matters because table captions, cross-references, layout
classes, and computational output may be normalized by Quarto filters before the
final Typst writer sees them.

Quarto format extensions can bundle filters and default metadata. They are useful
for an optional turnkey authoring format, but they require users to change
`format:`. A plain filter extension is easier to add to existing Typst documents.

### 2.2 Quarto Typst output and CSS conversion

Quarto Typst output supports Typst-specific features and can translate a subset
of CSS-like styling into Typst properties. This is useful for colors, borders,
fonts, and similar visual properties. It is not a table layout engine. The
properties that matter most for intelligent table layout, such as min/max widths,
table layout algorithms, word-breaking policy, and overflow behavior, cannot be
relied on as a cross-format CSS bridge.

Therefore, building beautiful HTML tables is insufficient. For Typst PDFs, the
extension must make layout decisions before or during Typst generation.

### 2.3 Pandoc Table AST

Pandoc exposes tables as structured `Table` elements with:

- table attributes;
- caption;
- column specifications with alignment and fractional widths;
- header, body, and footer sections;
- row and cell objects;
- cell contents;
- row spans and column spans.

This is the right abstraction for transparent improvement because Markdown pipe
tables, grid tables, and many computational tables converge here.

Pandoc `ColSpec` widths are page-fraction numbers. They cannot directly express
Typst's richer table track choices such as `auto`, fixed lengths, and `fr`.
Quarto already has internal handling for `tbl-colwidths`, but that path maps
metadata into Pandoc fractional colspecs. It is useful for ordinary Pandoc
writers, not sufficient for this extension's intended Typst-native layout.

Explicit user widths are still valuable evidence. If a table has `tbl-colwidths`
or nonzero Pandoc column widths, v2 should not discard them blindly. The layout
engine should either translate them into compatible Typst tracks or treat them as
a signal to leave the table alone.

### 2.4 Typst tables

Typst native `table()` is the correct output primitive. It supports:

- `columns` specified as count, `auto`, fixed lengths, percentages, and relative
  tracks;
- `table.cell()` for per-cell styling, alignment, fill, inset, row spans, and
  column spans;
- `table.hline()` and `table.vline()` for rule control;
- `table.header()` with repeatable headers;
- `table.footer()` for repeatable footers;
- arbitrary cell content.

Typst table packages such as `tablex` are not the preferred foundation for v2.
The `tablex` package itself now recommends built-in Typst tables for most use
cases because many of its features were upstreamed into Typst. Depending on a
third-party package would add install complexity without solving the core layout
problem: choosing good tracks from table content.

### 2.5 Consequence

The cleanest v2 architecture is:

1. analyze Pandoc `Table` elements in a Quarto Lua filter;
2. infer table semantics and layout in Lua;
3. emit native Typst table code for eligible tables;
4. leave unsupported or risky tables unchanged;
5. use a small Typst helper file for reusable visual styling, not for content
   analysis.

## 3. Architectural decision

v2 will be a Quarto Lua filter extension with a pure Lua layout engine and a
small Typst style/runtime helper.

The extension should not be R-first. R can produce tables, but the extension must
work after Quarto has normalized the document into the Pandoc AST. That is the
only point where Markdown tables, grid tables, and many generated tables can be
handled uniformly.

The extension should not be HTML-first. HTML/CSS output cannot reliably control
Typst table layout.

The extension should not be Typst-only. Typst receives the final content but does
not have direct access to the richer Pandoc table structure, original table
metadata, or Quarto table conventions at the right abstraction level. Typst
helpers should render and style, while the Lua filter should analyze and plan.

## 4. Proposed repository structure

The implementation phase should start from a clean tree with this structure:

```text
README.md
DESIGN.md
LICENSE
examples/
  markdown-tables.qmd
  computational-tables.qmd
  edge-cases.qmd
  data/
    transactions.csv
_extensions/
  smart-typst-tables/
    _extension.yml
    smart-typst-tables.lua
    smart-typst-tables.typ
    modules/
      config.lua
      table_ast.lua
      text_metrics.lua
      type_inference.lua
      layout_engine.lua
      header_wrap.lua
      typst_writer.lua
      diagnostics.lua
tests/
  fixtures/
    ...
  testthat/
    ...
  snapshots/
    ...
```

The test runner can be R `testthat`, Lua-based tests, or both. The production
extension code should remain Lua and Typst.

## 5. Rendering pipeline

The target pipeline is:

```text
Quarto source
  ↓
Execution engines produce output
  ↓
Pandoc reader builds document AST
  ↓
Quarto built-in filters normalize captions, crossrefs, figures, layout
  ↓
smart-typst-tables analyzes eligible Table nodes
  ↓
smart-typst-tables replaces eligible tables with RawBlock("typst")
  ↓
Pandoc Typst writer emits remaining document
  ↓
Typst compiler renders PDF
```

The exact filter phase must be validated during implementation. The preferred
phase is after Quarto has normalized table captions and references but before the
Pandoc Typst writer emits output. If Quarto extension metadata cannot reliably
target that phase, v2 should provide two supported activation modes:

1. plain filter mode for existing documents;
2. optional custom format mode that bundles the filter in the correct order.

The design must not silently sacrifice cross-references for prettier tables.

## 6. Component responsibilities

### 6.1 `_extension.yml`

Responsibilities:

- register the Lua filter;
- make the Typst helper available;
- declare minimum Quarto version;
- later, optionally expose a custom `smart-typst` format that derives from Typst
  and bundles the filter in a controlled order.

### 6.2 `smart-typst-tables.lua`

Responsibilities:

- entry point only;
- detect whether the current target is Typst;
- load modules through relative `require()`;
- load document-level configuration;
- register table handlers;
- inject or include the Typst helper file;
- coordinate diagnostics.

It should contain orchestration code, not layout algorithms.

### 6.3 `config.lua`

Responsibilities:

- read metadata from `smart-tables` or `format.typst.smart-tables` after Quarto
  metadata merging;
- provide defaults;
- validate user options;
- merge table-specific attributes with document defaults;
- expose a simple normalized config object to the rest of the extension.

Initial document-level configuration:

```yaml
format:
  typst:
    smart-tables:
      profile: academic
      optimize-widths: true
      wrap-headers: balanced
      repeat-header: true
      stripe: false
      notes: true
      diagnostics: false
```

Table-level overrides should use attributes when possible:

```markdown
::: {smart-tables-profile="compact" smart-tables-stripe="true"}
| A | B |
|---|---|
| 1 | 2 |
:::
```

The exact attribute spelling should be finalized during implementation after
testing how Quarto preserves attributes on table containers and captions.

### 6.4 `table_ast.lua`

Responsibilities:

- convert a Pandoc `Table` into an internal neutral model;
- preserve caption, label, attributes, colspecs, alignment, headers, bodies,
  footers, spans, and cell contents;
- classify whether the table is eligible for optimization;
- identify table features that require fallback.

Internal model sketch:

```lua
{
  id = "tbl-transactions",
  caption = <pandoc Blocks>,
  attr = <pandoc Attr>,
  n_cols = 7,
  n_rows = 5,
  columns = {
    { source_align = "AlignDefault", source_width = 0 },
    ...
  },
  header_rows = {
    { cells = { ... } }
  },
  body_rows = {
    { cells = { ... } }
  },
  footer_rows = {},
  features = {
    has_spans = false,
    has_block_content = false,
    has_raw_content = false,
    has_math = false,
    has_links = false
  }
}
```

### 6.5 `text_metrics.lua`

Responsibilities:

- convert simple cell content to plain text for analysis only;
- compute Unicode-aware text lengths;
- compute maximum, median, mean, and percentile lengths;
- detect unbreakable tokens;
- estimate numeric precision;
- estimate visual width with simple character classes.

The metric engine should be deterministic and explicit. It should not attempt
font measurement in v2.0.

### 6.6 `type_inference.lua`

Responsibilities:

- infer column types from header and cell values;
- produce confidence scores, not only labels;
- combine source alignment with inferred type.

Initial types:

- `identifier`
- `date`
- `currency`
- `numeric`
- `percentage`
- `boolean`
- `categorical`
- `free_text`
- `code`
- `mixed`

The engine should prefer conservative classifications. A column with mixed
evidence should stay `mixed` and receive safe layout choices.

### 6.7 `header_wrap.lua`

Responsibilities:

- wrap headers only at spaces or explicit separators;
- never split words;
- preserve apostrophes and typographic characters;
- balance two- and three-line headers;
- accept a user dictionary for preferred breaks;
- eventually support language-specific phrase rules.

The first implementation should be deterministic:

1. tokenize header by whitespace while preserving punctuation inside tokens;
2. enumerate possible line-break combinations up to `max-lines`;
3. score candidates by maximum line length, line-length variance, and semantic
   penalties;
4. choose the lowest score.

### 6.8 `layout_engine.lua`

Responsibilities:

- decide column tracks;
- decide alignment;
- decide table profile;
- decide whether to use full body width or natural width;
- decide font size within safe profile bounds;
- detect when optimization is unsafe and return fallback.

The layout engine should produce a plan, not Typst code:

```lua
{
  columns = {"auto", "5.8em", "1.4fr", "2.6fr"},
  align = {"left", "right", "left", "left"},
  header_lines = {{"Prime", "annuelle"}, ...},
  font_size = "8.7pt",
  table_width = "100%",
  repeat_header = true,
  stripe = false,
  profile = "academic",
  diagnostics = {...}
}
```

Initial heuristic:

- identifiers get `auto` or a small fixed width;
- dates get compact fixed widths based on detected date format;
- numeric, currency, and percentage columns get compact fixed widths;
- code columns get fixed or `auto` based on unbreakable token length;
- short categorical columns get `auto`;
- free-text columns get `fr` and absorb remaining width;
- wide mixed columns get `fr`;
- if every column appears compact, allow natural width rather than forcing
  100%;
- if total fixed width risks starving any text column, shrink numeric/date
  widths within profile bounds before reducing text columns;
- if explicit `tbl-colwidths` or nonzero source widths exist, respect them unless
  the user opts into re-optimization;
- if no safe layout exists, leave the table unchanged.

### 6.9 `typst_writer.lua`

Responsibilities:

- render the internal model and layout plan as native Typst code;
- preserve simple inline formatting where safe;
- escape Typst syntax correctly;
- emit `figure()` when the table has a caption;
- emit labels compatible with Typst references;
- emit `table.header(repeat: ...)`;
- emit `table.cell()` with alignment, fill, spans, and inset;
- emit booktabs-like rules using `table.hline()`;
- call shared helper functions for consistent styling.

The writer should be deliberately conservative. If a cell contains content that
cannot be converted safely to Typst content, the table should not be optimized in
v2.0.

The writer must not start by supporting every Pandoc inline. The first supported
conversion matrix should be explicit:

| Pandoc content | v2.0 behavior |
| --- | --- |
| Plain text, spaces, punctuation | render as escaped Typst content |
| Strong/emphasis | render if round-trip tests pass |
| Code | render as Typst `raw` or fallback until tested |
| Math | fallback until a safe representation is tested |
| Links | preserve visible text first; link target support later |
| Raw inline/block | fallback |
| Multiple paragraphs/lists | fallback |

### 6.10 `smart-typst-tables.typ`

Responsibilities:

- define visual profiles;
- centralize colors, strokes, insets, and note styling;
- keep generated Typst smaller;
- provide stable extension points for user customization.

It should not infer column types or compute layout.

### 6.11 `diagnostics.lua`

Responsibilities:

- emit warnings only when useful;
- support a diagnostics mode that can insert comments or logs explaining layout
  decisions;
- provide a structured debug report for tests.

Diagnostics should be quiet by default. A user should not see warnings for every
table in a normal document.

## 7. Fallback and safety policy

The extension must never silently degrade a table.

Fallback to the original Pandoc table when:

- target format is not Typst;
- table has unsupported raw content;
- table has complex block content that cannot be safely converted;
- row or column spans are too complex for the current writer;
- required cross-reference/caption semantics cannot be preserved;
- layout scoring cannot find a non-pathological plan;
- configuration explicitly disables optimization for that table.

Fallback is not failure. It is the correct behavior when the extension cannot
improve a table safely.

## 8. Configuration design

Document-level configuration:

```yaml
format:
  typst:
    smart-tables:
      profile: academic
      optimize-widths: true
      wrap-headers: balanced
      repeat-header: true
      stripe: false
      fallback: unchanged
      diagnostics: false
```

Potential profiles:

- `academic`: default booktabs-like style.
- `compact`: dense lecture notes and appendices.
- `exam`: high clarity, slightly larger type, minimal decoration.
- `textbook`: balanced spacing and repeated headers.
- `plain`: minimal visual changes, layout optimization only.

Table-level overrides should be possible but uncommon:

```markdown
::: {smart-tables-profile="compact" smart-tables-width="natural"}
| A | B |
|---|---|
| 1 | 2 |
:::
```

Opt-out:

```markdown
::: {smart-tables="false"}
| A | B |
|---|---|
| 1 | 2 |
:::
```

## 9. Caption and cross-reference strategy

Captions and labels are non-negotiable for academic documents.

The implementation must test these cases before broad optimization is enabled:

- Markdown table with caption and `#tbl-*` label.
- Computational table with `#| label: tbl-*` and `#| tbl-cap`.
- Table without caption.
- Table in a float/panel layout.
- Table referenced later with `@tbl-*`.

Preferred strategy:

1. allow Quarto to normalize table captions and identifiers;
2. read the final table identifier and caption from the AST;
3. emit a Typst `figure(kind: table, caption: ...)` with the same label;
4. verify that Quarto references still resolve correctly.

If this cannot be made reliable as a plain filter, the extension should ship an
optional custom Typst format that controls filter order.

## 10. Testing strategy

Testing must cover both algorithms and rendered output.

### 10.1 Unit tests

- UTF-8 text measurement.
- Type inference.
- Header wrapping.
- Width scoring.
- Configuration parsing.
- Typst escaping.
- AST model extraction from Pandoc tables.
- Fallback decisions.

### 10.2 Snapshot tests

- deterministic Typst output for known fixtures;
- diagnostic reports for known fixtures;
- unchanged output for unsupported tables.

### 10.3 Integration tests

Render Quarto documents to Typst/PDF for:

- narrow pages;
- wide pages;
- transaction tables;
- insurance examples;
- many numeric columns;
- many date columns;
- French headers;
- English headers;
- long free-text columns;
- code-like columns;
- booleans;
- missing values;
- long unbreakable strings;
- spans;
- captions and cross-references;
- computational tables from R and Python when Quarto turns them into Pandoc
  tables.

### 10.4 Visual regression

Visual regression should be added after the first stable implementation. The
initial approach can render PDFs to PNG and compare either images or OCR-free
layout metrics. This should not block v2.0 alpha, but it should be part of the
open-source quality roadmap.

## 11. Documentation strategy

The README must be rewritten from scratch.

It should explain:

- why the extension exists;
- why Typst alone does not solve intelligent table layout;
- why HTML/CSS translation is insufficient;
- the rendering pipeline;
- installation with `quarto add`;
- how to enable the filter project-wide;
- examples using ordinary Markdown tables;
- examples using computational tables;
- document-level configuration;
- table-level opt-out and overrides;
- limitations;
- roadmap.

The README should not lead with an R API.

## 12. Known limitations

v2.0 should explicitly limit scope:

- no formal font measurement engine;
- no guarantee of optimal layout;
- no conversion of arbitrary HTML tables unless Quarto/Pandoc exposes them as
  structured tables;
- limited support for complex block content in cells;
- limited or deferred support for row/column spans;
- no automatic language-specific header phrase model in the first release;
- no promise to improve every table.

The extension's contract is: improve eligible ordinary tables; leave unsafe
tables unchanged.

## 13. Critical self-review

### Weakness 1: replacing tables with raw Typst may bypass Quarto semantics

Raw Typst output risks bypassing Quarto's table handling, captions, numbering,
and cross-references. This is the largest architectural risk.

Revision:

- Do not replace tables until filter ordering is proven.
- Make caption/cross-reference preservation a milestone-zero test.
- If ordinary filter ordering is insufficient, add a custom Typst format wrapper
  that controls order.
- Keep fallback behavior for any table whose label/caption cannot be preserved.

### Weakness 2: Lua may be less convenient than R for data analysis

R is better at data frame analysis, but the extension must improve ordinary
Markdown and Pandoc tables. Requiring R would exclude Python, Julia, Markdown-only
authors, and non-code tables.

Revision:

- Keep production analysis in Lua.
- Keep the algorithms simple and deterministic.
- Use R only for tests or fixture generation if useful.

### Weakness 3: Typst raw generation can become brittle

Generating strings of Typst code is error-prone.

Revision:

- Separate layout planning from Typst rendering.
- Centralize escaping in one module.
- Use snapshot tests extensively.
- Keep Typst helpers small and stable.
- Prefer generating native `table()` code over inventing a large custom Typst
  DSL.
- Define and test a small content-conversion matrix before optimizing broad
  classes of tables.

### Weakness 4: transparent behavior can surprise users

Automatically changing every table may surprise users when a table was already
carefully formatted.

Revision:

- Default to optimizing only eligible simple tables.
- Support table-level opt-out.
- Respect explicit user widths where possible; if a user gave widths, assume
  intent and do not override unless configured.
- Provide diagnostics mode to explain choices.

### Weakness 5: rich cell content may be hard to preserve

Pandoc cells can contain links, emphasis, code, math, paragraphs, and raw blocks.
Converting all of this into raw Typst safely is nontrivial.

Revision:

- v2.0 should optimize simple inline content first.
- Math, code, emphasis, and links can be supported incrementally.
- Complex block content should initially fallback unchanged.

### Weakness 6: page width estimation is approximate

The filter may not know the exact body width after margins, layout columns, and
Quarto page classes.

Revision:

- Avoid algorithms that require exact physical width.
- Use Typst `fr` tracks to allocate residual space.
- Use page-width estimates only for risk scoring.
- Add support for explicit table width classes later.

## 14. Revised v2 implementation sequence

Do not begin by porting old code. Implement in this order:

1. Minimal clean extension skeleton.
2. Metadata/config parser.
3. Pandoc table model extractor.
4. Plain-text analyzer and type inference.
5. Header wrapping.
6. Layout planner that returns a plan only.
7. Content-conversion matrix and escaping tests.
8. Typst writer for simple tables.
9. Caption/cross-reference preservation tests.
10. Fallback logic.
11. Examples and README.
12. Broader table support.

If any step reveals that a prior architectural decision is wrong, stop and revise
this document before continuing.

## 15. Sources consulted

- Quarto filter extensions documentation:
  <https://quarto.org/docs/extensions/filters.html>
- Quarto custom format extensions documentation:
  <https://quarto.org/docs/extensions/formats.html>
- Quarto Typst output documentation:
  <https://quarto.org/docs/output-formats/typst.html>
- Quarto Lua API documentation:
  <https://quarto.org/docs/extensions/lua-api.html>
- Pandoc Lua filters documentation:
  <https://pandoc.org/lua-filters.html>
- Pandoc table syntax documentation:
  <https://pandoc.org/MANUAL.html#tables>
- Typst table reference:
  <https://typst.app/docs/reference/model/table/>
- Typst `tablex` package documentation:
  <https://typst.app/universe/package/tablex/>

## 16. HTML and revealjs backend addendum

The extension can support HTML and revealjs without changing the Typst-first
layout rationale. The shared Lua pipeline remains:

```text
Pandoc Table
  ↓
neutral table model
  ↓
type inference and header wrapping
  ↓
layout plan
```

The backend decision differs by output format:

- Typst replaces eligible tables with raw native Typst because Pandoc's Typst
  writer cannot express the desired table tracks and styling precisely enough.
- HTML and revealjs should preserve Pandoc/Quarto's native table output wherever
  possible. Browser table layout is already strong, and preserving the `Table`
  node protects captions, identifiers, cross-references, accessibility
  attributes, and revealjs integration.

The HTML backend therefore mutates eligible `Table` nodes conservatively:

- add table and wrapper classes;
- add CSS profiles for `academic`, `compact`, `exam`, and `plain`;
- apply inferred column alignment through Pandoc colspecs and inline spans;
- apply balanced header wrapping with `LineBreak` in header cells;
- use a responsive wrapper for `natural` and `full` width strategies;
- leave unsupported or disabled tables unchanged.

Options should keep the same names across targets, but their exact rendering
contract is format-specific. In particular, Typst `fr` tracks do not map
directly to HTML table columns, and `repeat-header` is meaningful for Typst page
breaks but only helps print-oriented HTML where the browser supports repeated
table headers.
