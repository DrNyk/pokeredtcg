EnemyAttachDecision2:
xor a
.nextMonster
cp 6
jr nz, .NormalCheck
; if we fall to here, then wWhichPokemon went too far. No mon needs this energy. We may as well make it an option for retreat cost for the currently out-there Pokemon.
ld a, [wEnemyMonPartyPos]
ld [wWhichPokemon], a
ret
.NormalCheck
ld [wWhichPokemon], a
ld hl, wEnemyMon1HP
ld bc, PARTYMON_STRUCT_LENGTH
call AddNTimes
ld a, [hli]
or [hl]
jr nz, .ThisMonIsAlive
ld a, [wWhichPokemon]
inc a
.nextMonster_launchpoint
jr .nextMonster

.ThisMonIsAlive
ld bc, 6 ; not sure what constants this relates to
add hl, bc ; this should bump hl to wEnemyMonNMoves
ld d, 4
.topLoop
ld a, [hl]
and a
push hl ; to cycle through the Moves ; comes before branch to keep in sync
push de ; keeing track of how many moves I've checked
jr z, .nextMove ; this was an empty move slot, don't waste our time

call MoveCheckPreRequisite ; e = secondary type, d = primary type, b = PPs
call FindTheBenchPP ; it moves hl to the wEnemyMonNPP and it sets in a [wEnemyBattleStatus3] *IF* the mon is the active mon, so I can test for transformed
bit TRANSFORMED, a
jr nz, .transformed
ld a, [wTempByteValue]
cp e
jr z, .secondaryTypeMatchesDrawnType
cp d
jr z, .primaryTypeMatchesDrawnType
ld a, $1
cp e
jr z, .secondaryTypeIsColorless
cp d
jr z, .primaryTypeIsColorless
; fall through here, and this energy isn't applicable. I.e. drew Grass and we're looking at Fire Punch.
jr .nextMove
.transformed
ld a, b ; b holds the energy cost of PP1|PP2. I want to get these to sum together.
add a ; now it's PP1+PP2|PP1+PP2
and $0f ; now it's 0|PP1+PP2
ld b, a
call ColorlessEnergyCheck ; returns in a how much total energy I have
cp b ; energy I have minus energy I need
jr c, .iCanUseThisEnergy
jr .nextMove ; I don't need this energy
.secondaryTypeMatchesDrawnType
	call GetCurrentEnergyMatchingDrawnType
	; register b has PP1|PP2 in it. I am curious about PP2. 
	ld c, a ; store my current energy for the drawn type here
	ld a, b
	and $0f ; this is just PP2 now
	cp c ; energy required minus current energy
	jr z, .secondaryTypeMatchesDrawnTypeSuffices
	jr c, .secondaryTypeMatchesDrawnTypeSuffices
	; fall through if nc + nz
	; I need this type
	jr .iCanUseThisEnergy
	.secondaryTypeMatchesDrawnTypeSuffices
	; if the primary type is colorless, then I want to see if I still need excess energy to count as colorless
	ld a, COLORLESS ; $1
	cp d
	jr nz, .nextMove ; the secondary typing is not colorless, nothing more to evaluate
	ld a, b
	and $f0
	swap a
	ld b, a ; this is now the PP1 colorless requirement alone
	; c is still holding onto my PP2 colored energy
	call ColorlessEnergyCheck ; returns in a how much total energy I have
	sub c ; subtract the energy requirements of the colored component. If it got this far, this will result in a zero or positive value in a
	sub b
	jr c, .iCanUseThisEnergy
	jr .nextMove
