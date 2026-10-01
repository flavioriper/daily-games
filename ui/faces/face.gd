extends Control

## The base of every drawn character -- Binairo's sun, moon and sprout, and
## Code Break's six friends: one
## Control that draws its whole picture as one or two cached meshes, so a
## board of sixty-four cells is sixty-four faces and not hundreds of nodes,
## and each face costs the renderer one draw_mesh per layer rather than one
## canvas command per eye, cheek and ray. A subclass names its layers and
## appends each one's shapes to a Builder; the base turns that into an
## ArrayMesh with vertex colours, keeps it in a static cache keyed by kind,
## layer, size, expression and eye level, and draws it. Every face of a
## kind on a board shares the same few meshes; the first of each state pays
## for the build.
##
## Every measure is in units of the face radius R, ported number for number
## from the approved canvas mock (docs/brainstorm/concepts.html#binairo:
## faceParts and the three bodies), so the game and the mock stay the same
## drawing.
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, section 4
## and the amendments at its end.
##
## Antialiasing: MSAA stays off for the whole 2D canvas, so every shape
## carries a feather -- a rim of vertices FEATHER pixels outside its outline
## at alpha 0, joined to the outline in a band. The band lies wholly outside
## the fill, so it never doubles the alpha of a translucent shape the way an
## outline centred on the edge would, and the shadows take it too.
##
## Measured 2026-09-18 on this Mac at 1080x1920 (the coordinator's probe,
## /tmp/_perf_flat.gd): the first version drew each part as its own canvas
## command, about fifty per face, and the flat board idled at 8.4 ms with
## 1449 render objects against 4.3 ms and 501 with the faces hidden; the
## compat renderer pays per command. Meshes bring a face down to one
## command (the sun to three: shadow, rays, body, because the rays turn
## between the other two).

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")

## HAPPY, JOY, WORRIED and SLEEPY are the flat Binairo's four. STRAIN and
## PUZZLED joined for Shikaku's markers, which wear four states and need
## four faces to tell them apart: a plot of the wrong size strains, and one
## holding two numbers or none is puzzled
## (docs/superpowers/specs/2026-09-18-shikaku-flat-design.md, section 4).
enum Expr { HAPPY, JOY, WORRIED, SLEEPY, STRAIN, PUZZLED }

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
## The feather's width, in the face's pixels.
const FEATHER := 1.5
## Pixels of arc per polygon segment, and the bounds on how many segments.
const ARC_STEP := 3.0
const ARC_MIN := 8
const ARC_MAX := 256
## eye_open is snapped to one of these for the cache; four levels are enough
## for a blink to read, and the blink's own ease does the rest.
const EYE_LEVELS: Array[float] = [0.1, 0.4, 0.7, 1.0]
## R is rounded to this many pixels for the cache key.
const R_STEP := 1.0
## How far the eyes move toward `look`, in the face's R.
const LOOK_SHIFT := 0.06
## A party hat's cone, stripes and pom-pom, per style.
const HAT_STYLES := [
	[Pal.FLOWER, Pal.SURFACE, Pal.SUN_RAY],
	[Pal.ACCENT, Pal.SUN_RAY, Pal.FLOWER],
	[Pal.BERRY, Pal.SURFACE, Pal.ACCENT],
]

## Every mesh built so far: "kind|layer|R[|expression|eye|plain]" -> ArrayMesh.
## Shared by every face; a mesh handed to draw_mesh has to stay referenced
## until the frame is rendered, and this keeps them for good.
static var _mesh_cache: Dictionary = {}

var expression: int = Expr.HAPPY:
	set(v):
		expression = v
		queue_redraw()
## While true, the face is read eyes open and looking ahead (bake_into's
## `rest`).
var _resting := false
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
## Fixes R as this fraction of the rect, whatever the subclass would have
## chosen; 0 leaves it to the subclass. Code Break seats every friend in the
## same square and wants the mock's own per-friend ratios there, so the six
## sit at comparable weights in one seat.
var radius_ratio := 0.0:
	set(v):
		radius_ratio = v
		queue_redraw()
## A silhouette: the whole drawing without eyes, mouth or cheeks. The compact
## history draws its friends this way -- 62 units is 22 pixels on a phone and
## a face there is a smudge.
var plain := false:
	set(v):
		plain = v
		queue_redraw()
