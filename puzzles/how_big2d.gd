extends "res://core/puzzle_base.gd"

## How Big? as a flat board: a sky of paper over a strip of grass, and two
## silhouettes standing on it. The one on the left is the ruler -- ink, at a
## stated size, with a bracket over what the number measures. The one on the
## right is white and plainly the wrong size: the finger pulls it bigger or
## smaller until the two look right together, and Lock ends the round. The
## white shape is left as an outline where the guess stood, the thing grows
## or shrinks to its true size in the colour of the grade, and a card says
## how far off it was. A few rounds make the day.
##
## It was the game's one turn, a 3D scene on a dock, removed with the 3D game
## on 2026-09-24; this is that game brought back as a board. The rules are in
## puzzles/how_big_state.gd, which this only draws; the shapes are
## ui/faces/how_big_art.gd's, cut from content/how_big_shapes.json.
##
## How it is drawn. `_still` is the card, the sky and the grass (a layout).
## `_live` is the round: both silhouettes, the brackets, the grip, and after
## a lock the outline and the truth. A silhouette is rebuilt at the size it
## stands rather than scaled, so `_live` is rebuilt on every frame the finger
## moves and on no other. The pills, the captions, the result card and the
## toast are a layer of their own.
##
## How it moves. The flat boards' vocabulary (core/motion.gd,
## docs/art/flat-motion.md) read as curves: the ruler drops in, the answer
## pops in a beat later, the grip sinks under the finger. This board's own:
## the truth growing out of the guess, the result card, the two things
## walking off before the next pair, and on the Ladder the thing just sized
## walking across to stand as the next ruler.

