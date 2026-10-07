-- text-size.lua : ::: {.text-NN} / [..]{.text-NN} / ::: {.math-NN} を LaTeX のサイズ指定に写す
-- (revealjs では text-size.scss が効くので何もしない．PDF 出力のときだけ働く．math-size.lua の後継)
local function size_for(n)
  if n <= 55 then return "\\tiny"
  elseif n <= 65 then return "\\scriptsize"
  elseif n <= 80 then return "\\footnotesize"
  elseif n <= 95 then return "\\small"
  elseif n <= 105 then return "\\normalsize"
  elseif n <= 125 then return "\\large"
  elseif n <= 150 then return "\\Large"
  elseif n <= 180 then return "\\LARGE"
  else return "\\huge" end
end
local function find_size(classes)
  for _, c in ipairs(classes) do
    local n = c:match("^text%-(%d+)$") or c:match("^math%-(%d+)$")
    if n then return size_for(tonumber(n)) end
  end
end
local function is_latex()
  return quarto.doc.is_format("latex") or quarto.doc.is_format("pdf")
end
function Div(el)
  if not is_latex() then return nil end
  local sz = find_size(el.classes)
  if not sz then return nil end
  local out = {pandoc.RawBlock("latex", "\\begingroup" .. sz)}
  for _, b in ipairs(el.content) do table.insert(out, b) end
  table.insert(out, pandoc.RawBlock("latex", "\\par\\endgroup"))
  return out
end
function Span(el)
  if not is_latex() then return nil end
  local sz = find_size(el.classes)
  if not sz then return nil end
  local out = {pandoc.RawInline("latex", "{" .. sz .. " ")}
  for _, b in ipairs(el.content) do table.insert(out, b) end
  table.insert(out, pandoc.RawInline("latex", "}"))
  return out
end
