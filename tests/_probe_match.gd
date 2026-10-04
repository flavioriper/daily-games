extends SceneTree

## Drives versus/online/match.gd against the Firebase emulators and prints
## PASS or FAIL for each thing it saw. Not a test: a probe, for reading with
## your eyes. No game is played -- the moves are bare dictionaries.
##
##   cd server && PATH="/opt/homebrew/opt/openjdk/bin:$PATH" \
##     firebase emulators:start --only auth,database --project demo-peeplet
##   FIREBASE_EMULATOR=127.0.0.1 FIREBASE_PROJECT=demo-peeplet \
##     godot --headless --path . --script res://tests/_probe_match.gd
##
## Run bare, it is the conductor. It checks that an unstarted Backend answers
## `offline` with no network, that a lone seeker hears `nobody` after `wait`
## and leaves no ticket behind, and then starts **two more processes** of
## itself (`-- play a|b <result file>`), each with its own BACKEND_PLAYER, so
## they are two players. Those two seek chess, find each other, trade ten
## moves in turn, the seat that opened resigns, and each writes what it saw
## to its file; the conductor reads both and compares. The seat that did not
## open cuts its own stream the moment move 2 arrives and answers at once, so
## move 4 is made while it is not listening: it has to turn up anyway.
##
## With `-- clocks` after the script it goes on to the three clocks Match
## claims on, waited out for real (about 65 s), each against one more process
## that seeks and then only sits (`-- sit <who> <file> <game>`): a ticket
## whose owner never shows is **void** and the claimer looks again; a player
## whose heartbeat stops has **left**; a seat that does not move in 60 s
## loses on **timeout**.
## Spec: docs/superpowers/specs/2026-10-04-versus-online-design.md, section 5.

const Backend = preload("res://core/backend.gd")
const Live = preload("res://core/live.gd")
const Match = preload("res://versus/online/match.gd")
const Names = preload("res://versus/online/names.gd")

const MOVES := 10
const DEADLINE := 60.0

var _begun := false
var _fails := 0
var _tag := ""

func _process(_delta: float) -> bool:
	if not _begun:
		_begun = true
		var args := OS.get_cmdline_user_args()
		if args.size() >= 3 and args[0] == "play":
			_tag = "[%s] " % args[1]
			_play(args[1], args[2], "chess", true)
		elif args.size() >= 4 and args[0] == "sit":
			_tag = "[%s] " % args[1]
			_play(args[1], args[2], args[3], false)
		else:
			_conduct(args.has("clocks"))
	return false

func _say(text: String) -> void:
	print(_tag + text)

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_fails += 1
	_say("%s  %s%s" % ["PASS" if ok else "FAIL", name, "" if detail.is_empty() else " (%s)" % detail])

func _new_match() -> Match:
	var m: Match = Match.new()
	root.add_child(m)
	return m

# --- the conductor ---

func _spawn(mode: String, who: String, game := "") -> Array:
	var file := ProjectSettings.globalize_path("user://probe_match_%s.json" % who)
	DirAccess.remove_absolute(file)
	OS.set_environment("BACKEND_PLAYER", "user://probe_player_%s.cfg" % who)
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/_probe_match.gd", "--", mode, who, file]
	if not game.is_empty():
		args.append(game)
	return [file, OS.create_process(OS.get_executable_path(), args)]

