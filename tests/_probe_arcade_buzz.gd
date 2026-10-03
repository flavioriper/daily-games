extends SceneTree

## What the phone knocks for on an Arcade game, read like `_probe_perf.gd`'s
## `x=buzz` reads a board: a run played through the real screen by a simple
## bot, every sim event printed against the kinds that landed with it
## (`Haptics.trace`), then the end card, Play again, the boost card and the
## Second chance (docs/agents/haptics.md).
##
##     godot --headless --path . --script res://tests/_probe_arcade_buzz.gd -- firefly
##
## Games: firefly, molehill, stackwood.
##
## `rm` after the game runs it under reduce motion. SECS (the first run's
## length before its fireflies are taken away, 60) from the environment.
## Throwaway wallet; puts user://arcade.cfg and user://ads.cfg back.

const Haptics = preload("res://core/haptics.gd")
const Motion = preload("res://core/motion.gd")

## Events too many to print one by one: counted, with the knocks beside them.
const QUIET := {
	"firefly": ["shoot", "dive", "beam"],
	"molehill": ["up"],
	"stackwood": ["spawn", "move"],
}

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
var _quiet: Array = []
## The bots' own clocks and plans.
var _mh_next := 0.0
var _mh_slip := 6.0
var _sw_piece := -1
var _sw_wait := 0.0
var _sw_bad := false

func _env(name: String, fallback: int) -> int:
	return int(OS.get_environment(name)) if OS.has_environment(name) else fallback

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_game = args[0]
	_quiet = QUIET.get(_game, [])
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
		if _bot:
			match _game:
				"firefly":
					_firefly_bot()
				"molehill":
					_molehill_bot()
				"stackwood":
					_stackwood_bot()
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
		if _game == "molehill" and n == "hit":
			n = "hit %s%s" % [["mole", "gold", "pot", "bunny"][int(ev.kind)], ""]
		if _game == "molehill" and (n == "streak_lost" or n == "forgiven"):
			n = "%s (%s)" % [n, ev.why]
		if _game == "stackwood" and n == "land":
			n = "land%s%s" % [" dropped" if bool(ev.get("dropped", false)) else " by itself", " wild" if bool(ev.wild) else ""]
		if _game == "stackwood" and n == "merge":
			n = "merge x%d" % int(ev.chain)
		if not _quiet.has(n):
			names.append(n)
	heard.clear()
	var got := _new()
	if names.is_empty():
		if got != "-":
			print("  %-34s %s" % ["(%s)" % "/".join(_quiet), got])
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
	match _game:
		"molehill":
			await _molehill()
		"stackwood":
			await _stackwood()
		_:
			await _firefly()
	_finish()

## The end of a first run and what follows it: the card, Play again, a short
## second run (`play`, awaited) ended by `end_run`, the Second chance, the
## card without a best, Restart and the boost card.
func _end_card_and_cards(field: Control, at: Vector2, play: Callable, end_run: Callable) -> void:
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
	_press(field, at, true)
	_press(field, at, false)
	await play.call()
	print("  -- the run ended by the probe: the Second chance")
	end_run.call()
	await _wait(0.8)
	var chance := _s.get_node_or_null("SecondChance")
	if chance != null:
		_do("Second chance taken")
		chance.taken.emit()
		chance.queue_free()
		await _wait(0.8)
		_say()
		print("  -- ended again")
		end_run.call()
		_do("the card (no best)")
		await _wait(3.5)
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

# --- molehill ---

## Whacks what is up after a hand's reaction time, one whack at a time; now
## and then it slips: a rabbit whacked, a swing at the lawn, a mole let go.
func _molehill_bot() -> void:
	var sim: RefCounted = _s.sim
	var Sim: GDScript = _s.Sim
	if sim.phase != Sim.Phase.PLAY:
		return
	_mh_next -= root.get_process_delta_time()
	_mh_slip -= root.get_process_delta_time()
	if _mh_next > 0.0:
		return
	if _mh_slip <= 0.0:
		_mh_slip = _rng.randf_range(7.0, 12.0)
		_mh_next = 0.9  # and looks away: a mole or two gets off
		_s.tap(Vector2(4.0, 6.0))
		return
	for i in Sim.HILLS:
		var h: Dictionary = sim.hills[i]
		if h.done or h.st != Sim.St.UP or h.t < 0.2:
			continue
		if h.kind == Sim.Kind.BUNNY and _rng.randf() > 0.004:
			continue
		_s.tap(Sim.hill_pos(i) + Vector2(0, -30.0))
		_mh_next = 0.14
		return

