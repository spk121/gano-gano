;;; Tests for (gano screen): screens, and updating one into another.
;;;
;;; The operations screen-update returns are checked two ways: for
;;; chosen cases, that they are the ones expected; and always, that
;;; carrying them out on the first screen (with screen-apply-ops, the
;;; module's model of the terminal) gives the second.

(define-module (test screen)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-64)
  #:use-module (rnrs bytevectors)
  #:use-module (gano rendering)
  #:use-module (gano screen))

(setlocale LC_ALL "C.UTF-8")

;;; Helpers

(define bold (make-sgr #:intensity 'intensity-bold))
(define reverse-video (make-sgr #:polarity 'polarity-negative))
(define red-underlined (make-sgr #:foreground-color 'color-red #:underline 'underline-single))

(define* (screen-of width height lines #:key (cursor '(0 0)) (visible? #t))
  "A screen showing the strings LINES from the top row down.  A line
   may also be a list of strings and (STRING . SGR) pairs."
  (let ([screen (make-screen width height)])
    (let loop ([lines lines] [row 0])
      (when (pair? lines)
        (if (string? (car lines))
            (screen-put-string! screen row 0 (car lines))
            (fold (lambda (part col)
                    (if (string? part)
                        (screen-put-string! screen row col part)
                        (screen-put-string! screen row col (car part) (cdr part))))
                  0 (car lines)))
        (loop (cdr lines) (+ row 1))))
    (screen-set-cursor! screen (car cursor) (cadr cursor) visible?)
    screen))

(define (rows screen)
  (map (lambda (r) (string-trim-right (screen-row-string screen r)))
       (iota (screen-height screen))))

(define (update before after . options)
  "The operations that turn BEFORE into AFTER, having checked that
   they do"
  (let ([ops (apply screen-update before after options)])
    (unless (screen-equal? (screen-apply-ops before ops) after)
      (error "screen-update's operations do not give the screen asked for" ops))
    ops))

(define (ops-of kind ops) (filter (lambda (op) (eq? (car op) kind)) ops))
(define (uses? kind ops) (pair? (ops-of kind ops)))

(define paragraph
  '("It was the best of times,"
    "it was the worst of times,"
    "it was the age of wisdom,"
    "it was the age of foolishness,"
    "it was the epoch of belief,"
    "it was the epoch of incredulity,"
    "it was the season of Light,"
    "it was the season of Darkness,"
    "it was the spring of hope,"
    "it was the winter of despair."))

(test-begin "screen")

;;; ---------------------------------------------------------------
;;; Screens
;;; ---------------------------------------------------------------

(test-group "building screens"
  (let ([s (make-screen 10 3)])
    (test-equal "size" '(10 3) (list (screen-width s) (screen-height s)))
    (test-equal "blank at first" '("" "" "") (rows s))
    (test-equal "cursor at the top left" '(0 0 #t)
                (list (screen-cursor-row s) (screen-cursor-col s) (screen-cursor-visible? s)))
    (test-equal "put-string returns the next column" 5 (screen-put-string! s 1 2 "abc"))
    (test-equal "and writes the text" "  abc     " (screen-row-string s 1))
    (test-equal "text past the right edge is left out" 10 (screen-put-string! s 2 7 "wxyz!"))
    (test-equal "the row keeps its width" "       wxy" (screen-row-string s 2))
    (screen-set-cursor! s 99 99 #f)
    (test-equal "the cursor is kept on the screen" '(2 9 #f)
                (list (screen-cursor-row s) (screen-cursor-col s) (screen-cursor-visible? s))))
  (let ([s (make-screen 10 2)])
    (screen-put-string! s 0 0 "ab" bold)
    (screen-put-string! s 0 2 "cd" (list reverse-video (make-default-sgr)))
    (test-assert "one sgr for the whole string"
                 (sgr-equal? bold (screen-cell-sgr s 0 1)))
    (test-assert "or one for each character"
                 (and (sgr-equal? reverse-video (screen-cell-sgr s 0 2))
                      (sgr-equal? (make-default-sgr) (screen-cell-sgr s 0 3))))
    (test-assert "untouched cells have the default attributes"
                 (sgr-equal? (make-default-sgr) (screen-cell-sgr s 1 0))))
  (let ([s (make-screen 6 3)])
    (test-equal "a double-width character takes two cells" 4 (screen-put-string! s 0 0 "日本"))
    (test-equal "a combining mark shares its base's cell" 2 (screen-put-string! s 1 0 "éx"))
    (test-equal "and stays with it" "éx    " (screen-row-string s 1))
    (test-equal "a double-width character that does not fit is left out" 6
                (screen-put-string! s 2 5 "日"))
    (test-equal "leaving a blank" "      " (screen-row-string s 2))
    (screen-put-string! s 0 1 "x")
    (test-equal "overwriting half of one blanks the other half" " x本  " (screen-row-string s 0))
    (screen-put-string! s 2 0 "a\ab")
    (test-equal "control characters are not kept" "a?b   " (screen-row-string s 2)))
  (test-assert "screen-equal? compares cells"
               (screen-equal? (screen-of 8 2 '("ab" "cd")) (screen-of 8 2 '("ab" "cd"))))
  (test-assert "text" (not (screen-equal? (screen-of 8 2 '("ab")) (screen-of 8 2 '("ax")))))
  (test-assert "attributes"
               (not (screen-equal? (screen-of 8 2 '("ab")) (screen-of 8 2 `((("ab" . ,bold)))))))
  (test-assert "and the cursor"
               (not (screen-equal? (screen-of 8 2 '("ab")) (screen-of 8 2 '("ab") #:cursor '(1 0))))))

;;; ---------------------------------------------------------------
;;; Encoding
;;; ---------------------------------------------------------------

(test-group "encoding operations"
  (test-equal "text and controls" "ab\r\n\b" (ops->string '((text "ab") (cr) (lf) (bs))))
  (test-equal "a count of 1 is left out" "\x1b[C\x1b[5C" (ops->string '((cuf 1) (cuf 5))))
  (test-equal "cursor position" "\x1b[H\x1b[4H\x1b[4;7H\x1b[1;7H"
              (ops->string '((cup 1 1) (cup 4 1) (cup 4 7) (cup 1 7))))
  (test-equal "attributes" "\x1b[m\x1b[1;31m" (ops->string '((sgr) (sgr 1 31))))
  (test-equal "extended attributes and explicit reset" "\x1b[38;2;10;20;30m\x1b[0m"
              (ops->string '((sgr 38 2 10 20 30) (sgr 0))))
  (test-error "unknown operation" #t (ops->string '((unknown))))
  (test-equal "erasing" "\x1b[K\x1b[3X\x1b[2J" (ops->string '((el) (ech 3) (ed 2))))
  (test-equal "inserting and deleting" "\x1b[2@\x1b[P\x1b[3L\x1b[M"
              (ops->string '((ich 2) (dch 1) (il 3) (dl 1))))
  (test-equal "scrolling" "\x1b[2;9r\x1b[3S\x1b[T\x1b[r"
              (ops->string '((stbm 2 9) (su 3) (sd 1) (stbm))))
  (test-equal "the rest" "\x1b[4b\x1b[9G\x1b[2d\x1b[3A\x1b[2B\x1b[6D\x1b[?25l\x1b[?25h"
              (ops->string '((rep 4) (cha 9) (vpa 2) (cuu 3) (cud 2) (cub 6)
                             (cursor-hide) (cursor-show))))
  (let ([ops '((cup 12 40) (sgr 0 1 38 5 100) (text "aé日") (rep 12) (stbm 2 20) (sgr)
               (cup 3 1) (cuf 1) (cuf 10) (el) (ed 2) (lf) (cursor-hide))])
    (test-equal "ops-byte-count is the size in UTF-8"
                (bytevector-length (string->utf8 (ops->string ops)))
                (ops-byte-count ops))))

;;; ---------------------------------------------------------------
;;; The model of the terminal
;;; ---------------------------------------------------------------

(test-group "carrying out operations"
  (define (after ops . lines)
    (rows (screen-apply-ops (screen-of 10 4 lines) ops)))
  (test-equal "text is written at the cursor" '("xyc")
              (take (after '((text "xy")) "abc") 1))
  (test-equal "erase to end of line" '("ab")
              (take (after '((cuf 2) (el)) "abcdef") 1))
  (test-equal "erase characters" '("a   ef")
              (take (after '((cuf 1) (ech 3)) "abcdef") 1))
  (test-equal "insert characters" '("a  bcdef")
              (take (after '((cuf 1) (ich 2)) "abcdef") 1))
  (test-equal "which pushes text off the right edge" '("a  bcdefgh")
              (take (after '((cuf 1) (ich 2)) "abcdefghij") 1))
  (test-equal "delete characters" '("adef")
              (take (after '((cuf 1) (dch 2)) "abcdef") 1))
  (test-equal "repeat" '("x----")
              (take (after '((text "x-") (rep 3)) "") 1))
  (test-equal "scroll up" '("b" "c" "d" "") (after '((su 1)) "a" "b" "c" "d"))
  (test-equal "scroll down" '("" "" "a" "b") (after '((sd 2)) "a" "b" "c" "d"))
  (test-equal "scroll within a region" '("a" "c" "" "d")
              (after '((stbm 2 3) (su 1) (stbm)) "a" "b" "c" "d"))
  (test-equal "delete lines" '("a" "d" "" "") (after '((cup 2 1) (dl 2)) "a" "b" "c" "d"))
  (test-equal "insert lines" '("a" "" "b" "c") (after '((cup 2 1) (il 1)) "a" "b" "c" "d"))
  (test-equal "line feed moves down" '("a" " x")
              (take (after '((cuf 1) (lf) (text "x")) "a") 2))
  (test-equal "and scrolls at the bottom" '("b" "c" "d" "")
              (after '((cup 4 1) (lf)) "a" "b" "c" "d"))
  (test-equal "erase the screen" '("" "" "" "") (after '((cup 2 2) (ed 2)) "a" "b" "c" "d"))
  (let ([s (screen-apply-ops (screen-of 10 4 '()) '((cup 3 5) (cub 2) (cud 9) (cursor-hide)))])
    (test-equal "cursor movement" '(3 2 #f)
                (list (screen-cursor-row s) (screen-cursor-col s) (screen-cursor-visible? s))))
  (let ([s (screen-apply-ops (screen-of 10 4 '()) '((sgr 1 31) (text "a") (sgr 22) (text "b")))])
    (test-eq "attributes are applied" 'intensity-bold (sgr-intensity (screen-cell-sgr s 0 0)))
    (test-eq "one group at a time" 'intensity-normal (sgr-intensity (screen-cell-sgr s 0 1)))
    (test-eq "the others staying" 'color-red (sgr-foreground-color (screen-cell-sgr s 0 1))))
  (let ([erase (lambda () (screen-apply-ops (screen-of 10 4 '("abcdef")) '((sgr 41) (el))))])
    (test-assert "erasing with attributes set leaves cells that equal nothing"
                 (not (screen-equal? (erase) (erase)))))
  (let ([s (screen-of 10 4 '("abc"))])
    (screen-apply-ops s '((text "xyz") (su 2)))
    (test-equal "the screen given is not changed" '("abc" "" "" "") (rows s))))

;;; ---------------------------------------------------------------
;;; Updates: single rows
;;; ---------------------------------------------------------------

(test-group "small changes"
  (let ([s (screen-of 40 10 paragraph #:cursor '(3 5))])
    (test-equal "nothing to do for the same screen" '() (update s s))
    (test-equal "or an equal one" '()
                (update s (screen-of 40 10 paragraph #:cursor '(3 5)))))
  (test-equal "one character at the cursor, which then moves on: just the character"
              '((text "x"))
              (update (screen-of 40 10 '("ab") #:cursor '(0 2))
                      (screen-of 40 10 '("abx") #:cursor '(0 3))))
  (test-equal "one character elsewhere: go there, write it, come back"
              '((cup 6 4) (text "X") (cup 1 1))
              (update (screen-of 40 10 paragraph)
                      (screen-of 40 10 (append (take paragraph 5)
                                               '("it Xas the epoch of incredulity,")
                                               (drop paragraph 6)))))
  (test-equal "only the cursor moves: the shortest way there"
              '((lf) (lf))
              (update (screen-of 40 10 paragraph #:cursor '(2 7))
                      (screen-of 40 10 paragraph #:cursor '(4 7))))
  (test-equal "to the start of the next row" '((lf) (cr))
              (update (screen-of 40 10 paragraph #:cursor '(2 7))
                      (screen-of 40 10 paragraph #:cursor '(3 0))))
  (test-equal "a little to the left" '((bs) (bs))
              (update (screen-of 40 10 paragraph #:cursor '(2 7))
                      (screen-of 40 10 paragraph #:cursor '(2 5))))
  (test-equal "far away" '((cup 10 31))
              (update (screen-of 40 10 paragraph #:cursor '(2 7))
                      (screen-of 40 10 paragraph #:cursor '(9 30))))
  (test-equal "without LF" '((cud 2))
              (update (screen-of 40 10 paragraph #:cursor '(2 7))
                      (screen-of 40 10 paragraph #:cursor '(4 7))
                      #:lf? #f))
  (test-equal "hiding and showing the cursor" '((cursor-hide))
              (update (screen-of 40 10 paragraph)
                      (screen-of 40 10 paragraph #:visible? #f)))
  (test-equal "showing it comes last" '((lf) (cursor-show))
              (update (screen-of 40 10 paragraph #:visible? #f)
                      (screen-of 40 10 paragraph #:cursor '(1 0)))))

(test-group "rewriting a row"
  (test-equal "the end of a row going blank is erased"
              '((cuf 7) (el) (cr))
              (update (screen-of 40 4 '("it was the age of wisdom,"))
                      (screen-of 40 4 '("it was"))))
  (test-equal "a whole row going blank"
              '((lf) (el) (cuu 1))
              (update (screen-of 40 4 '("a" "it was the age of wisdom,"))
                      (screen-of 40 4 '("a"))))
  (test-equal "a blank stretch in the middle is erased too"
              '((cuf 7) (ech 12) (cr))
              (update (screen-of 40 4 '("it was the age of wisdom,"))
                      (screen-of 40 4 (list (string-append "it was " (make-string 12 #\space)
                                                           "isdom,")))))
  (test-equal "a few unchanged cells between changes are rewritten, not skipped"
              '((text "IT wA") (cr))
              (update (screen-of 40 4 '("it was the age of wisdom,"))
                      (screen-of 40 4 '("IT wAs the age of wisdom,"))))
  (test-equal "many are skipped"
              '((text "I") (cuf 22) (text "M") (cr))
              (update (screen-of 40 4 '("it was the age of wisdom,"))
                      (screen-of 40 4 '("It was the age of wisdoM,"))))
  (test-equal "a repeated character is sent once"
              '((text "-") (rep 29) (cr))
              (update (screen-of 40 4 '())
                      (screen-of 40 4 (list (make-string 30 #\-)))))
  (test-equal "unless REP is not to be used"
              `((text ,(make-string 30 #\-)) (cr))
              (update (screen-of 40 4 '())
                      (screen-of 40 4 (list (make-string 30 #\-)))
                      #:rep? #f))
  (test-equal "attributes are set for the text and reset after"
              '((cuf 3) (sgr 1) (text "was") (sgr) (cr))
              (update (screen-of 40 4 '("it was the age"))
                      (screen-of 40 4 `(("it " ("was" . ,bold) " the age")))))
  (test-equal "a reset is used when it is shorter than undoing each attribute"
              '((sgr 4 31) (text "ab") (sgr 0 1) (text "cd") (sgr) (cr))
              (update (screen-of 40 4 '())
                      (screen-of 40 4 `((("ab" . ,red-underlined) ("cd" . ,bold))))))
  (test-equal "and just the difference when that is shorter"
              '((sgr 4 31) (text "ab") (sgr 1) (text "cd") (sgr) (cr))
              (update (screen-of 40 4 '())
                      (screen-of 40 4 `((("ab" . ,red-underlined)
                                         ("cd" . ,(make-sgr #:foreground-color 'color-red
                                                            #:underline 'underline-single
                                                            #:intensity 'intensity-bold)))))))
  (let ([ops (update (screen-of 10 4 '())
                     (screen-of 10 4 '("0123456789" "abcdefghij") #:cursor '(3 0)))])
    (test-equal "after the last column the next move does not trust the cursor's column"
                '((text "0123456789") (cr) (lf) (text "abcdefghij") (cr) (lf) (lf))
                ops))
  (let ([ops (update (screen-of 20 4 '("日本語 text" "abc"))
                     (screen-of 20 4 '("日xy語 text" "a日")))])
    (test-equal "double-width characters are replaced whole, both ways"
                '((text "xy") (text "日")) (ops-of 'text ops))))

(test-group "sliding a row sideways"
  (let ([line "it was the age of foolishness, it was the epoch of belief"])
    (test-equal "typing in the middle of a line: insert, then the character"
                '((ich 1) (text "X"))
                (update (screen-of 70 4 (list line) #:cursor '(0 7))
                        (screen-of 70 4 (list (string-append (substring line 0 7) "X"
                                                             (substring line 7)))
                                   #:cursor '(0 8))))
    (test-equal "deleting in the middle of a line"
                '((dch 1))
                (update (screen-of 70 4 (list line) #:cursor '(0 7))
                        (screen-of 70 4 (list (string-append (substring line 0 7)
                                                             (substring line 8)))
                                   #:cursor '(0 7))))
    (test-equal "deleting a word"
                '((cuf 7) (dch 8) (cr))
                (update (screen-of 70 4 (list line))
                        (screen-of 70 4 (list (string-append (substring line 0 7)
                                                             (substring line 15))))))
    (test-equal "a row scrolled left: delete, then draw what came into view"
                '((dch 5) (cuf 35) (text "e epo") (cr))
                (update (screen-of 40 4 (list (substring line 0 40)))
                        (screen-of 40 4 (list (substring line 5 45)))))
    (test-equal "a row scrolled right: insert, then draw what came into view"
                '((ich 5) (text "it wa") (cr))
                (update (screen-of 40 4 (list (substring line 5 45)))
                        (screen-of 40 4 (list (substring line 0 40)))))
    (let ([ops (update (screen-of 40 10 (map (lambda (l) (string-append "    " l)) paragraph))
                       (screen-of 40 10 paragraph))])
      (test-equal "a screen scrolled sideways: one delete for each row" 10
                  (length (ops-of 'dch ops)))
      (test-assert "and no text at all" (not (uses? 'text ops))))
    (let ([wide "it was the 日本語 of foolishness, it was the epoch"])
      (test-assert "double-width characters are not slid: the row is rewritten"
                   (not (uses? 'dch (update (screen-of 60 4 (list wide))
                                            (screen-of 60 4 (list (substring wide 3))))))))))

;;; ---------------------------------------------------------------
;;; Updates: scrolling
;;; ---------------------------------------------------------------

(test-group "scrolling"
  (test-equal "the whole screen up a row: one scroll, then the new row"
              '((su 1) (cud 9) (text "we had everything before us,") (cup 1 1))
              (update (screen-of 40 10 paragraph)
                      (screen-of 40 10 (append (cdr paragraph) '("we had everything before us,")))))
  (test-equal "the whole screen down two rows"
              '((sd 2) (text "A TALE") (lf) (cr) (text "Book 1") (cup 1 1))
              (update (screen-of 40 10 paragraph)
                      (screen-of 40 10 (append '("A TALE" "Book 1") (take paragraph 8)))))
  (let ([status `((" tale.txt  Ln 1" . ,reverse-video))])
    (test-equal "rows above a status line: the scroll region is set, and put back"
                '((stbm 1 10) (su 1) (stbm) (cud 9) (text "we had everything before us,")
                  (cup 1 1))
                (update (screen-of 40 11 (append paragraph (list status)))
                        (screen-of 40 11 (append (cdr paragraph) '("we had everything before us,")
                                                 (list status)))))
    (test-equal "a row inserted in the middle moves only the rows below it"
                '((stbm 4 10) (sd 1) (stbm) (lf) (lf) (lf) (text "NEW") (cup 1 1))
                (update (screen-of 40 11 (append paragraph (list status)))
                        (screen-of 40 11 (append (take paragraph 3) '("NEW")
                                                 (take (drop paragraph 3) 6) (list status))))))
  (test-equal "a row deleted, with nothing below to protect: delete line"
              '((lf) (lf) (lf) (dl 1) (cud 6) (text "we had everything before us,") (cup 1 1))
              (update (screen-of 40 10 paragraph)
                      (screen-of 40 10 (append (take paragraph 3) (drop paragraph 4)
                                               '("we had everything before us,")))))
  (test-equal "a row inserted likewise: insert line"
              '((lf) (lf) (lf) (il 1) (text "NEW") (cup 1 1))
              (update (screen-of 40 10 paragraph)
                      (screen-of 40 10 (append (take paragraph 3) '("NEW")
                                               (take (drop paragraph 3) 6)))))
  (let ([ops (update (screen-of 40 10 paragraph)
                     (screen-of 40 10 (append (take (cdr paragraph) 3) '("it was a new line,")
                                              (drop paragraph 5) '("we had everything"))))])
    (test-equal "a scroll is still found when a row in it changed too"
                '((su 1)) (ops-of 'su ops)))
  (let ([ops (update (screen-of 40 10 paragraph)
                     ;; rows 1-3 move up one, rows 6-8 move down one
                     (screen-of 40 10 (list (list-ref paragraph 1) (list-ref paragraph 2)
                                            (list-ref paragraph 3) "" (list-ref paragraph 4)
                                            "" (list-ref paragraph 5) (list-ref paragraph 6)
                                            (list-ref paragraph 7) (list-ref paragraph 9))))])
    (test-equal "two separate moves are both found" '(1 1)
                (list (length (ops-of 'su ops)) (length (ops-of 'sd ops)))))
  (let ([ops (update (screen-of 40 10 '("a" "b" "c" "d" "e" "f" "g" "h" "i" "j"))
                     (screen-of 40 10 '("b" "c" "d" "e" "f" "g" "h" "i" "j" "k")))])
    (test-assert "rows that are cheap to rewrite are rewritten, not scrolled, if that is less"
                 (<= (ops-byte-count ops) 30)))
  (test-assert "scrolling is far cheaper than redrawing"
               (< (* 8 (ops-byte-count
                        (update (screen-of 40 10 paragraph)
                                (screen-of 40 10 (append (cdr paragraph) '("we had"))))))
                  (ops-byte-count (screen-update #f (screen-of 40 10 paragraph))))))

;;; ---------------------------------------------------------------
;;; Updates: the whole screen
;;; ---------------------------------------------------------------

(test-group "unknown terminal contents"
  (let* ([s (screen-of 40 10 paragraph #:cursor '(2 3))]
         [ops (screen-update #f s)])
    (test-equal "everything is reset and erased first"
                '((cursor-hide) (sgr) (stbm) (ed 2)) (take ops 4))
    (test-equal "the cursor is shown at the end" '(cursor-show) (last ops))
    (test-assert "whatever the terminal showed, it shows the screen afterwards"
                 (screen-equal? s (screen-apply-ops
                                   (screen-of 40 10 (reverse paragraph) #:cursor '(7 7))
                                   ops)))
    (test-assert "blank cells are not sent"
                 (< (ops-byte-count ops) (+ 60 (apply + (map string-length paragraph)))))
    (test-equal "screen-update-string is the same, encoded"
                (ops->string ops) (screen-update-string #f s)))
  (let* ([s (screen-of 30 5 (take paragraph 5))]
         [ops (screen-update (screen-of 40 10 paragraph) s)])
    (test-equal "a screen of another size counts as unknown"
                '((cursor-hide) (sgr) (stbm) (ed 2)) (take ops 4))))

(test-group "hiding the cursor during long updates"
  (let ([a (screen-of 40 10 paragraph)]
        [b (screen-of 40 10 (reverse paragraph))])
    (let ([ops (update a b)])
      (test-equal "hidden first" '(cursor-hide) (first ops))
      (test-equal "and shown last" '(cursor-show) (last ops)))
    (test-assert "not when asked not to"
                 (not (uses? 'cursor-hide (update a b #:hide-cursor-over #f))))
    (test-assert "nor for a short update"
                 (not (uses? 'cursor-hide
                             (update a (screen-of 40 10 (cons "It was the BEST of times,"
                                                              (cdr paragraph)))))))))

;;; ---------------------------------------------------------------
;;; Random screens
;;; ---------------------------------------------------------------

;; Screens built from random lines, and the changes an editor makes to
;; them: lines scrolled, inserted, deleted and edited; text scrolled
;; sideways; attributes changed.

(define random-words
  '("define" "lambda" "(let" "foo" "x" "bar-baz" "日本語" "é" "éx" "    " "  " "}"
    "if (a < b) {" "return 0;" "ｗｉｄｅ" "------------" "aaaaaaaaaaaaaaaa"))
(define random-sgrs
  (list #f #f #f #f bold reverse-video red-underlined
        (make-sgr #:background-color (make-color-256 100) #:intensity 'intensity-faint)))

(define (pick state lst) (list-ref lst (random (length lst) state)))

(define (random-line state)
  "A list of (STRING . SGR) parts"
  (if (zero? (random 5 state))
      '()
      (append-map (lambda (_) (list (cons (pick state random-words) (pick state random-sgrs))
                                    (cons " " #f)))
                  (iota (random 12 state)))))

(define (change-lines state lines)
  (let ([n (length lines)]
        [new (lambda () (random-line state))])
    (define (change-part line f)
      (if (null? line)
          line
          (let ([p (random (length line) state)])
            (append (take line p) (f (list-ref line p)) (drop line (+ p 1))))))
    (define (change-line f)
      (let ([i (random n state)])
        (append (take lines i) (list (f (list-ref lines i))) (drop lines (+ i 1)))))
    (case (random 8 state)
      [(0) (let ([k (+ 1 (random (max 1 (quotient n 2)) state))])    ; scroll up
             (append (drop lines k) (map (lambda (_) (new)) (iota k))))]
      [(1) (let ([k (+ 1 (random (max 1 (quotient n 2)) state))])    ; scroll down
             (append (map (lambda (_) (new)) (iota k)) (take lines (- n k))))]
      [(2) (let ([i (random n state)])                                ; insert a line
             (append (take lines i) (list (new)) (take (drop lines i) (- n i 1))))]
      [(3) (let* ([i (random n state)]                                ; delete a line
                  [j (+ i (random (- n i) state))])
             (append (take lines i) (take (drop lines (+ i 1)) (- j i)) (list (new))
                     (drop lines (+ j 1))))]
      [(4) (change-line (lambda (line)                                ; insert text
                          (let ([p (random (+ 1 (length line)) state)])
                            (append (take line p)
                                    (list (cons (pick state random-words) (pick state random-sgrs)))
                                    (drop line p)))))]
      [(5) (change-line (lambda (line) (change-part line (lambda (part) '()))))]  ; delete text
      [(6) (change-line (lambda (line)                                ; change attributes
                          (change-part line (lambda (part)
                                              (list (cons (car part) (pick state random-sgrs)))))))]
      [else (map (lambda (line) (if (zero? (random 3 state)) (new) line)) lines)])))

(define (random-screen state width height lines shift)
  "LINES with their first SHIFT characters scrolled off to the left"
  (let ([screen (make-screen width height)])
    (for-each
     (lambda (line row)
       (let* ([str (string-concatenate (map car line))]
              [sgrs (append-map (lambda (part)
                                  (make-list (string-length (car part))
                                             (or (cdr part) (make-default-sgr))))
                                line)]
              [k (min shift (string-length str))])
         (screen-put-string! screen row 0 (substring str k) (drop sgrs k))))
     lines (iota height))
    (screen-set-cursor! screen (random height state) (random width state)
                        (not (zero? (random 6 state))))
    screen))

(test-group "random screens"
  (let ([state (seed->random-state 20261125)]
        [failures 0]
        [bytes 0]
        [redraw-bytes 0])
    (do ([i 0 (+ i 1)]) ((= i 400))
      (let* ([width (+ 8 (random 90 state))]
             [height (+ 2 (random 30 state))]
             [lines (map (lambda (_) (random-line state)) (iota height))]
             [shift (if (zero? (random 4 state)) (random 10 state) 0)]
             [before (random-screen state width height lines shift)]
             [after (random-screen
                     state width height
                     (fold (lambda (_ lines) (change-lines state lines))
                           lines (iota (+ 1 (random 3 state))))
                     (case (random 5 state)
                       [(0) (+ shift 1 (random 8 state))]
                       [(1) (max 0 (- shift 1 (random 8 state)))]
                       [else shift]))]
             [options (case (random 4 state)
                        [(0) '(#:rep? #f)]
                        [(1) '(#:lf? #f #:hide-cursor-over #f)]
                        [else '()])]
             [ops (apply screen-update before after options)]
             [redraw (screen-update #f after)])
        (set! bytes (+ bytes (ops-byte-count ops)))
        (set! redraw-bytes (+ redraw-bytes (ops-byte-count redraw)))
        (unless (and (screen-equal? after (screen-apply-ops before ops))
                     (screen-equal? after (screen-apply-ops before redraw))
                     (= (ops-byte-count ops)
                        (bytevector-length (string->utf8 (ops->string ops)))))
          (set! failures (+ failures 1)))))
    (test-equal "every update gives the screen asked for" 0 failures)
    (test-assert "in under half the bytes of redrawing" (< (* 2 bytes) redraw-bytes))))

;;; ---------------------------------------------------------------
;;; The terminal
;;; ---------------------------------------------------------------

(test-group "showing screens"
  (let ([a (screen-of 40 10 paragraph)]
        [b (screen-of 40 10 (cons "It was the BEST of times," (cdr paragraph)))]
        [sent (lambda (screen)
                (call-with-output-string (lambda (port) (show-screen screen port))))])
    (redraw-screen)
    (test-equal "the first screen is drawn in full" (screen-update-string #f a) (sent a))
    (test-equal "the next as a change to it" (screen-update-string a b) (sent b))
    (test-equal "the same again sends nothing" "" (sent b))
    (redraw-screen)
    (test-equal "after redraw-screen it is drawn in full again"
                (screen-update-string #f b) (sent b))
    (test-equal "and then changes are sent as before" (screen-update-string b a) (sent a))
    (test-equal "show-screen returns how much it sent"
                (string-length (screen-update-string a b))
                (show-screen b (%make-void-port "w")))))

(test-end "screen")
