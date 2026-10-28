extends "res://core/puzzle_base.gd"
## Yarn Hoop: a picture hidden on the linen of an embroidery hoop, cut into
## panels whose corners are pins. Drag a thread from pin to pin along a
## panel's side; a panel whose every side is threaded fills with knitting in
## its colour, and every panel filled is the picture
## (docs/agents/boards/hoop.md). The rules are puzzles/hoop_state.gd's.
##
## A `bleed` board (ui/flat/flat_host.gd): a sewing table is the whole
## screen, the hoop on it as big as the room between the pill and the foot
## allows, the picture inside it. A thread is laid only while the finger
## is held down, and breaks when it is let go. One drag can go on from pin
## to pin, and the panels it closes on the way are a combo: the bubble counts them and
## each one climbs a step.
##
## Drawn as `_bg` (the table), `_hoop` (the ring and its linen) and
## `_clamp` (the screw over the ring), the knitting in chunks of panels
## rebuilt when one fills, the threads, the pins and the panels' marks as a
## mesh each rebuilt when a thread is laid, and what moves (a panel knitting
## in, a pin popping off, the thread in hand) as one mesh a frame. No
## character: the pieces are marks.
##
## The whole table zooms (`zoom`, ui/flat/pan_zoom.gd; the user, 2026-10-14:
## "make sure it has zoom in and out properly"): two fingers pinch, the
## wheel zooms on a desk, the round button at the foot's left goes close and
## back out a step at a time, and a finger dragged from bare linen looks
## round a table seen close. The zoom is one transform over the same
## meshes; the pill and the bubble stay on the glass.

