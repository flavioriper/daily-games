extends "res://core/puzzle_base.gd"

## Mini Golf as a flat board: the day's course on a mown lawn, a hole at a
## time -- a felt green inside a wooden kerb, a white ball on the tee and a
## flag in the cup. Drag back anywhere and let go to putt: the further the
## pull, the harder the stroke, and the dots show where the ball will go
## first. Down the last cup the card is added up against par. The rules live
## in puzzles/minigolf_state.gd and the physics in puzzles/minigolf_sim.gd,
## which this only draws.
##
## Easy is three short holes of kerbs and blocks, Medium four with sand and
## bumper posts, Hard five with ponds and slopes. Insane is Swing Gates:
## five holes whose gates shut on every other putt, and the strokes are
## counted (the course's par and a few over, docs/agents/flat-screens.md,
## "Insane counts moves") -- the card closed before the last cup is the loss.
##
## How it is drawn. Meshes, most of them cached:
##   still -- the card's lawn, on a relayout only;
##   hole  -- the hole in play at rest (Parts.hole), built once a hole and
##            moved by transform as the next one slides in;
##   hud   -- the scorecard's pips, rebuilt when one changes;
##   live  -- the gates, the aim, the ball, its trail, the flag and the
##            ripples: small, and built only while something moves.

signal leave

