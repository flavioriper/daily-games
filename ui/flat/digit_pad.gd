extends "res://ui/hud/panel.gd"

## Sudoku's tray: two rows of chips under the board -- the digits and the
## remove chip (a cross), which empties the selected cell. It took the
## pencil's seat on 2026-09-23 at the user's request. Every chip is a
## **direct action, not a brush**, the way Code Break's friend chips and
## Hidden Word's keys are: tap 5 and a 5 goes into the selected cell, and
## nothing stays armed.
##
## **Two rows, not one** (2026-09-23, at the user's request, after the
## reference mini sudoku's pad). Hard's nine digits and the cross stand five
## and five -- 1 to 5 over 6 to 9 and the cross. The mini's six stand three
## and three with the cross a tall chip at the end of both rows. **The pad
## fills whatever width the column gives it**: the chips are sized off the
## inner's own width on every resize, never off a fixed 1000, because a
## wider screen widens the column and a fixed pad stopped short of it.
## The board says how many digits it has (`digit_count()`), and the pad lays
## itself out again on refresh whenever that changes, because the tray is
## built before the board and outlives a change of band.
##
## Tapping the digit a cell already holds still takes it out again, as it
## did before the cross existed; the cross is the door a player looks for.
##
## A digit already placed as many times as the grid is wide goes pale and stops answering: the pad
## is the only place on the screen that can say there are no more of these.
##
## Every chip stands in its own slot, a plain Control the Button sits inside,
## so a pressed chip's squash never fights a container's sort -- the lesson
## Balance's weight cards paid for on 2026-09-18. The inner is a bare
## Container, which never sorts, and `_lay` places the slots itself: a chip
## that spans both rows is not something a Box or a Grid can hold.
##
## The tray only asks; the board owns the digits and refresh() reads the
## counts back.
## Spec: docs/superpowers/specs/2026-09-20-sudoku-flat-design.md, section 6.

## A chip was tapped: 0..8 for digits 1..9, REMOVE for the cross.
signal pick(i: int)

const Icons = preload("res://ui/icons.gd")

## The narrowest the pad asks for; it fills whatever it is given.
const MIN_WIDTH := 600.0
const CHIP_H := 88.0
const GAP := 10.0
const LIFT := 10.0
## The pad's height: two rows of chips and the gap between them, the room a
## press needs above, and the air the mock leaves under. The host measures
## its bottom slot from this.
const HEIGHT := CHIP_H * 2.0 + GAP + LIFT + 20.0
const REMOVE := 9
const COUNT := 10
const RADIUS := 20
const FONT_SIZE := 56
## The family's own pair, the same two ui/menu/puzzle_card_2d.gd's chips wear.
const EDGE_DARKEN := 0.28
const PRESS_DARKEN := 0.12
const BORDER_W := 7
## How far a spent chip fades. Not hidden: a gap in the row would move every
## chip after it, and a row that moves under a thumb is worse than a pale one.
const SPENT_ALPHA := 0.35
## The tap's own squash, tile_tray.gd's SQUASH beside its own CHIP_LIFT_TIME:
## the family's press for a chip that fires on `pressed` rather than being
## held, so nothing here reads Motion.press, which is the held-down recipe
## key_board.gd uses instead.
const SQUASH := 0.1

var _chips: Array[Button] = []
var _press: Dictionary = {}   # Button -> Tween
## How many digit chips are laid out; 0 until the first _lay.
var _digits := 0
var _slots: Array[Control] = []

func _init() -> void:
	enter_from = Vector2(0, 100)

