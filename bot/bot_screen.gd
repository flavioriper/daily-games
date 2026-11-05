class_name BotScreen
extends Control

## The Swarm's call screen (2026-11-05, docs/agents/bot.md): the dark room
## round the face (bot/swarm_face.gd), opened from the Bot chip of the first
## screen's categories. Opening it starts a call to the call server
## (bot/call.gd); the back button ends it and the screen closes at once (the
## call says bye in the background, and the memory frames that come after are
## still kept, BotMemory.apply). Nothing else is on screen: the one back
## button, the subtitles (the face's), a status line under the face, the
## quiet log of what the tools did, the demo pills while there is no call,
## and the "what I know about you" button (hidden until its sheet exists).
##
## No key is read by the app: the brain, the ears and the voice are the
## server's. Offline (no token: a harness, the suite, a phone without the
## backend, or the mic refused) the face plays its demo and the status line
## says why. A harness never dials: a `--script` run is offline even when it
## builds world/main.tscn, which starts Backend (as Power.start skips one).
##
## Half duplex (BotCall.FULL_DUPLEX false): silence goes up instead of the
## mic while the server says `speaking` or the voice is still playing; a tap
## on the face interrupts and opens the mic again. The face's speaking look
## holds until the voice has drained, not until the server's next state, and
## a drawing being judged (`draw`, then `see`) keeps a thinking look.

signal closed

const Face = preload("res://bot/swarm_face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Icons = preload("res://ui/icons.gd")
const Music = preload("res://core/music.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Motion = preload("res://core/motion.gd")
const Backend = preload("res://core/backend.gd")

const BACK := 64.0
const PILL_H := 64.0
## How long the waking face shows before an offline screen says so.
const OFFLINE_AFTER := 5.0
## The subtitles' pace against the voice played, characters a second.
const REVEAL_CPS := 16.0
const MIC_PERMISSION := "RECORD_AUDIO"
const LANGS := ["en", "pt", "es"]
const TOOLS := ["swarm", "move", "draw", "dots", "tone"]
## A call's end, by `ended`'s reason, to the status line ("" says nothing).
const ENDS := {"4429": "BOT_LIMIT", "4409": "BOT_OFFLINE", "offline": "BOT_OFFLINE", "bye": ""}

var face: Face
var _back: Button
var _pills: Array[Button] = []  # Intro, Draw
var _memory_btn: Button
var _log: Label
var _status: Label
var _insets := Vector2.ZERO

## "" closed, "asking" (permission, token), "dialing" (a token, waiting for
## the last call to finish ending), "connecting" (started, no `session`),
## "live", "offline".
var _phase := ""
var _open_n := 0  # each opening; an await that outlasts its opening drops what it was doing
var _token := ""
## `ended`s still due from calls this screen has let go of: each is ignored
## (ended is deferred, so a quick close and reopen can hear the old one late).
var _stale := 0
var _server_state := ""
var _shown := ""  # the state the face was last given
var _judging := false  # a drawing is being judged: thinking until the next said or state
var _opened := false  # a tap interrupted: the mic stays open until the next said or state
var _mark := 0  # BotCall.consumed() when the line came
var _offline_at := -1  # ticks when the offline line shows
var _offline_line := ""
var _demo_due := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP

	face = Face.new()
	add_child(face)
	face.noted.connect(_note)
	face.tapped.connect(_on_tap)
	face.demo_changed.connect(_pill_marks)

	# What the agent just did with its tools, quietly, in the corner (the
	# web's action log).
	_log = Label.new()
	_log.add_theme_font_override("font", CozyTheme.body(600))
	_log.add_theme_font_size_override("font_size", 22)
	_log.add_theme_color_override("font_color", Color(Face.COL_P, 0.42))
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log)

	# The call's state in words, under the face: waking, remembering, or why
	# there is no call.
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_override("font", CozyTheme.body(600))
	_status.add_theme_font_size_override("font_size", 26)
	_status.add_theme_color_override("font_color", Color(Face.COL_PH, 0.62))
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)

	# The way out: small, in the top left corner, glass on the dark.
	_back = Button.new()
	_back.flat = true
	_back.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		_back.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_back.size = Vector2(BACK, BACK)
	_back.pivot_offset = Vector2(BACK, BACK) * 0.5
	_back.draw.connect(func() -> void:
		var c := Vector2(BACK, BACK) * 0.5
		_back.draw_circle(c, BACK * 0.5, Color(Face.COL_PH, 0.10))
		_back.draw_arc(c, BACK * 0.5 - 1.0, 0, TAU, 48, Color(Face.COL_PH, 0.22), 2.0, true)
		Icons.paint(_back, "chevron_left", Rect2(c - Vector2(14, 14), Vector2(28, 28)), Color(Face.COL_PH, 0.9)))
	_back.button_down.connect(func() -> void: Motion.bump(_back, 0.12))
	_back.pressed.connect(close)
	add_child(_back)

	# The two demos, glass pills in the top right, only while there is no call.
	for spec in [["SWARM_BTN_INTRO", Face.INTRO], ["SWARM_BTN_DRAW", Face.SHOWOFF]]:
		var pill := _glass_pill(spec[0])
		var demo: Array = spec[1]
		pill.button_down.connect(func() -> void: Motion.bump(pill, 0.12))
		pill.pressed.connect(func() -> void: face.play_demo(demo))
		add_child(pill)
		_pills.append(pill)

	# What the Swarm knows about the player: hidden until its sheet lands
	# (bot/memory_sheet.gd, the plan's Task 14).
	_memory_btn = _glass_pill("BOT_KNOWN_TITLE")
	_memory_btn.visible = false
	add_child(_memory_btn)

	BotCall.hub().event.connect(_on_event)
	BotCall.hub().ended.connect(_on_ended)

	visible = false
	set_process(false)


