extends "res://core/puzzle_base.gd"

## Marigold as a flat board: a pond garden at dusk under an arbor, a field of
## flower buds, the family's sun at the top with a leaf spout, and a
## terracotta pot sliding along the bank at the foot. Drag to aim, let go and
## the sun shoots a seed; every bud it touches blooms, and the blooms are
## picked when the seed has gone. Bloom every marigold. The rules and the
## physics live in puzzles/marigold_state.gd, which this only draws.
##
## After the reference the user asked for (the Xbox classic of pegs, a
## launcher and a sliding bucket), re-dressed as a garden. Out of seeds with
## a marigold left, the garden grows back for another try; on Hard and
## Insane that try costs a heart, and out of hearts the day can be lost.
## Insane is Sweethearts: the marigolds come in pairs tied by a ribbon, and a
## marigold blooms for good only in the same shot as its sweetheart.
##
## How it is drawn. Meshes, most of them cached:
##   still -- the card, the dusk garden and the arbor, on a relayout only;
##   buds  -- every closed bud, rebuilt when one blooms or the garden grows;
##   lit   -- the blooms and the ones being picked, while any of them moves;
##   guide -- the dotted aim, when the aim moves;
##   trail -- the seed's wake, while a seed is out;
##   live  -- the garden's small breath, every frame, in two: under the
##            buds, fireflies, twinkling stars, drifting glints, the
##            lanterns' flicker and the ripples round every bloom; over
##            everything, a glint on a marigold now and then, the marigolds
##            flying up to their pips and the full bloom's petals;
##   pill  -- the multiplier's tag, rebuilt when it steps and popped by
##            transform;
##   the pot, the seed and the sun's three parts are built once and moved by
##   transform, so an idle garden rebuilds nothing.
##
## Spec: docs/superpowers/specs/2026-09-26-marigold-flat-design.md; the
## polish (hearts, Sweethearts, the gags, the sounds):
## docs/superpowers/specs/2026-10-01-marigold-polish-design.md.

signal leave

const State = preload("res://puzzles/marigold_state.gd")
const Parts = preload("res://ui/faces/marigold_parts.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Locale = preload("res://core/locale.gd")
const Seal = preload("res://ui/flat/seal.gd")
const NapCat = preload("res://ui/faces/nap_cat.gd")

# --- the screen, measured ---
## The card's inset round the field, the band over it the counts take, the
## card's corner, and the room under the field.
const INSET := 22.0
const BAND := 112.0
const CARD_RADIUS := 32.0
const FOOT := 10.0
## The sun's radius, in field units.
const SUN_R := 3.4
const SCORE_FONT := 52
const MULT_FONT := 40
const COUNT_FONT := 30
const FLOAT_FONT := 40
const BANNER_FONT := 104

# --- this board's own motion ---
## A bud opens over BLOOM_TIME when touched. The blooms are picked one after
## another, PICK_STEP apart (the whole shot's inside PICK_ALL), each fading
## over PICK_TIME with a petal puff.
const BLOOM_TIME := 0.24
const PICK_STEP := 0.07
const PICK_ALL := 1.3
const PICK_TIME := 0.2
## The aim's dots, GUIDE_GAP units apart, up to GUIDE_LEN of the way.
const GUIDE_GAP := 2.3
const GUIDE_LEN := 30.0
## The seed's wake: TRAIL points.
const TRAIL := 14
## The last marigold, as it happens in the reference. A seed heading for it
## within NEAR units slows the garden toward NEAR_SLOW and pushes the view in
## toward NEAR_ZOOM, the closer the more, under a drumroll; a seed that came
## inside CLOSE and turned away without touching it is a near miss. Touching
## it slams the garden to SLOW and the view to FEVER_ZOOM on the seed for
## FEVER_HOLD of real time, then eases over FEVER_EASE to FEVER_LATE and the
## whole field while the seed falls to its pot, under the music. The view and
## the clock follow their targets at CAM_RATE.
const NEAR := 18.0
const CLOSE := 6.0
const NEAR_SLOW := 0.3
const NEAR_ZOOM := 1.55
const SLOW := 0.15
const FEVER_ZOOM := 2.1
const FEVER_HOLD := 1.2
const FEVER_EASE := 1.0
const FEVER_LATE := 0.5
const CAM_RATE := 6.0
## The full bloom's music waits MUSIC_AFTER for the sting to open it.
const MUSIC_AFTER := 0.35
const BANNER_TIME := 2.4
const FLOAT_TIME := 1.1
const POT_GLOW_TIME := 0.5
const OUT_WAIT := 2.4
const WIN_HOLD := 1.2
## A bloom rings the water RIPPLE_TIME; a picked bloom rises PICK_RISE units
## and turns as it fades; a bloomed marigold flies up to its pip over
## FLY_TIME. The sun recoils over RECOIL_TIME, the pot wobbles WOBBLE_TIME
## after it turns at an end and squashes CATCH_TIME when it catches a seed,
## the tag pops TAG_TIME when the multiplier steps. A marigold glints every
## GLINT_EVERY; the full bloom's petals fall for PETAL_TIME.
const RIPPLE_TIME := 0.5
const PICK_RISE := 2.6
const FLY_TIME := 0.6
const RECOIL_TIME := 0.32
const WOBBLE_TIME := 0.9
const CATCH_TIME := 0.34
const TAG_TIME := 0.4
const GLINT_EVERY := 1.7
const GLINT_TIME := 0.6
const PETAL_TIME := 4.5
const FIREFLIES := 8
## The reference's rising scale, one step a bloom within a shot: a major
## scale up an octave and a fifth, then held at the top.
const SCALE := [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19]
const TOAST_HOLD := 2.6
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 40.0
const TIPS := ["MG_TIP_AIM", "MG_TIP_GOAL", "MG_TIP_POT"]
const BUD_BANDS := 6

# --- the rewards, made loud (the spec's third amendment) ---
## A long shot's words, by blooms in the shot, lettered bigger the higher.
const WORDS := [[30, "MG_WORD_5"], [22, "MG_WORD_4"], [15, "MG_WORD_3"], [10, "MG_WORD_2"], [6, "MG_WORD_1"]]
## Marigolds in one shot: two, three, four or more.
const BUNCH := ["", "", "MG_BUNCH_2", "MG_BUNCH_3", "MG_BUNCH_4"]
const STICKER_COLS := [Color("ff6f61"), Color("ffb03b"), Color("ffd84d"), Color("7fd66a"), Color("5cb8ff"), Color("b77be6")]
const GOLD := Color("f2b632")
const ROSE := Color("ff6f8e")
const PETALS := [Color("f08a2c"), Color("fcc271"), Color("f9c04a"), Color("f4a3a0"), Color("c6b0ea"), Color("fbf7ee")]
## Where the stickers stand, in field rows: the first free one is taken.
const STICKER_ROWS := [40.0, 55.0, 70.0, 85.0]
const MAX_BITS := 260
## The bloom counter shows from this many blooms in a shot.
const COUNT_FROM := 4
const COUNT_FONT_BIG := 44
const HOP_TIME := 0.4
const KICK_TIME := 0.35
const SEED_FLY := 0.55

# --- the polish of 2026-10-01: hearts, Sweethearts and sillier rewards ---
## The hearts hang on a little wooden sign off the arch, left of the sun, in
## field units; a lost one splits and falls.
const SIGN_AT := Vector2(12.0, 10.6)
const HEART_R := 1.75
const HEART_GAP := 0.9
const SPLIT_TIME := 0.7
const SPLIT_FALL := 6.0
const SPLIT_SPREAD := 1.6
const SPLIT_TURN := 0.7
const HEART_BACK_TIME := 0.3
const DUSK := Color(0.74, 0.76, 0.92)
const DUSK_TIME := 0.8
const CARD_AFTER := 1.4
const CARD_AFTER_STILL := 0.3
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
const TIPS_HEARTS := ["MG_TIP_AIM", "MG_TIP_HEARTS", "MG_TIP_POT"]
const TIPS_SWEET := ["MG_TIP_SWEET", "MG_TIP_SWEET_PLAN", "MG_TIP_SWEET_HEARTS"]
## Sweethearts: a marigold left alone folds back into a bud over FOLD_TIME
## when the shot ends; each pair's ribbon has its own colour.
const FOLD_TIME := 0.5
const RIBBONS := [Color("f59bbd"), Color("f7b878"), Color("9fd88c"), Color("8fc0f0"), Color("c3a6ef"), Color("f5d76e")]
## A bud a seed brushes past without touching shivers for RUSTLE_TIME.
const RUSTLE_TIME := 0.5
const RUSTLE_REACH := 4.8
## The spout follows the finger at AIM_RATE, so a jump of the finger turns it.
const AIM_RATE := 24.0
## The frog on the lily pad: a hop takes FROG_HOP; a croak FROG_CROAK.
const FROG_AT := Vector2(13.4, 116.4)
const FROG_HOP := 0.62
const FROG_CROAK := 0.7
## The ducks paddle across the pond over DUCK_TIME after a long shot.
const DUCK_TIME := 8.0
## The sun's sunglasses drop on over SHADES_DROP and stay SHADES_STAY.
const SHADES_DROP := 0.32
const SHADES_STAY := 5.0
## Shots in a row that keep a marigold (a pair on Insane) are a streak.
const STREAK_FROM := 2
## The party after the win: the nap cat on the bank, the seal, the wisdom.
const PARTY_AT := 0.6
const CHEERS := 10
const CAT_PX := 0.16
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

var _state = State.new()
var fx: Node2D

## "aim", "shot" (a seed is out), "pick" (the blooms are picked), "out" (no
## seeds left, the garden about to grow back), "won".
var _phase := "aim"
var _aim := PI * 0.5
var _aiming := false
## The hint's long guide is shown for this aim until the aim moves.
var _super := false
var _acc := 0.0
## The garden's clock (1: real time), the view's zoom about _focus (px), and
## the view itself, which every drawing and the fx layer go through.
var _slow := 1.0
var _zoom := 1.0
var _focus := Vector2.ZERO
var _cam := Transform2D.IDENTITY
## How close a seed is to the last marigold (0..1), and whether one has come
## inside CLOSE this shot -- a near miss if it turns away.
var _near := 0.0
var _near_armed := false
var _near_spent := false
var _roll: AudioStreamPlayer
var _music: AudioStreamPlayer
## Per bud: when it bloomed and when it is picked (-1: not).
var _hit_at := PackedFloat32Array()
var _pick_at := PackedFloat32Array()
## The buds bloomed this shot, in the order they bloomed.
var _order := PackedInt32Array()
var _picking: Array = []
var _pick_done := 0.0
var _pick_result := {}
var _trails: Array = []
var _floats: Array = []
var _pot_glow_at := -100.0
var _fever_at := -100.0
var _fever_from := Vector2.ZERO
var _fever_pot := -1
var _fever_pot_at := -100.0
var _out_at := -100.0
var _grown_at := 0.0
var _opened := 0.0
var _solved_at := -1.0
var _blink_at := 0.0
var _expr := Face.Expr.HAPPY
var _expr_until := 0.0
var _log := ""
## The hint's search, on a worker thread: {"id", "box", "at"}; empty when none.
var _think := {}
var _shot_oranges := 0
var _shot_pot := false
var _shot_at := -100.0
var _pot_turn_at := -100.0
var _pot_last_dir := 1.0
## Ripples on the water: {"at" (field units), "t", "col"}.
var _ripples: Array = []
## Marigolds flying up to their pips: {"from" (px), "t"}.
var _flies: Array = []
var _mult_shown := 1
var _mult_at := -100.0
var _score_shown := 0.0
var _glint_i := -1
var _glint_at := -100.0
## The trough holds this many seeds: the try's first handful.
var _seeds_start := 10
## The rewards. Bits thrown in the garden (pixels before the view, moving on
## the garden's clock, so the full bloom's slow motion slows them too) and
## in the air over it (the card's pixels, real time); the stickers, lettered
## a hopping letter at a time; the warm glow round the card while a shot
## runs long, the flash, the view's shake and the rain.
var _bits: Array = []
var _air_bits: Array = []
var _stickers: Array = []
var _heat := 0.0
var _flash := 0.0
var _flash_col := Color.WHITE
var _shake := 0.0
var _rain := 0.0
var _rain_coins := false
## The loudest word shown this shot, the sun's hop, the score's kick and the
## bloom counter's bump.
var _word_tier := -1
var _hop_at := -100.0
var _kick_at := -100.0
var _count_at := -100.0
## Seeds flying into the trough: {"from" (px), "t"}.
var _seed_flies: Array = []
var _air: ArrayMesh

## Hearts: Hard and Insane (State.HEARTS_BY). A garden run out of seeds, or
## given up with Reset after a seed has flown, costs one.
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
var _lost_ever := false
var _flawless := false
var _won := false
var _heart_card: Control
var _split_index := -1
var _split_at := -100.0
var _back_index := -1
var _back_at := -100.0
var _dusk_tw: Tween
var _hearts_mesh: ArrayMesh
var _hearts_for := ""
## Sweethearts: per bud, when it folded back (-1: not); each pair's ribbon
## colour; the ribbons' mesh and what it was built for.
var _fold_at := PackedFloat32Array()
var _fold_until := -100.0
var _ribbon := PackedInt32Array()
var _threads: ArrayMesh
var _threads_for := ""
var _shot_pairs := 0
var _apart_told := false
## Buds a seed brushed past: when each started shivering, and the strips
## still shivering (band -> until).
var _rustle_at := PackedFloat32Array()
var _rustling := {}
## The spout's own angle, following _aim.
var _aim_shown := PI * 0.5
## The silly ones: the frog, the ducks, the sun's sunglasses, the streak.
var _frog_hop_at := -100.0
var _frog_flip := false
var _frog_croak_at := -100.0
var _ducks_at := -100.0
var _shades_at := -100.0
var _shades_until := -100.0
var _shades: ArrayMesh
var _streak := 0
## The party: the nap cat, the seal.
var _party_at := INF
var _cat: Control
var _cat_at := INF
var _cat_curled := false
var _stamp_at := INF
var _seal_mesh: ArrayMesh

var _still: ArrayMesh
## The closed buds in BUD_BANDS strips down the field, so a bloom rebuilds
## only its own strip.
var _buds: Array = []
var _lit: ArrayMesh
var _guide: ArrayMesh
var _trail: ArrayMesh
var _pot: ArrayMesh
var _pot_for := -1
var _seed: ArrayMesh
var _rays: ArrayMesh
var _body: ArrayMesh
var _body_for := ""
var _spout: ArrayMesh
var _spout_for := -1
var _back: ArrayMesh
var _live: ArrayMesh
var _live_back: ArrayMesh
var _pill: ArrayMesh
var _pill_for := -1
var _hud: ArrayMesh
var _hud_for := ""
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""
## The meshes the last _draw handed over: a canvas command holds a mesh by
## RID, so dropping the only reference leaves the renderer a freed one.
var _shown: Array = []
var _toast := ""
var _toast_at := -100.0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY

func puzzle_id() -> String: return "marigold"
func title() -> String: return "Marigold"

## The rules, then the band's own closing: hearts (Hard), Sweethearts
## (Insane).
func rules() -> String:
	var out := tr("MG_RULES")
	if _state.sweethearts:
		out += "\n\n" + tr("MG_RULES_SWEET") % max_hearts
	elif max_hearts > 0:
		out += "\n\n" + tr("MG_RULES_HEARTS") % max_hearts
	return out

func _tips() -> Array:
	if _state.sweethearts:
		return TIPS_SWEET
	if max_hearts > 0:
		return TIPS_HEARTS
	return TIPS

## Hint only: nothing to take back once a seed has flown. Reset is the
## host's. Insane has no hint.
func capabilities() -> Array[String]:
	if _state.band >= 3:
		return []
	return ["hint"]

## Reset waits while a seed is out or the sun is thinking; it costs a heart
## on Hard and Insane once a seed has flown (reset_board).
func can_reset() -> bool:
	return _phase == "aim" and _think.is_empty() and not out_of_hearts

func busy() -> bool:
	return _phase in ["shot", "pick", "out"] or not _think.is_empty()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_roll = _voice("roll", true)
	_music = _voice("music", false)
	resized.connect(_layout)
	solved.connect(_on_solved)

func _exit_tree() -> void:
	_close_card()
	if not _think.is_empty():
		WorkerThreadPool.wait_for_task_completion(int(_think.id))
		_think = {}

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_close_card()
	_state.build(rng, difficulty, bank_step)
	max_hearts = State.hearts_for(difficulty)
	hearts = max_hearts
	out_of_hearts = false
	_heart_used = false
	_lost_ever = false
	_flawless = false
	_won = false
	_split_index = -1
	_back_index = -1
	_streak = 0
	_apart_told = false
	_reset_party()
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	_opened = _now()
	_fresh(_opened)
	_log = ""
	_layout()
	fx.cue("enter")
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)

## Everything a new try starts from.
func _fresh(t: float) -> void:
	var n: int = _state.pos.size()
	_hit_at = PackedFloat32Array()
	_hit_at.resize(n)
	_hit_at.fill(-1.0)
	_pick_at = PackedFloat32Array()
	_pick_at.resize(n)
	_pick_at.fill(-1.0)
	_order = PackedInt32Array()
	_picking = []
	_trails = []
	_floats = []
	_phase = "aim"
	_aiming = false
	_super = false
	_aim = PI * 0.5
	_acc = 0.0
	_slow = 1.0
	_zoom = 1.0
	_cam = Transform2D.IDENTITY
	if fx != null:
		fx.transform = _cam
	_near = 0.0
	_near_armed = false
	_near_spent = false
	_quiet_audio()
	_fever_at = -100.0
	_fever_pot = -1
	_fever_pot_at = -100.0
	_out_at = -100.0
	_solved_at = -1.0
	_grown_at = t
	_blink_at = t + 2.5
	_buds = []
	_lit = null
	_guide = null
	_back = null
	_hud = null
	_buds = []
	_ripples = []
	_flies = []
	_mult_shown = _state.mult()
	_mult_at = -100.0
	_pill = null
	_score_shown = float(_state.score)
	_shot_at = -100.0
	_seeds_start = _state.seeds
	_bits = []
	_stickers = []
	_seed_flies = []
	_heat = 0.0
	_shake = 0.0
	_word_tier = -1
	_fold_at = PackedFloat32Array()
	_fold_at.resize(n)
	_fold_at.fill(-1.0)
	_fold_until = -100.0
	_rustle_at = PackedFloat32Array()
	_rustle_at.resize(n)
	_rustle_at.fill(-100.0)
	_rustling = {}
	_aim_shown = _aim
	_threads = null
	_threads_for = ""
	_shot_pairs = 0
	_shades_until = minf(_shades_until, t)
	# each pair's ribbon colour, in the order the pairs first appear
	_ribbon = PackedInt32Array()
	_ribbon.resize(n)
	_ribbon.fill(-1)
	var k := 0
	for i in n:
		var j: int = _state.pair[i] if i < _state.pair.size() else -1
		if j >= 0 and _ribbon[i] < 0:
			_ribbon[i] = k
			_ribbon[j] = k
			k += 1

