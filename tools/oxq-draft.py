#!/usr/bin/env python3
"""oxq-draft.py — 議論用 (非公開) の写しを，合言葉で暗号化して drafts に置く (publish.mk の make publish-draft から)．

未発表の結果を含む資料を共同研究者に Web で見せるための仕組み．drafts は talks と別のリポジトリ (private でも Pages の頁は公開される) で，
中身はすべて暗号化して置く: html は StatiCrypt (npx staticrypt)，PDF は qpdf (AES-256)．合言葉を知る人だけが読める．

    python3 oxq-draft.py --id ID --name YYYY-MM-DD[-b] --src ../snapshots/<名前> --root ../../../drafts --pass-file ~/.config/oxq/drafts/ID.pass

- --src の中の html と PDF を，同じ並びのまま drafts/<ID>/<名前>/ に写す (前の中身は消して置き換える．固定はしない)．
  .org・SOURCE・MEMO などの html / PDF 以外は写さない (一覧を出す)．暗号化できない種類 (画像・css・js など) が
  html から参照されていれば止める (平文で出さないため．slide.html は embed-resources の 1 ファイルなので問題ない)．
- 合言葉は --pass-file から読む (リポジトリにも原本にも書かない．講演ごとに別の合言葉)．npx には環境変数で渡す．
- 「Remember me」は既定で印を付け，覚える場所は講演ごとに分ける (localStorage の oxq_draft_<ID>_passphrase)．
  印を付けて一度解けば，スライドの中の iframe のデモや同じ講演のほかの頁も合言葉なしで開ける．
- 頁には noindex を付ける．drafts/<ID>/index.html (写しの名前の一覧) も暗号化する．drafts/index.html には題を出さない．
- 最後に drafts/<ID>/ の html がすべて暗号化され，PDF に合言葉が掛かっていることを調べる (平文の漏れ止め)．

要るもの: node (npx) と qpdf．staticrypt は版を固定して npx で取る (STATICRYPT)．
"""
from __future__ import annotations

import argparse
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

STATICRYPT = os.environ.get("OXQ_STATICRYPT", "staticrypt@3.5.4")
ID_RE = re.compile(r"[a-z0-9][a-z0-9-]*")
NAME_RE = re.compile(r"\d{4}-\d{2}-\d{2}(?:-[a-z])?")
MARK = "oxq-draft"                       # 暗号化した頁に入れる印 (検査に使う)
REF_RE = re.compile(r'''\b(?:src|href|data-src|data-iframe-src|poster)\s*=\s*"([^"#?]+)''')
LOCAL_RE = re.compile(r"/Users/[A-Za-z0-9_.-]+|(?:src|href)\s*=\s*[\"']file://")
TITLE = "議論用の資料"
INSTR = "共同研究者の方へ: 受け取った合言葉を入れてください．"


def die(msg: str) -> None:
    sys.exit(f"oxq-draft: {msg}")


def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode != 0:
        sys.stderr.write(r.stdout[-2000:] + r.stderr[-2000:])
        die(f"失敗した: {' '.join(str(c) for c in cmd[:3])} …")
    return r


def collect(src: Path) -> tuple[list[Path], list[str]]:
    """写す html / PDF と，写さないものの一覧．html から平文のファイルを参照していれば止める．"""
    keep, skipped, problems = [], [], []
    for p in sorted(src.rglob("*")):
        rel = p.relative_to(src)
        if p.is_symlink():
            problems.append(f"{rel}: シンボリックリンクは写さない")
            continue
        if p.is_dir() or any(part.startswith(".") for part in rel.parts):
            continue
        if p.suffix.lower() in (".html", ".pdf"):
            keep.append(rel)
        else:
            skipped.append(str(rel))
    names = {k.as_posix() for k in keep}
    for rel in keep:
        if rel.suffix.lower() != ".html":
            continue
        text = (src / rel).read_text(encoding="utf-8", errors="replace")
        m = LOCAL_RE.search(text)
        if m:
            problems.append(f"{rel}: 手元のパスがある ({m.group(0)[:40]})")
        for ref in REF_RE.findall(text):
            if re.match(r"^[a-z][a-z0-9+.-]*:|^//|^data:|^mailto:", ref) or not ref.strip():
                continue
            target = os.path.normpath((rel.parent / ref).as_posix())
            if target.startswith(".."):
                problems.append(f"{rel}: 写しの外を指す ({ref})")
            elif not (src / target).exists():
                problems.append(f"{rel}: 写しに無いファイルを参照している ({ref})")
            elif target not in names and not (src / target).is_dir():
                problems.append(f"{rel}: 暗号化しないファイルを参照している ({ref})．html か PDF にするか，参照をやめる")
    if problems:
        die("止めた:\n  " + "\n  ".join(problems))
    return keep, skipped


