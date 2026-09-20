extends "res://core/puzzle_base.gd"

## Word Trail as a flat board: a field of cream letter tiles with grey walls
## carved through it, a row of empty length boxes under it, and the scenery
## band at the card's foot. Drag from a tile to a side-adjacent tile and the
## trail bends around the walls; let go on one of today's words and it locks
## in its own colour, ribbon and all. The rules live in
## puzzles/word_trail_state.gd, which this only draws.
##
## **You are never told the words, only how long each one is.** The slots
## under the field are the whole clue: one group of boxes per word, shortest
## first, and nothing about a word's shape is ever shown. Every open tile
## belongs to exactly one word, so the grid is the scoreboard -- the last
## word locked fills the last tile.
##
## How it is drawn. One mesh and no Controls. The walls, the tile faces, the
## ribbons, the hint glows and the slot boxes all go into a single
## `ArrayMesh`, because none of them has a face on it and a Control per cell
## would be forty-nine nodes for a field of rounded squares; the letters are
## draw commands over the top (`Mosaic.letter`, which is `draw_set_transform`
## then `draw_string`), as Nonogram draws its clue numbers and Hidden Word
## its guesses. A glyph in a mesh cache key would multiply every state by
## twenty-six.
##
## **The order is the only one that works, because a tile is opaque**: the
## walls, then the tile faces, then the ribbons *over* them, then the hint
## glow and the letters. A ribbon drawn under a tile is a ribbon nobody sees,
## and it cost one wrong screenshot on the concept page.
##
## Spec: docs/superpowers/specs/2026-09-20-word-trail-flat-design.md,
## sections 6 and 7. Ported number for number from the canvas mock at
## docs/brainstorm/concepts.html#wordtrail, which is the reference for every
## measure here.

const State = preload("res://puzzles/word_trail_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")

# --- the screen, measured (spec section 6) ---
## The card's own inset and the gap between two tiles.
const INSET := 28.0
const GAP := 14.0
## The air between the field and the slots, and the band the slots take.
const SLOTS_PAD := 24.0
const SLOTS_H := 150.0
## One length box, the gap between two of them, the gap between two groups,
## and the gap between two wrapped lines.
const SLOT_W := 34.0
const SLOT_H := 52.0
const SLOT_GAP := 5.0
const GROUP_GAP := 22.0
const LINE_GAP := 14.0
## This board's own two, and the only two it needs. The wave's step per tile
## and how long a beam takes to grow or to unwind.
const WAVE_STEP := 0.05
const BEAM_TIME := 0.18
## How long the win waits after the last lock, so the wave that won it can
## finish first.
const WIN_WAIT := 1.4
## Three, as the mock's badge says (spec section 10).
const HINTS := 3

# --- the pieces, in cells or in the mock's own pixels ---
## A tile's and a wall's corner, and the bottom edge each wears -- the soft
## lip every card on these screens has. The edges are the mock's pixels
## rather than fractions of a cell: so are INSET, GAP and every slot measure
## above, and this board is drawn in the same 1080-wide design space.
const RADIUS := 0.22
const TILE_EDGE := 7.0
const WALL_EDGE := 6.0
const SLOT_RADIUS := 12.0
const SLOT_EDGE := 5.0
## How far a rim goes toward the ink: a wall's a fifth, a free tile's a
## sixth. A found tile's rim goes that far from its pale face toward its
## word's deep instead.
const WALL_RIM := 0.2
const TILE_RIM := 1.0 / 6.0
const FOUND_RIM := 0.45
const SLOT_RIM := 0.4
## The leaf on a wall: where on the cell it starts, how long, how it leans
## and how far its ink is let through.
const WALL_LEAF_AT := Vector2(0.32, 0.52)
const WALL_LEAF := 0.34
const WALL_LEAF_ANGLE := -0.5
const WALL_LEAF_INK := 0.14
## The ribbon over a locked word and the beam under the finger, in cells.
const RIBBON_W := 0.46
const RIBBON_ALPHA := 0.5
const BEAM_W := 0.44
const BEAM_ALPHA := 0.6
const GHOST_ALPHA := 0.55
## A letter on the field, in cells, and one in a slot box, in pixels.
const LETTER := 0.48
const SLOT_FONT := 29
## The hint's glow and the dashed outline over it: each inset from the cell's
## corner, its size taken off the cell, its corner, and the dash's on and off
## runs. All the mock's.
const GLOW_INSET := 7.0
const GLOW_TRIM := Vector2(14.0, 21.0)
const GLOW_RADIUS := 0.19
const GLOW_ALPHA := 0.45
const DASH_INSET := 9.0
const DASH_TRIM := Vector2(18.0, 25.0)
const DASH_RADIUS := 0.18
const DASH_W := 5.0
const DASH_ON := 0.1
const DASH_OFF := 0.08
## The hint's ring, in cells: it starts just outside the tile.
const RING_R := 0.62

## A locked word takes one of the palette's six chip colours, in order, and
## every part of it agrees: the ribbon in the strong one at RIBBON_ALPHA, the
## tile faces in the pale *_TILE, the letters in the deep one. Six is also
## the most words any band has, so nothing ever wraps round. No new colour is
## added to the palette for this board (spec section 7).
const WORD_COLS := [Pal.LEAF, Pal.SUN, Pal.MOON_INK, Pal.BERRY, Pal.ACORN, Pal.FLOWER]
const WORD_TILES := [Pal.LEAF_TILE, Pal.SUN_TILE, Pal.MOON_TILE, Pal.BERRY_TILE, Pal.ACORN_TILE, Pal.FLOWER_TILE]
const WORD_DEEPS := [Pal.LEAF_DEEP, Pal.SUN_DEEP, Pal.MOON_DEEP, Pal.BERRY_DEEP, Pal.ACORN_DEEP, Pal.FLOWER_DEEP]

const TIP_CYCLE := 8.0
const TIPS := [
	"Drag from letter to letter. Never diagonally.",
	"Every open tile belongs to one word.",
	"The lengths under the field are the only clue.",
	"A wrong trail costs nothing. Try another.",
]

var _state = State.new()
## The board's own effects node, as on every flat board: the hint's ring and
## sparkle come through it and nowhere else.
var fx: Node2D

## The cells the finger has strung together, in order. Empty when nothing is
## being dragged.
var _trail: Array[Vector2i] = []
## When the beam last reached a new tile. The beam's growth is the motion
## pass's (task 3); this is the moment it reads.
var _beam_at := -100.0
## The trail a release did not lock, unwinding: {"path": Array, "at": float}.
## Nothing else happens on a wrong trail -- no toast, no shiver, no move
## counted, no hint spent (spec section 3).
var _ghost: Dictionary = {}
## Each locked word's moment, by word index, and each lifted word's. The wave
## reads them; until the motion pass lands, a found word is simply whole.
var _found_at: Dictionary = {}
var _lifted_at: Dictionary = {}

var _opened := 0.0
var _anim_until := 0.0
var _solved_at := -1.0
## The field mesh, dropped whenever something changed so the next _draw
## rebuilds it.
var _field: ArrayMesh
## The mesh the last _draw actually handed to the canvas item. A canvas
## command holds a mesh by RID and not by reference, so dropping the only
## reference to a mesh still on the item's command list leaves the renderer
## drawing a freed RID ("Parameter mesh is null", and an empty card).
var _shown: ArrayMesh
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "wordtrail"
func title() -> String: return "Word Trail"

func rules() -> String:
	return "Drag from letter to letter -- up, down, left or right, never diagonally -- to trace a hidden word. A trail may bend as often as it likes, but it may not cross a grey wall or a word you have already found. You are never told the words, only how long each one is: the boxes under the field are the lengths, shortest first. Every open tile belongs to exactly one word, so when the last word is traced the field is full. A trail that is not one of today's words simply unwinds -- it costs you nothing."

