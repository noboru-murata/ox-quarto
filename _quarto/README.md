# oerreveal: structure + palette + deck

`oerreveal.scss` is based on `css/oer-reveal.css`, the standard theme of the
Emacs package [oer-reveal](https://gitlab.com/oer/oer-reveal) (an extension of
org-re-reveal for reveal.js teaching material, part of emacs-reveal), carried
over to Quarto's SCSS theme.

The former single-file theme `oerreveal-lecture.scss` was split into three
layers so that colours and decoration can be swapped without touching the
slide structure. (The old file has been removed; it remains in the git history.)

```
oerreveal.scss        structure only: sizes, fonts, figures, lists, code,
                      tables, callouts, scroll boxes, title-slide layout,
                      vertical alignment (.v-center ...). Neutral grey alone.

-- palettes: colours only (variables, no rules) --
indigo-palette.scss  indigo / crimson on light grey (the former lecture look)
jade-palette.scss     green / amber on pale green-grey, dark title slide
dracula-palette.scss  the Dracula colours (dark deck)
mint-palette.scss     green / amber on near-white paper, deep-green headings,
                      title and section dividers on the paper (jade's light sister)
lavender-palette.scss violet / rose on near-white lilac paper, deep-violet
                      headings, title and section dividers on the paper (as indigo)
amethyst-palette.scss dusty purple / wine on lilac paper, deep-purple headings,
                      greyed aubergine (#2E273A) for the title and dark slides
                      (the lavender-palette before 2026-10-21)
garnet-palette.scss   garnet (burgundy) / deep teal on warm ivory, deep-wine
                      headings, dark wine for the title and dark slides
                      (the burgundy-palette before 2026-10-21)

-- decks: decoration (rules) --
lecture-deck.scss     "↗" after external links, tinted menu button
line-deck.scss        thin line under h2/h3; .eyebrow .muted .accent
                      .secondary .alert; .kpi big numbers
logo-deck.scss        logo + fading line under h2/h3
pin-deck.scss         talk (`center: true`): h2/h3 pinned to the top, only the
                      body centred below; stack after line-deck / logo-deck
```

```yaml
format:
  revealjs:
    theme:
      - default
      - _quarto/scss/oerreveal.scss
      - _quarto/scss/indigo-palette.scss   # swap: jade- / lavender- / mint- / amethyst- / garnet- / dracula-palette
      - _quarto/scss/lecture-deck.scss      # stackable
      - _quarto/scss/logo-deck.scss         # or line-deck (pick one of the two)
```

`oerreveal + indigo-palette + lecture-deck` reproduces the former
`oerreveal-lecture.scss` (checked slide by slide on slide02 at the time).

## Rules for writing a palette or a deck

Quarto reads the `scss:defaults` of the **last** file in `theme:` first.

- Every variable is `!default`, so the file listed later wins.
- A palette sets the `$oer-*` names (and callout, code, table, title-slide
  colours) with literal values only. It must not refer to oerreveal's
  variables: they do not exist yet when the palette is read.
- A deck's colour variables default to `null` and are resolved against the
  palette inside `scss:rules` (`if($line-color, $line-color, $oer-primary)`),
  so a deck works with any palette, and a palette may also preset them
  (indigo-palette sets `$menu-icon-color`).

Palette names a deck can rely on: `$oer-text $oer-viewport-bg $oer-heading
$oer-accent $oer-link $oer-link-external $oer-gray $oer-muted $oer-surface
$oer-quote-bg $oer-example-bg $oer-rule $oer-primary $oer-secondary
$oer-alert $oer-on-dark $oer-on-dark-muted $dark-bg-strong-color
$title-slide-bg $title-slide-title-color $title-slide-subtitle-color
$title-slide-meta-color`.

With a dark title slide (jade, amethyst, garnet) or a dark deck (dracula), leave `title-bg.scss`
out of `theme:`. With dracula-palette, also set `highlight-style: dracula`.

For your own logo with logo-deck, see「logo-deck」below.

# logo-deck: 見出しの左のロゴと線

`logo-deck.scss` は h2 / h3 の見出しの左にロゴ，右寄せの題，下に右へ消えていく線を付ける (line-deck の代わり．どちらか一方)．
色は palette から (線は `$oer-primary` → `$oer-secondary`，既定のロゴは `$oer-primary` の縦の棒)．
org では `#+QUARTO_DECK: logo` (`samples/Makefile` の `make palettes` の logo も同じ)．
以前の `default-header.scss` / `dracula-header.scss` (Quarto の default / dracula の theme に重ねる版) の後継で，変数の名前 (`$header-*`) は同じ．