const State = preload("res://puzzles/how_big_state.gd")
const Art = preload("res://ui/faces/how_big_art.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Seal = preload("res://ui/flat/seal.gd")
const CozyTheme = preload("res://ui/theme.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"

# --- the card ---
const PAD := 30.0
## The strip the pills stand in over the stage.
const HUD_ROW := 76.0
## The grass under the ground line, where the captions are written.
const GROUND_H := 170.0
## The card is never taller than this many times its width.
const CARD_TALL := 1.22
const CARD_RADIUS := 26.0
const CARD_EDGE := 6.0
## Room each side of the stage for a standing bracket.
const GUTTER := 46.0
## Air kept over the tallest thing the stage will hold.
const HEADROOM := 26.0
const SKY := Pal.SKY_HORIZON
const INK := Pal.TEXT
const PAPER := Pal.SURFACE
const OUTLINE_W := 3.5
const BRACKET_W := 4.0
const BRACKET_OFF := 22.0
const GRIP_R := 26.0

# --- motion: what is this board's own ---
## The ruler drops in, and the answer pops in this much later.
const TGT_LAG := 0.16
## The truth grows out of the guess.
const REVEAL_TIME := 0.7
## The result card comes once the truth has landed.
const CARD_AT := 0.45
## A round's pair walks off, and the next comes on.
const SWAP_OUT := 0.26
const SWAP_IN := 0.3
## On the Ladder the thing just sized crosses to the ruler's place.
const CROSS_TIME := 0.5
## The last round is read before the day ends.
const LAST_HOLD := 1.5
## A step of the size's own clicks: one every time the answer has grown or
## shrunk by this ratio.
const NOTCH := 1.08
const WIN_WAIT := 0.9
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.13
const STAMP_TILT := -0.22
const CARD_AFTER := 1.6
const CARD_AFTER_STILL := 0.5
const PILL_FONT := 32
const PILL_H := 50.0
const NAME_FONT := 36
const SIZE_FONT := 30
const SCORE_FONT := 84
const VERDICT_FONT := 32
const FACT_FONT := 27
const TOAST_HOLD := 2.4
const TOAST_H := 76.0
const TOAST_PAD := 72.0
const TOAST_RADIUS := 26.0
const TOAST_FONT := 30

## What the phone does under each cue (docs/agents/haptics.md). The size's
## own clicks are the faintest thing the phone can do; a lock is a knock; a
## reveal is felt by its grade.
const HAPTICS := {
	"notch": Haptics.ECHO,
	"reset": Haptics.TAP,
	"next": Haptics.TICK,
	"lock": Haptics.BUMP,
	"spot": Haptics.GOOD,
	"close": Haptics.GOOD,
	"fair": Haptics.TAP,
	"off": Haptics.WARN,
	"hint": Haptics.GOOD,
	"heart_lost": Haptics.BAD,
	"heart_back": Haptics.GOOD,
	"out_of_hearts": Haptics.LOSE,
	"solved": Haptics.WIN,
}

enum Phase { PLAY, REVEAL, SWAP }

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

var _card := Rect2()
## Where things stand: its foot is the ground line.
var _stage := Rect2()
## Bumped on every rebuild; a pending callback from the last board checks it.
var _gen := 0
var _phase := Phase.PLAY
## The round's frame (State.frame) and the answer's longer side, in pixels.
var _frame := {}
var _px := 0.0
var _notch := 0
var _touched := false
var _settled := false

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
var _result_mesh: ArrayMesh
var _result_mesh_for := ""

# --- the finger ---
var _drag := false
var _drag_from := Vector2.ZERO
var _drag_px := 0.0
var _grip_at := -INF
var _grip_up := -INF

# --- the clocks ---
var _opened := -1.0e9
var _round_at := -1.0e9
var _lock_at := -INF
var _swap_at := -INF
## What walks off in a swap, and on the Ladder what crosses: the last
## round's two things as they stood.
var _old := {}
var _anim_until := 0.0
var _pill_bump := [-INF, -INF]
var _stamp_at := INF
var _toast := ""
var _toast_at := -100.0
var _hint_dir := 0
var _hint_at := -INF

func puzzle_id() -> String: return "how_big"
func title() -> String: return "How Big?"

func rules() -> String:
	var out := tr("HB_RULES") % state.round_count()
	if state.band == 0:
		out += "\n\n" + tr("HB_RULES_TAPE")
	if max_hearts > 0:
		out += "\n\n" + tr("HB_RULES_LADDER") % max_hearts
	return out

## The tutorial: each page is the board itself on a hand-picked pair
## (ui/hud/how_big_tutorial_diagram.gd). Loaded, not preloaded: the page's
## board extends this script.
func tutorial_pages() -> Array:
	var path := "res://ui/hud/how_big_tutorial_diagram.gd"
	if not ResourceLoader.exists(path):
		return []
	var Diagram = load(path)
	var hints: int = State.HINTS_BY[state.band]
	var steps := [
		[Diagram.Lesson.SIZE, "HTP_HB_SIZE", tr("HTP_HB_SIZE_BODY")],
		[Diagram.Lesson.LOCK, "HTP_HB_LOCK", tr("HTP_HB_LOCK_BODY")],
		[Diagram.Lesson.GRADE, "HTP_HB_GRADE", tr("HTP_HB_GRADE_BODY")]]
	if state.band == 0:
		steps.append([Diagram.Lesson.TAPE, "HTP_HB_TAPE", tr("HTP_HB_TAPE_BODY")])
	if max_hearts > 0:
		steps.append([Diagram.Lesson.LADDER, "HTP_HB_LADDER", tr("HTP_HB_LADDER_BODY")])
		steps.append([Diagram.Lesson.HEARTS, "HTP_HB_HEARTS", tr("HTP_HB_HEARTS_BODY") % max_hearts])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_HB_HINT",
			tr("HTP_HB_HINT_BODY_ONE") if hints == 1 else tr("HTP_HB_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Hint and Lock up to Hard; Lock alone on the Ladder. No Undo anywhere: a
## lock is the one move there is, and it is never taken back.
func capabilities() -> Array[String]:
	if state.band >= 3:
		return ["check"]
	return ["hint", "check"]

## The row's third button locks the round, then deals the next.
func check_label() -> String:
	if _phase == Phase.PLAY or state.index + 1 >= state.round_count():
		return "HB_LOCK"
	return "HB_NEXT"

func check_icon() -> String:
	return "check" if check_label() == "HB_LOCK" else "play"

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

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	state.setup(rng, difficulty)
	_begin()

## The day as `state` has it, from the top.
func _begin() -> void:
	max_hearts = State.HEARTS_BY[state.band]
	_heart_used = false
	_deal()
	_layout()
	_opened = _now()
	_round_at = _opened + (0.0 if Motion.reduce else Motion.ENTER_DELAY)
	_busy_for(Motion.ENTER_DELAY + Motion.DROP_TIME + TGT_LAG + Motion.POP_IN)
	fx.cue("enter")

func _deal() -> void:
	hearts = state.hearts
	out_of_hearts = false
	_phase = Phase.PLAY
	_settled = false
	_touched = false
	_drag = false
	_old = {}
	_lock_at = -INF
	_swap_at = -INF
	_stamp_at = INF
	_seal_mesh = null
	_toast = ""
	_hint_dir = 0
	_frame = {}

# --- layout ---

func _layout() -> void:
	if state.rounds.is_empty() or size.x <= 0.0:
		return
	var tall := card_height(size.y)
	_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
	var top := _card.position.y + HUD_ROW
	_stage = Rect2(_card.position.x + PAD, top, _card.size.x - 2.0 * PAD, _card.end.y - CARD_EDGE - GROUND_H - top)
	# The answer keeps the share of its range it had, whatever the card became.
	var share := -1.0
	if not _frame.is_empty() and _px > 0.0:
		share = _px / float(_frame.max)
	_frame = state.frame(_room())
	_px = float(_frame.start) if share < 0.0 or not _touched else clampf(share * float(_frame.max), float(_frame.min), float(_frame.max))
	if state.locked():
		_px = _px_of(float(state.results[state.index].guess))
	_notch = _notch_of(_px)
	_still = _build_still()
	_seal_mesh = null
	_redraw()
	_hud_layer.queue_redraw()

## What the stage has for things to stand in.
func _room() -> Vector2:
	return Vector2(_stage.size.x - 2.0 * GUTTER, _stage.size.y - HEADROOM)

func card_height(available: float) -> float:
	return minf(available, size.x * CARD_TALL)

func card_centred() -> bool:
	return true

## Where the ruler's box has its bottom left, and the answer's its bottom right.
func _ref_foot() -> Vector2:
	return Vector2(_stage.position.x + GUTTER, _stage.end.y)

func _tgt_foot() -> Vector2:
	return Vector2(_stage.end.x - GUTTER, _stage.end.y)

## The answer's box at `px` across its longer side.
func _tgt_box(px: float) -> Rect2:
	var s := Art.size_of(str(state.tgt().id))
	var k := px / maxf(s.x, s.y)
	return Rect2(_tgt_foot() - s * k, s * k)

func _ref_box() -> Rect2:
	var s: Vector2 = _frame.ref
	return Rect2(_ref_foot() - Vector2(0.0, s.y), s)

## The longer side the answer's box has when its measure reads `m`.
func _px_of(m: float) -> float:
	var tb := State.box_m(state.tgt(), m)
	return maxf(tb.x, tb.y) * float(_frame.ppm)

func _guess() -> float:
	return state.guess_at(_px, float(_frame.ppm))

func _notch_of(px: float) -> int:
	return int(floor(log(maxf(px, 1.0)) / log(NOTCH)))

## The corner of the answer's box the finger sizes by, for the harnesses and
## the tutorial: its top left.
func grip_point() -> Vector2:
	return _tgt_box(_px).position

## The point to drag the grip to for the answer to read `m`.
func grip_for(m: float) -> Vector2:
	return _tgt_box(clampf(_px_of(m), float(_frame.min), float(_frame.max))).position

# --- the still drawing ---

func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	b.fan(Face.Builder.round_rect(_card.position, _card.size, CARD_RADIUS), Pal.LEAF_DEEP)
	b.fan(Face.Builder.round_rect(_card.position, _card.size - Vector2(0.0, CARD_EDGE), CARD_RADIUS), Pal.MEADOW)
	# The sky: the card's top corners, and square where it meets the grass.
	var sky := Rect2(_card.position, Vector2(_card.size.x, _stage.end.y - _card.position.y))
	var pts := PackedVector2Array()
	var r := CARD_RADIUS
	pts.append(Vector2(sky.position.x, sky.end.y))
	var a := Face.Builder.arc_points(sky.position + Vector2(r, r), r, PI, PI * 1.5)
	pts.append_array(a)
	a = Face.Builder.arc_points(Vector2(sky.end.x - r, sky.position.y + r), r, -PI * 0.5, 0.0)
	pts.append_array(a)
	pts.append(sky.end)
	b.fan(pts, SKY)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261008
	for k in 3:
		var at := Vector2(sky.position.x + sky.size.x * (0.2 + 0.3 * k + 0.08 * rng.randf()),
			_stage.position.y + _stage.size.y * (0.1 + 0.16 * rng.randf()))
		Scenery.cloud(b, at, 30.0 + 14.0 * rng.randf(), Color(Color.WHITE, 0.7))
	# The turf's lip.
	b.stroke(PackedVector2Array([Vector2(_card.position.x, _stage.end.y), Vector2(_card.end.x, _stage.end.y)]),
		5.0, Pal.LEAF, false, false)
	return b.mesh()

# --- the drawing ---

func _draw() -> void:
	if _still == null or _frame.is_empty():
		return
	var now := _now()
	var shown: Array = []
	var since := now - _opened - Motion.ENTER_DELAY
	var seen := 1.0 if Motion.reduce else Motion.appear_level(since)
	var grown := 1.0 if Motion.reduce else Motion.wide_pop_scale(since)
	var centre := _card.get_center()
	var xf := Transform2D(0.0, Vector2(grown, grown), 0.0, centre) * Transform2D(0.0, -centre)
	if seen > 0.0:
		draw_mesh(_still, null, xf, Color(1.0, 1.0, 1.0, seen))
		shown.append(_still)
	if _live_dirty or now < _anim_until or _drag:
		_live = _build_live(now)
		_live_dirty = false
	if _live != null:
		draw_mesh(_live, null)
		shown.append(_live)
	_shown = shown

## The grade's colour: leaf for a near thing, sun for a fair one, berry for a miss.
static func grade_colour(score: int) -> Color:
	if score >= 78:
		return Pal.LEAF_DEEP
	if score >= 45:
		return Pal.SUN_DEEP
	return Pal.BERRY_DEEP

func _build_live(now: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var ref_id := str(state.ref().id)
	var tgt_id := str(state.tgt().id)
	var e := now - _round_at
	# A swap: the last pair walks off first, and nothing of the new one shows
	# until it has.
	if _phase == Phase.SWAP and not _old.is_empty():
		var u := clampf((now - _swap_at) / SWAP_OUT, 0.0, 1.0)
		var fade := 1.0 - u
		var slide := Vector2(-60.0 * u * u, 0.0)
		if not bool(_old.get("cross", false)):
			Art.fill(b, str(_old.tgt), Art.stand(str(_old.tgt), _tgt_foot() + slide, float(_old.tgt_px), true),
				Color(_old.tint, fade))
		Art.fill(b, str(_old.ref), Art.stand(str(_old.ref), _ref_foot() + slide, float(_old.ref_px)), Color(INK, fade))
		if bool(_old.get("cross", false)):
			# The thing just sized crosses the stage and turns to ink on the way.
			var cu := clampf((now - _swap_at) / CROSS_TIME, 0.0, 1.0)
			cu = cu * cu * (3.0 - 2.0 * cu)
			var box_from: Vector2 = Art.size_of(tgt_id_old()) * (float(_old.cross_from) / _long(tgt_id_old()))
			var box_to: Vector2 = _frame.ref
			var left_from := _tgt_foot().x - box_from.x
			var long_px := lerpf(float(_old.cross_from), maxf(box_to.x, box_to.y), cu)
			var foot := Vector2(lerpf(left_from, _ref_foot().x, cu), _stage.end.y - sin(PI * cu) * 26.0)
			Art.fill(b, tgt_id_old(), Art.stand(tgt_id_old(), foot, long_px), (_old.tint as Color).lerp(INK, cu))
		if e < 0.0:
			return _mesh_of(b)
	# The ruler: dropped in at the round's start (already standing when it
	# crossed over), ink, with its bracket.
	var ref_box := _ref_box()
	var ref_long := maxf(ref_box.size.x, ref_box.size.y)
	var crossed: bool = _phase == Phase.SWAP and bool(_old.get("cross", false))
	if not crossed:
		var lift := 0.0
		var alpha := 1.0
		var sc := 1.0
		if not Motion.reduce and e < Motion.DROP_TIME:
			lift = Motion.drop_in_lift(e, Motion.DROP, Motion.DROP_TIME)
			alpha = Motion.appear_level(e)
			sc = Motion.pop_in_scale(e, Motion.DROP_TIME).y
		if alpha > 0.0:
			Art.fill(b, ref_id, Art.stand(ref_id, _ref_foot() - Vector2(0.0, lift), ref_long * sc), Color(INK, alpha))
	var mark := 1.0 if Motion.reduce else Motion.appear_level(e - Motion.DROP_TIME, 0.2)
	if mark > 0.0:
		_bracket(b, state.ref(), ref_box, false, Color(Pal.TEXT_DIM, mark))
	# The answer.
	var te := e - TGT_LAG
	if te < 0.0 and not Motion.reduce:
		return _mesh_of(b)
	var pop := Vector2.ONE if Motion.reduce else Motion.pop_in_scale(te)
	var t_alpha := 1.0 if Motion.reduce else Motion.appear_level(te)
	if _phase == Phase.PLAY or not state.locked():
		var xf := Art.stand(tgt_id, _tgt_foot(), _px * pop.y, true)
		Art.fill(b, tgt_id, xf, Color(PAPER, t_alpha))
		Art.outline(b, tgt_id, xf, OUTLINE_W, Color(INK, t_alpha))
		_grip(b, now, t_alpha)
		return _mesh_of(b)
	# Locked: the truth grows out of the guess in the grade's colour, and the
	# guess stays behind as its outline.
	var res: Dictionary = state.results[state.index]
	var guess_px := _px_of(float(res.guess))
	var true_px := _px_of(float(res.truth))
	var u := 1.0
	if not Motion.reduce:
		u = clampf((now - _lock_at) / REVEAL_TIME, 0.0, 1.0)
		u = Motion.back_out(u)
	var show_px := lerpf(guess_px, true_px, u)
	var tint := grade_colour(int(res.score))
	Art.fill(b, tgt_id, Art.stand(tgt_id, _tgt_foot(), show_px, true), tint)
	Art.outline(b, tgt_id, Art.stand(tgt_id, _tgt_foot(), guess_px, true), OUTLINE_W, Color(INK, 0.55))
	var settled := 1.0 if Motion.reduce else Motion.appear_level(now - _lock_at - REVEAL_TIME * 0.7, 0.2)
	if settled > 0.0:
		_bracket(b, state.tgt(), _tgt_box(true_px), true, Color(tint, settled))
	return _mesh_of(b)

## `b`'s mesh, or none when nothing was drawn (an empty surface is an error).
static func _mesh_of(b: Face.Builder) -> ArrayMesh:
	return null if b.verts.is_empty() else b.mesh()

func tgt_id_old() -> String:
	return str(_old.tgt)

static func _long(id: String) -> float:
	var s := Art.size_of(id)
	return maxf(s.x, s.y)

## The bracket over what `it`'s number measures, on the box it stands in: up
## the outer side for a height, under the ground line for a length.
func _bracket(b: Face.Builder, it: Dictionary, box: Rect2, right: bool, colour: Color) -> void:
	var from := float(it.get("from", 0.0))
	var to := float(it.get("to", 1.0))
	if State.is_tall(it):
		var x := box.end.x + BRACKET_OFF if right else box.position.x - BRACKET_OFF
		Art.bracket(b, Vector2(x, box.end.y - from * box.size.y), Vector2(x, box.end.y - to * box.size.y),
			Vector2.RIGHT, colour, BRACKET_W)
	else:
		var y := box.end.y + BRACKET_OFF
		Art.bracket(b, Vector2(box.position.x + from * box.size.x, y), Vector2(box.position.x + to * box.size.x, y),
			Vector2.DOWN, colour, BRACKET_W)

## The grip on the answer's top left corner: it sinks under the finger, and
## wears the bulb's arrow for a while after a hint.
func _grip(b: Face.Builder, now: float, alpha: float) -> void:
	var at := _tgt_box(_px).position
	# Kept on the stage however small the answer gets.
	at = at.clamp(_stage.position + Vector2.ONE * GRIP_R, _stage.end - Vector2.ONE * GRIP_R)
	var k := 1.0
	if not Motion.reduce:
		if _drag:
			k = Motion.press_scale(now - _grip_at)
		else:
			k = Motion.press_scale(Motion.PRESS_TIME, now - _grip_up)
	var face := Pal.SUN
	var hinted := now - _hint_at
	if _hint_dir != 0 and hinted < TOAST_HOLD:
		face = Pal.LEAF if _hint_dir > 0 else Pal.CLOUD
		if not Motion.reduce:
			k *= Motion.bump_scale(hinted, 0.3)
	Art.grip(b, at, GRIP_R * k, Vector2(-1.0, -1.0), Color(face, alpha), Color(INK, alpha))

# --- the pills, the captions, the result ---

func _draw_hud() -> void:
	if _frame.is_empty():
		return
	var now := _now()
	var since := now - _opened - Motion.ENTER_DELAY
	if since < 0.0 and not Motion.reduce:
		return
	var shown: Array = []
	var alpha := 1.0 if Motion.reduce else Motion.appear_level(since)
	var font: Font = CozyTheme.display(700)
	var y := _card.position.y + HUD_ROW * 0.5 + 6.0
	# Left: the round, with a pip a round in its grade's colour. Right: the day's points.
	var n: int = state.round_count()
	var left_text := tr("HB_ROUND") % [mini(state.index + 1, n), n]
	var right_text := "%d" % state.total()
	var lw := font.get_string_size(left_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT).x
	var rw := font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT).x
	var pip := 16.0
	var pips_w := n * pip + (n - 1) * 8.0
	var icon := PILL_H * 0.8
	var boxes := [Vector2(lw + pips_w + 56.0, PILL_H), Vector2(rw + icon + 44.0, PILL_H)]
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
		var c := Vector2(pips_x + pip * 0.5 + k * (pip + 8.0), y)
		var tint := Pal.LINE
		if k < state.results.size() and (k < state.index or _phase != Phase.PLAY or state.locked()):
			tint = grade_colour(int(state.results[k].score))
		elif k == state.index:
			tint = Pal.TEXT_DIM
		b.disc(c, pip * 0.5, tint)
	var star_at: Vector2 = centres[1] + Vector2(-boxes[1].x * 0.5 + 16.0 + icon * 0.5, 0.0)
	b.polygon(Seal.star(star_at, icon * 0.5), Pal.SUN)
	# Insane's hearts, between the pills.
	for k in max_hearts:
		var c := Vector2(size.x * 0.5 + (k - (max_hearts - 1) * 0.5) * 46.0, y)
		var s := 1.0
		if not Motion.reduce and k == hearts:
			s = Motion.bump_scale(now - _heart_at, 0.4)
		Art.heart(b, c, 18.0 * s, Pal.HEART if k < hearts else Pal.LINE)
	var pills := b.mesh()
	_hud_layer.draw_mesh(pills, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	shown.append(pills)
	var mid := (font.get_ascent(PILL_FONT) - font.get_descent(PILL_FONT)) * 0.5
	_hud_layer.draw_string(font, Vector2(centres[0].x - boxes[0].x * 0.5 + 22.0, y + mid), left_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT, Color(Pal.TEXT, alpha))
	_hud_layer.draw_string(font, star_at + Vector2(icon * 0.5 + 8.0, mid), right_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT, Color(Pal.TEXT, alpha))
	_draw_captions(now, alpha)
	if state.locked() and _phase != Phase.SWAP:
		_draw_result(now, shown)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_draw_toast(now, shown)
	_hud_shown = shown

## A size the way a person says it: millimetres, centimetres or metres.
static func size_text(m: float) -> String:
	if m < 0.0095:
		return tr_s("HB_MM") % Locale.number(m * 1000.0, 1 if m < 0.003 else 0)
	if m < 0.995:
		return tr_s("HB_CM") % Locale.number(m * 100.0, 1 if m < 0.03 else 0)
	return tr_s("HB_M") % Locale.number(m, 1 if m < 9.95 else 0)

static func tr_s(key: String) -> String:
	return TranslationServer.translate(key)

## "1.6 m at the shoulder", "25 m long".
static func measure_text(it: Dictionary, m: float) -> String:
	var what := State.what_key(it)
	if what != "" and tr_s(what) != what:
		return tr_s(what) % size_text(m)
	return tr_s("HB_TALL" if State.is_tall(it) else "HB_LONG") % size_text(m)

static func name_of(it: Dictionary) -> String:
	return tr_s(str(it.get("label", "")))

## The two captions in the grass: the ruler's on the left, the answer's on
## the right -- a question mark until the lock (Easy reads the tape as it
## goes), then the truth and what the player said.
func _draw_captions(now: float, alpha: float) -> void:
	var name_font: Font = CozyTheme.display(700)
	var body: Font = CozyTheme.body(600)
	var e := now - _round_at
	var a := alpha
	if _phase == Phase.SWAP:
		a *= (1.0 - clampf((now - _swap_at) / SWAP_OUT, 0.0, 1.0)) if e < 0.0 else Motion.appear_level(e, 0.2)
	elif not Motion.reduce:
		a *= Motion.appear_level(e, 0.2)
	if a <= 0.0:
		return
	var showing_old := _phase == Phase.SWAP and e < 0.0 and not _old.is_empty()
	var ref_it: Dictionary = _old.ref_it if showing_old else state.ref()
	var tgt_it: Dictionary = _old.tgt_it if showing_old else state.tgt()
	var ref_m: float = float(_old.ref_m) if showing_old else state.ref_m
	var top := _stage.end.y + 44.0
	var left := _stage.position.x + 14.0
	var right := _stage.end.x - 14.0
	var half := _stage.size.x * 0.5 - 24.0
	var y1 := top + name_font.get_ascent(NAME_FONT)
	var y2 := y1 + 40.0
	var y3 := y2 + 34.0
	_hud_layer.draw_string(name_font, Vector2(left, y1), name_of(ref_it), HORIZONTAL_ALIGNMENT_LEFT, half, NAME_FONT, Color(Pal.TEXT, a))
	var ref_line := measure_text(ref_it, ref_m)
	_hud_layer.draw_string(body, Vector2(left, y2), ref_line, HORIZONTAL_ALIGNMENT_LEFT, half, SIZE_FONT, Color(Pal.TEXT, a))
	if state.band >= 3 and not showing_old and absf(ref_m - float(ref_it.size_m)) > 1e-6:
		_hud_layer.draw_string(body, Vector2(left, y3), tr("HB_YOUR_SIZE"), HORIZONTAL_ALIGNMENT_LEFT, half, SIZE_FONT - 4, Color(Pal.LEAF_DEEP, a))
	_hud_layer.draw_string(name_font, Vector2(right - half, y1), name_of(tgt_it), HORIZONTAL_ALIGNMENT_RIGHT, half, NAME_FONT, Color(Pal.TEXT, a))
	var line := "?"
	var ink := Pal.TEXT
	var said := ""
	if showing_old or state.locked():
		var res: Dictionary = _old.res if showing_old else state.results[state.index]
		line = measure_text(tgt_it, float(res.truth))
		ink = grade_colour(int(res.score)).darkened(0.25)
		said = tr("HB_YOU_SAID") % size_text(float(res.guess))
	elif state.band == 0:
		line = tr("HB_ABOUT") % size_text(_guess())
	_hud_layer.draw_string(body, Vector2(right - half, y2), line, HORIZONTAL_ALIGNMENT_RIGHT, half, SIZE_FONT, Color(ink, a))
	if said != "":
		_hud_layer.draw_string(body, Vector2(right - half, y3), said, HORIZONTAL_ALIGNMENT_RIGHT, half, SIZE_FONT - 4, Color(Pal.TEXT, a * 0.8))

## "30% too big", "12% too small", or the grade's own word inside the 6%.
static func verdict(res: Dictionary) -> String:
	var g := float(res.guess)
	var t := float(res.truth)
	if int(res.score) >= 100:
		return tr_s("HB_SPOT")
	if g > t:
		var over := g / t
		if over >= 2.0:
			return tr_s("HB_TIMES_BIG") % Locale.number(over, 1)
		return tr_s("HB_OVER") % Locale.number(round((over - 1.0) * 100.0))
	var under := t / g
	if under >= 2.0:
		return tr_s("HB_TIMES_SMALL") % Locale.number(under, 1)
	return tr_s("HB_UNDER") % Locale.number(round((1.0 - g / t) * 100.0))

## The result card at the head of the stage: the round's points, how far off,
## and a line about the thing.
func _draw_result(now: float, shown: Array) -> void:
	var e := now - _lock_at - CARD_AT
	if e < 0.0 and not Motion.reduce:
		return
	var res: Dictionary = state.results[state.index]
	var big: Font = CozyTheme.display(700)
	var body: Font = CozyTheme.body(600)
	var score_text := "+%d" % int(res.score)
	var verdict_text := verdict(res)
	if bool(res.missed):
		verdict_text += "  " + tr("HB_HEART_LOST")
	var fact := tr(State.fact_key(state.tgt()))
	if fact == State.fact_key(state.tgt()):
		fact = ""
	var wide := minf(_stage.size.x - 40.0, 760.0)
	var fact_h := 0.0
	if fact != "":
		fact_h = body.get_multiline_string_size(fact, HORIZONTAL_ALIGNMENT_CENTER, wide - 60.0, FACT_FONT).y + 14.0
	var tall := 26.0 + big.get_height(SCORE_FONT) * 0.82 + body.get_height(VERDICT_FONT) + fact_h + 22.0
	var key := "%d|%d" % [int(wide), int(tall)]
	if _result_mesh == null or _result_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-wide, -tall) * 0.5 + Vector2(0.0, 5.0), Vector2(wide, tall), 30.0), Color(Pal.LINE, 0.9))
		b.fan(Face.Builder.round_rect(Vector2(-wide, -tall) * 0.5, Vector2(wide, tall), 30.0), Pal.SURFACE)
		_result_mesh = b.mesh()
		_result_mesh_for = key
	shown.append(_result_mesh)
	var k := 1.0
	var alpha := 1.0
	if not Motion.reduce:
		k = Motion.pop_in_scale(e).y
		alpha = Motion.appear_level(e)
	var centre := Vector2(size.x * 0.5, _stage.position.y + 16.0 + tall * 0.5)
	var xf := Transform2D(0.0, Vector2(k, k), 0.0, centre)
	_hud_layer.draw_set_transform_matrix(xf)
	_hud_layer.draw_mesh(_result_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha * 0.97))
	var tint := grade_colour(int(res.score))
	var yy := -tall * 0.5 + 14.0 + big.get_ascent(SCORE_FONT) * 0.9
	_hud_layer.draw_string(big, Vector2(-wide * 0.5, yy), score_text, HORIZONTAL_ALIGNMENT_CENTER, wide, SCORE_FONT, Color(tint, alpha))
	yy += body.get_height(VERDICT_FONT) + 4.0
	_hud_layer.draw_string(body, Vector2(-wide * 0.5, yy), verdict_text, HORIZONTAL_ALIGNMENT_CENTER, wide, VERDICT_FONT, Color(Pal.TEXT, alpha))
	if fact != "":
		yy += 16.0 + body.get_ascent(FACT_FONT)
		_hud_layer.draw_multiline_string(body, Vector2(-wide * 0.5 + 30.0, yy), fact, HORIZONTAL_ALIGNMENT_CENTER,
			wide - 60.0, FACT_FONT, -1, Color(Pal.TEXT_DIM, alpha))
	_hud_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

