class_name BotCall
extends Node

## The phone's side of the Swarm's call socket (server/bot, docs/agents/bot.md):
## one WebSocketPeer, the mic up as 16 kHz int16 mono frames of 20 ms, the
## Swarm's voice down as 24 kHz int16 into an AudioStreamGenerator on the
## `Swarm` bus, and every JSON frame out as `event`. Static: one call at a
## time. `start` hangs a small poller (an instance of this script) on the host;
## the call's end frees it, the mic player and the voice player with it.
##
## Signals live on a hub that outlives every call (GDScript has no static
## signals): `BotCall.hub().event` (every JSON frame, a Dictionary) and
## `BotCall.hub().ended` (reason: "bye", "4401", "4429", "4409", "dropped",
## "timeout", "offline"). Exactly one `ended` per accepted `start`, always
## deferred (a listener connected right after `start`, or a host being torn
## down, is safe); a refused second `start` emits nothing.
##
## Nothing here asks for the mic permission or reads `Backend`: the screen
## does both and hands `start` the token ("" means offline, nothing dialled).

## The screen gates the mic with send_silence: zeros go up in the mic's place
## whenever the talk button is not held (hold to talk, 2026-11-05), so the
## frames keep their pace and the server hears silence, never a gap.
## Where the call server lives. In a debug build only, overridden by the BOT_URL
## environment variable, then by the first line of user://bot_url (a phone
## pointed at a Mac's server). The Cloud Run service `peeplet-bot` in
## daily-games-420bf, deployed 2026-11-05. While the address is the placeholder
## the Bot chip is not shown (`configured`).
const BOT_URL := "wss://peeplet-bot-ao7js3tmhq-uc.a.run.app/ws/bot"
const PLACEHOLDER := "wss://peeplet-bot.invalid/ws/bot"
const URL_FILE := "user://bot_url"
const VOICE_BUS := "Swarm"
const MIC_BUS := "SwarmMic"
const UP_RATE := 16000.0
const DOWN_RATE := 24000
const FRAME := 320  # samples up per frame, 20 ms at 16 kHz
const LEAD := 0.2  # seconds of voice kept in the generator; the rest waits in our queue
const FADE := 0.05  # a `clear` winds the voice down over this
## After `bye` the server's end-of-call memory may take up to 25 s (END_MEMORY_S)
## before `bye_ack`: the call waits the whole thirty, never less.
const BYE_MAX := 30.0
const BYE_WAIT := BYE_MAX
## A call live this long is ended here (the server's own cap is fifteen
## minutes), so a lost server can never hold the game and the screen awake.
const CALL_MAX := 16.0 * 60.0
## The socket pings this often, so a dead line is noticed and closed.
const HEARTBEAT := 10.0
## The button held and the mic giving nothing but exact zeros this long: the
## mic was refused (iOS gives silence, not an error).
const MIC_DEAD := 1.5

## No `session` this long after `start` ends the call with "timeout" (a cold
## start of the server can take forty seconds). A probe may shorten it.
static var connect_timeout := 60.0
## Test hook: when > 0 no mic is opened and a tone of this pitch, made at the
## mix rate as the capture would give it, goes up the same path (headless has
## no mic).
static var test_tone_hz := 0.0

class Hub:
	extends RefCounted
	signal event(msg: Dictionary)
	signal ended(reason: String)

static var _hub := Hub.new()
static var _call: BotCall

# --- the poller's own state ---
var _peer := WebSocketPeer.new()
var _hello := {}
var _t0 := 0  # ticks at start; the clocks below are the wall clock, not summed deltas
var _live := false  # `session` came
var _live_at := 0
var _heard_at := 0  # ticks of the last non-zero mic sample, or of the button's press
var _stopping := false
var _bye_at := 0
var _stop_at := 0
var _done := false
var _silence := false
# up
var _mic: AudioStreamPlayer
var _cap: AudioEffectCapture
var _rate := 44100.0
var _src := PackedFloat32Array()  # mono at the mix rate, not yet averaged down
var _pos := 0.0  # where the next output sample starts in _src
var _up := PackedByteArray()  # int16 at 16 kHz waiting to fill a frame
var _tone_t := 0.0
var _tone_phase := 0.0
# down
var _voice: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _room := 0  # the generator's capacity in frames
var _down := PackedByteArray()  # int16 at 24 kHz not yet in the generator
var _fade_left := -1.0
## Counters a probe reads.
var frames_up := 0
var samples_pushed := 0


# --- the static face ---

static func hub() -> Hub:
	return _hub


