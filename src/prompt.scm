(define-module (gano prompt)
  ;;#:use-module (gano CMiniBuffer)
  #:export (
            DoStatusbarInput
            ))

(define (DoStatusbarInput fFuncsAllow)
  (let ((meta_key #f)
        (input #f)
        (ran_func #f)
        (cut_copy #f)
        (kbinput #f))

    ;; Read in a character.  get_kbinput returns a qualifier and a key.
    ;; The qualifier is either 'raw or 'meta.  The key is
    ;; either a char or a ncurses keycode.
    (let ([kbinput (get_kbinput vWinBottom)])
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
          (let* ([s (GetShortcutFromMenuKey MMAIN input meta_key)]
                 ;; If we have a shortcut from the main list, or a
                 ;; "universal" edit window shortcut, set
                 ;; have_shortcut to true
                 [have_shortcut (not (not s))]
                 [funcId (if s (GetShortcutFuncId s) 0)])

            ;; If this wasn't a shortcut, and it isn't a regular character, quit
            (unless have_shortcut
              (when (or meta_key (not (char? input)) (IsControlChar? input))
                (beep)
                (set! meta_key #f)
                (set! input ERR)))

            (when fFuncsAllow
              ;; FIXME: view mode processing

              ;; If it is a regular character, output it
              (when (and (not have_shortcut) (not (eq? ERR input)))
                (DoStatusbarCharInsert input #f))

              ;; Finally, process the shortcuts
              (when have_shortcut
                (DispatchPrompt funcId)))))]))))

(define (DispatchPrompt funcId)
  "Given a function ID, execute the function"
  (cond
   [(or (eqv? funcId DO_TAB) (eqv? funcId DO_ENTER))
    *unspecified*]
   [(eqv? funcId TOTAL_REFRESH)
    (DoTotalRefresh)]
   [(eqv? funcId DO_CUT_TEXT)
    ;; In restricted mode, if the filename isn't blank, and
    ;; we're at the Write File prompts, disable, CUT
    (unless (and (ISSET RESTRICTED)
                 (not (string-null? (GetBufferFileName)))
                 (eqv? vMenuCur MWRITEFILE))
      (DoStatusbarCutText))]
   [(eqv? funcId DO_RIGHT)
    (DoStatusbarRight)]
   [(eqv? funcId DO_LEFT)
    (DoStatusbarLeft)]
   [(eqv? funcId DO_NEXT_WORD)
    (DoStatusbarNextWord)]
   [(eqv? funcId DO_PREV_WORD)
    (DoStatusbarPrevWord)]
   [(eqv? funcId DO_HOME)
    (DoStatusbarHome)]
   [(eqv? funcId DO_END)
    (DoStatusbarEnd)]
   [(eqv? funcId DO_FIND_BRACKET)
    (DoStatusbarFindBracket)]
   [(eqv? funcId DO_DELETE)
    ;; In restricted mode, if the filename isn't blank, and
    ;; we're at the Write File prompts, disable
    (unless (and (ISSET RESTRICTED)
                 (not (string-null? (GetBufferFileName)))
                 (eqv? vMenuCur MWRITEFILE))
      (DoStatusbarDelete))]
   [(eqv? funcId DO_BACKSPACE)
    ;; In restricted mode, if the filename isn't blank, and
    ;; we're at the Write File prompts, disable
    (unless (and (ISSET RESTRICTED)
                 (not (string-null? (GetBufferFileName)))
                 (eqv? vMenuCur MWRITEFILE))
      (DoStatusbarBackspace))]))

;; When the editable text in the minibuffer is longer than the display
;; it will be scrolled in chunks.  This function takes screen cell
;; location of the first cell in the editable text of the minibuffer,
;; and the cursor's location, and returns a cell location
(define (GetStatusbarPageStart xGoalStart xGoal)
  (if (or (= xGoalStart xGoal) (< xGoal (1- (cols))))
      0
      ;; else
      (+ xGoal
         (- xGoalStart)
         (- (quotient (- xGoal xGoalStart) (- (cols) (1- xGoalStart)))))))

(define (RefreshStatusbarLine)
  "Update the editable text portion of the minibuffer"
  (let ([colStart (+ 2 (CountCellsInString (GetMiniBufferPrompt)))]
        [xGoal (CountCellsInSubstring (GetMiniBufferText) (GetMiniBufferXCur))]
        [xGoalPageStart (GetStatusbarPageStart colStart xGoal)])
    (attr-on! fWinBottom vAttrReverse)
    (BlankStatusbar)
    (addstr fWinBottom 0 0 (GetMiniBufferPrompt)
            (GetIndexFromStringCell (GetMiniBufferPrompt) (- (cols) 2)))
    (addstr ":")
    (if (> xGoalPageStart 0) (addstr "$") (addstr " "))
    (addstr fWinBottom (DisplayString (GetMiniBufferText) xGoalPageStart
                                      (- (cols) (1- xGoalPageStart)) #f))
    (attr-of! fWinBottom vAttrReverse)
    (SetMiniBufferXGoal! (Get))
    (ResetStatusbarCursor)
    (refresh fWinBottom)))
