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
local html_transformer = require("html_transformer")
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

local function is_html()
  if quarto and quarto.doc and quarto.doc.is_format then
    return quarto.doc.is_format("html") or quarto.doc.is_format("revealjs")
  end
  return FORMAT == "html" or FORMAT == "html5" or FORMAT == "revealjs" or (FORMAT and FORMAT:match("html"))
end

local function target_format()
  if is_typst() then
    return "typst"
  end
  if is_html() then
    return "html"
  end
  return nil
end

local function include_typst_helpers()
  if state.helper_injected == "typst" then
    return
  end
  state.helper_injected = "typst"
  if quarto and quarto.doc and quarto.doc.include_file then
    quarto.doc.include_file("in-header", "smart-typst-tables.typ")
  end
end

local function include_html_helpers()
  if state.helper_injected == "html" then
    return
  end
  state.helper_injected = "html"
  if quarto and quarto.doc and quarto.doc.include_file then
    quarto.doc.include_file("in-header", "smart-tables.html")
  end
end

local function has_table_options(attr)
  local attrs = (attr and attr.attributes) or {}
  if attrs["smart-tables"] ~= nil then
    return true
  end
  for key, _ in pairs(attrs) do
    if key:match("^smart%-tables%-") then
      return true
    end
  end
  return false
end

local function copy_list(values)
  local out = {}
  for i, value in ipairs(values or {}) do
    out[i] = value
  end
  return out
end

local function copy_attributes(values)
  local out = {}
  for key, value in pairs(values or {}) do
    out[key] = value
  end
  return out
end

local function merge_attrs(table_attr, wrapper_attr)
  if not wrapper_attr then
    return table_attr
  end

  local id = table_attr and table_attr.identifier or ""
  if id == "" then
    id = wrapper_attr.identifier or ""
  end

  local classes = copy_list(wrapper_attr.classes)
  for _, class in ipairs((table_attr and table_attr.classes) or {}) do
    table.insert(classes, class)
  end

  local attrs = copy_attributes(wrapper_attr.attributes)
  for key, value in pairs((table_attr and table_attr.attributes) or {}) do
    attrs[key] = value
  end

  return pandoc.Attr(id, classes, attrs)
end

local function disable_table(tbl)
  tbl.attr = tbl.attr or pandoc.Attr()
  tbl.attr.attributes = tbl.attr.attributes or {}
  tbl.attr.attributes["smart-tables"] = "false"
end

local function is_processed(tbl)
  local attrs = tbl.attr and tbl.attr.attributes or {}
  return attrs["data-smart-tables-processed"] == "true"
end

local function mark_processed(tbl)
  tbl.attr = tbl.attr or pandoc.Attr()
  tbl.attr.attributes = tbl.attr.attributes or {}
  tbl.attr.attributes["data-smart-tables-processed"] = "true"
end

local function render_table(tbl, attr)
  local target = target_format()
  if not target then
    return nil
  end

  if is_processed(tbl) then
    return nil
  end

  local options = state.options or config.defaults()
  local model = table_ast.from_pandoc_table(tbl)
  if attr then
    model.attr = merge_attrs(model.attr, attr)
    if target == "html" then
      tbl.attr = model.attr
    end
  end
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

  if target == "typst" then
    local typst, writer_reason = typst_writer.render(model, plan, table_options)
    if not typst then
      diagnostics.debug(options, "table skipped: " .. writer_reason)
      return nil
    end

    include_typst_helpers()
    return pandoc.RawBlock("typst", typst)
  end

  mark_processed(tbl)
  include_html_helpers()
  return html_transformer.render(tbl, model, plan, table_options)
end

local function div_filter(div)
  if not target_format() or not has_table_options(div.attr) then
    return nil
  end
  if #div.content ~= 1 or div.content[1].t ~= "Table" then
    return nil
  end

  local rendered = render_table(div.content[1], div.attr)
  if rendered then
    return rendered
  end

  disable_table(div.content[1])
  return div
end

local function table_filter(tbl)
  return render_table(tbl)
end

function Pandoc(doc)
  if not target_format() then
    return doc
  end

  state.options = config.from_meta(doc.meta)
  doc = doc:walk({
    Div = div_filter
  })
  return doc:walk({
    Table = table_filter
  })
end
