extends "res://core/puzzle_base.gd"

## Golden Acorn as a flat board: a quiz. A card of paper holds the question;
## under it stand four answers on wooden plates, lettered A to D. A tap picks
## one, a second tap on it (or Lock) makes it final, and after a held breath the right plate turns
## leaf green -- with the picked one in berry beside it when they differ --
## and a line under the question says why. A few questions make the day; the
## Climb (Insane) is ten that rise, with hearts.
##
## The rules are in puzzles/acorn_state.gd, which this only draws. The day's
## questions are written by a model and published by the backend
## (server/functions/src/acorn.ts); a daily reads them through core/backend.gd
## once its host has said which day it is, and everything else -- no network,
## a board dealt from New, a probe -- is dealt from the bank in
## content/acorn.json. docs/agents/boards/golden-acorn.md has the reasons.
##
## How it is drawn. `_still` is the card and the question's paper (a layout).
## `_live` is the four plates with their letters and marks, rebuilt only on a
## frame something moves. The words -- the question, the answers, the why,
## the pills -- are a layer of their own over both.
##
## How it moves. The flat boards' vocabulary (core/motion.gd,
## docs/art/flat-motion.md) read as curves: the plates pop in one after
## another, the pressed one sinks, the picked one bumps. This board's own: the
## held breath between a lock and its answer, and the wrong plate's shiver.
##
## The oak is the whole screen (2026-10-13, the registry's `bleed`):
## puzzles/acorn_world.gd lies edge to edge as the board's first child from
## the first `set_clear`, and the pills, the paper and the plates are laid
## in the span the host's rows leave, on its side margin, with no card of
## their own under them. Until it is told a clear (the tutorial's Stage, a
## probe) the board lays itself in its card as before. On the win it slides
## and shrinks into the win's span under its own one transform, the oak
## held still against it.

