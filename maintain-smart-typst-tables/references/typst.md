# Typst maintenance

Typst eligibility is intentionally strict. It rejects spans, complex content,
unsafe source widths, wide tables, and unsupported structures rather than
producing a lossy native conversion. Change these conditions only with a
matching writer capability and a regression fixture.

`layout_engine.lua` calculates the shared plan and `typst_writer.lua` renders
it into native `table()` syntax. Type inference and header wrapping are shared
with HTML, but Typst track choices (`auto`, fixed `em`, and `fr`) remain
Typst-specific. Do not make them browser CSS rules.

When changing header behavior, test both automatic and forced
`header-lines`. Forced counts split only between words; a one-word header must
remain one line. Keep `max-header-lines` as the automatic upper bound.

When changing layout, preserve explicitly declared alignments and source width
policy. If fixed tracks exceed the safe page width, retain the fallback instead
of silently compressing content.
