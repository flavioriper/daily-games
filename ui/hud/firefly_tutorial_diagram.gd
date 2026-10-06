extends Control

## One page of Firefly's tutorial: a small night garden played by the game
## itself. The page holds a `Garden` -- arcade/firefly_screen.gd with its top
## bar, plates, cards, sounds, knocks and records taken out, so what is left
## is the field it draws -- looking at the foot of the field only (the firefly
## and the hundred and fifty units over it: the whole field in a slot this
## short would make a bug a dot), and a `Night` -- arcade/firefly_sim.gd with the
## swarm seated low enough to be in that view, no stage of its own and no
## attack it was not told to make. A finger plays it through the screen's own
## touch: it comes down beside the firefly, slides, and the firefly follows
## the slide and fires while it is held. So a gnat pops for 50, a moth
## blushes at its first hit, a seed costs a lantern, the escorts double their
## moth, the silk beam hauls the firefly up and the rescue brings it back as
## a pair, exactly as in a run. `lesson` picks the page (set before it enters
## the tree):
##
## - MOVE: the finger slides and holds, and the firefly sweeps a row of gnats.
## - SWARM: one column shot from the bottom up: 50, 80, a blush, 150.
## - DIVE: a ladybird dives and is shot for double past its seed; the next
##   one's seed is left to land, and a lantern goes.
## - ESCORT: a moth dives with two ladybirds; they go first, then the moth.
## - BEAM: a moth's beam carries the firefly off; shot in its next dive, the
##   firefly comes back and the two fire together.
## - FLYBY: a stream passes through without firing and is caught whole.
## - SHOP: no garden: the mote a bug drops and the shop's five cards, drawn
##   as they are beside what each is.
## - HUD: the top bar's Reset, the gear and the ?, and the boosters, drawn as
##   they are beside what each does.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://arcade/firefly_sim.gd")
const BoosterIcon = preload("res://arcade/booster_icon.gd")
const Art = preload("res://arcade/firefly_art.gd")
const Motes = preload("res://ui/motes.gd")

## SHOP is last so the old numbers stand; the screen lays it before HUD.
enum Lesson { MOVE, SWARM, DIVE, ESCORT, BEAM, FLYBY, HUD, SHOP }

## The wooden frame round the garden, as the field's own.
const FRAME := 10.0
const WOOD := Color("6e4a2f")
const WOOD_EDGE := Color("9c6b45")
## The finger rests this far right of where the firefly is and this far up
## from the garden's foot, so it never hides what it steers.
const FINGER_SIDE := 110.0
const FINGER_UP := 36.0
const FINGER_R := 30.0
## The HUD page's left edge and the gap between two of its buttons.
const HUD_X := 32.0
const HUD_GAP := 14.0
## A bug lower than this is too near to shoot at: the finger leaves it.
const REACH := 326.0
## A still page is played to its telling moment in steps this long.
const STILL_DT := 1.0 / 60.0

var lesson: int = Lesson.MOVE

var _garden: Garden
var _sim: Night
var _over: Control
var _begun := false
## The lesson: [time, Callable] in order, how long it runs before it starts
## again, and the moment a still page stands at.
var _script: Array = []
var _next := 0
var _len := 6.0
var _still_at := 2.0
## The finger: whether it is down, where it wants the firefly (field units),
## how fast it slides there, and whether it is chasing bugs by itself.
var _down := false
var _aim := 0.0
var _aim_to := 0.0
var _speed := 200.0
var _hunt := false
var _hunt_seats := false
var _low_first := false
## Bugs to shoot in this order, when the lesson names them.
var _marks: Array = []
## Each bug's last place and its speed, by id, for the finger's lead.
var _last := {}
var _vel := {}
var _last_t := 0.0
var _finger_shown: ArrayMesh
var _frame_shown: ArrayMesh
var _hud_shown: ArrayMesh