頁ごとに外す:

```markdown
## ロゴを出さない {.no-logo}
## 線を引かない {.no-rule}
## どちらも無し {.plain-header}
```

## 自分のロゴ

SCSS の変数は yaml から渡せないので，`/*-- scss:defaults --*/` の下に `$header-logo: …;` を書いた 1 行の scss を作り，
`theme:` の logo-deck の **後** に置く (手順は `local/README.md`．校章など配布できないロゴは `_quarto/local/` に)．

- **data URI (勧める)**: `python3 _quarto/lib/svg2datauri.py my-logo.png` が `$header-logo:` の行を出す．
  SVG は % で，PNG / JPEG は base64 で埋め込むので，Quarto の出力の配置が変わっても壊れない．横長のロゴには `$header-logo-width` の値も出す．
- **ファイルを指す**: Quarto は theme を `<doc>_files/libs/revealjs/dist/theme/quarto-<hash>.css` に組み，CSS の `url()` はその css から見た位置になる．
  qmd の隣の `images/logo.png` は `url("../../../../../images/logo.png")` (5 段上がる)．yaml の `resources:` にも足す．
  `url("/images/logo.png")` はサーバから配るときだけ (ファイルを直接開くと出ない)．

画像の目安: ロゴの箱は見出しの約 1.15em で，reveal は大きな画面で全体を拡大するので長辺 256px くらい (128px 未満は HiDPI でぼやける)．
背景は透明に．透明でないときは `$header-logo-plate: true` で下に板を敷く．正方形のロゴは `$header-logo-width: $header-logo-size;`．

| 変数 | 既定 | |
|---|---|---|
| `$header-levels` | `(h2, h3)` | 飾る見出し |
| `$header-rule-color` / `-2` | `$oer-primary` / `$oer-secondary` | 線の左端の色 / 35% の位置の色 |
| `$header-rule-height` / `-fade` / `-gap` | `3px` / `85%` / `0.25em` | 線の太さ / 消える位置 / 題との間 |
| `$header-logo` | 縦の棒 | ロゴ (`url(…)`) |
| `$header-logo-size` / `-width` | `1.15em` / `0.18em` | ロゴの高さ / 箱の幅 (棒は 1.15em × 10/64) |
| `$header-logo-gap` / `-offset` | `0.5em` / `0` | 題との間 / 縦のずらし |
| `$header-logo-plate` (`-color` `-pad` `-radius`) | `false` | ロゴの下の板 |

## 本文の縦の位置 (center: false の deck)

talk / lecture の yaml は reveal の `center: true` (見出しと本文をまとめて上下の中央に．見出しの高さは本文の量で変わる)．
見出しの高さをそろえるには `pin-deck.scss` を line-deck / logo-deck の後に足す (org では `#+QUARTO_DECK: pin`)．
見出しを上に留め，本文はその下と脚注の間の中央に，脚注は下に置く．表紙・`#` の頁・`{.notitle}`・`{.scrollable}` はそのまま．
1 枚だけ本文の位置を変えるのは `{.v-top}` / `{.v-bottom}`．`$pin-body-align`，`$pin-top`，`$pin-bottom` で調整．lecture.yaml の既定には入っていない．

Quarto の既定の `center: false` の deck では，見出しは上に置いたまま，その下の本文の位置を oerreveal の
`$slide-v-align` (`top` (既定) / `center` / `bottom`) と頁ごとの `{.v-center}` / `{.v-bottom}` / `{.v-top}` で決める．
flexbox と auto の margin で並べるので，その頁の直下の要素では `float` が効かない (float の段組みは上寄せの頁で)．
表紙は対象外．`center: true` の deck ではこれらの class は効かない．

# text-size: 文字と数式の大きさ (どの theme でも使える)

`scss/text-size.scss` は `math-size.scss` の後継で，theme の並びのどこに置いてもよい
(他の scss の変数に依存しない)．`math-size.scss` は古いデッキのために残してある．

```yaml
theme:
  - default
  - _quarto/scss/oerreveal.scss      # default / dracula だけでも可
  - _quarto/scss/indigo-palette.scss
  - _quarto/scss/lecture-deck.scss
  - _quarto/scss/text-size.scss
filters:
  - _quarto/lib/text-size.lua        # PDF 出力でも .text-NN / .math-NN を効かせる (任意)
```