const State = preload("res://puzzles/acorn_state.gd")
const Art = preload("res://ui/faces/acorn_art.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const Seal = preload("res://ui/flat/seal.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Backend = preload("res://core/backend.gd")
const World = preload("res://puzzles/acorn_world.gd")
const StarLine = preload("res://ui/flat/star_line.gd")
const Progress = preload("res://core/progress.gd")
## Kept once the player has locked a plate by tapping it again: the tip stops.
const TAP_LEARNT := "acorn_tap_lock"
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
const FLAT_HOST := "res://ui/flat/flat_host.gd"
## The slide into the win's span (the host's SLOT_TIME), and the air kept
## round the block inside it.
const WIN_SLIDE := 0.45
const WIN_PAD := 28.0

# --- the card ---
const PAD := 30.0
## The strip the pills stand in over the question.
const HUD_ROW := 76.0
## The card is never taller than this many times its width.
const CARD_TALL := 1.22
const CARD_RADIUS := 26.0
const CARD_EDGE := 6.0
## The question's paper takes this share of what the pills leave.
const PANEL_SHARE := 0.4
const PANEL_RADIUS := 24.0
## The strip at the paper's head for the subject, and at its foot for the why.
const CAT_H := 54.0
const WHY_H := 92.0
const PLATE_GAP := 14.0
const PLATE_RADIUS := 22.0
const PLATE_LIP := 5.0
## The letter's disc, as a share of a plate's height.
const LETTER_R := 0.3
const LETTERS := "ABCD"

const Q_FONTS := [46, 42, 38, 34, 30, 27]
const A_FONTS := [38, 34, 30, 27, 24]
const CAT_FONT := 24
const WHY_FONT := 27
const LETTER_FONT := 34
const PILL_FONT := 32
const PILL_H := 50.0

# --- motion: what is this board's own ---
## The breath held between a lock and its answer.
const HOLD := 0.6
## The why comes once the answer has been seen.
const WHY_AT := 0.35
## A question's plates leave, and the next one's come.
const SWAP_OUT := 0.16
const PLATE_STAGGER := 0.06
## The last heart's answer is read before the card comes.
const CARD_AFTER := 2.6
const CARD_AFTER_STILL := 0.8
## How long a slow network is waited on before the bank deals instead.
const FETCH_WAIT := 4.0
const WIN_WAIT := 0.9
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_TILT := -0.22
const TOAST_HOLD := 2.4
## An answer picked and an answer locked are heard a dozen times a day, so
## neither is the same tock twice (they were 1.0 every time).
const TICK_VARY := Vector2(0.94, 1.06)
## A second tap on the lit plate locks it ("are you sure?" asked by the
## finger), but not one that lands this soon after the pick: a jittery
## double tap must not lock what it only meant to pick.
const ARM := 0.3
## A run of rights climbs: each right answer's notes a step higher, up to
## RUN_STEPS steps, and its sparkle the fuller.
const RUN_PITCH := 0.05
const RUN_STEPS := 5
## The run is cheered from three in a row, on a word that rises off the plate.
const RUN_CHEER := 3
const CHEER_TIME := 1.3
const CHEER_RISE := 70.0
const CHEER_FONT := 46
## The acorn a right answer earns flies from its plate to the count.
const FLIGHT := 0.5
const STAR_SCALE := 0.9
const TOAST_H := 76.0
const TOAST_PAD := 72.0
const TOAST_RADIUS := 26.0
const TOAST_FONT := 30

## What the phone does under each cue (docs/agents/haptics.md). A pick is
## the faintest tap; a lock is a knock; the answer is felt by what it was.
const HAPTICS := {
	"pick": Haptics.TICK,
	"lock": Haptics.BUMP,
	"right": Haptics.GOOD,
	"wrong": Haptics.WARN,
	"next": Haptics.TICK,
	"hint": Haptics.GOOD,
	"refuse": Haptics.TAP,
	"heart_lost": Haptics.BAD,
	"heart_back": Haptics.GOOD,
	"out_of_hearts": Haptics.LOSE,
	"solved": Haptics.WIN,
}

enum Phase { WAIT, PLAY, REVEAL, SWAP }

var state = State.new()
## Back to camp from the out-of-hearts card; the host listens for it.
signal leave

var fx: Node2D
## Insane's hearts, by the names the host and the card already read.
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
var _heart_card: Control
var _heart_at := -INF
var _tries := 0

## The oak, once the host has said what its rows cover (`set_clear`), and
## what they cover of the rect, top and bottom, while playing and on the win.
var _world: Control
var _bled := false
var _clear_rows := Vector2.ZERO
var _win_clear := Vector2.ZERO
var _won := false
## The board's own transform on the win: the block's middle while playing,
## how far it moves and how small it gets, and how far along it is.
var _slid_from := Vector2.ZERO
var _slid_by := Vector2.ZERO
var _slid_scale := 1.0
var _slid := 0.0
var _placed := false
## The host's slide on a change of level (set_shift).
var _shift := 0.0
var _slide_tw: Tween
## Asked to arrive whole (skip_entrance) before the deal has begun.
var _skip_enter := false

var _card := Rect2()
var _panel := Rect2()
var _plates: Array[Rect2] = []
## Bumped on every rebuild; a pending callback from the last board checks it.
var _gen := 0
var _phase := Phase.WAIT
## What build() was handed, kept for the deal that follows it.
var _seed_key := 0
var _dealt := false
var _settled := false
## The shown place picked and not yet locked, -1 for none.
var _picked := -1

var _still: ArrayMesh
var _live: ArrayMesh
var _live_dirty := true
## The meshes the last _draw handed over (docs/agents/flat-screens.md: a
## canvas command holds a mesh by RID).
var _shown: Array = []
var _hud_layer: Control
var _hud_shown: Array = []
var _seal_mesh: ArrayMesh
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""

# --- the finger ---
var _down := -1
var _down_at := -INF
var _up := -1
var _up_at := -INF

# --- the clocks ---
var _opened := -1.0e9
var _round_at := -1.0e9
var _pick_at := -INF
var _lock_at := -INF
var _swap_at := -INF
var _cut_at := -INF
var _anim_until := 0.0
var _pill_bump := [-INF, -INF]
var _stamp_at := INF
var _toast := ""
var _toast_at := -100.0
## Three stars on the pill row, falling as wrong answers come (not the Climb:
## its hearts say the same).
var _stars := StarLine.new()
## The word a run is cheered with, the plate it rises off and when.
var _cheer := ""
var _cheer_at := -INF
var _cheer_from := Vector2.ZERO
## The acorn flying to the count, from where.
var _flight_at := -INF
var _flight_from := Vector2.ZERO
## The first pick of a board says a second tap locks it, until the player
## has once locked that way (TAP_LEARNT).
var _told_tap := false

func puzzle_id() -> String: return "acorn"
func title() -> String: return "Golden Acorn"

func rules() -> String:
	var out := tr("AC_RULES") % State.ASKS[state.band]
	var hints: int = State.HINTS_BY[state.band]
	if hints > 0:
		out += "\n\n" + (tr("AC_RULES_BULB_ONE") if hints == 1 else tr("AC_RULES_BULB_N") % hints)
	if State.HEARTS_BY[state.band] == 0:
		out += "\n\n" + tr("AC_RULES_STARS")
	if State.HEARTS_BY[state.band] > 0:
		out += "\n\n" + tr("AC_RULES_CLIMB") % State.HEARTS_BY[state.band]
	return out

## The tutorial: each page is the board itself on a hand-picked question
## (ui/hud/acorn_tutorial_diagram.gd). Loaded, not preloaded: the page's
## board extends this script.
func tutorial_pages() -> Array:
	var path := "res://ui/hud/acorn_tutorial_diagram.gd"
	if not ResourceLoader.exists(path):
		return []
	var Diagram = load(path)
	var hints: int = State.HINTS_BY[state.band]
	var lives: int = State.HEARTS_BY[state.band]
	var steps := [
		[Diagram.Lesson.PICK, "HTP_AC_PICK", tr("HTP_AC_PICK_BODY")],
		[Diagram.Lesson.LOCK, "HTP_AC_LOCK", tr("HTP_AC_LOCK_BODY")],
		[Diagram.Lesson.WHY, "HTP_AC_WHY", tr("HTP_AC_WHY_BODY")]]
	if lives > 0:
		steps.append([Diagram.Lesson.CLIMB, "HTP_AC_CLIMB", tr("HTP_AC_CLIMB_BODY") % lives])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_AC_HINT",
			tr("HTP_AC_HINT_BODY_ONE") if hints == 1 else tr("HTP_AC_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## The bulb and Lock up to Hard; Lock alone on the Climb. No Undo anywhere:
## a lock is the one move there is, and it is never taken back.
func capabilities() -> Array[String]:
	if State.HINTS_BY[state.band] <= 0:
		return ["check"]
	return ["hint", "check"]

## The row's third button locks the answer, then asks the next; after the
## last answer it ends the day, so its line can be read first.
func check_label() -> String:
	if _phase != Phase.REVEAL:
		return "AC_LOCK"
	return "AC_NEXT" if state.index + 1 < state.count() else "AC_DONE"

func check_icon() -> String:
	return "check" if check_label() == "AC_LOCK" else "play"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.haptics = HAPTICS
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_hud_layer = Control.new()
	_hud_layer.name = "Hud"
	_hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.z_index = 1
	_hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_layer.draw.connect(_draw_hud)
	add_child(_hud_layer)
	resized.connect(_layout)
	solved.connect(_on_solved)

## The host calls this before it has said which day the board is
## (`daily_key` lands right after start()), so nothing is dealt here: the
## card stands empty for a frame and `_deal` asks once the day is known.
func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	state = State.new()
	state.band = clampi(difficulty, 0, 3)
	_seed_key = int(rng.randi())
	_dealt = false
	_tries = 0
	_told_tap = false
	_phase = Phase.WAIT
	_clear()
	_layout()
	_deal.call_deferred(_gen)

## Deals the board: a daily from the day's published questions -- at once
## when this phone already holds them, after one short wait on the network
## when it does not -- and anything else, or a daily nobody could fetch, from
## the bank.
func _deal(gen: int) -> void:
	if gen != _gen or _dealt:
		return
	var key := daily_key
	if key == 0:
		state.setup(_seed_key, state.band)
		_begin()
		return
	var doc := Backend.cached_day(State.GAME, key)
	if doc.is_empty() and Backend.started():
		_hud_layer.queue_redraw()
		# A slow network is not waited out: the bank deals, and the day's own
		# questions are on the phone for the next board.
		get_tree().create_timer(FETCH_WAIT).timeout.connect(func() -> void:
			if gen == _gen and not _dealt:
				state.setup(key, state.band)
				_begin())
		var got: Dictionary = await Backend.day_content(State.GAME, key)
		if gen != _gen or _dealt or not is_inside_tree():
			return
		doc = got.data if bool(got.ok) else {}
	if not state.setup_day(doc, key, state.band):
		state.setup(key, state.band)
	_begin()

## The day as dealt, for tools/export_days.gd (PuzzleBase.day_dict): the
## questions in English, the answers in the order they are shown.
func day_dict() -> Dictionary:
	if not _dealt:
		return {"pending": true}
	if state.questions.is_empty():
		return {}
	var asked: Array = []
	var rights: Array = []
	for i in state.questions.size():
		var w: Dictionary = state.questions[i].get("en", {})
		var all: Array = [w.get("right", "")] + (w.get("wrong", []) as Array)
		var shown: Array = []
		for k: int in state.orders[i]:
			shown.append(str(all[k]))
		var place: int = state.right_place(i)
		asked.append({"id": str(state.questions[i].id), "q": str(w.get("q", "")), "answers": shown})
		rights.append({"place": LETTERS[place], "right": str(w.get("right", "")), "why": str(w.get("why", ""))})
	return {
		"source": "bank" if state.source == "bank" else "server", "kind": "text",
		"payload": {"questions": asked, "lang": "en", "written_by": state.source},
		"solution": {"answers": rights},
		"metrics": {"questions": asked.size(), "questions_wanted": int(State.ASKS[state.band]),
			"hints": int(State.HINTS_BY[state.band]), "hearts": int(State.HEARTS_BY[state.band]),
			"climb": state.band >= 3, "written_by": state.source},
	}

## The day as `state` has it, from the top.
func _begin() -> void:
	_dealt = true
	max_hearts = State.HEARTS_BY[state.band]
	_heart_used = false
	_clear()
	_phase = Phase.PLAY
	_layout()
	_opened = _now()
	_round_at = _opened + (0.0 if Motion.reduce else Motion.ENTER_DELAY)
	if _skip_enter:
		# Dealt into a screen already standing: whole, with no entrance.
		_skip_enter = false
		_opened -= 10.0
		_round_at = _opened
	else:
		_busy_for(Motion.ENTER_DELAY + Motion.POP_IN + 4.0 * PLATE_STAGGER + 0.1)
		fx.cue("enter")
	focus_changed.emit()
	moved.emit()

func _clear() -> void:
	hearts = state.hearts
	out_of_hearts = false
	_settled = false
	_picked = -1
	_down = -1
	_up = -1
	_pick_at = -INF
	_lock_at = -INF
	_swap_at = -INF
	_cut_at = -INF
	_stamp_at = INF
	_seal_mesh = null
	_toast = ""
	_cheer = ""
	_cheer_at = -INF
	_flight_at = -INF
	_stars.clear()

# --- layout ---

## In a card: the card is the rect's width, centred. In the oak: the pills,
## the paper and the plates are as wide as the host's rows (its side margin)
## at the top of the span the rows leave (`_clear_rows`), with no card and
## no padding of their own.
func _layout() -> void:
	if size.x <= 0.0:
		return
	if _world != null:
		_world.size = size
	var top: float
	var inner: float
	if _bled:
		var wide := size.x - 2.0 * _side()
		var span := size.y - _clear_rows.x - _clear_rows.y
		_card = Rect2(_side(), _clear_rows.x, wide, minf(span, wide * CARD_TALL))
		top = _card.position.y + HUD_ROW
		inner = _card.end.y - top
	else:
		var tall := card_height(size.y)
		_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
		top = _card.position.y + HUD_ROW
		inner = _card.end.y - CARD_EDGE - PAD - top
	_panel = Rect2(_card.position.x + _pad(), top, _card.size.x - 2.0 * _pad(), inner * PANEL_SHARE)
	var plate_h := (inner - _panel.size.y - 4.0 * PLATE_GAP) / 4.0
	_plates.clear()
	for i in 4:
		_plates.append(Rect2(_panel.position.x, _panel.end.y + PLATE_GAP + i * (plate_h + PLATE_GAP),
			_panel.size.x, plate_h))
	_still = _build_still()
	_seal_mesh = null
	if _won and _bled:
		# Laid out under a win (a resize, or a day reopened solved): the
		# slide is aimed again, and set at its end if it never ran.
		_aim()
		if _slid <= 0.0 and not (_slide_tw != null and _slide_tw.is_valid()):
			_slid = 1.0
	_place()
	_redraw()
	_hud_layer.queue_redraw()

## The card's padding, which the oak has none of.
func _pad() -> float:
	return 0.0 if _bled else PAD

## The host's side margin, which the block keeps although the oak does not.
func _side() -> float:
	return float(load(FLAT_HOST).MARGIN)

## What the host's rows cover, in this board's own pixels (it is laid full
## rect). While playing the block is laid in what is left. On the win it is
## not laid out again: the board slides and shrinks into the win's span.
func set_clear(top: float, bottom: float, won := false) -> void:
	Motion.stop(_slide_tw)
	if not _bled:
		_bled = true
		_world = World.new()
		_world.name = "World"
		_world.show_behind_parent = true
		add_child(_world)
		move_child(_world, 0)
		_world.size = size
	_won = won
	if not won:
		_clear_rows = Vector2(top, bottom)
		_slid = 0.0
		_layout()
		return
	_win_clear = Vector2(top, bottom)
	# A day reopened solved is told before it has been laid out: _layout
	# sets the slide when it has a block to aim.
	if _card.size.x <= 0.0:
		return
	_aim()
	if Motion.reduce or not is_inside_tree() or _slid >= 1.0:
		_slide(1.0)
		return
	_slide_tw = create_tween()
	_slide_tw.tween_method(_slide, _slid, 1.0, WIN_SLIDE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Where the win's slide ends, from the block as it is laid and the win's span.
func _aim() -> void:
	var span := size.y - _win_clear.x - _win_clear.y
	_slid_from = _card.get_center()
	_slid_scale = clampf(minf((size.x - 2.0 * _side() - 2.0 * WIN_PAD) / _card.size.x,
		(span - 2.0 * WIN_PAD) / _card.size.y), 0.1, 1.0)
	_slid_by = Vector2(size.x * 0.5, _win_clear.x + span * 0.5) - _slid_from

func _slide(t: float) -> void:
	_slid = t
	_place()

## The host slides the board `x` aside on a change of level; the oak stays
## where it is, and the board that is leaving shows none, so the one
## arriving under it is not hidden.
func set_shift(x: float, leaving := false) -> void:
	_shift = x
	if _world != null:
		_world.visible = not leaving
	_place()

## The host deals this board into a screen already standing: it arrives
## whole, without the card's pop or the plates'. The deal comes a frame
## after this is asked, so it is kept for `_begin`.
func skip_entrance() -> void:
	if _dealt:
		_opened = _now() - 10.0
		_round_at = _opened
		_redraw()
		_hud_layer.queue_redraw()
	else:
		_skip_enter = true

## The board's transform at `_slid`, and the oak's against it, so the oak
## stays where it is while the block and everything on it goes.
func _place() -> void:
	if _slid <= 0.0 and _shift == 0.0 and not _placed:
		return
	_placed = _slid > 0.0 or _shift != 0.0
	var k := lerpf(1.0, _slid_scale, _slid)
	var by := _slid_by * _slid + Vector2(_shift, 0.0)
	pivot_offset = _slid_from
	scale = Vector2(k, k)
	position = by
	if _world != null:
		_world.pivot_offset = _slid_from
		_world.scale = Vector2.ONE / k
		_world.position = -by / k

func card_height(available: float) -> float:
	return minf(available, size.x * CARD_TALL)

func card_centred() -> bool:
	return true

## Where shown place `i`'s plate has its middle, for the harnesses and the
## tutorial.
func plate_point(i: int) -> Vector2:
	return _plates[clampi(i, 0, 3)].get_center() if _plates.size() == 4 else Vector2.ZERO

# --- the still drawing ---

func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	# The card, where the board stands in one; in the oak the paper and the
	# plates stand on the world itself.
	if not _bled:
		b.fan(Face.Builder.round_rect(_card.position, _card.size, CARD_RADIUS), Pal.ACORN_DEEP)
		b.fan(Face.Builder.round_rect(_card.position, _card.size - Vector2(0.0, CARD_EDGE), CARD_RADIUS), Pal.ACORN_TILE)
	# The question's paper, with a lip under it.
	b.fan(Face.Builder.round_rect(_panel.position + Vector2(0.0, PLATE_LIP), _panel.size, PANEL_RADIUS), Color(Pal.LINE, 0.7))
	b.fan(Face.Builder.round_rect(_panel.position, _panel.size, PANEL_RADIUS), Pal.SURFACE)
	return b.mesh()

# --- the drawing ---

func _draw() -> void:
	if _still == null:
		return
	var now := _now()
	var shown: Array = []
	var since := now - _opened - Motion.ENTER_DELAY
	var seen := 1.0
	var grown := 1.0
	if not Motion.reduce and _dealt:
		seen = Motion.appear_level(since)
		grown = Motion.wide_pop_scale(since)
	var centre := _card.get_center()
	var xf := Transform2D(0.0, Vector2(grown, grown), 0.0, centre) * Transform2D(0.0, -centre)
	if seen > 0.0:
		draw_mesh(_still, null, xf, Color(1.0, 1.0, 1.0, seen))
		shown.append(_still)
	if _live_dirty or now < _anim_until:
		_live = _build_live(now)
		_live_dirty = false
	if _live != null:
		draw_mesh(_live, null)
		shown.append(_live)
	_shown = shown

## Whether the answer to the question on the card is out: a lock, and the
## held breath after it, both behind.
func _revealed(now: float) -> bool:
	return state.locked() and (Motion.reduce or now - _lock_at >= HOLD)

## What plate `i` is doing at `now`: its scale, its sideways shiver and how
## much of it shows.
func _plate_pose(i: int, now: float) -> Dictionary:
	var s := 1.0
	var dx := 0.0
	var alpha := 1.0
	if Motion.reduce:
		return {"s": s, "dx": dx, "alpha": alpha}
	if _phase == Phase.SWAP:
		var u := now - _swap_at - (3 - i) * 0.02
		s = Motion.pop_out_scale(u, SWAP_OUT)
		alpha = clampf(1.0 - u / SWAP_OUT, 0.0, 1.0)
		return {"s": s, "dx": dx, "alpha": alpha}
	var e := now - _round_at - i * PLATE_STAGGER
	if e < 0.0:
		return {"s": 0.0, "dx": 0.0, "alpha": 0.0}
	s = Motion.pop_in_scale(e).y
	alpha = Motion.appear_level(e)
	if i == _down:
		s *= Motion.press_scale(now - _down_at)
	elif i == _up:
		s *= Motion.press_scale(Motion.PRESS_TIME, now - _up_at)
	if i == _picked and not state.locked():
		s *= Motion.bump_scale(now - _pick_at, 0.08)
	if state.locked():
		var res: Dictionary = state.results[state.index]
		var since := now - _lock_at
		if since < HOLD:
			# The held breath: the locked plate swells and settles, twice.
			if i == int(res.pick):
				s *= 1.0 + 0.025 * sin(since / HOLD * TAU * 2.0)
		else:
			if i == state.right_place():
				s *= Motion.bump_scale(since - HOLD, 0.1)
			elif i == int(res.pick):
				dx = Motion.shiver_offset(since - HOLD, 7.0, 0.32)
	return {"s": s, "dx": dx, "alpha": alpha}

func _plate_xf(i: int, pose: Dictionary) -> Transform2D:
	var c := _plates[i].get_center() + Vector2(float(pose.dx), 0.0)
	return Transform2D(0.0, Vector2(float(pose.s), float(pose.s)), 0.0, c)

## The look of plate `i`: [face, rim, disc, letter ink, mark] where mark is
## 1 for a tick, -1 for a cross, 2 for the padlock of the plate picked (a
## second tap locks it) and 0 for the letter.
func _plate_look(i: int, now: float) -> Array:
	if _revealed(now):
		var res: Dictionary = state.results[state.index]
		if i == state.right_place():
			return [Pal.LEAF_TILE, Pal.LEAF_DEEP, Pal.LEAF_DEEP, Pal.SURFACE, 1]
		if i == int(res.pick):
			return [Pal.BERRY_TILE, Pal.BERRY_DEEP, Pal.BERRY_DEEP, Pal.SURFACE, -1]
		return [Pal.SURFACE, Pal.LINE, Pal.ACORN_TILE, Pal.TEXT_DIM, 0]
	var held := i == _picked or (state.locked() and i == int(state.results[state.index].pick))
	if held:
		return [Pal.SUN_TILE, Pal.SUN_DEEP, Pal.SUN_DEEP, Pal.SURFACE, 2]
	return [Pal.SURFACE, Pal.LINE, Pal.ACORN_TILE, Pal.TEXT, 0]

## How much of plate `i` is left to see: an answer the bulb took fades, and
## after the answer is out the two that were neither stand back.
func _plate_fade(i: int, now: float) -> float:
	if state.is_cut(i):
		return 0.28 if Motion.reduce else lerpf(1.0, 0.28, clampf((now - _cut_at) / 0.25, 0.0, 1.0))
	if _revealed(now):
		var res: Dictionary = state.results[state.index]
		if i != state.right_place() and i != int(res.pick):
			return 0.5
	return 1.0

func _build_live(now: float) -> ArrayMesh:
	if not _dealt or state.count() == 0 or _plates.size() != 4:
		return null
	var b := Face.Builder.new()
	for i in 4:
		var pose := _plate_pose(i, now)
		var alpha := float(pose.alpha) * _plate_fade(i, now)
		if alpha <= 0.0 or float(pose.s) <= 0.0:
			continue
		var xf := _plate_xf(i, pose)
		var look := _plate_look(i, now)
		var half := _plates[i].size * 0.5
		var rim := 3.0
		b.fan(xf * Face.Builder.round_rect(-half + Vector2(0.0, PLATE_LIP), half * 2.0, PLATE_RADIUS), Color(look[1] as Color, alpha * 0.8))
		b.fan(xf * Face.Builder.round_rect(-half, half * 2.0, PLATE_RADIUS), Color(look[1] as Color, alpha))
		b.fan(xf * Face.Builder.round_rect(-half + Vector2.ONE * rim, half * 2.0 - Vector2.ONE * rim * 2.0, PLATE_RADIUS - rim), Color(look[0] as Color, alpha))
		var r := _plates[i].size.y * LETTER_R
		var at := xf * Vector2(-half.x + 22.0 + r, 0.0)
		b.disc(at, r * float(pose.s), Color(look[2] as Color, alpha))
		if int(look[4]) == 2:
			Art.padlock(b, at, r * float(pose.s), Color(look[3] as Color, alpha))
		elif int(look[4]) > 0:
			Art.tick(b, at, r * float(pose.s), Color(look[3] as Color, alpha))
		elif int(look[4]) < 0:
			Art.cross(b, at, r * float(pose.s), Color(look[3] as Color, alpha))
	return null if b.verts.is_empty() else b.mesh()

# --- the words ---

## The largest of `sizes` at which `text` wraps into `room`; the smallest
## when none does.
static func _fit(font: Font, text: String, room: Vector2, sizes: Array) -> int:
	for s: int in sizes:
		if font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, room.x, s).y <= room.y:
			return s
	return int(sizes.back())

## `text` wrapped and centred both ways in `box`, on the hud layer's current
## transform.
func _write(font: Font, text: String, box: Rect2, font_size: int, colour: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var tall := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, box.size.x, font_size).y
	var y := box.position.y + (box.size.y - tall) * 0.5 + font.get_ascent(font_size)
	_hud_layer.draw_multiline_string(font, Vector2(box.position.x, y), text, align, box.size.x, font_size, -1, colour)

func _draw_hud() -> void:
	if _card.size.x <= 0.0:
		return
	var now := _now()
	var shown: Array = []
	if not _dealt:
		# Waiting on the day's questions: one quiet line where they will be.
		if daily_key != 0 and Backend.started():
			_write(CozyTheme.body(600), tr("AC_FETCHING"), _panel, Q_FONTS[3], Pal.TEXT_DIM)
		_hud_shown = shown
		return
	var since := now - _opened - Motion.ENTER_DELAY
	if since < 0.0 and not Motion.reduce:
		_hud_shown = shown
		return
	var alpha := 1.0 if Motion.reduce else Motion.appear_level(since)
	_draw_pills(now, alpha, shown)
	_draw_question(now, alpha)
	_draw_answers(now)
	_draw_cheer(now)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_draw_toast(now, shown)
	_hud_shown = shown

## Left: which question, with a pip each in what it came to. Right: the
## acorns won. Between them, the Climb's hearts.
func _draw_pills(now: float, alpha: float, shown: Array) -> void:
	var font: Font = CozyTheme.display(700)
	var y := _card.position.y + HUD_ROW * 0.5 + 6.0
	var n: int = state.count()
	var left_text := tr("AC_ROUND") % [mini(state.index + 1, n), n]
	var right_text := "%d" % _rights_shown(now)
	var lw := font.get_string_size(left_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT).x
	var rw := font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT).x
	var pip := 14.0
	var pip_gap := 7.0
	var pips_w := n * pip + (n - 1) * pip_gap
	var icon := PILL_H * 0.72
	var boxes := [Vector2(lw + pips_w + 56.0, PILL_H), Vector2(rw + icon + 46.0, PILL_H)]
	var centres := [Vector2(_card.position.x + _pad() + boxes[0].x * 0.5, y),
		Vector2(_card.end.x - _pad() - boxes[1].x * 0.5, y)]
	var b := Face.Builder.new()
	for k in 2:
		var s := 1.0 if Motion.reduce else Motion.bump_scale(now - float(_pill_bump[k]), 0.12)
		var box: Vector2 = boxes[k] * s
		var c: Vector2 = centres[k]
		b.polygon(Face.Builder.round_rect(c - box * 0.5 - Vector2.ONE * 2.0, box + Vector2.ONE * 4.0, box.y * 0.5 + 2.0), Pal.LINE)
		b.polygon(Face.Builder.round_rect(c - box * 0.5, box, box.y * 0.5), Pal.SURFACE)
	var pips_x: float = centres[0].x - boxes[0].x * 0.5 + 22.0 + lw + 14.0
	var told := _revealed(now)
	for k in n:
		var c := Vector2(pips_x + pip * 0.5 + k * (pip + pip_gap), y)
		var tint := Pal.LINE
		if k < state.results.size() and (k < state.index or told):
			tint = Pal.LEAF_DEEP if bool(state.results[k].right) else Pal.BERRY_DEEP
		elif k == state.index:
			tint = Pal.TEXT_DIM
		b.disc(c, pip * 0.5, tint)
	var nut_at: Vector2 = centres[1] + Vector2(-boxes[1].x * 0.5 + 18.0 + icon * 0.4, 0.0)
	Art.acorn(b, nut_at, icon * 0.46, true)
	for k in max_hearts:
		var c := Vector2(size.x * 0.5 + (k - (max_hearts - 1) * 0.5) * 46.0, y)
		var s := 1.0
		if not Motion.reduce and k == hearts:
			s = Motion.bump_scale(now - _heart_at, 0.4)
		Art.heart(b, c, 18.0 * s, Pal.HEART if k < hearts else Pal.LINE)
	# The acorn a right answer earned, on its way from the plate to the count.
	var flown := (now - _flight_at) / FLIGHT
	if not Motion.reduce and flown >= 0.0 and flown < 1.0:
		var u := 1.0 - pow(1.0 - flown, 3.0)
		var lift := Vector2(0.0, -120.0 * sin(PI * u))
		Art.acorn(b, _flight_from.lerp(nut_at, u) + lift, icon * 0.46 * lerpf(1.3, 1.0, u), true)
	var pills := b.mesh()
	_hud_layer.draw_mesh(pills, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	shown.append(pills)
	if max_hearts == 0:
		var sw := StarLine.width(STAR_SCALE)
		_stars.draw(_hud_layer, Vector2(size.x * 0.5 - sw * 0.5 + StarLine.R * STAR_SCALE, y), STAR_SCALE, now, alpha)
	var mid := (font.get_ascent(PILL_FONT) - font.get_descent(PILL_FONT)) * 0.5
	_hud_layer.draw_string(font, Vector2(centres[0].x - boxes[0].x * 0.5 + 22.0, y + mid), left_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT, Color(Pal.TEXT, alpha))
	_hud_layer.draw_string(font, nut_at + Vector2(icon * 0.5 + 8.0, mid), right_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT, Color(Pal.TEXT, alpha))

## The paper: the subject at its head, the question in its middle, and once
## the answer is out, the line about it at its foot.
func _draw_question(now: float, alpha: float) -> void:
	if state.count() == 0:
		return
	var a := alpha
	if not Motion.reduce:
		if _phase == Phase.SWAP:
			a *= clampf(1.0 - (now - _swap_at) / SWAP_OUT, 0.0, 1.0)
		else:
			a *= Motion.appear_level(now - _round_at, 0.2)
	if a <= 0.0:
		return
	var q: Dictionary = state.question()
	var w: Dictionary = State.wording(q)
	var display: Font = CozyTheme.display(700)
	var body: Font = CozyTheme.body(600)
	var cat_key := "AC_CAT_" + str(q.get("cat", "")).to_upper()
	var cat := tr(cat_key)
	if cat != cat_key:
		_hud_layer.draw_string(display, Vector2(_panel.position.x, _panel.position.y + 18.0 + display.get_ascent(CAT_FONT)),
			cat.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, _panel.size.x, CAT_FONT, Color(Pal.ACORN_DEEP, a))
	var box := Rect2(_panel.position.x + 34.0, _panel.position.y + CAT_H,
		_panel.size.x - 68.0, _panel.size.y - CAT_H - WHY_H)
	if now >= _stamp_at:
		# The seal takes the paper's top right corner; the question makes room.
		box.size.x -= _seal_rad() * 2.0 - 24.0
	var text := str(w.get("q", ""))
	# Fitted to the room the why will leave it, so its size never jumps, but
	# stood in the paper's middle until the why comes, and then lifted.
	var up := 0.0
	if _revealed(now):
		up = 1.0 if Motion.reduce else Motion.appear_level(now - _lock_at - HOLD, 0.25)
	var stood := Rect2(box.position, box.size + Vector2(0.0, (WHY_H - 12.0) * (1.0 - up)))
	_write(display, text, stood, _fit(display, text, box.size, Q_FONTS), Color(Pal.TEXT, a))
	if not _revealed(now):
		return
	var why := str(w.get("why", ""))
	var wa := a if Motion.reduce else a * Motion.appear_level(now - _lock_at - HOLD - WHY_AT, 0.25)
	if why == "" or wa <= 0.0:
		return
	var foot := Rect2(box.position.x, _panel.end.y - WHY_H, box.size.x, WHY_H - 12.0)
	var res: Dictionary = state.results[state.index]
	var ink := Pal.LEAF_DEEP if bool(res.right) else Pal.BERRY_DEEP
	_write(body, why, foot, _fit(body, why, foot.size, [WHY_FONT, 24, 22]), Color(ink.darkened(0.2), wa))

## The letter and the answer on each plate, moving as its plate moves.
func _draw_answers(now: float) -> void:
	if state.count() == 0 or _plates.size() != 4:
		return
	var display: Font = CozyTheme.display(700)
	var body: Font = CozyTheme.body(600)
	var answers: Array = state.answers()
	for i in 4:
		var pose := _plate_pose(i, now)
		var alpha := float(pose.alpha) * _plate_fade(i, now)
		if alpha <= 0.0 or float(pose.s) <= 0.0:
			continue
		var look := _plate_look(i, now)
		var half := _plates[i].size * 0.5
		var r := _plates[i].size.y * LETTER_R
		_hud_layer.draw_set_transform_matrix(_plate_xf(i, pose))
		if int(look[4]) == 0:
			var lx := -half.x + 22.0
			_hud_layer.draw_string(display, Vector2(lx, (display.get_ascent(LETTER_FONT) - display.get_descent(LETTER_FONT)) * 0.5),
				LETTERS[i], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, LETTER_FONT, Color(look[3] as Color, alpha))
		var box := Rect2(-half.x + 22.0 + r * 2.0 + 20.0, -half.y + 6.0, 0.0, half.y * 2.0 - 12.0)
		box.size.x = half.x - 22.0 - box.position.x
		var text := str(answers[i])
		_write(body, text, box, _fit(body, text, box.size, A_FONTS), Color(Pal.TEXT, alpha), HORIZONTAL_ALIGNMENT_LEFT)
	_hud_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

## A line the player has to see now, on a dark pill over the question.
func _tell(text: String) -> void:
	_toast = text
	_toast_at = _now()
	_hud_layer.queue_redraw()

func _draw_toast(now: float, shown: Array) -> void:
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
	var room := size.x - 120.0
	var wide := minf(room, font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x + TOAST_PAD)
	var key := "%s|%d" % [_toast, int(wide)]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-wide, -TOAST_H) * 0.5, Vector2(wide, TOAST_H), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh()
		_toast_mesh_for = key
	shown.append(_toast_mesh)
	# Over the paper's foot: the finger works the plates under it.
	var mid := Vector2(size.x * 0.5, _panel.end.y - 14.0 - TOAST_H * 0.5)
	_hud_layer.draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha * 0.94))
	var base := mid.y - font.get_height(TOAST_FONT) * 0.5 + font.get_ascent(TOAST_FONT)
	_hud_layer.draw_string(font, Vector2(mid.x - wide * 0.5, base), _toast, HORIZONTAL_ALIGNMENT_CENTER, wide,
		TOAST_FONT, Color(Pal.PAPER, alpha))

