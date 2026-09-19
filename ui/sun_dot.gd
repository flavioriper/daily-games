extends Control

## The title system's golden sun-dot: the dot of every lowercase i in the
## label this is attached to, drawn as a small sun. It is the dot and not a
## sticker over one: the label's i's are set in the dotless ı (Fredoka
## carries it), and the sun is seated where Fredoka's own dot would have
## been -- measured once off the rendered face at 140, 84 and 32, the three
## title sizes: a circle centred 0.64 em above the baseline, 0.09 em in
## radius, dead centre on the glyph's advance box -- so the lettering keeps
## its rhythm and the rays stand open on paper rather than on ink.
##
## Attach it as a child of a Label. It reads the label's own character
## bounds, so alignment, wrapping and stylebox margins come for free, and one
## mark serves the 140 px wordmark (ui/menu/menu_header.gd), the 84 px game
## headers (ui/flat/flat_top_bar.gd) and the 32 px card names
## (ui/menu/puzzle_card_2d.gd). The sun is the header's own
## (ui/faces/sun_face.gd) in miniature -- a disc in SUN with eight capsule
## rays in SUN_RAY -- built per size so the builder's feather stays one
## screen pixel. A rayed sun is lifted RAY_LIFT_EM off the dot's seat so its
## bottom pair of rays clears the stem (measured at 140 the tips would land
## two pixels into the ink), and the rays are turned half a step so none
## points straight up or down. Under RAYS_FROM it is a plain disc a little larger
## than the ink dot, seated exactly on it, because a ray a pixel wide is a
## smudge.
##
## A rayed sun idles the way the header's sun does (ui/faces/sun_face.gd):
## its rays turn once in that sun's SPIN_PERIOD, so the two suns on the first
## screen turn together, and every few seconds it glints -- over the boards'
## flash timings (Motion.FLASH_IN and FLASH_OUT) the rays flare out by FLARE
## and a shine rises over it, a pale halo of SUN_RAY round a white cast on
## the disc, and fades. The shine is one more mesh drawn only while `glint`
## is above zero, so a resting sun costs the disc and the rays and nothing
## else. Plain discs never move. Reduce-motion stills all of it: set_idle
## does nothing under it, and a glint that comes due under it stops the
## idle. A screen that refreshes its motion on the settings toggle (the
## header) calls set_idle; the rest catch up at their next glint.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Motion = preload("res://core/motion.gd")
const SunFace = preload("res://ui/faces/sun_face.gd")

const DOTLESS := "ı"
## Fredoka 700's dot, measured: its centre above the baseline and its radius,
## in em.
const DOT_CENTRE_EM := 0.64
const DOT_RADIUS_EM := 0.09
## How far a rayed sun floats above the dot's seat, in em.
const RAY_LIFT_EM := 0.03
## The rays, in R: the capsule's width and its run out from the disc.
const RAY_WIDTH := 0.34
const RAY_FROM := 1.12
const RAY_TO := 1.75
## Below this R the rays are dropped and the disc grows by PLAIN_SCALE.
const RAYS_FROM := 5.0
const PLAIN_SCALE := 1.15
## The glint: how far the rays flare, in scale; the shine's halo, in R, and
## the halo's and the white cast's alpha at the peak; and how long a sun
## waits between glints.
const FLARE := 0.18
const SHINE_HALO := 1.9
const SHINE_HALO_ALPHA := 0.3
const SHINE_ALPHA := 0.45
const GLINT_WAIT_MIN := 3.5
const GLINT_WAIT_MAX := 6.5

## The rays' angle, and the glint's level, 0 at rest and 1 at the peak.
var spin := 0.0:
	set(value):
		spin = value
		queue_redraw()
var glint := 0.0:
	set(value):
		glint = value
		queue_redraw()

var _label: Label
var _idle := false
var _spin_tw: Tween
var _glint_tw: Tween
var _glint_wait: Tween
static var _meshes := {}

func _init(label: Label, opacity := 1.0) -> void:
	_label = label
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	self_modulate.a = opacity
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.resized.connect(queue_redraw)
	dress(_label)

func _ready() -> void:
	set_idle(true)

## On: a rayed sun turns and glints. Off: everything stops where it is, with
## any glint put out. Under reduce-motion, and for a plain disc, on does
## nothing.
func set_idle(on: bool) -> void:
	_stop_idle()
	if not on or Motion.reduce or not rayed():
		return
	_idle = true
	_spin_tw = create_tween().set_loops()
	# A full turn lands on the same picture, so the loop's seam is invisible.
	_spin_tw.tween_property(self, "spin", spin + TAU, SunFace.SPIN_PERIOD).from(spin)
	_schedule_glint()

