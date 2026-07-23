local M = {}

function M.debug(options, message)
  if options and options.diagnostics then
    if quarto and quarto.log and quarto.log.debug then
      quarto.log.debug("[smart-typst-tables] " .. message)
    else
      io.stderr:write("[smart-typst-tables] " .. message .. "\n")
    end
  end
end

function M.plan(options, plan)
  if not (options and options.diagnostics and plan) then return end
  for column, inferred in ipairs(plan.types or {}) do
    M.debug(options, string.format(
      "column %d: type=%s confidence=%.2f nowrap=%s width=%s reason=%s",
      column, inferred.type or "mixed", inferred.confidence or 0,
      tostring(inferred.nowrap), tostring((plan.columns or {})[column] or "browser-auto"),
      inferred.reason or "heuristic"))
  end
end

return M
