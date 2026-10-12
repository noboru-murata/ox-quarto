-- title-qr.lua — 表紙 (#title-slide) の右下に QR コードと URL などの短い文を置く
--
-- front matter (org では #+QUARTO_QR / #+QUARTO_QR_CAPTION．ox-quarto-ext-theme.el が書き出す):
--   title-qr:
--     image: figs/qr-edition.svg       QR コードの画像 (tools/oxq-qr.py で作れる)
--     caption: "https://…/talks/<主題>/<版>/"   画像の下の小さな文 (省略可．URL ならリンクにする)
--
-- 表紙は Quarto がひな形から作り，フィルタからは触れない．そこで文書の最後に隠した div を置き，
-- 短いスクリプトで #title-slide の中へ移す (Quarto のひな形を写さないので，版が上がっても壊れにくい)．
-- 画像は普通の Image なので embed-resources で html に埋め込まれる．
-- 位置と大きさは parts.scss の $title-qr-* ．revealjs 以外では何もしない．

local function str(v)
  if v == nil then return nil end
  local s = pandoc.utils.stringify(v)
  if s == "" then return nil end
  return s
end

function Pandoc(doc)
  if not quarto.doc.is_format("revealjs") then return nil end
  local q = doc.meta["title-qr"]
  if q == nil then return nil end
  local image, caption
  if pandoc.utils.type(q) == "table" or pandoc.utils.type(q) == "Meta" then
    image, caption = str(q.image), str(q.caption)
  else
    image = str(q)
  end
  if not image then return nil end

  local content = pandoc.Blocks{}
  content:insert(pandoc.Plain{ pandoc.Image({}, image, "", pandoc.Attr("", {"oxq-title-qr-img"})) })
  if caption then
    local inl
    if caption:match("^https?://") then
      inl = pandoc.Link(caption, caption)
    else
      inl = pandoc.Str(caption)
    end
    content:insert(pandoc.Plain{ pandoc.Span({inl}, pandoc.Attr("", {"oxq-title-qr-caption"})) })
  end
  doc.blocks:insert(pandoc.Div(content, pandoc.Attr("oxq-title-qr", {"oxq-title-qr"}, {style = "display:none"})))

  quarto.doc.include_text("after-body", [[
<script>
// title-qr.lua: 文書の最後に置いた QR コードを表紙 (#title-slide) に移し，スライドの右下に合わせる．
// center: true では表紙の section は中身の高さしか無く，reveal が top をずらして中央に置くので，
// その分を測って bottom を決める (位置は parts.scss の $title-qr-right / $title-qr-bottom)．
(function () {
  var q = document.getElementById("oxq-title-qr");
  var t = document.getElementById("title-slide");
  if (!q || !t) return;
  t.appendChild(q);
  q.style.display = "";
  // reveal は画像を data-src で遅れて読む (近くのスライドだけ)．最後のスライドから移したので自分で読む
  var img = q.querySelector("img");
  if (img && !img.getAttribute("src") && img.getAttribute("data-src")) {
    img.setAttribute("src", img.getAttribute("data-src"));
  }
  function place() {
    var H = (window.Reveal && Reveal.getConfig) ? Reveal.getConfig().height : 700;
    var gap = parseFloat(getComputedStyle(q).getPropertyValue("--oxq-title-qr-bottom")) || 0;
    var below = H - (t.offsetTop + t.offsetHeight);   // 表紙の section の下からスライドの下まで
    q.style.bottom = (gap - below) + "px";
  }
  if (window.Reveal && Reveal.on) {
    Reveal.on("ready", place);
    Reveal.on("resize", place);
    Reveal.on("slidechanged", place);
  }
  window.addEventListener("load", place);
  if (img) img.addEventListener("load", place);
})();
</script>
]])
  return doc
end
