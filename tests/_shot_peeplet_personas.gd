extends SceneTree

## Every Peeplet in peeplet/peeplet_personas.gd through the live view
## (ui/peeplet_view.gd), twelve a page, one PNG each. Windowed:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_peeplet_personas.gd -- out=<dir>

const PeepletView = preload("res://ui/peeplet_view.gd")
const Personas = preload("res://peeplet/peeplet_personas.gd")
const Pal = preload("res://core/palette.gd")
const COLS := 3
const ROWS := 4
const SETTLE := 1.2

var _out := "/tmp/peeplet_personas"
var _page := 0
var _t := 0.0
var _bg: ColorRect
var _cells: Array[Rect2] = []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	_bg = ColorRect.new()
	_bg.color = Pal.PAPER
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_bg)
	_lay()

func _lay() -> void:
	for c in _bg.get_children():
		c.queue_free()
	_cells.clear()
	var view := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	var w := view.x / COLS
	var h := view.y / ROWS
	for k in COLS * ROWS:
		var i := _page * COLS * ROWS + k
		if i >= Personas.count():
			break
		var p: Dictionary = Personas.get_persona(i)
		var cell := Rect2((k % COLS) * w, (k / COLS) * h, w, h)
		_cells.append(cell)
		var v := PeepletView.new()
		v.position = cell.position
		v.size = cell.size
		v.frame_height = 1.25 * h / w
		v.aim_y = 0.45
		v.color_index = int(p.coat)
		v.headgear = String(p.hat)
		v.eyewear = String(p.eyes)
		_bg.add_child(v)
	_t = 0.0

func _process(delta: float) -> bool:
	_t += delta
	if _t < SETTLE:
		return false
	var img := root.get_texture().get_image()
	var scale := float(img.get_width()) / float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	for k in _cells.size():
		var i := _page * COLS * ROWS + k
		var c := _cells[k]
		var region := Rect2i(Vector2i(c.position * scale), Vector2i(c.size * scale))
		img.get_region(region).save_png("%s/%02d_%s.png" % [_out, i, String(Personas.get_persona(i).name).to_lower()])
	print("page ", _page, " draw calls: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	_page += 1
	if _page * COLS * ROWS >= Personas.count():
		return true
	_lay()
	return false
