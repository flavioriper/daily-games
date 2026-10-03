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
##
## Motion and rewards (2026-09-29, the same spec's section 2): a change of
## symbol turns the tile like a coin (each tile is a slot for the hops and
## the press with a coin inside it for the turn), faces near a tap glance at
## it, right tiles in a row build a streak with a paper bubble and confetti,
## a clean line plays one of three gags, and the solve stamps a flawless run
## and throws a party. Notes: docs/agents/boards/binairo.md.

const Gen = preload("res://puzzles/binairo_gen.gd")
const State = preload("res://puzzles/binairo_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Seal = preload("res://ui/flat/seal.gd")
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
const HEART_R := 21.0
const HEART_GAP := 12.0
## The paper pill the hearts sit on, like the signs' badges: its padding
## round the row and its rim.
const HEART_PILL_PAD := Vector2(18.0, 8.0)
const HEART_PILL_RIM := 2.0
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
## Motion and rewards (the polish spec's section 2). A change of symbol turns
## the tile like a coin: it narrows to its edge over FLIP_IN, the face changes
## there, and it springs open over FLIP_OUT with the back ease's overshoot.
const FLIP_IN := 0.1
const FLIP_OUT := 0.14
## Faces this many tiles (a king's move) from a tap look at it this long.
const GLANCE_REACH := 2
const GLANCE_TIME := 0.6
## A hinted tile warms from white into the given sand over this long.
const WARM_TIME := 0.3
## The streak: its paper bubble shows from COMBO_FROM, the layered `combo`
## pluck climbs the major pentatonic from the second in a row (semitones from
## the sample's own pitch; the eighth and past hold the top), and confetti
## flies at COMBO_CONFETTI. A broken streak's bubble deflates over
## COMBO_DEFLATE.
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0

## What the phone does under each cue (core/haptics.gd keeps the strongest
## of a frame's). A tile set and a tile cleared are the faintest knock there
## is; touching a given and arming the brush say nothing (2026-10-03: less
## is more, a buzz for every touch was too much). A blush warns (from
## `_recolour`, after the grace, not from its cue), which on Easy and Medium
## is the only word a wrong tile gets; a heart lost is a heavy knock. The
## streak's pluck and the entrance say nothing either.
const HAPTICS := {
	"clear": Haptics.TICK,
	"undo": Haptics.TICK,
	"place": Haptics.TAP,
	"reset": Haptics.TAP,
	"line": Haptics.BUMP,
	"confetti": Haptics.BUMP,
	"liar": Haptics.BUMP,
	"hint": Haptics.GOOD,
	"check_ok": Haptics.GOOD,
	"heart_back": Haptics.GOOD,
	"check": Haptics.WARN,
	"flawless": Haptics.THUD,
	"heart_lost": Haptics.BAD,
	"out_of_hearts": Haptics.LOSE,
	"solved": Haptics.WIN,
}
const COMBO_CONFETTI := [5, 10]
const COMBO_DEFLATE := 0.25
const COMBO_FONT := 44
## The silly line moments: the gag's punchline lands SILLY_AT after the hop
## starts, and `line_silly` with it, a beat after `line` rather than on top.
const SILLY_AT := 0.32
const SILLY_DB := -3.0
const GLASSES_IN := 0.28
const GLASSES_HOLD := 0.75
const GLASSES_OUT := 0.2
const SNEEZE_WINDUP := 0.3
const LEAN_ANGLE := 0.16
const LEAN_PX := 7.0
const LEAN_TIME := 0.34
const LEAN_STEP := 0.09
## The flawless stamp: it lands STAMP_AT after the wave's lead, dropping from
## STAMP_FROM its size over STAMP_DROP; its radius, as a fraction of the grid.
const STAMP_AT := 0.7
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.11
const STAMP_TILT := -0.22
## The solve party, after the wave's lead: hats pop on along the diagonal,
## confetti, and a big sun and moon slide in from the edges (BIG tiles
## across) and hug at the centre. The host's win screen waits PARTY_EXTRA
## past its usual beat for the hug.
const PARTY_AT := 0.9
const PARTY_HAT := 0.3
const PARTY_HAT_STAGGER := 0.02
const PARTY_SLIDE := 0.55
const PARTY_HUG := 0.28
const PARTY_EXTRA := 1.7
const BIG := 2.5

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
## Under the tiles: every coin, focus tint, sun shadow and sun ray, and
## every face's body, each set one MultiMesh draw (_sync_under). A coin's
## Panel and a face still move as ever -- the hops, flips, leans, spins and
## blinks write their transforms and expressions -- but draw none of that
## themselves (a face keeps only its hat and glasses): gl_compatibility
## batches no polygon or mesh, so a full 10x10 was a hundred coin draws, one
## a moon and three a sun -- about 400 calls, the Insane lag (performance
## checkup, 2026-10-01). Bodies are grouped by mesh: a board shows a handful
## of expressions, eye levels and glances at once, not a hundred.
var _under: Control
var _mm_edge: MultiMesh
var _mm_face: MultiMesh
var _mm_tint: MultiMesh
var _mm_shadow: MultiMesh
var _mm_rays: MultiMesh
var _mm_bodies: Dictionary = {}   # ArrayMesh -> MultiMesh, the bodies shown now
var _mm_sent: Dictionary = {}     # MultiMesh -> the buffer last handed over
var _mm_tile := -1.0
var _mm_sun_r := -1.0
var _tiles: Array = []      # [r][c] -> the tile's slot: hops, nudges, presses, sags
var _coins: Array = []      # [r][c] -> the Panel inside it that turns like a coin
var _flips: Array = []      # [r][c] -> the coin's turn
var _outgoing: Array = []   # [r][c] -> the face the turn's edge takes away
var _leans: Array = []      # [r][c] -> a high-five's lean on the coin
var _warm: Array = []       # [r][c] -> 0 white to 1 given sand
var _warm_tws: Array = []   # [r][c] -> a hint's warm-up fade
var _styles: Array = []     # [r][c] -> its StyleBoxFlat
var _tints: Array = []      # [r][c] -> the focus tint Panel over the tile
var _tint_styles: Array = []  # [r][c] -> its StyleBoxFlat
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
## The newest glance; an older one's end leaves the faces alone.
var _glance_n := 0
## The streak: how many right tiles in a row, which cells have counted once
## already (a cell counts the first time it is right, so cycling one tile
## never climbs), and the bubble: its count, cell, when it popped or bumped,
## and when it began to deflate.
var _streak := 0
var _counted: Array = []
var _combo_layer: Control
var _combo_shown: ArrayMesh
var _combo_n := 0
var _combo_cell := Vector2i(-1, -1)
var _combo_at := -INF
var _combo_popped := false
var _combo_out_at := -INF
## Expressions a gag holds for a while over the state's: Vector2i(c, r) ->
## [expression, msec until].
var _acting := {}
## Whether a heart was lost since the board was dealt, and whether the solve
## was flawless (no heart lost and no hint; on Easy and Medium, no hint and
## no check).
## A heart lost on this board ever, which Try again does not deal away:
## Flawless means the first try.
var _lost_ever := false
var _flawless := false
## The Out of hearts card while it is up, so it opens once and closes for sure.
var _card: Control
var _stamp: Control
var _party: Array = []

func puzzle_id() -> String: return "binairo"
func title() -> String: return "Binairo"

func rules() -> String:
	return tr("BN_RULES")

## The tutorial's pages, for this board's level (ui/hud/how_to_play.gd):
## how a tap works, the three rules, the signs, and on Hard and Insane what a
## wrong tile costs -- and on Insane, that one sign lies.
func tutorial_pages() -> Array:
	const Diagram = preload("res://ui/hud/binairo_tutorial_diagram.gd")
	var pages := []
	for step in [
			[Diagram.Lesson.TAP, "HTP_BN_TAP", "HTP_BN_TAP_BODY"],
			[Diagram.Lesson.THREE, "HTP_BN_THREE", "HTP_BN_THREE_BODY"],
			[Diagram.Lesson.HALF, "HTP_BN_HALF", "HTP_BN_HALF_BODY"],
			[Diagram.Lesson.SIGNS, "HTP_BN_SIGNS", "HTP_BN_SIGNS_BODY"],
			[Diagram.Lesson.HEART, "HTP_BN_HEART", "HTP_BN_HEART_BODY_INSANE" if _level >= 3 else "HTP_BN_HEART_BODY"]]:
		if step[0] == Diagram.Lesson.HEART and max_hearts <= 0:
			continue
		var d := Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": tr(step[2])})
	return pages

## Hard drops Check (a wrong tile says so itself); Insane drops Hint too.
## Insane kept no Undo until the checkup of 2026-10-01; it gives nothing
## away -- a wrong tile is charged after its grace whatever happens -- and
## a player wants to take back a slip. The host reads this after start(),
## so _level is the built one.
func capabilities() -> Array[String]:
	if _level >= 3:
		return ["undo"]
	if _level == 2:
		return ["undo", "hint"]
	return ["undo", "hint", "check"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	# First child, so the tiles (added after) and their faces draw over it.
	_under = Control.new()
	_under.name = "Under"
	_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mm_edge = _multimesh()
	_mm_face = _multimesh()
	_mm_tint = _multimesh()
	_mm_shadow = _multimesh()
	_mm_rays = _multimesh()
	_under.draw.connect(func() -> void:
		for mm in [_mm_edge, _mm_face, _mm_tint, _mm_shadow, _mm_rays] + _mm_bodies.values():
			if mm.mesh != null:
				_under.draw_multimesh(mm, null))
	add_child(_under)
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
	_combo_layer = Control.new()
	_combo_layer.name = "Combo"
	_combo_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_layer.z_index = 2
	_combo_layer.draw.connect(_draw_combo)
	add_child(_combo_layer)
	fx = Fx2D.new()
	fx.name = "Fx"
	# Over the tiles, which are added after it: stars land on the board, not under it.
	fx.z_index = 1
	fx.haptics = HAPTICS
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
	_flawless = false
	_streak = 0
	_combo_n = 0
	_combo_out_at = -INF
	_acting = {}
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
	_coins = []
	_flips = []
	_outgoing = []
	_leans = []
	_warm = []
	_warm_tws = []
	_counted = []
	_styles = []
	_tints = []
	_tint_styles = []
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
	if is_instance_valid(_stamp):
		_stamp.queue_free()
	for node in _party:
		if is_instance_valid(node):
			node.queue_free()
	_party = []
	for r in n:
		var tiles := []
		var coins := []
		var warm := []
		var styles := []
		var tints := []
		var tint_styles := []
		var faces := []
		for c in n:
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(TILE_RADIUS)
			sb.border_width_bottom = TILE_EDGE
			# The slot takes the hops, nudges, the press and the sag; the coin
			# inside it takes the flip and a high-five's lean, so no two tweens
			# ever write the same property (a card moving inside a container
			# needs a slot, docs/agents/flat-screens.md).
			var tile := Control.new()
			tile.name = "tile_%d_%d" % [r, c]
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tile)
			var coin := Panel.new()
			coin.name = "coin"
			coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# The coin is drawn under the tiles (_sync_under); `sb` only keeps
			# its colours.
			coin.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			tile.add_child(coin)
			# CozyTheme.dress() hands every Panel the HUD's paper wash as it enters
			# the tree; on a tile that small the wash reads as a blotch, and a
			# board of them as a stain. The tiles stay flat.
			coin.material = null
			# The focus tint over the tile, the symbol's colour at a few percent,
			# shown for a moment on the tapped cell's row and column.
			var tint := Panel.new()
			tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tsb := StyleBoxFlat.new()
			tsb.set_corner_radius_all(TILE_RADIUS)
			tsb.bg_color = Pal.LINE
			tint.add_theme_stylebox_override("panel", tsb)
			tint.modulate.a = 0.0
			# Drawn under the tiles too (_sync_under), off its modulate.
			tint.visible = false
			coin.add_child(tint)
			tint.material = null
			tiles.append(tile)
			coins.append(coin)
			warm.append(1.0 if state.given[r][c] else 0.0)
			styles.append(sb)
			tints.append(tint)
			tint_styles.append(tsb)
			faces.append(null)
		_tiles.append(tiles)
		_coins.append(coins)
		_warm.append(warm)
		_warm_tws.append(_nulls())
		_flips.append(_nulls())
		_outgoing.append(_nulls())
		_leans.append(_nulls())
		_counted.append(_nulls())
		_styles.append(styles)
		_tints.append(tints)
		_tint_styles.append(tint_styles)
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
	_under.position = Vector2.ZERO
	_under.size = size
	if _tile != _mm_tile:
		_mm_tile = _tile
		_mm_edge.mesh = _coin_mesh(_tile)
		_mm_face.mesh = _coin_mesh(_tile - TILE_EDGE)
		_mm_tint.mesh = _mm_face.mesh
		_under.queue_redraw()
	for layer: Control in [_sign_layer, _heart_layer, _combo_layer]:
		layer.position = Vector2.ZERO
		layer.size = size
		layer.queue_redraw()
	for r in n:
		for c in n:
			var tile: Control = _tiles[r][c]
			tile.position = _rest(r, c) + (Vector2(0.0, SAG) if _asleep else Vector2.ZERO)
			tile.size = Vector2(_tile, _tile)
			tile.pivot_offset = tile.size * 0.5
			var coin: Panel = _coins[r][c]
			coin.position = Vector2.ZERO
			coin.size = tile.size
			coin.pivot_offset = tile.size * 0.5
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
		face.skip_layers = ["shadow", "rays", "body"]
	else:
		face = MoonFace.new()
		face.skip_layers = ["body"]
		face.rocks = _hash(r, c) < ROCK_SHARE
	face.name = "face"
	_coins[r][c].add_child(face)
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
	var warm: float = _warm[r][c]
	var base: Color = Pal.SURFACE.lerp(Pal.STONE_GIVEN, warm)
	var fill: Color
	if blend <= 1.0:
		fill = base.lerp(Pal.BAD_TILE, blend)
	else:
		fill = Pal.BAD_TILE.lerp(Pal.BAD, minf(1.0, (blend - 1.0) * 0.5))
	var sb: StyleBoxFlat = _styles[r][c]
	sb.bg_color = fill
	sb.border_color = Color(Pal.LINE, 0.5).lerp(Pal.LINE, warm)

## The tile at (r, c) warms toward the given sand (1) or back to white (0).
func _set_warm(w: float, r: int, c: int) -> void:
	_warm[r][c] = w
	_paint(_blend[r][c], r, c)

## Rule feedback. Cells whose line just broke blush with two heartbeats and
## shiver once, and their faces worry; cells whose line was fixed fade back.
## A cell already heading for the right blend is left alone.
func _recolour(animate := true) -> void:
	state.refresh_bad()
	_liar_hidden = state.liar >= 0 and not state.is_solved()
	_sign_layer.queue_redraw()
	var blushed: Array[Vector2i] = []
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
				var tw: Tween = Motion.fade(self, setter, _blend[r][c], target, BLUSH_IN, 16, 0.0, true)
				if tw != null:
					for i in 2:
						tw.tween_method(setter, target, target + BLUSH_BEAT_EXTRA, BLUSH_BEAT * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
						tw.tween_method(setter, target + BLUSH_BEAT_EXTRA, target, BLUSH_BEAT * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				_fades[r][c] = tw
				Motion.shiver(_tiles[r][c])
				fx.cue("blush_in")
				blushed.append(Vector2i(c, r))
			else:
				_fades[r][c] = Motion.fade(self, setter, _blend[r][c], target, BLUSH_OUT, 16, 0.0, true)
				fx.cue("blush_out")
	# The blush's buzz waits out the grace a tapped sun gets: a sun on its
	# way to a moon breaks a line for one tap and should not warn the hand.
	if not blushed.is_empty():
		_later(WRONG_GRACE, func() -> void:
			for cell in blushed:
				if _blend_target[cell.y][cell.x] > 0.5:
					Haptics.play(Haptics.WARN)
					return)

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
	var act: Array = _acting.get(Vector2i(c, r), [])
	if not act.is_empty() and Time.get_ticks_msec() < int(act[1]):
		return int(act[0])
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
	_silly(cells, r, c)

# --- silly line moments ---

## A clean line's gag, one of three, picked by a hash of the completing cell
## so a board replays the same: the line's suns slide on sunglasses while its
## moons beam, one moon sneezes a puff of stars, or the line high-fives down
## its length. `line_silly` lands on the punchline, a beat after `line`.
## Decoration: none under reduce-motion, where the line keeps its beam.
func _silly(cells: Array, r: int, c: int) -> void:
	if Motion.reduce or is_done() or state.is_solved():
		return
	match posmod(hash(Vector3i(r, c, n)), 3):
		0: _shades(cells, r, c)
		1: _sneeze(cells, r, c)
		_: _high_five(cells, r, c)
	_later(SILLY_AT, fx.cue.bind("line_silly", 1.0, SILLY_DB))

## Every sun in the line slides on sunglasses, holds them a moment and slides
## them off again, in a wave from the tapped cell.
func _shades(cells: Array, r: int, c: int) -> void:
	for cell in cells:
		var face: Control = _faces[cell.y][cell.x]
		if face == null or state.grid[cell.y][cell.x] != 0:
			continue
		var delay := 0.1 + Motion.stagger(absi(cell.y - r) + absi(cell.x - c), LINE_STAGGER)
		var tw := face.create_tween()
		tw.tween_property(face, "glasses", 1.0, GLASSES_IN).from(0.0).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(GLASSES_HOLD)
		tw.tween_property(face, "glasses", 0.0, GLASSES_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## One moon in the line, picked by the hash, screws its eyes shut and
## stretches ("ah-"), then squashes flat with a puff of stars ("choo!") and
## beams.
func _sneeze(cells: Array, r: int, c: int) -> void:
	var moons := []
	for cell in cells:
		if state.grid[cell.y][cell.x] == 1 and _faces[cell.y][cell.x] != null:
			moons.append(cell)
	if moons.is_empty():
		return
	var at: Vector2i = moons[posmod(hash(Vector2i(c, r)), moons.size())]
	var face: Control = _faces[at.y][at.x]
	_act(at.y, at.x, Face.Expr.SLEEPY, SNEEZE_WINDUP + 0.12)
	var tw := face.create_tween()
	tw.tween_property(face, "scale", Vector2(0.9, 1.12), SNEEZE_WINDUP).set_delay(0.02) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		var tile := cell_to_local(at.y, at.x)
		fx.puff(tile + Vector2(-0.12, 0.1) * _tile, Pal.SUN_RAY, 10)
		fx.puff(tile + Vector2(-0.12, 0.1) * _tile, Pal.CHEEK, 6)
		_act(at.y, at.x, Face.Expr.JOY, JOY_TIME))
	tw.tween_property(face, "scale", Vector2(1.24, 0.76), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(face, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The line's tiles pair off along it and lean into each other one pair
## after another, a clap of sparkle where they meet. In a row they tilt
## their tops together; in a column they bump heads.
func _high_five(cells: Array, r: int, c: int) -> void:
	var row: bool = cells.size() > 1 and cells[0].y == cells[1].y
	var line := cells.duplicate()
	line.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a.x < b.x) if row else (a.y < b.y))
	# Pairs run from the end nearer the tapped cell.
	var near_start: bool = (c if row else r) < n / 2
	if not near_start:
		line.reverse()
	for i in range(0, line.size() - 1, 2):
		var a: Vector2i = line[i]
		var b: Vector2i = line[i + 1]
		var delay := 0.1 + (i / 2) * LEAN_STEP
		var dir := Vector2(b.x - a.x, b.y - a.y)
		_lean(a, dir, delay)
		_lean(b, -dir, delay)
		var mid := (cell_to_local(a.y, a.x) + cell_to_local(b.y, b.x)) * 0.5 - Vector2(0.0, _tile * 0.25)
		_later(delay + LEAN_TIME * 0.5, fx.sparkle.bind(mid, Pal.SUN_RAY))

## The coin at `cell` leans `dir` (a unit step toward its partner) and comes
## back: along a row it tilts its top that way, down a column it only shifts.
func _lean(cell: Vector2i, dir: Vector2, delay: float) -> void:
	var coin: Panel = _coins[cell.y][cell.x]
	Motion.stop(_leans[cell.y][cell.x])
	var tilt := LEAN_ANGLE * dir.x
	var lean := func(t: float) -> void:
		var k := sin(PI * t) * (1.0 + 0.25 * sin(TAU * t))
		coin.rotation = tilt * k
		coin.position = dir * LEAN_PX * k
	var tw := coin.create_tween()
	tw.tween_method(lean, 0.0, 1.0, LEAN_TIME).set_delay(delay)
	_leans[cell.y][cell.x] = tw

## Holds `expr` on the face at (r, c) for `time` over what the state says,
## then gives it back.
func _act(r: int, c: int, expr: int, time: float) -> void:
	_acting[Vector2i(c, r)] = [expr, Time.get_ticks_msec() + int(time * 1000.0)]
	var face: Control = _faces[r][c]
	if face != null:
		face.expression = expr
	_later(time + 0.02, func() -> void:
		var now_face: Control = _faces[r][c]
		if now_face != null:
			now_face.expression = _expression(r, c))

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
	_land_flip(r, c, true)
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

## A change of symbol at (r, c): the coin narrows to its edge, the old face
## goes and the new one shows there, and it springs open again with a small
## overshoot. The new face is made at once, hidden, so everything that asks
## for the cell's face (a wrong tile's yelp, a glance) finds it; the old one
## is kept in _outgoing until the edge. A turn cut short by another lands
## first. Under reduce-motion the faces swap at once.
func _flip_face(r: int, c: int, v: int) -> void:
	_land_flip(r, c, false)
	var old: Control = _faces[r][c]
	_faces[r][c] = null
	if old != null:
		old.set_idle(false)
		_outgoing[r][c] = old
	if v != -1:
		var face := _make_face(r, c, v)
		face.visible = false
		_faces[r][c] = face
	var coin: Panel = _coins[r][c]
	if Motion.reduce:
		_land_flip(r, c, true)
		return
	var tw := coin.create_tween()
	tw.tween_property(coin, "scale:x", 0.0, FLIP_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_edge.bind(r, c))
	tw.tween_property(coin, "scale:x", 1.0, FLIP_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flips[r][c] = tw

## The coin's edge: the face it took away goes, the new one shows.
func _edge(r: int, c: int) -> void:
	var old: Control = _outgoing[r][c]
	_outgoing[r][c] = null
	if old != null:
		old.queue_free()
	var face: Control = _faces[r][c]
	if face != null:
		face.visible = true

## Stops a turn on (r, c) where it is and lands its swap; `open` also opens
## the coin fully (a pop or a rebuild follows, not another turn).
func _land_flip(r: int, c: int, open: bool) -> void:
	if _flips.is_empty():
		return
	Motion.stop(_flips[r][c])
	_flips[r][c] = null
	_edge(r, c)
	if open:
		_coins[r][c].scale = Vector2.ONE

## Faces within GLANCE_REACH of a tapped (r, c) look toward it for
## GLANCE_TIME; a newer glance takes over. Decoration: none under
## reduce-motion.
func _glance(r: int, c: int) -> void:
	if Motion.reduce:
		return
	_glance_n += 1
	var mine := _glance_n
	_look_ahead()
	for rr in range(maxi(0, r - GLANCE_REACH), mini(n, r + GLANCE_REACH + 1)):
		for cc in range(maxi(0, c - GLANCE_REACH), mini(n, c + GLANCE_REACH + 1)):
			var face: Control = _faces[rr][cc]
			if face != null and (rr != r or cc != c):
				face.look = Vector2(c - cc, r - rr).normalized()
	_later(GLANCE_TIME, func() -> void:
		if mine == _glance_n:
			_look_ahead())

## Every face looks straight ahead again.
func _look_ahead() -> void:
	for row in _faces:
		for face in row:
			if face != null and face.look != Vector2.ZERO:
				face.look = Vector2.ZERO

## A hop (negative height lifts) on the tile, replacing any hop already on it.
func _hop(r: int, c: int, height: float, time: float, delay := 0.0) -> void:
	Motion.stop(_hops[r][c])
	var tile: Control = _tiles[r][c]
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
	_flip_face(r, c, v)
	_hop(r, c, Motion.HOP, Motion.HOP_TIME)
	_nudge_neighbours(r, c)
	_glance(r, c)
	if v != -1:
		fx.puff(cell_to_local(r, c), Pal.SUN if v == 0 else Pal.MOON_INK, 5)
	fx.cue("place" if v != -1 else "clear")
	_focus(r, c)
	_after_change(r, c)
	# Every tap under the cycle is on its way somewhere: a sun to a moon, a
	# moon (which always came from a sun) to empty. So either waits out the
	# grace, and only a brush's symbol is judged at once.
	var grace := brush == -2
	# Scored before the move is counted, since the move may solve: the
	# streak's pluck and confetti belong to the tap, not after the party.
	if v != -1:
		_score(r, c, grace)
	note_move()
	_judge(r, c, grace)

# --- the streak ---

## A tile set at (r, c) by the player: it adds to the streak when it is right
## and has not counted before. Right means the solution's own symbol on a
## board with hearts, which a wrong tile says aloud anyway; on Easy and
## Medium, where nothing else tells, it means no rule broken, so the bubble
## never gives away more than the blush does. A wrong tile on a heart board
## ends the streak through _wrong (after the grace for a tapped sun); a
## blushing one on Easy or Medium ends it here.
func _score(r: int, c: int, grace: bool) -> void:
	var good: bool
	if max_hearts > 0:
		good = not state.is_wrong(r, c)
	else:
		good = not _bad(r, c)
		if not good:
			_break_streak()
	if not good or _counted[r][c] != null:
		return
	_counted[r][c] = true
	_streak += 1
	if _streak >= 2:
		var step: int = COMBO_STEPS[mini(_streak - 2, COMBO_STEPS.size() - 1)]
		fx.cue("combo", pow(2.0, step / 12.0), COMBO_DB)
	if _streak >= COMBO_FROM and not state.is_solved():
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = _streak
		_combo_cell = Vector2i(c, r)
		_combo_at = _now()
		_combo_out_at = -INF
		_combo_layer.queue_redraw()
	if COMBO_CONFETTI.has(_streak):
		fx.confetti(cell_to_local(r, c), 22)
		fx.cue("confetti")

## The streak ends: its bubble, if it was up, deflates.
func _break_streak() -> void:
	_streak = 0
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
		_combo_layer.queue_redraw()
	if Motion.reduce:
		_combo_n = 0

## The streak's paper bubble at the upper right of its tile, "x3" and up in
## ink: it pops in the first time, bumps at each step and deflates when the
## streak ends. One mesh for the paper and one string, off the clock, like
## Nonogram's clues.
func _draw_combo() -> void:
	if _combo_n < COMBO_FROM or _tile <= 0.0:
		return
	var now := _now()
	var k := 1.0
	var alpha := 1.0
	if _combo_out_at > -INF:
		var u := (now - _combo_out_at) / COMBO_DEFLATE
		if u >= 1.0 or Motion.reduce:
			_combo_n = 0
			return
		k = 1.0 - 0.75 * u * u
		alpha = 1.0 - u
	elif not Motion.reduce:
		var e := now - _combo_at
		k = Motion.pop_in_scale(e).x if _combo_popped else Motion.bump_scale(e)
	if k <= 0.01:
		return
	var font: Font = CozyTheme.display(700)
	var text := "x%d" % _combo_n
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT).x
	var box := Vector2(tw + 30.0, COMBO_FONT + 16.0)
	var cell := cell_to_local(_combo_cell.y, _combo_cell.x)
	var tail := cell + Vector2(_tile * 0.3, -_tile * 0.3)
	var centre := tail + Vector2(box.x * 0.35, -box.y * 0.75)
	centre.x = clampf(centre.x, box.x * 0.5 + 4.0, size.x - box.x * 0.5 - 4.0)
	centre.y = maxf(centre.y, box.y * 0.5 + 4.0)
	var b := Face.Builder.new()
	var tip := tail - centre
	var root := Vector2(clampf(tip.x, -box.x * 0.3, box.x * 0.3), box.y * 0.3)
	b.polygon(PackedVector2Array([root + Vector2(-9.0, 0.0), tip, root + Vector2(9.0, 0.0)]), Pal.LINE)
	b.polygon(Face.Builder.round_rect(-box * 0.5 - Vector2(2.0, 2.0), box + Vector2(4.0, 4.0), box.y * 0.5 + 2.0), Pal.LINE)
	b.polygon(PackedVector2Array([root + Vector2(-6.5, -2.0), tip + (root - tip).normalized() * 3.0, root + Vector2(6.5, -2.0)]), Pal.SURFACE)
	b.polygon(Face.Builder.round_rect(-box * 0.5, box, box.y * 0.5), Pal.SURFACE)
	_combo_shown = b.mesh()
	_combo_layer.draw_set_transform(centre, 0.0, Vector2.ONE * k)
	_combo_layer.draw_mesh(_combo_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	var ascent := font.get_ascent(COMBO_FONT)
	var descent := font.get_descent(COMBO_FONT)
	_combo_layer.draw_string(font, Vector2(-tw * 0.5, (ascent - descent) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color(Pal.SUN_DEEP, alpha))
	_combo_layer.draw_set_transform(Vector2.ZERO)

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
	_lost_ever = true
	_break_streak()
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
	var tile: Panel = _coins[r][c]
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
	_land_flip(r, c, true)
	_ejecting[r][c] = null
	var crack: Control = _cracks[r][c]
	_cracks[r][c] = null
	if state.is_wrong(r, c):
		_clear_wrong(r, c)
		_recolour()
		focus_changed.emit()
	_drop_out(crack)
	var still: Control = _faces[r][c]
	if still != null:
		still.expression = _expression(r, c)
	moved.emit()
	if out_of_hearts and not _asleep:
		_run_out()

## Empties a wrong (r, c) with the eject's drop and no charge: the state
## forgets it (no move, no history) and any judgement waiting on it lapses.
func _clear_wrong(r: int, c: int) -> void:
	_pending[r][c] += 1
	_land_flip(r, c, true)
	state.clear_silent(r, c)
	var face: Control = _faces[r][c]
	_faces[r][c] = null
	_drop_out(face)

## No wrong tile outlives running out or a heart given back: one still in
## its grace, or one a heart could not be charged for, leaves quietly, so
## the board the player wakes to (or leaves) holds only what could be right.
## A tile mid-eject empties itself.
func _sweep_wrong() -> void:
	var any := false
	for r in n:
		for c in n:
			if _ejecting[r][c] == null and state.is_wrong(r, c):
				_clear_wrong(r, c)
				any = true
	if any:
		_recolour()
		focus_changed.emit()
		moved.emit()

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
	# Two wrong tiles inside one eject window both land here; one sleep.
	if _asleep:
		return
	_asleep = true
	_sweep_wrong()
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
	if not out_of_hearts or is_done() or is_instance_valid(_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used)
	_card = card
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

## One more heart (the card's video): once a board. The
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
	_sweep_wrong()
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
	if is_instance_valid(_card) and not _card.is_queued_for_deletion():
		_card.queue_free()
	_card = null

## Seconds on a steady clock, for the drawn animations.
static func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _process(delta: float) -> void:
	super(delta)
	_sync_under()
	var now := _now()
	if (_split_index >= 0 and now - _split_at < SPLIT_TIME + 0.1) \
			or (_back_index >= 0 and now - _back_at < HEART_BACK_TIME + 0.1):
		_heart_layer.queue_redraw()
	if _unmask_i >= 0 and now - _unmask_at < UNMASK_TIME + 0.1:
		_sign_layer.queue_redraw()
	if _combo_n >= COMBO_FROM and (now - _combo_at < Motion.POP_IN + 0.1 or _combo_out_at > -INF):
		_combo_layer.queue_redraw()

## A MultiMesh of 2D transforms with a colour each.
static func _multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	return mm

## A coin `h` tall and a tile wide, in white for the instance colour to tint:
## the whole coin for its edge, the coin less TILE_EDGE for its face.
func _coin_mesh(h: float) -> ArrayMesh:
	var b := Face.Builder.new()
	b.polygon(Face.Builder.round_rect(Vector2.ZERO, Vector2(_tile, h), TILE_RADIUS), Color.WHITE)
	return b.mesh()

## Copies every coin's, tint's and face's place, turn and colour into the
## MultiMeshes under the tiles, and hands a buffer over only when it changed.
func _sync_under() -> void:
	if _tiles.size() != n or _tile <= 0.0:
		return
	var count := n * n
	var edge := PackedFloat32Array()
	edge.resize(count * 12)
	var face := PackedFloat32Array()
	face.resize(count * 12)
	var tints := PackedFloat32Array()
	tints.resize(count * 12)
	# A coin holds its face and, mid-turn, the one leaving.
	var shadow := PackedFloat32Array()
	shadow.resize(count * 2 * 12)
	var rays := PackedFloat32Array()
	rays.resize(count * 2 * 12)
	var suns := 0
	var bodies := {}   # mesh -> [Transform2D, Color, ...]
	var i := 0
	for r in n:
		for c in n:
			var tile: Control = _tiles[r][c]
			var coin: Control = _coins[r][c]
			var xf := tile.get_transform() * coin.get_transform()
			var a := tile.modulate.a * coin.modulate.a if tile.visible and coin.visible else 0.0
			var sb: StyleBoxFlat = _styles[r][c]
			_put(edge, i, xf, Color(sb.border_color, sb.border_color.a * a))
			_put(face, i, xf, Color(sb.bg_color, sb.bg_color.a * a))
			var tint: Control = _tints[r][c]
			var tc: Color = (_tint_styles[r][c] as StyleBoxFlat).bg_color
			_put(tints, i, xf, Color(tc, tc.a * tint.modulate.a * a))
			i += 1
			for f in coin.get_children():
				if not (f is Face) or f.skip_layers.is_empty():
					continue
				var R := roundf(f._R_for(minf(f.size.x, f.size.y)) / Face.R_STEP) * Face.R_STEP
				if R <= 0.0:
					continue
				var fxf: Transform2D = xf * f.get_transform()
				var centre: Vector2 = f.size * 0.5
				var tone: Color = f.modulate
				tone.a *= a if f.visible else 0.0
				if f is SunFace and suns < count * 2:
					if R != _mm_sun_r:
						_mm_sun_r = R
						_mm_shadow.mesh = f._mesh_for("shadow", false, R, 1.0)
						_mm_rays.mesh = f._mesh_for("rays", false, R, 1.0)
						_under.queue_redraw()
					_put(shadow, suns, fxf * f._layer_transform("shadow", R, centre), tone)
					_put(rays, suns, fxf * f._layer_transform("rays", R, centre), tone)
					suns += 1
				var mesh: ArrayMesh = f._mesh_for("body", true, R, f._eye_level())
				if not bodies.has(mesh):
					bodies[mesh] = []
				bodies[mesh].append(fxf * f._layer_transform("body", R, centre))
				bodies[mesh].append(tone)
	_hand(_mm_edge, edge, count)
	_hand(_mm_face, face, count)
	_hand(_mm_tint, tints, count)
	_hand(_mm_shadow, shadow, count * 2, suns)
	_hand(_mm_rays, rays, count * 2, suns)
	# Only the bodies on show are drawn; a blink or a glance changes which.
	for mesh in _mm_bodies.keys():
		if not bodies.has(mesh):
			_mm_sent.erase(_mm_bodies[mesh])
			_mm_bodies.erase(mesh)
			_under.queue_redraw()
	for mesh in bodies:
		var list: Array = bodies[mesh]
		var buf := PackedFloat32Array()
		buf.resize(list.size() * 6)
		for k in list.size() / 2:
			_put(buf, k, list[2 * k], list[2 * k + 1])
		if not _mm_bodies.has(mesh):
			var mm := _multimesh()
			mm.mesh = mesh
			_mm_bodies[mesh] = mm
			_under.queue_redraw()
		_hand(_mm_bodies[mesh], buf, list.size() / 2)

## Instance `i` of a 2D MultiMesh buffer: the basis and origin in the
## server's row order, then the colour.
static func _put(buf: PackedFloat32Array, i: int, xf: Transform2D, col: Color) -> void:
	var o := i * 12
	buf[o] = xf.x.x
	buf[o + 1] = xf.y.x
	buf[o + 3] = xf.origin.x
	buf[o + 4] = xf.x.y
	buf[o + 5] = xf.y.y
	buf[o + 7] = xf.origin.y
	buf[o + 8] = col.r
	buf[o + 9] = col.g
	buf[o + 10] = col.b
	buf[o + 11] = col.a

## Hands `buf` to `mm` when it differs from what was handed last (never read
## back: a buffer read can stall on the GPU).
func _hand(mm: MultiMesh, buf: PackedFloat32Array, count: int, shown := -1) -> void:
	if mm.instance_count != count:
		mm.instance_count = count
		_mm_sent.erase(mm)
	var visible := count if shown < 0 else shown
	if mm.visible_instance_count != visible:
		mm.visible_instance_count = visible
	if _mm_sent.get(mm) != buf:
		mm.buffer = buf
		_mm_sent[mm] = buf

## The hearts over the grid as one mesh, on a paper pill like the signs'
## badges so they read as the board's own and not the day card's streak: each
## heart is the board's two halves, sun on the left and moon on the right,
## with a small face; a faint ghost of the halves where one was, the lost one's halves
## falling apart (they are the same halves), and a heart coming back popping in.
func _draw_hearts() -> void:
	if max_hearts <= 0 or _tile <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var y := _origin.y - HEART_ROW * 0.5
	var x0 := size.x * 0.5 - step * (max_hearts - 1) * 0.5
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var corner := Vector2(size.x * 0.5, y) - pill * 0.5
	var rim := Vector2.ONE * HEART_PILL_RIM
	b.polygon(Face.Builder.round_rect(corner - rim, pill + 2.0 * rim, pill.y * 0.5 + HEART_PILL_RIM), Pal.LINE)
	b.polygon(Face.Builder.round_rect(corner, pill, pill.y * 0.5), Pal.SURFACE)
	for i in max_hearts:
		var at := Vector2(x0 + step * i, y)
		if i < hearts:
			var s := HEART_R
			if i == _back_index and not Motion.reduce:
				s *= Motion.pop_in_scale(now - _back_at, HEART_BACK_TIME).x
			if s > 0.5:
				b.polygon(_heart(at, s, -1), Pal.SUN)
				b.polygon(_heart(at, s, 1), Pal.MOON_INK)
				_heart_face(b, at, s)
			continue
		# A spent heart stays as its two halves' ghost, so even an empty row
		# reads as the board's and never as the day card's outlined hearts.
		b.polygon(_heart(at, HEART_R, -1), Color(Pal.SUN, 0.22))
		b.polygon(_heart(at, HEART_R, 1), Color(Pal.MOON_INK, 0.22))
		var u := (now - _split_at) / SPLIT_TIME
		if i == _split_index and u < 1.0 and not Motion.reduce:
			var fade := 1.0 - u * u
			for side in [-1, 1]:
				var turn: float = side * SPLIT_TURN * u
				var shift := Vector2(side * SPLIT_SPREAD * u, SPLIT_FALL * u * u)
				var pts := _heart(Vector2.ZERO, HEART_R, side)
				for k in pts.size():
					pts[k] = at + shift + pts[k].rotated(turn)
				b.polygon(pts, Color(Pal.SUN if side < 0 else Pal.MOON_INK, fade))
	_hearts_shown = b.mesh()
	_heart_layer.draw_mesh(_hearts_shown, null)

## A heart's small face: two dots and a smile in ink, a shine at the top left.
static func _heart_face(b, at: Vector2, s: float) -> void:
	b.ellipse(at + Vector2(-0.5, -0.5) * s, 0.16 * s, 0.1 * s, Color(1.0, 1.0, 1.0, 0.45))
	for sx in [-1.0, 1.0]:
		b.disc(at + Vector2(sx * 0.28, -0.12) * s, 0.09 * s, Pal.OUTLINE)
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, 0.02) * s, 0.16 * s, PI * 0.2, PI * 0.8), 0.07 * s, Pal.OUTLINE)

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
	# The crack leaves the tip straight up the middle and meets the notch from
	# the side, so neither half's outline crosses the curve it starts from (a
	# first zig off to one side cut across the right half's tip, and the
	# right half triangulated to nothing).
	var zig := [Vector2(0.0, 13.0), Vector2(1.5, 8.0), Vector2(-1.5, 3.0), Vector2(1.0, -2.0)]
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
	_flip_face(r, c, got.z)
	_hop(r, c, Motion.HOP, Motion.HOP_TIME)
	fx.cue("undo")
	_focus(r, c)
	_after_change(r, c)
	moved.emit()
	# The player chose what the undo brings back, so it is judged like a tap
	# that set it: charged and ejected when wrong, after the same grace a
	# cycling tap gets when no brush is armed (_judge bumps _pending, which
	# also cancels any judgement the undone change was waiting on).
	_judge(r, c, brush == -2)
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
	_counted[r][c] = true
	Motion.stop(_warm_tws[r][c])
	_warm_tws[r][c] = Motion.fade(self, _set_warm.bind(r, c), _warm[r][c], 1.0, WARM_TIME, 16, 0.0, true)
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
		var tile: Control = _tiles[r][c]
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
		Motion.stop(_warm_tws[cell.y][cell.x])
		_warm_tws[cell.y][cell.x] = null
		_set_warm(0.0, cell.y, cell.x)
	_streak = 0
	_break_streak()
	for row in _counted:
		row.fill(null)
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
	# Whether that solve was flawless is not known here: the tallies it was
	# judged on (hints, hearts, checks) belonged to the board that solved and
	# are not saved with the completion, so a reopened board shares no
	# Flawless line rather than guess one.
	_flawless = false

func is_solved() -> bool:
	return state.is_solved()

## The grid as ever, and a flawless solve adds one line under it.
func share_glyphs() -> String:
	var out := state.share_glyphs()
	if _flawless:
		out += ("🌙 %s · %s" % [tr("BN_INSANE_SEAL"), tr("BN_FLAWLESS")]) if _level >= 3 else ("🏅 " + tr("BN_FLAWLESS"))
		out += "\n"
	return out

## Every face hops along the diagonal and beams for good, with sparkles over
## the board. The host brings the win screen in after this wave.
## On Insane the liar is caught first (_unmask) and the wave waits for it.
func _on_solved() -> void:
	_focus_clear()
	brush = -2
	brush_changed.emit()
	_break_streak()
	_look_ahead()
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 else checks == 0)
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
	if _flawless:
		_later(_lead + (0.0 if Motion.reduce else STAMP_AT), _stamp_down)
	if not Motion.reduce:
		_later(_lead + PARTY_AT, _party_on)

# --- the flawless stamp ---

## The stamp drops onto the lower right of the grid from STAMP_FROM its size,
## squashes as it lands and rings; gold "Flawless", or on Insane a night-blue
## seal with a crescent. Under reduce-motion it is simply there. It is the
## result, not decoration, so it shows either way.
func _stamp_down() -> void:
	if _tile <= 0.0 or is_instance_valid(_stamp):
		return
	var g := _tile * n + GAP * (n - 1)
	var rad := g * STAMP_R
	var stamp := Control.new()
	stamp.name = "Stamp"
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.z_index = 3
	stamp.size = Vector2.ONE * rad * 2.0
	stamp.pivot_offset = stamp.size * 0.5
	var centre := _origin + Vector2(g, g) - Vector2.ONE * rad * 0.8
	stamp.position = centre - stamp.pivot_offset
	stamp.rotation = STAMP_TILT
	var insane := _level >= 3
	var mesh := _seal_mesh(rad, insane)
	stamp.draw.connect(func() -> void:
		stamp.draw_mesh(mesh, null, Transform2D(0.0, stamp.pivot_offset))
		_seal_text(stamp, rad, insane))
	add_child(stamp)
	_stamp = stamp
	fx.cue("flawless")
	if Motion.reduce:
		return
	stamp.scale = Vector2.ONE * STAMP_FROM
	stamp.modulate.a = 0.0
	var tw := stamp.create_tween()
	tw.set_parallel(true)
	tw.tween_property(stamp, "scale", Vector2.ONE, STAMP_DROP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(stamp, "modulate:a", 1.0, STAMP_DROP * 0.6)
	tw.chain().tween_callback(func() -> void:
		Motion.squash(stamp, 0.22, 0.26)
		fx.ring(centre, rad * 0.9, Pal.SUN if not insane else Pal.MOON_INK))

## The seal as one mesh (ui/flat/seal.gd, shared with Code Break's stamp).
static func _seal_mesh(rad: float, insane: bool) -> ArrayMesh:
	return Seal.mesh(rad, insane)

## The seal's words: "Flawless", or on Insane the seal's name over a smaller
## "Flawless".
static func _seal_text(item: CanvasItem, rad: float, insane: bool) -> void:
	var lines := [[Seal.tr_static("BN_INSANE_SEAL"), 0.32, 0.02], [Seal.tr_static("BN_FLAWLESS"), 0.2, 0.36]] if insane \
		else [[Seal.tr_static("BN_FLAWLESS"), 0.3, 0.12]]
	Seal.text(item, rad, lines)

# --- the solve party ---

## After the wave: every face pops a party hat on along the diagonal,
## confetti of suns and moons flies over the board, and a big sun and a big
## moon slide in from the edges, wearing hats, and hug at the centre.
func _party_on() -> void:
	if _tile <= 0.0 or not state.is_solved():
		return
	fx.cue("party")
	for r in n:
		for c in n:
			var face: Control = _faces[r][c]
			if face == null:
				continue
			face.hat_style = posmod(hash(Vector2i(r, c)), 3)
			var tw := face.create_tween()
			tw.tween_property(face, "hat", 1.0, PARTY_HAT).from(0.0) \
				.set_delay(Motion.stagger(r + c, PARTY_HAT_STAGGER, 0.4)) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var g := _tile * n + GAP * (n - 1)
	fx.confetti(_origin + Vector2(g * 0.5, g * 0.15), 48, g * 0.9)
	_later(0.25, fx.confetti.bind(_origin + Vector2(g * 0.5, g * 0.55), 32, g * 0.6))
	var mid := _origin + Vector2.ONE * g * 0.5
	var sun: Control = SunFace.new()
	var moon: Control = MoonFace.new()
	sun.size = Vector2.ONE * BIG * _tile * 1.25
	moon.size = Vector2.ONE * BIG * _tile * 0.85
	var gap := BIG * _tile * 0.5
	for pair in [[sun, -1.0, 0], [moon, 1.0, 1]]:
		var face: Control = pair[0]
		var side: float = pair[1]
		face.name = "PartySun" if pair[2] == 0 else "PartyMoon"
		face.z_index = 2
		face.expression = Face.Expr.JOY
		face.shadowless = true
		face.hat = 1.0
		face.hat_style = pair[2]
		face.pivot_offset = face.size * 0.5
		add_child(face)
		face.set_idle(true)
		_party.append(face)
		var rest := mid + Vector2(side * gap, 0.0) - face.size * 0.5
		var from := Vector2(size.x * 0.5 + side * (size.x * 0.5 + face.size.x), rest.y)
		var hug := rest - Vector2(side * _tile * 0.22, 0.0)
		face.position = from
		var tw := face.create_tween()
		# Out of a long slide the back ease overshoots by a tenth of the
		# screen and the two cross; a cubic lands them without.
		tw.tween_property(face, "position", rest, PARTY_SLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(face, "position", hug, PARTY_HUG).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(face, "rotation", -side * 0.2, PARTY_HUG).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func() -> void: Motion.squash(face, 0.1, 0.3))

## How long the host waits before the win screen: its own beat, after the
## unmasking when there was one.
func win_delay() -> float:
	var host: GDScript = load(FLAT_HOST)
	if Motion.reduce:
		return _lead + float(host.WIN_AFTER_STILL)
	return _lead + float(host.WIN_AFTER) + PARTY_EXTRA

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
			var tile: Control = _tiles[r][c]
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
	for rows in [_fades, _hops, _scales, _leans, _warm_tws]:
		for row in rows:
			for tw in row:
				Motion.stop(tw)
	for r in _flips.size():
		for c in _flips[r].size():
			_land_flip(r, c, true)
			_coins[r][c].rotation = 0.0
			_coins[r][c].position = Vector2.ZERO
