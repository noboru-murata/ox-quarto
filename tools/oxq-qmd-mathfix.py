#!/usr/bin/env python3
# oxq-qmd-mathfix.py — ox-quarto が書き出した qmd の数式まわりの後処理 (その場で書き換える)
#
# 使い方: oxq-qmd-mathfix.py FILE.qmd [FILE2.qmd ...]
#
# - 行内数式の閉じ $ の直後に数字が続くと pandoc は数式と認めない ($x$2 など) ので, 空の HTML コメント <!----> をはさむ.
#   (org で \(x\)2 のように書いた数式が qmd で $x$2 になったときに起こる. html/tex どちらでも見た目は変わらない.)
# - 何度実行しても結果は同じ (冪等).
import re, sys


def fix(t):
    return re.sub(r'(?<![\\$])(\$(?!\$)[^$\n]+(?<![\\ ])\$)(?=\d)', r'\1<!---->', t)


if __name__ == '__main__':
    for f in sys.argv[1:]:
        s = open(f, encoding='utf8').read()
        open(f, 'w', encoding='utf8').write(fix(s))
