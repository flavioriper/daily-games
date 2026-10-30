extends "res://versus/versus_options.gd"

## Checkers' options, one sheet, chess's: the clock, your colour, the piece
## set and the aids. What a game was started with stands until the next one,
## except the set and the aids, which change at once.

const GAME := "checkers"
## The time controls: seconds each and seconds added a move, 0 for no clock.
const CONTROLS := [[0, 0], [180, 2], [300, 0], [600, 0]]
const CONTROL_KEYS := ["CHS_CLOCK_OFF", "3 + 2", "5 + 0", "10 + 0"]
const COLOUR_KEYS := ["CHS_COLOUR_SWAP", "CHS_COLOUR_WHITE", "CHS_COLOUR_BLACK"]
const SKINS := ["classic", "garden"]
const SKIN_KEYS := ["CHS_SET_CLASSIC", "CHS_SET_GARDEN"]
const SWITCHES := [["grades", "CHS_OPT_GRADES", "CHS_OPT_GRADES_SUB"],
	["traps", "CKR_OPT_TRAPS", "CKR_OPT_TRAPS_SUB"],
	["threats", "CHS_OPT_THREATS", "CHS_OPT_THREATS_SUB"]]

static func control() -> int:
	return clampi(int(Record.option(GAME, "clock", 0)), 0, CONTROLS.size() - 1)

static func colour() -> int:
	return clampi(int(Record.option(GAME, "colour", 0)), 0, 2)

static func on(key: String) -> bool:
	return bool(Record.option(GAME, key, true))

func _game() -> String:
	return GAME

func _build_sheet(col: VBoxContainer) -> void:
	_title_row(col, "CHS_OPTIONS", "gear")
	_chips(col, "CHS_OPT_CLOCK", CONTROL_KEYS, control(), func(i: int) -> void:
		Record.set_option(GAME, "clock", i))
	_chips(col, "CHS_OPT_COLOUR", COLOUR_KEYS, colour(), func(i: int) -> void:
		Record.set_option(GAME, "colour", i))
	_chips(col, "CHS_OPT_SET", SKIN_KEYS, maxi(SKINS.find(Record.skin(GAME)), 0), func(i: int) -> void:
		Record.set_skin(GAME, SKINS[i]))
	for row: Array in SWITCHES:
		_switch(col, row[0], row[1], row[2])
	var done := _wide_primary("check", "CHS_OPT_DONE")
	done.pressed.connect(close)
	col.add_child(done)
