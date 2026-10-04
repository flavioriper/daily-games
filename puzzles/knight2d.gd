extends "res://core/puzzle_base.gd"

## Knight as a flat board: a paper chessboard on a garden table. Your cream
## knight hops in Ls; take the rose king to win. The king never moves, but
## one to three rose knights stand guard and answer every move you make,
## hopping toward you. Land where one can reach and it takes you: the board
## shakes, holds a beat and slides back one move. The rules live in
## puzzles/knight_state.gd, which this only draws.
##
## Nothing wrong can sit on the board (a catch is undone as it happens), so
## no Check, no tray and no actions row: Undo, Reset and Hint ride in the
## top bar -- Pinwheel's shape.
##
## The polish (2026-10-01, spec 2026-10-01-knight-polish-design.md): on Hard
## and Insane a catch costs a heart, and out of hearts the garden dozes off
## and the card offers Try again. Insane is Brambles: every square you hop
## off grows a bramble that nothing lands on again, and a rose knight fenced
## in by them naps for good; a hop that leaves you boxed in (no hop that is
## not a catch) costs a heart and the brambles wither back to the opening.
## On every other band a position with no way left to the king is told at
## once, and a Start over button comes up under the board (players got stuck
## with no idea the day was lost). Rewards: a streak of safe hops, gags (a
## somersault, love hearts, a butterfly), and the party -- the crown lands
## on your knight's head, confetti, the nap cat, the seal and a bit of
## knightly wisdom.
##
## How it is drawn. Four meshes:
##   table -- the garden table under the board, clipped to the card and
##            drawn outside the entrance's grow;
##   still  -- the frame and the squares, made once a board size and drawn
##             scaled onto a smaller relayout (the win card's);
##   ground -- the brambles or the trail, and the marks, put together from
##             looks and handed back while nothing on it changes;
##   pieces -- every piece and what flies over them, put together from
##             looks (`_make_shape`) on every frame anything moves, or for a
##             blink or a doze now and then. At rest nothing rebuilds.
## The pieces are ui/faces/chess_piece.gd, which the menu card draws too.
##
## Spec: docs/superpowers/specs/2026-09-26-knight-flat-design.md, section 7.
## Ported from the canvas mock at docs/brainstorm/concepts.html#knight, the
## reference for every measure.

const State = preload("res://puzzles/knight_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const Piece = preload("res://ui/faces/chess_piece.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Seal = preload("res://ui/flat/seal.gd")
const NapCat = preload("res://ui/faces/nap_cat.gd")
const Cat = preload("res://ui/faces/caterpillar.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Gen = preload("res://puzzles/knight_gen.gd")
const RunMesh = preload("res://ui/flat/run_mesh.gd")

signal leave

const INSET := 70.0
const CELL_CAP := 170.0
const FRAME := 24.0
const FRAME_R := 30.0
## The hop: how long, and how high its arc rises at mid-flight, in cells.
const JUMP_TIME := 0.3
const HOP_ARC := 0.55
## A landing's squash: how long, and how deep.
const LAND_TIME := 0.2
const LAND_SQUASH := 0.14
## The rose side's answer: the beat after you land, then each next knight's.
const ANSWER_GAP := 0.08
const ANSWER_STEP := 0.09
## A catch: the hold before the board slides back, and the slide.
const CAUGHT_HOLD := 0.55
const SLIDE_BACK := 0.32
## The crouch before a hop, how deep it squats, and the stretch it springs
## into, which lets go over the first third of the flight.
const CROUCH := 0.08
const CROUCH_SQUASH := 0.12
const TAKEOFF_STRETCH := 0.09
## How far a piece leans into its hop (radians): nose up as it rises, nose
## down as it comes in, level at both ends.
const LEAN := 0.3
## The dust a landing kicks up at the plinth's sides.
const DUST_TIME := 0.35
## A caught knight is knocked aside this far (cells) and over this far
## (radians), with a swirl in its eye, over KNOCK_TIME.
const KNOCK := 0.28
const KNOCK_TILT := 0.45
const KNOCK_TIME := 0.18
## A taken rose knight is knocked off its square: it tumbles away on an arc,
## spinning this far, and fades over this.
const TAKE_TIME := 0.5
const TUMBLE_SPIN := 2.6
## The win: the crown pops off the king and spins to rest on the board over
## CROWN_FLY; your knight rears up; petals fall over PETAL_TIME.
const CROWN_FLY := 0.6
const CROWN_ARC := 0.9
const REAR := 0.4
const REAR_TIME := 0.55
const PETALS := 18
const PETAL_TIME := 2.0
## At rest, now and then: your knight blinks, and the king dozes off with a
## nod and a rising z. Moments, never a loop, so the board rebuilds only
## while one is on.
const BLINK_EVERY := 4.3
const BLINK_TIME := 0.14
const DOZE_EVERY := 7.0
const DOZE_TIME := 1.6
const DOZE_NOD := 0.08
## The garden table the board sits on: its planks, clipped to the card's
## rounded rect (ui/flat/flat_host.gd's stylebox, Rings' CARD_RADIUS).
const CARD_RADIUS := 32.0
const PLANK := 124.0
const TABLE := Color("e9d3b3")
const TABLE_DEEP := Color("b28a62")
## The marks fade in over this once the board is still.
const MARK_FADE := 0.2
## The win: the king tips this far (radians) over this long, then the wait.
const TOPPLE := 1.35
## How far (cells) the taken king is shoved aside as he topples.
const KING_SHOVE := 0.42
const TOPPLE_TIME := 0.45
const WIN_WAIT := 2.2
## The trail keeps only your last few hops' prints, the oldest faintest.
const TRAIL_HOPS := 3
## A knight's eight hops, in the order the trail's looks are numbered.
const HOPS: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
	Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)]
## The looks' ids (`_make_shape`).
const SH_KNIGHT := 0     # + side * 4 + EYE_*
const SH_KING := 10      # + 1 fallen, + 2 crowned, + 4 dozing
const SH_CROWN := 20
const SH_SHADOW := 21
const SH_REACH := 30
const SH_DOT := 31       # + MARK_*
const SH_TRAIL := 40     # + hop * TRAIL_HOPS + age
const SH_BRAMBLE := 100  # + square
const EYE_OPEN := 0
const EYE_SHUT := 1
const EYE_JOY := 2
const EYE_DIZZY := 3
const MARK_DOT := 0
const MARK_RING := 1
const MARK_TAKE := 2
const TIP_CYCLE := 8.0
const TIPS := ["KN_TIP_TAP", "KN_TIP_GOAL", "KN_TIP_ANSWER", "KN_TIP_CORNERS", "KN_TIP_TAKE"]
const TIPS_HEARTS := ["KN_TIP_TAP", "KN_TIP_CORNERS", "KN_TIP_HEARTS", "KN_TIP_ANSWER", "KN_TIP_STUCK"]
const TIPS_BRAMBLES := ["KN_TIP_BRAMBLE", "KN_TIP_FENCE", "KN_TIP_NAP", "KN_TIP_CORNERS", "KN_TIP_HEARTS"]
## A press on a square you can hop to: your knight crouches this deep, ready,
## and the dot swells, until the finger lets go.
const PRESS_SQUASH := 0.07
const PRESS_TIME := 0.12
## A bramble springs up over this as your knight leaves the square, and
## withers over WITHER_TIME when the board goes back.
const BRAMBLE_GROW := 0.45
const WITHER_TIME := 0.4
## A napping rose knight's z's: one every Z_EVERY, rising for Z_LIFE.
const Z_EVERY := 1.3
const Z_LIFE := 2.4
## The stuck button under the board: how far under the frame, and its pop.
const STUCK_DROP := 30.0
const STUCK_H := 104.0
## Insane boxed in: the beat before the brambles wither back to the opening.
const BOXED_HOLD := 0.9
## The toast: the board's own line for what just happened (a catch, a take,
## a refusal, a hint, an undo), drawn over the foot of the card. The tip card
## that used to carry these is gone from every board, so without it they
## reach no screen. Rings' toast, measure for measure; a line too long for
## the card wraps and the pill grows a row a line.
const TOAST_HOLD := 2.6
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 66.0
const STUCK_MSG := "KN_STUCK"
const REWOUND_MSG := "KN_REWOUND"

# --- hearts, Binairo's and Sunbeam's measures ---
const HEART_ROW := 64.0
const HEART_TOP := 6.0
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
const CARD_AFTER := 1.1
const CARD_AFTER_STILL := 0.3
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
const AGO := -1.0e9

# --- the streak and the gags ---
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0
const COMBO_DEFLATE := 0.25
## The bubble shows its number this long, then deflates on its own; the
## streak itself runs on, and the next right move pops it back in.
const COMBO_HOLD := 1.2
const COMBO_FONT := 44
## A gag on one kept hop in GAG_ODDS, picked off the day's hash so a day
## always deals the same ones; never two at once.
enum Gag { NONE = -1, FLIP, LOVE, BUTTERFLY }
const GAG_SPAN := 9
const GAG_ODDS := 3
const GAG_STEP := 5
const LOVE_HEARTS := 3
const LOVE_TIME := 1.2
const LOVE_RISE := 0.9
const LOVE_R := 0.13
const FLY_IN := 0.7
const FLY_SIT := 0.9
const FLY_OUT := 0.7
## A taken knight's dizzy stars, circling over it as it tumbles.
const STARS := 3

# --- the party ---
const PARTY_AT := 0.35
const PARTY_TIME := 3.0
const CHEERS := 12
## The win's crown: off the king, up, and down onto your knight's head,
## sitting a size smaller there.
const CROWN_ON := 0.78
const CAT_PX := 0.18
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

## How each piece is travelling: {"from", "to" (squares; -1 off the board),
## "at", "dur", "arc" (cells; 0 slides), "pop" (pops in at `to`)}.
var _you_a := {}
var _foe_a: Array = []
## Rose knights taken this turn, still fading where they stood: {"c", "at"}.
var _gone: Array = []
## A catch in progress: {"at"} when the rose knight lands on you; empty when none.
var _caught := {}
var _shake_at := -100.0
## Which turn the timers _play schedules belong to: a Reset, an Undo, a
## catch's slide-back or a new deal bumps it, and a stale timer does nothing.
var _turn := 0
## Your knight's shiver on a refused tap.
var _bump_at := -100.0
var _rings: Array = []
## Landings still kicking up dust: {"pos", "at"}.
var _dust: Array = []
## Whether the last frame at rest was drawn mid-blink or mid-doze, so the
## frame after the moment ends is rebuilt once to put the face back.
var _idle_drawn := false
var _table: ArrayMesh

var _opened := 0.0
## Input waits, and the marks hide, until this.
var _busy_until := -100.0
var _anim_until := 0.0
var _solved_at := -1.0
var _still: ArrayMesh
## The layout the still was made at: kept across the win card's smaller
## relayout and drawn scaled (3-4 ms a rebuild), made again only when the
## board grows or changes size.
var _still_s := 0.0
var _still_o := Vector2.ZERO
var _still_w := 0
## The ground (brambles or trail, and the marks) and the pieces, each put
## together from looks (`_make_shape`) by its own RunMesh; the ground is
## handed back while `_ground_key` holds.
var _ground: ArrayMesh
var _ground_key: Array = []
var _pieces: ArrayMesh
var _piece_rm: RunMesh
var _ground_rm: RunMesh
var _ref_s := 0.0
## What is drawn live between two looks, flushed before the next look.
var _lb: Face.Builder
## The meshes the last _draw handed over: a canvas command holds a mesh by
## RID, so dropping the only reference leaves the renderer a freed one.
var _shown: Array = []
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer
## The toast's key (translated as it is drawn, so a language change reaches
## it) and when it went up; "" when none.
var _toast := ""
var _toast_at := -100.0
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""
## Which deal the timers belong to: a build, Try again or a restore bumps it.
var _gen := 0
## A press waiting on its release: {"c", "at"}; empty when none.
var _press := {}
## Brambles drawn: square -> when it sprang up; and withering: square -> when.
var _grown := {}
var _wither := {}
## Rose knights that fell asleep: index -> when.
var _nap_at := {}
var _nap_told := false
## Bumped by every hop, Undo, hint rewind, Reset and deal: a stuck verdict
## shows only for the position it was judged on.
var _hop_id := 0
## Whether the position is lost (no way to the king), shown by the stuck
## button under the board once the pieces are still.
var _lost := false
var _stuck_btn: Button
var _stuck_at := AGO

# --- hearts ---
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
var _lost_ever := false
var _undo_ever := false
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

# --- rewards ---
## Harness hook: -2 lets the day pick, Gag.NONE never, a Gag forces it.
var force_gag := -2
var _streak := 0
var _streak_gen := 0
var _hops := 0
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
var _love: Array = []       # [{"at", "t", "phase"}]
var _flies: Array = []      # [{"t", "from"}] a butterfly visiting your knight
var _love_mesh: ArrayMesh
var _seal_mesh: ArrayMesh
var _party_at := INF
var _stamp_at := INF
var _cat: Control
var _cat_at := INF
var _cat_curled := false

