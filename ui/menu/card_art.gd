extends Control

## One puzzle card's picture on the first screen: the same characters the
## board itself plays with (ui/faces/), seated in a 320 by 118 box and
## scaled to whatever the card gives them.
##
## It is never an image and never a render of a model. Thirteen of the
## seventeen are made almost entirely of the flat boards' own cast --
## It is never an image and never a render of a model. Twelve of the
## eighteen are made almost entirely of the flat boards' own cast --
## Binairo's sun and moon, Code Break's friends, Balance's fruit, Untangle's
## lanterns, Shikaku's markers, Tents' tent and conifers, Light Up's lamp,
## One Line's snail, Queens' bee, Mushroom Patch's mushrooms, Fairy Lights'
## two lit papers (Untangle's lantern again, which is what that board plays
## with too), and the shared sprout that stands in for Hidden Word's and
## Word Trail's -- so a card and its board are visibly the same drawing.
## Only the furniture under them (a tray, a beam, a tile, a run of wire) is
## drawn here.
##
## The six that borrow nothing are Nonogram, Sudoku, Bridges, Quilt, Paper
## Planes and Pinwheel, and for the same reason: none of those boards has a
## character at all. Their pictures are entirely `_draw` -- tiles for the
## first, a ruled three-by-three fragment with numerals for the second, a sea
## with islets on it for the third, a part-sewn blanket for the fourth,
## bent trails with darts for the fifth, and a frame of pinned pieces with
## one of them turned off its square for the sixth -- and none of them has a
## branch of `_build`.
##
## A new card costs one branch of `_build` and, if it needs furniture, one
## of `_draw`. That is the same bargain the dioramas offered
## (legacy/ui/hud/card_scene.gd), without the World3D.
## Spec: docs/superpowers/specs/2026-09-18-flat-menu-design.md, section 3.

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Friends = preload("res://ui/faces/friends.gd")
const Fruit = preload("res://ui/faces/fruit.gd")
const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")
const LanternFace = preload("res://ui/faces/lantern_face.gd")
const CourtLantern = preload("res://ui/faces/court_lantern.gd")
const TentFace = preload("res://ui/faces/tent_face.gd")
const ConiferFace = preload("res://ui/faces/conifer_face.gd")
const MarkerFace = preload("res://ui/faces/marker_face.gd")
const SnailFace = preload("res://ui/faces/snail_face.gd")
const BeeFace = preload("res://ui/faces/bee_face.gd")
const SproutFace = preload("res://ui/faces/sprout_face.gd")
const MushroomFace = preload("res://ui/faces/mushroom_face.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const MosaicTile = preload("res://ui/faces/mosaic_tile.gd")
const PatchCloth = preload("res://ui/faces/patch_cloth.gd")
const PinWheel = preload("res://ui/faces/pin_wheel.gd")
const PaperPlane = preload("res://ui/faces/paper_plane.gd")
const Cat = preload("res://ui/faces/caterpillar.gd")
const Rings2D = preload("res://puzzles/rings2d.gd")

## The box every picture is composed in. The card scales it to fit.
const ART := Vector2(320.0, 118.0)

## Bridges' three islets and their radius, in the box's own units. The pair
## on the left face each other across a lane the double run fills; the third
## stands clear of both, so nothing on the card reads as a run that is not
## drawn. An islet is 0.40 of a cell on the board, so the cell these are
## spaced and planked by is SEA_R / 0.40.
const SEA_R := 26.0
const SEA_ISLETS := [Vector2(-100.0, 14.0), Vector2(26.0, 14.0), Vector2(104.0, -20.0)]

## Fairy Lights, in the box's own units. Everything in that picture is a
## fraction of one cell, exactly as the board sizes its own pieces off the
## cell it was dealt (`POST_R` 0.34, `LANTERN_R` 0.27, `WIRE` 0.13 in
## puzzles/fairy_lights2d.gd), so the card keeps the board's proportions
## rather than being measured by eye. LIGHTS_CELL is the one number chosen
## here: at 100 a post and two papers fill the 320 box's width with the
## post's finial and the papers' tassels both clear of its edges, and the
## three of them stand exactly one cell apart, which is the spacing they
## would have as three cells of a real garden.
const LIGHTS_CELL := 100.0
const LIGHTS_POST_R := 0.34
const LIGHTS_LAMP_R := 0.27
const LIGHTS_WIRE := 0.13
## Where the run hangs, where the post stands on it, and where the two papers
## are strung along it. The far lamp ends the run, because on the board a
## lantern is always the end of a branch and never a thing a wire runs past.
const LIGHTS_Y := 2.0
const LIGHTS_POST_X := -105.0
const LIGHTS_LAMPS := [-5.0, 95.0]
## Which two of Untangle's five papers. Not the amber: lit, it comes back
## almost exactly the wire's own gold, and the one thing this picture has to
## say is which of the two things is the light and which is the cable.
const LIGHTS_HUES := [1, 2]
## Pinwheel's frame, in the box's own units. Three rows is what 118 will hold
## at a cell worth drawing a wheel on, and eight columns is what the tiling
## below takes; the board's own bands are taller than they are wide and a box
## 2.7 times wider than it is tall cannot show one, so the card states the
## game rather than the shape of a band.
const PIN_CELL := 35.0
const PIN_COLS := 8
const PIN_ROWS := 3
const PIN_PAD := 5.0
## The wheel, in cells. **The one number here not taken from the board**: at
## `pinwheel2d.gd`'s own 0.19 a wheel is five pixels across in this box and
## comes out a dot, and the four vanes are the whole of the drawing.
const PIN_WHEEL_R := 0.32

## The frame's pieces, as [cloth index, pin cell, cells covered]. Four are
## lying in their square and tile the frame with the fifth; the fifth is
## `PIN_TURNED`, a quarter turn clockwise about its own pin off where it
## belongs, which is what puts two pieces on (3, 0) and (5, 1) and leaves
## (3, 2) and (4, 2) bare. **A card of a solved frame would say nothing
## about the game**: the stain and the bare ground are the whole of it.
const PIN_PIECES := [
	[0, Vector2i(0, 1), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(0, 2), Vector2i(1, 2)]],
	[6, Vector2i(2, 1), [Vector2i(2, 0), Vector2i(3, 0), Vector2i(1, 1),
		Vector2i(2, 1), Vector2i(2, 2)]],
	[3, Vector2i(6, 0), [Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0),
		Vector2i(5, 1), Vector2i(5, 2)]],
	[4, Vector2i(7, 2), [Vector2i(6, 1), Vector2i(7, 1), Vector2i(6, 2),
		Vector2i(7, 2)]],
]
const PIN_TURNED := [2, Vector2i(4, 1), [Vector2i(3, 0), Vector2i(4, 0),
	Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]]
const PIN_STAINED := [Vector2i(3, 0), Vector2i(5, 1)]

## Caterpillar's card: Pinwheel's 8 by 3 strip of ground, the caterpillar
## part-way through its walk -- leaves 1 and 2 eaten under it, 3 and 4 still
## ahead -- and one fence. The walk is tail first.
const CAT_WALK := [Vector2i(0, 2), Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 1),
	Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]
const CAT_LEAVES := [Vector2i(0, 2), Vector2i(1, 1), Vector2i(7, 1), Vector2i(5, 2)]
const CAT_FENCE := [Vector2i(5, 1), Vector2i(5, 2)]