## Undo and Hint, and nothing else. There is no Check because nothing wrong
## can be sitting on the board to check: only a right word locks, so the
## registry drops the actions row and Reset rides up into the top bar.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_state.build(rng, difficulty)
	_trail = []
	_beam_at = -100.0
	_ghost = {}
	_found_at = {}
	_lifted_at = {}
	_solved_at = -1.0
	_layout()
	_enter()
	_tip_idx = 0
	_say(TIPS[0], Face.Expr.HAPPY)
	_tip_timer.start()

# --- layout ---

## The largest cell the card holds. **The width binds at every band** -- 178,
## 146 and 123 at 1080 wide, against Queens' and Nonogram's 103 on their hard
## boards -- because the field is square while the slot is tall. What the
## field and the slots do not spend is the scenery band at the card's foot.
func _cell_for(available: float) -> float:
	if _state.n <= 0:
		return 0.0
	var span := float(_state.n - 1) * GAP
	var across := (size.x - 2.0 * INSET - span) / float(_state.n)
	var down := (available - 2.0 * INSET - SLOTS_H - SLOTS_PAD - span) / float(_state.n)
	return maxf(0.0, minf(across, down))

func _cell() -> float:
	return _cell_for(size.y)

## The field is n cells and the gaps between them, square.
func _field_size() -> float:
	return float(_state.n) * _cell() + float(_state.n - 1) * GAP

## The field's top-left inside this Control's rect: centred across the card,
## its top at the card's own inset.
func _origin() -> Vector2:
	return Vector2((size.x - _field_size()) * 0.5, INSET)

## The centre of the field: what the entrance pops about.
func _field_centre() -> Vector2:
	return _origin() + Vector2.ONE * (_field_size() * 0.5)

## The slots' band: SLOTS_PAD under the field, SLOTS_H tall.
func _slots_top() -> float:
	return _origin().y + _field_size() + SLOTS_PAD

## The top-left of cell (x across, y down).
func _corner(cell: Vector2i) -> Vector2:
	var step := _cell() + GAP
	return _origin() + Vector2(cell) * step

func _centre(cell: Vector2i) -> Vector2:
	return _corner(cell) + Vector2.ONE * (_cell() * 0.5)

## Control-local point over the centre of the cell at (row, column), the name
## every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(Vector2i(c, r))

## The cell under a local point, or (-1, -1). The gap between two tiles
## belongs to neither: a finger crossing it changes nothing until it is over
## the next tile, which is what keeps a fast drag from cutting a corner.
func _cell_at(local: Vector2) -> Vector2i:
	var cell := _cell()
	if cell <= 0.0:
		return Vector2i(-1, -1)
	var step := cell + GAP
	var p := (local - _origin()) / step
	var at := Vector2i(int(floor(p.x)), int(floor(p.y)))
	if at.x < 0 or at.y < 0 or at.x >= _state.n or at.y >= _state.n:
		return Vector2i(-1, -1)
	var corner := _corner(at)
	if local.x > corner.x + cell or local.y > corner.y + cell:
		return Vector2i(-1, -1)
	return at

## The card this board wants: every pixel it is given. The field takes what
## the width allows, the slots their fixed band, and the rest is the scenery
## band -- 222, 236 and 250 by band -- so there is never any slack.
func card_height(available: float) -> float:
	return available

## False, and honestly so: card_height() hands back everything, so the slack
## is zero and there is nothing to centre.
func card_centred() -> bool:
	return false

func _layout() -> void:
	_refresh()

