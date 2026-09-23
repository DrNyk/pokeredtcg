; creates a set of moves that may be used and returns its address in hl
; unused slots are filled with 0, all used slots may be chosen with equal probability
AIEnemyTrainerChooseMoves:
	; ld a, $a
	; ld hl, wBuffer ; init temporary move selection array. Only the moves with the lowest numbers are chosen in the end
	; ld [hli], a   ; move 1
	; ld [hli], a   ; move 2
	; ld [hli], a   ; move 3
	; ld [hl], a    ; move 4
	; ld a, [wEnemyDisabledMove] ; forbid disabled move (if any)
	; swap a
	; and $f
	; jr z, .noMoveDisabled
	; ld hl, wBuffer
	; dec a
	; ld c, a
	; ld b, $0
	; add hl, bc    ; advance pointer to forbidden move
	; ld [hl], $50  ; forbid (highly discourage) disabled move
	
	ld b, $4
	ld de, wBuffer
	ld hl, wEnergyStringBuffer ; holds my currently viable moves
.nextWeight
	ld a, [hli]
	and a
	ld a, $a ; normal AI preference for moves
	jr nz, .validmove ; if the hl entry was a move ID, we can use it.
	ld a, $50 ; heavily discourage move because that slot was not viable per AnyMoveToSelect
.validmove
	ld [de], a
	inc de
	dec b
	jr nz, .nextWeight
	
.noMoveDisabled
	ld hl, TrainerClassMoveChoiceModifications
	ld a, [wTrainerClass]
	ld b, a
.loopTrainerClasses
	dec b
	jr z, .readTrainerClassData
.loopTrainerClassData
	ld a, [hli]
	and a
	jr nz, .loopTrainerClassData
	jr .loopTrainerClasses
.readTrainerClassData
	ld a, [hl]
	and a
	jp z, .useOriginalMoveSet
	push hl
.nextMoveChoiceModification
	pop hl
	ld a, [hli]
	and a
	jr z, .loopFindMinimumEntries
	push hl
	ld hl, AIMoveChoiceModificationFunctionPointers
	dec a
	add a
	ld c, a
	ld b, 0
	add hl, bc    ; skip to pointer
	ld a, [hli]   ; read pointer into hl
	ld h, [hl]
	ld l, a
	ld de, .nextMoveChoiceModification  ; set return address
	push de
	jp hl         ; execute modification function
.loopFindMinimumEntries ; all entries will be decremented sequentially until one of them is zero
	ld hl, wBuffer  ; temp move selection array
	ld de, wEnemyMonMoves  ; enemy moves
	ld c, NUM_MOVES
.loopDecrementEntries
	ld a, [de]
	inc de
	and a
	jr z, .loopFindMinimumEntries
	dec [hl]
	jr z, .minimumEntriesFound
	inc hl
	dec c
	jr z, .loopFindMinimumEntries
	jr .loopDecrementEntries
.minimumEntriesFound
	ld a, c
.loopUndoPartialIteration ; undo last (partial) loop iteration
	inc [hl]
	dec hl
	inc a
	cp NUM_MOVES + 1
	jr nz, .loopUndoPartialIteration
	ld hl, wBuffer  ; temp move selection array
	ld de, wEnergyStringBuffer ; wEnemyMonMoves  ; enemy moves
	ld c, NUM_MOVES
.filterMinimalEntries ; all minimal entries now have value 1. All other slots will be disabled (move set to 0)
	ld a, [de]
	and a
	jr nz, .moveExisting
	ld [hl], a
.moveExisting
	ld a, [hl]
	dec a
	jr z, .slotWithMinimalValue
	xor a
	ld [hli], a     ; disable move slot
	jr .next
.slotWithMinimalValue
	ld a, [de]
	ld [hli], a     ; enable move slot
.next
	inc de
	dec c
	jr nz, .filterMinimalEntries
	ld hl, wBuffer    ; use created temporary array as move set
	ret
.useOriginalMoveSet
	; ld hl, wEnemyMonMoves    ; use original move set
	ld hl, wEnergyStringBuffer ; act like a wild mon and randomly choose anything valid
	ret

AIMoveChoiceModificationFunctionPointers:
	dw AIMoveChoiceModification1
	dw AIMoveChoiceModification2
	dw AIMoveChoiceModification3
	dw AIMoveChoiceModification4 ; unused, does nothing

