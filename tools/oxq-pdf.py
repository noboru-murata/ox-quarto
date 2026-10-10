#!/usr/bin/env python3
# oxq-pdf.py — qmd から配布用の PDF を作る入口．front matter の notes-pdf で方式を選ぶ
#
# 使い方 (qmd のあるフォルダで):
#   python3 /path/to/ox-quarto/tools/oxq-pdf.py 講義.qmd               → 講義.pdf
#   python3 /path/to/ox-quarto/tools/oxq-pdf.py 講演.qmd -o memo.pdf
#   python3 /path/to/ox-quarto/tools/oxq-pdf.py 講演.qmd --html 講演.html   (書き出し済みの revealjs を使う)
#   python3 /path/to/ox-quarto/tools/oxq-pdf.py 講義.qmd -n                 (何をするかだけ表示)
#
# 方式 (front matter のキー．org では  #+QUARTO_OPTIONS: notes-pdf:slides notes-pdf-layout:side):
#   notes-pdf: slides     方式 1: revealjs のスライドの画像と発表者ノートを並べる (tools/notes-handout.py)
#   notes-pdf: document   方式 2: Quarto の pdf (無ければ typst) 形式．ノートは slide-notes (box / margin / …) に従う
#   無ければ: yaml に pdf / typst 形式があれば document (lecture，handout，report)，無ければ slides (talk)
# 方式 1 の細かい指定 (どれも省略できる．notes-handout.py の同名のオプションに渡す):
#   notes-pdf-layout: stack | side       notes-pdf-engine: typst | lualatex | xelatex
#   notes-pdf-class: jlreq | bxjsarticle notes-pdf-keep: true (tex / typ と画像を残す)
#   notes-pdf-per-page: 2                notes-pdf-img-width: 118mm      notes-pdf-font-size: 9pt
# 既定を yaml に書かないのは，org の #+QUARTO_OPTIONS と同じキーが front matter で重なるとエラーになるため．
#
# 前提: quarto．方式 1 は notes-handout.py の前提も: uv (brew install uv) と Chromium
#   (uv run --with playwright playwright install chromium を一度だけ)，LaTeX なら TeX Live．
#   uv があれば notes-handout.py を uv run で動かす (playwright は uv が用意する)．無ければこの python で動かす．
#   このスクリプト自体は python の標準の部品だけで動く (brew の python3 でよい)．

import argparse, json, os, shutil, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OPTS = ['layout', 'engine', 'class', 'keep', 'per-page', 'img-width', 'font-size']

def quarto():
    q = shutil.which('quarto') or sys.exit('quarto が見つからない')
    return q

def inspect(qmd):
    r = subprocess.run([quarto(), 'inspect', str(qmd)], capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stderr); sys.exit(f'quarto inspect {qmd} に失敗した')
    d = json.loads(r.stdout)
    formats = list(d.get('formats', {}))
    meta = {}
    for f in formats:                       # 形式ごとに同じ front matter が入っている
        meta.update({k: v for k, v in d['formats'][f].get('metadata', {}).items() if k.startswith('notes-pdf')})
    return formats, meta

def run(cmd, dry, cwd=None):
    print('$ ' + ' '.join(str(c) for c in cmd), flush=True)
    if not dry:
        r = subprocess.run(cmd, cwd=cwd)
        if r.returncode != 0: sys.exit(r.returncode)

def main():
    ap = argparse.ArgumentParser(description='qmd から配布用の PDF を作る (front matter の notes-pdf で方式を選ぶ)')
    ap.add_argument('qmd')
    ap.add_argument('-o', '--output', help='出力の PDF (既定: <qmd の名前>.pdf)')
    ap.add_argument('--html', help='方式 1 で使う書き出し済みの revealjs の html (無ければここで書き出す)')
    ap.add_argument('--method', choices=['slides', 'document'], help='front matter の notes-pdf より優先する')
    ap.add_argument('-n', '--dry-run', action='store_true', help='何をするかを表示するだけ')
    a = ap.parse_args()

    qmd = Path(a.qmd)
    if not qmd.exists(): sys.exit(f'{qmd} が無い')
    out = Path(a.output) if a.output else qmd.with_suffix('.pdf')
    formats, meta = inspect(qmd)
    doc_fmt = 'pdf' if 'pdf' in formats else ('typst' if 'typst' in formats else None)
    method = a.method or str(meta.get('notes-pdf', '')).strip() or ('document' if doc_fmt else 'slides')
    if method not in ('slides', 'document'):
        sys.exit(f"notes-pdf: '{method}' は slides か document")
    print(f'{qmd}: notes-pdf = {method}' + ('' if 'notes-pdf' in meta or a.method else ' (既定)'), flush=True)

    if method == 'document':
        if not doc_fmt:
            sys.exit(f'{qmd} の yaml に pdf / typst の形式が無い (notes-pdf: slides にするか，lecture.yaml などを使う)')
        run([quarto(), 'render', qmd.name, '--to', doc_fmt], a.dry_run, cwd=qmd.parent or None)
        made = qmd.with_suffix('.pdf')
        if not a.dry_run and made.resolve() != out.resolve():
            shutil.move(str(made), str(out))
        print(f'→ {out}')
        return

    # 方式 1: revealjs の html → notes-handout.py
    if 'revealjs' not in formats:
        sys.exit(f'{qmd} の yaml に revealjs の形式が無い (notes-pdf: document にする)')
    tmp_html = None
    if a.html:
        html = Path(a.html)
    else:
        # lecture では html 形式も <名前>.html を作るので，別の名前で書き出して後で消す
        tmp_html = qmd.with_name(qmd.stem + '-oxq-slides.html')
        run([quarto(), 'render', qmd.name, '--to', 'revealjs', '--output', tmp_html.name], a.dry_run,
            cwd=qmd.parent or None)
        html = tmp_html
    uv = shutil.which('uv') if not os.environ.get('OXQ_NO_UV') else None
    runner = [uv, 'run', '--quiet'] if uv else [sys.executable]
    cmd = runner + [str(HERE / 'notes-handout.py'), str(html), '-o', str(out)]
    for k in OPTS:
        v = meta.get(f'notes-pdf-{k}')
        if v is None or v == '': continue
        if k == 'keep':
            if v is True or str(v).lower() in ('true', 'yes', '1'): cmd.append('--keep')
        else:
            cmd += [f'--{k}', str(v)]
    run(cmd, a.dry_run)
    if tmp_html and not a.dry_run:
        tmp_html.unlink(missing_ok=True)
        shutil.rmtree(tmp_html.with_name(tmp_html.stem + '_files'), ignore_errors=True)
    print(f'→ {out}')

if __name__ == '__main__':
    main()
