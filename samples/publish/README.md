# samples/publish — 公開の仕組みを試すための作り物の講演

`tools/publish.mk` と `tools/oxq-publish.py`，公開側 (talks) の `tools/check.py` と `tools/build-index.py` を，
講演のリポジトリをつながずに試すためのもの．内容に意味はない．取り決めは talks の `PUBLISHING.md`．

    samples/publish/
    ├── publish/meta.yml      講演の原本の meta.yml (主題 publish-sample，版 2030-01-15 と 2030-03-02)
    ├── talk/Makefile         PUB_* の変数と include (講演の talk/Makefile と同じ書き方)．sandbox / test / clean
    ├── talk/sample-talk.html スライドの代わり (発表者ノート，../demo/ の iframe，charset が 1024 バイトより後ろ)
    ├── talk/sample-report.html  解説の代わり (主題の部分)
    ├── demo/sample-demo.html デモ (スライドと解説が ../demo/ で読む)
    ├── mkpdf.py              html から簡単な PDF を作る (標準ライブラリだけ．quarto の代わり)
    └── test.sh               いろいろな場面を自動で試す

- quarto も playwright も要らない．要るのは make，uv，rsync，python3．
- 版の日付はわざと先 (2030 年) にしてある．固定の動きは `OXQ_PUBLISH_TODAY=YYYY-MM-DD` で「今日」を変えて試す．
- PDF は Helvetica で組むので日本語は落ちる．発表者ノートの照合は，ノートの中の英語の文で働く．

## 自動の試験

    sh samples/publish/test.sh            # 作業用のフォルダは mktemp -d
    sh samples/publish/test.sh ~/t/pub    # 作業用のフォルダを決める (記録は <フォルダ>/log/)
    make -C samples/publish/talk test     # 同じ

samples/publish を作業用のフォルダに写して，その中で make を走らせる．リポジトリの中のファイルは書き換えない．
公開側は本物の talks ではなく写し (`make sandbox`．本物の talks の `PUBLISHING.md`・`tools/`・`site.yml`・`Makefile` を写す)．
本物の talks の場所は既定で ox-quarto と同じ階層 (`TALKS=…` で変える)．

試す場面 (84 項目):

- 準備: 写しでない公開側 (本物の talks) には写さない，`make sandbox`
- 初めての公開: 主題が無いと版は止まる，`publish-all`，ノートの除去，`<meta charset>` の追加，3 種類の頁，talks の `make check` (Finder の .DS_Store は読み飛ばし，ほかの隠しファイルは誤り)
- 固定: 講演の日は上書きできる，翌日は止まる (版は変わらない)，`PUB_FIX` で訂正 (revisions と版の頁)，訂正でファイルの増減は止まる
- 主題を育てる: `make publish` で主題は新しくなり，版のデモ・ファイルは固定のまま
- 2 つ目の版: 版ごとの題，主題の頁に 2 つの版，固定前の `PUB_FIX` は記録しない，版の名前の形，editions に無い版，主題に版の名前のフォルダ
- 版の頁の QR コード (`make publish-qr`): 公開側が無くても作れる，URL が版の頁，同じ URL なら同じ画像，PNG，
  editions に無い版は注意だけ，版の名前・画像の拡張子・PUB_ID の形
- 配布用 PDF の短い名前 (`make talk-handout`): PUB_EDITION_FILES の `*-handout.pdf` を作る，新しければ作り直さない，
  ファイル名でも呼べる，`PUB_HANDOUT` で指定，決まらなければ止まる
- 配布用 PDF の並べ方 (`handout-grid`): org の指定を渡す，`PUB_HANDOUT_OPTS` の `--grid` / `--per-page` が優先，書かなければ今と同じ，
  形の誤りで止まる，格子が頁に収まる (quarto は inspect だけの作り物で代え，`oxq-pdf.py -n` で渡す指定を見る)
- 誤りの検出: 配布用 PDF のノート (解説の PDF は照合しない)，公開しないファイルへの参照，相対位置の変わる並び，
  公開しない種類 (.org)，手元の絶対パス，禁止した画像 (ロゴ) の埋め込み，PUB_ID の形

publish.mk・oxq-publish.py・check.py・build-index.py を変えたら走らせる．
Cowork の VM では接続フォルダの中で削除ができないので，作業用のフォルダは接続フォルダの外 (例 `$HOME/t/pub`) にする．

## 手で試す

    cd samples/publish/talk
    make sandbox                                     # ../_talks/ を作る (作り直すときも)
    OXQ_PUBLISH_TODAY=2030-01-10 make publish-all    # 主題と版 2030-01-15
    open ../_talks/publish-sample/2030-01-15/index.html
    OXQ_PUBLISH_TODAY=2030-01-16 make publish-edition                      # 止まる (固定)
    OXQ_PUBLISH_TODAY=2030-01-16 make publish-edition PUB_FIX="誤字の訂正"  # 訂正
    make publish-edition PUB_EDITION=2030-03-02      # 2 つ目の版
    make clean

`publish-guard` に `sample-guard` を足してあり，`make sandbox` の印 (`.sandbox`) が無い公開側には写さない
(作り物を本物の talks に写さないため)．`_talks/`，`talk/_publish/` と PDF は git に入れない．
