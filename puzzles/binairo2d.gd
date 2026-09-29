extends "res://core/puzzle_base.gd"

## Binairo as a flat board: a square of rounded tiles on the host's parchment
## card, each carrying an illustrated sun or moon with a face. Built beside
## the island version (puzzles/binairo3d.gd) so the two can be judged against
## each other on the phone; the rules live in puzzles/binairo_state.gd, which
## this only draws. A tap cycles empty, sun, moon; the host's palette arms a
## brush through set_brush() and cells then take that symbol. Every motion
## goes through core/motion.gd, so reduce-motion stills the decoration and
## keeps the change of symbol.
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, sections
## 4 to 6 and 9.2, as amended after the mock (docs/brainstorm/concepts.html#binairo).
##
## Signs (2026-09-23): a board carries "=" and "x" marks between some
## side-by-side tiles -- the two match, the two differ -- drawn as small
## paper badges over the gap, all of them one mesh on a layer above the
## tiles. A broken sign turns its glyph red and blushes the two tiles it
## joins. The card asks for the difficulty first, as Sudoku's does.
##
## Hearts and the fibbing sign (2026-09-29, spec
## docs/superpowers/specs/2026-09-29-binairo-insane-polish-design.md, section
## 1): Hard carries three hearts and Insane one, drawn as one mesh over the
## grid. A free tile set against the solution costs one -- it cracks, its face
## yelps, and it ejects itself a beat later through the state with no move
## and no history. The last heart gone puts the faces to sleep and raises
## ui/hud/out_of_hearts.gd. Insane is a banked 10x10 whose one sign lies; it
## looks like every other sign until the solve unmasks it.

