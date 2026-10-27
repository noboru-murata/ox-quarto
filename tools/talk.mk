# talk.mk — 講演の talk/Makefile の共通の部品 (org → qmd → revealjs / PDF，解説文，文献，議論用のスナップショット)
#
# 講演の型 (_meta/handoff-talks.md) の名前: slide.org → slide.html，companion.org → companion.html / .pdf．
# 講演の talk/Makefile は変数を数行書いて include するだけにする (雛形は samples/talk/Makefile)．
# talk.mk は最後に publish.mk も読む (公開と議論用の写しの drafts)．
#
#   OXQ    ?= ../../../ox-quarto
#   PUB_ID := my-topic
#   include $(OXQ)/tools/talk.mk
#
# ターゲット (make help でも出る):
#   make                  slide と companion (TALK_ALL で変えられる)
#   make slide            スライド (revealjs)                      → slide.html
#   make slide-notes      スライドとノートを並べた PDF (手元用)      → slide-notes.pdf
#   make slide-handout    配布用 PDF (ノートなし．publish.mk の規則)  → slide-handout.pdf
#   make companion        解説文を LaTeX の PDF と html で            → companion.pdf，companion.html
#   make alts             比較用の別案のスライド (ALTS)．別案のノート付きは make <名前>-notes.pdf
#   make qmd / bib        org → qmd だけ / refs.bib を LIBRARY から作り直す (oxq-bib.py)
#   make snapshot         議論用のスナップショット (軽い版: SNAP_LIGHT) を ../snapshots/<SNAP>/ に (oxq-snapshot.sh)
#   make snapshot-full    同じく重い版 (SNAP_FULL: PDF も)
#   make open-slide / open-notes / open-handout / open-companion   できたものを開く
#   make clean            生成物を消す
#   (公開は publish.mk: make publish / publish-edition / publish-all / publish-qr / publish-draft …)
#   (前からの名前 talk / talk-notes / talk-handout も同じものを作る)
#
# 変えられる変数 (既定):
#   TALK     slide           スライドの org の名前
#   REPORT   companion       解説文の org の名前 (空にすると解説文を扱わない．companion.org がまだ無いときなど)
#   TALK_ALL slide companion make だけで作るもの (REPORT が空なら slide)
#   ALTS     (空)            比較用の別案のスライドの名前 (例 slide-space slide-history)
#   TALK_DEPS ../demo/*.html スライドが読むもの (iframe のデモなど)．変わると slide.html を作り直す
#   ASSETS   *.R refs.bib figs/* ../data/*   スライドと解説文の両方が使うもの
#   BIB_ORGS (TALK と REPORT と ALTS の org)  引用を拾う org (長い版の解説文などを足す)
#   LIBRARY  $(OXQ)/../biblio/bib/library.bib   文献の正本 (読むだけ．無ければ refs.bib はそのまま使う)
#   PENDING  ../research/pending.bib  登録待ちの文献 (あれば oxq-bib.py --extra で読む)
#   SNAP     (今日)          スナップショットの名前 YYYY-MM-DD[-b]
#   SNAP_LIGHT / SNAP_FULL   スナップショットに入れるもの
#   EMACS emacs / QUARTO quarto / PYTHON python3 / OPEN open
#
# 講演に固有の規則 (文献ガイドなど) は include の後に書けばよい (既定のターゲットは all のまま)．
# macOS 同梱の make (3.81) で動くように書いている．並列 (-j) では動かさない．

TALK_MK := $(dir $(lastword $(MAKEFILE_LIST)))
OXQ     ?= $(TALK_MK)..

EMACS  ?= emacs
QUARTO ?= quarto
PYTHON ?= python3
OPEN   ?= open

TALK      ?= slide
REPORT    ?= companion
ALTS      ?=
TALK_ALL  ?= slide $(if $(REPORT),companion)
TALK_DEPS ?= $(wildcard ../demo/*.html)
ASSETS    ?= $(wildcard *.R refs.bib figs/* ../data/*)
BIB_ORGS  ?= $(TALK).org $(if $(REPORT),$(REPORT).org) $(addsuffix .org,$(ALTS))
LIBRARY   ?= $(OXQ)/../biblio/bib/library.bib
PENDING   ?= ../research/pending.bib

EXPORT_CMD = $(EMACS) --batch -Q -l $(OXQ)/tools/export-batch.el
ELISP     := $(OXQ)/tools/export-batch.el $(wildcard $(OXQ)/lisp/ox-quarto/*.el $(OXQ)/lisp/ox-quarto-ext/*.el $(OXQ)/_quarto/org/*.org)
THEME     := $(wildcard $(OXQ)/_quarto/*/* $(OXQ)/_extensions/*/*/*)
PDF_TOOLS := $(OXQ)/tools/oxq-pdf.py $(OXQ)/tools/notes-handout.py $(wildcard $(OXQ)/_quarto/lib/slide-notes.lua)
DECKS     := $(TALK) $(ALTS)

.PHONY: all help qmd slide slide-notes companion alts bib talk talk-notes \
        open-slide open-notes open-handout open-companion snapshot snapshot-full clean
.DELETE_ON_ERROR:
.DEFAULT_GOAL := all

## 主なターゲット ----------------------------------------------------------

all: $(TALK_ALL)

