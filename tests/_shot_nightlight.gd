extends SceneTree

## Nightlight, shot at fixed beats through the real menu:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_nightlight.gd -- <outdir> [reduce] [en|pt|es] [fresh]
##
## 1 the Arcade tab with its card, 2 a new star in its ring, 3 a finger down
## on the ring's fullest part (a ScreenTouch, as a phone sends it) 0.2 s
## after it landed, its light still there, 3b the arc that finger then
## dragged along (a ScreenDrag a frame, braking as often as a held finger
## does) a second and a half after it lifted, still warm from the brake (the
## log says where that arc is twenty seconds on), 4 the ring a steady hand
## has braked for two minutes, with what the gas has made, 4b a planet the
## tide has torn, 4c a sky as full as it gets (the draw calls' worst; its
## gas and rocks are laid from a seed, so every run shoots the same sky), 5a
## the two powers
## offered at the next mark (the card comes up by itself), 5b one picked and
## on its disc, 5e the card opened on a held finger (the log says the card
## stayed down while the finger did, that the finger was dropped as it
## opened, that a press under it braked nothing and a pick in its first
## half second took nothing however late it lifted; then that after a lift
## it waits OFFER_CALM, comes up by itself and a tile pressed after the
## half second is taken), 5c the star with nothing to burn, dim, 6 a
## heavy star burning carbon, a giant, 6c three relics put by hand round
## it (a white dwarf, a neutron star, an old black hole, each with its
## nebula), 6b the powers it holds, 7 the shop
## with a tile just bought, 8a-8f the supernova (the core falling in, the
## layers leaving, the camera pulling back from the neutron star it leaves,
## panning to the new star, the new star condensing), 11 the perks, 12 one
## drawn, 13 the new star among the gas, 9a-9b a star of four Suns whose
## carbon core cannot light letting its layers go as a nebula (9c the camera
## between the white dwarf and the birthplace, 9b the new star after),
## 13b-13c a star letting go, 6d a later star's iron-rich ring four minutes
## on with its worlds and the line that names them, 6e a star of three Suns
## a minute into a ring its disc half covers, the gas in the disc warm and
## the ring outside it kept full by the far sky (both put there by hand:
## `system`, `half`), 14-16 the tutorial's four pages (14 the GAS
## page 0.2 s after its second press, 14b the gas that press sent half way
## in, 16b the END page's camera), 17 the tab again with the star and its
## relics and its worlds on its card.
## Every run but `fresh` opens a kept star (a first cloud saved before the
## screen opens, so nothing is born on screen); `fresh` deletes the file, so
## the screen opens on a first star condensing out of its cloud (0 the birth,
## 0b after it, 2b the ring two seconds after the birth is over) and stops
## there.
## Prints the draw calls at each shot and the frames since the last with
## their mean and longest gap. The star and the wallet are throwaway files.
## Every guard is checked (`_check`): a line that starts FAIL, and the run
## exits 1 at its end, the rest of the beats shot all the same. A card's
## tiles and buttons are pressed with real ScreenTouches pushed into the
## window (a Button answers a ScreenTouch as it does a mouse button here,
## with mouse-from-touch off), timed from the moment the card came up.
## The beats' clock never moves more than MOST_STEP a frame, so a step that
## runs the sim for seconds does not bring the next beats up with it. The
## sky's own filter is IGNORE for the whole run and every press goes
## straight to the screen's `_on_sky_input`: the real pointer over the
## window would brake too.

const Sim = preload("res://arcade/nightlight_sim.gd")