const State = preload("res://puzzles/hoop_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const Seal = preload("res://ui/flat/seal.gd")
const CozyTheme = preload("res://ui/theme.gd")
const PanZoom = preload("res://ui/flat/pan_zoom.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Progress = preload("res://core/progress.gd")

## The hoop: its room from the screen's sides, the ring's width, and the
## linen left round the picture inside it.
const SIDE := 26.0
const HUD_ROW := 76.0
const RING := 30.0
const INSET := 30.0
## A pin's head, and how near a finger has to come to one (a share of the
## shortest side between two pins, within the two bounds).
const PIN_R := 11.0
const PIN_R_MIN := 5.5
const SNAP := Vector2(24.0, 46.0)
const SNAP_SHARE := 0.45
## The magnet (the user, 2026-10-14: "some helper to help user when clicking
## near the dot to avoid miss click by requiring something too accurate"):
## past the snap, a finger still takes the nearest pin out to REACH (a share
## of the shortest side, within the bound) when that pin is clearly the
## nearest, REACH_CLEAR times nearer than the next; a halo on it says so
## while the finger is down. A drag let go short of a pin: only the pins a
## side joins to the pin held compete (`_target_at`), the nearest within
## the reach taken outright (the user, 2026-10-15: players "have to click
## exactly on the dot to connect after clicking on the start point").
const REACH_SHARE := 0.8
const REACH_MAX := 78.0
const REACH_CLEAR := 1.35
## On its way a drag takes only a pin it passes this near (a share of the
## snap): three pins all but in a line, and a straight drag to the far one
## would be taken by the middle one at the full snap.
const PASS_SHARE := 0.6
## A thread: its width at the most, and its twist a dash every TWIST
## pixels at that width. Chunky since 2026-10-28 (was 6, 0.13 of the
## shortest side): the reference's rope reads across the room, ours was a
## pencil line among the pins.
const YARN_W := 9.0
const ROPE_SHARE := 0.19
const TWIST := 12.0
## The knitting: a stitch's column width and row height on the screen, and
## the linen left between two panels.
## One V stitch on the table, px at 1x (the reference's are specks whole
## and read close up), the stitches a tile of the knit texture holds, and
## the texels across one.
const STITCH := Vector2(8.0, 6.0)
const TILE := Vector2i(4, 6)
const TEXEL := 32
## Each panel a shade of its own, so the picture reads as facets: this much
## lighter or darker than its colour, and this much from one side of the
## panel to the other.
const FACET := 0.13
const FACET_SLOPE := 0.08
const LIGHT := Vector2(-0.6, -0.8)
## Panels a chunk of the knitting's meshes.
const CHUNK := 10

## The table, the linen, the ring's wood, the yarn and the pins.
const TABLE := Color("efe4d3")
const TABLE_WEAVE := Color("e5d7c2")
const TABLE_CHECK := Color("f5ece0")
const LINEN := Color("fbf6ec")
const LINEN_WEAVE := Color("efe6d6")
const LINEN_SHADE := Color("e9dcc8")
const RING_WOOD := Color("d4a777")
const RING_DEEP := Color("a87a4f")
const RING_HI := Color("e9c79c")
const SCREW := Color("b58a5e")
const YARN := Color("b8664d")
const YARN_DEEP := Color("8e4634")
const YARN_HI := Color("d98c70")
const PIN := Color("6b5b8c")
const PIN_DEEP := Color("4d4068")
const PIN_HI := Color("a596c4")
const MARK := Color("6f604c")
## A panel's mark is how many of its sides are still to thread (its corner
## count until the first, since the made-fun pass of 2026-10-28: the
## board speaks as it is threaded, each lay ticking down the numbers on
## either side of it), written in a stitched numeral sized to the room
## about the panel's middle, this tall at the least and the most seen
## whole; the zoom scales it with the linen. It was 3.5-5.5 px from the
## user's 2026-10-14 "numbers should be really small" (on Insane's 300
## panels): specks no one read at the whole view of a phone, where the
## reference's numerals are as bold as its dots. Sized to the room, a
## crowded board's stay small and an open one's read; the ink takes the
## panel's colour as its sides are threaded, wholly at the last one.
const MARK_H := Vector2(6.0, 18.0)
const MARK_W := 0.21
const MARK_STROKE := 1.1
const MARK_ROOM := 0.65
## ... and never over MARK_SEEN px as the zoom shows it (close up on
## Insane, 18 px at 4x stood over the pins).
const MARK_SEEN := 24.0
## The darkest a numeral's ink may be lifted to, so a pale panel's still
## reads on the linen.
const MARK_LUM := 0.38
## A numeral ticking down swells and settles over MARK_TICK s.
const MARK_TICK := 0.32
## The numerals a panel can need (1 to 7 sides), as strokes in a box a
## unit tall: a 1 is a flag and a stem, a 4 a stem and a bent arm, a 7 a
## bar and a slope; the 2, 3, 5 and 6 have bows (`_glyph`).
const GLYPH_ONE := [[Vector2(0.14, 0.2), Vector2(0.44, 0.0), Vector2(0.44, 1.0)]]
const GLYPH_FOUR := [[Vector2(0.62, 0.0), Vector2(0.62, 1.0)], [Vector2(0.62, 0.0), Vector2(0.0, 0.66), Vector2(0.78, 0.66)]]
const GLYPH_SEVEN := [[Vector2(0.02, 0.0), Vector2(0.72, 0.0), Vector2(0.26, 1.0)]]
## The zoom: the round button's size and inset at the foot's left, how wide
## the shortest side between two pins comes to seen close, and the farthest
## the fingers may go.
const ZOOM_B := 84.0
const ZOOM_INSET := 12.0
const ZOOM_SIDE := 110.0
const ZOOM_NEAR := Vector2(1.6, 4.0)
const ZOOM_MOST := 5.0
## The table's dressing: balls of yarn, a needle.
const BALLS := [Color("e48a7a"), Color("8fb7a0"), Color("e9c46a")]

## This board's own motion (the rest is core/motion.gd's).
## A panel knits in from the side that closed it over FILL, a stitch popping
## in over STITCH_POP; FILL_PUSH is how far the panel swells as it fills.
const FILL := 0.42
const STITCH_POP := 0.14
const FILL_PUSH := 0.06
const PIN_GONE := 0.2
const THREAD_IN := 0.12
const SAG := 0.08
const HINT_BEAT := 0.45
const WIN_WAIT := 1.1
const PARTY_EXTRA := 0.6
const WIN_SLIDE := 0.5
const WAVE := 0.9
const STAMP_AT := 0.9
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.17
const STAMP_TILT := -0.22

## A combo: panels closed in one drag. Each one closed climbs a step of
## this scale (semitones, five at the most: docs/agents/sound.md, rule 2);
## the bubble shows from COMBO_FROM, and a drag that closed BIG_RUN ends on
## two notes and a sparkle.
const RUN_SCALE := [0, 2, 4, 5]
const COMBO_FROM := 2
const BIG_RUN := 3
const RUN_CONFETTI := 5
const STITCH_STEP := 0.5
const COMBO_DEFLATE := 0.25
const COMBO_HOLD := 1.1
const COMBO_FONT := 44
const PILL_FONT := 30
const PILL_H := 48.0
const TOAST_HOLD := 2.6
const TOAST_H := 66.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32

## What the phone does under each cue (docs/agents/haptics.md): a pin taken
## up a tick, a thread laid a tap, a panel filled a bump, two at once and a
## combo's end small yeses, a thread no panel has a warning.
const HAPTICS := {
	"pick": Haptics.TICK,
	"stitch": Haptics.TAP,
	"fill": Haptics.BUMP,
	"double": Haptics.GOOD,
	"run": Haptics.GOOD,
	"whole": Haptics.GOOD,
	"locked": Haptics.WARN,
	"reset": Haptics.TICK,
	"hint": Haptics.GOOD,
	"solved": Haptics.WIN,
}

var state = State.new()

var fx: Node2D
## The zoom over the table, and whether this board may zoom at all (the
## tutorial's small boards may not).
var zoom := PanZoom.new()
var zoomable := true
var _zoom_b: IconButton
var _pan_last := Vector2(-1.0, -1.0)

## The host reads these off every board; this one has neither hearts nor a
## move counter and cannot be lost.
var hearts := 0
var max_hearts := 0
var moves_left := 0
var max_moves := 0
var out_of_hearts := false

# layout
var _clear := Vector2.ZERO
var _won := false
var _centre := Vector2.ZERO
var _radius := 0.0
var _mid := Vector2.ZERO
var _k := 0.0
var _snap := 30.0
var _reach := 50.0
var _pin_r := PIN_R
## The rope's width on this cut: YARN_W, thinner on a fine cut (Insane's
## panels are 18-40 px, and a 6 px rope round each made a wire mesh of
## the picture).
var _rope_w := YARN_W
var _px := PackedVector2Array()
var _from_k := 0.0
var _from_centre := Vector2.ZERO
var _slid_at := -INF
var _gen := 0

# meshes
var _bg: ArrayMesh
var _hoop: ArrayMesh
var _clamp: ArrayMesh
var _threads: ArrayMesh
var _threads_stale := true
var _pins: ArrayMesh
var _pins_stale := true
var _marks: ArrayMesh
var _marks_stale := true
var _chunks := {}
var _chunk_stale := {}
## A panel's knitting, built once a layout: [verts, colours, indices, uvs]
## over the knit texture, lit as a facet.
var _knit := {}
## A side's rope, by side and colour (see `_yarn_part`).
var _yarn := {}
var _pin_part := []
## The zoom the table's meshes were built for: they are rebuilt at the zoom
## once it settles, so a feather stays Face.FEATHER screen pixels and a
## numeral's strokes stay strokes close up (built at 1x and scaled 4x, the
## feather was a 6 px blur and the 3s were blots; the user, 2026-10-15:
## "check why the game resolution is so terrible"). While fingers pinch
## the built meshes ride the transform.
var _built_k := 1.0
var _shown: Array = []
var _hud_layer: Control
var _hud_shown: ArrayMesh
var _hud_wide := -1.0
var _combo_shown: ArrayMesh
var _seal_mesh: ArrayMesh
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""

# what moves
var _filling := {}
var _gone := {}
var _laid_at := {}
var _shiver_at := {}
## Panels whose numeral just ticked down: when, drawn swelling over the
## still marks until MARK_TICK.
var _ticked := {}

# the hand
var _cur := -1
var _moved := false
var _finger := Vector2(-1.0, -1.0)
var _refused := -1
var _stroke := 0
var _stroke_threads := 0
var _best := 0
var _combo_n := 0
var _combo_at := -INF
var _combo_out_at := -INF
var _combo_popped := false
var _combo_pos := Vector2.ZERO
var _pill_bump := -INF
var _opened := -1.0e9
var _solved_at := -INF
var _stamp_at := INF
var _anim_until := 0.0
var _toast := ""
var _toast_at := -100.0
var _final_refused := 0

func puzzle_id() -> String: return "hoop"
func title() -> String: return "Yarn Hoop"

func rules() -> String:
	var out := tr("YH_RULES")
	out += "\n\n" + tr("YH_RULES_COMBO")
	out += "\n\n" + tr("YH_RULES_HOLD")
	if state.band >= State.INSANE:
		out += "\n\n" + tr("YH_RULES_INSANE")
	out += "\n\n" + tr("YH_RULES_ZOOM")
	return out

## The tutorial: each page is the board itself on a small hand-cut picture
## (ui/hud/hoop_tutorial_diagram.gd). Loaded, not preloaded: the page's
## board extends this script.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/hoop_tutorial_diagram.gd")
	var hints: int = State.hints_for(state.band)
	var steps := [
		[Diagram.Lesson.THREAD, "HTP_YH_THREAD", tr("HTP_YH_THREAD_BODY")],
		[Diagram.Lesson.FILL, "HTP_YH_FILL", tr("HTP_YH_FILL_BODY")],
		[Diagram.Lesson.COMBO, "HTP_YH_COMBO", tr("HTP_YH_COMBO_BODY")],
		[Diagram.Lesson.HOLD, "HTP_YH_HOLD", tr("HTP_YH_HOLD_BODY")]]
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_YH_HINT",
			tr("HTP_YH_HINT_BODY_ONE") if hints == 1 else tr("HTP_YH_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## The bulb on every band. No Undo (a thread is only ever taken along a
## panel's side, so nothing laid is wrong) and no Check: the bin is the way
## back.
func capabilities() -> Array[String]:
	return ["hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	# the knit tile repeats under every panel and is mipmapped, so it stays
	# even whole and sharp close up
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	fx = Fx2D.new()
	fx.haptics = HAPTICS
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_hud_layer = Control.new()
	_hud_layer.name = "Hud"
	_hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.z_index = 3
	_hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_layer.draw.connect(_draw_hud)
	add_child(_hud_layer)
	# The zoom button, over the table at the foot's left (the thumb's side
	# stays clear): its own size, in no container.
	_zoom_b = IconButton.new("plus", "", "IconButton")
	_zoom_b.name = "Zoom"
	_zoom_b.z_index = 1
	_zoom_b.visible = false
	_zoom_b.custom_minimum_size = Vector2(ZOOM_B, ZOOM_B)
	var up := CozyTheme.soft_button(Pal.SURFACE, int(ZOOM_B * 0.5), false, 0)
	var down := CozyTheme.soft_button(Pal.SURFACE, int(ZOOM_B * 0.5), true, 0)
	for st in ["normal", "hover", "disabled"]:
		_zoom_b.add_theme_stylebox_override(st, up)
	_zoom_b.add_theme_stylebox_override("pressed", down)
	_zoom_b.pressed.connect(zoom_button)
	add_child(_zoom_b)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	state.setup(rng, difficulty, daily_key if bank_step == 0 else 0)
	_best = 0
	_resume()
	_begin()

## The day as cut, for tools/export_days.gd (PuzzleBase.day_dict): the bead
## picture it was cut from, the pins and the panels ([colour, corners]).
func day_dict() -> Dictionary:
	if state.panels.is_empty():
		return {}
	var pins: Array = []
	for p in state.pins:
		pins.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
	var panels: Array = []
	var corners := [0, 0, 0, 0, 0]
	for k in state.panels.size():
		panels.append([state.colour[k], Array(state.panels[k])])
		corners[clampi((state.panels[k] as PackedInt32Array).size() - 3, 0, 4)] += 1
	var doubles := 0
	for sp in state.side_panels:
		if (sp as PackedInt32Array).size() == 2:
			doubles += 1
	return {
		"source": "bank" if state.name_key != "" else "generator", "kind": "text",
		"payload": {"picture": state.name_key, "w": state.w, "h": state.h, "colours": Array(state.colours),
			"pins": pins, "panels": panels},
		"solution": {"sides": state.sides.size()},
		"metrics": {"panels": state.panels.size(), "corners_3_to_7": corners, "pins": state.pins.size(),
			"sides": state.sides.size(), "shared_sides": doubles, "colours": state.colours.size(),
			"hints": State.hints_for(state.band)},
	}

func _begin() -> void:
	_won = false
	_solved_at = -INF
	_slid_at = -INF
	_stamp_at = INF
	_seal_mesh = null
	_deal()
	_layout()
	_enter()

func _deal() -> void:
	_cur = -1
	_refused = -1
	_stroke = 0
	_combo_n = 0
	_toast = ""
	_filling = {}
	_gone = {}
	_laid_at = {}
	_shiver_at = {}
	_ticked = {}
	_threads_stale = true
	_pins_stale = true
	_marks_stale = true
	_chunks = {}
	_chunk_stale = {}
	if _hud_layer != null:
		_hud_layer.queue_redraw()

## What the host's rows cover (a `bleed` board): the top and the foot, and
## on the win the span the win screen leaves, which the hoop slides to the
## middle of.
func set_clear(top: float, bottom: float, won := false) -> void:
	_clear = Vector2(top, bottom)
	if won and not _won and _k > 0.0:
		_from_k = _k
		_from_centre = _centre
		_slid_at = _now() if is_inside_tree() and _solved_at > _now() - 5.0 else -INF
	_won = won
	_layout()

func skip_entrance() -> void:
	_opened = _now() - 10.0

# --- layout ---

## The hoop as big as the room allows, the picture inside it as big as its
## pins farthest from its middle allow.
func _layout() -> void:
	if state.pins.is_empty() or size.x <= 0.0:
		return
	var top := _clear.x + (0.0 if _won else HUD_ROW)
	var foot := size.y - _clear.y
	_radius = minf(size.x * 0.5 - SIDE, (foot - top) * 0.5 - 6.0)
	_centre = Vector2(size.x * 0.5, (top + foot) * 0.5)
	var lo: Vector2 = state.pins[0]
	var hi: Vector2 = state.pins[0]
	for p in state.pins:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	_mid = (lo + hi) * 0.5
	var far := 0.01
	for p in state.pins:
		far = maxf(far, p.distance_to(_mid))
	_k = (_radius - RING - INSET) / far
	_px = PackedVector2Array()
	for p in state.pins:
		_px.append(_to_screen(p))
	var shortest := INF
	for s in state.sides:
		shortest = minf(shortest, _px[s.x].distance_to(_px[s.y]))
	_snap = clampf(shortest * SNAP_SHARE, SNAP.x, SNAP.y)
	_reach = clampf(shortest * REACH_SHARE, _snap, REACH_MAX)
	_pin_r = clampf(shortest * 0.16, PIN_R_MIN, PIN_R)
	_rope_w = clampf(shortest * ROPE_SHARE, 3.0, YARN_W)
	# the zoom's room is the whole table; close is the shortest side made
	# wide enough for a finger, within bounds; none once the day is won
	var near := clampf(ZOOM_SIDE / maxf(shortest, 1.0), ZOOM_NEAR.x, ZOOM_NEAR.y)
	if _won or not zoomable:
		near = 1.0
	zoom.setup(Rect2(Vector2.ZERO, size), near, maxf(near, ZOOM_MOST) if near > 1.0 else 1.0)
	_zoom_b.position = Vector2(ZOOM_INSET, size.y - _clear.y - ZOOM_INSET - ZOOM_B)
	_zoom_b.size = Vector2(ZOOM_B, ZOOM_B)
	_built_k = zoom.k
	_bg = _build_table()
	_hoop = _build_hoop()
	_clamp = _build_clamp()
	_knit = {}
	_yarn = {}
	_pin_part = []
	_chunks = {}
	_chunk_stale = {}
	_threads_stale = true
	_pins_stale = true
	_marks_stale = true
	_seal_mesh = null
	_hud_layer.queue_redraw()
	_request()

func _to_screen(p: Vector2) -> Vector2:
	return _centre + (p - _mid) * _k

## Control-local point of pin `v`, wherever the zoom has it. The harnesses
## press these.
func pin_screen(v: int) -> Vector2:
	return zoom.to_screen(_px[v]) if v < _px.size() else Vector2.ZERO

## A panel's middle on the table as laid out (the meshes' coordinates).
func panel_screen(k: int) -> Vector2:
	return _to_screen(state.centre(k))

## A point of the table as laid out, where the zoom shows it: the fx and
## the bubble are on the glass.
func _at(p: Vector2) -> Vector2:
	return zoom.to_screen(p)

func _zoom_button_wanted() -> bool:
	return zoom.enabled and not _won and _solved_at == -INF and not is_done()

## The zoom button: whole, half way, close, and back out a step at a time.
func zoom_button() -> void:
	zoom.cycle()
	_request()

func _outline_px(k: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in state.panels[k]:
		out.append(_px[v])
	return out

# --- the meshes ---

## The sewing table: oat cloth, a faint check, balls of yarn and a needle
## where the hoop leaves the cloth bare.
func _build_table() -> ArrayMesh:
	var b := Face.Builder.new()
	b.fan(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]), TABLE)
	var step := 120.0
	var x := -step * 0.5
	while x < size.x + step:
		b.fan(PackedVector2Array([Vector2(x, 0.0), Vector2(x + step * 0.5, 0.0), Vector2(x + step * 0.5, size.y), Vector2(x, size.y)]), Color(TABLE_CHECK, 0.55))
		x += step
	var y := -step * 0.5
	while y < size.y + step:
		b.fan(PackedVector2Array([Vector2(0.0, y), Vector2(size.x, y), Vector2(size.x, y + step * 0.5), Vector2(0.0, y + step * 0.5)]), Color(TABLE_WEAVE, 0.45))
		y += step
	# the hoop's shadow on the cloth
	b.ellipse(_centre + Vector2(0.0, 14.0), _radius + 10.0, _radius + 6.0, Color(Pal.OUTLINE, 0.08))
	# the dressing, in the corners the hoop leaves
	var room := size.y - (_centre.y + _radius)
	if room > 150.0 and not _won:
		var foot_y := _centre.y + _radius + room * 0.5
		_ball(b, Vector2(size.x * 0.2, foot_y), minf(56.0, room * 0.3), BALLS[0])
		_ball(b, Vector2(size.x * 0.82, foot_y + 10.0), minf(44.0, room * 0.24), BALLS[1])
		_needle(b, Vector2(size.x * 0.42, foot_y + 22.0), Vector2(size.x * 0.66, foot_y - 26.0))
	return b.mesh()

## A ball of yarn: a disc and its wraps.
func _ball(b, at: Vector2, r: float, col: Color) -> void:
	b.ellipse(at + Vector2(0.0, r * 0.82), r * 0.95, r * 0.28, Color(Pal.OUTLINE, 0.1))
	b.disc(at, r, col)
	for k in 5:
		var a := -0.9 + k * 0.42
		var pts := Face.Builder.arc_points(at + Vector2.from_angle(a + PI) * r * 0.55, r * 1.05, a - 0.75, a + 0.75)
		var inside := PackedVector2Array()
		for p in pts:
			if p.distance_to(at) < r * 0.96:
				inside.append(p)
		if inside.size() > 1:
			b.stroke(inside, 2.6, col.darkened(0.18))
	b.disc(at + Vector2(-r * 0.35, -r * 0.4), r * 0.18, Color(col.lightened(0.35), 0.6))
	# its loose end across the cloth
	var tail := Face.Builder.bezier2(at + Vector2(r * 0.7, r * 0.6), at + Vector2(r * 1.8, r * 1.4), at + Vector2(r * 2.6, r * 0.9))
	b.stroke(tail, 3.0, col.darkened(0.08))

func _needle(b, from: Vector2, to: Vector2) -> void:
	var d := (to - from).normalized()
	var n := Vector2(-d.y, d.x)
	b.fan(PackedVector2Array([from - n * 3.0, to, from + n * 3.0, from - d * 6.0]), Color("c9c2b6"))
	b.stroke(PackedVector2Array([from + d * 6.0, from + d * 14.0]), 2.0, Color(TABLE, 0.9))
	var tail := Face.Builder.bezier2(from + d * 8.0, from - d * 50.0 + n * 40.0, from - d * 20.0 + n * 90.0)
	b.stroke(tail, 3.0, YARN)

## The ring and the linen stretched in it, with its weave.
func _build_hoop() -> ArrayMesh:
	var b := _builder()
	b.disc(_centre, _radius, RING_DEEP)
	b.disc(_centre + Vector2(0.0, -2.0), _radius - 3.0, RING_WOOD)
	var hi := Face.Builder.arc_points(_centre, _radius - RING * 0.3, PI * 1.1, PI * 1.75)
	b.stroke(hi, 4.0, Color(RING_HI, 0.8))
	var inner := _radius - RING
	b.disc(_centre, inner + 3.0, Color(RING_DEEP, 0.9))
	b.disc(_centre, inner, LINEN)
	# the weave: faint threads both ways, kept inside the ring
	var gap := 16.0
	var y := _centre.y - inner + gap
	while y < _centre.y + inner:
		var half := sqrt(maxf(0.0, inner * inner - (y - _centre.y) * (y - _centre.y))) - 2.0
		if half > 4.0:
			b.fan(PackedVector2Array([Vector2(_centre.x - half, y), Vector2(_centre.x + half, y), Vector2(_centre.x + half, y + 1.4), Vector2(_centre.x - half, y + 1.4)]), LINEN_WEAVE)
		y += gap
	var x := _centre.x - inner + gap
	while x < _centre.x + inner:
		var half := sqrt(maxf(0.0, inner * inner - (x - _centre.x) * (x - _centre.x))) - 2.0
		if half > 4.0:
			b.fan(PackedVector2Array([Vector2(x, _centre.y - half), Vector2(x + 1.4, _centre.y - half), Vector2(x + 1.4, _centre.y + half), Vector2(x, _centre.y + half)]), Color(LINEN_WEAVE, 0.7))
		x += gap
	# the linen dips a little into the ring at its edge
	var shade := Face.Builder.arc_points(_centre, inner - 5.0, 0.0, TAU)
	b.stroke(shade, 10.0, Color(LINEN_SHADE, 0.6), true)
	return b.mesh()

## The ring's screw at the top, over everything on the linen.
func _build_clamp() -> ArrayMesh:
	var b := _builder()
	var top := _centre + Vector2(0.0, -_radius)
	b.polygon(Face.Builder.round_rect(top + Vector2(-26.0, -14.0), Vector2(52.0, RING + 10.0), 8.0), RING_DEEP)
	b.polygon(Face.Builder.round_rect(top + Vector2(-23.0, -12.0), Vector2(46.0, RING + 4.0), 7.0), RING_WOOD)
	b.polygon(Face.Builder.round_rect(top + Vector2(-9.0, -40.0), Vector2(18.0, 30.0), 5.0), SCREW)
	b.disc(top + Vector2(0.0, -44.0), 15.0, RING_DEEP)
	b.disc(top + Vector2(0.0, -46.0), 13.0, SCREW)
	b.stroke(PackedVector2Array([top + Vector2(-7.0, -46.0), top + Vector2(7.0, -46.0)]), 3.0, RING_DEEP)
	return b.mesh()

## The knit: one tile of V stitches drawn once into a texture (grey, the
## panel's colour multiplied in as vertex colour) and laid under every
## filled panel through its UVs, so a chunk of panels is still one draw
## call, the stitches are as fine as a real knit's and they stay sharp
## close up (the tile repeats and is mipmapped). Each stitch is two plump
## leaves meeting at the foot, its point tucked between the arms of the
## one below, as stockinette lies; the groove between leaves is dark.
static var _knit_tex: ImageTexture

static func knit_texture() -> ImageTexture:
	if _knit_tex != null:
		return _knit_tex
	var cw := float(TEXEL)
	var tw := TILE.x * TEXEL
	var th := int(round(cw * STITCH.y / STITCH.x * TILE.y))
	var rh := float(th) / TILE.y
	var img := Image.create(tw, th, true, Image.FORMAT_RGBA8)
	# each arm a leaf, slim at its top and plump at the foot, the V's foot
	# reaching a third of the way into the row below, where it lies over
	# the slim tops of that row's arms, as a knit does (arms of one width
	# stopping at their own row left the valleys a field of dark
	# arrowheads, and plump ones merged across the columns into a chevron
	# weave)
	var r_top := cw * 0.11
	var r_foot := cw * 0.3
	var light := LIGHT.normalized()
	var leaves := [[Vector2(0.17, -0.02), Vector2(0.5, 1.3)], [Vector2(0.83, -0.02), Vector2(0.5, 1.3)]]
	for y in th:
		for x in tw:
			var p := Vector2(fmod(x + 0.5, cw), fmod(y + 0.5, rh))
			var inside := 0.0
			var ridge := 0.0
			for dy in [-2.0, -1.0, 0.0, 1.0]:
				var o := Vector2(0.0, dy * rh)
				for leaf: Array in leaves:
					var a: Vector2 = Vector2(leaf[0].x * cw, leaf[0].y * rh) + o
					var b: Vector2 = Vector2(leaf[1].x * cw, leaf[1].y * rh) + o
					var q := Geometry2D.get_closest_point_to_segment(p, a, b)
					var along := (q - a).length() / maxf((b - a).length(), 0.001)
					var r := lerpf(r_top, r_foot, along)
					var d := 1.0 - q.distance_to(p) / r
					if d > inside:
						inside = d
						# the light on a leaf's upper left side
						ridge = (p - q).normalized().dot(light)
			# the groove is only a little darker than a leaf's edge: whole,
			# the knit is an even grain, not a grid of dots
			var v := 0.56
			if inside > 0.0:
				var round_ := sqrt(clampf(inside, 0.0, 1.0))
				v = lerpf(0.68, 1.0, round_) + 0.05 * ridge * (1.0 - round_)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	img.generate_mipmaps()
	_knit_tex = ImageTexture.create_from_image(img)
	return _knit_tex

## Panel `k`'s knitting, built once a layout: its outline over the knit
## tile, lit as a facet: a shade of its own (FACET, by its index) and a
## slope across it toward the light (FACET_SLOPE), so neighbours of one
## colour read as the low-poly picture's planes.
func _knit_part(k: int) -> Array:
	if _knit.has(k):
		return _knit[k]
	var outline := _outline_px(k)
	var base: Color = State.ink(state.colours[state.colour[k]])
	# the tile is grey about 0.8, so the colour is lifted to read true
	base = base.lightened(0.12)
	# a drawn picture's facets are already shaded by the drawing
	var h := 0.0 if state.drawn else float((k * 2654435761) % 1000) / 500.0 - 1.0
	var lit := base.lightened(FACET * h) if h > 0.0 else base.darkened(FACET * -h)
	var c := Vector2.ZERO
	for p in outline:
		c += p
	c /= outline.size()
	var reach := 1.0
	for p in outline:
		reach = maxf(reach, p.distance_to(c))
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var span := Vector2(STITCH.x * TILE.x, STITCH.y * TILE.y)
	var light := LIGHT.normalized()
	for p in outline:
		verts.append(p)
		var slope := (p - c).dot(light) / reach * FACET_SLOPE
		cols.append(lit.lightened(slope) if slope > 0.0 else lit.darkened(-slope))
		uvs.append(Vector2(p.x / span.x, p.y / span.y))
	var idx := Geometry2D.triangulate_polygon(outline)
	var part := [verts, cols, idx, uvs]
	_knit[k] = part
	return part

## A side's thread: the player's terracotta yarn while it lies on bare
## linen, and once a panel beside it is knitted, a rope in that panel's
## colour, lighter than the knit, with its twist (the reference's panels
## are rimmed so). `colour` -1 is the player's yarn.
func _yarn_part(s: int, colour: int) -> Array:
	# a drawn picture can hold a colour a panel, a few hundred
	var key := s * 1024 + colour + 1
	if _yarn.has(key):
		return _yarn[key]
	var a := _px[state.sides[s].x]
	var c := _px[state.sides[s].y]
	var b := _builder()
	_rope_into(b, a, c, colour)
	var part := [b.verts, b.cols, b.idx]
	_yarn[key] = part
	return part

## The rope's body and twist colours for a panel colour, or the yarn's.
func _rope_colours(colour: int) -> Array:
	if colour < 0:
		return [YARN, Color(YARN_DEEP, 0.7)]
	var base: Color = State.ink(state.colours[colour])
	return [base.lightened(0.3), Color(base.darkened(0.25), 0.55)]

func _rope_into(b, a: Vector2, c: Vector2, colour: int) -> void:
	var cols := _rope_colours(colour)
	var body: Color = cols[0]
	var deep: Color = cols[1]
	var w := _rope_w
	var twist := TWIST * w / YARN_W
	b.stroke(PackedVector2Array([a + Vector2(1.0, 2.0), c + Vector2(1.0, 2.0)]), w + 1.0, Color(Pal.OUTLINE, 0.16))
	b.stroke(PackedVector2Array([a, c]), w, body)
	var d := (c - a)
	var n := d.length()
	if n > 0.0:
		var u := d / n
		var v := Vector2(-u.y, u.x)
		var t := twist * 0.5
		while t < n - twist * 0.3:
			var p := a + u * t
			b.stroke(PackedVector2Array([p - v * w * 0.4 - u * w * 0.33, p + v * w * 0.4 + u * w * 0.33]), maxf(0.9, w * 0.23), deep, false, false)
			t += twist

## A knot where a pin has popped off: the rope's end tied, in the colour of
## a panel knitted beside it (the yarn's while none is).
func _knot_into(b, at: Vector2, colour: int) -> void:
	var cols := _rope_colours(colour)
	var body: Color = cols[0]
	var deep: Color = cols[1]
	var r := _rope_w * 0.95
	b.disc(at + Vector2(1.0, 1.5), r, Color(Pal.OUTLINE, 0.16))
	b.disc(at, r, deep)
	b.disc(at + Vector2(-0.3, -0.5), r * 0.8, body)
	b.disc(at + Vector2(-r * 0.3, -r * 0.35), r * 0.28, Color(body.lightened(0.4), 0.8))

## The colour a side's rope takes: of a panel beside it that is knitted
## (the first), -1 for the yarn.
func _side_colour(s: int) -> int:
	for k in state.side_panels[s]:
		if state.filled[k] and not _filling.has(k):
			return state.colour[k]
	return -1

## The colour a pin's knot takes: of a panel knitted at it, -1 for none.
func _pin_colour(v: int) -> int:
	for s in state.pin_sides[v]:
		var c := _side_colour(s)
		if c >= 0:
			return c
	return -1

## A pin: its shadow, its head and the light on it.
func _pin_into(b, at: Vector2, r: float) -> void:
	b.disc(at + Vector2(1.5, 2.5), r, Color(Pal.OUTLINE, 0.18))
	b.disc(at, r, PIN_DEEP)
	b.disc(at + Vector2(-0.4, -0.6), r * 0.82, PIN)
	b.disc(at + Vector2(-r * 0.3, -r * 0.32), r * 0.3, PIN_HI)

## Panel `k`'s mark: the sides it still wants threaded, stitched about
## its middle in the mark's ink turning to the panel's colour as its sides
## are laid (wholly at the last one), sized to the room the panel has about
## that middle and never under MARK_H.x: a cramped panel's may touch its
## sides, but every panel says its count. `swell` scales it (a numeral
## ticking down). A count with no numeral (none is cut) gets a dot a side.
func _mark_into(b, k: int, swell := 1.0) -> void:
	var outline := _outline_px(k)
	var n := outline.size()
	var left: int = state.open_sides[k]
	var c := _mark_at(outline)
	# the room: the nearest side
	var room := INF
	for m in n:
		room = minf(room, Geometry2D.get_closest_point_to_segment(c, outline[m], outline[(m + 1) % n]).distance_to(c))
	var tall := minf(clampf(room * MARK_ROOM, MARK_H.x, MARK_H.y), MARK_SEEN / _built_k) * swell
	var wide := maxf(MARK_STROKE / _built_k, tall * MARK_W)
	var ink := MARK
	if left < n:
		var own: Color = State.ink(state.colours[state.colour[k]]).darkened(0.22)
		# a pale panel's (cream, white) would sink into the linen
		var lum := own.get_luminance()
		if lum > MARK_LUM:
			own = own.darkened(1.0 - MARK_LUM / lum)
		ink = MARK.lerp(own, 1.0 if left <= 1 else float(n - left) / float(n - 1))
	var strokes := _glyph(left)
	if strokes.is_empty():
		for m in left:
			b.disc(c + Vector2.from_angle(TAU * m / maxf(1.0, left)) * tall * 0.45, 3.0, ink)
		return
	for stroke: Array in strokes:
		var pts := PackedVector2Array()
		for q: Vector2 in stroke:
			pts.append(c + (q - Vector2(0.36, 0.5)) * tall)
		b.stroke(pts, wide, ink)

## Numeral `n` as strokes in a box a unit tall, about (0.36, 0.5); [] for
## a count no panel is cut with.
static func _glyph(n: int) -> Array:
	match n:
		1:
			return GLYPH_ONE
		2:
			# a bow over the top, a slope down to the foot and the foot
			var bow := Array(Face.Builder.arc_points(Vector2(0.36, 0.3), 0.29, PI * 1.08, PI * 2.18))
			bow.append(Vector2(0.04, 1.0))
			bow.append(Vector2(0.74, 1.0))
			return [bow]
		3:
			# two bows, the top one a little smaller, open to the left
			var r := 0.26
			var top := Face.Builder.arc_points(Vector2(0.36, r), r, PI * 1.15, PI * 2.5)
			var low := Face.Builder.arc_points(Vector2(0.36, 1.0 - r), r, PI * 1.5, PI * 2.85)
			return [Array(top), Array(low)]
		4:
			return GLYPH_FOUR
		5:
			# a flag, a short stem and a bow open to the left
			var bow := Face.Builder.arc_points(Vector2(0.34, 0.65), 0.33, PI * 1.2, PI * 2.8)
			return [[Vector2(0.66, 0.0), Vector2(0.1, 0.0), Vector2(0.07, 0.46)], Array(bow)]
		6:
			# a sweep down the left into a closed loop
			var loop := Face.Builder.arc_points(Vector2(0.36, 0.69), 0.3, 0.0, TAU)
			return [[Vector2(0.62, 0.02), Vector2(0.3, 0.12), Vector2(0.11, 0.4), Vector2(0.06, 0.69)], Array(loop)]
		7:
			return GLYPH_SEVEN
	return []

## Where a panel's mark sits: the panel's centre of area (the user,
## 2026-10-14: "the number should always stay at the center of the region
## it's indicating"; a triangle's incentre until then, which on a thin
## panel sat by its wide corner). A quad's corners are weighed by area,
## not just averaged, so a kite's mark is in its body.
func _mark_at(outline: PackedVector2Array) -> Vector2:
	var n := outline.size()
	var c := Vector2.ZERO
	var twice := 0.0
	for i in n:
		var p := outline[i]
		var q := outline[(i + 1) % n]
		var cross := p.cross(q)
		c += (p + q) * cross
		twice += cross
	if absf(twice) < 1e-6:
		for p in outline:
			c += p
		return c / n
	return c / (3.0 * twice)

## A Builder for the meshes drawn under the zoom, feathered and rounded
## for the zoom they are built at (`_built_k`).
func _builder() -> Face.Builder:
	var b := Face.Builder.new()
	b.feather = Face.FEATHER / _built_k
	b.detail = _built_k
	return b

## Parts [verts, colours, indices] (and uvs, for the knitting) as one mesh.
func _combine(parts: Array) -> ArrayMesh:
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var uvs := PackedVector2Array()
	for part: Array in parts:
		var first := verts.size()
		var ix: PackedInt32Array = part[2]
		if first > 0:
			ix = ix.duplicate()
			for m in ix.size():
				ix[m] += first
		verts.append_array(part[0])
		cols.append_array(part[1])
		idx.append_array(ix)
		if part.size() > 3:
			uvs.append_array(part[3])
	if idx.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	if uvs.size() == verts.size():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

func _threads_mesh() -> ArrayMesh:
	if not _threads_stale:
		return _threads
	_threads_stale = false
	var parts: Array = []
	for s in state.sides.size():
		if not state.laid[s] or _laid_at.has(s):
			continue
		parts.append(_yarn_part(s, _side_colour(s)))
	_threads = _combine(parts)
	return _threads

func _pins_mesh() -> ArrayMesh:
	if not _pins_stale:
		return _pins
	_pins_stale = false
	var b := _builder()
	for v in state.pins.size():
		if state.pin_live[v] > 0:
			_pin_into(b, _px[v], _pin_r)
		elif not _gone.has(v):
			_knot_into(b, _px[v], _pin_colour(v))
	_pins = b.mesh() if not b.idx.is_empty() else null
	return _pins

func _marks_mesh() -> ArrayMesh:
	if not _marks_stale:
		return _marks
	_marks_stale = false
	_marks = null
	var b := _builder()
	for k in state.panels.size():
		if not state.filled[k] and not _ticked.has(k):
			_mark_into(b, k)
	_marks = b.mesh() if not b.idx.is_empty() else null
	return _marks

func _chunk_mesh(c: int) -> ArrayMesh:
	if _chunks.has(c) and not _chunk_stale.has(c):
		return _chunks[c]
	_chunk_stale.erase(c)
	var parts: Array = []
	for k in range(c * CHUNK, mini(state.panels.size(), (c + 1) * CHUNK)):
		if state.filled[k] and not _filling.has(k):
			parts.append(_knit_part(k))
	_chunks[c] = _combine(parts)
	return _chunks[c]

# --- the drawing ---

## The hoop's slide to the win's span: where it was played, to where it is.
func _slide_xf(now: float) -> Transform2D:
	var e := now - _slid_at
	if Motion.reduce or e >= WIN_SLIDE or _from_k <= 0.0 or _k <= 0.0:
		return Transform2D.IDENTITY
	var u := clampf(e / WIN_SLIDE, 0.0, 1.0)
	var s := u * u * (3.0 - 2.0 * u)
	var r := lerpf(_from_k / _k, 1.0, s)
	var at := (_from_centre - _centre * (_from_k / _k)).lerp(Vector2.ZERO, s)
	return Transform2D(0.0, Vector2(r, r), 0.0, at)

func _draw() -> void:
	if _k <= 0.0 or _bg == null:
		return
	var now := _now()
	var shown: Array = [_bg]
	draw_mesh(_bg, null)
	var since := now - _opened - Motion.ENTER_DELAY
	var xf := _slide_xf(now)
	var k := 1.0
	if not Motion.reduce and since < Motion.ENTER_POP:
		k = Motion.wide_pop_scale(maxf(0.0, since))
	# the win: the whole picture swells once
	if _solved_at > -INF and not Motion.reduce:
		var w := now - _solved_at - FILL
		if w > 0.0 and w < WAVE:
			k *= 1.0 + 0.05 * sin(PI * w / WAVE)
	if k != 1.0:
		xf = xf * Transform2D(0.0, Vector2(k, k), 0.0, _centre - _centre * k)
	xf = zoom.xf() * xf
	draw_set_transform_matrix(xf)
	var alpha := 1.0 if Motion.reduce else Motion.appear_level(since + Motion.ENTER_DELAY)
	draw_mesh(_hoop, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	shown.append(_hoop)
	var knit := knit_texture()
	for c in ceili(float(state.panels.size()) / CHUNK):
		var m := _chunk_mesh(c)
		if m != null:
			draw_mesh(m, knit)
			shown.append(m)
	var marks := _marks_mesh()
	if marks != null and _solved_at == -INF:
		draw_mesh(marks, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
		shown.append(marks)
	var threads := _threads_mesh()
	if threads != null:
		draw_mesh(threads, null)
		shown.append(threads)
	var moving: Array = _moving_meshes(now, since)
	if moving[0] != null:
		draw_mesh(moving[0], knit)
		shown.append(moving[0])
	if moving[1] != null:
		draw_mesh(moving[1], null)
		shown.append(moving[1])
	if not _entering(since):
		var pins := _pins_mesh()
		if pins != null:
			draw_mesh(pins, null)
			shown.append(pins)
	if moving[2] != null:
		draw_mesh(moving[2], null)
		shown.append(moving[2])
	draw_mesh(_clamp, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	shown.append(_clamp)
	if _stamp_at <= now:
		_draw_stamp(now, shown, xf)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_shown = shown

func _entering(since: float) -> bool:
	return not Motion.reduce and since < Motion.ENTER_POP * 0.5 + Motion.stagger(state.pins.size(), Motion.ENTER_STAGGER, 0.8) + Motion.POP_IN

## What moves, as three meshes a frame, two under the still pins and one
## over them: under, the panels knitting in (over the knit texture), then
## the pins while they pop in (the still ones are `_pins` after) and the
## threads being laid; over, the pins popping off, a refused pin's ring and
## the thread in hand.
func _moving_meshes(now: float, since: float) -> Array:
	var parts: Array = []
	var b := _builder()
	if _entering(since):
		for v in state.pins.size():
			if state.pin_live[v] <= 0:
				continue
			var e := since - Motion.ENTER_POP * 0.5 - Motion.stagger(_enter_order(v), Motion.ENTER_STAGGER, 0.8)
			if e <= 0.0:
				continue
			_pin_into(b, _px[v], _pin_r * Motion.pop_in_scale(e).x)
	# the panels knitting in, from the side that closed them
	for kk: int in _filling.keys():
		var f: Dictionary = _filling[kk]
		var e := now - float(f.at)
		if e >= FILL or Motion.reduce:
			_filling.erase(kk)
			_chunk_stale[kk / CHUNK] = true
			_threads_stale = true
			_pins_stale = true
			continue
		parts.append(_knit_now(kk, e, f.from))
	# threads being laid draw in from the pin they left
	for s: int in _laid_at.keys():
		var l: Dictionary = _laid_at[s]
		var e := now - float(l.at)
		if e >= THREAD_IN or Motion.reduce:
			_laid_at.erase(s)
			_threads_stale = true
			continue
		var a := _px[int(l.from)]
		var c := _px[int(l.to)]
		b.stroke(PackedVector2Array([a, a.lerp(c, Motion.back_out(e / THREAD_IN))]), _rope_w, YARN)
	# numerals ticking down swell and settle
	for kk: int in _ticked.keys():
		var e := now - float(_ticked[kk])
		if e >= MARK_TICK or state.filled[kk] or _solved_at > -INF:
			_ticked.erase(kk)
			_marks_stale = true
			continue
		_mark_into(b, kk, 1.0 + 0.45 * sin(PI * e / MARK_TICK) * (1.0 - e / MARK_TICK))
	var knitting := _combine(parts)
	var under := b.mesh() if not b.idx.is_empty() else null
	b = _builder()
	# pins whose every panel is filled pop off
	for v: int in _gone.keys():
		var e := now - float(_gone[v])
		if e >= PIN_GONE or Motion.reduce:
			_gone.erase(v)
			continue
		_pin_into(b, _px[v], _pin_r * (1.0 + 0.4 * sin(PI * e / PIN_GONE)) * Motion.pop_out_scale(maxf(0.0, e - PIN_GONE * 0.5), PIN_GONE * 0.5))
	# a refused pin shivers with a rose ring
	for v: int in _shiver_at.keys():
		var e := now - float(_shiver_at[v])
		if e >= Motion.SHIVER_TIME * 2.0:
			_shiver_at.erase(v)
			continue
		var at := _px[v] + Vector2(Motion.shiver_offset(e, 4.0), 0.0)
		b.stroke(Face.Builder.arc_points(at, _pin_r + 6.0, 0.0, TAU), 3.0, Color(Pal.BAD, 1.0 - e / (Motion.SHIVER_TIME * 2.0)), true)
	# the thread in hand, sagging a little from its pin to the finger
	var from := _cur
	if from >= 0 and _can_play():
		var a := _px[from]
		b.stroke(Face.Builder.arc_points(a, _pin_r + 7.0, 0.0, TAU), 3.0, Color(YARN, 0.8), true)
		if _cur >= 0 and _finger.x >= 0.0 and _finger.distance_to(a) > _pin_r:
			var mid := (a + _finger) * 0.5 + Vector2(0.0, a.distance_to(_finger) * SAG)
			b.stroke(Face.Builder.bezier2(a, mid, _finger, 12), _rope_w, Color(YARN, 0.85))
			b.disc(_finger, _rope_w * 0.9, YARN_HI)
			# the magnet's halo: the pin the finger would take, let go here
			var near := _reached(zoom.to_screen(_finger))
			if near >= 0 and near != _refused:
				b.disc(_px[near], _pin_r + 9.0, Color(YARN_HI, 0.35))
	return [knitting, under, b.mesh() if not b.idx.is_empty() else null]

## A pin's turn in the entrance: from the top down, as the picture is read.
func _enter_order(v: int) -> int:
	return int((_px[v].y - (_centre.y - _radius)) / maxf(1.0, _snap))

## Panel `kk` `e` seconds into knitting in from `from` (a point on the side
## that closed it): the knit comes in across the panel from that side, and
## the panel swells a little about its middle.
func _knit_now(kk: int, e: float, from: Vector2) -> Array:
	var part := _knit_part(kk)
	var src: PackedVector2Array = part[0]
	var verts := PackedVector2Array()
	verts.resize(src.size())
	var cols: PackedColorArray = (part[1] as PackedColorArray).duplicate()
	var c := panel_screen(kk)
	var far := 1.0
	for p in src:
		far = maxf(far, p.distance_to(from))
	var u := e / FILL
	var swell := 1.0 + FILL_PUSH * sin(PI * u)
	for m in src.size():
		var p := src[m]
		# the far corner comes in last
		var at := 0.55 * p.distance_to(from) / far
		cols[m].a = clampf((u - at) / 0.35, 0.0, 1.0)
		verts[m] = c + (p - c) * swell
	return [verts, cols, part[2], part[3]]

# --- the pill, the toast and the combo ---

func _draw_hud() -> void:
	if _k <= 0.0:
		return
	var now := _now()
	var since := now - _opened - Motion.ENTER_DELAY
	if since < 0.0 and not Motion.reduce:
		return
	if not _won:
		var font: Font = CozyTheme.display(700)
		var text := pill_text()
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT).x
		var box := Vector2(wide + 52.0 + 34.0, PILL_H)
		if _hud_shown == null or not is_equal_approx(_hud_wide, box.x):
			var b := Face.Builder.new()
			b.polygon(Face.Builder.round_rect(-box * 0.5 - Vector2.ONE * 2.0, box + Vector2.ONE * 4.0, box.y * 0.5 + 2.0), Pal.LINE)
			b.polygon(Face.Builder.round_rect(-box * 0.5, box, box.y * 0.5), Pal.SURFACE)
			# a small ball of yarn before the count
			var ball := Vector2(-box.x * 0.5 + 30.0, 0.0)
			b.disc(ball, 13.0, YARN)
			for m in 3:
				var a := -0.6 + m * 0.6
				b.stroke(Face.Builder.arc_points(ball + Vector2.from_angle(a + PI) * 7.0, 13.0, a - 0.7, a + 0.7), 1.8, YARN_DEEP)
			_hud_shown = b.mesh()
			_hud_wide = box.x
		var alpha := 1.0 if Motion.reduce else Motion.appear_level(since)
		var k := 1.0 if Motion.reduce else Motion.bump_scale(now - _pill_bump, 0.12)
		_hud_layer.draw_set_transform(Vector2(size.x * 0.5, _clear.x + HUD_ROW * 0.5), 0.0, Vector2(k, k))
		_hud_layer.draw_mesh(_hud_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
		var rise := (font.get_ascent(PILL_FONT) - font.get_descent(PILL_FONT)) * 0.5
		_hud_layer.draw_string(font, Vector2(-wide * 0.5 + 17.0, rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT, Color(Pal.TEXT, alpha))
		_hud_layer.draw_set_transform(Vector2.ZERO)
	_draw_combo(now)
	_draw_toast(now)

## What the pill reads: the panels filled of all of them.
func pill_text() -> String:
	return "%d / %d" % [state.done, state.panels.size()]

func _bump_pill() -> void:
	_pill_bump = _now()
	_hud_layer.queue_redraw()

## The combo's bubble, over the panel the drag closed last.
func _draw_combo(now: float) -> void:
	if _combo_n < COMBO_FROM:
		return
	var k := 1.0
	var alpha := 1.0
	if _combo_out_at == -INF and now - _combo_at >= COMBO_HOLD:
		_combo_out_at = now
	if _combo_out_at > -INF:
		var u := (now - _combo_out_at) / COMBO_DEFLATE
		if u >= 1.0 or Motion.reduce:
			_combo_n = 0
			return
		k = 1.0 - 0.75 * u * u
		alpha = 1.0 - u
	elif not Motion.reduce:
		var e := now - _combo_at
		k = Motion.pop_in_scale(e).x if _combo_popped else Motion.bump_scale(e)
	if k <= 0.01:
		return
	var font: Font = CozyTheme.display(700)
	var text := "x%d" % _combo_n
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT).x
	var box := Vector2(tw + 30.0, COMBO_FONT + 16.0)
	var tail := _at(_combo_pos) + Vector2(0.0, -12.0)
	var centre := tail + Vector2(box.x * 0.35, -box.y * 0.95)
	centre.x = clampf(centre.x, box.x * 0.5 + 4.0, size.x - box.x * 0.5 - 4.0)
	centre.y = maxf(centre.y, box.y * 0.5 + 4.0)
	var b := Face.Builder.new()
	var tip := tail - centre
	var root := Vector2(clampf(tip.x, -box.x * 0.3, box.x * 0.3), box.y * 0.3)
	b.polygon(PackedVector2Array([root + Vector2(-9.0, 0.0), tip, root + Vector2(9.0, 0.0)]), Pal.LINE)
	b.polygon(Face.Builder.round_rect(-box * 0.5 - Vector2(2.0, 2.0), box + Vector2(4.0, 4.0), box.y * 0.5 + 2.0), Pal.LINE)
	b.polygon(PackedVector2Array([root + Vector2(-6.5, -2.0), tip + (root - tip).normalized() * 3.0, root + Vector2(6.5, -2.0)]), Pal.SURFACE)
	b.polygon(Face.Builder.round_rect(-box * 0.5, box, box.y * 0.5), Pal.SURFACE)
	_combo_shown = b.mesh()
	_hud_layer.draw_set_transform(centre, 0.0, Vector2.ONE * k)
	_hud_layer.draw_mesh(_combo_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_hud_layer.draw_string(font, Vector2(-tw * 0.5, (font.get_ascent(COMBO_FONT) - font.get_descent(COMBO_FONT)) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color(YARN_DEEP, alpha))
	_hud_layer.draw_set_transform(Vector2.ZERO)

func _draw_toast(now: float) -> void:
	if _toast == "":
		return
	var since := now - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE),
		Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var font: Font = CozyTheme.body(600)
	var room := maxf(TOAST_PAD, size.x - 120.0)
	var text_room := room - TOAST_PAD
	var one: float = font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x
	var lines := 1
	var text_w := one
	if one > text_room:
		var wrapped: Vector2 = font.get_multiline_string_size(_toast, HORIZONTAL_ALIGNMENT_CENTER, text_room, TOAST_FONT)
		lines = maxi(1, int(round(wrapped.y / font.get_height(TOAST_FONT))))
		text_w = minf(text_room, wrapped.x)
	var wide := minf(room, text_w + TOAST_PAD)
	var tall := TOAST_H + float(lines - 1) * font.get_height(TOAST_FONT)
	var key := "%s|%d|%d" % [_toast, int(wide), lines]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-wide, -tall) * 0.5, Vector2(wide, tall), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh()
		_toast_mesh_for = key
	var mid := Vector2(size.x * 0.5, _clear.x + HUD_ROW * 0.5)
	_hud_layer.draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha * 0.94))
	var top := mid.y - tall * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - wide * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		_hud_layer.draw_string(font, Vector2(left, top), _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		_hud_layer.draw_multiline_string(font, Vector2(left, top), _toast, HORIZONTAL_ALIGNMENT_CENTER,
			wide - TOAST_PAD, TOAST_FONT, lines, Color(Pal.PAPER, alpha))

func _tell(text: String) -> void:
	_toast = text
	_toast_at = _now()
	_hud_layer.queue_redraw()

# --- the hand ---

## Touch and mouse, as every flat board takes them (touch is not mouse here:
## emulate_mouse_from_touch is off). The zoom reads every event first: two
## fingers pinch and pan, the wheel zooms on a desk, and a gesture that
## begins takes the thread in hand with it. Then a press on a pin takes the
## thread up; a drag lays it to every pin it passes that shares a side with
## the one in hand; let go, and the thread breaks off there (the user,
## 2026-10-15: "user has to click and hold to connect dots, if touch is
## released the string breaks"; a tap had held the thread and taps laid
## it on, pin to pin, since 2026-10-14). A press on bare linen seen close,
## dragged, looks round.
func _gui_input(event: InputEvent) -> void:
	if zoom.enabled:
		var took := zoom.feed(event)
		if took != PanZoom.NONE:
			if took == PanZoom.BEGAN:
				_end_stroke()
				_cur = -1
				_finger = Vector2(-1.0, -1.0)
				_pan_last = Vector2(-1.0, -1.0)
			_request()
			return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			press(event.position)
		else:
			release(event.position)
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and (_cur >= 0 or _pan_last.x >= 0.0)):
		drag(event.position)

func _can_play() -> bool:
	return not (is_done() or _solved_at > -INF)

## The pin a finger at `at` (the screen; the table as the zoom shows it)
## means: the nearest still standing within the snap, -1 for none. With
## `reach` (a tap, or a drag let go), the magnet: out to the reach when it
## is clearly the nearest. A drag on its way takes only what it passes
## close to, or it would be pulled to pins beside its path.
func pin_at(at: Vector2, but := -1, reach := false, within := -1.0) -> int:
	var snap := (_snap if within < 0.0 else within) / zoom.k
	var best := -1
	var best_d := INF
	var next_d := INF
	var lp := zoom.to_layout(at)
	for v in _px.size():
		if v == but or state.pin_live[v] <= 0:
			continue
		var d := _px[v].distance_to(lp)
		if d < best_d:
			next_d = best_d
			best_d = d
			best = v
		elif d < next_d:
			next_d = d
	if best < 0:
		return -1
	# within the snap it is taken; past it, only when clearly the nearest
	if best_d < snap:
		return best
	if reach and best_d < _reach / zoom.k and best_d * REACH_CLEAR < next_d:
		return best
	return -1

func press(at: Vector2) -> void:
	if not _can_play():
		return
	# a pin under the finger is the pin meant; off every pin, the magnet's
	# pick
	var v := pin_at(at, -1, false)
	if v < 0:
		v = pin_at(at, -1, true)
	_finger = zoom.to_layout(at)
	_moved = false
	_pan_last = Vector2(-1.0, -1.0)
	if v < 0:
		# bare linen: seen close, a drag pans
		if zoom.zoomed():
			_pan_last = at
		_request()
		return
	_refused = -1
	_stroke = 0
	_stroke_threads = 0
	_cur = v
	fx.cue("pick", randf_range(0.94, 1.06))
	_request()

## The pin a finger at `at` (screen) would take with the thread in hand,
## within the magnet's reach, when a side joins it to the pin held; -1
## for none.
func _reached(at: Vector2) -> int:
	if _cur < 0:
		return -1
	return _target_at(at, _cur)

## The pin a finger at `at` (screen) means with the thread in hand at pin
## `from`: the nearest of the standing pins a side joins to it, when the
## finger is nearer that pin than the pin held and no farther from it
## than the pin held is (or within the magnet's reach); -1 for none. Only
## the pins the thread can go to compete, so a tap roughly toward the
## next one lands, however many other pins lie about it and however far
## apart the two are (the reach alone, 0.8 of the board's shortest side,
## was 30 px on a Medium board whose pins lie 96 px apart).
func _target_at(at: Vector2, from: int) -> int:
	if from < 0:
		return -1
	var lp := zoom.to_layout(at)
	var reach := _reach / zoom.k
	var held := _px[from].distance_to(lp)
	var best := -1
	var best_d := INF
	for s in state.pin_sides[from]:
		var sd: Vector2i = state.sides[s]
		var v: int = sd.y if sd.x == from else sd.x
		if state.pin_live[v] <= 0:
			continue
		var d := _px[v].distance_to(lp)
		if d < best_d and (d < reach or (d < held and d < _px[v].distance_to(_px[from]))):
			best_d = d
			best = v
	return best

func drag(at: Vector2) -> void:
	if _pan_last.x >= 0.0:
		zoom.pan_by(at - _pan_last)
		_pan_last = at
		_request()
		return
	if _cur < 0 or not _can_play():
		return
	# the finger's way since the last event, a sample a half snap apart, so
	# a quick drag still passes every pin under it
	var lp := zoom.to_layout(at)
	var snap := _snap / zoom.k
	var from := _finger if _finger.x >= 0.0 else lp
	var n := maxi(1, ceili(from.distance_to(lp) / (snap * 0.5)))
	for m in range(1, n + 1):
		var q := from.lerp(lp, float(m) / n)
		if _refused >= 0 and q.distance_to(_px[_refused]) > snap:
			_refused = -1
		var v := pin_at(zoom.to_screen(q), _cur, false, -1.0 if m == n else _snap * PASS_SHARE)
		if v >= 0 and v != _refused:
			_step(v)
			if _cur < 0 or not _can_play():
				break
	_finger = lp
	if _cur >= 0 and lp.distance_to(_px[_cur]) > snap:
		_moved = true
	_request()

## Let go: a drag let go near a pin the thread could reach along a side
## takes it, then the thread breaks off (a snip and a puff of yarn where
## the finger was, when it hung loose) and its combo is counted.
func release(at: Vector2) -> void:
	_pan_last = Vector2(-1.0, -1.0)
	if _cur < 0:
		return
	if _moved and _can_play():
		var v := _reached(at)
		if v >= 0:
			_step(v)
	if _cur >= 0 and _can_play():
		var lp := zoom.to_layout(at)
		if lp.distance_to(_px[_cur]) > _snap / zoom.k:
			fx.cue("pick", 0.72)
			if not Motion.reduce:
				fx.puff(_at(lp), YARN_HI, 4)
	_end_stroke()
	_cur = -1
	_finger = Vector2(-1.0, -1.0)
	_request()

## The thread in hand goes on to pin `v`: laid when the two share a side,
## walked along when that side is threaded already, refused otherwise.
func _step(v: int) -> void:
	var s: int = state.side_between(_cur, v)
	if s < 0:
		state.refused += 1
		_refused = v
		fx.cue("locked")
		if not Motion.reduce:
			_shiver_at[v] = _now()
			_busy_for(Motion.SHIVER_TIME * 2.0)
		return
	var was := _cur
	_cur = v
	_moved = true
	# every new pin the thread reaches is a select, laid or walked along
	fx.cue("pick", randf_range(0.94, 1.06))
	if state.laid[s]:
		return
	_lay(s, was, v)

## Side `s` threaded from pin `a` to pin `b`: its thread draws in, the
## panels it closed knit in, and the pins with no open panel left pop
## off.
func _lay(s: int, a: int, b: int) -> void:
	var now := _now()
	var closed: PackedInt32Array = state.lay_side(s)
	_stroke_threads += 1
	if not Motion.reduce:
		_laid_at[s] = {"at": now, "from": a, "to": b}
	_threads_stale = true
	_pins_stale = true
	var semis := mini(_stroke_threads - 1, 10) * STITCH_STEP
	fx.cue("stitch", pow(2.0, minf(semis, 5.0) / 12.0) * randf_range(0.97, 1.03))
	var mid := (_px[a] + _px[b]) * 0.5
	_marks_stale = true
	if not Motion.reduce:
		for k in state.side_panels[s]:
			if not state.filled[k]:
				_ticked[k] = now
	for k in closed:
		_close(k, mid, now)
		for v in state.panels[k]:
			if state.pin_live[v] <= 0:
				_gone[v] = now
	if closed.size() == 2:
		_after(0.0 if Motion.reduce else 0.06, fx.cue.bind("double"))
	if not closed.is_empty():
		_bump_pill()
		_check_whole(closed)
	_busy_for(FILL + 0.1)
	_request()
	note_move()

## Panel `k` is closed: it knits in from `from`, and the drag's combo grows.
func _close(k: int, from: Vector2, now: float) -> void:
	if not Motion.reduce:
		_filling[k] = {"at": now, "from": from}
	_chunk_stale[k / CHUNK] = true
	_stroke += 1
	_best = maxi(_best, _stroke)
	var c := panel_screen(k)
	var step: int = RUN_SCALE[mini(_stroke - 1, RUN_SCALE.size() - 1)]
	_after(0.0 if Motion.reduce else FILL * 0.5, func() -> void:
		fx.cue("fill", pow(2.0, step / 12.0) * randf_range(0.98, 1.02))
		if not Motion.reduce:
			var col: Color = State.ink(state.colours[state.colour[k]])
			fx.puff(_at(c), col.lightened(0.25), 6))
	if _stroke >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = _stroke
		_combo_pos = c
		_combo_at = now
		_combo_out_at = -INF
		_hud_layer.queue_redraw()

## A drag put down: one that closed BIG_RUN panels or more ends on its two
## notes and a sparkle, a long one with confetti.
func _end_stroke() -> void:
	if _stroke >= BIG_RUN and not is_done():
		fx.cue("run")
		if not Motion.reduce:
			fx.sparkle(_at(_combo_pos), Pal.SUN)
			if _stroke >= RUN_CONFETTI:
				fx.confetti(_at(_combo_pos), 14, _radius * 0.6 * zoom.k)
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_at = minf(_combo_at, _now() - COMBO_HOLD * 0.5)
	if _stroke_threads > 0:
		_keep()
	_stroke = 0
	_stroke_threads = 0

## A colour whose every panel is filled: three notes and sparkles on it.
func _check_whole(closed: PackedInt32Array) -> void:
	if state.is_solved():
		return
	for k in closed:
		var c: int = state.colour[k]
		var all := true
		for m in state.panels.size():
			if state.colour[m] == c and not state.filled[m]:
				all = false
				break
		if not all:
			continue
		_after(0.0 if Motion.reduce else FILL, func() -> void:
			if is_done():
				return
			fx.cue("whole")
			if Motion.reduce:
				return
			var n := 0
			for m in state.panels.size():
				if state.colour[m] == c and n < 8:
					fx.sparkle(_at(panel_screen(m)), Pal.SUN)
					n += 1)

func tip_line() -> Dictionary:
	return {"text": "", "mood": Face.Expr.HAPPY}

# --- the HUD's actions ---

func hints_left() -> int:
	return State.hints_for(state.band) + hints_extra - hints_used

## Threads a side of the panel nearest done, as the player would: rings on
## its two pins, a beat, then the thread.
func hint() -> bool:
	if not _can_play() or hints_left() <= 0:
		return false
	var s: int = state.hint()
	if s < 0:
		return false
	hints_used += 1
	var a: int = state.sides[s].x
	var b: int = state.sides[s].y
	zoom.show_point((_px[a] + _px[b]) * 0.5)
	for v in [a, b]:
		fx.ring(_at(_px[v]), _pin_r * 3.0 * zoom.k, Pal.SUN)
	fx.sparkle(_at((_px[a] + _px[b]) * 0.5), Pal.SUN)
	fx.cue("hint")
	_tell(tr("YH_HINTED"))
	_after(0.0 if Motion.reduce else HINT_BEAT, func() -> void:
		if not _can_play() or state.laid[s]:
			return
		_stroke = 0
		_stroke_threads = 0
		_lay(s, a, b)
		_end_stroke()
		_request())
	return true

# --- the day kept mid-way ---

## A day's threads kept while it is played (2026-10-28): a Hard day is ~200
## sides, Insane up to ~390, and leaving the board threw them all away (no
## board kept a day mid-way; they were minutes long). Today's daily only,
## a band a key, beside the progress file so a harness's runs keep their
## own; other days are let go on the next write.
func _play_path() -> String:
	return Progress.path.get_basename() + "_hoop_play.cfg"

func _play_key() -> String:
	return "band_%d" % state.band

func _keeps() -> bool:
	return daily_key != 0 and bank_step == 0 and not state.panels.is_empty()

func _keep() -> void:
	if not _keeps() or is_done():
		return
	var cfg := ConfigFile.new()
	cfg.load(_play_path())
	for sec in cfg.get_sections():
		if sec != str(daily_key):
			cfg.erase_section(sec)
	cfg.set_value(str(daily_key), _play_key(), {"sides": state.sides.size(), "laid": state.laid,
		"slips": state.refused, "hints": hints_used, "best": _best, "moves": moves, "elapsed": elapsed})
	cfg.save(_play_path())

func _forget() -> void:
	if not _keeps():
		return
	var cfg := ConfigFile.new()
	if cfg.load(_play_path()) != OK or not cfg.has_section_key(str(daily_key), _play_key()):
		return
	cfg.erase_section_key(str(daily_key), _play_key())
	cfg.save(_play_path())

## The threads this day's band was left with, laid again (no animation, no
## sound) before the board is shown; a cut that came out different (another
## side count) is not trusted and is let go.
func _resume() -> void:
	if not _keeps():
		return
	var cfg := ConfigFile.new()
	if cfg.load(_play_path()) != OK or not cfg.has_section_key(str(daily_key), _play_key()):
		return
	var got = cfg.get_value(str(daily_key), _play_key())
	if not (got is Dictionary) or int(got.get("sides", -1)) != state.sides.size():
		return
	var laid = got.get("laid")
	if not (laid is PackedByteArray) or (laid as PackedByteArray).size() != state.sides.size():
		return
	for s in state.sides.size():
		if laid[s]:
			state.lay_side(s)
	if state.is_solved():
		state.reset()
		return
	state.refused = int(got.get("slips", 0))
	hints_used = int(got.get("hints", 0))
	_best = int(got.get("best", 0))
	moves = int(got.get("moves", 0))
	elapsed = float(got.get("elapsed", 0.0))

## The linen as the day opened it: every thread taken out. The hints a
## player spent are not refunded.
func reset_board() -> void:
	if is_done():
		return
	_gen += 1
	state.reset()
	_forget()
	moves = 0
	_running = true
	_deal()
	_opened = _now() - Motion.ENTER_DELAY
	_busy_for(Motion.ENTER_POP + Motion.POP_IN + Motion.stagger(state.pins.size(), Motion.ENTER_STAGGER, 0.8) + 0.1)
	_bump_pill()
	_tell(tr("YH_RESET"))
	fx.cue("reset")
	_request()

func is_solved() -> bool:
	return state.is_solved()

## The win's brain report: a fifth off for every slip (spec 2026-10-22-brain-skills, section 6).
func skill_quality() -> float:
	return 1.0 / (1.0 + 0.2 * float(state.refused))

func completion_record() -> Dictionary:
	return {"best": _best, "slips": state.refused}

## A completed daily is rebuilt from its seed: every side threaded, the
## picture whole as the win left it.
func restore_completed_board() -> void:
	var now := _now()
	_gen += 1
	state.finish()
	state.refused = int(completed_record.get("slips", 0))
	_best = int(completed_record.get("best", 0))
	zoom.reset()
	_deal()
	_opened = now - 10.0
	_solved_at = now - 10.0
	_slid_at = -INF
	_final_refused = state.refused
	_anim_until = 0.0
	_stamp_at = now - 10.0 if _stamped() else INF
	_seal_mesh = null
	_hud_layer.queue_redraw()
	_request()

func share_glyphs() -> String:
	return "%s ✨x%d" % [state.share_glyphs(), _best]

# --- the win ---

## The seal: any Insane picture, or one threaded without a thread refused.
func _stamped() -> bool:
	return state.band >= State.INSANE or _final_refused == 0

func flat_win() -> Dictionary:
	var what := tr(state.name_key) if state.name_key != "" else title()
	return {"faces": [], "subtitle": tr("YH_WIN_SUB") % [what, state.panels.size()]}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT + PARTY_EXTRA

## The last panel knits in, the picture swells once, and the seal drops.
func _on_solved() -> void:
	var now := _now()
	_end_stroke()
	_forget()
	_cur = -1
	_toast = ""
	_solved_at = now
	_final_refused = state.refused
	# the picture is seen whole for its win
	if zoom.zoomed():
		zoom.toggle()
	var lag := 0.0 if Motion.reduce else FILL
	_after(lag, fx.cue.bind("solved"))
	_hud_layer.queue_redraw()
	_party(lag)
	_busy_for(lag + WAVE + 1.0 + WIN_SLIDE + 0.3)
	_request()

func _party(lag: float) -> void:
	var now := _now()
	if _stamped():
		_stamp_at = now if Motion.reduce else now + lag + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_request())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
			_busy_for(lag + STAMP_AT + STAMP_DROP * 3.0)
	if Motion.reduce:
		return
	_after(lag + 0.2, func() -> void:
		fx.confetti(_at(_centre + Vector2(0.0, -_radius * 0.6)), 30, _radius * 1.4)
		fx.cue("party"))
	_after(lag + 0.6, func() -> void:
		fx.confetti(_at(_centre), 24, _radius))

func _draw_stamp(now: float, shown: Array, slide: Transform2D) -> void:
	var rad := maxf(_radius * 2.0, 420.0) * STAMP_R
	var insane: bool = state.band >= State.INSANE
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := _centre + Vector2(_radius, _radius) * 0.62
	var xf := slide * Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	draw_set_transform_matrix(xf)
	draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02], [tr("YH_SEAL_NEAT") if _final_refused == 0 else tr("YH_SEAL_INSANE"), 0.17, 0.36]]
	else:
		lines = [[tr("YH_SEAL_NEAT"), 0.24, 0.12]]
	Seal.text(self, rad, lines)
	draw_set_transform_matrix(slide)

# --- entrance ---

## The chrome is the host's; here the hoop pops in wide and the pins pop
## onto the linen from the top down.
func _enter() -> void:
	_opened = _now()
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP + Motion.POP_IN + Motion.stagger(state.pins.size(), Motion.ENTER_STAGGER, 0.8) + 0.1)
	fx.cue("enter")

