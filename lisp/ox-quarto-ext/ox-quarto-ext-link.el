;;; ox-quarto-ext-link.el --- Org image links -> Quarto figures  -*- lexical-binding: t; -*-

;; ox-quarto は画像リンクを `org-md-link' に丸投げするため、Quarto の図としては
;; 情報が落ちる。素の状態では:
;;
;;   [[file:images/plot.png]]            -> ![img](images/plot.png)   (alt が "img" 固定)
;;   #+CAPTION: 散布図                    -> markdown の title 属性になるだけ
;;   #+NAME: fig-scatter                 -> 消える（相互参照できない）
;;   #+ATTR_QUARTO: :width 60%           -> 消える
;;   [[file:...png][説明]]                -> 画像ではなくリンクになる
;;
;; 段落に単独で置かれた画像リンクを Quarto の図記法に変換する。
;;
;;     #+CAPTION: 散布図のキャプション
;;     #+NAME: fig-scatter
;;     #+ATTR_QUARTO: :width 60% :fig-align "center"
;;     [[file:images/plot.png]]
;;
;;   -> ![散布図のキャプション](images/plot.png){#fig-scatter width=60% fig-align="center"}
;;
;; * キャプションは #+CAPTION: に書く。リンクの説明部 ([[file:...][説明]]) は
;;   Org 自身が「画像ではなくリンク」と解釈するので使わない
;;   （説明があってキャプションが無いときだけ alt に回す）。
;; * #+NAME: が {#...} になるので本文から @fig-scatter で参照できる。
;;   相互参照させるなら名前は fig- で始める。
;; * #+ATTR_QUARTO: の値はそのまま属性になる。引用符付きで出したい値は
;;   :fig-align "center" のように書く。
;; * 文中のインライン画像は ![](path) になり、属性は付かない。
;; * 画像以外のリンクは ox-quarto 本来の `org-quarto-link' に渡す。

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'ox)
(require 'ox-quarto-ext-core)

(declare-function org-quarto-link "ox-quarto" (link desc info))

(defcustom ox-quarto-ext-image-extensions
  '("png" "jpg" "jpeg" "gif" "svg" "pdf" "webp" "tif" "tiff")
  "画像として扱うファイル拡張子。"
  :type '(repeat string)
  :group 'ox-quarto-ext)

(defun ox-quarto-ext-link--image-p (link)
  "Non-nil when LINK points at a local image file."
  (and (member (org-element-property :type link) '("file" nil ""))
       (member (downcase (or (file-name-extension
                              (org-element-property :path link))
                             ""))
               ox-quarto-ext-image-extensions)))

(defun ox-quarto-ext-link--standalone-parent (link)
  "Return LINK's paragraph when LINK is the only content of it.
Affiliated keywords (#+CAPTION:, #+NAME:, #+ATTR_QUARTO:) は link ではなく
paragraph に付くので、それを取り出す必要がある。"
  (let ((par (org-element-property :parent link)))
    (when (and par (eq (org-element-type par) 'paragraph))
      (let ((kids (cl-remove-if (lambda (x)
                                  (and (stringp x) (string-blank-p x)))
                                (org-element-contents par))))
        (when (and (= (length kids) 1) (eq (car kids) link))
          par)))))

(defun ox-quarto-ext-link--attrs (par)
  "Build the `{#id key=value}' suffix from PAR's keywords."
  (let* ((attrs (and par (org-export-read-attribute :attr_quarto par)))
         (name  (and par (org-element-property :name par)))
         (parts '()))
    (when (and name (org-string-nw-p name))
      (push (concat "#" name) parts))
    (cl-loop for (k v) on attrs by #'cddr
             do (push (format "%s=%s" (ox-quarto-ext-keyword-name k) v) parts))
    (if parts
        (concat "{" (mapconcat #'identity (nreverse parts) " ") "}")
      "")))

(defun ox-quarto-ext-link--caption (par info)
  (let ((cap (and par (org-element-property :caption par))))
    (if cap (string-trim (org-export-data (car (car cap)) info)) "")))

(defun ox-quarto-ext-link (link desc info)
  "Export an image LINK as a Quarto figure; delegate everything else."
  (if (not (ox-quarto-ext-link--image-p link))
      (org-quarto-link link desc info)
    (let* ((par  (ox-quarto-ext-link--standalone-parent link))
           (path (org-element-property :path link))
           (cap  (ox-quarto-ext-link--caption par info))
           (alt  (cond ((org-string-nw-p cap) cap)
                       ((org-string-nw-p desc) desc)
                       (t ""))))
      (concat "![" alt "](" path ")" (ox-quarto-ext-link--attrs par)))))

(with-eval-after-load 'ox-quarto
  (ox-quarto-ext-set-transcoder 'link #'ox-quarto-ext-link))

(provide 'ox-quarto-ext-link)
;;; ox-quarto-ext-link.el ends here
