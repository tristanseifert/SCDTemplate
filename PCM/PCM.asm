; A few small config memory areas
DriverStateArea:	EQU $37E00
; $00 - Channels enabled (1 = sounding/enabled)
; $01 - Song loaded flag.
; $02 - PCM Channel 1 current offset
; $04 - PCM Channel 2 current offset
; $06 - PCM Channel 3 current offset
; $08 - PCM Channel 4 current offset
; $0A - PCM Channel 5 current offset
; $0C - PCM Channel 6 current offset
; $0E - PCM Channel 7 current offset
; $10 - PCM Channel 8 current offset

SongStorageArea:	EQU $38000
SampleStorageArea:	EQU $40000

Level3JumpTableLoc:	EQU	$00005F82

;---------------------------------------------------------------------------------------------------
; PCM_InitialiseDriver
;
; Initialises the PCM driver, configuring it as the interrupt source and setting default
; parameters in memory, and initialising PCM registers.
;---------------------------------------------------------------------------------------------------

PCM_InitialiseDriver:
;		move.w	#$4EF9, (Level3JumpTableLoc).w					; Use JMP opcode in jump table
;		move.l	#DriverMainLoop_IntWrap, (Level3JumpTableLoc+2).w; Set the interrupt wrapper for int3
		
		bclr	#0, DriverStateArea+$1							; No song is loaded.
		
		lea		$FF0000, a1										; PCM chip to a1 
		move.b	#$FF, $11(a1)									; Disable sounding for all channels.
		
		moveq	#7, d7											; Loop over 8 channels.
		moveq	#0, d0											; Clear d0.
		
		moveq	#0, d2											; Channel's ST data
		
@initChannel:
		moveq	#7, d0											; Channel into d0
		sub.b	d7, d0											; Subtract loop counter.

		moveq	#0, d1											; Clear d1.
		move.b	d0, d1											; Get the channel.
		bset	#7, d1											; Make sure sounding is enabled.
		bset	#6, d1											; Enable "MOD" bit.
		move.b	d1, $F(a1)										; Set the control register to allow register modifications.
		bsr.s	PCM_WaitForRF5C164								; Wait for PCM chip.

		move.b	d2, $D(a1)										; Write channel ST data to PCM chip
		bsr.s	PCM_WaitForRF5C164								; Wait for PCM chip.
		move.b	d2, $B(a1)										; Set LSH to ST value.
		bsr.s	PCM_WaitForRF5C164								; Wait for PCM chip.
		move.b	#0, $9(a1)										; Set LSL to 0. (Sample loops.)
		bsr.s	PCM_WaitForRF5C164								; Wait for PCM chip.
		move.b	#0, $7(a1)										; FDH set to 0 (no sounding of this channel.)
		bsr.s	PCM_WaitForRF5C164								; Wait for PCM chip.
		move.b	#0, $5(a1)										; FDL set to 0 (no sounding of this channel.)
		bsr.s	PCM_WaitForRF5C164								; Wait for PCM chip.
		move.b	#$FF, $3(a1)									; Centred pan.
		bsr.s	PCM_WaitForRF5C164								; Wait for PCM chip.
		move.b	#$D0, $1(a1)									; Set envelope data.
		bsr.s	PCM_WaitForRF5C164								; Wait for PCM chip.

		add.b	#$20, d2										; Add to the ST data for the next channel.
		dbf		d7, @initChannel								; Keep looping.
		
		move.b	#$00, $11(a1)									; Enable sounding for all channels.
		
		rts

; This routine delays the code between register writes since the RF5C154 is a slow piece of shit.
PCM_WaitForRF5C164:
		move.l	d0, -(sp)										; Back up d0.

		moveq	#$14, d0										; Number of cycles to burn.
		
		; Each loop iteration is 4+4+10 = 18 cycles, plus 18 when exiting.
@burnCycles:
		nop
		nop
		dbf		d0, @burnCycles									; Keep looping.
		
		move.l	(sp)+, d0										; Restore d0.
		rts
		
