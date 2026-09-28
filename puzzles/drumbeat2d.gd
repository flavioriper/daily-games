extends "res://core/puzzle_base.gd"

## Drumbeat as a flat board: the drum-festival rhythm game on a garden stage
## at dusk. Berries with faces ride a wooden lane from the right into the
## hit ring on the left, in time with the day's song; strike the drum under
## the lane on its face for a red note (don) and on its rim -- or anywhere
## off the skin -- for a blue one (ka). A big note wants two fingers at once,
## a golden drumroll as many strokes as the player can give it, and a balloon
## that many dons before it pops. Clear the song -- end it with the soul
## gauge at or over its line -- and the day's board is solved. A song that
## ends under the line is played again, never lost.
##
## The rules, the judging and the score live in puzzles/drumbeat_state.gd,
## which has no clock of its own: this board keeps the song's clock off the
## music's playback position (corrected for the mix and the output latency,
## and smoothed by the frame clock between mixes) and hands it every frame
## and every stroke. The songs and their charts are tools/gen_drumbeat.py's:
## assets/sfx/drumbeat/song_<id>.ogg and content/drumbeat.json, written
## against the same bar grid so they cannot drift. A per-phone timing nudge
## (`_offset`, user://drumbeat.cfg) moves the notes against the music for a
## phone whose audio arrives late.
##
## How it is drawn. The stage, the lane and the hit ring's frame are one
## still mesh, rebuilt on a relayout; the drum is one cached mesh; every note,
## lantern and Tam's body and arms are cached meshes moved by the transform
## (ui/faces/drumbeat_parts.gd); the bar lines, the gauge, the bursts and the
## drum's ripples are one live mesh a frame.
##
## Spec: docs/superpowers/specs/2026-09-28-drumbeat-flat-design.md.

