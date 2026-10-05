extends SceneTree

## What the phone knocks for on an Arcade game, read like `_probe_perf.gd`'s
## `x=buzz` reads a board: a run played through the real screen by a simple
## bot, every sim event printed against the kinds that landed with it
## (`Haptics.trace`), then the end card, Play again, the boost card and the
## Second chance (docs/agents/haptics.md).
##
##     godot --headless --path . --script res://tests/_probe_arcade_buzz.gd -- firefly
##
## Games: firefly, molehill, stackwood, thirteen, posy, peapod.
##
## `rm` after the game runs it under reduce motion. SECS (the first run's
## length before its fireflies are taken away, 60) and MOVES (thirteen's and
## posy's bot, 40 and 60) from the environment.
## Throwaway wallet; puts user://arcade.cfg and user://ads.cfg back.

const Haptics = preload("res://core/haptics.gd")
const Motion = preload("res://core/motion.gd")

## Events too many to print one by one: counted, with the knocks beside them.
const QUIET := {
	"firefly": ["shoot", "dive", "beam"],
	"molehill": ["up"],
	"stackwood": ["spawn", "move"],
	"thirteen": ["select", "unselect", "settle", "merge"],
	"posy": ["fall", "unswap", "goal_done", "convert", "offer", "over"],
	"peapod": ["shot", "hit", "zap", "knock"],
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
var _pp_hand := 150.0

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
	if _game == "posy":
		# Posy plays its events off a queue, one at a time: heard as played
		gd.source_code = "extends \"res://arcade/posy_screen.gd\"\nvar heard: Array = []\nfunc _apply(ev: Dictionary) -> void:\n\theard.append(ev.duplicate())\n\tsuper(ev)\n"
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
				"peapod":
					_peapod_bot()
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
		if _game == "peapod" and n == "kill":
			n = "kill %s%s" % [["crate", "gold", "firecracker", "head", "gift", "gift", "gift", "gift", "gift", "gift", "gift", "iron"][int(ev.kind)], " (tail)" if bool(ev.popped) else ""]
		if _game == "peapod" and (n == "gift" or n == "use" or n == "pod_off"):
			n = "%s %s" % [n, ["", "", "", "", "fan", "pierce", "burst", "zap", "flame", "frost", "shove"][int(ev.kind)]]
		if _game == "molehill" and n == "hit":
			n = "hit %s%s" % [["mole", "gold", "pot", "bunny"][int(ev.kind)], ""]
		if _game == "molehill" and (n == "streak_lost" or n == "forgiven"):
			n = "%s (%s)" % [n, ev.why]
		if _game == "stackwood" and n == "land":
			n = "land%s%s" % [" dropped" if bool(ev.get("dropped", false)) else " by itself", " wild" if bool(ev.wild) else ""]
		if _game == "stackwood" and n == "merge":
			n = "merge x%d" % int(ev.chain)
		if (_game == "thirteen" or _game == "posy") and (n == "tool" or n == "refused"):
			n = "%s %s" % [n, ev.tool]
		if _game == "posy" and n == "swap":
			n = "swap%s" % (" (a tool's)" if bool(ev.get("free", false)) else ("" if bool(ev.ok) else " refused"))
		if _game == "posy" and n == "clear":
			var met := true
			for g: Dictionary in ev.goals:
				met = met and int(g.got) >= int(g.need)
			var kinds := {}
			for b: Dictionary in ev.blasts:
				kinds[String(b.kind)] = true
			n = "clear %d%s%s%s" % [int(ev.step), " made" if not (ev.made as Array).is_empty() else "",
				" blast:" + "+".join(kinds.keys()) if not kinds.is_empty() else "", " (day met)" if met else ""]
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
		"thirteen":
			await _thirteen()
		"posy":
			await _posy()
		"peapod":
			await _peapod()
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

# --- peapod ---

## Rolls under the lowest crate or the plate furthest along, at a hand's
## pace, and in the shop buys what it can, the heavier pea first, and goes on.
func _peapod_bot() -> void:
	var sim: RefCounted = _s.sim
	var Sim: GDScript = _s.Sim
	if sim.phase == Sim.Phase.SHOP and _s._shop != null:
		for card in Sim.Card.size():
			if sim.can_buy(card):
				_do("the shop: card %d bought" % card)
				_s._buy(card)
				_say()
		_do("the shop: Go")
		_s._close_shop()
		_say()
		return
	if sim.phase != Sim.Phase.PLAY:
		return
	var want: float = sim.x
	if sim.wave_kind == Sim.Wave.WALL:
		for r in sim.rows.size():
			var found := false
			for c in Sim.COLS:
				if sim.rows[r][c] != null:
					want = (c + 0.5) * Sim.CELL_W
					found = true
					break
			if found:
				break
	elif not sim.segs.is_empty():
		want = Sim.path_at(float(sim.segs[0].s) + 8.0).x
	_pp_hand = move_toward(_pp_hand, want, 300.0 * root.get_process_delta_time())
	sim.target_x = _pp_hand
	# a gift is started a second after it is had, by the screen's own press
	for kind in range(Sim.Kind.FAN, Sim.Kind.SHOVE + 1):
		if _s._counted(kind) > 0 and sim.can_use(kind) and _s._clock - float(_s._chip_at.get(kind, -10.0)) > 1.0:
			_s._press_gift(kind)

func _peapod() -> void:
	var field: Control = _s.field
	var Sim: GDScript = _s.Sim
	var grass := field.size * Vector2(0.5, 0.9)
	_do("the screen opened")
	await _wait(0.2)
	_say()
	_do("a finger down and a slide before Go")
	_press(field, grass, true)
	_move(grass + Vector2(80, 0))
	_press(field, grass + Vector2(80, 0), false)
	await _wait(1.8)
	_say()
	_do("paused")
	_s._pause(true)
	await _wait(0.3)
	_say()
	_do("resumed by a touch")
	_press(field, grass, true)
	_press(field, grass, false)
	await _wait(0.2)
	_say()
	_pp_hand = _s.sim.x
	_bot = true
	var secs := float(_env("SECS", 70))
	var t0 := Time.get_ticks_msec()
	while not _s.sim.is_over() and (Time.get_ticks_msec() - t0) / 1000.0 < secs:
		await process_frame
	_bot = false
	print("  -- %d s: wave %d, score %d, kills %d, caught %d, best streak %d" % [int(_s.sim.t), _s.sim.wave, _s.sim.score,
		_s.sim.kills, _s.sim.caught, _s.sim.best_streak])
	var end_run := func() -> void:
		_bot = false
		if _s.sim.wave_kind == Sim.Wave.WALL:
			_s.sim.wall_y = 1000.0
		elif _s.sim.segs.is_empty():
			# the beat between a millipede gone and the next wave
			_s.sim._end("milli")
		else:
			_s.sim.segs[0].s = Sim.path_len()
	if not _s.sim.is_over():
		print("  -- the line reached, by the probe")
		end_run.call()
	await _wait(1.0)
	# the second run: the best is passed mid-run (set low for the probe)
	var passed := func() -> void:
		_s._best = 5
		_pp_hand = _s.sim.x
		_bot = true
		await _wait(9.0)
	await _end_card_and_cards(field, grass, passed, end_run)

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

# --- thirteen ---

## The longest chain the tray holds, or [].
func _lt_longest() -> Array:
	var sim: RefCounted = _s.sim
	var best: Array = []
	for g: Array in sim.groups_of(_s.Sim.MIN_CHAIN):
		for end: Vector2i in g:
			var chain: Array = _s.Sim.chain_through(g, end, 300)
			if chain.size() > best.size():
				best = chain
			if best.size() == g.size():
				break
	return best

func _lt_at(cell: Vector2i) -> Vector2:
	return _s.px(cell.x, cell.y)

## Waits for the tray to stop moving, and a little more.
func _lt_still(more := 0.1) -> void:
	await process_frame
	while _s.sim != null and _s.busy():
		await process_frame
	await _wait(more)

## Presses on the chain's first pebble and drags through the rest; lets go
## when `release`.
func _lt_draw(chain: Array, release := true) -> void:
	_press(_s.field, _lt_at(chain[0]), true)
	for k in range(1, chain.size()):
		_move(_lt_at(chain[k]))
	if release:
		_press(_s.field, _lt_at(chain[-1]), false)

## The bot's move: the longest chain there is, named by what it makes.
func _lt_play() -> bool:
	var sim: RefCounted = _s.sim
	var chain := _lt_longest()
	if chain.size() < _s.Sim.MIN_CHAIN or sim.phase != _s.Sim.Phase.PLAY:
		return false
	var nv: int = sim.value(chain[-1]) + 1
	_do("chain of %d -> %d%s" % [chain.size(), nv, " (a new number)" if nv > sim.max_v else ""])
	_lt_draw(chain)
	await _lt_still(0.45)
	_say()
	return true

## A tray with no two touching pebbles alike, checked: stuck with clovers
## for a tool, over without.
func _lt_jam(clovers: int) -> void:
	var sim: RefCounted = _s.sim
	for c in _s.Sim.COLS:
		for r in _s.Sim.ROWS:
			sim.grid[c][r].v = 1 + (c % 2) + 2 * (r % 2)
	sim.clovers = clovers
	sim._check()
	_s._play_events()

func _lt_tool(tool: int) -> void:
	_s._tool_buttons[tool].pressed.emit()

func _lt_tap(cell: Vector2i) -> void:
	_press(_s.field, _lt_at(cell), true)
	_press(_s.field, _lt_at(cell), false)

## A pebble whose number is (or is not) `v`, other than `skip`.
func _lt_find(v: int, same: bool, skip := Vector2i(-1, -1)) -> Vector2i:
	for c in _s.Sim.COLS:
		for r in _s.Sim.ROWS:
			var p := Vector2i(c, r)
			if p != skip and (_s.sim.value(p) == v) == same:
				return p
	return Vector2i(-1, -1)

func _thirteen() -> void:
	var field: Control = _s.field
	var Sim: GDScript = _s.Sim
	_do("the screen opened")
	await _wait(0.2)
	_say()
	await _lt_still(0.3)
	_do("Undo with nothing to take back")
	_lt_tool(Sim.Tool.UNDO)
	await _wait(0.3)
	_say()
	var chain := _lt_longest()
	_do("a pebble pressed and let go")
	_lt_draw(chain.slice(0, 1))
	await _wait(0.3)
	_say()
	_do("two pebbles and let go (too short)")
	_lt_draw(chain.slice(0, 2))
	await _wait(0.3)
	_say()
	_do("a chain of %d drawn, one back, on again" % chain.size())
	_lt_draw(chain, false)
	await _wait(0.1)
	_move(_lt_at(chain[-2]))
	await _wait(0.1)
	_move(_lt_at(chain[-1]))
	await _wait(0.1)
	_say()
	_do("let go: the merge lands")
	_press(field, _lt_at(chain[-1]), false)
	await _lt_still(0.45)
	_say()
	var moves := _env("MOVES", 40)
	var played := 0
	while played < moves and await _lt_play():
		played += 1
	print("  -- %d moves: score %d, biggest %d, best chain %d, clovers %d" % [_s.sim.moves, _s.sim.score, _s.sim.max_v,
		_s.sim.best_chain, _s.sim.clovers])
	# three twelves laid by the probe: the thirteen
	for c in 3:
		_s.sim.grid[c][0].v = 12
	_s.sim.max_v = 12
	await _wait(0.2)
	_do("three twelves: the thirteen")
	_lt_draw([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	await _lt_still(3.0)
	_say()
	# the tools, with clovers handed over
	_s.sim.clovers = 5000
	await _lt_still()
	_do("Swap armed")
	_lt_tool(Sim.Tool.SWAP)
	await _wait(0.2)
	_say()
	var a := Vector2i(0, 0)
	_do("  its first pebble picked")
	_lt_tap(a)
	await _wait(0.2)
	_say()
	var twin := _lt_find(_s.sim.value(a), true, a)
	if twin.x >= 0:
		_do("  a second of the same number")
		_lt_tap(twin)
		await _wait(0.2)
		_say()
	_do("  a second pebble: swapped")
	_lt_tap(_lt_find(_s.sim.value(a), false))
	await _lt_still(0.3)
	_say()
	_do("Pluck armed, a pebble tapped")
	_lt_tool(Sim.Tool.PLUCK)
	_lt_tap(Vector2i(2, 3))
	await _lt_still(0.3)
	_say()
	_do("Lift armed, the biggest tapped")
	_lt_tool(Sim.Tool.LIFT)
	_lt_tap(_lt_find(_s.sim.max_v, true))
	await _wait(0.3)
	_say()
	_do("  a smaller pebble: lifted")
	_lt_tap(_lt_find(_s.sim.max_v, false))
	await _lt_still(0.3)
	_say()
	_do("Shuffle")
	_lt_tool(Sim.Tool.SHUFFLE)
	await _lt_still(0.3)
	_say()
	_do("Undo")
	_lt_tool(Sim.Tool.UNDO)
	await _lt_still(0.3)
	_say()
	_do("Pluck armed and put away")
	_lt_tool(Sim.Tool.PLUCK)
	await _wait(0.2)
	_lt_tool(Sim.Tool.PLUCK)
	await _wait(1.2)
	_say()
	print("  -- the tray jammed by the probe, clovers in the bank")
	_do("the tray is stuck")
	_lt_jam(5000)
	await _wait(1.5)
	_say()
	_do("a tool that does not free it (Lift)")
	_lt_tool(Sim.Tool.LIFT)
	_lt_tap(Vector2i(0, 0))
	await _lt_still(0.3)
	_say()
	_do("Shuffle sets it moving")
	_lt_tool(Sim.Tool.SHUFFLE)
	await _lt_still(0.3)
	_say()
	await _lt_play()
	print("  -- jammed again")
	_do("the tray is stuck")
	_lt_jam(5000)
	await _wait(2.0)
	_say()
	_do("End game")
	_button(_s._stuck_box, "EndGame").pressed.emit()
	await _wait(0.4)
	_say()
	var end_run := func() -> void:
		_lt_jam(0)
	# the second run: the best is passed on its first merge (set low)
	var short := func() -> void:
		_s._best = 15
		await _lt_still(0.3)
		for k in 4:
			await _lt_play()
	await _end_card_and_cards(field, _lt_at(Vector2i(2, 2)), short, end_run)

# --- posy ---

## Waits for the bed to finish playing out, and a little more.
func _ps_still(more := 0.1) -> void:
	await process_frame
	var t := 0.0
	while _s.sim != null and _s.busy() and t < 30.0:
		await process_frame
		t += root.get_process_delta_time()
	await _wait(more)

## A drag from `a` far enough toward `b` to swap them.
func _ps_drag(a: Vector2i, b: Vector2i) -> void:
	var from: Vector2 = _s.px(a.x, a.y)
	_press(_s.field, from, true)
	_move(from + Vector2(b - a) * _s._u * 0.5)
	_press(_s.field, from + Vector2(b - a) * _s._u * 0.5, false)

func _ps_tap(cell: Vector2i) -> void:
	_press(_s.field, _s.px(cell.x, cell.y), true)
	_press(_s.field, _s.px(cell.x, cell.y), false)

## The bot's move: the sim's own hint. False with none to make.
func _ps_play() -> bool:
	await _ps_still()
	var sim: RefCounted = _s.sim
	if sim.phase != _s.Sim.Phase.PLAY:
		return false
	var m: Array = sim.hint()
	if m.is_empty():
		return false
	_ps_drag(m[0], m[1])
	return true

## A plain tile (no special) with a plain neighbour: [a, b], taken or not.
func _ps_pair(taken: bool) -> Array:
	var sim: RefCounted = _s.sim
	var moves: Array = sim.all_moves()
	for c in _s.Sim.COLS - 1:
		for r in _s.Sim.ROWS:
			var a := Vector2i(c, r)
			var b := Vector2i(c + 1, r)
			if sim.at(a).is_empty() or sim.at(b).is_empty() or sim.special(a) != 0 or sim.special(b) != 0:
				continue
			if moves.has([a, b]) == taken:
				return [a, b]
	return []

func _posy() -> void:
	var field: Control = _s.field
	var Sim: GDScript = _s.Sim
	_do("the screen opened")
	await _ps_still(0.3)
	_say()
	var idle: Array = _ps_pair(false)
	_do("a tile picked, and put down")
	_ps_tap(idle[0])
	await _wait(0.2)
	_ps_tap(idle[0])
	await _wait(0.2)
	_say()
	_do("a swap that lines nothing up")
	_ps_drag(idle[0], idle[1])
	await _ps_still(0.3)
	_say()
	_label = "(nothing played)"
	var moves := _env("MOVES", 60)
	var played := 0
	while played < 6 and await _ps_play():
		played += 1
	await _ps_still(0.5)
	if _s.sim.phase == Sim.Phase.PLAY:
		# a breeze laid by the probe, tapped where it stands
		var spot: Array = _ps_pair(false)
		if spot.is_empty():
			spot = _ps_pair(true)
		var tile: Dictionary = _s.sim.at(spot[0])
		tile.sp = Sim.Sp.ROW
		_s._tiles[tile.id].sp = Sim.Sp.ROW
		_s.sim.moves_left += 20
		_s._shown_moves += 20
		print("  -- a breeze laid by the probe, tapped")
		_ps_tap(spot[0])
		await _ps_still(0.5)
		# the tools
		for tool: int in [Sim.Tool.TROWEL, Sim.Tool.SWAP, Sim.Tool.BOMB, Sim.Tool.RAINBOW]:
			if _s.sim.phase != Sim.Phase.PLAY:
				break
			_s.sim.tools[tool] = 1
			var pair: Array = _ps_pair(false)
			if pair.is_empty():
				pair = _ps_pair(true)
			_do("%s armed" % Sim.TOOL_KEYS[tool])
			_s._tool_buttons[tool].pressed.emit()
			await _wait(0.2)
			_say()
			_label = "(nothing played)"
			_ps_tap(pair[0])
			if tool == Sim.Tool.SWAP:
				await _wait(0.2)
				_ps_tap(pair[1])
			await _ps_still(0.5)
			_do("%s with none left" % Sim.TOOL_KEYS[tool])
			_s._tool_buttons[tool].pressed.emit()
			await _wait(0.2)
			_say()
	_label = "(nothing played)"
	while played < moves and await _ps_play():
		played += 1
	await _ps_still(0.5)
	print("  -- %d moves: day %d, score %d, specials made %d, best cascade %d" % [_s.sim.moves, _s.sim.day, _s.sim.score,
		_s.sim.made, _s.sim.best_cascade])
	if _s.sim.phase == Sim.Phase.PLAY:
		print("  -- one move left, the day short: the offer")
		for g: Dictionary in _s.sim.goals:
			g.need = int(g.got) + 99
		_s.sim.moves_left = 1
		_label = "(nothing played)"
		await _ps_play()
		await _ps_still(0.8)
	if _s.sim.is_offered():
		_do("the offer taken")
		_button(_s._offer, "Take").pressed.emit()
		await _ps_still(0.5)
		_say()
		print("  -- one move left again: out of moves")
		_s.sim.moves_left = 1
		_label = "(nothing played)"
		await _ps_play()
		await _ps_still(0.5)
	var end_run := func() -> void:
		_s.sim.give_up()
		_s._take_events()
	# the second run: the best is passed mid-run (set low for the probe)
	var short := func() -> void:
		_s._best = 15
		_label = "(nothing played)"
		for k in 4:
			await _ps_play()
		await _ps_still(0.3)
	await _end_card_and_cards(field, _s.px(3, 3), short, end_run)

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
