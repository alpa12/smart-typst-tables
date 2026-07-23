local table_ast = require("table_ast")
local header_wrap = require("header_wrap")
local metrics = require("text_metrics")

local M = {}

local function add_class(attr, class)
  attr = attr or pandoc.Attr()
  attr.classes = attr.classes or {}
  for _, existing in ipairs(attr.classes) do
    if existing == class then
      return attr
    end
  end
  table.insert(attr.classes, class)
  return attr
end

local function set_attribute(attr, key, value)
  attr = attr or pandoc.Attr()
  attr.attributes = attr.attributes or {}
  if value ~= nil and value ~= "" then
    attr.attributes[key] = value
  end
  return attr
end

local function css_ident(value, default)
  value = tostring(value or default or "")
  value = value:gsub("[^%w%-_]", "-")
  if value == "" then
    return default or "default"
  end
  return value
end

local function css_size(value)
  if value == nil or value == "" or value == "auto" then
    return nil
  end
  return tostring(value)
end

local function append_style(attr, declaration)
  if declaration == nil or declaration == "" then
    return attr
  end
  attr = attr or pandoc.Attr()
  attr.attributes = attr.attributes or {}
  local current = attr.attributes.style or ""
  if current ~= "" and not current:match(";%s*$") then
    current = current .. ";"
  end
  attr.attributes.style = current .. declaration
  return attr
end

local function pandoc_align(value)
  if value == "right" then
    return pandoc.AlignRight or "AlignRight"
  end
  if value == "center" then
    return pandoc.AlignCenter or "AlignCenter"
  end
  if value == "left" then
    return pandoc.AlignLeft or "AlignLeft"
  end
  return pandoc.AlignDefault or "AlignDefault"
end

local function text_inlines(text)
  local inlines = {}
  local first = true
  for word in tostring(text or ""):gmatch("%S+") do
    if not first then
      table.insert(inlines, pandoc.Space())
    end
    table.insert(inlines, pandoc.Str(word))
    first = false
  end
  return inlines
end

local function header_inlines(lines)
  local inlines = {}
  for index, line in ipairs(lines or {}) do
    for _, inline in ipairs(text_inlines(line)) do
      table.insert(inlines, inline)
    end
    if index < #lines then
      table.insert(inlines, pandoc.LineBreak())
    end
  end
  return inlines
end

local function cell_classes(plan, col, is_header)
  local classes = {
    "smart-table-cell",
    "smart-table-align-" .. css_ident((is_header and plan.header_align and plan.header_align[col]) or plan.col_align[col], "left"),
  }

  local inferred = plan.types and plan.types[col]
  local kind = inferred and inferred.type or "mixed"
  table.insert(classes, "smart-table-type-" .. css_ident(kind, "mixed"))
  -- Headers have already received deliberate line breaks from header_wrap.
  -- Do not turn those breaks into a minimum-width constraint: a narrow
  -- numeric column may still need its title to wrap in a small container.
  if not is_header and (kind == "numeric" or kind == "currency" or kind == "percentage" or kind == "date" or kind == "duration") then
    table.insert(classes, "smart-table-nowrap")
  end

  return classes
end

local function add_classes(attr, classes)
  for _, class in ipairs(classes or {}) do
    add_class(attr, class)
  end
  return attr
end

local function copy_classes(classes)
  local out = {}
  for _, class in ipairs(classes or {}) do
    table.insert(out, class)
  end
  return out
end

local function is_simple_text_blocks(blocks)
  if blocks == nil or #blocks ~= 1 then
    return false
  end
  local block = blocks[1]
  if block.t ~= "Plain" and block.t ~= "Para" then
    return false
  end
  for _, inline in ipairs(block.content or {}) do
    if inline.t ~= "Str" and inline.t ~= "Space" and inline.t ~= "SoftBreak" and inline.t ~= "LineBreak" then
      return false
    end
  end
  return true
end

local function style_cell(cell, classes, scope)
  cell.attr = add_classes(cell.attr or pandoc.Attr(), classes)
  if scope and not (cell.attr.attributes or {}).scope then
    cell.attr = set_attribute(cell.attr, "scope", scope)
  end
end