## A line the player has to see now, on a dark pill over the foot of the stage.
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
	# Over the head of the stage: the finger works its foot.
	var mid := Vector2(size.x * 0.5, _stage.position.y + 24.0 + TOAST_H * 0.5)
	_hud_layer.draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha * 0.94))
	var base := mid.y - font.get_height(TOAST_FONT) * 0.5 + font.get_ascent(TOAST_FONT)
	_hud_layer.draw_string(font, Vector2(mid.x - wide * 0.5, base), _toast, HORIZONTAL_ALIGNMENT_CENTER, wide,
		TOAST_FONT, Color(Pal.PAPER, alpha))

func _bump_pill(k: int) -> void:
	_pill_bump[k] = _now()
	_hud_layer.queue_redraw()

# --- input ---

## Touch and mouse, as every flat board takes them (touch is not mouse here:
## emulate_mouse_from_touch is off). A finger anywhere on the card holds the
## answer by the point it pressed: pulled away from the answer's foot it
## grows, pushed toward it it shrinks. After a lock, a tap deals the next.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(event.position)
		else:
			_release()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _drag:
		drag_to(event.position)

func _press(at: Vector2) -> void:
	if is_done() or out_of_hearts or _frame.is_empty() or not _card.has_point(at):
		return
	if _phase == Phase.REVEAL:
		if _now() - _lock_at > CARD_AT + 0.25:
			next_round()
		return
	if _phase != Phase.PLAY:
		return
	_drag = true
	_drag_from = at
	_drag_px = _px
	_grip_at = _now()
	_busy_for(Motion.PRESS_TIME)
	_redraw()