func _glass_pill(text: String) -> Button:
	var pill := Button.new()
	pill.focus_mode = Control.FOCUS_NONE
	pill.text = text
	var up := StyleBoxFlat.new()
	up.bg_color = Color(Face.COL_PH, 0.10)
	up.border_color = Color(Face.COL_PH, 0.22)
	up.set_border_width_all(2)
	up.set_corner_radius_all(int(PILL_H * 0.5))
	up.content_margin_left = 26
	up.content_margin_right = 26
	var down := up.duplicate()
	down.bg_color = Color(Face.COL_PH, 0.22)
	for st in ["normal", "hover", "focus", "disabled"]:
		pill.add_theme_stylebox_override(st, up)
	pill.add_theme_stylebox_override("pressed", down)
	pill.add_theme_stylebox_override("hover_pressed", down)
	pill.add_theme_font_override("font", CozyTheme.body(700))
	pill.add_theme_font_size_override("font_size", 24)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		pill.add_theme_color_override(c, Color(Face.COL_PH, 0.9))
	pill.custom_minimum_size = Vector2(0, PILL_H)
	return pill


## Opens the room and starts a call: the face gathers, the soundtrack waits,
## and the waking line shows until the call is on (or says why it is not).
func open() -> void:
	if visible:
		return
	_open_n += 1
	_log.text = ""
	_status.text = ""
	_server_state = ""
	_shown = ""
	_judging = false
	_opened = false
	_offline_at = -1
	_demo_due = false
	_token = ""
	Music.hold("bot", true)
	visible = true
	set_process(true)
	face.open()
	_insets = SafeArea.insets(self)
	_set_phase("asking")
	_begin_call(_open_n)


func is_open() -> bool:
	return visible


## Ends the call (in the background: bye, the last memory, bye_ack) and
## closes at once.
func close() -> void:
	if not visible:
		return
	_open_n += 1
	if _phase == "connecting" or _phase == "live":
		_stale += 1
		BotCall.stop()
	_phase = ""
	_demo_due = false
	face.close()
	Music.hold("bot", false)
	visible = false
	set_process(false)
	closed.emit()


func _exit_tree() -> void:
	Music.hold("bot", false)


## The mic permission (Android asks here; iOS and desktops ask when the mic
## opens), then the token; either missing is the offline face.
func _begin_call(n: int) -> void:
	_status.text = tr("BOT_WAKING")
	if OS.get_name() == "Android" and not _has_mic():
		var granted := OS.request_permission(MIC_PERMISSION)
		while not granted:
			var got: Array = await get_tree().on_request_permissions_result
			if String(got[0]).ends_with(MIC_PERMISSION):
				granted = bool(got[1])
				break
		if n != _open_n:
			return
		if not granted:
			_go_offline("BOT_MIC_REFUSED", 0.0, true)
			return
	# A harness or the suite never dials, whatever Backend has.
	var token := ""
	if not ("--script" in OS.get_cmdline_args()):
		token = await Backend.token()
	if n != _open_n:
		return
	if token == "":
		_go_offline("BOT_OFFLINE", OFFLINE_AFTER, true)
		return
	_token = token
	_set_phase("dialing")


static func _has_mic() -> bool:
	for p in OS.get_granted_permissions():
		if String(p).ends_with(MIC_PERMISSION):
			return true
	return false


## The game's language, as the call server knows it.
static func _lang() -> String:
	var l := TranslationServer.get_locale().substr(0, 2)
	return l if l in LANGS else "en"


## No call: the demo face, and after `after` seconds (from now) the line
## that says why. `demo` plays the intro once the face has formed.
func _go_offline(key: String, after: float, demo: bool) -> void:
	_set_phase("offline")
	face.set_live(false)
	_demo_due = demo
	_offline_line = tr(key) if key != "" else ""
	if after <= 0.0:
		_status.text = _offline_line
		_offline_at = -1
	else:
		_offline_at = Time.get_ticks_msec() + int(after * 1000.0)


func _set_phase(p: String) -> void:
	_phase = p


func _process(_delta: float) -> void:
	_layout()
	if _demo_due and face.play_demo():
		_demo_due = false
	if _offline_at >= 0 and Time.get_ticks_msec() >= _offline_at:
		_offline_at = -1
		_status.text = _offline_line
	match _phase:
		"dialing":
			# The last call may still be saying bye: wait for it, so this
			# start is not refused.
			if BotCall.current() == null:
				_set_phase("connecting")
				BotCall.start(self, BotCall.url(), _token, BotMemory.payload(), _lang())
				_token = ""
		"live":
			_drive()


