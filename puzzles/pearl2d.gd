extends "res://core/puzzle_base.gd"

## Pearl Dive as a flat board: a prompt on a card of paper names a kind of
## thing, the player types one on the keyboard under the card, and a diving
## bell goes down the water beside the paper by how rare the answer was. One
## answer of every prompt is its Pearl, the deepest there is. A clock runs
## while a prompt stands; an answer the list does not hold costs some of it.
## A few prompts make the day; One Breath (Insane) is a single tank of air
## for the whole dive.
##
## The rules are in puzzles/pearl_state.gd, which this only draws. The day's
## prompts are written by a model and published by the backend
## (server/functions/src/pearl.ts); a daily reads them through
## core/backend.gd once its host has said which day it is, and everything
## else -- no network, a board dealt from New, a probe -- is dealt from the
## bank in content/pearl.json. docs/agents/boards/pearl-dive.md has the
## reasons.
##
## How it is drawn. `_still` is the card, the paper and the water with its
## sand and shell (a layout). `_live` is the clock's bar, the line the answer
## is typed on, the rope and the bell, rebuilt on every frame the clock runs.
## The words are a layer of their own over both.
##
## How it moves. The flat boards' vocabulary (core/motion.gd,
## docs/art/flat-motion.md) read as curves. This board's own: the bell
## sinking to its new depth, and the clock.