## The game, with the swarm seated in the page's view and nothing planned:
## the page lays its own bugs and sends each dive itself.
class Night extends "res://arcade/firefly_sim.gd":
	## Where the swarm's top row sits, and the top of what the page shows.
	const SEAT_TOP := 224.0
	const VIEW_TOP := 196.0

	func _start_stage() -> void:
		stage = maxi(stage, 1)
		_challenge = false
		phase = Phase.PLAY
		phase_t = 0.0
		_sway_amp = 0.0

	func home(slot: Vector2i) -> Vector2:
		return super(slot) + Vector2(0, SEAT_TOP - FORM_TOP)

	func _attack() -> void:
		pass

	## A lesson's bugs are the first stage's: one shot, a moth two and
	## blushing at the first, whatever stage the page says it is.
	func hp_of(kind: int) -> int:
		return 2 if kind == Kind.MOTH else 1

	## No shop on a page.
	func _after_stage() -> void:
		_start_stage()

	## Only a flyby is tallied: a lesson's last bug is not a stage cleared.
	func _check_clear() -> void:
		if _challenge:
			super()

	## A bug of `kind` in its seat.
	func seat(kind: int, col: int, row: int) -> Dictionary:
		var slot := Vector2i(col, row)
		var e := _spawn(kind, slot, PackedVector2Array([home(slot)]), St.FORM)
		e.st = St.FORM
		e.pos = home(slot)
		enemies.append(e)
		return e

	## Out of a seat as every dive leaves one, then through `pts`.
	func _line(from: Vector2, pts: Array) -> PackedVector2Array:
		var side := -1.0 if from.x < W * 0.5 else 1.0
		var out := PackedVector2Array([from, from + Vector2(side * 8.0, -10.0), from + Vector2(side * 20.0, -9.0),
			from + Vector2(side * 26.0, 3.0), from + Vector2(side * 21.0, 18.0)])
		for p: Vector2 in pts:
			out.append(p)
		return smooth(out, 12)

	## The game's own dive on a line laid by hand, so it stays in view: `e`
	## drops a seed as it passes each height in `seeds`, and `escorts` fly
	## it beside `e`.
	func send(e: Dictionary, pts: Array, seeds: Array = [], escorts: Array = []) -> void:
		e.escorts_down = 0
		_dive(e, {})
		_set_path(e, _line(e.pos, pts))
		e.fire_at = seeds.duplicate()
		for o: Dictionary in escorts:
			_dive(o, e)
			o.fire_at = []

	## A moth's beam run that stops at the last of `pts` and opens there.
	func send_beam(e: Dictionary, pts: Array) -> void:
		_dive_beam(e)
		_set_path(e, _line(e.pos, pts))
		e["beam_at"] = 1e9

	## A flyby's stream: `n` bugs down one path, `gap` seconds apart.
	func stream(fracs: Array, kinds: Array, n: int, first: float, gap: float) -> void:
		_challenge = true
		var path := _path(fracs, false)
		for i in n:
			var e := _spawn(kinds[i % kinds.size()], Vector2i(-1, -1), path, St.FLYBY)
			e.hp = 1
			e.max = 1
			e.delay = first + i * gap
			enemies.append(e)
			flyby_total += 1

