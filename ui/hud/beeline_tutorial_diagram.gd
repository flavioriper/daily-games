extends Control

## One page of Beeline's tutorial: a small garden flown by the game itself.
## The page holds a `Garden` -- arcade/beeline_screen.gd with its top bar,
## plates, cards, lettering, sound and record taken out, so what is left is
## the framed garden -- running a `Round`, the game's own sim with a hand
## added: it beats her wings whenever she sinks under a line, through the
## screen's own `beat`. So she lifts on a tap and sinks without one, the
## hedges come and the big number counts the gaps, a hedge met knocks her
## dizzy onto the lawn, and the tenth gap wears its ribbon and pays it,
## exactly as in the garden. `lesson` picks the page (set before it enters
## the tree):
##
## - FLY: no hedge in sight; taps hold her level, then she is let sink and
##   is caught again.
## - GAPS: the hand flies her through the gaps and the number counts them.
## - BUMP: after one gap the hand lets go, and she meets the next hedge.
## - RIBBONS: the run stands at eight; the tenth gap pays the first ribbon.
## - BOOSTS: the two boosters and the Second chance, drawn as chips.
## - HUD: the top bar's Reset, gear and ?, drawn as they are (a beat is never
##   taken back, so no Undo).

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://arcade/beeline_sim.gd")
const Boosters = preload("res://arcade/boosters.gd")

enum Lesson { FLY, GAPS, BUMP, RIBBONS, BOOSTS, HUD }

## A tap's finger stays down this long.
const TAP_DOWN := 0.14
const FINGER_ALPHA := 0.16

var lesson: int = Lesson.FLY

var _garden: Garden
var _over: Control
var _begun := false
## When the lesson starts over, and the second a still page stands at.
var _length := 6.0
var _still_at := 1.0
var _finger_shown: ArrayMesh
var _rows_shown: ArrayMesh

## The game's sim with a hand on it: a beat whenever she sinks under `line`
## (under the next gap's foot when `line` is below nothing), from `from`
## until `until`.
class Round extends "res://arcade/beeline_sim.gd":
	var clock := 0.0
	var line := -1.0
	var rest_from := INF
	var rest_until := INF
	var on_tap := Callable()
	var tapped_at := -10.0

	func step() -> void:
		clock += DT
		if phase == Phase.PLAY and (clock < rest_from or clock >= rest_until) and v > 0.0:
			var g := next_gate()
			var want: float = line if line >= 0.0 else float(g.cy) + float(g.gap) * 0.5 - R - 14.0
			if y > want:
				tapped_at = clock
				on_tap.call()
		super()

	## No hedge anywhere near: a page about her wings alone.
	func open_sky() -> void:
		for g: Dictionary in gates:
			g.x = float(g.x) + 100000.0

	## The run as it stands after `n` gaps, the hedges ahead numbered on.
	func stand_at(n: int) -> void:
		score = n
		ribbons = ribbons_of(n)
		gates.clear()
		_made = n
		_last_cy = START_Y
		_grow()

