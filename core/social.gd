extends RefCounted

## Friends: this player's code, who their friends are, who of them is around,
## and who is asking for a game. Static like core/backend.gd and riding on its
## identity; the data is the Realtime Database's (core/live.gd) and the server
## is rules alone (server/database.rules.json).
##
## Unstarted means offline: every call answers as if there were no network
## and nothing is listened to. `fake()` is a harness's way to a Social that
## answers from a Dictionary.
## Spec: docs/superpowers/specs/2026-10-04-friends-design.md, section 2.

const Backend = preload("res://core/backend.gd")
const Live = preload("res://core/live.gd")

## What `hub()` is: the node whose signals say what changed.
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

const SITE := "https://daily-games-420bf.web.app/f/"
const ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const CODE_LEN := 8

## The friend Online is waiting on or playing.
static var busy_with := ""
## A live online game is on.
static var in_game := false

static var _hub: Hub
static var _started := false
static var _faked := false
static var _fake := {}
static var _code := ""
static var _friends: Array[String] = []
static var _online := {}
static var _invites := {}
static var _loaded := false

static func start(_host: Node) -> void:
	pass

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

## The node whose signals say what changed. There from the first ask.
static func hub() -> Node:
	if not is_instance_valid(_hub):
		_hub = Hub.new()
		_hub.name = "Social"
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

static func enable() -> void:
	pass

static func my_code() -> String:
	return _code

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

static func add(code: String) -> Dictionary:
	if not _faked:
		return {"ok": false, "uid": "", "why": "offline"}
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

static func remove(uid: String) -> bool:
	if not _faked or not _friends.has(uid):
		return false
	_friends.erase(uid)
	_invites.erase(uid)
	hub().changed.emit()
	return true

static func friends() -> Array[String]:
	return _friends.duplicate()

static func is_friend(uid: String) -> bool:
	return _friends.has(uid)

static func loaded() -> bool:
	return _loaded

static func refresh_presence() -> void:
	pass

static func is_online(uid: String) -> bool:
	return _online.has(uid)

static func invite_from(uid: String) -> String:
	return str(_invites.get(uid, ""))

static func decline(from: String) -> void:
	if _invites.erase(from):
		hub().changed.emit()