var id := ""
## Design units per pixel, and the box's centre, both set by _relayout.
var _u := 1.0
var _c := Vector2.ZERO
## Hidden Word's band, held here rather than as a function local: a canvas
## command keeps a mesh by RID and not by reference, so a local ArrayMesh is
## freed before the frame it was queued in ever renders.
var _band_mesh: ArrayMesh
## Bridges' sea, islets and planks, held for the same RID reason.
var _sea_mesh: ArrayMesh
## Quilt's backing, its patches and their seams, likewise.
var _quilt_mesh: ArrayMesh
## Fairy Lights' run of wire and its post, likewise.
var _lights_mesh: ArrayMesh
## Paper Planes' sky -- the dots, the trails and the darts, all baked into
## one mesh -- held here for exactly the same reason as `_band_mesh` above.
var _sky_mesh: ArrayMesh
## Pinwheel's frame, its pieces, the stain over them and every wheel, again
## for the RID reason and not for the arithmetic.
var _pinwheel_mesh: ArrayMesh
var _caterpillar_mesh: ArrayMesh
## Rings' three pegs, held for the same reason as _band_mesh above.
var _rings_mesh: ArrayMesh

func _init(the_id := "") -> void:
	id = the_id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _ready() -> void:
	resized.connect(_relayout)
	_relayout()

## In the picture's own units: (0, 0) is the middle of the box.
func at(x: float, y: float) -> Vector2:
	return _c + Vector2(x, y) * _u

func _relayout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_u = minf(size.x / ART.x, size.y / ART.y)
	_c = size * 0.5
	# Taken out of the tree before being queued: two resizes in one frame
	# would otherwise find the previous pass's children still parented (a
	# queue_free only lands at the end of the frame) and draw both casts
	# over each other until it did.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build()
	queue_redraw()

## Seats a face of `seat` design units, centred on (x, y).
func _seat(face: Control, seat: float, x: float, y: float) -> Control:
	face.size = Vector2(seat, seat) * _u
	face.pivot_offset = face.size * 0.5
	face.position = at(x, y) - face.size * 0.5
	add_child(face)
	return face

func _build() -> void:
	match id:
		"binairo":
			_seat(SunFace.new(), 74.0, -44.0, 2.0)
			var moon := MoonFace.new()
			moon.rocks = true
			_seat(moon, 62.0, 40.0, -2.0)
		"mastermind":
			# Three of the seven, on the tray _draw lays under them.
			for i in 3:
				add_child(Friends.make(i + 3, 50.0 * _u, at(-64.0 + i * 64.0, -2.0)))
		"balance":
			# The two pans of the beam _draw tilts; the fruit ride its ends,
			# so the picture reads as a weighing and not two loose fruit.
			add_child(Fruit.make(0, 52.0 * _u, at(-64.0, -24.0)))
			add_child(Fruit.make(1, 44.0 * _u, at(66.0, -11.0)))
		"untangle":
			var seats := [Vector2(-78.0, -26.0), Vector2(70.0, -30.0), Vector2(-56.0, 30.0), Vector2(80.0, 24.0)]
			for i in seats.size():
				var lamp := LanternFace.new()
				_seat(lamp, 56.0, seats[i].x, seats[i].y)
		"shikaku":
			# Two plots, two numbers; the grid under them is _draw's.
			var a := MarkerFace.new()
			a.number = 4
			_seat(a, 44.0, -76.0, -19.0)
			var b := MarkerFace.new()
			b.number = 2
			_seat(b, 44.0, 38.0, 19.0)
		"tents":
			_seat(ConiferFace.new(), 84.0, -86.0, 0.0)
			_seat(ConiferFace.new(), 70.0, 76.0, 8.0)
			_seat(TentFace.new(), 78.0, -6.0, 6.0)
		"lightup":
			var lamp := CourtLantern.new()
			_seat(lamp, 58.0, -81.0, 0.0)
		"oneline":
			_seat(SnailFace.new(), 96.0, 6.0, 4.0)
		"queens":
			# The queen bee on a patch of the court _draw lays under her.
			_seat(BeeFace.new(), 72.0, 0.0, 2.0)
		"hiddenword":
			# No cast: the three marks are the whole picture, and _draw lays
			# them and the band under them, so this branch seats nothing.
			pass
		"bridges":
			# Nothing to seat either: that board adds no character to
			# ui/faces/ (spec section 8), so an islet is drawn furniture and
			# the whole picture is _draw's.
			pass
		"wordtrail":
			# The sprout beside a small field: the field is one plain Control
			# whose own `draw` this branch wires up, so the picture costs one
			# branch of _build and none of _draw (spec section 11).
			_seat(SproutFace.new(), 58.0, -122.0, 6.0)
			var field := Control.new()
			field.mouse_filter = Control.MOUSE_FILTER_IGNORE
			field.size = Vector2(210.0, 100.0) * _u
			field.position = at(32.0, 2.0) - field.size * 0.5
			field.draw.connect(_draw_word_field.bind(field))
			add_child(field)
		"mushroom":
			# Two mushrooms on the turf strip _draw lays under them, the tile
			# and its numeral drawn beside them. `sprig` stays false: it marks
			# a mushroom a hint planted, which would be a lie on a card.
			# The y's here were set by eye against a rendered, zoomed crop,
			# not by the body's arithmetic alone (a first pass trusted the
			# arithmetic and buried both mushrooms to the chin -- see
			# _draw_patch's comment): each mushroom's own foot lands right at
			# the strip's top (24), fully clear of it, rather than sunk in.
			_seat(MushroomFace.new(), 62.0, -104.0, -1.0)
			_seat(MushroomFace.new(), 48.0, -26.0, 5.0)
		"fairylights":
			# Two paper lanterns strung on the run _draw lays under them, and
			# **lit**: `lit` is 1, so each wears the warmed paper, its face
			# and its own halo -- an unlit garden is what that board looks
			# like before it is played, and a card shows the thing you are
			# playing for. `dims` is left alone for the same reason: it is
			# the wash an *unlit* paper takes, and nothing here is unlit.
			# Seated on the run's own line rather than under it: on the board
			# the wire runs into a lantern's middle and the paper covers the
			# joint, which is why the cable may pass behind these two without
			# either reading as floating over it.
			var lamp_seat := LIGHTS_CELL * LIGHTS_LAMP_R * LanternFace.SEAT
			for i in LIGHTS_LAMPS.size():
				var lamp := LanternFace.new()
				lamp.hue = int(LIGHTS_HUES[i])
				lamp.lit = 1.0
				_seat(lamp, lamp_seat, float(LIGHTS_LAMPS[i]), LIGHTS_Y)
		"rings":
			# No cast: Rings seats no character, joining Nonogram, Hidden
			# Word, Word Trail and Sudoku. Its whole picture is three pegs
			# drawn with the board's own peg shape (Rings2D._append_peg)
			# scaled down, so -- like Word Trail's field -- it is one plain
			# Control this branch wires its own draw to, rather than a
			# branch of the top _draw() match: there is no furniture
			# distinct from the piece here, so there is nothing for that
			# match to add.
			# This calls rings2d.gd's own underscore-prefixed
			# `_append_peg` directly (below) rather than a
			# published API -- deliberately, so the card draws the board's
			# real ring instead of a second copy of it; see that file's
			# header for what this costs.
			var field := Control.new()
			field.mouse_filter = Control.MOUSE_FILTER_IGNORE
			field.size = Vector2(300.0, 112.0) * _u
			field.position = at(0.0, 0.0) - field.size * 0.5
			field.draw.connect(_draw_rings_pegs.bind(field))
			add_child(field)
		_:
			pass
		_:
			pass

