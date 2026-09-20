extends Control

## One puzzle card's picture on the first screen: the same characters the
## board itself plays with (ui/faces/), seated in a 320 by 118 box and
## scaled to whatever the card gives them.
##
## It is never an image and never a render of a model. Ten of the twelve
## are made almost entirely of the flat boards' own cast -- Binairo's sun and
## moon, Code Break's friends, Balance's fruit, Untangle's lanterns,
## Shikaku's markers, Tents' tent and conifers, Light Up's lamp, One Line's
## snail, Queens' bee -- so a card and its board are visibly the same
## drawing. Only the furniture under them (a tray, a beam, a tile, a pipe) is
## drawn here, and only the one `soon` card (Pipes) is drawn here outright,
## because the board it names has no flat cast to borrow from yet.
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
const MushroomFace = preload("res://ui/faces/mushroom_face.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const MosaicTile = preload("res://ui/faces/mosaic_tile.gd")

## The box every picture is composed in. The card scales it to fit.
const ART := Vector2(320.0, 118.0)

var id := ""
## Design units per pixel, and the box's centre, both set by _relayout.
var _u := 1.0
var _c := Vector2.ZERO
## Hidden Word's band, held here rather than as a function local: a canvas
## command keeps a mesh by RID and not by reference, so a local ArrayMesh is
## freed before the frame it was queued in ever renders.
var _band_mesh: ArrayMesh

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
		"mushroom":
			# Two mushrooms on the turf strip _draw lays under them, the tile
			# and its numeral drawn beside them. `sprig` stays false: it marks
			# a mushroom a hint planted, which would be a lie on a card.
			_seat(MushroomFace.new(), 62.0, -104.0, 0.0)
			_seat(MushroomFace.new(), 48.0, -26.0, 10.0)
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
		"pipes": _draw_pipes()
		"hiddenword": _draw_letters()
		"mushroom": _draw_patch()

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
func _draw_patch() -> void:
	_round(-150.0, 20.0, 195.0, 50.0, 16.0, Pal.TURF_REACH)
	_round(70.0, -38.0, 76.0, 76.0, 14.0, Pal.SURFACE)
	_text("3", 108.0, 12.0, 42.0, Pal.LEAF_DEEP)

## Pipes is the one `soon` card left: no flat board, so no cast to borrow.
## It is one small drawing, sized to say what the puzzle is at a glance and
## no more. Horse Pen left `Registry.PUZZLES` for Hidden Word (`b2de66a`),
## and its own drawing (`_draw_paddock`) should have left with it -- the
## precedent is Snake Apple's `_draw_burrow`, deleted in the same commit
## that dropped its card (`b6723a9`) -- but it was left behind until now.
func _draw_pipes() -> void:
	_round(-92.0, -14.0, 72.0, 56.0, 10.0, Pal.WOOD)
	_round(22.0, -14.0, 72.0, 56.0, 10.0, Pal.WOOD)
	_line([Vector2(-56.0, 20.0), Vector2(-56.0, -34.0), Vector2(58.0, -34.0), Vector2(58.0, 20.0)], 26.0, Pal.WATER_HI)
	_line([Vector2(-56.0, 6.0), Vector2(-56.0, -28.0)], 8.0, Color(Pal.SURFACE, 0.5))
