(ert-deftest org-cliplink-parse-raw-header-test ()
  (should (equal
           '(("Last-Modified" . "Sun, 08 Mar 2015 14:06:08 GMT")
             ("Content-Length" . "199")
             ("Content-type" . "text/html")
             ("Date" . "Sun, 08 Mar 2015 14:17:14 GMT")
             ("Server" . "SimpleHTTP/0.6 Python/2.7.9"))
           (org-cliplink-parse-raw-header
            (concat "HTTP/1.0 200 OK\n"
                    "Server: SimpleHTTP/0.6 Python/2.7.9\n"
                    "Date: Sun, 08 Mar 2015 14:17:14 GMT\n"
                    "Content-type: text/html\n"
                    "Content-Length: 199\n"
                    "Last-Modified: Sun, 08 Mar 2015 14:06:08 GMT\n"))))
  (should (equal
           '(("Last-Modified" . "Sun, 08 Mar 2015 14:06:08 GMT")
             ("Content-Length" . "199")
             ("Content-type" . "text/html")
             ("Date" . "Sun, 08 Mar 2015 14:17:14 GMT")
             ("Server" . "SimpleHTTP/0.6 Python/2.7.9"))
           (org-cliplink-parse-raw-header
            (concat "HTTP/1.0 200 OK\n"
                    "Server: SimpleHTTP/0.6 Python/2.7.9\r\n"
                    "Date: Sun, 08 Mar 2015 14:17:14 GMT\n"
                    "Content-type: text/html\n"
                    "Content-Length: 199\r\n"
                    "Last-Modified: Sun, 08 Mar 2015 14:06:08 GMT\n")))))

(ert-deftest org-cliplink-parse-response-test ()
  (with-mock
   (stub org-cliplink-parse-raw-header => nil)
   (let ((test-data '(("test-data/responses/inconsistent-eol-response" .
                       (nil . "Here goes body\n"))
                      ("test-data/responses/correct-response-without-title" .
                       (nil . "Here goes body\n")))))
     (dolist (test-case test-data)
       (message (car test-case))
       (let ((data-file (car test-case))
             (expected-outcome (cdr test-case)))
         (with-temp-buffer
           (insert-file data-file)
           (should (equal (org-cliplink-parse-response) expected-outcome))))))))


