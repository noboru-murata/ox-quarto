-- cite-margin.lua — Tufte 形式 (handout / note) の右の余白に，引いた文献の短い書誌を置く (2026-11-23)
--
-- 本文の引用と文書の最後の参考文献の一覧は Quarto (pandoc の citeproc) に任せる (citation-location: document．
-- 引用は一覧へのリンクになる)．このフィルタは余白だけを作る: 引用のある段落の後ろに ::: {.column-margin} を置き，
-- その段落で引いた文献を
--     著者 (年). 題. 誌名・会議名・出版社.
-- の短い形で並べる (巻・頁・DOI は一覧で見る)．脚注の中の引用は余白に重ねない．
--   著者: 1 名 Tufte，2 名 Xie & Allaire，3 名以上 Xie et al.．著者が全員和文の名なら 山田・鈴木，3 名以上 山田他．
--         著者が無ければ編者．literal の名はそのまま．
--   誌名: container-title (雑誌・会議の論文集・本の章の本)，無ければ publisher (本)，無ければ書かない．
-- 書誌の中身は bibliography / references から直接読む (csl は使わない．番号式の csl でも余白は著者と年)．
--
-- 文書に ::: {#refs} が無ければ，PDF (LaTeX / typst) では最後に見出し「参考文献」(language の section-title-references) と
-- ::: {#refs} を足す (html は Quarto が付録の「参考文献」に置く)．
--
-- 使う yaml: handout-latex，handout-typst，note (filters．citation-location: margin は書かない)．
-- 調整: front matter の cite-margin: false で余白に置かない．cite-margin-heading: false で見出しと #refs を足さない．

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

local function short_names(names)
  if type(names) ~= 'table' or #names == 0 then return nil end
  local fam = {}
  local all_cjk = true
  for _, n in ipairs(names) do
    table.insert(fam, n.literal and str(n.literal) or str(n.family))
    if not cjk_name(n) then all_cjk = false end
  end
  if all_cjk then
    return (#fam >= 3) and (fam[1] .. '他') or table.concat(fam, '・')
  end
  if #fam == 1 then return fam[1] end
  if #fam == 2 then return fam[1] .. ' & ' .. fam[2] end
  return fam[1] .. ' et al.'
end

local function year_of(r)
  local d = r.issued
  if type(d) == 'table' then
    local dp = d['date-parts']
    if dp and dp[1] and dp[1][1] then return tostring(dp[1][1]) end
    if d.literal then return str(d.literal) end
  end
  return 'n.d.'
end

local function as_inlines(v)
  if v == nil then return nil end
  if pandoc.utils.type(v) == 'Inlines' then return v end
  local s = str(v)
  if s == '' then return nil end
  return pandoc.Inlines(s)
end

-- 1 つの文献の短い書誌 (Inlines)
local function short_entry(r)
  local il = pandoc.Inlines({})
  local who = short_names(r.author) or short_names(r.editor)
  if who then il:insert(pandoc.Str(who)); il:insert(pandoc.Space()) end
  il:insert(pandoc.Str('(' .. year_of(r) .. ').'))
  local title = as_inlines(r.title)
  if title then
    il:insert(pandoc.Space()); il:extend(title)
    local last = pandoc.utils.stringify(title)
    if not last:match('[%.%?!．？！]$') then il:insert(pandoc.Str('.')) end
  end
  local venue = as_inlines(r['container-title']) or as_inlines(r.publisher)
  if venue then
    il:insert(pandoc.Space()); il:insert(pandoc.Emph(venue)); il:insert(pandoc.Str('.'))
  end
  return il
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
      elseif x.t ~= 'Note' and x.content and pandoc.utils.type(x.content) == 'Inlines' then
        scan(x.content)
      end
    end
  end
  scan(inlines)
  return keys
end

function Pandoc(doc)
  local meta = doc.meta
  if quarto.doc.is_format('revealjs') then return nil end
  if not (meta.bibliography or meta.references) then return nil end
  local ok, refs = pcall(pandoc.utils.references, doc)
  if not ok or not refs or #refs == 0 then return nil end
  local byid = {}
  for _, r in ipairs(refs) do byid[r.id] = r end
  local latex = quarto.doc.is_format('latex')

  if meta_bool(meta['cite-margin'], true) then
    local function margin_for(keys)
      local bl = pandoc.Blocks({})
      for _, k in ipairs(keys) do
        local r = byid[k]
        if r then
          local il = short_entry(r)
          if latex then
            il:insert(1, pandoc.RawInline('latex', '{\\footnotesize '))
            il:insert(pandoc.RawInline('latex', '\\par\\vspace{3pt}}'))
          end
          bl:insert(pandoc.Para(il))
        end
      end
      if #bl == 0 then return nil end
      -- typst の余白は両端揃えで，狭い幅では和文の字間が開くので左揃えに (この余白の中だけ)
      if quarto.doc.is_format('typst') then bl:insert(1, pandoc.RawBlock('typst', '#set par(justify: false)')) end
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
  end

  -- PDF では最後に見出しと #refs (文書に #refs が無いとき)
  if (latex or quarto.doc.is_format('typst')) and meta_bool(meta['cite-margin-heading'], true) then
    local has_refs = false
    doc.blocks:walk({ Div = function(d) if d.identifier == 'refs' then has_refs = true end end })
    if not has_refs then
      local title = '参考文献'
      if meta.language and meta.language['section-title-references'] then
        title = pandoc.utils.stringify(meta.language['section-title-references'])
      end
      doc.blocks:insert(pandoc.Header(1, pandoc.Inlines(title), pandoc.Attr('', { 'unnumbered' })))
      doc.blocks:insert(pandoc.Div({}, pandoc.Attr('refs')))
    end
  end
  return doc
end