## The server's address: the constant, then the environment, then the file.
static func url() -> String:
	var u := BOT_URL
	if not OS.is_debug_build():
		return u
	var env := OS.get_environment("BOT_URL").strip_edges()
	if env != "":
		u = env
	if FileAccess.file_exists(URL_FILE):
		var line := FileAccess.get_file_as_string(URL_FILE).get_slice("\n", 0).strip_edges()
		if line != "":
			u = line
	return u


## A real server to call: the Bot chip shows only then.
static func configured() -> bool:
	return url() != PLACEHOLDER


## Dials `url` and says hello with the token, the language and the phone's
## memory file. An empty token is offline: `ended("offline")` next frame. A
## second start while a call is live is refused with a warning and emits
## nothing (one call at a time; the live call's `ended` is still to come).
static func start(host: Node, address: String, token: String, memory: Dictionary, language: String) -> void:
	if _call != null:
		push_warning("BotCall: a call is already live")
		return
	if token == "":
		_hub.call_deferred("emit_signal", "ended", "offline")
		return
	var c := BotCall.new()
	c.name = "BotCall"
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	c._t0 = Time.get_ticks_msec()
	c._hello = {"type": "hello", "token": token, "language": language, "memory": memory}
	c._peer.inbound_buffer_size = 1 << 20  # replies come in bursts faster than they play
	c._peer.outbound_buffer_size = 1 << 20
	c._peer.max_queued_packets = 8192
	c._peer.heartbeat_interval = HEARTBEAT
	_call = c
	host.add_child(c)
	var err := c._peer.connect_to_url(address)
	if err != OK:
		c._finish("dropped")


## Says bye; the call ends at `bye_ack`, or thirty seconds after stop() without
## one. The Swarm's voice stops at once (faded, as a `clear`): what it was
## still saying, and any voice that comes after the bye, is dropped.
## With `now` (the app sent to the background, where nothing is waited for)
## the bye goes up and the call ends at once with "bye", the memory frames
## the server was still to send left unread.
static func stop(now := false) -> void:
	if _call == null or (_call._stopping and not now):
		return
	var c := _call
	if now:
		c._release_mic()
		if c._peer.get_ready_state() == WebSocketPeer.STATE_OPEN and c._live and not c._stopping:
			c._send({"type": "bye"})
			c._peer.poll()  # the frame leaves before the socket closes
		c._stopping = true
		c._finish("bye")
		return
	c._stopping = true
	c._stop_at = Time.get_ticks_msec()
	c._bye_at = c._stop_at + int(BYE_WAIT * 1000.0)
	c._release_mic()
	c._clear_voice()
	if c._peer.get_ready_state() == WebSocketPeer.STATE_OPEN and c._live:
		c._send({"type": "bye"})
	else:
		c._finish("bye")


static func interrupt() -> void:
	if _call != null:
		_call._send({"type": "interrupt"})


static func forget(id: String) -> void:
	if _call != null and id != "":
		_call._send({"type": "forget", "id": id})


## The answer to a `tool {name: "see", id}`: a jpg of what the Swarm was shown.
static func seen(id: String, jpg: PackedByteArray, w: int, h: int) -> void:
	if _call != null:
		_call._send({"type": "seen", "id": id, "jpg": Marshalls.raw_to_base64(jpg), "w": w, "h": h})


static func send_silence(on: bool) -> void:
	if _call != null:
		if _call._silence and not on:
			_call._heard_at = Time.get_ticks_msec()  # the press starts the clock
		_call._silence = on


## The mic is held open and has given only exact zeros (or nothing) for
## MIC_DEAD seconds: a refused mic. Never with the test tone.
static func mic_dead() -> bool:
	if _call == null or test_tone_hz > 0.0:
		return false
	var c := _call
	return c._live and not c._stopping and not c._silence and Time.get_ticks_msec() - c._heard_at >= int(MIC_DEAD * 1000.0)


static func live() -> bool:
	return _call != null and _call._live


## The Swarm's voice still has audio waiting or playing.
static func playing() -> bool:
	if _call == null:
		return false
	var c := _call
	if not c._down.is_empty():
		return true
	return c._pb != null and c._pb.get_frames_available() < c._room - 64


## Voice frames (24 kHz) the generator has played on this call: pushed, less
## what still waits in it. A screen reveals a line's words by it. A `clear`
## drops what waited, so it jumps forward there.
static func consumed() -> int:
	if _call == null:
		return 0
	var c := _call
	var waiting := 0
	if c._pb != null:
		waiting = maxi(0, c._room - c._pb.get_frames_available())
	return c.samples_pushed - waiting


