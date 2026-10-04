extends SceneTree

## Whole games online through the real screen, against the Firebase
## emulators, and PASS or FAIL for each thing seen. Not a test: a probe.
##
##   cd server && PATH="/opt/homebrew/opt/openjdk/bin:$PATH" \
##     firebase emulators:start --only auth,database --project demo-peeplet
##   FIREBASE_EMULATOR=127.0.0.1 FIREBASE_PROJECT=demo-peeplet \
##     godot --headless --path . --script res://tests/_probe_online.gd -- chess
##
## Run with only the game's name, it is the conductor: for each of three
## games it starts **two more processes** of itself (`-- chess play <who>
## <file> <mode>`), each with its own BACKEND_PLAYER, so they are two
## players. Each opens the real screen at level 3, is found by the other
## through the lobby, and plays its own seat with the game's computer as if
## tapped; the other seat is the match. Each writes what it saw to its file
## and the conductor compares.
##
## 1. **A whole game.** Both open on a scripted line that has an en passant,
##    an underpromotion (to a knight) and a castle on each side, so all three
##    are known to travel in the move, then the computer plays on (level 1
##    against level 0) to a mate or a draw. Both ends must print one result
##    and one final position.
## 2. **A kill.** One process kills itself (SIGKILL) on its fourth move; the
##    other must end with `left`, a win.
## 3. **A resignation.** One presses Back and the dialog's Resign; the other
##    must end with `resign`, a win, and the resigner's screen must close.
##
## 4. **A foul.** One sends a move no rule allows, past its own screen; the
##    other must walk away with `left`, a win.
##
## SPEED (Engine.time_scale, 4), SEED. user://versus.cfg is put back by the
## conductor on every way out (the players share it, so they leave it alone).
## Spec: docs/superpowers/specs/2026-10-04-versus-online-design.md, section 5.

const Backend = preload("res://core/backend.gd")
const Rules = preload("res://versus/chess_rules.gd")
const AI = preload("res://versus/chess_ai.gd")
const Record = preload("res://versus/versus_record.gd")

const CFG := "user://versus.cfg"
## The opening both ends play, a ply each in turn: from, to, promotion.
const LINE := [
	["e2", "e4", 0], ["a7", "a6", 0], ["e4", "e5", 0], ["d7", "d5", 0],
	["e5", "d6", 0], ["h7", "h6", 0], ["d6", "c7", 0], ["h6", "h5", 0],
	["c7", "b8", Rules.KNIGHT], ["g7", "g6", 0], ["g1", "f3", 0], ["f8", "g7", 0],
	["f1", "e2", 0], ["g8", "f6", 0], ["e1", "g1", 0], ["e8", "g8", 0],
]
## A game this long is given up by whoever is to move, the real way.
const LONG := 110

var _begun := false
var _fails := 0
var _tag := ""
var _had := false
var _saved := ""

# a player's
var _s: Node
var _mode := ""
var _file := ""
var _mine := 0
var _acted := false
var _reported := false
var _over_t := 0.0
var _idle_t := 0.0
var _last_state := -1

func _env(name: String, fallback: int) -> int:
	return int(OS.get_environment(name)) if OS.has_environment(name) else fallback

func _process(delta: float) -> bool:
	if not _begun:
		_begun = true
		var args := OS.get_cmdline_user_args()
		if args.size() >= 5 and args[1] == "play":
			_tag = "[%s] " % args[2]
			_file = args[3]
			_mode = args[4]
			_play()
		elif args.size() >= 1 and args[0] == "chess":
			_conduct()
		else:
			print("usage: -- chess   (checkers and snooker are not built yet)")
			quit(2)
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
	var file := ProjectSettings.globalize_path("user://probe_online_%s.json" % who)
	DirAccess.remove_absolute(file)
	OS.set_environment("BACKEND_PLAYER", "user://probe_player_%s.cfg" % who)
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/_probe_online.gd", "--", "chess", "play", who, file, mode]
	return [file, OS.create_process(OS.get_executable_path(), args)]

func _report(file: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(file)) if FileAccess.file_exists(file) else null
	return d if typeof(d) == TYPE_DICTIONARY else {}

## Starts two players and waits for the reports of those in `need`.
func _pair(mode_a: String, mode_b: String, need: Array, deadline: float) -> Array:
	var a := _spawn("a", mode_a)
	var b := _spawn("b", mode_b)
	var made := [a, b]
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < deadline * 1000.0:
		var all := true
		for i: int in need:
			all = all and FileAccess.file_exists(made[i][0])
		if all:
			break
		await create_timer(0.25, true, false, true).timeout
	await create_timer(1.5, true, false, true).timeout
	var out := [_report(a[0]), _report(b[0]), (Time.get_ticks_msec() - t0) / 1000.0]
	for m: Array in made:
		if OS.is_process_running(m[1]):
			OS.kill(m[1])
	return out

func _online_record() -> Vector3i:
	var r := Record.get_record("chess", Record.ONLINE)
	return Vector3i(r.x, r.y, Record.get_draws("chess", Record.ONLINE))

