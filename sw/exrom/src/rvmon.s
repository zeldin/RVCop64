
	.import rvmem_addr, rvmem_cmd, rvmem_data
	.import rvdebug_halt, rvdebug_getreg, rvdebug_getpc, rvdebug_step
	.import rvdebug_setreg, rvdebug_jump, rvdebug_continue
	.import rvdebug_flush_caches, rvdebug_check_halted

	.global rvmon

basin  = $ffcf
chrout = $ffd2
stop   = $ffe1

tmp1   = $49
tmp2   = $4a
tmp3   = $4b
tmp4   = $4c
tmp5   = $4d
tempf1 = $57
facho  = $62
facmoh = $63
facmo  = $64
faclo  = $65
ndx    = $c6
pnt    = $d1
pntr   = $d3
lnmx   = $d5

buf    = $200
keyd   = $277


	.code

rvmon:
	ldx #0
	stx rvmem_addr
	stx rvmem_addr+1
	stx rvmem_addr+2
	lda #$70
	sta rvmem_addr+3
	jsr monitor_print
	jmp cmd_r

base_cmd:
	dex
	jsr getop
	ldx #0
	jsr printbasedcrspc
	ldx #1
	jsr printbasedcrspc
	ldx #2
	jsr printbasedcrspc
	ldx #3
	jsr printbasedcrspc
	jmp readline
	
synerr:
	ldx #errmsg-monitor_str
	jsr monitor_print
readline:
	lda #$0d
	jsr chrout
readline_no_cr:
	ldx #0
@nextchr:
	jsr basin
	sta buf,x
	inx
	cpx #$59
	bcs synerr
	cmp #$0d
	bne @nextchr
	lda #0
	sta buf-1,x
	tax
@first_char:
	jsr get_cmd_char
	beq readline
	cmp #' '
	beq @first_char
	ldy #ncmds+nbases-1
@searchcmd:
	cmp cmdchars,y
	beq @foundcmd
	dey
	bpl @searchcmd
	bmi synerr
@foundcmd:
	cpy #ncmds
	bcs base_cmd
	tya
	asl
	tay
	lda cmdfuncs+1,y
	pha
	lda cmdfuncs,y
	pha

getop:
	jsr getop_low
	pla
	pla
	jmp synerr

getop_safe:
	jsr getop_low
	sec
	rts

getop_safe_paren:
	jsr getop_low
	bcs @done
	dex
	cmp #'('
	clc
	beq @done
	sec
@done:
	rts

getop_low:
	jsr getval
	bcs @operr
	jsr got_cmd_char
	bne @notend
	dex
	sec
	lda tmp1
	beq @nonum
@oksep:
	clc
@nonum:
	pla
	pla
	rts
@notend:
	cmp #' '
	beq @oksep
	cmp #','
	beq @oksep
	clc
@operr:
	rts


cmd_d:
	bcs @noarg
	jsr addr_from_arg
	jsr getop
	bcs @noarg
	jsr arg_minus_addr
	bcs cmd_d_core
	jmp synerr
@noarg:	
	lda #29
	sta faclo
cmd_d_core:
	inc facmo
	inc facmoh
	inc facho
@d_loop:
	jsr stop
	beq @d_done
	lda #$0d
	jsr chrout
	lda #'.'
	jsr chrout
	jsr printaddr
	lda #' '
	jsr chrout
	jsr disinst
	stx tmp1
	sec
	lda faclo
	sbc tmp1
	sta faclo
	bcs @d_loop
	dec facmo
	bne @d_loop
	dec facmoh
	bne @d_loop
	dec facho
	bne @d_loop
@d_done:
	jmp readline


cmd_f:
	jsr getrangeand3rd
	bcc @ok
	jmp synerr
@ok:	
	lda faclo
@f_loop:
	jsr putbyte
	dec tempf1+4
	bne @f_loop
	dec tempf1+3
	bne @f_loop
	dec tempf1+2
	bne @f_loop
	dec tempf1+1
	bne @f_loop
	jmp readline


cmd_t:
	jsr getrangeand3rd
	bcc @t_loop
	jmp synerr
@t_loop:
	jsr getbyte
	jsr swap_addr_and_arg
	jsr putbyte
	jsr swap_addr_and_arg
	dec tempf1+4
	bne @t_loop
	dec tempf1+3
	bne @t_loop
	dec tempf1+2
	bne @t_loop
	dec tempf1+1
	bne @t_loop
	jmp readline

	
cmd_c:
	jsr getrangeand3rd
	bcc @c_start
	jmp synerr
@c_start:
	lda #$0d
	jsr chrout
@c_loop:
	jsr stop
	beq @c_done
	jsr getbyte_noinc
	sta tmp1
	jsr swap_addr_and_arg
	jsr getbyte
	jsr swap_addr_and_arg
	cmp tmp1
	beq @same
	jsr printaddr
	lda #' '
	jsr chrout
	jsr chrout
@same:
	jsr incaddr
	dec tempf1+4
	bne @c_loop
	dec tempf1+3
	bne @c_loop
	dec tempf1+2
	bne @c_loop
	dec tempf1+1
	bne @c_loop
@c_done:
	jmp readline


cmd_h:
	jsr getrange
	bcc @h_getdata
@synerr:
	jmp synerr
@h_getdata:
	ldy #0
	jsr get_cmd_char
	cmp #$27
	beq @h_string
	dex
	sty tmp5
	jsr getop
	bcs @synerr
@moreops:
	ldy tmp5
	lda faclo
	sta buf,y
	iny
	sty tmp5
	jsr getop
	bcc @moreops
	bcs @h_gotdata
@h_string:
	jsr get_cmd_char
	cmp #0
	beq @synerr
@morestr:
	sta buf,y
	iny
	jsr get_cmd_char
	bne @morestr
	sty tmp5
@h_gotdata:
	lda #$0d
	jsr chrout
@h_loop:
	jsr stop
	beq @h_done
	jsr getbyte_noinc
	cmp buf
	bne @nomatch
	jsr addr_to_arg
	ldy #0