## How loud the Swarm bus is right now, 0..1 (as the Swarm tab's face reads it).
static func level() -> float:
	var sp := spectrum()
	if sp == null:
		return 0.0
	var m := sp.get_magnitude_for_frequency_range(90.0, 4000.0)
	return clampf((linear_to_db(maxf(m.x, m.y)) + 52.0) / 34.0, 0.0, 1.0)


## The voice's own bus, with an analyser on it so a face can follow how loud
## it is; it sends to Master, so the Sound switch still silences it.
static func ensure_bus() -> void:
	var at := AudioServer.get_bus_index(VOICE_BUS)
	if at < 0:
		AudioServer.add_bus()
		at = AudioServer.bus_count - 1
		AudioServer.set_bus_name(at, VOICE_BUS)
		AudioServer.set_bus_send(at, "Master")
		var fx := AudioEffectSpectrumAnalyzer.new()
		fx.buffer_length = 0.1
		fx.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
		AudioServer.add_bus_effect(at, fx)


static func spectrum() -> AudioEffectSpectrumAnalyzerInstance:
	ensure_bus()
	return AudioServer.get_bus_effect_instance(AudioServer.get_bus_index(VOICE_BUS), 0) as AudioEffectSpectrumAnalyzerInstance


## The call on the line, for a probe's counters; null between calls.
static func current() -> BotCall:
	return _call


# --- the poller ---

func _process(dt: float) -> void:
	if _done:
		return
	_peer.poll()
	var st := _peer.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN and not _hello.is_empty():
		_send(_hello)
		_hello = {}
	# read what came even when the socket has just closed: a `bye_ack` and the
	# last `memory` messages arrive together with the close frame
	while _peer.get_available_packet_count() > 0:
		var pkt := _peer.get_packet()
		if _peer.was_string_packet():  # of the packet just taken
			_on_text(pkt.get_string_from_utf8())
		elif not _stopping:  # after bye the voice is not played
			_down.append_array(pkt)
		if _done:
			return
	if st == WebSocketPeer.STATE_CLOSED:
		var code := _peer.get_close_code()
		if _stopping or code == 1000:
			_finish("bye")
		elif code in [4401, 4429, 4409]:
			_finish(str(code))
		else:
			_finish("dropped")
		return
	if not _live and not _stopping and Time.get_ticks_msec() - _t0 >= int(connect_timeout * 1000.0):
		_finish("timeout")
		return
	if _stopping:
		if Time.get_ticks_msec() >= _bye_at:
			_finish("bye")
			return
	elif _live and Time.get_ticks_msec() - _live_at >= int(CALL_MAX * 1000.0):
		BotCall.stop()
	if _live and not _stopping:
		_pump_up(dt)
	_feed_voice(dt)


func _on_text(raw: String) -> void:
	var m = JSON.parse_string(raw)
	if not (m is Dictionary):
		return
	var kind := String(m.get("type", ""))
	match kind:
		"session":
			_live = true
			_live_at = Time.get_ticks_msec()
			_heard_at = _live_at
			_open_voice()
			_open_mic()
		"clear":
			_clear_voice()
		"bye_ack":
			_hub.event.emit(m)
			_peer.close(1000)  # the phone closes first; the server waits for it
			_finish("bye")
			return
	_hub.event.emit(m)


func _send(msg: Dictionary) -> void:
	if _peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var err := _peer.send_text(JSON.stringify(msg))
		if err != OK:
			push_warning("BotCall: %s not sent (%s)" % [msg.get("type"), error_string(err)])


func _finish(reason: String) -> void:
	if _done:
		return
	_done = true
	_release_mic()
	if _voice != null:
		_voice.stop()
		_voice.queue_free()
		_voice = null
		_pb = null
	var st := _peer.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN or st == WebSocketPeer.STATE_CONNECTING:
		_peer.close(1000)
	if _call == self:
		_call = null
	if is_inside_tree():
		queue_free()
	_hub.call_deferred("emit_signal", "ended", reason)


func _exit_tree() -> void:
	# The host went away mid-call (a screen freed without stop): hang up.
	if not _done:
		_finish("dropped")


# --- up: the mic, averaged down to 16 kHz, 20 ms a frame ---

