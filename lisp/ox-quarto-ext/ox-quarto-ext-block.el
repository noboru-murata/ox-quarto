;;; ox-quarto-ext-block.el --- #+begin_... blocks for ox-quarto  -*- lexical-binding: t; -*-

;; `#+begin_...' で書くブロック 2 種類の面倒を見る。
;;
;; ■ 特殊ブロック (::: {.class}) の引用符
;;
;;   ox-quarto の特殊ブロックは属性を 2 通りの書き方で受け取る。
;;
;;     #+begin_scroll :class "fig-tall extra"      ← インラインパラメータ
;;     #+ATTR_QUARTO: :class "fig-tall extra"      ← ATTR_QUARTO
;;
;;   インライン側は `org-quarto--parse-parameters' が引用符を外すが、
;;   ATTR_QUARTO 側は `org-export-read-attribute' が値をそのまま渡すので
;;   引用符が残って壊れる。
;;
;;     ::: {.scroll ."fig-tall .extra"}
;;     ::: {.scroll style=""color: red""}
;;
;;   div ヘッダを組み立てる直前に引用符を落として、どちらの書き方でも
;;   正しく展開されるようにする。これは ox-quarto 自身の内部関数への
;;   advice なので、他のバックエンドには影響しない。
;;
;; ■ #+begin_export latex
;;
;;   ox-quarto は export block のうち MARKDOWN と HTML しか通さず、
;;
;;     #+begin_export latex
;;     \figfitboth
;;     #+end_export
;;
;;   は何も出力せずに消える（`org-md-export-block' が markdown 以外を
;;   ox-html に回し、ox-html は HTML 以外で nil を返すため）。
;;   これを Quarto の raw block に変換する。
;;
;;     ```{=latex}
;;     \figfitboth
;;     ```
;;
;;   pdf 出力ではそのまま LaTeX として展開され、revealjs や html では
;;   pandoc が無視するので、同じ org ファイルを両方に使える。
;;   MARKDOWN / HTML の export block は従来どおり ox-md に渡す。

;;; Code:

(require 'cl-lib)
(require 'ox-md)
(require 'ox-quarto-ext-core)

(declare-function org-quarto--build-div-header "ox-quarto" (type id classes attrs))

;;; 特殊ブロック: #+ATTR_QUARTO: の引用符を落とす

(defun ox-quarto-ext-block--unquote-args (args)
  "Strip quotes from the id, class list and attribute values in ARGS."
  (let ((block-type (nth 0 args))
        (id         (ox-quarto-ext-unquote (nth 1 args)))
        (classes    (ox-quarto-ext-unquote (nth 2 args)))
        (attrs      (nth 3 args)))
    (list block-type id classes
          (cl-loop for (k v) on attrs by #'cddr
                   append (list k (ox-quarto-ext-unquote v))))))

;;; export block: latex を ```{=latex} にする

(defcustom ox-quarto-ext-raw-types '("LATEX" "TEX")
  "Quarto の raw block に変換する export block の種類。"
  :type '(repeat string)
  :group 'ox-quarto-ext)

(defun ox-quarto-ext-export-block (export-block contents info)
  "Turn a LaTeX EXPORT-BLOCK into a Quarto ```{=latex} raw block."
  (if (member (org-element-property :type export-block)
              ox-quarto-ext-raw-types)
      (concat "```{=latex}\n"
              (org-remove-indentation (org-element-property :value export-block))
              "```")
    (org-md-export-block export-block contents info)))

(with-eval-after-load 'ox-quarto
  (advice-add 'org-quarto--build-div-header :filter-args
              #'ox-quarto-ext-block--unquote-args)
  (ox-quarto-ext-set-transcoder 'export-block #'ox-quarto-ext-export-block))

(provide 'ox-quarto-ext-block)
;;; ox-quarto-ext-block.el ends here
