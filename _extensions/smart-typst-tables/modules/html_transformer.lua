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
  if kind == "numeric" or kind == "currency" or kind == "percentage" or kind == "date" or kind == "duration" then
    table.insert(classes, "smart-table-nowrap")
  end

  return classes
end

local function wrap_blocks(blocks, classes)
  if blocks == nil then
    return blocks
  end

  for _, block in ipairs(blocks) do
    if block.t == "Plain" or block.t == "Para" then
      block.content = { pandoc.Span(block.content, pandoc.Attr("", classes, {})) }
    end
  end

  return blocks
end

local function transform_header(tbl, plan)
  if tbl.head == nil or tbl.head.rows == nil then
    return
  end

  for _, row in ipairs(tbl.head.rows) do
    for col, cell in ipairs(row.cells) do
      local lines = plan.header_lines[col] or { "" }
      local classes = cell_classes(plan, col, true)
      cell.contents = {
        pandoc.Plain({ pandoc.Span(header_inlines(lines), pandoc.Attr("", classes, {})) })
      }
    end
  end
end

local function transform_body(tbl, plan)
  for _, body in ipairs(tbl.bodies or {}) do
    for _, row in ipairs(body.body or {}) do
      for col, cell in ipairs(row.cells) do
        cell.contents = wrap_blocks(cell.contents, cell_classes(plan, col, false))
      end
    end
  end
end

local function apply_colspecs(tbl, plan)
  for col, colspec in ipairs(tbl.colspecs or {}) do
    if plan.col_align and plan.col_align[col] then
      colspec[1] = pandoc_align(plan.col_align[col])
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

function M.render(tbl, model, plan, options)
  transform_header(tbl, plan)
  transform_body(tbl, plan)
  apply_colspecs(tbl, plan)

  tbl.attr = tbl.attr or pandoc.Attr()
  add_class(tbl.attr, "smart-table")
  add_class(tbl.attr, "smart-table-profile-" .. css_ident(plan.profile, "academic"))
  add_class(tbl.attr, "smart-table-width-" .. css_ident(plan.table_width, "natural"))
  add_class(tbl.attr, "smart-table-align-" .. css_ident(plan.align, "center"))
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
  if size then
    append_style(wrapper_attr, "--smart-table-font-size:" .. size .. ";")
  end
  set_attribute(wrapper_attr, "data-smart-tables", "true")

  return pandoc.Div({ tbl }, wrapper_attr)
end

return M
