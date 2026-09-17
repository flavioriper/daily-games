extends RefCounted

## The game's one way to the backend: an anonymous identity, the day's
## content, the crowd's tally and a player's submit. Modelled on
## core/analytics.gd -- static, woken by world/main.gd and nobody else.
##
## Unstarted means offline. Every call then answers from the cache on disk or
## from content bundled in res://, so the suite and the harnesses build these
## same screens without ever reaching the network. That is why this is not an
## autoload, exactly as with Analytics.
##
## Nothing here ever blocks a frame, and in particular nothing blocks Lock:
## a turn grades against whatever is in hand and the crowd number catches up
## on the next read.
## Spec: docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md,
## section 3.

const PROJECT := "peeplet-daily"
## A public client key, the same kind that sits in every Firebase web app.
const API_KEY := "PASTE_WEB_API_KEY_HERE"
const REGION := "us-central1"

const CACHE_DIR := "user://backend_cache"
const PLAYER_PATH := "user://player.cfg"
const QUEUE_PATH := "user://backend_queue.json"
const TIMEOUT := 5.0
## Renew the id token when less than this is left on it.
const RENEW_MARGIN := 300.0
## Content bundled with the game, so a phone that has never been online plays.
const BUNDLED := "res://content/%s.json"

static var _node: Node = null
static var _uid := ""
static var _refresh_token := ""
static var _id_token := ""
static var _expires_at := 0.0
## Set from FIREBASE_EMULATOR ("127.0.0.1") to point every host at the suite.
static var _emulator := ""
## True while a sign-up or a refresh is in flight. world/main.gd starts the
## backend without awaiting it -- boot must not block -- so the menu is
## interactive while the first launch is still signing up, and opening a turn
## card inside that window used to sign up a *second* time: two anonymous
## uids, _save_player keeping whichever landed last, and a submit recorded
## against the other. That uid is the identity a leaderboard and a later
## account upgrade are rooted in, so the second caller waits for the first.
static var _signing_in := false

# --- lifecycle ---

## Wakes the backend under `host`, which must be in the tree. Signs in,
## flushes anything the last run could not send, and warms the cache.
static func start(host: Node) -> void:
	if started():
		return
	_emulator = OS.get_environment("FIREBASE_EMULATOR").strip_edges()
	var n := Node.new()
	n.name = "Backend"
	host.add_child(n)
	_node = n
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	_load_player()
	if await _ensure_token():
		await _flush_queue()

static func started() -> bool:
	return _node != null and is_instance_valid(_node)

## Silences the backend again. Harnesses that build the real main scene call
## this so a probe run never submits.
static func stop() -> void:
	if started():
		_node.queue_free()
	_node = null
	_id_token = ""
	_expires_at = 0.0
	# A sign-up in flight dies with the node its request hung off, and its
	# coroutine never resumes to clear this; leaving it set would make every
	# later caller wait out the deadline for nothing.
	_signing_in = false

static func uid() -> String:
	return _uid

# --- hosts ---

## The project the URLs address. An environment override exists so the probe
## can point at the emulator suite, which runs under a demo- project id.
static func _project() -> String:
	var from_env := OS.get_environment("FIREBASE_PROJECT").strip_edges()
	return from_env if not from_env.is_empty() else PROJECT

static func _host(which: String) -> String:
	if _emulator.is_empty():
		match which:
			"firestore": return "https://firestore.googleapis.com/v1"
			"identity": return "https://identitytoolkit.googleapis.com/v1"
			"securetoken": return "https://securetoken.googleapis.com/v1"
			"functions": return "https://%s-%s.cloudfunctions.net" % [REGION, _project()]
	else:
		match which:
			"firestore": return "http://%s:8080/v1" % _emulator
			"identity": return "http://%s:9099/identitytoolkit.googleapis.com/v1" % _emulator
			"securetoken": return "http://%s:9099/securetoken.googleapis.com/v1" % _emulator
			"functions": return "http://%s:5001/%s/%s" % [_emulator, _project(), REGION]
	return ""

static func _docs() -> String:
	return "%s/projects/%s/databases/(default)/documents" % [_host("firestore"), _project()]

# --- identity ---

static func _load_player() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PLAYER_PATH)  # a missing file is fine
	_uid = str(cfg.get_value("player", "uid", ""))
	_refresh_token = str(cfg.get_value("player", "refresh_token", ""))

static func _save_player() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PLAYER_PATH)
	cfg.set_value("player", "uid", _uid)
	cfg.set_value("player", "refresh_token", _refresh_token)
	cfg.save(PLAYER_PATH)

