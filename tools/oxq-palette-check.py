#!/usr/bin/env python3
# oxq-palette-check.py — palette の callout の色を調べる (役割の色相が離れているか，地の上で読めるか)
#
# 使い方: python3 tools/oxq-palette-check.py [_quarto/scss/jade-palette.scss ...]   (省くと _quarto/scss/*-palette.scss 全部)
#
# callout は役割で使う (README.org の「callout の役割」): note = 説明，important = 要，tip = 問題，
# warning = 注意，caution = 頁の結論の一文．どの palette でも 5 つが色相で見分けられるよう，
#   - 5 つの $callout-color-* の OKLCH の色相が互いに --min-hue (既定 40°) 以上離れていること
#   - $callout-color-* と $callout-bg-* のコントラスト比が --min-contrast (既定 4.5) 以上であること
#   - note 以外の 4 つ (important / tip / warning / caution) の色相が主色 ($oer-primary．見出し・リンクの色) と
#     --min-primary (既定 35°) 以上離れていること (note は主色にする約束なので比べない．結論の一文が見出しと同じ色にならないように)
#   - PDF と html (白い頁．_quarto/lib/callout-colors.lua) で使う色 ($doc-callout-color-* があればそれ，無ければ $callout-color-*) が
#     白の上で --min-contrast 以上あること．$doc-callout-color-* があれば (暗い palette．dracula) その 5 つの色相も --min-hue 以上離れていること
# を調べ，満たさない組を書き出す．どれかあれば終了コード 1．palette を足す・直すときに走らせる．
# 標準の部品だけで動く．値は scss の行 `$callout-color-note: #0B7558 !default;` から読む (#rrggbb のみ)．

import argparse, glob, math, re, sys
from pathlib import Path

ROLES = ['note', 'important', 'tip', 'warning', 'caution']


def _lin(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _rgb(h):
    h = h.lstrip('#')
    return [_lin(int(h[i:i + 2], 16)) for i in (0, 2, 4)]


def hue(h):
    """OKLCH の色相 (度)．"""
    r, g, b = _rgb(h)
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return math.degrees(math.atan2(bb, a)) % 360


def contrast(x, y):
    lum = lambda h: sum(w * c for w, c in zip((0.2126, 0.7152, 0.0722), _rgb(h)))
    a, b = sorted((lum(x), lum(y)), reverse=True)
    return (a + 0.05) / (b + 0.05)


def read(path):
    text = Path(path).read_text(encoding='utf-8')
    get = lambda kind, role: (re.search(r'^\$callout-%s-%s:\s*(#[0-9A-Fa-f]{6})\b' % (kind, role), text, re.M) or [None, None])[1]
    prim = re.search(r'^\$oer-primary:\s*(#[0-9A-Fa-f]{6})\b', text, re.M)
    doc = {r: (re.search(r'^\$doc-callout-color-%s:\s*(#[0-9A-Fa-f]{6})\b' % r, text, re.M) or [None, None])[1] for r in ROLES}
    return {r: (get('color', r), get('bg', r)) for r in ROLES}, (prim.group(1) if prim else None), doc


def main():
    ap = argparse.ArgumentParser(description="palette の callout の色を調べる")
    ap.add_argument('files', nargs='*')
    ap.add_argument('--min-hue', type=float, default=40)
    ap.add_argument('--min-contrast', type=float, default=4.5)
    ap.add_argument('--min-primary', type=float, default=35)
    a = ap.parse_args()
    files = a.files or sorted(glob.glob(str(Path(__file__).resolve().parent.parent / '_quarto/scss/*-palette.scss')))
    bad = 0
    for f in files:
        cols, primary, doc = read(f)
        name = Path(f).name.replace('-palette.scss', '')
        missing = [r for r, (c, _) in cols.items() if not c]
        hs = {r: hue(c) for r, (c, _) in cols.items() if c}
        line = '  '.join(f'{r} {hs[r]:.0f}°' for r in ROLES if r in hs)
        if primary:
            line += f'  | primary {hue(primary):.0f}°'
        probs = []
        if missing:
            probs.append('値が読めない: ' + ', '.join(missing))
        rs = [r for r in ROLES if r in hs]
        for i, x in enumerate(rs):
            for y in rs[i + 1:]:
                d = abs(hs[x] - hs[y]); d = min(d, 360 - d)
                if d < a.min_hue:
                    probs.append(f'{x}–{y} の色相が近い ({d:.0f}°)')
        if primary:
            hp = hue(primary)
            for r in ROLES[1:]:
                if r in hs:
                    d = abs(hs[r] - hp); d = min(d, 360 - d)
                    if d < a.min_primary:
                        probs.append(f'{r} の色相が主色に近い ({d:.0f}°)')
        for r, (c, bg) in cols.items():
            if c and bg and contrast(c, bg) < a.min_contrast:
                probs.append(f'{r} の地の上のコントラストが低い ({contrast(c, bg):.1f}:1)')
        own_doc = any(doc.values())
        dcols = {r: (doc[r] if own_doc else c) for r, (c, _) in cols.items()}
        if own_doc:
            ds = {r: hue(c) for r, c in dcols.items() if c}
            line += '\n' + f'{"  (doc)":10s} ' + '  '.join(f'{r} {ds[r]:.0f}°' for r in ROLES if r in ds)
            rs = [r for r in ROLES if r in ds]
            for i, x in enumerate(rs):
                for y in rs[i + 1:]:
                    d = abs(ds[x] - ds[y]); d = min(d, 360 - d)
                    if d < a.min_hue:
                        probs.append(f'(doc) {x}–{y} の色相が近い ({d:.0f}°)')
        for r, c in dcols.items():
            if c and contrast(c, '#ffffff') < a.min_contrast:
                probs.append(f'(doc) {r} の白の上のコントラストが低い ({contrast(c, "#ffffff"):.1f}:1)')
        print(f'{name:10s} {line}')
        for p in probs:
            print(f'{"":10s} ! {p}')
        bad += len(probs)
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
