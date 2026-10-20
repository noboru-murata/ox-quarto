-- callout-colors-typst.lua — typst の PDF の callout の枠・印・題の帯を palette の役割の色にする
--
-- 使い方 (report-typst / handout-typst の yaml): filters で quarto の *後* に置く (callout-colors.lua は前)．
--   filters:
--     - _quarto/lib/callout-colors.lua
--     - quarto
--     - _quarto/lib/callout-colors-typst.lua
--
-- Quarto (1.10) は typst の callout を #callout(…, background_color: rgb("#dae6fb"), icon_color: rgb("#0758E5"), …) と
-- 書き出し，色は種類ごとに決まった値 (Quarto の kColor* / kBackgroundColor*) になる．Quarto の処理の後で走り，
-- その値を front matter の callout-palette: の palette の色 (callout-colors.lua と同じ読み方) に置き換える．
-- 題の帯は色を白に 12% 混ぜたもの (html と同じ)．Quarto の既定の色が変わったら下の DEFAULTS を直す
-- (report-typst で書き出して確かめる)．typst 以外では何もしない．

local ROLES = { 'note', 'tip', 'warning', 'important', 'caution' }
-- Quarto 1.10 の既定 (filters/main.lua の kColor* と kBackgroundColor*)
local DEFAULTS = {
  note      = { '0758E5', 'dae6fb' },
  important = { 'CC1914', 'f7dddc' },
  warning   = { 'EB9113', 'fcefdc' },
  tip       = { '00A047', 'ccf1e3' },
  caution   = { 'FC5300', 'ffe5d0' },
}

local function script_dir()
  local f = PANDOC_SCRIPT_FILE or ''
  return f:match('^(.*)[/\\]') or '.'
end

local function read_palette(name)
  local path = script_dir() .. '/../scss/' .. name .. '-palette.scss'
  local fh = io.open(path, 'r')
  if not fh then return nil end
  local text = fh:read('a'); fh:close()
  local function get(var)
    return text:match('\n%$' .. var:gsub('%-', '%%-') .. ':%s*#(%x%x%x%x%x%x)')
  end
  local out = {}
  for _, r in ipairs(ROLES) do
    out[r] = get('doc-callout-color-' .. r) or get('callout-color-' .. r)
  end
  return out
end

local function tint(hex, t)
  local s = ''
  for i = 1, 5, 2 do
    local c = tonumber(hex:sub(i, i + 1), 16)
    s = s .. string.format('%02X', math.floor(c * t + 255 * (1 - t) + 0.5))
  end
  return s
end

local map = nil   -- 既定の色 (大文字) -> 新しい色

return {
  {
    Meta = function(meta)
      if not quarto.doc.is_format('typst') then return end
      local v = meta['callout-palette']
      if not v then return end
      local name = pandoc.utils.stringify(v)
      if name == '' or name == 'none' then return end
      local colors = read_palette(name)
      if not colors then return end
      map = {}
      for _, r in ipairs(ROLES) do
        if colors[r] then
          map[DEFAULTS[r][1]:upper()] = colors[r]
          map[DEFAULTS[r][2]:upper()] = tint(colors[r], 0.12)
        end
      end
    end,
  },
  {
    RawInline = function(el)
      if not map or el.format ~= 'typst' then return end
      local t, n = el.text:gsub('rgb%("#(%x%x%x%x%x%x)"%)', function(h)
        local c = map[h:upper()]
        if c then return 'rgb("#' .. c .. '")' end
      end)
      if n > 0 then el.text = t; return el end
    end,
  },
}
