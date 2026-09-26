extends "res://ui/hud/panel.gd"

## The flat Nonogram's tray: a tile chip and a cross chip under the board.
## Whichever is armed is what a drag paints, and a drag that begins on your
## own paint rubs it out instead -- so there is no eraser chip here and no
## mode to get stuck in.
##
## Two chips rather than Binairo's three, and wide enough to carry a word:
## the island cycles a cell blank -> tile -> cross -> blank on repeated taps,
## which is three taps to correct a cross, and a hard board is 81 cells of
## which about 43 are tiles and 38 crosses. The tray is what makes that a
## screen you can play rather than one you grind.
##
## The tray only asks; the puzzle owns the brush (`brush`) and refresh()
## reads it back, so a board that drops the brush on a solve is shown here
## too. `symbol_tray.gd`'s sibling.
##
## Three boards wear it. It is built with a **chip set** -- what each chip
## paints, the word it carries, its node name and which glyph it draws --
## and there are three: MOSAIC, Nonogram's tile and cross, the default;
## QUEENS, Queens' bee and cross, which the registry asks for with
## `"tray": "queens"`; and PATCH, Mushroom Patch's mushroom and pebble, asked
## for with `"tray": "patch"`. One tray, three sets, no copy.
## Spec: docs/superpowers/specs/2026-09-18-nonogram-flat-design.md, section 6;
## docs/superpowers/specs/2026-09-19-queens-flat-design.md, section 6;
## docs/superpowers/specs/2026-09-20-mushroom-patch-flat-design.md, section 7.

## What the player chose: one of the set's values.
signal pick(v: int)

const NonogramState = preload("res://puzzles/nonogram_state.gd")
const QueensState = preload("res://puzzles/queens_state.gd")
const MushroomState = preload("res://puzzles/mushroom_state.gd")
const BeeFace = preload("res://ui/faces/bee_face.gd")
const MushroomFace = preload("res://ui/faces/mushroom_face.gd")
const Face = preload("res://ui/faces/face.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const CrossMark = preload("res://ui/faces/cross_mark.gd")

const CHIP := Vector2(300.0, 130.0)
const GAP := 40.0
const LIFT := 10.0
## The row's height: a chip, the room its lift needs above it, and the air the
## mock leaves under it. The host measures its bottom slot from this.
const HEIGHT := CHIP.y + LIFT + 10.0
## The Palette moment's numbers are the family's (Motion.CHIP_LIFT_TIME, the
## squash of a tenth); only the lift differs, because this chip is taller.
const SQUASH := 0.1
## The mock's own geometry inside a chip: the picture's centre and the size it
## is drawn at, and where the word begins.
const GLYPH := 84.0
const GLYPH_X := 72.0
const GLYPH_Y := 60.0
const LABEL_X := 128.0
const LABEL_Y := 62.0
## The cross chip's socket is drawn with the mock's own corner rather than the
## board's tenth of a cell: at 84 across, a tenth reads as a circle.
const SOCKET_RADIUS := 12.0

## The three sets. `glyphs` names what the chip's picture is: a laid tile, a
## pebble on its socket, Queens' X on its socket, the bee (a BeeFace seated on the chip, alive) or the
## mushroom (a MushroomFace, still).
const MOSAIC := {
	"values": [NonogramState.FILL, NonogramState.MARK],
	"labels": ["TRAY_TILE", "TRAY_CROSS"],
	"names": ["TileChip", "CrossChip"],
	"glyphs": ["tile", "pebble"],
}
const QUEENS := {
	"values": [QueensState.QUEEN, QueensState.CROSS],
	"labels": ["TRAY_QUEEN", "TRAY_CROSS"],
	"names": ["QueenChip", "CrossChip"],
	"glyphs": ["bee", "cross"],
}
const PATCH := {
	"values": [MushroomState.FOUND, MushroomState.CLEAR],
	"labels": ["TRAY_MUSHROOM", "TRAY_PEBBLE"],
	"names": ["MushroomChip", "PebbleChip"],
	"glyphs": ["mushroom", "pebble"],
}

var chips: Array[Button] = []
var _set: Dictionary = MOSAIC
var _armed := -1
var _lifts: Array = [null, null]

func _init(chip_set: Dictionary = MOSAIC) -> void:
	_set = chip_set
	enter_from = Vector2(0, 100)

func _make_inner() -> Container:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(GAP))
	row.custom_minimum_size.y = HEIGHT
	return row

