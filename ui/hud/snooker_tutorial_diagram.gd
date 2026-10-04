extends Control

## One page of Snooker's tutorial: the top end of the table, played by the
## table itself. The page holds a `Cloth` -- versus/snooker_table.gd, deaf to
## the player's own hands -- over a sim and a referee of its own
## (versus/snooker_sim.gd, versus/snooker_rules.gd) with a hand-made few balls
## on it, and a finger that aims, draws the cue back and lets go through the
## table's own input. So the dotted line swings, the ruler fills beside the
## cue, the balls on glow, a red drops, the black comes back to its spot and a
## foul is called exactly as in a frame. The table is far taller than the
## page, so the page looks at its top end only, as wide as the slot, and the
## rest fades into the card. `lesson` picks the page (set before it enters the
## tree):
##
## - AIM: press the table to swing the line, draw the cue back, let go.
## - ORDER: a red, then a colour, which comes back while reds remain.
## - WORTH: what each ball is worth, and the colours' order once the reds
##   are gone (the table's own painted balls in a row: the whole table at
##   page size would make them specks).
## - FOUL: the wrong ball struck first, then the white lost in a pocket,
##   each with the referee's own line and penalty.
## - SPIN: the spin pad (versus/snooker_controls.gd) touched high, then low,
##   and the same shot following on, then coming back.
## - HINT: the bulb pressed, the gold line and the gold notch, the cue drawn
##   back to the notch.
## - HUD: the top bar's buttons, drawn as they are beside what they do.
##
## A page plays no sound and buzzes nothing: the screen's Fx2D is not here.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://versus/snooker_sim.gd")
const Rules = preload("res://versus/snooker_rules.gd")
const Table = preload("res://versus/snooker_table.gd")
const Controls = preload("res://versus/snooker_controls.gd")

enum Lesson { AIM, ORDER, WORTH, FOUL, SPIN, HINT, HUD }

## The room either side of the table and over it, the side column a page
## with a pad or a bulb keeps (the screen's own is 150), and how much of the
## page's foot fades into the card.
const PAD := 4.0
const TOP := 8.0
const COLUMN := 168.0
const FADE := 64.0
## The full draw of the cue on a page, px: the table's own is whatever room
## the screen leaves behind the cue, and a page has less.
const DRAW := 240.0
## Where along the cue the finger picks it up, metres behind the ball.
const GRAB := 0.16
const FINGER_R := 30.0
const FINGER_ALPHA := 0.16
const CAPTION_PX := 28
## The beats of a gesture, seconds.
const AIM_T := 1.0
const PULL_T := 0.8
## The worth page: how long a ball's turn is while they are counted, and
## while the colours go down in order.
const COUNT_STEP := 0.55
const ORDER_STEP := 0.85
const CHIP := 96.0

var lesson: int = Lesson.AIM
## The screen's own pull-to-pace curve (snooker_screen.gd `_speed_for`).
var pace := Callable()
## Hints a frame, for the bulb's badge.
var hints := 3

var sim: RefCounted
var rules: RefCounted
var _art: Cloth
var _pad: Control
var _kicker: Label
var _over: Control
var _fade: Control
var _pill: PanelContainer
var _caption: Label
var _clock: Timer
var _begun := false
var _running := false
## Bumped to stop the lesson's loop (a page turned away, a new start).
var _gen := 0
var _finger := Vector2(-1.0, -1.0)   # page-local; x < 0 is no finger
var _down := false
## A shot is on its way: the stroke, the roll and the referee.
var _busy := false
var _rolling := false
var _acc := 0.0
var _badge := 3
var _t := 0.0
var _said := ""
var _over_shown: ArrayMesh
var _fade_shown: ArrayMesh
var _page_shown: ArrayMesh

## The table, quiet: it takes no touch but the page's finger, and a full draw
## of the cue is the page's own length.
class Cloth extends "res://versus/snooker_table.gd":
	var room := 240.0

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _room(_at: Vector2, _d: Vector2) -> float:
		return room

	## The cue held drawn back at `p`, for a page that stands still.
	func hold(p: float) -> void:
		_reach = room
		power = p

	## Nothing left over from the last shot.
	func wipe() -> void:
		_trails.clear()
		_flashes.clear()
		_sinking.clear()
		_drag = ""

