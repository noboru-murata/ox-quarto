#!/usr/bin/env python3
# oxq-mathjax-check.py — 文書中の全数式を MathJax 3 で試験的に読み込み, 解釈できないものを行番号つきで出す
#
# 使い方:
#   oxq-mathjax-check.py FILE.qmd [FILE2.qmd ...]      # qmd / md: $$..$$ と $..$ と数式の環境を検査
#   oxq-mathjax-check.py FILE.org                      # org: \(..\) \[..\] $$..$$ と #+begin_export markdown 内の $$..$$ を検査
#   (どちらも数式の環境 \begin{align}..\end{align} など (* 付きも) を検査する．名前の無い環境は qmd にそのまま出るため)
#   検査しない所: qmd / md のコードブロック (``` / ~~~)．org の * COMMENT の節，# で始まるコメント行，
#   #+begin_comment / example / src の中．どれも空白に置き換えるので行番号は変わらない．
#   一度だけ: (cd tools/oxq-mathjax-check && npm install)    # mathjax-full 3.2.2 を入れる (node が必要)
#
# - MathJax は mathtools 拡張つき・bussproofs なしで読み込む (Quarto の html と同じ程度の範囲).
# - 検査するだけで文書は変更しない. エラーが 1 件でもあれば終了コード 1.
# - 数式の外の問題 (\ref の未解決など) は見ない.
import re, sys, json, os, subprocess, tempfile

HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'oxq-mathjax-check')


ENVS = r'align|alignat|equation|gather|multline|eqnarray|flalign'
ENV_RE = r'(\\begin\{(' + ENVS + r')\*?\}.*?\\end\{\2\*?\})'


def blank(m):
    return re.sub(r'[^\n]', ' ', m.group(0))


def mask_org(t):
    """org の検査しない所 (COMMENT の節，コメント行，comment / example / src ブロック) を空白にする (行番号は保つ)．"""
    t = re.sub(r'^[ \t]*#\+begin_(comment|example|src)\b.*?^[ \t]*#\+end_\1\b[^\n]*', blank, t, flags=re.S | re.M | re.I)
    t = re.sub(r'^[ \t]*#(?:[ \t][^\n]*)?$', blank, t, flags=re.M)
    lines = t.split('\n')
    level = None
    for i, l in enumerate(lines):
        m = re.match(r'(\*+) ', l)
        if m:
            n = len(m.group(1))
            if level is not None and n <= level:
                level = None
            if level is None and re.match(r'\*+ +COMMENT\b', l):
                level = n
        if level is not None:
            lines[i] = ' ' * len(l)
    return '\n'.join(lines)


def extract(path):
    t = open(path, encoding='utf8').read()
    t2 = re.sub(r'\A---\n.*?\n---\n', lambda m: '\n' * m.group(0).count('\n'), t, count=1, flags=re.S)
    if path.endswith('.org'):
        t2 = mask_org(t2)
    else:
        t2 = re.sub(r'^(```|~~~).*?^\1[ \t]*$', blank, t2, flags=re.S | re.M)
    items = []
    line = lambda pos: t2.count('\n', 0, pos) + 1
    work = t2
    # $$ ... $$ (行をまたぐ)
    for m in re.finditer(r'\$\$\n?(.*?)\n?\$\$', work, flags=re.S):
        items.append({'tex': m.group(1), 'display': True, 'line': line(m.start())})
    work = re.sub(r'\$\$.*?\$\$', blank, work, flags=re.S)
    # 数式の環境 (org でも qmd でも．$$ の中のものは上で消してある)
    for m in re.finditer(ENV_RE, work, flags=re.S):
        items.append({'tex': m.group(1), 'display': True, 'line': line(m.start())})
    work = re.sub(ENV_RE, blank, work, flags=re.S)
    if path.endswith('.org'):
        for m in re.finditer(r'\\\[(.*?)\\\]', work, flags=re.S):
            items.append({'tex': m.group(1), 'display': True, 'line': line(m.start())})
        work = re.sub(r'\\\[.*?\\\]', blank, work, flags=re.S)
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
