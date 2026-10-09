extends SceneTree

## Whole games online through the real screen, against the Firebase
## emulators, and PASS or FAIL for each thing seen. Not a test: a probe.
##
##   cd server && PATH="/opt/homebrew/opt/openjdk/bin:$PATH" \
##     firebase emulators:start --only auth,database --project demo-peeplet
##   FIREBASE_EMULATOR=127.0.0.1 FIREBASE_PROJECT=demo-peeplet \
##     godot --headless --path . --script res://tests/_probe_online.gd -- chess
##   (or `-- checkers`, `-- penny`, `-- reversi`, or `-- snooker`)
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
##    and one final position. Checkers' line is seven plies: a capture each
##    way, then a man that takes two in one move and is crowned where it
##    lands, so a chain and a crowning are known to travel in the array.
## 2. **A kill.** One process kills itself (SIGKILL) on its fourth move; the
##    other must end with `left`, a win.
## 3. **A resignation.** One presses Back and the dialog's Resign; the other
##    must end with `resign`, a win, and the resigner's screen must close.
##
## 4. **A foul.** One sends a move no rule allows, past its own screen; the
##    other must walk away with `left`, a win.
##
## **Snooker** (`-- snooker`) is the same four, and what it is really for is
## the first: two phones cannot be trusted to roll a shot alike, so the
## shooter's table is the one that counts, and after EVERY shot both ends must
## hold the same table and the same referee's state. Each seat is played by
## versus/snooker_ai.gd (level 1 against level 0) through the screen's own
## release; each end hashes its table and referee's state (seen from seat 0)
## as every shot settles, and the conductor compares the lists, and prints how
## many shots that was and how far the watcher's own roll had drifted from the
## shooter's before it took theirs. Then **a nudge**: one end moves a ball on
## its own copy a few millimetres (NUDGE, metres, 0.004) before every roll it
## watches, so its roll does differ, and the lists must still agree. The foul
## is tried twice: a shot that is not one, and a table one ball short.
##
## And four more, each a defect a review found (2026-10-04):
##
## 5. **A forged end** (chess, checkers). One plays a move and writes `end`
##    with itself the winner -- the rules take that from whoever moved last --
##    while the game is still on. The other plays the move, sees its own
##    rules say the game is not over, and calls a foul: `left`, a win, and
##    no loss counted.
## 6. **A move inside the found beat.** The seat that opens starts its game
##    the moment it is found (no beat, reduce motion) and moves at once, so
##    its move reaches the other end while that end's found card is still up.
##    The other must play it when its board is laid, and the game go on to a
##    resignation; before the fix it threw the move away and lost on time.
## 7. **Back inside the found beat.** One presses Back the moment it is found:
##    its screen closes; the other goes back to looking with no card; nobody's
##    record moves.
## 8. **An in-off with a ball on the cue ball's spot** (snooker). One end's
##    shot is stopped mid-roll with the cue ball down a pocket and a red
##    standing where the referee puts a cue ball in hand. The table it sends
##    must be one the other end takes (the cue ball seated somewhere free
##    first), every hash agreeing, and the frame go on.
##
## SPEED (Engine.time_scale, 4; snooker 8), SEED. user://versus.cfg is put back by the
## conductor on every way out (the players share it, so they leave it alone).
## Spec: docs/superpowers/specs/2026-10-04-versus-online-design.md, section 5.

const Backend = preload("res://core/backend.gd")
const Rules = preload("res://versus/chess_rules.gd")
const AI = preload("res://versus/chess_ai.gd")
const CkRules = preload("res://versus/checkers_rules.gd")
const CkAI = preload("res://versus/checkers_ai.gd")
const PnRules = preload("res://versus/penny_rules.gd")
const PnAI = preload("res://versus/penny_ai.gd")
const DmRules = preload("res://versus/dominoes_rules.gd")
const RvRules = preload("res://versus/reversi_rules.gd")
const RvAI = preload("res://versus/reversi_ai.gd")
const DmAI = preload("res://versus/dominoes_ai.gd")
const Record = preload("res://versus/versus_record.gd")
const Sim = preload("res://versus/snooker_sim.gd")
const SnAI = preload("res://versus/snooker_ai.gd")