func _release() -> void:
	if not _drag:
		return
	_drag = false
	_grip_up = _now()
	_busy_for(Motion.RELEASE_TIME)
	_redraw()
	focus_changed.emit()

## The finger is at `at`: the answer is as much bigger than it was at the
## press as the finger is further from the answer's foot. A press too near
## the foot to steer by reads the finger's rise instead.
func drag_to(at: Vector2) -> void:
	if not _drag or _phase != Phase.PLAY:
		return
	var foot := _tgt_foot()
	var d0 := (_drag_from - foot).length()
	var k := 1.0
	if d0 >= 90.0:
		k = (at - foot).length() / d0
	else:
		k = exp((_drag_from.y - at.y) / 260.0)
	set_px(_drag_px * k)

## The answer at `px` across its longer side, clamped to what the stage holds.
func set_px(px: float) -> void:
	var was := _px
	_px = clampf(px, float(_frame.min), float(_frame.max))
	if is_equal_approx(was, _px) and _touched:
		return
	_touched = true
	var notch := _notch_of(_px)
	if notch != _notch:
		_notch = notch
		# The size's own click: deeper the bigger the thing has become.
		var u := inverse_lerp(log(float(_frame.min)), log(float(_frame.max)), log(_px))
		fx.cue("notch", lerpf(1.35, 0.75, clampf(u, 0.0, 1.0)), -6.0)
	_redraw()
	_hud_layer.queue_redraw()