# --- the lessons' tables ---

## A lesson's scenes, each the balls on the table (id: metres) and its shots:
## "pot" [ball, pocket] aims at the ghost ball that sends it there, "ball" at
## a ball's middle; "pull" is how far the cue is drawn, "tip" where it
## strikes. Every shot was tried on the sim (it steps a fixed 1/480 s, so a
## shot repeats exactly).
static func scenes(the_lesson: int) -> Array:
	var black: Vector2 = Sim.SPOTS[Sim.BLACK]
	match the_lesson:
		Lesson.AIM:
			return [{"balls": {Sim.CUE: Vector2(1.3, 0.35), 1: Vector2(0.5, 0.26)},
				"shots": [{"pot": [1, 0], "pull": 0.35}]}]
		Lesson.ORDER:
			return [{"balls": {Sim.CUE: Vector2(1.1, 0.72), 1: Vector2(0.3, 0.3), 2: Vector2(1.5, 0.3), Sim.BLACK: black},
				"shots": [{"pot": [1, 0], "pull": 0.4}, {"pot": [Sim.BLACK, 1], "pull": 0.35}]}]
		Lesson.FOUL:
			return [
				{"balls": {Sim.CUE: Vector2(1.35, 0.4), 1: Vector2(0.45, 0.6), Sim.BLACK: black},
					"shots": [{"ball": Sim.BLACK, "pull": 0.3}]},
				{"balls": {Sim.CUE: Vector2(1.2, 0.62), 1: Vector2(0.3915, 0.2175), Sim.BLACK: black},
					"shots": [{"pot": [1, 0], "pull": 0.42}]},
			]
		Lesson.SPIN:
			var balls := {Sim.CUE: Vector2(1.25, 0.85), 1: Vector2(1.0006, 0.6834)}
			return [
				{"balls": balls, "shots": [{"pot": [1, 0], "pull": 0.35, "tip": Vector2(0.0, 0.35)}]},
				{"balls": balls, "shots": [{"pot": [1, 0], "pull": 0.35, "tip": Vector2(0.0, -0.58)}]},
			]
		Lesson.HINT:
			return [{"balls": {Sim.CUE: Vector2(1.25, 0.7), 1: Vector2(0.6, 0.4)},
				"shots": [{"pot": [1, 0], "pull": 0.35}]}]
	return []

## Only `balls` on the table, each where it says.
static func lay(the_sim: RefCounted, balls: Dictionary) -> void:
	for i in Sim.COUNT:
		the_sim.on[i] = balls.has(i)
		if balls.has(i):
			the_sim.pos[i] = balls[i]
	the_sim.begin_shot()

## The point on the table a shot's aim goes through.
static func aim_at(the_sim: RefCounted, shot: Dictionary) -> Vector2:
	if shot.has("ball"):
		return the_sim.pos[int(shot.ball)]
	var id := int(shot.pot[0])
	var pk: Dictionary = the_sim.pockets[int(shot.pot[1])]
	var mouth: Vector2 = pk.at + (pk.out as Vector2) * 0.02
	return the_sim.pos[id] - (mouth - the_sim.pos[id]).normalized() * Sim.R * 2.0

