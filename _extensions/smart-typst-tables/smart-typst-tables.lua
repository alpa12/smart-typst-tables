local function script_dir()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  return source:match("^(.*[/\\])") or "./"
end

package.path = script_dir() .. "modules/?.lua;" .. package.path

local config = require("config")
local table_ast = require("table_ast")
local layout_engine = require("layout_engine")
local typst_writer = require("typst_writer")
local diagnostics = require("diagnostics")

local state = {
  options = nil,
  helper_injected = false,
}

local function is_typst()
  if quarto and quarto.doc and quarto.doc.is_format then
    return quarto.doc.is_format("typst")
  end
  return FORMAT == "typst" or (FORMAT and FORMAT:match("^typst"))
end

local function include_helpers()
  if state.helper_injected then
    return
  end
  state.helper_injected = true
  if quarto and quarto.doc and quarto.doc.include_file then
    quarto.doc.include_file("in-header", "smart-typst-tables.typ")
  end
end

local function table_filter(tbl)
  if not is_typst() then
    return nil
  end

  local options = state.options or config.defaults()
  local model = table_ast.from_pandoc_table(tbl)
  local table_options = config.for_table(options, model.attr)

  if not table_options.enabled then
    diagnostics.debug(options, "table skipped: disabled by configuration")
    return nil
  end

  local eligible, reason = table_ast.is_eligible(model, table_options)
  if not eligible then
    diagnostics.debug(options, "table skipped: " .. reason)
    return nil
  end

  local plan, plan_reason = layout_engine.plan(model, table_options)
  if not plan then
    diagnostics.debug(options, "table skipped: " .. plan_reason)
    return nil
  end

  local typst, writer_reason = typst_writer.render(model, plan, table_options)
  if not typst then
    diagnostics.debug(options, "table skipped: " .. writer_reason)
    return nil
  end

  include_helpers()
  return pandoc.RawBlock("typst", typst)
end

function Pandoc(doc)
  if not is_typst() then
    return doc
  end

  state.options = config.from_meta(doc.meta)
  return doc:walk({
    Table = table_filter
  })
end