@h_compare:
	jsr getbyte
	cmp buf,y
	bne @badmatch
	iny
	cpy tmp5
	bne @h_compare
@badmatch:
	jsr addr_from_arg
	cpy tmp5
	bne @nomatch
	jsr printaddr
	lda #' '
	jsr chrout
	jsr chrout
@nomatch:
	jsr incaddr
	dec tempf1+4
	bne @h_loop
	dec tempf1+3
	bne @h_loop
	dec tempf1+2
	bne @h_loop
	dec tempf1+1
	bne @h_loop
@h_done:
	jmp readline


cmd_m:
	bcs @noarg
	jsr addr_from_arg
	jsr getop
	bcs @noarg
	jsr arg_minus_addr
	bcs @noerr
	jmp synerr
@noarg:	
	lda #95
	sta faclo
@noerr:
	ldx #3
@div:
	lsr facho
	ror facmoh
	ror facmo
	ror faclo
	dex
	bne @div
	inc faclo
	inc facmo
	inc facmoh
	inc facho
@m_loop:
	jsr stop
	beq @m_done
	ldx #0
	lda #$0d
	jsr chrout
	lda #'>'
	jsr chrout
	jsr printaddr
@nohdr:
	lda #' '
	jsr chrout
	jsr getbyte
	jsr printhex
	inx
	cpx #8
	bne @nohdr
	dec faclo
	bne @m_loop
	dec facmo
	bne @m_loop
	dec facmoh
	bne @m_loop
	dec facho
	bne @m_loop
@m_done:
	jmp readline

cmd_r:
	jsr rvdebug_halt
	ldx #reg_header-monitor_str
	jsr monitor_print
	ldx #0
@r_loop:
	txa
	and #3
	bne @nohdr
	lda #$0d
	jsr chrout
	lda #';'
	jsr chrout
	txa
	jsr printdec5_2dig
@nohdr:
	lda #' '
	jsr chrout
	jsr @getreg
	jsr printhex32
	inx
	cpx #32
	bne @r_loop
	jmp readline

@getreg:
	txa
	beq @getpc
	jmp rvdebug_getreg
@getpc:
	jmp rvdebug_getpc


cmd_j:
	jsr rvdebug_flush_caches
	bcs @synerr
	ldx #1
	jsr rvdebug_setreg
	jsr rvdebug_jump
	lda #0
	sta facho
	sta facmoh
	lda #>ebreak_instr
	sta facmo
	lda #<ebreak_instr
	sta faclo
	ldx #1
	jsr rvdebug_setreg
	jsr rvdebug_continue
@wait_ebreak:
	jsr stop
	beq @j_done
	jsr rvdebug_check_halted
	beq @wait_ebreak
@j_done:
	jsr rvdebug_halt
	jmp readline
@synerr:
	jmp synerr


cmd_g:
	jsr rvdebug_flush_caches
	bcs @noarg
	jsr addr_from_arg
	ldx #5
	jsr rvdebug_getreg
	jsr savefac
	lda rvmem_addr
	sta faclo
	lda rvmem_addr+1
	sta facmo
	lda rvmem_addr+2
	sta facmoh
	lda rvmem_addr+3
	sta facho
	ldx #5
	jsr rvdebug_setreg
	jsr rvdebug_jump
	jsr restorefac
	jsr rvdebug_setreg
@noarg:
	jsr rvdebug_continue


cmd_x:
	jmp ($a002)


cmd_z:
	bcc @yesarg
	inc faclo
@yesarg:
	lda faclo
	bne @inc1
	lda facmo
	bne @inc2
	lda facmoh
	bne @inc3
	lda facho
	bne @z_loop
	jmp synerr
@inc1:
	inc facmo
@inc2:
	inc facmoh
@inc3:
	inc facho
@z_loop:
	jsr rvdebug_step
	dec faclo
	bne @z_loop
	dec facmo
	bne @z_loop
	dec facmoh
	bne @z_loop
	dec facho
	bne @z_loop
	jsr rvdebug_getpc
	jsr addr_from_arg
	jsr clrarg
	jmp cmd_d_core


cmd_greaterthan:
	bcs @noarg
	jsr addr_from_arg
	jsr getop
	bcc @yesarg
@noarg:
	jmp readline
@okarg:
	lda faclo
	jsr putbyte
	jsr getop
	bcs @noarg
@yesarg:
	lda facmo
	ora facmoh
	ora facho
	beq @okarg
	jmp synerr


cmd_semicolon:	
	bcs @noarg
	jsr arg_to_reg
	bcs @badreg
	cmp #0
	beq @setpc
	sta tempf1+1
@nextreg:
	jsr getop
	bcs @noarg
	txa
	pha
	ldx tempf1+1
	cpx #32
	bcs @badreg0
@setpc_end:
	jsr rvdebug_setreg
	pla
	tax
	inc tempf1+1
	bne @nextreg
@noarg:
	jmp readline
@badreg0:
	pla
	tax
@badreg:
	jmp synerr

@setpc:
	txa
	pha
	ldx #5
	jsr rvdebug_getreg
	jsr savefac
	pla
	tax
	jsr getop
	bcs @noarg
	txa
	pha
	ldx #5
	jsr rvdebug_setreg
	jsr rvdebug_jump
	jsr restorefac
	lda #0
	sta tempf1+1
	beq @setpc_end


cmdchars:
	.byte "acdfghjmrtxz.>;"
ncmds = (* - cmdchars)
base_sign:
	.byte "$+&%"
nbases = (* - base_sign)

cmdfuncs:
	.word cmd_a-1
	.word cmd_c-1
	.word cmd_d-1
	.word cmd_f-1
	.word cmd_g-1
	.word cmd_h-1
	.word cmd_j-1
	.word cmd_m-1
	.word cmd_r-1
	.word cmd_t-1
	.word cmd_x-1
	.word cmd_z-1
	.word cmd_a-1
	.word cmd_greaterthan-1
	.word cmd_semicolon-1


