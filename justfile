setup:
    @git submodule update --init --recursive

run: setup
    @odin run src -collection:ui=ui

build: setup
    @odin build src -out:ui-demo.exe -collection:ui=ui

check: setup
    @odin check src -collection:ui=ui

screenshot view="0" scale="1" ssaa="2" out="screenshot.png": setup
    @odin run src -collection:ui=ui -- --view {{view}} --scale {{scale}} --ssaa {{ssaa}} --screenshot {{out}}
