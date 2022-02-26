
	.global install_basic_wedge

	.import rvterm
	.import rvmem_addr, rvmem_data, rvmem_cmd
	.import rvdebug_halt, rvdebug_continue
	.import rvdebug_setreg, rvdebug_getreg, rvdebug_jump

endchr = $08
count  = $0b
valtyp = $0d
dores  = $0f
poker  = $14
lstpnt = $49
deccnt = $5d
facexp = $61
facho  = $62
facmoh = $63
facmo  = $64
faclo  = $65
facsgn = $66
bufptr = $71
chrget = $73
chrgot = $79
txtptr = $7a
buf    = $0200
reslst = $a09e
prit4  = $a6ef
ploop  = $a6f3
newstt = $a7ae
gone   = $a7e4
outdo  = $ab47
frmnum = $ad8a
qdot   = $aead
parchk = $aef1
chkcom = $aefd
snerr  = $af08
isvar  = $af28
isletc = $b113
fcerr  = $b248
sngflt = $b3a2
getbyt = $b79e
combyt = $b7f1
getadr = $b7f7
overr  = $b97e
qint   = $bc9b
fin    = $bcf3
finlog = $bd7e

datatk = $83
remtk  = $8f
printk = $99
plustk = $aa
pi     = $ff
	
	.code
		
install_basic_wedge:
	lda #<newcrunch
	ldy #>newcrunch
	sta $0304
	sty $0305
	lda #<newqplop
	ldy #>newqplop
	sta $0306
	sty $0307
	lda #<newgone
	ldy #>newgone
	sta $0308
	sty $0309
	lda #<neweval
	ldy #>neweval
	sta $030a
	sty $030b
	rts


newcrunch:
	ldx txtptr	;SET SOURCE POINTER.
	ldy #4	        ;SET DESTINATION OFFSET.
	sty dores	;ALLOW CRUNCHING.
@kloop:
	lda buf,x
	bpl @cmpspc	;GO LOOK AT SPACES.
	cmp #pi		;PI??
	beq @stuffh	;GO SAVE IT.
	inx		;SKIP NO PRINTING.
	bne @kloop	;ALWAYS GOES.

@cmpspc:
	cmp #' '	;IS IT A SPACE TO SAVE?
	beq @stuffh	;YES, GO SAVE IT.
        sta endchr      ;IF IT'S A QUOTE, THIS WILL STOP LOOP WHEN OTHER QUOTE APPEARS.
	cmp #'"'	;QUOTE SIGN?
	beq @strng	;YES, DO SPECIAL STRING HANDLING.
	bit dores	;TEST FLAG.
	bvs @stuffh	;NO CRUNCH, JUST STORE.
	cmp #'?'	;A QMARK?
	bne @kloop1
	lda #printk	;YES, STUFF A "PRINT" TOKEN.
	bne @stuffh	;ALWAYS GO TO STUFFH.
@kloop1:
	cmp #'0'	;SKIP NUMERICS.
	bcc @mustcr
	cmp #';'+1	;":" AND ";" ARE ENTERED STRAIGHTAWAY.
	bcc @stuffh
@mustcr:
	sty bufptr	;SAVE BUFFER POINTER.
	ldy #0		;LOAD RESLST POINTER.
	sty count	;ALSO CLEAR COUNT.
	dey
	stx txtptr	;SAVE TEXT POINTER FOR LATER USE.
	dex
@reser:
	iny
	inx
@rescon:
	lda buf,x
	sec		;PREPARE TO SUBSTARCT.
	sbc reslst,y	;CHARACTERS EQUAL?
	beq @reser	;YES, CONTINUE SEARCH.
	cmp #$80	;NO BUT MAYBE THE END IS HERE.
	bne @nthis	;NO, TRULY UNEQUAL.
@token_found:
	ora count
@getbpt:
	ldy bufptr	;GET BUFFER PNTR.
