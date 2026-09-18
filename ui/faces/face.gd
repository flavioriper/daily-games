extends Control

## The base of Binairo's three faces (the sun, the moon and the sprout): one
## Control that draws every part in its own draw call from a few tweened
## properties, so a board of sixty-four cells is sixty-four faces and not
## hundreds of nodes. A subclass draws its body in _draw and calls
## _face_parts for the eyes, brows, mouth and cheeks. Every measure is in
## units of the face radius R, ported number for number from the approved
## canvas mock (docs/brainstorm/concepts.html#binairo: faceParts and the
## three bodies), so the game and the mock stay the same drawing.
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, section 4
## and the amendments at its end.
##
## Antialiasing: MSAA stays off for the whole 2D canvas, so a disc or an arc
## is drawn with the antialiased primitive, an ellipse is an antialiased disc
## under a squashed transform, and a filled polygon gets a thin antialiased
## outline in its own colour, which softens its edge. That last trick doubles
## the alpha along the rim, so it is only laid on an opaque fill; a
## translucent polygon (the moon's shadow) goes without and hides its
## staircase in its faintness.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")

enum Expr { HAPPY, JOY, WORRIED, SLEEPY }

## One blink, shut and open again.
const BLINK_TIME := 0.14
## The eyes stay this open at the bottom of a blink.
const BLINK_SHUT := 0.1
## A resting face blinks after a random wait in this range, each its own.
const BLINK_WAIT_MIN := 3.0
const BLINK_WAIT_MAX := 7.0
## A sleepy face's lids.
const SLEEPY_EYE := 0.35
## The offset shadow under every face: ink at 8 percent.
const SHADOW_ALPHA := 0.08
## The outline laid over a filled polygon in its own colour, in pixels.
const SOFT_EDGE := 1.5
## Pixels of arc per polygon segment, and the bounds on how many segments.
const ARC_STEP := 3.0
const ARC_MIN := 8
const ARC_MAX := 256

var expression: int = Expr.HAPPY:
	set(v):
		expression = v
		queue_redraw()
## 0 shut to 1 open; a blink tweens it.
var eye_open := 1.0:
	set(v):
		eye_open = v
		queue_redraw()
## Radians; the sun turns its rays by it.
var spin := 0.0:
	set(v):
		spin = v
		queue_redraw()
## Radians; the moon tilts by it about its centre.
var rock := 0.0:
	set(v):
		rock = v
		queue_redraw()
## Whether set_idle(true) rocks this face. Only a moon reads it, and the owner
## turns it on for about a third of them so a board sways rather than nods.
var rocks := false

var _idle := false
var _blink_tw: Tween
var _blink_wait: Tween
var _idle_tw: Tween
## The transform every part is drawn under: the rect's centre, turned by the
## moon's rock. A subclass sets it first thing in _draw through _begin.
var _xf := Transform2D.IDENTITY

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	# Owners scale a face for the pop and the squash; the scale has to turn
	# about the centre or the face slides off its tile. A size set before the
	# face enters the tree sends no RESIZED (the cache updates silently and
	# the entry pass then sees no change), so the entry centres it too.
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_ENTER_TREE:
		pivot_offset = size * 0.5
	elif what == NOTIFICATION_EXIT_TREE:
		_stop_idle()

## R for the current size, so the whole drawing fits the rect. A subclass
## decides the ratio (the sun's rays and the sprout's leaves reach past R).
func radius() -> float:
	return minf(size.x, size.y) * 0.5

