extends "res://core/puzzle_base.gd"

## Drumbeat as a flat board: a little band of drums on a garden stage at
## dusk. Berries with faces ride one road of planks, right to left, in time
## with the day's short song, every one into the same ring; each wears the
## colour of the drum it wants and has that drum's mark under it, and the
## drums stand in a row under the road, where the thumbs are. Strike a
## berry's drum as it reaches the ring. One drum on Easy, two on Medium,
## three on Hard and Insane. A berry with a ribbon behind it is held down to
## the ribbon's end, a golden bar is drummed as fast as the player can, a
## balloon wants that many strokes. Two berries at once (one over the other)
## are two fingers. Clear the song -- end it with the soul gauge at or over
## its line -- and the day's board is solved. On Easy and Medium a song that
## ends under the line is simply played again; Hard and Insane carry hearts
## (MISS_RUN misses in a row, or a song under the line, break one), and out
## of hearts the song stops.
##
## Insane is Echo: the bars go in pairs, and the second of each pair plays
## the first again with its berries hidden -- read it, play it, then play it
## back from memory by ear.
##
## Every note on a chart is a note in the music: tools/gen_drumbeat.py writes
## the songs and their charts from the same events, each level's chart for
## the drums it has: the tune's notes by pitch, the kick and bass on the big
## drum. The tune
## is its own stem (`_lead`), and it dips while the player lets notes pass.
##
## The clock. The song's time runs off the microsecond clock from the
## instant the music is heard, and the music's playback position only steers
## it, gently, never back. A phone's audio is late by an amount the engine
## cannot read on Android (it reports no output latency), so the board keeps
## a per-phone timing (`_offset`, user://drumbeat.cfg), measured by a
## tap-along of wood-block knocks the first time it is played on a phone
## and on the start card's Tune button whenever the player likes.
##
## The rules, the judging and the score live in puzzles/drumbeat_state.gd;
## the drawings in ui/faces/drumbeat_parts.gd.
##
## Spec: docs/superpowers/specs/2026-10-01-drumbeat-polish-design.md, and
## its 2026-10-03 amendment (one road; docs/brainstorm/concepts.html#drumbeat).

signal leave

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
const Seal = preload("res://ui/flat/seal.gd")
const NapCat = preload("res://ui/faces/nap_cat.gd")
const RunMesh = preload("res://ui/flat/run_mesh.gd")

# --- the screen, measured (design pixels at a 1000-wide card) ---
const CARD_RADIUS := 32.0
## The band over the stage with the score, the hearts and the soul gauge.
const BAND := 118.0
## The road the berries ride, under the stage: its height, the rail along
## its top, the line the berries are on, where the planks end, and the strip
## under them where each berry's mark rides.
const ROAD := 260.0
const ROAD_RAIL := 18.0
const ROAD_NOTE := 104.0
const ROAD_FLOOR := 188.0
const ROAD_MARK := 229.0
## The ring every berry is struck in, from the card's left.
const RING_X := 150.0
## The drums' ground under the road, and their feet above the card's foot.
const GROUND := 620.0
const DRUM_FOOT := 150.0
## A drum's half-width, by how many stand.
const DRUM_R := [190.0, 172.0, 150.0]
## Which of the band's drums stand (ui/faces/drumbeat_parts.gd's kinds: the
## big drum, the hand drum, the jingle drum, the tongue drum), by how many.
const DRUM_KINDS := [[0], [0, 3], [0, 1, 3]]
## Seconds a note is in sight before it reaches the ring, by difficulty.
const TRAVEL := [2.2, 1.9, 1.6, 1.5]
const NOTE_R := 44.0
## Two berries at once ride this far apart, one over the other (in NOTE_R).
const TWIN := 1.5
## The drum the next berry wants glows from this share of the travel out.
const GLOW_REACH := 0.45
const VOICES := 4
const SCORE_FONT := 50
const KICKER_FONT := 24
const COMBO_FONT := 110
const JUDGE_FONT := 34
const TITLE_FONT := 60
const LINE_FONT := 32

# --- this board's own motion ---
const JUDGE_TIME := 0.42
const FLY_TIME := 0.42
const BURST_TIME := 0.3
const FLASH_TIME := 0.16
const SQUASH_TIME := 0.14
const MOOD_TIME := 0.6
## A note let past sinks off the road past the ring for FALL_TIME.
const FALL_TIME := 0.5
## The finale: fireworks, the crowd on its feet, before the win screen.
const WIN_HOLD := 3.4
const ROCKET_TIME := 0.35
const BURST_LIFE := 1.15
const CROWD_MAX := 10
const CROWD_START := 3
const CHEER_TIME := 0.7
const KICK_TIME := 0.16
## The combo at which each fever tier begins: a gold glow, a hotter one, a
## rainbow (and Tam's sunglasses).
const TIERS := [10, 25, 50]
## A conga line of critters dances across the stage on these combos and every
## hundred past them.
const CONGA_AT := [30, 80]
const CONGA_TIME := 5.0
const CONGA_N := 5
const SHADES_DROP := 0.35
const FIREWORK_COLS := [Color("f2c14e"), Color("f08aa6"), Color("8cc8ec"), Color("f59a6a"), Color("b7e07a"), Color("c9a0f0")]
const STICK_COLS := [Color("ff8fb0"), Color("7fe0ff"), Color("ffe066"), Color("a8ff8a")]
## The tune dips this far (dB) while notes are let past, by difficulty, and
## comes back at DUCK_RATE dB a second.
const DUCK_DB := [-6.0, -9.0, -12.0, -12.0]
const DUCK_RATE := 30.0
const ECHO_DB := -30.0
## The timing: its step on the card's buttons, its reach, its first guess on
## a phone that reports no output latency.
const OFFSET_STEP := 0.01
const OFFSET_MAX := 0.35
const PHONE_GUESS := 0.12
const SETTINGS := "user://drumbeat.cfg"
## The tap-along keeps the taps from this knock on, and wants this many.
const TUNE_FROM := 3
const TUNE_MIN := 5
## Hearts: the sign in the band, and the out-of-hearts card after the song
## winds down.
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
const WIND_DOWN := 1.4
const CARD_AFTER := 1.8
const CARD_AFTER_STILL := 0.3
const DUSK := Color(0.74, 0.76, 0.92)
const DUSK_TIME := 0.8
const SPLIT_TIME := 0.7
## One more heart picks the song up this many beats before where it stopped.
const PICK_UP_BEATS := 4.0
## The party after the win: the nap cat on the big drum, the seal.
const PARTY_AT := 0.7
const STAMP_AT := 1.3
const STAMP_DROP := 0.18
const STAMP_FROM := 1.8
const STAMP_R := 0.14
const STAMP_TILT := -0.2

const GOLD := Color("f2b632")
const PATH_WOOD := Color("8a5c3a")
const PATH_DEEP := Color("5a3a25")
const PATH_TRACK := Color("4a3426")
const PATH_GOGO := Color("ff7a59")
const SKY_TOP := Color("3d4a7a")
const SKY_LOW := Color("f2a37a")
const HILL := Color("6f7fa6")
const HILL_NEAR := Color("5d6c8f")
const STALL := Color("8c4a3a")
const STALL_ROOF := Color("c9593f")
const GAUGE_BACK := Color("4a3a30")
const GAUGE_FILL := Color("f59a6a")
const GAUGE_CLEAR := Color("f2c14e")
const HEART := Color("f07a8a")
const HEART_DEEP := Color("c9566a")
const JUDGE_COLS := [Color("f2b632"), Color("fff6e6"), Color("9fb3c8")]
const JUDGE_KEYS := ["DB_GOOD", "DB_OK", "DB_BAD"]
const LANTERN_COLS := [Color("f59a6a"), Color("f2c14e"), Color("f08aa6"), Color("f59a6a"), Color("8cc8ec"), Color("f2c14e")]
const DRUM_KEYS := [[KEY_J], [KEY_F, KEY_J], [KEY_F, KEY_J, KEY_K]]

var fx: Node2D
var _rw: Rewards
var _songs: Array = []
var _song: Dictionary = {}
var _level := 0
var _st: State
## "ready" before the first stroke, "tune" (the tap-along), "play",
## "paused", "missed" (ended under the line, waiting to go again), "out"
## (out of hearts) and "won".
var _phase := "ready"
var _music: AudioStreamPlayer
var _lead: AudioStreamPlayer
var _voices: Array = []   # per drum, its pool
var _voice := [0, 0, 0, 0]
var _lead_db := 0.0
var _duck := false
## The song's clock: song time 0 is heard at `_zero_us` (microseconds); while
## stopped, `_clock` holds it.
var _zero_us := 0
var _clock := 0.0
var _last_vt := -10.0
var _offset := 0.0
var _tuned := false
var _tune_then_play := false
var _tune_taps: Array = []
var _tune_result := INF
var _plays := 0
var _log := ""
var _kept_hearts := -1
var _heart_used := false
var _heart_card: Control
var _stopped_at := 0.0
## Touches held: index -> drum.
var _held := {}

# motion, on the screen's own clock (seconds, `_now()`)
var _judge := {}          # the latest: {grade, at}
var _flies: Array = []    # {lane, from, at, golden}
## Two berries at once: note index -> its row, in TWINs either side of the line.
var _rows := {}
var _ghosts: Array = []   # {pos, at}
var _bursts: Array = []   # {at, col, pos, big, ring}
var _hit_at := [-10.0, -10.0, -10.0, -10.0]
var _drum_mood := [0, 0, 0, 0]
var _drum_mood_until := [0.0, 0.0, 0.0, 0.0]
var _arm_at := [-10.0, -10.0]
var _arm_next := 0
var _roll_pop := {}       # {n, at}
var _gogo_at := -10.0
var _soul_at := -10.0
var _mood := Parts.Mood.HAPPY
var _mood_until := 0.0
var _balloon_gone := {}   # i -> at
var _fireworks: Array = []
var _cheer_at := -10.0
var _worry_until := 0.0
var _party_until := 0.0
var _flare_at := -10.0
var _crowd_n := CROWD_START
var _joined: Array = []
var _combo_at := -10.0
var _score_shown := 0.0
var _score_at := -10.0
var _soul_full_said := false
var _counted := -1
var _go_said := false
var _conga_at := -10.0
var _shades_at := INF
var _hold_note_at := [0.0, 0.0, 0.0, 0.0]
var _split_at := -10.0
var _split_index := -1
var _back_at := -10.0
var _dusk_tw: Tween
var _wind_tw: Tween
## Insane's echo bars: per bar [hidden notes, struck, missed, said].
var _echo_bars: Array = []
var _echo_said := 0
var _next_echo := 0
## The golden berries: note index -> true.
var _golden := {}
var _goldens_hit := 0
# the party
var _party_at := INF
var _cat: Control
var _stamp_at := INF
var _seal_mesh: ArrayMesh

# cached meshes (the canvas keeps a mesh by RID, so each is held until replaced)
var _still: ArrayMesh
var _shown: Array = []

# The checkup (2026-10-03): whatever only moves, swells, turns or fades is a
# shape made once at this layout and copied natively under a transform into
# one of three meshes -- the road's (under the berries), the top's (the
# gauge, the hearts, the glows and bursts) and the one over the drums --
# painted through a slot when its colour changes (`RunMesh`). A firework is
# one look a step of its life, copied the same way (`_fw`). Only what
# changes shape is still made on the frame: the gauge's fill when it moves,
# a heart breaking, a rocket. Draw calls are what the phone's driver pays
# for, so nothing here is a draw call of its own but a drum.
const S_BAR := 0x100
const S_BEAD := 0x200
const S_MARK := 0x300        # + drum * 2 + (1 under a twin)
const S_ROLL := 0x400        # + drum
const S_CAP := 0x500         # + ribbon (2 a drumroll's, 1 the ribbon over its ink)
const S_BODY := 0x600
const S_RING := 0x700
const S_RING_PULSE := 0x800
const S_DISC := 0x900
const S_WASH := 0xa00
const S_RAILS := 0xb00       # + tier
const S_VEIL := 0xc00
const S_VEIL_STARS := 0xd00  # + group
const S_GLOW := 0xe00
const S_RIPPLE := 0xf00      # + step
const S_BURST := 0x1000      # + kind * 16 + step
const S_GAUGE_OVER := 0x1100
const S_GLINT := 0x1200
const S_STAR := 0x1300       # + 1 gold
const S_GAUGE_HEART := 0x1400  # + 1 cleared
const S_HEART := 0x1500
const S_HEART_EMPTY := 0x1600
const S_FILL := 0x10000      # + half-pixels of width * 2 + (1 cleared)
const RIPPLE_STEPS := 8
const BURST_STEPS := 10
## A tint's alpha (and a rainbow's hue) is cut into this many steps, so the
## painted colours are found again.
const TINT_STEPS := 24.0
## A firework's life in looks, its trails, and the radius its looks are made at.
const FW_STEPS := 32
const FW_TRAILS := 16
const FW_R := 100.0
var _looks := {}
var _road: RunMesh
var _top: RunMesh
var _over: RunMesh
var _veil_w := 0.0
var _fw: RunMesh
var _fw_cols := {}
var _fw_tiled := PackedInt32Array()
var _fw_tiled_n := 0
## The first note that can still be on screen: every loop over the notes
## starts here.
var _first := 0
var _held_was := false
## Looks waiting to be made, a few a frame from the moment the board opens,
## so the first cheer, Go-Go or firework of a song makes nothing.
var _warm: Array = []

func puzzle_id() -> String: return "drumbeat"
func title() -> String: return "Drumbeat"

func rules() -> String:
	var out := tr("DB_RULES")
	var hearts: int = State.HEARTS[clampi(_level, 0, 3)]
	if _level == 3:
		out += "\n\n" + tr("DB_RULES_ECHO") % hearts
	elif hearts > 0:
		out += "\n\n" + tr("DB_RULES_HEARTS") % hearts
	return out

## Nothing to take back or check: the song is its own judge. Reset (a fresh
## start of the song) is the host's.
func capabilities() -> Array[String]:
	return []

