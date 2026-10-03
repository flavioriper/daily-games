extends "res://core/puzzle_base.gd"

## Hedgehogs as a flat board: an autumn lawn under leaf piles, with
## hedgehogs asleep under some of them. Rake a pile and the grass under it
## shows how many hedgehogs sleep in the eight cells around; a nought blows
## its neighbours clear. Flag the piles a hedgehog must be under. Rake every
## bare cell and the day is done. A wrong rake is never a loss: the hedgehog
## wakes, curls up grumpy on a rose cell, and the day goes on. The rules live
## in puzzles/hedgehogs_state.gd, which this only draws.
##
## **The gust is this board's signature.** A raked cell's leaves blow off
## when the gust reaches it -- its flood ring times Motion.WAVE_STEP after the
## rake -- flying away from the cell that was raked, and its number pops in
## just after.
##
## How it is drawn. Three meshes and some text:
##   lawn  -- the setting: the card's grass, fallen leaves, acorns and a
##            toadstool in the margins, and the wooden bed round the grid.
##            Built once a layout, outside the entrance's grow.
##   still -- every cell at rest: its ground, its pile, its flag, in bands
##            of BAND rows, one mesh a band. A band is rebuilt only when the
##            look of one of its cells changes (`_band_looks`), so a cell
##            settling redraws its own few rows and not a hundred piles.
##   live  -- every cell with something moving on it (a gust, a pile popping
##            back in, a flag dropping in, a refusal's shiver, the breeze),
##            the rake's stroke, the gust's wind, the hint's ring and the
##            win's swirl. Rebuilt only while something moves.
##   the numbers and the tally line are drawn text, one draw_set_transform a
##            cell (Mushroom Patch's precedent).
## Since the board checkup (2026-10-02) nothing on a cell is drawn in script
## while it plays: every cell's ground, pile (as it rests, pressed under a
## flag, and its mound and rim alone), the flag, a pin and the paw prints are
## looks made once (`_make_look`) at a reference cell, and each leaf kind a
## look painted in its colours, all put by RunMesh (ui/flat/run_mesh.gd) --
## a band's cells into runs of their own, a moving cell's pile under its
## squash and its flying or lifted leaves one look each. The bands and the
## live mesh are built in the reference layout's space and drawn under
## `_relay()`, so the win card's smaller relayout makes only the lawn again.
## The woken hedgehogs, and on the win every hedgehog, are HedgehogFace nodes
## in slots of their own (docs/art/flat-motion.md rule 2). The pile and the
## flag are ui/faces/leaf_pile.gd, which the tray and the menu card draw too.
##
## Spec: docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md, section 7;
## the polish (hearts, Sleepwalkers, rewards, the party, the HARVEST sound):
## docs/superpowers/specs/2026-10-01-hedgehogs-polish-design.md.
## Ported from the canvas mock at docs/brainstorm/concepts.html#hedgehogs, the
## reference for every measure.

