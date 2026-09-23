InitBattleVariables:
	ldh a, [hTileAnimations]
	ld [wSavedTileAnimations], a
	xor a
	ld [wActionResultOrTookBattleTurn], a
	ld [wBattleResult], a
	ld hl, wPartyAndBillsPCSavedMenuItem
	ld [hli], a
	ld [hli], a
	ld [hli], a
	ld [hl], a
	ld [wListScrollOffset], a
	ld [wCriticalHitOrOHKO], a
	ld [wBattleMonSpecies], a
	ld [wPartyGainExpFlags], a
	ld [wPlayerMonNumber], a
	ld [wEscapedFromBattle], a
	ld [wMapPalOffset], a
	ld hl, wPlayerHPBarColor
	ld [hli], a ; wPlayerHPBarColor
	ld [hl], a ; wEnemyHPBarColor
	ld b, b
push de
	ld hl, wPartyMon1PP
	ld bc, wPartyMon2PP - wPartyMon1PP - 2
	ld d, 6
.partyMonPPWipeLoop
	ld [hli], a
	ld [hli], a
	ld [hl], a
	dec d
	add hl, bc
	jr nz, .partyMonPPWipeLoop

	ld a, [wLinkState]
	cp LINK_STATE_BATTLING
	jr z, .linkBattle1 ; PP priming stuff only works in single player battles
	ld hl, wPartyMon1PP+3
	call Priming
	
.linkBattle1
	ld a, 1
	ldh a, [hWhoseTurn]
	xor a
	ld hl, wEnemyMonPP
	ld [hli], a
	ld [hli], a
	ld [hl], a
	ld hl, wEnemyMon1PP
	ld bc, wEnemyMon2PP - wEnemyMon1PP - 2
	ld d, 6
.enemyMonPPWipeLoop
	ld [hli], a
	ld [hli], a
	ld [hl], a
	dec d
	add hl, bc
	jr nz, .enemyMonPPWipeLoop
	
	ld a, [wLinkState]
	cp LINK_STATE_BATTLING
	jr z, .linkBattle2 ; PP priming stuff only works in single player battles
	ld hl, wEnemyMon1PP+3
	call Priming
.linkBattle2	
	
	pop de
	xor a
	ldh a, [hWhoseTurn] ; reset this with the Priming shenanigans
	ld hl, wCanEvolveFlags
	ld b, wMiscBattleDataEnd - wMiscBattleData
.loop
	ld [hli], a
	dec b
	jr nz, .loop
	inc a ; POUND
	ld [wTestBattlePlayerSelectedMove], a
	ld a, [wCurMap]
	cp SAFARI_ZONE_EAST
	jr c, .notSafariBattle
	cp SAFARI_ZONE_CENTER_REST_HOUSE
	jr nc, .notSafariBattle
	ld a, BATTLE_TYPE_SAFARI
	ld [wBattleType], a
.notSafariBattle
	jpfar PlayBattleMusic

Priming: ; hl should be input to w___MonNPP+3
	ld d, 6
.analyzingMon
	ld a, [hl]
	and a
	jr z, .skippartypriming
	push hl ; this points to w___MonNPP+3
	ld e, a
	ld bc, wPartyMon1HP - (wPartyMon1PP+3) ; going to be an $FFxx number
	add hl, bc
	ld a, [hli]
	or [hl]
	jr z, .deadmonskipit
	ld a, e ; otherwise we have a living mon, we can check its moves against what PP4 held as a move id
	ld bc, wPartyMon1Moves - (wPartyMon1HP + 1) ; this will make b = 0
	add hl, bc ; now we point at wPartyMon1Moves
	cp [hl]
	jr z, .attackToPrime
	inc hl
	cp [hl]
	jr z, .attackToPrime
	inc hl
	cp [hl]
	jr z, .attackToPrime
	inc hl
	cp [hl]
	jr nz, .deadmonskipit; NOT .skippartypriming because of the push hl on this branch ; none of the moves match the prime identity
.attackToPrime
	push de
	callfar MoveCheckPreRequisite ; while b is clobbered by the BankSwitch stuff, d and e should be just fine for returning primary and secondary types respectively. And that's all I really need to know, is what type it wants energy for.
	pop bc ; store my d counter in b (and not carring about e in c)
	pop hl ; restores w___MonNPP+3
	push hl ; to complement the pop hl we fall through below at the .deadmonskipit tag, and we do want to restore this hl to byte +3 no matter where this following logic shuffled hl to
	dec hl
	dec hl
	dec hl ; get it lined up to the first PP byte
	ld a, d
	dec a ; if it's fighting type, we go from 2->1
	jr z, .colorlessprimary