const STEPS := [
	[1.6, "tab"], [2.8, "shot", "1_tab"],
	[2.9, "open"], [3.9, "shot", "2_start"],
	# a finger down, then 1.6 s along half a radian of the ring: it brakes as
	# it lands and at 0.6, 1.2 and 1.8 s
	[4.0, "press"], [4.2, "shot", "3_press"], [4.3, "drag", 1.6, 0.5], [6.0, "let_go"],
	# the arc while it is still warm (a brake's flush is gone in six seconds),
	# then where it has got to twenty seconds on, for the log
	[6.1, "run", 1.0, false], [6.5, "shot", "3b_falling"], [6.6, "run", 19.0, false],
	[7.1, "run", 120.0, true], [9.0, "shot", "4_disc"],
	[9.1, "planet"], [12.0, "shot", "4b_torn"],
	[12.1, "crowd"], [13.0, "shot", "4c_full"],
	[13.1, "grow"], [14.6, "shot", "5a_pick"], [14.7, "pick", 0], [15.3, "shot", "5b_picked"],
	# the card and the finger: held down 1.5 s past a pick (PICK_WAIT and
	# OFFER_CALM are 1.2 together), the card opened on it, then a finger
	# lifted and the card left to come by itself, 1.2 s on. A real touch on
	# a tile each time the card is up: one that lands 0.2 s after it shows
	# and lifts at 0.8 takes nothing, one that lands at 0.7 and lifts at 0.9
	# takes the power
	[15.4, "hold_grow"], [16.9, "card_held"], [16.91, "press_card", "pick", "tile", 0.2, 0.8, false], [17.3, "shot", "5e_card_drops_finger"], [17.9, "pick", 0],
	[18.0, "hold_grow"], [18.3, "let_go"], [18.31, "press_card", "pick", "tile", 0.7, 0.9, true], [18.7, "calm", "pick", false], [19.8, "calm", "pick", true], [20.58, "picked"],
	[20.6, "starve"], [23.2, "shot", "5c_dim"], [23.3, "feed"],
	[23.4, "heavy"], [23.5, "run", 40.0, true], [26.7, "shot", "6_giant"],
	[26.75, "relics"], [26.95, "shot", "6c_relics"],
	[27.05, "powers"], [27.4, "shot", "6b_powers"], [27.5, "powers_x"],
	[27.6, "shop"], [27.7, "buy"], [28.2, "shot", "7_shop"], [28.3, "shop_x"],
	# the supernova: swap at 32.0, the pull back to 33.2, the pan to 36.2,
	# the close to 40.2 (reduce motion: over at 36.0). A finger is on the sky
	# from 29.5 to 41.0, so the perks wait for it and OFFER_CALM: up at 41.6,
	# with a touch on Buy (0.2 to 0.8 s after) and one outside the card (0.3 to
	# 0.5) that do nothing
	[28.4, "iron"], [29.3, "shot", "8a_fall"], [29.5, "sky_down"], [30.1, "shot", "8b_leaving"], [31.0, "shot", "8c_shells"],
	[32.5, "shot", "8d_pull_back"], [32.51, "where"], [33.3, "where"], [34.2, "shot", "8e_pan"], [34.21, "where"], [37.2, "shot", "8f_rising"],
	[40.9, "perks_held"], [41.0, "let_go"], [41.01, "press_card", "perks", "buy", 0.2, 0.8, false], [41.02, "press_card", "perks", "scrim", 0.3, 0.5, false],
	[41.4, "calm", "perks", false], [42.6, "calm", "perks", true],
	[43.3, "shot", "11_perks"], [43.4, "perk"], [43.8, "shot", "12_perk"],
	[43.9, "perks_x"], [45.9, "shot", "13_new"],
	# the nebula: swap at 50.2, the pull back to 51.4, the pan to 54.4, the
	# close to 58.4 and the perks (reduce motion: over at 54.2)
	[46.0, "nebula"], [48.5, "shot", "9a_nebula_leaving"], [50.7, "where"], [51.5, "where"], [52.9, "shot", "9c_nebula_pan"], [52.91, "where"],
	[58.6, "perks_x"], [58.9, "shot", "9b_after_nebula"],
	# the fade: swap at 64.0, the pull back to 65.2, over at 72.2 (reduce
	# motion: 68.0)
	[59.0, "let_go_star"], [62.4, "shot", "13b_letting_go"], [64.5, "where"], [65.4, "shot", "13c_gone"], [65.41, "where"], [72.7, "perks_x"],
	# the new star's sky put there by hand: an iron-rich ring and its worlds
	# four minutes on, then three Suns and a minute into a ring its disc half
	# covers. That second beat was called `6e_half_eaten` and never showed a
	# ring half eaten: the far sky makes a ring up by need as fast as the
	# disc takes it, so the name says what is in the shot
	[72.8, "system"], [73.6, "shot", "6d_system"], [73.65, "line", "6d", 1],
	[73.7, "half"], [74.5, "shot", "6e_disc_over_ring"], [74.55, "line", "6e", 0],
	# GAS presses 0.8 and 1.6 s into its page and its gas is half way in at 19
	[74.6, "tutor"], [76.4, "shot", "14_tut_gas"], [92.6, "shot", "14b_tut_gas_in"],
	[92.7, "page", 1], [94.7, "shot", "15_tut_worlds"],
	# BURN's star is a giant (swell 1, 20 Suns) from 12.0 to 13.8 s into the page
	[94.8, "page", 2], [100.8, "shot", "15b_tut_burn"], [107.9, "shot", "15c_tut_burn_giant"],
	[108.0, "page", 3], [111.1, "shot", "16_tut_end"], [115.6, "shot", "16b_tut_end_pan"],
	[115.7, "leave"], [116.9, "shot", "17_tab_after"], [116.95, "card"],
	[117.0, "quit"],
]
## The beats' clock moves this much a frame at most, in seconds.
const MOST_STEP := 0.1
## `fresh`: no file, so the screen opens on a first star being born.
const FRESH_STEPS := [
	[1.6, "tab"], [2.8, "fresh"],
	[2.9, "open"], [4.4, "shot", "0_birth"], [7.4, "shot", "0b_born"], [8.9, "shot", "2b_ring"],
	[9.0, "quit"],
]

var _menu: Node
var _s: Node
var _t := 0.0
var _i := 0
var _out := "/tmp"
var _tmp: Array = []
var _reduce := false
var _fresh := false
var _steps: Array = STEPS
var _frames := 0
var _gap_sum := 0.0
var _gap_max := 0.0
## Where finger 0 is, in the sim's units, and the drag it is on: seconds
## left of `_drag_all`, round the star by `_drag_arc` radians from `_drag_from`.
var _spot_now := Vector2.ZERO
var _drag_left := 0.0
var _drag_all := 0.0
var _drag_arc := 0.0
var _drag_from := Vector2.ZERO
var _marked: Array = []
var _arc_s := 0.0
## The guards checked and how many failed; what is still to do at a time of
## the clock ([msec, Callable], soonest first); and what waits for a card to
## come up ({card, plan}: `plan` is called with the msec it came up at).
var _checks := 0
var _fails := 0
var _due: Array = []
var _watch: Array = []
var _fingers_used := 0