const State = preload("res://puzzles/drumbeat_state.gd")
const Parts = preload("res://ui/faces/drumbeat_parts.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Locale = preload("res://core/locale.gd")
const Rewards = preload("res://arcade/rewards.gd")
const UiSound = preload("res://ui/ui_sound.gd")

# --- the screen, measured (design pixels at a 1000-wide card) ---
const INSET := 22.0
const CARD_RADIUS := 32.0
## The band over the stage with the score and the soul gauge.
const BAND := 118.0
## The stage over the lane, and the lane.
const STAGE := 330.0
const LANE := 170.0
## The hit ring's centre from the lane's left end, and its radius.
const RING_X := 150.0
const RING_R := 62.0
const NOTE_R := 44.0
const BIG_R := 64.0
## Scroll speed, design pixels a second for every beat a minute.
const SPEED_PER_BPM := 4.4
## The drum: its skin's radius as a share of the room under the lane, capped.
const FACE_SHARE := 0.33
const FACE_MAX := 300.0
const RIM_OVER := 1.3
## A stroke this close to the skin's edge still counts as the skin.
const FACE_SLACK := 1.04
const VOICES := 6
const SCORE_FONT := 50
const KICKER_FONT := 24
const COMBO_FONT := 64
const JUDGE_FONT := 40
const TITLE_FONT := 60
const LINE_FONT := 32

# --- this board's own motion ---
const JUDGE_TIME := 0.4
const FLY_TIME := 0.42
const BURST_TIME := 0.3
const RIPPLE_TIME := 0.35
const FLASH_TIME := 0.18
const WIN_HOLD := 1.6
## The timing nudge's step and reach, in seconds.
const OFFSET_STEP := 0.01
const OFFSET_MAX := 0.3
const SETTINGS := "user://drumbeat.cfg"

const GOLD := Color("f2b632")
const LANE_WOOD := Color("7a5134")
const LANE_DEEP := Color("5a3a25")
const LANE_TRACK := Color("3f2c22")
const LANE_GOGO := Color("7a3a2a")
const SKY_TOP := Color("3d4a7a")
const SKY_LOW := Color("f2a37a")
const HILL := Color("6f7fa6")
const HILL_NEAR := Color("5d6c8f")
const STALL := Color("8c4a3a")
const STALL_ROOF := Color("c9593f")
const GAUGE_BACK := Color("4a3a30")
const GAUGE_FILL := Color("f59a6a")
const GAUGE_CLEAR := Color("f2c14e")
const JUDGE_COLS := [Color("f2b632"), Color("fff6e6"), Color("9fb3c8")]
const JUDGE_KEYS := ["DB_GOOD", "DB_OK", "DB_BAD"]
const LANTERN_COLS := [Color("f59a6a"), Color("f2c14e"), Color("f08aa6"), Color("f59a6a"), Color("8cc8ec"), Color("f2c14e")]

var fx: Node2D
var _rw: Rewards
var _songs: Array = []
var _song: Dictionary = {}
var _level := 0
var _st: State
## "ready" before the first stroke, "play", "paused", "missed" (ended under
## the line, waiting for a stroke to go again) and "won".
var _phase := "ready"
var _music: AudioStreamPlayer
var _don: Array = []
var _ka: Array = []
var _voice := 0
## The song's clock: its value at `_ticks_at` (microseconds).
var _clock := 0.0
var _ticks_at := 0
var _offset := 0.0
var _plays := 0
var _best_score := 0
var _log := ""

# motion, on the screen's own clock (seconds, `_now()`)
var _judges: Array = []   # {grade, at, big}
var _flies: Array = []    # {type, from, at}
var _bursts: Array = []   # {at, col, big, pos}
var _ripples: Array = []  # {at, face, side}
var _hit_face_at := -10.0
var _hit_rim_at := -10.0
var _rim_side := 1.0
var _arm_at := [-10.0, -10.0]
var _arm_next := 0
var _roll_pop := {}       # {n, at}
var _gogo_at := -10.0
var _soul_at := -10.0
var _mood := Parts.Mood.HAPPY
var _mood_until := 0.0
var _balloon_gone := {}   # i -> at

# cached meshes (the canvas keeps a mesh by RID, so each is held until replaced)
var _still: ArrayMesh
var _drum: ArrayMesh
var _shown: Array = []

func puzzle_id() -> String: return "drumbeat"
func title() -> String: return "Drumbeat"

func rules() -> String:
	return tr("DB_RULES")

## Nothing to take back or check: the song is its own judge. Reset (a fresh
## start of the song) is the host's.
func capabilities() -> Array[String]:
	return []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 3
	add_child(fx)
	_rw = Rewards.new()
	_rw.z_index = 4
	add_child(_rw)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	for pool in [[_don, "don"], [_ka, "ka"]]:
		var path := "res://assets/sfx/drumbeat/%s.ogg" % pool[1]
		var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
		for i in VOICES:
			var p := AudioStreamPlayer.new()
			p.stream = stream
			add_child(p)
			(pool[0] as Array).append(p)
	_load_offset()
	resized.connect(_layout)
	solved.connect(_on_solved)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_pause(true)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_songs = State.songs()
	_level = difficulty
	if _songs.is_empty():
		return
	_song = _songs[rng.randi() % _songs.size()]
	_music.stream = load(String(_song.file)) if ResourceLoader.exists(String(_song.file)) else null
	_best_score = 0
	_log = ""
	_plays = 0
	_fresh()
	_layout()
	fx.cue("enter")

## A new run at the song: the state, the clock and the motion, and the music
## stopped at its start.
func _fresh() -> void:
	_st = State.new(_song, _level)
	_music.stop()
	_phase = "ready"
	_clock = -0.5
	_ticks_at = Time.get_ticks_usec()
	_judges = []
	_flies = []
	_bursts = []
	_ripples = []
	_roll_pop = {}
	_balloon_gone = {}
	_mood = Parts.Mood.HAPPY
	if _rw != null:
		_rw.clear()
	queue_redraw()

func _start() -> void:
	_fresh()
	_phase = "play"
	_plays += 1
	_clock = 0.0
	_ticks_at = Time.get_ticks_usec()
	if _music.stream != null:
		_music.play()
	fx.cue("start", 1.0, -6.0)

func _pause(on: bool) -> void:
	if on and _phase == "play":
		_phase = "paused"
		_music.stream_paused = true
		queue_redraw()
	elif not on and _phase == "paused":
		_phase = "play"
		_music.stream_paused = false
		_ticks_at = Time.get_ticks_usec()
		queue_redraw()

# --- layout ---

func _u() -> float:
	return size.x / 1000.0

func _band_h() -> float:
	return BAND * _u()

func _lane_top() -> float:
	return (BAND + STAGE) * _u()

func _lane_mid() -> float:
	return _lane_top() + LANE * 0.5 * _u()

func _lane_bottom() -> float:
	return _lane_top() + LANE * _u()

func _ring() -> Vector2:
	return Vector2(RING_X * _u(), _lane_mid())

func _drum_c() -> Vector2:
	var room := size.y - _lane_bottom()
	return Vector2(size.x * 0.5, _lane_bottom() + room * 0.52)

func _face_r() -> float:
	return minf((size.y - _lane_bottom()) * FACE_SHARE, FACE_MAX * _u())

func card_height(available: float) -> float:
	return available

func card_centred() -> bool:
	return false

func _layout() -> void:
	_still = null
	_drum = null
	queue_redraw()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## The song's time now, from the last sync and the microsecond clock.
func song_now() -> float:
	if _phase != "play":
		return _clock
	return _clock + (Time.get_ticks_usec() - _ticks_at) / 1e6

## The time the notes and the judge read: the song's, less the nudge.
func view_t() -> float:
	return song_now() - _offset

func _speed() -> float:
	return float(_song.get("bpm", 120)) * SPEED_PER_BPM * _u()

# --- the frame loop ---

func _process(delta: float) -> void:
	super(delta)
	if _st == null:
		return
	if _phase == "play":
		_sync_clock()
		_st.update(view_t())
		_handle()
	_rw.bounds = Rect2(Vector2.ZERO, size)
	_rw.step(delta)
	queue_redraw()

## The clock follows the music: the playback position plus the time since
## the last mix, less what the output still holds. Between mixes the
## microsecond clock carries it; a small drift is eased out, a big one (a
## stall, a seek) is snapped to.
func _sync_clock() -> void:
	var guess := song_now()
	var now_us := Time.get_ticks_usec()
	if _music.playing:
		var heard := _music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		if absf(heard - guess) > 0.06:
			guess = heard
		else:
			guess += (heard - guess) * 0.08
	_clock = guess
	_ticks_at = now_us

# --- the strokes ---

func _gui_input(event: InputEvent) -> void:
	var at := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		at = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		at = event.position
	if at == Vector2.INF:
		return
	accept_event()
	stroke_at(at)

## The keyboard, on a desktop: F and J the face, D and K the rim.
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_F, KEY_J:
			stroke(true)
		KEY_D, KEY_K:
			stroke(false)
		_:
			return
	get_viewport().set_input_as_handled()

## A stroke at a point of the board: the skin is a don, anywhere else a ka.
## Before a song, the timing nudge's two buttons answer first.
func stroke_at(at: Vector2) -> void:
	if _phase == "ready" or _phase == "missed":
		var nudge := _nudge_hit(at)
		if nudge != 0:
			_set_offset(_offset + nudge * OFFSET_STEP)
			fx.cue("select", 1.0 + 0.05 * nudge)
			return
	var face := at.distance_to(_drum_c()) <= _face_r() * FACE_SLACK
	if not face:
		_rim_side = -1.0 if at.x < _drum_c().x else 1.0
	stroke(face)

func stroke(face: bool) -> void:
	if _st == null or _done:
		return
	_play_voice(face)
	var t := _now()
	if face:
		_hit_face_at = t
	else:
		_hit_rim_at = t
	_ripples.append({"at": t, "face": face, "side": _rim_side})
	_arm_at[_arm_next] = t
	_arm_next = 1 - _arm_next
	match _phase:
		"paused":
			_pause(false)
			return
		"ready", "missed":
			_start()
			return
		"play":
			_st.hit(view_t(), face)
			_handle()

func _play_voice(face: bool) -> void:
	var pool: Array = _don if face else _ka
	var p: AudioStreamPlayer = pool[_voice % VOICES]
	_voice += 1
	if p.stream != null:
		p.pitch_scale = randf_range(0.98, 1.02)
		p.play()
	UiSound.board_frame = Engine.get_process_frames()

# --- what the state said ---

func _handle() -> void:
	var t := _now()
	for ev: Dictionary in _st.events:
		match String(ev.type):
			"judge":
				var grade := int(ev.grade)
				_judges.append({"grade": grade, "at": t, "big": bool(ev.big)})
				if grade != State.Grade.BAD:
					var n: Dictionary = _st.notes[int(ev.i)]
					_flies.append({"type": int(n.type), "at": t})
					_bursts.append({"at": t, "col": JUDGE_COLS[grade], "big": bool(ev.big) or grade == State.Grade.GOOD})
					moves += 1
					if grade == State.Grade.GOOD and not Motion.reduce and _st.combo % 10 == 0:
						_rw.spray(_ring(), GOLD, 3, 300.0, "star", 0.7, 0.0, _gauge_end())
				elif not bool(ev.passed):
					_bursts.append({"at": t, "col": JUDGE_COLS[2], "big": false})
			"big":
				_bursts.append({"at": t, "col": GOLD, "big": true})
				fx.ring(_ring(), RING_R * 1.6 * _u(), GOLD)
			"roll":
				_roll_pop = {"n": int(ev.hits), "at": t}
				if not Motion.reduce and int(ev.hits) % 4 == 0:
					_rw.spray(_ring(), Parts.ROLL, 2, 260.0, "spark", 0.6)
			"roll_end":
				if int(ev.hits) >= 8:
					_rw.sticker(tr("DB_HITS") % int(ev.hits), _ring() + Vector2(90.0, -110.0) * _u(), 44, 0.9, false, Parts.ROLL, false, "roll", 20.0)
			"balloon":
				fx.cue("balloon", 1.0 + 0.04 * clampf(float(_st.notes[int(ev.i)].hits), 0.0, 12.0), -4.0)
			"pop":
				fx.cue("pop")
				_rw.spray(_ring(), Parts.BALLOON, 14, 620.0, "confetti", 1.0)
				_rw.spray(_ring(), GOLD, 6, 520.0, "star", 0.9)
				_rw.sticker(tr("DB_POP"), _ring() + Vector2(120.0, -120.0) * _u(), 64, 1.0, true, Color.WHITE, true, "pop", 24.0)
			"balloon_gone":
				_balloon_gone[int(ev.i)] = t
				fx.cue("balloon_gone")
			"combo":
				var n := int(ev.n)
				fx.cue("combo", 1.0 + 0.04 * minf(n / 25.0, 6.0))
				var mid := Vector2(size.x * 0.5, _band_h() + STAGE * 0.42 * _u())
				_rw.sticker(tr("DB_COMBO_CALL") % n, mid, 56 + mini(n / 25, 4) * 8, 1.2, true, Color.WHITE, n >= 50, "combo", 24.0)
				if n >= 50:
					_rw.spray(mid, GOLD, 10, 640.0, "star", 1.0)
				_set_mood(Parts.Mood.JOY, 1.2)
			"break":
				if int(ev.combo) >= 10:
					fx.cue("break")
					_set_mood(Parts.Mood.WORRIED, 1.0)
			"gogo_on":
				_gogo_at = t
				fx.cue("gogo")
				_rw.sticker(tr("DB_GOGO"), Vector2(size.x * 0.5, _band_h() + STAGE * 0.4 * _u()), 72, 1.4, true, Color.WHITE, true, "gogo", 24.0)
				_rw.spray(Vector2(size.x * 0.5, _band_h() + STAGE * 0.4 * _u()), GOLD, 12, 700.0, "star", 1.0)
				_set_mood(Parts.Mood.JOY, 1.5)
			"gogo_off":
				pass
			"soul_clear":
				_soul_at = t
				fx.cue("soul")
				_rw.spray(_gauge_line(), GOLD, 8, 420.0, "star", 0.8)
				_rw.sticker(tr("DB_SOUL_LINE"), _gauge_line() + Vector2(0, 80.0) * _u(), 40, 1.0, false, GOLD, false, "soul", 16.0)
			"soul_lost":
				pass
			"done":
				_song_over()
	_st.events.clear()

func _set_mood(m: int, hold: float) -> void:
	_mood = m
	_mood_until = _now() + hold

func _song_over() -> void:
	_best_score = maxi(_best_score, _st.score)
	var mark := "🥁"
	if _st.all_good():
		mark = "👑"
	elif _st.full_combo():
		mark = "🎉"
	elif _st.cleared():
		mark = "✅"
	else:
		mark = "·"
	_log += mark
	if _st.cleared():
		_phase = "won"
		_set_mood(Parts.Mood.JOY, 100.0)
		check_solved()
	else:
		_phase = "missed"
		_music.stop()
		fx.cue("fail")
		_set_mood(Parts.Mood.SAD, 3.0)

# --- the win ---

func is_solved() -> bool:
	return _st != null and _st.done and _st.cleared()

func _on_solved() -> void:
	var crown := "DB_CLEARED"
	if _st.all_good():
		crown = "DB_ALL_GOOD"
	elif _st.full_combo():
		crown = "DB_FULL_COMBO"
	fx.cue("full_combo" if _st.full_combo() else "clear")
	var mid := Vector2(size.x * 0.5, _band_h() + STAGE * 0.45 * _u())
	_rw.sticker(tr(crown), mid, 84, 2.2, true, Color.WHITE, true, "crown", 24.0)
	if not Motion.reduce:
		_rw.rain(2.6, ["confetti", "star"], Rewards.CONFETTI)
		_rw.spray(mid, GOLD, 16, 760.0, "star", 1.1)

func reset_board() -> void:
	_fresh()
	moves = 0
	_running = true
	fx.cue("reset")

func share_glyphs() -> String:
	return _log

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("DB_WIN") % [Locale.number(_st.score if _st != null else 0), _st.max_combo if _st != null else 0]}

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_HOLD

