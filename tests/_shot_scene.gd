extends SceneTree

## Screenshots any scene once it has settled, so a staged composition can be
## looked at outside the editor's viewport gizmos.
##
##     godot --path . --resolution 1280x720 --script res://tests/_shot_scene.gd \
##         -- res://tests/preview_tree.tscn
##
## Saves /tmp/shot_<scene name>.png. Run it windowed: a headless run draws
## nothing to save.

const SHOT_AT := 1.2

var _path := "res://tests/preview_tree.tscn"
var _t := 0.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_path = args[0]
	root.add_child(load(_path).instantiate())

func _process(delta: float) -> bool:
	_t += delta
	if _t < SHOT_AT:
		return false
	# The viewport texture is whatever was last drawn, and a windowed run that
	# loses focus stops drawing; force one frame before reading it.
	RenderingServer.force_draw()
	var out := "/tmp/shot_%s.png" % _path.get_file().get_basename()
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	return true
