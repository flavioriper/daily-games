extends SceneTree

## Toy Boats online, two processes through the real screen, against the
## emulators and nothing else:
##
##     cd server && PATH="/opt/homebrew/opt/openjdk/bin:$PATH" firebase emulators:start --only auth,database --project demo-peeplet
##     FIREBASE_EMULATOR=127.0.0.1 FIREBASE_PROJECT=demo-peeplet godot --headless --path . --script res://tests/_probe_boats_online.gd [-- lay]
##
## The conductor starts two more of itself (`-- play <who> <file> <mode>`),
## each its own identity (BACKEND_PLAYER), each a hand that presses Ready and
## throws where the computer would, as taps on the board. The cases:
##
## 1. **A whole game** to one result at both ends: one won and one lost, the
##    winner's slate true of the loser's pond, the loser shown the winner's
##    fleet as it really lay, one win and one loss counted.
## 2. **A fleet moved after its seal.** One end lays its boats elsewhere once
##    play has begun and answers for the new places. Nothing can tell until a
##    fleet is shown; then the other end finds it out (the seal, or an answer
##    that was not true of it) and wins by a foul.
## 3. **A throw that is not one** (a square off the pond): a foul at once.
## 4. **An answer that cannot be** (sunk said of a boat with squares never
##    hit): a foul at once.
## 5. **A resignation** through Back and the dialog.
## 6. `lay`: **one end never presses Ready.** Its boats are taken as they lie
##    with a few seconds left on its minute, and the game is played (waits
##    most of a real minute).
##
## Only the conductor saves and restores user://versus.cfg. SPEED (4) is the
## players' time scale.

const Rules = preload("res://versus/boats_rules.gd")
const AI = preload("res://versus/boats_ai.gd")
const Record = preload("res://versus/versus_record.gd")
const Backend = preload("res://core/backend.gd")
const CFG := "user://versus.cfg"

var _begun := false
var _fails := 0
var _tag := ""
var _had := false
var _saved := ""

# a player's
var _s: Node
var _mode := ""
var _file := ""
var _reported := false
var _rng := RandomNumberGenerator.new()
var _why := ""
var _said := ""
var _over_t := 0.0
var _moved := false
var _acted := false
var _sealed_fleet := ""

func _env(name: String, fallback: int) -> int:
	return int(OS.get_environment(name)) if OS.has_environment(name) else fallback

func _process(delta: float) -> bool:
	if not _begun:
		_begun = true
		if OS.get_environment("FIREBASE_EMULATOR").strip_edges().is_empty():
			print("FIREBASE_EMULATOR is not set; this probe only ever talks to the emulator")
			quit(2)
			return false
		var args := OS.get_cmdline_user_args()
		if args.size() >= 4 and args[0] == "play":
			_tag = "[%s] " % args[1]
			_file = args[2]
			_mode = args[3]
			_play()
		else:
			_conduct(args.has("lay"))
		return false
	if _s != null:
		_drive(delta / maxf(Engine.time_scale, 0.01))
	return false

func _say(text: String) -> void:
	print(_tag + text)

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_fails += 1
	_say("%s  %s%s" % ["PASS" if ok else "FAIL", name, "" if detail.is_empty() else " (%s)" % detail])

# --- the conductor ---

func _spawn(who: String, mode: String) -> Array:
	var file := ProjectSettings.globalize_path("user://probe_boats_%s.json" % who)
	DirAccess.remove_absolute(file)
	OS.set_environment("BACKEND_PLAYER", "user://probe_player_%s.cfg" % who)
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/_probe_boats_online.gd", "--", "play", who, file, mode]
	return [file, OS.create_process(OS.get_executable_path(), args)]

func _report(file: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(file)) if FileAccess.file_exists(file) else null
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _pair(mode_a: String, mode_b: String, deadline: float) -> Array:
	var a := _spawn("a", mode_a)
	var b := _spawn("b", mode_b)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < deadline * 1000.0:
		if FileAccess.file_exists(a[0]) and FileAccess.file_exists(b[0]):
			break
		await create_timer(0.25, true, false, true).timeout
	await create_timer(1.5, true, false, true).timeout
	var out := [_report(a[0]), _report(b[0]), (Time.get_ticks_msec() - t0) / 1000.0]
	for m: Array in [a, b]:
		if OS.is_process_running(m[1]):
			OS.kill(m[1])
	return out

