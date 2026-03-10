;;; vibe-mode.el --- Major mode for editing Vibe source files  -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Vibe Project
;;
;; Author: Vibe Project
;; Maintainer: Vibe Project
;; Created: 2025
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: languages, vibe, scheme, llvm
;; URL: https://github.com/vibe-lang/vibe

;;; Commentary:
;;
;; vibe-mode is a major mode for editing Vibe source files (.vibe).
;; Vibe is a R7RS Small Scheme derivative that compiles to LLVM bitcode.
;;
;; This mode is derived from scheme-mode and adds custom indentation for
;; Vibe-specific define-like forms (llvm:define-function, llvm:define-type,
;; etc.) so that body forms indent one level instead of aligning to the
;; first argument as scheme-mode does for standard define.
;;
;; To use: Add (load "path/to/vibe-mode.el") to your init file, or add
;; the emacs directory to your load-path.
;;
;;   (add-to-list 'load-path "~/Source/vibe/emacs")
;;   (require 'vibe-mode)

;;; Code:

(require 'scheme)

(defgroup vibe nil
  "Major mode for editing Vibe source files."
  :group 'languages
  :prefix "vibe-")

(defcustom vibe-indent-offset 2
  "Indentation offset for Vibe forms.
Used for define-like forms (llvm:define-function, etc.) where
body is indented one level."
  :type 'integer
  :safe 'integerp
  :group 'vibe)

;; Forms whose body should indent 1 level (not align to first argument).
;; scheme-mode treats define-like forms specially; these Vibe forms
;; should use simple one-level indentation for their body.
;;
;; Indent spec: N means first N args are "header", arg N+1 indents.
;; - Spec 2: (llvm:define-function (sig) return-type body...) - sig+return are header
;; - Spec 1: (llvm:define-type Name (field type)...) - only Name is header
(defconst vibe-indent-specs
  '((llvm:define-function . 2)
    (llvm:define-type . 1)
    (llvm:define-constant . 2)
    (llvm:define-ffi-function . 2)
    (llvm:declare-function . 2)
    (llvm:label . 1)
    (define-bitcode-function . 2)
    (define-bitcode . 2))
  "Alist of (form . indent-spec) for Vibe define-like forms.")

(defun vibe--setup-indentation ()
  "Configure indentation for Vibe-specific define-like forms."
  (dolist (entry vibe-indent-specs)
    (put (car entry) 'scheme-indent-function (cdr entry))))

;;;###autoload
(define-derived-mode vibe-mode scheme-mode "Vibe"
  "Major mode for editing Vibe source files.

Vibe is a R7RS Small Scheme derivative that compiles to LLVM bitcode.
This mode is derived from scheme-mode with custom indentation for
Vibe-specific forms:

  - llvm:define-function
  - llvm:define-type
  - llvm:define-constant
  - llvm:define-ffi-function
  - llvm:declare-function
  - define-bitcode-function
  - define-bitcode

For these forms, body elements indent one level (simple indent) rather
than aligning to the first argument as scheme-mode does for define."
  (vibe--setup-indentation))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.vibe\\'" . vibe-mode))

(provide 'vibe-mode)
;;; vibe-mode.el ends here
