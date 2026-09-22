MetronomePickMove:
	xor a
	ld [wAnimationType], a
	ld a, METRONOME
	call PlayMoveAnimation ; play Metronome's animation
; values for player turn
	ld de, wPlayerMoveNum
	ld hl, wPlayerSelectedMove
	ldh a, [hWhoseTurn]
	and a
	jr z, .pickMoveLoop
; values for enemy turn
	ld de, wEnemyMoveNum
	ld hl, wEnemySelectedMove
; loop to pick a random number in the range of valid moves used by Metronome
.pickMoveLoop
	call BattleRandom
	and a
	jr z, .pickMoveLoop
	cp STRUGGLE
	ASSERT NUM_ATTACKS == STRUGGLE ; random numbers greater than STRUGGLE are not moves
	jr nc, .pickMoveLoop
	cp METRONOME
	jr z, .pickMoveLoop
		
	ld [hl], a ; we'd normally be done here
; this is TCG Insert
	push hl ; as it points to wEnemySelectedMove/wPlayerSelectedMove
	; WHAT IS THE SIGNIFANCE OF DE? I'll push/pop protect it too
	call MoveCheckPreRequisite
	ldh a, [hWhoseTurn]
	and a
	ld hl, wBattleMonPP
	jr z, .playersTurn
	ld hl, wEnemyMonPP
.playersTurn
	push hl ; THIS IS FOR THE SAKE OF THE INNER FUNCTION
	call MoveCheck.transformedMoveSelected ; treat all attacks as colorless? And bypass the disabled check?
	and a
	pop hl
	jr nz, .pickMoveLoop ; reroll, we didn't have enough energy for this
	jr ReloadMoveData