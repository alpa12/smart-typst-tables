source_path <- c("R/smart_table.R", "../../R/smart_table.R")
source(source_path[file.exists(source_path)][1])

sample_transactions <- function() {
  data_path <- c("examples/data/transactions.csv", "../../examples/data/transactions.csv")
  read.csv(data_path[file.exists(data_path)][1], check.names = FALSE)
}

test_that("Typst escaping protects special characters", {
  expect_equal(escape_typst("A #1 [draft] $100"), "A \\#1 \\[draft\\] \\$100")
  expect_equal(escape_typst("Date d'effet"), "Date d'effet")
})

test_that("Typst output has valid table structure", {
  data <- sample_transactions()
  types <- infer_column_types(data)
  spec <- list(
    caption = "Données",
    width = "100%",
    types = types,
    align = infer_alignment(data, types),
    widths = compute_widths(data, types, wrap_headers(names(data))),
    headers = wrap_headers(names(data)),
    striped = TRUE,
    notes = "Source: données simulées."
  )

  code <- as_typst_table(data, spec)

  expect_true(grepl("#figure(", code, fixed = TRUE))
  expect_true(grepl("block(width: 100%)", code, fixed = TRUE))
  expect_true(grepl("#table(", code, fixed = TRUE))
  expect_true(grepl("table.header(", code, fixed = TRUE))
  expect_true(grepl("#set text(size: 8.7pt, hyphenate: false)", code, fixed = TRUE))
  expect_true(grepl("repeat: true", code, fixed = TRUE))
  expect_true(grepl("table.hline(", code, fixed = TRUE))
  expect_true(grepl("caption: [Données]", code, fixed = TRUE))
  expect_true(grepl("Modification en cours de terme", code, fixed = TRUE))
  expect_true(grepl("smart-table-note", code, fixed = TRUE))
})

test_that("sample transaction table avoids broken header words", {
  data <- sample_transactions()
  types <- infer_column_types(data)
  headers <- wrap_headers(names(data))
  code <- as_typst_table(data, list(
    caption = "Données",
    width = "100%",
    types = types,
    align = infer_alignment(data, types),
    widths = compute_widths(data, types, headers),
    headers = headers
  ))

  expect_true(grepl("Date d'effet#linebreak()de police", code, fixed = TRUE))
  expect_false(grepl("d'effe#linebreak\\(\\)t", code))
  expect_true(grepl("Prime#linebreak()annuelle", code, fixed = TRUE))
  expect_true(grepl("Prime#linebreak()du terme", code, fixed = TRUE))
})
