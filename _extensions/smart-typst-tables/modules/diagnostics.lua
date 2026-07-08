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

return M
