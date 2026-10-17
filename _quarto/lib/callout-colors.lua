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
-- html の印 (:icon true のときだけ出る) は，Quarto が色付きの SVG を background-image に埋め込むので色の CSS では変わらない．
--   印の形を mask-image で切り抜き，background-color で役割の色に塗り直す (形は下の ICONS．Quarto を上げたら samples の html で印を確かめる)．
-- typst はまだ (Quarto が callout ごとに色を書き込むため．README.org の「callout の役割」)．

local ROLES = { 'note', 'tip', 'warning', 'important', 'caution' }

-- 印の形 (Bootstrap Icons，MIT License，https://icons.getbootstrap.com．Quarto 1.10 の html の callout の印と同じ)
local ICONS = {
  note = {  -- bi-info-circle
    'M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14zm0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16z',
    'm8.93 6.588-2.29.287-.082.38.45.083c.294.07.352.176.288.469l-.738 3.468c-.194.897.105 1.319.808 1.319.545 0 1.178-.252 1.465-.598l.088-.416c-.2.176-.492.246-.686.246-.275 0-.375-.193-.304-.533L8.93 6.588zM9 4.5a1 1 0 1 1-2 0 1 1 0 0 1 2 0z',
  },
  tip = {  -- bi-lightbulb
    'M2 6a6 6 0 1 1 10.174 4.31c-.203.196-.359.4-.453.619l-.762 1.769A.5.5 0 0 1 10.5 13a.5.5 0 0 1 0 1 .5.5 0 0 1 0 1l-.224.447a1 1 0 0 1-.894.553H6.618a1 1 0 0 1-.894-.553L5.5 15a.5.5 0 0 1 0-1 .5.5 0 0 1 0-1 .5.5 0 0 1-.46-.302l-.761-1.77a1.964 1.964 0 0 0-.453-.618A5.984 5.984 0 0 1 2 6zm6-5a5 5 0 0 0-3.479 8.592c.263.254.514.564.676.941L5.83 12h4.342l.632-1.467c.162-.377.413-.687.676-.941A5 5 0 0 0 8 1z',
  },
  warning = {  -- bi-exclamation-triangle
    'M7.938 2.016A.13.13 0 0 1 8.002 2a.13.13 0 0 1 .063.016.146.146 0 0 1 .054.057l6.857 11.667c.036.06.035.124.002.183a.163.163 0 0 1-.054.06.116.116 0 0 1-.066.017H1.146a.115.115 0 0 1-.066-.017.163.163 0 0 1-.054-.06.176.176 0 0 1 .002-.183L7.884 2.073a.147.147 0 0 1 .054-.057zm1.044-.45a1.13 1.13 0 0 0-1.96 0L.165 13.233c-.457.778.091 1.767.98 1.767h13.713c.889 0 1.438-.99.98-1.767L8.982 1.566z',
    'M7.002 12a1 1 0 1 1 2 0 1 1 0 0 1-2 0zM7.1 5.995a.905.905 0 1 1 1.8 0l-.35 3.507a.552.552 0 0 1-1.1 0L7.1 5.995z',
  },
  caution = {  -- bi-cone-striped
    'M9.97 4.88l.953 3.811C10.158 8.878 9.14 9 8 9c-1.14 0-2.159-.122-2.923-.309L6.03 4.88C6.635 4.957 7.3 5 8 5s1.365-.043 1.97-.12zm-.245-.978L8.97.88C8.718-.13 7.282-.13 7.03.88L6.274 3.9C6.8 3.965 7.382 4 8 4c.618 0 1.2-.036 1.725-.098zm4.396 8.613a.5.5 0 0 1 .037.96l-6 2a.5.5 0 0 1-.316 0l-6-2a.5.5 0 0 1 .037-.96l2.391-.598.565-2.257c.862.212 1.964.339 3.165.339s2.303-.127 3.165-.339l.565 2.257 2.391.598z',
  },
  important = {  -- bi-exclamation-circle
    'M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14zm0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16z',
    'M7.002 11a1 1 0 1 1 2 0 1 1 0 0 1-2 0zM7.1 4.995a.905.905 0 1 1 1.8 0l-.35 3.507a.552.552 0 0 1-1.1 0L7.1 4.995z',
  },
}

local function icon_url(role)   -- 印の形を data: の URL に (mask に使うので色は付けない)
  local svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">'
  for _, d in ipairs(ICONS[role]) do svg = svg .. '<path d="' .. d .. '"/>' end
  svg = svg .. '</svg>'
  return "url('data:image/svg+xml," .. svg:gsub('[%%#<>"]', function(c)
    return string.format('%%%02X', string.byte(c))
  end) .. "')"
end
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
        'body div.callout-%s.callout .callout-body :is(strong, b) { color: #%s; }\n' ..
        'body div.callout-%s.callout .callout-icon::before { background-image: none; background-color: #%s;\n' ..
        '  -webkit-mask: %s no-repeat center / contain; mask: %s no-repeat center / contain; }',
        r, c, r, tint(c, 0.12), r, c, r, c, icon_url(r), icon_url(r)))
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
