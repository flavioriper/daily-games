extends Control

## The win screen's top: the sun and the moon at illustration size, both
## beaming, the moon in front and a little lower, leaves at the sides, three
## stars, then "Well done!" and "Perfect balance!". Laid out in the column's
## space (1000 wide, 640 tall) under the host's top margin, at the spec's
## positions. It slides down into the space the top bar and day card leave.
##
## A board whose answer is itself a row of characters replaces that pair
## with its own cast (`set_cast`), laid across the same space at the board's
## own pitch: Code Break's answer is four friends, so showing them is both
## the celebration and the answer.
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, section 8
## (as amended), and
## docs/superpowers/specs/2026-09-18-codebreak-flat-design.md, section 6.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Icons = preload("res://ui/icons.gd")
const Face = preload("res://ui/faces/face.gd")
const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")

const HEIGHT := 640.0
## Centres in the column's space (the spec's x less the 40 margin, y less
## the 40 top margin).
const SUN_AT := Vector2(430.0, 230.0)
const SUN_SIZE := 130.0 * 2.0 * 1.55
const MOON_AT := Vector2(570.0, 290.0)
const MOON_SIZE := 105.0 * 2.0
const LEAF_L := Vector2(210.0, 260.0)
const LEAF_R := Vector2(790.0, 260.0)
const LEAF := 110.0
const STARS := [[360.0, 100.0, 22.0], [690.0, 100.0, 16.0], [760.0, 200.0, 26.0]]
## A cast fills the middle of the art where the pair left room, so the
## leaves go out to the edges and the stars up out of its way.
const CAST_LEAF_L := Vector2(66.0, 390.0)
const CAST_LEAF_R := Vector2(934.0, 390.0)
const CAST_LEAF := 116.0
const CAST_STARS := [[190.0, 110.0, 22.0], [812.0, 128.0, 16.0], [906.0, 236.0, 26.0]]
## A cast laid across the art: its centre line, and the pitch the board's
## own seats use (150 wide, 40 apart). A cast wider than CAST_SPAN is closed
## up and its faces shrink with the pitch, the mock's own rule, because past
## four the row otherwise runs out into the leaves at the edges of the art:
## Code Break's four fit at the full pitch, Balance's five do not.
const CAST_SPAN := 800.0
const CAST_SEAT_SHARE := 0.85
## A cast that carries labels puts each one this far under its face's lower
## edge, so the gap does not change with the seat.
const CAST_LABEL_GAP := 24.0
const CAST_LABEL_H := 60.0
const CAST_LABEL_SIZE := 46
const CAST_Y := 290.0
const CAST := 150.0
const CAST_GAP := 40.0
const TITLE_Y := 508.0
const SUB_Y := 582.0
const SLIDE := 0.4
const FADE := 0.2

var sun: Control
var moon: Control
var _cast: Array[Control] = []
var _cast_labels: Array[Label] = []
## Set when the cast had to be closed up to fit: the row then reaches the
## right of the art, and the decoration there steps aside (see _draw_art).
var _cast_wide := false
var _art: Control
var _title: Label
var _sub: Label
var _spin: Tween
var _rock: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = HEIGHT
	_art = Control.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_art.bind(_art))
	add_child(_art)
	sun = SunFace.new()
	sun.size = Vector2(SUN_SIZE, SUN_SIZE)
	sun.position = SUN_AT - sun.size * 0.5
	sun.expression = Face.Expr.JOY
	add_child(sun)
	moon = MoonFace.new()
	moon.size = Vector2(MOON_SIZE, MOON_SIZE)
	moon.position = MOON_AT - moon.size * 0.5
	moon.expression = Face.Expr.JOY
	moon.rocks = true
	add_child(moon)
	_title = Label.new()
	_title.theme_type_variation = "WellDone"
	_title.text = "WIN_WELL_DONE"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = TITLE_Y - 60.0
	_title.offset_bottom = TITLE_Y + 60.0
	add_child(_title)
	_sub = Label.new()
	_sub.theme_type_variation = "CardBodyDim"
	_sub.add_theme_font_size_override("font_size", 34)
	_sub.text = "WIN_PERFECT"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_sub.offset_top = SUB_Y - 24.0
	_sub.offset_bottom = SUB_Y + 24.0
	add_child(_sub)
	resized.connect(_fit_cast)
	visible = false

