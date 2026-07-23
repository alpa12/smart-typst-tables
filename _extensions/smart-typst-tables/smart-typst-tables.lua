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
  if quarto and quarto.doc and quarto.doc.is_format and quarto.doc.is_format("revealjs") then
    return "revealjs"
  end
  if FORMAT == "revealjs" then
    return "revealjs"
  end
  if is_html() then
    return "html"
  end
  return nil
end

local function diagnostic_block(tbl, reason, target)
  if target == "typst" or not (state.options and state.options.diagnostics) then
    return nil
  end
  tbl.attr = tbl.attr or pandoc.Attr()
  tbl.attr.attributes = tbl.attr.attributes or {}
  tbl.attr.attributes["data-smart-tables-diagnosed"] = "true"
  local note = pandoc.Div(
    { pandoc.Para({ pandoc.Str("Smart table unchanged: " .. reason) }) },
    pandoc.Attr("", { "smart-table-diagnostic" }, {})
  )
  return pandoc.Div({ tbl, note }, pandoc.Attr("", { "smart-table-diagnostic-wrap" }, {}))
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

-- A Quarto table with a caption/reference is commonly represented as a Div
-- containing both the Table and one or more caption blocks.  Keep the Div's
-- identifier for Quarto, but pass its styling options to the contained table.
local function attr_without_identifier(attr)
  if not attr then
    return pandoc.Attr()
  end
  return pandoc.Attr("", copy_list(attr.classes), copy_attributes(attr.attributes))
end

local function is_processed(tbl)
  local attrs = tbl.attr and tbl.attr.attributes or {}
  return attrs["data-smart-tables-processed"] == "true" or attrs["data-smart-tables-diagnosed"] == "true"
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

  local options = config.for_target(state.options or config.defaults(), target)
  local model = table_ast.from_pandoc_table(tbl)
  if attr then
    model.attr = merge_attrs(model.attr, attr)
    if target ~= "typst" then
      tbl.attr = model.attr
    end
  end
  local source_attrs = (model.attr and model.attr.attributes) or {}
  if source_attrs["data-smart-tables-raw"] == "true" then
    diagnostics.debug(options, "table skipped: explicitly marked as raw HTML")
    return nil
  end
  local table_options = config.for_table(options, model.attr)
  table_options.output_target = target

  if not table_options.enabled then
    diagnostics.debug(options, "table skipped: disabled by configuration")
    return nil
  end

  local eligible, reason = table_ast.is_eligible(model, table_options, target == "typst" and "typst" or "html")
  if not eligible then
    diagnostics.debug(options, "table skipped: " .. reason)
    return diagnostic_block(tbl, reason, target)
  end

  local plan, plan_reason = layout_engine.plan(model, table_options)
  if not plan then
    diagnostics.debug(options, "table skipped: " .. plan_reason)
    return diagnostic_block(tbl, plan_reason, target)
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
  return html_transformer.render(tbl, model, plan, table_options, target)
end

local function div_filter(div)
  if not target_format() or not has_table_options(div.attr) then
    return nil
  end
  local table_index = nil
  for index, block in ipairs(div.content or {}) do
    if block.t == "Table" then
      if table_index then
        -- Applying one set of table-specific options to several tables would
        -- be ambiguous; leave this container to the ordinary table visitor.
        return nil
      end
      table_index = index
    end
  end
  if not table_index then
    return nil
  end

  local is_table_only = #div.content == 1
  local rendered = render_table(
    div.content[table_index],
    is_table_only and div.attr or attr_without_identifier(div.attr)
  )
  if rendered then
    if not is_table_only then
      div.content[table_index] = rendered
      return div
    end
    return rendered
  end

  disable_table(div.content[table_index])
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
