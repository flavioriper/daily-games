extends SceneTree

## Shots of Gumdrop, the daily board, through the real menu and the flat
## host. Windowed, one at a time:
##   godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_gumdrop.gd -- <outdir> [0|1|2|3] [reduce] [en|pt|es] [tutor] [pour]
## Opens the card at the band (Easy when none is named), then presses with
## real touches through the viewport: a pot, a tap on the tray, the squeeze
## button held, a drag over the tray, and that first mould served nearly
## clear (a flop: it is emptied and poured again). A careful bot then
## plays the day's moulds through the sim, reading the fluid back, and
## serves each with a real touch; the win is shot, the board left and
## opened again as a finished day.
## With `tutor` the ? card's pages are shot instead; with `pour` the
## squeeze button is held four seconds and let go, then the grey drain
## button held three, the tip's chunk read off the dye and the meter at
## each still, and the run ends there.
## Each shot prints the frame's draw calls. The save is a harness file and
## the wallet a throwaway, so nothing of this Mac's is touched.

const Sim = preload("res://puzzles/gumdrop_sim.gd")
const Mould = preload("res://puzzles/gumdrop_mould.gd")
const Registry = preload("res://ui/registry.gd")

var _menu: Node
var _host: Node
var _b: Node
var _t_: Node
var _t := 0.0
var _out := "/tmp"
var _band := 0
var _tutor := false
var _pour := false
var _page := 0
var _turns := 0
var _gold := 0
var _mixed := false
var _step := 0
var _at := 0.0
var _play := false
var _was := Vector2.ZERO
var _seen := -1
var _flops := 0

