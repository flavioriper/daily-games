extends SceneTree

## What the phone knocks for on an Arcade game, read like `_probe_perf.gd`'s
## `x=buzz` reads a board: a run played through the real screen by a simple
## bot, every sim event printed against the kinds that landed with it
## (`Haptics.trace`), then the end card, Play again, the boost card and the
## Second chance (docs/agents/haptics.md).
##
##     godot --headless --path . --script res://tests/_probe_arcade_buzz.gd -- firefly
##
## `rm` after the game runs it under reduce motion. SECS (the first run's
## length before its fireflies are taken away, 60) from the environment.
## Throwaway wallet; puts user://arcade.cfg and user://ads.cfg back.

const Haptics = preload("res://core/haptics.gd")
const Motion = preload("res://core/motion.gd")

## Events too many to print one by one: counted, with the knocks beside them.
const QUIET := ["shoot", "dive", "beam"]

var _game := "firefly"
var _s: Node
var _seen := 0
var _begun := false
var _saved := {}
var _tmp := ""
var _bot := false
var _rng := RandomNumberGenerator.new()
var _tally := {}
var _label := ""
var _answered := false

func _env(name: String, fallback: int) -> int:
	return int(OS.get_environment(name)) if OS.has_environment(name) else fallback

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_game = args[0]
	for f: String in ["user://arcade.cfg", "user://ads.cfg"]:
		if FileAccess.file_exists(f):
			_saved[f] = FileAccess.get_file_as_bytes(f)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var wallet: Node = root.get_node("Wallet")
	_tmp = OS.get_user_data_dir() + "/_probe_arcade_buzz_wallet.cfg"
	DirAccess.remove_absolute(_tmp)
	wallet.path = _tmp
	wallet.reload()
	# the welcome gift is gold and a chance of each: spend it all, so the
	# first run opens with no card
	wallet.spend(wallet.gold(), "probe")
	for id: String in wallet.Boosters.ITEMS:
		while wallet.count(id) > 0:
			wallet.use(id, "probe")
	Motion.settings_path = "user://_probe_arcade_buzz.cfg"
	Motion.reduce = args.has("rm")
	Haptics.on = true
	Haptics.trace = []
	_rng.seed = 7
	# The screen with its events overheard: a subclass made here, loaded at
	# run time (a preload compiles before the Ads autoload exists).
	var gd := GDScript.new()
	gd.source_code = "extends \"res://arcade/%s_screen.gd\"\nvar heard: Array = []\nfunc _play_events() -> void:\n\tfor ev: Dictionary in sim.events:\n\t\theard.append(ev.duplicate())\n\tsuper()\n" % _game
	gd.reload()
	_s = gd.new()
	root.add_child(_s)

func _finish() -> void:
	print("haptics: ", " ".join(Haptics.trace))
	print("counted: ", _tally)
	for f: String in ["user://arcade.cfg", "user://ads.cfg"]:
		if _saved.has(f):
			var out := FileAccess.open(f, FileAccess.WRITE)
			out.store_buffer(_saved[f])
			out.close()
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	DirAccess.remove_absolute(_tmp)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_probe_arcade_buzz.cfg"))
	quit()

func _process(_delta: float) -> bool:
	if not _begun:
		_begun = true
		_run()
	# Runs before the screen's own frame: what it heard and knocked last
	# frame is read here, and the bot's hand set for this one.
	if _s != null and _s.sim != null:
		_report()
		if _bot and _game == "firefly":
			_firefly_bot()
	return false

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _new() -> String:
	var all: Array = Haptics.trace
	var out := " ".join(all.slice(_seen)) if all.size() > _seen else "-"
	_seen = all.size()
	return out

## Names what the hand is about to do: knocks that land with no event are
## printed against it, and `_say` closes it ("-" if nothing landed).
func _do(what: String) -> void:
	_label = what
	_answered = false

func _say() -> void:
	if not _answered:
		print("  %-34s %s" % [_label, _new()])
	_label = ""

