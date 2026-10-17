;;; ox-quarto-ext-math.el --- 数式: 番号つきの式 ($$ … $$ {#eq-…}) と行内数式の直後の数字  -*- lexical-binding: t; -*-

;; Quarto の番号つきの式は `$$ … $$ {#eq-名前}' (かたまり 1 つに番号 1 つ) で，
;; org の latex 環境や \[ … \] には {#eq-…} を付ける書き方が無い．そこで
;;
;;     #+NAME: eq-energy                 (または #+ATTR_QUARTO: :id eq-energy)
;;     \begin{align}
;;     E &= mc^2 \\
;;     p &= mv
;;     \end{align}
;;
;; のように名前が eq- で始まる latex 環境を
;;
;;     $$
;;     \begin{aligned}
;;     E &= mc^2 \\
;;     p &= mv
;;     \end{aligned}
;;     $$ {#eq-energy}
;;
;; に書き出す．環境の中の \label{eq-…} も名前として使う (LaTeX の原稿をそのまま貼れる)．
;; - equation / displaymath は中身だけ，align / flalign / eqnarray は aligned，alignat{n} は alignedat{n}，
;;   gather / multline は gathered にする (* 付きも同じ)．どれも $$ の中で LaTeX と MathJax の両方が通る形．
;;   それ以外の環境 (split など) はそのまま $$ の中に置く．\label と \nonumber / \notag は消す (番号は Quarto が付ける)．
;; - 番号はかたまり 1 つに 1 つ．行ごとに番号が要るときは式を分ける．
;; - 名前が eq- で始まる段落で，中身が \[ … \] だけのものも同じく $$ … $$ {#eq-…} にする．
;; - 名前の無い環境は今まで通り (ox-md のまま)．
;; - 参照は [cite:@eq-energy] か本文に @eq-energy．
;;
;; 行内数式の直後に数字が続く (\(x\)2) と，qmd の $x$2 を pandoc は数式と認めない．
;; 書き出すときに空の HTML コメントをはさむ ($x$<!---->2．html でも tex でも見た目は変わらない)．
;; (tools/oxq-qmd-mathfix.py の後処理と同じこと．org の $x$ の書き方では org がそもそも数式と読まない．)

;;; Code:

(require 'ox-quarto-ext-core)
(require 'ox-md)
(require 'subr-x)

(defun ox-quarto-ext-math--eq-id (element)
  "ELEMENT の #+ATTR_QUARTO: :id か #+NAME: が eq- で始まればそれを返す．"
  (let* ((attr (org-export-read-attribute :attr_quarto element))
         (id (and (plist-get attr :id) (ox-quarto-ext-unquote (plist-get attr :id))))
         (name (org-element-property :name element)))
    (cond ((and id (string-prefix-p "eq-" id)) id)
          ((and name (string-prefix-p "eq-" name)) name))))

(defun ox-quarto-ext-math--unwrap (value)
  "latex 環境の文字列 VALUE を $$ の中に置ける形にする．"
  (let ((v (string-trim value)))
    (setq v (replace-regexp-in-string "[ \t]*\\\\label{[^}]*}[ \t]*\\(\n\\)?" "" v))
    (setq v (replace-regexp-in-string "[ \t]*\\\\\\(?:nonumber\\|notag\\)\\b" "" v))
    (if (string-match
         "\\`\\\\begin{\\([A-Za-z]+\\*?\\)}\\(?:{\\([0-9]+\\)}\\)?\\(\\(?:.\\|\n\\)*\\)\\\\end{\\1}\\'" v)
        (let* ((env (match-string 1 v))
               (arg (match-string 2 v))
               (body (string-trim (match-string 3 v)))
               (base (string-remove-suffix "*" env)))
          (cond ((member base '("equation" "displaymath")) body)
                ((member base '("align" "flalign" "eqnarray"))
                 (format "\\begin{aligned}\n%s\n\\end{aligned}" body))
                ((and (equal base "alignat") arg)
                 (format "\\begin{alignedat}{%s}\n%s\n\\end{alignedat}" arg body))
                ((member base '("gather" "multline"))
                 (format "\\begin{gathered}\n%s\n\\end{gathered}" body))
                (t v)))
      v)))

(defun ox-quarto-ext-latex-environment (latex-environment contents info)
  "名前が eq- の LATEX-ENVIRONMENT を $$ … $$ {#eq-…} にする (他は ox-md のまま)．"
  (let* ((value (org-remove-indentation (org-element-property :value latex-environment)))
         (label (and (string-match "\\\\label{\\(eq-[^}]*\\)}" value) (match-string 1 value)))
         (id (or (ox-quarto-ext-math--eq-id latex-environment) label)))
    (if (and id (plist-get info :with-latex))
        (format "$$\n%s\n$$ {#%s}\n" (ox-quarto-ext-math--unwrap value) id)
      (org-md-latex-environment latex-environment contents info))))

(defun ox-quarto-ext-math-paragraph (paragraph contents info)
  "名前が eq- の段落で中身が $$ … $$ だけなら {#eq-…} を付ける．"
  (let ((text (org-quarto-paragraph paragraph contents info))
        (id (ox-quarto-ext-math--eq-id paragraph)))
    (if (and id (string-match "\\`[ \t\n]*\\(\\$\\$\\(?:.\\|\n\\)*\\$\\$\\)[ \t\n]*\\'" text))
        (format "%s {#%s}\n" (match-string 1 text) id)
      text)))

(defun ox-quarto-ext-latex-fragment (latex-fragment contents info)
  "行内数式の直後が数字なら <!----> をはさむ (pandoc が $x$2 を数式と読まないため)．"
  (let ((out (org-md-latex-fragment latex-fragment contents info)))
    (if (and out
             (string-prefix-p "\\(" (org-element-property :value latex-fragment))
             (zerop (or (org-element-property :post-blank latex-fragment) 0))
             (let ((next (org-export-get-next-element latex-fragment info)))
               (and (stringp next) (string-match-p "\\`[0-9]" next))))
        (concat out "<!---->")
      out)))

(with-eval-after-load 'ox-quarto
  (ox-quarto-ext-set-transcoder 'latex-environment #'ox-quarto-ext-latex-environment)
  (ox-quarto-ext-set-transcoder 'latex-fragment #'ox-quarto-ext-latex-fragment)
  (ox-quarto-ext-set-transcoder 'paragraph #'ox-quarto-ext-math-paragraph))

(provide 'ox-quarto-ext-math)
;;; ox-quarto-ext-math.el ends here
