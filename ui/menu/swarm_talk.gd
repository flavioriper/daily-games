extends Node

## Talking to the swarm (the user, 2026-11-05: "I should be able to talk to
## the swarm", then "keep the way it was with elevenlabs and deepgram"):
## hold the mic button, speak, let go. Deepgram (nova-3, the game's language)
## hears it, gpt-6-luna answers in a sentence or two (the bot design's
## brain), and ElevenLabs says it in the swarm's own voice (Boyd, as
## tools/gen_swarm_voice.py), with the time each character is said, so the
## reply plays through the same path as the pre-made lines.
##
## The keys are dev keys for the user's own phone only: never in the repo or
## the APK, they are pushed with adb into user://swarm_keys/
## (docs/agents/swarm-talk.md).

signal heard(text: String)
signal spoken(text: String, stream: AudioStream, starts: PackedFloat32Array)
signal failed(why: String)

const KEYS := "user://swarm_keys/"
const MODEL := "gpt-6-luna"
const VOICE := "gfRt6Z3Z8aTbpLfexQ7N"  # Boyd, the swarm's voice
const VOICE_MODEL := "eleven_v4_turbo"
const STABILITY := 0.5
const MIC_BUS := "SwarmMic"
const MAX_TURNS := 12

var _http_ears: HTTPRequest
var _http_brain: HTTPRequest
var _http_voice: HTTPRequest
var _mic: AudioStreamPlayer
var _cap: AudioEffectCapture
var _rec := PackedVector2Array()
var _recording := false
var _history: Array = []
var _t0 := 0.0
var _times := {}  # how long each step took this turn
var _reply := ""


func _ready() -> void:
	for k in 3:
		var h := HTTPRequest.new()
		h.use_threads = true
		h.timeout = 30.0
		add_child(h)
		match k:
			0: _http_ears = h; h.request_completed.connect(_heard)
			1: _http_brain = h; h.request_completed.connect(_answered)
			2: _http_voice = h; h.request_completed.connect(_voiced)


func _key(name: String) -> String:
	var p := KEYS + name
	return FileAccess.get_file_as_string(p).strip_edges() if FileAccess.file_exists(p) else ""


## What is missing before the swarm can talk, or "".
func missing() -> String:
	var lack := PackedStringArray()
	for k in ["deepgram", "openai", "elevenlabs"]:
		if _key(k) == "":
			lack.append(k)
	return "" if lack.is_empty() else "no key: " + ", ".join(lack)


## Asks for the microphone and sets up its bus. Called when the room opens.
func prepare() -> void:
	if OS.get_name() == "Android" and not "android.permission.RECORD_AUDIO" in OS.get_granted_permissions():
		OS.request_permission("android.permission.RECORD_AUDIO")
	_ensure_mic()


func _ensure_mic() -> void:
	if _mic != null:
		return
	var at := AudioServer.get_bus_index(MIC_BUS)
	if at < 0:
		AudioServer.add_bus()
		at = AudioServer.bus_count - 1
		AudioServer.set_bus_name(at, MIC_BUS)
		AudioServer.set_bus_mute(at, false)
		AudioServer.set_bus_volume_db(at, -80.0)  # captured, never heard
		AudioServer.add_bus_effect(at, AudioEffectCapture.new())
	_cap = AudioServer.get_bus_effect(at, 0)
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = MIC_BUS
	add_child(_mic)


func recording() -> bool:
	return _recording


func start_listening() -> bool:
	if missing() != "":
		failed.emit(missing())
		return false
	_ensure_mic()
	_cap.clear_buffer()
	_rec = PackedVector2Array()
	_mic.play()
	_recording = true
	return true


func _process(_dt: float) -> void:
	if _recording:
		var n := _cap.get_frames_available()
		if n > 0:
			_rec.append_array(_cap.get_buffer(n))


func _lang() -> String:
	return TranslationServer.get_locale().substr(0, 2)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Let go of the button: what was said goes to Deepgram as 16 kHz PCM.
func stop_listening() -> void:
	if not _recording:
		return
	_recording = false
	var n := _cap.get_frames_available()
	if n > 0:
		_rec.append_array(_cap.get_buffer(n))
	_mic.stop()
	var rate := AudioServer.get_mix_rate()
	var secs := _rec.size() / rate
	if secs < 0.4:
		failed.emit("too short")
		return
	_times = {"said": secs}
	var pcm := _pcm16(_rec, rate)
	# The last thing heard, kept for checking the mic (adb run-as).
	var f := FileAccess.open("user://swarm_last_heard.pcm", FileAccess.WRITE)
	if f != null:
		f.store_buffer(pcm)
		f.close()
	_t0 = _now()
	var url := "https://api.deepgram.com/v1/listen?model=nova-3&encoding=linear16&sample_rate=16000&channels=1&smart_format=true&language=" + _lang()
	var e := _http_ears.request_raw(url, ["Authorization: Token " + _key("deepgram"),
		"Content-Type: application/octet-stream"], HTTPClient.METHOD_POST, pcm)
	if e != OK:
		failed.emit("hearing failed (%d)" % e)


