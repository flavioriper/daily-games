extends "res://core/puzzle_base_3d.gd"

## One Line on the island stage. The figure is a jetty: Untangle's own mooring
## posts stand on the platform, and between every connected pair lies a plank.
## A plank you have not walked is a dark stone ford, flush with the deck;
## walking it lays a warm plank over it, which rises into place. So the drawing
## is something you build rather than something you colour in, and how much is
## left is a thing you can see across the whole board at once.
##
## The posts carry the rest of the guidance in their caps, which is what
## Untangle uses them for too: green on a post you are allowed to begin at,
## terracotta on the one your finger is on, teal on a post with planks still
## to walk, and pale stone on one you have finished with. A player who cannot
## see where the stroke may start cannot start it.
##
## The lattice is laid out two cells apart rather than one. At one cell the
## posts very nearly touch and a plank between two of them is a sliver; at two
## the plank is most of the span, which is the thing the puzzle is about.
##
## The rule is unchanged: every plank exactly once, and a figure with two
## odd-degree posts must be begun at one of them. Both Hint and Check are
## built on the same question -- whether the planks still unwalked can all be
## reached from where you stand -- because the one way to lose One Line is to
## strand part of the figure behind you, and the flat board never said so.
## Design: agreed in chat on 2026-09-15 (no spec file by request).

