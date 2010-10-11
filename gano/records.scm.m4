m4_include(`config.m4')

(define-module (gano records)
  #:use-module (rnrs records syntactic)
  #:export (
            ;; records
            make-sc
            sc?
            sc-keystr
            sc-keystr-set!
            sc-type
            sc-type-set!
            sc-seq
            sc-seq-set!
            sc-menu
            sc-menu-set!
            sc-scfunc
            sc-scfunc-set!
            sc-toggle
            sc-toggle-set!
            sc-execute
            sc-execute-set!
            sc-next
            sc-next-set!

            make-subnfunc
            subnfunc?
            subnfunc-scfunc
            subnfunc-scfunc-set!
            subnfunc-menus
            subnfunc-menus-set!
            subnfunc-desc
            subnfunc-desc-set!
            m4_ifdef({DISABLE_HELP},{},{
            subnfunc-help
            subnfunc-help-set!
            subnfunc-blank_after
            subnfunc-blank_after-set!
            })
            subnfunc-viewok
            subnfunc-viewok-set!
            subnfunc-toggle
            subnfunc-toggle-set!
            subnfunc-next
            subnfunc-next-set!

            filestruct-data
            filestruct-data-set!
            filestruct-lineno
            filestruct-lineno-set!
            filestruct-multidata
            filestruct-multidata-set!
            filestruct-next
            filestruct-next-set!
            filestruct-prev
            filestruct-prev-set!


            openfile?
            set-openfile!
            append-openfile!
            make_new_opennode
            make_new_node
            initialize_buffer_text

            make-filestruct
            make-openfilestruct
            openfile-current-index-set!
            openfile-current-index
            openfile-current-lineno
            openfile-current_x
            openfile-current_x-set!
            openfile-current_y
            openfile-current_y-set!
            openfile-edittop
            openfile-edittop-index
            openfile-edittop-index-set!
            openfile-edittop-lineno
            openfile-fileage-data-set!
            openfile-fileage
            openfile-fileage-set!
            openfile-filename
            openfile-filename-set!
            openfile-modified
            openfile-modified-set!
            openfile-placewewant
            openfile-placewewant-set!
            openfile-totsize
            openfile-totsize-set!
            ))

;; The list of all open file buffers
(define %openfile #f)

;; The index of the current buffer in the openfile file buffer list
(define openfile_index 0)

;; Returns #t if there in any open files
(define (openfile?)
  (if (and %openfile (not (null? %openfile))) #t #f))

(define (openfile)
  (if %openfile
      (list-ref %openfile openfile_index)
      #f))

(define (set-openfile! x)
  (set! %openfile (list x))
  (set! openfile_index 0))

(define (append-openfile! x)
  (if (openfile?)
      (begin
        (set! %openfile (append %openfile (list x)))
        (set! openfile_index (1- (length %openfile))))
      (set-openfile! x)))

(define (openfile-current_x) (openfilestruct-current_x (openfile)))
(define (openfile-current_x-set! val) (openfilestruct-current_x-set! (openfile) val))
(define (openfile-current_y) (openfilestruct-current_y (openfile)))
(define (openfile-current_y-set! val) (openfilestruct-current_y-set! (openfile) val))
(define (openfile-placewewant) (openfilestruct-placewewant (openfile)))
(define (openfile-placewewant-set! val) (openfilestruct-placewewant-set! (openfile) val))
(define (openfile-modified) (openfilestruct-modified (openfile)))
(define (openfile-modified-set! val) (openfilestruct-modified-set! (openfile) val))
(define (openfile-fileage) (openfilestruct-fileage (openfile)))
(define (openfile-filename-set! val) (openfilestruct-filename-set! (openfile) val))
;; (define (openfile-fileage-data-set! val) (filestruct-data-set! (openfilestruct-fileage (openfile)) val))
(define (openfile-current_stat) (openfilestruct-current_stat (openfile)))
(define (openfile-current_stat-set! val) (openfilestruct-current_stat-set! (openfile) val))
(define (openfile-current-index) (openfilestruct-current-index (openfile)))
(define (openfile-current-index-set! val) (openfilestruct-current-index-set! (openfile) val))
(define (openfile-edittop-index) (openfilestruct-edittop-index (openfile)))

;; Create a new openfilestruct node
(define (make_new_opennode)
  (let ((newnode (make-openfilestruct)))
    (openfilestruct-filename-set! newnode #f)
    (openfilestruct-fileage-set! newnode #f)
    ;; filebot not used
    (openfilestruct-edittop-index-set! newnode 0)
    (openfilestruct-current-index-set! newnode 0)
    m4_ifdef({NANO_TINY},{},{
    (openfilestruct-current_stat-set! newnode #f)
    (openfilestruct-last_action-set! newnode OTHER)
    })
    newnode))

;; Initialize the text of the current entry of the openfile openfilestruct
(define (initialize_buffer_text)
  (openfilestruct-fileage-set! (openfile) (list (make_new_node #f)))
  (openfile-fileage-data-set! "")
  (openfilestruct-edittop-index-set! (openfile) 0)
  (openfilestruct-current-index-set! (openfile) 0)
  m4_ifdef({ENABLE_COLOR},{
  (openfilestruct-fileage-multidata-set! (openfile) #f)
  })
  (openfilestruct-totsize-set! (openfile) 0))

;; Create a new filestruct node.  Note that we do not set prevnode->next
;; to the new line
(define (make_new_node prevnode)
  (let ((newnode (make-filestruct)))
    (filestruct-data-set! newnode #f)
    (filestruct-prev-set! newnode prevnode)
    (filestruct-next-set! newnode #f)
    (filestruct-lineno-set! newnode (if prevnode 
                                        (+ 1 (filestruct-lineno prev))
                                        1))
    m4_ifdef({ENABLE_COLOR},{
    (filestruct-multidata-set! newnode #f)
    })
    newnode))


m4_ifdef({ENABLE_COLOR},{
(define-record-type colortype
  (fields
   ;; This syntax's foreground color
   (mutable fg)
   ;; This syntax's background color
   (mutable bg)
   ;; Is this color A_BOLD?
   (mutable bright)
   ;; Is this regex string case insensitive?
   (mutable icase)
   ;; The color pair number used for this pair
   (mutable pairnum)
   ;; The start (or all) of the regex string
   (mutable start_regex)
   ;; The compiled start (or all) of the regex string
   (mutable start)
   ;; The end (if any) of the regex string
   (mutable end-regex)
   ;; The compiled end (if any) of the regex string
   (mutable end)
   ;; Next set of colors
   (mutable next)
   ;; Basic id for assigning to lines later
   (mutable id)
   ))
})

(define-record-type exttype
  (fields
   ;; The extension that match this syntax
   (mutable ext_regex)
   ;; The compiled extensions that match this syntax
   (mutable ext)
   ;; Next set of extensions
   (mutable next)))

(define-record-type syntaxtype
  (fields
   ;; The name of this syntax
   (mutable desc)
   ;; The list of extensions that this syntax applies to
   (mutable extensions)
   ;; Regexes to match on the 'header' (1st line) of the file
   (mutable headers)
   ;; The colors used in this syntax
   (mutable color)
   ;; How many multi line strings this syntax has
   (mutable nmultis)
   ;; Next Syntax
   (mutable next)
   ))
(define-record-type filestruct
  (fields
   ;; The text of this line
   (mutable data)
   ;; The numer of this line
   (mutable lineno)
   ;; Next node
   (mutable next)
   ;; Previous node
   (mutable prev)
m4_ifdef({ENABLE_COLOR},{
   ;;Array of which multi-line regexes apply to this line
   (mutable multidata)
})
  ))


(define-record-type partition
  (fields
   ;; The top line of this portion of the file.
   (mutable fileage)
   ;; The line before the top line of this portion of the file.
   (mutable top_prev)
   ;; The text before the beginning of the top line of this portion of the file.
   (mutable top_prev)
   ;; The bottom line of this portion of the file
   (mutable filebot)
   ;; The line after the bottom line of this portion of the file
   (mutable bot_next)
   ;; The text after the end of the bottom line of this portion of the file
   (mutable bot_data)))

m4_ifdef({NANO_TINY},{},{
(define-record-type undo
  (fields
   (mutable lineno)
   ;; What type of undo was this
   (mutable type)
   ;; Where did this action begin or end
   (mutable begin)
   ;; String type data we will use for copying the affected line back
   (mutable strdata)
   (mutable strdata2)
   (mutable xflags)

   ;; Cut specific stuff we need

   ;; Copy of the cutbuffer
   (mutable cutbuffer)
   ;; Copy of the cutbottom
   (mutable cutbottom)
   ;; Was the marker set when we cut
   (mutable mark_set)
   ;; Was this a cut to the end
   (mutable to_end)
   (mutable mark_begin_lineno)
   (mutable mark_begin_x)
   (mutable next)))
})

(define-record-type (openfilestruct make-openfilestruct openfilestruct?)
  (fields
   ;; The current file's name
   (mutable filename)
   ;; A list of filestructs that contain the current file's text
   (mutable fileage)
   ;; unused
   (immutable filebot)
   ;; The index of the list 'fileage' that is the top of the current window
   (mutable edittop-index)
   ;; The current file's current line. 
   ;; The index of the list 'fileage' that is the current line
   (mutable current-index)
   ;; The current file's total number of characters. 
   (mutable totsize)
   ;; The current file's x-coordinate position. 
   (mutable current_x)
   ;; The current file's place we want. 
   (mutable placewewant)
   ;; The current file's y-coordinate position. 
   (mutable current_y)
   ;; Whether the current file has been modified. 
   (mutable modified)
m4_ifdef({NANO_TINY},{},{
   ;; Whether the mark is on in the current file. 
   (mutable mark_set)
   ;; The current file's beginning marked line, if any. 
   (mutable mark_begin)
   ;; The current file's beginning marked line's x-coordinate
   ;; position, if any.
   (mutable  mark_begin_x)
   ;; The current file's format.
   (mutable fmt)
   ;; The current file's stat. 
   (mutable current_stat)
   ;; Top of the undo list 
   (mutable undotop)
   ;; The current (i.e. n ext) level of undo 
   (mutable current_undo)
   (mutable last_action)
})
m4_ifdef({ENABLE_COLOR},{
    ;; The  syntax struct for this file, if any 
    (mutable syntax)
    ;; The current file's associated colors. 
    (mutable colorstrings)
})
    ;; Next node. UNUSED
    (immutable next)
    ;; Previous node. UNUSED.
    (immutable prev)))

(define-record-type shortcut
  (fields
   ;; The function's description
   (mutable desc)
m4_ifdef({DISABLE_HELP},{},{   
   ;; The help file entry text for this function
   (mutable help)
   ;; Whether there should be a blank line after the help entry text
   (mutable blank_after)
})			    
    ;; Note: Key values that aren't used should be set to NANO_NO_KEY.
    
    ;; The special sentinel key or control key we want bound, if any
    (mutable ctrlval)
    ;; The meta key we want bound, if any
    (mutable metaval)
    ;; The function key we want bound, if any
    (mutable funcval)
    ;; The other meta key we want bound, if any
    (mutable miscval)
    ;; Is this function allowe when in view mode?
    (mutable viewok)
    ;; The function to call when we get this key
    (mutable func)
    ;; Next shortcut
    (mutable next)))

m4_ifdef({ENABLE_NANORC},{
(define-record-type rcoption
  (fields
    ;; The name of the rcfile option
    (mutable name)
    ;; The flag associated with it, if any
    (mutable flag)))
})

(define-record-type (sc make-sc sc?)
  (fields
   ;; The shortcut key for a function, ASCII version 
   (mutable keystr)
   ;; What kind of function key is it for convenience later 
   (mutable type)
   ;; The actual sequence to check on the the type is determined 
   (mutable seq)
   ;; What list does this apply to 
   (mutable menu)
   ;; The function we're going to run 
   (mutable scfunc)
   ;; If a toggle, what we're toggling 
   (mutable toggle)
	;; Whether to execute the function in question or just return
	;; so the sequence can be caught by the calling code
   (mutable execute)
   ;; Next in the list 
   (mutable next)))

(define-record-type (subnfunc make-subnfunc subnfunc?)
  (fields
   ;; What function is this 
   (mutable scfunc)
   ;; In what menus does this function applu 
   (mutable menus)
   ;; The function's description, e.g. "Page Up". 
   (mutable desc)
   m4_ifdef({DISABLE_HELP},{},{
   ;; The help file entry text for this function. 
   (mutable help)
   ;; Whether there should be a blank line after the help entry
   ;; text for this function.
   (mutable blank_after)
   })
   ;; Is this function allowed when in view mode? 
   (mutable viewok)
   ;; If this is a toggle, if nonzero what toggle to set 
   (mutable toggle)
   ;; next item in the list 
   (mutable next)
   ))

(define (openfile-current-lineno)
  (filestruct-lineno (list-ref (openfile-fileage) 
                               (openfile-current-index))))

(define (openfile-edittop)
  (list-ref (openfile-fileage) (openfile-edittop-index)))

(define (openfile-edittop-lineno)
  (filestruct-lineno (openfile-edittop)))

(define (openfile-fileage-data-set! val)
  (let ((node (list-ref (openfile-fileage)
                        (openfile-current-index))))
    (filestruct-data-set! node val)))

