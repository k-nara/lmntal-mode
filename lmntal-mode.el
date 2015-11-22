;;; lmntal-mode.el --- An LMNtal development environment

;; Copyright (C) 2013 Ueda Lab. LMNtal Group

;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are
;; met:
;;
;;  1. Redistributions of source code must retain the above copyright
;;     notice, this list of conditions and the following disclaimer.
;;
;;  2. Redistributions in binary form must reproduce the above copyright
;;     notice, this list of conditions and the following disclaimer in
;;     the documentation and/or other materials provided with the
;;     distribution.
;;
;;  3. Neither the name of the Ueda Laboratory LMNtal Group nor the names of its
;;     contributors may be used to endorse or promote products derived from
;;     this software without specific prior written permission.
;;
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;; A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;; OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
;; LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
;; DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
;; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

;; Author: Kota Nara
;; Maintainer: Kota Nara
;; Contributor:
;; URL: http://www.ueda.info.waseda.ac.jp/lmntal/
;; Version: 20150910

;;; Commentary:

;; Load this script
;;
;;   (require 'lmntal-mode)
;;
;; and `lmntal-mode' (`lmntal-slimcode-mode') is automatically enabled
;; when opening .lmn (.il) files.
;;
;; See Readme.org for more info.

;;; Change Log:

;; 20140327 nara
;; - モデル検査の結果をGraphvizで描画できるようにした
;; - Javaランタイムのサポートをやめた
;; - 変数名 `lmntal-lmntal-directory' を `lmntal-home-directory' に変更
;; - `LMNTAL_HOME' を `lmntal-mode-directory' のデフォルト値として使うようにした
;; 20140731 nara
;; - syntax-table を更新, comment-start-skip の設定
;; - 実行結果を読むための major-mode の名前を変更
;; - `lmntal-beginning/end-of-rule' コマンドを追加
;; - 対応するリンク名のハイライトを実装
;; 20140802 nara
;; - `lmntal-trace-mode' にも "対応するリンク名のハイライト" を実装
;; 20140827 nara
;; - 実行結果でシンタックスハイライトが無効になるバグを修正
;; 20141112 nara
;; - `lmntal-slimcode-mode' で一行コメントを扱えるようにした
;; - `lmntal-slimcode-mode' にも autoload を付けた
;; - `lmntal-slimcode-mode' 用の indent-line-function を実装
;; 20141113 nara
;; - `lmntal-slimcode-help' コマンドを追加
;; 20141229 nara
;; - imagemagick に対応
;; 20150318 nara
;; - 行コメントの直後の行頭に '/' を入力するとハングする不具合を修正
;; - '.' をルール末尾のピリオドと勘違いしてしまう不具合を修正
;; 20150321 nara
;; - `lmntal-slimcode--help-table' を同梱
;; 20150327 nara
;; - 他の LMNtal 関連プロジェクトに合わせてライセンスを変更
;; 20150329 nara
;; - `lmntal-link-name-face` のデフォルト色を白背景のテーマに対応
;; 20150430 nara
;; - あるリンク名が別のリンク名の一部に含まれるときハイライトが壊れるバグを修正
;; 20150522 nara
;; - ')'を入力するとカーソルが行頭に移動するバグを修正
;; 20150527 nara
;; - UNYO のサポートを打ち切り、 Graphene のサポートを追加
;; 20150528 nara
;; - `--use-builtin-rule' をデフォルトのオプションから外した
;; 20150608 nara
;; - 一時ファイルを作成するときにミニバッファにメッセージを出ないようにした
;; 20150625 nara
;; - `lmntal-indent-line' でカーソルを進めるようにした
;; 20150711 nara
;; - 存在しない一時ファイルを削除しようとするバグを修正
;; 20150910 nara
;; - インポート文 (module.use) のシンタックスハイライトを追加

;;; Code:

(require 'font-lock)                ; font-lock-defaults
(require 'view)                     ; view-mode
(require 'eldoc)                    ; eldoc-mode
(require 'electric)                 ; electric-indent, electric-layout
(require 'cl-lib)                   ; destructuring-bind

(defconst lmntal-mode-version "20150910")

;; + customs

(defgroup lmntal nil
  "major mode for editing LMNtal codes"
  :group 'languages)

(defcustom lmntal-indent-width 4
  "unit size of indentation"
  :group 'lmntal)

(defcustom lmntal-enable-link-highlight t
  "when non-nil, matching link/context names are highlighted"
  :group 'lmntal)

(defcustom lmntal-home-directory (getenv "LMNTAL_HOME")
  "path/to/lmntal/"
  :group 'lmntal)

(defcustom lmntal-slim-executable "installed/bin/slim"
  "path/to/slim (can be either an absolute path or a relative
path from \"lmntal-home-directory\")"
  :group 'lmntal)

(defcustom lmntal-graphene-executable "graphene/graphene.jar"
  "path/to/graphene.jar"
  :group 'lmntal)

(defcustom lmntal-compile-options
  '("--slimcode" "--hl")
  "options passed to LMNtal compiler")

(defcustom lmntal-runtime-options
  '("-t" "--hl" "--hide-ruleset")
  "options passed to SLIM in RunTime-mode")

(defcustom lmntal-mc-options
  '("--nd" "-t" "--hl" "--hide-ruleset" "--show-transition")
  "options passed to SLIM in ModelChecker-mode")

(defcustom lmntal-output-window-fraction 40
  "height(%) of the output window"
  :group 'lmntal)

(defcustom lmntal-mc-use-dot nil
  "when non-nil, use dot to render the result of model-checker"
  :group 'lmntal)

(defcustom lmntal-mc-dot-options
  '("-Ktwopi" "-Gsize=6.5,100" "-Goverlap=false" "-Gsplines=true")
  "options passed to dot"
  :group 'lmntal)

(defcustom lmntal-slimcode-help-hook nil
  "run when help buffer is created."
  :group 'lmntal)

(defcustom lmntal-mode-map
  (let ((kmap (make-sparse-keymap)))
    (define-key kmap (kbd "C-c C-c") 'lmntal-run-trace)
    (define-key kmap (kbd "C-c C-m") 'lmntal-run-mc)
    (define-key kmap (kbd "C-c C-i") 'lmntal-compile-only)
    (define-key kmap (kbd "C-c C-g") 'lmntal-run-graphene)
    (define-key kmap [remap end-of-defun] 'lmntal-end-of-rule)
    (define-key kmap [remap beginning-of-defun] 'lmntal-beginning-of-rule)
    kmap)
  "keymap for LMNtal mode"
  :group 'lmntal)

(defcustom lmntal-trace-mode-map
  (let ((kmap (make-sparse-keymap)))
    (define-key kmap (kbd "g") 'lmntal-run-graphene)
    (define-key kmap (kbd "C-c C-g") 'lmntal-run-graphene)
    kmap)
  "keymap for LMNtal-trace mode"
  :group 'lmntal)

(defcustom lmntal-slimcode-mode-map
  (let ((kmap (make-sparse-keymap)))
    (define-key kmap (kbd "C-c C-c") 'lmntal-slimcode-run)
    (define-key kmap (kbd "C-c C-m") 'lmntal-slimcode-mc)
    (define-key kmap [remap info-lookup-symbol] 'lmntal-slimcode-help)
    (define-key kmap [remap newline-and-indent] 'reindent-then-newline-and-indent)
    kmap)
  "keymap for LMNtal-slimcode mode"
  :group 'lmntal)

(defface lmntal-rule-name-face
  '((t (:inherit font-lock-comment-face)))
  "face used for LMNtal rule names"
  :group 'lmntal)

(defface lmntal-link-name-face
  '((((background dark)) (:background "#003944"))
    (t (:background "#f8f6f1")))
  "face used for LMNtal link/context names"
  :group 'lmntal)

(defface lmntal-highlight-face
  '((t (:foreground "#cc828f" :bold t :underline t)))
  "face used for matching link names"
  :group 'lmntal)

;; + LMNtal common syntax table

(defvar lmntal-syntax-table
  (let ((st (make-syntax-table)))
    ;; symbol
    (modify-syntax-entry ?! "_" st)     ; hyperlinks
    (modify-syntax-entry ?$ "_" st)     ; process contexts
    (modify-syntax-entry ?@ "_" st)     ; rule contexts
    (modify-syntax-entry ?* "_ 23" st)  ; link-bundles
    ;; punct
    (modify-syntax-entry ?: "." st)
    (modify-syntax-entry ?. "." st)
    (modify-syntax-entry ?| "." st)
    (modify-syntax-entry ?+ "." st)
    (modify-syntax-entry ?- "." st)
    (modify-syntax-entry ?= "." st)
    (modify-syntax-entry ?< "." st)
    (modify-syntax-entry ?> "." st)
    (modify-syntax-entry ?\\ "." st)
    ;; string
    (modify-syntax-entry ?\" "\"" st)
    (modify-syntax-entry ?\' "\"" st)
    ;; parens
    (modify-syntax-entry ?\( "()" st)
    (modify-syntax-entry ?\[ "(]" st)
    (modify-syntax-entry ?\{ "(}" st)
    (modify-syntax-entry ?\) ")(" st)
    (modify-syntax-entry ?\] ")[" st)
    (modify-syntax-entry ?\} "){" st)
    ;; "%" comments
    (modify-syntax-entry ?% "< b" st)
    (modify-syntax-entry ?\n "> b" st)
    ;; "/" and "/*" comments
    (modify-syntax-entry ?/  ". 124b" st)
    (modify-syntax-entry ?*  ". 23" st)
    st)
  "syntax table for LMNtal mode")

;; + utility functions
;;   + comment recognizer

(defun lmntal--in-comment-p ()
  "return if the point is inside a comment (inclusive)."
  (or (nth 4 (syntax-ppss))
      (and (not (eobp))
           (save-excursion
             (nth 4 (syntax-ppss (1+ (point))))))
      ;; *FIXME* FALSE-POSITIVE
      (looking-back "\\*/")
      (looking-at "/\\(?:/\\|\\*\\)")))

(defun lmntal--in-string-p ()
  "return if the point is inside of a string (exclusive)."
  (nth 3 (syntax-ppss)))

(defun lmntal--beginning-of-comment ()
  "go to the beginning of THIS comment.
if nothing happened, return nil. otherwise return non-nil"
  (when (and (lmntal--in-comment-p) (not (bobp)))
    (while (and (not (bobp))
                (save-excursion
                  (forward-char -1)
                  (lmntal--in-comment-p)))
      (forward-char -1))
    t)
  ;; *NOTE* どのみち遅かったから、そもそもアプローチが間違ってるぽい
  ;;        magic-latex-buffer みたいにサーチしてからコメント内外判定ではダメ？
  ;; (let ((orig-pos (point))
  ;;       (new-pos (comment-beginning)))
  ;;   (when new-pos (goto-char new-pos))
  ;;   new-pos)
  )

(defun lmntal--end-of-comment ()
  "go to the end of THIS comment.
if nothing happened, return nil. otherwise return non-nil"
  (when (and (lmntal--in-comment-p) (not (eobp)))
    (while (and (not (eobp))
                (save-excursion
                  (forward-char 1)
                  (lmntal--in-comment-p)))
      (forward-char 1))
    t)
  ;; (let* ((orig-pos (point))
  ;;        (beg-pos (comment-beginning))
  ;;        (new-pos (when beg-pos
  ;;                   (goto-char beg-pos)
  ;;                   (forward-comment 1))))
  ;;   new-pos)
  )

;;   + jumping around (for internal use)

(defun lmntal--go-forward ()
  "when looking at either a comment, list, identifier or
 character except for ])}, jump forward over it and skip
 following spaces then return non-nil. otherwise just return nil.

  |bar  : -  foo  (bar)  /*baz*/  baz .
   bar |: -  foo  (bar)  /*baz*/  baz .
   bar  :|-  foo  (bar)  /*baz*/  baz .
   bar  : - |foo  (bar)  /*baz*/  baz .
   bar  : -  foo |(bar)  /*baz*/  baz .
   bar  : -  foo  (bar) |/*baz*/  baz .
   bar  : -  foo  (bar)  /*baz*/ |baz .
   bar  : -  foo  (bar)  /*baz*/  baz|.
   bar  : -  foo  (bar)  /*baz*/  baz .|
   bar  : -  foo  (bar)  /*baz*/  baz .| (nil)"
  (unless (or (eobp) (memql (char-after) '(?\) ?\] ?\})))
    (cond ((lmntal--in-comment-p)
           (lmntal--end-of-comment))
          ((or (memql (char-after) '(?\( ?\[ ?\{)) (looking-at "\\_<"))
           (forward-sexp))
          (t
           (forward-char 1)))
    (skip-chars-forward "\s\t\n")))

(defun lmntal--go-backward ()
  "when looking back either a comment, list, identifier or
 character except for [({, jump backward over it and skip
 preceding spaces then return non-nil. otherwise just return nil.

   bar  : -  foo  (bar)  /*baz*/  qux .|
   bar  : -  foo  (bar)  /*baz*/  baz|.
   bar  : -  foo  (bar)  /*baz*/| baz .
   bar  : -  foo  (bar)| /*baz*/  baz .
   bar  : -  foo| (bar)  /*baz*/  baz .
   bar  : -| foo  (bar)  /*baz*/  baz .
   bar  :|-  foo  (bar)  /*baz*/  baz .
   bar| : -  foo  (bar)  /*baz*/  baz .
  |bar  : -  foo  (bar)  /*baz*/  baz .
  |bar  : -  foo  (bar)  /*baz*/  baz . (nil)"
  (unless (or (bobp) (memql (char-before) '(?\( ?\[ ?\{)))
    (cond ((lmntal--in-comment-p)
           (lmntal--beginning-of-comment))
          ((or (memql (char-before) '(?\) ?\] ?\})) (looking-back "\\_>"))
           (backward-sexp))
          (t
           (forward-char -1)))
    (skip-chars-backward "\s\t\n")))

(defun lmntal--search-forward (regex)
  "search regexp forward via `lmntal--go-forward'.
return non-nil iff succeeded."
  (when (or (not (zerop (skip-chars-forward "\s\t\n")))
            (lmntal--go-forward))
    (while (and (not (looking-at regex))
                (lmntal--go-forward)))
    (looking-at regex)))

