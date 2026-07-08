local metrics = require("text_metrics")

local M = {}

local function cell_text(cell)
  return metrics.stringify_blocks(cell.contents)
end

local function rows_from_section(section)
  local rows = {}
  if section == nil or section.rows == nil then
    return rows
  end
  for _, row in ipairs(section.rows) do
    local cells = {}
    for _, cell in ipairs(row.cells) do
      table.insert(cells, {
        text = cell_text(cell),
        contents = cell.contents,
        align = tostring(cell.alignment or ""),
        col_span = cell.col_span or 1,
        row_span = cell.row_span or 1,
        attr = cell.attr,
      })
    end
    table.insert(rows, { cells = cells })
  end
  return rows
end

local function body_rows(tbl)
  local rows = {}
  for _, body in ipairs(tbl.bodies or {}) do
    for _, row in ipairs(body.body or {}) do
      local cells = {}
      for _, cell in ipairs(row.cells) do
        table.insert(cells, {
          text = cell_text(cell),
          contents = cell.contents,
          align = tostring(cell.alignment or ""),
          col_span = cell.col_span or 1,
          row_span = cell.row_span or 1,
          attr = cell.attr,
        })
      end
      table.insert(rows, { cells = cells })
    end
  end
  return rows
end

local function has_unsupported_blocks(cell)
  if cell.contents == nil then
    return false
  end
  if #cell.contents > 1 then
    return true
  end
  for _, block in ipairs(cell.contents) do
    if block.t ~= "Plain" and block.t ~= "Para" then
      return true
    end
    for _, inline in ipairs(block.content or {}) do
      if inline.t ~= "Str" and inline.t ~= "Space" and inline.t ~= "SoftBreak" and inline.t ~= "LineBreak" then
        return true
      end
    end
  end
  return false
end

function M.from_pandoc_table(tbl)
  local colspecs = {}
  for _, spec in ipairs(tbl.colspecs or {}) do
    local width = spec[2] or 0
    table.insert(colspecs, {
      align = tostring(spec[1]),
      width = width,
    })
  end

  local model = {
    attr = tbl.attr,
    caption = tbl.caption,
    colspecs = colspecs,
    header_rows = rows_from_section(tbl.head),
    body_rows = body_rows(tbl),
    footer_rows = rows_from_section(tbl.foot),
    n_cols = #colspecs,
    features = {
      has_spans = false,
      has_complex_content = false,
      has_explicit_widths = false,
    },
  }

  if tbl.attr and tbl.attr.attributes and tbl.attr.attributes["tbl-colwidths"] then
    model.features.has_explicit_widths = true
  end

  for _, section in ipairs({ model.header_rows, model.body_rows, model.footer_rows }) do
    for _, row in ipairs(section) do
      for _, cell in ipairs(row.cells) do
        if cell.col_span ~= 1 or cell.row_span ~= 1 then
          model.features.has_spans = true
        end
        if has_unsupported_blocks(cell) then
          model.features.has_complex_content = true
        end
      end
    end
  end

  return model
end

function M.header_texts(model)
  local headers = {}
  if #model.header_rows > 0 then
    for _, cell in ipairs(model.header_rows[1].cells) do
      table.insert(headers, cell.text)
    end
  else
    for i = 1, model.n_cols do
      table.insert(headers, "")
    end
  end
  return headers
end

function M.column_values(model, col)
  local values = {}
  for _, row in ipairs(model.body_rows) do
    if row.cells[col] then
      table.insert(values, row.cells[col].text)
    end
  end
  return values
end

function M.is_eligible(model, options)
  if model.n_cols == 0 then
    return false, "no columns"
  end
  if model.n_cols > 14 then
    return false, "too many columns"
  end
  if model.features.has_spans then
    return false, "spans are not supported yet"
  end
  if model.features.has_complex_content then
    return false, "complex cell content is not supported yet"
  end
  if model.features.has_explicit_widths and options.explicit_widths ~= "optimize" then
    return false, "explicit source widths respected"
  end
  return true
end

return M