## The screen, quiet: the framed garden alone, no top bar, plate, sheet,
## card or hint, no sound (its id names no set), no knock, no record and no
## analytics.
class Garden extends "res://arcade/beeline_screen.gd":
	## The garden is no wider than this for its height, so the bee is not
	## lost in a long strip of it.
	const WIDE := 1.25
	## A page looks closer: this much of the garden's height, in units, and
	## the look follows her this fast.
	const TALL := 250.0
	const FOLLOW := 2.2

	var _frame: PanelContainer

	## The rewards with no lettering but a ribbon's, cut to the page, and
	## nothing flown to a plate the page has not got.
	class Quiet extends "res://arcade/rewards.gd":
		func sticker(text: String, where: Vector2, fs: int, life: float, rainbow := true, col := Color.WHITE, rays := false, id := "", rise := 0.0, keep := false) -> Dictionary:
			if id != "ribbon":
				return {}
			return super(text, where, mini(fs, 44), life, rainbow, col, rays, id, rise, keep)

		func spray(from: Vector2, col: Color, n: int, speed: float, kind := "spark", size := 1.0, delay := 0.0, to := Vector2.INF) -> void:
			if to == Vector2.INF:
				super(from, col, n, speed * 0.5, kind, size * 0.6, delay, to)

		func ring(_from: Vector2, _radius: float, _col: Color, _delay := 0.0, _life := 0.45) -> void:
			pass

	func puzzle_id() -> String:
		return "beeline_tutorial"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# the plates are read by the screen and never shown
		var plates := _build_hud()
		plates.visible = false
		add_child(plates)
		_frame = _build_frame()
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_frame)
		field.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.buzzes = false
		_rw = Quiet.new()
		add_child(_rw)
		resized.connect(_fit)

	## The size the garden takes in `room`: all its height, and no wider than
	## WIDE of it.
	static func size_for(room: Vector2) -> Vector2:
		var tall := room.y - 2.0 * FRAME
		return Vector2(minf(room.x, tall * WIDE + 2.0 * FRAME), room.y).floor()

	func _fit() -> void:
		_frame.position = Vector2.ZERO
		_frame.size = size
		# now, not on the frame's next sort: a lesson laid this frame is drawn
		# in the field's pixels
		field.position = Vector2(FRAME, FRAME)
		field.size = size - Vector2(FRAME, FRAME) * 2.0

	func _tall_units() -> float:
		return TALL

	## The look drifts after her, so a beat still reads as a lift.
	func _animate(delta: float) -> void:
		super(delta)
		_cam = lerpf(_cam, _cam_for(), minf(1.0, delta * FOLLOW))

	func _cam_for() -> float:
		return clampf(sim.y * _u - field.size.y * 0.5, 0.0, (Sim.H + Art.GROUND) * _u - field.size.y)

	func _pause(_on: bool) -> void:
		pass

	func _hint(_text: String, _sub_text: String) -> void:
		pass

	func _run_over() -> void:
		pass

	## A round laid on the garden, already flying: nothing left of the last.
	func lay(game: RefCounted) -> void:
		sim = game
		_acc = 0.0
		_paused = false
		_bits.clear()
		_shake = 0.0
		_shake_off = Vector2.ZERO
		_flash = 0.0
		_bumped = false
		_lean = 0.0
		_flap_at = -10.0
		_pass_at = -10.0
		_best = 0
		_beat_best = false
		_shown_score = sim.score
		_milestone = 0
		_rw.clear()
		_cam = _cam_for()

	## The round run to second `at` and held there, for a page that stands
	## still.
	func hold(at: float) -> void:
		while sim.clock < at and not sim.is_over():
			sim.step()
			_play_events()
			_clock += Sim.DT
			_animate(Sim.DT)
		_paused = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if _played():
		_garden = Garden.new()
		add_child(_garden)
		_over = Control.new()
		_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_over.z_index = 6
		_over.draw.connect(_draw_finger)
		add_child(_over)
	resized.connect(_layout)
	call_deferred("_layout")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun:
		call_deferred("_reset")

func _played() -> bool:
	return lesson != Lesson.BOOSTS and lesson != Lesson.HUD

func _layout() -> void:
	if not _played():
		queue_redraw()
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# the frame's shadow falls under it
	var room := size - Vector2(0, 14.0)
	_garden.size = Garden.size_for(room)
	_garden.position = ((room - _garden.size) * 0.5).round()
	_over.position = Vector2.ZERO
	_over.size = size
	if not _begun and is_inside_tree():
		_begun = true
		_reset()

# --- the lessons ---

## The lesson from its top: a fresh round in the garden, already flying.
func _reset() -> void:
	if not _played() or not is_inside_tree() or size.x <= 0.0:
		return
	var game := Round.new(4)
	game.events.clear()
	game.on_tap = _garden.beat
	match lesson:
		Lesson.FLY:
			# held level, let sink for a moment, caught again
			game.open_sky()
			game.line = 190.0
			game.rest_from = 2.4
			game.rest_until = 2.95
			_length = 6.0
			_still_at = 1.2
		Lesson.GAPS:
			_length = 9.0
			_still_at = 3.3
		Lesson.BUMP:
			# through the first gap, then the hand lets go
			game.rest_from = (Sim.LEAD + Sim.GATE_W + 30.0) / Sim.SPEED
			_length = game.rest_from + 3.2
			_still_at = game.rest_from + 1.25
		Lesson.RIBBONS:
			game.stand_at(Sim.RIBBONS[0] - 2)
			_length = 8.5
			_still_at = (Sim.LEAD + Sim.SPACING + Sim.GATE_W + 40.0) / Sim.SPEED
	_garden.lay(game)
	game.flap()
	_garden._play_events()
	if Motion.reduce:
		_garden.hold(_still_at)
	_over.queue_redraw()

