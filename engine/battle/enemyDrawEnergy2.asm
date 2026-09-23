EnemyAttachDecision:
ld a, [wEnemyMonPartyPos] ; going to start with the active mon, for switchers like Agatha / Jugglers
ld e, $FF
.nextMonster
cp 6
jr nz, .NormalCheck
; if we fall to here, then wWhichPokemon went too far. No mon needs this energy. We may as well make it an option for retreat cost for the currently out-there Pokemon.
		; ld a, [wEnemyMonPartyPos]
		; ld [wWhichPokemon], a
		; ret
inc e ; goes from $FF to 0 the first time we restart looking through the party
ld a, [wEnemyMonPartyPos]
ld [wWhichPokemon], a
ret nz ; if e has increased from 0 to 1, that means we have looked at the party between 1 and 2 times (latter half of party twice, first half once) and NOBODY wants this energy. So default to active mon.
; if e were still 0, then we'll make sure a is zero for the drop through.
xor a ; wrap around to slot 0 .. could do ld a, e just as well.
.NormalCheck
ld [wWhichPokemon], a
ld b, a
ld a, [wEnemyMonPartyPos]
cp b
ld a, [wWhichPokemon] ; this really could go after the jr z to follow. Because if they were the same, nothing changed on this value. But, whatever.
ld hl, wEnemyMonMoves
ld d, 5 ; when we jump down to the .activeMon or .aliveMon, the .topLoop is expecting d = 4 to start and it'll decrement it repeatedly. (UPDATE. I MADE THIS 5, BECAUSE I DO THE DEC D LOGIC AT THE BEGINNING OF .topLoop
jr z, .activeMon ; we know the active mon is alive. And if they are transformed, then we want to use their wEnemyMonMoves address instead.
; otherwise, this Pokemon is on the bench so we need to align with the bench data
ld hl, wEnemyMon1HP
ld bc, PARTYMON_STRUCT_LENGTH ; b is set to zero
call AddNTimes
ld a, [hli]
or [hl]
ld c, 6 ; b is set to zero, so let's make it 6. "ld bc, 6" not sure what constants this relates to
add hl, bc ; this should bump hl to wEnemyMonNMoves
jr nz, .alivemon ; the jr logic comes later to try to cram as many bytes above this LaunchPoint as possible to get it in range of the jr at very end
.nextMonsterLaunchPoint
ld a, [wWhichPokemon]
inc a
jr .nextMonster

.activeMon ; hl needs to be wEnemyMonMoves
.alivemon
.topLoop
dec d
jr z, .nextMonsterLaunchPoint ; all the attacks have been checked
ld a, [hli]
and a
push hl ; to cycle through the Moves ; comes before branch to keep in sync
push de ; keeing track of how many moves I've checked
jr z, .nextMove ; this was an empty move slot, don't waste our time

call MoveCheckPreRequisite ; e = secondary type, d = primary type, b = PPs
call FindTheBenchPP ; it moves hl to the wEnemyMonNPP and it sets in a [wEnemyBattleStatus3] *IF* the mon is the active mon, so I can test for transformed
bit TRANSFORMED, a
jr nz, .transformed ; special situation where the PP is treated as colorless
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
swap a ; to PP2|PP1
add b ; now it's PP1+PP2|PP1+PP2
and $0f ; now it's 0|PP1+PP2
ld b, a
call ColorLessEnergyCheck ; returns in a how much total energy I have
cp b ; energy I have minus energy I need
jr c, .iCanUseThisEnergy
jr .nextMove ; I don't need this energy
.secondaryTypeMatchesDrawnType
	ld c, e ; secondary type caches into c
	ld e, d ; primary type overwrites secondary type
	ld d, c ; cached secondary type overwrites primary type
	swap b ; now it's PP2|PP1
	; fall through here and the math should work out. It's as if the drawn type matches the primary type, we'll check on the secondary type later to be colorless, and with the PP's swapped it aligns with the type checking we're doing.
.primaryTypeMatchesDrawnType
	call GetCurrentEnergyMatchingDrawnType
	ld c, a ; store my current energy for the drawn type here
	ld a, b
	and $f0 ; this is just PP1 now
	swap a
	cp c ; energy required minus current energy
	jr z, .DrawnTypeSuffices
	jr c, .DrawnTypeSuffices
	jr .iCanUseThisEnergy
	.DrawnTypeSuffices
	ld a, COLORLESS ; $1
	cp e
	jr nz, .nextMove
	ld a, b
	and $0f 
	ld b, a ; this is just the colorless energy requirements
	call ColorLessEnergyCheck
	sub c ; subtract energy requirements of the colored component
	sub b
	jr c, .iCanUseThisEnergy
	jr .nextMove
.secondaryTypeIsColorless ; if we get here, the primary type of this move is NOT WHAT WE DREW. However, we can check if it still needs colorless energy
	ld c, e ; secondary type (COLORLESS) caches into c
	ld e, d ; primary type (COLORED=/=DRAWN) overwrites secondary type
	ld d, c ; cached secondary type overwrites primary type
	swap b ; now it's PP2|PP1
	; fall through here and the math should work out. 
.primaryTypeIsColorless
	ld a, e ; we load the colored type
	call GetCurrentEnergyMatchingDrawnType ; not really the drawn type
	ld c, a ; store the current energy of the colored type here
	ld a, b ; colorlessPP|coloredPP
	and $0f
	cp c
	jr nc, .currentEnergyIsTheMinimum2
	ld c, a ; otherwise the current energy was larger, and I want c to hold the coloredPP requirements instead
	.currentEnergyIsTheMinimum2
	ld a, b
	and $f0
	swap a
	ld b, a ; just PP1 now
	call ColorLessEnergyCheck
	sub c
	sub b
	jr c, .iCanUseThisEnergy

.nextMove ; currently have stack of hl|de
pop de
pop hl
;inc hl
jr .topLoop ; check the next attack

.iCanUseThisEnergy ; currently have stack of hl|de
pop de
pop hl
ret ; whatever [wWhichPokemon] is set to is what I want it to be






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
push hl ; cache my hl for the start of the PP "Bar"
call srlAAndIncrementPPByteOffset
ld a, [hl]
pop hl ; restore the hl at the start of the PP "Bar"
jr c, .noSwap
swap a
.noSwap
and $0f
ret