HealParty:
; restore HP and status
	ld hl, wPartySpecies
	ld de, wPartyMon1HP
.healmon
	ld a, [hli]
	cp $ff ; see wPartySpecies has 7 bytes for storing our party, and $ff is the 7th-byte terminator
	jr z, .done
	push hl
	
	ld hl, MON_STATUS - MON_HP ; bumps from wPartyMonNHP -> wPartyMonNStatus
	add hl, de
	xor a
	ld [hl], a ; wipes the status
	
	; right now de remains wPartyMonNHP
	; so the goal is to get hl up to wPartyMonNHPMax. It's at wPartyMonNStatus
	ld hl, MON_MAXHP - MON_HP
	add hl, de
	; hl is at wPartyMonNHPMax
	; de is at wPartyMonNHP
	ld a, [hli] ; gets value of wPartyMonNHPMax and makes hl wPartyMonNHPMax + 1
	ld [de], a
	inc de ; bumps this to wPartyMonNHP + 1
	ld a, [hl]
	ld [de], a
	dec de ; reset de back to wPartyMonNHP
	ld hl, PARTYMON_STRUCT_LENGTH
	add hl, de
	ld d, h
	ld e, l
	pop hl
	jr .healmon
	
.done
	xor a
	ld [wWhichPokemon], a
	ld [wUsingPPUp], a
	ret