;---------------------------------------------------------------------------------------------------
; PCM_LoadSong
;
; Loads the song ID specified in d0 to the driver's storage areas.
;---------------------------------------------------------------------------------------------------
PCM_LoadSong:
		move.w	#0, DriverStateArea								; Disable sounding of all channels - not playing.

		lea		SongIDArray(pc), a0								; Load the song array to a0.
		lsl.w	#3, d0											; Multiply by 8.

		move.l	4(a0, d0.w), d1									; Size (in sectors)
		
		lea		PCM_ReadCD_Packet(pc), a5						; Load the packet address to a5.
		move.l	(a0, d0.w), (a5)								; Load the start sector from the table.
		move.l	d1, 4(a5)										; Load the size of file in sectors to the packet.
		move.l	#SongStorageArea, 8(a5)							; Load the destination to the packet.
		bsr.w	PCM_ReadCD										; Read from the disc.
		
		lea		SampleBanks(pc), a0								; Load sample bank table to a0.
		moveq	#0, d0											; Clear d0.
		move.b	SongStorageArea, d0								; Get sample bank to use.
		lsl.w	#3, d0											; Multiply by 8.
		lea		(a0, d0.w), a0									; Get entry into table
		
		lea		PCM_ReadCD_Packet(pc), a5						; Load the packet address to a5.
		move.l	(a0), (a5)										; Load the start sector from the table.
		move.l	4(a0), 4(a5)									; Load the size of file in sectors to the packet.
		move.l	#SampleStorageArea, 8(a5)						; Load the destination to the packet.
		bsr.w	PCM_ReadCD										; Read from the disc.
		
		lea		DriverStateArea, a0								; Driver state area.
		moveq	#0, d0											; Clear d0.
		moveq	#$1F, d7										; Clear 32 * 8 bytes of song state memory.
		
@clearStateRAM:
		move.l	d0, (a0)+										; Clear 4 bytes.
		move.l	d0, (a0)+										; Clear 4 bytes.
		dbf		d7, @clearStateRAM								; Loop until everything is cleared.
		
		move.b	SongStorageArea+$2, ($FFFF8031).w				; Set the interrupt timer value.
		;move.w	#$00F0, ($FFFF8030).w							; Set timer.
		bset	#3, ($FFFF8033).w								; Enable level 3 int.
		
		moveq	#0, d0											; Clear d0, the loop counter.
		move.b	SongStorageArea+$1, d0							; Number of channels to use.

		lea		SongStorageArea+$4, a0							; Track pointer thingies
		lea		DriverStateArea+$2, a1							; PCM1 track offset.

@setUpInitialChannelData:
		move.w	(a0), (a1)+										; Get the initial track location to the state area.
		addq.l	#4, a0											; Move over to the next channel.		
		dbf		d0, @setUpInitialChannelData					; Keep looping until all channels are initialised.
		
		move.l	#"REND", DriverStateArea+$50					; Mark the end of the driver state area. (For memory dumps)
		
		lea		$FF0000, a1										; PCM chip to a1 
		move.b	#$FF, $11(a1)									; Enable sounding for all channels.
		;move.b	#$00, $11(a1)									; Enable sounding for all channels.
		
		move.b	#1, DriverStateArea+$1							; We just loaded a song.
		
		rts

