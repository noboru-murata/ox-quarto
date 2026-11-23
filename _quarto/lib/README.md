# _quarto/lib — Lua フィルタと差し込み (一覧)

yaml (`_quarto/yaml/*.yaml`) の `filters:` / `include-in-header:` から読む部品．詳しい書き方は各ファイルの頭のコメント．
「使う yaml」は既定で入っているもの (入っていなくても front matter に足せば使える)．

## Lua フィルタ (`filters:`)

| ファイル | 役割 | 使う yaml |
|---|---|---|
| `section-toc.lua` | 節の一覧: 梗概 (`{.overview}`) と節扉 (`scss/section-toc.scss` と組) | talk |
| `cite-aside.lua` | スライドで引用した文献の書誌をそのスライドの下端に (`cite-aside-max`) | talk, lecture |
| `ack.lua` | 謝辞の頁の人の一覧 (`#+begin_people`．ほかの部品は `scss/parts.scss`) | talk, lecture |
| `iframe.lua` | `#+begin_iframe` (`::: {.iframe src=…}`) を `<iframe>` に．`:steps t` で `iframe-steps.html` を足す | talk, lecture |
| `pin.lua` | 中央寄せの頁でも absolute の要素を上端・下端に固定 (`.pin-top` / `.pin-bottom`) | talk, lecture |
| `title-qr.lua` | 表紙の右下に QR コードと短い文 (`#+QUARTO_QR`) | talk, lecture |
| `no-hrule.lua` | `---` を revealjs 以外で横線にしない | talk, lecture |
| `text-size.lua` | `.text-NN` / `.math-NN` を PDF (LaTeX) の大きさの指定に (revealjs は `scss/text-size.scss`) | talk, lecture |
| `text-center.lua` | 中央寄せ (`#+begin_center` → `::: {.text-center}`) を各形式で | すべて |
| `slide-notes.lua` | 発表者ノート (`#+begin_notes`) を revealjs 以外でどう出すか (`slide-notes-default`) | lecture, handout-*, note |
| `callout-colors.lua` | PDF (LaTeX) と html の callout を palette の役割の色に (`callout-palette:`) | lecture, report-*, handout-*, note |
| `callout-colors-typst.lua` | typst の callout の色 (`quarto` の **後** に置く) | report-typst, handout-typst |
| `title-block.lua` | 解説文の表題を紀要の形に (`#+INSTITUTE` / `#+EMAIL` / `#+AUTHOR_EN` / `#+INSTITUTE_EN`) | report-*, handout-*, note |
| `cjk-names.lua` | 番号式の文献 (`csl/ams-numeric.csl`) で和文の著者名を和文の書き方に | report-*, handout-*, note |
| `cite-margin.lua` | Tufte 形式の文献: 引いた段落の横の余白に短い書誌「著者 (年). 題. 誌名.」(本文の引用と最後の一覧は Quarto．PDF では一覧の見出しを足す) | handout-*, note |
| `cite-key-escape.lua` | Quarto の余白の書誌 (`citation-location: margin`，LaTeX．`cite-margin: false` のとき) で和文などのキーの文献も書誌が出るように (Quarto の不具合の回避．`at: post-finalize` で読む) | handout-latex, note |

## html の差し込み (`include-in-header:` など)

| ファイル | 役割 | 使う yaml |
|---|---|---|
| `mathjax-fix.html` | `\mathcal` / `\mathbb` が Chrome で豆腐になるときの対処 | talk, lecture |
| `pixel-snap.html` | スライドの位置と拡大率を整数ピクセルに (Safari のぼやけ対策) | talk, lecture |
| `slide-number-arrows.html` | 頁番号を右下の矢印の箱の中へ (`$slide-number-place: arrows`) | talk, lecture |
| `iframe-steps.html` | 頁送りで埋め込んだデモの段を進める (スライドの側．`iframe.lua` が足す) | (自動) |

## そのほか

| ファイル | 役割 |
|---|---|
| `embed-steps.js` | デモ (html) の側の `iframe-steps` の相手．デモと一緒に写して使う |
| `svg2datauri.py` | 画像を data URI に (`deck-logo` の `$header-logo:`，pointer の `$pointer-image:`) |

整理の記録 (NOTES.org): 2026-11-18 に古い `math-size.lua` (と `scss/math-size.scss`) を消した (`text-size.lua` / `text-size.scss` が後継)．