const State = preload("res://puzzles/minigolf_state.gd")
const Sim = preload("res://puzzles/minigolf_sim.gd")
const Parts = preload("res://ui/faces/minigolf_parts.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Seal = preload("res://ui/flat/seal.gd")
const NapCat = preload("res://ui/faces/nap_cat.gd")
const Haptics = preload("res://core/haptics.gd")
const MovesPill = preload("res://ui/flat/moves_pill.gd")
const MovesDiagram = preload("res://ui/hud/moves_tutorial_diagram.gd")

# --- the screen, measured ---
## The card's inset round the field, the band over it the scorecard takes
## (and the row the moves pill adds on a band that counts), the card's
## corner, and the room under the field.
const INSET := 22.0
const BAND := 136.0
const PILL_ROW := 58.0
const CARD_RADIUS := 32.0
const FOOT := 16.0
## The lawn kept round a hole's green, in field units, and how much bigger
## than the whole field's scale a small hole may be drawn.
const ROOM := 6.0
const ZOOM := 1.4
## The scorecard: a pip a hole, the count line under them.
const PIP_R := 25.0
const PIP_GAP := 16.0
const PIP_FONT := 30
const PIP_Y := 48.0
const LINE_Y := 108.0
const LINE_FONT := 32
const TAG_FONT := 28
# --- the hand ---
## A pull shorter than MIN_PULL is no putt (let go there to put the aim
## down); PULL more is the hardest stroke.
const MIN_PULL := 28.0
const PULL := 300.0
## The dots of the aim are GUIDE_GAP field units apart.
const GUIDE_GAP := 2.6
## The aim takes the bulb's line when it is this near it (radians, power).
const SNAP_A := 0.07
const SNAP_U := 0.07
# --- the clocks ---
const SINK_TIME := 0.32
const CHEER_HOLD := 1.25
const SWAP_TIME := 0.6
const WET_TIME := 0.85
const GATE_TIME := 0.32
const POST_TIME := 0.3
# --- the sounds (docs/agents/sound.md, the cozy rules) ---
## The softest putt and the softest knock on a kerb, in dB under the hardest.
## They were -8 and -12; the files are 6 dB under the ones they replaced
## (putt -13 where it was -7, wall -15 where it was -9), and a kiss on the
## kerb at -12 read -28 dB on a phone; at -5 it reads -22.
const PUTT_SOFT_DB := -4.0
const WALL_SOFT_DB := -5.0
## A tick or a breath that repeats is never the same sound twice (the rim,
## the sand, the gates; they were 1.0 every time). The kerb by its speed
## (0.9 to 1.2, five semitones), the putt by its power (0.92 to 1.14) and a
## post by its number (1.0 to 1.12) were inside five semitones already.
const TICK_VARY := Vector2(0.94, 1.06)
const FLAG_NEAR := 17.0
## How often the ball at rest breathes a ring out.
const BECKON := 2.4
const FLAG_RATE := 9.0
const TRAIL := 9
const STICKER_LIFE := 1.5
const WIN_HOLD := 1.2
const PARTY_AT := 0.6
const CHEERS := 6
const CAT_PX := 0.15
const CAT_POP := 0.22
const CAT_HOPS := 3
const CAT_HOP_TIME := 0.3
const CAT_HOP_H := 0.4
const CAT_SETTLE := 0.25
const CURL_AT := 1.7
const STAMP_AT := 1.4
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.13
const STAMP_TILT := -0.22
const DUSK := Color(0.74, 0.76, 0.92)
const DUSK_TIME := 0.8
const CARD_AFTER := 1.2
const CARD_AFTER_STILL := 0.3
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
## What the card's video buys on a band that counts strokes.
const MOVES_BONUS := 3
const TOAST_HOLD := 2.4
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32

const TIPS := ["GF_TIP_AIM", "GF_TIP_BANK", "GF_TIP_PAR"]
const TIPS_SAND := ["GF_TIP_AIM", "GF_TIP_SAND", "GF_TIP_PAR"]
const TIPS_WATER := ["GF_TIP_AIM", "GF_TIP_WATER", "GF_TIP_SLOPE"]
const TIPS_GATES := ["GF_TIP_STROKES", "GF_TIP_GATES", "GF_TIP_WATER"]

## What the phone does (docs/agents/haptics.md). The hand does one thing, it
## lets the ball go: a tap as it leaves (`putt`). What the ball then does is
## the green's and is heard, not chosen -- kerbs, posts, sand, the rim are
## echoes of their sounds -- but for what the putt was for: a bump as it
## drops (`sink`), a warn as it goes in the pond (`splash`). The aim taking
## the bulb's line is a tick (`_pull`, by `fx.buzz`), the bulb itself a
## good, Reset a tap. Out of strokes is the lose. The last cup is the win,
## knocked as the ball drops (`_on_sunk`, by `fx.buzz`); the seal knocks as
## it lands (`_party`). The aim, the guide, the gates' swing, the flag, the
## words and the party say nothing.
const HAPTICS := {
	"putt": Haptics.TAP,
	"sink": Haptics.BUMP,
	"splash": Haptics.WARN,
	"hint": Haptics.GOOD,
	"reset": Haptics.TAP,
	"heart_back": Haptics.GOOD,
	"out_of_hearts": Haptics.LOSE,
}

var _state = State.new()
var fx: Node2D

## "aim" (the ball at rest), "roll", "wet" (fished out of the pond), "sunk"
## (down, the cheer), "swap" (the next hole sliding in), "won", "asleep".
var _phase := "aim"
var _acc := 0.0
var _aiming := false
var _from := Vector2.ZERO
var _aim := -PI * 0.5
var _power := 0.0
var _snapped := false
var _guide_pts := PackedVector2Array()
var _guide_for := Vector2(INF, INF)
## The bulb's line: {"a", "u", "pts"}; {} when there is none.
var _ghost := {}
var _think := {}
var _trail: Array = []
var _opened := 0.0
var _hole_at := 0.0
var _sunk_at := -100.0
var _swap_at := -100.0
var _wet_at := -100.0
var _wet_from := Vector2.ZERO
var _gate_at := -100.0
var _gate_was := 0
var _post_at := PackedFloat32Array()
var _pip_at := PackedFloat32Array()
var _flag_lift := 0.0
var _solved_at := -1.0
var _stickers: Array = []
var _log := ""
var _tries := 1
var _flawless := false
var _won := false
## The hole in play's bounds, and where the hole before it stood.
var _box := Rect2(0.0, 0.0, 82.0, 116.0)
var _old_origin := Vector2.ZERO

## Read by the host and the out-of-hearts card; the hearts are asleep
## (State.HEARTS_BY) and Insane counts strokes instead.
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var moves_left := 0
var max_moves := 0
var _moves_pill := MovesPill.new()
var _heart_used := false
var _lost_ever := false
var _heart_card: Control
var _dusk_tw: Tween

var _party_at := INF
var _cat: Control
var _cat_at := INF
var _cat_curled := false
var _stamp_at := INF
var _seal_mesh: ArrayMesh

var _still: ArrayMesh
var _hole: ArrayMesh
var _old_hole: ArrayMesh
var _hud: ArrayMesh
var _hud_for := ""
var _live: ArrayMesh
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""
## A canvas command holds a mesh by RID: what the last _draw handed over.
var _shown: Array = []
var _toast := ""
var _toast_at := -100.0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _anim_until := 0.0

func puzzle_id() -> String: return "minigolf"
func title() -> String: return "Mini Golf"

## The rules, then what the band adds: sand and posts (Medium), ponds and
## slopes (Hard), the gates and the count of strokes (Insane).
func rules() -> String:
	var out := tr("GF_RULES")
	if _state.band >= 1:
		out += "\n\n" + tr("GF_RULES_SAND")
	if _state.band >= 2:
		out += "\n\n" + tr("GF_RULES_WATER")
	if _state.band >= 3:
		out += "\n\n" + tr("GF_RULES_GATES")
	if max_moves > 0:
		out += "\n\n" + tr("GF_RULES_STROKES") % max_moves
	return out

## The how-to-play pages, band-aware: the putt, the bank shot, the card and
## par, then what the band adds, the bulb (bands with hints) and Insane's
## count. Each page is the board itself on a hand-made hole, playing the
## lesson (ui/hud/minigolf_tutorial_diagram.gd).
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/minigolf_tutorial_diagram.gd")
	var band: int = _state.band
	var hints: int = State.hints_for(band)
	var steps := [[Diagram.Lesson.PUTT, "HTP_GF_PUTT", tr("HTP_GF_PUTT_BODY")],
		[Diagram.Lesson.BANK, "HTP_GF_BANK", tr("HTP_GF_BANK_BODY")],
		[Diagram.Lesson.CARD, "HTP_GF_CARD", tr("HTP_GF_CARD_BODY")]]
	if band >= 1:
		steps.append([Diagram.Lesson.SAND, "HTP_GF_SAND", tr("HTP_GF_SAND_BODY")])
	if band >= 2:
		steps.append([Diagram.Lesson.WATER, "HTP_GF_WATER", tr("HTP_GF_WATER_BODY")])
	if band >= 3:
		steps.append([Diagram.Lesson.GATES, "HTP_GF_GATES", tr("HTP_GF_GATES_BODY")])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_GF_HINT_BODY_ONE") if hints == 1 else tr("HTP_GF_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	if max_moves > 0:
		var page: Dictionary = MovesDiagram.page(self, max_moves, true)
		page["body"] = tr("HTP_GF_MOVES_BODY") % max_moves
		pages.append(page)
	return pages

func _tips() -> Array:
	if _state.band >= 3:
		return TIPS_GATES
	if _state.band >= 2:
		return TIPS_WATER
	if _state.band >= 1:
		return TIPS_SAND
	return TIPS

## The bulb only: a putt cannot be taken back, and Reset is the host's.
## Insane counts strokes and has no bulb either.
func capabilities() -> Array[String]:
	if _state.band >= 3:
		return []
	return ["hint"]

## Reset waits while the ball rolls or the bulb is looking.
func can_reset() -> bool:
	return _phase == "aim" and _think.is_empty() and not out_of_hearts

func busy() -> bool:
	return _phase in ["roll", "wet", "sunk", "swap"] or not _think.is_empty()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	fx.haptics = HAPTICS
	add_child(fx)
	resized.connect(_layout)
	solved.connect(_on_solved)

func _exit_tree() -> void:
	_close_card()
	_drop_think()

func _drop_think() -> void:
	if not _think.is_empty():
		WorkerThreadPool.wait_for_task_completion(int(_think.id))
		_think = {}

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_hud = null
		queue_redraw()

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_close_card()
	_drop_think()
	_state.build(rng, difficulty)
	_begin()

## Everything a course starts from, the state already laid.
func _begin() -> void:
	max_hearts = State.hearts_for(_state.band)
	hearts = max_hearts
	max_moves = _state.moves_budget()
	moves_left = max_moves
	out_of_hearts = false
	_heart_used = false
	_lost_ever = false
	_flawless = false
	_won = false
	_tries = 1
	_log = ""
	_reset_party()
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	_opened = _now()
	_fresh(_opened)
	_layout()
	fx.cue("enter")
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)

## The course from its first tee.
func _fresh(t: float) -> void:
	_pip_at = PackedFloat32Array()
	_pip_at.resize(_state.holes.size())
	_pip_at.fill(-100.0)
	_stickers = []
	_solved_at = -1.0
	_old_hole = null
	_swap_at = -100.0
	_fresh_hole(t)

## The hole in play, the ball on its tee.
func _fresh_hole(t: float) -> void:
	_phase = "aim"
	_acc = 0.0
	_aiming = false
	_power = 0.0
	_snapped = false
	_guide_pts = PackedVector2Array()
	_guide_for = Vector2(INF, INF)
	_ghost = {}
	_trail = []
	_hole_at = t
	_sunk_at = -100.0
	_wet_at = -100.0
	_gate_at = -100.0
	_gate_was = 0
	_flag_lift = 0.0
	var posts: int = _state.sim.posts.size()
	_post_at = PackedFloat32Array()
	_post_at.resize(posts)
	_post_at.fill(-100.0)
	_box = _bounds()
	_hole = null
	_hud = null
	_live = null
	_busy_for(1.2)

