set windows-shell := ["powershell.exe", "-c"]

test-typing:
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
  # moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_fn_apply_wrong_param.mbt
  # moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_fn_apply_wrong_return.mbt
  # moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_fn_decl_wrong_param.mbt
  # moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_fn_decl_wrong_return.mbt
  # moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_int_plus_float.mbt
  # moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_self.mbt
  # moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/_neg_untyped_unification_fail.mbt

test-knf:
  moon run src/bin --debug -- --knf-interpreter ./test/test_src/adder.mbt

submit:
  git archive -o submit.zip HEAD
