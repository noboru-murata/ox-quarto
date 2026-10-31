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
- 済 (2026-10-15，公開の仕組み): 案 1．notes-handout.py がノートを読むときに `class="detail"` の要素 (div / span) を飛ばす．
  .detail を除いて空になるノートはノートの無いスライドと同じ扱い．含めるときは `--notes-detail` か org の `#+QUARTO_OPTIONS: notes-pdf-detail:t`
  (oxq-pdf.py が渡す．ノートなしの配布用 PDF には関係ない)．発表者画面 (`Reveal.getSlideNotes()`) には .detail の文がそのまま入ることを確かめた．
  説明: notes-handout.py / oxq-pdf.py の冒頭，README.org (配布用の PDF)，NOTES.org，samples/org/talk-sample.org．試験は samples/publish/test.sh (87 項目)．
  講演の案件での確認は講演側で (詳しくは _meta)．

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

## 要望: callout の種類を役割で使う前提で，配色の色を見直したい (tip を「問題」に，caution の強調)
- 日付・出所: 2026-10-17，講演の案件 (講義でも同じ規則を使う予定)
- 決めた使い方 (環境は増やさず Quarto の 5 種類に役割を割り当てる):
  note = 説明の箱，important = 要 (定義・定式化・原則)，**tip = 問題 (例題・練習問題)**，warning = 注意・限界，
  caution (題なし) = 頁の結論の一文，種類なし = 範囲の外．定義と問題を同じ色にしないため (beamer でも定義と例は色が違う)．
