extends "res://ui/hud/panel.gd"

## Sudoku's tray: one row of ten chips under the board -- 1 to 9 and the
## pencil. A chip is a **direct action, not a brush**, the way Code Break's
## friend chips and Hidden Word's keys are: tap 5 and a 5 goes into the
## selected cell, and nothing stays armed. The pencil is the one exception,
## because it IS a mode, and the only one on the screen, so it is drawn lit
## while it is on.
##
## **A chip is (1000 - 9*GAP)/10 = 91 wide** with GAP 10, and ten chips with
## nine gaps close on the 1000 column exactly. That is not a new number: it
## is ui/flat/key_board.gd's KEY width, so a thumb here has the room it
## already has on a shipped screen.
##
## **There is no eraser chip.** Tapping the digit a cell already holds takes
## it out again, which is one tap rather than two -- Nonogram's rule, no
## eraser and no mode to get stuck in -- and it is what buys the row back for
## the pencil, which a 9x9 at 30 givens genuinely needs.
##
## A digit already placed nine times goes pale and stops answering: the pad
## is the only place on the screen that can say there are no more of these.
##
## Every chip stands in its own slot, a plain Control the Button sits inside,
## and the slot is the HBoxContainer's child rather than the Button itself --
## the row would otherwise put a pressed chip's scale fight back on the next
## sort, the lesson Balance's weight cards paid for on 2026-09-18. The row
## itself lays the ten slots out (`ui/flat/tile_tray.gd`'s own idiom), so
## nothing here computes a slot's x position by hand.
##
## The tray only asks; the board owns both the digits and the pencil, and
## refresh() reads them back.
## Spec: docs/superpowers/specs/2026-09-20-sudoku-flat-design.md, section 6.

## A chip was tapped: 0..8 for digits 1..9, PENCIL for the pencil.
signal pick(i: int)

const Icons = preload("res://ui/icons.gd")

const CHIP := Vector2(91.0, 130.0)
const GAP := 10.0
const LIFT := 10.0
## The row's height: a chip, the room its press needs above it, and the air
## the mock leaves under it. The host measures its bottom slot from this.
const HEIGHT := CHIP.y + LIFT + 30.0
const PENCIL := 9
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
var _pencil_on := false

func _init() -> void:
	enter_from = Vector2(0, 100)

func _make_inner() -> Container:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(GAP))
	row.custom_minimum_size.y = HEIGHT
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row

func _build() -> void:
	for k in COUNT:
		# A plain Control holds each chip so the press can move the chip
		# freely; the row's HBoxContainer would otherwise put it straight
		# back on the next sort.
		var slot := Control.new()
		slot.name = "Slot%d" % k
		slot.custom_minimum_size = Vector2(CHIP.x, CHIP.y + LIFT)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inner.add_child(slot)
		var b := Button.new()
		b.name = "Digit%d" % k if k < PENCIL else "PencilChip"
		b.size = CHIP
		b.position = Vector2(0.0, LIFT)
		b.pivot_offset = CHIP * 0.5
		b.focus_mode = Control.FOCUS_NONE
		b.text = str(k + 1) if k < PENCIL else ""
		b.add_theme_font_override("font", CozyTheme.display(600))
		b.add_theme_font_size_override("font_size", FONT_SIZE)
		b.pressed.connect(_on_chip.bind(k))
		slot.add_child(b)
		_chips.append(b)
		if k == PENCIL:
			b.draw.connect(_draw_pencil.bind(b))
	_paint()

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

func _draw_pencil(on: Button) -> void:
	var ink: Color = Pal.PAPER if _pencil_on else Pal.TEXT
	Icons.paint(on, "pencil", Rect2(on.size * 0.5 - Vector2(33, 33), Vector2(66, 66)), ink)

## Read the digits and the pencil back off the board. Called by the host on
## every move and every focus change.
func refresh(puzzle) -> void:
	if puzzle == null:
		return
	_pencil_on = puzzle.pencil_on() if puzzle.has_method("pencil_on") else false
	for k in PENCIL:
		var left: int = puzzle.remaining(k + 1) if puzzle.has_method("remaining") else 9
		var spent := left <= 0
		_chips[k].disabled = spent
		_chips[k].modulate.a = SPENT_ALPHA if spent else 1.0
	_chips[PENCIL].queue_redraw()
	_paint()

func _paint() -> void:
	for k in COUNT:
		var lit := k == PENCIL and _pencil_on
		var face: Color = Pal.SUN if lit else Pal.SURFACE
		var ink: Color = Pal.SURFACE if lit else Pal.TEXT
		var edge: Color = face.darkened(EDGE_DARKEN)
		_chips[k].add_theme_stylebox_override("normal", CozyTheme.card(face, RADIUS, edge, BORDER_W, 0))
		_chips[k].add_theme_stylebox_override("hover", CozyTheme.card(face, RADIUS, edge, BORDER_W, 0))
		_chips[k].add_theme_stylebox_override("pressed", CozyTheme.card(face.darkened(PRESS_DARKEN), RADIUS, edge, BORDER_W, 0))
		_chips[k].add_theme_stylebox_override("disabled", CozyTheme.card(face, RADIUS, edge, BORDER_W, 0))
		_chips[k].add_theme_color_override("font_color", ink)
		_chips[k].add_theme_color_override("font_disabled_color", ink)
