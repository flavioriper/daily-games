extends RefCounted

## Fire-and-forget gameplay telemetry, sent to Firebase.
##
## On a phone the export carries the native Firebase SDK
## (addons/godotx_firebase: Core, Analytics, Crashlytics), and that is the
## path: sessions, first opens, retention and the platform come from the SDK,
## every event below is logged through it unchanged, and each one is also left
## as a Crashlytics breadcrumb beside the engine's own errors
## (core/crash_log.gd). Anywhere else -- a desktop run -- the old path stays:
## the GA4 Measurement Protocol over plain HTTPS, live only with an API secret.
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
## The Firebase Android app in project daily-games-420bf.
const APP_ID := "1:260608109943:android:cc54665867638bf150c572"
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
const AgeGate = preload("res://core/age_gate.gd")
const CrashLog = preload("res://core/crash_log.gd")
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

## The native SDK's GodotxFirebaseAnalytics and GodotxFirebaseCrashlytics,
## each set once its module reports itself ready. Events tracked before
## Analytics is ready wait in `_pending`, so the launch's `game_open` is kept.
static var _fa: Object = null
static var _fc: Object = null
static var _native := false
static var _pending: Array = []
static var _crash_log: CrashLog = null

## Wakes telemetry up under `host`, which must be in the tree. On a phone it
## starts the native SDK; elsewhere, without an API secret, it returns quietly
## and every later `track()` is a no-op.
static func start(host: Node) -> void:
	if _node != null and is_instance_valid(_node):
		return
	if Engine.has_singleton("GodotxFirebaseCore"):
		_start_native(host)
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
	if _crash_log != null:
		OS.remove_logger(_crash_log)
		_crash_log = null

## Core first; Analytics and Crashlytics only once it says Firebase is up.
## The export's privacy-safe defaults hold collection and every consent signal
## off until the game opens them here (see `apply_consent`).
static func _start_native(host: Node) -> void:
	_native = true
	var n := Node.new()
	n.name = "Analytics"
	host.add_child(n)
	_node = n
	_crash_log = CrashLog.new()
	OS.add_logger(_crash_log)
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(_drain_crash_log)
	n.add_child(t)
	var core: Object = Engine.get_singleton("GodotxFirebaseCore")
	core.core_initialized.connect(_on_core_ready, CONNECT_ONE_SHOT)
	core.initialize()

static func _on_core_ready(ok: bool) -> void:
	if not ok:
		return
	if Engine.has_singleton("GodotxFirebaseCrashlytics"):
		var fc: Object = Engine.get_singleton("GodotxFirebaseCrashlytics")
		fc.crashlytics_initialized.connect(_on_crashlytics_ready, CONNECT_ONE_SHOT)
		fc.initialize()
	if Engine.has_singleton("GodotxFirebaseAnalytics"):
		var fa: Object = Engine.get_singleton("GodotxFirebaseAnalytics")
		fa.analytics_initialized.connect(_on_analytics_ready, CONNECT_ONE_SHOT)
		fa.initialize()

static func _on_crashlytics_ready(ok: bool) -> void:
	if not ok:
		return
	_fc = Engine.get_singleton("GodotxFirebaseCrashlytics")
	_fc.set_crashlytics_collection_enabled(true)
	_fc.set_custom_value_string("locale", Locale.current())
	_drain_crash_log()

static func _on_analytics_ready(ok: bool) -> void:
	if not ok:
		return
	_fa = Engine.get_singleton("GodotxFirebaseAnalytics")
	_fa.set_analytics_collection_enabled(true)
	apply_consent()
	for e in _pending:
		_fa.log_event(e[0], e[1])
	_pending.clear()

## Firebase's consent signals from the player's age band: gameplay stats are
## always on (the privacy policy's first section), ad storage and ad user data
## are off for a child, and ad personalisation is for adults only -- the same
## line core/ads.gd draws for AdMob. Before the age screen is answered the
## player counts as a child. Ads.start() calls this again once the band is
## known; Google's consent form still has the last word in the EEA through
## the TCF string Firebase reads on its own.
static func apply_consent() -> void:
	if _fa == null:
		return
	var b := AgeGate.band() if AgeGate.known() else AgeGate.CHILD
	# The plugin reads each value as the string "granted"; anything else,
	# a bool included, is denied.
	_fa.set_consent({
		"analytics_storage": _granted(true),
		"ad_storage": _granted(b != AgeGate.CHILD),
		"ad_user_data": _granted(b != AgeGate.CHILD),
		"ad_personalization": _granted(b == AgeGate.ADULT),
	})

static func _granted(on: bool) -> String:
	return "granted" if on else "denied"

## One line in the next crash report's log. Free to call anywhere; it does
## nothing until Crashlytics is up, and nothing at all off a phone.
static func breadcrumb(text: String) -> void:
	if _fc != null:
		_fc.log_message(text.substr(0, CrashLog.MAX_LEN))

## Moves the engine errors core/crash_log.gd queued into Crashlytics' log, on
## the main thread.
static func _drain_crash_log() -> void:
	if _fc == null or _crash_log == null:
		return
	var got: Array = _crash_log.drain()
	for line in got[0]:
		_fc.log_message(line)
	if got[1] > 0:
		_fc.set_custom_value_int("errors_dropped", got[1])

## Records one event. `params` values must be numbers, bools or short strings;
## anything else is stringified and clipped.
static func track(event: String, params: Dictionary = {}) -> void:
	if _node == null or not is_instance_valid(_node):
		return
	if _native:
		var np := _clean(params)
		np["locale"] = Locale.current()
		if _fa == null:
			_pending.append([event, np])
		else:
			_fa.log_event(event, np)
		breadcrumb("%s %s" % [event, JSON.stringify(np)])
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