const State = preload("res://puzzles/pearl_state.gd")
const Art = preload("res://ui/faces/pearl_art.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const Seal = preload("res://ui/flat/seal.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Backend = preload("res://core/backend.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"

# --- the card ---
const PAD := 30.0
## The strip the pills stand in over the paper.
const HUD_ROW := 76.0
## The card is never taller than this many times its width.
const CARD_TALL := 0.92
const CARD_RADIUS := 26.0
const CARD_EDGE := 6.0
const PANEL_RADIUS := 24.0
const PANEL_LIP := 5.0
## The water takes this share of the card's width, right of the paper.
const SHAFT_SHARE := 0.2
const SHAFT_GAP := 16.0
const SHAFT_RADIUS := 22.0
## Where the bell hangs at no depth, and how far over the sand at the floor.
const SHAFT_HEAD := 54.0
const SHAFT_FOOT := 118.0
## The sand under the water, where the floor's depth is written.
const SAND_H := 44.0
const BELL_R := 26.0
## The clock's bar at the paper's head.
const CLOCK_H := 20.0
const CLOCK_ROOM := 76.0
## The line the answer is typed on.
const FIELD_H := 108.0
const FIELD_RADIUS := 22.0
## The field's middle, as a share of the paper's height.
const FIELD_AT := 0.5

const ASK_FONTS := [50, 46, 42, 38, 34, 30]
const TYPE_FONTS := [52, 46, 40, 34, 30]
const FOOT_FONT := 28
const TIER_FONT := 34
const CLOCK_FONT := 34
const PILL_FONT := 32
const PILL_H := 50.0
const DEPTH_FONT := 22

# --- motion: what is this board's own ---
## The bell sinking to its new depth.
const DIVE_TIME := 0.7
## The clock's last seconds are counted aloud.
const LAST_SECONDS := 5
## A prompt leaves, and the next one comes.
const SWAP_OUT := 0.16
## The answer is read before a tap may ask the next.
const NEXT_AFTER := 0.5
const CARET_PERIOD := 1.0
## How long a slow network is waited on before the bank deals instead.
const FETCH_WAIT := 4.0
const WIN_WAIT := 0.9
const CARD_AFTER := 1.2
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_TILT := -0.22
const TOAST_HOLD := 2.2
const TOAST_H := 68.0
const TOAST_PAD := 64.0
const TOAST_RADIUS := 24.0
const TOAST_FONT := 28

## What the phone does under each cue (docs/agents/haptics.md). The clock's
## last seconds are the faintest tap; an answer is felt by how deep it went.
const HAPTICS := {
	"dive": Haptics.BUMP,
	"tick": Haptics.TICK,
	"miss": Haptics.WARN,
	"refuse": Haptics.TAP,
	"hit": Haptics.TAP,
	"deep": Haptics.GOOD,
	"pearl": Haptics.WIN,
	"dry": Haptics.BAD,
	"next": Haptics.TICK,
	"hint": Haptics.GOOD,
	"air_back": Haptics.GOOD,
	"out_of_air": Haptics.LOSE,
	"solved": Haptics.WIN,
}

enum Phase { WAIT, READY, PLAY, REVEAL, SWAP }

var state = State.new()
## Back to camp from the out-of-air card; the host listens for it.
signal leave

var fx: Node2D
## True once One Breath's air is gone (the name every board with an
## out-of-something card uses).
var out_of_hearts := false
var _air_used := false
var _out_card: Control
var _tries := 0

var _card := Rect2()
var _panel := Rect2()
var _shaft := Rect2()
var _clock := Rect2()
var _field := Rect2()
## Bumped on every rebuild; a pending callback from the last board checks it.
var _gen := 0
var _phase := Phase.WAIT
## What build() was handed, kept for the deal that follows it.
var _seed_key := 0
var _dealt := false
var _settled := false
## The letters on the line, as the keys sent them.
var _typed := ""
var _tray: Control = null
## The line under an answer that says what Enter does next; the tutorial's
## pages, which have no Enter, leave it out.
var _enter_line := true

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

# --- the clocks ---
var _opened := -1.0e9
var _round_at := -1.0e9
var _answer_at := -INF
var _miss_at := -INF
var _swap_at := -INF
var _dive_at := -INF
var _dive_from := 0.0
var _anim_until := 0.0
var _pill_bump := [-INF, -INF]
var _stamp_at := INF
var _toast := ""
var _toast_at := -100.0
## The last whole second the clock showed, for counting the last ones aloud.
var _whole := 0

func puzzle_id() -> String: return "pearl"
func title() -> String: return "Pearl Dive"

func rules() -> String:
	var out := ""
	if state.band >= 3:
		out = tr("PD_RULES_BREATH") % [State.ASKS[3], int(State.AIR)]
	else:
		out = tr("PD_RULES") % [State.ASKS[state.band], int(State.SECONDS[state.band])]
	out += "\n\n" + tr("PD_RULES_DEPTH") % int(State.MISS_COST)
	var hints: int = State.HINTS_BY[state.band]
	if hints > 0:
		out += "\n\n" + (tr("PD_RULES_BULB_ONE") if hints == 1 else tr("PD_RULES_BULB_N") % hints)
	return out

## The tutorial: each page is the board itself on a hand-picked prompt
## (ui/hud/pearl_tutorial_diagram.gd). Loaded, not preloaded: the page's
## board extends this script.
func tutorial_pages() -> Array:
	var path := "res://ui/hud/pearl_tutorial_diagram.gd"
	if not ResourceLoader.exists(path):
		return []
	var Diagram = load(path)
	var hints: int = State.HINTS_BY[state.band]
	var steps := [
		[Diagram.Lesson.TYPE, "HTP_PD_TYPE", tr("HTP_PD_TYPE_BODY")],
		[Diagram.Lesson.RARE, "HTP_PD_RARE", tr("HTP_PD_RARE_BODY")],
		[Diagram.Lesson.MISS, "HTP_PD_MISS", tr("HTP_PD_MISS_BODY") % int(State.MISS_COST)]]
	if state.band >= 3:
		steps.append([Diagram.Lesson.BREATH, "HTP_PD_BREATH", tr("HTP_PD_BREATH_BODY") % int(State.AIR)])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_PD_HINT",
			tr("HTP_PD_HINT_BODY_ONE") if hints == 1 else tr("HTP_PD_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## The bulb up to Hard and nothing on One Breath. No Undo, no Check and no
## Reset: an answer is the one move there is, and Enter is what offers it.
func capabilities() -> Array[String]:
	if State.HINTS_BY[state.band] <= 0:
		return []
	return ["hint"]

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

## The host hands the keyboard over once a board. Its keys are Hidden Word's
## and may still wear that board's marks.
func set_tray(t: Control) -> void:
	_tray = t
	_tray.match_locale()
	_tray.clear_marks()
	if _tray.gone:
		_tray.enter(0.0)

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
	_phase = Phase.WAIT
	_clear()
	_layout()
	_deal.call_deferred(_gen)

## Deals the board: a daily from the day's published prompts -- at once when
## this phone already holds them, after one short wait on the network when it
## does not -- and anything else, or a daily nobody could fetch, from the
## bank.
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
		# prompts are on the phone for the next board.
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

## The day as `state` has it, from the top: the card stands ready and the
## clock waits for the player to dive.
func _begin() -> void:
	_dealt = true
	_air_used = false
	_clear()
	_phase = Phase.READY
	_layout()
	_opened = _now()
	_round_at = _opened + (0.0 if Motion.reduce else Motion.ENTER_DELAY)
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP + 0.2)
	fx.cue("enter")
	focus_changed.emit()
	moved.emit()

func _clear() -> void:
	out_of_hearts = false
	_settled = false
	_typed = ""
	_answer_at = -INF
	_miss_at = -INF
	_swap_at = -INF
	_dive_at = -INF
	_dive_from = 0.0
	_stamp_at = INF
	_seal_mesh = null
	_toast = ""
	_whole = 0

# --- layout ---

func _layout() -> void:
	if size.x <= 0.0:
		return
	var tall := card_height(size.y)
	_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
	var top := _card.position.y + HUD_ROW
	var inner := _card.end.y - CARD_EDGE - PAD - top
	var wide := _card.size.x - 2.0 * PAD
	var shaft_w := wide * SHAFT_SHARE
	_shaft = Rect2(_card.end.x - PAD - shaft_w, top, shaft_w, inner)
	_panel = Rect2(_card.position.x + PAD, top, wide - shaft_w - SHAFT_GAP, inner)
	_clock = Rect2(_panel.position.x + 30.0, _panel.position.y + 30.0, _panel.size.x - 60.0 - CLOCK_ROOM, CLOCK_H)
	_field = Rect2(_panel.position.x + 26.0, _panel.position.y + _panel.size.y * FIELD_AT - FIELD_H * 0.5,
		_panel.size.x - 52.0, FIELD_H)
	_still = _build_still()
	_seal_mesh = null
	_redraw()
	_hud_layer.queue_redraw()

func card_height(available: float) -> float:
	return minf(available, size.x * CARD_TALL)

func card_centred() -> bool:
	return true

## Where the line the answer is typed on has its middle, for the harnesses
## and the tutorial.
func field_point() -> Vector2:
	return _field.get_center()

## Where the bell hangs `metres` down.
func _depth_y(metres: float) -> float:
	var floor_m := maxf(1.0, float(state.floor_depth())) if state.count() > 0 else 1.0
	return lerpf(_shaft.position.y + SHAFT_HEAD, _shaft.end.y - SHAFT_FOOT, clampf(metres / floor_m, 0.0, 1.0))

func _depth_shown(now: float) -> float:
	var to := float(state.depth())
	if Motion.reduce:
		return to
	var u := clampf((now - _dive_at) / DIVE_TIME, 0.0, 1.0)
	return lerpf(_dive_from, to, 1.0 - pow(1.0 - u, 3.0))

# --- the still drawing ---

func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	b.fan(Face.Builder.round_rect(_card.position, _card.size, CARD_RADIUS), Pal.CLOUD_DEEP)
	b.fan(Face.Builder.round_rect(_card.position, _card.size - Vector2(0.0, CARD_EDGE), CARD_RADIUS), Pal.CLOUD_TILE)
	# The paper, with a lip under it.
	b.fan(Face.Builder.round_rect(_panel.position + Vector2(0.0, PANEL_LIP), _panel.size, PANEL_RADIUS), Color(Pal.LINE, 0.7))
	b.fan(Face.Builder.round_rect(_panel.position, _panel.size, PANEL_RADIUS), Pal.SURFACE)
	# The water: lighter under the surface, dark over the sand.
	var sea: Array = Art.SEA
	b.fan(Face.Builder.round_rect(_shaft.position + Vector2(0.0, PANEL_LIP), _shaft.size, SHAFT_RADIUS), Color(sea[5] as Color, 0.7))
	b.fan(Face.Builder.round_rect(_shaft.position, _shaft.size, SHAFT_RADIUS), sea[0])
	var from := _shaft.position.y + SHAFT_RADIUS
	var to := _shaft.end.y - SHAFT_RADIUS
	var step := (to - from) / float(sea.size() - 1)
	for k in range(1, sea.size()):
		var y := from + (k - 1) * step
		b.fan(PackedVector2Array([Vector2(_shaft.position.x, y), Vector2(_shaft.end.x, y),
			Vector2(_shaft.end.x, to), Vector2(_shaft.position.x, to)]), sea[k])
	b.fan(Face.Builder.round_rect(Vector2(_shaft.position.x, to - SHAFT_RADIUS), Vector2(_shaft.size.x, SHAFT_RADIUS * 2.0),
		SHAFT_RADIUS), sea[sea.size() - 1])
	# The sand and the shell that holds the pearl.
	var mid := _shaft.get_center().x
	var sand := PackedVector2Array([Vector2(_shaft.position.x + 6.0, _shaft.end.y - 8.0)])
	sand.append_array(Face.Builder.bezier3(Vector2(_shaft.position.x + 6.0, _shaft.end.y - SAND_H),
		Vector2(mid - 30.0, _shaft.end.y - SAND_H - 16.0), Vector2(mid + 30.0, _shaft.end.y - SAND_H + 8.0),
		Vector2(_shaft.end.x - 6.0, _shaft.end.y - SAND_H - 6.0)))
	sand.append(Vector2(_shaft.end.x - 6.0, _shaft.end.y - 8.0))
	b.polygon(sand, Art.SAND)
	Art.shell(b, Vector2(mid, _shaft.end.y - SAND_H - 22.0), 11.0)
	# A few bubbles standing in the water.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 6:
		var at := Vector2(rng.randf_range(_shaft.position.x + 14.0, _shaft.end.x - 14.0),
			rng.randf_range(_shaft.position.y + 30.0, _shaft.end.y - SAND_H - 70.0))
		Art.bubble(b, at, rng.randf_range(3.0, 6.5), 0.5)
	# The clock's track.
	b.fan(Face.Builder.round_rect(_clock.position, _clock.size, CLOCK_H * 0.5), Pal.SURFACE_HI)
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
	if _live_dirty or now < _anim_until or _phase == Phase.PLAY:
		# Not while the card is still growing in: the live parts are laid where
		# the card will stand.
		_live = _build_live(now) if (Motion.reduce or since >= Motion.ENTER_POP) else null
		_live_dirty = false
	if _live != null:
		draw_mesh(_live, null)
		shown.append(_live)
	_shown = shown

## What the prompt on the card came to, {} while it stands.
func _result() -> Dictionary:
	return state.results[state.index] if state.answered() else {}

## The share of the clock that is left.
func _clock_share() -> float:
	var full: float = State.AIR if state.band >= 3 else float(State.SECONDS[state.band])
	return clampf(state.time_left / maxf(1.0, full), 0.0, 1.0)

func _clock_colour() -> Color:
	if state.time_left <= float(LAST_SECONDS):
		return Pal.BERRY
	return Pal.ACCENT

## The field's sideways shiver after an answer the list did not hold.
func _field_dx(now: float) -> float:
	return 0.0 if Motion.reduce else Motion.shiver_offset(now - _miss_at, 9.0, 0.32)

## The field's look: [face, rim].
func _field_look() -> Array:
	if _phase == Phase.REVEAL and state.answered():
		var t := int(_result().t)
		return [Art.tier_tile(t), Art.tier(t)]
	if _phase == Phase.PLAY:
		return [Pal.SUN_TILE, Pal.SUN_DEEP]
	return [Pal.SURFACE_HI, Pal.LINE]

func _build_live(now: float) -> ArrayMesh:
	if not _dealt or state.count() == 0:
		return null
	var b := Face.Builder.new()
	# The clock's bar.
	var share := _clock_share()
	if share > 0.0:
		var w := maxf(CLOCK_H, _clock.size.x * share)
		b.fan(Face.Builder.round_rect(_clock.position, Vector2(w, CLOCK_H), CLOCK_H * 0.5), _clock_colour())
	# The line the answer is typed on.
	var look := _field_look()
	var at := _field.position + Vector2(_field_dx(now), 0.0)
	var grow := 1.0
	if not Motion.reduce and _phase == Phase.REVEAL:
		grow = Motion.bump_scale(now - _answer_at, 0.06)
	var fxf := Transform2D(0.0, Vector2(grow, grow), 0.0, at + _field.size * 0.5)
	var half := _field.size * 0.5
	b.fan(fxf * Face.Builder.round_rect(-half + Vector2(0.0, PANEL_LIP), _field.size, FIELD_RADIUS), Color(look[1] as Color, 0.8))
	b.fan(fxf * Face.Builder.round_rect(-half, _field.size, FIELD_RADIUS), look[1])
	b.fan(fxf * Face.Builder.round_rect(-half + Vector2.ONE * 3.0, _field.size - Vector2.ONE * 6.0, FIELD_RADIUS - 3.0), look[0])
	if _phase == Phase.REVEAL and state.answered():
		var t := int(_result().t)
		var mark := fxf * Vector2(-half.x + 50.0, 0.0)
		b.disc(mark, 26.0, Art.tier(t))
		if t < 0:
			Art.cross(b, mark, 22.0, Pal.SURFACE)
		elif t >= State.PEARL:
			Art.pearl(b, mark, 15.0)
		else:
			Art.tick(b, mark, 22.0, Pal.SURFACE)
	# The rope and the bell, and a mark where each answer left it.
	var x := _shaft.get_center().x
	var metres := 0
	for k in state.results.size():
		var r: Dictionary = state.results[k]
		metres += int(r.m)
		if int(r.t) >= 0 and (k < state.index or now - _answer_at >= DIVE_TIME or Motion.reduce):
			Art.pip(b, Vector2(_shaft.position.x + 16.0, _depth_y(metres)), 7.0, int(r.t))
	var y := _depth_y(_depth_shown(now))
	b.stroke(PackedVector2Array([Vector2(x, _shaft.position.y + 4.0), Vector2(x, y - BELL_R)]), 3.0, Color(Art.NACRE, 0.85))
	Art.bell(b, Vector2(x, y), BELL_R)
	return b.mesh()

# --- the words ---

## The largest of `sizes` at which `text` wraps into `room`; the smallest
## when none does.
static func _fit(font: Font, text: String, room: Vector2, sizes: Array) -> int:
	for s: int in sizes:
		if font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, room.x, s).y <= room.y:
			return s
	return int(sizes.back())

