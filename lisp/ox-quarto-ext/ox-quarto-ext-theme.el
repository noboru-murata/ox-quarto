;;; ox-quarto-ext-theme.el --- #+QUARTO_PALETTE / #+QUARTO_DECK: yaml の theme を org から選ぶ  -*- lexical-binding: t; -*-

;; 講演と講義の yaml は 1 つずつ (_quarto/yaml/talk.yaml，lecture.yaml) にして，
;; 配色と修飾 (deck) は大元の org の行で選ぶ．
;;
;;     #+SETUPFILE: _quarto/org/talk.org
;;     #+QUARTO_PALETTE: lavender       配色: theme の palette-*.scss を palette-lavender.scss に
;;     #+QUARTO_DECK: pin               修飾: deck-pin.scss を theme に足す (空白区切りで複数可)
;;
;; 書き出すとき，QUARTO_FRONTMATTER の yaml を読んで theme の行を書き換え，
;; 書き換えた yaml をそのまま front matter にする (yaml のファイルは変えない)．
;; 書き出した qmd の front matter の先頭に，何を書き換えたかを 1 行のコメントで残す．
;;
;; - QUARTO_PALETTE: theme の `_quarto/scss/palette-<名前>.scss' の行 (1 つだけのはず) の
;;   名前を差し替える．後に書いたものが勝つので，SETUPFILE の後に書けば上書きできる．
;;   `callout-palette:' の行 (pdf / html の callout の色．lib/callout-colors.lua) も同じ名前にする．
;;   report / handout の yaml には theme の行が無く callout-palette: だけがあり，それだけを書き換える．
;; - QUARTO_DECK: `_quarto/scss/deck-<名前>.scss' を，theme にある最後の deck-*.scss の
;;   行の後に書いた順に足す．既にある deck は足さない．SETUPFILE と大元の両方に書けば両方が足される．
;;   _quarto/scss に無く `_quarto/local/deck-<名前>.scss' (git に入れない手元の deck) があればそちらを足す．
;; - 配色ごとの追加の設定は `ox-quarto-ext-palette-rules' (dracula ではコードも dracula 配色に)．
;; - scss のファイルが無い，theme に palette の行が無い，などはエラーにする
;;   (黙って元のまま書き出すと，見た目が変わらない理由が分かりにくい)．
;; - どちらの行も無ければ何もしない (yaml はそのまま)．
;;
;; 表題まわりのキーワード (#+INSTITUTE，#+AUTHOR の \and，#+DATE の文字，#+EMAIL，#+QUARTO_QR など) は
;; ox-quarto-ext-frontmatter.el (2026-11-18 に分けた)．このファイルの options フィルタが theme を書き換えた後に
;; `ox-quarto-ext-frontmatter-options' を呼ぶ．
;;
;; 実装: quarto バックエンドにキーワードを登録し，options フィルタで
;; :quarto-frontmatter (ファイル名) を書き換えた yaml の文字列に置き換える
;; (ox-quarto はファイルとして見つからない値を yaml そのものとして扱う)．

;;; Code:

(require 'ox-quarto-ext-core)
(require 'ox-quarto-ext-format)
(require 'ox-quarto-ext-frontmatter)
(require 'seq)
(require 'subr-x)

(defcustom ox-quarto-ext-palette-rules
  '(("dracula"
     :revealjs ("highlight-style: dracula")))  ; コードの配色も dracula に
                                               ; (表紙の白い幕は oer-revealjs が暗い deck では出さない)
  "配色ごとに theme 以外で変える設定．
要素は (PALETTE :revealjs (\"KEY: VALUE\" ...) :drop (SCSS-NAME ...))．
:revealjs は format の revealjs に置く行 (同じ KEY があれば置き換える)，
:drop は theme から外す `_quarto/scss/SCSS-NAME.scss' の行．"
  :type '(alist :key-type string :value-type plist)
  :group 'ox-quarto-ext)

(defconst ox-quarto-ext--theme-line-re
  "^\\([ \t]*-[ \t]*_quarto/scss/\\)\\([A-Za-z0-9_-]+\\)\\(\\.scss\\)\\(.*\\)$"
  "theme の一覧の `- _quarto/scss/NAME.scss  # …' の行．")

(defun ox-quarto-ext--theme-lines (lines)
  "LINES のうち theme の scss の行の (位置 . 名前) を返す．"
  (let ((i 0) out)
    (dolist (l lines)
      (when (string-match ox-quarto-ext--theme-line-re l)
        (push (cons i (match-string 2 l)) out))
      (setq i (1+ i)))
    (nreverse out)))

(defun ox-quarto-ext--check-scss (name base)
  (let ((f (expand-file-name (format "_quarto/scss/%s.scss" name) base)))
    (unless (file-exists-p f)
      (user-error "ox-quarto-ext: _quarto/scss/%s.scss が無い" name))))

(defconst ox-quarto-ext--callout-palette-re
  "^\\(callout-palette:[ \t]*\\)\\([A-Za-z0-9_-]+\\)\\(.*\\)$"
  "front matter の `callout-palette: NAME  # …' の行 (pdf / html の callout の色．lib/callout-colors.lua)．")

(defun ox-quarto-ext--set-palette (lines palette)
  "theme の palette-*.scss の行と callout-palette: の行を PALETTE にする．
どちらも無ければエラー (talk / lecture は両方か theme だけ，report / handout は callout-palette だけ)．"
  (let ((hits (seq-filter (lambda (p) (string-prefix-p "palette-" (cdr p)))
                          (ox-quarto-ext--theme-lines lines)))
        (cp (seq-position lines nil (lambda (l _) (string-match-p ox-quarto-ext--callout-palette-re l)))))
    (cond ((and (null hits) (null cp))
           (user-error "ox-quarto-ext: yaml に theme の palette-*.scss の行も callout-palette: の行も無い"))
          ((cdr hits)
           (user-error "ox-quarto-ext: yaml の theme に palette-*.scss の行が %d 個ある (1 個のはず)"
                       (length hits))))
    (when hits
      (let* ((i (caar hits)) (l (nth i lines)))
        (string-match ox-quarto-ext--theme-line-re l)
        (setf (nth i lines)
              (concat (match-string 1 l) "palette-" palette (match-string 3 l)
                      (match-string 4 l)))))
    (when cp
      (let ((l (nth cp lines)))
        (string-match ox-quarto-ext--callout-palette-re l)
        (setf (nth cp lines) (concat (match-string 1 l) palette (match-string 3 l)))))
    lines))

(defun ox-quarto-ext--deck-dir (deck base)
  "DECK の scss がある所 (\"scss\" か \"local\")．どちらにも無ければエラー．"
  (let ((f (lambda (dir) (expand-file-name (format "_quarto/%s/deck-%s.scss" dir deck) base))))
    (cond ((file-exists-p (funcall f "scss")) "scss")
          ((file-exists-p (funcall f "local")) "local")
          (t (user-error "ox-quarto-ext: _quarto/scss/deck-%s.scss も _quarto/local/deck-%s.scss も無い" deck deck)))))

(defun ox-quarto-ext--add-deck (lines deck &optional dir)
  (let* ((theme (ox-quarto-ext--theme-lines lines))
         (name (concat "deck-" deck))
         (local (equal dir "local")))
    (if (or (and (not local) (rassoc name theme))
            (and local (seq-some (lambda (l) (string-match-p (format "_quarto/local/%s\\.scss" (regexp-quote name)) l)) lines)))
        lines
      (let ((decks (seq-filter (lambda (p) (string-prefix-p "deck-" (cdr p))) theme)))
        (unless decks
          (user-error "ox-quarto-ext: theme に deck-*.scss の行が無いので %s を置けない" name))
        (let* ((i (car (car (last decks))))
               (l (nth i lines)))
          (string-match ox-quarto-ext--theme-line-re l)
          (append (seq-take lines (1+ i))
                  (list (concat (if local
                                    (replace-regexp-in-string "_quarto/scss/\\'" "_quarto/local/" (match-string 1 l))
                                  (match-string 1 l))
                                name ".scss"))
                  (seq-drop lines (1+ i))))))))

(defun ox-quarto-ext--drop-theme (lines name)
  (seq-remove (lambda (l) (and (string-match ox-quarto-ext--theme-line-re l)
                               (equal (match-string 2 l) name)))
              lines))

(defun ox-quarto-ext--set-revealjs (lines kv)
  "format の revealjs に KV (\"key: value\") を置く．"
  (let* ((key (car (split-string kv ":")))
         (start (seq-position lines nil
                              (lambda (l _) (string-match-p "^  revealjs:[ \t]*$" l)))))
    (unless start
      (user-error "ox-quarto-ext: yaml に format の `  revealjs:' の行が無い"))
    ;; revealjs の中 (字下げ 4 以上が続く範囲) で同じ key を探す
    (let ((i (1+ start)) found)
      (while (and (< i (length lines))
                  (string-match-p "^\\(    \\|[ \t]*$\\)" (nth i lines))
                  (not found))
        (when (string-match-p (format "^    %s:" (regexp-quote key)) (nth i lines))
          (setq found i))
        (setq i (1+ i)))
      (if found
          (progn (setf (nth found lines) (concat "    " kv)) lines)
        (append (seq-take lines (1+ start))
                (list (concat "    " kv))
                (seq-drop lines (1+ start)))))))

(defun ox-quarto-ext-theme-filter (info _backend)
  "#+QUARTO_PALETTE / #+QUARTO_DECK があれば frontmatter の yaml の theme を書き換える．
続けて表題まわりのキーワード (ox-quarto-ext-frontmatter.el) と #+QUARTO_<FORMAT>_OPTIONS (ox-quarto-ext-format.el) を書き出す．"
  (let ((palette (org-string-nw-p (plist-get info :quarto-palette)))
        (decks (split-string (or (plist-get info :quarto-deck) "") "[ \t\n]+" t)))
    (when (or palette decks)
      (let* ((fm (string-trim (or (plist-get info :quarto-frontmatter) "")))
             (input (plist-get info :input-file))
             (base (if input (file-name-directory input) default-directory))
             (file (expand-file-name fm base)))
        (unless (and (string-match-p "\\.ya?ml\\'" fm) (file-exists-p file))
          (user-error "ox-quarto-ext: QUARTO_PALETTE / QUARTO_DECK には QUARTO_FRONTMATTER の yaml ファイルが要る (%s)" fm))
        (let ((lines (split-string (with-temp-buffer
                                     (insert-file-contents file)
                                     (buffer-string))
                                   "\n"))
              (note nil))
          (when palette
            (setq palette (string-trim palette))
            (ox-quarto-ext--check-scss (concat "palette-" palette) base)
            (setq lines (ox-quarto-ext--set-palette lines palette))
            (let ((rule (cdr (assoc palette ox-quarto-ext-palette-rules))))
              (dolist (name (plist-get rule :drop))
                (setq lines (ox-quarto-ext--drop-theme lines name)))
              (when (seq-some (lambda (l) (string-match-p "^  revealjs:[ \t]*$" l)) lines)
                (dolist (kv (plist-get rule :revealjs))   ; report / handout には revealjs が無い
                  (setq lines (ox-quarto-ext--set-revealjs lines kv)))))
            (push (concat "palette " palette) note))
          (dolist (d decks)
            (setq lines (ox-quarto-ext--add-deck lines d (ox-quarto-ext--deck-dir d base))))
          (when decks (push (concat "deck " (string-join decks " ")) note))
          (setq info
                (plist-put info :quarto-frontmatter
                           (concat (format "# ox-quarto-ext: %s を %s から書き換え\n"
                                           (string-join (nreverse note) "，") fm)
                                   (string-join lines "\n")))))))
    (ox-quarto-ext-format-options (ox-quarto-ext-frontmatter-options info))))

(let ((backend (org-export-get-backend 'quarto)))
  (if (null backend)
      (warn "ox-quarto-ext: quarto backend not found; QUARTO_PALETTE / QUARTO_DECK skipped")
    (dolist (opt '((:quarto-palette "QUARTO_PALETTE" nil nil t)
                   (:quarto-deck "QUARTO_DECK" nil nil space)))
      (unless (assq (car opt) (org-export-backend-options backend))
        (push opt (org-export-backend-options backend))))
    (setf (alist-get :filter-options (org-export-backend-filters backend))
          #'ox-quarto-ext-theme-filter)))

(provide 'ox-quarto-ext-theme)
;;; ox-quarto-ext-theme.el ends here
