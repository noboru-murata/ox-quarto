-- cite-margin.lua — Tufte 形式 (handout / note) の文献: 引用した段落の横の余白に書誌，文書の最後に参考文献の一覧 (2026-11-23)
--
-- Quarto の citation-location: margin は余白に書誌を出すが，最後の一覧を作らない (::: {#refs} も空)．
-- このフィルタは citation-location を document のまま (yaml で margin にしない) で，自分で書誌を作って
--   - 引用のある段落の後ろに ::: {.column-margin} (その段落で引いた文献の書誌．LaTeX は余白の注，html / typst も余白)
--   - 文書の最後 (::: {#refs} があればそこ) に見出し「参考文献」(language の section-title-references) と一覧
-- を置き，pandoc の citeproc の一覧は suppress-bibliography で止める．脚注の中の引用は余白に重ねない (一覧には入る)．
--
-- 和文の著者 (2026-11-23): 著者が全員和文の名の文献は，和文の慣習に近い形にする．
--   本文     (山田・鈴木, 2025)，3 名以上は (山田他, 2025)       ← 文献の著者を literal「山田・鈴木」にして pandoc の citeproc に渡す
--   書誌     山田 太郎・鈴木 花子 (2025). 題. 誌名, 巻, 頁.        ← 書誌を作るときは literal「山田 太郎・鈴木 花子」
-- (APA の csl のままだと書誌が「山田太郎., & 鈴木花子. (2025).」になる．CSL では名ごとに書き分けられない．)
-- 欧文と和文が混じる文献，欧文だけの文献はそのまま．
--
-- 使う yaml: handout-latex，handout-typst，note (filters で cjk-names.lua と title-block.lua の後．citation-location は書かない)．
-- typst は citeproc: true (pandoc の citeproc．typst の内蔵の文献処理だと最後の一覧が二重になる)．
-- 調整: front matter の cite-margin: false で何もしない (Quarto の余白の書誌に戻すなら citation-location: margin も書く)．
--       cite-margin-list: false で最後の一覧を出さない．cite-margin-cjk: false で和文の著者をそのまま．
-- 書誌の書式は front matter の csl (無ければ _quarto/csl/apa.csl．typst の版は csl を html だけに置くので)．

local function meta_bool(v, default)
  if v == nil then return default end
  if type(v) == 'boolean' then return v end
  local s = pandoc.utils.stringify(v)
  return not (s == 'false' or s == 'no' or s == '0')
end

local xref_prefix = { 'fig', 'tbl', 'eq', 'sec', 'lst', 'thm', 'lem', 'cor', 'prp', 'cnj',
                      'def', 'exm', 'exr', 'sol', 'rem', 'alg' }
local function is_xref(id)
  for _, p in ipairs(xref_prefix) do
    if id:sub(1, #p + 1) == p .. '-' then return true end
  end
  return false
end

-- 和文の名 (cjk-names.lua と同じ判定)
local CJK = { { 0x3040, 0x30FF }, { 0x3400, 0x4DBF }, { 0x4E00, 0x9FFF }, { 0xF900, 0xFAFF }, { 0x20000, 0x2FFFF } }
local function str(v)
  if v == nil then return '' end
  if type(v) == 'string' then return v end
  return pandoc.utils.stringify(v)
end
local function has_cjk(s)
  for _, c in utf8.codes(str(s)) do
    for _, r in ipairs(CJK) do
      if c >= r[1] and c <= r[2] then return true end
    end
  end
  return false
end
local function cjk_name(n)
  if n.literal then return has_cjk(n.literal) end
  return has_cjk(n.family) or has_cjk(n.given)
end
local function all_cjk(names)
  if type(names) ~= 'table' or #names == 0 then return false end
  for _, n in ipairs(names) do
    if not cjk_name(n) then return false end
  end
  return true
end
local function family_of(n) return n.literal and str(n.literal) or str(n.family) end
local function full_of(n)
  if n.literal then return str(n.literal) end
  local g = str(n.given)
  return str(n.family) .. (g ~= '' and (' ' .. g) or '')
end

-- 和文の著者の文献を 2 通りに書き換えた複製 (本文用と書誌用)
local ROLES = { 'author', 'editor', 'translator' }
local function cjk_copies(refs)
  local intext, biblio, cjk_ids = {}, {}, {}
  for _, r in ipairs(refs) do
    local a, b = {}, {}
    for k, v in pairs(r) do a[k] = v; b[k] = v end
    local hit = false
    for _, role in ipairs(ROLES) do
      local names = r[role]
      if all_cjk(names) then
        hit = true
        local fam, full = {}, {}
        for _, n in ipairs(names) do
          table.insert(fam, family_of(n)); table.insert(full, full_of(n))
        end
        local short = (#fam >= 3) and (fam[1] .. '他') or table.concat(fam, '・')
        a[role] = { { literal = short } }
        b[role] = { { literal = table.concat(full, '・') } }
      end
    end
    if hit then cjk_ids[r.id] = true end
    table.insert(intext, a); table.insert(biblio, b)
  end
  return intext, biblio, cjk_ids
end

-- 書誌の「山田 太郎・鈴木 花子. (2025).」の著者の後ろの . を外す (和文の慣習: 著者 (年).)
local function drop_author_period(blocks)
  local done = false
  return pandoc.Blocks(blocks):walk({ Inlines = function(il)
    if done then return nil end
    for i = 1, #il - 2 do
      local a, b, c = il[i], il[i + 1], il[i + 2]
      if a.t == 'Str' and a.text:sub(-1) == '.' and b.t == 'Space' and c.t == 'Str' and c.text:sub(1, 1) == '(' then
        a.text = a.text:sub(1, -2)
        done = true
        return il
      end
    end
  end })
end

local function script_dir()
  local src = debug.getinfo(1, 'S').source:gsub('^@', '')
  return src:match('(.*)/') or '.'
end

-- 段落の中の引用 (脚注の中は除く) の文献のキー
local function cited_keys(inlines)
  local keys, seen = {}, {}
  local function scan(il)
    for _, x in ipairs(il) do
      if x.t == 'Cite' then
        for _, ci in ipairs(x.citations) do
          if not is_xref(ci.id) and not seen[ci.id] then seen[ci.id] = true; table.insert(keys, ci.id) end
        end
      elseif x.t ~= 'Note' and x.content and type(x.content) == 'table' and x.t ~= 'Math' then
        if pandoc.utils.type(x.content) == 'Inlines' then scan(x.content) end
      end
    end
  end
  scan(inlines)
  return keys
end

local function fmt_entry_inline_start(fmt)
  if fmt == 'latex' then return pandoc.RawInline('latex', '\\noindent\\hangindent=1.5em\\hangafter=1 ') end
  return nil
end

function Pandoc(doc)
  local meta = doc.meta
  if not meta_bool(meta['cite-margin'], true) then return nil end
  if quarto.doc.is_format('revealjs') then return nil end
  if not (meta.bibliography or meta.references) then return nil end
  local ok, refs = pcall(pandoc.utils.references, doc)
  if not ok or not refs or #refs == 0 then return nil end

  -- 引用された文献 (出てきた順．脚注の中も含む)
  local all, seen = {}, {}
  pandoc.Blocks(doc.blocks):walk({ Cite = function(c)
    for _, ci in ipairs(c.citations) do
      if not is_xref(ci.id) and not seen[ci.id] then seen[ci.id] = true; table.insert(all, ci.id) end
    end
  end })
  if #all == 0 then return nil end

  local cjk = meta_bool(meta['cite-margin-cjk'], true)
  local intext, biblio, cjk_ids = refs, refs, {}
  if cjk then intext, biblio, cjk_ids = cjk_copies(refs) end

  -- 書誌を作る (一覧の順は csl の並べ方)
  local bmeta = pandoc.Meta({})
  for k, v in pairs(meta) do bmeta[k] = v end
  bmeta.references = biblio
  bmeta.bibliography = nil
  bmeta['suppress-bibliography'] = false
  if not bmeta.csl then bmeta.csl = script_dir() .. '/../csl/apa.csl' end
  local cites = {}
  for _, id in ipairs(all) do table.insert(cites, pandoc.Cite({}, { pandoc.Citation(id, 'NormalCitation') })) end
  local cok, cdoc = pcall(pandoc.utils.citeproc, pandoc.Pandoc({ pandoc.Para(cites) }, bmeta))
  if not cok then
    io.stderr:write('cite-margin.lua: citeproc failed: ' .. tostring(cdoc) .. '\n')
    return nil
  end
  local entry, order = {}, {}
  cdoc:walk({ Div = function(d)
    if d.classes:includes('csl-entry') then
      local id = d.identifier:gsub('^ref%-', '')
      -- 番号式の csl の [1] などの枠 (csl-left-margin / csl-right-inline …) を外す．一覧を pandoc に作らせないので，
      -- LaTeX の \CSLLeftMargin などが定義されず止まるため
      local blocks = pandoc.Blocks(d.content):walk({
        Span = function(sp)
          for _, c in ipairs(sp.classes) do
            if c == 'csl-left-margin' then
              local il = pandoc.Inlines(sp.content); il:insert(pandoc.Space()); return il
            elseif c:match('^csl%-') then return sp.content end
          end
        end,
        Div = function(dv)
          for _, c in ipairs(dv.classes) do
            if c:match('^csl%-') then return dv.content end
          end
        end })
      if cjk_ids[id] then blocks = drop_author_period(blocks) end
      entry[id] = blocks
      table.insert(order, id)
    end
  end })

  local fmt = quarto.doc.is_format('latex') and 'latex' or (quarto.doc.is_format('typst') and 'typst' or 'html')
  local function entry_blocks(id, small)
    local out = pandoc.Blocks({})
    for _, b in ipairs(entry[id] or {}) do
      if (b.t == 'Para' or b.t == 'Plain') then
        local il = pandoc.Inlines({})
        if fmt == 'latex' and small then il:insert(pandoc.RawInline('latex', '{\\footnotesize ')) end
        if not small then
          local s = fmt_entry_inline_start(fmt); if s then il:insert(s) end
        end
        il:extend(b.content)
        if fmt == 'latex' and small then il:insert(pandoc.RawInline('latex', '\\par\\vspace{3pt}}')) end
        out:insert(pandoc.Para(il))
      else
        out:insert(b)
      end
    end
    return out
  end

  -- 引用のある段落の後ろに余白の書誌
  local function margin_for(keys)
    local bl = pandoc.Blocks({})
    for _, k in ipairs(keys) do
      if entry[k] then bl:extend(entry_blocks(k, true)) end
    end
    if #bl == 0 then return nil end
    return pandoc.Div(bl, pandoc.Attr('', { 'column-margin', 'cite-margin' }))
  end
  local function process(blocks)
    local out = pandoc.Blocks({})
    for _, b in ipairs(blocks) do
      if b.t == 'Para' or b.t == 'Plain' then
        out:insert(b)
        local m = margin_for(cited_keys(b.content))
        if m then out:insert(m) end
      elseif b.t == 'Div' then
        if not b.classes:includes('column-margin') and b.identifier ~= 'refs' then b.content = process(b.content) end
        out:insert(b)
      elseif b.t == 'BlockQuote' then
        b.content = process(b.content); out:insert(b)
      elseif b.t == 'BulletList' or b.t == 'OrderedList' then
        for i, item in ipairs(b.content) do b.content[i] = process(item) end
        out:insert(b)
      else
        out:insert(b)
      end
    end
    return out
  end
  doc.blocks = process(doc.blocks)

  -- 最後の一覧
  if meta_bool(meta['cite-margin-list'], true) then
    local list = pandoc.Blocks({})
    for _, id in ipairs(order) do
      local eb = entry_blocks(id, false)
      if fmt == 'html' then
        list:insert(pandoc.Div(eb, pandoc.Attr('', { 'cite-margin-entry' },
          { style = 'padding-left: 1.5em; text-indent: -1.5em; margin-bottom: 0.4em;' })))
      elseif fmt == 'typst' then
        list:insert(pandoc.RawBlock('typst', '#par(hanging-indent: 1.5em)['))
        list:extend(eb)
        list:insert(pandoc.RawBlock('typst', ']'))
      else
        list:extend(eb)
      end
    end
    local title = '参考文献'
    if meta.language and meta.language['section-title-references'] then
      title = pandoc.utils.stringify(meta.language['section-title-references'])
    end
    local placed = false
    doc.blocks = doc.blocks:walk({ Div = function(d)
      if d.identifier == 'refs' then
        placed = true
        return pandoc.Div(list, pandoc.Attr('', { 'cite-margin-list' }))
      end
    end })
    if not placed then
      doc.blocks:insert(pandoc.Header(1, pandoc.Inlines(title), pandoc.Attr('cite-margin-references', { 'unnumbered' })))
      doc.blocks:insert(pandoc.Div(list, pandoc.Attr('', { 'cite-margin-list' })))
    end
  end

  -- 本文の引用は pandoc の citeproc (和文の著者は「山田・鈴木」)．一覧は出さない
  meta.references = intext
  meta.bibliography = nil
  meta['suppress-bibliography'] = true
  if not meta.csl then meta.csl = bmeta.csl end
  doc.meta = meta
  return doc
end