func puzzle_id() -> String: return "knight"
func title() -> String: return "Knight"

## The rules, then the band's own closing: nothing can be lost (Easy,
## Medium), hearts (Hard), or Brambles (Insane).
func rules() -> String:
	var out := tr("KN_RULES")
	if _state.brambles():
		out += "\n\n" + tr("KN_RULES_BRAMBLES") % max_hearts
	elif max_hearts > 0:
		out += "\n\n" + tr("KN_RULES_HEARTS") % max_hearts
	else:
		out += "\n\n" + tr("KN_RULES_SAFE")
	return out

## The how-to-play card's pages, the band's own: hopping in an L onto the
## king, the rose knights' answer and a catch, taking a rose knight,
## Brambles (Insane), a dead end -- Start over (Easy to Hard) or boxed in
## (Insane) --, Undo and Reset, and the bulb (bands with hints). Each page is
## the board itself on a hand-made 5x5 position, playing the lesson
## (ui/hud/knight_tutorial_diagram.gd).
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/knight_tutorial_diagram.gd")
	var band: int = _state.difficulty
	var hints: int = State.hints_for(band)
	var hearts_n: int = State.hearts_for(band)
	var steps := [[Diagram.Lesson.HOP, "HTP_KN_HOP", tr("HTP_KN_HOP_BODY")]]
	if hearts_n > 0:
		steps.append([Diagram.Lesson.ANSWER, "HTP_KN_ANSWER", tr("HTP_KN_ANSWER_BODY_HEARTS") % hearts_n])
	else:
		steps.append([Diagram.Lesson.ANSWER, "HTP_KN_ANSWER", tr("HTP_KN_ANSWER_BODY")])
	steps.append([Diagram.Lesson.TAKE, "HTP_KN_TAKE", tr("HTP_KN_TAKE_BODY")])
	if band >= 3:
		steps.append([Diagram.Lesson.BRAMBLES, "KN_BRAMBLE_SEAL", tr("HTP_KN_BRAMBLES_BODY")])
		steps.append([Diagram.Lesson.STUCK, "HTP_KN_BOXED", tr("HTP_KN_BOXED_BODY") % hearts_n])
	else:
		steps.append([Diagram.Lesson.STUCK, "HTP_KN_STUCK", tr("HTP_KN_STUCK_BODY")])
	var undo_body := "HTP_KN_UNDO_BODY"
	if band >= 3:
		undo_body = "HTP_KN_RESET_BODY"
	elif hearts_n > 0:
		undo_body = "HTP_KN_UNDO_BODY_JUDGED"
	steps.append([Diagram.Lesson.UNDO, "HTP_WT_UNDO", tr(undo_body)])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_KN_HINT_BODY_ONE") if hints == 1 else tr("HTP_KN_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func _tips() -> Array:
	if _state.brambles():
		return TIPS_BRAMBLES
	if max_hearts > 0:
		return TIPS_HEARTS
	return TIPS

## Undo and Hint; Reset is the host's. No Check: a catch is the check.
## Insane has neither undo nor hint: can_undo() and hints_left() say so.
func capabilities() -> Array[String]:
	if _state.difficulty >= 3:
		return ["undo"]
	return ["undo", "hint"]

