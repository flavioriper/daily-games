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
@export var fov_deg: float = 30.0
## Fraction of the rect's shorter side kept clear around the board.
@export var margin: float = 0.06
## Parallel projection instead of perspective, for a board that reads as a
## diorama of blocks rather than a scene with depth. A board asks for it on
## every fit through Stage.fit_camera, so fit() re-applies it rather than
## trusting whatever the last board left behind.
@export var orthographic: bool = false

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
## The last fit's arguments, so a turn can re-frame the board it left.
var _last_aabb := AABB()
var _last_rect := Rect2()
var _fitted := false

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
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if orthographic else Camera3D.PROJECTION_PERSPECTIVE

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
## distance; orthographic solves for the size (see _fit_ortho). The arguments
## are kept so turn() can re-fit at the stop it lands on without the board
## having to hand them over again.
func fit(aabb: AABB, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not is_inside_tree():
		return
	_apply_projection()
	_last_aabb = aabb
	_last_rect = rect
	_fitted = true
	if orthographic:
		_fit_ortho(aabb, rect)
	else:
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

## Swings the view a quarter turn per step and re-fits where it lands. The
## camera is re-placed on every step of the tween, not just at the end, so the
## board turns rather than jumping. The turn is the state change itself, so it
## is essential the way Motion.roll is: under reduce-motion it still turns,
## shortened and linear. The yaw is folded back into 0..360 at the end so
## repeated turns cannot drift it off into the thousands.
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
		if _fitted:
			fit(_last_aabb, _last_rect)
		elif camera != null:
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
## does not matter and the camera's size is that height already.
func _world_per_pixel() -> float:
	var vh := camera.get_viewport().get_visible_rect().size.y
	if orthographic:
		return camera.size / maxf(vh, 1.0)
	return 2.0 * _distance * tan(deg_to_rad(camera.fov) * 0.5) / maxf(vh, 1.0)
