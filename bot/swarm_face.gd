class_name SwarmFace
extends Control

## The Swarm's face: a swarm of glowing particles that gathers into a face,
## looks, moves, draws and talks. Cut out of the Swarm tab
## (ui/menu/swarm_tab.gd) on 2026-11-05, when the tab became the call screen
## (bot/bot_screen.gd, the room around this face: the back button, the log,
## the demo pills, the call). The tab began as a test (the user, 2026-11-04):
## a port of Persona Studio's swarm
## (~/dev/hokipoki/persona-studio/static/home.html, "the swarm"). It
## deliberately wears none of the game's paper: a dark room, and the face
## talking to the player out loud. Offline it plays its demos (the words
## appear as they are said from ElevenLabs clips, tools/gen_swarm_voice.py,
## and the voice's loudness drives the face and the cloud); on a call
## (`live`) the screen hands it the server's states, lines, level and tools.
##
## Every dot is one unit of the same material, with a role: free (the cloud
## round the face, a few wandering the room), body (a shaded disc) or eye (two
## pills). Movement is steering with momentum, not interpolation, so the swarm
## overshoots, settles and shimmers. The numbers are the web's, per 60 Hz
## step, with lengths scaled by `_u` (the face's radius over the web's 75).
##
## Drawing (2026-11-04, the second pass: "a futuristic fully detailed thing",
## Godot-native, the renderer left on Compatibility): the sim runs in
## GDScript and lands in MultiMeshes whose dots are drawn by a shader from
## their custom data (shaders/swarm_dot_2d.gdshader: a soft mote, a hex
## crystal or a bokeh disc, in or out of focus, a chromatic fringe along a
## fast streak, a hot core). The face is a sphere, not a disc: every body dot
## has a depth, the sphere turns toward where it looks, and its shading comes
## from the turned normal under one light in the room, so the far side goes
## dark and soft as it rolls away. The nearest body dots are tied by a
## lattice of thin threads (a third MultiMesh), instrument rings turn on the
## cloud's orbit plane (one quad, swarm_rings_2d), and the room itself is a
## shader (a lit hex floor, the face's light pooled below it, dithered). The
## bloom is Godot's only one on this renderer: the same MultiMeshes drawn
## again at a quarter of the size into a SubViewport, blurred in a second,
## and added over the screen. Eleven draw calls for the swarm whatever its
## size, and no draw call grows with N.
##
## Two more tools (2026-11-05, the user: "let the agent draw any pixel
## image using the particles", "also add tool to agent spawn more
## particles, or despawn it"):
## - `apply_draw`: the face comes apart and its dots, and the cloud's, crowd
##   into the shape of a picture (bot/swarm_picture.gd: a Pixel Garden
##   picture by name, the night's picture, a grid the agent wrote, or a png).
##   They stay the swarm's own dots, motes and crystals in its tone, each a
##   little brighter or dimmer by its pixel, so features show; never tiles in
##   the picture's colours (the user: "Drawing should be done using the
##   particles, not spawning something"). It travels with the move tool,
##   stays until cleared or for `seconds`, then the face forms again; the
##   rings, threads and halo fade while it shows.
## - `apply_tone` (the user: "Give him tool to change particles tone and
##   intensity"): the whole swarm's colour, by name or hex, and how bright
##   it burns, eased over a second, for good or for `seconds`. The face's
##   palette (its lit, deep, eye and two orbit accents), the halo, the rings
##   and the room's pool all follow, each keeping its place against the base
##   as the green ones do.
## - `apply_dots`: more dots (born at the face, a point or drifting in from
##   the edges, fading in) or fewer (cloud dots only, fading where they are,
##   swallowed by the face or flying off the edges), between MIN_LIVE and
##   CAP. A slot is reused once its dot has died; the MultiMesh is sized
##   CAP and draws only the slots in use, so the draw calls stay the same.

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Motion = preload("res://core/motion.gd")

const Picture = preload("res://bot/swarm_picture.gd")

## The dots the room opens with, and the most the dots tool may raise them
## to (every slot a step and a draw walk is GDScript, so CAP is the brake).
const N := 1300
const CAP := 2400
const BODY_N := int(N * 0.42)
const EYE_N := int(N * 0.05)
## The fewest live dots: the face's, and a thin cloud.
const MIN_LIVE := BODY_N + EYE_N + 80
const FADE_IN := 0.6
const PIC_SIZE := 0.7
const DOTS_A_PIXEL := 6
const STEP := 1.0 / 60.0
const IDLE_MS := 5000.0
## The web's dark theme (static/home.html, :root dark): the agent's green,
## its highlight and shadow, the eyes, and the room.
const COL_P := Color8(138, 214, 166)
const COL_PH := Color8(214, 246, 222)
const COL_PD := Color8(36, 110, 70)
const COL_EYE := Color8(246, 255, 248)
## The cloud's cooler lights: the atoms passing in front lean cyan, the far
## ones behind lean violet, so the orbit has a near and a far.
const COL_CYAN := Color8(126, 228, 255)
const COL_VIOLET := Color8(150, 126, 255)
## The tones the tone tool knows by name (any "#rrggbb" works too).
const TONES := {
	"green": COL_P, "mint": Color("9ff0c8"), "cyan": Color("7ee4ff"), "blue": Color("7fa8ff"),
	"violet": Color("a58bff"), "pink": Color("ff8fc8"), "red": Color("ff6f6f"),
	"orange": Color("ffa45c"), "gold": Color("ffd166"), "white": Color("e6eef0"),
}
const INTENSITY := [0.0, 1.8]  # 0 = gone from the screen, still on the call (the user, 2026-11-06)
## The dials the swarm and move tools turn (the user, 2026-11-06: "way more
## open to agent creativity"): how open the eyes are, the face's size, and how
## fast it travels, each a multiplier of the face as it is.
const EYES := [0.0, 1.5]
const SCALE := [0.4, 1.8]
const SPEED := [0.25, 3.0]
const WINK_MS := 380.0
const ROOM := Color("0b1510")
const ROOM_DEEP := Color("040806")
## The one light in the room: from the upper left, toward the viewer.
const LIGHT := Vector3(-0.45, -0.42, 0.79)
const BLOOM_DIV := 4
const BLOOM_GROW := 1.7
const BLOOM_STRENGTH := 0.6
const LINKS_MAX := 900
const DOT_SHADER := preload("res://shaders/swarm_dot_2d.gdshader")
const LINK_SHADER := preload("res://shaders/swarm_link_2d.gdshader")
const RINGS_SHADER := preload("res://shaders/swarm_rings_2d.gdshader")
const ROOM_SHADER := preload("res://shaders/swarm_room_2d.gdshader")
const BLUR_SHADER := preload("res://shaders/swarm_blur_2d.gdshader")
const VOICE_DIR := "res://assets/voice/swarm/"
const VOICE_TIMES := "res://content/swarm_voice.json"
const VOICE_BUS := "Swarm"

##
## Waiting (2026-11-05, the user: "add a button on hud to start the intro,
## and one to showoff the drawing. swarm should be just idle waiting to
## interact with the user"): the room opens on the face alone, idling
## (`wander`: drifting looks, checking on the last touch now and then) until
## touched. Two glass pills (the screen's) play the demos: Intro, the
## talking script (INTRO), and Draw, the draw and dots tools (SHOWOFF). A
## demo ends, or is stopped by the other pill, back at the idle face:
## centred, looking ahead, N dots.

## What the tools just did, for the room's quiet log.
signal noted(text: String)
## A touch: where, and whether it landed on the face (or the picture).
signal tapped(at: Vector2, on_face: bool)
## A demo started or ended (`demo()` says which).
signal demo_changed

enum Role { FREE, BODY, EYE, PIXEL, DEAD }
enum Die { NO, FADE, FACE, OUT }

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

## A grid as an agent would write one for the draw tool.
const HEART := [
	"..rr.rr..",
	".rprrrrr.",
	"rpwprrrrr",
	"rprrrrrrr",
	"rrrrrrrrr",
	".rrrrrrr.",
	"..rrrrr..",
	"...rrr...",
	"....r....",
]

## The demos: what an agent would have said and done with its tools.
## `look`/`idle`/`seconds` are the swarm tool's, `move` the move tool's,
## `draw` the draw tool's and `dots` the dots tool's (the drawing demo says
## nothing: a line needs its clips).
const INTRO := [
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
	{"wait": 6.0},
]

