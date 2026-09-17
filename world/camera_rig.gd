extends Node3D

## Fixed-direction board camera. The direction never changes between fits
## (pitch below the horizontal, yaw around Y); fit() only moves the camera
## along that direction and slides its target so a given AABB fills a given
## screen rect. turn() is the one thing that swings the direction, a quarter
## at a time, for a board that is looked at from four stops.
## Between fits a tiny breath drifts camera and target together (see BREATH).
## Projection needs a live viewport, so this is verified by the win and
## screenshot harnesses rather than by headless tests.

@export var pitch_deg: float = 68.0
@export var yaw_deg: float = 0.0
## The frame spans pitch +/- fov/2, so the horizon (at 0.5 - pitch/fov down
## the frame) already shows at our 7-degree pitch with a 30-degree field --
## 26.7% down, not off the top. Widening to 40 buys two things instead: it
## pushes the horizon further down the frame, to 32.5%, giving more sky and
## less of the frame spent on foreground board; and it widens the field, so
## more landscape flanks the board on either side at the same pitch.
@export var fov_deg: float = 40.0
## Fraction of the rect's shorter side kept clear around the board.
@export var margin: float = 0.06
## Parallel projection instead of perspective, for a board that reads as a
## diorama of blocks rather than a scene with depth. A board asks for it on
## every fit through Stage.fit_camera, so fit() re-applies it rather than
## trusting whatever the last board left behind.
@export var orthographic: bool = false
## A shift lens, for a thing framed in one part of the screen rather than its
## middle: the horizontal field of view across the fitted rect, in degrees, or
## 0 for the ordinary perspective above. Under the ordinary perspective the
## camera's axis runs through the screen's centre, so holding a box in the top
## quarter of the frame means aiming well under it -- the box is then drawn far
## off-axis and steeply from above, and the only way to keep that mild is a
## narrow field, which flattens it. With the shift the axis aims straight at the
## box and the frustum is slid so that spot lands where the rect is, the way a
## tilt-shift lens holds a building upright: the rect is drawn exactly as a
## camera pointed at it would draw it, whatever the rest of the frame shows.
## Implemented as Camera3D's frustum projection with an offset. Godot 4.7's
## project_position and project_ray_normal ignore that offset's scaling with
## depth (unproject_position does not), so this rig derives rays and pixel
## sizes itself under a shift; see ray_normal and pixels_per_unit_at.
@export var shift_fov_deg: float = 0.0

## How long a quarter turn takes, in seconds.
const TURN_TIME := 0.35

const Motion = preload("res://core/motion.gd")

## Camera breath: camera and target drift together by this fraction of the
## fitted distance on two slow sine loops (8 s across, 11 s up), for a
## handheld-diorama calm. Off under reduce-motion or when breathing is false.
## Try-and-keep per the polish spec: drop it if the strip reads as wobble.
const BREATH := 0.002
var breathing := true
var _breath := Vector3.ZERO
var _breath_t := 0.0

var camera: Camera3D
var _target := Vector3.ZERO
var _distance := 10.0
## The rect the shift lens was last fitted to, in viewport pixels; the frustum
## offset is derived from where its centre sits in the viewport.
var _shift_rect := Rect2()

func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = fov_deg
	camera.near = 0.05
	camera.far = 200.0
	_apply_projection()
	add_child(camera)
	camera.current = true
	_place()

## Unit vector from the target toward the camera: toward +Z (the player) and up.
func view_offset_dir() -> Vector3:
	return _dir_at(yaw_deg)

## The camera's right at an arbitrary yaw, so Stage can lean the board at a
## turn's other three stops -- to union their boxes for the ortho no-swell
## fit -- without moving the camera to any of them first.
func right_at(yaw_deg_at: float) -> Vector3:
	var right := Vector3.UP.cross(_dir_at(yaw_deg_at))
	return right.normalized() if right.length_squared() > 1e-6 else Vector3.RIGHT

## The same vector at an arbitrary yaw, so the ortho fit can measure the board
## at the three stops it is not standing on without moving the camera there.
func _dir_at(yaw_deg_at: float) -> Vector3:
	var pitch := deg_to_rad(pitch_deg)
	var yaw := deg_to_rad(yaw_deg_at)
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()

## The camera's orthonormal basis at a yaw: x right, y up, z toward the camera.
## Matches what look_at builds in _place, so its transpose takes a world point
## into camera space.
func _view_basis(yaw_deg_at: float) -> Basis:
	var dir := _dir_at(yaw_deg_at)
	var right := Vector3.UP.cross(dir).normalized()
	return Basis(right, dir.cross(right), dir)

## Puts the camera into the projection `orthographic` asks for. Called when the
## camera is built and again on every fit, because the flag is a board's and
## boards take turns.
func _apply_projection() -> void:
	if camera == null:
		return
	if orthographic:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	elif shifted():
		_apply_shift()
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = fov_deg

