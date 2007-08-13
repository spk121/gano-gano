;; -*- mode: scheme;-*- 

;; This module contains all of the low-level ncurses functions.  These
;; functions are made to appear as close as possible to the NCurses C
;; API.

(define-module (ncurses core)
  :export (
	   ;; From add_wch.c
	   add-wch
	   wadd-wch
	   mvadd-wch
	   mvwadd-wch
	   echo-wchar
	   wecho-wchar
	   
	   ;; From addch.c
	   addch
	   waddch
	   mvaddch
	   echochar
	   wechochar
	   get-tabsize
	   set-tabsize

	   acs-block 
	   acs-board 
	   acs-btee
	   acs-bullet	   
	   acs-ckboard
	   acs-darrow
	   acs-degree
	   acs-diamond
	   acs-gequal
	   acs-hline 
	   acs-lantern
	   acs-larrow
	   acs-lequal
	   acs-llcorner 
	   acs-lrcorner 
	   acs-ltee
	   acs-nequal
	   acs-pi 
	   acs-plminus
	   acs-plus
	   acs-rarrow
	   acs-rtee
	   acs-s1 
	   acs-s3
	   acs-s7
	   acs-s9
	   acs-sterling
	   acs-ttee
	   acs-uarrow
	   acs-ulcorner
	   acs-urcorner
	   acs-vline

	   ;; From addstr.c
	   addstr
	   addnstr
	   waddstr
	   waddnstr
	   mvaddstr
	   mvaddnstr
	   mvwaddstr
	   mvwaddnstr

	   ;; From attr.c
	   attroff
	   wattroff
	   attron
	   wattron
	   attrset
	   wattrset
	   color-set
	   wcolor-set
	   standend
	   wstandend
	   standout
	   wstandout
	   attr-get
	   wattr-get
	   attr-off
	   wattr-off
	   attr-set
	   wattr-set
	   chgat
	   wchgat
	   mvwchgat
	   pair-number

	   ;; From colors.c
	   colors
	   color-pairs
	   color-pair
	   start-color
	   init-pair
	   init-color
	   has-colors
	   can-change-color
	   color-content
	   pair-content

	   ;; From default_colors.c
	   use-default-colors
	   assume-default-colors

	   ;; From getch.c
	   getch
	   wgetch
	   mvgetch
	   mvwgetch
	   ungetch
	   has-key
	   
	   ;; From initscr.c
	   stdscr
	   cols
	   lines
	   initscr
	   endwin
	   isendwin
	   ;; FIXME newterm
	   set-term
	   delscreen
	   
	   ;; From inopts.c
	   cbreak
	   nocbreak
	   echo
	   noecho
	   halfdelay
	   intrflush
	   keypad
	   meta
	   nodelay
	   raw
	   noraw
	   noqiflush
	   qiflush
	   notimeout
	   timeout
	   wtimeout
	   ;; FIXME: typeahead

	   ;; From kernel.c
	   def-prog-mode
	   def-shell-mode
	   reset-prog-mode
	   reset-shell-mode
	   resetty
	   savetty
	   getsyx
	   setsyx
	   ;; FIXME: ripoffline
	   curs-set
	   napms

	   ;; From move.c
	   move
	   wmove

	   ;; From refresh.c
	   refresh
	   wrefresh
	   wnoutrefresh
	   doupdate
	   redrawwin
	   wredrawln

	   ;; From this file
	   *color-black*
	   *color-red*
	   *color-green*
	   *color-yellow*
	   *color-blue*
	   *color-magenta*
	   *color-cyan*
	   *color-white*

	   *a-normal* 	
	   *a-standout* 	
	   *a-underline* 	
	   *a-reverse* 	
	   *a-blink* 	
	   *a-dim* 	
	   *a-bold* 	
	   *a-protect* 	
	   *a-invis* 	
	   *a-altcharset* 
	   *a-chartext* 	

	   *key-code-yes* 
	   *key-min*      
	   *key-break*    
	   *key-sreset*   
	   *key-reset*    
	   *key-down*     
	   *key-up*       
	   *key-left*     
	   *key-right*    
	   *key-home*     
	   *key-backspace*
	   *key-f0*       
	   *key-dl*       
	   *key-il*       
	   *key-dc*       
	   *key-ic*       
	   *key-eic*      
	   *key-clear*    
	   *key-eos*      
	   *key-eol*      
	   *key-sf*       
	   *key-sr*       
	   *key-npage*    
	   *key-ppage*    
	   *key-stab*     
	   *key-ctab*     
	   *key-catab*    
	   *key-enter*    
	   *key-print*    
	   *key-ll*       
	   *key-a1*       
	   *key-a3*       
	   *key-b2*       
	   *key-c1*       
	   *key-c3*       
	   *key-btab*     
	   *key-beg*      
	   *key-cancel*   
	   *key-close*    
	   *key-command*  
	   *key-copy*     
	   *key-create*   
	   *key-end*      
	   *key-exit*     
	   *key-find*     
	   *key-help*     
	   *key-mark*     
	   *key-message*  
	   *key-move*     
	   *key-next*     
	   *key-open*     
	   *key-options*  
	   *key-previous* 
	   *key-redo*     
	   *key-reference*
	   *key-refresh*  
	   *key-replace*  
	   *key-restart*  
	   *key-resume*   
	   *key-save*     
	   *key-sbeg*     
	   *key-scancel*  
	   *key-scommand* 
	   *key-scopy*    
	   *key-screate*  
	   *key-sdc*      
	   *key-sdl*      
	   *key-select*   
	   *key-send*     
	   *key-seol*     
	   *key-sexit*    
	   *key-sfind*    
	   *key-shelp*    
	   *key-shome*    
	   *key-sic*      
	   *key-sleft*    
	   *key-smessage* 
	   *key-smove*    
	   *key-snext*    
	   *key-soptions* 
	   *key-sprevious*
	   *key-sprint*   
	   *key-sredo*    
	   *key-sreplace* 
	   *key-sright*   
	   *key-srsume*   
	   *key-ssave*    
	   *key-ssuspend* 
	   *key-sundo*    
	   *key-suspend*  
	   *key-undo*     
	   *key-mouse*    
	   *key-resize*   
	   *key-event*    
	   *key-max*      
	   key-fn
	   ))