## Sizes the answer so its measure reads `m`: the harnesses' and the
## tutorial's way in.
func size_to(m: float) -> void:
	if _phase != Phase.PLAY or _frame.is_empty():
		return
	set_px(_px_of(m))

# --- the HUD's actions ---

func hints_left() -> int:
	return State.HINTS_BY[state.band] + hints_extra - hints_used

## The bulb says which way the truth lies from where the answer stands.
func hint() -> bool:
	if is_done() or out_of_hearts or _phase != Phase.PLAY or hints_left() <= 0:
		return false
	hints_used += 1
	_hint_dir = state.nudge(_guess())
	_hint_at = _now()
	var at := _tgt_box(_px).position
	if _hint_dir == 0:
		_tell(tr("HB_HINT_THERE"))
		fx.sparkle(at, Pal.SUN)
	else:
		_tell(tr("HB_HINT_BIGGER") if _hint_dir > 0 else tr("HB_HINT_SMALLER"))
		fx.ring(at, GRIP_R * 2.2, Pal.LEAF if _hint_dir > 0 else Pal.CLOUD)
	fx.cue("hint")
	_busy_for(TOAST_HOLD)
	_redraw()
	moved.emit()
	return true

## Lock, and after it Next. Always -1: there is nothing to count.
func check() -> int:
	if is_done() or out_of_hearts:
		return -1
	if _phase == Phase.PLAY:
		lock()
	elif _phase == Phase.REVEAL:
		next_round()
	return -1