disinst:
	jsr getbyte
	sta tmp1
	jsr getbyte
	sta tmp2
	lda #3
	and tmp1
	cmp #3
	bne @inst16
	jsr getbyte
	sta tmp3
	jsr getbyte
	sta tmp4
	jsr printhex
	lda tmp3
	jsr printhex
	lda tmp2
	jsr printhex
	lda tmp1
	jsr printhex
	jsr disinst32
	ldx #4
	bcs @badinst
	rts
@inst16:
	lda tmp2
	jsr printhex
	lda tmp1
	jsr printhex
	jsr disinst16
	ldx #2
	stx tmp1
	bcs @badinst
	rts

@badinst:
	ldx #unkinstr-monitor_str
	jmp monitor_print


disinst32:
	lda tmp1
	lsr
	and #$3e
	tax
	lda dis32func+1,x
	pha
	lda dis32func,x
	pha
	lda tmp2
	and #$70
	lsr
	lsr
	lsr
	lsr
	tax
	rts

dis32func:
	.word dis32load-1, dis32loadfp-1, dis32custom0-1, dis32miscmem-1
	.word dis32opimm-1, dis32auipc-1, dis32opimm32-1, dis3248b-1
	.word dis32store-1, dis32storefp-1, dis32custom1-1, dis32amo-1
	.word dis32op-1, dis32lui-1, dis32op32-1, dis3264b-1
	.word dis32madd-1, dis32msub-1, dis32nmsub-1, dis32nmadd-1
	.word dis32opfp-1, dis32rsvd-1, dis32custom2-1, dis3248b-1
	.word dis32branch-1, dis32jalr-1, dis32rsvd-1, dis32jal-1
	.word dis32system-1, dis32rsvd-1, dis32custom3-1, dis3280b-1

dis32load:
	lda loadinstr,x
	beq badinst0
	jsr printinstrspc
	jsr getrd
	jsr printregcomma
	jsr printim12
	lda #'('
	jsr chrout
	jsr getrs1
	jsr printreg
	lda #')'
	jsr chrout
	clc
	rts

dis32store:
	cpx #3
	bcs badinst0
	lda storeinstr,x
	jsr printinstrspc
	jsr getrs2
	jsr printregcomma
	lda #'$'
	jsr chrout
	lda tmp4
	and #$fe
	tax
	lda #$10
	bit tmp1
	beq @nobit4
	inx
@nobit4:
	txa
	jsr printhex
	lda tmp1
	asl
	lda tmp2
	rol
	jsr printhexnyb
	lda #'('
	jsr chrout
	jsr getrs1
	jsr printreg
	lda #')'
	jsr chrout
	clc
	rts

dis32opimm:
	cpx #1
	beq @shiftinstr
	cpx #5
	bne @notshift
	bit tmp4
	bvc @shiftinstr
	ldx #8
@shiftinstr:
	dec tmp1
@notshift:
	lda opimminstr,x
	jmp dis32itype

badinst0:
	sec
	rts

dis32jal:
	lda #is_jal-instr_str+1
	jsr printinstrspc
	jsr getrd
	jsr printregcomma
	lda tmp3
	asl
	rol tmp4
	rol
	rol tmp4
	rol
	rol tmp4
	rol
	asl tmp4
	rol
	tax
	and #7
	sta tempf1+3
	lda tmp4
	sta tempf1+4
	txa
	and #8
	beq @nonneg
	lda #$ff
@nonneg:
	sta tempf1+1
	and #$f0
	sta tempf1+2
	lda tmp3
	tax
	and #$0f
	ora tempf1+2
	sta tempf1+2
	txa
	and #$10
	lsr
	ora tempf1+3
	sta tempf1+3
	lda tmp2
	and #$f0
	ora tempf1+3
	sta tempf1+3
	jmp printreladdr

dis32system:
	bne dis32csr
	ldx #numsysinstr-1
@findsys:
	lda tmp4
	cmp sysinstr_hipat,x
	bne @nomatch
	lda tmp3
	and #$f0
	cmp sysinstr_lopat,x
	beq @sysmatch
@nomatch:
	dex
	bpl @findsys
	bmi badinst0
@sysmatch:
	lda sysinstr,x
disnoarg:
	jsr printinstr
	clc
	rts

dis32miscmem:
	cpx #2
	bcs badinst0
	lda mminstr,x
	bne disnoarg

dis32csr:
	lda csrinstr-1,x
	beq badinst0
	jsr printinstrspc
	jsr getrd
	jsr printregcomma
	jsr printim12
	jsr printcomma
	jsr getrs1
	bit tmp2
	bvc @isrs1
	pha
	lda #'$'
	jsr chrout
	pla
	jmp printhex
@isrs1:
	jmp printreg
	
dis32auipc:
	lda #is_auipc-instr_str+1
	bne dis32utype
dis32lui:
	lda #is_lui-instr_str+1
dis32utype:
	jsr printinstrspc
	jsr getrd
	jsr printregcomma
	jsr printtopim
	lda tmp3
	jsr printhex
	lda tmp2
	jmp printhighnyb

dis32op:
	lda #2
	bit tmp4
	beq @notmultop
	lda multinstr,x
	bne @multop
@notmultop:
	cpx #0
	beq @maybealt
	cpx #5
	bne @notalt
@maybealt:
	bit tmp4
	bvc @notalt
	txa
	and #1
	ora #8
	tax
@notalt:
	lda opinstr,x
@multop:
	jsr printinstrspc
	jsr getrd
	jsr printregcomma
	jsr getrs1
	jsr printregcomma
	jsr getrs2
	jmp printreg


dis32branch:
	lda branchinstr,x
	beq badinst
	jsr printinstrspc
	jsr getrs1
	jsr printregcomma
	jsr getrs2
	jsr printregcomma
	ldx #0
	lda tmp4
	asl
	bcc @nonneg
	dex
@nonneg:
	stx tempf1+1
	stx tempf1+2
	stx tempf1+3
	asl tmp1
	rol tempf1+3
	asl
	rol tempf1+3
	asl
	rol tempf1+3
	asl
	rol tempf1+3
	and #$e0
	sta tempf1+4
	lda tmp2
	asl
	and #$1e
	ora tempf1+4
	sta tempf1+4
	jmp printreladdr

