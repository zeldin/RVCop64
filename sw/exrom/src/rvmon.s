
	.import rvmem_addr, rvmem_cmd, rvmem_data
	.import rvdebug_halt, rvdebug_getreg, rvdebug_getpc, rvdebug_step

	.global rvmon

basin  = $ffcf
chrout = $ffd2
stop   = $ffe1
	
tmp1   = $49
tmp2   = $4a
tmp3   = $4b
tmp4   = $4c
tempf1 = $57
facho  = $62
facmoh = $63
facmo  = $64
faclo  = $65

buf    = $200
	

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
	rts
@notend:
	cmp #' '
	beq @oksep
	cmp #','
	beq @oksep
@operr:
	pla
	pla
	jmp synerr


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
	stx tmp1
	bcc @nextinst
	bcs @badinst
@inst16:
	lda tmp2
	jsr printhex
	lda tmp1
	jsr printhex
	jsr disinst16
	ldx #2
	stx tmp1
	bcc @nextinst
@badinst:
	ldx #unkinstr-monitor_str
	jsr monitor_print
@nextinst:
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
	
	
cmdchars:
	.byte "dmrxz"
ncmds = (* - cmdchars)
base_sign:
	.byte "$+&%"
nbases = (* - base_sign)

cmdfuncs:
	.word cmd_d-1
	.word cmd_m-1
	.word cmd_r-1
	.word cmd_x-1
	.word cmd_z-1


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


instr_str:
is_lui:	  .byte "lu",'i'+$80
is_auipc: .byte "auip",'c'+$80
is_jal:	  .byte "ja",'l'+$80
is_jalr:  .byte "jal",'r'+$80
is_beq:   .byte "be",'q'+$80
is_bne:   .byte "bn",'e'+$80
is_blt:   .byte "bl",'t'+$80
is_bge:   .byte "bg",'e'+$80
is_bltu:  .byte "blt",'u'+$80
is_bgeu:  .byte "bge",'u'+$80
is_lb:    .byte "l",'b'+$80
is_lh:    .byte "l",'h'+$80
is_lw:    .byte "l",'w'+$80
is_lbu:   .byte "lb",'u'+$80
is_lhu:   .byte "lh",'u'+$80
is_sb:    .byte "s",'b'+$80
is_sh:    .byte "s",'h'+$80
is_sw:    .byte "s",'w'+$80
is_addi:  .byte "add",'i'+$80
is_slti:  .byte "slt",'i'+$80
is_sltiu: .byte "slti",'u'+$80
is_xori:  .byte "xor",'i'+$80
is_ori:   .byte "or",'i'+$80
is_andi:  .byte "and",'i'+$80
is_slli:  .byte "sll",'i'+$80
is_srli:  .byte "srl",'i'+$80
is_srai:  .byte "sra",'i'+$80
is_add:	  .byte "ad",'d'+$80
is_sub:	  .byte "su",'b'+$80
is_sll:	  .byte "sl",'l'+$80
is_slt:	  .byte "sl",'t'+$80
is_sltu:  .byte "slt",'u'+$80
is_xor:	  .byte "xo",'r'+$80
is_srl:	  .byte "sr",'l'+$80
is_sra:	  .byte "sr",'a'+$80
is_or:	  .byte "o",'r'+$80
is_and:	  .byte "an",'d'+$80
is_fence: .byte "fenc",'e'+$80
is_fencei:.byte "fence.",'i'+$80
is_ecall: .byte "ecal",'l'+$80
is_ebreak:.byte "ebrea",'k'+$80
is_sret:  .byte "sre",'t'+$80
is_wfi:   .byte "wf",'i'+$80
is_mret:  .byte "mre",'t'+$80
is_csrrw: .byte "csrr",'w'+$80
is_csrrs: .byte "csrr",'s'+$80
is_csrrc: .byte "csrr",'c'+$80
is_csrrwi:.byte "csrrw",'i'+$80
is_csrrsi:.byte "csrrs",'i'+$80
is_csrrci:.byte "csrrc",'i'+$80
is_mul:   .byte "mu",'l'+$80
is_mulh:  .byte "mul",'h'+$80
is_mulhsu:.byte "mulhs",'u'+$80
is_mulhu: .byte "mulh",'u'+$80
is_div:   .byte "di",'v'+$80
is_divu:  .byte "div",'u'+$80
is_rem:   .byte "re",'m'+$80
is_remu:  .byte "rem",'u'+$80


sysinstr_hipat:
	.byte $00,$00,$10,$10,$30
sysinstr_lopat:
	.byte $00,$10,$20,$50,$20

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



getbyte:
	lda #$c0
	sta rvmem_cmd
@wait:
	bit rvmem_cmd
	bmi @wait
	lda rvmem_data
	rts

