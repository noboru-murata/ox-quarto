-- pin.lua — 中央寄せの頁でも，absolute の要素をキャンバスの上端・下端に固定する (.pin-top / .pin-bottom)
--
-- 書き方 (qmd．org では #+begin_export markdown の中に):
--   ::: {.absolute .pin-top right=0 pin-top="0"}       上端から 0px (キャンバスは 1050×700)
--   ![](figs/qr-edition.svg){.qr-tile}                  .qr-tile: QR コードを白い地に (parts.scss)
--   :::
--   ::: {.pin-bottom left=0 pin-bottom="40"} … :::      下端から 40px
-- 左右は Quarto の .absolute の left= / right= のまま．余白を書かなければ 0 (CSS の --pin-top / --pin-bottom でも与えられる)．
--
-- なぜ要るか: center: true では reveal が頁の section に top を与えて中身を上下の中央に置き，section は中身の高さしか無い．
-- そのため .absolute の top=0 / bottom=0 は中身の上端・下端になり，中身の量で動く．さらに reveal は中央に置く高さに
-- scrollHeight (absolute の要素のはみ出しも含む) を使うので，下にはみ出した要素があると中身が上にずれる．
-- このフィルタは，そういう要素がある文書にだけ短いスクリプトを足す．スクリプトは
--   1. 固定する要素のある中央寄せの頁の top を，中身の高さ (offsetHeight．absolute を含まない) で置き直し，
--   2. 要素の top / bottom を「キャンバスの端からの距離 − section のずれ」にする．
-- reveal は文字や画像を読んだ後にも top を計算し直すので，reveal のイベントと load に加えて，section の style の変化
-- (MutationObserver) と大きさの変化 (ResizeObserver) でも測り直す．中央寄せでない頁ではずれが 0 なので，そのまま効く．
-- ?print-pdf (notes-handout.py) では頁 (.pdf-page) の高さを基準にする．表紙の QR コード (title-qr.lua) もこれを使う．
-- revealjs 以外では何もしない (クラスは残るが働かない)．

local found = false

local function has_pin(el)
  if el.classes and (el.classes:includes("pin-top") or el.classes:includes("pin-bottom")) then
    found = true
  end
end

local SCRIPT = [[
<script>
// pin.lua: .pin-top / .pin-bottom の要素をキャンバスの上端・下端に固定する (中央寄せの頁でも)
(function () {
  var seen = (typeof WeakSet === "function") ? new WeakSet() : null;
  function canvasHeight(sec) {
    var page = sec.closest(".pdf-page");
    if (page) return page.clientHeight;
    return (window.Reveal && Reveal.getConfig) ? Reveal.getConfig().height : 700;
  }
  function gap(el, side) {
    var v = el.getAttribute("data-pin-" + side);
    if (v === null || v === "") v = el.getAttribute("pin-" + side);
    if (v === null || v === "") v = getComputedStyle(el).getPropertyValue("--pin-" + side);
    return parseFloat(v) || 0;
  }
  function place(sec) {
    if (!sec.offsetParent) return;                      // 見えていない頁 (display: none) は測れない
    var pins = Array.prototype.filter.call(sec.querySelectorAll(".pin-top, .pin-bottom"),
      function (el) { return el.closest("section") === sec; });
    if (!pins.length) return;
    var H = canvasHeight(sec);
    if (sec.classList.contains("center")) {             // reveal の中央寄せをはみ出しを除いた高さで置き直す
      var want = Math.max((H - sec.offsetHeight) / 2, 0) + "px";
      if (sec.style.top !== want) sec.style.top = want;
    }
    var top = sec.offsetTop, bottom = H - (sec.offsetTop + sec.offsetHeight);
    pins.forEach(function (el) {
      if (el.classList.contains("pin-top")) {
        el.style.top = (gap(el, "top") - top) + "px"; el.style.bottom = "auto";
      } else {
        el.style.bottom = (gap(el, "bottom") - bottom) + "px"; el.style.top = "auto";
      }
    });
  }
  function watch(sec) {
    if (!seen || seen.has(sec)) return;
    seen.add(sec);
    if (window.MutationObserver) {
      new MutationObserver(function () { place(sec); })
        .observe(sec, { attributes: true, attributeFilter: ["style", "class"] });
    }
    if (window.ResizeObserver) new ResizeObserver(function () { place(sec); }).observe(sec);
    Array.prototype.forEach.call(sec.querySelectorAll(".pin-top img, .pin-bottom img"), function (img) {
      img.addEventListener("load", function () { place(sec); });
    });
  }
  function all() {
    var secs = [];
    Array.prototype.forEach.call(document.querySelectorAll(".reveal .slides .pin-top, .reveal .slides .pin-bottom"),
      function (el) { var s = el.closest("section"); if (s && secs.indexOf(s) < 0) secs.push(s); });
    secs.forEach(function (s) { watch(s); place(s); });
  }
  if (window.Reveal && Reveal.on) {
    Reveal.on("ready", all);
    Reveal.on("resize", all);
    Reveal.on("slidechanged", all);
    Reveal.on("pdf-ready", all);
  }
  window.addEventListener("load", all);
  all();
})();
</script>
]]

return {
  {
    Div = has_pin, Span = has_pin, Image = has_pin,
    Pandoc = function(doc)
      if not quarto.doc.is_format("revealjs") then return nil end
      if found or doc.meta["title-qr"] ~= nil then
        quarto.doc.include_text("after-body", SCRIPT)
      end
      return nil
    end,
  },
}
