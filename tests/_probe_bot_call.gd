extends SceneTree
## Throwaway probe for bot/call.gd against tools/bot_echo.py on 127.0.0.1:8765.
## PROBE_REAL=1 runs only the real 60 s timeout.

const BASE := "ws://127.0.0.1:8765/"
var _host: Node
var _events: Array = []
var _ended := ""
var _ended_at := 0
var _fails := 0


func _initialize() -> void:
	_host = Node.new()
	root.add_child(_host)
	BotCall.hub().event.connect(func(m): _events.append(m))
	BotCall.hub().ended.connect(func(r): _ended = r; _ended_at = Time.get_ticks_msec())
	BotCall.test_tone_hz = 440.0
	_run.call_deferred()


func _check(name: String, ok: bool, info := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("  (" + info + ")" if info != "" else ""))
	if not ok:
		_fails += 1


func _wait(sec: float) -> void:
	var until := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _wait_for(cond: Callable, sec: float) -> bool:
	var until := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _reset() -> void:
	_events.clear()
	_ended = ""


func _has(type: String) -> bool:
	return _events.any(func(m): return m.get("type") == type)


func _run() -> void:
	print("mix rate ", AudioServer.get_mix_rate(), " url() ", BotCall.url())
	if OS.get_environment("PROBE_REAL") == "1":
		_reset()
		var t0 := Time.get_ticks_msec()
		var where := "ws://127.0.0.1:8766/ws/bot" if OS.get_environment("PROBE_MUTE") == "1" else BASE + "paused"
		BotCall.start(_host, where, "dummy", {}, "en")
		await _wait_for(func(): return _ended != "", 70.0)
		var s := (_ended_at - t0) / 1000.0
		_check("real timeout at 60 s", _ended == "timeout" and s >= 59.9 and s < 61.5, "%s after %.2f s" % [_ended, s])
		_end()
		return

	# offline
	_reset()
	BotCall.start(_host, BASE + "normal", "", {}, "en")
	_check("offline: nothing dialled", BotCall.current() == null and _host.get_child_count() == 0)
	await _wait_for(func(): return _ended != "", 0.5)
	_check("offline: ended(offline)", _ended == "offline", _ended)

	# normal call
	_reset()
	var t0 := Time.get_ticks_msec()
	BotCall.start(_host, BASE + "normal", "dummy", {"facts": [], "episodes": []}, "en")
	BotCall.start(_host, BASE + "normal", "dummy", {}, "en")  # refused: one call at a time
	_check("second start refused", _host.get_child_count() == 1)
	var got := await _wait_for(func(): return _has("session"), 2.0)
	_check("session within 2 s", got, "%.2f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	await _wait(1.5)
	var c := BotCall.current()
	var up := c.frames_up if c else 0
	var pushed := c.samples_pushed if c else 0
	_check("frames up (~50/s)", up >= 60 and up <= 90, "%d frames in ~1.5 s" % up)
	_check("echo pushed into generator", pushed > 0, "%d samples at 24 kHz (expect ~%d)" % [pushed, up * 480])
	_check("playing() while voice queued", BotCall.playing())
	_check("level() in 0..1", BotCall.level() >= 0.0 and BotCall.level() <= 1.0, str(BotCall.level()))
	BotCall.send_silence(true)
	await _wait(0.3)
	BotCall.send_silence(false)
	BotCall.interrupt()
	got = await _wait_for(func(): return _has("clear"), 1.0)
	_check("interrupt -> clear event", got)
	await _wait(0.3)
	var after_a: int = BotCall.current().samples_pushed
	await _wait(0.5)
	var after_b: int = BotCall.current().samples_pushed
	_check("voice plays again after clear", after_b > after_a and BotCall.current()._pb != null, "%d -> %d" % [after_a, after_b])
	var pb_drained := await _wait_for(func(): return BotCall.current() != null and BotCall.current()._down.is_empty(), 1.0)
	_check("clear dropped the queue", pb_drained)
	var mic_count := AudioServer.get_bus_index("Swarm")
	_check("Swarm bus exists", mic_count >= 0)
	_check("heartbeat every 10 s", is_equal_approx(BotCall.current()._peer.heartbeat_interval, 10.0), str(BotCall.current()._peer.heartbeat_interval))
	await _wait_for(func(): return not BotCall.current()._down.is_empty(), 1.0)
	var cc := BotCall.current()
	t0 = Time.get_ticks_msec()
	BotCall.stop()
	_check("stop: queued voice dropped, fade begun", cc._down.is_empty() and cc._fade_left > 0.0, "down %d fade %.3f" % [cc._down.size(), cc._fade_left])
	var pushed_at_stop := cc.samples_pushed
	await _wait(0.15)
	if is_instance_valid(cc) and not cc._done:
		_check("stop: no voice pushed after the bye", cc.samples_pushed == pushed_at_stop and cc._down.is_empty(), "%d -> %d" % [pushed_at_stop, cc.samples_pushed])
	await _wait_for(func(): return _ended != "", 7.0)
	_check("stop -> ended(bye) with bye_ack", _ended == "bye" and _has("bye_ack") and _has("memory"), "%s after %.2f s, events %s" % [_ended, (_ended_at - t0) / 1000.0, _events.map(func(m): return m.get("type"))])
	await process_frame
	await process_frame
	_check("nothing left running", BotCall.current() == null and _host.get_child_count() == 0)

	# the fixed server: memory and bye_ack back to back, then it waits for our close
	_reset()
	BotCall.start(_host, BASE + "eagerclose", "dummy", {}, "en")
	await _wait_for(func(): return _has("session"), 2.0)
	BotCall.stop()
	await _wait_for(func(): return _ended != "", 7.0)
	_check("eager close (fixed server) -> memory + bye_ack + ended(bye)", _ended == "bye" and _has("bye_ack") and _has("memory"), str(_events.map(func(m): return m.get("type"))))

	# the server before the fix: closes right behind bye_ack
	_reset()
	BotCall.start(_host, BASE + "oldclose", "dummy", {}, "en")
	await _wait_for(func(): return _has("session"), 2.0)
	BotCall.stop()
	await _wait_for(func(): return _ended != "", 7.0)
	print("INFO oldclose: ended %s, got bye_ack %s, got memory %s (Godot drops frames read with the close)" % [_ended, _has("bye_ack"), _has("memory")])

	# a slow remembering: four memory frames 4 s apart, then bye_ack (~12 s)
	_reset()
	BotCall.start(_host, BASE + "remember", "dummy", {}, "en")
	await _wait_for(func(): return _has("session"), 2.0)
	t0 = Time.get_ticks_msec()
	BotCall.stop()
	await _wait_for(func(): return _ended != "", 20.0)
	var mems := _events.filter(func(m): return m.get("type") == "memory").size()
	_check("slow remembering -> all memory then ended(bye)", _ended == "bye" and mems == 5 and _has("bye_ack"), "%s after %.2f s, %d memory frames" % [_ended, (_ended_at - t0) / 1000.0, mems])

	# remembering that never ends: capped at 30 s after stop()
	_reset()
	BotCall.start(_host, BASE + "forever", "dummy", {}, "en")
	await _wait_for(func(): return _has("session"), 2.0)
	t0 = Time.get_ticks_msec()
	BotCall.stop()
	await _wait_for(func(): return _ended != "", 35.0)
	var cap_s := (_ended_at - t0) / 1000.0
	_check("endless remembering -> ended(bye) at 30 s", _ended == "bye" and cap_s >= 29.9 and cap_s < 30.6, "%s after %.2f s" % [_ended, cap_s])
	await process_frame
	_check("nothing left running", BotCall.current() == null and _host.get_child_count() == 0)

	# connect_to_url fails inside start(): a listener connected right after start() still hears ended
	_reset()
	var late := [""]
	BotCall.start(_host, "bogus://nowhere", "dummy", {}, "en")
	var heard := func(r): late[0] = r
	BotCall.hub().ended.connect(heard)
	await process_frame
	await process_frame
	BotCall.hub().ended.disconnect(heard)
	_check("ended is deferred: a listener connected after start() hears it", late[0] == "dropped" and BotCall.current() == null, late[0])

	# no bye_ack
	_reset()
	BotCall.start(_host, BASE + "noack", "dummy", {}, "en")
	await _wait_for(func(): return _has("session"), 2.0)
	t0 = Time.get_ticks_msec()
	BotCall.stop()
	await _wait_for(func(): return _ended != "", 33.0)
	var s := (_ended_at - t0) / 1000.0
	_check("stop without bye_ack -> bye at 30 s (the server's end budget is 25)", _ended == "bye" and s >= 29.9 and s <= 30.6, "%s after %.2f s" % [_ended, s])
	await process_frame
	_check("nothing left running", BotCall.current() == null and _host.get_child_count() == 0)

	# the client's own cap: a call live past CALL_MAX says bye by itself
	_reset()
	BotCall.start(_host, BASE + "normal", "dummy", {}, "en")
	await _wait_for(func(): return _has("session"), 2.0)
	BotCall.current()._live_at -= int((BotCall.CALL_MAX + 1.0) * 1000.0)
	await process_frame
	_check("past CALL_MAX: stopping", BotCall.current() != null and BotCall.current()._stopping)
	await _wait_for(func(): return _ended != "", 3.0)
	_check("past CALL_MAX: ended(bye) with bye_ack", _ended == "bye" and _has("bye_ack"), _ended)
	await process_frame

	# 4429
	_reset()
	BotCall.start(_host, BASE + "refuse4429", "dummy", {}, "en")
	await _wait_for(func(): return _ended != "", 3.0)
	_check("server closes 4429 -> ended(4429)", _ended == "4429", _ended)

	# nothing listening
	_reset()
	BotCall.start(_host, "ws://127.0.0.1:8799/ws/bot", "dummy", {}, "en")
	await _wait_for(func(): return _ended != "", 5.0)
	_check("no server -> ended(dropped)", _ended == "dropped", _ended)

	# host freed mid-call
	_reset()
	var h2 := Node.new()
	root.add_child(h2)
	BotCall.start(h2, BASE + "normal", "dummy", {}, "en")
	await _wait_for(func(): return _has("session"), 2.0)
	h2.queue_free()
	await _wait_for(func(): return _ended != "", 1.0)
	_check("host freed -> ended(dropped), call cleared", _ended == "dropped" and BotCall.current() == null, _ended)

	# paused server, short timeout
	_reset()
	BotCall.connect_timeout = 3.0
	t0 = Time.get_ticks_msec()
	BotCall.start(_host, BASE + "paused", "dummy", {}, "en")
	await _wait_for(func(): return _ended != "", 5.0)
	s = (_ended_at - t0) / 1000.0
	_check("no session -> ended(timeout) at connect_timeout (3 s here)", _ended == "timeout" and s >= 2.9 and s < 3.5, "%s after %.2f s" % [_ended, s])

	# the upgrade never answered (a server still waking): still our clock that ends it
	_reset()
	t0 = Time.get_ticks_msec()
	BotCall.start(_host, "ws://127.0.0.1:8766/ws/bot", "dummy", {}, "en")
	await _wait_for(func(): return _ended != "", 5.0)
	s = (_ended_at - t0) / 1000.0
	_check("handshake hangs -> ended(timeout) at connect_timeout", _ended == "timeout" and s >= 2.9 and s < 3.5, "%s after %.2f s" % [_ended, s])
	_end()


func _end() -> void:
	print("DONE fails=%d" % _fails)
	quit(1 if _fails > 0 else 0)
