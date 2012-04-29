		include		cdbios.inc
		include		SCDMAKE.INC

		org	$6000									; Start of Program RAM after BIOS and header

StartSubCPU:	
	;; 11 character string, start with MAIN or ends with SYS, SUB, or DAT
	;; null terminated string
	dc.b    'MAIN       ',$00
	;; version
	dc.w    $0000
	;; type
	dc.w	$0000
	;; next header, zero if no more headers
	dc.l    $00000000
	;; length of packet including header
	dc.l    (EndSubCPU-StartSubCPU)
	;; offset from beginning of header to entry point data
	dc.l    (StartUserCallData-StartSubCPU)
	;; work RAM size
	dc.l    $00000000 ; 32 bytes (AKA $20)
StartUserCallData:	
	;; entry point as offset
	dc.w    (SPInit-StartUserCallData)				; Initialization routine
	dc.w    (SPMain-StartUserCallData)				; Main routine
	dc.w    (SPInt-StartUserCallData)				; Level 2 interrupt
	dc.w    (SPInit-StartUserCallData)				; User-definable call
	dc.w	$0000									; Is at $6028
	
SPInit:		
		move.w	#$8400, d1							; Set max volume for master.
		BIOS_FDRSET									; Actually set the master volume.
		move.w	#$0400, d1							; Set max volume.
		BIOS_FDRSET									; Actually set the volume.
		
		BIOS_MSCSTOP								; Stop all CD playback.
		lea		DriveInitParam(pc), a0				; Load drive initialization pramaters
		BIOS_DRVINIT								; Read the ToC from the disc.
		BIOS_CDCSTOP								; Stop any data read that might be going on
		
		rts
	
SPMain:		
		move.b	#'S', $FF800F						; Tell the Main CPU we're alive
		
@waitForMainCPU:
		cmp.b	#'M', $FF800E						; Has the Main CPU acknowledged our existence?
		bne.s	@waitForMainCPU						; If not, keep looping.
		
		move.b	#'D', $FF800F						; Clear busy flag.
	
;---------------------------------------------------------------------------------------------------
; We drop into the main loop after handshaking.
	
MainLoop:
		move.b	#'D', $FF800F						; Clear busy flag.
		nop
		nop
		
		cmp.b	#0, $FF800E							; Do we have a pending command?
		beq.s	MainLoop							; If not, keep checking.
		
		move.b	#'B', $FF800F						; Set busy flag.
		
		moveq	#0, d0								; Clear d0.
		move.b	$FF800E, d0							; Copy command to d0.
		
		cmp.b	#1, d0								; Are we executing 'LoadProgram?'
		beq.s	LoadProgram							; If so, branch.
		cmp.b	#2, d0								; Are we executing 'PlayCDDAR?'
		beq.w	PlayCDDAR							; If so, branch.
		cmp.b	#3, d0								; Are we executing 'CDDAPause?'
		beq.w	CDDAPause							; If so, branch.
		cmp.b	#4, d0								; Are we executing 'CDDAResume?'
		beq.w	CDDAResume							; If so, branch.

		bra.s	MainLoop							; Keep looping.
		
;---------------------------------------------------------------------------------------------------		
; Packet Format:
; sector to read, number of sectors to read, Pointer to dest. buffer, header buffer, terminator?
;
; This function is what the module loader uses to load a new file from the disc to the Word RAM.
; Place the module ID (word) into $A12010 and call this function as described above with the functon number 1.
; Note that any files must be inside the bounds of the "FileLocationTable" LUT.

LoadProgram:		
		BIOS_MSCSTOP
		andi.b	#$FA, $FF8003						; Set 2 Mbit mode
		nop
		ori.b	#2, $FF8003							; Make sure the Word RAM is returned to us.
		
		moveq	#0, d0								; Clear d0.
		move.w	$FF8010, d0							; Copy command to d0.
		subq.l	#1, d0								; Subtract to turn list into 0-based
		lsl.l	#3, d0								; Multiply by two
		lea		FileLocationTable(pc, d0), a0		; Jump to the function.
		
		move.l	(a0), d0							; Copy start sector to d0.
		move.l	4(a0), d1							; Copy size in sectors to d1.

		lea		Packet(pc), a5						; Load the packet address to a5.
		move.l	d0, (a5)							; Load the start sector to the packet.
		move.l	d1, 4(a5)							; Load the size of file in sectors to the packet.
		move.l	#$80000, 8(a5)						; Load the destination (Word RAM) to the packet.
		
		jsr		ReadCD(pc)							; Read from the disc.
		
		ori.b	#1, $FF8003							; Return Word RAM to owner
		