## The acorns the count shows: the answer on the card is not counted before
## it is out and its acorn has landed (it counted from the lock before
## 2026-10-28, which told a right answer through the held breath).
func _rights_shown(now: float) -> int:
	var n: int = state.rights()
	if state.locked() and state.index < state.results.size() and bool(state.results[state.index].right):
		var landed := _revealed(now) and (Motion.reduce or now - _flight_at >= FLIGHT)
		if not landed:
			n -= 1
	return maxi(0, n)

## The run's word, rising off the right plate and fading.
func _draw_cheer(now: float) -> void:
	if _cheer == "":
		return
	var e := now - _cheer_at
	if e < 0.0 or e >= CHEER_TIME:
		return
	var font: Font = CozyTheme.display(700)
	var u := e / CHEER_TIME
	var k := 1.0 if Motion.reduce else Motion.pop_in_scale(e).x
	var a := minf(1.0, (1.0 - u) * 3.0)
	var at := _cheer_from + Vector2(0.0, 0.0 if Motion.reduce else -CHEER_RISE * (1.0 - pow(1.0 - u, 2.0)))
	var wide := font.get_string_size(_cheer, HORIZONTAL_ALIGNMENT_LEFT, -1.0, CHEER_FONT).x
	_hud_layer.draw_set_transform_matrix(Transform2D(-0.06, Vector2(k, k), 0.0, at))
	var base := Vector2(-wide * 0.5, font.get_ascent(CHEER_FONT) * 0.35)
	_hud_layer.draw_string_outline(font, base, _cheer, HORIZONTAL_ALIGNMENT_LEFT, -1.0, CHEER_FONT, 10, Color(Pal.SURFACE, a))
	_hud_layer.draw_string(font, base, _cheer, HORIZONTAL_ALIGNMENT_LEFT, -1.0, CHEER_FONT, Color(Pal.SUN_DEEP.darkened(0.15), a))
	_hud_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

