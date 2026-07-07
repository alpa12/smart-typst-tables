# Smart Typst tables for Quarto documents.
#
# This file is intentionally dependency-light so it can be sourced directly
# from course-material projects without installing an R package.

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
}

smart_table <- function(data,
                        caption = NULL,
                        profile = "academic",
                        auto_widths = TRUE,
                        width = "100%",
                        col_widths = NULL,
                        align_dates = c("center", "left"),
                        header_breaks = NULL,
                        notes = NULL,
                        striped = FALSE,
                        row_rules = TRUE,
                        font_size = NULL,
                        max_header_lines = 3,
                        fallback = c("auto", "markdown", "html", "none"),
                        ...) {
  fallback <- match.arg(fallback)
  align_dates <- match.arg(align_dates)
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)

  if (!is_typst_output()) {
    warning(
      "smart_table() is optimized for Quarto Typst output. ",
      "Using a Markdown fallback for this non-Typst render.",
      call. = FALSE
    )
    out <- as_markdown_table(data, caption = caption)
    return(asis_output(out))
  }

  types <- infer_column_types(data)
  align <- infer_alignment(data, types, date_align = align_dates)
  headers <- wrap_headers(names(data), max_lines = max_header_lines, breaks = header_breaks)
  widths <- if (isTRUE(auto_widths)) {
    compute_widths(data, types, headers, profile = profile)
  } else {
    normalize_col_widths(col_widths, ncol(data))
  }

  table_style <- table_profile(profile)
  if (!is.null(font_size)) {
    table_style$font_size <- font_size
  }

  spec <- list(
    caption = caption,
    profile = profile,
    width = width,
    types = types,
    align = align,
    widths = widths,
    headers = headers,
    notes = notes,
    striped = striped,
    row_rules = row_rules,
    style = table_style
  )

  code <- as_typst_table(data, spec)
  asis_output(paste0("```{=typst}\n", code, "\n```\n"))
}

infer_column_types <- function(data) {
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  stats::setNames(vapply(data, infer_one_column_type, character(1)), names(data))
}

infer_one_column_type <- function(x) {
  if (inherits(x, c("Date", "POSIXct", "POSIXlt"))) {
    return("date")
  }

  values <- trimws(as.character(x))
  values <- values[!is.na(values) & nzchar(values) & values != "-"]
  if (length(values) == 0) {
    return("text")
  }

  if (mean(grepl("^\\d{4}-\\d{2}-\\d{2}$", values)) >= 0.85) {
    return("date")
  }
  if (is.numeric(x) || is.integer(x)) {
    return("numeric")
  }
  if (mean(grepl("^-?\\s?[$€£]|[$€£]\\s?$|^-?[0-9][0-9 ,.\\u00a0]*\\s?[$€£]$", values)) >= 0.6) {
    return("currency")
  }
  if (mean(grepl("^-?[0-9]+([,.][0-9]+)?\\s?%$", values)) >= 0.6) {
    return("percentage")
  }

  normalized <- gsub("[\\s\\u00a0,$€£%]", "", values)
  normalized <- gsub(",", ".", normalized, fixed = TRUE)
  suppressWarnings(numeric_like <- !is.na(as.numeric(normalized)))
  if (mean(numeric_like) >= 0.85) {
    return("numeric")
  }

  unique_ratio <- length(unique(values)) / length(values)
  max_chars <- max(nchar(values, type = "chars"))
  median_chars <- stats::median(nchar(values, type = "chars"))
  if (max_chars <= 18 && unique_ratio <= 0.75) {
    return("categorical")
  }
  if (median_chars >= 24 || max_chars >= 28) {
    return("long_text")
  }
  "text"
}

infer_alignment <- function(data, types, date_align = c("center", "left")) {
  date_align <- match.arg(date_align)
  align <- ifelse(types %in% c("numeric", "currency", "percentage"), "right", "left")
  align[types == "date"] <- date_align
  align[types == "categorical"] <- "left"
  stats::setNames(align, names(types))
}

