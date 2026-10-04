extends RefCounted

## The Realtime Database over REST: the one live thing in the game, which is
## Versus online. Four verbs and a stream, static like core/backend.gd and
## riding on its identity -- the same anonymous id token goes in `?auth=`.
##
## Unstarted Backend means offline: every verb answers {ok = false, code = 0}
## and a Stream stays shut, without touching the network. That is how the
## suite and the harnesses build an online screen and never leave the Mac.
##
## There is no SDK and no socket: a write is one request, and listening is one
## long GET with `Accept: text/event-stream` that the server keeps open and
## writes `put` and `patch` events down (Stream, below).
## Spec: docs/superpowers/specs/2026-10-04-versus-online-design.md, section 1.

const Backend = preload("res://core/backend.gd")

## The live database. An instance outside us-central1 has another host
## (<name>.<region>.firebasedatabase.app), which is why this is spelled out
## and not built from the project id.
const HOST := "https://daily-games-420bf-default-rtdb.firebaseio.com"
const EMULATOR_PORT := 9000
## The value the server replaces with its own clock, in rules' `now`.
const STAMP := {".sv": "timestamp"}

## The server's clock minus this device's, in ms, from the last stamped write.
static var _offset_ms := 0.0
static var _clocked := false
## For a probe, as Stream.drop() is: the next `lose` requests are made and
## land, and their answers are thrown away -- {ok = false, code = 0}, what a
## network that went quiet mid-request looks like from here.
static var lose := 0

static func online() -> bool:
	return Backend.started()

# --- the four verbs ---

## GET. `query` is the REST API's own (orderBy, limitToFirst, shallow...); a
## string value is quoted for it, as the API wants its strings.
static func read(path: String, query := {}) -> Dictionary:
	return await _call(HTTPClient.METHOD_GET, path, null, false, query)

## PUT: `value` replaces what is at `path`.
static func write(path: String, value: Variant) -> Dictionary:
	return await _call(HTTPClient.METHOD_PUT, path, value, true, {})

## PATCH: each key of `changes` is a child of `path`, or a path under it
## ("moves/3"), and all of them land together or none does.
static func patch(path: String, changes: Dictionary) -> Dictionary:
	return await _call(HTTPClient.METHOD_PATCH, path, changes, true, {})

## DELETE.
static func remove(path: String) -> Dictionary:
	return await _call(HTTPClient.METHOD_DELETE, path, null, false, {})

## The server's clock in ms since the epoch, as near as the last stamped
## write told it; this device's own until there has been one.
static func server_now() -> float:
	return Time.get_unix_time_from_system() * 1000.0 + _offset_ms

## True once a stamped write has answered, so server_now() is the server's.
static func clocked() -> bool:
	return _clocked

# --- one request ---

static func _call(method: int, path: String, value: Variant, has_body: bool,
		query: Dictionary) -> Dictionary:
	if not online():
		return {"ok": false, "code": 0, "data": null}
	var lost := lose > 0
	if lost:
		lose -= 1
	var res := {}
	# Twice at most: a token the server calls stale is renewed once. A rule's
	# refusal is a 401 too, and that one is an answer, not a reason to retry.
	for attempt in 2:
		var token := await Backend.token(attempt == 1)
		if token.is_empty():
			return {"ok": false, "code": 0, "data": null}
		var sent := Time.get_unix_time_from_system()
		res = await Backend._http(url(path, token, query), method,
			["Content-Type: application/json"],
			JSON.stringify(value) if has_body else "")
		if int(res.code) != 401 or str(res.body).contains("Permission denied"):
			if res.ok and has_body:
				var back := Time.get_unix_time_from_system()
				_read_stamp(value, JSON.parse_string(str(res.body)), (sent + back) * 500.0)
			break
	if lost:
		return {"ok": false, "code": 0, "data": null}
	var text := str(res.body)
	return {
		"ok": bool(res.ok),
		"code": int(res.code),
		"data": JSON.parse_string(text) if not text.is_empty() else null,
	}

## Where the request held STAMP, the answer holds the server's clock at the
## write. The first one found sets the offset; `at_ms` is this device's clock
## halfway through the round trip.
static func _read_stamp(sent: Variant, got: Variant, at_ms: float) -> bool:
	if typeof(sent) != TYPE_DICTIONARY:
		return false
	if sent.has(".sv"):
		if typeof(got) == TYPE_FLOAT or typeof(got) == TYPE_INT:
			_offset_ms = float(got) - at_ms
			_clocked = true
			return true
		return false
	if typeof(got) != TYPE_DICTIONARY:
		return false
	for k in sent:
		if got.has(k) and _read_stamp(sent[k], got[k], at_ms):
			return true
	return false