func _conduct() -> void:
	if OS.get_environment("FIREBASE_EMULATOR").is_empty():
		print("FIREBASE_EMULATOR is not set; this probe only ever talks to the emulator")
		quit(2)
		return
	_had = FileAccess.file_exists(CFG)
	if _had:
		_saved = FileAccess.get_file_as_string(CFG)

	print("-- a whole game")
	var before := _online_record()
	var seen: Array = await _pair("game", "game", [0, 1], 420.0)
	var a: Dictionary = seen[0]
	var b: Dictionary = seen[1]
	_check("both processes finished", not a.is_empty() and not b.is_empty(), "%.0f s" % seen[2])
	if not a.is_empty() and not b.is_empty():
		_check("they are two players in one match", a.uid != b.uid and a.opponent == b.uid and b.opponent == a.uid)
		_check("in different seats, the opener white", int(a.seat) + int(b.seat) == 1 \
			and int(a.first) == int(b.first) and bool(a.white) != bool(b.white) \
			and bool(a.white) == (int(a.seat) == int(a.first)))
		_check("each drew the other's name on its scoreboard", a.rival == b.me and b.rival == a.me,
			"%s against %s" % [a.me, b.me])
		_check("one result at both ends", int(a.winner) == int(b.winner) and a.why == b.why,
			"winner seat %d, why %s" % [int(a.winner), a.why])
		var mirror := {"won": "lost", "lost": "won", "draw": "draw"}
		_check("and each end's card agrees with it", mirror.get(a.outcome, "") == b.outcome \
			and (a.outcome == "draw") == (int(a.winner) < 0) \
			and (a.outcome != "won" or int(a.winner) == int(a.seat)),
			"a %s, b %s; status %d, move %d" % [a.outcome, b.outcome, int(a.status), int(a.fullmove)])
		_check("the same final position", a.position == b.position and int(a.plies) == int(b.plies),
			"%s after %d plies" % [a.position, int(a.plies)])
		_check("an en passant, a promotion and two castles travelled",
			int(a.ep) == 1 and int(b.ep) == 1 and int(a.promo) >= 1 and int(b.promo) >= 1 \
			and int(a.castle) >= 2 and int(b.castle) >= 2 and a.specials == b.specials,
			"ep %d, promotions %d, castles %d; b8 was made a %s" % [int(a.ep), int(a.promo), int(a.castle), a.b8])
		_check("undo, reset and the bulb were off", not bool(a.tools) and not bool(b.tools))
		_check("the end card's button is Find another", a.again == b.again and not str(a.again).is_empty(), str(a.again))
		var after := _online_record()
		_say("      record at level 3: won %d lost %d drawn %d -> won %d lost %d drawn %d" % [
			before.x, before.y, before.z, after.x, after.y, after.z])

	print("-- a kill (the other waits about 22 s)")
	before = _online_record()
	seen = await _pair("die", "stay", [1], 120.0)
	b = seen[1]
	_check("the one left alone finished", not b.is_empty(), "%.0f s" % seen[2])
	if not b.is_empty():
		_check("it ended with left, a win", b.why == "left" and b.outcome == "won" and int(b.winner) == int(b.seat),
			"why %s, %s; card says: %s" % [b.why, b.outcome, b.said])
		var after := _online_record()
		_check("and a win was counted at level 3", after == before + Vector3i(1, 0, 0),
			"won %d -> %d" % [before.x, after.x])

	print("-- a resignation")
	seen = await _pair("resign", "stay", [0, 1], 120.0)
	a = seen[0]
	b = seen[1]
	_check("both processes finished", not a.is_empty() and not b.is_empty(), "%.0f s" % seen[2])
	if not a.is_empty() and not b.is_empty():
		_check("Back asked first, and Resign closed the screen", bool(a.asked) and bool(a.closed))
		_check("no end card on the way out", str(a.again).is_empty())
		_check("the other ended with resign, a win", b.why == "resign" and b.outcome == "won" \
			and int(b.winner) == int(b.seat), "card says: %s" % b.said)

	print("-- a foul")
	seen = await _pair("cheat", "stay", [1], 60.0)
	b = seen[1]
	_check("the one fouled finished", not b.is_empty(), "%.0f s" % seen[2])
	if not b.is_empty():
		_check("it ended with left, a win", b.why == "left" and b.outcome == "won", "card says: %s" % b.said)

	print("-- %s" % ("all passed" if _fails == 0 else "%d FAILED" % _fails))
	_restore()
	quit(0 if _fails == 0 else 1)

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
	# load(), not preload: the screen names the Ads autoload, which is not
	# there yet when this script compiles.
	var screen: GDScript = load("res://versus/chess_screen.gd")
	_s = screen.new(Record.ONLINE)
	_s.closed.connect(_on_closed)
	root.add_child(_s)
	_say("%s is looking" % load("res://versus/online/names.gd").name_of(Backend.uid()))