; discourages moves that cause no damage but only a status ailment if player's mon already has one
AIMoveChoiceModification1:
	ld a, [wBattleMonStatus]
	and a
	ret z ; return if no status ailment on player's mon
	ld hl, wBuffer - 1 ; temp move selection array (-1 byte offset)
	ld de, wEnergyStringBuffer ; wEnemyMonMoves ; enemy moves
	ld b, NUM_MOVES + 1
.nextMove
	dec b
	ret z ; processed all 4 moves
	inc hl
	ld a, [de]
	and a
	;ret z ; no more moves in move set
	inc de
	jr z, .nextMove ; this move is unavailable due to Disable or Insufficient PP, try the next one
	call ReadMove
	ld a, [wEnemyMovePower]
	and a
	jr nz, .nextMove
	ld a, [wEnemyMoveEffect]
	push hl
	push de
	push bc
	ld hl, StatusAilmentMoveEffects
	ld de, 1
	call IsInArray
	pop bc
	pop de
	pop hl
	jr nc, .nextMove
	ld a, [hl]
	add $5 ; heavily discourage move
	ld [hl], a
	jr .nextMove

StatusAilmentMoveEffects:
	db EFFECT_01 ; unused sleep effect
	db SLEEP_EFFECT
	db POISON_EFFECT
	db PARALYZE_EFFECT
	db -1 ; end

; slightly encourage moves with specific effects.
; in particular, stat-modifying moves and other move effects
; that fall in-between
AIMoveChoiceModification2:
	ld a, [wAILayer2Encouragement]
	cp $1
	ret nz
	ld hl, wBuffer - 1 ; temp move selection array (-1 byte offset)
	ld de, wEnergyStringBuffer ; wEnemyMonMoves ; enemy moves
	ld b, NUM_MOVES + 1
.nextMove
	dec b
	ret z ; processed all 4 moves
	inc hl
	ld a, [de]
	and a
	;ret z ; no more moves in move set
	inc de
	jr z, .nextMove ; this move is unavailable due to Disable or Insufficient PP, try the next one
	call ReadMove
	ld a, [wEnemyMoveEffect]
	cp ATTACK_UP1_EFFECT
	jr c, .nextMove
	cp BIDE_EFFECT
	jr c, .preferMove
	cp ATTACK_UP2_EFFECT
	jr c, .nextMove
	cp POISON_EFFECT
	jr c, .preferMove
	jr .nextMove
.preferMove
	dec [hl] ; slightly encourage this move
	jr .nextMove

; encourages moves that are effective against the player's mon (even if non-damaging).
; discourage damaging moves that are ineffective or not very effective against the player's mon,
; unless there's no damaging move that deals at least neutral damage
AIMoveChoiceModification3:
	ld hl, wBuffer - 1 ; temp move selection array (-1 byte offset)
	ld de, wEnergyStringBuffer ; wEnemyMonMoves ; enemy moves
	ld b, NUM_MOVES + 1
.nextMove
	dec b
	ret z ; processed all 4 moves
	inc hl
	ld a, [de]
	and a
	;ret z ; no more moves in move set
	inc de
	jr z, .nextMove ; this move is unavailable due to Disable or Insufficient PP, try the next one
	call ReadMove
	push hl
	push bc
	push de
	callfar AIGetTypeEffectiveness
	pop de
	pop bc
	pop hl
	ld a, [wTypeEffectiveness]
	cp $10
	jr z, .nextMove
	jr c, .notEffectiveMove
	dec [hl] ; slightly encourage this move
	jr .nextMove
.notEffectiveMove ; discourages non-effective moves if better moves are available
	push hl
	push de
	push bc
	ld a, [wEnemyMoveType]
	ld d, a
	ld hl, wEnergyStringBuffer ; wEnemyMonMoves  ; enemy moves
	ld b, NUM_MOVES + 1
	ld c, $0
.loopMoves
	dec b
	jr z, .done
	ld a, [hli]
	and a
	jr z, .loopMoves ; .done
	call ReadMove
	ld a, [wEnemyMoveEffect]
	cp SUPER_FANG_EFFECT
	jr z, .betterMoveFound ; Super Fang is considered to be a better move
	cp SPECIAL_DAMAGE_EFFECT
	jr z, .betterMoveFound ; any special damage moves are considered to be better moves
	cp FLY_EFFECT
	jr z, .betterMoveFound ; Fly is considered to be a better move
	ld a, [wEnemyMoveType]
	cp d
	jr z, .loopMoves
	ld a, [wEnemyMovePower]
	and a
	jr nz, .betterMoveFound ; damaging moves of a different type are considered to be better moves
	jr .loopMoves
