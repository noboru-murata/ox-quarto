-- math-size.lua : ::: {.math-NN} を LaTeX のサイズ指定に写す
local SIZE = {
  ["math-95"] = "\\small",
  ["math-90"] = "\\small",
  ["math-85"] = "\\footnotesize",
  ["math-80"] = "\\footnotesize",
  ["math-75"] = "\\scriptsize",
  ["math-70"] = "\\scriptsize",
}
function Div(el)
  if not (quarto.doc.is_format("latex") or quarto.doc.is_format("pdf")) then
    return nil
  end
  for _, c in ipairs(el.classes) do
    if SIZE[c] then
      local out = {pandoc.RawBlock("latex", "\\begingroup" .. SIZE[c])}
      for _, b in ipairs(el.content) do table.insert(out, b) end
      table.insert(out, pandoc.RawBlock("latex", "\\endgroup"))
      return out
    end
  end
  return nil
end