const State = preload("res://puzzles/hedgehogs_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const HedgehogFace = preload("res://ui/faces/hedgehog_face.gd")
const Lawn = preload("res://ui/faces/leaf_pile.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Rings = preload("res://puzzles/rings2d.gd")
const Seal = preload("res://ui/flat/seal.gd")
const NapCat = preload("res://ui/faces/nap_cat.gd")
const Cat = preload("res://ui/faces/caterpillar.gd")
const RunMesh = preload("res://ui/flat/run_mesh.gd")

## The looks a cell is put together from, each made once at the reference
## cell about the cell's centre: a look's id is its kind times LOOK_SPAN plus
## its cell (or, for a leaf, its kind of leaf).
enum Look { GROUND, RAKED, WOKE, PILE, PRESSED, BACK, LEAF, FLAG, PIN, PAWS }
const LOOK_SPAN := 4096
## A leaf look's length, as a fraction of a cell: the size a pile's leaves
## are near, so a look drawn at another length scales its feather little.
const LEAF_LOOK := 0.36
## Room a band's cell keeps beyond its covered look, for a pressed pile's
## few more feather vertices.
const ROOM_SLACK := 64
## How long a quiet frame may spend making looks ahead of their first use.
const PRIME_BUDGET_MS := 1.0

## The out-of-hearts card's Back: the host takes the player back to camp.
signal leave

# --- the lawn ---
## The card's inset round the lawn, and the tally strip over it.
const PAD := 44.0
const TALLY := 72.0
const TALLY_SIZE := 34
const TALLY_GLYPH := 60.0
const TALLY_GAP := 14.0
## The numeral, as a fraction of a cell.
const NUM_SIZE := 0.54
## A flag's R, and a hint's sun dot at its foot, as fractions of a cell.
const FLAG_R := 0.46
const PIN_DOT := 0.06
## A hedgehog's seat, as a fraction of a cell.
const SEAT := 1.0
## The card's rounded corner (ui/flat/flat_host.gd's stylebox, Rings'
## CARD_RADIUS), and the wooden bed round the grid: its width, its corner,
## and the soil between the cells.
const CARD_RADIUS := 32.0
const FRAME := 14.0
const FRAME_R := 20.0
const SOIL := Color("b89a6e")
## How many leaves, acorns and toadstools the margins try to hold.
const LITTER := 22
## The still mesh is cut into bands of this many rows.
const BAND := 3

# --- the motion ---
## The gust: how long a pile's leaves take to go, and how long after they go
## the number pops in.
const LEAF_TIME := 0.45
const NUM_LAG := 0.12
## A flag shrinks out over this; one drops in from this high (in cells)
## over FLAG_DROP, and the pile under it is pressed down over the same.
const FLAG_OUT := 0.2
const FLAG_DROP := 0.26
const FLAG_FALL := 0.4
## How long the pennant shakes after the thunk.
const FLAG_FLUTTER := 0.2
## The rake's stroke across the cell it rakes, and how far into it the
## leaves go.
const RAKE_TIME := 0.3
const RAKE_LEAD := 0.12
## A flood bigger than GUST_CELLS draws this many streaks of wind out of
## the raked cell.
const STREAKS := 5
## The breeze: one row's piles rustle, a cell after another, every
## BREEZE_MIN..BREEZE_MAX seconds, and a woken hedgehog may peek meanwhile.
const BREEZE_MIN := 4.0
const BREEZE_MAX := 7.0
const BREEZE_STEP := 0.07
const RUSTLE_TIME := 0.7
const PEEK_TIME := 1.1
## The tally's sleeper breathes, and lets out a z every Z_EVERY seconds.
const BREATH := 2.6
const Z_EVERY := 3.4
const Z_TIME := 1.8
## The win's swirl of leaves across the lawn.
const SWIRL_LEAVES := 26
const SWIRL_TIME := 1.8
## An Undo re-covers its flood back to front, this apart.
const UNDO_STEP := 0.012
## How long a press must be held to do the other chip's action.
const LONG_PRESS := 0.4
## The win: the sleepers' wave starts this long after the last rake, and
## the win screen waits this long after the wave.
const WIN_LEAD := 0.3
const WIN_WAIT := 2.2
## A flood bigger than this sounds a gust rather than a rake.
const GUST_CELLS := 6
## The toast: Knight's and Rings' measure for measure.
const TOAST_HOLD := 2.6
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 40.0
const TIP_CYCLE := 8.0
const TIPS := ["HH_TIP_RAKE", "HH_TIP_NUMBER", "HH_TIP_FLAG", "HH_TIP_CHORD", "HH_TIP_WOKE"]
const TIPS_HEARTS := ["HH_TIP_RAKE", "HH_TIP_HEARTS", "HH_TIP_NUMBER", "HH_TIP_FLAG", "HH_TIP_CHORD"]
const TIPS_WALK := ["HH_TIP_WALK", "HH_TIP_RUSTLE", "HH_TIP_TUCK", "HH_TIP_BELL", "HH_TIP_HEARTS"]

# --- the press ---
## A pile under a finger sinks into the lawn over PRESS_IN and springs back
## on the release.
const PRESS_DIP := Vector2(1.07, 0.84)
const PRESS_IN := 0.08
const RELEASE_TIME := 0.26

# --- Sleepwalkers ---
## The bell rings this long after the rake that struck it (the gust is
## under way), and the two piles snuffle over WALK_TIME; input waits for
## WALK_HOLD of it.
const WALK_LEAD := 0.5
const WALK_TIME := 0.95
const WALK_HOLD := 0.5
## The moon and its three dots on the tally strip.
const MOON_R := 17.0
const PIP_R := 7.0
const PIP_GAP := 18.0
const BELL_TIME := 0.6
## A walk's paw prints on both piles, as a fraction of a cell.
const PAW := 0.085

# --- hearts (Knight's measures) ---
const HEART_ROW := 64.0
const HEART_R := 21.0
const HEART_GAP := 12.0
const HEART_PILL_PAD := Vector2(18.0, 8.0)
const HEART_PILL_RIM := 2.0
const SPLIT_TIME := 0.7
const SPLIT_FALL := 56.0
const SPLIT_SPREAD := 14.0
const SPLIT_TURN := 0.7
const HEART_BACK_TIME := 0.3
const DUSK := Color(0.74, 0.76, 0.92)
const DUSK_TIME := 0.8
const CARD_AFTER := 1.2
const CARD_AFTER_STILL := 0.3
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
const AGO := -1.0e9

# --- the rewards ---
## The streak: safe rakes in a row (not a hint's); the bubble from the third.
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0
const COMBO_DEFLATE := 0.25
const COMBO_FONT := 44
## The gags, one safe rake in three off the day's hash, one at a time.
enum Gag { NONE = -1, ACORN, LOVE, BUTTERFLY }
const GAG_SPAN := 9
const GAG_ODDS := 3
const GAG_STEP := 5
const ACORN_TIME := 1.1
const LOVE_HEARTS := 3
const LOVE_TIME := 1.2
const LOVE_RISE := 0.9
const LOVE_R := 0.13
const FLY_TIME := 1.7
## A rake whose flood is this big says Whoosh.
const BIG_GUST := 20

# --- the party ---
const PARTY_AT := 0.4
const PARTY_TIME := 3.0
const CHEERS := 12
const CAT_PX := 0.17
const CAT_AT := 0.9
const CAT_POP := 0.22
const CAT_HOPS := 3
const CAT_HOP_TIME := 0.32
const CAT_HOP_H := 0.45
const CAT_SETTLE := 0.25
const CURL_AT := 2.7
const STAMP_AT := 1.6
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.16
const STAMP_TILT := -0.22

var _state = State.new()
var fx: Node2D
## The armed chip, read by the tray (ui/flat/tile_tray.gd's refresh).
var brush: int = State.RAKE

## Per cell: when the gust reaches it (its leaves go), the cell it blows
## from, when an Undo or a Reset re-covered it, when a flag went in or out,
## when it was refused, and when anything on it stops moving.
var _blow_at := PackedFloat64Array()
var _blow_from := PackedInt32Array()
var _cover_at := PackedFloat64Array()
var _flag_at := PackedFloat64Array()
var _unflag_at := PackedFloat64Array()
var _bump_at := PackedFloat64Array()
var _rustle_at := PackedFloat64Array()
var _until := PackedFloat64Array()
## The rake's strokes, the gust's streaks: {pos, at} and {from, dir, reach,
## at, time}.
var _rakes: Array = []
var _streaks: Array = []
## The win's swirl starts at this; below zero there is none.
var _swirl_at := -100.0
var _next_breeze := 0.0
## The still mesh's bands, and the looks each was built from.
var _bands: Array = []
var _band_looks: Array = []
## The looks' cache (`_looks`, no runs), a RunMesh a band (a run a cell)
## and the live mesh's (no runs), all sharing the looks.
var _looks: RunMesh
var _band_rms: Array = []
var _live_rm: RunMesh
## The layout the looks, bands and live mesh are made in: the first with
## room on it after a deal, and any larger one; a smaller one (the win
## card's) is drawn under `_relay()`.
var _ref_cell := 0.0
var _ref_grid := Vector2.ZERO
var _cur_cell := 0.0
var _cur_grid := Vector2.ZERO
## Looks still to make ahead of their first use, a few each frame.
var _prime_ids := PackedInt32Array()
## A numeral's width, by value and pixel size.
var _num_w := {}
var _warm_combo := true
var _lawn: ArrayMesh
var _z_label: Label
var _z_tw: Tween
## Cells with something moving on them: cell -> true. They are drawn in the
## live mesh and left out of the still one until they settle.
var _moving := {}
## HedgehogFace per cell, each in a slot of its own: cell -> face, face -> slot.
var _faces := {}
var _slots := {}
var _tally_face: Control
var _rings: Array = []
## The last cell raked, where the win's wave starts.
var _last := 0
## Which deal the timers belong to: a new build bumps it and a stale timer
## does nothing.
var _turn := 0

var _opened := 0.0
## Input waits for the entrance.
var _busy_until := -100.0
var _anim_until := 0.0
var _solved_at := -1.0
var _cell := 0.0
var _grid := Vector2.ZERO
var _tally_y := 0.0
var _live: ArrayMesh
## The meshes the last _draw handed over: a canvas command holds a mesh by
## RID, so dropping the only reference leaves the renderer a freed one.
var _shown: Array = []
## The press in progress: its cell, and whether its long press has fired.
var _press_cell := -1
var _press_id := 0
## The finger holding the press (-1 the mouse), -2 with no press; a second
## finger neither starts a press nor ends the first's.
var _press_finger := -2
## Whether the move being shown is a hint's, which counts no move.
var _hinting := false
## Whether the gesture being shown already bumped for its flood.
var _gust_bumped := false
var _long_fired := false
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer
var _toast := ""
var _toast_arg := ""
var _toast_at := -100.0
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""

## The numbers as shown: the state's, copied when nothing is waiting to be
## told (a walk's new counts appear with its rustle, not with the rake that
## rang the bell), and when each last changed.
var _num_view := PackedInt32Array()
var _num_at := PackedFloat64Array()
## Per cell: when a walk snuffled it, when a finger let it go.
var _walk_at := PackedFloat64Array()
var _release_at := PackedFloat64Array()
var _press_at := -100.0
## The last walk's two cells, paw-printed alike; the moon's lit dots as
## shown, and when the bell last rang.
var _paws := Vector2i(-1, -1)
var _bell_view := 0
var _bell_at := AGO
var _bell_mesh: ArrayMesh
var _bell_key: Array = []
var _walk_told := false

var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
var _lost_ever := false
var _flawless := false
var _asleep := false
var _heart_card: Control
var _split_index := -1
var _split_at := AGO
var _back_index := -1
var _back_at := AGO
var _heart_layer: Control
var _hearts_shown: ArrayMesh
var _dusk_tw: Tween
var _was_busy := false

## -2 picks off the day; a Gag forces one (the harness).
var force_gag := -2
var _streak := 0
var _streak_gen := 0
var _rakes_n := 0
var _gag_until := 0.0
var _gag_gen := 0
var _combo_n := 0
var _combo_at := -INF
var _combo_pos := Vector2.ZERO
var _combo_popped := false
var _combo_out_at := -INF
var _combo_shown: ArrayMesh
var _combo_key: Array = []
var _life_layer: Control
var _life_shown: Array = []
var _love: Array = []     # [{"at", "t", "phase"}]
var _acorns: Array = []   # [{"at", "t", "side"}]
var _flies: Array = []    # [{"at", "t", "side"}]
var _love_mesh: ArrayMesh
var _seal_mesh: ArrayMesh
var _party_at := INF
var _stamp_at := INF
var _cat: Control
var _cat_at := INF
var _cat_curled := false

func puzzle_id() -> String: return "hedgehogs"
func title() -> String: return "Hedgehogs"

## The rules, then the band's own closing: nothing is lost (Easy, Medium),
## hearts (Hard), or Sleepwalkers (Insane).
func rules() -> String:
	var out := tr("HH_RULES")
	if _state.walkers():
		out += "\n\n" + tr("HH_RULES_WALKERS") % max_hearts
	elif max_hearts > 0:
		out += "\n\n" + tr("HH_RULES_HEARTS") % max_hearts
	else:
		out += "\n\n" + tr("HH_RULES_SAFE")
	return out

## The how-to-play card's pages, the band's own: raking and what a number
## counts, flagging a sleeper, raking round a number, a guess that wakes a
## hedgehog (a heart on Hard and Insane), Sleepwalkers (Insane), Undo and
## Reset (Reset alone on Insane), and the bulb (bands with hints). Each page
## is the board itself on one hand-made 5x4 lawn, playing the lesson
## (ui/hud/hedgehogs_tutorial_diagram.gd).
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/hedgehogs_tutorial_diagram.gd")
	var band: int = _state.difficulty
	var hints: int = State.hints_for(band)
	var hearts_n: int = State.hearts_for(band)
	var steps := [[Diagram.Lesson.RAKE, "HTP_HH_RAKE", tr("HTP_HH_RAKE_BODY")],
		[Diagram.Lesson.FLAG, "HTP_HH_FLAG", tr("HTP_HH_FLAG_BODY")],
		[Diagram.Lesson.CHORD, "HTP_HH_CHORD", tr("HTP_HH_CHORD_BODY")]]
	if hearts_n > 0:
		steps.append([Diagram.Lesson.WOKE, "HTP_HH_WOKE", tr("HTP_HH_WOKE_BODY_HEARTS") % hearts_n])
	else:
		steps.append([Diagram.Lesson.WOKE, "HTP_HH_WOKE", tr("HTP_HH_WOKE_BODY")])
	if band >= 3:
		steps.append([Diagram.Lesson.WALK, "HH_WALK_SEAL", tr("HTP_HH_WALK_BODY")])
	var undo_body := "HTP_HH_UNDO_BODY"
	if band >= 3:
		undo_body = "HTP_HH_RESET_BODY"
	elif hearts_n > 0:
		undo_body = "HTP_HH_UNDO_BODY_JUDGED"
	steps.append([Diagram.Lesson.UNDO, "HTP_WT_UNDO", tr(undo_body)])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_HH_HINT_BODY_ONE") if hints == 1 else tr("HTP_HH_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func _tips() -> Array:
	if _state.walkers():
		return TIPS_WALK
	if max_hearts > 0:
		return TIPS_HEARTS
	return TIPS

## Sleepwalkers has no hint, no Check, and an Undo that stays grey.
func capabilities() -> Array[String]:
	if _state.walkers():
		return ["undo"]
	return ["undo", "hint", "check"]

## What the phone does under each cue (docs/agents/haptics.md). A rake or a
## chord that cleared piles is one knock (`_after_rake`, by `fx.buzz`, not
## the `rake` and `gust` cues): a tap, or a bump when the flood is BIG_GUST
## piles or more (a hint's falls under its good); a flag taps as it drops
## and ticks as it is lifted, under the finger still held when a long press
## set it. The streak's confetti bumps unless that flood already has
## (`_on_safe_rake`: `confetti` is not mapped). A wake does not tap: on Easy
## and Medium, where it costs nothing but the clean lawn, it is a warn as
## the hedgehog pops up (`_wake`: `woke` fires before the stroke is through),
## on Hard and Insane the heart. The moon's bell and the walk are the
## lawn's own, like a refusal, the Whoosh, the streak's notes, the gags and
## the party: nothing. The win knocks as the sleepers' wave sets off
## (`solved`), the seal as it lands (`_party`).
const HAPTICS := {
	"flag": Haptics.TAP,
	"unflag": Haptics.TICK,
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
	"hint": Haptics.GOOD,
	"check_ok": Haptics.GOOD,
	"check": Haptics.WARN,
	"heart_back": Haptics.GOOD,
	"heart_lost": Haptics.BAD,
	"out_of_hearts": Haptics.LOSE,
	"solved": Haptics.WIN,
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	fx.haptics = HAPTICS
	add_child(fx)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	_heart_layer = Control.new()
	_heart_layer.name = "Hearts"
	_heart_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heart_layer.z_index = 1
	_heart_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_heart_layer.draw.connect(_draw_hearts)
	add_child(_heart_layer)
	_life_layer = Control.new()
	_life_layer.name = "Life"
	_life_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_life_layer.z_index = 3
	_life_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_life_layer.draw.connect(_draw_life)
	add_child(_life_layer)
	_looks = RunMesh.new(_make_look)
	_live_rm = RunMesh.new(_make_look)
	_live_rm.share_shapes(_looks)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_state.setup(rng, difficulty)
	# A new lawn takes its reference layout afresh (its cell may be smaller
	# than the last deal's).
	_ref_cell = 0.0
	_dealt()

## Everything a new lawn starts from, once the state holds it: build()'s,
## and the tutorial's hand-made lawns'.
func _dealt() -> void:
	_turn += 1
	_close_card()
	brush = State.RAKE
	max_hearts = State.hearts_for(_state.difficulty)
	_heart_used = false
	_lost_ever = false
	_flawless = false
	_deal_hearts()
	_reset_rewards()
	var n: int = _state.size()
	for a in [_blow_at, _cover_at, _flag_at, _unflag_at, _bump_at, _rustle_at, _until, _num_at, _walk_at, _release_at]:
		a.resize(n)
		a.fill(-100.0)
	_sync_numbers()
	_paws = Vector2i(-1, -1)
	_bell_view = 0
	_bell_at = AGO
	_walk_told = false
	_blow_from.resize(n)
	_blow_from.fill(-1)
	_moving = {}
	_bands = []
	_clear_faces()
	_rings = []
	_rakes = []
	_streaks = []
	_swirl_at = -100.0
	_solved_at = -1.0
	_press_cell = -1
	_press_finger = -2
	_toast = ""
	_toast_at = -100.0
	_last = int(_state.g.start)
	_opened = _now()
	# The opening's gust plays once the card has popped in.
	var gust_at := _opened + (0.0 if Motion.reduce else Motion.ENTER_DELAY + Motion.ENTER_POP)
	var opening := PackedByteArray()
	opening.resize(n)
	var flood: Array[Vector2i] = State.Gen.flood(_state.g, opening, _state.g.start)
	_gust_cells(flood, int(_state.g.start), gust_at, 0)
	_busy_until = gust_at
	_next_breeze = gust_at + randf_range(BREEZE_MIN, BREEZE_MAX)
	if _tally_face == null:
		_tally_face = HedgehogFace.new()
		_tally_face.expression = Face.Expr.SLEEPY
		_tally_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tally_face)
		Motion.pulse(_tally_face, "scale", Vector2.ONE, Vector2(1.05, 0.95), BREATH)
	_start_z()
	_layout()
	fx.cue("enter")
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()

## Every heart back and the morning light: a new deal and Try again.
func _deal_hearts() -> void:
	hearts = max_hearts
	out_of_hearts = false
	_asleep = false
	_split_index = -1
	_split_at = AGO
	_back_index = -1
	_back_at = AGO
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	if _heart_layer != null:
		_heart_layer.queue_redraw()

## The numbers shown catch up with the state's.
func _sync_numbers() -> void:
	_num_view = _state.g.num.duplicate() if not _state.g.is_empty() else PackedInt32Array()

func _clear_faces() -> void:
	for face in _faces.values():
		var slot: Control = _slots[face]
		slot.queue_free()
	_faces = {}
	_slots = {}

# --- layout ---

func _cell_for(available: float) -> float:
	if _state.size() == 0:
		return 0.0
	return maxf(0.0, minf((size.x - 2.0 * _pad()) / float(_state.cols()),
		(available - 2.0 * _pad() - _top_h()) / float(_state.rows())))

## The card's inset round the lawn and its strip (the tutorial's is less).
func _pad() -> float:
	return PAD

## The strip over the lawn: the tally, and on Hard and Insane the hearts'
## pill over it.
func _top_h() -> float:
	return TALLY + (HEART_ROW if max_hearts > 0 else 0.0)

func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * float(_state.rows()) + 2.0 * _pad() + _top_h())

func card_centred() -> bool:
	return true

func _layout() -> void:
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var field := Vector2(_state.cols(), _state.rows()) * _cell
	var tall := minf(size.y, field.y + 2.0 * _pad() + _top_h())
	var top := (size.y - tall) * 0.5
	_grid = Vector2(size.x * 0.5 - field.x * 0.5, top + _pad() + _top_h())
	_tally_y = _grid.y - TALLY * 0.5
	for c: int in _faces:
		_seat(_faces[c], _centre(c))
	if _tally_face != null:
		_tally_face.size = Vector2.ONE * TALLY_GLYPH
		_tally_face.pivot_offset = Vector2(TALLY_GLYPH * 0.5, TALLY_GLYPH * 0.8)
	_take_ref()
	# A curled-up nap cat follows the bed (the win card lays the board out
	# again smaller; Knight's lesson).
	if is_instance_valid(_cat) and _cat_curled:
		var px := _cat_px()
		_cat.size = Vector2(px, px)
		_cat.pivot_offset = _cat.size * Vector2(0.5, 0.85)
		_cat.position = _cat_spot() - _cat.size * 0.5
	_lawn = null
	_love_mesh = null
	_seal_mesh = null
	_refresh()
	if _heart_layer != null:
		_heart_layer.queue_redraw()
	if _life_layer != null:
		_life_layer.queue_redraw()

## The layout the looks, bands and live mesh are made in: taken on the first
## layout with room on it after a deal, and again on any larger one (a look
## made small and drawn large would blur). A smaller one -- the win card's
## -- keeps it, and everything is drawn under `_relay()`.
func _take_ref() -> void:
	if _cell <= 0.0:
		return
	if _ref_cell > 0.0 and _cell <= _ref_cell + 0.01:
		return
	_ref_cell = _cell
	_ref_grid = _grid
	_looks.reset()
	_live_rm.share_shapes(_looks)
	_band_rms = []
	_bands = []
	_live = null
	# Made ahead, a few a frame: what a rake, a flag or the breeze will put
	# first (a pile at rest and the covered ground are made with the bands).
	_prime_ids = PackedInt32Array()
	for id in [_id(Look.WOKE, 0), _id(Look.FLAG, 0), _id(Look.PIN, 0), _id(Look.PAWS, 0),
			_id(Look.LEAF, 0), _id(Look.LEAF, 1), _id(Look.LEAF, 2)]:
		_prime_ids.append(id)
	for kind in [Look.RAKED, Look.BACK, Look.PRESSED]:
		for c in _state.size():
			_prime_ids.append(_id(kind, c))
	_prime_ids.reverse()

## The reference layout onto the one the board has now.
func _relay() -> Transform2D:
	if _ref_cell <= 0.0:
		return Transform2D.IDENTITY
	var k := _cell / _ref_cell
	return Transform2D(0.0, Vector2(k, k), 0.0, _grid - _ref_grid * k)

## While a mesh is made, `_cell` and `_grid` (and so `_centre`) answer the
## reference layout; `_out_of_ref` puts the layout back.
func _into_ref() -> void:
	_cur_cell = _cell
	_cur_grid = _grid
	_cell = _ref_cell
	_grid = _ref_grid

func _out_of_ref() -> void:
	_cell = _cur_cell
	_grid = _cur_grid

static func _id(kind: int, c: int) -> int:
	return kind * LOOK_SPAN + c

## Makes the looks still waiting, newest need first, for at most
## PRIME_BUDGET_MS.
func _prime_looks() -> void:
	if _prime_ids.is_empty() or _ref_cell <= 0.0:
		return
	var t0 := Time.get_ticks_usec()
	while not _prime_ids.is_empty() and Time.get_ticks_usec() - t0 < PRIME_BUDGET_MS * 1000.0:
		var id := _prime_ids[_prime_ids.size() - 1]
		_prime_ids.resize(_prime_ids.size() - 1)
		_looks.shape(id)

## Look `id` drawn at the reference cell about the cell's centre: the
## ground, raked or woken, the pile as it rests, pressed under a flag, or
## its mound and rim alone; a leaf in slot colours (0 the leaf, 1 its
## midrib); the flag in slot colours (Lawn.flag_inks' order); a hint's pin;
## the paw prints.
func _make_look(id: int) -> Face.Builder:
	var b := Face.Builder.new()
	var kind := id / LOOK_SPAN
	var c := id % LOOK_SPAN
	var s := _ref_cell
	match kind:
		Look.GROUND:
			Lawn.ground(b, Vector2.ZERO, s, c, false, false)
		Look.RAKED:
			Lawn.ground(b, Vector2.ZERO, s, c, true, false)
		Look.WOKE:
			Lawn.ground(b, Vector2.ZERO, s, c, true, true)
		Look.PILE:
			Lawn.pile(b, Vector2.ZERO, s, c)
		Look.PRESSED:
			Lawn.pile(b, Vector2.ZERO, s, c, 0.0, Vector2.UP, Lawn.PRESSED)
		Look.BACK:
			Lawn.back(b, Vector2.ZERO, s, c)
		Look.LEAF:
			Lawn.leaf(b, Vector2.ZERO, s * LEAF_LOOK, 0.0, RunMesh.slot(0), c, 1.0, RunMesh.slot(1))
		Look.FLAG:
			Lawn.flag(b, Vector2.ZERO, s * FLAG_R, false, Vector2.ONE, 1.0, 0.0,
				[RunMesh.slot(0), RunMesh.slot(1), RunMesh.slot(2), RunMesh.slot(3), RunMesh.slot(4)])
		Look.PIN:
			b.disc(Vector2(0.3, 0.3) * s, s * PIN_DOT, Pal.SUN)
		Look.PAWS:
			_draw_paws(b, Vector2.ZERO, s)
	return b

func _centre(c: int) -> Vector2:
	return _grid +(Vector2(c % _state.cols(), c / _state.cols()) + Vector2(0.5, 0.5)) * _cell

## Control-local point over the centre of the cell at (row, column), the name
## every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(r * _state.cols() + c)

func _cell_at(local: Vector2) -> int:
	if _cell <= 0.0:
		return -1
	var v := (local - _grid) / _cell
	var x := int(floor(v.x))
	var y := int(floor(v.y))
	if x < 0 or y < 0 or x >= _state.cols() or y >= _state.rows():
		return -1
	return y * _state.cols() + x

## A hedgehog seated on the cell `centre`, in a slot of its own so the pop
## and the hop never fight the layout.
func _seat(face: Control, centre: Vector2) -> void:
	var seat := Vector2.ONE * _cell * SEAT
	var slot: Control = _slots[face]
	slot.size = seat
	slot.position = centre - seat * 0.5
	face.size = seat
	face.pivot_offset = seat * 0.5

func _face_at(c: int, expr: int) -> Control:
	if _faces.has(c):
		var have: Control = _faces[c]
		have.expression = expr
		return have
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	var face := HedgehogFace.new()
	face.expression = expr
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(face)
	_faces[c] = face
	_slots[face] = slot
	_seat(face, _centre(c))
	return face

# --- the moments ---

## Marks `c` as moving until `until`: drawn live, left out of the still mesh.
func _touch(c: int, until: float) -> void:
	_until[c] = maxf(_until[c], until)
	_moving[c] = true
	_busy_for(until - _now())

## A flood's gust: each cell's leaves go at its ring (offset by `ring0`)
## times WAVE_STEP after `at`, blowing away from `from`.
func _gust_cells(flood: Array, from: int, at: float, ring0: int) -> void:
	for p: Vector2i in flood:
		var when := at + (0.0 if Motion.reduce else float(p.y + ring0) * Motion.WAVE_STEP)
		_blow_at[p.x] = when
		_blow_from[p.x] = from
		_touch(p.x, when + LEAF_TIME + NUM_LAG + Motion.POP_IN)

## `lead` holds the leaves back while the rake's stroke gets into the pile.
func _gust(cells: PackedInt32Array, rings: PackedInt32Array, from: int, lead := 0.0) -> void:
	var t := _now() + lead
	var flood: Array = []
	var far := 0
	for i in cells.size():
		flood.append(Vector2i(cells[i], rings[i]))
		far = maxi(far, rings[i])
	_gust_cells(flood, from, t, 0)
	if not cells.is_empty():
		_last = cells[cells.size() - 1]
		fx.cue("gust" if cells.size() > GUST_CELLS else "rake")
	if cells.size() > GUST_CELLS and not Motion.reduce:
		_wind(from, far, t)

## Streaks of wind out of the cell `from`, as far as the flood's last ring.
func _wind(from: int, far: int, at: float) -> void:
	var turn := Lawn.h01(from, _turn) * TAU
	var time := minf(1.1, float(far) * Motion.WAVE_STEP + 0.45)
	for k in STREAKS:
		var dir := Vector2.from_angle(turn + TAU * float(k) / float(STREAKS) + (Lawn.h01(from, k) - 0.5) * 0.6)
		# Its cell and its reach in cells: drawn in the reference layout.
		_streaks.append({"from": from, "dir": dir, "reach": (float(far) * 0.55 + 1.2) * (0.75 + 0.35 * Lawn.h01(k, from)),
			"at": at + float(k) * 0.03, "time": time, "bend": (Lawn.h01(k + 5, from) - 0.5) * 2.0})
	_busy_for(at - _now() + time + float(STREAKS) * 0.03)

## The rake's stroke across the cell `c`.
func _rake_stroke(c: int) -> void:
	if Motion.reduce:
		return
	_rakes.append({"cell": c, "at": _now()})
	_busy_for(RAKE_TIME)

## A hedgehog a rake woke: its cell washes rose, it pops in curled and
## shivers, and the toast says so kindly.
func _wake(c: int, lead := 0.0, tell := true) -> void:
	var t := _now() + lead
	_blow_at[c] = t
	_blow_from[c] = c
	_touch(c, t + LEAF_TIME)
	var face := _face_at(c, Face.Expr.STRAIN)
	if not Motion.reduce:
		face.scale = Vector2.ZERO
	Motion.pop_in(face, Motion.POP_IN, lead)
	# Bristles once it is in, then shivers, and huffs a puff of dust.
	Motion.shiver(face, Motion.SHIVER_PX * 3.0, Motion.SHIVER_TIME * 2.0)
	if not Motion.reduce:
		# bump reads the scale it starts from, so it waits for the pop.
		_later(lead + Motion.POP_IN, func():
			if not is_instance_valid(face):
				return
			Motion.bump(face, 0.16)
			fx.puff(_centre(c) + Vector2(-_cell * 0.3, -_cell * 0.1), Pal.PAPER, 4))
	fx.cue("woke")
	if max_hearts == 0:
		# Free, but it is on the win screen: a warn as it pops up.
		if lead > 0.0:
			_later(lead, fx.buzz.bind(Haptics.WARN))
		else:
			fx.buzz(Haptics.WARN)
	if tell:
		_tell("HH_WOKE_FIRST" if _state.woken == 1 else "HH_WOKE_AGAIN", Face.Expr.STRAIN)

func _refuse(c: int, key: String) -> void:
	_bump_at[c] = _now()
	_touch(c, _now() + Motion.SHIVER_TIME)
	fx.cue("refuse")
	_tell(key, Face.Expr.STRAIN)

## One tap's worth on cell `c`, with the rake or the flag. A raked number
## always chords.
func _act(c: int, use: int) -> void:
	if is_done() or out_of_hearts or c < 0 or _now() < _busy_until:
		return
	if _state.open[c] == 1:
		# Raked, but its gust has not reached it yet: it still looks
		# covered, so a tap there waits rather than chording.
		if _now() < float(_blow_at[c]):
			return
		_show_chord(_state.chord(c), c)
		return
	if use == State.FLAG:
		var f: Dictionary = _state.toggle_flag(c)
		match String(f.kind):
			"laid":
				_flag_at[c] = _now()
				_touch(c, _now() + FLAG_DROP + Motion.BUMP_TIME)
				fx.cue("flag")
				_after_move()
			"lifted":
				_unflag_at[c] = _now()
				_touch(c, _now() + FLAG_OUT)
				fx.cue("unflag")
				_after_move()
			"refused_pin":
				_refuse(c, "HH_PINNED")
		return
	_show_rake(_state.rake(c), c)

func _show_rake(r: Dictionary, c: int) -> void:
	var lead := 0.0 if Motion.reduce else RAKE_LEAD
	match String(r.kind):
		"raked":
			_rake_stroke(c)
			_gust(r.cells, r.rings, c, lead)
			_after_rake(r, c, PackedInt32Array(), lead)
			_after_move()
		"woke":
			_last = c
			_rake_stroke(c)
			_wake(c, lead, max_hearts == 0)
			_after_rake(r, c, PackedInt32Array([c]), lead)
			_after_move()
		"refused_flag":
			_refuse(c, "HH_FLAGGED")
		"refused_pin":
			_refuse(c, "HH_PINNED")
		"chord", "too_few", "too_many":
			_show_chord(r, c)

func _show_chord(r: Dictionary, c: int) -> void:
	match String(r.kind):
		"chord":
			_gust(r.cells, r.rings, c)
			var tell := max_hearts == 0
			for w: int in r.woke:
				_wake(w, 0.0, tell)
				tell = false
			fx.cue("chord")
			_after_rake(r, c, r.woke, 0.0)
			_after_move()
		"too_few":
			_refuse(c, "HH_CHORD_FEW")
		"too_many":
			_refuse(c, "HH_CHORD_MANY")

## What a rake gesture brings beyond its gust: a wake costs a heart on Hard
## and Insane; a safe one (not a hint's) grows the streak and may play a gag;
## a big flood says Whoosh; on Sleepwalkers the bell counts it, and when it
## rings a hedgehog walks once the gust is under way. The numbers shown wait
## for the walk.
func _after_rake(r: Dictionary, c: int, woke: PackedInt32Array, lead: float) -> void:
	var cells: PackedInt32Array = r.cells
	var lands := _now() + lead
	# A big flood by hand is the move's one knock, over its tap and in place
	# of the streak's confetti.
	_gust_bumped = cells.size() >= BIG_GUST and woke.is_empty() and not _hinting
	if not cells.is_empty() and String(r.kind) != "woke":
		fx.buzz(Haptics.BUMP if _gust_bumped else Haptics.TAP)
	if not woke.is_empty():
		# The wake holds the HUD until the hedgehog has popped in.
		_busy_until = maxf(_busy_until, _now() + lead + Motion.POP_IN + 0.05)
		_break_streak()
		_clear_gags()
		if max_hearts > 0:
			_lose_heart(lands)
			_later(lead + 0.25, func(): fx.cue("heart_lost"))
			_tell_hearts("HH_WOKE_HEART")
			if out_of_hearts:
				_later(lead + 0.9, _run_out)
	elif not cells.is_empty() and not _hinting:
		_on_safe_rake(c, lands)
	if cells.size() >= BIG_GUST and not Motion.reduce:
		_later(lead + 0.15, func():
			fx.sparkle(_centre(c), Pal.SUN)
			fx.cue("whoosh"))
		if woke.is_empty():
			_say(tr("HH_WHOOSH"), Face.Expr.JOY)
	_queue_walk(r, lead)

## Sleepwalkers' bell. A gesture that did not ring it lights a dot; one that
## did lights the third, holds input, and after WALK_LEAD rings: the two
## piles snuffle alike and the numbers round them change.
func _queue_walk(r: Dictionary, lead: float) -> void:
	if not r.has("walk") or not _state.walkers() or _state.is_solved():
		_sync_numbers()
		return
	if _state.bell != 0:
		_bell_view = _state.bell
		_bell_at = _now()
		_sync_numbers()
		return
	_bell_view = State.Gen.WALK_EVERY
	_bell_at = _now()
	var w: Vector2i = r.walk
	var wait := lead + (0.05 if Motion.reduce else WALK_LEAD)
	_busy_until = maxf(_busy_until, _now() + wait + (0.05 if Motion.reduce else WALK_HOLD))
	_busy_for(wait + WALK_TIME)
	_later(wait, func(): _show_walk(w))

func _show_walk(w: Vector2i) -> void:
	var t := _now()
	_bell_view = 0
	_bell_at = t
	fx.cue("bell")
	if w.x < 0:
		_sync_numbers()
		_say(tr("HH_WALK_NONE"), Face.Expr.SLEEPY)
		_refresh()
		return
	_paws = w
	for c in [w.x, w.y]:
		_walk_at[c] = t
		_touch(c, t + WALK_TIME)
		if not Motion.reduce:
			fx.puff(_centre(c) + Vector2(0.0, _cell * 0.1), Pal.AUTUMN_LEAVES[c % Pal.AUTUMN_LEAVES.size()], 6)
			fx.ring(_centre(c), _cell * 0.45, Pal.MOON_INK)
	# Every number whose count the walk changed pops as the piles settle.
	var now_num: PackedInt32Array = _state.g.num
	for c in _state.size():
		if _state.open[c] == 1 and c < _num_view.size() and _num_view[c] != now_num[c]:
			_num_at[c] = t + (0.0 if Motion.reduce else WALK_TIME * 0.45)
	_sync_numbers()
	_later(0.0 if Motion.reduce else 0.18, func(): fx.cue("snuffle"))
	# Only the first walk is toasted: the toast sits over the lawn's foot,
	# and on Sleepwalkers every number there counts.
	if _walk_told:
		_say(tr("HH_WALK"), Face.Expr.WORRIED)
	else:
		_tell("HH_WALK_FIRST", Face.Expr.WORRIED)
	_walk_told = true
	_refresh()

## A move counts (note_move emits `moved` and checks the solve); a hint's
## does not, so it emits and checks for itself, as PuzzleBase's contract has
## it.
func _after_move() -> void:
	if _hinting:
		moved.emit()
		check_solved()
	else:
		note_move()
	_refresh()

## Runs `fn` after `delay`, unless the board has left the tree meanwhile or
## a new deal has begun.
func _later(delay: float, fn: Callable) -> void:
	var turn := _turn
	get_tree().create_timer(maxf(0.0, delay)).timeout.connect(func():
		if is_inside_tree() and turn == _turn:
			fn.call())

# --- frames ---

func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0 or _state.size() == 0:
		return
	var t := _now()
	# A wake's heart or a walk lets go of the HUD: it greyed Undo, Hint and
	# Reset.
	var bz := busy()
	if _was_busy and not bz:
		moved.emit()
	_was_busy = bz
	if _tick_life(t):
		_life_layer.queue_redraw()
	if t >= _cat_at and not _cat_curled:
		_place_cat(t)
	if max_hearts > 0 and (t - _split_at < SPLIT_TIME + 0.1 or t - _back_at < HEART_BACK_TIME + 0.1 \
			or t - _opened < Motion.ENTER_DELAY + Motion.POP_IN + 0.1):
		_heart_layer.queue_redraw()
	# A band a frame while the card is still hidden before its entrance, so
	# the first frame it shows does not pay for a hundred piles at once.
	if t - _opened < Motion.ENTER_DELAY and not Motion.reduce:
		_update_bands(t, 1)
	elif not _prime_ids.is_empty():
		_prime_looks()
	var settled := false
	for c: int in _moving.keys():
		if float(_until[c]) <= t:
			_moving.erase(c)
			settled = true
	if t >= _next_breeze:
		_breeze(t)
	if settled or _animating(t):
		_refresh()
	elif _toast != "" and t - _toast_at < TOAST_HOLD + 0.1:
		queue_redraw()

## The breeze: one row's piles rustle, a cell after another, and a woken
## hedgehog may peek out of its ball. Every covered pile takes it alike, so
## it says nothing about what sleeps under which.
func _breeze(t: float) -> void:
	_next_breeze = t + randf_range(BREEZE_MIN, BREEZE_MAX)
	if Motion.reduce or is_done() or out_of_hearts or _cell <= 0.0:
		return
	var cols: int = _state.cols()
	var row := randi() % _state.rows()
	var from_left := randf() < 0.5
	for x in cols:
		var c := row * cols + x
		if _shows_raked(c, t):
			continue
		var when := t + float(x if from_left else cols - 1 - x) * BREEZE_STEP
		_rustle_at[c] = when
		_touch(c, when + RUSTLE_TIME)
	if not _faces.is_empty() and randf() < 0.6:
		var cells := _faces.keys()
		var face: Control = _faces[cells[randi() % cells.size()]]
		if face.expression == Face.Expr.STRAIN:
			face.expression = Face.Expr.WORRIED
			_later(PEEK_TIME, func():
				if is_instance_valid(face) and face.expression == Face.Expr.WORRIED:
					face.expression = Face.Expr.STRAIN)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()

func _animating(t: float) -> bool:
	if not _moving.is_empty() or t < _anim_until:
		return true
	if Motion.reduce:
		return false
	return t - _opened < Motion.ENTER_DELAY + Motion.ENTER_POP + 0.1

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds + 0.05)

