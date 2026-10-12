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
