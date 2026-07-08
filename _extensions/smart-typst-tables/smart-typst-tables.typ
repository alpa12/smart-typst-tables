// Runtime helpers for smart-typst-tables v2.

#let smart-table-profile(name) = {
  if name == "compact" {
    (
      font-size: 8pt,
      leading: 0.54em,
      inset-x: 2.4pt,
      inset-y: 1.8pt,
      header-fill: luma(94%),
      stripe-fill: luma(98%),
      header-stroke: 0.65pt + black,
      row-stroke: 0.22pt + luma(84%),
      gutter: 1.1pt,
    )
  } else if name == "exam" {
    (
      font-size: 9pt,
      leading: 0.6em,
      inset-x: 3.6pt,
      inset-y: 2.7pt,
      header-fill: luma(96%),
      stripe-fill: luma(99%),
      header-stroke: 0.75pt + black,
      row-stroke: 0.24pt + luma(86%),
      gutter: 1.5pt,
    )
  } else if name == "plain" {
    (
      font-size: 8.7pt,
      leading: 0.56em,
      inset-x: 3pt,
      inset-y: 2.2pt,
      header-fill: none,
      stripe-fill: none,
      header-stroke: 0.7pt + black,
      row-stroke: none,
      gutter: 1.3pt,
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

#let smart-table-scope(profile: "academic", body) = {
  let p = smart-table-profile(profile)
  set text(size: p.font-size, hyphenate: false)
  set par(leading: p.leading)
  body
}
