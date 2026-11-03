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
--   #+AUTHOR: 氏名            → author:  (共著は「氏名1 \and 氏名2」→ author: のリスト)
--   #+INSTITUTE: 和文の所属   → institute: (行を重ねれば複数行．共著なら著者の順に 1 行ずつ．1 人の所属が複数なら「，」でつなぐ)
--   #+EMAIL: メール           → oxq-email: (氏名に付く脚注 *．1 人目の著者に．「2:メール」なら 2 人目に)
--   #+AUTHOR_EN: 英文の氏名   → oxq-author-en: (行を重ねれば and でつなぐ)
--   #+INSTITUTE_EN: 英文の所属 → oxq-institute-en: (行を重ねれば複数行)
-- 共著 (2026-11-03): 著者が 2 人以上なら和文の部分は「所属 (右寄せ)　氏名 (左寄せ)」の表 (著者ごとの行)，
-- その下に英文の氏名 (and でつなぐ) と英文の所属の行．
-- institute / oxq-email / oxq-author-en / oxq-institute-en のどれも無ければ何もしない (今までの表題のまま)．
--
-- 形式ごと:
--   LaTeX  \AtBeginDocument{\author{…}} で \maketitle の著者の欄を置き換える．メールは \thanks (印は *)．
--   html   Quarto の表題の著者を外し，表題の下に中央寄せの段落を置く．メールは氏名に * を付け，最後に「* メール」の行．
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

local function author_list(meta)
  local out = {}
  for _, a in ipairs(list_of(meta.author)) do table.insert(out, inlines(a)) end
  return out
end

-- #+EMAIL: mail  (1 人目の著者に) / #+EMAIL: 2:mail (2 人目に)
local function parse_email(v)
  if not v then return nil, nil end
  local s = pandoc.utils.stringify(v)
  local n, rest = s:match('^%s*(%d+)%s*:%s*(.+)$')
  if n then return tonumber(n), pandoc.Inlines(rest) end
  return 1, inlines(v)
end

local function join_and(list)
  local out = pandoc.Inlines({})
  for i, x in ipairs(list) do
    if i > 1 then out:extend({ pandoc.Space(), pandoc.Str('and'), pandoc.Space() }) end
    out:extend(inlines(x))
  end
  return out
end

