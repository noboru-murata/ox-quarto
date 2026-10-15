# ISSUES — 案件の作業中に気づいた ox-quarto と公開の仕組みの不具合・要望

案件 (講演・講義) のチャットが追記し，「ox-quarto の拡張」プロジェクトのチャットで拾って直す．
直したら項目に「済 (日付，commit)」を書き足す．

**このファイルは GitHub で公開される．** 道具の不具合・要望とその直し方だけを書く．
講演の題・会場・日付，案件のフォルダやファイルの名前，原稿の中身，未発表の結果，個人の情報は書かない
(「講演の案件」「講演の org」のようにぼかす)．そうした事情や，チャットの間の依頼・伝言は
~/Desktop/claude/_meta/messages/ (private．push しない) に書き，ここからは「詳しくは _meta」とだけ書く．

## 要望: 表紙 (#title-slide) に QR コード (と URL) を置きたい
- 日付・出所: 2026-10-12，講演の案件
- 何をしたいか: 講演の版の頁 (talks/PUBLISHING.md の「講演で見せる URL・QR コード」) の QR コードを表紙の右下などに置き，
  講演の始めに写真に撮ってもらう．配布用 PDF にも残るよう，小さく URL の文字も添えたい．
- 今のやり方: 表紙は front matter から Quarto が作るので，org から中身を足せない．
  代わりに次の頁 (`{.overview}` の「講演の流れ」) とまとめの頁に，markdown の export で
  `::: {.absolute right=0 bottom=0 width="200"}` の中に `![](figs/qr-edition.svg)` を置いている (講演の org)．
- 案:
  - org のキーワード (例 `#+QUARTO_QR: figs/qr-edition.svg` と `#+QUARTO_QR_CAPTION: ...`) から表紙に画像を足す．
    `#+QUARTO_DECK: logo` のロゴと同じ仕組み (scss の data URI) か，Lua フィルタ・title-slide の partial で．
  - あるいは URL だけを指定して QR コードを書き出しの時に作る (publish.mk の PUB_EDITION から URL が決まるので，
    tools/ に QR コードを作る規則を置く手もある．Python の segno なら依存が軽い)．
  - あわせて，absolute 配置の QR コードを置く書き方を README.org の「よく使う書き方」に載せるか検討．
- 済 (2026-10-12，ox-quarto の拡張): 表紙の右下に QR コードと URL を置けるようにした．
  - org: `#+QUARTO_QR: figs/qr-edition.svg` と `#+QUARTO_QR_CAPTION: https://noboru-murata.github.io/talks/<主題>/<版>/`
    (CAPTION は省略可．URL ならリンク)．talk.yaml / lecture.yaml の filters に `_quarto/lib/title-qr.lua` を足したので，SETUPFILE はそのまま．
  - 画像: `uv run --script ../../ox-quarto/tools/oxq-qr.py URL figs/qr-edition.svg` (talk/ から．依存は segno だけ)．
  - 位置と大きさは parts.scss の `$title-qr-width` (170px) / `$title-qr-right` / `$title-qr-bottom` (40px) / `$title-qr-padding` / `$title-qr-caption-size`．
    白い地に置くので暗い表紙でも読める．配布用 PDF (notes-handout の ?print-pdf) にも同じ位置に出る．
  - 例: samples/org/talk-sample.org．README.org の「よく使う書き方」に absolute 配置の書き方も載せた．
  - 講演側では，次の頁とまとめの頁の手書きの absolute 配置はそのまま使える．表紙に移すなら #+QUARTO_QR の 2 行を足す．
  - 残り (公開の仕組みの Cowork へ): publish.mk の PUB_ID と PUB_EDITION から URL を組んで QR の画像を作る規則 (例 `make qr`) を足すか．
  - 済 (2026-10-12，公開の仕組み): publish.mk に `make publish-qr` を足した．URL は `PUB_URL_BASE/PUB_ID/PUB_EDITION/`，
    画像は `PUB_QR` (既定 `figs/qr-edition.svg`．talk/ から見たパス)．talks と主題が無くても作れる．最後に org に貼る
    `#+QUARTO_QR` と `#+QUARTO_QR_CAPTION` の 2 行を表示する．試験は samples/publish/test.sh (62 項目)．talks/PUBLISHING.md の 6 に 1 行．

