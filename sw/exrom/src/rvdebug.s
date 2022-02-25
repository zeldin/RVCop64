
	.global rvdebug_halt, rvdebug_continue
	.global rvdebug_setreg, rvdebug_getreg, rvdebug_jump


rvdebug_status = $de30
rvdebug_set    = $de32
rvdebug_clear  = $de33
rvdebug_instr  = $de34 ; ...$de37
rvdebug_regval = $de34 ; ...$de37


tmp1   = $49
tmp2   = $4a
facho  = $62
facmoh = $63
facmo  = $64
faclo  = $65


rvdebug_halt:
	lda #2
	sta rvdebug_set
@waithalt:
	bit rvdebug_status
	beq @waithalt
	rts


rvdebug_continue:
	lda #2
	sta rvdebug_clear
	rts


	;; X = register number
	;; FAC = value to write
rvdebug_setreg:
	txa
	lsr
	sta tmp1
	lda #$37*2   ; lui
	ror
	sta rvdebug_instr
	lda facmo
	sta tmp2
	and #$08
	adc facmo
	and #$f0
	ora tmp1
	sta rvdebug_instr+1
	lda #0
	adc facmoh
	sta rvdebug_instr+2
	lda #0
	adc facho
	sta rvdebug_instr+3
	txa
	lsr
	lda #$13*2    ; addi
	ror
	sta rvdebug_instr
	txa
	lsr
	txa
	ror
	sta rvdebug_instr+1
	lda faclo
	asl
	rol tmp2
	asl
	rol tmp2
	asl
	rol tmp2
	asl
	rol tmp2
	ora tmp1
	sta rvdebug_instr+2
	lda tmp2
	sta rvdebug_instr+3
	rts


	;; X = register number
	;; FAC <- read value is put here
rvdebug_getreg:
	lda #$13     ; addi
	jsr getreg_sub
	lda rvdebug_regval
	sta faclo
	lda rvdebug_regval+1
	sta facmo
	lda rvdebug_regval+2
	sta facmoh
	lda rvdebug_regval+3
	sta facho
	rts


	;; X = register number
rvdebug_jump:
	lda #$67     ; jalr
getreg_sub:
	sta rvdebug_instr
	txa
	lsr
	sta tmp1
	lda #0
	ror
	sta rvdebug_instr+1
	lda tmp1
	sta rvdebug_instr+2
	lda #0
	sta rvdebug_instr+3
	rts
