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
const Face = preload("res://ui/faces/face.gd")
const KeyBoard = preload("res://ui/flat/key_board.gd")

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
## The chips' paint (the board checkup, 2026-10-02), Hidden Word's keyboard
## pattern: a Button with its own StyleBoxFlat and digit cost two draw calls,
## 20 of Sudoku's 104 at rest. The Buttons still take the taps and carry the
## squash, but draw nothing; `_paint`, over them, draws every chip's face (and
## the cross) as one mesh and every digit after it, read off each Button's
## transform. A look (size, pressed, spent, the cross) is made once as a flat
## triangle list and copied natively under the chip's transform; the mesh is
## made again only on a frame where some chip moved, was pressed or spent.
var _paint: Control
var _flats: Dictionary = {}   # look key -> [verts, cols]
var _faces: ArrayMesh
var _sig := PackedFloat32Array()
var _font: Font

func _init() -> void:
	enter_from = Vector2(0, 100)

func _make_inner() -> Container:
	var box := Container.new()
	box.custom_minimum_size = Vector2(MIN_WIDTH, HEIGHT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.resized.connect(func() -> void: _lay(_digits, true))
	return box

func _build() -> void:
	_font = CozyTheme.display(600)
	_paint = Control.new()
	_paint.name = "Paint"
	_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paint.draw.connect(_draw_chips)
	add_child(_paint)
	# The paper every Button wore, on the paint instead, so the chips keep
	# their grain.
	_paint.material = CozyTheme.paper()
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
		b.pressed.connect(_on_chip.bind(k))
		slot.add_child(b)
		# Dropped after add_child, which is when CozyTheme.dress() puts the
		# shared paper wash on; the paint draws the chip instead.
		b.material = null
		KeyBoard._blank(b)
		_chips.append(b)
	_lay(9)

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

func _process(_delta: float) -> void:
	if _paint == null or not is_visible_in_tree():
		return
	# Every chip's place, scale, press and spend, in the paint's space; a
	# frame that matches the last one draws the mesh it already has.
	var inv := _paint.get_global_transform().affine_inverse()
	var sig := PackedFloat32Array()
	sig.resize(_chips.size() * 8)
	var k := 0
	for chip in _chips:
		var xf := inv * chip.get_global_transform()
		sig[k] = xf.x.x
		sig[k + 1] = xf.x.y
		sig[k + 2] = xf.y.x
		sig[k + 3] = xf.y.y
		sig[k + 4] = xf.origin.x
		sig[k + 5] = xf.origin.y
		sig[k + 6] = (1.0 if KeyBoard._held(chip) else 0.0) + (2.0 if chip.is_visible_in_tree() else 0.0)
		sig[k + 7] = chip.modulate.a
		k += 8
	if sig == _sig:
		return
	_sig = sig
	_faces = null
	_paint.queue_redraw()

## Every chip's face and the cross as one mesh, then every digit: two draw
## calls.
func _draw_chips() -> void:
	if _chips.is_empty():
		return
	var inv := _paint.get_global_transform().affine_inverse()
	if _faces == null:
		var b := Face.FlatBuilder.new()
		for k in _chips.size():
			var chip := _chips[k]
			if not chip.is_visible_in_tree():
				continue
			var f := _flat_for(chip, k == REMOVE)
			b.verts.append_array((inv * chip.get_global_transform()) * (f[0] as PackedVector2Array))
			b.cols.append_array(f[1])
		_faces = b.mesh() if not b.verts.is_empty() else null
	if _faces != null:
		_paint.draw_mesh(_faces, null)
	var asc := _font.get_ascent(FONT_SIZE)
	for k in mini(_digits, REMOVE):
		var chip := _chips[k]
		if not chip.is_visible_in_tree():
			continue
		var text := str(k + 1)
		var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var at := Vector2((chip.size.x - ts.x) * 0.5, (chip.size.y - ts.y) * 0.5 + asc)
		_paint.draw_set_transform_matrix(inv * chip.get_global_transform())
		_paint.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE,
			Color(Pal.TEXT, chip.modulate.a))
	_paint.draw_set_transform_matrix(Transform2D.IDENTITY)

## A chip's face as a flat triangle list about its own top-left corner, made
## once per size, press, spend and glyph: CozyTheme.soft_button's look in
## SURFACE (the soft shadow, the two-pixel border, the face; key_board.gd's
## triangles), the cross stroked on the remove chip as Icons' "cross" is.
func _flat_for(chip: Button, cross: bool) -> Array:
	var held := KeyBoard._held(chip)
	var a := chip.modulate.a
	var key := "%d|%d|%s|%.2f|%s" % [int(chip.size.x), int(chip.size.y), held, a, cross]
	var f: Array = _flats.get(key, [])
	if not f.is_empty():
		return f
	var fill: Color = Pal.SURFACE
	var b := Face.Builder.new()
	var sz := chip.size
	var tint := fill.darkened(0.55).lerp(Color(0.35, 0.23, 0.12), 0.5)
	KeyBoard._shadow(b, Vector2(0.0, 1.0 if held else 4.0), sz, RADIUS, 3.0 if held else 10.0,
		Color(tint, (0.10 if held else 0.2) * a))
	b.fan(KeyBoard._rounded(Vector2.ZERO, sz, RADIUS), Color(fill.darkened(0.16), a))
	b.fan(KeyBoard._rounded(Vector2(2.0, 2.0), sz - Vector2(4.0, 4.0), RADIUS - 2.0),
		Color(fill.darkened(0.07) if held else fill, a))
	if cross:
		var lo := sz * 0.5 - Vector2(32.0, 32.0)
		# A hair under Icons' width: the stroke's feather adds to it.
		var w := Icons.STROKE * 64.0 - 1.5
		for line in Icons.shape("cross").lines:
			b.stroke(Transform2D(0.0, Vector2(64.0, 64.0), 0.0, lo) * (line as PackedVector2Array), w, Pal.TEXT)
	f = Face.FlatBuilder.flat_of(b)
	_flats[key] = f
	return f

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
