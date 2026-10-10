-- ack.lua — 謝辞の頁の部品: 人の一覧 (.people)．ほかの部品 (.logos / .funding / .ack-note) は parts.scss だけで組む
--
-- org では記述リストで書く (写真は名前の前に画像のリンク．無くてもよい):
--   #+begin_people
--   - [[file:figs/ack/hanako.jpg]] 山田 花子 :: ○○大学 理工学部
--   - 鈴木 一郎 :: △△研究所
--   #+end_people
-- ox-quarto (ox-md) は記述リストの項目を「**[画像] 名前:** 所属」の箇条書きにするので，
-- それを写真・名前・所属の組 (div.person) に組み直す．見た目は parts.scss (.people)．
-- revealjs / html 以外 (pdf / typst) では写真を外し「名前 (所属)」の箇条書きにする．

local function is_html()
  return quarto.doc.is_format("html:js") or quarto.doc.is_format("revealjs")
end

-- 名前の末尾の ":" (ox-md が付ける) と前後の空白を取る
local function trim_name(inl)
  while #inl > 0 and (inl[1].t == "Space" or inl[1].t == "SoftBreak") do inl:remove(1) end
  while #inl > 0 and (inl[#inl].t == "Space" or inl[#inl].t == "SoftBreak") do inl:remove(#inl) end
  local last = inl[#inl]
  if last and last.t == "Str" then
    last.text = last.text:gsub("[:：]$", "")
    if last.text == "" then inl:remove(#inl) end
  end
  return inl
end

local function trim(inl)
  while #inl > 0 and (inl[1].t == "Space" or inl[1].t == "SoftBreak") do inl:remove(1) end
  while #inl > 0 and (inl[#inl].t == "Space" or inl[#inl].t == "SoftBreak") do inl:remove(#inl) end
  return inl
end

-- 項目 (Block の並び) → photo (Image か nil)，name，affil
local function split_item(blocks)
  local b = blocks[1]
  if not b or (b.t ~= "Para" and b.t ~= "Plain") then return nil end
  local inl = b.content
  local photo, name, affil = nil, pandoc.Inlines{}, pandoc.Inlines{}
  if inl[1] and inl[1].t == "Strong" then
    for _, x in ipairs(inl[1].content) do
      if x.t == "Image" and not photo then photo = x else name:insert(x) end
    end
    for i = 2, #inl do affil:insert(inl[i]) end
  else
    for _, x in ipairs(inl) do
      if x.t == "Image" and not photo then photo = x else name:insert(x) end
    end
  end
  return photo, trim_name(name), trim(affil)
end

local function people(div)
  local list
  for _, b in ipairs(div.content) do
    if b.t == "BulletList" then list = b; break end
  end
  if not list then return nil end
  if is_html() then
    local cards = pandoc.Blocks{}
    for _, item in ipairs(list.content) do
      local photo, name, affil = split_item(item)
      if name then
        local kids = pandoc.Blocks{}
        if photo then
          photo.attr = pandoc.Attr("", {}, {})        -- 大きさは parts.scss に任せる
          kids:insert(pandoc.Div(pandoc.Plain{photo}, pandoc.Attr("", {"ack-photo"})))
        end
        local text = pandoc.Blocks{ pandoc.Div(pandoc.Plain(name), pandoc.Attr("", {"ack-name"})) }
        if #affil > 0 then text:insert(pandoc.Div(pandoc.Plain(affil), pandoc.Attr("", {"ack-affil"}))) end
        kids:insert(pandoc.Div(text, pandoc.Attr("", {"ack-text"})))
        cards:insert(pandoc.Div(kids, pandoc.Attr("", {"person"})))
      end
    end
    div.content = cards
    return div
  end
  -- pdf / typst: 名前 (所属)
  local items = {}
  for _, item in ipairs(list.content) do
    local _, name, affil = split_item(item)
    if name then
      local line = pandoc.Inlines{ pandoc.Strong(name) }
      if #affil > 0 then
        line:insert(pandoc.Str(" ("))
        line:extend(affil)
        line:insert(pandoc.Str(")"))
      end
      table.insert(items, { pandoc.Plain(line) })
    end
  end
  return pandoc.Div({ pandoc.BulletList(items) }, div.attr)
end

return {
  { Div = function(d)
      if d.classes:includes("people") then return people(d) end
    end },
}
