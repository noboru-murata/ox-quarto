-- theorem-callout.lua — スライド (revealjs) で定理の類を callout の箱に入れる (2026-11-24)
--
-- #+begin_theorem :id "thm-…" などの定理の類 (Quarto の相互参照) を，callout の役割の色の箱で包む．
-- 箱の題は「定理 1 (題)」．中の定理の div はそのまま (id も残るので @thm-… の参照は今まで通り)，
-- 定理自身の題 (.theorem-title) は箱の題と重なるので隠す (parts.scss)．PDF・html・typst では何もしない．
--
--   定理・補題・系・命題 (thm lem cor prp)   important (要)
--   定義 (def)・解 (sol)・アルゴリズム (alg) note (説明の箱)
--   例・演習 (exm exr)                       tip (問題)
--   注意・予想 (rem cnj)，番号なしの注意     warning (注意・限界)
--   証明・番号なしの解                       箱に入れない
--
-- 番号は Quarto と同じ数え方 (種類ごとに文書の頭から 1, 2, …) でここで数える．見出しの語は front matter の
-- language (crossref-thm-title など．_quarto/yaml/talk.yaml，lecture.yaml) から．
-- 止めるには front matter に theorem-callout: false．

local ROLE = {
  thm = 'important', lem = 'important', cor = 'important', prp = 'important',
  def = 'note', sol = 'note', alg = 'note',
  exm = 'tip', exr = 'tip',
  rem = 'warning', cnj = 'warning',
}
local DEFAULT_TITLE = {
  thm = '定理', lem = '補題', cor = '系', prp = '命題', cnj = '予想', def = '定義',
  exm = '例', exr = '演習', sol = '解', rem = '注意', alg = 'アルゴリズム',
}

local function meta_bool(v, default)
  if v == nil then return default end
  if type(v) == 'boolean' then return v end
  local s = pandoc.utils.stringify(v)
  return not (s == 'false' or s == 'no' or s == '0')
end

local enabled, lang = true, {}
local count = {}

local function label(kind)
  local v = lang['crossref-' .. kind .. '-title']
  return v and pandoc.utils.stringify(v) or DEFAULT_TITLE[kind]
end

local boxed
local function numbered(el)
  local kind = (el.identifier or ''):match('^(%a%a%a)%-')
  if not (kind and ROLE[kind]) then return nil end
  count[kind] = (count[kind] or 0) + 1
  return boxed(el, ROLE[kind], label(kind) .. ' ' .. count[kind]), false
end

boxed = function(el, role, title)
  local name = el.name and pandoc.utils.stringify(el.name) or ''
  if name ~= '' then title = title .. ' (' .. name .. ')' end
  -- 中身は定理の本文 (el.div の中身) を id 付きの div に (@thm-… のリンクの行き先)．
  -- 箱 (callout) に thm- の id を付けると Quarto が callout の相互参照と取り違えて止まる
  local body = el.div and el.div.content or pandoc.Blocks({})
  return quarto.Callout({
    type = role,
    title = pandoc.Inlines(title),
    icon = false,
    content = pandoc.Blocks({ pandoc.Div(body, pandoc.Attr(el.identifier or '', { 'theorem-body' })) }),
    attr = pandoc.Attr('', { 'theorem-callout' }),
  })
end

return {
  {
    Meta = function(meta)
      enabled = quarto.doc.is_format('revealjs') and meta_bool(meta['theorem-callout'], true)
      lang = meta.language or {}
    end,
  },
  {
    -- Quarto は定理を自分の部品 (Theorem / Proof) にして渡す．文書の順に数えるので topdown
    traverse = 'topdown',
    Theorem = function(el)
      if not enabled then return nil end
      return numbered(el)
    end,
    Proof = function(el)
      if not enabled then return nil end
      local n = numbered(el)        -- rem- / sol- など番号付きは Proof で来ることもある
      if n then return n, false end
      -- 番号なし: type は Quarto の見出しの語 (Remark / Proof / Solution)
      if (el.identifier or '') == '' and string.lower(pandoc.utils.stringify(el.type or '')) == 'remark' then
        local t = lang['environment-remark-title']
        return boxed(el, 'warning', t and pandoc.utils.stringify(t) or '注意'), false
      end
      return nil
    end,
  },
}
