extends SceneTree
## Throwaway probe for Task 13: the call holds the game awake and the phone's
## screen on; the background ends it; the face greets on return. Never dials:
## the "call" is a BotCall node that was never connected.

const Power = preload("res://core/power.gd")
const Haptics = preload("res://core/haptics.gd")
var _fails := 0
var _s: Control
var _step := 0
var _t := 0.0
var _ended: Array = []


func _check(name: String, ok: bool, info := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("  (" + info + ")" if info != "" else ""))
	if not ok:
		_fails += 1


func _fake_call() -> BotCall:
	var c := BotCall.new()
	c.name = "BotCall"
	BotCall._call = c  # never started: no socket, nothing dialled
	return c


func _initialize() -> void:
	TranslationServer.set_locale("en")
	Power.enabled = true
	BotCall.hub().ended.connect(func(r: String) -> void: _ended.append(r))
	_s = load("res://bot/bot_screen.gd").new()
	root.add_child(_s)
	_s.size = Vector2(810, 1440)


func _process(d: float) -> bool:
	_t += d
	match _step:
		0:
			# Offline open (the demo): a show, resting is fine, nothing held.
			_s.open()
			_check("offline open: no hold", not Power.is_held() and not _s._kept)
			# Twenty-odd seconds of idle with no hold: the game rests.
			for i in 25:
				Power._tick(1.0)
			_check("no call: the game rests after 25 s", Power.resting)
			# The call starts dialing: the hold wakes it.
			Haptics.trace = []
			_s._set_phase("connecting")
			_check("connecting: hold taken", Power.is_held() and _s._kept)
			_check("connecting: a resting game woke", not Power.resting)
			_check("screen kept on (display server)", DisplayServer.screen_is_kept_on() or DisplayServer.get_name() == "headless",
					"DisplayServer " + DisplayServer.get_name() + " reports " + str(DisplayServer.screen_is_kept_on()))
			BotCall.hub().event.emit({"type": "session", "session_id": "x"})
			_check("session: live and a good knock", _s._phase == "live" and Haptics.trace == ["good"], str(Haptics.trace))
			# Thirty seconds of fake idle in ticks of a frame: never rests.
			for i in 1800:
				Power._tick(1.0 / 60.0)
			_check("30 s idle on a call: not resting", not Power.resting)
			Power.rest_now(false)
			_check("window unfocus (the shade) on a call: not resting", not Power.resting)
			# A tap that cuts the voice.
			Haptics.trace = []
			Haptics._until = 0  # the session's knock has played out
			_s._server_state = "speaking"
			_s._on_tap(Vector2.ZERO, true)
			_check("interrupt: a tap of the hand", Haptics.trace == ["tap"], str(Haptics.trace))
			_s._server_state = "listening"
			Haptics._until = 0
			_s._on_tap(Vector2.ZERO, true)
			_check("tap while it listens: a tick", Haptics.trace == ["tap", "tick"], str(Haptics.trace))
			# The background.
			_fake_call()
			_ended.clear()
			_s.notification(NOTIFICATION_APPLICATION_PAUSED)
			_check("pause: phase offline", _s._phase == "offline", _s._phase)
			_check("pause: Power hold released", not Power.is_held())
			_check("pause: screen keep-on released", not _s._kept)
			_check("pause: the call is gone", BotCall.current() == null)
			_check("pause: stale end counted", _s._stale == 1, str(_s._stale))
			_check("pause: no redial (nothing dialled)", BotCall.current() == null and _s._token == "")
			_step = 1
		1:
			# `ended` is deferred: it arrives a frame later, and is ignored.
			_check("pause: ended(bye) emitted", _ended == ["bye"], str(_ended))
			_check("pause: stale end swallowed", _s._stale == 0 and _s._phase == "offline" and _s._status.text == "", _s._status.text)
			# Background really rests the game.
			Power.rest_now(true)
			_check("background: the game rests", Power.resting)
			# Resume: the greeting, and how to call again.
			_s.notification(NOTIFICATION_APPLICATION_RESUMED)
			_check("resume: face greets (SWARM_L1)", _s.face.line() == tr("SWARM_L1") and _s.face.line() != "SWARM_L1", _s.face.line())
			_check("resume: line is whole", _s.face._words.visible_characters == -1)
			_check("resume: tap-to-call line", _s._status.text == tr("BOT_REDIAL") and tr("BOT_REDIAL") != "BOT_REDIAL", _s._status.text)
			_check("resume: not redialled", _s._phase == "offline" and BotCall.current() == null)
			# A pause that ended nothing (the permission sheet) greets nothing.
			_s.face.say("")
			_s._status.text = ""
			_s.notification(NOTIFICATION_APPLICATION_PAUSED)
			_s.notification(NOTIFICATION_APPLICATION_RESUMED)
			_check("pause with no call: nothing said", _s.face.line() == "" and _s._status.text == "")
			# A tap on the face calls again: an offline harness gets the offline face (no token), no dial.
			Power.touch()
			var n0: int = _s._open_n
			_s._on_tap(Vector2.ZERO, true)
			_check("tap after a cut: began a call again (waking line), no hold offline", _s._open_n == n0 + 1 and _s._status.text == tr("BOT_WAKING") and _s._phase == "offline" and not Power.is_held(), _s._phase + " " + _s._status.text)
			_step = 2
			_t = 0.0
		2:
			if _t > 0.5:
				_check("redial offline: offline face, nothing dialled, retry open", _s._phase == "offline" and BotCall.current() == null and _s._redial, _s._phase)
				# Dialing phase: a pause there drops the token and holds nothing.
				_s._token = "tok"
				_s._set_phase("dialing")
				_check("dialing: hold taken", Power.is_held() and _s._kept)
				_s.notification(NOTIFICATION_APPLICATION_PAUSED)
				_check("pause while dialing: released, token dropped, nothing stale",
						not Power.is_held() and not _s._kept and _s._token == "" and _s._stale == 0 and _s._phase == "offline")
				# Close during a call releases; so does freeing the screen.
				_s._set_phase("live")
				Haptics.trace = []
				_fake_call()
				_s.close()
				_check("close on a call: released + hang-up knock", not Power.is_held() and not _s._kept and Haptics.trace == ["tap"], str(Haptics.trace))
				_s._set_phase("live")  # as if a call were on, then the screen is freed
				_check("held again", Power.is_held())
				_s.free()
				_check("freed: released", not Power.is_held())
				_step = 3
				_t = 0.0
		3:
			if _t > 0.2:
				BotCall._call = null
				print("FAILS: %d" % _fails)
				return true
	return false
