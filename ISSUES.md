# ISSUES — 案件の作業中に気づいた不具合・要望

案件 (講演・講義) のチャットが追記し，「ox-quarto の拡張」プロジェクトのチャットで拾って直す．
直したら項目に「済 (日付，commit)」を書き足す．

## 要望: 表紙 (#title-slide) に QR コード (と URL) を置きたい
- 日付・出所: 2026-10-12，physics-informed_ml (講演 2026-10-19)
- 何をしたいか: 講演の版の頁 (talks/PUBLISHING.md の「講演で見せる URL・QR コード」) の QR コードを表紙の右下などに置き，
  講演の始めに写真に撮ってもらう．配布用 PDF にも残るよう，小さく URL の文字も添えたい．
- 今のやり方: 表紙は front matter から Quarto が作るので，org から中身を足せない．
  代わりに次の頁 (`{.overview}` の「講演の流れ」) とまとめの頁に，markdown の export で
  `::: {.absolute right=0 bottom=0 width="200"}` の中に `![](figs/qr-edition.svg)` を置いている (physics-informed_ml/talk/piml.org)．
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
- 日付・出所: 2026-10-12，physics-informed_ml (講演 2026-10-19)
- 何が起きたか: piml.org に `#+INSTITUTE: 早稲田大学 理工学術院` を足したら，表紙の題がこれまでよりかなり上に見えた．
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
- 確かめ方: physics-informed_ml/talk/piml.org で #+INSTITUTE の行の有無を切り替えて，題の高さが変わらないこと．
- 済 (2026-10-12，ox-quarto の拡張): oerreveal.scss の `$title-slide-top` (既定 202px) で，表紙だけ中央寄せをやめ，題の上端を上から一定の位置に固定した．
  - `.reveal .slides section#title-slide.center { top: 0 !important; padding-top: $title-slide-top !important; }`．
    padding の !important は reveal の印刷の CSS (`padding: 0 !important`) に勝つため．`center: false` の yaml には効かない．`null` で従来の中央寄せ．
  - 202px は talk-sample の「題・副題・氏名」で中央寄せのときの題の位置 (279px) に合わせた値．講演ごとに変えるなら palette や local の scss で上書き．
  - ずれの原因は所属の行だけでなく，absolute の QR コードのはみ出しを reveal が高さに数えていたこと (talk-sample で 279px → 188px)．これも直る．
  - talk-sample で所属と QR の有無の 4 通り，画面と ?print-pdf で題の高さが同じことを確かめた．piml.org での確認は講演側で．

## 不具合: #+begin_center の中の脚注の本文が出ない
- 日付・出所: 2026-10-12，physics-informed_ml (まとめの頁．今は脚注を使わない形に変えたので急がない)
- 何が起きたか: `#+begin_center` … `[…]{.ex}[fn:qr]` … `#+end_center` と書くと，qmd では center の中が ox-html の raw HTML になり，
  脚注の参照が `<sup><a id="fnr.qr" class="footref" href="#fn.qr">10</a></sup>` のまま出る．
  本文 `[^qr]: …` は qmd の末尾にあるが参照が markdown の `[^qr]` でないので結びつかず，番号だけ出て脚注の本文はどこにも出ない．
- 期待: center の中でも脚注が `[^qr]` になる (あるいは center の中の脚注は警告する)．
- 済 (2026-10-12，ox-quarto の拡張): `#+begin_center` を `::: {.text-center}` の markdown の div にした (ox-quarto-ext-block.el)．中の脚注は `[^qr]` になる．
  中央寄せは `_quarto/lib/text-center.lua` (全部の yaml の filters．html / revealjs は text-align，LaTeX は center 環境，typst は align)．
  あわせて，PDF では center の中身が raw HTML として消えていたのも直った．

## 要望: 中央寄せの頁でも absolute の要素をキャンバスの端に固定する (`.pin-top` / `.pin-bottom`)
- 日付・出所: 2026-10-12，physics-informed_ml (まとめの頁の右上の QR コード)
- 何が起きたか: `center: true` では reveal が頁の section に `top` を与えて中身を上下の中央に置き，section は中身の高さしか無い．
  そのため `::: {.absolute top=0 right=0}` の top=0 は見出しの行 (中身の上端) になり，中身の量で上下に動く．
  bottom=0 も同じく中身の下端になる (まとめの頁では最後の項目の行の高さに出た)．
