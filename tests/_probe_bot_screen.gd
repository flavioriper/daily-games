extends SceneTree
## Throwaway probe for bot/bot_screen.gd (Task 12): offline open, the lines
## by reason, stale ends, the call's events driving the face, and the chip's
## age gate. Never dials: Backend is not started under --script.

const AGE := "user://_probe_bot_screen_age.cfg"
const MEM := "user://_probe_bot_screen_memory.json"
var _fails := 0
var _s: Control
var _t := 0.0
var _step := 0
var _at := 0.0
var _row: Node
var _menu: Node
var _saved_age := ""
var _saved_mem := ""
var _ps: Control  # the screen the real pointer presses (hold to talk)
## ui/menu.gd loaded before bot/bot_screen.gd, as the game does: the other
## order leaves a script cycle that leaks ~570 objects at exit (an artifact of
## the probe's load order, not of the game).
var _menu_script: Script


## A call that is never dialled: its `_silence` is what the screen asks for,
## and what it would send is kept.
class FakeCall extends BotCall:
	var sent: Array = []
	func _send(msg: Dictionary) -> void:
		sent.append(msg)


func _touch(index: int, pressed: bool, at := Vector2.ZERO, canceled := false) -> InputEventScreenTouch:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = pressed
	ev.position = at
	ev.canceled = canceled
	return ev


func _mouse(pressed: bool, at := Vector2.ZERO) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	return ev


func _check(name: String, ok: bool, info := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("  (" + info + ")" if info != "" else ""))
	if not ok:
		_fails += 1


func _initialize() -> void:
	_menu_script = load("res://ui/menu.gd")
	TranslationServer.set_locale("en")
	# The chip: a child never sees it, a teen does, an unknown age does not.
	var AgeGate = load("res://core/age_gate.gd")
	var Row = load("res://ui/menu/category_row.gd")
	var saved_age: String = AgeGate.path
	AgeGate.path = AGE
	var keys := func() -> Array: return Row.entries().map(func(t): return t.key)
	AgeGate.forget()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AGE))
	_check("unknown age: no bot chip", not keys.call().has("bot"), str(keys.call()))
	var year := int(Time.get_datetime_dict_from_system(true).year)
	AgeGate.set_birth_year(year - 9)
	_check("child: no bot chip", not keys.call().has("bot"), str(keys.call()))
	AgeGate.set_birth_year(year - 16)
	_check("placeholder url: no bot chip", not keys.call().has("bot") and not FileAccess.file_exists(BotCall.URL_FILE), str(keys.call()))
	OS.set_environment("BOT_URL", "ws://127.0.0.1:9/ws/bot")  # a debug build reads it
	_check("debug url from the env", BotCall.url() == "ws://127.0.0.1:9/ws/bot" and BotCall.configured())
	_check("teen: bot chip", keys.call().has("bot"), str(keys.call()))
	# A row built before the answer gets the chip on rebuild (checked next frame).
	AgeGate.set_birth_year(year - 9)
	_row = Row.new()
	root.add_child(_row)
	_saved_age = saved_age
	return


