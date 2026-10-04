extends SceneTree

## Drives core/social.gd and a friend's game (versus/online/online.gd over
## match.gd) against the Firebase emulators and prints PASS or FAIL for each
## thing it saw. Not a test: a probe, for reading with your eyes.
##
##   cd server && PATH="/opt/homebrew/opt/openjdk/bin:$PATH" \
##     firebase emulators:start --only auth,database --project demo-peeplet
##   FIREBASE_EMULATOR=127.0.0.1 FIREBASE_PROJECT=demo-peeplet \
##     godot --headless --path . --script res://tests/_probe_friends.gd
##
## Run bare, it is the conductor. It checks that an unstarted Social answers
## offline, and what `code_in` takes for a code, and then starts **two more
## processes** of itself (`-- play a|b <result file>`), each with a brand-new
## identity of its own (BACKEND_PLAYER), so they are two players with their
## own friends.cfg. Each wakes Social the way world/main.gd does and plays
## its part; the database is all that passes between them, but for one file:
## the link, which is what a player would have sent by hand.
##
## a makes its code and writes the link. b opens it: both lists and
## `befriended` at both ends, presence both ways. Then a asks b to a game
## four times, each through a real Online on a bare Control (the lobby
## and all, no board): snooker, and b **declines**; checkers, and a takes it
## back (**withdrawn**); chess, and b **accepts** -- six bare moves in turn,
## the last mover says `end`, both settle. Then both press Rematch on the same
## tick of the clock (**matched**: one invite is dropped, the other taken),
## two moves and a resignation. Then b **removes** a: both lists empty, and
## a's next asking is refused by the rules (`unfriend`).
##
## In the middle of the first game the conductor -- a third player, c, who
## opens a's link there and then -- asks a to a game: a is `in_game` and the invite
## must be deleted at once without a word at a's end. (b's very first call
## is `add`, on the frame Backend is started and before it has an identity:
## a cold start from a link.)
##
## user://versus.cfg is put back by the conductor on every way out (the
## players share it and a friend's game counts in the online record).
## Spec: docs/superpowers/specs/2026-10-04-friends-design.md, section 6.

const Backend = preload("res://core/backend.gd")
const Live = preload("res://core/live.gd")
const Social = preload("res://core/social.gd")
const Match = preload("res://versus/online/match.gd")
const Online = preload("res://versus/online/online.gd")
const Lobby = preload("res://versus/online/lobby.gd")
const Names = preload("res://versus/online/names.gd")
const Motion = preload("res://core/motion.gd")

const CFG := "user://versus.cfg"
const LINK := "user://probe_friends_link.txt"
const DEADLINE := 150.0
const MOVES := 6

var _begun := false
var _fails := 0
var _tag := ""
var _had := false
var _saved := ""

func _process(_delta: float) -> bool:
	if not _begun:
		_begun = true
		var args := OS.get_cmdline_user_args()
		# Every mode, the players' too: Backend.start with no emulator named
		# is the live project.
		if OS.get_environment("FIREBASE_EMULATOR").strip_edges().is_empty():
			print("FIREBASE_EMULATOR is not set; this probe only ever talks to the emulator")
			quit(2)
			return false
		if args.size() >= 3 and args[0] == "play":
			_tag = "[%s] " % args[1]
			if args[1] == "a":
				_play_a(args[2])
			else:
				_play_b(args[2])
		else:
			_conduct()
	return false

func _say(text: String) -> void:
	print(_tag + text)

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_fails += 1
	_say("%s  %s%s" % ["PASS" if ok else "FAIL", name, "" if detail.is_empty() else " (%s)" % detail])

## Waits until `cond` answers true; false when `seconds` went by first.
func _until(cond: Callable, seconds: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not await cond.call():
		if Time.get_ticks_msec() - t0 > seconds * 1000.0:
			return false
		await process_frame
	return true

## A new identity: the player's file and its friends.cfg are removed, so
## every run is two strangers.
func _fresh(who: String) -> void:
	var player := "user://probe_friend_%s.cfg" % who
	DirAccess.remove_absolute(ProjectSettings.globalize_path(player))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(player.get_basename() + "_friends.cfg"))
	OS.set_environment("BACKEND_PLAYER", player)

func _wake() -> void:
	var host := Node.new()
	root.add_child(host)
	await Backend.start(host)
	Social.start(host)

# --- the conductor ---

