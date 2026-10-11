# publish.mk — 講演の生成物を公開用リポジトリ (talks/) に写す共通の部品
#
# 講演の Makefile (例 talk/Makefile) の最後で include する:
#
#   PUB_ID    := piml                                    # 公開側のフォルダ名 (英小文字・数字・ハイフン)
#   PUB_FILES := piml.html=talk/piml.html \              # 「元のパス=公開側のパス」の並び
#                piml-handout.pdf=talk/piml-handout.pdf \
#                piml-review.html=report/piml-review.html \
#                ../demo/clothoid-pinn.html=demo/clothoid-pinn.html
#   include $(OXQ)/tools/publish.mk
#
# 変えられる変数 (既定):
#   PUB_ROOT   ../../talks           公開用リポジトリ (PUBLISHING.md があること)
#   PUB_META   ../publish/meta.yml   講演の原本の meta.yml (書き方は talks/PUBLISHING.md)
#   PUB_FORBID _quarto/local         公開しない画像の置き場 (埋め込まれていないか照合する)
#   PUB_STAGE  _publish              仮置き場 (git の対象外にする)
#   UV         uv
#   PUB_HANDOUT_OPTS     ノートなしの配布用 PDF (<名前>-handout.pdf) を作るときの oxq-pdf.py の追加の指定
#
# ターゲット:
#   make publish-stage   仮置き場 _publish/<id>/ に公開する形で集める (ノートは既定で取り除く)
#   make publish-check   集めたものを talks/tools/check.py で調べる
#   make publish-diff    調べたうえで，talks/<id>/ がどう変わるかを表示するだけ (何も書かない)
#   make publish         調べたうえで talks/<id>/ に写し，talks/index.html を作り直す
#                        (talks の commit と push は手で)
#
# 元のファイル (PUB_FILES の左側) は，講演の Makefile の規則があればそれで作り直される．
# macOS 同梱の make (3.81) で動くように書いている．

PUB_ROOT   ?= ../../talks
PUB_META   ?= ../publish/meta.yml
PUB_FORBID ?= _quarto/local
PUB_STAGE  ?= _publish
UV         ?= uv

PUB_TOOLS  := $(dir $(lastword $(MAKEFILE_LIST)))
PUB_DIR     = $(PUB_STAGE)/$(PUB_ID)
PUB_DEST    = $(PUB_ROOT)/$(PUB_ID)
PUB_NOTES   = $(PUB_STAGE)/$(PUB_ID).notes.txt
PUB_SRCS    = $(foreach p,$(PUB_FILES),$(word 1,$(subst =, ,$(p))))

# ノートなしの配布用 PDF (公開用)．PUB_FILES に <名前>-handout.pdf=… と書けば，ここで作る
# (講演の Makefile に同じ名前の規則があればそちらが優先)．並べ方は PUB_HANDOUT_OPTS (例 --per-page 4)
PYTHON           ?= python3
PUB_HANDOUT_OPTS ?=
%-handout.pdf: %.qmd %.html $(PUB_TOOLS)oxq-pdf.py $(PUB_TOOLS)notes-handout.py
	$(PYTHON) $(PUB_TOOLS)oxq-pdf.py $*.qmd --html $*.html --no-notes $(PUB_HANDOUT_OPTS) -o $@

.PHONY: publish publish-stage publish-check publish-diff publish-guard

# 写し先を取り違えないための確認 (rsync --delete の前に必ず通す)
publish-guard:
	@case "$(PUB_ID)" in \
	  ""|*/*|*..*|.*) echo "publish.mk: PUB_ID ('$(PUB_ID)') が空か，/ や .. を含む" >&2; exit 1;; \
	esac
	@echo "$(PUB_ID)" | grep -Eq '^[a-z0-9][a-z0-9-]*$$' || { echo "publish.mk: PUB_ID は英小文字・数字・ハイフンだけ" >&2; exit 1; }
	@test -n "$(strip $(PUB_FILES))" || { echo "publish.mk: PUB_FILES が空" >&2; exit 1; }
	@test -f "$(PUB_ROOT)/PUBLISHING.md" || { echo "publish.mk: $(PUB_ROOT) に PUBLISHING.md が無い (PUB_ROOT を確かめる)" >&2; exit 1; }
	@test -f "$(PUB_META)" || { echo "publish.mk: $(PUB_META) が無い (書き方は $(PUB_ROOT)/PUBLISHING.md)" >&2; exit 1; }

publish-stage: publish-guard $(PUB_SRCS)
	@echo "== 仮置き場 $(PUB_DIR)/"
	@$(UV) run --quiet --script $(PUB_TOOLS)oxq-publish.py stage --id $(PUB_ID) --meta $(PUB_META) \
	  --out $(PUB_DIR) --notes-out $(PUB_NOTES) $(PUB_FILES)

publish-check: publish-stage
	@echo "== 検査 ($(PUB_ROOT)/tools/check.py)"
	@$(UV) run --quiet --script $(PUB_ROOT)/tools/check.py $(PUB_DIR) \
	  --forbid-assets $(PUB_FORBID) --notes-snippets $(PUB_NOTES)

publish-diff: publish-check
	@echo "== $(PUB_DEST)/ との違い (何も書いていない)"
	@rsync -rlpt -n --delete --checksum -i $(PUB_DIR)/ $(PUB_DEST)/

publish: publish-check
	@mkdir -p $(PUB_DEST)
	rsync -rlpt --delete --checksum $(PUB_DIR)/ $(PUB_DEST)/
	@$(UV) run --quiet --script $(PUB_ROOT)/tools/build-index.py $(PUB_ROOT)
	@echo "== 写した．次は $(PUB_ROOT) で git diff を見て commit / push (タグの例: git tag $(PUB_ID)-YYYY-MM-DD)"