## The screen, quiet: only its field, at the page's scale. No top bar, no
## plates, no cards, no sound, no knock, no record; the lettering kept is the
## few words that are the lesson (Oh no!, Saved!, Double fire!, the escort's
## bonus, the flyby's), smaller, and fitted to the garden by the layer.
class Garden extends "res://arcade/firefly_screen.gd":
	## Field units of height in view.
	const VIEW := Night.H - Night.VIEW_TOP

	class Quiet extends "res://arcade/rewards.gd":
		const KEPT := ["caught", "saved", "double", "escort", "bonus", "ouch"]
		const SMALL := 0.62

		func sticker(text: String, where: Vector2, fs: int, life: float, rainbow := true, col := Color.WHITE, rays := false, id := "", rise := 0.0, keep := false) -> Dictionary:
			if not KEPT.has(id):
				return {}
			return super(text, where, int(fs * SMALL), life, rainbow, col, rays, id, rise * SMALL, keep)

		## Fewer bits, smaller and thrown less far: the garden is a third
		## of the field's size.
		func spray(from: Vector2, col: Color, n: int, speed: float, kind := "spark", bit := 1.0, delay := 0.0, to := Vector2.INF) -> void:
			super(from, col, ceili(n * 0.5), speed * SMALL, kind, bit * SMALL, delay, to)

		func rain(seconds: float, kinds: Array = ["confetti", "star"], cols: Array = CONFETTI) -> void:
			super(seconds * 0.5, kinds, cols)

	class Hush extends "res://ui/fx2d.gd":
		func cue(cue_name: String, _pitch := 1.0, _volume_db := 0.0) -> void:
			last_cue = cue_name

		func _prefetch() -> void:
			pass

	func puzzle_id() -> String:
		return "firefly_tutorial"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		field = Control.new()
		field.clip_contents = true
		field.mouse_filter = Control.MOUSE_FILTER_IGNORE
		field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		field.draw.connect(_draw_field)
		field.resized.connect(_layout_field)
		add_child(field)
		_fx = Hush.new()
		_fx.buzzes = false
		field.add_child(_fx)
		# the banner's box is placed by the layout; it is never shown
		var box := Control.new()
		box.visible = false
		field.add_child(box)
		_banner = Label.new()
		_banner.set_meta("box", box)
		box.add_child(_banner)
		_rw = Quiet.new()
		_rw.set_additive(true)
		add_child(_rw)

	## As wide as the garden, however little of the field's height that shows.
	func _unit(s: Vector2) -> float:
		return s.x / Sim.W

	## Only the page's finger: no key steers a lesson.
	func _hands() -> void:
		sim.axis = 0.0
		sim.fire = _touch != -1

	func _beam_sound() -> void:
		pass

	func _refresh_hud(_delta := 0.0) -> void:
		pass

	func _knock_now() -> void:
		_knock = -1

	func _show_banner(_text: String, _sub: String, _hold: float) -> void:
		pass

	## No score plate for a kill's stars to fly home to: up out of the garden.
	func _plate_at(_l: Label) -> Vector2:
		return _field_at(0.5, -0.1)

	func _game_over() -> void:
		pass

	func _pause(_on: bool) -> void:
		pass

	func _tutor_hold(_on: bool) -> void:
		pass

	## A fresh lesson: `s` on a field with nothing left over from the last.
	func lay(s: RefCounted) -> void:
		sim = s
		_touch = -1
		_mouse = false
		_acc = 0.0
		_pops.clear()
		_bursts.clear()
		_vis.clear()
		_wake.clear()
		_shake = 0.0
		_freeze = 0.0
		_lean = 0.0
		_muzzle = 0.0
		_prev_px = sim.px
		_ready_at = -10.0
		_chain = 0
		_chain_t = 99.0
		_heat = 0.0
		_flash = 0.0
		_knock = -1
		_rw.clear()

	## The page's finger, through the field's own touch: down or up at `at`
	## (the field's pixels), and sliding to it.
	func finger(at: Vector2, down: bool) -> void:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.position = at
		ev.pressed = down
		_on_field_input(ev)

	func slide(at: Vector2) -> void:
		var ev := InputEventScreenDrag.new()
		ev.index = 0
		ev.position = at
		_on_field_input(ev)

	## Where a finger steering the firefly to `x` (field units) rests.
	func finger_at(x: float) -> Vector2:
		return Vector2(field.size.x * 0.5 + FINGER_SIDE + (x - Sim.W * 0.5) * _u / GAIN, field.size.y - FINGER_UP)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if not _drawn():
		_garden = Garden.new()
		add_child(_garden)
		_over = Control.new()
		_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_over.draw.connect(_draw_finger)
		add_child(_over)
	elif lesson == Lesson.HUD:
		for id: String in ["ff_spare", "ff_twin", "second_chance"]:
			add_child(BoosterIcon.new(id))
	resized.connect(_layout)
	call_deferred("_layout")

