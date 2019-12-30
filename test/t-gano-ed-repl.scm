(use-modules (srfi srfi-64)
             (gano ed-repl))

(test-begin "t-gano-ed-repl")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; append

(test-equal "ed test 'a'"
  '("hello world"
    "line 1"
    "hello world!"
    "line 2"
    "line 3"
    "line 4"
    "line5"
    "hello world!!")
  (let ((ed (make-ed-repl #:verbose #t)))
    (set-text! ed
               '("line 1"
                 "line 2"
                 "line 3"
                 "line 4"
                 "line5"))
    (ed-repl-do ed (open-input-string "0a\nhello world\n."))
    (ed-repl-do ed (open-input-string "2a\nhello world!\n."))
    (ed-repl-do ed (open-input-string "$a\nhello world!!\n."))
    (get-text ed)))

(test-equal "ed test 'addr'"
  '("line 2"
    ;; "line9"
    ;; The NetBSD test suite says that there is a "line9" at the end.
    ;; But GNU ed doesn't have a line 9.
    )
  (let ((ed (make-ed-repl #:verbose #t)))
    (set-text! ed
               '("line 1"
                 "line 2"
                 "line 3"
                 "line 4"
                 "line5"
                 "line6"
                 "line7"
                 "line8"
                 "line9"
                 ))
    (ed-repl-do ed (open-input-string "1 d"))
    (ed-repl-do ed (open-input-string "1 1 d"))
    (ed-repl-do ed (open-input-string "1,2,d"))
    (ed-repl-do ed (open-input-string "1;+ + ,d"))
    (ed-repl-do ed (open-input-string "1,2;., + 2d"))
    (get-text ed)))

(test-equal "ed test 'c'"
  '("at the top"
    "between top/middle"
    "in the middle"
    "at the bottom")
  (let ((ed (make-ed-repl #:verbose #t)))
    (set-text! ed '("line 1"
                    "line 2"
                    "line 3"
                    "line 4"
                    "line5"))
    (ed-repl-do ed (open-input-string "1c\nat the top\n."))
    (ed-repl-do ed (open-input-string "4c\nin the middle\n."))
    (ed-repl-do ed (open-input-string "$c\nat the bottom\n."))
    (ed-repl-do ed (open-input-string "2,3c\nbetween top/middle\n."))
    (get-text ed)))

(test-equal "ed test 'd'"
  '("line 2")
  (let ((ed (make-ed-repl #:verbose #t)))
    (set-text! ed '("line 1"
                    "line 2"
                    "line 3"
                    "line 4"
                    "line5"))
    (ed-repl-do ed (open-input-string "1d"))
    (ed-repl-do ed (open-input-string "2;+1d"))
    (ed-repl-do ed (open-input-string "$d"))
    (get-text ed)))

(test-equal "ed test 'E1'"
  '("hello world")
  (let ((ed (make-ed-repl #:verbose #t)))
    (ed-repl-do ed (open-input-string "E test/t1.txt"))
    (get-text ed)))

(test-equal "ed test 'E2'"
  '("hello world-")
  (let ((ed (make-ed-repl #:verbose #t)))
    (ed-repl-do ed (open-input-string "E !echo hello world-"))
    (get-text ed)))

(test-equal "ed test 'E3'"
  '("E hello world-")
  (let ((ed (make-ed-repl #:verbose #t)))
    (set-text! ed '("E hello world-"))
    (ed-repl-do ed (open-input-string "E"))
    (get-text ed)))

(test-equal "ed test 'E4'"
  '("E hello world-")
  (let ((ed (make-ed-repl #:verbose #t)))
    (set-text! ed '("E hello world-"))
    (ed-repl-do ed (open-input-string "e"))
    (get-text ed)))

(test-equal "ed test 'g1'"
  '("line5 help! world"
    "line 4 help! world"
    "line 3 help! world"
    "line 2 help! world"
    "line 1 help! world")
  (let ((ed (make-ed-repl #:verbose #t)))
    (set-text! ed '("line 1"
                    "line 2"
                    "line 3"
                    "line 4"
                    "line5"))
    (ed-repl-do ed (open-input-string ",g/./m0"))
    (ed-repl-do ed (open-input-string "g/./s/$/ hello world/"))
    (ed-repl-do ed (open-input-string "g/hello /s/lo/p!/"))
    (get-text ed)))

(test-end "t-gano-ed-repl")
