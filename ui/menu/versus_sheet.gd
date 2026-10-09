extends "res://ui/menu/difficulty_sheet.gd"

## Asks who to play before a Versus card opens (2026-10-09, the user: "match
## the daily games cards, where the difficulty (+ online) shows as the same
## sheet after clicking on the game"): the difficulty sheet's own rows, the
## computer's three levels and then the other player -- online, or across the
## same phone for a game with no game online (VersusTab.levels_of). The
## fourth is the night row. Each row's line is the record at that level, the
## one the card used to carry; the other player's row says what it is until
## there is a record to show.

## A row was picked: `game` at `level` (a Record level).
signal picked(game: String, level: int)

const VersusTab = preload("res://ui/menu/versus_tab.gd")
const Record = preload("res://versus/versus_record.gd")

func ask_game(game: String) -> void:
	_title.text = String(VersusTab.NAMES.get(game, ""))
	_blurb.text = "VS_PICK"
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var levels := VersusTab.levels_of(game)
	for i in levels.size():
		var level := int(levels[i][1])
		_list.add_child(_row({"name": String(levels[i][0]), "line": _line(game, level)}, clampi(i, 0, 3), false,
			func() -> void: close_then(picked.emit.bind(game, level))))
	open()

## Two on one phone are both the player and keep no record; a game online
## has one once a game has been played.
func _line(game: String, level: int) -> String:
	if level == Record.LOCAL:
		return "VS_TWO_LINE"
	if level == Record.ONLINE:
		var rec := Record.get_record(game, level)
		if rec.x + rec.y + Record.get_draws(game, level) == 0:
			return "VS_ONLINE_LINE"
	return Record.record_line(game, level)
