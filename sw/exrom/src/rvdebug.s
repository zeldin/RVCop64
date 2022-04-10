
	.global rvdebug_halt, rvdebug_continue, rvdebug_step
	.global rvdebug_setreg, rvdebug_getreg, rvdebug_getpc, rvdebug_jump
	.global rvdebug_flush_ic, rvdebug_flush_dc, rvdebug_flush_caches


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


rvdebug_step:
	lda #$10
	.byte $2c ; bit abs

rvdebug_continue:
	lda #0
	sta rvdebug_status
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
getreg_common:
	lda rvdebug_regval
	sta faclo
	lda rvdebug_regval+1
	sta facmo
	lda rvdebug_regval+2
	sta facmoh
	lda rvdebug_regval+3
	sta facho
	rts

rvdebug_getpc:	
	lda #$17     ; auipc
	sta rvdebug_instr
	lda #0
	jsr common_flush
	beq getreg_common

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

	;; Cache flushing - instruction $100f flushes icache and $500f dcache
rvdebug_flush_caches:	
	jsr rvdebug_flush_dc
rvdebug_flush_ic:
	lda #$0f
	sta rvdebug_instr
	lda #$10
	bne common_flush
rvdebug_flush_dc:
	lda #$0f
	sta rvdebug_instr
	lda #$50
common_flush:
	sta rvdebug_instr+1
	lda #0
	sta rvdebug_instr+2
	sta rvdebug_instr+3
	rts
