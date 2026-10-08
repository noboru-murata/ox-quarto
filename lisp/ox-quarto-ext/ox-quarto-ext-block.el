;;; ox-quarto-ext-block.el --- #+begin_... blocks for ox-quarto  -*- lexical-binding: t; -*-

;; `#+begin_...' で書くブロックの面倒を見る。
;;
;; ■ 特殊ブロック (::: {.class}) の :title
;;
;;   ox-quarto 本体の `org-quarto-special-block' は、どの特殊ブロックでも
;;   :title を div の中の「## 見出し」にし、div の属性からは外す。callout
;;   ではそれが見出しになるので正しいが、title を属性として読むブロック
;;   (iframe.lua の iframe の title など) には届かず、div の中に余計な
;;   見出しが入る。そこで特殊ブロックのトランスコーダを差し替え、
;;
;;     callout / callout-*   →  ## 見出し (従来どおり)
;;     それ以外               →  属性 title="…"
;;
;;     #+begin_callout-note :title "定義"      →  ::: {.callout-note}
;;                                                 ## 定義
;;     #+begin_iframe :src "x.html" :title "デモ"  →  ::: {.iframe src="x.html" title="デモ"}
;;
;;   属性の値の \ と " は \\ と \" にして、見出し行が壊れないようにする
;;   (Pandoc の属性の構文で読める)。
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
;;   正しく展開されるようにする (上のトランスコーダの中で行う)。
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

;;; 特殊ブロック: :title の扱いと属性の引用符

(declare-function org-quarto--parse-parameters "ox-quarto" (params-str))

(defun ox-quarto-ext-block--callout-p (block-type)
  "BLOCK-TYPE が callout (callout または callout-note など) なら non-nil。"
  (string-match-p "\\`callout\\(-\\|\\'\\)" block-type))

(defun ox-quarto-ext-block--plain-value (v)
  "属性の値 V から文字列そのものを取り出す。
#+ATTR_QUARTO: の値は \"…\" のまま渡ってくるので外側の引用符を外し、
中の \\\" や \\\\ (org での書き方) を \" と \\ に戻す。"
  (let ((raw (format "%s" v)))
    (if (string-match "\\`\"\\(.*\\)\"\\'" raw)
        (replace-regexp-in-string "\\\\\\(.\\)" "\\1" (match-string 1 raw))
      raw)))

(defun ox-quarto-ext-block--attr-value (v)
  "属性の値 V を Pandoc の \"…\" の中に書ける形にする (\\ と \" をエスケープ)。"
  (replace-regexp-in-string
   "\"" "\\\""
   (replace-regexp-in-string "\\\\" "\\\\"
                             (ox-quarto-ext-block--plain-value v) t t)
   t t))

(defun ox-quarto-ext-block--div-header (block-type id classes attrs skip)
  "Quarto の div の見出し行 ::: {#ID .BLOCK-TYPE .CLASSES key=\"value\"} を作る。
ATTRS のうち :id :class と SKIP に挙げたキーは属性にしない。"
  (let ((parts '())
        (id (ox-quarto-ext-unquote id))
        (classes (ox-quarto-ext-unquote classes)))
    (when (org-string-nw-p id) (push (concat "#" id) parts))
    (push (concat "." block-type) parts)
    (when (org-string-nw-p classes)
      (dolist (cls (split-string classes "[ \t]+" t))
        (push (concat "." cls) parts)))
    (cl-loop for (k v) on attrs by #'cddr
             unless (memq k (append '(:id :class) skip))
             do (push (format "%s=\"%s\"" (ox-quarto-ext-keyword-name k)
                              (ox-quarto-ext-block--attr-value v))
                      parts))
    (concat "::: {" (mapconcat #'identity (nreverse parts) " ") "}")))

(defun ox-quarto-ext-special-block (special-block contents _info)
  "SPECIAL-BLOCK を Quarto の div にする (`org-quarto-special-block' の置き換え)。
属性は #+ATTR_QUARTO: と #+begin_ 行のパラメータから取る (後者が優先)。
:title は callout では div の中の ## 見出しに、それ以外では属性 title にする。"
  (let* ((block-type (org-element-property :type special-block))
         (attr-quarto (org-export-read-attribute :attr_quarto special-block))
         (inline (org-quarto--parse-parameters
                  (org-element-property :parameters special-block)))
         (attrs (let ((merged (copy-sequence attr-quarto)))
                  (cl-loop for (k v) on inline by #'cddr
                           do (setq merged (plist-put merged k v)))
                  merged))
         (callout (ox-quarto-ext-block--callout-p block-type))
         (title (and callout (plist-get attrs :title)))
         (header (ox-quarto-ext-block--div-header
                  block-type (plist-get attrs :id) (plist-get attrs :class)
                  attrs (and callout '(:title)))))
    (concat header "\n"
            (when (org-string-nw-p title)
              (concat "## " (ox-quarto-ext-block--plain-value title) "\n"))
            ;; div の中の見出しが効くよう \# を戻す (本体と同じ)
            (replace-regexp-in-string "\\\\#" "#" (or contents ""))
            ":::\n")))

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
  ;; 以前の版は org-quarto--build-div-header に advice で引用符を外していた．
  ;; 特殊ブロックは下のトランスコーダが組み立てるので，残っていれば外す
  (when (fboundp 'ox-quarto-ext-block--unquote-args)
    (advice-remove 'org-quarto--build-div-header #'ox-quarto-ext-block--unquote-args))
  (ox-quarto-ext-set-transcoder 'special-block #'ox-quarto-ext-special-block)
  (ox-quarto-ext-set-transcoder 'export-block #'ox-quarto-ext-export-block))

(provide 'ox-quarto-ext-block)
;;; ox-quarto-ext-block.el ends here
