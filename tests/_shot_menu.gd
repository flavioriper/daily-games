extends SceneTree

## The first screen, after the entrance has landed, and again with the More
## sheet up -- or, with `page2` after `--`, turned to its second page instead
## of opening More. Sudoku's task 7 (2026-09-20) needed page two's own
## draw-call reading and had no committed way to retake it; this is that way,
## rather than a throwaway probe whose number nothing in the tree can
## reproduce.
##
##     godot --path . --resolution 540x960 --script res://tests/_shot_menu.gd
##     godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd -- page2
##
## Saves /tmp/shot_menu_1.png and /tmp/shot_menu_2.png (or, under `page2`,
## /tmp/shot_menu_1.png and /tmp/shot_menu_page2.png), and prints the mean
## frame time and the peak draw-call count over the idle window before each
## shot, so a change to the first screen can be measured as well as looked
## at.

const FIRST_AT := 1.8
const SECOND_AT := 2.8
const IDLE_FROM := 0.8
## `page2`: how long after the turn to wait before the second shot -- the
## crossfade out and the incoming cards' entrance (`ui/menu.gd`'s
## `ENTER_FADE`, 0.3 s, plus the second card's own stagger, `CARD_STEP` 0.05,
## page two having held two cards since Sudoku landed beside Mushroom Patch)
## with margin -- and how much of that tail counts as its idle window.
const PAGE2_SETTLE := 1.0
const PAGE2_IDLE := 0.3

var _menu: Node
var _t := 0.0
var _phase := 0
var _idle: Array[float] = []
var _draws := 0
var _page2 := false

func _initialize() -> void:
	_page2 = OS.get_cmdline_user_args().has("page2")
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if _phase == 0 and _t >= IDLE_FROM:
		_idle.append(delta * 1000.0)
		_draws = maxi(_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _phase == 0 and _t >= FIRST_AT:
		var mean := 0.0
		for ms in _idle:
			mean += ms
		mean /= maxf(_idle.size(), 1.0)
		print("idle frames=%d mean_ms=%.2f max_draw_calls=%d" % [_idle.size(), mean, _draws])
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/shot_menu_1.png")
		print("saved /tmp/shot_menu_1.png")
		if _page2:
			_menu._turn_page(1)
			_idle = []
			_draws = 0
		else:
			_menu.legacy_sheet.open()
		_phase = 1
	elif _phase == 1 and _page2:
		if _t >= FIRST_AT + PAGE2_SETTLE - PAGE2_IDLE:
			_idle.append(delta * 1000.0)
			_draws = maxi(_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		if _t >= FIRST_AT + PAGE2_SETTLE:
			var mean2 := 0.0
			for ms in _idle:
				mean2 += ms
			mean2 /= maxf(_idle.size(), 1.0)
			print("page2 idle frames=%d mean_ms=%.2f max_draw_calls=%d" % [_idle.size(), mean2, _draws])
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("/tmp/shot_menu_page2.png")
			print("saved /tmp/shot_menu_page2.png")
			return true
	elif _phase == 1 and _t >= SECOND_AT:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/shot_menu_2.png")
		print("saved /tmp/shot_menu_2.png")
		return true
	return false
