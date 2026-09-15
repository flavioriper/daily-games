extends "res://core/puzzle_base.gd"

## A PuzzleBase whose board lives in the 3D stage. The host still sees a
## Control filling the board slot: this class turns that slot into a camera
## frame and its touches into board-plane hits. Subclasses build into `board`
## and override the on_board_* hooks.

const BoardMath = preload("res://core/board_math.gd")

var board: Node3D
var _stage: Node
var _pressing := false

func is_3d() -> bool: return true

# --- to override ---
## Columns and rows of the board, in cells.
func board_size() -> Vector2i: return Vector2i(1, 1)
## How tall the tallest piece is; frames the camera.
func board_height() -> float: return 0.5
## Height of the surface taps land on (the tile tops).
func plane_height() -> float: return 0.0
## Camera pitch this board wants, in degrees above the horizontal; NAN takes
## the island's own. Only a board whose pieces mean something by their height
## should move it (see Stage.fit_camera).
func board_pitch() -> float: return NAN
func on_board_press(_hit: Vector3) -> void: pass
func on_board_drag(_hit: Vector3) -> void: pass
func on_board_release(_hit: Vector3) -> void: pass
# -------------------

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	board = Node3D.new()
	board.name = "%s_board" % puzzle_id()
	_stage = get_tree().get_first_node_in_group("stage")
	if _stage != null:
		_stage.mount(board)
	else:
		push_warning("PuzzleBase3D: no Stage in group 'stage'; board %s will not render and taps will miss" % board.name)
		add_child(board)
	resized.connect(_refit)
	_refit()

func _exit_tree() -> void:
	if is_instance_valid(board):
		if _stage != null and is_instance_valid(_stage):
			_stage.unmount(board)
		board.queue_free()

## Extra world units framed around the tiles on each side (a platform lip).
func board_margin() -> float: return 0.0
## Depth framed below the tile plane (the platform's thickness).
func board_depth() -> float: return 0.0

func board_aabb() -> AABB:
	var s := board_size()
	var box := BoardMath.board_aabb(s.x, s.y, board_height())
	var m := board_margin()
	var d := board_depth()
	return AABB(box.position - Vector3(m, d, m), box.size + Vector3(2.0 * m, d, 2.0 * m))

## This control's rectangle in viewport pixels, the space the camera projects into.
func viewport_rect() -> Rect2:
	return get_global_transform_with_canvas() * Rect2(Vector2.ZERO, size)

func _refit() -> void:
	if _stage == null or not is_inside_tree():
		return
	_stage.fit_camera(board_aabb(), viewport_rect(), board_pitch())

func _camera() -> Camera3D:
	return get_viewport().get_camera_3d()

## Board-plane point under a control-local position, or null when the ray misses.
func local_to_board(local: Vector2) -> Variant:
	var cam := _camera()
	if cam == null:
		return null
	var vp := get_global_transform_with_canvas() * local
	return BoardMath.ray_plane(cam.project_ray_origin(vp), cam.project_ray_normal(vp), plane_height())

## Control-local position of a world point; the inverse of local_to_board.
func board_to_local(world: Vector3) -> Vector2:
	var cam := _camera()
	if cam == null:
		return Vector2.INF
	return get_global_transform_with_canvas().affine_inverse() * cam.unproject_position(world)

## Touch events only. The project emulates touch from mouse, and the viewport
## hands a control both the mouse event and the emulated touch, so listening
## to both would fire twice per click.
func _gui_input(event: InputEvent) -> void:
	if is_done():
		return
	if event is InputEventScreenTouch:
		var hit = local_to_board(event.position)
		if event.pressed:
			if hit == null:
				return
			_pressing = true
			on_board_press(hit)
		elif _pressing:
			_pressing = false
			if hit != null:
				on_board_release(hit)
	elif event is InputEventScreenDrag and _pressing:
		var hit = local_to_board(event.position)
		if hit != null:
			on_board_drag(hit)
