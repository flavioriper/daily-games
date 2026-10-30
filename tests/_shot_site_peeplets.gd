extends SceneTree

## The website's Peeplets: the live Peeplet (ui/peeplet_view.gd) in eight
## cells, each saved on its own from its transparent SubViewport, for the
## landing page (web/, docs/agents/website.md). The user, 2026-10-30: "i'm
## missing some peeplets around the page". Rendered, never hand-edited, like
## the reference sheet (tests/_shot_peeplet_sheet.gd). Windowed:
##
##     godot --path . --resolution 1600x800 --always-on-top --script res://tests/_shot_site_peeplets.gd
##
## Writes build/site_peeplets/<name>.png (premultiplied alpha, as the viewport
## hands it over; web/scripts/gen_games.py straightens and trims them). The
## laugh is frozen at its bounce's peak as the sheet does it.

const PeepletView = preload("res://ui/peeplet_view.gd")

# name, coat, hat, eyewear, turn, pose
const CELLS := [
	["coral", 0, "", "", 22.0, "idle"],
	["sunhat", 5, "sunhat", "", -28.0, "idle"],
	["reader", 3, "cap", "roundglasses", 8.0, "sit"],
	["laugh", 2, "beanie", "", 30.0, "laugh"],
	["mushroom", 6, "mushroomCap", "roundglasses", -14.0, "idle"],
	["watcher", 4, "bow", "", 150.0, "idle"],
	["party", 1, "partyHat", "", 12.0, "idle"],
	["flowers", 7, "flowerCrown", "", -34.0, "sit"],
]
const COLS := 4
const ROWS := 2
const SIZE := Vector2i(1600, 800)
const OUT := "res://build/site_peeplets"
const LAUGH_AT := 0.5
const LAUGH_PEAK := 0.80
const SAVE_LAG := 4

var _t := 0.0
var _cells := []
var _laughed := false
var _frozen := -1

func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED

func _lay() -> void:
	var w := float(root.size.x) / COLS
	var h := float(root.size.y) / ROWS
	for i in CELLS.size():
		var c: Array = CELLS[i]
		var p := PeepletView.new()
		p.position = Vector2((i % COLS) * w, (i / COLS) * h)
		p.size = Vector2(w, h)
		p.frame_height = 1.0
		p.aim_y = 0.34
		p.turn = c[4]
		p.color_index = c[1]
		p.headgear = c[2]
		p.eyewear = c[3]
		root.add_child(p)
		if c[5] == "sit":
			p.seated = true
		_cells.append(p)

func _process(delta: float) -> bool:
	if _cells.is_empty():
		_lay()
		if root.size != SIZE:
			print("WARNING: window ", root.size, ", expected ", SIZE)
		return false
	_t += delta
	var laugher: Node = _cells[CELLS.find_custom(func(c): return c[5] == "laugh")]
	var walker: PeepletWalker = laugher.walker
	if not _laughed and _t >= LAUGH_AT:
		walker.trigger_laugh()
		_laughed = true
	elif _laughed and _frozen < 0 and walker.laugh_time >= LAUGH_PEAK:
		for p in _cells:
			p.set_idle(false)
			p._viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_frozen = 0
	elif _frozen >= 0:
		_frozen += 1
		if _frozen >= SAVE_LAG:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
			for i in _cells.size():
				var img: Image = _cells[i]._viewport.get_texture().get_image()
				var path := "%s/%s.png" % [OUT, CELLS[i][0]]
				img.save_png(path)
				print("saved ", path, " ", img.get_size())
			print("draw calls: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			return true
	return false
