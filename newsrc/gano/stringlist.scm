;; A stringlist is a list of strings.  Each list element represents
;; a single line of text.

(define-module (gano stringlist)
  #:use-module (srfi srfi-1)
  #:export (
            ;; Operations
            strlist-insert-in-line
            strlist-replace-in-line
            strlist-move-in-line
            strlist-copy-in-line
            strlist-delete-in-line

            strlist-insert-lines
            strlist-replace-lines
            strlist-move-lines
            strlist-copy-lines
            strlist-delete-lines

            strlist-merge-lines
            strlist-split-line))

(define (sublist list start end)
  (drop (take list end) start))

(define-syntax strlist-insert-in-line
  (syntax-rules ()
    ((_ strlist LInsert PInsert txt)
     (let ((linetxt (list-ref strlist LInsert)))
     (set! strlist
       (append
        (take strlist LInsert)
        (list (string-append (string-take linetxt PInsert)
                             txt
                             (string-drop linetxt PInsert)))
        (drop strlist (1+ LInsert))))))))

(define-syntax strlist-replace-in-line
  (syntax-rules ()
    ((_ strlist LReplace PReplaceStart PReplaceEnd txt)
     (let* ((linetxt (list-ref strlist LReplace))
            (removedtxt (substring linetxt PReplaceStart PReplaceEnd)))
       (set! strlist
         (append
          (take strlist LReplace)
          (list (string-append (string-take linetxt PReplaceStart)
                               txt
                               (string-drop linetxt PReplaceEnd)))
          (drop strlist (1+ LReplace))))
       removedtxt))))

(define-syntax strlist-move-in-line
  (syntax-rules ()
    ((_ strlist LMove PMoveStart PMoveEnd PMoveAfter)
     (let* ((linetxt (list-ref strlist LMove))
            (movetxt (substring linetxt PMoveStart PMoveEnd)))
       (set! strlist
         (append
          (take strlist LMove)
          (list (cond
                 ((< PMoveAfter PMoveStart)
                  (string-append (substring linetxt 0 PMoveAfter)
                                 movetxt
                                 (substring linetxt PMoveAfter PMoveStart)
                                 (substring linetxt PMoveEnd)))
                 (else
                  (string-append (substring linetxt 0 PMoveStart)
                                 (substring linetxt PMoveEnd PMoveAfter)
                                 movetxt
                                 (substring linetxt PMoveAfter)))))
          (drop strlist (1+ LMove))))))))

(define-syntax strlist-copy-in-line
  (syntax-rules ()
    ((_ strlist LCopy PCopyStart PCopyEnd PCopyAfter)
     (let* ((linetxt (list-ref strlist LCopy))
            (copytxt (substring linetxt PCopyStart PCopyEnd)))
       (set! strlist
         (append
          (take strlist LCopy)
          (list (string-append (substring linetxt 0 PCopyAfter)
                               copytxt
                               (substring linetxt PCopyAfter)))
          (drop strlist (1+ LCopy))))))))

(define-syntax strlist-delete-in-line
  (syntax-rules ()
    ((_ strlist LDelete PDeleteStart PDeleteEnd)
     (let* ((linetxt (list-ref strlist LDelete))
            (deletedtxt (substring linetxt PDeleteStart PDeleteEnd)))
       (set! strlist
         (append
          (take strlist LDelete)
          (list (string-append (substring linetxt 0 PDeleteStart)
                               (substring linetxt PDeleteEnd)))
          (drop strlist (1+ LDelete))))
       deletedtxt))))

(define (strlist-insert-lines strlist LInsert txtlists)
  (syntax-rules()
    ((_ strlist LInsert txtlist)
     (set! strlist
       (take strlist LInsert)
       txtlist
       (drop strlist LInsert)))))

(define-syntax strlist-replace-lines
  (syntax-rules()
    ((_ strlist LReplaceStart LReplaceEnd txtlist)
     (let ((replacedtxt (sublist strlist LReplaceStart LReplaceEnd)))
       (set! strlist
         (append
          (take strlist LReplaceStart)
          txtlist
          (drop strlist LReplaceEnd)))
       replacedtxt))))

(define-syntax strlist-delete-lines
  (syntax-rules()
    ((_ strlist LDeleteStart LDeleteEnd)
     (let ((deletedtxt (sublist strlist LDeleteStart LDeleteEnd)))
       (set! strlist
         (append
          (take strlist LDeleteStart)
          (drop strlist LDeleteEnd)))
       deletedtxt))))

(define-syntax strlist-move-lines
  (syntax-rules()
    ((_ strlist LMoveStart LMoveEnd LMoveAfter)
     (set! strlist
       (cond
        ((< LMoveAfter LMoveStart)
         (append
          (take strlist (1+ LMoveAfter))
          (sublist strlist LMoveStart (1+ LMoveAfter))
          (sublist strlist LMoveAfter LMoveStart)
          (drop strlist LMoveEnd)))
        (else
         (append
          (take strlist LMoveStart)
          (sublist strlist LMoveEnd (1+ LMoveAfter))
          (sublist strlist LMoveStart LMoveEnd)
          (drop strlist LMoveAfter))))))))

(define-syntax strlist-copy-lines
  (syntax-rules()
    ((_ strlist LCopyStart LCopyEnd LCopyAfter)
     (set! strlist
       (append
        (take strlist LCopyAfter)
        (sublist strlist LCopyStart LCopyAfter)
        (drop strlist LCopyAfter))))))

(define-syntax strlist-merge-lines
  (syntax-rules()
    ((_ strlist LMergeStart LMergeEnd)
     (set! strlist
       (append
        (take strlist LMergeStart)
        (list (apply string-append (sublist strlist LMergeStart LMergeEnd)))
        (drop strlist LMergeEnd))))))

(define-syntax strlist-split-line
  (syntax-rules()
    ((_ strlist LSplit PSplitAfter)
     (set! strlist
       (append
        (take strlist LSplit)
        (list (string-take (list-ref strlist LSplit) PSplitAfter)
              (string-drop (list-ref strlist LSplit) PSplitAfter))
        (drop strlist (1+ LSplit)))))))

;; Local Variables:
;; coding: iso-latin-1-unix
;; indent-tabs-mode: nil
;; End:
