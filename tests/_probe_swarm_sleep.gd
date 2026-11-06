extends SceneTree

## Throwaway: the face held asleep stays a loose field, wakes into a face with
## its eyes shut a moment, and an unformed face only sleeps once.

var _f
var _t := 0.0
var _phase := 0
var _fails := 0

func _check(what: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1

func _process(delta: float) -> bool:
	if _f == null:
		_f = load("res://bot/swarm_face.gd").new()
		_f.size = Vector2(810, 1440)
		root.add_child(_f)
		_f.size = Vector2(810, 1440)
		_f.open()
		_f.sleep(true)
		return false
	_t += delta
	match _phase:
		0:
			if _t > 3.0:
				_check("asleep 3 s: not formed", not _f.is_formed())
				_check("asleep: no gather", _f._gather == 0.0)
				_f.sleep(false)
				_t = 0.0
				_phase = 1
		1:
			if _t > 0.2 and _t < 0.3:
				_check("woken 0.2 s: still gathering, not formed", not _f.is_formed())
			if _f.is_formed():
				_check("formed %.2f s after waking" % _t, _t > 1.2 and _t < 1.6)
				_check("eyes shut on waking", _f._eyes_to == 0.0)
				_t = 0.0
				_phase = 2
		2:
			if _t > 1.2:
				_check("eyes open again", _f._eyes_to == 1.0 and _f._eyes > 0.9)
				_f.sleep(true)
				_check("a formed face ignores sleep", not _f._asleep)
				print("fails: %d" % _fails)
				return true
	return false
