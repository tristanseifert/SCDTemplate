#!/bin/bash

# Assemble the loader (used to load new modules)
/Applications/Wine.app/Contents/MacOS/startwine bin/asm68k /o op+ /o os+ /o ow+ /o oz+ /o oaq+ /o osq+ /o omq+ /p /o ae- common/loadermodule.asm, common/loadermodule.bin, , common/loadermodule.lst

# Put more commands below to compile each of your modules
/Applications/Wine.app/Contents/MacOS/startwine bin/asm68k /o op+ /o os+ /o ow+ /o oz+ /o oaq+ /o osq+ /o omq+ /p /o ae- menu/menu.asm, MENU.BIN, , menu/menu.lst

# Assemble the ISO's
./scdmake