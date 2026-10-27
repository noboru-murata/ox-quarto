#!/bin/sh
# test.sh — publish.mk / oxq-publish.py / talks の check.py と build-index.py を，作り物の講演で試す．
#
#   sh samples/publish/test.sh [作業用のフォルダ]
#
# samples/publish を作業用のフォルダ (既定は mktemp -d) に写し，その中で make を走らせる．
# リポジトリの中のファイルは書き換えない．公開側も本物の talks ではなく写し (make sandbox)．
# 本物の talks は TALKS (既定: ox-quarto と同じ階層の talks) から tools/ と PUBLISHING.md を写すだけ．
# 要るもの: make，uv，rsync，python3．議論用の写し (publish-draft) の試験には npx と qpdf (無ければ飛ばす)．
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
OXQ=$(cd "$HERE/../.." && pwd -P)
TALKS=${TALKS:-$(cd "$OXQ/.." && pwd -P)/talks}
WORK=${1:-$(mktemp -d "${TMPDIR:-/tmp}/oxq-publish-test.XXXXXX")}
[ -f "$TALKS/PUBLISHING.md" ] || { echo "test.sh: $TALKS に PUBLISHING.md が無い (TALKS=… で指す)" >&2; exit 2; }

mkdir -p "$WORK"
WORK=$(cd "$WORK" && pwd -P)
case "$WORK" in "$OXQ"|"$OXQ"/*|"$TALKS"|"$TALKS"/*) echo "test.sh: 作業用のフォルダはリポジトリの外に" >&2; exit 2;; esac
rm -rf "$WORK/sample"
rsync -a --exclude _talks --exclude _drafts --exclude _snapshots --exclude _publish --exclude _work --exclude '*.pdf' "$HERE/" "$WORK/sample/"
T="$WORK/sample/talk"
PUB="$WORK/sample/_talks"
TOPIC="$PUB/publish-sample"
ED1="$TOPIC/2030-01-15"
ED2="$TOPIC/2030-03-02"
LOG="$WORK/log"
mkdir -p "$LOG"
unset OXQ_PUBLISH_TODAY PUB_FIX

pass=0; fail=0; n=0
say()  { printf '%s\n' "$*"; }
good() { pass=$((pass + 1)); say "  ok   $n $1"; }
bad()  { fail=$((fail + 1)); say "  FAIL $n $1 (記録: $LOG/$n.log)"; }

# m 今日 [make の引数…]: 試しの講演で make を走らせ，記録を $LOG/$n.log に残す
m() {
  day=$1; shift
  ( cd "$T" && OXQ_PUBLISH_TODAY=$day make --no-print-directory OXQ="$OXQ" TALKS="$TALKS" "$@" ) >"$LOG/$n.log" 2>&1
}
# ok 説明 今日 [make の引数…]: 通ること
ok() { n=$((n + 1)); d=$1; shift; if m "$@"; then good "$d"; else bad "$d"; tail -5 "$LOG/$n.log" | sed 's/^/       | /'; fi; }
# ng 説明 期待する文 今日 [make の引数…]: 止まり，記録に期待する文があること
ng() {
  n=$((n + 1)); d=$1; pat=$2; shift 2
  if m "$@"; then bad "$d (止まるはずが通った)"
  elif grep -q -- "$pat" "$LOG/$n.log"; then good "$d"
  else bad "$d (「$pat」が出ない)"; tail -5 "$LOG/$n.log" | sed 's/^/       | /'; fi
}
# is 説明 コマンド…: 条件が成り立つこと
is() { n=$((n + 1)); d=$1; shift; if "$@" >"$LOG/$n.log" 2>&1; then good "$d"; else bad "$d"; fi; }
not() { ! "$@"; }
first1k_has_charset() { head -c 1024 "$1" | grep -qi '<meta charset'; }
sum() { (cd "$1" && find . -type f ! -name index.html ! -name meta.yml | LC_ALL=C sort | xargs cat | cksum); }

say "== 作業用のフォルダ: $WORK"
say "== ox-quarto: $OXQ"
say "== talks (写すだけ): $TALKS"

say "-- 準備"
ng "写しでない公開側には写さない" "make sandbox で作った写しではない" 2030-01-10 publish-check PUB_ROOT="$TALKS"
ok "make sandbox" 2030-01-10 sandbox
is "写しに一覧の頁ができる" test -f "$PUB/index.html"

say "-- 初めての公開 (今日 2030-01-10，講演の 5 日前)"
ng "主題が無いと版は止まる" "主題がまだ無い" 2030-01-10 publish-edition
ok "publish-all" 2030-01-10 publish-all
is "主題の解説・デモ・PDF" test -f "$TOPIC/report/sample-report.html" -a -f "$TOPIC/report/sample-report.pdf" -a -f "$TOPIC/demo/sample-demo.html"
is "版のスライド・配布用 PDF・デモ" test -f "$ED1/talk/publish-sample.html" -a -f "$ED1/talk/publish-sample-handout.pdf" -a -f "$ED1/demo/sample-demo.html"
is "主題・版・一覧の頁 (index.html)" test -f "$TOPIC/index.html" -a -f "$ED1/index.html" -a -f "$PUB/index.html"
is "一覧に主題が出る" grep -q 'publish-sample' "$PUB/index.html"
is "発表者ノートを取り除いた" not grep -q 'class="notes"' "$ED1/talk/publish-sample.html"
is "<meta charset> が先頭 1024 バイトに入った" first1k_has_charset "$ED1/talk/publish-sample.html"
is "版の meta.yml: published は今日" grep -q '^published: 2030-01-10' "$ED1/meta.yml"
is "主題の meta.yml に editions が無い" not grep -q '^editions:' "$TOPIC/meta.yml"
n=$((n + 1)); if (cd "$PUB" && uv run --quiet --script tools/check.py publish-sample) >"$LOG/$n.log" 2>&1; then good "talks の check.py が公開側を通す"; else bad "talks の check.py が公開側を通す"; fi
n=$((n + 1)); if (cd "$PUB" && make --no-print-directory check) >"$LOG/$n.log" 2>&1; then good "talks の make check"; else bad "talks の make check"; fi
: > "$TOPIC/.DS_Store"; : > "$ED1/talk/.DS_Store"
n=$((n + 1)); if (cd "$PUB" && make --no-print-directory check) >"$LOG/$n.log" 2>&1; then good "Finder の .DS_Store があっても make check は通る"; else bad "Finder の .DS_Store があっても make check は通る"; fi
: > "$TOPIC/.hidden"
n=$((n + 1)); if (cd "$PUB" && make --no-print-directory check) >"$LOG/$n.log" 2>&1; then bad "ほかの隠しファイルは誤り (通ってしまった)"; elif grep -q '隠しファイル' "$LOG/$n.log"; then good "ほかの隠しファイルは誤り"; else bad "ほかの隠しファイルは誤り"; fi
rm -f "$TOPIC/.hidden"

say "-- 当日まで上書き，翌日から固定"
printf '\n<!-- 当日の修正 -->\n' >> "$T/slide.html"
ok "講演の日 (2030-01-15) は上書きできる" 2030-01-15 publish-edition
is "上書きが届いた" grep -q '当日の修正' "$ED1/talk/publish-sample.html"
is "「明日から固定」の案内" grep -q '明日から固定' "$LOG/$((n - 1)).log"
is "published は初めの日のまま" grep -q '^published: 2030-01-10' "$ED1/meta.yml"
S1=$(sum "$ED1")
ng "翌日 (2030-01-16) は止まる" "固定されている" 2030-01-16 publish-edition
is "止まったとき版は変わらない" test "$(sum "$ED1")" = "$S1"
printf '\n<!-- 誤字の訂正 -->\n' >> "$T/slide.html"
: > "$ED1/.DS_Store"; : > "$ED1/talk/.DS_Store"   # 固定のあとに Finder が作る
ok "PUB_FIX で訂正できる" 2030-01-16 publish-edition PUB_FIX="誤字の訂正 (試験)"
is "revisions に記録" grep -q '誤字の訂正 (試験)' "$ED1/meta.yml"
is "版の頁に訂正の記録" grep -q '誤字の訂正 (試験)' "$ED1/index.html"
S2=$(sum "$ED1")
ng "訂正でファイルを足すと止まる" "並びを変えられない" 2030-01-16 publish-edition PUB_FIX=x \
   PUB_EDITION_FILES="slide.html=talk/publish-sample.html slide-handout.pdf=talk/publish-sample-handout.pdf ../demo/sample-demo.html=demo/sample-demo.html companion.html=talk/extra.html"
ng "訂正でファイルを減らすと止まる" "並びを変えられない" 2030-01-16 publish-edition PUB_FIX=x \
   PUB_EDITION_FILES="slide.html=talk/publish-sample.html ../demo/sample-demo.html=demo/sample-demo.html"
is "止まったとき版は変わらない" test "$(sum "$ED1")" = "$S2"

say "-- 主題を育てる (版は残る)"
printf '\n<!-- 主題の更新 -->\n' >> "$T/companion.html"
printf '\n<!-- デモの更新 -->\n' >> "$WORK/sample/demo/sample-demo.html"
ok "make publish (2030-01-20)" 2030-01-20 publish
is "主題の解説が新しくなった" grep -q '主題の更新' "$TOPIC/report/sample-report.html"
is "主題のデモは新しい" grep -q 'デモの更新' "$TOPIC/demo/sample-demo.html"
is "版のデモは固定のまま" not grep -q 'デモの更新' "$ED1/demo/sample-demo.html"
is "版のフォルダが残る" test "$(sum "$ED1")" = "$S2"

say "-- 2 つ目の版 (2030-03-02)"
ok "PUB_FIX はまだ固定されていない版では記録しない" 2030-03-01 publish-edition PUB_EDITION=2030-03-02 PUB_FIX=x
is "  (案内が出る)" grep -q 'まだ固定されていない' "$LOG/$n.log"
is "  (revisions は無い)" not grep -q '^revisions:' "$ED2/meta.yml"
is "版ごとの題 (title の上書き)" grep -q '拡張版' "$ED2/meta.yml"
is "主題の頁に 2 つの版" sh -c "grep -q '2030-01-15' '$TOPIC/index.html' && grep -q '2030-03-02' '$TOPIC/index.html'"
ng "版の名前の形でないと止まる" "YYYY-MM-DD" 2030-03-01 publish-edition PUB_EDITION=2030-3-2
ng "原本の editions に無い版は止まる" "editions に" 2030-03-01 publish-edition PUB_EDITION=2030-04-01
ng "主題の部分に版の名前のフォルダは置けない" "版の名前の形" 2030-03-01 publish \
   PUB_FILES="companion.html=2030-05-05/report.html"

say "-- Hugo で組む (samples/publish/hugo．build-index.py の頁と同じになるか)"
HUGO=${HUGO:-$(command -v hugo || true)}
if [ -z "$HUGO" ]; then
  say "  (hugo が無いので飛ばす．HUGO=… で指定できる)"
else
  SITE="$WORK/site"; rm -rf "$SITE"; cp -R "$WORK/sample/hugo" "$SITE"
  rsync -a --exclude 'index.html' "$TOPIC" "$SITE/static/"
  n=$((n + 1)); if "$HUGO" -s "$SITE" --quiet >"$LOG/$n.log" 2>&1; then good "hugo で組める"; else bad "hugo で組める"; fi
  is "一覧・主題・2 つの版の頁" test -f "$SITE/docs/index.html" -a -f "$SITE/docs/publish-sample/index.html" -a -f "$SITE/docs/publish-sample/2030-01-15/index.html" -a -f "$SITE/docs/publish-sample/2030-03-02/index.html"
  n=$((n + 1))
  if python3 - "$PUB" "$SITE/docs" >"$LOG/$n.log" 2>&1 <<'PY2'
import sys, difflib
from html.parser import HTMLParser
class P(HTMLParser):
    def __init__(s): super().__init__(); s.out = []; s.skip = 0
    def handle_starttag(s, t, a):
        a = dict(a)
        if t in ("style", "footer"): s.skip += 1
        if t == "a": s.out.append(f"[a {a.get('href')}]")
        if t in ("html", "title", "h1", "h2", "h3", "p", "li", "article", "nav", "header", "ul", "time"):
            s.out.append(f"<{t} {a.get('lang', '')} {a.get('class', '')} {a.get('id', '')}>")
    def handle_endtag(s, t):
        if t in ("style", "footer"): s.skip -= 1
    def handle_data(s, d):
        if not s.skip and d.strip(): s.out.append(d.strip())
def norm(p):
    x = P(); x.feed(open(p, encoding="utf-8").read()); return x.out
bad = 0
for rel in ["index.html", "publish-sample/index.html", "publish-sample/2030-01-15/index.html", "publish-sample/2030-03-02/index.html"]:
    d = list(difflib.unified_diff(norm(f"{sys.argv[1]}/{rel}"), norm(f"{sys.argv[2]}/{rel}"), lineterm="", n=0))
    print(rel, "差なし" if not d else "\n".join(d)); bad += bool(d)
sys.exit(1 if bad else 0)
PY2
  then good "頁の中身 (題・日付・会場・リンク・訂正の記録) が build-index.py と同じ (footer を除く)"; else bad "頁の中身が build-index.py と同じ"; fi
  n=$((n + 1)); m=0
  for f in $(cd "$TOPIC" && find . -type f ! -name index.html ! -name .DS_Store); do cmp -s "$TOPIC/$f" "$SITE/docs/publish-sample/$f" || { echo "違う・無い: $f"; m=$((m + 1)); }; done >"$LOG/$n.log"
  if [ "$m" -eq 0 ]; then good "資料はすべて同じ場所に同じ中身で出る (URL が変わらない)"; else bad "資料はすべて同じ場所に同じ中身で出る"; fi
  is ".nojekyll も出る" test -f "$SITE/docs/.nojekyll"
  n=$((n + 1)); if (cd "$PUB" && uv run --quiet --script tools/check.py "$SITE/docs/publish-sample") >"$LOG/$n.log" 2>&1; then good "組んだ docs/ を check.py が通す"; else bad "組んだ docs/ を check.py が通す"; fi
  mkdir -p "$SITE/content/publish-sample"
  printf -- '+++\ntitle = "手で直した題"\n+++\n\n手で書いた紹介文．\n' > "$SITE/content/publish-sample/_index.md"
  printf -- '+++\ntitle = "版の題 (手)"\n+++\n\n当日の補足．\n' > "$SITE/content/publish-sample/2030-01-15.md"
  n=$((n + 1)); if "$HUGO" -s "$SITE" --quiet >"$LOG/$n.log" 2>&1; then good "content.org (ox-hugo) の頁を置いても組める"; else bad "content.org の頁を置いても組める"; fi
  is "  主題の題と本文は手書き，一覧と版の頁の案内にも手書きの題" sh -c "grep -q '<h1>手で直した題</h1>' '$SITE/docs/publish-sample/index.html' && grep -q '手で書いた紹介文' '$SITE/docs/publish-sample/index.html' && grep -q '手で直した題' '$SITE/docs/index.html' && grep -q '手で直した題' '$SITE/docs/publish-sample/2030-01-15/index.html'"
  is "  版の題と本文も手書き，会場と資料は meta.yml のまま" sh -c "grep -q '<h1>版の題 (手)</h1>' '$SITE/docs/publish-sample/2030-01-15/index.html' && grep -q '当日の補足' '$SITE/docs/publish-sample/2030-01-15/index.html' && grep -q 'talk/publish-sample.html' '$SITE/docs/publish-sample/2030-01-15/index.html'"
fi

say "-- 版の頁の QR コード (make publish-qr)"
U1=https://noboru-murata.github.io/talks/publish-sample/2030-01-15/
ok "公開側が無くても作れる" 2030-01-10 publish-qr PUB_ROOT=/nonexistent
is "  画像ができた (figs/qr-edition.svg)" sh -c "grep -q '<svg' '$T/figs/qr-edition.svg'"
is "  org に貼る行 (URL は版の頁)" grep -qF "#+QUARTO_QR_CAPTION: $U1" "$LOG/$((n - 1)).log"
Q1=$(cksum < "$T/figs/qr-edition.svg")
ok "作り直し" 2030-01-10 publish-qr
is "  同じ URL なら同じ画像" test "$(cksum < "$T/figs/qr-edition.svg")" = "$Q1"
ok "2 つ目の版と PNG" 2030-01-10 publish-qr PUB_EDITION=2030-03-02 PUB_QR=figs/qr-2.png
is "  URL が 2 つ目の版" grep -qF "https://noboru-murata.github.io/talks/publish-sample/2030-03-02/" "$LOG/$n.log"
is "  PNG ができた" sh -c "head -c 8 '$T/figs/qr-2.png' | grep -q PNG"
ok "editions に無い版は注意だけ" 2030-01-10 publish-qr PUB_EDITION=2030-04-01 PUB_QR=_work/qr-x.svg
is "  (注意が出る)" grep -q '見当たらない' "$LOG/$n.log"
ng "版の名前の形でないと止まる" "YYYY-MM-DD" 2030-01-10 publish-qr PUB_EDITION=2030-4-1
ng "画像は .svg か .png" ".svg か .png" 2030-01-10 publish-qr PUB_QR=figs/qr.jpg
ng "PUB_ID の形" "英小文字" 2030-01-10 publish-qr PUB_ID=Bad_ID

say "-- 配布用 PDF の短い名前 (make slide-handout / talk-handout)"
rm -f "$T/slide-handout.pdf" "$T/companion.pdf"
ok "ファイルの名前の短い名前 (slide-handout) で作る" 2030-01-10 slide-handout
is "  slide-handout.pdf ができた" test -f "$T/slide-handout.pdf"
rm -f "$T/slide-handout.pdf"
ok "前からの名前 talk-handout でも作る" 2030-01-10 talk-handout
is "  slide-handout.pdf ができた" test -f "$T/slide-handout.pdf"
is "  ほかの PDF は作らない" test ! -f "$T/companion.pdf"
ok "  新しければ作り直さない" 2030-01-10 talk-handout
is "  (何もしない)" not grep -q mkpdf "$LOG/$n.log"
ok "ファイル名でも呼べる (従来どおり)" 2030-01-10 slide-handout.pdf
ok "PUB_HANDOUT で指定" 2030-01-10 talk-handout PUB_HANDOUT=companion.pdf
is "  companion.pdf ができた" test -f "$T/companion.pdf"
ng "決まらなければ止まる" "配布用 PDF が決まらない" 2030-01-10 talk-handout \
   PUB_EDITION_FILES="slide.html=talk/publish-sample.html"

say "-- PUB_ROOT の既定 (publish.mk の 2 段上の talks．講演のフォルダの深さによらない)"
L="$WORK/layout"; rm -rf "$L"; mkdir -p "$L/ox-quarto" "$L/talks" "$L/talk_materials/x/talk" "$L/y/talk"
cp -R "$OXQ/tools" "$L/ox-quarto/"; : > "$L/talks/PUBLISHING.md"
printf 'print-root:\n\t@echo "$(PUB_ROOT)"\n\t@test -f "$(PUB_ROOT)/PUBLISHING.md"\n' > "$L/print.mk"
for d in talk_materials/x/talk:../../../ox-quarto y/talk:../../ox-quarto; do
  dir=${d%%:*}; oxq=${d#*:}
  printf 'OXQ ?= %s\nPUB_ID := x\nPUB_EDITION_FILES := slide-handout.pdf=talk/x-handout.pdf\ninclude $(OXQ)/tools/publish.mk\n' "$oxq" > "$L/$dir/Makefile"
  n=$((n + 1)); if (cd "$L/$dir" && make --no-print-directory -f Makefile -f "$L/print.mk" print-root) >"$LOG/$n.log" 2>&1; then good "  $dir から talks が見つかる ($(head -1 "$LOG/$n.log"))"; else bad "  $dir から talks が見つかる"; fi
done
n=$((n + 1)); if (cd "$L/y/talk" && make --no-print-directory -f Makefile -f "$L/print.mk" print-root PUB_ROOT=/nonexistent) >"$LOG/$n.log" 2>&1; then bad "  PUB_ROOT=… で変えられる (止まるはずが通った)"; else good "  PUB_ROOT=… で変えられる"; fi

say "-- 配布用 PDF の並べ方 (handout-grid．oxq-pdf.py -n で渡す指定だけを見る)"
# quarto の代わり: inspect に qmd の front matter の key: value をそのまま返す (quarto の無い所でも試せる)
mkdir -p "$WORK/bin" "$T/_work"
cat > "$WORK/bin/quarto" <<'STUB'
#!/usr/bin/env python3
import json, re, sys
if sys.argv[1:2] != ["inspect"]: sys.exit("stub quarto: inspect だけ")
text = open(sys.argv[2], encoding="utf-8").read()
m = re.match(r"---\n(.*?)\n---", text, re.S)
meta = dict(l.split(": ", 1) for l in (m.group(1).splitlines() if m else []) if ": " in l)
print(json.dumps({"formats": {"revealjs": {"metadata": meta}}}))
STUB
chmod +x "$WORK/bin/quarto"
OPATH=$PATH; PATH="$WORK/bin:$PATH"; export PATH
printf -- '---\ntitle: g\nhandout-grid: 4x2\nnotes-pdf-per-page: 3\n---\n' > "$T/_work/g.qmd"
printf -- '---\ntitle: d\n---\n' > "$T/_work/d.qmd"
printf -- '---\ntitle: b\nhandout-grid: 4by2\n---\n' > "$T/_work/b.qmd"
: > "$T/_work/g.html"; : > "$T/_work/d.html"; : > "$T/_work/b.html"
ok "org の handout-grid を渡す (make … -handout.pdf)" 2030-01-10 _work/g-handout.pdf PUB_HANDOUT_OPTS=-n
is "  --grid 4x2" grep -q -- '--no-notes --grid 4x2' "$LOG/$n.log"
is "  notes-pdf-* (ノート付きの指定) は渡さない" not grep -q -- '--per-page 3' "$LOG/$((n - 1)).log"
ok "PUB_HANDOUT_OPTS の --grid が優先" 2030-01-10 _work/g-handout.pdf PUB_HANDOUT_OPTS="-n --grid 2x1"
is "  --grid 2x1" sh -c "grep -q -- '--grid 2x1' '$LOG/$n.log' && ! grep -q -- '--grid 4x2' '$LOG/$n.log'"
ok "PUB_HANDOUT_OPTS の --per-page も優先" 2030-01-10 _work/g-handout.pdf PUB_HANDOUT_OPTS="-n --per-page 4"
is "  --per-page 4 だけ" sh -c "grep -q -- '--per-page 4' '$LOG/$n.log' && ! grep -q -- '--grid' '$LOG/$n.log'"
ok "書かなければ今と同じ (指定なし = 6 枚)" 2030-01-10 _work/d-handout.pdf PUB_HANDOUT_OPTS=-n
is "  --grid も --per-page も渡さない" sh -c "grep -q -- '--no-notes' '$LOG/$n.log' && ! grep -q -- '--grid\|--per-page' '$LOG/$n.log'"
ng "handout-grid の形が違えば止まる" "段x列" 2030-01-10 _work/b-handout.pdf PUB_HANDOUT_OPTS=-n
printf -- '---\ntitle: n\nnotes-pdf-detail: t\nnotes-pdf-layout: side\n---\n' > "$T/_work/n.qmd"; : > "$T/_work/n.html"
n=$((n + 1)); if (cd "$T" && python3 "$OXQ/tools/oxq-pdf.py" _work/n.qmd --html _work/n.html -n) >"$LOG/$n.log" 2>&1 \
   && grep -q -- '--notes-detail' "$LOG/$n.log"; then good "ノート付き: notes-pdf-detail:t で --notes-detail を渡す"; else bad "ノート付き: notes-pdf-detail:t で --notes-detail を渡す"; fi
n=$((n + 1)); if (cd "$T" && python3 "$OXQ/tools/oxq-pdf.py" _work/d.qmd --html _work/d.html -n) >"$LOG/$n.log" 2>&1 \
   && ! grep -q -- '--notes-detail' "$LOG/$n.log"; then good "ノート付き: 書かなければ渡さない (.detail は省く)"; else bad "ノート付き: 書かなければ渡さない"; fi
n=$((n + 1)); if (cd "$T" && python3 "$OXQ/tools/oxq-pdf.py" _work/n.qmd --html _work/n.html --no-notes -n) >"$LOG/$n.log" 2>&1 \
   && ! grep -q -- '--notes-detail\|--layout' "$LOG/$n.log"; then good "ノートなし: notes-pdf-* は渡さない"; else bad "ノートなし: notes-pdf-* は渡さない"; fi
PATH=$OPATH; export PATH
n=$((n + 1))
if python3 - "$OXQ/tools/notes-handout.py" >"$LOG/$n.log" 2>&1 <<'PY2'
import importlib.util, sys
s = importlib.util.spec_from_file_location("nh", sys.argv[1]); m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
ok = True
for g in ["3x2", "4x2", "4x3", "2x1", "5x2", "6x3", "1x1", "10x6"]:
    r, c = m.parse_grid(g); w = m.grid_cell_width(r, c); h = m.grid_height(r, w)
    fits = h <= m.BODY_H and w * c + m.COL_GAP * (c - 1) <= m.BODY_W + 0.01
    print(g, round(w, 1), round(h, 1), fits); ok &= fits
ok &= abs(m.grid_cell_width(3, 2) - 84.0) < 0.01      # 既定 (6 枚) と同じ幅
sys.exit(0 if ok else 1)
PY2
then good "notes-handout.py の格子は頁に収まる (幅・高さの見積もり)"; else bad "notes-handout.py の格子は頁に収まる"; fi

say "-- 誤りを見つける"
mkdir -p "$T/_work" "$T/_quarto/local"
(cd "$T" && python3 ../mkpdf.py --notes slide.html -o _work/leak.pdf) >/dev/null 2>&1
ng "配布用 PDF に発表者ノート" "発表者ノートの文が載っている" 2030-03-01 publish-edition-check PUB_EDITION=2030-03-02 \
   PUB_EDITION_FILES="slide.html=talk/publish-sample.html _work/leak.pdf=talk/publish-sample-handout.pdf ../demo/sample-demo.html=demo/sample-demo.html"
ok "解説の PDF (report-pdf) はノートと照合しない" 2030-03-01 publish-check \
   PUB_FILES="companion.html=report/sample-report.html _work/leak.pdf=report/sample-report.pdf ../demo/sample-demo.html=demo/sample-demo.html"
printf '<!doctype html><html><head><meta charset="utf-8"><title>x</title></head><body><img src="missing.png"></body></html>\n' > "$T/_work/broken.html"
ng "公開しないファイルへの参照" "公開するファイルに入っていない" 2030-03-01 publish-check PUB_FILES="_work/broken.html=report/broken.html"
ng "相対位置が変わる並び" "公開側では" 2030-03-01 publish-edition-check PUB_EDITION=2030-03-02 \
   PUB_EDITION_FILES="slide.html=talk/publish-sample.html ../demo/sample-demo.html=extras/sample-demo.html"
printf '* 原本\n' > "$T/_work/source.org"
ng "公開しない種類のファイル (.org)" "公開しない種類" 2030-03-01 publish-check \
   PUB_FILES="companion.html=report/sample-report.html ../demo/sample-demo.html=demo/sample-demo.html companion.pdf=report/sample-report.pdf _work/source.org=report/source.org"
printf '<!doctype html><html><head><meta charset="utf-8"><title>x</title></head><body><p>/Users/someone/talk</p></body></html>\n' > "$T/_work/local.html"
ng "手元の絶対パス" "手元の絶対パス" 2030-03-01 publish-check \
   PUB_FILES="companion.html=report/sample-report.html ../demo/sample-demo.html=demo/sample-demo.html companion.pdf=report/sample-report.pdf _work/local.html=report/local.html"
python3 -c "import os,sys; open(sys.argv[1],'wb').write(b'\x89PNG\r\n\x1a\n'+os.urandom(1024))" "$T/_quarto/local/fake-logo.png"
python3 - "$T" <<'PY'
import base64, sys
t = sys.argv[1]
b = base64.b64encode(open(f"{t}/_quarto/local/fake-logo.png", "rb").read()).decode()
open(f"{t}/_work/logo.html", "w").write(f'<!doctype html><html><head><meta charset="utf-8"><title>x</title></head>'
                                        f'<body><img src="data:image/png;base64,{b}"></body></html>\n')
PY
ng "禁止した画像 (ロゴ) の埋め込み" "禁止した画像" 2030-03-01 publish-check \
   PUB_FILES="companion.html=report/sample-report.html ../demo/sample-demo.html=demo/sample-demo.html companion.pdf=report/sample-report.pdf _work/logo.html=report/logo.html"
ng "PUB_ID の形" "英小文字" 2030-03-01 publish-check PUB_ID=Bad_ID
## 講演の雛形 samples/talk/Makefile と tools/talk.mk (make -n で組み立てだけを見る．emacs と quarto は要らない) ----
say "== 講演の雛形 (talk.mk)"
K="$WORK/talkmk/k/talk"; mkdir -p "$K" "$WORK/talkmk/k/demo"
sed 's/<topic-id>/my-topic/' "$OXQ/samples/talk/Makefile" > "$K/Makefile"
touch "$K/slide.org" "$K/companion.org" "$K/slide-a.org" "$WORK/talkmk/k/demo/d.html"
printf '@book{a,title={x}}\n' > "$WORK/talkmk/lib.bib"
# tm 説明 期待する文 [make の引数…]: 雛形の講演で make を走らせ，記録に期待する文があること
tm() {
  n=$((n + 1)); d=$1; pat=$2; shift 2
  ( cd "$K" && make --no-print-directory OXQ="$OXQ" LIBRARY="$WORK/talkmk/none.bib" "$@" ) >"$LOG/$n.log" 2>&1
  if grep -q -- "$pat" "$LOG/$n.log"; then good "$d"; else bad "$d (「$pat」が出ない)"; tail -5 "$LOG/$n.log" | sed 's/^/       | /'; fi
}
tm "版が未定でも make slide-handout (雛形)" "oxq-pdf.py slide.qmd --html slide.html --no-notes *-o slide-handout.pdf" -n slide-handout
tm "talk-handout も同じ" "no-notes *-o slide-handout.pdf" -n talk-handout
tm "make だけで slide と companion" "quarto render companion.qmd --to html" -n
tm "make slide は revealjs" "quarto render slide.qmd --to revealjs" -n slide
tm "make slide-notes" "oxq-pdf.py slide.qmd --html slide.html -o slide-notes.pdf" -n slide-notes
tm "REPORT が空なら make は slide だけ" "slide.qmd --to revealjs" -n REPORT=
is "REPORT が空なら解説文を作らない" not grep -q companion "$LOG/$n.log"
tm "別案 (ALTS) のスライドとノート付き" "oxq-pdf.py slide-a.qmd --html slide-a.html -o slide-a-notes.pdf" -n ALTS=slide-a alts slide-a-notes.pdf
tm "LIBRARY が無ければ bib は止まる" "refs.bib は作り直さない" bib
tm "LIBRARY が無くても make slide は通る (refs.bib を作らない)" "slide.qmd --to revealjs" -n slide
is "LIBRARY が無いとき oxq-bib.py を呼ばない" not grep -q oxq-bib "$LOG/$n.log"
mkdir -p "$WORK/talkmk/k/research"; : > "$WORK/talkmk/k/research/pending.bib"
tm "LIBRARY があれば bib (pending.bib を --extra で)" "\-\-extra ../research/pending.bib" -n bib LIBRARY="$WORK/talkmk/lib.bib"
touch "$K/slide.qmd" "$K/companion.qmd"; sleep 1; touch "$K/slide.html" "$K/companion.html"
tm "make snapshot (oxq-snapshot.sh)" "を作った" snapshot SNAP=2030-02-01
is "スナップショットに talk/，demo/，SOURCE，MEMO.org" test -f "$WORK/talkmk/k/snapshots/2030-02-01/talk/slide.html" -a -f "$WORK/talkmk/k/snapshots/2030-02-01/demo/d.html" -a -f "$WORK/talkmk/k/snapshots/2030-02-01/SOURCE" -a -f "$WORK/talkmk/k/snapshots/2030-02-01/MEMO.org"
tm "同じ名前のスナップショットは止まる" "既にある" snapshot SNAP=2030-02-01
tm "make help" "make slide-handout" help
printf 'OXQ ?= ../../../ox-quarto\nTALK := slide\nPUB_ID := my-topic\nPUB_FILES :=\ninclude $(OXQ)/tools/publish.mk\n' > "$K/Makefile.old"
tm "publish.mk だけの Makefile でも版が未定で slide-handout (TALK から)" "no-notes *-o slide-handout.pdf" -n -f Makefile.old slide-handout

## 議論用 (非公開) の写し: make publish-draft (oxq-draft.py) ----------------
if command -v npx >/dev/null 2>&1 && command -v qpdf >/dev/null 2>&1; then
  say "== 議論用の写し (publish-draft)"
  DR="$WORK/sample/_drafts"; SN="$WORK/sample/_snapshots"; S1="$SN/2030-01-14"
  mkdir -p "$DR" "$S1/talk" "$S1/demo" "$T/_work"
  cp "$T/slide.html" "$T/companion.html" "$S1/talk/"
  cp "$WORK/sample/demo/sample-demo.html" "$S1/demo/"
  (cd "$T" && python3 ../mkpdf.py slide.html -o "$S1/talk/slide-handout.pdf") >/dev/null 2>&1
  printf '* メモ\n' > "$S1/MEMO.org"
  ng "写しの名前が無いと止まる" "写しの名前" 2030-01-14 publish-draft
  ng "合言葉のファイルが無いと止まる" "合言葉のファイル" 2030-01-14 publish-draft DRAFT=2030-01-14
  ok "draft-pass で合言葉を作る" 2030-01-14 draft-pass
  is "合言葉のファイルは本人だけが読める" sh -c "ls -l '$T/_work/draft.pass' | grep -q '^-rw-------'"
  ng "写しが無いと止まる" "が無い" 2030-01-14 publish-draft DRAFT=2030-01-13
  ng "DRAFT_ID の形" "英小文字" 2030-01-14 publish-draft DRAFT=2030-01-14 DRAFT_ID=Bad_ID
  ok "publish-draft (2030-01-14)" 2030-01-14 publish-draft DRAFT=2030-01-14
  D1="$DR/publish-sample/2030-01-14"
  is "html と PDF が同じ並びで置かれる" test -f "$D1/talk/slide.html" -a -f "$D1/talk/companion.html" -a -f "$D1/demo/sample-demo.html" -a -f "$D1/talk/slide-handout.pdf" -a -f "$D1/index.html"
  is "html / PDF 以外 (MEMO.org) は写さない" not test -e "$D1/MEMO.org"
  is "どの html も暗号化されている" sh -c "for f in \$(find '$DR/publish-sample' -name '*.html'); do grep -q 'name=\"generator\" content=\"oxq-draft\"' \$f && grep -q staticrypt \$f || exit 1; done"
  title=$(sed -n 's/.*<title>\([^<]*\)<.*/\1/p' "$T/slide.html" | head -1)
  is "平文 (スライドの題) が残っていない" not grep -rqF "$title" "$DR"
  is "PDF に合言葉が掛かっている" qpdf --is-encrypted "$D1/talk/slide-handout.pdf"
  is "PDF は合言葉で開ける" qpdf --password="$(head -1 "$T/_work/draft.pass")" --check "$D1/talk/slide-handout.pdf"
  is "「覚える」は講演ごとの名前で，既定で印が付く" sh -c "grep -q oxq_draft_publish-sample_passphrase '$D1/talk/slide.html' && grep -q 'name=\"remember\" checked' '$D1/talk/slide.html'"
  is "頁に noindex" grep -q 'noindex' "$D1/talk/slide.html"
  salt=$(sed -n 's/.*"salt": *"\([0-9a-f]*\)".*/\1/p' "$DR/publish-sample/.staticrypt.json")
  rm -rf "$WORK/dec"
  (cd "$DR/publish-sample" && STATICRYPT_PASSWORD="$(head -1 "$T/_work/draft.pass")" npx --yes staticrypt@3.5.4 2030-01-14 -r --decrypt \
     --salt "$salt" --config false -d ../../dec) >"$LOG/dec.log" 2>&1
  is "合言葉で解くと元の html に戻る" sh -c "cmp '$WORK/sample/dec/2030-01-14/talk/slide.html' '$S1/talk/slide.html' && cmp '$WORK/sample/dec/2030-01-14/demo/sample-demo.html' '$S1/demo/sample-demo.html'"
  is "drafts の入口に講演の名前を出さない" not grep -q 'publish-sample' "$DR/index.html"
  is "drafts に .nojekyll" test -f "$DR/.nojekyll"
  rm "$S1/talk/companion.html"
  ok "同じ名前で出し直すと置き換わる" 2030-01-15 publish-draft DRAFT=2030-01-14
  is "消したファイルは残らない" not test -e "$D1/talk/companion.html"
  mkdir -p "$SN/2030-01-20-b/talk"; cp "$T/slide.html" "$SN/2030-01-20-b/talk/"
  ng "写しに無いファイル (デモ) を参照すると止まる" "写しに無いファイル" 2030-01-20 publish-draft DRAFT=2030-01-20-b
  cp -R "$S1/demo" "$SN/2030-01-20-b/"
  ok "2 つめの写し (2030-01-20-b)" 2030-01-20 publish-draft DRAFT=2030-01-20-b
  is "講演の一覧も暗号化され，入口に写しの名前を出さない" sh -c "grep -q oxq-draft '$DR/publish-sample/index.html' && grep -q staticrypt '$DR/publish-sample/index.html' && ! grep -q 2030 '$DR/index.html'"
  mkdir -p "$SN/2030-01-21/talk"
  printf '<!doctype html><html><head><meta charset="utf-8"><title>x</title></head><body><img src="fig.png"></body></html>\n' > "$SN/2030-01-21/talk/fig.html"
  printf 'png' > "$SN/2030-01-21/talk/fig.png"
  ng "暗号化しないファイル (画像) を参照すると止まる" "暗号化しないファイル" 2030-01-21 publish-draft DRAFT=2030-01-21
  is "止まったときは何も置かない" not test -e "$DR/publish-sample/2030-01-21"
  printf 'short\n' > "$T/_work/short.pass"; chmod 600 "$T/_work/short.pass"
  ng "合言葉が短いと止まる" "合言葉が短い" 2030-01-21 publish-draft DRAFT=2030-01-20-b DRAFT_PASS=_work/short.pass
  is "drafts の写しは talks に触れない" not test -e "$PUB/publish-sample/2030-01-14"
else
  say "== 議論用の写し (publish-draft) は npx か qpdf が無いので飛ばす"
fi

n=$((n + 1)); if (cd "$PUB" && uv run --quiet --script tools/check.py publish-sample) >"$LOG/$n.log" 2>&1; then good "誤りの試験のあとも公開側は check を通る"; else bad "誤りの試験のあとも公開側は check を通る"; fi

say "== 結果: 通った $pass，だめ $fail (記録は $LOG)"
[ "$fail" -eq 0 ]