@stuffh:
	inx
	iny
	sta buf-5,y
	lda buf-5,y
	beq @crdone	;NULL IMPLIES END OF LINE.
	sec		;PREPARE TO SUBSTARCT.
	sbc #':'	;IS IT A ":"?
	beq @colis	;YES, ALLOW CRUNCHING AGAIN.
	cmp #datatk-':'	;IS IT A DATATK?
	bne @nodatt	;NO, SEE IF IT IS REM TOKEN.
@colis:
	sta dores	;SETUP FLAG.
@nodatt:
	sec		;PREP TO SBCQ
	sbc #remtk-':'	;REM ONLY STOPS ON NULL.
	bne @kloop	;NO, CONTINUE CRUNCHING.
	sta endchr	;REM STOPS ONLY ON NULL, NOT : OR ".
@str1:
	lda buf,x
	beq @stuffh	;YES, END OF LINE, SO DONE.
	cmp endchr	;END OF GOBBLE?
	beq @stuffh	;YES, DONE WITH STRING.
@strng:
	iny		;INCREMENT BUFFER POINTER.
	sta buf-5,y
	inx
	bne @str1	;PROCESS NEXT CHARACTER.

@nthis:
	ldx txtptr	;RESTORE TEXT POINTER.
	inc count	;INCREMENT RES WORD COUNT.
@nthis1:
	iny
	lda reslst-1,y	;GET RES CHARACTER.
	bpl @nthis1	;END OF ENTRY?
	lda reslst,y	;YES. IS IT THE END?
	bne @rescon	;NO, TRY THE NEXT WORD.

	; Handle extended tokens
	lda buf,x
	cmp #'r'
	bne @notrv
	lda buf+1,x
	cmp #'v'
	beq @isrv
@notrv:	
	; End extended token handling

	lda buf,x	;YES, END OF TABLE. GET 1ST CHR.
	bpl @getbpt	;STORE IT AWAY (ALWAYS BRANCHES).
@crdone:
	sta buf-3,y	;SO THAT IF THIS IS A DIR STATEMENT ITS END WILL LOOK LIKE END OF PROGRAM.
	dec txtptr+1
	lda #<(buf-1)	;MAKE TXTPTR POINT TO
	sta txtptr	;CRUNCHED LINE.
	rts		;RETURN TO CALLER.

	; Search for extended tokens
@isrv:
	ldy #0		;Load rvreslst pointer.
@rv_rescon:
	inx
	dey
@rv_reser:
	iny
	inx
	lda buf,x
	sec
	sbc rv_reslst,y	;Characters equal?
	beq @rv_reser	;Yes, continue search.
	cmp #$80	;No but maybe the end is here.
	beq @token_found

	ldx txtptr	;Restore text pointer.
	inc count	;Increment res word count.
@rv_nthis1:
	iny
	lda rv_reslst-1,y	;Get res character.
	bpl @rv_nthis1	;End of entry?
	lda rv_reslst,y	;Yes. Is it the end?
	bne @rv_rescon	;No, try the next word.
	beq @notrv



newqplop:
	bpl @ploop	;IS IT A TOKEN? NO, HEAD FOR PRINTER.
	cmp #pi
	beq @ploop
	bit dores	;INSIDE QUOTE MARKS?
	bmi @ploop	;YES, JUST TYPE THE CHARACTER.
	sec
	sbc #$7f	;GET RID OF SIGN BIT AND ADD 1.
	tax		;MAKE IT A COUNTER.
	sty lstpnt	;SAVE POINTER TO LINE.
	ldy #$ff	;LOOK AT RES'D WORD LIST.
	sbc #$4d
	bcs @rv_qplop
@resrch:
	dex		;IS THIS THE RES'D WORD?
	beq @prit3	;YES, GO TOSS IT UP..
@rescr1:
	iny
	lda reslst,y	;END OF ENTRY?
	bpl @rescr1	;NO, CONTINUE PASSING.
	bmi @resrch
@prit3:
	iny
	lda reslst,y
	bmi @prit4	;END OF RESERVED WORD.
	jsr outdo	;PRINT IT.
	bne @prit3	;END OF ENTRY? NO, TYPE REST.

@ploop:
	jmp ploop