.betterMoveFound
	ld c, a
.done
	ld a, c
	pop bc
	pop de
	pop hl
	and a
	jr z, .nextMove
	inc [hl] ; slightly discourage this move
	jr .nextMove
AIMoveChoiceModification4:
	ret

ReadMove:
	push hl
	push de
	push bc
	dec a
	ld hl, Moves
	ld bc, MOVE_LENGTH
	call AddNTimes
	ld de, wEnemyMoveNum
	call CopyData
	pop bc
	pop de
	pop hl
	ret

INCLUDE "data/trainers/move_choices.asm"

INCLUDE "data/trainers/pic_pointers_money.asm"

INCLUDE "data/trainers/names.asm"

INCLUDE "engine/battle/misc.asm"

INCLUDE "engine/battle/read_trainer_party.asm"

INCLUDE "data/trainers/special_moves.asm"

INCLUDE "data/trainers/parties.asm"

TrainerAI:
	and a
	ld a, [wIsInBattle]
	dec a
	ret z ; if not a trainer, we're done here
	ld a, [wLinkState]
	cp LINK_STATE_BATTLING
	ret z ; if in a link battle, we're done as well
	ld a, [wTrainerClass] ; what trainer class is this?
	dec a
	ld c, a
	ld b, 0
	ld hl, TrainerAIPointers
	add hl, bc
	add hl, bc
	add hl, bc
	ld a, [wAICount]
	and a
	ret z ; if no AI uses left, we're done here
	inc hl
	inc a
	jr nz, .getpointer
	dec hl
	ld a, [hli]
	ld [wAICount], a
.getpointer
	ld a, [hli]
	ld h, [hl]
	ld l, a
	call Random
	jp hl

INCLUDE "data/trainers/ai_pointers.asm"

JugglerAI:
	cp 25 percent + 1
	ret nc
	jp AISwitchIfEnoughMons

BlackbeltAI:
	cp 13 percent - 1
	ret nc
	jp AIUseXAttack

GiovanniAI:
	cp 25 percent + 1
	ret nc
	jp AIUseGuardSpec

CooltrainerMAI:
	cp 25 percent + 1
	ret nc
	jp AIUseXAttack

CooltrainerFAI:
	; The intended 25% chance to consider switching will not apply.
	; Uncomment the line below to fix this.
	cp 25 percent + 1
	; ret nc
	ld a, 10
	call AICheckIfHPBelowFraction
	jp c, AIUseHyperPotion
	ld a, 5
	call AICheckIfHPBelowFraction
	ret nc
	jp AISwitchIfEnoughMons

BrockAI:
; if his active monster has a status condition, use a full heal
	ld a, [wEnemyMonStatus]
	and a
	ret z
	jp AIUseFullHeal

MistyAI:
	cp 25 percent + 1
	ret nc
	jp AIUseXDefend

LtSurgeAI:
	cp 25 percent + 1
	ret nc
	jp AIUseXSpeed

ErikaAI:
	cp 50 percent + 1
	ret nc
	ld a, 10
	call AICheckIfHPBelowFraction
	ret nc
	jp AIUseSuperPotion

KogaAI:
	cp 25 percent + 1
	ret nc
	jp AIUseXAttack

BlaineAI:
	cp 25 percent + 1
	ret nc
	jp AIUseSuperPotion

SabrinaAI:
	cp 25 percent + 1
	ret nc
	ld a, 10
	call AICheckIfHPBelowFraction
	ret nc
	jp AIUseHyperPotion

Rival2AI:
	cp 13 percent - 1
	ret nc
	ld a, 5
	call AICheckIfHPBelowFraction
	ret nc
	jp AIUsePotion

Rival3AI:
	cp 13 percent - 1
	ret nc
	ld a, 5
	call AICheckIfHPBelowFraction
	ret nc
	jp AIUseFullRestore

LoreleiAI:
	cp 50 percent + 1
	ret nc
	ld a, 5
	call AICheckIfHPBelowFraction
	ret nc
	jp AIUseSuperPotion

BrunoAI:
	cp 25 percent + 1
	ret nc
	jp AIUseXDefend

AgathaAI:
	cp 8 percent
	jp c, AISwitchIfEnoughMons
	cp 50 percent + 1
	ret nc
	ld a, 4
	call AICheckIfHPBelowFraction
	ret nc
	jp AIUseSuperPotion