@waitForWRAM:
		nop
		btst	#0, $FF8003							; Has the RAM been returned yet?
		beq.s	@waitForWRAM						; If not, check again.
		
		move.b	#'D', $FF800F						; Clear busy flag.
		moveq	#$1F, d0							; Loop a little for the Main CPU to ack the data
@loop:
		nop
		nop
		nop
		nop
		nop
		dbf		d0, @loop		
		bra.w	MainLoop							; Return to main loop.

FileLocationTable:
		dc.l	FILE_MENU_BIN_START_SECTOR, FILE_MENU_BIN_SIZE_SECTORS
		even

; This routine plays the track in $A12010. Call it with function numer 2 as descrbed above.

PlayCDDAR:
		BIOS_CDCSTOP								; Stop any data read that might be going on
		BIOS_MSCSTOP								; Stop currently playing track.

		lea		CDDA_TrackTable(pc), a0				; Load track table to a0.
		move.w	$FF8010, (a0)						; Copy the track number into the table.
		BIOS_MSCPLAYR								; Keep looping the track.
		
		move.w	#4, d1
		BIOS_LEDSET
		
		move.b	#'D', $FF800F						; Clear busy flag.
		moveq	#$1F, d0
@loop:
		nop
		nop
		nop
		nop
		nop
		dbf		d0, @loop		
		bra.w	MainLoop							; Return to main loop.

; ===============================================================================	
CDDAPause:
		BIOS_MSCPAUSEON								; Call into BIOS
		bra.w	ReturnToMain						; Return to main loop.
	
; ===============================================================================	
CDDAResume:
		BIOS_MSCPAUSEOFF							; Call into BIOS
		bra.w	ReturnToMain						; Return to main loop.

; Dummy function
ReturnToMain:
		move.b	#'D', $FF800F						; Clear busy flag.
		bra.w	MainLoop							; Return to main loop.
		
CDDA_TrackTable:
		dc.w	$0002
		even

; Start reading ToC at first track - read all tracks.
DriveInitParam:	dc.w	$01FF
		even
		
;---------------------------------------------------------------------------------------------------
; Level 2 interrupt code (Always initiated by Main CPU through a register)

SPInt:
		movem.l	d0-a6, -(sp)						; Back up all registers

		movem.l	(sp)+, d0-a6						; Restore registers.
		rts
		
;---------------------------------------------------------------------------------------------------
; Subroutines used by CD code
		
ReadCD:	
		movea.l	a5, a0								; Copy a5 to a0.
		move.w	#CDCSTOP, d0						; Stop the CD controller
		jsr 	$5F22								; Jump to BIOS.
		move.w	#ROMREADN, d0						; Start read operation
		jsr		$5F22

@checkIfPrepared:
		move.w	#CDCSTAT, d0						; Check if data is prepared.
		jsr		$5F22								; Jump into BIOS.
		bcs.s	@checkIfPrepared					; If no data is present, check again.

@checkForData:
		move.w	#CDCREAD, d0						; Read from CD.
		jsr		$5F22								; Jump into BIOS.
		bcc.s	@checkForData						; Try again if error happened.

@checkForData3:
		move.w	#CDCTRN, d0							; Read a frame of data.
		movea.l	8(a5), a0							; Move pointer to destination buffer?
		lea		$C(a5), a1							; Move pointer to next header buffer?
		jsr		$5F22								; Jump to BIOS.
		bcc.s	@checkForData3						; Try again if error.
		
		move.w	#CDCACK, d0							; Ends the data read.
		jsr		$5F22								; Jump into BIOS.
		
		addi.l	#$800, 8(a5)						; Add to next sector?
		addq.l	#1, (a5)							; Add to a5's memory
		subq.l	#1, 4(a5)							; Subtract 4 bytes into a5
		bne.s	@checkIfPrepared					; If there's more data to read, branch.
		rts
		
BeginOffset:
		dc.l	$0
Packet:
		dc.l	$10, 1, $8000, ExtraJunk, 0			; sector to read, number of sectors to read, Pointer to dest. buffer, header buffer, terminator?
		
ExtraJunk:
		dc.b	0
		even
		
EndSubCPU:
		even