.readytoassign
	ld d, b ; move our restored d counter that was in b, back into d
	dec a ; if it's fighting type, we g from 1->0; and if it's fire, we go 2->1
	srl a ; if it's fighting type (high nibble), then it yields 0 (0); if it's fire type (low nibble), then it yields 0 (1). So even type constants have no carry, and they should have value $10 to them. odd type constants have carry, so they should have value $1 to them.
	jr z, .alreadyalignedtohl
	inc hl
	dec a
	jr z, .alreadyalignedtohl
	inc hl
.alreadyalignedtohl
	ld a, $1
	jr c, .noswap
	swap a
.noswap
	ld [hl], a
	jr .deadmonskipit ; we're actually done on this mon
.colorlessprimary ; I am not accommodating a scenario of 
	ld a, e
	and a
	jr z, .onlycolorless
	dec a ; now type shifts from 2-7 to 1-6. If for some reason we had colorless as the secondary type and skiped over the first logic... We'll fall down to .onlycolorless. I.e. "colorless colorless" move, or some glitch where the first color wasn't detected in primary types.
	jr nz, .readytoassign
.onlycolorless
	; let's randomly get something. What's nifty here is, DrawEnergy handles this for us. I just need to have manipulated ldh a, [hWhoseTurn] prior to doing these.
	push hl
	push bc
	call DrawEnergyPriming ; a random type appropriate for the team (not necessarily the specific mon; i.e. if you have PP-Up'd Hyper Beam on a Charizard but also have a Blastoise with Surf on your team, you could be given a Water energy on Charizard to start to give you progress toward the Hyper Beam.)
	pop bc ; that rehoused d ticker counting in here
	pop hl
	jr z, .readytoassign
.deadmonskipit
	pop hl ; this would restore w___MonNPP+3
.skippartypriming
	ld bc, PARTYMON_STRUCT_LENGTH ; If I can make AttackToPrime NOT clobber b, I can make this just ld c, PARTYMON_STRUCT_LENGTH to save a byte
	add hl, bc
	dec d
	jr nz, .analyzingMon
	ret
	
DrawEnergyPriming:
xor a
ld [wTempByteValue], a ; we're going to use this for checking what types of moves I've got in the party
ld hl, wPartyMon1HP
ld a, [wPartyCount]
ld d, a 
; ld d, 6 ; why not make it the party size!?!?! Yes, do that. It's fine for player, but the NPC may not take kindly when you go from a 6-mon party to a 3-mon party. That data may not be wiped out.
ldh a, [hWhoseTurn] ; 0 = player's turn. As I make this a repeatable function, we'll need to, uh, set hWhoseTurn before its call. 
and a
jr z, .nextMonLoop
; otherwise it's the enemy needing to draw
ld hl, wEnemyMon1HP
ld a, [wEnemyPartyCount]
ld d, a
.nextMonLoop
ld a, [hli]
or [hl]
ld bc, wPartyMon1Moves - (wPartyMon1HP + 1)
add hl, bc ; now hl is at wPartyMon1Moves
jr z, .FaintedOrEmptySlot_SkipEnergyOptions
ld b, 4
.moveCheckLoop
	ld a, [hli] ; so we read the value of the move
	and a
	jr z, .skip
	push bc
	push de
	push hl
	dec a ; as table starts at pound, not null_move
	ld hl, Moves
	ld bc, MOVE_LENGTH
	call AddNTimes
	ld de, wMoveData
	ld a, BANK(Moves)
	call FarCopyData
	ld a, [wMoveData + 3]
	and $77 ; this strips the physical/special prefix right out of them
	ld b, a ; cache the $77 value of the move types for energies
	ld c, 1
	and $0f ; look at type1. This is now a value of 0 to 7
	cp $2
	jr c, .skipBitLoop ; - means the type is null or colorless
	; we know carry flag is empty right now, it was no carry
	dec a ; fighting type at value of 2 becomes 1
	.bitLoop
		rl c ; c goes from 1 to 2, then to 4, then to 8, etc. What we care about is merely the one bit
		dec a
	jr nz, .bitLoop ; keep rotating this c register until a hits 0. 0000 0001 ("colorless") -> 0000 0010 (fighting) -> 0000 0100 (fire) -> 0000 1000 (water) -> 0001 0000 (grass) -> 0010 0000 (lightning) -> 0100 0000 (psychic_type)
	.skipBitLoop
	ld a, [wTempByteValue]
	or c
	ld [wTempByteValue], a
	ld a, b ; check for a type2
	ld c, 1
	swap a
	and $0f ; looks at type
	cp $2
	jr c, .skipBitLoop2 ; null or colorless secondary typing
	dec a
	.bitLoop2
		rl c
		dec a
	jr nz, .bitLoop2
	.skipBitLoop2
	ld a, [wTempByteValue]
	or c
	ld [wTempByteValue], a
	pop hl
	pop de
	pop bc
.skip
	dec b
	jr nz, .moveCheckLoop
	jr .moncomplete
.FaintedOrEmptySlot_SkipEnergyOptions
	inc hl
	inc hl
	inc hl
	inc hl
.moncomplete
ld bc, wPartyMon2HP - (wPartyMon1Moves + 3) - 1
add hl, bc
dec d
jr nz, .nextMonLoop
; we exit the loop when d is 0
; count how many types qualify
; I NEED A SAFETY CHECK FOR WHEN NO TYPES QUALIFIED!!
ld e, d ; d = 0 right now. e will count to the "highest" type we have. Starts at 1 for colorless, then 2 is fighting
ld a, [wTempByteValue] ; this is necessary because when we run it to checking if a move slot is empty, we lose the a that otherwise happened just after the .skipBitLoop step. Because we instead jumped to .skip
and $FE ; $FE = %1111 1110 ; we could have had a "Colorless" bit at bit0 set to true, so we remove that.
ld [wTempByteValue], a
jr z, .EveryAttackIsColorless
.next ; we're starting this off e = 0 (as d= 0)
srl a
inc e ; doesn't touch carry flag
jr nc, .next ; the first time through, it should have no carry flag from rra
inc d ; otherwise a bit was counted
and a
jr nz, .next
; once we're out, we know how many types are an option
dec d
ld a, e ; if we had only one type, we skip the call
ret z
;call nz, .GetRandomDraw ; changed the logic, let it fall through
; a is going to have just one type when we get to this



;.GetRandomDraw:
ld a, d ; d already shifted from 1-6 types to 0-5 types. The cp $3 with carry means 0-2 (1-3) vs 3-5 types set (4-6)
cp $3
jr c, .fewBitsOption
; fallthrough to the highBitsOption


;OPTION 1: = $18 bytes (LIES! HAD TO CORRECT IT) ; hypothetically the better choice when there are many bits set
; once d hits zero, that should terminate the loop and we'll have created a type-bit mask for drawing energy
.rerollHighBitsOption
	call Random
	; the goal is I need a single 1 bit that is somewhere in 0111 1110.
	and $7
	jr z, .rerollHighBitsOption
	; past here means it's range 1-7
	dec a ; shifts down to 0-6
	jr z, .rerollHighBitsOption
	; past here means it's range 1-6
	ld b, a ; put my rotation counter in here
	ld a, 1
.keeprotatingHighBitsOption
	sla a
	dec b
	jr nz, .keeprotatingHighBitsOption
	ld b, a
	ld a, [wTempByteValue]
	and b
	jr z, .rerollHighBitsOption ; we failed to get one that matched an existing type
; otherwise, we've got our type of energy drawn in a
; This gives me a bit-mask... For example, %0000 1000 is generated (8) but that should correspond to type 4 = water
	; ret is wrong
	ld e, 0
	ld d, 0
	jr .next ; from way up above, we narrowed it down to 1 type and will circle through for the 1-type calculation

;OPTION 2: = $15 bytes ; hypothetically the better choice when there are few bits set
	; d is currently at 0
.fewBitsOption
	ld hl, wTempByteValue
.reroll
	ld d, 0
	call Random
	and [hl]
	; so now it is 0??? ???0
	jr z, .reroll ; if it turned out to be 0000 0000 then we can't use this
.keeprotating
	inc d ; d counts for our type. d = 1 when rra products 00?? ???? thus d = colorless. So we keep going. If it produces 000? ???? (1) then d = 2 = fighting.
	srl a		
	jr nc, .keeprotating
	; once it carries, I need it to be zero
	and a
	jr nz, .reroll
.weGotOurAnswer
	ld a, d ; this is the type constant we want!!
	ret


.EveryAttackIsColorless
	ldh a, [hWhoseTurn]
	and a
	ld a, [wPlayerStarter]
	jr z, .playerZ
	ld a, [wRivalStarter]
.playerZ	
	ld b, a
	cp CHARMANDER
	ld a, FIRE
	ret z
	ld a, b
	cp SQUIRTLE
	ld a, WATER
	ret z
	ld a, GRASS
	ret