## Whether the shift lens is in effect: a field was asked for and a rect to
## hold has been fitted.
func shifted() -> bool:
	return shift_fov_deg > 0.0 and _shift_rect.size.x > 0.0 and _shift_rect.size.y > 0.0

## The frustum that draws _shift_rect as a camera of shift_fov_deg pointed at
## its centre would. Camera3D's frustum `size` is the near plane's height
## (keep_aspect KEEP_HEIGHT) and its offset slides that plane in the same
## units, so: the near plane is wide enough that the rect's share of it spans
## the field, and it is slid by the rect centre's distance from the viewport's
## centre, as a fraction of the plane.
func _apply_shift() -> void:
	var vs := camera.get_viewport().get_visible_rect().size
	var width := 2.0 * camera.near * tan(deg_to_rad(shift_fov_deg) * 0.5) * vs.x / _shift_rect.size.x
	var height := width * vs.y / vs.x
	# Sliding the frustum toward +x or +y moves the axis's image the other
	# way, and screen y runs down: the axis lands at 0.5 - ox/width across and
	# 0.5 + oy/height down.
	var c := _shift_rect.get_center()
	var offset := Vector2((0.5 - c.x / vs.x) * width, (c.y / vs.y - 0.5) * height)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.set_frustum(height, offset, camera.near, camera.far)

func _place() -> void:
	camera.global_position = _target + _breath + view_offset_dir() * _distance
	camera.look_at(_target + _breath, Vector3.UP)

## The breath offset applied on top of the fitted position.
func breath_offset() -> Vector3:
	return _breath

func _process(delta: float) -> void:
	if not breathing or Motion.reduce:
		if not _breath.is_zero_approx():
			_breath = Vector3.ZERO
			_place()
		return
	_breath_t += delta
	var dir := view_offset_dir()
	var right := Vector3.UP.cross(dir).normalized()
	var up := dir.cross(right)
	var a := _distance * BREATH
	_breath = right * (sin(_breath_t * TAU / 8.0) * a) + up * (0.6 * sin(_breath_t * TAU / 11.0) * a)
	_place()

