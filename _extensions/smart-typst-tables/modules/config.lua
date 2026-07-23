local M = {}

local function meta_to_value(value)
  if value == nil then
    return nil
  end
  local t = pandoc.utils.type(value)
  if t == "boolean" or t == "string" or t == "number" then
    return value
  end
  if t == "Inlines" or t == "Blocks" then
    return pandoc.utils.stringify(value)
  end
  if type(value) == "table" and value.t == "MetaBool" then
    return value
  end
  return value
end

local function bool(value, default)
  value = meta_to_value(value)
  if value == nil then
    return default
  end
  if type(value) == "boolean" then
    return value
  end
  value = tostring(value):lower()
  if value == "true" or value == "yes" or value == "1" then
    return true
  end
  if value == "false" or value == "no" or value == "0" then
    return false
  end
  return default
end

local function string_value(value, default)
  value = meta_to_value(value)
  if value == nil or value == "" then
    return default
  end
  return tostring(value)
end

local function text_size(value, default)
  value = string_value(value, default)
  if value == nil then
    return default
  end
  value = tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
  if value == "" then
    return default
  end
  if value:lower() == "auto" then
    return "auto"
  end
  if value:match("^%d+%.?%d*$") then
    return value .. "em"
  end
  local normalized = value:lower()
  if normalized:match("^%d+%.?%d*%s*em$") or normalized:match("^%d+%.?%d*%s*pt$") then
    return normalized:gsub("%s+", "")
  end
  return default
end

local function positive_integer(value, default)
  value = tonumber(string_value(value, default))
  if value == nil or value < 1 then
    return default
  end
  return math.floor(value)
end

local function header_lines(value, default)
  value = string_value(value, default)
  if tostring(value):lower() == "auto" then
    return "auto"
  end
  return positive_integer(value, default)
end

function M.defaults()
  return {
    enabled = true,
    profile = "academic",
    text_size = "auto",
    optimize_widths = true,
    wrap_headers = "balanced",
    repeat_header = true,
    stripe = false,
    row_rules = true,
    fallback = "unchanged",
    diagnostics = false,
    max_header_lines = 3,
    header_lines = "auto",
    explicit_widths = "respect",
    table_width = "natural",
    align = "center",
    nowrap = "auto",
    column_types = nil,
    profile_explicit = false,
    revealjs = {
      max_width = "100%",
      max_height = "70vh",
      overflow = "auto",
      font_size = "auto",
    },
  }
end

local function css_value(value, default)
  value = string_value(value, default)
  if value:match("[;{}\n\r]") then
    return default
  end
  return value
end

local function revealjs_config(cfg, defaults)
  cfg = cfg or {}
  local overflow = string_value(cfg.overflow, defaults.overflow):lower()
  if overflow ~= "auto" and overflow ~= "scroll" and overflow ~= "hidden" and overflow ~= "visible" then
    overflow = defaults.overflow
  end
  return {
    max_width = css_value(cfg["max-width"] or cfg.max_width, defaults.max_width),
    max_height = css_value(cfg["max-height"] or cfg.max_height, defaults.max_height),
    overflow = overflow,
    font_size = text_size(cfg["font-size"] or cfg.font_size, defaults.font_size),
  }
end

function M.from_meta(meta)
  local out = M.defaults()
  local cfg = meta["smart-tables"] or meta["smart_typst_tables"] or {}

  out.enabled = bool(cfg.enabled, out.enabled)
  out.profile_explicit = cfg.profile ~= nil
  out.profile = string_value(cfg.profile, out.profile)
  out.text_size = text_size(cfg["text-size"] or cfg.text_size, out.text_size)
  out.optimize_widths = bool(cfg["optimize-widths"] or cfg.optimize_widths, out.optimize_widths)
  out.wrap_headers = string_value(cfg["wrap-headers"] or cfg.wrap_headers, out.wrap_headers)
  out.repeat_header = bool(cfg["repeat-header"] or cfg.repeat_header, out.repeat_header)
  out.stripe = bool(cfg.stripe, out.stripe)
  out.row_rules = bool(cfg["row-rules"] or cfg.row_rules, out.row_rules)
  out.fallback = string_value(cfg.fallback, out.fallback)
  out.diagnostics = bool(cfg.diagnostics, out.diagnostics)
  out.max_header_lines = positive_integer(cfg["max-header-lines"] or cfg.max_header_lines, out.max_header_lines)
  out.header_lines = header_lines(cfg["header-lines"] or cfg.header_lines, out.header_lines)
  out.explicit_widths = string_value(cfg["explicit-widths"] or cfg.explicit_widths, out.explicit_widths)
  out.table_width = string_value(cfg["table-width"] or cfg.table_width, out.table_width)
  out.align = string_value(cfg.align, out.align)
  out.revealjs = revealjs_config(cfg.revealjs, out.revealjs)

  return out
end

function M.for_target(options, target)
  local out = {}
  for k, v in pairs(options) do
    out[k] = v
  end
  if target == "revealjs" and not out.profile_explicit then
    out.profile = "reveal"
  end
  return out
end

function M.for_table(options, attr)
  local out = {}
  for k, v in pairs(options) do
    out[k] = v
  end

  local attrs = (attr and attr.attributes) or {}
  if attrs["smart-tables"] == "false" or attrs["smart-tables"] == "off" then
    out.enabled = false
  end
  if attrs["smart-tables-profile"] then
    out.profile = attrs["smart-tables-profile"]
    out.profile_explicit = true
  end
  if attrs["smart-tables-text-size"] then
    out.text_size = text_size(attrs["smart-tables-text-size"], out.text_size)
  end
  if attrs["smart-tables-stripe"] then
    out.stripe = bool(attrs["smart-tables-stripe"], out.stripe)
  end
  if attrs["smart-tables-row-rules"] then
    out.row_rules = bool(attrs["smart-tables-row-rules"], out.row_rules)
  end
  if attrs["smart-tables-repeat-header"] then
    out.repeat_header = bool(attrs["smart-tables-repeat-header"], out.repeat_header)
  end
  if attrs["smart-tables-max-header-lines"] then
    out.max_header_lines = positive_integer(attrs["smart-tables-max-header-lines"], out.max_header_lines)
  end
  if attrs["smart-tables-header-lines"] then
    out.header_lines = header_lines(attrs["smart-tables-header-lines"], out.header_lines)
  end
  if attrs["smart-tables-optimize-widths"] then
    out.optimize_widths = bool(attrs["smart-tables-optimize-widths"], out.optimize_widths)
  end
  if attrs["smart-tables-width"] then
    out.table_width = attrs["smart-tables-width"]
  end
  if attrs["smart-tables-align"] then
    out.align = attrs["smart-tables-align"]
  end
  if attrs["smart-tables-nowrap"] then
    local nowrap = tostring(attrs["smart-tables-nowrap"]):lower()
    if nowrap == "auto" or nowrap == "all" or nowrap == "none" then out.nowrap = nowrap end
  end
  if attrs["smart-tables-column-types"] then
    out.column_types = {}
    for value in tostring(attrs["smart-tables-column-types"]):gmatch("[^,%s]+") do
      table.insert(out.column_types, value:lower())
    end
  end
  for key, value in pairs(attrs) do
    local index = key:match("^smart%-tables%-column%-(%d+)$")
    if index then
      out.column_types = out.column_types or {}
      out.column_types[tonumber(index)] = tostring(value):lower()
    end
  end
  return out
end

return M