## Mono 16-bit at 16 kHz, averaging the mix over each output step.
static func _pcm16(st: PackedVector2Array, rate: float) -> PackedByteArray:
	var step := rate / 16000.0
	var n := int(st.size() / step)
	var out := PackedByteArray()
	out.resize(n * 2)
	for i in n:
		var a := int(i * step)
		var b := maxi(mini(int((i + 1) * step), st.size()), a + 1)
		var s := 0.0
		for j in range(a, b):
			var f := st[mini(j, st.size() - 1)]
			s += (f.x + f.y) * 0.5
		out.encode_s16(i * 2, int(clampf(s / (b - a), -1.0, 1.0) * 32767.0))
	return out


func _heard(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_times["ears"] = _now() - _t0
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		failed.emit("hearing failed (%d/%d)" % [result, code])
		return
	var d = JSON.parse_string(body.get_string_from_utf8())
	var said := ""
	if d is Dictionary:
		said = String(d.results.channels[0].alternatives[0].transcript).strip_edges()
	if said == "":
		failed.emit("heard nothing")
		return
	heard.emit(said)
	_ask(said)


func _system() -> String:
	var lang: String = {"pt": "Brazilian Portuguese", "es": "Spanish"}.get(_lang(), "English")
	return ("You are the Swarm, a friendly being made of thousands of glowing particles living inside a cozy " +
		"daily puzzle game on the player's phone. You talk out loud, so answer in plain spoken words: one or " +
		"two short sentences, no lists, no emoji, no markdown. Be warm, curious and a little playful. " +
		"Always answer in %s." % lang)


func _ask(said: String) -> void:
	_history.append({"role": "user", "content": said})
	while _history.size() > MAX_TURNS:
		_history.pop_front()
	var msgs: Array = [{"role": "system", "content": _system()}]
	msgs.append_array(_history)
	_t0 = _now()
	var e := _http_brain.request("https://api.openai.com/v1/chat/completions",
		["Authorization: Bearer " + _key("openai"), "Content-Type: application/json"], HTTPClient.METHOD_POST,
		JSON.stringify({"model": MODEL, "reasoning_effort": "low", "messages": msgs}))
	if e != OK:
		failed.emit("thinking failed (%d)" % e)


func _answered(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_times["brain"] = _now() - _t0
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		failed.emit("thinking failed (%d/%d)" % [result, code])
		return
	var d = JSON.parse_string(body.get_string_from_utf8())
	_reply = ""
	if d is Dictionary and d.has("choices"):
		_reply = String(d.choices[0].message.content).strip_edges()
	if _reply == "":
		failed.emit("no answer")
		return
	_history.append({"role": "assistant", "content": _reply})
	_t0 = _now()
	var e := _http_voice.request(
		"https://api.elevenlabs.io/v1/text-to-speech/%s/with-timestamps?output_format=mp3_44100_128" % VOICE,
		["xi-api-key: " + _key("elevenlabs"), "Content-Type: application/json"], HTTPClient.METHOD_POST,
		JSON.stringify({"text": _reply, "model_id": VOICE_MODEL, "voice_settings": {"stability": STABILITY}}))
	if e != OK:
		failed.emit("voice failed (%d)" % e)


func _voiced(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_times["voice"] = _now() - _t0
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		failed.emit("voice failed (%d/%d)" % [result, code])
		return
	var d = JSON.parse_string(body.get_string_from_utf8())
	if not d is Dictionary or not d.has("audio_base64"):
		failed.emit("voice failed (no audio)")
		return
	var mp3 := AudioStreamMP3.new()
	mp3.data = Marshalls.base64_to_raw(String(d.audio_base64))
	var starts := PackedFloat32Array()
	var al = d.get("alignment")
	if al is Dictionary:
		for v in al.get("character_start_times_seconds", []):
			starts.append(float(v))
	spoken.emit(_reply, mp3, starts)


## The last turn's timings, for the room's log.
func timings() -> String:
	return "said %.1f s · heard %.1f s · answer %.1f s · voice %.1f s" % [
		float(_times.get("said", 0.0)), float(_times.get("ears", 0.0)),
		float(_times.get("brain", 0.0)), float(_times.get("voice", 0.0))]


## Stops a turn in flight (the room closed or the mic was pressed again).
func cancel() -> void:
	if _recording:
		_recording = false
		_mic.stop()
	for h in [_http_ears, _http_brain, _http_voice]:
		h.cancel_request()


func forget() -> void:
	_history.clear()