LanceAI:
	cp 50 percent + 1
	ret nc
	ld a, 5
	call AICheckIfHPBelowFraction
	ret nc
	jp AIUseHyperPotion

GenericAI:
	and a ; clear carry
	ret

; end of individual trainer AI routines

DecrementAICount:
	ld hl, wAICount
	dec [hl]
	scf
	ret

AIPlayRestoringSFX:
	ld a, SFX_HEAL_AILMENT
	jp PlaySoundWaitForCurrent

AIUseFullRestore:
	call AICureStatus
	ld a, FULL_RESTORE
	ld [wAIItem], a
	ld de, wHPBarOldHP
	ld hl, wEnemyMonHP + 1
	ld a, [hld]
	ld [de], a
	inc de
	ld a, [hl]
	ld [de], a
	inc de
	ld hl, wEnemyMonMaxHP + 1
	ld a, [hld]
	ld [de], a
	inc de
	ld [wHPBarMaxHP], a
	ld [wEnemyMonHP + 1], a
	ld a, [hl]
	ld [de], a
	ld [wHPBarMaxHP+1], a
	ld [wEnemyMonHP], a
	jr AIPrintItemUseAndUpdateHPBar

AIUsePotion:
; enemy trainer heals his monster with a potion
	ld a, POTION
	ld b, 20
	jr AIRecoverHP

AIUseSuperPotion:
; enemy trainer heals his monster with a super potion
	ld a, SUPER_POTION
	ld b, 50
	jr AIRecoverHP

AIUseHyperPotion:
; enemy trainer heals his monster with a hyper potion
	ld a, HYPER_POTION
	ld b, 200
	; fallthrough

AIRecoverHP:
; heal b HP and print "trainer used $(a) on pokemon!"
	ld [wAIItem], a
	ld hl, wEnemyMonHP + 1
	ld a, [hl]
	ld [wHPBarOldHP], a
	add b
	ld [hld], a
	ld [wHPBarNewHP], a
	ld a, [hl]
	ld [wHPBarOldHP+1], a
	ld [wHPBarNewHP+1], a
	jr nc, .next
	inc a
	ld [hl], a
	ld [wHPBarNewHP+1], a
.next
	inc hl
	ld a, [hld]
	ld b, a
	ld de, wEnemyMonMaxHP + 1
	ld a, [de]
	dec de
	ld [wHPBarMaxHP], a
	sub b
	ld a, [hli]
	ld b, a
	ld a, [de]
	ld [wHPBarMaxHP+1], a
	sbc b
	jr nc, AIPrintItemUseAndUpdateHPBar
	inc de
	ld a, [de]
	dec de
	ld [hld], a
	ld [wHPBarNewHP], a
	ld a, [de]
	ld [hl], a
	ld [wHPBarNewHP+1], a
	; fallthrough

AIPrintItemUseAndUpdateHPBar:
	call AIPrintItemUse_
	hlcoord 2, 2
	xor a
	ld [wHPBarType], a
	predef UpdateHPBar2
	jp DecrementAICount

AISwitchIfEnoughMons:
; enemy trainer switches if there are 2 or more unfainted mons in party
	ld a, [wEnemyPartyCount]
	ld c, a
	ld hl, wEnemyMon1HP

	ld d, 0 ; keep count of unfainted monsters

	; count how many monsters haven't fainted yet
.loop
	ld a, [hli]
	ld b, a
	ld a, [hld]
	or b
	jr z, .Fainted ; has monster fainted?
	inc d
.Fainted
	push bc
	ld bc, PARTYMON_STRUCT_LENGTH
	add hl, bc
	pop bc
	dec c
	jr nz, .loop

	ld a, d ; how many available monsters are there?
	cp 2    ; don't bother if only 1
	jp nc, SwitchEnemyMon
.wipecarryflagthenreturn
	and a
	ret
	
ColorLessEnergyCheck_TrainerAIBank:
	push bc
	push hl
	ld b, 3
	xor a
	ld c, a ; accumulator
	.loop
	ld a, [hl] 
	and $f
	add c
	ld c, a
	ld a, [hli]
	swap a
	and $f
	add c
	ld c, a
	dec b
	jr nz, .loop
	pop hl
	pop bc
	; all 6 nybbles have been summed and put in a
	ret

SwitchEnemyMon:

; prepare to withdraw the active monster: copy HP, party pos, and status to roster
	;ld b, b
	ld a, [wEnemyMonType1]
	and $F0
	swap a ; this is my retreat cost
	ld b, a ; the amount of energy I need to flee
	ld hl, wEnemyMonPP
	call ColorLessEnergyCheck_TrainerAIBank
	cp b
	jr c, AISwitchIfEnoughMons.wipecarryflagthenreturn ; not enough energy
	push hl
	call AIFindDesiredEnergyTypes ; clobbers everything. Returns in b positive mask (types wanted) and in c negative mask (types to discard)
	pop hl ;ld hl, wEnemyMonPP
	ld de, wEnergyStringBuffer ; I'm going to play around with AI PP here...
	ld a, [hli]
	ld [de], a
	inc de
	ld a, [hli]
	ld [de], a
	inc de
	ld a, [hl]
	ld [de], a
	inc de
	ld a, $AA ; my stop signal
	ld [de], a ; now wEnergyStringBuffer is PP(Fighting|Fire), PP(Water|Grass), PP(Lightning|Psychic), and $AA
	
	; going into here, c are the types I want to discard!
	; i will overwrite b as I don't care about what I keep, per se.
	ld hl, wEnergyStringBuffer
	ld a, [wEnemyMonType1]
	and $F0
	swap a ; this is my retreat cost
	ld b, a ; how much energy I need to discard
	ld d, $10 ; for high nibble deductions
	ld e, $2 ; using as kind of a counter to how many times I've tried this passover
.highnibblecheck
	srl c
	jr nc, .lownibblecheck
.highnibblesubtractloop
	ld d, $10
	ld a, [hl]
	sub d
	jr c, .lownibblecheck ; we could not accept this deduction, so move on to the next energy
	ld [hl], a
	dec b
	jr z, .PPCostPaid
	jr .highnibblesubtractloop
.lownibblecheck
	srl c
	jr nc, .next
	ld a, [hl]
	and $07
	jr z, .next ; there's no more energy to deduct on this lownibble PP
	dec [hl]
	dec b
	jr z, .PPCostPaid
	jr .lownibblecheck
.next
	inc hl
	ld a, $AA
	cp [hl]
	jr nz, .highnibblecheck
; fall to here means hl has progressed passed all the PP in wEnergyStringBuffer
; and it means that we still have energy cost to pay in register b
	ld hl, wEnergyStringBuffer ; reset this
	ld c, %00111111 ; check all the types next time
	dec e
	jr z, .highnibblecheck ; we are going on our third pass! This "has" to guarantee it works
	; otherwise, if we have only had one pass done, our c "negative mask" should exclude STAB type
	ld a, [wEnemyMonType1]
	and $07 ; this is my Pokemon's type
	dec a ; disregard colorless
	jr z, .highnibblecheck
	ld d, $0
	scf
.tryagain
	rl d
	dec a
	jr nz, .tryagain
; fall through here when the STAB type is met
	ld a, d
	ld d, $10 ; restore my d of $10 here for the next loop through for high nibble checks
	xor c ; say I have a fighting type. It's a register become %00000001. xor with %00111111 yields %00111110 meaning check if any non-fighting energy can be discarded this loop.
	ld c, a
	jr .highnibblecheck
