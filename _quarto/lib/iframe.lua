--[[ iframe.lua ------------------------------------------------------------
     ::: {.iframe src="..." } を <iframe> に変換する Quarto filter

     org 側の書き方:
       #+begin_iframe :src "demo.html" :height "420px"
       （PDF 用の代替テキスト。html では表示されません）
       #+end_iframe

     対応する属性:
       src        必須。相対パスまたは URL
       width      既定 "100%"
       height     既定 "500px" (図と同じ $fig-max-height で頭打ち)．
                  明示したときは頭打ちにせず，その高さで出す
       fill       領域いっぱいに広げる (width / height より優先)
                    "canvas"  スライドのキャンバス全体 (1050×700) を覆う．見出しは隠す
                              (DOM には残るのでメニューには出る)．中のページは
                              1050×700 の窓として描かれ，スライドと一緒に拡大縮小される
                    "tall"    見出しの下に $fig-full-height (35ex，約 600px) の高さで
       title      iframe の title (アクセシビリティ用)。省略時は "embedded page"
                  org の :title はこの属性になる (callout 以外の特殊ブロックでは
                  :title は見出しではなく属性．ox-quarto-ext-block.el)
       sandbox    値をそのまま sandbox 属性へ（例 "allow-scripts"）
       allow      例 "fullscreen; clipboard-write"
       scrolling  "no" など
       border     "true" を指定すると .iframe-wrap に枠線クラスを付与

     html/revealjs 以外（PDF など）では、div の中身＋URL へのリンクに置換。

     例: キャンバス全体に html を取り込む (:title は iframe の title 属性になる)
       ** デモ
       #+begin_iframe :src "demo.html" :fill "canvas" :title "デモ: 曲線の設計"
       （PDF 用の代替テキスト）
       #+end_iframe

     ■ background-iframe との違い
       reveal の {background-iframe="…"} は窓全体 (余白の帯も含む) に敷く背景で，
       操作するには background-interactive も要る．fill="canvas" はスライドの
       キャンバスの中に置くので，余白・拡大縮小・頁番号の位置がほかのスライドと揃い，
       そのまま操作 (クリック・スクロール) できる．iframe の中をクリックすると
       キー入力はそちらに渡るので，頁送りはキャンバスの外をクリックしてから．

     ■ embed-resources: true への対応
       pandoc の self-contained 処理は <iframe src="..."> の中身を
       data: URI としてインライン展開してしまい、埋め込み先が壊れる。
       そこで src は書かず data-iframe-src に入れておき、ブラウザ側の
       スクリプトで src を復元する（reveal.js ではスライド表示時に遅延
       ロードする）。この方式なら embed-resources の有無を問わず動く。
-----------------------------------------------------------------------------]]

local script_added = false

local loader = [[
<script>
(function () {
  function load(f) {
    if (f.dataset.iframeSrc && !f.src) { f.src = f.dataset.iframeSrc; }
  }
  function loadIn(root) {
    (root || document).querySelectorAll('iframe[data-iframe-src]').forEach(load);
  }
  if (window.Reveal && typeof Reveal.on === 'function') {
    // 表示されたスライドの中だけ読み込む（遅延ロード）
    Reveal.on('ready',      function (e) { loadIn(e.currentSlide); });
    Reveal.on('slidechanged', function (e) { loadIn(e.currentSlide); });
  } else {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', function () { loadIn(); });
    } else {
      loadIn();
    }
  }
})();
</script>
]]

local function attr(el, k, default)
  local v = el.attributes[k]
  if v == nil or v == "" then return default end
  return v
end

-- 属性の値を html の "…" の中に書ける形にする (title に " などが入っても壊れないように)
local function esc(v)
  return (tostring(v):gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function opt(name, value)
  if value == nil then return "" end
  return string.format(' %s="%s"', name, esc(value))
end

function Div(el)
  if not el.classes:includes("iframe") then return nil end
  local src = attr(el, "src")
  if not src then return nil end

  if quarto.doc.is_format("html:js") or quarto.doc.is_format("revealjs") then
    if not script_added then
      quarto.doc.include_text("after-body", loader)
      script_added = true
    end

    local wrap = "iframe-wrap"
    if attr(el, "border") == "true" then wrap = wrap .. " iframe-bordered" end

    local fill = attr(el, "fill")
    local width, height = attr(el, "width", "100%"), attr(el, "height")
    if fill == "canvas" then
      wrap, width, height = wrap .. " iframe-canvas", "100%", "100%"
    elseif fill == "tall" then
      wrap, width, height = wrap .. " iframe-tall", "100%", nil  -- 高さは CSS
    elseif fill then
      io.stderr:write("iframe.lua: unknown fill \"" .. fill .. "\" (canvas | tall)\n")
    elseif height then
      wrap = wrap .. " iframe-sized"                -- 明示した高さは頭打ちにしない
    else
      height = "500px"
    end

    local html = table.concat({
      '<div class="', wrap, '">',
      '<iframe data-iframe-src="', esc(src), '"',   -- src= と書かないのが要点
      opt("width",     width),
      opt("height",    height),
      opt("title",     attr(el, "title",  "embedded page")),
      opt("sandbox",   attr(el, "sandbox")),
      opt("allow",     attr(el, "allow")),
      opt("scrolling", attr(el, "scrolling")),
      ' allowfullscreen></iframe>',
      '</div>'
    })
    return pandoc.RawBlock("html", html)
  else
    -- PDF などでは中身（代替テキスト）＋リンクを残す
    local out = el.content
    table.insert(out, pandoc.Para{
      pandoc.Str("→ "), pandoc.Link(pandoc.Str(src), src)})
    return out
  end
end
