;;; -*- mode: scheme; coding: us-ascii; indent-tabs-mode: nil; -*-
;;; (gano poslist) -- adjust lists of locations under mutation
;;; Copyright (C) 2017 Michael L. Gran <spk121@yahoo.com>
;;;
;;; This program is free software: you can redistribute it and/or
;;; modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundataion, either version 3 of
;;; this License, or (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see
;;; <http://www.gnu.org/licenses/>


;; Named position lists are association lists between names and
;; positions in a text. There are two flavors of named position lists:
;; bookmarks and tags.

;; For bookmarks, names most be unique, and a text position may have
;; only one name.  Under a copy operation, a bookmark is not copied
;; and stays with the original text.

;; For tags, the names need not be unique, and each position may have
;; any number of tags.  Under a copy operation, tags are also copied.

;; Bookmarks might be used when implementing navigation.
;; Tags might be used for markup.

(define-module (gano poslist)
  #:use-module (srfi srfi-1)
  #:use-module (gano position)
  #:export (

            ;; Operations
            bookmark-get
            bookmark-get-at
            bookmark-get-all-in-line
            bookmark-set!
            bookmark-remove!
            bookmark-remove-at!
            bookmark-name-at?

            tag-get-all-by-name
            tag-get-all-at
            tag-set!
            tag-remove-all-by-name!
            tag-remove-at-by-name!
            tag-remove-all-at!
            tag-name-at?

            adjust-poslist-insert-in-line-after
            adjust-poslist-insert-in-line-before
            adjust-poslist-replace-in-line
            adjust-poslist-move-in-line
            adjust-poslist-copy-in-line
            adjust-poslist-delete-in-line
            poslist-copy-in-line

            adjust-poslist-insert-lines-before
            adjust-poslist-insert-lines-after
            adjust-poslist-replace-lines
            adjust-poslist-move-lines
            adjust-poslist-copy-lines
            poslist-copy-lines
            adjust-poslist-delete-lines

            adjust-poslist-merge-lines
            adjust-poslist-split-lines


            ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (bookmark-get poslist name)
  (assoc-ref poslist name))

(define (bookmark-get-at poslist line pos)
  (find (lambda (entry)
            (and
             (equal? (list-ref entry 1) line)
             (equal? (list-ref entry 2) pos)))
          poslist))

(define (bookmark-get-all-in-line poslist line)
  (filter (lambda (entry)
             (equal? (list-ref entry 1) line))
          poslist))


(define (bookmarks-get-not-at poslist line pos)
  (filter! (lambda (entry)
             (not
              (and
               (equal? (list-ref entry 1) line)
               (equal? (list-ref entry 2) pos))))
           poslist))

;; Remove the old bookmarks at this position, if it exists, and then
;; add a new bookmark.
(define-syntax bookmark-set!
  (syntax-rules ()
    ((_ poslist name line pos)
     (begin
       (set! poslist (assoc-set! (bookmarks-get-not-at poslist line pos)
                            name (list line pos)))))))

(define-syntax bookmark-remove!
  (syntax-rules ()
    ((_ poslist name)
     (set! poslist (assoc-remove! poslist name)))))

(define-syntax bookmark-remove-at!
  (syntax-rules ()
    ((_ poslist line pos)
     (set! poslist
       (filter! (lambda (entry)
                  (not
                   (and
                    (equal? (list-ref entry 1) line)
                    (equal? (list-ref entry 2) pos))))
                poslist)))))

(define (bookmark-name-at? poslist name line pos)
  (let ((entry (assoc name poslist)))
    (and entry
         (equal? line (list-ref entry 1))
         (equal? pos (list-ref entry 2)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (tag-get-all-by-name poslist name)
  (filter (lambda (entry)
            (equal? (car entry) name))
          poslist))

(define (tag-get-all-at poslist line pos)
  (filter (lambda (entry)
            (and
             (equal? (list-ref entry 1) line)
             (equal? (list-ref entry 2) pos)))
          poslist))

(define (tag-name-at? poslist name line pos)
  (let ((entry (find (lambda (entry)
                       (and
                        (equal? (list-ref entry 0) name)
                        (equal? (list-ref entry 1) line)
                        (equal? (list-ref entry 2) pos)))
                     poslist)))
    (if entry
        #t
        #f)))

(define-syntax tag-set!
  (syntax-rules ()
    ((_ poslist name line pos)
     (begin
       (if (not (tag-name-at? poslist name line pos))
           (set! poslist (acons name (list line pos) poslist)))))))

(define-syntax tag-remove-all-by-name!
  (syntax-rules ()
    ((_ poslist name)
     (set! poslist
       (filter! (lambda (entry)
                  (not (equal? (car entry) name)))
                poslist)))))

(define-syntax tag-remove-at-by-name!
  (syntax-rules ()
    ((_ poslist name line pos)
     (set! poslist
       (filter! (lambda (entry)
                  (not
                   (and (equal? (car entry) name)
                        (equal? (list-ref entry 1) line)
                        (equal? (list-ref entry 2) pos))))
                poslist)))))

(define-syntax tag-remove-all-at!
  (syntax-rules ()
    ((_ poslist name line pos)
     (set! poslist
       (filter! (lambda (entry)
                  (not
                   (and (equal? (list-ref entry 1) line)
                        (equal? (list-ref entry 2) pos))))
                poslist)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-syntax adjust-positions
  (syntax-rules ()
    ((_ proc poslist)
     (set! poslist
       (fold-right
        (lambda (entry ret)
          (let ((LPos (list-ref entry 1))
                (PPos (list-ref entry 2)))
            (let ((adjusted-pos (proc LPos PPos)))
              (if (null-list? adjusted-pos)
                  ret
                  (begin
                    (set-cdr! entry (proc LPos PPos))
                    (cons entry ret))))))
        (list)
        poslist)))))

(define-syntax adjust-poslist-insert-in-line-after
  (syntax-rules ()
    ((_ poslist LInsert PInsert LenInsert)
     (adjust-positions
      (lambda (LPos PPos)
        (pos-insert-in-line-after LPos PPos LInsert PInsert LenInsert))
      poslist))))

(define-syntax adjust-poslist-insert-in-line-before
  (syntax-rules ()
    ((_ poslist LInsert PInsert LenInsert)
     (adjust-positions
      (lambda (LPos PPos)
        (pos-insert-in-line-before LPos PPos LInsert PInsert LenInsert))
      poslist))))

(define-syntax adjust-poslist-replace-in-line
  (syntax-rules ()
    ((_ poslist LReplace PReplaceStart PReplaceEnd ReplaceLen)
     (adjust-positions
      (lambda (LPos PPos)
        (pos-replace-in-line LPos PPos LReplace PReplaceStart PReplaceEnd ReplaceLen))
      poslist))))

(define-syntax adjust-poslist-move-in-line
  (syntax-rules()
    ((_ poslist LMove PMoveStart PMoveEnd PMoveAfter)
     (adjust-positions
      (lambda (LPos PPos)
        (pos-move-in-line LPos PPos LMove PMoveStart PMoveEnd PMoveAfter))
      poslist))))

(define-syntax adjust-poslist-copy-in-line
  (syntax-rules ()
    ((_ poslist LCopy PCopyStart PCopyEnd PCopyAfter followCopy)
     (adjust-positions
      (lambda (LPos PPos)
        (pos-copy-in-line LPos PPos LCopy PCopyStart PCopyEnd PCopyAfter followCopy))
      poslist))))

;; Moves the entries as a response to a copy-in-line. An entry in the
;; region to be copied will be duplicated, with the original tag
;; remaining in the original region and the copy moved to the copied
;; region.
(define-syntax poslist-copy-in-line
  (syntax-rules ()
    ((_ poslist LCopy PCopyStart PCopyEnd PCopyAfter)
     (set! poslist
       (fold-right
        (lambda (entry ret)
          (let ((LPos (list-ref entry 1))
                (PPos (list-ref entry 2)))
            (let ((adjusted-pos (pos-copy-in-line LPos PPos LCopy PCopyStart PCopyEnd PCopyAfter #t)))
              (cond
               ((and (= LPos LCopy) (<= PCopyStart PPos) (< PPos PCopyAfter))
                ;; We're in the region to be copied, so we make two
                ;; entries.  The original is not moved, and the copy
                ;; is moved.
                (let ((newentry (set-cdr! (list-copy entry) adjusted-pos)))
                  (cons newentry (cons entry ret)))))
              (else
               (set-cdr! entry adjusted-pos)
               (cons entry ret)))))
        (list)
        poslist)))))


(define-syntax adjust-poslist-delete-in-line
  (syntax-rules ()
    ((_ poslist LDelete PDeleteStart PDeleteEnd)
     (adjust-positions
      (lambda (LPos PPos)
        (pos-delete-in-line LPos PPos LDelete PDeleteStart PDeleteEnd))
      poslist))))

(define-syntax adjust-poslist-insert-lines-before
  (syntax-rules ()
    ((_ poslist LInsert LCount)
     (adjust-positions
      (lambda (LPos PPos)
        (pos-insert-lines-before LPos PPos LInsert LCount))
      poslist))))

(define-syntax adjust-poslist-insert-lines-after
  (syntax-rules ()
    ((_ poslist LInsert LCount)
     (adjust-positions
      (lambda (LPos PPos)
        (pos-insert-lines-after LPos PPos LInsert LCount))
      poslist))))

(define-syntax adjust-poslist-replace-lines
  (syntax-rules ()
    ((_ poslist LReplaceStart LReplaceEnd ReplaceLen)
     (adjust-positions
      (lambda (LPos PPos)
        (pos-replace-lines LPos PPos LReplaceStart LReplaceEnd ReplaceLen))
      poslist))))

(define-syntax adjust-poslist-move-lines
  (syntax-rules ()
    ((_ poslist LMoveStart LMoveEnd LMoveTo)
     (adjust-positions
      (lambda (LPos PPos)
        (pos-move-lines LPos PPos LMoveStart LMoveEnd LMoveTo))
      poslist))))

(define-syntax adjust-poslist-copy-lines
  (syntax-rules ()
    ((_ poslist LCopyStart LCopyEnd LCopyTo followCopy)
     (adjust-positions
      (lambda (LPos PPos)
        (pos-copy-lines LPos PPos LCopyStart LCopyEnd LCopyTo followCopy))
      poslist))))

;; Moves the entries as a response to a copy-lines. An entry in the
;; region to be copied will be duplicated, with the original tag
;; remaining in the original region and the copy moved to the copied
;; region.
(define-syntax poslist-copy-lines
  (syntax-rules ()
    ((_ poslist LCopyStart LCopyEnd LCopyAfter)
     (set! poslist
       (fold-right
        (lambda (entry ret)
          (let ((LPos (list-ref entry 1))
                (PPos (list-ref entry 2)))
            (let ((adjusted-pos (pos-copy-lines LPos PPos LCopyStart LCopyEnd LCopyAfter #t)))
              (cond
               ((and (<= LCopyStart LPos) (< LPos LCopyEnd))
                ;; We're in the region to be copied, so we make two
                ;; entries.  The original is not moved, and the copy
                ;; is moved.
                (let ((newentry (set-cdr! (list-copy entry) adjusted-pos)))
                  (cons newentry (cons entry ret)))))
              (else
               (set-cdr! entry adjusted-pos)
               (cons entry ret)))))
        (list)
        poslist)))))

(define-syntax adjust-poslist-delete-lines
  (syntax-rules ()
    ((_ poslist LDeleteStart LDeleteEnd)
     (adjust-positions
      (lambda (LPos PPos)
        (pos-delete-lines LPos PPos LDeleteStart LDeleteEnd))
      poslist))))

(define-syntax adjust-poslist-merge-lines
  (syntax-rules ()
    ((_ poslist LMergeStart LMergeEnd PMergeLengthList)
     (adjust-positions
      (lambda (LPos PPos)
        (pos-merge-lines LPos PPos LMergeStart LMergeEnd PMergeLengthList))
      poslist))))

(define-syntax adjust-poslist-split-lines
  (syntax-rules ()
    ((_ poslist LSplit PSplitAfter)
     (adjust-positions
      (lambda (LPos PPos)
        (pos-split-lines LPos PPos LSplit PSplitAfter))
      poslist))))
