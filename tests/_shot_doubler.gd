extends SceneTree

## Task 9's look: a Firefly end card with the gold doubler, before and after
## the press, and again on a day whose Arcade cap the run itself uses up.
##
##     ADS_FAKE_FULL=1 godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_doubler.gd -- <outdir>
##
## A throwaway wallet; user://arcade.cfg is put back on every exit path.

const PATH := "user://arcade.cfg"
var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := ""
var _had := false
var _wallet: Node

func _initialize() -> void:
	_had = FileAccess.file_exists(PATH)
	if _had:
		_before = FileAccess.get_file_as_string(PATH)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_wallet = root.get_node("Wallet")
	var tmp := OS.get_user_data_dir() + "/_shot_doubler_wallet.cfg"
	DirAccess.remove_absolute(tmp)
	_wallet.path = tmp
	_wallet.reload()
	# and a throwaway ads state, so this Mac's pacing is neither read nor spent
	var ads: Node = root.get_node("Ads")
	ads.state_path = OS.get_user_data_dir() + "/_shot_doubler_ads.cfg"
	DirAccess.remove_absolute(ads.state_path)
	ads.reload_state()
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _restore() -> void:
	if _had:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(_before)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DirAccess.remove_absolute(_wallet.path)
	DirAccess.remove_absolute(root.get_node("Ads").state_path)

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/dbl_%s.png" % [_out, name])

func _skip_gold() -> void:
	if _s == null or not is_instance_valid(_s):
		return
	var boost: Node = _s.get_node_or_null("BoostCard")
	if boost != null and not boost.is_queued_for_deletion():
		boost._on_play()
	var chance: Node = _s.get_node_or_null("SecondChance")
	if chance != null and not chance.is_queued_for_deletion():
		chance._on_no()

func _find(n: Node, tail: String = "gold_doubler.gd") -> Node:
	if n.is_queued_for_deletion():
		return null
	if n.get_script() != null and str(n.get_script().resource_path).ends_with(tail):
		return n
	for c in n.get_children():
		var r := _find(c, tail)
		if r != null:
			return r
	return null

func _button(d: Node) -> Button:
	for c in d.get_children():
		if c is Button and not c.is_queued_for_deletion():
			return c
	return null

func _process(delta: float) -> bool:
	_t += delta
	_skip_gold()
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_menu._open_arcade("firefly")
				_s = _find(root, "firefly_screen.gd")
				_step = 1
				_at = _t
		1:
			if _t > _at + 2.5:
				_s.sim.score = 1234
				_s.sim.ships = 1
				_s.sim.ship = load("res://arcade/firefly_sim.gd").Ship.ALIVE
				_s.sim._ship_hit(0)
				_step = 2
				_at = _t
		2:
			if _t > _at + 4.5:
				var d := _find(root)
				var b := _button(d) if d != null else null
				print("doubler ", d, " can_reward ", root.get_node("Ads").can_reward("double"), " fake ", root.get_node("Ads")._fake_full)
				print("run gold ", _s._run_gold, " wallet ", _wallet.gold(), " room ", _wallet.arcade_room(), " button ", b.text if b != null else "none")
				_shot("1_before")
				# a skipped video first: the button must come back, gold unchanged
				root.get_node("Ads")._fake_full = "skip"
				if b != null:
					b.pressed.emit()
				_step = 25
				_at = _t
		25:
			if _t > _at + 2.5:
				var d := _find(root)
				var b := _button(d) if d != null else null
				print("skipped: wallet ", _wallet.gold(), " button ", ("present, disabled=%s" % b.disabled) if b != null else "GONE")
				_shot("1b_skipped")
				root.get_node("Ads")._fake_full = "1"
				if b != null:
					b.pressed.emit()
				_step = 3
				_at = _t
		3:
			if _t > _at + 2.5:
				var d := _find(root)
				print("after: wallet ", _wallet.gold(), " room ", _wallet.arcade_room(), " button ", "present" if d != null and _button(d) != null else "gone")
				_shot("2_after")
				# a capped day: the run itself uses up the cap
				_s.queue_free()
				_wallet.reload()
				_wallet.path = OS.get_user_data_dir() + "/_shot_doubler_wallet2.cfg"
				DirAccess.remove_absolute(_wallet.path)
				_wallet.reload()
				_wallet.pay_bonus(_wallet.arcade_room() - 5)  # leaves 5: the run's own 5 uses it up
				_menu._show_tab("arcade")
				_menu._open_arcade("firefly")
				_step = 4
				_at = _t
		4:
			if _t > _at + 1.0:
				_s = _find(root, "firefly_screen.gd")
				_step = 5
				_at = _t
		5:
			if _t > _at + 2.5:
				_s.sim.score = 5
				_s.sim.ships = 1
				_s.sim.ship = load("res://arcade/firefly_sim.gd").Ship.ALIVE
				_s.sim._ship_hit(0)
				_step = 6
				_at = _t
		6:
			if _t > _at + 4.5:
				var d := _find(root)
				print("capped: run gold ", _s._run_gold, " room ", _wallet.arcade_room(), " doubler ", "present" if d != null else "none", " button ", "present" if d != null and _button(d) != null else "none")
				_shot("3_capped")
				DirAccess.remove_absolute(_wallet.path)
				_restore()
				quit()
	if _t > 60.0:
		_restore()
		quit(1)
	return false
