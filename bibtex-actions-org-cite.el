;;; bibtex-actions-org-cite.el --- Org-cite support for bibtex-actions -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2021 Bruce D'Arcus
;;
;; Author: Bruce D'Arcus <https://github.com/bdarcus>
;; Maintainer: Bruce D'Arcus <https://github.com/bdarcus>
;; Created: July 11, 2021
;; License: GPL-3.0-or-later
;; Version: 0.1
;; Homepage: https://github.com/bdarcus/bibtex-actions
;; Package-Requires: ((emacs "26.3")(org "9.5"))
;;
;; This file is not part of GNU Emacs.
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;
;;; Commentary:
;;
;;  This is a small package that intergrates bibtex-actions and org-cite.  It
;;  provides a simple org-cite processor with "follow" and "insert" capabilties.
;;
;;  Simply load this file and it will configure them for 'org-cite.'
;;
;;; Code:

(require 'bibtex-actions)
(require 'org)
(require 'oc)
(require 'oc-basic)
(require 'oc-csl)
(require 'citeproc)
(require 'embark)

(declare-function bibtex-actions-at-point "bibtex-actions")
(declare-function org-open-at-point "org")

;;; Internal variables

(defvar bibtex-actions-org-cite-style-preview-alist
  '((natbib . bibtex-actions--org-cite-natbib-style-preview)
    (biblatex . bibtex-actions--org-cite-biblatex-style-preview)))

(defvar bibtex-actions--org-cite-biblatex-style-preview
  '(;; Default "nil" style.
    ("/" . "\\autocite")
    ("/b" . "\\cite")
    ("/c" . "\\Autocite")
    ("/bc" . "\\Cite")
    ;; "text" style.
    ("t" . "\\textcite")
    ("t/c" .  "\\Textcite")
    ;; "nocite" style.
    ("n" . "\\nocite")
    ;; "author" style.
    ("a/c" . "\\Citeauthor*")
    ("a/f" . "\\citeauthor")
    ("a/cf" . "\\Citeauthor")
    ("a" . "\\citeauthor*")
    ;; "locators" style.
    ("l/b" . "\\notecite")
    ("l/c" . "\\Pnotecite")
    ("l/bc" . "\\Notecite")
    ("l" . "\\pnotecite")
    ;; "noauthor" style.
    ("na" .  "\\autocite*")))

(defvar bibtex-actions--org-cite-natbib-style-preview
  '(;; Default ("nil") style.
    ("/" . "\\citep")
    ("/b" . "\\citealp")
    ("/c" . "\\Citep")
    ("/f" . "\\citep*")
    ("/bc" .  "\\Citealp")
    ("/bf" . "\\citealp*")
    ("/cf" . "\\Citep*")
    ("/bcf" . "\\Citealp*")
    ;; "text" style.
    ("t" . "\\citet")
    ("t/b" . "\\citealt")
    ("t/c" . "\\Citet")
    ("t/f" . "\\citet*")
    ("t/bc" . "\\Citealt")
    ("t/bf"  .   "\\citealt*")
    ("t/cf" .    "\\Citet*")
    ("t/bcf" . "\\Citealt*")
    ;; "author" style.
    ("a" . "\\citeauthor")
    ("a/c" . "\\Citeauthor")
    ("a/f" . "\\citeauthor*")
    ;; "noauthor" style.
    ("na" . "\\citeyearpar")
    ("na/b" .   "\\citeyear")
    ;; "nocite" style.
    ("n" .  "\\nocite")))


;TODO
;(defvar bibtex-actions-org-cite-open-default

;; Org-cite processor

(defun bibtex-actions-org-cite-insert (&optional multiple)
  "Return a list of keys when MULTIPLE, or else a key string."
  (let ((references (bibtex-actions-read)))
    (if multiple
        references
      (car references))))

(defun bibtex-actions-org-cite-follow (_datum _arg)
  "Follow processor for org-cite."
  (call-interactively bibtex-actions-at-point-function))

(org-cite-register-processor 'bibtex-actions-org-cite
  :insert (org-cite-make-insert-processor
           #'bibtex-actions-org-cite-insert
           #'org-cite-basic--complete-style)
  :follow #'bibtex-actions-org-cite-follow)

(defun bibtex-actions-org-cite-select-style (&optional keys)
"Complete a citation style for org-cite with KEYS preview.

The previews include all configured export processors, with the
following faces to indicate:

'bibtex-actions-org-cite-styles-default' (default exported processor)
'bibtex-actions-org-cite-styles-fallback' (a style or variant not directly supported)"
;; TODO
)

(defun bibtex-actions--org-cite-styles-completing-read-group (cand transform)
  "Return group title of style CAND or TRANSFORM the candidate."
  (if transform
      ;; If there's a variant, remove it from the group title.
      (car (split-string cand "/")))
    cand)

(defun bibtex-actions-csl-render-citation (citation)
  "Render CITATION."
  (let ((proc (org-cite-csl--processor)))
    (citeproc-clear proc)
    (let* ((info (list :cite-citeproc-processor proc))
	   (cit-struct (org-cite-csl--create-structure citation info)))
      (citeproc-append-citations (list cit-struct) proc)
      (car (citeproc-render-citations proc 'plain t)))))

(defun bibtex-actions-org-cite-style-to-command (style output)
  "Return comand from STYLE for OUTPUT."
  ;; This should be added to oc.el.
  (let styles (assoc output bibtex-actions-org-cite-style-preview-alist)
       (cdr (assoc style styles))))

;;; Embark target finder

(defun bibtex-actions-org-cite-citation-finder ()
  "Return org-cite citation keys at point as a list for `embark'."
  (when-let ((keys (bibtex-actions-get-key-org-cite)))
    (cons 'oc-citation (bibtex-actions--stringify-keys keys))))

;;; Keymap

(defvar bibtex-actions-org-cite-map
  (let ((map (make-sparse-keymap)))
    (define-key map "c" '("cite | insert/edit" . org-cite-insert))
    (define-key map "o" '("cite | open-at-point" . bibtex-actions-open))
    (define-key map "e" '("cite | open/edit entry" . bibtex-actions-open-entry))
    (define-key map "n" '("cite | open notes" . bibtex-actions-open-notes))
    (define-key map (kbd "RET") '("cite | default action" . bibtex-actions-run-default-action))
    map)
  "Keymap for 'bibtex-actions-org-cite' `embark' at-point functionality.")

;; Bibtex-actions-org-cite configuration

(setq org-cite-follow-processor 'bibtex-actions-org-cite)
(setq org-cite-insert-processor 'bibtex-actions-org-cite)
(setq bibtex-actions-at-point-function 'embark-dwim)

;; Embark configuration for org-cite

(add-to-list 'embark-target-finders 'bibtex-actions-org-cite-citation-finder)
(add-to-list 'embark-keymap-alist '(bibtex . bibtex-actions-map))
(add-to-list 'embark-keymap-alist '(oc-citation . bibtex-actions-org-cite-map))

(provide 'bibtex-actions-org-cite)
;;; bibtex-actions-org-cite.el ends here