func _refresh() -> void:
	_live = null
	queue_redraw()

# --- the drawing ---

func _draw() -> void:
	if _state.size() == 0 or _cell <= 0.0:
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var grow := Motion.wide_pop_scale(since)
	var mid := _grid + Vector2(_state.cols(), _state.rows()) * _cell * 0.5
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var tint := Color(1.0, 1.0, 1.0, seen)
	if _lawn == null:
		_lawn = _build_lawn()
	draw_mesh(_lawn, null)
	_update_bands(t)
	if _live == null:
		_live = _build_live(t)
	var shown: Array = [_lawn]
	var at := xf * _relay()
	for m in _bands + [_live]:
		if m != null:
			draw_mesh(m, null, at, tint)
			shown.append(m)
	_draw_numbers(t, xf, seen)
	_draw_tally(t, seen, shown)
	_draw_toast(t, shown)
	_shown = shown

## The setting, built once a layout: the card's autumn grass in mown bands,
## soft shade, fallen leaves, acorns and a toadstool in the margins (never
## under the bed or behind the tally's words), and the wooden bed round the
## grid with soil showing between its cells.
func _build_lawn() -> ArrayMesh:
	var b := Face.Builder.new()
	var w := size.x
	var h := size.y
	var clip := Face.Builder.round_rect(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0, CARD_RADIUS - 2.0)
	var grass := Pal.LAWN.lerp(Pal.PAPER, 0.62)
	Rings._clip_polygon(b, clip, grass, clip)
	var band := 84.0
	for k in int(ceil(h / band)):
		if k % 2 == 1:
			Rings._clip_polygon(b, PackedVector2Array([Vector2(0.0, k * band), Vector2(w, k * band),
				Vector2(w, (k + 1) * band), Vector2(0.0, (k + 1) * band)]), Pal.LAWN.lerp(Pal.PAPER, 0.56), clip)
	var seed_i: int = _state.cols() * 97 + _state.rows() * 13 + int(_state.g.start)
	for d in 6:
		var at := Vector2(w * Lawn.h01(seed_i, d + 200), h * Lawn.h01(seed_i, d + 300))
		Scenery.soft_disc(b, at, 110.0, 70.0, Color(Pal.LAWN_DEEP, 0.08))
	var field := Vector2(_state.cols(), _state.rows()) * _cell
	var bed := Rect2(_grid - Vector2.ONE * (FRAME + 18.0), field + Vector2.ONE * (FRAME + 18.0) * 2.0)
	var words := Rect2(w * 0.5 - 260.0, _tally_y - 40.0, 520.0, 80.0)
	var placed := 0
	for f in LITTER * 4:
		if placed >= LITTER:
			break
		var at := Vector2(30.0 + (w - 60.0) * Lawn.h01(seed_i, f + 500), 30.0 + (h - 60.0) * Lawn.h01(seed_i, f + 600))
		if bed.has_point(at) or words.has_point(at):
			continue
		var pick := Lawn.h01(seed_i, f + 700)
		if pick < 0.08:
			Lawn.toadstool(b, at, 15.0)
		elif pick < 0.2:
			Lawn.acorn(b, at, 10.0, (Lawn.h01(f, 3) - 0.5) * 1.6)
		elif pick < 0.35:
			Scenery.tuft(b, at, 18.0 + 8.0 * Lawn.h01(f, 4))
		else:
			var colour: Color = Pal.AUTUMN_LEAVES[f % Pal.AUTUMN_LEAVES.size()]
			var rot := Lawn.h01(f, 5) * TAU
			Lawn.leaf(b, at + Vector2(2.0, 3.0), 30.0, rot, Color(Pal.TEXT, 0.1), f % 3)
			Lawn.leaf(b, at, 30.0 + 8.0 * Lawn.h01(f, 6), rot, colour.lerp(grass, 0.25), f % 3)
		placed += 1
	# The bed: a shadow, the frame with its grain, then soil.
	var out := _grid - Vector2.ONE * FRAME
	var out_size := field + Vector2.ONE * FRAME * 2.0
	Scenery.soft_disc(b, out + out_size * Vector2(0.5, 1.0) + Vector2(0.0, 6.0), out_size.x * 0.55, 26.0, Color(Pal.TEXT, 0.14))
	b.fan(Face.Builder.round_rect(out + Vector2(0.0, 5.0), out_size, FRAME_R), Pal.PLAQUE_DEEP)
	b.fan(Face.Builder.round_rect(out, out_size, FRAME_R), Pal.PLAQUE)
	b.fan(Face.Builder.round_rect(out + Vector2.ONE * 2.5, out_size - Vector2.ONE * 5.0, FRAME_R - 2.5), Pal.WOOD)
	var grain := Color(Pal.PLAQUE_DEEP, 0.25)
	var mid := FRAME * 0.5
	for k: float in [-1.0, 1.0]:
		var off := k * 2.5
		b.stroke(PackedVector2Array([_grid + Vector2(field.x * 0.08, -mid + off), _grid + Vector2(field.x * 0.4, -mid + off)]), 1.5, grain)
		b.stroke(PackedVector2Array([_grid + Vector2(field.x * 0.58, field.y + mid + off), _grid + Vector2(field.x * 0.93, field.y + mid + off)]), 1.5, grain)
		b.stroke(PackedVector2Array([_grid + Vector2(-mid + off, field.y * 0.3), _grid + Vector2(-mid + off, field.y * 0.7)]), 1.5, grain)
		b.stroke(PackedVector2Array([_grid + Vector2(field.x + mid + off, field.y * 0.12), _grid + Vector2(field.x + mid + off, field.y * 0.46)]), 1.5, grain)
	b.fan(Face.Builder.round_rect(_grid - Vector2.ONE * 2.0, field + Vector2.ONE * 4.0, FRAME_R - 8.0), Pal.PLAQUE)
	b.fan(Face.Builder.round_rect(_grid, field, FRAME_R - 10.0), SOIL)
	for c in 4:
		var corner := _grid + Vector2(float(c % 2), float(c / 2)) * field + Vector2(-1.0 if c % 2 == 0 else 1.0, -1.0 if c < 2 else 1.0) * mid
		b.disc(corner, 4.0, Pal.PLAQUE_DEEP)
	return b.mesh()

