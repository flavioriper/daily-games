extends Control

## One page of Drumbeat's tutorial: the road and the drums played by the
## board itself. The page holds a `Road` -- drumbeat2d.gd with its stage,
## music, voices, stickers, fireworks, cards and endings taken out, so what
## is left is the road of berries, the ring and the drums under it (and the
## band with the soul gauge on the page that teaches it) -- running a
## hand-made song of a few notes on a loop, and a finger a drum striking it
## through the board's own strokes. So the berries ride in, the drum the next
## one wants glows, a stroke is stamped GOOD, a ribbon is kept, a golden bar
## is rolled, a balloon swells and pops, the gauge fills past its line, a
## heart breaks on three misses, a hidden bar is played back, exactly as on
## the board. `lesson` picks the page (set before it enters the tree):
##
## - STRIKE: a berry rides to the ring; tap the drum as it gets there (one
##   drum, whatever the band).
## - DRUMS (Medium up): each berry's colour and mark name its drum; on Hard
##   and Insane two at once are struck together.
## - HOLD: a ribbon is pressed and kept to its end.
## - ROLL: a golden bar is drummed fast; a balloon wants its count of taps.
## - SOUL: good hits fill the gauge past the line; on Hard and Insane three
##   misses in a row break a heart.
## - ECHO (Insane): a bar played as seen, then again with its berries hidden.
## - HUD: the top bar's Reset and ?, and the start card's Tune, drawn as they
##   are (a song has no move to take back, so no Undo).
##
## The board checkup, 2026-10-03: Drumbeat had only the shared one-page card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const State = preload("res://puzzles/drumbeat_state.gd")

enum Lesson { STRIKE, DRUMS, HOLD, ROLL, SOUL, ECHO, HUD }

const CAPTION_H := 92.0
## How long before a song's zero a lesson starts, and after its end it waits.
const LEAD := 0.4
const REST := 1.1
## A tap's finger stays down this long; a roll's taps come this far apart.
const TAP_DOWN := 0.1
const ROLL_GAP := 0.11
const FINGER_ALPHA := 0.16
## What a GOOD is worth on the soul page, so the gauge passes its line on
## the fifth of five berries.
const SOUL_GAIN := 18.0

var lesson: int = Lesson.STRIKE
## The band the board behind the page is on.
var band := 0

var _art: Road
var _over: Control
var _caption: Label
var _begun := false
var _song := {}
var _level := 0
var _caps: Array = []      # [time, key], in order
var _skip := {}            # note index -> true: let past
var _still_at := 0.0
var _cap_next := 0
var _struck := {}
var _lifts: Array = []     # [time, lane]
var _down := {}            # lane -> true while its finger is down
var _seen := {}            # lane -> true once its finger has come
var _roll_at := -10.0
var _finger_shown: ArrayMesh
var _hud_shown: ArrayMesh