## One group of boxes per word, shortest first, wrapped to as many lines as
## it takes -- one on easy, two on the others. Length is the whole clue.
## Returns [{"items": [{"i": int, "w": float}], "w": float}].
func _slot_lines() -> Array:
	var wide := size.x - 2.0 * INSET
	var lines: Array = []
	var cur: Array = []
	var cur_w := 0.0
	for i in _state.words.size():
		var span := float((_state.words[i]["path"] as Array).size())
		var group := span * SLOT_W + (span - 1.0) * SLOT_GAP
		var add := (GROUP_GAP if not cur.is_empty() else 0.0) + group
		if not cur.is_empty() and cur_w + add > wide:
			lines.append({"items": cur, "w": cur_w})
			cur = []
			cur_w = 0.0
			add = group
		cur_w += add
		cur.append({"i": i, "w": group})
	if not cur.is_empty():
		lines.append({"items": cur, "w": cur_w})
	return lines

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.words.is_empty():
		return
	# A ghost keeps its own frames coming until _build_field lets go of it:
	# a beam whose unwind ran a frame past _anim_until would otherwise stay
	# on the card for ever at an alpha nobody can see.
	if _now() < _anim_until or not _ghost.is_empty():
		_refresh()

## Keeps the field redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Drops the field mesh so the next _draw rebuilds it, and asks for that
## draw. The mesh the last _draw handed over is still held by _shown, so the
## renderer is never left pointing at a freed RID.
func _refresh() -> void:
	_field = null
	queue_redraw()

# --- the drawing ---

func _draw() -> void:
	if _state.words.is_empty() or _cell() <= 0.0:
		return
	var t := _now()
	if _field == null:
		_field = _build_field(t)
	if _field != null:
		draw_mesh(_field, null)
		_shown = _field
	_draw_letters(t)
	_draw_slot_letters(t)