# --- building ---

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_badge = hints
	set_process(lesson != Lesson.HUD)
	if lesson != Lesson.HUD:
		_art = Cloth.new()
		_art.room = DRAW
		add_child(_art)
		if lesson == Lesson.WORTH:
			# Only its painted balls are wanted, in a row.
			_art.visible = false
			_art.set_process(false)
		else:
			_art.released.connect(_on_release)
			_fade = Control.new()
			_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_fade.z_index = 4
			_fade.draw.connect(_draw_fade)
			add_child(_fade)
		_pill = PanelContainer.new()
		_pill.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, 26, 10))
		_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pill.z_index = 5
		_pill.visible = false
		_caption = Label.new()
		_caption.theme_type_variation = "SheetBody"
		_caption.add_theme_font_size_override("font_size", CAPTION_PX)
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pill.add_child(_caption)
		add_child(_pill)
	if lesson == Lesson.SPIN:
		_pad = Controls.SpinPad.new()
		_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pad.changed.connect(func() -> void: _art.tip = _pad.tip)
		add_child(_pad)
		# The screen's own caption over it.
		_kicker = Label.new()
		_kicker.text = "SNK_SPIN"
		_kicker.theme_type_variation = "MenuKicker"
		_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_kicker)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.z_index = 6
	_over.draw.connect(_draw_over)
	add_child(_over)
	resized.connect(_layout)
	call_deferred("_layout")
	call_deferred("_start")

func _exit_tree() -> void:
	_gen += 1
	_running = false

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun and not _running:
		call_deferred("_start")

func _column() -> float:
	return COLUMN if lesson == Lesson.SPIN or lesson == Lesson.HINT else 0.0

func _layout() -> void:
	if _over == null or size.x <= 0.0:
		return
	_over.position = Vector2.ZERO
	_over.size = size
	if _art != null and lesson != Lesson.WORTH:
		# As wide as the page: the table's top end, the rest out of the slot.
		var span := Vector2(Sim.W, Sim.L) + Vector2.ONE * 2.0 * (Table.CUSHION + Table.RAIL)
		var wide := size.x - _column() - PAD * 2.0
		_art.position = Vector2(_column() + PAD, TOP)
		_art.size = span * (wide / span.x)
		_fade.position = Vector2.ZERO
		_fade.size = size
		_fade.queue_redraw()
	if _pad != null:
		_pad.size = _pad.custom_minimum_size
		_pad.position = Vector2((COLUMN - _pad.size.x) * 0.5, 96.0)
		_kicker.position = Vector2(0.0, 56.0)
		_kicker.size = Vector2(COLUMN, 34.0)
	_place_pill()
	queue_redraw()
	if not _begun and is_inside_tree():
		call_deferred("_start")

func _process(delta: float) -> void:
	_t += delta
	if _rolling:
		# The screen's own loop: fixed steps, then the referee.
		_acc += minf(delta, 0.05)
		var n := 0
		while _acc >= Sim.DT and n < 40:
			sim.step(Sim.DT)
			_acc -= Sim.DT
			n += 1
		_play_events()
		if not sim.moving():
			_rolling = false
			rules.judge()
			_busy = false
	if Motion.reduce:
		return
	_over.queue_redraw()
	if lesson == Lesson.WORTH:
		_say("TUT_SNOOKER_CAP_WORTH" if _worth_clock() < _gone_at() else "TUT_SNOOKER_CAP_ORDER")
		queue_redraw()

## What the table shows of a shot, as the screen does it, with no sound.
func _play_events() -> void:
	for e in sim.events:
		match String(e.kind):
			"ball":
				_art.flash("ball", e.at, float(e.speed) / 2.5)
			"cushion":
				if float(e.speed) > 0.08:
					_art.flash("cushion", e.at, float(e.speed) / 2.0)
			"pot":
				var out: Vector2 = sim.pockets[int(e.pocket)].out
				if e.has("from"):
					_art.sink(int(e.id), e.from, (e.at as Vector2) + out * 0.03)
				_art.flash("pot", (e.at as Vector2) + out * 0.03, 1.0)
	sim.events.clear()

# --- the lessons ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	if _begun and _running:
		return
	_gen += 1
	_begun = true
	if lesson == Lesson.HUD:
		return
	if lesson == Lesson.WORTH:
		_t = 0.0
		_say("TUT_SNOOKER_CAP_ORDER" if Motion.reduce else "TUT_SNOOKER_CAP_WORTH")
		return
	_running = true
	_run(_gen)

