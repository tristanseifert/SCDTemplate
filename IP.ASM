		org		$FF0584								; Area where the SCD BIOS will load us to, after security code.
		
EntryPoint:
		lea		Vint(pc), a1						; Load Address for VBL routine
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
		
		lea		(Font, PC), a0						; Load from RAM
		moveq	#0, d0								; Start of VRAM
		move.w	#$80, d1							; Load 64 tiles
		bsr.w	Load_Tiles							; Write to VRAM
		
		lea		(Palette, pc), a0					; Load Palette
		moveq	#0, d0
		bsr.w	Load_Palette
		
		lea		(ASCII_LoadInitial, pc), a1			; Load loading text.
		move.l	#$40000003, d5						; Write to the the FG maps.
		bsr.w	WriteASCIIToScreen					; Write some ASCII to screen.

		move.w	#$8144, $C00004						; Turn off VINTs
		ori.b	#2, $A12003							; Give SUB CPU control of WordRAM
		
		move.w	#1, $A12010							; Load Menu screen.
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
		
		lea		(ASCII_VerifyInitial, pc), a1		; Load verification text.
		move.l	#$41000003, d5						; Write to the the FG maps.
		bsr.w	WriteASCIIToScreen					; Write some ASCII to screen.
		
		lea		$200000, a0							; Load Word RAM address to a0.
		
		cmp.l	#"MAIN", (a0)						; Is the loaded file a Main CPU executable?
		bne.s	FileInvalid
		
		lea		(ASCII_RunInitial, pc), a1			; Load verification text.
		move.l	#$42000003, d5						; Write to the the FG maps.
		bsr.w	WriteASCIIToScreen					; Write some ASCII to screen.
		
		lea		$200000, a6							; Load Word RAM address to a0.
		moveq	#0, d0								; Clear d0.
		move.w	4(a6), d0							; Copy offset of entry point to d0.
		add.l	d0, a6								; Add to pointer.

		jmp		$200008
		;jmp		(a0)								; Jump into the code.
		
