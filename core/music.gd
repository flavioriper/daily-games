extends RefCounted

## The soundtrack (the user, 2026-11-01): twelve quiet tracks that run one
## into the next behind every screen, on a bus of their own under Master, so
## the Sound switch and the ad's quiet still silence them. The settings sheet's
## player (ui/hud/music_player.gd) is the only door: play and pause, next,
## mute and the volume bar. Choices are saved beside Sound's in the same file.
##
## Started only by world/main.gd (`start(host)`), so tests and harnesses stay
## silent; everything else here is safe to call before that, and does nothing
## audible. A screen with a beat of its own to hear (Drumbeat, Birdsong, the
## Marigold bloom, the opening's tune) asks for silence with `hold`.
##
## The deck runs on `_process`, never a looping tween, because it has to go on
## while the game rests (core/power.gd). Tracks are in tools/gen_music.py, which
## keeps this same order and treats the files.

const Motion = preload("res://core/motion.gd")
const Sound = preload("res://core/sound.gd")

const BUS := "Music"
const DIR := "res://assets/music/"
const TRACKS: Array[Dictionary] = [
	{"id": "garden_walk", "title": "Garden Walk"},
	{"id": "sandal_hop", "title": "Sandal Hop"},
	{"id": "fairway_morning", "title": "Fairway Morning"},
	{"id": "sunny_bench", "title": "Sunny Bench"},
	{"id": "palm_shade", "title": "Palm Shade"},
	{"id": "balcony_breeze", "title": "Balcony Breeze"},
	{"id": "island_breakfast", "title": "Island Breakfast"},
	{"id": "hillside_picnic", "title": "Hillside Picnic"},
	{"id": "rain_on_the_window", "title": "Rain on the Window"},
	{"id": "bobbing_boats", "title": "Bobbing Boats"},
	{"id": "meadow_skip", "title": "Meadow Skip"},
	{"id": "village_square", "title": "Village Square"},
]
## The bar's resting place. The files sit at -20 LUFS, so this is low already.
const VOLUME := 0.7
## One track into the next when it runs out, and when Next is pressed.
const CROSS := 2.5
const CROSS_NEXT := 0.5
## Play, pause and a hold fade rather than cut.
const DUCK := 0.35
const SILENT := 0.0001

class Notifier extends RefCounted:
	signal changed

## Said when the track or any choice changes; the player redraws on it.
static var news := Notifier.new()
static var playing := true
static var muted := false
static var volume := VOLUME
static var index := 0
static var _holds: Dictionary = {}
static var _deck: Deck

## Two players, so the old track can fade under the new one.
class Deck extends Node:
	var _music: Script
	var players: Array[AudioStreamPlayer] = []
	var active := 0
	var fades := [0.0, 0.0]
	var cross_rate := 1.0 / CROSS
	var duck := 0.0
	var away := false

	func _init() -> void:
		name = "Music"
		process_mode = Node.PROCESS_MODE_ALWAYS
		_music = load("res://core/music.gd")

	func _ready() -> void:
		for k in 2:
			var p := AudioStreamPlayer.new()
			p.bus = BUS
			p.volume_db = linear_to_db(SILENT)
			add_child(p)
			players.append(p)

	## Bring track `at` in on the idle player and let the other fade out.
	func deal(at: int, rate: float) -> void:
		var path: String = DIR + String(TRACKS[at].id) + ".ogg"
		if not ResourceLoader.exists(path):
			return
		active = 1 - active
		cross_rate = rate
		players[active].stream = load(path)
		players[active].stream_paused = false
		players[active].play()

	func _process(delta: float) -> void:
		var live: AudioStreamPlayer = players[active]
		var wanted: bool = _music.should_sound() and not away
		duck = move_toward(duck, 1.0 if wanted else 0.0, delta / DUCK)
		var still := duck <= 0.0
		for p: AudioStreamPlayer in players:
			p.stream_paused = still
		if still:
			return
		if live.stream == null:
			deal(_music.index, 1.0 / CROSS)
			live = players[active]
		for k in 2:
			fades[k] = move_toward(fades[k], 1.0 if k == active else 0.0, delta * cross_rate)
			players[k].volume_db = linear_to_db(max(fades[k] * duck, SILENT))
			if fades[k] <= 0.0 and players[k].playing:
				players[k].stop()
		if live.playing and live.stream.get_length() - live.get_playback_position() < CROSS:
			_music.advance(1.0 / CROSS)

	func _notification(what: int) -> void:
		match what:
			NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
				away = true
				duck = 0.0
				for p: AudioStreamPlayer in players:
					p.stream_paused = true
			NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
				away = false

static func should_sound() -> bool:
	return playing and _holds.is_empty() and Sound.on

static func held() -> bool:
	return not _holds.is_empty()

static func title() -> String:
	return String(TRACKS[index].title)

static func load_settings() -> void:
	var cfg := ConfigFile.new()
	playing = true
	muted = false
	volume = VOLUME
	index = 0
	if cfg.load(Motion.settings_path) == OK:
		playing = bool(cfg.get_value("music", "playing", true))
		muted = bool(cfg.get_value("music", "muted", false))
		volume = clampf(float(cfg.get_value("music", "volume", VOLUME)), 0.0, 1.0)
		index = posmod(int(cfg.get_value("music", "track", 0)), TRACKS.size())

static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Motion.settings_path)  # keeps other sections; a missing file is fine
	cfg.set_value("music", "playing", playing)
	cfg.set_value("music", "muted", muted)
	cfg.set_value("music", "volume", volume)
	cfg.set_value("music", "track", index)
	cfg.save(Motion.settings_path)

## The launch: the bus, the deck and the next track on from the last visit.
static func start(host: Node) -> void:
	load_settings()
	_ensure_bus()
	apply()
	index = posmod(index + 1, TRACKS.size())
	_save()
	_deck = Deck.new()
	host.add_child(_deck)

static func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	AudioServer.add_bus()
	var at := AudioServer.bus_count - 1
	AudioServer.set_bus_name(at, BUS)
	AudioServer.set_bus_send(at, "Master")

## The bar is squared, so its top half does the fine work an ear hears.
static func apply() -> void:
	var at := AudioServer.get_bus_index(BUS)
	if at < 0:
		return
	AudioServer.set_bus_volume_db(at, linear_to_db(max(volume * volume, SILENT)))
	AudioServer.set_bus_mute(at, muted or volume <= 0.0)

static func set_playing(on: bool) -> void:
	playing = on
	_save()
	news.changed.emit()

static func toggle() -> void:
	set_playing(not playing)

static func set_muted(on: bool) -> void:
	muted = on
	apply()
	_save()
	news.changed.emit()

## A drag calls this on every step; `save` waits for the finger to lift.
static func set_volume(value: float, save := true) -> void:
	volume = clampf(value, 0.0, 1.0)
	if muted and volume > 0.0:
		muted = false
	apply()
	if save:
		_save()
	news.changed.emit()

## Next: on to the following track, and playing if it was paused.
static func next() -> void:
	playing = true
	advance(1.0 / CROSS_NEXT)

static func advance(rate: float) -> void:
	index = posmod(index + 1, TRACKS.size())
	if _deck != null:
		_deck.deal(index, rate)
	_save()
	news.changed.emit()

## Silence while `who` holds it. Nothing is lost: the track waits where it was.
static func hold(who: String, on: bool) -> void:
	if on:
		_holds[who] = true
	else:
		_holds.erase(who)
	news.changed.emit()