## The hole's green, kerb and all, in field units.
func _bounds() -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var cells: PackedByteArray = _state.sim.cells
	for i in cells.size():
		if cells[i] == 0:
			continue
		var r := Sim.cell_rect(i)
		lo = lo.min(r.position)
		hi = hi.max(r.end)
	if lo.x > hi.x:
		return Rect2(Vector2.ZERO, Vector2(Sim.W, Sim.H))
	return Rect2(lo, hi - lo).grow(ROOM)

# --- layout ---

func _band() -> float:
	return BAND + (PILL_ROW if max_moves > 0 else 0.0)

## The card under the band: where a hole stands.
func _area() -> Rect2:
	return Rect2(Vector2(INSET, _band()), Vector2(size.x - 2.0 * INSET, size.y - _band() - FOOT))

## Pixels a field unit: a hole fills the card as far as ZOOM lets a small
## one grow, so a short hole is a big one.
func _s() -> float:
	var area := _area()
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return 0.0
	var whole := minf(area.size.x / Sim.W, area.size.y / Sim.H)
	return minf(whole * ZOOM, minf(area.size.x / _box.size.x, area.size.y / _box.size.y))

## The hole's own top-left: every hole mesh and the live mesh are built
## from it, so the swap moves them by transform.
func _hole_origin() -> Vector2:
	return _area().get_center() - _box.get_center() * _s()

## A field point of the hole in play, on the card.
func _pt(v: Vector2) -> Vector2:
	return _hole_origin() + v * _s()

func card_height(available: float) -> float:
	return available

func card_centred() -> bool:
	return true

func _layout() -> void:
	_still = null
	_hole = null
	_old_hole = null
	_hud = null
	_live = null
	_seal_mesh = null
	queue_redraw()

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

# --- the frame loop ---

func _process(delta: float) -> void:
	super(delta)
	if _s() <= 0.0 or _state.holes.is_empty():
		return
	var t := _now()
	if _phase == "roll":
		_acc += delta
		var events: Array = []
		var n := 0
		var rolling := true
		while _acc >= Sim.DT and n < 16 and rolling:
			rolling = _state.step(events)
			_acc -= Sim.DT
			n += 1
		_trail.append(_state.sim.p)
		if _trail.size() > TRAIL:
			_trail.pop_front()
		_handle(events, t)
	elif _phase == "wet" and t - _wet_at >= (0.0 if Motion.reduce else WET_TIME):
		_phase = "aim"
		_after_putt(t)
	elif _phase == "sunk" and not _won and t - _sunk_at >= (Motion.REDUCED_TIME if Motion.reduce else CHEER_HOLD):
		_swap(t)
	elif _phase == "swap" and t - _swap_at >= (0.0 if Motion.reduce else SWAP_TIME):
		_phase = "aim"
		_old_hole = null
	_tick_flag(t, delta)
	if not _think.is_empty() and WorkerThreadPool.is_task_completed(int(_think.id)):
		WorkerThreadPool.wait_for_task_completion(int(_think.id))
		var box: Dictionary = _think.box
		_think = {}
		if _phase == "aim" and not _done and box.has("shot"):
			_show_hint(box.shot)
	if _cat_at < INF:
		_place_cat(t)
	for i in range(_stickers.size() - 1, -1, -1):
		if t - float(_stickers[i].at) > float(_stickers[i].life):
			_stickers.remove_at(i)
	if _moving(t):
		_live = null
		queue_redraw()

## Whether anything on the card is in motion this frame.
func _moving(t: float) -> bool:
	if _phase in ["roll", "wet", "sunk", "swap"] or _aiming or not _think.is_empty():
		return true
	if t < _anim_until or not _stickers.is_empty():
		return true
	if _toast != "" and t - _toast_at < TOAST_HOLD + 0.1:
		return true
	if max_moves > 0 and _moves_pill.animating(t - 0.1):
		return true
	if t >= _stamp_at and t - _stamp_at < 1.0:
		return true
	# the flag flutters on; a still card under reduce motion draws nothing
	return not Motion.reduce and not _won

## The flag is lifted out of the cup while the ball rolls near it.
func _tick_flag(_t: float, delta: float) -> void:
	var sim = _state.sim
	var near: bool = _phase == "roll" and sim.p.distance_to(sim.cup) < FLAG_NEAR
	var want := 1.0 if near else 0.0
	_flag_lift = want if Motion.reduce else lerpf(_flag_lift, want, 1.0 - exp(-FLAG_RATE * delta))

## What the ball did this frame.
func _handle(events: Array, t: float) -> void:
	var s := _s()
	for e: Array in events:
		var at: Vector2 = e[1]
		match String(e[0]):
			"wall", "gate":
				var hard := clampf(float(e[2]) / 90.0, 0.0, 1.0)
				fx.cue("wall", 0.9 + 0.3 * hard, lerpf(WALL_SOFT_DB, 0.0, hard))
				if hard > 0.25:
					fx.puff(_pt(at), Pal.GF_KERB_HI, 2)
			"post":
				_post_at[int(e[2])] = t
				fx.cue("post", 1.0 + 0.06 * float(int(e[2]) % 3))
				fx.ring(_pt(at), 3.4 * s, Pal.GF_POST_HI, 0.35)
			"sand":
				fx.cue("sand", randf_range(TICK_VARY.x, TICK_VARY.y))
				fx.puff(_pt(at), Pal.GF_SAND, 4)
			"lip":
				fx.cue("lip", randf_range(TICK_VARY.x, TICK_VARY.y))
				_float_word("GF_LIP", at)
			"splash":
				_on_splash(at, t)
			"sunk":
				_on_sunk(t)
			"stop":
				_on_stop(t)

func _on_stop(t: float) -> void:
	_phase = "aim"
	_after_putt(t)

## The ball is at rest again: the gates swap, and a count that has run out
## ends the course.
func _after_putt(t: float) -> void:
	var sim = _state.sim
	if sim.gate_phase.size() > 0 and sim.parity != _gate_was:
		_gate_was = sim.parity
		_gate_at = t
		fx.cue("gate", randf_range(TICK_VARY.x, TICK_VARY.y))
		_busy_for(GATE_TIME + 0.1)
	_guide_for = Vector2(INF, INF)
	_busy_for(0.3)
	if max_moves > 0 and moves_left <= 0 and not is_done():
		_moves_out()
		return
	moved.emit()

func _on_splash(at: Vector2, t: float) -> void:
	_phase = "wet"
	_wet_at = t
	_wet_from = at
	_trail = []
	fx.cue("splash")
	fx.puff(_pt(at), Pal.GF_WATER_HI, 6)
	_tell("GF_WET", Face.Expr.WORRIED)

