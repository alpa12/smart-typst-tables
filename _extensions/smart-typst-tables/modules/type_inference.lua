local metrics = require("text_metrics")

local M = {}

local function clean_values(values)
  local out = {}
  for _, value in ipairs(values) do
    value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if value ~= "" and value ~= "-" then
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

function M.infer(header, values)
  values = clean_values(values)
  local header_lc = tostring(header or ""):lower()
  if #values == 0 then
    return { type = "mixed", confidence = 0.2 }
  end

  if share(values, "^%d%d%d%d%-%d%d%-%d%d$") >= 0.75 or header_lc:match("date") then
    return { type = "date", confidence = 0.9 }
  end
  if header_lc:match("duration") or share(values, "^%d+%s+[Dd]ays?$") + share(values, "^%d+%s+[Ww]eeks?$") + share(values, "^%d+%s+[Mm]onths?$") >= 0.65 then
    return { type = "duration", confidence = 0.85 }
  end
  if share(values, "^%-?[%d%s,%.]+%s?[$€£]$") >= 0.65 or header_lc:match("prime") or header_lc:match("amount") then
    return { type = "currency", confidence = 0.85 }
  end
  if share(values, "^%-?%d+[,.]?%d*%s?%%$") >= 0.65 or header_lc:match("ratio") or header_lc:match("rate") then
    return { type = "percentage", confidence = 0.85 }
  end
  if share(values, "^[Tt]rue$") + share(values, "^[Ff]alse$") >= 0.75 then
    return { type = "boolean", confidence = 0.8 }
  end

  local numeric = 0
  for _, value in ipairs(values) do
    local normalized = value:gsub("[%s,$€£%%]", ""):gsub(",", ".")
    if tonumber(normalized) ~= nil then
      numeric = numeric + 1
    end
  end
  if numeric / #values >= 0.8 then
    return { type = "numeric", confidence = 0.85 }
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
    return { type = "identifier", confidence = 0.7 }
  end
  if med_len >= 24 or max_len >= 36 then
    return { type = "free_text", confidence = 0.85 }
  end
  if unique_count / #values <= 0.75 and max_len <= 18 then
    return { type = "categorical", confidence = 0.75 }
  end
  if share(values, "^[%w_%-%.:/]+$") >= 0.8 and metrics.max(lengths) >= 16 then
    return { type = "code", confidence = 0.7 }
  end
  return { type = "mixed", confidence = 0.45 }
end

return M
