
	.global ansi_reset, ansi_print, ascii_print
	.global ansi_getc


chrout = $ffd2
getin = $ffe4


	.zeropage

ansi_esc:	.res 1
ansi_color:	.res 1
csi_params:	.res 2
ansi_keypos:	.res 1


	.code
	
	;; Reset ANSI terminal emulation
ansi_reset:
	lda #0
	sta ansi_esc
	sta ansi_keypos
	lda #$0e	; text mode
	jsr chrout
	lda #$92	; rvsoff
	jsr chrout
	lda #$0f

	;; Set ANSI foreground color
ansi_set_fg_color:
	and #$0f
	sta ansi_color
	tay
	lda ansi_color_table,y
	jmp chrout
	
	;; Print a character with (partial) ANSI terminal emulation
ansi_print:	
	cmp #$1b
	beq @esc
	ldx ansi_esc
	bne @check_esc
	jmp ascii_print
	
@esc:		
	lda #$ff
	sta ansi_esc
	rts

@esc_done:
	lda #0
	sta ansi_esc
	rts
	
@check_csi:
	cmp #$1b
	bne @esc_done
	ldx #0
	stx csi_params
	inx
	stx ansi_esc
	rts

@next_param:
	cpx #2
	bcs @noreset
	lda #0
	sta csi_params,x
@noreset:	
	inx
	bmi @noinc
	stx ansi_esc
@noinc:	
	rts

@check_esc:
	bmi @check_csi
	cmp #';'
	beq @next_param
	cmp #$40
	bcs @csi_end
	sbc #'0'-1
	bcc @skipdig
	cmp #10
	bcs @skipdig
	cpx #3
	bcs @skipdig
	tay
	lda csi_params-1,x
	asl
	asl
	adc csi_params-1,x
	asl
	sta csi_params-1,x
	tya
	adc csi_params-1,x
	sta csi_params-1,x
@skipdig:
	rts

@csi_end:
	ldy #0
	sty ansi_esc
	cmp #'A'
	beq @cursor_up
	cmp #'B'
	beq @cursor_down
	cmp #'C'
	beq @cursor_right
	cmp #'D'
	beq @cursor_left
	cmp #'H'
	beq @curspos
	cmp #'J'
	beq @clrscr
	cmp #'m'
	beq @sgr
	rts

@cursor_up:
	lda #$91
	bne @cursor
@cursor_down:	
	lda #$11
	bne @cursor
@cursor_right:	
	lda #$1d
	bne @cursor
@cursor_left:
	lda #$9d
@cursor:
	ldx csi_params
	bne @cursloop
	inx
@cursloop:
	jsr chrout
	dex
	bne @cursloop
	rts

@curspos:
	lda #$13
	jsr chrout
	cpx #2
	bcc @nocol
	ldx csi_params+1
	beq @nocol
	dex
	beq @nocol
	lda #$1d
	jsr @cursloop
@nocol:	
	ldx csi_params
	beq @norow
	lda #$11
	dex
	bne @cursloop
@norow:	
	rts

@clrscr:
	lda #$93
	jmp chrout
	
@sgr:
	dex
@next_sgr:	
	lda csi_params,x
	cmp #10
	bcc @attr
	sbc #30
	bcc @unhandled_sgr
	cmp #8
	bcc @fg_color
	cmp #98-30
	bcs @unhandled_sgr
	sbc #90-30-8-1
	cmp #8
	bcc @unhandled_sgr
@fg_color:	
	jsr ansi_set_fg_color
@unhandled_sgr:
	dex
	bpl @next_sgr
	rts

@attr:
	cmp #0
	bne @not0
	lda #$92	; rvsoff
	jsr chrout
	lda #$0f
	bne @fg_color
	
@not0:	
	cmp #1
	bne @not1
	lda ansi_color
	ora #$08
	bne @fg_color

@not1:
	cmp #2
	bne @not2
	lda ansi_color
	and #$07
	bpl @fg_color

@not2:	
	cmp #7
	bne @unhandled_sgr
	lda #$12	; rvson
	jsr chrout
	jmp @unhandled_sgr

	;; Print an ASCII character
ascii_print:
	cmp #$20
	bcc @ctrl
	cmp #$7f
	bcs @ctrl
	cmp #$41
	bcc @done
	cmp #$5b
	bcc @swapcase
	cmp #$5f
	beq @underscore
	bcc @done
	cmp #$60
	beq @backtick
	cmp #$7b
	bcc @swapcase
	cmp #$7e
	beq @tilde
@done:	
	jmp chrout
@swapcase:	
	eor #$20
	jmp chrout
@tilde:
	lda #$ba
	bne @done
@backtick:
	lda #$ad
	bne @done
@underscore:
	lda #$a4
	bne @done

@ctrl:
	cmp #$0c
	beq @clear
	cmp #$0d
	beq @done
	cmp #$7f
	beq @del
	cmp #$08
	bne @unknown_ctrl
@del:	
	lda #$14
	bne @done
@clear:	
	lda #$93
	bne @done
@unknown_ctrl:	
	rts


ansi_color_table:	
	.byte	$90		; black
	.byte	$1c		; red
	.byte	$1e		; green
	.byte	$95		; dark yellow (brown)
	.byte	$1f		; blue
	.byte	$81		; dark purple (orange)
	.byte	$97		; dark cyan (gray 1)
	.byte	$98		; light gray (gray 3)
	.byte	$9b		; dark gray (gray 2)
	.byte	$96		; light red
	.byte	$99		; light green
	.byte	$9e		; light yellow (yellow)
	.byte	$9a		; light blue
	.byte	$9c		; light purple (purple)
	.byte	$9f		; light cyan (cyan)
	.byte	$05		; white


ansi_getc:
	ldx ansi_keypos
	bne @send_esc_seq
	jsr getin
	bcs @done
	cmp #0
	beq @doneok
	cmp #$91
	beq @cursor_up
	cmp #$11
	beq @cursor_down
	cmp #$1d
	beq @cursor_right
	cmp #$9d
	beq @cursor_left
	cmp #$13
	beq @home
	cmp #$94
	beq @insert
	cmp #$14
	bne @doneok
	ldx #esc_seq_del-esc_seq_base+1
	bne @start_esc_seq
@cursor_up:
	ldx #esc_seq_up-esc_seq_base+1
	bne @start_esc_seq
@cursor_down:	
	ldx #esc_seq_down-esc_seq_base+1
	bne @start_esc_seq
@cursor_right:	
	ldx #esc_seq_right-esc_seq_base+1
	bne @start_esc_seq
@cursor_left:
	ldx #esc_seq_left-esc_seq_base+1
	bne @start_esc_seq
@home:
	ldx #esc_seq_home-esc_seq_base+1
	bne @start_esc_seq
@insert:		
	ldx #esc_seq_ins-esc_seq_base+1
@start_esc_seq:
	stx ansi_keypos
	lda #$1b
@doneok:	
	clc
@done:	
	rts

@send_esc_seq:
	lda esc_seq_base-1,x
	inx
	cmp #$40
	bcc @more
	cmp #$5b
	beq @more
	ldx #0
@more:	
	stx ansi_keypos
	cmp #$ff	; clear Z and C
	rts

esc_seq_base:	
esc_seq_ins:
	.byte "[2~"
esc_seq_del:
	.byte "[3~"
esc_seq_up:
	.byte "[A"
esc_seq_down:
	.byte "[B"
esc_seq_right:
	.byte "[C"
esc_seq_left:
	.byte "[D"
esc_seq_home:
	.byte "[H"