## Ends the round on the size the answer stands at.
func lock() -> void:
	if _phase != Phase.PLAY or is_done() or out_of_hearts or _frame.is_empty():
		return
	var now := _now()
	if now - _round_at < TGT_LAG:
		return
	var res: Dictionary = state.lock(_guess())
	if res.is_empty():
		return
	_drag = false
	_phase = Phase.REVEAL
	_lock_at = now
	_toast = ""
	_hint_dir = 0
	checks += 1
	moves += 1
	fx.cue("lock")
	var score := int(res.score)
	var gen := _gen
	_after(0.0 if Motion.reduce else REVEAL_TIME * 0.75, func() -> void:
		if gen != _gen:
			return
		var at := _tgt_box(_px_of(float(res.truth))).get_center()
		if score >= 100:
			fx.cue("spot")
			fx.sparkle(at, Pal.SUN)
			fx.ring(at, 90.0, Pal.SUN)
		elif score >= 78:
			fx.cue("close")
			fx.ring(at, 80.0, Pal.LEAF)
		elif score >= 45:
			fx.cue("fair")
		else:
			fx.cue("off")
		_bump_pill(0)
		_bump_pill(1))
	if bool(res.missed):
		hearts = state.hearts
		_after(CARD_AT if not Motion.reduce else 0.0, func() -> void:
			_heart_at = _now()
			fx.cue("heart_lost")
			_hud_layer.queue_redraw())
	_busy_for(REVEAL_TIME + CARD_AT + Motion.POP_IN + 0.3)
	_redraw()
	_hud_layer.queue_redraw()
	moved.emit()
	if max_hearts > 0 and state.hearts <= 0:
		out_of_hearts = true
		_running = false
		_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _run_out)
	elif state.index + 1 >= state.round_count():
		_after(Motion.REDUCED_TIME if Motion.reduce else LAST_HOLD, _finish)

