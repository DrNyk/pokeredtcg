; does nothing since no stats are ever selected (barring glitches)
DoubleSelectedStats:
	ldh a, [hWhoseTurn]
	and a
	ld a, [wPlayerStatsToDouble]
	ld hl, wBattleMonAttack + 1
	jr z, .notEnemyTurn
	ld a, [wEnemyStatsToDouble]
	ld hl, wEnemyMonAttack + 1
.notEnemyTurn
	ld c, 4
	ld b, a
.loop
	srl b
	call c, .doubleStat
	inc hl
	inc hl
	dec c
	ret z
	jr .loop

.doubleStat
	ld a, [hl]
	add a
	ld [hld], a
	ld a, [hl]
	rl a
	ld [hli], a
	ret

; does nothing since no stats are ever selected (barring glitches)
HalveSelectedStats:
	ldh a, [hWhoseTurn]
	and a
	ld a, [wPlayerStatsToHalve]
	ld hl, wBattleMonAttack
	jr z, .notEnemyTurn
	ld a, [wEnemyStatsToHalve]
	ld hl, wEnemyMonAttack
.notEnemyTurn
	ld c, 4
	ld b, a
.loop
	srl b
	call c, .halveStat
	inc hl
	inc hl
	dec c
	ret z
	jr .loop

.halveStat
	ld a, [hl]
	srl a
	ld [hli], a
	rr [hl]
	or [hl]
	jr nz, .nonzeroStat
	ld [hl], 1
.nonzeroStat
	dec hl
	ret

LoadPlayerBackPic:
	ld a, [wBattleType]
	dec a ; is it the old man tutorial?
	ld de, RedPicBack
	jr nz, .next
	ld de, OldManPicBack
.next
	ld a, BANK(RedPicBack)
	ASSERT BANK(RedPicBack) == BANK(OldManPicBack)
	call UncompressSpriteFromDE
	predef ScaleSpriteByTwo
	ld hl, wShadowOAM
	xor a
	ldh [hOAMTile], a ; initial tile number
	ld b, $7 ; 7 columns
	ld e, $a0 ; X for the left-most column
.loop ; each loop iteration writes 3 OAM entries in a vertical column
	ld c, $3 ; 3 tiles per column
	ld d, $38 ; Y for the top of each column
.innerLoop ; each loop iteration writes 1 OAM entry in the column
	ld [hl], d ; OAM Y
	inc hl
	ld [hl], e ; OAM X
	ld a, TILE_HEIGHT
	add d ; increase Y by height of tile
	ld d, a
	inc hl
	ldh a, [hOAMTile]
	ld [hli], a ; OAM tile number
	inc a ; increment tile number
	ldh [hOAMTile], a
	inc hl
	dec c
	jr nz, .innerLoop
	ldh a, [hOAMTile]
	add $4 ; increase tile number by 4
	ldh [hOAMTile], a
	ld a, TILE_WIDTH
	add e ; increase X by width of tile
	ld e, a
	dec b
	jr nz, .loop
	ld de, vBackPic
	call InterlaceMergeSpriteBuffers
	ld a, RAMG_SRAM_ENABLE
	ld [rRAMG], a
	xor a
	ld [rRAMB], a
	ld hl, vSprites
	ld de, sSpriteBuffer1
	ldh a, [hLoadedROMBank]
	ld b, a
	ld c, PIC_SIZE
	call CopyVideoData
	xor a
	ld [rRAMG], a
	ld a, $31
	ldh [hStartTileID], a
	hlcoord 1, 5
	predef_jump CopyUncompressedPicToTilemap