## The tutorial, a page a rule, each the road and the drums themselves
## playing a few notes (ui/hud/drumbeat_tutorial_diagram.gd): the stroke,
## the drums (two or more), ribbons, golden bars and balloons, the soul
## gauge (and the hearts, Hard and Insane), Echo (Insane), and the top bar.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/drumbeat_tutorial_diagram.gd")
	var level := clampi(_level, 0, 3)
	var hearts: int = State.HEARTS[level]
	var steps := [[Diagram.Lesson.STRIKE, "HTP_DB_STRIKE", tr("HTP_DB_STRIKE_BODY")]]
	if level >= 1:
		steps.append([Diagram.Lesson.DRUMS, "HTP_DB_DRUMS", tr("HTP_DB_DRUMS_BODY_TWIN" if level >= 2 else "HTP_DB_DRUMS_BODY")])
	steps.append([Diagram.Lesson.HOLD, "HTP_DB_HOLD", tr("HTP_DB_HOLD_BODY")])
	steps.append([Diagram.Lesson.ROLL, "HTP_DB_ROLL", tr("HTP_DB_ROLL_BODY")])
	steps.append([Diagram.Lesson.SOUL, "HTP_DB_SOUL", tr("HTP_DB_SOUL_BODY_HEARTS") % hearts if hearts > 0 else tr("HTP_DB_SOUL_BODY")])
	if level == 3:
		steps.append([Diagram.Lesson.ECHO, "HTP_DB_ECHO", tr("HTP_DB_ECHO_BODY")])
	steps.append([Diagram.Lesson.HUD, "HTP_DB_HUD", tr("HTP_DB_HUD_BODY")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = level
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_road = RunMesh.new(_shape)
	_top = RunMesh.new(_shape)
	_over = RunMesh.new(_shape)
	_top.share_shapes(_road)
	_over.share_shapes(_road)
	_fw = RunMesh.new(_fw_shape)
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 3
	add_child(fx)
	_rw = Rewards.new()
	_rw.z_index = 4
	add_child(_rw)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_lead = AudioStreamPlayer.new()
	add_child(_lead)
	_make_voices()
	_load_offset()
	resized.connect(_layout)
	solved.connect(_on_solved)

## Each drum's voice, a pool of players a drum.
func _make_voices() -> void:
	for kind in 4:
		var path := "res://assets/sfx/drumbeat/drum_%d.ogg" % kind
		var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
		var pool: Array = []
		for i in VOICES:
			var p := AudioStreamPlayer.new()
			p.stream = stream
			add_child(p)
			pool.append(p)
		_voices.append(pool)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_pause(true)
	elif what == NOTIFICATION_EXIT_TREE:
		_close_card()

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_songs = State.songs()
	_level = difficulty
	if _songs.is_empty():
		return
	_song = _songs[rng.randi() % _songs.size()]
	_log = ""
	_plays = 0
	_kept_hearts = -1
	_heart_used = false
	_fresh()
	_layout()
	fx.cue("enter")

## A new run at the song: the state, the clock and the motion, and the music
## stopped at its start. Hearts carry over a replay (`_kept_hearts`).
func _fresh() -> void:
	_st = State.new(_song, _level)
	if _kept_hearts >= 0 and _st.max_hearts > 0:
		_st.hearts = _kept_hearts
	_stop_music()
	_phase = "ready"
	_clock = -0.5
	_last_vt = -10.0
	_judge = {}
	_flies = []
	# two berries at one instant ride one over the other, the lower drum's on top
	_rows = {}
	var at := 0
	while at < _st.notes.size():
		var twins: Array = []
		var to := at
		while to < _st.notes.size() and absf(float(_st.notes[to].t) - float(_st.notes[at].t)) < 0.002:
			if int(_st.notes[to].type) <= State.Type.HOLD:
				twins.append(to)
			to += 1
		if twins.size() > 1:
			for k in twins.size():
				_rows[twins[k]] = k - (twins.size() - 1) * 0.5
		at = to
	_still = null
	_first = 0
	_ghosts = []
	_bursts = []
	_roll_pop = {}
	_balloon_gone = {}
	_fireworks = []
	_cheer_at = -10.0
	_worry_until = 0.0
	_party_until = 0.0
	_crowd_n = CROWD_START
	_joined = []
	for k in CROWD_MAX:
		_joined.append(-10.0)
	_score_shown = 0.0
	_soul_full_said = false
	_counted = -1
	_go_said = false
	_conga_at = -10.0
	_shades_at = INF
	_mood = Parts.Mood.HAPPY
	_duck = false
	_held = {}
	_goldens_hit = 0
	_reset_party()
	modulate = Color.WHITE
	_echo_bars = []
	for e: Array in _st.echo:
		_echo_bars.append([0, 0, 0, false])
	for n: Dictionary in _st.notes:
		if n.hidden:
			var k := _echo_bar(float(n.t))
			if k >= 0:
				_echo_bars[k][0] += 1
	_echo_said = 0
	_next_echo = 0
	# a golden berry: the first plain note into each Go-Go section
	_golden = {}
	for g: Array in _st.gogo:
		for i in _st.notes.size():
			var n: Dictionary = _st.notes[i]
			if float(n.t) >= float(g[0]) and n.type == State.Type.TAP and not n.hidden:
				_golden[i] = true
				break
	if _rw != null:
		_rw.clear()
	queue_redraw()

func _echo_bar(t: float) -> int:
	for k in _st.echo.size():
		var e: Array = _st.echo[k]
		if t >= float(e[0]) - 0.001 and t < float(e[1]):
			return k
	return -1

func _start(from := 0.0) -> void:
	if from <= 0.0:
		_fresh()
		_plays += 1
	_phase = "play"
	_play_music(String(_song.get("file", "")), String(_song.get("lead", "")), from)

func _play_music(file: String, lead: String, from: float) -> void:
	_music.stream = load(file) if file != "" and ResourceLoader.exists(file) else null
	_lead.stream = load(lead) if lead != "" and ResourceLoader.exists(lead) else null
	_music.pitch_scale = 1.0
	_lead.pitch_scale = 1.0
	_music.volume_db = 0.0
	_lead_db = 0.0
	_lead.volume_db = 0.0
	if _music.stream != null:
		_music.play(from)
	if _lead.stream != null:
		_lead.play(from)
	# the sound starts with the next mix, and reaches the ear an output
	# latency later (none, as far as Android tells)
	var wait := AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
	_zero_us = Time.get_ticks_usec() + int((wait - from) * 1e6)
	_last_vt = -10.0

func _stop_music() -> void:
	# (and no longer paused: a song reset while it waited under the ? must
	# sound when it starts again)
	if _music != null:
		_music.stop()
		_music.stream_paused = false
	if _lead != null:
		_lead.stop()
		_lead.stream_paused = false

func _pause(on: bool) -> void:
	if on and _phase == "play":
		_clock = song_now()
		_phase = "paused"
		_music.stream_paused = true
		_lead.stream_paused = true
		_st.lift_all(_clock - _offset)
		_handle()
		_release_all()
		queue_redraw()
	elif not on and _phase == "paused":
		_phase = "play"
		_music.stream_paused = false
		_lead.stream_paused = false
		var wait := AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
		_zero_us = Time.get_ticks_usec() + int((wait - _clock) * 1e6)
		queue_redraw()

# --- layout ---

func _u() -> float:
	return size.x / 1000.0

## Whether the stage stands over the road: the sky, the lanterns, the crowd
## and Tam, the fireworks, the cards and the big combo. A tutorial page's
## board (ui/hud/drumbeat_tutorial_diagram.gd) is the road and the drums alone.
func _staged() -> bool:
	return true

func _band_h() -> float:
	return BAND * _u()

## How many drums stand, and which of the band's drums stands at `lane`.
func _n() -> int:
	return _st.lanes if _st != null else 1

func _kind(lane: int) -> int:
	var kinds: Array = DRUM_KINDS[_n() - 1]
	return kinds[clampi(lane, 0, kinds.size() - 1)]

## The stage's foot, which is the road's top.
func _path_top() -> float:
	return size.y - (ROAD + GROUND) * _u()

func _stage_h() -> float:
	return _path_top() - _band_h()

## The line the berries ride, and the ring on it.
func _note_y() -> float:
	return _path_top() + ROAD_NOTE * _u()

func _ring() -> Vector2:
	return Vector2(RING_X * _u(), _note_y())

## A note's place along the road for its time to go `dt` (seconds before the
## ring): the card's right edge at the travel's start, the ring at 0, on
## past it to the left.
func _x_of(dt: float) -> float:
	var r := RING_X * _u()
	return r + dt / _travel() * (size.x + (NOTE_R + 10.0) * _u() - r)

## Note `i`'s height on the road: the line, or its row of a twin.
func _row_y(i: int) -> float:
	return _note_y() + float(_rows.get(i, 0.0)) * NOTE_R * TWIN * _u()

## Where note `i` is struck: the ring, at its row.
func _ring_at(i: int) -> Vector2:
	return Vector2(RING_X * _u(), _row_y(i))

## Over the ring, clear of the card's edge: where its stickers are said.
func _over_ring() -> Vector2:
	return Vector2(290.0 * _u(), _path_top() - 56.0 * _u())

func _travel() -> float:
	return TRAVEL[clampi(_level, 0, 3)]

func _drum_r() -> float:
	return DRUM_R[_n() - 1] * _u()

## Where drum `lane` stands: its foot, in its column of the ground.
func _drum_foot(lane: int) -> Vector2:
	return Vector2(size.x * (lane + 0.5) / _n(), size.y - DRUM_FOOT * _u())

func _drum_skin(lane: int) -> Vector2:
	return _drum_foot(lane) + Vector2(0, Parts.skin_y(_kind(lane), _drum_r()))

## Which drum a point of the board strikes: its column.
func _lane_at(at: Vector2) -> int:
	return clampi(int(floor(at.x / (size.x / _n()))), 0, _n() - 1)

func card_height(available: float) -> float:
	return available

func card_centred() -> bool:
	return false

func _layout() -> void:
	_still = null
	_looks = {}
	_veil_w = 0.0
	_fw_cols = {}
	_fw_tiled = PackedInt32Array()
	_fw_tiled_n = 0
	if _road != null:
		_road.reset()
		_top.share_shapes(_road)
		_over.share_shapes(_road)
		_fw.reset()
	_queue_warm()
	queue_redraw()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## The song's time now: off the microsecond clock while it plays.
func song_now() -> float:
	if _phase != "play" and _phase != "tune":
		return _clock
	return (Time.get_ticks_usec() - _zero_us) / 1e6

## The time the notes and the judge read: the song's, less the phone's
## timing, and never going back.
func view_t() -> float:
	var t := song_now() - _offset
	if _phase == "play":
		t = maxf(t, _last_vt)
	return t

# --- the frame loop ---

func _process(delta: float) -> void:
	super(delta)
	if _st == null:
		return
	# the ? is up over a song: the band waits
	# (on the moment it comes up only: a tap on a drum after it goes on)
	if clock_held and not _held_was and _phase == "play":
		_pause(true)
	_held_was = clock_held
	# looks a song will want, a couple a frame
	for k in 2:
		if not _warm.is_empty():
			(_warm.pop_front() as Callable).call()
	if _phase == "play" or _phase == "tune":
		_steer_clock()
	if _phase == "play":
		var vt := view_t()
		_last_vt = vt
		_st.update(vt)
		_handle()
		_count_in()
		_echo_cue(vt)
		_gather()
		_hold_motes()
	elif _phase == "tune":
		_tune_step()
	# the tune comes back after a dip
	var want: float = DUCK_DB[clampi(_level, 0, 3)] if _duck else 0.0
	# Echo: the tune steps aside under a hidden bar, so what the player hears
	# there is the band's backing and their own drums answering
	if _phase == "play" and not _st.echo.is_empty() and _st.echo_at(view_t()):
		want = ECHO_DB
	_lead_db = move_toward(_lead_db, want, DUCK_RATE * delta * (4.0 if want < _lead_db else 2.0))
	if _phase == "play":
		_lead.volume_db = _lead_db
	if _score_shown < _st.score:
		_score_shown = minf(float(_st.score), _score_shown + maxf(40.0, (_st.score - _score_shown) * minf(1.0, delta * 9.0)))
	elif _score_shown > _st.score:
		_score_shown = float(_st.score)
	_rw.bounds = Rect2(Vector2.ZERO, size)
	_rw.step(delta)
	if _party_at < INF:
		_place_cat(_now())
	queue_redraw()

## The music steers the clock: what the music has played, less what the
## output still holds, against what the clock says. A small difference is
## eased out a millisecond a frame at most, so the notes never stutter or
## step back; a big one (a stall, a resume) is taken at once.
func _steer_clock() -> void:
	if not _music.playing or _music.stream_paused:
		return
	var heard := _music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	var err := heard - song_now()
	if absf(err) > 0.12:
		_zero_us -= int(err * 1e6)
	else:
		_zero_us -= int(clampf(err * 0.05, -0.001, 0.001) * 1e6)

## The last three beats before the first note are counted out over the stage,
## and the first note is met with a Go!
func _count_in() -> void:
	if _st.notes.is_empty() or _go_said:
		return
	var first := float(_st.notes[0].t)
	var beat := _beat()
	var left := int(ceil((first - view_t()) / beat))
	if left <= 1:
		_go_said = true
		if not Motion.reduce:
			_rw.sticker(tr("DB_GO"), _stage_mid(), 88, 0.9, true, Color.WHITE, true, "count", 10.0)
	elif left <= 4 and left != _counted:
		_counted = left
		_rw.sticker(str(left - 1), _stage_mid(), 96, beat * 0.95, false, Parts.CREAM, false, "count", 0.0)

func _beat() -> float:
	return float(_song.get("beat", 0.5))

## Echo: Tam calls each hidden bar as it comes -- loudly the first times,
## then with a wink.
func _echo_cue(vt: float) -> void:
	while _next_echo < _st.echo.size() and vt >= float(_st.echo[_next_echo][0]) - _travel():
		var k := _next_echo
		_next_echo += 1
		if _echo_bars[k][0] == 0:
			continue
		_echo_said += 1
		fx.cue("echo", 1.0, -4.0 if _echo_said <= 3 else -10.0)
		_set_mood(Parts.Mood.JOY, 0.6)
		if _echo_said <= 2:
			_rw.sticker(tr("DB_ECHO_TURN"), _stage_mid() + Vector2(0, 40.0 * _u()), 54, 1.2, false, Parts.ECHO, false, "echo", 20.0)
		elif not Motion.reduce:
			_rw.spray(_frog_head(), Parts.ECHO, 3, 220.0, "note", 0.9)

## The crowd gathers as the soul gauge fills, each newcomer popping in with
## a heart. It never thins within a run.
func _gather() -> void:
	var want := CROWD_START + int(floor(_st.gauge / State.GAUGE_MAX * (CROWD_MAX - CROWD_START) + 0.001))
	want = clampi(want, CROWD_START, CROWD_MAX)
	while _crowd_n < want:
		var seat := _crowd_n
		_crowd_n += 1
		_joined[seat] = _now()
		if not Motion.reduce:
			_rw.spray(_seat(seat) + Vector2(0, -60.0 * _u()), Parts.BALLOON, 3, 180.0, "heart", 0.8)
		if _crowd_n == CROWD_MAX:
			_rw.sticker(tr("DB_CROWD"), _stage_mid() + Vector2(0, 60.0 * _u()), 50, 1.2, true, Color.WHITE, false, "crowd", 20.0)
			_cheer()

## A held drum hums: music notes rise off it while its ribbon is kept.
func _hold_motes() -> void:
	if Motion.reduce:
		return
	var now := _now()
	for i in range(_first, _st.notes.size()):
		var n: Dictionary = _st.notes[i]
		if float(n.t) > _last_vt:
			break
		if not n.held:
			continue
		var lane := int(n.lane)
		if now - _hold_note_at[lane] > 0.22:
			_hold_note_at[lane] = now
			_rw.spray(_drum_skin(lane) + Vector2(0, -20.0 * _u()), Parts.LANE_HI[_kind(lane)], 1, 160.0, "note", 0.8)

func _stage_mid() -> Vector2:
	return Vector2(size.x * 0.5, _band_h() + _stage_h() * 0.42)

# --- the strokes ---

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		accept_event()
		if e.pressed:
			var lane := _lane_at(e.position)
			_held[e.index] = lane
			_press_at(e.position, lane)
		elif _held.has(e.index):
			var lane: int = _held[e.index]
			_held.erase(e.index)
			_lift(lane)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var e := event as InputEventMouseButton
		accept_event()
		if e.pressed:
			var lane := _lane_at(e.position)
			_held[-1] = lane
			_press_at(e.position, lane)
		elif _held.has(-1):
			var lane: int = _held[-1]
			_held.erase(-1)
			_lift(lane)

## The keyboard, on a desktop: J for one drum, F and J for two, F, J and K
## for three.
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or event.echo:
		return
	var code := (event as InputEventKey).keycode
	var lane: int = (DRUM_KEYS[_n() - 1] as Array).find(code)
	if lane < 0 and _n() == 1 and code in [KEY_D, KEY_F, KEY_K, KEY_SPACE]:
		lane = 0
	if lane < 0:
		return
	if event.pressed:
		_held[100 + lane] = lane
		strike(lane)
	elif _held.has(100 + lane):
		_held.erase(100 + lane)
		_lift(lane)
	get_viewport().set_input_as_handled()

## A press at a point of the board. Before a song the card's buttons answer
## first; then it is a stroke on the drum under it.
func _press_at(at: Vector2, lane: int) -> void:
	if _phase == "ready" or _phase == "missed":
		var b := _card_button(at)
		if b != 0:
			_held.clear()
			if b == 2:
				_begin_tune(false)
			else:
				_set_offset(_offset + b * OFFSET_STEP)
				fx.cue("select", 1.0 + 0.05 * b)
			return
	strike(lane)

func strike(lane: int) -> void:
	if _st == null or _done:
		return
	_play_voice(lane)
	var t := _now()
	_hit_at[lane] = t
	_arm_at[_arm_next] = t
	_arm_next = 1 - _arm_next
	match _phase:
		"paused":
			_pause(false)
		"ready", "missed":
			if _needs_tune():
				_begin_tune(true)
			else:
				_start()
		"tune":
			_tune_taps.append(song_now())
		"play":
			var said := _st.press(view_t(), lane)
			if said == "" and not Motion.reduce:
				_bursts.append({"at": t, "col": Color(Parts.CREAM, 0.6), "pos": _drum_skin(lane), "big": false, "ring": false})
			_handle()

func _lift(lane: int) -> void:
	for l: int in _held.values():
		if l == lane:
			return
	if _phase == "play" and _st != null:
		_st.lift(view_t(), lane)
		_handle()

func _release_all() -> void:
	_held.clear()

func _play_voice(lane: int) -> void:
	var kind := _kind(lane)
	var pool: Array = _voices[kind]
	var p: AudioStreamPlayer = pool[_voice[kind] % VOICES]
	_voice[kind] += 1
	if p.stream != null:
		p.pitch_scale = randf_range(0.985, 1.015)
		p.play()
	UiSound.board_frame = Engine.get_process_frames()

# --- what the state said ---

func _handle() -> void:
	var t := _now()
	for ev: Dictionary in _st.events:
		match String(ev.type):
			"judge":
				_on_judge(ev, t)
			"slip":
				_set_drum_mood(-1, Parts.Mood.WORRIED)
			"hold_done":
				var lane := int(_st.notes[int(ev.i)].lane)
				var at := _ring_at(int(ev.i))
				_bursts.append({"at": t, "col": Parts.LANE_HI[_kind(lane)], "pos": at, "big": true, "ring": true})
				fx.cue("hold_done", 1.0 + 0.06 * lane, -6.0)
				if not Motion.reduce:
					_rw.spray(at, Parts.LANE_BODY[_kind(lane)], 5, 360.0, "star", 0.8)
			"hold_drop":
				pass
			"roll":
				_roll_pop = {"n": int(ev.hits), "at": t}
				if not Motion.reduce and int(ev.hits) % 4 == 0:
					_rw.spray(_ring(), Parts.ROLL, 2, 260.0, "spark", 0.6)
			"roll_end":
				if int(ev.hits) >= 8:
					_rw.sticker(tr("DB_HITS") % int(ev.hits), _over_ring(), 44, 0.9, false, Parts.ROLL, false, "roll", 20.0)
					_cheer()
			"balloon":
				fx.cue("balloon", 1.0 + 0.04 * clampf(float(_st.notes[int(ev.i)].hits), 0.0, 12.0), -4.0)
			"pop":
				var at := _ring()
				fx.cue("pop")
				_rw.spray(at, Parts.BALLOON, 14, 620.0, "confetti", 1.0)
				_rw.spray(at, GOLD, 6, 520.0, "star", 0.9)
				_rw.ring(at, 160.0 * _u(), Parts.BALLOON)
				_rw.sticker(tr("DB_POP"), _over_ring(), 64, 1.0, true, Color.WHITE, true, "pop", 24.0)
				_launch(1, 0.0)
				_cheer()
			"balloon_gone":
				_balloon_gone[int(ev.i)] = t
				fx.cue("balloon_gone")
			"combo":
				_on_combo(int(ev.n), t)
			"break":
				if int(ev.combo) >= 10:
					fx.cue("break")
					_set_mood(Parts.Mood.WORRIED, 1.0)
					_worry_until = t + 1.0
			"gogo_on":
				_gogo_at = t
				fx.cue("gogo")
				_rw.sticker(tr("DB_GOGO"), _stage_mid(), 72, 1.4, true, Color.WHITE, true, "gogo", 24.0)
				_rw.spray(_stage_mid(), GOLD, 12, 700.0, "star", 1.0)
				_launch(3, 0.0)
				_flare_at = t
				_cheer()
				_set_mood(Parts.Mood.JOY, 1.5)
			"soul_clear":
				_soul_at = t
				fx.cue("soul")
				_rw.spray(_gauge_line(), GOLD, 8, 420.0, "star", 0.8)
				_rw.sticker(tr("DB_SOUL_LINE"), _gauge_line() + Vector2(0, 80.0) * _u(), 40, 1.0, false, GOLD, false, "soul", 16.0)
				_launch(2, 0.0)
				_cheer()
			"soul_full":
				if not _soul_full_said:
					_soul_full_said = true
					_soul_at = t
					_rw.spray(_gauge_end(), GOLD, 10, 480.0, "star", 0.9)
					_rw.spray(_gauge_end(), Parts.BALLOON, 5, 300.0, "heart", 0.9)
					_rw.sticker(tr("DB_SOUL_MAX"), _gauge_end() + Vector2(-120.0, 80.0) * _u(), 42, 1.1, true, Color.WHITE, false, "soul", 16.0)
			"heart":
				_lose_heart(t, int(ev.left))
			"out":
				_run_out()
			"done":
				_song_over()
	_st.events.clear()

func _on_judge(ev: Dictionary, t: float) -> void:
	var grade := int(ev.grade)
	var i := int(ev.i)
	var lane := int(ev.lane)
	var n: Dictionary = _st.notes[i]
	var kind := _kind(lane)
	var at := _ring_at(i)
	_judge = {"grade": grade, "at": t}
	if grade == State.Grade.BAD:
		_duck = true
		_set_drum_mood(lane, Parts.Mood.WORRIED)
		if not bool(ev.passed):
			_bursts.append({"at": t, "col": JUDGE_COLS[2], "pos": at, "big": false, "ring": true})
		_echo_count(float(n.t), false)
		return
	_duck = false
	_set_drum_mood(lane, Parts.Mood.JOY)
	var golden := _golden.has(i)
	# (to the gauge: a board with no band over it has nowhere to send it)
	if (not n.held or golden) and _band_h() > 0.0:
		_flies.append({"lane": lane, "at": t, "golden": golden, "from": at})
	if bool(ev.hidden):
		_ghosts.append({"pos": at, "at": t})
		_echo_count(float(n.t), true)
	_bursts.append({"at": t, "col": JUDGE_COLS[grade], "pos": at, "big": grade == State.Grade.GOOD, "ring": true})
	_combo_at = t
	_score_at = t
	moves += 1
	var skin := at
	if not Motion.reduce:
		var juice: Color = Parts.LANE_BODY[kind]
		_rw.spray(skin, juice, 3 if grade == State.Grade.GOOD else 2, 420.0, "clod", 0.9)
		if grade == State.Grade.GOOD:
			_rw.spray(skin, Color(1, 1, 0.9), 2, 260.0, "spark", 0.8)
		if grade == State.Grade.GOOD and _st.combo % 10 == 0:
			_rw.spray(skin, GOLD, 3, 300.0, "star", 0.7, 0.0, _gauge_end())
	if golden:
		_goldens_hit += 1
		fx.cue("golden")
		_rw.sticker(tr("DB_GOLDEN"), _over_ring() + Vector2(60.0 * _u(), 0), 56, 1.2, true, Color.WHITE, true, "golden", 24.0)
		_rw.spray(skin, GOLD, 12, 640.0, "coin", 1.0)
		_rw.spray(_stage_mid(), Parts.BALLOON, 8, 420.0, "heart", 0.9)
		_launch(2, 0.0)
		_cheer()

## Echo: a hidden bar all struck is a perfect echo.
func _echo_count(t: float, hit: bool) -> void:
	var k := _echo_bar(t)
	if k < 0:
		return
	var eb: Array = _echo_bars[k]
	if hit:
		eb[1] += 1
	else:
		eb[2] += 1
	if not eb[3] and eb[1] + eb[2] >= eb[0] and eb[2] == 0 and eb[0] >= 2:
		eb[3] = true
		fx.cue("echo_perfect")
		var mid := Vector2(size.x * 0.5, _path_top() - 56.0 * _u())
		_rw.sticker(tr("DB_ECHO_PERFECT"), mid, 50, 1.0, false, Parts.ECHO, false, "echo_ok", 20.0)
		if not Motion.reduce:
			_rw.spray(mid, Parts.ECHO, 8, 420.0, "star", 0.9)

func _on_combo(n: int, t: float) -> void:
	fx.cue("combo", 1.0 + 0.04 * minf(n / 25.0, 6.0))
	var mid := _stage_mid()
	var word := 1
	for c: int in [25, 50, 100, 200]:
		if n >= c:
			word += 1
	_rw.sticker(tr("DB_WORD_%d" % word), mid + Vector2(0, -24.0 * _u()), 60 + word * 8, 1.3, true, Color.WHITE, n >= 50, "combo", 24.0)
	_rw.sticker(tr("DB_COMBO_CALL") % n, mid + Vector2(0, 58.0 * _u()), 40, 1.3, false, GOLD, false, "combo_n", 16.0, true)
	_rw.spray(mid, GOLD, 4 + word * 3, 520.0 + word * 60.0, "star", 1.0)
	if n >= 100:
		_rw.spray(mid, GOLD, 8, 600.0, "coin", 1.0)
	_launch(mini(word, 5), 0.0)
	_flare_at = t
	_cheer()
	_set_mood(Parts.Mood.JOY, 1.2)
	if n in CONGA_AT or (n > 150 and n % 100 == 50):
		_conga_at = t
		fx.cue("conga", 1.0, -4.0)
	if n >= TIERS[2] and _shades_at == INF:
		_shades_at = t
		fx.cue("shades")

func _set_mood(m: int, hold: float) -> void:
	_mood = m
	_mood_until = _now() + hold

## A drum's face for a moment: -1 is every drum.
func _set_drum_mood(lane: int, m: int) -> void:
	for l in _n():
		if lane < 0 or l == lane:
			_drum_mood[l] = m
			_drum_mood_until[l] = _now() + MOOD_TIME

## The crowd jumps with its paws up, and Tam with it.
func _cheer() -> void:
	_cheer_at = _now()

## `n` fireworks over the stage, half a beat apart, the first after `delay`.
func _launch(n: int, delay: float) -> void:
	if Motion.reduce:
		return
	var u := _u()
	var gap := _beat() * 0.5
	for k in n:
		_fireworks.append({"at": _now() + delay + k * gap,
			"pos": Vector2(size.x * randf_range(0.14, 0.86), _band_h() + randf_range(70.0, 170.0) * u),
			"ci": randi() % FIREWORK_COLS.size(),
			"r": randf_range(70.0, 110.0) * u, "turn": randf() * TAU})

## How hot the run is: 0 below the first of TIERS, up to 3.
func _tier() -> int:
	var t := 0
	for c: int in TIERS:
		if _st != null and _st.combo >= c:
			t += 1
	return t

## The crowd's seat `i`, along the foot of the stage over the road.
func _seat(i: int) -> Vector2:
	var u := _u()
	var order := [0, 9, 1, 8, 2, 7, 3, 6, 4, 5]
	var slot: int = order[i]
	var side := -1.0 if slot < 5 else 1.0
	var k := slot if slot < 5 else 9 - slot
	var x := size.x * 0.5 + side * (70.0 + k * 82.0) * u
	var back := k % 2 == 1
	return Vector2(x, _path_top() - (18.0 if back else 0.0) * u)

func _song_over() -> void:
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
	if _st.out:
		return
	if _st.cleared():
		_phase = "won"
		_set_mood(Parts.Mood.JOY, 100.0)
		_party_until = _now() + WIN_HOLD + 1.5
		check_solved()
	else:
		_clock = song_now()
		_phase = "missed"
		_kept_hearts = _st.hearts
		_wind_down(false)
		fx.cue("fail")
		_set_mood(Parts.Mood.SAD, 3.0)

# --- hearts ---

func _lose_heart(t: float, left: int) -> void:
	_split_index = left
	_split_at = t
	_log += "💔"
	fx.cue("heart_lost")
	_set_mood(Parts.Mood.SAD, 1.2)
	_worry_until = t + 1.2
	if not Motion.reduce:
		_rw.spray(_heart_at(left), HEART, 5, 260.0, "heart", 0.8)

## The last heart is gone: the band winds down -- the music slows and fades
## like a music box running out -- dusk falls, Tam nods off, and the card.
func _run_out() -> void:
	_stopped_at = view_t()
	_clock = song_now()
	_phase = "out"
	_running = false
	_release_all()
	_kept_hearts = 0
	fx.cue("out_of_hearts")
	_set_mood(Parts.Mood.SAD, 1.0e6)
	_wind_down(true)
	_dusk_toward(DUSK)
	get_tree().create_timer(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER).timeout.connect(_open_card)

## The music runs down: slowing and fading (or simply stopping, with reduce
## motion or when it ended anyway).
func _wind_down(slow: bool) -> void:
	Motion.stop(_wind_tw)
	if not slow or Motion.reduce or not _music.playing:
		_stop_music()
		return
	_wind_tw = create_tween().set_parallel(true)
	for p: AudioStreamPlayer in [_music, _lead]:
		_wind_tw.tween_property(p, "pitch_scale", 0.45, WIND_DOWN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_wind_tw.tween_property(p, "volume_db", -40.0, WIND_DOWN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_wind_tw.chain().tween_callback(_stop_music)

func _dusk_toward(tint: Color) -> void:
	Motion.stop(_dusk_tw)
	if Motion.reduce:
		modulate = tint
		return
	_dusk_tw = create_tween()
	_dusk_tw.tween_property(self, "modulate", tint, DUSK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _open_card() -> void:
	if not is_inside_tree() or _phase != "out" or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["DB_OUT_BODY", "DB_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the song from the top, every heart back, waiting on the start
## card.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	Motion.stop(_wind_tw)
	Motion.stop(_dusk_tw)
	_kept_hearts = -1
	_fresh()
	_log += "·"
	elapsed = 0.0
	moves = 0
	_running = true
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	fx.cue("reset")
	moved.emit()

## One more heart (the card's video), once a day: the band picks the song up
## a bar before where it stopped, with one heart.
func heart_back() -> void:
	if is_done() or _phase != "out":
		return
	_close_card()
	Motion.stop(_wind_tw)
	_heart_used = true
	_back_at = _now()
	_running = true
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	_set_mood(Parts.Mood.JOY, 1.0)
	if _st.done:
		# it ran out at the song's end: the song again, one heart
		_kept_hearts = 1
		_fresh()
		_start_with_hearts()
		return
	var beat := _beat()
	var from := maxf(0.0, _stopped_at - PICK_UP_BEATS * beat)
	_st.revive(_stopped_at)
	_first = 0
	_duck = false
	_last_vt = -10.0
	_counted = -1
	_go_said = true
	_phase = "play"
	_play_music(String(_song.get("file", "")), String(_song.get("lead", "")), from)
	_rw.sticker(tr("DB_PICK_UP"), _stage_mid(), 64, 1.4, true, Color.WHITE, false, "count", 20.0)
	moved.emit()

func _start_with_hearts() -> void:
	_phase = "play"
	_plays += 1
	_play_music(String(_song.get("file", "")), String(_song.get("lead", "")), 0.0)
	moved.emit()

func _leave_board() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

# --- the win ---

func is_solved() -> bool:
	return _st != null and _st.done and _st.cleared() and not _st.out

func _on_solved() -> void:
	var crown := "DB_CLEARED"
	if _st.all_good():
		crown = "DB_ALL_GOOD"
	elif _st.full_combo():
		crown = "DB_FULL_COMBO"
	elif _level == 3:
		crown = "DB_ECHO_CLEARED"
	fx.cue("full_combo" if _st.full_combo() else "clear")
	var mid := Vector2(size.x * 0.5, _band_h() + _stage_h() * 0.45)
	_rw.sticker(tr(crown), mid, 84, WIN_HOLD, true, Color.WHITE, true, "crown", 24.0)
	if not Motion.reduce:
		_rw.rain(WIN_HOLD, ["confetti", "star", "note"], Rewards.CONFETTI)
		_rw.spray(mid, GOLD, 16, 760.0, "star", 1.1)
		_rw.spray(mid, GOLD, 10, 640.0, "coin", 1.0)
		var volley := 6 + (3 if _st.full_combo() else 0) + (3 if _st.all_good() else 0)
		_launch(volley, 0.0)
		_launch(volley / 2, 1.4)
	_party()

func _reset_party() -> void:
	_party_at = INF
	_stamp_at = INF
	_seal_mesh = null
	if is_instance_valid(_cat):
		_cat.queue_free()
	_cat = null

## After the win: the nap cat hops onto the big drum and curls up, and the
## seal when the song earned one (a full combo, or Insane cleared).
func _party() -> void:
	var t := _now()
	_party_at = t + (0.0 if Motion.reduce else PARTY_AT)
	if _st.full_combo() or _level == 3:
		_stamp_at = t if Motion.reduce else _party_at + STAMP_AT
		_seal_mesh = null
		get_tree().create_timer(maxf(0.01, _stamp_at - t)).timeout.connect(func():
			if is_inside_tree():
				fx.cue("stamp"))
	if Motion.reduce:
		return
	get_tree().create_timer(PARTY_AT).timeout.connect(func():
		if not is_inside_tree():
			return
		fx.cue("party")
		_conga_at = _now())

func _place_cat(t: float) -> void:
	if t < _party_at:
		return
	var px := size.x * 0.16
	if not is_instance_valid(_cat):
		_cat = NapCat.new()
		_cat.name = "Cat"
		_cat.need = 0
		_cat.z_index = 3
		_cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cat.expression = Face.Expr.JOY
		add_child(_cat)
		_cat.set_idle(true)
	if _cat.size.x != px:
		_cat.size = Vector2(px, px)
		_cat.pivot_offset = _cat.size * Vector2(0.5, 0.85)
	var spot := _drum_skin(0) + Vector2(0, -6.0 * _u())
	var e := t - _party_at
	var start := spot + Vector2(-0.3 * size.x, -px)
	var at := spot
	var sc := Vector2.ONE
	if Motion.reduce or e >= 1.3:
		_cat.expression = Face.Expr.SLEEPY
		if not Motion.reduce and e < 1.4:
			fx.cue("purr")
	elif e < 0.9:
		var u := e / 0.9
		at = start.lerp(spot, u) - Vector2(0, sin(u * PI) * px * 0.6)
		sc = Motion.pop_in_scale(e, 0.22)
	else:
		var q := 0.12 * sin((e - 0.9) / 0.4 * PI)
		sc = Vector2(1.0 + q, 1.0 - q)
	_cat.position = at - _cat.size * Vector2(0.5, 0.82)
	_cat.scale = sc

func reset_board() -> void:
	_close_card()
	Motion.stop(_wind_tw)
	Motion.stop(_dusk_tw)
	_kept_hearts = -1
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

## A reopened daily that was already cleared: the stage at rest, the band
## beaming, and the score it was cleared with.
func restore_completed_board() -> void:
	if _st == null:
		return
	_stop_music()
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
	_crowd_n = CROWD_MAX
	_score_shown = float(_st.score)

# --- the timing ---

func _load_offset() -> void:
	var cfg := ConfigFile.new()
	var ok := cfg.load(SETTINGS) == OK
	_tuned = ok and bool(cfg.get_value("timing", "tuned", false))
	if ok and cfg.has_section_key("timing", "offset"):
		_offset = float(cfg.get_value("timing", "offset", 0.0))
	elif _phone_blind():
		_offset = PHONE_GUESS

## A phone whose audio latency the engine cannot read: its first guess, and
## the tap-along before its first song.
func _phone_blind() -> bool:
	return OS.has_feature("mobile") and AudioServer.get_output_latency() < 0.005

func _needs_tune() -> bool:
	return not _tuned and _phone_blind()

func _set_offset(v: float, tuned := false) -> void:
	_offset = clampf(snappedf(v, 0.005), -OFFSET_MAX, OFFSET_MAX)
	if tuned:
		_tuned = true
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("timing", "offset", _offset)
	cfg.set_value("timing", "tuned", _tuned or bool(cfg.get_value("timing", "tuned", false)))
	cfg.save(SETTINGS)
	queue_redraw()

## The tap-along: the wood block knocks CALIB clicks, the player taps any
## drum with each, and the timing is how late the taps land, on the median.
func _begin_tune(then_play: bool) -> void:
	var c := State.calib()
	if c.is_empty():
		if then_play:
			_start()
		return
	_tune_then_play = then_play
	_tune_taps = []
	_tune_result = INF
	_phase = "tune"
	_play_music(String(c.file), "", 0.0)
	fx.cue("select")

func _tune_clicks() -> Array:
	return State.calib().get("clicks", [])

func _tune_step() -> void:
	var clicks := _tune_clicks()
	if clicks.is_empty():
		return
	if song_now() < float(clicks[clicks.size() - 1]) + 0.6:
		return
	_stop_music()
	var lags: Array = []
	for tap: float in _tune_taps:
		var best := INF
		var idx := -1
		for k in clicks.size():
			var d := tap - float(clicks[k])
			if absf(d) < absf(best):
				best = d
				idx = k
		if idx >= TUNE_FROM and absf(best) < 0.4:
			lags.append(best)
	_clock = 0.0
	_phase = "ready"
	if lags.size() < TUNE_MIN:
		_tune_result = INF
		_rw.sticker(tr("DB_TUNE_AGAIN"), _stage_mid(), 44, 1.6, false, Parts.CREAM, false, "tune", 10.0)
		return
	lags.sort()
	var mid: float = lags[lags.size() / 2]
	_set_offset(mid, true)
	_tune_result = _offset
	fx.cue("tune_done")
	_rw.sticker(tr("DB_TUNED") % ("%+d" % int(roundf(_offset * 1000.0))), _stage_mid(), 48, 1.6, false, GOLD, false, "tune", 10.0)
	if _tune_then_play:
		_tune_then_play = false
		get_tree().create_timer(0.9).timeout.connect(func():
			if is_inside_tree() and _phase == "ready":
				_start())

## The card the start and the retry are written on, over the stage and path.
func _card_rect() -> Rect2:
	var u := _u()
	return Rect2(Vector2(40.0 * u, _band_h() + 14.0 * u), Vector2(size.x - 80.0 * u, 640.0 * u))

## The card's three buttons at its foot: the timing's minus, Tune, plus.
func _card_rects() -> Array:
	var r := _card_rect()
	var u := _u()
	var y := r.end.y - 92.0 * u
	var s := Vector2(84.0, 68.0) * u
	var mid := Vector2(330.0, 68.0) * u
	var c := r.get_center().x
	return [Rect2(Vector2(c - mid.x * 0.5 - 24.0 * u - s.x, y), s), Rect2(Vector2(c - mid.x * 0.5, y), mid), Rect2(Vector2(c + mid.x * 0.5 + 24.0 * u, y), s)]

## -1 or 1 for the timing's buttons, 2 for Tune, 0 for none.
func _card_button(at: Vector2) -> int:
	var rects := _card_rects()
	if (rects[0] as Rect2).grow(10.0).has_point(at):
		return -1
	if (rects[2] as Rect2).grow(10.0).has_point(at):
		return 1
	if (rects[1] as Rect2).grow(8.0).has_point(at):
		return 2
	return 0

# --- drawing ---

func _gauge_rect() -> Rect2:
	var u := _u()
	return Rect2(Vector2(size.x * 0.5, _band_h() * 0.5 - 16.0 * u), Vector2(size.x * 0.44, 32.0 * u))

func _gauge_line() -> Vector2:
	var r := _gauge_rect()
	return Vector2(r.position.x + r.size.x * State.CLEAR / State.GAUGE_MAX, r.get_center().y)

func _gauge_end() -> Vector2:
	var r := _gauge_rect()
	return Vector2(r.end.x - 20.0 * _u(), r.get_center().y)

## Heart `i` in the band, between the score and the gauge.
func _heart_at(i: int) -> Vector2:
	var u := _u()
	return Vector2(size.x * 0.33 + i * 44.0 * u, _band_h() * 0.56)

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
	var vt := view_t() if _phase == "play" else _clock - _offset
	var beat := _beat()
	var bars: Array = _song.get("bars", [])
	var first := float(bars[0]) if not bars.is_empty() else 0.0
	var beats := (vt - first) / beat
	var playing := _phase == "play"
	var gogo := _st.in_gogo and playing
	var calm := Motion.reduce
	var tier := _tier() if playing else 0
	var pulse := 0.0 if calm or not playing else pow(1.0 - fposmod(beats, 1.0), 3.0)
	_trim(vt)

	if _staged():
		_draw_stage(now, beats, gogo, tier, pulse)

	# the road, one mesh: Go-Go warms it; Echo's hidden bars under a lilac
	# veil; a hot run lights its rails; the ring every berry is struck in
	# breathes on the beat and flashes on a stroke in the colour of the drum
	# struck; bar lines, ribbons and marks ride it with the berries
	var ring := _ring()
	_road.begin()
	if gogo:
		var a := 0.12 + 0.1 * (0.0 if calm else absf(sin(beats * PI)))
		_road.put(S_WASH, [Color(PATH_GOGO, _q(a))], Transform2D.IDENTITY)
	_draw_veils(vt, now)
	if tier > 0:
		var rail: Color = [GOLD, Color("ff9a4a"), Color.from_hsv(_q(fmod(now * 0.25, 1.0)), 0.55, 1.0)][tier - 1]
		_road.put(S_RAILS + tier, [Color(rail, _q(0.4 + 0.35 * pulse))], Transform2D.IDENTITY)
	var rr := (NOTE_R + 10.0) * u
	var swell := (rr + (9.0 + 6.0 * pulse) * u) / (rr + 9.0 * u)
	_road.put(S_RING_PULSE, [Color(Parts.CREAM, _q(0.22 + 0.3 * pulse))], Transform2D(0.0, Vector2(swell, swell), 0.0, ring))
	_road.put(S_RING, [], Transform2D(0.0, ring))
	var struck := 0
	for lane in _n():
		if float(_hit_at[lane]) > float(_hit_at[struck]):
			struck = lane
	var fl := 1.0 - clampf((now - float(_hit_at[struck])) / FLASH_TIME, 0.0, 1.0)
	if fl > 0.0 and not calm:
		var fs := 1.0 + 0.2 * (1.0 - fl)
		_road.put(S_DISC, [Color(Parts.LANE_HI[_kind(struck)], _q(0.45 * fl))], Transform2D(0.0, Vector2(fs, fs), 0.0, ring))
	for bt: float in bars:
		var x := _x_of(bt - vt)
		if x < ring.x - 100.0 * u or x > size.x:
			continue
		_road.put(S_BAR, [], Transform2D(0.0, Vector2(x, 0.0)))
	_draw_long(vt)
	_draw_marks(vt)
	_put_mesh(_road.mesh())

	_draw_notes(vt, now)
	_draw_balloons(vt, now)

	# over the notes, one mesh: the gauge and the hearts, the glow on the
	# drum the next berry wants as it nears the ring, the bursts in the ring
	var n_d := _n()
	_top.begin()
	if _band_h() > 0.0:
		_draw_gauge(now, pulse)
		_draw_hearts(now)
	if playing and n_d > 1:
		for h: Array in _next_up(vt):
			var c := _drum_foot(int(h[0])) + Vector2(0, -_drum_r() * 0.6)
			_top.put(S_GLOW, [Color(GOLD, _q(0.16 + 0.44 * float(h[1])))], Transform2D(0.0, c))
	for bu: Dictionary in _bursts:
		var k := (now - float(bu.at)) / BURST_TIME
		if k >= 1.0 or calm:
			continue
		var col: Color = bu.col
		var step := mini(int(k * BURST_STEPS), BURST_STEPS - 1)
		var grow := (0.8 + 0.7 * k) / (0.8 + 0.7 * (step + 0.5) / BURST_STEPS)
		var ba := _q(0.9 * (1.0 - k))
		_top.put(S_BURST + ((1 if bu.big else 0) if bu.ring else 2) * 16 + step, [Color(col.r, col.g, col.b, ba), Color(col.r, col.g, col.b, ba * 0.5)],
			Transform2D(0.0, Vector2(grow, grow), 0.0, bu.pos))
	_bursts = _bursts.filter(func(bu: Dictionary) -> bool: return now - float(bu.at) < BURST_TIME)
	_put_mesh(_top.mesh())
	for g: Dictionary in _ghosts:
		var k := (now - float(g.at)) / 0.5
		if k >= 1.0:
			continue
		var sc := 1.0 + 0.6 * k
		draw_mesh(Parts.ghost(NOTE_R * u), null, Transform2D(0.0, Vector2(sc, sc), 0.0, (g.pos as Vector2) + Vector2(0, -k * 30.0 * u)), Color(1, 1, 1, 1.0 - k))
	_ghosts = _ghosts.filter(func(g: Dictionary) -> bool: return now - float(g.at) < 0.5)

	# the combo, faint and large on the ground over the drums
	if _st.combo >= 3 and playing and _staged():
		_draw_path_combo(now, tier)

	# the drums, squashed on a stroke, nodding on the beat, each with its
	# mark on its skin
	_over.begin()
	for lane in n_d:
		var kind := _kind(lane)
		var foot := _drum_foot(lane)
		var since := now - float(_hit_at[lane])
		var squash := 1.0
		var nod := 0.0
		if not calm:
			squash -= 0.07 * (1.0 - clampf(since / SQUASH_TIME, 0.0, 1.0))
			if playing:
				nod = 0.012 * pulse
		var mood: int = _drum_mood[lane] if now < float(_drum_mood_until[lane]) else Parts.Mood.HAPPY
		if _phase == "out":
			mood = Parts.Mood.SAD
		elif _phase == "won":
			mood = Parts.Mood.JOY
		var wob := 0.0 if calm or since > 0.3 else sin(since * 40.0) * 0.04 * (1.0 - since / 0.3)
		draw_mesh(_drum_look(kind, mood), null, Transform2D(wob, Vector2((1.0 + nod) / squash, (1.0 + nod) * squash), 0.0, foot))
		if since < 0.36 and not calm:
			var k := since / 0.36
			var skin := foot + Vector2(0, Parts.skin_y(kind, _drum_r()) * (1.0 + nod) * squash)
			var step := mini(int(k * RIPPLE_STEPS), RIPPLE_STEPS - 1)
			var grow := (0.35 + 0.5 * k) / (0.35 + 0.5 * (step + 0.5) / RIPPLE_STEPS)
			_over.put(S_RIPPLE + step, [Color(Parts.LANE_HI[kind], _q(0.8 * (1.0 - k)))], Transform2D(0.0, Vector2(grow, grow), 0.0, skin))
	for f: Dictionary in _flies:
		var k := (now - float(f.at)) / FLY_TIME
		if k >= 1.0 or calm:
			continue
		var from: Vector2 = f.from
		var to := _gauge_end()
		var p := from.lerp(to, k) + Vector2(0, -sin(k * PI) * 160.0 * u)
		var sc := lerpf(1.0, 0.45, k)
		var m := Parts.golden_berry(NOTE_R * u) if f.golden else Parts.berry(_kind(int(f.lane)), NOTE_R * u, Parts.Mood.JOY)
		draw_mesh(m, null, Transform2D(k * 4.0, Vector2(sc, sc), 0.0, p))
	_flies = _flies.filter(func(f: Dictionary) -> bool: return now - float(f.at) < FLY_TIME)

	# the card's edges glow in Go-Go, on a hot run and through the finale
	var heat := 0.0
	if gogo:
		heat = 0.8
	elif tier >= 2:
		heat = 0.35 + 0.15 * (tier - 2)
	if _phase == "won" and now < _party_until:
		heat = 0.7
	if heat > 0.0 and not calm:
		var eg := Face.Builder.new()
		Rewards.edge_glow(eg, Rect2(Vector2.ZERO, size), Color("ffb347") if tier < 3 or gogo else Color.from_hsv(fmod(now * 0.2, 1.0), 0.5, 1.0), heat, pulse)
		_over.put_builder(eg)
	# over the drums, one mesh: a stroke's ripple on its skin, the edges' glow
	_put_mesh(_over.mesh())
	if _stamp_at < INF and now >= _stamp_at:
		_draw_stamp(now)
	_draw_words(now)

## The stage over the road: the sky's Go-Go warmth and the fireworks, the
## lanterns on their cord swinging to the beat, the conga, the crowd and Tam.
func _draw_stage(now: float, beats: float, gogo: bool, tier: int, pulse: float) -> void:
	var u := _u()
	var calm := Motion.reduce
	var sky := Face.Builder.new()
	if gogo:
		var top := _band_h()
		var low := _path_top()
		var warm := Color("ff7a59", 0.0)
		var i0 := sky.vertex(Vector2(0, top), warm)
		var i1 := sky.vertex(Vector2(size.x, top), warm)
		var hot := Color("ff7a59", 0.22 + 0.12 * pulse)
		var i2 := sky.vertex(Vector2(size.x, low), hot)
		var i3 := sky.vertex(Vector2(0, low), hot)
		sky.tri(i0, i1, i2)
		sky.tri(i0, i2, i3)
	_draw_rockets(sky, now)
	_draw_fireworks(sky, now)
	var flare := 1.0 - clampf((now - _flare_at) / 0.8, 0.0, 1.0)
	var n_l := LANTERN_COLS.size()
	for k in n_l:
		var x := size.x * (0.1 + 0.8 * k / float(n_l - 1))
		var sag := sin(PI * k / float(n_l - 1)) * 30.0 * u
		var hang := Vector2(x, _band_h() + 30.0 * u + sag)
		var swing := 0.0 if calm else sin(beats * PI + k) * ((0.12 if gogo else 0.05) + 0.25 * flare)
		var glow := 1.0 if gogo or flare > 0.0 or _phase == "won" else 0.35 + 0.15 * tier
		var sc := 1.0 + (0.0 if calm else 0.08 * pulse * (1.0 if gogo else 0.4))
		draw_mesh(Parts.lantern(22.0 * u, LANTERN_COLS[k], glow), null, Transform2D(swing, Vector2(sc, sc), 0.0, hang))
	_draw_conga(now, beats)
	_draw_crowd(now, beats, gogo, tier)
	_draw_frog(now, beats, gogo)

## Notes long gone by are left behind: `_first` is the earliest that can
## still be on screen.
func _trim(vt: float) -> void:
	var notes: Array = _st.notes
	while _first < notes.size():
		var n: Dictionary = notes[_first]
		if n.held or maxf(float(n.t), float(n.end)) > vt - 2.0:
			break
		_first += 1

# --- looks ---

## A tint's alpha (or a hue) in steps.
func _q(a: float) -> float:
	return roundf(a * TINT_STEPS) / TINT_STEPS

## Draws a mesh made this frame, keeping it until the next frame's.
func _put_mesh(m: ArrayMesh) -> void:
	if m == null:
		return
	_shown.append(m)
	draw_mesh(m, null)

## Drum `kind` in mood `mood` with its mark on its skin: the drum's own
## arrays with the mark's after them, a mesh drawn under the drum's squash.
func _drum_look(kind: int, mood: int) -> ArrayMesh:
	var key := kind * 8 + mood
	var hit: ArrayMesh = _looks.get(key)
	if hit != null:
		return hit
	var bd := Face.Builder.new()
	var arrays := Parts.band_drum(kind, _drum_r(), mood).surface_get_arrays(0)
	_mark(bd, kind, Vector2(0, Parts.skin_y(kind, _drum_r())), _drum_r() * 0.3, Color(Parts.LANE_BODY[kind], 0.9), 0.3)
	var verts: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var base := verts.size()
	var ix := bd.idx.duplicate()
	for i in ix.size():
		ix[i] += base
	verts.append_array(bd.verts)
	cols.append_array(bd.cols)
	idx.append_array(ix)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_COLOR] = cols
	out[Mesh.ARRAY_INDEX] = idx
	var dm := ArrayMesh.new()
	dm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	_looks[key] = dm
	return dm

## Shape `id` (an S_ constant and what it adds), made the first time it is
## put: about its own origin unless it lies where it is drawn (the wash, the
## rails, the gauge's ticks and fill), in its own colours unless it is
## tinted, when it is in slot 0 (a star in three).
func _shape(id: int) -> Face.Builder:
	var u := _u()
	var o := Vector2.ZERO
	var b := Face.Builder.new()
	var top := _path_top()
	var plank := top + ROAD_RAIL * u
	var floor_y := top + ROAD_FLOOR * u
	var rr := (NOTE_R + 10.0) * u
	var tint := RunMesh.slot(0)
	if id >= S_FILL:
		# the gauge filled `w` wide, past its line or not, with its sheen
		var r := _gauge_rect()
		var w := float((id - S_FILL) >> 1) * 0.5
		b.polygon(Face.Builder.round_rect(r.position, Vector2(w, r.size.y), r.size.y * 0.5), GAUGE_CLEAR if (id - S_FILL) & 1 == 1 else GAUGE_FILL)
		b.polygon(Face.Builder.round_rect(r.position + Vector2(r.size.y * 0.3, r.size.y * 0.16), Vector2(maxf(0.0, w - r.size.y * 0.6), r.size.y * 0.22), r.size.y * 0.11), Color(1, 1, 1, 0.35))
		return b
	var a := id & 0xff
	match id & ~0xff:
		S_BAR:
			b.stroke(PackedVector2Array([Vector2(0, plank), Vector2(0, floor_y)]), 3.0 * u, Color(1, 1, 1, 0.22))
		S_BEAD:
			b.disc(o, 6.0 * u, Color(Parts.CREAM, 0.75))
		S_MARK:
			_mark(b, a >> 1, o, (13.0 if a & 1 == 1 else 16.0) * u, Parts.LANE_BODY[a >> 1])
		S_ROLL:
			_mark(b, a, o, 12.0 * u, Parts.ROLL_DEEP)
		S_CAP, S_BODY:
			# a ribbon's round end and its body a pixel long: a hold's or a
			# drumroll's (2), its ink or the ribbon itself (1)
			var half := NOTE_R * (0.8 if a >= 2 else 0.4) * u + (0.0 if a % 2 == 1 else 5.0 * u)
			if id & ~0xff == S_BODY:
				# (a stroke: feathered along its sides only, so the stretch
				# leaves its ends square under the round ones)
				b.stroke(PackedVector2Array([o, Vector2(1.0, 0.0)]), half * 2.0, tint, false, false)
			else:
				b.disc(o, half, tint)
		S_RING:
			# about the ring's centre: its pale disc, the ring, the post down
			# to the marks' strip
			var ry := _note_y()
			b.disc(o, rr, Color(Parts.CREAM, 0.14))
			b.stroke(_ellipse_pts(o, rr, rr), 7.0 * u, Parts.CREAM, true)
			b.stroke(PackedVector2Array([Vector2(0, floor_y + 12.0 * u - ry), Vector2(0, top + (ROAD - 10.0) * u - ry)]), 4.0 * u, Color(Parts.CREAM, 0.5))
		S_RING_PULSE:
			b.stroke(_ellipse_pts(o, rr + 9.0 * u, rr + 9.0 * u), 6.0 * u, tint, true)
		S_DISC:
			b.disc(o, rr, tint)
		S_WASH:
			b.polygon(_rect(0.0, plank, size.x, floor_y), tint)
		S_RAILS:
			for y: float in [top + ROAD_RAIL * 0.5 * u, floor_y + 5.0 * u]:
				b.stroke(PackedVector2Array([Vector2(0, y), Vector2(size.x, y)]), (5.0 + 2.0 * a) * u, tint)
		S_VEIL:
			# a hidden bar `_veil_w` long, from its left edge
			b.polygon(_rect(0.0, plank, _veil_w, floor_y), Color(Parts.ECHO, 0.4))
			for edge: float in [0.0, _veil_w]:
				b.stroke(PackedVector2Array([Vector2(edge, plank), Vector2(edge, floor_y)]), 5.0 * u, Color(Color("e6dcff"), 0.9))
		S_VEIL_STARS:
			# the moonlight in it, in three groups that twinkle apart
			for k in 9:
				if k % 3 != a:
					continue
				var f := fposmod(k * 0.37 + 0.13, 1.0)
				var y := lerpf(plank + 14.0 * u, floor_y - 14.0 * u, fposmod(k * 0.61, 1.0))
				Rewards._star(b, Vector2(_veil_w * f, y), 7.0 * u, 0.0, RunMesh.slot(0), RunMesh.slot(1), RunMesh.slot(2))
		S_GLOW:
			b.ellipse(o, _drum_r() * 1.28, _drum_r() * 1.02, tint)
		S_RIPPLE:
			var k := (a + 0.5) / RIPPLE_STEPS
			var s := 0.35 + 0.5 * k
			b.stroke(_ellipse_pts(o, _drum_r() * s, _drum_r() * 0.26 * s), 7.0 * u * (1.0 - k), tint, true)
		S_BURST:
			# a stroke's ring (0), a GOOD's with its rays (1), a bare drum's (2)
			var kind := a >> 4
			var k := ((a & 15) + 0.5) / BURST_STEPS
			var r := (NOTE_R * u * 1.2 if kind < 2 else _drum_r()) * (0.8 + 0.7 * k) * (1.2 if kind == 1 else 1.0)
			b.stroke(_ellipse_pts(o, r, r if kind < 2 else r * 0.42), 9.0 * u * (1.0 - k), tint, true)
			if kind == 1:
				# (half as strong as the ring: a second slot)
				Rewards.sunrays(b, o, r * 0.5, r * 0.95, 10, k * 0.6, RunMesh.slot(1))
		S_GAUGE_OVER:
			var r := _gauge_rect()
			for i in range(1, 10):
				var x := r.position.x + r.size.x * i / 10.0
				b.stroke(PackedVector2Array([Vector2(x, r.position.y + 6.0 * u), Vector2(x, r.end.y - 6.0 * u)]), 2.0 * u, Color(Parts.INK, 0.18))
			var line := _gauge_line()
			b.stroke(PackedVector2Array([line + Vector2(0, -r.size.y * 0.75), line + Vector2(0, r.size.y * 0.75)]), 5.0 * u, Parts.CREAM)
		S_GLINT:
			Rewards.glint(b, o, 100.0, 0.0)
		S_STAR:
			Rewards.star(b, o, 14.0 * u, GOLD if a == 1 else Parts.CREAM, 0.0)
		S_GAUGE_HEART:
			Rewards.heart(b, o, 22.0 * u * 1.12, 0.0, Color(Parts.INK, 0.6))
			Rewards.heart(b, o, 22.0 * u, 0.0, Parts.DON if a == 1 else Color("8a7a6e"))
		S_HEART:
			var r := 17.0 * u
			Rewards.heart(b, o, r * 1.15, 0.0, Color(Parts.INK, 0.55))
			Rewards.heart(b, o, r, 0.0, HEART)
			b.ellipse(Vector2(-r * 0.35, -r * 0.35), r * 0.18, r * 0.11, Color(1, 1, 1, 0.5))
		S_HEART_EMPTY:
			Rewards.heart(b, o, 17.0 * u, 0.0, Color(Parts.INK, 0.25))
	return b

## A fan of exactly `n` points, so every look of a drawing has one topology.
func _fan_n(b: Face.Builder, at: Vector2, r: float, colour: Color, n: int) -> void:
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		pts[i] = at + Vector2.from_angle(TAU * i / n) * r
	b.fan(pts, colour)

## A firework's burst at step `id` of its life, made about its heart at
## FW_R in slot colours: the flash (slot 4), then every trail and its head
## (the even trails slots 0 and 2, the odd 1 and 3). The look is drawn
## scaled by how far the burst has opened, so its widths are divided by that.
func _fw_shape(id: int) -> Face.Builder:
	var u := _u()
	var k := (id + 0.5) / FW_STEPS
	var out := 1.0 - pow(1.0 - k, 3.0)
	var back := 1.0 - pow(1.0 - maxf(0.0, k - 0.12), 3.0)
	var a := 1.0 - pow(k, 1.6)
	var r := FW_R * u
	var b := Face.Builder.new()
	_fan_n(b, Vector2.ZERO, (r * 0.55 * maxf(0.0, 1.0 - k / 0.2) + 6.0 * u) / out, RunMesh.slot(4), 14)
	for i in FW_TRAILS:
		var d := Vector2.from_angle(TAU * i / FW_TRAILS)
		b.stroke(PackedVector2Array([d * r * back / out, d * r]), 4.5 * u * a / out, RunMesh.slot(i % 2), false, false)
		_fan_n(b, d * r, 4.0 * u * (0.5 + 0.5 * a) / out, RunMesh.slot(2 + i % 2), 8)
	return b

## Step `step`'s colours for a firework of colour `ci`.
func _fw_colours(ci: int, step: int) -> PackedColorArray:
	var key := ci * FW_STEPS + step
	var hit = _fw_cols.get(key)
	if hit != null:
		return hit
	var k := (step + 0.5) / FW_STEPS
	var a := 1.0 - pow(k, 1.6)
	var col: Color = FIREWORK_COLS[ci]
	var light := col.lightened(0.35)
	var out := _fw.ink(step, [Color(col, 0.85 * a), Color(light, 0.85 * a), Color(col.lightened(0.5), a), Color(light.lightened(0.5), a),
		Color(col.lightened(0.6), 0.5 * maxf(0.0, 1.0 - k / 0.2))])
	_fw_cols[key] = out
	return out

## One firework look's indices tiled for `n` of them.
func _fw_indices(n: int) -> PackedInt32Array:
	var s := _fw.shape(0)
	var idx: PackedInt32Array = s[1]
	var per := idx.size()
	if n > _fw_tiled_n:
		var count := (s[0] as PackedVector2Array).size()
		var ix := PackedInt32Array()
		ix.resize((n - _fw_tiled_n) * per)
		for m in n - _fw_tiled_n:
			var base := (_fw_tiled_n + m) * count
			var w := m * per
			for j in per:
				ix[w + j] = idx[j] + base
		_fw_tiled.append_array(ix)
		_fw_tiled_n = n
	return _fw_tiled.slice(0, n * per)

## What a song will draw for the first time mid-song, made ahead: the
## fireworks' steps, the drums' moods, the crowd's and the berries' faces.
func _queue_warm() -> void:
	_warm = []
	if size.x <= 0.0 or _st == null:
		return
	var u := _u()
	var r := NOTE_R * u
	for lane in _n():
		var kind := _kind(lane)
		for mood in [Parts.Mood.JOY, Parts.Mood.WORRIED, Parts.Mood.SAD]:
			_warm.append(func() -> void:
				_drum_look(kind, mood)
				Parts.berry(kind, r, mood))
	_warm.append(func() -> void:
		Parts.golden_berry(r)
		Parts.ghost(r)
		Parts.shades(52.0 * u))
	for mood in [Parts.Mood.JOY, Parts.Mood.WORRIED, Parts.Mood.SAD]:
		_warm.append(func() -> void:
			Parts.frog(52.0 * u, mood, false)
			if mood != Parts.Mood.JOY:
				Parts.frog(52.0 * u, mood, true))
	for i in CROWD_MAX:
		var back := _seat(i).y < _path_top() - 1.0
		var s := (25.0 if back else 30.0) * u
		var kind := (i * 3 + 1) % Parts.CRITTERS.size()
		var stick: Color = STICK_COLS[i % STICK_COLS.size()]
		_warm.append(func() -> void:
			Parts.critter(kind, s, Parts.Mood.HAPPY, false, Color(0, 0, 0, 0))
			Parts.critter(kind, s, Parts.Mood.JOY, true, Color(0, 0, 0, 0)))
		_warm.append(func() -> void:
			Parts.critter(kind, s, Parts.Mood.JOY, true, stick)
			Parts.critter(kind, s, Parts.Mood.WORRIED, false, Color(0, 0, 0, 0)))
	for i in CONGA_N:
		_warm.append(func() -> void:
			Parts.critter((i * 2 + 3) % Parts.CRITTERS.size(), 22.0 * u, Parts.Mood.JOY, i % 2 == 0, STICK_COLS[i % STICK_COLS.size()]))
	_warm.append(func() -> void: _fw_indices(14))
	for step in FW_STEPS:
		_warm.append(func() -> void: _fw.shape(step))
	for k in LANTERN_COLS.size():
		_warm.append(func() -> void:
			for glow: float in [0.5, 0.65, 0.8, 1.0]:
				Parts.lantern(22.0 * u, LANTERN_COLS[k], glow))

func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

## A drum's mark, `s` its half-size: the big drum's dot, the hand drum's
## triangle, the jingle drum's diamond, the tongue drum's square. `flat`
## lays it on a skin seen from above.
func _mark(b: Face.Builder, kind: int, c: Vector2, s: float, col: Color, flat := 1.0) -> void:
	match kind:
		0:
			b.ellipse(c, s * 0.82, s * 0.82 * flat, col)
		1:
			b.polygon(PackedVector2Array([c + Vector2(0, -s * flat), c + Vector2(s * 0.95, s * 0.72 * flat), c + Vector2(-s * 0.95, s * 0.72 * flat)]), col)
		2:
			b.polygon(PackedVector2Array([c + Vector2(0, -s * flat), c + Vector2(s, 0), c + Vector2(0, s * flat), c + Vector2(-s, 0)]), col)
		_:
			b.polygon(_rect(c.x - s * 0.76, c.y - s * 0.76 * flat, c.x + s * 0.76, c.y + s * 0.76 * flat), col)

## The drums the next berry into the ring wants, and how near it is:
## [[lane, 0..1]], two for a twin. A hidden berry is never given away.
func _next_up(vt: float) -> Array:
	var reach := _travel() * GLOW_REACH
	var notes: Array = _st.notes
	for i in range(_first, notes.size()):
		var n: Dictionary = notes[i]
		if n.st != State.St.WAIT or n.held or n.hidden:
			continue
		var dt := float(n.t) - vt
		if State.is_long(n.type) and dt <= 0.0:
			if vt <= float(n.end):
				return [[int(n.lane), 1.0]]
			continue
		if dt > reach:
			return []
		var out := [[int(n.lane), 1.0 - clampf(dt / reach, 0.0, 1.0)]]
		for j in range(i + 1, notes.size()):
			if absf(float(notes[j].t) - float(n.t)) > 0.002:
				break
			if notes[j].st == State.St.WAIT and not notes[j].hidden:
				out.append([int(notes[j].lane), out[0][1]])
		return out
	return []

func _ellipse_pts(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 29:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## The long notes, into the road's mesh: a hold's ribbon from its berry
## back to its end (lit while kept), a drumroll's golden bar stamped with its
## drum's mark.
func _draw_long(vt: float) -> void:
	var u := _u()
	var ring_x := RING_X * u
	for i in range(_first, _st.notes.size()):
		var n: Dictionary = _st.notes[i]
		var t0 := float(n.t)
		if t0 - vt > _travel() + 0.1:
			break
		var type := int(n.type)
		if type == State.Type.TAP or type == State.Type.BALLOON or n.hidden:
			continue
		var t1 := float(n.end)
		if t1 < vt - 0.1:
			continue
		if n.st != State.St.WAIT and not n.held:
			continue
		var kind := _kind(int(n.lane))
		var roll := type == State.Type.ROLL
		var lit: bool = n.held or (roll and t0 <= vt)
		var x0 := ring_x if lit else _x_of(t0 - vt)
		var x1 := minf(_x_of(t1 - vt), size.x + 80.0 * u)
		if x1 <= x0:
			continue
		var y := _row_y(i)
		var half := NOTE_R * (0.8 if roll else 0.4) * u
		var col: Color = Parts.ROLL if roll else Parts.LANE_BODY[kind]
		# the ribbon, its ink under it: a round end, a body stretched to its
		# length, a round end
		for layer in 2:
			var v := (2 if roll else 0) + layer
			var paint := [Parts.INK if layer == 0 else col.lightened(0.3 if lit else 0.0)]
			var xl := minf(x0 + half + (5.0 * u if layer == 0 else 0.0), x1)
			_road.put(S_CAP + v, paint, Transform2D(0.0, Vector2(xl, y)))
			if x1 > xl:
				_road.put(S_BODY + v, paint, Transform2D(0.0, Vector2(x1 - xl, 1.0), 0.0, Vector2(xl, y)))
			_road.put(S_CAP + v, paint, Transform2D(0.0, Vector2(x1, y)))
		# beads along the ribbon, the drum's mark along the bar, riding with it
		var step := 0.24 if roll else 0.2
		var bt: float = ceil(maxf(t0, vt) / step) * step
		while bt < t1:
			var x := _x_of(bt - vt)
			if x > x0 + NOTE_R * u and x < size.x:
				_road.put(S_ROLL + kind if roll else S_BEAD, [], Transform2D(0.0, Vector2(x, y)))
			bt += step

## Under every berry in sight, its drum's mark in the drum's colour, on the
## strip under the road.
func _draw_marks(vt: float) -> void:
	var u := _u()
	var y := _path_top() + ROAD_MARK * u
	var ring_x := RING_X * u
	for i in range(_first, _st.notes.size()):
		var n: Dictionary = _st.notes[i]
		var dt := float(n.t) - vt
		if dt > _travel() + 0.05:
			break
		if n.hidden or (n.st != State.St.WAIT and not n.held):
			continue
		var x := _x_of(dt)
		if n.held or State.is_long(n.type):
			if vt > float(n.end):
				continue
			x = maxf(x, ring_x)
		elif dt < -0.3:
			continue
		var kind := _kind(int(n.lane))
		var twin := _rows.has(i)
		_road.put(S_MARK + kind * 2 + (1 if twin else 0), [], Transform2D(0.0, Vector2(x + float(_rows.get(i, 0.0)) * 40.0 * u, y)))

## The fireworks over the stage. A rocket's climb trailing sparks is made
## on the frame, into the sky's builder (two little shapes a rocket).
func _draw_rockets(b: Face.Builder, now: float) -> void:
	var u := _u()
	for fw: Dictionary in _fireworks:
		var t := now - float(fw.at)
		if t < 0.0 or t >= ROCKET_TIME:
			continue
		var pos: Vector2 = fw.pos
		var col: Color = FIREWORK_COLS[int(fw.ci)]
		var k := t / ROCKET_TIME
		var from := Vector2(pos.x, _path_top())
		var head := from.lerp(pos, 1.0 - pow(1.0 - k, 2.0))
		var tail := from.lerp(pos, maxf(0.0, 1.0 - pow(1.0 - maxf(0.0, k - 0.3), 2.0)))
		b.stroke(PackedVector2Array([tail, head]), 4.0 * u, Color(col.lightened(0.4), 0.7))
		b.disc(head, 5.0 * u, Color(1, 1, 0.9))

## Then the burst -- a flash, a ring of trails falling slowly and fading:
## every burst in the sky is one look a step of its life (`_fw_shape`),
## copied under how far it has opened and fallen. All of them are one mesh
## with what `sky` holds (Go-Go's warmth, the rockets) after them.
func _draw_fireworks(sky: Face.Builder, now: float) -> void:
	var u := _u()
	var v := PackedVector2Array()
	var c := PackedColorArray()
	var n := 0
	for fw: Dictionary in _fireworks:
		var k := (now - float(fw.at) - ROCKET_TIME) / BURST_LIFE
		if k < 0.0 or k >= 1.0:
			continue
		var step := mini(int(k * FW_STEPS), FW_STEPS - 1)
		var s := float(fw.r) * (1.0 - pow(1.0 - k, 3.0)) / (FW_R * u)
		v.append_array(Transform2D(float(fw.turn), Vector2(s, s), 0.0, (fw.pos as Vector2) + Vector2(0, 46.0 * u * k * k)) * (_fw.shape(step)[0] as PackedVector2Array))
		c.append_array(_fw_colours(int(fw.ci), step))
		n += 1
	_fireworks = _fireworks.filter(func(fw: Dictionary) -> bool: return now - float(fw.at) < ROCKET_TIME + BURST_LIFE)
	if n == 0:
		_put(sky)
		return
	var idx := _fw_indices(n)
	if not sky.verts.is_empty():
		var base := v.size()
		var ix := sky.idx.duplicate()
		for i in ix.size():
			ix[i] += base
		v.append_array(sky.verts)
		c.append_array(sky.cols)
		idx.append_array(ix)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_put_mesh(m)

## The crowd either side of the path: each critter bobs on the beat, jumps
## with its paws up on a cheer, waves glow sticks through Go-Go and the
## finale, frets after a broken combo. Newcomers pop in.
func _draw_crowd(now: float, beats: float, gogo: bool, tier: int) -> void:
	var u := _u()
	var calm := Motion.reduce
	var party := _phase == "won" and now < _party_until
	var cheer := now - _cheer_at
	for pass_ in 2:
		for i in _crowd_n:
			var at := _seat(i)
			var back := at.y < _path_top() - 1.0
			if back != (pass_ == 0):
				continue
			var s := (25.0 if back else 30.0) * u
			var kind := (i * 3 + 1) % Parts.CRITTERS.size()
			var ph := i * 0.7
			var amp: float = [3.0, 6.0, 9.0, 12.0][tier] if _phase == "play" else 2.0
			if gogo:
				amp = 13.0
			var y := 0.0
			var up := gogo or party
			var mood := Parts.Mood.HAPPY
			if not calm:
				if _phase == "play" or party:
					y = absf(sin(beats * PI + ph)) * amp * u
				else:
					y = absf(sin(now * 2.0 + ph)) * 2.0 * u
				var ck := (cheer - i * 0.04) / CHEER_TIME
				if ck > 0.0 and ck < 1.0:
					y += sin(ck * PI) * 42.0 * u
					up = true
				if party:
					y += absf(sin(now * 5.0 + ph)) * 24.0 * u
			if up:
				mood = Parts.Mood.JOY
			elif now < _worry_until:
				mood = Parts.Mood.WORRIED
			elif _phase == "missed" or _phase == "out":
				mood = Parts.Mood.SAD
			var stick: Color = STICK_COLS[i % STICK_COLS.size()] if (gogo or party) else Color(0, 0, 0, 0)
			var sway := 0.0 if calm else sin(beats * PI * 0.5 + ph) * (0.14 if up else 0.04)
			var sc := 1.0
			var since := now - float(_joined[i])
			if since < 0.4 and not calm:
				sc = Motion.back_out(clampf(since / 0.4, 0.0, 1.0))
			draw_mesh(Parts.critter(kind, s, mood, up, stick), null, Transform2D(sway, Vector2(sc, sc), 0.0, at + Vector2(0, -y)))

## The conga: a line of critters dancing across the stage, kicking out on
## every other beat.
func _draw_conga(now: float, beats: float) -> void:
	var k := (now - _conga_at) / CONGA_TIME
	if k < 0.0 or k >= 1.0 or Motion.reduce:
		return
	var u := _u()
	var span := size.x + 520.0 * u
	for i in CONGA_N:
		var x := -260.0 * u + span * k - i * 72.0 * u
		if x < -60.0 * u or x > size.x + 60.0 * u:
			continue
		var hop := absf(sin(beats * PI + i * 0.5)) * 16.0 * u
		var kick := sin(beats * PI * 0.5 + i) * 0.22
		var at := Vector2(x, _band_h() + _stage_h() * 0.66 - hop)
		draw_mesh(Parts.critter((i * 2 + 3) % Parts.CRITTERS.size(), 22.0 * u, Parts.Mood.JOY, i % 2 == 0, STICK_COLS[i % STICK_COLS.size()]), null, Transform2D(kick, at))

## Echo's hidden bars under a lilac veil riding the road, moonlight
## twinkling in it: a shape a bar's length (the first bar's; another length
## is that one stretched), put where the bar is.
func _draw_veils(vt: float, now: float) -> void:
	for e: Array in _st.echo:
		var x0 := _x_of(float(e[0]) - vt)
		var x1 := _x_of(float(e[1]) - vt)
		if x1 < 1.0 or x0 > size.x - 1.0:
			continue
		if _veil_w <= 0.0:
			_veil_w = x1 - x0
		var xf := Transform2D(0.0, Vector2((x1 - x0) / _veil_w, 1.0), 0.0, Vector2(x0, 0.0))
		_road.put(S_VEIL, [], xf)
		var moon := Color("f4efff")
		for g in 3:
			var tw := _q(0.35 + 0.4 * (0.5 + 0.5 * (1.0 if Motion.reduce else sin(now * 3.0 + g * 2.1))))
			_road.put(S_VEIL_STARS + g, [Color(moon.darkened(0.35), tw), Color(moon, tw), Color(1, 1, 1, 0.5 * tw)], xf)

## Draws what a builder holds, keeping the mesh until the next frame's
## replaces it; an empty builder draws nothing.
func _put(b: Face.Builder) -> void:
	if b.verts.is_empty():
		return
	var m := b.mesh()
	_shown.append(m)
	draw_mesh(m, null)

func _frog_foot() -> Vector2:
	var u := _u()
	return Vector2(size.x - 120.0 * u, _band_h() + _stage_h() * 0.78)

func _frog_head() -> Vector2:
	var s := 52.0 * _u()
	return _frog_foot() + Vector2(0, -s * 1.62)

## Tam the frog, the bandleader, on the stage's right: bobbing on the beat,
## his sticks up and down with the player's strokes, his sunglasses on for a
## run past a hundred, asleep when the hearts run out.
func _draw_frog(now: float, beats: float, gogo: bool) -> void:
	var u := _u()
	var s := 52.0 * u
	var foot := _frog_foot()
	var calm := Motion.reduce
	var bob := 0.0 if calm else absf(sin(beats * PI)) * (14.0 if gogo else 6.0) * u
	if _phase != "play" and not calm:
		bob = absf(sin(now * 2.2)) * 5.0 * u
	var mood := _mood if now < _mood_until else Parts.Mood.HAPPY
	if _phase == "out":
		mood = Parts.Mood.SAD
		bob = 0.0
	var blink := (not calm and fmod(now, 3.7) < 0.12) or _phase == "out"
	if not calm and _phase != "out":
		var ck := (now - _cheer_at) / CHEER_TIME
		if ck > 0.0 and ck < 1.0:
			bob += sin(ck * PI) * 36.0 * u
		if _phase == "won" and now < _party_until:
			bob += absf(sin(now * 4.4)) * 28.0 * u
	var at := foot + Vector2(0, -bob)
	draw_mesh(Parts.frog(s, mood, blink and mood != Parts.Mood.JOY), null, Transform2D(0.0, at))
	for side in 2:
		var dir := -1.0 if side == 0 else 1.0
		var since := now - float(_arm_at[side])
		var swing := 0.0
		if since < 0.2 and not calm:
			swing = sin(since / 0.2 * PI)
		var lift := 0.5 + (0.0 if calm else sin(beats * PI + side * PI) * 0.1)
		var ang := -dir * lerpf(2.3, 0.4, swing) * lift * 1.6
		var shoulder := at + Vector2(dir * s * 0.66, -s * 1.05)
		draw_mesh(Parts.frog_arm(s), null, Transform2D(ang, shoulder))
	# the sunglasses, dropped on once and kept for the song
	if now >= _shades_at and _phase in ["play", "won"]:
		var k := 1.0 if calm else clampf((now - _shades_at) / SHADES_DROP, 0.0, 1.0)
		var drop := (1.0 - Motion.back_out(k)) * -120.0 * u
		var eyes := at + Vector2(0, -s * 1.62 - s * 0.58 + drop)
		draw_mesh(Parts.shades(s), null, Transform2D(0.0, eyes))
	if _phase == "out" and not calm:
		# z's off the sleeping bandleader
		for k in 3:
			var ph := fposmod(now * 0.6 + k / 3.0, 1.0)
			var p := at + Vector2(s * (0.9 + ph * 0.8), -s * (2.3 + ph * 1.6))
			_label(p, "z", int((22.0 + 14.0 * ph) * u), Color(Parts.CREAM, 1.0 - ph), Color(Parts.INK, 0.5 * (1.0 - ph)))

## The berries riding the road, the earliest drawn last; Echo's hidden ones
## not at all; a note let past goes on past the ring, sinking and frowning.
func _draw_notes(vt: float, _now_t: float) -> void:
	var u := _u()
	var notes: Array = _st.notes
	var ring_x := RING_X * u
	var r := NOTE_R * u
	var hi := notes.size() - 1
	# the last note in sight
	for i in range(_first, notes.size()):
		if float(notes[i].t) - vt > _travel() + 0.05:
			hi = i - 1
			break
	for i in range(hi, _first - 1, -1):
		var n: Dictionary = notes[i]
		var type := int(n.type)
		var dt := float(n.t) - vt
		var kind := _kind(int(n.lane))
		if type == State.Type.BALLOON or n.hidden:
			continue
		if type == State.Type.ROLL:
			# a drumroll's head is its drum's berry, waiting in the ring
			if n.st == State.St.WAIT and vt <= float(n.end):
				draw_mesh(Parts.berry(kind, r, Parts.Mood.JOY if dt <= 0.0 else Parts.Mood.HAPPY), null, Transform2D(0.0, Vector2(maxf(_x_of(dt), ring_x), _note_y())))
			continue
		if n.st == State.St.HIT and not n.held:
			continue
		var y := _row_y(i)
		var x := ring_x if n.held else _x_of(dt)
		if n.st == State.St.MISSED:
			# let past: on past the ring, sinking, fading
			if dt > 0.0:
				continue
			var k := clampf(-dt / FALL_TIME, 0.0, 1.0)
			if k >= 1.0 or Motion.reduce and dt < -0.2:
				continue
			draw_mesh(Parts.berry(kind, r, Parts.Mood.SAD), null, Transform2D(-k * 1.2, Vector2(x, y + k * k * 70.0 * u)), Color(1, 1, 1, 1.0 - k))
			continue
		if dt < -0.3 and not n.held:
			continue
		var mood := Parts.Mood.JOY if dt < 0.25 and not Motion.reduce else Parts.Mood.HAPPY
		var hop := 0.0
		if not Motion.reduce and not n.held:
			hop = absf(sin(dt * TAU)) * 4.0 * u
		var m := Parts.golden_berry(r) if _golden.has(i) else Parts.berry(kind, r, mood)
		draw_mesh(m, null, Transform2D(0.0, Vector2(x, y - hop)))


## The balloons: along the road to the ring, then sitting in it swelling
## with every tap, or flying off when let go.
func _draw_balloons(vt: float, now: float) -> void:
	var u := _u()
	var notes: Array = _st.notes
	for i in range(_first, notes.size()):
		var n: Dictionary = notes[i]
		var dt := float(n.t) - vt
		if dt > _travel() + 0.05:
			break
		if int(n.type) != State.Type.BALLOON:
			continue
		if n.st == State.St.HIT or n.hidden:
			continue
		var gone: float = now - float(_balloon_gone.get(i, INF))
		if float(n.end) < vt - 1.2:
			continue
		var p := Vector2(maxf(_x_of(dt), RING_X * u), _note_y() - 10.0 * u)
		var fill := float(n.hits) / maxf(1.0, float(n.count))
		if gone >= 0.0:
			if gone > 1.0:
				continue
			p += Vector2(gone * 120.0, -gone * 420.0) * u
		draw_mesh(Parts.balloon(NOTE_R * u, fill), null, Transform2D(0.0, p))
		if dt <= 0.0 and gone < 0.0:
			_label(p + Vector2(NOTE_R * 1.0, -NOTE_R * 1.1) * u, str(maxi(0, int(n.count) - int(n.hits))), int(44 * u), Color.WHITE, Parts.INK)

func _draw_path_combo(now: float, tier: int) -> void:
	var u := _u()
	var kick := 0.0 if Motion.reduce else 1.0 - clampf((now - _combo_at) / KICK_TIME, 0.0, 1.0)
	var sc := 1.0 + 0.14 * kick
	var fs := int(COMBO_FONT * u)
	var text := str(_st.combo)
	var font: Font = CozyTheme.display(700)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base: Color = [Color("d6bf98"), Parts.ROLL, Color("ffb08a")][mini(tier, 2)]
	var mid := Vector2(size.x * 0.5, _path_top() + (ROAD + 84.0) * u)
	draw_set_transform(mid, 0.0, Vector2(sc, sc))
	var x := -w * 0.5
	for i in text.length():
		var ch := text[i]
		var adv := font.get_char_size(ch.unicode_at(0), fs).x
		var col := base
		if tier >= 3:
			col = Rewards.STICKER_COLS[(i + int(now * 6.0)) % Rewards.STICKER_COLS.size()]
		var o := Vector2(x, fs * 0.36)
		draw_char_outline(font, o, ch, fs, int(fs * 0.12), Color(Parts.INK, 0.5))
		draw_char(font, o, ch, fs, Color(col, 0.95))
		x += adv
	draw_set_transform(Vector2.ZERO)
	_label(mid + Vector2(0, fs * 0.66), tr("DB_COMBO"), int(30 * u), Color(Parts.INK, 0.5), Color(0, 0, 0, 0))

## The soul gauge, into the top's mesh. Its bed is in the still picture;
## its fill is a shape a width (made when the gauge moves), its ticks, line,
## star and heart shapes; only a full gauge's rainbow is made on the frame.
func _draw_gauge(now: float, pulse: float) -> void:
	var u := _u()
	var r := _gauge_rect()
	var calm := Motion.reduce
	var k := _st.gauge / State.GAUGE_MAX
	var full := _st.gauge >= State.GAUGE_MAX
	var cleared := _st.cleared()
	if k > 0.01:
		var w := maxf(r.size.y, r.size.x * k)
		_top.put(S_FILL + roundi(w * 2.0) * 2 + (1 if cleared else 0), [], Transform2D.IDENTITY)
		if full and not calm:
			# the rainbow running along a full gauge: plain quads
			var bb := Face.Builder.new()
			var bands := 12
			var y0 := r.position.y + 3.0 * u
			var y1 := r.end.y - 3.0 * u
			for i in bands:
				var x0 := r.position.x + r.size.y * 0.4 + (r.size.x - r.size.y * 0.8) * i / bands
				var x1 := r.position.x + r.size.y * 0.4 + (r.size.x - r.size.y * 0.8) * (i + 1) / bands
				var c := Color.from_hsv(fposmod(i / float(bands) - now * 0.6, 1.0), 0.45, 1.0, 0.55)
				var i0 := bb.vertex(Vector2(x0, y0), c)
				var i1 := bb.vertex(Vector2(x1, y0), c)
				var i2 := bb.vertex(Vector2(x1, y1), c)
				var i3 := bb.vertex(Vector2(x0, y1), c)
				bb.tri(i0, i1, i2)
				bb.tri(i0, i2, i3)
			_top.put_builder(bb)
		if not calm and _phase == "play":
			var gr := r.size.y * (0.7 + 0.5 * pulse) / 100.0
			_top.put(S_GLINT, [], Transform2D(now * 3.0, Vector2(gr, gr), 0.0, Vector2(r.position.x + w - r.size.y * 0.35, r.get_center().y)))
	_top.put(S_GAUGE_OVER, [], Transform2D.IDENTITY)
	var pop := 1.0 + (0.0 if calm else 0.4 * (1.0 - clampf((now - _soul_at) / 0.5, 0.0, 1.0)))
	_top.put(S_STAR + (1 if cleared else 0), [],
		Transform2D(0.0 if calm or not cleared else now * 1.5, Vector2(pop, pop), 0.0, _gauge_line() + Vector2(0, -r.size.y * 1.05)))
	var hs := (1.0 + (0.25 * pulse if full else 0.0)) * pop
	_top.put(S_GAUGE_HEART + (1 if cleared else 0), [], Transform2D(0.0, Vector2(hs, hs), 0.0, Vector2(r.end.x + 4.0 * u, r.get_center().y)))

## The hearts in the band on Hard and Insane: a lost one cracks and falls, a
## heart given back pops in, and the last one beats while it is all there is.
func _draw_hearts(now: float) -> void:
	if _st.max_hearts <= 0:
		return
	var u := _u()
	var calm := Motion.reduce
	for i in _st.max_hearts:
		var at := _heart_at(i)
		if i < _st.hearts:
			var sc := 1.0
			if _st.hearts == 1 and not calm and _phase == "play":
				sc *= 1.0 + 0.12 * absf(sin(now * 6.0))
			if i == 0 and now - _back_at < 0.3 and not calm:
				sc *= Motion.pop_in_scale(now - _back_at, 0.3).x
			_top.put(S_HEART, [], Transform2D(0.0, Vector2(sc, sc), 0.0, at))
			continue
		_top.put(S_HEART_EMPTY, [], Transform2D(0.0, at))
		var k := (now - _split_at) / SPLIT_TIME
		if i == _split_index and k < 1.0 and not calm:
			# the halves of a heart just broken, falling: made on the frame
			var b := Face.Builder.new()
			var r := 17.0 * u
			var fade := 1.0 - k * k
			for side in [-1.0, 1.0]:
				var p: Vector2 = at + Vector2(side * 14.0 * k, 50.0 * k * k) * u
				Rewards.heart(b, p, r * 0.8, side * 0.6 * k, Color(HEART_DEEP if side > 0 else HEART, fade))
			_top.put_builder(b)

## The seal over the road: Flawless for a full combo; on Insane the night
## seal, "Insane" over Flawless or Echo.
func _draw_stamp(now: float) -> void:
	var rad := size.x * STAMP_R
	var insane := _level == 3
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	_shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var uu := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, uu * uu) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := Vector2(size.x * 0.5, _path_top() + ROAD * 0.5 * _u())
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	draw_set_transform_matrix(xf)
	draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02], [tr("BN_FLAWLESS") if _st.full_combo() else tr("DB_ECHO_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(self, rad, lines)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_words(now: float) -> void:
	var u := _u()
	if _band_h() > 0.0:
		_label_left(Vector2(30.0 * u, _band_h() * 0.36), tr("DB_SCORE"), int(KICKER_FONT * u), Color(Parts.INK, 0.7), Color(0, 0, 0, 0))
		var kick := 0.0 if Motion.reduce else 1.0 - clampf((now - _score_at) / KICK_TIME, 0.0, 1.0)
		var sk := 1.0 + 0.12 * kick
		draw_set_transform(Vector2(30.0 * u, _band_h() * 0.8), 0.0, Vector2(sk, sk))
		_label_left(Vector2.ZERO, Locale.number(int(_score_shown)), int(SCORE_FONT * u), Parts.INK.lerp(Parts.DON_DEEP, kick * 0.6), Color(0, 0, 0, 0))
		draw_set_transform(Vector2.ZERO)
		var gr := _gauge_rect()
		_label_left(Vector2(gr.position.x, gr.position.y - 12.0 * u), tr("DB_SOUL"), int(KICKER_FONT * u), Color(Parts.INK, 0.7), Color(0, 0, 0, 0))
	if _staged():
		var level_name: String = tr(["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD", "DIFF_INSANE"][clampi(_level, 0, 3)])
		var title := "%s · %s" % [String(_song.get("title", "")), level_name]
		if _level == 3:
			title += " · " + tr("DB_ECHO")
		_label(Vector2(size.x * 0.5, _band_h() + 30.0 * u), title, int(26 * u), Parts.CREAM, Color(Parts.INK, 0.5))
	# the latest judgement, stamped over the ring and rising
	if not _judge.is_empty() and now - float(_judge.at) < JUDGE_TIME:
		var k := (now - float(_judge.at)) / JUDGE_TIME
		var rise := 0.0 if Motion.reduce else (1.0 - pow(1.0 - k, 3.0)) * 24.0 * u
		var a := 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
		var col: Color = JUDGE_COLS[int(_judge.grade)]
		var pop := 1.0 if Motion.reduce else Motion.back_out(clampf(k / 0.35, 0.0, 1.0))
		var fs := JUDGE_FONT + (6 if int(_judge.grade) == State.Grade.GOOD else 0)
		draw_set_transform(Vector2((RING_X + 14.0) * u, _path_top() - 30.0 * u - rise), 0.0, Vector2(pop, pop))
		_label(Vector2.ZERO, tr(JUDGE_KEYS[int(_judge.grade)]), int(fs * u), Color(col, a), Color(Parts.INK, 0.85 * a))
		draw_set_transform(Vector2.ZERO)
	if not _roll_pop.is_empty() and now - float(_roll_pop.at) < 0.5:
		_label(Vector2((RING_X + 190.0) * u, _path_top() - 30.0 * u), str(int(_roll_pop.n)), int(44 * u), Parts.ROLL, Parts.INK)
	if not _staged():
		return
	match _phase:
		"ready":
			_draw_card(tr("DB_TAP_START"), "", now)
		"tune":
			_draw_tune(now)
		"missed":
			var head := "DB_SO_CLOSE" if _st.gauge >= State.CLEAR * 0.6 else "DB_KEEP_GOING"
			var line := tr("DB_MISSED_LINE") % int(roundf(_st.gauge))
			if _st.max_hearts > 0:
				line = (tr("DB_MISSED_HEART_ONE") if _st.hearts == 1 else tr("DB_MISSED_HEARTS") % _st.hearts)
			_draw_card(tr(head), line, now)
		"paused":
			_draw_card(tr("DB_PAUSED"), tr("DB_RESUME"), now, false)

## The start card, the retry card and the pause, written over the stage and
## the path: a head, a line, the legend (only before a song) and the timing.
func _draw_card(head: String, line: String, now: float, buttons := true) -> void:
	var u := _u()
	var r := _card_rect()
	var b := Face.Builder.new()
	b.polygon(Face.Builder.round_rect(r.position + Vector2(0, 8.0 * u), r.size, 36.0 * u), Color(Parts.INK, 0.2))
	b.polygon(Face.Builder.round_rect(r.position, r.size, 36.0 * u), Color(Pal.PAPER, 0.97))
	if buttons:
		var rects := _card_rects()
		for k in rects.size():
			var rr: Rect2 = rects[k]
			var glow := k == 1 and _needs_tune() and not Motion.reduce
			var col := Color("f6d98a") if glow else Color("efe3cc")
			b.polygon(Face.Builder.round_rect(rr.position, rr.size, 22.0 * u), col)
	_put(b)
	var c := r.get_center()
	var y := r.position.y + 70.0 * u
	if _phase == "ready":
		_label(Vector2(c.x, y), String(_song.get("title", "")), int(TITLE_FONT * u), Parts.INK, Color(0, 0, 0, 0))
		y += 58.0 * u
		var lv: Array = ["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD", "DIFF_INSANE"]
		var sub := "%s · %d BPM" % [tr(lv[clampi(_level, 0, 3)]), int(_song.get("bpm", 0))]
		if _st.max_hearts > 0:
			sub += " · " + (tr("DB_HEARTS_ONE") if _st.hearts == 1 else tr("DB_HEARTS_N") % _st.hearts)
		_label(Vector2(c.x, y), sub, int(28 * u), Color(Parts.INK, 0.65), Color(0, 0, 0, 0))
		# the legend: the drums' berries, then a ribbon and a roll
		y += 80.0 * u
		for lane in _n():
			var x := c.x + (lane - (_n() - 1) * 0.5) * 110.0 * u
			draw_mesh(Parts.berry(_kind(lane), 30.0 * u), null, Transform2D(0.0, Vector2(x, y)))
		_label(Vector2(c.x, y + 62.0 * u), tr("DB_LEGEND_ONE" if _n() == 1 else "DB_LEGEND_DRUMS"), int(26 * u), Parts.INK, Color(0, 0, 0, 0))
		y += 112.0 * u
		var line2 := tr("DB_LEGEND_HOLD") + "   ·   " + tr("DB_LEGEND_ROLL")
		if _level == 3:
			line2 = tr("DB_LEGEND_ECHO")
		_label(Vector2(c.x, y), line2, int(26 * u), Color(Parts.INK, 0.8), Color(0, 0, 0, 0))
		y += 78.0 * u
		var pulse := 1.0 if Motion.reduce else 0.75 + 0.25 * sin(now * 4.0)
		var go_line := tr("DB_TUNE_FIRST") if _needs_tune() else head
		_label(Vector2(c.x, y), go_line, int(38 * u), Color(Parts.DON_DEEP, pulse), Color(0, 0, 0, 0))
	else:
		_label(Vector2(c.x, y + 30.0 * u), head, int(TITLE_FONT * u), Parts.INK, Color(0, 0, 0, 0))
		if line != "":
			_label(Vector2(c.x, y + 100.0 * u), line, int(LINE_FONT * u), Color(Parts.INK, 0.75), Color(0, 0, 0, 0))
		if _phase == "missed":
			_label(Vector2(c.x, y + 160.0 * u), tr("DB_STATS") % [_st.goods, _st.oks, _st.bads, _st.max_combo], int(28 * u), Color(Parts.INK, 0.65), Color(0, 0, 0, 0))
			var pulse2 := 1.0 if Motion.reduce else 0.75 + 0.25 * sin(now * 4.0)
			_label(Vector2(c.x, y + 250.0 * u), tr("DB_TAP_AGAIN"), int(38 * u), Color(Parts.DON_DEEP, pulse2), Color(0, 0, 0, 0))
	if buttons:
		var rects := _card_rects()
		_label((rects[0] as Rect2).get_center() + Vector2(0, 14.0 * u), "−", int(44 * u), Parts.INK, Color(0, 0, 0, 0))
		_label((rects[2] as Rect2).get_center() + Vector2(0, 14.0 * u), "+", int(44 * u), Parts.INK, Color(0, 0, 0, 0))
		var ms := int(roundf(_offset * 1000.0))
		_label((rects[1] as Rect2).get_center() + Vector2(0, 10.0 * u), tr("DB_TUNE_BUTTON") % ("%+d" % ms), int(27 * u), Parts.INK, Color(0, 0, 0, 0))

## The tap-along's card: a wooden block that hops on each knock, and a dot a
## tap on a ruler from early to late.
func _draw_tune(now: float) -> void:
	var u := _u()
	var r := _card_rect()
	var b := Face.Builder.new()
	b.polygon(Face.Builder.round_rect(r.position + Vector2(0, 8.0 * u), r.size, 36.0 * u), Color(Parts.INK, 0.2))
	b.polygon(Face.Builder.round_rect(r.position, r.size, 36.0 * u), Color(Pal.PAPER, 0.97))
	var c := r.get_center()
	var clicks := _tune_clicks()
	var t := song_now()
	var since := 10.0
	var count := 0
	for k in clicks.size():
		if t >= float(clicks[k]):
			since = t - float(clicks[k])
			count = k + 1
	var hop := 0.0 if Motion.reduce else maxf(0.0, 1.0 - since / 0.25) * 30.0 * u
	var blk := Vector2(c.x, r.position.y + 290.0 * u - hop)
	b.polygon(Face.Builder.round_rect(blk + Vector2(-90.0, -46.0) * u, Vector2(180.0, 92.0) * u, 18.0 * u), Color("b36a32"))
	b.polygon(Face.Builder.round_rect(blk + Vector2(-84.0, -50.0) * u, Vector2(168.0, 84.0) * u, 16.0 * u), Color("d9894a"))
	b.polygon(Face.Builder.round_rect(blk + Vector2(-60.0, -12.0) * u, Vector2(120.0, 12.0) * u, 6.0 * u), Color(Parts.INK, 0.5))
	if since < 0.2 and not Motion.reduce:
		b.stroke(_ellipse_pts(blk, 110.0 * u * (1.0 + since * 2.0), 60.0 * u * (1.0 + since * 2.0)), 5.0 * u, Color(GOLD, 1.0 - since / 0.2), true)
	# the ruler: early to the left, late to the right, a dot a tap
	var ry := r.position.y + 420.0 * u
	var half := 300.0 * u
	b.stroke(PackedVector2Array([Vector2(c.x - half, ry), Vector2(c.x + half, ry)]), 6.0 * u, Color(Parts.INK, 0.25))
	b.stroke(PackedVector2Array([Vector2(c.x, ry - 18.0 * u), Vector2(c.x, ry + 18.0 * u)]), 4.0 * u, Color(Parts.INK, 0.5))
	for tap: float in _tune_taps:
		var best := INF
		for ck in clicks:
			if absf(tap - float(ck)) < absf(best):
				best = tap - float(ck)
		var x := c.x + clampf(best / 0.3, -1.0, 1.0) * half
		b.disc(Vector2(x, ry), 10.0 * u, Color(Parts.LANE_BODY[2], 0.9))
	_put(b)
	_label(Vector2(c.x, r.position.y + 80.0 * u), tr("DB_TUNE_HEAD"), int(48 * u), Parts.INK, Color(0, 0, 0, 0))
	_label(Vector2(c.x, r.position.y + 140.0 * u), tr("DB_TUNE_LINE"), int(28 * u), Color(Parts.INK, 0.7), Color(0, 0, 0, 0))
	_label(Vector2(c.x, r.position.y + 370.0 * u), "%d / %d" % [count, clicks.size()], int(30 * u), Color(Parts.INK, 0.6), Color(0, 0, 0, 0))
	_label(Vector2(c.x - half, ry + 50.0 * u), tr("DB_EARLY"), int(24 * u), Color(Parts.INK, 0.55), Color(0, 0, 0, 0))
	_label(Vector2(c.x + half, ry + 50.0 * u), tr("DB_LATE"), int(24 * u), Color(Parts.INK, 0.55), Color(0, 0, 0, 0))

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
## stalls and the lanterns' cord, the road of planks across the card and the
## festival mat the drums stand on.
func _build_still() -> ArrayMesh:
	var u := _u()
	var b := Face.Builder.new()
	b.polygon(Face.Builder.round_rect(Vector2.ZERO, size, CARD_RADIUS * u), Pal.PAPER)
	var top := _band_h()
	var low := _path_top()
	var w := size.x
	if top > 0.0:
		# the soul gauge's bed
		var gr := _gauge_rect()
		b.polygon(Face.Builder.round_rect(gr.position - Vector2(4, 4) * u, gr.size + Vector2(8, 8) * u, (gr.size.y * 0.5 + 4.0 * u)), Color(Parts.INK, 0.55))
		b.polygon(Face.Builder.round_rect(gr.position, gr.size, gr.size.y * 0.5), GAUGE_BACK)
	if _staged():
		_build_stage(b)
	# the ground: a festival mat under everything below the stage
	b.polygon(PackedVector2Array([Vector2(0, low), Vector2(w, low), Vector2(w, size.y - CARD_RADIUS * u), Vector2(0, size.y - CARD_RADIUS * u)]), Color("e8dcc4"))
	b.polygon(Face.Builder.round_rect(Vector2(0, size.y - CARD_RADIUS * u * 2.0), Vector2(w, CARD_RADIUS * u * 2.0), CARD_RADIUS * u), Color("e8dcc4"))
	# the road of planks across the card: a rail over it and one under, and
	# the strip under the lower rail where each berry's mark rides
	var plank := low + ROAD_RAIL * u
	var floor_y := low + ROAD_FLOOR * u
	b.polygon(_rect(0, low, w, low + ROAD * u), PATH_DEEP)
	b.polygon(_rect(0, plank, w, floor_y), PATH_TRACK)
	var board := 96.0 * u
	var k := 0
	while k * board < w:
		if k % 2 == 0:
			b.polygon(_rect(k * board, plank, minf(w, (k + 1) * board), floor_y), Color(PATH_WOOD, 0.3))
		k += 1
	b.polygon(_rect(0, low, w, plank), PATH_WOOD)
	b.polygon(_rect(0, low, w, low + 5.0 * u), PATH_WOOD.lightened(0.25))
	b.polygon(_rect(0, floor_y, w, floor_y + 10.0 * u), PATH_WOOD)
	# a faint seam between the drums' columns
	for lane in range(1, _n()):
		var x := w * lane / float(_n())
		b.stroke(PackedVector2Array([Vector2(x, low + (ROAD + 50.0) * u), Vector2(x, size.y - 70.0 * u)]), 3.0 * u, Color(Parts.INK, 0.07))
	return b.mesh()

## The dusk stage, into the still picture: the sky and its stars, the moon,
## the hills, the stalls and the lanterns' cord.
func _build_stage(b: Face.Builder) -> void:
	var u := _u()
	var w := size.x
	var top := _band_h()
	var low := _path_top()
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
	b.disc(Vector2(w * 0.2, top + 70.0 * u), 28.0 * u, Color("fff1c8"))
	b.disc(Vector2(w * 0.2 + 12.0 * u, top + 62.0 * u), 24.0 * u, Color(SKY_TOP.lerp(SKY_LOW, 0.2), 1.0))
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
	for sx: float in [0.3, 0.6]:
		var base := Vector2(w * sx, low - 60.0 * u)
		var sw := 130.0 * u
		b.polygon(Face.Builder.round_rect(base + Vector2(-sw * 0.5, -76.0 * u), Vector2(sw, 76.0 * u), 6.0 * u), STALL)
		b.polygon(Face.Builder.round_rect(base + Vector2(-sw * 0.44, -56.0 * u), Vector2(sw * 0.88, 36.0 * u), 6.0 * u), Color("f3c98f", 0.85))
		for s in 5:
			var x0 := base.x - sw * 0.6 + s * sw * 1.2 / 5.0
			b.polygon(PackedVector2Array([Vector2(x0, base.y - 76.0 * u), Vector2(x0 + sw * 0.24, base.y - 76.0 * u),
				Vector2(x0 + sw * 0.24, base.y - 94.0 * u), Vector2(x0, base.y - 94.0 * u)]), STALL_ROOF if s % 2 == 0 else Parts.CREAM)
		for s in 5:
			var cx := base.x - sw * 0.6 + (s + 0.5) * sw * 1.2 / 5.0
			b.disc(Vector2(cx, base.y - 76.0 * u), sw * 0.12, STALL_ROOF if s % 2 == 0 else Parts.CREAM)
	var cord := PackedVector2Array()
	for k in 25:
		var t := k / 24.0
		cord.append(Vector2(w * (0.02 + 0.96 * t), top + 30.0 * u + sin(PI * (t - 0.02) / 0.96) * 30.0 * u))
	b.stroke(cord, 3.0 * u, Color(Parts.INK, 0.7))
