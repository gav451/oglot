;;; oglot.el --- Org source blocks with Eglot -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Gerard Vermeulen

;; Author: Gerard Vermeulen <gerard.vermeulen@posteo.net>
;; Version: 0.2
;; Keywords: hypermedia, languages, text
;; Package-Requires: ((emacs "28.1") (eglot "1.9"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Oglot (Org source blocks with Eglot) builds on the idea of the
;; https://www.reddit.com/r/emacs/comments/w4f4u3 post to facititate
;; the analyis of Org source code blocks with LSP servers.  This
;; requires installing suitable LSP servers and tangling of the Org
;; source blocks.  Note: https://github.com/brotzeit/rustic supports
;; Rust source blocks by means of
;; https://github.com/brotzeit/rustic/blob/master/rustic-babel.el.

;; Oglot tries to locate an Org source block in a tangled file when
;; calling `org-edit-src-code'.  In case of success, it visits the
;; tangled file in the `org-src-mode' buffer and narrows the buffer to
;; the block before launching Eglot on the tangled file.  Oglot
;; ensures also to delete the invisible regions outside the narrowed
;; block before calling `org-edit-src-exit' or `org-edit-src-save'.

;; Oglot works well with https://github.com/python-lsp/python-lsp-ruff
;; and Python, but it should also work with other languages and
;; servers: add your language mode to `oglot-maybe-ensure-modes' and
;; define an `org-babel-edit-prep:<LANGUAGE>' function similar to
;; `org-babel-edit-prep:python' using `oglot-org-babel-edit-prep'.

;; Oglot works with https://github.com/non-Jedi/eglot-jl and
;; https://github.com/julia-vscode/LanguageServer.jl, but the server
;; startup time is too long for small snippets and the server is too
;; verbose.

;; Oglot also allows to control tangling: synchronizing an Org file
;; with a tangled file works best after tangling the Org file with the
;; header arguments property ":comments link".  Toggling this property
;; allows to use those comments for internal use and to nuke them for
;; external use (by using e.g. `oglot-python-comments-link-toggle').

;;; Code:

(declare-function org-ctrl-c-ctrl-c "org" (&optional arg))

;; Basic functionality:

(defgroup oglot nil
  "Org source blocks with Eglot."
  :group 'text)

(defun oglot-org-babel-edit-prep (info)
  "Try to setup an `org-mode-src' buffer to make `eglot-ensure' succeed.
INFO has a form similar to the return value of
`org-babel-get-src-block-info'.  Try to load the tangled file
into the `org-src-mode' buffer as well as to narrow the region to
the Org-mode source block code before calling `eglot-ensure'."
  (when-let ((ok (bound-and-true-p org-src-mode))
             (point (point))
             (body (nth 1 info))
             (filename (cdr (assq :tangle (nth 2 info)))))
    (when (string= filename "no")
      (setq ok nil)
      (message "Org source block has no tangled file"))
    (when ok
      (setq filename (expand-file-name filename))
      (unless (file-readable-p filename)
        (setq ok nil)
        (message "Tangled file %s is not readable" filename)))
    (when ok
      (with-temp-buffer
        (insert-file-contents filename 'visit nil nil 'replace)
        (unless (search-forward body nil 'noerror)
          (setq ok nil)
          (message "Org source block does not occur in tangled file %s"
                   filename))
        (when (search-forward body nil 'noerror)
          (setq ok nil)
          (message
           "Org source block occurs twice or more in tangled file %s"
           filename))))
    (when ok
      (goto-char (point-min))
      (insert-file-contents filename 'visit nil nil 'replace)
      (search-forward body)
      ;; The next line preserves point in the `org-src-mode' buffer.
      (goto-char (+ (match-beginning 0) point -1))
      (narrow-to-region (match-beginning 0) (match-end 0))
      (eglot-ensure))))