# --- the furniture the faces stand on ---

func _draw() -> void:
	if _u <= 0.0:
		return
	match id:
		"mastermind": _draw_tray()
		"balance": _draw_beam()
		"untangle": _draw_cords()
		"shikaku": _draw_field()
		"lightup": _draw_court()
		"oneline": _draw_trail()
		"nonogram": _draw_mosaic()
		"queens": _draw_regions()
		"hiddenword": _draw_letters()
		"mushroom": _draw_patch()
		"sudoku": _draw_sudoku()
		"bridges": _draw_sea()
		"quilt": _draw_quilt()
		"fairylights": _draw_lights()
		"planes": _draw_planes()
		"pinwheel": _draw_pinwheel()
		"caterpillar": _draw_caterpillar()

func _round(x: float, y: float, w: float, h: float, radius: float, colour: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = colour
	sb.set_corner_radius_all(int(radius * _u))
	draw_style_box(sb, Rect2(at(x, y), Vector2(w, h) * _u))

func _disc(x: float, y: float, r: float, colour: Color) -> void:
	draw_circle(at(x, y), r * _u, colour)

func _line(pts: Array, width: float, colour: Color) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append(at(v.x, v.y))
	draw_polyline(p, colour, width * _u, true)

func _text(s: String, x: float, y: float, px: float, colour: Color) -> void:
	var font := CozyTheme.display(700)
	var sz := int(px * _u)
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string(font, at(x, y) - Vector2(w * 0.5, 0.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, colour)

## Code Break: the wooden tray the friends are seated in.
func _draw_tray() -> void:
	_round(-112.0, -38.0, 224.0, 78.0, 16.0, Pal.WOOD)
	_round(-104.0, -32.0, 208.0, 58.0, 12.0, Pal.PLAQUE_DEEP)

## Balance: the fulcrum, and the beam tilted across it.
func _draw_beam() -> void:
	var tilt := 0.11
	var pivot := at(0.0, 30.0)
	draw_colored_polygon(PackedVector2Array([
		at(-18.0, 34.0), at(18.0, 34.0), at(0.0, -2.0)]), Pal.PLAQUE_DEEP)
	var half := 98.0 * _u
	var thick := 8.0 * _u
	var d := Vector2(cos(tilt), sin(tilt))
	var n := Vector2(-d.y, d.x)
	var mid := pivot - Vector2(0.0, 34.0 * _u)
	draw_colored_polygon(PackedVector2Array([
		mid - d * half - n * thick, mid + d * half - n * thick,
		mid + d * half + n * thick, mid - d * half + n * thick]), Pal.WOOD)

## Untangle: two cords that cross, under the four lanterns.
func _draw_cords() -> void:
	var p := [Vector2(-78.0, -26.0), Vector2(70.0, -30.0), Vector2(-56.0, 30.0), Vector2(80.0, 24.0)]
	for e in [[0, 3], [1, 2], [0, 1], [2, 3]]:
		_line([p[e[0]], p[e[1]]], 7.0, Color(Pal.WOOD, 0.75))

## Shikaku: a field of five by three, with two plots ruled off on it.
func _draw_field() -> void:
	var cell := 38.0
	var x0 := -cell * 2.5
	var y0 := -cell * 1.5
	for r in 3:
		for k in 5:
			_round(x0 + k * cell + 3.0, y0 + r * cell + 3.0, cell - 6.0, cell - 6.0, 7.0, Pal.STONE)
	for plot in [[0, 0, 2, 2, Pal.ACCENT], [3, 1, 2, 1, Pal.ACCENT_2]]:
		var rect := Rect2(at(x0 + plot[0] * cell + 2.0, y0 + plot[1] * cell + 2.0),
			Vector2(plot[2] * cell - 4.0, plot[3] * cell - 4.0) * _u)
		draw_rect(rect, plot[4], false, 5.0 * _u)

## Light Up: the lamp's own row, a black block with its count, and the cell
## the block keeps dark.
func _draw_court() -> void:
	var cell := 54.0
	var x0 := -cell * 2.0
	var fills: Array[Color] = [Pal.LAMPLIT_FLOOR, Pal.LAMPLIT_FLOOR, Pal.BLOCK_STONE, Pal.STONE]
	for k in 4:
		_round(x0 + k * cell + 4.0, -cell * 0.5 + 4.0, cell - 8.0, cell - 8.0, 11.0, fills[k])
	_text("1", x0 + cell * 2.5, 10.0, 30.0, Pal.SURFACE)
	# The lamp's own light, under it: without a halo the row reads as a face
	# sitting on some tiles rather than a lamp lighting them.
	_disc(x0 + cell * 0.5, 0.0, 40.0, Color(Pal.SUN, 0.22))
	_disc(x0 + cell * 0.5, 0.0, 26.0, Color(Pal.SUN, 0.18))

## One Line: the posts and the stroke the snail is walking.
func _draw_trail() -> void:
	var p := [Vector2(-88.0, 24.0), Vector2(-26.0, -26.0), Vector2(38.0, 22.0), Vector2(92.0, -24.0)]
	_line(p, 9.0, Color(Pal.ACCENT, 0.8))
	for v in p:
		_disc(v.x, v.y, 12.0, Pal.SURFACE)
		draw_arc(at(v.x, v.y), 12.0 * _u, 0.0, TAU, 18, Pal.WOOD, 4.0 * _u, true)

## Nonogram: a three by three of the picture, with its clues beside it. The
## tiles are drawn rather than seated, because ui/faces/mosaic_tile.gd is
## builder shapes for one big mesh, not a Control of its own.
func _draw_mosaic() -> void:
	# The clue band stands above the grid, so the grid sits low in the box:
	# at y0 = -1.4 cells the numbers' caps were cut off by the card's top.
	var cell := 27.0
	var x0 := -cell * 1.1
	var y0 := -cell * 0.85
	var grid := [[1, 1, 0], [0, 1, 1], [1, 1, 0]]
	for r in 3:
		for k in 3:
			var fill: Color = Pal.MOSAIC if grid[r][k] == 1 else Pal.STONE
			_round(x0 + k * cell + 2.0, y0 + r * cell + 2.0, cell - 4.0, cell - 4.0, 6.0, fill)
	for r in 3:
		_text("2", x0 - 15.0, y0 + r * cell + cell * 0.72, 21.0, Pal.TEXT)
	var cols := ["1 1", "3", "1"]
	for k in 3:
		_text(cols[k], x0 + k * cell + cell * 0.5, y0 - 8.0, 19.0, Pal.TEXT)

## Queens: six cells of the court in two regions with the seam between them,
## under the bee, and the soft disc she stands on.
func _draw_regions() -> void:
	var cell := 54.0
	var x0 := -cell * 1.5
	var y0 := -cell
	var plan := [[1, 1, 2], [1, 2, 2]]
	for r in 2:
		for k in 3:
			_round(x0 + k * cell, y0 + r * cell, cell, cell, 0.0, Pal.REGION[plan[r][k]])
	_line([Vector2(x0 + 2.0 * cell, y0), Vector2(x0 + 2.0 * cell, y0 + cell),
		Vector2(x0 + cell, y0 + cell), Vector2(x0 + cell, y0 + 2.0 * cell)], 4.0, Pal.TEXT)
	draw_rect(Rect2(at(x0, y0), Vector2(3.0 * cell, 2.0 * cell) * _u), Pal.TEXT, false, 4.0 * _u)
	_disc(0.0, 31.0, 20.0, Color(Pal.TEXT, 0.14))

## Hidden Word: three marks in a row -- HIT, NEAR and MISS, lettered H, I, D
## for the game's own name -- seated on the same turf and clouds the board
## stands its grid on (ui/flat/scenery.gd), so the card and the board read as
## the one drawing. No character sits here, so unlike its ten siblings this
## branch's whole picture is `_draw`, in a single mesh and three tiles.
func _draw_letters() -> void:
	var b := Face.Builder.new()
	var turf: Color = Pal.LEAF.lerp(Pal.PARCHMENT, 0.4)
	b.fan(Face.Builder.round_rect(at(-160.0, 24.0), Vector2(320.0, 35.0) * _u, 16.0 * _u), turf)
	var puff: Color = Pal.PARCHMENT.lerp(Pal.SURFACE, Scenery.CLOUD_LIFT)
	Scenery.cloud(b, at(-108.0, -44.0), 15.0 * _u, puff)
	Scenery.cloud(b, at(104.0, -48.0), 12.0 * _u, puff)
	_band_mesh = b.mesh()
	draw_mesh(_band_mesh, null)
	var cell := 62.0
	var xs := [-70.0, 0.0, 70.0]
	var marks := [Pal.GOOD, Pal.WORD_NEAR, Pal.WORD_MISS]
	var letters := ["H", "I", "D"]
	var font := CozyTheme.display(700)
	for i in 3:
		_round(xs[i] - cell * 0.5, -cell * 0.5 - 6.0, cell, cell, 12.0, marks[i])
		MosaicTile.letter(self, at(xs[i], -6.0), cell * _u, letters[i], Vector2.ONE, Pal.PAPER, font)

## Mushroom Patch: the turf strip the pair stands on -- TURF_REACH, the same
## pale meadow a covered cell wears on the board itself, so the card and the
## field read as one screen -- and, beside them, a cream SURFACE tile
## carrying a number. The numeral is written in LEAF_DEEP rather than TEXT: a
## turned-over cell's own ink is TEXT, but LEAF_DEEP is what a number turns
## the moment its count is satisfied, and that is the hint worth giving on a
## card for a board nobody has played yet. The tile stays SURFACE rather than
## washing toward LEAF, because a fully green tile would claim a solved board
## rather than hint at the mechanic.
##
## The strip's top is 24 and its height 35, landing its bottom exactly on the
## box's own edge (ART.y * 0.5 = 59) with its radius fully inside that span
## -- Hidden Word's turf band (_draw_letters) is drawn the same way for the
## same reason: a strip cut short of the radius, or clipped mid-curve by
## `clip_contents`, shows its straight-cut bottom overhanging the card
## plate's own rounded corner, which reads as a drawing bug rather than
## ground running off the frame. A first pass here got this wrong (top 20,
## height 50, bottom 70 clipped at 59) and, worse, seated the mushrooms with
## their feet above the strip's top, burying them to the chin and clipping
## the smaller one's face; both are fixed by the numbers below, checked
## against a rendered, zoomed crop rather than by arithmetic alone.
func _draw_patch() -> void:
	_round(-150.0, 24.0, 195.0, 35.0, 16.0, Pal.TURF_REACH)
	_round(70.0, -38.0, 76.0, 76.0, 14.0, Pal.SURFACE)
	_text("3", 108.0, 12.0, 42.0, Pal.LEAF_DEEP)

## Word Trail: a small field of letter tiles beside the sprout, four by
## three, with two grey wall slabs and one trail bending twice through the
## rest in Pal.LEAF over Pal.LEAF_TILE, its letters in Pal.LEAF_DEEP. Wired
## as `field`'s own `draw` handler rather than a branch of this file's
## `_draw()` (spec section 11), so the field is a plain Control this method
## draws directly on, in its own local pixels -- never a mesh, an image or a
## SubViewport. The letters spell nothing, so the card never reads as a
## solvable day.
func _draw_word_field(field: Control) -> void:
	const COLS := 4
	const ROWS := 3
	var raw := minf(field.size.x / COLS, field.size.y / ROWS)
	var gap := raw * 0.14
	var cell := minf((field.size.x - gap * (COLS - 1)) / COLS, (field.size.y - gap * (ROWS - 1)) / ROWS)
	var fw := cell * COLS + gap * (COLS - 1)
	var fh := cell * ROWS + gap * (ROWS - 1)
	var origin := (field.size - Vector2(fw, fh)) * 0.5
	var walls := [Vector2i(3, 0), Vector2i(0, 2)]
	var trail := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2)]
	var letters := {
		Vector2i(0, 0): "Q", Vector2i(1, 0): "X", Vector2i(2, 0): "K",
		Vector2i(0, 1): "R", Vector2i(1, 1): "J", Vector2i(2, 1): "Z", Vector2i(3, 1): "Y",
		Vector2i(1, 2): "F", Vector2i(2, 2): "V", Vector2i(3, 2): "W",
	}
	var on_trail := {}
	for c in trail:
		on_trail[c] = true
	var corner := func(cell_pos: Vector2i) -> Vector2:
		return origin + Vector2(cell_pos) * (cell + gap)
	for r in ROWS:
		for k in COLS:
			var cell_pos := Vector2i(k, r)
			var face: Color = Pal.SURFACE
			if walls.has(cell_pos):
				face = Pal.STONE_GIVEN
			elif on_trail.has(cell_pos):
				face = Pal.LEAF_TILE
			var sb := StyleBoxFlat.new()
			sb.bg_color = face
			sb.set_corner_radius_all(int(cell * 0.18))
			field.draw_style_box(sb, Rect2(corner.call(cell_pos), Vector2(cell, cell)))
	if trail.size() > 1:
		var pts := PackedVector2Array()
		for c in trail:
			pts.append(corner.call(c) + Vector2.ONE * (cell * 0.5))
		field.draw_polyline(pts, Color(Pal.LEAF, 0.5), cell * 0.42, true)
	var font := CozyTheme.display(700)
	for cell_pos: Vector2i in letters:
		var mid: Vector2 = corner.call(cell_pos) + Vector2.ONE * (cell * 0.5)
		var ink: Color = Pal.LEAF_DEEP if on_trail.has(cell_pos) else Pal.TEXT
		MosaicTile.letter(field, mid, cell, String(letters[cell_pos]), Vector2.ONE, ink, font)