func tip_line() -> Dictionary:
	return {"text": tr("DB_TAP_START"), "mood": Face.Expr.HAPPY}

func completion_record() -> Dictionary:
	if _st == null:
		return {}
	return {"song": String(_song.get("id", "")), "score": _st.score, "combo": _st.max_combo,
		"good": _st.goods, "ok": _st.oks, "bad": _st.bads, "log": _log}

## A reopened daily that was already cleared: the stage at rest, Tam
## beaming, and the score it was cleared with.
func restore_completed_board() -> void:
	if _st == null:
		return
	_music.stop()
	_phase = "won"
	_st.score = int(completed_record.get("score", 0))
	_st.max_combo = int(completed_record.get("combo", 0))
	_st.goods = int(completed_record.get("good", 0))
	_st.oks = int(completed_record.get("ok", 0))
	_st.bads = int(completed_record.get("bad", 0))
	_st.gauge = State.GAUGE_MAX
	_st.done = true
	for n: Dictionary in _st.notes:
		n.st = State.St.HIT
	_log = String(completed_record.get("log", ""))
	_set_mood(Parts.Mood.JOY, 100.0)

# --- the timing nudge ---

func _load_offset() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		_offset = float(cfg.get_value("timing", "offset", 0.0))

func _set_offset(v: float) -> void:
	_offset = clampf(snappedf(v, OFFSET_STEP), -OFFSET_MAX, OFFSET_MAX)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("timing", "offset", _offset)
	cfg.save(SETTINGS)
	queue_redraw()