## The lesson, over and over, while the page is up: a coroutine that waits
## on a timer of its own (freed with the page, so a turned page never
## resumes it) and stops as soon as `_gen` moves on.
func _run(gen: int) -> void:
	if _clock == null:
		_clock = Timer.new()
		_clock.one_shot = true
		add_child(_clock)
	var all := scenes(lesson)
	while gen == _gen:
		for k in all.size():
			var scene: Dictionary = all[k]
			_lay(scene)
			if Motion.reduce:
				_still(scene)
				_running = false
				return
			if not await _play(k, scene, gen):
				return

## One scene from its first caption to its last beat; false when stopped.
func _play(k: int, scene: Dictionary, gen: int) -> bool:
	var shots: Array = scene.shots
	match lesson:
		Lesson.AIM:
			_say("TUT_SNOOKER_CAP_AIM")
			if not await _wait(1.1, gen): return false
			if not await _aim(shots[0], gen): return false
			_say("TUT_SNOOKER_CAP_PULL")
			if not await _pull(shots[0], gen, "TUT_SNOOKER_CAP_GO"): return false
			return await _wait(1.8, gen)
		Lesson.ORDER:
			_say("TUT_SNOOKER_CAP_RED")
			if not await _wait(1.3, gen): return false
			if not await _aim(shots[0], gen): return false
			if not await _pull(shots[0], gen): return false
			_turn()
			_say("TUT_SNOOKER_CAP_COLOUR")
			if not await _wait(1.6, gen): return false
			if not await _aim(shots[1], gen): return false
			if not await _pull(shots[1], gen): return false
			_turn()
			_say("TUT_SNOOKER_CAP_BACK")
			return await _wait(3.0, gen)
		Lesson.FOUL:
			_say("TUT_SNOOKER_CAP_RED" if k == 0 else "TUT_SNOOKER_CAP_WHITE")
			if not await _wait(1.3, gen): return false
			if not await _aim(shots[0], gen): return false
			if not await _pull(shots[0], gen): return false
			_say_text(_foul_line(rules.last))
			return await _wait(2.8, gen)
		Lesson.SPIN:
			_say("TUT_SNOOKER_CAP_PAD")
			if not await _wait(1.0, gen): return false
			var tip: Vector2 = shots[0].tip
			var on_pad: Vector2 = _pad.size * 0.5 + Vector2(tip.x, -tip.y) * _pad._r()
			if not await _tap(_pad.position + on_pad, gen, _touch.bind(_pad, on_pad, true)): return false
			_say("TUT_SNOOKER_CAP_HIGH" if tip.y > 0.0 else "TUT_SNOOKER_CAP_LOW")
			if not await _wait(0.9, gen): return false
			if not await _pull(shots[0], gen): return false
			return await _wait(1.6, gen)
		Lesson.HINT:
			_badge = hints
			_say("TUT_SNOOKER_CAP_BULB")
			if not await _wait(1.1, gen): return false
			if not await _tap(_bulb_rect().get_center(), gen, _show_hint.bind(shots[0])): return false
			_say("TUT_SNOOKER_CAP_GOLD")
			if not await _wait(1.9, gen): return false
			_say("TUT_SNOOKER_CAP_NOTCH")
			if not await _pull(shots[0], gen): return false
			return await _wait(1.8, gen)
	return false

## Reduce-motion: the lesson's telling moment, standing still.
func _still(scene: Dictionary) -> void:
	var shot: Dictionary = scene.shots[0]
	var to := aim_at(sim, shot)
	_art.aim_dir = (to - sim.pos[Sim.CUE]).normalized()
	match lesson:
		Lesson.AIM:
			_art.hold(float(shot.pull))
			_finger = _art.position + _grab() - _art.aim_dir * float(shot.pull) * DRAW
			_down = true
			_say("TUT_SNOOKER_CAP_PULL")
		Lesson.ORDER:
			_say("TUT_SNOOKER_CAP_RED")
		Lesson.FOUL:
			_say_text(_foul_line({"reason": "SNK_FOUL_FIRST", "penalty": Sim.value(Sim.BLACK)}))
		Lesson.SPIN:
			_pad.set_tip(shot.tip)
			_art.tip = shot.tip
			_say("TUT_SNOOKER_CAP_HIGH")
		Lesson.HINT:
			_show_hint(shot)
			_say("TUT_SNOOKER_CAP_GOLD")
	# Still: the balls on would go on glowing in and out.
	_art.set_process(false)
	_art.queue_redraw()
	_over.queue_redraw()