const SHOWOFF := [
	{"dots": {"add": 700, "from": "face"}, "wait": 2.5},
	{"draw": {"name": "bank:sun"}, "tone": {"tone": "gold"}, "wait": 5.0},
	{"draw": {"name": "bank:duck", "size": 0.65}, "tone": {"tone": "cyan"}, "wait": 5.0},
	{"draw": {"rows": HEART, "palette": {"r": "red", "p": "pink", "w": "white"}, "size": 0.5}, "tone": {"tone": "pink", "intensity": 1.3}, "wait": 4.5},
	{"draw": {"name": "bank:strawberry", "size": 0.6}, "move": "top-right", "tone": {"tone": "red"}, "wait": 4.5},
	{"draw": {"name": "bank:tulip", "size": 0.6}, "move": "bottom-left", "tone": {"tone": "violet"}, "wait": 4.5},
	{"draw": {"name": "bank:snail", "size": 0.65}, "move": "centre", "tone": {"tone": "mint", "intensity": 0.9}, "wait": 4.5},
	{"draw": {"clear": true}, "move": "centre", "tone": {"tone": "green", "intensity": 1.0}, "wait": 2.0},
	{"tone": {"tone": "cyan", "intensity": 1.7, "seconds": 1.2}, "wait": 2.0},
	{"dots": {"remove": 700, "to": "edges"}, "wait": 3.0},
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
var _z := PackedFloat32Array()  # a body dot's depth on the sphere, 0 at the limb, 1 nearest
var _role := PackedInt32Array()
var _life := PackedFloat32Array()  # 0 born or gone .. 1 fully there
var _dying := PackedInt32Array()  # a Die: NO while alive, else how it goes
var _pl := PackedFloat32Array()  # a picture dot's brightness, from its pixel
var _hi := 0  # slots in use: every live or dying dot is below it

# --- the picture the draw tool put up ---
var _pic_on := false
var _pic_w := 1
var _pic_h := 1
var _pic_size := PIC_SIZE
var _pic_back_at := -1.0
var _pic_px := {}  # the picture's pixels (Picture.pixels), for dots born into it
var _pic_k := 0.0  # eases to 1 while a picture shows (rings, threads, halo fade)

# --- the tone tool: the swarm's colour and how bright it burns ---
var _tone := COL_P
var _tone_to := COL_P
var _inten := 1.0
var _inten_to := 1.0
var _tone_back = null  # {tone, intensity} to go back to, for a while
var _eyes := 1.0
var _eyes_to := 1.0
var _eyes_back = null  # the eyes' openness to go back to, for a while
var _eyes_at := 0.0
var _wink := 0.0  # -1 the left eye (as seen), 1 the right, 0 none
var _wink_until := 0.0
var _scale := 1.0
var _scale_to := 1.0
var _speed := 1.0
## The perform tool's routine: steps {at (s from the start), swarm, move,
## dots, tone, draw} still to fire, when it started and ends (ms), and with
## `back`, how the face was, to put back when it ends.
var _perf: Array = []
var _perf_t0 := 0.0
var _perf_end := -1.0
var _perf_snap = null
var _tone_at := 0.0
var _cp := COL_P
var _cph := COL_PH
var _cpd := COL_PD
var _ceye := COL_EYE
var _cacc1 := COL_CYAN
var _cacc2 := COL_VIOLET
# The lattice: pairs of body dots, each with its rest length and a phase.
var _la := PackedInt32Array()
var _lb := PackedInt32Array()
var _ll := PackedFloat32Array()
var _lph := PackedFloat32Array()
var _links_n := 0

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
var _script: Array = []  # the demo playing, or none: the face waits
## On a call: the screen sets the state, the line and the level, and no
## demo runs (set_live).
var live := false
var _ext_level := 0.0
var _step_wait := 0.0
var _boot_t := 0.0
var _line := ""
var _line_t := 0.0
var _line_len := 0.0
var _think_t := 0.0
var _pending_say := ""
var _starts := PackedFloat32Array()  # when each character of the line is said
var _voiced := false  # the line has a clip playing
var _player: AudioStreamPlayer
var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _times := {}
var _insets := Vector2.ZERO

# --- the drawing ---
var _dots: MultiMesh
var _links: MultiMesh
var _dot_buf := PackedFloat32Array()
var _link_buf := PackedFloat32Array()
var _halo: Sprite2D
var _room_mat: ShaderMaterial
var _rings_mat: ShaderMaterial
var _blur_mat: ShaderMaterial
var _rings: MeshInstance2D
var _rings_bloom: MeshInstance2D
var _bloom_vp: SubViewport
var _blur_vp: SubViewport
var _blur_rect: TextureRect
var _bloom_out: TextureRect
var _bloom_root: Node2D
var _vp_size := Vector2i.ZERO
var _rings_open := 0.0
var _words: Label
## The subtitles are off (the user, 2026-11-06: they did not match the voice;
## off until asked for). The line still drives the talking look.
var subtitles := false

func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# The room: one shader on one rect (the floor, the pool of light, the
	# vignette and the dither).
	var room := ColorRect.new()
	_room_mat = ShaderMaterial.new()
	_room_mat.shader = ROOM_SHADER
	_room_mat.set_shader_parameter("room", ROOM)
	_room_mat.set_shader_parameter("deep", ROOM_DEEP)
	_room_mat.set_shader_parameter("tint", COL_P)
	room.material = _room_mat
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room)

	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_halo = Sprite2D.new()
	_halo.texture = _radial([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.24, 1.0], 256)
	_halo.material = add
	add_child(_halo)

	# The bloom: the swarm drawn again at a quarter of the size into one
	# viewport, blurred into a second (the first is the second's child, so
	# it is drawn first), and the second added over the screen.
	_blur_vp = SubViewport.new()
	_blur_vp.disable_3d = true
	_blur_vp.transparent_bg = false
	_blur_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_blur_vp.size = Vector2i(64, 64)
	add_child(_blur_vp)
	_bloom_vp = SubViewport.new()
	_bloom_vp.disable_3d = true
	_bloom_vp.transparent_bg = false
	_bloom_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_bloom_vp.size = Vector2i(64, 64)
	_blur_vp.add_child(_bloom_vp)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = Vector2(4096, 4096)
	_bloom_vp.add_child(black)
	_bloom_root = Node2D.new()
	_bloom_root.scale = Vector2.ONE / BLOOM_DIV
	_bloom_vp.add_child(_bloom_root)
	_blur_mat = ShaderMaterial.new()
	_blur_mat.shader = BLUR_SHADER
	_blur_rect = TextureRect.new()
	_blur_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_blur_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_blur_rect.material = _blur_mat
	_blur_vp.add_child(_blur_rect)
	_bloom_out = TextureRect.new()
	_bloom_out.stretch_mode = TextureRect.STRETCH_SCALE
	_bloom_out.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bloom_out.material = add
	_bloom_out.modulate = Color(1, 1, 1, BLOOM_STRENGTH)
	_bloom_out.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bloom_out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bloom_out)

	# The swarm proper: the lattice under the dots, and the rings over them,
	# each once on the screen and once, small, in the bloom.
	_links = _multimesh(LINKS_MAX, false)
	_dots = _multimesh(CAP, true)
	var link_mat := ShaderMaterial.new()
	link_mat.shader = LINK_SHADER
	var dot_mat := ShaderMaterial.new()
	dot_mat.shader = DOT_SHADER
	var dot_bloom_mat := ShaderMaterial.new()
	dot_bloom_mat.shader = DOT_SHADER
	dot_bloom_mat.set_shader_parameter("grow", BLOOM_GROW)
	_rings_mat = ShaderMaterial.new()
	_rings_mat.shader = RINGS_SHADER
	_rings_mat.set_shader_parameter("tint", COL_P)
	_rings_mat.set_shader_parameter("hot", COL_PH)
	_rings_mat.set_shader_parameter("open", 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for host in [self, _bloom_root]:
		var link_mi := MultiMeshInstance2D.new()
		link_mi.multimesh = _links
		link_mi.material = link_mat
		host.add_child(link_mi)
		var dot_mi := MultiMeshInstance2D.new()
		dot_mi.multimesh = _dots
		dot_mi.material = dot_mat if host == self else dot_bloom_mat
		host.add_child(dot_mi)
		var rings := MeshInstance2D.new()
		rings.mesh = quad
		rings.material = _rings_mat
		host.add_child(rings)
		if host == self:
			_rings = rings
		else:
			_rings_bloom = rings
	_dot_buf.resize(CAP * 16)
	_link_buf.resize(LINKS_MAX * 12)

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

	_player = AudioStreamPlayer.new()
	_player.bus = VOICE_BUS
	add_child(_player)

	visible = false
	set_process(false)

## Opens the room: the swarm gathers again from a loose field, the script
## starts from its first line and the soundtrack waits.
func open() -> void:
	if visible:
		return
	_ensure_bus()
	if _times.is_empty() and FileAccess.file_exists(VOICE_TIMES):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(VOICE_TIMES))
		if parsed is Dictionary:
			_times = parsed
	_seeded = false
	_formed = false
	_boot_t = 0.0
	_step_i = -1
	_step_wait = 0.0
	_script = []
	_state = ""
	_voice = false
	_line = ""
	_think_t = 0.0
	_idle = "wander"
	_look = {"look": "ahead"}
	_place = {"to": "centre"}
	_glance_back = null
	_visit_back = null
	_cv = Vector2.ZERO
	_links_n = 0
	_links.visible_instance_count = 0
	_pic_on = false
	_pic_k = 0.0
	_pic_back_at = -1.0
	_tone = COL_P
	_tone_to = COL_P
	_inten = 1.0
	_inten_to = 1.0
	_tone_back = null
	_eyes = 1.0
	_eyes_to = 1.0
	_eyes_back = null
	_wink = 0.0
	_scale = 1.0
	_scale_to = 1.0
	_speed = 1.0
	_perf.clear()
	_perf_end = -1.0
	_perf_snap = null
	_palette()
	_bloom_out.modulate.a = BLOOM_STRENGTH
	_rings_open = 0.0
	_rings_mat.set_shader_parameter("open", 0.0)
	_room_mat.set_shader_parameter("lit", 0.0)
	live = false
	_ext_level = 0.0
	visible = true
	# A bare SubViewport draws every frame whether or not its parent shows,
	# so the bloom's two run only while the room is open.
	_bloom_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_blur_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	set_process(true)
	_last_active = _now
	modulate.a = 0.0
	Motion.appear(self, 0.0, 1.0, 0.25)

