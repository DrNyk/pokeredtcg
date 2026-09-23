.moveSelected
pop af
ret nz
ld hl, wBattleMonMoves
ld a, [wCurrentMenuItem]
ld c, a
ld b, $0
add hl, bc

call MoveCheck ; should output a value "a" depending on the outcome for us

and a
ret z ; $0 = pass. $1 = Disabled. $2 = NoPP
dec a ; or if it was $1 for Disabled Move
ld hl, MoveDisabledText
jp z, .disabled
ld hl, MoveNoPPText
; noPP fallthrough
.print
call PrintText
call LoadScreenTilesFromBuffer1
jp MoveSelectionMenu



MoveCheck:
	ld a, [hl]
	dec a ; table starts at pound, not null
	ld hl, Moves
	ld bc, MOVE_LENGTH
	call AddNTimes
	push de
	ld de, wMoveData
	ld a, BANK(Moves)
	call FarCopyData
	ld hl, wMoveData + 3 ; de was adjusted by FarCopyData so don't do ld h, d / ld l, e shortcut
	ld a, [hli] 
	ld d, a ; d will store my type(s) for now
	inc hl ; skip over accuracy
	ld b, [hl] ; b will store my PP(s) for now
	ld a, [wPlayerBattleStatus3]
	bit TRANSFORMED, a
	jp nz, .transformedMoveSelected ; treat all energy as colorless
	ld a, $7
	and b
	z, .singleTypeRequirement
; otherwise this is going to have two energy requirements. Fun.
	ld c, a ; this is the PP2 Requirement for the Attack
	ld a, b
	and $F0
	swap a
	ld b, a ; now b has the PP1 Requirement for the Attack
	; I do have SKY_ATTACK which is primarily colorless, but secondary Fire type required
	ld a, d
	swap a
	and $7
	ld e, a ; e is my move's SECONDARY TYPE
	ld a, d
	and $7
	ld d, a ; d is my move's PRIMARY TYPE
	xor a
	inc a ; a is now 1
	cp e
	jr z, .SecondaryIsColorless
	cp d
	jr z, .PrimaryIsColorless
	; fallthrough when neither are colorless
	; this will cause problems when there is an error about using two colorless types in the move definition. I think it's otherwise salvageable. 
	ld a, d
	dec a
	dec a ; shifts from 2-7 down to 0-5
	srl a
		; 0000 -> 0000 0
		; 0001 -> 0000 1
		; 0010 -> 0001 0
		; 0011 -> 0001 1
		; 0100 -> 0010 0
		; 0101 -> 0010 1
	ld hl, wBattleMonPP
	jr z, .NeitherIsColorlessCheck1
	inc hl
	dec a ; doesn't touch the carry flag!! Wahoo!
	jr z, .NeitherIsColorlessCheck1
	inc hl ; otherwise a was 2 to start with and we want to look at wBattleMonPP+a
.NeitherIsColorlessCheck1
	ld a, [hl]
	jr c, .noSwap2
	swap a
.noSwap2
	and $7
	sub b
	jp c, .noPP
	ld a, e
	dec a
	dec a
	srl a
	ld hl, wBattleMonPP
	jr z, .NeitherIsColorlessCheck2
	inc hl
	dec a
	jr z, .NeitherIsColorlessCheck2
	inc hl
.NeitherIsColorlessCheck2
	ld a, [hl]
	jr c, .noSwap3
	swap a
.noSwap3
	and $7
	sub c
	jp c, .noPP
	jr .passedEnergyCheck
.SecondaryIsColorless ; e and c are the colorless registers
	ld a, d
	dec a
	dec a ; shifts from 2-7 down to 0-5
	srl a
	ld hl, wBattleMonPP
	jr z, .SecondaryIsColorlessCheckPrimary
	inc hl
	dec a
	jr z, .SecondaryIsColorlessCheckPrimary
	inc hl
.SecondaryIsColorlessCheckPrimary
	ld a, [hl]
	jr c, .noSwap4
	swap a
.noSwap4
	and $7
	sub b
	jp c, .noPP
	ld hl, wBattleMonPP
	call ColorLessEnergyCheck
	; a now holds how much total energy we have
	sub b ; subtract my primary energy requirements from it
	jr c, .noPP
	; we're halfway there. If we still have more energy in a than what is required of register c, then we're golden
	sub c ; secondary energy requirements
	jr c, .noPP
	jr .passedEnergyCheck
