# samples — スライド作成用サンプル

ox-quarto とその拡張 (ox-quarto-ext) で使う書き方を，1 つずつ確かめられるように集めたもの。

- org/slide-sample.org : 講義用 (SETUPFILE `_quarto/org/lecture.org`)。slide01〜03 から機能を含む頁を集めた
  - 箇条書き・順に表示・callout・数式・文字と数式の大きさ・脚注
  - 図と説明の 2 列・R の表 (html と pdf で出し分け)・画像と org の表・図の相互参照
  - コードの表示 (echo / eval)・演習 (背景色)・節扉 (見出しをそのまま表示)
  - R の下準備は `preamble.R`
- org/talk-sample.org : 講演用 (SETUPFILE `_quarto/org/talk-<palette>.org`)。talk/piml.org から抜粋
  - 先頭の SETUPFILE の行を入れ替えると palette (jade / indigo / lavender / burgundy / dracula) を試せる
  - 梗概 `{.overview}`・節扉の一覧 (`summary`)・引用と脚注欄の書誌・発表者ノート
  - SVG の図・callout を 3 列・列の間の矢印・定式化の表 `{.formulation}`・大きな数値 (kpi)・暗い背景・参考文献
  - R の下準備は `preamble-talk.R`，文献は `talk-sample.bib`，数値は `data/*.csv`，図は `figs/`
- old/ : 整理前のサンプル (slide01〜03 の org / qmd / html と preamble.R)。slide-sample.org の元
- quarto/ : ox-quarto で出力した .qmd
- html/   : quarto render で生成した HTML (見た目の確認用)

同じサンプルは 3 つのフォルダで同じファイル名 (拡張子だけ違う) にすると対応が分かりやすい。

書き出し:

```sh
cd ox-quarto/samples/org
emacs --batch -Q -l ../../tools/export-batch.el slide-sample.org
quarto render slide-sample.qmd --to revealjs   # pdf / html も可
```
