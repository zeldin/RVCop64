
mmucr  = $ff00
primm  = $ff7d
chrout = $ffd2

smode = $d7
color = $f1

	.code

	sei
	cld
	clv
	jmp funcstart

	.byte $ff,"cbm"

funcstart:
	lda #$08
	sta mmucr

	lda color
	pha
	lda #$1e
	ldx #12
	bit smode
	bpl col40
	lda #$97
	ldx #32
col40:
	jsr chrout
	lda #' '
align:
	jsr chrout
	dex
	bpl align

	jsr primm
	.byte $a,"rvcop64 running",$d,0
	pla
	sta color
	rts
