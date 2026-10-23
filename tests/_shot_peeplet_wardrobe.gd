extends SceneTree

## Every coat, hat and eyewear piece the Peeplet (ui/peeplet_view.gd) brought
## over from ~/dev/peeplet, a cell each on paper. Windowed:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_peeplet_wardrobe.gd -- <colors|hats|eyewear> out=<png> [ink]

const PeepletView = preload("res://ui/peeplet_view.gd")
const Pal = preload("res://core/palette.gd")
const SHOT_AT := 2.0

var _page := "colors"
var _out := "/tmp/peeplet_wardrobe.png"
var _t := 0.0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
		elif a == "ink":
			PeepletFur.ink = true
		else:
			_page = a
	var cells := []
	match _page:
		"colors":
			for i in PeepletPalette.count():
				cells.append([PeepletPalette.names()[i], i, "", ""])
		"hats":
			for kind in HeadgearItemFactory.kinds():
				cells.append([kind, 0, kind, ""])
		"eyewear":
			for kind in EyewearItemFactory.kinds():
				cells.append([kind, 0, "", kind])
	var bg := ColorRect.new()
	bg.color = Pal.PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var view := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	var cols := 3 if cells.size() <= 12 else 4
	var rows := ceili(float(cells.size()) / cols)
	var w := view.x / cols
	var h := view.y / rows
	for i in cells.size():
		var at := Vector2((i % cols) * w, (i / cols) * h)
		var p := PeepletView.new()
		p.position = at + Vector2(0.0, 34.0)
		p.size = Vector2(w, h - 34.0)
		p.frame_height = 0.9 * (h - 34.0) / w
		p.color_index = cells[i][1]
		p.headgear = cells[i][2]
		p.eyewear = cells[i][3]
		bg.add_child(p)
		var label := Label.new()
		label.text = cells[i][0]
		label.position = at + Vector2(12.0, 6.0)
		label.add_theme_color_override("font_color", Pal.TEXT)
		label.add_theme_font_size_override("font_size", 26)
		bg.add_child(label)

func _process(delta: float) -> bool:
	_t += delta
	if _t >= SHOT_AT:
		root.get_texture().get_image().save_png(_out)
		print("draw calls: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		return true
	return false