func _report(file: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(file)) if FileAccess.file_exists(file) else null
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _conduct(clocks: bool) -> void:
	if OS.get_environment("FIREBASE_EMULATOR").is_empty():
		print("FIREBASE_EMULATOR is not set; this probe only ever talks to the emulator")
		quit(2)
		return
	# Unstarted: offline, and not a byte sent.
	var cold := _new_match()
	var heard := [false]
	cold.offline.connect(func() -> void: heard[0] = true)
	cold.seek("chess")
	var none := await Live.read("queue/chess")
	await process_frame
	await process_frame
	_check("unstarted: seek says offline", heard[0])
	_check("unstarted: Live answers {ok=false, code=0}", not none.ok and int(none.code) == 0)
	cold.free()

	OS.set_environment("BACKEND_PLAYER", "user://probe_player_lone.cfg")
	var host := Node.new()
	root.add_child(host)
	await Backend.start(host)
	_check("backend started on the emulator", Backend.started() and not Backend.uid().is_empty(), Backend.uid())
	_say("      this player is %s" % Names.name_of(Backend.uid()))

	# A lone seeker, in a queue nobody else is in.
	var lone := _new_match()
	lone.wait = 4.0
	var said := [false, false]
	lone.nobody.connect(func() -> void: said[0] = true)
	lone.found.connect(func(_s: int, _f: int, _d: int, _o: String) -> void: said[1] = true)
	var t0 := Time.get_ticks_msec()
	lone.seek("snooker")
	while not said[0] and Time.get_ticks_msec() - t0 < 8000:
		await process_frame
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	_check("a lone seeker hears nobody after wait", said[0] and not said[1] and took >= 3.9, "%.1f s, wait 4" % took)
	var ticket := await Live.read("queue/snooker/%s" % Backend.uid())
	_check("its ticket is in the queue while it looks",
		ticket.ok and typeof(ticket.data) == TYPE_DICTIONARY and not ticket.data.has("match"))
	_check("the server's clock was read off the ticket", Live.clocked())
	lone.cancel()
	await create_timer(0.6).timeout
	ticket = await Live.read("queue/snooker/%s" % Backend.uid())
	_check("cancel takes the ticket out", ticket.ok and ticket.data == null)
	lone.free()

	# Two players, two processes.
	var files: Array[String] = []
	var pids: Array[int] = []
	for who in ["a", "b"]:
		var made := _spawn("play", who)
		files.append(made[0])
		pids.append(made[1])
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < DEADLINE * 1000.0 \
			and not (FileAccess.file_exists(files[0]) and FileAccess.file_exists(files[1])):
		await create_timer(0.25).timeout
	await create_timer(0.5).timeout
	var seen: Array = [_report(files[0]), _report(files[1])]
	for pid in pids:
		if OS.is_process_running(pid):
			OS.kill(pid)
	var a: Dictionary = seen[0]
	var b: Dictionary = seen[1]
	_check("both processes finished", not a.is_empty() and not b.is_empty())
	if not a.is_empty() and not b.is_empty():
		_check("they are two players", a.uid != b.uid and a.opponent == b.uid and b.opponent == a.uid)
		_check("in one match", a.id == b.id and not str(a.id).is_empty(), str(a.id))
		_check("in different seats", int(a.seat) + int(b.seat) == 1)
		_check("agreed on who opens and on the seed", int(a.first) == int(b.first) and int(a.seed) == int(b.seed),
			"first %d, seed %d" % [int(a.first), int(a.seed)])
		var opener: Dictionary = a if int(a.seat) == int(a.first) else b
		var other: Dictionary = b if opener == a else a
		_check("the opener sent 0 2 4 6 8 and got 1 3 5 7 9",
			str(opener.sent) == str([0, 2, 4, 6, 8].map(func(i: int) -> float: return float(i))) \
			and str(opener.got) == str([1, 3, 5, 7, 9].map(func(i: int) -> float: return float(i))),
			"sent %s got %s" % [opener.sent, opener.got])
		_check("the other got 0 2 4 6 8 across a dropped stream",
			str(other.got) == str([0, 2, 4, 6, 8].map(func(i: int) -> float: return float(i))) \
			and int(other.drops) >= 1 and int(other.opens) >= 2,
			"got %s, %d drop, %d opens" % [other.got, int(other.drops), int(other.opens)])
		_check("move 4 was made while it was not listening", int(other.reopened_at_n) >= 5,
			"the stream reopened on a match of %d moves" % int(other.reopened_at_n))
		_check("both saw the same result", int(a.winner) == int(b.winner) and a.why == b.why,
			"winner seat %d, why %s" % [int(a.winner), a.why])
		_check("the opener resigned and the other won",
			a.why == "resign" and int(a.winner) == int(other.seat))
		_check("both heard the clock", int(a.clocks) > 0 and int(b.clocks) > 0)
	if clocks:
		await _clocks()
	print("-- %s" % ("all passed" if _fails == 0 else "%d FAILED" % _fails))
	Backend.stop()
	quit(0 if _fails == 0 else 1)

