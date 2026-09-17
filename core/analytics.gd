extends RefCounted

## Fire-and-forget gameplay telemetry, sent to Firebase over the GA4
## Measurement Protocol. Firebase Analytics is GA4 underneath, so an app
## stream accepts `firebase_app_id` + an API secret over plain HTTPS; that
## keeps the Android export on the fast non-gradle path with no native SDK.
##
## Nothing sends until `start()` runs, and only the live game calls it: the
## test suite and the harnesses build these same screens and stay silent. A
## missing API secret is not an error either -- the game just runs untracked.
##
## Every call is best effort. One request per event, failures are swallowed,
## nothing blocks a frame, and no player data beyond a random install id ever
## leaves the device.

const ENDPOINT := "https://www.google-analytics.com/mp/collect"
## Validates a payload and reports what is wrong with it instead of recording
## it. See `validate`.
const DEBUG_ENDPOINT := "https://www.google-analytics.com/debug/mp/collect"
## The Firebase Android app in project peeplet-daily.
const APP_ID := "1:881491152475:android:0e88e9f9a22583fdd0b97e"
## Deliberately not in git: written by hand beside project.godot and packed by
## the export preset's include_filter. The secret comes from GA4 Admin ->
## Data Streams -> the app stream -> Measurement Protocol API secrets.
const SECRET_FILE := "res://analytics_secret.cfg"
## This install's own id, which GA4 calls `app_instance_id`: 32 lowercase hex
## digits, made once and kept beside the other player state. It identifies a
## copy of the game, not a person.
const ID_PATH := "user://analytics.cfg"
## The locale every event's `locale` param reads, so a report can be split by
## language without a second system to join against.
const Locale = preload("res://core/locale.gd")
## GA4 drops events whose parameters run long.
const MAX_PARAMS := 25
const MAX_VALUE_LEN := 100

## The node that owns the in-flight requests. Null means "not started", which
## is the state every test runs in.
static var _node: Node = null
static var _secret: String = ""
static var _instance_id: String = ""
static var _session_id: int = 0
## Sends to the validation endpoint and prints its verdict instead of
## recording anything. For proving the wiring, not for shipping.
static var validate: bool = false
## Tags every event so it surfaces in the console's DebugView within seconds,
## rather than waiting hours for the normal reports.
static var debug_mode: bool = false

## Wakes telemetry up under `host`, which must be in the tree. Without an API
## secret this returns quietly and every later `track()` is a no-op.
static func start(host: Node) -> void:
	if _node != null and is_instance_valid(_node):
		return
	_secret = _read_secret()
	if _secret.is_empty():
		return
	_instance_id = _load_or_make_id()
	# One session per launch is close enough for a game played in one sitting.
	_session_id = int(Time.get_unix_time_from_system())
	var n := Node.new()
	n.name = "Analytics"
	host.add_child(n)
	_node = n

## True once an API secret was found and telemetry is live. Tools ask this
## rather than reading into the state above.
static func started() -> bool:
	return _node != null and is_instance_valid(_node)

## This install's id, as it reaches GA4. Empty until start() finds a secret.
static func instance_id() -> String:
	return _instance_id

## Silences telemetry again. Harnesses that build the real main scene call
## this so a probe run never reports itself as a player.
static func stop() -> void:
	if _node != null and is_instance_valid(_node):
		_node.queue_free()
	_node = null

## Records one event. `params` values must be numbers, bools or short strings;
## anything else is stringified and clipped.
static func track(event: String, params: Dictionary = {}) -> void:
	if _node == null or not is_instance_valid(_node):
		return
	var p := _clean(params)
	# GA4 only counts an event towards a session and its engagement when the
	# event carries these two.
	p["session_id"] = _session_id
	p["engagement_time_msec"] = 1
	p["locale"] = Locale.current()
	if debug_mode:
		p["debug_mode"] = 1
	_post(JSON.stringify({
		"app_instance_id": _instance_id,
		"timestamp_micros": int(Time.get_unix_time_from_system() * 1000000.0),
		"non_personalized_ads": true,
		"events": [{"name": event, "params": p}],
	}))

## Sends the body and forgets about it; the request frees itself either way.
static func _post(body: String) -> void:
	var req := HTTPRequest.new()
	req.timeout = 5.0
	_node.add_child(req)
	req.request_completed.connect(
		func(_result: int, code: int, _headers: PackedStringArray, data: PackedByteArray) -> void:
			if validate:
				print("analytics: HTTP %d %s" % [code, data.get_string_from_utf8()])
			req.queue_free()
	)
	var url := "%s?firebase_app_id=%s&api_secret=%s" % [
		DEBUG_ENDPOINT if validate else ENDPOINT, APP_ID, _secret
	]
	if req.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body) != OK:
		req.queue_free()

## Keeps the parameters inside GA4's limits so a long value never costs us the
## whole event.
static func _clean(params: Dictionary) -> Dictionary:
	var out := {}
	for key in params:
		if out.size() >= MAX_PARAMS - 4:  # room for the four we add
			break
		var v = params[key]
		if v is float:
			v = snappedf(v, 0.1)
		elif v is bool:
			v = 1 if v else 0
		elif not (v is int):
			v = str(v).substr(0, MAX_VALUE_LEN)
		out[str(key).substr(0, 40)] = v
	return out

static func _read_secret() -> String:
	# The environment wins, so a desktop run can be pointed anywhere without
	# touching the packed file.
	var from_env := OS.get_environment("GA_API_SECRET").strip_edges()
	if not from_env.is_empty():
		return from_env
	var cfg := ConfigFile.new()
	if cfg.load(SECRET_FILE) != OK:
		return ""
	return str(cfg.get_value("analytics", "api_secret", "")).strip_edges()

static func _load_or_make_id() -> String:
	var cfg := ConfigFile.new()
	cfg.load(ID_PATH)  # a missing file is fine
	var id := str(cfg.get_value("analytics", "instance_id", ""))
	if id.length() != 32:
		id = _random_hex()
		cfg.set_value("analytics", "instance_id", id)
		cfg.save(ID_PATH)
	return id

static func _random_hex() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out := ""
	for _i in 32:
		out += "0123456789abcdef"[rng.randi_range(0, 15)]
	return out
