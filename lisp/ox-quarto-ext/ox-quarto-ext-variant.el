;;; ox-quarto-ext-variant.el --- #+QUARTO_VARIANT: frontmatter の yaml の別版を選ぶ  -*- lexical-binding: t; -*-

;; SETUPFILE (例 _quarto/org/talk-jade.org) は
;;
;;     #+QUARTO_FRONTMATTER: _quarto/yaml/talk-jade.yaml
;;
;; で yaml を 1 つ読む．大元の org に
;;
;;     #+QUARTO_VARIANT: pin
;;
;; と書くと，同じフォルダの別版 _quarto/yaml/talk-jade-pin.yaml を読む
;; (<名前>.yaml → <名前>-<variant>.yaml)．SETUPFILE の行はそのままでよく，
;; 配色の選択 (どの SETUPFILE を有効にするか) と別版の選択を独立に切り替えられる．
;;
;; - 行が無い，あるいは値が空なら元の yaml を読む．
;; - 別版の yaml が無ければエラーにする (黙って元の yaml を使うと，
;;   見た目が変わらない理由が分かりにくい)．
;; - QUARTO_FRONTMATTER が yaml ファイルでない (yaml を直接書いた) 場合もエラー．
;;
;; 実装: quarto バックエンドに QUARTO_VARIANT を登録し，options フィルタで
;; :quarto-frontmatter のファイル名を差し替える．ox-quarto 本体には手を入れない．

;;; Code:

(require 'ox-quarto-ext-core)

(defun ox-quarto-ext-variant-file (file variant)
  "FILE (foo.yaml) の VARIANT 版のファイル名 (foo-VARIANT.yaml) を返す。"
  (concat (file-name-sans-extension file) "-" variant
          "." (file-name-extension file)))

(defun ox-quarto-ext-variant-filter (info _backend)
  "#+QUARTO_VARIANT があれば INFO の :quarto-frontmatter を別版にする。"
  (let ((variant (org-string-nw-p (plist-get info :quarto-variant))))
    (when variant
      (let* ((variant (string-trim variant))
             (fm (string-trim (or (plist-get info :quarto-frontmatter) "")))
             (input (plist-get info :input-file))
             (base (if input (file-name-directory input) default-directory)))
        (unless (string-match-p "\\.ya?ml\\'" fm)
          (user-error "QUARTO_VARIANT %s: QUARTO_FRONTMATTER が yaml ファイルでない (%s)"
                      variant fm))
        (let ((new (ox-quarto-ext-variant-file fm variant)))
          (unless (file-exists-p (expand-file-name new base))
            (user-error "QUARTO_VARIANT %s: %s が無い" variant new))
          (setq info (plist-put info :quarto-frontmatter new))))))
  info)

(let ((backend (org-export-get-backend 'quarto)))
  (if (null backend)
      (warn "ox-quarto-ext: quarto backend not found; QUARTO_VARIANT skipped")
    (unless (assq :quarto-variant (org-export-backend-options backend))
      (push '(:quarto-variant "QUARTO_VARIANT" nil nil t)
            (org-export-backend-options backend)))
    (setf (alist-get :filter-options (org-export-backend-filters backend))
          #'ox-quarto-ext-variant-filter)))

(provide 'ox-quarto-ext-variant)
;;; ox-quarto-ext-variant.el ends here
