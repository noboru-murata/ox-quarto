# Decorated slide headers for Quarto reveal.js

Two matching theme layers, one for a dark deck and one for a light deck:

- `#` (h1) — centered section title
- `##` (h2) — logo on the left, title text right aligned, and a rule underneath
  that starts solid at the left and fades out towards the right

```
dracula/dracula-header.scss   on top of Quarto's dracula theme
default/default-header.scss   on top of Quarto's default theme
*/logo.svg                    the bundled logo: a plain 10x64 vertical bar
*/logo-mark.svg, logo.png     an abstract mark, if you prefer a real logo shape
svg2datauri.py                turns your logo into a $header-logo: line
logo.scss                     template for pointing the theme at your own logo
```

Both files expose the same variables and the same per-slide classes, so
switching a deck between light and dark is a one-line change.

## Use

```yaml
# dark
format:
  revealjs:
    theme: [dracula, dracula-header.scss]
```

```yaml
# light
format:
  revealjs:
    theme: [default, default-header.scss]
```

Copy just the one `.scss` next to your `.qmd`. The placeholder logo is embedded
in it as a data URI, so there is nothing else to copy and nothing is fetched at
render time.

## Your own logo

SCSS variables cannot be set from YAML, so point the theme at your file with a
one-line SCSS listed **after** the header theme in `theme:`. `logo.scss` in this
folder is a ready-made template.

```yaml
format:
  revealjs:
    theme: [default, default-header.scss, logo.scss]
resources:
  - images/
```

```scss
/*-- scss:defaults --*/
$header-logo: url("../../../../../images/logo.png");
```

### Why five `../`

Quarto compiles the theme to

```
<doc>_files/libs/revealjs/dist/theme/quarto-<hash>.css
```

and a `url()` in CSS resolves relative to the CSS file, not to the `.qmd`. Five
levels up lands back in your document's directory, so `images/logo.png` next to
the `.qmd` is `../../../../../images/logo.png` from the stylesheet. A bare
`url("logo.png")` looks inside the theme folder and 404s.

Verified on Quarto 1.8, including with `embed-resources: true`, where pandoc
follows that path and inlines the image for you. Add `resources:` so the file is
copied to the output directory.

A root-relative `url("/images/logo.png")` also works, but only for a deck served
over http(s) — not when opening the `.html` off disk.

### Or embed it, and forget about paths

```bash
python3 svg2datauri.py images/logo.png
```

Paste the printed `$header-logo:` line into `logo.scss` (or over the one in the
theme). SVG is percent-encoded, raster formats are base64-encoded; either way
the result is one self-contained line that cannot break when Quarto changes its
output layout. This is how the bundled placeholder logo is stored.

The script also reports the pixel size and, for a wide logo, the
`$header-logo-width` to use:

```
// my-logo.png: data URI is 2.4 KB
// 640x160 px
// wide logo — set  $header-logo-width: 4.60em;
```

### The bundled bar

`logo.svg` in each theme folder is a plain vertical bar — a 10 x 64 rounded
rect, coloured to match the start of the header rule (`#bd93f9` on dracula,
`#2a76dd` on default). It is what the theme ships with, embedded as a data URI.

Because it is 10 wide and 64 tall, the logo box has to be narrow or the title
sits far from it:

```scss
$header-logo-width: 0.18em;   // = $header-logo-size * 10/64
```

To make the bar thicker or thinner, change the `width`/`viewBox` in the SVG and
re-run `svg2datauri.py`, or just scale `$header-logo-width` — the bar is drawn
with `background-size: contain`, so a wider box makes a proportionally taller
bar, not a stretched one. To change its colour, edit the `fill` in `logo.svg`.

`logo-mark.svg` and `logo.png` are the earlier abstract mark, kept in case you
want a conventional logo shape; they are square, so pair them with
`$header-logo-width: $header-logo-size;`.

### Raster logos

