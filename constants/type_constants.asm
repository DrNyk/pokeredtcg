; TypeNames indexes (see data/types/names.asm)
	const_def

	const NULL_TYPE       ; $00 	$00
	const COLORLESS     ; $01		$01
	const FIGHTING       ; $02		$02		0X
	const FIRE       ; $03			$04		X0
	const WATER       ; $04			$08		0X
	const GRASS         ; $05		$10		X0
	const LIGHTNING         ; $06	$20		0X
	const PSYCHIC_TYPE          ; $07$40	X0

DEF NUM_TYPES EQU const_value

	const_def
	
	const PHYSICAL_ATTACK ; $00
	const SPECIAL_ATTACK ; $01
	
	DEF STATUS_ATTACK EQU $01 ; also $01
	
