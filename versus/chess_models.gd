extends SubViewportContainer

## Chess pieces that are real models, the way the Peeplet is (ui/peeplet_view.gd,
## the user, 2026-10-30: "a gd model like the peeplets, not drawed by hand").
## One transparent 3D world the size of the board holds every model piece, so
## 32 pieces cost one SubViewport and not 32. It renders only on a frame where
## something moved (`render_target_update_mode`), and a resting board costs
## nothing past showing the last picture.
##
## The camera is orthographic: the board under it is flat 2D, every row the
## same size, and a piece must stand where the board says whichever row it is
## on. A piece's foot lands exactly on the 2D foot pixel, and the camera's
## pitch hands the layer its depth, so near pieces cover far ones for free.

const PITCH := 22.0
## One white sun of energy 1 and no ambient: the toon shader writes its own
## light from it, as ui/peeplet_view.gd lights the props.
const SUN := Vector3(-0.449114, 0.821149, 0.352151)
const TOON := preload("res://world/toon_prop.gdshader")
## A piece turned a little, so its key and its gear both show.
const YAW := 0.42
const NAMES := {1: "pawn", 2: "knight", 3: "bishop", 4: "rook", 5: "queen", 6: "king"}
## Set to 0 if a phone can't afford the edges over a whole board.
const MSAA := Viewport.MSAA_4X

var _viewport: SubViewport
var _camera: Camera3D
var _forward := Vector3.FORWARD
var _up := Vector3.UP
## Actor -> {root, type, skin, xf}.
var _pieces := {}
var _scenes := {}
var _materials := {}
var _dirty := true
var _wait := 0.0

func _init() -> void:
	stretch = true
	mouse_filter = MOUSE_FILTER_IGNORE
	# As the Peeplet's: a transparent target leaves its colour premultiplied.
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	material = blend
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = MSAA
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.1
	_camera.far = 200.0
	_viewport.add_child(_camera)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.looking_at(-SUN, Vector3.UP), Vector3.ZERO)
	sun.light_energy = 1.0
	_viewport.add_child(sun)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	var pitch := deg_to_rad(PITCH)
	_forward = Vector3(0.0, -sin(pitch), -cos(pitch))
	_up = Vector3(0.0, cos(pitch), -sin(pitch))
	_camera.transform = Transform3D(Basis.looking_at(_forward, _up), -_forward * 60.0)

## Where a foot on the board lands in the world, `lift` cells up.
func _world(foot: Vector2, lift: float, cell: float) -> Vector3:
	var up_px := size.y * 0.5 - foot.y
	var sy := up_px / cell
	return Vector3((foot.x - size.x * 0.5) / cell, lift / cos(deg_to_rad(PITCH)), -sy / sin(deg_to_rad(PITCH)))

func _material(skin: RefCounted, name_of: String, seat: int) -> ShaderMaterial:
	var key := "%s|%s|%d" % [skin.id(), name_of, seat]
	var m: ShaderMaterial = _materials.get(key)
	if m == null:
		m = ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("albedo_tint", skin.model_tint(name_of, seat))
		_materials[key] = m
	return m

func _dress(node: Node, skin: RefCounted, seat: int) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			node.set_surface_override_material(i, _material(skin, mat.resource_name if mat != null else "Body", seat))
	for child in node.get_children():
		_dress(child, skin, seat)

func _make(type: int, skin: RefCounted, seat: int) -> Node3D:
	var path := "%s/%s.glb" % [skin.model_dir(), NAMES[type]]
	var scene: PackedScene = _scenes.get(path)
	if scene == null:
		scene = load(path)
		_scenes[path] = scene
	var root: Node3D = scene.instantiate()
	_dress(root, skin, seat)
	_viewport.add_child(root)
	return root

## Stands every model piece. `pieces` is [[actor, type, skin, seat, foot, lift,
## tilt, squash, scale, alpha, look, left, full]]; an actor gone from the list
## is taken off. Called from the board's _draw, so it runs at the board's rate.
func sync(pieces: Array, cell: float, clock: float, delta: float, resting: bool) -> void:
	var h := size.y / cell
	if not is_equal_approx(_camera.size, h):
		_camera.size = h
		_dirty = true
	var seen := {}
	for e: Array in pieces:
		var actor: Object = e[0]
		seen[actor] = true
		var p: Dictionary = _pieces.get(actor, {})
		if p.is_empty() or p.type != e[1] or p.skin != e[2]:
			if not p.is_empty():
				p.root.queue_free()
			p = {"root": _make(e[1], e[2], e[3]), "type": e[1], "skin": e[2], "xf": Transform3D()}
			_pieces[actor] = p
			_dirty = true
		var yaw: float = YAW if e[10] < 0.0 else PI - YAW
		var b := Basis(_forward, e[6]) * Basis.from_scale(Vector3(e[7].x, e[7].y, 1.0) * e[8]) * Basis(Vector3.UP, yaw)
		var xf := Transform3D(b, _world(e[4], e[5], cell))
		var show: bool = e[9] > 0.05
		if xf != p.xf or p.root.visible != show:
			p.xf = xf
			p.root.transform = xf
			p.root.visible = show
			_dirty = true
	for actor: Object in _pieces.keys():
		if not seen.has(actor):
			_pieces[actor].root.queue_free()
			_pieces.erase(actor)
			_dirty = true
	# A model's own moving parts run at their skin's few frames a second, and
	# never while the game rests (core/power.gd).
	_wait -= delta
	if _wait <= 0.0 and not resting:
		var hz := 0.0
		for e: Array in pieces:
			var skin: RefCounted = e[2]
			hz = maxf(hz, skin.model_hz())
			skin.model_tick(_pieces[e[0]].root, clock, e[11], e[12])
		if hz > 0.0:
			_wait = 1.0 / hz
			_dirty = true
	if _dirty:
		_dirty = false
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
