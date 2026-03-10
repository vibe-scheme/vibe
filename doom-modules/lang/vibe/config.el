;;; lang/vibe/config.el --- Vibe language configuration for Doom Emacs  -*- lexical-binding: t; -*-

;; Set treesit-extra-load-path so Emacs can find libtree-sitter-vibe.
;; Resolve symlinks so path works when module is symlinked into doom/modules.

(defconst vibe-module-dir (file-truename (file-name-directory (or load-file-name buffer-file-name "")))
  "Canonical directory of this Doom module (resolves symlinks).")

(defconst vibe-root-dir (expand-file-name "../../.." vibe-module-dir)
  "Root of the Vibe repository (parent of doom-modules).")

(defconst vibe-grammar-dir (expand-file-name "tree-sitter-vibe/build" vibe-root-dir)
  "Directory containing libtree-sitter-vibe.so / libtree-sitter-vibe.dylib.")

(when (file-directory-p vibe-grammar-dir)
  (add-to-list 'treesit-extra-load-path vibe-grammar-dir))
