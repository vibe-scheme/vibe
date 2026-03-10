;;; lang/vibe/packages.el --- No external packages  -*- lexical-binding: t; -*-

;; This module uses local files from the Vibe repo only.
;; No MELPA or other package dependencies.

(package! vibe-mode
  :recipe (:local-repo "/Users/jballanc/Source/vibe/emacs/"))

(package! vibe-ts
  :recipe (:local-repo "/Users/jballanc/Source/vibe/emacs/"))

;;; packages.el ends here