.PrimaryIsColorless ; d and b are the colorless registers
	ld a, e
	dec a
	dec a
	srl a
	ld hl, wBattleMonPP
	jr z, .PrimaryIsColorlessCheckSecondary
	inc hl
	dec a
	jr z, .PrimaryIsColorlessCheckSecondary
	inc hl
.PrimaryIsColorlessCheckSecondary
	ld a, [hl]
	jr c, .noSwap5
	swap a
.noSwap5
	and $7
	sub c
	jr c, .noPP
	call ColorLessEnergyCheck
	sub c ; remove my secondary energy which is non-colorless
	jr c, .noPP
	sub b
	jr c, .noPP
	jr .passedEnergyCheck
.transformedMoveSelected
	; hl is still pointing at the PP byte. 
	; b has copied that value.
; a is non-zero, in at least the bit controlling being transformed. 
	; d is my current type which I'll overwrite to be colorless
	; c is $3 arbitrarily
	; e is part of wMoveData address
	ld d, 1
	ld a, b ; this is the PP requirement in the format pp1/2
	swap a ; this is the PP requirement in the format pp2/1
	add b ; this is the PP requirement in the format pp1+pp2/pp1+pp2 -- should not yield higher than $E in either nybble
	and $f0 ; reduce this down to pp1+pp2 in the HIGH NYBBLE
	ld b, a ; now b has the PP requirement in the HIGH NYBBLE
.singleTypeRequirement
	swap b ; now the PP *1* is available in the low nybble
	ld a, d ; get my type again
	and $7 ; we're looking at just the one type of move
	dec a ; shifts from values 1-7 down to 0-6
	ld hl, wBattleMonPP ; the code branches on the next line, and both branches need to start here on their hl value
	jr z, .ColorLessAttack
	; otherwise it requires a specific type of energy, which is now shifted 1-6 for Fighting
	; if it is 1, 3, or 5 then I need the high nibble of the respective PP
	; if it is 2, 4, or 6 then I need the low nibble
	dec a ; again so now the 1-6 remaining is 0-5
	srl a
		; 0000 -> 0000 0
		; 0001 -> 0000 1
		; 0010 -> 0001 0
		; 0011 -> 0001 1
		; 0100 -> 0010 0
		; 0101 -> 0010 1
	; what a contains now is the carry flag that tells me which nibble I need
	; and a is ready to be used for a loop to inc hl
	jr z, .SpecificTypeAttack
	inc hl
	dec a ; doesn't touch the carry flag!! Wahoo!
	jr z, .SpecificTypeAttack
	inc hl ; otherwise a was 2 to start with and we want to look at wBattleMonPP+a
.SpecificTypeAttack
	ld a, [hl]
	jr c, .noSwap
	swap a
.noSwap
	and $7 ; now we have our type-specific PP
	sub b
	jr c, .noPP
	jr .passedEnergyCheck
.ColorLessAttack
	call ColorLessEnergyCheck
	sub b ; subtract the b energy requirements
	jr c, .noPP

	; my PP is structured such that it is 6 nibbles long of 	[Fighting|Fire]|[Water|Grass]|[Lightning|Psychic_Type] and I have an extra byte left over in PP for mon data structure.   2|3|4|5|6|7
	
	
	;and PP_MASK
	;jr z, .noPP
.passedEnergyCheck
	pop de
	ld a, [wPlayerDisabledMove]
	swap a
	and $f
	dec a
	cp c
	jr z, .disabled
	ld a, [wCurrentMenuItem]
	ld hl, wBattleMonMoves
	ld c, a
	ld b, $0
	add hl, bc
	ld a, [hl]
	ld [wPlayerSelectedMove], a
	xor a
	ret
.disabled
	ld a, $1
	ret
.noPP
	pop de
	ld a, $2
	ret
	
	
CountPartyAlive: ; derivative of AnyPartyAlive
	ld a, [wPartyCount]
	ld e, a ; alive count
	ld d, a ; total count
	xor a
	ld hl, wPartyMon1HP
	ld bc, PARTYMON_STRUCT_LENGTH - 1
