#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml>=6"]
# ///
"""oxq-publish.py — 公開する生成物を，公開側と同じ並びで仮置き場に集める (publish.mk の stage)．

公開側 (talks) は「主題のフォルダの中に講演の版を並べる」形 (talks/PUBLISHING.md):

    talks/<主題>/              主題の部分 (解説・デモなど育てていくもの．常に最新)
    talks/<主題>/<版>/         講演の版 (YYYY-MM-DD[-x]．講演の日の翌日から固定)

使い方 (講演の Makefile のあるフォルダで．ふつうは publish.mk から):
    uv run --script oxq-publish.py topic --id ID --meta META --out STAGE/topic/ID \\
        --notes-out NOTES  元=公開側 ...
    uv run --script oxq-publish.py edition --id ID --edition ED --meta META \\
        --out STAGE/edition/ID/ED --dest TALKS/ID/ED [--fix 理由] --notes-out NOTES  元=公開側 ...

どちらも:
  1. 仮置き場を作り直し，「元=公開側のパス」の組ごとに写す
  2. html の相対参照を確かめる (組で公開するファイルなら公開側でも同じ相対位置か，
     <名前>_files/ の中なら一緒に写す，それ以外は誤り)
  3. publish.notes が false (既定) なら html から <aside class="notes"> を取り除き，
     ノートの断片を --notes-out に書く (check.py が配布用 PDF を調べる)
  4. meta.yml を作って仮置き場に置く
     topic:   原本から editions を除き，id と updated を足す
     edition: 原本の editions[版] に主題の値 (題・ライセンス・publish) を補い，
              edition・topic・date・published・revisions を足す

edition は封印も扱う: 公開側に同じ版があり，講演の日 (date) を過ぎていれば止める．
--fix 理由 を付けたときだけ訂正として通し (ファイルの並びが今と同じことが条件)，
revisions に理由を記録する．

公開してよいかの検査はここではしない．公開側の tools/check.py が受け持つ．
"""
from __future__ import annotations

import argparse
import datetime as dt
import html as htmllib
import os.path
import re
import shutil
import sys
from pathlib import Path, PurePosixPath

import yaml

ID_RE = re.compile(r"[a-z0-9][a-z0-9-]*")
EDITION_RE = re.compile(r"\d{4}-\d{2}-\d{2}(?:-[a-z])?")
REF_ATTR = re.compile(r'''\b(?:src|href|poster|data-src|data-iframe-src|data-background-image|data-background-iframe)\s*=\s*"([^"]*)"''')
NOTES_BLOCK = re.compile(r'<aside\b[^>]*class="[^"]*\bnotes\b[^"]*"[^>]*>.*?</aside>', re.S)
CHARSET_RE = re.compile(r"""<meta\b[^>]*\bcharset\s*=|<meta\b[^>]*http-equiv\s*=\s*["']?content-type""", re.I)
HEAD_RE = re.compile(r"<head\b[^>]*>", re.I)
GENERATED = {"index.html", "meta.yml"}     # 公開側で build-index / この道具が作るもの


def today_() -> dt.date:
    # 試験用: OXQ_PUBLISH_TODAY=YYYY-MM-DD で「今日」を変えられる
    t = os.environ.get("OXQ_PUBLISH_TODAY")
    return dt.date.fromisoformat(t) if t else dt.date.today()


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
        die(f"公開側のパス {dest!r} はフォルダの中の相対パスにする")
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


def ensure_charset(text: str) -> tuple[str, bool]:
    """先頭 1024 バイトに文字コードの指定が無ければ，<head> の直後に <meta charset="utf-8"> を入れる．
    (Quarto の embed-resources はスクリプトを <meta charset> より前に埋め込むので，ブラウザの
    先読みで見つからず，charset を送らないサーバーでは文字化けする)"""
    if CHARSET_RE.search(text[:1024].encode("utf-8")[:1024].decode("utf-8", "ignore")):
        return text, False
    m = HEAD_RE.search(text[:4096])
    if not m:
        return text, False
    return text[:m.end()] + '\n<meta charset="utf-8">' + text[m.end():], True


def _inside(p: Path, d: Path) -> bool:
    try:
        p.relative_to(d)
        return True
    except ValueError:
        return False


def load_meta(path: str) -> dict:
    mp = Path(path)
    if not mp.exists():
        die(f"{mp} がない (講演の原本の meta.yml．書き方は talks/PUBLISHING.md)")
    return yaml.safe_load(mp.read_text(encoding="utf-8")) or {}