## What the phone does under each cue (docs/agents/haptics.md). A hop taps
## as your knight sets off (`hop`; a hint's falls under its good) and the
## rest of the turn knocks only for what it did to you: a bump as it lands
## on a rose knight (`_play`, by `fx.buzz`: `take` rings for a hint's hop
## too) and where the streak's confetti flies, the same landing, so one
## bump; a catch as the rose knight lands on you, a warn on Easy and Medium
## where it costs nothing and the heart on Hard and Insane; a warn once the
## board is still on the hop that left no way to the king (`stuck`), and on
## Brambles the heart for being boxed in. The rose side's answer, a bramble
## grown, a knight fenced in to nap, the slide back, the wither, a square
## that is no L (`refuse`), your own knight tapped, the streak's notes, the
## crown, the gags and the party say nothing. The win knocks as you land on
## the king (`solved` is queued for it), the seal as it lands (`_party`).
const HAPTICS := {
	"hop": Haptics.TAP,
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
	"confetti": Haptics.BUMP,
	"hint": Haptics.GOOD,
	"heart_back": Haptics.GOOD,
	"caught": Haptics.WARN,
	"stuck": Haptics.WARN,
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
	_stuck_btn = Dialog.primary("reset", tr("KN_START_OVER"))
	_stuck_btn.name = "StartOver"
	_stuck_btn.custom_minimum_size = Vector2(0.0, STUCK_H)
	_stuck_btn.z_index = 4
	_stuck_btn.visible = false
	_stuck_btn.pressed.connect(_on_start_over)
	add_child(_stuck_btn)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	_close_card()
	_state.build(rng, difficulty, bank_step)
	max_hearts = State.hearts_for(difficulty)
	_heart_used = false
	_lost_ever = false
	_undo_ever = false
	_flawless = false
	_deal()
	_reset_rewards()
	_opened = _now()
	# The marks wait for the pieces' entrance, then fade in.
	if not Motion.reduce:
		_busy_until = _opened + Motion.ENTER_DELAY + 0.2 \
			+ Motion.stagger(_state.foes.size() + 1, 0.07) + Motion.POP_IN
		_busy_for(_busy_until - _now() + MARK_FADE)
	_layout()
	fx.cue("enter")
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()

## The board as it is dealt, and as Try again deals it back: every heart,
## every piece where it opened, no brambles.
func _deal() -> void:
	_turn += 1
	hearts = max_hearts
	out_of_hearts = false
	_asleep = false
	_split_index = -1
	_split_at = AGO
	_back_index = -1
	_back_at = AGO
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	_snap_to_state()
	_rings = []
	_shake_at = -100.0
	_bump_at = -100.0
	_solved_at = -1.0
	_toast = ""
	_toast_at = -100.0
	_press = {}
	_hop_id += 1
	_nap_told = false
	_set_lost(false)

static func _still_at(c: int) -> Dictionary:
	return {"from": c, "to": c, "at": -100.0, "dur": 1.0, "arc": 0.0, "pop": false}

## Every piece drawn where the state has it, nothing moving.
func _snap_to_state() -> void:
	_you_a = _still_at(_state.you)
	_foe_a = []
	for i in _state.foes.size():
		_foe_a.append(_still_at(_state.foe_square(i)))
	_grown = {}
	_wither = {}
	for c in _state.size():
		if _state.is_bramble(c):
			_grown[c] = AGO
	_nap_at = {}
	_sync_naps()
	_gone = []
	_caught = {}
	_dust = []
	_busy_until = -100.0
	_anim_until = 0.0
	_refresh()

# --- layout ---

func _cell() -> float:
	if _state.w <= 0:
		return 0.0
	var inset := _inset()
	return maxf(0.0, minf(CELL_CAP, minf(size.x - 2.0 * inset, size.y - 2.0 * inset - _heart_row()) / float(_state.w)))

## The table's margin round the board (the tutorial's page is short).
func _inset() -> float:
	return INSET

## The room the hearts' pill takes over the board on Hard and Insane.
func _heart_row() -> float:
	return HEART_ROW if max_hearts > 0 else 0.0

func _grid_size() -> Vector2:
	return Vector2.ONE * float(_state.w) * _cell()

func _origin() -> Vector2:
	return (size - _grid_size() + Vector2(0.0, _heart_row())) * 0.5

func _centre(c: int) -> Vector2:
	return _origin() + (Vector2(c % _state.w, c / _state.w) + Vector2(0.5, 0.5)) * _cell()

## Control-local point over the centre of the square at (row, column), the
## name every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(r * _state.w + c)

func card_height(available: float) -> float:
	return available

## The board is square and the slot is tall: halve the slack.
func card_centred() -> bool:
	return true

func _layout() -> void:
	_table = null
	_love_mesh = null
	_seal_mesh = null
	_place_stuck()
	# a cat already curled up follows the frame onto the win card's smaller
	# board (she stayed where the frame was, over the card's buttons)
	if _cat_curled and is_instance_valid(_cat) and _cell() > 0.0:
		var px := _cat_px()
		_cat.size = Vector2(px, px)
		_cat.pivot_offset = _cat.size * Vector2(0.5, 0.85)
		_cat.position = _cat_spot() - _cat.size * 0.5
	_refresh()
	if _heart_layer != null:
		_heart_layer.queue_redraw()
	if _life_layer != null:
		_life_layer.queue_redraw()

func _square_at(local: Vector2) -> int:
	var s := _cell()
	if s <= 0.0:
		return -1
	var v := (local - _origin()) / s
	var x := int(floor(v.x))
	var y := int(floor(v.y))
	if x < 0 or y < 0 or x >= _state.w or y >= _state.w:
		return -1
	return y * _state.w + x

# --- the pieces in motion ---

## Where a travelling piece is at `t`: {"at" (px), "lift" (px), "land"
## (when it lands), "sq" (its crouch or stretch), "tilt" (its lean), "dir"
## (-1 or 1, which way a hop heads), "hopping" (crouched or in the air)};
## empty when it is off the board. A hop crouches for its "crouch" first and
## then flies for "dur"; a slide ("arc" 0) only glides, and lets go of any
## "tilt_from" it started with (a knocked knight righting itself).
func _where(a: Dictionary, t: float) -> Dictionary:
	if int(a.to) < 0:
		return {}
	var from: int = a.from if int(a.from) >= 0 else a.to
	var crouch := float(a.get("crouch", 0.0))
	var fly_at := float(a.at) + crouch
	var dur := maxf(float(a.dur), 0.001)
	var u := 1.0 if Motion.reduce else clampf((t - fly_at) / dur, 0.0, 1.0)
	var e := 0.5 - 0.5 * cos(PI * u)
	var start: Vector2 = a.from_px if a.has("from_px") else _centre(from)
	var end := _centre(a.to)
	var arc := float(a.arc)
	var sq := Vector2.ONE
	var tilt := float(a.get("tilt_from", 0.0)) * (1.0 - e)
	var dir := 1.0 if end.x >= start.x else -1.0
	var hopping := false
	if arc > 0.0 and not Motion.reduce and t >= float(a.at) and t < fly_at + dur:
		hopping = true
		if t < fly_at:
			var k := sin(0.5 * PI * (t - float(a.at)) / maxf(crouch, 0.001)) * CROUCH_SQUASH
			sq = Vector2(1.0 + k * 0.6, 1.0 - k)
		else:
			var st := TAKEOFF_STRETCH * maxf(0.0, 1.0 - u / 0.35)
			sq = Vector2(1.0 - st * 0.6, 1.0 + st)
			tilt = dir * LEAN * -cos(PI * u) * sin(PI * u) * 2.0
			if bool(a.get("flip", false)):
				# the gag: a whole somersault over the top of the hop
				tilt -= dir * TAU * (u * u * (3.0 - 2.0 * u))
	return {"at": start.lerp(end, e), "lift": sin(PI * u) * arc * _cell(),
		"land": fly_at + float(a.dur), "sq": sq, "tilt": tilt, "dir": dir, "hopping": hopping}

func _land_squash(land: float, t: float) -> Vector2:
	var u := (t - land) / LAND_TIME
	if Motion.reduce or u < 0.0 or u >= 1.0:
		return Vector2.ONE
	var k := sin(PI * u) * LAND_SQUASH
	return Vector2(1.0 + k * 0.5, 1.0 - k)

func _jump() -> float:
	return 0.0 if Motion.reduce else JUMP_TIME

func _crouch() -> float:
	return 0.0 if Motion.reduce else CROUCH

## A hop from `from` to `to` starting at `at`: the crouch, then the flight.
func _hop(from: int, to: int, at: float) -> Dictionary:
	return {"from": from, "to": to, "at": at, "dur": maxf(_jump(), 0.001), "arc": HOP_ARC,
		"pop": false, "crouch": _crouch()}

func _kick_dust(c: int, at: float) -> void:
	if not Motion.reduce:
		_dust.append({"pos": _centre(c), "at": at})

## One hop of yours and the rose side's answer, animated. A catch holds, then
## everything slides back; the state never kept it. On Hard and Insane it
## costs a heart. A kept hop grows the streak (and maybe a gag), grows a
## bramble on Insane, and once everything is still the position is checked:
## lost on Easy to Hard (the Start over button), boxed in on Insane.
func _play(to: int, from_hint := false) -> void:
	var t := _now()
	if is_done() or out_of_hearts or t < _busy_until:
		return
	if not _state.legal().has(to):
		if _state.is_bramble(to) and Gen.hops(_state.w, _state.you).has(to):
			_refuse("KN_BRAMBLE")
		else:
			_refuse("KN_L")
		return
	var from: int = _state.you
	var r: Dictionary = _state.play(to)
	if r.is_empty():
		return
	var jt := _jump()
	var lead := _crouch()
	var land := t + lead + jt
	var caught := int(r.caught) >= 0
	var gag := Gag.NONE
	if not caught and not bool(r.won) and not from_hint:
		gag = _pick_gag()
	_you_a = _hop(from, to, t)
	_you_a["flip"] = gag == Gag.FLIP
	_kick_dust(to, land)
	fx.cue("hop")
	if gag == Gag.FLIP:
		_later(lead, func(): fx.cue("flip"))
	if int(r.get("grew", -1)) >= 0:
		_grown[from] = t + lead
		_later(lead + jt * 0.3, func(): fx.cue("bramble"))
	var took: int = r.took
	if took >= 0:
		var away := 1.0 if _centre(to).x >= _centre(from).x else -1.0
		_gone.append({"c": to, "at": land, "dir": away})
		_foe_a[took] = _still_at(-1)
		_nap_at.erase(took)
		var turn := _turn
		_later(lead + jt, func():
			if turn != _turn:
				return
			fx.puff(_centre(to), Pal.KNIGHT_ROSE, 7)
			fx.sparkle(_centre(to) - Vector2(0.0, _cell() * 0.4), Pal.SUN)
			fx.cue("take")
			if not from_hint and not is_done():
				fx.buzz(Haptics.BUMP))
	var last := land
	var k := 0
	var catcher := -1
	var mvs: Array = r.moved
	for i in mvs.size():
		var mv: Vector2i = mvs[i]
		if i == took or mv.x < 0 or mv.y < 0 or mv.x == mv.y:
			continue
		var at := land + (0.0 if Motion.reduce else ANSWER_GAP + Motion.stagger(k, ANSWER_STEP))
		_foe_a[i] = _hop(mv.x, mv.y, at)
		last = at + lead + jt
		_kick_dust(mv.y, last)
		if mv.y == to:
			catcher = mv.x
		k += 1
	if k > 0:
		var turn := _turn
		_later(land - t + (0.0 if Motion.reduce else ANSWER_GAP), func():
			if turn == _turn:
				fx.cue("answer"))
	if bool(r.won):
		_busy_until = land
		_busy_for(land - t)
		note_move()
		return
	if caught:
		var knock := -1.0 if catcher >= 0 and _centre(catcher).x > _centre(to).x else 1.0
		_caught = {"at": last, "dir": knock}
		_shake_at = last
		_busy_until = last + CAUGHT_HOLD + (0.0 if Motion.reduce else SLIDE_BACK)
		_busy_for(_busy_until - t + MARK_FADE)
		_was_busy = true
		_break_streak()
		_clear_gags()
		if max_hearts > 0:
			_lose_heart(last)
		var turn := _turn
		_later(last - t, func():
			if turn != _turn:
				return
			fx.cue("caught")
			if max_hearts > 0:
				fx.cue("heart_lost")
				_tell_hearts("KN_CAUGHT_HEART")
			else:
				_tell("KN_CAUGHT", Face.Expr.STRAIN))
		_later(last - t + CAUGHT_HOLD, func():
			if turn == _turn and not _caught.is_empty():
				fx.cue("slide")
				_slide_to_state(_now(), 0.0)
				if out_of_hearts:
					_later(SLIDE_BACK, _run_out))
		_refresh()
		moved.emit()
		return
	var napped: Array = r.get("napped", [])
	for i: int in napped:
		_nap_at[i] = last
	if not napped.is_empty():
		var turn := _turn
		_later(last - t + 0.1, func():
			if turn != _turn:
				return
			fx.cue("nap")
			if not _nap_told:
				_nap_told = true
				_tell("KN_NAPPED", Face.Expr.JOY))
	# Judged now, while the position is the one this hop made (a hop slipped
	# in before the reveal must not be charged for this one's box), and
	# shown once everything is still. Boxed in holds input until it plays.
	var boxed: bool = _state.brambles() and _state.trapped()
	var lost: bool = not _state.brambles() and _state.lost()
	_busy_until = last + (100.0 if boxed else 0.0)
	_busy_for(last - t + MARK_FADE)
	_hop_id += 1
	var hop_id := _hop_id
	note_move()
	if took >= 0:
		_tell("KN_TAKEN", Face.Expr.HAPPY)
	elif from_hint:
		_tell("KN_HINT", Face.Expr.HAPPY)
	elif _tip_mood == Face.Expr.STRAIN:
		_say(tr(_tips()[1]), Face.Expr.HAPPY)
	if from_hint:
		_break_streak()
	else:
		_on_safe_hop(to, land, gag)
	_later(last - t + 0.05, func():
		if hop_id == _hop_id:
			_show_stuck(boxed, lost))
	_refresh()

## Once a kept hop has settled: on Brambles, boxed in (no hop that is not a
## catch) costs a heart and the board withers back to the opening; on every
## other band a position with no way left to the king says so and brings up
## the Start over button.
func _show_stuck(boxed: bool, lost: bool) -> void:
	if is_done() or out_of_hearts:
		return
	if boxed:
		_boxed_in()
		return
	if _state.brambles():
		return
	var was := _lost
	_set_lost(lost)
	if _lost and not was:
		_tell(STUCK_MSG, Face.Expr.STRAIN)
		fx.cue("stuck")

## Brambles: nowhere left to hop that is not a catch. A heart splits, your
## knight shivers, and after a beat the brambles wither and every piece
## slides back to the opening -- or, the last heart gone, dusk.
func _boxed_in() -> void:
	var t := _now()
	_break_streak()
	_clear_gags()
	_bump_at = t
	_lose_heart(t)
	fx.cue("boxed")
	fx.cue("heart_lost")
	_tell_hearts("KN_BOXED")
	var hold := Motion.REDUCED_TIME if Motion.reduce else BOXED_HOLD
	_busy_until = t + hold + (0.0 if Motion.reduce else SLIDE_BACK)
	_was_busy = true
	_busy_for(_busy_until - t + MARK_FADE)
	_refresh()
	moved.emit()
	var turn := _turn
	_later(hold, func():
		if turn != _turn:
			return
		if out_of_hearts:
			_run_out()
			return
		_state.reset_board()
		fx.cue("wither")
		_slide_to_state(_now(), Motion.RESET_STAGGER))

## How far a caught knight has been knocked at `t`: 0 to 1, 0 when none.
func _knocked(t: float) -> float:
	if _caught.is_empty() or t < float(_caught.at):
		return 0.0
	if Motion.reduce:
		return 1.0
	return Motion.back_out(clampf((t - float(_caught.at)) / KNOCK_TIME, 0.0, 1.0))

## Every piece slides from where it is drawn to where the state has it:
## after a catch, an Undo, a hint's rewind or a Reset. It starts from the
## pixel each piece is drawn at right now (`from_px`), so a Reset or an Undo
## mid-hop slides from the air rather than snapping to the hop's end first,
## and a knocked knight slides home from where it was knocked, righting
## itself on the way. A rose knight taken in the undone move pops back in
## where it stood.
func _slide_to_state(t: float, stagger: float) -> void:
	var dur := 0.001 if Motion.reduce else SLIDE_BACK
	_turn += 1
	var you_now := _where(_you_a, t)
	var kn := _knocked(t)
	var kdir := float(_caught.get("dir", 1.0))
	_caught = {}
	_shake_at = -100.0
	_you_a = {"from": int(_you_a.to), "to": _state.you, "at": t, "dur": dur, "arc": 0.0, "pop": false}
	if not you_now.is_empty():
		_you_a["from_px"] = you_now.at + Vector2(kdir * KNOCK * _cell() * kn, 0.0)
		_you_a["tilt_from"] = kdir * KNOCK_TILT * kn + float(you_now.tilt)
	# brambles the state no longer has wither where they stood
	for c in _grown.keys():
		if not _state.is_bramble(int(c)):
			_wither[c] = t
			_grown.erase(c)
	_hop_id += 1
	_sync_naps()
	var k := 0
	for i in _state.foes.size():
		var want: int = _state.foe_square(i)
		var shown: int = int(_foe_a[i].to)
		var drawn := _where(_foe_a[i], t)
		var at := t + Motion.stagger(k, stagger)
		if want < 0:
			_foe_a[i] = _still_at(-1)
		elif shown < 0:
			_foe_a[i] = {"from": want, "to": want, "at": at, "dur": dur, "arc": 0.0, "pop": true}
		else:
			_foe_a[i] = {"from": shown, "to": want, "at": at, "dur": dur, "arc": 0.0, "pop": false}
			if not drawn.is_empty():
				_foe_a[i]["from_px"] = drawn.at
				_foe_a[i]["tilt_from"] = drawn.tilt
		k += 1
	_gone = []
	_dust = []
	_press = {}
	_busy_until = t + Motion.stagger(k, stagger) + dur
	_busy_for(maxf(_busy_until - t + MARK_FADE, WITHER_TIME))
	_refresh()

## Runs `fn` after `delay`, unless the board has left the tree meanwhile
## (Mushroom Patch's `_after`); the turn guard inside each `fn` does the rest.
func _later(delay: float, fn: Callable) -> void:
	if not is_inside_tree():
		return
	var gen := _gen
	get_tree().create_timer(maxf(0.0, delay)).timeout.connect(func():
		if gen == _gen and is_inside_tree():
			fn.call())

func _refuse(key: String) -> void:
	_bump_at = _now()
	_busy_for(Motion.SHIVER_TIME * 2.0)
	fx.cue("refuse")
	_tell(key, Face.Expr.STRAIN)
	_refresh()

# --- frames ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.size() == 0:
		return
	var t := _now()
	# A catch or a boxed-in ending lets go of the HUD: it greyed Undo, Hint
	# and Reset.
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
	if _animating(t):
		_refresh()
	elif _idle_moment(t):
		_idle_drawn = true
		_refresh()
	elif _idle_drawn:
		_idle_drawn = false
		_refresh()
	elif _toast != "" and t - _toast_at < TOAST_HOLD + 0.1:
		# the toast is drawn apart from the meshes: a redraw, not a rebuild
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()

## Moving while anything travels, the marks are still fading in, or the
## pieces are still entering.
func _animating(t: float) -> bool:
	if t < _anim_until or not _press.is_empty():
		return true
	if Motion.reduce:
		return false
	if not _nap_at.is_empty() and not is_done():
		return true
	var entrance := Motion.ENTER_DELAY + Motion.ENTER_POP \
		+ Motion.stagger(_state.foes.size() + 2, 0.07) + Motion.POP_IN + 0.2
	return t - _opened < entrance

## Whether a blink or a doze is on at `t`: the only rebuilds at rest.
func _idle_moment(t: float) -> bool:
	return _eye(t) < 0.5 or _doze(t) >= 0.0

## Your knight's eye at rest: 0 for the length of a blink every BLINK_EVERY.
func _eye(t: float) -> float:
	if Motion.reduce or is_done():
		return 1.0
	return 0.0 if fmod(t - _opened, BLINK_EVERY) < BLINK_TIME else 1.0

## How far through a doze the king is at `t`, 0 to 1; -1 when awake.
func _doze(t: float) -> float:
	if Motion.reduce or is_done() or t < _busy_until:
		return -1.0
	var p := fmod(t - _opened + 3.0, DOZE_EVERY)
	return p / DOZE_TIME if p < DOZE_TIME else -1.0

func _busy_for(seconds: float) -> void:
	# the marks pop in over POP_IN plus their stagger after the fade starts
	_anim_until = maxf(_anim_until, _now() + seconds + Motion.POP_IN + 0.2)

func _refresh() -> void:
	_pieces = null
	queue_redraw()

func _entry(i: int, t: float) -> float:
	if Motion.reduce:
		return 1.0
	var e := t - _opened - Motion.ENTER_DELAY - 0.2 - Motion.stagger(i, 0.07)
	return 0.01 if e <= 0.0 else Motion.pop_in_scale(e).x

# --- the drawing ---

func _draw() -> void:
	if _state.size() == 0 or _cell() <= 0.0:
		return
	var t := _now()
	var shown: Array = []
	# the table is the card's own surface: never grown, never faded in
	if _table == null:
		_table = _build_table()
	draw_mesh(_table, null)
	shown.append(_table)
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		_shown = shown
		return
	var grow := Motion.wide_pop_scale(since)
	var mid := _origin() + _grid_size() * 0.5
	var shake := Motion.shiver_offset(t - _shake_at) * 3.0
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow) + Vector2(shake, 0.0))
	var tint := Color(1.0, 1.0, 1.0, seen)
	var s := _cell()
	if _still == null or s > _still_s + 0.5 or _still_w != _state.w:
		_still = _build_still()
		_still_s = s
		_still_o = _origin()
		_still_w = _state.w
	_check_ref()
	if _pieces == null:
		_lb = Face.Builder.new()
		_build_ground(t)
		_pieces = _build_pieces(t)
	# the frame and squares as made, scaled onto the board as laid out now
	var k := s / _still_s
	draw_mesh(_still, null, xf * Transform2D(0.0, Vector2.ONE * k, 0.0, _origin() - _still_o * k), tint)
	shown.append(_still)
	for m in [_ground, _pieces]:
		if m != null:
			draw_mesh(m, null, xf, tint)
			shown.append(m)
	_draw_toast(t, shown)
	_shown = shown

