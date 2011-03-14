(define (string-base str)
  "Returns a string with any combining marks removed."
  (apply string
         (string-fold-right
          (lambda (c r)
            (if (char-combining-mark? c)
                r
                (cons c r)))
          '()
          str)))

(define (string-base-length str)
  "Returns the number of characters in the string, ignoring combining
marks."
  (string-length (string-base str)))

(define (string-base-indices str)
  "Returns a list of indices that indicate the positions of all
the codepoints in the string that are not combining marks."
  (let loop ([i 0]
             [str str]
             [indices '()])
    (if (string-null? str)
        indices
        ;; else
        (let ([c (string-ref str 0)])
          (if (char-combining-mark? c)
              (loop (+ i 1) (substring str 1) indices)
              (loop (+ i 1) (substring str 1) (append indices (list i))))))))

(define (string-count-base-codepoints-in-substring str start end)
  (string-base-length (substring str start end)))

(define (string-x-index->x-data n str)
  "Returns the count of the number of characters in the first N
codepoints of STR.  Characters formed from a combination of base
codepoints and combining-mark characters are counted as a single
character.  If N is equal to the number of base characters in the
string, the string length is returned.  If N is greater than the
number of base characters in the string, #f is returned."
  (let ([n-base (string-base-length str)])
    (cond
     [(> n (string-length str))
      #f]
     [(= n 0)
      0]
     [else
      (let loop ([ch (string-ref str 0)]
                 [rest (substring str 1)]
                 [pos 0]
                 [i 1])
        ;; (format #t "char cur ~S next ~S base? ~S pos before op ~S"
        ;;         ch
        ;;         (if (string-null? rest) #f (string-ref rest 0))
        ;;         (if (string-null? rest) #f (char-base? (string-ref rest 0)))
        ;;         pos)
        (if (or (string-null? rest)
                (not (char-combining-mark? (string-ref rest 0))))
            (set! pos (+ 1 pos)))
        ;; (format #t " pos after op ~S~%" pos)
        (if (= i n)
            pos
            ;; else
            (loop (string-ref rest 0)
                  (substring rest 1)
                  pos
                  (+ i 1))))])))

(define (string-x-index->x-cell n str tabsize)
  "Returns the character cell location of the Nth codepoint in the
string.  If N is equal to the string length, the character cell
location just after then end of the string is given.  If N is greater
than the string length, #f is returned.  Horizontal tabulation
characters are assumed to occupy cells up to the next tab stop.

Combining marks are presumed to occupy the same character cell as the
base character that they are attached to.  But this isn't the case for
all zero-width characters.  A non-combining zero width character that
follows non-zero-width character will begin in a new cell, and then
character that follows it will occupy the same cell."
  (let ([n-base (string-base-length str)])
    (cond
     [(> n (string-length str))
      #f]
     [(= n 0)
      0]
     [else
      (let loop ([ch (list (string-ref str 0))]
                 [rest (substring str 1)]
                 [cell 0]
                 [i 1])
        ;; (format #t "char cur ~S next ~S base? ~S cell before op ~S"
        ;;         ch
        ;;         (if (string-null? rest) #f (string-ref rest 0))
        ;;         (if (string-null? rest) #f (char-base? (string-ref rest 0)))
        ;;         cell)
        (if (or (string-null? rest)
                (not (char-combining-mark? (string-ref rest 0))))
            ;; The next location is a new character, so sum of the width
            ;; of this character, including its base character and any
            ;; combining marks
            (cond
             [(char=? #\tab (car ch))
              (set! cell (* tabsize (quotient (+ cell tabsize) tabsize)))
              (set! ch '())]
             [else
              ;; Sum over the width of all the character in the previous
              ;; character, which might be a base character plus combining
              ;; marks, or which might be a standalone character.
              (set! cell (+ cell (apply + (map wcwidth ch))))
              (set! ch '())]))
        ;; (format #t " cell after op ~S~%" cell)
        (if (= i n)
            cell
            ;; else
            (loop (append ch (list (string-ref rest 0)))
                  (substring rest 1)
                  cell
                  (+ i 1))))])))

;; aka string-find-index-of-nth-base-codepoint
(define (string-x-data->x-index n str)
  "Returns the string index that points to the Nth non-combining-mark
character in the string.  If N is equal to the number of non-combining-mark
characters in the string, the string length is returned.  If there are
fewer than N non-combining-mark codepoints in the string, #f is returned."
  (cond
   [(= n 0)
    0]
   [else
    (let*  ([base-list (string-base-indices str)]
            [len (length base-list)])
      (cond
       [(> n len)
        #f]
       [(= n len)
        (string-length str)]
       [else
        (list-ref base-list n)]))]))

(define (string-x-data->x-cell n str tabsize)
  "Finds the character cell location of the Nth base character in the
string.  Characters that are formed from a base character plus one or
more combining marks are counted as a single character.  If N is equal
to the number of base characters in the string, the character cell
location just after the end of the string is given.  If N is greater
than the number of base characters in the string, #f is returned."
  (let ([baselen (string-base-length str)])
    (cond
     [(> n baselen)
      #f]
     [(= n baselen)
      (last (string-compute-x-cell-list-from-string str tabsize))]
     [else
      (list-ref (string-compute-x-cell-list-from-string str tabsize)
                (string-x-data->x-index n str))])))

(define (string-x-cell->x-index n str tabsize)
  "Returns the string index of the first codepoint in STR that
occupies the Nth character cell. If N is the number of character cells
the entire string occupies, it returns the string length.  If N is
greater than the number of character cells that STR occupies, it
returns #f."
  ;; FIXME: This is very inefficient.
  (let* ([x-cell-list (string-compute-x-cell-list-from-string str tabsize)]
         [i-start (length (take-while (lambda (x) (<= x n)) x-cell-list))])
    (if (> n (last x-cell-list))
        #f
        (- i-start 1))))

(define (string-x-cell->x-data n str tabsize)
  "Returns the number of characters in the first N character cells of
the string.  Characters formed from a combination of a base character
plus one or more combining marks are counted as a single character.
If N is equal to the number of base characters in the string, the cell
after the end of the string is given.  If N is greater than the number
of base characters in the string, #f is returned."
  (let ([x-cell-list (string-compute-x-cell-list-from-string str tabsize)])
    (cond
     [(> n (last x-cell-list))
      #f]
     [(= n (last x-cell-list))
      (string-base-length str)]
     [else
      (string-x-index->x-data (string-x-cell->x-index n str tabsize) str)])))

(define (string-find-index-of-nth-base-codepoint str n)
  "Returns the string index that points to the Nth non-combining-mark
character in the string.  If N is equal to the number of
non-combining-mark characters in the string, the string length is
returned.  If there are fewer than N non-combining-mark codepoints in
the string, #f is returned"
  (let loop ([i 0]
             [n n]
             [str str])
    (cond
     [(= n 0)
      i]
     [(string-null? str)
      #f]
     [else
      (if (char-combining-mark? (string-ref str 0))
          (loop (+ i 1) n (substring str 1))
          (loop (+ i 1) (- n 1) (substring str 1)))])))


(define (string-find-index-of-nth-cell str n tabsize)
  "Returns the string index of the first codepoint in STR that
occupies the Nth character cell. If N is the number of character cells
the entire string occupies, it returns the string length.  If N is
greater than the number of character cells that STR occupies, it
returns #f."
  ;; FIXME: This is very inefficient.
  (let* ([x-cell-list (string-compute-x-cell-list-from-string str tabsize)]
         [i-start (length (take-while (lambda (x) (<= x n)) x-cell-list))])
    (if (> n (last x-cell-list))
        #f
        (- i-start 1))))

(define (string-compute-x-cell-list-from-string str tabsize)
  ;;(format #t "In string-compute-x-cell-list-from-string ~S ~S ~%" str tabsize)
  (let loop ([pp 0] [lst '()] [str str])
    (cond
     [(not (= 0 (string-length str)))
      (loop (+ pp (char-count-cells (string-ref str 0) pp tabsize))
            (append lst (list pp))
            (substring str 1))]
     [else
      ;; return list
       ;;(format #t "Exiting string-compute-x-cell-list-from-string = ~a~%" (append lst (list pp)))
       (append lst (list pp))])))

(define (string-cell-length str tabsize)
  "Returns the number of cells that the string occupies."
  (last (string-compute-x-cell-list-from-string str tabsize)))

(define (%string-render-line-tabs str tabsize)
  "Return a copy of STR with each tab expanded into
an appropriate number of spaces."
  (let* ([x-cell-list (string-compute-x-cell-list-from-string str tabsize)]
         [str2 ""])
    (string-for-each-index
     (lambda (i)
       (if (char=? (string-ref str i) #\tab)
           (set! str2 (string-append str2 (make-string (- (list-ref x-cell-list (+ i 1))
                                                          (list-ref x-cell-list i))
                                                       #\space)))
           (set! str2 (string-append str2 (string (string-ref str i))))))
     str)
    str2))

(define (string-render-line str tabsize x-cell-start x-width)
  "Return the substring of str beginning at the x-cell cell position
and having x-width cells.  Tabs are converted to spaces, and
characters that would be clipped by the edges are replaced with
spaces."
  (let* ([str (%string-render-line-tabs str tabsize)]
         [x-cell-end (+ x-cell-start x-width)]
         [x-cell-list (string-compute-x-cell-list-from-string str tabsize)]
         ;; The index of the first character past the start of the window
         [i-start (list-index (lambda (x) (>= x x-cell-start)) x-cell-list)]
         ;; The index of the first character past the end of the window
         [i-end (list-index (lambda (x) (> x x-cell-end)) x-cell-list)]
         ;; The number of left-side spaces needed
         [left-padding (min x-width
                            (if i-start
                                (- (list-ref x-cell-list i-start) x-cell-start)
                                0))]
         ;; #t if the last character straddles the frame
         [truncated-p (and i-end (> (list-ref x-cell-list i-end) x-cell-end))]
         ;; The number of cells that the windowed string occupies
         [str-x-size (cond
                      [(and (not i-start) (not i-end))
                       ;; window starts after string
                       0]
                      [(and i-start (not i-end))
                       ;; string starts in window and ends before window
                       (- (last x-cell-list) (list-ref x-cell-list i-start))]
                      [(= i-start i-end)
                       ;; string starts after window
                       0]
                      [(and (= i-start (- i-end 1))
                            truncated-p)
                       ;; the only character is truncated
                       0]
                      [else
                       ;; the normal case
                       (if truncated-p
                           (- (list-ref x-cell-list (- i-end 1))
                              (list-ref x-cell-list i-start))
                           ;; else
                           (- (list-ref x-cell-list i-end)
                              (list-ref x-cell-list i-start)))])]
         ;;[right-padding (- x-width (+ left-padding str-x-size))]
         [right-padding (if truncated-p
                            (- x-width (+ left-padding str-x-size))
                            ;; else
                            0)])

    ;; (format (current-error-port) "~s ~s ~s~%" left-padding str-pp-size right-padding)
    (string-append
     ;; Space padding for initial truncated characters
     (make-string left-padding #\space)
     ;; Main list
     (cond
      [(not i-start)
       ""]
      [i-start
       (let ([inner-str ""])
         (do ([i i-start (+ i 1)]) ([>= i (- (or i-end (length x-cell-list)) 1)])
           (if (char=? #\tab (string-ref str i))
               (set! inner-str (string-append
                                inner-str
                                (make-string (- (list-ref x-cell-list (+ i 1))
                                                (list-ref x-cell-list i)) #\space)))
               (set! inner-str (string-append inner-str (string (string-ref str i))))))
         inner-str)])
     ;; End of line space padding
     (make-string right-padding #\space))))
