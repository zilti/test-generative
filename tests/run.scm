(use data-generators test test-generative)

(test-group "group around"
   (test-group "probably failing"

       (test-generative ((number (gen-fixnum))
                         (string (gen-string-of (gen-char #\a #\z))))
           (test-assert "failing1" (> (string-length string) 30))
           (test-assert ((constantly #t)))))

       (test-group "all passing"
           (test-generative ((number (gen-fixnum)))
               (test-assert "passing1" (number? number)))))


(test-group "other"
            (test "foo" #t #t)
            (test "bar" #t #t))


(test-exit)
