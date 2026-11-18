;;; ox-quarto-ext-frontmatter.el --- 表題まわりのキーワード (#+INSTITUTE / #+AUTHOR の \and / #+DATE / #+EMAIL / #+QUARTO_QR) を front matter に  -*- lexical-binding: t; -*-

;; ox-quarto 本体が書き出さない，あるいは Quarto の読み方と合わない表題まわりのキーワードを
;; front matter の行にする (2026-11-18 に ox-quarto-ext-theme.el から分けた)．
;; 呼ぶのは ox-quarto-ext-theme.el の options フィルタ (theme を書き換えた後)．
;;
;; #+INSTITUTE: (beamer と同じ書き方) は表紙の所属として front matter の institute: に書き出す
;; (ox-quarto 本体は書き出さない)．行を重ねれば所属の一覧 (yaml のリスト) になる．Quarto は
;; institute を著者の所属 (.quarto-title-affiliation) として氏名の下に出す．
;;
;; #+DATE に日付でない文字がまじれば，日付を date:，文字を date-format: の [ ] に書き出す (2026-11-07．
;; Quarto は date: を日付として読み，文字がまじると Invalid Date と出る)．日付の書式は #+QUARTO_DATE_FORMAT (空白も書ける)．
;; #+AUTHOR: 氏名1 \and 氏名2 (2026-11-03) は front matter の author: をリストにする (本体は 1 つの文字列にする)．
;; #+EMAIL:，#+AUTHOR_EN:，#+INSTITUTE_EN: (2026-11-03) は front matter の oxq-email: / oxq-author-en: /
;; oxq-institute-en: に書き出す (書いたときだけ．INSTITUTE_EN は行を重ねればリスト)．解説文 (report) の表題を
;; 紀要の形 (和文の所属と氏名・英文の氏名と所属・連絡先の脚注) にするのは _quarto/lib/title-block.lua．
;;
;; #+QUARTO_QR: (画像のパス) と #+QUARTO_QR_CAPTION: (画像の下の短い文．URL ならリンク) は
;; front matter の title-qr: に書き出す．表紙の右下に置くのは _quarto/lib/title-qr.lua
;; (講演の版の頁の QR コードを想定．画像は tools/oxq-qr.py で作れる)．
;;
;; どれも front matter の先頭に行を足す (`ox-quarto-ext--prepend-frontmatter'．QUARTO_FRONTMATTER が
;; yaml のファイル名なら中身を読んでから足す)．

;;; Code:

(require 'ox-quarto-ext-core)
(require 'subr-x)

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

(defun ox-quarto-ext--split-authors (info)
  "#+AUTHOR: 氏名1 \\and 氏名2 (LaTeX の書き方) なら，front matter の author: をリストにする．
本体は #+AUTHOR を 1 つの文字列で書くので，:author を外してこちらで書く (2026-11-03．共著の表題)．"
  (let* ((a (plist-get info :author))
         (s (and a (plist-get info :with-author)
                 (string-trim (org-element-interpret-data a)))))
    (when (and s (string-match-p "\\\\and\\b" s))
      (let ((names (split-string s "[ \t]*\\\\and\\b[ \t]*" t "[ \t]+")))
        (setq info (plist-put info :author nil))
        (setq info (ox-quarto-ext--prepend-frontmatter
                    info
                    (concat "author:\n"
                            (mapconcat (lambda (x) (concat "  - " (ox-quarto-ext--yaml-string x)))
                                       names "\n")))))))
  info)

(defconst ox-quarto-ext--date-re
  "\\`\\(today\\|now\\|last-modified\\|[0-9]\\{4\\}-[0-9]\\{1,2\\}-[0-9]\\{1,2\\}\\)\\([ \t]*\\)\\(.*\\)\\'"
  "#+DATE の先頭の日付 (Quarto が日付として読む形) と，その後の文字．")

(defun ox-quarto-ext--dayjs-literal (text)
  "TEXT を dayjs の書式の文字の部分 [ … ] にする (] は使えないので全角に)．"
  (concat "[" (replace-regexp-in-string "\\]" "］" text) "]"))

