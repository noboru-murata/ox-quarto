# samples/Makefile — org → qmd (ox-quarto) → revealjs / html / pdf (quarto)
#
# 使い方は `make help`．作業は org/ の中で行い，できたものを次に置く．
#   quarto/  書き出した qmd の写し
#   html/    revealjs (と講義の html 版)
#   pdf/     講義の PDF
# qmd は org を，html / pdf は qmd・テーマ (_quarto)・R・図・文献を更新したときだけ作り直す．
# macOS 同梱の make (3.81) で動くように書いている．

EMACS  ?= emacs
QUARTO ?= quarto
OPEN   ?= open

ORG      := org
QMD_DIR  := quarto
HTML_DIR := html
PDF_DIR  := pdf
EXPORT   := ../tools/export-batch.el

TALK     := talk-sample
SLIDE    := slide-sample
DECKS    := $(TALK) $(SLIDE)
PALETTES := jade indigo lavender burgundy dracula logo

# 作り直しの判断に使うファイル
ELISP  := $(EXPORT) $(wildcard ../lisp/ox-quarto/*.el ../lisp/ox-quarto-ext/*.el)
THEME  := $(wildcard ../_quarto/*/* ../_extensions/*/*/*)
ASSETS := $(wildcard $(ORG)/*.R $(ORG)/*.bib $(ORG)/data/* $(ORG)/figs/*)

EXPORT_CMD = $(EMACS) --batch -Q -l $(CURDIR)/$(EXPORT)

QMD          := $(DECKS:%=$(QMD_DIR)/%.qmd)
REVEAL       := $(DECKS:%=$(HTML_DIR)/%.html)
PALETTE_HTML := $(PALETTES:%=$(HTML_DIR)/$(TALK)-%.html)

.PHONY: all help qmd talk slide slide-doc slide-pdf slide-all palettes full \
        open-talk open-slide clean distclean
.DELETE_ON_ERROR:

## 主なターゲット ----------------------------------------------------------

all: qmd talk slide                   ## qmd と revealjs をすべて (既定)

help:                                 ## この一覧
	@echo "make            qmd と revealjs をすべて (= make all)"
	@echo "make qmd        org → qmd だけ (quarto/ に写す)"
	@echo "make talk       講演 $(TALK) の revealjs  → $(HTML_DIR)/$(TALK).html"
	@echo "make slide      講義 $(SLIDE) の revealjs → $(HTML_DIR)/$(SLIDE).html"
	@echo "make slide-doc  講義の html 版           → $(HTML_DIR)/$(SLIDE)-doc.html"
	@echo "make slide-pdf  講義の PDF (lualatex)    → $(PDF_DIR)/$(SLIDE).pdf"
	@echo "make slide-all  講義を revealjs・html・pdf のすべて"
	@echo "make palettes   講演を全 palette で      → $(HTML_DIR)/$(TALK)-<palette>.html"
	@echo "make palette-P  講演を palette P で (P: $(PALETTES))"
	@echo "make full       上のすべて"
	@echo "make open-talk / open-slide   できた revealjs をブラウザで開く"
	@echo "make clean      org/ の中の生成物を消す   make distclean  quarto/ html/ pdf/ も消す"
	@echo "変数: EMACS=$(EMACS) QUARTO=$(QUARTO)  (例: make talk QUARTO=/path/to/quarto)"

qmd: $(QMD)
talk: $(HTML_DIR)/$(TALK).html
slide: $(HTML_DIR)/$(SLIDE).html
slide-doc: $(HTML_DIR)/$(SLIDE)-doc.html
slide-pdf: $(PDF_DIR)/$(SLIDE).pdf
slide-all: slide slide-doc slide-pdf
palettes: $(PALETTE_HTML)
palette-%: $(HTML_DIR)/$(TALK)-%.html ;
full: all slide-doc slide-pdf palettes

open-talk: $(HTML_DIR)/$(TALK).html
	$(OPEN) $<
open-slide: $(HTML_DIR)/$(SLIDE).html
	$(OPEN) $<

## 規則 --------------------------------------------------------------------

$(QMD_DIR) $(HTML_DIR) $(PDF_DIR):
	mkdir -p $@

# org → qmd (org/ の中に作る．render はそこで行う)
$(ORG)/%.qmd: $(ORG)/%.org $(ELISP)
	cd $(ORG) && $(EXPORT_CMD) $*.org

$(QMD): $(QMD_DIR)/%.qmd: $(ORG)/%.qmd | $(QMD_DIR)
	cp $< $@

# revealjs
$(REVEAL): $(HTML_DIR)/%.html: $(ORG)/%.qmd $(THEME) $(ASSETS) | $(HTML_DIR)
	cd $(ORG) && $(QUARTO) render $*.qmd --to revealjs
	mv -f $(ORG)/$*.html $@

# 講義の html 版と PDF (lecture.yaml が持つ形式)
$(HTML_DIR)/$(SLIDE)-doc.html: $(ORG)/$(SLIDE).qmd $(THEME) $(ASSETS) | $(HTML_DIR)
	cd $(ORG) && $(QUARTO) render $(SLIDE).qmd --to html --output $(SLIDE)-doc.html
	mv -f $(ORG)/$(SLIDE)-doc.html $@

$(PDF_DIR)/$(SLIDE).pdf: $(ORG)/$(SLIDE).qmd $(THEME) $(ASSETS) | $(PDF_DIR)
	cd $(ORG) && $(QUARTO) render $(SLIDE).qmd --to pdf
	mv -f $(ORG)/$(SLIDE).pdf $@

# 講演を palette ごとに: SETUPFILE の行だけを入れ替えた一時的な org を作って書き出す
$(PALETTE_HTML): $(HTML_DIR)/$(TALK)-%.html: $(ORG)/$(TALK).org $(ELISP) $(THEME) $(ASSETS) | $(HTML_DIR)
	sed -E -e 's|^(# )?#\+SETUPFILE: _quarto/org/talk-([a-z]+)\.org|# #+SETUPFILE: _quarto/org/talk-\2.org|' \
	       -e 's|^# (#\+SETUPFILE: _quarto/org/talk-$*\.org)|\1|' $< > $(ORG)/$(TALK)-$*.org
	@grep -q '^#+SETUPFILE: _quarto/org/talk-$*\.org' $(ORG)/$(TALK)-$*.org || \
	  { echo "palette '$*' の SETUPFILE の行が $< にない"; rm -f $(ORG)/$(TALK)-$*.org; exit 1; }
	cd $(ORG) && $(EXPORT_CMD) $(TALK)-$*.org && $(QUARTO) render $(TALK)-$*.qmd --to revealjs
	mv -f $(ORG)/$(TALK)-$*.html $@
	rm -rf $(ORG)/$(TALK)-$*.org $(ORG)/$(TALK)-$*.qmd $(ORG)/$(TALK)-$*_files

## 後始末 ------------------------------------------------------------------

clean:
	rm -f  $(ORG)/*.qmd $(ORG)/*.html $(ORG)/*.tex $(ORG)/*.typ $(ORG)/*.pdf $(ORG)/*.log
	rm -f  $(PALETTES:%=$(ORG)/$(TALK)-%.org)
	rm -rf $(ORG)/*_files $(ORG)/.quarto

distclean: clean
	rm -rf $(QMD_DIR) $(HTML_DIR) $(PDF_DIR)