## A page with no garden: drawn, standing still.
func _drawn() -> bool:
	return lesson == Lesson.HUD or lesson == Lesson.SHOP

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun:
		call_deferred("_reset")

func _layout() -> void:
	queue_redraw()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if lesson == Lesson.HUD:
		# the boosters' own badges, in the third row's column
		var disc := (_hud_col() - HUD_GAP * 2.0) / 3.0
		var n := 0
		for c in get_children():
			if c is BoosterIcon:
				(c as Control).custom_minimum_size = Vector2(disc, disc)
				(c as Control).size = Vector2(disc, disc)
				(c as Control).position = Vector2(HUD_X + n * (disc + HUD_GAP), size.y * 5.0 / 6.0 - disc * 0.5)
				n += 1
		return
	if lesson == Lesson.SHOP:
		return
	var u := minf((size.x - FRAME * 2.0) / Sim.W, (size.y - FRAME * 2.0) / Garden.VIEW)
	_garden.size = Vector2(Sim.W * u, Garden.VIEW * u).floor()
	_garden.position = ((size - _garden.size) * 0.5).round()
	_over.position = Vector2.ZERO
	_over.size = size
	if not _begun and is_inside_tree():
		_begun = true
		_reset()

# --- the lessons ---

## A lesson's bugs, its finger and its dives. Seats are (column, row): the
## columns are twenty apart about the middle, the rows moths, ladybirds, gnats.
func _plan() -> void:
	var K := Sim.Kind
	var s := Night.new(7)
	_sim = s
	_script = []
	match lesson:
		Lesson.MOVE:
			for c in range(2, 8):
				s.seat(K.GNAT, c, 1)
				s.seat(K.GNAT, c, 2)
			s.px = 70.0
			_script = [[0.9, _press], [1.1, _to.bind(170.0, 50.0)], [3.7, _lift]]
			_len = 4.6
			_still_at = 1.9
		Lesson.SWARM:
			for c in range(3, 7):
				s.seat(K.MOTH, c, 0)
				s.seat(K.BEETLE, c, 1)
				s.seat(K.GNAT, c, 2)
			s.px = 110.0
			_script = [[0.9, _press], [2.4, _to.bind(130.0, 60.0)], [4.0, _lift]]
			_len = 5.0
			_still_at = 1.45
		Lesson.DIVE:
			for c in range(4, 6):
				s.seat(K.MOTH, c, 0)
			var row := []
			for c in range(3, 7):
				row.append(s.seat(K.BEETLE, c, 1))
			_script = [
				[0.7, func() -> void: s.send(row[3], [Vector2(138, 268), Vector2(160, 302), Vector2(176, 340), Vector2(190, 402)], [264.0])],
				[1.25, _press], [1.3, _chase.bind(false, true)], [2.9, _to.bind(112.0, 160.0)], [3.3, _lift],
				[3.6, func() -> void: s.send(row[0], [Vector2(100, 272), Vector2(88, 304), Vector2(64, 340), Vector2(40, 402)], [266.0])]]
			_len = 6.0
			_still_at = 1.55
		Lesson.ESCORT:
			var moths := []
			var row := []
			for c in range(3, 7):
				moths.append(s.seat(K.MOTH, c, 0))
				row.append(s.seat(K.BEETLE, c, 1))
			s.px = 150.0
			_script = [
				[0.7, func() -> void: s.send(moths[2], [Vector2(168, 256), Vector2(112, 274), Vector2(72, 292), Vector2(120, 312), Vector2(170, 334), Vector2(200, 402)], [], [row[2], row[3]])],
				[1.2, _press], [1.2, _mark.bind([row[3], row[2], moths[2]])], [3.0, _lift]]
			_len = 4.8
			_still_at = 1.9
		Lesson.BEAM:
			var moths := []
			for c in range(3, 7):
				moths.append(s.seat(K.MOTH, c, 0))
			s.seat(K.BEETLE, 2, 1)
			s.seat(K.BEETLE, 7, 1)
			_script = [
				[0.7, func() -> void: s.send_beam(moths[2], [Vector2(142, 246), Vector2(122, 252)])],
				[6.0, func() -> void: s.send(moths[2], [Vector2(150, 258), Vector2(118, 288), Vector2(96, 322), Vector2(80, 402)])],
				[6.55, _press], [6.55, _chase.bind(false, true)], [7.8, _chase.bind(true, false)], [9.6, _lift]]
			_len = 10.4
			_still_at = 3.0
		Lesson.FLYBY:
			s.stage = 3
			s.stream([Vector2(-0.08, 0.65), Vector2(0.25, 0.62), Vector2(0.55, 0.67), Vector2(0.80, 0.63), Vector2(0.90, 0.72),
				Vector2(0.72, 0.80), Vector2(0.45, 0.75), Vector2(0.20, 0.81), Vector2(0.10, 0.71), Vector2(0.25, 0.64),
				Vector2(0.55, 0.71), Vector2(0.85, 0.65), Vector2(1.10, 0.61)],
				[K.GNAT, K.BEETLE], 8, 0.5, 0.32)
			_script = [[0.9, _press], [0.9, _mark.bind(s.enemies.duplicate())], [6.0, _lift]]
			_len = 8.4
			_still_at = 2.2

