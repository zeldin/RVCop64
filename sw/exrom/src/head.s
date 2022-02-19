	.import install_basic_wedge

	.code
	
	.word coldstart
	.word warmstart

	.byte "CBM80"

coldstart:
	sei
	ldx #$ff
	txs
	cld
	lda #$37
	sta $01
	lda #$2f
	sta $00
	lda #$0b
	sta $d011
	jsr $fda3
	jsr $fd50
	jsr $fd15
	jsr $ff5b
	cli
	jsr $e453
	jsr install_basic_wedge
	jsr $e3bf
	jsr $e422
	lda #<welcome_message
	ldy #>welcome_message
	jsr $ab1e
	jmp $e39d

nostop:
	jmp $fe72
warmstart:
	jsr $f6bc
	jsr $ffe1
	bne nostop
	jsr $fd15
	jsr $fda3
	jsr $e518
	jmp ($a002)

welcome_message:
	.byte $9f, "   rvcop64 installed, rvhelp for help", $9a, $0d, 0

