extends SceneTree

## Nightlight, shot at fixed beats through the real menu:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_nightlight.gd -- <outdir> [reduce] [en|pt|es] [fresh]
##
## 1 the Arcade tab with its card, 2 a new star in its ring, 3 a finger down
## on the ring's fullest part (a ScreenTouch, as a phone sends it) 0.2 s
## after it landed, its light still there, 3b the arc that finger then
## dragged along (a ScreenDrag a frame, braking as often as a held finger
## does) twenty seconds on, falling, 4 the ring a steady hand has braked for
## two minutes, with what the gas has made, 4b a planet the tide has torn,
## 4c a sky as full as it gets (the draw calls' worst), 5a the two powers
## offered at the next mark (the card comes up by itself), 5b one picked and
## on its disc, 5e the card opened on a held finger (the log says the card
## stayed down while the finger did, that the finger was dropped as it
## opened, that a press under it braked nothing and a pick in its first
## half second was not taken; then that after a lift it waits OFFER_CALM
## and comes up by itself), 5c the star with nothing to burn, dim, 6 a
## heavy star burning carbon, a giant, 6c three relics put by hand round
## it (a white dwarf, a neutron star, an old black hole, each with its
## nebula), 6b the powers it holds, 7 the shop
## with a tile just bought, 8a-8f the supernova (the core falling in, the
## layers leaving, the camera pulling back from the neutron star it leaves,
## panning to the new star, the new star condensing), 11 the perks, 12 one
## drawn, 13 the new star among the gas, 9a-9b a star of four Suns whose
## carbon core cannot light letting its layers go as a nebula (9c the camera
## between the white dwarf and the birthplace, 9b the new star after),
## 13b-13c a star letting go, 14-16 the tutorial's four pages (14 the GAS
## page 0.2 s after its second press, 14b the gas that press sent half way
## in, 16b the END page's camera), 17 the tab again with the star and its
## relics on its card.
## Every run but `fresh` opens a kept star (a first cloud saved before the
## screen opens, so nothing is born on screen); `fresh` deletes the file, so
## the screen opens on a first star condensing out of its cloud (0 the birth,
## 0b after it) and stops there.
## Prints the draw calls at each shot and the frames since the last with
## their mean and longest gap. The star and the wallet are throwaway files.
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
	[6.1, "run", 20.0, false], [7.0, "shot", "3b_falling"],
	[7.1, "run", 120.0, true], [9.0, "shot", "4_disc"],
	[9.1, "planet"], [12.0, "shot", "4b_torn"],
	[12.1, "crowd"], [13.0, "shot", "4c_full"],
	[13.1, "grow"], [14.6, "shot", "5a_pick"], [14.7, "pick", 0], [15.3, "shot", "5b_picked"],
	# the card and the finger: held down 1.5 s past a pick (PICK_WAIT and
	# OFFER_CALM are 1.2 together), the card opened on it, then a finger
	# lifted and the card left to come by itself, 1.2 s on, and picked from
	# once it has been up PICK_DEAF
	[15.4, "hold_grow"], [16.9, "card_held"], [17.1, "shot", "5e_card_drops_finger"], [17.6, "pick", 0],
	[17.7, "hold_grow"], [18.0, "let_go"], [18.4, "calm", false], [19.5, "calm", true], [20.0, "pick", 0],
	[20.1, "starve"], [22.7, "shot", "5c_dim"], [22.8, "feed"],
	[22.9, "heavy"], [23.0, "run", 40.0, true], [26.2, "shot", "6_giant"],
	[26.25, "relics"], [26.45, "shot", "6c_relics"],
	[26.55, "powers"], [26.9, "shot", "6b_powers"], [27.0, "powers_x"],
	[27.1, "shop"], [27.2, "buy"], [27.7, "shot", "7_shop"], [27.8, "shop_x"],
	# the supernova: swap at 31.5, the pull back to 32.7, the pan to 35.7,
	# the close to 39.7 and the perks (reduce motion: over at 35.5)
	[27.9, "iron"], [28.8, "shot", "8a_fall"], [29.6, "shot", "8b_leaving"], [30.5, "shot", "8c_shells"],
	[32.0, "shot", "8d_pull_back"], [32.01, "where"], [32.8, "where"], [33.7, "shot", "8e_pan"], [33.71, "where"], [36.7, "shot", "8f_rising"],
	[40.5, "shot", "11_perks"], [40.6, "perk"], [41.0, "shot", "12_perk"],
	[41.1, "perks_x"], [43.1, "shot", "13_new"],
	# the nebula: swap at 47.4, the pull back to 48.6, the pan to 51.6, the
	# close to 55.6 and the perks (reduce motion: over at 51.4)
	[43.2, "nebula"], [45.7, "shot", "9a_nebula_leaving"], [47.9, "where"], [48.7, "where"], [50.1, "shot", "9c_nebula_pan"], [50.11, "where"],
	[55.8, "perks_x"], [56.1, "shot", "9b_after_nebula"],
	# the fade: swap at 61.2, the pull back to 62.4, over at 69.4 (reduce
	# motion: 65.2)
	[56.2, "let_go_star"], [59.6, "shot", "13b_letting_go"], [61.7, "where"], [62.6, "shot", "13c_gone"], [62.61, "where"], [69.9, "perks_x"],
	# GAS presses 0.8 and 1.6 s into its page and its gas is half way in at 19
	[70.0, "tutor"], [71.8, "shot", "14_tut_gas"], [88.0, "shot", "14b_tut_gas_in"],
	[88.1, "page", 1], [90.1, "shot", "15_tut_worlds"],
	# BURN's star is a giant (swell 1, 20 Suns) from 12.0 to 13.8 s into the page
	[90.2, "page", 2], [96.2, "shot", "15b_tut_burn"], [103.3, "shot", "15c_tut_burn_giant"],
	[103.4, "page", 3], [106.5, "shot", "16_tut_end"], [111.0, "shot", "16b_tut_end_pan"],
	[111.1, "leave"], [112.3, "shot", "17_tab_after"],
	[112.4, "quit"],
]
## The beats' clock moves this much a frame at most, in seconds.
const MOST_STEP := 0.1
## `fresh`: no file, so the screen opens on a first star being born.
const FRESH_STEPS := [
	[1.6, "tab"], [2.8, "fresh"],
	[2.9, "open"], [4.4, "shot", "0_birth"], [7.4, "shot", "0b_born"],
	[7.5, "quit"],
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

func _process(delta: float) -> bool:
	_t += minf(delta, MOST_STEP)
	_frames += 1
	_gap_sum += delta
	_gap_max = maxf(_gap_max, delta)
	if _t > 140.0:
		_finish()
		return true
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
				# as full a sky as the sim lets there be
				while _s.sim.gas_count() < Sim.MOST:
					var pos: Vector2 = Vector2.from_angle(randf() * TAU) * _s.sim.haze_r() * randf_range(0.7, 0.97)
					var puff: Sim.Body = _s.sim.add(Sim.Kind.GAS, Sim.RING_M / Sim.RING, pos, _s.sim.circle_vel(pos) * randf_range(0.97, 1.0))
					puff.h = _s.sim.puff_h()
					puff.dust = _s.sim.dusty
				for k in 140:
					var far: float = _s.sim.haze_r() * (0.55 + 0.004 * k)
					var way := Vector2.from_angle(TAU * k * 0.381)
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
					print("the braked arc twenty seconds on: %d of %d left, %s from the star; the ring starts at %d, the disc at %d" % [rs.size(), _marked.size(), str(rs), int(_s.sim.ring.x), int(_s.sim.haze_r())])
			"grow":
				# past the next pick: the card comes up by itself
				_grow()
				print("grown to %.1f Suns: owed %d, fingers %s" % [_s.sim.suns(), _s.sim.owed(), str(_s._fingers.keys())])
			"hold_grow":
				# a finger down on the sky, and the star past a pick under it
				_grow()
				_spot_now = Vector2(_s.sim.ring.y * 0.8, 0.0)
				_touch(true, _spot_now)
				print("held and grown to %.1f Suns: owed %d, fingers %s, card up %s" % [_s.sim.suns(), _s.sim.owed(), str(_s._fingers.keys()), _s._pick.visible])
			"card_held":
				print("1.5 s on with the finger down: card up %s (the guard: false), fingers %s, owed %d" % [_s._pick.visible, str(_s._fingers.keys()), _s.sim.owed()])
				_s.open_pick()
				print("the card opened on it: card up %s, fingers empty %s" % [_s._pick.visible, _s._fingers.is_empty()])
				# gas right under a second finger, which a press would brake
				var under: Sim.Body = _s.sim.add(Sim.Kind.GAS, Sim.PUFF, _spot_now, _s.sim.circle_vel(_spot_now))
				var v0 := under.vel
				_s.sim.events.clear()
				_touch(true, _spot_now, 1)
				var brakes := 0
				for e: Dictionary in _s.sim.events:
					if String(e.kind) == "brake":
						brakes += 1
				print("a press under the card: %d brake events (0), the gas under it slowed %s (false), fingers empty %s" % [brakes, under.vel != v0, _s._fingers.is_empty()])
				_touch(false, _spot_now, 1)
				var picks: int = _s.sim.picks
				_s._on_pick(0)
				print("a pick in the card's first half second: taken %s (false), card up %s (true)" % [_s.sim.picks != picks, _s._pick.visible])
			"calm":
				print("%.1f s after the finger lifted: card up %s (%s), owed %d, fingers %s" % [(Time.get_ticks_msec() - int(_s._lifted_at)) / 1000.0, _s._pick.visible, str(bool(step[2])), _s.sim.owed(), str(_s._fingers.keys())])
			"pick":
				print("pick open: %s, on offer %s, owed %d" % [_s._pick.visible, str(_s.sim.offer), _s.sim.owed()])
				_s._on_pick(int(step[2]))
				print("picked: %s, card open %s" % [str(_s.sim.power), _s._pick.visible])
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
				_s._perk_buy.pressed.emit()
				print("perk drawn: %s, dust %d" % [str(_s.sim.perk), _s.sim.dust])
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
			"tutor":
				_s.tutor.show()
			"page":
				_s.get_node("HowToPlay")._show_page(int(step[2]))
			"leave":
				_s.get_node("HowToPlay")._continue()
				_s.go_back()
			"quit":
				if _fresh:
					print("after the birth: sky ending %s, a birth %s, shift %s, view %.3f" % [_s.sky.ending(), _s._birth, _s.sky.shift, _s.sky.view])
				else:
					print("back on tab: %s, screen gone: %s, the card says %s" % [_menu._tab, _menu.get_node_or_null("Nightlight") == null or _menu.get_node("Nightlight").is_queued_for_deletion(), Sim.kept()])
				_finish()
				return true
	return false
