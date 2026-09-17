extends "res://core/turn_base.gd"

## The phase 0 stub. The day publishes a number from 0 to 100; a row of pegs
## is the dial, dragged along to set a guess, and the reveal raises the true
## answer's peg beside it. Deleted when How Big? lands in phase 1 -- it exists
## to prove publish, read, play, grade, submit, roll up and re-read.

const Models = preload("res://core/models.gd")
const Scenery = preload("res://world/scenery.gd")
const Toon = preload("res://core/toon.gd")
const Pal = preload("res://core/palette.gd")
const DailySeed = preload("res://core/daily.gd")

## The dial is ten pegs wide; a guess of 100 fills all ten.
const PEGS := 10
const RAISE := 0.45

var value: int = 50
## Whether the player has set the dial at all. The starting 50 is the turn's
## default, not an answer.
var _touched := false
var _pegs: Array[Node3D] = []
var _answer_peg: Node3D

func turn_id() -> String: return "guess_number"
func title() -> String: return tr("GUESS_TITLE")
func motto() -> String: return tr("GUESS_MOTTO")
func footer() -> String: return tr("GUESS_FOOTER")
func prompt_text() -> String: return tr("GUESS_PROMPT")

func board_size() -> Vector2i: return Vector2i(PEGS, 1)
func board_height() -> float: return 1.0
func plane_height() -> float: return 0.0
func board_margin() -> float: return 0.5

## Lock stays dark until the dial has been touched once. The stub proves the
## affordance the base class promises (spec 2.3) rather than asserting it: a
## turn nobody has answered yet is not a turn that can be committed.
func has_input() -> bool: return _touched
func guess() -> Variant: return value

## Puts a restored day's guess back on the dial, so a reopened card shows
## what was actually locked in rather than the fresh-turn default.
func apply_guess(the_guess) -> void:
	value = clampi(int(the_guess), 0, 100)
	_touched = true
	_paint()

## The published answer, or the same number derived from the day when the
## phone has never reached the network. Both sides use the same hash.
func _answer() -> int:
	if content.has("answer"):
		return clampi(int(content.answer), 0, 100)
	return DailySeed.fnv1a("guess_number|%d" % DailySeed.date_key()) % 101

func build_turn(_content: Dictionary) -> void:
	for i in PEGS:
		var pivot := Scenery.prop("peg", _at(i), 0.0, Vector3.ONE)
		board.add_child(pivot)
		_pegs.append(pivot.get_child(0))
	_paint()

static func _at(i: int) -> Vector3:
	return Vector3(i - (PEGS - 1) * 0.5, 0.0, 0.0)

## A drag anywhere along the row sets the guess from its x.
func on_board_press(hit: Vector3) -> void:
	_set_from(hit)

func on_board_drag(hit: Vector3) -> void:
	_set_from(hit)

func _set_from(hit: Vector3) -> void:
	var t := (hit.x + (PEGS - 1) * 0.5) / float(PEGS - 1)
	var next := clampi(int(round(t * 100.0)), 0, 100)
	# The first touch counts even when it lands on the value already shown:
	# it is what lights Lock, so it has to reach the host.
	var first := not _touched
	_touched = true
	if next == value and not first:
		return
	value = next
	_paint()
	input_changed.emit()

## Pegs up to the guess stand raised and warm; the rest sit flat and pale.
## The peg model's tintable layer is "Shell" (see puzzles/codebreak3d.gd),
## not "Peg"; Pal.PEGS is the palette the peg was modelled against.
func _paint() -> void:
	var lit := int(round(value / 100.0 * PEGS))
	for i in _pegs.size():
		var on := i < lit
		_pegs[i].position.y = RAISE if on else 0.0
		Models.tint_named(_pegs[i], "Shell", Pal.PEGS[3] if on else Pal.PLOT_SOIL)

## The answer stands up as an eleventh peg, taller and in its own colour.
## Nothing here animates, so `animate` has nothing to skip; a turn whose
## reveal moves has to honour it (see TurnBase.reveal).
func reveal(_animate := true) -> void:
	var a := _answer()
	var x := (a / 100.0) * (PEGS - 1) - (PEGS - 1) * 0.5
	var pivot := Scenery.prop("peg", Vector3(x, 0.0, -1.2), 0.0, Vector3.ONE * 1.3)
	board.add_child(pivot)
	_answer_peg = pivot.get_child(0)
	Models.tint_named(_answer_peg, "Shell", Pal.PEGS[0])

## 100 when exact, falling a point per unit away.
func grade(_answer_in) -> int:
	return clampi(100 - absi(value - _answer()), 0, 100)

func share_text() -> String:
	return "Guess %d — I said %d, it was %d" % [DailySeed.date_key(), value, _answer()]

func share_glyphs() -> String:
	var lit := int(round(grade(null) / 100.0 * PEGS))
	var out := ""
	for i in PEGS:
		out += "🟩" if i < lit else "⬜"
	return out
