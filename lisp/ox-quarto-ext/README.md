まず、**先ほどの二重出力の原因が init.el に見つかりました**。

```elisp
(advice-add 'org-md-headline :around #'my/org-quarto-headline-advice)
```

これと `ox-quarto-heading-attr.el` が同じ仕事をしていました。私が再現テストで使った擬似コードと同一の構造です。

## 整理の方針

要素種別ごとに分ける、という現在の切り分け自体は適切でした。変えたのは次の3点です。

**1. ox-md への advice をすべて廃止** — `org-md-headline` / `org-md-export-block` は ox-md 全体で共有される関数で、そこに advice を足すのが今回の事故の原因でした。代わりに **quarto バックエンドのトランスコーダとして登録**します。

```elisp
(setf (alist-get 'headline (org-export-backend-transcoders
                            (org-export-get-backend 'quarto)))
      #'ox-quarto-ext-headline)
```

これなら何度読み込んでも「置き換え」なので二重適用が原理的に起こりません。advice を残したのは ox-quarto 自身の内部関数 `org-quarto--build-div-header` だけです。

**2. 名前空間を `ox-quarto-ext-` に統一** — 旧版は `ox-quarto-` と `org-quarto-` が混在していて、後者は ox-quarto 本体の名前空間と衝突する危険がありました。

**3. エントリポイントを1つに** — `ox-quarto-ext.el` を require すれば全部入ります。

```
~/lib/org/ox-quarto-ext/
├── ox-quarto-ext.el            エントリポイント + org 側の入力支援
├── ox-quarto-ext-core.el       共通ヘルパ（トランスコーダ登録・引用符処理）
├── ox-quarto-ext-headline.el   見出し: :QUARTO_ATTR: と :notitle:
├── ox-quarto-ext-src.el        コードブロック: #| と実行チャンク判定
├── ox-quarto-ext-link.el       画像リンク: Quarto の図記法
└── ox-quarto-ext-block.el      #+begin_ ブロック: ::: の引用符・export latex
```

`unquote-attr` と `export-block` を `-block.el` にまとめたのは、どちらも「`#+begin_...` で書くブロック」の面倒を見るものだからです。単独では小さすぎました。

## init.el

構造テンプレートとタグ登録も el 側に移したので、こうなります。

```elisp
(leaf ox-quarto
  :straight (ox-quarto :type git :host github :repo "jrgant/ox-quarto")
  :load-path "~/lib/org/ox-quarto-ext"
  :after ox
  :require ox-quarto ox-quarto-ext
  :config
  (ox-quarto-ext-install-org-settings))
```

`:preface` の `my/org-quarto-headline-advice` と `advice-add`、11行の `add-to-list`、5行の絶対パス `require` がすべて消えます。`:load-path` は straight のクローン先とは別に、自分の el を置いたディレクトリを足すためのものです（ディレクトリ名を `ox-quarto-ext` にしたのは、straight のクローンと紛らわしくならないようにするためです）。

テンプレートや タグを変えたいときは `:custom` で:

```elisp
  :custom ((ox-quarto-ext-executable-languages . '("r" "python" "ojs"))
           (ox-quarto-ext-notitle-attr . "{.unnumbered .unlisted .cover}"))
```

## 確認したこと

すべて実際に export して確認しています。

- 見出し属性 / `:notitle:` / チャンクオプション / `:exec` / yaml が ```` ```yaml ```` になること / 画像の図記法 / `::: {.scroll .fig-tall .extra}` の引用符除去 / ```` ```{=latex} ```` — 全部期待どおり
- **二重 require しても属性は1個**
- `advice--p` で `org-md-headline` / `org-md-export-block` に advice が **残っていない**こと
- 同じ org を ox-md で書き出しても Quarto 用の属性が混入しないこと
- `ox-quarto-ext-install-org-settings` を2回呼んでもテンプレートが重複しないこと
- 6ファイルすべてバイトコンパイルが警告なしで通ること

## 移行手順

旧 `ox-quarto-*.el` 5本と、それらの `.elc` は削除してください。`.elc` が残っていると古い定義が読まれます。init を書き換えたら Emacs を再起動するのが確実です（advice は再起動しないと消えません）。
