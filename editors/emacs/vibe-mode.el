;;; vibe-mode.el --- Major mode for editing Vibe code -*- lexical-binding: t; -*-

;; Author: Vibe Language Team
;; Version: 0.1.0
;; Package-Requires: ((emacs "26.1"))
;; Keywords: languages
;; URL: https://github.com/vibe-lang/vibe-mode

;;; Commentary:
;; This package provides a major mode for editing Vibe code and
;; interacting with a Vibe REPL.

;;; Code:

(require 'comint)
(require 'scheme)

(defgroup vibe nil
  "Support for Vibe code."
  :group 'languages
  :prefix "vibe-")

(defcustom vibe-repl-host "localhost"
  "Host where the Vibe REPL is running."
  :type 'string
  :group 'vibe)

(defcustom vibe-repl-port 7654
  "Port number of the Vibe REPL."
  :type 'integer
  :group 'vibe)

(defvar vibe-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") 'vibe-eval-buffer)
    (define-key map (kbd "C-c C-r") 'vibe-eval-region)
    (define-key map (kbd "C-c C-z") 'vibe-switch-to-repl)
    map)
  "Keymap for Vibe major mode.")

(defvar vibe-repl-process nil
  "Network process connected to the Vibe REPL.")

(defvar vibe-repl-buffer "*vibe-repl*"
  "Name of the Vibe REPL buffer.")

(defun vibe--make-message-header (type length)
  "Create a message header for TYPE with payload LENGTH."
  (let ((header (make-string 16 0)))
    (dotimes (i 4)
      (aset header i (logand (ash 1 (* i 8)) #xFF))) ; version = 1
    (dotimes (i 4)
      (aset header (+ i 4) (logand (ash type (* i 8)) #xFF)))
    (dotimes (i 8)
      (aset header (+ i 8) (logand (ash length (* i 8)) #xFF)))
    header))

(defun vibe--send-message (type payload)
  "Send a message of TYPE with PAYLOAD to the REPL."
  (when vibe-repl-process
    (let* ((payload-bytes (encode-coding-string payload 'utf-8))
           (header (vibe--make-message-header type (length payload-bytes))))
      (process-send-string vibe-repl-process (concat header payload-bytes)))))

(defun vibe-connect-repl ()
  "Connect to a running Vibe REPL."
  (interactive)
  (let ((host (read-string "REPL host: " vibe-repl-host))
        (port (read-number "REPL port: " vibe-repl-port)))
    (when (and host port)
      (setq vibe-repl-process
            (make-network-process
             :name "vibe-repl"
             :buffer vibe-repl-buffer
             :host host
             :service port
             :filter 'vibe--process-filter))
      (with-current-buffer (get-buffer-create vibe-repl-buffer)
        (vibe-repl-mode)
        (goto-char (point-max))
        (insert (format "Connected to Vibe REPL at %s:%d\n" host port))))))

(defun vibe--process-filter (proc string)
  "Process filter for PROC that handles STRING from the REPL."
  (when (buffer-live-p (process-buffer proc))
    (with-current-buffer (process-buffer proc)
      (let ((moving (= (point) (process-mark proc))))
        (save-excursion
          (goto-char (process-mark proc))
          (insert string)
          (set-marker (process-mark proc) (point)))
        (if moving (goto-char (process-mark proc)))))))

(defun vibe-eval-region (start end)
  "Evaluate the region between START and END in the Vibe REPL."
  (interactive "r")
  (let ((code (buffer-substring-no-properties start end)))
    (vibe--send-message 1 code))) ; 1 = MSG_TYPE_EVAL

(defun vibe-eval-buffer ()
  "Evaluate the current buffer in the Vibe REPL."
  (interactive)
  (vibe-eval-region (point-min) (point-max)))

(defun vibe-switch-to-repl ()
  "Switch to the Vibe REPL buffer."
  (interactive)
  (if (get-buffer vibe-repl-buffer)
      (pop-to-buffer vibe-repl-buffer)
    (vibe-connect-repl)))

;;;###autoload
(define-derived-mode vibe-mode scheme-mode "Vibe"
  "Major mode for editing Vibe code."
  :group 'vibe
  (use-local-map vibe-mode-map))

;;;###autoload
(define-derived-mode vibe-repl-mode comint-mode "Vibe REPL"
  "Major mode for interacting with a Vibe REPL."
  :group 'vibe)

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.vibe\\'" . vibe-mode))

(provide 'vibe-mode)

;;; vibe-mode.el ends here 