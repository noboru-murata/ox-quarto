#!/bin/sh
# oxq-snapshot.sh — 議論のためのスナップショットを ../snapshots/<名前>/ に作る (talk.mk の make snapshot / snapshot-full から呼ぶ)
#   講演の talk/ で動かす．講演 gradient_design の talk/snapshot.sh を共通にしたもの (2026-10-27)
#   環境変数 SNAP_KIND (light / full) を SOURCE と一覧に書く
#
#   sh snapshot.sh <名前> <ファイル ...>
#     <名前>      YYYY-MM-DD[-b]．既にあれば止める (スナップショットは書き換えない．別の名前で作る)
#     <ファイル>  talk/ の中の書き出し済みのもの (slide.html，*.pdf，companion.html など)．無いものは飛ばして知らせる
#
# 作るもの:
#   ../snapshots/<名前>/talk/   渡したファイル (と companion_files/ などの付属のフォルダ)
#   ../snapshots/<名前>/demo/   ../demo/ の html (スライドが ../demo/ で読むので同じ並び)
#   ../snapshots/<名前>/SOURCE  講演と ox-quarto の commit，未 commit の変更の有無
#   ../snapshots/<名前>/MEMO.org 議論のメモの雛形
#   ../snapshots/README.org     一覧に 1 行足す
# git の commit と tag (snap/<名前>) はこのスクリプトではしない．
set -eu
name=${1:?名前 (YYYY-MM-DD[-b]) が要る}; shift
kind=${SNAP_KIND:-light}
case "$name" in
  [0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]|[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]-[a-z]) ;;
  *) echo "snapshot: 名前は YYYY-MM-DD か YYYY-MM-DD-b の形 ($name)" >&2; exit 1 ;;
esac
root=../snapshots
dir=$root/$name
if [ -e "$dir" ]; then
  echo "snapshot: $dir は既にある (書き換えない．SNAP=$name-b などで別の名前に)" >&2; exit 1
fi
mkdir -p "$dir/talk" "$dir/demo"
missing=""
for f in "$@"; do
  if [ -f "$f" ]; then
    cp -p "$f" "$dir/talk/"
    d="${f%.*}_files"; [ -d "$d" ] && cp -Rp "$d" "$dir/talk/"
  else
    missing="$missing $f"
  fi
done
for f in ../demo/*.html; do [ -f "$f" ] && cp -p "$f" "$dir/demo/"; done
oxq=${OXQ:-../../../ox-quarto}
{
  echo "snapshot: $name ($kind)"
  echo "made:     $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "talk:     $(git -C .. rev-parse --short HEAD 2>/dev/null || echo '?')"
  if [ -n "$(git -C .. status --porcelain -- talk demo 2>/dev/null)" ]; then
    echo "          (talk/ か demo/ に未 commit の変更があった．この版はその commit と少し違う)"
  fi
  echo "ox-quarto: $(git -C "$oxq" rev-parse --short HEAD 2>/dev/null || echo '?')"
  echo "files:    $*"
  [ -n "$missing" ] && echo "missing: $missing"
} > "$dir/SOURCE"
cat > "$dir/MEMO.org" <<MEMO
#+TITLE: スナップショット $name の議論のメモ

* 誰と・どこで

* 見せたもの
- talk/ のファイル (SOURCE の files)．送ったもの:
- 主に議論した頁:

* 出た意見・問い

* 決めたこと (NOTES.md に移したら印を付ける)

* 次にやること
MEMO
if [ ! -f "$root/README.org" ]; then
  cat > "$root/README.org" <<'HEAD'
#+TITLE: 議論のスナップショットの一覧 (時系列．新しいものが下)

議論に使ったスライドの写し．~make snapshot~ (talk/) で作り，書き換えない．仕組みは講演の NOTES.md と _meta/handoff-talks.md の「議論用のスナップショット」．
各フォルダ: talk/ (slide.html・PDF・解説文)，demo/，SOURCE (commit)，MEMO.org (議論のメモ)．

| 名前 | 種類 | 相手・場 | 要点 | メモ |
|------+------+----------+------+------|
HEAD
fi
printf '| %s | %s | | | [[file:%s/MEMO.org][MEMO]] |\n' "$name" "$kind" "$name" >> "$root/README.org"
echo "== $dir を作った (git の commit と tag snap/$name はまだ．Web で見せるなら make publish-draft DRAFT=$name)"
[ -n "$missing" ] && echo "== 無かったので飛ばした:$missing (make で作ってから入れ直すなら，フォルダを消して作り直す)" >&2
exit 0