# --- layout ---

## Pixels a field unit.
func _s() -> float:
	var w := (size.x - 2.0 * INSET) / State.W
	var h := (size.y - BAND - INSET - FOOT) / State.H
	return maxf(0.0, minf(w, h))

## The field's top-left.
func _origin() -> Vector2:
	var s := _s()
	var room := size.y - BAND - FOOT
	return Vector2((size.x - State.W * s) * 0.5, BAND + maxf(0.0, (room - State.H * s) * 0.5))

func _pt(v: Vector2) -> Vector2:
	return _origin() + v * _s()

func card_height(available: float) -> float:
	return available

func card_centred() -> bool:
	return true

func _layout() -> void:
	_still = null
	_buds = []
	_lit = null
	_guide = null
	_trail = null
	_pot = null
	_seed = null
	_rays = null
	_body = null
	_spout = null
	_back = null
	_hud = null
	_pill = null
	_threads = null
	_hearts_mesh = null
	_shades = null
	queue_redraw()

# --- the frame loop ---

func _process(delta: float) -> void:
	super(delta)
	if _s() <= 0.0 or _state.pos.is_empty():
		return
	var t := _now()
	var sd := delta * _slow
	if _phase == "shot":
		_acc += sd
		var events: Array = []
		var n := 0
		while _acc >= State.DT and n < 60:
			_state.step(events)
			_acc -= State.DT
			n += 1
			if _state.balls.is_empty():
				break
		_handle(events, t)
		_follow_trails()
		_brush(t)
		if _state.balls.is_empty():
			_end_shot(t)
	elif not _done and _phase != "asleep":
		_state.step_pot(sd)
	_aim_shown = _aim if Motion.reduce else lerp_angle(_aim_shown, _aim, 1.0 - exp(-AIM_RATE * delta))
	_camera(t, delta)
	_tick_rewards(t, delta)
	if _state.pot_dir != _pot_last_dir:
		_pot_last_dir = _state.pot_dir
		_pot_turn_at = t
	_tick_garden(t, delta)
	if not _think.is_empty() and WorkerThreadPool.is_task_completed(int(_think.id)):
		WorkerThreadPool.wait_for_task_completion(int(_think.id))
		var box: Dictionary = _think.box
		_think = {}
		if _phase == "aim" and not _done:
			_aim = float(box.a)
			_super = true
			_guide = null
			fx.ring(_pt(State.SUN_C), SUN_R * _s() * 1.6, Pal.SUN)
			fx.cue("hint")
			_tell("MG_HINT", Face.Expr.HAPPY)
	if _phase == "pick" and t >= _pick_done:
		_after_pick(t)
	if _phase == "out" and t - _out_at >= OUT_WAIT:
		_regrow(t)
	if not Motion.reduce and t > _blink_at + Face.BLINK_TIME:
		_blink_at = t + randf_range(2.8, 5.5)
	if _lit_moving(t):
		_lit = null
	if _buds_moving(t):
		_buds = []
	elif not _rustling.is_empty() and _buds.size() == BUD_BANDS:
		for band: int in _rustling.keys():
			_buds[band] = null
			if t > float(_rustling[band]):
				_rustling.erase(band)
	if _cat_at < INF:
		_place_cat(t)
	queue_redraw()

## The buds a seed brushes past without touching shiver, a strip at a time.
func _brush(t: float) -> void:
	if Motion.reduce:
		return
	var reach := RUSTLE_REACH
	for ball: Dictionary in _state.balls:
		var p: Vector2 = ball.p
		var cx := int(floorf(p.x / 6.0))
		var cy := int(floorf(p.y / 6.0))
		for gy in range(cy - 1, cy + 2):
			for gx in range(cx - 1, cx + 2):
				var key := gx + gy * 64
				if not _state.grid.has(key):
					continue
				for i: int in _state.grid[key]:
					if _state.st[i] != State.UP or t - _rustle_at[i] < RUSTLE_TIME:
						continue
					if p.distance_squared_to(_state.pos[i]) < reach * reach:
						_rustle_at[i] = t
						_rustling[_band_of(i)] = t + RUSTLE_TIME
## The last marigold's approach and the full bloom: the clock, the view, the
## drumroll and the near miss, every frame.
func _camera(t: float, delta: float) -> void:
	var want_slow := 1.0
	var want_zoom := 1.0
	var want_focus := _focus
	var near := 0.0
	if _phase == "shot" and _state.fever and not _state.balls.is_empty():
		var k := clampf((t - _fever_at - FEVER_HOLD) / FEVER_EASE, 0.0, 1.0)
		want_slow = lerpf(SLOW, FEVER_LATE, k)
		want_zoom = lerpf(FEVER_ZOOM, 1.0, k)
		# the seed nearest where the view already is: a clover's twin
		# does not steal the camera
		var best := INF
		for ball: Dictionary in _state.balls:
			var p := _pt(ball.p)
			if p.distance_squared_to(_focus) < best:
				best = p.distance_squared_to(_focus)
				want_focus = p
	elif _phase == "shot" and _state.oranges_left == 1:
		var last := _last_marigold()
		var reach := State.PEG_R + State.BALL_R
		var closing := false
		for ball: Dictionary in _state.balls:
			var to: Vector2 = _state.pos[last] - Vector2(ball.p)
			var d := to.length() - reach
			var toward: bool = Vector2(ball.v).dot(to) > 0.0
			if d < CLOSE and not _near_spent:
				_near_armed = true
			if toward:
				closing = closing or d < NEAR
				var c := 1.0 - clampf(d / (NEAR - reach), 0.0, 1.0)
				if c > near:
					near = c
					want_focus = _pt((Vector2(ball.p) + _state.pos[last]) * 0.5)
		if _near_armed and not closing:
			_near_miss()
		want_slow = lerpf(1.0, NEAR_SLOW, near)
		want_zoom = lerpf(1.0, NEAR_ZOOM, near)
	elif _near_armed:
		# the shot ended with a seed having brushed past it
		if _state.fever:
			_near_armed = false
		else:
			_near_miss()
	_near = near
	if Motion.reduce:
		want_slow = 1.0
		want_zoom = 1.0
	var a := 1.0 - exp(-CAM_RATE * delta)
	_slow = lerpf(_slow, want_slow, a)
	_zoom = lerpf(_zoom, want_zoom, a)
	if _zoom < 1.001 and want_zoom <= 1.0:
		_zoom = 1.0
	_focus = _focus.lerp(want_focus, minf(1.0, a * 2.0))
	# zoom about the focus, drawn toward the middle as it deepens, and never
	# past the card's edge
	var mid := size * 0.5
	var pull := clampf((_zoom - 1.0) / (FEVER_ZOOM - 1.0), 0.0, 1.0) * 0.6
	var c := _focus.lerp(mid, pull)
	c.x = clampf(c.x, size.x - (size.x - _focus.x) * _zoom, _focus.x * _zoom)
	c.y = clampf(c.y, size.y - (size.y - _focus.y) * _zoom, _focus.y * _zoom)
	_cam = Transform2D(0.0, Vector2.ONE * _zoom, 0.0, c - _focus * _zoom)
	if _shake > 0.0 and not Motion.reduce:
		_cam.origin += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 16.0 * _shake * _shake
	fx.transform = _cam
	_drumroll(delta)

## The one marigold still up.
func _last_marigold() -> int:
	for i in _state.pos.size():
		if _state.kind[i] == State.ORANGE and _state.st[i] == State.UP:
			return i
	return 0

## A seed brushed past the last marigold and turned away.
func _near_miss() -> void:
	_near_armed = false
	_near_spent = true
	fx.cue("close")
	_mood(Face.Expr.WORRIED, 1.2)
	_say(tr("MG_CLOSE"), Face.Expr.WORRIED)
	var last := _pt(_state.pos[_last_marigold()])
	_sticker(tr("MG_CLOSE"), _row_at("close"), 76, 1.5, false, ROSE, false, "close")
	_spray(_bits, last, Pal.MG_ORANGE_HI, 8, 300.0, "spark")
	_shake = maxf(_shake, 0.45)

## The drumroll swells with the approach and stops the moment it ends.
func _drumroll(delta: float) -> void:
	if _roll == null or _roll.stream == null:
		return
	var want := _near if _phase == "shot" and not _state.fever else 0.0
	var now := db_to_linear(_roll.volume_db)
	now = move_toward(now, want, delta * (4.0 if want > now else 8.0))
	_roll.volume_db = linear_to_db(maxf(now, 0.0001))
	_roll.pitch_scale = lerpf(0.95, 1.15, want)
	if now > 0.002 and not _roll.playing:
		_roll.play()
	elif now <= 0.002 and _roll.playing:
		_roll.stop()

