# notes.mk — 研究ノート・調べ物のノート (*.org) を PDF / html にする共通の部品 (2026-11-10)
#
# 講演の research/，講義のメモ，本の下調べなど，org のノートを何本も置くフォルダで使う．
# そのフォルダの Makefile は変数を数行書いて include するだけにする (雛形は samples/notes/Makefile)．
#
#   OXQ ?= ../../../ox-quarto
#   NOT_NOTES := to-register.org
#   include $(OXQ)/tools/notes.mk
#
# ノートの頭書き (Tufte 形式: 脚注・文献・補足の図が右の余白に．_quarto/yaml/note.yaml)．雛形は samples/notes/example.org
#   #+TITLE: …
#   #+AUTHOR: …
#   :QUARTO:
#   #+SETUPFILE: _quarto/org/note.org
#   #+BIBLIOGRAPHY: refs.bib        (文献を引くとき)
#   :END:
#
# ターゲット (make help でも出る):
#   make                ノートをすべて PDF に (NOTES_ALL で変えられる)
#   make pdf / html     ノートをすべて PDF / html に
#   make <名前>.pdf     1 本だけ (<名前>.html も)
#   make qmd            org → qmd だけ
#   make bib            ノートで引用している文献を LIBRARY から抜き出して refs.bib に (NOTES_BIB を書いたとき)
#   make links          _quarto と _extensions のリンクを張る (OXQ を指す．はじめに 1 度)
#   make clean          生成物を消す (org は消さない)
#
# 変えられる変数 (既定):
#   NOT_NOTES  (空)              ノートでない org (書誌の控えなど)
#   NOTES      (*.org から NOT_NOTES を除いたもの)
#   NOTES_ALL  pdf               make だけで作るもの (pdf html も)
#   ASSETS     *.bib figs/*      変わるとノートを作り直すもの
#   NOTES_BIB  (空)              文献の抜き出し先 (例 refs.bib)．空なら make bib は何もしない
#   LIBRARY    $(OXQ)/../biblio/bib/library.bib   文献の正本 (読むだけ)
#   PENDING    pending.bib       登録待ちの文献 (あれば oxq-bib.py --extra で読む)
#   EMACS emacs / QUARTO quarto / PYTHON python3
#
# 注意 (README.org の「研究ノート」):
#   - #+OPTIONS: toc:2 などで org の目次を有効にすると，note.yaml の目次と二重になる (org の目次は toc:nil のまま)．
#   - 表の中の数式に | (絶対値) を書くと org が列の区切りと読む．\lvert … \rvert で書く．
# macOS 同梱の make (3.81) で動くように書いている．並列 (-j) では動かさない．値の後ろに # で注釈を書かない (空白が値に入る)．

NOTES_MK := $(dir $(lastword $(MAKEFILE_LIST)))
OXQ      ?= $(NOTES_MK)..

EMACS  ?= emacs
QUARTO ?= quarto
PYTHON ?= python3

NOT_NOTES ?=
NOTES     ?= $(basename $(filter-out $(NOT_NOTES),$(wildcard *.org)))
NOTES_ALL ?= pdf
ASSETS    ?= $(wildcard *.bib figs/*)
NOTES_BIB ?=
LIBRARY   ?= $(OXQ)/../biblio/bib/library.bib
PENDING   ?= pending.bib

EXPORT_CMD = $(EMACS) --batch -Q -l $(OXQ)/tools/export-batch.el
ELISP     := $(OXQ)/tools/export-batch.el $(wildcard $(OXQ)/lisp/ox-quarto/*.el $(OXQ)/lisp/ox-quarto-ext/*.el $(OXQ)/_quarto/org/*.org)
THEME     := $(wildcard $(OXQ)/_quarto/yaml/note.yaml $(OXQ)/_quarto/lib/* $(OXQ)/_quarto/tex/* $(OXQ)/_quarto/csl/*)

.PHONY: all pdf html qmd bib links clean help
.PRECIOUS: %.qmd
.DELETE_ON_ERROR:

all: $(NOTES_ALL)
pdf:  $(addsuffix .pdf,$(NOTES))
html: $(addsuffix .html,$(NOTES))
qmd:  $(addsuffix .qmd,$(NOTES))

help:
	@echo "make                ノートをすべて $(NOTES_ALL) に (ノート: $(NOTES))"
	@echo "make pdf / html     ノートをすべて PDF / html に"
	@echo "make <名前>.pdf     1 本だけ (<名前>.html も)"
	@echo "make qmd            org → qmd だけ"
	@echo "make bib            引用している文献を LIBRARY から抜き出して $(if $(NOTES_BIB),$(NOTES_BIB),(NOTES_BIB を書いたとき)) に"
	@echo "make links          _quarto と _extensions のリンクを張る ($(OXQ) を指す)"
	@echo "make clean          生成物を消す (org は消さない)"

%.qmd: %.org $(ELISP)
	$(EXPORT_CMD) $<

%.pdf: %.qmd $(THEME) $(ASSETS)
	$(QUARTO) render $< --to pdf

%.html: %.qmd $(THEME) $(ASSETS)
	$(QUARTO) render $< --to html

# 文献: ノートで引用しているものだけを正本から抜き出す (talk.mk と同じ．正本が無い所では今の refs.bib をそのまま使う)
ifneq ($(NOTES_BIB),)
bib: $(NOTES_BIB)
$(NOTES_BIB): $(addsuffix .org,$(NOTES)) $(wildcard $(PENDING)) $(wildcard $(LIBRARY)) $(OXQ)/tools/oxq-bib.py
	@if [ -f "$(LIBRARY)" ]; then \
	  $(PYTHON) $(OXQ)/tools/oxq-bib.py $(addsuffix .org,$(NOTES)) --library $(LIBRARY) $(if $(wildcard $(PENDING)),--extra $(PENDING)) -o $@; \
	else echo "文献の正本が無い ($(LIBRARY))．$@ はそのまま使う"; fi
else
bib:
	@echo "NOTES_BIB を書いていないので何もしない (例 NOTES_BIB := refs.bib)"
endif

# _quarto と _extensions のリンク (OXQ を指す．既にあれば何もしない)
links:
	@for d in _quarto _extensions; do \
	  if [ -e $$d ]; then echo "$$d はある"; else ln -s $(OXQ)/$$d $$d && echo "$$d -> $(OXQ)/$$d"; fi; \
	done

clean:
	rm -rf $(foreach n,$(NOTES),$(n).qmd $(n).pdf $(n).html $(n).tex $(n).log $(n).aux $(n)_files) .quarto