func _spawn(who: String) -> Array:
	var file := ProjectSettings.globalize_path("user://probe_friends_%s.json" % who)
	DirAccess.remove_absolute(file)
	_fresh(who)
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/_probe_friends.gd", "--", "play", who, file]
	return [file, OS.create_process(OS.get_executable_path(), args)]

func _report(file: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(file)) if FileAccess.file_exists(file) else null
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _restore() -> void:
	if _had:
		var f := FileAccess.open(CFG, FileAccess.WRITE)
		f.store_string(_saved)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))

func _conduct() -> void:
	_had = FileAccess.file_exists(CFG)
	if _had:
		_saved = FileAccess.get_file_as_string(CFG)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LINK))

	# Unstarted: offline, and not a byte sent.
	var cold: Dictionary = await Social.add("ABCDEFGH")
	var cold_code: String = await Social.my_code()
	_check("unstarted: add says offline, my_code is empty, nobody is a friend",
		not cold.ok and cold.why == "offline" and cold_code.is_empty() and Social.friends().is_empty() \
		and not Social.started() and not Social.loaded())
	_check("code_in: a link, a url of the game's own, typed text, and what is not a code",
		Social.code_in("https://daily-games-420bf.web.app/f/ABCDEFGH") == "ABCDEFGH" \
		and Social.code_in("peepletdaily://f/XYZ23456?x=1") == "XYZ23456" \
		and Social.code_in(" abcd efgh ") == "ABCDEFGH" \
		and Social.code_in("ABCD-EFGH") == "ABCDEFGH" \
		and Social.code_in("ABCDEFG") == "" and Social.code_in("ABCDEFG1") == "" \
		and Social.code_in("https://example.com/") == "" \
		and Social.link("ABCDEFGH") == "https://daily-games-420bf.web.app/f/ABCDEFGH")

	var a := _spawn("a")
	var b := _spawn("b")

	# The third player: this process, opening a's link as b does.
	_fresh("c")
	await _wake()
	var me := Backend.uid()
	_check("a third player started on the emulator", Social.started() and not me.is_empty(), Names.name_of(me))
	_check("asleep until enabled: no stream", not Social._opened and not Social._enabled)
	# In the middle of a's first game: a friend made, who asks, and is
	# refused at once.
	var playing := await _until(func() -> bool:
		return FileAccess.file_exists(ProjectSettings.globalize_path("user://probe_friends_playing.txt")), 90.0)
	_check("a's first game is on", playing)
	var added: Dictionary = await Social.add(Social.code_in(FileAccess.get_file_as_string(LINK)))
	_check("it opens a's link too", added.ok, str(added))
	var uid_a := str(added.uid)
	var ask := "social/%s/invites/%s" % [uid_a, me]
	var wrote := await Live.write(ask, {"game": "chess", "at": Live.STAMP})
	var went := await _until(func() -> bool:
		var there := await Live.read(ask)
		return there.ok and there.data == null, 6.0)
	_check("an invite to a player in a live game is declined at once", wrote.ok and went)

	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < DEADLINE * 1000.0 \
			and not (FileAccess.file_exists(a[0]) and FileAccess.file_exists(b[0])):
		await create_timer(0.25).timeout
	await create_timer(0.5).timeout
	var ra := _report(a[0])
	var rb := _report(b[0])
	for made in [a, b]:
		if OS.is_process_running(made[1]):
			OS.kill(made[1])
	_check("both processes finished", not ra.is_empty() and not rb.is_empty())
	if not ra.is_empty() and not rb.is_empty():
		_fails += int(ra.fails) + int(rb.fails)
		_check("they are two players, each the other's friend", ra.uid != rb.uid and ra.friend == rb.uid and rb.friend == ra.uid)
		_check("a heard nothing of the third player's invite", int(ra.invited) == 0, "%d" % int(ra.invited))
		_check("the accepted game: one match, different seats, the one who asked is p0",
			ra.id1 == rb.id1 and not str(ra.id1).is_empty() and int(ra.seat1) == 0 and int(rb.seat1) == 1, str(ra.id1))
		_check("its six moves went across in turn", str(ra.got1) != str(rb.got1) \
			and (ra.got1 as Array).size() + (rb.got1 as Array).size() == MOVES,
			"a got %s, b got %s" % [ra.got1, rb.got1])
		_check("both ends settled the same result", ra.end1 != rb.end1 and [ra.end1, rb.end1].has("won/end") \
			and [ra.end1, rb.end1].has("lost/end"), "a %s, b %s" % [ra.end1, rb.end1])
		_check("the rematch: another match, and both in it", ra.id2 == rb.id2 and ra.id2 != ra.id1 \
			and int(ra.seat2) + int(rb.seat2) == 1, str(ra.id2))
		var small: Dictionary = ra if str(ra.uid) < str(rb.uid) else rb
		_check("both asked at once: `matched`, and the smaller uid took the other's invite",
			int(small.matched) >= 1 and int(small.seat2) == 1,
			"a heard matched %d, b %d; the smaller uid sat in seat %d" % [int(ra.matched), int(rb.matched), int(small.seat2)])
		_check("the rematch ended in a resignation both saw", [ra.end2, rb.end2].has("won/resign") \
			and [ra.end2, rb.end2].has("lost/resign"), "a %s, b %s" % [ra.end2, rb.end2])
	print("-- %s" % ("all passed" if _fails == 0 else "%d FAILED" % _fails))
	_restore()
	Backend.stop()
	quit(0 if _fails == 0 else 1)