## Not `is_open`: ui/menu.gd go_back() closes the first node answering
## is_open(), and that must be the screen (which ends the call), never the face.
func is_showing() -> bool:
	return visible

func close() -> void:
	if not visible:
		return
	_player.stop()
	live = false
	visible = false
	_bloom_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_blur_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)

## The voice's own bus and its analyser, shared with the call
## (BotCall.ensure_bus) so both voices go the same way.
func _ensure_bus() -> void:
	_spectrum = BotCall.spectrum()

## A MultiMesh of unit quads; custom data (what the dot shader reads) has to
## be switched on before the count is set.
static func _multimesh(count: int, custom: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = custom
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = count
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

## The two viewports and the room follow the control's size.
func _fit() -> void:
	var want := Vector2i(ceili(size.x / BLOOM_DIV), ceili(size.y / BLOOM_DIV))
	if want == _vp_size:
		return
	_vp_size = want
	_bloom_vp.size = want
	_blur_vp.size = want
	_blur_rect.size = Vector2(want)
	_blur_rect.texture = _bloom_vp.get_texture()
	_blur_mat.set_shader_parameter("texel", Vector2(1.0 / want.x, 1.0 / want.y))
	_bloom_out.texture = _blur_vp.get_texture()
	_room_mat.set_shader_parameter("size", size)

func _seed() -> void:
	_seeded = true
	_insets = SafeArea.insets(self)
	var w := size.x
	var h := size.y
	_R = minf(w, h) * 0.17
	_u = _R / 75.0
	_c = _spot("centre")
	_fit()
	_room_mat.set_shader_parameter("radius", _R)
	_rings_mat.set_shader_parameter("px", 1.0 / _R)
	for arr in [_x, _y, _vx, _vy, _s, _a, _ph, _uu, _ang, _r, _sp, _lx, _ly, _sh, _ex, _k, _z, _life, _pl]:
		arr.resize(CAP)
	_role.resize(CAP)
	_dying.resize(CAP)
	for i in CAP:
		_role[i] = Role.DEAD
		_dying[i] = Die.NO
		_life[i] = 0.0
	_hi = 0
	for i in N:
		_born(i, Vector2(randf_range(0, w), randf_range(0, h)), Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)) * _u)
		_life[i] = 1.0
	_dots.visible_instance_count = _hi

## A dot comes into slot `i` (a dead one) at `p`, moving at `v`, a free
## dot of the cloud or a wanderer, fading in.
func _born(i: int, p: Vector2, v: Vector2) -> void:
	_x[i] = p.x
	_y[i] = p.y
	_vx[i] = v.x
	_vy[i] = v.y
	_s[i] = randf_range(0.6, 2.0)
	_a[i] = randf_range(0.3, 0.9)
	_ph[i] = randf_range(0, TAU)
	_uu[i] = randf()
	_ang[i] = atan2((p.y - _c.y) / 0.48, p.x - _c.x)
	_r[i] = randf_range(1.3, 3.4)
	_sp[i] = randf_range(0.002, 0.007) * (1.0 if randf() < 0.5 else -1.0)
	_sh[i] = 1.0
	_ex[i] = 1.0
	_k[i] = 0.0
	_z[i] = 0.0
	_role[i] = Role.FREE
	_dying[i] = Die.NO
	_life[i] = 0.0
	if i >= _hi:
		_hi = i + 1

func _free_shuffled() -> Array:
	var out := []
	for i in _hi:
		if _role[i] == Role.FREE and _dying[i] == Die.NO:
			out.append(i)
	out.shuffle()
	return out

## The swarm takes the shape of a face: a sphere seen from the front, every
## dot on its near surface (its depth from its place on the disc), the limb
## dimmer. Then the lattice: each body dot tied to its nearest neighbour on
## the surface, found through a grid so the forming never hitches.
func _become(count: int) -> void:
	var body := _free_shuffled().slice(0, count)
	for i in body:
		_role[i] = Role.BODY
		_k[i] = randf_range(0.05, 0.1)
		var a := randf_range(0, TAU)
		var rr := sqrt(randf())
		_lx[i] = cos(a) * rr
		_ly[i] = sin(a) * rr
		_z[i] = sqrt(maxf(0.0, 1.0 - rr * rr))
		_sh[i] = 0.55 if rr > 0.93 else 1.0
		_s[i] = randf_range(0.7, 1.9)
		_a[i] = randf_range(0.55, 1.0)
	_lattice(body)

## The lattice's nodes are a quarter of the body (the hex crystals), each
## tied to its two nearest nodes over the surface; a thread between two
## neighbours of the whole body would be shorter than a dot.
func _lattice(body: Array) -> void:
	var nodes := []
	for i in body:
		if _uu[i] < 0.26:
			nodes.append(i)
	var cells := 8
	var grid := {}
	for i in nodes:
		var key := int((_lx[i] + 1.0) * 0.5 * cells) * 64 + int((_ly[i] + 1.0) * 0.5 * cells)
		if not grid.has(key):
			grid[key] = []
		grid[key].append(i)
	var seen := {}
	_la = PackedInt32Array()
	_lb = PackedInt32Array()
	_ll = PackedFloat32Array()
	_lph = PackedFloat32Array()
	for i in nodes:
		var gx := int((_lx[i] + 1.0) * 0.5 * cells)
		var gy := int((_ly[i] + 1.0) * 0.5 * cells)
		var near := []
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for j in grid.get((gx + dx) * 64 + gy + dy, []):
					if j == i:
						continue
					var ex := _lx[i] - _lx[j]
					var ey := _ly[i] - _ly[j]
					var ez := _z[i] - _z[j]
					near.append([ex * ex + ey * ey + ez * ez, j])
		near.sort_custom(func(a, b): return a[0] < b[0])
		for n in mini(2, near.size()):
			var j: int = near[n][1]
			var key := mini(i, j) * CAP + maxi(i, j)
			if seen.has(key) or _la.size() >= LINKS_MAX:
				continue
			seen[key] = true
			_la.append(i)
			_lb.append(j)
			_ll.append(Vector2(_lx[i] - _lx[j], _ly[i] - _ly[j]).length())
			_lph.append(randf_range(0, TAU))
	_links_n = _la.size()
	_links.visible_instance_count = _links_n

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
		_z[i] = 0.96
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
	# Half off an edge (peeking in) or right off it (gone that way): the face
	# only; a picture keeps all of itself on screen.
	if not _pic_on and (to.begins_with("peek-") or to.begins_with("off-")):
		var r := _R * _scale
		var out := r * (0.0 if to.begins_with("peek-") else 4.2)
		match to.get_slice("-", 1):
			"left":
				return Vector2(-out, size.y * 0.42)
			"right":
				return Vector2(size.x + out, size.y * 0.42)
			"top":
				return Vector2(size.x * 0.5, -out)
			"bottom":
				return Vector2(size.x * 0.5, size.y + out)
	var f: Vector2 = SPOTS.get(to, SPOTS.centre)
	return _clamp_face(Vector2(f.x * size.x, f.y * size.y))

