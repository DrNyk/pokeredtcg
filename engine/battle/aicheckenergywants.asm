AIFindDesiredEnergyTypes: ; clobbers everything. But returns in b the positive mask (these types wanted), and in c returns the negative mask (doesn't really need to be put on this mon).
	ld b, 0 ; b is a big time tracker that helps us look at all the moves 
	ld hl, wEnemyMonMoves
	ld de, wMoveData 
.grandloop
	ld a, [hli]
	and a
	jr z, .skipAsItsTypeNull2 ; this move slot is empty and has no energy needs
	dec a
	push hl
	push bc
	ld hl, Moves
	ld bc, MOVE_LENGTH
	call AddNTimes
	ld a, BANK(Moves)
	call FarCopyData
	pop bc
	pop hl
	ld a, [wMoveData + 3]
	and $70
	swap a
	jr z, .skipAsItsTypeNull
	scf
	ld c, $0
.rotationloop
	rl c
	dec a
	jr nz, .rotationloop ; once a hits zero, then we've rotated c far enough. 
	; if a starts at 1, then c becomes 1 (%0001). if a starts at 2, then c becomes 2 (%0010). if a starts at 3, then c becomes 4 (%0100)
	ld a, c
	or b ; this keeps of the binary type matches across all 8 possible type asks on my moveset 
	ld b, a ; save for next time
.skipAsItsTypeNull
	ld a, [wMoveData + 3]
	and $07
	jr z, .skipAsItsTypeNull2 ; doubt this ever executes as we're looking at the primary type, but a safety check anyway
	scf
	ld c, $0
.rotationloop2
	rl c
	dec a
	jr nz, .rotationloop2
	ld a, c
	or b
	ld b, a
.skipAsItsTypeNull2
	ld a, LOW(wEnemyMonMoves+4) ; checking if we've gone too far on type checks
	cp l
	jr nz, .grandloop
; once we have checked all 4 moves, we fall to here
	ld a, %01111110
	and b ; creates a mask of energies this mon wants to have
	jr nz, .usualcontinue
	ld b, a ; = $00; the mon doesn't want any specific energy; all colorless
	ld c, %00111111 ; any of the 6 elementals I am happy to discard for this mon
	ret
.usualcontinue
	srl a ; rotates it so instead of "0-index" it's "-1-index". Before srl, the first bit (bit 0) would have represented colorless, now it represents fighting.
	ld b, a ; load it into b
	xor %00111111
	ld c, a ; now c holds a mask of energy the mon wants to GET RID OF
	ret