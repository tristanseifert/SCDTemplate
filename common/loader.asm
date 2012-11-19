LoadModule:
		move	#$2700, sr										; Disable interrupts.
		move.w  #$000, $A11200				       				; Assert Z80 reset.
		
@waitZ80:
		btst	#0, $A11200										; Has the Z80 reset yet?
		bne.s	@waitZ80										; Wait for the Z80 to be ready.

		moveq	#0, d7											; Clears d7
		lea		$FF0200, a0										; Location where loader is loaded to in RAM
		lea		LoaderModule(pc), a1							; Location of loader. (PC relative)
		move.w	#((LoaderEnd-LoaderModule)/2), d7				; Copy 256 words
		subq.w	#1, d7											; Subtract one to offset for loop
		
@copyDriverLoop:
		move.w	(a1)+, (a0)+									; Copy a word of the loader.
		dbf		d7, @copyDriverLoop								; Loop until the driver has loaded.

		jmp		$FF0200											; Jump to the loader.

LoaderModule:
		incbin	"common/loadermodule.bin"
		even
LoaderEnd:		