## Shuts the eyes and opens them again over BLINK_TIME. Returns the tween, or
## null under reduce-motion, when nothing moves.
func blink() -> Tween:
	if Motion.reduce:
		return null
	Motion.stop(_blink_tw)
	_blink_tw = create_tween()
	_blink_tw.tween_property(self, "eye_open", BLINK_SHUT, BLINK_TIME * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_blink_tw.tween_property(self, "eye_open", 1.0, BLINK_TIME * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return _blink_tw

## On: the face lives. It blinks at a random interval of its own, and a
## subclass adds its motion (the sun's turn, a rocking moon's tilt). Off:
## everything stops where it is. Under reduce-motion, on does nothing.
func set_idle(on: bool) -> void:
	_stop_idle()
	if not on or Motion.reduce:
		return
	_idle = true
	_schedule_blink()
	_idle_tw = _idle_motion()

## The subclass's idle motion, if it has one: a looping tween the base kills
## with the rest. The base has none.
func _idle_motion() -> Tween:
	return null

func _schedule_blink() -> void:
	Motion.stop(_blink_wait)
	_blink_wait = create_tween()
	_blink_wait.tween_interval(randf_range(BLINK_WAIT_MIN, BLINK_WAIT_MAX))
	_blink_wait.tween_callback(_idle_blink)

func _idle_blink() -> void:
	if not _idle:
		return
	blink()
	_schedule_blink()

func _stop_idle() -> void:
	_idle = false
	Motion.stop(_blink_wait)
	Motion.stop(_idle_tw)
	# A blink cut short would leave the eyes half shut for good.
	if Motion.running(_blink_tw):
		Motion.stop(_blink_tw)
		eye_open = 1.0

# ---- drawing, all in R about the rect's centre ----

## Sets the transform every part draws under: the rect's centre, turned by
## `angle`. A subclass calls it first thing in _draw.
func _begin(angle := 0.0) -> void:
	_xf = Transform2D(angle, size * 0.5)
	draw_set_transform_matrix(_xf)

## An antialiased disc.
func _disc(centre: Vector2, r: float, colour: Color) -> void:
	draw_circle(centre, r, colour, true, -1.0, true)

## An antialiased ellipse: a disc under a transform squashed to the ratio,
## which keeps the primitive's own edge rather than a polygon's staircase.
func _ellipse(centre: Vector2, rx: float, ry: float, colour: Color) -> void:
	draw_set_transform_matrix(_xf * Transform2D(0.0, Vector2(1.0, ry / rx), 0.0, centre))
	draw_circle(Vector2.ZERO, rx, colour, true, -1.0, true)
	draw_set_transform_matrix(_xf)

## How many segments an arc of `r` sweeping `sweep` radians takes.
func _arc_n(r: float, sweep: float) -> int:
	return clampi(int(ceilf(absf(sweep) * r / ARC_STEP)), ARC_MIN, ARC_MAX)

## Points along an arc of `r` about `centre` from `from` to `to`, a few
## pixels apart; `to` below `from` runs the other way. The end point is
## included, so a caller joining two arcs drops it.
func _arc_points(centre: Vector2, r: float, from: float, to: float) -> PackedVector2Array:
	var n := _arc_n(r, to - from)
	var pts := PackedVector2Array()
	pts.resize(n + 1)
	for i in n + 1:
		pts[i] = centre + Vector2.from_angle(lerpf(from, to, float(i) / n)) * r
	return pts

## Points around an ellipse, without repeating the first.
func _ellipse_points(centre: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var n := _arc_n(maxf(rx, ry), TAU)
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * i / n
		pts[i] = centre + Vector2(cos(a) * rx, sin(a) * ry)
	return pts

## A stroked arc with round caps, the way the mock's canvas strokes them.
func _arc(centre: Vector2, r: float, from: float, to: float, colour: Color, width: float) -> void:
	draw_arc(centre, r, from, to, _arc_n(r, to - from) + 1, colour, width, true)
	_disc(centre + Vector2.from_angle(from) * r, width * 0.5, colour)
	_disc(centre + Vector2.from_angle(to) * r, width * 0.5, colour)

## A stroked line with round caps.
func _line(from: Vector2, to: Vector2, colour: Color, width: float) -> void:
	draw_line(from, to, colour, width, true)
	_disc(from, width * 0.5, colour)
	_disc(to, width * 0.5, colour)

## A filled polygon with a soft edge: the fill, then its closed outline in the
## same colour, thin and antialiased. An opaque colour only (see the header);
## a translucent one is filled plain.
func _fill(points: PackedVector2Array, colour: Color) -> void:
	draw_colored_polygon(points, colour)
	if colour.a < 1.0:
		return
	var loop := PackedVector2Array(points)
	loop.append(points[0])
	draw_polyline(loop, colour, SOFT_EDGE, true)

## Eyes, brows, mouth and cheeks for `expression` and `eye_open`, at scale R
## about `centre`, in `ink`: number for number the mock's faceParts. HAPPY is
## round eyes with a catchlight and a smile; JOY shut arches over the open
## mouth with its tongue; WORRIED round eyes under slanted brows and a small
## round mouth; SLEEPY the happy face with its lids down.
func _face_parts(R: float, centre: Vector2, ink: Color) -> void:
	var eye := eye_open
	match expression:
		Expr.JOY:
			eye = 1.0
		Expr.SLEEPY:
			eye = minf(eye_open, SLEEPY_EYE)
	var cheek := Color(Pal.CHEEK, 0.85)
	_ellipse(centre + Vector2(-0.46, 0.16) * R, 0.13 * R, 0.09 * R, cheek)
	_ellipse(centre + Vector2(0.46, 0.16) * R, 0.13 * R, 0.09 * R, cheek)
	for sx: float in [-1.0, 1.0]:
		var e := centre + Vector2(sx * 0.34, -0.1) * R
		if expression == Expr.JOY:
			_arc(e + Vector2(0.0, 0.04 * R), 0.13 * R, PI * 1.1, PI * 1.9, ink, 0.075 * R)
			continue
		_ellipse(e, 0.1 * R, maxf(0.012 * R, 0.1 * R * eye), ink)
		if eye > 0.5:
			_disc(e + Vector2(-0.03, -0.035) * R, 0.03 * R, Color(1.0, 1.0, 1.0, 0.9))
		if expression == Expr.WORRIED:
			_line(e + Vector2(sx * 0.16, -0.2) * R, e + Vector2(-sx * 0.1, -0.3) * R, ink, 0.06 * R)
	if expression == Expr.WORRIED:
		draw_circle(centre + Vector2(0.0, 0.3 * R), 0.08 * R, ink, false, 0.06 * R, true)
		return
	var big := expression == Expr.JOY
	var mouth := centre + Vector2(0.0, (0.08 if big else 0.1) * R)
	var mr := (0.28 if big else 0.22) * R
	var from := PI * (0.1 if big else 0.18)
	var to := PI * (0.9 if big else 0.82)
	_arc(mouth, mr, from, to, ink, 0.07 * R)
	if big:
		# The open mouth is the arc closed by its chord, and the tongue the
		# same over the middle. The tongue is the cheek laid at nine tenths
		# over the ink, baked to one opaque colour so its soft edge holds.
		_fill(_arc_points(mouth, mr, from, to), ink)
		_fill(_arc_points(mouth, mr, PI * 0.3, PI * 0.7), ink.lerp(Pal.CHEEK, 0.9))