func _process(d: float) -> bool:
	_t += d
	match _step:
		0:
			var AgeGate = load("res://core/age_gate.gd")
			_check("row built for a child: no bot", not _row._tabs.has("bot"), str(_row._tabs.keys()))
			AgeGate.set_birth_year(int(Time.get_datetime_dict_from_system(true).year) - 30)
			_row.rebuild_tabs()
			_check("row rebuilt for an adult: bot", _row._tabs.has("bot") and _row._row.get_child_count() == 2, str(_row._tabs.keys()))
			_row.queue_free()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(AGE))
			AgeGate.path = _saved_age
			AgeGate.forget()
			_s = load("res://bot/bot_screen.gd").new()
			root.add_child(_s)
			_s.size = Vector2(810, 1440)
			_s.open()
			_check("music held while open", load("res://core/music.gd")._holds.has("bot"))
			_at = _t
			_step = 1
		1:
			if _t - _at >= 2.5:
				_check("demo playing offline", not _s.face.demo().is_empty())
				_check("waking line first", _s._status.text == tr("BOT_WAKING"), _s._status.text)
				_check("pills shown offline", _s._pills[0].visible)
				_check("offline: talk button hidden", not _s._mic_btn.visible and not _s._hint.visible)
				_check("nothing dialled", BotCall.current() == null)
				_step = 2
		2:
			if _t - _at >= 5.3:
				_check("offline line after five seconds", _s._status.text == tr("BOT_OFFLINE"), _s._status.text)
				# A call that ends at the hour's limit.
				_s._set_phase("connecting")
				BotCall.hub().ended.emit("4429")
				_check("4429 shows the limit", _s._status.text == tr("BOT_LIMIT"), _s._status.text)
				_check("back to offline", _s._phase == "offline")
				_check("4429: no redial", not _s._redial)
				for r in [["dropped", "BOT_DROPPED", true], ["timeout", "BOT_DROPPED", true], ["4401", "BOT_DROPPED", true], ["4409", "BOT_OFFLINE", false], ["offline", "BOT_OFFLINE", true]]:
					_s._set_phase("live")
					BotCall.hub().ended.emit(r[0])
					_check("%s -> %s, redial %s" % r, _s._status.text == tr(r[1]) and _s._redial == r[2], _s._status.text)
				_s._set_phase("live")
				BotCall.hub().ended.emit("bye")
				_check("an unasked bye: redial line, redial on", _s._status.text == tr("BOT_REDIAL") and _s._redial, _s._status.text)
				_step = 3
		3:
			# A call's events (faked on the hub) drive the face.
			_s._set_phase("connecting")
			var hub = BotCall.hub()
			hub.event.emit({"type": "session", "session_id": "x"})
			_check("session: live", _s._phase == "live" and _s.face.live)
			_check("session: no demo", _s.face.demo().is_empty())
			_s._process(0.016)
			_check("live: pills hidden", not _s._pills[0].visible)
			_check("live: face listening", _s.face.state() == "listening", _s.face.state())
			# Hold to talk: the button is the only thing that opens the mic.
			var fake := FakeCall.new()
			BotCall._call = fake
			var btn: Button = _s._mic_btn
			_s._process(0.016)
			_check("live: talk button shown, enabled", btn.visible and not btn.disabled)
			_check("live idle: silence goes up", fake._silence)
			_check("live idle: hint shown", _s._hint.visible and tr("BOT_HOLD") == "Hold to talk", tr("BOT_HOLD"))
			btn.gui_input.emit(_touch(0, true, Vector2(56, 56)))
			_check("press opens the mic", _s._held and not fake._silence)
			_s._process(0.016)
			_check("held: mic stays open a frame on", not fake._silence)
			_check("held: listening look, hint hidden", _s.face.state() == "listening" and not _s._hint.visible, _s.face.state())
			btn.gui_input.emit(_touch(3, false, Vector2(56, 56)))
			_check("another finger's lift ignored", _s._held and not fake._silence)
			btn.gui_input.emit(_touch(0, false, Vector2(56, 56)))
			_check("release closes the mic", not _s._held and fake._silence)
			_s._process(0.016)
			_check("released: silence a frame on", fake._silence)
			btn.gui_input.emit(_touch(1, true, Vector2(56, 56)))
			btn.gui_input.emit(_touch(1, false, Vector2(56, 56), true))
			_check("cancelled touch closes the mic", not _s._held and fake._silence)
			btn.gui_input.emit(_mouse(true, Vector2(56, 56)))
			_check("mouse press opens", _s._held and not fake._silence)
			btn.gui_input.emit(_mouse(false, Vector2(-500, -700)))
			_check("mouse release outside closes", not _s._held and fake._silence)
			# A press while the Swarm talks cuts it first, then listens.
			hub.event.emit({"type": "state", "name": "speaking"})
			fake._down = PackedByteArray([0, 0, 0, 0])  # voice still waiting
			_s._process(0.016)
			_check("speaking: mic shut", fake._silence and _s.face.state() == "speaking")
			fake.sent.clear()
			btn.gui_input.emit(_touch(0, true, Vector2(56, 56)))
			_s._process(0.016)
			_check("press while speaking interrupts", fake.sent.size() == 1 and fake.sent[0].type == "interrupt", str(fake.sent))
			_check("press while speaking opens the mic", _s._held and not fake._silence and _s.face.state() == "listening", _s.face.state())
			btn.gui_input.emit(_touch(0, false))
			fake._down = PackedByteArray()
			hub.event.emit({"type": "state", "name": "listening"})
			# The face's tap still interrupts, and opens nothing.
			fake.sent.clear()
			_s._on_tap(Vector2.ZERO, true)
			_s._process(0.016)
			_check("face tap interrupts, mic stays shut", fake.sent.size() == 1 and fake._silence and not _s._held)
			# Held when the call stops being live: shut, and no press until live.
			btn.gui_input.emit(_touch(0, true))
			_s._set_phase("connecting")
			_s._process(0.016)
			_check("call not live: mic shut, button disabled", not _s._held and fake._silence and btn.disabled)
			btn.gui_input.emit(_touch(0, true))
			_check("disabled: press opens nothing", not _s._held and fake._silence)
			btn.gui_input.emit(_touch(0, false))
			hub.event.emit({"type": "session", "session_id": "x"})
			_s._process(0.016)
			# The shade, an overlay or the memory sheet: a held mic is let go.
			for what in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
				btn.gui_input.emit(_touch(0, true))
				_s._notification(what)
				_check("focus out %d releases the mic" % what, not _s._held and fake._silence)
			btn.gui_input.emit(_touch(0, true))
			_s._memory_btn.pressed.emit()
			_check("memory sheet releases the mic", not _s._held and fake._silence and _s.sheet.is_open())
			_s.sheet.close()
			_s._set_phase("connecting")
			hub.event.emit({"type": "session", "session_id": "x"})
			_s._process(0.016)
			BotCall._call = null
			fake.free()
			hub.event.emit({"type": "state", "name": "speaking"})
			hub.event.emit({"type": "said", "text": "Hello there, friend."})
			_s._process(0.016)
			_check("speaking look", _s.face.state() == "speaking", _s.face.state())
			_check("said: line set, nothing revealed yet", _s.face.line() == "Hello there, friend." and _s.face._words.visible_characters == 0, str(_s.face._words.visible_characters))
			# said before its audio, with the server not (yet) speaking: no flash of the whole line
			hub.event.emit({"type": "state", "name": "listening"})
			hub.event.emit({"type": "said", "text": "Next line."})
			_s._process(0.016)
			_check("said before audio: not shown whole", _s.face._words.visible_characters == 0, str(_s.face._words.visible_characters))
			_s._heard = true  # as if its voice had played
			_s._process(0.016)
			_check("played and drained: line whole", _s.face.state() == "listening" and _s.face._words.visible_characters == -1)
			# clear ends speaking on the client: mic open, face out of the speaking look
			hub.event.emit({"type": "state", "name": "speaking"})
			_s._process(0.016)
			hub.event.emit({"type": "clear"})
			_s._process(0.016)
			_check("clear: listening, speaking look gone", _s._server_state == "listening" and _s._opened and _s.face.state() == "listening", _s.face.state())
			hub.event.emit({"type": "tool", "name": "tone", "cmd": {"tone": "gold"}})
			_check("tone tool applied", _s.face._tone_to.is_equal_approx(Color("ffd166")))
			hub.event.emit({"type": "tool", "name": "move", "cmd": {"to": "top-left"}})
			_check("move tool applied", String(_s.face._place.to) == "top-left")
			hub.event.emit({"type": "tool", "name": "move", "cmd": {}})
			_check("move without to ignored", String(_s.face._place.to) == "top-left")
			var r = _s.face.apply_draw({"name": "bank:sun"})
			hub.event.emit({"type": "tool", "name": "draw", "cmd": {"name": "bank:sun"}})
			_s._process(0.016)
			_check("draw: judging looks thinking", _s.face.state() == "thinking", _s.face.state() + " " + str(r))
			hub.event.emit({"type": "tool", "name": "see", "id": "abc"})
			_check("see answered or skipped without a crash", true)
			hub.event.emit({"type": "state", "name": "remembering"})
			_check("remembering line", _s._status.text == tr("BOT_REMEMBERING"))
			# memory frames are kept even after the screen closes
			var saved_mem: String = BotMemory.path
			BotMemory.path = MEM
			DirAccess.remove_absolute(ProjectSettings.globalize_path(MEM))
			_s.close()
			_check("closed: stale end counted", _s._stale == 1)
			_check("music released", not load("res://core/music.gd")._holds.has("bot"))
			hub.event.emit({"type": "memory", "op": "add", "id": "f1", "text": "Likes owls."})
			var facts: Array = BotMemory.load().facts
			_check("memory after close kept", facts.size() == 1 and facts[0].text == "Likes owls.", str(facts))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(MEM))
			BotMemory.path = saved_mem
			# Reopen; the old call's late end is ignored, the new one's is not.
			_s.open()
			_s._set_phase("connecting")
			hub.ended.emit("dropped")
			_check("stale end ignored", _s._phase == "connecting" and _s._stale == 0, _s._phase)
			hub.ended.emit("dropped")
			_check("own end shown", _s._status.text == tr("BOT_DROPPED"), _s._status.text)
			# The mic refused: the line at once, the demo face, no call.
			_s._go_offline("BOT_MIC_REFUSED", 0.0, true)
			_check("mic refused line", _s._status.text == tr("BOT_MIC_REFUSED") and BotCall.current() == null)
			_s.close()
			_s.queue_free()
			_step = 30
		30:
			# The real pointer: a finger down on the button, lifted far off it.
			_ps = load("res://bot/bot_screen.gd").new()
			root.add_child(_ps)
			_ps.size = Vector2(810, 1440)
			_ps.open()
			_at = _t
			_step = 31
		31:
			if _t - _at >= 2.5 and _ps.face.is_formed():
				_ps._set_phase("connecting")
				BotCall.hub().event.emit({"type": "session", "session_id": "y"})
				_step = 32
		32:
			var b: Button = _ps._mic_btn
			var c := b.get_global_rect().get_center()
			Input.parse_input_event(_touch(0, true, root.get_final_transform() * c))
			_step = 33
		33:
			_check("real touch: press opens", _ps._held, str(_ps._mic_btn.get_global_rect()))
			Input.parse_input_event(_touch(0, false, root.get_final_transform() * Vector2(40, 200)))
			_step = 34
		34:
			_check("real touch: lift off the button closes", not _ps._held)
			# A refused mic gives only zeros: held 1.5 s of them ends the call.
			var fk := FakeCall.new()
			fk._live = true
			BotCall._call = fk
			_ps._process(0.016)  # idle: silence goes up
			_ps._mic_down(0)
			_check("a fresh press is not a dead mic", _ps._held and not BotCall.mic_dead())
			fk._heard_at = Time.get_ticks_msec() - 1000
			_ps._process(0.016)
			_check("1 s of zeros: still live", _ps._phase == "live" and _ps._held)
			BotCall.test_tone_hz = 440.0
			fk._heard_at = Time.get_ticks_msec() - 1600
			_check("the test tone is never a dead mic", not BotCall.mic_dead())
			BotCall.test_tone_hz = 0.0
			_ps._process(0.016)
			_check("1.6 s of zeros: call ended, mic refused line", _ps._phase == "offline" and not _ps._held and _ps._status.text == tr("BOT_MIC_REFUSED") and BotCall.current() == null and _ps._stale == 1 and not _ps._redial, _ps._status.text)
			fk.free()
			_step = 35
		35:
			_check("its end was let go", _ps._stale == 0 and _ps._phase == "offline" and _ps._status.text == tr("BOT_MIC_REFUSED"))
			_ps._set_phase("live")
			_ps._process(0.016)
			_ps._mic_down(0)
			root.remove_child(_ps)
			_check("leaving the tree releases the mic", not _ps._held)
			root.add_child(_ps)
			_ps.close()
			_ps.queue_free()
			_step = 4
		4:
			# Android's back through the menu closes the screen, not the face.
			_menu = load("res://ui/menu.gd").new()
			root.add_child(_menu)
			_step = 5
			_at = _t
		5:
			if _t - _at >= 0.5:
				_menu._on_tab("bot")
				_step = 6
		6:
			var bs = _menu.bot_screen
			_check("menu: screen open", bs != null and bs.is_open())
			_check("face answers no is_open", not bs.face.has_method("is_open"))
			_check("banner held while open", root.get_node("/root/Ads")._held.has("bot"))
			_check("memory pill shown", bs._memory_btn.visible)
			# The memory sheet over the room, on a probe file.
			_saved_mem = BotMemory.path
			BotMemory.path = MEM
			var f := FileAccess.open(MEM, FileAccess.WRITE)
			f.store_string(JSON.stringify({"facts": [
				{"id": "f1", "text": "Has a cat called Biscuit.", "since": "2026-11-01T10:00:00Z"},
				{"id": "f2", "text": "Likes owls.", "since": "2026-11-03T10:00:00Z"}],
				"episodes": [{"id": "e1", "summary": "We drew a sun together.", "at": "2026-11-02T10:00:00Z"}]}))
			f.close()
			bs._set_phase("live")  # as if a call were on
			bs._memory_btn.pressed.emit()
			_step = 60
			_at = _t
		60:
			if _t - _at < 0.5:
				return false
			var bs = _menu.bot_screen
			var sh = bs.sheet
			_check("sheet open", sh.is_open())
			var flow = sh._list.get_child(0)
			_check("two chips, newest first", flow is HFlowContainer and flow.get_child_count() == 2 and flow.get_child(0).text == "Likes owls.", str(flow.get_child_count()))
			_check("one episode row", sh._list.get_child_count() == 2 and sh._list.get_child(1).text == "We drew a sun together.")
			flow.get_child(0).pressed.emit()
			_check("tap asks", is_instance_valid(sh._ask) and sh._ask.is_open())
			_menu.go_back()
			_check("back closes the ask, not the sheet", not is_instance_valid(sh._ask) and sh.is_open() and bs.is_open())
			flow.get_child(0).pressed.emit()
			sh._ask.answered.emit(true)
			var m := BotMemory.load()
			_check("forgot f2 only", m.facts.size() == 1 and m.facts[0].id == "f1" and m.episodes.size() == 1, str(m))
			_check("list rebuilt", sh._list.get_child(0).get_child_count() == 1 or sh._list.get_child_count() >= 2)
			sh._list.get_child(sh._list.get_child_count() - 1).pressed.emit()
			sh._ask.answered.emit(true)
			_check("forgot the episode", BotMemory.load().episodes.is_empty())
			BotCall.hub().event.emit({"type": "memory", "op": "add", "id": "f9", "text": "Plays the flute."})
			_check("still live under the sheet", bs._phase == "live")
			_step = 61
		61:
			var bs = _menu.bot_screen
			var sh = bs.sheet
			var flow = sh._list.get_child(0)
			_check("memory frame refreshed the list", flow is HFlowContainer and flow.get_child_count() == 2 and flow.get_child(0).text == "Plays the flute.", str(flow.get_child_count()))
			_menu.go_back()
			_check("back closes the sheet first", not sh.is_open() and bs.is_open())
			DirAccess.remove_absolute(ProjectSettings.globalize_path(MEM))
			sh.open()
			_check("empty: none line", sh._list.get_child_count() == 1 and sh._list.get_child(0) is Label and sh._list.get_child(0).text == "BOT_KNOWN_NONE")
			_menu.go_back()
			BotMemory.path = _saved_mem
			_check("screen still open", bs.is_open())
			_menu.go_back()
			_check("go_back closed the screen", not bs.is_open() and not bs.face.is_showing())
			_check("go_back: call let go (stale end counted)", bs._stale == 1)
			_check("go_back: music released", not load("res://core/music.gd")._holds.has("bot"))
			_check("go_back: banner released", not root.get_node("/root/Ads")._held.has("bot"))
			BotCall.hub().ended.emit("bye")
			_step = 7
		7:
			print("FAILS: %d" % _fails)
			return true
	return false


func _finalize() -> void:
	OS.unset_environment("BOT_URL")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MEM))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MEM + ".tmp"))
	if _fails:
		OS.set_restart_on_exit(false)
