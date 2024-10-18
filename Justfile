set windows-shell := ["C:/Program Files/Git/bin/bash.exe", "-c"]


test-parse:
  moon run src/bin --debug -- --end-stage parse ./test/test_src/ack.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/adder.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/adder2.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/cls-bug.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/cls-bug2.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/cls-rec.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/cls-reg-bug.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/even-odd.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/fib.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/float.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/funcomp.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/gcd.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/id.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/inprod-loop.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/inprod-rec.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/inprod.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/join-reg.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/join-reg2.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/join-stack.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/join-stack2.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/join-stack3.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/matmul-flat.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/matmul.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/non-tail-if.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/non-tail-if2.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/print.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/shuffle.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/spill.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/spill2.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/spill3.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/sum-tail.mbt
  moon run src/bin --debug -- --end-stage parse ./test/test_src/sum.mbt


test-typecheck:
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/arith.mbt
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/global_let.mbt
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/ident.mbt
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/nested_fns.mbt
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/nested_fns_no_type_annotation.mbt
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/numbers.mbt
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/simple.mbt
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/very_deep.mbt
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/untyped_inner_fn.mbt
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/landins_knot.mbt
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_fn_apply_wrong_return.mbt    ; [ $? -ne 0 ]
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_fn_decl_wrong_param.mbt      ; [ $? -ne 0 ]
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_fn_decl_wrong_return.mbt     ; [ $? -ne 0 ]
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_int_plus_float.mbt           ; [ $? -ne 0 ]
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_self.mbt                     ; [ $? -ne 0 ]
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_untyped_unification_fail.mbt ; [ $? -ne 0 ]


test-knf:
  rm -rf temp
  mkdir temp
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/adder.mbt 2>/dev/null > ./temp/adder.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/adder2.mbt 2>/dev/null > ./temp/adder2.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/cls-bug.mbt 2>/dev/null > ./temp/cls-bug.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/cls-bug2.mbt 2>/dev/null > ./temp/cls-bug2.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/cls-rec.mbt 2>/dev/null > ./temp/cls-rec.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/cls-reg-bug.mbt 2>/dev/null > ./temp/cls-reg-bug.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/fib.mbt 2>/dev/null > ./temp/fib.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/float.mbt 2>/dev/null > ./temp/float.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/funcomp.mbt 2>/dev/null > ./temp/funcomp.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/gcd.mbt 2>/dev/null > ./temp/gcd.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/id.mbt 2>/dev/null > ./temp/id.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/inprod-loop.mbt 2>/dev/null > ./temp/inprod-loop.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/inprod-rec.mbt 2>/dev/null > ./temp/inprod-rec.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/inprod.mbt 2>/dev/null > ./temp/inprod.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/join-reg.mbt 2>/dev/null > ./temp/join-reg.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/join-reg2.mbt 2>/dev/null > ./temp/join-reg2.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/join-stack.mbt 2>/dev/null > ./temp/join-stack.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/join-stack2.mbt 2>/dev/null > ./temp/join-stack2.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/join-stack3.mbt 2>/dev/null > ./temp/join-stack3.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/matmul-flat.mbt 2>/dev/null > ./temp/matmul-flat.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/matmul.mbt 2>/dev/null > ./temp/matmul.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/non-tail-if.mbt 2>/dev/null > ./temp/non-tail-if.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/non-tail-if2.mbt 2>/dev/null > ./temp/non-tail-if2.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/print.mbt 2>/dev/null > ./temp/print.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/shuffle.mbt 2>/dev/null > ./temp/shuffle.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/spill.mbt 2>/dev/null > ./temp/spill.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/spill2.mbt 2>/dev/null > ./temp/spill2.out
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/spill3.mbt 2>/dev/null > ./temp/spill3.out
  diff -Z test/test_src/adder.ans temp/adder.out
  diff -Z test/test_src/adder2.ans temp/adder2.out
  diff -Z test/test_src/cls-bug.ans temp/cls-bug.out
  diff -Z test/test_src/cls-bug2.ans temp/cls-bug2.out
  diff -Z test/test_src/cls-rec.ans temp/cls-rec.out
  diff -Z test/test_src/cls-reg-bug.ans temp/cls-reg-bug.out
  diff -Z test/test_src/fib.ans temp/fib.out
  diff -Z test/test_src/float.ans temp/float.out
  diff -Z test/test_src/funcomp.ans temp/funcomp.out
  diff -Z test/test_src/gcd.ans temp/gcd.out
  diff -Z test/test_src/id.ans temp/id.out
  diff -Z test/test_src/inprod-loop.ans temp/inprod-loop.out
  diff -Z test/test_src/inprod-rec.ans temp/inprod-rec.out
  diff -Z test/test_src/inprod.ans temp/inprod.out
  diff -Z test/test_src/join-reg.ans temp/join-reg.out
  diff -Z test/test_src/join-reg2.ans temp/join-reg2.out
  diff -Z test/test_src/join-stack.ans temp/join-stack.out
  diff -Z test/test_src/join-stack2.ans temp/join-stack2.out
  diff -Z test/test_src/join-stack3.ans temp/join-stack3.out
  diff -Z test/test_src/matmul-flat.ans temp/matmul-flat.out
  diff -Z test/test_src/matmul.ans temp/matmul.out
  diff -Z test/test_src/non-tail-if.ans temp/non-tail-if.out
  diff -Z test/test_src/non-tail-if2.ans temp/non-tail-if2.out
  diff -Z test/test_src/print.ans temp/print.out
  diff -Z test/test_src/shuffle.ans temp/shuffle.out
  diff -Z test/test_src/spill.ans temp/spill.out
  diff -Z test/test_src/spill2.ans temp/spill2.out
  diff -Z test/test_src/spill3.ans temp/spill3.out