## Leaves out the offset "shadow" layer: a face standing in the open (on
## Balance's seesaw, against the sky) rather than on a tile, where the ink
## disc reads as a grey halo instead of a shadow.
var shadowless := false:
	set(v):
		shadowless = v
		queue_redraw()
## Layers the owner draws itself, every face's at once (Binairo's board puts
## all its suns' shadows and rays in two MultiMesh draws, since a canvas
## command per layer per face was most of a full 10x10's draw calls). Empty
## draws every layer, as before.
var skip_layers: Array = []
## Whether set_idle(true) rocks this face. Only a moon reads it, and the owner
## turns it on for about a third of them so a board sways rather than nods.
var rocks := false
## Where the eyes look, each axis -1 to 1; the eyes shift LOOK_SHIFT of R
## toward it. Snapped to eight directions (or none) for the cache, so a
## glance costs one mesh per direction and never a rebuild per frame.
## Binairo's faces glance at a tapped tile.
var look := Vector2.ZERO:
	set(v):
		look = v
		queue_redraw()
## Accessories, 0 off to 1 on, each its own cached mesh drawn over the face's
## layers with the face layer's transform, so a moon's rock carries them. The
## value is the arrival: a hat grows from its brim, sunglasses slide down
## from above and fade in. Nothing is drawn at 0, so a board that never sets
## them pays nothing. Binairo's solve party and silly lines wear them.
var hat := 0.0:
	set(v):
		hat = v
		queue_redraw()
var glasses := 0.0:
	set(v):
		glasses = v
		queue_redraw()
## Which of HAT_STYLES the hat is.
var hat_style := 0

var _idle := false
## _mesh_for's last answer per layer: [key, mesh].
var _memo: Dictionary = {}
var _blink_tw: Tween
var _blink_wait: Tween
var _idle_tw: Tween

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
## decides the ratio in _radius_for (the sun's rays and the sprout's leaves
## reach past R).
func radius() -> float:
	return _R_for(minf(size.x, size.y))

## R for a rect `px` across, after the owner's ratio if it set one.
func _R_for(px: float) -> float:
	return px * radius_ratio if radius_ratio > 0.0 else _radius_for(px)

## R for a rect `px` across.
func _radius_for(px: float) -> float:
	return px * 0.5

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

# ---- the layers and their meshes ----

## The kind's name in the cache key.
func _kind() -> String:
	return "face"

## The layers a subclass draws, in order, each [name, carries_face]. A layer
## that carries the face is keyed by expression and eye level; one that does
## not is shared by every face of the kind and size.
func _layers() -> Array:
	return [["body", true]]

## The angle a layer is drawn at about the centre: the sun's rays turn by
## spin, the moon's body by rock. Drawing it as a transform means neither
## ever rebuilds a mesh, and the Control's own rotation stays the owner's
## (the board turns an outgoing face a quarter as it shrinks).
func _layer_angle(_name: String) -> float:
	return 0.0

## The whole transform a layer is drawn with, for a layer that moves by more
## than a turn about the centre: the bee's wings beat by a squash about her
## shoulder line (ui/faces/bee_face.gd). The base turns by _layer_angle, so a
## face that only turns overrides nothing new. `R` is the radius the mesh was
## built at, `centre` the rect's middle.
func _layer_transform(name: String, _R: float, centre: Vector2) -> Transform2D:
	return Transform2D(_layer_angle(name), centre)

## Appends a layer's shapes to `b`, in R. `eye` is the eye level after the
## expression's own rule (JOY ignores it, SLEEPY caps it). The subclass's
## drawing.
func _build_layer(_name: String, _R: float, _eye: float, _b: Builder) -> void:
	pass

func _draw() -> void:
	var R := roundf(_R_for(minf(size.x, size.y)) / R_STEP) * R_STEP
	if R <= 0.0:
		return
	var eye := _eye_level()
	var centre := size * 0.5
	for layer in _layers():
		if shadowless and layer[0] == "shadow":
			continue
		if skip_layers.has(layer[0]):
			continue
		var mesh := _mesh_for(layer[0], layer[1], R, eye)
		draw_mesh(mesh, null, _layer_transform(layer[0], R, centre))
	if hat > 0.0 or glasses > 0.0:
		_draw_accessories(R, centre)