; We should NEVER drop down here. It's intended as a method to prevent death from ocurring when
; the game code returns (rts's) too much
	
DeathLoop:
		nop
		bra.s	DeathLoop							; Keep looping.

FileInvalid:
		lea		(ASCII_NotValid, pc), a1		; Load verification text.
		move.l	#$42000003, d5						; Write to the the FG maps.
		bsr.w	WriteASCIIToScreen					; Write some ASCII to screen.
		bra.s	DeathLoop
;---------------------------------------------------
; Various Interrupts and Subroutines
;---------------------------------------------------

Vint:	
		move.b	#1, $A12000							; Trigger Level 2 int on Sub CPU
		rte											; Return to currently running programme.
	
; ===========================================================================
; DisplayByteValueOnVDP
;
; This routine will write a byte value to the VDP.
; To use it, put these value into data registers:
; d1 - the byte to display.
; d2 - the VDP address for the first digit.
; ---------------------------------------------------------------------------

DisplayByteValueOnVDP:
		lea		($C00000).l, a0					; Load VDP data port to a0.
		move.l	d2, 4(a0)						; Write what part of the mappings we want to write to.
		
		moveq	#0, d0							; Clear d0
		move.b	d1, d0							; Move the selected sound ID to d0.
		lsr.b	#4, d0							; Shift the significant nybble to the left.
		
		cmp.b	#$9, d0							; Is d0 less than $A?
		ble.s	@noCompensateNeeded1			; If so, branch.
		
		add.b	#$7, d0							; Add to compensate.
		
@noCompensateNeeded1:
		add.w	#$0010, d0						; Add the tile and palette offset to d0.
		move.w	d0, (a0)						; Write the previously computed number to the VDP.

		add.l	#$00020000, d2					; Add to the initial address.
		move.l	d2, 4(a0)						; Write what part of the mappings we want to write to.
		
		moveq	#0, d0							; Clear d0
		move.b	d1, d0							; Move the selected sound ID to d0.
		andi.b	#$F,d0							; AND away the high nybble.
		
		cmp.b	#$9, d0							; Is d0 less than $A?
		ble.s	@noCompensateNeeded2			; If so, branch.
		
		add.b	#$7, d0							; Add to compensate.
		
@noCompensateNeeded2:
		add.w	#$0010, d0						; Add the tile and palette offset to d0.
		move.w	d0, (a0)						; Write the previously computed number to the VDP.
	
		rts
		
	
ClearFG:
		move.l	#$40000003, d5
        bra.s	DoClear

ClearBG:
		move.l	#$60000003, d5
		
DoClear:
		move.l	d5, $C00004
		moveq	#0, d0
		moveq	#0, d1
		move.w	#$375, d0

@loop:
		move.l	d1, $C00000
		dbf		d0, @loop
		rts
		
WriteASCIIToScreen:	
_Tab		equ	$09									; Byte to indicate a tab.
_NewLine	equ	$0A									; Byte to indicate a newline. 
_Space		equ	$0D									; Byte to indicate a space.
_End		equ	$7D									; Byte to indicate end of text.
VRAM_ASCII	equ	$0									; The offset to add to the VDP tile
		
LoadASCII:
		move.l	d5,($C00004).l

LoadText_Loop:
LoadText_Loop_NoDelay:
		moveq	#0,d1
		move.b	(a1)+,d1
		move.b	d1,d2

		cmp.b	#_Tab,d2
		beq	LoadASCII_AddTab
		cmp.b	#_Space,d2
		beq	LoadASCII_AddSpace
		cmp.b	#_End,d2
		bne	LoadASCII_Print

		rts
; ---------------------------------------------------------------------------
VRAM_ASCII	equ	$0

LoadASCII_Print:
		cmp.b	#_NewLine,d2
		beq		LoadASCII_NewLine

		move.b	d2,d1
		add.w	#VRAM_ASCII,d1
		subi.w	#$0020, d1
		move.w	d1,($C00000)
		
LoadASCII_Fix:
		bra		LoadText_Loop

LoadASCII_NewLine:
		add.l	#$800000,d5
		bra		LoadASCII
		
LoadASCII_AddSpace:
		cmp.b	#_Tab,d2
		beq		LoadASCII_Fix

		add.l	#$800000,d5
		bra		LoadASCII

LoadASCII_AddTab:
		add.l	#$100000,d5
		bra		LoadASCII

LoadASCII_Test2:
		cmp.b	#_NewLine,d2
		beq		LoadASCII_Fix
		rts
	
Load_Palette:
;Loads a palette of 16 entries
; a0 = data source
; d0 = palette number
		move.l 	d1, -(a7)
		moveq 	#0, d1
		move.w 	#$C000, d1
		lsl.w 	#5, d0
		add.w	 d0, d1
		swap 	d1
		move.l 	d1, $C00004
		lea 	$C00000, a1
		rept 	16
		move.w (a0)+, (a1)
		endr
		move.l (a7)+, d1
		rts
	
Load_Tiles:
;Loads tiles, a0 = in
;d0 = destination in vram1
;d1 = amount of tiles
;Breaks d0, d1, d2, d3, a0, a1
		bsr.w 	CalcOffset
		lea 	$C00000, a1
@LoadLoop:
		moveq	#7, d3

@loop2:
		move.l (a0)+, (a1)
		dbf		d3, @loop2
		
		dbf 	d1, @LoadLoop
		rts
	
CalcOffset:
;Calculate VDP command shits from an adress in d0.... breaks.... nothing!
;Optimization time!!!
		movem.l d0-d3, -(a7)
		moveq 	#0, d2
		moveq 	#0, d3
		move.w 	#$4000, d2
		move.w 	d0, d3
		and.w 	#$3FFF, d3
		add.w 	d3, d2
		and.w 	#$C000, d0
		lsr.w 	#8, d0
		lsr.w 	#6, d0 
		swap 	d2
		or.l 	d0, d2
		move.l 	d2, $C00004
		movem.l (a7)+, d0-d3
		rts
		even
		
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
	
ASCII_LoadInitial:
		dc.b	" Loading Initial Main Program...", _End
		even
		
ASCII_VerifyInitial:
		dc.b	" Verifying Initial Main Program...", _End
		even
		
ASCII_RunInitial:
		dc.b	" Running Initial Main Program...", _End
		even
		
ASCII_NotValid:
		dc.b	" Initial Program not valid.", _End
		even	
		
		
Font:	incbin	"modules/Font.bin"
		even
		
Palette:	incbin	"modules/UI.pal"
		even