## The garden table under the board: planks across the card, each a shade
## apart with a butt joint, grain and now and then a knot, and a few petals
## and leaves blown onto it, never under the board. Clipped to the card's
## rounded rect, built once a layout.
func _build_table() -> ArrayMesh:
	var b := Face.Builder.new()
	var clip := Face.Builder.round_rect(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0), CARD_RADIUS - 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7127
	var n := int(ceil(size.y / PLANK))
	var y0 := (size.y - float(n) * PLANK) * 0.5
	for i in n:
		var top := y0 + float(i) * PLANK
		var tone := TABLE.lerp(TABLE_DEEP, 0.06 + 0.07 * float(i % 2) + rng.randf_range(-0.02, 0.02))
		_clipped(b, _rect(Vector2(0.0, top), Vector2(size.x, PLANK - 4.0)), tone, clip)
		_clipped(b, _rect(Vector2(0.0, top + PLANK - 4.0), Vector2(size.x, 4.0)), Color(TABLE_DEEP, 0.55), clip)
		_clipped(b, _rect(Vector2(0.0, top), Vector2(size.x, 3.0)), Color(1.0, 1.0, 1.0, 0.18), clip)
		var joint := rng.randf_range(size.x * 0.2, size.x * 0.8)
		_clipped(b, _rect(Vector2(joint, top), Vector2(3.0, PLANK - 4.0)), Color(TABLE_DEEP, 0.4), clip)
		# grain: long soft waves along the plank, kept clear of the card's corners
		for g in 3:
			var gy := top + PLANK * (0.22 + 0.26 * float(g)) + rng.randf_range(-6.0, 6.0)
			var phase := rng.randf() * TAU
			var x0 := CARD_RADIUS + rng.randf_range(0.0, size.x * 0.3)
			var x1 := minf(size.x - CARD_RADIUS, x0 + rng.randf_range(size.x * 0.35, size.x * 0.7))
			var pts := PackedVector2Array()
			var x := x0
			while x <= x1:
				pts.append(Vector2(x, gy + sin(x / 70.0 + phase) * 3.5))
				x += 18.0
			if pts.size() > 1:
				b.stroke(pts, 2.0, Color(TABLE_DEEP, 0.16))
		if rng.randf() < 0.45:
			var kp := Vector2(rng.randf_range(CARD_RADIUS * 2.0, size.x - CARD_RADIUS * 2.0), top + PLANK * 0.5)
			b.stroke(Face.Builder.ring(kp, 16.0, 7.0), 2.5, Color(TABLE_DEEP, 0.3), true)
			b.ellipse(kp, 6.0, 3.0, Color(TABLE_DEEP, 0.35))
	# petals and leaves, blown on, off the board's footprint
	var keep_out := Rect2(_origin() - Vector2.ONE * (FRAME + 30.0), _grid_size() + Vector2.ONE * (FRAME + 30.0) * 2.0)
	var placed := 0
	var tries := 0
	while placed < 9 and tries < 200:
		tries += 1
		var p := Vector2(rng.randf_range(40.0, size.x - 40.0), rng.randf_range(40.0, size.y - 40.0))
		if keep_out.has_point(p):
			continue
		var ang := rng.randf() * TAU
		if placed % 3 == 2:
			_leaf(b, p, rng.randf_range(20.0, 28.0), ang)
		else:
			var col: Color = Pal.FLOWER_TILE if placed % 2 == 0 else Pal.FLOWER
			_petal(b, p, rng.randf_range(17.0, 22.0), ang, col)
		placed += 1
	return b.mesh()

static func _rect(at: Vector2, sz: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(sz.x, 0.0), at + sz, at + Vector2(0.0, sz.y)])

static func _clipped(b: Face.Builder, pts: PackedVector2Array, col: Color, clip: PackedVector2Array) -> void:
	for piece in Geometry2D.intersect_polygons(pts, clip):
		b.polygon(piece, col)

