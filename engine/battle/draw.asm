; logic check. You can only draw energy if your mon is alive. So, do for hp check:
DrawEnergy:
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
ld a, [wIsInBattle]
ld d, a ; assuming it's 1 for wild battle...
ld hl, wEnemyMonHP
dec a
jr z, .nextMonLoop ; we have a wild battle going on
ld hl, wEnemyMon1HP
ld a, [wEnemyPartyCount]
ld d, a
.nextMonLoop
ld bc, wPartyMon1Moves - (wPartyMon1HP + 1) ; d173 - (d167) = $c
ld a, HIGH(wEnemyMonHP) ; $CF
cp h
jr nz, .normalTrainerBattle
; otherwise, it's just a wild battle, and the data moves differently
ld c, wEnemyMonMoves - (wEnemyMonHP + 1) ; $6
		;cfed			   - cfe7
.normalTrainerBattle
ld a, [hli]
or [hl]
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
	call BattleRandom ; my attempt at link battle support. Not a clue if it works this easily.
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
	call BattleRandom
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
	
AttachEnergy:
ld a, [wTempByteValue]
and $1 ; so if say [wTempByteValue] = FIGHTING = 2, then it's high nibble. This WILL be ZERO. 1 & 2 = 0
; if it is say FIRE = 3, then it's low nibble. 1 & 3 = 1
jr nz, .lownibble
ld a, $10 ; a "high" 1 for the high nibble
.lownibble ; if it jumped here, then a was 1
push af ; save this for now whether it is $1 or $10
ldh a, [hWhoseTurn]
ld hl, wPartyMon1PP - 1 ; we'll compensate with an "Extra" inc hl
and a
jr z, .playersTurn
ld hl, wEnemyMon1PP - 1
.playersTurn
ld bc, PARTYMON_STRUCT_LENGTH
ld a, [wWhichPokemon]
call AddNTimes
ld a, [wTempByteValue] ; values 2-7 ::: 0010, 0011  (2|3) ; 0100, 0101 (4|5) ; 0110, 0111 (6|7)
srl a ; :::		    0001, 0001  (1|1) ; 0010, 0010 (2|2) ; 0011, 0011 (3|3)
.loop
inc hl
dec a
jr nz, .loop
pop af ; restores either the $1 or $10
add [hl] ; adds this to the value of the byte we want
ld b, a ; cache the good a value for now
; here is where I want to check if either value has exceeded $90 | $9
and $F0
cp $91
jr nc, .tooLargeHighNibble
ld a, b
and $0f
cp $0A
ld a, b
jr c, .UpdateThePP ; acceptable nibbles
.tooLargeLowNibble ; fall through to here
and $f0
or $09
jr .UpdateThePP
.tooLargeHighNibble
ld a, b
and $0f
or $90
.UpdateThePP
ld [hl], a ; PP byte is updated
ld d, h
ld e, l ; just in case we need to do a copy
ldh a, [hWhoseTurn]
and a
ld a, [wWhichPokemon] ; for both branches
ld hl, wPlayerMonNumber
ld bc, wBattleMonPP - wPlayerMonNumber - 1 ; this further -1 is offset by an "extra" inc hl in loop to come ;;; D02D - CC2F - 1 = 3FD
;ld a, [wBattleMonPartyPos]
jr z, .playersTurnB
ld hl, wEnemyMonPartyPos ; THIS MIGHT BE A FLAW? WHY IS wBattleMonPartyPos always 0, is wEnemyMonPartyPos always 0 too ?? Is there a counterpart to wPlayerMonNumber ?? 
ld bc, wEnemyMonPP - wEnemyMonPartyPos - 1 ; this further -1 is offset by an "extra" inc hl in loop to come ;;; CFFE - CFE8 = 16
;ld a, [wEnemyMonPartyPos]
.playersTurnB
cp [hl]
ret nz ; the Pokemon we put energy on is not in battle
; otherwise if we get to here, it is the mon in battle so we need to update 
;ldh a, [hWhoseTurn]
;and a
;ret nz ; enemy stuff I have to program later
add hl, bc
ld a, [wTempByteValue]
srl a ; 0011 -> 0001 . hl will increase to d02d. The loop escapes.
.loopB
inc hl
dec a
jr nz, .loopB
ld a, [de] ; the new pp we just updated
ld [hl], a ; the active mon pp is mirroring it now
;dec a
ret

srlAAndIncrementPPByteOffset:
	srl a ; if it's an "odd type" (Fire, Grass, Or Psychic) which hides in the low bytes... carry flag is SET
	ret z
	inc hl
	dec a
	ret z
	inc hl
	ret
	

; DeductEnergyPlayer:
	; ld hl, wBattleMonPP
	; call srlAAndIncrementPPByteOffset
; .alreadyOnTheRightPP
	; ld a, [hl]
	; ld b, $1
	; jr c, .noSwap
	; swap a
	; swap b
; .noSwap
	; and $f
	; and a
	; jr z, .earlyAbortThisWasAtZeroAlready
	; ld a, [hl]
	; sub b
	; jr c, .earlyAbortThisWentNegative
	; ld [hl], a
; .earlyAbortThisWentNegative	
; .earlyAbortThisWasAtZeroAlready
	; ;ld b, b
	; ret