## Sudoku: a three-by-three fragment of the board with the heavy rule round
## it and three numerals in ink. No cast -- this board's pieces are numbers,
## and ui/faces/ gets nothing, which is what Nonogram decided and Hidden Word
## confirmed. The outline is `draw_rect`'s own unfilled rectangle, the way
## _draw_field and _draw_regions already rule off a plot and a court -- there
## is no `_frame` helper in this file, and this is what stands in for it.
func _draw_sudoku() -> void:
	var cell := 30.0
	var x0 := -cell * 1.5
	var y0 := -cell * 1.5
	for r in 3:
		for c in 3:
			var tint: Color = Pal.GRID_TINT if (r + c) % 2 == 1 else Pal.SURFACE
			_round(x0 + c * cell + 1.0, y0 + r * cell + 1.0, cell - 2.0, cell - 2.0, 4.0, tint)
	draw_rect(Rect2(at(x0, y0), Vector2(cell * 3.0, cell * 3.0) * _u), Pal.GRID_RULE, false, 3.0 * _u)
	_text("5", x0 + cell * 0.5, y0 + cell * 0.78, 26.0, Pal.TEXT)
	_text("3", x0 + cell * 1.5, y0 + cell * 1.78, 26.0, Pal.LEAF_DEEP)
	_text("7", x0 + cell * 2.5, y0 + cell * 2.78, 26.0, Pal.TEXT)