## Rebuilds each band of the still mesh whose cells' looks have changed
## since it was built: every cell with nothing moving on it, its looks put
## into its own run. At most `limit` bands when it is not negative.
func _update_bands(t: float, limit := -1) -> void:
	if _ref_cell <= 0.0:
		return
	var cols: int = _state.cols()
	var n := int(ceil(float(_state.rows()) / float(BAND)))
	if _bands.size() != n or _band_rms.size() != n:
		_bands.resize(n)
		_bands.fill(null)
		_band_looks.resize(n)
		_band_looks.fill(PackedInt32Array())
		_band_rms = []
		for k in n:
			var rm := RunMesh.new(_make_look)
			rm.share_shapes(_looks)
			_band_rms.append(rm)
	for k in n:
		var first := k * BAND * cols
		var last := mini(_state.size(), (k + 1) * BAND * cols)
		var looks := PackedInt32Array()
		looks.resize(last - first)
		for c in range(first, last):
			looks[c - first] = -1 if _moving.has(c) else _look(c, t)
		if _bands[k] != null and looks == _band_looks[k]:
			continue
		if limit == 0:
			return
		limit -= 1
		_into_ref()
		_bands[k] = _build_band(k, first, last, t)
		_out_of_ref()
		_band_looks[k] = looks

## Band `k` (cells first..last-1) at rest: a run a cell, laid the first
## time as long as its ground and pile, so a cell's looks are offset once
## and kept; then, after every run, the flags, pins and paw prints, which
## only a few cells wear (each stays inside its own cell, so drawing it
## after its neighbours' piles changes no pixel).
func _build_band(k: int, first: int, last: int, t: float) -> ArrayMesh:
	var rm: RunMesh = _band_rms[k]
	if not rm.laid():
		for c in range(first, last):
			rm.room(0, c, _looks.size_of(_id(Look.GROUND, c)) + _looks.size_of(_id(Look.PILE, c)) + ROOM_SLACK)
	rm.begin()
	var marked: Array = []
	for c in range(first, last):
		if not _moving.has(c):
			rm.open(0, c)
			if _put_rest(rm, c, t):
				marked.append(c)
	rm.close()
	for c: int in marked:
		_put_marks(rm, c, t)
	return rm.mesh()

## A cell at rest, as `_put_cell` puts it once nothing on it moves: its
## ground and its pile, pressed under a standing flag. Whether it wears a
## flag or paw prints (`_put_marks`).
func _put_rest(rm: RunMesh, c: int, t: float) -> bool:
	var at := _centre(c)
	if _shows_raked(c, t):
		rm.put(_id(Look.WOKE, 0) if _state.woke[c] == 1 else _id(Look.RAKED, c), [], Transform2D(0.0, at))
		return false
	rm.put(_id(Look.GROUND, c), [], Transform2D(0.0, at))
	var up := _flag_up(c, t)
	if up:
		rm.put(_id(Look.PRESSED, c), [], Transform2D(0.0, at + Vector2(0.0, _cell * 0.3 * (1.0 - Lawn.PRESSED.y))))
	else:
		rm.put(_id(Look.PILE, c), [], Transform2D(0.0, at))
	return up or _paw_on(c)

## A resting cell's paw prints, or its flag and a hint's pin.
func _put_marks(rm: RunMesh, c: int, t: float) -> void:
	var at := _centre(c)
	if _paw_on(c):
		rm.put(_id(Look.PAWS, 0), [], Transform2D(0.0, at))
	if _flag_up(c, t):
		rm.put(_id(Look.FLAG, 0), Lawn.flag_inks(_state.wrong[c] == 1), Transform2D(0.0, at + Vector2(0.0, _cell * 0.02)))
		if _state.pin[c] == 1:
			rm.put(_id(Look.PIN, 0), [], Transform2D(0.0, at))

## Everything a resting cell's drawing depends on.
func _look(c: int, t: float) -> int:
	var raked := 1 if _shows_raked(c, t) else 0
	var up := 1 if _flag_up(c, t) else 0
	var paw := 1 if _paw_on(c) else 0
	return raked | (int(_state.woke[c]) << 1) | (up << 2) | (int(_state.wrong[c]) << 3) | (int(_state.pin[c]) << 4) \
		| (paw << 5)

## Whether cell `c` carries the last walk's paw prints: one of its two
## cells, still covered and unflagged.
func _paw_on(c: int) -> bool:
	return (c == _paws.x or c == _paws.y) and _state.open[c] == 0 and _state.flag[c] == 0 \
		and _state.woke[c] == 0 and _solved_at < 0.0

## Every moving cell, the wind, the win's swirl, the rake's strokes and the
## hint's ring, in the reference layout. The cells go latest-settling first,
## so one that settles or starts to blow changes the size of nothing put
## before it and the looks after it keep their places' indices.
func _build_live(t: float) -> ArrayMesh:
	if _ref_cell <= 0.0:
		return null
	_into_ref()
	var rm := _live_rm
	rm.begin()
	var cells: Array = _moving.keys()
	cells.sort_custom(func(a: int, b: int) -> bool:
		return _until[a] > _until[b] or (_until[a] == _until[b] and a < b))
	for c: int in cells:
		_put_cell(rm, c, t)
	var b := Face.Builder.new()
	_draw_wind(b, t)
	rm.put_builder(b)
	_put_swirl(rm, t)
	b = Face.Builder.new()
	_draw_rakes(b, t)
	var keep: Array = []
	for r: Dictionary in _rings:
		var u := (t - float(r.at)) / Motion.RING_TIME
		if u < 1.0:
			keep.append(r)
		if u >= 0.0 and u < 1.0:
			var rad := _cell * (0.3 + 0.4 * u)
			b.stroke(Face.Builder.ring(_centre(int(r.cell)), rad, rad), _cell * 0.05 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)
	_rings = keep
	rm.put_builder(b)
	_out_of_ref()
	return rm.mesh()

## Whether cell `c` shows as raked at `t`: raked (or woken, or a sleeper
## uncovered by the win) and the gust has reached it.
func _shows_raked(c: int, t: float) -> bool:
	var uncovered: bool = _state.open[c] == 1 or _state.woke[c] == 1 \
		or (_solved_at >= 0.0 and _state.is_hog(c))
	return uncovered and t >= float(_blow_at[c])

