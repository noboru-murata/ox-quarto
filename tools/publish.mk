# publish.mk — 講演の生成物を公開用リポジトリ (talks/) に写す共通の部品
#
# 公開側は「主題のフォルダの中に講演の版を並べる」形 (talks/PUBLISHING.md):
#   talks/<主題>/          主題の部分: 解説・デモなど育てていくもの (常に最新)       ← make publish
#   talks/<主題>/<版>/     講演の版: その日のスライド・配布物 (翌日から固定)         ← make publish-edition
#
# 講演の Makefile (例 talk/Makefile) の最後で include する (ふつうは tools/talk.mk が読む．雛形は samples/talk/Makefile):
#
#   PUB_ID            := my-topic                        # 主題 (英小文字・数字・ハイフン)
#   PUB_FILES         := review.html=report/my-topic-review.html \
#                        ../demo/demo.html=demo/demo.html
#   PUB_EDITION       := 2030-01-15                      # いま作っている版 (YYYY-MM-DD[-b])
#   PUB_EDITION_FILES := slide.html=talk/my-topic.html \
#                        slide-handout.pdf=talk/my-topic-handout.pdf \
#                        ../demo/demo.html=demo/demo.html
#   include $(OXQ)/tools/publish.mk
#
#   *_FILES は「元のパス (この Makefile から)=公開側のパス (主題 / 版のフォルダから)」の並び．
#
# 変えられる変数 (既定):
#   PUB_ROOT   (publish.mk の 2 段上の talks)  公開用リポジトリ (PUBLISHING.md があること)．ox-quarto と talks が同じ階層なら
#              講演のフォルダの深さによらず決まる (~/Desktop/claude/talk_materials/<講演>/talk/ からは ../../../talks)
#   PUB_META   ../publish/meta.yml   講演の原本の meta.yml (主題の情報と editions．talks/PUBLISHING.md)
#   PUB_FORBID _quarto/local         公開しない画像の置き場 (埋め込まれていないか照合する)
#   PUB_STAGE  _publish              仮置き場 (git の対象外にする)
#   PUB_FIX    (空)                  固定された版を訂正するときの理由 (例 PUB_FIX="図 3 の出典を追記")
#   PUB_HANDOUT_OPTS (空)            ノートなしの配布用 PDF を作るときの oxq-pdf.py の追加の指定
#                                    (例 --grid 4x2 や --per-page 4．org の #+QUARTO_OPTIONS: handout-grid:4x2 より優先)
#   PUB_URL_BASE https://noboru-murata.github.io/talks   公開の URL の根 (talks/PUBLISHING.md の「URL の約束」)
#   PUB_QR     figs/qr-edition.svg  make publish-qr が書く版の頁の QR コード (.svg か .png)
#   PUB_HANDOUT (PUB_EDITION_FILES の左側の *-handout.pdf．無ければ $(TALK)-handout.pdf)  短い名前で作る配布用 PDF
#   DRAFT_ROOT (publish.mk の 2 段上の drafts)  議論用の写しの置き場 (talks と別のリポジトリ．頁は公開されるので中身はすべて暗号化)
#   DRAFT_ID   (PUB_ID)              drafts の中の講演の名前 (URL に出る．題を明かしたくなければ別の名前に)
#   DRAFT_SRC  ../snapshots          写しの並ぶフォルダ (講演の make snapshot が作る <名前>/talk/, demo/ …)
#   DRAFT_PASS ~/.config/oxq/drafts/<DRAFT_ID>.pass   合言葉のファイル (リポジトリにも原本にも置かない)
#   UV uv / PYTHON python3
#
# ターゲット:
#   make publish               主題の部分を talks/<主題>/ に写す (版のフォルダには触れない)
#   make publish-edition       版を talks/<主題>/<版>/ に写す (講演の日まで上書きでき，翌日から固定)
#   make publish-all           上の 2 つを続けて (初めての公開と講演の当日に)
#   make publish-diff / publish-edition-diff   調べたうえで変わる所を表示するだけ
#   make publish-check / publish-edition-check 集めて調べるだけ
#   make <名前>-handout.pdf    ノートなしの配布用 PDF (oxq-pdf.py --no-notes)
#   make slide-handout         同じものを短い名前で．名前は PUB_HANDOUT の basename (slide-handout.pdf なら slide-handout)
#   make talk-handout          同じ (前からの名前．PUB_HANDOUT の名前によらない)
#   make publish-qr            版の頁の URL の QR コードを PUB_QR に作る (表紙の #+QUARTO_QR 用．公開の前に使える)
#   make publish-draft DRAFT=<名前>  議論用 (非公開) の写し DRAFT_SRC/<名前>/ を合言葉で暗号化して drafts/<DRAFT_ID>/<名前>/ に置く
#                              (oxq-draft.py．talks には触れない．drafts の commit と push は手で)
#   make draft-pass            講演の合言葉のファイル DRAFT_PASS を作って表示する (初めの一度．既にあれば表示だけ)
#   どれも最後に talks/index.html などを作り直す．talks の commit と push は手で．
#   並列 (-j) では動かさない．
#
# 元のファイル (*_FILES の左側) は，講演の Makefile の規則があればそれで作り直される．
# macOS 同梱の make (3.81) で動くように書いている．

