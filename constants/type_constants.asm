; TypeNames indexes (see data/types/names.asm)
	const_def

	const NULL_TYPE       ; $00
	const COLORLESS     ; $01
	const FIGHTING       ; $02
	const FIRE       ; $03
	const WATER       ; $04
	const GRASS         ; $05
	const LIGHTNING         ; $06
	const PSYCHIC_TYPE          ; $07
	const DARK        ; $08
	const METAL	   ; $09

DEF NUM_TYPES EQU const_value

	const_def
	
	const PHYSICAL_ATTACK ; $00
	const SPECIAL_ATTACK ; $01
	const STATUS_ATTACK ; $02