## One moving cell: its ground, its pile squashed, rustling or blowing off,
## its flag. The ground and a still pile are the cell's looks under the
## moment's shiver and squash; a rustle puts the mound and rim as one look
## and lifts each top leaf as a leaf look; a gust carries every leaf off as
## one look each. Only a fluttering pennant is drawn live.
func _put_cell(rm: RunMesh, c: int, t: float) -> void:
	var s := _cell
	var at := _centre(c)
	at.x += Motion.shiver_offset(t - float(_bump_at[c]), s * 0.03)
	var raked := _shows_raked(c, t)
	var ground := _id(Look.RAKED, c) if raked else _id(Look.GROUND, c)
	if raked and _state.woke[c] == 1:
		ground = _id(Look.WOKE, 0)
	rm.put(ground, [], Transform2D(0.0, at))
	var rustle := _rustle(c, t)
	if raked:
		var u := 1.0 if Motion.reduce else (t - float(_blow_at[c])) / LEAF_TIME
		if u < 1.0:
			_put_leaves(rm, Lawn.leaves(at, s, c, maxf(u, 0.001), _blow_dir(c), _press(c, t)))
	else:
		var cover := t - float(_cover_at[c])
		var sc := Motion.pop_in_scale(cover) if cover >= 0.0 and cover < Motion.POP_IN else Vector2.ONE
		var pressed := _press(c, t) * _finger(c, t)
		var walk := _snuffle(c, t)
		if walk > 0.0:
			# A sleepwalker under it: the pile heaves twice and settles.
			var heave := absf(sin(walk * PI * 2.0)) * (1.0 - walk)
			pressed *= Vector2(1.0 - 0.08 * heave, 1.0 + 0.16 * heave)
			rustle = maxf(rustle, walk)
		# The pile sits on its foot, so a press squashes it down, not in.
		var foot := at + Vector2(0.0, s * 0.3 * (1.0 - pressed.y))
		var k := sc * pressed
		if rustle > 0.0:
			rm.put(_id(Look.BACK, c), [], Transform2D(0.0, k, 0.0, foot))
			_put_leaves(rm, Lawn.leaves(foot, s, c, 0.0, Vector2.UP, k, 1.0, rustle).slice(Lawn.BACK))
		elif k == Lawn.PRESSED:
			rm.put(_id(Look.PRESSED, c), [], Transform2D(0.0, foot))
		else:
			rm.put(_id(Look.PILE, c), [], Transform2D(0.0, k, 0.0, foot))
		if _paw_on(c):
			rm.put(_id(Look.PAWS, 0), [], Transform2D(0.0, at))
	_put_flag(rm, c, at, t, rustle)

## Leaves as Lawn.leaves hands them out, each its kind's look painted its
## colour (and its midrib's) under its place, turn, length and flip.
func _put_leaves(rm: RunMesh, leaves: Array) -> void:
	var made := _cell * LEAF_LOOK
	for l: Array in leaves:
		var length: float = l[1]
		var colour: Color = l[3]
		var vein := Color(colour, 0.0)
		if length >= 14.0 and colour.a >= 0.05:
			vein = Color(colour.lightened(0.3), 0.55 * colour.a)
		var xf := Transform2D(float(l[2]), Vector2(length, length * maxf(float(l[5]), 0.08)) / made, 0.0, l[0])
		rm.put(_id(Look.LEAF, int(l[4])), [colour, vein], xf)

## A flag drops in from above and thunks into its pile; the breeze flutters
## its pennant (drawn live while it does); a lifted one shrinks out.
func _put_flag(rm: RunMesh, c: int, at: Vector2, t: float, rustle: float) -> void:
	var s := _cell
	var foot := at + Vector2(0.0, s * 0.02)
	if _flag_up(c, t):
		var since := t - float(_flag_at[c])
		var fall := Motion.drop_in_lift(since, s * FLAG_FALL, FLAG_DROP)
		var a := Motion.appear_level(since, Motion.DROP_FADE)
		var wave := sin(rustle * TAU * 1.5) * (1.0 - rustle)
		var landed := since - FLAG_DROP
		if landed > 0.0 and landed < FLAG_FLUTTER and not Motion.reduce:
			# The pennant still shaking from the thunk.
			wave += sin(landed * 30.0) * 0.6 * (1.0 - landed / FLAG_FLUTTER)
		var wrong: bool = _state.wrong[c] == 1
		if wave == 0.0:
			rm.put(_id(Look.FLAG, 0), Lawn.flag_inks(wrong, a), Transform2D(0.0, foot - Vector2(0.0, fall)))
		elif a > 0.0:
			var b := Face.Builder.new()
			Lawn.flag(b, foot - Vector2(0.0, fall), s * FLAG_R, wrong, Vector2.ONE, a, wave)
			rm.put_builder(b)
		if _state.pin[c] == 1:
			rm.put(_id(Look.PIN, 0), [], Transform2D(0.0, at))
		return
	var out := t - float(_unflag_at[c])
	if out >= 0.0 and out < FLAG_OUT and not Motion.reduce:
		var k := 1.0 - out / FLAG_OUT
		if k > 0.0:
			rm.put(_id(Look.FLAG, 0), Lawn.flag_inks(), Transform2D(0.0, Vector2(k, k), 0.0, foot))

## A walk's snuffle through cell `c` at `t`: 0 still, 0..1 while it heaves.
func _snuffle(c: int, t: float) -> float:
	if Motion.reduce:
		return 0.0
	var u := (t - float(_walk_at[c])) / WALK_TIME
	return u if u > 0.0 and u < 1.0 else 0.0

## A finger's weight on cell `c`: the pile sinks while it is held and
## springs back once let go.
func _finger(c: int, t: float) -> Vector2:
	if Motion.reduce:
		return Vector2.ONE
	if c == _press_cell and _press_finger != -2 and not _long_fired:
		var k := clampf((t - _press_at) / PRESS_IN, 0.0, 1.0)
		return Vector2.ONE.lerp(PRESS_DIP, k)
	var e := t - float(_release_at[c])
	if e >= 0.0 and e < RELEASE_TIME:
		var k := Motion.bump_scale(e, 0.1, RELEASE_TIME)
		return Vector2(2.0 - k, k)
	return Vector2.ONE

## Little paw prints at a pile's foot: the two cells of the last walk wear
## the same ones, so they say where it walked and never which way.
func _draw_paws(b: Face.Builder, at: Vector2, s: float) -> void:
	var ink := Color(Pal.MOON_DEEP, 0.85)
	for k in 2:
		var p := at + Vector2(-0.16 + 0.3 * float(k), 0.3 - 0.14 * float(k)) * s
		b.disc(p, s * PAW * 1.25, Color(Pal.PAPER, 0.75))
		b.ellipse(p, s * PAW * 0.62, s * PAW * 0.5, ink)
		for toe in 3:
			var a := -PI * 0.5 + (float(toe) - 1.0) * 0.6
			b.disc(p + Vector2(cos(a), sin(a)) * s * PAW * 0.85, s * PAW * 0.24, ink)

## The breeze through cell `c` at `t`: 0 still, 0..1 while it passes.
func _rustle(c: int, t: float) -> float:
	var u := (t - float(_rustle_at[c])) / RUSTLE_TIME
	return u if u > 0.0 and u < 1.0 else 0.0

## How far a flag presses its pile down: none without one, PRESSED once it
## has landed with a squash, easing back as it is pulled out.
func _press(c: int, t: float) -> Vector2:
	if Motion.reduce:
		return Lawn.PRESSED if _flag_up(c, t) else Vector2.ONE
	if _flag_up(c, t):
		var since := t - float(_flag_at[c]) - FLAG_DROP
		if since < 0.0:
			return Vector2.ONE
		var squash := 1.0 - (Motion.bump_scale(since, 0.14) - 1.0)
		return Lawn.PRESSED * Vector2(2.0 - squash, squash)
	var out := t - float(_unflag_at[c])
	if out >= 0.0 and out < FLAG_OUT:
		return Lawn.PRESSED.lerp(Vector2.ONE, out / FLAG_OUT)
	return Vector2.ONE

## Whether cell `c` shows a flag standing in it at `t`.
func _flag_up(c: int, t: float) -> bool:
	return _state.flag[c] == 1 and _state.woke[c] == 0 and _state.open[c] == 0 \
		and not (_solved_at >= 0.0 and t >= float(_blow_at[c]))

## The rake's stroke: the rake drawn across the cell, pulled toward the
## player and turning as it goes, fading in and out.
func _draw_rakes(b: Face.Builder, t: float) -> void:
	var keep: Array = []
	for r: Dictionary in _rakes:
		var u := (t - float(r.at)) / RAKE_TIME
		if u >= 1.0:
			continue
		keep.append(r)
		if u < 0.0:
			continue
		var e := 1.0 - (1.0 - u) * (1.0 - u)
		var at: Vector2 = _centre(int(r.cell)) + Vector2(lerpf(0.28, -0.22, e), lerpf(-0.18, 0.02, e)) * _cell
		var a := minf(1.0, u / 0.15) * minf(1.0, (1.0 - u) / 0.3)
		Lawn.rake(b, at, _cell * 0.8, lerpf(-0.15, -0.75, e), a)
	_rakes = keep

## The gust's wind: curved streaks running out of the raked cell, a head and
## a fading tail.
func _draw_wind(b: Face.Builder, t: float) -> void:
	var keep: Array = []
	for w: Dictionary in _streaks:
		var u := (t - float(w.at)) / float(w.time)
		if u >= 1.0:
			continue
		keep.append(w)
		if u <= 0.0:
			continue
		var dir: Vector2 = w.dir
		var side := Vector2(-dir.y, dir.x) * float(w.bend)
		var reach: float = float(w.reach) * _cell
		var head := minf(1.0, u * 1.25)
		var tail := maxf(0.0, u * 1.25 - 0.45)
		# A soft curving streak that ends in a little curl, cut where it
		# would leave the lawn.
		var field := Rect2(_grid, Vector2(_state.cols(), _state.rows()) * _cell)
		var pts := PackedVector2Array()
		for k in 12:
			var q := lerpf(tail, head, float(k) / 11.0)
			var p: Vector2 = _centre(int(w.from)) + dir * (_cell * 0.35 + reach * q) + side * sin(q * PI * 1.2) * reach * 0.3
			if q > 0.8:
				var curl := (q - 0.8) / 0.2 * PI * 1.4
				p += (dir * sin(curl) + side.normalized() * (1.0 - cos(curl))) * _cell * 0.18
			if not field.has_point(p):
				break
			pts.append(p)
		if pts.size() > 1 and head > tail:
			b.stroke(pts, _cell * 0.065, Color(Pal.PAPER, 0.8 * (1.0 - u)), false, true)
	_streaks = keep

## The win's swirl: leaves spiralling up out of the last cell raked and
## across the lawn, tumbling and fading: a leaf look each.
func _put_swirl(rm: RunMesh, t: float) -> void:
	var u0 := (t - _swirl_at) / SWIRL_TIME
	if u0 <= 0.0 or u0 >= 1.0:
		return
	var leaves: Array = []
	var from := _centre(_last)
	var span := Vector2(_state.cols(), _state.rows()) * _cell
	for i in SWIRL_LEAVES:
		var d := float(i) / float(SWIRL_LEAVES) * 0.35
		var u := clampf((u0 - d) / (1.0 - d), 0.0, 1.0)
		if u <= 0.0:
			continue
		var hv := Lawn.h01(i, 404)
		var ang := hv * TAU + u * (3.0 + 2.0 * Lawn.h01(i, 405))
		var rad := u * maxf(span.x, span.y) * (0.35 + 0.35 * Lawn.h01(i, 406))
		var at := from + Vector2(cos(ang), sin(ang) * 0.7) * rad + Vector2(0.0, -u * _cell * 1.5)
		var colour: Color = Pal.AUTUMN_LEAVES[i % Pal.AUTUMN_LEAVES.size()]
		var a := minf(1.0, u / 0.1) * (1.0 - u)
		leaves.append([at, _cell * 0.3, ang * 1.7, Color(colour, a), i % 3, 0.3 + 0.7 * absf(cos(u * 8.0 + float(i)))])
	_put_leaves(rm, leaves)

func _blow_dir(c: int) -> Vector2:
	var from: int = _blow_from[c]
	if from < 0 or from == c:
		return Vector2(Lawn.h01(c, 5) - 0.5, -0.6).normalized()
	var d := _centre(c) - _centre(from)
	return d.normalized() if d.length() > 0.001 else Vector2.UP

## The numerals, over the meshes and inside the entrance pop: one
## draw_set_transform a cell, so each pops in just after its leaves go. A
## nought draws nothing.
func _draw_numbers(t: float, xf: Transform2D, seen: float) -> void:
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(_cell * NUM_SIZE))
	if px <= 0:
		return
	var rise := font.get_ascent(px) * 0.5
	for c in _state.size():
		if _state.open[c] == 0 or c >= _num_view.size():
			continue
		var v: int = _num_view[c]
		if v <= 0:
			continue
		var since := t - float(_blow_at[c]) - NUM_LAG
		var changed := t - float(_num_at[c])
		if changed < Motion.POP_IN and not Motion.reduce:
			# A walk changed it: out while the piles snuffle, then back in.
			since = changed if changed >= 0.0 else -1.0
		if since < 0.0 and not Motion.reduce:
			continue
		var sc: Vector2 = Motion.pop_in_scale(since) if not Motion.reduce else Vector2.ONE
		var at := _centre(c) + Vector2(Motion.shiver_offset(t - float(_bump_at[c]), _cell * 0.03), _cell * 0.02)
		draw_set_transform_matrix(xf * Transform2D(0.0, sc, 0.0, at))
		var text := str(v)
		var wide: float = _num_w.get(v * 1000 + px, -1.0)
		if wide < 0.0:
			wide = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
			_num_w[v * 1000 + px] = wide
		draw_string(font, Vector2(-wide * 0.5, rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px,
			Color(Pal.NUM_INK[mini(v, Pal.NUM_INK.size() - 1)], seen))
	draw_set_transform(Vector2.ZERO)

## The tally strip: a sleeping hedgehog and how many are still asleep and
## unflagged -- the global count the proof uses, given free. BAD when there
## are more flags than hedgehogs.
func _tally_line() -> String:
	var left: int = _state.flags_left()
	if _solved_at >= 0.0:
		return tr("HH_TALLY_DONE")
	if left < 0:
		return tr("HH_TALLY_OVER_ONE") if left == -1 else tr("HH_TALLY_OVER_N") % -left
	return tr("HH_TALLY_ONE") if left == 1 else tr("HH_TALLY_N") % left

func _draw_tally(t: float, seen: float, shown: Array) -> void:
	var font: Font = CozyTheme.display(700)
	var line := _tally_line()
	var wide := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TALLY_SIZE).x
	var moon := _state.walkers() and _solved_at < 0.0
	var bell_w := 2.0 * MOON_R + 12.0 + PIP_GAP * float(State.Gen.WALK_EVERY)
	var run := TALLY_GLYPH + TALLY_GAP + wide + (TALLY_GAP * 1.6 + bell_w if moon else 0.0)
	var start := size.x * 0.5 - run * 0.5
	if moon:
		_draw_bell(Vector2(start + TALLY_GLYPH + TALLY_GAP + wide + TALLY_GAP * 1.6 + MOON_R, _tally_y), t, seen, shown)
	var ink: Color = Pal.BAD if _state.flags_left() < 0 and _solved_at < 0.0 else Pal.TEXT
	draw_string(font, Vector2(start + TALLY_GLYPH + TALLY_GAP, _tally_y + font.get_ascent(TALLY_SIZE) * 0.4),
		line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TALLY_SIZE, Color(ink, seen))
	if _tally_face != null:
		var want := Vector2(start, _tally_y - TALLY_GLYPH * 0.5)
		if _tally_face.position != want:
			_tally_face.position = want
		_tally_face.modulate.a = seen

