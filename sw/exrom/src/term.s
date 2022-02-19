	.import ansi_reset, ansi_print, ansi_getc
	.import ansi_cursor_on, ansi_cursor_off

	.global rvterm

	.code
	
rvterm:
	jsr ansi_reset
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