## Appends the face as it is drawn now to `b`, under `xf` (this Control's
## own space to the baker's) and tinted: for a board that bakes a still row
## of faces into one mesh (Code Break's played rows, checkup 2026-10-01).
## A hat or glasses is baked only when fully on (exactly 1); a baker waits
## while one is arriving or leaving.
## `rest` bakes it eyes open and looking ahead whatever it is doing now, so
## a blink or a glance can be drawn by the face itself over its baked twin
## rather than asking for a new bake (Shikaku's signs, checkup 2026-10-01);
## `at_rest()` says whether the face as drawn is that twin. `b` is a Builder
## or a FlatBuilder.
func bake_into(b, xf: Transform2D, tint := Color.WHITE, rest := false) -> void:
	var R := roundf(_R_for(minf(size.x, size.y)) / R_STEP) * R_STEP
	if R <= 0.0:
		return
	_resting = rest
	var eye := _eye_level()
	var centre := size * 0.5
	for layer in _layers():
		if shadowless and layer[0] == "shadow":
			continue
		if skip_layers.has(layer[0]):
			continue
		b.append(_mesh_for(layer[0], layer[1], R, eye), xf * _layer_transform(layer[0], R, centre), tint)
	_resting = false
	# A hat or glasses fully on is baked as _draw_accessories draws it; one
	# on its way is not, and its baker should wait.
	if hat == 1.0 or glasses == 1.0:
		var face_layer := "body"
		for layer in _layers():
			if layer[1]:
				face_layer = layer[0]
		var at := xf * _layer_transform(face_layer, R, centre)
		var frame := _face_frame(R)
		if glasses == 1.0 and not plain:
			b.append(_accessory("glasses", roundf(frame[1]), 0), at * Transform2D(0.0, frame[0]), tint)
		if hat == 1.0:
			var seat: Array = _hat_place(R)
			b.append(_accessory("hat", roundf(float(seat[2])), hat_style),
				at * Transform2D(float(seat[1]), Vector2.ONE, 0.0, seat[0]), tint)

func at_rest() -> bool:
	if _look_index() != 0:
		return false
	var now := _eye_level()
	_resting = true
	var rest := _eye_level()
	_resting = false
	return now == rest

## The accessories over the face, in the face layer's transform: the hat on
## the head at _hat_place's seat, grown from its brim by `hat`; the glasses
## over the eyes, slid down from above and faded in by `glasses`.
func _draw_accessories(R: float, centre: Vector2) -> void:
	var face_layer := "body"
	for layer in _layers():
		if layer[1]:
			face_layer = layer[0]
	var xf := _layer_transform(face_layer, R, centre)
	var frame := _face_frame(R)
	var fc: Vector2 = frame[0]
	var fr: float = roundf(frame[1])
	if glasses > 0.0 and not plain:
		var g := clampf(glasses, 0.0, 1.0)
		var at := fc + Vector2(0.0, -(1.0 - g) * 0.9 * fr)
		draw_mesh(_accessory("glasses", fr, 0), null, xf * Transform2D(0.0, at),
			Color(1.0, 1.0, 1.0, clampf(g * 2.5, 0.0, 1.0)))
	if hat > 0.0:
		var seat: Array = _hat_place(R)
		var unit := roundf(float(seat[2]))
		draw_mesh(_accessory("hat", unit, hat_style), null,
			xf * Transform2D(float(seat[1]), Vector2.ONE * maxf(hat, 0.001), 0.0, seat[0]))

## The face's own centre and radius inside the drawing, in the rect-centred
## frame the layers use: where the glasses go. A face drawn off-centre (the
## moon's) says where.
func _face_frame(R: float) -> Array:
	return [Vector2.ZERO, R]

## Where the hat sits: [the brim's middle, its tilt, its size], in the same
## frame. The base seats it on top of the head.
func _hat_place(R: float) -> Array:
	return [Vector2(0.0, -0.8 * R), 0.0, 0.6 * R]

## An accessory's mesh at size `unit`, cached like the layers.
func _accessory(kind: String, unit: float, style: int) -> ArrayMesh:
	var key := "acc|%s|%d|%d" % [kind, int(unit), style]
	var mesh: ArrayMesh = _mesh_cache.get(key)
	if mesh == null:
		var b := Builder.new()
		if kind == "hat":
			_build_hat(b, unit, HAT_STYLES[style % HAT_STYLES.size()])
		else:
			_build_glasses(b, unit)
		mesh = b.mesh()
		_mesh_cache[key] = mesh
	return mesh