func _build() -> void:
	for i in (_set.values as Array).size():
		# A plain Control holds each chip so the lift can move the chip
		# freely; a container would put it straight back.
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(CHIP.x, CHIP.y + LIFT)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inner.add_child(slot)
		var chip := Button.new()
		chip.name = str(_set.names[i])
		chip.focus_mode = Control.FOCUS_NONE
		chip.size = CHIP
		chip.position = Vector2(0.0, LIFT)
		chip.pivot_offset = CHIP * 0.5
		_style(chip, false)
		chip.pressed.connect(_on_pressed.bind(i))
		slot.add_child(chip)
		chips.append(chip)

		var glyph: Control
		if str(_set.glyphs[i]) == "bee":
			# The bee is a face of her own and draws herself; alive, so her
			# wings beat on the chip as they do on the court.
			glyph = BeeFace.new()
			glyph.set_idle(true)
		elif str(_set.glyphs[i]) == "mushroom":
			# The mushroom draws herself too, but the mock keeps her still: no
			# idle motion of her own means set_idle(true) here would only add
			# a blink neither the mock nor the tray's other chips carry.
			glyph = MushroomFace.new()
		else:
			glyph = Control.new()
			glyph.draw.connect(_draw_glyph.bind(glyph, i))
		glyph.name = "Glyph"
		glyph.size = Vector2.ONE * GLYPH
		glyph.position = Vector2(GLYPH_X, GLYPH_Y) - glyph.size * 0.5
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(glyph)

		var label := Label.new()
		label.name = "Label"
		label.theme_type_variation = "ChipLabel"
		label.text = str(_set.labels[i])
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = Vector2(LABEL_X, LABEL_Y - CHIP.y * 0.5)
		label.size = Vector2(CHIP.x - LABEL_X, CHIP.y)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(label)

## The chip's picture: a tile as the board lays it, or the socket a cross
## rules out with its pebble on it -- the same two drawings, so what the tray
## offers is literally what the finger leaves behind.
func _draw_glyph(glyph: Control, i: int) -> void:
	var b := Face.Builder.new()
	var centre := glyph.size * 0.5
	if str(_set.glyphs[i]) == "tile":
		Mosaic.tile(b, centre, GLYPH, Vector2.ONE, false, 0.0, 1.0)
	elif str(_set.glyphs[i]) == "cross":
		# Queens' X, on the socket, the mark the board leaves.
		b.fan(Face.Builder.round_rect(Vector2.ZERO, glyph.size, SOCKET_RADIUS),
			Pal.SOCKET_OUT)
		CrossMark.draw(b, centre, GLYPH, Vector2.ONE, 1.0)
	else:
		b.fan(Face.Builder.round_rect(Vector2.ZERO, glyph.size, SOCKET_RADIUS),
			Pal.SOCKET_OUT)
		Mosaic.pebble(b, centre, GLYPH, Vector2.ONE, 1.0)
	var mesh := b.mesh()
	if mesh != null:
		glyph.draw_mesh(mesh, null)
		# A canvas command holds the mesh by RID and not by reference; keeping
		# it on the node is what stops the renderer drawing a freed one.
		glyph.set_meta("mesh", mesh)

## Its look, resting or armed: cream lifted off the page, and when armed a
## sun border all round, exactly as Binairo's chips take it.
func _style(chip: Button, armed: bool) -> void:
	var fill: Color = Pal.SURFACE if armed else Pal.SURFACE_HI
	var sb := CozyTheme.chip(fill, 32, Pal.SUN, 5 if armed else 0)
	var pressed := CozyTheme.chip(fill, 32, Pal.SUN, 5 if armed else 0, true)
	for state in ["normal", "hover", "focus"]:
		chip.add_theme_stylebox_override(state, sb)
	chip.add_theme_stylebox_override("pressed", pressed)
	chip.add_theme_stylebox_override("disabled", sb)

func _on_pressed(i: int) -> void:
	Motion.squash(chips[i], SQUASH, Motion.CHIP_LIFT_TIME)
	pick.emit(int(_set.values[i]))

## Reads the puzzle's brush and shows it: the armed chip lifts with the back
## ease and takes its border, the other settles back.
func refresh(puzzle) -> void:
	var brush: int = puzzle.get("brush") if puzzle != null and puzzle.get("brush") != null else -1
	var armed := (_set.values as Array).find(brush)
	var done: bool = puzzle != null and puzzle.is_done()
	for chip in chips:
		chip.disabled = done
	if armed == _armed:
		return
	_armed = armed
	for i in chips.size():
		var chip := chips[i]
		var up := i == armed
		_style(chip, up)
		Motion.stop(_lifts[i])
		_lifts[i] = Motion.slide(chip, "position:y", chip.position.y, 0.0 if up else LIFT, Motion.CHIP_LIFT_TIME)