func _clamp_face(p: Vector2) -> Vector2:
	if _pic_on:
		# A picture keeps all of itself on screen, clear of the subtitles.
		var half := Vector2(_pic_w, _pic_h) * _pic_cell() * 0.5 + Vector2(16, 16)
		return Vector2(_fit_axis(p.x, half.x, size.x - half.x), _fit_axis(p.y, half.y + 40.0, size.y - half.y - 200.0))
	var m := _R * _scale * 1.25
	return Vector2(_fit_axis(p.x, m, size.x - m), _fit_axis(p.y, m, size.y - _R * _scale * 2.4))

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
	if cmd.has("eyes"):
		_eyes_back = null
		if cmd.has("seconds"):
			_eyes_back = _eyes_to
			_eyes_at = _now + float(cmd.seconds) * 1000.0
		_eyes_to = clampf(float(cmd.eyes), EYES[0], EYES[1])
		_note("eyes  %.2f" % _eyes_to + ("  · %ss" % cmd.seconds if cmd.has("seconds") else ""))
	if bool(cmd.get("blink", false)):
		_blink_until = _now + 130.0
		_note("blink")
	if cmd.has("wink"):
		_wink = -1.0 if String(cmd.wink) == "left" else 1.0
		_wink_until = _now + WINK_MS
		_note("wink  " + String(cmd.wink))
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
	if cmd.has("size"):
		_scale_to = clampf(float(cmd.size), SCALE[0], SCALE[1])
		if Motion.reduce:
			_scale = _scale_to
		_note("size  %.2f" % _scale_to)
	if cmd.has("speed"):
		_speed = clampf(float(cmd.speed), SPEED[0], SPEED[1])
		_note("speed  %.2f" % _speed)
	if not cmd.has("to"):
		return
	_visit_back = null
	if cmd.has("seconds"):
		_visit_back = _place
		_visit_at = _now + float(cmd.seconds) * 1000.0
	_place = cmd
	if Motion.reduce:
		_c = _goal()
		_cv = Vector2.ZERO
	_note("move  " + String(cmd.to) + ("  · %ss" % cmd.seconds if cmd.has("seconds") else ""))

static func _fit_axis(v: float, lo: float, hi: float) -> float:
	return (lo + hi) * 0.5 if lo > hi else clampf(v, lo, hi)

## How wide one pixel of the picture is on screen.
func _pic_cell() -> float:
	return minf(size.x, size.y) * _pic_size / float(maxi(1, maxi(_pic_w, _pic_h)))

func _pic_cell_for(px: Dictionary) -> float:
	return minf(size.x, size.y) * _pic_size / float(maxi(1, maxi(int(px.w), int(px.h))))

## The draw tool: the swarm takes the shape of a picture (see Picture for
## the sources) where the face is, `size` of the screen's shorter side
## across (0.2 to 0.95), for good or for `seconds`; `clear` brings the face
## back. Every dot of the face and the cloud goes into it, dealt round its
## pixels so each holds its share, scattered inside its pixel; the
## wanderers stay out. A picture is shrunk, squares kept, until every pixel
## has at least DOTS_A_PIXEL dots. Returns what was done, or an error, for
## the agent to hear.
func apply_draw(cmd: Dictionary) -> Dictionary:
	if bool(cmd.get("clear", false)):
		if _pic_on:
			_clear_picture()
		_note("draw  clear")
		return {"summary": "Done: my face is back"}
	if not _formed:
		return {"error": "the swarm is still forming"}
	var got := Picture.image_of(cmd)
	if got.has("error"):
		_note("draw  " + String(got.error))
		return got
	var pool := []
	var cloud := []
	for i in _hi:
		if _dying[i] != Die.NO:
			continue
		match _role[i]:
			Role.BODY, Role.EYE, Role.PIXEL:
				pool.append(i)
			Role.FREE:
				if _uu[i] <= 0.86:
					cloud.append(i)
	cloud.sort_custom(func(a, b): return _r[a] < _r[b])
	pool.append_array(cloud)
	var px := Picture.pixels(got.image, maxi(1, pool.size() / DOTS_A_PIXEL))
	_pic_size = clampf(float(cmd.get("size", PIC_SIZE)), 0.2, 0.95)
	var n: int = px.n
	if n == 0:
		_note("draw  nothing to draw")
		return {"error": "the picture has nothing bright enough to draw"}
	# A place for every dot: the pixels share the dots by weight (bright
	# ones and outlines more, dark ones fewer: Picture.pixels), dealt in
	# even steps along the weights so the shares are exact, each dot
	# anywhere inside its pixel.
	var xs: PackedFloat32Array = px.x
	var ys: PackedFloat32Array = px.y
	var ls: PackedFloat32Array = px.l
	var ws: PackedFloat32Array = px.wt
	var total := 0.0
	for wt in ws:
		total += wt
	var stride := total / pool.size()
	var at := randf() * stride
	var run := 0.0
	var spots := []
	for c in n:
		run += ws[c]
		while at < run and spots.size() < pool.size():
			spots.append([xs[c] + randf_range(-0.5, 0.5), ys[c] + randf_range(-0.5, 0.5), ls[c]])
			at += stride
	while spots.size() < pool.size():
		var c := randi() % n
		spots.append([xs[c] + randf_range(-0.5, 0.5), ys[c] + randf_range(-0.5, 0.5), ls[c]])
	# Dots and places sorted alike (top to bottom, in bands left to right),
	# so each dot flies to a place near where it is.
	spots.sort_custom(func(a, b): return a[1] < b[1])
	spots = Picture.band_sorted(spots, func(q): return q[0])
	pool.sort_custom(func(a, b): return _y[a] < _y[b])
	pool = Picture.band_sorted(pool, func(i): return _x[i])
	_pic_px = px
	var cell := _pic_cell_for(px)
	for j in pool.size():
		var i: int = pool[j]
		_role[i] = Role.PIXEL
		_lx[i] = spots[j][0]
		_ly[i] = spots[j][1]
		_pl[i] = spots[j][2]
		_k[i] = randf_range(0.03, 0.065)
		if Motion.reduce:
			# Under reduced motion the picture is simply there.
			_x[i] = _c.x + _lx[i] * cell
			_y[i] = _c.y + _ly[i] * cell
			_vx[i] = 0.0
			_vy[i] = 0.0
	_pic_on = true
	_pic_w = px.w
	_pic_h = px.h
	_pic_back_at = _now + float(cmd.seconds) * 1000.0 if cmd.has("seconds") else -1.0
	_links_n = 0
	_links.visible_instance_count = 0
	_note("draw  %s  %dx%d · %d dots" % [got.name, px.w, px.h, pool.size()] + ("  · %ss" % cmd.seconds if cmd.has("seconds") else ""))
	return {"summary": "Done: I drew %s with my %d dots, %d by %d" % [got.name, pool.size(), px.w, px.h], "w": px.w, "h": px.h, "dots": pool.size()}

## The see tool's phone half (the user, 2026-11-05: "give the agent a tool
## to see the screen ... so he can draw and see it"): the frame last drawn,
## the room only, shrunk to `width` pixels across and sent back as a JPEG in
## base64, for the call to hand the model as an image. It shows only what
## the room shows (the swarm, the subtitles, and the screen's log, status
## line and buttons over them); there is no camera and nothing of any other
## screen in it.
func snapshot(width := 384) -> Dictionary:
	if not visible or size.x < 10.0:
		return {"error": "the room is not open"}
	if DisplayServer.get_name() == "headless":
		return {"error": "no frame drawn"}  # nothing is rendered (the dummy renderer would only complain)
	var frame := get_viewport().get_texture().get_image()
	if frame == null or frame.is_empty():
		return {"error": "no frame drawn"}  # headless: nothing is rendered
	var r := Rect2i(get_global_rect()).intersection(Rect2i(Vector2i.ZERO, frame.get_size()))
	if r.size.x < 10 or r.size.y < 10:
		return {"error": "nothing on screen"}
	var img := frame.get_region(r)
	var w := clampi(width, 128, 768)
	img.resize(w, maxi(1, int(round(float(r.size.y) * w / r.size.x))), Image.INTERPOLATE_BILINEAR)
	var jpg := img.save_jpg_to_buffer(0.75)
	_note("see  %dx%d" % [img.get_width(), img.get_height()])
	return {"jpg": Marshalls.raw_to_base64(jpg), "w": img.get_width(), "h": img.get_height(), "bytes": jpg.size()}

## The perform tool: a routine of the other tools' commands, each fired at
## its `at` (seconds from the start) by the same apply_* a single call uses;
## with `back` (the default) the face is put back as it was when it ends
## (`end` seconds). A new routine ends the one playing; `stop` ends it early.
func apply_perform(cmd: Dictionary) -> void:
	_perf_finish()
	if bool(cmd.get("stop", false)):
		_note("perform  stop")
		return
	var steps: Array = cmd.get("steps", [])
	_perf = steps.duplicate()
	_perf.sort_custom(func(a, b): return float(a.get("at", 0.0)) < float(b.get("at", 0.0)))
	_perf_t0 = _now
	_perf_end = _now + float(cmd.get("end", 0.0)) * 1000.0
	_perf_snap = _face_now() if bool(cmd.get("back", true)) else null
	_note("perform  %d steps · %ss" % [_perf.size(), cmd.get("end", 0)])