## Bridges: three turf islets with their numbers on a small sea panel, two of
## them joined by a double run and one still waiting. That board adds nothing
## to ui/faces/ (spec section 8), so unlike its siblings this picture seats no
## character at all -- every piece of it is drawn furniture, and it is one
## mesh (the pool, the shallows, the ripples, the two planks and the islets)
## with the numbers as draw commands over it, which is the arrangement the
## board itself uses.
##
## Every colour is a core/palette.gd entry or a mix of exactly two of them,
## and the mixes are the board's own (spec section 7): the sea is WATER_HI let
## down into PAPER rather than WATER straight, and on a pale sea the mark is
## darker than the water, so Pal.WATER is the ripple and not the water.
func _draw_sea() -> void:
	var sea: Color = Pal.WATER_HI.lerp(Pal.PAPER, 0.46)          # #a4cde6
	var sea_pale: Color = Pal.WATER_HI.lerp(Pal.PAPER, 0.74)     # #cfdfe4
	var sea_deep: Color = Pal.WATER_HI.lerp(Pal.TEXT, 0.20)      # #5896c2
	var sea_shade: Color = Pal.WATER.lerp(Pal.TEXT, 0.35)        # #336e99
	var sand_deep: Color = Pal.ACORN.lerp(Pal.TEXT, 0.22)
	var bank_deep: Color = Pal.BANK.lerp(Pal.TEXT, 0.28)
	var bank_hi: Color = Pal.BANK.lerp(Pal.SURFACE, 0.26)
	var b := Face.Builder.new()
	# The pool, with its darker bottom edge showing under it.
	b.fan(Face.Builder.round_rect(at(-156.0, -54.0), Vector2(312.0, 108.0) * _u, 12.0 * _u), sea_deep)
	b.fan(Face.Builder.round_rect(at(-156.0, -54.0), Vector2(312.0, 105.0) * _u, 12.0 * _u), sea)
	# The shallows: a paler band inside the rim, not a deeper one.
	b.stroke(Face.Builder.round_rect(at(-152.0, -50.0), Vector2(304.0, 100.0) * _u, 9.0 * _u),
		8.0 * _u, Color(sea_pale, 0.85), true)
	for r: Array in [[-140.0, -34.0, 28.0], [40.0, -42.0, 26.0], [-34.0, 42.0, 30.0]]:
		var from := at(r[0], r[1])
		var to := at(r[0] + r[2], r[1])
		var arc := Face.Builder.bezier2(from, at(r[0] + r[2] * 0.5, r[1] - 3.0), to, 8)
		arc.append(to)
		b.stroke(arc, 2.6 * _u, Color(Pal.WATER, 0.24))
	# The run: two planks in the lane between the first two islets, thick and
	# spaced as the board's are -- 0.115 of a cell with 0.095 between them.
	var cell := SEA_R / 0.40
	var th := cell * 0.115
	var gap := cell * 0.095
	var x0: float = SEA_ISLETS[0].x + SEA_R
	var x1: float = SEA_ISLETS[1].x - SEA_R
	for i in 2:
		var y := SEA_ISLETS[0].y + i * (th + gap) - (th + gap) * 0.5
		b.fan(Face.Builder.round_rect(at(x0 + 2.0, y - th * 0.5 + 4.0),
			Vector2(x1 - x0, th) * _u, th * 0.34 * _u), Color(Pal.TEXT, 0.22))
		b.fan(Face.Builder.round_rect(at(x0, y - th * 0.5),
			Vector2(x1 - x0, th) * _u, th * 0.34 * _u), Pal.WOOD_DEEP)
		b.fan(Face.Builder.round_rect(at(x0, y - th * 0.5),
			Vector2(x1 - x0, th - 2.0) * _u, th * 0.34 * _u), Pal.DECK)
		var step := cell * 0.30
		var s := step * 0.6
		while s < x1 - x0 - step * 0.3:
			b.stroke(PackedVector2Array([at(x0 + s, y - th * 0.5 + 1.0), at(x0 + s, y + th * 0.5 - 2.0)]),
				2.0 * _u, Color(Pal.WOOD_DEEP, 0.28), false, false)
			s += step
	# The islets: a coloured shadow on the water, a beach of ACORN over its
	# own wet sand, turf on top and one sun cap. ACORN rather than STONE is
	# what gives the islet an edge on a pale sea (spec section 7).
	for seat: Vector2 in SEA_ISLETS:
		b.ellipse(at(seat.x, seat.y + SEA_R * 0.30), SEA_R * 1.02 * _u, SEA_R * 0.40 * _u,
			Color(sea_shade, 0.30))
		b.disc(at(seat.x, seat.y + SEA_R * 0.07), SEA_R * _u, sand_deep)
		b.disc(at(seat.x, seat.y), SEA_R * _u, Pal.ACORN)
		b.disc(at(seat.x, seat.y + SEA_R * 0.04), SEA_R * 0.80 * _u, bank_deep)
		b.disc(at(seat.x, seat.y), SEA_R * 0.80 * _u, Pal.BANK)
		b.ellipse(at(seat.x - SEA_R * 0.22, seat.y - SEA_R * 0.34), SEA_R * 0.30 * _u,
			SEA_R * 0.17 * _u, Color(bank_hi, 0.55))
	_sea_mesh = b.mesh()
	draw_mesh(_sea_mesh, null)
	# The numbers read as a real board part-solved: the double run spends two
	# at each end, so the 2 is met, the 3 still wants one more, and the third
	# islet has spent nothing at all.
	var needs := ["2", "3", "1"]
	for i in 3:
		_text(needs[i], SEA_ISLETS[i].x, SEA_ISLETS[i].y + SEA_R * 0.32, SEA_R * 0.95, Pal.TEXT)

