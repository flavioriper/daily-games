extends SceneTree
## Throwaway: plays Yarn Hoop through press/drag/release on every band.
const Board = preload("res://puzzles/hoop2d.gd")
const Motion = preload("res://core/motion.gd")
var _b
var _band := 0
var _frame := 0
func _initialize() -> void:
	Motion.reduce = true
func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 1:
		_make()
	elif _frame == 3:
		_play()
		_band += 1
		if _band >= 4:
			return true
		_b.queue_free()
		_frame = 0
	return false
func _make() -> void:
	_b = Board.new()
	_b.size = Vector2(1080, 1920)
	root.add_child(_b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777 + _band
	_b.start(rng, _band)
	_b.set_clear(330.0, 60.0)
func _play() -> void:
	var s = _b.state
	var t0 := Time.get_ticks_msec()
	# a refused thread: two pins that share no side
	var bad := 0
	for a in s.pins.size():
		for c in s.pins.size():
			if a != c and s.side_between(a, c) < 0 and _b.pin_screen(a).distance_to(_b.pin_screen(c)) < 200:
				_b.press(_b.pin_screen(a)); _b.drag(_b.pin_screen(c)); _b.release(_b.pin_screen(c))
				bad = s.refused
				break
		if bad > 0: break
	# every panel's outline as one drag where it can be
	var best := 0
	for k in s.panels.size():
		if s.filled[k]: continue
		var corners: PackedInt32Array = s.panels[k]
		var p0 = _b.pin_screen(corners[0])
		if s.pin_open[corners[0]] <= 0:
			continue
		_b.press(p0)
		for m in range(1, corners.size() + 1):
			var v = corners[m % corners.size()]
			_b.drag(_b.pin_screen(v))
		best = max(best, _b._stroke)
		_b.release(Vector2.ZERO)
	# whatever is left, by the side
	for i in s.sides.size():
		if not s.laid[i]:
			s.lay_side(i)
	_b.check_solved()
	var draw_t := Time.get_ticks_msec()
	_b._layout()
	for c in ceili(float(s.panels.size()) / 10):
		_b._chunk_mesh(c)
	print("band %d: %d panels %d pins %d sides, refused %d, best stroke %d, solved %s, done %s, knit build %d ms, play %d ms" % [_band, s.panels.size(), s.pins.size(), s.sides.size(), bad, best, s.is_solved(), _b.is_done(), Time.get_ticks_msec() - draw_t, draw_t - t0])