(defun ox-quarto-ext--split-date (info)
  "#+DATE に日付でない文字があれば，日付を date: に，文字を date-format: の [ ] の中に書き出す (2026-11-07)．
Quarto は date: を日付として読むので，文字がまじると表紙に Invalid Date と出る．
  #+DATE: 2026-01-01 の講演の拡大版  → date: 2026-01-01，date-format: \"YYYY-MM-DD[ の講演の拡大版]\"
  #+DATE: 〜の講演の拡大版           → date: today，date-format: \"[〜の講演の拡大版]\" (文字だけが出る)
日付の書式は #+QUARTO_DATE_FORMAT (dayjs．空白も書ける．例 YYYY年M月D日)，無ければ YYYY-MM-DD
\(revealjs の表紙の既定と同じ見た目．html の既定は January 1, 2026 の形，LaTeX は書いたまま)．日付だけの #+DATE は今まで通り (#+QUARTO_DATE_FORMAT は date-format: になる)．"
  (let* ((d (plist-get info :date))
         (s (and d (plist-get info :with-date)
                 (string-trim (org-element-interpret-data d))))
         (fmt (org-string-nw-p (string-trim (or (plist-get info :quarto-date-format) ""))))
         (lines nil))
    (when (org-string-nw-p s)
      (if (string-match ox-quarto-ext--date-re s)
          (let ((date (match-string 1 s)) (sep (match-string 2 s)) (rest (match-string 3 s)))
            (when (org-string-nw-p rest)
              (setq info (plist-put info :date nil))
              (push (concat "date: " date) lines)
              (push (concat "date-format: "
                            (ox-quarto-ext--yaml-string
                             (concat (or fmt "YYYY-MM-DD") (ox-quarto-ext--dayjs-literal (concat sep rest)))))
                    lines)
              (setq fmt nil)))
        (setq info (plist-put info :date nil))
        (push "date: today" lines)
        (push (concat "date-format: " (ox-quarto-ext--yaml-string (ox-quarto-ext--dayjs-literal s))) lines)
        (setq fmt nil)))
    (when fmt (push (concat "date-format: " (ox-quarto-ext--yaml-string fmt)) lines))
    (when lines
      (setq info (ox-quarto-ext--prepend-frontmatter info (string-join (nreverse lines) "\n")))))
  info)

(defun ox-quarto-ext--add-title-names (info)
  "#+EMAIL / #+AUTHOR_EN / #+INSTITUTE_EN があれば front matter の先頭に
oxq-email: / oxq-author-en: / oxq-institute-en: を足す (解説文の表題．lib/title-block.lua)．
#+EMAIL は書いたときだけ (org の既定の user-mail-address は使わない)．"
  (dolist (kv '((:quarto-email . "oxq-email")
                (:quarto-author-en . "oxq-author-en")
                (:quarto-institute-en . "oxq-institute-en")))
    (let ((vals (split-string (or (plist-get info (car kv)) "") "\n" t "[ \t]+")))
      (when vals
        (setq info (ox-quarto-ext--prepend-frontmatter
                    info
                    (if (cdr vals)
                        (concat (cdr kv) ":\n"
                                (mapconcat (lambda (x) (concat "  - " (ox-quarto-ext--yaml-string x)))
                                           vals "\n"))
                      (concat (cdr kv) ": " (ox-quarto-ext--yaml-string (car vals)))))))))
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

(defun ox-quarto-ext-frontmatter-options (info)
  "表題まわりのキーワードを front matter に書き出した INFO を返す．
足す順 (front matter の先頭に重ねるので，出る順はこの逆): author，date，institute，oxq-*，title-qr．"
  (ox-quarto-ext--add-title-qr
   (ox-quarto-ext--add-title-names
    (ox-quarto-ext--add-institute
     (ox-quarto-ext--split-date
      (ox-quarto-ext--split-authors info))))))

(let ((backend (org-export-get-backend 'quarto)))
  (if (null backend)
      (warn "ox-quarto-ext: quarto backend not found; #+INSTITUTE などの表題のキーワードは書き出さない")
    (dolist (opt '((:quarto-institute "INSTITUTE" nil nil newline)
                   (:quarto-email "EMAIL" nil nil t)
                   (:quarto-date-format "QUARTO_DATE_FORMAT" nil nil t)
                   (:quarto-author-en "AUTHOR_EN" nil nil newline)
                   (:quarto-institute-en "INSTITUTE_EN" nil nil newline)
                   (:quarto-qr "QUARTO_QR" nil nil t)
                   (:quarto-qr-caption "QUARTO_QR_CAPTION" nil nil t)))
      (unless (assq (car opt) (org-export-backend-options backend))
        (push opt (org-export-backend-options backend))))))

(provide 'ox-quarto-ext-frontmatter)
;;; ox-quarto-ext-frontmatter.el ends here