compute_widths <- function(data, types, headers, page_width = NULL, profile = "academic") {
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  n <- ncol(data)
  if (n == 0) {
    return(character())
  }

  header_text <- vapply(headers, function(x) paste(x, collapse = " "), character(1))
  header_line_max <- vapply(headers, function(x) max(nchar(x, type = "chars")), numeric(1))
  max_cell <- vapply(data, function(x) {
    vals <- as.character(x)
    vals[is.na(vals)] <- ""
    max(nchar(vals, type = "chars"), na.rm = TRUE)
  }, numeric(1))
  med_cell <- vapply(data, function(x) {
    vals <- as.character(x)
    vals[is.na(vals)] <- ""
    stats::median(nchar(vals, type = "chars"), na.rm = TRUE)
  }, numeric(1))
  header_len <- nchar(header_text, type = "chars")

  fixed <- rep(NA_character_, n)
  weight <- rep(NA_real_, n)
  style <- table_profile(profile)

  for (i in seq_len(n)) {
    type <- unname(types[i])
    need <- max(header_line_max[i] * 0.62, med_cell[i] * 0.55, min(max_cell[i], 40) * 0.22)

    if (type == "date") {
      fixed[i] <- sprintf("%.1fem", style$date_width)
    } else if (type == "currency") {
      fixed[i] <- sprintf("%.1fem", clamp(max(4.6, need + 0.4), 4.6, style$numeric_width_max))
    } else if (type == "percentage") {
      fixed[i] <- sprintf("%.1fem", clamp(max(3.8, need + 0.2), 3.8, 5.0))
    } else if (type == "numeric") {
      fixed[i] <- sprintf("%.1fem", clamp(max(4.0, need + 0.3), 4.0, style$numeric_width_max))
    } else if (type == "categorical" && max(header_len[i], max_cell[i]) <= 12) {
      fixed[i] <- "auto"
    } else if (type == "long_text") {
      weight[i] <- clamp(need / 5.5, 1.8, 5.0)
    } else {
      if (n >= 7 && max(header_len[i], max_cell[i]) <= 16) {
        fixed[i] <- "auto"
      } else {
        weight[i] <- clamp(need / 6.5, 0.9, 2.4)
      }
    }
  }

  if (all(!is.na(fixed))) {
    longest <- which.max(header_len + max_cell)
    fixed[longest] <- "1fr"
  }

  fr <- !is.na(weight)
  if (any(fr)) {
    weight <- weight / min(weight[fr], na.rm = TRUE)
    fixed[fr] <- paste0(format_fr(weight[fr]), "fr")
  }

  stats::setNames(fixed, names(data))
}

wrap_headers <- function(headers, max_lines = 3, breaks = NULL) {
  lapply(headers, function(header) {
    header <- as.character(header)
    if (!is.null(breaks) && !is.null(breaks[[header]])) {
      return(as.character(breaks[[header]]))
    }

    words <- split_header_words(header)
    if (length(words) <= 1 || nchar(header, type = "chars") <= 10) {
      return(header)
    }

    line_count <- min(max_lines, max(2, ceiling(nchar(header, type = "chars") / 16)))
    line_count <- min(line_count, length(words))
    split_balanced_words(words, line_count)
  })
}

escape_typst <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  vapply(x, function(value) {
    chars <- strsplit(value, "", fixed = TRUE)[[1]]
    paste(vapply(chars, function(ch) {
      if (ch %in% c("\\", "#", "$", "[", "]")) paste0("\\", ch) else ch
    }, character(1)), collapse = "")
  }, character(1), USE.NAMES = FALSE)
}