## A live id token, signing up or refreshing as needed. False means the game
## runs offline this launch and tries again on the next.
static func _ensure_token() -> bool:
	if not _id_token.is_empty() and Time.get_unix_time_from_system() < _expires_at - RENEW_MARGIN:
		return true
	if _signing_in:
		return await _wait_for_sign_in()
	_signing_in = true
	var ok := false
	if not _refresh_token.is_empty():
		ok = await _refresh()
	if not ok:
		ok = await _sign_up()
	_signing_in = false
	return ok

## Waits out the sign-in another caller already started, rather than starting
## a second one. The deadline covers the case where that caller's coroutine
## died with its node: two round trips is the longest an honest sign-in can
## take (a refresh that fails, then a sign-up).
static func _wait_for_sign_in() -> bool:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var deadline := Time.get_unix_time_from_system() + 2.0 * TIMEOUT
		while _signing_in and Time.get_unix_time_from_system() < deadline:
			await (loop as SceneTree).process_frame
	return not _id_token.is_empty()

static func _sign_up() -> bool:
	var res := await _http("%s/accounts:signUp?key=%s" % [_host("identity"), API_KEY],
		HTTPClient.METHOD_POST, ["Content-Type: application/json"],
		JSON.stringify({"returnSecureToken": true}))
	var d = JSON.parse_string(str(res.body))
	if not res.ok or typeof(d) != TYPE_DICTIONARY:
		return false
	_uid = str(d.get("localId", ""))
	_refresh_token = str(d.get("refreshToken", ""))
	_id_token = str(d.get("idToken", ""))
	_expires_at = Time.get_unix_time_from_system() + float(str(d.get("expiresIn", "3600")))
	_save_player()
	return not _uid.is_empty()

static func _refresh() -> bool:
	var body := "grant_type=refresh_token&refresh_token=%s" % _refresh_token.uri_encode()
	var res := await _http("%s/token?key=%s" % [_host("securetoken"), API_KEY],
		HTTPClient.METHOD_POST,
		["Content-Type: application/x-www-form-urlencoded"], body)
	var d = JSON.parse_string(str(res.body))
	if not res.ok or typeof(d) != TYPE_DICTIONARY:
		# A rejected refresh token is dead; drop it so the next call signs up.
		_refresh_token = ""
		_save_player()
		return false
	_uid = str(d.get("user_id", _uid))
	_refresh_token = str(d.get("refresh_token", _refresh_token))
	_id_token = str(d.get("id_token", ""))
	_expires_at = Time.get_unix_time_from_system() + float(str(d.get("expires_in", "3600")))
	_save_player()
	return not _id_token.is_empty()

# --- the three calls ---

## The day's content. Answers from the cache at once when it has one and
## refreshes behind the caller; only a cold cache waits on the network, and a
## cold cache with no network falls back to what is bundled in res://.
static func day_content(game: String, date_key: int) -> Dictionary:
	var cached := _read_cache(game, date_key, "content")
	if not cached.is_empty():
		@warning_ignore("return_value_discarded")
		_fetch(game, date_key, "content")  # deliberately not awaited
		return {"ok": true, "data": cached, "error": ""}
	var got := await _fetch(game, date_key, "content")
	if got.ok:
		return got
	return {"ok": false, "data": bundled(game), "error": got.error}

## The crowd so far: {count, histogram, byLocale}. Always asks the network
## when there is one, because this is the number that moves.
static func tally(game: String, date_key: int) -> Dictionary:
	var got := await _fetch(game, date_key, "tally")
	if got.ok:
		return got
	var cached := _read_cache(game, date_key, "tally")
	if not cached.is_empty():
		return {"ok": true, "data": cached, "error": "cache"}
	return {"ok": false, "data": {}, "error": got.error}

## Records this player's turn. The submit is queued first and then sent, so a
## failure leaves it on disk for the next launch; the server keys on
## uid + day + game, which makes a double flush harmless.
static func submit(game: String, date_key: int, payload: Dictionary) -> Dictionary:
	_queue_push({
		"game": game,
		"day": date_key,
		"score": int(payload.get("score", 0)),
		"guess": payload.get("guess"),
		"locale": str(payload.get("locale", "en")),
	})
	return await _flush_queue()

## Where `score` stands in the day's crowd: the share of players it beats,
## 0 to 100, or -1 when there is no crowd yet. Computed here rather than
## asked of the server, so the reveal costs no round trip and survives
## offline (spec 3.4).
static func percentile(data: Dictionary, score: int) -> int:
	var hist = data.get("histogram", [])
	var total := int(data.get("count", 0))
	if total <= 0 or typeof(hist) != TYPE_ARRAY or hist.is_empty():
		return -1
	var below := 0
	for i in mini(hist.size(), maxi(score, 0)):
		below += int(hist[i])
	return int(round(100.0 * float(below) / float(total)))