(defun lmntal--search-backward (regex)
  "search regexp backward via `lmntal--go-backward'.
return non-nil iff succeeded."
  (when (or (not (zerop (skip-chars-backward "\s\t\n")))
            (lmntal--go-backward))
    (while (and (not (looking-back regex))
                (lmntal--go-backward)))
    (looking-back regex)))

;;   + rule parser

(defun lmntal--syntax-info ()
  "return (BEG-OF-ANNOTATION BEG-OF-LHS BEG-OF-GUARD BEG-OF-RHS
END-OF-RHS) of statement at the point, or nil on parse-error."
  (let (annot lhs rhs guard end)
    (save-excursion
      ;; annotation
      (while (and (lmntal--search-backward "\\(\\.\\|@@\\)")
                  ;; module prefix (like 'mymodule.hoge')
                  (or (looking-at "[a-z]") (lmntal--in-string-p))))
      (when (looking-back "[_a-z0-9]+@@" nil t)
        (setq annot (match-beginning 0)))
      (while (and (skip-chars-forward "\s\t\n")
                  (lmntal--end-of-comment)))
      (unless (or (eobp) (looking-at "[)}]"))
        (setq lhs (point))
        ;; guard
        (while (and (lmntal--search-forward "\\(\\.\\|:-\\)")
                    (or (looking-at "\\.[a-z]") (lmntal--in-string-p))))
        (if (not (looking-at ":-"))
            ;; this process is not a rule
            `(,annot ,lhs nil nil ,(1+ (point)))
          (forward-char 2)
          (while (and (skip-chars-forward "\s\t\n")
                      (lmntal--end-of-comment)))
          (setq guard (point))
          (when (or (looking-at "[^.]\\|$") (lmntal--in-string-p))
            ;; search for end of the guard or rule
            (while (and (lmntal--search-forward "\\(\\.\\||\\)")
                        (or (looking-at "\\.[a-z]") (lmntal--in-string-p)))))
          (if (not (looking-at "|"))
              ;; this rule does not have a guard
              `(,annot ,lhs nil ,guard ,(1+ (point)))
            (forward-char 1)
            (while (and (skip-chars-forward "\s\t\n")
                        (lmntal--end-of-comment)))
            (setq rhs (point))
            ;; end of stmt
            (while (and (lmntal--search-forward "\\.")
                        (or (looking-at "\\.[a-z]") (lmntal--in-string-p))))
            `(,annot ,lhs ,guard ,rhs ,(1+ (point)))))))))

(defun lmntal--this-rule-info ()
  "like `lmntal--syntax-info', but if the statement has no RHS,
search parent recursively."
  (let* ((info (lmntal--syntax-info)))
    (cond ((null info) nil)
          ((nth 3 info) info)
          (t
           (condition-case nil
               (save-excursion
                 (up-list)
                 (lmntal--this-rule-info))
             ;; we cannot go upward anymore
             (error info))))))

;;   + others

(defun lmntal--last-noncomment-char ()
  "search for the last char, which is not a whitespace nor inside comment.
return nil if not found."
  (save-excursion
    (while (and (lmntal--go-backward) (lmntal--in-comment-p)))
    (unless (bobp)
      (char-before))))

;; + highlight matching links

(defvar lmntal--highlight-overlay nil)
(make-variable-buffer-local 'lmntal--highlight-overlay)

(defsubst lmntal--in-linkname-p (&optional pos)
  "return non-nil if POS is inside a link-name."
  (ignore-errors
    (eq 'lmntal-link-name-face
        (get-text-property (or pos (point)) 'face))))

(defun lmntal--highlight-update ()
  (mapc 'delete-overlay lmntal--highlight-overlay)
  (setq lmntal--highlight-overlay nil)
  (when (and lmntal-enable-link-highlight
             (or (lmntal--in-linkname-p)
                 (lmntal--in-linkname-p (1- (point)))))
    (save-excursion
      (let ((info (lmntal--this-rule-info))
            (str (thing-at-point 'symbol))
            (case-fold-search nil))
        (when (and info str)
          (let ((beg (or (car info) (cadr info)))
                (rhs (nth 3 info))
                (limit (nth 4 info))
                (rx (concat "\\_<" (regexp-quote str) "\\_>")))
            ;; make highlights
            (goto-char beg)
            (while (search-forward-regexp rx limit t)
              (push (make-overlay (match-beginning 0) (match-end 0))
                    lmntal--highlight-overlay))
            (mapc (lambda (ov)
                    (overlay-put ov 'category 'lmntal)
                    (overlay-put ov 'face 'lmntal-highlight-face))
                  lmntal--highlight-overlay)
            ;; process nested rules
            (when rhs
              (goto-char rhs)
              (while (search-forward ":-" limit t)
                (let ((tmp (lmntal--this-rule-info)))
                  (when tmp
                    (remove-overlays
                     (cadr tmp) (nth 4 tmp) 'category 'lmntal)))))))))))

;; + jump commands

(defun lmntal-beginning-of-rule (&optional arg)
  "move backward to the beginning of rule at point."
  (interactive "P")
  (dotimes (_ (or arg 1))
    (let ((pos (point)))
      (lmntal--go-backward)
      (while (lmntal--beginning-of-comment)
        (skip-chars-backward "\s\t\n"))
      (let ((info (unless (bobp) (lmntal--this-rule-info))))
        (if info
            (goto-char (or (car info) (cadr info)))
          (goto-char pos)
          (error "no rules found"))))))

(defun lmntal-end-of-rule (&optional arg)
  "move forward to the end of rule at point."
  (interactive "P")
  (dotimes (_ (or arg 1))
    (let ((pos (point)))
      (lmntal--go-forward)
      (while (lmntal--end-of-comment)
        (skip-chars-forward "\s\t\n"))
      (let ((info (unless (eobp) (lmntal--this-rule-info))))
        (if info
            (goto-char (nth 4 info))
          (goto-char pos)
          (error "no rules found"))))))

;; + run LMNtal within Emacs
;;   + utilities

(defvar lmntal--output-window nil)
(defvar lmntal--output-buffer nil)

(defun lmntal--prepare-output-buffer ()
  (or (buffer-live-p lmntal--output-buffer)
      (setq lmntal--output-buffer (get-buffer-create "*LMNtal Output*")))
  (or (window-live-p lmntal--output-window)
      (setq lmntal--output-window
            (split-window-vertically
             (/ (* lmntal-output-window-fraction (window-height)) -100))))
  (set-window-buffer lmntal--output-window lmntal--output-buffer))

(defun lmntal-output-exit ()
  "close this output window"
  (interactive)
  (if (use-region-p)
      (keyboard-quit)
    (select-window (previous-window))
    (when (window-live-p lmntal--output-window)
      (delete-window lmntal--output-window))
    (when (buffer-live-p lmntal--output-buffer)
      (kill-buffer lmntal--output-buffer))))

(defvar lmntal--temp-files nil)
(defun lmntal--make-temp-file (&optional with-content)
  "make and return a temporary file. the file will be deleted
when emacs is killed. when WITH-CONTENT is non-nil, write either
region or whole buffer to the file."
  (let ((file (make-temp-file "lmntal_" nil ".lmn")))
    (push file lmntal--temp-files)
    (when with-content
      (if (use-region-p)
          (write-region (region-beginning) (region-end) file nil 'nomsg)
        (write-region (point-min) (point-max) file nil 'nomsg)))
    file))

(add-hook 'kill-emacs-hook
          (lambda ()
            (mapc (lambda (f) (when (file-exists-p f) (delete-file f)))
                  lmntal--temp-files)))

;;   + visualize .lmn

(defun lmntal-run-graphene ()
  "visualize region (or buffer) as LMNtal code."
  (interactive)
  (when (not lmntal-graphene-executable)
    (error "specify lmntal-graphene-executable"))
  (let* ((file (lmntal--make-temp-file t))
         (default-directory lmntal-home-directory)
         (fullpath (expand-file-name lmntal-graphene-executable))
         (jar-filename (file-name-nondirectory fullpath))
         (default-directory (file-name-directory fullpath))
         (command (concat "java -jar " jar-filename " --lmntal.file " file)))
    (message command)
    (save-window-excursion
      (async-shell-command command nil nil))))

;;   + run .lmn

(defun lmntal-run-trace ()
  "run region (or buffer) as LMNtal code."
  (interactive)
  (when (not lmntal-home-directory)
    (error "specify lmntal-home-directory"))
  (lmntal--prepare-output-buffer)
  (let* ((file (lmntal--make-temp-file t))
         (default-directory lmntal-home-directory)
         (command
          (concat "java"
                  " -classpath ./bin/lmntal.jar:./lib/std_lib.jar"
                  " -DLMNTAL_HOME=."
                  " runtime.FrontEnd"
                  " " (mapconcat 'identity lmntal-compile-options " ")
                  " " file
                  " | " lmntal-slim-executable
                  " " (mapconcat 'identity lmntal-runtime-options " ")
                  " -")))
    (message command)
    (shell-command command lmntal--output-buffer)
    (select-window lmntal--output-window)
    (lmntal-trace-mode)
    (local-set-key [remap keyboard-quit] 'lmntal-output-exit)))

(defun lmntal-run-mc ()
  "model check region (or buffer) as LMNtal code."
  (interactive)
  (when (not lmntal-home-directory)
    (error "specify lmntal-home-directory"))
  (lmntal--prepare-output-buffer)
  (let* ((file (lmntal--make-temp-file t))
         (outfile (lmntal--make-temp-file nil))
         (default-directory lmntal-home-directory)
         (command1
          (concat "java"
                  " -classpath ./bin/lmntal.jar:./lib/std_lib.jar"
                  " -DLMNTAL_HOME=."
                  " runtime.FrontEnd"
                  " " (mapconcat 'identity lmntal-compile-options " ")
                  " " file))
         (command2
          (if lmntal-mc-use-dot
              (concat " | " lmntal-slim-executable
                      " " (mapconcat 'identity lmntal-mc-options " ")
                      " --dump-dot -"
                      " | dot -Kdot -Tpng"
                      " " (mapconcat 'identity lmntal-mc-dot-options " ")
                      " -o" outfile)
            (concat " | " lmntal-slim-executable
                    " " (mapconcat 'identity lmntal-mc-options " ")
                    " -")))
         (command (concat command1 command2)))
    (message command)
    (shell-command command lmntal--output-buffer)
    (select-window lmntal--output-window)
    (if (not lmntal-mc-use-dot)
        (lmntal-mc-mode)
      (insert-image (create-image outfile
                                  (if (image-type-available-p 'imagemagick)
                                      'imagemagick
                                    'png)
                                  nil))
      (view-mode))
    (local-set-key [remap keyboard-quit] 'lmntal-output-exit)))

;;   + compile .lmn

(defun lmntal-compile-only ()
  "compile region (or buffer) as LMNtal code."
  (interactive)
  (when (not lmntal-home-directory)
    (error "specify lmntal-home-directory"))
  (lmntal--prepare-output-buffer)
  (let ((file (lmntal--make-temp-file t))
        (buf (get-buffer-create (concat (buffer-name) "-SLIMcode"))))
    (switch-to-buffer buf)
    (let* ((default-directory lmntal-home-directory)
           (command
            (concat "java"
                    " -classpath ./bin/lmntal.jar:./lib/std_lib.jar"
                    " -DLMNTAL_HOME=."
                    " runtime.FrontEnd"
                    " " (mapconcat 'identity lmntal-compile-options " ")
                    " " file)))
      (message command)
      (shell-command command buf lmntal--output-buffer)
      (lmntal-slimcode-mode)
      (select-window  lmntal--output-window)
      (if (string= (buffer-string) "")
          (lmntal-output-exit)
        (view-mode)
        (local-set-key [remap keyboard-quit] 'lmntal-output-exit)))))

;;   + run/model-check .il

(defun lmntal-slimcode-run ()
  "run region (or buffer) as LMNtal intermediate code."
  (interactive)
  (when (not lmntal-home-directory)
    (error "specify lmntal-home-directory"))
  (lmntal--prepare-output-buffer)
  (let* ((file (lmntal--make-temp-file t))
         (default-directory lmntal-home-directory)
         (command
          (concat lmntal-slim-executable
                  " " (mapconcat 'identity lmntal-runtime-options " ")
                  " " file)))
    (message command)
    (shell-command command lmntal--output-buffer)
    (select-window lmntal--output-window)
    (lmntal-trace-mode)
    (local-set-key [remap keyboard-quit] 'lmntal-output-exit)))

(defun lmntal-slimcode-mc ()
  "model check region (or buffer) as LMNtal intermediate code."
  (interactive)
  (when (not lmntal-home-directory)
    (error "specify lmntal-home-directory"))
  (lmntal--prepare-output-buffer)
  (let* ((file (lmntal--make-temp-file t))
         (default-directory lmntal-home-directory)
         (command
          (concat lmntal-slim-executable
                  " " (mapconcat 'identity lmntal-mc-options " ")
                  " " file)))
    (message command)
    (shell-command command lmntal--output-buffer)
    (select-window lmntal--output-window)
    (lmntal-mc-mode)
    (local-set-key [remap keyboard-quit] 'lmntal-output-exit)))

;; + major-modes
;;   + lmntal-mode

;; font-lock

(defvar lmntal-font-lock-keywords
  '(
    ;; annotations
    ("\\_<.*?@@" . 'lmntal-rule-name-face)
    ;; processes / rule-contexts / hyperlinks
    ("\\_<[$@!][a-zA-Z0-9_]*\\_>"
     . 'lmntal-link-name-face)
    ;; link-bundles [| *Xs]
    ("\\(|[\s\t]*\\)\\([*][A-Z][a-zA-Z0-9_]*\\)\\_>"
     2 'lmntal-link-name-face)
    ;; link-variables
    ("\\_<[A-Z][a-zA-Z0-9_]*\\_>"
     . 'lmntal-link-name-face)
    ;; processes-types
    ("\\_<\\(float\\|ground\\|hl\\(?:ground\\|ink\\)\\|int\\|n\\(?:ew\\|um\\)\\|string\\|un\\(?:ary\\|iq\\)\\)\\_>"
     . font-lock-keyword-face)
    ;; rules :-
    (":-" . font-lock-keyword-face)
    ;; guard |
    ("\\(^\\|:-\\)\\([^[:.|]\\|:[^-|]\\)*\\(|\\)"
     3 font-lock-keyword-face)
    ;; membranes { foo, bar }/
    ("\\({\\|}[\s\t]*/?\\)" . font-lock-type-face)
    ;; lists, free-links [a, b | c]
    ("[][|]" . font-lock-variable-name-face)
    ;; module import
    ("\\([a-zA-Z0-9_]+\\)\\.\\(use\\)"
     (1 'font-lock-variable-name-face)
     (2 'font-lock-keyword-face)))
  "highlighting expressions for LMNtal mode")

;; imenu

(defvar lmntal-imenu-expression
  '(("Rules" "\\(?:^\\|[[{(.,]\\)[\s\t\n]*\\([a-zA-Z0-9_]+\\)[\s\t\n]*@@" 1)
    ("Membranes" "\\(?:^\\|[[{(.,]\\)[\s\t\n]*\\([a-zA-Z0-9_]+\\)[\s\t\n]*{" 1))
  "indexing expressions for LMNtal mode")

;; indent engine

(defun lmntal--calculate-indent (&optional silent)
  "calculate width of indent for THIS line"
  (save-excursion
    (beginning-of-line)
    (skip-chars-forward "\s\t")
    (cond
     ;; multi-line comment cont'd
     ((save-excursion
        (and (lmntal--in-comment-p)
             (ignore-errors (forward-char -1) t)
             (lmntal--in-comment-p)))
      (if (looking-at "\\*/")
          ;; looking at closing "*/"
          ;;   -> same column as opening "/*"
          (progn
            (unless silent (message "indent: mcomment end"))
            (lmntal--beginning-of-comment)
            (lmntal--calculate-indent t))
        ;; not the end of multi-line comment
        (if (not (eolp))
            ;; already has content
            ;;   -> do nothing
            (progn
              (unless silent (message "indent: ignore"))
              (current-column))
          ;; empty comment line
          ;;   -> +3 as opening "/*"
          (unless silent (message "indent: mcomment cont'd"))
          (lmntal--beginning-of-comment)
          (+ 3 (lmntal--calculate-indent t)))))
     ;; closing paren
     ((looking-at "[\s\t]*[])}]")
      (unless silent (message "indent: closing"))
      (save-excursion
        (forward-char 1)
        (backward-sexp 1)
        (let ((syntax (lmntal--syntax-info)))
          (goto-char (or (nth 0 syntax) (nth 1 syntax))))
        (current-column)))
     ;; otherwise
     (t
      (let* ((depth (nth 0 (syntax-ppss)))
             (last-char (lmntal--last-noncomment-char))
             (syntax-info (lmntal--syntax-info))
             (lhs (nth 1 syntax-info))
             (guard (nth 2 syntax-info))
             (rhs (nth 3 syntax-info))
             (stmt (nth 4 syntax-info))
             (point (point)))
        (cond
         ;; children
         ((member last-char '(?| ?-))
          (unless silent (message "indent: children"))
          (* (+ depth 1) lmntal-indent-width))
         ;; top-level
         ((member last-char '(?\( ?\{ ?\[ ?@ ?. nil))
          (unless silent (message "indent: top-level"))
          (* depth lmntal-indent-width))
         ;; line-up RHS
         ((and (= last-char ?,)
               rhs (< rhs point))
          (unless silent (message "indent: line-up RHS"))
          (goto-char rhs)
          (current-column))
         ;; line-up guard
         ((or (and (= last-char ?,)
                   guard (< guard point))
              (eql (char-after) ?|))    ; (char-after) can be nil
          (unless silent (message "indent: line-up guard"))
          (goto-char guard)
          (current-column))
         ;; line-up lhs
         ((or (= last-char ?,)
              (looking-at ":-"))
          (unless silent (message "indent: line-up LHS"))
          (goto-char lhs)
          (max 2 (current-column)))
         ;; otherwise do nothing
         (t
          (unless silent (message "indent: UNDECIDABLE"))
          (current-column))))))))

(defun lmntal-indent-line ()
  "indent current-line as LMNtal code"
  (interactive)
  (save-excursion
    (indent-line-to (lmntal--calculate-indent)))
  (when (looking-back "^[\s\t]*")
    (skip-chars-forward "\s\t")))

;; the mode

;;;###autoload
(define-derived-mode lmntal-mode prog-mode "LMNtal"
  "major mode for editing LMNtal programs"
  :group 'lmntal
  :syntax-table lmntal-syntax-table
  (set (make-local-variable 'imenu-generic-expression) lmntal-imenu-expression)
  (set (make-local-variable 'indent-line-function) 'lmntal-indent-line)
  (set (make-local-variable 'font-lock-defaults) '(lmntal-font-lock-keywords))
  (set (make-local-variable 'comment-start) "%")
  (set (make-local-variable 'comment-end) "")
  (set (make-local-variable 'comment-use-syntax) t)
  (set (make-local-variable 'comment-start-skip) "\\(?:/\\*+\\|%+\\|//+\\)\s*")
  (set (make-local-variable 'electric-indent-chars) '(?\} ?\) ?\]))
  (set (make-local-variable 'electric-layout-rules) '((?. . after)))
  (add-hook 'post-command-hook 'lmntal--highlight-update nil t))

;;   + lmntal-slimcode-mode

;; font-lock

(defvar lmntal-slimcode-font-lock-keywords
  '(
    ;; messages
    ("\\(Compiled\\|Ruleset\\|Rule\\|Inline\\)"
     . font-lock-keyword-face)
    ;; sections
    ("--[^:]*:"
     . font-lock-comment-face)
    ;; rule-names
    ("\\_<@[a-zA-Z0-9_]*@?\\_>"
     . 'lmntal-rule-name-face)
    ;; processes
    ("\\_<$[a-zA-Z0-9_]*\\_>"
     . 'lmntal-link-name-face)
    ;; hyperlinks
    ("\\_<![a-zA-Z0-9_]*\\_>"
     . 'lmntal-link-name-face)
    ;; link-variables
    ("\\_<[A-Z][a-zA-Z0-9_]*\\_>"
     . 'lmntal-link-name-face)
    ;; lists
    ("[][|]" . font-lock-variable-name-face)
    )
  "highlighting expressions for LMNtal-slimcode mode")

;; imenu

(defun lmntal-slimcode-imenu-function ()
  "function used by imenu to create index."
  (goto-char (point-min))
  (let ((rulesets nil)
        (rules nil)
        (case-fold-search nil))
    (while (search-forward "Compiled Rule" nil t)
      (if (looking-at "set[\s\t]*\\([^\s\t\n]*\\)")
          (push (cons (match-string-no-properties 1) (point-at-bol)) rulesets)
        (let ((pos (point-at-bol)))
          (search-forward-regexp "commit[\s\t\n]*\\[\"\\(.*\\)\"")
          (push (cons (match-string-no-properties 1) pos) rules))))
    (list (cons "Rules" (nreverse rules))
          (cons "Rulesets" (nreverse rulesets)))))

;; indent engine

(defconst lmntal-slimcode-output-operations
  '("allocatom" "allocatomindirect" "alloclink"
    "allocmem" "anymem" "copyatom" "copycells"
    "copyground" "deref" "derefatom" "dereffunc"
    "dereflink" "findatom" "getclass" "getclassfunc"
    "getfromlist" "getfunc" "getlink" "getmem"
    "getparent" "getruntime" "iadd" "iaddfunc"
    "insertconnectors" "insertconnectorsinnull"
    "isal" "isar" "isground" "ishr" "loadfunc"
    "lockmem" "lookuplink" "newatom" "newatomindirect"
    "newlinklist" "newmem" "newroot" "newset")
  "list of SLIM operations that do output. this may affect TAB
behavior in lmntal-slimcde-mode.")

(defun lmntal-slimcode-indent-line ()
  "indent current line as slimcode."
  (interactive)
  (let ((marker (set-marker (make-marker) (point))))
    (set-marker-insertion-type marker t)
    (back-to-indentation)
    (cond ((looking-at "--")            ; label -> indent to 4
           (indent-line-to tab-width))
          ((lmntal--in-comment-p)       ; comment -> do nothing
           nil)
          ((eq (get-text-property (point) 'face)
               'font-lock-keyword-face) ; keyword -> indent to 0
           (indent-line-to 0))
          (t                            ; otherwise
           ;; calculate appropriate indent width and indent
           (let ((depth (- (car (syntax-ppss (point)))
                           (if (looking-at "]]") 2 0))))
             (indent-line-to (/ (* (+ depth 4) tab-width) 2)))
           ;; fix margin between operation and arguments
           (when (looking-at "\\([a-z]+\\)\\(\s*\\)")
             (let* ((len (- (match-end 1) (match-beginning 1)))
                    (len (if (member (match-string 1)
                                     lmntal-slimcode-output-operations) (+ len 2) len))
                    (len (max 0 (- 15 len))))
               (unless (= (- (match-end 2) (match-beginning 2)) len)
                 (replace-match (make-string len ?\s) t t nil 2))))))
    ;; jump back to the original position
    (goto-char marker)))

;; help / eldoc

(defconst lmntal-slimcode--help-table
  (let ((hash (make-hash-table :test 'equal)))
    (mapc (lambda (doc) (dolist (op (car doc)) (puthash op doc hash)))
          '((("addatom") "[dstmem, atom]" "ボディ命令"
             "（所属膜を持たない）アトム $atom を膜 $dstmem に所属させる。")
            (("addatomtoset") "[srcset, atom]" "--"
             "$atom をアトムセット $srcset に追加する")
            (("addmem") "[dstmem, srcmem]" "ボディ命令"
             "ロックされた（親膜の無い）膜 $srcmem を（活性化された）膜 $dstmem に移動する。 子膜のロックは取得していないものとする。 子膜はルート膜の直前の膜まで再帰的に移動される。ホスト間移動した膜は活性化される。 膜 $srcmem を再利用するために使用される。 newmemと違い、 $srcmem のロックは明示的に解放しなければならない。 moveToメソッドを呼び出す。")
            (("addtolist") "[dstlist, src]" "--"
             "$src をリスト $dstlist の最後に追加する ( 2006/09/13 kudo )")
            (("allocatom") "[-dstatom, funcref]" "型付き拡張用命令"
             "ファンクタfuncrefを持つ所属膜を持たない新しいアトム作成し、参照を $dstatom に代入する。 ガード検査で使われる定数アトムを生成するために使用される。")
            (("allocatomindirect") "[-dstatom, func]" "型付き拡張用最適化用命令"
             "ファンクタ $func を持つ所属膜を持たない新しいアトムを作成し、参照を $dstatom に代入する。 ガード検査で使われる定数アトムを生成するために使用される。")
            (("alloclink") "[-link, atom, pos]" "出力する失敗しない拡張ガード命令、最適化用ボディ命令"
             "アトム $atom の第pos引数を指すリンクオブジェクトを生成し、参照を $link に代入する。 典型的には、 $atom はルールボディに存在する。")
            (("allocmem") "[-dstmem]" "最適化用ボディ命令"
             "親膜を持たない新しい膜を作成し、参照を $dstmem に代入する。")
            (("alterfunc") "[atom, funcref]" "最適化用ボディ命令"
             "（所属膜を持つ）アトム $atom のファンクタをfuncrefにする。 引数の個数が異なる場合の動作は未定義とする。")
            (("alterfuncindirect") "[atom, func]" "最適化用ボディ命令"
             "alterfuncと同じ。ただしファンクタは $func にする。")
            (("anymem") "[-dstmem, srcmem, memtype, memname]" "反復するロック取得するガード命令"
             "膜 $srcmem の子膜のうち、 $memtype で表せるタイプのまだロックを取得していない膜に対して次々に、 ノンブロッキングでのロック取得を試みる。 そして、ロック取得に成功した $memtype で表せるタイプの各子膜への参照を $dstmem に代入する。 取得したロックは、後続の命令列がその膜に対して失敗したときに解放される。 注意　ロック取得に失敗した場合と、その膜が存在していなかった場合とは区別できない。")
            (("branch") "[[instructions...]]" "構造化命令"
             "引数の命令列を実行することを表す。 引数実行中に失敗した場合、引数実行中に取得したロックを解放し、branchの次の命令に進む。 引数実行中にproceed命令を実行した場合、ここで終了する。")
            (("builtin") "[class, method, [links...]]" "--"
             "インタプリタ動作するときに組み込み機能を提供するために使用する。 通常は、 $builtin (class,method):(X1,…,Xn)に対応し、引数の種類によって次のものが渡される。 型付きプロセス文脈は、膜から除去したヘッド出現（またはガード生成したもの）が渡される。 ヘッドとボディに1回ずつ出現するリンクは、ヘッドでのリンク出現が渡される。 ボディに2回出現するリンクは、X=Xで初期化された後、各出現をヘッドでの出現と見なして渡される。")
            (("callback") "[srcmem, atom]" "ボディ命令"
             "所属膜がsrcmemのアトム $atom に対して、Cのコールバック関数を呼び出す")
            (("changevars") "[[memargs...], [atomargs...], [varargs...]]" "未使用命令"
             "")
            (("clearrules") "[dstmem]" "ボディ命令"
             "膜 $dstmem にある全てのルールを消去する。")
            (("commit") "[rulename, lineno]" "--"
             "トレースとデバッガに必要な情報を保持する. トレース用にルール名を文字列で保持. デバッガ用にソース上の行番号linenoを整数で保持. sakurai")
            (("connectruntime") "[srcatom]" "分散拡張用ガード命令"
             "アトム $srcatom が文字列ファンクタを持つことを確認し、 その文字列が表すノードに接続できることを確認する。 文字列が空のときはつねに成功する。 ルールの右辺に{..}@Hがあるときに使用される。文字列を使うのは仮仕様だがおそらく変えない。 追記(nakajima: 2004-01-12) 方法7（分散版）では、指定ホストにVMが無かったら作る。あったら生存確認。 新方式1では、生存確認のみ。新規作成はボディ命令に移動。")
            (("copyatom") "[-dstatom, mem, srcatom]" "--"
             "copygroundtermに移行すべきかもしれない。")
            (("copycells") "[-dstmap, dstmem, srcmem]" "（予約された）ボディ命令"
             "再帰的にロックされた膜 $srcmem の内容のコピーを作成し,膜 $dstmem に入れる. その際、リンク先がこの膜の(子膜を含めて)中に無いアトムの情報を コピーされるアトムオブジェクト -> コピーされたアトムオブジェクト (2005/01/13 従来のAtom.idからの参照を変更) というMapオブジェクトとして,dstmapに入れる.")
            (("copyground") "[-dstlist, srclinklist, dstmem]" "--"
             "（基底項プロセスを指す）リンク列 $srclinklist を $dstmem に複製し、  $dstlist の第1要素はコピーされたリンク列を， 第二要素にはコピー元のアトムからコピー先のアトムへのマップがそれぞれ格納される．")
            (("copyrules") "[dstmem, srcmem]" "ボディ命令"
             "膜 $srcmem にある全てのルールを膜 $dstmem にコピーする。 注意　Ruby版のinheritrulesから名称変更")
            (("deleteconnectors") "[srcset, srcmap]" "--"
             "$srcset に含まれる'='アトムをコピーしたアトムを $srcmap から得て、 削除し、リンクをつなぎなおす。")
            (("dequeueatom") "[srcatom]" "最適化用ボディ命令"
             "アトム $srcatom がこの計算ノードにある実行アトムスタックに入っていれば、スタックから取り出す。 注意　この命令は、メモリ使用量のオーダを削減するために任意に使用することができる。 アトムを再利用するときは、因果関係に注意すること。 なお、他の計算ノードにある実行アトムスタックの内容を取得/変更する命令は存在しない。 この命令は、Runtime.Atom.dequeueを呼び出す。")
            (("deref") "[-dstatom, srcatom, srcpos, dstpos]" "出力するガード命令"
             "アトム $srcatom の第srcpos引数のリンク先が第dstpos引数に接続していることを確認したら、 リンク先のアトムへの参照を $dstatom に代入する。")
            (("derefatom") "[-dstatom, srcatom, srcpos]" "出力する失敗しない最適化用＋型付き拡張用ガード命令"
             "アトム $srcatom の第srcpos引数のリンク先のアトムへの参照を $dstatom に代入する。 引き続き $dstatom が、単項アトム（整数なども含む）や自由リンク管理アトムと マッチするかどうか検査する場合に使用することができる。")
            (("dereffunc") "[-dstfunc, srcatom, srcpos]" "出力する失敗しない拡張ガード命令"
             "アトム $srcatom の第srcpos引数のリンク先のアトムのファンクタを取得し、 $dstfunc に代入する。 引き続き、型付き単項アトムのマッチングを行うために使用される。 単項アトムでない型付きプロセス文脈は、リンクオブジェクトを使って操作する。 derefatom[dstatom,srcatom,srcpos];getfunc[dstfunc,dstatom]と同じなので廃止？")
            (("dereflink") "[-dstatom, srclink, dstpos]" "出力する最適化用ガード命令"
             "リンク $srclink が第dstpos引数に接続していることを確認したら、 リンク先のアトムへの参照を $dstatom に代入する。")
            (("dropmem") "[srcmem]" "（予約された）ボディ命令"
             "再帰的にロックされた膜 $srcmem を破棄する。 この膜や子孫の膜をルート膜とするタスクは強制終了する。")
            (("enqueueallatoms") "[srcmem]" "（予約された）ボディ命令"
             "何もしない。または、膜 $srcmem にある全てのアクティブアトムをこの膜の実行アトムスタックに積む。 アトムがアクティブかどうかを判断するには、 ファンクタを動的検査する方法と、2つのグループのアトムがあるとして所属膜が管理する方法がある。")
            (("enqueueatom") "[srcatom]" "ボディ命令"
             "アトム $srcatom を所属膜の実行アトムスタックに積む。 すでに実行アトムスタックに積まれていた場合の動作は未定義とする。 アトム $srcatom がシンボルファンクタを持たない場合の動作も未定義とする。 アクティブかどうかによって命令の動作は変わらない。 むしろこの命令で積まれるアトムがアクティブである。")
            (("enqueuemem") "[srcmem]" "--"
             "ロックされた膜 $srcmem をロックしたまま活性化する。 この場合の活性化は、 $srcmem がルート膜の場合、仮の実行膜スタックに積むことを意味し、 ルート膜でない場合、親膜と同じ実行膜スタックに積むことを意味する。 すでに実行膜スタックまたは仮の実行膜スタックに積まれている場合は、何もしない。")
            (("eqatom") "[atom1, atom2]" "ガード命令"
             "$atom1 と $atom2 が同一のアトムを参照していることを確認する。 注意 Ruby版のeqから分離")
            (("eqfunc") "[func1, func2]" "型付き拡張用ガード命令"
             "ファンクタ $func1 と $func2 が等しいことを確認する。")
            (("eqground") "[link1,link2]" "（予約された）拡張ガード命令"
             "（どちらかが基底項プロセスを指すとわかっている） 2つのリンクlink1とlink2に対して、 それらが同じ形状の基底項プロセスであることを確認する。")
            (("eqmem") "[mem1, mem2]" "ガード命令"
             "$mem1 と $mem2 が同一の膜を参照していることを確認する。 注意 Ruby版のeqから分離")
            (("findatom") "[-dstatom, srcmem, funcref]" "反復するガード命令"
             "膜 $srcmem にあってファンクタfuncrefを持つアトムへの参照を次々に $dstatom に代入する。")
            (("findproccxt") "[atom1, length1, arg1, atom2, length2, arg2]" "--"
             "アトム番号atom1(価数=lenght1)の第arg1引数の型付きプロセス文脈が、 アトム番号atom2(価数=lenght2)の第arg2引数の型付きプロセス文脈と同名であることを示す 必ず(atom1,arg1)がオリジナル、(atom2,arg2)が新たに生成された名前になるよう配置されている")
            (("freeatom") "[srcatom]" "最適化用ボディ命令"
             "何もしない。  $srcatom がどの膜にも属さず、かつこの計算ノード内の実行アトムスタックに積まれていないことを表す。 アトムを他の計算ノードで積んでいる場合、輸出表の整合性は大丈夫か調べる。 → 輸出表は作らないことにしたので大丈夫。")
            (("freeground") "[srclinklist]" "--"
             "基底項プロセス $srclinklist がどの膜にも属さず、かつスタックに積まれていないことを表す。")
            (("freemem") "[srcmem]" "ボディ命令"
             "膜 $srcmem を廃棄する。  $srcmem がどの膜にも属さず、かつスタックに積まれていないことを表す。")
            (("func") "[srcatom, funcref]" "ガード命令"
             "アトム $srcatom がファンクタfuncrefを持つことを確認する。 getfunc[tmp,srcatom];loadfunc[func,funcref];eqfunc[tmp,func] と同じ。")
            (("getclass") "[-stringatom, atom]" "出力するガード命令"
             "アトム $atom がObjectFunctorまたはそのサブクラスのファンクタを持つことを確認し、 格納されたオブジェクトのクラスの完全修飾名文字列を表すファンクタを持つアトムを生成し、  $stringatom に代入する。 ただし、Translator を利用した場合、同一ソースのInlineコードで定義されたクラスに関しては単純名を取得する。(2005/10/17 Mizuno )")
            (("getclassfunc") "[-stringfunc, func]" "出力するガード命令"
             "ファンクタ $func がObjectFunctorまたはそのサブクラスであることを確認し、 格納されたオブジェクトのクラスの完全限定（修飾）名文字列を表すファンクタを生成し、  $stringfunc に代入する。 ただし、Translator を利用した場合、同一ソースのInlineコードで定義されたクラスに関しては単純名を取得する。(2005/10/17 Mizuno )")
            (("getfromlist") "[-dst, list, pos]" "--"
             "$list からpos番目の要素を $dst に取得する")
            (("getfunc") "[-func, atom]" "出力する失敗しない拡張ガード命令"
             "アトム $atom のファンクタへの参照を $func に代入する。")
            (("getlink") "[-link, atom, pos]" "出力する失敗しない拡張ガード命令"
             "最適化用ボディ命令 アトム $atom の第pos引数に格納されたリンクオブジェクトへの参照を $link に代入する。 典型的には、 $atom はルールヘッドに存在する。")
            (("getmem") "[-dstmem, srcatom, memtype, memname]" "ガード命令"
             "アトム $srcatom の所属膜への参照をロックせずに $dstmem に代入する。 所属膜が $memtype で表せるタイプでは無い場合は失敗する。 所属膜の名前がmemnameでない場合は失敗する。 アトム主導テストで使用される。")
            (("getnum") "[hyperlink, atom]" "--"
             "hyperlinkの要素数をatomに返すことを示す")
            (("getparent") "[-dstmem, srcmem]" "ガード命令"
             "（ロックしていない）膜 $srcmem に対して、その親膜への参照をロックせずに $dstmem に代入する。 親膜が無い場合は失敗する。 アトム主導テストで使用される。")
            (("getruntime") "[-dstatom, srcmem]" "--"
             "失敗しない分散拡張用ガード命令 膜 $srcmem （を管理するタスク）が所属するノードを表す文字列ファンクタを持つ 所属膜を持たない文字列アトムを生成し、 $dstatom に代入する。 ただし上記の仕様はルート膜のときのみ。ルート膜でない膜に対しては空文字列が得られる。 ルールの左辺に{..}@Hがあるときに使用される。文字列を使うのは仮仕様だがおそらく変えない。")
            (("group") "[subinsts]" "--"
             "subinsts 内部の命令列 sakurai")
            (("iadd" "isub" "imul" "idiv" "ineg" "imod" "inot" "iand" "ior" "ixor") "[-dstintatom, intatom1, intatom2]" "整数用の組み込み命令"
             "整数アトムの加算結果を表す所属膜を持たない整数アトムを生成し、 $dstintatom に代入する。 idivおよびimodに限り失敗する。")
            (("iaddfunc" "isubfunc" "imulfunc" "idivfunc" "inegfunc" "imodfunc" "inotfunc" "iandfunc" "iorfunc" "ixorfunc" "isalfunc" "isarfunc" "ishrfunc") "[-dstintfunc, intfunc1, intfunc2]" "整数用の最適化用組み込み命令"
             "整数ファンクタの加算結果を表す整数ファンクタを生成し、 $dstintfunc に代入する。 idivfuncおよびimodfuncに限り失敗する。")
            (("ilt" "ile" "igt" "ige" "ieq" "ine") "[intatom1, intatom2]" "整数用の組み込みガード命令"
             "整数アトムの値の大小比較が成り立つことを確認する。")
            (("iltfunc" "ilefunc" "igtfunc" "igefunc" "fadd" "fsub" "fmul" "fdiv" "fneg" "faddfunc" "fsubfunc" "fmulfunc" "fdivfunc" "fnegfunc" "flt" "fle" "fgt" "fge" "feq" "fne" "fltfunc" "flefunc" "fgtfunc" "fgefunc") "[intfunc1, intfunc2]" "整数用の最適化用組み込みガード命令"
             "整数ファンクタの値の大小比較が成り立つことを確認する。")
            (("inheritlink") "[atom1, pos1, link2, mem]" "最適化用ボディ命令"
             "アトム $atom1 （膜 $mem にある）の第pos1引数と、 リンク $link2 のリンク先（膜 $mem にある）を接続する。 典型的には、 $atom1 はルールボディに存在し、 $link2 はルールヘッドに存在する。relinkの代用。  $link2 は再利用されるため、実行後は $link2 は廃棄しなければならない。 alloclink[link1,atom1,pos1];unifylinks[link1,link2,mem]と同じ。")
            (("inline") "[atom, string, inlineref]" "ガード命令、ボディ命令"
             "アトム $atom に対して、inlinerefが指定するインライン命令を適用し、成功することを確認する。 inlinerefには現在、インライン番号を渡すことになっているが、 ボディで呼ばれる場合、典型的には、全てのリンクを張り直した直後に呼ばれる。")
            (("insertconnectors") "[-dstset,linklist,mem]" "--"
             "linklistリストの各変数番号にはリンクオブジェクトが格納されている。 それらのリンクオブジェクトのリンク先は $mem 内のアトムである。 それらのリンクオブジェクトの全ての組み合わせに対し、buddyの関係にあるかどうかを検査し、 その場合には'='アトムを挿入する。 挿入したアトムを $dstset に追加する。")
            (("insertconnectorsinnull") "[-dstset,linklist]" "--"
             "linklistリストの各変数番号にはリンクオブジェクトが格納されている。 それらのリンクオブジェクトの全ての組み合わせに対し、buddyの関係にあるかどうかを検査し、 その場合には'='アトムを挿入する。 ただし'='は所属膜を持たない． 挿入したアトムを $dstset に追加する。 この命令は型付きプロセス文脈の複製に伴い発行される．")
            (("insertproxies") "[parentmem,childmem]" "ボディ命令"
             "指定された膜間に自由リンク管理アトムを自動挿入する。 addmemが全て終わった後で呼ばれる。")
            (("isal") "[-dstintatom, intatom1, intatom2]" "整数用の組み込み命令"
             "$intatom1 を $intatom2 ビット分符号つき(算術)左シフトした結果を表す所属膜を持たない整数アトムを生成し、 $dstintatom に代入する。")
            (("isar") "[-dstintatom, intatom1, intatom2]" "整数用の組み込み命令"
             "$intatom1 を $intatom2 ビット分符号つき(算術)右シフトした結果を表す所属膜を持たない整数アトムを生成し、 $dstintatom に代入する。")
            (("isbuddy") "[link1, link2]" "--"
             "$link1 が $link2 と接続されていることを確認する 2006/07/09 by kudo")
            (("isground") "[-natomsfunc, linklist, avolist]" "（予約された）ロック取得する拡張ガード命令"
             "リンク列 $linklist の指す先が基底項プロセスであることを確認する。 すなわち、リンク先から（戻らずに）到達可能なアトムが全てこの膜に存在していることを確認する。 ただし、 $avolist に登録されたリンクに到達したら失敗する。 見つかった基底項プロセスを構成するこの膜のアトムの個数（をラップしたInteger）を $natoms に格納する。 natomsとnmemsと統合した命令を作り、 $natoms の総和を引数に渡すようにする。 子膜の個数の照合は、本膜がロックしていない子膜の個数が0個かどうか調べればよい。 しかし本膜がロックしたかどうかを調べるメカニズムが今は備わっていないため、保留。 groundには膜は含まれないことになったので、上記は不要")
            (("ishlink") "[link]" "--"
             "link先に接続する構造がhyperlinkであることをチェックすることを示す")
            (("ishr") "[-dstintatom, intatom1, intatom2]" "整数用の組み込み命令"
             "$intatom1 を $intatom2 ビット分論理右シフトした結果を表す所属膜を持たない整数アトムを生成し、 $dstintatom に代入する。")
            (("isint" "isfloat" "isstring") "[atom]" "ガード命令"
             "アトム $atom が整数アトムであることを確認する。")
            (("isintfunc" "isfloatfunc" "isstringfunc") "[func]" "最適化用ガード命令"
             "ファンクタ $func が整数ファンクタであることを確認する。")
            (("isunary" "isunaryfunc") "[atom]" "ガード命令"
             "アトム $atom が1引数のアトムであることを確認する。")
            (("jump") "[instructionlist, [memargs...], [atomargs...], [varargs...]]" "--"
             "ただしbodyはinstructionlistの命令列で、先頭の命令はspec[formals,locals]")
            (("loadfunc") "[-func, funcref]" "出力する失敗しない拡張ガード命令"
             "ファンクタfuncrefへの参照を $func に代入する。")
            (("loadmodule") "[dstmem, ruleset]" "ボディ命令"
             "ルールセットrulesetを膜 $dstmem にコピーする。")
            (("loadruleset") "[dstmem, ruleset]" "ボディ命令"
             "ルールセットrulesetを膜 $dstmem にコピーする。 この膜のアクティブアトムは再エンキューすべきである。")
            (("lock") "[srcmem]" "ロック取得するガード命令"
             "膜 $srcmem に対して、ノンブロッキングでのロックを取得を試みる。 取得したロックは、後続の命令列が失敗したときに解放される。 アトム主導テストで、主導するアトムによって特定された膜のロックを取得するために使用される。")
            (("lockmem") "[-dstmem, freelinkatom, memname]" "ロック取得するガード命令"
             "自由リンク出力管理アトム $freelinkatom が所属する膜に対して、 ノンブロッキングでのロックを取得を試みる。 そしてロック取得に成功したこの膜への参照を $dstmem に代入する。 取得したロックは、後続の命令列がその膜に対して失敗したときに解放される。 ロック取得に成功すれば、この膜はまだ参照を（＝ロックを）取得していなかった膜である （この検査はRuby版ではneqmem命令で行っていた）。 膜の外からのリンクで初めて特定された膜への参照を取得するために使用される。")
            (("lookuplink") "[-dstlink, srcmap, srclink]" "--"
             "srclinkのリンク先のアトムのコピーを $srcmap より得て、 そのアトムをリンク先とする-dstlinkを作って返す。")
            (("loop") "[[instructions...]]" "構造化命令"
             "引数の命令列を実行することを表す。 引数実行中に失敗した場合、引数実行中に取得したロックを解放し、loopの次の命令に進む。 引数実行中にproceed命令を実行した場合、このloop命令の実行を繰り返す。")
            (("makehlink") "[ID, link]" "--"
             "過去に生成されたhyperlinkのうち, 識別子IDを持つhyperlinkを生成し, link先に接続することを示す （未実装、hyperlinkへの値の代入などに使用できるかも？）")
            (("movecells") "[dstmem, srcmem]" "ボディ命令"
             "（親膜を持たない）膜 $srcmem にある全てのアトムと子膜（ロックを取得していない）を膜 $dstmem に移動する。 子膜はルート膜の直前の膜まで再帰的に移動される。ホスト間移動した膜は活性化される。 実行後、膜 $srcmem はこのまま廃棄されなければならない。実行後、膜 $dstmem の全てのアクティブアトムをエンキューし直すべきである。 注意　Ruby版のpourから名称変更 moveCellsFromメソッドを呼び出す。")
            (("natoms") "[srcmem, count]" "ガード命令"
             "膜 $srcmem の自由リンク管理アトム以外のアトム数がcountであることを確認する。")
            (("natomsindirect") "[srcmem, countfunc]" "ガード命令"
             "膜 $srcmem の自由リンク管理アトム以外のアトム数が $countfunc の値であることを確認する。")
            (("neqatom") "[atom1, atom2]" "ガード命令"
             "$atom1 と $atom2 が異なるアトムを参照していることを確認する。 注意 Ruby版のneqから分離")
            (("neqfunc") "[func1, func2]" "型付き拡張用ガード命令"
             "ファンクタ $func1 と $func2 が異なることを確認する。")
            (("neqground") "[link1,link2]" "拡張ガード命令"
             "（どちらかが基底項プロセスを指すとわかっている） 2つのリンクlink1とlink2に対して、 それらが同じ形状の基底項プロセスでないことを確認する。")
            (("neqmem") "[mem1, mem2]" "ガード命令"
             "$mem1 と $mem2 が異なる膜を参照していることを確認する。 注意 Ruby版のneqから分離 この命令は不要かも知れない")
            (("newatom") "[-dstatom, srcmem, funcref]" "ボディ命令"
             "膜 $srcmem にファンクタfuncrefを持つ新しいアトム作成し、参照を $dstatom に代入する。 アトムはまだ実行アトムスタックには積まれない。")
            (("newatomindirect") "[-dstatom, srcmem, func]" "型付き拡張用ボディ命令"
             "膜 $srcmem にファンクタ $func を持つ新しいアトム作成し、参照を $dstatom に代入する。 アトムはまだ実行アトムスタックには積まれない。")
            (("newhlink") "[link]" "--"
             "新たなhyperlinkを生成し, link先に接続することを示す")
            (("newlink") "[atom1, pos1, atom2, pos2, mem1]" "ボディ命令"
             "アトム $atom1 （膜 $mem1 にある）の第pos1引数と、 アトム $atom2 の第pos2引数の間に両方向リンクを張る。 典型的には、 $atom1 と $atom2 はいずれもルールボディに存在する。 注意　Ruby版の片方向から仕様変更された。 alloclink[link1,atom1,pos1];alloclink[link2,atom2,pos2];unifylinks[link1,link2,mem1]と同じ。")
            (("newlinklist") "[-dstlist]" "--"
             "新しいリンクのリストを作る")
            (("newmem") "[-dstmem, srcmem, memtype]" "ボディ命令"
             "（活性化された）膜 $srcmem に新しい（ルート膜でない） $memtype で表せるタイプの子膜を作成し、  $dstmem に代入し、活性化する。 この場合の活性化は、 $srcmem と同じ実行膜スタックに積むことを意味する。")
            (("newroot") "[-dstmem, srcmem, nodeatom, memtype]" "ボディ命令"
             "膜 $srcmem の子膜にアトム $nodeatom の名前で指定された計算ノードで実行される新しいロックされた  $memtype で表せるタイプのルート膜を作成し、参照を $dstmem に代入し、（ロックしたまま）活性化する。 この場合の活性化は、仮の実行膜スタックに積むことを意味する。 ただし上記の仕様は計算ノード指定が空文字列でないときのみ。 空文字列の場合は、newmemと同じだがロックされた状態で作られる。 newmemと違い、このルート膜のロックは明示的に解放しなければならない。")
            (("newset") "[-dstset]" "--"
             "新しいアトムセットを作る")
            (("nfreelinks") "[srcmem, count]" "ガード命令"
             "膜 $srcmem の自由リンク数がcountであることを確認する。")
            (("nmems") "[srcmem, count]" "ガード命令"
             "膜 $srcmem の子膜の数がcountであることを確認する。")
            (("norules") "[srcmem]" "ガード命令"
             "膜 $srcmem にルールが存在しないことを確認する。")
            (("not") "[instructionlist]" "（予約された）構造化命令"
             "引数の命令列を実行することを表す。引数列はロックを取得してはならない。 引数実行中に失敗した場合、notの次の命令に進む。 引数実行中にproceed命令を実行した場合、この命令が失敗する。 将来、否定条件のコンパイルに使用するために予約。")
            (("notfunc") "[srcatom, funcref]" "ガード命令"
             "アトム $srcatom がファンクタfuncrefを持たないことを確認する。 典型的には、プロセス文脈の明示的な自由リンクの出現アトムが $inside _proxyでないことを確認するために使われる。 getfunc[tmp,srcatom];loadfunc[func,funcref];neqfunc[tmp,func] と同じ。")
            (("react") "[ruleref, [memargs...], [atomargs...], [varargs...]]" "未使用命令"
             "")
            (("recursivelock") "[srcmem]" "（予約された）ガード命令"
             "膜 $srcmem の全ての子膜に対して再帰的にロックを取得する。 右辺での出現が1回でないプロセス文脈が書かれた左辺の膜に対して使用される。 デッドロックが起こらないことを保証できれば、この命令はブロッキングで行うべきである。")
            (("recursiveunlock") "[srcmem]" "（予約された）ボディ命令"
             "膜 $srcmem の全ての子膜に対して再帰的にロックを解放する。 膜はそれを管理するタスクの実行膜スタックに再帰的に積まれる。 再帰的に積む方法は、今後考える。")
            (("relink") "[atom1, pos1, atom2, pos2, mem]" "--"
             "alloclink[link1,atom1,pos1];getlink[link2,atom2,pos2];unifylinks[link1,link2,mem]と同じ。")
            (("removeatom") "[srcatom, srcmem, funcref]" "ボディ命令"
             "（膜 $srcmem にあってファンクタ $func を持つ）アトム $srcatom を現在の膜から取り出す。 実行アトムスタックは操作しない。")
            (("removeground") "[srclinklist,srcmem]" "--"
             "$srcmem に属する（基底項プロセスを指す）リンク列 $srclinklist を現在の膜から取り出す。 実行アトムスタックは操作しない。")
            (("removemem") "[srcmem, parentmem]" "ボディ命令"
             "膜 $srcmem を親膜（ $parentmem ）から取り出す。 実行膜スタックに積まれている場合は除去する。")
            (("removeproxies") "[srcmem]" "ボディ命令"
             "$srcmem を通る無関係な自由リンク管理アトムを自動削除する。 removememの直後に同じ膜に対して呼ばれる。")
            (("removetemporaryproxies") "[srcmem]" "ボディ命令"
             "膜 $srcmem （本膜）に残された\"star\"アトムを除去する。 insertproxiesが全て終わった後で呼ばれる。")
            (("removetoplevelproxies") "[srcmem]" "ボディ命令"
             "膜 $srcmem （本膜）を通過している無関係な自由リンク管理アトムを除去する。 removeproxiesが全て終わった後で呼ばれる。")
            (("resetvars") "[[memargs...], [atomargs...], [varargs...]]" "--"
             "")
            (("run") "[[instructions...]]" "（予約された）構造化命令"
             "引数の命令列を実行することを表す。引数列はロックを取得してはならない。 引数実行中に失敗した場合、runの次の命令に進む。 引数実行中にproceed命令を実行した場合、次の命令に進む。 将来、明示的な引数付きのプロセス文脈のコンパイルに使用するために予約。")
            (("samefunc") "[atom1, atom2]" "ガード命令"
             "$atom1 と $atom2 が同じファンクタを持つことを確認する。 getfunc[func1,atom1];getfunc[func2,atom2];eqfunc[func1,func2]と同じ。")
            (("setmemname") "[dstmem, name]" "ボディ命令"
             "膜 $dstmem の名前を文字列（またはnull）nameに設定する。 現在、膜の名前の使用目的は表示用のみ。いずれ、膜名に対するマッチングができるようになるはず。")
            (("spec") "[formals, locals]" "制御命令"
             "仮引数と局所変数の個数を宣言する。 局所変数の個数が不足している場合、変数ベクタを拡張する。")
            (("stable") "[srcmem]" "ガード命令"
             "膜 $srcmem とその子孫の全ての膜の実行が停止していることを確認する。")
            (("subclass") "[atom1, atom2]" "--"
             "atom1 が atom2 のサブクラスかどうかを判定する 2006.6.30 by inui")
            (("systemrulesets") "[subinsts1, subinsts2, vars]" "--"
             "subinsts1 展開したシステムルールセット subinsts2 システムルールセット内で失敗したときに実行する命令列 vars この変数番号が定義されていなければsubinsts1は実行できない sakurai")
            (("testmem") "[dstmem, srcatom]" "ガード命令"
             "アトム $srcatom が（ロックされた）膜 $dstmem に所属することを確認する。 注意　Ruby版ではgetmemで参照を取得した後でeqmemを行っていた。")
            (("unify") "[atom1, pos1, atom2, pos2, mem]" "ボディ命令"
             "アトム $atom1 の第pos1引数のリンク先の引数と、 アトム $atom2 の第pos2引数のリンク先の引数を接続する。 $atom1  と  $atom2  の両方もしくは一方が所属膜を持たない場合もある。 これは a(A),f(A,B),(a(X),f(Y,Z):-Y=Z,b(X)) の書き換えなどで起こる。 典型的には、 $atom1 と $atom2 はいずれもルールヘッドに存在する。 getlink[link1,atom1,pos1];getlink[link2,atom2,pos2];unifylinks[link1,link2,mem]と同じ。")
            (("unifyhlinks") "[mem, unify_atom]" "--"
             "膜memにあるunify_atom\"><\"に対してhyperlinkの併合操作を行なうことを示す")
            (("unifylinks") "[link1, link2, mem]" "ボディ命令"
             "リンク $link1 の指すアトム引数とリンク $link2 の指すアトム引数との間に双方向のリンクを張る。 ただし $link1 は膜 $mem のアトムを指しているか、または所属膜の無いアトムを指している。 後者の場合、何もしないで終わってもよいことになっている。 todo 命令の解釈時にmem引数が使われることはないので、引数に含めないようにした方がよい。 実行後 $link1 および $link2 は無効なリンクオブジェクトとなるため、参照を使用してはならない。 基底項データ型のコンパイルで使用される。")
            (("uniq") "[ [Links...] ]" "拡張ガード命令"
             "型付きプロセス文脈 Links... に対して、過去にこの組み合わせで反応が起きていたら失敗する。 起きていなかったら履歴にこの組み合わせを記録して成功する。")
            (("unlockmem") "[srcmem]" "ボディ命令"
             "（活性化した）膜 $srcmem のロックを解放する。  $srcmem がルート膜の場合、仮の実行膜スタックの内容を実行膜スタックの底に転送する。 addmemによって再利用された膜、およびnewrootによってルールで新しく生成された ルート膜に対して、（子孫から順番に）必ず呼ばれる。 実行後、 $srcmem への参照は廃棄しなければならない。")
            (("newlist") "[-dstlist]" "--"
             "新しいリストを作る。")
            (("proceed") "[]" "--"
             "命令列を成功終了する。")))
    hash))

(defun lmntal-slimcode-help ()
  "show help for SLIM operations."
  (interactive)
  (let* ((op (completing-read
              "Operation: " lmntal-slimcode--help-table nil t
              (save-excursion
                (back-to-indentation)
                (when (looking-at "[a-z]*") (match-string 0)))))
         (doc (gethash op lmntal-slimcode--help-table nil)))
    (with-current-buffer (get-buffer-create "*SLIMcode-help*")
      (erase-buffer)
      (cl-destructuring-bind (ops arglst type description) doc
        (insert (car ops) " " arglst "\n"
                "(" (mapconcat 'identity ops ", ") ")\n\n"
                type "\n" description "\n"))
      (goto-char (point-min))
      (display-buffer (current-buffer))
      (toggle-truncate-lines -1)
      (recenter 0)
      (run-hooks 'lmntal-slimcode-help-hook))))

(defun lmntal-slimcode-eldoc-function ()
  "an eldoc function for SLIMcode."
  (save-excursion
    (back-to-indentation)
    (when (looking-at "[a-z]+")
      (cadr (gethash (match-string 0) lmntal-slimcode--help-table nil)))))

;; the mode

;;;###autoload
(define-derived-mode lmntal-slimcode-mode prog-mode "SLIMcode"
  "major mode for reading slimcodes"
  :group 'lmntal
  :syntax-table lmntal-syntax-table
  (set (make-local-variable 'eldoc-documentation-function) 'lmntal-slimcode-eldoc-function)
  (set (make-local-variable 'imenu-create-index-function) 'lmntal-slimcode-imenu-function)
  (set (make-local-variable 'indent-line-function) 'lmntal-slimcode-indent-line)
  (set (make-local-variable 'comment-start) "//")
  (set (make-local-variable 'comment-end) "")
  (set (make-local-variable 'font-lock-defaults) '(lmntal-slimcode-font-lock-keywords))
  (set (make-local-variable 'electric-indent-chars) '(?\]))
  (eldoc-mode 1))

;;   + lmntal-trace-mode

(defvar lmntal-trace-font-lock-keywords
  '(
    ;; messages
    ("^shuffle level [123]"
     . font-lock-comment-face)
    ;; step numbers
    ("^[0-9]*:"
     . font-lock-comment-face)
    ;; application
    ("^.*-->.*$"
     . font-lock-keyword-face)
    ;; rule-names
    ("\\_<@[a-zA-Z0-9_]*@?\\_>"
     . 'lmntal-rule-name-face)
    ;; module-names
    ("{module([^)]*)}"
     . font-lock-comment-face)
    ;; hyperlinks
    ("\\_<![a-zA-Z0-9_]*\\_>"
     . 'lmntal-link-name-face)
    ;; link-variables
    ("\\_<[A-Z][a-zA-Z0-9_]*\\_>"
     . 'lmntal-link-name-face)
    ;; membranes
    ("[{}]" . font-lock-type-face)
    ;; lists
    ("[][|]" . font-lock-variable-name-face)
    )
  "highlighting expressions for LMNtal-trace mode")

(define-derived-mode lmntal-trace-mode special-mode "LMNtal-trace"
  "major mode for reading LMNtal traces"
  :group 'lmntal
  :syntax-table lmntal-syntax-table
  (setq truncate-lines nil)
  (set (make-local-variable 'font-lock-defaults) '(lmntal-trace-font-lock-keywords))
  (add-hook 'post-command-hook 'lmntal--highlight-update nil t))

;;   + lmntal-mc-mode

(defvar lmntal-mc-font-lock-keywords
  '(
    ;; messages
    ("^\\(States\\|Transitions\\)"
     . font-lock-keyword-face)
    ;; step numbers
    ("^\\([0-9]*:\\|init:[0-9]*\\)"
     . font-lock-comment-face)
    ;; hyperlinks
    ("\\_<![a-zA-Z0-9_]*\\_>"
     . 'lmntal-link-name-face)
    ;; link-variables
    ("\\_<[A-Z][a-zA-Z0-9_]*\\_>"
     . 'lmntal-link-name-face)
    ;; membranes
    ("[{}]" . font-lock-type-face)
    ;; lists
    ("[][|]" . font-lock-variable-name-face)
    )
  "highlighting expressions for LMNtal-mc mode")

(define-derived-mode lmntal-mc-mode special-mode "LMNtal-mc"
  "major mode for reading results of LMNtal model check"
  :group 'lmntal
  :syntax-table lmntal-syntax-table
  (view-mode)
  (set (make-local-variable 'font-lock-defaults) '(lmntal-mc-font-lock-keywords)))

;; + provide

(add-to-list 'auto-mode-alist '("\\.lmn$" . lmntal-mode))
(add-to-list 'auto-mode-alist '("\\.il$" . lmntal-slimcode-mode))

(provide 'lmntal-mode)

;;; lmntal-mode.el ends here
