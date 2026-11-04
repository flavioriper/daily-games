extends Control

## A test (the user, 2026-11-04): a port of Persona Studio's swarm
## (~/dev/hokipoki/persona-studio/static/home.html, "the swarm") as a special
## tab of the first screen. It deliberately wears none of the game's paper:
## a dark room, and a swarm of glowing particles that gathers into a face and
## talks to the player. Nothing is wired to a brain; a short script plays the
## agent's two screen tools (agent/tools.py `swarm` and `move`) so every look,
## glance, move, visit and idle can be seen.
##
## Every dot is one unit of the same material, with a role: free (the cloud
## round the face, a few wandering the room), body (a shaded disc) or eye (two
## pills). Movement is steering with momentum, not interpolation, so the swarm
## overshoots, settles and shimmers. The numbers are the web's, per 60 Hz
## step, with lengths scaled by `_u` (the face's radius over the web's 75).
##
## Drawing: the sim runs in GDScript and lands in two MultiMeshes under an
## additive material -- a sharp core per dot, stretched into a streak when it
## travels fast, and a soft glow under the eyes, the big free motes and the
## face -- plus one radial halo behind the face. Three draw calls for the
## swarm whatever its size.

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Motion = preload("res://core/motion.gd")

const N := 1300
const STEP := 1.0 / 60.0
const IDLE_MS := 5000.0
## The web's dark theme (static/home.html, :root dark): the agent's green,
## its highlight and shadow, the eyes, and the room.
const COL_P := Color8(138, 214, 166)
const COL_PH := Color8(214, 246, 222)
const COL_PD := Color8(36, 110, 70)
const COL_EYE := Color8(246, 255, 248)
const ROOM := Color("0b1510")
const ROOM_DEEP := Color("040806")
const RADIUS := 36

enum Role { FREE, BODY, EYE }

const DIRS := {
	"left": Vector2(-1, 0), "right": Vector2(1, 0), "up": Vector2(0, -1), "down": Vector2(0, 1),
	"up-left": Vector2(-0.71, -0.71), "up-right": Vector2(0.71, -0.71),
	"down-left": Vector2(-0.71, 0.71), "down-right": Vector2(0.71, 0.71),
}
const SPOTS := {
	"centre": Vector2(0.5, 0.42), "left": Vector2(0.2, 0.42), "right": Vector2(0.8, 0.42),
	"top": Vector2(0.5, 0.2), "bottom": Vector2(0.5, 0.7),
	"top-left": Vector2(0.24, 0.2), "top-right": Vector2(0.76, 0.2),
	"bottom-left": Vector2(0.24, 0.7), "bottom-right": Vector2(0.76, 0.7),
}

## The demo: what an agent would have said and done with its two tools.
## `look`/`idle`/`seconds` are the swarm tool's, `move` the move tool's.
const SCRIPT := [
	{"say": "SWARM_L1"},
	{"look": "up-left", "seconds": 1.4, "say": "SWARM_L2"},
	{"move": "top-left", "say": "SWARM_L3"},
	{"look": "point", "x": 0.85, "y": 0.85, "seconds": 2.2, "say": "SWARM_L4"},
	{"move": "bottom-right", "seconds": 4.5, "say": "SWARM_L5"},
	{"wait": 4.5},
	{"move": "centre", "look": "ahead", "idle": "cursor", "say": "SWARM_L6"},
	{"wait": 9.0},
	{"idle": "wander", "say": "SWARM_L7"},
	{"wait": 12.0},
	{"idle": "doze", "say": "SWARM_L8"},
	{"wait": 16.0},
]

# --- the particles, one slot each across parallel arrays ---
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _vx := PackedFloat32Array()
var _vy := PackedFloat32Array()
var _s := PackedFloat32Array()
var _a := PackedFloat32Array()
var _ph := PackedFloat32Array()
var _uu := PackedFloat32Array()
var _ang := PackedFloat32Array()
var _r := PackedFloat32Array()
var _sp := PackedFloat32Array()
var _lx := PackedFloat32Array()
var _ly := PackedFloat32Array()
var _sh := PackedFloat32Array()
var _ex := PackedFloat32Array()
var _k := PackedFloat32Array()
var _role := PackedInt32Array()

