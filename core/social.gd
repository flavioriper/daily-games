extends RefCounted

## Friends: this player's code, who their friends are, who of them is around,
## and who is asking for a game. Static like core/backend.gd and riding on its
## identity; the data is the Realtime Database's (core/live.gd) and the server
## is rules alone (server/database.rules.json).
##
## Woken only by world/main.gd (`Social.start(host)`). Unstarted means
## offline: every call answers as if there were no network and nothing is
## listened to. Started, it still **sleeps until the player has social** --
## they opened the Friends sheet, shared a link or opened someone's
## (`enable()`, kept in user://friends.cfg) -- so a puzzle-only player holds
## no connection.
##
## Awake, it is a **follower of state**, as versus/online/match.gd is: one
## stream on social/{uid} hands the document over whole and then piece by
## piece, this keeps it (`_doc`), applies each event by its path with Match's
## own `_apply`, and after every one says what the document now implies that
## has not been said: a friend more, an invite, an invite gone. A stream that
## drops and comes back sends the whole again, so reconnecting has no code.
##
## `fake()` is a harness's way to a Social that answers from a Dictionary.
## Spec: docs/superpowers/specs/2026-10-04-friends-design.md, sections 1, 2.

const Backend = preload("res://core/backend.gd")
const Live = preload("res://core/live.gd")
const Match = preload("res://versus/online/match.gd")

## What `hub()` is: the node whose signals say what changed. It also holds
## the stream and gives Social its clock.
class Hub extends Node:
	## The friends, their presence or the invites are not what they were.
	signal changed
	## `uid` became a friend after the list was first read.
	signal befriended(uid: String)
	## A friend asks for a game of `game`.
	signal invited(from: String, game: String)
	## That invite is gone, or went stale.
	signal withdrawn(from: String)
	## The friend this player is waiting on has asked them too.
	signal matched(from: String, game: String)

	var stream: Live.Stream
	## The window has the player's eye. A phone in a pocket is not online.
	var focused := true
	# An inner class does not see the outer one's functions.
	var _social: Script

	func _init() -> void:
		name = "Social"
		_social = load("res://core/social.gd")
		stream = Live.Stream.new()
		stream.name = "SocialStream"
		stream.event.connect(func(kind: String, path: String, data: Variant) -> void:
			_social._on_event(kind, path, data))
		add_child(stream)

	func _process(delta: float) -> void:
		_social._tick(delta)

	func _notification(what: int) -> void:
		match what:
			NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
				focused = false
			NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
				if not focused:
					focused = true
					_social._beat()

const SITE := "https://daily-games-420bf.web.app/f/"
const ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const CODE_LEN := 8
const CFG := "user://friends.cfg"
## Presence's heartbeat, and how old one may be for its player to be online.
const BEAT := 20.0
const ONLINE_MS := 50000.0
## An invite's heartbeat is 4 s (Match.TICKET_BEAT). It is fresh under the
## rules' 10 s, and one this stale is deleted by whoever it was sent to.
const FRESH_MS := 10000.0
const STALE_MS := 61000.0
## How often the invites are judged against the clock, and the wait before
## asking again for a token that would not come.
const JUDGE := 1.0
const RETRY := 5.0

## The friend Online is waiting on or playing.
static var busy_with := ""
## A live online game is on.
static var in_game := false

static var _hub: Hub
static var _started := false
static var _faked := false
static var _fake := {}
static var _enabled := false
## The stream has been pointed at this player's document.
static var _opened := false
static var _opening := false
static var _uid := ""
static var _code := ""
## The code in the file has been looked up on the server this session.
static var _code_checked := false
## social/{uid} as last known.
static var _doc: Variant = null
static var _loaded := false
static var _friends: Array[String] = []
## Friends already said, so `befriended` is said once each.
static var _known := {}
## uid -> the server's clock at their last heartbeat, from the last refresh.
static var _presence := {}
static var _online := {}
## from -> game, for every invite that is fresh and has been said.
static var _invites := {}
static var _beat_t := 0.0
static var _judge_t := 0.0
static var _retry_t := 0.0

# --- waking ---

## world/main.gd's, and nobody else's: tests and harnesses stay offline.
static func start(host: Node) -> void:
	if _started or _faked:
		return
	_started = true
	_seat_hub(host)
	_load()
	if _enabled:
		_open()

static func started() -> bool:
	return _started or _faked

