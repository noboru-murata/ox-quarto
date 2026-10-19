#!/usr/bin/env python3
"""oxq-bib.py — org で引用している文献だけを文献の正本 (library.bib) から抜き出して，文書の bib を作る

使い方:
  python3 tools/oxq-bib.py slide.org companion.org [--library LIB] [-o refs.bib]
  python3 tools/oxq-bib.py slide.org -n                 # 書き込まずに，足りない文献と増減だけ表示
  python3 tools/oxq-bib.py slide.org --extra ../research/pending.bib   # 正本に無い (登録待ちの) 文献を手で書いた bib も読む

- 引用は org の [cite:@a;@b] / [cite/t:@a] などから拾う (COMMENT の見出しの下も含む．# で始まるコメント行と ~code~ の中は除く)．
- 正本 (Zotero / Better BibTeX の書き出しなど．読むだけ) のエントリから --drop の欄 (既定: abstract file keywords urldate
  annotation bibsource timestamp pubstate) を除き，引用の初出順に並べる．
- Better BibTeX の書き出しの癖を直す: @report の eid → number (Zotero の Report Number．pandoc は eid を読まない)．
- 正本に無いキーは，--extra の bib (登録待ちの文献を手で書いたもの．複数可) から，それにも無ければ今の出力から引き継ぎ，
  その旨を表示する (どこにも無ければ警告し，終了コード 1)．探す順は 正本 → --extra の bib (書いた順) → 今の出力．
  --extra の bib にあるキーが正本にもあれば正本の方を使い，「正本に登録済み (--extra の bib から消してよい)」と知らせる．
- 中身が変わらなければ書かない (更新時刻が変わらないので make が無駄に作り直さない)．
- 正本の場所: --library，無ければ環境変数 OXQ_BIB_LIBRARY (LIBRARY_BIB も読む)，無ければ ox-quarto の隣の biblio/bib/library.bib
  (~/Desktop/claude/ox-quarto なら ~/Desktop/claude/biblio/bib/library.bib．publish.mk の PUB_ROOT と同じ考え)．
- python の標準の部品だけで動く．

Makefile の例 (README.org の「文献」):
  LIBRARY ?= $(OXQ)/../biblio/bib/library.bib
  refs.bib: slide.org companion.org $(LIBRARY) $(OXQ)/tools/oxq-bib.py
  	python3 $(OXQ)/tools/oxq-bib.py slide.org companion.org --library $(LIBRARY) -o $@
"""
import argparse, os, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent            # ox-quarto
DEFAULT_LIBRARY = ROOT.parent / 'biblio' / 'bib' / 'library.bib'
DEFAULT_DROP = 'abstract,file,keywords,urldate,annotation,bibsource,timestamp,pubstate'


def cited_keys(sources):
    keys = []
    for src in sources:
        for line in Path(src).read_text(encoding='utf-8').splitlines():
            s = line.lstrip()
            if s.startswith('#') and not s.startswith('#+'):
                continue
            line = re.sub(r'~[^~]*~', '', line)   # ~code~ の中は除く
            for m in re.finditer(r'\[cite(?:/[A-Za-z/]+)?:([^\]]*)\]', line):
                for k in re.findall(r'@([^\s;\]]+)', m.group(1)):
                    if k not in keys:
                        keys.append(k)
    return keys


def entries(text):
    """{key: (型, 本文)} を返す．エントリは '@type{key,' で始まり，括弧の対応で終わる．"""
    out = {}
    for m in re.finditer(r'^@(\w+)\{([^,\s]+),', text, re.M):
        i, depth, j = text.index('{', m.start()), 0, len(text) - 1
        for j in range(i, len(text)):
            c = text[j]
            if c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    break
        out[m.group(2)] = (m.group(1), text[m.end():j])
    return out


def fields(body):
    """本文を (名前, 値) の並びに分ける (値は括弧の対応で切る)．"""
    res, i, n = [], 0, len(body)
    name_re, comma_re = re.compile(r'\s*([A-Za-z][\w-]*)\s*=\s*'), re.compile(r'\s*,')
    while i < n:
        m = name_re.match(body, i)
        if not m:
            break
        name, j = m.group(1), m.end()
        if j < n and body[j] == '{':
            depth, k = 0, j
            for k in range(j, n):
                if body[k] == '{':
                    depth += 1
                elif body[k] == '}':
                    depth -= 1
                    if depth == 0:
                        break
            val, i = body[j:k + 1], k + 1
        else:
            k = j
            while k < n and body[k] not in ',\n':
                k += 1
            val, i = body[j:k].strip(), k
        res.append((name, val))
        m2 = comma_re.match(body, i)
        if m2:
            i = m2.end()
    return res