## A party hat, brim at the origin and pointing up, `u` across the brim and
## about 1.2 u tall: a cone, two stripes across it and a pom-pom on the tip.
static func _build_hat(b: Builder, u: float, colours: Array) -> void:
	var h := 1.2 * u
	var half := 0.5 * u
	var tip := Vector2(0.0, -h)
	b.polygon(PackedVector2Array([tip, Vector2(-half, 0.0), Vector2(half, 0.0)]), colours[0])
	for band: Vector2 in [Vector2(0.18, 0.32), Vector2(0.55, 0.68)]:
		var w0 := half * (1.0 - band.x)
		var w1 := half * (1.0 - band.y)
		b.polygon(PackedVector2Array([Vector2(-w0, -h * band.x), Vector2(w0, -h * band.x),
			Vector2(w1, -h * band.y), Vector2(-w1, -h * band.y)]), colours[1])
	# A band of shade along the brim, so the cone sits on the head.
	b.stroke(PackedVector2Array([Vector2(-half, 0.0), Vector2(half, 0.0)]), 0.1 * u, Color(colours[0].darkened(0.2)))
	b.disc(tip, 0.16 * u, colours[2])
	b.disc(tip + Vector2(-0.05, -0.05) * u, 0.06 * u, Color(1.0, 1.0, 1.0, 0.6))

## Sunglasses over a face of radius `r` centred on the origin: two dark
## rounded lenses over the eyes with a shine across each, the bridge and
## short arms.
static func _build_glasses(b: Builder, r: float) -> void:
	var ink := Pal.OUTLINE
	for sx: float in [-1.0, 1.0]:
		var c := Vector2(sx * 0.34, -0.1) * r
		var size := Vector2(0.46, 0.31) * r
		b.polygon(Builder.round_rect(c - size * 0.5, size, 0.1 * r), ink)
		b.stroke(PackedVector2Array([c + Vector2(-0.1, 0.05) * r, c + Vector2(0.0, -0.08) * r]), 0.05 * r, Color(1.0, 1.0, 1.0, 0.55))
		b.stroke(PackedVector2Array([c + Vector2(sx * 0.2, -0.08) * r, c + Vector2(sx * 0.32, -0.14) * r]), 0.05 * r, ink)
	b.stroke(Builder.arc_points(Vector2(0.0, -0.06) * r, 0.1 * r, PI * 1.15, PI * 1.85), 0.05 * r, ink)

## eye_open snapped to EYE_LEVELS and put through the expression's rule.
func _eye_level() -> float:
	if expression == Expr.JOY:
		return 1.0
	var open := 1.0 if _resting else eye_open
	var best: float = EYE_LEVELS[0]
	for lv in EYE_LEVELS:
		if absf(lv - open) < absf(best - open):
			best = lv
	if expression == Expr.SLEEPY:
		best = minf(best, SLEEPY_EYE)
	return best

func _mesh_for(layer: String, carries_face: bool, R: float, eye: float) -> ArrayMesh:
	# This face's last answer per layer, checked on plain numbers first: the
	# shared cache's string key cost more than the draw on a board that asks
	# every frame for a hundred faces (Binairo's MultiMesh, 2026-10-01).
	var memo_key := Vector4i(int(R), int(roundf(eye * 100.0)), expression, (int(plain) << 4) | _look_index()) \
		if carries_face else Vector4i(int(R), 0, 0, 0)
	# The kind is in the answer too: a tent pegged by a hint, a bee pinned or
	# a lantern lit changes its kind and nothing else (Tents checkup,
	# 2026-10-01: a hinted tent on a square tapped before kept its unpegged
	# fabric).
	var kind := _kind()
	var memo: Array = _memo.get(layer, [])
	if not memo.is_empty() and memo[0] == memo_key and memo[2] == kind:
		return memo[1]
	var mesh := _shared_mesh(layer, carries_face, R, eye)
	_memo[layer] = [memo_key, mesh, kind]
	return mesh

