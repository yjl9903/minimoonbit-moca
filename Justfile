set windows-shell := ["powershell.exe", "-c"]

test-typing:
  moon run src/bin --debug -- --end-stage typecheck ./test/test_typing/arith.mbt

test-knf:
  moon run src/bin --debug -- --start-stage knf --end-stage knf ./test/test_knf/helloworld.json
