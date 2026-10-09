# samples/Makefile — org → qmd (ox-quarto) → revealjs / html / pdf (quarto)
#
# 使い方は `make help`．作業は org/ の中で行い，できたものを次に置く．
#   quarto/  書き出した qmd の写し
#   html/    revealjs (と講義の html 版)．iframe-sample が取り込む html は html/iframe/ に写す
#   pdf/     講義と解説文の PDF
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
IFRAME   := iframe-sample
DECKS    := $(TALK) $(SLIDE) $(IFRAME)
REPORT   := report-sample
HANDOUT  := handout-sample
DOCS     := $(REPORT) $(HANDOUT)
PALETTES := jade indigo lavender burgundy dracula logo
LECTURE_PALETTES := indigo jade lavender burgundy dracula

# 作り直しの判断に使うファイル
ELISP  := $(EXPORT) $(wildcard ../lisp/ox-quarto/*.el ../lisp/ox-quarto-ext/*.el)
THEME  := $(wildcard ../_quarto/*/* ../_extensions/*/*/*)
ASSETS := $(wildcard $(ORG)/*.R $(ORG)/*.bib $(ORG)/data/* $(ORG)/figs/*)

EXPORT_CMD = $(EMACS) --batch -Q -l $(CURDIR)/$(EXPORT)

QMD          := $(DECKS:%=$(QMD_DIR)/%.qmd) $(DOCS:%=$(QMD_DIR)/%.qmd)
DOC_PDF      := $(DOCS:%=$(PDF_DIR)/%.pdf)
DOC_HTML     := $(DOCS:%=$(HTML_DIR)/%.html)
REVEAL       := $(DECKS:%=$(HTML_DIR)/%.html)
PALETTE_HTML := $(PALETTES:%=$(HTML_DIR)/$(TALK)-%.html)
SLIDE_PALETTE_HTML := $(LECTURE_PALETTES:%=$(HTML_DIR)/$(SLIDE)-%.html)
# iframe-sample が相対パスで読む html (org/iframe/ → html/iframe/)
IFRAME_PAGES := $(patsubst $(ORG)/%,$(HTML_DIR)/%,$(wildcard $(ORG)/iframe/*.html))

.PHONY: all help qmd talk slide iframe slide-doc slide-pdf slide-all palettes slide-palettes full \
        report report-typst handout handout-typst docs \
        open-talk open-slide open-iframe pin-yaml clean distclean
.DELETE_ON_ERROR:

## 主なターゲット ----------------------------------------------------------

all: qmd talk slide iframe            ## qmd と revealjs をすべて (既定)

help:                                 ## この一覧
	@echo "make            qmd と revealjs をすべて (= make all)"
	@echo "make qmd        org → qmd だけ (quarto/ に写す)"
	@echo "make talk       講演 $(TALK) の revealjs  → $(HTML_DIR)/$(TALK).html"
	@echo "make slide      講義 $(SLIDE) の revealjs → $(HTML_DIR)/$(SLIDE).html"
	@echo "make iframe     iframe の例 $(IFRAME)    → $(HTML_DIR)/$(IFRAME).html (と $(HTML_DIR)/iframe/)"
	@echo "make slide-doc  講義の html 版           → $(HTML_DIR)/$(SLIDE)-doc.html"
	@echo "make slide-pdf  講義の PDF (lualatex)    → $(PDF_DIR)/$(SLIDE).pdf"
	@echo "make slide-all  講義を revealjs・html・pdf のすべて"
	@echo "make palettes   講演を全 palette で      → $(HTML_DIR)/$(TALK)-<palette>.html"
	@echo "make palette-P  講演を palette P で (P: $(PALETTES))"
	@echo "make slide-palettes  講義を全 palette で (revealjs) → $(HTML_DIR)/$(SLIDE)-<palette>.html"
	@echo "make slide-palette-P 講義を palette P で (P: $(LECTURE_PALETTES))"
	@echo "make report     解説文 $(REPORT) を LaTeX の PDF と html で → $(PDF_DIR)/$(REPORT).pdf，$(HTML_DIR)/$(REPORT).html"
	@echo "make report-typst   同じ解説文を typst の PDF で → $(PDF_DIR)/$(REPORT)-typst.pdf"
	@echo "make handout    Tufte 形式 $(HANDOUT) を LaTeX の PDF と html で → $(PDF_DIR)/$(HANDOUT).pdf，$(HTML_DIR)/$(HANDOUT).html"
	@echo "make handout-typst  同じものを typst の PDF で → $(PDF_DIR)/$(HANDOUT)-typst.pdf"
	@echo "make docs       report・report-typst・handout・handout-typst のすべて"
	@echo "make full       上のすべて"
	@echo "make open-talk / open-slide / open-iframe   できた revealjs をブラウザで開く"
	@echo "make pin-yaml  talk-*.yaml を直したあと，見出し固定版 talk-*-pin.yaml を作り直す"
	@echo "make clean      org/ の中の生成物を消す   make distclean  quarto/ html/ pdf/ も消す"
	@echo "変数: EMACS=$(EMACS) QUARTO=$(QUARTO)  (例: make talk QUARTO=/path/to/quarto)"

qmd: $(QMD)
talk: $(HTML_DIR)/$(TALK).html
slide: $(HTML_DIR)/$(SLIDE).html
iframe: $(HTML_DIR)/$(IFRAME).html $(IFRAME_PAGES)
slide-doc: $(HTML_DIR)/$(SLIDE)-doc.html
slide-pdf: $(PDF_DIR)/$(SLIDE).pdf
slide-all: slide slide-doc slide-pdf
palettes: $(PALETTE_HTML)
palette-%: $(HTML_DIR)/$(TALK)-%.html ;
slide-palettes: $(SLIDE_PALETTE_HTML)
slide-palette-%: $(HTML_DIR)/$(SLIDE)-%.html ;
report: $(PDF_DIR)/$(REPORT).pdf $(HTML_DIR)/$(REPORT).html
report-typst: $(PDF_DIR)/$(REPORT)-typst.pdf
handout: $(PDF_DIR)/$(HANDOUT).pdf $(HTML_DIR)/$(HANDOUT).html
handout-typst: $(PDF_DIR)/$(HANDOUT)-typst.pdf
docs: report report-typst handout handout-typst
full: all slide-doc slide-pdf palettes slide-palettes docs

# talk-*.yaml から見出し固定版 talk-*-pin.yaml を作り直す (#+QUARTO_VARIANT: pin で読まれる)
pin-yaml:
	cd .. && python3 tools/mkpin.py .

open-talk: $(HTML_DIR)/$(TALK).html
	$(OPEN) $<
open-slide: $(HTML_DIR)/$(SLIDE).html
	$(OPEN) $<
open-iframe: iframe
	$(OPEN) $(HTML_DIR)/$(IFRAME).html

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

# iframe-sample が取り込む html を写す (書き出した html から相対パスで読むため)
$(IFRAME_PAGES): $(HTML_DIR)/iframe/%.html: $(ORG)/iframe/%.html
	@mkdir -p $(@D)
	cp $< $@

# 解説文 (report-sample) と Tufte 形式 (handout-sample) の PDF (LaTeX) と html
$(DOC_PDF): $(PDF_DIR)/%.pdf: $(ORG)/%.qmd $(THEME) $(ASSETS) | $(PDF_DIR)
	cd $(ORG) && $(QUARTO) render $*.qmd --to pdf
	mv -f $(ORG)/$*.pdf $@

$(DOC_HTML): $(HTML_DIR)/%.html: $(ORG)/%.qmd $(THEME) $(ASSETS) | $(HTML_DIR)
	cd $(ORG) && $(QUARTO) render $*.qmd --to html
	mv -f $(ORG)/$*.html $@

# typst の PDF: SETUPFILE の <kind>(-latex).org を <kind>-typst.org に入れ替えた一時的な org で書き出す
# (report-sample は report，handout-sample は handout)
TYPST_PDF := $(PDF_DIR)/$(REPORT)-typst.pdf $(PDF_DIR)/$(HANDOUT)-typst.pdf
$(TYPST_PDF): $(PDF_DIR)/%-sample-typst.pdf: $(ORG)/%-sample.org $(ELISP) $(THEME) $(ASSETS) | $(PDF_DIR)
	sed -E 's|^#\+SETUPFILE: _quarto/org/$*(-[a-z]+)?\.org|#+SETUPFILE: _quarto/org/$*-typst.org|' $< > $(ORG)/$*-sample-typst.org
	@grep -q '^#+SETUPFILE: _quarto/org/$*-typst\.org' $(ORG)/$*-sample-typst.org || \
	  { echo "$< に $* の SETUPFILE の行がない"; rm -f $(ORG)/$*-sample-typst.org; exit 1; }
	cd $(ORG) && $(EXPORT_CMD) $*-sample-typst.org && $(QUARTO) render $*-sample-typst.qmd --to typst
	mv -f $(ORG)/$*-sample-typst.pdf $@
	rm -rf $(ORG)/$*-sample-typst.org $(ORG)/$*-sample-typst.qmd $(ORG)/$*-sample-typst_files

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

# 講義を palette ごとに (revealjs だけ．pdf と html は配色によらない):
# SETUPFILE の lecture(-<palette>).org を lecture-<palette>.org に入れ替えた一時的な org で書き出す
$(SLIDE_PALETTE_HTML): $(HTML_DIR)/$(SLIDE)-%.html: $(ORG)/$(SLIDE).org $(ELISP) $(THEME) $(ASSETS) | $(HTML_DIR)
	@test -f ../_quarto/org/lecture-$*.org || { echo "palette '$*' の _quarto/org/lecture-$*.org がない"; exit 1; }
	sed -E 's|^#\+SETUPFILE: _quarto/org/lecture(-[a-z]+)?\.org|#+SETUPFILE: _quarto/org/lecture-$*.org|' $< > $(ORG)/$(SLIDE)-$*.org
	@grep -q '^#+SETUPFILE: _quarto/org/lecture-$*\.org' $(ORG)/$(SLIDE)-$*.org || \
	  { echo "$< に lecture の SETUPFILE の行がない"; rm -f $(ORG)/$(SLIDE)-$*.org; exit 1; }
	cd $(ORG) && $(EXPORT_CMD) $(SLIDE)-$*.org && $(QUARTO) render $(SLIDE)-$*.qmd --to revealjs
	mv -f $(ORG)/$(SLIDE)-$*.html $@
	rm -rf $(ORG)/$(SLIDE)-$*.org $(ORG)/$(SLIDE)-$*.qmd $(ORG)/$(SLIDE)-$*_files

## 後始末 ------------------------------------------------------------------

clean:
	rm -f  $(ORG)/*.qmd $(ORG)/*.html $(ORG)/*.tex $(ORG)/*.typ $(ORG)/*.pdf $(ORG)/*.log
	rm -f  $(PALETTES:%=$(ORG)/$(TALK)-%.org) $(LECTURE_PALETTES:%=$(ORG)/$(SLIDE)-%.org) $(ORG)/$(REPORT)-typst.org $(ORG)/$(HANDOUT)-typst.org
	rm -rf $(ORG)/*_files $(ORG)/.quarto

distclean: clean
	rm -rf $(QMD_DIR) $(HTML_DIR) $(PDF_DIR)
