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
            strlist-split-lines))

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
    ((_ strlist LMoveStart LMoveEnd LMoveTo)
     (set! strlist
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
          (drop strlist LMoveTo))))))))

(define-syntax strlist-copy-lines
  (syntax-rules()
    ((_ strlist LCopyStart LCopyEnd LCopyTo)
     (set! strlist
       (append
        (take strlist LCopyTo)
        (sublist strlist LCopyStart LCopyEnd)
        (drop strlist LCopyTo))))))

(define-syntax strlist-merge-lines
  (syntax-rules()
    ((_ strlist LMergeStart LMergeEnd)
     (set! strlist
       (append
        (take strlist LMergeStart)
        (list (apply string-append (sublist strlist LMergeStart LMergeEnd)))
        (drop strlist LMergeEnd))))))

(define-syntax strlist-split-lines
  (syntax-rules()
    ((_ strlist LSplit LengthList)
     (let ((str (list-ref strlist LSplit)))
       (set! strlist
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
          (drop strlist (1+ LSplit))))))))