(defcustom oglot-maybe-ensure-modes nil
  "Modes where calling `org-edit-src-code' will call `eglot-ensure'.
Using `setopt', it is safe to add modes, but unsafe to remove modes.
Only `python-mode' works for sure and `julia-mode' works but has rough
edges.  The status of the modes `f90-mode', `fortran-mode',
`haskell-mode', `lua-mode', and `ruby-mode' is unsure.  Support for
other modes requires to update `oglot'.  Be careful not to redefine
`org-babel-edit-prep:elisp', `org-babel-edit-prep:emacs-lisp', and
`org-babel-edit-prep:sql'."
  :group 'oglot
  :version "0.1"
  :type '(repeat (symbol :tag "Major mode"))
  :initialize 'custom-initialize-set
  :set (lambda (var val)
         (if (not (featurep 'oglot))
             (set-default-toplevel-value var val)
           (set-default var val)
           (when (member 'f90-mode val)
             (defun org-babel-edit-prep:f90 (info)
               "Oglot `org-babel-edit-prep:<LANG>' for Fortran 90 and 95."
               (oglot-org-babel-edit-prep info)))
           (when (member 'fortran-mode val)
             (defun org-babel-edit-prep:fortran (info)
               "Oglot `org-babel-edit-prep:<LANG>' for Fortran 77."
               (oglot-org-babel-edit-prep info)))
           (when (member 'julia-mode val)
             (defun org-babel-edit-prep:julia (info)
               "Oglot `org-babel-edit-prep:<LANG>' for Julia."
               (oglot-org-babel-edit-prep info)))
           (when (member 'haskell-mode val)
             (defun org-babel-edit-prep:haskell (info)
               "Oglot `org-babel-edit-prep:<LANG>' for Haskell."
               (oglot-org-babel-edit-prep info)))
           (when (member 'lua-mode val)
             (defun org-babel-edit-prep:lua (info)
               "Oglot `org-babel-edit-prep:<LANG>' for Lua."
               (oglot-org-babel-edit-prep info)))
           (when (member 'python-mode val)
             (defun org-babel-edit-prep:python (info)
               "Oglot `org-babel-edit-prep:<LANG>' for Python."
               (oglot-org-babel-edit-prep info)))
           (when (member 'ruby-mode val)
             (defun org-babel-edit-prep:ruby (info)
               "Oglot `org-babel-edit-prep:<LANG>' for Ruby."
               (oglot-org-babel-edit-prep info))))))

(defun oglot-undo-org-babel-edit-prep()
  "Undo the `eglot' setup by deleting the text hidden by narrowing.
This is to advice `org-edit-src-exit' and `org-edit-src-save'."
  (when (and (bound-and-true-p org-src-mode)
             (apply #'derived-mode-p oglot-maybe-ensure-modes))
    (save-excursion
      (goto-char (point-min))
      (save-restriction
        (widen)
        (delete-region (point-min) (point)))
      (goto-char (point-max))
      (save-restriction
        (widen)
        (delete-region (point) (point-max))))))

(advice-add 'org-edit-src-exit :before #'oglot-undo-org-babel-edit-prep)
(advice-add 'org-edit-src-save :before #'oglot-undo-org-babel-edit-prep)

;; Tangling control:

(defconst oglot-comments-link-re
  "\\( :comments link$\\)\\|\\( *$\\)"
  "Regexp to find \"#+property:\" \":comments link\".")

(defconst oglot-ha-re-template
  (format "\\(?:^[[:blank:]]*#\\+%s:[[:blank:]]+%s:%s\\+*\\)+"
          "property" "header-args" "%s")
  "Regexp template to find `#+property:' header-args:any-language.")

(defconst oglot-emacs-lisp-ha-re
  (format oglot-ha-re-template "emacs-lisp")
  "Regexp to find `#+property:' Emacs Lisp header arguments.")

(defconst oglot-f90-ha-re
  (format oglot-ha-re-template "f90")
  "Regexp to find `#+property:' Fortran 90 and 95 header arguments.")

(defconst oglot-fortran-ha-re
  (format oglot-ha-re-template "fortran")
  "Regexp to find `#+property:' Fortran 77 header arguments.")

(defconst oglot-julia-ha-re
  (format oglot-ha-re-template "julia")
  "Regexp to find `#+property:' Julia header arguments.")

(defconst oglot-haskell-ha-re
  (format oglot-ha-re-template "haskell")
  "Regexp to find `#+property:' Haskell header arguments.")

(defconst oglot-lua-ha-re
  (format oglot-ha-re-template "lua")
  "Regexp to find `#+property:' Lua header arguments.")

(defconst oglot-python-ha-re
  (format oglot-ha-re-template "python")
  "Regexp to find `#+property:' Python header arguments.")

(defconst oglot-ruby-ha-re
  (format oglot-ha-re-template "ruby")
  "Regexp to find `#+property:' Ruby header arguments.")

(when nil
  ;; Use a macro to generate `oglot-ID-comments-link-toggle' commands.
  ;; This definition shows what the macro should be able to produce.
  ;; Therefore, use ID in symbols and NAME in strings.
  (defun oglot-python-comments-link-toggle ()
    "Toggle \":comments link\" in Python header arguments properties."
    (interactive)
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward oglot-python-ha-re nil 'noerror)
          (when (re-search-forward oglot-comments-link-re nil t)
            (if (match-string 1)
                (replace-match " ")
              (replace-match " :comments link"))
            (org-ctrl-c-ctrl-c))
        (user-error "Found no Python header arguments property")))))

(defmacro oglot--comments-link-toggle (id name)
  "Generate `oglot-ID-comments-link-toggle' commands. Use NAME in strings."
  `(defun ,(intern (format "oglot-%s-comments-link-toggle" id)) ()
     ,(format
       "Toggle \":comments link\" in %s header arguments properties." name)
     (interactive)
     (save-excursion
       (goto-char (point-min))
       (if (re-search-forward ,(intern (format "oglot-%s-ha-re" id))
                              nil 'noerror)
           (when (re-search-forward oglot-comments-link-re nil t)
             (if (match-string 1)
                 (replace-match " ")
               (replace-match " :comments link"))
             (org-ctrl-c-ctrl-c))
         (user-error
          ,(format "Found no %s header arguments property" name))))))

(oglot--comments-link-toggle "emacs-lisp" "Emacs Lisp")
(oglot--comments-link-toggle "f90" "Fortran 90 and 95")
(oglot--comments-link-toggle "fortran" "Fortran 77")
(oglot--comments-link-toggle "haskell" "Haskell")
(oglot--comments-link-toggle "julia" "Julia")
(oglot--comments-link-toggle "lua" "Lua")
(oglot--comments-link-toggle "python" "Python")
(oglot--comments-link-toggle "ruby" "Ruby")

(provide 'oglot)
;;; oglot.el ends here