.loop
	or [hl]
	inc hl
	or [hl]
	add hl, bc ; prepare for the next mon
	jr nz, .itsalive
	dec e ; reduce e if a mon is fainted
	ld a, [wPartyCount] ; pretend it's 1
	sub d ; this gives us an offset for populating [wWhichPokemon]. First mon? Slot 0. Last mon of 6? Slot 5, as d would be 1 when we check the last slot.
	ld [wWhichPokemon], a
	xor a ; keep this back at 0 for the next `or [hl]`
.itsalive
	dec d
	jr nz, .loop ; look at the next one if we aren't yet at end of party
	ld a, e ; a (and e) contain the number of alive Pokemon
	ret
	
CountPartyAlive: ; derivative of AnyPartyAlive
	ld a, [wPartyCount]
	ld e, a ; alive count
	ld d, a ; total count
	xor a
	ld hl, wPartyMon1HP
	ld bc, PARTYMON_STRUCT_LENGTH - 1
.loop
	dec e ; presumed to be fainted
	or [hl]
	inc hl
	or [hl]
	add hl, bc ; prepare for the next mon
	jr z, .itsfainted
	; fall through here if it's actually alive
	inc e ; undo the fainted count we just applied
	ld a, [wPartyCount] ; pretend it's 1
	sub d ; this gives us an offset for populating [wWhichPokemon]. First mon? Slot 0. Last mon of 6? Slot 5, as d would be 1 when we check the last slot.
	ld [wWhichPokemon], a
	xor a ; keep this back at 0 for the next `or [hl]`
.itsfainted
	dec d ; deduct always
	jr nz, .loop ; look at the next one if we aren't yet at end of party
	ld a, e ; a (and e) contain the number of alive Pokemon
	ret
	
	
	
	ld a, [wEnergyGranted] ; presumed to be 1 if I'm able to select Fight. I make it a 2 when I'm writing "PASS "
	cp $2
	ret z ; we already overwrote this to be "PASS " instead.
	inc a
	ld [wEnergyGranted], a
	ld hl, BattleMenu_RunWasSelected.InsufficientEnergy
	call PrintText
	rra ; this always set the z flag to 0
	ret ; the z flag is false, so the call that made this will proceed to a `jp nz, .MainInBattleLoop`
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
MoveCheck:
	ld a, [hl]
	dec a ; table starts at pound, not null
	ld hl, Moves
	ld bc, MOVE_LENGTH
	call AddNTimes
	ld de, wMoveData
	ld a, BANK(Moves)
	call FarCopyData
	ld hl, wMoveData + 3 ; de was adjusted by FarCopyData so don't do ld h, d / ld l, e shortcut
	ld a, [hli] 
	ld d, a ; d will store my type(s) for now
	inc hl ; skip over accuracy
	ld b, [hl] ; b will store my PP(s) for now
	ld hl, wBattleMonPP
	ldh a, [hWhoseTurn]
	and a
	ld a, [wPlayerBattleStatus3]
	jr z, .Player
	ld hl, wEnemyMonPP
	ld a, [wEnemyBattleStatus3]
.Player
	push hl ; cache the wBattleMonPP or wEnemyMonPP
	bit TRANSFORMED, a
	jp nz, .transformedMoveSelected ; treat all energy as colorless
	ld a, $7
	and b
	jp z, .singleTypeRequirement
; otherwise this is going to have two energy requirements. Fun.
	ld c, a ; this is the PP2 Requirement for the Attack
	ld a, b
	and $F0
	swap a
	ld b, a ; now b has the PP1 Requirement for the Attack
	; I do have SKY_ATTACK which is primarily colorless, but secondary Fire type required
	ld a, d
	swap a
	and $7
	ld e, a ; e is my move's SECONDARY TYPE
	ld a, d
	and $7
	ld d, a ; d is my move's PRIMARY TYPE
	xor a
	inc a ; a is now 1
	cp e
	jr z, .SecondaryIsColorless
	cp d
	jr z, .PrimaryIsColorless
	; fallthrough when neither are colorless
	; this will cause problems when there is an error about using two colorless types in the move definition. I think it's otherwise salvageable. 
	ld a, d
	dec a
	dec a ; shifts from 2-7 down to 0-5
	srl a
		; 0000 -> 0000 0
		; 0001 -> 0000 1
		; 0010 -> 0001 0
		; 0011 -> 0001 1
		; 0100 -> 0010 0
		; 0101 -> 0010 1
	pop hl ; restore the wBattleMonPP/wEnemyMonPP here
	push hl
	jr z, .NeitherIsColorlessCheck1 ; submit to it [hl+0]
	inc hl
	dec a ; doesn't touch the carry flag!! Wahoo!
	jr z, .NeitherIsColorlessCheck1 ; submit to it [hl+1]
	inc hl ; otherwise a was 2 to start with and we want to look at [hl+2]
