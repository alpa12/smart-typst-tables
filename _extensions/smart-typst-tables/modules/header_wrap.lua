local metrics = require("text_metrics")

local M = {}

local function split_words(text)
  local words = {}
  for word in tostring(text or ""):gmatch("%S+") do
    table.insert(words, word)
  end
  return words
end

local function combinations(n, k, start, current, out)
  if #current == k then
    local item = {}
    for i, value in ipairs(current) do
      item[i] = value
    end
    table.insert(out, item)
    return
  end
  for i = start, n do
    table.insert(current, i)
    combinations(n, k, i + 1, current, out)
    table.remove(current)
  end
end

local function make_lines(words, breaks)
  local lines = {}
  local starts = { 1 }
  for _, b in ipairs(breaks) do
    table.insert(starts, b + 1)
  end
  for i, start in ipairs(starts) do
    local stop = breaks[i] or #words
    local line = {}
    for j = start, stop do
      table.insert(line, words[j])
    end
    table.insert(lines, table.concat(line, " "))
  end
  return lines
end

function M.wrap(text, max_lines, forced_lines)
  text = tostring(text or "")
  max_lines = max_lines or 3
  local words = split_words(text)
  if #words <= 1 then
    return { text }
  end

  local line_count
  if forced_lines and forced_lines ~= "auto" then
    line_count = math.min(math.max(1, tonumber(forced_lines) or 1), #words)
  elseif metrics.len(text) <= 10 then
    line_count = 1
  elseif metrics.len(text) <= 38 then
    -- Two balanced lines are usually the best compromise between a compact
    -- table and an easily scannable header. Reserve three or more lines for
    -- genuinely long labels.
    line_count = math.min(2, max_lines, #words)
  else
    line_count = math.min(max_lines, math.max(2, math.ceil(metrics.len(text) / 22)), #words)
  end
  local all = {}
  combinations(#words - 1, line_count - 1, 1, {}, all)

  local best = nil
  local best_score = math.huge
  for _, breaks in ipairs(all) do
    local lines = make_lines(words, breaks)
    local max_len = 0
    local sum = 0
    local penalty = 0
    for _, line in ipairs(lines) do
      local len = metrics.visual_width(line)
      max_len = math.max(max_len, len)
      sum = sum + len
      if #split_words(line) == 1 and metrics.len(line) <= 4 then
        penalty = penalty + 8
      end
      if line:match("^[dD]e$") or line:match("^[dD]u$") then
        penalty = penalty + 5
      end
    end
    local mean = sum / #lines
    local variance = 0
    for _, line in ipairs(lines) do
      local delta = metrics.visual_width(line) - mean
      variance = variance + delta * delta
    end
    local score = max_len + math.sqrt(variance / #lines) + penalty
    if score < best_score then
      best = lines
      best_score = score
    end
  end
  return best or { text }
end

function M.fit(text, max_lines, width, forced_lines)
  text = tostring(text or "")
  if width and metrics.visual_width(text) <= width then
    return { text }
  end
  return M.wrap(text, max_lines, forced_lines)
end

return M
