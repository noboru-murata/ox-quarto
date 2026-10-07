;;; ox-quarto-ext-core.el --- shared helpers for ox-quarto extensions  -*- lexical-binding: t; -*-

;; ox-quarto (https://github.com/jrgant/ox-quarto) を Quarto の機能に合わせて
;; 補強する一連の設定の土台。各機能ファイルはこれを require する。
;;
;; 設計方針
;; --------
;; 補強はすべて **quarto バックエンドのトランスコーダ** として登録する。
;; `org-md-headline' や `org-md-export-block' のような ox-md の関数に
;; advice を足すと、ox-md での書き出しにも影響するうえ、同じ処理を行う
;; 設定が二重に走ったときに属性が 2 回付くといった事故が起きる。
;; ox-quarto 自身の内部関数 (org-quarto--...) にだけは advice を使う。

;;; Code:

(require 'ox)

(defgroup ox-quarto-ext nil
  "ox-quarto の出力を Quarto の記法に合わせるための拡張。"
  :group 'org-export
  :prefix "ox-quarto-ext-")

(defun ox-quarto-ext-set-transcoder (type function)
  "quarto バックエンドの TYPE 用トランスコーダを FUNCTION に差し替える。
既に登録されていれば上書きするので、二重に適用される心配はない。"
  (let ((backend (org-export-get-backend 'quarto)))
    (if (null backend)
        (warn "ox-quarto-ext: quarto backend not found; %s skipped" type)
      (setf (alist-get type (org-export-backend-transcoders backend))
            function))))

(defun ox-quarto-ext-unquote (s)
  "S の前後を囲む二重引用符を 1 段だけ外す。"
  (if (and (stringp s) (string-match "\\`\"\\(.*\\)\"\\'" s))
      (match-string 1 s)
    s))

(defun ox-quarto-ext-keyword-name (key)
  "プロパティリストのキー KEY (:width など) から先頭のコロンを落とす。"
  (substring (symbol-name key) 1))

(defun ox-quarto-ext-plist-remove (plist key)
  "PLIST から KEY とその値を取り除いた新しいプロパティリストを返す。"
  (let (out)
    (while plist
      (unless (eq (car plist) key)
        (setq out (append out (list (car plist) (cadr plist)))))
      (setq plist (cddr plist)))
    out))

(provide 'ox-quarto-ext-core)
;;; ox-quarto-ext-core.el ends here
