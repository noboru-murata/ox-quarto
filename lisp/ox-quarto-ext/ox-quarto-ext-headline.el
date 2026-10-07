;;; ox-quarto-ext-headline.el --- heading attributes & :notitle:  -*- lexical-binding: t; -*-

;; ox-quarto は `headline' のトランスコーダを持たず ox-md のものを使うため、
;; 見出しは素の `## タイトル' になり、Quarto の見出し属性を書く手段がない。
;; このファイルは 2 つを補う。
;;
;; (1) :QUARTO_ATTR: プロパティを見出し行の末尾に付ける
;;
;;     * まとめ
;;     :PROPERTIES:
;;     :QUARTO_ATTR: {background-color="#fff3bf"}
;;     :END:
;;
;;   ->  # まとめ {background-color="#fff3bf"}
;;
;;   .class / #id / background-image / background-iframe など、Quarto が
;;   見出しに受け付ける属性はそのまま書ける。
;;
;; (2) :notitle: タグの付いた見出しはタイトル文字列を空にする
;;
;;     *** 図だけのスライド                                        :notitle:
;;     [[file:images/scatter.png]]
;;
;;   ->  ### {.unnumbered .unlisted}
;;
;;   org 上には見出し文字列が残るので折りたたみ・検索・agenda では従来どおり
;;   扱えるが、スライドには出ない。`:ignore:' と違ってスライドの分割は
;;   そのまま行われる（親に吸収されない）。
;;   revealjs では空の h3 が出るが、oerreveal-lecture.scss の
;;   `h3:empty { display: none; }' で高さ 0 になる。
;;   付加する既定の属性は `ox-quarto-ext-notitle-attr' で変える。
;;   :QUARTO_ATTR: を併記した場合はそちらが優先される。

;;; Code:

(require 'ox-md)
(require 'subr-x)
(require 'ox-quarto-ext-core)

(defcustom ox-quarto-ext-notitle-tag "notitle"
  "見出し文字列を空にする org タグ。"
  :type 'string
  :group 'ox-quarto-ext)

(defcustom ox-quarto-ext-notitle-attr "{.unnumbered .unlisted}"
  "`ox-quarto-ext-notitle-tag' の付いた見出しに既定で付与する Quarto 属性。
目次・スライドメニューに空項目が並ぶのを防ぐ。不要なら nil にする。"
  :type '(choice string (const nil))
  :group 'ox-quarto-ext)

(defun ox-quarto-ext-headline--append (line attr)
  "LINE の末尾に ATTR を足す。既に同じ属性で終わっていれば何もしない。
古い設定が残っていて属性が二重に付くのを防ぐための保険。"
  (if (and attr
           (org-string-nw-p attr)
           (not (string-suffix-p attr (string-trim-right line))))
      (concat line " " attr)
    line))

(defun ox-quarto-ext-headline (headline contents info)
  "Transcode HEADLINE, honouring :QUARTO_ATTR: and the notitle tag.
`org-md-headline' の戻り値は改行で始まることがあるため、先頭一致ではなく
最初の `#' 始まりの行を探して処理する。"
  (let* ((out     (org-md-headline headline contents info))
         (attr    (org-element-property :QUARTO_ATTR headline))
         (notitle (member ox-quarto-ext-notitle-tag
                          (org-export-get-tags headline info))))
    (cond
     ;; タイトルを空にする（属性は :QUARTO_ATTR: 優先、無ければ既定値）
     ((and notitle (string-match "^\\(#+\\) .*$" out))
      (replace-match
       (string-trim-right
        (concat (match-string 1 out) " "
                (or attr ox-quarto-ext-notitle-attr "")))
       t t out 0))
     ;; 属性だけを付け足す
     ((and attr (string-match "^\\(#+ .*\\)$" out))
      (replace-match (ox-quarto-ext-headline--append (match-string 1 out) attr)
                     t t out 1))
     (t out))))

(with-eval-after-load 'ox-quarto
  (ox-quarto-ext-set-transcoder 'headline #'ox-quarto-ext-headline))

(provide 'ox-quarto-ext-headline)
;;; ox-quarto-ext-headline.el ends here
