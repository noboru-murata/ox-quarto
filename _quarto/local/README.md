# _quarto/local — 手元だけのファイル

このフォルダの中身は git に入れない (この README を除く。`.gitignore` で除外)。
配布できないもの (組織の校章やロゴ、個人用の設定) を置く。

例: 自分のロゴを見出しに出す講演の設定

1. ロゴを data URI にする: `python3 ../lib/svg2datauri.py my-logo.png`
2. `my-logo.scss` を作り、`/*-- scss:defaults --*/` の下に 1. の `$header-logo: ...;` を書く
   (大きさなどは `../scss/logo.scss` と `../scss/logo-deck.scss` の変数を参照)
3. `../yaml/talk-logo.yaml` をここに複製し、`theme:` の logo-deck の後に `_quarto/local/my-logo.scss` を足す
4. `../org/talk-logo.org` をここに複製し、`#+QUARTO_FRONTMATTER:` を 3. の yaml に向ける
5. org の先頭で `#+SETUPFILE: _quarto/local/<その org>`
