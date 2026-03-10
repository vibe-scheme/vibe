# vibe-mode

Emacs major mode for editing Vibe source files (.vibe).

## Installation

Add the emacs directory to your load-path and require the mode:

```elisp
(add-to-list 'load-path "~/path/to/vibe/emacs")
(require 'vibe-mode)
```

Or load directly:

```elisp
(load "~/path/to/vibe/emacs/vibe-mode.el")
```

## Features

vibe-mode is derived from scheme-mode and provides:

- **Custom indentation** for Vibe define-like forms:
  - `llvm:define-function`
  - `llvm:define-type`
  - `llvm:define-constant`
  - `llvm:define-ffi-function`
  - `llvm:declare-function`
  - `define-bitcode-function`
  - `define-bitcode`

For these forms, body elements indent one level (simple indent) rather than aligning to the first argument as scheme-mode does for standard `define`.

## Auto-mode

Files with the `.vibe` extension are automatically opened in vibe-mode.
