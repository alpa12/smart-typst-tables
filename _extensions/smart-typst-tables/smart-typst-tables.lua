-- Inject Typst helper definitions for smart-typst-tables.
-- The R API emits raw Typst. This filter keeps reusable styling helpers in the
-- extension so documents do not need to import them manually.

local function is_typst()
  return FORMAT and FORMAT:match("typst")
end

local function filter_dir()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  return source:match("^(.*[/\\])") or ""
end

local function read_typst_helpers()
  local path = filter_dir() .. "smart-typst-tables.typ"
  local file = io.open(path, "r")
  if not file then
    io.stderr:write("smart-typst-tables: could not read " .. path .. "\n")
    return ""
  end
  local content = file:read("*a")
  file:close()
  return content
end

function Pandoc(doc)
  if not is_typst() then
    return doc
  end

  local helpers = read_typst_helpers()
  if helpers == "" then
    return doc
  end

  table.insert(doc.blocks, 1, pandoc.RawBlock("typst", helpers))
  return doc
end

