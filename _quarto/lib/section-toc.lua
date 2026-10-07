-- section-toc.lua : 節の一覧 (梗概と節扉) を自動で作る
--
-- 第 1 階層の見出し (# / org の *) を節とみなし，
--   * {.overview} の付いた見出しのスライドには，全節の題と summary 属性を箇条書きで並べる (梗概)
--   * 各節の見出しのスライド (節扉) には，全節の題を並べ，その節だけを .toc-current にする
-- 色と大きさは _quarto/scss/section-toc.scss．org での書き方:
--   * 講演の流れ                     * フィジカルAI
--   :PROPERTIES:                     :PROPERTIES:
--   :QUARTO_ATTR: {.overview}        :QUARTO_ATTR: {summary="現実世界で動く AI と…"}
--   :END:                            :END:
-- 節扉に一覧を出したくない節は {.no-toc}．一覧から外したい節は {.toc-skip}．
-- 梗概と節扉は見出しを {.notitle} で隠し一覧だけを出す (見出しはメニュー等のために残る)．
-- 節扉で見出しも出したいときは {.show-title}．
-- 節扉の背景は theme の --oer-section-bg (oerreveal では表紙の色を少し明るくした暗色)．地色のままにするなら {.light}．

local function is_html()
  return quarto.doc.is_format("revealjs") or quarto.doc.is_format("html")
end

function Pandoc(doc)
  if not is_html() then return nil end
  local secs = {}
  for _, b in ipairs(doc.blocks) do
    if b.t == "Header" and b.level == 1 and not b.classes:includes("overview")
       and not b.classes:includes("toc-skip") then
      table.insert(secs, { id = b.identifier, title = b.content, summary = b.attributes["summary"] })
    end
  end
  if #secs == 0 then return nil end

  local function toc(current)
    local items = {}
    for _, s in ipairs(secs) do
      local cls = (s.id == current) and "toc-current" or "toc-other"
      table.insert(items, { pandoc.Plain({ pandoc.Span(s.title, pandoc.Attr("", { cls })) }) })
    end
    return pandoc.Div({ pandoc.BulletList(items) }, pandoc.Attr("", { "section-toc" }))
  end

  local function overview()
    local items = {}
    for _, s in ipairs(secs) do
      local inl = { pandoc.Strong(s.title) }
      if s.summary and s.summary ~= "" then
        table.insert(inl, pandoc.LineBreak())
        table.insert(inl, pandoc.Span({ pandoc.Str(s.summary) }, pandoc.Attr("", { "toc-summary" })))
      end
      table.insert(items, { pandoc.Plain(inl) })
    end
    return pandoc.Div({ pandoc.BulletList(items) }, pandoc.Attr("", { "section-overview" }))
  end

  local out = {}
  for _, b in ipairs(doc.blocks) do
    table.insert(out, b)
    if b.t == "Header" and b.level == 1 then
      b.attributes["summary"] = nil
      if b.classes:includes("overview") then
        if not b.classes:includes("notitle") then b.classes:insert("notitle") end
        table.insert(out, overview())
      elseif not b.classes:includes("no-toc") and not b.classes:includes("toc-skip") then
        if not b.classes:includes("show-title") and not b.classes:includes("notitle") then
          b.classes:insert("notitle")
        end
        table.insert(out, toc(b.identifier))
        -- 節扉の背景 (色は theme の --oer-section-bg．未定義なら通常の地色のまま)
        if not b.attributes["background-color"] and not b.classes:includes("light") then
          b.attributes["background-color"] = "var(--oer-section-bg)"
        end
      end
    end
  end
  doc.blocks = out
  return doc
end