func _on_sunk(t: float) -> void:
	var sim = _state.sim
	_phase = "sunk"
	_sunk_at = t
	_trail = []
	var i: int = _state.index
	var n: int = sim.strokes
	var d: int = n - _state.par()
	_pip_at[i] = t
	_hud = null
	fx.cue("sink")
	var at := _pt(sim.cup)
	fx.ring(at, Sim.CUP_R * _s() * 2.2, Pal.SUN, 0.5)
	fx.sparkle(at, Pal.SUN_RAY)
	var word := "GF_IN"
	var col: Color = Pal.PAPER
	var cue_name := "bogey"
	var glyph := "🔴"
	if n == 1:
		word = "GF_ACE"
		col = Pal.SUN_RAY
		cue_name = "ace"
		glyph = "⭐"
	elif d <= -2:
		word = "GF_EAGLE"
		col = Pal.SUN_RAY
		cue_name = "birdie"
		glyph = "🟢"
	elif d == -1:
		word = "GF_BIRDIE"
		col = Pal.SUN_RAY
		cue_name = "birdie"
		glyph = "🟢"
	elif d == 0:
		word = "GF_PAR"
		col = Color("d9f5c9")
		cue_name = "par"
		glyph = "⚪"
	elif d == 1:
		word = "GF_BOGEY"
		col = Pal.FLOWER_TILE
		glyph = "🟠"
	elif d == 2:
		word = "GF_DOUBLE"
		col = Pal.FLOWER_TILE
	_log += glyph
	var last: bool = _state.last_hole()
	get_tree().create_timer(0.0 if Motion.reduce else SINK_TIME).timeout.connect(func():
		if is_inside_tree() and (_phase == "sunk" or _won):
			# The last cup's word is shown and not sounded: `solved` began on
			# the frame the ball dropped and `party` is 0.28 s off, and a third
			# phrase between them is three tunes at once (it was sounded always).
			if not _won:
				fx.cue(cue_name)
			_sticker(tr(word), col, n == 1 or d < 0))
	if n == 1 and not Motion.reduce:
		fx.confetti(Vector2(size.x * 0.5, _band() + 20.0), 24, size.x * 0.8)
	_say(tr(word), Face.Expr.JOY if d <= 0 else Face.Expr.HAPPY)
	if last:
		fx.buzz(Haptics.WIN)
		check_solved()
	elif max_moves > 0 and moves_left <= 0:
		# down, but the card is closed with holes still to play
		_moves_out()
	moved.emit()

## Whatever is in motion played out at once, for a harness with no seconds
## to wait: the roll to its end, the cheer and the swap skipped.
func settle_now() -> void:
	var t := _now()
	for k in 8:
		if _phase == "roll":
			var events: Array = []
			while _state.step(events):
				pass
			_handle(events, t)
		elif _phase == "wet":
			_phase = "aim"
			_after_putt(t)
		elif _phase == "sunk" and not _won and not _state.last_hole() and not out_of_hearts:
			_swap(t)
		elif _phase == "swap":
			_phase = "aim"
			_old_hole = null
		else:
			break

## The next hole slides in from the right as this one leaves to the left.
func _swap(t: float) -> void:
	if _state.last_hole():
		return
	_old_hole = _hole
	_old_origin = _hole_origin()
	if not _state.next_hole():
		return
	_fresh_hole(t)
	_phase = "swap"
	_swap_at = t
	fx.cue("next")
	_say(tr("GF_NEXT") % [_state.index + 1, _state.par()], Face.Expr.HAPPY)
	moved.emit()

# --- the words ---

## A word of praise popped over the green.
func _sticker(text: String, col: Color, big: bool) -> void:
	_stickers.append({"text": text, "col": col, "at": _now(), "life": STICKER_LIFE, "px": 92 if big else 76,
		"pos": Vector2(size.x * 0.5, _band() + (size.y - _band()) * 0.36), "tilt": -0.06})

## A small word by the ball.
func _float_word(key: String, at: Vector2) -> void:
	_stickers.append({"text": tr(key), "col": Pal.PAPER, "at": _now(), "life": 0.9, "px": 44,
		"pos": _pt(at) + Vector2(0.0, -46.0), "tilt": 0.0})

func _draw_stickers(t: float, seen: float) -> void:
	var font: Font = CozyTheme.display(700)
	for st: Dictionary in _stickers:
		var e := t - float(st.at)
		var life: float = st.life
		if e < 0.0 or e > life:
			continue
		var px: int = st.px
		var text: String = st.text
		var k := 1.0 if Motion.reduce else Motion.pop_in_scale(e, 0.26).x
		var fade := clampf((life - e) / 0.3, 0.0, 1.0) * seen
		var rise := 0.0 if Motion.reduce else -26.0 * e
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		# a long word in another language is lettered smaller, never off the card
		var fit := minf(1.0, (size.x - 60.0) / maxf(w, 1.0))
		draw_set_transform(Vector2(st.pos) + Vector2(0.0, rise), float(st.tilt), Vector2(k, k) * fit)
		var o := Vector2(-w * 0.5, px * 0.36)
		draw_string_outline(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(px * 0.3), Color(Color("fffaf0"), fade))
		draw_string_outline(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(px * 0.13), Color(Pal.TEXT, fade))
		draw_string(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(st.col, fade))
	draw_set_transform(Vector2.ZERO)

# --- Insane's strokes ---

## `cost` strokes off Insane's count.
func _spend(cost: int, _land: float) -> void:
	if max_moves <= 0 or cost <= 0:
		return
	moves_left = maxi(0, moves_left - cost)
	_moves_pill.bump(_now())

## Out of strokes before the last cup: the course is lost (`out_of_hearts`
## is the name the host and the card read).
func _moves_out() -> void:
	_lost_ever = true
	out_of_hearts = true
	_log += "💔"
	_run_out()

## Dusk falls on the lawn and the out-of-moves card comes up.
func _run_out() -> void:
	_phase = "asleep"
	_running = false
	_aiming = false
	fx.cue("out_of_hearts")
	_say(tr("GF_ASLEEP"), Face.Expr.SLEEPY)
	_dusk_toward(DUSK)
	moved.emit()
	get_tree().create_timer(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER).timeout.connect(_open_card)

func _dusk_toward(tint: Color) -> void:
	Motion.stop(_dusk_tw)
	if Motion.reduce:
		modulate = tint
		return
	_dusk_tw = create_tween()
	_dusk_tw.tween_property(self, "modulate", tint, DUSK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _open_card() -> void:
	if not is_inside_tree() or not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, [], MOVES_BONUS)
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the course from its first tee, the whole count back, the clock
## and the strokes from zero. Hints spent stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	_state.restart()
	moves_left = max_moves
	out_of_hearts = false
	_tries += 1
	var t := _now()
	_fresh(t)
	_log += "·"
	elapsed = 0.0
	moves = 0
	_running = true
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	fx.cue("reset")
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	moved.emit()