local function transform_header(tbl, model, plan, options)
  if tbl.head == nil or tbl.head.rows == nil then
    return
  end

  local rows = table_ast.logical_rows(model.header_rows)
  for row_index, row in ipairs(tbl.head.rows) do
    for cell_index, cell in ipairs(row.cells) do
      local logical = rows[row_index] and rows[row_index][cell_index]
      local col = logical and logical.column or cell_index
      local classes = cell_classes(plan, col, true)
      style_cell(cell, classes, (cell.col_span or 1) > 1 and "colgroup" or "col")
      if logical and (cell.col_span or 1) == 1 and is_simple_text_blocks(cell.contents) then
        -- Reuse the fitted, balanced lines selected by the shared layout
        -- engine (and therefore by Typst) for the primary header row.
        local lines = plan.header_lines[col]
        if row_index > 1 or not lines then
          lines = header_wrap.wrap(logical.cell.text, options.max_header_lines, options.header_lines)
        end
        -- The explicit LineBreaks are the chosen header-line budget.  Mark
        -- their inner span so CSS cannot make an additional, accidental wrap
        -- inside one of those lines (for example "On-time" -> "On-" / "time").
        local content_classes = copy_classes(classes)
        table.insert(content_classes, "smart-table-header-lines")
        cell.contents = { pandoc.Plain({ pandoc.Span(header_inlines(lines), pandoc.Attr("", content_classes, {})) }) }
      end
    end
  end
end

local function transform_body(tbl, model, plan)
  local model_offset = 0
  for _, body in ipairs(tbl.bodies or {}) do
    local model_rows = {}
    for row_index = 1, #(body.body or {}) do
      model_rows[row_index] = model.body_rows[model_offset + row_index]
    end
    local rows = table_ast.logical_rows(model_rows)
    for row_index, row in ipairs(body.body or {}) do
      for cell_index, cell in ipairs(row.cells) do
        local logical = rows[row_index] and rows[row_index][cell_index]
        local col = logical and logical.column or cell_index
        style_cell(cell, cell_classes(plan, col, false), nil)
      end
    end
    model_offset = model_offset + #(body.body or {})
  end
end

local function max_line_width(lines)
  local out = 0
  for _, line in ipairs(lines or {}) do
    out = math.max(out, metrics.visual_width(line))
  end
  return out
end

local function html_column_natural_width(model, plan, col)
  local kind = plan.types and plan.types[col] and plan.types[col].type or "mixed"
  local base = {
    numeric = 3.5, currency = 4.5, percentage = 4,
    date = 6.5, duration = 5.5, identifier = 6, categorical = 6.5,
    boolean = 4, code = 8, mixed = 9, free_text = 12,
  }
  local cap = {
    numeric = 8, currency = 9, percentage = 8.5,
    date = 8.5, duration = 7.5, identifier = 10, categorical = 10,
    boolean = 6, code = 14, mixed = 15, free_text = 22,
  }
  local header_need = max_line_width(plan.header_lines and plan.header_lines[col]) + 1.2
  local values = table_ast.column_values(model, col)
  local visual, unbreakable = {}, 0
  for _, value in ipairs(values) do
    table.insert(visual, metrics.visual_width(value))
    unbreakable = math.max(unbreakable, metrics.unbreakable_width(value))
  end
  local data_need = unbreakable + 1.2
  if kind == "free_text" or kind == "mixed" then
    data_need = math.max(data_need, metrics.median(visual) * 0.42 + 1.2)
  end
  local minimum = base[kind] or 9
  local maximum = cap[kind] or 16
  return math.min(maximum, math.max(minimum, header_need, data_need))
end

-- Intrinsic content width is only the starting point.  A date, a percentage
-- or a status is easy to scan in a compact column, whereas prose becomes
-- markedly less useful when it is squeezed beside them.  Bias the colspec
-- allocation accordingly; this changes proportions, not author-supplied
-- widths.  Keeping this policy here also gives HTML and RevealJS the same
-- behaviour.
local function html_column_weight(model, plan, col)
  local width = html_column_natural_width(model, plan, col)
  local kind = plan.types and plan.types[col] and plan.types[col].type or "mixed"
  local bias = {
    numeric = 0.62, currency = 0.68, percentage = 0.62,
    date = 0.76, duration = 0.72, boolean = 0.7,
    identifier = 0.78, categorical = 0.8, code = 0.88,
    mixed = 1.08, free_text = 1.35,
  }
  return width * (bias[kind] or 1)
