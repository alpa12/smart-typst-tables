source_path <- c("R/smart_table.R", "../../R/smart_table.R")
source(source_path[file.exists(source_path)][1])

sample_transactions <- function() {
  data_path <- c("examples/data/transactions.csv", "../../examples/data/transactions.csv")
  read.csv(data_path[file.exists(data_path)][1], check.names = FALSE)
}

test_that("column types are inferred for transaction data", {
  data <- sample_transactions()
  types <- infer_column_types(data)

  expect_equal(types[["Police"]], "categorical")
  expect_equal(types[["Date d'effet de police"]], "date")
  expect_equal(types[["Date de transaction"]], "date")
  expect_equal(types[["Prime annuelle"]], "currency")
  expect_equal(types[["Prime du terme"]], "currency")
  expect_equal(types[["Type de transaction"]], "long_text")
})

test_that("alignment follows inferred types", {
  data <- sample_transactions()
  types <- infer_column_types(data)
  align <- infer_alignment(data, types)

  expect_equal(align[["Police"]], "left")
  expect_equal(align[["Date de transaction"]], "center")
  expect_equal(align[["Prime annuelle"]], "right")
})

test_that("width computation is stable and mixes track types", {
  data <- sample_transactions()
  types <- infer_column_types(data)
  headers <- wrap_headers(names(data))
  widths <- compute_widths(data, types, headers)

  expect_length(widths, ncol(data))
  expect_equal(widths[["Police"]], "auto")
  expect_match(widths[["Date d'effet de police"]], "em$")
  expect_match(widths[["Prime annuelle"]], "em$")
  expect_match(widths[["Type de transaction"]], "fr$")
  expect_equal(unname(widths), c("auto", "6.3em", "6.3em", "auto", "5.4em", "5.4em", "1fr"))
})

test_that("headers wrap without breaking words", {
  wrapped <- wrap_headers(c("Date d'effet de police", "Modification en cours de terme"))

  expect_lte(length(wrapped[[1]]), 3)
  expect_true(any(wrapped[[1]] == "Date d'effet"))
  expect_false(any(grepl("d'effe$", wrapped[[1]])))
  expect_true(all(!grepl("  ", unlist(wrapped))))
})
