local M = {}

local function escape(text)
  text = tostring(text or "")
  text = text:gsub("\\", "\\\\")
  text = text:gsub("#", "\\#")
  text = text:gsub("%$", "\\$")
  text = text:gsub("%[", "\\[")
  text = text:gsub("%]", "\\]")
  return text
end

local function align(value)
  if value == "right" then
    return "right"
  end
  if value == "center" then
    return "center"
  end
  return "left"
end

local function caption_text(caption)
  if caption == nil or caption.long == nil or #caption.long == 0 then
    return nil
  end
  return pandoc.utils.stringify(caption.long)
end

local function identifier(attr)
  if attr and attr.identifier and attr.identifier ~= "" then
    return attr.identifier
  end
  return nil
end

local function cell(line)
  return "    " .. line
end

local function typst_align(value)
  if value == "left" then
    return "left"
  end
  if value == "right" then
    return "right"
  end
  return "center"
end

local function text_size_arg(value)
  if value == nil or value == "" or value == "auto" then
    return ""
  end
  return ", text-size: " .. value
end

function M.render(model, plan, options)
  local p = "smart-table-profile(\"" .. escape(plan.profile) .. "\")"
  local scope_args = "profile: \"" .. escape(plan.profile) .. "\"" .. text_size_arg(plan.text_size)
  local items = {}

  table.insert(items, "table.header(")
  table.insert(items, "  repeat: " .. tostring(plan.repeat_header) .. ",")
  for col = 1, model.n_cols do
    local escaped_lines = {}
    for _, line in ipairs(plan.header_lines[col]) do
      local escaped_line = escape(line):gsub(" ", "~"):gsub("%-", "‑")
      table.insert(escaped_lines, escaped_line)
    end
    local header = table.concat(escaped_lines, "#linebreak()")
    local comma = col == model.n_cols and "" or ","
    table.insert(items, string.format(
      "  table.cell(align: %s, fill: %s.header-fill)[#strong[%s]]%s",
      align((plan.header_align and plan.header_align[col]) or plan.col_align[col]),
      p,
      header,
      comma
    ))
  end
  table.insert(items, "),")
  table.insert(items, "table.hline(stroke: " .. p .. ".header-stroke),")

  for row_index, row in ipairs(model.body_rows) do
    for col = 1, model.n_cols do
      local source = row.cells[col]
      local fill = ""
      if plan.stripe and row_index % 2 == 0 then
        fill = ", fill: " .. p .. ".stripe-fill"
      end
      local comma = ","
      table.insert(items, string.format(
        "table.cell(align: %s%s)[%s]%s",
        align(plan.col_align[col]),
        fill,
        escape(source and source.text or ""),
        comma
      ))
    end
    if plan.row_rules and row_index < #model.body_rows then
      table.insert(items, "table.hline(stroke: " .. p .. ".row-stroke),")
    end
  end

  local table_expression = table.concat({
    "#table(",
    "    columns: (" .. table.concat(plan.columns, ", ") .. (model.n_cols == 1 and "," or "") .. "),",
    "    column-gutter: " .. p .. ".gutter,",
    "    stroke: none,",
    "    inset: (x: " .. p .. ".inset-x, y: " .. p .. ".inset-y),",
    cell(table.concat(items, "\n    ")),
    "  )"
  }, "\n")

  if plan.table_width == "full" then
    table_expression = table.concat({
      "#block(width: 100%)[",
      "  " .. table_expression:gsub("\n", "\n  "),
      "]"
    }, "\n")
  end

  local table_code = table.concat({
    "smart-table-scope(" .. scope_args .. ")[",
    "  " .. table_expression:gsub("\n", "\n  "),
    "]"
  }, "\n")

  local cap = caption_text(model.caption)
  local id = identifier(model.attr)
  local wrapped_table = "#" .. table_code
  if plan.align and plan.align ~= "none" then
    wrapped_table = "#align(" .. typst_align(plan.align) .. ")[\n  " .. wrapped_table:gsub("\n", "\n  ") .. "\n]"
  end

  if cap then
    local label = id and (" <" .. id .. ">") or ""
    return table.concat({
      "#align(" .. typst_align(plan.align) .. ")[",
      "  #figure(",
      "    " .. table_code:gsub("\n", "\n    "),
      "    ,",
      "    kind: table,",
      "    caption: [" .. escape(cap) .. "]",
      "  )" .. label,
      "]"
    }, "\n")
  end

  return wrapped_table
end

M.escape = escape

return M
