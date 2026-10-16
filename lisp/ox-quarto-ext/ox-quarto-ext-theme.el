;;; ox-quarto-ext-theme.el --- #+QUARTO_PALETTE / #+QUARTO_DECK / #+INSTITUTE / #+QUARTO_QR: front matter を org から整える  -*- lexical-binding: t; -*-

;; 講演と講義の yaml は 1 つずつ (_quarto/yaml/talk.yaml，lecture.yaml) にして，
;; 配色と修飾 (deck) は大元の org の行で選ぶ．
;;
;;     #+SETUPFILE: _quarto/org/talk.org
;;     #+QUARTO_PALETTE: lavender       配色: theme の *-palette.scss を lavender-palette.scss に
;;     #+QUARTO_DECK: pin               修飾: pin-deck.scss を theme に足す (空白区切りで複数可)
;;
;; 書き出すとき，QUARTO_FRONTMATTER の yaml を読んで theme の行を書き換え，
;; 書き換えた yaml をそのまま front matter にする (yaml のファイルは変えない)．
;; 書き出した qmd の front matter の先頭に，何を書き換えたかを 1 行のコメントで残す．
;;
;; - QUARTO_PALETTE: theme の `_quarto/scss/<名前>-palette.scss' の行 (1 つだけのはず) の
;;   名前を差し替える．後に書いたものが勝つので，SETUPFILE の後に書けば上書きできる．
;;   `callout-palette:' の行 (pdf / html の callout の色．lib/callout-colors.lua) も同じ名前にする．
;;   report / handout の yaml には theme の行が無く callout-palette: だけがあり，それだけを書き換える．
;; - QUARTO_DECK: `_quarto/scss/<名前>-deck.scss' を，theme にある最後の *-deck.scss の
;;   行の後に書いた順に足す．既にある deck は足さない．SETUPFILE と大元の両方に書けば両方が足される．
;; - 配色ごとの追加の設定は `ox-quarto-ext-palette-rules' (dracula ではコードも dracula 配色に，
;;   表紙の title-bg は外す)．
;; - scss のファイルが無い，theme に palette の行が無い，などはエラーにする
;;   (黙って元のまま書き出すと，見た目が変わらない理由が分かりにくい)．
;; - どちらの行も無ければ何もしない (yaml はそのまま)．
;;
;; #+INSTITUTE: (beamer と同じ書き方) は表紙の所属として front matter の institute: に書き出す
;; (ox-quarto 本体は書き出さない)．行を重ねれば所属の一覧 (yaml のリスト) になる．Quarto は
;; institute を著者の所属 (.quarto-title-affiliation) として氏名の下に出す．
;;
;; #+QUARTO_QR: (画像のパス) と #+QUARTO_QR_CAPTION: (画像の下の短い文．URL ならリンク) は
;; front matter の title-qr: に書き出す．表紙の右下に置くのは _quarto/lib/title-qr.lua
;; (講演の版の頁の QR コードを想定．画像は tools/oxq-qr.py で作れる)．
;;
;; 実装: quarto バックエンドにキーワードを登録し，options フィルタで
;; :quarto-frontmatter (ファイル名) を書き換えた yaml の文字列に置き換える
;; (ox-quarto はファイルとして見つからない値を yaml そのものとして扱う)．

;;; Code:

(require 'ox-quarto-ext-core)
(require 'ox-quarto-ext-format)
(require 'seq)
(require 'subr-x)

(defcustom ox-quarto-ext-palette-rules
  '(("dracula"
     :revealjs ("highlight-style: dracula")   ; コードの配色も dracula に
     :drop ("title-bg")))                     ; 暗い表紙に白い幕を掛けない
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
  "theme の *-palette.scss の行と callout-palette: の行を PALETTE にする．
どちらも無ければエラー (talk / lecture は両方か theme だけ，report / handout は callout-palette だけ)．"
  (let ((hits (seq-filter (lambda (p) (string-suffix-p "-palette" (cdr p)))
                          (ox-quarto-ext--theme-lines lines)))
        (cp (seq-position lines nil (lambda (l _) (string-match-p ox-quarto-ext--callout-palette-re l)))))
    (cond ((and (null hits) (null cp))
           (user-error "ox-quarto-ext: yaml に theme の *-palette.scss の行も callout-palette: の行も無い"))
          ((cdr hits)
           (user-error "ox-quarto-ext: yaml の theme に *-palette.scss の行が %d 個ある (1 個のはず)"
                       (length hits))))
    (when hits
      (let* ((i (caar hits)) (l (nth i lines)))
        (string-match ox-quarto-ext--theme-line-re l)
        (setf (nth i lines)
              (concat (match-string 1 l) palette "-palette" (match-string 3 l)
                      (match-string 4 l)))))
    (when cp
      (let ((l (nth cp lines)))
        (string-match ox-quarto-ext--callout-palette-re l)
        (setf (nth cp lines) (concat (match-string 1 l) palette (match-string 3 l)))))
    lines))

(defun ox-quarto-ext--add-deck (lines deck)
  (let* ((theme (ox-quarto-ext--theme-lines lines))
         (name (concat deck "-deck")))
    (if (rassoc name theme)
        lines
      (let ((decks (seq-filter (lambda (p) (string-suffix-p "-deck" (cdr p))) theme)))
        (unless decks
          (user-error "ox-quarto-ext: theme に *-deck.scss の行が無いので %s を置けない" name))
        (let* ((i (car (car (last decks))))
               (l (nth i lines)))
          (string-match ox-quarto-ext--theme-line-re l)
          (append (seq-take lines (1+ i))
                  (list (concat (match-string 1 l) name ".scss"))
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

(defun ox-quarto-ext--yaml-string (s)
  "S を yaml の二重引用符の文字列にする．"
  (concat "\"" (replace-regexp-in-string "[\"\\]" (lambda (c) (concat "\\" c)) s t t) "\""))

(defun ox-quarto-ext--prepend-frontmatter (info text)
  "front matter の先頭に TEXT (yaml の行) を足した INFO を返す．
QUARTO_FRONTMATTER が yaml のファイル名なら中身を読んでから足す．"
  (let* ((fm (or (plist-get info :quarto-frontmatter) ""))
         (input (plist-get info :input-file))
         (base (if input (file-name-directory input) default-directory))
         (file (and (string-match-p "\\.ya?ml\\'" (string-trim fm))
                    (expand-file-name (string-trim fm) base)))
         (body (cond ((and file (file-exists-p file))
                      (with-temp-buffer (insert-file-contents file) (buffer-string)))
                     (t fm))))
    (plist-put info :quarto-frontmatter
               (if (org-string-nw-p body) (concat text "\n" body) text))))

(defun ox-quarto-ext--add-institute (info)
  "#+INSTITUTE があれば front matter の先頭に institute: を足す．"
  (let ((insts (split-string (or (plist-get info :quarto-institute) "") "\n" t "[ \t]+")))
    (when insts
      (setq info (ox-quarto-ext--prepend-frontmatter
                  info
                  (if (cdr insts)
                      (concat "institute:\n"
                              (mapconcat (lambda (x) (concat "  - " (ox-quarto-ext--yaml-string x)))
                                         insts "\n"))
                    (concat "institute: " (ox-quarto-ext--yaml-string (car insts))))))))
  info)

(defun ox-quarto-ext--add-title-qr (info)
  "#+QUARTO_QR があれば front matter の先頭に title-qr: を足す (表紙の QR コード．lib/title-qr.lua)．"
  (let ((image (org-string-nw-p (string-trim (or (plist-get info :quarto-qr) ""))))
        (caption (org-string-nw-p (string-trim (or (plist-get info :quarto-qr-caption) "")))))
    (cond
     (image
      (setq info (ox-quarto-ext--prepend-frontmatter
                  info
                  (concat "title-qr:\n  image: " (ox-quarto-ext--yaml-string image)
                          (if caption
                              (concat "\n  caption: " (ox-quarto-ext--yaml-string caption))
                            "")))))
     (caption
      (user-error "ox-quarto-ext: #+QUARTO_QR_CAPTION には #+QUARTO_QR (画像) が要る"))))
  info)

(defun ox-quarto-ext-theme-filter (info _backend)
  "#+QUARTO_PALETTE / #+QUARTO_DECK があれば frontmatter の yaml の theme を書き換える．"
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
            (ox-quarto-ext--check-scss (concat palette "-palette") base)
            (setq lines (ox-quarto-ext--set-palette lines palette))
            (let ((rule (cdr (assoc palette ox-quarto-ext-palette-rules))))
              (dolist (name (plist-get rule :drop))
                (setq lines (ox-quarto-ext--drop-theme lines name)))
              (when (seq-some (lambda (l) (string-match-p "^  revealjs:[ \t]*$" l)) lines)
                (dolist (kv (plist-get rule :revealjs))   ; report / handout には revealjs が無い
                  (setq lines (ox-quarto-ext--set-revealjs lines kv)))))
            (push (concat "palette " palette) note))
          (dolist (d decks)
            (ox-quarto-ext--check-scss (concat d "-deck") base)
            (setq lines (ox-quarto-ext--add-deck lines d)))
          (when decks (push (concat "deck " (string-join decks " ")) note))
          (setq info
                (plist-put info :quarto-frontmatter
                           (concat (format "# ox-quarto-ext: %s を %s から書き換え\n"
                                           (string-join (nreverse note) "，") fm)
                                   (string-join lines "\n")))))))
    (ox-quarto-ext-format-options
     (ox-quarto-ext--add-title-qr (ox-quarto-ext--add-institute info)))))

(let ((backend (org-export-get-backend 'quarto)))
  (if (null backend)
      (warn "ox-quarto-ext: quarto backend not found; QUARTO_PALETTE / QUARTO_DECK skipped")
    (dolist (opt '((:quarto-palette "QUARTO_PALETTE" nil nil t)
                   (:quarto-deck "QUARTO_DECK" nil nil space)
                   (:quarto-institute "INSTITUTE" nil nil newline)
                   (:quarto-qr "QUARTO_QR" nil nil t)
                   (:quarto-qr-caption "QUARTO_QR_CAPTION" nil nil t)))
      (unless (assq (car opt) (org-export-backend-options backend))
        (push opt (org-export-backend-options backend))))
    (setf (alist-get :filter-options (org-export-backend-filters backend))
          #'ox-quarto-ext-theme-filter)))

(provide 'ox-quarto-ext-theme)
;;; ox-quarto-ext-theme.el ends here