;---------------------------------------------------------------------------------------------------
; PCM_LoadSampleToChip
;
; Loads a new sample to the chip (d0 is channel (1-8), d1 is the ID of the sample)
;
; Breaks: 	a0, a1, a2 
; 			d0, d1, d2, d3
;			(Backed up and restored)
;---------------------------------------------------------------------------------------------------
PCM_LoadSampleToChip:
		movem.l	d0-d3/a0-a2, -(sp)								; Back up the registers we mangle.

		moveq	#0, d3											; Clear d3
		moveq	#0, d2											; Clear d2
		subq.b	#1, d0											; Subtract one for the proper bit numbers for channels

		lea		$FF0000, a1										; PCM chip to a1 
		lea		$2001(a1), a2									; PCM wave RAM ($FF2001)
		
		moveq	#0, d3											; Clear d3.
		bset	d0, d3											; Set the right bit.
		move.b	d3, $11(a1)										; Disable sounding for the channel we're updating.
		bsr.w	PCM_WaitForRF5C164								; Wait for PCM chip.
				
		lea		SampleStorageArea, a0							; Sample bank storage
		lsl.w	#3, d1											; Multiply d1 by 8 to get sample offset into the table.
		;add.l	d1, a0											; Add to pointer.
		
		move.l	(a0, d1.w), d3									; Read first long of the sample's heasder (offset)
		move.l	4(a0, d1.w), d2									; Read second long of the sample's header (size)
		and.l	#$1FFF, d2										; Make sure length is < 8k
		
		lea		SampleStorageArea, a0							; Sample bank storage area
		add.l	d3, a0											; Add offset to a0
		
		; d1 can be abused at this point, d2 holds sample size
		bclr	d0, DriverStateArea								; Disable current channel
			
		; Configure the PCM chip to access the selected channel's registers.
		moveq	#0, d1											; Clear d2.
		move.b	d0, d1											; Get the channel.
		bset	#7, d1											; Make sure sounding is enabled.
		bset	#6, d1											; Enable "MOD" bit.
		move.b	d1, $F(a1)										; Set the control register to allow register modifications.
		bsr.w	PCM_WaitForRF5C164								; Wait for PCM chip.
		
		; Make sure this channel won't play.
		move.b	#$00, $7(a1)									; Set FDH to $00
		bsr.w	PCM_WaitForRF5C164								; Wait for PCM chip.
		move.b	#$00, $5(a1)									; Set FDL to $00
		bsr.w	PCM_WaitForRF5C164								; Wait for PCM chip.
		
		; Set up the PCM chip with the right bank for the channel.
		moveq	#0, d1											; Clear d2 — MOD is disabled, we select 4k bank.
		move.b	d0, d1											; Get the channel.
		add.b	d1, d1											; Multiply by two.
		bset	#7, d1											; Make sure sounding is enabled.
		move.b	d1, $F(a1)										; Update the control register to write to the bank for the channel.
		bsr.w	PCM_WaitForRF5C164								; Wait for PCM chip.
		
		; See if sample is > 4K
		cmp.w	#$FFF, d2										; Is the size less than 4K?
		bhs.s	@sampleMoreThan4K								; If not, branch.
		
		; Only copy what is needed.
		move.w	d2, d1											; Copy size (since < 4K) to loop counter
		bra.s	@copyFirst4K									; Jump into the loop.
		
		; Copy the first 4K.
@sampleMoreThan4K:
		move.w	#$FFF, d1										; Copy a 4K block first.
		
		; Begin copying to PCM RAM.
@copyFirst4K:
		move.b	(a0)+, (a2)										; Copy a byte of PCM data.
		addq.l	#2, a2											; Increase PCM address.
		dbf		d1, @copyFirst4K								; Keep looping.
		
		; If it was less than 4K, we're done here.
		cmp.w	#$FFF, d2										; Is the sample's size less than 4K?
		bls.s	@noMoreCopyNeeded								; If so, we're done here.
		
		; Configure the PCM chip to the second 4K bank for the channel.
		moveq	#0, d1											; Clear d2 — MOD is disabled, we select 4k bank.
		move.b	d0, d1											; Get the channel.
		add.b	d1, d1											; Multiply by two.
		bset	#0, d1											; Second bank for the channel.
		bset	#7, d1											; Make sure sounding is enabled.
		move.b	d1, $F(a1)										; Update the control register to write to the bank for the channel.
		bsr.w	PCM_WaitForRF5C164								; Wait for PCM chip.
		
		; Reset pointers and copy.
		lea		$2001(a1), a2									; Reset a2 to PCM wave RAM.
		moveq	#0, d1											; Clear d1
		move.w	d2, d1											; Copy the sample length to d1.
		sub.w	#$1000, d1										; Subtract 4K from it.
		and.w	#$FFF, d1										; Make sure it does not exceed 4k.
		
@copyMorePCMData:
		move.b	(a0)+, (a2)										; Copy a byte of PCM data.
		addq.l	#2, a2											; Increase PCM address.
		dbf		d1, @copyMorePCMData							; Keep looping.

		; Restore registers and exit.
