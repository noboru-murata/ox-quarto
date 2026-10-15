#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = ["playwright"]
# ///
# oxq-thumb.py — html のページ (デモなど) を開いて PNG のサムネイルを撮る．#+begin_iframe の :poster 用
#
# 使い方 (uv が playwright を用意する．Chromium は notes-handout.py と同じく一度だけ入れておく:
#   uv run --with playwright playwright install chromium):
#   uv run --script /path/to/ox-quarto/tools/oxq-thumb.py "../demo/demo.html#mode=design&embed" -o figs/demo-thumb.png
#   uv run --script /path/to/ox-quarto/tools/oxq-thumb.py https://example.org/ -o figs/x.png --size 1050x700 --wait 3000
# org では
#   #+begin_iframe :src "../demo/demo.html#mode=design&embed" :fill "canvas" :poster "figs/demo-thumb.png"
#
# - src はローカルのファイル (相対パス．# や ? はそのまま渡る) か http(s) の URL．
# - --size は窓の大きさ (既定 1050x700 = :fill "canvas" のキャンバス)．枠に入れる iframe ならその大きさに．
# - --wait は開いてから撮るまでの待ち (ミリ秒．既定 2000)．計算や描画に時間のかかるデモは長めに．
# - --scale で画素の倍率 (既定 2．PDF で粗く見えないように)．
# - 撮った画像は講演の側に置き，git に入れるかは講演の側で決める．

import argparse, sys
from pathlib import Path
from urllib.parse import urlsplit


def to_url(src):
    if urlsplit(src).scheme in ("http", "https", "file"):
        return src
    path, sep, rest = src.partition("#")
    path, qsep, query = path.partition("?")
    p = Path(path).resolve()
    if not p.exists():
        sys.exit(f"oxq-thumb: ファイルが無い: {p}")
    url = p.as_uri()
    if qsep: url += "?" + query
    if sep:  url += "#" + rest
    return url


def main():
    ap = argparse.ArgumentParser(description="html のページを開いて PNG のサムネイルを撮る (iframe の :poster 用)")
    ap.add_argument("src", help="ファイル (相対パス．#… も可) か URL")
    ap.add_argument("-o", "--output", required=True, help="書き出す PNG")
    ap.add_argument("--size", default="1050x700", help="窓の大きさ 幅x高さ (既定 1050x700)")
    ap.add_argument("--wait", type=int, default=2000, help="撮るまでの待ち (ミリ秒．既定 2000)")
    ap.add_argument("--scale", type=float, default=2, help="画素の倍率 (既定 2)")
    a = ap.parse_args()
    try:
        w, h = (int(x) for x in a.size.lower().split("x"))
    except ValueError:
        sys.exit(f"oxq-thumb: --size は 幅x高さ (例 1050x700): {a.size}")
    from playwright.sync_api import sync_playwright
    url = to_url(a.src)
    out = Path(a.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(viewport={"width": w, "height": h}, device_scale_factor=a.scale)
        pg.goto(url)
        pg.wait_for_timeout(a.wait)
        pg.screenshot(path=str(out))
        b.close()
    print(f"oxq-thumb: {out} ({w}x{h}, x{a.scale:g}): {a.src}")


if __name__ == "__main__":
    main()