## Everything with no glyph on it, in one mesh and in the one order that
## works: the walls, the tile faces, the ribbons over them, the hint glows
## over those, and the slot boxes.
func _build_field(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	for cell: Vector2i in _state.walls:
		_wall(b, cell)
	for cell: Vector2i in _state.letters:
		_tile(b, cell)
	_ribbons(b, t)
	for i in _state.words.size():
		_glow(b, i)
	_slot_boxes(b)
	return b.mesh() if not b.verts.is_empty() else null

## A rounded card: its face over a bottom edge in the rim colour, the soft
## lip every card on these screens wears. The canvas mock's `card()`.
func _slab(b, at: Vector2, box: Vector2, r: float, edge: float, face: Color, rim: Color) -> void:
	b.fan(Face.Builder.round_rect(at, box, r), rim)
	b.fan(Face.Builder.round_rect(at, Vector2(box.x, box.y - edge), r), face)

## A wall: the mock's grey slab in the family's warm grey, with a leaf
## pressed into it. The cool grey the mock draws goes muddy on cream, which
## is Hidden Word's finding.
func _wall(b, cell: Vector2i) -> void:
	var s := _cell()
	var at := _corner(cell)
	_slab(b, at, Vector2(s, s), s * RADIUS, WALL_EDGE,
		Pal.STONE_GIVEN, Pal.STONE_GIVEN.lerp(Pal.TEXT, WALL_RIM))
	_leaf(b, at + WALL_LEAF_AT * s, s * WALL_LEAF, WALL_LEAF_ANGLE,
		Color(Pal.TEXT, WALL_LEAF_INK))

## One open tile: plain SURFACE with a rim a sixth of the way to ink, or its
## word's pale face once that word is found.
func _tile(b, cell: Vector2i) -> void:
	var s := _cell()
	var face: Color = Pal.SURFACE
	var rim: Color = Pal.SURFACE.lerp(Pal.TEXT, TILE_RIM)
	var i := _lit_word(cell)
	if i >= 0:
		face = WORD_TILES[i % WORD_TILES.size()]
		rim = face.lerp(WORD_DEEPS[i % WORD_DEEPS.size()], FOUND_RIM)
	_slab(b, _corner(cell), Vector2(s, s), s * RADIUS, TILE_EDGE, face, rim)

## The word whose colour this cell is wearing, or -1. The wave the motion
## pass adds will narrow this to the tiles it has reached; a found word is
## whole until then.
func _lit_word(cell: Vector2i) -> int:
	var i := _state.word_at(cell)
	return i if i >= 0 and bool(_state.words[i]["found"]) else -1

## Every locked word's ribbon, then the beam under the finger and the one a
## release let go of. A ribbon is a rounded polyline through the path's cell
## centres: the corners are filleted into the centreline rather than joined,
## because a stroke's own join pinches at ninety degrees and two overlapping
## strokes at half alpha would darken where they cross.
func _ribbons(b, t: float) -> void:
	var s := _cell()
	for i in _state.words.size():
		if not bool(_state.words[i]["found"]):
			continue
		_ribbon(b, _state.words[i]["path"], s * RIBBON_W,
			Color(WORD_COLS[i % WORD_COLS.size()], RIBBON_ALPHA))
	if not _ghost.is_empty():
		var u := clampf((t - float(_ghost["at"])) / BEAM_TIME, 0.0, 1.0)
		if u >= 1.0 or Motion.reduce:
			_ghost = {}
		else:
			var path: Array = _ghost["path"]
			_ribbon(b, path, s * BEAM_W,
				Color(Pal.SUN_RAY, GHOST_ALPHA * (1.0 - u)),
				float(path.size() - 1) * (1.0 - u))
	if not _trail.is_empty():
		_ribbon(b, _trail, s * BEAM_W, Color(Pal.SUN_RAY, BEAM_ALPHA))

## One ribbon along `cells`, `reach` segments of it (all of them by default).
func _ribbon(b, cells: Array, width: float, colour: Color, reach := -1.0) -> void:
	if cells.is_empty() or width <= 0.0:
		return
	var pts := PackedVector2Array()
	for cell: Vector2i in cells:
		pts.append(_centre(cell))
	if reach >= 0.0:
		pts = _upto(pts, reach)
	if pts.size() < 2:
		if pts.size() == 1:
			b.disc(pts[0], width * 0.5, colour)
		return
	b.stroke(_filleted(pts, width * 0.5), width, colour)

## The first `reach` segments of `pts`, the last one cut part-way.
static func _upto(pts: PackedVector2Array, reach: float) -> PackedVector2Array:
	if pts.size() < 2:
		return pts
	var out := PackedVector2Array([pts[0]])
	var whole := clampi(int(floor(reach)), 0, pts.size() - 1)
	for i in range(1, whole + 1):
		out.append(pts[i])
	var frac := reach - float(whole)
	if frac > 0.0 and whole + 1 < pts.size():
		out.append(pts[whole].lerp(pts[whole + 1], frac))
	return out

## `pts` with every corner cut back by `r` and bridged with a quadratic, so a
## stroke along it turns rather than pinching. A straight run is left alone.
static func _filleted(pts: PackedVector2Array, r: float) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var here := pts[i]
		var back := (pts[i - 1] - here).normalized()
		var on := (pts[i + 1] - here).normalized()
		if back.dot(on) < -0.99:
			continue
		var cut := minf(r, minf(pts[i - 1].distance_to(here), pts[i + 1].distance_to(here)) * 0.5)
		var a := here + back * cut
		var c := here + on * cut
		out.append_array(Face.Builder.bezier2(a, here, c, 6))
		out.append(c)
	out.append(pts[pts.size() - 1])
	return out

## A leaf: the mock's two quadratics, turned by `angle` about its stem.
func _leaf(b, at: Vector2, length: float, angle: float, colour: Color) -> void:
	var tip := Vector2(length, 0.0)
	var pts := Face.Builder.bezier2(Vector2.ZERO, Vector2(length * 0.55, -length * 0.42), tip, 10)
	pts.append_array(Face.Builder.bezier2(tip, Vector2(length * 0.55, length * 0.42), Vector2.ZERO, 10))
	b.polygon(Transform2D(angle, at) * pts, colour)

## The glow a hint leaves on a tile: a pale wash under a dashed outline,
## which stays until that word is found. A hint is a given, and every board
## in this game says so in the same language.
func _glow(b, i: int) -> void:
	if bool(_state.words[i]["found"]):
		return
	var shown := _state.hint_shown(i)
	if shown <= 0:
		return
	var s := _cell()
	var path: Array = _state.words[i]["path"]
	for k in mini(shown, path.size()):
		var at := _corner(path[k])
		b.fan(Face.Builder.round_rect(at + Vector2.ONE * GLOW_INSET,
			Vector2(s, s) - GLOW_TRIM, s * GLOW_RADIUS), Color(Pal.SUN_RAY, GLOW_ALPHA))
		var ring := Face.Builder.round_rect(at + Vector2.ONE * DASH_INSET,
			Vector2(s, s) - DASH_TRIM, s * DASH_RADIUS)
		for dash in _dashes(ring, s * DASH_ON, s * DASH_OFF):
			b.stroke(dash, DASH_W, Pal.SUN_DEEP)

## The closed outline `pts` cut into dashes of `on` with `off` between them.
static func _dashes(pts: PackedVector2Array, on: float, off: float) -> Array:
	var out: Array = []
	if pts.size() < 2 or on <= 0.0 or off <= 0.0:
		return out
	var cur := PackedVector2Array([pts[0]])
	var lit := true
	var spent := 0.0
	for i in pts.size():
		var a := pts[i]
		var z := pts[(i + 1) % pts.size()]
		var span := a.distance_to(z)
		if span <= 0.001:
			continue
		var walked := 0.0
		while walked < span:
			# Never zero: a dash that ended exactly on a corner would other-
			# wise walk nowhere for ever.
			var want := maxf((on if lit else off) - spent, 0.001)
			if walked + want >= span:
				spent += span - walked
				walked = span
				if lit:
					cur.append(z)
			else:
				walked += want
				var p := a.lerp(z, walked / span)
				if lit:
					cur.append(p)
					if cur.size() >= 2:
						out.append(cur)
					cur = PackedVector2Array()
				else:
					cur = PackedVector2Array([p])
				lit = not lit
				spent = 0.0
	if lit and cur.size() >= 2:
		out.append(cur)
	return out

## The empty length boxes, and the ones a found word has filled. Each line is
## centred across the card and the block is centred in the slots' band.
func _slot_boxes(b) -> void:
	var lines := _slot_lines()
	if lines.is_empty():
		return
	var tall := float(lines.size()) * SLOT_H + float(lines.size() - 1) * LINE_GAP
	var y := _slots_top() + (SLOTS_H - tall) * 0.5
	for line in lines:
		var x := size.x * 0.5 - float(line["w"]) * 0.5
		for item in line["items"]:
			var i: int = item["i"]
			var lit := bool(_state.words[i]["found"])
			var face: Color = WORD_TILES[i % WORD_TILES.size()] if lit else Pal.SURFACE_HI
			var rim: Color = face.lerp(WORD_DEEPS[i % WORD_DEEPS.size()], SLOT_RIM) if lit else Pal.LINE
			var span: int = (_state.words[i]["path"] as Array).size()
			for k in span:
				_slab(b, Vector2(x + float(k) * (SLOT_W + SLOT_GAP), y),
					Vector2(SLOT_W, SLOT_H), SLOT_RADIUS, SLOT_EDGE, face, rim)
			x += float(item["w"]) + GROUP_GAP
		y += SLOT_H + LINE_GAP

## The field's letters, over the mesh: ink on a free tile, the word's deep
## once it is found. One draw command each, and only when something changed.
func _draw_letters(_t: float) -> void:
	var s := _cell()
	var font: Font = CozyTheme.display(700)
	# Mosaic.letter sizes a glyph at its own LETTER_SIZE of the box it is
	# handed; this board's letter is LETTER of the cell, so the box is scaled
	# rather than the constant copied.
	var box := s * LETTER / Mosaic.LETTER_SIZE
	for cell: Vector2i in _state.letters:
		var i := _lit_word(cell)
		var ink: Color = WORD_DEEPS[i % WORD_DEEPS.size()] if i >= 0 else Pal.TEXT
		Mosaic.letter(self, _centre(cell), box, String(_state.letters[cell]),
			Vector2.ONE, ink, font)

## A found word's letters, dropped into its slot group in its own deep.
func _draw_slot_letters(_t: float) -> void:
	var lines := _slot_lines()
	if lines.is_empty():
		return
	var font: Font = CozyTheme.display(700)
	var tall := float(lines.size()) * SLOT_H + float(lines.size() - 1) * LINE_GAP
	var y := _slots_top() + (SLOTS_H - tall) * 0.5
	for line in lines:
		var x := size.x * 0.5 - float(line["w"]) * 0.5
		for item in line["items"]:
			var i: int = item["i"]
			if bool(_state.words[i]["found"]):
				var word: String = _state.words[i]["word"]
				var ink: Color = WORD_DEEPS[i % WORD_DEEPS.size()]
				for k in word.length():
					_glyph(font, SLOT_FONT, word.substr(k, 1), ink,
						Vector2(x + float(k) * (SLOT_W + SLOT_GAP) + SLOT_W * 0.5,
							y + SLOT_H * 0.5))
			x += float(item["w"]) + GROUP_GAP
		y += SLOT_H + LINE_GAP

## One glyph centred on `at`, as Nonogram centres a clue number.
func _glyph(font: Font, px: int, text: String, ink: Color, at: Vector2) -> void:
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	var rise := font.get_height(px) * 0.5 - font.get_descent(px)
	draw_string(font, at + Vector2(-wide * 0.5, rise), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, ink)

# --- the moments ---

## The chrome is the host's; the field's own entrance is the motion pass's.
func _enter() -> void:
	_opened = _now()
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP)
	fx.cue("enter")

