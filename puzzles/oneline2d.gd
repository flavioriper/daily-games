extends "res://core/puzzle_base.gd"

## One Line as a flat board: the figure drawn square-on on the host's
## parchment card, its lines lying as dark stone fords, and a snail walking
## the stroke that lays a warm plank over every one it crosses. Built beside
## the island version (puzzles/oneline3d.gd) so the two can be judged against
## each other on the phone; the rules live in puzzles/oneline_state.gd, which
## this only draws.
##
## What flat buys here is the figure. Half of a hard board's lines are
## diagonals, and seen at seven degrees a 45-degree plank is not at 45 degrees
## any more: the lattice shears, the near rows stretch, the far rows crowd,
## and the shape the player is asked to trace is a shape the camera invented.
## Worse, One Line is the only board in the set that asks a question about the
## *whole* drawing -- is what is left still all in one piece from where I
## stand -- which is the last thing that should be foreshortened. Square-on,
## the figure is the figure, and a crossing stops being a rendering problem:
## the island has to lift every plank 0.0008 per edge index to keep two
## coplanar top faces from z-fighting, and here the later stroke is simply on
## top. **And it buys the walker.** On the island the player's finger is the
## walker and the planks rise behind it; flat, a small character can ride the
## stroke and lay the line as it goes, which makes "without lifting your
## finger" literal and costs a canvas almost nothing.
##
## How it is drawn. The whole figure is **one** mesh, rebuilt only while
## something is moving: every line as a stone stroke, every plank walked over
## it, and every post as a drum with its coloured cap. The stone runs first
## and the planks all go over it, so the trail is never cut by a line nobody
## has walked. Only the walker is a Control, with the face family's cached
## meshes behind it (ui/faces/snail_face.gd).
## Spec: docs/superpowers/specs/2026-09-18-oneline-flat-design.md, sections 2
## to 7, and the mock it is ported from
## (docs/brainstorm/concepts.html#oneline).