const Gen = preload("res://puzzles/oneline_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Platform = preload("res://core/platform.gd")
const Motion = preload("res://core/motion.gd")
const Fx = preload("res://world/fx.gd")
const Scenery = preload("res://world/scenery.gd")

## Cells between neighbouring lattice posts.
const SPACING := 2
## How close a tap or a drag has to pass a post to take it, in world units.
## Posts are two cells apart, so there is no ambiguity to resolve; this is
## simply a thumb-sized reach.
const GRAB_R := 0.85
## A plank not yet walked is squashed flat into a ford; walking it brings it up
## to its full thickness.
const FORD_SCALE := 0.32
const LAY_TIME := 0.28
## Planks cross -- that is what makes these figures figures -- and two of them
## at the same height share a coplanar patch of top face wherever they do,
## which z-fights. Each plank is lifted this much per edge index instead, so
## every crossing has a settled winner. Twenty edges come to 0.016, well under
## the bevel and invisible on the stage.
const PLANK_STACK := 0.0008
const HINTS := 3
const SPARKLE_LIFT := 0.2
const BLUSH_STEPS := 16
const CHECK_IN := 0.15
const CHECK_OUT := 0.5
const ENTER_DROP := 0.5
const ENTER_PLATFORM := 0.5
const ENTER_POP := 0.26
const ENTER_STAGGER := 0.04
const SOLVE_HOP := 0.12
const SOLVE_TIME := 0.4
const SOLVE_STAGGER := 0.05

var _cols: int = 3
var _rows: int = 3
var _edges: Array = []
var _nodes: Array = []
var _starts: Array = []
## Edge index -> true once walked. Not `_done`: PuzzleBase already owns that
## name for the solved flag, and a shadowing member is a parse error.
var _walked: Dictionary = {}
var _current: int = -1
## The nodes walked in order, and the edge indices in order. Undo pops both.
var _walk: Array[int] = []
var _trail: Array[int] = []

var fx: Node3D
var _posts: Dictionary = {}          # node -> Node3D
var _planks: Array = []              # edge index -> Node3D pivot
var _plank_models: Array = []
var _plank_tw: Array = []
var _entrance: Array = []

func _ready() -> void:
	super()
	solved.connect(_on_solved)

func puzzle_id() -> String: return "oneline"
func title() -> String: return "One Line"

func rules() -> String:
	return "Start on a green post and walk along every plank exactly once, without going over one twice."

func board_size() -> Vector2i:
	return Vector2i(_cols * SPACING - 1, _rows * SPACING - 1)
func board_height() -> float:
	return Placeholders.POST_H + Placeholders.POST_CAP_H
func plane_height() -> float: return 0.0
func board_margin() -> float: return Platform.LIP
func board_depth() -> float: return Placeholders.PLATFORM_H

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var dims := [[3, 3, 0.55], [4, 3, 0.5], [4, 4, 0.45]]
	var d: Array = dims[clampi(difficulty, 0, 2)]
	_cols = d[0]
	_rows = d[1]
	var out: Dictionary = Gen.generate(rng, _cols, _rows, d[2])
	_edges = out.edges
	_nodes = out.nodes
	_starts = out.starts
	_walked = {}
	_current = -1
	_walk = []
	_trail = []
	_build_scene()
	_recolour()
	_refit()
	_enter()

## The jetty is taken up again: every plank drops back to a ford at once.
func reset_board() -> void:
	_stop_entrance()
	_walked = {}
	_current = -1
	_walk = []
	_trail = []
	moves = 0
	for e in _edges.size():
		_seat_plank(e, false)
	_recolour()
	fx.cue("reset")

func is_solved() -> bool:
	return not _edges.is_empty() and _walked.size() == _edges.size()

func share_glyphs() -> String:
	return "✏️ %d lines in one stroke" % _edges.size()

# --- the rule, as the board reads it ---

## Whether node `n` may begin the stroke. A figure with two odd-degree posts
## must start at one of them; one with none may start anywhere.
func _may_start(n: int) -> bool:
	return _starts.is_empty() or _starts.has(n)

## The edge index joining `a` and `b`, or -1 when they are not joined.
func _edge_between(a: int, b: int) -> int:
	var want := Vector2i(mini(a, b), maxi(a, b))
	for i in _edges.size():
		if _edges[i] == want:
			return i
	return -1

## Every edge index still unwalked.
func _remaining() -> Array[int]:
	var out: Array[int] = []
	for i in _edges.size():
		if not _walked.has(i):
			out.append(i)
	return out

## Whether every edge in `remaining` can still be walked in one stroke
## starting from `v`. This is the Eulerian-trail condition applied to what is
## left: the unwalked planks must all hang together in one piece that `v` is
## part of, and the odd-degree posts among them must be none, or exactly two
## with `v` one of them. It is the only thing that can go wrong in One Line
## and the only thing Hint and Check need to know.
func _walkable_from(remaining: Array[int], v: int) -> bool:
	if remaining.is_empty():
		return true
	var adj: Dictionary = {}
	var deg: Dictionary = {}
	for i in remaining:
		var e: Vector2i = _edges[i]
		for pair in [[e.x, e.y], [e.y, e.x]]:
			if not adj.has(pair[0]):
				adj[pair[0]] = []
			adj[pair[0]].append(pair[1])
			deg[pair[0]] = int(deg.get(pair[0], 0)) + 1
	if not adj.has(v):
		return false
	var seen: Dictionary = {v: true}
	var stack: Array = [v]
	while not stack.is_empty():
		var cur = stack.pop_back()
		for n in adj[cur]:
			if not seen.has(n):
				seen[n] = true
				stack.append(n)
	for i in remaining:
		var e: Vector2i = _edges[i]
		if not seen.has(e.x) or not seen.has(e.y):
			return false
	var odd: Array = []
	for n in deg:
		if int(deg[n]) % 2 == 1:
			odd.append(n)
	if odd.is_empty():
		return true
	return odd.size() == 2 and odd.has(v)

## Unwalked planks that can no longer be reached from where the player stands.
## Before the stroke begins nothing is stranded.
func _stranded() -> Array[int]:
	var out: Array[int] = []
	if _current < 0:
		return out
	var remaining := _remaining()
	var adj: Dictionary = {}
	for i in remaining:
		var e: Vector2i = _edges[i]
		for pair in [[e.x, e.y], [e.y, e.x]]:
			if not adj.has(pair[0]):
				adj[pair[0]] = []
			adj[pair[0]].append(pair[1])
	var seen: Dictionary = {_current: true}
	var stack: Array = [_current]
	while not stack.is_empty():
		var cur = stack.pop_back()
		for n in adj.get(cur, []):
			if not seen.has(n):
				seen[n] = true
				stack.append(n)
	for i in remaining:
		var e: Vector2i = _edges[i]
		if not seen.has(e.x):
			out.append(i)
	return out

## Unwalked edges still touching node `n`.
func _open_at(n: int) -> int:
	var count := 0
	for i in _edges.size():
		if _walked.has(i):
			continue
		var e: Vector2i = _edges[i]
		if e.x == n or e.y == n:
			count += 1
	return count

# --- scene ---

func _stop_all() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for tw in _plank_tw:
		Motion.stop(tw)

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_posts = {}
	_planks = []
	_plank_models = []
	_plank_tw = []

	var size := board_size()
	board.add_child(Platform.build(size.x, size.y))
	fx = Fx.new()
	board.add_child(fx)

	for n in _nodes:
		var post := Models.instance("post")
		post.name = "post_%d" % n
		post.position = _world_of(n)
		Scenery.seed_grain(post, float(n))
		board.add_child(post)
		_posts[n] = post

	for e in _edges.size():
		var edge: Vector2i = _edges[e]
		var a := _world_of(edge.x)
		var b := _world_of(edge.y)
		var pivot := Node3D.new()
		pivot.name = "plank_%d" % e
		pivot.position = (a + b) * 0.5 + Vector3(0.0, e * PLANK_STACK, 0.0)
		# Local +X turned by yaw about Y lands on (cos, 0, -sin), so the yaw
		# that points it down the edge is atan2(-dz, dx).
		pivot.rotation.y = atan2(-(b.z - a.z), b.x - a.x)
		board.add_child(pivot)
		var model := Models.instance("plank")
		Scenery.seed_grain(model, float(e) + 0.5)
		pivot.add_child(model)
		_planks.append(pivot)
		_plank_models.append(model)
		_plank_tw.append(null)
		_seat_plank(e, false)

## World point of lattice node `n`, on the deck. The lattice is laid SPACING
## cells apart, so the board is that much bigger than the graph is wide.
func _world_of(n: int) -> Vector3:
	var size := board_size()
	var x: int = n % _cols
	var y: int = n / _cols
	return BoardMath.cell_center(y * SPACING, x * SPACING, size.x, size.y)

## Puts plank `e` at its resting shape at once: a ford when `laid` is false,
## a full plank when true. `_span` is baked into scale.x, so both states keep
## the stretch that makes the plank reach its posts.
func _seat_plank(e: int, laid: bool) -> void:
	Motion.stop(_plank_tw[e])
	_plank_tw[e] = null
	var pivot: Node3D = _planks[e]
	# Its own height back too: killing a solve hop mid-flight would otherwise
	# leave the plank stranded above the deck.
	pivot.position.y = e * PLANK_STACK
	pivot.scale = Vector3(_span(e), 1.0 if laid else FORD_SCALE, 1.0)
	_paint_plank(e)

## The length of edge `e` in world units: a plank is modelled one cell long
## and stretched to this, the way Shikaku's wall runs are.
func _span(e: int) -> float:
	var edge: Vector2i = _edges[e]
	return _world_of(edge.x).distance_to(_world_of(edge.y))

func _paint_plank(e: int) -> void:
	Models.tint_named(_plank_models[e],
		"Plank", Pal.PLANK_LAID if _walked.has(e) else Pal.PLANK_BARE)

# --- colour ---

## The posts say where the stroke may begin, where it is, and which posts
## still have planks to walk.
func _recolour() -> void:
	for n in _posts:
		var col: Color = Pal.ACCENT
		if n == _current:
			col = Pal.ACCENT_2
		elif _current == -1 and _may_start(n):
			col = Pal.GOOD
		elif _open_at(n) == 0:
			col = Pal.POST_SPENT
		Models.tint_named(_posts[n], "Cap", col)

# --- input ---

func on_board_press(hit: Vector3) -> void:
	_reach(hit)

func on_board_drag(hit: Vector3) -> void:
	_reach(hit)

## The post nearest `hit`, if the reach lands on one, and what to do with it:
## take it as the start of the stroke, or walk the plank to it.
func _reach(hit: Vector3) -> void:
	var n := _nearest(hit)
	if n < 0:
		return
	if _current == -1:
		if not _may_start(n):
			fx.cue("locked")
			return
		_current = n
		_walk = [n]
		_recolour()
		fx.cue("start")
		return
	_step(n)

## Walks the plank from the current post to `n`, if there is one left to walk.
func _step(n: int) -> void:
	if n == _current:
		return
	var e := _edge_between(_current, n)
	if e < 0 or _walked.has(e):
		return
	_walked[e] = true
	_trail.append(e)
	_current = n
	_walk.append(n)
	_lay_plank(e)
	_recolour()
	note_move()

## The post nearest `hit` within GRAB_R, or -1.
func _nearest(hit: Vector3) -> int:
	var best := -1
	var best_d := GRAB_R
	for n in _posts:
		var d := _world_of(n).distance_to(hit)
		if d < best_d:
			best_d = d
			best = n
	return best

## Control-local point over node `n`. The win harness drags between these.
func node_to_local(n: int) -> Vector2:
	return board_to_local(_world_of(n))

# --- capabilities ---

func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

func can_undo() -> bool:
	return not is_done() and not _trail.is_empty()

## Takes back the last plank walked, and steps back onto the post it was
## walked from. Counts no move.
func undo() -> bool:
	if is_done() or _trail.is_empty():
		return false
	var e: int = _trail.pop_back()
	_walked.erase(e)
	_walk.pop_back()
	_current = _walk[-1]
	_seat_plank(e, false)
	_recolour()
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Shows the next safe step. Before the stroke begins that is a post it may
## begin at; after, it walks one plank whose far end still leaves every other
## plank reachable in one stroke -- so a hint can never be the move that
## strands the figure. Three per puzzle. Counts no move but can finish.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or _nodes.is_empty():
		return false
	if _current == -1:
		var start: int = _starts[0] if not _starts.is_empty() else int(_nodes[0])
		_current = start
		_walk = [start]
		hints_used += 1
		fx.sparkle(_world_of(start) + Vector3(0.0, Placeholders.POST_H + SPARKLE_LIFT, 0.0))
		fx.cue("hint")
		_recolour()
		moved.emit()
		return true
	var pick := -1
	for i in _remaining():
		var e: Vector2i = _edges[i]
		if e.x != _current and e.y != _current:
			continue
		var far: int = e.y if e.x == _current else e.x
		var rest := _remaining()
		rest.erase(i)
		if _walkable_from(rest, far):
			pick = i
			break
	if pick < 0:
		# Every step from here strands something: there is no honest hint to
		# give, and saying so by doing nothing is better than lying.
		fx.cue("locked")
		return false
	var edge: Vector2i = _edges[pick]
	var to: int = edge.y if edge.x == _current else edge.x
	hints_used += 1
	fx.sparkle(_world_of(to) + Vector3(0.0, Placeholders.POST_H + SPARKLE_LIFT, 0.0))
	fx.cue("hint")
	_step(to)
	return true

## Flashes every plank that can no longer be reached from where the player
## stands, and returns how many. That is the only way to lose One Line, and
## the flat board never mentioned it.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var lost := _stranded()
	for e in lost:
		_flash_plank(e)
	fx.cue("check" if not lost.is_empty() else "check_ok")
	return lost.size()

# --- motion on one plank ---

## A plank rises from its ford to full thickness: the stroke laying it down.
func _lay_plank(e: int) -> void:
	Motion.stop(_plank_tw[e])
	_paint_plank(e)
	var pivot: Node3D = _planks[e]
	pivot.scale = Vector3(_span(e), FORD_SCALE, 1.0)
	_plank_tw[e] = Motion.settle(pivot, "scale",
		Vector3(_span(e), 1.0, 1.0), LAY_TIME)
	if _plank_tw[e] == null:
		pivot.scale = Vector3(_span(e), 1.0, 1.0)
	fx.cue("lay")

## A stranded plank flashes rose and settles back to whatever it was: Check
## pointing at it.
func _flash_plank(e: int) -> void:
	var laid: bool = _walked.has(e)
	var base: Color = Pal.PLANK_LAID if laid else Pal.PLANK_BARE
	var setter := func(blend: float) -> void:
		if e >= _plank_models.size() or not is_instance_valid(_plank_models[e]):
			return
		var q := roundf(blend * BLUSH_STEPS) / BLUSH_STEPS
		Models.tint_named(_plank_models[e], "Plank", base.lerp(Pal.BAD, q))
	var tw: Tween = Motion.fade(_planks[e], setter, 0.0, 1.0, CHECK_IN, BLUSH_STEPS)
	if tw == null:
		setter.call(0.0)
		return
	tw.tween_method(setter, 1.0, 0.0, CHECK_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- entrance and solve ---

## The board arrives: the platform rises out of the water and the posts pop in
## along a diagonal wave. The planks are already there as fords -- they are
## the figure, and the figure should be readable before the first touch.
func _enter() -> void:
	_stop_entrance()
	var platform: Node3D = board.get_node("Platform")
	platform.position.y = -ENTER_DROP
	var rise: Tween = Motion.settle(platform, "position:y", 0.0, ENTER_PLATFORM)
	if rise != null:
		_entrance.append(rise)
		var splash := board.create_tween()
		splash.tween_interval(ENTER_PLATFORM * 0.9)
		splash.tween_callback(_splash)
		_entrance.append(splash)
	var i := 0
	for n in _posts:
		var post: Node3D = _posts[n]
		post.scale = Vector3.ONE * 0.01
		var pop: Tween = Motion.settle(post, "scale", Vector3.ONE, ENTER_POP,
			ENTER_PLATFORM + Motion.stagger(i, ENTER_STAGGER))
		if pop == null:
			post.scale = Vector3.ONE
		else:
			_entrance.append(pop)
		i += 1
	fx.cue("enter")

func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	var platform: Node3D = board.get_node_or_null("Platform")
	if platform != null:
		platform.position.y = 0.0
	for n in _posts:
		(_posts[n] as Node3D).scale = Vector3.ONE

## Rings the water under the board, when there is a stage to ask.
func _splash() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(board.global_position)

## The stroke runs back along itself: every plank hops in the order it was
## walked, so the finished figure is drawn once more by itself.
func _on_solved() -> void:
	for k in _trail.size():
		var e: int = _trail[k]
		Motion.stop(_plank_tw[e])
		_plank_tw[e] = Motion.hop(_planks[e], SOLVE_HOP, SOLVE_TIME,
			Motion.stagger(k, SOLVE_STAGGER), e * PLANK_STACK)
	fx.cue("solved")
