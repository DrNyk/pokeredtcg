; [wCurSpecies] = pokemon ID
; hl = dest addr
PrintMonType:

	
	call GetPredefRegisters
	push hl
	call GetMonHeader
	pop hl
	ld a, [wMonHType1]
	call PrintType
	ld bc, SCREEN_WIDTH * 2
	add hl, bc ; queues up our weakness line
	push hl
	hlcoord 15, 9
	ld a, [wMonHType1]
	add $BF
	ld [hl], a
	pop hl ; restore the weakness line
	ld a, [wMonHType2]
	and $f0
	jr z, .dontprintweakness
	swap a ; weakness
	call PrintType
	push hl
	hlcoord 15, 11
	ld a, [wMonHType2]
	and $f0
	swap a
	add $BF
	ld [hl], a
	pop hl
.dontprintweakness
	add hl, bc ; gets us down to the resistance line
	ld a, [wMonHType2]
	and $0f
	ret z
	push hl ; hl is currently lined up to the resistance line
	add $BF ; nothing manipulated on a yet
	hlcoord 17, 15
	ld [hl], a
	pop hl ; restore the resistance line and fall through
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
	and $0f
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