## A player for a sound the board holds on to: the drumroll loops, the music
## plays once. Silent (no stream) when the file is not there.
func _voice(cue_name: String, loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = -80.0 if loop else 0.0
	var path := "res://assets/sfx/marigold/%s.ogg" % cue_name
	if ResourceLoader.exists(path):
		var stream: AudioStreamOggVorbis = (load(path) as AudioStreamOggVorbis).duplicate()
		stream.loop = loop
		p.stream = stream
	add_child(p)
	return p

func _quiet_audio() -> void:
	if _roll != null:
		_roll.stop()
		_roll.volume_db = -80.0
	if _music != null:
		_music.stop()

## Every seed's wake: the last TRAIL places it was drawn at.
func _follow_trails() -> void:
	while _trails.size() < _state.balls.size():
		_trails.append(PackedVector2Array())
	for k in _state.balls.size():
		var tr_pts: PackedVector2Array = _trails[k]
		tr_pts.append(Vector2(_state.balls[k].p))
		if tr_pts.size() > TRAIL:
			tr_pts.remove_at(0)
		_trails[k] = tr_pts
	_trail = null

func _lit_moving(t: float) -> bool:
	if not _picking.is_empty() or t < _fold_until:
		return true
	if _phase == "shot" and not _order.is_empty() and not Motion.reduce:
		return true
	for i in _order:
		if t - _hit_at[i] < BLOOM_TIME + 0.05:
			return true
	return false

func _buds_moving(t: float) -> bool:
	if Motion.reduce:
		return t < _fold_until
	return t - _grown_at < _entrance_time() or t < _fold_until + Motion.POP_IN

func _entrance_time() -> float:
	return Motion.ENTER_DELAY + 0.1 + 0.9 + Motion.POP_IN + 0.05

## The small things that run on the frame clock: the score rolling up to
## what it is, the tag stepping, the flying marigolds landing on their pips,
## the ripples dying, and the next marigold to glint.
func _tick_garden(t: float, delta: float) -> void:
	var target := float(_state.score + (_state.shot_points if _phase == "shot" else 0))
	if Motion.reduce or target < _score_shown:
		_score_shown = target
	else:
		_score_shown = minf(target, _score_shown + maxf((target - _score_shown) * minf(1.0, delta * 9.0), 60.0 * delta))
	var m: int = _state.mult()
	if m != _mult_shown:
		if m > _mult_shown:
			if not Motion.reduce:
				_mult_at = t
				fx.ring(_tag_centre(), 70.0, Pal.MG_ORANGE_HI, 0.5)
				fx.sparkle(_tag_centre(), Pal.SUN_RAY)
			_step_up(m)
		_mult_shown = m
		_pill = null
	var keep: Array = []
	for f: Dictionary in _flies:
		if t - float(f.t) >= FLY_TIME:
			var pip := _pip_at(_pips_filled(t))
			fx.sparkle(pip, Pal.SUN_RAY)
			_ring(_air_bits, pip, 34.0, Color(GOLD, 0.9))
			_spray(_air_bits, pip, GOLD, 4, 260.0, "star", 0.6)
		else:
			keep.append(f)
	if keep.size() != _flies.size():
		_flies = keep
		_hud = null
	var alive: Array = []
	for r: Dictionary in _ripples:
		if t - float(r.t) < RIPPLE_TIME:
			alive.append(r)
	_ripples = alive
	if t - _glint_at > GLINT_EVERY and not Motion.reduce and _phase != "won":
		_glint_at = t
		_glint_i = -1
		var up: Array = []
		for i in _state.pos.size():
			if _state.kind[i] == State.ORANGE and _state.st[i] == State.UP:
				up.append(i)
		if not up.is_empty():
			_glint_i = up[randi() % up.size()]

## The pips lit: every marigold bloomed, less the ones still flying up.
func _pips_filled(t: float) -> int:
	var n: int = _state.orange_total - _state.oranges_left
	for f: Dictionary in _flies:
		if t - float(f.t) < FLY_TIME:
			n -= 1
	return maxi(0, n)

# --- a shot's events ---

func _handle(events: Array, t: float) -> void:
	var s := _s()
	for e: Dictionary in events:
		match String(e.t):
			"hit":
				var i: int = e.i
				_hit_at[i] = t
				_fold_at[i] = -1.0
				_threads = null
				if not Motion.reduce:
					_ripples.append({"at": _state.pos[i], "t": t, "col": Parts.colours(_state.kind[i])[1]})
					if _state.kind[i] == State.ORANGE:
						_flies.append({"from": _pt(_state.pos[i]), "t": t + BLOOM_TIME * 0.6})
						_hud = null
				_order.append(i)
				_dirty_bud(i)
				var step: int = SCALE[mini(int(e.n) - 1, SCALE.size() - 1)]
				fx.cue("hit", pow(2.0, float(step) / 12.0))
				var at := _pt(_state.pos[i])
				_bloom_bits(i, int(e.n))
				match _state.kind[i]:
					State.ORANGE:
						_shot_oranges += 1
						_mood(Face.Expr.JOY, 0.8)
						fx.puff(at, Pal.MG_ORANGE_HI, 4)
						if _state.sweethearts:
							var j: int = _state.pair[i]
							# the board's own event order, not the state's: a frame's
							# batch of steps can hold both hits already
							if j >= 0 and _order.has(j):
								_sweethearts(i, j)
						elif _shot_oranges >= 2 and not _state.fever:
							_bunch(_shot_oranges)
					State.PURPLE:
						fx.cue("violet")
						fx.sparkle(at, Pal.MG_PURPLE_HI)
						_sticker("+%s" % Locale.number(500 * _state.mult()), _cam * at - Vector2(0.0, 56.0), 60, 1.1, false,
							Pal.MG_PURPLE_HI, false, "violet")
						_flash_now(Pal.MG_PURPLE_HI, 0.18)
					State.GREEN:
						fx.cue("clover")
						fx.sparkle(at, Pal.MG_GREEN_HI)
				_count_at = t
				_shot_word(int(e.n))
			"split":
				_tell("MG_SPLIT", Face.Expr.JOY)
			"wall":
				if float(e.speed) > 20.0:
					fx.cue("wall", 1.0, -4.0)
			"pot":
				_pot_glow_at = t
				_ripples.append({"at": Vector2(e.at), "t": t, "col": Pal.SUN_RAY})
				_shot_pot = true
				fx.cue("pot")
				fx.sparkle(_pt(e.at), Pal.SUN)
				_float(_pt(e.at) - Vector2(0.0, s * 3.0), tr("MG_SEED_BACK"), Pal.SUN_RAY)
				_mood(Face.Expr.JOY, 1.0)
				_caught(_pt(e.at), t)
			"fever":
				_fever_at = t
				_fever_from = _pt(e.at)
				_back = null
				if not Motion.reduce:
					_slow = SLOW
					_focus = _fever_from
				_near_armed = false
				_roll.stop()
				_roll.volume_db = -80.0
				fx.cue("fever")
				if _music.stream != null:
					get_tree().create_timer(MUSIC_AFTER).timeout.connect(func():
						if _state.fever and is_inside_tree():
							_music.play())
				fx.ring(_pt(e.at), s * 6.0, Pal.SUN, 0.9)
				_mood(Face.Expr.JOY, 30.0)
				_full_bloom(_pt(e.at))
			"fever_pot":
				_fever_pot = int(e.k)
				_fever_pot_at = t
				fx.cue("fever_pot")
				var at := _pt(Vector2((float(e.k) + 0.5) * State.W / float(State.FEVER_POTS.size()), State.POT_Y))
				fx.sparkle(at, Pal.SUN)
				fx.puff(at, Pal.MG_ORANGE_HI, 8)
				_jackpot(int(e.k), at)
			"drain":
				fx.cue("drain", 1.0, -6.0)
				_croak(t)
			"unstick":
				for i: int in e.list:
					_pick_at[i] = t
					_picking.append(i)
					fx.puff(_pt(_state.pos[i]), Parts.colours(_state.kind[i])[1], 3)
				fx.cue("pop")

## The last seed is gone: pick the blooms, one after another.
func _end_shot(t: float) -> void:
	_pick_result = _state.end_shot(_order)
	var folded: PackedInt32Array = _pick_result.get("folded", PackedInt32Array())
	if not folded.is_empty():
		_fold(folded, t)
	_on_streak(_shot_pairs > 0 if _state.sweethearts else _shot_oranges > 0)
	var cleared: PackedInt32Array = _pick_result.cleared
	var step := minf(PICK_STEP, PICK_ALL / maxf(1.0, float(cleared.size())))
	if Motion.reduce:
		step = 0.0
	for k in cleared.size():
		var i := cleared[k]
		var at := t + 0.15 + step * float(k)
		_pick_at[i] = at
		_picking.append(i)
		var pitch := pow(2.0, float(SCALE[mini(k, SCALE.size() - 1)]) / 12.0)
		var where := _pt(_state.pos[i])
		var col: Color = Parts.colours(_state.kind[i])[1]
		get_tree().create_timer(at - t).timeout.connect(func():
			fx.cue("pop", pitch)
			fx.puff(where, col, 3))
	_pick_done = t + 0.15 + step * float(cleared.size()) + PICK_TIME
	_phase = "pick"
	_trails = []
	_trail = null
	_log += ("🟠" if (_shot_pairs > 0 if _state.sweethearts else _shot_oranges > 0) else "🔵") + ("🪴" if _shot_pot else "")
	if _state.oranges_left <= 0:
		_log += "🌈"
	var pts: int = _pick_result.points
	if pts > 0:
		get_tree().create_timer(_pick_done - t).timeout.connect(func():
			if is_inside_tree():
				_shot_total(pts))

## The blooms are picked: bank the shot and go on -- the next aim, the
## garden growing back, or the win.
func _after_pick(t: float) -> void:
	_picking = []
	_lit = null
	# the violet has moved
	_buds = []
	var free: int = _pick_result.get("free", 0)
	if free > 0:
		_tell("MG_FREE_ONE" if free == 1 else "MG_FREE", Face.Expr.JOY, [free])
		fx.cue("free")
		_big_shot(free, t)
	if _state.oranges_left <= 0:
		_phase = "won"
		if _state.left_bonus > 0:
			_sticker(tr("MG_LEFT") % [Locale.number(_state.left_bonus)], _row_at("left"), 56, 2.0, false, GOLD, true, "left")
			_kick_at = t
		check_solved()
		return
	if _state.is_out():
		_out_of_seeds(t)
		return
	_phase = "aim"
	_shot_oranges = 0
	_shot_pairs = 0
	_shot_pot = false
	_guide = null
	if _state.seeds == 1:
		_tell("MG_LAST", Face.Expr.WORRIED)
	else:
		_cycle_tip()

## Out of seeds with a marigold up: the garden grows back for another try --
## free on Easy and Medium, a heart on Hard and Insane, and out of hearts the
## sun falls asleep.
func _out_of_seeds(t: float) -> void:
	_mood(Face.Expr.WORRIED, OUT_WAIT)
	_phase = "out"
	_out_at = t
	if max_hearts > 0:
		_lose_heart(t)
		if out_of_hearts:
			_run_out()
			return
		_tell("MG_OUT_HEART_ONE" if hearts == 1 else "MG_OUT_HEART", Face.Expr.WORRIED, [] if hearts == 1 else [hearts])
		return
	_tell("MG_OUT", Face.Expr.WORRIED)
	fx.cue("out")

## Out of seeds: the same garden grows back, a try later.
func _regrow(t: float) -> void:
	_state.regrow()
	_fresh(t)
	_log += "·"
	fx.cue("reset")
	_say(tr("MG_TRY") % [_state.tries], Face.Expr.HAPPY)

func _float(at: Vector2, text: String, col: Color) -> void:
	_floats.append({"at": at, "text": text, "col": col, "t": _now()})

func _mood(expr: int, seconds: float) -> void:
	_expr = expr
	_expr_until = _now() + seconds

# --- the rewards ---

## What a bloom throws: petals in its own colour and sparks, more the
## further into the shot; a marigold gold stars and a ring, a violet a burst
## of its own stars, a clover its leaves.
func _bloom_bits(i: int, n: int) -> void:
	var at := _pt(_state.pos[i])
	var s := _s()
	var k := s / 9.5
	var c: Array = Parts.colours(_state.kind[i])
	var loud := mini(n, 24)
	_spray(_bits, at, c[1], 3 + loud / 4, 200.0 + 10.0 * float(loud), "petal", k)
	_spray(_bits, at, Color("fffaf0"), 1 + loud / 6, 240.0 + 8.0 * float(loud), "spark", k)
	match _state.kind[i]:
		State.ORANGE:
			_spray(_bits, at, GOLD, 4, 340.0, "star", k)
			_spray(_bits, at, Pal.MG_ORANGE, 3, 260.0, "petal", k * 1.3)
			_ring(_bits, at, s * 5.0, Color(GOLD, 0.85))
		State.PURPLE:
			_spray(_bits, at, Pal.MG_PURPLE_HI, 10, 420.0, "star", k)
			_ring(_bits, at, s * 6.0, Color(Pal.MG_PURPLE_HI, 0.85))
		State.GREEN:
			_spray(_bits, at, Pal.MG_GREEN_HI, 8, 320.0, "leaf", k * 1.2)
			_ring(_bits, at, s * 4.5, Color(Pal.MG_GREEN_HI, 0.8))
	if n >= 15:
		_spray(_bits, at, STICKER_COLS[n % STICKER_COLS.size()], 3, 380.0, "star", k * 0.8)

## A long shot's word, the loudest it has reached, over the garden; the sun
## hops and the card flashes from the third.
func _shot_word(n: int) -> void:
	for w in WORDS.size():
		if n < int(WORDS[w][0]):
			continue
		var tier := WORDS.size() - 1 - w
		if tier <= _word_tier:
			return
		_word_tier = tier
		_sticker(tr(WORDS[w][1]), _row_at("word"), 64 + 10 * tier, 1.3 + 0.15 * float(tier), true, Color.WHITE, tier >= 2, "word")
		fx.cue("free", 1.0 + 0.08 * float(tier), -6.0)
		_hop_at = _now()
		_mood(Face.Expr.JOY, 1.0)
		_frog_jump(tier >= 3)
		if tier >= 2:
			_shades_on(SHADES_STAY)
		if tier >= 1:
			_ducks()
		if tier >= 2:
			_flash_now(Color("fff4c2"), 0.2 + 0.08 * float(tier - 2))
			_shake = maxf(_shake, 0.3 + 0.1 * float(tier))
		return

## Two, three, four marigolds in one shot.
func _bunch(n: int) -> void:
	var key: String = BUNCH[mini(n, BUNCH.size() - 1)]
	var text := tr(key) % n if n >= BUNCH.size() - 1 else tr(key)
	_sticker(text, _row_at("bunch"), 60, 1.3, false, Pal.MG_ORANGE_HI, n >= 3, "bunch")
	_hop_at = _now()

## The multiplier steps up: the tag throws stars, and its new worth is
## lettered across the garden over a sunburst.
func _step_up(m: int) -> void:
	_sticker(tr("MG_MULT") % m, _row_at("mult"), 84, 1.6, false, Pal.MG_ORANGE_HI, true, "mult")
	_spray(_air_bits, _tag_centre(), GOLD, 10, 520.0, "star", 1.0)
	_spray(_air_bits, _tag_centre(), Color("fffaf0"), 8, 420.0, "spark", 1.2)
	_ring(_air_bits, _tag_centre(), 110.0, Color(Pal.MG_ORANGE_HI, 0.9))
	_flash_now(Color("ffd58a"), 0.3)
	_shake = maxf(_shake, 0.35)
	fx.cue("free", 1.25, -4.0)

## A seed caught by the pot: a word over it, a burst of gold, and the seed
## flying back up into the trough.
func _caught(at: Vector2, t: float) -> void:
	_sticker(tr("MG_CAUGHT"), _cam * at - Vector2(0.0, 150.0), 64, 1.2, false, Color("7fd66a"), false, "caught")
	_spray(_bits, at, GOLD, 8, 420.0, "star", _s() / 9.5)
	_spray(_bits, at, Color("b8f0a0"), 8, 360.0, "spark", _s() / 9.5)
	_ring(_bits, at, _s() * 7.0, Color(Pal.SUN_RAY, 0.9))
	_frog_jump(false)
	if not Motion.reduce:
		_seed_flies.append({"from": _cam * at, "t": t + 0.1})
		_hud = null

## The shot's points, lettered over the garden as the blooms are banked,
## bigger and brighter the more; the score kicks and throws stars.
func _shot_total(pts: int) -> void:
	var text := "+%s" % Locale.number(pts)
	var tier := 0
	for edge: int in [1000, 5000, 15000, 40000]:
		if pts >= edge:
			tier += 1
	var cols := [Pal.PAPER, Pal.SUN_RAY, Pal.MG_ORANGE_HI, GOLD, GOLD]
	_sticker(text, _row_at("total"), 52 + 8 * tier, 1.3 + 0.1 * float(tier), tier >= 4, cols[tier], tier >= 3, "total")
	_kick_at = _now()
	var score_at := Vector2(size.x * 0.5, 40.0)
	_spray(_air_bits, score_at, GOLD, 3 + 2 * tier, 300.0 + 60.0 * float(tier), "star", 0.8)
	if tier >= 2:
		_ring(_air_bits, score_at, 90.0 + 20.0 * float(tier), Color(GOLD, 0.8))
	if tier >= 3:
		_flash_now(Color("fff4c2"), 0.25)
		_rain = maxf(_rain, 0.8)
		_rain_coins = true

## A shot big enough to hand seeds back: a word, and the seeds flying from
## the score into the trough.
func _big_shot(free: int, t: float) -> void:
	_sticker(tr("MG_BIG_SHOT"), _row_at("big"), 80, 1.8, true, Color.WHITE, true, "big")
	_flash_now(Color("fff4c2"), 0.35)
	_shake = maxf(_shake, 0.5)
	_hop_at = t
	if Motion.reduce:
		return
	for k in free:
		_seed_flies.append({"from": Vector2(size.x * 0.5, 60.0), "t": t + 0.25 + 0.15 * float(k)})
	_hud = null

## The last marigold opens: FULL BLOOM lettered over a sunburst, the card
## flashing gold, and petals and confetti raining down the whole garden.
func _full_bloom(at: Vector2) -> void:
	_stickers = []
	_sticker(tr("MG_FEVER"), Vector2(size.x * 0.5, _pt(Vector2(0.0, 48.0)).y), BANNER_FONT, BANNER_TIME, true, Color.WHITE, true, "fever")
	_flash_now(Color("fff4c2"), 0.6)
	_shake = maxf(_shake, 0.8)
	_rain = maxf(_rain, PETAL_TIME - 1.0)
	_rain_coins = false
	_shades_on(30.0)
	_ducks()
	var s := _s()
	_spray(_bits, at, GOLD, 16, 620.0, "star", s / 9.5)
	_spray(_bits, at, Pal.MG_ORANGE_HI, 18, 520.0, "petal", s / 9.5 * 1.3)
	_ring(_bits, at, s * 10.0, Color(GOLD, 0.9))
	_ring(_bits, at, s * 16.0, Color(Pal.MG_ORANGE_HI, 0.7), 0.12)

## A pot of the full bloom: its worth lettered over it, gold raining, and
## the middle pot's hundred thousand a jackpot of its own.
func _jackpot(k: int, at: Vector2) -> void:
	var worth: int = State.FEVER_POTS[k]
	var top := worth >= 100000
	_sticker("+%s" % Locale.number(worth), _cam * at - Vector2(0.0, 220.0), 72 if not top else 88, 2.2, top, GOLD, true, "pot")
	if top:
		_sticker(tr("MG_JACKPOT"), _row_at("jackpot"), 96, 2.4, true, Color.WHITE, true, "jackpot")
	_spray(_bits, at, GOLD, 14 if top else 8, 600.0, "coin", _s() / 9.5)
	_spray(_bits, at, Color("fffaf0"), 10, 480.0, "spark", _s() / 9.5)
	_ring(_bits, at, _s() * 12.0, Color(GOLD, 0.9))
	_flash_now(Color("ffe39a"), 0.5 if top else 0.3)
	_shake = maxf(_shake, 0.9 if top else 0.6)
	_rain = maxf(_rain, 3.0 if top else 1.6)
	_rain_coins = true
	_kick_at = _now()

## The rewards' own clocks: the bits, the stickers, the glow, the flash,
## the shake and the rain.
func _tick_rewards(t: float, delta: float) -> void:
	_step_bits(_bits, delta * _slow)
	_step_bits(_air_bits, delta)
	for st: Dictionary in _stickers:
		st.t += delta
	_stickers = _stickers.filter(func(st: Dictionary) -> bool: return st.t < st.life)
	_flash = maxf(0.0, _flash - delta * 2.0)
	_shake = maxf(0.0, _shake - delta * 2.2)
	var want := 0.0
	if _phase == "shot":
		want = clampf(float(_state.shot_hits - 5) / 15.0, 0.0, 1.0)
	_heat = move_toward(_heat, want, delta * (1.5 if want > _heat else 0.6))
	var keep: Array = []
	for f: Dictionary in _seed_flies:
		if t - float(f.t) < SEED_FLY:
			keep.append(f)
	for j in _seed_flies.size() - keep.size():
		var slot := _trough_at(_state.seeds - keep.size() - 1 - j)
		_ring(_air_bits, slot, 30.0, Color(GOLD, 0.9))
		_spray(_air_bits, slot, Color("fffaf0"), 5, 220.0, "spark", 0.7)
	if keep.size() != _seed_flies.size():
		_seed_flies = keep
		_hud = null
	if _rain > 0.0:
		_rain -= delta
		if not Motion.reduce and randf() < delta * 34.0:
			var r := randf()
			var kind := "coin" if _rain_coins and r < 0.45 else ("star" if r < (0.6 if _rain_coins else 0.25) else "petal")
			if _won and _state.sweethearts and r > 0.8:
				kind = "heart"
			var col: Color = GOLD if kind != "petal" else PETALS[randi() % PETALS.size()]
			if kind == "heart":
				col = ROSE
			_air_bits.append({"pos": Vector2(randf_range(0.0, size.x), -30.0), "vel": Vector2(randf_range(-50.0, 50.0), randf_range(150.0, 280.0)),
				"rot": randf() * TAU, "spin": randf_range(-4.0, 4.0), "t": 0.0, "life": 4.0, "kind": kind, "col": col,
				"size": randf_range(1.0, 1.5), "float": true})

## The seeds in the air, not yet in the trough.
func _seeds_flying(t: float) -> int:
	var n := 0
	for f: Dictionary in _seed_flies:
		if t - float(f.t) < SEED_FLY:
			n += 1
	return n

## The middle of the `k`th seed's place in the trough.
func _trough_at(k: int) -> Vector2:
	return Vector2(INSET + 22.0 + float(clampi(k, 0, 9)) * 30.0, 38.0)

## Bits move: thrown, pulled down, slowed by the air; rain drifts down
## swaying.
func _step_bits(bits: Array, delta: float) -> void:
	if bits.is_empty():
		return
	var drag := exp(-delta * 2.2)
	for b: Dictionary in bits:
		b.t += delta
		if b.t < 0.0 or String(b.kind) == "ring":
			continue
		var v: Vector2 = b.vel
		if b.get("float", false):
			v.y = minf(v.y + 100.0 * delta, 280.0)
			b.pos += Vector2(v.x + sin(b.t * 3.0 + b.rot) * 60.0, v.y) * delta
		else:
			v *= drag
			v.y += (700.0 if String(b.kind) in ["petal", "leaf"] else 1500.0) * delta
			b.pos += v * delta
		b.vel = v
		b.rot += float(b.spin) * delta
	var keep := bits.filter(func(b: Dictionary) -> bool: return b.t < b.life)
	bits.clear()
	bits.append_array(keep)

## Throws `n` bits of `kind` out of `at` at up to `speed` pixels a second.
func _spray(bits: Array, at: Vector2, col: Color, n: int, speed: float, kind := "spark", sz := 1.0, delay := 0.0) -> void:
	if Motion.reduce:
		return
	n = mini(n, MAX_BITS - bits.size())
	for i in n:
		var v := Vector2.from_angle(randf() * TAU) * speed * randf_range(0.35, 1.0) + Vector2(0, -speed * 0.45)
		bits.append({"pos": at, "vel": v, "rot": randf() * TAU, "spin": randf_range(-10.0, 10.0), "t": -delay,
			"life": randf_range(0.55, 0.95) + (0.5 if kind in ["petal", "leaf", "coin"] else 0.0), "kind": kind,
			"col": col, "size": sz * randf_range(0.7, 1.25)})

## A ring swelling out of `at` to `radius` and fading.
func _ring(bits: Array, at: Vector2, radius: float, col: Color, delay := 0.0) -> void:
	if Motion.reduce:
		return
	bits.append({"pos": at, "vel": Vector2.ZERO, "rot": 0.0, "spin": 0.0, "t": -delay, "life": 0.45, "kind": "ring",
		"col": col, "size": radius})

func _flash_now(col: Color, amount: float) -> void:
	if Motion.reduce:
		return
	_flash = maxf(_flash, amount)
	_flash_col = col

## The first sticker row over the garden no other sticker is standing in,
## in the card's pixels.
func _row_at(id: String) -> Vector2:
	for y: float in STICKER_ROWS:
		var p := Vector2(size.x * 0.5, _pt(Vector2(0.0, y)).y)
		var free := true
		for st: Dictionary in _stickers:
			if String(st.id) != id and absf(Vector2(st.at).y - p.y) < 60.0 and st.t < float(st.life) - 0.3:
				free = false
				break
		if free:
			return p
	return Vector2(size.x * 0.5, _pt(Vector2(0.0, STICKER_ROWS[0])).y)

## A word lettered at `at` (the card's pixels), each letter hopping in on
## its own and fitted to the card. `rainbow` letters it in the sticker
## colours, else in `col`; `rays` sets a sunburst turning behind it. A
## sticker with an `id` replaces the one before it with the same id.
func _sticker(text: String, at: Vector2, px: int, life: float, rainbow := true, col := Color.WHITE, rays := false, id := "") -> void:
	if id != "":
		_stickers = _stickers.filter(func(st: Dictionary) -> bool: return String(st.id) != id)
	var room := size.x - 80.0
	var w: float = CozyTheme.display(700).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if w > room:
		px = int(float(px) * room / w)
		w = room
	at.x = clampf(at.x, w * 0.5 + 40.0, size.x - w * 0.5 - 40.0)
	at.y = clampf(at.y, BAND + px * 0.6, size.y - px)
	# the letters' advances, measured once
	var font: Font = CozyTheme.display(700)
	var adv := PackedFloat32Array()
	var total := 0.0
	for i in text.length():
		adv.append(font.get_char_size(text.unicode_at(i), px).x)
		total += adv[i]
	_stickers.append({"text": text, "at": at, "t": 0.0, "life": life, "size": px, "rainbow": rainbow, "col": col,
		"rays": rays and not Motion.reduce, "tilt": 0.0 if Motion.reduce else randf_range(-0.08, 0.08), "id": id,
		"adv": adv, "w": total})
	queue_redraw()

# --- Sweethearts (Insane) ---

## A marigold's sweetheart bloomed in the same shot: the pair stays open.
## Love hearts rise off both, a ring round each, and a word.
func _sweethearts(i: int, j: int) -> void:
	_shot_pairs += 1
	var a := _pt(_state.pos[i])
	var c := _pt(_state.pos[j])
	var k := _s() / 9.5
	for at: Vector2 in [a, c]:
		_spray(_bits, at, ROSE, 5, 260.0, "heart", k * 1.3)
		_ring(_bits, at, _s() * 6.0, Color(ROSE, 0.85))
	_spray(_bits, a.lerp(c, 0.5), Color("fff0f5"), 6, 300.0, "spark", k)
	_threads = null
	fx.cue("pair", 1.0 + 0.06 * float(mini(_shot_pairs - 1, 6)))
	_hop_at = _now()
	if _state.fever:
		return
	if _shot_pairs >= 2:
		_bunch(_shot_pairs)
	else:
		_sticker(tr("MG_PAIR"), _row_at("bunch"), 60, 1.2, false, ROSE, false, "bunch")

## The shot ended with marigolds whose sweethearts stayed shut: each droops
## and folds back into a bud, its pip empties, and the garden says so.
func _fold(folded: PackedInt32Array, t: float) -> void:
	var k := _s() / 9.5
	for i in folded:
		# one the stuck seed cleared has faded already: no bloom to shut,
		# the bud just pops back
		_fold_at[i] = t - FOLD_TIME * 0.7 if _pick_at[i] >= 0.0 else t
		_hit_at[i] = maxf(_hit_at[i], 0.0)
		_pick_at[i] = -1.0
		_picking.erase(i)
		_spray(_bits, _pt(_state.pos[i]), Color("b7a9c9"), 4, 160.0, "petal", k)
	_fold_until = t + FOLD_TIME
	_threads = null
	_buds = []
	_hud = null
	var filled := _pips_filled(t)
	for n in folded.size():
		_spray(_air_bits, _pip_at(filled + n), Color("c9bcd8"), 3, 140.0, "petal", 0.6)
	fx.cue("apart")
	_mood(Face.Expr.WORRIED, 1.2)
	_sticker(tr("MG_APART"), _row_at("apart"), 64, 1.4, false, Color("b8a6d9"), false, "apart")
	if not _apart_told:
		_apart_told = true
		_tell("MG_APART_TIP", Face.Expr.WORRIED)

## The ribbons tying each pair of sweethearts, under the buds: soft while
## both are shut, bright while one waits open in a shot, gold once both
## bloomed; a picked pair's ribbon is gone. Cached on what it shows.
func _draw_threads(t: float, xf: Transform2D, tint: Color, shown: Array) -> void:
	var waiting := PackedInt32Array()
	if _phase == "shot":
		waiting = _state.shot_bloomed
	var key := "%d|%d|%d|%d" % [hash(_state.st), hash(waiting), int(size.x), int(size.y)]
	if _threads == null or _threads_for != key:
		var b := Face.Builder.new()
		var s := _s()
		for i in _state.pos.size():
			var j: int = _state.pair[i]
			if j <= i:
				continue
			var si: int = _state.st[i]
			var sj: int = _state.st[j]
			if si == State.GONE and sj == State.GONE:
				continue
			var col: Color = RIBBONS[_ribbon[i] % RIBBONS.size()]
			var width := 0.36
			var alpha := 0.75
			if si == State.LIT and sj == State.LIT:
				col = GOLD
				alpha = 0.85
				width = 0.34
			elif si == State.LIT or sj == State.LIT:
				width = 0.42
				alpha = 1.0
			var a: Vector2 = _state.pos[i]
			var z: Vector2 = _state.pos[j]
			var ctrl := (a + z) * 0.5 + Vector2(0.0, 3.0 + 0.16 * a.distance_to(z))
			var pts := PackedVector2Array()
			for n in 25:
				var u := float(n) / 24.0
				pts.append(_pt(a.lerp(ctrl, u).lerp(ctrl.lerp(z, u), u)))
			if alpha >= 1.0:
				b.stroke(pts, s * width * 2.6, Color(col, 0.22))
			b.stroke(pts, s * width * 1.8, Color(col.darkened(0.35), alpha * 0.35))
			b.stroke(pts, s * width, Color(col, alpha))
			# a collar in the ribbon's colour round each end, so a pair is
			# told at a glance
			for e: Vector2 in [a, z]:
				b.disc(_pt(e), s * State.PEG_R * 1.55, Color(col.darkened(0.2), 0.9))
				b.disc(_pt(e), s * State.PEG_R * 1.35, col)
		_threads = b.mesh() if not b.verts.is_empty() else null
		_threads_for = key
	_put(_threads, xf, tint, shown)

# --- the streak and the silly ones ---

## Shots in a row that keep a marigold (a pair on Insane): from the second a
## word with a note up the scale, confetti from the third.
func _on_streak(kept: bool) -> void:
	if not kept:
		_streak = 0
		return
	_streak += 1
	if _streak < STREAK_FROM or _state.oranges_left <= 0:
		return
	var n := _streak
	get_tree().create_timer(0.45).timeout.connect(func():
		if not is_inside_tree() or _phase in ["asleep", "out"] or _streak != n:
			return
		_sticker(tr("MG_STREAK") % n, _row_at("streak"), 54 + 4 * mini(n, 6), 1.3, true, Color.WHITE, n >= 4, "streak")
		fx.cue("combo", pow(2.0, float(SCALE[mini(n - STREAK_FROM, SCALE.size() - 1)]) / 12.0))
		if n >= 3 and not Motion.reduce:
			fx.confetti(Vector2(size.x * 0.5, BAND + 30.0), 12 + 4 * mini(n, 6), size.x * 0.8)
			fx.cue("confetti", 1.0, -4.0))

## The frog croaks at a seed that falls past the pot.
func _croak(t: float) -> void:
	if t - _frog_croak_at < FROG_CROAK * 2.0 or t - _frog_hop_at < FROG_HOP:
		return
	_frog_croak_at = t
	fx.cue("ribbit", randf_range(0.94, 1.08), -5.0)

## The frog hops on its pad (turning a somersault when `flip`), croaking,
## and the pad rings the water when it lands.
func _frog_jump(flip: bool) -> void:
	var t := _now()
	if t - _frog_hop_at < FROG_HOP + 0.2 or Motion.reduce:
		return
	_frog_hop_at = t
	_frog_flip = flip
	_frog_croak_at = t
	fx.cue("ribbit", 1.12 if flip else 1.0, -3.0)
	get_tree().create_timer(FROG_HOP).timeout.connect(func():
		if is_inside_tree():
			_ripples.append({"at": FROG_AT + Vector2(0.0, 0.4), "t": _now(), "col": Pal.MG_SHINE})
			fx.cue("splash", 1.0, -8.0))

## The sun puts its sunglasses on for a while.
func _shades_on(stay: float) -> void:
	var t := _now()
	if t >= _shades_until:
		_shades_at = t
		fx.cue("shades", 1.0, -4.0)
	_shades_until = maxf(_shades_until, t + stay)

## A duck and her ducklings paddle across the pond, quacking.
func _ducks() -> void:
	var t := _now()
	if t - _ducks_at < DUCK_TIME or Motion.reduce:
		return
	_ducks_at = t
	fx.cue("quack", 1.0, -6.0)

## A field point of the frog's body (about its middle, field units) to the
## card's pixels: squashed, turned and lifted.
func _frog_pt(v: Vector2, mid: Vector2, sq: Vector2, turn: float) -> Vector2:
	return _pt(mid + (v * sq * 1.3).rotated(turn))

## The frog on the left lily pad: round and green, eyes on top following the
## seed, a smile, a throat that puffs when it croaks; it hops and lands
## squashing.
func _draw_frog(b: Face.Builder, t: float) -> void:
	var s := _s()
	var e := t - _frog_hop_at
	var lift := 0.0
	var turn := 0.0
	var sq := Vector2.ONE
	if e < FROG_HOP:
		var u := e / FROG_HOP
		lift = sin(PI * u) * 8.0
		turn = TAU * u * u * (3.0 - 2.0 * u) if _frog_flip else sin(PI * u) * 0.25
		sq = Vector2(1.0 - 0.12 * sin(PI * u), 1.0 + 0.15 * sin(PI * u))
	elif e < FROG_HOP + 0.2:
		var u := (e - FROG_HOP) / 0.2
		sq = Vector2(1.0 + 0.2 * sin(PI * u), 1.0 - 0.2 * sin(PI * u))
	var mid := FROG_AT + Vector2(0.0, -1.2 - lift)
	b.ellipse(_pt(FROG_AT + Vector2(0.0, 0.2)), s * 2.0 / (1.0 + lift * 0.1), s * 0.5 / (1.0 + lift * 0.1), Color(Pal.MG_POND_DEEP, 0.55))
	var green := Color("79c26b")
	var deep := Color("4f9150")
	for sx: float in [-1.0, 1.0]:
		b.ellipse(_frog_pt(Vector2(sx * 1.1, 0.7), mid, sq, turn), s * 0.95 * sq.x, s * 0.55 * sq.y, deep)
	b.ellipse(_frog_pt(Vector2.ZERO, mid, sq, turn), s * 1.55 * 1.3 * sq.x, s * 1.2 * 1.3 * sq.y, green)
	b.ellipse(_frog_pt(Vector2(0.0, 0.4), mid, sq, turn), s * 1.0 * 1.3 * sq.x, s * 0.7 * 1.3 * sq.y, Color("cfe9a8"))
	var c := t - _frog_croak_at
	if c < FROG_CROAK:
		var puff := sin(PI * c / FROG_CROAK)
		b.disc(_frog_pt(Vector2(0.0, 0.35), mid, sq, turn), s * (0.4 + 0.6 * puff) * 1.3, Color("f4c6cf"))
	for sx: float in [-1.0, 1.0]:
		b.disc(_frog_pt(Vector2(sx * 0.62, 1.15), mid, sq, turn), s * 0.32, deep)
		b.disc(_frog_pt(Vector2(sx * 1.0, 0.05), mid, sq, turn), s * 0.22, Color("f4a3a0", 0.7))
	# eyes on top, looking at the seed (or up at the sun)
	var target := State.SUN_C
	if not _state.balls.is_empty():
		target = Vector2(_state.balls[0].p)
	var look := (target - mid).normalized() * 0.14
	var shut := fmod(t + 1.3, 4.7) < 0.13
	for sx: float in [-1.0, 1.0]:
		var at := _frog_pt(Vector2(sx * 0.7, -1.0), mid, sq, turn)
		b.disc(at, s * 0.62 * 1.3, green)
		if shut:
			b.stroke(PackedVector2Array([at + Vector2(-0.4, 0.0) * s, at + Vector2(0.4, 0.0) * s]), s * 0.16, Pal.TEXT)
		else:
			b.disc(at, s * 0.44 * 1.3, Color("fffaf0"))
			b.disc(at + look * s * 1.3 * 1.5, s * 0.24 * 1.3, Pal.TEXT)
	var m := _frog_pt(Vector2(0.0, -0.35), mid, sq, turn)
	b.stroke(Face.Builder.arc_points(m, s * 0.75, PI * 0.18 + turn, PI * 0.82 + turn), s * 0.14, deep, false, false)

## A duck and three ducklings paddling across the pond, bobbing, each with a
## little wake; they fade in and out at the pond's edges.
func _draw_ducks(b: Face.Builder, t: float) -> void:
	var e := t - _ducks_at
	if e < 0.0 or e > DUCK_TIME:
		return
	var s := _s()
	var x0 := lerpf(-6.0, State.W + 20.0, e / DUCK_TIME)
	for k in 4:
		var mother := k == 0
		var x := x0 - (0.0 if mother else 5.4 + 4.0 * float(k - 1))
		var fade := clampf(minf(x - 2.0, State.W - 2.0 - x) / 4.0, 0.0, 1.0)
		if fade <= 0.0:
			continue
		var r := 2.1 if mother else 1.3
		var body := Color("fbf3dc") if mother else Color("ffd84d")
		var c := Vector2(x, 66.0 + float(k) * 0.6 + sin(t * 5.0 + float(k) * 1.3) * 0.16)
		b.stroke(PackedVector2Array([_pt(c + Vector2(-r * 1.1, r * 0.5)), _pt(c + Vector2(-r * 2.8, r * 0.95))]), s * 0.16, Color(Pal.MG_SHINE, 0.45 * fade))
		b.stroke(PackedVector2Array([_pt(c + Vector2(-r * 1.1, r * 0.55)), _pt(c + Vector2(-r * 2.6, r * 0.2))]), s * 0.16, Color(Pal.MG_SHINE, 0.3 * fade))
		b.ellipse(_pt(c + Vector2(0.0, r * 0.55)), r * 1.3 * s, r * 0.22 * s, Color(Pal.MG_POND_DEEP, 0.45 * fade))
		b.fan(PackedVector2Array([_pt(c + Vector2(-r * 0.9, -r * 0.1)), _pt(c + Vector2(-r * 1.55, -r * 0.6)), _pt(c + Vector2(-r * 0.6, -r * 0.4))]),
			Color(body.darkened(0.08), fade))
		b.ellipse(_pt(c), r * 1.2 * s, r * 0.62 * s, Color(body, fade))
		b.ellipse(_pt(c + Vector2(-r * 0.15, -r * 0.12)), r * 0.6 * s, r * 0.3 * s, Color(body.darkened(0.1), fade))
		var head := c + Vector2(r * 0.8, -r * 0.8)
		b.disc(_pt(head), r * 0.5 * s, Color(body, fade))
		b.fan(PackedVector2Array([_pt(head + Vector2(r * 0.35, -r * 0.08)), _pt(head + Vector2(r * 0.85, r * 0.06)), _pt(head + Vector2(r * 0.35, r * 0.2))]),
			Color(Color("f2a23a"), fade))
		b.disc(_pt(head + Vector2(r * 0.15, -r * 0.12)), r * 0.09 * s + 1.0, Color(Pal.TEXT, fade))

# --- hearts ---

func _lose_heart(t: float) -> void:
	_lost_ever = true
	hearts = maxi(0, hearts - 1)
	_split_index = hearts
	_split_at = t
	out_of_hearts = hearts <= 0
	_log += "💔"
	_streak = 0
	_hearts_mesh = null
	fx.cue("heart_lost")

## The hearts on a little wooden sign hung off the arch, left of the sun: a
## lost one splits and falls, a heart given back pops in.
func _draw_hearts(t: float, xf: Transform2D, tint: Color, shown: Array) -> void:
	var s := _s()
	var moving := not Motion.reduce and (t - _split_at < SPLIT_TIME or t - _back_at < HEART_BACK_TIME)
	var key := "%d|%d|%d" % [hearts, max_hearts, int(s * 100.0)]
	if _hearts_mesh == null or _hearts_for != key or moving:
		var b := Face.Builder.new()
		var step := (2.0 * HEART_R + HEART_GAP) * s
		var w := step * float(max_hearts) + HEART_GAP * s
		var h := (2.0 * HEART_R + 1.4) * s
		var mid := _pt(SIGN_AT)
		var top := mid.y - h * 0.5
		# two strings up to the arch, then the plank
		for sx: float in [-0.36, 0.36]:
			var x := mid.x + sx * w
			b.stroke(PackedVector2Array([Vector2(x, _origin().y - s * 0.6), Vector2(x, top + s * 0.4)]), s * 0.16, Pal.MG_ARBOR_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(mid.x - w * 0.5, top + s * 0.35), Vector2(w, h), s * 1.0), Pal.MG_ARBOR_DEEP.darkened(0.2))
		b.fan(Face.Builder.round_rect(Vector2(mid.x - w * 0.5, top), Vector2(w, h), s * 1.0), Pal.MG_ARBOR)
		b.stroke(PackedVector2Array([Vector2(mid.x - w * 0.42, top + s * 0.45), Vector2(mid.x + w * 0.42, top + s * 0.45)]), s * 0.22,
			Color(Pal.MG_ARBOR_HI, 0.7))
		for sx: float in [-0.36, 0.36]:
			b.disc(Vector2(mid.x + sx * w, top + s * 0.5), s * 0.28, Pal.MG_ARBOR_DEEP)
		var x0 := mid.x - w * 0.5 + HEART_GAP * s + HEART_R * s
		var r := HEART_R * s
		for i in max_hearts:
			var at := Vector2(x0 + step * float(i), mid.y + s * 0.2)
			if i < hearts:
				var rr := r
				if i == _back_index and not Motion.reduce:
					rr *= Motion.pop_in_scale(t - _back_at, HEART_BACK_TIME).x
				if rr > 0.5:
					b.polygon(_heart(at, rr, -1), Pal.FLOWER)
					b.polygon(_heart(at, rr, 1), Pal.FLOWER_DEEP)
					_heart_face(b, at, rr)
				continue
			b.polygon(_heart(at, r, 0), Color(Pal.MG_ARBOR_DEEP, 0.55))
			var u := (t - _split_at) / SPLIT_TIME
			if i == _split_index and u < 1.0 and not Motion.reduce:
				var fade := 1.0 - u * u
				for side in [-1, 1]:
					var turn: float = side * SPLIT_TURN * u
					var shift := Vector2(side * SPLIT_SPREAD * u, SPLIT_FALL * u * u) * s
					var pts := _heart(Vector2.ZERO, r, side)
					for k in pts.size():
						pts[k] = at + shift + pts[k].rotated(turn)
					b.polygon(pts, Color(Pal.FLOWER if side < 0 else Pal.FLOWER_DEEP, fade))
		_hearts_mesh = b.mesh()
		_hearts_for = key
	_put(_hearts_mesh, xf, tint, shown)