# --- one player ---

## What each end keeps of its games, and the Online it plays them through.
var _on: Node
var _screen: Control
var _saw := {
	"uid": "", "friend": "", "fails": 0, "invited": 0, "matched": 0,
	"id1": "", "seat1": -1, "got1": [], "end1": "",
	"id2": "", "seat2": -1, "got2": [], "end2": "",
}
var _round := 1
var _closed := false
var _gone := ""

func _write(file: String) -> void:
	_saw.fails = _fails
	var f := FileAccess.open(file, FileAccess.WRITE)
	f.store_string(JSON.stringify(_saw))
	f.close()
	Backend.stop()
	quit(0)

## A real Online on a bare Control: the lobby and all, and no board.
func _online(game: String, friend: String, accept: bool) -> Node:
	if is_instance_valid(_on):
		_on.free()
	if not is_instance_valid(_screen):
		_screen = Control.new()
		root.add_child(_screen)
	_closed = false
	_gone = ""
	Online.with_friend = {"uid": friend, "accept": accept}
	_on = Online.new(_screen, game)
	_on.closed.connect(func() -> void: _closed = true)
	_on.started.connect(_on_started)
	_on.move.connect(_on_move)
	_on.over.connect(_on_over)
	_screen.add_child(_on)
	_on._match.gone.connect(func(why: String) -> void: _gone = why)
	return _on

func _lobby_state() -> int:
	return _on._lobby.state if is_instance_valid(_on) and is_instance_valid(_on._lobby) else Lobby.State.NONE

func _on_started() -> void:
	_saw["id%d" % _round] = _on._match.id
	_saw["seat%d" % _round] = _on.seat
	_say("game %d started: seat %d, %s against %s" % [_round, _on.seat,
		"opening" if _on.opens() else "second", _on.rival()])
	if _on.opens():
		_on.send({"i": 0})

func _on_move(d: Dictionary) -> void:
	var i := int(d.get("i", -1))
	_saw["got%d" % _round].append(i)
	var last := MOVES - 1 if _round == 1 else 1
	if _round == 1:
		# A game that lasts a few seconds, so the third player's invite lands
		# inside it.
		await create_timer(0.6).timeout
	if i < last:
		_on.send({"i": i + 1})
		if i + 1 == last and _round == 1:
			# The last move is this seat's: the game ended on the board.
			_saw.end1 = "won/end"
			_on.settle("won", "", MOVES, true)
	elif _round == 2:
		# The dialog's Resign, without the dialog.
		_saw.end2 = "lost/resign"
		_on.settle("lost", "resign", 2)
		_on._match.resign()

func _on_over(outcome: String, why: String) -> void:
	_saw["end%d" % _round] = "%s/%s" % [outcome, why]
	_on.settle(outcome, why, MOVES)

## Both ends press Rematch on the same tick: the next whole 4 s of the
## wall clock that is at least 1.5 s away (one Mac, one clock).
func _rematch_together() -> void:
	var now := Time.get_unix_time_from_system()
	var at := ceilf((now + 1.5) / 4.0) * 4.0
	await create_timer(at - now).timeout
	_round = 2
	_on.again_button().pressed.emit()

func _common(friend: String) -> void:
	Social.hub().invited.connect(func(_from: String, _game: String) -> void: _saw.invited += 1)
	Social.hub().matched.connect(func(_from: String, _game: String) -> void: _saw.matched += 1)
	_saw.uid = Backend.uid()
	_saw.friend = friend

