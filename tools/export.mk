# export.mk — org → qmd の共通の部品 (talk.mk と notes.mk が頭で読む．2026-11-18)
#
# 置くのは変数と型の規則 (%.qmd) だけ．普通の目標 (bib など) は書かない
# (読む側の既定の目標を変えないため．notes.mk は .DEFAULT_GOAL を決めていない)．
#
# 読み方 (読む側の mk の頭で):
#   XXX_MK := $(dir $(lastword $(MAKEFILE_LIST)))     ← 自分の場所は include の前に := で取る
#   OXQ    ?= $(XXX_MK)..                              (include で MAKEFILE_LIST の最後が変わる)
#   include $(XXX_MK)export.mk
#
# 決めるもの (既定):
#   OXQ      この mk の ..                     ox-quarto
#   EMACS emacs / QUARTO quarto / PYTHON python3
#   LIBRARY  $(OXQ)/../biblio/bib/library.bib   文献の正本 (読むだけ)
#   EXPORT_CMD   org → qmd のコマンド (tools/export-batch.el)
#   ELISP        qmd が依存する lisp と SETUPFILE の org (直せば書き出し直す)
#   OXQ_BIB_CMD / OXQ_BIB_OPTS   文献の抜き出し: $(OXQ_BIB_CMD) <org …> $(OXQ_BIB_OPTS) -o <bib>
#                (OXQ_BIB_OPTS は = で遅れて展開．PENDING は読む側で決める: talk.mk は ../research/pending.bib，notes.mk は pending.bib)
# 二重に読まれても 1 度だけ効く (同じ Makefile が talk.mk と notes.mk を読むこともある)．
# macOS 同梱の make (3.81) で動くように書いている．

ifndef OXQ_EXPORT_MK
OXQ_EXPORT_MK := $(lastword $(MAKEFILE_LIST))

OXQ     ?= $(dir $(OXQ_EXPORT_MK))..
EMACS   ?= emacs
QUARTO  ?= quarto
PYTHON  ?= python3
LIBRARY ?= $(OXQ)/../biblio/bib/library.bib

EXPORT_CMD = $(EMACS) --batch -Q -l $(OXQ)/tools/export-batch.el
ELISP     := $(OXQ)/tools/export-batch.el $(wildcard $(OXQ)/lisp/ox-quarto/*.el $(OXQ)/lisp/ox-quarto-ext/*.el $(OXQ)/_quarto/org/*.org)

OXQ_BIB_CMD   = $(PYTHON) $(OXQ)/tools/oxq-bib.py
OXQ_BIB_OPTS  = --library $(LIBRARY) $(if $(wildcard $(PENDING)),--extra $(PENDING))

# org → qmd
%.qmd: %.org $(ELISP)
	$(EXPORT_CMD) $<
endif
