;;; lang/vibe/packages.el --- Vibe language support  -*- lexical-binding: t; -*-

;; Packages are pulled from the public Vibe repo on GitHub.
;; No symlinks or local paths required.

(package! vibe-mode
  :recipe (:host github :repo "vibe-scheme/vibe" :files ("emacs/vibe-mode.el")))

(package! vibe-ts
  :recipe (:host github :repo "vibe-scheme/vibe" :files ("emacs/vibe-ts.el")))

;;; packages.el ends here