func _initialize() -> void:
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_reduce = args.has("reduce")
	_fresh = args.has("fresh")
	if _fresh:
		_steps = FRESH_STEPS
	# the language for this run only: Locale.set_current would write it to
	# the player's own file
	for lang: String in ["en", "pt", "es"]:
		if args.has(lang):
			load("res://core/locale.gd")._current = lang
	var dir := OS.get_user_data_dir()
	var wallet: Node = root.get_node("Wallet")
	DirAccess.remove_absolute(dir + "/_shot_wallet.cfg")
	wallet.path = dir + "/_shot_wallet.cfg"
	wallet.reload()
	_tmp.append(wallet.path)
	Sim.path = dir + "/_shot_nightlight.cfg"
	DirAccess.remove_absolute(Sim.path)
	_tmp.append(Sim.path)
	var main: Node = load("res://world/main.tscn").instantiate()
	main.set_script(load("res://tests/_offline_main.gd"))
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _finish() -> void:
	for p: String in _tmp:
		DirAccess.remove_absolute(p)
	print("throwaway files removed")

## The run's end: 1 if a guard failed or one never ran.
func _end() -> bool:
	_finish()
	if not _due.is_empty() or not _watch.is_empty():
		_fails += 1
		print("FAIL %d timed presses never ran (%d still waiting for a card)" % [_due.size() + _watch.size(), _watch.size()])
	print("guards: %d checked, %d failed" % [_checks, _fails])
	if _fails > 0:
		quit(1)
		return false
	return true

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("%s %s" % ["ok  " if ok else "FAIL", what])

## `do` at `msec` of the engine's clock.
func _at(msec: int, do: Callable) -> void:
	_due.append([msec, do])
	_due.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))

## A real touch pushed into the window at `at` (the window's pixels).
func _push(down: bool, at: Vector2, finger: int) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = finger
	ev.pressed = down
	ev.position = at
	root.push_input(ev)

## Where a card is pressed, in the window's pixels: a pick's first tile, the
## perks' Buy, or the scrim outside the perks' card.
func _target(what: String) -> Vector2:
	var on: Control = _s._pick_tiles[0].button if what == "tile" else (_s._perk_buy if what == "buy" else _s._perks)
	var local := Vector2(16.0, 16.0) if what == "scrim" else on.size * 0.5
	return root.get_final_transform() * (on.get_global_transform() * local)

## What that press would change: the picks taken, the perks drawn, or the
## perks' card being up.
func _count(what: String) -> int:
	if what == "tile":
		return int(_s.sim.picks)
	return int(_s.sim.bought) if what == "buy" else int(_s._perks.visible)

## A card came up at `base` msec: a touch lands on `what` of it `land`
## seconds after and lifts `lift` seconds after, and it does something or
## not, as `expect` says.
func _press_plan(base: int, what: String, land: float, lift: float, expect: bool) -> void:
	_fingers_used += 1
	var finger := 4 + _fingers_used
	var state := {}
	_at(base + int(land * 1000.0), func() -> void:
		state.at = _target(what)
		state.before = _count(what)
		state.landed = (Time.get_ticks_msec() - base) / 1000.0
		_push(true, state.at, finger))
	_at(base + int(lift * 1000.0), func() -> void:
		state.lifted = (Time.get_ticks_msec() - base) / 1000.0
		_push(false, state.at, finger))
	_at(base + int(lift * 1000.0) + 80, func() -> void:
		var did: bool = _count(what) != int(state.before)
		var early: bool = float(state.landed) < float(_s.PICK_DEAF)
		_check(did == expect and early != expect and float(state.lifted) >= float(_s.PICK_DEAF),
			"a touch on the %s that landed %.2f s after the card came up and lifted at %.2f: it did something %s (%s)" % [what, state.landed, state.lifted, did, expect]))