## A harness's Social: started, with no network. `state` is {code, friends,
## online, codes: {CODE: uid}, invites: {uid: game}}; the calls answer from
## it, and the harness says the hub's signals itself.
static func fake(state: Dictionary) -> void:
	_faked = true
	_fake = state
	_code = str(state.get("code", ""))
	_friends.clear()
	for u in state.get("friends", []):
		_friends.append(str(u))
	_online = {}
	for u in state.get("online", []):
		_online[str(u)] = true
	_invites = {}
	var asks: Dictionary = state.get("invites", {})
	for u in asks:
		_invites[str(u)] = str(asks[u])
	_loaded = true
	_seat_hub(null)

## The node whose signals say what changed. There from the first ask, so a
## screen can connect before anything is started.
static func hub() -> Node:
	if not is_instance_valid(_hub):
		_hub = Hub.new()
	return _hub

static func _seat_hub(host: Node) -> void:
	var h := hub()
	if h.get_parent() != null:
		return
	if host == null:
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			host = (loop as SceneTree).root
	if host != null:
		host.add_child.call_deferred(h)

## The player has social from now on: the stream opens and presence beats.
static func enable() -> void:
	if not _started or _enabled:
		return
	_enabled = true
	_save()
	_open()

## Where `enabled` and the code are kept. Beside the identity when
## BACKEND_PLAYER names another one, so two processes are two players here
## as well.
static func _cfg_path() -> String:
	var player := OS.get_environment("BACKEND_PLAYER").strip_edges()
	return CFG if player.is_empty() else player.get_basename() + "_friends.cfg"

static func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_cfg_path()) != OK:
		return
	_enabled = bool(cfg.get_value("friends", "enabled", false))
	_code = str(cfg.get_value("friends", "code", ""))
	_uid = str(cfg.get_value("friends", "uid", ""))

static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("friends", "enabled", _enabled)
	cfg.set_value("friends", "code", _code)
	cfg.set_value("friends", "uid", _uid)
	cfg.save(_cfg_path())

## This player's uid, once there is a token; "" offline. A code kept for
## another identity is not this one's.
static func _me() -> String:
	var token := await Backend.token()
	if token.is_empty():
		return ""
	var uid := Backend.uid()
	if uid != _uid:
		if not _uid.is_empty():
			_code = ""
		_uid = uid
		_code_checked = false
		_save()
	return uid

static func _open() -> void:
	if _opened or _opening:
		return
	_opening = true
	var uid := await _me()
	_opening = false
	if uid.is_empty():
		_retry_t = RETRY
		return
	_opened = true
	hub().stream.open("social/%s" % uid)
	_beat()

# --- the code ---

## This player's code, made on the first ask; "" offline. Await it.
static func my_code() -> String:
	if _faked:
		return _code
	if not _started:
		return ""
	enable()
	var uid := await _me()
	if uid.is_empty():
		return ""
	if not _code.is_empty():
		if _code_checked:
			return _code
		# Once a session: is the code in the file still this player's on the
		# server. Offline, it is taken on trust.
		var there := await Live.read("codes/%s" % _code)
		if not there.ok:
			return _code if int(there.code) == 0 else ""
		if there.data == null:
			there = await Live.write("codes/%s" % _code, uid)
		if there.ok and str(there.data) == uid:
			_code_checked = true
			return _code
		_code = ""
	# A code somebody has is refused by the rules, and another is dealt.
	for attempt in 6:
		var code := ""
		for i in CODE_LEN:
			code += ALPHABET[randi() % ALPHABET.length()]
		var res := await Live.write("codes/%s" % code, uid)
		if res.ok:
			_code = code
			_code_checked = true
			_save()
			return _code
		if int(res.code) == 0:
			break
	return ""

static func link(code: String) -> String:
	return SITE + code

## A code out of a link, a peepletdaily:// url or typed text; "" if none.
static func code_in(text: String) -> String:
	var t := text.strip_edges().to_upper()
	var cut := t.rfind("/F/")
	if cut >= 0:
		t = t.substr(cut + 3)
	for stop in ["?", "#", "/"]:
		var at := t.find(stop)
		if at >= 0:
			t = t.substr(0, at)
	var out := ""
	for ch in t:
		if ALPHABET.contains(ch):
			out += ch
		elif ch != " " and ch != "-":
			return ""
	return out if out.length() == CODE_LEN else ""

# --- friends ---

