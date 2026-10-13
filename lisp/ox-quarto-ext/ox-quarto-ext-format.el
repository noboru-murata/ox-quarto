;;; ox-quarto-ext-format.el --- #+QUARTO_<FORMAT>_OPTIONS を front matter の yaml に書き込む  -*- lexical-binding: t; -*-

;; ox-quarto 本体は #+QUARTO_REVEALJS_OPTIONS: csl:x.csl のような行があると，
;; front matter の yaml (QUARTO_FRONTMATTER．talk.yaml など) の format: の中を
;; 1 行ずつ読み直して組み立て直す (`org-quarto--strip-and-parse-format-block')．
;; その読み方は「    key: value」の 1 行の形しか扱わないので，
;;
;;     format:
;;       revealjs:
;;         theme:
;;           - default
;;           - _quarto/scss/oerreveal.scss
;;
;; のリストの行 (- …) と行末のコメントが落ち，theme: や include-in-header: が
;; 空になって Quarto が止まる (Field "theme" has empty value)．
;;
;; そこで，front matter の yaml があるときはこちらで書き込む:
;;   - #+QUARTO_<FORMAT>_OPTIONS: key:value … の各 key を format: の <format>: の中に
;;     「    key: value」として置く．同じ key があれば (リストの値ごと) 置き換え，無ければ足す．
;;     format: や <format>: が無ければ作る．ほかの行 (リスト・コメント) には触れない．
;;   - 書き込んだ行は parse tree から外し，本体の読み直しを通らないようにする．
;; front matter の yaml が無い (QUARTO_FRONTMATTER を書かない) ときは本体に任せる．
;; key:value の区切り方は本体と同じ (`org-quarto--parse-opts-str-to-alist'．[a, b] も可)．
;; 書き込んだことは qmd の front matter の先頭に 1 行のコメントで残す．

;;; Code:

(require 'ox-quarto-ext-core)
(require 'subr-x)
(require 'seq)

(declare-function org-quarto--parse-opts-str-to-alist "ox-quarto" (opts-str))

(defconst ox-quarto-ext-format--keyword-re
  "\\`QUARTO_\\([A-Z0-9][A-Z0-9-]*\\)_OPTIONS\\'"
  "#+QUARTO_<FORMAT>_OPTIONS のキーワード名 (#+QUARTO_OPTIONS は含まない)．")

(defun ox-quarto-ext-format--collect ()
  "いまのバッファの #+QUARTO_<FORMAT>_OPTIONS を ((FORMAT . \"k:v …\") …) で返す (書いた順)．"
  (let ((case-fold-search t) out)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward
              "^[ \t]*#\\+QUARTO_\\([A-Za-z0-9][A-Za-z0-9-]*\\)_OPTIONS:[ \t]*\\(.*\\)$" nil t)
        (let* ((fmt (downcase (match-string-no-properties 1)))
               (val (string-trim (match-string-no-properties 2)))
               (cell (assoc fmt out)))
          (unless (string-prefix-p "#" (string-trim-left
                                        (buffer-substring (line-beginning-position)
                                                          (match-beginning 0))))
            (if cell
                (setcdr cell (concat (cdr cell) " " val))
              (push (cons fmt val) out))))))
    (nreverse out)))

(defun ox-quarto-ext-format--indent (line)
  "LINE の先頭の空白の数．空行・コメントだけの行は nil．"
  (unless (string-match-p "\\`[ \t]*\\(#.*\\)?\\'" line)
    (string-match "\\`[ ]*" line)
    (match-end 0)))

(defun ox-quarto-ext-format--block-end (lines start min-indent)
  "START の次から，字下げが MIN-INDENT 以上 (か空行・コメント) の行が続く範囲の終わり (次の行の位置)．
末尾の空行・コメントは範囲に含めない．"
  (let ((i (1+ start)) (last start))
    (while (and (< i (length lines))
                (let ((ind (ox-quarto-ext-format--indent (nth i lines))))
                  (or (null ind) (>= ind min-indent))))
      (when (ox-quarto-ext-format--indent (nth i lines)) (setq last i))
      (setq i (1+ i)))
    (1+ last)))

(defun ox-quarto-ext-format--find (lines re from to)
  "FROM から TO の前までで RE に合う最初の行の位置．"
  (let ((i from) found)
    (while (and (< i to) (not found))
      (when (string-match-p re (nth i lines)) (setq found i))
      (setq i (1+ i)))
    found))

(defun ox-quarto-ext-format--set (lines fmt key value)
  "yaml の行 LINES の format: の FMT: に「    KEY: VALUE」を置いた行を返す．"
  (let* ((n (length lines))
         (f (ox-quarto-ext-format--find lines "\\`format:[ \t]*\\(#.*\\)?\\'" 0 n)))
    (unless f
      (setq lines (append lines (list "format:")) f (length lines) n f
            f (1- f)))
    (let* ((fend (ox-quarto-ext-format--block-end lines f 1))
           (g (ox-quarto-ext-format--find
               lines (format "\\`  %s:[ \t]*\\(#.*\\)?\\'" (regexp-quote fmt)) (1+ f) fend)))
      (unless g
        (setq lines (append (seq-take lines fend) (list (format "  %s:" fmt)) (seq-drop lines fend))
              g fend))
      (let* ((gend (ox-quarto-ext-format--block-end lines g 3))
             (k (ox-quarto-ext-format--find
                 lines (format "\\`    %s:" (regexp-quote key)) (1+ g) gend))
             (new (format "    %s: %s" key value)))
        (if k
            ;; key の値の続き (字下げ 5 以上の行と，字下げ 4 の「- 」の行) ごと置き換える
            (let ((kend (1+ k)))
              (while (and (< kend gend)
                          (let ((l (nth kend lines)))
                            (or (string-match-p "\\`[ ]\\{5,\\}[^ ]" l)
                                (string-match-p "\\`    - " l)
                                (string-match-p "\\`[ \t]*\\'" l))))
                (setq kend (1+ kend)))
              (append (seq-take lines k) (list new) (seq-drop lines kend)))
          (append (seq-take lines gend) (list new) (seq-drop lines gend)))))))

(defun ox-quarto-ext-format--frontmatter-text (info)
  "INFO の :quarto-frontmatter を yaml の文字列で返す (ファイル名なら中身)．無ければ nil．"
  (let* ((fm (plist-get info :quarto-frontmatter))
         (input (plist-get info :input-file))
         (base (if input (file-name-directory input) default-directory)))
    (when (org-string-nw-p fm)
      (let ((file (and (string-match-p "\\.ya?ml\\'" (string-trim fm))
                       (expand-file-name (string-trim fm) base))))
        (if (and file (file-exists-p file))
            (with-temp-buffer (insert-file-contents file) (buffer-string))
          fm)))))

(defun ox-quarto-ext-format-options (info)
  "#+QUARTO_<FORMAT>_OPTIONS を front matter の yaml に書き込んだ INFO を返す (options フィルタから)．"
  (let ((opts (ox-quarto-ext-format--collect))
        (text (ox-quarto-ext-format--frontmatter-text info)))
    (when (and opts text)
      (let ((lines (split-string text "\n")) (note '()))
        (dolist (o opts)
          (let ((kvs (org-quarto--parse-opts-str-to-alist (cdr o))))
            (dolist (kv kvs)
              (setq lines (ox-quarto-ext-format--set lines (car o) (car kv) (cdr kv))))
            (when kvs
              (push (format "%s (%s)" (car o) (mapconcat #'car kvs " ")) note))))
        (setq info (plist-put info :quarto-frontmatter
                              (concat (format "# ox-quarto-ext: QUARTO_<FORMAT>_OPTIONS を format: に書き込み: %s\n"
                                              (string-join (nreverse note) "，"))
                                      (string-join lines "\n"))))
        (setq info (plist-put info :ox-quarto-ext-format-done t)))))
  info)

(defun ox-quarto-ext-format-drop-keywords (tree _backend info)
  "書き込んだ #+QUARTO_<FORMAT>_OPTIONS を TREE から外す (本体が読み直さないように)．"
  (when (plist-get info :ox-quarto-ext-format-done)
    (org-element-map tree 'keyword
      (lambda (kw)
        (when (string-match-p ox-quarto-ext-format--keyword-re (org-element-property :key kw))
          (org-element-extract-element kw)))))
  tree)

(let ((backend (org-export-get-backend 'quarto)))
  (when backend
    (let* ((cell (assq :filter-parse-tree (org-export-backend-filters backend)))
           (old (cdr cell))
           (fns (if (functionp old) (list old) old)))
      (unless (memq #'ox-quarto-ext-format-drop-keywords fns)
        (setf (alist-get :filter-parse-tree (org-export-backend-filters backend))
              (cons #'ox-quarto-ext-format-drop-keywords fns))))))

(provide 'ox-quarto-ext-format)
;;; ox-quarto-ext-format.el ends here
