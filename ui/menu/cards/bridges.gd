extends "res://ui/menu/cards/card_face.gd"

## Bridges' card: the sea is the paper. A lagoon runs the whole card, deeper
## toward the foot, and four of the board's islets stand in it: three along
## the foot and one up the right side under the seal's corner. Two planks
## join the first pair, one climbs to the islet above, and the run between
## the second and third is not laid yet -- that span is the go button, one
## wide plank in the card's colour with a chevron, lifted over its shadow.
## Every number is counted in code from the runs drawn and the go span, and
## washed as the board washes a coin: the two end islets hold all they ask
## for and are green, the two the go span would join are still on paper with
## a socket empty. The name stands top left over open water in cream.
##
## The sea, the islets, the planks and the go span are one mesh; the four
## numerals are drawn over it, as the board writes them. Nothing lives on it.
## The islet and the plank are redrawn small from `bridges2d.gd`'s builders,
## which are instance methods tied to the board's lattice.

const Board = preload("res://puzzles/bridges2d.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## An islet's radius at H, and how much stouter than the board's a plank is
## laid, so two of them read as two at card size.
const ISLET := 30.0
const PLANK_K := 1.4
## The islets, as [how far in from the card's right side, how far down], at
## H, and the runs between them as [islet, islet, planks]. The last run is
## the go span.
const ISLETS := [Vector2(382.0, 188.0), Vector2(226.0, 188.0), Vector2(70.0, 188.0), Vector2(70.0, 104.0)]
const RUNS := [[0, 1, 2], [2, 3, 1]]
const GO := [1, 2, 1]
## The go span: how thick, how far it is lifted, and how far its ends tuck
## in over the two beaches.
const GO_THICK := 29.0
const GO_LIFT := 5.0
const GO_TUCK := 3.0
## The words' margin from the card's side and how far down they start.
const SIDE := 22.0
const WORDS_TOP := 14.0

## The lagoon, top to foot, the shallows round an islet, and the words' inks.
const SEA_TOP := Color("37889b")
const SEA_LOW := Color("246a86")
const SHALLOWS := Color("8fd6d0")
const SHALLOWS_ALPHA := 0.26
const INK := Color("fff8ea")
const BLURB := Color("d2e8e4")
## The wave marks, as [x in the card's width, y at H, length at H].
const WAVES := [
	[0.05, 158.0, 30.0],
	[0.19, 230.0, 24.0],
	[0.64, 42.0, 28.0],
	[0.63, 132.0, 22.0],
]
const WAVE_ALPHA := 0.24

## The numerals, [centre, text, ink], written over the mesh.
var _nums: Array = []

func _k() -> float:
	return size.y / H

func _r() -> float:
	return ISLET * _k()

## The board's cell an islet of this radius stands in.
func _cell() -> float:
	return _r() / Board.ISLET_R

## Islet `i`'s top centre.
func _at(i: int) -> Vector2:
	var p: Vector2 = ISLETS[i]
	return Vector2(size.x - p.x * _k(), p.y * _k())

## How many planks islet `i` asks for, and how many of them are laid.
static func _want(i: int) -> int:
	return _got(i) + (int(GO[2]) if GO[0] == i or GO[1] == i else 0)

static func _got(i: int) -> int:
	var total := 0
	for run in RUNS:
		if run[0] == i or run[1] == i:
			total += int(run[2])
	return total

## Where a run between islets `i` and `j` meets their beaches, as the board's
## `_lane_ends` reads it: a level run at the tops' own height, a climbing one
## from rim to rim, the islets being round from above.
func _ends(i: int, j: int) -> Dictionary:
	var a := _at(i)
	var c := _at(j)
	var r := _r()
	if is_equal_approx(a.y, c.y):
		var lo := minf(a.x, c.x) + r
		var hi := maxf(a.x, c.x) - r
		return {"horiz": true, "a": Vector2(lo, a.y), "b": Vector2(hi, a.y)}
	var top := minf(a.y, c.y) + r
	var bot := maxf(a.y, c.y) - r
	return {"horiz": false, "a": Vector2(a.x, top), "b": Vector2(a.x, bot)}

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var r := _r()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, SEA_TOP, SEA_LOW, 0.0, size.y)
	for wave in WAVES:
		_wave(b, Vector2(size.x * float(wave[0]), float(wave[1]) * k), float(wave[2]) * k, k)
	# The shallows round each islet, then the runs, then the islets over
	# their ends, the far one first.
	for i in ISLETS.size():
		Scenery.soft_disc(b, _at(i), r * 1.6, r * 1.6, Color(SHALLOWS, SHALLOWS_ALPHA))
	for run in RUNS:
		_run(b, _ends(run[0], run[1]), int(run[2]), run[0] * 7 + run[1])
	_nums.clear()
	var order := range(ISLETS.size())
	order.sort_custom(func(p: int, q: int) -> bool: return ISLETS[p].y < ISLETS[q].y)
	for i: int in order:
		_islet(b, i, _at(i), r)
	if not soon:
		_go(b, _ends(GO[0], GO[1]), k)

