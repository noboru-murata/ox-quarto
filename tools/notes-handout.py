#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = ["playwright"]
# ///
# notes-handout.py — revealjs の html から，スライドと発表者ノートを並べた A4 縦の PDF を作る
#
# 使い方 (uv が playwright を用意する．上の script の欄が必要なものの宣言):
#   uv run tools/notes-handout.py talk.html                 → talk-notes.pdf
#   uv run tools/notes-handout.py talk.html -o memo.pdf --per-page 1
#   uv run tools/notes-handout.py talk.html --layout side   → 左にスライド，右にノート (幅は 60:40)
#   uv run tools/notes-handout.py talk.html --layout side --ratio 55:45   → 左右の幅の比を変える
#   uv run tools/notes-handout.py talk.html --engine lualatex --keep   → LaTeX で組み，tex を残す
#   uv run tools/notes-handout.py talk.html --no-notes      → ノートなし．スライドだけを 1 頁に 6 枚 (2 列 × 3 段)
#                                                              → talk-handout.pdf (公開用の配布物．--per-page 1〜3 は 1 列)
# 初めに一度だけ Chromium を入れる:  uv run --with playwright playwright install chromium
# (uv を使わないなら，playwright を入れた python で python3 tools/notes-handout.py …)
#
# 仕組み:
#   1. html を Chromium (playwright) で reveal の PDF 表示 (?print-pdf) にして，スライドを 1 枚ずつ PNG にする
#      (PDF と同じ見た目: 断片 (fragment) は全部出た状態，暗い頁は $print-dark-slides に従う)．
#   2. 各スライドの発表者ノート (::: notes → <aside class="notes">) を取り出し，typst の文に直す
#      (段落・箇条書き・太字・斜体・コード・リンク・数式 (TeX のまま) を扱う)．
#   3. typst に組み，quarto typst compile で PDF にする．--layout stack (既定): 1 頁に --per-page 枚 (既定 2)，上にスライド・下にノート．
#      --layout side: 左にスライド・右にノートの行を詰めて流す (--per-page を付ければその枚数で改頁)．
#      左右の幅は --ratio (既定 60:40 = スライド 101.4mm) か --img-width で決める．
#      65:35 (110mm) がスライドが 1 頁に 3 枚並ぶ上限 (ノートが短いとき)．
#      ノートの無いスライドはスライドだけ．ノートが長くて入りきらないときは次の頁に続く．
#      --no-notes: ノートを一切載せず，スライドだけを格子に並べる (--per-page 既定 6．4 以上は 2 列)．
#      ノートは html に残っていても読まない (公開用の配布物．talks/PUBLISHING.md)．typst だけで組む．
#
# 前提: uv (brew install uv) と Chromium (上)，quarto (typst を同梱)．
#       --engine lualatex / xelatex では TeX Live (jlreq / bxjsarticle，paracol，fancyhdr，lastpage，enumitem，needspace)．
#       文書クラスは lualatex では jlreq，xelatex では bxjsarticle (--class で変えられる)．ノートの数式は LaTeX で組まれる．
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
    try:
        from playwright.async_api import async_playwright
    except ImportError:
        sys.exit('playwright が無い: uv run tools/notes-handout.py … で動かす (brew install uv)．\n'
                 'Chromium は uv run --with playwright playwright install chromium で入れる')
    url = Path(html_path).resolve().as_uri() + "?print-pdf"
    async with async_playwright() as p:
        try:
            b = await p.chromium.launch()
        except Exception as e:
            if "Executable doesn't exist" in str(e):
                sys.exit('playwright の Chromium が無い (playwright の版が変わったときも)．次で入れる:\n'
                         '  uv run --with playwright playwright install chromium')
            raise
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


# ---------------------------------------------------------------- LaTeX に直す (--engine lualatex / xelatex)
TEX_SPECIAL = {'\\': r'\textbackslash{}', '{': r'\{', '}': r'\}', '$': r'\$', '&': r'\&', '#': r'\#',
               '^': r'\textasciicircum{}', '_': r'\_', '%': r'\%', '~': r'\textasciitilde{}'}