const State = preload("res://puzzles/oneline_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const SnailFace = preload("res://ui/faces/snail_face.gd")

# --- the field ---
## The card's inset around the figure.
const PAD := 40.0
## The lattice keeps **square spacing** -- the same distance across as down --
## so a diagonal stays a diagonal and the figure reads as a drawing rather
## than as a stretched grid. This is the post and its air at the edge of the
## figure, in steps, which is what the lattice needs beyond its own span.
const MARGIN := 0.8

# --- the pieces, in steps ---
const POST_R := 0.17
const LINE_W := 0.13
const PLANK_DEEP_W := 0.15
const PLANK_W := 0.115
const SNAIL_R := 0.15
## How high above the line the walker rides, so it sits on the plank rather
## than inside it.
const SNAIL_LIFT := 0.34
## How close a tap or a drag has to pass a post to take it. The line between
## two posts is never in doubt, so there is nothing to aim at but the post:
## this is simply a thumb-sized reach, and it is the tightest gesture of the
## eight flat screens (37 CSS pixels on hard).
const REACH := 0.42

# --- motion ---
## The island's own LAY_TIME: a plank grows under the walker over this, which
## is also exactly how long the walker takes to cross the line.
const LAY_TIME := 0.28
const ENTER_LINE := 0.14
const ENTER_LINE_STEP := 0.02
const ENTER_LINE_TIME := 0.4
const ENTER_POST := 0.2
const ENTER_POST_STEP := 0.03
const ENTER_POST_TIME := 0.4
const ENTER_POST_FROM := 0.7
const ENTER_POST_LIFT := 0.14
const POP_TIME := 0.26
const DIP := 0.04
const DIP_TIME := 0.3
const RING_TIME := 0.8
const RING_R := 1.32
const RING_W := 0.2
const FLASH := 0.035
const FLASH_TIME := 0.6
const FLASH_SWINGS := 9.0
const ROCK := 0.07
const ROCK_RATE := 9.0
const ROCK_STILL := 0.25
## The finished trail warms a shade brighter, plank by plank in walk order.
const BRIGHT_DELAY := 0.15
const BRIGHT_STEP := 0.06
const BRIGHT_TIME := 0.35
const SOLVE_HOP := 0.1
const SOLVE_HOPS := 3.0
## How long the host waits before the win screen: the trail has to finish
## warming and the walker has to land.
const WIN_WAIT := 2.0

const HINTS := State.HINTS
const TIP_CYCLE := 10.0
## The three lines that teach the board, cycled while there is nothing better
## to say.
const TIPS := [
	"Start on a green post and walk every line exactly once, without lifting your finger.",
	"Drag from post to post. A line you have walked turns from stone to warm plank.",
	"Two green posts mean the stroke has to begin at one of them.",
]

var state = State.new()
## The names the win harness and the island board share, so one driver solves
## both twins: they are the state's own.
var _edges: Array:
	get: return state.edges
var _nodes: Array:
	get: return state.nodes
var _walked: Dictionary:
	get: return state.walked

var fx: Node2D
var snail: SnailFace
var _step := 0.0
var _origin := Vector2.ZERO
var _card := Rect2()

## The line in flight, and the walker's own travel with it:
## {"edge", "from", "to", "at", "up"}. `from` and `to` are posts -- the walker
## goes from one to the other in either direction -- and `up` is false for an
## undo, where the plank sinks back to stone instead of growing. The plank
## always grows from the end it was originally walked from (`up` ? from : to),
## which is what keeps the trail behind the snail and never against it.
var _stroke: Dictionary = {}
var _dip: Dictionary = {}       # node -> the second a refused tap dipped it
var _ring: Dictionary = {}      # node -> the second a hint rang it
var _flash: Dictionary = {}     # edge -> the second Check shook it
var _bright: Dictionary = {}    # edge -> the second it warms on the win
var _begin_at := -100.0
var _opened := 0.0
var _solved_at := -1.0

var _figure: ArrayMesh
## The mesh the last _draw actually handed to the canvas item. A canvas
## command holds the mesh by RID and not by reference, so dropping the only
## reference to a mesh still on the item's command list leaves the renderer
## drawing a freed RID ("Parameter mesh is null", and an empty card) on any
## frame rendered without its queued redraw flushed first -- which is what
## RenderingServer.force_draw() in a harness does.
var _shown: ArrayMesh

var _drawing := false
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "oneline"
func title() -> String: return "One Line"

func rules() -> String:
	return "Start on a green post and walk along every line exactly once, without going over one twice. Walk into a part of the figure you cannot get back out of and the rest is stranded: undo back to the fork."

func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	snail = SnailFace.new()
	snail.name = "Walker"
	snail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	snail.z_index = 1
	add_child(snail)
	snail.set_idle(true)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	state.setup(rng, difficulty)
	_stroke = {}
	_dip = {}
	_ring = {}
	_flash = {}
	_bright = {}
	_begin_at = -100.0
	_drawing = false
	_solved_at = -1.0
	_opened = _now()
	_layout()
	_tip_idx = 0
	_say(TIPS[0], Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("enter")

# --- layout ---

## The figure is the largest square-spaced lattice the card holds, and the
## card is then cut to the figure and centred in the slot rather than pinned
## under the day card. Easy and hard fill it; medium, whose lattice is wider
## than it is tall, leaves air above and below in equal measure -- which reads
## as room, where all of it below would read as a board that fell over.
func _layout() -> void:
	if state.nodes.is_empty():
		return
	_step = _step_for(size.y)
	if _step <= 0.0:
		return
	var figure := Vector2(_step * (state.cols - 1), _step * (state.rows - 1))
	var tall := minf(size.y, figure.y + 2.0 * PAD + _step * MARGIN)
	_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
	_origin = Vector2(size.x * 0.5 - figure.x * 0.5,
		_card.position.y + (tall - figure.y) * 0.5)
	_refresh()

## The lattice step a slot of `available` height holds. The figure's span is
## one step short of its lattice, plus the MARGIN a post and its air want at
## each edge.
func _step_for(available: float) -> float:
	if state.nodes.is_empty():
		return 0.0
	return minf((size.x - 2.0 * PAD) / (float(state.cols) - 1.0 + MARGIN),
		(available - 2.0 * PAD) / (float(state.rows) - 1.0 + MARGIN))

## The host cuts its card to the figure and centres it, which is what these
## two say.
func card_height(available: float) -> float:
	var one := _step_for(available)
	if one <= 0.0:
		return available
	return minf(available, one * (float(state.rows) - 1.0 + MARGIN) + 2.0 * PAD)

func card_centred() -> bool:
	return true

## Control-local point over post `n`. The win harness taps these, exactly as
## it does on the island board.
func node_to_local(n: int) -> Vector2:
	return _origin + Vector2(n % state.cols, n / state.cols) * _step

## The post nearest `at` within a thumb of it, or -1.
func _nearest(at: Vector2) -> int:
	if _step <= 0.0:
		return -1
	var best := -1
	var closest := _step * REACH
	for n in state.nodes:
		var d := at.distance_to(node_to_local(n))
		if d < closest:
			closest = d
			best = n
	return best

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _step <= 0.0 or state.nodes.is_empty():
		return
	if _animating(_now()):
		_refresh()

## True while anything on the board is still moving. Nothing is rebuilt or
## redrawn on a frame this says no to, which is most of them: a figure sitting
## still costs the walker's blinks and nothing else.
func _animating(t: float) -> bool:
	# Both waves, and the later of the two: the lines fade in one per index and
	# the posts drop on a diagonal, and on a figure with many lines the lines
	# are the ones still going. Watching only the posts froze the last few
	# chords at four fifths of their fade -- visible on a rendered frame as two
	# pale lines that never arrived.
	var entrance: float = maxf(
		ENTER_LINE + float(state.edges.size()) * ENTER_LINE_STEP + ENTER_LINE_TIME,
		ENTER_POST + float(state.cols + state.rows) * ENTER_POST_STEP + ENTER_POST_TIME)
	if t < _opened + entrance:
		return true
	if _solved_at >= 0.0 and t < _solved_at + WIN_WAIT:
		return true
	if t < _begin_at + POP_TIME:
		return true
	if not _stroke.is_empty() and t < float(_stroke.at) + LAY_TIME:
		return true
	for n in _dip:
		if t < float(_dip[n]) + DIP_TIME:
			return true
	for n in _ring:
		if t < float(_ring[n]) + RING_TIME:
			return true
	for e in _flash:
		if t < float(_flash[e]) + FLASH_TIME:
			return true
	for e in _bright:
		if t < float(_bright[e]) + BRIGHT_TIME:
			return true
	return false

func _refresh() -> void:
	if _step <= 0.0 or state.nodes.is_empty():
		return
	var t := _now()
	_place_walker(t)
	_figure = _build_figure(t)
	queue_redraw()

# --- the walker ---

## The snail rides the stroke: on the post it stands on, or part way along the
## line it is crossing, facing the way it is heading and rocking as it goes.
func _place_walker(t: float) -> void:
	if state.current < 0:
		snail.visible = false
		return
	snail.visible = true
	var seat := _step * SNAIL_R * SnailFace.SEAT
	snail.size = Vector2.ONE * seat
	snail.pivot_offset = snail.size * 0.5
	var ride := _ride(t)
	var at: Vector2 = ride.at - Vector2(0.0, _step * SNAIL_LIFT + _hop(t))
	snail.position = at - snail.size * 0.5
	var pop := 1.0
	if not Motion.reduce:
		var u := clampf((t - _begin_at) / POP_TIME, 0.0, 1.0)
		pop = lerpf(0.01, 1.0, _back_out(u))
	snail.scale = Vector2(pop * (-1.0 if ride.dir < 0.0 else 1.0), pop)
	snail.rotation = 0.0 if Motion.reduce else sin(t * ROCK_RATE) * ROCK \
		* (1.0 if ride.moving else ROCK_STILL)
	if is_done():
		snail.expression = Face.Expr.JOY
	elif not state.stranded().is_empty():
		snail.expression = Face.Expr.STRAIN
	else:
		snail.expression = Face.Expr.HAPPY

## Where the walker is, which way it faces, and whether it is on the move.
func _ride(t: float) -> Dictionary:
	var at := node_to_local(state.current)
	var dir := 1.0
	var moving := false
	if not _stroke.is_empty():
		var a := node_to_local(int(_stroke.from))
		var b := node_to_local(int(_stroke.to))
		var u := _dec((t - float(_stroke.at)) / LAY_TIME)
		if u < 1.0:
			at = a.lerp(b, u)
			moving = true
		dir = 1.0 if b.x >= a.x else -1.0
	return {"at": at, "dir": dir, "moving": moving}

## The hop the walker takes on the post the stroke finished at, damped so it
## lands rather than bobbing for ever.
func _hop(t: float) -> float:
	if Motion.reduce or _solved_at < 0.0:
		return 0.0
	var u := clampf((t - _solved_at) / WIN_WAIT, 0.0, 1.0)
	return _step * SOLVE_HOP * absf(sin(u * PI * SOLVE_HOPS)) * (1.0 - u)

# --- the drawing ---

func _draw() -> void:
	_shown = _figure
	if _shown != null:
		draw_mesh(_shown, null)

## The whole figure in one mesh: every line as stone, every plank walked over
## it, then the posts. The stone runs in one pass before any plank, so a
## walked line is never cut where an unwalked one crosses it -- the island
## cannot do that at all, since its planks are solids at the same height.
func _build_figure(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var lost: Dictionary = {}
	for e in state.stranded():
		lost[e] = true
	for i in state.edges.size():
		var en := _line_entrance(i, t)
		if en <= 0.0:
			continue
		var ends := _line_ends(i)
		var shake := _shake(i, t)
		b.stroke(PackedVector2Array([ends[0] + shake, ends[1] + shake]),
			_step * LINE_W,
			Color(Pal.PLANK_LOST if lost.has(i) else Pal.PLANK_BARE, en))
	for i in state.edges.size():
		var en := _line_entrance(i, t)
		if en <= 0.0:
			continue
		_build_plank(b, i, t, en)
	for n in state.nodes:
		_build_post(b, n, t)
	if b.verts.is_empty():
		return null
	return b.mesh()

## The plank laid over line `i`, as far along as the walker has taken it. It
## grows from the post the walker crossed *from*, and on the win it warms a
## shade brighter in walk order, so the finished figure draws itself once more.
func _build_plank(b, i: int, t: float, alpha: float) -> void:
	var u := 1.0 if state.walked.has(i) else 0.0
	var anchor: int = int(state.lay_from.get(i, state.edges[i].x))
	if not _stroke.is_empty() and int(_stroke.edge) == i:
		var prog := _dec((t - float(_stroke.at)) / LAY_TIME)
		u = prog if bool(_stroke.up) else 1.0 - prog
		anchor = int(_stroke.from) if bool(_stroke.up) else int(_stroke.to)
	if u <= 0.0:
		return
	var edge: Vector2i = state.edges[i]
	var from := node_to_local(anchor)
	var to := node_to_local(edge.y if anchor == edge.x else edge.x)
	var shake := _shake(i, t)
	var line := PackedVector2Array([from + shake, from.lerp(to, u) + shake])
	var warm: Color = Pal.PLANK_LAID
	if _bright.has(i):
		warm = warm.lerp(Pal.PLANK_HI,
			_dec((t - float(_bright[i])) / BRIGHT_TIME))
	b.stroke(line, _step * PLANK_DEEP_W, Color(Pal.WOOD_DEEP, alpha))
	b.stroke(line, _step * PLANK_W, Color(warm, alpha))

## A mooring post, seen from above the way the whole board is: a stone drum
## with a coloured cap. The cap carries all the guidance, which is the
## island's own use for it -- a player who cannot see where the stroke may
## start cannot start it.
func _build_post(b, n: int, t: float) -> void:
	var en := _dec((t - _opened - ENTER_POST
		- float(n % state.cols + n / state.cols) * ENTER_POST_STEP) / ENTER_POST_TIME)
	if en <= 0.0:
		return
	var at := node_to_local(n)
	var R := _step * POST_R
	if not Motion.reduce:
		var eased := _back_out(en)
		R *= lerpf(ENTER_POST_FROM, 1.0, eased)
		at.y -= _step * ENTER_POST_LIFT * (1.0 - eased)
		var dip := (t - float(_dip.get(n, -100.0))) / DIP_TIME
		if dip >= 0.0 and dip < 1.0:
			at.y += _step * DIP * sin(PI * dip)
	b.ellipse(at + Vector2(0.05, 0.3) * R, 0.92 * R, 0.8 * R, Color(Pal.TEXT, 0.13 * en))
	b.disc(at + Vector2(0.0, 0.1) * R, R, Color(Pal.POST_DEEP, en))
	b.disc(at, R, Color(Pal.POST_STONE, en))
	b.disc(at + Vector2(0.0, -0.04) * R, 0.62 * R, Color(_cap_of(n), en))
	b.ellipse(at + Vector2(-0.2, -0.26) * R, 0.26 * R, 0.16 * R, Color(1.0, 1.0, 1.0, 0.22 * en))
	var ring := (t - float(_ring.get(n, -100.0))) / RING_TIME
	if ring >= 0.0 and ring < 1.0:
		b.stroke(Face.Builder.ring(at, RING_R * R, RING_R * R), RING_W * R,
			Color(Pal.GOOD, 0.9 * en * (1.0 - ring)), true)

## The island's four caps, unchanged: terracotta under the walker, green on a
## post the stroke may begin at, teal where lines are still to walk, and pale
## stone once a post is finished with. The measurement says the green matters
## most -- 198 of 200 easy figures and all 400 of the harder ones have exactly
## two odd posts, so the opening is forced almost every time.
func _cap_of(n: int) -> Color:
	if n == state.current:
		return Pal.ACCENT_2
	if state.current < 0 and state.may_start(n):
		return Pal.GOOD
	if state.open_at(n) > 0:
		return Pal.ACCENT
	return Pal.POST_SPENT

func _line_ends(i: int) -> Array:
	var edge: Vector2i = state.edges[i]
	return [node_to_local(edge.x), node_to_local(edge.y)]

## The stone lines fade in one per ENTER_LINE_STEP in index order, so the
## figure draws itself before the first touch: it is the thing to read, and
## the planks are the answer to it.
func _line_entrance(i: int, t: float) -> float:
	return _dec((t - _opened - ENTER_LINE - float(i) * ENTER_LINE_STEP) / ENTER_LINE_TIME)

## The shake a failed Check gave line `i`.
func _shake(i: int, t: float) -> Vector2:
	if Motion.reduce:
		return Vector2.ZERO
	var u := (t - float(_flash.get(i, -100.0))) / FLASH_TIME
	if u < 0.0 or u >= 1.0:
		return Vector2.ZERO
	return Vector2(_step * FLASH * sin(FLASH_SWINGS * PI * u) * (1.0 - u), 0.0)

# --- input ---

## Touch and drag only, as every flat board takes them. A press takes the post
## under it; a drag steps whenever the finger comes within a thumb of a
## neighbouring post, because the line between two posts is never in doubt.
## Taps work too: the same reach, one step at a time, which is what a player
## with a small screen and a big thumb will actually do.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.position)
		else:
			_drawing = false
	elif event is InputEventScreenDrag and _drawing:
		_reach(event.position)

func _press(at: Vector2) -> void:
	if is_done():
		return
	var n := _nearest(at)
	if n < 0:
		return
	_drawing = true
	_take(n)

func _reach(at: Vector2) -> void:
	if is_done():
		return
	var n := _nearest(at)
	if n < 0 or n == state.current:
		return
	_take(n)

func _take(n: int) -> void:
	if state.current < 0:
		_begin(n)
	else:
		_walk_to(n)

## Stands the walker on a post to open the stroke. A post the figure forbids
## answers with a dip and a line from the sprout rather than a move.
func _begin(n: int) -> void:
	var t := _now()
	if not state.begin(n):
		_dip[n] = t
		_say("The stroke has to begin on one of the two green posts."
			if not state.starts.is_empty()
			else "Begin anywhere: this figure has no odd post.", Face.Expr.PUZZLED)
		fx.cue("locked")
		_refresh()
		return
	_begin_at = t
	_stroke = {}
	_say("Now walk every line exactly once.", Face.Expr.HAPPY)
	fx.cue("start")
	_refresh()

## Walks the line to post `n`, if there is one left to walk. A line already
## walked refuses with a dip: every line takes exactly one crossing.
func _walk_to(n: int) -> void:
	var t := _now()
	var from: int = state.current
	match state.step(n):
		State.STEP_WALKED:
			_dip[n] = t
			_say("That line is walked already. Every line takes exactly one crossing.",
				Face.Expr.PUZZLED)
			fx.cue("locked")
			_refresh()
		State.STEP_OK:
			_stroke = {"edge": state.trail[-1], "from": from, "to": n,
				"at": t, "up": true}
			_speak()
			fx.cue("lay")
			_refresh()
			note_move()

# --- the sprout's line ---

## What the tip card says: the rule while nothing is walked, then how many
## lines are left, and the stranding warning the moment it applies -- after
## the step that caused it and never before. Live reachability was on the
## table and was turned down: avoiding stranding *is* the difficulty, and a
## board that greys out the wrong moves has played the puzzle for you.
func _speak(undone := false) -> void:
	if is_done():
		return
	var lost := state.stranded()
	if not lost.is_empty():
		if undone:
			_say("One line is still stranded behind you." if lost.size() == 1
				else "%d lines are still stranded behind you." % lost.size(),
				Face.Expr.STRAIN)
		else:
			_say("One line is stranded behind you now. Undo back to the fork."
				if lost.size() == 1
				else "%d lines are stranded behind you now. Undo back to the fork."
					% lost.size(), Face.Expr.STRAIN)
		return
	var left := state.lines_left()
	_say("One line still to walk." if left == 1 else "%d lines still to walk." % left,
		Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal; nothing else on this screen has a focus.
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _tip_mood != Face.Expr.HAPPY:
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(TIPS[_tip_idx], Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not state.trail.is_empty()

## Takes back the last line walked: the plank sinks to stone and the walker
## steps back onto the post it came from. Counts no move, as on the island.
func undo() -> bool:
	if is_done() or state.trail.is_empty():
		return false
	var out: Dictionary = state.undo()
	if out.is_empty():
		return false
	_stroke = {"edge": int(out.edge), "from": int(out.from), "to": int(out.to),
		"at": _now(), "up": false}
	_speak(true)
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Shows the next safe step. Before the stroke begins that is a post it may
## begin at; after, it walks one line whose far end still leaves every other
## line walkable in one stroke, so a hint can never be the move that strands
## the figure. When no such line exists it says so rather than inventing one,
## which is the island's behaviour exactly and the one place a hint is allowed
## to refuse.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or state.nodes.is_empty():
		return false
	var t := _now()
	if state.current < 0:
		var n := state.start_post()
		if n < 0 or not state.begin(n):
			return false
		hints_used += 1
		_begin_at = t
		_ring[n] = t
		fx.sparkle(node_to_local(n), Pal.GOOD)
		fx.cue("hint")
		_say("Begin there.", Face.Expr.HAPPY)
		_refresh()
		moved.emit()
		return true
	var to := state.safe_step()
	if to < 0:
		_say("There is no safe step left from here. Undo back to the fork.",
			Face.Expr.STRAIN)
		fx.cue("locked")
		_refresh()
		return false
	hints_used += 1
	_ring[to] = t
	fx.sparkle(node_to_local(to), Pal.GOOD)
	fx.cue("hint")
	# _walk_to counts the move and can finish the puzzle, as the island's does.
	_walk_to(to)
	return true

## Shakes every line that can no longer be reached from where the walker
## stands, and says how many. That is the only way to lose One Line, and it is
## the one thing this board will not draw in advance.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var t := _now()
	var lost := state.stranded()
	for e in lost:
		_flash[e] = t
	if state.current < 0:
		_say("Nothing is walked yet, so nothing is stranded. Begin on a green post.",
			Face.Expr.HAPPY)
	elif lost.is_empty():
		_say("Every line left can still be reached from where you stand.", Face.Expr.JOY)
	else:
		_say("One line is stranded: nothing can reach it now." if lost.size() == 1
			else "%d lines are stranded: nothing can reach them now." % lost.size(),
			Face.Expr.STRAIN)
	fx.cue("check" if not lost.is_empty() else "check_ok")
	_refresh()
	return lost.size()

func reset_board() -> void:
	state.reset()
	_stroke = {}
	_dip = {}
	_flash = {}
	_ring = {}
	_bright = {}
	_begin_at = -100.0
	_drawing = false
	moves = 0
	_running = true
	_say("The jetty is taken up again. The hints you spent are not refunded.",
		Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

# --- the win ---

## The board is the answer here, as it is on Untangle and Balance, so the win
## screen shows no cast: the finished figure stays on the card under it with
## the walker standing where it finished.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": "One stroke, not a line missed."}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## Every plank warms a shade brighter along the trail in walk order, so the
## stroke runs back along itself and draws the figure once more; the walker
## hops on the post it finished on.
func _on_solved() -> void:
	var t := _now()
	_drawing = false
	_tip_timer.stop()
	_solved_at = t
	_bright = {}
	for k in state.trail.size():
		_bright[state.trail[k]] = t + BRIGHT_DELAY + float(k) * BRIGHT_STEP
	_say("One stroke, and not a line missed.", Face.Expr.JOY)
	fx.cue("solved")
	_refresh()

# --- odds and ends ---

## Seconds since the scene started, the clock every animation here reads.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## 0 to 1, and 1 at once under reduce-motion.
func _dec(u: float) -> float:
	return 1.0 if Motion.reduce else clampf(u, 0.0, 1.0)

## The overshoot the whole family's pops use, as a curve rather than a tween,
## because these are drawn rather than tweened.
func _back_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	const C := 1.70158
	return 1.0 + (C + 1.0) * pow(u - 1.0, 3.0) + C * pow(u - 1.0, 2.0)
