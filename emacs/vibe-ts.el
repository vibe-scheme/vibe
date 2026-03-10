;;; vibe-ts.el --- Tree-sitter support for Vibe  -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Vibe Project
;;
;; Author: Vibe Project
;; Maintainer: Vibe Project
;; Created: 2025
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (vibe-mode "0.1.0"))
;; Keywords: languages, vibe, scheme, llvm, tree-sitter
;; URL: https://github.com/vibe-lang/vibe

;;; Commentary:
;;
;; vibe-ts-mode provides tree-sitter integration for Vibe source files.
;; It is derived from vibe-mode and adds parser-based font-lock,
;; indentation, and navigation when the vibe grammar is available.
;;
;; Requires: Emacs 29+ with tree-sitter support, libtree-sitter-vibe
;; built and on treesit-extra-load-path.
;;
;; See doom-modules/lang/vibe/README.org for installation.

;;; Code:

(require 'vibe-mode)
(require 'treesit)

(defgroup vibe-ts nil
  "Tree-sitter support for Vibe."
  :group 'vibe
  :prefix "vibe-ts-")

(defcustom vibe-ts-indent-offset 2
  "Indentation offset for Vibe forms in vibe-ts-mode."
  :type 'integer
  :safe 'integerp
  :group 'vibe-ts)

;; Tree-sitter font-lock: capture names map to font-lock faces
(defvar vibe-ts--font-lock-settings
  (treesit-font-lock-rules
   :language 'vibe
   :feature 'comment
   '([(comment) (block_comment)] @font-lock-comment-face)
   :language 'vibe
   :feature 'string
   '([(string)] @font-lock-string-face)
   :language 'vibe
   :feature 'constant
   '([(boolean) (character) (number)] @font-lock-constant-face)
   :language 'vibe
   :feature 'type
   '([(vertical_bar_symbol)] @font-lock-type-face)
   :language 'vibe
   :feature 'keyword
   '([(identifier) @kw
      (:match "^\\(llvm:define-function\\|llvm:define-type\\|llvm:define-constant\\|llvm:define-ffi-function\\|llvm:declare-function\\|define-bitcode-function\\|define-bitcode\\|let\\*\\)$" @kw)]
     @font-lock-keyword-face)
   :language 'vibe
   :feature 'function
   '([(list (identifier) @fn . (_))
      (:match "^\\(llvm:call\\|llvm:ret\\|llvm:ret-void\\|llvm:store\\|llvm:load\\|llvm:gep\\|llvm:icmp\\|llvm:and\\|llvm:or\\|llvm:add\\|llvm:sub\\|llvm:mul\\|llvm:select\\|llvm:alloca\\|llvm:const-int\\|llvm:bitcast\\|llvm:zext\\|llvm:trunc\\|llvm:br\\)$" @fn)]
     @font-lock-function-call-face))
  "Tree-sitter font-lock settings for vibe-ts-mode.")

;; Indent rules: Lisp-style - first child at opening paren, rest indent one level
(defvar vibe-ts--indent-rules
  (let ((parent (alist-get 'parent treesit-simple-indent-presets))
        (first-sibling (alist-get 'first-sibling treesit-simple-indent-presets))
        (node-is (alist-get 'node-is treesit-simple-indent-presets))
        (match (alist-get 'match treesit-simple-indent-presets)))
    `((vibe
       (,(funcall node-is ")") ,parent 0)
       (,(funcall node-is "]") ,parent 0)
       (,(funcall match nil "list" nil 0 0) ,first-sibling 0)
       (,(funcall match nil "list" nil 1 999) ,first-sibling ,vibe-ts-indent-offset)
       (,(funcall match nil "vector" nil 0 999) ,parent ,vibe-ts-indent-offset))))
  "Tree-sitter indent rules for vibe-ts-mode.")

(defun vibe-ts--defun-name (node)
  "Return the defun name for NODE (a list node), or nil.
Handles llvm:define-function, llvm:define-type, etc."
  (when (and node (string-equal (treesit-node-type node) "list"))
    (let* ((first (treesit-node-child node 0))
           (first-text (when first (treesit-node-text first)))
           (second (treesit-node-child node 1)))
      (when (and first-text second
                 (string-match-p (concat "llvm:define-\\(function\\|type\\|constant\\|ffi-function\\)\\|"
                                        "llvm:declare-function\\|define-bitcode\\(-function\\)?")
                                 first-text))
        (cond
         ((string-equal (treesit-node-type second) "list")
          (treesit-node-text (treesit-node-child second 0)))
         ((string-equal (treesit-node-type second) "identifier")
          (treesit-node-text second))
         (t nil))))))

;;;###autoload
(define-derived-mode vibe-ts-mode vibe-mode "Vibe[TS]"
  "Major mode for Vibe with tree-sitter support.

Derived from vibe-mode. When the vibe grammar is available
(treesit-language-available-p), enables parser-based font-lock,
indentation, and navigation. Falls back to vibe-mode behavior otherwise."
  :group 'vibe-ts
  (when (treesit-language-available-p 'vibe)
    (setq-local treesit-font-lock-settings vibe-ts--font-lock-settings)
    (setq-local treesit-font-lock-feature-list
                '((comment string constant type)
                  (keyword function)))
    (setq-local treesit-simple-indent-rules vibe-ts--indent-rules)
    (setq-local treesit-defun-type-regexp "list")
    (setq-local treesit-defun-name-function #'vibe-ts--defun-name)
    (treesit-major-mode-setup)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.vibe\\'" . vibe-ts-mode))

(provide 'vibe-ts)
;;; vibe-ts.el ends here