def fixup(typ, fs):
    """Better BibTeX の書き出しの癖を直す (@report の eid → number)．"""
    names = {a.lower() for a, _ in fs}
    if typ.lower() == 'report' and 'eid' in names and 'number' not in names:
        fs = [('number' if a.lower() == 'eid' else a, v) for a, v in fs]
    return fs


def render(key, typ, body, drop):
    fs = fixup(typ, [(a, v) for a, v in fields(body) if a.lower() not in drop])
    return '@%s{%s,\n%s\n}\n' % (typ, key, ',\n'.join('  %s = %s' % (a, v) for a, v in fs))


def header(sources, library, extras, drop):
    return ('%% このファイルは oxq-bib.py (ox-quarto/tools) が作る．手で直さない (直すなら文献の正本で)．\n'
            '%% 引用している文献だけを %s%s から抜き出した．引用を拾った org: %s\n'
            '%% 除いた欄: %s\n') % (os.path.relpath(library),
                                  ''.join(' と ' + os.path.relpath(e) for e in extras),
                                  ' '.join(str(s) for s in sources), ' '.join(sorted(drop)))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('sources', nargs='+', metavar='ORG', help='引用を拾う org (複数可)')
    ap.add_argument('--library', help='文献の正本 (既定: 環境変数 OXQ_BIB_LIBRARY か %s)' % DEFAULT_LIBRARY)
    ap.add_argument('--extra', action='append', default=[], metavar='BIB',
                    help='正本に無い (登録待ちの) 文献を手で書いた bib (複数可．正本の次に探す)')
    ap.add_argument('-o', '--output', default='refs.bib', help='出力 (既定 refs.bib)')
    ap.add_argument('--drop', default=DEFAULT_DROP, help='除く欄 (カンマ区切り．既定 %s．空なら何も除かない)' % DEFAULT_DROP)
    ap.add_argument('-n', '--dry-run', action='store_true', help='書き込まずに増減と足りない文献だけ表示')
    a = ap.parse_args()

    library = Path(a.library or os.environ.get('OXQ_BIB_LIBRARY') or os.environ.get('LIBRARY_BIB') or DEFAULT_LIBRARY)
    if not library.exists():
        sys.exit(f'oxq-bib: 文献の正本が無い: {library} (--library か OXQ_BIB_LIBRARY で指定する)')
    out = Path(a.output)
    drop = {f.strip().lower() for f in a.drop.split(',') if f.strip()}

    extras = [Path(e) for e in a.extra]
    for e in extras:
        if not e.exists():
            sys.exit(f'oxq-bib: --extra の bib が無い: {e}')
    keys = cited_keys(a.sources)
    lib = entries(library.read_text(encoding='utf-8'))
    extra = [(e, entries(e.read_text(encoding='utf-8'))) for e in extras]
    old = entries(out.read_text(encoding='utf-8')) if out.exists() else {}
    parts, kept, missing, pending, registered = [header(a.sources, library, extras, drop)], [], [], [], []
    for k in keys:
        ex = next(((e, d[k]) for e, d in extra if k in d), None)
        if k in lib:
            parts.append(render(k, *lib[k], drop))
            if ex:
                registered.append((k, ex[0]))
        elif ex:
            parts.append(render(k, *ex[1], drop))
            pending.append((k, ex[0]))
        elif k in old:
            parts.append(render(k, *old[k], drop))
            kept.append(k)
        else:
            missing.append(k)
    added = [k for k in keys if k not in old]
    removed = [k for k in old if k not in keys]
    n_lib = len(keys) - len(kept) - len(missing) - len(pending)
    print(f'引用 {len(keys)} 件 (正本 {n_lib}，登録待ち {len(pending)}，{out.name} から引き継ぎ {len(kept)})')
    for k in added:
        print('  追加:', k)
    for k in removed:
        print('  削除:', k)
    for k, e in pending:
        print(f'  登録待ち ({e.name} から):', k)
    for k, e in registered:
        print(f'  正本に登録済み ({e.name} から消してよい):', k)
    for k in kept:
        print(f'  正本に無い ({out.name} から):', k)
    for k in missing:
        print('  警告: どこにも無い:', k, file=sys.stderr)
    text = '\n'.join(parts)
    if a.dry_run:
        pass
    elif out.exists() and out.read_text(encoding='utf-8') == text:
        print('変更なし:', out)
    else:
        out.write_text(text, encoding='utf-8')
        print('書いた:', out)
    return 1 if missing else 0


if __name__ == '__main__':
    sys.exit(main())
