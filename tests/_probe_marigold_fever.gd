extends SceneTree

## Throwaway: the last marigold's approach and the full bloom, through the
## real board. Leaves one marigold, shoots a line that hits it (or, with
## `miss`, one that brushes past it), logs the clock, the zoom, the drumroll
## and the music, and shoots frames to /tmp/mgf_<n>.png.
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_probe_marigold_fever.gd [-- miss]

const Board = preload("res://puzzles/marigold2d.gd")

var _b
var _t := 0.0
var _miss := false
var _shots := [0.9, 1.6, 2.2, 2.8, 3.6, 5.0]
var _next := 0
var _log_at := 0.0
var _fired := false

func _initialize() -> void:
	_miss = "miss" in OS.get_cmdline_user_args()
	_b = Board.new()
	_b.size = Vector2(1000, 1300)
	_b.position = Vector2(40, 200)
	root.add_child(_b)

func _process(delta: float) -> bool:
	_t += delta
	if _b._state.pos.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		_b.build(rng, 1)
		return false
	if not _fired and _t > 0.6:
		_fired = true
		_setup()
	if _fired and _t >= _log_at:
		_log_at = _t + 0.1
		print("t=%.2f phase=%s slow=%.2f zoom=%.2f near=%.2f roll=%.1fdB%s music=%s fever=%s spent=%s toast=%s" % [
			_t, _b._phase, _b._slow, _b._zoom, _b._near, _b._roll.volume_db,
			"(on)" if _b._roll.playing else "", _b._music.playing, _b._state.fever, _b._near_spent, _b._toast])
	if _next < _shots.size() and _t >= _shots[_next]:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/mgf_%d.png" % _next)
		_next += 1
	return _t > 7.5

func _setup() -> void:
	var st = _b._state
	# keep the first marigold the hint's line blooms, clear the rest
	var a: float = st.best_angle()
	var keep := _first_orange(st, a)
	for i in st.pos.size():
		if st.kind[i] == 1 and i != keep:
			st.st[i] = 2
			st.oranges_left -= 1
	if _miss:
		# a line that comes inside CLOSE of it and never touches it
		var best := -1.0
		for k in 400:
			var ang := lerpf(0.2, PI - 0.2, float(k) / 399.0)
			var r := _closest(st, ang, keep)
			if not r.hit and r.d > 0.4 and r.d < 3.0:
				best = ang
				print("miss line: angle %.3f passes %.2f units off" % [ang, r.d])
				break
		a = best
	_b._buds = []
	_b._hud = null
	_b._aim = a
	_b._shoot()
	print("fired at %.3f, marigold %d, oranges_left %d" % [a, keep, st.oranges_left])

func _first_orange(st, a: float) -> int:
	var c = st.clone()
	c.fire(a)
	for n in 240 * 8:
		for e: Dictionary in c.step([]):
			if e.t == "hit" and c.kind[e.i] == 1:
				return e.i
		if c.balls.is_empty():
			break
	return 0

func _closest(st, a: float, target: int) -> Dictionary:
	var c = st.clone()
	c.fire(a)
	var d := INF
	var reach: float = st.PEG_R + st.BALL_R
	for n in 240 * 8:
		for e: Dictionary in c.step([]):
			if e.t == "hit" and e.i == target:
				return {"hit": true, "d": 0.0}
		if c.balls.is_empty():
			break
		for ball: Dictionary in c.balls:
			d = minf(d, Vector2(ball.p).distance_to(st.pos[target]) - reach)
	return {"hit": false, "d": d}