@noMoreCopyNeeded:	
		; Configure the PCM chip to access the selected channel's registers.
		moveq	#0, d1											; Clear d2.
		move.b	d0, d1											; Get the channel.
		bset	#7, d1											; Make sure sounding is enabled.
		bset	#6, d1											; Enable "MOD" bit.
		move.b	d1, $F(a1)										; Set the control register to allow register modifications.
		bsr.w	PCM_WaitForRF5C164								; Wait for PCM chip.

		move.b	#$00, $11(a1)									; Enable sounding for all channels.
		bsr.w	PCM_WaitForRF5C164								; Wait for PCM chip.
		
		bset	d0, DriverStateArea								; Enable current channel
		
		move.b	#$FF, (a2)										; Write end of sample flag.
		move.b	#$FF, 2(a2)										; Write end of sample flag.
		move.b	#$FF, 4(a2)										; Write end of sample flag.
		move.b	#$FF, 6(a2)										; Write end of sample flag.
		
		moveq	#4, d1
		BIOS_LEDSET
		
		movem.l	(sp)+, d0-d3/a0-a2								; Restore the registers we mangled.
		rts
	
;---------------------------------------------------------------------------------------------------
; PCM_ReadCD
;
; Reads a specified number of sectors from the disc.
;---------------------------------------------------------------------------------------------------
	
PCM_ReadCD:	
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
		
PCM_NoteFDEquivs:   
		dc.w 0                  ; rest
		dc.w $104               ; C0 
		dc.w $113               ; C#0 
		dc.w $124               ; D0 
		dc.w $135               ; D#0 
		dc.w $148               ; E0 
		dc.w $15B               ; F0 
		dc.w $170               ; F#0 
		dc.w $186               ; G0 
		dc.w $19D               ; G#0 
		dc.w $1B5               ; A0 
		dc.w $1D0               ; A#0 
		dc.w $1EB               ; B0 
		dc.w $208               ; C1 
		dc.w $228               ; C#1 
		dc.w $248               ; D1 
		dc.w $26B               ; D#1 
		dc.w $291               ; E1 
		dc.w $2B8               ; F1 
		dc.w $2E1               ; F#1 
		dc.w $30E               ; G1 
		dc.w $33C               ; G#1 
		dc.w $36E               ; A1 
		dc.w $3A3               ; A#1 
		dc.w $3DA               ; B1 
		dc.w $415               ; C2 
		dc.w $454               ; C#2 
		dc.w $497               ; D2 
		dc.w $4DD               ; D#2 
		dc.w $528               ; E2 
		dc.w $578               ; F2 
		dc.w $5CB               ; F#2 
		dc.w $625               ; G2 
		dc.w $684               ; G#2 
		dc.w $6E8               ; A2 
		dc.w $753               ; A#2 
		dc.w $7C4               ; B2 
		dc.w $83B               ; C3 
		dc.w $8B0               ; C#3 
		dc.w $93D               ; D3 
		dc.w $9C7               ; D#3 
		dc.w $A60               ; E3 
		dc.w $AF8               ; F3 
		dc.w $BA8               ; F#3 
		dc.w $C55               ; G3 
		dc.w $D10               ; G#3 
		dc.w $DE2               ; A3 
		dc.w $EBE               ; A#3 
		dc.w $FA4               ; B3 
		dc.w $107A              ; C4 
		dc.w $1186              ; C#4 
		dc.w $1280              ; D4 
		dc.w $1396              ; D#4 
		dc.w $14CC              ; E4 
		dc.w $1624              ; F4 
		dc.w $1746              ; F#4 
		dc.w $18DE              ; G4 
		dc.w $1A38              ; G#4 
		dc.w $1BE0              ; A4 
		dc.w $1D94              ; A#4 
		dc.w $1F65              ; B4 
		dc.w $20FF              ; C5 
		dc.w $2330              ; C#5 
		dc.w $2526              ; D5 
		dc.w $2753              ; D#5 
		dc.w $29B7              ; E5 
		dc.w $2C63              ; F5 
		dc.w $2F63              ; F#5 
		dc.w $31E0              ; G5 
		dc.w $347B              ; G#5 
		dc.w $377B              ; A5 
		dc.w $3B41              ; A#5 
		dc.w $3EE8              ; B5 
		dc.w $4206              ; C6 
		dc.w $4684              ; C#6 
		dc.w $4A5A              ; D6 
		dc.w $4EB5              ; D#6 
		dc.w $5379              ; E6 
		dc.w $58E1              ; F6 
		dc.w $5DE0              ; F#6 
		dc.w $63C0              ; G6 
		dc.w $68FF              ; G#6 
		dc.w $6EFF              ; A6 
		dc.w $783C              ; A#6 
		dc.w $7FC2              ; B6 
		dc.w $83FC              ; C7 
		dc.w $8D14              ; C#7 
		dc.w $9780              ; D7 
		dc.w $9D80              ; D#7 
		dc.w $AA5D              ; E7 
		dc.w $B1F9              ; F7 
		dc.w $BBBA              ; F#7 
		dc.w $CC77              ; G7 
		dc.w $D751              ; G#7 
		dc.w $E333              ; A7 	
		dc.w $F0B5              ; A#7
		