## Sleepwalkers' bell: a crescent moon and a dot for each rake since it
## last rang, lit one by one; on the ring the moon swings and glows and the
## dots go out. One mesh, rebuilt only when what it shows changes.
func _draw_bell(at: Vector2, t: float, seen: float, shown: Array) -> void:
	var e := t - _bell_at
	var ringing := e >= 0.0 and e < BELL_TIME and not Motion.reduce
	var swing := sin(e * 22.0) * 0.35 * (1.0 - e / BELL_TIME) if ringing else 0.0
	var glow := (1.0 - e / BELL_TIME) if ringing else 0.0
	var key := [_bell_view, snappedf(swing, 0.02), snappedf(glow, 0.05)]
	if _bell_mesh == null or key != _bell_key:
		var b := Face.Builder.new()
		if glow > 0.0:
			b.disc(Vector2.ZERO, MOON_R * (1.5 + 0.4 * glow), Color(Pal.SUN, 0.35 * glow))
		var tip := Vector2.from_angle(swing - PI * 0.5)
		var bite := Face.Builder.ring(tip.rotated(0.9) * MOON_R * 0.55, MOON_R * 0.86, MOON_R * 0.86)
		for rim in [[2.0, Pal.LINE], [0.0, Pal.SUN]]:
			var disc := Face.Builder.ring(Vector2.ZERO, MOON_R + float(rim[0]), MOON_R + float(rim[0]))
			for part in Geometry2D.clip_polygons(disc, bite):
				b.polygon(part, rim[1])
		for k in State.Gen.WALK_EVERY:
			var p := Vector2(MOON_R + 12.0 + PIP_GAP * (float(k) + 0.5), 0.0)
			var lit := k < _bell_view
			b.disc(p, PIP_R + 1.5, Pal.LINE)
			b.disc(p, PIP_R, Pal.SUN if lit else Pal.SURFACE)
		_bell_mesh = b.mesh()
		_bell_key = key
	draw_mesh(_bell_mesh, null, Transform2D(0.0, at), Color(1.0, 1.0, 1.0, seen))
	shown.append(_bell_mesh)
	if ringing:
		queue_redraw()

## The tally sleeper's z: a Label under its face that drifts up and fades
## every Z_EVERY seconds on a tween of its own, so it never redraws the board.
func _start_z() -> void:
	if _z_label == null:
		_z_label = Label.new()
		_z_label.text = "z"
		_z_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_z_label.add_theme_font_override("font", CozyTheme.display(700))
		_z_label.add_theme_font_size_override("font_size", 24)
		_z_label.add_theme_color_override("font_color", Color(Pal.TEXT, 0.55))
		_tally_face.add_child(_z_label)
	Motion.stop(_z_tw)
	_z_label.visible = not Motion.reduce
	if Motion.reduce:
		return
	var from := Vector2(TALLY_GLYPH * 0.8, -TALLY_GLYPH * 0.1)
	_z_label.position = from
	_z_label.modulate.a = 0.0
	_z_tw = _z_label.create_tween().set_loops()
	_z_tw.tween_interval(Z_EVERY - Z_TIME)
	_z_tw.tween_callback(func():
		_z_label.position = from
		_z_label.scale = Vector2.ONE * 0.8)
	_z_tw.tween_property(_z_label, "modulate:a", 1.0, Z_TIME * 0.2)
	_z_tw.parallel().tween_property(_z_label, "position", from + Vector2(16.0, -30.0), Z_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_z_tw.parallel().tween_property(_z_label, "scale", Vector2.ONE * 1.15, Z_TIME)
	_z_tw.parallel().tween_property(_z_label, "modulate:a", 0.0, Z_TIME * 0.3).set_delay(Z_TIME * 0.7)

func _stop_z() -> void:
	Motion.stop(_z_tw)
	if _z_label != null:
		_z_label.visible = false

## The toast over the foot of the card, fading in and out over
## Motion.DROP_FADE -- Knight's `_draw_toast`, in the card's own pixels and
## wrapped to the card's width.
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
	var line := tr(_toast)
	if _toast_arg != "":
		line = line % _toast_arg
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
	var mid := Vector2(size.x * 0.5, size.y - TOAST_MARGIN - h * 0.5)
	draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var top := mid.y - h * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - w * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		draw_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		draw_multiline_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_CENTER, w - TOAST_PAD,
			TOAST_FONT, lines, Color(Pal.PAPER, alpha))

func _ring_at(c: int) -> void:
	if Motion.reduce:
		return
	_rings.append({"cell": c, "at": _now()})
	_busy_for(Motion.RING_TIME)

# --- input ---

## A touch resolves on release; a press held LONG_PRESS fires the other
## chip's action at once and the release is then ignored. One finger holds
## the press: another landing meanwhile is ignored, press and release.
func _gui_input(event: InputEvent) -> void:
	if _done or out_of_hearts:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		var finger: int = event.index if event is InputEventScreenTouch else -1
		var c := _cell_at(event.position)
		if event.pressed:
			if _press_finger != -2 and finger != _press_finger:
				return
			_press_finger = finger
			_press_cell = c
			_long_fired = false
			_press_id += 1
			_press_at = _now()
			var id := _press_id
			if c >= 0 and _state.open[c] == 0:
				_touch(c, _press_at + LONG_PRESS + 0.3)
			if c >= 0:
				_later(LONG_PRESS, func():
					if id == _press_id and _press_cell == c and not _long_fired:
						_long_fired = true
						_act(c, State.FLAG if brush == State.RAKE else State.RAKE))
			return
		if finger != _press_finger:
			return
		var was := _press_cell
		_press_cell = -1
		_press_finger = -2
		_press_id += 1
		if was >= 0 and not _long_fired:
			_release_at[was] = _now()
			_touch(was, _now() + RELEASE_TIME)
		if _long_fired or c < 0 or c != was:
			return
		if event is InputEventScreenTouch and event.canceled:
			return
		_act(c, brush)

## The tray armed a chip.
func set_brush(v: int) -> void:
	brush = v

# --- the sprout's line and the toast ---

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

## An explanation of what just happened: the sprout's line (which no screen
## shows since the tip card left every board) and the toast, which one does.
func _tell(key: String, mood: int, arg := "") -> void:
	_say(tr(key) % arg if arg != "" else tr(key), mood)
	_toast = key
	_toast_arg = arg
	_toast_at = _now()
	queue_redraw()

func _cycle_tip() -> void:
	if is_done() or _state.can_undo():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return _state.can_undo() and not is_done() and not out_of_hearts and not busy() \
		and not _state.walkers()

## Takes back the last gesture: its cells' piles pop back in, back to front;
## its flag pops in or out. A woken hedgehog stays awake.
func undo() -> bool:
	if not can_undo():
		return false
	_break_streak()
	_clear_gags()
	var u: Dictionary = _state.undo()
	if u.is_empty():
		return false
	var t := _now()
	var raked: PackedInt32Array = u.raked
	for i in raked.size():
		var c := raked[i]
		var at := t + (0.0 if Motion.reduce else float(raked.size() - 1 - i) * UNDO_STEP)
		_cover_at[c] = at
		_blow_at[c] = -100.0
		_touch(c, at + Motion.POP_IN)
	for f: Array in u.flags:
		var c: int = f[0]
		if int(f[1]) == 1:
			_flag_at[c] = t
			_touch(c, t + FLAG_DROP + Motion.BUMP_TIME)
		else:
			_unflag_at[c] = t
			_touch(c, t + FLAG_OUT)
	fx.cue("undo")
	_tell("HH_UNDONE", Face.Expr.HAPPY)
	moved.emit()
	_refresh()
	return true

func hints_left() -> int:
	if _state.walkers():
		return 0
	return maxi(0, State.hints_for(_state.difficulty) + hints_extra - hints_used)

## The next thing logic can prove from what the player can see: a bare cell
## raked, else a hedgehog flagged and pinned.
func hint() -> bool:
	if is_done() or out_of_hearts or hints_left() <= 0 or busy():
		return false
	_break_streak()
	var step: Dictionary = _state.hint_step()
	if step.is_empty():
		return false
	hints_used += 1
	var c: int = step.cell
	if step.kind == "rake" and _state.flag[c] == 1:
		_unflag_at[c] = _now()
	var r: Dictionary = _state.apply_hint(step)
	_ring_at(c)
	fx.cue("hint")
	_hinting = true
	if String(r.kind) == "pinned":
		_flag_at[c] = _now()
		_touch(c, _now() + FLAG_DROP + Motion.BUMP_TIME)
		_tell("HH_HINT_FLAG", Face.Expr.HAPPY)
		_after_move()
	else:
		_show_rake(r, c)
		# A rake that finished the lawn has the win's line; leave it.
		if not is_done():
			_tell("HH_HINT_RAKE", Face.Expr.HAPPY)
	_hinting = false
	return true

## Every wrong flag's pennant turns rose and shivers, and holds until the
## next move. Counts a check.
func check() -> int:
	if is_done() or out_of_hearts or _state.walkers():
		return 0
	checks += 1
	var wrong: PackedInt32Array = _state.check()
	var t := _now()
	for c in wrong:
		_bump_at[c] = t
		_touch(c, t + Motion.SHIVER_TIME)
	if wrong.is_empty():
		_tell("HH_CHECK_OK", Face.Expr.JOY)
		fx.cue("check_ok")
	else:
		_tell("HH_CHECK_ONE" if wrong.size() == 1 else "HH_CHECK_N", Face.Expr.STRAIN,
			"" if wrong.size() == 1 else str(wrong.size()))
		fx.cue("check")
	_refresh()
	return wrong.size()

## Back to the opening, the piles popping back in out from it; woken
## hedgehogs and a hint's flags stay.
func can_reset() -> bool:
	return not (is_done() or out_of_hearts or busy())

## Whether a wake's heart or a walk is still playing out: input, Undo, Hint
## and Reset wait.
func busy() -> bool:
	return _now() < _busy_until

func reset_board() -> void:
	if not can_reset():
		return
	_break_streak()
	_clear_gags()
	var night := _state.walkers()
	# Timers waiting on faces or a walk belong to the lawn before the reset.
	_turn += 1
	var before: PackedByteArray = _state.flag.duplicate()
	var covered: PackedInt32Array = _state.reset_board()
	if night:
		_night_back()
	var t := _now()
	var start: int = _state.g.start
	var cols: int = _state.cols()
	for c in covered:
		var d := absi(c % cols - start % cols) + absi(c / cols - start / cols)
		var at := t + (0.0 if Motion.reduce else Motion.stagger(d, Motion.RESET_STAGGER))
		_cover_at[c] = at
		_blow_at[c] = -100.0
		_touch(c, at + Motion.POP_IN)
	for c in _state.size():
		if before[c] == 1 and _state.flag[c] == 0:
			_unflag_at[c] = t
			_touch(c, t + FLAG_OUT)
	_last = start
	moves = 0
	_running = true
	_tell("HH_NIGHT_RESET" if night else "HH_RESET", Face.Expr.HAPPY)
	fx.cue("reset")
	moved.emit()
	_refresh()

## After State.restart: nobody woken, every number as dealt, no paw prints,
## the moon's dots out.
func _night_back() -> void:
	var t := _now()
	for c: int in _faces:
		_cover_at[c] = t
		_blow_at[c] = -100.0
		_touch(c, t + Motion.POP_IN)
	_clear_faces()
	_sync_numbers()
	_num_at.fill(-100.0)
	_walk_at.fill(-100.0)
	_paws = Vector2i(-1, -1)
	_bell_view = 0
	_bell_at = AGO
	_bands = []

func is_solved() -> bool:
	return _state.is_solved()