## Last frame's events against last frame's knocks.
func _report() -> void:
	var heard: Array = _s.heard
	if heard.is_empty():
		if Haptics.trace.size() > _seen:
			print("  %-34s %s" % [_label if _label != "" else "(no event)", _new()])
			_answered = true
		return
	var names: Array = []
	for ev: Dictionary in heard:
		var n := String(ev.type)
		if n == "pop":
			n = "pop %s%s" % [["gnat", "beetle", "moth", "rogue"][int(ev.kind)] if _game == "firefly" else "", " rammed" if bool(ev.get("rammed", false)) else ""]
		if not QUIET.has(n):
			names.append(n)
	heard.clear()
	var got := _new()
	if names.is_empty():
		if got != "-":
			print("  %-34s %s" % ["(shoot/dive/beam)", got])
		return
	var key := ", ".join(names)
	var line := "%s -> %s" % [key, got]
	_tally[line] = int(_tally.get(line, 0)) + 1
	# each kind of line once, then counted
	if int(_tally[line]) <= 2:
		print("  %-34s %s" % [key, got])

func _press(c: Control, at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	if pressed:
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
	_s._on_field_input(e)

func _move(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	_s._on_field_input(e)

func _button(under: Node, name: String) -> BaseButton:
	var b := under.find_child(name, true, false)
	return b as BaseButton

func _run() -> void:
	await _wait(0.5)
	print(_game, ", reduce ", Motion.reduce)
	await _firefly()
	_finish()

# --- firefly ---

## Sits under the lowest bug, sidesteps bullets coming down on it; the
## finger is already down, so it fires.
func _firefly_bot() -> void:
	var sim: RefCounted = _s.sim
	var aim: float = sim.px
	var best := -1.0
	for e: Dictionary in sim.enemies:
		if e.st == _s.Sim.St.WAIT:
			continue
		if e.pos.y > best and e.pos.y < _s.Sim.PLAYER_Y - 30.0:
			best = e.pos.y
			aim = e.pos.x
	for b: Dictionary in sim.bullets:
		if b.pos.y > _s.Sim.PLAYER_Y - 90.0 and absf(b.pos.x - sim.px) < 14.0 and _rng.randf() < 0.8:
			aim = sim.px + (30.0 if b.pos.x < sim.px else -30.0)
	sim.target_x = aim

func _firefly() -> void:
	var field: Control = _s.field
	_do("the screen opened")
	await _wait(0.2)
	_say()
	var mid := field.size * Vector2(0.5, 0.8)
	_do("finger down, firing")
	_press(field, mid, true)
	await _wait(0.3)
	_say()
	_do("slid across and back")
	_move(mid + Vector2(120.0, 0.0))
	await _wait(0.3)
	_move(mid - Vector2(160.0, 0.0))
	await _wait(0.3)
	_say()
	_do("paused")
	_s._pause(true)
	await _wait(0.3)
	_say()
	_do("resumed by a touch")
	_press(field, mid, true)
	await _wait(0.2)
	_say()
	_press(field, mid, true)
	_bot = true
	var secs := float(_env("SECS", 60))
	var t := 0.0
	while not _s.sim.is_over() and t < secs:
		await process_frame
		t += root.get_process_delta_time()
	print("  -- %d s in: stage %d, score %d, ships %d; the rest are taken away" % [int(t), _s.sim.stage, _s.sim.score, _s.sim.ships])
	_bot = false
	_s.sim.target_x = NAN
	_s.sim.ships = mini(_s.sim.ships, 1)
	t = 0.0
	while not _s.sim.is_over() and t < 90.0:
		await process_frame
		t += root.get_process_delta_time()
	_do("the card (a first best)")
	await _wait(3.0)
	_say()
	_do("Play again")
	_button(_s._end, "Again").pressed.emit()
	await _wait(0.3)
	_say()
	# a short run that beats nothing, with gold in the wallet: the Second
	# chance, the boost card
	root.get_node("Wallet").add_gold(5000, "probe")
	_press(field, mid, true)
	await _wait(1.0)
	print("  -- the run ended by the probe (no pop): the Second chance")
	_s.sim.ships = 1
	_s.sim._lose_ship()
	await _wait(0.5)
	var chance := _s.get_node_or_null("SecondChance")
	if chance != null:
		_do("Second chance taken")
		chance.taken.emit()
		chance.queue_free()
		await _wait(0.5)
		_say()
		print("  -- ended again")
		_s.sim.ships = 1
		_s.sim._lose_ship()
		_do("the card (no best)")
		await _wait(3.0)
		_say()
	_do("Restart: the boost card")
	_s._on_reset()
	await _wait(0.3)
	_say()
	var card := _s.get_node_or_null("BoostCard")
	if card != null:
		_do("Play on the card")
		card.play.emit([])
		card.queue_free()
		await _wait(0.3)
		_say()
	await _wait(0.2)
