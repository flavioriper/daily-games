extends SceneTree

## Every Gumdrop picture on one sheet, as the card draws it and as the
## clear jelly lies on the tray (floor and skin, no tint). Windowed:
##   godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_gumdrop_bank.gd -- <out.png>
## Run after touching `Mould.parts`.

const Mould = preload("res://puzzles/gumdrop_mould.gd")
const Art = preload("res://puzzles/gumdrop_art.gd")

var _sheet: Control
var _frames := 0
var _out := "/tmp/gd_bank.png"
var _meshes: Array = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_sheet = Control.new()
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.draw.connect(_draw)
	root.add_child(_sheet)

func _draw() -> void:
	var s := root.get_visible_rect().size
	_sheet.draw_rect(Rect2(Vector2.ZERO, s), Art.TABLE)
	var cols := 5
	var side := s.x / cols
	var u := (side - 12.0) / Mould.SIDE
	_meshes.clear()
	for i in Mould.PICTURES.size():
		var m := Mould.build(Mould.PICTURES[i])
		var at := Vector2((i % cols) * side + 6.0, (i / cols) * side * 1.0 + 6.0)
		var wide := i % 2 == 0
		if wide:
			_sheet.draw_rect(Rect2(at, Vector2.ONE * (side - 12.0)), Art.TRAY)
			_meshes.append(Art.floor_of(m, u))
			_sheet.draw_mesh(_meshes[-1], null, Transform2D(0.0, at))
			_meshes.append(Art.gloss_of(m, u))
			_sheet.draw_mesh(_meshes[-1], null, Transform2D(0.0, at))
			_meshes.append(Art.picture(m, u * 0.34))
			_sheet.draw_mesh(_meshes[-1], null, Transform2D(0.0, at))
		else:
			_meshes.append(Art.picture(m, u))
			_sheet.draw_mesh(_meshes[-1], null, Transform2D(0.0, at))

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 4:
		_sheet.queue_redraw()
	if _frames == 8:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		return true
	return false
