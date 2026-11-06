extends SceneTree
## Throwaway probe (2026-11-06): the swarm's new dials (eyes, wink, size,
## speed, peek/off spots) and the perform routine, on a bare face. Prints
## values; in a window it also writes snapshots to user://_dials_*.jpg.

var Face: Script
var _menu_script: Script
var _f: Control
var _t := 0.0
var _i := 0
var _fails := 0
var _shots := DisplayServer.get_name() != "headless"
var _plan: Array = []


func _check(name: String, ok: bool, info := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("  (" + info + ")" if info != "" else ""))
	if not ok:
		_fails += 1


func _initialize() -> void:
	_menu_script = load("res://ui/menu.gd")
	Face = load("res://bot/swarm_face.gd")
	_f = Face.new()
	_f.size = Vector2(810, 1440)
	root.add_child(_f)
	_f.open()
	_plan = [
		[3.5, func(): _check("formed", _f.is_formed())],
		[0.0, func(): _f.apply_swarm({"eyes": 0.0, "seconds": 1.5})],
		[0.8, func(): _check("eyes shut", _f._eye_open < 0.15, "%.2f" % _f._eye_open); _shot("eyes_shut")],
		[1.2, func(): _check("eyes back", _f._eyes_to == 1.0 and _f._eye_open > 0.8, "%.2f" % _f._eye_open)],
		[0.0, func(): _f.apply_swarm({"wink": "left"})],
		[0.2, func(): _check("wink left", _f._wink == -1.0); _shot("wink")],
		[0.5, func(): _check("wink over", _f._wink == 0.0)],
		[0.0, func(): _f.apply_move({"size": 0.5})],
		[1.5, func(): _check("small", absf(_f._scale - 0.5) < 0.05, "%.2f" % _f._scale); _shot("small")],
		[0.0, func(): _f.apply_move({"size": 1.6, "speed": 3.0, "to": "peek-left"})],
		[1.5, func(): _check("peek left", absf(_f._c.x) < 40.0, "x %.0f" % _f._c.x); _shot("peek_left")],
		[0.0, func(): _f.apply_move({"to": "off-right", "size": 1.0})],
		[2.0, func(): _check("off right", _f._c.x > _f.size.x + _f._R * 1.5, "x %.0f, R %.0f, goal %.0f" % [_f._c.x, _f._R, _f._goal().x]); _shot("off_right")],
		[0.0, func(): _f.apply_move({"to": "centre", "speed": 1.0})],
		[0.0, func(): _f.apply_tone({"intensity": 0.0})],
		[1.5, func(): _check("invisible", _f._inten < 0.05, "%.2f" % _f._inten); _shot("invisible")],
		[0.0, func(): _f.apply_tone({"intensity": 1.0})],
		# A routine with back: pink, small, top, then back as it was.
		[1.5, func(): _f.apply_perform({"steps": [
			{"at": 0.0, "tone": {"tone": "pink"}, "move": {"to": "top", "size": 0.6}},
			{"at": 0.6, "move": {"to": "bottom"}, "swarm": {"eyes": 1.5}},
			{"at": 1.2, "move": {"to": "top"}}], "back": true, "end": 1.8})],
		[0.9, func(): _check("routine playing", _f._perf_end >= 0.0 and _f._scale_to == 0.6 and _f._eyes_to == 1.5); _shot("routine")],
		[1.4, func(): _check("routine back", _f._perf_end < 0.0 and _f._scale_to == 1.0 and _f._eyes_to == 1.0 and String(_f._place.to) == "centre" and _f._tone_to.is_equal_approx(Face.COL_P), "to %s scale %.2f" % [_f._place.to, _f._scale_to])],
		# Frames: a moving picture, dots flowing between two drawings.
		[0.0, func(): _f.apply_perform({"steps": [
			{"at": 0.0, "draw": {"rows": ["#####", "#...#", "#...#", "#...#", "#####"]}},
			{"at": 0.8, "draw": {"rows": ["..#..", ".###.", "#####", ".###.", "..#.."]}}], "back": false, "end": 1.6})],
		[0.4, func(): _shot("frame_1")],
		[1.2, func(): _check("frames rest on the last", _f._pic_on and _f._perf_end < 0.0); _shot("frame_2")],
		# Stop: a long routine ended early puts the face back.
		[0.0, func(): _f.apply_draw({"clear": true}); _f.apply_perform({"steps": [{"at": 0.0, "move": {"size": 1.7}}, {"at": 30.0, "tone": {"tone": "red"}}], "back": true, "end": 31.0})],
		[0.5, func(): _f.apply_perform({"stop": true})],
		[0.2, func(): _check("stop puts back", _f._perf_end < 0.0 and _f._scale_to == 1.0)],
		# A call ends with the face hidden, off screen and tiny, mid-routine.
		[0.0, func(): _f.set_live(true); _f.apply_tone({"intensity": 0.0}); _f.apply_move({"to": "off-left", "size": 0.4}); _f.apply_perform({"steps": [{"at": 20.0, "tone": {"tone": "red"}}], "back": false, "end": 21.0})],
		[0.5, func(): _f.set_live(false)],
		[1.5, func(): _check("call end brings the face back", _f._perf_end < 0.0 and _f._scale_to == 1.0 and _f._inten_to == 1.0 and String(_f._place.to) == "centre", "inten %.1f to %s" % [_f._inten_to, _f._place.to])],
		# A picture keeps on screen: peek-left with a picture goes to the left side.
		[0.0, func(): _f.apply_draw({"rows": ["###", "#.#", "###"]}); _f.apply_move({"to": "peek-left"})],
		[1.5, func(): _check("picture peeks to the side", _f._goal().x < _f.size.x * 0.4 and _f._goal().x > 0.0, "goal x %.0f" % _f._goal().x)],
	]


func _shot(name: String) -> void:
	if not _shots:
		return
	var got: Dictionary = _f.snapshot(405)
	if got.has("jpg"):
		var fa := FileAccess.open("user://_dials_%s.jpg" % name, FileAccess.WRITE)
		fa.store_buffer(Marshalls.base64_to_raw(String(got.jpg)))
		fa.close()


func _process(delta: float) -> bool:
	if _i >= _plan.size():
		print("DONE fails=%d" % _fails)
		_f.close()
		return true
	_t += delta
	if _t >= float(_plan[_i][0]):
		_t = 0.0
		(_plan[_i][1] as Callable).call()
		_i += 1
	return false
