#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml>=6"]
# ///
"""oxq-publish.py — 公開する生成物を，公開側と同じ並びで仮置き場に集める (publish.mk の stage)．

使い方 (講演の Makefile のあるフォルダで．ふつうは make publish-stage から):
    uv run --script oxq-publish.py stage --id piml --meta ../publish/meta.yml \\
        --out _publish/piml --notes-out _publish/piml.notes.txt \\
        piml.html=talk/piml.html ../demo/clothoid-pinn.html=demo/clothoid-pinn.html ...

すること:
  1. 仮置き場 (--out) を作り直し，「元=公開側のパス」の組ごとに写す
  2. html が相対パスで参照するファイルを調べる
       - 組で公開するファイルなら，公開側でも同じ相対パスで届くか確かめる
       - <名前>_files/ の中なら一緒に写す (embed-resources を使わない html のため)
       - それ以外は誤り (公開しないファイルを指している)
  3. meta.yml の publish.notes が false (既定) なら html から <aside class="notes"> を取り除き，
     ノートの断片を --notes-out に書く (check.py が配布用 PDF に載っていないか調べる)
  4. meta.yml に id と updated (今日) を足して仮置き場に置く

公開してよいかの検査はここではしない．公開側の tools/check.py が受け持つ (talks/PUBLISHING.md)．
"""
from __future__ import annotations

import argparse
import datetime as dt
import html as htmllib
import re
import shutil
import sys
from pathlib import Path, PurePosixPath

import yaml

REF_ATTR = re.compile(r'''\b(?:src|href|poster|data-src|data-iframe-src|data-background-image|data-background-iframe)\s*=\s*"([^"]*)"''')
NOTES_BLOCK = re.compile(r'<aside\b[^>]*class="[^"]*\bnotes\b[^"]*"[^>]*>.*?</aside>', re.S)


def die(msg: str) -> None:
    sys.exit(f"oxq-publish: {msg}")


def is_local_ref(ref: str) -> bool:
    if not ref or ref.startswith(("#", "data:", "mailto:", "javascript:", "//")):
        return False
    if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", ref):
        return False
    if any(c in ref for c in "'+{}$` <>"):
        return False
    return True


def safe_rel(dest: str) -> PurePosixPath:
    p = PurePosixPath(dest)
    if p.is_absolute() or ".." in p.parts or not p.parts or p.name in ("", "."):
        die(f"公開側のパス {dest!r} は講演のフォルダの中の相対パスにする")
    return p


def strip_notes(text: str) -> tuple[str, list[str]]:
    snippets = []
    for m in NOTES_BLOCK.finditer(text):
        plain = htmllib.unescape(re.sub(r"<[^>]+>", " ", m.group(0)))
        for line in re.split(r"[。．.!?！？\n]", plain):
            line = re.sub(r"\s+", " ", line).strip()
            if len(line) >= 16:
                snippets.append(line[:60])
    return NOTES_BLOCK.sub("", text), snippets


def stage(a: argparse.Namespace) -> None:
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", a.id or ""):
        die(f"--id ({a.id!r}) は英小文字・数字・ハイフンだけにする")
    out = Path(a.out)
    if out.name != a.id:
        die(f"仮置き場 {out} の名前は講演の id ({a.id}) にする")
    meta_path = Path(a.meta)
    if not meta_path.exists():
        die(f"{meta_path} がない (講演の原本の meta.yml．書き方は talks/PUBLISHING.md)")
    meta = yaml.safe_load(meta_path.read_text(encoding="utf-8")) or {}
    notes_public = bool((meta.get("publish") or {}).get("notes", False))

    pairs: list[tuple[Path, PurePosixPath]] = []
    for spec in a.files:
        if "=" not in spec:
            die(f"{spec!r} は「元のパス=公開側のパス」で書く")
        src, dest = spec.split("=", 1)
        sp = Path(src)
        if not sp.is_file():
            die(f"{src} がない (先に make で作る)")
        pairs.append((sp.resolve(), safe_rel(dest)))
    dests = [d for _, d in pairs]
    if len(set(dests)) != len(dests):
        die("公開側のパスが重なっている")
    src2dest = {s: d for s, d in pairs}

    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    all_snippets: list[str] = []
    extra: dict[Path, PurePosixPath] = {}
    for src, dest in pairs:
        target = out / dest
        target.parent.mkdir(parents=True, exist_ok=True)
        if src.suffix.lower() != ".html":
            shutil.copy2(src, target)
            print(f"  {dest}")
            continue
        text = src.read_text(encoding="utf-8")
        note = ""
        if not notes_public:
            text, snip = strip_notes(text)
            if snip:
                note = f"  (発表者ノートを取り除いた)"
                all_snippets += snip
        # 相対参照を確かめる
        for ref in REF_ATTR.findall(text):
            if not is_local_ref(ref):
                continue
            path = ref.split("#")[0].split("?")[0]
            if not path:
                continue
            ref_src = (src.parent / path).resolve()
            if ref_src in src2dest:
                want = PurePosixPath(*Path(_relpath(src2dest[ref_src], dest.parent)).parts)
                if PurePosixPath(path) != want and str(PurePosixPath(path)) != str(want):
                    die(f"{dest}: {ref} は公開側では {want} になる．公開側の並びを元と同じ相対位置にする")
                continue
            files_dir = src.parent / f"{src.stem}_files"
            if ref_src.is_file() and _inside(ref_src, files_dir.resolve()):
                rel = ref_src.relative_to(src.parent.resolve())
                extra[ref_src] = dest.parent / PurePosixPath(*rel.parts)
                continue
            die(f"{src.name}: {ref} を参照しているが，公開するファイルに入っていない (PUB_FILES に足すか，参照をやめる)")
        target.write_text(text, encoding="utf-8")
        print(f"  {dest}{note}")

    for s, d in sorted(extra.items(), key=lambda x: str(x[1])):
        (out / d).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(s, out / d)
    if extra:
        print(f"  (*_files/ から {len(extra)} 個)")

    meta["id"] = a.id
    meta["updated"] = dt.date.today()
    (out / "meta.yml").write_text(
        "# この講演の原本の meta.yml から publish.mk が作る．直すときは講演のリポジトリで．\n"
        + yaml.safe_dump(meta, allow_unicode=True, sort_keys=False, width=1000),
        encoding="utf-8")
    print("  meta.yml")

    if a.notes_out:
        Path(a.notes_out).write_text("\n".join(all_snippets) + "\n", encoding="utf-8")


def _relpath(target: PurePosixPath, start: PurePosixPath) -> str:
    import os.path
    return os.path.relpath(str(target), str(start) or ".")


def _inside(p: Path, d: Path) -> bool:
    try:
        p.relative_to(d)
        return True
    except ValueError:
        return False


def main() -> None:
    ap = argparse.ArgumentParser(description="公開する生成物を仮置き場に集める (ox-quarto/tools/publish.mk)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("stage")
    s.add_argument("--id", required=True)
    s.add_argument("--meta", required=True)
    s.add_argument("--out", required=True)
    s.add_argument("--notes-out")
    s.add_argument("files", nargs="+", help="元のパス=公開側のパス")
    a = ap.parse_args()
    if a.cmd == "stage":
        stage(a)


if __name__ == "__main__":
    main()