.PPCostPaid	; could be fortunate that unwanted PP got discarded, or we had to throw away some additional PP
	ld hl, wEnergyStringBuffer
	ld de, wEnemyMonPP
	ld a, [hli]
	ld [de], a
	inc de
	ld a, [hli]
	ld [de], a
	inc de
	ld a, [hl]
	ld [de], a
	
	; back to vanilla
	ld a, [wEnemyMonPartyPos]
	ld hl, wEnemyMon1HP
	ld bc, PARTYMON_STRUCT_LENGTH
	call AddNTimes
	ld d, h
	ld e, l
	ld hl, wEnemyMonHP
	ld bc, MON_STATUS + 1 - MON_HP ; also copies party pos in-between HP and status ; 4 bytes to copy. So it copies CFE6-7 (HP 2 bytes), CFE8 (don't care), and CFE9 (status) into wEnemyMonNHP-Status field...
	call CopyData ; this does dec bc to being 00
	
	; now do the same thing for PP
	
	ld a, [wEnemyMonPartyPos]
	ld hl, wEnemyMon1PP
	ld bc, PARTYMON_STRUCT_LENGTH
	call AddNTimes
	ld d, h
	ld e, l
	ld hl, wEnemyMonPP
	ld bc, 3
	call CopyData
	
	ld hl, AIBattleWithdrawText
	call PrintText

	; This wFirstMonsNotOutYet variable is abused to prevent the player from
	; switching in a new mon in response to this switch.
	ld a, 1
	ld [wFirstMonsNotOutYet], a
	callfar EnemySendOut
	xor a
	ld [wFirstMonsNotOutYet], a

	ld a, [wLinkState]
	cp LINK_STATE_BATTLING
	ret z
	scf
	ret

AIBattleWithdrawText:
	text_far _AIBattleWithdrawText
	text_end

AIUseFullHeal:
	call AIPlayRestoringSFX
	call AICureStatus
	ld a, FULL_HEAL
	jp AIPrintItemUse

AICureStatus:
; cures the status of enemy's active pokemon
	ld a, [wEnemyMonPartyPos]
	ld hl, wEnemyMon1Status
	ld bc, PARTYMON_STRUCT_LENGTH
	call AddNTimes
	xor a
	ld [hl], a ; clear status in enemy team roster
	ld [wEnemyMonStatus], a ; clear status of active enemy
	ld hl, wEnemyBattleStatus3
	res BADLY_POISONED, [hl]
	ret

AIUseXAccuracy: ; unreferenced
	call AIPlayRestoringSFX
	ld hl, wEnemyBattleStatus2
	set USING_X_ACCURACY, [hl]
	ld a, X_ACCURACY
	jp AIPrintItemUse

AIUseGuardSpec:
	call AIPlayRestoringSFX
	ld hl, wEnemyBattleStatus2
	set PROTECTED_BY_MIST, [hl]
	ld a, GUARD_SPEC
	jp AIPrintItemUse

AIUseDireHit: ; unreferenced
	call AIPlayRestoringSFX
	ld hl, wEnemyBattleStatus2
	set GETTING_PUMPED, [hl]
	ld a, DIRE_HIT
	jp AIPrintItemUse

AICheckIfHPBelowFraction:
; return carry if enemy trainer's current HP is below 1 / a of the maximum
	ldh [hDivisor], a
	ld hl, wEnemyMonMaxHP
	ld a, [hli]
	ldh [hDividend], a
	ld a, [hl]
	ldh [hDividend + 1], a
	ld b, 2
	call Divide
	ldh a, [hQuotient + 3]
	ld c, a
	ldh a, [hQuotient + 2]
	ld b, a
	ld hl, wEnemyMonHP + 1
	ld a, [hld]
	ld e, a
	ld a, [hl]
	ld d, a
	ld a, d
	sub b
	ret nz
	ld a, e
	sub c
	ret

AIUseXAttack:
	ld b, ATTACK_UP1_EFFECT
	ld a, X_ATTACK
	jr AIIncreaseStat

AIUseXDefend:
	ld b, DEFENSE_UP1_EFFECT
	ld a, X_DEFEND
	jr AIIncreaseStat

AIUseXSpeed:
	ld b, SPEED_UP1_EFFECT
	ld a, X_SPEED
	jr AIIncreaseStat

AIUseXSpecial:
	ld b, SPECIAL_UP1_EFFECT
	ld a, X_SPECIAL
	; fallthrough

AIIncreaseStat:
	ld [wAIItem], a
	push bc
	call AIPrintItemUse_
	pop bc
	ld hl, wEnemyMoveEffect
	ld a, [hld]
	push af
	ld a, [hl]
	push af
	push hl
	ld a, XSTATITEM_DUPLICATE_ANIM
	ld [hli], a
	ld [hl], b
	callfar StatModifierUpEffect
	pop hl
	pop af
	ld [hli], a
	pop af
	ld [hl], a
	jp DecrementAICount

AIPrintItemUse:
	ld [wAIItem], a
	call AIPrintItemUse_
	jp DecrementAICount

AIPrintItemUse_:
; print "x used [wAIItem] on z!"
	ld a, [wAIItem]
	ld [wNamedObjectIndex], a
	call GetItemName
	ld hl, AIBattleUseItemText
	jp PrintText

AIBattleUseItemText:
	text_far _AIBattleUseItemText
	text_end

AIFindDesiredEnergyTypes: ; clobbers everything. But returns in b the positive mask (these types wanted), and in c returns the negative mask (doesn't really need to be put on this mon).
	ld b, 0 ; b is a big time tracker that helps us look at all the moves 
	ld hl, wEnemyMonMoves
.grandloop
	ld de, wMoveData ; when I use FarCopyData, de gets shuffled along and starts overwriting other important data... So we just restore it. I could do a push and pop, but that's 2 more bytes...
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
	