## A wave mark at `at`: a bowed stroke and a shorter one under it.
func _wave(b: Face.Builder, at: Vector2, length: float, k: float) -> void:
	var ink := Color(Pal.SURFACE, WAVE_ALPHA)
	b.stroke(PackedVector2Array([at, at + Vector2(length * 0.5, -3.5 * k), at + Vector2(length, 0.0)]), 3.0 * k, ink)
	var under := at + Vector2(length * 0.45, 9.0 * k)
	b.stroke(PackedVector2Array([under, under + Vector2(length * 0.3, -2.5 * k), under + Vector2(length * 0.6, 0.0)]),
		2.5 * k, Color(ink, WAVE_ALPHA * 0.7))

## A run of `count` planks between `g`'s ends, as
## Board._planks lays one at rest.
func _run(b: Face.Builder, g: Dictionary, count: int, seed_i: int) -> void:
	var s := _cell()
	var horiz: bool = g.horiz
	var thick := s * Board.PLANK * PLANK_K
	var air := s * Board.PLANK_GAP
	var total := float(count) * thick + float(count - 1) * air
	var a: Vector2 = g.a
	var e: Vector2 = g.b
	var span := (e.x - a.x) if horiz else (e.y - a.y)
	var shadow: Color = Pal.WATER.lerp(Pal.TEXT, Board.SEA_SHADE)
	var k := _k()
	for i in count:
		var off := float(i) * (thick + air) - (total - thick) * 0.5
		var at := Vector2(a.x, a.y + off - thick * 0.5) if horiz else Vector2(a.x + off - thick * 0.5, a.y)
		var box := Vector2(span, thick) if horiz else Vector2(thick, span)
		var round := thick * Board.PLANK_RADIUS
		b.fan(Face.Builder.round_rect(at + Vector2(2.0, 4.5) * k, box, round), Color(shadow, 0.3))
		var tone := (Board._hash(seed_i, i) - 0.5) * 2.0 * Board.PLANK_TONE
		var face: Color = Pal.DECK.lightened(tone) if tone > 0.0 else Pal.DECK.darkened(-tone)
		_plank(b, at, box, horiz, face, Pal.WOOD_DEEP, 2.0 * k, s * Board.SLAT_STEP)

## A plank, as Board._plank cuts one from above: `deep` showing as an even
## edge of half `lip` along both long sides, `face` between, lit along its
## top (its left on a climbing one), and slats across it every `step`, none
## within `clear` of its middle.
func _plank(b: Face.Builder, at: Vector2, box: Vector2, horiz: bool, face: Color, deep: Color, lip: float,
		step: float, clear := 0.0) -> void:
	var thick := minf(box.x, box.y)
	var round := thick * Board.PLANK_RADIUS
	b.fan(Face.Builder.round_rect(at, box, round), deep)
	var edge := Vector2(0.0, lip * 0.5) if horiz else Vector2(lip * 0.5, 0.0)
	var top := box - edge * 2.0
	b.fan(Face.Builder.round_rect(at + edge, top, round * 0.8), face)
	var bevel := maxf(1.5, thick * Board.PLANK_BEVEL)
	var strip := Vector2(top.x - round, bevel) if horiz else Vector2(bevel, top.y - round)
	var strip_at := at + edge + (Vector2(round * 0.5, 0.0) if horiz else Vector2(0.0, round * 0.5))
	b.fan(Face.Builder.round_rect(strip_at, strip, bevel * 0.5), face.lerp(Pal.SURFACE, Board.PLANK_LIT))
	var ink := Color(deep, Board.SLAT_ALPHA)
	var span := box.x if horiz else box.y
	var wide := maxf(1.5, thick * 0.16)
	var s := step * 0.6
	while s < span - step * 0.3:
		if absf(s - span * 0.5) >= clear:
			if horiz:
				b.stroke(PackedVector2Array([at + Vector2(s, bevel + 1.0), at + Vector2(s, top.y - 1.5)]), wide, ink)
			else:
				b.stroke(PackedVector2Array([at + Vector2(bevel + 1.0, s), at + Vector2(top.x - 1.5, s)]), wide, ink)
		s += step