## The day's shape, never its answer, and how many woke.
func share_glyphs() -> String:
	var tail := tr("HH_SHARE_NONE") if _state.woken == 0 else (tr("HH_SHARE_ONE") if _state.woken == 1
		else tr("HH_SHARE_N") % _state.woken)
	if _state.walkers() and is_solved():
		tail += " 🌙 " + tr("HH_WALK_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless:
		tail += " 🏅 " + tr("BN_FLAWLESS")
	return _state.share_glyphs() + "\n" + tail

# --- the win ---

func flat_win() -> Dictionary:
	var faces: Array = []
	for i in 3:
		faces.append(HedgehogFace.new())
	var sub := tr("HH_WIN_NONE") if _state.woken == 0 else (tr("HH_WIN_WOKE_ONE") if _state.woken == 1
		else tr("HH_WIN_WOKE_N") % _state.woken)
	return {"faces": faces, "subtitle": sub}

## The wave's length: the farthest sleeper from the last rake.
func _wave_span() -> float:
	var cols: int = _state.cols()
	var far := 0
	for c in _state.size():
		if _state.is_hog(c) and _state.woke[c] == 0:
			far = maxi(far, maxi(absi(c % cols - _last % cols), absi(c / cols - _last / cols)))
	return Motion.stagger(far, Motion.WAVE_STEP * 2.0)

## The win screen waits for the sleepers' wave and the party's moment.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	var wave := WIN_LEAD + _wave_span() + WIN_WAIT
	var party := maxf(0.0, _party_at - _now()) + PARTY_TIME if _party_at < INF else wave
	return maxf(wave, party)

## Every sleeper's leaves blow off in a wave out of the last cell raked, and
## each hedgehog pops up awake and hops; the woken ones cheer up too.
func _on_solved() -> void:
	var t := _now()
	_solved_at = t
	_tip_timer.stop()
	_stop_z()
	_press_cell = -1
	# Flawless: no hint and not one hedgehog woken.
	_flawless = hints_used == 0 and _state.woken == 0
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = t
	_streak_gen += 1
	_clear_gags()
	_heart_layer.queue_redraw()
	var cols: int = _state.cols()
	for c in _state.size():
		if not _state.is_hog(c):
			continue
		var d := maxi(absi(c % cols - _last % cols), absi(c / cols - _last / cols))
		var delay := 0.0 if Motion.reduce else WIN_LEAD + Motion.stagger(d, Motion.WAVE_STEP * 2.0)
		if _state.woke[c] == 1:
			var woken_face: Control = _faces.get(c)
			if woken_face != null:
				woken_face.expression = Face.Expr.JOY
				Motion.hop(woken_face, -_cell * 0.16, 0.4, delay + 0.3)
			continue
		_blow_at[c] = t + delay
		_blow_from[c] = _last
		_touch(c, t + delay + LEAF_TIME)
		_wake_up(_face_at(c, Face.Expr.SLEEPY), delay)
	if not Motion.reduce:
		_swirl_at = t + WIN_LEAD
		_busy_for(WIN_LEAD + SWIRL_TIME)
		_later(WIN_LEAD, func():
			fx.sparkle(_centre(_last), Pal.SUN)
			fx.cue("solved"))
	else:
		fx.cue("solved")
	_say(tr("HH_WIN_NONE") if _state.woken == 0 else tr("HH_WIN_WOKE_ONE") if _state.woken == 1
		else tr("HH_WIN_WOKE_N") % _state.woken, Face.Expr.JOY)
	_party(0.0 if Motion.reduce else WIN_LEAD + _wave_span() + PARTY_AT)
	_refresh()

## A sleeper the win uncovers: it pops up still asleep, stretches tall with
## its eyes screwed shut and mouth open (the yawn, which is JOY's face), and
## hops awake.
func _wake_up(face: Control, delay: float) -> void:
	if Motion.reduce:
		face.expression = Face.Expr.JOY
		return
	face.scale = Vector2.ZERO
	Motion.pop_in(face, Motion.POP_IN, delay)
	var tw := face.create_tween()
	tw.tween_interval(delay + Motion.POP_IN + 0.12)
	tw.tween_callback(func(): face.expression = Face.Expr.JOY)
	tw.tween_property(face, "scale", Vector2(0.88, 1.16), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(face, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Motion.hop(face, -_cell * 0.14, 0.4, delay + Motion.POP_IN + 0.5)

## The hedgehogs a rake woke, so a reopened daily can say how many and wash
## the same cells rose. Plain ints, because it goes through a ConfigFile.
func completion_record() -> Dictionary:
	var out: Array = []
	var hogs: Array = []
	for c in _state.size():
		if _state.woke[c] == 1:
			out.append(c)
		if _state.is_hog(c):
			hogs.append(c)
	# `woken` is the day's tally: a Try again or an Insane Reset puts the
	# woken back to sleep, but they still count.
	var rec := {"woke": out, "hearts": hearts, "flawless": _flawless, "woken": _state.woken}
	# Sleepwalkers ends with the hedgehogs where they walked to.
	if _state.walkers():
		rec["hogs"] = hogs
	return rec

## A reopened daily that was already solved: every bare cell raked and every
## hedgehog awake on it, the ones a rake woke back on their rose cells from
## `completed_record` (a save from before completion_record() existed has
## none, and reads as a day nobody woke). Never check_solved(): `solved`
## must not fire twice.
func restore_completed_board() -> void:
	_turn += 1
	_close_card()
	_deal_hearts()
	_reset_rewards()
	hearts = clampi(int(completed_record.get("hearts", max_hearts)), 0, max_hearts)
	_flawless = bool(completed_record.get("flawless", false))
	_restore_hogs()
	_sync_numbers()
	_paws = Vector2i(-1, -1)
	for c in _state.size():
		if not _state.is_hog(c):
			_state.open[c] = 1
	_state.woke.fill(0)
	_state.woken = 0
	for w in _recorded_woke():
		_state.woke[w] = 1
		_state.woken += 1
	_state.woken = maxi(_state.woken, int(completed_record.get("woken", 0)))
	_state.history = []
	var t := _now()
	# Never below zero: _solved_at >= 0 is what "solved" reads as, and a day
	# reopened within 100 s of launch would read unsolved.
	_solved_at = maxf(0.0, t - 100.0)
	_opened = t - 100.0
	_blow_at.fill(-100.0)
	_moving = {}
	_stop_z()
	for c in _state.size():
		if _state.is_hog(c):
			_face_at(c, Face.Expr.JOY)
	_tip_timer.stop()
	_say(tr("HH_WIN_NONE") if _state.woken == 0 else tr("HH_TIP_WOKE"), Face.Expr.JOY)
	_cat_at = t - 100.0
	_place_cat(t)
	if _flawless or _state.walkers():
		_stamp_at = t - 100.0
	_heart_layer.queue_redraw()
	_life_layer.queue_redraw()
	_bands = []
	_refresh()

## Sleepwalkers' record keeps where the hedgehogs walked to: the lawn is
## put back that way when the record holds k distinct cells, as dealt
## otherwise.
func _restore_hogs() -> void:
	var raw = completed_record.get("hogs", [])
	if not _state.walkers() or not raw is Array or raw.size() != int(_state.g.k):
		return
	var hog := PackedByteArray()
	hog.resize(_state.size())
	for v in raw:
		var c := int(v)
		if c < 0 or c >= _state.size() or hog[c] == 1:
			return
		hog[c] = 1
	_state.g.hog = hog
	State.Gen.count(_state.g)

## The record's woken cells if every one is a hedgehog on today's lawn, each
## once, and none otherwise.
func _recorded_woke() -> PackedInt32Array:
	var out := PackedInt32Array()
	var raw = completed_record.get("woke", [])
	if not raw is Array:
		return out
	for v in raw:
		var c := int(v)
		if c < 0 or c >= _state.size() or not _state.is_hog(c) or out.has(c):
			return PackedInt32Array()
		out.append(c)
	return out

# --- hearts ---

func _hearts_y() -> float:
	return _grid.y - TALLY - HEART_ROW * 0.5 + 4.0

## The middle of the hearts' pill (`pill` its size): over the tally. The
## tutorial's lawn hangs it beside the bed.
func _hearts_at(_pill: Vector2) -> Vector2:
	return Vector2(size.x * 0.5, _hearts_y())

## A heart splits off the pill at `at`; the last one sets out_of_hearts.
func _lose_heart(at: float) -> void:
	_lost_ever = true
	hearts = maxi(0, hearts - 1)
	_split_index = hearts
	_split_at = at
	if hearts <= 0:
		out_of_hearts = true
	_heart_layer.queue_redraw()

## A line about a lost heart, with how many are left after it.
func _tell_hearts(key: String) -> void:
	_tell(key, Face.Expr.WORRIED)
	if hearts > 0:
		_say(tr(key) + " " + (tr("SB_HEARTS_ONE") if hearts == 1 else tr("SB_HEARTS_N") % hearts), Face.Expr.WORRIED)

## The hearts' pill over the tally: Knight's, heart for heart.
func _draw_hearts() -> void:
	if max_hearts <= 0 or _cell <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var mid := _hearts_at(pill)
	var y := mid.y
	var left := mid.x - pill.x * 0.5
	var corner := Vector2(left, y - pill.y * 0.5)
	var rim := Vector2.ONE * HEART_PILL_RIM
	var enter := 1.0 if Motion.reduce else Motion.pop_in_scale(now - _opened - Motion.ENTER_DELAY).x
	if enter <= 0.0:
		return
	b.polygon(Face.Builder.round_rect(corner - rim, pill + 2.0 * rim, pill.y * 0.5 + HEART_PILL_RIM), Pal.LINE)
	b.polygon(Face.Builder.round_rect(corner, pill, pill.y * 0.5), Pal.SURFACE)
	var x0 := left + HEART_PILL_PAD.x + HEART_R
	for i in max_hearts:
		var at := Vector2(x0 + step * i, y)
		if i < hearts or (i == _split_index and now < _split_at):
			var r := HEART_R
			if i == _back_index and not Motion.reduce:
				r *= Motion.pop_in_scale(now - _back_at, HEART_BACK_TIME).x
			if r > 0.5:
				b.polygon(_heart(at, r, -1), Pal.FLOWER)
				b.polygon(_heart(at, r, 1), Pal.FLOWER_DEEP)
				_heart_face(b, at, r)
			continue
		b.polygon(_heart(at, HEART_R, 0), Color(Pal.FLOWER, 0.22))
		var u := (now - _split_at) / SPLIT_TIME
		if i == _split_index and u < 1.0 and not Motion.reduce:
			var fade := 1.0 - u * u
			for side in [-1, 1]:
				var turn: float = side * SPLIT_TURN * u
				var shift := Vector2(side * SPLIT_SPREAD * u, SPLIT_FALL * u * u)
				var pts := _heart(Vector2.ZERO, HEART_R, side)
				for k in pts.size():
					pts[k] = at + shift + pts[k].rotated(turn)
				b.polygon(pts, Color(Pal.FLOWER if side < 0 else Pal.FLOWER_DEEP, fade))
	_hearts_shown = b.mesh()
	_heart_layer.draw_set_transform(mid * (1.0 - enter), 0.0, Vector2.ONE * enter)
	_heart_layer.draw_mesh(_hearts_shown, null)
	_heart_layer.draw_set_transform(Vector2.ZERO)

static func _heart_face(b, at: Vector2, s: float) -> void:
	b.ellipse(at + Vector2(-0.5, -0.5) * s, 0.16 * s, 0.1 * s, Color(1.0, 1.0, 1.0, 0.45))
	for sx in [-1.0, 1.0]:
		b.disc(at + Vector2(sx * 0.28, -0.12) * s, 0.09 * s, Pal.OUTLINE)
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, 0.02) * s, 0.16 * s, PI * 0.2, PI * 0.8), 0.07 * s, Pal.OUTLINE)
	b.ellipse(at + Vector2(0.25, -0.76) * s, 0.24 * s, 0.11 * s, Pal.LEAF)

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
	var zig := [Vector2(0.0, 13.0), Vector2(1.5, 8.0), Vector2(-1.5, 3.0), Vector2(1.0, -2.0)]
	if side < 0:
		zig.reverse()
	for z: Vector2 in zig:
		pts.append(at + (z + off) * k)
	return pts

