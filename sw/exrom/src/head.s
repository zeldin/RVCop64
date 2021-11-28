
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

vuart_loop:
	bit $de11
	bmi @nooutp
	lda $de10
	jsr $ffd2
	bit $de11
@nooutp:
	bvs vuart_loop
	jsr $ffe4
	cmp #0
	beq vuart_loop
	sta $de10
	bne vuart_loop


message:		
	.byte $0e, "Hello, world!", $0d, $0d, 0
