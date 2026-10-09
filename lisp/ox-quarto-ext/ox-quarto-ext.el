;;; ox-quarto-ext.el --- ox-quarto extensions, all in one  -*- lexical-binding: t; -*-

;; ox-quarto (https://github.com/jrgant/ox-quarto) を Quarto の記法に
;; 合わせて補強する拡張群のエントリポイント。init では
;;
;;     (require 'ox-quarto)
;;     (require 'ox-quarto-ext)
;;
;; の 2 行だけでよい。構成は Org の要素種別ごとに分かれている。
;;
;;   ox-quarto-ext-core.el      共通ヘルパ（トランスコーダ登録・引用符処理）
;;   ox-quarto-ext-headline.el  見出し: :QUARTO_ATTR: と :notitle: タグ
;;   ox-quarto-ext-src.el       コードブロック: #| チャンクオプション・実行判定
;;   ox-quarto-ext-link.el      画像リンク: Quarto の図記法
;;   ox-quarto-ext-block.el     #+begin_ ブロック: :title・::: の引用符・export latex
;;   ox-quarto-ext-theme.el     #+QUARTO_PALETTE / #+QUARTO_DECK: yaml の theme の配色と修飾を org から選ぶ
;;
;; org 側の入力支援（`<cn' などの構造テンプレートと :notitle: タグ）は
;; `ox-quarto-ext-install-org-settings' で入れる。

;;; Code:

(require 'ox-quarto-ext-core)
(require 'ox-quarto-ext-headline)
(require 'ox-quarto-ext-src)
(require 'ox-quarto-ext-link)
(require 'ox-quarto-ext-block)
(require 'ox-quarto-ext-theme)

(defcustom ox-quarto-ext-structure-templates
  '(("cn" . "callout-note :icon false :title")
    ("ct" . "callout-tip :icon false :title")
    ("cw" . "callout-warning :icon false :title")
    ("ci" . "callout-important :icon false :title")
    ("cc" . "callout-caution :icon false :title")
    ("cs" . "columns")
    ("co" . "column")
    ("cm" . "column-margin")
    ("cv" . "content-visible :when-format")
    ("ft" . "fig-tall")
    ("st" . "scroll-tall"))
  "`org-structure-template-alist' に追加する Quarto 用のテンプレート。
`C-c C-,' あるいは `<cn TAB' で展開される。"
  :type '(alist :key-type string :value-type string)
  :group 'ox-quarto-ext)

(defcustom ox-quarto-ext-notitle-tag-key ?n
  "`ox-quarto-ext-notitle-tag' を `org-tag-alist' に登録するときの打鍵。
nil ならタグを登録しない。"
  :type '(choice character (const nil))
  :group 'ox-quarto-ext)

;;;###autoload
(defun ox-quarto-ext-install-org-settings ()
  "Quarto 用の構造テンプレートと :notitle: タグを Org に登録する。
何度呼んでも重複しない。"
  (interactive)
  (require 'org)
  (dolist (tpl ox-quarto-ext-structure-templates)
    (add-to-list 'org-structure-template-alist tpl))
  (when ox-quarto-ext-notitle-tag-key
    (add-to-list 'org-tag-alist
                 (cons ox-quarto-ext-notitle-tag
                       ox-quarto-ext-notitle-tag-key))))

(provide 'ox-quarto-ext)
;;; ox-quarto-ext.el ends here