func _perf_fire(st: Dictionary) -> void:
	if st.get("move") is Dictionary:
		apply_move(st.move)
	if st.get("swarm") is Dictionary:
		apply_swarm(st.swarm)
	if st.get("dots") is Dictionary:
		apply_dots(st.dots)
	if st.get("tone") is Dictionary:
		apply_tone(st.tone)
	if st.get("draw") is Dictionary:
		apply_draw(st.draw)

func _perf_finish() -> void:
	_perf.clear()
	_perf_end = -1.0
	if _perf_snap == null:
		return
	var was: Dictionary = _perf_snap
	_perf_snap = null
	if _pic_on and not bool(was.pic):
		apply_draw({"clear": true})
	var place: Dictionary = was.place.duplicate()
	place.erase("seconds")
	apply_move(place.merged({"size": was.scale, "speed": was.speed}))
	var look: Dictionary = was.look.duplicate()
	look.erase("seconds")
	apply_swarm(look.merged({"eyes": was.eyes, "idle": was.idle}) if was.idle != "" else look.merged({"eyes": was.eyes}))
	apply_tone({"tone": "#" + (was.tone as Color).to_html(false), "intensity": was.inten})
	if _live_count() != int(was.dots):
		apply_dots({"total": int(was.dots)})
	_note("perform  back")

## How the face is now, for a routine to put back.
func _face_now() -> Dictionary:
	return {"place": _place.duplicate(), "look": _look.duplicate(), "idle": _idle, "tone": _tone_to, "inten": _inten_to,
		"eyes": _eyes_to, "scale": _scale_to, "speed": _speed, "dots": _live_count(), "pic": _pic_on}

## The tone tool: the swarm's `tone` (a name of TONES or "#rrggbb") and its
## `intensity` (0 invisible .. 1 as it is .. 1.8 blazing), either or both,
## eased in over about a second; `seconds` makes it a flash that goes back.
func apply_tone(cmd: Dictionary) -> Dictionary:
	if not cmd.has("tone") and not cmd.has("intensity"):
		return {"error": "pass tone, intensity, or both"}
	var to := _tone_to
	if cmd.has("tone"):
		var t := String(cmd.tone).strip_edges().to_lower()
		if TONES.has(t):
			to = TONES[t]
		elif t.trim_prefix("#").length() == 6 and t.trim_prefix("#").is_valid_hex_number():
			to = Color.html(t.trim_prefix("#"))
		else:
			return {"error": "tone is one of %s or #rrggbb" % ", ".join(TONES.keys())}
		if to.get_luminance() < 0.2:
			# Light on the dark: a tone too dark to glow is lifted.
			to = to.lightened(0.45)
	var inten := clampf(float(cmd.get("intensity", _inten_to)), INTENSITY[0], INTENSITY[1])
	_tone_back = null
	if cmd.has("seconds"):
		_tone_back = {"tone": _tone_to, "intensity": _inten_to}
		_tone_at = _now + float(cmd.seconds) * 1000.0
	_tone_to = to
	_inten_to = inten
	if Motion.reduce:
		_tone = to
		_inten = inten
	_note("tone  #%s  · %.1f" % [to.to_html(false), inten] + ("  · %ss" % cmd.seconds if cmd.has("seconds") else ""))
	return {"summary": "Done: my dots are #%s at %.1f" % [to.to_html(false), inten], "tone": "#" + to.to_html(false), "intensity": inten}

## The face's palette from the tone: every colour of the green set moved by
## the tone's turn of hue and scaled by its saturation and value against the
## green's, so green gives back the set exactly and white whitens it all.
func _palette() -> void:
	var dh := _tone.h - COL_P.h
	var fs := _tone.s / COL_P.s
	var fv := _tone.v / COL_P.v
	var shift := func(k: Color) -> Color:
		return Color.from_hsv(wrapf(k.h + dh, 0.0, 1.0), clampf(k.s * fs, 0.0, 1.0), clampf(k.v * fv, 0.0, 1.0))
	_cp = _tone
	_cph = shift.call(COL_PH)
	_cpd = shift.call(COL_PD)
	_ceye = shift.call(COL_EYE)
	_cacc1 = shift.call(COL_CYAN)
	_cacc2 = shift.call(COL_VIOLET)
	_room_mat.set_shader_parameter("tint", _cp)
	_rings_mat.set_shader_parameter("tint", _cp)
	_rings_mat.set_shader_parameter("hot", _cph)

func _to_cloud(i: int) -> void:
	_role[i] = Role.FREE
	_ang[i] = atan2((_y[i] - _c.y) / 0.48, _x[i] - _c.x)

## The picture comes apart and the face forms again out of every free dot.
func _clear_picture() -> void:
	for i in _hi:
		var r := _role[i]
		if r == Role.PIXEL or r == Role.BODY or r == Role.EYE:
			_to_cloud(i)
	_pic_on = false
	_pic_back_at = -1.0
	_become(BODY_N)
	_open_eyes(EYE_N)

func _live_count() -> int:
	var n := 0
	for i in _hi:
		if _role[i] != Role.DEAD and _dying[i] == Die.NO:
			n += 1
	return n

## The dots tool: `add` or `remove` that many, or make it `total`, between
## MIN_LIVE and CAP. New dots come `from` the face (a burst out of it, the
## default), the `edges` (drifting in) or a `point` (x, y from 0 to 1); dots
## go `to` nothing where they are (`fade`, the default), into the `face`, or
## off the `edges`. Cloud dots and wanderers go first, never the face's;
## while a picture shows, new dots fly into it and dots may leave it (it
## grows denser or sparser, never smaller).
func apply_dots(cmd: Dictionary) -> Dictionary:
	var live := _live_count()
	var want := live
	if cmd.has("total"):
		want = int(cmd.total)
	elif cmd.has("add"):
		want = live + int(cmd.add)
	elif cmd.has("remove"):
		want = live - int(cmd.remove)
	else:
		return {"error": "pass add, remove or total"}
	want = clampi(want, MIN_LIVE, CAP)
	var changed := 0
	if want > live:
		changed = _spawn(want - live, cmd)
	elif want < live:
		changed = -_despawn(live - want, cmd)
	var now_live := live + changed
	_note("dots  %+d  · %d" % [changed, now_live])
	return {"summary": "Done: %d dots now (%+d)" % [now_live, changed], "dots": now_live, "fewest": MIN_LIVE, "most": CAP}

func _spawn(n: int, cmd: Dictionary) -> int:
	var from := String(cmd.get("from", "face"))
	var made := 0
	var i := 0
	while made < n:
		while i < CAP and _role[i] != Role.DEAD:
			i += 1
		if i >= CAP:
			break
		var p: Vector2
		var v: Vector2
		match from:
			"edges":
				var t := randf()
				match randi() % 4:
					0: p = Vector2(t * size.x, -8.0)
					1: p = Vector2(t * size.x, size.y + 8.0)
					2: p = Vector2(-8.0, t * size.y)
					_: p = Vector2(size.x + 8.0, t * size.y)
				v = (_c - p).normalized() * randf_range(1.0, 2.5) * _u
			"point":
				p = Vector2(clampf(float(cmd.get("x", 0.5)), 0.0, 1.0) * size.x, clampf(float(cmd.get("y", 0.5)), 0.0, 1.0) * size.y)
				v = Vector2.from_angle(randf() * TAU) * randf_range(1.5, 6.0) * _u
			_:
				var a := randf() * TAU
				p = _c + Vector2.from_angle(a) * sqrt(randf()) * _R * 0.4
				v = Vector2.from_angle(a) * randf_range(2.0, 7.0) * _u
		_born(i, p, v)
		if _pic_on and not _pic_px.is_empty():
			var c := randi() % int(_pic_px.n)
			_role[i] = Role.PIXEL
			_lx[i] = _pic_px.x[c] + randf_range(-0.5, 0.5)
			_ly[i] = _pic_px.y[c] + randf_range(-0.5, 0.5)
			_pl[i] = _pic_px.l[c]
			_k[i] = randf_range(0.03, 0.065)
		if Motion.reduce:
			_life[i] = 1.0
		made += 1
		i += 1
	_dots.visible_instance_count = _hi
	return made

func _despawn(n: int, cmd: Dictionary) -> int:
	var to := String(cmd.get("to", "fade"))
	var mode := Die.FACE if to == "face" else (Die.OUT if to == "edges" else Die.FADE)
	# The newest go first, so the slots in use shrink back after a thinning.
	var pick := _free_shuffled()
	pick.sort()
	pick.reverse()
	if _pic_on:
		var inside := []
		for i in _hi:
			if _role[i] == Role.PIXEL and _dying[i] == Die.NO:
				inside.append(i)
		inside.sort()
		inside.reverse()
		pick.append_array(inside)
	n = mini(n, mini(_live_count() - MIN_LIVE, pick.size()))
	for j in maxi(n, 0):
		var i: int = pick[j]
		if Motion.reduce:
			# Under reduced motion they are simply gone.
			_role[i] = Role.DEAD
			_life[i] = 0.0
			continue
		_dying[i] = mode
		if mode == Die.OUT:
			var d := Vector2(_x[i], _y[i]) - _c
			if d.length() < 1.0:
				d = Vector2.RIGHT
			var out := _c + d.normalized() * size.length()
			_lx[i] = out.x
			_ly[i] = out.y
	return maxi(n, 0)