## The card's video, once a day: MOVES_BONUS more strokes on the course as
## it stands -- the ball where it lies, or on the next tee.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	var t := _now()
	_heart_used = true
	moves_left = MOVES_BONUS
	_moves_pill.bump(t)
	out_of_hearts = false
	_running = true
	_phase = "aim"
	if _state.sim.sunk:
		_phase = "sunk"
		_sunk_at = t - CHEER_HOLD
	_log += "·"
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	_say(MovesPill.line(self, moves_left), Face.Expr.HAPPY)
	moved.emit()

func _leave_board() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

# --- the party ---

func _reset_party() -> void:
	_party_at = INF
	_cat_at = INF
	_cat_curled = false
	_stamp_at = INF
	_seal_mesh = null
	if is_instance_valid(_cat):
		_cat.queue_free()
	_cat = null

## The day's own number, so a day always says the same wisdom.
func _day_hash() -> int:
	var cells: Array = []
	for h: Dictionary in _state.holes:
		cells.append(h.get("cells", []))
	return absi(hash(cells))

## After the win: confetti, the nap cat strolling onto the lawn to curl up,
## a bit of clubhouse wisdom, and the seal when the round earned one (a
## flawless card, or any Insane course).
func _party() -> void:
	var t := _now()
	_party_at = t + (0.0 if Motion.reduce else PARTY_AT)
	_cat_at = _party_at
	if _flawless or _state.band >= 3:
		_stamp_at = t if Motion.reduce else _party_at + STAMP_AT
		_seal_mesh = null
		get_tree().create_timer(maxf(0.01, _stamp_at - t)).timeout.connect(func():
			if is_inside_tree():
				fx.cue("stamp"))
		if not Motion.reduce:
			get_tree().create_timer(_stamp_at - t + STAMP_DROP).timeout.connect(func():
				if is_inside_tree():
					fx.buzz(Haptics.THUD))
	get_tree().create_timer(PARTY_AT + 0.9).timeout.connect(func():
		if is_inside_tree():
			_say(tr("GF_CHEER_%d" % posmod(_day_hash(), CHEERS)), Face.Expr.JOY))
	if Motion.reduce:
		return
	get_tree().create_timer(PARTY_AT).timeout.connect(func():
		if not is_inside_tree():
			return
		fx.cue("party")
		fx.confetti(Vector2(size.x * 0.5, _band() + 20.0), 30, size.x * 0.9))

func _cat_px() -> float:
	return size.x * CAT_PX

## Where the cat curls up: on the lawn at the foot of the card.
func _cat_spot() -> Vector2:
	return Vector2(size.x * 0.82, size.y - _cat_px() * 0.55)

func _cat_start() -> Vector2:
	return Vector2(size.x + _cat_px() * 0.6, size.y - _cat_px() * 0.55)

func _place_cat(t: float) -> void:
	if t < _cat_at or _s() <= 0.0:
		return
	if not is_instance_valid(_cat):
		_cat = NapCat.new()
		_cat.name = "Cat"
		_cat.need = 0
		_cat.z_index = 3
		_cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cat.expression = Face.Expr.JOY
		add_child(_cat)
		_cat.set_idle(true)
		_cat_curled = false
	var px := _cat_px()
	if _cat.size.x != px:
		_cat.size = Vector2(px, px)
		_cat.pivot_offset = _cat.size * Vector2(0.5, 0.85)
	if _cat_curled:
		_cat.position = _cat_spot() - _cat.size * Vector2(0.5, 0.8)
		return
	var e := t - _cat_at
	var spot := _cat_spot()
	var start := _cat_start()
	var at := spot
	var sc := Vector2.ONE
	var walk := CAT_POP + CAT_HOPS * CAT_HOP_TIME
	if Motion.reduce or e >= CURL_AT:
		_cat_curled = true
		_cat.expression = Face.Expr.SLEEPY
		_cat.scale = Vector2.ONE
		_cat.position = spot - _cat.size * Vector2(0.5, 0.8)
		if not Motion.reduce and e < CURL_AT + 1.0:
			fx.cue("purr")
		return
	elif e < CAT_POP:
		at = start
		sc = Motion.pop_in_scale(e, CAT_POP)
	elif e < walk:
		var hh := (e - CAT_POP) / CAT_HOP_TIME
		var n := int(hh)
		var u := hh - float(n)
		var from := start.lerp(spot, float(n) / CAT_HOPS)
		var to := start.lerp(spot, float(n + 1) / CAT_HOPS)
		at = from.lerp(to, u) - Vector2(0.0, 4.0 * u * (1.0 - u) * CAT_HOP_H * px)
		var q := 0.1 * sin(u * PI)
		sc = Vector2(1.0 - q, 1.0 + q)
	elif e < walk + CAT_SETTLE:
		var u := (e - walk) / CAT_SETTLE
		var q := 0.14 * sin(u * PI)
		sc = Vector2(1.0 + q, 1.0 - q)
	_cat.position = at - _cat.size * Vector2(0.5, 0.8)
	_cat.scale = sc

