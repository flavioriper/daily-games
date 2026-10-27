extends SceneTree

## The Peeplet reference sheet: the live Peeplet (ui/peeplet_view.gd) in eight
## cells on flat paper, one PNG, for the image model that paints Peeplets into
## the day's pictures and for the reviewer that checks them. Windowed:
##
##     godot --path . --resolution 2048x1024 --always-on-top --script res://tests/_shot_peeplet_sheet.gd -- [out=<png>] [ink]
##
## Front, three-quarter, side and back (coat 0, coral), sitting and laughing
## (coat 0), a sunhat (coat 5) and round glasses (coat 6). The default `out` is
## server/functions/assets/peeplet_sheet.png; `ink` turns the line round the
## coat on (PeepletFur.ink, off in the repo). Frame, not video: one PNG after
## the warm-up, the laugh frozen at its bounce's peak.

const PeepletView = preload("res://ui/peeplet_view.gd")
const Pal = preload("res://core/palette.gd")

# pose, label, turn, coat, hat, eyewear
const CELLS := [
	["idle", "front", 0.0, 0, "", ""],
	["idle", "three-quarter", 35.0, 0, "", ""],
	["idle", "side", 90.0, 0, "", ""],
	["idle", "back", 180.0, 0, "", ""],
	["sit", "sitting", 0.0, 0, "", ""],
	["laugh", "laughing (bounce)", 0.0, 0, "", ""],
	["idle", "sunhat", 0.0, 5, "sunhat", ""],
	["idle", "round glasses", 0.0, 6, "", "roundglasses"],
]
const COLS := 4
const ROWS := 2
const LABEL_H := 64.0
## The laugh (peeplet_walker.gd: LAUGH_DURATION 1.6 s, bounce 6.5 Hz under a
## sin swell, body squash 0.085 and a 14 degree rock back; it never opens a
## mouth) is triggered LAUGH_AT seconds in and the cell is frozen when the
## walker's own laugh_time reaches LAUGH_PEAK, where the bounce is at its
## tallest (5.25 bounces = 0.8077 s) under the swell's crest. Frozen means the
## walker is put to sleep (set_idle) and its picture drawn once more, so the
## frame is the walker's, not the wall clock's. The PNG is saved SAVE_LAG
## frames later: the viewport draws a frame behind the walker, the root a
## frame behind that.
const LAUGH_AT := 0.5
const LAUGH_PEAK := 0.80
const SAVE_LAG := 4
const SIZE := Vector2i(2048, 1024)

var _t := 0.0
var _out := "res://server/functions/assets/peeplet_sheet.png"
var _cells := []
var _laughed := false
var _frozen := -1

func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for a in OS.get_cmdline_user_args():
		if a == "ink":
			PeepletFur.ink = true
		elif a.begins_with("out="):
			_out = a.substr(4)

## The window has no size yet in _initialize (the cells collapsed to a corner),
## so the sheet is laid out on the first frame, from the root's real size.
func _lay() -> void:
	var bg := ColorRect.new()
	bg.color = Pal.PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var w := float(root.size.x) / COLS
	var h := float(root.size.y) / ROWS
	for i in CELLS.size():
		var c: Array = CELLS[i]
		var at := Vector2((i % COLS) * w, (i / COLS) * h)
		var p := PeepletView.new()
		p.position = at
		p.size = Vector2(w, h - LABEL_H)
		p.frame_height = 0.95
		p.aim_y = 0.36
		p.turn = c[2]
		p.color_index = c[3]
		p.headgear = c[4]
		p.eyewear = c[5]
		bg.add_child(p)
		if c[0] == "sit":
			p.walker.set_sitting(true)
		var label := Label.new()
		label.text = c[1]
		label.position = at + Vector2(0.0, h - LABEL_H)
		label.size = Vector2(w, LABEL_H)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Pal.TEXT)
		label.add_theme_font_size_override("font_size", 30)
		bg.add_child(label)
		_cells.append(p)

func _process(delta: float) -> bool:
	if _cells.is_empty():
		_lay()
		if root.size != SIZE:
			push_warning("sheet window is %s, not %s: pass --resolution 2048x1024 before --script" % [root.size, SIZE])
			print("WARNING: window ", root.size, ", expected ", SIZE)
		return false
	_t += delta
	var laugher: Node = _cells[CELLS.find_custom(func(c): return c[0] == "laugh")]
	var walker: PeepletWalker = laugher.walker
	if not _laughed and _t >= LAUGH_AT:
		walker.trigger_laugh()
		_laughed = true
	elif _laughed and _frozen < 0 and walker.laugh_time >= LAUGH_PEAK:
		laugher.set_idle(false)
		laugher._viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_frozen = 0
		print("laugh frozen at laugh_time ", snappedf(walker.laugh_time, 0.001))
	elif _frozen >= 0:
		_frozen += 1
		if _frozen >= SAVE_LAG:
			root.get_texture().get_image().save_png(_out)
			print("saved ", _out, " ", root.size, " ink=", PeepletFur.ink)
			print("draw calls: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			return true
	return false