func _bump_pill(k: int) -> void:
	_pill_bump[k] = _now()
	_hud_layer.queue_redraw()

# --- input ---

## Touch and mouse, as every flat board takes them (touch is not mouse here:
## emulate_mouse_from_touch is off). A press sinks a plate and its release
## on the same plate picks it. Once the answer is out, a tap asks the next.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)

func _plate_at(at: Vector2) -> int:
	for i in _plates.size():
		if _plates[i].has_point(at):
			return i
	return -1

func _press(at: Vector2) -> void:
	if is_done() or out_of_hearts or not _dealt or not _card.has_point(at):
		return
	if _phase == Phase.REVEAL:
		if _now() - _lock_at > HOLD + WHY_AT + 0.3:
			next_question()
		return
	if _phase != Phase.PLAY:
		return
	var i := _plate_at(at)
	if i < 0 or state.is_cut(i):
		return
	_down = i
	_down_at = _now()
	_busy_for(Motion.PRESS_TIME)
	_redraw()

func _release(at: Vector2) -> void:
	if _down < 0:
		return
	var i := _down
	_down = -1
	_up = i
	_up_at = _now()
	_busy_for(Motion.RELEASE_TIME)
	if _phase == Phase.PLAY and _plate_at(at) == i:
		if i == _picked:
			# The lit plate again: sure. Too soon after the pick, nothing.
			if _now() - _pick_at >= ARM:
				lock()
				if puzzle_id() == "acorn" and state.locked():
					Progress.mark_tutorial_seen(TAP_LEARNT)
		else:
			pick_answer(i)
	_redraw()