- 望むこと:
  1. 各 palette で，主色 (= note)，tip，important，warning，caution が色相で見分けられること．今気づいた所:
     - jade: tip (#18794e) が note (#0B7558) とほぼ同じ緑．講演側では仮に紫 (線 #6B4E9B，地 #F6F3FA，題の帯 #E9E3F1) にしている．
     - indigo: caution (#92400e) が warning (#b45309) とほぼ同じ茶．他の palette と同じく warning と別の色相に．
     - burgundy: note (主色の濃い赤) と important (赤) が近い (note を主色にする方針なら仕方ないが，確認を)．
  2. 題なしの caution (結論の一文) の中の強調 (strong) を，枠の色にする (今は本文の strong の色 = 主色)．講演側は `<style>` で
     `.reveal .callout.callout-caution strong{color:<caution の色>}` を書いている．
  3. README.org (callout の項) に，上の役割の対応を書く (tip と caution は Quarto の本来の意味と違う使い方であることも)．
- 規則の全文は private の側 (_meta) にある．詳しくは _meta．
- 済 (2026-10-17，ox-quarto の拡張): 役割ごとに色相の定位置を決め (important = 赤，warning = 琥珀，caution = 青，tip = 紫，note = 主色)，
  主色とぶつかる palette だけ代わりの色にした．jade: tip #6B4E9B，caution #006CA8 (#0072B2 は地の上で 4.5:1 にわずかに届かない)．
  indigo: caution #0E7490 (青緑)，warning #9A6700．lavender: tip #2F7D5B (緑)．burgundy: important #6B3FA0 (紫)．
  dracula: caution #bd93f9，important #ff6e6e．どの palette でも 5 つの色相 (OKLCH) が 40° 以上離れ，地の上で 4.5:1 以上
  (`tools/oxq-palette-check.py` で調べる)．箱の中の太字は caution に限らずどの箱でもその箱の色にした．
  README.org に「callout の役割」の節 (tip と caution が Quarto の本来の意味と違うことも)．講演の org の <style> の tip の色と
  caution の太字の指定は消せる．暗い頁と ?print-pdf での見え方は講演側で確かめてほしい．

## 要望: 番号つきの式と例を org の素直な書き方で出したい (LaTeX 由来の原稿を org に載せる案件)
- 日付・出所: 2026-10-17，本の案件 (LaTeX の原稿を org に移し，org → quarto → html / tex / pdf で作る)
- 今:
  - 番号つきの式は，org の latex 環境 (`\begin{align}` など) に `{#eq-…}` を付けられないので，`#+begin_export markdown` の中に
    `$$ … $$ {#eq-…}` と書いている (NOTES.org にもある)．LaTeX の `\label` の代わりに 1 式ごとに export ブロックを書くことになり，
    数百の式をもつ原稿では org が読みにくくなる．
  - 例 (`exm-`) は org の `#+begin_example` が verbatim ブロックなので special block にできず，`::: {#exm-…  .example}` を
    export markdown で直接書いている．定理類 (`thm-` `lem-` `cor-` `def-`) は `#+ATTR_QUARTO: :id` つきの special block でよい．
  - 行内数式の直後に数字が続く (`\(x\)2`) と，qmd の `$x$2` を pandoc が数式と認めない．後処理で空の HTML コメントをはさんでいる
    (`tools/oxq-qmd-mathfix.py`)．
- 望むこと (どれも「できるなら」):
  1. `#+NAME: eq-…` (または `#+ATTR_QUARTO: :id eq-…`) を付けた latex 環境 / `\[ … \]` を，`$$ … $$ {#eq-…}` として書き出す．
  2. `#+ATTR_QUARTO: :id exm-…` を付けた例のブロック (special block の `example`) を `::: {#exm-… .example}` に書き出す．
  3. 行内数式の直後が数字のとき，書き出しの段階で `<!---->` をはさむ (上の後処理を ox-quarto 側に取り込む)．
- 確かめ方: 上の 3 つを含む小さな org を書き出し，quarto の html と tex で式番号・例の番号と相互参照 (`[cite:@eq-…]`) が出ること．
- 済 (2026-10-17，ox-quarto の拡張): 新しい ox-quarto-ext-math.el．
  1. 名前 (`#+NAME:` か `#+ATTR_QUARTO: :id`) が `eq-` で始まる latex 環境を `$$ … $$ {#eq-…}` に書き出す．環境の中の `\label{eq-…}` も名前に使う
     (LaTeX の原稿をそのまま貼れる)．`$$` の中に align などは置けないので，equation は中身だけ，align / flalign / eqnarray → aligned，
     alignat{n} → alignedat{n}，gather / multline → gathered にし，`\label` と `\nonumber` / `\notag` は消す．番号はかたまり 1 つに 1 つ
     (行ごとに番号が要るときは式を分ける)．名前が `eq-` の段落で中身が `\[ … \]` だけのものも同じ．
     番号は名前を付けた式だけに付く (html も PDF も)．PDF は mathtools の showonlyrefs に加え，式の後に `\noeqref{eq-…}` を書き出して
     Quarto の `\ref` の参照でも番号が消えないようにした (report / handout の yaml にも showonlyrefs)．equation と equation* は書き分けなくてよい．
  2. 例は `#+ATTR_QUARTO: :id exm-…` を付けた `#+begin_exm` (special block)．`::: {#exm-… .exm}` になり，Quarto は id の `exm-` で例と見る
     (もとから書き出せていた)．report / handout の yaml に定理・補題・系・命題・定義・例の日本語の名前 (`crossref-*-title` / `-prefix`) を足した．
  3. 行内数式の直後が数字なら書き出しで `<!---->` をはさむ (`\(x\)2` → `$x$<!---->2`．tools/oxq-qmd-mathfix.py は要らなくなる)．
  - report-sample.org の式を `#+NAME: eq-model` に書き換え，例 (`exm-faithful`) を足した．README.org の「よく使う書き方」，NOTES.org．
  - クラウドで org → qmd → html / tex を通し，式・例の番号と `@eq-…` / `[cite:@eq-…]` の参照を確かめた．

## 不具合 (小): 表示だけの src ブロック (:exec no) では #+ATTR_QUARTO の :class などが落ちる
- 日付・出所: 2026-10-17，講演の案件
- 今: `ox-quarto-ext-src-block` は，実行しないブロックを属性なしの ```` ```python ```` として書き出し，ATTR_QUARTO の :class を使わない
  (実行するブロックでは #| の行になる)．そのため `#+attr_quarto: :exec no :class "code-lines-none"` が効かず，
  12 行を超えるコードがスクロールになる．
- 講演側の回避: `#+begin_code-lines-none` … `#+end_code-lines-none` で src ブロックを囲む (`div.code-lines-none pre` が効く)．
- 望むこと: 表示だけのブロックで :class (と :id) を ```` ```{.python .code-lines-none} ```` の形で書き出す．
  README の「よく使う書き方」に code-lines-N / code-lines-none の書き方 (org での指定) を載せる．
- 済 (2026-10-17，ox-quarto の拡張): 表示だけのブロックで ATTR_QUARTO の `:class` (空白で複数)・`:id`・そのほかのキーを
  ```` ```{.python .code-lines-none #id key="v"} ```` の形で書き出す (ox-quarto-ext-src.el)．Quarto は class を `<pre>` に付けるので
  `pre.code-lines-N` が効く．README.org の「よく使う書き方」に「コードの行数 (スライド)」の行．講演側の `#+begin_code-lines-none` の囲みは外せる．

## 不具合 (小): oxq-mathjax-check.py は qmd の名前の無い latex 環境 (`\begin{align*}` など) を検査しない
- 日付・出所: 2026-10-17，LaTeX 由来の原稿を org に載せる案件
- 何が起きたか: 番号の無い式を org の latex 環境 (`\begin{equation*}`，`\begin{align*}` など) で書くと，ox-md がそのまま qmd に出す
  (`$$` で囲まない．pandoc は数式の環境として読み，html は MathJax，tex はそのまま LaTeX が組む)．
  `oxq-mathjax-check.py FILE.qmd` は qmd では `$$ … $$` と `$ … $` だけを拾うので，これらの環境の中の誤り
  (例: MathJax に無い `\lefteqn`) を見逃し「errors 0」になる．同じ原稿を `oxq-mathjax-check.py FILE.org` にかけると見つかる．
  名前 (`eq-`) を付けた環境は ox-quarto-ext-math.el が `$$ … $$ {#eq-…}` にするので qmd でも検査される．
- 案件側の回避: org を検査する (COMMENT の節とコメント行は空行に置き換えてから渡す．org のまま渡すとコメントの中の数式も拾ってしまう)．
- 望むこと:
  1. qmd / md でも，行頭から始まる数式の環境 (align / alignat / equation / gather / multline / flalign / eqnarray と `*` 付き) を検査する
     (org の場合と同じ正規表現で足りる)．
  2. org の検査で，`* COMMENT` の節，`# ` で始まるコメント行，`#+begin_comment` / `example` / `src` の中を対象から外す (行番号は保つ)．
- 確かめ方: `\begin{align*} \lefteqn{a} \\ &= b \end{align*}` を含む qmd と，同じ式を `# ` のコメント行にした org で，
  前者がエラー 1，後者がエラー 0 になること．
- 済 (2026-10-17，ox-quarto の拡張): 1，2 とも．qmd / md でも数式の環境 (`*` 付きも) を検査し，コードブロック (``` / ~~~) の中は外す．
  org では `* COMMENT` の節 (子の節も)，`# ` のコメント行，`#+begin_comment` / `example` / `src` の中を空白に置き換えてから拾う (行番号は保つ)．
  確かめ方の 2 つで qmd がエラー 1，org がエラー 0 (comment 行・src・COMMENT の節の中の \lefteqn は数えず，本文の環境の 1 つだけ) になった．

## 要望: publish.mk の短い名前 talk-handout を，講演の型の名前 (slide-handout) と合わせたい
- 日付・出所: 2026-10-17，講演の案件
- 今: publish.mk は配布用 PDF の短い名前として `make talk-handout` を持つ．講演の側ではファイルの名前を一般名にし
  (slide.org → slide.html，slide-notes.pdf，slide-handout.pdf，解説文は companion)，Makefile のターゲットもファイルの名前にそろえた
  (`make slide` / `slide-notes` / `slide-handout` / `companion`)．`make talk-handout` で slide-handout.pdf ができるのは紛らわしい．
- 講演側の回避: 講演の Makefile に `slide-handout: $(TALK)-handout.pdf` を書いた (talk-handout も残っている)．
- 望むこと: publish.mk に `slide-handout` を (talk-handout と並べて，または置き換えて) 用意する．あるいは短い名前を
  PUB_HANDOUT の basename から作る (`$(basename $(PUB_HANDOUT))` をターゲットにする) と，どの名前の講演でも合う．
  samples/publish や README の例 (talk-notes / talk-handout) も，型を変えるなら合わせて．
- 済 (2026-10-17，公開の仕組み): publish.mk が配布用 PDF の短い名前を PUB_HANDOUT の basename から作る (slide-handout.pdf なら
  `make slide-handout`)．前からの `make talk-handout` も残した (どちらも前提だけの規則なので，講演の Makefile の同じ名前の規則と重なっても上書きしない)．
  あわせて PUB_ROOT の既定を publish.mk の 2 段上の talks にした (講演のフォルダの深さによらない)．samples/publish の作り物の講演の元の名前を
  型に合わせ (talk/slide.html，talk/companion.html)，talks/PUBLISHING.md の 6 の例も型の名前に．試験は samples/publish/test.sh (92 項目．hugo があれば 101)．
  講演側の Makefile の `slide-handout: $(TALK)-handout.pdf` の行は消してよい (残しても害はない)．

## 要望: 空行なしで隣り合う文と数式の環境を，qmd でも 1 つの段落にしたい
- 日付・出所: 2026-10-17，LaTeX 由来の原稿を org に載せる案件
- 何が起きたか: org で
  ```
  文の前半
  \begin{equation*} … \end{equation*}
  文の後半
  ```
  と空行なしで書いても，ox-md は要素の間に必ず空行を入れる (`org-md-separate-elements` が :post-blank を 1 にする) ので，
  qmd では数式の前後で段落が切れる．tex では「文の後半」が新しい段落として字下げされ，LaTeX の原稿 (数式の前後に空行が無い) と組みが変わる．
  名前 (`eq-`) を付けた式 (`$$ … $$ {#eq-…}`) も同じ．Quarto は段落の途中の `$$ … $$ {#eq-…}` を段落を切らずに組むので
  (`\begin{equation}…\label{…}\end{equation}` が段落の中に入る)，qmd で空行が無ければ字下げの問題は起きない．
  org のコメント行 (`# …`．LaTeX の原稿の `%` 行を移したもの) をはさんだ 2 つの段落も，同じ理由で切れる．
- 案件側の回避 (案件の中の小さな elisp と qmd の後処理．詳しくは _meta):
  書き出しの前に parse tree の filter で，原稿 (バッファ) の上で空行なしに隣り合う「段落 / latex 環境」の組
  (間にコメント行だけがあってもよい．`#+NAME` / `#+CAPTION` などの付いた段落 = 図は除く) を見つけ，後ろの要素の頭に印 `<!--jb-->` を付け
  (`org-export-data` への advice)，後処理で印と直前の空行を消す．:post-blank は ox-md の filter で書き換わるので，空行の有無は
  要素の :contents-end (latex 環境は :post-affiliated + 値の長さ) から次の要素の :begin までの文字列で判定している．
  箇条書きの中では空行が字下げの空白だけの行になるので，後処理の正規表現はそれも消す．
- 望むこと: ox-quarto-ext で同じことをする (例えば ox-quarto-ext-math.el に，空行なしで隣り合う段落と latex 環境の間に空行を入れない処理)．
  コメント行をはさむ段落をつなぐかどうかは選べるとよい (変数など．LaTeX 由来の原稿ではつなぎたい)．
- 確かめ方: 上の 3 行の org と，`#+NAME: eq-x` を付けた equation，箇条書きの中の式，間にコメント行をはさんだ 2 つの段落，
  空行で区切った式を含む org を書き出し，qmd で空行が無い所だけがつながり，tex で後ろの文が字下げされないこと．
- 済 (2026-10-17，ox-quarto の拡張): ox-quarto-ext-math.el．quarto バックエンドの parse tree の filter を
  `org-md-separate-elements` の後にもう 1 つ足し，元の org で空行なしに隣り合う段落・latex 環境の組の間は空行を入れない
  (`ox-quarto-ext-math-join`，既定 t)．間にコメント行だけがある組 (段落と段落も) は `ox-quarto-ext-math-join-comments` が t のとき (既定 nil)．
  名前・題の付いた段落 (図) は除き，名前が `eq-` の式は含む．印と後処理は使わない．
  確かめ方の org で，空行の無い所だけがつながり (箇条書きの中も．字下げだけの行も残らない)，tex で後ろの文が同じ段落に入ることを確かめた．
  samples では slide-sample の箇条書きの中の式と report-sample の式の前後だけが変わった．
  本の側は book-join.el と qmd_post.py の <!--jb--> の処理を外し，init (または Makefile で読む elisp) で
  `(setq ox-quarto-ext-math-join-comments t)` にすれば同じになるはず．

## 不具合: スライドが flex の箱になると `#+begin_iframe` の幅が 300px に縮む

- 日付・出所: 2026-10-17，講演の案件 (詳しくは _meta/messages/to-ox-quarto.org)
- 何が起きたか: `#+QUARTO_DECK: pin` の講演の org で `#+begin_iframe :src "…" :fill "tall"` と書くと，iframe が幅 300px (iframe の既定の幅) ×
  高さ 600px の縦長になり，中のデモが真ん中に小さく出る．表示中のスライドが flex (column) の箱になり (oerreveal.scss の slide-flex)，
  `.iframe-wrap` の `margin: 0 auto` (iframe.scss) のため横に伸びず中身の幅に縮む．中の iframe は `width="100%"` なので，縮んだ箱の 100% になり，
  結局 iframe の既定の 300px になる．`:fill "tall"` に限らず，幅を % で指定した iframe は同じはず．
- 案件側の回避: `:width "1000px"` のように幅を px で書く (箱がその幅に縮むので正しく出る)．
- 望むこと: `.iframe-wrap` に `width: 100%` (または `align-self: stretch`) を付けるなどして，flex のスライドでも横いっぱいになるようにする．
- 確かめ方: pin の講演で `:fill "tall"`，`:height "500px"`，指定なしの iframe を置き，どれも横幅いっぱいに出ること (playwright で iframe の clientWidth を見る)．
- 済 (2026-10-17，ox-quarto の拡張): `.iframe-wrap` の左右の margin を 0 にし，flex の中では `align-self: stretch` で横いっぱいにした
  (`width: 100%` は列の中で margin の分はみ出すので使わない)．幅を px などで書いた iframe は iframe.lua が `iframe-fixed-width` を付け，
  箱を iframe の幅に縮めて中央に置く (印刷の札も iframe の幅)．pin の講演で `:fill "tall"` / `:height "500px"` / 指定なしが
  どれも幅 1050px (キャンバスいっぱい)，`:width "600px"` は 600px で中央，?print-pdf の札も同じ幅になった．iframe-sample は変わらない．
  講演側の `:width "1000px"` は外してよい．

## 要望: 引用している文献だけを library.bib から抜き出す道具を tools/ に
- 日付・出所: 2026-10-19，講演の案件 (講演・講義・本のどれでも使える)
- 今: 講演の案件の talk/ に，org で引いている文献だけを文献の正本 (Zotero / Better BibTeX が書き出す library.bib．読むだけ) から
  抜き出して講演の bib を作る小さな python の道具を置き，Makefile の `make bib` から呼んでいる．講演に共通の型
  (_meta の引き継ぎ) がこの道具を前提にしたが，道具は一つの講演の中にしかない．
- 今の道具がしていること (標準の部品だけ，約 130 行):
  - 引用は org の `[cite:@a;@b]` / `[cite/t:@a]` から拾う (COMMENT の見出しの下も含め，`#` の行は除く)．読む org は複数．
  - library.bib のエントリから abstract / file / keywords / urldate / annotation などを除き，引用の初出順に並べる．
  - Better BibTeX の書き出しの癖を直す (@report の eid → number)．
  - library.bib に無いキーは今の出力から引き継いで表示する (どちらにも無ければ警告)．`-n` で書き込まずに過不足だけ表示．
  - 中身が変わらなければ書かない (make の作り直しを起こさない)．
- 望むこと: `tools/oxq-bib.py` のような共通の道具にする．引数で 読む org (複数)，library.bib の場所，出力，除く欄 を渡せるように
  (例 `python3 $(OXQ)/tools/oxq-bib.py slide.org companion.org ../report/companion-long.org --library $(LIBRARY) -o refs.bib`)．
  library.bib の既定は ox-quarto の隣の biblio/bib/library.bib (publish.mk の PUB_ROOT と同じ考え)．
  README に Makefile の `bib` の規則の例を載せる．
- 今の道具の中身は private の側にある．詳しくは _meta (to-ox-quarto.org)．
- 済 (2026-10-19，ox-quarto の拡張): `tools/oxq-bib.py`．今の道具の処理はそのままに，読む org (並べて渡す)・`--library`・`-o`・`--drop` を引数にした．
  正本の既定は `--library`，環境変数 `OXQ_BIB_LIBRARY` (`LIBRARY_BIB` も読む)，ox-quarto の隣の `biblio/bib/library.bib` の順．
  出力の頭の注は一般的な文に (正本の場所は相対パス)．README.org に「文献」の節と Makefile の規則の例．
  講演の 3 つの org と今の refs.bib を正本の代わりにして書き出し，エントリが今の refs.bib と同じになること，2 度目は「変更なし」になることを確かめた．

## 要望: oxq-bib.py に，正本に無い文献の書誌を手で書いた bib から読む指定を

- 日付・出所: 2026-10-19，講演の案件 (詳しくは _meta/messages/to-ox-quarto.org)
- 今: 正本 (library.bib) に無いキーは今の出力 (refs.bib) から引き継ぐ．Zotero に登録する前の文献 (仮のラベル) を引用するには，
  その書誌を生成物の refs.bib に手で入れるしかなく，refs.bib を消したり別の場所で作り直したりすると失われる．
- 望むこと: 手で書いた bib (例 `research/pending.bib`) を追加で読む指定 (例 `--extra FILE`，複数可)．探す順は 正本 → 追加の bib → 今の出力．
  追加の bib から写したキーは「登録待ち」と表示し，同じキーが正本にあれば「正本に登録済み (追加の bib から消してよい)」と知らせる．
- 確かめ方: 正本に無いキーを追加の bib にだけ書き，refs.bib を消してから作ると入ること．同じキーを正本にも置くと正本の方が使われ，知らせが出ること．
- 済 (2026-10-19，ox-quarto の拡張): `--extra BIB` (複数可)．探す順は 正本 → `--extra` (書いた順) → 今の出力．
  `--extra` から写したキーは「登録待ち (pending.bib から)」，正本にもあるキーは正本の方を使って「正本に登録済み (pending.bib から消してよい)」と表示．
  出力の頭の注にも `--extra` の bib を書く．確かめ方の 2 つを小さな bib で確かめた (refs.bib が無くても登録待ちの文献が入る)．README.org の「文献」にも．
  Makefile では `--extra ../research/pending.bib` を足し，依存にも pending.bib を入れる．

## 不具合 (小): oxq-bib.py が改行をまたぐ引用を拾わず，verbatim やブロックの中の引用を拾う
- 日付・出所: 2026-10-19，講演の案件 (詳しくは _meta/messages/to-ox-quarto.org)
- 何が起きたか: 引用を行ごとに拾っていたので，org の fill で `[cite:@a;` と `@b]` が 2 行に分かれると a も b も拾わなかった．
  逆に `=…=` や `#+begin_src` / `#+begin_example` の中の `[cite:@…]` (書式の例) を拾い，「どこにも無い」で止まった．
- 望むこと: 段落や文書を単位に拾う．verbatim とブロックの中を除く．キーは正本のキーの形の文字に限る．
- 済 (2026-10-19，ox-quarto の拡張): 文書全体を単位に拾うようにした (`[cite:…]` の中は改行をまたいでよい)．
  `#` のコメント行，`~code~` と `=verbatim=` の中 (前後の文字の決まりは org と同じ程度．`a = b` のような式の `=` は外さない)，
  `#+begin_src` / `example` / `comment` の中を除く．キーは英数字と `_ : . + / -` だけ (`@…` は拾わない．末尾の `.` `:` は落とす)．
  折れた引用・式の中の引用・verbatim / code / src / example / コメント行の例・`@…`・地の文の `@key`・COMMENT の節の引用を含む org で
  確かめた (COMMENT の節の引用は今まで通り拾う)．講演の org 3 つでは結果が変わらない．

## 不具合 (小): 列の中の単独の画像の右寄せ (float) の脇に，下の説明文が縦 1 文字ずつ回り込む
- 日付・出所: 2026-10-21，講演の案件
- 何が起きたか: 3 列の column の中で `#+begin_center` に画像 (`#+attr_quarto: :width "100%"` の svg) と，その下に `#+begin_text-80` の説明文を置くと，
  説明文の最初の数文字が画像の左の狭い隙間に縦に 1 文字ずつ並び，残りが画像の下に出る．
  原因は oerreveal の `.reveal img { float: right; }` と `max-width: 90%` (画像が列の幅の 90% までに縮み，左に隙間が残る)．
  talk-base で文字が小さくなって隙間に文字が入るようになり，目立った (Chrome で確認．以前からある振る舞い)．
- 講演側の回避: 画像に `:fig-align "center"` を付けると Quarto が figure で包み，float が外れる．
- 望むこと: 単独の画像の後の要素が回り込まないようにする (例: 画像だけの段落の後を `clear: both` にする，または center の中の画像は float しない)．
- 確かめ方: 3 列の column で，center の中に画像と説明文を置き，説明文が画像の下にまとまって出ること．
- 済 (2026-10-21，ox-quarto の拡張): oerreveal.scss で中央寄せの div (`#+begin_center` → `.text-center`) の中の画像は float しない
  (`.text-center img { float: none; }`)．画像は列の中央に置かれ，後の説明文は画像の下に出る．
  center の外の単独の画像は今まで通り右に float する (oer の回り込み．後の文が脇に並ぶのを使う書き方があるので，clear は足さない)．
  3 列の column で text-60 / text-80 の説明文で確かめた (直す前は text-60 で縦 1 文字ずつの回り込みが出た)．`:fig-align "center"` の回避は外してよい．

## 不具合: 版が未定の講演では `make slide-handout` が無い (配布用 PDF の短い名前が PUB_EDITION_FILES に依る)
- 日付・出所: 2026-10-27，講演の案件 (詳しくは _meta)
- 今: publish.mk の短い名前 (`slide-handout` など) は `PUB_HANDOUT ?= $(filter %-handout.pdf,$(PUB_E_SRCS))` から作る．
  版 (講演の日) が未定で PUB_EDITION_FILES をコメントにしている講演では PUB_HANDOUT が空になり，`make slide-handout` が
  「No rule to make target」で止まる (`make talk-handout` は guard の文言で止まる)．講演の型 (handoff) では `make slide-handout` が使える前提．
- 講演側の回避: 講演の Makefile の include の前に `PUB_HANDOUT := $(TALK)-handout.pdf` を書く．
- 望むこと:
  - PUB_HANDOUT が空のとき，講演の Makefile の `TALK` があれば `$(TALK)-handout.pdf` を既定にする (無ければ今の guard)．
  - あわせて，講演の talk/Makefile の雛形 (ターゲットが slide / slide-notes / slide-handout / companion / bib の型) を ox-quarto に置く
    (samples/publish の Makefile は作り物の講演用で，そのまま写せない．今は既にある講演の Makefile を写していて，古い名前 (talk / talk-notes) が広がる)．
  - 確かめ方: PUB_EDITION_FILES をコメントにした講演で `make -n slide-handout` が `oxq-pdf.py slide.qmd --html slide.html --no-notes -o slide-handout.pdf` になること．
- 済 (2026-10-27，公開の仕組み，ox-quarto 70fcb5d): 
  - publish.mk: PUB_HANDOUT の既定は PUB_EDITION_FILES の左側の `*-handout.pdf`，無ければ `$(TALK)-handout.pdf`．講演の Makefile の
    `PUB_HANDOUT := $(TALK)-handout.pdf` の回避は消してよい．版が未定の講演で `make -n slide-handout` が上の形になることを確かめた．
  - 雛形: `samples/talk/Makefile` (写して `<topic-id>` などを直す)．規則は新しい `tools/talk.mk` にまとめた
    (slide / slide-notes / slide-handout / companion / alts / bib / snapshot / snapshot-full / open-* / clean / help．最後に publish.mk を読む)．
    講演の Makefile には変数と講演に固有の規則だけを書く．前からの名前 talk / talk-notes / talk-handout も同じものを作る．
    LIBRARY (文献の正本) が無い所では refs.bib をそのまま使う (今までは「No rule to make target …library.bib」で止まった)．
    議論用のスナップショットは `tools/oxq-snapshot.sh` (講演の型のものを共通にした)．
  - samples/publish/test.sh に 17 項目 (全部で 145)．

## 不具合: oxq-bib.py が ASCII でない文字を含むキー (漢字，発音記号付きの名前) の引用を拾わない
- 日付・出所: 2026-10-31，講演の案件 (詳しくは _meta)
- 今: `KEY_RE = re.compile(r'@([A-Za-z0-9_][A-Za-z0-9_:.+/-]*)')` が ASCII だけなので，library.bib のキーが
  漢字で始まるもの (`[cite:@松田_2025_…]`) や発音記号で始まるもの (`@Čencov_2000_…`) は引用として拾われず，refs.bib に入らない (警告も出ない)．
  途中に入るもの (`@Csiszár_Tusnády_1984_…`) は `Csisz` で切れて「どこにも無い: Csisz」と警告して止まる．
  library.bib (Better BibTeX) は和文の文献のキーを漢字に，発音記号付きの名前をそのまま書き出す方針になった (biblio の整理，2026-10-28〜29) ので，講演で当たり始めた．
- 望むこと: キーの文字を Unicode の文字・数字と `_:.+/-` にする (例 `@([^\W][\w:.+/-]*)` を re.UNICODE で．`\w` は Python 3 では Unicode)．
  書誌の側の読み取り (bib の項目のキー) も同じ文字を受けること．
- 確かめ方: `[cite:@松田_2025_最適輸送と情報幾何]`，`[cite:@Čencov_2000_StatisticalDecisionRules]`，`[cite:@Csiszár_Tusnády_1984_InformationGeometryAlternating]` を書いた org で
  `oxq-bib.py -n` が 3 件とも「正本」から拾うこと．
- 済 (2026-10-31，ox-quarto の拡張): キーの文字を `\w` (Unicode の文字・数字と `_`) と `:.+/-` にした (`@(\w[\w:.+/-]*)`)．
  `@…` (仮の書き方) は今まで通り拾わない．org と bib のキーはどちらも NFC に揃えてから比べる (Mac で打った Č が C + 結合文字でも同じキー)．
  bib の項目のキーの読み取り (`@type{key,`) はもとから ASCII に限らない．上の 3 つと ASCII のキーを並べた org と，NFD の Čencov の org で
  `-n` が 4 件とも「正本」から拾うこと，refs.bib にそのキーで書き出すことを確かめた．physics-informed_ml の slide.org / companion.org では直す前と同じ結果．