def copy_files(specs: list[str], out: Path, notes_public: bool, notes_out: str | None) -> None:
    """「元=公開側」の組を out に写す．html の相対参照を確かめ，ノートを取り除く．"""
    pairs: list[tuple[Path, PurePosixPath]] = []
    for spec in specs:
        if "=" not in spec:
            die(f"{spec!r} は「元のパス=公開側のパス」で書く")
        src, dest = spec.split("=", 1)
        sp = Path(src)
        if not sp.is_file():
            die(f"{src} がない (先に make で作る)")
        d = safe_rel(dest)
        if str(d) in GENERATED:
            die(f"公開側のパス {dest} は道具が作るので使えない")
        pairs.append((sp.resolve(), d))
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
                note = "  (発表者ノートを取り除いた)"
                all_snippets += snip
        for ref in REF_ATTR.findall(text):
            if not is_local_ref(ref):
                continue
            path = ref.split("#")[0].split("?")[0]
            if not path:
                continue
            ref_src = (src.parent / path).resolve()
            if ref_src in src2dest:
                want = os.path.relpath(str(src2dest[ref_src]), str(dest.parent) or ".")
                if PurePosixPath(path) != PurePosixPath(want):
                    die(f"{dest}: {ref} は公開側では {want} になる．公開側の並びを元と同じ相対位置にする")
                continue
            files_dir = (src.parent / f"{src.stem}_files").resolve()
            if ref_src.is_file() and _inside(ref_src, files_dir):
                rel = ref_src.relative_to(src.parent.resolve())
                extra[ref_src] = dest.parent / PurePosixPath(*rel.parts)
                continue
            die(f"{src.name}: {ref} を参照しているが，公開するファイルに入っていない (FILES に足すか，参照をやめる)")
        text, added = ensure_charset(text)
        if added:
            note += "  (<meta charset> を先頭に足した)"
        target.write_text(text, encoding="utf-8")
        print(f"  {dest}{note}")

    for s, d in sorted(extra.items(), key=lambda x: str(x[1])):
        (out / d).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(s, out / d)
    if extra:
        print(f"  (*_files/ から {len(extra)} 個)")
    if notes_out:
        Path(notes_out).parent.mkdir(parents=True, exist_ok=True)
        Path(notes_out).write_text("\n".join(all_snippets) + "\n", encoding="utf-8")


def write_meta(out: Path, meta: dict, header: str) -> None:
    (out / "meta.yml").write_text(
        header + yaml.safe_dump(meta, allow_unicode=True, sort_keys=False, width=1000),
        encoding="utf-8")
    print("  meta.yml")


def file_set(root: Path) -> set[str]:
    return {p.relative_to(root).as_posix() for p in root.rglob("*")
            if p.is_file() and p.relative_to(root).as_posix() not in GENERATED}


# ------------------------------------------------------------------ 主題
def cmd_topic(a: argparse.Namespace) -> None:
    if not ID_RE.fullmatch(a.id or ""):
        die(f"--id ({a.id!r}) は英小文字・数字・ハイフンだけにする")
    out = Path(a.out)
    if out.name != a.id:
        die(f"仮置き場 {out} の名前は主題の id ({a.id}) にする")
    src = load_meta(a.meta)
    for spec in a.files:
        top = PurePosixPath(spec.split("=", 1)[-1]).parts[0]
        if EDITION_RE.fullmatch(top):
            die(f"主題の部分に版の名前の形 ({top}) のフォルダは置けない: {spec}")
    notes_public = bool((src.get("publish") or {}).get("notes", False))
    copy_files(a.files, out, notes_public, a.notes_out)
    meta = {k: v for k, v in src.items() if k != "editions"}
    meta["id"] = a.id
    meta["updated"] = today_()
    write_meta(out, meta, "# 主題の情報．講演の原本の meta.yml から publish.mk (make publish) が作る．\n")


