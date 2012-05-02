; A few small config memory areas
DriverStateArea:	EQU $30000
SongStorageArea:	EQU $30200
SampleStorageArea:	EQU $40000

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
	; An entry is like so: dc.l song_sector, sample_bank_id
	dc.l	0, 1
	dc.l	0
	
SampleBanks:
	; Sample bank sector, sample bank size in sectors
	dc.l	FILE_PCM__TST_BNK_START_SECTOR, FILE_PCM__TST_BNK_SIZE_SECTORS
	dc.l	0