end

local function html_natural_width(model, plan)
  local total = 0
  for col = 1, #(plan.columns or {}) do
    total = total + html_column_weight(model, plan, col)
  end
  total = math.max(12, math.min(56, total + 1.2))
  return string.format("%.1fem", total):gsub("%.0em", "em")
end

local function apply_colspecs(tbl, model, plan)
  local total = 0
  local weights = {}
  if not model.features.has_explicit_widths then
    for col = 1, #(tbl.colspecs or {}) do
      weights[col] = html_column_weight(model, plan, col)
      total = total + weights[col]
    end
  end
  for col, colspec in ipairs(tbl.colspecs or {}) do
    if plan.col_align and plan.col_align[col] then
      colspec[1] = pandoc_align(plan.col_align[col])
    end
    if total > 0 then
      colspec[2] = weights[col] / total
    end
  end
end

local function profile_attr(plan)
  local attr = pandoc.Attr("", {}, {})
  add_class(attr, "smart-table-wrap")
  add_class(attr, "smart-table-align-" .. css_ident(plan.align, "center"))
  add_class(attr, "smart-table-width-" .. css_ident(plan.table_width, "natural"))
  return attr
end

function M.render(tbl, model, plan, options, target)
  transform_header(tbl, model, plan, options)
  transform_body(tbl, model, plan)
  apply_colspecs(tbl, model, plan)

  tbl.attr = tbl.attr or pandoc.Attr()
  add_class(tbl.attr, "smart-table")
  add_class(tbl.attr, "smart-table-profile-" .. css_ident(plan.profile, "academic"))
  add_class(tbl.attr, "smart-table-width-" .. css_ident(plan.table_width, "natural"))
  add_class(tbl.attr, "smart-table-align-" .. css_ident(plan.align, "center"))
  local natural_width = nil
  if not model.features.has_explicit_widths then
    add_class(tbl.attr, "smart-table-layout-planned")
    if plan.table_width == "natural" then
      natural_width = html_natural_width(model, plan)
      append_style(tbl.attr, "--smart-table-natural-width:" .. natural_width .. ";")
      -- Quarto themes can load after this extension and force table width to
      -- 100%. An inline important declaration preserves the planned intrinsic
      -- width while the wrapper remains responsible for overflow.
      append_style(tbl.attr, "width:" .. natural_width .. " !important;")
      append_style(tbl.attr, "max-width:none !important;")
      append_style(tbl.attr, "table-layout:fixed !important;")
    end
  end
  if plan.stripe then
    add_class(tbl.attr, "smart-table-stripe")
  end
  if plan.row_rules then
    add_class(tbl.attr, "smart-table-row-rules")
  end
  if plan.repeat_header then
    add_class(tbl.attr, "smart-table-repeat-header")
  end

  local size = css_size(plan.text_size)
  if size then
    append_style(tbl.attr, "--smart-table-font-size:" .. size .. ";")
  end

  local wrapper_attr = profile_attr(plan)
  if natural_width then
    -- The inner wrapper constrains themes that force table { width: 100% }.
    -- The outer scroll container can still occupy the page width.
    append_style(wrapper_attr, "width:" .. natural_width .. " !important;")
    append_style(wrapper_attr, "max-width:none !important;")
  end
  if size then
    append_style(wrapper_attr, "--smart-table-font-size:" .. size .. ";")
  end
  local scroll_attr = pandoc.Attr("", { "smart-table-scroll" }, {})
  set_attribute(scroll_attr, "data-smart-tables", "true")

  if target == "revealjs" then
    add_class(scroll_attr, "smart-table-reveal")
    local reveal = options.revealjs or {}
    append_style(scroll_attr, "--smart-table-reveal-max-width:" .. (reveal.max_width or "100%") .. ";")
    append_style(scroll_attr, "--smart-table-reveal-max-height:" .. (reveal.max_height or "70vh") .. ";")
    append_style(scroll_attr, "--smart-table-reveal-overflow:" .. (reveal.overflow or "auto") .. ";")
    local reveal_size = css_size(reveal.font_size)
    if reveal_size then
      append_style(wrapper_attr, "--smart-table-font-size:" .. reveal_size .. ";")
    end
  end

  return pandoc.Div({ pandoc.Div({ tbl }, wrapper_attr) }, scroll_attr)
end

return M
