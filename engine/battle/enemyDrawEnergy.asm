EnemyAttachDecision:
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
ld b, b ; definitely need a debug byte here
;ld hl, wEnemyMon1Moves
ld d, 4
.topLoop
ld a, [hl]
and a
push hl ; to cycle through the Moves ; comes before branch to keep in sync
push de ; keeping track of how many moves I've checked
jr z, .nextMove


call MoveCheckPreRequisite ; e = secondary type, d = primary type, b = PPs

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
	


push hl ; ; now it points to wEnemyMonNPP
push de ; caches the types of seconday and primary of the attack
call MoveCheck.Player ; .EnemyDrawInsertionPoint .. it will return a = 2 if disabled. It will return a = 1 if not enough energy. It will return a = 0 if viable.
and a
pop de ; restores secondary and primary of the attack
pop hl ; restore to wEnemyMonNPP
jr z, .nextMove ; this attack is already viable, it doesn't need more energy
dec a
jr nz, .nextMove ; this attack is disabled
; now we need to pretend this type of energy can help out and make this attack viable
ld a, [wTempByteValue] ; the type we just drew. It has a minimal value of 2 and maximum value of 7. We need to subtract that off so it's 0-5
dec a
dec a
push hl ; keep a cache copy of wEnemyMonPP
call srlAAndIncrementPPByteOffset ; the call will have carry flag set if it's an attack we read the low nibble for
ld e, [hl] ; keep the current PP in e to restore later
ld a, $0F
jr c, .noSwap ; from the call above
swap a ; so it's $F0 instead
.noSwap
or [hl]
ld [hl], a ; stick a "super PP" check in here
ld a, [wWhichPokemon]
ld h, a ; h is being thrown away anyway so we'll use it for fodder
ld a, [wEnemyMonPartyPos]
cp h
ld a, [wEnemyBattleStatus3] ; the active mon is out there, and MoveCheck.Player comes in with a checking if the mon is transformed
jr z, .activemon2
xor a
.activemon2
pop hl ; to point back to wEnemyMonNPP
push hl ; keep a cache copy
push de
call MoveCheck.Player ; .EnemyDrawInsertionPoint
pop de
pop hl ; restore to wEnemyMonNPP yet again
and a
jr nz, .nextMove ; it did not help
; otherwise, IT DID HELP!
ld a, [wTempByteValue] ; the type we just drew. It has a minimal value of 2 and maximum value of 7. We need to subtract that off so it's 0-5
dec a
dec a
call srlAAndIncrementPPByteOffset
ld [hl], e ; put the pp back to where it was before these tests
pop de
pop hl ; we can exit this routine. [wWhichPokemon] is populated with the mon we want.
ret 
.nextMove
pop de ; should restore my counter, notably looking at d going from 4 down to 0
pop hl ; wEnemyMonNMoves + n
inc hl ; wEnemyMonNMoves + n + 1
dec d
jr nz, .topLoop
; otherwise we fell through here and all moves have been checked
ld a, [wWhichPokemon]
inc a
jr .nextMonster_launchpoint