# --- the engine: the web's `eng`, one face only (the bare home) ---
var _seeded := false
var _formed := false
var _gather := 0.0
var _c := Vector2.ZERO
var _cv := Vector2.ZERO
var _R := 120.0
var _u := 1.6
var _travel := 0.0
var _eye_open := 1.0
var _blink_until := 0.0
var _next_blink := 4000.0
var _doze := 0.0
var _gaze := Vector2.ZERO
var _level := 0.0
var _voice := false
var _state := ""  # "", "thinking", "speaking", "listening"
var _now := 0.0  # ms of sim time
var _acc := 0.0

var _look := {"look": "ahead"}
var _glance_back = null
var _glance_at := 0.0
var _place := {"to": "centre"}
var _visit_back = null
var _visit_at := 0.0
var _idle := ""
var _idle_now := false
var _wander_spot = null
var _wander_until := 0.0
var _mouse = null
var _last_active := 0.0
var _listen_until := 0.0

# --- the talk ---
var _step_i := -1
var _step_wait := 0.0
var _boot_t := 0.0
var _line := ""
var _line_t := 0.0
var _line_len := 0.0
var _think_t := 0.0
var _pending_say := ""

# --- the drawing ---
var _dots: MultiMesh
var _glows: MultiMesh
var _dot_buf := PackedFloat32Array()
var _glow_buf := PackedFloat32Array()
var _halo: Sprite2D
var _words: Label
var _log: Label

func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

	var room := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ROOM
	sb.set_corner_radius_all(RADIUS)
	sb.anti_aliasing_size = 1.2
	room.add_theme_stylebox_override("panel", sb)
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room)
	# A vignette: the room is deepest at its corners.
	var vig := TextureRect.new()
	vig.texture = _radial([Color(ROOM_DEEP, 0.0), Color(ROOM_DEEP, 0.0), Color(ROOM_DEEP, 0.85)], [0.0, 0.45, 1.0], 256)
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)

	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_halo = Sprite2D.new()
	_halo.texture = _radial([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.24, 1.0], 256)
	_halo.material = add
	add_child(_halo)

	_glows = _multimesh()
	_dots = _multimesh()
	var glow_mi := MultiMeshInstance2D.new()
	glow_mi.multimesh = _glows
	glow_mi.texture = _glow_texture()
	glow_mi.material = add
	add_child(glow_mi)
	var dot_mi := MultiMeshInstance2D.new()
	dot_mi.multimesh = _dots
	dot_mi.texture = _dot_texture()
	dot_mi.material = add
	add_child(dot_mi)
	_dot_buf.resize(N * 12)
	_glow_buf.resize(N * 12)

	_words = Label.new()
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.add_theme_font_override("font", CozyTheme.body(600))
	_words.add_theme_font_size_override("font_size", 36)
	_words.add_theme_color_override("font_color", Color(COL_PH, 0.92))
	_words.add_theme_color_override("font_shadow_color", Color(COL_P, 0.35))
	_words.add_theme_constant_override("shadow_outline_size", 10)
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_words)

	# What the agent just did with its tools, quietly, in the corner (the
	# web's action log).
	_log = Label.new()
	_log.add_theme_font_override("font", CozyTheme.body(600))
	_log.add_theme_font_size_override("font_size", 22)
	_log.add_theme_color_override("font_color", Color(COL_P, 0.42))
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log)

	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))
	set_process(false)

## The menu calls this when the tab opens.
func refresh() -> void:
	set_process(true)
	_last_active = _now

func _multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = N
	mm.custom_aabb = AABB(Vector3(-20000, -20000, -1), Vector3(40000, 40000, 2))
	return mm

