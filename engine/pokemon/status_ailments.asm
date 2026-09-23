PrintStatusAilment::
	ld a, [de]
	bit PSN, a
	jr nz, .psn
	bit BRN, a
	jr nz, .brn
	bit FRZ, a
	jr nz, .frz
	bit PAR, a
	jr nz, .par
	and SLP_MASK
	ret z
	ld a, $CB ; SLP
	ld [hl], a
	ret
.psn
	ld a, $CA ; PSN
	ld [hl], a
	ret
.brn
	ld a, $C2 ; BRN
	ld [hl], a
	ret
.frz
	ld a, $CE ; FRZ
	ld [hl], a
	ret
.par
	ld a, $C5 ; PAR
	ld [hl], a
	ret
