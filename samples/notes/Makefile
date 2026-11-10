# notes/Makefile — 研究ノートの雛形 (ox-quarto/samples/notes/Makefile を写して，OXQ と NOT_NOTES を直す)
#
# 規則は ox-quarto の tools/notes.mk にまとめてあり，ここにはフォルダごとの変数だけを書く．使い方は make help．
#   make            ノートをすべて PDF に        make html       すべて html に
#   make <名前>.pdf 1 本だけ                      make links      _quarto と _extensions のリンクを張る (はじめに 1 度)
#   make bib        引用している文献を refs.bib に (NOTES_BIB を書いたとき)
# macOS 同梱の make (3.81) で動くように書いている．値の後ろに # で注釈を書かない (空白が値に入る)．

# ox-quarto の場所 (このフォルダからの相対パス．講演の research/ なら ../../../ox-quarto)
OXQ ?= ../..

# ノートでない org (書誌の控えなど) を並べる
#   NOT_NOTES := to-register.org
# make だけで html も作る
#   NOTES_ALL := pdf html
# 文献を引くノートがあれば (LIBRARY から抜き出す．講演の research/ なら PENDING は pending.bib のまま)
#   NOTES_BIB := refs.bib

include $(OXQ)/tools/notes.mk
