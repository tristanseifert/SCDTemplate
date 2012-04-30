		org		$200000								; Offset for start of Word RAM

Header:
		dc.b	"MAIN"								; Header ID
		dc.w	(EntryPoint-Header), 0				; Entry point, reserved
		even

EntryPoint:
		lea		$FF0000, a0							; Start of scratch RAM
		moveq	#0, d0								; Clear d0
		moveq	#0, d1								; Clear d1
		move.b	#$F0, d1							; Loop over $100 bytes
		
@clearDMAQueue:
		move.l	d0, (a0)+
		dbf		d1, @clearDMAQueue
		
		lea		VBlank(pc), a1						; Load Address for VBL routine
		jsr     $368								; Make appropriate change in Interrupt Jump table
		
		move	#$2200, sr							; Re-enable ints.
		
		move.w	#$8134, $C00004						; Display on, DMA on, VBI on, 28 row, Genesis mode.
		move.w	#$8230, $C00004						; Plabe A address
		move.w	#$8328, $C00004						; Window plane address
		
		move.w	#$8407, $C00004						; Plane B address
		move.w	#$857C, $C00004						; Sprite table address
		move.w	#$8700, $C00004						; Backdrop is first colour in palette 0
	
		move.w	#$8B02, $C00004						; Per scanline scrolling
			
		move.w	#$8C81, $C00004						; No interlace, 40 tiles wide.
		move.w	#$8D3F, $C00004						; Location of HScroll
		move.w	#$8F02, $C00004						; Auto inc is 2
		
		move.w	#$9001, $C00004						; Plane size is 64x32
		
		move	#$2700, sr							; Disable interrupts.
		
		bsr.w	ClearFG								; Clear the FG plane
		bsr.w	ClearBG								; Clear the BG plane
		
		lea		MainMenu_art, a0					; Load from decompressed art
		moveq	#0, d0								; Start of VRAM
		move.w	#$69, d1							; Load 105 tiles
		bsr.w	Load_Tiles							; Write to VRAM
		
		lea		MainMenu_BG_Map, a1					; Load the BG maps to a1
		move.l	#$60000003, d0						; The BG maps
		moveq	#$27, d1							; $27 columns
		moveq	#$1B, d2							; $1B rows
		bsr.w	ShowVDPGraphics						; Write to the BG.
		
		lea		MainMenu_FG_Map, a1					; Load the BG maps to a1
		move.l	#$40000003, d0						; The BG maps
		moveq	#$27, d1							; $27 columns
		moveq	#$1B, d2							; $1B rows
		bsr.w	ShowVDPGraphics						; Write to the FG.
		
		move.w	#$8174, $C00004						; Enable the display.
		move.l	#0, $FF0200							; Clear status long		
		move	#$2200, sr							; Enable interrupters.
		
		lea		MainMenu_Pal, a0					; Fade in palette a0
		moveq	#0, d0								; Offset is 0
		bsr.w	Load_Palette						; Display palette.
		
		move.b	#5, $A1200E							; Play a PCM sample
		
MainLoop:
		stop	#$2500								; Wait for VBlank
		
		bra.w	MainLoop
		
;===================================================================================================

VBlank:
		movem.l	d0-a6, -(sp)						; Back up registers.
		bsr.w	ReadJoypads							; Read joypads.
		move.b	#1, $A12000							; Trigger Level 2 int on Sub CPU
		movem.l	(sp)+, d0-a6						; Restore registers.
		rte
	
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
		jsr 	CalcOffset
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
	
; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to map tile to VDP screen
;
; Address to the map goes in a5
; Number of columns to d0
; Number of rows to d1
; VDP address to d2.
; ---------------------------------------------------------------------------

Screen_Map:		
		lea		($C00000).l,a6					; Load VDP data port address to a6
		lea		$04(a6),a4						; Load VDP address port address to a4
		move.l	#$00800000,d4					; Prepare line add value

SM_Row:
		move.l	d2,(a4)							; Set VDP to VRam write mode
		move.w	d0,d3							; Reload number of columns

SM_Column:
		move.w	(a5)+,(a6)						; Dump map to VDP map slot
		dbf		d3,SM_Column					; Repeat til columns have dumped
		add.l	d4,d2							; Increase to next row on VRam
		dbf		d1,SM_Row						; Repeat til all rows have dumped
		rts										; Return To Sub
		
ShowVDPGraphics:			; XREF: SegaScreen; TitleScreen; SS_BGLoad
		lea	($C00000).l,a6
		move.l	#$800000,d4

loc_142C:
		move.l	d0,4(a6)
		move.w	d1,d3

loc_1432:
		move.w	(a1)+,(a6)
		dbf	d3,loc_1432
		add.l	d4,d0
		dbf	d2,loc_142C
		rts	
		
; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to map tile to VDP screen
;
; Address to the map goes in a5
; Number of columns to d0
; Number of rows to d1
; VDP address to d2.
; Value to add to everything to d6.
; ---------------------------------------------------------------------------

Screen_Map_WithAdd:		
		lea		($C00000).l, a6					; Load VDP data port address to a6
		lea		4(a6), a4						; Load VDP address port address to a4
		move.l	#$00800000, d4					; Prepare line add value

@SM_Row:
		move.l	d2, (a4)						; Set VDP to VRam write mode
		move.w	d0, d3							; Reload number of columns

@SM_Column:
		move.w	(a5)+, d5						; Dump map to d5
		add.w	d6, d5							; Add addition offset to the tile.
		move.w	d5, (a6)						; Write to VDP
		dbf		d3, @SM_Column					; Repeat til columns have dumped
		add.l	d4, d2							; Increase to next row on VRam
		dbf		d1, @SM_Row						; Repeat til all rows have dumped
		rts										; Return To Sub
		
ReadJoypads:
		lea	$FFFFFFF8, a0
		lea	$A10003, a1
		jsr	Joypad_Read
		addq.w	#2,a1

Joypad_Read:
		move.b	#0,(a1)
		nop
		nop
		move.b	(a1),d0
		lsl.b	#2,d0
		andi.b	#$C0,d0
		move.b	#$40,(a1) ; '@'
		nop
		nop
		move.b	(a1),d1
		andi.b	#$3F,d1	; '?'
		or.b	d1,d0
		not.b	d0
		move.b	(a0),d1
		eor.b	d0,d1
		move.b	d0,(a0)+
		and.b	d0,d1
		move.b	d1,(a0)+
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

        include		"common/loader.asm"
        even
        
PalSys_FadeTick:
		rts
        
MainMenu_Art:
		incbin		"menu/art.bin"
		even
		
MainMenu_Pal:
		incbin		"menu/pal.bin"
		even
		
MainMenu_BG_Map:
		incbin		"menu/bg_map.bin"
		even
		
MainMenu_FG_Map:
		incbin		"menu/fg_map.bin"
		even