@prit4:
	jmp prit4

	; Print extended tokens
@rv_qplop:
	pha
	lda #'r'
	jsr outdo
	lda #'v'
	jsr outdo
	pla
	tax
@rv_resrch:
	dex		;Is this the res'd word?
	bmi @rv_prit3	;Yes, go toss it up..
@rv_rescr1:
	iny
	lda rv_reslst,y	;End of entry?
	bpl @rv_rescr1	;No, continue passing.
	bmi @rv_resrch
@rv_prit3:
	iny
	lda rv_reslst,y
	bmi @prit4	;End of reserved word.
	jsr outdo	;Print it.
	bne @rv_prit3	;End of entry? No, type rest.


newgone:	
	jsr chrget
	beq @gone3
	bcc @gone3
	cmp #$cc
	bcs @mytoken
	sec
@gone3:
	jmp gone+3
@mytoken:
	cmp #$cc+num_rv_stmt
	ora #0
	bcs @gone3
	jsr jump_mytoken
	jmp newstt

jump_mytoken:	
	sbc #$cc-1
	asl
	tax
	lda rv_jumptable+1,x
	pha
	lda rv_jumptable,x
	pha
	jmp chrget


neweval:
	lda #0		;ASSUME VALUE WILL BE NUMERIC.
	sta valtyp
@eval0:
	jsr chrget	;GET A CHARACTER.
	bcs @eval2
	jmp fin         ;IT IS A NUMBER.
@eval2:
	jsr isletc	;VARIABLE NAME?
	bcs @isvar	;YES.
	cmp #pi
	bne @notpi
	jmp $ae9e
@notpi:
	cmp #plustk
	beq @eval0
	cmp #$cc
	bcs @myfun
	cmp #'$'
	beq @hexnum
	jmp qdot
@isvar:
	jmp isvar
@myfun:
	cmp #$cc+num_rv_stmt
	bcc @snerr
	cmp #$cc+num_rv_tokens
	bcc jump_mytoken
@snerr:
	jmp snerr
@hexnum:
	ldy #0		;ZERO FACSGN&SGNFLG.
	ldx #$0a	;ZERO EXP AND HO (AND MOH).
@finzlp:
	sty deccnt,x	;ZERO MO AND LO.
	dex		;ZERO TENEXP AND EXPSGN
	bpl @finzlp	;ZERO DECCNT, DPTFLG.
	jsr chrget
	bcc @findig
	sbc #'a'
	bcc @snerr
	cmp #6
	bcs @snerr
@xdig:
	adc #10
@findig:
	tax
	lda facexp
	beq @noexp
	clc
	adc #4
	bcs @overflow
	sta facexp
@noexp:	
	txa
	and #$0f
	jsr finlog
	jsr chrget
	bcc @findig
	sbc #'a'
	bcc @fine
	cmp #6
	bcc @xdig
@fine:
	rts

@overflow:
	jmp overr

	
rv_reslst:
	.byte "hel",'p'+$80
	.byte "ter",'m'+$80
	.byte "pok",'e'+$80
	.byte "stas",'h'+$80
	.byte "fetc",'h'+$80
	.byte "swa",'p'+$80
	.byte "sy",'s'+$80
	.byte "pee",'k'+$80
	.byte 0

rv_jumptable:
	.word rvhelp-1
	.word rvterm_stub-1
	.word rvpoke-1
	.word rvstash-1
	.word rvfetch-1
	.word rvswap-1
	.word rvsys-1
num_rv_stmt = (* - rv_jumptable)/2
rv_jumptable_funcs:
	.word rvpeek-1
num_rv_func = (* - rv_jumptable_funcs)/2
num_rv_tokens = (* - rv_jumptable)/2
		

syntax_error:
	rts

rvterm_stub:
	bne syntax_error
	jmp rvterm

rvhelp:
	bne syntax_error
	lda #<help_message
	ldy #>help_message
	jsr $ab1e
	lda #<help_message_part_2
	ldy #>help_message_part_2
	jmp $ab1e