disinst16:
	lda #' '
	jsr chrout	
	jsr chrout	
	jsr chrout	
	jsr chrout	

dis32loadfp:
dis32opimm32:
dis32storefp:
dis32amo:
dis32op32:
dis32madd:
dis32msub:
dis32nmsub:
dis32nmadd:
dis32opfp:
dis32custom0:
dis32custom1:
dis32custom2:
dis32custom3:
dis32rsvd:
dis3248b:
dis3264b:
dis3280b:
badinst:
	sec
	rts

dis32jalr:
	lda #is_jalr-instr_str+1
dis32itype:
	beq badinst
	jsr printinstrspc
	jsr getrd
	jsr printregcomma
	jsr getrs1
	jsr printregcomma
	lsr tmp1
	bcs @notshamt
	lda #'$'
	jsr chrout
	lsr tmp4
	lda tmp3
	ror
	lsr
	lsr
	lsr
	jmp printhex
@notshamt:
	jmp printim12



cmd_a:
	bcs @synerr
	jsr addr_from_arg
@scan:
	jsr get_cmd_char
	beq @a_done
	cmp #' '
	beq @scan
	dex
@look_for_op:
	jsr get_cmd_char
	beq @synerr
	cmp #' '
	beq @look_for_op
	dex
	stx tmp5
	ldy #0
	beq @compare_op
@compare_loop:
	iny
	inx
@compare_op:
	lda buf,x
	sec
	sbc instr_str,y
	beq @compare_loop
	cmp #$80
	beq @found
	ldx tmp5
@skip_op:
	iny
	lda instr_str-1,y
	bpl @skip_op
	cpy #n_instr_str
	bcc @compare_op
	jsr getop
	bcc @look_for_op
@synerr:
	jmp synerr
@a_done:
	jmp readline

@found:
	inx
@to_instr_start:
	lda instr_str-1,y
	bmi @at_instr_start
	dey
	bne @to_instr_start
@at_instr_start:
	iny
	tya
	ldy #n_all_instr
@look_for_instr:
	cmp all_instr-1,y
	beq @instr_found
	dey
	bne @look_for_instr
	beq @synerr
@instr_found:
	lda #0
	sta tempf1+3
	sta tempf1+4
	dey
	cpy #mminstr-all_instr
	bcs @upper_instr
	cpy #storeinstr-all_instr
	bcs @store_or_opimm
	cpy #branchinstr-all_instr
	bcs @branch_or_load
	cpy #nofuncinstr-all_instr
	bcs @ass_nofuncinstr
	lda #((%1110011<<1)&$f8)
	jsr init_instr
	lda sysinstr_hipat,y
	sta tempf1+4
	lda sysinstr_lopat,y
	sta tempf1+3
	jmp @ass_noarg
@branch_or_load:
	tya
	sbc #loadinstr-all_instr
	bcs @ass_loadinstr
	adc #loadinstr-branchinstr+(((%1100011)<<1)&$f8)
	jmp @ass_b_type
@ass_loadinstr:
	ora #((%0000011<<1)&$f8)
	jmp @ass_i_type_load
@store_or_opimm:
	tya
	sbc #opimminstr-all_instr
	bcs @ass_opimminstr
	adc #opimminstr-storeinstr+((%0100011<<1)&$f8)
	jmp @ass_s_type
@ass_opimminstr:
	cmp #8
	bcc @not_srai
	lda #$40
	sta tempf1+4
	lda #((%0010011<<1)&$f8)+5
	bcs @ass_shiftimm
@not_srai:
	ora #((%0010011<<1)&$f8)
	cmp #((%0010011<<1)&$f8)+1
	beq @ass_shiftimm
	cmp #((%0010011<<1)&$f8)+5
	bne @ass_normalimm
@ass_shiftimm:
	jmp @ass_i_type_shift
@ass_normalimm:
	jmp @ass_i_type
@ass_nofuncinstr:
	tya
	sbc #nofuncinstr-all_instr
	beq @ass_lui
	tay
	dey
	beq @ass_auipc
	dey
	beq @ass_jal
@ass_jalr:
	lda #((%1100111<<1)&$f8)
	jmp @ass_i_type_load
@ass_jal:
	lda #((%1101111<<1)&$f8)
	jmp @ass_j_type
@ass_auipc:
	lda #((%0010111<<1)&$f8)
	.byte $2c ; bit abs
@ass_lui:
	lda #((%0110111<<1)&$f8)
	jmp @ass_u_type
@upper_instr:
	cpy #multinstr-all_instr
	bcs @mult_or_op
	tya
	sbc #csrinstr-all_instr-1
	bcs @ass_csrinstr
	adc #csrinstr-mminstr
	bne @notfence
	ldy #$0f
	sty tempf1+4
	ldy #$f0
	sty tempf1+3
@notfence:
	ora #((%0001111<<1)&$f8)
	jsr init_instr
	jmp @ass_noarg
@ass_csrinstr:
	adc #((%1110011<<1)&$f8)
	jsr init_instr
	jsr @ass_rd
	jsr @getimm12
	jsr @putimm12
	bit tempf1+2
	bvs @ass_csri
	jsr @ass_rs1
	jmp @ass_noarg
@ass_csri:
	jsr @getimm12
	lda facmo
	bne @synerr_csr
	lda faclo
	cmp #$20
	bcs @synerr_csr
	jsr @ass_put_rs1
	jmp @ass_noarg
@synerr_csr:
	jmp synerr
@mult_or_op:
	tya
	sbc #opinstr-all_instr
	bcs @ass_opinstr
	adc #opinstr-multinstr+((%0110011<<1)&$f8)
	inc tempf1+4
	inc tempf1+4
	bne @ass_multinst
@ass_opinstr:
	cmp #8
	bcc @ass_op_notalt
	beq @ass_sub
	lda #5
@ass_sub:
	and #$7
	ror tempf1+4
	lsr tempf1+4
@ass_op_notalt:
	ora #((%0110011<<1)&$f8)
@ass_multinst:
	jmp @ass_r_type