func _process(_delta: float) -> void:
	if not _played() or not _begun or Motion.reduce:
		return
	_over.queue_redraw()
	if _garden.sim.clock >= _length:
		_reset()

# --- drawing ---

## The finger, low in the garden's thumb corner: down for a moment on every
## beat.
func _draw_finger() -> void:
	if _garden.sim == null:
		return
	var game: Round = _garden.sim
	var field: Control = _garden.field
	var down := game.clock - game.tapped_at < TAP_DOWN or (Motion.reduce and game.phase == Sim.Phase.PLAY)
	var at: Vector2 = _over.get_global_transform().affine_inverse() * (field.get_global_transform() * (field.size * Vector2(0.74, 0.7)))
	var r := field.size.y * 0.075 * (0.85 if down else 1.0)
	var b := Face.Builder.new()
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.8 if down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 4.0, Color(Pal.TEXT, 0.55), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)

## The chip pages: the boosters with what each does, and the top bar's
## buttons drawn as they are on the screen beside what they do here.
func _draw() -> void:
	if _played() or size.x <= 0.0:
		return
	var rows: Array = []
	if lesson == Lesson.BOOSTS:
		rows = [
			[Boosters.icon("bl_dew"), tr("TUT_BEELINE_BOOST_DEW")],
			[Boosters.icon("bl_wide"), tr("TUT_BEELINE_BOOST_WIDE") % Boosters.BL_WIDE],
			[Boosters.icon(Boosters.CHANCE), tr("TUT_BEELINE_BOOST_CHANCE")],
		]
	else:
		rows = [
			["reset", tr("TUT_BEELINE_HUD_RESET")],
			["gear", tr("TUT_BEELINE_HUD_GEAR")],
			["help", tr("TUT_BEELINE_HUD_HELP")],
		]
	var boosts := lesson == Lesson.BOOSTS
	var row_h := size.y / rows.size()
	var chip := minf(104.0, row_h * 0.72)
	var x0 := 36.0
	var b := Face.Builder.new()
	var centres: Array = []
	for k in rows.size():
		var c := Vector2(x0 + chip * 0.5, row_h * (k + 0.5))
		centres.append(c)
		if boosts:
			# a booster is a disc in its game's colour, the Second chance gold
			var tint: Color = Boosters.tint(Boosters.CHANCE if k == 2 else "bl_dew")
			b.disc(c + Vector2(0, 6.0), chip * 0.5, Color(Pal.TEXT, 0.16))
			b.disc(c, chip * 0.5, tint)
		else:
			var at := c - Vector2(chip, chip) * 0.5
			b.polygon(Face.Builder.round_rect(at + Vector2(0, 6.0), Vector2(chip, chip), 26.0), Color(Pal.TEXT, 0.16))
			b.polygon(Face.Builder.round_rect(at, Vector2(chip, chip), 26.0), Pal.SURFACE)
	_rows_shown = b.mesh()
	draw_mesh(_rows_shown, null)
	var font: Font = CozyTheme.display(700)
	var tx := x0 + chip + 28.0
	var wide := size.x - tx - 24.0
	for k in rows.size():
		var c: Vector2 = centres[k]
		Icons.paint(self, String(rows[k][0]), Rect2(c - Vector2(chip, chip) * 0.27, Vector2(chip, chip) * 0.54),
			Pal.SURFACE if boosts else Pal.TEXT, Color.TRANSPARENT if boosts else Pal.SURFACE)
		var line := String(rows[k][1])
		var lines := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30)
		draw_multiline_string(font, Vector2(tx, c.y - lines.y * 0.5 + 30.0 * 0.82), line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30, -1, Pal.TEXT)
