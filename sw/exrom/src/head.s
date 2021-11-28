
	.import ansi_reset, ansi_print, ansi_getc
	.import ansi_cursor_on, ansi_cursor_off

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
	jsr ansi_reset

	ldx #0
@more_message:	
	lda message,x
	beq @end_message
	jsr $ffd2
	inx
	bne @more_message
@end_message:

vuart_loop_busy:
	jsr ansi_cursor_off
vuart_loop:
	bit $de11
	bmi @nooutp
	jsr ansi_cursor_off
	lda $de10
	jsr ansi_print
	bit $de11
	bvs vuart_loop
@check_input:
	jsr ansi_getc
	bcs vuart_loop
	cmp #0
	beq vuart_loop
@gotchar:
	sta $de10
	bcc vuart_loop
@nooutp:
	bvs vuart_loop_busy
	jsr ansi_getc
	bcs vuart_loop_busy
	cmp #0
	bne @gotchar
	jsr ansi_cursor_on
	jmp vuart_loop


message:		
	.byte $0e, "Hello, world!", $0d, $0d, 0