## The whole address of `path`. Under the emulator the database is picked by
## `ns`, as its host is the emulator's and names nothing.
static func url(path: String, token: String, query := {}) -> String:
	var base := HOST
	var parts: PackedStringArray = []
	if not Backend._emulator.is_empty():
		base = "http://%s:%d" % [Backend._emulator, EMULATOR_PORT]
		parts.append("ns=%s-default-rtdb" % Backend._project())
	parts.append("auth=%s" % token.uri_encode())
	for k in query:
		var v: Variant = query[k]
		var text := JSON.stringify(v) if typeof(v) == TYPE_STRING else str(v)
		parts.append("%s=%s" % [str(k), text.uri_encode()])
	return "%s/%s.json?%s" % [base, path.trim_prefix("/"), "&".join(parts)]

# --- listening ---

## One open listen on one path. Add it to the tree, `open(path)`, and it
## emits `event` for all that is there now (a `put` at "/") and for every
## change after. It follows the 307 the live database answers with when the
## data lives on another host, reads the event stream as it arrives in
## `_process`, and when the connection drops, goes quiet or its token is
## revoked it says `dropped` once and opens again -- with a fresh token and a
## growing wait -- so the first event after is the whole of the data again.
## A listener that keeps what it was sent and applies each event by path is
## therefore right after a drop without knowing there was one.
##
## `cancel` (the rules no longer allow the read) is handed on as an event
## and ends the stream; nothing reopens it.
class Stream extends Node:
	## `kind` is "put" (data replaces what is at `path`), "patch" (each key of
	## data is a child or a path under `path`) or "cancel". `path` is relative
	## to the path opened, "/" for all of it.
	signal event(kind: String, path: String, data: Variant)
	## The connection went. Said once an outage; the stream is already trying
	## again.
	signal dropped

	enum { IDLE, TOKEN, CONNECTING, REQUESTING, REFUSED, BODY, WAITING }
	const BACKOFF_MIN := 0.5
	const BACKOFF_MAX := 8.0
	const CONNECT_TIMEOUT := 8.0
	## The server writes `keep-alive` every 30 s (the emulator too). A stream
	## quiet for longer is dead without having said so (a phone that changed
	## network).
	const QUIET_MAX := 40.0
	const MAX_REDIRECTS := 4

	var path := ""
	## How many times it has connected, for a probe to read.
	var opens := 0

	var _state := IDLE
	var _http: HTTPClient = null
	var _redirect := ""
	var _redirects := 0
	var _buf := PackedByteArray()
	var _kind := ""
	var _data := ""
	var _refusal := PackedByteArray()
	var _code := 0
	var _timer := 0.0
	var _backoff := BACKOFF_MIN
	var _fresh := false
	var _down := false
	## Goes up whenever the stream is opened or shut, so a token that arrives
	## for an older attempt is dropped.
	var _gen := 0

	func open(p: String) -> void:
		close()
		path = p
		_backoff = BACKOFF_MIN
		_begin()

	func close() -> void:
		_gen += 1
		_shut()
		_state = IDLE
		_down = false
		_redirect = ""

	func is_open() -> bool:
		return _state == BODY

	## Cuts the connection as a bad network would, for a probe: `dropped`,
	## then the usual way back.
	func drop() -> void:
		if _state != IDLE:
			_lost()

	func _exit_tree() -> void:
		close()

	func _shut() -> void:
		if _http != null:
			_http.close()
		_http = null
		_buf = PackedByteArray()
		_kind = ""
		_data = ""

	func _begin() -> void:
		_gen += 1
		var gen := _gen
		_shut()
		_state = TOKEN
		# An inner class does not see the outer one's functions; the script
		# is already in memory, so this is a lookup.
		var live: Script = load("res://core/live.gd")
		if not live.online():
			_state = IDLE
			return
		var address := _redirect
		if address.is_empty():
			var token: String = await Backend.token(_fresh)
			if gen != _gen:
				return
			if token.is_empty():
				_lost()
				return
			_fresh = false
			address = live.url(path, token)
		var tls := address.begins_with("https://")
		var rest := address.substr(address.find("://") + 3)
		var slash := rest.find("/")
		var host := rest.substr(0, slash) if slash >= 0 else rest
		var request := rest.substr(slash) if slash >= 0 else "/"
		var port := 443 if tls else 80
		var colon := host.rfind(":")
		if colon >= 0:
			port = int(host.substr(colon + 1))
			host = host.substr(0, colon)
		_http = HTTPClient.new()
		_http.set_meta("request", request)
		if _http.connect_to_host(host, port, TLSOptions.client() if tls else null) != OK:
			_lost()
			return
		_timer = 0.0
		_state = CONNECTING

	## The connection is gone or never came: say so once, wait, try again.
	func _lost() -> void:
		_gen += 1
		_shut()
		_redirect = ""
		_redirects = 0
		if not _down:
			_down = true
			dropped.emit()
		_state = WAITING
		_timer = _backoff
		_backoff = minf(_backoff * 2.0, BACKOFF_MAX)

	func _process(delta: float) -> void:
		match _state:
			WAITING:
				_timer -= delta
				if _timer <= 0.0:
					_begin()
			CONNECTING:
				_http.poll()
				_timer += delta
				match _http.get_status():
					HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING:
						if _timer > CONNECT_TIMEOUT:
							_lost()
					HTTPClient.STATUS_CONNECTED:
						var err := _http.request(HTTPClient.METHOD_GET, str(_http.get_meta("request")),
							["Accept: text/event-stream", "Cache-Control: no-cache"])
						if err != OK:
							_lost()
						else:
							_timer = 0.0
							_state = REQUESTING
					_:
						_lost()
			REQUESTING:
				_http.poll()
				_timer += delta
				var status := _http.get_status()
				if status == HTTPClient.STATUS_REQUESTING:
					if _timer > CONNECT_TIMEOUT:
						_lost()
				elif _http.has_response():
					_answered()
				else:
					_lost()
			REFUSED:
				_http.poll()
				_timer += delta
				if _http.get_status() == HTTPClient.STATUS_BODY and _timer < CONNECT_TIMEOUT:
					_refusal.append_array(_http.read_response_body_chunk())
				else:
					_refused()
			BODY:
				_http.poll()
				_timer += delta
				# Bounded, so a flood cannot hold a frame.
				for i in 16:
					if _http == null or _http.get_status() != HTTPClient.STATUS_BODY:
						break
					var chunk := _http.read_response_body_chunk()
					if chunk.is_empty():
						break
					_timer = 0.0
					_buf.append_array(chunk)
					_parse()
				if _state != BODY:
					return
				if _http.get_status() != HTTPClient.STATUS_BODY or _timer > QUIET_MAX:
					_lost()

	## The status line is in.
	func _answered() -> void:
		_code = _http.get_response_code()
		if _code == 200:
			opens += 1
			_redirects = 0
			_timer = 0.0
			_state = BODY
			return
		if _code in [301, 302, 307, 308]:
			# Read off the raw headers: the name's case is the server's choice.
			var to := ""
			for h in _http.get_response_headers():
				if h.to_lower().begins_with("location:"):
					to = h.substr(9).strip_edges()
			_redirects += 1
			if to.is_empty() or _redirects > MAX_REDIRECTS:
				_lost()
				return
			# The other host is asked the same thing; it stays the address
			# until the connection is lost, when the first host is asked again.
			_redirect = to
			_begin()
			return
		_refusal = PackedByteArray()
		_timer = 0.0
		_state = REFUSED

	## Anything but 200: a rule's refusal ends the stream as `cancel` does; a
	## token the server will not take is renewed; the rest is a drop.
	func _refused() -> void:
		var text := _refusal.get_string_from_utf8()
		if (_code == 401 or _code == 403) and text.contains("Permission denied"):
			close()
			event.emit("cancel", "/", null)
			return
		if _code == 401 or _code == 403:
			_fresh = true
		_lost()

	## Takes whole lines off the front of the buffer. A chunk ends anywhere --
	## mid-line, mid-character -- so only what a newline has closed is read,
	## and it is decoded a line at a time.
	func _parse() -> void:
		var from := 0
		while true:
			var nl := _buf.find(10, from)
			if nl < 0:
				break
			var line := _buf.slice(from, nl).get_string_from_utf8().trim_suffix("\r")
			from = nl + 1
			if line.is_empty():
				var kind := _kind
				var data := _data
				_kind = ""
				_data = ""
				if not kind.is_empty() and not _dispatch(kind, data):
					return  # the stream was shut or lost; the buffer went with it
			elif line.begins_with("event:"):
				_kind = line.substr(6).strip_edges()
			elif line.begins_with("data:"):
				_data += line.substr(5).strip_edges()
		_buf = _buf.slice(from)

	## One whole event. False when it ended this connection.
	func _dispatch(kind: String, data: String) -> bool:
		# Anything the server says proves the line is up.
		_down = false
		_backoff = BACKOFF_MIN
		match kind:
			"put", "patch":
				var d: Variant = JSON.parse_string(data)
				if typeof(d) == TYPE_DICTIONARY:
					var gen := _gen
					event.emit(kind, str(d.get("path", "/")), d.get("data"))
					return gen == _gen
			"cancel":
				close()
				event.emit("cancel", "/", null)
				return false
			"auth_revoked":
				_fresh = true
				_backoff = 0.0
				_lost()
				_backoff = BACKOFF_MIN
				return false
		return true  # keep-alive, and anything not known