def tesc(s):
    return ''.join(TEX_SPECIAL.get(c, c) for c in s)

def inline_tex(node):
    if isinstance(node, str):
        return tesc(squash(node))
    tag, kids = node[0], node[1:]
    if tag == 'math':                       # ノートの数式は TeX なのでそのまま組む
        tex, display = kids[0].strip(), kids[1]
        return f'\\[{tex}\\]' if display else f'\\({tex}\\)'
    if tag in ('strong', 'b'):
        body = ''.join(inline_tex(k) for k in kids).strip()
        return f'\\textbf{{{body}}}' if body else ''
    if tag in ('em', 'i'):
        body = ''.join(inline_tex(k) for k in kids).strip()
        return f'\\emph{{{body}}}' if body else ''
    if tag == 'code':
        return f'\\texttt{{{tesc(text_of(node))}}}'
    if tag == 'a':
        href, body = kids[0], ''.join(inline_tex(k) for k in kids[1:])
        if href.startswith(('http://', 'https://', 'mailto:')):
            return f'\\href{{{href.replace("%", chr(92) + "%").replace("#", chr(92) + "#")}}}{{{body}}}'
        return body
    if tag == 'br':
        return '\\\\\n'
    return ''.join(inline_tex(k) for k in kids)

def blocks_tex(node, out):
    """ノートの木を LaTeX の段落の並びにする．"""
    if isinstance(node, str) or node[0] not in BLOCKS:
        txt = inline_tex(node).strip()
        if txt: out.append(txt)
        return
    tag, kids = node[0], node[1:]
    if tag in ('ul', 'ol'):
        env = 'itemize' if tag == 'ul' else 'enumerate'
        items = []
        for k in kids:
            if not isinstance(k, str) and k[0] == 'li':
                sub = []
                for kk in k[1:]: blocks_tex(kk, sub)
                if sub: items.append('\\item ' + '\n\n'.join(sub))
        if items:
            out.append(f'\\begin{{{env}}}\n' + '\n'.join(items) + f'\n\\end{{{env}}}')
        return
    if tag == 'pre':
        out.append('\\begin{verbatim}\n' + text_of(node) + '\n\\end{verbatim}')
        return
    if any(not isinstance(k, str) and k[0] in BLOCKS for k in kids):
        buf = []
        def flush():
            txt = ''.join(inline_tex(b) for b in buf).strip()
            if txt: out.append(txt)
            buf.clear()
        for k in kids:
            if isinstance(k, str) or k[0] not in BLOCKS:
                buf.append(k)
            else:
                flush(); blocks_tex(k, out)
        flush()
    else:
        txt = ''.join(inline_tex(k) for k in kids).strip()
        if txt:
            out.append(f'\\textbf{{{txt}}}' if tag[0] == 'h' else txt)

