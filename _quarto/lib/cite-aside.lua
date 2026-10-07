-- cite-aside.lua : スライドで引用した文献の書誌を，そのスライドの下端 (脚注と同じ aside) に出す
--
-- 本文の引用 [@key] / @key (org では [cite:@key] / [cite/t:@key]) は，CSL の書式どおり
-- (Raissi et al., 2019) などと出る．このフィルタは加えて，各スライドで引用された文献の
-- 完全な書誌 (著者・題名・誌名) を，そのスライドの脚注欄に並べる．doi / url は表示せず，
-- 書誌全体をそのリンクにする (クリックすると新しいタブ・ウィンドウで開く)．
-- 書誌全体は ::: {#refs} ::: を置いたスライド (参考文献) に citeproc が出す．
--
-- 調整:
--   メタデータ cite-aside: false        すべてのスライドで出さない
--   メタデータ cite-aside-max: 3        1 枚で引用がこれより多いスライドでは出さない (既定 3)
--   見出し {.no-cite-aside}             そのスライドだけ出さない
--   見出し {.cite-aside}                cite-aside-max を超えても出す
-- 発表者ノート (::: notes) の中の引用は数えない．書式は SCSS の .cite-ref (oerreveal.scss)．

local function meta_bool(v, default)
  if v == nil then return default end
  if type(v) == "boolean" then return v end
  local s = pandoc.utils.stringify(v)
  return not (s == "false" or s == "no" or s == "0")
end

-- 書誌の doi / url を本文から外し，書誌全体をそのリンクにする (新しいタブで開く)
local function linkify(blocks)
  local target = nil
  local stripped = pandoc.Blocks(blocks):walk({ Link = function(l)
    target = target or l.target
    return {}
  end })
  if not target then return stripped end
  return stripped:walk({ Para = function(p)
    local inl = p.content
    while #inl > 0 and (inl[#inl].t == "Space" or inl[#inl].t == "SoftBreak") do inl:remove(#inl) end
    return pandoc.Para({ pandoc.Link(inl, target, "",
      pandoc.Attr("", { "cite-link" }, { target = "_blank", rel = "noopener" })) })
  end })
end

-- Quarto の相互参照の接頭辞
local xref_prefix = { "fig", "tbl", "eq", "sec", "lst", "thm", "lem", "cor", "prp", "cnj",
                      "def", "exm", "exr", "sol", "rem", "alg" }
local function is_xref(id)
  for _, p in ipairs(xref_prefix) do
    if id:sub(1, #p + 1) == p .. "-" then return true end
  end
  return false
end

function Pandoc(doc)
  if not quarto.doc.is_format("revealjs") then return nil end
  if not meta_bool(doc.meta["cite-aside"], true) then return nil end
  local max = tonumber(pandoc.utils.stringify(doc.meta["cite-aside-max"] or "3")) or 3
  local slide_level = (PANDOC_WRITER_OPTIONS and PANDOC_WRITER_OPTIONS.slide_level) or 2

  -- 書誌を作る (本文と同じ bibliography / csl で citeproc を一度走らせ，csl-entry を拾う)
  -- 相互参照 (@fig-x，@tbl-x など) は文献ではないので渡さない (citeproc の "not found" 警告を避ける)
  local cites = {}
  pandoc.Blocks(doc.blocks):walk({ Cite = function(c)
    for _, ci in ipairs(c.citations) do
      if not is_xref(ci.id) then table.insert(cites, pandoc.Cite({}, { ci })) end
    end
  end })
  if #cites == 0 then return nil end
  local ok, cdoc = pcall(pandoc.utils.citeproc, pandoc.Pandoc({ pandoc.Para(cites) }, doc.meta))
  if not ok then
    io.stderr:write("cite-aside.lua: citeproc failed: " .. tostring(cdoc) .. "\n")
    return nil
  end
  local refs = {}
  cdoc:walk({ Div = function(d)
    if d.classes:includes("csl-entry") then refs[(d.identifier:gsub("^ref%-", ""))] = d end
  end })

  local out, keys, seen, hdr = {}, {}, {}, nil
  local function flush()
    if #keys > 0 and hdr ~= nil and not hdr.classes:includes("no-cite-aside")
       and (#keys <= max or hdr.classes:includes("cite-aside")) then
      local items = {}
      for _, k in ipairs(keys) do
        if refs[k] then table.insert(items, pandoc.Div(linkify(refs[k].content), pandoc.Attr("", { "cite-ref" }))) end
      end
      if #items > 0 then table.insert(out, pandoc.Div(items, pandoc.Attr("", { "aside" }))) end
    end
    keys, seen = {}, {}
  end
  local skip = { Div = function(d)
    if d.classes:includes("notes") or d.identifier == "refs" then return {} end
  end }
  for _, b in ipairs(doc.blocks) do
    if (b.t == "Header" and b.level <= slide_level) or b.t == "HorizontalRule" then
      flush()
      if b.t == "Header" then hdr = b end
    end
    local is_skipped = b.t == "Div" and (b.classes:includes("notes") or b.identifier == "refs")
    local bb = is_skipped and pandoc.Div({}) or pandoc.walk_block(b, skip)
    pandoc.walk_block(bb, { Cite = function(c)
      for _, ci in ipairs(c.citations) do
        if not seen[ci.id] then seen[ci.id] = true; table.insert(keys, ci.id) end
      end
    end })
    table.insert(out, b)
  end
  flush()
  doc.blocks = out
  return doc
end