# --- odds and ends ---

func _after(delay: float, what: Callable) -> void:
	if delay <= 0.0:
		what.call()
		return
	var gen := _gen
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

func _process(delta: float) -> void:
	super(delta)
	if _k <= 0.0:
		return
	var now := _now()
	var gliding := zoom.step(delta)
	if not gliding and not zoom.busy() and absf(zoom.k / _built_k - 1.0) > 0.05:
		_rebuild_for_zoom()
	if gliding or zoom.busy() or now < _anim_until or now - _slid_at < WIN_SLIDE + 0.1 or not _filling.is_empty() \
			or not _laid_at.is_empty() or not _gone.is_empty() or _cur >= 0:
		_request()
	var wanted := _zoom_button_wanted()
	if _zoom_b.visible != wanted:
		_zoom_b.visible = wanted
	if wanted:
		_zoom_b.set_icon("plus" if zoom.next_in() else "minus")
	var since := now - _opened - Motion.ENTER_DELAY
	if since < Motion.DROP_FADE + 0.1 or now - _pill_bump < Motion.BUMP_TIME + 0.1 \
			or (_toast != "" and now - _toast_at < TOAST_HOLD + 0.1) \
			or (_combo_n >= COMBO_FROM and (now - _combo_at < COMBO_HOLD + 0.1 or _combo_out_at > -INF)):
		_hud_layer.queue_redraw()

## Rebuilds what is drawn under the zoom for the zoom it settled at; the
## table under it does not scale.
func _rebuild_for_zoom() -> void:
	_built_k = zoom.k
	_hoop = _build_hoop()
	_clamp = _build_clamp()
	_yarn = {}
	_threads_stale = true
	_pins_stale = true
	_marks_stale = true
	_request()

func _request() -> void:
	queue_redraw()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