function Pandoc(doc)
  local meta = doc.meta
  local inst = list_of(meta.institute)
  local email_idx, email = parse_email(meta['oxq-email'])
  local names_en = list_of(meta['oxq-author-en'])
  local inst_en = list_of(meta['oxq-institute-en'])
  if #inst == 0 and not email and #names_en == 0 and #inst_en == 0 then return nil end
  local authors = author_list(meta)

  -- 和文の部分: pre (所属だけの行．著者 1 人で所属が複数行のとき) と rows (所属と氏名の組)
  local pre, rows = {}, {}
  if #authors <= 1 then
    for i, x in ipairs(inst) do
      if i < #inst then table.insert(pre, inlines(x)) end
    end
    table.insert(rows, { aff = #inst > 0 and inlines(inst[#inst]) or nil,
                         name = authors[1] or pandoc.Inlines({}), email = email })
  else
    for i, nm in ipairs(authors) do
      table.insert(rows, { aff = inst[i] and inlines(inst[i]) or nil, name = nm,
                           email = (email_idx == i) and email or nil })
    end
  end
  -- 英文の部分: 氏名 (複数なら and でつなぐ) と所属の行
  local post = {}
  if #names_en > 0 then table.insert(post, join_and(names_en)) end
  for _, x in ipairs(inst_en) do table.insert(post, inlines(x)) end
  local multi = #rows > 1

  if quarto.doc.is_format('latex') then
    local function nm(r)
      local t = to_fmt(r.name, 'latex')
      if r.email then t = t .. '\\thanks{' .. to_fmt(r.email, 'latex') .. '}' end
      return t
    end
    local lines = {}
    for _, x in ipairs(pre) do table.insert(lines, to_fmt(x, 'latex')) end
    if multi then
      local cells = {}
      for _, r in ipairs(rows) do
        table.insert(cells, (r.aff and to_fmt(r.aff, 'latex') or '') .. ' & ' .. nm(r))
      end
      table.insert(lines, '\\begin{tabular}[t]{@{}r@{\\quad}l@{}}' .. table.concat(cells, ' \\\\ ') .. '\\end{tabular}')
    else
      local r = rows[1]
      table.insert(lines, (r.aff and (to_fmt(r.aff, 'latex') .. '\\quad ') or '') .. nm(r))
    end
    for _, x in ipairs(post) do table.insert(lines, to_fmt(x, 'latex')) end
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
    local function nm(r)
      local t = to_fmt(r.name, 'typst')
      if r.email then t = t .. '#footnote(numbering: "*")[' .. to_fmt(r.email, 'typst') .. ']' end
      return t
    end
    local parts = {}
    local plain = {}
    for _, x in ipairs(pre) do table.insert(plain, to_fmt(x, 'typst')) end
    if multi then
      if #plain > 0 then table.insert(parts, table.concat(plain, ' \\\n')) end
      local cells = {}
      for _, r in ipairs(rows) do
        table.insert(cells, '[' .. (r.aff and to_fmt(r.aff, 'typst') or '') .. ']')
        table.insert(cells, '[' .. nm(r) .. ']')
      end
      table.insert(parts, '#grid(columns: 2, column-gutter: 1em, row-gutter: 0.65em, align: (right, left),\n  '
        .. table.concat(cells, ', ') .. ')')
      plain = {}
    else
      local r = rows[1]
      table.insert(plain, (r.aff and (to_fmt(r.aff, 'typst') .. '#h(1em)') or '') .. nm(r))
    end
    for _, x in ipairs(post) do table.insert(plain, to_fmt(x, 'typst')) end
    if #plain > 0 then table.insert(parts, table.concat(plain, ' \\\n')) end
    blocks:insert(pandoc.RawBlock('typst', '#align(center)[\n' .. table.concat(parts, '\n\n') .. '\n]\n#v(1em)'))
  else
    -- メールは脚注にせず (余白の脚注を入れると Quarto が行を page-columns の grid にして崩れる)，
    -- 氏名に * を付け，表題の欄の最後に「* メール」の行を置く (PDF の脚注と同じ印)
    local function nm(r)
      local t = pandoc.Inlines({})
      t:extend(r.name)
      if r.email then t:insert(pandoc.Superscript({ pandoc.Str('*') })) end
      return t
    end
    local mail = nil
    for _, r in ipairs(rows) do
      if r.email then
        local il = pandoc.Inlines({ pandoc.Superscript({ pandoc.Str('*') }), pandoc.Space() })
        il:extend(r.email)
        mail = pandoc.Para({ pandoc.Span(il, pandoc.Attr('', { 'oxq-title-mail' })) })
      end
    end
    -- 行は 1 つの段落の中の改行で (段落を分けると行の間が空きすぎる)．題も中央に揃える
    local function para_of(list)
      local para = pandoc.Inlines({})
      for i, l in ipairs(list) do
        if i > 1 then para:insert(pandoc.LineBreak()) end
        para:extend(l)
      end
      return pandoc.Para(para)
    end
    blocks:insert(pandoc.RawBlock('html',
      '<style>#title-block-header .title { text-align: center; }\n' ..
      '.oxq-abstract .block-title { font-weight: bold; }\n' ..
      -- 共著の行: 所属 (右寄せ) と氏名 (左寄せ) を中央の線の両側に．Quarto が page-columns (grid) を付けるので !important
      '.oxq-title-row { display: grid !important; grid-template-columns: 1fr 1fr !important; column-gap: 1em; margin: 0.15em 0; }\n' ..
      '.oxq-title-mail { font-size: 0.85em; }\n' ..
      '.oxq-title-row .oxq-aff { text-align: right; }\n' ..
      '.oxq-title-row .oxq-name { text-align: left; }\n' ..
      '.oxq-title-authors p { margin: 0.3em 0; }</style>'))
    local inner = pandoc.Blocks({})
    if multi then
      if #pre > 0 then inner:insert(para_of(pre)) end
      -- 1 人 1 行の div (脚注は Quarto が行の後ろの余白の欄に出す)
      for _, r in ipairs(rows) do
        inner:insert(pandoc.Div({
          pandoc.Div({ pandoc.Plain(r.aff or pandoc.Inlines({})) }, pandoc.Attr('', { 'oxq-aff' })),
          pandoc.Div({ pandoc.Plain(nm(r)) }, pandoc.Attr('', { 'oxq-name' })) },
          pandoc.Attr('', { 'oxq-title-row' })))
      end
      if #post > 0 then inner:insert(para_of(post)) end
    else
      local lines = {}
      for _, x in ipairs(pre) do table.insert(lines, x) end
      local r = rows[1]
      local last = pandoc.Inlines({})
      if r.aff then last:extend(r.aff); last:insert(pandoc.Str('\u{3000}')) end
      last:extend(nm(r))
      table.insert(lines, last)
      for _, x in ipairs(post) do table.insert(lines, x) end
      inner:insert(para_of(lines))
    end
    if mail then inner:insert(mail) end
    blocks:insert(pandoc.Div(inner, pandoc.Attr('', { 'oxq-title-authors' },
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