- **Size.** The logo box is about 1.15 em tall and reveal.js scales the whole
  deck up on large displays, so aim for **256 px on the long edge**. Below
  128 px it softens on a HiDPI screen; the script warns about this.
- **Shape.** Square logos need nothing. A wide one needs `$header-logo-width` —
  the image is drawn with `background-size: contain`, so it is never stretched
  and a slightly generous width just adds empty space.
- **Transparency.** Use a transparent background. If your logo only exists on
  the wrong background, set `$header-logo-plate: true` — it draws a plate behind
  the logo (light on the dracula theme, dark on the default theme).
- **Weight.** base64 grows the file by about a third and it lands in every
  rendered HTML. A 256 px logo is typically 3–15 KB. If yours is much larger:
  ```bash
  magick my-logo.png -resize 256x256 -strip logo.png
  ```

## Knobs

All in `scss:defaults`. Defaults differ per theme where marked.

| variable | dracula | default | what it does |
|---|---|---|---|
| `$header-rule-color` | `#bd93f9` | `#2a76dd` | rule color at the left edge |
| `$header-rule-color-2` | `#ff79c6` | `#6741d9` | tint at 35%; set equal to the above for one hue |
| `$header-rule-height` | `4px` | `4px` | rule thickness |
| `$header-rule-fade` | `85%` | `85%` | where the rule becomes fully transparent |
| `$header-rule-gap` | `0.25em` | `0.25em` | gap between title and rule |
| `$header-logo-size` | `1.15em` | `1.15em` | logo height, relative to the h2 font |
| `$header-logo-width` | `0.18em` | `0.18em` | logo box width; `$header-logo-size` for a square logo, more for a wide one |
| `$header-logo-gap` | `0.5em` | `0.5em` | gap between logo and title |
| `$header-logo-offset` | `0` | `0` | vertical nudge for the logo |
| `$header-logo-plate` | `false` | `false` | backing plate behind the logo |
| `$header-logo-plate-color` | `#f8f8f2` | `#222` | plate color |
| `$header-h1-color` | `#f8f8f2` | `#222` | h1 color |
| `$header-h2-color` | `#f8f8f2` | `#222` | h2 color |
| `$presentation-h1-font-size` | `2.5em` | `2.5em` | h1 size |

## Per-slide opt-outs

```markdown
## No logo on this one {.no-logo}
## No rule under this one {.no-rule}
## Plain heading {.plain-header}
```

## Vertical alignment

The talk / lecture decks use reveal's `center: true`: heading and body are
centred together on every slide (the usual reveal.js demo look), so the
heading's height varies with the amount of content. reveal marks those slides
`.center`, and the rules of this section skip them.

To keep the heading at the same height on every slide of such a deck, add
`pin-deck.scss` to `theme:` (after line-deck / logo-deck); from org, write
`#+QUARTO_DECK: pin` in the main file (lisp/ox-quarto-ext adds the line to
talk.yaml's theme at export time). The heading is pinned at the top, the body is centred
in the space between it and the footnotes, which go to the bottom. The title
slide, `#` slides, {.notitle} and {.scrollable} slides are left as they are;
{.v-top} / {.v-bottom} change the body's place on one slide. `$pin-body-align`,
`$pin-top`, `$pin-bottom` adjust it. lecture.yaml does not use it by default.

The rest of this section is for decks with `center: false` (Quarto's default;
`default.yaml`, `dracula.yaml`). The header stays pinned at the top; only what
follows it moves.

```markdown
## Title {.v-center}    body centred in the space under the header
## Title {.v-bottom}    body pushed to the bottom
## Title {.v-top}       explicit top (to opt out of a deck-wide default)
```

Deck-wide default in `scss:defaults` — changing this one line is all it takes:

```scss
$slide-v-align: center;   // top (default) | center | bottom
```

The deck's own title slide is skipped: an auto margin under its `h1` would tear
the subtitle, author and date away from the title. A slide that names its own
alignment (`{.v-top}` and friends) is left to that class.

Use reveal's own `center: false` (Quarto's default) with this. Under
`center: true` the classes have no effect (the slides carry `.center` and are
skipped), so the two ways of placing a slide never fight.