func _note(s: String) -> void:
	noted.emit(s)

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

# --- on a call: the screen drives the face ---

## On a call (true) the demos stop and the screen hands the face its state,
## line and level; off a call the face is the demo face again, waiting.
func set_live(on: bool) -> void:
	if on == live:
		return
	if on:
		_hush()
		_script = []
		demo_changed.emit()
	live = on
	_state = ""
	_voice = false
	_ext_level = 0.0
	_line = ""
	_words.visible_characters = -1

## The server's state: listening, thinking, speaking or remembering (which
## looks like thinking).
func set_state(name: String) -> void:
	match name:
		"speaking":
			_state = "speaking"
		"thinking", "remembering":
			_state = "thinking"
		"listening":
			_state = "listening"
			_listen_until = _now + 800.0
		_:
			_state = ""
	_voice = _state == "speaking"
	if _state != "listening":
		_last_active = _now

func state() -> String:
	return _state

## How loud the voice is, 0..1 (BotCall.level()), read while speaking.
func set_level(v: float) -> void:
	_ext_level = clampf(v, 0.0, 1.0)

## A line for the subtitles, shown from nothing; `reveal` uncovers it.
func say(text: String) -> void:
	_line = text
	_line_t = 0.0
	_words.visible_characters = 0

## How many characters of the line show (-1: all of it).
func reveal(n: int) -> void:
	_words.visible_characters = n if n < _line.length() else -1

func line() -> String:
	return _line

# --- the demos ---

func _say(key: String) -> void:
	# A beat of thought (eyes narrow) before the words come.
	_pending_say = key
	_think_t = 0.55
	_state = "thinking"

func _run_script(dt: float) -> void:
	if _think_t > 0.0:
		_think_t -= dt
		if _think_t <= 0.0:
			_line = tr(BotVoice.line_key(_pending_say))
			_line_t = 0.0
			_line_len = _line.length() / 16.0 + 0.3
			_start_voice(_pending_say)
			_state = "speaking"
			_voice = true
		return
	if _state == "speaking":
		_line_t += dt
		# A line that was voiced stays whole for its last beat.
		var shown := int(_line_t * 16.0) if _starts.is_empty() else -1
		var done := _line_t >= _line_len
		if _voiced:
			# The words appear as they are said, and the line ends with the clip.
			var at := _player.get_playback_position() + AudioServer.get_time_since_last_mix()
			shown = 0
			while shown < _starts.size() and _starts[shown] <= at:
				shown += 1
			if not _player.playing:
				shown = -1
				_voiced = false
				_line_len = _line_t + 0.25
			done = false
		_words.visible_characters = shown
		if done:
			_state = ""
			_voice = false
			_words.visible_characters = -1
			_step_wait = 1.1
		return
	if _script.is_empty():
		return
	if _step_wait > 0.0:
		_step_wait -= dt
		return
	if _step_i + 1 >= _script.size():
		_rest()
		return
	_step_i += 1
	var st: Dictionary = _script[_step_i]
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
	if st.has("dots"):
		apply_dots(st.dots)
	if st.has("draw"):
		apply_draw(st.draw)
	if st.has("tone"):
		apply_tone(st.tone)
	if st.has("say"):
		_say(String(st.say))
	elif st.has("wait"):
		_step_wait = float(st.wait)

## A demo (INTRO by default) from its first step, stopping whatever was
## playing (a pill pressed again starts its demo over). Not on a call, and
## not before the face has formed (false then).
func play_demo(demo: Array = INTRO) -> bool:
	if not _formed or live:
		return false
	_hush()
	_rest()
	_script = demo
	_step_i = -1
	_step_wait = 0.4
	_last_active = _now
	demo_changed.emit()
	return true

func is_formed() -> bool:
	return _formed

## The demo playing, or [] while the face waits.
func demo() -> Array:
	return _script

## The line being said stops where it is.
func _hush() -> void:
	_player.stop()
	_voiced = false
	_voice = false
	_think_t = 0.0
	_line = ""
	_words.visible_characters = -1
	if _state == "speaking" or _state == "thinking":
		_state = ""

## Back to the waiting face: no demo, no picture, N dots, centred, looking
## ahead, wandering when left alone.
func _rest() -> void:
	_script = []
	if _pic_on:
		apply_draw({"clear": true})
	var live := _live_count()
	if live > N:
		apply_dots({"total": N, "to": "face"})
	elif live < N:
		apply_dots({"total": N, "from": "edges"})
	if String(_place.get("to", "")) != "centre" or _visit_back != null:
		apply_move({"to": "centre"})
	if _tone_to != COL_P or _inten_to != 1.0 or _tone_back != null:
		apply_tone({"tone": "green", "intensity": 1.0})
	apply_swarm({"look": "ahead", "idle": "wander"})
	demo_changed.emit()

## The line's clip in the player's voice (BotVoice: language, accent of the
## phone's region, a woman's or a man's; the language's first accent when
## that one has none), and when each of its characters is said; without a
## clip the line is shown at a reading pace and the level is made up.
func _start_voice(key: String) -> void:
	_voiced = false
	_starts = PackedFloat32Array()
	var lang := TranslationServer.get_locale().substr(0, 2)
	if not BotVoice.ACCENTS.has(lang):
		lang = "en"
	var mine := BotVoice.voice_set(lang)
	for vs in [mine, "%s-%s-%s" % [lang, BotVoice.ACCENTS[lang][0], BotVoice.gender()]]:
		var stem := "%s_%s" % [key, vs]
		var path := VOICE_DIR + stem + ".mp3"
		if not ResourceLoader.exists(path):
			continue
		var t: Dictionary = _times.get(stem, {})
		if t.is_empty() or String(t.get("text", "")) != _line:
			continue  # audio under other words would not match
		_player.stream = load(path)
		_player.play()
		_voiced = true
		for v in t.get("starts", []):
			_starts.append(float(v))
		if _starts.is_empty():
			# No timings: spread the characters over the clip.
			var n := _line.length()
			var ln := _player.stream.get_length()
			for i in n:
				_starts.append(ln * i / maxf(n, 1.0))
		return

## How loud the voice is right now, 0..1: the clip's own loudness when one is
## playing, else syllables at the reveal's pace, quiet on spaces and stops.
func _voice_level() -> float:
	if live:
		if _state == "speaking":
			return _ext_level
		if _state == "thinking" and _pic_on:
			# Judging its own drawing: the picture murmurs, so it never looks frozen.
			return 0.0 if Motion.reduce else 0.1 + 0.08 * sin(_now / 320.0)
		return 0.0
	if _state != "speaking":
		return 0.0
	if _voiced and _spectrum != null:
		var m := _spectrum.get_magnitude_for_frequency_range(90.0, 4000.0)
		var db := linear_to_db(maxf(m.x, m.y))
		return clampf((db + 52.0) / 34.0, 0.0, 1.0)
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
	if _formed and not live:
		_run_script(dt)
	_acc += dt
	var steps := 0
	while _acc >= STEP and steps < 4:
		_acc -= STEP
		steps += 1
		_step()
	if steps == 4:
		_acc = 0.0
	_render(dt)