## The largest of `sizes` at which `text` fits `wide` on one line.
static func _fit_line(font: Font, text: String, wide: float, sizes: Array) -> int:
	for s: int in sizes:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, s).x <= wide:
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
		# Waiting on the day's prompts: one quiet line where they will be.
		if daily_key != 0 and Backend.started():
			_write(CozyTheme.body(600), tr("PD_FETCHING"), _panel, ASK_FONTS[4], Pal.TEXT_DIM)
		_hud_shown = shown
		return
	var since := now - _opened - Motion.ENTER_DELAY
	if since < 0.0 and not Motion.reduce:
		_hud_shown = shown
		return
	var alpha := 1.0 if Motion.reduce else Motion.appear_level(since)
	_draw_pills(now, alpha, shown)
	_draw_paper(now, alpha)
	_draw_depths(alpha)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_draw_toast(now, shown)
	_hud_shown = shown

## Left: which prompt, with a pip each in what it came to. Right: the depth.
func _draw_pills(now: float, alpha: float, shown: Array) -> void:
	var font: Font = CozyTheme.display(700)
	var y := _card.position.y + HUD_ROW * 0.5 + 6.0
	var n: int = state.count()
	var left_text := tr("PD_ROUND") % [mini(state.index + 1, n), n]
	var right_text := tr("PD_METRES") % int(round(_depth_shown(now)))
	var lw := font.get_string_size(left_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT).x
	var rw := font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT).x
	var pip := 16.0
	var pip_gap := 7.0
	var pips_w := n * pip + (n - 1) * pip_gap
	var icon := PILL_H * 0.72
	var boxes := [Vector2(lw + pips_w + 56.0, PILL_H), Vector2(rw + icon + 46.0, PILL_H)]
	var centres := [Vector2(_card.position.x + PAD + boxes[0].x * 0.5, y),
		Vector2(_card.end.x - PAD - boxes[1].x * 0.5, y)]
	var b := Face.Builder.new()
	for k in 2:
		var s := 1.0 if Motion.reduce else Motion.bump_scale(now - float(_pill_bump[k]), 0.12)
		var box: Vector2 = boxes[k] * s
		var c: Vector2 = centres[k]
		b.polygon(Face.Builder.round_rect(c - box * 0.5 - Vector2.ONE * 2.0, box + Vector2.ONE * 4.0, box.y * 0.5 + 2.0), Pal.LINE)
		b.polygon(Face.Builder.round_rect(c - box * 0.5, box, box.y * 0.5), Pal.SURFACE)
	var pips_x: float = centres[0].x - boxes[0].x * 0.5 + 22.0 + lw + 14.0
	for k in n:
		var c := Vector2(pips_x + pip * 0.5 + k * (pip + pip_gap), y)
		if k < state.results.size():
			Art.pip(b, c, pip * 0.5, int(state.results[k].t))
		else:
			b.disc(c, pip * 0.5, Pal.TEXT_DIM if k == state.index else Pal.LINE)
	var pearl_at: Vector2 = centres[1] + Vector2(-boxes[1].x * 0.5 + 18.0 + icon * 0.4, 0.0)
	Art.pearl(b, pearl_at, icon * 0.4)
	var pills := b.mesh()
	_hud_layer.draw_mesh(pills, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	shown.append(pills)
	var mid := (font.get_ascent(PILL_FONT) - font.get_descent(PILL_FONT)) * 0.5
	_hud_layer.draw_string(font, Vector2(centres[0].x - boxes[0].x * 0.5 + 22.0, y + mid), left_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT, Color(Pal.TEXT, alpha))
	_hud_layer.draw_string(font, pearl_at + Vector2(icon * 0.5 + 8.0, mid), right_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT, Color(Pal.TEXT, alpha))

## The water's two figures: the surface and the floor.
func _draw_depths(alpha: float) -> void:
	if state.count() == 0:
		return
	var font: Font = CozyTheme.display(700)
	_hud_layer.draw_string(font, Vector2(_shaft.position.x, _shaft.end.y - 17.0), tr("PD_METRES") % state.floor_depth(),
		HORIZONTAL_ALIGNMENT_CENTER, _shaft.size.x, DEPTH_FONT, Color(Pal.TEXT, alpha * 0.8))

## The paper: the clock at its head, the prompt, the line the answer is typed
## on, and under it what the answer came to.
func _draw_paper(now: float, alpha: float) -> void:
	if state.count() == 0:
		return
	var display: Font = CozyTheme.display(700)
	var body: Font = CozyTheme.body(600)
	# The clock's figure, right of its bar.
	var secs := int(ceil(state.time_left))
	var mid := (display.get_ascent(CLOCK_FONT) - display.get_descent(CLOCK_FONT)) * 0.5
	_hud_layer.draw_string(display, Vector2(_clock.end.x + 8.0, _clock.get_center().y + mid), str(secs),
		HORIZONTAL_ALIGNMENT_RIGHT, CLOCK_ROOM - 8.0, CLOCK_FONT, Color(_clock_colour().darkened(0.15), alpha))
	var a := alpha
	if not Motion.reduce:
		if _phase == Phase.SWAP:
			a *= clampf(1.0 - (now - _swap_at) / SWAP_OUT, 0.0, 1.0)
		else:
			a *= Motion.appear_level(now - _round_at, 0.2)
	var ask_box := Rect2(_panel.position.x + 34.0, _clock.end.y + 18.0, _panel.size.x - 68.0,
		_field.position.y - _clock.end.y - 36.0)
	if now >= _stamp_at:
		# The seal takes the paper's top right corner; the prompt makes room.
		ask_box.size.x -= _seal_rad() * 2.0 - 24.0
	var foot := Rect2(ask_box.position.x, _field.end.y + 16.0, _panel.size.x - 68.0, _panel.end.y - _field.end.y - 30.0)
	if a <= 0.0:
		return
	if _phase == Phase.READY:
		var lead := tr("PD_READY_BREATH") % [state.count(), int(State.AIR)] if state.band >= 3 \
			else tr("PD_READY") % [state.count(), int(State.SECONDS[state.band])]
		_write(display, lead, ask_box, _fit(display, lead, ask_box.size, ASK_FONTS), Color(Pal.TEXT, a))
		_write(display, tr("PD_READY_FIELD"), Rect2(_field.position, _field.size), TYPE_FONTS[3], Color(Pal.TEXT_DIM, a))
		_write(body, tr("PD_READY_FOOT") % int(State.MISS_COST), foot, FOOT_FONT, Color(Pal.TEXT_DIM, a))
		return
	var ask: String = state.ask()
	_write(display, ask, ask_box, _fit(display, ask, ask_box.size, ASK_FONTS), Color(Pal.TEXT, a))
	if _phase == Phase.REVEAL and state.answered():
		_draw_reveal(now, a, foot)
		return
	# The line being typed, with its caret.
	var dx := _field_dx(now)
	var room := _field.size.x - 60.0
	if _typed == "":
		_write(display, tr("PD_TYPE"), Rect2(_field.position, _field.size), TYPE_FONTS[3], Color(Pal.TEXT_DIM, a * 0.8))
	else:
		var shown_text := _typed.to_upper()
		var fs := _fit_line(display, shown_text, room, TYPE_FONTS)
		var w := display.get_string_size(shown_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
		var base := _field.get_center().y + (display.get_ascent(fs) - display.get_descent(fs)) * 0.5
		var x := _field.get_center().x - w * 0.5 + dx
		_hud_layer.draw_string(display, Vector2(x, base), shown_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color(Pal.TEXT, a))
		if _phase == Phase.PLAY and (Motion.reduce or fmod(now, CARET_PERIOD) < CARET_PERIOD * 0.55):
			_hud_layer.draw_rect(Rect2(x + w + 5.0, _field.get_center().y - fs * 0.42, 4.0, fs * 0.84), Color(Pal.SUN_DEEP, a))
	var told: Dictionary = state.told()
	if not told.is_empty():
		var line := tr("PD_HINT_LINE") % [str(told.first), int(told.letters)]
		_write(body, line, foot, FOOT_FONT, Color(Art.tier(State.PEARL).darkened(0.15), a))

## What the answer came to: its name on the line with what it dived, its
## tier under it, and then the Pearl and two more that were deep.
func _draw_reveal(now: float, a: float, foot: Rect2) -> void:
	var display: Font = CozyTheme.display(700)
	var body: Font = CozyTheme.body(600)
	var res := _result()
	var t := int(res.t)
	var ink := Art.tier(t).darkened(0.25)
	var shown_name := tr("PD_DRY") if t < 0 else state.answer_name(state.index, int(res.a))
	if t >= 0 and shown_name == "":
		shown_name = tr("PD_TIER_%d" % t)
	var gain := "" if t < 0 else tr("PD_GAIN") % int(res.m)
	var gain_w := display.get_string_size(gain, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TYPE_FONTS[2]).x
	var left := _field.position.x + 90.0
	var room := _field.end.x - 26.0 - gain_w - 14.0 - left
	var fs := _fit_line(display, shown_name, room, TYPE_FONTS)
	var base := _field.get_center().y + (display.get_ascent(fs) - display.get_descent(fs)) * 0.5
	_hud_layer.draw_string(display, Vector2(left, base), shown_name, HORIZONTAL_ALIGNMENT_LEFT, room, fs, Color(ink, a))
	if gain != "":
		var gb := _field.get_center().y + (display.get_ascent(TYPE_FONTS[2]) - display.get_descent(TYPE_FONTS[2])) * 0.5
		_hud_layer.draw_string(display, Vector2(_field.end.x - 26.0 - gain_w, gb), gain, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			TYPE_FONTS[2], Color(ink, a))
	var wa := a if Motion.reduce else a * Motion.appear_level(now - _answer_at - 0.2, 0.25)
	if wa <= 0.0:
		return
	var lines := []
	if t >= State.PEARL:
		lines.append([display, tr("PD_FOUND_PEARL"), TIER_FONT, ink])
	else:
		if t >= 0:
			lines.append([display, tr("PD_TIER_%d" % t), TIER_FONT, ink])
		lines.append([body, tr("PD_PEARL_WAS") % state.pearl_name(), FOOT_FONT, Art.tier(State.PEARL).darkened(0.2)])
	var deep: Array = state.deep_names(state.index, 2)
	if not deep.is_empty():
		lines.append([body, tr("PD_ALSO_DEEP") % " · ".join(PackedStringArray(deep)), FOOT_FONT - 2, Pal.TEXT_DIM])
	var last: bool = state.index + 1 >= state.count()
	if _enter_line and not is_done():
		lines.append([body, tr("PD_ENTER_DONE") if last else tr("PD_ENTER_NEXT"), FOOT_FONT - 4, Color(Pal.TEXT_DIM, 0.8)])
	var tall := 0.0
	for l: Array in lines:
		tall += (l[0] as Font).get_height(int(l[2])) + 6.0
	var y := foot.position.y + maxf(0.0, (foot.size.y - tall) * 0.5)
	for l: Array in lines:
		var f: Font = l[0]
		var size_px := _fit_line(f, str(l[1]), foot.size.x, [int(l[2]), int(l[2]) - 4, int(l[2]) - 8])
		_hud_layer.draw_string(f, Vector2(foot.position.x, y + f.get_ascent(size_px)), str(l[1]),
			HORIZONTAL_ALIGNMENT_CENTER, foot.size.x, size_px, Color(l[3] as Color, wa))
		y += f.get_height(int(l[2])) + 6.0

## A line the player has to see now, on a dark pill over the paper's foot.
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
	var room := _panel.size.x - 40.0
	var wide := minf(room, font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x + TOAST_PAD)
	var key := "%s|%d" % [_toast, int(wide)]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-wide, -TOAST_H) * 0.5, Vector2(wide, TOAST_H), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh()
		_toast_mesh_for = key
	shown.append(_toast_mesh)
	var mid := Vector2(_panel.get_center().x, _panel.end.y - 18.0 - TOAST_H * 0.5)
	_hud_layer.draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha * 0.94))
	var base := mid.y - font.get_height(TOAST_FONT) * 0.5 + font.get_ascent(TOAST_FONT)
	_hud_layer.draw_string(font, Vector2(mid.x - wide * 0.5, base), _toast, HORIZONTAL_ALIGNMENT_CENTER, wide,
		TOAST_FONT, Color(Pal.PAPER, alpha))