static func _heart_face(b: Face.Builder, at: Vector2, s: float) -> void:
	b.ellipse(at + Vector2(-0.5, -0.5) * s, 0.16 * s, 0.1 * s, Color(1.0, 1.0, 1.0, 0.45))
	for sx in [-1.0, 1.0]:
		b.disc(at + Vector2(sx * 0.28, -0.12) * s, 0.09 * s, Pal.OUTLINE)
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, 0.02) * s, 0.16 * s, PI * 0.2, PI * 0.8), 0.07 * s, Pal.OUTLINE)

## A heart about `at`, `s` to its side; `side` -1 or 1 is one half, split
## down a zigzag (Super Slider's).
static func _heart(at: Vector2, s: float, side: int) -> PackedVector2Array:
	const STEPS := 36
	var k := s / 16.0
	var off := Vector2(0.0, -2.5)
	var pts := PackedVector2Array()
	var from := 0.0 if side >= 0 else PI
	var to := TAU if side == 0 else from + PI
	var count := STEPS if side == 0 else STEPS / 2 + 1
	for i in count:
		var u := lerpf(from, to, float(i) / float(STEPS if side == 0 else STEPS / 2))
		var p := Vector2(16.0 * pow(sin(u), 3.0),
			-(13.0 * cos(u) - 5.0 * cos(2.0 * u) - 2.0 * cos(3.0 * u) - cos(4.0 * u)))
		pts.append(at + (p + off) * k)
	if side == 0:
		return pts
	var zig := [Vector2(0.0, 13.0), Vector2(1.5, 8.0), Vector2(-1.5, 3.0), Vector2(1.0, -2.0)]
	if side < 0:
		zig.reverse()
	for z: Vector2 in zig:
		pts.append(at + (z + off) * k)
	return pts