def list_page(title: str, links: list[tuple[str, str]], note: str = "") -> str:
    li = "\n".join(f'<li><a href="{html.escape(h)}">{html.escape(t)}</a></li>' for h, t in links)
    return f"""<!doctype html>
<html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<style>body{{font:16px/1.7 system-ui,"Hiragino Sans","Noto Sans JP",sans-serif;max-width:40rem;margin:2rem auto;padding:0 1rem}}</style>
</head><body><h1>{html.escape(title)}</h1>{note}<ul>
{li}
</ul></body></html>
"""


def encrypt_html(stage: Path, out: Path, cfg: Path, password: str, draft_id: str) -> None:
    # StatiCrypt は --config と -d を作業フォルダからの相対で扱う (先頭に ./ を付ける) ので，stage の隣に置く
    tmp = stage.parent / "enc"
    shutil.rmtree(tmp, ignore_errors=True)
    shutil.copy2(cfg, stage.parent / "staticrypt.json")
    try:
        run(["npx", "--yes", STATICRYPT, stage.name, "-r", "-d", tmp.name, "--config", "staticrypt.json", "--short",
             "--remember", "60", "--template-title", TITLE, "--template-instructions", INSTR,
             "--template-button", "開く", "--template-remember", "この端末で覚える",
             "--template-placeholder", "合言葉", "--template-error", "合言葉が違います"],
            cwd=stage.parent, env={**os.environ, "STATICRYPT_PASSWORD": password})
        made = tmp / stage.name
        for p in made.rglob("*.html"):
            t = p.read_text(encoding="utf-8")
            reps = [('rememberPassphraseKey: "staticrypt_passphrase"', f'rememberPassphraseKey: "oxq_draft_{draft_id}_passphrase"'),
                    ('rememberExpirationKey: "staticrypt_expiration"', f'rememberExpirationKey: "oxq_draft_{draft_id}_expiration"'),
                    ('<input id="staticrypt-remember" type="checkbox" name="remember" />',
                     '<input id="staticrypt-remember" type="checkbox" name="remember" checked />')]
            for a, b in reps:
                if t.count(a) != 1:
                    die(f"StatiCrypt の頁の形が想定と違う ({STATICRYPT}．{a[:30]}…)．版を確かめる")
                t = t.replace(a, b)
            t = re.sub(r"<head>", f'<head>\n<meta name="robots" content="noindex, nofollow">\n<meta name="generator" content="{MARK}">', t, count=1)
            dest = out / p.relative_to(made)
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(t, encoding="utf-8")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def encrypt_pdf(src: Path, dest: Path, password: str) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", delete=False, suffix=".args") as f:   # 合言葉をコマンド行に出さない
        f.write(f"--encrypt\n{password}\n{password}\n256\n--\n{src}\n{dest}\n")
        args = f.name
    try:
        run(["qpdf", f"@{args}"])
    finally:
        os.unlink(args)


def verify(root: Path) -> list[str]:
    bad = []
    for p in root.rglob("*"):
        if p.is_file() and p.suffix.lower() == ".html" and MARK not in p.read_text(encoding="utf-8", errors="replace")[:4000]:
            bad.append(f"暗号化していない html: {p}")
        if p.is_file() and p.suffix.lower() == ".pdf" and subprocess.run(["qpdf", "--is-encrypted", str(p)]).returncode != 0:
            bad.append(f"合言葉の無い PDF: {p}")
        if p.is_file() and p.suffix.lower() not in (".html", ".pdf", ".json"):
            bad.append(f"html / PDF 以外: {p}")
    return bad