## Before the agent exists the dots are a loose field; then they are pulled
## together and become a face.
func _boot(dt: float) -> void:
	if _formed:
		return
	_boot_t += dt
	if _boot_t > 0.4:
		_gather = 1.0
	if _boot_t > 1.3:
		_become(BODY_N)
		_open_eyes(EYE_N)
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
	if _pic_on and _pic_back_at >= 0.0 and now >= _pic_back_at:
		_clear_picture()
		_note("draw  back to the face")
	_pic_k += ((1.0 if _pic_on else 0.0) - _pic_k) * 0.05
	if _eyes_back != null and now >= _eyes_at:
		_eyes_to = float(_eyes_back)
		_eyes_back = null
	if _perf_end >= 0.0:
		var t := (now - _perf_t0) / 1000.0
		while not _perf.is_empty() and float(_perf[0].get("at", 0.0)) <= t:
			_perf_fire(_perf.pop_front())
		if _perf.is_empty() and now >= _perf_end:
			_perf_finish()
	_eyes += (_eyes_to - _eyes) * 0.2
	_scale += (_scale_to - _scale) * (1.0 if Motion.reduce else 0.06)
	if _tone_back != null and now >= _tone_at:
		var back: Dictionary = _tone_back
		_tone_back = null
		_tone_to = back.tone
		_inten_to = back.intensity
		if Motion.reduce:
			_tone = _tone_to
			_inten = _inten_to
	# On a call, listening is the face's rest: the idle still comes when the
	# player goes quiet (the swarm tool's `idle`), the listening glow stays.
	if _state != "" and not (live and _state == "listening"):
		_last_active = now
	var was := _idle_now
	_idle_now = _idle != "" and now - _last_active > IDLE_MS
	if _idle_now and not was:
		_note("idle  " + _idle)
	if not _idle_now:
		_wander_until = 0.0
	if _state == "listening" and now > _listen_until and not live:
		_state = ""
	var target_level := _voice_level()
	_level += (target_level - _level) * 0.35

	if now > _blink_until + _next_blink and randf() < 0.02:
		_blink_until = now + 130.0
		_next_blink = randf_range(3800, 6500)
	var blink := now < _blink_until
	var dozing := 1.0 if (_idle_now and _idle == "doze") else 0.0
	_doze += (dozing - _doze) * (0.004 if _idle_now else 0.2)
	_eye_open += (((0.08 if blink else (0.32 if _state == "thinking" else 1.0)) * (1.0 - 0.72 * _doze) * _eyes) - _eye_open) * 0.3
	if _wink != 0.0 and now >= _wink_until:
		_wink = 0.0

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
	_cv = (_cv + (g - _c) * 0.0075 * _speed) * 0.875
	var cm := _cv.length()
	var top := 9.0 * u * _speed
	if cm > top:
		_cv *= top / cm
		cm = top
	_c += _cv
	var mvn := minf(1.0, cm / (6.0 * u))
	_travel += (mvn - _travel) * (0.08 if cm > _travel * 6.0 * u else 0.025)

	var breathe := 1.0 + 0.018 * sin(now / 1600.0)
	var fs := breathe
	if _state == "speaking":
		fs = breathe + 0.11 * _level
	elif _state == "thinking":
		fs = breathe * 0.97
	var sc := fs * _R * _scale
	var cx := _c.x
	var cy := _c.y
	var gx := _gaze.x
	var gy := _gaze.y
	var eo := _eye_open
	var mv := _travel
	var voice := _voice
	var env_lvl := minf(1.0, _level * 1.6)
	var gather := _gather
	# The sphere turns toward where it looks: a yaw and a pitch of the gaze
	# (y runs down the screen, so looking up is a negative gaze and a
	# positive pitch, which lifts the front of the sphere).
	var yaw := gx * 0.36
	var pitch := -gy * 0.28
	var cyw := cos(yaw)
	var syw := sin(yaw)
	var cpt := cos(pitch)
	var spt := sin(pitch)
	# The picture sits where the face would, and swells a little with the voice.
	var cell := _pic_cell() * (1.0 + 0.025 * _level)
	# The cloud stands back from a picture, its inner ring outside the picture.
	var push := 1.0 + _pic_k * maxf(0.0, Vector2(_pic_w, _pic_h).length() * 0.5 * _pic_cell() / (_R * 1.3) - 1.0)

	for i in _hi:
		var role := _role[i]
		if role == Role.DEAD:
			continue
		var dm := _dying[i]
		if dm != Die.NO:
			# Going: into the face, off the edges, or nothing where it is.
			var qvx := _vx[i]
			var qvy := _vy[i]
			if dm == Die.FACE:
				qvx = (qvx + (cx - _x[i]) * 0.02) * 0.9
				qvy = (qvy + (cy - _y[i]) * 0.02) * 0.9
			elif dm == Die.OUT:
				qvx = (qvx + (_lx[i] - _x[i]) * 0.004) * 0.95
				qvy = (qvy + (_ly[i] - _y[i]) * 0.004) * 0.95
			else:
				qvx *= 0.96
				qvy *= 0.96
			_x[i] += qvx
			_y[i] += qvy
			_vx[i] = qvx
			_vy[i] = qvy
			_life[i] -= STEP / (0.7 if dm == Die.FADE else 1.2)
			if _life[i] <= 0.0:
				_life[i] = 0.0
				_role[i] = Role.DEAD
				_dying[i] = Die.NO
			continue
		if _life[i] < 1.0:
			_life[i] = minf(1.0, _life[i] + STEP / FADE_IN)
		var px := _x[i]
		var py := _y[i]
		var vx := _vx[i]
		var vy := _vy[i]
		var tx: float
		var ty: float
		var k: float
		var damp: float
		var mx: float
		if role == Role.BODY:
			var ph := _ph[i]
			var lx := _lx[i]
			var ly := _ly[i]
			var lz := _z[i]
			var rx := lx * cyw + lz * syw
			var rz := lz * cyw - lx * syw
			var ry := ly * cpt - rz * spt
			tx = cx + rx * sc + sin(now / 700.0 + ph) * 0.9 * u
			ty = cy + ry * sc + cos(now / 900.0 + ph * 1.3) * 0.9 * u
			k = _k[i]
			damp = 0.8
			mx = 14.0 * u
		elif role == Role.EYE:
			var lx := _ex[i] * 0.17 + _lx[i] * 0.05
			var ly := 0.03 + _ly[i] * 0.19 * (eo * 0.08 if _wink == _ex[i] else eo)
			var lz := _z[i]
			var rx := lx * cyw + lz * syw
			var rz := lz * cyw - lx * syw
			var ry := ly * cpt - rz * spt
			tx = cx + rx * sc
			ty = cy + ry * sc
			k = _k[i]
			damp = 0.78
			mx = 14.0 * u
		elif role == Role.PIXEL:
			var ph3 := _ph[i]
			tx = cx + _lx[i] * cell + sin(now / 800.0 + ph3) * 0.35 * u
			ty = cy + _ly[i] * cell + cos(now / 950.0 + ph3) * 0.35 * u
			k = _k[i]
			damp = 0.8
			mx = 16.0 * u
		elif _formed and _uu[i] <= 0.86:
			# The cloud: atoms circling the face; when it travels the cloud
			# pulls in close and streams after it, inner atoms first.
			var ph2 := _ph[i]
			_ang[i] += _sp[i] * (2.2 if voice else 1.0)
			var env := 1.0
			if voice:
				env = 1.0 + 0.45 * env_lvl * (0.7 + 0.3 * absf(sin(now / 150.0 + ph2 * 0.2)))
			var rr := _R * _scale * _r[i] * (1.0 + 0.12 * sin(now / 1300.0 + ph2)) * env * push
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
	while _hi > 0 and _role[_hi - 1] == Role.DEAD:
		_hi -= 1

