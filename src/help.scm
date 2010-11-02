(define-module (gano help)
  #:use-module (gano config)
  #:use-module (gano CFunction)
  #:use-module (gano CShortcut)
  #:use-module (gano flags)
  #:use-module (gano global)
  #:use-module (gano input)
  #:use-module (gano nano-h)
  #:use-module (gano winio)
  #:use-module (ncurses curses)
  #:use-module (srfi srfi-1)
  #:export (
            DoHelp
            ))

(if %have-rnrs-control
    (use-modules (rnrs control))
    (use-modules (gano control)))

(define textHelpMain 
  '(
    "Main gano help text"
    ""
    "The gano editor is designed to emulate the "
    "functionality and ease-of-use of the UW Pico text "
    "editor.  There are four main sections of the editor.  "
    "The top line shows the program version, the current "
    "filename being edited, and whether or not the file "
    "has been modified.  Next is the main editor window "
    "showing the file being edited.  The status line is "
    "the third line from the bottom and shows important "
    "messages."
    ""
    "The bottom two lines show the most commonly used "
    "shortcuts in the editor."
    ""
    "The notation for shortcuts is as follows: Control-key "
    "sequences are notated with a caret (^) symbol and "
    "can be entered either by using the Control (Ctrl) "
    "key or pressing the Escape (Esc) key twice.  Escape-key "
    "sequences are notated with the Meta (M-) symbol and can "
    "be entered using either the Esc, Alt, or Meta key depending on "
    "your keyboard setup."
    ""
    "Also, pressing Esc twice and then typing a "
    "three-digit decimal number from 000 to 255 will enter "
    "the character with the corresponding value.  The "
    "following keystrokes are available in the main editor "
    "window.  Alternative keys are shown in "
    "parentheses"
    ""
    ""))

