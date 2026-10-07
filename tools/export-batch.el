;;; export-batch.el --- org → qmd をコマンド行で書き出す  -*- lexical-binding: t; -*-
;;
;; 使い方 (プロジェクトのフォルダで):
;;   emacs --batch -Q -l /path/to/ox-quarto/tools/export-batch.el piml.org [other.org ...]
;; 書き出した qmd は quarto render X.qmd --to revealjs (/ html / typst) で仕上げる．
;;
;; 前提: org (10.0-pre 以降)，org-contrib の ox-extra (:ignore: タグ)．
;; ox-quarto 本体は submodule (lisp/ox-quarto) を使う (git submodule update --init)．
;; org と org-contrib は straight の build (~/.emacs.d/straight/build/) を既定にしている．
;; 違う場所なら下の oxq-*-dir を直すか，環境変数 OXQ_ORG_DIR / OXQ_ORG_CONTRIB_DIR /
;; OXQ_OX_QUARTO_DIR で上書きする．

(setq load-prefer-newer t)
(defvar oxq-root (file-name-directory (directory-file-name
                                       (file-name-directory (or load-file-name buffer-file-name)))))
(defvar oxq-org-dir         (or (getenv "OXQ_ORG_DIR")         "~/.emacs.d/straight/build/org"))
(defvar oxq-org-contrib-dir (or (getenv "OXQ_ORG_CONTRIB_DIR") "~/.emacs.d/straight/build/org-contrib"))
(defvar oxq-ox-quarto-dir   (or (getenv "OXQ_OX_QUARTO_DIR")
                                (expand-file-name "lisp/ox-quarto" oxq-root)))

(dolist (d (list (expand-file-name "lisp" oxq-org-dir) oxq-org-dir
                 (expand-file-name "lisp" oxq-org-contrib-dir) oxq-org-contrib-dir
                 oxq-ox-quarto-dir
                 (expand-file-name "lisp/ox-quarto-ext" oxq-root)))
  (when (file-directory-p d) (add-to-list 'load-path d)))

(unless (file-directory-p oxq-org-dir)
  (message "注意: %s が無いので Emacs 同梱の org を使う (OXQ_ORG_DIR で指定できる)" oxq-org-dir))
(require 'org) (require 'ox)
(message "org %s (%s)" (org-version) (file-name-directory (locate-library "org")))
(require 'ox-extra) (ox-extras-activate '(ignore-headlines))
(unless (locate-library "ox-quarto")
  (error "ox-quarto が見つからない: %s (git submodule update --init を実行する)" oxq-ox-quarto-dir))
(require 'ox-quarto) (require 'ox-quarto-ext)
(ox-quarto-ext-install-org-settings)
(setq org-export-with-broken-links t)

(dolist (f command-line-args-left)
  (with-current-buffer (find-file-noselect f)
    (message "exported: %s" (org-quarto-export-to-qmd))))
(setq command-line-args-left nil)
;;; export-batch.el ends here