## Quilt: a backing part covered, five patches sewn onto it with the stitch
## showing along every seam between two of them, and one patch still waiting
## beside it at the rack's smaller cell -- the whole game in one picture.
##
## No cast. This board seats no character either (spec section 8), which
## makes it the fourth after Nonogram, Sudoku and Bridges, so the picture is
## entirely drawn furniture. It is **the board's own drawing** and not a
## second one: `ui/faces/patch_cloth.gd` traces the silhouette, rounds it and
## lays the lip under it here exactly as `puzzles/quilt2d.gd` does, so a card
## and its board cannot drift apart. One mesh, one draw call.
func _draw_quilt() -> void:
	var cell := 22.0 * _u
	var b := Face.Builder.new()
	# The backing: a four-row blanket with two corners bitten out of it, so
	# the shape reads as cut cloth rather than as a grid.
	var back: Array = []
	for r in 4:
		for c in 8:
			if (c == 7 and (r == 0 or r == 3)):
				continue
			back.append(Vector2i(c, r))
	var origin := at(-150.0, -44.0)
	PatchCloth.patch(b, PatchCloth.loops(back), origin, cell, Vector2i.ZERO,
		Pal.QUILT_BACK, Pal.LINE)
	# Five patches, by the same colour index the board would give them.
	var sewn := [
		[4, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]],
		[6, [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(2, 1)]],
		[2, [Vector2i(5, 0), Vector2i(6, 0), Vector2i(5, 1), Vector2i(6, 1)]],
		[0, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(0, 3)]],
		[3, [Vector2i(5, 2), Vector2i(6, 2), Vector2i(5, 3), Vector2i(6, 3)]],
	]
	for entry: Array in sewn:
		var i := int(entry[0])
		PatchCloth.patch(b, PatchCloth.loops(entry[1] as Array), origin, cell,
			Vector2i.ZERO, PatchCloth.cloth(i), PatchCloth.cloth_deep(i))
	# The stitch, along the four seams where two patches meet. The hem is
	# left unsewn here: at this size every edge dashed is a hatch, and the
	# seams between patches are the ones that say what the game is.
	var seams := [
		[Vector2(2.0, 0.0), Vector2(2.0, 2.0), 6],
		[Vector2(5.0, 0.0), Vector2(5.0, 1.0), 2],
		[Vector2(0.0, 2.0), Vector2(2.0, 2.0), 0],
		[Vector2(5.0, 2.0), Vector2(7.0, 2.0), 3],
	]
	for seam: Array in seams:
		PatchCloth.stitch(b, origin + (seam[0] as Vector2) * cell,
			origin + (seam[1] as Vector2) * cell, 0.05 * cell,
			0.15 * cell, 0.1 * cell, PatchCloth.cloth_stitch(int(seam[2])))
	# The patch still waiting, at the rack's own smaller cell, and clear of
	# the blanket so it reads as not yet sewn on.
	var wait_cell := 15.0 * _u
	PatchCloth.patch(b, PatchCloth.loops([Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]),
		at(88.0, -15.0), wait_cell, Vector2i.ZERO,
		PatchCloth.cloth(1), PatchCloth.cloth_deep(1))
	_quilt_mesh = b.mesh()
	draw_mesh(_quilt_mesh, null)

## Fairy Lights: the lantern post, a short run of live wire out of it, and
## the two papers strung along that run (seated by `_build`). Everything
## here with no face on it -- the halo, the wire and the post -- is one mesh
## and one draw call, which is the arrangement the board itself uses.
##
## It is drawn in the board's own order and with the board's own numbers
## (`puzzles/fairy_lights2d.gd`, section 5 of the spec): the halo under the
## run **before** any wire, because a live branch has to read as light before
## it reads as cable; then the wire's shade, its face in SUN, and the sheen
## along its back; then the post over the lot, so the cable leaves the post's
## middle the way an arm leaves a cell's. Nothing here is a new colour -- the
## gold is SUN over SUN_DEEP with SUN_RAY in the halo and LANTERN_LIT on the
## sheen, and the post is Light Up's LANTERN iron.
##
## The run is **live for its whole length**: a card shows the thing you are
## playing for, so there is no pale FLAGSTONE wire and no loose end on it.
func _draw_lights() -> void:
	var cell := LIGHTS_CELL
	var wire := cell * LIGHTS_WIRE
	var from := at(LIGHTS_POST_X, LIGHTS_Y)
	var to := at(float(LIGHTS_LAMPS[LIGHTS_LAMPS.size() - 1]), LIGHTS_Y)
	var run := PackedVector2Array([from, to])
	# The lip under the cable. The board's SHADE_DROP is 4 px under a cell of
	# 134 to 188; three of this box's units under a cell of 100 is the same
	# fraction of a cell, which is what keeps the lip the same weight here.
	var drop := Vector2(0.0, 3.0) * _u
	var shade := PackedVector2Array([from + drop, to + drop])
	var b := Face.Builder.new()
	b.stroke(run, wire * 2.7 * _u, Color(Pal.SUN_RAY, 0.15))
	b.stroke(run, wire * 1.6 * _u, Color(Pal.SUN, 0.22))
	b.stroke(shade, wire * _u, Pal.SUN_DEEP)
	b.stroke(run, wire * _u, Pal.SUN)
	b.stroke(run, wire * 0.3 * _u, Color(Pal.LANTERN_LIT, 0.55))
	_lights_post(b, from, cell * LIGHTS_POST_R * _u)
	_lights_mesh = b.mesh()
	draw_mesh(_lights_mesh, null)

## The post, in units of its own R and in the board's own proportions -- the
## iron foot, the pole, the sun in the glass and the hood over it. Redrawn
## here rather than borrowed, the way Bridges' islets are: `_post` on the
## board is an instance method measured off the cell it was dealt, and there
## is no character in `ui/faces/` to seat, because the post has no face.
##
## Its light is the board's own halo, not `_draw_court`'s pair of flat
## discs: a disc's edge is a visible ring at this size -- it was, on the
## first frame shot of this card -- and worse, the post stands 55 units from
## the left of a 320 box while its light reaches 78, so a disc of it is cut
## square by `clip_contents` where a gradient simply runs out.
func _lights_post(b, at_px: Vector2, R: float) -> void:
	var iron: Color = Pal.LANTERN
	b.ellipse(at_px + Vector2(0.0, 1.02) * R, 0.8 * R, 0.2 * R, Color(Pal.TEXT, 0.12))
	_glow(b, at_px + Vector2(0.0, -0.3) * R, 0.3 * R, 2.3 * R, Color(Pal.SUN, 0.3))
	b.fan(Face.Builder.round_rect(at_px + Vector2(-0.46, 0.76) * R,
		Vector2(0.92, 0.22) * R, 0.1 * R), iron)
	b.fan(Face.Builder.round_rect(at_px + Vector2(-0.13, -0.1) * R,
		Vector2(0.26, 0.96) * R, 0.06 * R), iron)
	b.disc(at_px + Vector2(0.0, -0.42) * R, 0.52 * R, Pal.SUN_DEEP)
	b.disc(at_px + Vector2(0.0, -0.46) * R, 0.46 * R, Pal.SUN)
	b.disc(at_px + Vector2(-0.1, -0.56) * R, 0.2 * R, Color(Pal.LANTERN_LIT, 0.55))
	b.fan(Face.Builder.round_rect(at_px + Vector2(-0.34, -1.08) * R,
		Vector2(0.68, 0.24) * R, 0.1 * R), iron)
	b.fan(Face.Builder.round_rect(at_px + Vector2(-0.08, -1.28) * R,
		Vector2(0.16, 0.24) * R, 0.06 * R), iron)

## A disc of light at `inner` fading to nothing at `outer`, built as two
## rings and the band between them -- what a canvas radial gradient comes to
## once it is triangles. `ui/faces/lantern_face.gd`'s own halo, which
## `puzzles/fairy_lights2d.gd` already keeps a copy of for the same reason
## this file needs one: it is a method on a Control there, and the post has
## no face and so is not one.
func _glow(b, centre: Vector2, inner: float, outer: float, warm: Color) -> void:
	if warm.a <= 0.0:
		return
	var clear := Color(warm, 0.0)
	var segments: int = LanternFace.GLOW_SEGMENTS
	var mid: int = b.vertex(centre, warm)
	var ring_i: int = b.verts.size()
	for i in segments:
		b.vertex(centre + Vector2.from_angle(TAU * i / segments) * inner, warm)
	var ring_o: int = b.verts.size()
	for i in segments:
		b.vertex(centre + Vector2.from_angle(TAU * i / segments) * outer, clear)
	for i in segments:
		var j := (i + 1) % segments
		b.tri(mid, ring_i + i, ring_i + j)
		b.tri(ring_i + i, ring_o + i, ring_o + j)
		b.tri(ring_i + i, ring_o + j, ring_i + j)
