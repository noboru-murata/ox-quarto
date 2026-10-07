;;; ox-quarto-ext-src.el --- chunk options & fence kind for src blocks  -*- lexical-binding: t; -*-

;; ox-quarto の `org-quarto-src-block' は言語名とコード本体しか見ないため、
;; 次の 2 つの問題がある。
;;
;;   1. Org のヘッダ引数が qmd に渡らないので、Quarto のチャンクオプション
;;      (#| echo: true など) を書けない
;;   2. 言語を問わず必ず ```{lang} という実行チャンクで出力するので、
;;      #+begin_src yaml のような表示目的のブロックでも knitr が実行しようと
;;      して警告が出る
;;
;;        Warning message:
;;        In get_engine(options$engine) :
;;          Unknown language engine 'yaml' (must be registered via knit_engines$set()).
;;
;; ■ チャンクオプション
;;
;;     #+name: fig-scatter
;;     #+ATTR_QUARTO: :echo true :eval false :fig-cap "散布図" :fig-height 5
;;     #+begin_src R
;;     plot(x, y)
;;     #+end_src
;;
;;   ->  ```{r}
;;       #| label: fig-scatter
;;       #| echo: true
;;       #| eval: false
;;       #| fig-cap: "散布図"
;;       #| fig-height: 5
;;       plot(x, y)
;;       ```
;;
;;   * `#+name:' は `#| label:' になる（`:label' を明示すればそちらが優先）
;;   * 値はそのまま YAML として流れるので、空白を含む文字列は
;;     `:fig-cap "散布図"' のように引用符ごと渡す
;;   * コード本体に直接書いた `#|' 行も従来どおり通る
;;
;; ■ 実行チャンク / 表示のみ の振り分け
;;
;;   `ox-quarto-ext-executable-languages' に入っている言語だけが ```{lang}
;;   になり、それ以外は ```lang（ハイライト付きの表示専用ブロック）になる。
;;   yaml, elisp, json, latex などはこちら。
;;
;;     #+ATTR_QUARTO: :exec yes :echo false     ; 強制的に実行チャンク
;;     #+ATTR_QUARTO: :exec no                  ; 強制的に表示のみ
;;
;;   :exec 自体は #| には出力されない。

;;; Code:

(require 'cl-lib)
(require 'ox)
(require 'ox-quarto-ext-core)

(defcustom ox-quarto-ext-executable-languages
  '("r" "python" "julia" "ojs" "mermaid" "dot")
  "実行チャンク (```{lang}) として書き出す言語。
ここに無い言語は ```lang となり、knitr が評価しようとしない。
ブロック単位の上書きは `#+ATTR_QUARTO: :exec yes' / `:exec no'。"
  :type '(repeat string)
  :group 'ox-quarto-ext)

(defconst ox-quarto-ext-src--truthy '("yes" "t" "true" "on"))
(defconst ox-quarto-ext-src--falsy  '("no" "nil" "false" "off"))

(defun ox-quarto-ext-src-block (src-block _contents info)
  "Transcode SRC-BLOCK, honouring #+ATTR_QUARTO: options and :exec."
  (let* ((lang  (downcase (org-element-property :language src-block)))
         (attrs (org-export-read-attribute :attr_quarto src-block))
         (exec  (plist-get attrs :exec))
         (name  (org-element-property :name src-block))
         (execp (cond ((member exec ox-quarto-ext-src--truthy) t)
                      ((member exec ox-quarto-ext-src--falsy)  nil)
                      (t (member lang ox-quarto-ext-executable-languages))))
         (opts  '()))
    ;; :exec は自前の指定なので出力しない
    (setq attrs (ox-quarto-ext-plist-remove attrs :exec))
    ;; #| は実行チャンクの中でしか意味を持たない
    (when execp
      (when (and name (org-string-nw-p name) (not (plist-get attrs :label)))
        (push (format "#| label: %s" name) opts))
      (cl-loop for (key val) on attrs by #'cddr
               do (push (format "#| %s: %s"
                                (ox-quarto-ext-keyword-name key) val)
                        opts)))
    (concat "```" (if execp (concat "{" lang "}") lang) "\n"
            (when opts
              (concat (mapconcat #'identity (nreverse opts) "\n") "\n"))
            (org-export-format-code-default src-block info)
            "```")))

(with-eval-after-load 'ox-quarto
  (ox-quarto-ext-set-transcoder 'src-block #'ox-quarto-ext-src-block))

(provide 'ox-quarto-ext-src)
;;; ox-quarto-ext-src.el ends here