help:
	@echo "make                $(TALK_ALL)"
	@echo "make slide          スライド (revealjs)                    → $(TALK).html"
	@echo "make slide-notes    スライドとノートを並べた PDF (手元用)    → $(TALK)-notes.pdf"
	@echo "make slide-handout  配布用 PDF (ノートなし)                 → $(TALK)-handout.pdf"
	@$(if $(REPORT),echo "make companion      解説文を LaTeX の PDF と html で       → $(REPORT).pdf，$(REPORT).html")
	@$(if $(ALTS),echo "make alts           比較用の別案 ($(ALTS))．ノート付きは make <名前>-notes.pdf")
	@echo "make qmd            org → qmd だけ"
	@echo "make bib            refs.bib を作り直す (引用している文献だけ．$(LIBRARY))"
	@echo "make snapshot       議論用のスナップショット (軽い版) → ../snapshots/$(SNAP)/  (重い版は snapshot-full．名前は SNAP=…)"
	@echo "make open-slide / open-notes / open-handout / open-companion   できたものを開く"
	@echo "make clean          生成物を消す"
	@echo "make publish-qr     版の頁の QR コード ($(PUB_QR))"
	@echo "make publish / publish-edition / publish-all   talks への公開 (主題 $(PUB_ID)．版 $(PUB_EDITION))．talks の commit / push は手で"
	@echo "make publish-draft DRAFT=<名前>   議論用の写しを暗号化して drafts に (合言葉は make draft-pass)"
	@echo "変数: EMACS=$(EMACS) QUARTO=$(QUARTO) OXQ=$(OXQ)"

qmd: $(addsuffix .qmd,$(DECKS)) $(if $(REPORT),$(REPORT).qmd)
slide talk: $(TALK).html
slide-notes talk-notes: $(TALK)-notes.pdf
# slide-handout (と talk-handout) は publish.mk が配布用 PDF の名前から作る (規則 %-handout.pdf も publish.mk)
alts: $(addsuffix .html,$(ALTS))
ifneq ($(strip $(REPORT)),)
companion: $(REPORT).pdf $(REPORT).html
else
companion:
	@echo "talk.mk: REPORT が空なので解説文は作らない" >&2; exit 1
endif

open-slide: $(TALK).html
	$(OPEN) $<
open-notes: $(TALK)-notes.pdf
	$(OPEN) $<
open-handout: $(TALK)-handout.pdf
	$(OPEN) $<
open-companion: $(REPORT).pdf
	$(OPEN) $<

## 規則 --------------------------------------------------------------------

# 文献: org で引いている文献だけを LIBRARY から抜き出す (中身が同じなら書かない)．
# LIBRARY が無い所 (biblio を置いていない Mac など) では，git に入れた refs.bib をそのまま使う
ifneq ($(wildcard $(LIBRARY)),)
bib: refs.bib
refs.bib: $(BIB_ORGS) $(wildcard $(PENDING)) $(LIBRARY) $(OXQ)/tools/oxq-bib.py
	$(PYTHON) $(OXQ)/tools/oxq-bib.py $(BIB_ORGS) --library $(LIBRARY) $(if $(wildcard $(PENDING)),--extra $(PENDING)) -o $@
else
bib:
	@echo "talk.mk: $(LIBRARY) が無いので refs.bib は作り直さない (LIBRARY=… で指す)" >&2; exit 1
endif

# org → qmd
%.qmd: %.org $(ELISP)
	$(EXPORT_CMD) $<

# スライド (revealjs) と別案
$(addsuffix .html,$(DECKS)): %.html: %.qmd $(THEME) $(ASSETS) $(TALK_DEPS)
	$(QUARTO) render $< --to revealjs

# スライドとノートを並べた PDF (ox-quarto の tools/oxq-pdf.py．並べ方は org の #+QUARTO_OPTIONS: notes-pdf-*)
# 前提: uv と Chromium (一度だけ: uv run --with playwright playwright install chromium)
$(addsuffix -notes.pdf,$(DECKS)): %-notes.pdf: %.qmd %.html $(PDF_TOOLS)
	$(PYTHON) $(OXQ)/tools/oxq-pdf.py $*.qmd --html $*.html -o $@

# 解説文 (LaTeX の PDF と html)
ifneq ($(strip $(REPORT)),)
$(REPORT).pdf: $(REPORT).qmd $(THEME) $(ASSETS)
	$(QUARTO) render $< --to pdf
$(REPORT).html: $(REPORT).qmd $(THEME) $(ASSETS)
	$(QUARTO) render $< --to html
endif

## 議論用のスナップショット (talks には出さない．_meta/handoff-talks.md) -------
# 足りないものは make が作る．Web で見せるときは続けて make publish-draft DRAFT=<名前> (publish.mk)
SNAP       ?= $(shell date +%Y-%m-%d)
SNAP_LIGHT ?= $(TALK).html $(if $(REPORT),$(REPORT).html)
SNAP_FULL  ?= $(TALK).html $(TALK)-notes.pdf $(TALK)-handout.pdf $(if $(REPORT),$(REPORT).html $(REPORT).pdf)
snapshot: $(SNAP_LIGHT)
	OXQ=$(OXQ) SNAP_KIND=light sh $(OXQ)/tools/oxq-snapshot.sh $(SNAP) $(SNAP_LIGHT)
snapshot-full: $(SNAP_FULL)
	OXQ=$(OXQ) SNAP_KIND=full sh $(OXQ)/tools/oxq-snapshot.sh $(SNAP) $(SNAP_FULL)

## 後始末 ------------------------------------------------------------------

TALK_CLEAN = $(foreach d,$(DECKS),$(d).qmd $(d).html $(d)-notes.pdf $(d)-handout.pdf) \
             $(if $(REPORT),$(REPORT).qmd $(REPORT).html $(REPORT).pdf $(REPORT).tex)
clean:
	rm -f  $(TALK_CLEAN) Rplots.pdf
	rm -rf $(foreach d,$(DECKS) $(REPORT),$(d)_files) .quarto _publish

## 公開 (talks / drafts) ----------------------------------------------------
include $(TALK_MK)publish.mk