## A petal `r` long pointing along `ang`, with a soft shadow under it.
static func _petal(b: Face.Builder, at: Vector2, r: float, ang: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 16:
		var a := TAU * float(k) / 16.0
		# rounded at the tip, drawn to a notch at the base
		var rr := r * (0.55 + 0.45 * cos(a * 0.5) * cos(a * 0.5))
		pts.append(Vector2(cos(a) * rr, sin(a) * rr * 0.6))
	var shadow := PackedVector2Array()
	var body := PackedVector2Array()
	for q in pts:
		shadow.append(at + q.rotated(ang) + Vector2(2.0, 3.0))
		body.append(at + q.rotated(ang))
	b.polygon(shadow, Color(TABLE_DEEP, 0.25))
	b.polygon(body, col)
	b.stroke(PackedVector2Array([at - Vector2(r * 0.4, 0.0).rotated(ang), at + Vector2(r * 0.3, 0.0).rotated(ang)]),
		1.5, Color(Pal.FLOWER_DEEP, 0.35))

## A leaf `r` long along `ang`, with its vein.
static func _leaf(b: Face.Builder, at: Vector2, r: float, ang: float) -> void:
	var half := PackedVector2Array()
	var body := PackedVector2Array()
	var shadow := PackedVector2Array()
	for k in 9:
		var f := float(k) / 8.0
		half.append(Vector2(lerpf(-r, r, f), -sin(PI * f) * r * 0.42))
	for k in range(7, 0, -1):
		var f := float(k) / 8.0
		half.append(Vector2(lerpf(-r, r, f), sin(PI * f) * r * 0.42))
	for q in half:
		body.append(at + q.rotated(ang))
		shadow.append(at + q.rotated(ang) + Vector2(2.0, 3.0))
	b.polygon(shadow, Color(TABLE_DEEP, 0.25))
	b.polygon(body, Pal.LEAF)
	b.stroke(PackedVector2Array([at - Vector2(r * 1.25, 0.0).rotated(ang), at + Vector2(r * 0.8, 0.0).rotated(ang)]),
		2.0, Color(Pal.LEAF_DEEP, 0.7))

## The wooden frame, its shadow, its brass corner pegs and the squares. None
## of it ever moves.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	var o := _origin()
	var g := _grid_size()
	var out := o - Vector2.ONE * FRAME
	var out_size := g + Vector2.ONE * FRAME * 2.0
	Scenery.soft_disc(b, out + out_size * Vector2(0.5, 1.0) + Vector2(0.0, 10.0), out_size.x * 0.55, 36.0, Color(Pal.TEXT, 0.14))
	b.fan(Face.Builder.round_rect(out + Vector2(0.0, 8.0), out_size, FRAME_R), Pal.CHESS_FRAME_DEEP)
	b.fan(Face.Builder.round_rect(out, out_size, FRAME_R), Pal.CHESS_FRAME)
	b.fan(Face.Builder.round_rect(out + Vector2(FRAME, 6.0), Vector2(out_size.x - FRAME * 2.0, 6.0), 3.0),
		Color(1.0, 0.925, 0.784, 0.3))
	# grain along each rail
	for side in 4:
		var along := Vector2.RIGHT if side < 2 else Vector2.DOWN
		var mid := FRAME * 0.5
		var base: Vector2 = [out + Vector2(FRAME_R, mid), out + Vector2(FRAME_R, out_size.y - mid),
			out + Vector2(mid, FRAME_R), out + Vector2(out_size.x - mid, FRAME_R)][side]
		var span := (out_size.x if side < 2 else out_size.y) - FRAME_R * 2.0
		for k in 2:
			var off := (Vector2(along.y, along.x)) * (float(k) * 7.0 - 3.5)
			b.stroke(PackedVector2Array([base + off + along * span * (0.08 + 0.3 * k), base + off + along * span * (0.55 + 0.35 * k)]),
				2.0, Color(Pal.CHESS_FRAME_DEEP, 0.28))
	# the brass pegs at the corners
	for cn: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := out + Vector2(FRAME * 0.5, FRAME * 0.5) + (out_size - Vector2.ONE * FRAME) * cn
		b.disc(p + Vector2(0.0, 2.0), FRAME * 0.34, Pal.CHESS_FRAME_DEEP)
		b.disc(p, FRAME * 0.32, Pal.CROWN_DEEP)
		b.disc(p + Vector2(-2.0, -2.0), FRAME * 0.14, Color(Pal.CROWN, 0.9))
	# the inner lip the squares are set into
	b.fan(PackedVector2Array([o - Vector2.ONE * 4.0, o + Vector2(g.x + 4.0, -4.0), o + g + Vector2.ONE * 4.0,
		o + Vector2(-4.0, g.y + 4.0)]), Pal.CHESS_FRAME_DEEP)
	b.fan(PackedVector2Array([o, o + Vector2(g.x, 0.0), o + g, o + Vector2(0.0, g.y)]), Pal.CHESS_LIGHT)
	var tile := Pal.CHESS_DARK.lerp(Pal.CHESS_LIGHT, 0.2)
	for c in _state.size():
		var x: int = c % _state.w
		var y: int = c / _state.w
		var at := o + Vector2(x, y) * s
		if (x + y) % 2 == 0:
			# a paper square's faint speckle
			var rng := RandomNumberGenerator.new()
			rng.seed = c * 31 + 5
			for k in 3:
				b.disc(at + Vector2(rng.randf_range(0.15, 0.85), rng.randf_range(0.15, 0.85)) * s, s * 0.012,
					Color(Pal.CHESS_DARK_EDGE, 0.35))
			continue
		b.fan(PackedVector2Array([at, at + Vector2(s, 0.0), at + Vector2(s, s), at + Vector2(0.0, s)]), Pal.CHESS_DARK)
		b.fan(Face.Builder.round_rect(at + Vector2.ONE * s * 0.12, Vector2.ONE * s * 0.76, s * 0.12), tile)
		b.fan(PackedVector2Array([at + Vector2(0.0, s - 5.0), at + Vector2(s, s - 5.0), at + Vector2(s, s), at + Vector2(0.0, s)]),
			Color(Pal.CHESS_DARK_EDGE, 0.5))
	# the lip's shade over the squares' top and left edges
	b.fan(PackedVector2Array([o, o + Vector2(g.x, 0.0), o + Vector2(g.x, 6.0), o + Vector2(0.0, 6.0)]), Color(Pal.CHESS_FRAME_DEEP, 0.18))
	b.fan(PackedVector2Array([o, o + Vector2(6.0, 0.0), o + Vector2(6.0, g.y), o + Vector2(0.0, g.y)]), Color(Pal.CHESS_FRAME_DEEP, 0.12))
	return b.mesh()

## The shapes the ground and the pieces are put together from, made once at
## the reference cell `_ref_s` about their own origin (Quilt's split, at the
## 2026-10-02 checkup): before it, every piece, bramble, hoofprint and mark
## was drawn in script on every frame anything moved -- and on Brambles a
## napping rose knight keeps the board moving, so a late Insane board built
## 20k vertices a frame (8-22 ms).
func _make_shape(id: int) -> Face.Builder:
	var b := Face.Builder.new()
	var s := _ref_s
	if id < SH_KING:
		var eye := id % 4
		Piece.knight(b, Vector2.ZERO, s, id / 4, -1.0, 0.0, Vector2.ONE, eye == EYE_JOY, 1.0, 0.0,
			0.0 if eye == EYE_SHUT else 1.0, eye == EYE_DIZZY, false)
	elif id < SH_CROWN:
		var k := id - SH_KING
		Piece.king(b, Vector2.ZERO, s, 0.0, 1.0, (k & 1) != 0, (k & 2) != 0, (k & 4) != 0, false)
	elif id == SH_CROWN:
		Piece.crown(b, Vector2.ZERO, s)
	elif id == SH_SHADOW:
		Scenery.soft_disc(b, Vector2.ZERO, s * 0.3, s * 0.08, RunMesh.slot(0))
	elif id == SH_REACH:
		_mark_reach(b, Vector2.ZERO, s, 1.0)
	elif id >= SH_DOT and id <= SH_DOT + MARK_TAKE:
		_mark_move(b, Vector2.ZERO, s, id - SH_DOT, 1.0, 1.0)
	elif id < SH_BRAMBLE:
		var k := id - SH_TRAIL
		var d: Vector2i = HOPS[k / TRAIL_HOPS]
		_hop_prints(b, Vector2.ZERO, Vector2(d) * s, s, _trail_col(k % TRAIL_HOPS))
	else:
		# about its foot, which is where it grows from
		_bramble(b, Vector2(0.0, -s * 0.3), s, 1.0, 1.0, id - SH_BRAMBLE)
	return b

## The looks are made again only when the board grows past them; the win
## card's smaller board draws them scaled.
func _check_ref() -> void:
	var s := _cell()
	if _piece_rm == null:
		_piece_rm = RunMesh.new(_make_shape)
		_ground_rm = RunMesh.new(_make_shape)
	if s > _ref_s + 0.5:
		_ref_s = s
		_piece_rm.reset()
		_ground_rm.reset()
		_ground_rm.share_shapes(_piece_rm)
		_ground_key = []

## Puts shape `id` under `xf`, after whatever the live builder holds, so the
## paint order is the order things were drawn in.
func _put(rm: RunMesh, id: int, xf: Transform2D, colours: Array = []) -> void:
	if not _lb.verts.is_empty():
		rm.put_builder(_lb)
		_lb = Face.Builder.new()
	rm.put(id, colours, xf)

func _flush(rm: RunMesh) -> ArrayMesh:
	if not _lb.verts.is_empty():
		rm.put_builder(_lb)
		_lb = Face.Builder.new()
	return rm.mesh()

## A piece's soft shadow, `r` of a cell wide, at alpha `a`.
func _put_shadow(at: Vector2, s: float, r: float, a: float) -> void:
	var xf := Transform2D(0.0, Vector2.ONE * (s / _ref_s) * (r / 0.3), 0.0, at + Vector2(0.0, s * 0.33))
	_put(_piece_rm, SH_SHADOW, xf, [Color(Pal.TEXT, snappedf(a, 0.01))])

## A knight look put where Piece.knight would draw it with these arguments
## (its map is affine: foot, turn, squash and cell size).
func _put_knight(at: Vector2, s: float, side: int, look: float, lift := 0.0, sq := Vector2.ONE,
		joy := false, tilt := 0.0, eye := 1.0, dizzy := false) -> void:
	var up := clampf(lift / s, 0.0, 1.0)
	_put_shadow(at, s, (0.3 - up * 0.08) * sq.x, 0.2 - up * 0.12)
	var u := s * Piece.PIECE
	var u0 := _ref_s * Piece.PIECE
	var foot := at + Vector2(0.0, -lift - s * Piece.STAND) + Piece.FOOT * u
	var foot0 := Vector2(0.0, -_ref_s * Piece.STAND) + Piece.FOOT * u0
	var k := u / u0
	var sx := -look * sq.x * k
	var sy := sq.y * k
	var c := cos(tilt)
	var n := sin(tilt)
	var xf := Transform2D(Vector2(c, n) * sx, Vector2(-n, c) * sy, foot) * Transform2D(0.0, -foot0)
	var e := EYE_DIZZY if dizzy else EYE_JOY if joy else EYE_SHUT if eye < 0.5 else EYE_OPEN
	_put(_piece_rm, SH_KNIGHT + side * 4 + e, xf)

## The king's look put where Piece.king would draw him.
func _put_king(at: Vector2, s: float, tip: float, scale: float, fallen: bool, crowned: bool, doze: bool) -> void:
	_put_shadow(at, s, 0.3, 0.2)
	var k := scale * s / _ref_s
	var lift := Vector2(0.0, -s * (0.3 + Piece.STAND))
	var foot0 := Vector2(0.0, _ref_s * 0.3) + Vector2(0.0, -_ref_s * (0.3 + Piece.STAND))
	var xf := Transform2D(tip, at + Vector2(0.0, s * 0.3)) * Transform2D(0.0, Vector2.ONE * k, 0.0, lift) \
		* Transform2D(0.0, -foot0)
	_put(_piece_rm, SH_KING + (1 if fallen else 0) + (2 if crowned else 0) + (4 if doze else 0), xf)

## The pieces' layer: every piece (lowest first, anything in the air over
## the rest), the dust, the win's crown and petals, the z's and a hint's
## ring. Rebuilt on every frame anything moves, from looks.
func _build_pieces(t: float) -> ArrayMesh:
	var s := _cell()
	var b := _lb
	_piece_rm.begin()
	var items: Array = []
	var kc := _centre(_state.king)
	var fall := -1.0 if _state.king % _state.w >= _state.w / 2 else 1.0
	var tip := 0.0
	var won := _solved_at >= 0.0
	var king_at := kc
	if won:
		var tu := 1.0 if Motion.reduce else clampf((t - _solved_at) / TOPPLE_TIME, 0.0, 1.0)
		tip = fall * TOPPLE * (1.0 if Motion.reduce else Motion.back_out(tu))
		# knocked aside as he goes over, so he lies beside your knight, not under it
		king_at = kc + Vector2(fall * s * KING_SHOVE * (1.0 - (1.0 - tu) * (1.0 - tu)), 0.0)
	var fallen := won and t >= _solved_at
	var doze := _doze(t)
	var dozing := doze >= 0.0 and doze > 0.12 and doze < 0.9
	if doze >= 0.0 and not won:
		tip = sin(PI * doze) * DOZE_NOD * fall
	var king_e := _entry(0, t)
	var crowned := not fallen
	items.append({"air": 0, "y": kc.y - 2.0, "fn": func(): _put_king(king_at, s, tip, king_e, fallen, crowned, dozing)})
	var you_now := _where(_you_a, t)
	for i in _foe_a.size():
		var a: Dictionary = _foe_a[i]
		var w := _where(a, t)
		if w.is_empty():
			continue
		var e: Vector2 = Motion.pop_in_scale(maxf(0.0, t - float(a.at))) if bool(a.pop) else Vector2.ONE * _entry(i + 1, t)
		var sq: Vector2 = e * _land_squash(float(w.land), t) * w.sq
		var look := -1.0 if not you_now.is_empty() and you_now.at.x < w.at.x else 1.0
		if bool(w.hopping):
			look = w.dir
		var eye := 1.0
		var tilt: float = w.tilt
		if _nap_at.has(i) and t >= float(_nap_at[i]):
			# fenced in: eyes shut, nodding off, breathing slow
			eye = 0.0
			var nod := 1.0 if Motion.reduce else minf(1.0, (t - float(_nap_at[i])) / 0.5)
			tilt += look * 0.12 * nod
			if not Motion.reduce:
				sq *= Vector2(1.0 + 0.015 * sin(t * 2.2 + i), 1.0 - 0.02 * sin(t * 2.2 + i))
		items.append({"air": 1 if float(w.lift) > 0.5 else 0, "y": w.at.y,
			"fn": func(): _put_knight(w.at, s, Piece.ROSE, look, w.lift, sq, false, tilt, eye)})
	for gn: Dictionary in _gone:
		var gs := t - float(gn.at)
		var gc := _centre(gn.c)
		if gs < 0.0:
			items.append({"air": 0, "y": gc.y, "fn": func(): _put_knight(gc, s, Piece.ROSE, -float(gn.dir))})
		elif gs < TAKE_TIME and not Motion.reduce:
			var u := gs / TAKE_TIME
			var d := float(gn.dir)
			var pos := gc + Vector2(d * s * 0.9 * u, 0.0)
			var lift := s * (1.0 * u - 0.55 * u * u)
			var k := 1.0 - u * u
			var spin := d * TUMBLE_SPIN * u
			# fading as it tumbles: drawn live, for the half second it takes
			items.append({"air": 2, "y": pos.y,
				"fn": func():
					Piece.knight(_lb, pos, s, Piece.ROSE, -d, lift, Vector2.ONE * (1.0 - 0.25 * u), false, k, spin, 1.0, true)
					_dizzy_stars(_lb, pos - Vector2(0.0, lift + s * 0.62), s, gs, k)})
	if not you_now.is_empty():
		var look := -1.0 if kc.x < you_now.at.x else 1.0
		if bool(you_now.hopping):
			look = you_now.dir
		var kn := _knocked(t)
		if kn > 0.0:
			var kd := float(_caught.dir)
			var pos: Vector2 = you_now.at + Vector2(kd * KNOCK * s * kn, 0.0)
			items.append({"air": 0, "y": you_now.at.y - 1.0,
				"fn": func(): _put_knight(pos, s, Piece.CREAM, -kd, 0.0, Vector2.ONE, false, kd * KNOCK_TILT * kn, 1.0, true)})
		else:
			var sh := Motion.shiver_offset(t - _bump_at) * 4.0
			var sq: Vector2 = Vector2.ONE * _entry(_foe_a.size() + 1, t) * _land_squash(float(you_now.land), t) * you_now.sq
			if not _press.is_empty() and not Motion.reduce:
				# ready to spring: a little crouch while the finger is down
				var pk := minf(1.0, (t - float(_press.at)) / PRESS_TIME) * PRESS_SQUASH
				sq *= Vector2(1.0 + pk * 0.6, 1.0 - pk)
			var lift: float = you_now.lift
			var tilt: float = you_now.tilt
			if fallen and not Motion.reduce:
				var v := (t - _solved_at - 0.05) / REAR_TIME
				if v > 0.0 and v < 1.0:
					tilt += -look * REAR * sin(PI * v)
					lift += s * 0.12 * sin(PI * v)
			var eye := _eye(t)
			var at: Vector2 = you_now.at + Vector2(sh, 0.0)
			items.append({"air": 1 if lift > 0.5 else 0, "y": you_now.at.y,
				"fn": func(): _put_knight(at, s, Piece.CREAM, look, lift, sq, fallen, tilt, eye)})
			if fallen:
				# the king's crown: off his head, up, and down onto yours
				var head := Piece.knight_head(at, s, look, lift, sq, tilt)
				var cu := 1.0 if Motion.reduce else clampf((t - _solved_at) / CROWN_FLY, 0.0, 1.0)
				var c0 := Piece.crown_seat(kc, s)
				var ce := cu * cu * (3.0 - 2.0 * cu)
				var cp := c0.lerp(head, ce) + Vector2(0.0, -sin(PI * cu) * CROWN_ARC * s)
				var ca := fall * TAU * (1.0 - ce) + tilt - look * 0.18 * ce
				var cs := lerpf(1.0, CROWN_ON, ce)
				items.append({"air": 2, "y": cp.y, "fn": func():
					_put(_piece_rm, SH_CROWN, Transform2D(ca, Vector2.ONE * cs * s / _ref_s, 0.0, cp))})
	items.sort_custom(func(p, q): return p.y < q.y if p.air == q.air else p.air < q.air)
	for it: Dictionary in items:
		it.fn.call()
	b = _lb
	_draw_dust(b, s, t)
	if doze >= 0.0 and not won:
		_draw_z(b, kc, s, doze, fall)
	_draw_nap_zs(b, s, t)
	if won:
		_draw_petals(b, s, t - _solved_at)
	_drop_rings(t)
	for r: Dictionary in _rings:
		var u := (t - float(r.at)) / Motion.RING_TIME
		if u >= 0.0 and u < 1.0:
			var rad := s * (0.3 + 0.4 * u)
			b.stroke(Face.Builder.ring(r.pos, rad, rad), s * 0.05 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)
	return _flush(_piece_rm)

## The ground under the pieces: the brambles or the trail, and the marks.
## Made again only while one of them moves (a bramble growing or withering,
## the marks fading in, a square pressed) or when what it shows changes;
## otherwise the last one is handed back -- a napping knight's breath
## rebuilds only the pieces.
func _build_ground(t: float) -> void:
	var s := _cell()
	var marks := not is_done() and not out_of_hearts and t >= _busy_until
	var legal: PackedInt32Array = _state.legal() if marks and _state.moves_left() != 0 else PackedInt32Array()
	var settled := _press.is_empty() and _wither.is_empty() and (not marks or Motion.reduce
		or t - _busy_until >= maxf(MARK_FADE, Motion.POP_IN + float(maxi(0, legal.size() - 1)) * 0.025))
	var route: PackedInt32Array = _state.route()
	var last := route.size()
	var you_now := _where(_you_a, t)
	if not you_now.is_empty() and t < float(you_now.land) and float(_you_a.arc) > 0.0:
		last -= 1
	if _state.brambles():
		for c in _grown:
			if not Motion.reduce and t - float(_grown[c]) < BRAMBLE_GROW:
				settled = false
	var key := [s, _origin(), route, last, _grown.keys(), _state.foes, marks, legal]
	if settled and _ground != null and key == _ground_key:
		return
	_ground_key = key if settled else []
	_ground_rm.begin()
	var rel := s / _ref_s
	if _state.brambles():
		for c in _grown:
			var e := t - float(_grown[c])
			if e < 0.0:
				continue
			var k := 1.0 if Motion.reduce else Motion.back_out(clampf(e / BRAMBLE_GROW, 0.0, 1.0))
			if k > 0.01:
				_put(_ground_rm, SH_BRAMBLE + int(c), Transform2D(0.0, Vector2.ONE * k * rel, 0.0,
					_centre(int(c)) + Vector2(0.0, s * 0.3)))
		for c in _wither.keys():
			var u := 1.0 if Motion.reduce else (t - float(_wither[c])) / WITHER_TIME
			if u >= 1.0:
				_wither.erase(c)
				continue
			# fading as it sinks: drawn live, for the moment it takes
			_bramble(_lb, _centre(int(c)), s, 1.0 - u * u, 1.0 - u, int(c))
	else:
		var hops := route.size() - 1
		for i in range(maxi(1, route.size() - TRAIL_HOPS), last):
			var d := Vector2i(route[i] % _state.w - route[i - 1] % _state.w, route[i] / _state.w - route[i - 1] / _state.w)
			var h := HOPS.find(d)
			if h >= 0:
				_put(_ground_rm, SH_TRAIL + h * TRAIL_HOPS + (hops - i),
					Transform2D(0.0, Vector2.ONE * rel, 0.0, _centre(route[i - 1])))
	if marks:
		var fade := 1.0 if Motion.reduce else clampf((t - _busy_until) / MARK_FADE, 0.0, 1.0)
		var reach: Dictionary = _state.reach()
		for q: int in reach:
			if q == _state.king:
				continue
			if fade >= 1.0:
				_put(_ground_rm, SH_REACH, Transform2D(0.0, Vector2.ONE * rel, 0.0, _centre(q)))
			else:
				_mark_reach(_lb, _centre(q), s, fade)
		for i in legal.size():
			var q: int = legal[i]
			var at := _centre(q)
			var e := 1.0 if Motion.reduce else maxf(0.05, Motion.pop_in_scale(maxf(0.0, t - _busy_until - float(i) * 0.025)).x)
			if not _press.is_empty() and int(_press.c) == q:
				e *= 1.35 if Motion.reduce else 1.0 + 0.35 * minf(1.0, (t - float(_press.at)) / PRESS_TIME)
			var kind := MARK_TAKE if q == _state.king or _foe_on(q) else MARK_RING if reach.has(q) else MARK_DOT
			if fade >= 1.0:
				_put(_ground_rm, SH_DOT + kind, Transform2D(0.0, Vector2.ONE * rel * e, 0.0, at))
			else:
				_mark_move(_lb, at, s, kind, e, fade)
	_ground = _flush(_ground_rm)

## A hop's hoofprints from `a` to `z`: the long leg of the L, then the short,
## a small horseshoe a step, alternating sides.
static func _hop_prints(b: Face.Builder, a: Vector2, z: Vector2, s: float, col: Color) -> void:
	var d := z - a
	var corner := a + Vector2(d.x, 0.0) if absf(d.x) > absf(d.y) else a + Vector2(0.0, d.y)
	var n := 0
	for leg in [[a, corner], [corner, z]]:
		var p0: Vector2 = leg[0]
		var p1: Vector2 = leg[1]
		var ln := p0.distance_to(p1)
		if ln <= 0.0:
			continue
		var dv := (p1 - p0) / ln
		var nrm := Vector2(-dv.y, dv.x)
		var steps := maxi(1, int(round(ln / (s * 0.34))))
		var first := 1 if leg[0] == a else 0
		for k in range(first, steps):
			var p := p0 + dv * (float(k) * ln / float(steps))
			var side := 1.0 if n % 2 == 0 else -1.0
			n += 1
			var base := dv.angle()
			b.stroke(Face.Builder.arc_points(p + nrm * side * s * 0.07, s * 0.052, base - PI * 0.68, base + PI * 0.68),
				s * 0.026, col)

## The prints of the hop `age` hops back from the last: older ones fainter.
static func _trail_col(age: int) -> Color:
	return Color(Pal.KNIGHT_CREAM_LINE, 0.3 - 0.07 * float(age))

## Rose corners in a square a rose knight reaches right now.
static func _mark_reach(b: Face.Builder, mid: Vector2, s: float, fade: float) -> void:
	var o := mid - Vector2.ONE * s * 0.5
	var col := Color(Pal.KNIGHT_REACH, 0.55 * fade)
	var gap := s * 0.1
	var tick := s * 0.16
	for cn: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var corner := o + Vector2(gap + cn.x * (s - 2.0 * gap), gap + cn.y * (s - 2.0 * gap))
		var dx := 1.0 if cn.x == 0.0 else -1.0
		var dy := 1.0 if cn.y == 0.0 else -1.0
		b.stroke(PackedVector2Array([corner + Vector2(0.0, dy * tick), corner, corner + Vector2(dx * tick, 0.0)]),
			s * 0.035, col)

## A square you can hop to: a sage dot, a rose ring where a rose knight
## reaches it, a big sage ring round a rose knight or the king you can take;
## `e` its pop.
static func _mark_move(b: Face.Builder, at: Vector2, s: float, kind: int, e: float, fade: float) -> void:
	if kind == MARK_TAKE:
		var r := s * 0.44 * e
		b.stroke(Face.Builder.ring(at, r, r), s * 0.05, Color(Pal.KNIGHT_MOVE, 0.85 * fade), true)
	elif kind == MARK_RING:
		var r := s * 0.13 * e
		b.stroke(Face.Builder.ring(at, r, r), s * 0.035, Color(Pal.KNIGHT_REACH, 0.7 * fade), true)
	else:
		b.disc(at, s * 0.13 * e, Color(Pal.KNIGHT_MOVE, 0.8 * fade))

## A landing's dust: little soft clouds puffing out from both sides of the
## plinth, rising a touch and fading.
func _draw_dust(b: Face.Builder, s: float, t: float) -> void:
	var keep: Array = []
	for d: Dictionary in _dust:
		var u := (t - float(d.at)) / DUST_TIME
		if u >= 1.0:
			continue
		keep.append(d)
		if u < 0.0:
			continue
		var e := 1.0 - (1.0 - u) * (1.0 - u)
		for side: float in [-1.0, 1.0]:
			for k in 3:
				var p: Vector2 = d.pos + Vector2(side * s * (0.26 + 0.2 * e + 0.07 * k), s * (0.32 - 0.03 * k - 0.07 * e))
				b.disc(p, s * (0.035 + 0.035 * e) * (1.0 - 0.22 * k), Color(Pal.KNIGHT_CREAM_DEEP, 0.6 * (1.0 - u)))
	_dust = keep

## The dozing king's z, two of them, drifting up and out as he nods.
func _draw_z(b: Face.Builder, kc: Vector2, s: float, doze: float, fall: float) -> void:
	for k in 2:
		var f := clampf(doze * 1.3 - float(k) * 0.3, 0.0, 1.0)
		if f <= 0.0 or f >= 1.0:
			continue
		var h := s * (0.08 + 0.05 * f) * (1.0 - 0.25 * k)
		var at := kc + Vector2(-fall * s * (0.28 + 0.12 * f), -s * (0.55 + 0.35 * f))
		var z := PackedVector2Array([at + Vector2(-h, -h), at + Vector2(h, -h), at + Vector2(-h, h), at + Vector2(h, h)])
		b.stroke(z, s * 0.022, Color(Pal.KNIGHT_ROSE_LINE, 0.75 * sin(PI * f)))

## The win's petals: drifting down over the board from above it, swaying,
## turning, fading as they go.
func _draw_petals(b: Face.Builder, s: float, since: float) -> void:
	if Motion.reduce or since < 0.0 or since >= PETAL_TIME + 0.6:
		return
	var o := _origin()
	var g := _grid_size()
	var cols := [Pal.FLOWER, Pal.FLOWER_TILE, Pal.KNIGHT_ROSE, Pal.CROWN]
	for i in PETALS:
		var h1 := fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin(float(i) * 78.233) * 12345.678, 1.0)
		var start := h2 * 0.6
		var u := (since - start) / PETAL_TIME
		if u <= 0.0 or u >= 1.0:
			continue
		var x := o.x + g.x * h1 + sin(u * TAU * 1.2 + float(i)) * s * 0.3
		var y := o.y - s * 0.4 + (g.y + s * 0.6) * u
		var ang := u * TAU * (0.6 + h2) + float(i)
		var r := s * (0.07 + 0.03 * h1)
		var pts := PackedVector2Array()
		for k in 12:
			var a := TAU * float(k) / 12.0
			pts.append(Vector2(x, y) + Vector2(cos(a) * r, sin(a) * r * (0.35 + 0.25 * abs(sin(u * 9.0 + float(i))))).rotated(ang))
		b.fan(pts, Color(cols[i % cols.size()], minf(1.0, (1.0 - u) * 2.5)))