.NeitherIsColorlessCheck1
	ld a, [hl]
	jr c, .noSwap2
	swap a
.noSwap2
	and $7
	sub b
	jp c, .noPP
	ld a, e
	dec a
	dec a
	srl a
	pop hl ; restores wBattleMonPP/wEnemyMonPP
	push hl
	jr z, .NeitherIsColorlessCheck2 ; submit to it [hl+0]
	inc hl
	dec a
	jr z, .NeitherIsColorlessCheck2 ; submit to it [hl+1]
	inc hl ; submit to it [hl+2]
.NeitherIsColorlessCheck2
	ld a, [hl]
	jr c, .noSwap3
	swap a
.noSwap3
	and $7
	sub c
	jp c, .noPP
	jr .passedEnergyCheck
.SecondaryIsColorless ; e and c are the colorless registers
	ld a, d
	dec a
	dec a ; shifts from 2-7 down to 0-5
	srl a
	pop hl ; restores wBattleMonPP/wEnemyMonPP
	push hl
	jr z, .SecondaryIsColorlessCheckPrimary
	inc hl
	dec a
	jr z, .SecondaryIsColorlessCheckPrimary
	inc hl
.SecondaryIsColorlessCheckPrimary
	ld a, [hl]
	jr c, .noSwap4
	swap a
.noSwap4
	and $7
	sub b
	jp c, .noPP
	ld hl, wBattleMonPP
	ldh a, [hWhoseTurn]
	and a
	jr z, .player3
	ld hl, wEnemyMonPP
.player3
	call ColorLessEnergyCheck
	; a now holds how much total energy we have
	sub b ; subtract my primary energy requirements from it
	jr c, .noPP
	; we're halfway there. If we still have more energy in a than what is required of register c, then we're golden
	sub c ; secondary energy requirements
	jr c, .noPP
	jr .passedEnergyCheck
.PrimaryIsColorless ; d and b are the colorless registers
	ld a, e
	dec a
	dec a
	srl a
	pop hl ; restores wBattleMonPP/wEnemyMonPP
	push hl
	jr z, .PrimaryIsColorlessCheckSecondary
	inc hl
	dec a
	jr z, .PrimaryIsColorlessCheckSecondary
	inc hl
.PrimaryIsColorlessCheckSecondary
	ld a, [hl]
	jr c, .noSwap5
	swap a
.noSwap5
	and $7
	sub c
	jr c, .noPP
	pop hl ; restores wBattleMonPP/wEnemyMonPP
	push hl
	call ColorLessEnergyCheck
	sub c ; remove my secondary energy which is non-colorless
	jr c, .noPP
	sub b
	jr c, .noPP
	jr .passedEnergyCheck
.transformedMoveSelected
	; ~~hl is still pointing at the PP byte. ~~ hl is now pointing at wBattleMonPP or wEnemyMonPP
	; b has copied that value.
; a is non-zero, in at least the bit controlling being transformed. 
	; d is my current type which I'll overwrite to be colorless
	; c is $3 arbitrarily
	; e is part of wMoveData address
	ld d, 1
	ld a, b ; this is the PP requirement in the format pp1/2
	swap a ; this is the PP requirement in the format pp2/1
	add b ; this is the PP requirement in the format pp1+pp2/pp1+pp2 -- should not yield higher than $E in either nybble
	and $f0 ; reduce this down to pp1+pp2 in the HIGH NYBBLE
	ld b, a ; now b has the PP requirement in the HIGH NYBBLE