## The card the start and the retry are written on, over the stage and lane.
func _card_rect() -> Rect2:
	var u := _u()
	return Rect2(Vector2(40.0 * u, _band_h() + 14.0 * u), Vector2(size.x - 80.0 * u, _lane_bottom() - _band_h() - 28.0 * u))

## The nudge's minus and plus, at the card's foot.
func _nudge_rects() -> Array:
	var r := _card_rect()
	var u := _u()
	var y := r.end.y - 84.0 * u
	var s := Vector2(76.0, 64.0) * u
	return [Rect2(Vector2(r.get_center().x - 250.0 * u, y), s), Rect2(Vector2(r.get_center().x + 174.0 * u, y), s)]

func _nudge_hit(at: Vector2) -> int:
	var rects := _nudge_rects()
	if (rects[0] as Rect2).grow(10.0).has_point(at):
		return -1
	if (rects[1] as Rect2).grow(10.0).has_point(at):
		return 1
	return 0

# --- drawing ---

func _gauge_rect() -> Rect2:
	var u := _u()
	return Rect2(Vector2(size.x * 0.42, _band_h() * 0.5 - 16.0 * u), Vector2(size.x * 0.54, 32.0 * u))

func _gauge_line() -> Vector2:
	var r := _gauge_rect()
	return Vector2(r.position.x + r.size.x * State.CLEAR / State.GAUGE_MAX, r.get_center().y)

func _gauge_end() -> Vector2:
	var r := _gauge_rect()
	return Vector2(r.end.x - 20.0 * _u(), r.get_center().y)

func _draw() -> void:
	if size.x <= 0.0 or _st == null:
		return
	_shown.clear()
	var u := _u()
	if _still == null:
		_still = _build_still()
	_shown.append(_still)
	draw_mesh(_still, null)
	var now := _now()
	var vt := view_t()
	var beat := float(_song.get("beat", 0.5))
	var first := float((_song.get("bars", [0.0]) as Array)[0]) if not (_song.get("bars", []) as Array).is_empty() else 0.0
	var beats := (vt - first) / beat
	var gogo := _st.in_gogo and _phase == "play"
	var calm := Motion.reduce

	# the lanterns on their cord, swinging to the beat and lit in Go-Go time
	var n_l := LANTERN_COLS.size()
	for k in n_l:
		var x := size.x * (0.1 + 0.8 * k / float(n_l - 1))
		var sag := sin(PI * k / float(n_l - 1)) * 34.0 * u
		var hang := Vector2(x, _band_h() + 34.0 * u + sag)
		var swing := 0.0 if calm else sin(beats * PI + k) * (0.12 if gogo else 0.05)
		var glow := 1.0 if gogo else 0.35
		draw_mesh(Parts.lantern(24.0 * u, LANTERN_COLS[k], glow), null, Transform2D(swing, hang))

	# Tam, drumming on the right of the stage
	_draw_frog(now, beats, gogo)

	# the lane: Go-Go warms it; the bar lines; the notes, the earliest on top
	var b := Face.Builder.new()
	if gogo:
		var warm := 0.6 + 0.4 * (0.0 if calm else absf(sin(beats * PI)))
		b.polygon(Face.Builder.round_rect(Vector2(0, _lane_top() + 10.0 * u), Vector2(size.x, (LANE - 20.0) * u), 20.0 * u), Color(LANE_GOGO, 0.55 * warm))
	var speed := _speed()
	var ring := _ring()
	for bt: float in _song.get("bars", []):
		var x: float = ring.x + (bt - vt) * speed
		if x < ring.x - RING_R * u or x > size.x + 10.0:
			continue
		b.stroke(PackedVector2Array([Vector2(x, _lane_top() + 14.0 * u), Vector2(x, _lane_bottom() - 14.0 * u)]), 3.0 * u, Color(1, 1, 1, 0.35))
	# the ring's flash on a stroke, red on the skin, blue on the rim
	var ff := 1.0 - clampf((now - _hit_face_at) / FLASH_TIME, 0.0, 1.0)
	var rf := 1.0 - clampf((now - _hit_rim_at) / FLASH_TIME, 0.0, 1.0)
	if ff > 0.0:
		b.disc(ring, RING_R * 0.86 * u, Color(Parts.DON, 0.45 * ff))
	if rf > 0.0:
		b.stroke(Face.Builder.arc_points(ring, RING_R * 0.93 * u, 0.0, TAU), 12.0 * u, Color(Parts.KA, 0.8 * rf), true)
	_put(b)

	_draw_notes(vt, speed, ring, now)

	# over the notes: bursts at the ring and the notes flying up to the gauge
	var fb := Face.Builder.new()
	for bu: Dictionary in _bursts:
		var k := (now - float(bu.at)) / BURST_TIME
		if k >= 1.0 or calm:
			continue
		var col: Color = bu.col
		var r := RING_R * u * (1.0 + 0.8 * k) * (1.25 if bu.big else 1.0)
		fb.stroke(Face.Builder.arc_points(ring, r, 0.0, TAU), 10.0 * u * (1.0 - k), Color(col, 0.9 * (1.0 - k)), true)
		if bu.big:
			Rewards.sunrays(fb, ring, r * 0.7, r * 1.25, 10, k * 0.6, Color(col, 0.5 * (1.0 - k)))
	_draw_gauge(fb, now)
	_draw_drum_fx(fb, now)
	_put(fb)
	for f: Dictionary in _flies:
		var k := (now - float(f.at)) / FLY_TIME
		if k >= 1.0 or calm:
			continue
		var to := _gauge_end()
		var p := ring.lerp(to, k) + Vector2(0, -sin(k * PI) * 180.0 * u)
		var sc := lerpf(1.0, 0.45, k)
		var r := (BIG_R if State.is_big(int(f.type)) else NOTE_R) * u
		draw_mesh(Parts.note(int(f.type), r, Parts.Mood.JOY), null, Transform2D(k * 4.0, Vector2(sc, sc), 0.0, p))
	_flies = _flies.filter(func(f: Dictionary) -> bool: return now - float(f.at) < FLY_TIME)
	_bursts = _bursts.filter(func(bu: Dictionary) -> bool: return now - float(bu.at) < BURST_TIME)

	# the drum
	var dc := _drum_c()
	var fr := _face_r()
	if _drum == null:
		_drum = Parts.drum(fr, fr * RIM_OVER)
	var squash := 1.0
	if not calm:
		squash -= 0.03 * (1.0 - clampf((now - _hit_face_at) / 0.12, 0.0, 1.0))
	draw_mesh(_drum, null, Transform2D(0.0, Vector2(1.0 / squash, squash), 0.0, dc))
	_draw_drum_ripples(now)

	_draw_words(now, vt)