func _bump_pill(k: int) -> void:
	_pill_bump[k] = _now()
	_hud_layer.queue_redraw()

# --- input ---

## Touch and mouse, as every flat board takes them (touch is not mouse here:
## emulate_mouse_from_touch is off). The card takes one tap: to dive, and
## once an answer is out, to ask the next. The typing is the keyboard's.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed and _card.has_point(event.position):
			if _phase == Phase.READY:
				start_dive()
			elif _phase == Phase.REVEAL and _now() - _answer_at > NEXT_AFTER:
				next_prompt()

## A key of the tray under the card (ui/flat/flat_host.gd sends the three).
func type_letter(letter: String) -> void:
	if _phase != Phase.PLAY or is_done() or out_of_hearts:
		return
	if _typed.length() >= State.TYPE_MAX:
		return
	_typed += letter
	_hud_layer.queue_redraw()

func erase_letter() -> void:
	if _phase != Phase.PLAY or is_done() or out_of_hearts or _typed == "":
		return
	_typed = _typed.substr(0, _typed.length() - 1)
	_hud_layer.queue_redraw()

## Enter: dives, offers the line, and once an answer is out asks the next.
func commit_row() -> void:
	if is_done() or out_of_hearts or not _dealt:
		return
	match _phase:
		Phase.READY:
			start_dive()
		Phase.PLAY:
			offer()
		Phase.REVEAL:
			next_prompt()

