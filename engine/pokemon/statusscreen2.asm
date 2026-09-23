.PrintPP
	ld a, [hli] ; it's at wLoadedMonMoves, thats $cfa0/1/2/3 .. at /4 is wLoadedMonOTID
	and a ; this just checks for early termination if less than 4 moves
	jr z, .PPDone
	push bc
	push hl
	push de
	; a is our move index of slot1 to start
	ld hl, Moves
	ld bc, MOVE_LENGTH
	call AddNTimes
	ld de, wMoveData
	ld a, BANK(Moves)
	call FarCopyData
	; animation ; effect ; power ; physical/special | type2 | type1 ; accuracy ; pp1 | pp2
	ld de, wMoveData + 3 ; gets me the types with physical/special prefix
	ld a, [de]
	and $77 ; this strips the physical/special prefix right out of them
	ld b, a ; b is going to hold our types
	inc de
	inc de
	ld a, [de]
	ld c, a ; cache real quick our pps
	ld h, a ; 
	swap h
	ld a, $0f
	and h
	ld h, a ; h now holds pp1
	ld a, $0f
	and c
	ld c, a ; c now holds our pp2
	ld a, b
	and $07 ; now it's just type1
	add $BF ; this is the text character for our type symbol
	; ah ha, we used decoord to paint the initial PP
	pop de ; this restores the 14, 10 for our first pp
	push de
.printFirstType	
	ld [de], a
	inc de
	dec h
	jr nz, .printFirstType
	xor a
	; now we get ready for the second type
	and c
	jr z, .escapeEarly ; there's no second type to print
	ld a, b
	swap a
	and $07 ; now it's just type2
	add $BF ; this is the text charater for our symbol
.printSecondType
	ld [de], a
	inc de
	dec c
	jr nz, .printSecondType
.escapeEarly
	pop de ; this restores the 14, 10 for our first PP
	ld hl, SCREEN_WIDTH * 2
	add hl, de
	ld d, h
	ld e, l ; now de points to the next row for PP needs
	pop hl
	pop bc