func _molehill() -> void:
	var field: Control = _s.field
	var Sim: GDScript = _s.Sim
	var lawn := field.size * Vector2(0.02, 0.02)
	_do("the screen opened")
	await _wait(0.2)
	_say()
	_do("a tap before Go")
	_press(field, field.size * 0.5, true)
	await _wait(1.9)
	_say()
	_do("a swing at the lawn, no streak")
	_press(field, lawn, true)
	await _wait(0.3)
	_say()
	_do("paused")
	_s._pause(true)
	await _wait(0.3)
	_say()
	_do("resumed by a touch")
	_press(field, lawn, true)
	await _wait(0.2)
	_say()
	_bot = true
	while not _s.sim.is_over():
		await process_frame
	_bot = false
	print("  -- time: score %d, best streak %d, whacked %d, escaped %d, missed %d, rabbits %d" % [_s.sim.score, _s.sim.best_streak,
		_s.sim.whacked, _s.sim.escaped, _s.sim.missed, _s.sim.bunnies])
	_do("a tap after the bell")
	_press(field, field.size * 0.5, true)
	await _wait(0.3)
	_say()
	var end_run := func() -> void:
		_bot = false
		_s.sim.t = Sim.ROUND + _s.sim.bonus - 0.05
	# the second run: the best is passed mid-run (set low for the probe)
	var passed := func() -> void:
		_s._best = 15
		_bot = true
		await _wait(7.0)
	await _end_card_and_cards(field, lawn, passed, end_run)

# --- stackwood ---

## Drops each block where it merges most, else on the lowest column; told to
## play badly (`_sw_bad`), on the tallest column it does not merge on.
func _stackwood_bot() -> void:
	var sim: RefCounted = _s.sim
	var Sim: GDScript = _s.Sim
	if sim.phase != Sim.Phase.FALL or sim.piece.is_empty() or sim.piece.dropping:
		return
	if int(sim.piece.id) != _sw_piece:
		_sw_piece = int(sim.piece.id)
		_sw_wait = 0.25
	_sw_wait -= root.get_process_delta_time()
	if _sw_wait > 0.0:
		return
	var v: int = sim.piece.v
	var best := 0
	var best_score := -INF
	for c in Sim.COLS:
		var row: int = sim.height(c)
		var mates := 0
		for n: Vector2i in [Vector2i(c - 1, row), Vector2i(c + 1, row), Vector2i(c, row - 1)]:
			if n.x >= 0 and n.x < Sim.COLS and n.y >= 0 and n.y < sim.height(n.x) and int(sim.cols[n.x][n.y].v) == v:
				mates += 1
		var score := (-100.0 * mates + row) if _sw_bad else (10.0 * mates - row)
		if score > best_score:
			best_score = score
			best = c
	_s.aim(best)
	if int(sim.piece.col) == best or _sw_bad:
		_s.drop()

func _stackwood() -> void:
	var field: Control = _s.field
	var Sim: GDScript = _s.Sim
	var mid := field.size * Vector2(0.5, 0.5)
	_do("the screen opened")
	await _wait(0.2)
	_say()
	await _wait(1.8)
	_do("finger down, steered across")
	_press(field, mid, true)
	await _wait(0.1)
	_move(Vector2(field.size.x * 0.95, mid.y))
	await _wait(0.1)
	_move(Vector2(field.size.x * 0.05, mid.y))
	await _wait(0.1)
	_say()
	_do("let go: the block drops")
	_press(field, Vector2(field.size.x * 0.05, mid.y), false)
	await _wait(0.6)
	_say()
	_do("a block left to fall by itself")
	while _s.sim.drops < 2:
		await process_frame
	await _wait(0.4)
	_say()
	_do("a tool without the acorns")
	_s._tool_buttons[Sim.Tool.BOMB].pressed.emit()
	await _wait(0.3)
	_say()
	_do("paused")
	_s._pause(true)
	await _wait(0.3)
	_say()
	_do("resumed by a touch")
	_press(field, mid, true)
	_press(field, mid, false)
	await _wait(0.6)
	_say()
	_bot = true
	var secs := float(_env("SECS", 45))
	var t := 0.0
	while not _s.sim.is_over() and t < secs:
		await process_frame
		t += root.get_process_delta_time()
	_bot = false
	print("  -- %d s in: score %d, drops %d, merges %d, best chain %d, biggest %d" % [int(t), _s.sim.score, _s.sim.drops,
		_s.sim.merges, _s.sim.best_chain, _s.sim.max_v])
	# the tools, with acorns handed over
	_s.sim.acorns = 2000
	for tool: int in [Sim.Tool.WILD, Sim.Tool.BOMB, Sim.Tool.ZAP]:
		while not _s.sim.can_use(tool) and not _s.sim.is_over():
			await process_frame
		_do("bought: %s" % Sim.TOOL_KEYS[tool])
		_s._tool_buttons[tool].pressed.emit()
		await _wait(0.15)
		_say()
		if tool != Sim.Tool.ZAP:
			_do("  and dropped")
			_s.drop()
			await _wait(0.9)
			_say()
		else:
			await _wait(0.9)
	print("  -- now it plays badly, to the line and over")
	_sw_bad = true
	_bot = true
	t = 0.0
	while not _s.sim.is_over() and t < 120.0:
		await process_frame
		t += root.get_process_delta_time()
	_bot = false
	_sw_bad = false
	await _wait(0.3)
	var end_run := func() -> void:
		_bot = false
		if not _s.sim.is_over():
			_s.sim.phase = Sim.Phase.OVER
			_s.sim.piece = {}
			_s.sim.events.append({"type": "over", "col": 0})
	var short := func() -> void:
		_bot = true
		await _wait(5.0)
	await _end_card_and_cards(field, mid, short, end_run)

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
