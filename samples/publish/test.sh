#!/bin/sh
# test.sh — publish.mk / oxq-publish.py / talks の check.py と build-index.py を，作り物の講演で試す．
#
#   sh samples/publish/test.sh [作業用のフォルダ]
#
# samples/publish を作業用のフォルダ (既定は mktemp -d) に写し，その中で make を走らせる．
# リポジトリの中のファイルは書き換えない．公開側も本物の talks ではなく写し (make sandbox)．
# 本物の talks は TALKS (既定: ox-quarto と同じ階層の talks) から tools/ と PUBLISHING.md を写すだけ．
# 要るもの: make，uv，rsync，python3．
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
rsync -a --exclude _talks --exclude _publish --exclude _work --exclude '*.pdf' "$HERE/" "$WORK/sample/"
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

say "-- 当日まで上書き，翌日から固定"
printf '\n<!-- 当日の修正 -->\n' >> "$T/sample-talk.html"
ok "講演の日 (2030-01-15) は上書きできる" 2030-01-15 publish-edition
is "上書きが届いた" grep -q '当日の修正' "$ED1/talk/publish-sample.html"
is "「明日から固定」の案内" grep -q '明日から固定' "$LOG/$((n - 1)).log"
is "published は初めの日のまま" grep -q '^published: 2030-01-10' "$ED1/meta.yml"
S1=$(sum "$ED1")
ng "翌日 (2030-01-16) は止まる" "固定されている" 2030-01-16 publish-edition
is "止まったとき版は変わらない" test "$(sum "$ED1")" = "$S1"
printf '\n<!-- 誤字の訂正 -->\n' >> "$T/sample-talk.html"
ok "PUB_FIX で訂正できる" 2030-01-16 publish-edition PUB_FIX="誤字の訂正 (試験)"
is "revisions に記録" grep -q '誤字の訂正 (試験)' "$ED1/meta.yml"
is "版の頁に訂正の記録" grep -q '誤字の訂正 (試験)' "$ED1/index.html"
S2=$(sum "$ED1")
ng "訂正でファイルを足すと止まる" "並びを変えられない" 2030-01-16 publish-edition PUB_FIX=x \
   PUB_EDITION_FILES="sample-talk.html=talk/publish-sample.html sample-talk-handout.pdf=talk/publish-sample-handout.pdf ../demo/sample-demo.html=demo/sample-demo.html sample-report.html=talk/extra.html"
ng "訂正でファイルを減らすと止まる" "並びを変えられない" 2030-01-16 publish-edition PUB_FIX=x \
   PUB_EDITION_FILES="sample-talk.html=talk/publish-sample.html ../demo/sample-demo.html=demo/sample-demo.html"
is "止まったとき版は変わらない" test "$(sum "$ED1")" = "$S2"

say "-- 主題を育てる (版は残る)"
printf '\n<!-- 主題の更新 -->\n' >> "$T/sample-report.html"
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
   PUB_FILES="sample-report.html=2030-05-05/report.html"

say "-- 誤りを見つける"
mkdir -p "$T/_work" "$T/_quarto/local"
(cd "$T" && python3 ../mkpdf.py --notes sample-talk.html -o _work/leak.pdf) >/dev/null 2>&1
ng "配布用 PDF に発表者ノート" "発表者ノートの文が載っている" 2030-03-01 publish-edition-check PUB_EDITION=2030-03-02 \
   PUB_EDITION_FILES="sample-talk.html=talk/publish-sample.html _work/leak.pdf=talk/publish-sample-handout.pdf ../demo/sample-demo.html=demo/sample-demo.html"
ok "解説の PDF (report-pdf) はノートと照合しない" 2030-03-01 publish-check \
   PUB_FILES="sample-report.html=report/sample-report.html _work/leak.pdf=report/sample-report.pdf ../demo/sample-demo.html=demo/sample-demo.html"
printf '<!doctype html><html><head><meta charset="utf-8"><title>x</title></head><body><img src="missing.png"></body></html>\n' > "$T/_work/broken.html"
ng "公開しないファイルへの参照" "公開するファイルに入っていない" 2030-03-01 publish-check PUB_FILES="_work/broken.html=report/broken.html"
ng "相対位置が変わる並び" "公開側では" 2030-03-01 publish-edition-check PUB_EDITION=2030-03-02 \
   PUB_EDITION_FILES="sample-talk.html=talk/publish-sample.html ../demo/sample-demo.html=extras/sample-demo.html"
printf '* 原本\n' > "$T/_work/source.org"
ng "公開しない種類のファイル (.org)" "公開しない種類" 2030-03-01 publish-check \
   PUB_FILES="sample-report.html=report/sample-report.html ../demo/sample-demo.html=demo/sample-demo.html sample-report.pdf=report/sample-report.pdf _work/source.org=report/source.org"
printf '<!doctype html><html><head><meta charset="utf-8"><title>x</title></head><body><p>/Users/someone/talk</p></body></html>\n' > "$T/_work/local.html"
ng "手元の絶対パス" "手元の絶対パス" 2030-03-01 publish-check \
   PUB_FILES="sample-report.html=report/sample-report.html ../demo/sample-demo.html=demo/sample-demo.html sample-report.pdf=report/sample-report.pdf _work/local.html=report/local.html"
python3 -c "import os,sys; open(sys.argv[1],'wb').write(b'\x89PNG\r\n\x1a\n'+os.urandom(1024))" "$T/_quarto/local/fake-logo.png"
python3 - "$T" <<'PY'
import base64, sys
t = sys.argv[1]
b = base64.b64encode(open(f"{t}/_quarto/local/fake-logo.png", "rb").read()).decode()
open(f"{t}/_work/logo.html", "w").write(f'<!doctype html><html><head><meta charset="utf-8"><title>x</title></head>'
                                        f'<body><img src="data:image/png;base64,{b}"></body></html>\n')
PY
ng "禁止した画像 (ロゴ) の埋め込み" "禁止した画像" 2030-03-01 publish-check \
   PUB_FILES="sample-report.html=report/sample-report.html ../demo/sample-demo.html=demo/sample-demo.html sample-report.pdf=report/sample-report.pdf _work/logo.html=report/logo.html"
ng "PUB_ID の形" "英小文字" 2030-03-01 publish-check PUB_ID=Bad_ID
n=$((n + 1)); if (cd "$PUB" && uv run --quiet --script tools/check.py publish-sample) >"$LOG/$n.log" 2>&1; then good "誤りの試験のあとも公開側は check を通る"; else bad "誤りの試験のあとも公開側は check を通る"; fi

say "== 結果: 通った $pass，だめ $fail (記録は $LOG)"
[ "$fail" -eq 0 ]