def main() -> int:
    ap = argparse.ArgumentParser(description="議論用の写しを暗号化して drafts に置く")
    ap.add_argument("--id", required=True, help="drafts の中の講演の名前 (英小文字・数字・ハイフン．URL に出る)")
    ap.add_argument("--name", required=True, help="写しの名前 YYYY-MM-DD[-b]")
    ap.add_argument("--src", required=True, help="写しのフォルダ (講演の snapshots/<名前>/)")
    ap.add_argument("--root", required=True, help="drafts リポジトリ")
    ap.add_argument("--pass-file", required=True, help="合言葉のファイル (1 行目)")
    a = ap.parse_args()

    if not ID_RE.fullmatch(a.id):
        die(f"--id '{a.id}' は英小文字・数字・ハイフン")
    if not NAME_RE.fullmatch(a.name):
        die(f"--name '{a.name}' は YYYY-MM-DD か YYYY-MM-DD-b")
    src, root, pf = Path(a.src), Path(a.root), Path(a.pass_file).expanduser()
    if not src.is_dir():
        die(f"{src} が無い (講演の make snapshot で作る)")
    if not root.is_dir():
        die(f"{root} が無い (drafts リポジトリ．ox-quarto の隣に置く)")
    if not pf.is_file():
        die(f"合言葉のファイル {pf} が無い (make draft-pass で作る)")
    if pf.stat().st_mode & 0o077:
        print(f"oxq-draft: 注意: {pf} はほかの人も読める (chmod 600 を)", file=sys.stderr)
    password = pf.read_text(encoding="utf-8").splitlines()[0].strip() if pf.read_text(encoding="utf-8").strip() else ""
    if len(password) < 12:
        die("合言葉が短い (12 文字以上に)")
    for tool in ("npx", "qpdf"):
        if not shutil.which(tool):
            die(f"{tool} が無い")

    keep, skipped = collect(src)
    if not any(k.suffix.lower() == ".html" for k in keep):
        die(f"{src} に html が無い")
    topic = root / a.id
    topic.mkdir(exist_ok=True)
    cfg = topic / ".staticrypt.json"                 # salt (秘密ではない．同じ講演の頁で「覚える」を共有するため共通)
    if not cfg.exists():
        cfg.write_text(json.dumps({"salt": os.urandom(16).hex()}, indent=4) + "\n", encoding="utf-8")

    with tempfile.TemporaryDirectory(prefix="oxq-draft-") as td:
        stage = Path(td) / "x"
        stage.mkdir()
        htmls = [k for k in keep if k.suffix.lower() == ".html"]
        for k in htmls:
            (stage / k).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src / k, stage / k)
        links = [(k.as_posix(), k.as_posix()) for k in keep]
        (stage / "index.html").write_text(list_page(f"{TITLE} ({a.name})", links), encoding="utf-8")
        out = Path(td) / "out"
        encrypt_html(stage, out, cfg, password, a.id)
        for k in keep:
            if k.suffix.lower() == ".pdf":
                encrypt_pdf(src / k, out / k, password)
        dest = topic / a.name
        if dest.exists():
            shutil.rmtree(dest)
        shutil.copytree(out, dest)

    # 講演の一覧 (写しの名前の並び．暗号化) と drafts の入口 (題を出さない)
    names = sorted((d.name for d in topic.iterdir() if d.is_dir() and NAME_RE.fullmatch(d.name)), reverse=True)
    with tempfile.TemporaryDirectory(prefix="oxq-draft-") as td:
        stage = Path(td) / "x"
        stage.mkdir()
        (stage / "index.html").write_text(list_page(TITLE, [(f"{n}/", n) for n in names]), encoding="utf-8")
        out = Path(td) / "out"
        encrypt_html(stage, out, cfg, password, a.id)
        shutil.copy2(out / "index.html", topic / "index.html")
    if not (root / "index.html").exists():
        (root / "index.html").write_text(
            '<!doctype html>\n<html lang="ja"><head><meta charset="utf-8"><meta name="robots" content="noindex, nofollow">\n'
            f'<meta name="generator" content="{MARK}"><title>{TITLE}</title></head>\n'
            f'<body><p>{TITLE}の置き場です．受け取った URL と合言葉で開いてください．</p></body></html>\n', encoding="utf-8")
    (root / ".nojekyll").touch()

    bad = verify(topic)
    if bad:
        die("検査で止めた:\n  " + "\n  ".join(bad))
    print(f"→ {topic / a.name}/  (html {sum(1 for k in keep if k.suffix == '.html')}，PDF {sum(1 for k in keep if k.suffix == '.pdf')}．"
          f"暗号化を確かめた)")
    if skipped:
        print("  写さなかったもの: " + "，".join(skipped))
    print(f"  drafts で commit / push すると https://noboru-murata.github.io/drafts/{a.id}/{a.name}/ で見られる")
    return 0


if __name__ == "__main__":
    sys.exit(main())