| 書き方 (qmd)                    | 書き方 (org)                         | 効果                                   |
|---------------------------------|--------------------------------------|----------------------------------------|
| `::: {.text-90}` … `:::`        | `#+begin_text-90` … `#+end_text-90`  | ブロック全体 (表・callout・数式も) 90% |
| `[語句]{.text-120}`             | `[語句]{.text-120}`                  | 行内 120%                              |
| `## 見出し {.text-85}`          | `:QUARTO_ATTR: {.text-85}`           | 見出しはそのまま，本文だけ 85%         |
| `::: {.callout-note .text-85}`  | `#+begin_callout-note :class "text-85"` | その callout だけ 85%             |
| `::: {.math-85}` … `:::`        | `#+begin_math-85` … `#+end_math-85`  | 数式ブロック 85% (従来どおり)          |
| `::: {.math-scroll}` … `:::`    | `#+begin_math-scroll` …              | はみ出す数式を横スクロール             |

NN は 50〜150 が 5 刻み，160〜200 が 10 刻み (`$text-sizes` で変更可)．em なので入れ子は掛け算．
`.smaller` (Quarto 0.7 / oerreveal 0.6) と `.larger` (1.25) もそのまま使えるが，新しく書く分は
`.text-NN` に揃えるとよい．

# callout の見出し帯

oerreveal は callout の見出し帯を枠の色で塗る: 帯の色 = `mix(枠の色, callout の地の色, $callout-title-tint)`
(既定 12%)．種類なしの `.callout` も含めてすべての callout に効き，地の色に混ぜるので
dracula のような濃い palette でも正しく出る．palette 側で `$callout-title-tint` を変えれば濃さを調整できる．

# pixel-snap: Safari で文字がぼやけるのを防ぐ

reveal.js はスライド全体を `translate(-50%, -50%) scale(s)` で窓の中央に置き，`center: true` の
スライドは縦位置を (窓の高さ − 中身の高さ) / 2 で決める．どちらも小数ピクセルになりやすく，
Safari (WebKit) はそのとき文字をぼかして描く．`lib/pixel-snap.html` は reveal が配置を終えるたびに

1. スライド全体の中心を整数ピクセルに置き，
2. 拡大率を縦横の半分の大きさが整数ピクセルになる値に切り下げ (1050×700 なら 1/175 刻み)，
3. 各スライドの top を整数ピクセルに丸める．

見た目の変化は高々 1 ピクセル程度．テーマ (scss) によらず使える．URL に `?nosnap` を付けると無効になる (見比べ用)．

```yaml
format:
  revealjs:
    include-in-header:
      - _quarto/lib/mathjax-fix.html
      - _quarto/lib/pixel-snap.html
```

# palette の名前

