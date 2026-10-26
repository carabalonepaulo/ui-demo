setup:
    @git clone https://github.com/carabalonepaulo/ui.git ui

run:
    @odin run src -collection:ui=ui

build:
    @odin build src -out:ui-demo.exe -collection:ui=ui

check:
    @odin check src -collection:ui=ui

screenshot view="0" scale="1" ssaa="2" out="screenshot.png":
    @odin run src -collection:ui=ui -- --view {{view}} --scale {{scale}} --ssaa {{ssaa}} --screenshot {{out}}
