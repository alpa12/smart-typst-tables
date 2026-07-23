# HTML and Revealjs styling

Apply this reference only for HTML or Revealjs output. Typst output is native
Typst and does not read CSS.

Register a stylesheet after the extension:

```yaml
format:
  html:
    css: styles.scss
  revealjs:
    css: styles.scss
```

Add a class to a table Div, then scope the override to its transformed wrapper:

```markdown
::: {#tbl-kpis .table-brand}
| Indicator | Rate | Note |
|---|---:|---|
| Retention | 91.0% | Above target. |

KPI summary.
:::
```

```scss
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

.table-brand .smart-table thead th { color: #fff; }
.table-brand .smart-table td { font-family: "Aptos", sans-serif; }
.table-brand .smart-table-type-percentage {
  color: #075f46;
  font-variant-numeric: tabular-nums;
}
```

## Hooks

- `.smart-table-scroll`: outer responsive and horizontal-scroll container.
- `.smart-table-wrap`: intrinsic-width wrapper and the host for all variables.
- `.smart-table`: native table element.
- `.smart-table thead th`, `.smart-table td`: header and body cells.
- `.smart-table-profile-*`: target `academic`, `compact`, `exam`, `plain`, or
  `reveal` only.
- `.smart-table-type-*`: target inferred types such as `numeric`, `currency`,
  `percentage`, `date`, `duration`, and `free_text`.
- `.smart-table-header-lines`: preserves the line breaks selected by the
  extension. Do not override its `white-space: nowrap`.

For presentation geometry, prefer configuration over structural CSS:

```yaml
smart-tables:
  revealjs:
    max-width: 100%
    max-height: 60vh
    overflow: auto
    font-size: 0.84em
```

Use `.reveal .table-brand ...` for reveal-specific color or typography rules.
Do not globally set `.smart-table { width: 100% }`, change
`.smart-table-wrap` to `display: block`, or remove `.smart-table-scroll`.
Those overrides defeat content-sized tables and safe overflow.