@ass_u_type:
	jsr init_instr
	jsr @ass_rd
	jsr getop_safe
	bcs @synerr_j
	lda facho
	bne @synerr_j
	lda facmoh
	cmp #$10
	bcs @synerr_j
	asl faclo
	rol facmo
	rol
	asl faclo
	rol facmo
	rol
	asl faclo
	rol facmo
	rol
	asl faclo
	rol facmo
	rol
	sta tempf1+4
	lda facmo
	sta tempf1+3
	lda faclo
	ora tempf1+2
	sta tempf1+2
	jmp @ass_noarg

@ass_j_type:
	jsr init_instr
	jsr @ass_rd
	jsr @ass_reladdr
	lda facmoh
	bmi @negjump
	cmp #$10
	bcs @synerr_j
	ldy facho
	beq @j_ok
@synerr_j:
	jmp synerr
@negjump:
	cmp #$f0
	bcc @synerr_j
	inc facho
	bne @synerr_j
@j_ok:
	and #$0f
	sta tempf1+3
	lda facmo
	and #$f0
	ora tempf1+2
	sta tempf1+2
	lsr faclo
	bcs @synerr_j
	lda facmo
	and #$0f
	cmp #8
	rol faclo
	asl faclo
	rol
	asl faclo
	rol
	asl faclo
	rol
	asl faclo
	rol
	asl
	sta tempf1+4
	lda facmoh
	and #$10
	cmp #$10
	ror tempf1+4
	lda faclo
	ora tempf1+3
	sta tempf1+3
	jmp @ass_noarg
	
@ass_s_type:
	jsr init_instr
	jsr @ass_rs2
	jsr @getimm12_paren
	asl tempf1+1
	lda faclo
	lsr
	ror tempf1+1
	and #$0f
	ora tempf1+2
	sta tempf1+2
	lda facmo
	asl faclo
	rol
	asl faclo
	rol
	asl faclo
	rol
	lsr tempf1+4
	rol
	sta tempf1+4
	jsr @ass_rs1_paren
	jmp @ass_noarg

@ass_i_type_load:
	jsr init_instr
	jsr @ass_rd
	jsr @getimm12_paren
	jsr @putimm12
	jsr @ass_rs1_paren
	jmp @ass_noarg	
@ass_i_type_shift:
	jsr init_instr
	jsr @ass_rd
	jsr @ass_rs1
	jsr getop_safe
	bcs @synerr_b
	lda facho
	ora facmoh
	ora facmo
	bne @synerr_b
	lda faclo
	cmp #32
	bcc @ass_i_common
	bcs @synerr_b
@ass_i_type:
	jsr init_instr
	jsr @ass_rd
	jsr @ass_rs1
	jsr @getimm12
@ass_i_common:
	jsr @putimm12
	jmp @ass_noarg

@ass_b_type:
	jsr init_instr
	jsr @ass_rs1
	jsr @ass_rs2
	jsr @ass_reladdr
	lda facmo
	bmi @negbranch
	cmp #$10
	bcs @synerr_b
	lda facho
	ora facmoh
	beq @checkodd
@synerr_b:
	jmp synerr
@negbranch:
	cmp #$f0
	bcc @synerr_b
	lda #$ff
	cmp facho
	bne @synerr_b
	cmp facmoh
	bne @synerr_b
@checkodd:
	lda faclo
	lsr
	bcs @synerr_b
	and #$0f
	ora tempf1+2
	sta tempf1+2
	asl tempf1+1
	lda faclo
	and #$e0
	asl
	sta faclo
	lda facmo
	and #$1f
	ora faclo
	ror
	ror
	ror
	ror
	ror tempf1+1
	sta facmo
	ror
	lda facmo
	ror
	ora tempf1+4
	sta tempf1+4
	jmp @ass_noarg

@ass_r_type:
	jsr init_instr
	jsr @ass_rd
	jsr @ass_rs1
	jsr @ass_rs2

@ass_noarg:
	jsr get_cmd_char
	beq @instr_done
	cmp #' '
	beq @ass_noarg
@synerr2:
	jmp synerr
@instr_done:
	jsr addr_to_arg
	lda tempf1+1
	jsr putbyte
	lda tempf1+2
	jsr putbyte
	lda tempf1+3
	jsr putbyte
	lda tempf1+4
	jsr putbyte
	jsr addr_from_arg
	ldy lnmx
	lda #' '
@clrline:
	sta (pnt),y
	dey
	bpl @clrline
	iny
	sty pntr
	jsr @printa
	jsr disinst
	lda #$0d
	jsr chrout
	jsr @printa
	lda #$91 ; use crsr-up+down to force basin to read whole line
	sta keyd
	lda #$11
	sta keyd+1
	lda #2
	sta ndx
	jmp readline_no_cr

@printa:
	lda #'a'
	jsr chrout
	jsr printaddr
	lda #' '
	jmp chrout

@putimm12:
	lda faclo
	asl
	rol facmo
	asl
	rol facmo
	asl
	rol facmo
	asl
	rol facmo
	ora tempf1+3
	sta tempf1+3
	lda facmo
	ora tempf1+4
	sta tempf1+4
	rts

@ass_reladdr:
	jsr getop_safe
	bcs @ass_fail
	sec
	lda faclo
	sbc rvmem_addr
	sta faclo
	lda facmo
	sbc rvmem_addr+1
	sta facmo
	lda facmoh
	sbc rvmem_addr+2
	sta facmoh
	lda facho
	sbc rvmem_addr+3
	sta facho
	clc
	rts

@getimm12_paren:
	jsr getop_safe_paren
	jmp @getimm12_common
@getimm12:
	jsr getop_safe
@getimm12_common:
	bcs @ass_fail
	lda facho
	bmi @negi
	ora facmoh
	bne @ass_fail
	lda facmo
	cmp #$10
	bcs @ass_fail
	rts
@negi:
	lda #$ff
	cmp facho
	bne @ass_fail
	cmp facmoh
	bne @ass_fail
	lda facmo
	cmp #$f8
	bcc @ass_fail
	rts
	
@ass_fail:
	pla
	pla
	jmp synerr
	