const Gen = preload("res://puzzles/binairo_gen.gd")
const State = preload("res://puzzles/binairo_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
## Loaded when wanted, not preloaded: both reach the autoloads (Ads, Store),
## which a --check-only of this file cannot see.
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
const FLAT_HOST := "res://ui/flat/flat_host.gd"
const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")

## Layout, in the board card's inner pixels (spec section 4).
const PAD := 28.0
const GAP := 12.0
const TILE_RADIUS := 18
const TILE_EDGE := 4
## Face sizes as a fraction of the tile: the sun's rays reach 1.55 R, so its
## Control is 2 * 1.55 * 0.26 of the tile; the moon's disc is its own radius.
const SUN_SIZE := 0.26 * 2.0 * 1.55
const MOON_SIZE := 0.34 * 2.0
## Hint count, not refunded by reset (HUD spec, section 3).
const HINTS := 3
## Timings (spec section 6). The press, the pop in and out, the hop, the
## nudge, the drop, the ring, the entrance and the solve wave are the flat
## vocabulary's own numbers now (core/motion.gd, docs/art/flat-motion.md);
## only what is Binairo's alone stays here.
const FACE_IN_LAG := 0.08
const DIP := 4.0
const BLUSH_IN := 0.25
const BLUSH_OUT := 0.4
const BLUSH_BEAT := 0.2
const BLUSH_BEAT_EXTRA := 0.33
const LINE_HOP := -8.0
const LINE_HOP_TIME := 0.35
const LINE_STAGGER := 0.03
const JOY_TIME := 0.6
const CHECK_FLASH := 0.6
const FOCUS_IN := 0.12
const FOCUS_HOLD := 1.5
const FOCUS_OUT := 0.4
const FOCUS_ALPHA := 0.12
## About a third of the moons rock; which ones is fixed per cell.
const ROCK_SHARE := 0.34
## A sign's badge radius and its glyph's half-width and stroke, as fractions
## of the tile.
const SIGN_R := 0.14
const SIGN_GLYPH := 0.065
const SIGN_STROKE := 0.028
## How long the signs take to fade in once the tiles have landed.
const SIGN_IN := 0.3
## Per difficulty: the board's side, the clue floor the strip stops at (0
## strips to minimal) and how many signs are laid. Hard's floor of 12 is what
## keeps an 8x8 strip affordable: the last clues are the expensive ones.
const LEVELS := [
	{"size": 6, "min_clues": 12, "signs": 8},
	{"size": 6, "min_clues": 0, "signs": 6},
	{"size": 8, "min_clues": 12, "signs": 10},
	# Insane's provisional band is exactly Hard's row: the 10x10/min_clues 14
	# row and the 8x8/min_clues 0 fallback both blew the 194 ms gate (2381 ms
	# worst) -- every row tried past Hard's own measured 4x and up slower --
	# so there is nothing harder to give it live; the bank in its own batch
	# is what makes this band Insane.
	{"size": 8, "min_clues": 12, "signs": 10},
]
## Hearts per difficulty: none on Easy and Medium, three on Hard, one on Insane.
const HEART_COUNTS := [0, 0, 3, 1]
## The strip kept over the grid for the hearts on a board that has them, and
## a heart's half-width and the air between two.
const HEART_ROW := 64.0
const HEART_R := 19.0
const HEART_GAP := 14.0
## Tapping cycles empty, sun, moon: a sun set by a tap may be on its way to a
## moon, so it is judged only once it has stood this long. A brush's symbol,
## and a moon, are judged at once.
const WRONG_GRACE := 0.4
## The wrong tile: the face's jolt, the beat before it ejects, and the drop
## and fade it leaves by.
const JOLT := 0.2
const EJECT_AFTER := 0.35
const EJECT_TIME := 0.28
const EJECT_DROP := 26.0
## The lost heart's halves: how long they fall, how far, how far apart and
## how much they turn.
const SPLIT_TIME := 0.7
const SPLIT_FALL := 56.0
const SPLIT_SPREAD := 14.0
const SPLIT_TURN := 0.7
## A heart coming back pops in over this long.
const HEART_BACK_TIME := 0.3
## Out of hearts: the faces nod off along the diagonal this far apart, the
## tiles sag, and the card comes up once they have.
const SLEEP_STAGGER := 0.05
const SAG := 4.0
const SAG_TIME := 0.3
const CARD_AFTER := 1.1
const CARD_AFTER_STILL := 0.3
## The liar's unmasking at the solve: its badge swells and blushes, turns
## over like a coin to show a sheepish face, and turns back to its true glyph.
## Times are from the solve; the solve wave waits UNMASK_WAVE.
const UNMASK_SWELL := 2.7
const UNMASK_GROW := 0.25
const UNMASK_FLIP_1 := 0.3
const UNMASK_FLIP_2 := 1.35
const UNMASK_FLIP := 0.2
const UNMASK_SHRINK := 1.6
const UNMASK_TIME := 1.85
const UNMASK_WAVE := 1.6
const UNMASK_BLUSH := 0.65

## The armed brush: -2 none (taps cycle), -1 clear, 0 sun, 1 moon.
var brush: int = -2
signal brush_changed
## The out-of-hearts card's Back to camp: the board has already ended
## unsolved (finish_unsolved) and the host leaves (ui/puzzle_host.gd).
signal leave
## Hearts left and the board's full count (0 on Easy and Medium).
var hearts := 0
var max_hearts := 0
## Whether the board has run out: input stops until Try again or a heart.
var out_of_hearts := false
## The last tapped cell as (col, row); (-1, -1) before the first tap.
var focus_cell := Vector2i(-1, -1)

var state = State.new()
var n: int:
	get: return state.n
## The win harness and the animation probe read these off the island board;
## they are the state's arrays under the same names.
var _given: Array:
	get: return state.given
var _solution: Array:
	get: return state.solution

var fx: Node2D
## The signs' layer, over the tiles and under the fx; its one mesh is kept in
## `_signs_shown` until the next replaces it (a canvas command holds a mesh
## by RID).
var _sign_layer: Control
var _signs_shown: ArrayMesh
var _signs_tw: Tween
var _tiles: Array = []      # [r][c] -> Panel
var _styles: Array = []     # [r][c] -> its StyleBoxFlat
var _tints: Array = []      # [r][c] -> the focus tint Panel over the tile
var _faces: Array = []      # [r][c] -> Face or null
var _blend: Array = []      # [r][c] -> painted blend toward BAD_TILE
var _blend_target: Array = []
var _fades: Array = []
var _hops: Array = []
var _scales: Array = []     # [r][c] -> the press or release tween
var _joy_until: Array = []  # [r][c] -> msec until which the face beams
var _entrance: Array = []
var _focus_tw: Tween
var _touch := Vector2i(-1, -1)
var _tile := 0.0
var _origin := Vector2.ZERO
## The difficulty, kept so capabilities() answers for the board it built.
var _level := 1
## What the board was built from, for Try again.
var _data: Dictionary = {}
## Bumped on every build: a timer from an older board does nothing.
var _gen := 0
var _pending: Array = []    # [r][c] -> token: a newer change cancels a waiting judgement
var _ejecting: Array = []   # [r][c] -> the wrong tile waiting to eject
var _cracks: Array = []     # [r][c] -> its crack Control, or null
var _asleep := false
var _heart_used := false
var _heart_layer: Control
var _hearts_shown: ArrayMesh
var _split_index := -1
var _split_at := -INF
var _back_index := -1
var _back_at := -INF
## The liar's index while it is being (or has been) unmasked, and when.
var _unmask_i := -1
var _unmask_at := -INF
var _caught: Control
## The wave's lead after a solve (the unmasking's), for win_delay().
var _lead := 0.0
## Whether a liar hides on this unsolved board, read at every recolour.
var _liar_hidden := false

func puzzle_id() -> String: return "binairo"
func title() -> String: return "Binairo"

func rules() -> String:
	return tr("BN_RULES")

## Hard drops Check (a wrong tile says so itself); Insane drops Hint and
## Undo too. The host reads this after start(), so _level is the built one.
func capabilities() -> Array[String]:
	if _level >= 3:
		return []
	if _level == 2:
		return ["undo", "hint"]
	return ["undo", "hint", "check"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	_sign_layer = Control.new()
	_sign_layer.name = "Signs"
	_sign_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sign_layer.z_index = 1
	_sign_layer.draw.connect(_draw_signs)
	add_child(_sign_layer)
	_heart_layer = Control.new()
	_heart_layer.name = "Hearts"
	_heart_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heart_layer.z_index = 1
	_heart_layer.draw.connect(_draw_hearts)
	add_child(_heart_layer)
	fx = Fx2D.new()
	fx.name = "Fx"
	# Over the tiles, which are added after it: stars land on the board, not under it.
	fx.z_index = 1
	add_child(fx)
	resized.connect(_layout)
	solved.connect(_on_solved)

## Insane takes a banked 10x10 with a liar (core/insane_bank.gd, stepped by
## New); with no bank it falls back to Hard's live row, as Rings does.
func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_level = clampi(difficulty, 0, LEVELS.size() - 1)
	var level: Dictionary = LEVELS[_level]
	var data := {}
	if _level == 3:
		data = Gen.insane_board(rng, bank_step)
	if data.is_empty():
		data = Gen.generate(rng, level.size, level.min_clues, level.signs)
	_data = data
	max_hearts = HEART_COUNTS[_level]
	_setup_board()

## Deals `_data` onto a fresh board with every heart: the build, and Try again.
func _setup_board() -> void:
	_gen += 1
	hearts = max_hearts
	out_of_hearts = false
	_asleep = false
	_split_index = -1
	_back_index = -1
	_unmask_i = -1
	_lead = 0.0
	state.setup(_data)
	brush = -2
	focus_cell = Vector2i(-1, -1)
	_build_tiles()
	_layout()
	_recolour(false)
	_heart_layer.queue_redraw()
	_enter()

# --- the grid ---

func _build_tiles() -> void:
	_stop_all()
	for row in _tiles:
		for t in row:
			t.queue_free()
	_tiles = []
	_styles = []
	_tints = []
	_faces = []
	_blend = []
	_blend_target = []
	_fades = []
	_hops = []
	_scales = []
	_joy_until = []
	_pending = []
	_ejecting = []
	_cracks = []
	if is_instance_valid(_caught):
		_caught.queue_free()
	for r in n:
		var tiles := []
		var styles := []
		var tints := []
		var faces := []
		for c in n:
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(TILE_RADIUS)
			sb.border_width_bottom = TILE_EDGE
			var tile := Panel.new()
			tile.name = "tile_%d_%d" % [r, c]
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_theme_stylebox_override("panel", sb)
			add_child(tile)
			# CozyTheme.dress() hands every Panel the HUD's paper wash as it enters
			# the tree; on a tile that small the wash reads as a blotch, and a
			# board of them as a stain. The tiles stay flat.
			tile.material = null
			# The focus tint over the tile, the symbol's colour at a few percent,
			# shown for a moment on the tapped cell's row and column.
			var tint := Panel.new()
			tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tsb := StyleBoxFlat.new()
			tsb.set_corner_radius_all(TILE_RADIUS)
			tsb.bg_color = Pal.LINE
			tint.add_theme_stylebox_override("panel", tsb)
			tint.modulate.a = 0.0
			tile.add_child(tint)
			tint.material = null
			tiles.append(tile)
			styles.append(sb)
			tints.append(tint)
			faces.append(null)
		_tiles.append(tiles)
		_styles.append(styles)
		_tints.append(tints)
		_faces.append(faces)
		_blend.append(_zeros())
		_blend_target.append(_zeros())
		_fades.append(_nulls())
		_hops.append(_nulls())
		_scales.append(_nulls())
		_joy_until.append(_zeros())
		_pending.append(_zeros())
		_ejecting.append(_nulls())
		_cracks.append(_nulls())
	for r in n:
		for c in n:
			_paint(0.0, r, c)
			if state.grid[r][c] != -1:
				_faces[r][c] = _make_face(r, c, state.grid[r][c])

func _zeros() -> Array:
	var row := []
	for c in n:
		row.append(0.0)
	return row

func _nulls() -> Array:
	var row := []
	for c in n:
		row.append(null)
	return row

## The grid is the square of the shorter side less the padding, centred. A
## board with hearts keeps HEART_ROW over it for them first.
func _layout() -> void:
	if _tiles.is_empty():
		return
	var top := HEART_ROW if max_hearts > 0 else 0.0
	var g := minf(size.x, size.y - top) - 2.0 * PAD
	_tile = (g - (n - 1) * GAP) / n
	if _tile <= 0.0:
		return
	_origin = Vector2((size.x - g) * 0.5, top + (size.y - top - g) * 0.5)
	for layer: Control in [_sign_layer, _heart_layer]:
		layer.position = Vector2.ZERO
		layer.size = size
		layer.queue_redraw()
	for r in n:
		for c in n:
			var tile: Panel = _tiles[r][c]
			tile.position = _rest(r, c) + (Vector2(0.0, SAG) if _asleep else Vector2.ZERO)
			tile.size = Vector2(_tile, _tile)
			tile.pivot_offset = tile.size * 0.5
			var tint: Panel = _tints[r][c]
			tint.position = Vector2.ZERO
			tint.size = Vector2(_tile, _tile - TILE_EDGE)
			var face: Control = _faces[r][c]
			if face != null:
				_fit_face(face, state.grid[r][c])

## Where tile (r, c) stands at rest.
func _rest(r: int, c: int) -> Vector2:
	return _origin + Vector2(c, r) * (_tile + GAP)

## Sizes a face for the current tile and centres it, a touch high so the
## tile's bottom edge does not crowd it.
func _fit_face(face: Control, v: int) -> void:
	var s := _tile * (SUN_SIZE if v == 0 else MOON_SIZE)
	face.size = Vector2(s, s)
	face.pivot_offset = face.size * 0.5
	face.position = (Vector2(_tile, _tile - TILE_EDGE) - face.size) * 0.5

## A new face for cell (r, c) showing `v`, parented to its tile, idling.
func _make_face(r: int, c: int, v: int) -> Control:
	var face: Control
	if v == 0:
		face = SunFace.new()
	else:
		face = MoonFace.new()
		face.rocks = _hash(r, c) < ROCK_SHARE
	face.name = "face"
	_tiles[r][c].add_child(face)
	if _tile > 0.0:
		_fit_face(face, v)
	face.expression = _expression(r, c)
	face.set_idle(true)
	return face

## A fixed pseudo-random number per cell, for which moons rock.
static func _hash(r: int, c: int) -> float:
	return float(posmod(hash(Vector2i(r, c)), 1000)) / 1000.0

## Control-local point over the centre of cell (r, c). The win harness taps
## this; it is the flat counterpart of the island board's.
func cell_to_local(r: int, c: int) -> Vector2:
	return _origin + Vector2(c, r) * (_tile + GAP) + Vector2(_tile, _tile) * 0.5

## The cell under a control-local point, as (col, row), or (-1, -1) between
## tiles and off the grid.
func _cell_at(local: Vector2) -> Vector2i:
	if _tile <= 0.0:
		return Vector2i(-1, -1)
	var p := local - _origin
	var step := _tile + GAP
	var c := int(floor(p.x / step))
	var r := int(floor(p.y / step))
	if c < 0 or r < 0 or c >= n or r >= n:
		return Vector2i(-1, -1)
	# The gap belongs to the nearer tile: a thumb is never that precise.
	return Vector2i(c, r)

# --- signs ---

## Where sign `s` sits: the middle of the gap between its two tiles.
func _sign_at(s: Vector4i) -> Vector2:
	var a := cell_to_local(s.x, s.y)
	var o := Gen.sign_other(s)
	return (a + cell_to_local(o.x, o.y)) * 0.5

## Every sign as one mesh: a paper badge with a line round it and the glyph
## in acorn ink, or in BAD while the sign is broken. On Insane the liar is
## drawn exactly like the rest until the solve unmasks it (_draw_liar).
func _draw_signs() -> void:
	if state.signs.is_empty() or _tile <= 0.0:
		return
	var b := Face.Builder.new()
	var r := _tile * SIGN_R
	var w := _tile * SIGN_GLYPH
	var line := maxf(2.0, _tile * SIGN_STROKE)
	for i in state.signs.size():
		if i == _unmask_i:
			continue
		var s: Vector4i = state.signs[i]
		var at := _sign_at(s)
		var ink: Color = Pal.BAD if state.sign_broken(i) else Pal.ACORN_DEEP
		b.disc(at, r + 2.0, Pal.LINE)
		b.disc(at, r, Pal.SURFACE)
		_glyph(b, at, w, line, s.w, ink)
	if _unmask_i >= 0:
		_draw_liar(b, r, w, line)
	_signs_shown = b.mesh()
	_sign_layer.draw_mesh(_signs_shown, null)

## A sign's glyph at `at`: "=" for kind 1, "x" for 0, squeezed across by `sx`
## (the unmasking's coin turn).
static func _glyph(b, at: Vector2, w: float, line: float, kind: int, ink: Color, sx := 1.0) -> void:
	if kind == 1:
		for dy in [-0.45, 0.45]:
			b.stroke(PackedVector2Array([at + Vector2(-w * sx, dy * w), at + Vector2(w * sx, dy * w)]), line, ink)
	else:
		var k := w * 0.8
		b.stroke(PackedVector2Array([at + Vector2(-k * sx, -k), at + Vector2(k * sx, k)]), line, ink)
		b.stroke(PackedVector2Array([at + Vector2(-k * sx, k), at + Vector2(k * sx, -k)]), line, ink)

## The liar, caught: off the clock since the solve, its badge swells and
## blushes, turns over like a coin onto a sheepish face, holds while the
## bubble says so, and turns back onto its true glyph as it shrinks home. It
## keeps the blush after. Under reduce-motion there is no swell and no turn:
## the face shows for the hold, then the true glyph.
func _draw_liar(b, r: float, w: float, line: float) -> void:
	var u := _now() - _unmask_at
	var shown: Vector4i = state.signs[_unmask_i]
	var truth: Vector4i = state.true_signs()[_unmask_i]
	var at := _sign_at(shown)
	var grow := 1.0
	var sx := 1.0
	var face := u >= UNMASK_FLIP_1 + UNMASK_FLIP * 0.5 and u < UNMASK_FLIP_2 + UNMASK_FLIP * 0.5
	if not Motion.reduce:
		if u < UNMASK_SHRINK:
			grow = 1.0 + (UNMASK_SWELL - 1.0) * Motion.back_out(clampf(u / UNMASK_GROW, 0.0, 1.0))
		else:
			var k := clampf((u - UNMASK_SHRINK) / UNMASK_GROW, 0.0, 1.0)
			grow = lerpf(UNMASK_SWELL, 1.0, k * k * (3.0 - 2.0 * k))
		for flip in [UNMASK_FLIP_1, UNMASK_FLIP_2]:
			if u >= flip and u < flip + UNMASK_FLIP:
				sx = absf(cos(PI * (u - flip) / UNMASK_FLIP))
	var blush := clampf(u / UNMASK_GROW, 0.0, 1.0) * UNMASK_BLUSH
	var rr := r * grow
	var fill: Color = Pal.SURFACE.lerp(Pal.CHEEK, blush)
	b.ellipse(at, (rr + 2.0) * sx, rr + 2.0, Pal.LINE)
	b.ellipse(at, rr * sx, rr, fill)
	if face:
		# The face's own parts at the badge's size, squeezed with it.
		var fb := Face.Builder.new()
		Face.face_parts(fb, rr * 0.95, at, Pal.OUTLINE, Face.SLEEPY_EYE + 0.1, Face.Expr.HAPPY)
		for i in fb.verts.size():
			fb.verts[i] = at + (fb.verts[i] - at) * Vector2(sx, 1.0)
		var base: int = b.verts.size()
		b.verts.append_array(fb.verts)
		b.cols.append_array(fb.cols)
		for k in fb.idx:
			b.idx.append(base + k)
	else:
		var kind: int = truth.w if u >= UNMASK_FLIP_2 else shown.w
		_glyph(b, at, w * grow, line * grow, kind, Pal.ACORN_DEEP, sx)

# --- colour ---

## The tile's fill at a blend toward BAD_TILE: white for a free cell (the
## user dropped the mock's checker, 2026-09-18), sand for a given, and past 1
## the heartbeat pushes on toward BAD.
func _paint(blend: float, r: int, c: int) -> void:
	_blend[r][c] = blend
	var locked: bool = state.given[r][c]
	var base: Color = Pal.STONE_GIVEN if locked else Pal.SURFACE
	var fill: Color
	if blend <= 1.0:
		fill = base.lerp(Pal.BAD_TILE, blend)
	else:
		fill = Pal.BAD_TILE.lerp(Pal.BAD, minf(1.0, (blend - 1.0) * 0.5))
	var sb: StyleBoxFlat = _styles[r][c]
	sb.bg_color = fill
	sb.border_color = Pal.LINE if locked else Color(Pal.LINE, 0.5)

## Rule feedback. Cells whose line just broke blush with two heartbeats and
## shiver once, and their faces worry; cells whose line was fixed fade back.
## A cell already heading for the right blend is left alone.
func _recolour(animate := true) -> void:
	state.refresh_bad()
	_liar_hidden = state.liar >= 0 and not state.is_solved()
	_sign_layer.queue_redraw()
	for r in n:
		for c in n:
			var target := 1.0 if _bad(r, c) else 0.0
			var face: Control = _faces[r][c]
			if face != null:
				face.expression = _expression(r, c)
			if is_equal_approx(_blend_target[r][c], target):
				continue
			_blend_target[r][c] = target
			Motion.stop(_fades[r][c])
			if not animate:
				_paint(target, r, c)
				_fades[r][c] = null
				continue
			var setter := _paint.bind(r, c)
			if target > _blend[r][c]:
				var tw: Tween = Motion.fade(self, setter, _blend[r][c], target, BLUSH_IN, 16)
				if tw != null:
					for i in 2:
						tw.tween_method(setter, target, target + BLUSH_BEAT_EXTRA, BLUSH_BEAT * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
						tw.tween_method(setter, target + BLUSH_BEAT_EXTRA, target, BLUSH_BEAT * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				_fades[r][c] = tw
				Motion.shiver(_tiles[r][c])
				fx.cue("blush_in")
			else:
				_fades[r][c] = Motion.fade(self, setter, _blend[r][c], target, BLUSH_OUT, 16)
				fx.cue("blush_out")

## Whether (r, c) blushes. While a liar hides, the ends of a broken sign do
## not: the state reads the liar as its true kind, so a pair of tiles
## blushing where the shown sign is kept would name it. Rows and columns
## still blush.
func _bad(r: int, c: int) -> bool:
	if _liar_hidden:
		return state.bad.rows.has(r) or state.bad.cols.has(c)
	return state.is_bad(r, c)


## What a face should show: asleep when the hearts are gone, a yelp on a
## wrong tile, joy while its celebration lasts, worry on a broken line,
## otherwise content.
func _expression(r: int, c: int) -> int:
	if _asleep:
		return Face.Expr.SLEEPY
	if _ejecting[r][c] != null:
		return Face.Expr.WORRIED
	if Time.get_ticks_msec() < _joy_until[r][c]:
		return Face.Expr.JOY
	if _bad(r, c):
		return Face.Expr.WORRIED
	return Face.Expr.HAPPY

## The faces of a completed clean line hop in a wave from the tapped cell and
## beam for a moment.
func _celebrate(cells: Array, r: int, c: int) -> void:
	if cells.is_empty():
		return
	for cell in cells:
		var rr: int = cell.y
		var cc: int = cell.x
		var delay := 0.1 + Motion.stagger(absi(rr - r) + absi(cc - c), LINE_STAGGER)
		_hop(rr, cc, LINE_HOP, LINE_HOP_TIME, delay)
		_beam(rr, cc, delay, JOY_TIME)
	fx.cue("line")

## Sets the face at (r, c) to JOY after `delay` for `time` seconds (INF to
## keep it), then back to what the state says.
func _beam(r: int, c: int, delay: float, time: float) -> void:
	var until := INF if is_inf(time) else float(Time.get_ticks_msec()) + (delay + time) * 1000.0
	_joy_until[r][c] = until
	var show := func() -> void:
		var face: Control = _faces[r][c]
		if face != null:
			face.expression = _expression(r, c)
	if delay <= 0.0:
		show.call()
	else:
		get_tree().create_timer(delay).timeout.connect(show)
	if not is_inf(time):
		get_tree().create_timer(delay + time).timeout.connect(show)

# --- faces coming and going ---

## The face at (r, c) leaves (shrinks with a quarter turn) and the face for
## `v` arrives (pops with squash and stretch), or drops from above when
## `drop` is set (a hint). Under reduce-motion both happen at once.
func _swap_face(r: int, c: int, v: int, delay := 0.0, drop := false) -> void:
	var old: Control = _faces[r][c]
	_faces[r][c] = null
	if old != null:
		old.set_idle(false)
		var out: Tween = Motion.pop_out(old, Motion.POP_OUT, delay)
		if out == null:
			old.queue_free()
		else:
			out.finished.connect(old.queue_free)
	if v == -1:
		return
	var face := _make_face(r, c, v)
	_faces[r][c] = face
	var start := delay + FACE_IN_LAG
	if drop:
		Motion.drop_in(face, Motion.DROP, Motion.DROP_TIME, start)
	else:
		Motion.pop_in(face, Motion.POP_IN, start)

## A hop (negative height lifts) on the tile, replacing any hop already on it.
func _hop(r: int, c: int, height: float, time: float, delay := 0.0) -> void:
	Motion.stop(_hops[r][c])
	var tile: Panel = _tiles[r][c]
	var rest := (_origin + Vector2(c, r) * (_tile + GAP)).y
	tile.position.y = rest
	_hops[r][c] = Motion.hop(tile, height, time, delay, rest)

## The four side neighbours nudge away from a tapped cell and come back.
func _nudge_neighbours(r: int, c: int) -> void:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var rr: int = r + d.y
		var cc: int = c + d.x
		if rr < 0 or cc < 0 or rr >= n or cc >= n:
			continue
		if Motion.reduce or Motion.running(_hops[rr][cc]):
			continue
		_hops[rr][cc] = Motion.nudge(_tiles[rr][cc], Vector2(d), _origin + Vector2(cc, rr) * (_tile + GAP))

## The press: the tile sinks under the finger and springs back on release.
func _press(r: int, c: int, down: bool) -> void:
	Motion.stop(_scales[r][c])
	_scales[r][c] = Motion.press(_tiles[r][c], down)

# --- focus ---

## The tapped cell's row and column take a tint of its symbol's colour for a
## moment, so the eye finds the lines a tap changed. Replaces the working-line
## card; line_state() still answers for anything that reads it.
func _focus(r: int, c: int) -> void:
	Motion.stop(_focus_tw)
	_set_focus_alpha(0.0)
	focus_cell = Vector2i(c, r)
	var v: int = state.grid[r][c]
	var colour: Color = Pal.SUN if v == 0 else (Pal.MOON_INK if v == 1 else Pal.LINE)
	for i in n:
		(_tints[r][i].get_theme_stylebox("panel") as StyleBoxFlat).bg_color = colour
		(_tints[i][c].get_theme_stylebox("panel") as StyleBoxFlat).bg_color = colour
	fx.cue("focus")
	focus_changed.emit()
	if Motion.reduce:
		return
	_focus_tw = create_tween()
	_focus_tw.tween_method(_set_focus_alpha, 0.0, FOCUS_ALPHA, FOCUS_IN)
	_focus_tw.tween_interval(FOCUS_HOLD)
	_focus_tw.tween_method(_set_focus_alpha, FOCUS_ALPHA, 0.0, FOCUS_OUT)

func _set_focus_alpha(a: float) -> void:
	if focus_cell.x < 0:
		return
	for i in n:
		_tints[focus_cell.y][i].modulate.a = a
		_tints[i][focus_cell.x].modulate.a = a

func _focus_clear() -> void:
	Motion.stop(_focus_tw)
	_set_focus_alpha(0.0)
	focus_cell = Vector2i(-1, -1)
	focus_changed.emit()

func line_state() -> Dictionary:
	return state.line_state(focus_cell)

## Which rule a line on the board breaks right now (0 none, 1 three alike, 2
## an uneven count, 3 two lines alike); the tip card names it.
func broken_rule() -> int:
	var rule := state.broken_rule()
	# A broken sign is the liar's tell while it hides (see _bad).
	return 0 if rule == 4 and _liar_hidden else rule

# --- input ---

## Touch events only, as StageView takes them: the viewport hands a control
## both the mouse event and the emulated touch, and two would fire twice.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		var cell := _cell_at(event.position)
		if event.pressed:
			if is_done() or out_of_hearts or cell.x < 0 or _ejecting[cell.y][cell.x] != null:
				return
			_touch = cell
			_press(cell.y, cell.x, true)
		elif _touch.x >= 0:
			var was := _touch
			_touch = Vector2i(-1, -1)
			_press(was.y, was.x, false)
			if cell == was and not is_done() and not out_of_hearts and _ejecting[was.y][was.x] == null:
				_tap(was.y, was.x)

## A tap on (r, c): cycles, or paints the armed brush. A given only dips.
func _tap(r: int, c: int) -> void:
	if out_of_hearts or _ejecting[r][c] != null:
		return
	if state.given[r][c]:
		_hop(r, c, DIP, Motion.HOP_TIME)
		_focus(r, c)
		return
	var changed: bool
	if brush == -2:
		changed = state.cycle(r, c)
	else:
		changed = state.place(r, c, brush)
	if not changed:
		return
	var v: int = state.grid[r][c]
	_swap_face(r, c, v)
	_hop(r, c, Motion.HOP, Motion.HOP_TIME)
	_nudge_neighbours(r, c)
	if v != -1:
		fx.puff(cell_to_local(r, c), Pal.SUN if v == 0 else Pal.MOON_INK, 5)
	fx.cue("place" if v != -1 else "clear")
	_focus(r, c)
	_after_change(r, c)
	note_move()
	_judge(r, c, v == 0 and brush == -2)

# --- hearts ---

## After a change at (r, c) on a board with hearts: a wrong symbol costs one,
## at once, or after WRONG_GRACE for a sun a tap may be cycling past on its
## way to a moon. Any later change to the cell cancels a waiting judgement.
func _judge(r: int, c: int, grace: bool) -> void:
	if max_hearts <= 0:
		return
	_pending[r][c] += 1
	if is_done() or not state.is_wrong(r, c):
		return
	if not grace:
		_wrong(r, c)
		return
	var token: float = _pending[r][c]
	_later(WRONG_GRACE, func() -> void:
		if _pending[r][c] == token and not is_done() and state.is_wrong(r, c):
			_wrong(r, c))

## `f` after `t` seconds, unless the board has been rebuilt or freed since.
func _later(t: float, f: Callable) -> void:
	var gen := _gen
	get_tree().create_timer(t).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_inside_tree() and gen == _gen:
			f.call())

## A wrong tile: a heart goes (its halves fall), the tile cracks and
## shivers, its face yelps, and after EJECT_AFTER it empties itself.
func _wrong(r: int, c: int) -> void:
	if out_of_hearts or hearts <= 0 or _ejecting[r][c] != null:
		return
	_ejecting[r][c] = true
	hearts -= 1
	_split_index = hearts
	_split_at = _now()
	_heart_layer.queue_redraw()
	if hearts <= 0:
		# Input stops now; the sleep waits for the eject.
		out_of_hearts = true
		_running = false
	_crack(r, c)
	Motion.shiver(_tiles[r][c])
	var face: Control = _faces[r][c]
	if face != null:
		face.expression = Face.Expr.WORRIED
		Motion.squash(face, JOLT, 0.18)
	fx.cue("heart_lost")
	moved.emit()
	_later(EJECT_AFTER, _eject.bind(r, c))

## A crack drawn over tile (r, c): a jagged line of ink, its own path per cell.
func _crack(r: int, c: int) -> void:
	var tile: Panel = _tiles[r][c]
	var crack := Control.new()
	crack.name = "crack"
	crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var seed_a := _hash(r, c)
	var seed_b := _hash(c + 7, r + 3)
	crack.draw.connect(func() -> void:
		var w := crack.size.x
		var h := crack.size.y - TILE_EDGE
		var pts := PackedVector2Array([
			Vector2(w * (0.3 + 0.2 * seed_a), h * 0.08),
			Vector2(w * (0.52 + 0.1 * seed_b), h * 0.3),
			Vector2(w * (0.4 + 0.08 * seed_a), h * 0.5),
			Vector2(w * (0.6 + 0.1 * seed_b), h * 0.7),
			Vector2(w * (0.48 + 0.1 * seed_a), h * 0.92),
		])
		crack.draw_polyline(pts, Color(Pal.OUTLINE, 0.55), maxf(2.0, w * 0.035), true))
	tile.add_child(crack)
	_cracks[r][c] = crack

## The wrong tile leaves: the face drops and fades, the crack with it, and
## the state empties the cell with no move and no history. A tile a hint or
## an undo already put right only loses its crack.
func _eject(r: int, c: int) -> void:
	_ejecting[r][c] = null
	var crack: Control = _cracks[r][c]
	_cracks[r][c] = null
	if state.is_wrong(r, c):
		state.clear_silent(r, c)
		var face: Control = _faces[r][c]
		_faces[r][c] = null
		_drop_out(face)
		_recolour()
		focus_changed.emit()
	_drop_out(crack)
	var still: Control = _faces[r][c]
	if still != null:
		still.expression = _expression(r, c)
	moved.emit()
	if out_of_hearts:
		_run_out()

## Drops `node` EJECT_DROP while it fades, then frees it.
func _drop_out(node: Control) -> void:
	if node == null:
		return
	if node.has_method("set_idle"):
		node.set_idle(false)
	if Motion.reduce:
		node.queue_free()
		return
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "position:y", node.position.y + EJECT_DROP, EJECT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "modulate:a", 0.0, EJECT_TIME)
	tw.chain().tween_callback(node.queue_free)

## The last heart is gone: the faces nod off along the diagonal, the tiles
## sag, and the card comes up once they have.
func _run_out() -> void:
	_asleep = true
	_focus_clear()
	fx.cue("out_of_hearts")
	for r in n:
		for c in n:
			var delay := Motion.stagger(r + c, SLEEP_STAGGER)
			_later(delay, _nod.bind(r, c))
			Motion.stop(_hops[r][c])
			var rest := _rest(r, c)
			_tiles[r][c].position = rest
			_hops[r][c] = Motion.slide(_tiles[r][c], "position:y", rest.y, rest.y + SAG, SAG_TIME, delay, false)
	_later(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

func _nod(r: int, c: int) -> void:
	var face: Control = _faces[r][c]
	if face != null:
		face.expression = _expression(r, c)

## The card, over the whole screen: laid on the host so it covers the chrome,
## or on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not out_of_hearts or is_done():
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used)
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same board from the top, every heart back, the clock, the
## moves and the hints from zero (the extra hints a video paid for stay).
func try_again() -> void:
	if is_done():
		return
	_close_card()
	moves = 0
	elapsed = 0.0
	hints_used = 0
	checks = 0
	_running = true
	_setup_board()
	brush_changed.emit()
	moved.emit()
	fx.cue("reset")

## One more heart (the card's video, or the purchase's): once a board. The
## faces wake along the diagonal and the tiles stand up again.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_heart_used = true
	hearts = 1
	_back_index = 0
	_back_at = _now()
	_heart_layer.queue_redraw()
	out_of_hearts = false
	_asleep = false
	_running = true
	fx.cue("heart_back")
	for r in n:
		for c in n:
			var delay := Motion.stagger(r + c, SLEEP_STAGGER)
			_later(delay, _nod.bind(r, c))
			Motion.stop(_hops[r][c])
			var rest := _rest(r, c)
			_hops[r][c] = Motion.slide(_tiles[r][c], "position:y", rest.y + SAG, rest.y, SAG_TIME, delay)
	moved.emit()

## Back to camp from the card: the board ends unsolved first, so the host logs
## puzzle_complete {solved: false} and not an abandon.
func _leave() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	for root_child in [get_tree().get_first_node_in_group("puzzle_host"), get_tree().root]:
		if root_child != null:
			var card: Node = root_child.get_node_or_null("OutOfHearts")
			if card != null and not card.is_queued_for_deletion():
				card.queue_free()

## Seconds on a steady clock, for the drawn animations.
static func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _process(delta: float) -> void:
	super(delta)
	var now := _now()
	if (_split_index >= 0 and now - _split_at < SPLIT_TIME + 0.1) \
			or (_back_index >= 0 and now - _back_at < HEART_BACK_TIME + 0.1):
		_heart_layer.queue_redraw()
	if _unmask_i >= 0 and now - _unmask_at < UNMASK_TIME + 0.1:
		_sign_layer.queue_redraw()

## The hearts over the grid as one mesh: a full heart for each left, an
## outline where one was, the lost one's halves falling apart, and a heart
## coming back popping in.
func _draw_hearts() -> void:
	if max_hearts <= 0 or _tile <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var y := _origin.y - HEART_ROW * 0.5
	var x0 := size.x * 0.5 - step * (max_hearts - 1) * 0.5
	for i in max_hearts:
		var at := Vector2(x0 + step * i, y)
		if i < hearts:
			var s := HEART_R
			if i == _back_index and not Motion.reduce:
				s *= Motion.pop_in_scale(now - _back_at, HEART_BACK_TIME).x
			if s > 0.5:
				b.polygon(_heart(at, s, 0), Pal.HEART)
				b.ellipse(at + Vector2(-0.42, -0.38) * s, 0.2 * s, 0.13 * s, Color(1.0, 1.0, 1.0, 0.45))
			continue
		b.stroke(_heart(at, HEART_R, 0), 3.0, Color(Pal.LINE, 0.55), true)
		var u := (now - _split_at) / SPLIT_TIME
		if i == _split_index and u < 1.0 and not Motion.reduce:
			var colour := Color(Pal.HEART, 1.0 - u * u)
			for side in [-1, 1]:
				var turn: float = side * SPLIT_TURN * u
				var shift := Vector2(side * SPLIT_SPREAD * u, SPLIT_FALL * u * u)
				var pts := _heart(Vector2.ZERO, HEART_R, side)
				for k in pts.size():
					pts[k] = at + shift + pts[k].rotated(turn)
				b.polygon(pts, colour)
	_hearts_shown = b.mesh()
	_heart_layer.draw_mesh(_hearts_shown, null)

## A heart `s` half-wide about `at` (side 0), or its left (-1) or right (1)
## half, split along a zigzag crack so the two halves fit together.
static func _heart(at: Vector2, s: float, side: int) -> PackedVector2Array:
	const STEPS := 36
	var k := s / 16.0
	var off := Vector2(0.0, -2.5)
	var pts := PackedVector2Array()
	var from := 0.0 if side >= 0 else PI
	var to := TAU if side == 0 else from + PI
	var count := STEPS if side == 0 else STEPS / 2 + 1
	for i in count:
		var t := lerpf(from, to, float(i) / float(STEPS if side == 0 else STEPS / 2))
		var p := Vector2(16.0 * pow(sin(t), 3.0),
			-(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)))
		pts.append(at + (p + off) * k)
	if side == 0:
		return pts
	var zig := [Vector2(1.5, 11.0), Vector2(-1.5, 5.0), Vector2(1.5, -1.0)]
	if side < 0:
		zig.reverse()
	for z: Vector2 in zig:
		pts.append(at + (z + off) * k)
	return pts

## After any change at (r, c): the blush, the worried faces, a completed
## line's wave.
func _after_change(r: int, c: int) -> void:
	_recolour()
	if r >= 0:
		_celebrate(state.line_just_completed(r, c), r, c)

## The host's palette arms a brush; the same value again lets it go.
func set_brush(v: int) -> void:
	if is_done() or out_of_hearts:
		return
	brush = -2 if brush == v else v
	fx.cue("brush")
	brush_changed.emit()

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not out_of_hearts and capabilities().has("undo") and not state.history.is_empty()

## Reverts the last tap: the current face leaves and the previous one pops
## back. Counts no move.
func undo() -> bool:
	if not can_undo():
		return false
	var got: Vector3i = state.undo()
	var r := got.x
	var c := got.y
	_pending[r][c] += 1
	_swap_face(r, c, got.z)
	_hop(r, c, Motion.HOP, Motion.HOP_TIME)
	fx.cue("undo")
	_focus(r, c)
	_after_change(r, c)
	moved.emit()
	return true

func hints_left() -> int:
	if not capabilities().has("hint"):
		return 0
	return HINTS + hints_extra - hints_used

## Fills one cell from the solution: a ring pulses, the face drops in with a
## bounce and sparkles, and the tile takes the given look. Counts no move but
## can finish the puzzle.
func hint() -> bool:
	if is_done() or out_of_hearts or hints_left() <= 0:
		return false
	var cell: Vector2i = state.apply_hint()
	if cell.x < 0:
		return false
	var r := cell.y
	var c := cell.x
	_swap_face(r, c, state.grid[r][c], 0.0, true)
	_paint(_blend[r][c], r, c)
	_ring(r, c)
	var at := cell_to_local(r, c)
	for i in 6:
		fx.sparkle(at + Vector2(_hash(i, r) - 0.5, _hash(c, i) - 0.5) * _tile * 0.7)
	fx.cue("hint")
	hints_used += 1
	_focus(r, c)
	_after_change(r, c)
	moved.emit()
	check_solved()
	return true

## A ring that grows and fades over the hinted tile.
func _ring(r: int, c: int) -> void:
	fx.ring(cell_to_local(r, c), _tile * 0.55)

## Marks every filled free cell that differs from the solution with a wobble
## and a flash. Returns how many; solving stays automatic.
func check() -> int:
	if is_done() or out_of_hearts:
		return 0
	checks += 1
	var wrong: Array = state.wrong_cells()
	for cell in wrong:
		var r: int = cell.y
		var c: int = cell.x
		var tile: Panel = _tiles[r][c]
		tile.rotation = 0.0
		Motion.wobble2d(tile)
		_flash(r, c)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	return wrong.size()

## A quick blush toward the flash level and back to whatever the cell's line
## is heading for.
func _flash(r: int, c: int) -> void:
	Motion.stop(_fades[r][c])
	_fades[r][c] = Motion.flash(self, _paint.bind(r, c), _blend[r][c], CHECK_FLASH, _blend_target[r][c])

## Reset as a wave from the bottom left: free faces shrink out, givens hop,
## a hint's cell goes back to the player, the brush is dropped.
func reset_board() -> void:
	if out_of_hearts:
		return
	_stop_entrance()
	_focus_clear()
	var unlocked := []
	for r in n:
		for c in n:
			if state.hinted[r][c]:
				unlocked.append(Vector2i(c, r))
	state.reset()
	for r in n:
		for c in n:
			_pending[r][c] += 1
			var delay := Motion.stagger((n - 1 - r) + c, Motion.RESET_STAGGER)
			if state.given[r][c]:
				_hop(r, c, Motion.RESET_HOP, Motion.HOP_TIME, delay)
				continue
			if _faces[r][c] != null:
				_swap_face(r, c, -1, delay)
	for cell in unlocked:
		_paint(_blend[cell.y][cell.x], cell.y, cell.x)
	brush = -2
	brush_changed.emit()
	moves = 0
	_recolour()
	fx.cue("reset")

## The daily completion flag persists independently of the board instance.
## Reopening the daily creates a fresh deterministic board, so copy the
## generated solution back into the cells before the host presents the win
## screen. This is deliberately not check_solved(): restoring a completion
## must not emit the completion signal a second time.
func restore_completed_board() -> void:
	_stop_entrance()
	_focus_clear()
	state.history.clear()
	for r in n:
		for c in n:
			state.grid[r][c] = state.solution[r][c]
			_swap_face(r, c, state.grid[r][c])
			_paint(0.0, r, c)
	if state.liar >= 0:
		# Reopened solved: the liar stands caught, as the solve left it.
		_unmask_i = state.liar
		_unmask_at = -INF
	_recolour(false)
	brush = -2
	brush_changed.emit()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

## Every face hops along the diagonal and beams for good, with sparkles over
## the board. The host brings the win screen in after this wave.
## On Insane the liar is caught first (_unmask) and the wave waits for it.
func _on_solved() -> void:
	_focus_clear()
	brush = -2
	brush_changed.emit()
	_lead = 0.0
	if state.liar >= 0:
		_unmask()
		_lead = UNMASK_WAVE
	for r in n:
		for c in n:
			var delay := _lead + Motion.SOLVE_DELAY + Motion.stagger(r + c, Motion.SOLVE_STAGGER)
			_hop(r, c, Motion.SOLVE_HOP, Motion.SOLVE_TIME, delay)
			_beam(r, c, delay, INF)
	if not Motion.reduce:
		var g := _tile * n + GAP * (n - 1)
		for i in 16:
			var at := _origin + Vector2(_hash(i, 1), _hash(i, 2)) * g
			get_tree().create_timer(_lead + 0.2 + _hash(i, 3) * 0.7).timeout.connect(func() -> void:
				if is_instance_valid(fx):
					fx.sparkle(at))
	if _lead > 0.0:
		_later(_lead, fx.cue.bind("solved"))
	else:
		fx.cue("solved")

## How long the host waits before the win screen: its own beat, after the
## unmasking when there was one.
func win_delay() -> float:
	var host: GDScript = load(FLAT_HOST)
	return _lead + float(host.WIN_AFTER_STILL if Motion.reduce else host.WIN_AFTER)

## The liar is caught: its badge swells, blushes and turns over onto a
## sheepish face (_draw_liar, off the clock), and a paper bubble says so over
## it for the hold.
func _unmask() -> void:
	_unmask_i = state.unmask_liar()
	_unmask_at = _now()
	_sign_layer.queue_redraw()
	fx.cue("liar")
	if _tile <= 0.0:
		return
	var bubble := PanelContainer.new()
	bubble.name = "Caught"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.z_index = 2
	var paper := StyleBoxFlat.new()
	paper.bg_color = Pal.SURFACE
	paper.set_corner_radius_all(22)
	paper.set_border_width_all(2)
	paper.border_color = Pal.LINE
	paper.content_margin_left = 20
	paper.content_margin_right = 20
	paper.content_margin_top = 8
	paper.content_margin_bottom = 8
	bubble.add_theme_stylebox_override("panel", paper)
	var label := Label.new()
	label.text = "BN_CAUGHT"
	label.add_theme_font_override("font", CozyTheme.display(700))
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Pal.ACORN_DEEP)
	bubble.add_child(label)
	add_child(bubble)
	bubble.material = null
	bubble.reset_size()
	var at := _sign_at(state.signs[_unmask_i])
	var lift := _tile * SIGN_R * UNMASK_SWELL + 16.0
	var pos := at - Vector2(bubble.size.x * 0.5, lift + bubble.size.y)
	pos.x = clampf(pos.x, 8.0, size.x - bubble.size.x - 8.0)
	if pos.y < 8.0:
		pos.y = at.y + lift
	bubble.position = pos
	bubble.pivot_offset = Vector2(clampf(at.x - pos.x, 0.0, bubble.size.x), bubble.size.y)
	bubble.visible = false
	_caught = bubble
	_later(UNMASK_FLIP_1 + UNMASK_FLIP * 0.5, func() -> void:
		bubble.visible = true
		Motion.pop_in(bubble))
	_later(UNMASK_FLIP_2 + UNMASK_FLIP * 0.5, func() -> void:
		var out: Tween = Motion.appear(bubble, 1.0, 0.0, Motion.POP_OUT * 2.0)
		if out == null:
			bubble.queue_free()
		else:
			out.finished.connect(bubble.queue_free))

