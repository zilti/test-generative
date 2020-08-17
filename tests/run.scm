(import chicken.random)
(import test)
(import test-generative)

(test-generative ((the-number (lambda () (add1 (pseudo-random-integer 100)))))
   (test-assert "it's numeric"  (number? the-number))
   (test-assert "it's positive" (positive? the-number))
;   (test-assert "it's smaller that 50" (< the-number 50))
   )


(test-exit)