(define (DoHelp menu)
  (format (current-error-port) "In DoHelp(~s)~%" menu)
  (let ([menuCurSav vMenuCur]
	[fHelpSav (ISSET NO_HELP)]
	[rgHelpText (CreateRgHelpText menu)])
    (format (current-error-port) "Help Text:~%")
    (format (current-error-port) "~s~%" rgHelpText)
    (force-output (current-error-port))
    (curs-set 0)
    (BlankEditor)
    (attr-off! vWinBottom vAttrReverse)
    (BlankStatusbar)
    (set! vMenuCur MHELP)

    ;; Even if no shortcut list is displayed in the main buffer,
    ;; display one here.
    (when (ISSET NO_HELP)
      (UNSET NO_HELP)
      (InitWindow))

    (DisplayShortcutList MHELP)
    (noutrefresh vWinBottom)

    (let loop ([abort #f] [line 0] [lastLine 0])
      (unless abort
	(BlankEditor)
	(do ([i 0 (1+ i)]) ([= i editwinrows])
	  (when (< (+ i line) (length rgHelpText))
	    (let ([eLine (list-ref rgHelpText (+ i line))])
	      (addstr vWinEdit eLine #:y i #:x 1))))
	(refresh vWinEdit)
	(set! lastLine line)
	(let* ([f (GetFunctionFromShortcut (DoInputForHelp))]
	       [fId (if f (GetFunctionId f) #f)])
	  (cond
	   [(eqv? fId TOTAL_REFRESH)
	    (DisplayTitlebar "")
	    (DisplayShortcutList vMenuCur)
	    (refresh vWinBottom)
	    (do ([i 0 (1+ i)]) ([= editwinrows])
	      (when (< (+ i line) (length rgHelpText))
		(let ([eLine (list-ref rgHelpText (+ i line))])
		  (addstr eLine vWinEdit #:y i #:x 0 #:n (min (string-length eLine) (cols))))))
	    (refresh vWinEdit)
	    (refresh vWinMain)]
	   [(eqv? fId DO_PAGE_UP)
	    (set! line (max 0 (- line (- editwinrows 2))))]
	   [(eqv? fId DO_PAGE_DOWN)
	    (set! line (min (- (length rgHelpText) (- editwinrows 2))
			    (+ line editwinrows -1)))]
	   [(eqv? fId DO_UP_VOID)
	    (set! line (max 0 (1- line)))]
	   [(eqv? fId DO_DOWN_VOID)
	    (set! line (min (- (length rgHelpText) (- editwinrows 2))
			    (1+ line)))]
	   [(eqv? fId DO_FIRST_LINE)
	    (set! line 0)]
	   [(eqv? fId DO_LAST_LINE)
	    (set! line (- (length rgHelpText) (- editwinrows 1)))]
	   [(eqv? fId DO_EXIT)
	    (set! abort #t)]))
	(loop abort line lastLine)))
    
    ;; Clean up
    (set! vMenuCur menuCurSav)
    (if fHelpSav
	(begin 
	  (BlankStatusbar)
	  (BlankShortcutList)
	  (noutrefresh vWinBottom)
	  (SET NO_HELP)
	  (InitWindow))
	;; else
	(DisplayShortcutList vMenuCur))
    (curs-set 1)))

(define (DoInputForHelp)
  (let ([meta_key #f]
        [input #f]
        [kbinput (get_kbinput vWinEdit)])
    (cond
     [(not kbinput)
      ;; no valid input.  We're done
      #f]
     [else
      (let ([qualifier (first kbinput)]
	    [input (second kbinput)])
	
	(if (eq? qualifier 'meta)
	    [set! meta_key #t]
	    [set! meta_key #f])
	
	;; Meta keys are not case sensitive
	(when (and (eq? qualifier 'meta) (char? input))
	  (set! input (char-downcase input)))
	
	;; Check for a shortcut in the main list
	(let* ([s (GetShortcutFromMenuKey MHELP input meta_key)]
	       ;; If we have a shortcut from the main list, or a
	       ;; "universal" edit window shortcut, set
	       ;; have_shortcut to true
	       [have_shortcut (not (not s))]
	       [funcId (if s (GetShortcutFuncId s) 0)])
	  (cond
	   ;; If this wasn't a shortcut, quit
	   [(not have_shortcut)
	    (DisplayStatusbar "Unknown Command")
	    (beep)
	    #f]
	   
	   [else
	    s])))])))

(define (CompareShortcutKeyStrings a b)
  "#t if A is before B in KeyString sort order"
  (let ([aLen (string-length a)]
        [bLen (string-length b)]
        [a1 (string-ref a 0)]
        [b1 (string-ref b 0)])
    (cond
     ;; Single letter strings have highest priority
     [(and (= aLen 1) (= bLen 1))
      (string< a b)]
     [(and (= aLen 1) (> bLen 1))
      #t]
     [(and (> aLen 1) (= bLen 1))
      #f]
     ;; Control strings are next
     [(and (char=? #\^ a1) (char=? #\^ b1))
      (string< a b)]
     [(and (char=? #\^ a1) (not (char=? #\^ b1)))
      #t]
     [(and (not (char=? #\^ a1)) (char=? #\^ b1))
      #f]
     ;; Function keys
     [(and (char=? #\F a1) (char=? #\F b1))
      (let ([an (string->number (string-drop a 1))]
            [bn (string->number (string-drop b 1))])
        (< an bn))]
     [(and (char=? #\F a1) (not (char=? #\F b1)))
      #t]
     [(and (not (char=? #\F a1)) (char=? #\F b1))
      #f]
     ;; Both are Meta
     [else
      (string< a b)])))

(define (CreateRgHelpText menu)
  (let ([rgHelpStr (cond
		    [(= menu MMAIN) textHelpMain]
		    [else '()])])
    (do ([iFunc 0 (1+ iFunc)]) ([= iFunc (length vrgFunctions)])
      (let ([eFunc (list-ref vrgFunctions iFunc)]
	    [rgSc '()])
	(when (and (logtest (GetFunctionMenus eFunc) vMenuCur)
		   (not (string-null? (GetFunctionDesc eFunc))))
	  ;; Get the shortcuts for this func
	  (do ([iSc 0 (1+ iSc)]) ([= iSc (length vrgShortcuts)])
	    (let ([eSc (list-ref vrgShortcuts iSc)])
	      (when (= (GetFunctionId eFunc) (GetShortcutFuncId eSc))
		(set! rgSc (append! rgSc (list (GetShortcutKeyStr eSc)))))))
	  ;; Construct help line. 1st Controls, then Fkey, then Meta
	  (sort! rgSc CompareShortcutKeyStrings)
	  (set! rgHelpStr 
		(append rgHelpStr (list (format #f "~7a~7a~7a    ~a"
						(if (> (length rgSc) 0)
						    (list-ref rgSc 0)
						    "")
						(if (> (length rgSc) 1)
						    (list-ref rgSc 1)
						    "")
						(if (> (length rgSc) 2)
						    (list-ref rgSc 2)
						    "")
						(if (not (string-null? (GetFunctionHelp eFunc)))
						    (GetFunctionHelp eFunc)
						    (GetFunctionDesc eFunc)))))))))
    rgHelpStr))