## Draws what a builder holds, keeping the mesh until the next frame's
## replaces it; an empty builder draws nothing.
func _put(b: Face.Builder) -> void:
	if b.verts.is_empty():
		return
	var m := b.mesh()
	_shown.append(m)
	draw_mesh(m, null)

func _draw_frog(now: float, beats: float, gogo: bool) -> void:
	var u := _u()
	var s := 58.0 * u
	var foot := Vector2(size.x - 140.0 * u, _lane_top() - 4.0 * u)
	var calm := Motion.reduce
	var bob := 0.0 if calm else absf(sin(beats * PI)) * (14.0 if gogo else 6.0) * u
	if _phase != "play" and not calm:
		bob = absf(sin(now * 2.2)) * 5.0 * u
	var mood := _mood if now < _mood_until else Parts.Mood.HAPPY
	var blink := not calm and fmod(now, 3.7) < 0.12
	var at := foot + Vector2(0, -bob)
	draw_mesh(Parts.frog(s, mood, blink and mood == Parts.Mood.HAPPY), null, Transform2D(0.0, at))
	# the arms over the body, a stick in each, raised and brought down on
	# the player's strokes, one hand after the other
	for side in 2:
		var dir := -1.0 if side == 0 else 1.0
		var since := now - float(_arm_at[side])
		var swing := 0.0
		if since < 0.2 and not calm:
			swing = sin(since / 0.2 * PI)
		var lift := 0.5 + (0.0 if calm else sin(beats * PI + side * PI) * 0.1)
		# 0 hangs straight down; the stick points out and up at rest and
		# comes down across the belly on a stroke
		var ang := -dir * lerpf(2.3, 0.4, swing) * lift * 1.6
		var shoulder := at + Vector2(dir * s * 0.66, -s * 1.05)
		draw_mesh(Parts.frog_arm(s), null, Transform2D(ang, shoulder))

func _draw_notes(vt: float, speed: float, ring: Vector2, now: float) -> void:
	var u := _u()
	var left := -BIG_R * 2.0 * u
	var right := size.x + BIG_R * u
	var notes: Array = _st.notes
	# the earliest note is drawn last, over the ones behind it
	for i in range(notes.size() - 1, -1, -1):
		var n: Dictionary = notes[i]
		var type := int(n.type)
		var x: float = ring.x + (float(n.t) - vt) * speed
		if x > right:
			continue
		if State.is_long(type):
			var x1: float = ring.x + (float(n.end) - vt) * speed
			if x1 < left:
				continue
			if type == State.Type.BALLOON:
				if n.st == State.St.HIT:
					continue
				var fill := float(n.hits) / maxf(1.0, float(n.get("count", 1)))
				var gone: float = now - float(_balloon_gone.get(i, INF))
				var p := Vector2(maxf(x, ring.x), ring.y - 6.0 * u)
				if gone >= 0.0:
					if gone > 1.0:
						continue
					p += Vector2(-gone * 120.0, -gone * 420.0) * u
				draw_mesh(Parts.balloon(NOTE_R * u, fill), null, Transform2D(0.0, p))
				if x <= ring.x and gone < 0.0:
					_label(p + Vector2(NOTE_R * 0.9, -NOTE_R * 1.1) * u, str(maxi(0, int(n.count) - int(n.hits))), int(44 * u), Color.WHITE, Parts.INK)
				continue
			var r := (BIG_R if type == State.Type.BIG_ROLL else NOTE_R) * u
			var m := Parts.roll(maxf(0.0, x1 - x), r)
			draw_mesh(m, null, Transform2D(0.0, Vector2(x, ring.y)))
			continue
		if n.st == State.St.HIT:
			continue
		if x < left:
			continue
		var r2 := (BIG_R if State.is_big(type) else NOTE_R) * u
		var mood := Parts.Mood.HAPPY
		var tint := Color.WHITE
		if n.st == State.St.MISSED:
			mood = Parts.Mood.SAD
			tint = Color(1, 1, 1, 0.45)
		elif float(n.t) - vt < 0.25 and not Motion.reduce:
			mood = Parts.Mood.JOY
		var hop := 0.0
		if n.st == State.St.WAIT and not Motion.reduce:
			hop = absf(sin((float(n.t) - vt) * TAU * 1.0)) * 4.0 * u
		if tint.a < 1.0:
			var m2 := Parts.note(type, r2, mood)
			# a missed note slides on under a veil of the lane's own wood
			draw_mesh(m2, null, Transform2D(0.0, Vector2(x, ring.y)))
			draw_circle(Vector2(x, ring.y), r2 * 1.02, Color(LANE_TRACK, 0.55))
		else:
			draw_mesh(Parts.note(type, r2, mood), null, Transform2D(0.0, Vector2(x, ring.y - hop)))

