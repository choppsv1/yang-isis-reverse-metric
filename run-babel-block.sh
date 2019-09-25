#!/bin/bash
# -*- mode: shell-script -*-
#
# Call named code block in org-mode file
#
DIR=`pwd`
FILE=$1
CODE_BLOCK=$2

read -r -d '' PROGN <<EOF
(progn
  (require 'org)(require 'ob)(require 'ob-table)(setq org-confirm-babel-evaluate nil)
;; Don't forget to load languages
;; ------8<------------------
(org-babel-do-load-languages
   'org-babel-load-languages
   '((shell . t)
     (emacs-lisp . t)
     ))
;; ------8<------------------
  (mapc (lambda (file)
        (find-file (expand-file-name file "$DIR"))
        (let ((re-run (quote t))
          (results (quote "ERROR: Did not call code block: $CODE_BLOCK")))
    (save-excursion
      (org-babel-goto-named-src-block "$CODE_BLOCK")
      (let ((info (org-babel-get-src-block-info 'light)))
        (when info
          (save-excursion
        ;; go to the results, if there aren't any then run the block
        (goto-char (or (and (not re-run) (org-babel-where-is-src-block-result))
                   (progn (org-babel-execute-src-block)
                      (org-babel-where-is-src-block-result))))
        (end-of-line 1)
        (while (looking-at "[\n\r\t\f ]") (forward-char 1))
        ;; open the results
        (if (looking-at org-bracket-link-regexp)
            ;; file results
            (org-open-at-point)
          (let ((r (org-babel-format-result
                (org-babel-read-result) (cdr (assq :sep (nth 2 info))))))
            (pop-to-buffer (get-buffer-create "*Org-Babel Results*"))
            (delete-region (point-min) (point-max))
            (insert r)
            (setq results (buffer-string))))
        t)))
      t)
    (princ (format "%s" results))
    )

      (kill-buffer))
    '("$FILE"))
  )
EOF

emacs -Q --batch -l ox-rfc.el --eval "$PROGN"