## Frames `aabb` inside `rect` (viewport pixels). Perspective searches for the
## distance; orthographic solves for the size (see _fit_ortho). Does not keep
## its arguments for turn() to reuse: a turn changes the board's lean, which
## changes the world box this has to frame, and only Stage knows the lean and
## the board-local box it acts on, so Stage re-fits explicitly instead.
func fit(aabb: AABB, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not is_inside_tree():
		return
	_shift_rect = rect if shift_fov_deg > 0.0 else Rect2()
	_apply_projection()
	if orthographic:
		_fit_ortho(aabb, rect)
	else:
		# The shift lens searches the distance the same way: the frustum is
		# fixed by the rect, so only how far back the camera stands is open.
		_fit_perspective(aabb, rect)

## Binary-searches the distance until every corner projects inside the
## margin-shrunk rect, re-centring the board at every step. The centring has to
## happen inside the search: under perspective the near edge grows faster than
## the far edge as the camera closes in, so a box centred at one distance hangs
## low at a nearer one, and a search that only re-centres between passes stops
## a quarter too far out on a deep board.
func _fit_perspective(aabb: AABB, rect: Rect2) -> void:
	var inner := rect.grow(-minf(rect.size.x, rect.size.y) * margin)
	_target = aabb.get_center()
	var lo := 0.5
	var hi := 200.0
	for _i in 28:
		_distance = (lo + hi) * 0.5
		var box := _centred_box(aabb, inner)
		if box.size != Vector2.ZERO and inner.encloses(box):
			hi = _distance
		else:
			lo = _distance
	_distance = hi
	_centred_box(aabb, inner)

## An orthographic projection is linear, so no search is needed: the box's
## extent in camera space is the size on screen, and one centring pass is
## exact. The size is taken at all four quarter stops and the largest wins --
## a quarter turn swings a different diagonal of the box across the screen, so
## a size fitted at this yaw alone would make the board swell and shrink as it
## turns, and the whole point of the four stops is that only the angle changes.
## The distance does not affect the size at all here; it only has to keep the
## box between near and far, so the camera simply stands a diagonal plus a
## comfortable margin back.
func _fit_ortho(aabb: AABB, rect: Rect2) -> void:
	var want := 0.0
	for k in 4:
		want = maxf(want, _ortho_size(aabb, rect, yaw_deg + 90.0 * k))
	camera.size = want
	_distance = aabb.size.length() + 20.0
	_target = aabb.get_center()
	_centred_box(aabb, rect)

## The camera size (the world height the full viewport spans) the box needs at
## `yaw`: its span in camera space measured against the rect's share of the
## viewport, widened so the margin stays clear on each side.
func _ortho_size(aabb: AABB, rect: Rect2, yaw: float) -> float:
	var to_camera := _view_basis(yaw).transposed()
	var lo := to_camera * aabb.get_endpoint(0)
	var hi := lo
	for i in range(1, 8):
		var p := to_camera * aabb.get_endpoint(i)
		lo = lo.min(p)
		hi = hi.max(p)
	var span := hi - lo
	# The height the box needs across the rect: its own, or the height the
	# rect has when the box's width just fills the rect's width.
	var height := maxf(span.y, span.x * rect.size.y / rect.size.x)
	var vh: float = camera.get_viewport().get_visible_rect().size.y
	return height / (1.0 - 2.0 * margin) * vh / rect.size.y

## Swings the view a quarter turn per step and re-places the camera at every
## step, not just at the end, so the board turns rather than jumping. It does
## not re-fit where it lands: a turn changes the board's lean (Stage's, not
## this rig's), which changes the world box that would have to be framed, and
## this rig knows neither the lean nor the board-local box it acts on. Stage
## is this method's only caller; it re-leans and re-fits itself once the
## callback below has folded the yaw back into 0..360 -- which happens here,
## rather than left to drift, so repeated turns cannot carry it off into the
## thousands. The turn is the state change itself, so it is essential the way
## Motion.roll is: under reduce-motion it still turns, shortened and linear.
func turn(steps: int) -> Tween:
	if not is_inside_tree():
		return null
	var to := yaw_deg + 90.0 * steps
	var swing := func(v: float) -> void:
		yaw_deg = v
		if camera != null:
			_place()
	var tw := create_tween()
	if Motion.reduce:
		tw.tween_method(swing, yaw_deg, to, Motion.REDUCED_TIME).set_trans(Tween.TRANS_LINEAR)
	else:
		tw.tween_method(swing, yaw_deg, to, TURN_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		yaw_deg = fposmod(to, 360.0)
		if camera != null:
			_place())
	return tw

## Places the camera at _distance, slides the target so the projected box sits
## on `into`'s centre, and returns the box from there; a zero rect when a
## corner is behind the camera.
func _centred_box(aabb: AABB, into: Rect2) -> Rect2:
	_place()
	var box := _projected(aabb)
	if box.size == Vector2.ZERO:
		return box
	var delta := box.get_center() - into.get_center()
	var per_px := _world_per_pixel()
	var b := camera.global_transform.basis
	_target += b.x * delta.x * per_px - b.y * delta.y * per_px
	_place()
	return _projected(aabb)

## Screen bounding box of the AABB corners, or a zero rect when any corner is
## behind the camera.
func _projected(aabb: AABB) -> Rect2:
	var box := Rect2()
	for i in 8:
		var p := aabb.get_endpoint(i)
		if camera.is_position_behind(p):
			return Rect2()
		var s := camera.unproject_position(p)
		box = Rect2(s, Vector2.ZERO) if i == 0 else box.expand(s)
	return box

## World units per viewport pixel on the plane through the target, using the
## vertical FOV (Godot keeps height by default). Orthographically the plane
## does not matter and the camera's size is that height already. Under the
## shift lens neither formula holds, so it is measured off the projection.
func _world_per_pixel() -> float:
	var vh := camera.get_viewport().get_visible_rect().size.y
	if orthographic:
		return camera.size / maxf(vh, 1.0)
	if shifted():
		return 1.0 / pixels_per_unit_at(_target)
	return 2.0 * _distance * tan(deg_to_rad(camera.fov) * 0.5) / maxf(vh, 1.0)

## How many viewport pixels one world unit covers at `point`, measured along
## `along` (a unit vector; the camera's right when left out). Reliable under
## every projection, unlike a formula in the FOV, because unproject_position
## is the one Camera3D helper that reads the real projection matrix in
## frustum mode.
func pixels_per_unit_at(point: Vector3, along := Vector3.ZERO) -> float:
	var dir: Vector3 = camera.global_transform.basis.x if along.is_zero_approx() else along.normalized()
	var px := camera.unproject_position(point + dir).distance_to(camera.unproject_position(point))
	return maxf(px, 1e-6)

## The world-space ray through viewport pixel `px`: origin, then direction.
## Camera3D's own project_ray_* pair mis-scales the frustum offset, so under a
## shift the ray is taken through the projection matrix's inverse instead.
func ray_origin(px: Vector2) -> Vector3:
	if not shifted():
		return camera.project_ray_origin(px)
	return camera.global_position

func ray_normal(px: Vector2) -> Vector3:
	if not shifted():
		return camera.project_ray_normal(px)
	var vs := camera.get_viewport().get_visible_rect().size
	var ndc := Vector2(px.x / vs.x * 2.0 - 1.0, 1.0 - px.y / vs.y * 2.0)
	var inv := camera.get_camera_projection().inverse()
	var a4 := inv * Vector4(ndc.x, ndc.y, -1.0, 1.0)
	var b4 := inv * Vector4(ndc.x, ndc.y, 1.0, 1.0)
	var a := Vector3(a4.x, a4.y, a4.z) / a4.w
	var b := Vector3(b4.x, b4.y, b4.z) / b4.w
	return (camera.global_transform.basis * (b - a)).normalized()
