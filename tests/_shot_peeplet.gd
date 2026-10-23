extends SceneTree

## The real Peeplet (ui/peeplet_view.gd: ~/dev/peeplet's walker, fur and glb
## in a SubViewport) in every pose its walker plays without a prop, one cell
## each, on paper. Windowed:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_peeplet.gd -- [live] [out=<dir>] [ink]
##
## `live` keeps the window open to watch; otherwise frames at 15 fps for four
## seconds go to <dir>/peeplet_<n>.png and it quits, printing the draw calls.
## Chop, dig and water swing empty hands: the tools stayed in ~/dev/peeplet.

const PeepletView = preload("res://ui/peeplet_view.gd")
const Pal = preload("res://core/palette.gd")

const POSES := ["idle", "walk", "run", "sit", "laugh", "grieve",
	"hot", "cold", "pick", "chop", "dig", "water"]
const COLS := 3
const ROWS := 4
const WARM := 1.0
const FRAMES := 60
const STEP := 1.0 / 15.0

var _t := 0.0
var _live := false
var _dir := "/tmp"
var _shot := 0
var _next := WARM
var _cells := []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "live":
			_live = true
		elif a == "ink":
			PeepletFur.ink = true
		elif a.begins_with("out="):
			_dir = a.substr(4)
	var bg := ColorRect.new()
	bg.color = Pal.PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var view := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	var w := view.x / COLS
	var h := view.y / ROWS
	for i in POSES.size():
		var at := Vector2((i % COLS) * w, (i / COLS) * h)
		var p := PeepletView.new()
		p.position = at + Vector2(0.0, 40.0)
		p.size = Vector2(w, h - 40.0)
		p.frame_height = 0.8 * (h - 40.0) / w
		bg.add_child(p)
		var label := Label.new()
		label.text = POSES[i]
		label.position = at + Vector2(16.0, 10.0)
		label.add_theme_color_override("font_color", Pal.TEXT)
		label.add_theme_font_size_override("font_size", 30)
		bg.add_child(label)
		_cells.append(p)

func _process(delta: float) -> bool:
	_t += delta
	for i in POSES.size():
		var walker: PeepletWalker = _cells[i].walker
		if walker == null:
			continue
		match POSES[i]:
			"walk":
				walker.walking = true
			"run":
				walker.walking = true
				walker.running = true
			"sit":
				walker.set_sitting(true)
			"grieve":
				walker.set_grieving(true)
			"hot":
				walker.set_comfort(1.0, 0.0)
			"cold":
				walker.set_comfort(0.0, 1.0)
			"laugh":
				if not walker.is_laughing():
					walker.trigger_laugh()
			"pick":
				if walker.pick_time < 0.0:
					walker.trigger_pick()
			"chop":
				if not walker.is_chopping():
					walker.trigger_chop()
			"dig":
				if not walker.is_chopping():
					walker.trigger_dig()
			"water":
				if not walker.is_chopping():
					walker.trigger_water()
	if _live:
		return false
	if _t >= _next:
		root.get_texture().get_image().save_png("%s/peeplet_%02d.png" % [_dir, _shot])
		_shot += 1
		_next += STEP
		if _shot >= FRAMES:
			print("draw calls: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			return true
	return false