## The seal over the middle of the card, dropping in and settling, its words
## over it: Flawless; on Insane "Insane" over Flawless or Swing Gates, on
## the night seal.
func _draw_stamp(t: float, shown: Array) -> void:
	var rad := size.x * STAMP_R
	var insane: bool = _state.band >= 3
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := t - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := Vector2(size.x * 0.5, _band() + (size.y - _band()) * 0.6)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	draw_set_transform_matrix(xf)
	draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless else tr("GF_GATES_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(self, rad, lines)
	draw_set_transform_matrix(Transform2D.IDENTITY)

# --- the drawing ---

func _draw() -> void:
	if _state.holes.is_empty() or _s() <= 0.0:
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := 1.0 if Motion.reduce else Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var grow := 1.0 if Motion.reduce else Motion.wide_pop_scale(since)
	var mid := size * 0.5
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var tint := Color(1.0, 1.0, 1.0, seen)
	var shown: Array = []
	if _still == null:
		_still = _build_still()
	_put(_still, xf, tint, shown)
	# the hole in play, and the one leaving while the next slides in
	var slide := 0.0
	if _phase == "swap" and not Motion.reduce:
		var u := clampf((t - _swap_at) / SWAP_TIME, 0.0, 1.0)
		slide = 1.0 - u * u * (3.0 - 2.0 * u)
	if _hole == null:
		var b := Face.Builder.new()
		Parts.hole(b, _state.sim, Vector2.ZERO, _s())
		_hole = b.mesh()
	if slide > 0.0 and _old_hole != null:
		var gone := Transform2D(0.0, _old_origin + Vector2(-(1.0 - slide) * size.x, 0.0))
		_put(_old_hole, xf * gone, tint, shown)
	var here := xf * Transform2D(0.0, _hole_origin() + Vector2(slide * size.x, 0.0))
	# no fade: a hole is layers in one mesh, and a faint one shows them all
	var hole_tint := tint
	_put(_hole, here, hole_tint, shown)
	if _live == null:
		_live = _build_live(t)
	_put(_live, here, hole_tint, shown)
	_draw_hud(t, xf, tint, shown)
	if max_moves > 0 and not is_done():
		_moves_pill.draw(self, xf * Vector2(size.x * 0.5, 34.0), moves_left, t)
	_draw_stickers(t, seen)
	if t >= _stamp_at:
		_draw_stamp(t, shown)
	_draw_toast(t, shown)
	_shown = shown

func _put(m: ArrayMesh, xf: Transform2D, tint: Color, shown: Array) -> void:
	if m == null:
		return
	draw_mesh(m, null, xf, tint)
	shown.append(m)

## The card's lawn. None of it ever moves.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	Parts.lawn(b, size, CARD_RADIUS - 2.0, [Rect2(Vector2.ZERO, Vector2(size.x, _band()))])
	return b.mesh()

## How shut gate `g` is drawn: it swings for GATE_TIME after the ball stops.
func _gate_shut(g: int, t: float) -> float:
	var sim = _state.sim
	var want := 1.0 if sim.gate_shut(g) else 0.0
	if Motion.reduce:
		return want
	var u := clampf((t - _gate_at) / GATE_TIME, 0.0, 1.0)
	u = Motion.back_out(u)
	return lerpf(1.0 - want, want, u)

## Everything on the green that moves, from the hole's own top-left: the
## gates, a post just struck, the bulb's line, the aim, the trail, the
## ripples, the ball and the flag.
func _build_live(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _s()
	var sim = _state.sim
	var gates: int = sim.gate_phase.size()
	for g in gates:
		var ga: Vector2 = sim.gate_a[g]
		var gb: Vector2 = sim.gate_b[g]
		Parts.gate(b, ga * s, gb * s, _gate_shut(g, t), s)
	if not Motion.reduce:
		for k in _post_at.size():
			var e := t - _post_at[k]
			if e >= 0.0 and e < POST_TIME:
				var q: Vector3 = sim.posts[k]
				Parts.post(b, Vector2(q.x, q.y) * s, q.z * s, Motion.bump_scale(e, 0.3, POST_TIME))
	var ball: Vector2 = sim.p
	var aimable := _phase == "aim" and not _done
	# the bulb's line, the whole way, under the player's own
	if aimable and not _ghost.is_empty():
		var pts: PackedVector2Array = _ghost.pts
		var n := pts.size()
		for i in n:
			b.disc(pts[i] * s, (0.62 if i % 2 == 0 else 0.5) * s, Color(Pal.GF_HINT, 0.95))
		if n > 0:
			b.stroke(Face.Builder.ring(pts[n - 1] * s, 1.5 * s, 1.5 * s), 0.4 * s, Pal.GF_HINT, true)
	if aimable and _aiming and _power > 0.0:
		_draw_aim(b, ball, s)
	elif aimable and not _aiming and not Motion.reduce and _think.is_empty():
		# the ball asks to be played: a soft ring breathes out from it
		var beat := fposmod(t - _hole_at, BECKON)
		if beat < BECKON * 0.55:
			var u := beat / (BECKON * 0.55)
			var r := Sim.BALL_R * s * (1.3 + 1.5 * u)
			b.stroke(Face.Builder.ring(ball * s, r, r), (0.45 - 0.25 * u) * s, Color(Pal.GF_BALL, 0.6 * (1.0 - u)), true)
	# the trail
	var m := _trail.size()
	for i in m:
		var u := float(i + 1) / float(m + 1)
		b.disc(Vector2(_trail[i]) * s, Sim.BALL_R * s * (0.35 + 0.5 * u), Color(Pal.GF_BALL, 0.28 * u))
	# the pond's ripples, and the ball handed back to its lie
	var ball_scale := 1.0
	var ball_seen := true
	if _phase == "wet" and not Motion.reduce:
		var u := clampf((t - _wet_at) / WET_TIME, 0.0, 1.0)
		for k in 3:
			var ru := u * 1.4 - float(k) * 0.2
			if ru > 0.0 and ru < 1.0:
				var r := (1.5 + 5.0 * ru) * s
				b.stroke(Face.Builder.ring(_wet_from * s, r, r * 0.8), (0.5 - 0.3 * ru) * s, Color(Pal.GF_WATER_HI, 1.0 - ru), true)
		ball_seen = u > 0.55
		if ball_seen:
			ball_scale = Motion.pop_in_scale((u - 0.55) * WET_TIME, 0.22).x
	# the ball comes onto a new tee with a pop
	var since := t - _hole_at - (SWAP_TIME * 0.7 if _swap_at == _hole_at else Motion.ENTER_DELAY + 0.1)
	if not Motion.reduce and since < 0.3:
		ball_scale *= Motion.pop_in_scale(since, 0.22).x
	var sink := 0.0
	if sim.sunk:
		sink = 1.0 if Motion.reduce else clampf((t - _sunk_at) / SINK_TIME, 0.0, 1.0)
	if ball_seen and ball_scale > 0.02 and sink < 1.0:
		Parts.ball(b, ball * s, Sim.BALL_R * s * ball_scale, sink)
	# the flag: lifted and faint while the ball rolls near, hopping when it drops
	var wave := 0.0 if Motion.reduce else t * 3.2
	var hop := 0.0
	var cheer := t - _sunk_at - SINK_TIME
	if sim.sunk and cheer > 0.0 and not Motion.reduce:
		hop = Motion.hop_lift(cheer, -1.8 * s, 0.34)
		wave = t * 9.0
	var cup: Vector2 = sim.cup * s + Vector2(0.0, hop)
	Parts.flag(b, cup, 9.5 * s, wave, _flag_lift, 1.0 - 0.65 * _flag_lift)
	return b.mesh() if not b.verts.is_empty() else null

## The aim: the dots where the ball will go, and the band pulled back behind
## the ball the other way.
func _draw_aim(b: Face.Builder, ball: Vector2, s: float) -> void:
	var key := Vector2(_aim, _power)
	if key != _guide_for:
		_guide_for = key
		_guide_pts = _state.sim.guide(_aim, _power, State.guide_for(_state.band), GUIDE_GAP)
	var n := _guide_pts.size()
	var gold := _snapped
	for i in n:
		var u := float(i) / float(maxi(n - 1, 1))
		var col := Pal.GF_HINT if gold else Pal.GF_GUIDE
		b.disc(_guide_pts[i] * s, (0.72 - 0.3 * u) * s, Color(col, 0.95 - 0.45 * u))
	var back := Vector2.from_angle(_aim + PI)
	var side := Vector2(-back.y, back.x)
	var reach := (3.0 + 11.0 * _power) * s
	var root := ball * s + back * Sim.BALL_R * s * 1.2
	var grip := ball * s + back * (Sim.BALL_R * s + reach)
	var hot := Pal.SUN.lerp(Color("ef6a4c"), clampf((_power - 0.6) / 0.4, 0.0, 1.0))
	b.fan(PackedVector2Array([root + side * 0.5 * s, grip + side * 1.25 * s, grip - side * 1.25 * s, root - side * 0.5 * s]),
		Color(hot, 0.85))
	b.disc(grip, 1.7 * s, Color(Pal.SURFACE, 0.95))
	b.disc(grip, 1.15 * s, hot)

## Where the scorecard's band starts.
func _hud_top() -> float:
	return _band() - BAND

## The scorecard over the green: a pip a hole with its strokes, the running
## score against par beside them, and the hole's line under them.
func _draw_hud(t: float, xf: Transform2D, tint: Color, shown: Array) -> void:
	var holes: int = _state.holes.size()
	var top := _hud_top()
	var step := 2.0 * PIP_R + PIP_GAP
	var wide := step * float(holes) - PIP_GAP
	var x0 := (size.x - wide) * 0.5 + PIP_R
	var y := top + PIP_Y
	var bumping := false
	for i in holes:
		if not Motion.reduce and t - _pip_at[i] < Motion.BUMP_TIME + SINK_TIME:
			bumping = true
	var index: int = _state.index
	var key := "%d|%s|%d|%s|%d" % [index, str(_state.card), int(size.x), str(_state.sim.sunk), int(top)]
	if _hud == null or _hud_for != key or bumping:
		var b := Face.Builder.new()
		for i in holes:
			var at := Vector2(x0 + step * float(i), y)
			var done_hole: bool = i < index or (i == index and _state.sim.sunk)
			var k := 1.0
			if bumping and done_hole:
				k = Motion.bump_scale(t - _pip_at[i] - SINK_TIME)
			var r := PIP_R * k
			b.disc(at + Vector2(0.0, 3.0), r, Color(Pal.GF_LAWN_DEEP.darkened(0.2), 0.6))
			if done_hole:
				var d: int = _state.card[i] - _state.par_of(i)
				# under par is gold, par is paper, over is rose: three inks, and
				# the number says the rest
				var fill: Color = Pal.SUN_RAY if d < 0 else (Pal.SURFACE if d == 0 else Pal.FLOWER_TILE)
				var rim: Color = Pal.SUN_DEEP if d < 0 else (Pal.GF_FELT_DEEP if d == 0 else Pal.FLOWER_DEEP)
				b.disc(at, r, rim)
				b.disc(at, r - 3.5, fill)
			else:
				b.disc(at, r, Color(Pal.LINE, 0.9))
				b.disc(at, r - 2.5, Color(Pal.SURFACE, 0.9) if i == index else Pal.GF_LAWN.lightened(0.25))
				if i == index:
					b.stroke(Face.Builder.ring(at, r + 5.0, r + 5.0), 3.0, Pal.SUN, true)
		_hud = b.mesh()
		_hud_for = key
	_put(_hud, xf, tint, shown)
	draw_set_transform_matrix(xf)
	var font: Font = CozyTheme.display(700)
	var rise := (font.get_ascent(PIP_FONT) - font.get_descent(PIP_FONT)) * 0.5
	for i in holes:
		var at := Vector2(x0 + step * float(i), y)
		var done_hole: bool = i < index or (i == index and _state.sim.sunk)
		var text := str(_state.card[i]) if done_hole else str(i + 1)
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PIP_FONT).x
		var ink := Pal.TEXT if done_hole or i == index else Color(Pal.TEXT_DIM, 0.8)
		draw_string(font, at + Vector2(-w * 0.5, rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1, PIP_FONT, Color(ink, ink.a * tint.a))
	# the running score against par, once a hole is on the card
	if index > 0 or _state.sim.sunk:
		var d: int = _state.over_par()
		var tag := tr("GF_EVEN") if d == 0 else ("+%d" % d if d > 0 else "−%d" % -d)
		var tw: float = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT).x
		var trise := (font.get_ascent(TAG_FONT) - font.get_descent(TAG_FONT)) * 0.5
		var right := minf(size.x - 28.0, x0 + wide - PIP_R + 28.0 + tw)
		var ink: Color = Pal.SUN_DEEP.darkened(0.25) if d < 0 else (Pal.TEXT if d == 0 else Pal.FLOWER_DEEP.darkened(0.2))
		draw_string(font, Vector2(right - tw, y + trise), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT, Color(ink, tint.a))
	var line := _line()
	if line != "":
		var body: Font = CozyTheme.body(700)
		var lw: float = body.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FONT).x
		draw_string(body, Vector2((size.x - lw) * 0.5, top + LINE_Y + body.get_ascent(LINE_FONT) * 0.36), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FONT, Color(Pal.TEXT, 0.75 * tint.a))
	draw_set_transform(Vector2.ZERO)