@ass_rd:
	jsr ass_reg
	bcs @ass_fail
	lsr
	ora tempf1+2
	sta tempf1+2
	lda #0
	ror
	ora tempf1+1
	sta tempf1+1
	rts

@ass_rs1_paren:
	jsr ass_reg_paren
	jmp @ass_rs1_common
@ass_rs1:
	jsr ass_reg
@ass_rs1_common:
	bcs @ass_fail
@ass_put_rs1:
	lsr
	ora tempf1+3
	sta tempf1+3
	lda #0
	ror
	ora tempf1+2
	sta tempf1+2
	rts

@ass_rs2:
	jsr ass_reg
	bcs @ass_fail
	asl
	asl
	asl
	asl
	ora tempf1+3
	sta tempf1+3
	lda #0
	rol
	ora tempf1+4
	sta tempf1+4
	rts

init_instr:
	sta tempf1+2
	lsr
	ora #3
	sta tempf1+1
	lda #7
	and tempf1+2
	asl
	asl
	asl
	asl
	sta tempf1+2
	rts

ass_reg_paren:
	jsr got_cmd_char
	beq @bad
	cmp #','
	beq @bad
	txa
	pha
@loop1:
	jsr get_cmd_char
	cmp #' '
	beq @loop1
	cmp #'('
	bne @badx
	lda #' '
	sta buf-1,x
@loop2:
	jsr get_cmd_char
	beq @badx
	cmp #')'
	bne @loop2
	lda #' '
	sta buf-1,x
@loop3:
	jsr get_cmd_char
	beq @okx
	cmp #' '
	beq @loop3
@badx:
	pla
	tax
@bad:
	sec
	rts
@okx:
	pla
	tax

ass_reg:
	jsr get_cmd_char
	cmp #' '
	beq ass_reg
	cmp #'x'
	beq @gotx
	dex
@gotx:
	jsr getop_safe
	bcc arg_to_reg
	rts

arg_to_reg:
	lda facmo
	ora facmoh
	ora facho
	bne @badreg
	lda faclo
	and #$0f
	cmp #$0a
	bcs @badreg
	lda faclo
	cmp #$32
	bcs @badreg
	cmp #$20
	bcc @lower
	cmp #$30
	bcs @upper
	sbc #12-1
	bne @okdec
@upper:	
	sbc #18
	bne @okdec
@lower:	
	cmp #$10
	bcc @okdec
	sbc #6
@okdec:
	clc
	rts
@badreg:
	sec
	rts
	

instr_str:
is_lui:	  .byte "lu",'i'+$80
is_auipc: .byte "auip",'c'+$80
is_jalr:  .byte "jal",'r'+$80
is_jal:	  .byte "ja",'l'+$80
is_beq:   .byte "be",'q'+$80
is_bne:   .byte "bn",'e'+$80
is_bltu:  .byte "blt",'u'+$80
is_bgeu:  .byte "bge",'u'+$80
is_blt:   .byte "bl",'t'+$80
is_bge:   .byte "bg",'e'+$80
is_lbu:   .byte "lb",'u'+$80
is_lhu:   .byte "lh",'u'+$80
is_lb:    .byte "l",'b'+$80
is_lh:    .byte "l",'h'+$80
is_lw:    .byte "l",'w'+$80
is_sb:    .byte "s",'b'+$80
is_sh:    .byte "s",'h'+$80
is_sw:    .byte "s",'w'+$80
is_addi:  .byte "add",'i'+$80
is_sltiu: .byte "slti",'u'+$80
is_slti:  .byte "slt",'i'+$80
is_xori:  .byte "xor",'i'+$80
is_ori:   .byte "or",'i'+$80
is_andi:  .byte "and",'i'+$80
is_slli:  .byte "sll",'i'+$80
is_srli:  .byte "srl",'i'+$80
is_srai:  .byte "sra",'i'+$80
is_add:	  .byte "ad",'d'+$80
is_sub:	  .byte "su",'b'+$80
is_sll:	  .byte "sl",'l'+$80
is_sltu:  .byte "slt",'u'+$80
is_slt:	  .byte "sl",'t'+$80
is_xor:	  .byte "xo",'r'+$80
is_srl:	  .byte "sr",'l'+$80
is_sra:	  .byte "sr",'a'+$80
is_or:	  .byte "o",'r'+$80
is_and:	  .byte "an",'d'+$80
is_fencei:.byte "fence.",'i'+$80
is_fence: .byte "fenc",'e'+$80
is_ecall: .byte "ecal",'l'+$80
is_ebreak:.byte "ebrea",'k'+$80
is_sret:  .byte "sre",'t'+$80
is_wfi:   .byte "wf",'i'+$80
is_mret:  .byte "mre",'t'+$80
is_csrrwi:.byte "csrrw",'i'+$80
is_csrrsi:.byte "csrrs",'i'+$80
is_csrrci:.byte "csrrc",'i'+$80
is_csrrw: .byte "csrr",'w'+$80
is_csrrs: .byte "csrr",'s'+$80
is_csrrc: .byte "csrr",'c'+$80
is_mulhsu:.byte "mulhs",'u'+$80
is_mulhu: .byte "mulh",'u'+$80
is_mulh:  .byte "mul",'h'+$80
is_mul:   .byte "mu",'l'+$80
is_divu:  .byte "div",'u'+$80
is_div:   .byte "di",'v'+$80
is_remu:  .byte "rem",'u'+$80
is_rem:   .byte "re",'m'+$80
n_instr_str = (* - instr_str)


sysinstr_hipat:
	.byte $00,$00,$10,$10,$30
sysinstr_lopat:
	.byte $00,$10,$20,$50,$20

all_instr:	
	
sysinstr:
	.byte is_ecall-instr_str+1
	.byte is_ebreak-instr_str+1
	.byte is_sret-instr_str+1
	.byte is_wfi-instr_str+1
	.byte is_mret-instr_str+1
numsysinstr = (* - sysinstr)

nofuncinstr:
	.byte is_lui-instr_str+1
	.byte is_auipc-instr_str+1
	.byte is_jal-instr_str+1
	.byte is_jalr-instr_str+1