## The last heart is gone: the sun nods off, dusk falls on the pond, and the
## out-of-hearts card comes up.
func _run_out() -> void:
	_phase = "asleep"
	_running = false
	_streak = 0
	_aiming = false
	_shades_until = _now()
	fx.cue("out_of_hearts")
	_mood(Face.Expr.SLEEPY, 1.0e6)
	_say(tr("MG_ASLEEP"), Face.Expr.SLEEPY)
	_dusk_toward(DUSK)
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
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["MG_OUT_BODY", "MG_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the garden as dealt, every heart back, the clock and the
## moves from zero. Hints spent stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	_state.restart()
	hearts = max_hearts
	out_of_hearts = false
	_split_index = -1
	_back_index = -1
	_hearts_mesh = null
	_streak = 0
	var t := _now()
	_fresh(t)
	_log += "·"
	elapsed = 0.0
	moves = 0
	_running = true
	_mood(Face.Expr.HAPPY, 0.0)
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	fx.cue("reset")
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	moved.emit()

## One more heart (the card's video), once a day: morning comes back and the
## garden grows back for one more try.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	var t := _now()
	_heart_used = true
	hearts = 1
	_back_index = 0
	_back_at = t
	out_of_hearts = false
	_hearts_mesh = null
	_running = true
	_state.regrow()
	_fresh(t)
	_log += "·"
	_mood(Face.Expr.HAPPY, 0.0)
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	_say(tr("MG_HEART_BACK"), Face.Expr.HAPPY)
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
	return absi(hash([_state.pos.size(), _state.kind0]))

## After the win: the frog turns a somersault, the ducks paddle by in a
## shower of confetti, the nap cat hops onto the right lily pad and curls
## up, a bit of garden wisdom, and the seal when the solve earned one
## (flawless, or any Sweethearts garden).
func _party() -> void:
	var t := _now()
	_party_at = t + (0.0 if Motion.reduce else PARTY_AT)
	_cat_at = _party_at
	if _flawless or _state.sweethearts:
		_stamp_at = t if Motion.reduce else _party_at + STAMP_AT
		_seal_mesh = null
		get_tree().create_timer(maxf(0.01, _stamp_at - t)).timeout.connect(func():
			if is_inside_tree():
				fx.cue("stamp"))
	get_tree().create_timer(PARTY_AT + 0.9).timeout.connect(func():
		if is_inside_tree():
			_say(tr("MG_CHEER_%d" % posmod(_day_hash(), CHEERS)), Face.Expr.JOY))
	if Motion.reduce:
		return
	get_tree().create_timer(PARTY_AT).timeout.connect(func():
		if not is_inside_tree():
			return
		fx.cue("party")
		fx.confetti(Vector2(size.x * 0.5, BAND + 20.0), 30, size.x * 0.9)
		_frog_jump(true)
		_ducks())

func _cat_px() -> float:
	return size.x * CAT_PX

## Where the cat curls up: on the right lily pad.
func _cat_spot() -> Vector2:
	return _pt(Vector2(87.0, 111.6))

func _cat_start() -> Vector2:
	return _pt(Vector2(State.W + 4.0, 111.6))

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

## The seal over the middle of the pond, dropping in and settling, its words
## over it: Flawless; on Sweethearts "Insane" over Flawless or Sweethearts,
## on the night seal.
func _draw_stamp(t: float, shown: Array) -> void:
	var rad := size.x * STAMP_R
	var insane: bool = _state.sweethearts
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := t - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := _pt(Vector2(54.0, 90.0))
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	draw_set_transform_matrix(xf)
	draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless else tr("MG_SWEET_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(self, rad, lines)
	draw_set_transform_matrix(Transform2D.IDENTITY)

# --- the drawing ---

func _draw() -> void:
	if _state.pos.is_empty() or _s() <= 0.0:
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := 1.0 if Motion.reduce else Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var grow := 1.0 if Motion.reduce else Motion.wide_pop_scale(since)
	var mid := size * 0.5
	# the HUD stands still; the garden goes through the view
	var hud := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var xf := _cam * hud
	var tint := Color(1.0, 1.0, 1.0, seen)
	var s := _s()
	var shown: Array = []
	if _still == null:
		_still = _build_still()
	_put(_still, xf, tint, shown)
	if _state.fever:
		if _back == null or t - _fever_at < 2.0:
			_back = _build_back(t)
		_put(_back, xf, tint, shown)
	if not Motion.reduce:
		_live_back = _build_live_back(t)
		_put(_live_back, xf, tint, shown)
	if _state.sweethearts:
		_draw_threads(t, xf, tint, shown)
	if _buds.size() != BUD_BANDS:
		_buds = []
		for k in BUD_BANDS:
			_buds.append(_build_buds(t, k))
	for k in BUD_BANDS:
		if _buds[k] == null:
			_buds[k] = _build_buds(t, k)
		_put(_buds[k], xf, tint, shown)
	if _lit == null:
		_lit = _build_lit(t)
	_put(_lit, xf, tint, shown)
	if _phase == "aim" and not _done:
		if _guide == null:
			_guide = _build_guide()
		_put(_guide, xf, tint, shown)
	if _phase == "shot":
		if _trail == null:
			_trail = _build_trail()
		_put(_trail, xf, tint, shown)
	# the pot, or the full bloom's five
	if not _state.fever:
		var glow := 0.0 if Motion.reduce else clampf(1.0 - (t - _pot_glow_at) / POT_GLOW_TIME, 0.0, 1.0)
		var gk := int(glow * 8.0)
		if _pot == null or _pot_for != gk:
			var b := Face.Builder.new()
			Parts.pot(b, _state.pot_w * s, float(gk) / 8.0)
			_pot = b.mesh()
			_pot_for = gk
		_put(_pot, xf * _pot_xf(t), tint, shown)
	# the seeds
	if _seed == null:
		var b := Face.Builder.new()
		Parts.kernel(b, Vector2.ZERO, State.BALL_R * s)
		_seed = b.mesh()
	for ball: Dictionary in _state.balls:
		var v: Vector2 = ball.v
		_put(_seed, xf * Transform2D(v.angle() if v.length() > 1.0 else PI * 0.5, _pt(ball.p)), tint, shown)
	_draw_sun(t, xf, tint, shown)
	if _state.fever:
		draw_set_transform_matrix(_cam)
		_draw_pot_worths(hud, seen)
		draw_set_transform(Vector2.ZERO)
	_draw_hud(t, hud, tint, shown)
	if max_hearts > 0:
		_draw_hearts(t, hud, tint, shown)
	if not Motion.reduce:
		_live = _build_live(t)
		_put(_live, xf, tint, shown)
	draw_set_transform_matrix(_cam)
	_draw_floats(t, seen)
	draw_set_transform(Vector2.ZERO)
	_air = _build_air(t)
	_put(_air, hud, tint, shown)
	_draw_count(t, hud, seen)
	_draw_stickers(hud, seen)
	if t >= _stamp_at:
		_draw_stamp(t, shown)
	_draw_toast(t, shown)
	_shown = shown

func _put(m: ArrayMesh, xf: Transform2D, tint: Color, shown: Array) -> void:
	if m == null:
		return
	draw_mesh(m, null, xf, tint)
	shown.append(m)

## The card, the dusk garden in the field, the bank along the foot, and the
## arbor round it. None of it ever moves.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _s()
	var o := _origin()
	var fw := State.W * s
	var fh := State.H * s
	_vgrad(b, Rect2(Vector2.ZERO, size), Pal.MG_CARD, Pal.MG_CARD_DEEP)
	# the sky, then the ranges, then the pond
	var horizon := 58.0
	_vgrad(b, Rect2(o, Vector2(fw, horizon * s)), Pal.MG_SKY_TOP, Pal.MG_SKY_LOW)
	# the moon, with a soft halo
	var moon := _pt(Vector2(81.0, 15.0))
	b.disc(moon, 9.0 * s, Color(Pal.MG_SHINE, 0.18))
	b.disc(moon, 6.2 * s, Color(Pal.MG_SHINE, 0.25))
	b.disc(moon, 4.2 * s, Pal.MOON)
	b.disc(moon + Vector2(1.6, -1.0) * s, 3.4 * s, Color(Pal.MG_SKY_TOP, 0.35))
	# a few stars
	for k in 14:
		var at := _pt(Vector2(4.0 + _hash(k, 3) * 92.0, 3.0 + _hash(k, 7) * 30.0))
		if at.distance_to(moon) < 9.0 * s:
			continue
		b.disc(at, s * (0.18 + 0.2 * _hash(k, 9)), Color(Pal.MG_SHINE, 0.8))
	_range(b, horizon, 17.0, 0.07, 1.3, Pal.MG_HILL_FAR, true)
	_range(b, horizon, 10.0, 0.11, 4.1, Pal.MG_HILL_NEAR, false)
	# a little castle on the far shore, as in the reference, in the near range's lilac
	var ca := Vector2(18.0, horizon - 6.0)
	for r: Rect2 in [Rect2(ca, Vector2(8.0, 6.0)), Rect2(ca + Vector2(-1.2, -4.0), Vector2(2.6, 10.0)),
			Rect2(ca + Vector2(6.6, -5.0), Vector2(2.6, 11.0)), Rect2(ca + Vector2(3.0, -2.5), Vector2(2.2, 8.5))]:
		b.fan(PackedVector2Array([_pt(r.position), _pt(r.position + Vector2(r.size.x, 0.0)),
			_pt(r.end), _pt(r.position + Vector2(0.0, r.size.y))]), Pal.MG_HILL_NEAR.darkened(0.08))
	for tip: Vector2 in [ca + Vector2(0.1, -4.0), ca + Vector2(7.9, -5.0), ca + Vector2(4.1, -2.5)]:
		b.fan(PackedVector2Array([_pt(tip + Vector2(-1.7, 0.0)), _pt(tip + Vector2(0.0, -2.8)), _pt(tip + Vector2(1.7, 0.0))]),
			Pal.MG_HILL_NEAR.darkened(0.16))
	b.disc(_pt(ca + Vector2(4.1, 1.5)), s * 0.5, Color(Pal.SUN_RAY, 0.9))
	# the pond, its far shore's reflection and its glints
	_vgrad(b, Rect2(o + Vector2(0.0, horizon * s), Vector2(fw, fh - horizon * s)), Pal.MG_POND, Pal.MG_POND_DEEP)
	_vgrad(b, Rect2(o + Vector2(0.0, horizon * s), Vector2(fw, 7.0 * s)), Color(Pal.MG_HILL_NEAR, 0.45), Color(Pal.MG_HILL_NEAR, 0.0))
	# the near range and the castle upside down in the water, faint
	var mirror := PackedVector2Array()
	for k in 41:
		var x := State.W * float(k) / 40.0
		var y := horizon - 10.0 * absf(sin(x * 0.11 + 4.1)) - 3.5 * sin(x * 0.11 * 2.3 + 8.2)
		mirror.append(_pt(Vector2(x, horizon + (horizon - y) * 0.55)))
	mirror.append(_pt(Vector2(State.W, horizon)))
	mirror.append(_pt(Vector2(0.0, horizon)))
	b.polygon(mirror, Color(Pal.MG_HILL_NEAR, 0.22))
	for r: Rect2 in [Rect2(ca + Vector2(0.0, 6.0), Vector2(8.0, 3.3)), Rect2(ca + Vector2(-1.2, 6.0), Vector2(2.6, 5.5)),
			Rect2(ca + Vector2(6.6, 6.0), Vector2(2.6, 6.0))]:
		b.fan(PackedVector2Array([_pt(r.position), _pt(r.position + Vector2(r.size.x, 0.0)),
			_pt(r.end), _pt(r.position + Vector2(0.0, r.size.y))]), Color(Pal.MG_HILL_NEAR.darkened(0.1), 0.25))
	# the moon's road across the water, breaking up as it comes near
	for k in 10:
		var y := horizon + 2.0 + float(k) * 3.6
		var half := (3.4 - float(k) * 0.22) * (0.55 + 0.45 * _hash(k, 81))
		var dx := (_hash(k, 83) - 0.5) * 1.6
		b.stroke(PackedVector2Array([_pt(Vector2(81.0 + dx - half, y)), _pt(Vector2(81.0 + dx + half, y))]), s * 0.5,
			Color(Pal.MG_SHINE, 0.5 - 0.04 * float(k)))
	# mist lying along the far shore
	_vgrad(b, Rect2(o + Vector2(0.0, (horizon - 4.0) * s), Vector2(fw, 4.0 * s)), Color(Pal.MG_SNOW, 0.0), Color(Pal.MG_SNOW, 0.35))
	_vgrad(b, Rect2(o + Vector2(0.0, horizon * s), Vector2(fw, 3.5 * s)), Color(Pal.MG_SNOW, 0.3), Color(Pal.MG_SNOW, 0.0))
	for k in 22:
		var y := horizon + 3.0 + _hash(k, 13) * 70.0
		var x := 6.0 + _hash(k, 17) * 88.0
		var w := 2.0 + _hash(k, 19) * 5.0
		b.stroke(PackedVector2Array([_pt(Vector2(x, y)), _pt(Vector2(x + w, y))]), s * 0.35, Color(Pal.MG_SHINE, 0.35))
	# lily pads, low and flat, and reeds in the corners
	for p: Vector3 in [Vector3(12.0, 118.0, 4.0), Vector3(88.0, 112.0, 3.4), Vector3(22.0, 128.0, 2.8), Vector3(74.0, 127.0, 3.0)]:
		var c := _pt(Vector2(p.x, p.y))
		b.ellipse(c + Vector2(0.0, s * 0.3), p.z * s, p.z * 0.42 * s, Color(Pal.MG_POND_DEEP.darkened(0.1), 0.6))
		b.ellipse(c, p.z * s, p.z * 0.4 * s, Color(Pal.MG_BANK_DEEP, 0.55))
		# the pad's notch
		b.fan(PackedVector2Array([c, c + Vector2(p.z * 0.9, -p.z * 0.12) * s, c + Vector2(p.z * 0.9, p.z * 0.2) * s]),
			Color(Pal.MG_POND_DEEP, 0.9))
	# a water lily open on the first pad
	var lily := _pt(Vector2(11.0, 117.2))
	for k in 7:
		var a := PI + PI * float(k) / 6.0
		b.ellipse(lily + Vector2(cos(a) * 1.3, sin(a) * 0.55) * s, s * 0.75, s * 0.42, Color("f3c9d6"))
	for k in 4:
		var a := PI + PI * (float(k) + 0.5) / 4.0
		b.ellipse(lily + Vector2(cos(a) * 0.7, sin(a) * 0.5 - 0.3) * s, s * 0.6, s * 0.38, Color("fbe3ea"))
	b.disc(lily + Vector2(0.0, -0.3) * s, s * 0.4, Pal.SUN_RAY)
	# the bank the pot slides on
	var bank := State.POT_Y + 3.2
	var pts := PackedVector2Array([o + Vector2(0.0, bank * s)])
	for k in 21:
		var x := State.W * float(k) / 20.0
		pts.append(_pt(Vector2(x, bank - 0.6 - 0.5 * sin(x * 0.4))))
	pts.append(o + Vector2(fw, fh + FOOT))
	pts.append(o + Vector2(0.0, fh + FOOT))
	b.polygon(pts, Pal.MG_BANK)
	b.fan(PackedVector2Array([_pt(Vector2(0.0, bank + 1.2)), _pt(Vector2(State.W, bank + 1.2)),
		o + Vector2(fw, fh + FOOT), o + Vector2(0.0, fh + FOOT)]), Pal.MG_BANK_DEEP)
	# the bank's lit lip, and clover and daisies along it
	b.stroke(pts.slice(1, 22), s * 0.4, Color(Pal.MG_VINE_HI, 0.7))
	for k in 13:
		var x := 9.0 + float(k) * 6.8 + (_hash(k, 91) - 0.5) * 2.0
		var foot := Vector2(x, bank + 0.6 + _hash(k, 93) * 0.8)
		for j in 3:
			var d := Vector2.from_angle(-PI * 0.5 + (float(j) - 1.0) * 0.6)
			Parts.leaf(b, _pt(foot), d, s * 1.1, s * 0.4, Pal.MG_GREEN_DEEP if j != 1 else Pal.MG_VINE)
		if k % 2 == 0:
			var head := _pt(foot + Vector2(0.4, -1.3))
			for j in 6:
				b.disc(head + Vector2.from_angle(TAU * float(j) / 6.0) * s * 0.42, s * 0.3, Color("fbf7ee"))
			b.disc(head, s * 0.26, Pal.SUN_RAY)
	for side: float in [0.0, 1.0]:
		for k in 5:
			var x := 1.5 + float(k) * 1.3 if side == 0.0 else State.W - 1.5 - float(k) * 1.3
			var top := bank - 9.0 - 4.0 * _hash(k, int(side) + 5)
			var foot := _pt(Vector2(x, bank + 0.5))
			var tip := _pt(Vector2(x + (0.8 if side == 0.0 else -0.8), top))
			b.stroke(PackedVector2Array([foot, tip]), s * 0.45, Pal.MG_BANK_DEEP)
			if k % 2 == 0:
				b.ellipse(tip + Vector2(0.0, s * 1.6), s * 0.5, s * 1.4, Pal.MG_ARBOR_DEEP)
	# the arbor: a post down each side and an arch over the sun
	var post := minf(3.0 * s, maxf(0.0, o.x - 4.0))
	if post > 4.0:
		for x: float in [o.x - post, o.x + fw]:
			b.fan(PackedVector2Array([Vector2(x, o.y - s * 2.0), Vector2(x + post, o.y - s * 2.0),
				Vector2(x + post, o.y + fh + FOOT), Vector2(x, o.y + fh + FOOT)]), Pal.MG_ARBOR)
			b.fan(PackedVector2Array([Vector2(x + post * 0.68, o.y - s * 2.0), Vector2(x + post, o.y - s * 2.0),
				Vector2(x + post, o.y + fh + FOOT), Vector2(x + post * 0.68, o.y + fh + FOOT)]), Pal.MG_ARBOR_DEEP)
			b.fan(PackedVector2Array([Vector2(x + post * 0.08, o.y - s * 2.0), Vector2(x + post * 0.26, o.y - s * 2.0),
				Vector2(x + post * 0.26, o.y + fh + FOOT), Vector2(x + post * 0.08, o.y + fh + FOOT)]), Color(Pal.MG_ARBOR_HI, 0.8))
			# a vine winding up it
			var vine := PackedVector2Array()
			for k in 60:
				var y := o.y + fh + FOOT - float(k) * (fh + FOOT) / 59.0
				vine.append(Vector2(x + post * 0.5 + sin(float(k) * 0.55) * post * 0.55, y))
			b.stroke(vine, s * 0.35, Pal.MG_VINE)
			for k in range(2, 58, 5):
				var at := vine[k]
				var side := 1.0 if k % 2 == 0 else -1.0
				b.ellipse(at + Vector2(side * s * 0.9, 0.0), s * 0.9, s * 0.5, Pal.MG_VINE if k % 3 else Pal.MG_VINE_HI)
				if k % 15 == 2:
					b.disc(at + Vector2(-side * s * 0.6, -s * 0.4), s * 0.55, Pal.MG_ORANGE_HI)
					b.disc(at + Vector2(-side * s * 0.6, -s * 0.4), s * 0.22, Pal.MG_ORANGE_DEEP)
	# the arch behind the sun
	var arch := PackedVector2Array()
	for k in 41:
		var u := float(k) / 40.0
		arch.append(o + Vector2(u * fw, s * (2.0 - 2.4 * sin(PI * u)) - s * 1.2))
	b.stroke(arch, s * 2.2, Pal.MG_ARBOR_DEEP)
	b.stroke(arch, s * 1.6, Pal.MG_ARBOR)
	var lit := PackedVector2Array()
	for p in arch:
		lit.append(p + Vector2(0.0, -s * 0.45))
	b.stroke(lit, s * 0.35, Color(Pal.MG_ARBOR_HI, 0.8))
	# the lanterns, hanging from the arch with a warm glow
	for k in 2:
		var cap := _pt(_lantern_at(k))
		var hook := cap - Vector2(0.0, s * 1.8)
		b.stroke(PackedVector2Array([hook, cap]), s * 0.16, Pal.MG_ARBOR_DEEP)
		b.disc(cap + Vector2(0.0, s * 1.5), s * 2.8, Color(Pal.SUN_RAY, 0.16))
		b.fan(Face.Builder.round_rect(cap + Vector2(-1.1, 0.0) * s, Vector2(2.2, 3.0) * s, s * 0.8), Color("f6d28b"))
		b.fan(Face.Builder.round_rect(cap + Vector2(-0.5, 0.45) * s, Vector2(1.0, 2.1) * s, s * 0.45), Color("fff1c4"))
		for side: float in [-1.0, 1.0]:
			b.stroke(PackedVector2Array([cap + Vector2(side * 0.55, 0.2) * s, cap + Vector2(side * 0.55, 2.8) * s]), s * 0.12,
				Color(Pal.MG_ARBOR_DEEP, 0.5))
		b.fan(Face.Builder.round_rect(cap + Vector2(-1.3, -0.35) * s, Vector2(2.6, 0.7) * s, s * 0.3), Pal.MG_ARBOR_DEEP)
		b.fan(Face.Builder.round_rect(cap + Vector2(-0.9, 2.8) * s, Vector2(1.8, 0.55) * s, s * 0.25), Pal.MG_ARBOR_DEEP)
	# a garland swagged along the arch: leaves, and a marigold in each swag
	var swag := PackedVector2Array()
	for k in 81:
		var u := float(k) / 80.0
		var p := arch[mini(40, int(round(u * 40.0)))]
		swag.append(Vector2(o.x + u * fw, p.y + s * (0.7 + 1.5 * absf(sin(PI * u * 4.0)))))
	b.stroke(swag, s * 0.3, Pal.MG_VINE)
	for k in range(2, 79, 3):
		var side := 1.0 if k % 2 == 0 else -1.0
		var d := (swag[k + 1] - swag[k - 1]).normalized()
		Parts.leaf(b, swag[k], (d.rotated(side * 1.1)).normalized(), s * 1.0, s * 0.34, Pal.MG_VINE if k % 4 else Pal.MG_VINE_HI)
	for k in 4:
		var at := swag[10 + 20 * k] + Vector2(0.0, s * 0.3)
		Parts.bloom(b, at, s * 1.0, State.ORANGE, 1.0)
	# a soft light round the sun
	b.disc(_pt(State.SUN_C), s * 7.0, Color(Pal.SUN_RAY, 0.12))
	b.disc(_pt(State.SUN_C), s * 5.2, Color(Pal.SUN_RAY, 0.14))
	return b.mesh()

## A range of hills along `base`, `amp` high, rolling at `freq`; the far
## one carries snow on its peaks.
func _range(b: Face.Builder, base: float, amp: float, freq: float, phase: float, col: Color, snow: bool) -> void:
	var pts := PackedVector2Array()
	var ridge := PackedVector2Array()
	for k in 41:
		var x := State.W * float(k) / 40.0
		var y := base - amp * absf(sin(x * freq + phase)) - amp * 0.35 * sin(x * freq * 2.3 + phase * 2.0)
		ridge.append(Vector2(x, y))
		pts.append(_pt(Vector2(x, y)))
	pts.append(_pt(Vector2(State.W, base + 0.2)))
	pts.append(_pt(Vector2(0.0, base + 0.2)))
	b.polygon(pts, col)
	if snow:
		for k in range(1, 40):
			var p := ridge[k]
			if p.y < ridge[k - 1].y and p.y < ridge[k + 1].y and p.y < base - amp * 0.8:
				var cap := PackedVector2Array([_pt(p + Vector2(-2.2, 2.0)), _pt(p + Vector2(0.0, -0.1)), _pt(p + Vector2(2.2, 2.0)),
					_pt(p + Vector2(0.8, 1.4)), _pt(p + Vector2(0.0, 2.2)), _pt(p + Vector2(-0.9, 1.3))])
				b.polygon(cap, Pal.MG_SNOW)

## A rectangle shaded from `top` to `bottom`.
static func _vgrad(b: Face.Builder, r: Rect2, top: Color, bottom: Color) -> void:
	var a := b.vertex(r.position, top)
	var c := b.vertex(r.position + Vector2(r.size.x, 0.0), top)
	var d := b.vertex(r.end, bottom)
	var e := b.vertex(r.position + Vector2(0.0, r.size.y), bottom)
	b.tri(a, c, d)
	b.tri(a, d, e)

static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) ^ (a * b * 1274126177)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0x7fffffff) / float(0x7fffffff)

