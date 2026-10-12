# publish.mk — 講演の生成物を公開用リポジトリ (talks/) に写す共通の部品
#
# 公開側は「主題のフォルダの中に講演の版を並べる」形 (talks/PUBLISHING.md):
#   talks/<主題>/          主題の部分: 解説・デモなど育てていくもの (常に最新)       ← make publish
#   talks/<主題>/<版>/     講演の版: その日のスライド・配布物 (翌日から固定)         ← make publish-edition
#
# 講演の Makefile (例 talk/Makefile) の最後で include する:
#
#   PUB_ID            := physics-informed-ml             # 主題 (英小文字・数字・ハイフン)
#   PUB_FILES         := piml-review.html=report/physics-informed-ml-review.html \
#                        ../demo/clothoid-pinn.html=demo/clothoid-pinn.html
#   PUB_EDITION       := 2026-10-19                      # いま作っている版 (YYYY-MM-DD[-b])
#   PUB_EDITION_FILES := piml.html=talk/physics-informed-ml.html \
#                        piml-handout.pdf=talk/physics-informed-ml-handout.pdf \
#                        ../demo/clothoid-pinn.html=demo/clothoid-pinn.html
#   include $(OXQ)/tools/publish.mk
#
#   *_FILES は「元のパス (この Makefile から)=公開側のパス (主題 / 版のフォルダから)」の並び．
#
# 変えられる変数 (既定):
#   PUB_ROOT   ../../talks           公開用リポジトリ (PUBLISHING.md があること)
#   PUB_META   ../publish/meta.yml   講演の原本の meta.yml (主題の情報と editions．talks/PUBLISHING.md)
#   PUB_FORBID _quarto/local         公開しない画像の置き場 (埋め込まれていないか照合する)
#   PUB_STAGE  _publish              仮置き場 (git の対象外にする)
#   PUB_FIX    (空)                  固定された版を訂正するときの理由 (例 PUB_FIX="図 3 の出典を追記")
#   PUB_HANDOUT_OPTS (空)            ノートなしの配布用 PDF を作るときの oxq-pdf.py の追加の指定
#   UV uv / PYTHON python3
#
# ターゲット:
#   make publish               主題の部分を talks/<主題>/ に写す (版のフォルダには触れない)
#   make publish-edition       版を talks/<主題>/<版>/ に写す (講演の日まで上書きでき，翌日から固定)
#   make publish-all           上の 2 つを続けて (初めての公開と講演の当日に)
#   make publish-diff / publish-edition-diff   調べたうえで変わる所を表示するだけ
#   make publish-check / publish-edition-check 集めて調べるだけ
#   make <名前>-handout.pdf    ノートなしの配布用 PDF (oxq-pdf.py --no-notes)
#   どれも最後に talks/index.html などを作り直す．talks の commit と push は手で．
#   並列 (-j) では動かさない．
#
# 元のファイル (*_FILES の左側) は，講演の Makefile の規則があればそれで作り直される．
# macOS 同梱の make (3.81) で動くように書いている．

PUB_ROOT   ?= ../../talks
PUB_META   ?= ../publish/meta.yml
PUB_FORBID ?= _quarto/local
PUB_STAGE  ?= _publish
PUB_FIX    ?=
UV         ?= uv
PYTHON     ?= python3
PUB_HANDOUT_OPTS ?=

PUB_TOOLS  := $(dir $(lastword $(MAKEFILE_LIST)))
PUB_RUN     = $(UV) run --quiet --script

PUB_T_DIR   = $(PUB_STAGE)/topic/$(PUB_ID)
PUB_T_NOTES = $(PUB_STAGE)/topic/$(PUB_ID).notes.txt
PUB_T_DEST  = $(PUB_ROOT)/$(PUB_ID)
PUB_T_SRCS  = $(foreach p,$(PUB_FILES),$(word 1,$(subst =, ,$(p))))

PUB_E_DIR   = $(PUB_STAGE)/edition/$(PUB_ID)/$(PUB_EDITION)
PUB_E_NOTES = $(PUB_STAGE)/edition/$(PUB_ID)/$(PUB_EDITION).notes.txt
PUB_E_DEST  = $(PUB_ROOT)/$(PUB_ID)/$(PUB_EDITION)
PUB_E_SRCS  = $(foreach p,$(PUB_EDITION_FILES),$(word 1,$(subst =, ,$(p))))

# rsync: 主題の部分では版のフォルダと作られる頁を消さない．版では作られる頁だけを残す
PUB_RSYNC          = rsync -rlpt --checksum --delete --exclude=/index.html
PUB_RSYNC_KEEP_EDS = --exclude='/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*'

# ノートなしの配布用 PDF (公開用)．*_FILES に <名前>-handout.pdf=… と書けば，ここで作る
# (講演の Makefile に同じ名前の規則があればそちらが優先)．並べ方は PUB_HANDOUT_OPTS (例 --per-page 4)
%-handout.pdf: %.qmd %.html $(PUB_TOOLS)oxq-pdf.py $(PUB_TOOLS)notes-handout.py
	$(PYTHON) $(PUB_TOOLS)oxq-pdf.py $*.qmd --html $*.html --no-notes $(PUB_HANDOUT_OPTS) -o $@