func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a == "reduce":
			load("res://core/motion.gd").reduce = true
		elif a == "tutor":
			_tutor = true
		elif a == "pour":
			_pour = true
		elif a in ["0", "1", "2", "3"]:
			_band = int(a)
		elif a in ["en", "pt", "es"]:
			# the language for this run only: Locale.set_current would write it
			# to this Mac's settings
			load("res://core/locale.gd")._current = a
		else:
			_out = a
	# A harness save, cleared every run, with the first play's tutorial seen.
	var progress_path := "user://progress_harness.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress_path))
	var progress = load("res://core/progress.gd")
	progress.path = progress_path
	progress.mark_tutorial_seen("gumdrop")
	# A throwaway wallet, so a run never spends or earns this Mac's gold.
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_shot_wallet.cfg"
	DirAccess.remove_absolute(wallet_tmp)
	wallet.path = wallet_tmp
	wallet.reload()
	# today's gift taken, so the gifts sheet does not open over the board
	wallet.claim_calendar()
	# two boosters of its Arcade days held: they come back as gold at the open
	wallet.give("gd_soft", 2)
	_gold = wallet.gold()
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/gd_%s.png" % [_out, name])
	var sim = _t_.sim if _t_ != null and is_instance_valid(_t_) else null
	print("shot %s at %.1f draws=%d mould=%d serves=%d match=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		sim.index if sim != null else -1, sim.serves if sim != null else 0, int(sim.match_all * 100.0) if sim != null else 0])

func _open() -> void:
	_menu._open_at(Registry.find("gumdrop"), _band)
	_host = root.get_tree().get_first_node_in_group("puzzle_host")
	_b = _host._puzzle
	_t_ = _b.table

var _fill := PackedFloat32Array()
var _measured_at := -10.0
var _done_at := -10.0
var _cell_since := {}

## How strong each cell is, read back from the fluid a few times a second.
func _fills() -> PackedFloat32Array:
	if _t - _measured_at > 0.3 or _fill.size() != _t_.sim.count.size():
		_measured_at = _t
		_fill = _t_._fluid.measure().fill
	return _fill

## The careful hand, a frame at a time: the first part not yet the card's
## shade, the pots its flavour is made of, the tip drawn about the part
## as it squeezes.
func _bot() -> void:
	var sim = _t_.sim
	if sim == null or sim.phase > Sim.Phase.PLAY or not _play:
		return
	var fills := _fills()
	for c in sim.count.size():
		var recipe: Dictionary = Mould.recipe(int(sim.mould.want[c]), sim.mould.pots)
		var upto := 0.0
		var have: float = fills[c] if c < fills.size() else 0.0
		var key := "%d/%d/%d" % [sim.index, sim.serves, c]
		for f: int in recipe:
			upto += float(recipe[f]) * 0.9
			if have < upto:
				# a cell that will not take the shade in fourteen seconds is left
				if not _cell_since.has(key):
					_cell_since[key] = _t
				if _t - float(_cell_since[key]) > 14.0:
					break
				sim.pick(sim.mould.pots.find(f))
				# the tint stays where it is put: the needle goes from square
				# to square of the part, three a second
				var own: Array = []
				for i in sim.reg.size():
					if sim.reg[i] == c:
						own.append(i)
				var at: Vector2 = Sim.at(own[int(_t * 3.0) * 7919 % own.size()])
				sim.aim(sim.tip.move_toward(at, 1.6))
				# on its way there it may cross another chunk: nothing goes in
				sim.squeeze(sim.tip_cell() == c)
				_done_at = _t
				return
	sim.squeeze(false)
	# five seconds for the colour to settle, then served
	if _t - _done_at > 5.0:
		var m: Dictionary = _t_._fluid.measure()
		print("bot serves at %.1f: fill %s near %s all %.2f" % [_t, str(m.fill), str(m.near), m.all])
		sim.serve()

const POUR_HELD := [0.5, 1.5, 2.5, 4.0]
const POUR_FREE := [0.1, 0.5, 2.0]
const DRAIN_HELD := [0.5, 1.5, 3.0]
var _marks := 0

## The chunk under the tip, read off the dye: what share of it holds any
## tint, and its mean and deepest amount (over the texture's top).
func _spread(name: String) -> void:
	_shot("pour_" + name)
	var fluid: Node = _t_._fluid
	var ids: PackedByteArray = fluid._mask_bytes()
	var dye: PackedByteArray = fluid.texture().get_image().get_data()
	var side: int = fluid.DYE
	var step: int = dye.size() / (side * side)
	var cell: int = _t_.sim.tip_cell()
	var all := 0
	var wet := 0
	var sum := 0.0
	var top := 0.0
	for i in side * side:
		if ids[i * 4] - 1 != cell:
			continue
		var c: float = (dye[i * step] + dye[i * step + 1] + dye[i * step + 2]) / 255.0
		all += 1
		sum += c
		top = maxf(top, c)
		if c > 0.03:
			wet += 1
	var level: Vector3 = fluid.level(cell)
	print("pour %s: cell %d of %d texels, tinted %.2f, mean %.3f, top %.3f; meter %.2f (%.2f %.2f %.2f) shown %d%% tank %.1f wet %s" % [name, cell, all, wet / maxf(1.0, all), sum / maxf(1.0, all), top,
		(level.x + level.y + level.z) / Sim.C_FULL, level.x, level.y, level.z, int(round((_t_._level.x + _t_._level.y + _t_._level.z) / Sim.C_FULL * 100.0)), _t_.sim.tank[cell], str(_t_.sim.wet())])

## A point of the field as the window has it.
func _win(p: Vector2) -> Vector2:
	return root.get_final_transform() * (_t_.field.get_global_transform_with_canvas() * p)

func _touch(pressed: bool, at: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = pressed
	ev.position = _win(at)
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _tap(at: Vector2) -> void:
	_touch(true, at)
	_touch(false, at)

func _process(delta: float) -> bool:
	_t += delta
	if _t_ != null and is_instance_valid(_t_):
		_bot()
	if _t > 400.0:
		print("gave up at step %d" % _step)
		return true
	match _step:
		0:
			# the grid turned to its last page, where the card is
			if _tutor and _t > 1.0 + 0.7 * _turns and _turns < _menu._pages() - 1:
				_turns += 1
				_menu._turn_page(1)
			if _t > (1.6 + 0.7 * _menu._pages() if _tutor else 1.6):
				_shot("0_menu")
				_open()
				_at = _t
				_step = 30 if _tutor else 1
		1:
			if _t > _at + 1.2:
				_shot("1_ready")
				print("refund: gold %d -> %d, gd_soft held %d" % [_gold, root.get_node("Wallet").gold(), root.get_node("Wallet").count("gd_soft")])
				print("bands: clear %s tray %s field %s" % [str(_t_.clear), str(_t_._tray), str(_t_.field.size)])
				# a real touch on the second pot
				_tap(_t_._pot_at[1] + Vector2(0, -50))
				print("touch picked the second pot: ", _t_.sim.picked == 1)
				# a tap on the tray puts the tip there
				_tap(_t_.px(_t_.sim.centre_of(1)))
				print("tap put the tip in cell 1: ", _t_.sim.reg[Sim.square(_t_.sim.tip)] == 1)
				_at = _t
				_step = 2
		2:
			if _t > _at + 0.3:
				# the squeeze button held
				_touch(true, _t_._squeeze_at)
				_at = _t
				_step = 40 if _pour else 3
		3:
			if _t > _at + 1.6:
				print("touch squeezes: ", _t_.sim.squeezing, " phase play: ", _t_.sim.phase == Sim.Phase.PLAY)
				print("pour: loop playing %s at %.1f dB, last cue %s" % [str(_t_._pour_snd.playing), _t_._pour_snd.volume_db, _t_._fx.last_cue])
				_shot("2_squeeze")
				_touch(false, _t_._squeeze_at)
				_at = _t
				_step = 4
		4:
			if _t > _at + 2.0:
				print("let go: ", not _t_.sim.squeezing)
				print("pour: loop stopped %s" % str(not _t_._pour_snd.playing))
				# a finger drawn over the tray moves the tip as far
				_was = _t_.sim.tip
				var from: Vector2 = _t_._tray.get_center()
				_touch(true, from)
				var drag := InputEventScreenDrag.new()
				drag.index = 0
				drag.position = _win(from + Vector2(-60, 40))
				drag.relative = Vector2(-60, 40)
				Input.parse_input_event(drag)
				Input.flush_buffered_events()
				_touch(false, from + Vector2(-60, 40))
				print("drag moved the tip: ", _was, " -> ", _t_.sim.tip)
				# served as it is, nearly clear: a flop
				_tap(_t_._serve_at)
				print("touch served: ", _t_.sim.phase == Sim.Phase.SETTLE, " moves ", _b.moves)
				_step = 5
		5:
			if _t_.sim.phase == Sim.Phase.SHOW and _t_.sim.phase_t > 0.6 and _seen < 0:
				_seen = 0
				_shot("3_flop")
			if _t_.sim.phase == Sim.Phase.PLAY and _seen == 0:
				_flops += 1
				print("under the mark: emptied, wet %s, index %d" % [str(_t_.sim.wet()), _t_.sim.index])
				_at = _t
				_shot("4_again")
				_play = true
				_step = 6
		6:
			# the bot plays: a shot of each mould served, and one mid-pour
			if _t_.sim.phase == Sim.Phase.SHOW and _t_.sim.phase_t > 0.5 and _t_.sim.serves > _seen:
				_seen = _t_.sim.serves
				_shot("5_served_%d" % _t_.sim.index)
			if _t_.sim.index == 1 and _t_.sim.phase == Sim.Phase.PLAY and _t_.sim.wet() and _fills()[0] > 0.5 and _seen < 100:
				_seen = 100
				_shot("5_mid")
			if _t_._fx.last_cue == "mix" and not _mixed:
				_mixed = true
				print("mix: bubbles as pot %d goes into cell %d, which held %s; loop %s" % [_t_.sim.picked, _t_.sim.tip_cell(), str(_t_._cell_pots.get(_t_.sim.tip_cell(), {}).keys()), str(_t_._pour_snd.playing)])
			if _b.is_done():
				print("solved: moves %d marks %s won %s" % [_b.moves, str(_t_.sim.marks), str(_host._won)])
				_at = _t
				_step = 7
		7:
			if _t > _at + 0.25 and _seen < 200:
				_seen = 200
				_shot("6_win_sliding")
			if _t > _at + 2.6:
				_shot("7_win")
				print("win: clear %s win tray %s fluid runs %s" % [str(_t_.clear), str(_t_._win_tray), str(_t_._fluid_runs())])
				_host._on_back()
				_at = _t
				_step = 8
		8:
			if _t > _at + 1.0:
				_t_ = null
				_open()
				_at = _t
				_step = 9
		9:
			if _t > _at + 2.0:
				_shot("8_done_day")
				print("reopened: done %s marks %s" % [str(_b.is_done()), str(_t_.sim.marks)])
				# Redo from the finished day: a fresh board, playing
				_host._on_redo()
				_b = _host._puzzle
				_t_ = _b.table
				_at = _t
				_step = 10
		10:
			if _t > _at + 1.2:
				_shot("9_redo")
				print("redo: done %s won %s clear %s" % [str(_b.is_done()), str(_t_.won), str(_t_.clear)])
				# Reset on a wet mould empties it
				_t_.sim.squeeze(true)
				_at = _t
				_step = 11
		11:
			if _t > _at + 0.8:
				_t_.sim.squeeze(false)
				var wet: bool = _t_.sim.wet()
				_host._on_reset()
				print("reset: was wet %s, now wet %s" % [str(wet), str(_t_.sim.wet())])
				return true
		40:
			# `pour`: the button held four seconds and let go, the tip's chunk
			# read at each still, so a pour that only spreads at the release
			# shows as a jump between `held_4.0` and `free_0.5`
			if _marks < POUR_HELD.size() and _t > _at + POUR_HELD[_marks]:
				_spread("held_%.1f" % POUR_HELD[_marks])
				_marks += 1
			elif _marks == POUR_HELD.size():
				_touch(false, _t_._squeeze_at)
				_at = _t
				_marks = 0
				_step = 41
		41:
			if _marks < POUR_FREE.size() and _t > _at + POUR_FREE[_marks]:
				_spread("free_%.1f" % POUR_FREE[_marks])
				_marks += 1
			elif _marks == POUR_FREE.size():
				# the grey button held: the chunk drawn back out
				_touch(true, _t_._drain_at)
				print("touch drains: ", _t_.sim.draining)
				_at = _t
				_marks = 0
				_step = 42
		42:
			if _marks < DRAIN_HELD.size() and _t > _at + DRAIN_HELD[_marks]:
				_spread("drain_%.1f" % DRAIN_HELD[_marks])
				_marks += 1
			elif _marks == DRAIN_HELD.size():
				_touch(false, _t_._drain_at)
				print("let go of the drain: ", not _t_.sim.draining)
				return true
		30:
			# the ? card, a shot of every page a while into its lesson
			if _t > _at + 1.0:
				_host._show_tutorial()
				_at = _t
				_step = 31
		31:
			if _t > _at + 6.5:
				var card: Node = _host._tutorial
				_shot("t_page_%d" % _page)
				_page += 1
				if _page >= card._pages.size():
					return true
				card._turn(1)
				_at = _t
	return false
