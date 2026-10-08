extends "res://core/puzzle_base.gd"

## Horse Pen as a flat board: a meadow seen from straight above, cut by
## streams with banks, boulders lying on it, a chestnut pony standing
## somewhere, and hay bales the player drops to close the gaps. The wheat is
## wherever the horse can still walk, so the pen is read off the board and
## never guessed. The 3D island it replaces was removed with the 3D game on
## 2026-09-24; the rules are that board's move for move, in
## puzzles/horse_state.gd, which this only draws. The look is the one agreed
## on docs/brainstorm/concepts.html#horse (the meadow fills the card, bales
## and not rails, wheat that stands up).
##
## How it is drawn. Everything is a cached unit mesh under a transform, baked
## with Face.FlatBuilder: `_still` is the meadow, its field, the water and the
## boulders (a layout); `_wheat` the reach, rebuilt only while it spreads or
## shrinks; `_items` the apples, hives and tunnel mouths; `_live` the shade
## under the finger, the blushes, the blooms and the bales. The horse and the
## bees are on a layer of their own, since they never stand quite still, and
## the two pills over the field on another.
##
## How it moves. The flat boards' vocabulary (core/motion.gd,
## docs/art/flat-motion.md) read as curves: a bale drops in with the squash
## and lifts out, a refused cell blushes, the field pops in wide. This
## board's own: the wheat spreading out from the horse a step at a time, the
## horse's shake of the head at a Submit that is not yet one, and the win --
## the horse kicks up its heels, the bales hop in the order they were laid,
## and flowers open across the pen from the horse outward.

