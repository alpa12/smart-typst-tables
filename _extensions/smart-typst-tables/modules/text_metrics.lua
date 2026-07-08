local M = {}

local function codepoints(text)
  text = text or ""
  local ok, out = pcall(function()
    local chars = {}
    for _, code in utf8.codes(text) do
      table.insert(chars, code)
    end
    return chars
  end)
  if ok then
    return out
  end

  local chars = {}
  for i = 1, #text do
    table.insert(chars, text:byte(i))
  end
  return chars
end

function M.stringify_blocks(blocks)
  if blocks == nil then
    return ""
  end
  local text = pandoc.utils.stringify(blocks)
  text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return text
end

function M.len(text)
  return #codepoints(text)
end

function M.visual_width(text)
  local width = 0
  for _, code in ipairs(codepoints(text)) do
    local ch = utf8.char(code)
    if ch:match("[%s%.,;:!'’%-]") then
      width = width + 0.35
    elseif ch:match("[%d]") then
      width = width + 0.55
    elseif ch:match("[%u]") then
      width = width + 0.72
    else
      width = width + 0.62
    end
  end
  return width
end

function M.median(values)
  if #values == 0 then
    return 0
  end
  local copy = {}
  for i, value in ipairs(values) do
    copy[i] = value
  end
  table.sort(copy)
  local mid = math.floor((#copy + 1) / 2)
  if #copy % 2 == 1 then
    return copy[mid]
  end
  return (copy[mid] + copy[mid + 1]) / 2
end

function M.max(values)
  local out = 0
  for _, value in ipairs(values) do
    if value > out then
      out = value
    end
  end
  return out
end

function M.unbreakable_width(text)
  local max_width = 0
  for token in tostring(text or ""):gmatch("%S+") do
    max_width = math.max(max_width, M.visual_width(token))
  end
  return max_width
end

return M