## Picks shown place `i`: the plate lights and waits for Lock. A second pick
## moves the light. The harnesses' and the tutorial's way in.
func pick_answer(i: int) -> void:
	if _phase != Phase.PLAY or is_done() or out_of_hearts or i < 0 or i > 3 or state.is_cut(i):
		return
	if i == _picked:
		return
	_picked = i
	_pick_at = _now()
	if not _told_tap:
		_told_tap = true
		if puzzle_id() != "acorn" or not Progress.tutorial_seen(TAP_LEARNT):
			_tell(tr("AC_TAP_AGAIN"))
	fx.cue("pick", randf_range(TICK_VARY.x, TICK_VARY.y))
	_busy_for(Motion.BUMP_TIME)
	_redraw()
	_hud_layer.queue_redraw()
	focus_changed.emit()

# --- the HUD's actions ---

func hints_left() -> int:
	return State.HINTS_BY[state.band] + hints_extra - hints_used

## The bulb takes two wrong answers off the card.
func hint() -> bool:
	if is_done() or out_of_hearts or _phase != Phase.PLAY or hints_left() <= 0:
		return false
	var gone: Array = state.cut_two()
	if gone.is_empty():
		_tell(tr("AC_HINT_USED"))
		fx.cue("refuse")
		return false
	hints_used += 1
	_cut_at = _now()
	if gone.has(_picked):
		_picked = -1
	for place: int in gone:
		fx.puff(_plates[place].get_center(), Pal.LINE, 6)
	_tell(tr("AC_HINT_TOLD"))
	fx.cue("hint")
	_busy_for(TOAST_HOLD)
	_redraw()
	moved.emit()
	return true

