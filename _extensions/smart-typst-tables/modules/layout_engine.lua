local table_ast = require("table_ast")
local metrics = require("text_metrics")
local type_inference = require("type_inference")
local header_wrap = require("header_wrap")

local M = {}

local function fmt(x)
  local out = string.format("%.2f", x)
  out = out:gsub("0+$", ""):gsub("%.$", "")
  return out
end

local function numeric_like_width(min_width, header_need, need, value_need)
  local upper = math.max(10, header_need, value_need)
  local target = math.max(need + 0.2, value_need)
  return math.max(min_width, math.min(upper, target))
end

local function type_width(kind, header_lines, values, n_cols)
  local line_width = 0
  for _, line in ipairs(header_lines) do
    line_width = math.max(line_width, metrics.visual_width(line))
  end

  local value_widths = {}
  local unbreakable = 0
  for _, value in ipairs(values) do
    table.insert(value_widths, metrics.visual_width(value))
    unbreakable = math.max(unbreakable, metrics.unbreakable_width(value))
  end
  local med = metrics.median(value_widths)
  local maxv = metrics.max(value_widths)
  local header_need = line_width + 0.35
  local need = math.max(header_need, med * 0.65, math.min(maxv, 42) * 0.25, unbreakable * 0.7)
  local numeric_value_need = maxv + 0.85

  if kind == "date" then
    return "fixed", math.max(5.7, math.min(math.max(6.6, header_need), need + 0.2))
  end
  if kind == "duration" then
    return "fixed", math.max(4.6, math.min(math.max(6.2, header_need), need + 0.2))
  end
  if kind == "currency" then
    return "fixed", numeric_like_width(4.7, header_need, need, numeric_value_need)
  end
  if kind == "percentage" or kind == "numeric" then
    return "fixed", numeric_like_width(4.0, header_need, need, numeric_value_need)
  end
  if kind == "identifier" or kind == "boolean" then
    return "auto", 0
  end
  if kind == "categorical" and need <= 9 and n_cols >= 5 then
    return "auto", 0
  end
  if kind == "free_text" then
    local fixed = math.max(line_width, med * 0.85, math.min(maxv, 36) * 0.55, unbreakable * 0.95) + 0.8
    return "fixed", math.max(8, math.min(24, fixed))
  end
  if kind == "code" then
    if unbreakable > 18 then
      return "fixed", math.max(12, math.min(26, unbreakable * 0.75))
    end
    return "auto", 0
  end
  if need <= 12 then
    return "auto", 0
  end
  return "fixed", math.max(8, math.min(18, need + 0.8))
end

local function alignment(kind, source)
  if source and source:match("Right") then
    return "right"
  end
  if source and source:match("Center") then
    return "center"
  end
  if kind == "currency" or kind == "percentage" or kind == "numeric" then
    return "right"
  end
  if kind == "date" or kind == "duration" then
    return "center"
  end
  return "left"
end

local function header_alignment(column_align, kind)
  if column_align == "right" or column_align == "center" then
    return "center"
  end
  if kind == "date" or kind == "duration" or kind == "numeric" or kind == "currency" or kind == "percentage" then
    return "center"
  end
  return "left"
end

function M.plan(model, options)
  if not options.optimize_widths then
    return nil, "width optimization disabled"
  end

  local headers = table_ast.header_texts(model)
  local columns = {}
  local aligns = {}
  local header_aligns = {}
  local header_lines = {}
  local types = {}
  local fixed_total = 0
  local fr_min = math.huge

  for col = 1, model.n_cols do
    local values = table_ast.column_values(model, col)
    local inferred = type_inference.infer(headers[col], values)
    local lines = header_wrap.wrap(headers[col], options.max_header_lines, options.header_lines)
    local width_kind, width_value = type_width(inferred.type, lines, values, model.n_cols)

    types[col] = inferred
    aligns[col] = alignment(inferred.type, model.colspecs[col] and model.colspecs[col].align)
    header_aligns[col] = header_alignment(aligns[col], inferred.type)

    if options.table_width == "full" and (inferred.type == "free_text" or inferred.type == "mixed") then
      columns[col] = math.max(1.3, math.min(4, width_value / 6))
      fr_min = math.min(fr_min, columns[col])
    elseif width_kind == "fixed" then
      columns[col] = fmt(width_value) .. "em"
      fixed_total = fixed_total + width_value
    elseif width_kind == "auto" then
      columns[col] = "auto"
    else
      columns[col] = width_value
      fr_min = math.min(fr_min, width_value)
    end
  end

  for col = 1, model.n_cols do
    header_lines[col] = header_wrap.wrap(headers[col], options.max_header_lines, options.header_lines)
  end

  local has_fr = false
  for col = 1, #columns do
    if type(columns[col]) == "number" then
      has_fr = true
      columns[col] = fmt(columns[col] / fr_min) .. "fr"
    end
  end

  if fixed_total > 36 and model.n_cols >= 8 and options.output_target == "typst" then
    return nil, "fixed columns exceed safe width"
  end

  return {
    columns = columns,
    col_align = aligns,
    header_align = header_aligns,
    header_lines = header_lines,
    types = types,
    profile = options.profile,
    text_size = options.text_size,
    repeat_header = options.repeat_header,
    stripe = options.stripe,
    row_rules = options.row_rules,
    table_width = options.table_width,
    align = options.align,
  }
end

return M