## Makes the owner of `code` a friend, both ways, in one write. Await it:
## {ok, uid, why}, `why` "" | "offline" | "unknown" | "self" | "already".
static func add(code: String) -> Dictionary:
	if _faked:
		return _fake_add(code)
	if not _started:
		return {"ok": false, "uid": "", "why": "offline"}
	enable()
	var me := await _me()
	if me.is_empty():
		return {"ok": false, "uid": "", "why": "offline"}
	var owner := await Live.read("codes/%s" % code)
	if not owner.ok:
		return {"ok": false, "uid": "", "why": "offline" if int(owner.code) == 0 else "unknown"}
	if owner.data == null:
		return {"ok": false, "uid": "", "why": "unknown"}
	var uid := str(owner.data)
	if uid == me:
		return {"ok": false, "uid": "", "why": "self"}
	if _friends.has(uid):
		return {"ok": false, "uid": uid, "why": "already"}
	var res := await Live.patch("", {
		"social/%s/friends/%s" % [uid, me]: {"at": Live.STAMP, "via": code},
		"social/%s/friends/%s" % [me, uid]: {"at": Live.STAMP},
	})
	if not res.ok:
		# The code is theirs and they are not this player: what the rules
		# refuse is a friendship that is already there (the list not read yet).
		return {"ok": false, "uid": uid, "why": "offline" if int(res.code) == 0 else "already"}
	# Said now, not when the stream brings it: a link opened as the game
	# starts lands before the first whole read, and a friend that is in the
	# first read is not news.
	var at := Live.server_now()
	if typeof(res.data) == TYPE_DICTIONARY:
		var mine: Variant = res.data.get("social/%s/friends/%s" % [me, uid])
		if typeof(mine) == TYPE_DICTIONARY:
			at = float(mine.get("at", at))
	_doc = Match._apply(_doc, "put", "/friends/%s" % uid, {"at": at})
	_digest(true)
	return {"ok": true, "uid": uid, "why": ""}

static func _fake_add(code: String) -> Dictionary:
	var codes: Dictionary = _fake.get("codes", {})
	if code == _code:
		return {"ok": false, "uid": "", "why": "self"}
	if not codes.has(code):
		return {"ok": false, "uid": "", "why": "unknown"}
	var uid := str(codes[code])
	if _friends.has(uid):
		return {"ok": false, "uid": uid, "why": "already"}
	_friends.append(uid)
	hub().befriended.emit(uid)
	hub().changed.emit()
	return {"ok": true, "uid": uid, "why": ""}

## Ends the friendship, both halves, and any invite between the two. Await it.
static func remove(uid: String) -> bool:
	if _faked:
		if not _friends.has(uid):
			return false
		_friends.erase(uid)
		_invites.erase(uid)
		hub().changed.emit()
		return true
	if not _started:
		return false
	var me := await _me()
	if me.is_empty():
		return false
	var res := await Live.patch("", {
		"social/%s/friends/%s" % [me, uid]: null,
		"social/%s/friends/%s" % [uid, me]: null,
		"social/%s/invites/%s" % [me, uid]: null,
		"social/%s/invites/%s" % [uid, me]: null,
	})
	if not res.ok:
		return false
	_doc = Match._apply(_doc, "put", "/friends/%s" % uid, null)
	_doc = Match._apply(_doc, "put", "/invites/%s" % uid, null)
	_digest(false)
	return true

## Their uids, the oldest friendship first.
static func friends() -> Array[String]:
	return _friends.duplicate()

static func is_friend(uid: String) -> bool:
	return _friends.has(uid)

## The list has been read at least once.
static func loaded() -> bool:
	return _loaded

# --- presence ---

## Reads every friend's presence. Await it; `changed` if anyone came or went.
static func refresh_presence() -> void:
	if _faked or not _opened or _friends.is_empty():
		return
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	var before := _online_now()
	var left := [_friends.size()]
	for uid in _friends:
		_read_presence(uid, left)
	while left[0] > 0:
		await loop.process_frame
	if _online_now() != before:
		hub().changed.emit()

static func _read_presence(uid: String, left: Array) -> void:
	var res := await Live.read("presence/%s" % uid)
	if res.ok:
		if typeof(res.data) == TYPE_DICTIONARY:
			_presence[uid] = float(res.data.get("at", 0.0))
		else:
			_presence.erase(uid)
	left[0] -= 1

static func _online_now() -> Array:
	var out := []
	for uid in _friends:
		if is_online(uid):
			out.append(uid)
	return out

## From the last refresh: their heartbeat is under 50 s old.
static func is_online(uid: String) -> bool:
	if _faked:
		return _online.has(uid)
	return _presence.has(uid) and Live.server_now() - float(_presence[uid]) < ONLINE_MS

## This player's own heartbeat, and a look at everyone else's.
static func _beat() -> void:
	_beat_t = 0.0
	if not _opened or _uid.is_empty():
		return
	@warning_ignore("return_value_discarded")
	Live.write("presence/%s" % _uid, {"at": Live.STAMP})  # deliberately not awaited
	refresh_presence()

# --- invites ---

