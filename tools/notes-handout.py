#!/usr/bin/env python3
# notes-handout.py — revealjs の html から，スライドと発表者ノートを並べた A4 縦の PDF を作る
#
# 使い方:
#   python3 tools/notes-handout.py talk.html                 → talk-notes.pdf
#   python3 tools/notes-handout.py talk.html -o memo.pdf --per-page 1
#
# 仕組み:
#   1. html を Chromium (playwright) で reveal の PDF 表示 (?print-pdf) にして，スライドを 1 枚ずつ PNG にする
#      (PDF と同じ見た目: 断片 (fragment) は全部出た状態，暗い頁は $print-dark-slides に従う)．
#   2. 各スライドの発表者ノート (::: notes → <aside class="notes">) を取り出し，typst の文に直す
#      (段落・箇条書き・太字・斜体・コード・リンク・数式 (TeX のまま) を扱う)．
#   3. 1 頁に --per-page 枚 (既定 2)，上にスライド，下にノートの順で typst に組み，quarto typst compile で PDF にする．
#      ノートの無いスライドはスライドだけ．ノートが長くて入りきらないときは次の頁に続く．
#
# 前提: python3，playwright (pip install playwright; python3 -m playwright install chromium)，quarto (typst を同梱)．
# html は Quarto で書き出したもの (embed-resources でも，_files が横にあっても良い)．数式は MathJax を読むのでネットにつなぐ．

import argparse, asyncio, os, re, shutil, subprocess, sys, unicodedata
from pathlib import Path

# ---------------------------------------------------------------- ブラウザ側
JS_COLLECT = r"""
() => {
  // ノートの DOM を小さな木 (["tag", children...] / "text") にする．MathJax の表示は捨て，元の TeX を使う．
  function walk(n) {
    if (n.nodeType === Node.TEXT_NODE) return n.textContent;
    if (n.nodeType !== Node.ELEMENT_NODE) return null;
    const t = n.tagName.toLowerCase();
    if (t === 'script') {
      const ty = n.getAttribute('type') || '';
      if (ty.startsWith('math/tex')) return ['math', n.textContent, ty.includes('display')];
      return null;
    }
    if (n.classList && [...n.classList].some(c => /^(MathJax|MJX|mjx)/.test(c))) return null;
    if (t === 'mjx-container') return null;
    if (t === 'style') return null;
    const kids = [...n.childNodes].map(walk).filter(x => x !== null);
    if (t === 'a') return ['a', n.getAttribute('href') || '', ...kids];
    return [t, ...kids];
  }
  const pages = [...document.querySelectorAll('.pdf-page')];
  const out = [];
  pages.forEach((p, i) => {
    const s = p.querySelector('section');
    const notes = s ? [...s.querySelectorAll(':scope > aside.notes, :scope aside.notes')] : [];
    out.push({
      index: i,
      id: s ? s.id : '',
      notes: notes.map(walk),
    });
  });
  const t = document.querySelector('#title-slide .title');
  return { title: t ? t.textContent.trim() : document.title, pages: out };
}
"""

async def capture(html_path, outdir, scale, mathjax_dir=None):
    from playwright.async_api import async_playwright
    url = Path(html_path).resolve().as_uri() + "?print-pdf"
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(device_scale_factor=scale, viewport={"width": 1400, "height": 1000})
        if mathjax_dir:   # 試験用: MathJax をネットでなく手元から読む
            async def mj(route):
                m = re.search(r'/npm/mathjax@2(?:\.7\.9)?/([^?#]*)', route.request.url)
                f = os.path.join(mathjax_dir, m.group(1)) if m else None
                await (route.fulfill(path=f) if f and os.path.isfile(f) else route.abort())
            await pg.route("**/cdn.jsdelivr.net/**", mj)
        await pg.goto(url)
        await pg.wait_for_function("window.Reveal && Reveal.isReady() && document.querySelector('.pdf-page')",
                                   timeout=60000)
        # MathJax の組版が終わるのを待つ (v2: Hub の待ち行列，無ければ少し待つだけ)
        await pg.evaluate("""() => new Promise(res => {
            if (window.MathJax && MathJax.Hub && MathJax.Hub.Queue) MathJax.Hub.Queue(() => res());
            else res(); })""")
        await pg.wait_for_timeout(1500)
        data = await pg.evaluate(JS_COLLECT)
        # 頁番号は表の下に「n / 総数」で出すので，スライドの中の番号は隠す
        await pg.add_style_tag(content=".slide-number-pdf, .reveal .slide-number { display: none !important; }")
        pages = await pg.query_selector_all('.pdf-page')
        for i, el in enumerate(pages):
            await el.screenshot(path=str(outdir / f"slide-{i+1:03d}.png"))
        await b.close()
    return data

