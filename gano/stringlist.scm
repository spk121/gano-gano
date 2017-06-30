;;; -*- mode: scheme; coding: us-ascii; indent-tabs-mode: nil; -*-
;;; (gano stringlist) - a library of procedures for lists of strings
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

(define-module (gano stringlist)
  #:use-module (srfi srfi-1)
  #:use-module (mlg logging)
  #:export (
            ;; Operations
            strlist-insert-in-line
            strlist-replace-in-line
            strlist-move-in-line
            strlist-unmove-in-line
            strlist-copy-in-line
            strlist-delete-in-line

            strlist-insert-lines
            strlist-replace-lines
            strlist-move-lines
            strlist-copy-lines
            strlist-delete-lines

            strlist-merge-lines
            strlist-split-lines))

(define (sublist list start end)
  (drop (take list end) start))

(define (strlist-insert-in-line strlist LInsert PInsert txt)
  (if (= LInsert (length strlist))
      (begin
        (warn-if-false (= 0 PInsert))
        (append strlist (list txt)))
      ;; else
      (let ((linetxt (list-ref strlist LInsert)))
        (append
         (take strlist LInsert)
         (list (string-append (string-take linetxt PInsert)
                              txt
                              (string-drop linetxt PInsert)))
         (drop strlist (1+ LInsert))))))

(define (strlist-replace-in-line strlist LReplace PReplaceStart PReplaceEnd txt)
  (let* ((linetxt (list-ref strlist LReplace)))
    (if (string-null? txt)
        strlist
        ;; else
        (append
         (take strlist LReplace)
         (list (string-append (string-take linetxt PReplaceStart)
                              txt
                              (string-drop linetxt PReplaceEnd)))
         (drop strlist (1+ LReplace))))))

(define (strlist-move-in-line strlist LMove PMoveStart PMoveEnd PMoveTo)
  (let* ((linetxt (list-ref strlist LMove))
         (movetxt (substring linetxt PMoveStart PMoveEnd)))
    (append
     (take strlist LMove)
     (list (cond
            ((= PMoveTo PMoveStart)
             linetxt)
            ((< PMoveTo PMoveStart)
             (string-append (substring linetxt 0 PMoveTo)
                            movetxt
                            (substring linetxt PMoveTo PMoveStart)
                            (substring linetxt PMoveEnd)))
            (else
             (string-append (substring linetxt 0 PMoveStart)
                            (substring linetxt PMoveEnd PMoveTo)
                            movetxt
                            (substring linetxt PMoveTo)))))
     (drop strlist (1+ LMove)))))

(define (strlist-unmove-in-line strlist LMove PMoveStart PMoveEnd PMoveTo)
  (let* ((linetxt (list-ref strlist LMove))
         (movetxt (substring linetxt PMoveStart PMoveEnd)))
    (append
     (take strlist LMove)
     (list (cond
            ((= PMoveTo PMoveStart)
             linetxt)
            ((< PMoveTo PMoveStart)
             (let ((pre (substring linetxt 0 PMoveTo))
                   (movetxt (substring linetxt
                                       PMoveTo
                                       (+ PMoveTo (- PMoveStart) PMoveEnd)))
                   (pushtxt (substring linetxt
                                       (+ PMoveTo (- PMoveStart) PMoveEnd)
                                       PMoveEnd))
                   (post (substring linetxt PMoveEnd)))
               (string-append pre pushtxt movetxt post)))
            (else
             (let ((pre (substring linetxt 0 PMoveStart))
                   (pushtxt (substring linetxt
                                       PMoveStart
                                       (+ PMoveStart (- PMoveEnd) PMoveTo)))
                   (movetxt (substring linetxt
                                       (+ PMoveStart (- PMoveEnd) PMoveTo)
                                       PMoveTo))
                   (post (substring linetxt PMoveTo)))
               (string-append pre movetxt pushtxt post)))))
     (drop strlist (1+ LMove)))))

(define (strlist-copy-in-line strlist LCopy PCopyStart PCopyEnd PCopyTo)
  (let* ((linetxt (list-ref strlist LCopy))
         (copytxt (substring linetxt PCopyStart PCopyEnd)))
    (append
     (take strlist LCopy)
     (list (string-append (substring linetxt 0 PCopyTo)
                          copytxt
                          (substring linetxt PCopyTo)))
     (drop strlist (1+ LCopy)))))

;; Remove character in line LDelete from PDeleteStart (inclusive) to
;; PDeleteEnd (exclusive).
(define (strlist-delete-in-line strlist LDelete PDeleteStart PDeleteEnd)
  (let* ((linetxt (list-ref strlist LDelete)))
    (append
     (take strlist LDelete)
     (list (string-append (substring linetxt 0 PDeleteStart)
                          (substring linetxt PDeleteEnd)))
     (drop strlist (1+ LDelete)))))

(define (strlist-insert-lines strlist LInsert txtlist)
  (append
   (take strlist LInsert)
   txtlist
   (drop strlist LInsert)))

(define (strlist-replace-lines strlist LReplaceStart LReplaceEnd txtlist)
  (append
   (take strlist LReplaceStart)
   txtlist
   (drop strlist LReplaceEnd)))

(define (strlist-delete-lines strlist LDeleteStart LDeleteEnd)
  (append
   (take strlist LDeleteStart)
   (drop strlist LDeleteEnd)))

(define (strlist-move-lines strlist LMoveStart LMoveEnd LMoveTo)
  (cond
   ((= LMoveTo LMoveStart)
    strlist)
   ((< LMoveTo LMoveStart)
    (append
     (take strlist LMoveTo)
     (sublist strlist LMoveStart LMoveEnd)
     (sublist strlist LMoveTo LMoveStart)
     (drop strlist LMoveEnd)))
   (>= LMoveTo LMoveEnd
       (append
        (take strlist LMoveStart)
        (sublist strlist LMoveEnd LMoveTo)
        (sublist strlist LMoveStart LMoveEnd)
        (drop strlist LMoveTo)))))

(define (strlist-copy-lines strlist LCopyStart LCopyEnd LCopyTo)
  (append
   (take strlist LCopyTo)
   (sublist strlist LCopyStart LCopyEnd)
   (drop strlist LCopyTo)))

(define (strlist-merge-lines strlist LMergeStart LMergeEnd)
  (append
   (take strlist LMergeStart)
   (list (apply string-append (sublist strlist LMergeStart LMergeEnd)))
   (drop strlist LMergeEnd)))

(define (strlist-split-lines strlist LSplit LengthList)
  (let ((str (list-ref strlist LSplit)))
    (append
     (take strlist LSplit)
     (let loop ((i 0)
                (out '()))
       (cond
        ((= i 0)
         (loop (1+ i)
               (list (string-take str (list-ref LengthList i)))))
        ((< i (length LengthList))
         (loop (1+ i)
               (append
                out
                (list (substring str
                                 (list-ref LengthList (1- i))
                                 (list-ref LengthList i))))))
        (else
         out)))
     (drop strlist (1+ LSplit)))))
