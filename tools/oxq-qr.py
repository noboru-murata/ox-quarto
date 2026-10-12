#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = ["segno"]
# ///
# oxq-qr.py — URL から QR コードの画像 (SVG / PNG) を作る．表紙の QR コード (#+QUARTO_QR．_quarto/lib/title-qr.lua) 用
#
# 使い方 (uv が segno を用意する．pip は使わない):
#   uv run --script /path/to/ox-quarto/tools/oxq-qr.py URL figs/qr-edition.svg
#   uv run --script /path/to/ox-quarto/tools/oxq-qr.py URL figs/qr-edition.png --scale 20
# 講演の版の頁の URL は talks/PUBLISHING.md の「URL の約束」:
#   https://noboru-murata.github.io/talks/<主題>/<版>/
# org では
#   #+QUARTO_QR: figs/qr-edition.svg
#   #+QUARTO_QR_CAPTION: https://noboru-murata.github.io/talks/<主題>/<版>/
#
# - 周りの余白 (quiet zone) は画像に含めない (--border 0)．表紙では parts.scss の
#   $title-qr-padding の白い余白を付けるので，暗い表紙でも読める．
# - 誤り訂正は M (既定)．URL が長くて細かくなるときは --error l．
# - 同じ URL なら同じ画像になる (書き出しの差分が出ない)．

import argparse, sys
from pathlib import Path

import segno


def main():
    ap = argparse.ArgumentParser(description="URL から QR コードの画像を作る (SVG / PNG)")
    ap.add_argument("url", help="QR コードにする URL (や文)")
    ap.add_argument("out", help="書き出すファイル (.svg / .png)")
    ap.add_argument("--error", default="m", choices=list("lmqh"), help="誤り訂正の水準 (既定 m)")
    ap.add_argument("--border", type=int, default=0, help="周りの余白 (モジュール数．既定 0)")
    ap.add_argument("--scale", type=int, default=10, help="1 モジュールの大きさ (既定 10．PNG では画素)")
    a = ap.parse_args()

    out = Path(a.out)
    if out.suffix.lower() not in (".svg", ".png"):
        sys.exit(f"oxq-qr: 書き出しは .svg か .png: {out}")
    out.parent.mkdir(parents=True, exist_ok=True)
    qr = segno.make(a.url, error=a.error, micro=False)
    qr.save(str(out), scale=a.scale, border=a.border, dark="#000", light="#fff")
    print(f"oxq-qr: {out} (version {qr.version}, error {qr.error}): {a.url}")


if __name__ == "__main__":
    main()
