
	.code
	
	.word start
	.word start

	.byte "CBM80"

start:
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
	jsr $ff84
	jsr $ff87
	jsr $ff8a
	jsr $ff81

	ldx #0
@more_message:	
	lda message,x
	beq @end_message
	jsr $ffd2
	inx
	bne @more_message
@end_message:
	jmp @end_message

message:		
	.byte $0e, "Hello, world!", 0