- 講演側の今のやり方 (仮．physics-informed_ml/talk/piml.org のまとめの頁．make して右上に止まることを確かめた):
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
- 確かめ方: piml.org のまとめの頁から講演側の `<script>` を消し，`.pin-top` のクラスだけで QR コードがキャンバスの右上 (余白 0) に止まること．
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
  - 講演側で: piml.org のまとめの頁の `<script>` と，画像の style・footer のリンクの `style="color:#BFD0C9"` を消し，
    `::: {.absolute .pin-top right=0 pin-top="0"}` と `![](figs/qr-edition.svg){.qr-tile}` だけで右上に止まることを確かめる．
    中身の多い頁では上端の QR が見出しと重なることがある (talk-sample のまとめで起きた．logo の deck は題が右寄せ)．

## 確認 (2026-10-12，physics-informed_ml): 368e8a9〜57635a8 の対応
- `.pin-top` / `.qr-tile`: piml.org のまとめの頁から自前の <script>・画像の style・data-pin-top を消し，
  `::: {.absolute .pin-top right=0 pin-top="0"}` と `![](figs/qr-edition.svg){.qr-tile}` だけにした．
  make した piml.html をヘッドレスの Chromium で確かめた: 画面ではキャンバスの上端 (差 0.5px 以内)・右端に止まり，
  前後の頁へ行き来しても動かない．?print-pdf でも .pdf-page の上端 (差 0)・キャンバスの右端 (ページの余白 52.5px の内側) に出る．
  中身 5 項目の頁で，QR の下端は見出しの下線のすぐ上に収まった (重ならない)．ユーザーも make して確認済み．
- 暗い頁の footer: リンクの style を消しても rgb(191, 208, 201) = #BFD0C9 で出る．
- 表紙の題の高さ ($title-slide-top): ユーザーが make して確認 (所属と QR があっても題の位置は問題なし)．
- 警告 "The following string was found in the document: :::": piml.org の発表者ノートの文中の `::: footer` などを
  `~::: footer~` のように org のコードにした (#+QUARTO_QR，.pin-top，.qr-tile，make publish-qr も)．
- #+begin_center: まとめの頁は脚注を使わない形のままなので，講演側の変更はなし．

## 要望: 配布用 PDF (ノートなし) に短い名前 `make handout` を
- 日付・出所: 2026-10-12，physics-informed_ml
- 今: publish.mk にはパターンの規則 `%-handout.pdf` しかないので，`make piml-handout.pdf` とファイル名で呼ぶ．
  一方，ノート付きの PDF は講演の Makefile に `talk-notes: piml-notes.pdf` の別名があり `make talk-notes` で作れる．呼び方が揃っていない．
- 望むこと: publish.mk に `handout` (.PHONY) を足し，講演の Makefile の変数から対象を決める．
  例: `PUB_HANDOUT ?= $(TALK)-handout.pdf` として `handout: $(PUB_HANDOUT)` (TALK が無い講演では PUB_HANDOUT を指定)．
  あるいは PUB_EDITION_FILES の左側から `*-handout.pdf` を拾う．
  あわせて publish.mk の冒頭の説明と ox-quarto/samples/Makefile の `make help` に載せる．
- 確かめ方: physics-informed_ml/talk で `make handout` が piml-handout.pdf を作ること (今の `make piml-handout.pdf` もそのまま使えること)．
- 済 (2026-10-12，公開の仕組み): 名前は `make talk-handout` にした (`handout` は samples/Makefile で Tufte 形式の解説文の名前なので避けた．
  ノート付きの `talk-notes` と対)．publish.mk の規則で，対象は `PUB_EDITION_FILES` の左側の `*-handout.pdf` (piml なら piml-handout.pdf)．
  `PUB_HANDOUT=…` で変えられる．`make piml-handout.pdf` もそのまま使える．講演の Makefile に同じ名前の規則があっても上書きしない．
  samples/Makefile は publish.mk を読まないので help には載せず，publish.mk の冒頭の説明と talks/PUBLISHING.md の 6 に載せた．
  試験は samples/publish/test.sh (71 項目)．確かめ方の piml での確認は講演側で．

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
  - 講演側で: piml.org に `#+QUARTO_OPTIONS: handout-grid:4x2` を足して make talk-handout (既に QUARTO_OPTIONS の行があればそこに足す)．