## Lock, then Next, then at the last question the day's end. Always -1:
## there is nothing to count.
func check() -> int:
	if is_done() or out_of_hearts or not _dealt:
		return -1
	if _phase == Phase.PLAY:
		lock()
	elif _phase == Phase.REVEAL:
		next_question()
	return -1

## Makes the picked answer final.
func lock() -> void:
	if _phase != Phase.PLAY or is_done() or out_of_hearts:
		return
	var now := _now()
	if _picked < 0:
		_tell(tr("AC_PICK_FIRST"))
		fx.cue("refuse")
		return
	var res: Dictionary = state.lock(_picked)
	if res.is_empty():
		return
	_picked = -1
	_down = -1
	_phase = Phase.REVEAL
	_lock_at = now
	_toast = ""
	checks += 1
	moves += 1
	fx.cue("lock", randf_range(TICK_VARY.x, TICK_VARY.y))
	var hold := 0.0 if Motion.reduce else HOLD
	var right := bool(res.right)
	var place: int = state.right_place()
	var run: int = state.run()
	if right:
		# Not landed until the answer is out and its acorn has flown.
		_flight_at = INF
	_after(hold, func() -> void:
		var at := _plates[place].get_center()
		var now_at := _now()
		if right:
			# A run climbs: the notes a step higher a right in a row, the
			# sparkle fuller, and from three in a row a word for it.
			var step := mini(run - 1, RUN_STEPS)
			fx.cue("right", 1.0 + RUN_PITCH * step)
			fx.sparkle(Vector2(_plates[place].position.x + 60.0, at.y), Pal.SUN)
			if run >= RUN_CHEER:
				fx.sparkle(Vector2(_plates[place].end.x - 60.0, at.y), Pal.SUN)
				fx.confetti(at, 6 + 2 * step, _plates[place].size.x * 0.5)
				_cheer = tr("AC_RUN_N") % run
				_cheer_at = now_at
				_cheer_from = Vector2(_plates[place].end.x - _plates[place].size.x * 0.24, _plates[place].position.y - 6.0)
			fx.ring(at, _plates[place].size.y * (0.9 + 0.08 * step), Pal.LEAF)
			_flight_at = now_at
			_flight_from = Vector2(_plates[place].position.x + 22.0 + _plates[place].size.y * LETTER_R, at.y)
			_after(0.0 if Motion.reduce else FLIGHT, func() -> void: _bump_pill(1))
		else:
			fx.cue("wrong")
		if max_hearts == 0:
			_stars.rate(state.stars(), now_at, true)
		_bump_pill(0)
		_busy_for(maxf(FLIGHT, CHEER_TIME) + 0.1)
		_redraw())
	if bool(res.missed):
		_after(hold + WHY_AT, func() -> void:
			hearts = state.hearts
			_heart_at = _now()
			fx.cue("heart_lost")
			_hud_layer.queue_redraw())
	_busy_for(hold + WHY_AT + 0.7)
	_redraw()
	_hud_layer.queue_redraw()
	moved.emit()
	focus_changed.emit()
	if max_hearts > 0 and state.hearts <= 0:
		out_of_hearts = true
		_running = false
		_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _run_out)