## The first prompt is asked and the clock runs.
func start_dive() -> void:
	if _phase != Phase.READY or is_done():
		return
	_phase = Phase.PLAY
	_round_at = _now()
	_whole = int(ceil(state.time_left))
	fx.cue("dive")
	_busy_for(0.4)
	_redraw()
	_hud_layer.queue_redraw()
	focus_changed.emit()

## The typed line, offered as the answer.
func offer() -> void:
	if _phase != Phase.PLAY or is_done() or out_of_hearts:
		return
	var now := _now()
	var before: int = state.depth()
	var said := _typed.to_upper()
	var res: Dictionary = state.guess(_typed)
	if res.is_empty():
		return
	if not bool(res.hit):
		if bool(res.get("short", false)):
			_tell(tr("PD_TYPE_FIRST"))
			fx.cue("refuse")
			return
		_typed = ""
		_miss_at = now
		checks += 1
		_tell(tr("PD_MISS") % [said, int(State.MISS_COST)])
		fx.cue("miss")
		_busy_for(0.4)
		if bool(res.get("ran", false)):
			_ran_out()
		_redraw()
		_hud_layer.queue_redraw()
		return
	_typed = ""
	_toast = ""
	_phase = Phase.REVEAL
	_answer_at = now
	_dive_at = now
	_dive_from = float(before)
	checks += 1
	moves += 1
	var t := int(res.t)
	fx.cue("pearl" if t >= State.PEARL else ("deep" if t >= 2 else "hit"))
	var at := Vector2(_shaft.get_center().x, _depth_y(float(state.depth())))
	_after(0.0 if Motion.reduce else DIVE_TIME * 0.8, func() -> void:
		fx.ring(at, BELL_R * 1.8, Art.tier(t))
		if t >= State.PEARL:
			fx.sparkle(at, Pal.SUN)
		_bump_pill(1))
	if float(res.air) > 0.0:
		_after(0.25, func() -> void: fx.cue("air_back"))
	_bump_pill(0)
	_busy_for(DIVE_TIME + 0.6)
	_redraw()
	_hud_layer.queue_redraw()
	moved.emit()
	focus_changed.emit()