func _draw_gauge(b: Face.Builder, now: float) -> void:
	var u := _u()
	var r := _gauge_rect()
	b.polygon(Face.Builder.round_rect(r.position - Vector2(4, 4) * u, r.size + Vector2(8, 8) * u, (r.size.y * 0.5 + 4.0 * u)), Color(Parts.INK, 0.55))
	b.polygon(Face.Builder.round_rect(r.position, r.size, r.size.y * 0.5), GAUGE_BACK)
	var k := _st.gauge / State.GAUGE_MAX
	if k > 0.01:
		var w := maxf(r.size.y, r.size.x * k)
		var col := GAUGE_CLEAR if _st.cleared() else GAUGE_FILL
		if _st.gauge >= State.GAUGE_MAX and not Motion.reduce:
			col = col.lerp(Color.WHITE, 0.25 + 0.25 * sin(now * 8.0))
		b.polygon(Face.Builder.round_rect(r.position, Vector2(w, r.size.y), r.size.y * 0.5), col)
		b.polygon(Face.Builder.round_rect(r.position + Vector2(r.size.y * 0.3, r.size.y * 0.16), Vector2(maxf(0.0, w - r.size.y * 0.6), r.size.y * 0.22), r.size.y * 0.11), Color(1, 1, 1, 0.35))
	# the clear line, a notch with a star over it
	var line := _gauge_line()
	b.stroke(PackedVector2Array([line + Vector2(0, -r.size.y * 0.75), line + Vector2(0, r.size.y * 0.75)]), 5.0 * u, Parts.CREAM)
	var pulse := 1.0 + (0.0 if Motion.reduce else 0.4 * (1.0 - clampf((now - _soul_at) / 0.5, 0.0, 1.0)))
	Rewards.star(b, line + Vector2(0, -r.size.y * 1.05), 14.0 * u * pulse, GOLD if _st.cleared() else Parts.CREAM)

func _draw_drum_fx(b: Face.Builder, now: float) -> void:
	var u := _u()
	var dc := _drum_c()
	var fr := _face_r()
	var rf := 1.0 - clampf((now - _hit_rim_at) / FLASH_TIME, 0.0, 1.0)
	if rf > 0.0 and not Motion.reduce:
		var mid := PI if _rim_side < 0.0 else 0.0
		b.stroke(Face.Builder.arc_points(dc, fr * (RIM_OVER + 1.0) * 0.5, mid - 1.1, mid + 1.1), fr * (RIM_OVER - 1.0) * 0.9, Color(Parts.KA_HI, 0.55 * rf))
	elif rf > 0.0:
		b.stroke(Face.Builder.arc_points(dc, fr * (RIM_OVER + 1.0) * 0.5, 0.0, TAU), fr * (RIM_OVER - 1.0) * 0.6, Color(Parts.KA_HI, 0.4 * rf), true)
	# idle: the skin breathes a faint red on the beat while a song plays
	if _phase == "ready" or _phase == "missed":
		var p := 0.5 + 0.5 * sin(now * 3.0)
		b.stroke(Face.Builder.arc_points(dc, fr * 0.98, 0.0, TAU), 6.0 * u, Color(Parts.DON, 0.25 + 0.35 * (0.0 if Motion.reduce else p)), true)

func _draw_drum_ripples(now: float) -> void:
	if Motion.reduce:
		_ripples.clear()
		return
	var b := Face.Builder.new()
	var dc := _drum_c()
	var fr := _face_r()
	for rp: Dictionary in _ripples:
		var k := (now - float(rp.at)) / RIPPLE_TIME
		if k >= 1.0 or not rp.face:
			continue
		b.stroke(Face.Builder.arc_points(dc, fr * (0.2 + 0.75 * k), 0.0, TAU), 8.0 * _u() * (1.0 - k), Color(Parts.DON, 0.5 * (1.0 - k)), true)
	_ripples = _ripples.filter(func(rp: Dictionary) -> bool: return now - float(rp.at) < RIPPLE_TIME)
	_put(b)

