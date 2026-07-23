local metrics = require("text_metrics")

local M = {}

-- Arithmetic expressions are prose-like table content, not compact numeric
-- values.  Detect them before any header hint can influence the result.
local function is_formula(value)
  -- Keep conventional date values out of the expression path even though they
  -- contain slashes. Other fraction-like values are formulae only when they
  -- carry an arithmetic operator or an explicit equality.
  if value:match("^%d%d%d%d%-%d%d%-%d%d$") or value:match("^%d?%d/%d?%d/%d%d%d%d$") then
    return false
  end
  return value:find("=", 1, true) ~= nil or value:find("×", 1, true) ~= nil
    or value:find("+", 1, true) ~= nil or value:find("−", 1, true) ~= nil
    or (value:find("/", 1, true) ~= nil and value:find("%d+/%d+") ~= nil)
end

local function clean_values(values)
  local out = {}
  for _, value in ipairs(values) do
    value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if value ~= "" and value ~= "-" and value ~= "—" and value:lower() ~= "na" and value:lower() ~= "nd" then
      table.insert(out, value)
    end
  end
  return out
end

local function share(values, pattern)
  if #values == 0 then
    return 0
  end
  local n = 0
  for _, value in ipairs(values) do
    if value:match(pattern) then
      n = n + 1
    end
  end
  return n / #values
end

local function share_if(values, predicate)
  if #values == 0 then return 0 end
  local n = 0
  for _, value in ipairs(values) do if predicate(value) then n = n + 1 end end
  return n / #values
end

local function is_currency(value)
  if not (value:find("$", 1, true) or value:find("€", 1, true) or value:find("£", 1, true)) then
    return false
  end
  local number = value:gsub("$", ""):gsub("€", ""):gsub("£", "")
  return number:match("^%s*%-?[%d%s,%.]+%s*$") ~= nil
end

function M.infer(header, values)
  values = clean_values(values)
  local header_lc = tostring(header or ""):lower()
  if #values == 0 then
    return { type = "mixed", confidence = 0.2 }
  end

  local formula_share = 0
  for _, value in ipairs(values) do
    if is_formula(value) then formula_share = formula_share + 1 end
  end
  formula_share = formula_share / #values
  if formula_share >= 0.5 then
    return { type = "formula", confidence = formula_share, compact_share = 0,
      reason = "arithmetic expressions in values" }
  end

  local date_share = math.max(share(values, "^%d%d%d%d%-%d%d%-%d%d$"), share(values, "^%d?%d[/%-]%d?%d[/%-]%d%d%d%d$"))
  if date_share >= 0.75 then
    return { type = "date", confidence = date_share, compact_share = date_share, reason = "date-shaped values" }
  end
  local duration_share = share(values, "^%d+%s+[Dd]ays?$") + share(values, "^%d+%s+[Ww]eeks?$") + share(values, "^%d+%s+[Mm]onths?$") + share(values, "^%d+%s*h%s*%d*%s*$")
  if duration_share >= 0.65 then
    return { type = "duration", confidence = duration_share, compact_share = duration_share, reason = "duration-shaped values" }
  end
  local currency_share = share_if(values, is_currency)
  if currency_share >= 0.65 then
    return { type = "currency", confidence = currency_share, compact_share = currency_share,
      reason = "currency symbols in values" }
  end
  local percentage_share = share(values, "^%-?%d+[,.]?%d*%s?%%$")
  if percentage_share >= 0.65 then
    return { type = "percentage", confidence = percentage_share, compact_share = percentage_share,
      reason = "percent signs in values" }
  end
  if share(values, "^[Tt]rue$") + share(values, "^[Ff]alse$") >= 0.75 then
    return { type = "boolean", confidence = 0.8, compact_share = 0.8, reason = "boolean values" }
  end

  local numeric = 0
  for _, value in ipairs(values) do
    local normalized = metrics.normalize_number_text(value):gsub("[$€£%%]", ""):gsub("%s", "")
    if normalized:match(",") and normalized:match("%.") then
      normalized = normalized:gsub("%.", ""):gsub(",", ".")
    else
      normalized = normalized:gsub(",", ".")
    end
    if tonumber(normalized) ~= nil then
      numeric = numeric + 1
    end
  end
  if numeric / #values >= 0.8 then
    return { type = "numeric", confidence = numeric / #values, compact_share = numeric / #values,
      reason = "numeric values" }
  end

  local lengths = {}
  local uniques = {}
  for _, value in ipairs(values) do
    table.insert(lengths, metrics.len(value))
    uniques[value] = true
  end
  local unique_count = 0
  for _ in pairs(uniques) do
    unique_count = unique_count + 1
  end
  local max_len = metrics.max(lengths)
  local med_len = metrics.median(lengths)

  if header_lc:match("id$") or header_lc:match("code") or max_len <= 8 then
    return { type = "identifier", confidence = 0.7, compact_share = 0.8, reason = "short identifiers" }
  end
  if med_len >= 24 or max_len >= 36 then
    return { type = "free_text", confidence = 0.85, compact_share = 0, reason = "long text values" }
  end
  if unique_count / #values <= 0.75 and max_len <= 18 then
    return { type = "categorical", confidence = 0.75, compact_share = 0, reason = "repeated categories" }
  end
  if share(values, "^[%w_%-%.:/]+$") >= 0.8 and metrics.max(lengths) >= 16 then
    return { type = "code", confidence = 0.7, compact_share = 0.8, reason = "code-like values" }
  end
  return { type = "mixed", confidence = 0.45, compact_share = 0, reason = "mixed values" }
end

return M
