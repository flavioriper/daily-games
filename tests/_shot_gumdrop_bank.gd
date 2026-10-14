extends SceneTree

## Every Gumdrop picture on one sheet, as the card draws it and as the
## clear jelly lies on the tray (floor and skin, no tint). Windowed:
##   godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_gumdrop_bank.gd -- <out.png>
## Run after touching `Mould.parts`. With `themed` after the file, the
## night's themed jellies of tools/days/themed-pixel/ instead, day by day
## and band by band, every other one on the tray.

const Mould = preload("res://puzzles/gumdrop_mould.gd")
const Art = preload("res://puzzles/gumdrop_art.gd")

var _sheet: Control
var _frames := 0
var _out := "/tmp/gd_bank.png"
var _meshes: Array = []
var _list: Array = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	if args.size() > 1 and args[1] == "themed":
		var dir := "res://tools/days/themed-pixel/"
		for f in DirAccess.get_files_at(dir):
			var day = JSON.parse_string(FileAccess.get_file_as_string(dir + f)) if f.ends_with(".json") else null
			if not day is Dictionary or not day.get("pictures") is Dictionary or not day.pictures.get("jellies") is Dictionary:
				continue
			for key: String in ["0", "1", "2", "3"]:
				for j in day.pictures.jellies.get(key, []):
					var m := Mould.build_parts(String(j.id), Mould.from_doc(j.parts))
					print(f, " band ", key, ": ", j.id)
					_list.append(m)
	else:
		for id: String in Mould.PICTURES:
			_list.append(Mould.build(id))
	_sheet = Control.new()
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.draw.connect(_draw)
	root.add_child(_sheet)

func _draw() -> void:
	var s := root.get_visible_rect().size
	_sheet.draw_rect(Rect2(Vector2.ZERO, s), Art.TABLE)
	var cols := 5 if _list.size() <= 40 else 6
	var side := s.x / cols
	var u := (side - 12.0) / Mould.SIDE
	_meshes.clear()
	for i in _list.size():
		var m: Dictionary = _list[i]
		if m.is_empty():
			continue
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