branchinstr:
	.byte is_beq-instr_str+1
	.byte is_bne-instr_str+1
	.byte 0
	.byte 0
	.byte is_blt-instr_str+1
	.byte is_bge-instr_str+1
	.byte is_bltu-instr_str+1
	.byte is_bgeu-instr_str+1

loadinstr:
	.byte is_lb-instr_str+1
	.byte is_lh-instr_str+1
	.byte is_lw-instr_str+1
	.byte 0
	.byte is_lbu-instr_str+1
	.byte is_lhu-instr_str+1
	.byte 0
	.byte 0

storeinstr:
	.byte is_sb-instr_str+1
	.byte is_sh-instr_str+1
	.byte is_sw-instr_str+1

opimminstr:
	.byte is_addi-instr_str+1
	.byte is_slli-instr_str+1
	.byte is_slti-instr_str+1
	.byte is_sltiu-instr_str+1
	.byte is_xori-instr_str+1
	.byte is_srli-instr_str+1
	.byte is_ori-instr_str+1
	.byte is_andi-instr_str+1
	.byte is_srai-instr_str+1

mminstr:
	.byte is_fence-instr_str+1
	.byte is_fencei-instr_str+1

csrinstr:
	.byte is_csrrw-instr_str+1
	.byte is_csrrs-instr_str+1
	.byte is_csrrc-instr_str+1
	.byte 0
	.byte is_csrrwi-instr_str+1
	.byte is_csrrsi-instr_str+1
	.byte is_csrrci-instr_str+1

multinstr:
	.byte is_mul-instr_str+1
	.byte is_mulh-instr_str+1
	.byte is_mulhsu-instr_str+1
	.byte is_mulhu-instr_str+1
	.byte is_div-instr_str+1
	.byte is_divu-instr_str+1
	.byte is_rem-instr_str+1
	.byte is_remu-instr_str+1

opinstr:
	.byte is_add-instr_str+1
	.byte is_sll-instr_str+1
	.byte is_slt-instr_str+1
	.byte is_sltu-instr_str+1
	.byte is_xor-instr_str+1
	.byte is_srl-instr_str+1
	.byte is_or-instr_str+1
	.byte is_and-instr_str+1
	.byte is_sub-instr_str+1
	.byte is_sra-instr_str+1

n_all_instr = (* - all_instr)

	
getrd:
	lda tmp1
	asl
	lda tmp2
	rol
	and #$1f
	rts

getrs1:
	lda tmp2
	asl
	lda tmp3
	rol
	and #$1f
	rts

getrs2:
	lda tmp4
	lsr
	lda tmp3
	ror
	lsr
	lsr
	lsr
	rts

printim12:
	jsr printtopim
	lda tmp3
printhighnyb:
	lsr
	lsr
	lsr
	lsr
	jmp printhexnyb

printtopim:
	lda #'$'
	jsr chrout
	lda tmp4
	jmp printhex

printreladdr:
	clc
	lda rvmem_addr
	adc tempf1+4
	sta tempf1+4
	lda rvmem_addr+1
	adc tempf1+3
	sta tempf1+3
	lda rvmem_addr+2
	adc tempf1+2
	sta tempf1+2
	lda rvmem_addr+3
	adc tempf1+1
	sta tempf1+1
	sec
	lda tempf1+4
	sbc #4
	sta tempf1+4
	bcs printtempf1
	lda tempf1+3
	bne @dec3
	lda tempf1+2
	bne @dec2
	dec tempf1+1
@dec2:
	dec tempf1+2
@dec3:
	dec tempf1+3
printtempf1:
	lda #'$'
	jsr chrout
	lda tempf1+1
	jsr printhex
	lda tempf1+2
	jsr printhex
	lda tempf1+3
	jsr printhex
	lda tempf1+4
	jmp printhex


printregcomma:	
	jsr printreg

printcomma:
	lda #','
	jmp chrout

printinstrspc:
	jsr printinstr
	lda #' '
	jmp chrout
	
printinstr:
	tax
	lda #' '
	jsr chrout
@printinstr:
	lda instr_str-1,x
	bmi @endinstr
	jsr chrout
	inx
	bne @printinstr
@endinstr:
	and #$7f
	jmp chrout

getval:
	jsr clrarg
	sta tmp1
@nextchr:	
	jsr get_cmd_char
	beq @endval
	cmp #' '
	beq @nextchr
	ldy #3
@searchbase:
	cmp base_sign,y
	beq @foundbase
	dey
	bpl @searchbase
	iny
	dex
@foundbase:
	sty tmp4
	jsr get_cmd_char
@nextdig:
	cmp #'a'
	bcc @dig
	sbc #'a'-10
	bcs @digdone
@dig:	
	sbc #'0'-1
	bcc @baddig
	cmp #10
	bcs @baddig
@digdone:
	ldy tmp4
	cmp base_max,y
	bcs @baddig
	pha
	lda base_shift,y
	bne @notdec
	jsr @mul5
	lda #1
@notdec:
	tay
	sty tmp1
	pla
@rotdig:
	asl faclo
	rol facmo
	rol facmoh
	rol facho
	bcs @badval
	dey
	bne @rotdig
	adc faclo
	sta faclo
	bcc @endadd
	inc facmo
	bne @endadd
	inc facmoh
	bne @endadd
	inc facho
	beq @badval
@endadd:
	jsr get_cmd_char
	bne @nextdig
	beq @endval
@baddig:
	sec
	lda tmp1
	beq @badval
@endval:
	clc
@badval:
	rts
@mul5:
	ldy facho
	lda facmoh
	sta tmp3
	lda facmo
	sta tmp2
	lda faclo
	sta tmp1
	asl
	rol facmo
	rol facmoh
	rol facho
	bcs @mul5_fail
	asl
	rol facmo
	rol facmoh
	rol facho
	bcs @mul5_fail
	sta faclo
	lda tmp1
	adc faclo
	sta faclo
	lda tmp2
	adc facmo
	sta facmo
	lda tmp3
	adc facmoh
	sta facmoh
	tya
	adc facho
	sta facho
	bcs @mul5_fail
	rts
