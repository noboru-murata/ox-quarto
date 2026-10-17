# samples/publish/talk/Makefile — publish.mk を試すための作り物の講演 (../README.md)
#
# 講演のリポジトリと同じ並び (talk/，demo/，publish/meta.yml) にしてある．
# 公開側は本物の talks ではなく，その写し (../_talks/．make sandbox で作る) を使う．
#
#   make sandbox                                  本物の talks から PUBLISHING.md・tools/ などを写して ../_talks/ を作る
#   OXQ_PUBLISH_TODAY=2030-01-10 make publish-all 主題と版 (2030-01-15) を ../_talks/ に写す
#   make slide-handout                            配布用 PDF (slide-handout.pdf．ここでは mkpdf.py で作る．talk-handout も同じ)
#   make test                                     いろいろな場面を作業用の写しで自動で試す (../test.sh)
#
# 版の日付はわざと先 (2030 年) にしてある．固定の動きは OXQ_PUBLISH_TODAY で「今日」を変えて試す．
# macOS 同梱の make (3.81) で動くように書いている．

OXQ      ?= ../../..
TALKS    ?= ../../../../talks
PUB_ROOT ?= ../_talks
PYTHON   ?= python3

PUB_ID            := publish-sample
PUB_FILES         := companion.html=report/sample-report.html \
                     companion.pdf=report/sample-report.pdf \
                     ../demo/sample-demo.html=demo/sample-demo.html
PUB_EDITION       := 2030-01-15
PUB_EDITION_FILES := slide.html=talk/publish-sample.html \
                     slide-handout.pdf=talk/publish-sample-handout.pdf \
                     ../demo/sample-demo.html=demo/sample-demo.html
include $(OXQ)/tools/publish.mk

# PDF は quarto を使わずに mkpdf.py で作る (publish.mk の %-handout.pdf より，こちらが優先)
slide-handout.pdf: slide.html ../mkpdf.py
	$(PYTHON) ../mkpdf.py $< -o $@
companion.pdf: companion.html ../mkpdf.py
	$(PYTHON) ../mkpdf.py --notes $< -o $@

.PHONY: sandbox sample-guard test clean
# 本物の talks に作り物を写さないよう，公開側に make sandbox の印 (.sandbox) があることを確かめる
publish-guard: sample-guard
sample-guard:
	@test -f "$(PUB_ROOT)/.sandbox" || { echo "samples/publish: $(PUB_ROOT) は make sandbox で作った写しではない (本物の talks には写さない)" >&2; exit 1; }

sandbox:
	@test -f "$(TALKS)/PUBLISHING.md" || { echo "samples/publish: $(TALKS) に PUBLISHING.md が無い (TALKS=… で本物の talks を指す)" >&2; exit 1; }
	@if [ -d "$(PUB_ROOT)" ] && [ ! -f "$(PUB_ROOT)/.sandbox" ]; then echo "samples/publish: $(PUB_ROOT) は写しではないので消さない" >&2; exit 1; fi
	rm -rf $(PUB_ROOT)
	mkdir -p $(PUB_ROOT)
	cp -R $(TALKS)/PUBLISHING.md $(TALKS)/site.yml $(TALKS)/Makefile $(TALKS)/.nojekyll $(TALKS)/tools $(PUB_ROOT)/
	rm -rf $(PUB_ROOT)/tools/__pycache__
	@echo "試験用の写し (samples/publish の make sandbox)．消してよい．" > $(PUB_ROOT)/.sandbox
	@cd $(PUB_ROOT) && $(UV) run --quiet --script tools/build-index.py .
	@echo "== $(PUB_ROOT) を作った (本物の talks の tools/ と PUBLISHING.md の写し)"

test:
	sh ../test.sh

clean:
	rm -rf $(PUB_STAGE) ../_talks _work _quarto slide-handout.pdf companion.pdf