(display "Loading ncurses core") 
(newline)

(use-modules (ncurses config))

(load-extension (string-append 
		 ncurses-config-libdir 
		 "/cygguile-ncurses-0-0.dll") 
		"gnc_init_core")


;; Curses constants

;; From color
(define *color-black* 0)
(define *color-red* 1)
(define *color-green* 2)
(define *color-yellow* 3)
(define *color-blue* 4)
(define *color-magenta* 5)
(define *color-cyan* 6)
(define *color-white* 7)

;; From attr
(define *a-normal* 	0)
(define *a-standout* 	(ash 1 (+ 8 8)))
(define *a-underline* 	(ash 1 (+ 8 9)))
(define *a-reverse* 	(ash 1 (+ 8 10)))
(define *a-blink* 	(ash 1 (+ 8 11)))
(define *a-dim* 	(ash 1 (+ 8 12)))
(define *a-bold* 	(ash 1 (+ 8 13)))
(define *a-protect* 	(ash 1 (+ 8 16)))
(define *a-invis* 	(ash 1 (+ 8 15)))
(define *a-altcharset* 	(ash 1 (+ 8 14)))
(define *a-chartext* 	#b11111111)


;; From getch
(define *key-code-yes*	0400		) ; a wchar-t contains a key code 
(define *key-min*      	0401		) ; minimum curses key 
(define *key-break*	0401		) ; break key (unreliable) 
(define *key-sreset*	0530		) ; soft (partial) reset (unreliable) 
(define *key-reset*	0531		) ; reset or hard reset (unreliable) 
(define *key-down*	0402		) ; down-arrow key 
(define *key-up*       	0403		) ; up-arrow key 
(define *key-left*	0404		) ; left-arrow key 
(define *key-right*	0405		) ; right-arrow key 
(define *key-home*	0406		) ; home key 
(define *key-backspace*	0407		) ; backspace key 
(define *key-f0*       	0410		) ; function keys.  space for 64 
(define *key-dl*       	0510		) ; delete-line key 
(define *key-il*       	0511		) ; insert-line key 
(define *key-dc*       	0512		) ; delete-character key 
(define *key-ic*       	0513		) ; insert-character key 
(define *key-eic*      	0514		) ; sent by rmir or smir in insert mode 
(define *key-clear*	0515		) ; clear-screen or erase key 
(define *key-eos*      	0516		) ; clear-to-end-of-screen key 
(define *key-eol*      	0517		) ; clear-to-end-of-line key 
(define *key-sf*       	0520		) ; scroll-forward key 
(define *key-sr*       	0521		) ; scroll-backward key 
(define *key-npage*	0522		) ; next-page key 
(define *key-ppage*	0523		) ; previous-page key 
(define *key-stab*	0524		) ; set-tab key 
(define *key-ctab*	0525		) ; clear-tab key 
(define *key-catab*	0526		) ; clear-all-tabs key 
(define *key-enter*	0527		) ; enter/send key 
(define *key-print*	0532		) ; print key 
(define *key-ll*       	0533		) ; lower-left key (home down) 
(define *key-a1*       	0534		) ; upper left of keypad 
(define *key-a3*       	0535		) ; upper right of keypad 
(define *key-b2*       	0536		) ; center of keypad 
(define *key-c1*       	0537		) ; lower left of keypad 
(define *key-c3*       	0540		) ; lower right of keypad 
(define *key-btab*	0541		) ; back-tab key 
(define *key-beg*      	0542		) ; begin key 
(define *key-cancel*	0543		) ; cancel key 
(define *key-close*	0544		) ; close key 
(define *key-command*	0545		) ; command key 
(define *key-copy*	0546		) ; copy key 
(define *key-create*	0547		) ; create key 
(define *key-end*      	0550		) ; end key 
(define *key-exit*	0551		) ; exit key 
(define *key-find*	0552		) ; find key 
(define *key-help*	0553		) ; help key 
(define *key-mark*	0554		) ; mark key 
(define *key-message*	0555		) ; message key 
(define *key-move*	0556		) ; move key 
(define *key-next*	0557		) ; next key 
(define *key-open*	0560		) ; open key 
(define *key-options*	0561		) ; options key 
(define *key-previous*	0562		) ; previous key 
(define *key-redo*	0563		) ; redo key 
(define *key-reference*	0564		) ; reference key 
(define *key-refresh*	0565		) ; refresh key 
(define *key-replace*	0566		) ; replace key 
(define *key-restart*	0567		) ; restart key 
(define *key-resume*	0570		) ; resume key 
(define *key-save*	0571		) ; save key 
(define *key-sbeg*	0572		) ; shifted begin key 
(define *key-scancel*	0573		) ; shifted cancel key 
(define *key-scommand*	0574		) ; shifted command key 
(define *key-scopy*	0575		) ; shifted copy key 
(define *key-screate*	0576		) ; shifted create key 
(define *key-sdc*      	0577		) ; shifted delete-character key 
(define *key-sdl*      	0600		) ; shifted delete-line key 
(define *key-select*	0601		) ; select key 
(define *key-send*	0602		) ; shifted end key 
(define *key-seol*	0603		) ; shifted clear-to-end-of-line key 
(define *key-sexit*	0604		) ; shifted exit key 
(define *key-sfind*	0605		) ; shifted find key 
(define *key-shelp*	0606		) ; shifted help key 
(define *key-shome*	0607		) ; shifted home key 
(define *key-sic*		0610		) ; shifted insert-character key 
(define *key-sleft*	0611		) ; shifted left-arrow key 
(define *key-smessage*	0612		) ; shifted message key 
(define *key-smove*	0613		) ; shifted move key 
(define *key-snext*	0614		) ; shifted next key 
(define *key-soptions*	0615		) ; shifted options key 
(define *key-sprevious*	0616		) ; shifted previous key 
(define *key-sprint*	0617		) ; shifted print key 
(define *key-sredo*	0620		) ; shifted redo key 
(define *key-sreplace*	0621		) ; shifted replace key 
(define *key-sright*	0622		) ; shifted right-arrow key 
(define *key-srsume*	0623		) ; shifted resume key 
(define *key-ssave*	0624		) ; shifted save key 
(define *key-ssuspend*	0625		) ; shifted suspend key 
(define *key-sundo*	0626		) ; shifted undo key 
(define *key-suspend*	0627		) ; suspend key 
(define *key-undo*	0630		) ; undo key 
(define *key-mouse*	0631		) ; mouse event has occurred 
(define *key-resize*	0632		) ; terminal resize event 
(define *key-event*	0633		) ; we were interrupted by an event 

(define *key-max*      		0777		) ; maximum key value is 0633 

;; compute the key value for functionkey F(n)
(define (key-fn n)	
  (+ *key-f0* n)) 