# --- entrance ---

## The board arrives: tiles pop in along the diagonal from the top left, and
## a given's face lands a beat after its tile with a squash.
func _enter() -> void:
	_stop_entrance()
	for r in n:
		for c in n:
			var tile: Panel = _tiles[r][c]
			var delay := Motion.stagger(r + c, Motion.ENTER_STAGGER)
			var pop: Tween = Motion.slide(tile, "scale", Vector2.ONE * 0.01, Vector2.ONE, Motion.ENTER_POP, delay)
			if pop != null:
				_entrance.append(pop)
			var face: Control = _faces[r][c]
			if face != null:
				var tw: Tween = Motion.pop_in(face, Motion.POP_IN, delay + Motion.ENTER_FACE_LAG)
				if tw != null:
					_entrance.append(tw)
	_signs_tw = Motion.appear(_sign_layer, 0.0, 1.0, SIGN_IN,
		Motion.stagger(2 * (n - 1), Motion.ENTER_STAGGER) + Motion.ENTER_POP * 0.5)
	fx.cue("enter")

## Cuts the entrance short: everything lands where it was going.
func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	Motion.stop(_signs_tw)
	_sign_layer.modulate.a = 1.0
	for r in _tiles.size():
		for c in _tiles[r].size():
			_tiles[r][c].scale = Vector2.ONE
			var face: Control = _faces[r][c]
			if face != null:
				face.scale = Vector2.ONE

## Kills every tween the previous board still tracks, so a rebuild never
## inherits a hop or a blush aimed at tiles that are about to go.
func _stop_all() -> void:
	_stop_entrance()
	Motion.stop(_focus_tw)
	for rows in [_fades, _hops, _scales]:
		for row in rows:
			for tw in row:
				Motion.stop(tw)
