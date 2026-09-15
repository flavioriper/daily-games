extends "res://core/puzzle_base_3d.gd"

## Untangle on the island stage. Mooring posts stand on the platform with rope
## strung between them; drag a post until no two ropes cross. Every rope is a
## simulated line -- a chain of Verlet points pinned at both posts, pulled down
## by gravity -- so it sags between its posts and whips when you fling one.
##
## The rule is still the flat one it always was: two edges cross when their
## straight segments cross, tested on the posts' positions, never on the rope's
## own curve. That stays honest because a rope pinned at both ends and pulled
## straight down settles in the vertical plane through its two posts, and
## anything in that plane projects to exactly that straight segment from above.
## A rope only leaves the plane while it is being flung, and it comes back.
## Ropes caught in a crossing turn red, so the board points at the problem
## rather than counting it.
## Spec: the design agreed in chat on 2026-09-15 (no spec file by request).

const Gen = preload("res://puzzles/untangle_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Platform = preload("res://core/platform.gd")
const Motion = preload("res://core/motion.gd")
const Toon = preload("res://core/toon.gd")
const Fx = preload("res://world/fx.gd")

const HINTS := 3
## Half a cell of stone is left around the posts so a post on the very edge of
## the normalised square still has its cap inside the moss rim.
const EDGE_MARGIN := 0.7
## How close a tap must land to a post's foot to grab it, in world units. A
## post is 0.42 across, so this is the thumb-sized reach the 2D board had.
const GRAB_R := 0.62

# --- rope simulation ---
## Points per rope, ends included. Eight segments is enough for a sag to read
## as a curve and few enough that a board of 24 ropes rebuilds cheaply.
const ROPE_POINTS := 9
const ROPE_RADIAL := 5
const GRAVITY := -11.0
## Verlet drag. Low enough that a flung rope swings a few times, high enough
## that it is back in its posts' vertical plane within about a second.
const ROPE_DAMPING := 0.93
## A length correction has to travel from the pinned ends to the middle, one
## segment per pass, so a chain of eight segments needs more passes than it has
## segments or gravity out-stretches the rope and it sags far past its rest
## length. The passes alternate direction, which carries a correction in from
## both ends at once.
const ROPE_ITERATIONS := 14
## Every rope is given the same sag, whatever its span: SAG_RATIO of a short
## span, never more than SAG_MAX. A proportional slack would hang a long rope
## on the stone, where its curve stops matching the straight segment the rule
## tests -- and a slack that is the same *fraction* everywhere makes short
## ropes look taut and long ones look dropped. The rest length is recomputed
## from the live span as the posts move; the points themselves are still
## integrated, so the rope keeps its weight and its whip.
## These are aimed low on purpose. A Verlet chain settles about half a percent
## longer than its rest length, and sag grows as the square root of the excess,
## so a little stretch lands a lot more sag than the arithmetic asks for.
## These are therefore aiming points, not predictions: measured on a
## difficulty-2 board, the deepest rope hangs about 0.32 below its cleats,
## which leaves it 0.26 clear of the stone. Chasing the nominal figure exactly
## would need sub-0.1-percent length accuracy and many more constraint passes,
## and would buy nothing anyone can see.
const SAG_MAX := 0.15
const SAG_RATIO := 0.07
## No point of a rope may sink below this; a safety net under the slack rule.
const ROPE_FLOOR := 0.06
## Below this much movement in a frame a rope is asleep and is not rebuilt.
const ROPE_SLEEP := 0.0006
const SIM_STEP := 1.0 / 60.0

# --- motion ---
const LIFT := 0.12
const LIFT_TIME := 0.16
const SOLVE_HOP := 0.12
const SOLVE_TIME := 0.4
const SOLVE_STAGGER := 0.05
const ENTER_DROP := 0.5
const ENTER_PLATFORM := 0.5
const ENTER_POP := 0.26
const ENTER_STAGGER := 0.04
const HINT_TIME := 0.35
const SPARKLE_LIFT := 0.1

var nodes: int = 7
var _edges: Array = []
## Node positions in the generator's normalised square, as the 2D board kept
## them: the generator, the crossing test and the win harness all speak this.
var _pos: PackedVector2Array = PackedVector2Array()
var _start: PackedVector2Array = PackedVector2Array()
var _planar: PackedVector2Array = PackedVector2Array()
var _crossings: int = 0
var _held: int = -1
var _grab_offset: Vector2 = Vector2.ZERO
## One entry per finished drag, newest last: {"node": i, "from": Vector2}.
var _history: Array[Dictionary] = []
var _locked: Array = []

# --- scene ---
var _cols: int = 6
var fx: Node3D
var _posts: Array = []        # [i] -> post model
var _ropes: Array = []        # [e] -> MeshInstance3D carrying the tube
var _rope_pts: Array = []     # [e] -> Array[Vector3], the simulated points
var _rope_prev: Array = []    # [e] -> Array[Vector3]
var _rope_awake: Array = []   # [e] -> bool
var _rope_bad: Array = []     # [e] -> bool, in a crossing
var _lift_tw: Array = []      # [i]
var _hop_tw: Array = []       # [i]
var _entrance: Array = []
var _sim_accum := 0.0

func _ready() -> void:
	super()
	solved.connect(_on_solved)

func puzzle_id() -> String: return "untangle"
func title() -> String: return "Untangle"

func rules() -> String:
	return "Drag the posts until no two ropes cross. A rope caught in a crossing turns red. Keep the posts apart -- a heap of posts in one corner does not count."

func board_size() -> Vector2i: return Vector2i(_cols, _cols)
func board_height() -> float: return Placeholders.POST_H + Placeholders.POST_CAP_H + LIFT
## Taps land on the stone the posts stand on.
func plane_height() -> float: return 0.0
func board_margin() -> float: return Platform.LIP
func board_depth() -> float: return Placeholders.PLATFORM_H

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	match difficulty:
		0: nodes = 7; _cols = 6
		1: nodes = 10; _cols = 7
		_: nodes = 14; _cols = 8
	var out: Dictionary = Gen.generate(rng, nodes)
	_edges = out.edges
	_start = out.start
	_planar = out.planar
	_pos = out.start.duplicate()
	_held = -1
	_history = []
	_locked = []
	for i in nodes:
		_locked.append(false)
	_build_scene()
	_score()
	_refit()
	_enter()

func reset_board() -> void:
	_stop_entrance()
	_held = -1
	for i in nodes:
		_settle(i)
		if _locked[i]:
			continue
		_pos[i] = _start[i]
	_history = []
	_running = true
	moves = 0
	_place_posts()
	_reseat_ropes()
	_score()
	fx.cue("reset")

func is_solved() -> bool:
	return Gen.is_untangled(_edges, _pos)

func share_glyphs() -> String:
	return "🕸 %d nodes · %d moves" % [nodes, moves]

# --- capabilities ---

func capabilities() -> Array[String]:
	return ["undo", "hint"]

func _open() -> bool:
	return not is_done()

func can_undo() -> bool:
	return _open() and not _history.is_empty()

## Puts the last dragged post back where it was picked up.
func undo() -> bool:
	if not _open() or _history.is_empty():
		return false
	var last: Dictionary = _history.pop_back()
	var i := int(last.node)
	_pos[i] = last.from
	_place_post(i)
	_wake_around(i)
	_score()
	fx.cue("undo")
	moved.emit()
	check_solved()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Slides one post to the place the generator's own untangled drawing put it,
## and pins it there. Prefers a post that is currently in a crossing: moving a
## post that is already out of trouble teaches nothing. Counts no move.
func hint() -> bool:
	if not _open() or hints_left() <= 0:
		return false
	var pick := -1
	for i in nodes:
		if _locked[i] or _pos[i].is_equal_approx(_planar[i]):
			continue
		if _in_crossing(i):
			pick = i
			break
	if pick < 0:
		for i in nodes:
			if not _locked[i] and not _pos[i].is_equal_approx(_planar[i]):
				pick = i
				break
	if pick < 0:
		return false
	_locked[pick] = true
	_pos[pick] = _planar[pick]
	var kept: Array[Dictionary] = []
	for h in _history:
		if int(h.node) != pick:
			kept.append(h)
	_history = kept
	var post: Node3D = _posts[pick]
	Motion.stop(_hop_tw[pick])
	_hop_tw[pick] = Motion.settle(post, "position", _world_of(pick), HINT_TIME, 0.0, true)
	if _hop_tw[pick] == null:
		post.position = _world_of(pick)
	Models.tint_named(post, "Cap", Pal.GOOD)
	fx.sparkle(_world_of(pick) + Vector3(0.0, Placeholders.POST_H + SPARKLE_LIFT, 0.0))
	_wake_around(pick)
	_score()
	hints_used += 1
	fx.cue("hint")
	moved.emit()
	check_solved()
	return true

## True when node `i` is an endpoint of any edge caught in a crossing.
func _in_crossing(i: int) -> bool:
	for e in _edges.size():
		if not _rope_bad[e]:
			continue
		var edge: Vector2i = _edges[e]
		if edge.x == i or edge.y == i:
			return true
	return false

# --- geometry ---

## World point of node `i`, on the stone. The generator works in a normalised
## square; this maps it onto the board, leaving EDGE_MARGIN of stone around it
## so a post on the very edge still has its cap inside the moss rim.
func _world_of(i: int) -> Vector3:
	return _world_at(_pos[i])

func _world_at(p: Vector2) -> Vector3:
	var half := _cols * 0.5 - EDGE_MARGIN
	return Vector3((p.x - 0.5) * 2.0 * half, 0.0, (p.y - 0.5) * 2.0 * half)

## The inverse: a board-plane point back into the normalised square.
func _norm_at(world: Vector3) -> Vector2:
	var half := _cols * 0.5 - EDGE_MARGIN
	return Vector2(world.x / (2.0 * half) + 0.5, world.z / (2.0 * half) + 0.5)

## Where a rope is made fast on post `i`.
func _cleat(i: int) -> Vector3:
	return _world_of(i) + Vector3(0.0, Placeholders.ROPE_Y, 0.0)

# --- scene ---

func _stop_all() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for group in [_lift_tw, _hop_tw]:
		for tw in group:
			Motion.stop(tw)

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_posts = []
	_ropes = []
	_rope_pts = []
	_rope_prev = []
	_rope_awake = []
	_rope_bad = []
	_lift_tw = []
	_hop_tw = []

	board.add_child(Platform.build(_cols, _cols))
	fx = Fx.new()
	board.add_child(fx)

	for i in nodes:
		var post := Models.instance("post")
		post.name = "post_%d" % i
		board.add_child(post)
		_posts.append(post)
		_lift_tw.append(null)
		_hop_tw.append(null)
	_place_posts()

	for e in _edges.size():
		var mi := MeshInstance3D.new()
		mi.name = "rope_%d" % e
		mi.mesh = ArrayMesh.new()
		# A rope is 0.09 across: its shadow would be a hairline on the stone,
		# and there are up to 24 of them, so that is 24 shadow-pass draw calls
		# for nothing. The posts still cast theirs.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		board.add_child(mi)
		# The shell shares this instance's mesh, so every rebuild carries the
		# outline with it -- nothing to refresh.
		Toon.add_outline(mi)
		_ropes.append(mi)
		_rope_pts.append([])
		_rope_prev.append([])
		_rope_awake.append(true)
		_rope_bad.append(false)
	_reseat_ropes()

func _place_posts() -> void:
	for i in nodes:
		_place_post(i)

func _place_post(i: int) -> void:
	(_posts[i] as Node3D).position = _world_of(i)

## Drops every rope straight onto the line between its posts and lets the sim
## take it from there. Used on build, reset and undo, where a rope should not
## whip in from wherever it happened to be.
func _reseat_ropes() -> void:
	for e in _edges.size():
		var edge: Vector2i = _edges[e]
		var a := _cleat(edge.x)
		var b := _cleat(edge.y)
		var pts: Array = []
		var prev: Array = []
		for k in ROPE_POINTS:
			var t := float(k) / float(ROPE_POINTS - 1)
			var p := a.lerp(b, t)
			pts.append(p)
			prev.append(p)
		_rope_pts[e] = pts
		_rope_prev[e] = prev
		_rope_awake[e] = true
		_rebuild_rope(e)

# --- the rope simulation ---

func _process(delta: float) -> void:
	super(delta)
	if _ropes.is_empty():
		return
	# Fixed steps, so the rope behaves the same on a slow frame as a fast one.
	_sim_accum += minf(delta, 0.1)
	var steps := 0
	while _sim_accum >= SIM_STEP and steps < 4:
		_sim_accum -= SIM_STEP
		steps += 1
		for e in _edges.size():
			if _rope_awake[e]:
				_step_rope(e)
	if steps == 0:
		return
	for e in _edges.size():
		if _rope_awake[e]:
			_rebuild_rope(e)

## One Verlet step of rope `e`: carry every free point by its own momentum,
## pull it down, then satisfy the segment lengths a few times. The two ends
## are pinned to their posts' cleats, which is what makes a dragged post throw
## its ropes about.
func _step_rope(e: int) -> void:
	var edge: Vector2i = _edges[e]
	var pts: Array = _rope_pts[e]
	var prev: Array = _rope_prev[e]
	var a := _cleat(edge.x)
	var b := _cleat(edge.y)
	var gravity := GRAVITY * SIM_STEP * SIM_STEP
	var before: Array = []
	for k in range(1, ROPE_POINTS - 1):
		var p: Vector3 = pts[k]
		before.append(p)
		var v: Vector3 = (p - (prev[k] as Vector3)) * ROPE_DAMPING
		prev[k] = p
		var next: Vector3 = p + v + Vector3(0.0, gravity, 0.0)
		if next.y < ROPE_FLOOR:
			next.y = ROPE_FLOOR
		pts[k] = next
	pts[0] = a
	pts[ROPE_POINTS - 1] = b
	prev[0] = a
	prev[ROPE_POINTS - 1] = b
	# Rest length from the sag we want, via the shallow-catenary relation
	# extra_length / span ~= (8/3)(sag / span)^2, recomputed from the live span
	# so a rope that is being stretched apart goes taut on its own.
	var span_ab := a.distance_to(b)
	var sag := minf(SAG_MAX, SAG_RATIO * span_ab)
	var slack := 1.0 + (8.0 / 3.0) * pow(sag / maxf(span_ab, 0.001), 2.0)
	var rest := span_ab * slack / float(ROPE_POINTS - 1)
	for pass_i in ROPE_ITERATIONS:
		for step in ROPE_POINTS - 1:
			# Alternate the sweep direction pass by pass.
			var k: int = step if pass_i % 2 == 0 else ROPE_POINTS - 2 - step
			var p0: Vector3 = pts[k]
			var p1: Vector3 = pts[k + 1]
			var d := p1 - p0
			var span := d.length()
			if span < 1e-6:
				continue
			# A pinned end cannot take its share, so the free end takes the
			# whole correction. Halving it there instead -- which is what
			# happens if both ends are treated alike -- throws away half the
			# correction at every boundary, and the rope settles stretched
			# well past its rest length however many passes it is given.
			var stretch := (span - rest) / span
			var pinned0 := k == 0
			var pinned1 := k + 1 == ROPE_POINTS - 1
			if pinned0 and pinned1:
				continue
			elif pinned0:
				pts[k + 1] = p1 - d * stretch
			elif pinned1:
				pts[k] = p0 + d * stretch
			else:
				var fix := d * stretch * 0.5
				pts[k] = p0 + fix
				pts[k + 1] = p1 - fix
		pts[0] = a
		pts[ROPE_POINTS - 1] = b
	# The constraint pass can pull a point back under the stone, so the floor
	# is applied after it, not only before.
	for k in range(1, ROPE_POINTS - 1):
		var q: Vector3 = pts[k]
		if q.y < ROPE_FLOOR:
			pts[k] = Vector3(q.x, ROPE_FLOOR, q.z)
	# Judged on where the point actually ended up, after the constraints had
	# their say -- an integration step that gravity and the length constraint
	# simply cancel out is a rope at rest, and a rope at rest is not redrawn.
	var moved_by := 0.0
	for k in range(1, ROPE_POINTS - 1):
		moved_by = maxf(moved_by, ((pts[k] as Vector3) - (before[k - 1] as Vector3)).length())
	if moved_by < ROPE_SLEEP:
		_rope_awake[e] = false

## Wakes every rope made fast to post `i`; called whenever that post moves.
func _wake_around(i: int) -> void:
	for e in _edges.size():
		var edge: Vector2i = _edges[e]
		if edge.x == i or edge.y == i:
			_rope_awake[e] = true

## Rebuilds rope `e`'s tube from its points. The outline shell shares this
## mesh, so it follows without being touched.
func _rebuild_rope(e: int) -> void:
	var mesh: ArrayMesh = (_ropes[e] as MeshInstance3D).mesh
	mesh.clear_surfaces()
	var pts: Array = _rope_pts[e]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for k in ROPE_POINTS:
		var tangent: Vector3
		if k == 0:
			tangent = (pts[1] as Vector3) - (pts[0] as Vector3)
		elif k == ROPE_POINTS - 1:
			tangent = (pts[k] as Vector3) - (pts[k - 1] as Vector3)
		else:
			tangent = (pts[k + 1] as Vector3) - (pts[k - 1] as Vector3)
		if tangent.length() < 1e-6:
			tangent = Vector3.RIGHT
		tangent = tangent.normalized()
		var side := tangent.cross(Vector3.UP)
		if side.length() < 1e-4:
			side = tangent.cross(Vector3.FORWARD)
		side = side.normalized()
		var up := side.cross(tangent).normalized()
		for r in ROPE_RADIAL:
			var ang := TAU * float(r) / float(ROPE_RADIAL)
			var dir := side * cos(ang) + up * sin(ang)
			verts.append((pts[k] as Vector3) + dir * Placeholders.ROPE_R)
			norms.append(dir)
	for k in ROPE_POINTS - 1:
		for r in ROPE_RADIAL:
			var r2 := (r + 1) % ROPE_RADIAL
			var a0 := k * ROPE_RADIAL + r
			var a1 := k * ROPE_RADIAL + r2
			var b0 := (k + 1) * ROPE_RADIAL + r
			var b1 := (k + 1) * ROPE_RADIAL + r2
			idx.append_array([a0, a1, b0, a1, b1, b0])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	(_ropes[e] as MeshInstance3D).set_surface_override_material(0,
		Toon.material(Pal.BAD if _rope_bad[e] else Pal.WOOD_DEEP))

# --- scoring and colour ---

## Recomputes the crossings and paints what it finds: a rope in a crossing
## goes red, and a post sitting on top of a neighbour turns its cap red too,
## which is the "keep them apart" rule the 2D board could only say in words.
func _score() -> void:
	_crossings = Gen.crossings(_edges, _pos)
	var bad_before: Array = _rope_bad.duplicate()
	for e in _edges.size():
		_rope_bad[e] = false
	for i in _edges.size():
		for j in range(i + 1, _edges.size()):
			var e: Vector2i = _edges[i]
			var f: Vector2i = _edges[j]
			if e.x == f.x or e.x == f.y or e.y == f.x or e.y == f.y:
				continue
			if Geometry2D.segment_intersects_segment(_pos[e.x], _pos[e.y], _pos[f.x], _pos[f.y]) != null:
				_rope_bad[i] = true
				_rope_bad[j] = true
	for e in _edges.size():
		if _rope_bad[e] != bad_before[e]:
			_rebuild_rope(e)
	_paint_posts()

func _paint_posts() -> void:
	var crowded := {}
	for a in nodes:
		for b in range(a + 1, nodes):
			if _pos[a].distance_to(_pos[b]) < Gen.MIN_SEP:
				crowded[a] = true
				crowded[b] = true
	for i in nodes:
		var col := Pal.ACCENT
		if i == _held:
			col = Pal.ACCENT_2
		elif crowded.has(i):
			col = Pal.BAD
		elif _locked[i]:
			col = Pal.GOOD
		Models.tint_named(_posts[i], "Cap", col)

# --- entrance, solve ---

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
	for i in nodes:
		var post: Node3D = _posts[i]
		post.scale = Vector3.ONE * 0.01
		var pop: Tween = Motion.settle(post, "scale", Vector3.ONE, ENTER_POP,
			ENTER_PLATFORM + Motion.stagger(i, ENTER_STAGGER))
		if pop == null:
			post.scale = Vector3.ONE
		else:
			_entrance.append(pop)
	fx.cue("enter")

func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	if _posts.is_empty():
		return
	var platform: Node3D = board.get_node_or_null("Platform")
	if platform != null:
		platform.position.y = 0.0
	for post in _posts:
		(post as Node3D).scale = Vector3.ONE

func _splash() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(board.global_position)

func _settle(i: int) -> void:
	Motion.stop(_lift_tw[i])
	Motion.stop(_hop_tw[i])
	_lift_tw[i] = null
	_hop_tw[i] = null
	var post: Node3D = _posts[i]
	post.position.y = 0.0
	post.scale = Vector3.ONE

## Nothing crosses: the posts hop in turn and every rope swings with them.
func _on_solved() -> void:
	_held = -1
	_paint_posts()
	for i in nodes:
		Motion.stop(_lift_tw[i])
		_lift_tw[i] = Motion.hop(_posts[i], SOLVE_HOP, SOLVE_TIME,
			Motion.stagger(i, SOLVE_STAGGER), 0.0)
		_wake_around(i)
	fx.cue("solved")

# --- input ---

## The grabbed post keeps its offset from the fingertip, so a thumb never sits
## on top of the crossing it is trying to fix -- the 2D board's trick, kept.
func on_board_press(hit: Vector3) -> void:
	var i := _nearest(hit)
	if i < 0 or _locked[i]:
		return
	_held = i
	_grab_offset = _pos[i] - _norm_at(hit)
	_history.append({"node": i, "from": _pos[i]})
	Motion.stop(_lift_tw[i])
	_lift_tw[i] = Motion.settle(_posts[i], "position:y", LIFT, LIFT_TIME)
	if _lift_tw[i] == null:
		(_posts[i] as Node3D).position.y = LIFT
	_paint_posts()
	fx.cue("grab")

func on_board_drag(hit: Vector3) -> void:
	if _held < 0:
		return
	var target := _norm_at(hit) + _grab_offset
	_pos[_held] = Vector2(clampf(target.x, 0.03, 0.97), clampf(target.y, 0.03, 0.97))
	var post: Node3D = _posts[_held]
	var lifted := post.position.y
	post.position = _world_of(_held)
	post.position.y = lifted
	_wake_around(_held)
	_score()

func on_board_release(_hit: Vector3) -> void:
	if _held < 0:
		return
	var i := _held
	_held = -1
	Motion.stop(_lift_tw[i])
	_lift_tw[i] = Motion.settle(_posts[i], "position:y", 0.0, LIFT_TIME, 0.0, true)
	if _lift_tw[i] == null:
		(_posts[i] as Node3D).position.y = 0.0
	_wake_around(i)
	_score()
	fx.puff(_world_of(i))
	fx.cue("drop")
	note_move()

## The post nearest a board-plane hit, or -1 when nothing is within reach.
func _nearest(hit: Vector3) -> int:
	var best := -1
	var best_d := GRAB_R
	for i in nodes:
		var d := Vector2(hit.x, hit.z).distance_to(Vector2(_world_of(i).x, _world_of(i).z))
		if d < best_d:
			best_d = d
			best = i
	return best

## Control-local point over post `i`, and over where an untangled drawing puts
## it. The win harness drags between the two.
func node_to_local(i: int) -> Vector2:
	return board_to_local(_world_of(i))

func planar_to_local(i: int) -> Vector2:
	return board_to_local(_world_at(_planar[i]))
