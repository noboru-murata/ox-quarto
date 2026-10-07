--[[ iframe.lua ------------------------------------------------------------
     ::: {.iframe src="..." } を <iframe> に変換する Quarto filter

     org 側の書き方:
       #+begin_iframe :src "demo.html" :height "420px"
       （PDF 用の代替テキスト。html では表示されません）
       #+end_iframe

     対応する属性:
       src        必須。相対パスまたは URL
       width      既定 "100%"
       height     既定 "500px"
       title      アクセシビリティ用。省略時は "embedded page"
       sandbox    値をそのまま sandbox 属性へ（例 "allow-scripts"）
       allow      例 "fullscreen; clipboard-write"
       scrolling  "no" など
       border     "true" を指定すると .iframe-wrap に枠線クラスを付与

     html/revealjs 以外（PDF など）では、div の中身＋URL へのリンクに置換。

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

local function opt(name, value)
  if value == nil then return "" end
  return string.format(' %s="%s"', name, value)
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

    local html = table.concat({
      '<div class="', wrap, '">',
      '<iframe data-iframe-src="', src, '"',   -- src= と書かないのが要点
      opt("width",     attr(el, "width",  "100%")),
      opt("height",    attr(el, "height", "500px")),
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