func _finish() -> void:
	_settled = true
	check_solved()

## Deals the next round: the pair walks off, and on the Ladder the thing
## just sized crosses over to be the ruler.
func next_round() -> void:
	if _phase != Phase.REVEAL or is_done() or out_of_hearts:
		return
	var res: Dictionary = state.results[state.index]
	var old := {"ref": str(state.ref().id), "tgt": str(state.tgt().id), "ref_it": state.ref(), "tgt_it": state.tgt(),
		"ref_m": state.ref_m, "res": res, "tint": grade_colour(int(res.score)),
		"ref_px": maxf(float(_frame.ref.x), float(_frame.ref.y)), "tgt_px": _px_of(float(res.truth))}
	if not state.advance():
		return
	var now := _now()
	# On the Ladder the thing crosses at the size it was given (the truth's,
	# if that lock cost a heart).
	if state.band >= 3:
		old["cross"] = true
		old["cross_from"] = _px_of_old(old, float(res.truth) if bool(res.missed) else float(res.guess))
	_old = old
	_phase = Phase.SWAP
	_swap_at = now
	_touched = false
	_frame = state.frame(_room())
	_px = float(_frame.start)
	_notch = _notch_of(_px)
	var out := 0.0 if Motion.reduce else (CROSS_TIME if state.band >= 3 else SWAP_OUT)
	_round_at = now + out
	_result_mesh = null
	fx.cue("next")
	_busy_for(out + Motion.DROP_TIME + TGT_LAG + Motion.POP_IN + 0.1)
	var gen := _gen
	_after(out + TGT_LAG, func() -> void:
		if gen == _gen and _phase == Phase.SWAP:
			_phase = Phase.PLAY
			_old = {}
			_redraw()
			_hud_layer.queue_redraw()
			focus_changed.emit())
	_bump_pill(0)
	_redraw()
	_hud_layer.queue_redraw()
	focus_changed.emit()
	moved.emit()