## Asks the next question, or after the last one ends the day.
func next_question() -> void:
	if _phase != Phase.REVEAL or is_done() or out_of_hearts:
		return
	# Not during the held breath: the answer is seen before the next is asked.
	if not _revealed(_now() - 0.15):
		return
	if state.index + 1 >= state.count():
		_settled = true
		check_solved()
		return
	var now := _now()
	_phase = Phase.SWAP
	_swap_at = now
	fx.cue("next")
	var out := 0.0 if Motion.reduce else SWAP_OUT + 0.06
	_busy_for(out + Motion.POP_IN + 4.0 * PLATE_STAGGER + 0.1)
	_after(out, func() -> void:
		if _phase != Phase.SWAP or not state.advance():
			return
		_phase = Phase.PLAY
		_round_at = _now()
		_lock_at = -INF
		_cut_at = -INF
		_up = -1
		_bump_pill(0)
		_redraw()
		_hud_layer.queue_redraw()
		focus_changed.emit())
	_redraw()
	_hud_layer.queue_redraw()
	focus_changed.emit()
	moved.emit()

## An answer is final and a question is not asked twice: Reset has nothing
## to give on this board.
func can_reset() -> bool:
	return false

func reset_board() -> void:
	pass

func is_solved() -> bool:
	return _settled and state.is_solved()