## The board, quiet: no stage over the road (`_staged`), no music or voices,
## no stickers or fireworks, no cards, no endings. The band with the gauge
## stands only when `band_shown`.
class Road extends "res://puzzles/drumbeat2d.gd":
	## Room over the road for a stroke's GOOD, the ground the drums stand
	## on and how far its foot is from theirs, in the board's units.
	const HEAD := 64.0
	const FLOOR := 264.0
	const FOOT := 44.0

	var band_shown := false

	## The rewards with no lettering: a page has no room for a sticker.
	class Quiet extends "res://arcade/rewards.gd":
		func sticker(_text: String, _where: Vector2, _fs: int, _life: float, _rainbow := true, _col := Color.WHITE, _rays := false, _id := "", _rise := 0.0, _keep := false) -> Dictionary:
			return {}

	func puzzle_id() -> String:
		return "drumbeat_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rw.queue_free()
		_rw = Quiet.new()
		_rw.z_index = 4
		add_child(_rw)
		_offset = 0.0
		_tuned = true

	## How tall the board is for its width's unit `u`.
	func height_for(u: float) -> float:
		return ((BAND if band_shown else 0.0) + HEAD + ROAD + FLOOR) * u

	func _staged() -> bool:
		return false

	func _band_h() -> float:
		return BAND * _u() if band_shown else 0.0

	func _path_top() -> float:
		return _band_h() + HEAD * _u()

	func _drum_foot(lane: int) -> Vector2:
		return Vector2(size.x * (lane + 0.5) / _n(), size.y - FOOT * _u())

	func _needs_tune() -> bool:
		return false

	## No music: the song's time runs off the clock alone.
	func _play_music(_file: String, _lead_file: String, from: float) -> void:
		_zero_us = Time.get_ticks_usec() - int(from * 1e6)
		_last_vt = -10.0

	func _stop_music() -> void:
		pass

	func _steer_clock() -> void:
		pass

	func _make_voices() -> void:
		pass

	func _play_voice(_lane: int) -> void:
		pass

	func _pause(_on: bool) -> void:
		pass

	func _unhandled_key_input(_event: InputEvent) -> void:
		pass

	func check_solved() -> void:
		pass

	func _song_over() -> void:
		pass

	func _run_out() -> void:
		pass

	func _gather() -> void:
		pass

	func _launch(_n_rockets: int, _delay: float) -> void:
		pass

	func _echo_cue(_vt: float) -> void:
		pass

	func _queue_warm() -> void:
		_warm = []

	## `song` at `level`, playing from `from` seconds on its clock.
	func lay(song: Dictionary, level: int, from: float) -> void:
		_song = song
		_level = level
		_kept_hearts = -1
		_fresh()
		_go_said = true
		_phase = "play"
		_play_music("", "", from)

	## The song held at `at`, for a page that stands still.
	func freeze(at: float) -> void:
		_phase = "still"
		_clock = at
		queue_redraw()

	## A finger on drum `lane` comes down, or up: the board's own stroke.
	func touch(lane: int, down: bool) -> void:
		if down:
			_held[lane] = lane
			strike(lane)
		elif _held.has(lane):
			_held.erase(lane)
			_lift(lane)

	## Where a finger rests on drum `lane`.
	func finger_at(lane: int) -> Vector2:
		return _drum_skin(lane) + Vector2(0, 26.0 * _u())

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if lesson != Lesson.HUD:
		_art = Road.new()
		_art.band_shown = lesson == Lesson.SOUL
		add_child(_art)
		_over = Control.new()
		_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_over.z_index = 6
		_over.draw.connect(_draw_fingers)
		add_child(_over)
	_caption = Label.new()
	_caption.theme_type_variation = "SheetBodyDim"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# One short line: a wrapping label measured before layout grows tall and
	# its centred text sinks under the buttons.
	_caption.clip_text = true
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	resized.connect(_layout)
	call_deferred("_layout")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again: the song's clock ran on
	# while it was away.
	if _begun:
		call_deferred("_reset")

func _layout() -> void:
	_caption.position = Vector2(20.0, size.y - CAPTION_H + 4.0)
	_caption.size = Vector2(size.x - 40.0, CAPTION_H - 8.0)
	if lesson == Lesson.HUD:
		_caption.visible = false
		queue_redraw()
		return
	var room := Vector2(size.x, maxf(0.0, size.y - CAPTION_H))
	if room.x <= 0.0 or room.y <= 0.0:
		return
	# as wide as the page while its height fits
	var u := minf(room.x / 1000.0, room.y / _art.height_for(1.0))
	_art.size = Vector2(1000.0 * u, _art.height_for(u))
	_art.position = ((room - _art.size) * 0.5).round()
	_over.position = Vector2.ZERO
	_over.size = size
	if not _begun and is_inside_tree():
		_begun = true
		_reset()

# --- the lessons ---