## Paper Planes: the empty sky's own faint dots, and three planes laid over
## them -- a groove each, ending in a folded dart of each of the three papers.
## **The board's own drawing and not a second one**: grooves and darts go
## through `ui/faces/paper_plane.gd`, which `puzzles/planes2d.gd` draws with,
## so the card and the board cannot drift apart. The lattice step here stands
## in for the board's cell, and the dot is a touch fainter because a card is
## read at a glance rather than played on. No cast.
##
## Baked into **one mesh**, the way Hidden Word's turf band is: gl_compatibility
## pays per `draw_*` command, and the board bakes its own planes the same way.
func _draw_planes() -> void:
	var b := Face.Builder.new()
	# The board's paper panel, so the planes read on paper and not on the
	# painted sky behind: a tan rim round a cream field, the board's own.
	var lo := at(-170.0, -52.0)
	var sz := at(170.0, 48.0) - lo
	b.fan(Face.Builder.round_rect(lo + Vector2(0.0, 2.0 * _u), sz, 12.0 * _u),
		Color(Pal.ACORN_DEEP, 0.25))
	b.fan(Face.Builder.round_rect(lo, sz, 12.0 * _u), PaperPlane.rim_colour())
	b.fan(Face.Builder.round_rect(lo + Vector2.ONE * 4.0 * _u, sz - Vector2.ONE * 8.0 * _u,
		8.0 * _u), Pal.SURFACE.lerp(Pal.PARCHMENT, 0.45))
	_dots_sky(b)
	var k := 0
	for trail in [
		[Vector2(-146.0, -34.0), Vector2(-66.0, -34.0), Vector2(-66.0, 18.0)],
		[Vector2(-34.0, -6.0), Vector2(56.0, -6.0)],
		[Vector2(84.0, -40.0), Vector2(84.0, 30.0), Vector2(138.0, 30.0)],
	]:
		_plane_trail(b, trail, k)
		k += 1
	_sky_mesh = b.mesh()
	draw_mesh(_sky_mesh, null)

## The lattice every plane would sit on, coarser than the board's own (a dot
## a cell) because a card is read at a glance rather than played on -- a dot
## a cell here would be a haze at this scale rather than a sky.
func _dots_sky(b) -> void:
	var step := 32.0
	var r := 2.4 * _u
	for gy in range(-1, 2):
		for gx in range(-4, 5):
			b.disc(at(gx * step, gy * step), r, Color(Pal.LINE, 0.4))

## One plane, tail to head, in paper `k`: the lattice step is its cell.
func _plane_trail(b, pts: Array, k: int) -> void:
	var canvas_pts := PackedVector2Array()
	for v in pts:
		canvas_pts.append(at(v.x, v.y))
	var cell := 32.0 * _u
	PaperPlane.trail(b, canvas_pts, cell, k)
	var head: Vector2 = canvas_pts[canvas_pts.size() - 1]
	var dir: Vector2 = (head - canvas_pts[canvas_pts.size() - 2]).normalized()
	PaperPlane.dart(b, head, dir.angle(), cell * 1.15, k)

## Pinwheel: a frame of five pinned pieces with one of them turned off its
## square, so the card carries the two hatched cells where it now sits on its
## neighbours and the two cells of bare ground it has left behind. That is
## what a Pinwheel board looks like while it is being played, and a picture of
## a solved frame would say nothing at all about the game.
##
## No cast. This board seats no character either, which makes it the sixth
## after Nonogram, Sudoku, Bridges, Quilt and Paper Planes, so the picture is
## entirely drawn
## furniture -- and, like Quilt's, it is **the board's own drawing** and not a
## second one: the cloth goes through `ui/faces/patch_cloth.gd` and the pins
## through `ui/faces/pin_wheel.gd`, the same two files `puzzles/pinwheel2d.gd`
## draws with, so a card and its board cannot drift apart. One mesh, one draw
## call.
##
## Every measure but the wheel's radius is the board's own, scaled by the
## cell: the ground is `Pal.QUILT_BACK` ruled in `QUILT_RULE`, a piece is its
## cloth over its own lip with a solid `cloth_stitch` edge, and a contested
## cell is washed in `Pal.TEXT` and then **hatched** -- because a wash alone
## cannot signal state on pieces coloured by index, which is Quilt's "a patch
## cannot blush" read from the other end.
## Spec: docs/superpowers/specs/2026-09-20-pinwheel-flat-design.md, section 4.
func _draw_pinwheel() -> void:
	var cell := PIN_CELL * _u
	var origin := at(-float(PIN_COLS) * PIN_CELL * 0.5, -float(PIN_ROWS) * PIN_CELL * 0.5)
	var b := Face.Builder.new()
	# The ground: Shikaku's unclaimed plot behind the grid, the faint rules
	# between its cells and a rim round the lot, as `_build_frame` lays it.
	var pad := PIN_PAD * _u
	var panel := Face.Builder.round_rect(origin - Vector2.ONE * pad,
		Vector2(PIN_COLS, PIN_ROWS) * cell + Vector2.ONE * (2.0 * pad), 0.24 * cell)
	b.polygon(panel, Pal.QUILT_BACK)
	var rule := maxf(1.0, cell * 0.018)
	for c in range(1, PIN_COLS):
		var x := origin.x + float(c) * cell
		b.stroke(PackedVector2Array([Vector2(x, origin.y),
			Vector2(x, origin.y + float(PIN_ROWS) * cell)]), rule, Pal.QUILT_RULE, false, false)
	for r in range(1, PIN_ROWS):
		var y := origin.y + float(r) * cell
		b.stroke(PackedVector2Array([Vector2(origin.x, y),
			Vector2(origin.x + float(PIN_COLS) * cell, y)]), rule, Pal.QUILT_RULE, false, false)
	b.stroke(panel, maxf(1.5, cell * 0.038), Pal.LINE, true)
	# The four pieces lying in their squares, then the one that is not: it
	# draws over the neighbours it has been turned across, the order the
	# board puts a swinging piece in.
	for piece: Array in PIN_PIECES:
		_pin_piece(b, piece, origin, cell)
	_pin_piece(b, PIN_TURNED, origin, cell)
	for stained: Vector2i in PIN_STAINED:
		_pin_stain(b, stained, origin, cell)
	# Every wheel over everything, because a wheel is the handle. Two of its
	# vanes wear its own piece's deep cloth, which is the only
	# thing saying whose handle it is -- and on a board where a pin can end
	# up underneath another piece, that is load-bearing rather than pretty.
	var all: Array = PIN_PIECES.duplicate()
	all.append(PIN_TURNED)
	for i in all.size():
		var piece: Array = all[i]
		var seat := origin + (Vector2(piece[1] as Vector2i) + Vector2(0.5, 0.5)) * cell
		var r := cell * PIN_WHEEL_R
		PinWheel.shadow(b, seat, r, Pal.TEXT)
		PinWheel.wheel(b, seat, r, float(i) * PI * 0.5, Pal.LINE, Pal.SURFACE,
			PinWheel.BRASS, PatchCloth.cloth_deep(int(piece[0])))
	_pinwheel_mesh = b.mesh()
	draw_mesh(_pinwheel_mesh, null)