Implemented with flexbox and auto margins: the heading takes the free space
below it, and a second auto margin on the last child splits that space in two,
so the block between them ends up centred. Consequences worth knowing:

- An aligned slide turns its direct children into flex items, and **`float` has
  no effect on a flex item**. Keep float-based column helpers on top-aligned
  slides.
- `display` is set `!important`, because reveal.css marks the visible slide
  `display: block !important`.
- Only the slide on screen is switched to flex, so reveal's `display: none` for
  the others is untouched. print-pdf, where every slide is shown at once and
  reveal wraps each in a `.pdf-page`, has its own selector.

## Notes

- The h2 is a flex container: the logo is `::before` with `margin-right: auto`
  (which is what pushes the title right), and the rule is `::after` with
  `flex: 0 0 100%` so it sits on its own full-width line. No extra markup.
- The gradient ends on its own hue at zero alpha rather than on the
  `transparent` keyword, so it fades cleanly instead of drifting towards grey.
- Nested (vertical) slides get a thinner, dimmer rule so the hierarchy reads.
- `print-color-adjust: exact` is set on the header, otherwise Chrome drops the
  gradient and the logo when exporting to PDF.
- Pandoc marks every `#` slide `title-slide slide level1`, and Quarto then
  shrinks that h1 to the h2 size unless reveal.js has set
  `data-navigation-mode="linear"`. Both files restore the h1 size in all
  navigation modes.


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
lavender-palette.scss dusty purple / wine on lilac paper, deep-purple headings,
                      greyed aubergine (#2E273A) for the title and dark slides
                      (the former burgundy-palette)
burgundy-palette.scss burgundy / deep teal on warm ivory, deep-wine headings,
                      dark wine for the title and dark slides

-- decks: decoration (rules) --
lecture-deck.scss     "↗" after external links, tinted menu button
line-deck.scss        thin line under h2/h3; .eyebrow .muted .accent
                      .secondary .alert; .kpi big numbers
logo-deck.scss        logo + fading line under h2/h3 (default-header look)
pin-deck.scss         talk (`center: true`): h2/h3 pinned to the top, only the
                      body centred below; stack after line-deck / logo-deck
```

```yaml
format:
  revealjs:
    theme:
      - default
      - _quarto/scss/oerreveal.scss
      - _quarto/scss/indigo-palette.scss   # swap: jade- / dracula- / lavender- / burgundy-palette
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

With a dark title slide (piml) or a dark deck (dracula), leave `title-bg.scss`
out of `theme:`. With dracula-palette, also set `highlight-style: dracula`.

For your own logo with logo-deck, `logo.scss` still works (list it after
logo-deck); `$header-logo` and the other `$header-*` names are the same as in
default-header.scss.

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

主色の名前に揃えた (10-05): `lecture-palette` → `indigo-palette` (#283593)，`piml-palette` → `jade-palette` (#0B7558)．
`dracula-palette` はそのまま．旧 `burgundy-palette` (紫) は `lavender-palette` に改名し，`burgundy-palette` は burgundy (#8C1C3A) を主色とする新しい palette にした (10-06)．

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
印の無い段落として本文に混ざるので，`lib/slide-notes.lua` と yaml の `slide-notes` で出し方を選ぶ．

- `box`: 「ノート」の見出しの枠 (lecture.yaml の既定)
- `margin`: 余白 (`.column-margin`．handout-latex / handout-typst の既定)．余白は頁をまたげないので数行まで
- `hide`: 出さない / `plain`: 普通の段落

ノートの長い講演は，スライドの画像とノートを並べた PDF を `tools/oxq-pdf.py` (`notes-pdf: slides`) で作る．
