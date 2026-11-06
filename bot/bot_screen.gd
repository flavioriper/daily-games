class_name BotScreen
extends Control

## The Swarm's call screen (2026-11-05, docs/agents/bot.md): the dark room
## round the face (bot/swarm_face.gd), opened from the Bot chip of the first
## screen's categories. Opening it starts a call to the call server
## (bot/call.gd); the back button ends it and the screen closes at once (the
## call says bye in the background, and the memory frames that come after are
## still kept, BotMemory.apply). Nothing else is on screen: the one back
## button, the subtitles (the face's), a status line under the face, the
## quiet log of what the tools did, the demo pills while there is no call
## (under it), and the "what I know about you" pill in the top right, which
## opens the memory sheet (bot/memory_sheet.gd) over the room; a call goes on
## under it. The ad banner stands aside while the room is up (Ads.hold).
##
## No key is read by the app: the brain, the ears and the voice are the
## server's. Offline (no token: a harness, the suite, a phone without the
## backend, or the mic refused) the face plays its demo and the status line
## says why. A harness never dials: a `--script` run is offline even when it
## builds world/main.tscn, which starts Backend (as Power.start skips one).
##
## Hands free, like a call (the user, 2026-11-05 evening: "replace the mic
## button with a hands free like a call"; the hold-to-talk button of that
## afternoon is gone). Full duplex on a phone whose call audio runs through
## the SwarmVoice plugin with the echo canceller on (`BotCall.full_duplex`):
## the mic never closes, so a pause and more words, or talking over the Swarm,
## reach the server as in the browser (2026-11-05 night). Elsewhere half
## duplex: the mic is open whenever the Swarm is not talking; while the
## server says `speaking` or its voice still plays, silence goes up in the
## mic's place (BotCall.send_silence), at the same pace, so the speaker never
## feeds the Swarm its own words (Godot's mic has no echo cancelling). A tap on the face while it talks cuts it and
## opens the mic at once. The face's speaking look holds until the voice has
## drained, not until the server's next state, and a drawing being judged
## (`draw`, then `see`) keeps a thinking look.
##
## A call in progress (dialing, connecting, live; the demo is a show and is
## not one) holds the game awake (Power.hold "bot": it would rest after twenty
## seconds without a touch, at 30 fps and with the face's idle stopped) and
## the phone's screen on. Both let go the moment the phase leaves those three
## (the call ended, closed, freed). The app sent to the background
## (NOTIFICATION_APPLICATION_PAUSED) ends the call at once, BotCall.stop(true)
## and never redials: a call costs money and the player has left. When the
## app comes back the face greets again (SWARM_L1) and a line says a tap on
## the face calls again (`_redial`).

signal closed