## One Pinwheel piece: its cloth over its own lip with a solid edge round it,
## laid through the board's own `PatchCloth` so the silhouette is traced and
## filleted once and not twice.
func _pin_piece(b, piece: Array, origin: Vector2, cell: float) -> void:
	var ci := int(piece[0])
	var lip := Vector2(0.0, PatchCloth.EDGE * cell)
	var edge := maxf(1.0, cell * 0.04)
	for loop: PackedVector2Array in PatchCloth.loops(piece[2] as Array):
		var pts := PatchCloth.laid(loop, origin, cell, Vector2i.ZERO)
		b.polygon(_shifted(pts, lip), PatchCloth.cloth_deep(ci))
		b.polygon(pts, PatchCloth.cloth(ci))
	PatchCloth.print_cloth(b, piece[2] as Array, ci, origin, cell, Vector2i.ZERO)
	for loop: PackedVector2Array in PatchCloth.loops(piece[2] as Array):
		b.stroke(PatchCloth.laid(loop, origin, cell, Vector2i.ZERO), edge,
			PatchCloth.cloth_stitch(ci), true)

## One contested cell: the wash, and the hatch over it. The hatch's phase
## comes off the frame and not off the cell, the way the board's does, so two
## stained cells side by side would carry one unbroken line across the seam.
func _pin_stain(b, at_cell: Vector2i, origin: Vector2, cell: float) -> void:
	var lo := origin + Vector2(at_cell) * cell
	var hi := lo + Vector2.ONE * cell
	b.polygon(Face.Builder.round_rect(lo, Vector2.ONE * cell, 0.22 * cell),
		Color(Pal.TEXT, 0.12))
	var ink := Color(Pal.TEXT, 0.22)
	var step := cell * 0.24
	var width := maxf(1.0, cell * 0.045)
	var phase := origin.x - origin.y
	var j := int(ceil(((lo.x - hi.y) - phase) / step))
	while true:
		var cc := phase + float(j) * step
		if cc > hi.x - lo.y:
			break
		var a := maxf(lo.y, lo.x - cc)
		var z := minf(hi.y, hi.x - cc)
		if z > a:
			b.stroke(PackedVector2Array([Vector2(a + cc, a), Vector2(z + cc, z)]),
				width, ink, false, false)
		j += 1

## `pts` moved by `by`, for the lip under a piece.
func _shifted(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + by
	return out

## Rings: three pegs in a 300 by 112 design box, one full of a colour (four
## rings, locked, its gold cap on) and two still part-sorted -- the same
## three states `_tap_rings()`'s harness engineers on the board itself. Each
## peg is the board's own `Rings2D._append_peg` at a 41-wide ring, so the
## card and the board are one drawing: every proportion there is a fraction
## of the ring's width, and nothing here is copied from it.
func _draw_rings_pegs(field: Control) -> void:
	const RW := 41.0
	const GROUND := 108.0
	var pegs := [
		{"cx": 50.0, "colours": [3, 3, 3, 3], "cap": 1.0},
		{"cx": 150.0, "colours": [0, 1], "cap": 0.0},
		{"cx": 250.0, "colours": [2, 5], "cap": 0.0},
	]
	var b := Face.Builder.new()
	var map := func(p: Vector2) -> Vector2: return p * _u
	for peg in pegs:
		Rings2D._append_peg(b, float(peg["cx"]), GROUND, RW, peg["colours"], map, 1.0, [], [], float(peg["cap"]))
	_rings_mesh = b.mesh()
	field.draw_mesh(_rings_mesh, null)

## Caterpillar: the board's own drawing, through `ui/faces/caterpillar.gd`,
## the file `puzzles/caterpillar2d.gd` draws with, so the card and the board
## cannot drift apart. One mesh, and the four leaf numbers over it.
## Spec: docs/superpowers/specs/2026-09-25-caterpillar-flat-design.md, section 4.
func _draw_caterpillar() -> void:
	var cell := PIN_CELL * _u
	var origin := at(-float(PIN_COLS) * PIN_CELL * 0.5, -float(PIN_ROWS) * PIN_CELL * 0.5)
	var centre := func(c: Vector2i) -> Vector2: return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell
	var b := Face.Builder.new()
	var pad := PIN_PAD * _u
	var panel := Face.Builder.round_rect(origin - Vector2.ONE * pad,
		Vector2(PIN_COLS, PIN_ROWS) * cell + Vector2.ONE * (2.0 * pad), 0.24 * cell)
	b.polygon(panel, Pal.BED_GROUND)
	var rule := maxf(1.0, cell * 0.018)
	for c in range(1, PIN_COLS):
		var x := origin.x + float(c) * cell
		b.stroke(PackedVector2Array([Vector2(x, origin.y),
			Vector2(x, origin.y + float(PIN_ROWS) * cell)]), rule, Pal.BED_LINE, false, false)
	for r in range(1, PIN_ROWS):
		var y := origin.y + float(r) * cell
		b.stroke(PackedVector2Array([Vector2(origin.x, y),
			Vector2(origin.x + float(PIN_COLS) * cell, y)]), rule, Pal.BED_LINE, false, false)
	b.stroke(panel, maxf(1.5, cell * 0.038), Pal.LINE, true)
	var mid: Vector2 = (centre.call(CAT_FENCE[0]) + centre.call(CAT_FENCE[1])) * 0.5
	var th := cell * 0.13
	b.fan(Face.Builder.round_rect(mid - Vector2(cell * 0.49, th * 0.5), Vector2(cell * 0.98, th), th * 0.5), Pal.FENCE_DARK)
	for x: float in [-0.44, 0.0, 0.44]:
		b.disc(mid + Vector2(x * cell, 0.0), th * 0.78, Pal.FENCE_POST)
	var pts := PackedVector2Array()
	var scales: Array = []
	var breath := PackedFloat32Array()
	for c: Vector2i in CAT_WALK:
		pts.append(centre.call(c))
		scales.append(Vector2.ONE)
		breath.append(1.0)
	Cat.body(b, pts, cell, scales, breath)
	for i in CAT_LEAVES.size():
		var at_c: Vector2 = centre.call(CAT_LEAVES[i])
		var r := cell * 0.27
		if i < 2:
			b.disc(at_c, r + cell * 0.06, Pal.SUN)
		b.disc(at_c, r, Pal.TEXT)
	Cat.head(b, pts[pts.size() - 1], Vector2(1.0, 0.0), cell, 1.0, Vector2.ONE, Face.Expr.HAPPY, 1.0)
	_caterpillar_mesh = b.mesh()
	draw_mesh(_caterpillar_mesh, null)
	var font: Font = CozyTheme.display(700)
	var px := int(round(cell * 0.3))
	for i in CAT_LEAVES.size():
		var text := str(i + 1)
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		var rise := font.get_height(px) * 0.5 - font.get_descent(px)
		draw_string(font, centre.call(CAT_LEAVES[i]) + Vector2(-wide * 0.5, rise), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Pal.SURFACE)