func _shared_mesh(layer: String, carries_face: bool, R: float, eye: float) -> ArrayMesh:
	var key := "%s|%s|%d" % [_kind(), layer, int(R)]
	if carries_face:
		key += "|%d|%d|%d|%d" % [expression, int(roundf(eye * 100.0)), int(plain), _look_index()]
	var mesh: ArrayMesh = _mesh_cache.get(key)
	if mesh == null:
		var b := Builder.new()
		_build_layer(layer, R, eye, b)
		mesh = b.mesh()
		_mesh_cache[key] = mesh
	return mesh

# ---- the face itself, in R ----

## Eyes, brows, mouth and cheeks for `expression` at eye level `eye`, at
## scale R about `centre`, in `ink`: number for number the mock's faceParts.
## HAPPY is round eyes with a catchlight and a smile; JOY shut arches over
## the open mouth with its tongue; WORRIED round eyes under slanted brows and
## a small round mouth; SLEEPY the happy face with its lids down; STRAIN the
## same slanted brows over a flat mouth; PUZZLED one raised brow over a
## small wavering frown.
func _face_parts(b: Builder, R: float, centre: Vector2, ink: Color, eye: float) -> void:
	if plain:
		return
	var i := _look_index()
	var dir := Vector2.ZERO if i == 0 else Vector2.from_angle((i - 1) * PI * 0.25)
	face_parts(b, R, centre, ink, eye, expression, dir)

## `look` snapped: 0 for straight ahead, 1 to 8 for the eight directions
## from the right, clockwise.
func _look_index() -> int:
	if _resting or look.length() < 0.3:
		return 0
	return posmod(roundi(look.angle() / (PI * 0.25)), 8) + 1

## The same face for a drawing that bakes one into its own mesh rather than
## standing a Control up for it (the caterpillar's head, ui/faces/caterpillar.gd).
## `look`, a unit direction or zero, moves the eyes LOOK_SHIFT of R toward it.
static func face_parts(b: Builder, R: float, centre: Vector2, ink: Color, eye: float, expression: int, look := Vector2.ZERO) -> void:
	var cheek := Color(Pal.CHEEK, 0.85)
	b.ellipse(centre + Vector2(-0.46, 0.16) * R, 0.13 * R, 0.09 * R, cheek)
	b.ellipse(centre + Vector2(0.46, 0.16) * R, 0.13 * R, 0.09 * R, cheek)
	for sx: float in [-1.0, 1.0]:
		var e := centre + Vector2(sx * 0.34, -0.1) * R + look * LOOK_SHIFT * R
		if expression == Expr.JOY:
			b.stroke(Builder.arc_points(e + Vector2(0.0, 0.04 * R), 0.13 * R, PI * 1.1, PI * 1.9), 0.075 * R, ink)
			continue
		b.ellipse(e, 0.1 * R, maxf(0.012 * R, 0.1 * R * eye), ink)
		if eye > 0.5:
			b.disc(e + Vector2(-0.03, -0.035) * R, 0.03 * R, Color(1.0, 1.0, 1.0, 0.9))
		if expression == Expr.WORRIED or expression == Expr.STRAIN:
			b.stroke(PackedVector2Array([e + Vector2(sx * 0.16, -0.2) * R, e + Vector2(-sx * 0.1, -0.3) * R]), 0.06 * R, ink)
		# One brow, and only the right one: two raised brows read as surprise,
		# where the mock's puzzled face is asking a question.
		if expression == Expr.PUZZLED and sx > 0.0:
			b.stroke(PackedVector2Array([e + Vector2(-0.14, -0.26) * R, e + Vector2(0.14, -0.2) * R]), 0.06 * R, ink)
	if expression == Expr.WORRIED:
		b.stroke(Builder.ring(centre + Vector2(0.0, 0.3 * R), 0.08 * R, 0.08 * R), 0.06 * R, ink, true)
		return
	if expression == Expr.STRAIN:
		b.stroke(PackedVector2Array([centre + Vector2(-0.16, 0.3) * R, centre + Vector2(0.16, 0.3) * R]), 0.06 * R, ink)
		return
	if expression == Expr.PUZZLED:
		# bezier2 carries its own start point and drops its end, so the last
		# point is appended rather than the first.
		var frown := Builder.bezier2(centre + Vector2(-0.16, 0.32) * R,
			centre + Vector2(0.0, 0.2) * R, centre + Vector2(0.16, 0.32) * R)
		frown.append(centre + Vector2(0.16, 0.32) * R)
		b.stroke(frown, 0.06 * R, ink)
		return
	var big := expression == Expr.JOY
	var mouth := centre + Vector2(0.0, (0.08 if big else 0.1) * R)
	var mr := (0.28 if big else 0.22) * R
	var from := PI * (0.1 if big else 0.18)
	var to := PI * (0.9 if big else 0.82)
	b.stroke(Builder.arc_points(mouth, mr, from, to), 0.07 * R, ink)
	if big:
		# The open mouth is the arc closed by its chord, and the tongue the
		# same over the middle. The tongue is the cheek laid at nine tenths
		# over the ink, baked to one colour since it always sits on the ink.
		b.fan(Builder.arc_points(mouth, mr, from, to), ink)
		b.fan(Builder.arc_points(mouth, mr, PI * 0.3, PI * 0.7), ink.lerp(Pal.CHEEK, 0.9))

