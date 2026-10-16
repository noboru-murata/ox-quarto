-- callout-colors.lua — PDF (LaTeX) と html の callout を palette の役割の色にする
--
-- 使い方: front matter に  callout-palette: indigo   (lecture / report / handout の yaml に既定がある．
--   org の #+QUARTO_PALETTE で ox-quarto-ext が書き換える) と，filters にこのファイル．
--
-- revealjs は scss (palette の $callout-color-*) がそのまま効くので何もしない．pdf と html では
-- Quarto の既定の色 (warning の橙と caution の橙赤が近い) になるので，_quarto/scss/<名前>-palette.scss の
--   $doc-callout-color-<種類>  (あれば．暗い palette の白い頁用．dracula)
--   $callout-color-<種類>       (無ければこちら)
--   $doc-callout-default-color / $callout-default-color  (種類なしの callout)
-- を読んで，
--   LaTeX: \definecolor{quarto-callout-<種類>-color} と …-color-frame を \AtBeginDocument で定義し直す
--          (Quarto はプリアンブルで既定の色を定義するので，その後で上書きする)．
--   html:  左の線と見出しの帯 (色を白に 12% 混ぜる．スライドの帯と同じ) の CSS を <head> に足す．
-- 箱の中の太字は箱の色にする (スライドと同じ．LaTeX は \textcolor，html は CSS)．
-- typst はまだ (Quarto が callout ごとに色を書き込むため．README.org の「callout の役割」)．

local ROLES = { 'note', 'tip', 'warning', 'important', 'caution' }
local palette_name = nil
local colors = nil

local function script_dir()
  local f = PANDOC_SCRIPT_FILE or ''
  return f:match('^(.*)[/\\]') or '.'
end

local function read_palette(name)
  local path = script_dir() .. '/../scss/' .. name .. '-palette.scss'
  local fh = io.open(path, 'r')
  if not fh then
    quarto.log.warning('callout-colors: ' .. path .. ' が無い (callout-palette: ' .. name .. ')')
    return nil
  end
  local text = fh:read('a'); fh:close()
  local function get(var)
    return text:match('\n%$' .. var:gsub('%-', '%%-') .. ':%s*#(%x%x%x%x%x%x)')
  end
  local out = {}
  for _, r in ipairs(ROLES) do
    out[r] = get('doc-callout-color-' .. r) or get('callout-color-' .. r)
  end
  out.default = get('doc-callout-default-color') or get('callout-default-color')
  return out
end

local function tint(hex, t)   -- hex を白に t の割合で混ぜる
  local s = ''
  for i = 1, 5, 2 do
    local c = tonumber(hex:sub(i, i + 1), 16)
    s = s .. string.format('%02X', math.floor(c * t + 255 * (1 - t) + 0.5))
  end
  return s
end

local function latex_header()
  local defs = {}
  for _, r in ipairs(ROLES) do
    if colors[r] then
      table.insert(defs, string.format('\\definecolor{quarto-callout-%s-color}{HTML}{%s}%%', r, colors[r]))
      table.insert(defs, string.format('\\definecolor{quarto-callout-%s-color-frame}{HTML}{%s}%%', r, colors[r]))
    end
  end
  if colors.default then
    table.insert(defs, string.format('\\definecolor{quarto-callout-color}{HTML}{%s}%%', colors.default))
    table.insert(defs, string.format('\\definecolor{quarto-callout-color-frame}{HTML}{%s}%%', colors.default))
  end
  return '% callout-colors.lua: callout-palette ' .. palette_name .. '\n'
    .. '\\AtBeginDocument{%\n  \\ifdefined\\definecolor\n  '
    .. table.concat(defs, '\n  ') .. '\n  \\fi\n}'
end

local function html_header()
  local css = {}
  for _, r in ipairs(ROLES) do
    local c = colors[r]
    if c then
      table.insert(css, string.format(
        'body div.callout-%s.callout { border-left-color: #%s; }\n' ..
        'body div.callout-%s.callout-style-default > .callout-header { background-color: #%s; }\n' ..
        'body div.callout-%s.callout .callout-body :is(strong, b) { color: #%s; }',
        r, c, r, tint(c, 0.12), r, c))
    end
  end
  return '<style>/* callout-colors.lua: callout-palette ' .. palette_name .. ' */\n'
    .. table.concat(css, '\n') .. '\n</style>'
end

local function color_strong(blocks, role)
  if not quarto.doc.is_format('latex') or not colors[role] then return blocks end
  return pandoc.walk_block(pandoc.Div(blocks), {
    Strong = function(el)
      local out = pandoc.List({ pandoc.RawInline('latex', '\\textcolor{quarto-callout-' .. role .. '-color}{') })
      out:insert(el)
      out:insert(pandoc.RawInline('latex', '}'))
      return out
    end,
  }).content
end

local function role_of(classes)
  for _, c in ipairs(classes) do
    local r = c:match('^callout%-(%a+)$')
    if r then
      for _, x in ipairs(ROLES) do if x == r then return r end end
    end
  end
end

return {
  {
    Meta = function(meta)
      if quarto.doc.is_format('revealjs') then return end
      if not (quarto.doc.is_format('latex') or quarto.doc.is_format('html')) then return end
      local v = meta['callout-palette']
      if not v then return end
      palette_name = pandoc.utils.stringify(v)
      if palette_name == '' or palette_name == 'none' then return end
      colors = read_palette(palette_name)
      if not colors then return end
      if quarto.doc.is_format('latex') then
        quarto.doc.include_text('in-header', latex_header())
      else
        quarto.doc.include_text('in-header', html_header())
      end
    end,
  },
  {
    Callout = function(el)
      if not colors then return end
      local r = el.type
      if r and colors[r] then el.content = color_strong(el.content, r) end
      return el
    end,
    Div = function(el)
      if not colors then return end
      local r = role_of(el.classes)
      if r then el.content = color_strong(el.content, r); return el end
    end,
  },
}