## The toast over the foot of the card, fading in and out over
## Motion.DROP_FADE -- Rings' `_draw_toast`, in the card's own pixels and
## wrapped to the card's width. Never under the board's shake or entrance.
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
	if _stuck_btn != null and _stuck_btn.visible:
		# the Start over button holds the foot: the toast goes over the board
		mid.y = maxf(h * 0.5 + 8.0, _origin().y - FRAME - 12.0 - h * 0.5)
	draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var top := mid.y - h * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - w * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		draw_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		draw_multiline_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_CENTER, w - TOAST_PAD,
			TOAST_FONT, lines, Color(Pal.PAPER, alpha))

func _ring_at(at: Vector2, when: float) -> void:
	if Motion.reduce:
		return
	_rings.append({"pos": at, "at": when})
	_busy_for(when - _now() + Motion.RING_TIME)

func _drop_rings(t: float) -> void:
	var keep: Array = []
	for r: Dictionary in _rings:
		if t - float(r.at) < Motion.RING_TIME:
			keep.append(r)
	_rings = keep

# --- input ---

## A press on a square your knight can reach crouches it, ready; the hop
## goes on the release over that same square (a finger slid off takes it
## back). A tap on your own knight shows the first tip again; anywhere else
## on the board, a refusal.
func _gui_input(event: InputEvent) -> void:
	if _done or out_of_hearts:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		var c := _square_at(event.position)
		if event.pressed:
			_press = {}
			if c >= 0 and _state.legal().has(c) and _now() >= _busy_until:
				_press = {"c": c, "at": _now()}
				_refresh()
			return
		var pressed: Dictionary = _press
		_press = {}
		if c < 0:
			_refresh()
			return
		if not pressed.is_empty() and int(pressed.c) != c:
			_refresh()
			return
		if c == _state.you:
			_bump_at = _now()
			_say(tr(_tips()[0]), Face.Expr.HAPPY)
			_refresh()
		else:
			_play(c)

# --- the sprout's line ---

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

## An explanation of what just happened: the sprout's line (which no screen
## shows since the tip card left every board) and the toast, which one does.
## The rotating opening tips never come through here -- they would be noise.
func _tell(key: String, mood: int) -> void:
	_say(tr(key), mood)
	_toast = key
	_toast_at = _now()
	queue_redraw()

## A line about a lost heart, with how many are left after it.
func _tell_hearts(key: String) -> void:
	_tell(key, Face.Expr.WORRIED)
	if hearts > 0:
		_say(tr(key) + " " + (tr("SB_HEARTS_ONE") if hearts == 1 else tr("SB_HEARTS_N") % hearts), Face.Expr.WORRIED)

