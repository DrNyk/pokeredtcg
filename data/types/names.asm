TypeNames:
	table_width 2
	dw .NullType
	dw .Colorless
	dw .Fighting
	dw .Fire
	dw .Water
	dw .Grass
	dw .Lightning
	dw .Psychic
	dw .Dark
	dw .Metal

	assert_table_length NUM_TYPES

.NullType:	   db "NULLTYPE@"
.Colorless:   db "COLORLESS@"
.Fighting: db "FIGHTING@"
.Fire:     db "FIRE@"
.Water:    db "WATER@"
.Grass:    db "GRASS@"
.Lightning: db "LIGHTNING@"
.Psychic:  db "PSYCHIC@"
.Dark:		db "DARK@"
.Metal:		db "METAL@"

