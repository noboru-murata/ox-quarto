#!/usr/bin/env python3
"""mkpdf.py — 試験用の講演 (samples/publish) の html から，簡単な PDF を作る (標準ライブラリだけ)．

本物の配布用 PDF (tools/oxq-pdf.py) は quarto と playwright が要るので，publish.mk の試験では
これで代わりをする．<section> ごとに 1 頁，見出しと本文の文字を並べるだけ．
PDF の標準フォント (Helvetica) を使うので，ASCII 以外の文字 (日本語) は落とす．
そのため作り物の html には英語の文も入れてある (発表者ノートの照合はこの英語の文で働く)．

    python3 mkpdf.py sample-talk.html -o sample-talk-handout.pdf          # ノートなし (配布用)
    python3 mkpdf.py --notes sample-talk.html -o leak.pdf                 # ノートも載せる (漏れの試験用)
"""
from __future__ import annotations

import argparse
import html
import re
import sys
import textwrap

SECTION = re.compile(r"<section\b[^>]*>(.*?)</section>", re.S)
NOTES = re.compile(r'<aside\b[^>]*class="[^"]*\bnotes\b[^"]*"[^>]*>.*?</aside>', re.S)
BLOCK = re.compile(r"<(h[1-6]|p|li)\b[^>]*>(.*?)</\1>", re.S)


def ascii_text(s: str) -> str:
    s = html.unescape(re.sub(r"<[^>]+>", " ", s))
    s = "".join(c if 32 <= ord(c) < 127 else " " for c in s)
    return re.sub(r"\s+", " ", s).strip()


def pages_from_html(text: str, with_notes: bool) -> list[list[str]]:
    body = re.search(r"<body\b[^>]*>(.*)</body>", text, re.S)
    body = body.group(1) if body else text
    secs = SECTION.findall(body) or [body]
    pages = []
    for sec in secs:
        if not with_notes:
            sec = NOTES.sub("", sec)
        lines = []
        for _, inner in BLOCK.findall(sec):
            t = ascii_text(inner)
            if t:
                lines += textwrap.wrap(t, 80)
        pages.append(lines or ["(no ASCII text on this page)"])
    return pages


def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def write_pdf(pages: list[list[str]], title: str, out: str) -> None:
    objs: list[bytes] = []                       # 1 から番号を振る
    def add(b: bytes) -> int:
        objs.append(b)
        return len(objs)
    font = add(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
    pages_id = len(objs) + 1 + 2 * len(pages)    # 頁と内容のあとに Pages を置く
    kids = []
    for lines in pages:
        ops = ["BT", "/F1 14 Tf", "56 780 Td", "18 TL"]
        for ln in lines[:40]:
            ops.append(f"({esc(ln)}) Tj T*")
        ops.append("ET")
        stream = "\n".join(ops).encode("latin-1")
        content = add(b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream")
        kids.append(add(b"<< /Type /Page /Parent %d 0 R /MediaBox [0 0 595 842] "
                        b"/Resources << /Font << /F1 %d 0 R >> >> /Contents %d 0 R >>" % (pages_id, font, content)))
    assert add(b"<< /Type /Pages /Kids [%s] /Count %d >>"
               % (" ".join(f"{k} 0 R" for k in kids).encode(), len(kids))) == pages_id
    catalog = add(b"<< /Type /Catalog /Pages %d 0 R >>" % pages_id)
    info = add(b"<< /Title (%s) /Producer (samples/publish/mkpdf.py) >>" % esc(title).encode("latin-1"))

    data = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = []
    for i, o in enumerate(objs, 1):
        offsets.append(len(data))
        data += b"%d 0 obj\n" % i + o + b"\nendobj\n"
    xref = len(data)
    data += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
    data += b"".join(b"%010d 00000 n \n" % off for off in offsets)
    data += b"trailer\n<< /Size %d /Root %d 0 R /Info %d 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (
        len(objs) + 1, catalog, info, xref)
    with open(out, "wb") as f:
        f.write(data)


def main() -> int:
    ap = argparse.ArgumentParser(description="試験用の html から簡単な PDF を作る (samples/publish)")
    ap.add_argument("html")
    ap.add_argument("-o", "--output", required=True)
    ap.add_argument("--notes", action="store_true", help="発表者ノートも載せる (漏れの試験用)")
    a = ap.parse_args()
    text = open(a.html, encoding="utf-8").read()
    m = re.search(r'<p class="en">(.*?)</p>', text, re.S)
    title = ascii_text(m.group(1)) if m else "samples/publish"
    write_pdf(pages_from_html(text, a.notes), title, a.output)
    print(f"mkpdf: {a.output}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