const Face = preload("res://bot/swarm_face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Icons = preload("res://ui/icons.gd")
const Music = preload("res://core/music.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Motion = preload("res://core/motion.gd")
const Backend = preload("res://core/backend.gd")
const Power = preload("res://core/power.gd")
const Haptics = preload("res://core/haptics.gd")
const MemorySheet = preload("res://bot/memory_sheet.gd")

const BACK := 64.0
const PILL_H := 64.0
## How long the waking face shows before an offline screen says so.
const OFFLINE_AFTER := 5.0
## The subtitles' pace against the voice played, characters a second.
const REVEAL_CPS := 16.0
const MIC_PERMISSION := "RECORD_AUDIO"
## How long the permission's answer is waited for before it counts as refused.
const PERMISSION_WAIT := 30.0
const LANGS := ["en", "pt", "es"]
const TOOLS := ["swarm", "move", "draw", "dots", "tone"]
## A call's end, by `ended`'s reason, to the status line ("" says nothing).
## A `bye` that reaches here was not the screen's (its own are ignored): the
## server's fifteen minutes, its error closing 1000, or BotCall's own cap.
const ENDS := {"4429": "BOT_LIMIT", "4409": "BOT_OFFLINE", "offline": "BOT_OFFLINE", "bye": "BOT_REDIAL"}
## Ends a tap on the face does not call again after: the answer stands.
const FINAL := ["4429", "4409"]

var face: Face
var _back: Button
var _pills: Array[Button] = []  # Intro, Draw
var _memory_btn: Button
## What the Swarm knows, the house's paper sheet over the room.
var sheet: MemorySheet
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
var _opened := false  # a tap interrupted: the mic stays open, no speaking look, until the next said or state
var _mark := 0  # BotCall.consumed() when the line came
var _offline_at := -1  # ticks when the offline line shows
var _offline_line := ""
var _demo_due := false
var _perm = null  # the mic permission's answer, while it is asked
var _heard := false  # the line's voice has started playing
var _kept := false  # the phone's screen is held on by this screen
var _redial := false  # a call ended: a tap on the face calls again
var _cut := false  # the background ended the call: the face greets on return


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

	# What the Swarm knows about the player, and forgetting it: the sheet
	# (bot/memory_sheet.gd), last in the room so it stands over everything and
	# Android's back closes it before the room.
	_memory_btn = _glass_pill("BOT_KNOWN_TITLE")
	_memory_btn.button_down.connect(func() -> void: Motion.bump(_memory_btn, 0.12))
	add_child(_memory_btn)
	sheet = MemorySheet.new()
	sheet.name = "MemorySheet"
	_memory_btn.pressed.connect(sheet.open)
	add_child(sheet)

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
	_redial = false
	_cut = false
	_token = ""
	Music.hold("bot", true)
	# The banner stands aside before the insets are read.
	Ads.hold("bot", true)
	visible = true
	set_process(true)
	face.open()
	# The room's buttons and lines fade in with the face.
	modulate.a = 0.0
	Motion.appear(self, 0.0, 1.0, 0.25)
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
	if _phase == "dialing" or _phase == "connecting" or _phase == "live":
		# Hanging up is felt: a touch of the hand.
		Haptics.play(Haptics.TAP)
	if _phase == "connecting" or _phase == "live":
		_stale += 1
		BotCall.stop()
	_set_phase("")
	_demo_due = false
	sheet.close()
	face.close()
	Music.hold("bot", false)
	Ads.hold("bot", false)
	visible = false
	set_process(false)
	closed.emit()


func _exit_tree() -> void:
	Music.hold("bot", false)
	Ads.hold("bot", false)
	_hold(false)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_on_background()
		NOTIFICATION_APPLICATION_RESUMED:
			_on_foreground()


## The game and the phone's screen stay awake while a call is on the way or
## on; `Power.hold` is idempotent and so is the screen switch (only this
## screen's own switch is undone).
func _hold(on: bool) -> void:
	Power.hold("bot", on)
	if on and not _kept:
		_kept = true
		DisplayServer.screen_set_keep_on(true)
	elif not on and _kept:
		_kept = false
		DisplayServer.screen_set_keep_on(false)


## The app went to the background: a call dialing or on ends at once (bye
## sent, nothing waited for, its `ended` ignored) and the holds go with it.
## Nothing redials.
func _on_background() -> void:
	if not visible:
		return
	if _phase != "dialing" and _phase != "connecting" and _phase != "live":
		return
	if _phase != "dialing" and BotCall.current() != null:
		_stale += 1
		BotCall.stop(true)
	_token = ""
	_open_n += 1  # an await still waiting on the token drops what it was doing
	_server_state = ""
	_shown = ""
	_judging = false
	_cut = true
	_redial = true
	_go_offline("", 0.0, false)


## Back in the app after the call was cut: the face greets again and says how
## to call. A pause that ended nothing (the permission sheet) says nothing.
func _on_foreground() -> void:
	if not visible or not _cut or _phase != "offline":
		return
	_cut = false
	face.say(tr("SWARM_L1"))
	face.reveal(-1)
	_status.text = tr("BOT_REDIAL")


## The mic permission (Android asks here; iOS and desktops ask when the mic
## opens), then the token; either missing is the offline face.
func _begin_call(n: int) -> void:
	_status.text = tr("BOT_WAKING")
	if OS.get_name() == "Android" and not _has_mic():
		var granted := OS.request_permission(MIC_PERMISSION)
		if not granted:
			# The answer, or after PERMISSION_WAIT none: refused, never a
			# screen left on the waking line.
			_perm = null
			var tree := get_tree()
			tree.on_request_permissions_result.connect(_on_permission)
			var t0 := Time.get_ticks_msec()
			while _perm == null and Time.get_ticks_msec() - t0 < int(PERMISSION_WAIT * 1000.0):
				await tree.process_frame
			tree.on_request_permissions_result.disconnect(_on_permission)
			# the answer may come by another way than the signal
			granted = _perm == true or _has_mic()
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
		_redial = true  # a retry costs nothing
		_go_offline("BOT_OFFLINE", OFFLINE_AFTER, true)
		return
	_token = token
	_set_phase("dialing")


func _on_permission(permission: String, granted: bool) -> void:
	if permission.ends_with(MIC_PERMISSION):
		_perm = granted


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
	_hold(p == "dialing" or p == "connecting" or p == "live")


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
				BotCall.send_silence(true)
				_token = ""
		"connecting":
			BotCall.send_silence(true)  # the greeting comes first: nothing to hear before the call is on
		"live":
			_drive()


## Each frame of a call: the mic (open unless the Swarm is talking), the
## level, the face's look and the subtitles' reveal.
func _drive() -> void:
	var playing := BotCall.playing()
	var speaking := _server_state == "speaking"
	# On the phone's call path with its echo canceller the mic stays open while the
	# Swarm talks: talking over it cuts it off (the server's barge-in), as in the browser.
	BotCall.send_silence((speaking or playing) and not _opened and not BotCall.full_duplex())
	if BotCall.mic_dead():
		_mic_refused()
		return
	face.set_level(BotCall.level())
	# The speaking look holds until the voice has drained; a listening that
	# came early waits for it (not after a tap or a `clear`: the voice is
	# being cut). A drawing being judged looks thoughtful.
	var look := _server_state
	if playing and not _opened:
		look = "speaking"
	elif _judging:
		look = "thinking"
	if look != _shown:
		_shown = look
		face.set_state(look)
	if face.line() != "":
		# A line's `said` comes before its voice: nothing shows until the voice
		# plays, then the words keep pace with it, and the whole line only
		# once it has played and drained.
		var played := BotCall.consumed() - _mark
		if played > 0:
			_heard = true
		if _heard and not playing and not speaking:
			face.reveal(-1)
		else:
			face.reveal(maxi(int(float(played) / BotCall.DOWN_RATE * REVEAL_CPS), 0))


func _on_event(msg: Dictionary) -> void:
	var kind := String(msg.get("type", ""))
	if kind == "memory":
		# Kept whenever it comes, the call's end after the screen has closed too.
		BotMemory.apply(msg)
		sheet.refresh()
		return
	if _phase != "connecting" and _phase != "live":
		return
	match kind:
		"session":
			_set_phase("live")
			Haptics.play(Haptics.GOOD)  # the call is on
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
			_heard = false
			_judging = false
			_opened = false
		"clear":
			# The voice was cut: the rest of the line was never said, and the
			# Swarm has stopped talking, whether or not a state follows. The
			# mic opens again until the next said or state.
			face.say("")
			_server_state = "listening"
			_opened = true
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
	_redial = not (reason in FINAL)
	_go_offline(String(ENDS.get(reason, "BOT_DROPPED")), 0.0, false)


## The mic open and giving only exact zeros (iOS answers a
## refused mic with silence): the call ends at once and the screen says why.
func _mic_refused() -> void:
	_stale += 1
	BotCall.stop(true)
	_server_state = ""
	_shown = ""
	_judging = false
	_redial = false
	_go_offline("BOT_MIC_REFUSED", 0.0, true)


## A tap on the face while it talks: it stops, and listens. Off a call, after
## one ended, it calls again (the hour's limit excepted: that answer stands).
func _on_tap(_at: Vector2, on_face: bool) -> void:
	if not on_face:
		return
	if _phase == "live":
		# Cutting the voice is a tap of the hand; a tap while it listens only a tick.
		Haptics.play(Haptics.TAP if (_server_state == "speaking" or BotCall.playing()) else Haptics.TICK)
		BotCall.interrupt()
		BotCall.send_silence(false)
		_opened = true
	elif _phase == "offline" and _redial and BotCall.current() == null:
		_redial = false
		Haptics.play(Haptics.TICK)
		_open_n += 1
		_log.text = ""
		_status.text = ""
		_server_state = ""
		_shown = ""
		_judging = false
		_opened = false
		_demo_due = false
		_offline_at = -1
		_token = ""
		face.say("")
		_set_phase("asking")
		_begin_call(_open_n)


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
	# The memory pill beside the back button's row, the demos in a row under it.
	var top := 28.0 + _insets.x + (BACK - PILL_H) * 0.5
	_memory_btn.size = _memory_btn.get_combined_minimum_size()
	_memory_btn.position = Vector2(size.x - 28.0 - _memory_btn.size.x, top)
	var right := size.x - 28.0
	for k in range(_pills.size() - 1, -1, -1):
		var pill := _pills[k]
		pill.size = pill.get_combined_minimum_size()
		right -= pill.size.x
		pill.position = Vector2(right, top + PILL_H + 14.0)
		right -= 14.0
		pill.visible = demos