## Writes the dots and the lattice in one pass. Each dot gets its colour,
## twinkle and custom data (its shape, its focus, its fringe, its hot core),
## a streak along its velocity once it is fast; a body dot is shaded by its
## turned normal under the room's one light, soft and dim as it rolls away;
## a cloud atom is near or far by where it is on its orbit.
func _render(dt: float) -> void:
	_fit()
	# The tone eases toward where the tone tool set it.
	if not _tone.is_equal_approx(_tone_to) or absf(_inten - _inten_to) > 0.001:
		var e := minf(1.0, dt * 3.0)
		_tone = _tone.lerp(_tone_to, e)
		_inten += (_inten_to - _inten) * e
		if _tone.is_equal_approx(_tone_to):
			_tone = _tone_to
		_palette()
	var now := _now
	var reduce := Motion.reduce
	var u := _u
	var listening := _state == "listening"
	var halo_a := 0.2 if listening else (0.12 + 0.06 * _level)
	_halo.position = _c
	var hs := _R * _scale * 4.4 / 256.0
	_halo.scale = Vector2(hs, hs)
	_halo.modulate = Color(_cp, (halo_a if _formed else 0.0) * (1.0 - _pic_k) * _inten)
	_bloom_out.modulate.a = BLOOM_STRENGTH * minf(_inten, 1.4)
	if _formed:
		_rings_open = minf(1.0, _rings_open + dt / 1.4)
	var rs := _R * _scale * 3.8
	_rings_mat.set_shader_parameter("px", 1.0 / (_R * _scale))
	for rg in [_rings, _rings_bloom]:
		rg.position = _c
		rg.scale = Vector2(rs, rs)
	# Under reduced motion the rings stand still and no streak splits its colours.
	_rings_mat.set_shader_parameter("t", 0.0 if reduce else now / 1000.0)
	_rings_mat.set_shader_parameter("level", _level)
	_rings_mat.set_shader_parameter("open", _rings_open * (0.5 if reduce else 1.0) * (1.0 - _pic_k) * minf(_inten, 1.0))
	_room_mat.set_shader_parameter("centre", _c)
	_room_mat.set_shader_parameter("radius", _R * _scale)
	_room_mat.set_shader_parameter("level", _level)
	_room_mat.set_shader_parameter("lit", _rings_open * minf(_inten, 1.0))
	var cvx := _cv.x
	var cvy := _cv.y
	var yaw := _gaze.x * 0.36
	var pitch := -_gaze.y * 0.28
	var cyw := cos(yaw)
	var syw := sin(yaw)
	var cpt := cos(pitch)
	var spt := sin(pitch)
	var lxd := LIGHT.x
	var lyd := LIGHT.y
	var lzd := LIGHT.z
	var pdr := _cpd.r
	var pdg := _cpd.g
	var pdb := _cpd.b
	var phr := _cph.r
	var phg := _cph.g
	var phb := _cph.b
	var db := _dot_buf
	var cloud_dim := 1.0 - 0.7 * _pic_k
	for i in _hi:
		var role := _role[i]
		if role == Role.DEAD:
			# A slot between live ones draws nothing (and a reused slot never
			# shows the dot it held before).
			var oz := i * 16
			for q in 16:
				db[oz + q] = 0.0
			continue
		var tw := 0.65 + 0.35 * sin(now / 500.0 + _ph[i])
		var cr: float
		var cg: float
		var cb: float
		var alpha: float
		var kind := 0.0
		var soft := 0.0
		var hot := 0.0
		var grow := 1.0
		if role == Role.BODY:
			var lx := _lx[i]
			var ly := _ly[i]
			var lz := _z[i]
			var rx := lx * cyw + lz * syw
			var rz := lz * cyw - lx * syw
			var ry := ly * cpt - rz * spt
			var rz2 := ly * spt + rz * cpt
			var shade := clampf(rx * lxd + ry * lyd + rz2 * lzd, 0.0, 1.0)
			var k := (0.1 + 0.72 * shade) * _sh[i]
			cr = pdr + (phr - pdr) * k
			cg = pdg + (phg - pdg) * k
			cb = pdb + (phb - pdb) * k
			var near := clampf(rz2, 0.0, 1.0)
			alpha = _a[i] * (0.8 + 0.2 * tw) * (0.45 + 0.55 * near) * 0.85
			soft = (1.0 - near) * 0.8
			hot = shade * 0.4
			grow = 0.65 + 0.4 * near
			if _uu[i] < 0.26:
				# A node of the lattice: a crystal, a little bigger.
				kind = 0.5
				grow *= 1.3
				hot = shade * 0.6
		elif role == Role.EYE:
			cr = _ceye.r
			cg = _ceye.g
			cb = _ceye.b
			alpha = _a[i] * 0.8
			hot = 1.0
			grow = 1.15
		elif role == Role.PIXEL:
			# A dot of the picture: the swarm's own, in its tone, lit as
			# brightly as its pixel; a quarter are crystals, as on the face.
			# The shading is in how many dots crowd a pixel; their own light
			# varies only a little, and they are small and sharp so the
			# shape holds under the glow.
			var lum := _pl[i]
			var kp := 0.35 + 0.65 * lum
			cr = pdr + (phr - pdr) * kp
			cg = pdg + (phg - pdg) * kp
			cb = pdb + (phb - pdb) * kp
			alpha = (0.55 + 0.25 * _a[i]) * (0.8 + 0.2 * tw) * (0.6 + 0.4 * lum)
			soft = 0.05
			hot = 0.4 * lum
			grow = 0.6 + 0.3 * lum
			if _uu[i] < 0.26:
				kind = 0.5
				grow *= 1.15
		elif _formed and _uu[i] <= 0.86:
			var zf := sin(_ang[i])
			var near := maxf(zf, 0.0)
			var far := maxf(-zf, 0.0)
			var kn := 0.45 * near
			var kf := 0.4 * far
			cr = _cp.r + (_cacc1.r - _cp.r) * kn + (_cacc2.r - _cp.r) * kf
			cg = _cp.g + (_cacc1.g - _cp.g) * kn + (_cacc2.g - _cp.g) * kf
			cb = _cp.b + (_cacc1.b - _cp.b) * kn + (_cacc2.b - _cp.b) * kf
			alpha = _a[i] * tw * 0.85 * (0.7 + 0.3 * zf) * cloud_dim
			grow = (1.0 + 0.4 * zf) * (1.1 - 0.12 * (_r[i] - 1.3))
			if _s[i] > 1.6 and zf > 0.5:
				# Passing in front, close to the lens: a bokeh disc.
				kind = 1.0
				soft = 0.35 + 0.5 * near
				grow *= 1.8
				alpha *= 0.55
			else:
				soft = 0.3 * far
				hot = 0.5 * (1.0 - far)
		else:
			cr = _cp.r
			cg = _cp.g
			cb = _cp.b
			alpha = _a[i] * tw * 0.85
			if _uu[i] > 0.975:
				# A few far lights, out of focus, drifting across the room.
				kind = 1.0
				soft = 0.6
				grow = 5.0
				alpha *= 0.09
			else:
				soft = 0.5
				grow = 0.8
		var vx := _vx[i]
		var vy := _vy[i]
		var rvx := vx - cvx if role != Role.FREE else vx
		var rvy := vy - cvy if role != Role.FREE else vy
		var spd := sqrt(rvx * rvx + rvy * rvy)
		var d := _s[i] * u * 2.4 * grow
		alpha *= _life[i] * _inten
		var px := _x[i]
		var py := _y[i]
		var o := i * 16
		var ax := d
		var ay := 0.0
		var bx := 0.0
		var by := d
		var ox := px
		var oy := py
		var fringe := 0.0
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
			if not reduce:
				fringe = minf(1.0, (spd - 3.0 * u) / (9.0 * u))
		db[o] = ax
		db[o + 1] = bx
		db[o + 2] = 0.0
		db[o + 3] = ox
		db[o + 4] = ay
		db[o + 5] = by
		db[o + 6] = 0.0
		db[o + 7] = oy
		db[o + 8] = cr
		db[o + 9] = cg
		db[o + 10] = cb
		db[o + 11] = alpha
		db[o + 12] = kind
		db[o + 13] = soft
		db[o + 14] = fringe
		db[o + 15] = hot
	_dots.visible_instance_count = _hi
	_dots.buffer = db

	# The lattice: a thread from each body dot to its neighbour, flickering,
	# dim on the far side, and gone while the two are far apart (forming, or
	# streaming after a move).
	if _links_n > 0:
		var lb := _link_buf
		var sc := _R * _scale
		var wdt := 1.0 + 0.45 * u
		var lr := _cp.r + (_cph.r - _cp.r) * 0.6
		var lg := _cp.g + (_cph.g - _cp.g) * 0.6
		var lbl := _cp.b + (_cph.b - _cp.b) * 0.6
		for k in _links_n:
			var ia := _la[k]
			var ib := _lb[k]
			var x1 := _x[ia]
			var y1 := _y[ia]
			var dx := _x[ib] - x1
			var dy := _y[ib] - y1
			var ln := sqrt(dx * dx + dy * dy)
			var o := k * 12
			var ratio := ln / maxf(_ll[k] * sc, 1.0)
			var fade := clampf(2.0 - ratio, 0.0, 1.0)
			var depth := 0.25 + 0.75 * (_z[ia] + _z[ib]) * 0.5
			var flick := 0.6 + 0.4 * sin(now / 260.0 + _lph[k])
			var alpha := 0.5 * fade * depth * flick * _rings_open * (1.0 - _pic_k) * _inten
			if ln < 0.5:
				alpha = 0.0
				ln = 0.5
			var nx := -dy / ln * wdt
			var ny := dx / ln * wdt
			lb[o] = dx
			lb[o + 1] = nx
			lb[o + 2] = 0.0
			lb[o + 3] = x1 + dx * 0.5
			lb[o + 4] = dy
			lb[o + 5] = ny
			lb[o + 6] = 0.0
			lb[o + 7] = y1 + dy * 0.5
			lb[o + 8] = lr
			lb[o + 9] = lg
			lb[o + 10] = lbl
			lb[o + 11] = alpha
		_links.buffer = lb

	_words.text = _line
	var ww := minf(size.x - 80.0, 640.0)
	_words.size = Vector2(ww, 0)
	_words.reset_size()
	_words.size.x = ww
	# Subtitles stay put near the foot of the screen, wherever the face goes.
	_words.position = Vector2((size.x - ww) * 0.5, size.y - _insets.y - 170.0 - _words.size.y * 0.5)
	_words.modulate.a = 1.0 if _formed else 0.0
	_words.visible = subtitles

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
	if tap:
		tapped.emit(p, on_face(p))

## Whether `p` is on the face (or on the picture it is drawing).
func on_face(p: Vector2) -> bool:
	if _pic_on:
		var half := Vector2(_pic_w, _pic_h) * _pic_cell() * 0.5
		return absf(p.x - _c.x) <= half.x + 24.0 and absf(p.y - _c.y) <= half.y + 24.0
	return p.distance_to(_c) <= _R * _scale * 1.3