func _play_a(file: String) -> void:
	Motion.reduce = true
	await _wake()
	var news: Array[String] = []
	Social.hub().befriended.connect(func(uid: String) -> void: news.append(uid))
	var code: String = await Social.my_code()
	var again: String = await Social.my_code()
	_check("a code is made on the first ask, and is the same on the second",
		Social.code_in(code) == code and code.length() == 8 and again == code, code)
	var owner := await Live.read("codes/%s" % code)
	_check("it is this player's on the server", owner.ok and str(owner.data) == Backend.uid())
	_check("asking for it enabled social: the stream is open",
		Social._enabled and await _until(func() -> bool: return Social.loaded(), 5.0))
	var f := FileAccess.open(LINK, FileAccess.WRITE)
	f.store_string(Social.link(code))
	f.close()

	var one := await _until(func() -> bool: return Social.friends().size() == 1, 25.0)
	_check("b opened the link: a friend here too, said once",
		one and news.size() == 1 and Social.friends() == news, str(news.map(Names.name_of)))
	var b: String = news[0] if one else ""
	var here := await _until(func() -> bool:
		await Social.refresh_presence()
		return Social.is_online(b), 8.0)
	_check("presence: the friend is online", here)
	_common(b)

	# 1. declined
	_online("snooker", b, false).open()
	_check("asked: the lobby waits on the friend", _lobby_state() == Lobby.State.WAITING and Social.busy_with == b)
	var said_no := await _until(func() -> bool: return _lobby_state() == Lobby.State.GONE, 12.0)
	_check("declined: the lobby says so and nothing is looked for",
		said_no and _gone == "declined" and _on._match.phase == Match.Phase.IDLE, _gone)

	# 2. withdrawn
	await create_timer(1.0).timeout
	_online("checkers", b, false).open()
	await create_timer(2.5).timeout
	var mine := await Live.read("social/%s/invites/%s" % [b, Backend.uid()])
	_check("the invite is on the server while the lobby waits",
		typeof(mine.data) == TYPE_DICTIONARY and str(mine.data.get("game", "")) == "checkers")
	_on.back()
	await create_timer(0.8).timeout
	mine = await Live.read("social/%s/invites/%s" % [b, Backend.uid()])
	_check("Cancel takes it back", _closed and mine.ok and mine.data == null)
	await create_timer(2.0).timeout

	# 3. accepted, and a whole game
	_online("chess", b, false).open()
	var began := await _until(func() -> bool: return not str(_saw.id1).is_empty(), 20.0)
	_check("accepted: the game started", began and Social.in_game)
	var note := FileAccess.open("user://probe_friends_playing.txt", FileAccess.WRITE)
	note.store_string("1")
	note.close()
	# Held on the board a while, so the third player's invite lands inside it:
	# the opener's first move is out, the rest wait for the reply.
	var ended := await _until(func() -> bool: return not str(_saw.end1).is_empty(), 30.0)
	_check("the game ended", ended, str(_saw.end1))
	_check("no game is on any more", not Social.in_game and Social.busy_with == b)
	await _until(func() -> bool: return _on._match.phase == Match.Phase.OVER, 5.0)

	# 4. both ask at once
	await _rematch_together()
	var again_began := await _until(func() -> bool: return not str(_saw.id2).is_empty(), 25.0)
	_check("rematch: a second game started", again_began)
	ended = await _until(func() -> bool: return not str(_saw.end2).is_empty(), 20.0)
	_check("and ended", ended, str(_saw.end2))

	# 5. removed by b
	var alone := await _until(func() -> bool: return not Social.is_friend(b), 15.0)
	_check("removed: the friend is gone from this list too, and the third player stays",
		alone and Social.friends().size() == 1 and news.size() == 2)
	await _until(func() -> bool: return _on._match.phase != Match.Phase.PLAYING, 5.0)
	_on.again_button().pressed.emit()
	var refused := await _until(func() -> bool: return _lobby_state() == Lobby.State.GONE, 10.0)
	_check("an invite to a player who is no friend is refused by the rules", refused and _gone == "unfriend", _gone)
	await Social.refresh_presence()
	_check("and their presence is closed", not Social.is_online(b))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://probe_friends_playing.txt"))
	_write(file)

