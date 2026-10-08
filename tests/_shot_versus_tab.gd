extends SceneTree

## The Versus tab alone, offline (tests/_offline_main.gd), to see how its
## cards fit the room:
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_versus_tab.gd -- <outdir> [lang=pt|es] [banner]
##
## `banner` takes an ad banner's share off the bottom first. Prints the draw
## calls, the tab's height and where the bar is. user://versus.cfg is put back.

var _menu: Node
var _t := 0.0
var _out := "/tmp"
var _banner := false
var _step := 0
var _had := false
var _saved := ""

func _initialize() -> void:
	_had = FileAccess.file_exists("user://versus.cfg")
	if _had:
		_saved = FileAccess.get_file_as_string("user://versus.cfg")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("lang="):
			load("res://core/locale.gd")._current = a.substr(5)
		elif a == "banner":
			_banner = true
		else:
			_out = a
	var main: Node = load("res://world/main.tscn").instantiate()
	main.set_script(load("res://tests/_offline_main.gd"))
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if _step == 0 and _t > 0.8:
		_menu._show_tab("versus")
		if _banner:
			root.get_node("Ads").banner_changed.emit(true, 150.0)
		_step = 1
	elif _step == 1 and _t > 1.8:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("%s/versus_tab%s.png" % [_out, "_banner" if _banner else ""])
		var tab: Control = _menu.versus_tab
		print("draws=%d tab %s min %s" % [int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			str(tab.get_global_rect()), str(tab.get_combined_minimum_size())])
		if _had:
			var f := FileAccess.open("user://versus.cfg", FileAccess.WRITE)
			f.store_string(_saved)
		quit()
	return false
