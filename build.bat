del -f ANTIPATHY.ISO

REM Assemble the module loader
bin/asm68k /o op+ /o os+ /o ow+ /o oz+ /o oaq+ /o osq+ /o omq+ /p /o ae- common/loadermodule.asm, common/loadermodule.bin, , common/loadermodule.lst

REM Assemble modules (add more assembler commands below)
bin/asm68k /o op+ /o os+ /o ow+ /o oz+ /o oaq+ /o osq+ /o omq+ /p /o ae- menu/menu.asm, MENU.BIN, , menu/menu.lst

perl scdmake_win
pause