test-closure:
  rm -rf temp
  mkdir temp
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/adder.mbt 2>/dev/null > ./temp/adder.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/adder2.mbt 2>/dev/null > ./temp/adder2.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/cls-bug.mbt 2>/dev/null > ./temp/cls-bug.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/cls-bug2.mbt 2>/dev/null > ./temp/cls-bug2.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/cls-rec.mbt 2>/dev/null > ./temp/cls-rec.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/cls-reg-bug.mbt 2>/dev/null > ./temp/cls-reg-bug.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/fib.mbt 2>/dev/null > ./temp/fib.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/float.mbt 2>/dev/null > ./temp/float.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/funcomp.mbt 2>/dev/null > ./temp/funcomp.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/gcd.mbt 2>/dev/null > ./temp/gcd.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/id.mbt 2>/dev/null > ./temp/id.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/inprod-loop.mbt 2>/dev/null > ./temp/inprod-loop.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/inprod-rec.mbt 2>/dev/null > ./temp/inprod-rec.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/inprod.mbt 2>/dev/null > ./temp/inprod.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/join-reg.mbt 2>/dev/null > ./temp/join-reg.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/join-reg2.mbt 2>/dev/null > ./temp/join-reg2.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/join-stack.mbt 2>/dev/null > ./temp/join-stack.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/join-stack2.mbt 2>/dev/null > ./temp/join-stack2.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/join-stack3.mbt 2>/dev/null > ./temp/join-stack3.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/matmul-flat.mbt 2>/dev/null > ./temp/matmul-flat.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/matmul.mbt 2>/dev/null > ./temp/matmul.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/non-tail-if.mbt 2>/dev/null > ./temp/non-tail-if.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/non-tail-if2.mbt 2>/dev/null > ./temp/non-tail-if2.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/print.mbt 2>/dev/null > ./temp/print.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/shuffle.mbt 2>/dev/null > ./temp/shuffle.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/spill.mbt 2>/dev/null > ./temp/spill.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/spill2.mbt 2>/dev/null > ./temp/spill2.out
  moon run src/bin --debug -- --closure-interpreter ./test/test_src/spill3.mbt 2>/dev/null > ./temp/spill3.out
  diff -Z test/test_src/adder.ans temp/adder.out
  diff -Z test/test_src/adder2.ans temp/adder2.out
  diff -Z test/test_src/cls-bug.ans temp/cls-bug.out
  diff -Z test/test_src/cls-bug2.ans temp/cls-bug2.out
  diff -Z test/test_src/cls-rec.ans temp/cls-rec.out
  diff -Z test/test_src/cls-reg-bug.ans temp/cls-reg-bug.out
  diff -Z test/test_src/fib.ans temp/fib.out
  diff -Z test/test_src/float.ans temp/float.out
  diff -Z test/test_src/funcomp.ans temp/funcomp.out
  diff -Z test/test_src/gcd.ans temp/gcd.out
  diff -Z test/test_src/id.ans temp/id.out
  diff -Z test/test_src/inprod-loop.ans temp/inprod-loop.out
  diff -Z test/test_src/inprod-rec.ans temp/inprod-rec.out
  diff -Z test/test_src/inprod.ans temp/inprod.out
  diff -Z test/test_src/join-reg.ans temp/join-reg.out
  diff -Z test/test_src/join-reg2.ans temp/join-reg2.out
  diff -Z test/test_src/join-stack.ans temp/join-stack.out
  diff -Z test/test_src/join-stack2.ans temp/join-stack2.out
  diff -Z test/test_src/join-stack3.ans temp/join-stack3.out
  diff -Z test/test_src/matmul-flat.ans temp/matmul-flat.out
  diff -Z test/test_src/matmul.ans temp/matmul.out
  diff -Z test/test_src/non-tail-if.ans temp/non-tail-if.out
  diff -Z test/test_src/non-tail-if2.ans temp/non-tail-if2.out
  diff -Z test/test_src/print.ans temp/print.out
  diff -Z test/test_src/shuffle.ans temp/shuffle.out
  diff -Z test/test_src/spill.ans temp/spill.out
  diff -Z test/test_src/spill2.ans temp/spill2.out
  diff -Z test/test_src/spill3.ans temp/spill3.out


test-ssa:
  moon run src/bin --debug -- --emit-ssa ./test/test_src/adder.mbt


submit:
  git archive -o submit.zip HEAD
