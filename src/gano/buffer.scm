;;; Gano Buffer Module
;;; One-stop import for the character buffer.
;;;
;;; The buffer is implemented in layers:
;;;
;;;   (gano cbuf-core)          records, accessors, conditions
;;;   (gano cbuf-basic)         minimum editing set + plugin undo system
;;;   (gano cbuf-standard)      search/replace, cut/paste, indent, paging
;;;   (gano cbuf-extra)         sorting, tabify, smarter word/case commands
;;;   (gano cbuf-serialization) load/save as plain text or JSON
;;;
;;; Editor code should just use (gano buffer), which re-exports the
;;; public interface of all five.  Where cbuf-extra replaces a
;;; cbuf-standard procedure (cbuf-upcase-region!, cbuf-downcase-region!,
;;; cbuf-select-word!), the cbuf-extra version is the one exported.

(define-module (gano buffer)
  #:use-module (gano cbuf-core)
  #:use-module (gano cbuf-basic)
  #:use-module ((gano cbuf-standard)
                #:hide (cbuf-upcase-region! cbuf-downcase-region! cbuf-select-word!))
  #:use-module (gano cbuf-extra)
  #:use-module (gano cbuf-serialization))

;; Rather than repeat ~250 names in a #:re-export clause that would
;; drift out of date, copy every binding these modules export into our
;; public interface.  Later modules in the list win on a name clash.
(let ([public (module-public-interface (current-module))]
      [hidden-from-standard '(cbuf-upcase-region!
                              cbuf-downcase-region!
                              cbuf-select-word!)])
  (for-each
   (lambda (name)
     (module-for-each
      (lambda (sym var)
        (unless (and (equal? name '(gano cbuf-standard))
                     (memq sym hidden-from-standard))
          (module-add! public sym var)))
      (resolve-interface name)))
   '((gano cbuf-core)
     (gano cbuf-basic)
     (gano cbuf-standard)
     (gano cbuf-extra)
     (gano cbuf-serialization))))