## A finger on the sky at `spot` of the sim, as a phone sends it (the
## project has mouse-from-touch off): straight to the screen, in the sky's
## own pixels.
func _touch(down: bool, spot: Vector2, finger := 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = finger
	ev.pressed = down
	ev.position = _s.sky.world(spot)
	_s._on_sky_input(ev)

## That finger, moved to `spot`.
func _drag(spot: Vector2, finger := 0) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = finger
	ev.position = _s.sky.world(spot)
	_s._on_sky_input(ev)

## Where a steady hand presses: the middle of the fullest of 24 slices of
## what is outside the disc (tests/_probe_nightlight.gd's `_spot`).
func _spot(sim: RefCounted) -> Vector2:
	var rh: float = sim.haze_r()
	var slices := PackedFloat32Array()
	slices.resize(24)
	var sum: Array[Vector2] = []
	sum.resize(24)
	sum.fill(Vector2.ZERO)
	for b: Sim.Body in sim.bodies:
		if b.pos.length() <= rh:
			continue
		var k := int(fposmod(b.pos.angle(), TAU) / TAU * 24.0) % 24
		slices[k] += b.m
		sum[k] += b.pos * b.m
	var top := 0
	for k in 24:
		if slices[k] > slices[top]:
			top = k
	return sum[top] / slices[top] if slices[top] > 0.0 else Vector2.ZERO

## How many bodies still feel a brake.
func _sinking() -> int:
	var n := 0
	for b: Sim.Body in _s.sim.bodies:
		if b.sink > 0.0:
			n += 1
	return n

## The star grown past the next pick it has not been offered.
func _grow() -> void:
	_s.sim.bodies.clear()
	_s.sim.mass = Sim.START * Sim.mile(_s.sim.picks) * 1.1
	_s.sim.fuel = _s.sim.mass * 0.6
	_s.sim.env = _s.sim.mass * 0.25

## `seconds` of the sim at once, buying the cheapest tile it can; with
## `press` a steady hand brakes the ring's fullest part every `flow_gap()`,
## choosing the place again every three seconds, as the probe's bot does.
func _run(seconds: float, press: bool) -> void:
	var since := 0.0
	var spot := Vector2.ZERO
	var spot_in := 0.0
	var braked := 0
	var t0 := Time.get_ticks_msec()
	for i in int(seconds / Sim.STEP):
		since += Sim.STEP
		spot_in -= Sim.STEP
		if press and spot_in <= 0.0:
			spot_in = 3.0
			spot = _spot(_s.sim)
		if press and since >= _s.sim.flow_gap():
			since = 0.0
			if _s.sim.brake(spot, _s.sim.press_r()) > 0:
				braked += 1
		_s.sim.tick()
		_s.sim.events.clear()
		for tile: String in Sim.TILES:
			if _s.sim.can_buy(tile):
				_s.sim.buy(tile)
		while _s.sim.owed() > 0:
			_s.sim.pick(0)
	_s._refresh_tiles()
	var solids := 0
	var inside := 0
	var fattest := 0.0
	for b: Sim.Body in _s.sim.bodies:
		if b.kind != Sim.Kind.GAS:
			solids += 1
		else:
			fattest = maxf(fattest, b.m)
			if b.pos.length() < _s.sim.haze_r():
				inside += 1
	print("ran %.0f s in %d ms, %d presses braked something: %.2f Suns, light %.1f, %d gas (%d in the disc, the heaviest puff %.3f) and %d solids (%s), lv %s, picks %d" % [seconds, Time.get_ticks_msec() - t0, braked, _s.sim.suns(), _s.sim.light,
		_s.sim.bodies.size() - solids, inside, fattest, solids, str(_s.sim.system()), str(_s.sim.lv), _s.sim.picks])

## A world of `m` put on a circle `far` from the star, `turn` round it, made
## of gas with `metal` of a dead star's iron in it.
func _world(m: float, far: float, turn: float, metal: float) -> Sim.Body:
	var pos := Vector2.from_angle(turn) * far
	var b: Sim.Body = _s.sim.add(Sim.Kind.PLANET, m, pos, _s.sim.circle_vel(pos))
	b.metal = metal
	return b

## The line that names the system says what the sim counts, `planets` of
## them at least, and is where it should be.
func _check_line(what: String, planets: int) -> void:
	var n: Dictionary = _s.sim.system()
	var line: Label = _s._system
	var chips: Control = _s._chips
	var top: float = chips.position.y + chips.size.y if chips.visible else float(_s.SYSTEM_Y)
	_check(int(n.planets) >= planets and line.visible and line.text != "" and line.text == _s._system_line() and is_equal_approx(line.position.y, top)
		and line.position.x + line.size.x <= _s.sky.size.x,
		"%s: the line \"%s\" names %s, shown %s, %s (its top %d, the discs end at %d), %d px of the sky's %d" % [what, line.text, str(n), line.visible,
			"under the powers' discs" if chips.visible else "at the sky's top with no power held", int(line.position.y), int(chips.position.y + chips.size.y), int(line.position.x + line.size.x), int(_s.sky.size.x)])

## 6d: the new star left by the fade, set to one Sun with a one-Sun
## newborn's ring whatever perk the run drew (an Ember's newborn is two
## Suns, and its ring farther out), with a later sky's ring, the richest in
## a dead star's dust the sim lays (ASH_MOST), and three worlds put on
## circles in it by hand, two planets and a core that keeps gas: the pace is
## not this harness's to wait for. Four minutes of the sim with no hand,
## then the shot.
func _system() -> void:
	var sim: RefCounted = _s.sim
	sim.bodies.clear()
	sim.novas = 2
	sim.mass = Sim.START
	sim.fuel = sim.mass * 0.6
	sim.env = sim.mass * 0.25
	sim._set_ring()
	sim._lay_ring(Sim.RING, Sim.RING_M, Sim.ASH_H, Sim.ASH_MOST)
	var mid: float = (sim.ring.x + sim.ring.y) * 0.5
	_world(0.009, lerpf(sim.ring.x, mid, 0.5), 0.6, 1.0)
	_world(0.011, lerpf(mid, sim.ring.y, 0.5), 3.9, 1.0)
	_world(0.016, mid, 2.2, 1.0)
	# `system()` counts only what is on a closed path: the three are on circles
	_check(int(sim.system().planets) == 3, "6d: the three worlds put by hand are on closed paths and counted: %s" % str(sim.system()))
	_run(240.0, false)
	print("a later star's ring 240 s on: %.2f Suns, novas %d, dust share %.3f, the system %s, the line \"%s\"" % [sim.suns(), sim.novas, sim.dusty, str(sim.system()), _s._system_line()])

## 6e: that star at three Suns, its ring laid again where it was born with
## it (the plain disc of three Suns covers its inner half) and two planets
## on circles in the outer half, a minute on with no hand: long enough for
## what the disc has to be winding in. It is a star eating a ring the far
## sky keeps full, not a ring half eaten: what the disc takes is made up
## by need, and the log says how much gas is outside the disc against what
## the ring weighed at birth. The powers it has grown past are taken first,
## never the Haze (a wider disc covers the whole ring), so the line stands
## under their discs.
func _half() -> void:
	var sim: RefCounted = _s.sim
	sim.bodies.clear()
	sim.mass = Sim.START * 3.0
	sim.fuel = sim.mass * 0.6
	sim.env = sim.mass * 0.25
	sim._lay_ring(Sim.RING, Sim.RING_M, Sim.ASH_H, Sim.ASH_MOST)
	_world(0.009, lerpf(sim.ring.x, sim.ring.y, 0.8), 1.1, 1.0)
	_world(0.01, lerpf(sim.ring.x, sim.ring.y, 0.95), 4.4, 1.0)
	_check(int(sim.system().planets) == 2, "6e: the two worlds put by hand are on closed paths and counted: %s" % str(sim.system()))
	while sim.owed() > 0:
		sim.pick(1 if String(sim.offering()[0]) == "haze" else 0)
	var ring0: int = sim.gas_count()
	_run(60.0, false)
	var out := 0
	for b: Sim.Body in sim.bodies:
		if b.kind == Sim.Kind.GAS and b.pos.length() >= sim.haze_r():
			out += 1
	print("three Suns 60 s on: %.2f Suns, the disc %d px, the ring %s, %d puffs where %d were laid and %d of them outside the disc, weighing %.2f of the ring's %.2f at birth, the system %s" % [sim.suns(), int(sim.haze_r()), str(sim.ring), sim.gas_count(), ring0, out, sim.gas_outside(), sim.ring_m, str(sim.system())])

func _process(delta: float) -> bool:
	_t += minf(delta, MOST_STEP)
	_frames += 1
	_gap_sum += delta
	_gap_max = maxf(_gap_max, delta)
	if _t > 140.0:
		_fails += 1
		print("FAIL the run did not reach its end")
		return _end()
	for w: Dictionary in _watch.duplicate():
		if (w.card as Control).visible:
			_watch.erase(w)
			(w.plan as Callable).call(int(_s._raised_at))
	while not _due.is_empty() and Time.get_ticks_msec() >= int(_due[0][0]):
		((_due.pop_front() as Array)[1] as Callable).call()
	if _drag_left > 0.0:
		_drag_left = maxf(0.0, _drag_left - delta)
		_spot_now = _drag_from.rotated(_drag_arc * (1.0 - _drag_left / _drag_all))
		_drag(_spot_now)
	while _i < _steps.size() and _t >= float(_steps[_i][0]):
		var step: Array = _steps[_i]
		_i += 1
		match String(step[1]):
			"shot":
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png("%s/nightlight_%s.png" % [_out, step[2]])
				print("shot %s draws=%d bodies=%d | since the last shot: %d frames, %.2f ms a frame (longest %.1f)" % [step[2],
					int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
					_s.sim.bodies.size() if is_instance_valid(_s) and _s.sim != null else -1,
					_frames, _gap_sum / maxi(1, _frames) * 1000.0, _gap_max * 1000.0])
				_frames = 0
				_gap_sum = 0.0
				_gap_max = 0.0
			"tab":
				if _reduce:
					load("res://core/motion.gd").reduce = true
				if _menu.gifts_sheet.is_open():
					_menu.gifts_sheet.close()
				_menu._show_tab("arcade")
			"fresh":
				DirAccess.remove_absolute(Sim.path)
				print("fresh: the star's file is gone: %s" % (not FileAccess.file_exists(Sim.path)))
			"open":
				if not _fresh:
					# a kept star: its first cloud, saved, so the screen opens on it as it stands
					var first: RefCounted = Sim.new()
					first.born()
					first.save()
				_menu._open_arcade("nightlight")
				_s = _menu.get_node("Nightlight")
				# the real pointer over the window cannot press the sky
				_s.sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
				print("opened: fresh %s, a birth playing %s, %d puffs, sky ending %s, ends in %.1f s" % [_s.sim.fresh, _s._birth, _s.sim.bodies.size(), _s.sky.ending(), _s.sky.end_time()])
			"press":
				print("star open: %.2f Suns, field %s, u %.3f, the star at %s, %d px; zoom %.3f, the ring %s is %d to %d px from it, %d puffs, the hint up %s" % [_s.sim.suns(), _s.sky.size, _s.sky.u, _s.sky.centre, _s.sky.star_px(),
					_s.sim.zoom(), _s.sim.ring, int(_s.sky.world(Vector2(_s.sim.ring.x, 0.0)).x - _s.sky.centre.x), int(_s.sky.world(Vector2(_s.sim.ring.y, 0.0)).x - _s.sky.centre.x), _s.sim.gas_count(), _s._hint.visible])
				_spot_now = _spot(_s.sim)
				_touch(true, _spot_now)
				var hit := 0
				for e: Dictionary in _s.sim.events:
					if String(e.kind) == "brake":
						hit += int(e.n)
				print("pressed at %s of the sim, %s of the sky (and back: %s): braked %d, fingers %s, a press %.0f px wide in the sim and %.0f on the screen, one every %.2f s" % [_spot_now, _s.sky.world(_spot_now), _s.sky.unworld(_s.sky.world(_spot_now)), hit,
					str(_s._fingers.keys()), _s.sim.press_r(), _s.sim.press_r() * _s.sim.zoom() * _s.sky.u, _s.sim.flow_gap()])
			"drag":
				_drag_all = float(step[2])
				_drag_left = _drag_all
				_drag_arc = float(step[3])
				_drag_from = _spot_now
			"let_go":
				var sinking := _sinking()
				if _marked.is_empty():
					for b: Sim.Body in _s.sim.bodies:
						if b.sink > 0.0:
							_marked.append(b.id)
				_touch(false, _spot_now)
				print("let go at %s: %d bodies braked and still sinking, fingers %s, the hint up %s" % [_spot_now, sinking, str(_s._fingers.keys()), _s._hint.visible])
			"planet":
				# on a circle a little outside where the tide tears it, and the disc brings it in
				var far: float = _s.sim.tear_r(0.03) * 1.004
				var b: Sim.Body = _s.sim.add(Sim.Kind.PLANET, 0.03, Vector2(0.0, -far), Vector2(sqrt(_s.sim.gm() / far), 0.0))
				b.ice = 0.6
				_s.sim._sort(b)
			"crowd":
				# as full a sky as the sim lets there be, laid from a seed. The
				# rocks go round at random: at a fixed step of the turn every
				# third one, the icy ones, stood on seven spokes, and their tails
				# made rays no game sky has
				var rng := RandomNumberGenerator.new()
				rng.seed = 41
				while _s.sim.gas_count() < Sim.MOST:
					var pos: Vector2 = Vector2.from_angle(rng.randf() * TAU) * _s.sim.haze_r() * rng.randf_range(0.7, 0.97)
					var puff: Sim.Body = _s.sim.add(Sim.Kind.GAS, Sim.RING_M / Sim.RING, pos, _s.sim.circle_vel(pos) * rng.randf_range(0.97, 1.0))
					puff.h = _s.sim.puff_h()
					puff.dust = _s.sim.dusty
				for k in 140:
					var far: float = _s.sim.haze_r() * (0.55 + 0.004 * k)
					var way := Vector2.from_angle(rng.randf() * TAU)
					var b: Sim.Body = _s.sim.add(Sim.Kind.ROCK, 0.001 + 0.0002 * (k % 9), way * far, way.orthogonal() * -sqrt(_s.sim.gm() / far))
					b.ice = 0.8 if k % 3 == 0 else 0.0
					_s.sim._sort(b)
				print("crowd: %d bodies up" % _s.sim.bodies.size())
			"run":
				_run(float(step[2]), bool(step[3]))
				if not bool(step[3]):
					var rs := []
					for b: Sim.Body in _s.sim.bodies:
						if _marked.has(b.id):
							rs.append(int(b.pos.length()))
					rs.sort()
					_arc_s += float(step[2])
					var warm := 0.0
					for b: Sim.Body in _s.sim.bodies:
						if _marked.has(b.id):
							warm = maxf(warm, b.sink)
					print("the braked arc %.0f s on: %d of %d left, the warmest still %.2f of a brake's flush, %s from the star; the ring starts at %d, the disc at %d" % [_arc_s, rs.size(), _marked.size(), warm, str(rs), int(_s.sim.ring.x), int(_s.sim.haze_r())])
			"grow":
				# past the next pick: the card comes up by itself
				_grow()
				print("grown to %.1f Suns: owed %d, fingers %s" % [_s.sim.suns(), _s.sim.owed(), str(_s._fingers.keys())])
			"hold_grow":
				# a finger down on the sky, and the star past a pick under it
				_grow()
				_spot_now = Vector2(_s.sim.ring.y * 0.8, 0.0)
				_touch(true, _spot_now)
				_check(_s.sim.owed() == 1 and _s._fingers.has(0) and not _s._pick.visible, "held and grown to %.1f Suns: owed %d, fingers %s, card up %s" % [_s.sim.suns(), _s.sim.owed(), str(_s._fingers.keys()), _s._pick.visible])
			"card_held":
				_check(not _s._pick.visible and _s._fingers.has(0) and _s.sim.owed() == 1, "1.5 s on with the finger down the card is not up: card up %s, fingers %s, owed %d" % [_s._pick.visible, str(_s._fingers.keys()), _s.sim.owed()])
				_s.open_pick()
				_check(_s._pick.visible and _s._fingers.is_empty(), "the card opened on it drops the finger: card up %s, fingers empty %s" % [_s._pick.visible, _s._fingers.is_empty()])
				# gas right under a second finger, which a press would brake
				var under: Sim.Body = _s.sim.add(Sim.Kind.GAS, Sim.PUFF, _spot_now, _s.sim.circle_vel(_spot_now))
				var v0 := under.vel
				_s.sim.events.clear()
				_touch(true, _spot_now, 1)
				var brakes := 0
				for e: Dictionary in _s.sim.events:
					if String(e.kind) == "brake":
						brakes += 1
				_check(brakes == 0 and under.vel == v0 and _s._fingers.is_empty(), "a press under the card brakes nothing: %d brake events, the gas under it slowed %s, fingers empty %s" % [brakes, under.vel != v0, _s._fingers.is_empty()])
				_touch(false, _spot_now, 1)
				_touch(false, _spot_now)
			"press_card":
				_watch.append({"card": _s._pick if String(step[2]) == "pick" else _s._perks,
					"plan": _press_plan.bind(String(step[3]), float(step[4]), float(step[5]), bool(step[6]))})
			"calm":
				var card: Control = _s._pick if String(step[2]) == "pick" else _s._perks
				_check(card.visible == bool(step[3]), "%.1f s after the finger lifted the %s card is %s: up %s, fingers %s, on the sky %s" % [(Time.get_ticks_msec() - int(_s._lifted_at)) / 1000.0, step[2],
					"up" if bool(step[3]) else "not up", card.visible, str(_s._fingers.keys()), str(_s._touching.keys())])
			"picked":
				_check(not _s._pick.visible, "the pick taken, the card is closed: card up %s, powers %s" % [_s._pick.visible, str(_s.sim.power)])
			"sky_down":
				# a finger on the sky through the end: not read, and still in the perks' way
				_spot_now = Vector2(0.0, -_s.sim.ring.y * 0.8)
				_touch(true, _spot_now)
				_check(_s._fingers.is_empty() and _s._touching.has(0), "a finger down while the star ends is not read but is known: fingers %s, on the sky %s" % [str(_s._fingers.keys()), str(_s._touching.keys())])
			"perks_held":
				_check(not _s.sky.ending() and _s._perks_due and not _s._perks.visible, "the end over and the finger still down, the perks wait: sky ending %s, perks due %s, perks up %s" % [_s.sky.ending(), _s._perks_due, _s._perks.visible])
			"pick":
				print("pick open: %s, on offer %s, owed %d" % [_s._pick.visible, str(_s.sim.offer), _s.sim.owed()])
				var had: int = _s.sim.picks
				_s._on_pick(int(step[2]))
				_check(_s.sim.picks == had + 1 and not _s._pick.visible, "picked: %s, card open %s" % [str(_s.sim.power), _s._pick.visible])
			"starve":
				# a small star again, as this beat has always been shot
				_s.sim.mass = Sim.START * 2.2
				_s.sim.bodies.clear()
				_s.sim.passing = false
				_s.sim.fuel = 0.0
			"feed":
				print("dim: awake %s, lit %.2f, %d K, cold %.1f s, %s" % [_s.sim.awake, _s.sim.lit, int(_s.sim.temp()), _s.sim.cold, _s._nova_l.text])
				_s.sim.fuel = _s.sim.mass * 0.5
				_s.sim.passing = true
			"heavy":
				# twelve Suns, most of the way up the chain
				_s.sim.mass = Sim.START * 12.0
				_s.sim.fuel = _s.sim.mass * 0.55
				_s.sim.env = _s.sim.mass * 0.2
				_s.sim.made.assign([0.05 * _s.sim.mass, 0.1 * _s.sim.mass, 0.02 * _s.sim.mass, 0.01 * _s.sim.mass, 0.01 * _s.sim.mass, 0.02 * _s.sim.mass])
				_s.sim.ignited.assign([true, true, true, true, true, true])
				_s.sim.light = 5000.0
				while _s.sim.owed() > 0:
					_s.sim.pick(_s.sim.owed() % 2)
			"relics":
				_s.sim.add_relic(Sim.Relic.WD, 6.0, Vector2(-900, -700), _s.sim.layers())
				_s.sim.add_relic(Sim.Relic.NS, 14.0, Vector2(1100, 300), _s.sim.layers())
				_s.sim.add_relic(Sim.Relic.BH, 50.0, Vector2(200, 1300), _s.sim.layers())
				_s.sim.relics[2].age = 300.0
				var spots := []
				for rel: Dictionary in _s.sim.relics:
					spots.append(_s.sky.world(rel.pos as Vector2))
				print("relics: %d, zoom %.3f, on screen at %s, field %s" % [_s.sim.relics.size(), _s.sim.zoom(), str(spots), _s.sky.size])
			"powers":
				_s._chips.pressed.emit()
				print("powers held: %s, card open %s" % [str(_s.sim.power), _s._powers.visible])
			"powers_x":
				_s._powers.find_child("Back", true, false).pressed.emit()
			"shop":
				_s._shop_b.pressed.emit()
				print("shop open: %s, badge %d" % [_s._shop.visible, _s._shop_b.badge])
			"buy":
				var before: int = mini(int(_s.sim.lv.pure), 3)
				_s.sim.lv.pure = before
				# the run before this spent the light on tiles: enough for this one
				_s.sim.light = maxf(_s.sim.light, float(_s.sim.cost("pure")) + 80.0)
				_s._on_tile("pure")
				print("bought pure gas: %d -> %d, light %.0f" % [before, _s.sim.lv.pure, _s.sim.light])
			"shop_x":
				_s._shop.find_child("Close", true, false).pressed.emit()
			"iron":
				print("a giant: swell %.2f, %d K, %s" % [_s.sim.swell, int(_s.sim.temp()), _s._nova_l.text])
				_s.sim.made[5] = Sim.IRON * Sim.START
				print("an iron core: the sim says %s, would pay %d" % [_s.sim.ending(), _s.sim.dust_for()])
			"perk":
				print("camera after the end: shift %s, view %.3f, sky ending %s, relics %d (kind of the last %d)" % [_s.sky.shift, _s.sky.view, _s.sky.ending(), _s.sim.relics.size(), int(_s.sim.relics[-1].kind) if not _s.sim.relics.is_empty() else -1])
				print("after the end: %.1f Suns, dust %d, novas %d, fades %d, %d puffs left, perks open %s" % [_s.sim.suns(), _s.sim.dust, _s.sim.novas, _s.sim.fades, _s.sim.bodies.size(), _s._perks.visible])
				var drawn: int = _s.sim.bought
				_s._perk_buy.pressed.emit()
				_check(_s.sim.bought == drawn + 1, "perk drawn: %s, dust %d" % [str(_s.sim.perk), _s.sim.dust])
			"perks_x":
				if _s._perks.visible:
					_s._perks.find_child("Back", true, false).pressed.emit()
			"where":
				# where the camera has the dead star and the new one, in the field's pixels
				var rel: Dictionary = _s.sim.relics[-1]
				var dead: Vector2 = _s.sky.world(rel.pos as Vector2)
				var star: Vector2 = _s.sky.world(Vector2.ZERO)
				var field := Rect2(Vector2.ZERO, _s.sky.size)
				print("camera at %.2f s: view %.3f, shift %s, the dead star at %s (in frame %s), the new star at %s (in frame %s), field %s" % [_s.sky.end_t(), _s.sky.view, _s.sky.shift, dead, field.has_point(dead), star, field.has_point(star), _s.sky.size])
			"nebula":
				# four Suns, helium lit, a carbon core of CARBON Suns it cannot light
				_s.sim.mass = Sim.START * 4.0
				_s.sim.ignited[1] = true
				_s.sim.made[1] = Sim.CARBON * Sim.START
				print("a nebula due: the sim says %s, remnant %d, %s" % [_s.sim.ending(), _s.sim.remnant(), _s.sim.goal()])
			"let_go_star":
				_s.sim.fuel = 0.0
				_s.sim.h_on = false
				_s.sim.awake = false
				_s.sim.cold = Sim.GRACE
				print("before the fade: shift %s, view %.3f, relics %d, kinds %s" % [_s.sky.shift, _s.sky.view, _s.sim.relics.size(), str(_s.sim.relics.map(func(r: Dictionary) -> int: return int(r.kind)))])
				print("left dim: the sim says %s" % _s.sim.ending())
			"system":
				_system()
			"half":
				_half()
			"line":
				_check_line(String(step[2]), int(step[3]))
			"card":
				# the Arcade card's line names the worlds the star was left with,
				# and the card is no wider for it than the screen has room for
				var kept: Dictionary = Sim.kept()
				var n := int(kept.worlds)
				var best: Label = _menu.arcade_tab._best["nightlight"]
				var words: String = tr("NL_CARD_WORLDS_ONE") if n == 1 else tr("NL_CARD_WORLDS_N") % n
				# the label, its line, the words, the head, the column, the card
				var card: Control = best.get_parent().get_parent().get_parent().get_parent().get_parent()
				var right: float = card.get_global_rect().end.x
				_check(n > 0 and best.text.contains(" · " + words) and right <= root.get_visible_rect().size.x,
					"the card names the star's worlds and its line fits: kept %s, the line \"%s\" %d px long, the card ends at %d of %d px" % [str(kept), best.text, int(best.size.x), int(right), int(root.get_visible_rect().size.x)])
			"tutor":
				_s.tutor.show()
			"page":
				_s.get_node("HowToPlay")._show_page(int(step[2]))
			"leave":
				_s.get_node("HowToPlay")._continue()
				print("leaving: %.2f Suns, the system %s, the line \"%s\"" % [_s.sim.suns(), str(_s.sim.system()), _s._system.text])
				_s.go_back()
			"quit":
				if _fresh:
					print("after the birth: sky ending %s, a birth %s, shift %s, view %.3f" % [_s.sky.ending(), _s._birth, _s.sky.shift, _s.sky.view])
				else:
					print("back on tab: %s, screen gone: %s, the card says %s" % [_menu._tab, _menu.get_node_or_null("Nightlight") == null or _menu.get_node("Nightlight").is_queued_for_deletion(), Sim.kept()])
				return _end()
	return false
