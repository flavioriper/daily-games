extends SceneTree

## Shots of Gumdrop through the real menu. Windowed, one at a time:
##   godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_gumdrop.gd -- <outdir> [reduce] [en|pt|es]
## Opens the Arcade tab and the game, then presses with real touches through
## the viewport: a pot, a tap on the tray, the squeeze button held, a drag
## over the tray. A careful bot then plays three moulds through the sim, in
## the fourth one cell is held under the dropper until it is far darker
## than the card and the mould served as it is, which ends the run. Each
## shot prints the frame's draw calls.
## user://arcade.cfg is put back on every way out.

const Sim = preload("res://arcade/gumdrop_sim.gd")
const Mould = preload("res://arcade/gumdrop_mould.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := ""
var _had := false
var _play := false
var _was := Vector2.ZERO
var _seen := 0
const PATH := "user://arcade.cfg"

func _initialize() -> void:
	# The first play's tutorial card would stand over the run and eat the taps.
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	_had = FileAccess.file_exists(PATH)
	if _had:
		_before = FileAccess.get_file_as_string(PATH)
	for a: String in OS.get_cmdline_user_args():
		if a == "reduce":
			load("res://core/motion.gd").reduce = true
		elif a in ["en", "pt", "es"]:
			# the language for this run only: Locale.set_current would write it
			# to this Mac's settings
			load("res://core/locale.gd")._current = a
		else:
			_out = a
	# A throwaway wallet, so a run never spends or earns this Mac's gold.
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_shot_wallet.cfg"
	DirAccess.remove_absolute(wallet_tmp)
	wallet.path = wallet_tmp
	wallet.reload()
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/gd_%s.png" % [_out, name])
	var sim = _s.sim if _s != null else null
	print("shot %s at %.1f draws=%d score=%d level=%d match=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		sim.score if sim != null else 0, sim.level if sim != null else 0, int(sim.match_all * 100.0) if sim != null else 0])

var _fill := PackedFloat32Array()
var _measured_at := -10.0
var _done_at := -10.0
var _cell_since := {}

## How strong each cell is, read back from the fluid a few times a second.
func _fills() -> PackedFloat32Array:
	if _t - _measured_at > 0.3 or _fill.size() != _s.sim.count.size():
		_measured_at = _t
		_fill = _s._fluid.measure().fill
	return _fill

## The careful hand, a frame at a time: the first cell not yet the card's
## shade, the pots its flavour is made of, the tip drawn in a small ring
## about the cell's middle as it squeezes (so the colour winds).
func _bot() -> void:
	var sim = _s.sim
	if sim == null or sim.phase > Sim.Phase.PLAY or not _play:
		return
	var fills := _fills()
	for c in sim.count.size():
		var recipe: Dictionary = Mould.recipe(int(sim.mould.want[c]), sim.mould.pots)
		var upto := 0.0
		var have: float = fills[c] if c < fills.size() else 0.0
		var key := "%d/%d" % [sim.level, c]
		for f: int in recipe:
			upto += float(recipe[f]) * 0.9
			if have < upto:
				# a cell that will not take the shade in fourteen seconds is left
				if not _cell_since.has(key):
					_cell_since[key] = _t
				if _t - float(_cell_since[key]) > 14.0:
					break
				sim.pick(sim.mould.pots.find(f))
				var ring := Vector2.from_angle(_t * 1.1) * 12.0
				var at: Vector2 = sim.centre_of(c) + ring
				if sim.reg[Sim.square(at)] != c:
					at = sim.centre_of(c)
				sim.aim(at)
				sim.squeeze(true)
				_done_at = _t
				return
	sim.squeeze(false)
	# five seconds for the colour to settle, then served
	if _t - _done_at > 5.0:
		var m: Dictionary = _s._fluid.measure()
		print("bot serves at %.1f: fill %s near %s all %.2f" % [_t, str(m.fill), str(m.near), m.all])
		sim.serve()

func _skip_gold() -> void:
	if _s == null:
		return
	var boost: Node = _s.get_node_or_null("BoostCard")
	if boost != null and not boost.is_queued_for_deletion():
		boost._on_play()
	var chance: Node = _s.get_node_or_null("SecondChance")
	if chance != null and not chance.is_queued_for_deletion():
		chance._on_no()

## A point of the field as the window has it.
func _win(p: Vector2) -> Vector2:
	return root.get_final_transform() * (_s.field.get_global_transform_with_canvas() * p)

func _touch(pressed: bool, at: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = pressed
	ev.position = _win(at)
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _restore() -> void:
	if _had:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(_before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func _process(delta: float) -> bool:
	_t += delta
	_skip_gold()
	_bot() if _s != null else null
	if _t > 240.0:
		print("gave up at step %d" % _step)
		_restore()
		return true
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_step = 1
		1:
			if _t > 1.8:
				_shot("1_tab")
				_menu._open_arcade("gumdrop")
				_s = _menu.get_node("Gumdrop")
				_step = 2
		2:
			if _t > 2.8:
				_shot("2_ready")
				# a real touch on the second pot
				_touch(true, _s._pot_at[1] + Vector2(0, -50))
				_touch(false, _s._pot_at[1] + Vector2(0, -50))
				print("touch picked the second pot: ", _s.sim.picked == 1)
				# a tap on the tray puts the tip there
				var to: Vector2 = _s.px(_s.sim.centre_of(1))
				_touch(true, to)
				_touch(false, to)
				print("tap put the tip in cell 1: ", _s.sim.reg[Sim.square(_s.sim.tip)] == 1)
				_at = _t
				_step = 3
		3:
			if _t > _at + 0.3:
				# the squeeze button held
				_touch(true, _s._squeeze_at)
				_at = _t
				_step = 4
		4:
			if _t > _at + 0.8 and _seen == 0:
				# the tip drawn across the cell as it squeezes: the colour winds
				_seen = -1
				_s.sim.aim(_s.sim.centre_of(1) + Vector2(-9.0, 4.0))
			if _t > _at + 1.3 and _seen == -1:
				_seen = -2
				_s.sim.aim(_s.sim.centre_of(1) + Vector2(6.0, -7.0))
			if _t > _at + 2.4:
				_seen = 0
				print("touch squeezes: ", _s.sim.squeezing, " phase play: ", _s.sim.phase == Sim.Phase.PLAY)
				_shot("3_squeeze")
				_touch(false, _s._squeeze_at)
				_at = _t
				_step = 9
		9:
			if _t > _at + 3.0:
				_shot("3b_settled")
				print("let go: ", not _s.sim.squeezing)
				# a finger drawn over the tray moves the tip as far
				_was = _s.sim.tip
				var from: Vector2 = _s._tray.get_center()
				_touch(true, from)
				var drag := InputEventScreenDrag.new()
				drag.index = 0
				drag.position = _win(from + Vector2(-60, 40))
				drag.relative = Vector2(-60, 40)
				Input.parse_input_event(drag)
				Input.flush_buffered_events()
				_touch(false, from + Vector2(-60, 40))
				print("drag moved the tip: ", _was, " -> ", _s.sim.tip)
				_play = true
				_step = 5
		5:
			if _s.sim.phase == Sim.Phase.SHOW and _s.sim.phase_t > 0.5 and _s.sim.level > _seen:
				_seen = _s.sim.level
				_shot("4_served_%d" % _s.sim.level)
			if _s.sim.phase == Sim.Phase.PLAY and _s.sim.level == 2 and _fills()[0] > 0.4 and _seen < 100:
				_shot("5_mid")
				_seen = 100
				_s.sim.level = 8
			if _s.sim.level == 9 and _s.sim.phase == Sim.Phase.PLAY and _fills()[1] > 0.5 and _seen < 200:
				_shot("6_late")
				_seen = 200
			if _s._end != null:
				# the bot flopped a mould: the end card as it is
				_at = _t
				_step = 8
			if _s.sim.level >= 10 and _s.sim.phase == Sim.Phase.PLAY:
				_play = false
				# one cell held under the dropper far past the card's shade
				_s.sim.pick(0)
				_s.sim.aim(_s.sim.centre_of(0))
				_touch(true, _s._squeeze_at)
				_at = _t
				_step = 6
		6:
			if _t > _at + 9.0:
				_shot("7_dark")
				_touch(false, _s._squeeze_at)
				_touch(true, _s._serve_at)
				_touch(false, _s._serve_at)
				print("touch served: ", _s.sim.phase == Sim.Phase.SETTLE)
				_at = _t
				_step = 7
		7:
			if _s.sim.phase == Sim.Phase.SHOW and _s.sim.phase_t > 0.6 and _seen < 300:
				_seen = 300
				_shot("8_flop")
			if _s._end != null:
				_at = _t
				_step = 8
		8:
			if _t > _at + 2.4:
				_shot("9_end")
				_restore()
				return true
	return false