# --- input ---

## A press, a drag and a release, as every flat board takes them. A trail
## grows one side-adjacent tile at a time and never crosses a wall or a word
## already found; dragging back over the tile before the last one retracts
## the beam rather than doubling it.
func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed
		var cell := _cell_at(event.position)
		if pressed:
			if cell.x >= 0 and _state.can_trace(cell):
				_trail = [cell]
				_beam_at = _now()
				_refresh()
				accept_event()
		elif not _trail.is_empty():
			_release()
			accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and not _trail.is_empty():
		var cell := _cell_at(event.position)
		if cell.x < 0:
			return
		var at := _trail.find(cell)
		if at == _trail.size() - 2:
			_trail.resize(_trail.size() - 1)          # retracting takes the beam back
		elif at < 0 and _state.can_trace(cell) and _adjacent(_trail[_trail.size() - 1], cell):
			_trail.append(cell)
			_beam_at = _now()
		_refresh()
		accept_event()

## Side-adjacent, never diagonal. The bending is the whole puzzle, and a
## diagonal step would make a straight line of it.
static func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1

## Let go. A trail locks only if it is one of today's unfound words traced
## along that word's own cells, in order; **anything else simply unwinds** --
## no toast, no shiver, no move counted and no hint spent. The board never
## says no, because it never had to say yes (spec section 3).
func _release() -> void:
	var path := _trail
	_trail = []
	var t := _now()
	var i := _state.trace(path)
	if i < 0:
		if path.size() > 1 and not Motion.reduce:
			_ghost = {"path": path, "at": t}
			_busy_for(BEAM_TIME)
		_refresh()
		return
	_found_at[i] = t
	_lifted_at.erase(i)
	var last: Vector2i = (_state.words[i]["path"] as Array)[-1]
	var colour: Color = WORD_COLS[i % WORD_COLS.size()]
	fx.ring(_centre(last), _cell() * RING_R, colour)
	fx.sparkle(_centre(last), colour)
	fx.cue("place")
	_speak()
	_refresh()
	# note_move() counts the move and ends the puzzle if that was the last
	# word; the host raises the win screen after win_delay().
	note_move()

