		org	$FF0200									; Run out of RAM
		; The ID of the module to load is expected in $FF01FE
		
EntryPoint:
		lea		VBlank(pc), a1						; Load Address for VBL routine
		jsr     $368								; Make appropriate change in Interrupt Jump table


;		move.w	#$8144, $C00004						; Turn off VINTs
		ori.b	#2, $A12003							; Give SUB CPU control of WordRAM
		
		move.w	$FF01FE, $A12010					; Load Menu screen.
		move.b	#1, $A1200E							; Load a program from the disc.
	
		moveq	#$7F, d0							; Loop 8 times = 40 nops
	
@loop:
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		dbf		d0, @loop							; Keep looping.
		
@waitForSubCPU3:
		nop
		cmp.b	#'D', $A1200F						; Wait for Sub CPU to service our command
		bne.s	@waitForSubCPU3						; Keep looping until it finishes
		
		move.b	#0, $A1200E							; Clear program.
		move.w	#0, $A12010							; Clear parameter.
		
		lea		$200000, a0							; Load Word RAM address to a0.
		
		cmp.l	#"MAIN", (a0)						; Is the loaded file a Main CPU executable?
		bne.s	FileInvalid
		
		cmp.w	#0, 6(a0)							; Check if we've got a RAM offset
		beq.w	@runFromWordRAM						; If not, branch.
		
		moveq	#0, d0								; Clear d0.
		moveq	#0, d1								; Clear d1.
		move.l	$FF0000, a6							; Start of RAM to a6
		move.w	6(a0), d0							; Get our RAM offset to d0
		bclr	#0, d0								; Clear LSB to even it out.
		add.l	d0, a6								; Add to the pointer.
		lea		$20000A, a5							; Word RAM offset to a5.
		move.w	8(a0), d1							; Get the length to copy.
		subq.w	#1, d1								; Subtract 1 to offset loop

@copyToMainRAM:
		move.b	(a5)+, (a6)+						; Copy one byte of the data.
		dbf		d1, @copyToMainRAM					; Loop until it's all copied.
		
		move.l	$FF0000, a6							; Start of RAM to a6
		move.w	6(a0), d0							; Get our RAM offset to d0
		bclr	#0, d0								; Clear LSB to even it out.
		add.l	d0, a6								; Add to the pointer.
		
		jmp		(a6)								; Jump to the code.

@runFromWordRAM:
		lea		$200000, a6							; Load Word RAM address to a0.
		moveq	#0, d0								; Clear d0.
		move.w	4(a6), d0							; Copy offset of entry point to d0.
		add.l	d0, a6								; Add to pointer.

		jmp		$200008								; Jump to program.
	
FileInvalid:
		bra.w	FileInvalid							; INFINITE LOOP!1!!!!!!
		
VBlank:
		rte