## The clock ran out: the prompt is dry, or on One Breath the dive is over.
func _ran_out() -> void:
	var now := _now()
	_typed = ""
	if state.out:
		out_of_hearts = true
		_running = false
		fx.cue("out_of_air")
		_tell(tr("PD_OUT"))
		_after(Motion.REDUCED_TIME if Motion.reduce else CARD_AFTER, _open_card)
	else:
		_phase = Phase.REVEAL
		_answer_at = now
		_dive_at = now
		_dive_from = float(state.depth())
		moves += 1
		fx.cue("dry")
		_bump_pill(0)
		moved.emit()
	_busy_for(0.6)
	_redraw()
	_hud_layer.queue_redraw()
	focus_changed.emit()

## Asks the next prompt, or after the last one ends the day.
func next_prompt() -> void:
	if _phase != Phase.REVEAL or is_done() or out_of_hearts:
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
	_busy_for(out + 0.4)
	_after(out, func() -> void:
		if _phase != Phase.SWAP or not state.advance():
			return
		_phase = Phase.PLAY
		_round_at = _now()
		_answer_at = -INF
		_whole = int(ceil(state.time_left))
		_bump_pill(0)
		_redraw()
		_hud_layer.queue_redraw()
		focus_changed.emit())
	_redraw()
	_hud_layer.queue_redraw()
	focus_changed.emit()
	moved.emit()