## The full bloom behind the field: a rainbow across the sky and the sun's
## rays out of the last marigold, and the five pots along the foot.
func _build_back(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _s()
	var e := 1.0 if Motion.reduce else clampf((t - _fever_at) / 1.4, 0.0, 1.0)
	var bands := [Color("f4a3a0"), Color("f7c58f"), Color("f6e39a"), Color("b9dfa0"), Color("a9c9ee"), Color("c6b0ea")]
	var c := _pt(Vector2(State.W * 0.5, 70.0))
	for k in bands.size():
		var r := (46.0 - float(k) * 2.6) * s
		b.stroke(Face.Builder.arc_points(c, r, PI, PI + PI * e), 2.6 * s, Color(bands[k], 0.55))
	if not Motion.reduce and t - _fever_at < 1.8:
		var a := 1.0 - clampf((t - _fever_at) / 1.8, 0.0, 1.0)
		for k in 12:
			var ang := TAU * float(k) / 12.0 + (t - _fever_at) * 0.6
			var d := Vector2.from_angle(ang)
			var side := Vector2(-d.y, d.x)
			var far := 90.0 * s * (0.3 + 0.7 * e)
			b.fan(PackedVector2Array([_fever_from, _fever_from + d * far + side * far * 0.08, _fever_from + d * far - side * far * 0.08]),
				Color(Pal.SUN_RAY, 0.35 * a))
	# the five pots, each with its worth
	var n := State.FEVER_POTS.size()
	var w := State.W / float(n)
	for k in n:
		var x := (float(k) + 0.5) * w
		var lit := 1.0 if k == _fever_pot else 0.0
		var rim := _pt(Vector2(x, State.POT_Y))
		var pb := Face.Builder.new()
		Parts.pot(pb, (w - 2.2) * s, lit)
		# fold the small builder into this one at the pot's place
		var base := b.verts.size()
		for i in pb.verts.size():
			b.verts.append(pb.verts[i] + rim)
			b.cols.append(pb.cols[i])
		for i in pb.idx:
			b.idx.append(base + i)
	for k in range(1, n):
		b.disc(_pt(Vector2(State.W * float(k) / float(n), State.POT_Y)), (State.POT_RIM + 0.4) * s, Pal.MG_ARBOR)
	return b.mesh()

## Every closed bud, popping in top to bottom as the garden grows.
func _band_of(i: int) -> int:
	var y: float = (_state.pos[i].y - State.TOP) / (State.BOTTOM - State.TOP + 1.0)
	return clampi(int(y * float(BUD_BANDS)), 0, BUD_BANDS - 1)

func _dirty_bud(i: int) -> void:
	if _buds.size() == BUD_BANDS:
		_buds[_band_of(i)] = null

func _build_buds(t: float, band: int) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _s()
	var r := State.PEG_R * s
	for i in _state.pos.size():
		if _state.st[i] != State.UP or _band_of(i) != band:
			continue
		var sc := _grow(i, t)
		# a marigold folding back comes up as a bud once its bloom has shut
		var f := _fold_at[i]
		if f >= 0.0 and not Motion.reduce:
			sc *= Motion.pop_in_scale(t - f - FOLD_TIME * 0.7).x if t - f > FOLD_TIME * 0.7 else 0.0
		if sc <= 0.01:
			continue
		var at := _pt(_state.pos[i])
		var e := t - _rustle_at[i]
		if e < RUSTLE_TIME and not Motion.reduce:
			at.x += sin(e * 42.0) * exp(-e * 7.0) * 0.32 * s
		Parts.bud(b, at, r, _state.kind[i], sc)
	return b.mesh() if not b.verts.is_empty() else null

func _grow(i: int, t: float) -> float:
	if Motion.reduce:
		return 1.0
	var y: float = (_state.pos[i].y - State.TOP) / (State.BOTTOM - State.TOP)
	var e := t - _grown_at - Motion.ENTER_DELAY - 0.1 - y * 0.8 - _hash(i, 31) * 0.1
	return 0.0 if e <= 0.0 else Motion.pop_in_scale(e).x

## The blooms, opening as they are touched and fading as they are picked.
func _build_lit(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _s()
	var r := State.PEG_R * s
	for i in _state.pos.size():
		var hit := _hit_at[i]
		if hit < 0.0:
			continue
		var pick := _pick_at[i]
		var alpha := 1.0
		var sc := 1.0
		var lift := 0.0
		var spin := 0.0
		var f := _fold_at[i]
		if f >= 0.0:
			# Sweethearts: a lonely bloom droops and shuts
			var u := clampf((t - f) / FOLD_TIME, 0.0, 1.0)
			if u >= 1.0 or Motion.reduce:
				continue
			var shut := 1.0 - u * u
			Parts.bloom(b, _pt(_state.pos[i]) + Vector2(0.0, s * 0.8 * u), r, _state.kind[i], shut, 1.0 - 0.15 * u, 1.0, -0.5 * u)
			continue
		if pick >= 0.0:
			var e := t - pick
			if e >= PICK_TIME or (Motion.reduce and e >= 0.0):
				continue
			if e > 0.0:
				var u := e / PICK_TIME
				alpha = 1.0 - u * u
				sc = 1.0 + 0.35 * u
				lift = PICK_RISE * s * u
				spin = 1.4 * u
		elif _state.st[i] != State.LIT:
			continue
		var open := 1.0 if Motion.reduce else Motion.back_out(clampf((t - hit) / BLOOM_TIME, 0.0, 1.0))
		# open blooms breathe while the seed is still out
		if pick < 0.0 and _phase == "shot" and not Motion.reduce:
			sc *= 1.0 + 0.05 * sin((t - hit) * 6.0 + float(i))
		Parts.bloom(b, _pt(_state.pos[i]) - Vector2(0.0, lift), r, _state.kind[i], open, sc, alpha, spin)
	return b.mesh() if not b.verts.is_empty() else null

## The aim: dots down the seed's way to the first bud it will touch (the
## hint's long guide: through three), fading as they go.
func _build_guide() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _s()
	var r: Dictionary = _state.trace(_aim, 3 if _super else 1, 3.0 if _super else 1.2, 2)
	var pts: PackedVector2Array = r.path
	var limit := 1e9 if _super else GUIDE_LEN
	var walked := 0.0
	var next := 0.0
	for k in range(1, pts.size()):
		var a := pts[k - 1]
		var z := pts[k]
		var seg := a.distance_to(z)
		while next <= walked + seg and next <= limit:
			var at := a.lerp(z, (next - walked) / maxf(seg, 1e-5))
			var u := next / (limit if not _super else maxf(1.0, _path_len(pts)))
			var col := Pal.SUN_RAY if _super else Pal.MG_SHINE
			b.disc(_pt(at), s * (0.55 - 0.25 * u), Color(col, 0.95 - 0.55 * u))
			next += GUIDE_GAP
		walked += seg
		if walked > limit:
			break
	return b.mesh() if not b.verts.is_empty() else null

static func _path_len(pts: PackedVector2Array) -> float:
	var n := 0.0
	for k in range(1, pts.size()):
		n += pts[k].distance_to(pts[k - 1])
	return n

func _build_trail() -> ArrayMesh:
	if Motion.reduce:
		return null
	var b := Face.Builder.new()
	var s := _s()
	for tr_pts: PackedVector2Array in _trails:
		var n := tr_pts.size()
		for k in n:
			var u := float(k + 1) / float(n + 1)
			b.disc(_pt(tr_pts[k]), s * State.BALL_R * (0.2 + 0.6 * u), Color(Pal.SUN_RAY, 0.32 * u))
			if k % 3 == 1:
				var off := Vector2(_hash(k, n) - 0.5, _hash(n, k) - 0.5) * s * 1.6
				b.disc(_pt(tr_pts[k]) + off, s * 0.2, Color(1.0, 1.0, 1.0, 0.7 * u))
	return b.mesh() if not b.verts.is_empty() else null

## The sun: rays turning slowly, the body and face looking down the aim,
## and the spout turned to it with a seed waiting when one is ready.
func _draw_sun(t: float, xf: Transform2D, tint: Color, shown: Array) -> void:
	var s := _s()
	var R := SUN_R * s
	var c := _pt(State.SUN_C)
	if _rays == null:
		var b := Face.Builder.new()
		Parts.sun_rays(b, R)
		_rays = b.mesh()
	var spin := 0.0 if Motion.reduce else t * TAU / 40.0
	if _slow < 0.9:
		spin *= 3.0
	if not _think.is_empty() and not Motion.reduce:
		spin += (t - float(_think.at)) * TAU * 1.5
	var loaded: bool = _phase == "aim" and _state.seeds > 0 and not _done
	var lk := 1 if loaded else 0
	if _spout == null or _spout_for != lk:
		var b := Face.Builder.new()
		Parts.spout(b, R, loaded, State.MUZZLE / SUN_R)
		_spout = b.mesh()
		_spout_for = lk
	var expr := _expr if t < _expr_until else (Face.Expr.WORRIED if _state.seeds <= 1 and _phase == "aim" and not _done else Face.Expr.HAPPY)
	if _won:
		expr = Face.Expr.JOY
	var eye := 1.0
	if not Motion.reduce and t >= _blink_at and t <= _blink_at + Face.BLINK_TIME:
		eye = absf(cos(PI * (t - _blink_at) / Face.BLINK_TIME))
	var look := State.aim_dir(_aim_shown) * 0.07 if _phase == "aim" else Vector2(0.0, 0.06)
	var key := "%d|%d|%d|%d" % [expr, int(eye * 6.0), int(look.x * 100.0), int(look.y * 100.0)]
	if _body == null or _body_for != key:
		var b := Face.Builder.new()
		Parts.sun_body(b, R, maxf(0.05, float(int(eye * 6.0)) / 6.0), expr, look)
		_body = b.mesh()
		_body_for = key
	# a shot kicks the sun back up its aim and squashes it; at rest it bobs
	var q := 0.0
	var bob := Vector2.ZERO
	if not Motion.reduce:
		var e := t - _shot_at
		if e < RECOIL_TIME:
			q = sin(PI * e / RECOIL_TIME) * (1.0 - 0.5 * e / RECOIL_TIME)
		bob = Vector2(0.0, sin(t * 1.7) * 0.22 * s)
		var h := t - _hop_at
		if h < HOP_TIME:
			bob.y -= sin(PI * h / HOP_TIME) * s * 1.3
	var back := -State.aim_dir(_aim_shown) * q * s
	_put(_rays, xf * Transform2D(spin, Vector2.ONE * (1.0 + 0.1 * q), 0.0, c + bob), tint, shown)
	_put(_spout, xf * Transform2D(State.aim_dir(_aim_shown).angle(), c + bob + back * 1.2), tint, shown)
	var body := xf * Transform2D(0.0, Vector2(1.0 + 0.12 * q, 1.0 - 0.1 * q), 0.0, c + bob + back * 0.5)
	_put(_body, body, tint, shown)
	# the sunglasses, dropped on after a loud shot and through a full bloom
	var on := t - _shades_at
	if on >= 0.0 and (t < _shades_until or _state.fever or _won):
		if _shades == null:
			var b := Face.Builder.new()
			_draw_shades(b, R)
			_shades = b.mesh()
		var drop := 0.0 if Motion.reduce or on >= SHADES_DROP else -R * 2.4 * pow(1.0 - on / SHADES_DROP, 2.0)
		var tilt := 0.0 if Motion.reduce or on >= SHADES_DROP + 0.3 else sin(on * 18.0) * 0.12 * exp(-on * 6.0)
		_put(_shades, body * Transform2D(tilt, Vector2(0.0, drop)), tint, shown)

## The sun's sunglasses about its middle: two dark round lenses on a gold
## bridge, each with a shine.
static func _draw_shades(b: Face.Builder, R: float) -> void:
	var y := -0.02 * R
	b.stroke(PackedVector2Array([Vector2(-0.98, y - 0.12) * R, Vector2(-0.6, y - 0.18) * R]), 0.09 * R, Color("3a2f44"))
	b.stroke(PackedVector2Array([Vector2(0.98, y - 0.12) * R, Vector2(0.6, y - 0.18) * R]), 0.09 * R, Color("3a2f44"))
	b.stroke(PackedVector2Array([Vector2(-0.16, y - 0.12) * R, Vector2(0.0, y - 0.18) * R, Vector2(0.16, y - 0.12) * R]), 0.1 * R, Color("3a2f44"))
	for sx: float in [-1.0, 1.0]:
		var c := Vector2(sx * 0.4, y) * R
		b.ellipse(c, 0.36 * R, 0.27 * R, Color("3a2f44"))
		b.ellipse(c + Vector2(0.0, 0.02 * R), 0.3 * R, 0.21 * R, Color("5a4a6e"))
		b.stroke(PackedVector2Array([c + Vector2(-0.18, -0.02) * R, c + Vector2(-0.04, -0.14) * R]), 0.06 * R, Color(1.0, 1.0, 1.0, 0.55))

## The band over the field: the seeds left in a wooden trough, the score
## rolling up, the multiplier on a tag, and a groove of marigold pips that
## fill as the marigolds fly up to them, gapped where the multiplier steps.
func _draw_hud(t: float, xf: Transform2D, tint: Color, shown: Array) -> void:
	var mult: int = _state.mult()
	var total: int = _state.orange_total
	var got := _pips_filled(t)
	var in_trough: int = _state.seeds - _seeds_flying(t)
	var key := "%d|%d|%d|%d|%d" % [in_trough, got, total, _seeds_start, int(size.x)]
	if _hud == null or _hud_for != key:
		var b := Face.Builder.new()
		# the trough, the seeds lying in it and the dents of the ones shot
		var slots := clampi(maxi(_seeds_start, _state.seeds), 1, 10)
		var tw := 30.0 * float(slots) + 14.0
		b.fan(Face.Builder.round_rect(Vector2(INSET + 5.0, 20.0), Vector2(tw, 40.0), 20.0), Pal.MG_ARBOR_DEEP.darkened(0.2))
		b.fan(Face.Builder.round_rect(Vector2(INSET + 5.0, 17.0), Vector2(tw, 40.0), 20.0), Pal.MG_ARBOR_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(INSET + 10.0, 22.0), Vector2(tw - 10.0, 30.0), 15.0), Pal.MG_ARBOR_DEEP.darkened(0.3))
		b.stroke(PackedVector2Array([Vector2(INSET + 22.0, 19.5), Vector2(INSET + tw - 12.0, 19.5)]), 2.0, Color(Pal.MG_ARBOR_HI, 0.6))
		var shown_seeds := mini(in_trough, 10)
		for k in slots:
			var at := Vector2(INSET + 22.0 + float(k) * 30.0, 38.0)
			if k < shown_seeds:
				Parts.kernel(b, at, 9.5, -PI * 0.5 + (0.2 if k % 2 == 0 else -0.2))
			else:
				b.ellipse(at + Vector2(0.0, 3.0), 7.0, 4.0, Color(Pal.TEXT, 0.25))
		# the pips' groove
		var g := _pip_geom()
		var pip: float = g.pip
		var row_x: float = g.x
		var row_w: float = g.w
		var row_y: float = g.y
		b.fan(Face.Builder.round_rect(Vector2(row_x - 12.0, row_y - pip * 0.5 - 4.0), Vector2(row_w + 24.0, pip + 12.0), pip * 0.5 + 6.0),
			Pal.MG_ARBOR_DEEP.darkened(0.2))
		b.fan(Face.Builder.round_rect(Vector2(row_x - 12.0, row_y - pip * 0.5 - 6.0), Vector2(row_w + 24.0, pip + 12.0), pip * 0.5 + 6.0),
			Pal.MG_ARBOR_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(row_x - 8.0, row_y - pip * 0.5 - 2.0), Vector2(row_w + 16.0, pip + 4.0), pip * 0.5 + 2.0),
			Pal.MG_ARBOR_DEEP.darkened(0.3))
		for k in total:
			var at := _pip_at(k)
			if k < got:
				Parts.bloom(b, at, pip * 0.3, State.ORANGE, 1.0)
			else:
				b.disc(at, pip * 0.27, Color(Pal.MG_ARBOR, 0.9))
				b.disc(at + Vector2(0.0, pip * 0.04), pip * 0.2, Pal.MG_ARBOR_DEEP.darkened(0.15))
		_hud = b.mesh()
		_hud_for = key
	_put(_hud, xf, tint, shown)
	# the tag, popping when the multiplier steps
	if _pill == null or _pill_for != mult:
		var b := Face.Builder.new()
		var sz := Vector2(108.0, 54.0)
		var face := Pal.MG_ORANGE if mult > 1 else Pal.MG_ARBOR
		b.fan(Face.Builder.round_rect(-sz * 0.5 + Vector2(0.0, 4.0), sz, 27.0), face.darkened(0.35))
		b.fan(Face.Builder.round_rect(-sz * 0.5, sz, 27.0), face)
		b.stroke(Face.Builder.arc_points(Vector2(-sz.x * 0.5 + 27.0, 0.0), 21.0, PI * 1.05, PI * 1.5), 3.0, Color(1.0, 1.0, 1.0, 0.3), false, false)
		b.disc(Vector2(-sz.x * 0.5 + 15.0, 0.0), 5.0, face.darkened(0.45))
		_pill = b.mesh()
		_pill_for = mult
	var pop := 1.0
	if not Motion.reduce and t - _mult_at < TAG_TIME:
		var u := (t - _mult_at) / TAG_TIME
		pop = 1.0 + 0.4 * sin(PI * u) * (1.0 - 0.4 * u)
	var tag := xf * Transform2D(0.0, Vector2.ONE * pop, 0.0, _tag_centre())
	_put(_pill, tag, tint, shown)
	var font: Font = CozyTheme.body(800)
	var a := tint.a
	if _state.seeds > 10:
		draw_string(font, xf * Vector2(INSET + 336.0, 50.0), "+%d" % (_state.seeds - 10), HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT,
			Color(Pal.PAPER, a))
	elif _state.seeds == 0:
		draw_string(font, xf * Vector2(INSET + 20.0, 50.0), tr("MG_NO_SEEDS"), HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT,
			Color(Pal.PAPER, 0.8 * a))
	var sc := Locale.number(int(_score_shown))
	var sw: float = font.get_string_size(sc, HORIZONTAL_ALIGNMENT_LEFT, -1, SCORE_FONT).x
	# the score kicks when a shot is banked, and glows gold while it rolls
	var kick := 1.0
	if not Motion.reduce and t - _kick_at < KICK_TIME:
		var u := (t - _kick_at) / KICK_TIME
		kick = 1.0 + 0.3 * sin(PI * u) * (1.0 - 0.5 * u)
	var rolling := clampf((float(_state.score + (_state.shot_points if _phase == "shot" else 0)) - _score_shown) / 400.0, 0.0, 1.0)
	draw_set_transform_matrix(xf * Transform2D(0.0, Vector2.ONE * kick, 0.0, Vector2(size.x * 0.5, 40.0)))
	var sat := Vector2(-sw * 0.5, 18.0)
	draw_string_outline(font, sat, sc, HORIZONTAL_ALIGNMENT_LEFT, -1, SCORE_FONT, 8, Color(Pal.MG_CARD_DEEP.darkened(0.3), 0.6 * a))
	draw_string(font, sat, sc, HORIZONTAL_ALIGNMENT_LEFT, -1, SCORE_FONT, Color(Pal.PAPER.lerp(Pal.SUN_RAY, rolling), a))
	draw_set_transform(Vector2.ZERO)
	var m := "×%d" % mult
	var mw: float = font.get_string_size(m, HORIZONTAL_ALIGNMENT_LEFT, -1, MULT_FONT).x
	draw_set_transform_matrix(tag)
	draw_string(font, Vector2(-mw * 0.5 + 6.0, 15.0), m, HORIZONTAL_ALIGNMENT_LEFT, -1, MULT_FONT, Color(Pal.PAPER, a))
	draw_set_transform(Vector2.ZERO)