func _draw_words(now: float, vt: float) -> void:
	var u := _u()
	# the score and the gauge's word
	_label_left(Vector2(INSET * u + 8.0 * u, _band_h() * 0.36), tr("DB_SCORE"), int(KICKER_FONT * u), Color(Parts.INK, 0.7), Color(0, 0, 0, 0))
	_label_left(Vector2(INSET * u + 8.0 * u, _band_h() * 0.8), Locale.number(_st.score), int(SCORE_FONT * u), Parts.INK, Color(0, 0, 0, 0))
	var gr := _gauge_rect()
	_label_left(Vector2(gr.position.x, gr.position.y - 12.0 * u), tr("DB_SOUL"), int(KICKER_FONT * u), Color(Parts.INK, 0.7), Color(0, 0, 0, 0))
	# the song and its level, over the stage
	var level_name: String = tr(["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD", "DIFF_INSANE"][clampi(_level, 0, 3)])
	_label(Vector2(size.x * 0.5, _band_h() + 36.0 * u), "%s · %s" % [String(_song.get("title", "")), level_name], int(28 * u), Parts.CREAM, Color(Parts.INK, 0.5))
	# the combo over the ring
	var ring := _ring()
	if _st.combo >= 3:
		_label(ring + Vector2(0, -RING_R * u - 72.0 * u), str(_st.combo), int(COMBO_FONT * u), Parts.CREAM, Parts.INK)
		_label(ring + Vector2(0, -RING_R * u - 36.0 * u), tr("DB_COMBO"), int(KICKER_FONT * u), Parts.CREAM, Parts.INK)
	# the latest judgement, rising off the ring
	if not _judges.is_empty():
		var j: Dictionary = _judges[_judges.size() - 1]
		var k := (now - float(j.at)) / JUDGE_TIME
		if k < 1.0:
			var rise := 0.0 if Motion.reduce else (1.0 - pow(1.0 - k, 3.0)) * 26.0 * u
			var a := 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
			var col: Color = JUDGE_COLS[int(j.grade)]
			_label(ring + Vector2(0, RING_R * u + 30.0 * u - rise), tr(JUDGE_KEYS[int(j.grade)]), int(JUDGE_FONT * u), Color(col, a), Color(Parts.INK, 0.8 * a))
	if _judges.size() > 8:
		_judges = _judges.slice(_judges.size() - 4)
	# a drumroll's count
	if not _roll_pop.is_empty() and now - float(_roll_pop.at) < 0.5:
		_label(ring + Vector2(RING_R * u + 50.0 * u, -RING_R * u), str(int(_roll_pop.n)), int(44 * u), Parts.ROLL, Parts.INK)
	match _phase:
		"ready":
			_draw_card(tr("DB_TAP_START"), "", now)
		"missed":
			var head := "DB_SO_CLOSE" if _st.gauge >= State.CLEAR * 0.6 else "DB_KEEP_GOING"
			_draw_card(tr(head), tr("DB_MISSED_LINE") % int(roundf(_st.gauge)), now)
		"paused":
			_draw_card(tr("DB_PAUSED"), tr("DB_RESUME"), now, false)

## The start card, the retry card and the pause, written over the stage and
## the lane: a head, a line, the legend of the four kinds of note (only
## before a song) and the timing nudge.
func _draw_card(head: String, line: String, now: float, nudge := true) -> void:
	var u := _u()
	var r := _card_rect()
	var b := Face.Builder.new()
	b.polygon(Face.Builder.round_rect(r.position + Vector2(0, 8.0 * u), r.size, 36.0 * u), Color(Parts.INK, 0.2))
	b.polygon(Face.Builder.round_rect(r.position, r.size, 36.0 * u), Color(Pal.PAPER, 0.97))
	if nudge:
		for rr: Rect2 in _nudge_rects():
			b.polygon(Face.Builder.round_rect(rr.position, rr.size, 22.0 * u), Color("efe3cc"))
	_put(b)
	var c := r.get_center()
	var y := r.position.y + 64.0 * u
	if _phase == "ready":
		_label(Vector2(c.x, y), String(_song.get("title", "")), int(TITLE_FONT * u), Parts.INK, Color(0, 0, 0, 0))
		y += 60.0 * u
		var lv: Array = ["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD", "DIFF_INSANE"]
		_label(Vector2(c.x, y), "%s · %d BPM" % [tr(lv[clampi(_level, 0, 3)]), int(_song.get("bpm", 0))], int(28 * u), Color(Parts.INK, 0.65), Color(0, 0, 0, 0))
		# the legend: a don, a ka, a big one and a roll, each with its word
		y += 70.0 * u
		var items := [[State.Type.DON, "DB_LEGEND_DON"], [State.Type.KA, "DB_LEGEND_KA"], [State.Type.BIG_DON, "DB_LEGEND_BIG"], [State.Type.ROLL, "DB_LEGEND_ROLL"]]
		for k in items.size():
			var col_x := r.position.x + (60.0 + (k % 2) * 440.0) * u
			var row_y := y + (k / 2) * 74.0 * u
			var it: Array = items[k]
			if int(it[0]) == State.Type.ROLL:
				draw_mesh(Parts.roll(40.0 * u, 26.0 * u), null, Transform2D(0.0, Vector2(col_x - 10.0 * u, row_y)))
			else:
				draw_mesh(Parts.note(int(it[0]), (38.0 if int(it[0]) == State.Type.BIG_DON else 28.0) * u), null, Transform2D(0.0, Vector2(col_x, row_y)))
			_label_left(Vector2(col_x + 56.0 * u, row_y + 10.0 * u), tr(String(it[1])), int(26 * u), Parts.INK, Color(0, 0, 0, 0))
		y += 170.0 * u
		var pulse := 1.0 if Motion.reduce else 0.75 + 0.25 * sin(now * 4.0)
		_label(Vector2(c.x, y), head, int(40 * u), Color(Parts.DON_DEEP, pulse), Color(0, 0, 0, 0))
	else:
		_label(Vector2(c.x, y + 20.0 * u), head, int(TITLE_FONT * u), Parts.INK, Color(0, 0, 0, 0))
		if line != "":
			_label(Vector2(c.x, y + 84.0 * u), line, int(LINE_FONT * u), Color(Parts.INK, 0.75), Color(0, 0, 0, 0))
		if _phase == "missed":
			_label(Vector2(c.x, y + 140.0 * u), tr("DB_STATS") % [_st.goods, _st.oks, _st.bads, _st.max_combo], int(28 * u), Color(Parts.INK, 0.65), Color(0, 0, 0, 0))
			var pulse2 := 1.0 if Motion.reduce else 0.75 + 0.25 * sin(now * 4.0)
			_label(Vector2(c.x, y + 210.0 * u), tr("DB_TAP_AGAIN"), int(38 * u), Color(Parts.DON_DEEP, pulse2), Color(0, 0, 0, 0))
	if nudge:
		var rects := _nudge_rects()
		_label((rects[0] as Rect2).get_center() + Vector2(0, 14.0 * u), "−", int(44 * u), Parts.INK, Color(0, 0, 0, 0))
		_label((rects[1] as Rect2).get_center() + Vector2(0, 14.0 * u), "+", int(44 * u), Parts.INK, Color(0, 0, 0, 0))
		var ms := int(roundf(_offset * 1000.0))
		_label(Vector2(c.x, (rects[0] as Rect2).get_center().y + 11.0 * u), tr("DB_TIMING") % ("%+d" % ms), int(28 * u), Color(Parts.INK, 0.75), Color(0, 0, 0, 0))