## Islet `i` about `mid`, as Board._islet_body lays one from above: its
## shadow down and right on the water, the wet sand and the dry, the moss lit
## from the top left, the inlay washed for its count, and the ring of
## grooves on the sand round it.
func _islet(b: Face.Builder, i: int, mid: Vector2, r: float) -> void:
	var want := _want(i)
	var got := _got(i) if not soon else _want(i)
	Scenery.soft_disc(b, mid + Vector2(r, r) * Board.ISLET_SHADOW, r * 1.12, r * 1.12,
		Color(Pal.WATER.lerp(Pal.TEXT, Board.SEA_SHADE), Board.SHADOW_ALPHA))
	b.fan(_moss(mid, r, r, i + 3), Board.SAND_WET)
	b.fan(_moss(mid, r * Board.SAND_DRY, r * Board.SAND_DRY, i + 5), Board.SAND)
	var tone := (Board._hash(i, 3) - 0.5) * 2.0 * Board.TONE
	var turf: Color = Pal.BANK.lightened(tone) if tone > 0.0 else Pal.BANK.darkened(-tone)
	var tr := r * Board.TURF_R
	var shift := r * Board.TURF_SHIFT
	b.fan(_moss(mid, tr, tr, i), turf.lerp(Pal.TEXT, Board.TURF_DEEP))
	b.fan(_moss(mid - Vector2(shift, shift), tr - shift * 1.4, tr - shift * 1.4, i), turf)
	Scenery.soft_disc(b, mid - Vector2(r, r) * 0.3, r * 0.42, r * 0.42, Color(Pal.LEAF_LIGHT, Board.TURF_LIT))
	# The coin and the number on it.
	var met := got == want
	var coin: Color = Pal.LEAF_TILE.lerp(Pal.GOOD, Board.COIN_MET) if met else Pal.SURFACE
	var cr := r * Board.COIN_R
	var at := mid - Vector2(0.0, r * Board.COIN_LIFT)
	Scenery.soft_disc(b, at + Vector2(0.0, cr * 0.04), cr * 1.12, cr * 1.12, Color(Pal.TEXT, Board.COIN_SHADOW))
	b.ellipse(at, cr, cr, coin.lerp(Pal.TEXT, Board.COIN_EDGE))
	b.ellipse(at, cr * Board.COIN_FACE, cr * Board.COIN_FACE, coin)
	_nums.append([mid + Vector2(0.0, r * (Board.NUMBER_AT - Board.COIN_LIFT)), str(want),
		Pal.LEAF_DEEP if met else Pal.TEXT])
	# The sockets, one per plank asked for, filled as they come.
	var ring := cr * Board.SLOT_R
	var w := maxf(3.0, r * Board.SLOT_W)
	var step := TAU / float(want)
	var gap := minf(Board.SLOT_GAP, step * 0.4)
	for n in want:
		var a0 := -PI * 0.5 + step * float(n) + gap * 0.5
		var pts := Face.Builder.arc_points(at, ring, a0, a0 + step - gap)
		var ink: Color = (Pal.LEAF_DEEP if met else Pal.WOOD_DEEP) if n < got else Board.SAND.lerp(Pal.TEXT, 0.24)
		b.stroke(pts, w, ink)

## The moss's lumpy outline about `c`, as Board._moss wobbles it.
static func _moss(c: Vector2, rx: float, ry: float, seed_i: int) -> PackedVector2Array:
	var n := 40
	var ph := Board._hash(seed_i, 71) * TAU
	var pts := PackedVector2Array()
	pts.resize(n)
	for q in n:
		var a := TAU * float(q) / float(n)
		pts[q] = c + Vector2(cos(a) * rx, sin(a) * ry) * (1.0 + Board.MOSS_WOB * sin(5.0 * a + ph) + Board.MOSS_WOB * 0.5 * sin(3.0 * a + ph * 2.0))
	return pts

## The go button: the span `g` still wants, one wide plank in the card's
## colour over its shadow, a chevron at its middle.
func _go(b: Face.Builder, g: Dictionary, k: float) -> void:
	var thick := GO_THICK * k
	var a: Vector2 = g.a
	var e: Vector2 = g.b
	var at := Vector2(a.x - GO_TUCK * k, a.y - thick * 0.5)
	var box := Vector2(e.x - a.x + 2.0 * GO_TUCK * k, thick)
	Scenery.soft_disc(b, at + box * 0.5 + Vector2(0.0, thick * 0.62), box.x * 0.52, thick * 0.5, Color(Pal.TEXT, 0.3))
	at.y -= GO_LIFT * k
	_plank(b, at, box, true, colour, colour.darkened(0.3), 4.0 * k, _cell() * Board.SLAT_STEP, thick * 0.7)
	var mid := at + Vector2(box.x * 0.5 + thick * 0.03, (thick - 4.0 * k) * 0.5)
	var h := thick * 0.24
	b.stroke(PackedVector2Array([mid + Vector2(-h * 0.55, -h), mid + Vector2(h * 0.55, 0.0),
		mid + Vector2(-h * 0.55, h)]), thick * 0.15, Pal.SURFACE)

func _draw() -> void:
	super()
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(_r() * Board.NUMBER_SIZE))
	if px <= 0:
		return
	var rise := font.get_height(px) * 0.5 - font.get_descent(px)
	for n in _nums:
		var wide := font.get_string_size(n[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		draw_string(font, n[0] + Vector2(-wide * 0.5, rise), n[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, n[2])

func _lay() -> void:
	# The name and the blurb over open water, short of the seal.
	var room := size.x - SIDE - (SEAL_IN + SEAL_R + 10.0)
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, room, INK, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
