// Runtime helpers for smart-typst-tables v2.

#let smart-table-profile(name) = {
  if name == "compact" {
    (
      font-size: 7.4pt,
      leading: 0.46em,
      inset-x: 1.8pt,
      inset-y: 1.1pt,
      header-fill: luma(91%),
      stripe-fill: luma(98%),
      header-stroke: 0.55pt + black,
      row-stroke: 0.16pt + luma(88%),
      gutter: 0.6pt,
    )
  } else if name == "exam" {
    (
      font-size: 10pt,
      leading: 0.72em,
      inset-x: 5pt,
      inset-y: 4pt,
      header-fill: luma(90%),
      stripe-fill: luma(96%),
      header-stroke: 0.95pt + black,
      row-stroke: 0.32pt + luma(78%),
      gutter: 2.2pt,
    )
  } else if name == "plain" {
    (
      font-size: 8.9pt,
      leading: 0.62em,
      inset-x: 2.4pt,
      inset-y: 1.9pt,
      header-fill: none,
      stripe-fill: none,
      header-stroke: 0.45pt + luma(35%),
      row-stroke: none,
      gutter: 1.8pt,
    )
  } else {
    (
      font-size: 8.7pt,
      leading: 0.56em,
      inset-x: 3.1pt,
      inset-y: 2.3pt,
      header-fill: luma(95%),
      stripe-fill: luma(98%),
      header-stroke: 0.7pt + black,
      row-stroke: 0.23pt + luma(86%),
      gutter: 1.4pt,
    )
  }
}

#let smart-table-note(body) = {
  v(3pt)
  set text(size: 8.2pt, fill: luma(40%))
  body
}

#let smart-table-scope(profile: "academic", text-size: none, body) = {
  let p = smart-table-profile(profile)
  set text(size: if text-size == none { p.font-size } else { text-size }, hyphenate: false)
  set par(leading: p.leading, justify: false)
  body
}