# ---------------------------------------------------------------- typst に直す
def esc(s):
    """typst の本文として安全な文字列にする．"""
    s = s.replace('\\', '\\\\')
    return re.sub(r'([#$*_@<>`\[\]~=/+\-])', lambda m: '\\' + m.group(1), s) if s else s

def esc_str(s):
    return s.replace('\\', '\\\\').replace('"', '\\"')

# 日本語の行の継ぎ目: org で改行した所は html では空白になるが，和文どうしの間なら詰める
CJK = r'\u3000-\u30ff\u3400-\u9fff\uf900-\ufaff\uff00-\uffef'
def squash(s):
    s = unicodedata.normalize('NFC', s)
    s = re.sub(rf'(?<=[{CJK}])\s*\n\s*(?=[{CJK}])', '', s)
    return re.sub(r'\s+', ' ', s)

def inline(node):
    if isinstance(node, str):
        return esc(squash(node))
    tag, kids = node[0], node[1:]
    if tag == 'math':
        tex, display = kids[0], kids[1]
        return f'#raw("{esc_str(tex.strip())}")'
    if tag in ('strong', 'b'):
        body = ''.join(inline(k) for k in kids).strip()
        return f'#strong[{body}]' if body else ''
    if tag in ('em', 'i'):
        body = ''.join(inline(k) for k in kids).strip()
        return f'#emph[{body}]' if body else ''
    if tag == 'code':
        return f'#raw("{esc_str(text_of(node))}")'
    if tag == 'a':
        href, body = kids[0], ''.join(inline(k) for k in kids[1:])
        if href.startswith(('http://', 'https://', 'mailto:')):
            return f'#link("{esc_str(href)}")[{body}]'
        return body
    if tag == 'br':
        return ' \\\n'
    return ''.join(inline(k) for k in kids)

def text_of(node):
    if isinstance(node, str): return node
    if node[0] == 'math': return node[1]
    if node[0] == 'a': return ''.join(text_of(k) for k in node[2:])
    return ''.join(text_of(k) for k in node[1:])

