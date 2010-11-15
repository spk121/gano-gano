;; coding: iso-8859-1
(setlocale LC_ALL "")

(use-modules (gano CBuffer)
	     (oop goops))

(load "testlib.scm")

(test "render-line ascii start-of-string"
      (let ([txt (render-line data-string-ascii 8 0 80)])
	(write txt) (newline)
	(and
	 (string=? (string-take txt (string-length presentation-string-ascii)) 
		   presentation-string-ascii)
	 (= (string-length txt) 80))))

(test "render-line ascii in string"
      (let ([txt (render-line data-string-ascii 8 2 80)])
	(write txt) (newline)
	(and
	 (string=? (string-take txt 26) 
		   "cdefghijklmnopqrstuvwxyz  ")
	 (= (string-length txt) 80))))

(test "render-line ascii before start-of-string"
      (let ([txt (render-line data-string-ascii 8 -1 80)])
	(write txt) (newline)
	(and
	 (string=? (string-take txt 26)
		   " abcdefghijklmnopqrstuvwxy")
	 (= (string-length txt) 80))))

(test "render-line ascii completely left of string"
      (let ([txt (render-line data-string-ascii 8 -90 80)])
	(write txt) (newline)
	(and
	 (string=? txt
		   (make-string 80 #\space))
	 (= (string-length txt) 80))))

(test "render-line ascii end-of-string"
      (let ([txt (render-line data-string-ascii 8 26 80)])
	(write txt) (newline)
	(and
	 (string=? txt
		   (make-string 80 #\space))
	 (= (string-length txt) 80))))

(test "render-line ascii past end-of-string"
      (let ([txt (render-line data-string-ascii 8 27 80)])
	(write txt) (newline)
	(and
	 (string=? txt
		   (make-string 80 #\space))
	 (= (string-length txt) 80))))

;;-----------------------

(test "render-line ascii start-of-string, truncated"
      (let ([txt (render-line data-string-ascii 8 0 10)])
	(write txt) (newline)
	(string=? txt "abcdefghij")))

(test "render-line ascii in string, truncated"
      (let ([txt (render-line data-string-ascii 8 2 10)])
	(write txt) (newline)
	(string=? txt "cdefghijkl")))

(test "render-line ascii before start-of-string, truncated"
      (let ([txt (render-line data-string-ascii 8 -1 10)])
	(write txt) (newline)
	(string=? txt " abcdefghi")))

(test "render-line ascii completely left of string, truncated"
      (let ([txt (render-line data-string-ascii 8 -90 10)])
	(write txt) (newline)
	(string=? txt "          ")))

(test "render-line ascii end-of-string, truncated"
      (let ([txt (render-line data-string-ascii 8 26 10)])
	(write txt) (newline)
	(string=? txt "          ")))

(test "render-line ascii past end-of-string, truncated"
      (let ([txt (render-line data-string-ascii 8 27 10)])
	(write txt) (newline)
	(string=? txt "          ")))




;;-----------------------

(test "render-line tabs start-of-string, truncated"
      (let ([txt (render-line data-string-tabs 8 0 30)])
	(write txt) (newline)
	(string=? txt (string-take presentation-string-tabs 30))))

(test "render-line tabs in string, truncated"
      (let ([txt (render-line data-string-tabs 8 2 30)])
	(write txt) (newline)
	(string=? txt (substring presentation-string-tabs 2 32))))

(test "render-line tabs before start-of-string, truncated"
      (let ([txt (render-line data-string-tabs 8 -1 30)])
	(write txt) (newline)
	(string=? txt (string-append " " (substring presentation-string-tabs 0 29)))))

(test "render-line tabs completely left of string, truncated"
      (let ([txt (render-line data-string-tabs 8 -90 10)])
	(write txt) (newline)
	(string=? txt "          ")))

(test "render-line tabs, truncated"
      (let ([txt (render-line data-string-tabs 8 26 10)])
	(write txt) (newline)
	(string=? txt "      d   ")))