as_typst_table <- function(data, spec) {
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  n <- ncol(data)
  widths <- spec$widths %||% rep("auto", n)
  align <- spec$align %||% rep("left", n)
  headers <- spec$headers %||% wrap_headers(names(data))
  width <- spec$width %||% "100%"
  striped <- isTRUE(spec$striped)
  row_rules <- isTRUE(spec$row_rules)
  style <- spec$style %||% table_profile(spec$profile %||% "academic")

  header_cells <- vapply(seq_len(n), function(i) {
    content <- paste(escape_typst(headers[[i]]), collapse = "#linebreak()")
    sprintf(
      "    table.cell(align: %s, fill: %s)[#strong[%s]]",
      typst_align(align[i]),
      style$header_fill,
      content
    )
  }, character(1))

  body_cells <- character()
  if (nrow(data) > 0 && n > 0) {
    for (row in seq_len(nrow(data))) {
      for (col in seq_len(n)) {
        fill <- if (striped && row %% 2 == 0) paste0(", fill: ", style$stripe_fill) else ""
        value <- format_cell(data[[col]][row], spec$types[[col]])
        body_cells <- c(
          body_cells,
          sprintf(
            "    table.cell(align: %s%s)[%s]",
            typst_align(align[col]),
            fill,
            escape_typst(value)
          )
        )
      }
      if (row_rules && row < nrow(data)) {
        body_cells <- c(body_cells, sprintf("    table.hline(stroke: %s)", style$row_rule_stroke))
      }
    }
  }

  table_args <- c(
    sprintf("  columns: (%s%s),", paste(unname(widths), collapse = ", "), if (n == 1) "," else ""),
    sprintf("  column-gutter: %s,", style$column_gutter),
    "  stroke: none,",
    sprintf("  inset: (x: %s, y: %s),", style$inset_x, style$inset_y),
    "  table.header(",
    "    repeat: true,",
    paste(header_cells, collapse = ",\n"),
    "  ),",
    sprintf("  table.hline(stroke: %s),", style$header_rule_stroke),
    if (length(body_cells)) paste(body_cells, collapse = ",\n") else NULL
  )
  table_code <- paste0("table(\n", paste(table_args, collapse = "\n"), "\n)")
  block_content <- paste(
    sprintf("#set text(size: %s, hyphenate: false)", style$font_size),
    sprintf("#set par(leading: %s)", style$leading),
    paste0("#", table_code),
    sep = "\n"
  )
  notes <- spec$notes
  if (!is.null(notes) && length(notes) > 0) {
    note_code <- paste(escape_typst(notes), collapse = " ")
    block_content <- paste0(block_content, "\n#smart-table-note[", note_code, "]")
  }

  block_expr <- sprintf(
    "block(width: %s)[\n%s\n]",
    typst_width(width),
    indent_typst(block_content, spaces = 2)
  )

  if (!is.null(spec$caption)) {
    return(sprintf(
      "#figure(\n%s,\n  kind: table,\n  caption: [%s]\n)",
      indent_typst(block_expr, spaces = 2),
      escape_typst(spec$caption)
    ))
  }
  paste0("#", block_expr)
}

is_typst_output <- function() {
  option <- getOption("smart.typst.tables.output", NULL)
  if (!is.null(option)) {
    return(identical(tolower(option), "typst"))
  }

  env <- tolower(c(
    Sys.getenv("QUARTO_FORMAT", ""),
    Sys.getenv("QUARTO_PROJECT_OUTPUT_FORMAT", ""),
    Sys.getenv("PANDOC_TARGET_FORMAT", "")
  ))
  if (any(grepl("^typst", env))) {
    return(TRUE)
  }

  if (requireNamespace("knitr", quietly = TRUE) && isTRUE(knitr::is_html_output())) {
    return(FALSE)
  }

  TRUE
}

asis_output <- function(x) {
  if (requireNamespace("knitr", quietly = TRUE)) {
    return(knitr::asis_output(x))
  }
  structure(x, class = "knit_asis")
}

as_markdown_table <- function(data, caption = NULL) {
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  if (requireNamespace("knitr", quietly = TRUE)) {
    return(knitr::kable(data, caption = caption, format = "pipe"))
  }
  header <- paste(names(data), collapse = " | ")
  rule <- paste(rep("---", ncol(data)), collapse = " | ")
  rows <- apply(data, 1, function(x) paste(as.character(x), collapse = " | "))
  paste(c(
    if (!is.null(caption)) paste0("Table: ", caption, "\n") else NULL,
    paste0("| ", header, " |"),
    paste0("| ", rule, " |"),
    paste0("| ", rows, " |")
  ), collapse = "\n")
}

normalize_col_widths <- function(col_widths, n) {
  if (is.null(col_widths)) {
    return(rep("auto", n))
  }
  if (length(col_widths) != n) {
    stop("`col_widths` must have one value per column.", call. = FALSE)
  }
  as.character(col_widths)
}