func _label(center: Vector2, text: String, px: int, col: Color, outline: Color) -> void:
	var font: Font = CozyTheme.display(700)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := center + Vector2(-w * 0.5, px * 0.35)
	if outline.a > 0.0:
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(2, px / 6), outline)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

func _label_left(at: Vector2, text: String, px: int, col: Color, outline: Color) -> void:
	var font: Font = CozyTheme.display(700)
	if outline.a > 0.0:
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(2, px / 6), outline)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

## The still picture: the card, the band, the dusk stage with its hills and
## stalls and the lanterns' cord, the lane and the hit ring's frame.
func _build_still() -> ArrayMesh:
	var u := _u()
	var b := Face.Builder.new()
	var w := size.x
	b.polygon(Face.Builder.round_rect(Vector2.ZERO, size, CARD_RADIUS * u), Pal.PAPER)
	# the stage: a dusk sky, graded top to foot
	var top := _band_h()
	var low := _lane_top()
	var i0 := b.vertex(Vector2(0, top), SKY_TOP)
	var i1 := b.vertex(Vector2(w, top), SKY_TOP)
	var i2 := b.vertex(Vector2(w, low), SKY_LOW)
	var i3 := b.vertex(Vector2(0, low), SKY_LOW)
	b.tri(i0, i1, i2)
	b.tri(i0, i2, i3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 26:
		b.disc(Vector2(rng.randf() * w, top + rng.randf() * (low - top) * 0.45), rng.randf_range(1.0, 2.6) * u, Color(1, 0.97, 0.85, rng.randf_range(0.3, 0.8)))
	# the moon
	b.disc(Vector2(w * 0.78, top + 70.0 * u), 30.0 * u, Color("fff1c8"))
	b.disc(Vector2(w * 0.78 + 12.0 * u, top + 62.0 * u), 26.0 * u, Color(SKY_TOP.lerp(SKY_LOW, 0.2), 1.0))
	# the hills, far and near
	var far := PackedVector2Array([Vector2(0, low)])
	for k in 13:
		var x := w * k / 12.0
		far.append(Vector2(x, low - (70.0 + 40.0 * sin(k * 1.3) + 20.0 * sin(k * 2.7)) * u))
	far.append(Vector2(w, low))
	b.polygon(far, HILL)
	var near := PackedVector2Array([Vector2(0, low)])
	for k in 13:
		var x := w * k / 12.0
		near.append(Vector2(x, low - (34.0 + 18.0 * sin(k * 0.9 + 1.0)) * u))
	near.append(Vector2(w, low))
	b.polygon(near, HILL_NEAR)
	# two festival stalls, their striped awnings
	for sx: float in [0.3, 0.58]:
		var base := Vector2(w * sx, low - 10.0 * u)
		var sw := 150.0 * u
		b.polygon(Face.Builder.round_rect(base + Vector2(-sw * 0.5, -86.0 * u), Vector2(sw, 86.0 * u), 6.0 * u), STALL)
		b.polygon(Face.Builder.round_rect(base + Vector2(-sw * 0.44, -62.0 * u), Vector2(sw * 0.88, 40.0 * u), 6.0 * u), Color("f3c98f", 0.85))
		for s in 5:
			var x0 := base.x - sw * 0.6 + s * sw * 1.2 / 5.0
			b.polygon(PackedVector2Array([Vector2(x0, base.y - 86.0 * u), Vector2(x0 + sw * 0.24, base.y - 86.0 * u),
				Vector2(x0 + sw * 0.24, base.y - 106.0 * u), Vector2(x0, base.y - 106.0 * u)]), STALL_ROOF if s % 2 == 0 else Parts.CREAM)
		for s in 5:
			var cx := base.x - sw * 0.6 + (s + 0.5) * sw * 1.2 / 5.0
			b.disc(Vector2(cx, base.y - 86.0 * u), sw * 0.12, STALL_ROOF if s % 2 == 0 else Parts.CREAM)
	# the lanterns' cord
	var cord := PackedVector2Array()
	for k in 25:
		var t := k / 24.0
		cord.append(Vector2(w * (0.02 + 0.96 * t), top + 34.0 * u + sin(PI * (t - 0.02) / 0.96) * 34.0 * u))
	b.stroke(cord, 3.0 * u, Color(Parts.INK, 0.7))
	# the lane: a wooden rail with a dark track
	b.polygon(Face.Builder.round_rect(Vector2(0, low), Vector2(w, LANE * u), 0.0), LANE_WOOD)
	b.polygon(Face.Builder.round_rect(Vector2(0, low + 10.0 * u), Vector2(w, (LANE - 20.0) * u), 20.0 * u), LANE_TRACK)
	b.stroke(PackedVector2Array([Vector2(0, low + 4.0 * u), Vector2(w, low + 4.0 * u)]), 3.0 * u, Color(1, 1, 1, 0.18))
	# the hit ring's frame: a cream ring with the ink round it
	var ring := _ring()
	b.disc(ring, RING_R * 1.06 * u, Color(Parts.INK, 0.6))
	b.disc(ring, RING_R * u, Color("5a463a"))
	b.stroke(Face.Builder.arc_points(ring, RING_R * 0.93 * u, 0.0, TAU), 6.0 * u, Parts.CREAM, true)
	b.stroke(Face.Builder.arc_points(ring, NOTE_R * 0.98 * u, 0.0, TAU), 3.0 * u, Color(Parts.CREAM, 0.55), true)
	# the ground under the drum: a festival mat
	var mat_top := _lane_bottom()
	b.polygon(PackedVector2Array([Vector2(0, mat_top), Vector2(w, mat_top), Vector2(w, size.y - CARD_RADIUS * u), Vector2(0, size.y - CARD_RADIUS * u)]), Color("efe3cc"))
	for k in 9:
		var y := mat_top + (k + 0.5) * (size.y - mat_top) / 9.0
		b.stroke(PackedVector2Array([Vector2(12.0 * u, y), Vector2(w - 12.0 * u, y)]), 2.0 * u, Color("e2d1b0", 0.8))
	return b.mesh()
