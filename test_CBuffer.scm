;; coding: utf-8
(setlocale LC_ALL "")

(use-modules (gano CBuffer)
             (oop goops)
             (oop goops describe)
	     (gano config)
             (gano control))

(set! (@@ (gano global) vTabSize) 8)

(define buf (make <CBuffer>))
(define (set-data-pos! buf n)
  (set-pd-cur! buf n)
  (set-pp-cur! buf (get-pp-from-pd-cur buf))
  (set-pp-goal! buf (get-pp-cur buf)))

(define (init-buf! buf str)
  (set-text! buf (list str))
  (set-line-frame! buf 0)
  (set-line-cur! buf 0)
  (set-pd-cur! buf 0)
  (set-pp-cur! buf (get-pp-from-pd-cur buf))
  (set-pp-goal! buf (get-pp-cur buf)))

(define (print-pos buf)
  (format #t "Pd ~a Pp ~a Pp-Goal ~a~%" (get-pd-cur buf) (get-pp-cur buf) (get-pp-goal buf)))

(define string-ascii       "abcdefghijklmnopqrstuvwxyz")
(define string-hanzi       "章掌杖仗丈障彰璋樟張嶂瘴遧弡鱆慞")
(define string-hanzi-odd   ":章掌杖仗丈障彰璋樟張嶂瘴遧弡鱆:")
(define string-tab-letter  "\ta\tb\tc\td\te")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BACKSPACE

;; Latin test: backspace moves the data and presentation positions
;; backwards, leaving the text unchanged.
(init-buf! buf string-ascii)
(set-data-pos! buf 10)
(backspace buf)
(unless (and (= 9 (get-pd-cur buf))
             (= 9 (get-pp-cur buf))
             (= 9 (get-pp-goal buf))
             (string=? (get-text-cur buf) string-ascii))
  (error "latin text: backspace"))

;; Limits test: a bacespace when the data position it at home does nothing.
(set-data-pos! buf 0)
(backspace buf)
(unless (and (= 0 (get-pd-cur buf))
             (= 0 (get-pp-cur buf))
             (= 0 (get-pp-goal buf))
             (string=? (get-text-cur buf) string-ascii))
  (error "backspace at home"))

(when %have-ucs4
      ;; CJK test: backspace moves the data position back 1, but, the presentation
      ;; position takes into account the width of a character
      (init-buf! buf string-hanzi)
      (set-data-pos! buf 10)
      (backspace buf)
      (unless (and (= 9 (get-pd-cur buf))
		   (= 18 (get-pp-cur buf))
		   (= 18 (get-pp-goal buf))
		   (string=? (get-text-cur buf) string-hanzi))
	      (error "CJK text: backspace")))

;; Tabs test: backspace takes into account the width of tabs
(init-buf! buf string-tab-letter)
(set-data-pos! buf 3)
(backspace buf)
(unless (and (= 2 (get-pd-cur buf))
             (= 9 (get-pp-cur buf))
             (= 9 (get-pp-goal buf))
             (string=? (get-text-cur buf) string-tab-letter))
	(error "Tab text: backspace"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CURSOR BACKWARDS TABULATION

;; Latin test: backtab when we're on a tab column already
(init-buf! buf string-ascii)
(set-data-pos! buf 16)
(cursor-backward-tabulation buf 1)
(unless (and (= 8 (get-pd-cur buf))
             (= 8 (get-pp-cur buf))
             (= 8 (get-pp-goal buf))
             (string=? (get-text-cur buf) string-ascii))
  (error "latin text: aligned backtab"))

;; Latin test: backtab when we're between columns
(init-buf! buf string-ascii)
(set-data-pos! buf 15)
(print-pos buf)
(cursor-backward-tabulation buf 1)
(print-pos buf)
(unless (and (= 8 (get-pd-cur buf))
             (= 8 (get-pp-cur buf))
             (= 8 (get-pp-goal buf))
             (string=? (get-text-cur buf) string-ascii))
  (error "latin text: unaligned backtab"))

;; Latin test: double backtabs
(init-buf! buf string-ascii)
(set-data-pos! buf 24)
(cursor-backward-tabulation buf 2)
(unless (and (= 8 (get-pd-cur buf))
             (= 8 (get-pp-cur buf))
             (= 8 (get-pp-goal buf))
             (string=? (get-text-cur buf) string-ascii))
  (error "latin text: double backtab"))

;; Limits test
(init-buf! buf string-ascii)
(set-data-pos! buf 24)
(format #t "~a ~a ~a ~%" (get-pd-cur buf) (get-pp-cur buf) (get-pp-goal buf))
(cursor-backward-tabulation buf 4)
(format #t "~a ~a ~a ~%" (get-pd-cur buf) (get-pp-cur buf) (get-pp-goal buf))
(unless (and (= 0 (get-pd-cur buf))
             (= 0 (get-pp-cur buf))
             (= 0 (get-pp-goal buf))
             (string=? (get-text-cur buf) string-ascii))
  (error "limits test: backtab"))

;; CJK test: backtab
(when %have-ucs4
      (init-buf! buf string-hanzi)
      (set-data-pos! buf 11)
      (format #t "~a ~a ~a ~%" (get-pd-cur buf) (get-pp-cur buf) (get-pp-goal buf))
      (cursor-backward-tabulation buf 1)
      (format #t "~a ~a ~a ~%" (get-pd-cur buf) (get-pp-cur buf) (get-pp-goal buf))
      (unless (and (= 8 (get-pd-cur buf))
		   (= 16 (get-pp-cur buf))
		   (= 16 (get-pp-goal buf))
		   (string=? (get-text-cur buf) string-hanzi))
	      (error "CJK text: backtab"))

      ;; CJK test: backtab when cursor isn't char aligned
      (set-pp-cur! buf 11)
      (set-pd-cur! buf 5)
      (format #t "~a ~a ~a ~%" (get-pd-cur buf) (get-pp-cur buf) (get-pp-goal buf))
      (cursor-backward-tabulation buf 1)
      (format #t "~a ~a ~a ~%" (get-pd-cur buf) (get-pp-cur buf) (get-pp-goal buf))
      (unless (and (= 4 (get-pd-cur buf))
		   (= 8 (get-pp-cur buf))
		   (= 8 (get-pp-goal buf))
		   (string=? (get-text-cur buf) string-hanzi))
	      (error "CJK text: backtab with half char"))
      
      ;; CJK test: backtab over odd hanzi
      (init-buf! buf string-hanzi-odd)
      (set-pp-cur! buf 11)
      (set-pd-cur! buf 5)
      (format #t "~a ~a ~a ~%" (get-pd-cur buf) (get-pp-cur buf) (get-pp-goal buf))
      (cursor-backward-tabulation buf 1)
      (format #t "~a ~a ~a ~%" (get-pd-cur buf) (get-pp-cur buf) (get-pp-goal buf))
      (unless (and (= 4 (get-pd-cur buf))
		   (= 7 (get-pp-cur buf))
		   (= 8 (get-pp-goal buf))
		   (string=? (get-text-cur buf) string-hanzi-odd))
	      (error "CJK text: backtab with half char 2")))

;; Tabs test: backtab takes into account the width of tabs
(init-buf! buf string-tab-letter)
(set-data-pos! buf 4)
(cursor-backward-tabulation buf 1)
(unless (and (= 3 (get-pd-cur buf))
             (= 16 (get-pp-cur buf))
             (= 16 (get-pp-goal buf))
             (string=? (get-text-cur buf) string-tab-letter))
  (error "Tab text: backtab"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CURSOR CHARACTER ABSOLUTE


;; Latin test
(init-buf! buf string-ascii)
(set-data-pos! buf 0)
(print-pos buf)
(cursor-character-absolute buf 10)
(print-pos buf)
(unless (and (= 10 (get-pd-cur buf))
             (= 10 (get-pp-cur buf))
             (= 10 (get-pp-goal buf))
             (string=? (get-text-cur buf) string-ascii))
  (error "latin text: absolute positionining"))

;; Limit test
(init-buf! buf string-ascii)
(set-data-pos! buf 0)
(print-pos buf)
(cursor-character-absolute buf -10)
(print-pos buf)
(unless (and (= 0 (get-pd-cur buf))
             (= 0 (get-pp-cur buf))
             (= 0 (get-pp-goal buf))
             (string=? (get-text-cur buf) string-ascii))
  (error "latin text: absolute positionining before home"))

;; Limit test
(init-buf! buf string-ascii)
(set-data-pos! buf 0)
(print-pos buf)
(cursor-character-absolute buf 30)
(print-pos buf)
(unless (and (= 26 (get-pd-cur buf))
             (= 26 (get-pp-cur buf))
             (= 30 (get-pp-goal buf))
             (string=? (get-text-cur buf) string-ascii))
  (error "latin text: absolute positionining after limit"))

;; CJK test
(when %have-ucs4
      (init-buf! buf string-hanzi)
      (set-data-pos! buf 0)
      (print-pos buf)
      (cursor-character-absolute buf 10)
      (print-pos buf)
      (unless (and (= 5 (get-pd-cur buf))
		   (= 10 (get-pp-cur buf))
		   (= 10 (get-pp-goal buf))
		   (string=? (get-text-cur buf) string-hanzi))
	      (error "CJK text: absolute positioning"))
      
      ;; CJK-odd test
      (init-buf! buf string-hanzi-odd)
      (print-pos buf)
      (cursor-character-absolute buf 10)
      (print-pos buf)
      (unless (and (= 5 (get-pd-cur buf))
		   (= 9 (get-pp-cur buf))
		   (= 10 (get-pp-goal buf))
		   (string=? (get-text-cur buf) string-hanzi-odd))
	      (error "CJK-odd text: absolute positioning")))

;; Tabs test
(init-buf! buf string-tab-letter)
(set-data-pos! buf 0)
(print-pos buf)
(cursor-character-absolute buf 10)
(print-pos buf)
(unless (and (= 2 (get-pd-cur buf))
             (= 9 (get-pp-cur buf))
             (= 10 (get-pp-goal buf))
             (string=? (get-text-cur buf) string-tab-letter))
  (error "Tab text: absolute positioning"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; WRITE TAB

;; Latin test: data: start of line
(init-buf! buf string-ascii)
(set-data-pos! buf 0)
(print-pos buf)
(write (get-text-cur buf))
(write-tabulation buf 'data)
(newline)
(print-pos buf)
(write (get-text-cur buf))
(newline)

;; Latin test: data: in line
(init-buf! buf string-ascii)
(set-data-pos! buf 1)
(print-pos buf)
(write (get-text-cur buf))
(write-tabulation buf 'data)
(newline)
(print-pos buf)
(write (get-text-cur buf))
(newline)

;; Latin test: data: end of line
(init-buf! buf string-ascii)
(set-data-pos! buf 26)
(print-pos buf)
(write (get-text-cur buf))
(write-tabulation buf 'data)
(newline)
(print-pos buf)
(write (get-text-cur buf))
(newline)

(when %have-ucs4
      ;; Hanzi test: data: start of line
      (init-buf! buf string-hanzi)
      (set-data-pos! buf 0)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-tabulation buf 'data)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)
      
      ;; Hanzi test: data: in line
      (init-buf! buf string-hanzi)
      (set-data-pos! buf 1)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-tabulation buf 'data)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)

      ;; Hanzi test: data: end of line
      (init-buf! buf string-hanzi)
      (set-data-pos! buf 11)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-tabulation buf 'data)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)

      
      ;; Hanzi-Odd test: data: start of line
      (init-buf! buf string-hanzi-odd)
      (set-data-pos! buf 0)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-tabulation buf 'data)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)
      
      ;; Hanzi-Odd test: data: in line
      (init-buf! buf string-hanzi-odd)
      (set-data-pos! buf 1)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-tabulation buf 'data)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)
      
      ;; Hanzi-Odd test: data: end of line
      (init-buf! buf string-hanzi-odd)
      (set-data-pos! buf 11)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-tabulation buf 'data)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline))

;; Latin test: presentation: start of line
(init-buf! buf string-ascii)
(set-data-pos! buf 0)
(print-pos buf)
(write (get-text-cur buf))
(write-tabulation buf 'presentation)
(newline)
(print-pos buf)
(write (get-text-cur buf))
(newline)

;; Latin test: presentation: in line
(init-buf! buf string-ascii)
(set-data-pos! buf 1)
(print-pos buf)
(write (get-text-cur buf))
(write-tabulation buf 'presentation)
(newline)
(print-pos buf)
(write (get-text-cur buf))
(newline)

;; Latin test: presentation: end of line
(init-buf! buf string-ascii)
(set-data-pos! buf 26)
(print-pos buf)
(write (get-text-cur buf))
(write-tabulation buf 'presentation)
(newline)
(print-pos buf)
(write (get-text-cur buf))
(newline)

(when %have-ucs4
      ;; Hanzi test: presentation: start of line
      (init-buf! buf string-hanzi)
      (set-data-pos! buf 0)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-tabulation buf 'presentation)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)

      ;; Hanzi test: presentation: in line
      (init-buf! buf string-hanzi)
      (set-data-pos! buf 1)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-tabulation buf 'presentation)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)

      ;; Hanzi test: presentation: end of line
      (init-buf! buf string-hanzi)
      (set-data-pos! buf 11)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-tabulation buf 'presentation)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)

      
      ;; Hanzi-Odd test: presentation: start of line
      (init-buf! buf string-hanzi-odd)
      (set-data-pos! buf 0)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-tabulation buf 'presentation)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)
      
      ;; Hanzi-Odd test: presentation: in line
      (init-buf! buf string-hanzi-odd)
      (set-data-pos! buf 1)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-tabulation buf 'presentation)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)
      
      ;; Hanzi-Odd test: presentation: end of line
      (init-buf! buf string-hanzi-odd)
      (set-data-pos! buf 11)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-tabulation buf 'presentation)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline))
      

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; WRITE CHARACTER

;; Latin test: data: start of line
(init-buf! buf string-ascii)
(set-data-pos! buf 0)
(print-pos buf)
(write (get-text-cur buf))
(write-character buf #\x 'data)
(newline)
(print-pos buf)
(write (get-text-cur buf))
(newline)

;; Latin test: data: in line
(init-buf! buf string-ascii)
(set-data-pos! buf 1)
(print-pos buf)
(write (get-text-cur buf))
(write-character buf #\x 'data)
(newline)
(print-pos buf)
(write (get-text-cur buf))
(newline)

;; Latin test: data: end of line
(init-buf! buf string-ascii)
(set-data-pos! buf 26)
(print-pos buf)
(write (get-text-cur buf))
(write-character buf #\x 'data)
(newline)
(print-pos buf)
(write (get-text-cur buf))
(newline)

(when %have-ucs4
      ;; Hanzi test: data: start of line
      (init-buf! buf string-hanzi)
      (set-data-pos! buf 0)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-character buf #\x 'data)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)
      
      ;; Hanzi test: data: in line
      (init-buf! buf string-hanzi)
      (set-data-pos! buf 1)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-character buf #\x 'data)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)
      
      ;; Hanzi test: data: end of line
      (init-buf! buf string-hanzi)
      (set-data-pos! buf 11)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-character buf #\x 'data)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)
      
      
      ;; Hanzi-Odd test: data: start of line
      (init-buf! buf string-hanzi-odd)
      (set-data-pos! buf 0)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-character buf #\x 'data)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)
      
      ;; Hanzi-Odd test: data: in line
      (init-buf! buf string-hanzi-odd)
      (set-data-pos! buf 1)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-character buf #\x 'data)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)
      
      ;; Hanzi-Odd test: data: end of line
      (init-buf! buf string-hanzi-odd)
      (set-data-pos! buf 11)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-character buf #\x 'data)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline))
      
;; Latin test: presentation: start of line
(init-buf! buf string-ascii)
(set-data-pos! buf 0)
(print-pos buf)
(write (get-text-cur buf))
(write-character buf #\x 'presentation)
(newline)
(print-pos buf)
(write (get-text-cur buf))
(newline)

;; Latin test: presentation: in line
(init-buf! buf string-ascii)
(set-data-pos! buf 1)
(print-pos buf)
(write (get-text-cur buf))
(write-character buf #\x 'presentation)
(newline)
(print-pos buf)
(write (get-text-cur buf))
(newline)

;; Latin test: presentation: end of line
(init-buf! buf string-ascii)
(set-data-pos! buf 26)
(print-pos buf)
(write (get-text-cur buf))
(write-character buf #\x 'presentation)
(newline)
(print-pos buf)
(write (get-text-cur buf))
(newline)

(when %have-ucs4
      ;; Hanzi test: presentation: start of line
      (init-buf! buf string-hanzi)
      (set-data-pos! buf 0)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-character buf #\x 'presentation)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)
      
      ;; Hanzi test: presentation: in line
      (init-buf! buf string-hanzi)
      (set-data-pos! buf 1)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-character buf #\x 'presentation)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)
      
      ;; Hanzi test: presentation: end of line
      (init-buf! buf string-hanzi)
      (set-data-pos! buf 11)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-character buf #\x 'presentation)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)
      
      
      ;; Hanzi-Odd test: presentation: start of line
      (init-buf! buf string-hanzi-odd)
      (set-data-pos! buf 0)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-character buf #\x 'presentation)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)
      
      ;; Hanzi-Odd test: presentation: in line
      (init-buf! buf string-hanzi-odd)
      (set-data-pos! buf 1)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-character buf #\x 'presentation)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline)
      
      ;; Hanzi-Odd test: presentation: end of line
      (init-buf! buf string-hanzi-odd)
      (set-data-pos! buf 11)
      (print-pos buf)
      (write (get-text-cur buf))
      (write-character buf #\x 'presentation)
      (newline)
      (print-pos buf)
      (write (get-text-cur buf))
      (newline))

