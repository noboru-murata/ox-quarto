# samples — スライド作成用サンプル

ox-quarto とその拡張 (ox-quarto-ext) で使う書き方を，1 つずつ確かめられるように集めたもの。

- org/slide-sample.org : 講義用 (SETUPFILE `_quarto/org/lecture.org`)。slide01〜03 から機能を含む頁を集めた (元の slide01〜03 は git の履歴 3e3412e の samples/old/ にある)
  - 箇条書き・順に表示・callout・数式・文字と数式の大きさ・脚注
  - 図と説明の 2 列・R の表 (html と pdf で出し分け)・画像と org の表・図の相互参照
  - コードの表示 (echo / eval)・演習 (背景色)・節扉 (見出しをそのまま表示)
  - R の下準備は `preamble.R`
- org/talk-sample.org : 講演用 (SETUPFILE `_quarto/org/talk.org`)。講演資料から抜粋
  - 先頭の `#+QUARTO_PALETTE:` (jade / indigo / lavender / burgundy / dracula) と `#+QUARTO_DECK:` (logo / pin) で配色と見出しを試せる (`make palettes` で配色を全部)
  - 梗概 `{.overview}`・節扉の一覧 (`summary`)・引用と脚注欄の書誌・発表者ノート
  - SVG の図・callout を 3 列・列の間の矢印・定式化の表 `{.formulation}`・大きな数値 (kpi)・暗い背景・参考文献
  - R の下準備は `preamble-talk.R`，文献は `talk-sample.bib`，数値は `data/*.csv`，図は `figs/`
- org/iframe-sample.org : html を取り込む例 (SETUPFILE `_quarto/org/talk.org`)
  - `#+begin_iframe` の指定ごとの例: 既定 (500px．図の上限で頭打ち)・`:height`・`:fill "tall"`・`:width` と `:border`・列の中・`:fill "canvas"` (キャンバス全体)
  - reveal の `background-iframe` (窓全体の背景) と `background-interactive`
  - 取り込む html は `org/iframe/` (sine: 正弦波のスライダー，table: 並べ替えできる元素の表，canvas: キャンバス全体のランダムウォーク，background: 背景の流れる点)．外部の読み込みはない
  - 書き出した html から相対パスで読むので，`make iframe` は `org/iframe/` を `html/iframe/` に写す
- org/report-sample.org : 解説文 (SETUPFILE `_quarto/org/report-latex.org` / `report-typst.org`)
  - 数式 (番号と参照)・R の図と表 (番号と参照)・callout・脚注・引用と参考文献
  - PDF は LaTeX (`make report`) と typst (`make report-typst`．SETUPFILE を入れ替えた一時的な org で書き出す) の両方を作る．文献は `report-sample.bib`
- org/handout-sample.org : Tufte 形式の解説文 (SETUPFILE `_quarto/org/handout-latex.org` / `handout-typst.org`)
  - 脚注 (余白の注)・引用の書誌・図の見出しを余白に，番号のない余白の注 (`[…]{.aside}`)，任意の内容を余白に (`#+begin_column-margin`)，小さな図を余白に (`:column "margin"`)，本文と余白をまたぐ図 (`:column "page-right"`)
  - PDF は LaTeX (`make handout`) と typst (`make handout-typst`) の両方を作る．書誌を余白に出すと文書の最後の参考文献の一覧は作られない．表の見出しは表の上
- quarto/ : ox-quarto で出力した .qmd (make が org/ から写す)
- html/   : quarto render で生成した HTML (見た目の確認用)
- pdf/    : 講義と解説文の PDF

quarto/ html/ pdf/ と org/ の中の .qmd .html は生成物なので git に入れない (make で作り直せる)。

同じサンプルは 3 つのフォルダで同じファイル名 (拡張子だけ違う) にすると対応が分かりやすい。

## 書き出し (make)

samples/ で make を使う。作業は org/ の中で行い、できたものを quarto/ html/ pdf/ に置く。
更新したファイル (org、テーマ `_quarto`、R、図、文献) に関係するものだけを作り直す。

| コマンド | 作るもの |
|---|---|
| `make` | qmd と revealjs をすべて (`make all`) |
| `make qmd` | org → qmd だけ (quarto/) |
| `make talk` / `make slide` | 講演 / 講義の revealjs (html/talk-sample.html, html/slide-sample.html) |
| `make talk-notes` | 講演の配布用 PDF (pdf/talk-sample-notes.pdf)．tools/oxq-pdf.py が front matter の `notes-pdf` で方式を選ぶ (講演の既定は slides: スライドとノートを A4 縦に 1 頁 2 枚．uv と Chromium が要る: brew install uv; uv run --with playwright playwright install chromium) |
| `make iframe` | iframe の例 (html/iframe-sample.html と html/iframe/) |
| `make slide-doc` / `make slide-pdf` | 講義の html 版 (html/slide-sample-doc.html) / PDF (pdf/slide-sample.pdf．oxq-pdf．講義の既定は document: Quarto の pdf でノートは枠) |
| `make slide-all` | 講義を revealjs・html・pdf のすべて |
| `make palettes` | 講演を全 palette で (html/talk-sample-<palette>.html) |
| `make palette-dracula` | 講演を 1 つの palette で (jade indigo lavender burgundy dracula logo) |
| `make slide-palettes` | 講義を全 palette の revealjs で (html/slide-sample-<palette>.html．pdf と html 版は配色によらないので作らない) |
| `make slide-palette-jade` | 講義を 1 つの palette で (indigo jade lavender burgundy dracula) |
| `make report` | 解説文を LaTeX の PDF と html で (pdf/report-sample.pdf，html/report-sample.html) |
| `make report-typst` | 同じ解説文を typst の PDF で (pdf/report-sample-typst.pdf) |
| `make handout` | Tufte 形式を LaTeX の PDF と html で (pdf/handout-sample.pdf，html/handout-sample.html) |
| `make handout-typst` | 同じものを typst の PDF で (pdf/handout-sample-typst.pdf) |
| `make docs` | report・report-typst・handout・handout-typst のすべて (`make full` にも含まれる) |
| `make full` | 上のすべて |
| `make open-talk` / `make open-slide` / `make open-iframe` | できた revealjs をブラウザで開く |
| `make clean` / `make distclean` | org/ の中の生成物を消す / quarto/ html/ pdf/ も消す |
| `make help` | 一覧 |

- palette 別の講演・講義は、talk-sample.org / slide-sample.org の SETUPFILE を talk-<palette>.org / lecture-<palette>.org にして `#+QUARTO_PALETTE` (と `#+QUARTO_DECK`) の行を外した一時的な org を作って書き出し、終わったら消す。元の org そのものは変えない。
- emacs や quarto が PATH に無ければ `make talk QUARTO=/path/to/quarto` のように指定する。
- org の場所などは tools/export-batch.el の既定 (straight の build) による。

make を使わずに書き出すとき:

```sh
cd ox-quarto/samples/org
emacs --batch -Q -l ../../tools/export-batch.el slide-sample.org
quarto render slide-sample.qmd --to revealjs   # pdf / html も可
```