static func _radial(cols: Array, offs: Array, px: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray(cols)
	g.offsets = PackedFloat32Array(offs)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = px
	t.height = px
	return t

## A dot: a hot white core with a short soft rim.
static func _dot_texture() -> ImageTexture:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for j in n:
		for i in n:
			var d := Vector2(i + 0.5 - n * 0.5, j + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := clampf((1.0 - d) / 0.35, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(i, j, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

## A glow: a gaussian that runs out at the quad's edge.
static func _glow_texture() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for j in n:
		for i in n:
			var d := Vector2(i + 0.5 - n * 0.5, j + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := exp(-d * d * 4.5) * clampf((1.0 - d) * 4.0, 0.0, 1.0)
			img.set_pixel(i, j, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _seed() -> void:
	_seeded = true
	var w := size.x
	var h := size.y
	_R = minf(w, h) * 0.17
	_u = _R / 75.0
	_c = _spot("centre")
	for arr in [_x, _y, _vx, _vy, _s, _a, _ph, _uu, _ang, _r, _sp, _lx, _ly, _sh, _ex, _k]:
		arr.resize(N)
	_role.resize(N)
	for i in N:
		_x[i] = randf_range(0, w)
		_y[i] = randf_range(0, h)
		_vx[i] = randf_range(-0.3, 0.3) * _u
		_vy[i] = randf_range(-0.3, 0.3) * _u
		_s[i] = randf_range(0.6, 2.0)
		_a[i] = randf_range(0.3, 0.9)
		_ph[i] = randf_range(0, TAU)
		_uu[i] = randf()
		_ang[i] = randf_range(0, TAU)
		_r[i] = randf_range(1.3, 3.4)
		_sp[i] = randf_range(0.002, 0.007) * (1.0 if randf() < 0.5 else -1.0)
		_sh[i] = 1.0
		_ex[i] = 1.0
		_k[i] = 0.0
		_role[i] = Role.FREE

func _free_shuffled() -> Array:
	var out := []
	for i in N:
		if _role[i] == Role.FREE:
			out.append(i)
	out.shuffle()
	return out

## The swarm takes the shape of a face: a disc shaded from its upper left.
func _become(count: int) -> void:
	for i in _free_shuffled().slice(0, count):
		_role[i] = Role.BODY
		_k[i] = randf_range(0.05, 0.1)
		var a := randf_range(0, TAU)
		var rr := sqrt(randf())
		_lx[i] = cos(a) * rr
		_ly[i] = sin(a) * rr
		var d := Vector2(_lx[i] + 0.38, _ly[i] + 0.34).length()
		_sh[i] = clampf(1.05 - d / 1.45, 0.08, 1.0) * (0.55 if rr > 0.93 else 1.0)
		_s[i] = randf_range(0.7, 1.9)
		_a[i] = randf_range(0.55, 1.0)

func _open_eyes(count: int) -> void:
	var n := 0
	for i in _free_shuffled().slice(0, count):
		_role[i] = Role.EYE
		_k[i] = randf_range(0.09, 0.12)
		_ex[i] = 1.0 if n % 2 else -1.0
		n += 1
		var p := _pill_point()
		_lx[i] = p.x
		_ly[i] = p.y
		_s[i] = randf_range(1.1, 2.0)
		_a[i] = randf_range(0.8, 1.0)

static func _pill_point() -> Vector2:
	while true:
		var x := randf_range(-1, 1)
		var y := randf_range(-1, 1)
		if absf(y) <= 0.62 or absf(x) <= sqrt(maxf(0.0, 1.0 - pow((absf(y) - 0.62) / 0.38, 2.0))):
			return Vector2(x, y)
	return Vector2.ZERO

func _spot(to: String) -> Vector2:
	var f: Vector2 = SPOTS.get(to, SPOTS.centre)
	return _clamp_face(Vector2(f.x * size.x, f.y * size.y))

func _clamp_face(p: Vector2) -> Vector2:
	var m := _R * 1.25
	return Vector2(clampf(p.x, m, size.x - m), clampf(p.y, m, size.y - _R * 2.4))

func _goal() -> Vector2:
	if _place.to == "point":
		return _clamp_face(Vector2(_place.x * size.x, _place.y * size.y))
	return _spot(String(_place.to))

# --- the two tools ---

## The swarm tool: where the eyes look, for a glance or for good, and what
## they do when the player goes quiet.
func apply_swarm(cmd: Dictionary) -> void:
	if cmd.has("idle"):
		_idle = String(cmd.idle)
		_note("idle set  " + _idle)
	if not cmd.has("look"):
		return
	_glance_back = null
	if cmd.has("seconds"):
		_glance_back = _look
		_glance_at = _now + float(cmd.seconds) * 1000.0
	_look = cmd
	_note("look  " + String(cmd.look) + ("  · %ss" % cmd.seconds if cmd.has("seconds") else ""))

## The move tool: where the face sits, for a visit or for good.
func apply_move(cmd: Dictionary) -> void:
	_visit_back = null
	if cmd.has("seconds"):
		_visit_back = _place
		_visit_at = _now + float(cmd.seconds) * 1000.0
	_place = cmd
	if Motion.reduce:
		_c = _goal()
		_cv = Vector2.ZERO
	_note("move  " + String(cmd.to) + ("  · %ss" % cmd.seconds if cmd.has("seconds") else ""))

func _note(s: String) -> void:
	var lines := _log.text.split("\n", false)
	lines.append(s)
	while lines.size() > 3:
		lines.remove_at(0)
	_log.text = "\n".join(lines)

## Where the agent chose to look this step: a unit direction (`dir`), a
## point in the room, or nothing (straight ahead).
func _look_target() -> Dictionary:
	var cmd: Dictionary = _look
	if _idle_now and _idle != "":
		match _idle:
			"cursor":
				return {"at": _mouse} if _mouse != null else {}
			"wander":
				if _now > _wander_until:
					_wander_until = _now + randf_range(1800, 4200)
					if _mouse != null and randf() < 0.3:
						_wander_spot = "cursor"
					else:
						_wander_spot = Vector2(size.x * (0.5 + randf_range(-0.42, 0.42)), size.y * (0.42 + randf_range(-0.32, 0.32)))
				if typeof(_wander_spot) == TYPE_STRING:
					return {"at": _mouse} if _mouse != null else {}
				return {"at": _wander_spot}
			_:
				return {}
	var l := String(cmd.get("look", "ahead"))
	if l == "cursor":
		return {"at": _mouse} if _mouse != null else {}
	if DIRS.has(l):
		return {"dir": DIRS[l]}
	if l == "point":
		return {"at": Vector2(float(cmd.x) * size.x, float(cmd.y) * size.y)}
	return {}

# --- the talk ---

func _say(key: String) -> void:
	# A beat of thought (eyes narrow) before the words come.
	_pending_say = key
	_think_t = 0.55
	_state = "thinking"

func _run_script(dt: float) -> void:
	if _think_t > 0.0:
		_think_t -= dt
		if _think_t <= 0.0:
			_line = tr(_pending_say)
			_line_t = 0.0
			_line_len = _line.length() / 16.0 + 0.3
			_state = "speaking"
			_voice = true
		return
	if _state == "speaking":
		_line_t += dt
		var shown := int(_line_t * 16.0)
		_words.visible_characters = shown
		if _line_t >= _line_len:
			_state = ""
			_voice = false
			_words.visible_characters = -1
			_step_wait = 1.1
		return
	if _step_wait > 0.0:
		_step_wait -= dt
		return
	_step_i = (_step_i + 1) % SCRIPT.size()
	var st: Dictionary = SCRIPT[_step_i]
	if st.has("move"):
		var m := {"to": st.move}
		if st.has("seconds") and not st.has("look"):
			m.seconds = st.seconds
		apply_move(m)
	var sw := {}
	for k in ["look", "idle", "x", "y"]:
		if st.has(k):
			sw[k] = st[k]
	if st.has("seconds") and st.has("look"):
		sw.seconds = st.seconds
	if not sw.is_empty():
		apply_swarm(sw)
	if st.has("say"):
		_say(String(st.say))
	elif st.has("wait"):
		_step_wait = float(st.wait)

## How loud the voice is right now, 0..1: syllables at the reveal's pace,
## quiet on spaces and stops.
func _voice_level() -> float:
	if _state != "speaking":
		return 0.0
	var i := int(_line_t * 16.0)
	if i >= _line.length():
		return 0.0
	var ch := _line[i]
	if ch == " " or ch in ".,!?…—":
		return 0.08
	return 0.35 + 0.65 * absf(sin(_line_t * 13.0)) * (0.6 + 0.4 * absf(sin(_line_t * 3.1)))

# --- the frame ---

func _process(delta: float) -> void:
	if size.x < 10.0 or size.y < 10.0:
		return
	if not _seeded:
		_seed()
	var dt := minf(delta, 0.1)
	_boot(dt)
	if _formed:
		_run_script(dt)
	_acc += dt
	var steps := 0
	while _acc >= STEP and steps < 4:
		_acc -= STEP
		steps += 1
		_step()
	if steps == 4:
		_acc = 0.0
	_render()

## Before the agent exists the dots are a loose field; then they are pulled
## together and become a face.
func _boot(dt: float) -> void:
	if _formed:
		return
	_boot_t += dt
	if _boot_t > 0.4:
		_gather = 1.0
	if _boot_t > 1.3:
		_become(int(N * 0.42))
		_open_eyes(int(N * 0.05))
		_formed = true
		_gather = 0.0
		_note("form  the agent")

func _step() -> void:
	_now += STEP * 1000.0
	var now := _now
	var w := size.x
	var h := size.y
	var u := _u

	if _glance_back != null and now >= _glance_at:
		_look = _glance_back
		_glance_back = null
		_note("look  " + String(_look.get("look", "ahead")))
	if _visit_back != null and now >= _visit_at:
		_place = _visit_back
		_visit_back = null
		_note("move  " + String(_place.to))
	if _state != "":
		_last_active = now
	var was := _idle_now
	_idle_now = _idle != "" and now - _last_active > IDLE_MS
	if _idle_now and not was:
		_note("idle  " + _idle)
	if not _idle_now:
		_wander_until = 0.0
	if _state == "listening" and now > _listen_until:
		_state = ""
	var target_level := _voice_level()
	_level += (target_level - _level) * 0.35

	if now > _blink_until + _next_blink and randf() < 0.02:
		_blink_until = now + 130.0
		_next_blink = randf_range(3800, 6500)
	var blink := now < _blink_until
	var dozing := 1.0 if (_idle_now and _idle == "doze") else 0.0
	_doze += (dozing - _doze) * (0.004 if _idle_now else 0.2)
	_eye_open += (((0.08 if blink else (0.32 if _state == "thinking" else 1.0)) * (1.0 - 0.72 * _doze)) - _eye_open) * 0.3

	var t := _look_target()
	var tg := Vector2.ZERO
	if t.has("dir"):
		tg = t.dir
	elif t.has("at"):
		var d: Vector2 = t.at - _c
		var dl := maxf(d.length(), 1.0)
		tg = d / dl * minf(1.0, dl / (_R * 2.2))
	_gaze += (tg - _gaze) * 0.12

	var g := _goal()
	_cv = (_cv + (g - _c) * 0.0075) * 0.875
	var cm := _cv.length()
	if cm > 9.0 * u:
		_cv *= 9.0 * u / cm
		cm = 9.0 * u
	_c += _cv
	var mvn := minf(1.0, cm / (6.0 * u))
	_travel += (mvn - _travel) * (0.08 if cm > _travel * 6.0 * u else 0.025)

	var breathe := 1.0 + 0.018 * sin(now / 1600.0)
	var fs := breathe
	if _state == "speaking":
		fs = breathe + 0.11 * _level
	elif _state == "thinking":
		fs = breathe * 0.97
	var sc := fs * _R
	var lean := 0.05 * sc
	var cx := _c.x
	var cy := _c.y
	var gx := _gaze.x
	var gy := _gaze.y
	var eo := _eye_open
	var mv := _travel
	var voice := _voice
	var env_lvl := minf(1.0, _level * 1.6)
	var gather := _gather

	for i in N:
		var px := _x[i]
		var py := _y[i]
		var vx := _vx[i]
		var vy := _vy[i]
		var role := _role[i]
		var tx: float
		var ty: float
		var k: float
		var damp: float
		var mx: float
		if role == Role.BODY:
			var ph := _ph[i]
			tx = cx + _lx[i] * sc + sin(now / 700.0 + ph) * 0.9 * u + gx * lean
			ty = cy + _ly[i] * sc + cos(now / 900.0 + ph * 1.3) * 0.9 * u + gy * lean
			k = _k[i]
			damp = 0.8
			mx = 14.0 * u
		elif role == Role.EYE:
			tx = cx + _ex[i] * 0.17 * sc + _lx[i] * 0.05 * sc + gx * 0.22 * sc
			ty = cy + 0.03 * sc + _ly[i] * 0.19 * sc * eo + gy * 0.16 * sc
			k = _k[i]
			damp = 0.78
			mx = 14.0 * u
		elif _formed and _uu[i] <= 0.86:
			# The cloud: atoms circling the face; when it travels the cloud
			# pulls in close and streams after it, inner atoms first.
			var ph2 := _ph[i]
			_ang[i] += _sp[i] * (2.2 if voice else 1.0)
			var env := 1.0
			if voice:
				env = 1.0 + 0.45 * env_lvl * (0.7 + 0.3 * absf(sin(now / 150.0 + ph2 * 0.2)))
			var rr := _R * _r[i] * (1.0 + 0.12 * sin(now / 1300.0 + ph2)) * env
			var wgt := clampf((3.6 - _r[i]) / 2.3, 0.15, 1.0)
			var r2 := rr * (1.0 - 0.5 * mv)
			tx = cx + cos(_ang[i]) * r2
			ty = cy + sin(_ang[i]) * r2 * 0.48 + sin(now / 1100.0 + ph2) * 6.0 * u
			k = 0.012 * (1.0 - mv) + mv * (0.004 + 0.01 * wgt)
			damp = 0.9
			mx = (2.6 + 5.0 * mv * wgt) * u
		else:
			# Wanderers (and, before the face, the whole field): a slow drift
			# that wraps at the walls, pulled in while gathering.
			vx += randf_range(-0.02, 0.02) * u
			vy += randf_range(-0.02, 0.02) * u
			if gather > 0.0:
				vx += (cx - px) * 0.0006 * gather
				vy += (cy - py) * 0.0006 * gather
			var lim := (3.0 if gather > 0.0 else 0.5) * u
			var m := sqrt(vx * vx + vy * vy)
			if m > lim:
				vx *= lim / m
				vy *= lim / m
			px += vx
			py += vy
			if px < -10.0: px = w + 10.0
			elif px > w + 10.0: px = -10.0
			if py < -10.0: py = h + 10.0
			elif py > h + 10.0: py = -10.0
			_x[i] = px
			_y[i] = py
			_vx[i] = vx
			_vy[i] = vy
			continue
		vx = (vx + (tx - px) * k) * damp
		vy = (vy + (ty - py) * k) * damp
		var m2 := sqrt(vx * vx + vy * vy)
		if m2 > mx:
			vx *= mx / m2
			vy *= mx / m2
		_x[i] = px + vx
		_y[i] = py + vy
		_vx[i] = vx
		_vy[i] = vy

## Writes both MultiMeshes in one pass: each dot's colour and twinkle, a
## streak along its velocity once it is fast, and a glow under the ones that
## carry one.
func _render() -> void:
	var now := _now
	var u := _u
	var listening := _state == "listening"
	var halo_a := 0.22 if listening else (0.14 + 0.06 * _level)
	_halo.position = _c
	var hs := _R * 4.4 / 256.0
	_halo.scale = Vector2(hs, hs)
	_halo.modulate = Color(COL_P, halo_a if _formed else 0.0)
	var cvx := _cv.x
	var cvy := _cv.y
	var db := _dot_buf
	var gb := _glow_buf
	for i in N:
		var role := _role[i]
		var tw := 0.65 + 0.35 * sin(now / 500.0 + _ph[i])
		var col: Color
		var alpha: float
		var glow := 0.0
		var glow_r := 3.0
		if role == Role.BODY:
			var k := _sh[i]
			col = COL_PD.lerp(COL_PH, k)
			alpha = _a[i] * (0.8 + 0.2 * tw)
			glow = 0.07 + 0.05 * k
			glow_r = 5.0
		elif role == Role.EYE:
			col = COL_EYE
			alpha = _a[i] * 0.6
			glow = 0.16
		else:
			col = COL_P
			alpha = _a[i] * tw * 0.85
			if _s[i] > 1.7:
				glow = 0.1
		var vx := _vx[i]
		var vy := _vy[i]
		var rvx := vx - cvx if role != Role.FREE else vx
		var rvy := vy - cvy if role != Role.FREE else vy
		var spd := sqrt(rvx * rvx + rvy * rvy)
		var d := _s[i] * u * 2.4
		var px := _x[i]
		var py := _y[i]
		var o := i * 12
		var ax := d
		var ay := 0.0
		var bx := 0.0
		var by := d
		var ox := px
		var oy := py
		if spd > 3.0 * u:
			# A streak: the dot drawn long along where it is going.
			var vl := sqrt(vx * vx + vy * vy)
			var dx := vx / vl
			var dy := vy / vl
			var ln := d + vl * 1.6
			ax = dx * ln
			ay = dy * ln
			bx = -dy * d * 0.8
			by = dx * d * 0.8
			ox = px - vx * 0.8
			oy = py - vy * 0.8
		db[o] = ax
		db[o + 1] = bx
		db[o + 2] = 0.0
		db[o + 3] = ox
		db[o + 4] = ay
		db[o + 5] = by
		db[o + 6] = 0.0
		db[o + 7] = oy
		db[o + 8] = col.r
		db[o + 9] = col.g
		db[o + 10] = col.b
		db[o + 11] = alpha
		var gd := _s[i] * u * glow_r * 2.0 if glow > 0.0 else 0.0
		gb[o] = gd
		gb[o + 1] = 0.0
		gb[o + 2] = 0.0
		gb[o + 3] = px
		gb[o + 4] = 0.0
		gb[o + 5] = gd
		gb[o + 6] = 0.0
		gb[o + 7] = py
		gb[o + 8] = col.r
		gb[o + 9] = col.g
		gb[o + 10] = col.b
		gb[o + 11] = alpha * glow * 2.2
	_dots.buffer = db
	_glows.buffer = gb

	# The words travel with the face, under it, kept inside the room.
	_words.text = _line
	var ww := minf(size.x - 80.0, 640.0)
	_words.size = Vector2(ww, 0)
	_words.reset_size()
	_words.size.x = ww
	var wy := _c.y + _R * 1.55
	_words.position = Vector2(clampf(_c.x - ww * 0.5, 40.0, size.x - ww - 40.0), minf(wy, size.y - _words.size.y - 30.0))
	_words.modulate.a = 1.0 if _formed else 0.0
	_log.position = Vector2(36, size.y - _log.size.y - 28.0)

# --- the player ---

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_touch(event.position, true)
	elif event is InputEventScreenDrag:
		_touch(event.position, false)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_touch(event.position, true)
	elif event is InputEventMouseMotion:
		_mouse = event.position

## A touch wakes the swarm: it listens, and a tap earns a glance.
func _touch(p: Vector2, tap: bool) -> void:
	_mouse = p
	_last_active = _now
	if _state == "" or _state == "listening":
		_state = "listening"
		_listen_until = _now + 800.0
	if tap and _formed:
		apply_swarm({"look": "point", "x": p.x / size.x, "y": p.y / size.y, "seconds": 2.5})
