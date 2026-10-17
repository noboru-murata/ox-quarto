#!/usr/bin/env python3
# oxq-mathjax-check.py — 文書中の全数式を MathJax 3 で試験的に読み込み, 解釈できないものを行番号つきで出す
#
# 使い方:
#   oxq-mathjax-check.py FILE.qmd [FILE2.qmd ...]      # qmd / md: $$..$$ と $..$ を検査
#   oxq-mathjax-check.py FILE.org                      # org: \(..\) \[..\] $$..$$ と #+begin_export markdown 内の $$..$$ を検査
#   (org の数式環境 \begin{align}..\end{align} も検査する)
#   一度だけ: (cd tools/oxq-mathjax-check && npm install)    # mathjax-full 3.2.2 を入れる (node が必要)
#
# - MathJax は mathtools 拡張つき・bussproofs なしで読み込む (Quarto の html と同じ程度の範囲).
# - 検査するだけで文書は変更しない. エラーが 1 件でもあれば終了コード 1.
# - 数式の外の問題 (\ref の未解決など) は見ない.
import re, sys, json, os, subprocess, tempfile

HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'oxq-mathjax-check')


def extract(path):
    t = open(path, encoding='utf8').read()
    t2 = re.sub(r'\A---\n.*?\n---\n', lambda m: '\n' * m.group(0).count('\n'), t, count=1, flags=re.S)
    items = []
    line = lambda pos: t2.count('\n', 0, pos) + 1
    blank = lambda m: re.sub(r'[^\n]', ' ', m.group(0))
    work = t2
    # $$ ... $$ (行をまたぐ)
    for m in re.finditer(r'\$\$\n?(.*?)\n?\$\$', work, flags=re.S):
        items.append({'tex': m.group(1), 'display': True, 'line': line(m.start())})
    work = re.sub(r'\$\$.*?\$\$', blank, work, flags=re.S)
    if path.endswith('.org'):
        for m in re.finditer(r'\\\[(.*?)\\\]', work, flags=re.S):
            items.append({'tex': m.group(1), 'display': True, 'line': line(m.start())})
        work = re.sub(r'\\\[.*?\\\]', blank, work, flags=re.S)
        for m in re.finditer(r'(\\begin\{(align|alignat|equation|gather|multline|eqnarray|flalign)\*?\}.*?\\end\{\2\*?\})',
                             work, flags=re.S):
            items.append({'tex': m.group(1), 'display': True, 'line': line(m.start())})
        work = re.sub(r'\\begin\{(align|alignat|equation|gather|multline|eqnarray|flalign)\*?\}.*?\\end\{\1\*?\}', blank, work, flags=re.S)
        for m in re.finditer(r'\\\((.*?)\\\)', work, flags=re.S):
            items.append({'tex': m.group(1), 'display': False, 'line': line(m.start())})
    else:
        for m in re.finditer(r'(?<![\\$])\$([^$\n][^$]*?)\$(?!\$)', work):
            items.append({'tex': m.group(1), 'display': False, 'line': line(m.start())})
    return items


def main():
    files = sys.argv[1:]
    if not files:
        sys.exit('usage: oxq-mathjax-check.py FILE [FILE...]')
    if not os.path.isdir(os.path.join(HERE, 'node_modules', 'mathjax-full')):
        sys.exit(f'mathjax-full が未インストールです: (cd {HERE} && npm install)')
    bad = 0
    for f in files:
        items = extract(f)
        with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False, encoding='utf8') as tf:
            json.dump(items, tf, ensure_ascii=False)
        r = subprocess.run(['node', os.path.join(HERE, 'check.js'), tf.name], capture_output=True, text=True)
        os.unlink(tf.name)
        out = r.stdout.rstrip()
        print(f'== {f}\n{out}')
        if r.returncode != 0 or re.search(r'errors [1-9]', out):
            bad += 1
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