## The three clocks, side by side in three queues, this process the bad
## opponent in each.
func _clocks() -> void:
	var me := Backend.uid()
	print("-- the clocks (about 65 s)")
	# void: a bare ticket in chess, with nobody behind it.
	await Live.write("queue/chess/%s" % me, {"since": Live.STAMP, "at": Live.STAMP})
	var c := _spawn("sit", "c", "chess")
	# left: found in snooker, then silence without a word.
	var goner := _new_match()
	goner.seek("snooker")
	var d := _spawn("sit", "d", "snooker")
	# timeout: found in checkers, heartbeat kept up, never a move from either.
	var idler := _new_match()
	var idle := {"winner": -9, "why": "", "seat": -1}
	idler.found.connect(func(seat: int, _f: int, _s: int, _o: String) -> void: idle.seat = seat)
	idler.ended.connect(func(winner: int, why: String) -> void:
		idle.winner = winner
		idle.why = why)
	idler.seek("checkers")
	var e := _spawn("sit", "e", "checkers")

	var t0 := Time.get_ticks_msec()
	var void_id := ""
	while Time.get_ticks_msec() - t0 < 12000 and void_id.is_empty():
		await create_timer(0.5).timeout
		var mine := await Live.read("queue/chess/%s" % me)
		if typeof(mine.data) == TYPE_DICTIONARY and mine.data.has("match"):
			void_id = str(mine.data.match)
	_check("void: the bare ticket was claimed", not void_id.is_empty(), void_id)
	while Time.get_ticks_msec() - t0 < 12000 and goner.phase != Match.Phase.PLAYING:
		await process_frame
	_check("left: found, and now silent", goner.phase == Match.Phase.PLAYING)
	goner._stop()  # no resign, no heartbeat: a phone that died
	var left_at := Time.get_ticks_msec()

	await create_timer(16.0).timeout
	var voided := await Live.read("matches/%s/result" % void_id)
	_check("void: the claimer voided the match", typeof(voided.data) == TYPE_DICTIONARY 		and str(voided.data.get("why", "")) == "void", str(voided.data))
	var queue := await Live.read("queue/chess")
	var back := 0
	if typeof(queue.data) == TYPE_DICTIONARY:
		for u in queue.data:
			if str(u) != me and not queue.data[u].has("match") 					and Live.server_now() - float(queue.data[u].get("at", 0.0)) < 6000.0:
				back += 1
	_check("void: and is looking again", back == 1, "%d fresh ticket in the queue" % back)
	OS.kill(c[1])

	while Time.get_ticks_msec() - left_at < 30000 and not FileAccess.file_exists(d[0]):
		await create_timer(0.5).timeout
	var left_took := (Time.get_ticks_msec() - left_at) / 1000.0
	await create_timer(0.3).timeout
	var dr := _report(d[0])
	_check("left: the one still there won", str(dr.get("why", "")) == "left" 		and int(dr.get("winner", -9)) == int(dr.get("seat", -1)) and left_took > 15.0,
		"why %s after %.1f s" % [dr.get("why", "?"), left_took])

	while Time.get_ticks_msec() - t0 < 75000 and not FileAccess.file_exists(e[0]):
		await create_timer(0.5).timeout
	var out_took := (Time.get_ticks_msec() - t0) / 1000.0
	await create_timer(1.0).timeout
	var er := _report(e[0])
	_check("timeout: the seat that was not to move won", str(er.get("why", "")) == "timeout" 		and int(er.get("winner", -9)) != int(er.get("first", -9)) and out_took > 55.0,
		"why %s, winner seat %d, first %d, after %.1f s" % [er.get("why", "?"), int(er.get("winner", -9)), int(er.get("first", -9)), out_took])
	_check("timeout: both ends saw it", idle.why == "timeout" and int(er.get("winner", -9)) == int(idle.winner),
		"this end: winner seat %d, why %s" % [int(idle.winner), idle.why])
	for made in [d, e]:
		if OS.is_process_running(made[1]):
			OS.kill(made[1])
	idler.free()
	goner.free()

# --- one player ---

func _play(who: String, file: String, game: String, moving: bool) -> void:
	var host := Node.new()
	root.add_child(host)
	await Backend.start(host)
	var m := _new_match()
	var saw := {
		"uid": Backend.uid(), "id": "", "seat": -1, "first": -1, "seed": -1, "opponent": "",
		"sent": [], "got": [], "winner": -9, "why": "", "drops": 0, "opens": 0, "clocks": 0,
		"reopened_at_n": -1,
	}
	var push := func(i: int) -> void:
		saw.sent.append(i)
		m.send({"i": i, "by": who}, 1 - m.seat)
	m.offline.connect(func() -> void: _say("offline"))
	m.nobody.connect(func() -> void: _say("nobody yet"))
	m.clock.connect(func(_seat: int, _left: int) -> void: saw.clocks += 1)
	m._stream.dropped.connect(func() -> void:
		saw.drops += 1
		_say("stream dropped"))
	# Connected after Match's own handler, so this reads what the stream said
	# on reopening: the whole match, and how many moves were in it by then.
	m._stream.event.connect(func(kind: String, path: String, data: Variant) -> void:
		if saw.drops > 0 and saw.reopened_at_n < 0 and kind == "put" and path == "/" \
				and typeof(data) == TYPE_DICTIONARY:
			saw.reopened_at_n = int(data.get("n", 0)))
	m.found.connect(func(seat: int, first: int, game_seed: int, opponent: String) -> void:
		saw.id = m.id
		saw.seat = seat
		saw.first = first
		saw.seed = game_seed
		saw.opponent = opponent
		_say("found: seat %d, first %d, seed %d, against %s" % [seat, first, game_seed, Names.name_of(opponent)])
		if moving and seat == first:
			push.call(0))
	m.move.connect(func(d: Dictionary) -> void:
		var i := int(d.get("i", -1))
		saw.got.append(i)
		_say("move %d from %s" % [i, d.get("by", "?")])
		if i == 2:
			m._stream.drop()  # and the answer goes out with nobody listening
		if i + 1 < MOVES:
			push.call(i + 1)
		else:
			m.resign())
	m.ended.connect(func(winner: int, why: String) -> void:
		saw.winner = winner
		saw.why = why
		saw.opens = m._stream.opens
		_say("ended: winner seat %d, why %s" % [winner, why])
		var f := FileAccess.open(file, FileAccess.WRITE)
		f.store_string(JSON.stringify(saw))
		f.close()
		quit(0))
	m.seek(game)