# --- the HUD's actions ---

func hints_left() -> int:
	return State.HINTS_BY[state.band] + hints_extra - hints_used

## The bulb tells the Pearl's first letter and how long it is.
func hint() -> bool:
	if is_done() or out_of_hearts or _phase != Phase.PLAY or hints_left() <= 0:
		return false
	var told: Dictionary = state.tell()
	if told.is_empty():
		_tell(tr("PD_HINT_USED"))
		fx.cue("refuse")
		return false
	hints_used += 1
	fx.cue("hint")
	fx.sparkle(Vector2(_shaft.get_center().x, _shaft.end.y - SAND_H - 22.0), Pal.SUN)
	_busy_for(0.5)
	_hud_layer.queue_redraw()
	moved.emit()
	return true

## An answer is final and a prompt is not asked twice: Reset has nothing to
## give on this board.
func can_reset() -> bool:
	return false

func reset_board() -> void:
	pass

func is_solved() -> bool:
	return _settled and state.is_solved()

func completion_record() -> Dictionary:
	var given := []
	var tiers := []
	for r: Dictionary in state.results:
		given.append(int(r.a))
		tiers.append(int(r.t))
	return {"given": given, "tiers": tiers, "set": state.set_id()}

## A completed daily is put back on its last prompt, answered. From the
## day's prompts if this phone still holds them and from the bank if not;
## when those are not the prompts that were answered, the answers are let go
## and only how deep each went is kept.
func restore_completed_board() -> void:
	var now := _now()
	_gen += 1
	_dealt = true
	var key := daily_key if daily_key != 0 else _seed_key
	if not state.setup_day(Backend.cached_day(State.GAME, key) if daily_key != 0 else {}, key, state.band):
		state.setup(key, state.band)
	var same := int(completed_record.get("set", 0)) == state.set_id()
	state.finish(completed_record.get("given", []) if same else [], completed_record.get("tiers", []))
	state.time_left = 0.0
	_clear()
	_phase = Phase.REVEAL
	_settled = true
	_opened = now - 10.0
	_round_at = now - 10.0
	_answer_at = now - 10.0
	_dive_at = now - 10.0
	_anim_until = 0.0
	_layout()
	_stamp_at = now - 10.0 if _stamped() else INF
	_hud_layer.queue_redraw()
	_redraw()