TEX_CLASS = {
    # 文書クラス: jlreq (lualatex 向き．JIS X 4051 の組版) と bxjsarticle (lualatex / xelatex)
    'jlreq': r"\documentclass[paper=a4,fontsize={font_size}]{{jlreq}}" "\n"
             r"\usepackage{{geometry}}",
    'bxjsarticle': r"\documentclass[a4paper,{engine},ja=standard,base={font_size}]{{bxjsarticle}}",
}
TEX_TEMPLATE = r"""{docclass}
\geometry{{top=16mm,bottom=18mm,hmargin=18mm,headsep=4mm,footskip=8mm}}
\usepackage{{graphicx,xcolor,amsmath,amssymb,enumitem,fancyhdr,lastpage,paracol,needspace}}
\renewcommand{{\familydefault}}{{\sfdefault}}  % typst 版と同じくゴシック (luatexja / xeCJK のどちらでも)
\ifdefined\kanjifamilydefault\renewcommand{{\kanjifamilydefault}}{{\gtdefault}}\fi
\ifdefined\CJKfamilydefault\renewcommand{{\CJKfamilydefault}}{{\CJKsfdefault}}\fi
\usepackage[hidelinks]{{hyperref}}
\definecolor{{rulegray}}{{gray}}{{0.78}}
\definecolor{{capgray}}{{gray}}{{0.47}}
\pagestyle{{fancy}}\fancyhf{{}}
\renewcommand{{\headrulewidth}}{{0pt}}
\fancyhead[R]{{\scriptsize\color{{capgray}}{title}}}
\fancyfoot[C]{{\footnotesize\color{{capgray}}\thepage\ / \pageref*{{LastPage}}}}
\setlist{{nosep,leftmargin=1.4em}}
\setlength{{\parindent}}{{0pt}}
\setlength{{\parskip}}{{0.45em}}
\setlength{{\fboxsep}}{{0pt}}
\setlength{{\fboxrule}}{{0.4pt}}
\newcommand{{\slideimg}}[2]{{\fcolorbox{{rulegray}}{{white}}{{\includegraphics[width=\dimexpr#2-0.8pt\relax]{{#1}}}}}}
\newcommand{{\slideno}}[2]{{{{\scriptsize\color{{capgray}}#1 / #2}}}}
\newcommand{{\sep}}{{\par\vspace{{2mm}}{{\color{{rulegray}}\rule{{\linewidth}}{{0.3pt}}}}\par\vspace{{2mm}}}}
\setcolumnwidth{{{img_width},\dimexpr\textwidth-{img_width}-5mm\relax}}
\setlength{{\columnsep}}{{5mm}}
\begin{{document}}
"""

def build_tex(data, imgdir, per_page, img_width, font_size, layout, engine, cls):
    keep = unique_pages(data['pages'])
    total = len(keep)
    docclass = TEX_CLASS[cls].format(engine=engine, font_size=font_size)
    parts = [TEX_TEMPLATE.format(docclass=docclass, img_width=img_width, title=tesc(data['title']))]
    m = re.fullmatch(r'([\d.]+)mm', img_width)
    need = f'{float(m.group(1)) * 700 / 1050 + 8:.1f}mm' if m else '70mm'   # スライド (3:2) と番号の高さ
    for n, pg in enumerate(keep, 1):
        paras = []
        for note in pg['notes']:
            blocks_tex(note, paras)
        notes = '\n\n'.join(paras)
        img = f"{imgdir}/slide-{pg['index']+1:03d}.png"
        if layout == 'side':
            # スライドが頁の途中で切れて左右の段がずれないよう，スライドの高さが残っていなければ改頁
            parts.append(f'\\needspace{{{need}}}\n')
            parts.append('\\begin{paracol}{2}\n'
                         f'\\slideimg{{{img}}}{{\\linewidth}}\\par{{\\centering\\slideno{{{n}}}{{{total}}}\\par}}\n'
                         '\\switchcolumn\n' + (notes or '\\mbox{}') + '\n\\end{paracol}\n')
        else:
            parts.append('\\begin{minipage}{\\linewidth}\\centering\n'
                         f'\\slideimg{{{img}}}{{{img_width}}}\\par\\vspace{{0.8mm}}\\slideno{{{n}}}{{{total}}}\n'
                         '\\end{minipage}\\par\\vspace{1.5mm}\n' + notes + '\n')
        if n < total:
            parts.append('\\clearpage\n' if per_page and n % per_page == 0 else '\\sep\n')
    parts.append('\\end{document}\n')
    return ''.join(parts), total

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
// --layout side: 左にスライド，右にノート (ノートが長ければ行が伸び，頁をまたぐ)
#let unit-side(img, no, total, notes) = grid(columns: ({img_width}, 1fr), column-gutter: 5mm, {{
  box(stroke: 0.4pt + luma(170), image(img, width: 100%))
  v(0.6mm)
  align(center, text(7.5pt, fill: luma(120))[#no / #total])
}}, notes)
#let sep = {{ v(3mm); line(length: 100%, stroke: 0.3pt + luma(200)); v(3mm) }}

