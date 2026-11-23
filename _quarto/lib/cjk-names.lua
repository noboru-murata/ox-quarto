-- cjk-names.lua — 番号式の文献 (ams-numeric.csl) で和文の著者名を和文の書き方にする (2026-11-03)
--
-- ams-numeric.csl は名を頭文字にし (initialize-with=". ")，最後の著者の前に and を入れる．
-- 和文の名 (漢字・仮名) にもそれが効き，「園田翔. and 村田昇.」になる．CSL では文字の種類で
-- 書き分けられず (item の language で分ける書き方は，Zotero の項目に language が無いことが多く使えない)，
-- pandoc の citeproc は bibliography の <layout locale="ja"> も受け付けない．そこで citeproc の前に
-- 文献のデータを直す:
--   - 著者 (と編者・訳者) が全員和文の名なら，全員を 1 つの literal の名「園田翔, 村田昇」にする
--     (literal は頭文字にされず，and も入らない)
--   - 和文と欧文が混じるなら，和文の名だけ literal の「園田翔」にする (and は残る)
-- 欧文の名はそのまま (「S. Sonoda and N. Murata」)．並べ替えは literal の文字の順 (和文は欧文の後ろ)．
--
-- 効くのは csl が ams-numeric.csl のとき (front matter の oxq-cjk-names: true でも)．
-- 文献は pandoc.utils.references で読み，front matter の references: に置き換えて bibliography: を外す
-- (この後の citeproc はそれを使う)．
--
-- もう 1 つ (2026-11-23): LaTeX で書誌を余白に出す (citation-location: margin．handout-latex / note) とき，
-- 漢字などを含む文献のキー (例 山田_2025_…) を ASCII のキーに替える．Quarto はキーで書誌を探して
-- 余白に置くが，pandoc の LaTeX は書誌のラベルを ASCII に直す (山 → ux5c71) ので見つからず，
-- 余白にキーがそのまま出て (_ で LaTeX が止まり)，本文の引用も (?) になっていた．
-- キーは pandoc と同じ形 (山田_2025 → ux5c71ux7530_2025) にし，本文の引用 (Cite) と文献の両方を替える．

local CJK = {
  { 0x3040, 0x30FF },   -- 仮名
  { 0x3400, 0x4DBF },   -- 漢字 (拡張 A)
  { 0x4E00, 0x9FFF },   -- 漢字
  { 0xF900, 0xFAFF },   -- 互換漢字
  { 0x20000, 0x2FFFF }, -- 漢字 (拡張 B 以降)
}

local function has_cjk(s)
  if type(s) ~= 'string' then s = pandoc.utils.stringify(s or '') end
  for _, c in utf8.codes(s) do
    for _, r in ipairs(CJK) do
      if c >= r[1] and c <= r[2] then return true end
    end
  end
  return false
end

local function str(v)
  if v == nil then return '' end
  if type(v) == 'string' then return v end
  return pandoc.utils.stringify(v)
end

local function cjk_name(n)
  if n.literal then return has_cjk(n.literal) end
  return has_cjk(str(n.family)) or has_cjk(str(n.given))
end

local function joined(n)
  if n.literal then return str(n.literal) end
  return str(n.family) .. str(n.given)
end

local function fix_names(names)
  if type(names) ~= 'table' or #names == 0 then return names end
  local all = true
  for _, n in ipairs(names) do
    if not cjk_name(n) then all = false end
  end
  if all then
    local parts = {}
    for _, n in ipairs(names) do table.insert(parts, joined(n)) end
    return { { literal = table.concat(parts, ', ') } }
  end
  local out = {}
  for _, n in ipairs(names) do
    if cjk_name(n) then table.insert(out, { literal = joined(n) }) else table.insert(out, n) end
  end
  return out
end

local function wanted(meta)
  if meta['oxq-cjk-names'] then return true end
  local csl = meta.csl and pandoc.utils.stringify(meta.csl) or ''
  return csl:match('ams%-numeric%.csl$') ~= nil
end

local function ascii_key(id)
  local out, changed = {}, false
  for _, c in utf8.codes(id) do
    if c < 128 then table.insert(out, utf8.char(c))
    else table.insert(out, string.format('ux%04x', c)); changed = true end
  end
  return changed and table.concat(out) or nil
end

local function margin_latex(meta)
  local loc = meta['citation-location'] and pandoc.utils.stringify(meta['citation-location']) or ''
  return loc == 'margin' and quarto and quarto.doc and quarto.doc.is_format('latex')
end

function Pandoc(doc)
  local names_wanted = wanted(doc.meta)
  local keys_wanted = margin_latex(doc.meta)
  if not (names_wanted or keys_wanted) then return nil end
  if not (doc.meta.bibliography or doc.meta.references) then return nil end
  local ok, refs = pcall(pandoc.utils.references, doc)
  if not ok or not refs then return nil end
  local changed = false
  local rename = {}
  if keys_wanted then
    for _, r in ipairs(refs) do
      local k = ascii_key(r.id)
      if k then rename[r.id] = k; r.id = k; changed = true end
    end
  end
  for _, r in ipairs(names_wanted and refs or {}) do
    for _, role in ipairs({ 'author', 'editor', 'translator' }) do
      local names = r[role]
      if type(names) == 'table' then
        for _, n in ipairs(names) do
          if not n.literal and cjk_name(n) then changed = true end
        end
        r[role] = fix_names(names)
      end
    end
  end
  if not changed then return nil end
  doc.meta.references = refs
  doc.meta.bibliography = nil
  if next(rename) then
    doc = doc:walk({ Cite = function(c)
      for _, ct in ipairs(c.citations) do
        if rename[ct.id] then ct.id = rename[ct.id] end
      end
      return c
    end })
  end
  return doc
end