# --- the sprout's line ---

func _left_line() -> String:
	var left: int = _state.words.size() - _state.found_count()
	if left <= 0:
		return "That is the field filled."
	return "One word left." if left == 1 else "%d words left." % left

func _speak() -> void:
	if is_done():
		return
	_say(_left_line(), Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal.
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _tip_mood != Face.Expr.HAPPY or not _state.order.is_empty():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(TIPS[_tip_idx], Face.Expr.HAPPY)

## The sprout's own line, rather than Binairo's cycle of broken rules: there
## is no rule a tap can break on this board.
func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not _state.order.is_empty()

## Lifts the last word locked. Counts no move.
func undo() -> bool:
	if is_done() or _state.order.is_empty():
		return false
	var i: int = _state.order[-1]
	if not _state.undo():
		return false
	_lifted_at[i] = _now()
	_found_at.erase(i)
	_trail = []
	_say("Taken back. " + _left_line(), Face.Expr.HAPPY)
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## Lights the next tile of the shortest unfound word's path -- its first
## tile, then its second. That is the one hint this game can give: the words
## are hidden but the letters are not, so the only thing a player can be
## short of is where a word starts.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var pick := _hint_pick()
	if pick < 0:
		return false
	var shown := _state.hint_shown(pick)
	var cell := _state.hint_cell(pick)
	if not _state.hint():
		return false
	hints_used += 1
	if cell.x >= 0:
		fx.ring(_centre(cell), _cell() * RING_R, Pal.LEAF)
		fx.sparkle(_centre(cell), Pal.LEAF)
	fx.cue("hint")
	_say("A word starts on the glowing tile." if shown == 0
		else "It carries on through the glow.", Face.Expr.HAPPY)
	_refresh()
	moved.emit()
	return true

## Which word the next hint will light: the state's own choice, read ahead so
## the board knows which tile to ring. `hint()` picks the shortest unfound
## word that still has a tile left to give.
func _hint_pick() -> int:
	var pick := -1
	for i in _state.words.size():
		if bool(_state.words[i]["found"]):
			continue
		var span: int = (_state.words[i]["path"] as Array).size()
		if _state.hint_shown(i) >= span:
			continue
		if pick < 0 or span < (_state.words[pick]["path"] as Array).size():
			pick = i
	return pick

## Every locked word unwinds. What a hint gave stays given: the hints spent
## are not refunded, only unpinned.
func reset_board() -> void:
	var t := _now()
	for i in _state.order:
		_lifted_at[i] = t
	_state.reset_board()
	_found_at = {}
	_trail = []
	_ghost = {}
	_solved_at = -1.0
	moves = 0
	_running = true
	_say("A clean field. " + _left_line(), Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

func is_solved() -> bool:
	return _state.is_solved()

## One line per word in lock order, a tile glyph per letter, so a shared
## board shows the shape of the day and never its answers.
func share_glyphs() -> String:
	var out: Array[String] = []
	for i in _state.order:
		out.append("🟩".repeat((_state.words[i]["path"] as Array).size()))
	return "\n".join(out)

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": "Every letter found its way."}

func win_delay() -> float:
	return WIN_WAIT

func _on_solved() -> void:
	_trail = []
	_ghost = {}
	_solved_at = _now()
	_tip_timer.stop()
	_say("Every letter found its way.", Face.Expr.JOY)
	fx.cue("solved")
	_refresh()

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
