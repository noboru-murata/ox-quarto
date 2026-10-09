-- slide-notes.lua — 発表者ノート (org の #+begin_notes → ::: notes) を revealjs 以外でどう出すか
--
-- revealjs では何もしない (S キーの発表者表示に出る)．html / pdf (LaTeX) / typst では，
-- 何もしないと Quarto はノートを印の無い普通の段落として本文に混ぜて出す．yaml の slide-notes で選ぶ:
--   slide-notes: box      本文の中に枠で囲んで置く (見出し「ノート」．lecture.yaml の既定)
--   slide-notes: margin   余白に置く (.column-margin．Tufte 形式の handout-*.yaml の既定)．
--                         余白は頁をまたげないので，数行までのノート向き (長いと余白の他の内容と重なる)
--   slide-notes: hide     出さない
--   slide-notes: plain    普通の段落 (Quarto のまま)
-- ノートの長い講演は，スライドの画像とノートを並べる tools/notes-handout.py を使う．

local mode = "plain"
local MODES = { box = true, margin = true, hide = true, plain = true }

local function labelled(blocks)
  -- 先頭の段落の頭に「ノート」を付ける (段落で始まらなければ段落を足す)
  local label = pandoc.Strong({ pandoc.Str("ノート") })
  if blocks[1] and (blocks[1].t == "Para" or blocks[1].t == "Plain") then
    blocks[1].content:insert(1, pandoc.Space())
    blocks[1].content:insert(1, label)
  else
    blocks:insert(1, pandoc.Para({ label }))
  end
  return blocks
end

return {
  { Meta = function(m)
      if m["slide-notes"] ~= nil then
        local v = pandoc.utils.stringify(m["slide-notes"])
        if MODES[v] then mode = v
        else quarto.log.warning("slide-notes: '" .. v .. "' は box / margin / hide / plain のどれか (plain にする)") end
      end
    end },
  { Div = function(d)
      if not d.classes:includes("notes") then return nil end
      if quarto.doc.is_format("revealjs") then return nil end
      if mode == "hide" then return {} end
      if mode == "margin" then
        return pandoc.Div(labelled(d.content), pandoc.Attr("", { "column-margin", "slide-notes" }))
      end
      if mode == "box" then
        return quarto.Callout({ type = "note", title = "ノート", content = d.content,
                                appearance = "simple", icon = false })
      end
      return pandoc.Div(d.content, pandoc.Attr("", { "slide-notes" }))
    end },
}