## Collects triangles with vertex colours and turns them into a 2D ArrayMesh.
## Later shapes draw over earlier ones, the order the mock painted in. Every
## shape ends in a feather (see the header).
class Builder:
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()

	## How many segments an arc of `r` sweeping `sweep` radians takes.
	static func arc_n(r: float, sweep: float) -> int:
		return clampi(int(ceilf(absf(sweep) * r / ARC_STEP)), ARC_MIN, ARC_MAX)

	## Points along an arc of `r` about `centre` from `from` to `to`, a few
	## pixels apart; `to` below `from` runs the other way. The end point is
	## included, so a caller joining two arcs drops it.
	static func arc_points(centre: Vector2, r: float, from: float, to: float) -> PackedVector2Array:
		var n := arc_n(r, to - from)
		var pts := PackedVector2Array()
		pts.resize(n + 1)
		for i in n + 1:
			pts[i] = centre + Vector2.from_angle(lerpf(from, to, float(i) / n)) * r
		return pts

	## Points around an ellipse, without repeating the first.
	static func ring(centre: Vector2, rx: float, ry: float) -> PackedVector2Array:
		var n := arc_n(maxf(rx, ry), TAU)
		var pts := PackedVector2Array()
		pts.resize(n)
		for i in n:
			var a := TAU * i / n
			pts[i] = centre + Vector2(cos(a) * rx, sin(a) * ry)
		return pts

	## Points along a cubic curve from `p0` through the controls `c0` and `c1`
	## to `p1`, without the end point, so curves chain without a doubled
	## vertex. The canvas mock's bezierCurveTo.
	static func bezier3(p0: Vector2, c0: Vector2, c1: Vector2, p1: Vector2, steps := 18) -> PackedVector2Array:
		var pts := PackedVector2Array()
		pts.resize(steps)
		for i in steps:
			var t := float(i) / steps
			var u := 1.0 - t
			pts[i] = p0 * (u * u * u) + c0 * (3.0 * u * u * t) + c1 * (3.0 * u * t * t) + p1 * (t * t * t)
		return pts

	## Points along a quadratic curve from `p0` through `c` to `p1`, likewise
	## without the end point.
	static func bezier2(p0: Vector2, c: Vector2, p1: Vector2, steps := 14) -> PackedVector2Array:
		var pts := PackedVector2Array()
		pts.resize(steps)
		for i in steps:
			var t := float(i) / steps
			var u := 1.0 - t
			pts[i] = p0 * (u * u) + c * (2.0 * u * t) + p1 * (t * t)
		return pts

	## A rounded rectangle's outline, the mock's roundRect: `size` from `at`,
	## corners of `r`, capped at half the shorter side.
	static func round_rect(at: Vector2, size: Vector2, r: float) -> PackedVector2Array:
		var rr := minf(r, minf(size.x, size.y) * 0.5)
		var pts := PackedVector2Array()
		var corners := [
			[at + Vector2(size.x - rr, rr), -PI * 0.5, 0.0],
			[at + Vector2(size.x - rr, size.y - rr), 0.0, PI * 0.5],
			[at + Vector2(rr, size.y - rr), PI * 0.5, PI],
			[at + Vector2(rr, rr), PI, PI * 1.5],
		]
		for c in corners:
			var arc := arc_points(c[0], rr, c[1], c[2])
			pts.append_array(arc.slice(0, arc.size() - 1))
		return pts

	func vertex(p: Vector2, c: Color) -> int:
		verts.append(p)
		cols.append(c)
		return verts.size() - 1

	func tri(a: int, b: int, c: int) -> void:
		idx.append(a)
		idx.append(b)
		idx.append(c)

	func disc(centre: Vector2, r: float, colour: Color) -> void:
		fan(ring(centre, r, r), colour)

	func ellipse(centre: Vector2, rx: float, ry: float, colour: Color) -> void:
		fan(ring(centre, rx, ry), colour)

	## A convex outline as a fan about its centroid. (Written into local
	## arrays sized once, here and in stroke() and _feather(): a vertex at a
	## time through vertex() and tri() was most of what a board rebuilding
	## its meshes every frame paid.)
	func fan(points: PackedVector2Array, colour: Color) -> void:
		var n := points.size()
		var c := Vector2.ZERO
		for p in points:
			c += p
		var ci := verts.size()
		var vs := PackedVector2Array()
		vs.resize(n + 1)
		vs[0] = c / n
		for i in n:
			vs[i + 1] = points[i]
		var cs := PackedColorArray()
		cs.resize(n + 1)
		cs.fill(colour)
		verts.append_array(vs)
		cols.append_array(cs)
		var first := ci + 1
		var ix := PackedInt32Array()
		ix.resize(n * 3)
		for i in n:
			ix[i * 3] = ci
			ix[i * 3 + 1] = first + i
			ix[i * 3 + 2] = first + (i + 1) % n
		idx.append_array(ix)
		_feather(points, first, colour)

	## Any simple outline, concave allowed.
	func polygon(points: PackedVector2Array, colour: Color) -> void:
		var tris := Geometry2D.triangulate_polygon(points)
		var first := verts.size()
		for p in points:
			vertex(p, colour)
		for t in tris:
			idx.append(first + t)
		_feather(points, first, colour)

	## A stroke of `width` along the centreline `points`: open with round
	## caps (the canvas's lineCap round) or closed as a ring; `caps` false
	## leaves an open stroke's ends flat, the sun's highlight.
	func stroke(points: PackedVector2Array, width: float, colour: Color, closed := false, caps := true) -> void:
		var n := points.size()
		var half := width * 0.5
		var clear := Color(colour, 0.0)
		var base := verts.size()
		var vs := PackedVector2Array()
		var cs := PackedColorArray()
		vs.resize(n * 4)
		cs.resize(n * 4)
		for i in n:
			var prev := points[(i - 1 + n) % n] if closed or i > 0 else points[i]
			var next := points[(i + 1) % n] if closed or i < n - 1 else points[i]
			var t := (next - prev).normalized()
			var nrm := Vector2(-t.y, t.x)
			# Four across: outer feather, edge, edge, outer feather.
			var w := i * 4
			vs[w] = points[i] - nrm * (half + FEATHER)
			vs[w + 1] = points[i] - nrm * half
			vs[w + 2] = points[i] + nrm * half
			vs[w + 3] = points[i] + nrm * (half + FEATHER)
			cs[w] = clear
			cs[w + 1] = colour
			cs[w + 2] = colour
			cs[w + 3] = clear
		verts.append_array(vs)
		cols.append_array(cs)
		var segs := n if closed else n - 1
		if segs > 0:
			var ix := PackedInt32Array()
			ix.resize(segs * 18)
			var w := 0
			for i in segs:
				var a := base + i * 4
				var c := base + ((i + 1) % n) * 4
				for k in 3:
					ix[w] = a + k
					ix[w + 1] = c + k
					ix[w + 2] = c + k + 1
					ix[w + 3] = a + k
					ix[w + 4] = c + k + 1
					ix[w + 5] = a + k + 1
					w += 6
			idx.append_array(ix)
		if not closed and caps:
			disc(points[0], half, colour)
			disc(points[n - 1], half, colour)

	## The feather: a rim of vertices FEATHER outside the closed outline
	## `points` (whose vertices start at `first`), transparent, joined to the
	## outline in a band. Outward is read off the outline's winding.
	func _feather(points: PackedVector2Array, first: int, colour: Color) -> void:
		var n := points.size()
		var clear := Color(colour, 0.0)
		var area := 0.0
		for i in n:
			var j := (i + 1) % n
			area += points[i].x * points[j].y - points[j].x * points[i].y
		var out := 1.0 if area > 0.0 else -1.0
		var rim := verts.size()
		var vs := PackedVector2Array()
		vs.resize(n)
		for i in n:
			var e0 := (points[i] - points[(i - 1 + n) % n]).normalized()
			var e1 := (points[(i + 1) % n] - points[i]).normalized()
			var nrm := Vector2(e0.y, -e0.x) + Vector2(e1.y, -e1.x)
			if nrm.length_squared() < 1e-8:
				nrm = Vector2(e1.y, -e1.x)
			vs[i] = points[i] + nrm.normalized() * out * FEATHER
		var cs := PackedColorArray()
		cs.resize(n)
		cs.fill(clear)
		verts.append_array(vs)
		cols.append_array(cs)
		var ix := PackedInt32Array()
		ix.resize(n * 6)
		for i in n:
			var j := (i + 1) % n
			var w := i * 6
			ix[w] = first + i
			ix[w + 1] = first + j
			ix[w + 2] = rim + j
			ix[w + 3] = first + i
			ix[w + 4] = rim + j
			ix[w + 5] = rim + i
		idx.append_array(ix)

	## Another Builder-made mesh, moved by `xf` and tinted, over what is
	## here: how a board bakes many cached drawings into one.
	func append(m: ArrayMesh, xf: Transform2D, tint := Color.WHITE) -> void:
		var a := m.surface_get_arrays(0)
		var base := verts.size()
		for p in a[Mesh.ARRAY_VERTEX]:
			verts.append(xf * Vector2(p.x, p.y))
		for c: Color in a[Mesh.ARRAY_COLOR]:
			cols.append(c * tint)
		for i in a[Mesh.ARRAY_INDEX]:
			idx.append(base + i)

	func mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m