## Where the multiplier's tag sits, its middle.
func _tag_centre() -> Vector2:
	return Vector2(size.x - INSET - 64.0, 39.0)

## The pips' row: the pip's pitch, where it starts, how wide, its line.
func _pip_geom() -> Dictionary:
	var total: int = _state.orange_total
	var pip := clampf((size.x - 2.0 * INSET - 40.0) / float(maxi(total, 1) + 4), 12.0, 30.0)
	var gaps := State.STEPS.size() - 1
	var w := pip * float(total) + pip * 0.5 * float(gaps)
	return {"pip": pip, "x": (size.x - w) * 0.5, "w": w, "y": BAND - 30.0}

## The middle of the `k`th pip, the gaps where the multiplier steps counted.
func _pip_at(k: int) -> Vector2:
	var g := _pip_geom()
	var total: int = _state.orange_total
	var pip: float = g.pip
	var x: float = g.x + pip * float(k)
	for j in range(1, State.STEPS.size()):
		if int(ceil(float(State.STEPS[j]) * float(total) - 1e-6)) <= k:
			x += pip * 0.5
	return Vector2(x + pip * 0.5, g.y)

## The pot's place, with its wobble after it turns at an end and its squash
## when it catches a seed, both about its foot.
func _pot_xf(t: float) -> Transform2D:
	var at := _pt(Vector2(_state.pot_x, State.POT_Y))
	if Motion.reduce:
		return Transform2D(0.0, at)
	var foot: float = _state.pot_w * _s() * 0.62
	var e := t - _pot_turn_at
	var ang := 0.0
	if e < WOBBLE_TIME:
		ang = -0.12 * _state.pot_dir * sin(e * 15.0) * exp(-e * 4.5)
	var sc := Vector2.ONE
	var c := t - _pot_glow_at
	if c < CATCH_TIME:
		var q := sin(PI * c / CATCH_TIME) * (1.0 - 0.4 * c / CATCH_TIME)
		sc = Vector2(1.0 + 0.16 * q, 1.0 - 0.18 * q)
	return Transform2D(0.0, at + Vector2(0.0, foot)) * Transform2D(ang, sc, 0.0, Vector2.ZERO) * Transform2D(0.0, Vector2(0.0, -foot))

## Under the buds, every frame: fireflies, the stars twinkling, glints
## drifting across the pond, the lanterns' flicker, and the ripples round
## every bud that bloomed.
func _build_live_back(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _s()
	var horizon := 58.0
	for k in 5:
		var j := k * 3 + 1
		var at := Vector2(4.0 + _hash(j, 3) * 92.0, 3.0 + _hash(j, 7) * 30.0)
		if at.distance_to(Vector2(81.0, 15.0)) < 9.0:
			continue
		var a := pow(maxf(0.0, sin(t * (1.1 + 0.3 * _hash(j, 11)) + float(j) * 1.9)), 6.0)
		if a > 0.05:
			_twinkle(b, _pt(at), s * 1.3 * a, Color(Pal.MG_SHINE, 0.9 * a), 0.0)
	for k in 7:
		var y := horizon + 5.0 + _hash(k, 61) * 62.0
		var span := 110.0
		var x := fmod(_hash(k, 63) * span + t * (0.8 + 0.8 * _hash(k, 65)), span) - 5.0
		var w := 2.0 + 2.5 * _hash(k, 67)
		var a := 0.4 * sin(PI * clampf((x + 5.0) / span, 0.0, 1.0))
		var x0 := clampf(x, 1.0, State.W - 1.0)
		var x1 := clampf(x + w, 1.0, State.W - 1.0)
		if x1 - x0 > 0.3:
			b.stroke(PackedVector2Array([_pt(Vector2(x0, y)), _pt(Vector2(x1, y))]), s * 0.32, Color(Pal.MG_SHINE, a))
	for k in FIREFLIES:
		var low := k % 2 == 0
		var base := Vector2(6.0 + _hash(k, 51) * 88.0, (108.0 + _hash(k, 53) * 18.0) if low else (10.0 + _hash(k, 53) * 12.0))
		var p := base + Vector2(sin(t * 0.37 + float(k) * 1.7) * 4.0, sin(t * 0.53 + float(k) * 2.3) * 2.2)
		var glow := pow(maxf(0.0, sin(t * (0.8 + 0.5 * _hash(k, 57)) + float(k) * 2.1)), 3.0)
		if glow < 0.03:
			continue
		b.disc(_pt(p), s * 1.4, Color(Pal.SUN_RAY, 0.2 * glow))
		b.disc(_pt(p), s * 0.36, Color(Color("fff6c8"), 0.95 * glow))
	for k in 2:
		var at := _lantern_at(k) + Vector2(0.0, 1.5)
		var f := 0.5 + 0.3 * sin(t * 6.3 + float(k) * 2.0) + 0.2 * sin(t * 10.7 + float(k))
		b.disc(_pt(at), s * (2.3 + 0.35 * f), Color(Pal.SUN_RAY, 0.12 + 0.1 * f))
	_draw_ducks(b, t)
	_draw_frog(b, t)
	for r: Dictionary in _ripples:
		var u := clampf((t - float(r.t)) / RIPPLE_TIME, 0.0, 1.0)
		var rad := State.PEG_R * s * (1.1 + 2.4 * Motion.back_out(u) * 0.8 + 0.4 * u)
		b.stroke(Face.Builder.arc_points(_pt(r.at), rad, 0.0, TAU), s * 0.3 * (1.0 - 0.5 * u), Color(Color(r.col), 0.6 * (1.0 - u)),
			true, false)
	return b.mesh() if not b.verts.is_empty() else null

## Over everything, every frame: a glint on a marigold now and then, the
## marigolds flying up to their pips, and the full bloom's falling petals.
func _build_live(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _s()
	if _glint_i >= 0 and _glint_i < _state.pos.size() and _state.st[_glint_i] == State.UP:
		var e := t - _glint_at
		if e < GLINT_TIME:
			var a := sin(PI * e / GLINT_TIME)
			var at := _pt(_state.pos[_glint_i] + Vector2(-0.7, -0.8) * State.PEG_R)
			_twinkle(b, at, s * 1.5 * a, Color(1.0, 1.0, 0.95, 0.95 * a), e * 2.0)
	# Sweethearts: a marigold open in this shot whose sweetheart is still shut
	# beats a little heart over it, waiting
	if _state.sweethearts and _phase == "shot":
		for i in _state.shot_bloomed:
			if _state.kind[i] != State.ORANGE or _state.st[_state.pair[i]] != State.UP:
				continue
			var beat := 1.0 + 0.18 * absf(sin((t - _hit_at[i]) * 7.0))
			var at := _pt(_state.pos[i]) - Vector2(0.0, s * 3.1)
			b.polygon(_heart(at, s * 0.9 * beat, 0), Color(ROSE.darkened(0.25), 0.95))
			b.polygon(_heart(at, s * 0.75 * beat, 0), ROSE)
	var in_air := 0
	var filled := _pips_filled(t)
	var g := _pip_geom()
	for f: Dictionary in _flies:
		var e := t - float(f.t)
		if e >= FLY_TIME:
			continue
		var k := filled + in_air
		in_air += 1
		if e < 0.0:
			continue
		var u := e / FLY_TIME
		var ease := u * u * (3.0 - 2.0 * u)
		var from: Vector2 = f.from
		var to := _pip_at(k)
		var side := -1.0 if from.x > size.x * 0.5 else 1.0
		var ctrl := from.lerp(to, 0.35) + Vector2(side * 160.0, -40.0)
		var p := from.lerp(ctrl, ease).lerp(ctrl.lerp(to, ease), ease)
		var r := lerpf(State.PEG_R * s * 1.1, float(g.pip) * 0.3, ease)
		for j in 3:
			var ub := maxf(0.0, ease - 0.06 * float(j + 1))
			var pb := from.lerp(ctrl, ub).lerp(ctrl.lerp(to, ub), ub)
			b.disc(pb, r * (0.4 - 0.1 * float(j)), Color(Pal.SUN_RAY, 0.5 - 0.12 * float(j)))
		Parts.bloom(b, p, r, State.ORANGE, 1.0, 1.0 + 0.25 * sin(PI * u), 1.0, u * TAU)
	if _state.fever and t - _fever_at < PETAL_TIME:
		var cols := [Pal.MG_ORANGE, Pal.MG_ORANGE_HI, Pal.SUN_RAY, Color("f4a3a0"), Pal.MG_PURPLE_HI]
		for k in 26:
			var e := t - _fever_at - _hash(k, 71) * 1.8
			var fall := 2.4 + _hash(k, 75)
			if e < 0.0 or e > fall:
				continue
			var u := e / fall
			var at := Vector2(_hash(k, 73) * State.W + sin(e * 2.2 + float(k)) * 4.0, -3.0 + u * (State.H * 0.9))
			var col: Color = cols[k % cols.size()]
			col.a = minf(1.0, (1.0 - u) * 4.0)
			Parts.leaf(b, _pt(at), Vector2.from_angle(e * 3.0 + float(k)), s * 1.5, s * 0.5, col)
	_draw_bits(b, _bits)
	return b.mesh() if not b.verts.is_empty() else null

## A four-pointed glint at `at`, `r` to a point.
static func _twinkle(b: Face.Builder, at: Vector2, r: float, col: Color, turn: float) -> void:
	if r <= 0.3:
		return
	for k in 2:
		var d := Vector2.from_angle(turn + PI * 0.5 * float(k))
		var n := Vector2(-d.y, d.x)
		b.fan(PackedVector2Array([at - d * r, at - n * r * 0.18, at + d * r, at + n * r * 0.18]), col)
	b.disc(at, r * 0.2, col)

## Where the `k`th lantern hangs from the arch, its cap.
func _lantern_at(k: int) -> Vector2:
	var u := 0.25 if k == 0 else 0.75
	return Vector2(u * State.W, 2.0 - 2.4 * sin(PI * u) - 1.2 + 1.8)

## Each of the full bloom's pots carries what it is worth on its belly.
func _draw_pot_worths(xf: Transform2D, seen: float) -> void:
	var font: Font = CozyTheme.body(800)
	var n := State.FEVER_POTS.size()
	var w := State.W / float(n)
	var px := int(clampf(w * _s() * 0.17, 16.0, 30.0))
	for k in n:
		var text := Locale.number(State.FEVER_POTS[k])
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var at := xf * (_pt(Vector2((float(k) + 0.5) * w, State.POT_Y + 4.2)) - Vector2(tw * 0.5, 0.0))
		var col := Pal.SUN_RAY.lightened(0.4) if k == _fever_pot else Pal.PAPER
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 8, Color(Pal.MG_POT_DEEP, seen))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col, seen))

