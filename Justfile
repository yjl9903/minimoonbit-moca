set windows-shell := ["powershell.exe", "-c"]

test-knf:
  moon run src/bin --debug -- --start-stage knf --end-stage knf ./test/knf/helloworld.json