## A baker for meshes that are only ever appended whole, many times over:
## each source mesh is flattened once into a plain triangle list, so an
## append is two native array copies and no per-index loop. Builder.append
## offsets every index in script, which was 4-8 ms a bake for an Insane
## field's signs; this is a tenth of that (Shikaku's checkup, 2026-10-01).
## The output has no index array, four times the vertices. The flattened
## copies live in `cache`, which the caller owns and clears when the meshes
## it bakes are thrown away (a static one would keep every mesh ever baked).
class FlatBuilder:
	var _flat: Dictionary   # ArrayMesh -> [verts, cols]
	var verts := PackedVector2Array()
	var cols := PackedColorArray()

	func _init(cache = null) -> void:
		_flat = cache if cache != null else {}

	func append(m: ArrayMesh, xf: Transform2D, tint := Color.WHITE) -> void:
		var f: Array = _flat.get(m, [])
		if f.is_empty():
			f = _flatten(m)
			_flat[m] = f
		if xf == Transform2D.IDENTITY:
			verts.append_array(f[0])
		else:
			verts.append_array(xf * (f[0] as PackedVector2Array))
		if tint == Color.WHITE:
			cols.append_array(f[1])
		else:
			for c: Color in f[1]:
				cols.append(c * tint)

	## A flattened triangle list made elsewhere (`flat_of`), appended whole.
	func append_flat(f: Array) -> void:
		verts.append_array(f[0])
		cols.append_array(f[1])

	## A Builder's drawing as a plain triangle list, for a caller that keeps
	## its own cache of them and never needs the mesh.
	static func flat_of(b) -> Array:
		var v := PackedVector2Array()
		var c := PackedColorArray()
		v.resize(b.idx.size())
		c.resize(b.idx.size())
		for k in b.idx.size():
			v[k] = b.verts[b.idx[k]]
			c[k] = b.cols[b.idx[k]]
		return [v, c]

	static func _flatten(m: ArrayMesh) -> Array:
		var a := m.surface_get_arrays(0)
		var src_v: PackedVector2Array = a[Mesh.ARRAY_VERTEX]
		var src_c: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var v := PackedVector2Array()
		var c := PackedColorArray()
		v.resize(ix.size())
		c.resize(ix.size())
		for k in ix.size():
			v[k] = src_v[ix[k]]
			c[k] = src_c[ix[k]]
		return [v, c]

	func mesh() -> ArrayMesh:
		if verts.is_empty():
			return null
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = cols
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m