PUB_TOOLS  := $(dir $(lastword $(MAKEFILE_LIST)))
# ox-quarto/tools/publish.mk の 2 段上 = ox-quarto と同じ階層の talks (講演のフォルダの深さによらない．2026-10-17)
PUB_ROOT   ?= $(PUB_TOOLS)../../talks
PUB_META   ?= ../publish/meta.yml
PUB_FORBID ?= _quarto/local
PUB_STAGE  ?= _publish
PUB_FIX    ?=
UV         ?= uv
PYTHON     ?= python3
PUB_HANDOUT_OPTS ?=
PUB_URL_BASE ?= https://noboru-murata.github.io/talks
PUB_QR     ?= figs/qr-edition.svg

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

# 短い名前: 版で公開する配布用 PDF を作る．対象は PUB_EDITION_FILES の左側の *-handout.pdf (無ければ PUB_HANDOUT=… で指定)．
# 名前はファイルの basename (slide-handout.pdf なら make slide-handout．講演の型の名前と同じ．2026-10-17) と，前からの talk-handout．
# (handout だけの名前は ox-quarto の samples で Tufte 形式の解説文の名前なので使わない)
# 講演の Makefile に同じ名前の規則があっても上書きしないよう，ここでは前提だけを並べる (処理は書かない)
# 版が未定 (PUB_EDITION_FILES が空) でも，講演の Makefile に TALK があれば $(TALK)-handout.pdf (2026-10-27)
PUB_HANDOUT ?= $(or $(filter %-handout.pdf,$(PUB_E_SRCS)),$(if $(TALK),$(TALK)-handout.pdf))
PUB_HANDOUT_NAMES = $(basename $(notdir $(PUB_HANDOUT)))
talk-handout: publish-handout-guard $(PUB_HANDOUT)
$(foreach h,$(PUB_HANDOUT),$(eval $(basename $(notdir $(h))): publish-handout-guard $(h)))
publish-handout-guard:
	@test -n "$(strip $(PUB_HANDOUT))" || { echo "publish.mk: 配布用 PDF が決まらない．PUB_EDITION_FILES の左側に <名前>-handout.pdf を書くか，PUB_HANDOUT=… を指定" >&2; exit 1; }

.PHONY: publish publish-stage publish-check publish-diff \
        publish-edition publish-edition-stage publish-edition-check publish-edition-diff \
        publish-all publish-guard publish-edition-guard publish-qr \
        talk-handout publish-handout-guard $(PUB_HANDOUT_NAMES) \
        publish-draft draft-pass draft-guard

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

## 版の頁の QR コード ------------------------------------------------------
# 表紙の #+QUARTO_QR (ox-quarto の title-qr.lua) に使う．URL は PUB_ID と PUB_EDITION から組む．
# 公開の前に作れるよう，talks と主題があるかは確かめない．版を変えても古い画像が残らないよう毎回作る
# (同じ URL なら同じ画像になるので差分は出ない)．
PUB_EDITION_URL = $(PUB_URL_BASE)/$(PUB_ID)/$(PUB_EDITION)/