func _draw_floats(t: float, seen: float) -> void:
	var font: Font = CozyTheme.body(800)
	var keep: Array = []
	for f: Dictionary in _floats:
		var e := t - float(f.t)
		if e >= FLOAT_TIME:
			continue
		keep.append(f)
		var u := e / FLOAT_TIME
		var alpha := minf(1.0, (1.0 - u) * 2.5) * seen
		var text: String = f.text
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FLOAT_FONT).x
		var at: Vector2 = Vector2(f.at) - Vector2(w * 0.5, 50.0 * u if not Motion.reduce else 0.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FLOAT_FONT, 10, Color(Pal.TEXT, 0.45 * alpha))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FLOAT_FONT, Color(f.col, alpha))
	_floats = keep

## Over everything, in the card's own pixels: the flash, the warm glow
## round the card while a shot runs long, the sunbursts behind the loud
## stickers, the seeds flying into the trough, and the bits in the air.
func _build_air(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	if _flash > 0.0:
		b.fan(Face.Builder.round_rect(Vector2.ZERO, size, CARD_RADIUS), Color(_flash_col, _flash * 0.55))
	if _heat > 0.01:
		_draw_heat(b, t)
	for st: Dictionary in _stickers:
		if not st.rays:
			continue
		var grow := Motion.back_out(clampf(float(st.t) / 0.35, 0.0, 1.0))
		var a := 1.0 - clampf((float(st.t) - (float(st.life) - 0.35)) / 0.35, 0.0, 1.0)
		var w: float = st.w
		var r := maxf(w * 0.62, float(st.size) * 1.5) * grow
		var at: Vector2 = st.at
		b.disc(at, r * 0.6, Color(Color("fff4c2"), 0.35 * a))
		Parts.sunrays(b, at, r * 0.2, r, 16, t * 0.8, Color(Color("ffe39a"), 0.28 * a))
		Parts.sunrays(b, at, r * 0.2, r * 0.8, 16, -t * 0.5 + 0.1, Color(Color("fffaf0"), 0.24 * a))
	var in_trough: int = _state.seeds - _seeds_flying(t)
	var n := 0
	for f: Dictionary in _seed_flies:
		var e := t - float(f.t)
		if e < 0.0 or e >= SEED_FLY:
			n += 1
			continue
		var to := _trough_at(in_trough + n)
		n += 1
		var from: Vector2 = f.from
		var ctrl := from.lerp(to, 0.4) + Vector2(0.0, -220.0)
		for j in range(5, -1, -1):
			var u := clampf((e - 0.03 * float(j)) / SEED_FLY, 0.0, 1.0)
			var ease := u * u * (3.0 - 2.0 * u)
			var p := from.lerp(ctrl, ease).lerp(ctrl.lerp(to, ease), ease)
			if j == 0:
				Parts.kernel(b, p, lerpf(14.0, 9.5, ease), e * 14.0)
			else:
				b.disc(p, 9.0 - float(j) * 1.3, Color(GOLD.lightened(0.2), 0.14 * float(6 - j)))
	_draw_bits(b, _air_bits)
	return b.mesh() if not b.verts.is_empty() else null

## A warm glow beating round the card's edge, rising with a long shot.
func _draw_heat(b: Face.Builder, t: float) -> void:
	var s := size
	var beat := 0.6 if Motion.reduce else 0.5 + 0.5 * sin(t * 9.0)
	var tint := Color("ffb03b").lerp(Color("ff6f61"), _heat)
	var edge := Color(tint, (0.22 + 0.2 * beat) * _heat)
	var none := Color(tint, 0.0)
	var w := (70.0 + 40.0 * beat) * (0.6 + 0.4 * _heat)
	_quad(b, [Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x - w, w), Vector2(w, w)], [edge, edge, none, none])
	_quad(b, [Vector2(0, s.y), Vector2(w, s.y - w), Vector2(s.x - w, s.y - w), s], [edge, none, none, edge])
	_quad(b, [Vector2.ZERO, Vector2(w, w), Vector2(w, s.y - w), Vector2(0, s.y)], [edge, none, none, edge])
	_quad(b, [Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x - w, s.y - w), Vector2(s.x - w, w)], [edge, edge, none, none])

static func _quad(b: Face.Builder, pts: Array, cols: Array) -> void:
	var i0 := b.vertex(pts[0], cols[0])
	var i1 := b.vertex(pts[1], cols[1])
	var i2 := b.vertex(pts[2], cols[2])
	var i3 := b.vertex(pts[3], cols[3])
	b.idx.append_array([i0, i1, i2, i0, i2, i3])

## The bits flung about, each fading out over the end of its life.
func _draw_bits(b: Face.Builder, bits: Array) -> void:
	for bit: Dictionary in bits:
		if bit.t < 0.0:
			continue
		var life: float = bit.life
		var a := clampf((life - bit.t) / (life * 0.35), 0.0, 1.0)
		var col: Color = bit.col
		col.a *= a
		var at: Vector2 = bit.pos
		var sz: float = bit.size
		var rot: float = bit.rot
		match String(bit.kind):
			"petal":
				Parts.petal(b, at, 13.0 * sz, rot, 0.35 + 0.65 * absf(cos(bit.t * 4.0 + rot)), col)
			"leaf":
				Parts.leaf(b, at, Vector2.from_angle(rot), 16.0 * sz, 5.0 * sz, col)
			"star":
				Parts.star(b, at, 13.0 * sz * (0.6 + 0.4 * a), col, rot)
			"spark":
				Parts.spark(b, at, 20.0 * sz * a, rot, col)
			"coin":
				# a gold coin turning over as it falls
				var face := absf(cos(bit.t * 6.0 + rot))
				b.ellipse(at, 12.0 * sz * maxf(0.15, face), 12.0 * sz, Color(GOLD.darkened(0.25), col.a))
				b.ellipse(at, 9.5 * sz * maxf(0.12, face), 9.5 * sz, col)
				b.ellipse(at + Vector2(-3.0 * sz * face, -3.0 * sz), 2.5 * sz * face, 2.5 * sz, Color(1, 1, 1, 0.6 * col.a))
			"heart":
				var hs := 9.0 * sz * (0.8 + 0.2 * a)
				var pts := _heart(Vector2.ZERO, hs, 0)
				for k in pts.size():
					pts[k] = at + pts[k].rotated(sin(bit.t * 5.0 + rot) * 0.3)
				b.polygon(pts, col)
			"ring":
				var k := clampf(bit.t / life, 0.0, 1.0)
				var r := sz * (0.3 + 0.7 * (1.0 - pow(1.0 - k, 3.0)))
				b.stroke(Face.Builder.ring(at, r, r), maxf(2.0, 14.0 * (1.0 - k)), Color(bit.col, (bit.col as Color).a * (1.0 - k)), true)

## The blooms of this shot counted under the sun, bumping with each one and
## warming as it climbs.
func _draw_count(t: float, xf: Transform2D, seen: float) -> void:
	if _phase != "shot" and _phase != "pick":
		return
	var n: int = _state.shot_hits
	if n < COUNT_FROM:
		return
	var font: Font = CozyTheme.display(700)
	var text := tr("MG_BLOOMS") % n
	# one size of the face, grown by the transform
	var px := COUNT_FONT_BIG
	var bump := 1.0 + 0.025 * float(mini(n - COUNT_FROM, 16))
	if not Motion.reduce and t - _count_at < 0.25:
		bump *= 1.0 + 0.3 * sin(PI * (t - _count_at) / 0.25)
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var col := Pal.SUN_RAY.lerp(Color("ff6f61"), clampf(float(n - COUNT_FROM) / 20.0, 0.0, 1.0))
	var a := seen
	if _phase == "pick":
		a *= clampf(1.0 - (t - (_pick_done - 0.4)) / 0.4, 0.0, 1.0)
	var at := _pt(Vector2(State.W * 0.5, 20.5))
	draw_set_transform_matrix(xf * Transform2D(0.0, Vector2.ONE * bump, 0.0, at))
	var o := Vector2(-w * 0.5, px * 0.36)
	draw_string_outline(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(px * 0.3), Color(Color("fffaf0"), a))
	draw_string_outline(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(px * 0.13), Color(col.darkened(0.5), a))
	draw_string(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col, a))
	draw_set_transform(Vector2.ZERO)

## The stickers' letters: each hops in on its own, rocks for a moment and
## the word swells away at the end; a white rim and a dark one under the
## colour, so it reads over anything.
func _draw_stickers(xf: Transform2D, seen: float) -> void:
	var font: Font = CozyTheme.display(700)
	for st: Dictionary in _stickers:
		var text: String = st.text
		var px: int = st.size
		var advs: PackedFloat32Array = st.adv
		var x := -float(st.w) * 0.5
		var tt: float = st.t
		var out_a := (1.0 - clampf((tt - (float(st.life) - 0.3)) / 0.3, 0.0, 1.0)) * seen
		var swell := 1.0 + 0.2 * (1.0 - out_a)
		var tilt: float = st.tilt
		for i in text.length():
			var ch := text[i]
			var adv := advs[i]
			var k := clampf((tt - float(i) * 0.035) / 0.28, 0.0, 1.0)
			if k <= 0.0 and not Motion.reduce:
				x += adv
				continue
			var sc := 1.0 if Motion.reduce else Motion.back_out(k)
			var hop := 0.0 if Motion.reduce else -sin(tt * 8.0 - float(i) * 0.55) * px * 0.09 * exp(-tt * 1.4)
			var centre: Vector2 = Vector2(st.at) + (Vector2(x + adv * 0.5, hop) * swell).rotated(tilt)
			var rock := 0.0 if Motion.reduce else sin(tt * 7.0 + float(i)) * 0.08 * exp(-tt * 1.2)
			draw_set_transform_matrix(xf * Transform2D(tilt + rock, Vector2(sc, sc) * swell, 0.0, centre))
			var o := Vector2(-adv * 0.5, px * 0.36)
			var col: Color = STICKER_COLS[i % STICKER_COLS.size()] if st.rainbow else st.col
			draw_char_outline(font, o, ch, px, int(px * 0.3), Color(Color("fffaf0"), out_a))
			draw_char_outline(font, o, ch, px, int(px * 0.13), Color(col.darkened(0.5), out_a))
			draw_char(font, o, ch, px, Color(col, out_a))
			x += adv
	draw_set_transform(Vector2.ZERO)

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
	# over the pond, clear of the pot's bank
	var mid := Vector2(size.x * 0.5, _pt(Vector2(0.0, State.POT_Y - 14.0)).y - h * 0.5)
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
		_aim_at(event.position)
		accept_event()

func _press(local: Vector2) -> void:
	if _phase != "aim" or _state.seeds <= 0 or not _think.is_empty():
		return
	_aiming = true
	_aim_at(local)

## The aim turns toward the finger; above the sun it lies nearly level.
func _aim_at(local: Vector2) -> void:
	var f := (local - _origin()) / maxf(_s(), 1e-3)
	var d := f - State.SUN_C
	if d.length() < 1.0:
		return
	var a := atan2(d.y, d.x)
	if a < 0.0:
		a = State.AIM_MIN if d.x > 0.0 else PI - State.AIM_MIN
	a = clampf(a, State.AIM_MIN, PI - State.AIM_MIN)
	if absf(a - _aim) < 0.002:
		return
	if absf(a - _aim) > 0.01:
		_super = false
	_aim = a
	_guide = null
	queue_redraw()

## Let go to shoot; let go over the band at the top to put the aim down.
func _release(local: Vector2) -> void:
	if not _aiming:
		return
	_aiming = false
	if local.y < BAND * 0.8:
		return
	_shoot()

func _shoot() -> void:
	if not _state.fire(_aim):
		return
	_phase = "shot"
	_order = PackedInt32Array()
	_shot_oranges = 0
	_shot_pairs = 0
	_word_tier = -1
	_shot_pot = false
	_acc = 0.0
	_super = false
	_trails = []
	_shot_at = _now()
	_near_armed = false
	_near_spent = false
	fx.cue("shoot")
	fx.puff(_pt(State.SUN_C + State.aim_dir(_aim) * State.MUZZLE), Pal.MG_GREEN_HI, 3)
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

var _tip_idx := 0

func _cycle_tip() -> void:
	var tips := _tips()
	_tip_idx = (_tip_idx + 1) % tips.size()
	_say(tr(tips[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func hints_left() -> int:
	return maxi(0, State.hints_for(_state.band) + hints_extra - hints_used)

## The sun finds the best line it can from here -- every angle played out on
## a copy of the garden -- turns to it, and shows the long guide.
func hint() -> bool:
	if is_done() or _state.band >= 3 or hints_left() <= 0 or _phase != "aim" or _state.seeds <= 0 or not _think.is_empty():
		return false
	# a third of a second on this Mac, so off the frame: the sun spins while
	# it looks, and the aim turns when it has found the line
	var c = _state.clone()
	var box := {"a": _aim}
	var id := WorkerThreadPool.add_task(func(): box.a = c.best_angle())
	_think = {"id": id, "box": box, "at": _now()}
	_aiming = false
	hints_used += 1
	_mood(Face.Expr.PUZZLED, 0.6)
	moved.emit()
	queue_redraw()
	return true

## Reset grows the garden back. On Hard and Insane, once a seed of this try
## has flown, giving the garden up costs a heart, as running out would.
func reset_board() -> void:
	if out_of_hearts or _phase == "asleep" or _phase in ["shot", "pick", "out"]:
		return
	if not _think.is_empty():
		WorkerThreadPool.wait_for_task_completion(int(_think.id))
		_think = {}
	var t := _now()
	if max_hearts > 0 and _state.shots > 0:
		_lose_heart(t)
		if out_of_hearts:
			_run_out()
			return
	_state.balls = []
	_state.regrow()
	_fresh(t)
	_log += "·"
	moves = 0
	_running = true
	fx.cue("reset")
	if max_hearts > 0 and _split_at == t:
		_tell("MG_RESET_HEART_ONE" if hearts == 1 else "MG_RESET_HEART", Face.Expr.WORRIED, [] if hearts == 1 else [hearts])
	else:
		_say(tr("MG_TRY") % [_state.tries], Face.Expr.HAPPY)

func is_solved() -> bool:
	return _state.is_solved()

## The day's shots, never its garden: a marigold shot, a plain one, a seed in
## the pot, a lost heart, a new try, and the rainbow at the end; then the
## seal the solve earned.
func share_glyphs() -> String:
	var out := _log
	if _state.sweethearts and is_solved():
		out += " 💞 " + tr("MG_SWEET_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless and is_solved():
		out += " 🏅 " + tr("BN_FLAWLESS")
	return out

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("MG_WIN") % [Locale.number(_state.score), _state.shots]}

## The win screen waits for the party: the cat on her pad and the seal.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return maxf(WIN_HOLD, PARTY_AT + STAMP_AT + STAMP_DROP * 2.0 + 0.5)

func _on_solved() -> void:
	_solved_at = _now()
	_won = true
	# Flawless: no hint, and no heart lost on Hard and Insane, or the first
	# try on Easy and Medium.
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 else _state.tries == 1)
	_mood(Face.Expr.JOY, 100.0)
	fx.cue("solved")
	if not Motion.reduce:
		var s := _s()
		for k in 6:
			var at := _pt(Vector2(12.0 + float(k) * 15.2, 40.0 + _hash(k, 41) * 50.0))
			get_tree().create_timer(0.08 * float(k)).timeout.connect(func():
				fx.sparkle(at, Pal.SUN_RAY)
				fx.puff(at, Pal.MG_ORANGE_HI, 5))
		fx.ring(_pt(State.SUN_C), SUN_R * s * 2.0, Pal.SUN, 0.8)
		_rain = maxf(_rain, 3.0)
		_rain_coins = true
		_flash_now(Color("fff4c2"), 0.35)
		_spray(_air_bits, _pt(State.SUN_C), GOLD, 14, 640.0, "star", 1.1)
		_ring(_air_bits, _pt(State.SUN_C), 220.0, Color(GOLD, 0.9))
	_say(tr("MG_WIN") % [Locale.number(_state.score), _state.shots], Face.Expr.JOY)
	_party()

func completion_record() -> Dictionary:
	return {"score": _state.score, "shots": _state.shots, "tries": _state.tries, "log": _log,
		"hearts": hearts, "flawless": _flawless}

## A reopened daily that was already solved: every marigold picked, the
## rainbow up, the score as it was. Never check_solved(): `solved` must not
## fire twice.
func restore_completed_board() -> void:
	for i in _state.pos.size():
		if _state.kind[i] == State.ORANGE:
			_state.st[i] = State.GONE
	_state.oranges_left = 0
	_state.fever = true
	_state.score = int(completed_record.get("score", 0))
	_state.shots = int(completed_record.get("shots", 0))
	_log = String(completed_record.get("log", ""))
	hearts = clampi(int(completed_record.get("hearts", max_hearts)), 0, max_hearts)
	_flawless = bool(completed_record.get("flawless", false))
	# the clocks are pushed back; _won, not the clock's sign, says it is won
	# (Super Slider's restore bug: under 100 s after launch they go negative)
	var t := _now()
	_fever_at = t - 100.0
	_opened = t - 100.0
	_grown_at = t - 100.0
	_solved_at = t - 100.0
	_won = true
	_phase = "won"
	# the tag shows x10 already: no step-up cheer for a garden long done
	_mult_shown = _state.mult()
	_pill = null
	_cat_at = t - 100.0
	_cat_curled = false
	if _flawless or _state.sweethearts:
		_stamp_at = t - 100.0
	_layout()
	_place_cat(t)
	_say(tr("MG_DONE"), Face.Expr.JOY)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