## The game a fresh invite from `uid` asks for, or "".
static func invite_from(uid: String) -> String:
	return str(_invites.get(uid, ""))

## Says no to `from`: the invite is deleted, and the one who asked hears it.
static func decline(from: String) -> void:
	var had: bool = _invites.erase(from)
	if not _faked and _opened:
		@warning_ignore("return_value_discarded")
		Live.remove("social/%s/invites/%s" % [_uid, from])  # deliberately not awaited
		_doc = Match._apply(_doc, "put", "/invites/%s" % from, null)
	if had:
		hub().withdrawn.emit(from)
		hub().changed.emit()

# --- following ---

static func _on_event(kind: String, path: String, data: Variant) -> void:
	if kind == "cancel" or not _opened:
		return
	_doc = Match._apply(_doc, kind, path, data)
	_loaded = true
	_digest(false)

## Everything the document implies that has not been said yet. `mine` when
## the change is this player's own write (add): its friend is news even if
## the list has never been read.
static func _digest(mine: bool) -> void:
	var doc: Dictionary = _doc if typeof(_doc) == TYPE_DICTIONARY else {}
	var entries: Variant = doc.get("friends")
	var by_uid: Dictionary = entries if typeof(entries) == TYPE_DICTIONARY else {}
	var list: Array[String] = []
	for uid in by_uid:
		list.append(str(uid))
	list.sort_custom(func(a: String, b: String) -> bool:
		var at_a := _at(by_uid[a])
		var at_b := _at(by_uid[b])
		return at_a < at_b or (at_a == at_b and a < b))
	var news: Array[String] = []
	for uid in list:
		if not _known.has(uid):
			_known[uid] = true
			# Before the first whole read nothing is news but what this player
			# has just done.
			if _loaded or mine:
				news.append(uid)
	for uid in _known.keys():
		if not by_uid.has(uid):
			_known.erase(uid)
			_presence.erase(uid)
	var moved := list != _friends
	_friends = list
	for uid in news:
		hub().befriended.emit(uid)
	if _judge() or moved:
		hub().changed.emit()
	if not news.is_empty():
		refresh_presence()

static func _at(entry: Variant) -> float:
	return float(entry.get("at", 0.0)) if typeof(entry) == TYPE_DICTIONARY else 0.0

## The invites against the clock: which are fresh now, said once each as
## they come and once as they go. True when anything was said.
static func _judge() -> bool:
	var doc: Dictionary = _doc if typeof(_doc) == TYPE_DICTIONARY else {}
	var entries: Variant = doc.get("invites")
	var asks: Dictionary = entries if typeof(entries) == TYPE_DICTIONARY else {}
	var now := Live.server_now()
	var said := false
	var fresh := {}
	for from in asks:
		var ask: Variant = asks[from]
		if typeof(ask) != TYPE_DICTIONARY:
			continue
		var age := now - float(ask.get("at", 0.0))
		# One left behind by a game that crashed. Only on the server's own
		# clock: this device's may be an hour out.
		if age > STALE_MS and Live.clocked():
			@warning_ignore("return_value_discarded")
			Live.remove("social/%s/invites/%s" % [_uid, from])  # deliberately not awaited
			_doc = Match._apply(_doc, "put", "/invites/%s" % from, null)
			continue
		# One with `match` on it has been taken: it is a game, not a question.
		if age < FRESH_MS and not ask.has("match") and _friends.has(str(from)):
			fresh[str(from)] = str(ask.get("game", ""))
	for from in _invites.keys():
		if not fresh.has(from) or fresh[from] != _invites[from]:
			_invites.erase(from)
			hub().withdrawn.emit(from)
			said = true
	for from in fresh:
		if _invites.has(from):
			continue
		if in_game:
			# In the middle of a live game: no, at once, so the one asking is
			# not left waiting on a card nobody will see.
			@warning_ignore("return_value_discarded")
			Live.remove("social/%s/invites/%s" % [_uid, from])  # deliberately not awaited
			_doc = Match._apply(_doc, "put", "/invites/%s" % from, null)
			continue
		_invites[from] = fresh[from]
		said = true
		if busy_with == from:
			hub().matched.emit(from, fresh[from])
		else:
			hub().invited.emit(from, fresh[from])
	return said

static func _tick(delta: float) -> void:
	if not _enabled or _faked:
		return
	if not _opened:
		_retry_t -= delta
		if _retry_t <= 0.0 and not _opening:
			_retry_t = RETRY
			_open()
		return
	_judge_t += delta
	if _judge_t >= JUDGE:
		_judge_t = 0.0
		if _judge():
			hub().changed.emit()
	_beat_t += delta
	if _beat_t >= BEAT and hub().focused:
		_beat()