func _sq(n: String) -> int:
	return "abcdefgh".find(n[0]) + (int(n[1]) - 1) * 8

## The move this seat makes now: the line's while it lasts and is legal,
## then the computer's.
func _choose() -> int:
	var g: RefCounted = _s.rules
	var ply: int = _s._history.size()
	if ply < LINE.size():
		var want: Array = LINE[ply]
		for m in g.legal_moves():
			if Rules.mv_from(m) == _sq(want[0]) and Rules.mv_to(m) == _sq(want[1]) \
					and Rules.mv_promo(m) == int(want[2]):
				return m
		_say("the line's ply %d is not legal here" % ply)
	return AI.new().plan(g.copy(), 1 if _s.player == Rules.WHITE else 0, _env("SEED", 1) + ply, 150)

func _drive(real: float) -> void:
	if _reported or not _s.is_inside_tree():
		return
	var st: int = _s._state
	if st != _last_state:
		_last_state = st
		_idle_t = 0.0
	_idle_t += real
	if st == _s.State.OVER:
		# The card, and the match's own word for the result.
		_over_t += real
		if is_instance_valid(_s._end) and (not _s.online.result.is_empty() or _over_t > 8.0):
			_write(false)
		return
	if st == _s.State.YOURS:
		_tools = _tools or _s.can_undo() or _s.can_reset() or _s.hints_left() > 0 or _s.hints_held() > 0
	if st == _s.State.YOURS and not _s.board.is_busy() and not _acted:
		if _mode == "die" and _mine >= 3:
			_say("killing itself")
			OS.kill(OS.get_process_id())
			return
		if (_mode == "resign" and _mine >= 3) or _s.rules.fullmove > LONG:
			_acted = true
			_resign()
			return
		if _mode == "cheat" and _mine >= 3:
			# A king's leap across the board, sent as the screen sends a move.
			_acted = true
			_say("sending a move that is not one")
			_s.online.send({"m": Rules.mv(_s.rules.kings[_s.player], 36)})
			return
		_mine += 1
		_s._on_chosen(_choose())
	elif _idle_t > 150.0 and st != _s.State.WAIT:
		_say("STUCK in state %d" % st)
		_write(false)

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

var _asked := false
var _tools := false

func _on_closed() -> void:
	if _reported:
		return
	_say("the screen closed")
	_write(true)

func _write(closed: bool) -> void:
	if _reported:
		return
	_reported = true
	var g: RefCounted = _s.rules
	var on: Node = _s.online
	var ep := 0
	var promo := 0
	var castle := 0
	var b8 := ""
	var specials: Array = []
	for i in _s._history.size():
		var d: Dictionary = _s._history[i]
		if int(d.rook_from) >= 0:
			castle += 1
			specials.append("%d castle" % i)
		if int(d.promo) != 0:
			promo += 1
			specials.append("%d promo %d" % [i, absi(int(d.promo))])
			if int(d.to) == _sq("b8"):
				b8 = ["", "pawn", "knight", "bishop", "rook", "queen", "king"][absi(int(d.promo))]
		if int(d.captured_at) >= 0 and int(d.captured_at) != int(d.to):
			ep += 1
			specials.append("%d ep" % i)
	var said := ""
	var again := ""
	if is_instance_valid(_s._end):
		for l in _s._end.find_children("*", "Label", true, false):
			if (l as Label).visible and (l as Label).theme_type_variation == "SheetBody":
				said = (l as Label).text
		var buttons: Node = _s._end.find_child("Buttons", true, false)
		if buttons != null:
			again = buttons.get_child(0).label_text
	var saw := {
		"uid": Backend.uid(), "me": load("res://versus/online/names.gd").name_of(Backend.uid()),
		"opponent": on.opponent, "rival": _s._names[1].text,
		"seat": on.seat, "first": on.first, "white": _s.player == Rules.WHITE,
		"winner": int(on.result.get("winner", -9)), "why": str(on.result.get("why", "")),
		"outcome": "lost" if closed else str(_s.board._mood), "status": g.status(), "fullmove": g.fullmove,
		"plies": _s._history.size(),
		"position": ("%s %d %d %d" % [g.board, g.turn, g.castling, g.ep]).md5_text(),
		"ep": ep, "promo": promo, "castle": castle, "b8": b8, "specials": ", ".join(specials),
		"tools": _tools,
		"said": said, "again": again, "asked": _asked, "closed": closed,
	}
	_say("%s by %s (winner seat %d), status %d on move %d, position %s" % [
		saw.outcome, saw.why, saw.winner, saw.status, saw.fullmove, saw.position])
	if closed:
		# As ui/menu.gd does on `closed`: the screen goes at once, and its
		# Match with it. The resignation has to land all the same, so this
		# process gives it a moment before it goes too.
		_s.queue_free()
		_s = null
		await create_timer(1.5, true, false, true).timeout
	var f := FileAccess.open(_file, FileAccess.WRITE)
	f.store_string(JSON.stringify(saw))
	f.close()
	quit(0)