.primaryTypeMatchesDrawnType
	call GetCurrentEnergyMatchingDrawnType
	ld c, a ; store my current energy for the drawn type here
	ld a, b
	and $f0 ; this is just PP1 now
	swap a
	cp c ; energy required minus current energy
	jr z, .primaryTypeMatchesDrawnTypeSuffices
	jr c, .primaryTypeMatchesDrawnTypeSuffices
	jr .iCanUseThisEnergy
	.primaryTypeMatchesDrawnTypeSuffices
	ld a, COLORLESS ; $1
	cp e
	jr nz, .nextMove
	ld a, b
	and $0f 
	ld b, a ; this is just PP2 now, the colorless energy requirements
	call ColorlessEnergyCheck
	sub c ; subtract energy requirements of the colored component
	sub b
	jr c, .iCanUseThisEnergy
	jr .nextMove
.secondaryTypeIsColorless ; if we get here, the primary type of this move is NOT WHAT WE DREW. However, we can check if it still needs colorless energy
	ld a, d ; put the primary type into a
	call GetCurrentEnergyMatchingDrawnType ; not really the DrawnType, but ya know
	ld c, a ; store the current energy of the primary type here
	; what I need is to find the minimum of the current primary energy vs the move's primary requirements
	; and then that I will subtract off the result of the ColorlessEnergyCheck. That subtraction will come from c. The goal is to put the smaller number in c
	ld a, b ; PP1|PP2
	and $f0
	swap a ; 0|PP1
	cp c ; PP1 Requirements minus Current Energy. If zero, they're equal. If >0, then Requirements is larger.
	jr nc, .currentEnergyIsTheMinimum ; don't touch c
	ld c, a ; otherwise, the current energy was larger, and I want c to hold the PP1 requirements instead
	.currentEnergyIsTheMinimum
	ld a, b ; we're going to get this to be the PP2 which is colorless energy requirements
	and $0f
	ld b, a ; just PP2 now
	call ColorlessEnergyCheck
	sub c ; subtract MIN(CurrentEnergy|EnergyRequirements) of the colored component. In a mono-color energy situation, the CurrentEnergy is what would subtract from that and it cannot go negative. And if the smaller EnergyRequirements was subbed, it would stay positive.
	sub b
	jr c, .iCanUseThisEnergy
	jr .nextMove ; I have enough colorless energy for this move
.primaryTypeIsColorless
	ld a, e
	call GetCurrentEnergyMatchingDrawnType
	ld c, a ; store the current energy of the secondary type here
	ld a, b ; PP1|PP2
	and $0f
	cp c
	jr nc, .currentEnergyIsTheMinimum2
	ld c, a ; otherwise the current energy was larger, and I want c to hold the PP2 requirements instead
	.currentEnergyIsTheMinimum2
	ld a, b
	and $f0
	swap a
	ld b, a ; just PP1 now
	call ColorlessEnergyCheck
	sub c
	sub b
	jr nc, .nextMove
	; fall through on the "jr c, .iCanUseThisEnergy"
.iCanUseThisEnegy ; currently have stack of hl|de
pop hl
pop de
ret ; whatever [wWhichPokemon] is set to is what I want it to be

.nextMove ; currently have stack of hl|de
pop de
pop hl
inc hl
dec d
jr nz, .topLoop
; otherwise we fell through here and all moves have been checked
ld a, [wWhichPokemon]
inc a
jr .nextMonster_launchpoint






FindTheBenchPP:
	push bc ; caches the PP requirements
ld a, [wWhichPokemon]
ld hl, wEnemyMon1PP
ld bc, PARTYMON_STRUCT_LENGTH
call AddNTimes ; now it points to wEnemyMonNPP

ld b, a ; wWhichPokemon
ld a, [wEnemyMonPartyPos]
cp b
ld a, [wEnemyBattleStatus3] ; the active mon is out there, and MoveCheck.Player comes in with a checking if the mon is transformed
jr z, .activemon
xor a
.activemon
	pop bc ; restores thsoe PP requirements
ret

GetCurrentEnergyMatchingDrawnType:
dec a
dec a
call srlAAndIncrementPPByteOffset
ld a, [hl]
jr c, .noSwap
swap a
.noSwap
and $0f
ret