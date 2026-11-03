-- title-block.lua — 解説文 (report) の表題を紀要の形にする (2026-11-03)
--
--                          題
--         和文の所属 (複数行可)　氏名*
--                英文の氏名 (例 Noboru MURATA)
--                英文の所属
--   ----
--   *連絡先 (メール)
--
-- org の書き方 (ox-quarto-ext-theme.el が front matter に書き出す):
--   #+AUTHOR: 氏名            → author:
--   #+INSTITUTE: 和文の所属   → institute: (行を重ねれば複数行)
--   #+EMAIL: メール           → oxq-email: (氏名に付く脚注 *)
--   #+AUTHOR_EN: 英文の氏名   → oxq-author-en:
--   #+INSTITUTE_EN: 英文の所属 → oxq-institute-en: (行を重ねれば複数行)
-- institute / oxq-email / oxq-author-en / oxq-institute-en のどれも無ければ何もしない (今までの表題のまま)．
--
-- 形式ごと:
--   LaTeX  \AtBeginDocument{\author{…}} で \maketitle の著者の欄を置き換える．メールは \thanks (印は *)．
--   html   Quarto の表題の著者を外し，表題の下に中央寄せの段落を置く．メールは脚注．
--          概要 (abstract) は表題の欄に入るので，著者の後ろに移す (題は language の section-title-abstract)．
--   typst  html と同じく著者と概要を外し，#align(center) の段落と #footnote(numbering: "*") を置く．
-- revealjs など他の形式では何もしない．

local function list_of(v)
  if v == nil then return {} end
  local t = pandoc.utils.type(v)
  if t == 'List' then
    local out = {}
    for _, x in ipairs(v) do table.insert(out, x) end
    return out
  end
  return { v }
end

local function inlines(v)
  -- メタの値 (Inlines / 文字列 / 著者の表) を Inlines に
  local t = pandoc.utils.type(v)
  if t == 'Inlines' then return v end
  if t == 'Blocks' then return pandoc.utils.blocks_to_inlines(v) end
  if t == 'table' or t == 'Meta' then
    if v.name then return inlines(v.name) end
    if v.literal then return inlines(v.literal) end
  end
  return pandoc.Inlines(pandoc.utils.stringify(v))
end

local function author_inlines(meta)
  local names = {}
  for _, a in ipairs(list_of(meta.author)) do
    local il = inlines(a)
    if #names > 0 then table.insert(names, pandoc.Str('，')) end
    for _, x in ipairs(il) do table.insert(names, x) end
  end
  return pandoc.Inlines(names)
end

local function to_fmt(il, fmt)
  local s = pandoc.write(pandoc.Pandoc({ pandoc.Plain(il) }), fmt)
  return (s:gsub('%s+$', ''))
end

local function abstract_title(meta)
  local lang = meta.language
  if lang and lang['section-title-abstract'] then
    return pandoc.utils.stringify(lang['section-title-abstract'])
  end
  return '概要'
end