## The referee's line for a foul, as the screen's toast says it.
func _foul_line(res: Dictionary) -> String:
	return tr(String(res.get("reason", ""))) + "\n" + tr("SNK_FOUL_TO") % [int(res.get("penalty", 4)), tr("SNK_BOT")]

## What the bulb lays out, for one of its count: the line and the notch.
func _show_hint(shot: Dictionary) -> void:
	_badge = hints - 1
	var dir: Vector2 = (aim_at(sim, shot) - sim.pos[Sim.CUE]).normalized()
	_art.aim_dir = dir
	_art.hint_dir = dir
	_art.hint_power = float(shot.pull)

## A scene's balls on a fresh frame, the player to play.
func _lay(scene: Dictionary) -> void:
	_lift()
	_busy = false
	_rolling = false
	sim = Sim.new()
	rules = Rules.new(sim, 0)
	rules.in_hand = false
	lay(sim, scene.balls)
	_art.sim = sim
	_art.wipe()
	_art.set_process(true)
	_turn()

## The start of a turn, as the screen starts one: the balls on lit, the cue
## come up behind the white and laid toward the nearest of them.
func _turn() -> void:
	_art.hint_dir = Vector2.ZERO
	_art.hint_power = 0.0
	_art.power = 0.0
	_art.in_hand = false
	_art.targets = rules.legal_first()
	_art.tip = Vector2.ZERO
	if _pad != null:
		_pad.set_tip(Vector2.ZERO)
	_art.cue_in()
	_art.interactive = true
	var cue: Vector2 = sim.pos[Sim.CUE]
	var best := INF
	for id in _art.targets:
		var d: float = sim.pos[id].distance_to(cue)
		if d < best:
			best = d
			_art.aim_dir = (sim.pos[id] - cue).normalized()

## The cue let go: through the ball, then the roll.
func _on_release(power: float) -> void:
	if power < 0.03:
		_art.power = 0.0
		return
	var dir: Vector2 = _art.aim_dir
	var speed: float = pace.call(power)
	var tip: Vector2 = _art.tip
	_busy = true
	_art.interactive = false
	_art.hint_dir = Vector2.ZERO
	_art.play_stroke(func() -> void:
		sim.strike(dir, speed, tip)
		_art.power = 0.0
		_acc = 0.0
		_rolling = true)

# --- the finger, through the table's own input ---

## Where the finger picks the cue up, table-local.
func _grab() -> Vector2:
	return _art.px(sim.pos[Sim.CUE]) - _art.aim_dir * GRAB * _art.ppm

## The finger presses the table beside the shot's line and swings the aim
## onto it.
func _aim(shot: Dictionary, gen: int) -> bool:
	var to: Vector2 = _art.px(aim_at(sim, shot))
	var cue: Vector2 = _art.px(sim.pos[Sim.CUE])
	# From a little wide of the line, on the side the cue was laid.
	var side := (to - cue).normalized().orthogonal()
	if side.dot(_art.aim_dir) < 0.0:
		side = -side
	var from := to + side * 0.12 * _art.ppm
	_touch(_art, from, true)
	if not await _wait(0.35, gen): return false
	var t := 0.0
	while t < AIM_T:
		if not await _tick(gen): return false
		t += get_process_delta_time()
		_slide(_art, from.lerp(to, smoothstep(0.0, 1.0, minf(1.0, t / AIM_T))))
	_slide(_art, to)
	if not await _wait(0.45, gen): return false
	_touch(_art, to, false)
	if not await _wait(0.3, gen): return false
	_lift()
	return true

