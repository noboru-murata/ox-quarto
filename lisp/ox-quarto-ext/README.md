# ox-quarto-ext

[ox-quarto](https://github.com/jrgant/ox-quarto)（Org → Quarto の qmd を書き出すバックエンド）を、Quarto の記法に合わせて補う拡張。
ox-quarto 本体はこのリポジトリの submodule `lisp/ox-quarto` に置いてある。

| ファイル | 役割 |
|---|---|
| `ox-quarto-ext.el` | エントリポイント。全部を読み込み、org 側の入力支援を入れる |
| `ox-quarto-ext-core.el` | 共通ヘルパ（トランスコーダの登録・引用符の処理） |
| `ox-quarto-ext-headline.el` | 見出し: `:QUARTO_ATTR:` と `:notitle:` |
| `ox-quarto-ext-src.el` | コードブロック: `#|` のチャンクオプションと実行チャンクの判定 |
| `ox-quarto-ext-link.el` | 画像リンク: Quarto の図記法 |
| `ox-quarto-ext-block.el` | `#+begin_` ブロック: `:title` の扱い・`:::` の引用符と `#+begin_export latex` |
| `ox-quarto-ext-theme.el` | `#+QUARTO_PALETTE:` / `#+QUARTO_DECK:` yaml の theme の配色と修飾を org から選ぶ |
| `ox-quarto-ext-math.el` | 数式: 名前が `eq-` の latex 環境を `$$ … $$ {#eq-…}` に、行内数式の直後の数字の前に `<!---->` |

## 設定

本体と拡張をどちらもこのリポジトリから読む。straight などで ox-quarto を別に取らない（版が 2 つになり、どちらが読まれるか分かりにくくなる）。

```elisp
(leaf ox-quarto
  :straight nil
  :load-path ("~/Desktop/claude/ox-quarto/lisp/ox-quarto"
              "~/Desktop/claude/ox-quarto/lisp/ox-quarto-ext")
  :after ox
  :require ox-quarto ox-quarto-ext
  :config
  (ox-quarto-ext-install-org-settings))
```

leaf を使わないなら次と同じ。

```elisp
(add-to-list 'load-path "~/Desktop/claude/ox-quarto/lisp/ox-quarto")
(add-to-list 'load-path "~/Desktop/claude/ox-quarto/lisp/ox-quarto-ext")
(with-eval-after-load 'ox
  (require 'ox-quarto)
  (require 'ox-quarto-ext)
  (ox-quarto-ext-install-org-settings))
```

- 読まれている場所は `(locate-library "ox-quarto")` と `(locate-library "ox-quarto-ext")` で確かめる。
- submodule を取っていないと `(require 'ox-quarto)` が失敗する（`git submodule update --init`）。
- コマンド行での書き出し（`tools/export-batch.el`）も同じ submodule を使う。

## 機能

### 見出し（`ox-quarto-ext-headline.el`）

ox-quarto は見出しを ox-md に任せるので、Quarto の見出し属性を書けない。これを補う。

```org
* まとめ
:PROPERTIES:
:QUARTO_ATTR: {.overview background-color="#fff3bf"}
:END:
```

→ `# まとめ {.overview background-color="#fff3bf"}`

`:notitle:` タグの付いた見出しは題を空にする（org 上は題が残るので折りたたみや検索はそのまま）。`:ignore:` と違ってスライドは分かれる。

```org
*** 図だけのスライド                                        :notitle:
```

→ `### {.unnumbered .unlisted}`（`:QUARTO_ATTR:` を併記すればそちらが優先）

### コードブロック（`ox-quarto-ext-src.el`）

`#+name:` と `#+ATTR_QUARTO:` をチャンクオプションにする。

```org
#+name: fig-scatter
#+ATTR_QUARTO: :echo true :fig-cap "散布図" :fig-height 5
#+begin_src R
plot(x, y)
#+end_src
```

→

````
```{r}
#| label: fig-scatter
#| echo: true
#| fig-cap: "散布図"
#| fig-height: 5
plot(x, y)
```
````

- `ox-quarto-ext-executable-languages` にある言語だけを実行チャンク `` ```{lang} `` にし、それ以外（yaml、elisp、json など）は表示だけの `` ```lang `` にする。knitr の「Unknown language engine」の警告が出なくなる。
- `:exec yes` / `:exec no` で個別に切り替える（`#|` には出ない）。
- 値は YAML としてそのまま流れる。空白を含む文字列は引用符ごと書く。

### 画像（`ox-quarto-ext-link.el`）

段落に単独で置いた画像リンクを Quarto の図にする。

```org
#+CAPTION: 散布図のキャプション
#+NAME: fig-scatter
#+ATTR_QUARTO: :width 60% :fig-align "center"
[[file:images/plot.png]]
```

→ `![散布図のキャプション](images/plot.png){#fig-scatter width=60% fig-align="center"}`

- 相互参照するなら名前は `fig-` で始め、本文で `@fig-scatter` と書く。
- キャプションは `#+CAPTION:` に書く（`[[file:…][説明]]` は org がリンクと解釈する）。
- 文中の画像は `![](path)` になり、属性は付かない。

### ブロック（`ox-quarto-ext-block.el`）

特殊ブロックのトランスコーダを差し替えて、`:title` をブロックの種類で使い分ける。

- callout（`callout` と `callout-note` などの `callout-*`）では、これまでどおり div の中の見出し `## …` にする。
- それ以外のブロックでは、属性 `title="…"` として div の見出し行に残す（iframe.lua の iframe の title など、title を属性として読むもの向け）。

```org
#+begin_callout-note :title "定義"            ->  ::: {.callout-note}
本文                                             ## 定義
#+end_callout-note                              本文

#+begin_iframe :src "demo.html" :title "デモ"  ->  ::: {.iframe src="demo.html" title="デモ"}
```

callout に空でない `:title` を付けたときは、`:icon` を書かなければ `icon="false"` を足してアイコンを消す（題を付けた callout ではアイコンを消すことがほとんどなので）。形式によらず同じ。アイコンを残すなら `:icon true`。題が無い・空ならそのまま（Quarto の既定はアイコンあり）。この動きを止めるには `ox-quarto-ext-callout-title-icon` を `t` に。

題の無い種類付きの callout（`callout-note` など）は、`:appearance` を書かなければ `appearance="minimal"` にする（帯もアイコンも無く、左の線と地の色だけが種類の色）。Quarto の既定（帯に既定の題「ノート」などとアイコン）を使うなら `:icon true`。止めるには `ox-quarto-ext-callout-untitled-minimal` を `nil` に。種類なしの `callout` はもともと帯なしなのでそのまま。

```org
#+begin_callout-note :title "定義"              ->  ::: {.callout-note icon="false"}
#+begin_callout-warning :title "注意" :icon true ->  ::: {.callout-warning icon="true"}
#+begin_callout-tip                              ->  ::: {.callout-tip appearance="minimal"}
#+begin_callout-tip :icon true                   ->  ::: {.callout-tip icon="true"}   (帯に「ヒント」)
```

属性の値の `\` と `"` は `\\` と `\"` にエスケープするので、`:title` などに `"` を含めても見出し行は壊れない（`#+ATTR_QUARTO:` では `:title "引用 \"x\""` のように書く）。

- `#+ATTR_QUARTO: :class "fig-tall extra"` の引用符が `::: {.scroll ."fig-tall .extra"}` のように残って壊れるのを直す（インラインパラメータと同じ結果になる）。
- `#+begin_export latex` を Quarto の raw block `` ```{=latex} `` にする（ox-quarto のままでは消える）。PDF では LaTeX として効き、revealjs と html では無視される。

### 配色と修飾（`ox-quarto-ext-theme.el`）

SETUPFILE が `#+QUARTO_FRONTMATTER:` で読む yaml の `theme:` を、大元の org の行で書き換えてから front matter にする（yaml のファイルは変えない）。

```org
#+SETUPFILE: _quarto/org/talk.org
#+QUARTO_PALETTE: lavender     ->  theme の jade-palette.scss を lavender-palette.scss に
#+QUARTO_DECK: logo pin        ->  logo-deck.scss と pin-deck.scss を最後の deck (line-deck) の後に足す
```

- `#+QUARTO_PALETTE:` は theme の `_quarto/scss/<名前>-palette.scss` の行（1 つだけのはず）を差し替える。後に書いたものが勝つ。
  front matter の `callout-palette:` の行（PDF / html の callout の色。`_quarto/lib/callout-colors.lua`）も同じ名前にする。report / handout の yaml は theme の行が無く `callout-palette:` だけなので、それだけを書き換える（どちらも無ければエラー）。
- `#+QUARTO_DECK:` は `_quarto/scss/<名前>-deck.scss` を、theme にある最後の `*-deck.scss` の行の後に書いた順に足す。既にあるものは足さない。複数の行に書けばつながる。
- 配色ごとの theme 以外の設定は `ox-quarto-ext-palette-rules`（既定: dracula では `highlight-style: dracula` を revealjs に置き、`title-bg.scss` を外す）。
- scss が無い、theme に palette の行が 1 つでない、QUARTO_FRONTMATTER が yaml ファイルでない、などはエラーにする。
- 書き換えたときは、qmd の front matter の先頭に `# ox-quarto-ext: palette lavender，deck logo pin を … から書き換え` のコメントを残す。
- どちらの行も無ければ何もしない。
- quarto バックエンドに 2 つのキーワードを登録し、options フィルタで `:quarto-frontmatter` を書き換えた yaml の文字列に置き換える（ox-quarto はファイルとして見つからない値を yaml そのものとして扱う）。

### 形式ごとの指定（`#+QUARTO_<FORMAT>_OPTIONS:`）

`#+QUARTO_REVEALJS_OPTIONS: csl:my.csl slide-number:false` のような行は、front matter の yaml（`QUARTO_FRONTMATTER`。talk.yaml など）があるときは `ox-quarto-ext-format.el` が yaml の `format:` の `revealjs:` の中に書き込む。同じキーがあれば（リストの値ごと）置き換え、無ければ足す。`format:` や形式の行が無ければ作る。ほかの行（`theme:` のリストやコメント）には触れない。

ox-quarto 本体もこの行を扱うが、yaml の `format:` を「key: value」の 1 行の形でしか読み直さないので、`theme:` や `include-in-header:` のリスト（`- 項目`）とコメントが落ち、Quarto が `Field "theme" has empty value` で止まる。そこで書き込んだ行は parse tree から外し、本体の読み直しを通らないようにしている。front matter の yaml が無いときは本体に任せる。書き込んだことは qmd の front matter の先頭にコメントで残る。

### 表紙の所属（`#+INSTITUTE:`）

beamer と同じ `#+INSTITUTE: ○○大学 △△学部` を front matter の `institute:` に書き出す（ox-quarto 本体は書き出さない）。行を重ねれば yaml のリストになる。Quarto の revealjs では氏名の下に所属として出る。実装は `ox-quarto-ext-theme.el` の options フィルタ。

### 中央寄せ（`#+begin_center`）

ox-quarto 本体は center ブロックを持たず、ox-md はそれを丸ごと HTML で書き出す（`org-md--convert-to-html`）。そのため中の脚注が HTML の `<sup><a class="footref">` になって本文と結びつかず、PDF では raw HTML として中身ごと消えていた。`ox-quarto-ext-block.el` が center ブロックを `::: {.text-center}` の div にするので、中は普通の markdown になる。中央寄せにするのは `_quarto/lib/text-center.lua`（html / revealjs は `text-align`、LaTeX は center 環境、typst は `#align(center)`）。

### 表紙の QR コード（`#+QUARTO_QR:` / `#+QUARTO_QR_CAPTION:`）

```org
#+QUARTO_QR: figs/qr-edition.svg
#+QUARTO_QR_CAPTION: https://noboru-murata.github.io/talks/<主題>/<版>/
```

を front matter の `title-qr: {image: …, caption: …}` に書き出す。表紙の右下に置くのは `_quarto/lib/title-qr.lua`（talk.yaml / lecture.yaml の filters．revealjs のみ）。CAPTION は画像の下の小さな文で、URL ならリンクになる（省略可）。CAPTION だけ書くとエラー。画像は `tools/oxq-qr.py` で作れる。実装は `#+INSTITUTE:` と同じ options フィルタ。

### org 側の入力支援（`ox-quarto-ext-install-org-settings`）

構造テンプレート（`C-c C-,`）と `:notitle:` タグを登録する。何度呼んでも重複しない。

| キー | 挿入されるブロック |
|---|---|
| `cn` `ct` `cw` `ci` `cc` | `callout-note` / `-tip` / `-warning` / `-important` / `-caution`（`:title`．題があればアイコンは自動で消える） |
| `cs` `co` `cm` | `columns` / `column` / `column-margin` |
| `cv` | `content-visible :when-format` |
| `ft` `st` | `fig-tall` / `scroll-tall` |

## カスタマイズ

| 変数 | 既定値 | 意味 |
|---|---|---|
| `ox-quarto-ext-executable-languages` | `("r" "python" "julia" "ojs" "mermaid" "dot")` | 実行チャンクにする言語 |
| `ox-quarto-ext-notitle-tag` | `"notitle"` | 題を空にするタグ |
| `ox-quarto-ext-notitle-attr` | `"{.unnumbered .unlisted}"` | そのタグの見出しに付ける属性（nil で付けない） |
| `ox-quarto-ext-notitle-tag-key` | `?n` | タグを `org-tag-alist` に入れるときのキー（nil で入れない） |
| `ox-quarto-ext-image-extensions` | `("png" "jpg" "jpeg" "gif" "svg" "pdf" "webp" "tif" "tiff")` | 画像として扱う拡張子 |
| `ox-quarto-ext-raw-types` | `("LATEX" "TEX")` | raw block にする export block の種類 |
| `ox-quarto-ext-structure-templates` | 上の表 | 構造テンプレート |

leaf なら `:custom` に書く。

```elisp
  :custom ((ox-quarto-ext-executable-languages . '("r" "python" "ojs"))
           (ox-quarto-ext-notitle-attr . "{.unnumbered .unlisted .cover}"))
```

## 設計方針

- 補いはすべて **quarto バックエンドのトランスコーダ** として登録する。`org-md-headline` など ox-md の関数には advice を足さない（ox-md での書き出しに影響し、二重に読み込むと属性が 2 回付く事故が起きたため）。
- advice は使わない。特殊ブロックもトランスコーダを差し替える（以前は `org-quarto--build-div-header` に advice を足していた）。ox-quarto 本体（submodule）は書き換えない。
- 何度 `require` しても、`ox-quarto-ext-install-org-settings` を何度呼んでも、結果は同じになる。
- ox-quarto の内部関数に依存するので、本体（submodule）を更新したらサンプルを書き出して確かめる。
