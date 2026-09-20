extends Control

## One puzzle card's picture on the first screen: the same characters the
## board itself plays with (ui/faces/), seated in a 320 by 118 box and
## scaled to whatever the card gives them.
##
## It is never an image and never a render of a model. Twelve of the
## seventeen are made almost entirely of the flat boards' own cast --
## Binairo's sun and moon, Code Break's friends, Balance's fruit, Untangle's
## lanterns, Shikaku's markers, Tents' tent and conifers, Light Up's lamp,
## One Line's snail, Queens' bee, Mushroom Patch's mushrooms, and the shared
## sprout that stands in for Hidden Word's and Word Trail's -- so a card and
## its board are visibly the same drawing. Only the furniture under them (a
## tray, a beam, a tile) is drawn here.
##
## The five that borrow nothing are Nonogram, Sudoku, Bridges, Quilt and
## Rings, and for the same reason: none of those boards has a character at
## all. Four of the five are entirely `_draw` -- tiles for the first, a
## ruled three-by-three fragment with numerals for the second, a sea with
## islets on it for the third and a part-sewn blanket for the fourth.
## **Three of those four have no branch of `_build`**; Bridges keeps an
## empty one, an explicit `pass` under a comment, so that a reader who
## wonders where its islets are seated learns that nothing is. Rings is the
## one that borrows no character and still has a `_build` branch doing real
## work: like Word Trail's field it draws into a plain child `Control` of
## its own, because its picture is one mesh with no furniture under it for
## the top `_draw` match to add.
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
		"rings":
			# No cast: Rings seats no character, joining Nonogram, Hidden
			# Word, Word Trail and Sudoku. Its whole picture is three pegs
			# drawn with the board's own ring shape (Rings2D._append_ring)
			# scaled down, so -- like Word Trail's field -- it is one plain
			# Control this branch wires its own draw to, rather than a
			# branch of the top _draw() match: there is no furniture
			# distinct from the piece here, so there is nothing for that
			# match to add.
			# This calls three of rings2d.gd's own underscore-prefixed
			# helpers and its RING_COLOURS directly (below) rather than a
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

## Rings: three pegs in a 300 by 112 design box, one full of a colour (four
## rings, locked) and two still part-sorted (two rings apiece, mixed
## colours) -- the same three states `_tap_rings()`'s harness engineers on
## the board itself. Every post is drawn its full height first, `Gen.CAP`
## slots tall, and the rings are stacked on top of it from the base up, so a
## part-sorted peg's post pokes out proud exactly the way the board's own
## `_build_station` leaves it: a glance at how much post shows above the
## rings says how much room is left. `RH`..`POST_UP` are this box's own
## scale-down of the board's RING_H..POST_UP (each ratio to RING_H copied
## across; POST_W and BASE_H happen to share the board's own 30, which is
## this file's coincidence to note and not to lean on), never the board's
## own constants directly -- a card this small does not want the board's
## touch targets, only its shape.
func _draw_rings_pegs(field: Control) -> void:
	const CAP := 4  # Rings_gen.gd's Gen.CAP, copied rather than read across
	                # scripts (rings2d.gd's own comment: a const from
	                # another script does not always fold in GDScript).
	const RH := 19.0
	const RW := 41.0
	const GAP := 1.25
	const BASE_H := 6.2
	const BASE_W := 37.6
	const POST_W := 6.2
	const POST_UP := 10.0
	var ground_y := 104.0
	var base_top := ground_y - BASE_H
	var stack_full := float(CAP) * RH + float(CAP - 1) * GAP
	var post_top := base_top - stack_full - POST_UP
	var post_col: Color = Pal.CHEEK.lerp(Pal.SURFACE, 0.62)
	var pegs := [
		{"cx": 50.0, "colours": [3, 3, 3, 3]},
		{"cx": 150.0, "colours": [0, 1]},
		{"cx": 250.0, "colours": [2, 5]},
	]
	var b := Face.Builder.new()
	var map := func(p: Vector2) -> Vector2: return p * _u
	for peg in pegs:
		var cx: float = peg["cx"]
		Rings2D._fan_mapped(b, Face.Builder.round_rect(Vector2(cx - POST_W * 0.5, post_top),
			Vector2(POST_W, base_top - post_top), POST_W * 0.5), post_col, map)
		Rings2D._slab_mapped(b, Vector2(cx - BASE_W * 0.5, base_top), Vector2(BASE_W, BASE_H),
			BASE_H * 0.5, 1.5, Pal.SURFACE_HI, Pal.LINE, map)
		var colours: Array = peg["colours"]
		for k in colours.size():
			var ci: int = colours[k]
			var cy := base_top - RH * 0.5 - float(k) * (RH + GAP)
			Rings2D._append_ring(b, cx, cy, RW, RH, Rings2D.RING_COLOURS[ci], ci + 1, 1.0, map)
	_rings_mesh = b.mesh()
	field.draw_mesh(_rings_mesh, null)