# --- fetching and caching ---

static func _path_for(game: String, date_key: int, what: String) -> String:
	if what == "tally":
		return "days/%d/turns/%s/tally/current" % [date_key, game]
	return "days/%d/turns/%s" % [date_key, game]

## GETs one document and unwraps its single `json` field. Firestore's REST
## API answers in typed values, and every document this game reads carries
## exactly one string field, which is what keeps that from becoming a decoder.
static func _fetch(game: String, date_key: int, what: String) -> Dictionary:
	if not started() or not await _ensure_token():
		return {"ok": false, "data": {}, "error": "offline"}
	var res := await _http("%s/%s" % [_docs(), _path_for(game, date_key, what)],
		HTTPClient.METHOD_GET, ["Authorization: Bearer %s" % _id_token], "")
	if not res.ok:
		return {"ok": false, "data": {}, "error": str(res.error)}
	var doc = JSON.parse_string(str(res.body))
	if typeof(doc) != TYPE_DICTIONARY:
		return {"ok": false, "data": {}, "error": "bad document"}
	var fields = doc.get("fields", {})
	var raw = fields.get("json", {}).get("stringValue", "") if typeof(fields) == TYPE_DICTIONARY else ""
	var parsed = JSON.parse_string(str(raw))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "data": {}, "error": "bad payload"}
	_write_cache(game, date_key, what, parsed)
	return {"ok": true, "data": parsed, "error": ""}

static func _cache_file(game: String, date_key: int, what: String) -> String:
	return "%s/%s-%d-%s.json" % [CACHE_DIR, game, date_key, what]

static func _read_cache(game: String, date_key: int, what: String) -> Dictionary:
	var path := _cache_file(game, date_key, what)
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if typeof(d) == TYPE_DICTIONARY else {}

static func _write_cache(game: String, date_key: int, what: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var f := FileAccess.open(_cache_file(game, date_key, what), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))

## The copy shipped in the build, for a phone that has never been online.
static func bundled(game: String) -> Dictionary:
	var path := BUNDLED % game
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if typeof(d) == TYPE_DICTIONARY else {}

# --- the offline queue ---

static func _queue_read() -> Array:
	if not FileAccess.file_exists(QUEUE_PATH):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(QUEUE_PATH))
	return d if typeof(d) == TYPE_ARRAY else []

static func _queue_write(items: Array) -> void:
	var f := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(items))

static func _queue_push(item: Dictionary) -> void:
	var items := _queue_read()
	for existing in items:
		if existing.get("game") == item.game and int(existing.get("day", 0)) == item.day:
			return  # already waiting; one submit per game per day
	items.append(item)
	_queue_write(items)

## Sends everything waiting, keeping whatever would not go. Answers with the
## result of the last item it tried -- which is the one just pushed when
## _queue_push actually appended, and the one already waiting for this game
## and day when it did not -- or an offline verdict.
static func _flush_queue() -> Dictionary:
	var items := _queue_read()
	if items.is_empty():
		return {"ok": true, "data": {}, "error": ""}
	if not started() or not await _ensure_token():
		return {"ok": false, "data": {}, "error": "offline"}
	var kept: Array = []
	var last := {"ok": false, "data": {}, "error": "offline"}
	for item in items:
		var res := await _http("%s/submitTurn" % _host("functions"),
			HTTPClient.METHOD_POST,
			["Content-Type: application/json", "Authorization: Bearer %s" % _id_token],
			JSON.stringify(item))
		if res.ok:
			var d = JSON.parse_string(str(res.body))
			last = {"ok": true, "data": d if typeof(d) == TYPE_DICTIONARY else {}, "error": ""}
		elif int(res.code) >= 400 and int(res.code) < 500 and int(res.code) != 429:
			# The server will never accept this one; dropping it beats
			# retrying it every launch forever.
			last = {"ok": false, "data": {}, "error": str(res.error)}
		else:
			kept.append(item)
			last = {"ok": false, "data": {}, "error": str(res.error)}
	_queue_write(kept)
	return last

# --- one request ---

static func _http(url: String, method: int, headers: PackedStringArray, body: String) -> Dictionary:
	if not started():
		return {"ok": false, "code": 0, "body": "", "error": "offline"}
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	_node.add_child(req)
	if req.request(url, headers, method, body) != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "body": "", "error": "request failed"}
	var out: Array = await req.request_completed
	req.queue_free()
	var code := int(out[1])
	var text := (out[3] as PackedByteArray).get_string_from_utf8()
	return {
		"ok": code >= 200 and code < 300,
		"code": code,
		"body": text,
		"error": "" if code >= 200 and code < 300 else "HTTP %d" % code,
	}