## A lesson's song, level, captions and the notes its fingers let past. A
## chart's rows are [time, drum, type, end, count, hidden], as
## tools/gen_drumbeat.py writes them.
func _plan() -> void:
	var T := State.Type
	var rows: Array = []
	var echo: Array = []
	_skip = {}
	_level = band
	match lesson:
		Lesson.STRIKE:
			_level = 0
			for t: float in [2.5, 3.0, 3.5, 4.5, 5.0]:
				rows.append([t, 0, T.TAP, 0.0, 0, 0])
			_caps = [[-9.0, "HTP_DB_RIDE_CAP"], [2.2, "HTP_DB_TAP_CAP"]]
			_still_at = 2.0
		Lesson.DRUMS:
			_level = maxi(band, 1)
			if _level == 1:
				for r: Array in [[2.5, 0], [3.0, 1], [3.5, 0], [4.0, 1], [4.5, 1], [5.0, 0]]:
					rows.append([r[0], r[1], T.TAP, 0.0, 0, 0])
				_caps = [[-9.0, "HTP_DB_COLOUR_CAP"], [3.2, "HTP_DB_GLOW_CAP"]]
			else:
				for r: Array in [[2.5, 0], [3.0, 1], [3.5, 2], [4.0, 1], [5.0, 0], [5.0, 2], [6.0, 1], [6.0, 2]]:
					rows.append([r[0], r[1], T.TAP, 0.0, 0, 0])
				_caps = [[-9.0, "HTP_DB_COLOUR_CAP"], [4.3, "HTP_DB_TWIN_CAP"]]
			_still_at = 2.2
		Lesson.HOLD:
			rows.append([2.5, 0, T.HOLD, 4.0, 0, 0])
			rows.append([4.75, 0, T.TAP, 0.0, 0, 0])
			rows.append([5.5, State.DRUMS[_level] - 1, T.HOLD, 6.5, 0, 0])
			_caps = [[-9.0, "HTP_DB_HOLD_CAP"], [3.4, "HTP_DB_LET_CAP"], [4.4, "HTP_DB_HOLD_CAP"], [6.1, "HTP_DB_LET_CAP"]]
			_still_at = 1.9
		Lesson.ROLL:
			rows.append([2.5, 0, T.ROLL, 4.5, 0, 0])
			rows.append([6.0, 0, T.BALLOON, 7.6, 6, 0])
			_caps = [[-9.0, "HTP_DB_ROLL_CAP"], [4.8, "HTP_DB_BALLOON_CAP"]]
			_still_at = 2.2
		Lesson.SOUL:
			for t: float in [2.5, 3.0, 3.5, 4.0, 4.5]:
				rows.append([t, 0, T.TAP, 0.0, 0, 0])
			_caps = [[-9.0, "HTP_DB_FILL_CAP"], [4.5, "HTP_DB_LINE_CAP"]]
			if State.HEARTS[_level] > 0:
				for t: float in [6.0, 6.5, 7.0]:
					_skip[rows.size()] = true
					rows.append([t, 0, T.TAP, 0.0, 0, 0])
				_caps.append([5.7, "HTP_DB_MISS_CAP"])
			_still_at = 2.0
		Lesson.ECHO:
			_level = 3
			var lanes := [0, 2, 1, 0]
			for k in 4:
				rows.append([2.5 + 0.5 * k, lanes[k], T.TAP, 0.0, 0, 0])
			for k in 4:
				rows.append([4.5 + 0.5 * k, lanes[k], T.TAP, 0.0, 0, 1])
			echo = [[4.25, 6.25]]
			_caps = [[-9.0, "HTP_DB_SEE_CAP"], [4.1, "HTP_DB_BLIND_CAP"]]
			_still_at = 3.4
	var last := 0.0
	for r: Array in rows:
		last = maxf(last, maxf(float(r[0]), float(r[3])))
	_song = {"id": "lesson", "title": "", "bpm": 120, "beat": 0.5, "bars": [0.25, 2.25, 4.25, 6.25, 8.25],
		"length": last + REST, "gogo": [], "echo": echo, "charts": [rows]}

## The lesson from its top: the song laid, no finger down.
func _reset() -> void:
	if lesson == Lesson.HUD or not is_inside_tree() or size.x <= 0.0:
		return
	_plan()
	_struck = {}
	_lifts = []
	_down = {}
	_seen = {}
	_roll_at = -10.0
	_cap_next = 0
	_art.lay(_song, _level, -LEAD)
	if lesson == Lesson.SOUL:
		_art._st._gain = SOUL_GAIN
	_say(String(_caps[0][1]))
	if Motion.reduce:
		# standing still: the berries on their way in, the gauge part full
		if lesson == Lesson.SOUL:
			_art._st.gauge = 54.0
		_art.freeze(_still_at)

func _process(_delta: float) -> void:
	if lesson == Lesson.HUD or not _begun or Motion.reduce:
		return
	var vt: float = _art.view_t()
	while _cap_next < _caps.size() and vt >= float(_caps[_cap_next][0]):
		_say(String(_caps[_cap_next][1]))
		_cap_next += 1
	_play(vt)
	_over.queue_redraw()
	# over before the song's own end, so a short song never judges itself
	if vt > float(_song.length) - 0.2:
		_reset()