func _conduct(lay: bool) -> void:
	_had = FileAccess.file_exists(CFG)
	if _had:
		_saved = FileAccess.get_file_as_string(CFG)
	var before := Record.get_record("boats", Record.ONLINE)

	_say("1. a whole game")
	var r: Array = await _pair("whole", "whole", 240.0)
	var a: Dictionary = r[0]
	var b: Dictionary = r[1]
	_check("both ends finished", not a.is_empty() and not b.is_empty(), "%.0f s" % r[2])
	if not a.is_empty() and not b.is_empty():
		var w: Dictionary = a if a.outcome == "won" else b
		var l: Dictionary = b if a.outcome == "won" else a
		_check("one won and one lost, on the water", w.outcome == "won" and l.outcome == "lost" and w.why == "" and l.why == "",
			"%s/%s why '%s'/'%s' said '%s'/'%s'" % [w.outcome, l.outcome, w.why, l.why, w.said, l.said])
		_check("in different seats, the opener threw first", int(a.seat) + int(b.seat) == 1 and a.first != b.first)
		_check("the winner sank all five and the loser's pond agrees", int(w.sunk) == 5 and int(l.lost) == 5 and w.slate == l.pond_marks,
			"%d pebbles" % int(w.shots))
		_check("the loser's slate is true of the winner's pond", l.slate == w.pond_marks)
		_check("each was shown the other's fleet as it lay", w.shown == l.fleet and l.shown == w.fleet)
		_check("each sealed the fleet it played", w.sealed == w.fleet and l.sealed == l.fleet)
		_check("both ends settled, and no foul", w.settled and l.settled and not w.foul and not l.foul)
		var after := Record.get_record("boats", Record.ONLINE)
		_check("one win and one loss counted", after - before == Vector2i(1, 1), str(after - before))

	_say("2. a fleet moved after its seal")
	r = await _pair("mover", "whole", 240.0)
	a = r[0]
	b = r[1]
	_check("both ends finished", not a.is_empty() and not b.is_empty(), "%.0f s" % r[2])
	if not b.is_empty():
		_check("the honest end found it out: won by a foul", b.outcome == "won" and b.why == "left", "%s why '%s' said '%s'" % [b.outcome, b.why, b.said])
		_check("the mover did move", not a.is_empty() and a.sealed != a.fleet)

	_say("3. a throw that is not one")
	r = await _pair("bad_throw", "whole", 60.0)
	b = r[1]
	_check("the other end ends it: won, the thrower gone", not b.is_empty() and b.outcome == "won" and b.why == "left", str(b.get("why", "?")))

	_say("4. an answer that cannot be")
	r = await _pair("bad_answer", "whole", 60.0)
	b = r[1]
	_check("the other end ends it: won, the answerer gone", not b.is_empty() and b.outcome == "won" and b.why == "left", str(b.get("why", "?")))

	_say("5. a resignation")
	var at5 := Record.get_record("boats", Record.ONLINE)
	r = await _pair("resign", "whole", 90.0)
	a = r[0]
	b = r[1]
	_check("the one who left was asked first, and its screen closed settled", not a.is_empty() and a.asked and a.closed and a.settled)
	_check("the other won by it", not b.is_empty() and b.outcome == "won" and b.why == "resign", str(b.get("why", "?")))
	_check("one win and one loss counted for it", Record.get_record("boats", Record.ONLINE) - at5 == Vector2i(1, 1))

	if lay:
		_say("6. one end never presses Ready")
		r = await _pair("idle", "whole", 400.0)
		a = r[0]
		b = r[1]
		_check("its boats were taken as they lay and the game was played", not a.is_empty() and not b.is_empty()
			and a.why == "" and b.why == "" and a.outcome != b.outcome, "%.0f s, %s/%s why '%s'/'%s'" % [r[2], a.get("outcome"), b.get("outcome"), a.get("why"), b.get("why")])

	_restore()
	_say("FAILS %d" % _fails)
	quit(1 if _fails > 0 else 0)

func _restore() -> void:
	if _had:
		var f := FileAccess.open(CFG, FileAccess.WRITE)
		f.store_string(_saved)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))

# --- one player ---

func _play() -> void:
	var host := Node.new()
	root.add_child(host)
	await Backend.start(host)
	Engine.time_scale = float(_env("SPEED", 4))
	load("res://core/motion.gd").reduce = true
	_rng.randomize()
	# load(), not preload: the screen names the Ads autoload, which is not
	# there yet when this script compiles.
	var screen: GDScript = load("res://versus/boats_screen.gd")
	_s = screen.new(Record.ONLINE)
	_s.closed.connect(func() -> void:
		_say("the screen closed")
		_write(true))
	root.add_child(_s)
	_s.board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_s.online.over.connect(func(outcome: String, why: String) -> void:
		_said = "%s %s" % [outcome, why]
		if why != "end":
			_why = why)
	_say("%s is looking" % load("res://versus/online/names.gd").name_of(Backend.uid()))

