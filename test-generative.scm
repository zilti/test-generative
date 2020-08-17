(module test-generative (test-generative run-tests-with-generator current-test-generative-iterations)

(import scheme)
(import chicken.base)
(import chicken.string)
(import chicken.format)
(import chicken.condition)

(import test)
(import (only srfi-1 any reverse! zip))


(define current-test-generative-iterations (make-parameter 100))

;;TODO: currently test-group-filter/remove doesn't work with groups inside test-generative
;; test-filter/remove does work however

;; just do the bare minimum to evaluate the expression
;; this has been extracted from test's code
(define (apply-test expect expr info)
  (define (assq-ref ls key . o)
    (cond ((assq key ls) => cdr)
          ((pair? o) (car o))
          (else #f)))

  (let ((expect-val
         (condition-case
          (expect)
          (e () #t))))
    (condition-case
     (let ((res (expr)))
       (let ((status
              (if (and (not (assq-ref info 'expect-error))
                       (if (assq-ref info 'assertion)
                           res
                           ((current-test-comparator) expect-val res)))
                  'PASS
                  'FAIL))
             (info `((result . ,res) (expected . ,expect-val) ,@info)))
         (list status expect expr info)))
     (e ()
        (list (if (assq-ref info 'expect-error) 'PASS 'ERROR)
              expect
              expr
              (append `((exception . ,e) (trace . ,get-call-chain)) info))))))


(define (with-stubbed-environment thunk)
  ;; HERE BE DRAGONS
  ;; this is the hacky part of the library
  ;; if you have groups there will be calls to test-begin and test-end that does some housekeeping
  ;; we want to avoid that during our iterations
  (let ((original-test-begin test-begin)
        (original-test-end   test-end))
    (dynamic-wind
      (lambda ()
        (set! test-begin (constantly #t))
        (set! test-end   (constantly #t)))
      thunk
      (lambda ()
        (set! test-begin original-test-begin)
        (set! test-end original-test-end)))))

(define (run-iteration iteration tests seeds)
  (let* ((test-results '())
         (test-applier (lambda args
                         (set! test-results (cons (apply apply-test args) test-results)))))
    (parameterize ((current-test-applier test-applier))
      (with-stubbed-environment
       (lambda ()
         (apply tests seeds)))
      (reverse! test-results))))

(define (failed-tests? results)
  (any
   (lambda (result)
     (member (car result) '(FAIL ERROR)))
   results))

(define (finish/failures tests seed-names seeds iteration)
  (let* ((original-handler (current-test-handler))
         (decorating-handler (lambda (status expect expr info)
                               (cond
                                ((eq? status 'PASS)
                                 (original-handler status expect expr info))
                                (else
                                 (original-handler status expect expr (cons `(values (iteration . ,iteration)
                                                                                     (seeds . ,(zip seed-names seeds)))
                                                                            info)))))))
    (parameterize ((current-test-handler decorating-handler))
      (apply tests seeds))))

(define (finish/success seeds tests)
  (apply tests seeds))

(define (run-tests-with-generator tests seed-names generator)
  (let ((iteration-count (current-test-generative-iterations)))
    (let loop ((iteration 1) (seeds (generator)))
      (let ((results (run-iteration iteration tests seeds)))
        (if (failed-tests? results)
            (finish/failures tests seed-names seeds iteration)
            (if (>= iteration iteration-count)
                (finish/success seeds tests)
                (loop (add1 iteration) (generator))))))))

(define-syntax test-generative
  (syntax-rules ()
    ((_ ((?var ?gen) ...) ?body ...)
     (run-tests-with-generator
      (lambda (?var ...)
        ?body ...)
      (list (quote ?var) ...)
      (lambda ()
        (list (?gen) ...))))))

)