func _open_mic() -> void:
	_rate = AudioServer.get_mix_rate()
	_src = PackedFloat32Array()
	_pos = 0.0
	_up = PackedByteArray()
	if test_tone_hz > 0.0:
		return
	var at := AudioServer.get_bus_index(MIC_BUS)
	if at < 0:
		AudioServer.add_bus()
		at = AudioServer.bus_count - 1
		AudioServer.set_bus_name(at, MIC_BUS)
		AudioServer.set_bus_mute(at, false)
		AudioServer.set_bus_volume_db(at, -80.0)  # captured, never heard
		var fx := AudioEffectCapture.new()
		fx.buffer_length = 0.5  # a slow frame never overflows the capture
		AudioServer.add_bus_effect(at, fx)
	_cap = AudioServer.get_bus_effect(at, 0) as AudioEffectCapture
	_cap.buffer_length = 0.5  # the bus may be the Swarm tab's, made at 0.1
	_cap.clear_buffer()
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = MIC_BUS
	add_child(_mic)
	_mic.play()


func _release_mic() -> void:
	if _mic != null:
		_mic.stop()
		_mic.queue_free()
		_mic = null
	if _cap != null:
		_cap.clear_buffer()
		_cap = null


func _pump_up(dt: float) -> void:
	var st: PackedVector2Array
	if test_tone_hz > 0.0:
		# a tone at the mix rate, as the capture would give it, by the clock
		_tone_t += dt * _rate
		var n := int(_tone_t)
		_tone_t -= n
		st.resize(n)
		for i in n:
			var v := sin(_tone_phase) * 0.25
			st[i] = Vector2(v, v)
			_tone_phase = fmod(_tone_phase + TAU * test_tone_hz / _rate, TAU)
	elif _cap != null:
		var n := _cap.get_frames_available()
		if n <= 0:
			return
		st = _cap.get_buffer(n)
	if st.is_empty():
		return
	var base := _src.size()
	_src.resize(base + st.size())
	var any := false
	for i in st.size():
		_src[base + i] = (st[i].x + st[i].y) * 0.5
		any = any or _src[base + i] != 0.0
	if any:
		_heard_at = Time.get_ticks_msec()
	# each output sample averages the input over its step; the fraction carries
	var step := _rate / UP_RATE
	while int(_pos + step) <= _src.size():
		var a := int(_pos)
		var b := maxi(int(_pos + step), a + 1)
		var s := 0.0
		for j in range(a, b):
			s += _src[j]
		var at := _up.size()
		_up.resize(at + 2)
		_up.encode_s16(at, int(clampf(s / (b - a), -1.0, 1.0) * 32767.0))
		_pos += step
	var used := int(_pos)
	if used > 0:
		_src = _src.slice(used)
		_pos -= used
	while _up.size() >= FRAME * 2:
		_send_frame(_up.slice(0, FRAME * 2))
		_up = _up.slice(FRAME * 2)


func _send_frame(f: PackedByteArray) -> void:
	if _silence:
		f.fill(0)
	if _peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_peer.send(f, WebSocketPeer.WRITE_MODE_BINARY)
		frames_up += 1


# --- down: the Swarm's voice, 24 kHz into a short generator ---

func _open_voice() -> void:
	ensure_bus()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = DOWN_RATE
	gen.buffer_length = 0.5
	_voice = AudioStreamPlayer.new()
	_voice.stream = gen
	_voice.bus = VOICE_BUS
	add_child(_voice)
	_voice.play()
	_pb = _voice.get_stream_playback() as AudioStreamGeneratorPlayback
	_room = _pb.get_frames_available() if _pb != null else 0


## `clear`: what is queued is dropped, the voice already in the generator is
## faded out over 50 ms by the player's volume, then the player restarts on an
## empty playback (a playing generator refuses clear_buffer).
func _clear_voice() -> void:
	_down = PackedByteArray()
	if _pb != null and _fade_left < 0.0:
		_fade_left = FADE


func _feed_voice(dt: float) -> void:
	if _pb == null:
		return
	if _fade_left >= 0.0:
		_fade_left -= dt
		if _fade_left > 0.0:
			_voice.volume_db = linear_to_db(maxf(_fade_left / FADE, 0.001))
			return
		# a playing generator refuses clear_buffer: a fresh playback is an empty one
		_voice.stop()
		_voice.volume_db = 0.0
		_voice.play()
		_pb = _voice.get_stream_playback() as AudioStreamGeneratorPlayback
		_fade_left = -1.0
		# whatever came after the `clear` (the next reply) plays from here
	if _down.size() < 2:
		return
	var filled := _room - _pb.get_frames_available()
	var want := int(LEAD * DOWN_RATE) - filled
	var n := mini(want, _down.size() / 2)
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	for i in n:
		var v := _down.decode_s16(i * 2) / 32768.0
		buf[i] = Vector2(v, v)
	_pb.push_buffer(buf)
	samples_pushed += n
	_down = _down.slice(n * 2)
