set windows-shell := ["nu.exe", "-c"]

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
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_fn_apply_wrong_return.mbt || exit 1
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_fn_decl_wrong_param.mbt || exit 1
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_fn_decl_wrong_return.mbt || exit 1
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_int_plus_float.mbt || exit 1
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_self.mbt || exit 1
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_untyped_unification_fail.mbt || exit 1

test-knf:
  moon run src/bin --debug -- --knf-interpreter ./test/test_knf/inprod.mbt

test-closure:
  moon run src/bin --debug -- --knf-interpreter ./test/test_knf/inprod.mbt  

submit:
  git archive -o submit.zip HEAD