SongIDArray:
		; An entry is like so: dc.l song_sector, song_size_in_sectors
		dc.l	FILE_PCMSONG__BIN_START_SECTOR, FILE_PCMSONG__BIN_SIZE_SECTORS
		dc.l	0
		
SampleBanks:
		; Sample bank sector, sample bank size in sectors
		dc.l	FILE_PCM__TST_BNK_START_SECTOR, FILE_PCM__TST_BNK_SIZE_SECTORS
		dc.l	0
		

PCM_ReadCD_Packet:
		dc.l	$10, 1, $8000, PCM_ReadCD_ExtraJunk, 0			; sector to read, number of sectors to read, Pointer to dest. buffer, header buffer, terminator?
		
PCM_ReadCD_ExtraJunk:
		dc.b	0
		even

;---------------------------------------------------------------------------------------------------
; DriverMainLoop_IntWrap
;
; A routine that can be set as an interrupt vector (for example, the level 3 timer interrupt) that
; backs up the registers and calls the driver.
;
; Destroys: Nothing (All is backed up to the stack.)
;---------------------------------------------------------------------------------------------------

DriverMainLoop_IntWrap:
		movem.l	d0-a6, -(sp)									; Back up all registers
		
		bsr.s	DriverMainLoop									; Jump to sound driver.
		
		movem.l	(sp)+, d0-a6									; Restore registers.
		rte														; We're jumped to straight from the vector table, so rte.

;---------------------------------------------------------------------------------------------------
; DriverMainLoop
;
; The driver's main loop, called every timer interrupt.
;
; Destroys: Everything! (srsly, it does) =V
;
; a6, a5, a4, d7 and d6 should not be touched by subroutines — however, if they are, they have to be
; backed up and restored properly or the driver might blow up and crash about as bad as if SEGA
; of Japan programmers were involved in the process of writing it.
;---------------------------------------------------------------------------------------------------
DriverMainLoop:
		cmp.b	#1, DriverStateArea+$1							; Is a song loaded?
		bne.s	@noSongLoaded									; If no song is loaded, exit.

		moveq	#7, d7											; Process all 8 PCM channels.
		lea		DriverStateArea+$2, a5							; Driver state area.
		lea		DriverStateArea+$20, a4							; Each channel has 8 bytes starting at $20.

@processChannels:
		lea		SongStorageArea, a6								; Area of song storage.
		add.w	(a5), a6										; Get the current channel's offset.

@pcmProcessCommand:		
		cmp.b	#$D0, (a6)										; Is this instruction a flag?
		bhs.w	@proccessFlag									; If so, branch.

		; We process all flags following each other until we hit a note.
		subq.b	#1, (a4)										; Subtract from the time.
		cmp.b	#$FF, (a4)										; Are we ready to process the next note?
		bne.s	@pcmDoneProcessing								; If not, branch.
		
		moveq	#0, d0											; Clear d0.
		move.b	(a6)+, d0										; Get note to d0.
		add.w	d0, d0											; Multiply by two.
		lea		PCM_NoteFDEquivs(pc), a0		 				; Get note table address to a0
		move.w	(a0, d0.w), d0									; Get the right note value to d0

		move.b	(a6)+, (a4)										; Set the timer value.

		; Now we get to transfer this value to the PCM chip.
		bsr.w	@transferFDToPCM								; Call subroutine to transfer.

@pcmDoneProcessing:
		; When we're done, write the current song offset.
		sub.l	#SongStorageArea, a6							; Subtract base from it
		move.w	a6, (a5)+										; Write it to memory.
		lea		$8(a4), a4										; Next channel's memory.

		dbf		d7, @processChannels							; Loop until all channels are processed.

@noSongLoaded:
		rts
		
; Called by the main loop to transfer the FD value in d0 to the PCM chip.
;
; Destroys: a1, d1, d2