const CFG := "user://versus.cfg"
## The opening both ends play, a ply each in turn: from, to, promotion.
const LINE := [
	["e2", "e4", 0], ["a7", "a6", 0], ["e4", "e5", 0], ["d7", "d5", 0],
	["e5", "d6", 0], ["h7", "h6", 0], ["d6", "c7", 0], ["h6", "h5", 0],
	["c7", "b8", Rules.KNIGHT], ["g7", "g6", 0], ["g1", "f3", 0], ["f8", "g7", 0],
	["f1", "e2", 0], ["g8", "f6", 0], ["e1", "g1", 0], ["e8", "g8", 0],
]
## Checkers' opening, whole moves as the rules make them: [from, n, the
## landings, the pieces taken]. The seventh takes 36 and 50 and is crowned on 57.
const CK_LINE := [
	[18, 1, 25], [43, 1, 34], [25, 1, 43, 34], [50, 1, 36, 43],
	[20, 1, 29], [57, 1, 50], [29, 2, 43, 57, 36, 50],
]
## A game this long is given up by whoever is to move, the real way.
const LONG := 110
## Reversi's opening: eight discs after which the first side has no square,
## so the second moves twice running and the first of those keeps the turn.
const RV_LINE := [44, 45, 26, 52, 60, 59, 46, 61]

## "chess", "checkers", "penny", "dominoes", "reversi" or "snooker".
var _game := "chess"
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
		if args.size() >= 1 and args[0] in ["chess", "checkers", "penny", "dominoes", "reversi", "snooker"]:
			_game = args[0]
		else:
			print("usage: -- chess|checkers|penny|dominoes|reversi|snooker")
			quit(2)
			return false
		# Every mode, the players' too: Backend.start with no emulator named
		# is the live project.
		if OS.get_environment("FIREBASE_EMULATOR").strip_edges().is_empty():
			print("FIREBASE_EMULATOR is not set; this probe only ever talks to the emulator")
			quit(2)
			return false
		if args.size() >= 5 and args[1] == "play":
			_tag = "[%s] " % args[2]
			_file = args[3]
			_mode = args[4]
			_play()
		else:
			_conduct()
		return false
	if _s != null:
		if _game == "snooker":
			_drive_snooker(delta / maxf(Engine.time_scale, 0.01))
		else:
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
		"--script", "res://tests/_probe_online.gd", "--", _game, "play", who, file, mode]
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
	var r := Record.get_record(_game, Record.ONLINE)
	return Vector3i(r.x, r.y, Record.get_draws(_game, Record.ONLINE))