func share_glyphs() -> String:
	return "%s\n🦪 %d m" % [state.share_glyphs(), state.depth()]

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("PD_WIN_SUB") % [state.depth(), state.floor_depth()]}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## A dive past the middle of the water is stamped, and so is any One Breath
## that came back up.
func _stamped() -> bool:
	return state.band >= 3 or state.depth() * 2 >= state.floor_depth()

func _on_solved() -> void:
	var now := _now()
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
	return minf(_panel.size.x * 0.13, (_field.position.y - _clock.end.y) * 0.42)

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
	var centre := Vector2(_panel.end.x - rad * 0.92, _clock.end.y + 10.0 + rad * 0.92)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_hud_layer.draw_set_transform_matrix(xf)
	_hud_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_hud_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02], [tr("PD_SEAL_BREATH"), 0.17, 0.36]]
	else:
		lines = [[tr("PD_SEAL_DEEP"), 0.24, 0.12]]
	Seal.text(_hud_layer, rad, lines)
	_hud_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

# --- One Breath's air ---

## The card, over the whole screen: on the host so it covers the chrome, or
## on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not is_inside_tree() or not out_of_hearts or is_done() or is_instance_valid(_out_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_air_used, ["PD_OUT_BODY", "PD_OUT_BODY_PLAIN"], 0,
		{"title": "PD_OUT_TITLE", "more": "PD_MORE_AIR"})
	_out_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(air_back)
	card.leave.connect(_leave)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: a new dive, since every answer of the lost one has been seen.
## A full tank, clock from zero.
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

## More air (the card's video): once a board. The prompt that was on the
## card when the air ran out is asked again.
func air_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_air_used = true
	state.more_air()
	out_of_hearts = false
	_running = true
	_phase = Phase.PLAY
	_typed = ""
	_whole = int(ceil(state.time_left))
	fx.cue("air_back")
	_redraw()
	_hud_layer.queue_redraw()
	moved.emit()

func _leave() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_out_card) and not _out_card.is_queued_for_deletion():
		_out_card.queue_free()
	_out_card = null

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

## True while a prompt is being dealt or changed: the host holds its video
## offer until the board is still.
func busy() -> bool:
	return _phase == Phase.SWAP or _phase == Phase.WAIT

func _process(delta: float) -> void:
	super(delta)
	if not _dealt:
		return
	var now := _now()
	if _phase == Phase.PLAY and _running and not clock_held and not out_of_hearts and now >= _round_at:
		var ran: bool = state.tick(delta)
		var whole := int(ceil(state.time_left))
		if whole < _whole and whole <= LAST_SECONDS and whole > 0:
			fx.cue("tick")
		_whole = whole
		if ran:
			_ran_out()
	if now < _anim_until or _phase == Phase.PLAY:
		queue_redraw()
		_hud_layer.queue_redraw()
	elif (_toast != "" and now - _toast_at < TOAST_HOLD + 0.1) \
			or now - float(_pill_bump[0]) < Motion.BUMP_TIME + 0.1 \
			or now - float(_pill_bump[1]) < Motion.BUMP_TIME + 0.1:
		_hud_layer.queue_redraw()

func _redraw() -> void:
	_live_dirty = true
	queue_redraw()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