## The line under the pips: the hole, its par and the strokes taken on it.
func _line() -> String:
	var n: int = _state.sim.strokes
	var at: int = _state.index + 1
	if n <= 0:
		return tr("GF_LINE_0") % [at, _state.par()]
	if n == 1:
		return tr("GF_LINE_ONE") % [at, _state.par()]
	return tr("GF_LINE_N") % [at, _state.par(), n]

## The toast over the foot of the card -- Super Slider's.
func _draw_toast(t: float, shown: Array) -> void:
	if _toast == "":
		return
	var since := t - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE),
		Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var line := _toast
	var font: Font = CozyTheme.body(600)
	var room := maxf(TOAST_PAD, size.x - 120.0)
	var text_room := room - TOAST_PAD
	var one: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x
	var lines := 1
	var text_w := one
	if one > text_room:
		var wrapped: Vector2 = font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, text_room, TOAST_FONT)
		var lh := font.get_height(TOAST_FONT)
		lines = maxi(1, int(round(wrapped.y / lh)))
		text_w = minf(text_room, wrapped.x)
	var w := minf(room, text_w + TOAST_PAD)
	var h := TOAST_H + float(lines - 1) * font.get_height(TOAST_FONT)
	var key := "%s|%d|%d" % [line, int(w), lines]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-w, -h) * 0.5, Vector2(w, h), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh() if not b.verts.is_empty() else null
		_toast_mesh_for = key
	if _toast_mesh == null:
		return
	var mid := Vector2(size.x * 0.5, size.y - 40.0 - h * 0.5)
	draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var top := mid.y - h * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - w * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		draw_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		draw_multiline_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_CENTER, w - TOAST_PAD,
			TOAST_FONT, lines, Color(Pal.PAPER, alpha))

# --- input ---

func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
		accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _aiming:
		_pull(event.position)
		accept_event()