## The last heart is gone: dusk falls on the lawn, every woken hedgehog
## dozes off again, and the out-of-hearts card comes up.
func _run_out() -> void:
	if _asleep or not out_of_hearts or is_done():
		return
	_asleep = true
	_press_cell = -1
	_press_finger = -2
	_break_streak()
	_clear_gags()
	_tip_timer.stop()
	for face in _faces.values():
		face.expression = Face.Expr.SLEEPY
	fx.cue("out_of_hearts")
	_say(tr("HH_OUT"), Face.Expr.SLEEPY)
	_dusk_toward(DUSK)
	_refresh()
	_later(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

func _dusk_toward(tint: Color) -> void:
	Motion.stop(_dusk_tw)
	if Motion.reduce:
		modulate = tint
		return
	_dusk_tw = create_tween()
	_dusk_tw.tween_property(self, "modulate", tint, DUSK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["HH_OUT_BODY", "HH_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same lawn as it was dealt, at its opening, every heart
## back, the clock and the moves from zero. Hints spent stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	_turn += 1
	var before: PackedByteArray = _state.flag.duplicate()
	var covered: PackedInt32Array = _state.restart()
	_deal_hearts()
	_night_back()
	var t := _now()
	var start: int = _state.g.start
	var cols: int = _state.cols()
	for c in covered:
		var d := absi(c % cols - start % cols) + absi(c / cols - start / cols)
		var at := t + (0.0 if Motion.reduce else Motion.stagger(d, Motion.RESET_STAGGER))
		_cover_at[c] = at
		_blow_at[c] = -100.0
		_touch(c, at + Motion.POP_IN)
	for c in _state.size():
		if before[c] == 1 and _state.flag[c] == 0:
			_unflag_at[c] = t
			_touch(c, t + FLAG_OUT)
	_last = start
	_break_streak()
	_clear_gags()
	_busy_until = t + (0.0 if Motion.reduce else Motion.POP_IN + 0.3)
	elapsed = 0.0
	moves = 0
	_running = true
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	_heart_layer.queue_redraw()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	_refresh()
	moved.emit()

## One more heart (the card's video): once a board. Morning comes back and
## the lawn plays on as it was.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	var now := _now()
	_heart_used = true
	hearts = 1
	_back_index = 0
	_back_at = now
	out_of_hearts = false
	_asleep = false
	_running = true
	for face in _faces.values():
		face.expression = Face.Expr.STRAIN
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	_heart_layer.queue_redraw()
	_refresh()
	_say(tr("HH_HEART_BACK"), Face.Expr.HAPPY)
	_tip_timer.start()
	moved.emit()

func _leave_board() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

# --- the rewards ---

func _reset_rewards() -> void:
	_streak = 0
	_streak_gen += 1
	_rakes_n = 0
	_gag_until = 0.0
	_gag_gen += 1
	_combo_n = 0
	_combo_at = -INF
	_combo_out_at = -INF
	_love = []
	_acorns = []
	_flies = []
	_party_at = INF
	_stamp_at = INF
	_seal_mesh = null
	_cat_at = INF
	_cat_curled = false
	if is_instance_valid(_cat):
		_cat.queue_free()
	_cat = null
	if _life_layer != null:
		_life_layer.queue_redraw()

## The day's own number, so a day always deals the same gags and wisdom.
func _day_hash() -> int:
	if _state.size() == 0:
		return 0
	return absi(hash([_state.cols(), _state.rows(), int(_state.g.start), int(_state.g.k)]))

## A safe rake that was not a hint's: the streak grows -- a note up the
## pentatonic from the second, the bubble over the pile from the third,
## confetti at 4, 7 and every 5 -- and the gag picked for it plays.
func _on_safe_rake(c: int, lands: float) -> void:
	_streak += 1
	var count := _streak
	var gen := _streak_gen
	var at := _centre(c)
	var wait := maxf(0.0, lands - _now())
	var bumped := _gust_bumped
	if count >= 2:
		var step: int = COMBO_STEPS[mini(count - 2, COMBO_STEPS.size() - 1)]
		_later(wait + 0.05, func() -> void:
			if gen == _streak_gen:
				fx.cue("combo", pow(2.0, step / 12.0), COMBO_DB))
	if count >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = count
		_combo_pos = at - Vector2(0.0, _cell * 0.45)
		_combo_at = lands
		_combo_out_at = -INF
	if _confetti_at(count) and not Motion.reduce:
		_later(wait, func() -> void:
			if gen == _streak_gen:
				fx.confetti(at, 22)
				fx.cue("confetti")
				if not bumped and not is_done():
					fx.buzz(Haptics.BUMP))
	_start_gag(c, _pick_gag(), lands)
	_life_layer.queue_redraw()

static func _confetti_at(count: int) -> bool:
	return count == 4 or count == 7 or (count >= 10 and count % 5 == 0)

## The gag for the next safe rake, off the day's hash: one in GAG_ODDS,
## never while one is still on.
func _pick_gag() -> int:
	_rakes_n += 1
	var t := _now()
	if Motion.reduce or t < _gag_until or force_gag == Gag.NONE:
		return Gag.NONE
	if force_gag >= 0:
		return force_gag
	var roll := posmod(_day_hash() + _rakes_n * GAG_STEP, GAG_SPAN)
	if roll >= GAG_SPAN / GAG_ODDS:
		return Gag.NONE
	return roll % 3

## The streak ends: a wake, an undo, a hint, a reset, the hearts running
## out. The bubble deflates.
func _break_streak() -> void:
	_streak = 0
	_streak_gen += 1
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
	else:
		_combo_n = 0
	if _life_layer != null:
		_life_layer.queue_redraw()

func _clear_gags() -> void:
	_love = []
	_acorns = []
	_flies = []
	_gag_until = 0.0
	_gag_gen += 1
	if _life_layer != null:
		_life_layer.queue_redraw()

## The gag for a rake of `c`: an acorn the rake turned up hops out and rolls
## away; love hearts float off the pile; or a butterfly that slept in the
## leaves flutters up and off.
func _start_gag(c: int, gag: int, lands: float) -> void:
	if gag == Gag.NONE:
		return
	var wait := maxf(0.0, lands - _now())
	var gg := _gag_gen
	var at := _centre(c)
	var side := -1.0 if at.x > size.x * 0.5 else 1.0
	var cue := ""
	match gag:
		Gag.ACORN:
			_acorns.append({"at": at, "t": lands + 0.1, "side": side})
			cue = "acorn"
			_gag_until = lands + ACORN_TIME
		Gag.LOVE:
			for k in LOVE_HEARTS:
				_love.append({"at": at + Vector2(float(k - 1) * 0.28, -0.3) * _cell,
					"t": lands + 0.12 * float(k), "phase": float(k) * 2.1})
			cue = "love"
			_gag_until = lands + 0.24 + LOVE_TIME
		Gag.BUTTERFLY:
			_flies.append({"at": at, "t": lands + 0.15, "side": side})
			cue = "flutter"
			_gag_until = lands + FLY_TIME
	_later(wait, func() -> void:
		if gg == _gag_gen:
			fx.cue(cue))

# --- the life over the board ---

func _tick_life(now: float) -> bool:
	_love = _love.filter(func(l): return now < float(l.t) + LOVE_TIME)
	_acorns = _acorns.filter(func(a): return now < float(a.t) + ACORN_TIME)
	_flies = _flies.filter(func(f): return now < float(f.t) + FLY_TIME)
	return not (_love.is_empty() and _acorns.is_empty() and _flies.is_empty()) \
		or (_combo_n >= COMBO_FROM and (now - _combo_at < Motion.POP_IN + 0.1 or _combo_out_at > -INF)) \
		or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1)

## Love hearts (one cached mesh through a transform each), the acorns and
## butterflies (one mesh a frame), the seal and the streak's bubble.
func _draw_life() -> void:
	if _warm_combo:
		# The streak's numbers, rasterised out of sight on the first frame:
		# drawn cold, "x3" costs its frame (Caterpillar's lesson).
		_warm_combo = false
		_life_layer.draw_string(CozyTheme.display(700), Vector2(-4000.0, -4000.0), "x0123456789",
			HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color.WHITE)
	if _cell <= 0.0 or _state.size() == 0:
		_life_shown = []
		return
	var now := _now()
	var shown: Array = []
	var s := _cell
	if not _love.is_empty():
		var mesh := _love_heart()
		shown.append(mesh)
		for l in _love:
			var e: float = now - float(l.t)
			if e <= 0.0:
				continue
			var u := e / LOVE_TIME
			var at: Vector2 = l.at + Vector2(sin(u * TAU + float(l.phase)) * 0.1 * s,
				-LOVE_RISE * s * (1.0 - (1.0 - u) * (1.0 - u)))
			var k := Motion.pop_in_scale(e, 0.2).x
			_life_layer.draw_mesh(mesh, null, Transform2D(sin(u * TAU) * 0.2, Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.4, 0.0, 1.0)))
	if not _acorns.is_empty() or not _flies.is_empty():
		var b := Face.Builder.new()
		for a in _acorns:
			_acorn_hop(b, a, now)
		for f in _flies:
			_fly(b, f, now)
		if not b.verts.is_empty():
			var m := b.mesh()
			shown.append(m)
			_life_layer.draw_mesh(m, null)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_draw_combo(now, shown)
	_life_shown = shown

func _love_heart() -> ArrayMesh:
	if _love_mesh == null:
		var b := Face.Builder.new()
		var r := maxf(12.0, _cell * LOVE_R)
		b.polygon(_heart(Vector2.ZERO, r * 1.15, 0), Pal.FLOWER_DEEP)
		b.polygon(_heart(Vector2.ZERO, r, 0), Pal.FLOWER)
		b.ellipse(Vector2(-0.45, -0.45) * r, 0.18 * r, 0.1 * r, Color(1.0, 1.0, 1.0, 0.5))
		_love_mesh = b.mesh()
	return _love_mesh

## An acorn the rake turned up: it pops out of the pile, lands a cell
## along with a squash, bounces once, rolls a little and fades.
func _acorn_hop(b: Face.Builder, a: Dictionary, now: float) -> void:
	var e := now - float(a.t)
	if e <= 0.0:
		return
	var s := _cell
	var side: float = a.side
	var u := e / ACORN_TIME
	var x := side * s * 0.9 * minf(1.0, u * 1.4)
	var h := 0.0
	if u < 0.45:
		var v := u / 0.45
		h = 4.0 * v * (1.0 - v) * s * 0.9
	elif u < 0.7:
		var v := (u - 0.45) / 0.25
		h = 4.0 * v * (1.0 - v) * s * 0.25
	var at: Vector2 = a.at + Vector2(x, s * 0.1 - h)
	# It shrinks away at the end: an acorn has no fade of its own.
	var k := clampf((1.0 - u) / 0.2, 0.0, 1.0)
	Scenery.soft_disc(b, a.at + Vector2(x, s * 0.22), s * 0.12 * k, s * 0.04 * k, Color(Pal.TEXT, 0.12))
	if k > 0.05:
		Lawn.acorn(b, at, s * 0.13 * k, side * u * 6.0)

## A butterfly that napped in the pile: up out of it with a flutter and off
## over the card's far side.
func _fly(b: Face.Builder, f: Dictionary, now: float) -> void:
	var e := now - float(f.t)
	if e <= 0.0:
		return
	var s := _cell
	var u := e / FLY_TIME
	var side: float = f.side
	var at: Vector2 = f.at + Vector2(side * s * 2.6 * u * u + sin(u * 11.0) * s * 0.18, -s * 3.0 * u)
	var beat := 0.3 + 0.7 * absf(sin(e * 14.0))
	var alpha := clampf((1.0 - u) / 0.3, 0.0, 1.0) * minf(1.0, u / 0.08)
	Cat.butterfly(b, at, s * 0.42, beat, side * 0.25, alpha)

func _draw_combo(now: float, shown: Array) -> void:
	if _combo_n < COMBO_FROM:
		return
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
		if e < 0.0:
			return
		k = Motion.pop_in_scale(e).x if _combo_popped else Motion.bump_scale(e)
	if k <= 0.01:
		return
	var font: Font = CozyTheme.display(700)
	var text := "x%d" % _combo_n
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT).x
	var box := Vector2(tw + 30.0, COMBO_FONT + 16.0)
	var tail := _combo_pos
	var centre := tail + Vector2(box.x * 0.35, -box.y * 0.95)
	centre.x = clampf(centre.x, box.x * 0.5 + 4.0, size.x - box.x * 0.5 - 4.0)
	centre.y = maxf(centre.y, box.y * 0.5 + 4.0)
	var tip := (tail - centre).round()
	var key := [text, tip]
	if _combo_shown == null or _combo_key != key:
		var b := Face.Builder.new()
		var root := Vector2(clampf(tip.x, -box.x * 0.3, box.x * 0.3), box.y * 0.3)
		b.polygon(PackedVector2Array([root + Vector2(-9.0, 0.0), tip, root + Vector2(9.0, 0.0)]), Pal.LINE)
		b.polygon(Face.Builder.round_rect(-box * 0.5 - Vector2(2.0, 2.0), box + Vector2(4.0, 4.0), box.y * 0.5 + 2.0), Pal.LINE)
		b.polygon(PackedVector2Array([root + Vector2(-6.5, -2.0), tip + (root - tip).normalized() * 3.0, root + Vector2(6.5, -2.0)]), Pal.SURFACE)
		b.polygon(Face.Builder.round_rect(-box * 0.5, box, box.y * 0.5), Pal.SURFACE)
		_combo_shown = b.mesh()
		_combo_key = key
	shown.append(_combo_shown)
	_life_layer.draw_set_transform(centre, 0.0, Vector2.ONE * k)
	_life_layer.draw_mesh(_combo_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	var ascent := font.get_ascent(COMBO_FONT)
	var descent := font.get_descent(COMBO_FONT)
	_life_layer.draw_string(font, Vector2(-tw * 0.5, (ascent - descent) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color(Pal.SUN_DEEP, alpha))
	_life_layer.draw_set_transform(Vector2.ZERO)

# --- the party ---

func _frame_rect() -> Rect2:
	return Rect2(_grid, Vector2(_state.cols(), _state.rows()) * _cell).grow(FRAME)

## After the sleepers' wave: confetti twice, the nap cat hopping onto the
## bed's foot and curling up, a bit of hedgehog wisdom, and the seal when
## the solve earned one (flawless, or any Sleepwalkers). Under reduce motion
## the cat and the seal are simply there.
func _party(lead: float) -> void:
	var now := _now()
	_party_at = now + lead
	_later(lead + 0.8, func() -> void:
		_say(_cheer(), Face.Expr.JOY))
	_cat_at = now if Motion.reduce else _party_at + CAT_AT
	if _flawless or _state.walkers():
		_stamp_at = now if Motion.reduce else _party_at + STAMP_AT
		_seal_mesh = null
		_later(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
		if not Motion.reduce:
			_later(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
	if Motion.reduce:
		_life_layer.queue_redraw()
		return
	var field := _frame_rect()
	_later(lead + 0.1, func() -> void:
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell * 0.5), 30, field.size.x * 0.9)
		fx.cue("party"))
	_later(lead + 0.7, func() -> void:
		fx.confetti(field.get_center(), 24, field.size.x * 0.7))
	_life_layer.queue_redraw()

func _cheer() -> String:
	return tr("HH_CHEER_%d" % posmod(_day_hash(), CHEERS))

func _cat_px() -> float:
	return size.x * CAT_PX

## Where she curls up: on the bed's foot, a fifth of the way along from its
## left (the seal takes the right).
func _cat_spot() -> Vector2:
	var box := _frame_rect()
	return Vector2(box.position.x + box.size.x * 0.22, box.end.y - _cat_px() * 0.28)

func _cat_start() -> Vector2:
	var box := _frame_rect()
	return Vector2(box.position.x + _cat_px() * 0.5, box.end.y - _cat_px() * 0.28)

func _cat_walk() -> float:
	return CAT_POP + CAT_HOPS * CAT_HOP_TIME

func _place_cat(t: float) -> void:
	if t < _cat_at or _cell <= 0.0:
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
	var e := t - _cat_at
	var spot := _cat_spot()
	var start := _cat_start()
	var at := spot
	var sc := Vector2.ONE
	if Motion.reduce or e >= CURL_AT - CAT_AT or _cat_curled:
		if not _cat_curled:
			_curl_cat(e > CURL_AT - CAT_AT + 1.0)
		else:
			_cat.position = _cat_spot() - _cat.size * 0.5
		return
	elif e < CAT_POP:
		at = start
		sc = Motion.pop_in_scale(e, CAT_POP)
	elif e < _cat_walk():
		var h := (e - CAT_POP) / CAT_HOP_TIME
		var n := int(h)
		var u := h - float(n)
		var from := start.lerp(spot, float(n) / CAT_HOPS)
		var to := start.lerp(spot, float(n + 1) / CAT_HOPS)
		at = from.lerp(to, u) - Vector2(0.0, 4.0 * u * (1.0 - u) * CAT_HOP_H * px)
		var sq := 0.1 * sin(u * PI)
		sc = Vector2(1.0 - sq, 1.0 + sq)
	elif e < _cat_walk() + CAT_SETTLE:
		var u := (e - _cat_walk()) / CAT_SETTLE
		var sq := 0.14 * sin(u * PI)
		sc = Vector2(1.0 + sq, 1.0 - sq)
	_cat.position = at - _cat.size * Vector2(0.5, 0.5)
	_cat.scale = sc

func _curl_cat(quiet: bool) -> void:
	_cat_curled = true
	_cat.expression = Face.Expr.SLEEPY
	_cat.scale = Vector2.ONE
	_cat.rotation = 0.0
	_cat.position = _cat_spot() - _cat.size * 0.5
	if not quiet:
		fx.cue("purr")

## The seal on the bed's lower right corner, dropping in and settling, its
## words over it: Flawless; on Sleepwalkers "Insane" over Flawless or
## Sleepwalkers, on the night seal.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := size.x * STAMP_R * 0.75
	var insane: bool = _state.walkers()
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var box := _frame_rect()
	var centre := box.end - Vector2(rad * 0.85, rad * 0.72)
	centre.x = clampf(centre.x, rad * 1.08, size.x - rad * 1.08)
	centre.y = minf(centre.y, size.y - rad * 1.02)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless else tr("HH_WALK_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