@mul5_fail:
	pla
	pla
	pla
	rts


base_max:
	.byte 16,10,8,2
base_shift:
	.byte 4,0,3,1


clrarg:
	lda #0
	sta faclo
	sta facmo
	sta facmoh
	sta facho
	rts

addr_from_arg:	
	lda faclo
	sta rvmem_addr
	lda facmo
	sta rvmem_addr+1
	lda facmoh
	sta rvmem_addr+2
	lda facho
	sta rvmem_addr+3
	rts

addr_to_arg:
	lda rvmem_addr
	sta faclo
	lda rvmem_addr+1
	sta facmo
	lda rvmem_addr+2
	sta facmoh
	lda rvmem_addr+3
	sta facho

swap_addr_and_arg:
	ldy faclo
	ldx rvmem_addr
	stx faclo
	sty rvmem_addr
	ldy facmo
	ldx rvmem_addr+1
	stx facmo
	sty rvmem_addr+1
	ldy facmoh
	ldx rvmem_addr+2
	stx facmoh
	sty rvmem_addr+2
	ldy facho
	ldx rvmem_addr+3
	stx facho
	sty rvmem_addr+3
	rts

arg_minus_addr:
	sec
	lda faclo
	sbc rvmem_addr
	sta faclo
	lda facmo
	sbc rvmem_addr+1
	sta facmo
	lda facmoh
	sbc rvmem_addr+2
	sta facmoh
	lda facho
	sbc rvmem_addr+3
	sta facho
	rts

getrangeand3rd:	
	jsr getrange
	bcc @okrange
	rts
	@okrange:
	jmp getop_safe

getrange:	
	bcs @fail
	jsr addr_from_arg
	jsr getop_safe
	bcs @fail
	jsr arg_minus_addr
	bcc @fail
	inc faclo
	bne @inc1
	inc facmo
	bne @inc2
	inc facmoh
	bne @inc3
	inc facho
	beq @fail
@inc1:
	inc facmo
@inc2:
	inc facmoh
@inc3:
	inc facho
	clc
	jmp savefac
@fail:
	sec
	rts

printdec5_2dig:
	cmp #10
	bcs printdec5
	bcc printhex

printreg:
	tay
	lda #'x'
	jsr chrout
	tya
printdec5:
	sec
	sbc #20
	bcc @sub20
	sbc #10
	bcc @sub30
	tay
	lda #'3'
	bne @twodig
@sub30:
	adc #10
	tay
	lda #'2'
	bne @twodig
@sub20:
	adc #10
	bcs @sup10
	adc #10
	bcs @onedig
@sup10:
	tay
	lda #'1'
@twodig:
	jsr chrout
	tya
@onedig:
	ora #'0'
	jsr chrout
	clc
	rts
	
printaddr:
	lda rvmem_addr+3
	jsr printhex
	lda rvmem_addr+2
	jsr printhex
	lda rvmem_addr+1
	jsr printhex
	lda rvmem_addr
	jmp printhex

printhex32:
	lda facho
	jsr printhex
	lda facmoh
	jsr printhex
printhex16:
	lda facmo
	jsr printhex
	lda faclo
printhex:
	pha
	lsr
	lsr
	lsr
	lsr
	jsr printhexnyb
	pla
printhexnyb:	
	and #$0f
	cmp #10
	bcc @less10
	adc #'a'-'0'-10-1
@less10:
	adc #'0'
	jsr chrout
	clc
	rts
	
		
	;; tmp1 = denominator, 1-128
divmod:
	ldy #32
	lda #0
@divmodloop:
	asl faclo
	rol facmo
	rol facmoh
	rol facho
	rol
	cmp tmp1
	bcc @less
	sbc tmp1
	inc faclo
@less:
	dey
	bne @divmodloop
	rts	

printbasedcrspc:
	lda #$0d
	jsr chrout
printbasedspc:
	lda #' '
	jsr chrout
printbased:
	lda base_sign,x
	jsr chrout
printbasednosign:	
	jsr savefac
	lda base_max,x
	sta tmp1
	ldx #39
@nextdig:
	jsr divmod
	cmp #10
	bcc @dig10
	adc #'a'-'0'-10-1
@dig10:	
	adc #'0'
	sta buf,x
	lda facho
	ora facmoh
	ora facmo
	ora faclo
	beq @endnum
	dex
	bpl @nextdig
@nextout:
	inx
@endnum:
	lda buf,x
	jsr chrout
	cpx #39
	bcc @nextout
	
restorefac:
	lda tempf1+1
	sta facho
	lda tempf1+2
	sta facmoh
	lda tempf1+3
	sta facmo
	lda tempf1+4
	sta faclo
	rts

savefac:
	lda facho
	sta tempf1+1
	lda facmoh
	sta tempf1+2
	lda facmo
	sta tempf1+3
	lda faclo
	sta tempf1+4
	rts

	
get_cmd_char:
	inx
got_cmd_char:
	lda buf-1,x
	beq @endchr
	cmp #':'
	beq @endchr
	cmp #'?'
	beq @endchr
@endchr:
	rts

monitor_print:
@printmsg:	
	lda monitor_str,x
	beq @endmsg
	jsr chrout
	inx
	bne @printmsg
@endmsg:
	rts

monitor_str:
	.byte $0d,"monitor",0
errmsg:
	.byte $9d, '?', 0
reg_header:
	.byte $0d,"    pc       x1       x2       x3",0
unkinstr:
	.byte " ???",0



getbyte_noinc:
	lda #$40
	.byte $2c ; bit abs
getbyte:
	lda #$c0
	sta rvmem_cmd
@wait:
	bit rvmem_cmd
	bmi @wait
	lda rvmem_data
	rts

putbyte:
	ldy #$03
	sty rvmem_cmd
	sta rvmem_data
@wait:
	bit rvmem_cmd
	bmi @wait
	rts

incaddr:
	lda #$80
	sta rvmem_cmd
	rts

	.align 4
ebreak_instr:	
	.byte $73,$00,$10,$00
