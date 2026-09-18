extends SceneTree

## Preview one model slot in the real stage: toon materials, outlines, island
## sun and sky, camera at eye level rather than the board's top-down pitch.
##
##     godot --path . --resolution 720x720 --script res://tests/_shot_model.gd -- mascot_pom
##
## Saves /tmp/shot_model_<slot>.png. Use it to look at a .glb the game does not
## place yet.

const Models = preload("res://legacy/core/models.gd")

const PITCH := 12.0
const FRAMES := 30

var _slot := "mascot_pom"
var _model: Node3D
var _stage: Node
var _frames := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_slot = args[0]
	_stage = load("res://legacy/world/stage.tscn").instantiate()
	root.add_child(_stage)

func _process(_delta: float) -> bool:
	_frames += 1
	# The stage builds its rig and anchor in _ready, which lands after
	# _initialize, so mount on the first frame instead.
	if _frames == 2:
		_model = Models.instance(_slot)
		_stage.mount(_model)
		_stage.rig.pitch_deg = PITCH
		# A model is not a board: it should stand up, not lean, so the stage's
		# lean is undone and the rig is fitted directly rather than through
		# Stage.fit_camera, which would re-pitch and re-lean.
		_stage.anchor.transform.basis = Basis()
	elif _frames == 5:
		var box := AABB(_model.position, Vector3.ZERO)
		for mi in Models.meshes(_model):
			box = box.merge(mi.transform * mi.mesh.get_aabb())
		_stage.rig.fit(box, root.get_visible_rect())
	elif _frames == FRAMES:
		var path := "/tmp/shot_model_%s.png" % _slot
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
		return true
	return false