## The finger takes the cue behind the ball, draws it back to the shot's
## pull and lets go (the caption turning to `go` as it does); then the shot,
## to the referee's word.
func _pull(shot: Dictionary, gen: int, go := "") -> bool:
	var from := _grab()
	_touch(_art, from, true)
	if not await _wait(0.35, gen): return false
	var to: Vector2 = from - _art.aim_dir * float(shot.pull) * _art.reach()
	var t := 0.0
	while t < PULL_T:
		if not await _tick(gen): return false
		t += get_process_delta_time()
		_slide(_art, from.lerp(to, smoothstep(0.0, 1.0, minf(1.0, t / PULL_T))))
	_slide(_art, to)
	if not await _wait(0.5, gen): return false
	if go != "":
		_say(go)
	_touch(_art, to, false)
	if not await _wait(0.25, gen): return false
	_lift()
	while _busy:
		if not await _tick(gen): return false
	return await _wait(0.5, gen)

## The finger comes over `at` (page-local), presses (`then` runs as it does)
## and lifts.
func _tap(at: Vector2, gen: int, then: Callable) -> bool:
	_finger = at
	_down = false
	if not await _wait(0.45, gen): return false
	_down = true
	then.call()
	if not await _wait(0.3, gen): return false
	_down = false
	if not await _wait(0.3, gen): return false
	_lift()
	return true

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