## 要望: 表紙 (#title-slide) の題の高さを，行の数によらず揃えたい
- 日付・出所: 2026-10-12，講演の案件
- 何が起きたか: 講演の org に `#+INSTITUTE:` (所属) を足したら，表紙の題がこれまでよりかなり上に見えた．
  表紙は reveal の `center: true` で題・副題・氏名・所属のまとまりを上下の中央に置くので，
  行 (所属，副題の折り返し，日付など) が増えるとその半分だけ題が上にずれる．講演ごとに題の高さが変わる．
  (QR コード #oxq-title-qr は absolute なので高さに関係しない．)
- 望むこと: 表紙だけ中央寄せをやめ，題の上端をスライドの上から一定の位置 (例 700px の高さの 25〜30%) に固定する．
  副題・氏名・所属・日付はその下に積む．行が増えても題は動かず，下に伸びるだけにしたい．
  QR コード (右下) やロゴ (#+QUARTO_DECK: logo / pin) とは重ならないこと．
- 案:
  - parts.scss / oerreveal.scss で `.reveal #title-slide` に `top: 0 !important` と `padding-top: $title-slide-top` を与える
    (reveal が center のときに付ける top の値を打ち消す)．変数 `$title-slide-top` (!default) で調整できるように．
  - または表紙だけ `data-no-center` 相当にする (title-qr.lua と同じく後から属性を足すスクリプト)．
  - 配布用 PDF (notes-handout の ?print-pdf) でも同じ位置になること．
  - title-qr.lua の place() は表紙の section の高さを測って bottom を決めているので，あわせて確かめる．
- 確かめ方: 講演の org で #+INSTITUTE の行の有無を切り替えて，題の高さが変わらないこと．
- 済 (2026-10-12，ox-quarto の拡張): oerreveal.scss の `$title-slide-top` (既定 202px) で，表紙だけ中央寄せをやめ，題の上端を上から一定の位置に固定した．
  - `.reveal .slides section#title-slide.center { top: 0 !important; padding-top: $title-slide-top !important; }`．
    padding の !important は reveal の印刷の CSS (`padding: 0 !important`) に勝つため．`center: false` の yaml には効かない．`null` で従来の中央寄せ．
  - 202px は talk-sample の「題・副題・氏名」で中央寄せのときの題の位置 (279px) に合わせた値．講演ごとに変えるなら palette や local の scss で上書き．
  - ずれの原因は所属の行だけでなく，absolute の QR コードのはみ出しを reveal が高さに数えていたこと (talk-sample で 279px → 188px)．これも直る．
  - talk-sample で所属と QR の有無の 4 通り，画面と ?print-pdf で題の高さが同じことを確かめた．講演の org での確認は講演側で．

## 不具合: #+begin_center の中の脚注の本文が出ない
- 日付・出所: 2026-10-12，講演の案件 (まとめの頁．今は脚注を使わない形に変えたので急がない)
- 何が起きたか: `#+begin_center` … `[…]{.ex}[fn:qr]` … `#+end_center` と書くと，qmd では center の中が ox-html の raw HTML になり，
  脚注の参照が `<sup><a id="fnr.qr" class="footref" href="#fn.qr">10</a></sup>` のまま出る．
  本文 `[^qr]: …` は qmd の末尾にあるが参照が markdown の `[^qr]` でないので結びつかず，番号だけ出て脚注の本文はどこにも出ない．
- 期待: center の中でも脚注が `[^qr]` になる (あるいは center の中の脚注は警告する)．
- 済 (2026-10-12，ox-quarto の拡張): `#+begin_center` を `::: {.text-center}` の markdown の div にした (ox-quarto-ext-block.el)．中の脚注は `[^qr]` になる．
  中央寄せは `_quarto/lib/text-center.lua` (全部の yaml の filters．html / revealjs は text-align，LaTeX は center 環境，typst は align)．
  あわせて，PDF では center の中身が raw HTML として消えていたのも直った．

## 要望: 中央寄せの頁でも absolute の要素をキャンバスの端に固定する (`.pin-top` / `.pin-bottom`)
- 日付・出所: 2026-10-12，講演の案件 (まとめの頁の右上の QR コード)
- 何が起きたか: `center: true` では reveal が頁の section に `top` を与えて中身を上下の中央に置き，section は中身の高さしか無い．
  そのため `::: {.absolute top=0 right=0}` の top=0 は見出しの行 (中身の上端) になり，中身の量で上下に動く．
  bottom=0 も同じく中身の下端になる (まとめの頁では最後の項目の行の高さに出た)．
- 講演側の今のやり方 (仮．講演の org のまとめの頁．make して右上に止まることを確かめた):
  ```org
  #+begin_export markdown
  ::: {.absolute .pin-top right=0 data-pin-top="0"}
  ![](figs/qr-edition.svg){style="width:170px;max-width:none;box-sizing:border-box;padding:10px;background:#fff;border-radius:4px;"}
  :::
  #+end_export
  ```
  と，同じ頁に `#+begin_export html` の `<script>` を置いている．中身は「`.pin-top` の要素ごとに `el.style.top = data-pin-top − section.offsetTop`」を
  Reveal の ready / resize / slidechanged と window の load で行い，さらに **section の style 属性を MutationObserver で見張る**．
  - 見張りが要る理由: reveal は頁を開いた後にも (文字や画像の読み込みの後) section の top を計算し直す．イベントだけだと
    古い offsetTop で合わせたままになる (調べた例: 97px で合わせた後に 118px に変わり，QR が 21px ずれて見出しと一緒に動いて見えた)．
    title-qr.lua の place() も同じ形なので，同じずれが起きないか確かめてほしい．
- 望むこと:
  - ox-quarto の Lua フィルタ (または after-body のスクリプト) で，クラス `.pin-top` / `.pin-bottom` を付けた absolute の要素を
    キャンバスの上端 / 下端に固定する．余白は属性 (例 `pin-top="0"` → data-pin-top) か scss の既定値で．right / left は今の .absolute のまま．
  - 中央寄せでない頁や `center: false` の yaml でもそのまま正しく動く (offsetTop が 0 なら何もしないのと同じ)．
  - 配布用 PDF (notes-handout の ?print-pdf) でも同じ位置に出る．
  - README.org の「よく使う書き方」に載せる (QR コードを右上に置く例．画像の白い地の style もクラスにできると良い．例 `.qr-tile`)．
- 確かめ方: 講演の org のまとめの頁から講演側の `<script>` を消し，`.pin-top` のクラスだけで QR コードがキャンバスの右上 (余白 0) に止まること．
  画面と ?print-pdf の両方で．
- 関連 (急がない): 下端に置く URL は Quarto の頁ごとの `::: footer` で済んだ (講演の標準にした．_meta/handoff-talks.md)．
  ただ footer は暗い地の頁で $oer-muted のままだと読みにくく，講演側でリンクに `style="color:#BFD0C9"` を付けている．
  `.has-dark-background` の頁では footer の文字とリンクを $oer-on-dark-muted にしてほしい (そうなれば講演側の style は消せる)．
- 済 (2026-10-12，ox-quarto の拡張):
  - `_quarto/lib/pin.lua` (talk.yaml / lecture.yaml の filters)．`.pin-top` / `.pin-bottom` の要素を，キャンバスの上端・下端から
    `pin-top="0"` / `pin-bottom="40"` px (または CSS の `--pin-top` / `--pin-bottom`) に固定する．左右は `.absolute` の left / right のまま．
    reveal のイベントと load に加え，section の style の変化 (MutationObserver) と大きさの変化 (ResizeObserver) で測り直す．
    下にはみ出す要素で reveal の中央寄せがずれるのも直す (固定する要素のある頁は，中身の高さで top を置き直す)．?print-pdf でも同じ．
  - `.qr-tile` (parts.scss): `![](figs/qr-edition.svg){.qr-tile}` で白い地の QR コード (幅 `$qr-tile-width` 170px)．
  - title-qr.lua も pin.lua を使うように直した (指摘のずれへの対処)．
  - 暗い地の頁 (`.reveal.has-dark-background`) で footer の文字とリンクを `$oer-on-dark-muted` に (oerreveal.scss)．
  - 例は samples/org/talk-sample.org の「資料の公開」．README.org の「よく使う書き方」に載せた．
  - 講演側で: 講演の org のまとめの頁の `<script>` と，画像の style・footer のリンクの `style="color:#BFD0C9"` を消し，
    `::: {.absolute .pin-top right=0 pin-top="0"}` と `![](figs/qr-edition.svg){.qr-tile}` だけで右上に止まることを確かめる．
    中身の多い頁では上端の QR が見出しと重なることがある (talk-sample のまとめで起きた．logo の deck は題が右寄せ)．

## 確認 (2026-10-12，講演の案件): 368e8a9〜57635a8 の対応
- `.pin-top` / `.qr-tile`: 講演の org のまとめの頁から自前の <script>・画像の style・data-pin-top を消し，
  `::: {.absolute .pin-top right=0 pin-top="0"}` と `![](figs/qr-edition.svg){.qr-tile}` だけにした．
  make した 講演の html をヘッドレスの Chromium で確かめた: 画面ではキャンバスの上端 (差 0.5px 以内)・右端に止まり，
  前後の頁へ行き来しても動かない．?print-pdf でも .pdf-page の上端 (差 0)・キャンバスの右端 (ページの余白 52.5px の内側) に出る．
  中身 5 項目の頁で，QR の下端は見出しの下線のすぐ上に収まった (重ならない)．ユーザーも make して確認済み．
- 暗い頁の footer: リンクの style を消しても rgb(191, 208, 201) = #BFD0C9 で出る．
- 表紙の題の高さ ($title-slide-top): ユーザーが make して確認 (所属と QR があっても題の位置は問題なし)．
- 警告 "The following string was found in the document: :::": 講演の org の発表者ノートの文中の `::: footer` などを
  `~::: footer~` のように org のコードにした (#+QUARTO_QR，.pin-top，.qr-tile，make publish-qr も)．
- #+begin_center: まとめの頁は脚注を使わない形のままなので，講演側の変更はなし．

## 要望: 配布用 PDF (ノートなし) に短い名前 `make handout` を
- 日付・出所: 2026-10-12，講演の案件
- 今: publish.mk にはパターンの規則 `%-handout.pdf` しかないので，`make <名前>-handout.pdf` とファイル名で呼ぶ．
  一方，ノート付きの PDF は講演の Makefile に `talk-notes: <名前>-notes.pdf` の別名があり `make talk-notes` で作れる．呼び方が揃っていない．
- 望むこと: publish.mk に `handout` (.PHONY) を足し，講演の Makefile の変数から対象を決める．
  例: `PUB_HANDOUT ?= $(TALK)-handout.pdf` として `handout: $(PUB_HANDOUT)` (TALK が無い講演では PUB_HANDOUT を指定)．
  あるいは PUB_EDITION_FILES の左側から `*-handout.pdf` を拾う．
  あわせて publish.mk の冒頭の説明と ox-quarto/samples/Makefile の `make help` に載せる．
- 確かめ方: 講演の talk/ で `make handout` が <名前>-handout.pdf を作ること (今の `make <名前>-handout.pdf` もそのまま使えること)．
- 済 (2026-10-12，公開の仕組み): 名前は `make talk-handout` にした (`handout` は samples/Makefile で Tufte 形式の解説文の名前なので避けた．
  ノート付きの `talk-notes` と対)．publish.mk の規則で，対象は `PUB_EDITION_FILES` の左側の `*-handout.pdf` (講演の <名前>-handout.pdf)．
  `PUB_HANDOUT=…` で変えられる．`make <名前>-handout.pdf` もそのまま使える．講演の Makefile に同じ名前の規則があっても上書きしない．
  samples/Makefile は publish.mk を読まないので help には載せず，publish.mk の冒頭の説明と talks/PUBLISHING.md の 6 に載せた．
  試験は samples/publish/test.sh (71 項目)．確かめ方の 講演の案件での確認は講演側で．

## 要望: ノートなしの配布用 PDF (make talk-handout) の並べ方を org から指定したい
- 日付・出所: 2026-10-13，ox-quarto の拡張 (ox-quarto の Cowork から公開の仕組みの Cowork へ)
- 今: 並べ方は notes-handout.py が決め (--no-notes の既定 6 枚，4 枚以上は 2 列)，変えられるのは講演の Makefile の
  PUB_HANDOUT_OPTS := --per-page 4 だけ．列は枚数から自動．org の notes-pdf-per-page はノート付きにだけ効く (分け方は保つ)．
- 望むこと: org から格子を指定 (例 #+QUARTO_OPTIONS: handout-grid:4x2 = 4 段 × 2 列)．キーは notes-pdf-* と分けて handout-*．
  既定は今と同じ (3x2) で yaml には書かない．notes-handout.py に段と列を渡す指定．優先はコマンド行 > org > 既定．
- 済 (2026-10-13，公開の仕組み):
  - org: `#+QUARTO_OPTIONS: handout-grid:4x2` (段x列．x / × / * のどれでも)．oxq-pdf.py が --no-notes のときだけ読む．
    ノート付きの notes-pdf-* は今までどおり --no-notes では渡さない．書かなければ今と同じ 6 枚 (3x2 と同じ配置)．
  - notes-handout.py `--grid RxC` (段 1〜10，列 1〜6．--no-notes のときだけ．--per-page より優先)．1 枚の幅は
    (174mm − 6mm × (列 − 1)) ÷ 列で，段が頁に収まらなければ縮める (縦横比はスライドのまま)．
  - 優先: PUB_HANDOUT_OPTS の `--grid` / `--per-page` (oxq-pdf.py のコマンド行) > org の handout-grid > 既定．
  - talk-sample (16 枚) で組んで確かめた: 4x2 → 2 頁 (8, 8)，3x2 → 3 頁 (6, 6, 4．既定と同じ)，4x3 → 2 頁 (12, 4)，2x1 → 8 頁，
    5x2・6x3 は幅を縮めて 1 頁に収まる．はみ出しなし (詳しくは NOTES.org の「ノートなしの配布用 PDF の格子」)．
  - 説明: oxq-pdf.py / notes-handout.py / publish.mk の冒頭，README.org (配布用の PDF)，NOTES.org，samples/org/talk-sample.org，talks/PUBLISHING.md の 6．
  - 試験: samples/publish/test.sh (84 項目)．
  - 講演側で: 講演の org に `#+QUARTO_OPTIONS: handout-grid:4x2` を足して make talk-handout (既に QUARTO_OPTIONS の行があればそこに足す)．

## 要望: 文献一覧の著者を省略する書式 (3 名までは全員，4 名以上は 2 名 + et al.)
- 日付・出所: 2026-10-13，講演の案件
- 今: _quarto/csl/apa.csl は文献一覧で 20 名まで全員を並べる．スライドの下に出る文献 (cite-aside) が長くなる
  (6 名の文献もある)．
- 講演側で試したこと: apa.csl を写した 講演側で写した csl の <bibliography> を et-al-min="4" et-al-use-first="2" にして
  (本文の (著者 et al., 年) は APA のまま)，講演の org に `#+QUARTO_REVEALJS_OPTIONS: csl:<写した csl>` を書いた．
  → 下の不具合で make が失敗したので外した．top-level の csl は talk.yaml にあり，#+QUARTO_OPTIONS で足すとキーが重なる．
- 望むこと: この版を _quarto/csl/ に置く (例 apa-short.csl) か，スライドの既定にするか．org から csl を差し替える方法も．
  解説文 (report) にも使えるか．
- 済 (2026-10-13，ox-quarto の拡張): `_quarto/csl/apa-short.csl` を足し，スライド (talk.yaml / lecture.yaml) の既定にした．
  apa.csl の文献一覧だけを et-al-min="4" et-al-use-first="2" にしたもの (本文の引用は APA のまま)．解説文 (report / handout) は apa.csl のまま．
  講演側の 講演側で写した csl と #+QUARTO_REVEALJS_OPTIONS の csl はいらなくなった (SETUPFILE のままで短くなる)．

## 不具合: #+QUARTO_REVEALJS_OPTIONS を書くと talk.yaml の format: revealjs: のリストの値が空になる
- 日付・出所: 2026-10-13，講演の案件
- 再現: 講演の org (SETUPFILE talk-jade.org) に `#+QUARTO_REVEALJS_OPTIONS: csl:<写した csl>` を足して make．
  qmd の format: revealjs: が `theme: ` と `include-in-header: ` (値なし) になり，Quarto が
  「Field "theme" has empty value」で止まる．talk.yaml ではどちらもリスト (- 項目)．
- 原因の見当: org-quarto--strip-and-parse-format-block / org-quarto--format-alist-to-yaml がスカラーの key: value しか扱わず，
  リストの値を落とす (ox-quarto.el の org-quarto-yaml-frontmatter)．
- 済 (2026-10-13，ox-quarto の拡張): 見当どおり本体の読み直しがリストとコメントを落としていた．本体は変えず，
  `lisp/ox-quarto-ext/ox-quarto-ext-format.el` が #+QUARTO_<FORMAT>_OPTIONS を yaml の format: の形式の中に直接書き込む
  (同じ key はリストの値ごと置き換え，無ければ足す．リストとコメントは残る)．書き込んだ行は本体の読み直しを通さない．
  講演側で: Emacs を再起動してから，#+QUARTO_REVEALJS_OPTIONS を書いた org で make が通ることを確かめる．
  csl はスライドの既定が apa-short.csl になったので，講演の案件では csl の行はいらない．

## 要望: 題なしの callout-caution (頁のまとめの一文) の色を palette で選びたい
- 日付・出所: 2026-10-15，講演の案件
- 今: 講演の案件では頁の結びの一文を題なしの callout-caution (appearance="minimal") にしている．jade では caution と warning が
  同じ琥珀なので，「落とし穴」(warning) と「まとめ」(caution) の見分けがつかない．
- 講演側で試したこと: 講演の org の <style> で caution だけ上書きした (左の線を図の主色の青 #0072B2，太さ 0.18em，地を #E6F0F8)．
  左の線は既定より細いほうが一文の帯として落ち着く．
- 望むこと: palette の scss に caution の色 (線・地) の変数を置き，jade などでは warning と別の色を既定にする．
  あるいは「まとめの一文」用の class (例 `.takeaway`) を parts.scss に用意する．
- 済 (2026-10-15，ox-quarto の拡張): jade / burgundy / lavender の caution を warning と別の青系にした (jade は講演側と同じ #0072B2 / 地 #E6F0F8)．
  講演の org の <style> の caution の上書きは消せる．左の線は 4px のまま (講演側の 0.18em は約 5.8px でむしろ太い．細くしたいなら別に相談)．

## 要望: 小さな汎用 class を parts.scss に (表の第 1 列を折り返さない，本文中の小さな参照)
- 日付・出所: 2026-10-15，講演の案件
- 講演の org の <style> で次を足して使っている．他の講演でも使いそうなので，部品にしたい．
  - 表の第 1 列を 1 行に (他の列は折り返す): `table td:first-child, th:first-child { white-space: nowrap }`．
    項目名の列が 2 行に割れると表の高さが増えてはみ出しやすい．表ごとに付ける class (例 `.tbl-key`) が扱いやすい．
  - 本文中の小さく灰色の参照 (例 `[(問題3)]{.ex}`): `font-size: 0.78em; color: (muted)`．`.muted` より小さく，行の中で使う．
  - コード片などの下の小さな説明 (`.cap`): `display: block; font-size: 0.6em; color: (muted)`．
- 色は palette の muted に合わせたい (今は講演側で #5f6b66 を直書き)．
- 済 (2026-10-15，ox-quarto の拡張): parts.scss に `.ex` (0.78em)，`.cap` (block，0.6em)，`.tbl-key` (div で包む: `#+begin_tbl-key` … `#+end_tbl-key`，
  または table に付ける)．色は palette の muted (暗い頁では on-dark-muted)．講演の org の <style> の同じ指定は消せる．

## 要望: inline の SVG (export html) をキャンバス全体に広げる書き方
- 日付・出所: 2026-10-15，講演の案件
- 今: `#+begin_export html` に書いた <svg> は，oerreveal.scss の `img, figure, …, svg { max-height: $fig-max-height }`
  で約 460px に頭打ちになる (width:100% を指定しても縦が縮む)．`#+begin_iframe … :fill "canvas"` のように，
  見出しを隠してキャンバス (1050×700) 全体に図を置きたい．
- 講演側で試したこと: 頁に `:QUARTO_ATTR: {.tl-full}` を付け，SVG の中の <style> で
  `section.tl-full { top:0 !important; height:100% }`，`> h2 { visibility:hidden }`，包む div を `position:absolute; inset:0`，
  svg を `width/height:100%; max-width/max-height:none` にした．題は SVG の中に h2 と同じ大きさ・下線で描いた．
  Chromium で 1050×700 いっぱいになることを確かめた (?print-pdf は未確認)．
- 望むこと: iframe.scss の canvas と同じ規則を，図 (img / svg / figure) にも使える頁の class (例 `{.fill-canvas}`) として用意する．
  見出しを隠すか残すか (残すなら見出しの下いっぱい = 図の `fill "tall"` 相当) を選べるとよい．
- 済 (2026-10-15，ox-quarto の拡張): 頁の class `{.fill-canvas}` (oerreveal.scss)．img / svg / figure をキャンバス全体に，見出しは隠す．
  画面と ?print-pdf で 1050×700 いっぱいになることを確かめた．見出しを残すなら `{.fig-tall}` (svg にも効く)．講演の SVG の中の <style> は消せる．

## 要望: README に図と表を横に並べる例 (figpanel / subfig)
- 日付・出所: 2026-10-15，講演の案件
- 解説文 (report) で `#+begin_figpanel :id fig-… :layout "[[55,45]]"` の中に `#+begin_subfig` を 2 つ置き，
  左に図，右に結果の表を並べた．期待どおり動くが，README.org の「よく使う書き方」に例が無く，書き方を探した．
- 望むこと: README.org (または samples) に，図 + 表の横並びと，列の比の指定の例を載せる．
- 済 (2026-10-15，ox-quarto の拡張): README.org の「よく使う書き方」に figpanel / subfig の例 (列の比，説明の一行，参照) を載せた．

## 要望: 発表者ノートは詳しく，ノート付きの PDF (notes-handout.py) には要約だけを載せたい
- 日付・出所: 2026-10-15，講演の案件
- 今: `#+begin_notes` の中身 (<aside class="notes">) は，reveal の発表者画面にもノート付きの PDF (--layout side の右欄) にも
  そのまま出る．PDF の右欄は狭いので，講演の案件ではノートを要点だけに縮め，詳しい元の文は `#+begin_comment` に退避した．
  発表者画面では詳しい文を見たい．
- 案 (どちらか，または両方):
  1. ノートの中の一部に印を付け，PDF では省く．例: `#+begin_notes` の中に `#+begin_detail` … `#+end_detail`
     (→ `::: {.detail}`)，行の中なら `[…]{.detail}`．発表者画面は aside の中身をそのまま出すので何もしなくてよい．
     notes-handout.py の walk() (aside.notes を辿る所) で `.detail` を飛ばす．
  2. 逆に PDF 用の要約に印を付ける: `#+begin_notes :class "brief"` の aside があればそれだけを PDF に，無ければ全部．
     発表者画面からは CSS (`.reveal aside.notes.brief` は speaker view にも出るので) ではなく，
     speaker view のノート欄に出さない工夫が要る (reveal の notes plugin は section の aside.notes を全部つなぐ)．
     1 のほうが単純．
- あれば: notes-handout.py に `--notes-detail` (印の付いた所も含める) の切り替え，org の `#+QUARTO_OPTIONS: notes-pdf-detail:t`．
- 確かめること: reveal の speaker view (?notes / S キー) が .detail の div を普通に出すこと，?print-pdf でも aside は出ないこと．
- 公開の仕組みの Cowork に回した (2026-10-15．notes-handout.py の受け持ち．_meta/messages/to-publishing.org)．
  org の `#+begin_detail` は今でも `::: {.detail}` になる (ox-quarto-ext の特殊ブロック) ので，残りは PDF で省く所．

## 要望: iframe の印刷用の札にサムネイル画像を出したい
- 日付・出所: 2026-10-15，講演の案件
- 今: `#+begin_iframe` は ?print-pdf (配布用 PDF，ノート付き PDF) で title・代わりの文・ファイル名の札になる (iframe.lua の .iframe-print)．
  デモの頁は PDF では何が見えていたのか分からない．
- 案:
  - `:poster "figs/demo-thumb.png"` を受け取り，札の中 (または札の代わり) に <img> を出す．iframe.scss の html.print-pdf の所で
    img を札いっぱい (object-fit: contain) に，title とファイル名は小さく下に重ねる．poster が無ければ今の札のまま．
    embed-resources: true なので画像は data URI で埋め込まれる (Quarto が img を埋め込む)．
  - サムネイルを作る道具: tools/ に playwright で iframe の src (# 付き) を 1050×700 (fill canvas) や枠の大きさで開いて
    PNG を撮るもの (例 `tools/oxq-thumb.py demo.html#mode=… -o figs/demo-thumb.png --size 1050x700 --wait 2000`)．
    notes-handout.py が既に playwright を使うので依存は増えない．make で src より古ければ撮り直す規則も．
  - html 表示でも iframe を読み込むまでの間 poster を背景に出せると，遅い環境で空白にならない (任意)．
- 済 (2026-10-15，ox-quarto の拡張): `#+begin_iframe … :poster "figs/demo-thumb.png"` で札の地にその画像 (縦横比のまま)，title とファイル名は下に小さく．
  サムネイルは `tools/oxq-thumb.py "../demo/demo.html#…" -o figs/demo-thumb.png [--size 1050x700 --wait 2000]`．make の規則は講演の Makefile で
  (例 `figs/demo-thumb.png: ../demo/demo.html` に `uv run --script $(OXQ)/tools/oxq-thumb.py "$<#…" -o $@`)．html 表示で poster を出すのはしていない．