func _make_inner() -> Container:
	var box := Container.new()
	box.custom_minimum_size = Vector2(MIN_WIDTH, HEIGHT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.resized.connect(func() -> void: _lay(_digits, true))
	return box

func _build() -> void:
	for k in COUNT:
		# A plain Control holds each chip so the press can move the chip
		# freely; the row's HBoxContainer would otherwise put it straight
		# back on the next sort.
		var slot := Control.new()
		slot.name = "Slot%d" % k
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inner.add_child(slot)
		_slots.append(slot)
		var b := Button.new()
		b.name = "Digit%d" % k if k < REMOVE else "RemoveChip"
		b.focus_mode = Control.FOCUS_NONE
		b.text = str(k + 1) if k < REMOVE else ""
		b.add_theme_font_override("font", CozyTheme.display(600))
		b.add_theme_font_size_override("font_size", FONT_SIZE)
		b.pressed.connect(_on_chip.bind(k))
		slot.add_child(b)
		_chips.append(b)
		if k == REMOVE:
			b.draw.connect(_draw_remove.bind(b))
	_lay(9)
	_paint()

## Place the chips for `n` digits: nine as five over four-and-the-cross,
## six as three over three with the cross standing the height of both rows
## at the end. Digits past `n` are hidden.
func _lay(n: int, force := false) -> void:
	# The inner's first resize comes before _build has made any chips.
	if _slots.is_empty():
		return
	if n == _digits and not force:
		return
	_digits = n
	var cols := 5 if n > 6 else 4
	var per_row := 5 if n > 6 else 3
	var w := (maxf(_inner.size.x, MIN_WIDTH) - GAP * (cols - 1)) / cols
	for k in COUNT:
		var col := 0
		var row := 0
		var tall := false
		if k == REMOVE:
			if n > 6:
				col = n - per_row
				row = 1
			else:
				col = per_row
				tall = true
		elif k < n:
			col = k % per_row
			row = k / per_row
		_slots[k].visible = k == REMOVE or k < n
		var chip := Vector2(w, CHIP_H * 2.0 + GAP if tall else CHIP_H)
		_slots[k].position = Vector2(col * (w + GAP), row * (CHIP_H + GAP))
		_slots[k].size = Vector2(chip.x, chip.y + LIFT)
		var b := _chips[k]
		b.size = chip
		b.position = Vector2(0.0, LIFT)
		b.pivot_offset = chip * 0.5
		b.queue_redraw()

func _on_chip(k: int) -> void:
	_bump(_chips[k])
	pick.emit(k)

## The tap's beat: a squash on the chip itself, the same recipe and the same
## pair of numbers (SQUASH, tile_tray.gd's own Motion.CHIP_LIFT_TIME) every
## direct-action chip in the family already wears for a tap. Motion.press is
## the held-down recipe key_board.gd's chips use instead (button_down to
## button_up); a chip here fires once, from `pressed`, so it takes the other
## one.
func _bump(b: Button) -> void:
	Motion.stop(_press.get(b))
	_press[b] = Motion.squash(b, SQUASH, Motion.CHIP_LIFT_TIME)

func _draw_remove(on: Button) -> void:
	Icons.paint(on, "cross", Rect2(on.size * 0.5 - Vector2(32, 32), Vector2(64, 64)), Pal.TEXT)

## Read the digit counts back off the board. Called by the host on
## every move and every focus change.
func refresh(puzzle) -> void:
	if puzzle == null:
		return
	_lay(puzzle.digit_count() if puzzle.has_method("digit_count") else 9)
	for k in _digits:
		var left: int = puzzle.remaining(k + 1) if puzzle.has_method("remaining") else 9
		var spent := left <= 0
		_chips[k].disabled = spent
		_chips[k].modulate.a = SPENT_ALPHA if spent else 1.0

func _paint() -> void:
	for k in COUNT:
		var face: Color = Pal.SURFACE
		var ink: Color = Pal.TEXT
		var edge: Color = face.darkened(EDGE_DARKEN)
		_chips[k].add_theme_stylebox_override("normal", CozyTheme.card(face, RADIUS, edge, BORDER_W, 0))
		_chips[k].add_theme_stylebox_override("hover", CozyTheme.card(face, RADIUS, edge, BORDER_W, 0))
		_chips[k].add_theme_stylebox_override("pressed", CozyTheme.card(face.darkened(PRESS_DARKEN), RADIUS, edge, BORDER_W, 0))
		_chips[k].add_theme_stylebox_override("disabled", CozyTheme.card(face, RADIUS, edge, BORDER_W, 0))
		_chips[k].add_theme_color_override("font_color", ink)
		_chips[k].add_theme_color_override("font_disabled_color", ink)