function Pandoc(doc)
  local meta = doc.meta
  local inst = list_of(meta.institute)
  local email = meta['oxq-email']
  local name_en = meta['oxq-author-en']
  local inst_en = list_of(meta['oxq-institute-en'])
  if #inst == 0 and not email and not name_en and #inst_en == 0 then return nil end
  local name = author_inlines(meta)

  if quarto.doc.is_format('latex') then
    local lines = {}
    for i, x in ipairs(inst) do
      if i < #inst then table.insert(lines, to_fmt(inlines(x), 'latex')) end
    end
    local last = ''
    if #inst > 0 then last = to_fmt(inlines(inst[#inst]), 'latex') .. '\\quad ' end
    last = last .. to_fmt(name, 'latex')
    if email then last = last .. '\\thanks{' .. to_fmt(inlines(email), 'latex') .. '}' end
    table.insert(lines, last)
    if name_en then table.insert(lines, to_fmt(inlines(name_en), 'latex')) end
    for _, x in ipairs(inst_en) do table.insert(lines, to_fmt(inlines(x), 'latex')) end
    local tex = '\\AtBeginDocument{\\author{' .. table.concat(lines, ' \\\\ ') .. '}}'
    local hi = meta['header-includes']
    if hi == nil then hi = pandoc.MetaList({})
    elseif pandoc.utils.type(hi) ~= 'List' then hi = pandoc.MetaList({ hi }) end
    hi:insert(pandoc.MetaBlocks({ pandoc.RawBlock('latex', tex) }))
    meta['header-includes'] = hi
    doc.meta = meta
    return doc
  end

  local html = quarto.doc.is_format('html')
  local typst = quarto.doc.is_format('typst')
  if not (html or typst) then return nil end

  local blocks = pandoc.Blocks({})
  if typst then
    local lines = {}
    for i, x in ipairs(inst) do
      if i < #inst then table.insert(lines, to_fmt(inlines(x), 'typst')) end
    end
    local last = ''
    if #inst > 0 then last = to_fmt(inlines(inst[#inst]), 'typst') .. '#h(1em)' end
    last = last .. to_fmt(name, 'typst')
    if email then last = last .. '#footnote(numbering: "*")[' .. to_fmt(inlines(email), 'typst') .. ']' end
    table.insert(lines, last)
    if name_en then table.insert(lines, to_fmt(inlines(name_en), 'typst')) end
    for _, x in ipairs(inst_en) do table.insert(lines, to_fmt(inlines(x), 'typst')) end
    blocks:insert(pandoc.RawBlock('typst', '#align(center)[\n' .. table.concat(lines, ' \\\n') .. '\n]\n#v(1em)'))
  else
    -- 行は 1 つの段落の中の改行で (段落を分けると行の間が空きすぎる)．題も中央に揃える
    local lines = {}
    for i, x in ipairs(inst) do
      if i < #inst then table.insert(lines, inlines(x)) end
    end
    local last = pandoc.Inlines({})
    if #inst > 0 then last:extend(inlines(inst[#inst])); last:insert(pandoc.Str('\u{3000}')) end
    last:extend(name)
    if email then last:insert(pandoc.Note({ pandoc.Plain(inlines(email)) })) end
    table.insert(lines, last)
    if name_en then table.insert(lines, inlines(name_en)) end
    for _, x in ipairs(inst_en) do table.insert(lines, inlines(x)) end
    local para = pandoc.Inlines({})
    for i, l in ipairs(lines) do
      if i > 1 then para:insert(pandoc.LineBreak()) end
      para:extend(l)
    end
    blocks:insert(pandoc.RawBlock('html',
      '<style>#title-block-header .title { text-align: center; }\n' ..
      '.oxq-abstract .block-title { font-weight: bold; }</style>'))
    blocks:insert(pandoc.Div({ pandoc.Para(para) }, pandoc.Attr('', { 'oxq-title-authors' },
      { style = 'text-align: center; margin-bottom: 1.5em;' })))
  end

  local abstract = meta.abstract
  if abstract then
    local ab = pandoc.utils.type(abstract) == 'Blocks' and abstract
      or pandoc.Blocks({ pandoc.Para(inlines(abstract)) })
    if typst then
      blocks:insert(pandoc.RawBlock('typst', '#block(inset: (x: 2em))[\n*' .. abstract_title(meta) .. '*#h(1em)'))
      blocks:extend(ab)
      blocks:insert(pandoc.RawBlock('typst', ']\n#v(1em)'))
    else
      local inner = pandoc.Blocks({ pandoc.Div({ pandoc.Plain(abstract_title(meta)) }, pandoc.Attr('', { 'block-title' })) })
      inner:extend(ab)
      blocks:insert(pandoc.Div(inner, pandoc.Attr('', { 'abstract', 'oxq-abstract' })))
    end
    meta.abstract = nil
  end
  -- Quarto は user filter の前に著者を authors / by-author / by-affiliation にも整えているので，それも外す
  for _, k in ipairs({ 'author', 'authors', 'by-author', 'by-affiliation', 'affiliations', 'institute' }) do
    meta[k] = nil
  end
  doc.meta = meta
  doc.blocks = blocks .. doc.blocks
  return doc
end