## One shine, now: the flash's rise and fall. Returns the tween, or null
## under reduce-motion, when nothing moves.
func glint_now() -> Tween:
	if Motion.reduce:
		return null
	Motion.stop(_glint_tw)
	_glint_tw = create_tween()
	_glint_tw.tween_property(self, "glint", 1.0, Motion.FLASH_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_glint_tw.tween_property(self, "glint", 0.0, Motion.FLASH_OUT) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return _glint_tw

func _schedule_glint() -> void:
	Motion.stop(_glint_wait)
	_glint_wait = create_tween()
	_glint_wait.tween_interval(randf_range(GLINT_WAIT_MIN, GLINT_WAIT_MAX))
	_glint_wait.tween_callback(_idle_glint)

func _idle_glint() -> void:
	if not _idle:
		return
	if Motion.reduce:
		set_idle(false)
		return
	glint_now()
	_schedule_glint()

func _stop_idle() -> void:
	_idle = false
	Motion.stop(_glint_wait)
	Motion.stop(_spin_tw)
	Motion.stop(_glint_tw)
	glint = 0.0

## Set the label's lowercase i's in the dotless ı, so no ink sits under the
## sun. Called on attach and again if the text is changed afterwards.
static func dress(label: Label) -> void:
	if label.text.contains("i"):
		label.text = label.text.replace("i", DOTLESS)

## The sun's radius, in the label's pixels.
func radius() -> float:
	return _label.get_theme_font_size("font_size") * DOT_RADIUS_EM

## How far the rays reach from a seat, in the label's pixels.
func reach() -> float:
	var r := radius()
	return r * PLAIN_SCALE if r < RAYS_FROM else r * RAY_TO

## Whether this size draws rays.
func rayed() -> bool:
	return radius() >= RAYS_FROM

## The suns' centres, in the label's space, one per dotless i.
func seats() -> PackedVector2Array:
	var out := PackedVector2Array()
	if _label == null:
		return out
	var text := _label.text
	var font := _label.get_theme_font("font")
	var font_size := _label.get_theme_font_size("font_size")
	var centre_em := DOT_CENTRE_EM + (RAY_LIFT_EM if rayed() else 0.0)
	var lift := font.get_ascent(font_size) - font_size * centre_em
	for index in text.length():
		if text[index] != DOTLESS:
			continue
		var box := _label.get_character_bounds(index)
		if box.size.x <= 0.0:
			continue
		out.append(Vector2(box.get_center().x, box.position.y + lift))
	return out

func _draw() -> void:
	if _label == null:
		return
	if _label.text.contains("i"):
		dress(_label)
		queue_redraw()
		return
	var r := radius()
	var with_rays := rayed()
	var disc := _mesh_for(r, "disc")
	var rays: ArrayMesh = _mesh_for(r, "rays") if with_rays else null
	var shine: ArrayMesh = _mesh_for(r, "shine") if with_rays and glint > 0.0 else null
	var flare := Vector2.ONE * (1.0 + FLARE * glint)
	for seat in seats():
		if with_rays:
			draw_mesh(rays, null, Transform2D(spin, flare, 0.0, seat))
		draw_mesh(disc, null, Transform2D(0.0, seat))
		if shine != null:
			draw_mesh(shine, null, Transform2D(0.0, seat), Color(1.0, 1.0, 1.0, glint))

## One layer of a sun of radius `r`, cached by layer and size: "disc" (the
## body, or the whole of a plain sun), "rays" and "shine".
static func _mesh_for(r: float, layer: String) -> ArrayMesh:
	var key := "%s:%d" % [layer, roundi(r * 4.0)]
	if _meshes.has(key):
		return _meshes[key]
	var b := Face.Builder.new()
	match layer:
		"disc":
			b.disc(Vector2.ZERO, r if r >= RAYS_FROM else r * PLAIN_SCALE, Pal.SUN)
		"rays":
			var half := RAY_WIDTH * 0.5 * r
			for i in 8:
				var dir := Vector2.from_angle(-PI * 0.5 + PI * 0.125 + i * PI * 0.25)
				b.stroke(PackedVector2Array([dir * (RAY_FROM * r + half), dir * (RAY_TO * r - half)]), RAY_WIDTH * r, Pal.SUN_RAY)
		"shine":
			b.disc(Vector2.ZERO, SHINE_HALO * r, Color(Pal.SUN_RAY, SHINE_HALO_ALPHA))
			b.disc(Vector2.ZERO, r, Color(Color.WHITE, SHINE_ALPHA))
	var mesh := b.mesh()
	_meshes[key] = mesh
	return mesh