func _touch(node: Control, at: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	_finger = node.position + at
	_down = pressed
	node._gui_input(ev)

func _slide(node: Control, at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.position = at
	_finger = node.position + at
	_down = true
	node._gui_input(ev)

## Waits `seconds`; false when the lesson has been stopped meanwhile.
func _wait(seconds: float, gen: int) -> bool:
	_clock.start(seconds)
	await _clock.timeout
	return gen == _gen and is_inside_tree()

## Waits a frame; false when the lesson has been stopped meanwhile.
func _tick(gen: int) -> bool:
	if not is_inside_tree():
		return false
	await get_tree().process_frame
	return gen == _gen and is_inside_tree()

# --- the caption ---

## `key` through tr.
func _say(key: String) -> void:
	if key != _said:
		_say_text(tr(key))
		_said = key

func _say_text(text: String) -> void:
	_said = ""
	_caption.text = text
	_pill.visible = true
	_place_pill.call_deferred()

## Under the table's middle, on the page's foot.
func _place_pill() -> void:
	if _pill == null:
		return
	_pill.reset_size()
	var s := _pill.get_combined_minimum_size()
	_pill.size = s
	_pill.position = Vector2(_column() + (size.x - _column() - s.x) * 0.5, size.y - s.y - 14.0).round()

# --- drawing ---

## The table's foot going into the card: paper over it, clear at the top.
func _draw_fade() -> void:
	var b := Face.Builder.new()
	var y0 := size.y - FADE
	var a := b.vertex(Vector2(_column(), y0), Color(Pal.PAPER, 0.0))
	b.vertex(Vector2(size.x, y0), Color(Pal.PAPER, 0.0))
	b.vertex(Vector2(size.x, size.y), Pal.PAPER)
	b.vertex(Vector2(_column(), size.y), Pal.PAPER)
	b.tri(a, a + 1, a + 2)
	b.tri(a, a + 2, a + 3)
	_fade_shown = b.mesh()
	_fade.draw_mesh(_fade_shown, null)

func _bulb_rect() -> Rect2:
	return Rect2(Vector2((COLUMN - CHIP) * 0.5, 120.0), Vector2(CHIP, CHIP))

## A top-bar button as it is on the bar: white paper lifted off the page.
func _chip(b: Face.Builder, r: Rect2, sink := 0.0) -> void:
	b.polygon(Face.Builder.round_rect(r.position + Vector2(0, 6.0), r.size, r.size.y * 0.29), Color(Pal.TEXT, 0.16))
	b.polygon(Face.Builder.round_rect(r.position + Vector2(0, sink), r.size, r.size.y * 0.29), Pal.SURFACE)

## The count on the bulb's corner.
func _badge_disc(b: Face.Builder, r: Rect2) -> Vector2:
	var c := Vector2(r.end.x - 8.0, r.position.y + 6.0)
	b.disc(c, 22.0, Pal.SURFACE)
	b.disc(c, 18.0, Pal.ACCENT_2)
	return c

func _badge_text(ci: CanvasItem, c: Vector2, n: int) -> void:
	var font: Font = CozyTheme.display(700)
	var w := font.get_string_size(str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	ci.draw_string(font, c + Vector2(-w * 0.5, 9.0), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Pal.SURFACE)

## Over the table: the bulb on the hint page, and the finger.
func _draw_over() -> void:
	var b := Face.Builder.new()
	var bulb := lesson == Lesson.HINT
	var r := _bulb_rect()
	var pressed := bulb and _down and r.has_point(_finger)
	var badge_at := Vector2.ZERO
	if bulb:
		_chip(b, r, 3.0 if pressed else 0.0)
		badge_at = _badge_disc(b, r)
	if _finger.x >= 0.0:
		var at := _finger + Vector2(12.0, 14.0)
		var fr := FINGER_R * (0.85 if _down else 1.0)
		b.disc(at, fr, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
		b.stroke(Face.Builder.ring(at, fr, fr), 3.0, Color(Pal.TEXT, 0.45), true)
	_over_shown = b.mesh() if not b.verts.is_empty() else null
	if _over_shown != null:
		_over.draw_mesh(_over_shown, null)
	if bulb:
		var g := CHIP * 0.5
		Icons.paint(_over, "bulb", Rect2(r.get_center() - Vector2(g, g) * 0.5 + Vector2(0, 3.0 if pressed else 0.0), Vector2(g, g)), Pal.TEXT)
		_badge_text(_over, badge_at, _badge)

func _draw() -> void:
	if size.x <= 0.0:
		return
	if lesson == Lesson.WORTH:
		_draw_worth()
	elif lesson == Lesson.HUD:
		_draw_hud()

# --- the worth page ---

const ROW := [1, Sim.YELLOW, Sim.GREEN, Sim.BROWN, Sim.BLUE, Sim.PINK, Sim.BLACK]

## When the count is through and the red goes, and when the colours' order
## starts, on the page's clock.
func _gone_at() -> float:
	return COUNT_STEP * ROW.size() + 0.7

func _order_from() -> float:
	return _gone_at() + 0.8

func _worth_clock() -> float:
	return fmod(_t, _order_from() + ORDER_STEP * ROW.size() + 1.6)

## The seven balls in a row on a strip of cloth, each over what it is worth.
## They are counted through, red to black; then the red goes and the colours
## go down in their order, the next one lit as a ball on is.
func _draw_worth() -> void:
	var b := Face.Builder.new()
	var strip := Rect2(Vector2(14.0, 34.0), Vector2(size.x - 28.0, 300.0))
	b.fan(Face.Builder.round_rect(strip.position + Vector2(0, 8.0), strip.size, 44.0), Table.WOOD_DEEP)
	b.fan(Face.Builder.round_rect(strip.position, strip.size, 44.0), Table.WOOD)
	var cloth := strip.grow(-24.0)
	b.fan(Face.Builder.round_rect(cloth.position - Vector2.ONE * 5.0, cloth.size + Vector2.ONE * 10.0, 24.0), Table.CUSHION_TOP)
	b.fan(Face.Builder.round_rect(cloth.position, cloth.size, 20.0), Table.CLOTH)
	var n := ROW.size()
	var step := cloth.size.x / n
	var r := minf(40.0, step * 0.36)
	var y := cloth.position.y + cloth.size.y * 0.38
	var t := _worth_clock()
	var ordering := not Motion.reduce and t >= _gone_at()
	var u := (t - _order_from()) / ORDER_STEP
	# The order's arrow under the six colours.
	var ay := cloth.end.y - 30.0
	var a0 := Vector2(cloth.position.x + step * 1.5 - r, ay)
	var a1 := Vector2(cloth.position.x + step * (n - 0.5) + r, ay)
	b.stroke(PackedVector2Array([a0, a1]), 4.0, Table.LINE)
	b.stroke(PackedVector2Array([a1 + Vector2(-16.0, -11.0), a1, a1 + Vector2(-16.0, 11.0)]), 4.0, Table.LINE)
	var marks: Array = []
	for k in n:
		var at := Vector2(cloth.position.x + step * (k + 0.5), y)
		var grow := 1.0
		var alpha := 1.0
		var lit := false
		if ordering:
			# The red goes; then colour k is on for its beat, and down.
			var mine := u - float(k - 1)
			if k == 0:
				alpha = 1.0 - clampf((t - _gone_at()) / 0.4, 0.0, 1.0)
			elif mine >= 0.0:
				lit = mine < 0.6
				alpha = 1.0 - clampf((mine - 0.6) / 0.3, 0.0, 1.0)
				grow = lerpf(0.55, 1.0, alpha)
		elif not Motion.reduce:
			var mine := (t - COUNT_STEP * k) / 0.45
			if mine >= 0.0 and mine < 1.0:
				grow = 1.0 + 0.2 * sin(mine * PI)
		marks.append([at, grow, alpha])
		if alpha <= 0.01:
			continue
		b.ellipse(at + Vector2(r * 0.28, r * 0.36) * grow, r * 1.02 * grow, r * 0.92 * grow, Color(Table.SHADOW, Table.SHADOW.a * alpha))
		if lit:
			b.stroke(Face.Builder.ring(at, r * 1.32, r * 1.32), 3.0, Color(1.0, 0.97, 0.8, 0.4 + 0.2 * sin(_t * 3.2)), true)
		_art._ball(b, ROW[k], at, r * grow, alpha, (1.0 - alpha) * 0.75)
	_page_shown = b.mesh()
	draw_mesh(_page_shown, null)
	var font: Font = CozyTheme.display(700)
	for k in n:
		var px := int(round(46.0 * maxf(1.0, float(marks[k][1]))))
		var word := str(Sim.value(ROW[k]))
		var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(font, Vector2((marks[k][0] as Vector2).x - w * 0.5, y + r + 62.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
			Color(Table.INLAY, lerpf(0.45, 1.0, float(marks[k][2]))))

# --- the buttons page ---

## The top bar's Reset, bulb, ? and gear, each drawn as it is on the bar
## beside what it does here.
func _draw_hud() -> void:
	var rows := [["reset", "TUT_SNOOKER_HUD_RESET"], ["bulb", "TUT_SNOOKER_HUD_BULB"],
		["help", "TUT_SNOOKER_HUD_HELP"], ["gear", "TUT_SNOOKER_HUD_GEAR"]]
	var row_h := size.y / rows.size()
	var chip := minf(CHIP, row_h * 0.78)
	var x0 := 40.0
	var b := Face.Builder.new()
	var rects: Array = []
	var badge_at := Vector2.ZERO
	for k in rows.size():
		var r := Rect2(Vector2(x0, row_h * (k + 0.5) - chip * 0.5), Vector2(chip, chip))
		rects.append(r)
		_chip(b, r)
		if String(rows[k][0]) == "bulb":
			badge_at = _badge_disc(b, r)
	_page_shown = b.mesh()
	draw_mesh(_page_shown, null)
	var font: Font = CozyTheme.display(700)
	var tx := x0 + chip + 36.0
	var wide := size.x - tx - 24.0
	for k in rows.size():
		var r: Rect2 = rects[k]
		Icons.paint(self, String(rows[k][0]), Rect2(r.get_center() - Vector2(chip, chip) * 0.27, Vector2(chip, chip) * 0.54), Pal.TEXT, Pal.SURFACE)
		var line := tr(String(rows[k][1]))
		if String(rows[k][0]) == "bulb":
			line = line % hints
		var lines := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30)
		draw_multiline_string(font, Vector2(tx, r.get_center().y - lines.y * 0.5 + 30.0 * 0.82), line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30, -1, Pal.TEXT)
	_badge_text(self, badge_at, hints)
