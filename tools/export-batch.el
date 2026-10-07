;;; export-batch.el --- org → qmd をコマンド行で書き出す  -*- lexical-binding: t; -*-
;;
;; 使い方 (プロジェクトのフォルダで):
;;   emacs --batch -Q -l /path/to/ox-quarto/tools/export-batch.el piml.org [other.org ...]
;; 書き出した qmd は quarto render X.qmd --to revealjs (/ html / typst) で仕上げる．
;;
;; 前提: org (10.0-pre 以降)，org-contrib の ox-extra (:ignore: タグ)，ox-quarto が
;; load-path にあること．下の oxq-*-dir を自分の環境に合わせる (環境変数でも上書きできる)．

(setq load-prefer-newer t)
(defvar oxq-root (file-name-directory (directory-file-name
                                       (file-name-directory (or load-file-name buffer-file-name)))))
(defvar oxq-org-dir         (or (getenv "OXQ_ORG_DIR")         "~/.emacs.d/elpa/org"))
(defvar oxq-org-contrib-dir (or (getenv "OXQ_ORG_CONTRIB_DIR") "~/.emacs.d/elpa/org-contrib"))
(defvar oxq-ox-quarto-dir   (or (getenv "OXQ_OX_QUARTO_DIR")   "~/.emacs.d/site-lisp/ox-quarto"))

(dolist (d (list (expand-file-name "lisp" oxq-org-dir) oxq-org-dir
                 (expand-file-name "lisp" oxq-org-contrib-dir)
                 oxq-ox-quarto-dir
                 (expand-file-name "lisp/ox-quarto-ext" oxq-root)))
  (when (file-directory-p d) (add-to-list 'load-path d)))

(require 'org) (require 'ox)
(require 'ox-extra) (ox-extras-activate '(ignore-headlines))
(require 'ox-quarto) (require 'ox-quarto-ext)
(ox-quarto-ext-install-org-settings)
(setq org-export-with-broken-links t)

(dolist (f command-line-args-left)
  (with-current-buffer (find-file-noselect f)
    (message "exported: %s" (org-quarto-export-to-qmd))))
(setq command-line-args-left nil)
;;; export-batch.el ends here
