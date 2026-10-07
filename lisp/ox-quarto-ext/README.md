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
| `ox-quarto-ext-block.el` | `#+begin_` ブロック: `:::` の引用符と `#+begin_export latex` |

## 設定

本体と拡張をどちらもこのリポジトリから読む。straight などで ox-quarto を別に取らない（版が 2 つになり、どちらが読まれるか分かりにくくなる）。

```elisp
(leaf ox-quarto
  :straight nil
  :load-path ("~/Desktop/projects/ox-quarto/lisp/ox-quarto"
              "~/Desktop/projects/ox-quarto/lisp/ox-quarto-ext")
  :after ox
  :require ox-quarto ox-quarto-ext
  :config
  (ox-quarto-ext-install-org-settings))
```

leaf を使わないなら次と同じ。

```elisp
(add-to-list 'load-path "~/Desktop/projects/ox-quarto/lisp/ox-quarto")
(add-to-list 'load-path "~/Desktop/projects/ox-quarto/lisp/ox-quarto-ext")
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

- `#+ATTR_QUARTO: :class "fig-tall extra"` の引用符が `::: {.scroll ."fig-tall .extra"}` のように残って壊れるのを直す（インラインパラメータと同じ結果になる）。
- `#+begin_export latex` を Quarto の raw block `` ```{=latex} `` にする（ox-quarto のままでは消える）。PDF では LaTeX として効き、revealjs と html では無視される。

### org 側の入力支援（`ox-quarto-ext-install-org-settings`）

構造テンプレート（`C-c C-,`）と `:notitle:` タグを登録する。何度呼んでも重複しない。

| キー | 挿入されるブロック |
|---|---|
| `cn` `ct` `cw` `ci` `cc` | `callout-note` / `-tip` / `-warning` / `-important` / `-caution`（`:icon false :title`） |
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
- advice を使うのは ox-quarto 自身の内部関数 `org-quarto--build-div-header` だけ。
- 何度 `require` しても、`ox-quarto-ext-install-org-settings` を何度呼んでも、結果は同じになる。
- ox-quarto の内部関数に依存するので、本体（submodule）を更新したらサンプルを書き出して確かめる。