## The win's brain report: the right answers out of the questions (spec 2026-10-22-brain-skills, section 6).
func skill_quality() -> float:
	if state.questions.is_empty():
		return -1.0
	return clampf(float(state.rights()) / float(state.questions.size()), 0.0, 1.0)

func completion_record() -> Dictionary:
	var picks := []
	var rights := []
	for r: Dictionary in state.results:
		picks.append(int(r.pick))
		rights.append(bool(r.right))
	return {"picks": picks, "rights": rights, "set": state.set_id()}

## A completed daily is put back on its last question, answered. From the
## day's questions if this phone still holds them and from the bank if not;
## when those are not the questions that were answered, the picks are let go
## and only what was right and wrong is kept.
func restore_completed_board() -> void:
	var now := _now()
	_gen += 1
	_dealt = true
	var key := daily_key if daily_key != 0 else _seed_key
	if not state.setup_day(Backend.cached_day(State.GAME, key) if daily_key != 0 else {}, key, state.band):
		state.setup(key, state.band)
	var same := int(completed_record.get("set", 0)) == state.set_id()
	state.finish(completed_record.get("picks", []) if same else [], completed_record.get("rights", []))
	max_hearts = State.HEARTS_BY[state.band]
	_clear()
	hearts = maxi(1, state.hearts) if max_hearts > 0 else 0
	if max_hearts == 0:
		_stars.rate(state.stars(), now, false)
	_phase = Phase.REVEAL
	_settled = true
	_opened = now - 10.0
	_round_at = now - 10.0
	_lock_at = now - 10.0
	_anim_until = 0.0
	_layout()
	_stamp_at = now - 10.0 if _stamped() else INF
	_hud_layer.queue_redraw()
	_redraw()

func share_glyphs() -> String:
	return "%s\n🌰 %d / %d" % [state.share_glyphs(), state.rights(), state.count()]

# --- the win ---

func flat_win() -> Dictionary:
	var sub := tr("AC_WIN_SUB") % [state.rights(), state.count()]
	var best: int = state.best_run()
	if best >= RUN_CHEER and best < state.count():
		sub = tr("AC_WIN_SUB_RUN") % [state.rights(), state.count(), best]
	return {"faces": [], "subtitle": sub}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## A day with nothing wrong is stamped, and so is any Climb that reached the top.
func _stamped() -> bool:
	return state.band >= 3 or state.perfect()

func _on_solved() -> void:
	var now := _now()
	_down = -1
	_toast = ""
	fx.cue("solved")
	if _stamped():
		_stamp_at = now if Motion.reduce else now + Motion.SOLVE_DELAY
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_hud_layer.queue_redraw())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
	if not Motion.reduce:
		_after(Motion.SOLVE_DELAY, func() -> void:
			fx.confetti(Vector2(_panel.get_center().x, _panel.position.y + 40.0), 30, _panel.size.x * 0.8)
			fx.cue("party"))
	_busy_for(Motion.SOLVE_DELAY + STAMP_DROP * 2.0 + 0.3)
	_hud_layer.queue_redraw()
	_redraw()

func _seal_rad() -> float:
	return minf(_panel.size.x * 0.11, (_panel.size.y - WHY_H) * 0.42)

## The seal on the paper's corner, dropping in and settling.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := _seal_rad()
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
	var centre := Vector2(_panel.end.x - rad * 0.92, _panel.position.y + rad * 0.92)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_hud_layer.draw_set_transform_matrix(xf)
	_hud_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_hud_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02], [tr("AC_SEAL_PERFECT") if state.perfect() else tr("AC_SEAL_CLIMB"), 0.17, 0.36]]
	else:
		lines = [[tr("AC_SEAL_PERFECT"), 0.24, 0.12]]
	Seal.text(_hud_layer, rad, lines)
	_hud_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

# --- the Climb's hearts ---

func _run_out() -> void:
	if not out_of_hearts or is_done():
		return
	fx.cue("out_of_hearts")
	_tell(tr("AC_OUT"))
	_after(0.5, _open_card)

## The card, over the whole screen: on the host so it covers the chrome, or
## on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not is_inside_tree() or not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["AC_OUT_BODY", "AC_OUT_BODY_PLAIN"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: a new Climb, since every answer of the lost one has been seen.
## Hearts full, clock from zero.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	_gen += 1
	_tries += 1
	moves = 0
	elapsed = 0.0
	checks = 0
	_running = true
	state.redeal(_tries)
	_begin()

## One more heart (the card's video): once a board. The question that cost
## the last heart stays answered, and the Climb goes on from it.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_heart_used = true
	state.hearts = 1
	hearts = 1
	out_of_hearts = false
	_running = true
	_heart_at = _now()
	fx.cue("heart_back")
	_hud_layer.queue_redraw()
	next_question()
	moved.emit()

func _leave() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

# --- odds and ends ---

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	var gen := _gen
	if delay <= 0.0:
		what.call()
		return
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## True while a question is being dealt or changed: the host holds its video
## offer until the board is still.
func busy() -> bool:
	return _phase == Phase.SWAP or _phase == Phase.WAIT

func _process(delta: float) -> void:
	super(delta)
	if not _dealt:
		return
	var now := _now()
	if now < _anim_until:
		queue_redraw()
		_hud_layer.queue_redraw()
	elif (_toast != "" and now - _toast_at < TOAST_HOLD + 0.1) \
			or now - float(_pill_bump[0]) < Motion.BUMP_TIME + 0.1 \
			or now - float(_pill_bump[1]) < Motion.BUMP_TIME + 0.1 \
			or now - _heart_at < Motion.BUMP_TIME + 0.5:
		_hud_layer.queue_redraw()

func _redraw() -> void:
	_live_dirty = true
	queue_redraw()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