## Each frame of a call: the mic's silence, the level, the face's look and
## the subtitles' reveal.
func _drive() -> void:
	var playing := BotCall.playing()
	var speaking := _server_state == "speaking"
	BotCall.send_silence((speaking or playing) and not _opened)
	face.set_level(BotCall.level())
	# The speaking look holds until the voice has drained; a listening that
	# came early waits for it. A drawing being judged looks thoughtful.
	var look := _server_state
	if playing:
		look = "speaking"
	elif _judging:
		look = "thinking"
	if look != _shown:
		_shown = look
		face.set_state(look)
	if face.line() != "":
		if playing or speaking:
			var n := int(float(BotCall.consumed() - _mark) / BotCall.DOWN_RATE * REVEAL_CPS)
			face.reveal(maxi(n, 0))
		else:
			face.reveal(-1)


func _on_event(msg: Dictionary) -> void:
	var kind := String(msg.get("type", ""))
	if kind == "memory":
		# Kept whenever it comes, the call's end after the screen has closed too.
		BotMemory.apply(msg)
		return
	if _phase != "connecting" and _phase != "live":
		return
	match kind:
		"session":
			_set_phase("live")
			_offline_at = -1
			_status.text = ""
			_server_state = "listening"
			_shown = ""
			face.set_live(true)
		"state":
			_server_state = String(msg.get("name", ""))
			_judging = false
			_opened = false
			_status.text = tr("BOT_REMEMBERING") if _server_state == "remembering" else ""
		"said":
			face.say(String(msg.get("text", "")))
			_mark = BotCall.consumed()
			_judging = false
			_opened = false
		"clear":
			# The voice was cut: the rest of the line was never said.
			face.say("")
		"tool":
			_tool(String(msg.get("name", "")), msg)


func _tool(name: String, msg: Dictionary) -> void:
	if name == "see":
		_judging = true
		var got := face.snapshot(384)
		# Nothing to show: no answer, and the server stops waiting on its own.
		if got.has("jpg"):
			BotCall.seen(String(msg.get("id", "")), Marshalls.base64_to_raw(String(got.jpg)), int(got.w), int(got.h))
		return
	var cmd: Variant = msg.get("cmd")
	if not (name in TOOLS) or not (cmd is Dictionary):
		return
	match name:
		"swarm":
			face.apply_swarm(cmd)
		"move":
			if cmd.has("to"):
				face.apply_move(cmd)
		"draw":
			face.apply_draw(cmd)
			_judging = not bool(cmd.get("clear", false))
		"dots":
			face.apply_dots(cmd)
		"tone":
			face.apply_tone(cmd)


func _on_ended(reason: String) -> void:
	if _stale > 0:
		_stale -= 1
		return
	if _phase != "connecting" and _phase != "live":
		return
	_server_state = ""
	_shown = ""
	_judging = false
	_go_offline(String(ENDS.get(reason, "BOT_DROPPED")), 0.0, false)


## A tap on the face while it talks: it stops, and listens.
func _on_tap(_at: Vector2, on_face: bool) -> void:
	if _phase == "live" and on_face:
		BotCall.interrupt()
		BotCall.send_silence(false)
		_opened = true


func _note(s: String) -> void:
	var lines := _log.text.split("\n", false)
	lines.append(s)
	while lines.size() > 3:
		lines.remove_at(0)
	_log.text = "\n".join(lines)


## The pill whose demo is playing stands brighter.
func _pill_marks() -> void:
	var playing := face.demo()
	for k in _pills.size():
		var on := not playing.is_empty() and playing == (Face.INTRO if k == 0 else Face.SHOWOFF)
		_pills[k].modulate = Color(1, 1, 1, 1.0 if on or playing.is_empty() else 0.55)


func _layout() -> void:
	var demos := _phase == "offline" and face.is_formed()
	_log.position = Vector2(36, size.y - _log.size.y - 28.0 - _insets.y)
	_back.position = Vector2(28.0, 28.0 + _insets.x)
	var ww := minf(size.x - 80.0, 640.0)
	_status.size = Vector2(ww, 0)
	_status.reset_size()
	_status.size.x = ww
	_status.position = Vector2((size.x - ww) * 0.5, size.y - _insets.y - 290.0 - _status.size.y * 0.5)
	var right := size.x - 28.0
	for k in range(_pills.size() - 1, -1, -1):
		var pill := _pills[k]
		pill.size = pill.get_combined_minimum_size()
		right -= pill.size.x
		pill.position = Vector2(right, 28.0 + _insets.x + (BACK - PILL_H) * 0.5)
		right -= 14.0
		pill.visible = demos
	_memory_btn.size = _memory_btn.get_combined_minimum_size()
	_memory_btn.position = Vector2(size.x - 28.0 - _memory_btn.size.x, 28.0 + _insets.x + (BACK - PILL_H) * 0.5)