(ert-deftest org-cliplink-read-secrets-test ()
  (let ((org-cliplink-secrets-path "./test-data/secrets/org-cliplink-secrets.el"))
    (should (equal (org-cliplink-read-secrets)
                   '(:hello (1 2 3)))))
  (let ((org-cliplink-secrets-path "/path/to/non/existing/secrets"))
    (should (not (org-cliplink-read-secrets)))))

(ert-deftest org-cliplink-check-basic-auth-for-url-test ()
  (let ((org-cliplink-secrets-path "./test-data/secrets/org-cliplink-basic-auth-secrets.el"))
    (should (equal (org-cliplink-check-basic-auth-for-url "http://rexim.me/test")
                   '(:url-pattern "http://rexim.me/*" :username "horta" :password "hell")))
    (should (not (org-cliplink-check-basic-auth-for-url "http://fornever.me/test")))))

(ert-deftest org-cliplink-extract-and-prepare-title-from-current-buffer-test ()
  (with-mock
   (stub org-cliplink-parse-response =>
         '(nil . "<title>hello</title>"))
   (not-called org-cliplink-uncompress-gziped-text)
   (should (equal "hello"
                  (org-cliplink-extract-and-prepare-title-from-current-buffer))))

  (with-mock
   (stub org-cliplink-parse-response =>
         '(nil . "<title meaning-of-life=\"42\">hello</title>"))
   (not-called org-cliplink-uncompress-gziped-text)
   (should (equal "hello"
                  (org-cliplink-extract-and-prepare-title-from-current-buffer))))
  (with-mock
   (stub org-cliplink-parse-response =>
         '(nil . "<TITLE>hello</TITLE>"))
   (not-called org-cliplink-uncompress-gziped-text)
   (should (equal "hello"
                  (org-cliplink-extract-and-prepare-title-from-current-buffer))))

  (with-mock
   (stub org-cliplink-parse-response =>
         '((("Content-Encoding" . "gzip")) . "<title>hello</title>"))
   (stub org-cliplink-uncompress-gziped-text =>
         "<title>hello</title>")
   (should (equal "hello"
                  (org-cliplink-extract-and-prepare-title-from-current-buffer)))))

(ert-deftest org-cliplink-escape-html4-test ()
  (should (equal "&{Hello} '{World} α  "
                 (org-cliplink-escape-html4
                  "&amp;[Hello] &#39;[World] &alpha; &nbsp;")))
  (should (equal "parents' coffee machine — 'quoted'"
                 (org-cliplink-escape-html4
                  "parents&#x27; coffee machine &#X2014; &#x27;quoted&#x27;")))
  (should (not (org-cliplink-escape-html4 nil))))

(ert-deftest org-cliplink-insert-org-mode-link-callback-test ()
  (with-temp-buffer
    (org-cliplink-insert-org-mode-link-callback "http://google.com/" "Google")
    (should (equal (buffer-string) "[[http://google.com/][Google]]")))

  (with-temp-buffer
    (org-cliplink-insert-org-mode-link-callback "http://google.com" nil)
    (should (equal (buffer-string) "[[http://google.com]]"))))

(ert-deftest org-cliplink-uncompress-gziped-text-test ()
  (let ((gziped-content (concat "\x1F\x8B\x08\x00\xD8\x8B"
                                "\x74\x55\x00\x03\xCB\x48"
                                "\xCD\xC9\xC9\x57\x28\xCF"
                                "\x2F\xCA\x49\x01\x00\x85"
                                "\x11\x4A\x0D\x0B\x00\x00"
                                "\x00")))
    (should (equal "hello world"
                   (org-cliplink-uncompress-gziped-text gziped-content)))))

(ert-deftest org-cliplink-clipboard-content-test ()
  (kill-append "khooy" nil)
  (should (equal "khooy"
                 (org-cliplink-clipboard-content))))

(ert-deftest org-cliplink-retrieve-title-synchronously-test ()
  (with-mock
   (stub message => :times 0)
   (should (equal nil
                  (org-cliplink-retrieve-title-synchronously "file:///.")))))

(defmacro org-cliplink-with-fake-titles (&rest body)
  "Run BODY with titles retrieved synchronously as \"Title of URL\"."
  `(cl-letf (((symbol-function 'org-cliplink-retrieve-title)
              (lambda (url title-callback)
                (funcall title-callback url (concat "Title of " url)))))
     ,@body))

(ert-deftest org-cliplink-link-at-point-test ()
  (dolist (x '(("see https://a.org/x now" "https://a.org/x" 5 20 nil)
               ("see <https://a.org/x> now" "https://a.org/x" 5 22 nil)
               ("see [[https://a.org/x]] now" "https://a.org/x" 5 24 nil)
               ("see [[https://a.org/x][A]] now" "https://a.org/x" 5 27 t)))
    (with-temp-buffer
      (insert (car x))
      (dolist (pos (list 4 5 12 (nth 3 x)))
        (goto-char pos)
        (let ((link (org-cliplink-link-at-point)))
          (should (equal (butlast (cdr x)) (butlast link)))
          (should (equal (nth 4 x) (and (nth 3 link) t)))))
      (goto-char 3)
      (should (not (org-cliplink-link-at-point)))))
  (with-temp-buffer
    (insert "no links here, ftp://a.org/x")
    (goto-char 4)
    (should (not (org-cliplink-link-at-point)))
    (goto-char (- (point-max) 3))
    (should (not (org-cliplink-link-at-point)))))

(ert-deftest org-cliplink-links-in-region-test ()
  (with-temp-buffer
    (insert "a https://a.org/1, <https://a.org/2>\n"
            "[[https://a.org/3]] [[https://a.org/4][Four https://a.org/5]]\n"
            "https://a.org/6")
    (should (equal '(("https://a.org/1" 3 18)
                     ("https://a.org/2" 20 37)
                     ("https://a.org/3" 38 57))
                   (org-cliplink-links-in-region (point-min) 100)))
    (should (equal '(("https://a.org/6" 100 115))
                   (org-cliplink-links-in-region 99 (point-max))))))

(ert-deftest org-cliplink-converts-region-test ()
  (org-cliplink-with-fake-titles
   (with-temp-buffer
     (setq-local transient-mark-mode t)
     (insert "keep https://a.org/0\n"
             "https://a.org/1 and [[https://a.org/2]] and [[https://a.org/3][Mine]]\n")
     (set-mark 22)
     (goto-char (point-max))
     (org-cliplink)
     (should (equal (buffer-string)
                    (concat "keep https://a.org/0\n"
                            "[[https://a.org/1][Title of https://a.org/1]] and "
                            "[[https://a.org/2][Title of https://a.org/2]] and "
                            "[[https://a.org/3][Mine]]\n")))
     (should (not (region-active-p))))))

(ert-deftest org-cliplink-converts-url-at-point-test ()
  (org-cliplink-with-fake-titles
   (with-temp-buffer
     (insert "see <https://a.org/x>.")
     (goto-char 10)
     (org-cliplink)
     (should (equal (buffer-string)
                    "see [[https://a.org/x][Title of https://a.org/x]].")))
   (with-temp-buffer
     (insert "see https://a.org/x")
     (goto-char 4)
     (org-cliplink)
     (should (equal (buffer-string)
                    "see [[https://a.org/x][Title of https://a.org/x]]")))
   (with-temp-buffer
     (insert "see [[https://a.org/x][Mine]]")
     (goto-char 10)
     (should-error (org-cliplink) :type 'user-error))))

(ert-deftest org-cliplink-falls-back-to-clipboard-test ()
  (org-cliplink-with-fake-titles
   (with-temp-buffer
     (setq-local kill-ring '("https://a.org/clip"))
     (setq-local kill-ring-yank-pointer kill-ring)
     (setq-local interprogram-paste-function nil)
     (insert "see ")
     (org-cliplink)
     (should (equal (buffer-string)
                    "see [[https://a.org/clip][Title of https://a.org/clip]]")))))

(ert-deftest org-cliplink-skips-edited-url-test ()
  (let ((callbacks nil))
    (cl-letf (((symbol-function 'org-cliplink-retrieve-title)
               (lambda (url title-callback)
                 (push (list title-callback url "T") callbacks)))
              ((symbol-function 'message) #'ignore))
      (with-temp-buffer
        (insert "https://a.org/1 https://a.org/2")
        (org-cliplink-replace-with-link "https://a.org/1" 1 16)
        (org-cliplink-replace-with-link "https://a.org/2" 17 32)
        (goto-char 16)
        (insert "x")
        (dolist (callback callbacks)
          (apply #'funcall callback))
        (should (equal (buffer-string)
                       "https://a.org/1x [[https://a.org/2][T]]"))))))

(ert-deftest org-cliplink-inserts-where-called-test ()
  (let ((callbacks nil))
    (cl-letf (((symbol-function 'org-cliplink-retrieve-title)
               (lambda (url title-callback)
                 (push (list title-callback url "T") callbacks))))
      (with-temp-buffer
        (insert "one two")
        (goto-char 4)
        (org-cliplink-insert-transformed-title
         "https://a.org" #'org-cliplink-org-mode-link-transformer)
        (goto-char (point-max))
        (insert " three")
        (dolist (callback callbacks)
          (apply #'funcall callback))
        (should (equal (buffer-string) "one[[https://a.org][T]] two three"))
        (should (= (point) (point-max)))))))

(ert-deftest org-cliplink-point-follows-inserted-link-test ()
  (org-cliplink-with-fake-titles
   (with-temp-buffer
     (insert "one two")
     (goto-char 4)
     (org-cliplink-insert-transformed-title
      "https://a.org" (lambda (_url _title) "LINK"))
     (should (equal (buffer-string) "oneLINK two"))
     (should (= (point) 8)))))

(ert-deftest org-cliplink-evil-normal-state-inserts-after-cursor-test ()
  (org-cliplink-with-fake-titles
   (with-temp-buffer
     (setq-local evil-local-mode t)
     (setq-local evil-state 'normal)
     (insert "trailing space \nnext")
     (goto-char 15)
     (org-cliplink-insert-transformed-title
      "https://a.org" (lambda (_url _title) "LINK"))
     (should (equal (buffer-string) "trailing space LINK\nnext"))
     (should (= (point) 19))
     (goto-char (point-max))
     (insert "\n")
     (org-cliplink-insert-transformed-title
      "https://a.org" (lambda (_url _title) "LINK"))
     (should (equal (buffer-string) "trailing space LINK\nnext\nLINK")))
   (with-temp-buffer
     (setq-local evil-local-mode t)
     (setq-local evil-state 'insert)
     (insert "a b")
     (goto-char 2)
     (org-cliplink-insert-transformed-title
      "https://a.org" (lambda (_url _title) "LINK"))
     (should (equal (buffer-string) "aLINK b")))))
