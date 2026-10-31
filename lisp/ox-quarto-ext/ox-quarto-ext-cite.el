;;; ox-quarto-ext-cite.el --- citations that survive Japanese text  -*- lexical-binding: t; -*-

;; ox-quarto 本体の引用 (org-quarto--citation-export) は [cite/t:@key] を素の @key にする．
;; これは日本語の文の中で 2 つの点で壊れる (pandoc 3 で確かめた．2026-10-31):
;;
;;   1. 直前が文字 (「評価した@key」) だと pandoc は @ を引用と読まず，@key がそのまま出る．
;;   2. 直後に空白が無い (「@keyは」) と pandoc は続く日本語まで鍵に含める (鍵 keyは が見つからない)．
;;
;; そこで本文中の引用 (cite/t) は [@{key}]{.cite-t} と書く．span の中の @ は直前が [ なので引用と読まれ
;; (AuthorInText の Cite．tex では \textcite)，{} が鍵の終わりを決める．sec-x などの参照も同じ Cite なので
;; quarto の相互参照もそのまま働く．html には <span class="cite-t"> が残るだけ．
;; 括弧つきの引用 ([cite:@key] → [@key]) は ] で鍵が終わるので本体と同じ．
;;
;; 本体 (submodule) には手を入れず，引用の書き出しの処理系 quarto-ext を登録して quarto に割り当てる．

;;; Code:

(require 'oc)
(require 'ox-quarto)        ; 本体の (quarto . (quarto)) の登録より後に割り当てる
(require 'ox-quarto-ext-core)

(defun ox-quarto-ext-cite--export (citation style _backend info)
  "CITATION を Quarto (pandoc) の引用に書き出す．STYLE は引用の様式．"
  (let* ((common-prefix (org-export-data (org-element-property :prefix citation) info))
         (common-suffix (org-export-data (org-element-property :suffix citation) info))
         (style-name (and style (car style)))
         (suppress-author (string= style-name "na"))
         (text-cite (member style-name '("t" "text")))
         (refs (mapconcat
                (lambda (ref)
                  (let ((key (org-element-property :key ref))
                        (prefix (org-export-data (org-element-property :prefix ref) info))
                        (suffix (org-export-data (org-element-property :suffix ref) info)))
                    (concat prefix
                            (if suppress-author "-@" "@")
                            (if text-cite (concat "{" key "}") key)
                            (if (and text-cite (org-string-nw-p suffix))
                                (concat " [" suffix "]")
                              suffix))))
                (org-element-contents citation)
                (if text-cite ", " "; "))))
    (if text-cite
        (concat common-prefix "[" refs "]{.cite-t}" common-suffix)
      (concat "[" common-prefix refs common-suffix "]"))))

(org-cite-register-processor 'quarto-ext
  :export-citation #'ox-quarto-ext-cite--export)

(setf (alist-get 'quarto org-cite-export-processors) '(quarto-ext))

(provide 'ox-quarto-ext-cite)
;;; ox-quarto-ext-cite.el ends here