## The lesson from its top.
func _reset() -> void:
	if _drawn() or not is_inside_tree() or size.x <= 0.0:
		return
	_plan()
	_next = 0
	_down = false
	_hunt = false
	_marks = []
	_last = {}
	_vel = {}
	_last_t = 0.0
	_aim = _sim.px
	_aim_to = _aim
	_garden.lay(_sim)
	_garden.set_process(not Motion.reduce)
	if Motion.reduce:
		# standing still: played unseen to the lesson's telling moment
		while _sim.t < _still_at:
			_drive(STILL_DT)
			_garden._process(STILL_DT)
		_over.queue_redraw()

func _process(delta: float) -> void:
	if _drawn() or not _begun or Motion.reduce:
		return
	_drive(delta)
	_over.queue_redraw()
	if _sim.t >= _len:
		_reset()

## The finger, a frame: its script, its chase, its slide.
func _drive(delta: float) -> void:
	while _next < _script.size() and _sim.t >= float(_script[_next][0]):
		(_script[_next][1] as Callable).call()
		_next += 1
	_watch()
	if not _down:
		# over the field, beside the firefly, wherever that now is
		_aim = _sim.px
		_aim_to = _aim
		return
	if _sim.ship != Sim.Ship.ALIVE:
		_lift()
		return
	if _hunt:
		_aim_to = _lead()
	_aim = move_toward(_aim, _aim_to, _speed * delta)
	_garden.slide(_garden.finger_at(_aim))

func _press() -> void:
	if _down or _sim.ship != Sim.Ship.ALIVE:
		return
	_down = true
	_hunt = false
	_aim = _sim.px
	_aim_to = _aim
	_garden.finger(_garden.finger_at(_aim), true)

func _lift() -> void:
	if not _down:
		return
	_down = false
	_hunt = false
	_garden.finger(_garden.finger_at(_aim), false)

## Slides until the firefly is at `x`, `speed` field units a second.
func _to(x: float, speed: float) -> void:
	_hunt = false
	_aim_to = x
	_speed = speed

## Chases the bugs: the ones in flight, and those in their seats when
## `seats`; the lowest first when `low`, else the nearest.
func _chase(seats: bool, low: bool) -> void:
	_hunt = true
	_hunt_seats = seats
	_low_first = low
	_marks = []
	_speed = 280.0