const State = preload("res://puzzles/horse_state.gd")
const Gen = preload("res://puzzles/horse_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const Parts = preload("res://ui/faces/horse_parts.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Seal = preload("res://ui/flat/seal.gd")
const CozyTheme = preload("res://ui/theme.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
const MovesPill = preload("res://ui/flat/moves_pill.gd")
const MovesDiagram = preload("res://ui/hud/moves_tutorial_diagram.gd")
## The moves the out-of-moves card's video buys, once a board.
const MOVES_BONUS := 5

# --- the meadow ---
const PAD := 30.0
## The strip the pills stand in over the field.
const HUD_ROW := 76.0
const CARD_RADIUS := 26.0
const CARD_EDGE := 6.0
const FIELD_RADIUS := 16.0
const GRID_WIDTH := 2.0
const GRID_ALPHA := 0.55
const WHEAT_INSET := 3.0
const WHEAT_RADIUS := 12.0
const SHADE_ALPHA := 0.1
const BLUSH_ALPHA := 0.85
const TUNNEL_TINTS := [Pal.FLOWER, Pal.CLOUD_DEEP, Pal.SUN]

# --- motion: what is this board's own ---
## The wheat spreads a step at a time from the horse, and sinks at once.
const REACH_TIME := 0.3
const REACH_STEP := 0.014
const REACH_CAP := 0.45
## A bale drops from half a cell up and squashes on landing.
const BALE_DROP := 0.5
const BALE_TIME := 0.24
const BALE_OUT := 0.14
const BALE_LIFT := 0.18
## The horse lands after the field, shakes its head at a Submit that is not
## one yet, hops when the pen closes and kicks on the win.
const HORSE_LAG := 0.25
const HORSE_DROP := 1.2
const HORSE_LAND := 0.36
const HORSE_HOP := 0.16
const SHAKE_TIME := 0.55
const SHAKE_TURNS := 3.0
const SHAKE_ANGLE := 0.26
const KICK_TIME := 0.5
const TAIL_SWING := 0.14
const BLINK_TIME := 0.14
## The win: flowers open over the pen from the horse outward.
const BLOOM_STEP := 0.045
const BLOOM_CAP := 0.9
const BLOOM_TIME := 0.3
const BLOOMS := [Pal.BLOOM, Pal.FLOWER_EYE, Pal.SUN_RAY]
const WIN_WAIT := 1.5
const PARTY_EXTRA := 0.7
const STAMP_AT := 0.5
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.15
const STAMP_TILT := -0.22
const CARD_AFTER := 1.0
const CARD_AFTER_STILL := 0.3
const PILL_FONT := 32
const PILL_H := 50.0
## The toast: the board's own line for what just happened (a refusal, the pen
## closing, a Submit that is not one yet), on a dark pill over the foot of
## the card -- or over its head when the finger is working down there. The
## tip card that used to carry these is gone from every board (Knight's and
## Rings' toast, measure for measure).
const TOAST_HOLD := 2.6
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 40.0

const TIP_CYCLE := 10.0
const TIPS := ["HP_TIP_BALE", "HP_TIP_WHEAT", "HP_TIP_WATER", "HP_TIP_BIGGER"]

## What the phone does under each cue (docs/agents/haptics.md). A bale set
## down is a knock and one lifted fainter; the pen closing, the target
## reached and the best pen are the milestones; a Submit that is not one yet
## warns. The seal thuds as it lands (`_party`).
const HAPTICS := {
	"lift": Haptics.TICK,
	"undo": Haptics.TICK,
	"place": Haptics.TAP,
	"reset": Haptics.TAP,
	"neigh": Haptics.TAP,
	"closed": Haptics.BUMP,
	"open": Haptics.TICK,
	"ready": Haptics.GOOD,
	"best": Haptics.GOOD,
	"hint": Haptics.GOOD,
	"heart_back": Haptics.GOOD,
	"locked": Haptics.WARN,
	"not_yet": Haptics.WARN,
	"out_of_hearts": Haptics.LOSE,
	"solved": Haptics.WIN,
}

var state = State.new()
## Back to camp from the out-of-moves card; the host listens for it.
signal leave

var fx: Node2D
## Insane's move counter (ui/flat/moves_pill.gd): `max_moves` is 0 on a band
## that does not count. Out of moves unsolved is `out_of_hearts`, the name
## the host and the card already know. No band has hearts.
var hearts := 0
var max_hearts := 0
var moves_left := 0
var max_moves := 0
var out_of_hearts := false
var _heart_used := false
var _lost_ever := false
var _asleep := false
var _heart_card: Control
var _moves_pill := MovesPill.new()

var _cell := 0.0
var _grid := Vector2.ZERO
var _card := Rect2()
## Bumped on every rebuild; a pending callback from the last board checks it.
var _gen := 0

# --- the meshes ---
var _still: ArrayMesh
var _items: ArrayMesh
var _wheat: ArrayMesh
var _live: ArrayMesh
var _wheat_unit: ArrayMesh
var _wash_unit: ArrayMesh
var _bale_unit: ArrayMesh
var _bale_old_unit: ArrayMesh
var _shade_unit: ArrayMesh
var _bloom_units: Array = []
var _flat_cache: Dictionary = {}
var _wheat_dirty := true
var _live_dirty := true
## The meshes the last _draw handed over (docs/agents/flat-screens.md: a
## canvas command holds a mesh by RID).
var _shown: Array = []
var _life_layer: Control
var _hud_layer: Control
var _life_shown: Array = []
var _hud_shown: ArrayMesh
var _horse_mesh: ArrayMesh
var _horse_key := ""
var _seal_mesh: ArrayMesh

# --- what the field is doing ---
## The wheat's level a cell: where it was, where it is going, from when.
var _lvl_from := PackedFloat32Array()
var _lvl_to := PackedFloat32Array()
var _lvl_at := PackedFloat32Array()
var _wheat_until := 0.0
## cell -> the second its bale began to drop.
var _bale_in: Dictionary = {}
## Bales leaving: [{"cell", "at", "old"}].
var _bale_out: Array = []
## cell -> the second its bale began a hop.
var _bale_hop: Dictionary = {}
## cell -> the second it began to blush.
var _blush: Dictionary = {}
var _shade_cell := -1
var _shade_at := 0.0
var _shade_until := INF
var _press_cell := -1
var _was_closed := false
var _was_ready := false
var _was_best := false

# --- the horse ---
var _expr := Face.Expr.HAPPY
var _hop_at := -INF
var _shake_at := -INF
var _kick_at := -INF
var _blink_at := 0.0
var _horse_press := -INF
var _pill_bump := [-INF, -INF]
var _pill_bad := -INF

var _opened := -1.0e9
var _solved_at := -1.0
var _stamp_at := INF
var _anim_until := 0.0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _toast := ""
var _toast_at := -100.0
var _toast_high := false
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""
var _tip_idx := 0
var _tip_timer: Timer
var _final_score := 0

func puzzle_id() -> String: return "horse"
func title() -> String: return "Horse Pen"

func rules() -> String:
	var out := tr("HP_RULES") % [state.budget, state.target]
	if state.has_items():
		out += "\n\n" + tr("HP_RULES_APPLES")
	if state.has_gold() or state.has_bees():
		out += "\n\n" + tr("HP_RULES_GOLD")
	if state.has_tunnels():
		out += "\n\n" + tr("HP_RULES_TUNNEL")
	if max_moves > 0:
		out += "\n\n" + tr("RULES_MOVES") % max_moves
	return out

func _tips() -> Array:
	var out: Array = TIPS
	if state.has_items():
		out = out + ["HP_TIP_APPLE"]
	if state.has_bees():
		out = ["HP_TIP_GOLD"] + out
	if state.has_tunnels():
		out = ["HP_TIP_TUNNEL"] + out
	if max_moves > 0:
		out = ["TIP_MOVES"] + out
	return out

## The tutorial: each page is the board itself on a small hand-made meadow
## (ui/hud/horse_tutorial_diagram.gd). Loaded, not preloaded: the page's
## meadow extends this script.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/horse_tutorial_diagram.gd")
	var hints: int = State.hints_for(state.band)
	var steps := [
		[Diagram.Lesson.PEN, "HTP_HP_PEN", tr("HTP_HP_PEN_BODY")],
		[Diagram.Lesson.LEAN, "HTP_HP_LEAN", tr("HTP_HP_LEAN_BODY")],
		[Diagram.Lesson.TARGET, "HTP_HP_TARGET", tr("HTP_HP_TARGET_BODY")]]
	if state.has_items():
		steps.append([Diagram.Lesson.APPLES, "HTP_HP_APPLES", tr("HTP_HP_APPLES_BODY")])
	if state.has_gold() or state.has_bees():
		steps.append([Diagram.Lesson.BEES, "HTP_HP_BEES", tr("HTP_HP_BEES_BODY")])
	if state.has_tunnels():
		steps.append([Diagram.Lesson.TUNNEL, "HTP_HP_TUNNEL", tr("HTP_HP_TUNNEL_BODY")])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_HP_HINT",
			tr("HTP_HP_HINT_BODY_ONE") if hints == 1 else tr("HTP_HP_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	if max_moves > 0:
		pages.append(MovesDiagram.page(self, max_moves))
	return pages

## Undo, Hint and Submit up to Hard. Insane counts moves, so no Undo (lifting
## a bale is the take-back, and it costs one) and no hint; Submit stays on
## every band, since it is the day's ending and says nothing the score does
## not already show.
func capabilities() -> Array[String]:
	if state.band >= 3:
		return ["check"]
	return ["undo", "hint", "check"]

func check_label() -> String: return "HP_SUBMIT"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.haptics = HAPTICS
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_life_layer = _layer("Life", 1, _draw_life)
	_hud_layer = _layer("Hud", 1, _draw_hud)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

## A full-rect layer over the field, drawn by `draw`.
func _layer(nm: String, z: int, draw: Callable) -> Control:
	var layer := Control.new()
	layer.name = nm
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = z
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.draw.connect(draw)
	add_child(layer)
	return layer

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	state.setup(rng, difficulty)
	_begin()

## The field as `state` has it, from the top: Insane's moves, nothing in
## flight, the entrance.
func _begin() -> void:
	max_moves = state.moves_budget()
	_heart_used = false
	_lost_ever = false
	_solved_at = -1.0
	_stamp_at = INF
	_seal_mesh = null
	_deal()
	var n: int = state.cells()
	_lvl_from = PackedFloat32Array()
	_lvl_from.resize(n)
	_lvl_to = PackedFloat32Array()
	_lvl_to.resize(n)
	_lvl_at = PackedFloat32Array()
	_lvl_at.resize(n)
	_layout()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	_enter()

func _deal() -> void:
	moves_left = max_moves
	out_of_hearts = false
	_asleep = false
	_bale_in = {}
	_bale_out = []
	_bale_hop = {}
	_blush = {}
	_shade_cell = -1
	_press_cell = -1
	_toast = ""
	_was_closed = false
	_was_ready = false
	_was_best = false
	_expr = Face.Expr.HAPPY
	_hop_at = -INF
	_shake_at = -INF
	_kick_at = -INF
	_horse_key = ""
	if _hud_layer != null:
		_hud_layer.queue_redraw()

# --- layout ---

## The field is the largest grid the card holds under its strip of pills,
## and the card is cut to the field and centred in the slot (Tents' reason:
## the cell is capped by the width, so there is slack however it is cut).
func _layout() -> void:
	if state.w <= 0:
		return
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var grid := Vector2(_cell * state.w, _cell * state.h)
	var tall := minf(size.y, grid.y + 2.0 * PAD + HUD_ROW)
	_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
	_grid = Vector2(size.x * 0.5 - grid.x * 0.5, _card.position.y + HUD_ROW + (tall - HUD_ROW - grid.y) * 0.5)
	_flat_cache = {}
	_build_units()
	_still = _build_still()
	_items = _build_items()
	_horse_key = ""
	_seal_mesh = null
	_wheat_dirty = true
	_live_dirty = true
	_hud_layer.queue_redraw()
	_life_layer.queue_redraw()
	queue_redraw()

func _cell_for(available: float) -> float:
	if state.w <= 0:
		return 0.0
	return minf((size.x - 2.0 * PAD) / state.w, (available - 2.0 * PAD - HUD_ROW) / state.h)

func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * state.h + 2.0 * PAD + HUD_ROW)

func card_centred() -> bool:
	return true

## Control-local point over the centre of `cell`. The harnesses tap these.
func cell_centre(cell: int) -> Vector2:
	return _grid + Vector2(cell % state.w + 0.5, cell / state.w + 0.5) * _cell

## The same by row and column, the name the win harness knows.
func cell_to_local(r: int, c: int) -> Vector2:
	return _grid + Vector2(c + 0.5, r + 0.5) * _cell

func _cell_at(local: Vector2) -> int:
	if _cell <= 0.0:
		return -1
	var p := (local - _grid) / _cell
	return state.at(Vector2i(int(floor(p.x)), int(floor(p.y))))

func _field_px() -> Rect2:
	return Rect2(_grid, Vector2(_cell * state.w, _cell * state.h))

# --- the still drawings ---

## The pieces drawn many times over, each once about the origin.
func _build_units() -> void:
	var b := Face.Builder.new()
	Parts.wheat(b, _cell, WHEAT_INSET, WHEAT_RADIUS)
	_wheat_unit = b.mesh()
	b = Face.Builder.new()
	var span := _cell - 2.0 * WHEAT_INSET
	b.fan(Face.Builder.round_rect(-Vector2.ONE * span * 0.5, Vector2.ONE * span, WHEAT_RADIUS), Color.WHITE)
	_wash_unit = b.mesh()
	b = Face.Builder.new()
	Parts.bale(b, Vector2.ZERO, _cell)
	_bale_unit = b.mesh()
	b = Face.Builder.new()
	Parts.bale(b, Vector2.ZERO, _cell, true)
	_bale_old_unit = b.mesh()
	b = Face.Builder.new()
	Parts.shade(b, Vector2.ZERO, _cell, 0.4, 0.22)
	_shade_unit = b.mesh()
	_bloom_units = []
	for colour: Color in BLOOMS:
		b = Face.Builder.new()
		Parts.bloom(b, Vector2.ZERO, _cell * 0.07, colour)
		_bloom_units.append(b.mesh())

## The meadow to the card's edge, darker than the field, with tufts in it;
## the field with its faint plot lines; the water; the boulders.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	b.fan(Face.Builder.round_rect(_card.position, _card.size, CARD_RADIUS), Pal.LEAF_DEEP)
	b.fan(Face.Builder.round_rect(_card.position, _card.size - Vector2(0.0, CARD_EDGE), CARD_RADIUS), Pal.TURF_RING)
	var field := _field_px()
	# Tufts in the ring, never on the field: by the card's own lot.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260915 + state.horse * 31 + state.w
	for _k in 26:
		var p := _card.position + Vector2(rng.randf() * _card.size.x, rng.randf() * (_card.size.y - CARD_EDGE))
		if field.grow(10.0).has_point(p) or p.y < _card.position.y + HUD_ROW \
				or not _card.grow(-16.0).has_point(p):
			continue
		Scenery.tuft(b, p, _cell * 0.16)
	b.fan(Face.Builder.round_rect(field.position - Vector2.ONE * 4.0, field.size + Vector2.ONE * 8.0,
		FIELD_RADIUS + 4.0), Color(Pal.LEAF_DEEP, 0.35))
	b.fan(Face.Builder.round_rect(field.position, field.size, FIELD_RADIUS), Pal.MEADOW)
	var line := Color(Pal.TURF_LINE, GRID_ALPHA)
	for x in range(1, state.w):
		b.stroke(PackedVector2Array([field.position + Vector2(x * _cell, 0.0),
			field.position + Vector2(x * _cell, field.size.y)]), GRID_WIDTH, line, false, false)
	for y in range(1, state.h):
		b.stroke(PackedVector2Array([field.position + Vector2(0.0, y * _cell),
			field.position + Vector2(field.size.x, y * _cell)]), GRID_WIDTH, line, false, false)
	Parts.water(b, state.is_water, state.w, state.h, _grid, _cell)
	for i in state.cells():
		if state.is_stone(i):
			Parts.shade(b, cell_centre(i), _cell, 0.38, 0.16)
			Parts.boulder(b, cell_centre(i), _cell * 0.94, i)
	return b.mesh()

## What lies on the grass, over the wheat: apples, the golden apple, hives
## and the tunnels' mouths.
func _build_items() -> ArrayMesh:
	var b := Face.Builder.new()
	var pair := 0
	for t in state.m.tunnels:
		for i: int in t:
			Parts.tunnel(b, cell_centre(i), _cell * 0.94, TUNNEL_TINTS[pair % TUNNEL_TINTS.size()])
		pair += 1
	for i in state.cells():
		match state.item(i):
			Gen.APPLE:
				Parts.shade(b, cell_centre(i), _cell, 0.2, 0.16)
				Parts.apple(b, cell_centre(i), _cell)
			Gen.GOLD:
				Parts.shade(b, cell_centre(i), _cell, 0.24, 0.16)
				Parts.apple(b, cell_centre(i), _cell, true)
			Gen.BEE:
				Parts.shade(b, cell_centre(i), _cell, 0.34, 0.16)
				Parts.hive(b, cell_centre(i) + Vector2(0.0, -0.03 * _cell), _cell * 1.2)
	return null if b.verts.is_empty() else b.mesh()

# --- the drawing ---

func _draw() -> void:
	if _cell <= 0.0 or _still == null:
		return
	var now := _now()
	var shown: Array = []
	# The meadow pops in wide once the chrome has slid in.
	var since := now - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since)
	var grown := Motion.wide_pop_scale(since)
	var centre := _card.get_center()
	var xf := Transform2D(0.0, Vector2(grown, grown), 0.0, centre) * Transform2D(0.0, -centre)
	if seen > 0.0:
		draw_mesh(_still, null, xf, Color(1.0, 1.0, 1.0, seen))
		shown.append(_still)
	if _wheat_dirty or now < _wheat_until:
		_wheat = _build_wheat(now)
		_wheat_dirty = false
	if _wheat != null:
		draw_mesh(_wheat, null)
		shown.append(_wheat)
	if _items != null and seen > 0.0:
		draw_mesh(_items, null, xf, Color(1.0, 1.0, 1.0, seen))
		shown.append(_items)
	if _live_dirty or now < _anim_until:
		_live = _build_live(now)
		_live_dirty = false
	if _live != null:
		draw_mesh(_live, null)
		shown.append(_live)
	_shown = shown

## The wheat's level on `cell` at `now`, 0 to 1.
func _level(cell: int, now: float) -> float:
	if Motion.reduce:
		return _lvl_to[cell]
	var u := clampf((now - _lvl_at[cell]) / REACH_TIME, 0.0, 1.0)
	return lerpf(_lvl_from[cell], _lvl_to[cell], u * u * (3.0 - 2.0 * u))

func _build_wheat(now: float) -> ArrayMesh:
	var fb := Face.FlatBuilder.new(_flat_cache)
	for i in _lvl_to.size():
		var lv := _level(i, now)
		if lv > 0.02:
			fb.append(_wheat_unit, Transform2D(0.0, Vector2(lv, lv), 0.0, cell_centre(i)))
	return fb.mesh()

## The wheat follows the horse's reach: it spreads a step at a time from the
## horse over cells newly reached, and sinks at once where a bale cut it off.
func _sync_reach(from: float) -> void:
	var r: Dictionary = state.reach()
	var seen: PackedByteArray = r.seen
	var dist: PackedInt32Array = r.dist
	var now := _now()
	var last := now
	for i in seen.size():
		var to := float(seen[i])
		if to == _lvl_to[i]:
			continue
		_lvl_from[i] = _level(i, now)
		_lvl_to[i] = to
		_lvl_at[i] = from + (minf(REACH_CAP, dist[i] * REACH_STEP) if to > 0.0 else 0.0)
		last = maxf(last, _lvl_at[i] + REACH_TIME)
	_wheat_until = maxf(_wheat_until, last + 0.05)
	_wheat_dirty = true
	queue_redraw()

## Everything on the field that moves: the shade under the finger, the
## blushes, the blooms of the win, and the bales arriving, standing, hopping
## and leaving.
func _build_live(now: float) -> ArrayMesh:
	var fb := Face.FlatBuilder.new(_flat_cache)
	var busy := false
	if _shade_cell >= 0:
		var grown := 0.0
		if now < _shade_until:
			grown = Motion.wide_pop_scale(now - _shade_at, Motion.POP_IN)
			busy = busy or now - _shade_at < Motion.POP_IN
		else:
			grown = Motion.pop_out_scale(now - _shade_until)
			busy = grown > 0.0
			if grown <= 0.0:
				_shade_cell = -1
		if grown > 0.0:
			fb.append(_wash_unit, Transform2D(0.0, Vector2(grown, grown), 0.0, cell_centre(_shade_cell)),
				Color(Pal.TEXT, SHADE_ALPHA))
	var gone: Array = []
	for cell: int in _blush:
		var e: float = now - float(_blush[cell])
		if e >= Motion.FLASH_IN + Motion.FLASH_OUT:
			gone.append(cell)
			continue
		busy = true
		var level := Motion.flash_level(e)
		if level > 0.0:
			fb.append(_wash_unit, Transform2D(0.0, cell_centre(cell)), Color(Pal.BAD, BLUSH_ALPHA * level * 0.6))
	for cell in gone:
		_blush.erase(cell)
	if _solved_at >= 0.0:
		busy = _build_blooms(fb, now) or busy
	var still: Array = []
	for out in _bale_out:
		var e: float = now - float(out.at)
		if e >= BALE_OUT or Motion.reduce:
			continue
		still.append(out)
		busy = true
		if e < 0.0:
			_bale(fb, int(out.cell), Vector2.ONE, 0.0, bool(out.old), 1.0)
			continue
		var k := Motion.pop_out_scale(e, BALE_OUT)
		_bale(fb, int(out.cell), Vector2(k, k), (1.0 - k) * BALE_LIFT * _cell, bool(out.old), k)
	_bale_out = still
	# Top rows first, so a bale's front overlaps the one behind it.
	var order: Array = state.laid.duplicate()
	order.sort()
	for cell: int in order:
		var sc := Vector2.ONE
		var lift := 0.0
		var alpha := 1.0
		if _bale_in.has(cell) and not Motion.reduce:
			var e: float = now - float(_bale_in[cell])
			if e < 0.0:
				busy = true
				continue
			if e < BALE_TIME:
				busy = true
				sc = Motion.pop_in_scale(e, BALE_TIME)
				lift = Motion.drop_in_lift(e, BALE_DROP * _cell, BALE_TIME)
				alpha = Motion.appear_level(e)
			else:
				_bale_in.erase(cell)
		if _bale_hop.has(cell) and not Motion.reduce:
			var e: float = now - float(_bale_hop[cell])
			if e >= 0.0 and e < Motion.SOLVE_TIME:
				lift -= Motion.hop_lift(e, Motion.SOLVE_HOP, Motion.SOLVE_TIME)
			if e < Motion.SOLVE_TIME:
				busy = true
			else:
				_bale_hop.erase(cell)
		_bale(fb, cell, sc, lift, state.pinned.has(cell), alpha)
	if busy:
		_anim_until = maxf(_anim_until, now + 0.1)
	return fb.mesh()

## One bale on `cell`, grown `sc` about its foot and raised `lift` pixels,
## over its shadow.
func _bale(fb, cell: int, sc: Vector2, lift: float, old: bool, alpha: float) -> void:
	var at := cell_centre(cell)
	var near := clampf(1.0 - lift / (BALE_DROP * _cell), 0.3, 1.0)
	fb.append(_shade_unit, Transform2D(0.0, Vector2(sc.x * near, near), 0.0, at), Color(1.0, 1.0, 1.0, alpha * near))
	var foot := Vector2(0.0, 0.35 * _cell)
	var xf := Transform2D(0.0, sc, 0.0, at + foot - Vector2(0.0, lift)) * Transform2D(0.0, -foot)
	fb.append(_bale_old_unit if old else _bale_unit, xf, Color(1.0, 1.0, 1.0, alpha))

## Flowers over the pen from the horse outward. True while any is opening.
func _build_blooms(fb, now: float) -> bool:
	var r: Dictionary = state.reach()
	var busy := false
	for cell: int in r.order:
		if cell == state.horse or state.item(cell) != Gen.NONE or state.twin(cell) >= 0:
			continue
		var e: float = now - _solved_at - Motion.SOLVE_DELAY - minf(BLOOM_CAP, int(r.dist[cell]) * BLOOM_STEP)
		var k := 1.0 if Motion.reduce else Motion.pop_in_scale(e, BLOOM_TIME).x
		if e < BLOOM_TIME and not Motion.reduce:
			busy = true
		if k <= 0.0:
			continue
		for j in 2:
			var lot := _hash(cell * 7 + j)
			var lot2 := _hash(cell * 13 + j + 50)
			var at := cell_centre(cell) + Vector2(lot - 0.5, lot2 - 0.5) * _cell * 0.6
			fb.append(_bloom_units[(cell + j) % _bloom_units.size()],
				Transform2D((lot - 0.5) * 2.0, Vector2(k, k) * (0.8 + 0.5 * lot2), 0.0, at))
	return busy

# --- the horse and the bees ---

func _draw_life() -> void:
	if _cell <= 0.0 or state.w <= 0:
		return
	var now := _now()
	var shown: Array = []
	var e := now - _opened - Motion.ENTER_DELAY - HORSE_LAG
	if e < 0.0 and not Motion.reduce:
		return
	var b := Face.Builder.new()
	for i in state.cells():
		if state.item(i) == Gen.BEE:
			_bees(b, i, now)
	var at := cell_centre(state.horse)
	var lift := 0.0
	var alpha := 1.0
	var squash := Vector2.ONE
	if not Motion.reduce:
		if e < HORSE_LAND:
			lift = Motion.drop_in_lift(e, HORSE_DROP * _cell, HORSE_LAND)
			alpha = Motion.appear_level(e)
			squash = Motion.pop_in_scale(e, HORSE_LAND)
		var hop := now - _hop_at
		if hop >= 0.0 and hop < Motion.HOP_TIME:
			lift -= Motion.hop_lift(hop, -HORSE_HOP * _cell, Motion.HOP_TIME)
		var kick_e := now - _kick_at
		if kick_e >= 0.0 and kick_e < KICK_TIME:
			lift += sin(PI * kick_e / KICK_TIME) * HORSE_HOP * 1.4 * _cell
		var held := now - _horse_press
		if held >= 0.0 and held < Motion.PRESS_TIME + Motion.RELEASE_TIME:
			squash *= Motion.press_scale(minf(held, Motion.PRESS_TIME), held - Motion.PRESS_TIME)
	# The shadow stays on the ground and shrinks as the horse leaves it.
	var near := clampf(1.0 - lift / (HORSE_DROP * _cell), 0.3, 1.0)
	var sb := Face.Builder.new()
	Scenery.soft_disc(sb, at + Vector2(0.0, 0.38 * _cell), 0.36 * _cell * near, 0.1 * _cell * near,
		Color(Pal.TEXT, 0.22 * alpha * near))
	var shadow := sb.mesh()
	_life_layer.draw_mesh(shadow, null)
	shown.append(shadow)
	var pose := _pose(now)
	var key := "%d|%.2f|%.3f|%.3f|%.3f" % [pose.expr, pose.eye, pose.nod, pose.kick, pose.tail]
	if key != _horse_key or _horse_mesh == null:
		var hb := Face.Builder.new()
		Parts.horse(hb, Vector2.ZERO, _cell * 0.92, pose.expr, pose.eye, pose.nod, pose.kick, pose.tail,
			state.horse % state.w >= (state.w + 1) / 2)
		_horse_mesh = hb.mesh()
		_horse_key = key
	var foot := Vector2(0.0, 0.38 * _cell)
	var xf := Transform2D(0.0, squash, 0.0, at + foot - Vector2(0.0, lift)) * Transform2D(0.0, -foot)
	_life_layer.draw_mesh(_horse_mesh, null, xf, Color(1.0, 1.0, 1.0, alpha))
	shown.append(_horse_mesh)
	if not b.verts.is_empty():
		var bees := b.mesh()
		_life_layer.draw_mesh(bees, null)
		shown.append(bees)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_life_shown = shown

## How the horse holds itself at `now`.
func _pose(now: float) -> Dictionary:
	var out := {"expr": _expr, "eye": 1.0, "nod": 0.0, "kick": 0.0, "tail": 0.0}
	if Motion.reduce:
		return out
	out.tail = snappedf(sin(now * 1.7) * TAIL_SWING, 0.01)
	var blink := now - _blink_at
	if blink >= 0.0 and blink < BLINK_TIME:
		out.eye = snappedf(absf(blink / BLINK_TIME * 2.0 - 1.0), 0.25)
	elif blink >= BLINK_TIME:
		_blink_at = now + 2.5 + 3.5 * _hash(int(now * 10.0))
	var shake := now - _shake_at
	if shake >= 0.0 and shake < SHAKE_TIME:
		var u := shake / SHAKE_TIME
		out.nod = snappedf(sin(u * TAU * SHAKE_TURNS) * SHAKE_ANGLE * (1.0 - u), 0.005)
	var kick := now - _kick_at
	if kick >= 0.0 and kick < KICK_TIME:
		out.kick = snappedf(sin(PI * kick / KICK_TIME), 0.02)
		out.nod = -0.15 * out.kick
	return out

## Two bees round the hive on `cell`; quicker and wider once the pen has
## closed over them.
func _bees(b: Face.Builder, cell: int, now: float) -> void:
	var c := cell_centre(cell) + Vector2(0.0, -0.12 * _cell)
	var penned: bool = state.closed() and state.reach().seen[cell] == 1
	var t := 0.0 if Motion.reduce else now * (2.6 if penned else 1.5)
	for k in 2:
		var ph := _hash(cell * 5 + k) * TAU
		var wide := (0.4 if penned else 0.32) * _cell
		var p := c + Vector2(cos(t + ph) * wide, sin(t * 1.7 + ph) * wide * 0.5)
		Parts.bee(b, p, _cell * 0.065, absf(sin(now * 30.0 + k)))

# --- the pills ---

## The stock of bales on the left, the pen's score against the target on the
## right, and on Insane the moves between them.
func _draw_hud() -> void:
	if _cell <= 0.0 or state.w <= 0:
		return
	var now := _now()
	var since := now - _opened - Motion.ENTER_DELAY
	if since < 0.0 and not Motion.reduce:
		return
	var font: Font = CozyTheme.display(700)
	var y := _card.position.y + HUD_ROW * 0.5 + 6.0
	var left_text := "%d" % state.bales_left()
	var closed: bool = state.closed()
	var right_text: String = ("%d / %d" % [state.score(), state.target]) if closed \
		else tr("HP_PILL_OPEN") % state.target
	var right_ink := Pal.TEXT_DIM
	if closed:
		right_ink = Pal.TEXT
		if state.score() >= state.best:
			right_ink = Pal.SUN_DEEP
		elif state.score() >= state.target:
			right_ink = Pal.LEAF_DEEP
	var left_ink := Pal.BAD if now - _pill_bad < 0.6 or state.bales_left() == 0 else Pal.TEXT
	var lw := font.get_string_size(left_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT).x
	var rw := font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT).x
	var icon := PILL_H * 0.9
	var boxes := [Vector2(lw + icon + 44.0, PILL_H), Vector2(rw + icon + 44.0, PILL_H)]
	var centres := [Vector2(_card.position.x + PAD + boxes[0].x * 0.5, y),
		Vector2(_card.end.x - PAD - boxes[1].x * 0.5, y)]
	var b := Face.Builder.new()
	var scales := [1.0, 1.0]
	for k in 2:
		if not Motion.reduce:
			scales[k] = Motion.bump_scale(now - float(_pill_bump[k]), 0.12)
		var box: Vector2 = boxes[k] * float(scales[k])
		var c: Vector2 = centres[k]
		b.polygon(Face.Builder.round_rect(c - box * 0.5 - Vector2.ONE * 2.0, box + Vector2.ONE * 4.0, box.y * 0.5 + 2.0), Pal.LINE)
		b.polygon(Face.Builder.round_rect(c - box * 0.5, box, box.y * 0.5), Pal.SURFACE)
	var bale_at: Vector2 = centres[0] + Vector2(-boxes[0].x * 0.5 + 16.0 + icon * 0.5, 0.0)
	Parts.bale(b, bale_at, icon * 0.9)
	var mark_at: Vector2 = centres[1] + Vector2(-boxes[1].x * 0.5 + 16.0 + icon * 0.5, 0.0)
	if closed and state.score() >= state.best:
		b.polygon(Seal.star(mark_at, icon * 0.42), Pal.SUN)
	else:
		Parts.wheat_ear(b, mark_at, icon, Pal.WHEAT.darkened(0.12) if closed else Pal.TEXT_DIM)
	_hud_shown = b.mesh()
	var alpha := 1.0 if Motion.reduce else Motion.appear_level(since)
	_hud_layer.draw_mesh(_hud_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	var mid := (font.get_ascent(PILL_FONT) - font.get_descent(PILL_FONT)) * 0.5
	_hud_layer.draw_string(font, bale_at + Vector2(icon * 0.5 + 8.0, mid), left_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT, Color(left_ink, alpha))
	_hud_layer.draw_string(font, mark_at + Vector2(icon * 0.5 + 8.0, mid), right_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT, Color(right_ink, alpha))
	if max_moves > 0:
		_moves_pill.draw(_hud_layer, Vector2(size.x * 0.5, y), moves_left, now)
	_draw_toast(now)

func _bump_pill(k: int) -> void:
	_pill_bump[k] = _now()
	_hud_layer.queue_redraw()

# --- input ---

## Touch and mouse, as every flat board takes them (touch is not mouse here:
## emulate_mouse_from_touch is off). A tap on bare grass drops a bale, a tap
## on a bale lifts it; a finger that leaves its cell cancels.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(_cell_at(event.position))
		else:
			_release(_cell_at(event.position))
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _press_cell >= 0:
		if _cell_at(event.position) != _press_cell:
			_press_cell = -1
			_end_shade()

func _press(cell: int) -> void:
	_press_cell = -1
	if is_done() or cell < 0 or out_of_hearts:
		return
	_press_cell = cell
	var now := _now()
	if cell == state.horse:
		_horse_press = now
	else:
		_shade_cell = cell
		_shade_at = now
		_shade_until = INF
	_busy_for(Motion.POP_IN)
	_redraw()

func _end_shade() -> void:
	if _shade_cell >= 0 and is_inf(_shade_until):
		_shade_until = _now()
	_busy_for(Motion.POP_OUT)
	_redraw()

func _release(cell: int) -> void:
	var pressed := _press_cell
	_press_cell = -1
	_end_shade()
	if pressed < 0 or cell != pressed or is_done() or out_of_hearts:
		return
	tap(cell)

## The move itself, which the harnesses and the tutorial call too.
func tap(cell: int) -> void:
	if is_done() or out_of_hearts or cell < 0:
		return
	if cell == state.horse:
		# The horse answers a pat: a hop and a whinny, and nothing else.
		_hop_at = _now()
		fx.cue("neigh")
		return
	# Insane counts moves: a bale laid or lifted is one, and a tap the count
	# cannot pay for is not a move.
	var cost := 1 if max_moves > 0 else 0
	if cost > moves_left and max_moves > 0:
		return
	var was_bale: bool = state.has_bale(cell)
	var old: bool = state.pinned.has(cell)
	match state.tap(cell):
		State.OK:
			var now := _now()
			if was_bale:
				_bale_in.erase(cell)
				if not Motion.reduce:
					_bale_out.append({"cell": cell, "at": now, "old": old})
				fx.cue("lift")
			else:
				_bale_in[cell] = now
				fx.puff(cell_centre(cell) + Vector2(0.0, 0.3 * _cell), Pal.STRAW, 4)
				fx.cue("place")
			_busy_for(BALE_TIME)
			_bump_pill(0)
			_after_change(now + (BALE_TIME * 0.6 if not was_bale else 0.0), false, cell)
			note_move()
			_spend(cost, now)
		State.REFUSED_STOCK:
			_pill_bad = _now()
			_bump_pill(0)
			_refuse(cell, "HP_REFUSE_STOCK")
		State.REFUSED_PINNED:
			_bale_hop[cell] = _now()
			_refuse(cell, "HP_REFUSE_PINNED")
		_:
			var why := "HP_REFUSE_ITEM"
			if state.is_water(cell): why = "HP_REFUSE_WATER"
			elif state.is_stone(cell): why = "HP_REFUSE_STONE"
			elif state.twin(cell) >= 0: why = "HP_REFUSE_TUNNEL"
			_refuse(cell, why)
	_redraw()

func _refuse(cell: int, why: String) -> void:
	_tell(tr(why), Face.Expr.PUZZLED, cell)
	fx.cue("locked")
	if not Motion.reduce:
		_blush[cell] = _now()
		_busy_for(Motion.FLASH_IN + Motion.FLASH_OUT)

## A bale moved: the wheat follows, the pills recount, and the horse and the
## sprout say what the pen has become.
func _after_change(from: float, quiet := false, near := -1) -> void:
	_sync_reach(from)
	var closed: bool = state.closed()
	var ready: bool = closed and state.score() >= state.target
	var is_best: bool = closed and state.score() >= state.best
	if closed != _was_closed or closed:
		_bump_pill(1)
	if not quiet:
		if is_best and not _was_best:
			fx.cue("best")
			_hop_at = _now()
			fx.sparkle(cell_centre(state.horse), Pal.SUN)
		elif ready and not _was_ready:
			fx.cue("ready")
			_hop_at = _now()
			fx.ring(cell_centre(state.horse), _cell * 0.6, Pal.LEAF)
		elif closed and not _was_closed:
			fx.cue("closed")
			fx.ring(cell_centre(state.horse), _cell * 0.6, Pal.WHEAT)
		elif _was_closed and not closed:
			fx.cue("open")
	var turned := closed != _was_closed or ready != _was_ready or is_best != _was_best \
		or (not closed and state.bales_left() == 0)
	_was_closed = closed
	_was_ready = ready
	_was_best = is_best
	_expr = _mood()
	_speak()
	# Said aloud only when the pen became something else, never on every bale.
	if turned and not quiet and state.bales() > 0 and (closed or state.bales_left() == 0):
		_tell(_tip_text, _tip_mood, near)
	_hud_layer.queue_redraw()
	_life_layer.queue_redraw()

## The horse's look: asleep with the board, pleased in a pen worth the
## target, uneasy when a hive is penned in with it.
func _mood() -> int:
	if _asleep:
		return Face.Expr.SLEEPY
	if not state.closed():
		return Face.Expr.HAPPY
	var seen: PackedByteArray = state.reach().seen
	for i in state.cells():
		if seen[i] == 1 and state.item(i) == Gen.BEE:
			return Face.Expr.WORRIED
	return Face.Expr.JOY if state.score() >= state.target else Face.Expr.HAPPY

# --- the sprout's line ---

func _speak() -> void:
	if is_done():
		return
	if state.bales() == 0:
		_say(tr(_tips()[_tip_idx % _tips().size()]), Face.Expr.HAPPY)
		return
	if not state.closed():
		_say(tr("HP_OPEN_STOCK") if state.bales_left() == 0 else tr("HP_OPEN"), Face.Expr.HAPPY)
		return
	var short: int = state.target - state.score()
	if short > 0:
		_say(tr("HP_SHORT_ONE") if short == 1 else tr("HP_SHORT_N") % short, Face.Expr.PUZZLED)
	elif state.score() >= state.best:
		_say(tr("HP_BEST"), Face.Expr.JOY)
	else:
		_say(tr("HP_READY"), Face.Expr.JOY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

## A line the player has to see now: said, and shown on the toast. `near` is
## the cell the finger is on, so the toast keeps out of its way.
func _tell(text: String, mood: int, near := -1) -> void:
	_say(text, mood)
	_toast = text
	_toast_at = _now()
	_toast_high = near >= 0 and near / state.w >= state.h * 2 / 3
	_hud_layer.queue_redraw()

func _draw_toast(now: float) -> void:
	if _toast == "":
		return
	var since := now - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE),
		Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var font: Font = CozyTheme.body(600)
	var room := maxf(TOAST_PAD, size.x - 120.0)
	var text_room := room - TOAST_PAD
	var one: float = font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x
	var lines := 1
	var text_w := one
	if one > text_room:
		var wrapped: Vector2 = font.get_multiline_string_size(_toast, HORIZONTAL_ALIGNMENT_CENTER, text_room, TOAST_FONT)
		lines = maxi(1, int(round(wrapped.y / font.get_height(TOAST_FONT))))
		text_w = minf(text_room, wrapped.x)
	var wide := minf(room, text_w + TOAST_PAD)
	var tall := TOAST_H + float(lines - 1) * font.get_height(TOAST_FONT)
	var key := "%s|%d|%d" % [_toast, int(wide), lines]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-wide, -tall) * 0.5, Vector2(wide, tall), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh()
		_toast_mesh_for = key
	var field := _field_px()
	var mid := Vector2(size.x * 0.5, field.end.y - TOAST_MARGIN - tall * 0.5)
	if _toast_high:
		mid.y = field.position.y + TOAST_MARGIN + tall * 0.5
	_hud_layer.draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha * 0.94))
	var top := mid.y - tall * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - wide * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		_hud_layer.draw_string(font, Vector2(left, top), _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		_hud_layer.draw_multiline_string(font, Vector2(left, top), _toast, HORIZONTAL_ALIGNMENT_CENTER,
			wide - TOAST_PAD, TOAST_FONT, lines, Color(Pal.PAPER, alpha))

func _cycle_tip() -> void:
	if is_done() or state.bales() > 0 or _tip_mood != Face.Expr.HAPPY:
		return
	_tip_idx = (_tip_idx + 1) % _tips().size()
	_say(tr(_tips()[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return max_moves == 0 and not is_done() and not out_of_hearts and not state.history.is_empty()

func undo() -> bool:
	if not can_undo():
		return false
	var before: bool = false
	var cell: int = state.undo()
	if cell < 0:
		return false
	before = not state.has_bale(cell)
	var now := _now()
	if before:
		if not Motion.reduce:
			_bale_out.append({"cell": cell, "at": now, "old": false})
	else:
		_bale_in[cell] = now
	_busy_for(BALE_TIME)
	_bump_pill(0)
	_after_change(now, true)
	fx.cue("undo")
	_redraw()
	moved.emit()
	return true

func hints_left() -> int:
	return State.hints_for(state.band) + hints_extra - hints_used

## Drops one bale of the answer's pen and pins it: a ring out of the cell,
## the bale from above in older straw, sparkles. If the stock was spent, one
## of the player's own bales is lifted to pay for it.
func hint() -> bool:
	if is_done() or out_of_hearts or hints_left() <= 0:
		return false
	var got: Dictionary = state.hint()
	if got.is_empty():
		_tell(tr("HP_HINT_NONE"), Face.Expr.HAPPY)
		return false
	hints_used += 1
	var now := _now()
	var cell: int = got.cell
	if int(got.lifted) >= 0 and not Motion.reduce:
		_bale_out.append({"cell": int(got.lifted), "at": now, "old": false})
	_bale_in[cell] = now
	var at := cell_centre(cell)
	fx.ring(at, _cell * 0.5, Pal.LEAF)
	fx.sparkle(at, Pal.LEAF)
	fx.cue("hint")
	_busy_for(BALE_TIME)
	_bump_pill(0)
	_after_change(now + BALE_TIME * 0.6, true)
	_tell(tr("HP_HINTED"), Face.Expr.HAPPY, cell)
	_redraw()
	moved.emit()
	return true

## Submit. An open pen blushes where the horse still gets out and the horse
## shakes its head; a closed one under the target gets the shake alone; a pen
## worth the target ends the day. Always -1: there is nothing to count.
func check() -> int:
	if is_done() or out_of_hearts:
		return -1
	checks += 1
	var now := _now()
	match state.submit():
		State.OPEN:
			if not Motion.reduce:
				for cell: int in state.reach().gaps:
					_blush[cell] = now
			_shake_at = now
			_tell(tr("HP_SUBMIT_OPEN"), Face.Expr.PUZZLED)
			fx.cue("not_yet")
			_busy_for(Motion.FLASH_IN + Motion.FLASH_OUT)
		State.SMALL:
			_shake_at = now
			var short: int = state.target - state.score()
			_tell(tr("HP_SUBMIT_SMALL_ONE") if short == 1 else tr("HP_SUBMIT_SMALL_N") % short, Face.Expr.PUZZLED)
			fx.cue("not_yet")
		State.OK:
			check_solved()
	_redraw()
	return -1

## Every bale goes, in a wave from the far corner, and the wheat runs back
## out to the edges. The hints a player spent are not refunded.
func reset_board() -> void:
	if is_done() or out_of_hearts:
		return
	_clear_field(_now())
	moves = 0
	moves_left = max_moves
	_running = true
	_tell(tr("HP_RESET"), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	_redraw()

func _clear_field(now: float) -> void:
	var pinned: Dictionary = state.pinned.duplicate()
	var had: Array = state.reset()
	_bale_in = {}
	_bale_hop = {}
	_blush = {}
	if not Motion.reduce:
		for cell: int in had:
			var c: Vector2i = state.xy(cell)
			_bale_out.append({"cell": cell, "old": pinned.has(cell),
				"at": now + Motion.stagger((state.h - 1 - c.y) + (state.w - 1 - c.x), Motion.RESET_STAGGER)})
	_busy_for(0.6 + BALE_OUT)
	_was_closed = false
	_was_ready = false
	_was_best = false
	_after_change(now, true)
	_bump_pill(0)

func is_solved() -> bool:
	return state.is_solved()

func completion_record() -> Dictionary:
	return {"walls": Array(state.laid), "score": state.score()}

## A completed daily is rebuilt from its seed, so the field opens bare: the
## player's own bales go back (the answer's when none were kept) and
## everything settles as the finished day left it.
func restore_completed_board() -> void:
	var now := _now()
	_gen += 1
	_tip_timer.stop()
	state.finish(completed_record.get("walls", []))
	if not state.closed():
		state.finish()
	_deal()
	_opened = now - 10.0
	_solved_at = now - 10.0
	_final_score = state.score()
	_anim_until = 0.0
	_expr = Face.Expr.JOY
	_was_closed = true
	var seen: PackedByteArray = state.reach().seen
	for i in seen.size():
		_lvl_from[i] = float(seen[i])
		_lvl_to[i] = float(seen[i])
		_lvl_at[i] = now - 10.0
	_wheat_dirty = true
	_stamp_at = now - 10.0 if state.band >= 3 or _final_score >= state.best else INF
	_seal_mesh = null
	_say(tr("HP_WIN"), Face.Expr.JOY)
	_hud_layer.queue_redraw()
	_life_layer.queue_redraw()
	_redraw()

func share_glyphs() -> String:
	var out: String = state.share_glyphs()
	out += "\n🌾 %d / %d" % [state.score(), state.target]
	if state.score() >= state.best:
		out += " ⭐ " + tr("HP_SEAL_BEST")
	return out

# --- the win ---

func flat_win() -> Dictionary:
	var sub := tr("HP_WIN_SUB") % [_final_score, state.best]
	if _final_score >= state.best:
		sub = tr("HP_WIN_SUB_BEST") % _final_score
	return {"faces": [], "subtitle": sub}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT + PARTY_EXTRA

## The horse kicks up its heels, the bales hop in the order they were laid,
## flowers open across the pen from the horse outward, and a pen as good as
## the best known (or any Insane one) is stamped.
func _on_solved() -> void:
	var now := _now()
	_press_cell = -1
	_end_shade()
	_tip_timer.stop()
	_toast = ""
	_solved_at = now
	_final_score = state.score()
	_expr = Face.Expr.JOY
	_kick_at = now + (0.0 if Motion.reduce else Motion.SOLVE_DELAY)
	var k := 0
	for cell: int in state.laid:
		_bale_hop[cell] = now + Motion.SOLVE_DELAY + Motion.stagger(k, Motion.SOLVE_STAGGER)
		k += 1
	_say(tr("HP_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_hud_layer.queue_redraw()
	_party()
	_busy_for(Motion.SOLVE_DELAY + BLOOM_CAP + BLOOM_TIME + 0.2)
	_redraw()

func _party() -> void:
	var now := _now()
	if state.band >= 3 or _final_score >= state.best:
		_stamp_at = now if Motion.reduce else now + Motion.SOLVE_DELAY + BLOOM_CAP * 0.5 + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
	if Motion.reduce:
		return
	_after(Motion.SOLVE_DELAY + 0.15, func() -> void:
		var field := _field_px()
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell), 30, field.size.x * 0.8)
		fx.sparkle(cell_centre(state.horse), Pal.SUN)
		fx.cue("party"))
	_after(Motion.SOLVE_DELAY + 0.6, func() -> void:
		var field := _field_px()
		fx.confetti(field.get_center(), 24, field.size.x * 0.6))

## The seal on the field's lower right, dropping in and settling.
func _draw_stamp(now: float, shown: Array) -> void:
	var field := _field_px()
	var rad := field.size.x * STAMP_R
	var insane: bool = state.band >= 3
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := field.end - Vector2(rad, rad) * 1.05
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var is_best: bool = _final_score >= state.best
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02], [tr("HP_SEAL_BEST") if is_best else tr("HP_SEAL_TUNNELS"), 0.17, 0.36]]
	else:
		lines = [[tr("HP_SEAL_BEST"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

# --- Insane's moves ---

## Spends `cost` moves. Out of moves with no pen worth submitting is the
## board lost; with one, the Submit is still the player's to press.
func _spend(cost: int, land: float) -> void:
	if max_moves <= 0 or cost <= 0:
		return
	moves_left = maxi(0, moves_left - cost)
	_moves_pill.bump(_now())
	_hud_layer.queue_redraw()
	if moves_left > 0 or is_done():
		return
	if state.closed() and state.score() >= state.target:
		return
	_lost_ever = true
	out_of_hearts = true
	_running = false
	_after(maxf(0.0, land - _now()) + (0.0 if Motion.reduce else BALE_TIME + REACH_TIME), _run_out)

func _run_out() -> void:
	if _asleep:
		return
	_asleep = true
	_press_cell = -1
	_expr = Face.Expr.SLEEPY
	_life_layer.queue_redraw()
	fx.cue("out_of_hearts")
	_tell(tr("HP_OUT"), Face.Expr.SLEEPY)
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

## The card, over the whole screen: on the host so it covers the chrome, or
## on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, [], MOVES_BONUS)
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same meadow bare, every move back, the clock from zero.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	moves = 0
	elapsed = 0.0
	checks = 0
	_running = true
	var now := _now()
	_deal()
	_clear_field(now)
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	moved.emit()
	_redraw()

## A few more moves (the card's video): once a board.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_heart_used = true
	moves_left = MOVES_BONUS
	_moves_pill.bump(_now())
	out_of_hearts = false
	_asleep = false
	_running = true
	_expr = _mood()
	fx.cue("heart_back")
	_speak()
	_hud_layer.queue_redraw()
	_life_layer.queue_redraw()
	moved.emit()

func _leave() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

# --- entrance ---

## The chrome is the host's; here the meadow pops in wide, the horse drops
## onto it a beat later and the wheat runs out from under its hooves.
func _enter() -> void:
	_opened = _now()
	_blink_at = _opened + 2.0
	for i in _lvl_to.size():
		_lvl_from[i] = 0.0
		_lvl_to[i] = 0.0
	var lag := 0.0 if Motion.reduce else Motion.ENTER_DELAY + HORSE_LAG + HORSE_LAND * 0.7
	_sync_reach(_opened + lag)
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP + HORSE_LAG + HORSE_LAND)
	if not Motion.reduce:
		_after(Motion.ENTER_DELAY + HORSE_LAG + HORSE_LAND * 0.8, func() -> void:
			fx.puff(cell_centre(state.horse) + Vector2(0.0, 0.35 * _cell), Pal.MEADOW, 4))
	fx.cue("enter")

# --- odds and ends ---

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	var gen := _gen
	get_tree().create_timer(maxf(delay, 0.0)).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0:
		return
	var now := _now()
	if now < _anim_until or now < _wheat_until:
		queue_redraw()
	# The horse's tail and the bees never stand quite still; under
	# reduce-motion the layer redraws only when something asks.
	if not Motion.reduce or now < _anim_until:
		_life_layer.queue_redraw()
	var since := now - _opened - Motion.ENTER_DELAY
	if (since < Motion.DROP_FADE + 0.1) or _moves_pill.animating(now - 0.1) \
			or now - float(_pill_bump[0]) < Motion.BUMP_TIME + 0.1 \
			or now - float(_pill_bump[1]) < Motion.BUMP_TIME + 0.1 \
			or (now - _pill_bad < 0.7) or (_toast != "" and now - _toast_at < TOAST_HOLD + 0.1):
		_hud_layer.queue_redraw()

func _redraw() -> void:
	_live_dirty = true
	queue_redraw()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## A fixed pseudo-random number per `k`, 0 to 1.
static func _hash(k: int) -> float:
	return float(posmod(hash(k * 2654435761), 1000)) / 1000.0