func _cycle_tip() -> void:
	if is_done() or _state.can_undo():
		return
	var tips := _tips()
	_tip_idx = (_tip_idx + 1) % tips.size()
	_say(tr(tips[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return _state.can_undo() and not is_done() and not out_of_hearts and not busy() \
		and _state.difficulty < 3

## Slides everything back to before your last kept hop. Counts no move.
func undo() -> bool:
	if not can_undo() or not _state.undo():
		return false
	_undo_ever = true
	_break_streak()
	_clear_gags()
	_slide_to_state(_now(), 0.0)
	_set_lost(_state.lost())
	_tell(STUCK_MSG if _lost else "KN_UNDONE", Face.Expr.STRAIN if _lost else Face.Expr.HAPPY)
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	return maxi(0, State.hints_for(_state.difficulty) + hints_extra - hints_used)

## Plays the next hop of the shortest line from here for you. From a lost
## position -- no line left -- it spends the hint rewinding to the last
## position that still had one instead.
func hint() -> bool:
	if is_done() or out_of_hearts or hints_left() <= 0 or busy():
		return false
	var m: int = _state.hint_move()
	if m < 0:
		if _state.rewind_to_live() > 0:
			hints_used += 1
			_break_streak()
			_slide_to_state(_now(), 0.0)
			_set_lost(false)
			_tell(REWOUND_MSG, Face.Expr.HAPPY)
			fx.cue("hint")
			moved.emit()
			return true
		_tell(STUCK_MSG, Face.Expr.STRAIN)
		fx.cue("refuse")
		return false
	hints_used += 1
	_ring_at(_centre(m), _now() + _jump())
	fx.cue("hint")
	_play(m, true)
	return true

func can_reset() -> bool:
	return not (is_done() or out_of_hearts or busy())

## Back to the opening, the brambles withering away. Hearts lost stay lost.
func reset_board() -> void:
	if not can_reset():
		return
	_break_streak()
	_clear_gags()
	_state.reset_board()
	_slide_to_state(_now(), Motion.RESET_STAGGER)
	_set_lost(false)
	_rings = []
	_solved_at = -1.0
	_toast = ""
	_toast_at = -100.0
	moves = 0
	_running = true
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	fx.cue("reset")
	moved.emit()

func _on_start_over() -> void:
	reset_board()

## Whether a catch or a boxed-in ending is still playing out: input, Undo,
## Hint and Reset wait, and the host holds its hint video.
func busy() -> bool:
	return _now() < _busy_until

func is_solved() -> bool:
	return _state.is_solved()

## The shape of the day and never its answer: you, a rose each, the crown;
## Brambles and Flawless when earned.
func share_glyphs() -> String:
	var out := "🐴" + "🌹".repeat(_state.foes.size()) + "👑"
	if _state.brambles() and is_solved():
		out += " 🌿 " + tr("KN_BRAMBLE_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless:
		out += " 🏅 " + tr("BN_FLAWLESS")
	return out

## What a reopened daily needs: the hearts kept and whether it was flawless.
func completion_record() -> Dictionary:
	return {"hearts": hearts, "flawless": _flawless}

# --- lost positions and the Start over button ---

## The naps drawn follow the state: one gone after a take is undone or
## slid back comes back asleep, and a restored day shows its nappers.
func _sync_naps() -> void:
	for i in _state.foes.size():
		if _state.napping(i):
			if not _nap_at.has(i):
				_nap_at[i] = AGO
		else:
			_nap_at.erase(i)

## Whether a rose knight (napping or not) stands on `c`.
func _foe_on(c: int) -> bool:
	for i in _state.foes.size():
		if _state.foe_square(i) == c:
			return true
	return false

func _set_lost(v: bool) -> void:
	if v and not _lost:
		_stuck_at = _now()
	_lost = v
	_place_stuck()

## The Start over button, centred under the board, popping in once the
## position is known lost and gone the moment it is not.
func _place_stuck() -> void:
	if _stuck_btn == null:
		return
	var show := _lost and not is_done() and not out_of_hearts and _cell() > 0.0
	if not show:
		_stuck_btn.visible = false
		return
	var was := _stuck_btn.visible
	_stuck_btn.visible = true
	_stuck_btn.size = _stuck_btn.get_combined_minimum_size()
	var w := _stuck_width()
	_stuck_btn.size = Vector2(w, STUCK_H)
	_stuck_btn.position = _stuck_spot(w)
	_stuck_btn.pivot_offset = _stuck_btn.size * 0.5
	if not was and not Motion.reduce:
		_stuck_btn.scale = Vector2.ONE * 0.6
		var tw := _stuck_btn.create_tween()
		tw.tween_property(_stuck_btn, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# and a little nudge a moment later, so the eye finds it
		tw.tween_interval(1.4)
		tw.tween_property(_stuck_btn, "scale", Vector2.ONE * 1.06, 0.12)
		tw.tween_property(_stuck_btn, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## How wide the Start over button is: its own width, or most of the card's.
func _stuck_width() -> float:
	return maxf(_stuck_btn.get_combined_minimum_size().x, minf(size.x - 80.0, 420.0))

## Where the Start over button `w` wide stands: centred under the board.
func _stuck_spot(w: float) -> Vector2:
	var top := _origin().y + _grid_size().y + FRAME + STUCK_DROP
	return Vector2((size.x - w) * 0.5, minf(top, size.y - STUCK_H - 12.0))

# --- the brambles and the naps ---

## A bramble on every square your knight has left: a low thorny mound of
## leaves with a few curling canes and thorns and one small wild rose,
## springing up over BRAMBLE_GROW as your knight takes off; withering ones
## sink and fade.
func _draw_brambles(b: Face.Builder, s: float, t: float) -> void:
	for c in _grown:
		var e := t - float(_grown[c])
		if e < 0.0:
			continue
		var k := 1.0 if Motion.reduce else Motion.back_out(clampf(e / BRAMBLE_GROW, 0.0, 1.0))
		_bramble(b, _centre(int(c)), s, k, 1.0, int(c))
	for c in _wither.keys():
		var u := 1.0 if Motion.reduce else (t - float(_wither[c])) / WITHER_TIME
		if u >= 1.0:
			_wither.erase(c)
			continue
		_bramble(b, _centre(int(c)), s, 1.0 - u * u, 1.0 - u, int(c))

static func _bramble(b: Face.Builder, at: Vector2, s: float, k: float, alpha: float, seed_c: int) -> void:
	if k <= 0.01:
		return
	var h := fposmod(sin(float(seed_c) * 12.9898) * 43758.5453, 1.0)
	var foot := at + Vector2(0.0, s * 0.3)
	Scenery.soft_disc(b, foot, s * 0.36 * k, s * 0.07, Color(Pal.TEXT, 0.16 * alpha))
	var deep := Color(Pal.LEAF_DEEP, alpha)
	var leaf := Color(Pal.LEAF, alpha)
	# the mound: overlapping leafy blobs, deep ones behind
	var blobs := [Vector2(-0.22, -0.02), Vector2(0.2, 0.0), Vector2(0.0, -0.14), Vector2(-0.1, 0.06), Vector2(0.12, 0.07)]
	for i in blobs.size():
		var bp: Vector2 = foot + (blobs[i] * Vector2(1.0, 1.0) + Vector2(0.0, -0.12)) * s * k
		b.disc(bp, s * (0.16 if i < 3 else 0.13) * k, deep if i < 3 else leaf)
	b.disc(foot + Vector2(-0.05, -0.2) * s * k, s * 0.1 * k, leaf)
	# canes curling out of the mound with thorns along them
	for side: float in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for j in 7:
			var f := float(j) / 6.0
			var a := PI * (0.55 + side * 0.25) + side * f * 1.6
			pts.append(foot + Vector2(-0.0, -0.18) * s * k + Vector2(side * f * 0.34, -sin(f * PI) * 0.22 - f * 0.06) * s * k
				+ Vector2.from_angle(a) * 0.0)
		b.stroke(pts, maxf(1.5, s * 0.03 * k), Color(Pal.CHESS_FRAME_DEEP, alpha))
		for j in [2, 4]:
			var p: Vector2 = pts[j]
			var tip := p + Vector2(side * 0.03, -0.06).normalized() * s * 0.06 * k
			b.polygon(PackedVector2Array([p + Vector2(-0.015, 0.0) * s * k, tip, p + Vector2(0.015, 0.0) * s * k]),
				Color(Pal.CHESS_FRAME_DEEP, alpha))
	# one small wild rose, on a side picked off the square
	var rp := foot + Vector2((h - 0.5) * 0.3, -0.26) * s * k
	for i in 5:
		var a := TAU * float(i) / 5.0 + h
		b.disc(rp + Vector2.from_angle(a) * s * 0.05 * k, s * 0.045 * k, Color(Pal.FLOWER_TILE, alpha))
	b.disc(rp, s * 0.03 * k, Color(Pal.CROWN, alpha))

## Each napping rose knight's z's, rising and drifting off its ear, one every
## Z_EVERY; a single still z under reduce motion.
func _draw_nap_zs(b: Face.Builder, s: float, t: float) -> void:
	if is_done():
		return
	for i in _nap_at:
		if t < float(_nap_at[i]) or int(_foe_a[i].to) < 0:
			continue
		var at := _centre(int(_foe_a[i].to)) + Vector2(s * 0.18, -s * 0.62)
		if Motion.reduce:
			_z(b, at, s * 0.09, 0.75)
			continue
		var e := t - float(_nap_at[i])
		for k in 3:
			var age := fmod(e - float(k) * Z_EVERY, Z_EVERY * 3.0)
			if e - float(k) * Z_EVERY < 0.0 or age > Z_LIFE:
				continue
			var u := age / Z_LIFE
			var p := at + Vector2(sin(u * 5.0 + float(k)) * s * 0.06 + u * s * 0.15, -u * s * 0.55)
			_z(b, p, s * (0.06 + 0.05 * u), sin(PI * u) * 0.8)

static func _z(b: Face.Builder, at: Vector2, h: float, alpha: float) -> void:
	var z := PackedVector2Array([at + Vector2(-h, -h), at + Vector2(h, -h), at + Vector2(-h, h), at + Vector2(h, h)])
	b.stroke(z, maxf(2.0, h * 0.32), Color(Pal.MOON_DEEP, alpha))

## A taken knight's dizzy stars: three little gold stars circling over it.
func _dizzy_stars(b: Face.Builder, at: Vector2, s: float, e: float, alpha: float) -> void:
	for k in STARS:
		var a := e * 9.0 + TAU * float(k) / float(STARS)
		var p := at + Vector2(cos(a) * s * 0.22, sin(a) * s * 0.07)
		b.polygon(Seal.star(p, s * 0.06), Color(Pal.CROWN, alpha * (0.6 + 0.4 * sin(a))))

# --- hearts ---

## A heart splits off the pill at `at`; the last one sets out_of_hearts.
func _lose_heart(at: float) -> void:
	_lost_ever = true
	hearts = maxi(0, hearts - 1)
	_split_index = hearts
	_split_at = at
	if hearts <= 0:
		out_of_hearts = true
		_set_lost(false)
	_heart_layer.queue_redraw()

func _draw_hearts() -> void:
	if max_hearts <= 0 or _cell() <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var y := maxf(HEART_TOP + HEART_PILL_PAD.y + HEART_R,
		_origin().y - FRAME - HEART_PILL_PAD.y - HEART_R - 10.0)
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var c := _hearts_at(pill, y)
	y = c.y
	var left := c.x - pill.x * 0.5
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
	_heart_layer.draw_set_transform(c * (1.0 - enter), 0.0, Vector2.ONE * enter)
	_heart_layer.draw_mesh(_hearts_shown, null)
	_heart_layer.draw_set_transform(Vector2.ZERO)

## The hearts' pill's centre: over the board, centred (the tutorial's page
## hangs it beside the board).
func _hearts_at(_pill: Vector2, y: float) -> Vector2:
	return Vector2(size.x * 0.5, y)

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

## The last heart is gone: dusk falls on the garden table, the pieces nod
## off, and the out-of-hearts card comes up.
func _run_out() -> void:
	if _asleep or not out_of_hearts or is_done():
		return
	_asleep = true
	_press = {}
	_break_streak()
	_clear_gags()
	_tip_timer.stop()
	_set_lost(false)
	fx.cue("out_of_hearts")
	_say(tr("KN_OUT"), Face.Expr.SLEEPY)
	_dusk_toward(DUSK)
	_refresh()
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

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
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["KN_OUT_BODY", "KN_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same board at its opening, every heart back, the clock and
## the moves from zero. Hints spent stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	_gen += 1
	_state.reset_board()
	var withering := _grown.duplicate()
	_deal()
	var t := _now()
	for c in withering:
		_wither[c] = t
	_slide_from_dusk()
	_break_streak()
	_clear_gags()
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

## Try again's pieces: a gentle pop back onto their opening squares.
func _slide_from_dusk() -> void:
	var t := _now()
	_you_a = {"from": _state.you, "to": _state.you, "at": t, "dur": 0.001, "arc": 0.0, "pop": true}
	for i in _foe_a.size():
		var c := _state.foe_square(i)
		_foe_a[i] = {"from": c, "to": c, "at": t + Motion.stagger(i + 1, Motion.RESET_STAGGER * 3.0),
			"dur": 0.001, "arc": 0.0, "pop": true}
	_busy_for(maxf(WITHER_TIME, Motion.POP_IN + 0.3))

## One more heart (the card's video): once a board. Morning comes back, and
## a board left boxed in withers back to the opening.
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
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	if _state.brambles() and _state.trapped():
		_state.reset_board()
		_slide_to_state(now, Motion.RESET_STAGGER)
	elif not _state.brambles():
		_set_lost(_state.lost())
	_heart_layer.queue_redraw()
	_refresh()
	_say(tr("KN_HEART_BACK"), Face.Expr.HAPPY)
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

## Runs `what` after `delay`, unless the board has been dealt again meanwhile.
func _after(delay: float, what: Callable) -> void:
	if not is_inside_tree():
		return
	var gen := _gen
	if delay <= 0.0:
		what.call()
		return
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

# --- the rewards ---

func _reset_rewards() -> void:
	_streak = 0
	_streak_gen += 1
	_hops = 0
	_gag_until = 0.0
	_gag_gen += 1
	_combo_n = 0
	_combo_at = -INF
	_combo_out_at = -INF
	_love = []
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
	return absi(hash([_state.w, _state.king, int(_state.g.you), _state.foes.size()]))

## A kept hop that was not a hint: the streak grows -- a note up the
## pentatonic from the second, the bubble over your knight from the third,
## confetti at 4, 7 and every 5 -- and the gag picked for it plays.
func _on_safe_hop(to: int, land: float, gag: int) -> void:
	_streak += 1
	var count := _streak
	var gen := _streak_gen
	var at := _centre(to)
	var wait := maxf(0.0, land - _now())
	if count >= 2:
		var step: int = COMBO_STEPS[mini(count - 2, COMBO_STEPS.size() - 1)]
		_after(wait + 0.05, func() -> void:
			if gen == _streak_gen:
				fx.cue("combo", pow(2.0, step / 12.0), COMBO_DB))
	if count >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = count
		_combo_pos = at - Vector2(0.0, _cell() * 0.55)
		_combo_at = land
		_combo_out_at = -INF
	if _confetti_at(count) and not Motion.reduce:
		_after(wait, func() -> void:
			if gen == _streak_gen:
				fx.confetti(at, 22)
				fx.cue("confetti"))
	_start_gag(to, gag, land)
	_life_layer.queue_redraw()

static func _confetti_at(count: int) -> bool:
	return count == 4 or count == 7 or (count >= 10 and count % 5 == 0)

## The gag for the next kept hop, off the day's hash: one in GAG_ODDS, never
## while one is still on.
func _pick_gag() -> int:
	_hops += 1
	var t := _now()
	if Motion.reduce or t < _gag_until or force_gag == Gag.NONE:
		return Gag.NONE
	if force_gag >= 0:
		return force_gag
	var roll := posmod(_day_hash() + _hops * GAG_STEP, GAG_SPAN)
	if roll >= GAG_SPAN / GAG_ODDS:
		return Gag.NONE
	return roll % 3

## The streak ends: a catch, boxed in, an undo, a hint, a reset, the hearts
## running out. The bubble deflates.
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
	_flies = []
	_gag_until = 0.0
	_gag_gen += 1
	if _life_layer != null:
		_life_layer.queue_redraw()

## The gag for a hop to `c`: the somersault is the hop itself (`_where`);
## love hearts float off your knight as it lands; or a butterfly flutters
## in, sits on its ear a moment and flies off.
func _start_gag(c: int, gag: int, lands: float) -> void:
	if gag == Gag.NONE:
		return
	var wait := maxf(0.0, lands - _now())
	var gg := _gag_gen
	var at := _centre(c)
	var cue := ""
	match gag:
		Gag.FLIP:
			_gag_until = lands + 0.3
			_after(wait, func() -> void:
				if gg == _gag_gen and not Motion.reduce:
					fx.sparkle(at - Vector2(0.0, _cell() * 0.3), Pal.SUN))
			return
		Gag.LOVE:
			for k in LOVE_HEARTS:
				_love.append({"at": at + Vector2(float(k - 1) * 0.28, -0.45) * _cell(),
					"t": lands + 0.12 * float(k), "phase": float(k) * 2.1})
			cue = "love"
			_gag_until = lands + 0.24 + LOVE_TIME
		Gag.BUTTERFLY:
			_flies.append({"t": lands, "from": -1.0 if at.x > size.x * 0.5 else 1.0})
			cue = "flutter"
			_gag_until = lands + FLY_IN + FLY_SIT + FLY_OUT
	_after(wait, func() -> void:
		if gg == _gag_gen:
			fx.cue(cue))

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("KN_WIN")}

## The win screen waits for your knight to land, the king to fall, the crown
## to find your head and the party to have its moment.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	var fall := maxf(0.0, _solved_at - _now()) + WIN_WAIT
	var party := maxf(0.0, _party_at - _now()) + PARTY_TIME if _party_at < INF else fall
	return maxf(fall, party)

func _on_solved() -> void:
	var t := _now()
	_solved_at = maxf(t, float(_you_a.at) + float(_you_a.get("crouch", 0.0)) + float(_you_a.dur))
	_tip_timer.stop()
	_press = {}
	_set_lost(false)
	# Flawless: no hint, and no heart lost on Hard and Insane, or never an
	# Undo on Easy and Medium.
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 else not _undo_ever)
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = t
	_streak_gen += 1
	_clear_gags()
	var kc := _centre(_state.king)
	if not Motion.reduce:
		_later(_solved_at - t, func():
			fx.sparkle(kc, Pal.SUN)
			fx.ring(kc, _cell() * 0.6)
			fx.puff(kc + Vector2(0.0, _cell() * 0.25), Pal.KNIGHT_ROSE, 6)
			fx.cue("solved"))
		_later(_solved_at - t + 0.2, func(): fx.sparkle(kc, Pal.CROWN))
		_later(_solved_at - t + CROWN_FLY, func():
			fx.sparkle(kc - Vector2(0.0, _cell() * 0.5), Pal.CROWN)
			fx.cue("crown"))
	else:
		fx.cue("solved")
	_busy_for(_solved_at - t + maxf(TOPPLE_TIME, PETAL_TIME + 0.6))
	_say(tr("KN_WIN"), Face.Expr.JOY)
	_heart_layer.queue_redraw()
	_party()
	_refresh()

## A reopened daily that was already solved: the day's line replayed through
## the state, your knight on the king's square wearing his crown, the king
## already fallen, the cat asleep and the seal. Never check_solved():
## `solved` must not fire twice.
func restore_completed_board() -> void:
	_gen += 1
	_close_card()
	_deal()
	_reset_rewards()
	hearts = clampi(int(completed_record.get("hearts", max_hearts)), 0, max_hearts)
	_flawless = bool(completed_record.get("flawless", false))
	_state.reset_board()
	for m in _state.g.line:
		_state.play(m)
	_snap_to_state()
	var t := _now()
	_solved_at = t - 100.0
	_opened = t - 100.0
	_cat_at = t - 100.0
	_place_cat(t)
	if _flawless or _state.brambles():
		_stamp_at = t - 100.0
	_tip_timer.stop()
	_say(tr("KN_WIN"), Face.Expr.JOY)
	_heart_layer.queue_redraw()
	_life_layer.queue_redraw()
	_refresh()

# --- the party ---

## After the king falls and the crown lands: confetti twice, the nap cat
## hopping onto the frame's foot and curling up, a bit of knightly wisdom,
## and the seal when the solve earned one (flawless, or any Brambles). Under
## reduce motion the cat and the seal are simply there.
func _party() -> void:
	var now := _now()
	var lead := 0.0 if Motion.reduce else maxf(0.0, _solved_at - now) + CROWN_FLY + PARTY_AT
	_party_at = now + lead
	_after(lead + 0.8, func() -> void:
		_say(_cheer(), Face.Expr.JOY))
	_cat_at = now if Motion.reduce else _party_at + CAT_AT
	if _flawless or _state.brambles():
		_stamp_at = now if Motion.reduce else _party_at + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
	if Motion.reduce:
		_life_layer.queue_redraw()
		return
	var field := _field_rect()
	_after(lead + 0.1, func() -> void:
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell() * 0.5), 30, field.size.x * 0.9)
		fx.cue("party"))
	_after(lead + 0.7, func() -> void:
		fx.confetti(field.get_center(), 24, field.size.x * 0.7))
	_life_layer.queue_redraw()

func _cheer() -> String:
	return tr("KN_CHEER_%d" % posmod(_day_hash(), CHEERS))

func _field_rect() -> Rect2:
	return Rect2(_origin(), _grid_size())

func _frame_rect() -> Rect2:
	return _field_rect().grow(FRAME)

# --- the nap cat ---

func _cat_px() -> float:
	return size.x * CAT_PX

## Where she curls up: on the frame's foot, a fifth of the way along from its
## left (the seal takes the right).
func _cat_spot() -> Vector2:
	var box := _frame_rect()
	var f := 0.46 if _seal_left() else 0.22
	return Vector2(box.position.x + box.size.x * f, box.end.y - _cat_px() * 0.3)

func _cat_start() -> Vector2:
	var box := _frame_rect()
	var x := box.end.x - _cat_px() * 0.5 if _seal_left() else box.position.x + _cat_px() * 0.5
	return Vector2(x, box.end.y - _cat_px() * 0.3)

## The win happens on the king's square: when that is in the board's lower
## right quarter, where the seal goes, the seal takes the lower left corner
## and the cat the right, so neither covers your crowned knight.
func _seal_left() -> bool:
	var w: int = _state.w
	return w > 0 and _state.king % w >= w / 2 and _state.king / w >= w / 2

func _cat_walk() -> float:
	return CAT_POP + CAT_HOPS * CAT_HOP_TIME

func _place_cat(t: float) -> void:
	if t < _cat_at or _cell() <= 0.0:
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

# --- the life over the board ---

func _tick_life(now: float) -> bool:
	_love = _love.filter(func(l): return now < float(l.t) + LOVE_TIME)
	_flies = _flies.filter(func(f): return now < float(f.t) + FLY_IN + FLY_SIT + FLY_OUT)
	return not (_love.is_empty() and _flies.is_empty()) \
		or (_combo_n >= COMBO_FROM and (now - _combo_at < COMBO_HOLD + 0.1 or _combo_out_at > -INF)) \
		or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1)

## Love hearts (one cached mesh through a transform each), the butterfly
## (one mesh a frame), the seal and the streak's bubble with their words.
func _draw_life() -> void:
	if _cell() <= 0.0 or _state.size() == 0:
		_life_shown = []
		return
	var now := _now()
	var shown: Array = []
	var s := _cell()
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
	if not _flies.is_empty():
		var b := Face.Builder.new()
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
		var r := maxf(12.0, _cell() * LOVE_R)
		b.polygon(_heart(Vector2.ZERO, r * 1.15, 0), Pal.FLOWER_DEEP)
		b.polygon(_heart(Vector2.ZERO, r, 0), Pal.FLOWER)
		b.ellipse(Vector2(-0.45, -0.45) * r, 0.18 * r, 0.1 * r, Color(1.0, 1.0, 1.0, 0.5))
		_love_mesh = b.mesh()
	return _love_mesh

## A butterfly's visit: in on a curve from the card's side, a rest on your
## knight's ear (following it if it hops away), and off up the other way.
func _fly(b: Face.Builder, f: Dictionary, now: float) -> void:
	var e := now - float(f.t)
	if e <= 0.0:
		return
	var s := _cell()
	var you_now := _where(_you_a, now)
	if you_now.is_empty():
		return
	var look := -1.0 if _centre(_state.king).x < you_now.at.x else 1.0
	var spot := Piece.knight_head(you_now.at, s, look, float(you_now.lift)) + Vector2(0.0, -s * 0.05)
	var side: float = f.from
	var at := spot
	var beat := 0.3 + 0.7 * absf(sin(e * 14.0))
	var lean := 0.0
	if e < FLY_IN:
		var u := e / FLY_IN
		var from := spot + Vector2(side * s * 3.0, -s * 2.2)
		at = from.lerp(spot, 1.0 - (1.0 - u) * (1.0 - u)) + Vector2(0.0, -sin(PI * u) * s * 0.5)
		lean = -side * 0.3
	elif e < FLY_IN + FLY_SIT:
		var w := e - FLY_IN
		beat = 0.25 + 0.5 * absf(sin(w * 3.0))
	else:
		var u := (e - FLY_IN - FLY_SIT) / FLY_OUT
		var to := spot + Vector2(-side * s * 2.8, -s * 3.4)
		at = spot.lerp(to, u * u) + Vector2(sin(u * 14.0) * s * 0.08, 0.0)
		lean = side * 0.3
	Cat.butterfly(b, at, s * 0.36, beat, lean)

func _draw_combo(now: float, shown: Array) -> void:
	if _combo_n < COMBO_FROM:
		return
	var k := 1.0
	var alpha := 1.0
	if _combo_out_at == -INF and now - _combo_at >= COMBO_HOLD:
		_combo_out_at = now
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

## The seal on the frame's lower right corner, dropping in and settling, its
## words over it: Flawless; on Brambles "Insane" over Flawless or Brambles,
## on the night seal.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := size.x * STAMP_R * 0.75
	var insane: bool = _state.brambles()
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
	var corner := box.end
	var centre := corner - Vector2(rad * 0.85, rad * 0.72)
	if _seal_left():
		centre.x = box.position.x + rad * 0.85
	centre.x = clampf(centre.x, rad * 1.08, size.x - rad * 1.08)
	centre.y = minf(centre.y, size.y - rad * 1.02)
	var xf := Transform2D(-STAMP_TILT if _seal_left() else STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless else tr("KN_BRAMBLE_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
