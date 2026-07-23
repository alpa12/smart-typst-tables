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
      has_pandoc_widths = false,
    },
  }

  if tbl.attr and tbl.attr.attributes then
    if tbl.attr.attributes["tbl-colwidths"] or tbl.attr.attributes.widths then
      model.features.has_explicit_widths = true
    end
  end
  for _, spec in ipairs(model.colspecs) do
    if tonumber(spec.width) and tonumber(spec.width) ~= 0 then
      model.features.has_pandoc_widths = true
    end
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
  for i = 1, model.n_cols do
    headers[i] = ""
  end
  if #model.header_rows > 0 then
    for _, logical in ipairs(M.logical_rows({ model.header_rows[1] })[1] or {}) do
      headers[logical.column] = logical.cell.text
    end
  end
  return headers
end

-- Pandoc stores physical cells only. Resolve their logical column positions so
-- HTML styling remains correct when rows contain rowspan or colspan cells.
function M.logical_rows(rows)
  local out, occupied = {}, {}
  for _, row in ipairs(rows or {}) do
    local cells, column = {}, 1
    for _, cell in ipairs(row.cells or {}) do
      while occupied[column] and occupied[column] > 0 do
        column = column + 1
      end
      table.insert(cells, { cell = cell, column = column })
      local col_span, row_span = cell.col_span or 1, cell.row_span or 1
      if row_span > 1 then
        for offset = 0, col_span - 1 do
          occupied[column + offset] = math.max(occupied[column + offset] or 0, row_span)
        end
      end
      column = column + col_span
    end
    table.insert(out, cells)
    for key, remaining in pairs(occupied) do
      occupied[key] = remaining - 1
      if occupied[key] <= 0 then
        occupied[key] = nil
      end
    end
  end
  return out
end

function M.column_values(model, col)
  local values = {}
  for _, row in ipairs(M.logical_rows(model.body_rows)) do
    for _, logical in ipairs(row) do
      if logical.column == col then
        table.insert(values, logical.cell.text)
      end
    end
  end
  return values
end

function M.is_eligible(model, options, target)
  if model.n_cols == 0 then
    return false, "no columns"
  end
  if target == "html" then
    -- Browser table layout supports rich blocks, spans, explicit widths, and
    -- wide tables, so Typst's safety restrictions do not apply here.
    return true
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
  if (model.features.has_explicit_widths or model.features.has_pandoc_widths)
    and options.explicit_widths ~= "optimize" then
    return false, "explicit source widths respected"
  end
  return true
end

return M