## The fingers: every berry struck on its drum as it reaches the ring (a
## ribbon kept to its end, a golden bar and a balloon tapped over and over),
## but for the ones the lesson lets past.
func _play(vt: float) -> void:
	var notes: Array = _art._st.notes
	for i in notes.size():
		var n: Dictionary = notes[i]
		var lane := int(n.lane)
		# a finger comes over its drum as its berry nears
		if float(n.t) - vt < 0.7 and not _skip.has(i):
			_seen[lane] = true
		if float(n.t) > vt + 0.005:
			break
		if _skip.has(i):
			continue
		if State.is_long(n.type):
			if vt <= float(n.end) and n.st == State.St.WAIT and vt - _roll_at >= ROLL_GAP:
				_roll_at = vt
				_tap(lane, vt + ROLL_GAP * 0.5)
			continue
		if _struck.has(i):
			continue
		_struck[i] = true
		_tap(lane, float(n.end) if n.type == State.Type.HOLD else vt + TAP_DOWN)
	var left: Array = []
	for l: Array in _lifts:
		if vt >= float(l[0]):
			_down.erase(int(l[1]))
			_art.touch(int(l[1]), false)
		else:
			left.append(l)
	_lifts = left

## Drum `lane` struck now, the finger up again at `until`.
func _tap(lane: int, until: float) -> void:
	_down[lane] = true
	_seen[lane] = true
	_art.touch(lane, true)
	_lifts.append([until, lane])

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

# --- drawing ---

func _draw_fingers() -> void:
	if _seen.is_empty() or Motion.reduce:
		_finger_shown = null
		return
	var u: float = _art._u()
	var b := Face.Builder.new()
	for lane: int in _seen:
		var down: bool = _down.has(lane)
		var at: Vector2 = _art.position + _art.finger_at(lane) + (Vector2.ZERO if down else Vector2(0, -22.0 * u))
		var r := 46.0 * u * (0.85 if down else 1.0)
		b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if down else 1.0)))
		b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)

## The HUD page: the top bar's Reset and ?, and the start card's Tune, each
## drawn as it is on the board beside what it does.
func _draw() -> void:
	if lesson != Lesson.HUD or size.x <= 0.0:
		return
	var rows := [["reset", "HTP_DB_HUD_RESET"], ["help", "HTP_DB_HUD_HELP"], ["", "HTP_DB_HUD_TUNE"]]
	var row_h := size.y / rows.size()
	var chip := minf(104.0, row_h * 0.72)
	var x0 := 36.0
	var b := Face.Builder.new()
	var rects: Array = []
	for k in rows.size():
		var cy := row_h * (k + 0.5)
		var wide := chip * (2.3 if String(rows[k][0]) == "" else 1.0)
		var r := Rect2(Vector2(x0 + (chip * 2.3 - wide) * 0.5, cy - chip * 0.5), Vector2(wide, chip))
		rects.append(r)
		b.polygon(Face.Builder.round_rect(r.position + Vector2(0, 6.0), r.size, 26.0), Color(Pal.TEXT, 0.16))
		b.polygon(Face.Builder.round_rect(r.position, r.size, 26.0), Color("efe3cc") if String(rows[k][0]) == "" else Pal.SURFACE)
	_hud_shown = b.mesh()
	draw_mesh(_hud_shown, null)
	var font: Font = CozyTheme.display(700)
	for k in rows.size():
		var r: Rect2 = rects[k]
		var icon := String(rows[k][0])
		if icon != "":
			Icons.paint(self, icon, Rect2(r.get_center() - Vector2(chip, chip) * 0.27, Vector2(chip, chip) * 0.54), Pal.TEXT)
		else:
			var word := tr("DB_TUNE_BUTTON") % "+0"
			var px := 30
			var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			if w > r.size.x - 20.0:
				px = int(px * (r.size.x - 20.0) / w)
				w = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			draw_string(font, r.get_center() + Vector2(-w * 0.5, px * 0.35), word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Pal.TEXT)
		var tx := x0 + chip * 2.3 + 28.0
		var line := tr(String(rows[k][1]))
		var lines := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, size.x - tx - 24.0, 30)
		draw_multiline_string(font, Vector2(tx, r.get_center().y - lines.y * 0.5 + 30.0 * 0.82), line, HORIZONTAL_ALIGNMENT_LEFT, size.x - tx - 24.0, 30, -1, Pal.TEXT)