func _press(local: Vector2) -> void:
	if _phase != "aim" or out_of_hearts or not _think.is_empty():
		return
	_aiming = true
	_from = local
	_power = 0.0
	_snapped = false

## The pull back from where the finger went down: the ball goes the other
## way, harder the further it is pulled.
func _pull(local: Vector2) -> void:
	var pull := local - _from
	var far := pull.length()
	if far < MIN_PULL:
		_power = 0.0
		_snapped = false
		return
	var a := (-pull).angle()
	var u := clampf((far - MIN_PULL) / (_span() - MIN_PULL), 0.02, 1.0)
	var was := _snapped
	_snapped = false
	if not _ghost.is_empty():
		var ga: float = _ghost.a
		var gu: float = _ghost.u
		if absf(angle_difference(a, ga)) < SNAP_A and absf(u - gu) < SNAP_U:
			a = ga
			u = gu
			_snapped = true
			if not was:
				fx.buzz(Haptics.TICK)
	_aim = a
	_power = u

## Let go to putt; let go with the pull put back to put the aim down.
func _release(local: Vector2) -> void:
	if not _aiming:
		return
	_pull(local)
	_aiming = false
	if _power <= 0.0:
		return
	_putt()

## The pull that makes a putt of `angle` and `power`: where a finger that
## went down at `from` lets go (the tutorial's and the harnesses' hand).
func pull_for(from: Vector2, angle: float, power: float) -> Vector2:
	return from - Vector2.from_angle(angle) * (MIN_PULL + clampf(power, 0.0, 1.0) * (_span() - MIN_PULL))

## The pull that is the hardest stroke (the tutorial's page is a small one).
func _span() -> float:
	return PULL

## Where the ball lies, on the card.
func ball_at() -> Vector2:
	return _pt(_state.sim.p)

func _putt() -> void:
	var power := _power
	if not _state.putt(_aim, power):
		return
	_phase = "roll"
	_acc = 0.0
	_trail = []
	_ghost = {}
	_power = 0.0
	_snapped = false
	_hud = null
	fx.cue("putt", 0.92 + 0.22 * power, lerpf(PUTT_SOFT_DB, 0.0, power))
	_spend(1, 0.0)
	note_move()

# --- the sprout's line and the toast ---

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

func _tell(key: String, mood: int, args: Array = []) -> void:
	var line := tr(key) % args if not args.is_empty() else tr(key)
	_say(line, mood)
	_toast = line
	_toast_at = _now()
	queue_redraw()

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func hints_left() -> int:
	return maxi(0, State.hints_for(_state.band) + hints_extra - hints_used)

## The bulb plays every putt out on a copy of the hole and shows the
## steadiest good one the whole way; the aim takes it when it comes near.
func hint() -> bool:
	if is_done() or _state.band >= 3 or hints_left() <= 0 or _phase != "aim" or not _think.is_empty():
		return false
	# a fraction of a second on this Mac, so off the frame
	var c = _state.sim.clone()
	var box := {}
	var id := WorkerThreadPool.add_task(func(): box["shot"] = c.best_shot())
	_think = {"id": id, "box": box, "at": _now()}
	_aiming = false
	hints_used += 1
	moved.emit()
	queue_redraw()
	return true

func _show_hint(shot: Dictionary) -> void:
	var a: float = shot.a
	var u: float = shot.u
	_ghost = {"a": a, "u": u, "pts": _state.sim.guide(a, u, 0.0, GUIDE_GAP)}
	fx.ring(_pt(_state.sim.p), Sim.BALL_R * _s() * 2.4, Pal.GF_HINT)
	fx.cue("hint")
	_tell("GF_HINT", Face.Expr.HAPPY)
	_busy_for(0.6)
	moved.emit()

## Reset plays the course again from its first tee, the card blank, and on
## Insane hands the whole count back.
func reset_board() -> void:
	if out_of_hearts or _phase != "aim":
		return
	_drop_think()
	var t := _now()
	if _state.total() > 0:
		_tries += 1
		_log += "·"
	_state.restart()
	moves_left = max_moves
	_fresh(t)
	moves = 0
	_running = true
	fx.cue("reset")
	_say(tr("GF_RESET"), Face.Expr.HAPPY)

func is_solved() -> bool:
	return _state.is_solved()

## The day's card, never its course: a mark a hole (an ace, under par, par,
## one over, more), the strokes against par, and the seal the round earned.
func share_glyphs() -> String:
	var out := _log
	if is_solved():
		var d: int = _state.total() - _state.par_total()
		out += " %d (%s)" % [_state.total(), tr("GF_EVEN") if d == 0 else ("+%d" % d if d > 0 else "−%d" % -d)]
		if _state.band >= 3:
			out += " 🚪 " + tr("GF_GATES_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
		elif _flawless:
			out += " 🏅 " + tr("BN_FLAWLESS")
	return out

# --- the win ---

func _win_line() -> String:
	var d: int = _state.total() - _state.par_total()
	if d == 0:
		return tr("GF_WIN_EVEN") % _state.total()
	if d < 0:
		return tr("GF_WIN_UNDER") % [_state.total(), -d]
	return tr("GF_WIN_OVER") % [_state.total(), d]

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": _win_line()}

## The win screen waits for the party: the cat on the lawn and the seal.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return maxf(WIN_HOLD, PARTY_AT + STAMP_AT + STAMP_DROP * 2.0 + 0.5)

func _on_solved() -> void:
	_solved_at = _now()
	_won = true
	# Flawless: par or better with no bulb, on the first card (no Reset once a
	# stroke was played, never out of strokes).
	_flawless = hints_used == 0 and _tries == 1 and not _lost_ever and _state.total() <= _state.par_total()
	fx.cue("solved")
	_say(_win_line(), Face.Expr.JOY)
	_party()

func completion_record() -> Dictionary:
	return {"card": Array(_state.card), "log": _log, "moves_left": moves_left, "flawless": _flawless}

## A reopened daily that was already solved: the last hole, the ball down,
## the card as it was written. Never check_solved(): `solved` must not fire
## twice.
func restore_completed_board() -> void:
	var saved: Array = completed_record.get("card", [])
	_state.finish()
	for i in mini(saved.size(), _state.card.size()):
		_state.card[i] = int(saved[i])
	_log = String(completed_record.get("log", ""))
	moves_left = maxi(0, int(completed_record.get("moves_left", 0)))
	_flawless = bool(completed_record.get("flawless", false))
	var t := _now()
	_fresh_hole(t - 100.0)
	_opened = t - 100.0
	_sunk_at = t - 100.0
	_solved_at = t - 100.0
	_won = true
	_phase = "won"
	_cat_at = t - 100.0
	_cat_curled = false
	if _flawless or _state.band >= 3:
		_stamp_at = t - 100.0
	_layout()
	_place_cat(t)
	_say(tr("GF_DONE"), Face.Expr.JOY)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