主色の名前に揃えた (10-05): `lecture-palette` → `indigo-palette` (#283593)，講演用の palette → `jade-palette` (#0B7558)．
`dracula-palette` はそのまま．旧 `burgundy-palette` (紫) は `lavender-palette` に改名し，`burgundy-palette` は burgundy (#8C1C3A) を主色とする新しい palette にした (10-06)．
10-21: 表紙と節扉が暗い palette を宝石の名前に揃えた (jade，amethyst，garnet)．`lavender-palette` (暗い表紙) は `amethyst-palette` に，
`burgundy-palette` は `garnet-palette` に改名．`lavender-palette` は表紙と節扉が白い新しい palette (indigo と同じ作り，主色は赤寄りの紫)．
10-22: jade の表紙と節扉を白くした `mint-palette` を足した (主色は黄み寄りの緑 #0B7641)．

# section-toc: 梗概と節扉の一覧

`lib/section-toc.lua` (filter) と `scss/section-toc.scss` (theme) を足すと，第 1 階層の見出しから
節の一覧を自動で作る．org に一覧を書く必要はない．

```org
* 講演の流れ                          ← 梗概: 全節の題と summary を箇条書きで並べる
:PROPERTIES:
:QUARTO_ATTR: {.overview}
:END:

* フィジカルAI                        ← 節扉: 全節の題を並べ，この節だけ濃く (他は薄く)
:PROPERTIES:
:QUARTO_ATTR: {summary="現実世界で動く AI と，その中で物理の知識が担う役割"}
:END:
```

節扉に一覧を出さない節は `{.no-toc}`，一覧から外す節は `{.toc-skip}`．
濃淡・大きさは `$toc-other-opacity` (0.35)，`$toc-font-size`，`$overview-font-size` で調整．palette 非依存．

```yaml
theme: [..., _quarto/scss/section-toc.scss]
filters: [_quarto/lib/section-toc.lua, ...]
```

# 文字の大きさ (oerreveal)

すべて `$slide-scale` (0.8．ルート 32px．2026-10 に 0.85 から変更) から em で決まる．図の高さや scroll の枠も ex なのでこれに比例する (0.8 にしたときに，図は 26.5ex / 35ex，scroll の枠は 27.5ex / 35ex に上げて前の高さを保った)．本文より小さい文字は 3 段にまとめ，
各要素の変数はその段を既定にしている．段を動かせばその段の要素がそろって変わり，1 つだけ変えるときは要素の変数を上書きする．

| 段 | 既定 | 要素の変数 |
|---|---|---|
| `$size-dense` | 0.8 | `$table-cell-font-size` (表)，`$quote-font-size` (引用ブロック) |
| `$size-small` | 0.6 | `$smaller-scale` (`.smaller`)，`$small-font-size` (`<small>`)，`$title-meta-font-size` (表紙の副題・著者・日付) |
| `$size-note` | 0.55 | `$footnote-font-size` (脚注・cite-aside)，`$code-block-font-size` (コード)，`$figcaption-font-size` (図の見出し)，`$footer-font-size` |

- 参考文献のスライドは段の間の `$references-font-size` (0.7em)．規則は `#refs` / `.csl-bib-body` の 1 つだけ．
- 見出しは `$presentation-h1-font-size`〜`h4` (2.0 / 1.6 / 1.25 / 1.05em)，callout は `$callout-font-size` (1em)，入れ子の箇条書きは `$list-nest-scale` (0.9 の掛け算，3 段まで)．
- footer はスライドの外にあるので，canvas の px (`$presentation-font-size-root * $size-note`) に reveal の拡大率 `--slide-scale` を掛ける (窓の高さ vh には依存しない)．

# 脚注

スライドの脚注 (org の `[fn:..]`) の上に細い線を引き，本文より小さくする (oerreveal)．
`$footnote-font-size` (既定 `$size-note` = 0.55em)，`$footnote-rule-color` (既定 `$oer-rule`)．

callout の大きさの既定は，Quarto の html と同じく周りの文字と同じ (`$callout-font-size: 1em`．以前は 0.85em)．

# PDF にしたときの暗い頁

revealjs を PDF にする (`?print-pdf`，Quarto のメニューの「E」) と，表紙・節扉・`{background-color="#…"}` の暗い頁は
`$print-dark-slides` (oerreveal) に従う．

- `plain` (既定): 地色にして，文字も普通の頁の色に戻す (見出しは `$oer-heading`，表紙の副題は `$oer-primary`，著者と日付は `$oer-muted`)．印刷向き．
- `keep`: 画面と同じ (暗い背景に明るい文字)．palette などに `$print-dark-slides: keep;` と書く．

背景が画像の頁はどちらでもそのまま．頁番号は頁ごとの背景に合わせる．
reveal は PDF では背景を頁ごとの `.pdf-page` に移すので，表紙の背景 (`.reveal .backgrounds > .slide-background:first-child`) と
title-bg の白い幕には PDF 用のセレクタ (`.pdf-page:has(> #title-slide)`) も書いてある．

# 頁番号の位置

`controls-layout: bottom-right` の右下の矢印と頁番号 (`slide-number`) の置き方 (oerreveal．画面だけ．PDF は reveal の既定)．

- `$slide-number-place: arrows` (既定): 4 つの矢印の真ん中に置く．左と上の矢印を `$controls-spread` (12px) 外へずらして空きを広げ，`$slide-number-center-size` (12px) で書く．
- `$slide-number-place: left`: 矢印の左に置く (`$slide-number-right` 120px，`$slide-number-bottom` 12px)．

# 発表者ノート (slide-notes)

org の `#+begin_notes` (`::: notes`) は revealjs では発表者表示 (S キー) に出る．html / pdf / typst では Quarto のままだと
印の無い段落として本文に混ざるので，`lib/slide-notes.lua` で出し方を選ぶ．既定は yaml の `slide-notes-default`，
文書ごとに変えるときは org に `#+QUARTO_OPTIONS: slide-notes:margin` (同じキーが yaml と org で重なるとエラーになるので名前を分けた)．

- `box`: 「ノート」の見出しの枠 (lecture.yaml の既定)
- `margin`: 余白 (`.column-margin`．handout-latex / handout-typst の既定)．余白は頁をまたげないので数行まで
- `hide`: 出さない / `plain`: 普通の段落

ノートの長い講演は，スライドの画像とノートを並べた PDF を `tools/oxq-pdf.py` (`notes-pdf: slides`) で作る．