func _tap(c: int) -> void:
	for down: bool in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = down
		ev.position = _s.board.point_of(1, c)
		_s.board._gui_input(ev)

func _drive(real: float) -> void:
	if _reported:
		return
	var S = _s.State
	var st: int = _s._state
	if st == S.OVER:
		_over_t += real
		if _over_t > 1.0:
			_write(false)
		return
	if st == S.PLACE and _mode != "idle":
		_sealed_fleet = Rules.pack(_s.pond.boats)
		_s._ready_b.pressed.emit()
		return
	if st == S.PLACE or st == S.READY:
		_sealed_fleet = Rules.pack(_s.pond.boats)
	if _mode == "mover" and not _moved and (st == S.YOURS or st == S.THEIRS) and _s.pond.shots == 0:
		# The boats go somewhere else, after the seal has gone.
		_moved = true
		var other := Rules.random_fleet(_rng, true)
		while Rules.pack(other) == _sealed_fleet:
			other = Rules.random_fleet(_rng, true)
		_s.pond.lay(other)
		_say("moved its fleet")
	if st != S.YOURS:
		if _mode == "bad_answer" and not _acted and st == S.THEIRS:
			# Whatever is thrown next is answered "sunk", of a boat that was
			# never touched.
			_acted = true
			_s.online.move.disconnect(_s._on_online_move)
			_s.online.move.connect(func(d: Dictionary) -> void:
				if d.has("s"):
					var at := Rules.xy(int(d.s))
					_s.online.send({"r": Rules.SUNK, "i": 4, "b": [mini(at.x, 8), at.y, 0]}, true))
		return
	if _mode == "bad_throw" and not _acted:
		_acted = true
		_say("throws at a square off the pond")
		_s.online.send({"s": 250})
		_s._state = S.FLY
		return
	if _mode == "resign" and _s.slate.shots >= 3 and not _acted:
		_acted = true
		_resign()
		return
	_tap(AI.plan(_s.slate, 2, _rng))

var _asked := false

## Back, as the top bar's arrow does it, and then the dialog's Resign.
func _resign() -> void:
	_s._on_back()
	await process_frame
	var ask: Node = _s.get_node_or_null("Leave")
	_asked = ask != null
	if ask == null:
		_say("no dialog came up")
		_write(false)
		return
	var go: Button = ask.find_child("Buttons", true, false).get_child(1)
	go.pressed.emit()

func _write(closed: bool) -> void:
	if _reported:
		return
	_reported = true
	var on: Node = _s.online
	var result: Dictionary = on.result
	var outcome := "?"
	if not result.is_empty():
		outcome = "won" if int(result.winner) == int(on.seat) else "lost"
	if _why == "" and str(result.get("why", "")) != "end" and not result.is_empty():
		_why = str(result.why)
	var shown := ""
	if _s.board._fleet.size() == 5:
		shown = Rules.pack(_s.board._fleet)
	elif _s.slate.all_sunk():
		# The winner found every boat: the slate's outlines are the fleet.
		shown = Rules.pack(_s.slate.boats)
	var saw := {
		"uid": Backend.uid(), "seat": int(on.seat), "first": bool(_s.first), "outcome": outcome, "why": _why, "said": _said,
		"closed": closed, "asked": _asked, "settled": bool(on._settled), "foul": _why == "left",
		"shots": int(_s.slate.shots), "sunk": 5 - int(_s.slate.afloat()), "lost": 5 - int(_s.pond.afloat()),
		"slate": Marshalls.raw_to_base64(_s.slate.marks), "pond_marks": Marshalls.raw_to_base64(_s.pond.marks),
		"fleet": Rules.pack(_s.pond.boats), "sealed": _sealed_fleet, "shown": shown, "state": int(_s._state),
	}
	_say("%s%s after %d pebbles" % [outcome, "" if _why == "" else " (" + _why + ")", saw.shots])
	var f := FileAccess.open(_file, FileAccess.WRITE)
	f.store_string(JSON.stringify(saw))
	f.close()
	await create_timer(1.0, true, false, true).timeout
	quit(0)
