# talk/Makefile — 講演の雛形 (ox-quarto/samples/talk/Makefile を講演の talk/ に写して，<…> の所を直す)
#
# 型は _meta/handoff-talks.md (slide.org → slide.html，companion.org → companion.html / .pdf)．
# 規則は ox-quarto の tools/talk.mk にまとめてあり，ここには講演ごとの変数だけを書く．使い方は make help．
#
#   make                 slide と companion
#   make slide           スライド (slide.html)
#   make slide-notes     ノート付きの PDF (slide-notes.pdf)
#   make slide-handout   配布用 PDF (ノートなし．slide-handout.pdf．版が未定でも作れる)
#   make companion       解説文の html と PDF
#   make bib             org で引用している文献を library.bib から抜き出して refs.bib を作る
#   make snapshot        議論用のスナップショット (../snapshots/<今日>/．重い版は snapshot-full)
#   make publish-qr      版の頁の QR コード (figs/qr-edition.svg)
#   make publish / publish-edition / publish-all   talks への公開 (talks/PUBLISHING.md)
#   make publish-draft DRAFT=<名前>   議論用の写しを暗号化して drafts に (talks/PUBLISHING.md の 10)
# macOS 同梱の make (3.81) で動くように書いている．並列 (-j) では動かさない．

OXQ    ?= ../../../ox-quarto
TALK   := slide
REPORT := companion

# 講演に合わせて変えるもの (全部の一覧は ox-quarto/tools/talk.mk の先頭．値の後ろに # で注釈を書かない: 空白が値に入る)
# 解説文がまだ無いうちは REPORT を空にする (make は slide だけ)
#   REPORT :=
# 比較用の別案のスライド (make alts)
#   ALTS := slide-a slide-b
# 引用を拾う org を足す
#   BIB_ORGS = $(TALK).org $(REPORT).org ../report/companion-long.org

## 公開 (talks/PUBLISHING.md．公開の情報は ../publish/meta.yml) ---------------
# 主題 id は一度決めたら変えない．版 (講演の日) が決まったら PUB_EDITION と PUB_EDITION_FILES を有効にし，
# ../publish/meta.yml の editions にも書く．
PUB_ID            := <topic-id>
PUB_FILES         :=
# PUB_FILES       := ../demo/<demo>.html=demo/<demo>.html
# PUB_EDITION       := YYYY-MM-DD
# PUB_EDITION_FILES := $(TALK).html=talk/$(PUB_ID).html \
#                      $(TALK)-handout.pdf=talk/$(PUB_ID)-handout.pdf \
#                      ../demo/<demo>.html=demo/<demo>.html
# drafts (議論用の写し) の URL に出る名前．既定は PUB_ID
# DRAFT_ID          := <URL に出してよい名前>

include $(OXQ)/tools/talk.mk

# 講演に固有の規則はここから下に (例: 文献ガイドの html)
