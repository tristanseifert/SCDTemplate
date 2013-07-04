		org		$FF0584								; Area where the SCD BIOS will load us to, after security code.
		
EntryPoint:
		lea		VInt(pc), a1						; Load Address for VBL routine
		jsr     $368								; Make appropriate change in Interrupt Jump table

		move.b	#$40, $A10009						; Set up I/O Port
	
		move.b	#0, $A1200E							; Clear out handshake.
		
@waitForSubCPU:
		nop
		nop
		cmp.b	#'S', $A1200F						; Has the Sub CPU initialized yet?
		bne.s	@waitForSubCPU						; Keep looping until it finished.
		
		move.b	#'M', $A1200E						; Tell the Sub CPU we're alive.
		
@waitForSubCPU1:
		nop
		nop
		cmp.b	#'D', $A1200F						; Has the Sub CPU returned our acknowledgement?
		bne.s	@waitForSubCPU1						; Keep looping until it finished.
		
		bsr.w	ClearVRAM							; Clear the VRAM.
		
		move.w	#$8144, $C00004						; Turn off VINTs
		ori.b	#2, $A12003							; Give SUB CPU control of WordRAM
		
		move.l 	#$C0000000, $C00004					; First line, 0th colour
		move.w 	#$0E00, $C00000 					; Blue

		move.w	#1, $A12010							; Load Menu screen.
		move.b	#1, $A1200E							; Load a program from the disc.
	
		moveq	#$7F, d0							; Loop 8 times = 40 nops
	
@loop:
		nop
		nop
		nop
		nop
		nop
		dbf		d0, @loop							; Keep looping.
		
		move.l 	#$C0000000, $C00004					; First line, 0th colour
		move.w 	#$00E0, $C00000 					; Green
		
@waitForSubCPU3:
		nop
		cmp.b	#'D', $A1200F						; Wait for Sub CPU to service our command
		bne.s	@waitForSubCPU3						; Keep looping until it finishes
		
		move.b	#0, $A1200E							; Clear program.
		move.w	#0, $A12010							; Clear parameter.
		
		lea		$200000, a0							; Load Word RAM address to a0.
		
		cmp.l	#"MAIN", (a0)						; Is the loaded file a Main CPU executable?
		bne.s	FileInvalid
			
		lea		$200000, a6							; Load Word RAM address to a0.
		moveq	#0, d0								; Clear d0.
		move.w	4(a6), d0							; Copy offset of entry point to d0.
		add.l	d0, a6								; Add to pointer.

		jmp		$200008
		;jmp		(a0)								; Jump into the code.
		
; We should NEVER drop down here. It's intended as a method to prevent death from ocurring when
; the game code returns (rts's) too much
	
DeathLoop:
		bra.s	DeathLoop							; Keep looping.

FileInvalid:
		move.l 	#$C0000000, $C00004					; First line, 0th colour
		move.w 	#$000E, $C00000 					; Set BG palette to red
		bra.s	DeathLoop

;---------------------------------------------------
; Various Interrupts and Subroutines
;---------------------------------------------------
VInt:	
		move.b	#1, $A12000							; Trigger Level 2 int on Sub CPU
		rte											; Return to currently running programme.

ClearVRAM:
		lea		$C00000, a1
		move.l	#$40000000, $C00004
		moveq	#0,d1
		move.w	#$7FF, d0

ClearVRAM_Loop:
		move.l	d1, (a1)
		move.l	d1, (a1)
		move.l	d1, (a1)
		move.l	d1, (a1)
		move.l	d1, (a1)
		move.l	d1, (a1)
		move.l	d1, (a1)
		move.l	d1, (a1)
		dbf		d0, ClearVRAM_Loop
		rts