help_message:
	.byte $93,"rvcop64 extended basic commands:", $0d, $0d
	.byte "rvhelp - display this screen", $0d
	.byte "rvterm - vuart terminal emulator", $0d
	.byte "rvpoke addr,byte,... - write rv memory", $0d
	.byte "?rvpeek(addr) - read rv memory", $0d
	.byte "rvstash cnt,intsa,extsa - copy to rvm", $0d
	.byte "rvfetch cnt,intsa,extsa - copy from rvm", $0d, 0
help_message_part_2:
	.byte "rvswap cnt,intsa,extsa - exchange rvm", $0d
	.byte "rvsys addr - set rv pc", $0d
	.byte $0d, 0
	

rvfetch:
	jsr getstashparm
	lda #$cc
	sta rvmem_cmd
	ldy #0
	ldx lstpnt
	beq @just_dex
	dex
	bne @just_inc
	lda lstpnt+1
	bne @next
	beq @fetchlast
@just_inc:
	inc lstpnt+1
	.byte $24 ; bit zp
@just_dex:
	dex
@next:	
	bit rvmem_cmd
	bmi @next
	lda rvmem_data
	sta (poker),y
	iny
	bne @skip1
	inc poker+1
@skip1:	
	dex
	bne @next
	dec lstpnt+1
	bne @next
@fetchlast:
	bit rvmem_cmd
	bmi @fetchlast
	stx rvmem_cmd
	lda rvmem_data
	sta (poker),y
	rts	

rvswap:
	jsr getstashparm
	ldy #0
	ldx lstpnt
	beq @next
	inc lstpnt+1
@next:
	lda #$43
	sta rvmem_cmd
@wait1:
	bit rvmem_cmd
	bmi @wait1
	lda rvmem_data
	pha
	lda (poker),y
	sta rvmem_data
	pla
	sta (poker),y
	iny
	bne @wait2
	inc poker+1
@wait2:
	bit rvmem_cmd
	bmi @wait2
	dex
	bne @next
	dec lstpnt+1
	bne @next
	beq rvmem_cmd_end	
	
rvstash:
	jsr getstashparm
	lda #$03
	sta rvmem_cmd
	ldy #0
	ldx lstpnt
	beq @next
	inc lstpnt+1
@next:
	lda (poker),y
	sta rvmem_data
@wait:
	bit rvmem_cmd
	bmi @wait
	iny
	bne @skip1
	inc poker+1
@skip1:	
	dex
	bne @next
	dec lstpnt+1
	bne @next
	beq rvmem_cmd_end	


rvsys:
	jsr frmnum
	jsr getuint32
	jsr rvdebug_halt
	ldx #1
	jsr rvdebug_setreg
	jsr rvdebug_jump
	jmp rvdebug_continue


rvpoke:
	jsr frmnum
	jsr getrvaddr
	lda #$03
	sta rvmem_cmd
@nextbyt:
	jsr combyt
	stx rvmem_data
@wait:
	bit rvmem_cmd
	bmi @wait
	jsr chrgot
	bne @nextbyt
rvmem_cmd_end:
	lda #0
	sta rvmem_cmd
	rts

rvpeek:
	jsr parchk
	jsr getrvaddr
	lda #$40
	sta rvmem_cmd
@wait:
	bit rvmem_cmd
	bmi @wait
	ldy rvmem_data
	jmp sngflt

getstashparm:
	jsr frmnum
	jsr getadr
	sty lstpnt
	sta lstpnt+1
	ora lstpnt
	beq gofuc
	jsr chkcom
	jsr frmnum
	jsr getadr
	jsr chkcom
	jsr frmnum
	
getrvaddr:
	jsr getuint32
	lda facho
	sta rvmem_addr+3
	lda facmoh
	sta rvmem_addr+2
	lda facmo
	sta rvmem_addr+1
	lda faclo
	sta rvmem_addr
done:
	rts

gofuc:
	jmp fcerr

getuint32:
	lda facsgn
	bmi gofuc
	lda facexp
	cmp #32+$80	; 32 bits
	beq done
	bcs gofuc
	jmp qint