## The longer side `old`'s answer had on the old frame when it read `m`.
func _px_of_old(old: Dictionary, m: float) -> float:
	return float(old.tgt_px) * m / float(old.res.truth)

## Reset has something to give only while a round is being sized.
func can_reset() -> bool:
	return _phase == Phase.PLAY and _touched and not is_done() and not out_of_hearts

## Reset puts the answer back where the round began. A lock is not undone.
func reset_board() -> void:
	if is_done() or out_of_hearts or _phase != Phase.PLAY or _frame.is_empty():
		return
	_px = float(_frame.start)
	_notch = _notch_of(_px)
	_touched = false
	_tell(tr("HB_RESET"))
	fx.cue("reset")
	_redraw()
	_hud_layer.queue_redraw()

func is_solved() -> bool:
	return _settled and state.is_solved()

func completion_record() -> Dictionary:
	var scores := []
	var guesses := []
	for r: Dictionary in state.results:
		scores.append(int(r.score))
		guesses.append(float(r.guess))
	return {"scores": scores, "guesses": guesses}

## A completed daily is rebuilt from its seed: the last round goes back as
## it was left, locked and revealed, with the day's points.
func restore_completed_board() -> void:
	var now := _now()
	_gen += 1
	state.finish(completed_record.get("scores", []), completed_record.get("guesses", []))
	_deal()
	_phase = Phase.REVEAL
	_settled = true
	_opened = now - 10.0
	_round_at = now - 10.0
	_lock_at = now - 10.0
	_anim_until = 0.0
	_layout()
	_stamp_at = now - 10.0 if state.band >= 3 or state.sharp() else INF
	_hud_layer.queue_redraw()
	_redraw()

func share_glyphs() -> String:
	var out: String = state.share_glyphs()
	out += "\n📏 %d / %d" % [state.total(), state.best_total()]
	return out

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("HB_WIN_SUB") % [state.total(), state.best_total()]}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## The day is done: confetti off the ground line, and a day worth nine
## points in ten (or any Ladder climbed) is stamped.
func _on_solved() -> void:
	var now := _now()
	_drag = false
	_toast = ""
	fx.cue("solved")
	if state.band >= 3 or state.sharp():
		_stamp_at = now if Motion.reduce else now + Motion.SOLVE_DELAY
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_hud_layer.queue_redraw())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
	if not Motion.reduce:
		_after(Motion.SOLVE_DELAY, func() -> void:
			fx.confetti(Vector2(_stage.get_center().x, _stage.position.y + 60.0), 30, _stage.size.x * 0.8)
			fx.cue("party"))
	_busy_for(Motion.SOLVE_DELAY + STAMP_DROP * 2.0 + 0.3)
	_hud_layer.queue_redraw()
	_redraw()

## The seal in the grass, dropping in and settling.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := minf(_stage.size.x * STAMP_R, GROUND_H * 0.46)
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
	# In the grass between the two captions, clear of both things.
	var centre := Vector2(_stage.get_center().x, _stage.end.y + GROUND_H * 0.52)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_hud_layer.draw_set_transform_matrix(xf)
	_hud_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_hud_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02], [tr("HB_SEAL_SHARP") if state.sharp() else tr("HB_SEAL_LADDER"), 0.17, 0.36]]
	else:
		lines = [[tr("HB_SEAL_SHARP"), 0.24, 0.12]]
	Seal.text(_hud_layer, rad, lines)
	_hud_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

# --- Insane's hearts ---

func _run_out() -> void:
	if not out_of_hearts or is_done():
		return
	fx.cue("out_of_hearts")
	_tell(tr("HB_OUT"))
	_after(0.5, _open_card)

## The card, over the whole screen: on the host so it covers the chrome, or
## on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not is_inside_tree() or not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["HB_OUT_BODY", "HB_OUT_BODY_PLAIN"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same Ladder from its first rung, hearts full, clock from zero.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	_gen += 1
	moves = 0
	elapsed = 0.0
	checks = 0
	_running = true
	state.restart()
	_deal()
	_layout()
	_round_at = _now()
	_busy_for(Motion.DROP_TIME + TGT_LAG + Motion.POP_IN)
	fx.cue("reset")
	focus_changed.emit()
	moved.emit()

## One more heart (the card's video): once a board. The rung that cost the
## last heart stays locked, and the climb goes on from it.
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
	if state.index + 1 >= state.round_count():
		_finish()
	else:
		next_round()
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

## True while a round is being dealt or revealed: the host holds its video
## offer until the board is still.
func busy() -> bool:
	return _phase == Phase.SWAP

func _process(delta: float) -> void:
	super(delta)
	if _frame.is_empty():
		return
	var now := _now()
	if now < _anim_until or _drag:
		queue_redraw()
		_hud_layer.queue_redraw()
	elif (_toast != "" and now - _toast_at < TOAST_HOLD + 0.1) \
			or now - float(_pill_bump[0]) < Motion.BUMP_TIME + 0.1 \
			or now - float(_pill_bump[1]) < Motion.BUMP_TIME + 0.1 \
			or now - _heart_at < Motion.BUMP_TIME + 0.1:
		_hud_layer.queue_redraw()

func _redraw() -> void:
	_live_dirty = true
	queue_redraw()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
