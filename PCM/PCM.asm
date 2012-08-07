; A few small config memory areas
DriverStateArea:	EQU $30000
; $0 - Channels enabled (1 = sounding/enabled)
;
SongStorageArea:	EQU $30200
SampleStorageArea:	EQU $40000

;---------------------------------------------------------------------------------------------------
; LoadSong
;
; Loads the song ID specified in d0 to the driver's storage areas.
;---------------------------------------------------------------------------------------------------
LoadSong:
		move.w	#0, DriverStateArea					; Disable sounding of all channels - not playing.

		lea		SongIDArray(pc), a0					; Load the song array to a0.
		lsl.w	#3, d0								; Multiply by 8.

		move.l	4(a0, d0.w), d1						; Size and sample bank ID.
		move.l	d1, -(sp)							; Write to stack.
		and.l	#$FFFF0000, d1						; Get size by itself.
		swap	d1									; Swap high word to low
		
		lea		ReadCD_Packet(pc), a5				; Load the packet address to a5.
		move.l	(a0, d0.w), (a5)					; Load the start sector from the table.
		move.l	d1, 4(a5)							; Load the size of file in sectors to the packet.
		move.l	#SongStorageArea, 8(a5)				; Load the destination to the packet.
		bsr.w	ReadCD								; Read from the disc.
		
		lea		SampleBanks(pc), a0					; Load sample bank table to a0.
		move.l	(sp)+, d0							; Get size and sample bank ID to d0.
		and.l	#$FFFF, d0							; Get rid of size byte.
		lsl.w	#3, d0								; Multiply by 8.
		lea		(a0, d0.w), a0						; Get entry into table
		
		lea		ReadCD_Packet(pc), a5				; Load the packet address to a5.
		move.l	(a0), (a5)							; Load the start sector from the table.
		move.l	4(a0), 4(a5)						; Load the size of file in sectors to the packet.
		move.l	#SampleStorageArea, 8(a5)			; Load the destination to the packet.
		bsr.w	ReadCD								; Read from the disc.
		
		rts

;---------------------------------------------------------------------------------------------------
; LoadSampleToChip
;
; Loads a new sample to the chip (d0 is channel, d1 is the ID of the sample)
;---------------------------------------------------------------------------------------------------
LoadSampleToChip:
		lea		SampleStorageArea, a0
		lsl.w	#2, d0								; Multiply d0 by 4 to get sample offset
		move.l	(a0, d0.w), d2						; Get offset of the sample.
		add.l	d2, a0								; Add offset of the sample to the storage area.
		
		lea		$FF0000, a1							; PCM chip to a1 
		
		subq.b	#1, d0								; Subtract one for the proper bit numbers
		bclr	d0, DriverStateArea					; Disable current channel
		move.b	DriverStateArea, $11(a1)			; Write enabled channels
		
		move.b	#$4, 7(a1)							; Reset FDH
		move.b	#$15, 5(a1)							; Reset FDL
		
		bset	d0, DriverStateArea					; Enable current channel
		move.b	DriverStateArea, $11(a1)			; Write enabled channels
		
		; ----- insert code to copy the sample to the PCM chip here -----
		
		rts
	
;---------------------------------------------------------------------------------------------------
; PCM_ReadCD
;
; Reads a specified number of sectoruus from the disc.
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
		
NoteFDEquivs:   
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
		; An entry is like so: dc.l song_sector, high: size, low:sample_bank_id
		dc.l	0, $00120001
		dc.l	0
		
SampleBanks:
		; Sample bank sector, sample bank size in sectors
		dc.l	FILE_PCM__TST_BNK_START_SECTOR, FILE_PCM__TST_BNK_SIZE_SECTORS
		dc.l	0
		

ReadCD_Packet:
		dc.l	$10, 1, $8000, ReadCD_ExtraJunk, 0			; sector to read, number of sectors to read, Pointer to dest. buffer, header buffer, terminator?
		
ReadCD_ExtraJunk:
		dc.b	0
		even

;---------------------------------------------------------------------------------------------------
; DriverMainLoop
;
; The driver's main loop
;---------------------------------------------------------------------------------------------------
DriverMainLoop:

		rts


;---------------------------------------------------------------------------------------------------
; LoopRoutines
;
; A table pointing to routines that are called by the driver when it encouters a loop or jump flag
; with an index greater than $04. Index $05 is the first entry in this table. Return 0 in d0 to not
; perform the loop/jump, or $FF to perform the loop/jump.
;---------------------------------------------------------------------------------------------------

LoopRoutines:
		dc.l	
