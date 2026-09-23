; [wCurSpecies] = pokemon ID
; hl = dest addr
PrintMonType:

	
	call GetPredefRegisters
	push hl
	call GetMonHeader
	pop hl
	ld a, [wMonHType1]
	and $0F
	call PrintType
	ld bc, SCREEN_WIDTH * 2
	add hl, bc ; queues up our weakness line
	push hl
	hlcoord 18, 14
	ld a, [wMonHType1]
	and $F0 ; retreat cost
	swap a
	add $F6 ; character padding for 0-9 values that go from F6-FF.
	ld [hl], a
	hlcoord 15, 8
	ld a, [wMonHType1]
	and $0F
	add $BF ; prints the character
	ld [hl], a
	pop hl ; restore the weakness line
	ld a, [wMonHType2]
	and $f0
	jr z, .dontprintweakness
	swap a ; weakness
	push hl ; caches the weakness line
	call PrintType
	hlcoord 15, 10
	ld a, [wMonHType2]
	and $f0
	swap a
	add $BF
	ld [hl], a
	pop hl ; restores the weakness line
.dontprintweakness
	ld bc, SCREEN_WIDTH * 2
	add hl, bc ; gets us down to the resistance line
	ld a, [wMonHType2]
	and $0f
	ret z 
	push hl 
	add $BF 
	hlcoord 17, 12
	ld [hl], a ; print the type icon
	pop hl ; restore the resistance line for the text
	sub $BF ; undo the add $BF
	; fall through to printtype if it's not zero


; a = type
; hl = dest addr
PrintType:
	push hl
	jr PrintType_


PrintMoveType:
	call GetPredefRegisters
	push hl
	ld a, [wPlayerMoveType]
	and $07
	ld hl, wPlayerBattleStatus3
	bit TRANSFORMED, [hl]
	jr z, PrintType_
	ld a, $8
; fall through

PrintType_:
	add a
	ld hl, TypeNames
	ld e, a
	ld d, $0
	add hl, de
	ld a, [hli]
	ld e, a
	ld d, [hl]
	pop hl
	jp PlaceString

INCLUDE "data/types/names.asm"