format_cell <- function(x, type = "text") {
  if (length(x) == 0 || is.na(x)) {
    return("")
  }
  if (inherits(x, "Date")) {
    return(format(x, "%Y-%m-%d"))
  }
  as.character(x)
}

typst_align <- function(x) {
  switch(
    as.character(x),
    left = "left",
    center = "center",
    right = "right",
    "left"
  )
}

typst_width <- function(width) {
  width <- as.character(width)
  if (grepl("%$", width)) {
    return(width)
  }
  width
}

indent_typst <- function(x, spaces = 2) {
  pad <- paste(rep(" ", spaces), collapse = "")
  paste(paste0(pad, strsplit(x, "\n", fixed = TRUE)[[1]]), collapse = "\n")
}

split_header_words <- function(header) {
  words <- unlist(strsplit(header, "\\s+"))
  words[nzchar(words)]
}

split_balanced_words <- function(words, line_count) {
  n <- length(words)
  line_count <- min(line_count, n)
  if (line_count <= 1) {
    return(paste(words, collapse = " "))
  }

  breaks <- utils::combn(seq_len(n - 1), line_count - 1, simplify = FALSE)
  candidates <- lapply(breaks, function(split_after) {
    starts <- c(1, split_after + 1)
    ends <- c(split_after, n)
    vapply(seq_along(starts), function(i) {
      paste(words[starts[i]:ends[i]], collapse = " ")
    }, character(1))
  })

  score <- vapply(candidates, function(lines) {
    len <- nchar(lines, type = "chars")
    single_short_word_penalty <- sum(lengths(strsplit(lines, "\\s+")) == 1 & len <= 5) * 10
    max(len) + stats::sd(len) + single_short_word_penalty
  }, numeric(1))

  candidates[[which.min(score)]]
}

clamp <- function(x, min, max) {
  pmax(min, pmin(max, x))
}

format_fr <- function(x) {
  out <- sprintf("%.2f", x)
  out <- sub("\\.?0+$", "", out)
  out
}

table_profile <- function(profile = "academic") {
  profile <- tolower(as.character(profile %||% "academic"))
  switch(
    profile,
    compact = list(
      font_size = "8pt",
      leading = "0.52em",
      inset_x = "2.4pt",
      inset_y = "1.7pt",
      column_gutter = "1.2pt",
      header_fill = "luma(94%)",
      stripe_fill = "luma(98%)",
      header_rule_stroke = "0.65pt + black",
      row_rule_stroke = "0.22pt + luma(84%)",
      date_width = 6.0,
      numeric_width_max = 5.4
    ),
    spacious = list(
      font_size = "9.4pt",
      leading = "0.62em",
      inset_x = "4.2pt",
      inset_y = "3.2pt",
      column_gutter = "1.8pt",
      header_fill = "luma(95%)",
      stripe_fill = "luma(98%)",
      header_rule_stroke = "0.75pt + black",
      row_rule_stroke = "0.25pt + luma(84%)",
      date_width = 6.8,
      numeric_width_max = 6.2
    ),
    teaching = list(
      font_size = "9pt",
      leading = "0.58em",
      inset_x = "3.8pt",
      inset_y = "2.9pt",
      column_gutter = "1.6pt",
      header_fill = "rgb(\"eef3fb\")",
      stripe_fill = "rgb(\"f8fbff\")",
      header_rule_stroke = "0.75pt + rgb(\"315a89\")",
      row_rule_stroke = "0.25pt + rgb(\"d7e2ef\")",
      date_width = 6.5,
      numeric_width_max = 5.9
    ),
    list(
      font_size = "8.7pt",
      leading = "0.56em",
      inset_x = "3.1pt",
      inset_y = "2.3pt",
      column_gutter = "1.4pt",
      header_fill = "luma(95%)",
      stripe_fill = "luma(98%)",
      header_rule_stroke = "0.7pt + black",
      row_rule_stroke = "0.23pt + luma(86%)",
      date_width = 6.3,
      numeric_width_max = 5.7
    )
  )
}