'''

def unique_pages(pages):
    # 断片ごとに頁が分かれていたら (pdfSeparateFragments)，同じスライドの最後の頁だけを使う
    keep = []
    for i, pg in enumerate(pages):
        nxt = pages[i + 1] if i + 1 < len(pages) else None
        if nxt and pg['id'] and nxt['id'] == pg['id']:
            continue
        keep.append(pg)
    return keep

def build_typ(data, imgdir, per_page, img_width, font_size, layout='stack'):
    keep = unique_pages(data['pages'])
    total = len(keep)
    parts = [TEMPLATE.format(title=esc(data['title']), title_str=esc_str(data['title']),
                             img_width=img_width, font_size=font_size)]
    for n, pg in enumerate(keep, 1):
        paras = []
        for note in pg['notes']:
            blocks(note, paras)
        notes = '\n\n'.join(paras)
        img = f"{imgdir}/slide-{pg['index']+1:03d}.png"
        fn = 'unit-side' if layout == 'side' else 'unit'
        parts.append(f'#{fn}("{esc_str(img)}", {n}, {total}, [\n{notes}\n])\n')
        if n < total:
            parts.append('#pagebreak(weak: true)\n' if per_page and n % per_page == 0 else '#sep\n')
    return ''.join(parts), total

TEMPLATE_SLIDES = r'''#set document(title: "{title_str}")
#set page(paper: "a4", margin: (x: 18mm, top: 16mm, bottom: 16mm),
  header: align(right, text(7.5pt, fill: luma(120))[{title}]),
  footer: context align(center, text(8pt, fill: luma(120), counter(page).display("1 / 1", both: true))))
#set text(font: ("Hiragino Sans", "Hiragino Kaku Gothic ProN", "Noto Sans CJK JP", "Noto Sans JP", "Yu Gothic"),
          size: 9pt, lang: "ja")

// tall: 縦に長い頁 (内容がはみ出したスライド) は，ふつうのスライドの高さに縮めて中央に置く
#let cell(img, no, total, tall: none) = block(breakable: false, width: 100%, {{
  if tall == none {{ box(stroke: 0.4pt + luma(170), image(img, width: 100%)) }}
  else {{ align(center, box(stroke: 0.4pt + luma(170), image(img, height: tall))) }}
  v(0.6mm)
  align(center, text(7pt, fill: luma(120))[#no / #total])
}})