.PHONY: publish publish-stage publish-check publish-diff \
        publish-edition publish-edition-stage publish-edition-check publish-edition-diff \
        publish-all publish-guard publish-edition-guard

## 確認 (rsync --delete の前に必ず通す) ------------------------------------
publish-guard:
	@case "$(PUB_ID)" in \
	  ""|*/*|*..*|.*) echo "publish.mk: PUB_ID ('$(PUB_ID)') が空か，/ や .. を含む" >&2; exit 1;; \
	esac
	@echo "$(PUB_ID)" | grep -Eq '^[a-z0-9][a-z0-9-]*$$' || { echo "publish.mk: PUB_ID は英小文字・数字・ハイフンだけ" >&2; exit 1; }
	@test -f "$(PUB_ROOT)/PUBLISHING.md" || { echo "publish.mk: $(PUB_ROOT) に PUBLISHING.md が無い (PUB_ROOT を確かめる)" >&2; exit 1; }
	@test -f "$(PUB_META)" || { echo "publish.mk: $(PUB_META) が無い (書き方は $(PUB_ROOT)/PUBLISHING.md)" >&2; exit 1; }

publish-edition-guard: publish-guard
	@echo "$(PUB_EDITION)" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}(-[a-z])?$$' || { echo "publish.mk: PUB_EDITION ('$(PUB_EDITION)') は YYYY-MM-DD か YYYY-MM-DD-b" >&2; exit 1; }
	@test -n "$(strip $(PUB_EDITION_FILES))" || { echo "publish.mk: PUB_EDITION_FILES が空" >&2; exit 1; }
	@test -f "$(PUB_T_DEST)/meta.yml" || { echo "publish.mk: $(PUB_T_DEST)/ に主題がまだ無い．先に make publish (または make publish-all)" >&2; exit 1; }

## 主題の部分 --------------------------------------------------------------
publish-stage: publish-guard $(PUB_T_SRCS)
	@echo "== 主題 $(PUB_ID): 仮置き場 $(PUB_T_DIR)/"
	@$(PUB_RUN) $(PUB_TOOLS)oxq-publish.py topic --id $(PUB_ID) --meta $(PUB_META) \
	  --out $(PUB_T_DIR) --notes-out $(PUB_T_NOTES) $(PUB_FILES)

publish-check: publish-stage
	@echo "== 検査 ($(PUB_ROOT)/tools/check.py)"
	@$(PUB_RUN) $(PUB_ROOT)/tools/check.py $(PUB_T_DIR) \
	  --forbid-assets $(PUB_FORBID) --notes-snippets $(PUB_T_NOTES)

publish-diff: publish-check
	@echo "== $(PUB_T_DEST)/ との違い (版のフォルダは対象外．何も書いていない)"
	@$(PUB_RSYNC) $(PUB_RSYNC_KEEP_EDS) -n -i $(PUB_T_DIR)/ $(PUB_T_DEST)/

publish: publish-check
	@mkdir -p $(PUB_T_DEST)
	$(PUB_RSYNC) $(PUB_RSYNC_KEEP_EDS) $(PUB_T_DIR)/ $(PUB_T_DEST)/
	@$(PUB_RUN) $(PUB_ROOT)/tools/build-index.py $(PUB_ROOT)
	@echo "== 主題を写した．$(PUB_ROOT) で git diff を見て commit / push"

## 講演の版 ----------------------------------------------------------------
publish-edition-stage: publish-edition-guard $(PUB_E_SRCS)
	@echo "== 版 $(PUB_ID)/$(PUB_EDITION): 仮置き場 $(PUB_E_DIR)/"
	@$(PUB_RUN) $(PUB_TOOLS)oxq-publish.py edition --id $(PUB_ID) --edition $(PUB_EDITION) \
	  --meta $(PUB_META) --out $(PUB_E_DIR) --dest $(PUB_E_DEST) --fix "$(PUB_FIX)" \
	  --notes-out $(PUB_E_NOTES) $(PUB_EDITION_FILES)

publish-edition-check: publish-edition-stage
	@echo "== 検査 ($(PUB_ROOT)/tools/check.py)"
	@$(PUB_RUN) $(PUB_ROOT)/tools/check.py $(PUB_E_DIR) \
	  --forbid-assets $(PUB_FORBID) --notes-snippets $(PUB_E_NOTES)

publish-edition-diff: publish-edition-check
	@echo "== $(PUB_E_DEST)/ との違い (何も書いていない)"
	@if [ -d $(PUB_E_DEST) ]; then $(PUB_RSYNC) -n -i $(PUB_E_DIR)/ $(PUB_E_DEST)/; \
	 else echo "(新しい版．$(PUB_E_DEST)/ を作る)"; fi

publish-edition: publish-edition-check
	@mkdir -p $(PUB_E_DEST)
	$(PUB_RSYNC) $(PUB_E_DIR)/ $(PUB_E_DEST)/
	@$(PUB_RUN) $(PUB_ROOT)/tools/build-index.py $(PUB_ROOT)
	@echo "== 版を写した．$(PUB_ROOT) で git diff を見て commit / push．講演が終わったら git tag $(PUB_ID)/$(PUB_EDITION)"

publish-all: publish publish-edition
