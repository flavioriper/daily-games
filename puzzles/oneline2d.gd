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
## it, and every post as a drum with its coloured cap over its own soft
## shadow. The stone runs first and the planks all go over it, so the trail is
## never cut by a line nobody has walked. Only the walker is a Control, with
## the face family's cached meshes behind it (ui/faces/snail_face.gd), and it
## stands in a slot the board positions every frame (the ride, the facing and
## the rock) so the recipes can tween the snail inside it.
##
## Motion is the flat boards' shared vocabulary (core/motion.gd,
## docs/art/flat-motion.md): the posts and lines are drawn, so they read the
## recipes as curves off Motion, and the walker takes them as tweens. What is
## this board's own is the walk itself -- the plank growing under the snail
## over LAY_TIME -- and the trail warming back along itself on the win.
## Spec: docs/superpowers/specs/2026-09-18-oneline-flat-design.md, sections 2
## to 7 and the amendment in section 11, and the mock it is ported from
## (docs/brainstorm/concepts.html#oneline).

const State = preload("res://puzzles/oneline_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
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
## The post's shadow on the parchment: the family's soft disc, whose rim
## fades, so it needs about twice the peak of the flat 0.13 ellipse it
## replaced to read the same.
const SHADOW_A := 0.24
const SHADOW_SPREAD := 1.15
## The hint's ring, in post radii: it starts just outside the drum.
const RING_R := 1.6
## How far a post sunk under the finger goes toward its deep colour at the
## bottom of its press: the family's 0.94 alone is five pixels on a drum this
## size, and Light Up found the same on its stones.
const SINK_SHADE := 0.5

# --- this board's own motion ---
## The island's own LAY_TIME: a plank grows under the walker over this, which
## is also exactly how long the walker takes to cross the line.
const LAY_TIME := 0.28
const ROCK := 0.07
const ROCK_RATE := 9.0
const ROCK_STILL := 0.25
## On the win every plank warms a shade brighter along the trail, in walk
## order at the family's solve stagger, and the posts hop as the warmth
## reaches them: the stroke runs back along itself. This is how long each
## plank takes to warm.
const BRIGHT_TIME := 0.35
## The beat the host waits after the last post has landed before the win
## screen.
const WIN_SETTLE := 0.3

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
## The walker's slot: the board writes its position, its facing and its rock
## every frame; the snail inside takes the recipes (rule 2 of the motion doc).
var _seat: Control
var _step := 0.0
var _origin := Vector2.ZERO
var _card := Rect2()

## The line in flight, and the walker's own travel with it:
## {"edge", "from", "to", "at", "up", "to_cap"}. `from` and `to` are posts --
## the walker goes from one to the other in either direction -- and `up` is
## false for an undo, where the plank sinks back to stone instead of growing.
## The plank always grows from the end it was originally walked from
## (`up` ? from : to), which is what keeps the trail behind the snail and
## never against it. `to_cap` is the colour the far post wore before the
## move: it keeps it until the walker lands, and takes its new one with the
## Count bump then.
var _stroke: Dictionary = {}
## Every drawn thing's moments, keyed by post or line, each the second it
## began, read off Motion's curve readers in _build_figure.
var _post_press: Dictionary = {}  # post -> {"down", "up"}
var _post_hop: Dictionary = {}    # post -> {"at", "height", "time"}
var _cap_bump: Dictionary = {}    # post -> at: the cap was recounted
var _post_shiver: Dictionary = {} # post -> at: a refused press
var _post_blush: Dictionary = {}  # post -> at: the drum blushes
var _wrong: Dictionary = {}       # line -> at: Check found it stranded
var _bright: Dictionary = {}      # line -> at: it warms on the win
## Planks taken up by Reset, shrinking to nothing where they lay:
## [{"from": Vector2, "to": Vector2, "at": float}].
var _gone: Array = []
## Where the walker last stood, and when Reset popped it out, so the slot
## stays put through the pop rather than vanishing with state.current.
var _walker_rest := Vector2.ZERO
var _walker_out := -100.0
var _walker_dir := 1.0
var _joy := false
var _opened := 0.0
var _anim_until := 0.0
var _solved_at := -1.0
var _gen := 0
var _look_tw: Tween
var _pos_tw: Tween

var _figure: ArrayMesh
## The mesh the last _draw actually handed to the canvas item. A canvas
## command holds the mesh by RID and not by reference, so dropping the only
## reference to a mesh still on the item's command list leaves the renderer
## drawing a freed RID ("Parameter mesh is null", and an empty card) on any
## frame rendered without its queued redraw flushed first -- which is what
## RenderingServer.force_draw() in a harness does.
var _shown: ArrayMesh

var _drawing := false
var _pressed_post := -1
var _walker_pressed := false
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
	_seat = Control.new()
	_seat.name = "WalkerSeat"
	_seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seat.z_index = 1
	add_child(_seat)
	snail = SnailFace.new()
	snail.name = "Walker"
	snail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seat.add_child(snail)
	snail.set_idle(true)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_stop_all()
	state.setup(rng, difficulty)
	_stroke = {}
	_post_press = {}
	_post_hop = {}
	_cap_bump = {}
	_post_shiver = {}
	_post_blush = {}
	_wrong = {}
	_bright = {}
	_gone = []
	_walker_out = -100.0
	_joy = false
	_drawing = false
	_pressed_post = -1
	_solved_at = -1.0
	_layout()
	_enter()
	_tip_idx = 0
	_say(TIPS[0], Face.Expr.HAPPY)
	_tip_timer.start()

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
	var seat := _step * SNAIL_R * SnailFace.SEAT
	_seat.size = Vector2.ONE * seat
	_seat.pivot_offset = _seat.size * 0.5
	snail.size = _seat.size
	snail.pivot_offset = snail.size * 0.5
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

## A post's place on the diagonal from the top-left corner, which paces the
## entrance and the solve wave; the far corner paces Reset.
func _diagonal(n: int) -> int:
	return n % state.cols + n / state.cols

func _far() -> int:
	var far := 0
	for n in state.nodes:
		far = maxi(far, _diagonal(n))
	return far

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _step <= 0.0 or state.nodes.is_empty():
		return
	if _now() < _anim_until:
		_refresh()

## Keeps the figure redrawing for `seconds` more: something on it is moving.
## Nothing is rebuilt on a frame outside that, which is most of them: a
## figure sitting still costs the walker's blinks and nothing else.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

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
## The slot carries all of that; the snail inside it carries the recipes.
func _place_walker(t: float) -> void:
	var leaving := t < _walker_out + Motion.POP_OUT and not Motion.reduce
	if state.current < 0 and not leaving:
		_seat.visible = false
		return
	_seat.visible = true
	var at := _walker_rest
	var dir := _walker_dir
	var moving := false
	if state.current >= 0:
		var ride := _ride(t)
		at = ride.at - Vector2(0.0, _step * SNAIL_LIFT)
		dir = ride.dir
		moving = ride.moving
		_walker_rest = at
		_walker_dir = dir
	_seat.position = at - _seat.size * 0.5
	_seat.scale = Vector2(dir, 1.0)
	_seat.rotation = 0.0 if Motion.reduce else sin(t * ROCK_RATE) * ROCK \
		* (1.0 if moving else ROCK_STILL)
	if _joy:
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

## The walker arrives on a post: with the squash when a tap stood it there,
## or from above when a hint did (the Hint moment).
func _walker_arrives(drop: bool) -> void:
	Motion.stop(_look_tw)
	Motion.stop(_pos_tw)
	snail.rotation = 0.0
	snail.position = Vector2.ZERO
	snail.modulate.a = 1.0
	snail.visible = true
	if drop:
		snail.scale = Vector2.ONE
		_pos_tw = Motion.drop_in(snail)
		_busy_for(Motion.DROP_TIME)
	else:
		_look_tw = Motion.pop_in(snail)
		_busy_for(Motion.POP_IN)

## The walker sinks under the finger with its post, and springs back.
func _walker_press(down: bool) -> void:
	Motion.stop(_look_tw)
	_look_tw = Motion.press(snail, down)
	_busy_for(Motion.PRESS_TIME if down else Motion.RELEASE_TIME)

## The walker hops `height` over `time` after `delay`, from its rest.
func _walker_hop(height: float, time: float, delay := 0.0) -> void:
	Motion.stop(_pos_tw)
	snail.position = Vector2.ZERO
	_pos_tw = Motion.hop(snail, height, time, delay, 0.0)
	_busy_for(delay + time)

# --- the drawing ---

func _draw() -> void:
	_shown = _figure
	if _shown != null:
		draw_mesh(_shown, null)

## The whole figure in one mesh: every post's shadow, every line as stone,
## every plank walked over it, then the posts. The stone runs in one pass
## before any plank, so a walked line is never cut where an unwalked one
## crosses it -- the island cannot do that at all, since its planks are
## solids at the same height.
func _build_figure(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var lost: Dictionary = {}
	for e in state.stranded():
		lost[e] = true
	for n in state.nodes:
		_build_shadow(b, n, t)
	for i in state.edges.size():
		var line := _line_geometry(i, t)
		if line.is_empty():
			continue
		var stone: Color = Pal.PLANK_LOST if lost.has(i) else Pal.PLANK_BARE
		var blush := Motion.flash_level(t - float(_wrong.get(i, -100.0)))
		if blush > 0.0:
			stone = stone.lerp(Pal.BAD_TILE, blush)
		b.stroke(PackedVector2Array([line.a, line.b]), _step * LINE_W, Color(stone, line.alpha))
	for i in state.edges.size():
		if _line_geometry(i, t).is_empty():
			continue
		_build_plank(b, i, t)
	_build_gone(b, t)
	for n in state.nodes:
		_build_post(b, n, t)
	if b.verts.is_empty():
		return null
	return b.mesh()

## Line `i`'s two ends as drawn now, and its alpha: it pops in wide about its
## middle along the entrance stagger (rule 7 of the motion doc: a long thing
## comes from most of the way), and wobbles about that middle when Check has
## found it stranded. {} while it has not arrived.
func _line_geometry(i: int, t: float) -> Dictionary:
	var elapsed := t - _opened - _enter_line_delay(i)
	if elapsed <= 0.0 and not Motion.reduce:
		return {}
	var edge: Vector2i = state.edges[i]
	var a := node_to_local(edge.x)
	var c := node_to_local(edge.y)
	var mid := a.lerp(c, 0.5)
	var grow := Motion.wide_pop_scale(elapsed)
	var angle := Motion.wobble_angle(t - float(_wrong.get(i, -100.0)))
	var half := (c - mid).rotated(angle) * grow
	return {"a": mid - half, "b": mid + half, "alpha": Motion.appear_level(elapsed)}

## The plank laid over line `i`, as far along as the walker has taken it. It
## grows from the post the walker crossed *from*, and on the win it warms a
## shade brighter in walk order, so the finished figure draws itself once more.
func _build_plank(b, i: int, t: float) -> void:
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
	var warm: Color = Pal.PLANK_LAID
	if _bright.has(i):
		warm = warm.lerp(Pal.PLANK_HI, _dec((t - float(_bright[i])) / BRIGHT_TIME))
	_plank(b, from, from.lerp(to, u), warm, 1.0)

func _plank(b, from: Vector2, to: Vector2, warm: Color, grow: float) -> void:
	var line := PackedVector2Array([from, to])
	b.stroke(line, _step * PLANK_DEEP_W * grow, Pal.WOOD_DEEP)
	b.stroke(line, _step * PLANK_W * grow, warm)

## The planks Reset took up: each shrinks to nothing about its own middle in
## the wave from the far corner (the Remove moment, without the quarter turn a
## long thing would only wobble through).
func _build_gone(b, t: float) -> void:
	var keep: Array = []
	for g in _gone:
		var elapsed: float = t - float(g.at)
		var grow := Motion.pop_out_scale(elapsed)
		if grow <= 0.0:
			continue
		keep.append(g)
		var mid: Vector2 = (g.from as Vector2).lerp(g.to, 0.5)
		var half: Vector2 = ((g.to as Vector2) - mid) * grow
		_plank(b, mid - half, mid + half, Pal.PLANK_LAID, grow)
	_gone = keep

## The post's soft shadow on the parchment, at the post's rest: a hopping post
## leaves it behind, which is what makes the hop read as height. It arrives
## with the post's own pop.
func _build_shadow(b, n: int, t: float) -> void:
	var grow := _post_entrance(n, t)
	if grow.y <= 0.0:
		return
	var R := _step * POST_R
	var at := node_to_local(n) + Vector2(0.05, 0.3) * R
	Scenery.soft_disc(b, at, 0.92 * R * SHADOW_SPREAD * grow.x, 0.8 * R * SHADOW_SPREAD * grow.y,
		Color(Pal.TEXT, SHADOW_A))

## A mooring post, seen from above the way the whole board is: a stone drum
## with a coloured cap. The cap carries all the guidance, which is the
## island's own use for it -- a player who cannot see where the stroke may
## start cannot start it. Drawn off the readers: it pops in with the squash
## along the diagonal, sinks under the finger, hops when the walker lands and
## on the waves, shivers and blushes when it refuses, and its cap bumps when
## the count it shows has changed.
func _build_post(b, n: int, t: float) -> void:
	var grow := _post_entrance(n, t)
	if grow.y <= 0.0:
		return
	var at := node_to_local(n)
	var R := _step * POST_R
	var drum: Color = Pal.POST_STONE
	var deep: Color = Pal.POST_DEEP
	if _post_press.has(n):
		var pr: Dictionary = _post_press[n]
		var released := -1.0 if is_inf(float(pr.up)) else t - float(pr.up)
		var sink := Motion.press_scale(t - float(pr.down), released)
		grow *= sink
		drum = drum.lerp(deep, SINK_SHADE * clampf((1.0 - sink) / (1.0 - Motion.PRESS_SCALE), 0.0, 1.0))
	if _post_hop.has(n):
		var hop: Dictionary = _post_hop[n]
		at.y += Motion.hop_lift(t - float(hop.at), hop.height, hop.time)
	at.x += Motion.shiver_offset(t - float(_post_shiver.get(n, -100.0)), Motion.SHIVER_PX)
	var blush := Motion.flash_level(t - float(_post_blush.get(n, -100.0)))
	if blush > 0.0:
		drum = drum.lerp(Pal.BAD_TILE, blush)
		deep = deep.lerp(Pal.BAD, blush * 0.5)
	var rx := R * grow.x
	var ry := R * grow.y
	b.ellipse(at + Vector2(0.0, 0.1) * ry, rx, ry, deep)
	b.ellipse(at, rx, ry, drum)
	var cap := Motion.bump_scale(t - float(_cap_bump.get(n, -100.0)))
	b.ellipse(at + Vector2(0.0, -0.04) * ry, 0.62 * rx * cap, 0.62 * ry * cap, _cap_colour(n, t))
	b.ellipse(at + Vector2(-0.2, -0.26) * ry, 0.26 * rx, 0.16 * ry, Color(1.0, 1.0, 1.0, 0.22))

## The post's entrance scale: pop_in's squash along the diagonal, a beat after
## the lines begin. Zero before it starts.
func _post_entrance(n: int, t: float) -> Vector2:
	return Motion.pop_in_scale(t - _opened - _enter_post_delay(n))

## The island's four caps, unchanged: terracotta under the walker, green on a
## post the stroke may begin at, teal where lines are still to walk, and pale
## stone once a post is finished with. The measurement says the green matters
## most -- 198 of 200 easy figures and all 400 of the harder ones have exactly
## two odd posts, so the opening is forced almost every time. The post the
## walker is crossing to keeps its old cap until the walker lands.
func _cap_colour(n: int, t: float) -> Color:
	if not _stroke.is_empty() and int(_stroke.to) == n and _stroke.has("to_cap") \
			and t < float(_stroke.at) + LAY_TIME and not Motion.reduce:
		return _stroke.to_cap
	return _cap_of(n)

func _cap_of(n: int) -> Color:
	if n == state.current:
		return Pal.ACCENT_2
	if state.current < 0 and state.may_start(n):
		return Pal.GOOD
	if state.open_at(n) > 0:
		return Pal.ACCENT
	return Pal.POST_SPENT

# --- the moments ---

## The chrome is the host's; here each stone line pops in wide about its
## middle in index order, and each post pops onto the figure a beat later with
## the squash along the diagonal from the top-left corner, its shadow arriving
## with it. The figure draws itself before the first touch: it is the thing to
## read, and the planks are the answer to it.
func _enter() -> void:
	_opened = _now()
	var lines := _enter_line_delay(state.edges.size() - 1) + Motion.ENTER_POP
	var posts := _enter_post_delay(_far()) + Motion.POP_IN
	_busy_for(maxf(lines, posts))
	fx.cue("enter")

func _enter_line_delay(i: int) -> float:
	return Motion.ENTER_DELAY + Motion.stagger(i, Motion.ENTER_STAGGER)

func _enter_post_delay(n: int) -> float:
	return Motion.ENTER_DELAY + Motion.ENTER_FACE_LAG + Motion.stagger(_diagonal(n), Motion.ENTER_STAGGER)

## The post under the finger sinks (the Press moment), and the walker with it
## when it is standing there.
func _press_post(n: int) -> void:
	_release_post()
	_pressed_post = n
	_post_press[n] = {"down": _now(), "up": INF}
	_busy_for(Motion.PRESS_TIME)
	if n == state.current:
		_walker_pressed = true
		_walker_press(true)

## Whatever the finger sank springs back.
func _release_post() -> void:
	if _pressed_post < 0:
		return
	var n := _pressed_post
	_pressed_post = -1
	if _post_press.has(n) and is_inf(float(_post_press[n].up)):
		_post_press[n].up = _now()
		_busy_for(Motion.RELEASE_TIME)
	_release_walker()

## The walker springs back if the finger had it down.
func _release_walker() -> void:
	if not _walker_pressed:
		return
	_walker_pressed = false
	_walker_press(false)

## The walker lands on post `n` at `at`: the post hops, its cap takes its new
## colour with the Count bump, and a puff in the plank's wood when a line was
## laid (the Place moment; an undo lands without one).
func _land(n: int, at: float, puff: bool) -> void:
	_post_hop[n] = {"at": at, "height": Motion.HOP, "time": Motion.HOP_TIME}
	_cap_bump[n] = at
	_busy_for(at - _now() + maxf(Motion.HOP_TIME, Motion.BUMP_TIME))
	if puff and not Motion.reduce:
		_after(at - _now(), fx.puff.bind(node_to_local(n), Pal.PLANK_LAID))

## The walker leaves post `n` now: its cap is recounted at once.
func _depart(n: int) -> void:
	_cap_bump[n] = _now()
	_busy_for(Motion.BUMP_TIME)

## A press the rules will not take on post `n`: it shivers while its drum
## blushes toward the family's rose and settles (the Refused moment).
func _refuse(n: int) -> void:
	if Motion.reduce:
		return
	var now := _now()
	_post_shiver[n] = now
	_post_blush[n] = now
	_busy_for(maxf(Motion.SHIVER_TIME, Motion.FLASH_IN + Motion.FLASH_OUT))

## The wave from the far corner Reset runs, per post or per line.
func _reset_wave(diagonal: float) -> float:
	if Motion.reduce:
		return 0.0
	return Motion.stagger(int(roundf(float(_far()) - diagonal)), Motion.RESET_STAGGER)

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
			_release_post()
			_refresh()
	elif event is InputEventScreenDrag and _drawing:
		_reach(event.position)

func _press(at: Vector2) -> void:
	if is_done():
		return
	var n := _nearest(at)
	if n < 0:
		return
	_drawing = true
	_press_post(n)
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

## Stands the walker on a post to open the stroke: it pops in with the squash
## and a puff in its own terracotta, and the post hops under it. A post the
## figure forbids answers with a shiver, a blush and a line from the sprout
## rather than a move.
func _begin(n: int) -> void:
	var t := _now()
	if not state.begin(n):
		_refuse(n)
		_say("The stroke has to begin on one of the two green posts."
			if not state.starts.is_empty()
			else "Begin anywhere: this figure has no odd post.", Face.Expr.PUZZLED)
		fx.cue("locked")
		_refresh()
		return
	_stroke = {}
	_walker_arrives(false)
	_post_hop[n] = {"at": t, "height": Motion.HOP, "time": Motion.HOP_TIME}
	for m in state.nodes:
		_cap_bump[m] = t
	_busy_for(maxf(Motion.HOP_TIME, Motion.BUMP_TIME))
	fx.puff(node_to_local(n), Pal.ACCENT_2)
	_say("Now walk every line exactly once.", Face.Expr.HAPPY)
	fx.cue("start")
	_refresh()

## Walks the line to post `n`, if there is one left to walk. A line already
## walked refuses with a shiver: every line takes exactly one crossing.
func _walk_to(n: int) -> void:
	var t := _now()
	var from: int = state.current
	var to_cap := _cap_of(n)
	match state.step(n):
		State.STEP_WALKED:
			_refuse(n)
			_say("That line is walked already. Every line takes exactly one crossing.",
				Face.Expr.PUZZLED)
			fx.cue("locked")
			_refresh()
		State.STEP_OK:
			_stroke = {"edge": state.trail[-1], "from": from, "to": n,
				"at": t, "up": true, "to_cap": to_cap}
			_release_walker()
			_busy_for(LAY_TIME)
			_depart(from)
			_land(n, t + (0.0 if Motion.reduce else LAY_TIME), true)
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
## steps back onto the post it came from, which hops as it lands. Counts no
## move, as on the island.
func undo() -> bool:
	if is_done() or state.trail.is_empty():
		return false
	var caps := _snapshot_caps()
	var out: Dictionary = state.undo()
	if out.is_empty():
		return false
	var t := _now()
	_stroke = {"edge": int(out.edge), "from": int(out.from), "to": int(out.to),
		"at": t, "up": false, "to_cap": caps.get(int(out.to), _cap_of(int(out.to)))}
	_busy_for(LAY_TIME)
	_depart(int(out.from))
	_land(int(out.to), t + (0.0 if Motion.reduce else LAY_TIME), false)
	_speak(true)
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

## Every post's cap as it is now, before a move changes the state under it.
func _snapshot_caps() -> Dictionary:
	var caps: Dictionary = {}
	for n in state.nodes:
		caps[n] = _cap_of(n)
	return caps

func hints_left() -> int:
	return HINTS - hints_used

## Shows the next safe step. Before the stroke begins that is a post it may
## begin at, and the walker drops onto it from above under a ring; after, it
## walks one line whose far end still leaves every other line walkable in one
## stroke, so a hint can never be the move that strands the figure, and the
## ring and the sparkle come as it lands. When no such line exists it says so
## rather than inventing one, which is the island's behaviour exactly and the
## one place a hint is allowed to refuse.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or state.nodes.is_empty():
		return false
	var t := _now()
	if state.current < 0:
		var n := state.start_post()
		if n < 0 or not state.begin(n):
			return false
		hints_used += 1
		_stroke = {}
		_walker_arrives(true)
		for m in state.nodes:
			_cap_bump[m] = t
		_busy_for(Motion.BUMP_TIME)
		_ring_at(n)
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
	_after(0.0 if Motion.reduce else LAY_TIME, _ring_at.bind(to))
	fx.cue("hint")
	# _walk_to counts the move and can finish the puzzle, as the island's does.
	_walk_to(to)
	return true

## The hint's ring and sparkle, in the family's green, out of post `n`.
func _ring_at(n: int) -> void:
	var at := node_to_local(n)
	fx.ring(at, _step * POST_R * RING_R, Pal.GOOD)
	fx.sparkle(at, Pal.GOOD)

## Every line that can no longer be reached from where the walker stands
## wobbles about its middle and blushes toward the family's rose, and the
## sprout says how many. That is the only way to lose One Line, and it is the
## one thing this board will not draw in advance.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var t := _now()
	var lost := state.stranded()
	if not Motion.reduce:
		for e in lost:
			_wrong[e] = t
		if not lost.is_empty():
			_busy_for(maxf(Motion.WOBBLE_TIME, Motion.FLASH_IN + Motion.FLASH_OUT))
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

## The jetty is taken up again: every plank shrinks to nothing in a wave from
## the far corner while the posts hop, and the walker pops out where it
## stood. The hints spent are not refunded.
func reset_board() -> void:
	var now := _now()
	_release_post()
	_drawing = false
	for e in state.walked:
		var anchor: int = int(state.lay_from.get(e, state.edges[e].x))
		var edge: Vector2i = state.edges[e]
		var other: int = edge.y if anchor == edge.x else edge.x
		var diagonal := 0.5 * float(_diagonal(anchor) + _diagonal(other))
		_gone.append({"from": node_to_local(anchor), "to": node_to_local(other),
			"at": now + _reset_wave(diagonal)})
	if state.current >= 0:
		_walker_out = now
		Motion.stop(_look_tw)
		Motion.stop(_pos_tw)
		snail.position = Vector2.ZERO
		_look_tw = Motion.pop_out(snail)
		_busy_for(Motion.POP_OUT)
	state.reset()
	_stroke = {}
	_post_press = {}
	_post_shiver = {}
	_post_blush = {}
	_wrong = {}
	_bright = {}
	_joy = false
	if not Motion.reduce:
		for n in state.nodes:
			var at: float = now + _reset_wave(float(_diagonal(n)))
			_post_hop[n] = {"at": at, "height": Motion.RESET_HOP, "time": Motion.HOP_TIME}
			_cap_bump[n] = at
		_busy_for(_reset_wave(0.0) + maxf(Motion.HOP_TIME, maxf(Motion.BUMP_TIME, Motion.POP_OUT)))
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

## The trail has to finish warming, the last post has to land and the walker
## has to come down.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return _solve_delay(state.trail.size()) + Motion.SOLVE_TIME + WIN_SETTLE

## The k-th step of the solve wave, which runs the whole trail rather than
## capping at the family's 0.6: the stroke running back along itself is this
## board's signature, and a capped retrace would arrive all at once at the
## end.
func _solve_delay(k: int) -> float:
	return Motion.SOLVE_DELAY + float(k) * Motion.SOLVE_STAGGER

## Every plank warms a shade brighter along the trail in walk order, so the
## stroke runs back along itself and draws the figure once more; each post
## hops as the warmth reaches it, and the walker last of all, grinning, with a
## sparkle where the stroke ended.
func _on_solved() -> void:
	var t := _now()
	_drawing = false
	_release_post()
	_tip_timer.stop()
	_solved_at = t
	_bright = {}
	var last := _solve_delay(state.trail.size())
	for k in state.trail.size():
		_bright[state.trail[k]] = t + _solve_delay(k)
	if not Motion.reduce:
		for k in state.walk.size():
			_post_hop[state.walk[k]] = {"at": t + _solve_delay(k),
				"height": Motion.SOLVE_HOP, "time": Motion.SOLVE_TIME}
		_walker_hop(Motion.SOLVE_HOP, Motion.SOLVE_TIME, last)
		_after(last, func() -> void:
			_joy = true
			fx.sparkle(node_to_local(state.current), Pal.SUN)
			_refresh())
	else:
		_joy = true
	_busy_for(last + maxf(Motion.SOLVE_TIME, BRIGHT_TIME))
	_say("One stroke, and not a line missed.", Face.Expr.JOY)
	fx.cue("solved")
	_refresh()

# --- odds and ends ---

## Kills every tween the previous board still tracks and retires its pending
## callbacks, so a rebuild never inherits a hop aimed at the last figure.
func _stop_all() -> void:
	_gen += 1
	Motion.stop(_look_tw)
	Motion.stop(_pos_tw)
	if snail != null:
		snail.scale = Vector2.ONE
		snail.position = Vector2.ZERO
		snail.rotation = 0.0
		snail.modulate.a = 1.0
		snail.visible = true

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	if delay <= 0.0:
		what.call()
		return
	var gen := _gen
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

## Seconds since the scene started, the clock every animation here reads.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## 0 to 1, and 1 at once under reduce-motion.
func _dec(u: float) -> float:
	return 1.0 if Motion.reduce else clampf(u, 0.0, 1.0)