'''

def png_size(path):
    import struct
    with open(path, 'rb') as f:
        head = f.read(24)
    return struct.unpack('>II', head[16:24]) if head[:8] == b'\x89PNG\r\n\x1a\n' else (0, 0)

def mm(length):
    m = re.fullmatch(r'(\d+(?:\.\d+)?)mm', str(length))
    return float(m.group(1)) if m else None

def slides_layout(per_page, img_width=None):
    """ノートなしの並べ方: (列の数, 格子の幅)．"""
    cols = 2 if per_page >= 4 else 1
    if img_width:
        width = img_width if cols == 1 else '100%'
    else:
        width = {1: '174mm', 2: '150mm', 3: '112mm'}.get(per_page, '100%')
    return cols, width

def build_typ_slides(data, imgdir, per_page, img_width=None, imgdir_abs=None):
    """--no-notes: スライドだけを 1 頁に per_page 枚ずつ格子に並べる．ノートは読まない．"""
    keep = unique_pages(data['pages'])
    total = len(keep)
    cols, width = slides_layout(per_page, img_width)
    # 1 枚の幅 (mm)．本文の幅 174mm (A4 − 余白 18mm × 2)
    cell_w = (174 - 6) / 2 if cols == 2 else (mm(width) or 174)
    sizes = [png_size(Path(imgdir_abs) / f"slide-{pg['index']+1:03d}.png") for pg in keep] if imgdir_abs else []
    ratio = 700 / 1050
    if sizes:
        rs = sorted(h / w for w, h in sizes if w)
        ratio = rs[len(rs) // 2] if rs else ratio          # ふつうのスライドの縦横比 (中央値)
    parts = [TEMPLATE_SLIDES.format(title=esc(data['title']), title_str=esc_str(data['title']))]
    for start in range(0, total, per_page):
        cells = []
        for n, pg in enumerate(keep[start:start + per_page], start + 1):
            img = f"{imgdir}/slide-{pg['index']+1:03d}.png"
            w, h = sizes[n - 1] if sizes else (0, 0)
            tall = f', tall: {cell_w * ratio:.1f}mm' if w and h / w > ratio * 1.02 else ''
            cells.append(f'cell("{esc_str(img)}", {n}, {total}{tall})')
        parts.append(f'#align(center, block(width: {width}, grid(columns: {cols}, column-gutter: 6mm, '
                     f'row-gutter: 5mm, {", ".join(cells)})))\n')
        if start + per_page < total:
            parts.append('#pagebreak()\n')
    return ''.join(parts), total

def find_typst():
    q = shutil.which('quarto')
    if q: return [q, 'typst', 'compile']
    t = shutil.which('typst')
    if t: return [t, 'compile']
    sys.exit('quarto も typst も見つからない')

# side の左右の幅: 本文の幅 (A4 210mm − 左右の余白 18mm×2) から段の間 5mm を引いた残りを比で分ける
SIDE_SPAN_MM = 210 - 2 * 18 - 5
SIDE_RATIO = '60:40'

def ratio_width(s):
    """'60:40' / '60/40' / '60-40' / '0.6' / '60%' → スライドの幅 ('101.4mm')．"""
    t = str(s).strip()
    m = re.fullmatch(r'(\d+(?:\.\d+)?)\s*[:/-]\s*(\d+(?:\.\d+)?)', t)
    if m:
        a, b = float(m.group(1)), float(m.group(2))
        f = a / (a + b) if a + b > 0 else 0
    else:
        m = re.fullmatch(r'(\d+(?:\.\d+)?)\s*(%?)', t)
        f = (float(m.group(1)) / (100 if m.group(2) or float(m.group(1)) > 1 else 1)) if m else 0
    if not 0.2 <= f <= 0.8:
        sys.exit(f"--ratio '{s}' が読めない (例 60:40，55/45，0.6．スライドの側は 20〜80%)")
    return f'{f * SIDE_SPAN_MM:.1f}mm'

def main():
    ap = argparse.ArgumentParser(description='revealjs の html からスライドと発表者ノートの A4 縦の PDF を作る')
    ap.add_argument('html')
    ap.add_argument('-o', '--output', help='出力の PDF (既定: <html の名前>-notes.pdf)')
    ap.add_argument('--layout', choices=['stack', 'side'], default='stack',
                    help='stack: 上にスライド・下にノート (既定)，side: 左にスライド・右にノート')
    ap.add_argument('--per-page', type=int, default=None,
                    help='1 頁のスライドの枚数 (既定: stack は 2，side は 0 = 詰めて流す)')
    ap.add_argument('--img-width', default=None, help='スライドの幅 (既定: stack 118mm，side は --ratio から)')
    ap.add_argument('--ratio', default=None,
                    help=f'side の左右 (スライド:ノート) の幅の比 (既定 {SIDE_RATIO}．55:45，60/40，0.6 とも書ける．--img-width が優先)')
    ap.add_argument('--font-size', default=None, help='ノートの文字の大きさ (既定: stack 9pt，side 8.5pt)')
    ap.add_argument('--engine', choices=['typst', 'lualatex', 'xelatex'], default='typst',
                    help='PDF にする組版 (既定 typst．lualatex / xelatex は LaTeX (bxjsarticle) で組む)')
    ap.add_argument('--class', dest='docclass', choices=['jlreq', 'bxjsarticle'], default=None,
                    help='LaTeX の文書クラス (既定: lualatex は jlreq，xelatex は bxjsarticle．jlreq は xelatex では使えない)')
    ap.add_argument('--scale', type=float, default=2, help='スライドの画像の解像度の倍率 (既定 2)')
    ap.add_argument('--keep', '--keep-tex', action='store_true',
                    help='組版の元 (<出力の名前>.tex / .typ) と画像を <出力の名前>_notes-src/ に残す')
    ap.add_argument('--no-notes', action='store_true',
                    help='ノートを載せず，スライドだけを並べる (公開用．既定の出力 <html の名前>-handout.pdf，'
                         '--per-page 既定 6．typst で組む．--layout / --ratio / --font-size は使わない)')
    a = ap.parse_args()
    side = a.layout == 'side'
    if a.no_notes:
        if a.per_page is None: a.per_page = 6
        if a.per_page < 1: sys.exit('--no-notes では --per-page を 1 以上に')
        if a.engine != 'typst':
            print(f'--no-notes は typst で組む (--engine {a.engine} は使わない)', file=sys.stderr)
            a.engine = 'typst'
    if a.per_page is None: a.per_page = 0 if side else 2
    if a.ratio and not side and not a.no_notes:
        print('--ratio は --layout side のときだけ使う (無視する)', file=sys.stderr)
    img_width_given = a.img_width
    if a.img_width is None: a.img_width = ratio_width(a.ratio or SIDE_RATIO) if side else '118mm'
    if a.font_size is None: a.font_size = '8.5pt' if side else '9pt'
    if a.docclass is None: a.docclass = 'jlreq' if a.engine == 'lualatex' else 'bxjsarticle'
    if a.engine == 'xelatex' and a.docclass == 'jlreq':
        sys.exit('jlreq は xelatex では使えない (lualatex にするか --class bxjsarticle)')
    if a.engine != 'typst' and not re.fullmatch(r'\d+(\.\d+)?pt', a.font_size):
        sys.exit('LaTeX では --font-size を pt で (例 9pt)')

    src = Path(a.html)
    out = Path(a.output) if a.output else src.with_name(src.stem + ('-handout.pdf' if a.no_notes else '-notes.pdf'))
    work = out.with_name(out.stem + '_notes-src')   # Quarto の <名前>_files とぶつからない名前
    if work.exists(): shutil.rmtree(work)
    work.mkdir(parents=True)
    imgdir = work / 'img'; imgdir.mkdir()

    data = asyncio.run(capture(src, imgdir, a.scale, os.environ.get('OXQ_MATHJAX_DIR')))
    if a.engine == 'typst':
        if a.no_notes:
            typ, total = build_typ_slides(data, 'img', a.per_page, img_width_given, imgdir)
        else:
            typ, total = build_typ(data, 'img', a.per_page, a.img_width, a.font_size, a.layout)
        src_path = work / (out.stem + '.typ')
        src_path.write_text(typ, encoding='utf-8')
        cmd = find_typst() + [str(src_path.resolve()), str(out.resolve())]
        # 見つからない字体の警告 (macOS と Linux で字体の名前が違う) は，失敗したときだけ見せる
        r = subprocess.run(cmd, cwd=work, capture_output=True, text=True)
        if r.returncode != 0:
            sys.stderr.write(r.stderr)
            sys.exit(f'typst で失敗した (途中のファイルは {work})')
    else:
        tex, total = build_tex(data, 'img', a.per_page, a.img_width, a.font_size, a.layout, a.engine, a.docclass)
        src_path = work / (out.stem + '.tex')
        src_path.write_text(tex, encoding='utf-8')
        exe = shutil.which(a.engine) or sys.exit(f'{a.engine} が見つからない')
        for _ in range(2):        # 2 回目で「頁 / 総頁」(lastpage) が埋まる
            r = subprocess.run([exe, '-interaction=nonstopmode', '-halt-on-error', src_path.name],
                               cwd=work, capture_output=True, text=True)
            if r.returncode != 0:
                sys.stderr.write(r.stdout[-3000:])
                sys.exit(f'{a.engine} で失敗した (途中のファイルは {work}，ログは {src_path.stem}.log)')
        shutil.copyfile(work / (out.stem + '.pdf'), out)
    if not a.keep: shutil.rmtree(work)
    print(f'{out}  ({total} 枚のスライド{"．ノートなし" if a.no_notes else ""})')

if __name__ == '__main__':
    main()