publish-qr:
	@echo "$(PUB_ID)" | grep -Eq '^[a-z0-9][a-z0-9-]*$$' || { echo "publish.mk: PUB_ID ('$(PUB_ID)') は英小文字・数字・ハイフンだけ" >&2; exit 1; }
	@echo "$(PUB_EDITION)" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}(-[a-z])?$$' || { echo "publish.mk: PUB_EDITION ('$(PUB_EDITION)') は YYYY-MM-DD か YYYY-MM-DD-b" >&2; exit 1; }
	@case "$(PUB_QR)" in *.svg|*.png) ;; *) echo "publish.mk: PUB_QR ('$(PUB_QR)') は .svg か .png" >&2; exit 1;; esac
	@if [ -f "$(PUB_META)" ] && ! grep -Eq '^[[:space:]]*"?$(PUB_EDITION)"?[[:space:]]*:' "$(PUB_META)"; then \
	  echo "publish.mk: 注意: $(PUB_META) の editions に $(PUB_EDITION) が見当たらない" >&2; fi
	@$(PUB_RUN) $(PUB_TOOLS)oxq-qr.py "$(PUB_EDITION_URL)" "$(PUB_QR)"
	@echo "== $(PUB_QR): $(PUB_EDITION_URL)"
	@echo "   org の先頭に (ox-quarto の表紙の QR コード):"
	@echo "#+QUARTO_QR: $(PUB_QR)"
	@echo "#+QUARTO_QR_CAPTION: $(PUB_EDITION_URL)"

## 議論用 (非公開) の写し --------------------------------------------------
# 未発表の結果を含む写しを共同研究者に見せる．drafts の頁は GitHub Pages で誰でも開ける (リポジトリが private でも) ので，html は StatiCrypt，PDF は qpdf で
# 合言葉を掛けて置く (oxq-draft.py)．合言葉は講演ごとに別．写しは固定しない (同じ名前で出し直すと置き換わる)．
DRAFT_ROOT ?= $(PUB_TOOLS)../../drafts
DRAFT_ID   ?= $(PUB_ID)
DRAFT_SRC  ?= ../snapshots
DRAFT_PASS ?= $(HOME)/.config/oxq/drafts/$(DRAFT_ID).pass
DRAFT      ?=

draft-guard:
	@echo "$(DRAFT_ID)" | grep -Eq '^[a-z0-9][a-z0-9-]*$$' || { echo "publish.mk: DRAFT_ID ('$(DRAFT_ID)') は英小文字・数字・ハイフン (既定は PUB_ID)" >&2; exit 1; }

publish-draft: draft-guard
	@echo "$(DRAFT)" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}(-[a-z])?$$' || { echo "publish.mk: DRAFT ('$(DRAFT)') は写しの名前 YYYY-MM-DD か YYYY-MM-DD-b (例 make publish-draft DRAFT=2030-01-15)" >&2; exit 1; }
	$(PYTHON) $(PUB_TOOLS)oxq-draft.py --id "$(DRAFT_ID)" --name "$(DRAFT)" --src "$(DRAFT_SRC)/$(DRAFT)" \
	  --root "$(DRAFT_ROOT)" --pass-file "$(DRAFT_PASS)"

draft-pass: draft-guard
	@if [ ! -f "$(DRAFT_PASS)" ]; then \
	  mkdir -p "$(dir $(DRAFT_PASS))" && chmod 700 "$(dir $(DRAFT_PASS))" && \
	  ( umask 077; $(PYTHON) -c 'import secrets; print(secrets.token_urlsafe(15))' > "$(DRAFT_PASS)" ) && \
	  echo "== $(DRAFT_PASS) を作った"; \
	else echo "== $(DRAFT_PASS) は既にある (変えるときは消してから．変えたら写しを出し直す)"; fi
	@echo "   合言葉: $$(head -1 "$(DRAFT_PASS)")   (URL とは別の経路で共同研究者に伝える)"