func _play_b(file: String) -> void:
	Motion.reduce = true
	var news: Array[String] = []
	var asks: Array[String] = []
	var took_back: Array[String] = []
	Social.hub().befriended.connect(func(uid: String) -> void: news.append(uid))
	Social.hub().invited.connect(func(_from: String, game: String) -> void: asks.append(game))
	Social.hub().withdrawn.connect(func(from: String) -> void: took_back.append(from))
	await _until(func() -> bool: return FileAccess.file_exists(LINK), 20.0)
	await create_timer(0.2).timeout
	var link := FileAccess.get_file_as_string(LINK)
	var code := Social.code_in(link)
	_check("the link holds a code", code.length() == 8, link)
	# A cold start from a link, the way world/main.gd does it: Backend is
	# started and not waited for, and the very first call is add, on the same
	# frame, by a player who has no identity yet. It must wait for one, not
	# answer offline.
	var host := Node.new()
	root.add_child(host)
	Backend.start(host)
	Social.start(host)
	var cold := Backend.uid().is_empty()
	Social.enable()
	var added: Dictionary = await Social.add(code)
	var a := str(added.uid)
	_check("a cold start from a link: add waits for the sign-in and makes the friend",
		cold and added.ok and not Backend.uid().is_empty(), str(added))
	_check("the link is opened: a friend, said once, at once", added.ok and news == [a] \
		and Social.friends() == [a] and Social.is_friend(a), Names.name_of(a))
	var unknown: Dictionary = await Social.add("ZZZZ9999")
	_check("a code nobody has: unknown", not unknown.ok and unknown.why == "unknown", str(unknown))
	var own: String = await Social.my_code()
	var selfish: Dictionary = await Social.add(own)
	_check("this player's own code: self", not selfish.ok and selfish.why == "self", str(selfish))
	var twice: Dictionary = await Social.add(code)
	_check("opened again: already", not twice.ok and twice.why == "already" and twice.uid == a, str(twice))
	await create_timer(1.0).timeout
	_check("the stream brought the same list and said nothing more", Social.loaded() and Social.friends() == [a] and news.size() == 1)
	var theirs := await Live.read("social/%s" % a)
	_check("a friend's social is not this player's to read", not theirs.ok and int(theirs.code) == 401)
	var here := await _until(func() -> bool:
		await Social.refresh_presence()
		return Social.is_online(a), 8.0)
	_check("presence: the friend is online", here)
	_common(a)
	_saw.invited = 0

	# 1. declined
	var asked := await _until(func() -> bool: return asks.has("snooker"), 30.0)
	_check("invited: a fresh invite is said once, with its game", asked and Social.invite_from(a) == "snooker" and asks.size() == 1)
	Social.decline(a)
	_check("declined: it is gone here at once", Social.invite_from(a).is_empty() and took_back == [a])

	# 2. withdrawn
	asked = await _until(func() -> bool: return asks.has("checkers"), 20.0)
	_check("invited again, to another game", asked and Social.invite_from(a) == "checkers")
	var went := await _until(func() -> bool: return took_back.size() == 2, 12.0)
	_check("withdrawn: the one who asked took it back", went and Social.invite_from(a).is_empty())

	# 3. accepted
	asked = await _until(func() -> bool: return asks.has("chess"), 20.0)
	_check("invited a third time", asked and Social.invite_from(a) == "chess")
	_online("chess", a, true).open()
	var began := await _until(func() -> bool: return not str(_saw.id1).is_empty(), 20.0)
	_check("Play: the game started", began and Social.in_game and Social.busy_with == a)
	_check("the invite taken is no longer a question", Social.invite_from(a).is_empty())
	var ended := await _until(func() -> bool: return not str(_saw.end1).is_empty(), 30.0)
	_check("the game ended", ended, str(_saw.end1))
	await _until(func() -> bool: return _on._match.phase == Match.Phase.OVER, 5.0)

	# 4. both ask at once
	await _rematch_together()
	var again_began := await _until(func() -> bool: return not str(_saw.id2).is_empty(), 25.0)
	_check("rematch: a second game started", again_began)
	ended = await _until(func() -> bool: return not str(_saw.end2).is_empty(), 20.0)
	_check("and ended", ended, str(_saw.end2))

	# 5. remove
	await create_timer(1.5).timeout
	var removed: bool = await Social.remove(a)
	_check("removed: the friendship is ended from here", removed and Social.friends().is_empty() and not Social.is_friend(a))
	var before := asks.size()
	await create_timer(6.0).timeout
	_check("and nothing more is heard from them", asks.size() == before)
	_write(file)
