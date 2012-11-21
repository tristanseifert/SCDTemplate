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
		lea	DriveInitParam(pc), a0					; Load drive initialization pramaters
		BIOS_DRVINIT								; Read the ToC from the disc.
		BIOS_CDCSTOP								; Stop any data read that might be going on
		
		; we can BRA since this rts's, saves 2 bytes and a bit of CPU time
		;bra.w	PCM_InitialiseDriver				; Initialise the PCM driver.
		
		rts
	
SPMain:		
		bsr.w	PCM_InitialiseDriver				; Initialise the PCM driver.
		
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
		cmp.b	#5, d0								; Are we executing 'PlayPCM?'
		beq.w	PlayPCM								; If so, branch.

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
		
; ===============================================================================

; Plays a simple drum loop.
; The FD value for the samples is all 0x03EF.
PlayPCM:		
		bsr.w	PCM_InitialiseDriver

		moveq	#0, d0								; Song 0
		bsr.w	PCM_LoadSong

		moveq	#1, d0											; Channel 1 (1 based)
		moveq	#0, d1
;		bsr.w	PCM_LoadSampleToChip

		bra.w	ReturnToMain
		
		moveq	#0, d0								; Clear d0.	
		move.b	#$FF, $FF0011						; Disable all channels.
		bsr.w	PCMWait								; Wait for PCM chip. 
		move.b	#$80, $FF000F						; Enable sounding, lowest bank of wave RAM
		bsr.w	PCMWait								; Wait for PCM chip.

		move.w	#$FFF, d0							; First 4 KB of Piano voice
		lea		Sample_Piano(pc), a1				; Piano voice to a1.
		lea		$FF2001, a2							; PCM Wave RAM to a2.
		
@loop1:
		move.b	(a1)+, (a2)							; Write a byte to Wave RAM.
		addq.l	#2, a2								; Add 2 to the offset in Wave RAM.
		dbf		d0, @loop1							; Loop until all is written.
		
		move.b	#$81, $FF000F						; Enable sounding, second bank of wave RAM
		bsr.w	PCMWait								; Wait for PCM chip.
		
		lea		$FF2001, a2							; PCM Wave RAM to a2.
		move.w	#$C5C, d0							; Second 4 KB of the sample
		
@loop2:
		move.b	(a1)+, (a2)							; Write a byte to Wave RAM.
		addq.l	#2, a2								; Add 2 to the offset in Wave RAM.
		dbf		d0, @loop2							; Loop until all is written.
		
		lea		$FF0000, a0							; Load PCM sound source to a0.
		
		move.b	#$C0, $F(a0)						; Enable sounding, Configure Ch1
		bsr.s	PCMWait								; Wait for PCM chip.
		
		move.b	#$00, $A(a0)						; Set LSH to 0
		bsr.s	PCMWait								; Wait for PCM chip.
		move.b	#$10, $9(a0)						; Set LSL to 0
		bsr.s	PCMWait								; Wait for PCM chip.
		move.b	#$03, $7(a0)						; Set FDH to $03
		bsr.s	PCMWait								; Wait for PCM chip.
		move.b	#$EF, $5(a0)						; Set FDL to $EF
		bsr.s	PCMWait								; Wait for PCM chip.
		move.b	#$FF, $3(a0)						; Center pan for L and R
		bsr.s	PCMWait								; Wait for PCM chip.
		move.b	#$FF, $1(a0)						; Set envelope to $E0
		bsr.s	PCMWait								; Wait for PCM chip.
		
		move.b	#$FE, $11(a0)						; Enable channel 1
		bsr.s	PCMWait								; Wait for PCM chip.
		move.b	#$00, $D(a0)						; Set start address to $0000
		bsr.s	PCMWait								; Wait for PCM chip.
		move.b	#$C0, $F(a0)						; Enable sounding for channel 1.
		bsr.s	PCMWait								; Wait for PCM chip.
		
		bra.w	ReturnToMain						; Jump back to main loop.
	
PCMWait:
		moveq  #$7F, d0								; Loop 127 times.

@PCMWaitLoop:
		nop
		nop
		dbf		d0, @PCMWaitLoop						; Loop.
		
		rts											; Return back to caller.
	
		
; ===============================================================================

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

		bsr.w	DriverMainLoop						; Run PCM driver.

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
		
Sample_Piano:
		incbin	"PCM/piano.pcm"
		dc.b	$FF, $FF, $FF, $FF
		even
		
		include	"PCM/PCM.asm"
		
EndSubCPU:
		even