@transferFDToPCM:
		movem.l	d1-d2/a1, -(sp)									; Back up registers.
		lea		$FF0000, a1										; PCM chip to a1 
	
		moveq	#7, d2											; 8 channels
		sub.b	d7, d2											; Subtract loop counter from it.
			
		; Configure the PCM chip to access the selected channel's registers.
		moveq	#0, d1											; Clear d2.
		move.b	d2, d1											; Get the channel.
		bset	#7, d1											; Make sure sounding is enabled.
		bset	#6, d1											; Enable "MOD" bit.	
		move.b	d1, $F(a1)										; Set the control register to allow register modifications.
		bsr.w	PCM_WaitForRF5C164								; Wait for PCM chip.
	
		move.w	d0, d1											; Get the value to d1.
		and.w	#$FF, d1										; Get only the low part.
		move.b	d1, $5(a1)										; Write the low part of the FD.
		bsr.w	PCM_WaitForRF5C164								; Wait for PCM chip.
	
		move.w	d0, d1											; Get the value to d1.
		and.w	#$FF00, d1										; Get only the high part.
		lsr.w	#8, d1											; Shift it into the low position.
		move.b	d1, $7(a1)										; Write the high part of the FD.
	
		movem.l	(sp)+, d1-d2/a1									; Restore registers.
		rts

; Called by the main loop to process a flag.
; a6 has the pointer to the byte after the instruction.
; 
; Destroys: d0

@proccessFlag:
		movem.l	d0-d1/a0, -(sp)									; Back up registers.

		moveq	#0, d0											; Clear d0.
		move.b	(a6)+, d0										; Copy the command.
		sub.w	#$D0, d0										; Subtract command offset.
		add.w	d0, d0											; Multiply by 2
		add.w	d0, d0											; Multiply by 2
		
		move.l	@flagRoutines(pc, d0.w), a0						; Get the offset out of the table.
		jsr		(a0)											; Jump to the correct routine.

		movem.l	(sp)+, d0-d1/a0									; Restore registers.
		bra.w	@pcmProcessCommand								; Return back to the driver.
		
@flagRoutines:
		dc.l	PCM_ChangeInstrument							; $D0
		dc.l	PCM_ChangePan
		dc.l	PCM_SetNoteDisp
		dc.l	PCM_Loop
		dc.l	PCM_SetVolume
		dc.l	PCM_RegJmp										; $D5
		dc.l	PCM_CondJmp
		
; Routine to change the current channel's PCM sample.
; Destroys: d0, d1

PCM_ChangeInstrument:		
		move.b	(a6)+, d1										; Get sample to load.
		moveq	#8, d0											; Channel.
		sub.b	d7, d0											; Subtract current loop iteration.
		bsr.w	PCM_LoadSampleToChip							; Load new sample to chip (d0=chan, d1=sample)
		
		rts

; Routine jumps back or forward a specific amount of bytes.
PCM_RegJmp:
		moveq	#0, d0											; Clear d0.
		move.b	(a6)+, d0										; Get the high word.
		lsl.w	#8, d0											; Shift it into position.
		move.b	(a6)+, d0										; Get the low word.
		
		lea		-3(a6), a6										; Rewind 3 bytes.
		
		cmp.w	#$8000, d0										; Is it a negative displacement (bit 15 set)?
		bhs.s	@negDisplace									; If so, branch.

		add.l	d0, a6											; Add to the offset.

		bra.s	@continue										; Branch over negative displacement code.

@negDisplace:
		and.w	#$7FFF, d0										; Clear sign bit. (Faster than bclr)
		sub.l	d0, a6											; Subtract from the offset.

@continue:
		rts
		
PCM_ChangePan:
PCM_SetNoteDisp:
PCM_Loop:
PCM_SetVolume:
PCM_CondJmp:
		rts
		
;---------------------------------------------------------------------------------------------------
; LoopRoutines
;
; A table pointing to routines that are called by the driver when it encouters a loop or jump flag
; with an index greater than $04. Index $05 is the first entry in this table. Return 0 in d0 to not
; perform the loop/jump, or $FF to perform the loop/jump.
;---------------------------------------------------------------------------------------------------

LoopRoutines:
		dc.l	@defaultLoopRoutine
		
@defaultLoopRoutine:
		move.b	#$FF, d0
		rts