## Two leaves turned outward and three four-point stars in sun, placed
## clear of whatever the middle of the art holds.
func _draw_art(ci: Control) -> void:
	var row := not _cast.is_empty()
	var leaf: float = CAST_LEAF if row else LEAF
	ci.draw_set_transform(CAST_LEAF_L if row else LEAF_L, -0.9, Vector2.ONE)
	Icons.paint(ci, "leaf", Rect2(Vector2(-leaf * 0.5, -leaf * 0.5), Vector2(leaf, leaf)), Pal.LEAF)
	# The right leaf stands at x 934 and the outermost star at 906, which is
	# inside a cast that had to be closed up to fit -- Balance's five fruit
	# reach 888 with their weights written under them. The answer is the
	# point of this screen, so the decoration on that side steps aside rather
	# than being drawn through. Four or fewer faces leave the art untouched.
	if not _cast_wide:
		ci.draw_set_transform(CAST_LEAF_R if row else LEAF_R, -2.2, Vector2.ONE)
		Icons.paint(ci, "leaf", Rect2(Vector2(-leaf * 0.5, -leaf * 0.5), Vector2(leaf, leaf)), Pal.LEAF)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var stars: Array = CAST_STARS if row else STARS
	if _cast_wide:
		stars = stars.slice(0, stars.size() - 1)
	for s in stars:
		var pts := PackedVector2Array()
		for i in 8:
			var a := i * PI / 4.0
			var r: float = s[2] if i % 2 == 0 else s[2] * 0.38
			pts.append(Vector2(s[0], s[1]) + Vector2(cos(a), sin(a)) * r)
		ci.draw_colored_polygon(pts, Pal.SUN)
		ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Pal.SUN, 1.5, true)

## Puts `faces` across the art in place of the sun and the moon, centred on
## the panel at the board's own pitch, and re-words the line under
## "Well done!". The faces come in ready-made from the board, which is the
## only thing that knows what the answer was.
## `labels`, when given, is one line under each face: Balance's answer is a
## weight per kind, so the cast is the fruit and the label is what each one
## turned out to weigh. Code Break passes none -- its cast is the whole
## answer on its own.
func set_cast(faces: Array, subtitle: String, labels: Array = []) -> void:
	for face in _cast:
		face.queue_free()
	for label in _cast_labels:
		label.queue_free()
	_cast = []
	_cast_labels = []
	sun.visible = false
	moon.visible = false
	for face in faces:
		face.expression = Face.Expr.JOY
		add_child(face)
		_cast.append(face)
	for i in labels.size():
		var label := Label.new()
		label.theme_type_variation = "WeightNumeral"
		label.add_theme_font_size_override("font_size", CAST_LABEL_SIZE)
		label.text = String(labels[i])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_cast_labels.append(label)
	_fit_cast()
	# After _fit_cast, which is what decides whether the row is wide.
	_art.queue_redraw()
	_sub.text = subtitle

## The cast across the middle of the art, centred on the panel, each label
## squarely under its own face.
func _fit_cast() -> void:
	var n := _cast.size()
	if n == 0:
		return
	var pitch: float = CAST + CAST_GAP
	var seat: float = CAST
	_cast_wide = pitch * float(n) > CAST_SPAN
	if _cast_wide:
		pitch = CAST_SPAN / float(n)
		seat = minf(CAST, pitch * CAST_SEAT_SHARE)
	for i in n:
		var centre := Vector2(size.x * 0.5 + (i - (n - 1) * 0.5) * pitch, CAST_Y)
		var face: Control = _cast[i]
		face.size = Vector2(seat, seat)
		face.pivot_offset = face.size * 0.5
		face.position = centre - face.size * 0.5
		if i < _cast_labels.size():
			var label: Label = _cast_labels[i]
			label.size = Vector2(pitch, CAST_LABEL_H)
			label.position = centre + Vector2(-pitch * 0.5, seat * 0.5 + CAST_LABEL_GAP)

## Slides in from 200 above while fading up, after `delay`. Every face starts
## its idle life (the sun turns its rays, the moon rocks).
func enter(delay := 0.0) -> void:
	visible = true
	Motion.slide(self, "position:y", position.y - 200.0, position.y, SLIDE, delay)
	Motion.appear(self, 0.0, 1.0, FADE, delay)
	if _cast.is_empty():
		sun.set_idle(true)
		moon.set_idle(true)
	for face in _cast:
		face.set_idle(true)
