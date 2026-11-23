-- cite-key-escape.lua — 余白の書誌 (citation-location: margin) を LaTeX で出すとき，和文などのキーの文献でも書誌が出るようにする
--
-- Quarto (1.11.9 で確かめた) は余白の書誌の所に {?quarto-cite:KEY} を置き，PDF に書き出した後で
-- \bibitem[\citeproctext]{ref-LABEL} の書誌と KEY で突き合わせる．pandoc は LABEL の ASCII でない文字を uxXXXX に変えるので，
-- 赤塚_村田_2025_… のようなキーは見つからず，キーがそのまま LaTeX に出て _ で止まる (Missing $ inserted)．
-- ここで KEY を pandoc と同じ規則 (英数字と _-+=:;. はそのまま，ほかは ux + 16 進) で変えて，突き合わせが合うようにする．
-- Quarto が置き場所を入れた後に走らせるため，yaml では at: post-finalize で読む:
--   filters:
--     - at: post-finalize
--       path: _quarto/lib/cite-key-escape.lua
-- html と typst では何もしない (置き場所が無い)．2026-11-23 (講演の案件で見つけた)．
local function to_label(s)
  local out = {}
  for _, c in utf8.codes(s) do
    local ch = utf8.char(c)
    if c < 128 and ch:match('[%w_%-%+=:;%.]') then
      out[#out + 1] = ch
    else
      out[#out + 1] = string.format('ux%x', c)
    end
  end
  return table.concat(out)
end

function RawInline(el)
  if el.format:match('latex') and el.text:find('{?quarto-cite:', 1, true) then
    el.text = el.text:gsub('{%?quarto%-cite:(.-)}', function(k)
      return '{?quarto-cite:' .. to_label(k) .. '}'
    end)
    return el
  end
end