# ------------------------------------------------------------------ 版
def cmd_edition(a: argparse.Namespace) -> None:
    if not ID_RE.fullmatch(a.id or ""):
        die(f"--id ({a.id!r}) は英小文字・数字・ハイフンだけにする")
    ed = a.edition or ""
    if not EDITION_RE.fullmatch(ed):
        die(f"版の名前 ({ed!r}) は YYYY-MM-DD か，同じ日の 2 つ目からは YYYY-MM-DD-b，-c …")
    out = Path(a.out)
    if out.name != ed or out.parent.name != a.id:
        die(f"仮置き場 {out} は …/{a.id}/{ed} にする")
    src = load_meta(a.meta)
    editions = {str(k): v for k, v in (src.get("editions") or {}).items()}
    if ed not in editions:
        die(f"原本の meta.yml の editions に {ed} がない (キーは \"{ed}\" のように文字列で書く)")
    e = dict(editions[ed] or {})
    date = str(e.pop("date", ed[:10]))
    try:
        day = dt.date.fromisoformat(date)
    except ValueError:
        die(f"editions.{ed}.date ({date}) が YYYY-MM-DD でない")
    if date != ed[:10]:
        die(f"版の名前 {ed} と date ({date}) の日付が違う")

    publish = dict(src.get("publish") or {})
    publish.update(e.pop("publish", None) or {})
    notes_public = bool(publish.get("notes", False))

    # 封印: 公開側に同じ版があり，講演の日を過ぎていれば，訂正 (--fix) のときだけ通す
    dest = Path(a.dest) if a.dest else None
    old = {}
    exists = bool(dest and (dest / "meta.yml").exists())
    if exists:
        old = yaml.safe_load((dest / "meta.yml").read_text(encoding="utf-8")) or {}
    today = today_()
    sealed = exists and today > day
    if sealed and not a.fix:
        die(f"版 {a.id}/{ed} は講演の日 ({date}) を過ぎて固定されている．"
            "訂正なら PUB_FIX=\"理由\" を付けて実行する (ファイルの追加・削除・改名はできない)．"
            "内容を足すなら主題の部分 (make publish) か新しい版に")
    if a.fix and not sealed:
        print(f"  (PUB_FIX は固定された版の訂正のためのもの．{ed} はまだ固定されていないので記録しない)")

    copy_files(a.files, out, notes_public, a.notes_out)

    revisions = list(old.get("revisions") or [])
    if sealed:
        before, after = file_set(dest), file_set(out)
        if before != after:
            added, removed = sorted(after - before), sorted(before - after)
            die("訂正ではファイルの並びを変えられない"
                + (f"．増える: {', '.join(added)}" if added else "")
                + (f"．なくなる: {', '.join(removed)}" if removed else ""))
        revisions.append({"date": today, "note": a.fix})
        print(f"  (訂正として記録: {a.fix})")

    meta = {
        "edition": ed,
        "topic": a.id,
        "title": e.pop("title", src.get("title")),
    }
    sub = e.pop("subtitle", src.get("subtitle"))
    if sub:
        meta["subtitle"] = sub
    meta["date"] = day
    for k in ("venue", "kind", "event_url"):
        if k in e:
            meta[k] = e.pop(k)
    meta["items"] = e.pop("items", None) or []
    meta["license"] = e.pop("license", src.get("license"))
    meta["publish"] = publish
    meta.update(e)                                   # そのほかの項目はそのまま
    meta["published"] = old.get("published", today)
    if revisions:
        meta["revisions"] = revisions
    write_meta(out, meta, "# 講演の版の情報．講演の原本の meta.yml (editions) から publish.mk (make publish-edition) が作る．\n"
                          "# 講演の日の翌日から固定 (talks/PUBLISHING.md)．\n")
    if not sealed and today >= day:
        print(f"  (講演の日を迎えた．明日から固定．タグ: git tag {a.id}/{ed})")


def main() -> None:
    ap = argparse.ArgumentParser(description="公開する生成物を仮置き場に集める (ox-quarto/tools/publish.mk)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    t = sub.add_parser("topic", help="主題の部分")
    t.add_argument("--id", required=True)
    t.add_argument("--meta", required=True)
    t.add_argument("--out", required=True)
    t.add_argument("--notes-out")
    t.add_argument("files", nargs="+", help="元のパス=公開側のパス")
    e = sub.add_parser("edition", help="講演の版")
    e.add_argument("--id", required=True)
    e.add_argument("--edition", required=True)
    e.add_argument("--meta", required=True)
    e.add_argument("--out", required=True)
    e.add_argument("--dest", help="公開側の版のフォルダ (固定かどうかと，前の published / revisions を読む)")
    e.add_argument("--fix", default="", help="固定された版の訂正の理由")
    e.add_argument("--notes-out")
    e.add_argument("files", nargs="+", help="元のパス=公開側のパス")
    a = ap.parse_args()
    {"topic": cmd_topic, "edition": cmd_edition}[a.cmd](a)


if __name__ == "__main__":
    main()
