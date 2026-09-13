extends Node3D

## Fixed-direction board camera. The direction never changes (pitch below the
## horizontal, yaw around Y); fit() only moves the camera along that direction
## and slides its target so a given AABB fills a given screen rect.
## Projection needs a live viewport, so this is verified by the win and
## screenshot harnesses rather than by headless tests.

@export var pitch_deg: float = 68.0
@export var yaw_deg: float = 0.0
@export var fov_deg: float = 30.0
## Fraction of the rect's shorter side kept clear around the board.
@export var margin: float = 0.06

var camera: Camera3D
var _target := Vector3.ZERO
var _distance := 10.0

func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = fov_deg
	camera.near = 0.05
	camera.far = 200.0
	add_child(camera)
	camera.current = true
	_place()

## Unit vector from the target toward the camera: toward +Z (the player) and up.
func view_offset_dir() -> Vector3:
	var pitch := deg_to_rad(pitch_deg)
	var yaw := deg_to_rad(yaw_deg)
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()

func _place() -> void:
	camera.global_position = _target + view_offset_dir() * _distance
	camera.look_at(_target, Vector3.UP)

## Frames `aabb` inside `rect` (viewport pixels): binary-search the distance
## until every corner projects inside the margin-shrunk rect, then slide the
## target so the projected centre lands on the rect centre. Three passes
## converge well past a pixel.
func fit(aabb: AABB, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not is_inside_tree():
		return
	var inner := rect.grow(-minf(rect.size.x, rect.size.y) * margin)
	_target = aabb.get_center()
	for _pass in 3:
		_distance = _search_distance(aabb, inner)
		_place()
		var box := _projected(aabb)
		if box.size == Vector2.ZERO:
			return
		var delta := box.get_center() - inner.get_center()
		var per_px := _world_per_pixel()
		var b := camera.global_transform.basis
		_target += b.x * delta.x * per_px - b.y * delta.y * per_px
		_place()

func _search_distance(aabb: AABB, inner: Rect2) -> float:
	var lo := 0.5
	var hi := 200.0
	for _i in 28:
		_distance = (lo + hi) * 0.5
		_place()
		var box := _projected(aabb)
		if box.size != Vector2.ZERO and inner.encloses(box):
			hi = _distance
		else:
			lo = _distance
	return hi

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
## vertical FOV (Godot keeps height by default).
func _world_per_pixel() -> float:
	var vh := camera.get_viewport().get_visible_rect().size.y
	return 2.0 * _distance * tan(deg_to_rad(camera.fov) * 0.5) / maxf(vh, 1.0)
