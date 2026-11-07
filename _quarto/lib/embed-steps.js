/* embed-steps.js — デモ (html) の側: スライドに埋め込んだとき，スライドの頁送りで段を進める (2026-11-07)
 *
 * 使い方: デモの html の最後で読む (デモと一緒に置く．公開するデモが ox-quarto を指さないように写して使う)
 *     <script src="embed-steps.js"></script>
 *   デモは window.demoSteps = {next(), prev(), start(), end()} を用意する (next / prev は進めたら true，端なら false)．
 *   スライドの側は #+begin_iframe :src "demo.html?embed" :steps t (_quarto/lib/iframe.lua と iframe-steps.html)．
 *
 * することは:
 *   - 親 (スライド) から {channel: 'oxq-demo', type: 'step', dir} を受けたら ack を返して一段進め，進めなかったら {type: 'edge', dir} を返す
 *     (親が頁を送る)．{type: 'enter', at: 'start' | 'end'} で最初か最後の段へ．読み込んだら {type: 'ready'}．
 *   - 図の中をクリックしてキーの焦点がデモにあっても，→ ← (PageDown / PageUp，スペース) は同じ動き (端なら親に頁送りを頼む)．
 *   - ?embed で開いたときは <html> に class "embed" を付ける (帯やボタンを隠す CSS はデモの側で html.embed … と書く)．
 *   - window.embedCaption(文) で図の上に一行の題の欄を出せる (段の題など．?embed のときだけ)．
 * 埋め込まれていない (単独で開いた) ときは何もしない (embedCaption は何もしない関数)．
 */
(function () {
  var CH = 'oxq-demo';
  var embedded = window.parent && window.parent !== window;
  var qp = new URLSearchParams(location.search);
  var cap = null;
  window.embedCaption = function (t) {
    if (!qp.has('embed')) return;
    if (!cap) {
      var st = document.createElement('style');
      st.textContent = 'html.embed .embed-cap { padding: 4px 14px 2px; font-size: 15px; font-weight: 600; opacity: 0.75;' +
        ' white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }';
      document.head.append(st);
      cap = document.createElement('div'); cap.className = 'embed-cap';
      document.body.prepend(cap);
    }
    cap.textContent = t || '';
  };
  if (qp.has('embed')) document.documentElement.classList.add('embed');
  if (!embedded) return;
  function api() { return window.demoSteps; }
  function send(m) { m.channel = CH; try { parent.postMessage(m, '*'); } catch (e) {} }
  function step(dir) {
    var a = api(); if (!a) return;
    var moved = dir === 'next' ? a.next() : a.prev();
    if (!moved) send({ type: 'edge', dir: dir });
  }
  addEventListener('message', function (e) {
    var d = e.data; if (!d || d.channel !== CH || e.source !== parent) return;
    var a = api(); if (!a) return;
    if (d.type === 'step') { send({ type: 'ack' }); step(d.dir); }
    else if (d.type === 'enter') { if (d.at === 'end') a.end(); else a.start(); }
  });
  addEventListener('keydown', function (e) {
    if (!api()) return;
    if (e.target && e.target.closest && e.target.closest('input, select, textarea, [contenteditable]')) return;
    if (e.metaKey || e.ctrlKey || e.altKey || e.shiftKey) return;
    var k = e.key, dir = null;
    if (k === 'ArrowRight' || k === 'PageDown' || k === ' ') dir = 'next';
    else if (k === 'ArrowLeft' || k === 'PageUp') dir = 'prev';
    if (!dir) return;
    e.preventDefault(); e.stopImmediatePropagation();
    step(dir);
  }, true);
  if (document.readyState === 'complete') send({ type: 'ready' });
  else addEventListener('load', function () { send({ type: 'ready' }); });
})();