BLOCKS = {'p', 'div', 'ul', 'ol', 'li', 'aside', 'section', 'blockquote', 'pre', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'}

def blocks(node, out):
    """ノートの木を typst の段落の並びにする．"""
    if isinstance(node, str) or node[0] not in BLOCKS:
        txt = inline(node).strip()
        if txt: out.append(txt)
        return
    tag, kids = node[0], node[1:]
    if tag in ('ul', 'ol'):
        mark = '-' if tag == 'ul' else '+'
        for k in kids:
            if not isinstance(k, str) and k[0] == 'li':
                sub = []
                for kk in k[1:]: blocks(kk, sub)
                if sub: out.append(f'{mark} ' + '\n  '.join(sub))
        return
    if tag == 'pre':
        out.append(f'#raw(block: true, "{esc_str(text_of(node))}")')
        return
    # 子に段落があれば段落ごと，無ければまとめて 1 段落
    if any(not isinstance(k, str) and k[0] in BLOCKS for k in kids):
        buf = []
        for k in kids:
            if isinstance(k, str) or k[0] not in BLOCKS:
                buf.append(k)
            else:
                if buf:
                    txt = ''.join(inline(b) for b in buf).strip()
                    if txt: out.append(txt)
                    buf = []
                blocks(k, out)
        if buf:
            txt = ''.join(inline(b) for b in buf).strip()
            if txt: out.append(txt)
    else:
        txt = ''.join(inline(k) for k in kids).strip()
        if txt:
            out.append(f'#strong[{txt}]' if tag[0] == 'h' else txt)

TEMPLATE = r'''#set document(title: "{title_str}")
#set page(paper: "a4", margin: (x: 18mm, top: 16mm, bottom: 16mm),
  header: align(right, text(7.5pt, fill: luma(120))[{title}]),
  footer: context align(center, text(8pt, fill: luma(120), counter(page).display("1 / 1", both: true))))
#set text(font: ("Hiragino Sans", "Hiragino Kaku Gothic ProN", "Noto Sans CJK JP", "Noto Sans JP", "Yu Gothic"),
          size: {font_size}, lang: "ja")
#set par(justify: true, leading: 0.62em, spacing: 0.75em)
#set list(indent: 0.6em)
#set enum(indent: 0.6em)
#show raw: set text(font: ("Menlo", "DejaVu Sans Mono", "Noto Sans Mono"), size: 0.92em)

#let unit(img, no, total, notes) = block(width: 100%, below: 0mm, {{
  block(breakable: false, width: 100%, below: 2.2mm, {{
    align(center, box(stroke: 0.4pt + luma(170), image(img, width: {img_width})))
    v(0.8mm)
    align(center, text(7.5pt, fill: luma(120))[#no / #total])
  }})
  notes
}})
#let sep = {{ v(3mm); line(length: 100%, stroke: 0.3pt + luma(200)); v(3mm) }}

'''

def build_typ(data, imgdir, per_page, img_width, font_size):
    pages = data['pages']
    # 断片ごとに頁が分かれていたら (pdfSeparateFragments)，同じスライドの最後の頁だけを使う
    keep = []
    for i, pg in enumerate(pages):
        nxt = pages[i + 1] if i + 1 < len(pages) else None
        if nxt and pg['id'] and nxt['id'] == pg['id']:
            continue
        keep.append(pg)
    total = len(keep)
    parts = [TEMPLATE.format(title=esc(data['title']), title_str=esc_str(data['title']),
                             img_width=img_width, font_size=font_size)]
    for n, pg in enumerate(keep, 1):
        paras = []
        for note in pg['notes']:
            blocks(note, paras)
        notes = '\n\n'.join(paras)
        img = f"{imgdir}/slide-{pg['index']+1:03d}.png"
        parts.append(f'#unit("{esc_str(img)}", {n}, {total}, [\n{notes}\n])\n')
        if n < total:
            parts.append('#pagebreak(weak: true)\n' if n % per_page == 0 else '#sep\n')
    return ''.join(parts), total

def find_typst():
    q = shutil.which('quarto')
    if q: return [q, 'typst', 'compile']
    t = shutil.which('typst')
    if t: return [t, 'compile']
    sys.exit('quarto も typst も見つからない')

def main():
    ap = argparse.ArgumentParser(description='revealjs の html からスライドと発表者ノートの A4 縦の PDF を作る')
    ap.add_argument('html')
    ap.add_argument('-o', '--output', help='出力の PDF (既定: <html の名前>-notes.pdf)')
    ap.add_argument('--per-page', type=int, default=2, help='1 頁のスライドの枚数 (既定 2)')
    ap.add_argument('--img-width', default='118mm', help='スライドの幅 (既定 118mm)')
    ap.add_argument('--font-size', default='9pt', help='ノートの文字の大きさ (既定 9pt)')
    ap.add_argument('--scale', type=float, default=2, help='スライドの画像の解像度の倍率 (既定 2)')
    ap.add_argument('--keep', action='store_true', help='途中の typ と PNG を残す (<出力>_files/)')
    a = ap.parse_args()

    src = Path(a.html)
    out = Path(a.output) if a.output else src.with_name(src.stem + '-notes.pdf')
    work = out.with_name(out.stem + '_files')
    if work.exists(): shutil.rmtree(work)
    work.mkdir(parents=True)
    imgdir = work / 'img'; imgdir.mkdir()

    data = asyncio.run(capture(src, imgdir, a.scale, os.environ.get('OXQ_MATHJAX_DIR')))
    typ, total = build_typ(data, 'img', a.per_page, a.img_width, a.font_size)
    typ_path = work / 'notes.typ'
    typ_path.write_text(typ, encoding='utf-8')
    cmd = find_typst() + [str(typ_path.resolve()), str(out.resolve())]
    # 見つからない字体の警告 (macOS と Linux で字体の名前が違う) は，失敗したときだけ見せる
    r = subprocess.run(cmd, cwd=work, capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stderr)
        sys.exit(f'typst で失敗した (途中のファイルは {work})')
    if not a.keep: shutil.rmtree(work)
    print(f'{out}  ({total} 枚のスライド)')

if __name__ == '__main__':
    main()