func _conduct() -> void:
	_had = FileAccess.file_exists(CFG)
	if _had:
		_saved = FileAccess.get_file_as_string(CFG)
	if _game == "snooker":
		await _conduct_snooker()
		return

	print("-- a whole game")
	var before := _online_record()
	var seen: Array = await _pair("game", "game", [0, 1], 420.0)
	var a: Dictionary = seen[0]
	var b: Dictionary = seen[1]
	_check("both processes finished", not a.is_empty() and not b.is_empty(), "%.0f s" % seen[2])
	if not a.is_empty() and not b.is_empty():
		_check("they are two players in one match", a.uid != b.uid and a.opponent == b.uid and b.opponent == a.uid)
		_check("in different seats, the opener %s" % {"chess": "white", "checkers": "light", "penny": "dropping first", "dominoes": "leading", "reversi": "moving first"}[_game], int(a.seat) + int(b.seat) == 1 \
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
		if _game == "chess":
			_check("an en passant, a promotion and two castles travelled",
				int(a.ep) == 1 and int(b.ep) == 1 and int(a.promo) >= 1 and int(b.promo) >= 1 \
				and int(a.castle) >= 2 and int(b.castle) >= 2 and a.specials == b.specials,
				"ep %d, promotions %d, castles %d; b8 was made a %s" % [int(a.ep), int(a.promo), int(a.castle), a.b8])
		elif _game == "penny":
			_check("every drop travelled, column by column", a.specials == b.specials and int(a.plies) >= 7,
				"the columns: %s" % str(a.specials))
		elif _game == "reversi":
			_check("every disc travelled, square by square, and a turn kept after the eighth", a.specials == b.specials
				and int(a.plies) >= 9 and str(a.specials).begins_with("44, 45, 26, 52, 60, 59, 46, 61 again, "),
				str(a.specials).left(60))
		elif _game == "dominoes":
			_check("both dealt every hand from the match's seed and laid the same tiles", a.specials == b.specials and int(a.plies) >= 14,
				str(a.specials))
		else:
			_check("a chain and a crowning travelled",
				int(a.chain) >= 1 and int(b.chain) >= 1 and int(a.crown) >= 1 and int(b.crown) >= 1 \
				and a.specials == b.specials and str(a.specials).begins_with("2 take 1, 3 take 1, 6 take 2 crown"),
				"chains %d (the longest took %d), crownings %d, captures %d; the line: %s" % [
					int(a.chain), int(a.longest), int(a.crown), int(a.takes), str(a.specials).left(34)])
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

	print("-- a forged end: a move, and `end` written with the game still on")
	before = _online_record()
	seen = await _pair("cheat_end", "stay", [1], 60.0)
	b = seen[1]
	_check("the one lied to finished", not b.is_empty(), "%.0f s" % seen[2])
	if not b.is_empty():
		_check("its own rules said the game was on, and it called a foul: left, a win",
			b.why == "left" and b.outcome == "won" and int(b.status) == 0,
			"why %s, %s, status %d after %d plies; card says: %s" % [b.why, b.outcome, int(b.status), int(b.plies), b.said])
		var after := _online_record()
		_check("a win was counted and no loss", after == before + Vector3i(1, 0, 0),
			"won %d -> %d, lost %d -> %d" % [before.x, after.x, before.y, after.y])

	await _early_case(180.0)
	await _beat_case()

	print("-- %s" % ("all passed" if _fails == 0 else "%d FAILED" % _fails))
	_restore()
	quit(0 if _fails == 0 else 1)

## A move that reaches the other end inside its found beat is played, not
## thrown away.
func _early_case(deadline: float) -> void:
	print("-- a move inside the found beat")
	var seen: Array = await _pair("early", "early", [0, 1], deadline)
	var a: Dictionary = seen[0]
	var b: Dictionary = seen[1]
	_check("both processes finished", not a.is_empty() and not b.is_empty(), "%.0f s" % seen[2])
	if a.is_empty() or b.is_empty():
		return
	var late: Dictionary = b if int(a.seat) == int(a.first) else a
	var stayed: Dictionary = b if bool(a.closed) else a
	_check("the opener's first move landed while the other's found card was up", int(late.early) >= 1,
		"%d message held until its board was laid" % int(late.early))
	if _game == "snooker":
		_same_shots(a, b)
		_check("and the frame went on to a resignation, not a clock",
			bool(a.closed) != bool(b.closed) and stayed.why == "resign" and stayed.outcome == "won" and int(stayed.shots) >= 6,
			"why %s after %d shots" % [stayed.why, int(stayed.shots)])
	else:
		_check("and the game went on to the opener's resignation, not a clock",
			stayed == late and late.why == "resign" and late.outcome == "won" and int(late.plies) >= 6,
			"why %s after %d plies; card says: %s" % [late.why, int(late.plies), late.said])

## Back inside the found beat: a game that never began. Nothing is counted at
## either end, one closes and the other looks again.
func _beat_case() -> void:
	print("-- Back inside the found beat")
	var before := _online_record()
	var seen: Array = await _pair("beat_quit", "beat_stay", [0, 1], 60.0)
	var a: Dictionary = seen[0]
	var b: Dictionary = seen[1]
	_check("both processes finished", not a.is_empty() and not b.is_empty(), "%.0f s" % seen[2])
	if a.is_empty() or b.is_empty():
		return
	_check("the one who pressed Back closed, with no dialog and no card",
		bool(a.closed) and not bool(a.card) and not bool(a.asked) and int(a.founds) == 1)
	_check("the other was found once and is looking again, with no card",
		int(b.founds) == 1 and bool(b.looking) and not bool(b.card) and not bool(b.settled),
		"state %d" % int(b.state))
	var after := _online_record()
	_check("nobody's record moved", after == before,
		"won %d lost %d drawn %d -> won %d lost %d drawn %d" % [before.x, before.y, before.z, after.x, after.y, after.z])

## Snooker's five: a whole frame, a frame with one end's rolls nudged, a
## kill, a resignation and two fouls.
func _conduct_snooker() -> void:
	print("-- a whole frame")
	var before := _online_record()
	var seen: Array = await _pair("game", "game", [0, 1], 1500.0)
	var a: Dictionary = seen[0]
	var b: Dictionary = seen[1]
	_check("both processes finished", not a.is_empty() and not b.is_empty(), "%.0f s" % seen[2])
	if not a.is_empty() and not b.is_empty():
		_check("they are two players in one match", a.uid != b.uid and a.opponent == b.uid and b.opponent == a.uid)
		_check("in different seats, the opener breaking off", int(a.seat) + int(b.seat) == 1 \
			and int(a.first) == int(b.first) and bool(a.broke) != bool(b.broke) \
			and bool(a.broke) == (int(a.seat) == int(a.first)))
		_check("each drew the other's name on its scoreboard", a.rival == b.me and b.rival == a.me,
			"%s against %s" % [a.me, b.me])
		_same_shots(a, b)
		_check("the frame ended on the table, one result at both ends",
			bool(a.over) and bool(b.over) and int(a.winner) == int(b.winner) and a.why == "end" and b.why == "end",
			"winner seat %d, why %s" % [int(a.winner), a.why])
		_check("and each end's card agrees with it", {"won": "lost", "lost": "won"}.get(a.outcome, "") == b.outcome \
			and (a.outcome == "won") == (int(a.winner) == int(a.seat)) and a.card == a.outcome and b.card == b.outcome \
			and int(a.scores[0]) == int(b.scores[1]) and int(a.scores[1]) == int(b.scores[0]),
			"a %s %d-%d, b %s %d-%d" % [a.outcome, int(a.scores[0]), int(a.scores[1]), b.outcome, int(b.scores[0]), int(b.scores[1])])
		_check("the bulb and reset were off", not bool(a.tools) and not bool(b.tools))
		_check("the end card's button is Find another", a.again == b.again and not str(a.again).is_empty(), str(a.again))
		var after := _online_record()
		_say("      record at level 3: won %d lost %d -> won %d lost %d" % [before.x, before.y, after.x, after.y])

	print("-- a nudge: one end's copy of a ball moved before every roll it watches")
	seen = await _pair("nudge", "stay", [0, 1], 400.0)
	a = seen[0]
	b = seen[1]
	_check("both processes finished", not a.is_empty() and not b.is_empty(), "%.0f s" % seen[2])
	if not a.is_empty() and not b.is_empty():
		_check("the nudged rolls did end somewhere else", int(a.nudges) > 0 and float(a.drift.worst) > 0.0 and int(a.drift.moved) > 0,
			"%d nudges" % int(a.nudges))
		_same_shots(a, b)

	print("-- a kill (the other waits about 22 s)")
	before = _online_record()
	seen = await _pair("die", "stay", [1], 180.0)
	b = seen[1]
	_check("the one left alone finished", not b.is_empty(), "%.0f s" % seen[2])
	if not b.is_empty():
		_check("it ended with left, a win", b.why == "left" and b.outcome == "won" and int(b.winner) == int(b.seat),
			"why %s, %s after %d shots; card says: %s" % [b.why, b.outcome, int(b.shots), b.said])
		var after := _online_record()
		_check("and a win was counted at level 3", after == before + Vector3i(1, 0, 0),
			"won %d -> %d" % [before.x, after.x])

	print("-- a resignation")
	seen = await _pair("resign", "stay", [0, 1], 180.0)
	a = seen[0]
	b = seen[1]
	_check("both processes finished", not a.is_empty() and not b.is_empty(), "%.0f s" % seen[2])
	if not a.is_empty() and not b.is_empty():
		_check("Back asked first, and Resign closed the screen", bool(a.asked) and bool(a.closed))
		_check("no end card on the way out", str(a.again).is_empty())
		_check("the other ended with resign, a win", b.why == "resign" and b.outcome == "won" \
			and int(b.winner) == int(b.seat), "card says: %s" % b.said)

	for mode: String in ["cheat", "cheat_table"]:
		print("-- a foul: %s" % ("a shot that is not one" if mode == "cheat" else "a table one ball short"))
		seen = await _pair(mode, "stay", [1], 120.0)
		b = seen[1]
		_check("the one fouled finished", not b.is_empty(), "%.0f s" % seen[2])
		if not b.is_empty():
			_check("it ended with left, a win", b.why == "left" and b.outcome == "won", "card says: %s" % b.said)

	print("-- an in-off with a ball on the cue ball's spot")
	seen = await _pair("inoff", "stay", [0, 1], 400.0)
	a = seen[0]
	b = seen[1]
	_check("both processes finished", not a.is_empty() and not b.is_empty(), "%.0f s" % seen[2])
	if not a.is_empty() and not b.is_empty():
		_check("the shot went in-off with a red on the spot, and the cue ball was seated clear of it",
			bool(a.inoff) and float(a.red_gap) < 0.0001 and float(a.cue_gap) >= 2.0 * Sim.R and bool(a.cue_free),
			"the red %.1f mm from the spot, the cue ball %.1f mm (a ball is %.1f mm across)" % [
				float(a.red_gap) * 1000.0, float(a.cue_gap) * 1000.0, 2000.0 * Sim.R])
		_same_shots(a, b)
		_check("no foul was called: the frame went on to a resignation",
			bool(a.closed) and b.why == "resign" and b.outcome == "won" and int(b.shots) >= int(a.inoff_shot) + 4,
			"why %s after %d shots (the in-off was shot %d); card says: %s" % [b.why, int(b.shots), int(a.inoff_shot), b.said])

	await _early_case(400.0)
	await _beat_case()

	print("-- %s" % ("all passed" if _fails == 0 else "%d FAILED" % _fails))
	_restore()
	quit(0 if _fails == 0 else 1)

## Both ends' hashes of the table and the referee's state, shot by shot: the
## ones both have must be the same (an end that left early has fewer).
func _same_shots(a: Dictionary, b: Dictionary) -> void:
	var ha: Array = a.hashes
	var hb: Array = b.hashes
	var n := mini(ha.size(), hb.size())
	var bad := -1
	for i in n:
		if ha[i] != hb[i] and bad < 0:
			bad = i
	var whole: bool = ha.size() == hb.size() or not (bool(a.over) and bool(b.over))
	_check("after every shot, one table and one referee's state at both ends", n > 0 and bad < 0 and whole,
		"%d shots compared (a saw %d, b %d)%s" % [n, ha.size(), hb.size(), "" if bad < 0 else "; the first to differ is shot %d" % (bad + 1)])
	for who: Array in [["a", a], ["b", b]]:
		var d: Dictionary = who[1].drift
		_say("      %s watched %d shots; its own roll, before it took the shooter's table: worst %.6f mm off, %d balls slid, %d on one table and off the other" % [
			who[0], int(d.shots), float(d.worst) * 1000.0, int(d.moved), int(d.pots)])

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
	Engine.time_scale = float(_env("SPEED", 8 if _game == "snooker" else 4))
	# load(), not preload: the screen names the Ads autoload, which is not
	# there yet when this script compiles.
	var screen: GDScript = load("res://versus/%s_screen.gd" % _game)
	_s = screen.new(Record.ONLINE)
	_s.closed.connect(_on_closed)
	root.add_child(_s)
	# After Online's own handlers, so these see what it made of each.
	var mt: Node = _s.online._match
	mt.move.connect(func(_d: Dictionary) -> void:
		if not _s.online._begun:
			_early += 1)
	mt.found.connect(_on_found)
	_say("%s is looking" % load("res://versus/online/names.gd").name_of(Backend.uid()))

var _early := 0
var _founds := 0

func _on_found(seat: int, first: int, _seed: int, _opponent: String) -> void:
	_founds += 1
	if _mode == "beat_quit":
		_say("Back, inside the found beat")
		_s._on_back()
	elif _mode == "early" and seat == first:
		# The opener's game starts now -- no beat, nothing dealt in -- so its
		# first move is on its way while the other end's found card is up.
		(func() -> void:
			load("res://core/motion.gd").reduce = true
			_s.online._run += 1
			_s.online._drop_lobby()
			_s.online._begin()).call_deferred()

## Found once, and back to looking under the lobby with no card: what the end
## left in the found beat has come to.
func _beat_watch() -> void:
	if _reported or _founds < 1 or int(_s.online.seat) != -1 or not _s.online.in_lobby():
		return
	_write_beat(false)

func _write_beat(closed: bool) -> void:
	if _reported:
		return
	_reported = true
	var saw := {
		"uid": Backend.uid(), "founds": _founds, "closed": closed, "asked": _s.get_node_or_null("Leave") != null,
		"looking": not closed and _s.online.in_lobby() and int(_s.online.seat) == -1,
		"card": is_instance_valid(_s._end), "settled": bool(_s.online._settled), "state": int(_s._state),
	}
	_say("%s after being found %d time" % ["closed" if closed else "looking again", _founds])
	if closed:
		_s.queue_free()
		_s = null
		await create_timer(1.5, true, false, true).timeout
	var f := FileAccess.open(_file, FileAccess.WRITE)
	f.store_string(JSON.stringify(saw))
	f.close()
	quit(0)

func _sq(n: String) -> int:
	return "abcdefgh".find(n[0]) + (int(n[1]) - 1) * 8

## The move this seat makes now: the line's while it lasts and is legal,
## then the computer's.
func _choose() -> Variant:
	var g: RefCounted = _s.rules
	if _game == "penny":
		return PnAI.new().plan(g.copy(), 1 if _s.player == PnRules.FIRST else 0, _env("SEED", 1) + int(g.ply), 150)
	if _game == "reversi":
		if int(g.ply) < RV_LINE.size() and g.can(RV_LINE[int(g.ply)]):
			return RV_LINE[int(g.ply)]
		return RvAI.new().plan(g.copy(), 1 if _s.player == RvRules.FIRST else 0, _env("SEED", 1) + int(g.ply), 60)
	if _game == "dominoes":
		return DmAI.new().plan(g.view(g.turn), 1 if _s.player == DmRules.FIRST else 0, _env("SEED", 1) + int(g.laid), 60)
	var ply: int = _s._history.size()
	if _game == "checkers":
		if ply < CK_LINE.size():
			var want := PackedInt32Array(CK_LINE[ply])
			for m: PackedInt32Array in g.legal_moves():
				if m == want:
					return m
			_say("the line's ply %d is not legal here" % ply)
		return CkAI.new().plan(g.copy(), 1 if _s.player == CkRules.LIGHT else 0, _env("SEED", 1) + ply, 150)
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
	if _mode == "beat_stay":
		_beat_watch()
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
	if _game == "dominoes" and st == _s.State.YOURS and not _s.board.is_busy() and not _acted and _s.rules.can(DmRules.DRAW):
		# Nothing fits: a tile from the boneyard, as a tap on it takes one.
		_s._on_draw()
		return
	if st == _s.State.YOURS and not _s.board.is_busy() and not _acted:
		if _mode == "die" and _mine >= 3:
			_say("killing itself")
			OS.kill(OS.get_process_id())
			return
		if (_mode == "resign" and _mine >= 3) or (_mode == "early" and _s.online.opens() and _mine >= 3) \
				or _moves() > LONG:
			_acted = true
			_resign()
			return
		if _mode == "cheat" and _mine >= 3:
			# A king's leap across the board, sent as the screen sends a move.
			_acted = true
			_say("sending a move that is not one")
			if _game == "penny":
				# A slot the rack does not have.
				_s.online.send({"m": 9})
			elif _game == "reversi":
				# A square the board does not have.
				_s.online.send({"m": 99})
			elif _game == "dominoes":
				# A tile said to have been drawn while one in hand fits.
				_s.online.send({"d": 1, "m": int(_choose())})
			elif _game == "checkers":
				# A man's leap from one corner to the other.
				_s.online.send({"m": [0, 1, 63]})
			else:
				_s.online.send({"m": Rules.mv(_s.rules.kings[_s.player], 36)})
			return
		if _mode == "cheat_end" and _mine >= 3:
			# A real move, and then the match is told the game ended on the board
			# and this seat won it: the rules take `end` from whoever moved last.
			_acted = true
			_say("playing a move and writing end, won, with the game still on")
			_s.online._settled = true  # this end counts nothing: the record read is the other's
			_s._on_chosen(_choose())
			_s.online._match.end(int(_s.online.seat))
			return
		_mine += 1
		_s._on_chosen(_choose())
	elif _idle_t > 150.0 and st != _s.State.WAIT:
		_say("STUCK in state %d" % st)
		_write(false)

# --- snooker's player ---

var _hashes: Array = []
var _hashed := 0
var _nudges := 0
var _nudged_at := -1
var _sn_rng := RandomNumberGenerator.new()
var _inoff := false
var _inoff_shot := -1
var _inoff_red := -1
var _cue_gap := -1.0
var _red_gap := -1.0
var _cue_free := false

## One table and one referee's state as text, the same at both ends when they
## agree: the referee's seen from seat 0.
func _table_hash() -> String:
	return JSON.stringify([_s.sim.snapshot(), _s.rules.to_dict(int(_s.online.seat) == 1)]).md5_text()

func _drive_snooker(real: float) -> void:
	if _reported or not _s.is_inside_tree():
		return
	if _mode == "beat_stay":
		_beat_watch()
		return
	var st: int = _s._state
	var states: Dictionary = _s.State
	if st != _last_state:
		_last_state = st
		_idle_t = 0.0
	_idle_t += real
	var spot := Sim.D_CENTRE + Vector2(0.0, Sim.D_R * 0.5)
	if _mode == "inoff" and not _inoff and st == states.ROLL and int(_s.rules.turn) == 0 and _mine >= 2:
		# This seat's own shot, stopped where it is: the cue ball down a pocket
		# and a red standing on the spot the referee puts a cue ball in hand.
		var sim: RefCounted = _s.sim
		for id in range(1, Sim.REDS + 1):
			if not sim.on[id] or sim.potted.has(id):
				continue
			var clear := true
			for j in range(1, Sim.COUNT):
				clear = clear and (j == id or not sim.on[j] or sim.pos[j].distance_to(spot) > 2.0 * Sim.R * 1.01)
			if not clear:
				break
			for i in Sim.COUNT:
				sim.vel[i] = Vector2.ZERO
				sim.roll[i] = Vector2.ZERO
				sim.side[i] = 0.0
			sim.pos[id] = spot
			sim.on[Sim.CUE] = false
			if not sim.potted.has(Sim.CUE):
				sim.potted.append(Sim.CUE)
			_inoff = true
			_inoff_red = id
			_inoff_shot = int(_s._shots) + 1
			_say("shot %d stopped: the cue ball in a pocket, red %d on the spot in the D" % [_inoff_shot, id])
			break
	if _inoff and _cue_gap < 0.0 and int(_s._shots) >= _inoff_shot:
		# Judged and sent: where the cue ball in hand was put.
		_cue_gap = _s.sim.pos[Sim.CUE].distance_to(spot)
		_red_gap = _s.sim.pos[_inoff_red].distance_to(spot)
		_cue_free = _s.sim.on[Sim.CUE] and _s.sim.free_at(_s.sim.pos[Sim.CUE], Sim.CUE)
	# Every shot, as it settles at this end: its own once judged, the other
	# player's once their table has been taken.
	if st != states.LOBBY and int(_s._shots) > _hashed:
		_hashed = int(_s._shots)
		_hashes.append(_table_hash())
	if st == states.OVER:
		_over_t += real
		if is_instance_valid(_s._end) and (not _s.online.result.is_empty() or _over_t > 8.0):
			_write_snooker(false)
		return
	if st == states.AI_AIM and _mode == "nudge" and _nudged_at != int(_s._shots):
		# The other player's shot is about to be rolled here: this copy of the
		# table is made wrong first.
		_nudged_at = int(_s._shots)
		var by := float(OS.get_environment("NUDGE")) if OS.has_environment("NUDGE") else 0.004
		for id in range(1, Sim.COUNT):
			var to: Vector2 = _s.sim.pos[id] + Vector2(by, by * 0.75)
			if _s.sim.on[id] and _s.sim.free_at(to, id) and to.x > Sim.R and to.x < Sim.W - Sim.R and to.y > Sim.R:
				_s.sim.pos[id] = to
				_nudges += 1
				break
	if st == states.AIM:
		_tools = _tools or _s.can_reset() or _s.hints_left() > 0 or _s.hints_held() > 0
		if _acted:
			return
		if _mode == "die" and _mine >= 3:
			_say("killing itself")
			OS.kill(OS.get_process_id())
			return
		if (_mode == "resign" and _mine >= 3) or (_mode == "nudge" and int(_s._shots) >= 24) or int(_s._shots) > 400 \
				or (_mode == "early" and int(_s._shots) >= 6) \
				or (_mode == "inoff" and ((_inoff and int(_s._shots) >= _inoff_shot + 4) or int(_s._shots) > 60)):
			_acted = true
			_resign()
			return
		if _mode == "cheat" and _mine >= 3:
			_acted = true
			_say("sending a shot that is not one")
			_s.online.send({"shot": Sim.pack(PackedFloat32Array([0.0, -1.0, 2.0]))}, true)
			return
		if _mode == "cheat_table" and _mine >= 3:
			# A real shot, and then -- before this table has stopped -- a table
			# with a ball missing from it, sent as the screen sends its own.
			_say("sending a table one ball short")
			var flat := PackedFloat32Array()
			for i in Sim.COUNT - 1:
				flat.append_array(PackedFloat32Array([_s.sim.pos[i].x, _s.sim.pos[i].y]))
			_shoot_snooker()
			_acted = true
			_s.online.send({"table": {"p": Sim.pack(flat), "on": (1 << Sim.COUNT) - 1}, "rules": _s.rules.to_dict()}, true)
			return
		_shoot_snooker()
	elif _idle_t > 150.0 and st != states.LOBBY:
		_say("STUCK in state %d" % st)
		_write_snooker(false)

## This seat's shot: the computer's plan, delivered with its arm's wobble, and
## played through the screen's own release (the cue ball put where the plan
## wants it first, as a finger would carry it round the D).
func _shoot_snooker() -> void:
	var lv := 1 if int(_s.online.seat) == 0 else 0
	if _mine == 0:
		_sn_rng.seed = _env("SEED", 1) * 2 + int(_s.online.seat)
	var r: RefCounted = _s.rules
	var state := {"phase": r.phase, "free_ball": r.free_ball, "in_hand": r.in_hand, "break_off": _s._break_off}
	var plan: Dictionary = SnAI.plan(_s.sim, state, lv)
	if plan.is_empty():
		_say("the computer has no shot")
		return
	var shot: Dictionary = SnAI.deliver(plan, lv, _sn_rng)
	if (r.in_hand or _s._break_off) and plan.has("cue_at"):
		_s.sim.pos[Sim.CUE] = plan.cue_at
	_s.table.aim_dir = shot.dir
	_s.spin_pad.set_tip(shot.tip)
	_mine += 1
	_s._on_release(_s._power_for(float(shot.speed)))

func _write_snooker(closed: bool) -> void:
	if _reported:
		return
	_reported = true
	var on: Node = _s.online
	var r: RefCounted = _s.rules
	var said := ""
	var again := ""
	var card := ""
	if is_instance_valid(_s._end):
		for l in _s._end.find_children("*", "Label", true, false):
			var label := l as Label
			if label.visible and label.theme_type_variation == "SheetBody":
				said = label.text
			if label.theme_type_variation == "WellDone":
				card = "won" if label.text == on.head("won") else ("lost" if label.text == on.head("lost") else label.text)
		var buttons: Node = _s._end.find_child("Buttons", true, false)
		if buttons != null:
			again = buttons.get_child(0).label_text
	var winner := int(on.result.get("winner", -9))
	var saw := {
		"uid": Backend.uid(), "me": load("res://versus/online/names.gd").name_of(Backend.uid()),
		"opponent": on.opponent, "rival": _s._names[1].text,
		"seat": on.seat, "first": on.first, "broke": int(_s._breaker) == 0,
		"winner": winner, "why": str(on.result.get("why", "")),
		"outcome": "lost" if closed else ("won" if winner == int(on.seat) else "lost"),
		"card": card, "over": bool(r.over), "scores": [r.scores[0], r.scores[1]],
		"shots": int(_s._shots), "mine": _mine, "hashes": _hashes, "drift": _s.drift, "nudges": _nudges,
		"tools": _tools, "said": said, "again": again, "asked": _asked, "closed": closed,
		"early": _early, "inoff": _inoff, "inoff_shot": _inoff_shot, "cue_gap": _cue_gap, "red_gap": _red_gap,
		"cue_free": _cue_free,
	}
	_say("%s by %s (winner seat %d), %d-%d after %d shots (%d its own), table %s" % [
		saw.outcome, saw.why, winner, int(r.scores[0]), int(r.scores[1]), int(_s._shots), _mine,
		"-" if _hashes.is_empty() else str(_hashes[-1]).left(8)])
	if closed:
		_s.queue_free()
		_s = null
		await create_timer(1.5, true, false, true).timeout
	var f := FileAccess.open(_file, FileAccess.WRITE)
	f.store_string(JSON.stringify(saw))
	f.close()
	quit(0)

## The move number the screen shows.
func _moves() -> int:
	if _game == "dominoes":
		# Tiles laid, four or five hands of them: scaled so LONG still means long.
		return int(_s.rules.laid) / 4
	if _game == "reversi":
		# Discs set down, sixty a game: halved so LONG still means long.
		return int(_s.rules.ply) / 2
	return int(_s.rules.fullmove) if _game == "chess" else int(_s._move_number())

## Back, as the top bar's arrow does it, and then the dialog's Resign.
func _resign() -> void:
	_s._on_back()
	await process_frame
	var ask: Node = _s.get_node_or_null("Leave")
	_asked = ask != null
	if ask == null:
		_say("no dialog came up")
		if _game == "snooker":
			_write_snooker(false)
		else:
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
	if _mode == "beat_quit":
		_write_beat(true)
	elif _game == "snooker":
		_write_snooker(true)
	else:
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
	var chain := 0
	var longest := 0
	var crown := 0
	var takes := 0
	var specials: Array = []
	var flat: bool = _game == "penny" or _game == "dominoes" or _game == "reversi"
	var plies: int = int(g.laid) if _game == "dominoes" else (int(g.ply) if _game == "penny" or _game == "reversi" else _s._history.size())
	if _game == "reversi":
		# Each square, and "again" after one that left the other side none.
		for i in g.history.size():
			var nxt: int = g.history[i + 1][2] if i + 1 < g.history.size() else (g.turn if not g.over else -1)
			specials.append("%d%s" % [int(g.history[i][0]), " again" if nxt == int(g.history[i][2]) else ""])
	if _game == "penny":
		for col in g.history:
			specials.append(str(col))
	if _game == "dominoes":
		specials.append("seed %d, %d hands, %d tiles laid, %d-%d to the opener" % [int(g.deal_seed), int(g.hand_no) + 1,
			int(g.laid), int(g.scores[0]), int(g.scores[1])])
	for i in (0 if flat else plies):
		var d: Dictionary = _s._history[i]
		if _game == "checkers":
			var n: int = (d.caps as Array).size()
			if n == 0 and not bool(d.crown):
				continue
			takes += 1 if n > 0 else 0
			chain += 1 if n >= 2 else 0
			longest = maxi(longest, n)
			crown += 1 if bool(d.crown) else 0
			specials.append("%d%s%s" % [i, " take %d" % n if n > 0 else "", " crown" if bool(d.crown) else ""])
			continue
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
		"seat": on.seat, "first": on.first,
		"white": _s.player == {"chess": Rules.WHITE, "checkers": CkRules.LIGHT, "penny": PnRules.FIRST, "dominoes": DmRules.FIRST, "reversi": RvRules.FIRST}[_game],
		"winner": int(on.result.get("winner", -9)), "why": str(on.result.get("why", "")),
		"outcome": "lost" if closed else str(_s.board._mood), "status": g.status(), "fullmove": _moves(),
		"plies": plies,
		"position": (("%s %d %d %d" % [g.board, g.turn, g.castling, g.ep]) if _game == "chess" \
			else (("%s %d" % [g.cells, g.turn]) if _game == "penny" or _game == "reversi" else (str(g.digest()) if _game == "dominoes" \
			else ("%s %d %d" % [g.board, g.turn, g.quiet])))).md5_text(),
		"chain": chain, "longest": longest, "crown": crown, "takes": takes,
		"ep": ep, "promo": promo, "castle": castle, "b8": b8, "specials": ", ".join(specials),
		"tools": _tools,
		"said": said, "again": again, "asked": _asked, "closed": closed, "early": _early,
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
