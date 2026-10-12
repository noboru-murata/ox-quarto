-- text-center.lua — 中央寄せの div (::: {.text-center}．org の #+begin_center … #+end_center) を各形式で効かせる
--
-- ox-quarto 本体は #+begin_center を ox-md に任せ，ox-md はブロックを丸ごと HTML で書き出す．そのため
-- 中の脚注が markdown の [^x] にならず本文が出ない，PDF では raw HTML として中身ごと消える，といった不具合があった．
-- ox-quarto-ext (ox-quarto-ext-block.el) は center を ::: {.text-center} の div にするので，中は普通の markdown になる．
-- このフィルタはその div を形式ごとに中央寄せにする:
--   revealjs / html   style="text-align: center" を足す (Bootstrap の .text-center が無い revealjs でも効く)
--   LaTeX (pdf)       \begin{center} … \end{center} で包む
--   typst             #align(center)[ … ] で包む
-- 手で ::: {.text-center} と書いた div にも効く．

local function is_html()
  return quarto.doc.is_format("html:js") or quarto.doc.is_format("revealjs")
end

function Div(div)
  if not div.classes:includes("text-center") then return nil end
  if is_html() then
    local style = div.attributes["style"] or ""
    if not style:match("text%-align") then
      div.attributes["style"] = (style ~= "" and (style:gsub(";?%s*$", "; ")) or "") .. "text-align: center;"
    end
    return div
  elseif quarto.doc.is_format("latex") then
    local out = pandoc.Blocks{ pandoc.RawBlock("latex", "\\begin{center}") }
    out:extend(div.content)
    out:insert(pandoc.RawBlock("latex", "\\end{center}"))
    return out
  elseif quarto.doc.is_format("typst") then
    local out = pandoc.Blocks{ pandoc.RawBlock("typst", "#align(center)[") }
    out:extend(div.content)
    out:insert(pandoc.RawBlock("typst", "]"))
    return out
  end
  return nil
end
