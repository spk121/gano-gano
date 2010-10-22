(define-module (gano assert)
  #:export (
            assert-type
            ))

(define-syntax assert-type
  (lambda (x)
    (syntax-case x ()
      [(_ type var)
       #`(if (not (#,(datum->syntax #'var
                      (string->symbol (string-append 
                                       (symbol->string (syntax->datum #`type)) 
                                       "?")))
                   var))
             (error (string-append "not type '" 
                                   #,(symbol->string (syntax->datum #`type))
                                   "': ")
                    var))])))
