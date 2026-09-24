extends SceneTree

## The first screen, after the entrance has landed, and again with either its
## second page turned (`page2` after `--`) or a tab open (`streak` or `stats`
## after `--`) instead of the legacy sheet, which left with the 3D game on
## 2026-09-24. Sudoku's task 7 (2026-09-20) needed page two's own draw-call
## reading and had no committed way to retake it; this is that way, rather
## than a throwaway probe whose number nothing in the tree can reproduce.
##
##     godot --path . --resolution 540x960 --script res://tests/_shot_menu.gd
##     godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd -- page2
##     godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd -- streak
##     godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd -- stats
##
## Saves /tmp/shot_menu_1.png and /tmp/shot_menu_2.png (or, under `page2`,
## /tmp/shot_menu_1.png and /tmp/shot_menu_page2.png), and prints the mean
## frame time and the peak draw-call count over the idle window before each
## shot, so a change to the first screen can be measured as well as looked
## at. With `streak` or `stats`, phase 0's shot also prints a `tab idle`
## line for the tab's own draw calls, sampled over the last 0.5s before
## FIRST_AT; with no arg, phase 1 just shoots Home again.

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
## A tab shot's own idle window: the last half second before SECOND_AT,
## after the tab's fade-in (ui/menu.gd's ENTER_FADE, 0.3s) has landed.
const TAB_IDLE := 0.5

var _menu: Node
var _t := 0.0
var _phase := 0
var _idle: Array[float] = []
var _draws := 0
var _page2 := false
var _tab_arg := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_page2 = args.has("page2")
	for a in ["streak", "stats"]:
		if args.has(a):
			_tab_arg = a
			break
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
		elif not _tab_arg.is_empty():
			_menu._show_tab(_tab_arg)
			_idle = []
			_draws = 0
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
	elif _phase == 1 and not _tab_arg.is_empty():
		if _t >= SECOND_AT - TAB_IDLE:
			_idle.append(delta * 1000.0)
			_draws = maxi(_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		if _t >= SECOND_AT:
			var mean3 := 0.0
			for ms in _idle:
				mean3 += ms
			mean3 /= maxf(_idle.size(), 1.0)
			print("tab idle frames=%d mean_ms=%.2f max_draw_calls=%d" % [_idle.size(), mean3, _draws])
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("/tmp/shot_menu_2.png")
			print("saved /tmp/shot_menu_2.png")
			return true
	elif _phase == 1 and _t >= SECOND_AT:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/shot_menu_2.png")
		print("saved /tmp/shot_menu_2.png")
		return true
	return false