## Chases `bugs` one after another, in their order.
func _mark(bugs: Array) -> void:
	_chase(true, false)
	_marks = bugs

## Every bug's speed, from where it was a frame ago.
func _watch() -> void:
	var dt: float = _sim.t - _last_t
	if dt <= 0.0:
		return
	var now := {}
	for e: Dictionary in _sim.enemies:
		if _last.has(e.id):
			_vel[e.id] = ((e.pos as Vector2) - (_last[e.id] as Vector2)) / dt
		now[e.id] = e.pos
	_last = now
	_last_t = _sim.t

## Where the firefly must be for a shot fired now to meet the bug chased.
func _lead() -> float:
	var best := _aim_to
	var best_w := INF
	var marked := {}
	for e: Dictionary in _marks:
		if e.st != Sim.St.DEAD:
			if e.st == Sim.St.WAIT:
				return best
			marked = e
			break
	for e: Dictionary in _sim.enemies:
		var st: int = e.st
		if st == Sim.St.WAIT or st == Sim.St.DEAD or (not _marks.is_empty() and not is_same(e, marked)):
			continue
		var seated := st == Sim.St.FORM
		if seated and not _hunt_seats:
			continue
		var pos: Vector2 = e.pos
		if pos.y < Night.VIEW_TOP + 6.0 or pos.y > REACH or pos.x < 4.0 or pos.x > Sim.W - 4.0:
			continue
		var v: Vector2 = Vector2.ZERO if seated else _vel.get(e.id, Vector2.ZERO)
		var x := pos.x + v.x * (Sim.PLAYER_Y - 8.0 - pos.y) / (Sim.SHOT_SPEED + v.y)
		var w := -pos.y if _low_first else absf(x - _sim.px)
		if seated:
			w += 1000.0
		if w < best_w:
			best_w = w
			best = x
	if best_w == INF:
		return best
	# a pair's two shots straddle it: the left one is put on the bug
	return clampf(best + (Sim.PAIR if _sim.pair else 0.0), 16.0, Sim.W - 16.0)

# --- drawing ---

## The finger over the garden: a ring while it hovers, pressed in while it
## is down.
func _draw_finger() -> void:
	if _sim == null or (Motion.reduce and not _down):
		_finger_shown = null
		return
	var at: Vector2 = _garden.position + _garden.finger_at(_aim) + (Vector2.ZERO if _down else Vector2(0, -14.0))
	var r := FINGER_R * (0.86 if _down else 1.0)
	var b := Face.Builder.new()
	b.disc(at, r, Color(1, 1, 1, 0.3 if _down else 0.1))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(1, 1, 1, 0.75 if _down else 0.4), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)

func _draw() -> void:
	if size.x <= 0.0:
		return
	if lesson == Lesson.HUD:
		_draw_hud()
		return
	if lesson == Lesson.SHOP:
		_draw_shop()
		return
	# the garden's wooden frame
	var b := Face.Builder.new()
	var at := _garden.position - Vector2(FRAME, FRAME)
	var sz := _garden.size + Vector2(FRAME, FRAME) * 2.0
	b.polygon(Face.Builder.round_rect(at, sz, 22.0), WOOD_EDGE)
	b.polygon(Face.Builder.round_rect(at + Vector2(4, 4), sz - Vector2(8, 8), 18.0), WOOD)
	_frame_shown = b.mesh()
	draw_mesh(_frame_shown, null)

## A button's side on the HUD page, and how wide its column of them is.
func _hud_chip() -> float:
	return minf(100.0, size.y / 3.0 * 0.68)

func _hud_col() -> float:
	return _hud_chip() * 2.0 + HUD_GAP + 16.0