.singleTypeRequirement
	swap b ; now the PP *1* is available in the low nybble
	ld a, d ; get my type again
	and $7 ; we're looking at just the one type of move
	dec a ; shifts from values 1-7 down to 0-6
	; ld hl, wBattleMonPP either branch that comes in here, being .transformedMoveSelected or .singleTypeRequirement has the correct hl already for player vs enemy.
	jr z, .ColorLessAttack
	; otherwise it requires a specific type of energy, which is now shifted 1-6 for Fighting
	; if it is 1, 3, or 5 then I need the high nibble of the respective PP
	; if it is 2, 4, or 6 then I need the low nibble
	dec a ; again so now the 1-6 remaining is 0-5
	srl a
		; 0000 -> 0000 0
		; 0001 -> 0000 1
		; 0010 -> 0001 0
		; 0011 -> 0001 1
		; 0100 -> 0010 0
		; 0101 -> 0010 1
	; what a contains now is the carry flag that tells me which nibble I need
	; and a is ready to be used for a loop to inc hl
	jr z, .SpecificTypeAttack
	inc hl
	dec a ; doesn't touch the carry flag!! Wahoo!
	jr z, .SpecificTypeAttack
	inc hl ; otherwise a was 2 to start with and we want to look at wBattleMonPP+a
.SpecificTypeAttack
	ld a, [hl]
	jr c, .noSwap
	swap a
.noSwap
	and $7 ; now we have our type-specific PP
	sub b
	jr c, .noPP
	jr .passedEnergyCheck
.ColorLessAttack
	call ColorLessEnergyCheck
	sub b ; subtract the b energy requirements
	jr c, .noPP

	; my PP is structured such that it is 6 nibbles long of 	[Fighting|Fire]|[Water|Grass]|[Lightning|Psychic_Type] and I have an extra byte left over in PP for mon data structure.   2|3|4|5|6|7
	
	
	;and PP_MASK
	;jr z, .noPP
.passedEnergyCheck
	pop hl
	ld a, [wPlayerDisabledMove]
	swap a
	and $f
	dec a
	cp c
	jr z, .disabled
	ld bc, wBattleMonMoves - wBattleMonPP ; big rollover so it targets either wBattleMonPP or wEnemyMonPP
	add hl, bc
	ld a, [wCurrentMenuItem]
	ld c, a
	ld b, $0
	add hl, bc
	ldh a, [hWhoseTurn]
	and a
	ld a, [hl]
	jr z, .playerY
	ld [wEnemySelectedMove], a
	xor a
	ret
.playerY
	ld [wPlayerSelectedMove], a
	xor a
	ret
.disabled
	ld a, $1
	ret
.noPP
	pop hl
	ld a, $2
	ret
	
	
ld hl, wBattleMonPP
call ColorLessEnergyCheck
ld b, a
ld a, [wBattleMonType]
and $f0
swap a
cp b
jr z, .enoughEnergy
jr c, .enoughEnergy
ld hl, .InsufficientEnergy
call PrintText
jp DisplayBattleMenu
.enoughEnergy
; how many types of energy
; if it's all one type, we don't even need to have player choose
; hl should still be as defined before ColorLessEnergyCheck
ld b, 0 ; b will be our counter
ld c, 3 ; c will check how many byte we checked
.nextByte
xor a
or [hl]
and $f0
jr z, .nopp1
inc b
.nopp1
xor a
or [hl]
and $0f
jr z, .nopp2
inc b
.nopp2
inc hl
dec c
jr nz, .nextByte
; if we get to here, then b is how many types we have PP for
dec b
jr z, .onlyOneType
ld a, ENERGY_DISCARD_MENU_TEMPLATE 


call HandleMenuInput ; somehow I need just a and b to be active

.onlyOneType














AnyMoveToSelect:
	ld hl, wBattleMonMoves
	ld c, 0 ; the count of available moves, as there is CheckForDisobedience that does this
	ld de, wEnergyStringBuffer ; while it's meant for a string, I'm going to record the move slots in here
	ldh a, [hWhoseTurn]
	and a
	jr z, .next
	ld hl, wEnemyMonMoves
.next
	push bc
	push de
	push hl
	call MoveCheck
	and a
	pop hl
	pop de
	pop bc
	jr nz, .notviable
	ld a, [hl]
	ld [de], a
	inc de
	inc c
.notviable
	inc hl
	ld a, LOW(wBattleMonMoves+4)
	cp l
	jr nz, .next
	; fall through here when loop is done
	ld a, c
	and a
	ret