## The HUD page: Reset, the gear and the ?, and the boosters, each drawn as
## it is on the screen beside what it does.
func _draw_hud() -> void:
	var rows := [[["reset"], "TUT_FIREFLY_HUD_RESET"], [["gear", "help"], "TUT_FIREFLY_HUD_PAUSE"], [[], "TUT_FIREFLY_HUD_BOOST"]]
	var row_h := size.y / rows.size()
	var chip := _hud_chip()
	var gap := HUD_GAP
	var x0 := HUD_X
	var col := _hud_col()
	var b := Face.Builder.new()
	var marks: Array = []
	for k in rows.size():
		var cy := row_h * (k + 0.5)
		var icons: Array = rows[k][0]
		var wide := icons.size() * chip + (icons.size() - 1) * gap
		for i in icons.size():
			var r := Rect2(Vector2(x0 + (col - wide) * 0.5 + i * (chip + gap), cy - chip * 0.5), Vector2(chip, chip))
			b.polygon(Face.Builder.round_rect(r.position + Vector2(0, 6.0), r.size, 26.0), Color(Pal.TEXT, 0.16))
			b.polygon(Face.Builder.round_rect(r.position, r.size, 26.0), Pal.SURFACE)
			marks.append([String(icons[i]), r])
	_hud_shown = b.mesh()
	draw_mesh(_hud_shown, null)
	for m: Array in marks:
		var r: Rect2 = m[1]
		Icons.paint(self, String(m[0]), Rect2(r.get_center() - r.size * 0.27, r.size * 0.54), Pal.TEXT, Pal.SURFACE)
	var font: Font = CozyTheme.display(700)
	var tx := x0 + col + 28.0
	var room := size.x - tx - 24.0
	for k in rows.size():
		var line := tr(String(rows[k][1]))
		var tall := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, room, 30).y
		draw_multiline_string(font, Vector2(tx, row_h * (k + 0.5) - tall * 0.5 + 30.0 * 0.82), line, HORIZONTAL_ALIGNMENT_LEFT, room, 30, -1, Pal.TEXT)

## The shop's page, laid as the HUD's: the mote a bug drops, the gun's three
## cards and the other two, each row beside what it is.
func _draw_shop() -> void:
	var C := Sim.Card
	var rows := [[[-1], "TUT_FIREFLY_SHOP_ENERGY"], [[C.DAMAGE, C.SPEED, C.SHOTS], "TUT_FIREFLY_SHOP_GUN"],
		[[C.CRIT, C.ENERGY], "TUT_FIREFLY_SHOP_MORE"]]
	var row_h := size.y / rows.size()
	var disc := minf(84.0, row_h * 0.6)
	var gap := 8.0
	var col := disc * 3.0 + gap * 2.0
	for k in rows.size():
		var cy := row_h * (k + 0.5)
		var icons: Array = rows[k][0]
		var wide := icons.size() * disc + (icons.size() - 1) * gap
		for i in icons.size():
			var c := Vector2(HUD_X + (col - wide) * 0.5 + i * (disc + gap) + disc * 0.5, cy)
			if int(icons[i]) < 0:
				# a mote, on a slip of the night it is seen against
				var b := Face.Builder.new()
				b.disc(c, disc * 0.5, Color("2a2c5a"))
				_hud_shown = b.mesh()
				draw_mesh(_hud_shown, null)
				var sc := Motes.icon_scale(disc * 0.8)
				draw_mesh(Motes.orb(), null, Transform2D(0.0, Vector2(sc, sc), 0.0, c))
			else:
				draw_mesh(Art.card_token(int(icons[i]), disc), null, Transform2D(0.0, c))
	var font: Font = CozyTheme.display(700)
	var tx := HUD_X + col + 28.0
	var room := size.x - tx - 24.0
	for k in rows.size():
		var line := tr(String(rows[k][1]))
		var tall := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, room, 30).y
		draw_multiline_string(font, Vector2(tx, row_h * (k + 0.5) - tall * 0.5 + 30.0 * 0.82), line, HORIZONTAL_ALIGNMENT_LEFT, room, 30, -1, Pal.TEXT)
