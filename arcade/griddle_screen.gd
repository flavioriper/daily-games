extends Control

## Griddle: the twelfth game on the Arcade tab, a toastie stand of four
## places that run at once (spec
## docs/superpowers/specs/2026-10-12-arcade-griddle-design.md). **The place
## is the whole screen**, edge to edge (the rule since 2026-10-10). Over it
## lie the flat boards' top bar, a paper row with the coins held, the rush
## and the toasties to the next star, and at the foot the tray: the shop's
## button on the left, where the thumb that sells does not rest, then the
## four places, each with a dot when it wants looking at.
##
## **A kept game, like Furrow**: no run, no end card, no gold. The sim
## (arcade/griddle_sim.gd) is loaded when the screen opens, given the time
## away (the fields and the yard go on into the larder; nothing is sold)
## and saved on every purchase, every twenty seconds, when the app loses
## focus and when the screen is left.
##
## Play: every place works by itself, slowly, and a finger does the same at
## once (arcade/griddle_place.gd takes the touch): a ripe lot cut, a full
## cow's milk taken, a poorly cow tucked up, the front toastie sold to the
## front of the queue. Each place has a shortcut and somebody who minds it.
## Every touch that changes anything is heard and felt; the cart, the pail,
## the cook and the till are heard only on the counter, quietly, and never
## over a rush.
##
## The moments (arcade/rewards.gd over everything): a sale by hand's tick
## climbs a semitone a link to five and holds; the rush's sum is lettered
## as it grows; the 5th, 10th and 15th link are named with a rising phrase;
## a queue emptied by a rush is a clean counter with confetti; a rush
## ending sends its coins to the plate; a star is named with rays.

signal closed

const Sim = preload("res://arcade/griddle_sim.gd")
const Art = preload("res://arcade/griddle_art.gd")
const Place = preload("res://arcade/griddle_place.gd")
const Shop = preload("res://arcade/griddle_shop.gd")
const Card = preload("res://arcade/griddle_card.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const ScreenTutor = preload("res://ui/hud/screen_tutor.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Icons = preload("res://ui/icons.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Analytics = preload("res://core/analytics.gd")
const Rewards = preload("res://arcade/rewards.gd")
const Face = preload("res://ui/faces/face.gd")

const GAME := "griddle"
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
const TRAY_H := 190.0
const SAVE_EVERY := 20.0
## The cozy rules (docs/agents/sound.md): no cue climbs past five semitones.
const CLIMB := 5
const TICK_VARY := 0.03
## The phrase a named link plays, a step or two higher each.
const RUSH_PITCH := [1.0, 1.122, 1.26]
const RUSH_KEYS := ["GR_RUSH_0", "GR_RUSH_1", "GR_RUSH_2"]
## The crew's own work is heard this many seconds apart at the nearest.
const WORK_GAP := 0.35
const SLIDE := 0.16
## The phone knocks through `_feel`, once a frame with the strongest asked.
const HAPTICS := {}

var sim: RefCounted
var top_bar: Control
var settings_sheet: Control
var tutor: RefCounted
var world: Control
var tray: Control
var _fx: Node2D
var _rw: Rewards
var _margins: MarginContainer
var _coins_l: Label
var _rush_l: Label
var _star_l: Label
var _font: Font
var _clock := 0.0
var _knock := -1
var _saved_at := 0.0
var _opened_at := 0
var _shown_coins := -1
var _shown_rush := -1
var _shown_star := ""
var _bumped_at := -10.0
var _worked_at := -10.0
var _said_at := {}
var _chip_at := {}
var _slot_down := -1
var _slot_touch := -2
var _sliding := false
var _tray_live: ArrayMesh

func puzzle_id() -> String:
	return GAME

func _ready() -> void:
	add_to_group("versus_host")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	_font = theme.get_font("font", "SheetTitle")
	sim = Sim.load_saved()
	_build()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	tutor = ScreenTutor.new(self, puzzle_id(), "Griddle")
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	top_bar.refresh(self)
	_opened_at = Time.get_ticks_msec()
	_fx.cue("start")
	_welcome.call_deferred(sim.away_came, sim.away_secs)
	Analytics.track("griddle_enter", {"served": sim.served, "stars": sim.stars, "coins": sim.coins, "away": int(sim.away_secs)})

func _notification(what: int) -> void:
	if sim == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		sim.save()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# the phone slept with the screen up: the stand was shut all the same
		var gap: float = Time.get_unix_time_from_system() - sim.stamp
		if gap > 5.0:
			_welcome(sim.away(gap), gap)

## What the time away did, said once over the place.
func _welcome(came: int, secs: float) -> void:
	if secs < 60.0 or _rw == null or came <= 0:
		return
	_rw.sticker(tr("GR_BACK"), _rw.at(self, size * Vector2(0.5, 0.4)), 50, 2.8, false, Color("fff4c2"), true, "back")

# --- building ---

func _build() -> void:
	world = Place.new()
	world.name = "World"
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.sim = sim
	world.font = _font
	world.refused.connect(_on_refused)
	world.lot_asked.connect(_show_lot)
	world.touched.connect(func(pitch: float) -> void:
		_fx.touch(pitch)
		_feel(Haptics.TAP))
	world.landed.connect(func() -> void: _bump_coins(0.12))
	add_child(world)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	world.add_child(_fx)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margins.add_child(col)

	top_bar = FlatTopBar.new("Griddle", tr("GR_MOTTO"), false)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	col.add_child(top_bar)
	col.add_child(_build_hud())
	var open := Control.new()
	open.size_flags_vertical = Control.SIZE_EXPAND_FILL
	open.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(open)

	tray = Control.new()
	tray.name = "Tray"
	tray.custom_minimum_size.y = TRAY_H
	tray.mouse_filter = Control.MOUSE_FILTER_STOP
	tray.draw.connect(_draw_tray)
	tray.gui_input.connect(_on_tray_input)
	col.add_child(tray)

	_rw = Rewards.new()
	add_child(_rw)
	_apply_insets()

func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 16)
	var made := []
	for key in ["GR_COINS", "GR_RUSH", "GR_STAR"]:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plate.size_flags_stretch_ratio = 1.3 if key == "GR_COINS" else 1.0
		plate.add_theme_stylebox_override("panel", CozyTheme.lifted(Color("fcf7ef"), 30, 8))
		var words := VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_theme_constant_override("separation", -6)
		plate.add_child(words)
		var kicker := Label.new()
		kicker.text = key
		kicker.theme_type_variation = "MenuKicker"
		kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.add_child(kicker)
		var value: Control
		var label := Label.new()
		label.text = "0"
		label.theme_type_variation = "SheetTitle"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value = label
		if key == "GR_COINS":
			var line := HBoxContainer.new()
			line.alignment = BoxContainer.ALIGNMENT_CENTER
			line.add_theme_constant_override("separation", 8)
			line.add_child(Shop.coin_icon(40.0))
			line.add_child(label)
			value = line
		words.add_child(value)
		row.add_child(plate)
		made.append(label)
	_coins_l = made[0]
	_rush_l = made[1]
	_star_l = made[2]
	return row

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_lay_world()

## The place has the room between the plates and the tray.
func _lay_world() -> void:
	if world == null or size.x <= 0.0:
		return
	var insets := SafeArea.insets(self)
	var top := MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + GAP
	var foot := MARGIN + insets.y + TRAY_H + GAP
	world.area = Rect2(30.0, top, size.x - 60.0, maxf(60.0, size.y - top - foot))

# --- the top bar's questions ---

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/griddle_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.SERVE, "TUT_GRIDDLE_SERVE", tr("TUT_GRIDDLE_SERVE_BODY")],
		[Diagram.Lesson.RUSH, "TUT_GRIDDLE_RUSH", tr("TUT_GRIDDLE_RUSH_BODY") % [int(round(Sim.RUSH_STEP * 100.0)), Sim.CLEAN_MIN]],
		[Diagram.Lesson.FIELDS, "TUT_GRIDDLE_FIELDS", tr("TUT_GRIDDLE_FIELDS_BODY")],
		[Diagram.Lesson.YARD, "TUT_GRIDDLE_YARD", tr("TUT_GRIDDLE_YARD_BODY")],
		[Diagram.Lesson.OFFICE, "TUT_GRIDDLE_OFFICE", tr("TUT_GRIDDLE_OFFICE_BODY")],
		[Diagram.Lesson.ROUND, "TUT_GRIDDLE_ROUND", tr("TUT_GRIDDLE_ROUND_BODY")],
	]
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func capabilities() -> Array:
	return []

func is_done() -> bool:
	return false

func is_solved() -> bool:
	return false

func can_undo() -> bool:
	return false

func hints_left() -> int:
	return 0

# --- the frame ---

func _busy() -> bool:
	return get_node_or_null("Card") != null or get_node_or_null("Shop") != null

func _process(delta: float) -> void:
	if sim == null:
		return
	if world.area.size.x != size.x - 60.0:
		_lay_world()
	_clock += delta
	if tutor.is_open():
		# the guide is being read: the stand waits, so a first queue is not
		# found gone under it
		sim.stamp = Time.get_unix_time_from_system()
	else:
		sim.step(minf(delta, 2.0))
	_play_events()
	world.fly_to = world.get_global_transform().affine_inverse() * (_coins_l.get_global_transform() * (_coins_l.size * 0.5))
	world.tick(delta)
	_rw.bounds = Rect2(Vector2.ZERO, size)
	_rw.step(delta)
	_refresh_hud()
	if _knock >= 0:
		_fx.buzz(_knock)
		_knock = -1
	if _clock - _saved_at > SAVE_EVERY:
		_save()
	tray.queue_redraw()

func _save() -> void:
	_saved_at = _clock
	sim.save()

## Asks for a knock this frame; the strongest asked for is the one played.
func _feel(kind: int) -> void:
	_knock = maxi(_knock, kind)

func _refresh_hud() -> void:
	if sim.coins != _shown_coins:
		_shown_coins = sim.coins
		_coins_l.text = Locale.number(sim.coins)
	if sim.rush != _shown_rush:
		if sim.rush > _shown_rush and _shown_rush >= 0:
			_rush_l.pivot_offset = _rush_l.size * 0.5
			Motion.bump(_rush_l, 0.2 + 0.02 * mini(sim.rush, 10), 0.22)
		_shown_rush = sim.rush
		_rush_l.text = "×%d" % sim.rush if sim.rush > 0 else (tr("GR_RUSH_BEST") % sim.best_rush if sim.best_rush > 0 else "–")
	var star := "%s/%s" % [Locale.number(sim.served), Place.short(sim.next_star())]
	if star != _shown_star:
		_shown_star = star
		_star_l.text = star

# --- the sim's events ---

## Says a thing once in a while, not every time it happens.
func _once(id: String, every: float) -> bool:
	if _clock - float(_said_at.get(id, -1000.0)) < every:
		return false
	_said_at[id] = _clock
	return true

func _here(p: String) -> bool:
	return world.place == p

func _in_rw(p: Vector2) -> Vector2:
	return _rw.at(world, p)

func _plate_at(l: Control) -> Vector2:
	return _rw.at(l, l.size * 0.5)

## Where the rush's sum is lettered: over the queue.
func _tally_at() -> Vector2:
	return _in_rw(world.over("queue") + Vector2(0, -20.0))

func _top() -> Vector2:
	return _rw.at(self, size * Vector2(0.5, 0.4))

func _play_events() -> void:
	if sim.events.is_empty():
		return
	var evs: Array = sim.events.duplicate()
	sim.events.clear()
	for ev: Dictionary in evs:
		world.play(ev)
		match String(ev.type):
			"serve":
				_on_serve(ev)
			"rush":
				_on_rush(int(ev.n), int(ev.tier))
			"clean":
				_on_clean(int(ev.n), int(ev.bonus))
			"rush_end":
				_on_rush_end(int(ev.n), int(ev.sum))
			"no_serve":
				if _once("no_serve", 1.6):
					_rw.sticker(tr("GR_NO_PASS") if ev.why == "pass" else tr("GR_NO_QUEUE"), _in_rw(world.over("pass" if ev.why == "pass" else "queue")), 38, 1.2, false, Color("fffaf0"), false, "none", 20.0)
			"cook":
				_work("cook")
			"harvest":
				if bool(ev.hand):
					_fx.cue("cut", randf_range(0.96, 1.04))
					_feel(Haptics.TICK)
					_rw.sticker("+%d" % int(ev.n), _in_rw(world.over("lot", int(ev.i))), 40, 0.8, false, Color("fffaf0"), false, "", 40.0)
			"tired":
				if _once("tired", 20.0):
					_rw.sticker(tr("GR_TIRED"), _in_rw(world.over("lot", int(ev.i))) if _here("fields") else _top(), 40, 2.2, false, Color("ffe1d6"), false, "tired")
			"plant":
				_fx.cue("plant", randf_range(0.96, 1.04))
				_feel(Haptics.TAP)
			"milk":
				if bool(ev.hand):
					_fx.cue("milk", randf_range(0.96, 1.04))
					_feel(Haptics.BUMP)
					_rw.sticker("+1", _in_rw(world.over("cow", int(ev.k))), 40, 0.8, false, Color("fffaf0"), false, "", 40.0)
			"poorly":
				_fx.cue("warn", 1.06, -4.0)
				_feel(Haptics.WARN)
				if _here("yard"):
					_rw.sticker(tr("GR_POORLY"), _in_rw(world.over("cow", int(ev.k))), 40, 2.0, false, Color("ffe1d6"), false, "poorly", 20.0)
			"tuck":
				_fx.touch(0.9)
				_feel(Haptics.TAP)
				_rw.spray(_in_rw(world.over("cow", int(ev.k))), Color("f28aa4"), 3, 160.0, "heart", 0.9)
			"well":
				if _here("yard"):
					_rw.sticker(tr("GR_WELL"), _in_rw(world.over("cow", int(ev.k))), 38, 1.4, false, Color("fff4c2"), false, "well", 20.0)
			"toggle":
				_fx.cue("switch", 1.0 if bool(ev.on) else 0.9)
				_feel(Haptics.TAP)
			"tea":
				if bool(ev.on):
					_fx.cue("tea")
					_feel(Haptics.TAP)
					_rw.sticker(tr("GR_TEA"), _in_rw(world.over("kettle")), 40, 1.6, false, Color("fff4c2"), false, "tea", 20.0)
				elif _here("counter"):
					_rw.sticker(tr("GR_BACK_TO_WORK"), _in_rw(world.over("pass")), 38, 1.4, false, Color("fffaf0"), false, "tea", 20.0)
			"crew_back":
				_fx.cue("level", 0.9, -4.0)
				_rw.sticker(tr("GR_CREW_BACK"), _in_rw(world.over("pass")) if _here("counter") else _top(), 42, 1.8, false, Color("fff4c2"), false, "crew")
			"left":
				if _here("counter") and _once("left", 4.0):
					_rw.sticker(tr("GR_LEFT"), _in_rw(world.over("queue")), 36, 1.4, false, Color("ffe1d6"), false, "left", 20.0)
			"star":
				_on_star(int(ev.n))
			"warn":
				_on_warn(String(ev.m))
			"boil":
				_on_boil(String(ev.m), int(ev.bill))
			"favour":
				_on_favour(ev)
			"bought":
				_on_bought(ev)
			"up":
				_fx.cue("level", minf(pow(2.0, (int(ev.level) - 1) * 0.25 / 12.0), 1.335))
				_feel(Haptics.GOOD)
				Analytics.track("griddle_upgrade", {"tile": ev.id, "level": int(ev.level), "coins": int(ev.paid)})
				_save()
			"day":
				if int(ev.took) > 0:
					_rw.sticker(tr("GR_DAY") % Locale.number(int(ev.took)), _top() + Vector2(0, -120.0), 38, 2.4, false, Color("fffaf0"), false, "day")

## The cook's and the till's own work: heard on the counter only, quietly,
## not too often and never over a rush.
func _work(cue_name: String) -> void:
	if not _here("counter") or sim.rush > 0 or _busy() or _clock - _worked_at < WORK_GAP:
		return
	_worked_at = _clock
	_fx.cue(cue_name, randf_range(0.94, 1.06), -3.0)

## A link of the rush's tick: a semitone higher a link, to five and no
## further.
func _tick_pitch(n: int) -> float:
	return pow(2.0, mini(n - 1, CLIMB) / 12.0) * randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY)

func _on_serve(ev: Dictionary) -> void:
	if not bool(ev.hand):
		_work("till")
		return
	var n := int(ev.n)
	_fx.cue("serve", _tick_pitch(n))
	_feel(Haptics.TICK)
	if n >= 2:
		_rw.sticker("+" + Locale.number(sim.rush_sum), _tally_at(), mini(50 + n * 2, 84), Sim.WINDOW + 0.5, false, Color("fff4c2"), false, "tally", 0.0, true)
	else:
		_rw.sticker("+" + Locale.number(int(ev.pay)), _in_rw(world.queue_at(0) - Vector2(0, 150.0)), 40, 0.8, false, Color("fffaf0"), false, "one", 40.0)

func _on_rush(n: int, tier: int) -> void:
	_fx.cue("rush", RUSH_PITCH[tier])
	_feel(Haptics.GOOD)
	var at := _tally_at() + Vector2(0, 96.0)
	_rw.sticker(tr(RUSH_KEYS[tier]) + " ×%d" % n, at, 56 + tier * 6, 1.3, tier >= 1, Color("fffaf0"), tier >= 1, "rush")
	_rw.spray(at, Pal.SUN, 6 + tier * 4, 520.0, "star", 0.9 + 0.1 * tier)
	_rw.ring(at, 150.0 + 40.0 * tier, Color(Pal.SUN, 0.9))

func _on_clean(n: int, bonus: int) -> void:
	_fx.cue("clean")
	_feel(Haptics.WIN)
	var at := _rw.at(self, size * Vector2(0.5, 0.42))
	_rw.sticker(tr("GR_CLEAN"), at, 78, 2.0, true, Color.WHITE, true, "clean", 0.0, true)
	_rw.sticker("+" + Locale.number(bonus), at + Vector2(0, 96.0), 58, 2.0, false, Color("fff4c2"), false, "clean_bonus", 0.0, true)
	_rw.rain(1.6, ["confetti", "star"], Rewards.CONFETTI)
	_rw.spray(at, Pal.SUN, 16, 720.0, "coin", 1.1, 0.1, _plate_at(_coins_l))
	Analytics.track("griddle_clean", {"n": n, "coins": sim.rush_sum})

## A rush over: its sum goes to the plate. A link or two is no rush and
## says nothing more.
func _on_rush_end(n: int, sum: int) -> void:
	if n < 3:
		return
	_fx.cue("tally")
	_feel(Haptics.BUMP)
	var from := _tally_at() if _here("counter") else _top()
	_rw.stickers = _rw.stickers.filter(func(st: Dictionary) -> bool: return String(st.id) != "tally")
	_rw.sticker("+" + Locale.number(sum), from, 64, 0.9, false, Color("fff4c2"), false, "tally_end", -60.0, true)
	_rw.spray(from, Art.COIN, mini(4 + n, 16), 420.0, "coin", 1.0, 0.0, _plate_at(_coins_l))
	_bump_coins(0.3)
	if n >= 5:
		Analytics.track("griddle_rush", {"n": n, "coins": sum})
	_save()

func _on_star(n: int) -> void:
	_fx.cue("star")
	_feel(Haptics.WIN)
	var at := _top()
	_rw.sticker(tr("GR_STAR_ONE") if n == 1 else tr("GR_STAR_N") % n, at, 70, 2.4, true, Color.WHITE, true, "star")
	_rw.sticker(tr("GR_STAR_LINE") % [int(round(Sim.STAR_PRICE * 100.0)), int(round(Sim.STAR_PULL * 100.0))], at + Vector2(0, 90.0), 38, 2.4, false, Color("fff4c2"), false, "star_line", 0.0, true)
	_rw.spray(at, Pal.SUN, 16, 660.0, "star", 1.1, 0.1, _plate_at(_star_l))
	_rw.rain(1.6, ["confetti", "star"], Rewards.CONFETTI)
	_star_l.pivot_offset = _star_l.size * 0.5
	Motion.bump(_star_l, 0.3, 0.3)
	Analytics.track("griddle_star", {"n": n})
	_save()

func _on_warn(m: String) -> void:
	_fx.cue("warn")
	_feel(Haptics.WARN)
	_rw.sticker(tr("GR_WARN_" + m.to_upper()), _top() + Vector2(0, -60.0), 42, 3.0, false, Color("ffe1d6"), false, "warn")
	_chip_at[4] = _clock

func _on_boil(m: String, bill: int) -> void:
	_fx.cue("boil")
	_feel(Haptics.BAD)
	var at := _top()
	_rw.sticker(tr("GR_BOIL_" + m.to_upper()), at, 48, 3.6, false, Color("ffe1d6"), true, "boil", 0.0, true)
	if bill > 0:
		_rw.sticker("−" + Locale.number(bill), at + Vector2(0, 80.0), 52, 3.0, false, Color("ffd0c2"), false, "bill", 0.0, true)
	Analytics.track("griddle_boil", {"mood": m, "coins": bill})
	_save()

func _on_favour(ev: Dictionary) -> void:
	_fx.cue("favour")
	_feel(Haptics.GOOD)
	var k := Sim.MOODS.find(String(ev.m))
	var at := _in_rw(world.jar_at(k)) if _here("office") else _top()
	_rw.spray(at, Color("f28aa4"), 6, 260.0, "heart", 1.0)
	_rw.ring(at, 150.0, Color(Art.CREAM, 0.9))
	_rw.sticker(tr("GR_FAVOUR_DONE"), at - Vector2(0, 110.0), 42, 1.6, false, Color("fff4c2"), false, "favour")
	Analytics.track("griddle_favour", {"mood": ev.m, "coins": int(ev.paid)})
	_save()

## A lot, a cow, a stall, a grill, a till.
func _on_bought(ev: Dictionary) -> void:
	var what := String(ev.what)
	var big := what in ["grill", "till"]
	_fx.cue("buy", 1.0 if not big else 1.12)
	_feel(Haptics.WIN if big else Haptics.GOOD)
	var at := _top()
	if _busy():
		pass
	elif what == "lot" and _here("fields"):
		at = _in_rw(world.lot_mid(int(ev.i)))
	elif what == "cow" and _here("yard"):
		at = _in_rw(world.cow_foot(int(ev.i)) - Vector2(0, 70.0))
	elif what == "stall" and _here("yard"):
		at = _in_rw(world.stall_sign() - Vector2(0, 70.0))
	elif what == "grill" and _here("counter"):
		at = _in_rw(world.grill_at(int(ev.i)))
	elif what == "till" and _here("counter"):
		at = _in_rw(world.till_at(int(ev.i)))
	_rw.sticker(tr("GR_NEW_" + what.to_upper()), at - Vector2(0, 110.0), 50 if big else 44, 1.6, big, Color("fffaf0"), true, "bought")
	_rw.spray(at, Pal.SUN, 10 if big else 6, 460.0, "star", 0.9)
	_rw.ring(at, 170.0, Color(Art.CREAM, 0.9))
	Analytics.track("griddle_buy", {"tile": what, "coins": int(ev.paid)})
	_save()

func _bump_coins(amount: float) -> void:
	if _clock - _bumped_at < 0.12:
		return
	_bumped_at = _clock
	_coins_l.pivot_offset = _coins_l.size * 0.5
	Motion.bump(_coins_l, amount, 0.22)

## A touch the place could not do.
func _on_refused(why: String, at: Vector2, n: int) -> void:
	var p := _in_rw(at)
	match why:
		"short":
			_refuse()
			_rw.sticker(tr("GR_SHORT") % Locale.number(n), p, 40, 1.2, false, Color("fffaf0"), false, "short", 20.0)
		"full":
			_refuse()
			_rw.sticker(tr("GR_FULL"), p, 40, 1.4, false, Color("fffaf0"), false, "full", 20.0)
		"hush":
			_refuse()
			_rw.sticker(tr("GR_HUSHED") % n, p, 38, 1.6, false, Color("fffaf0"), false, "hush", 20.0)
		"wait":
			# not yet: its time left, and no sound
			_rw.sticker("%d s" % n, p, 40, 1.0, false, Color("fffaf0"), false, "wait", 20.0)

func _refuse() -> void:
	_fx.cue("nope")
	_feel(Haptics.WARN)

# --- a lot's card ---

func _show_lot(i: int) -> void:
	if _busy():
		return
	_fx.touch()
	_feel(Haptics.TAP)
	var card := Card.new()
	card.name = "Card"
	card.sim = sim
	card.lot = i
	card.closed.connect(func() -> void:
		_fx.touch(0.94)
		_fx.buzz(Haptics.TAP))
	card.chose.connect(func(id: String) -> void:
		match id:
			"wheat":
				sim.plant(i, Sim.WHEAT)
			"clover":
				sim.plant(i, Sim.CLOVER)
			"rest":
				sim.plant(i, Sim.FALLOW)
			"tonic":
				sim.set_tonic(i, not sim.lots[i].tonic)
		_save())
	add_child(card)
	move_child(_rw, get_child_count() - 1)

# --- the tray ---

func _slots() -> int:
	return Sim.PLACES.size() + 1

func _slot_mid(slot: int) -> Vector2:
	return Vector2(tray.size.x * (slot + 0.5) / _slots(), 78.0)

## The tray under a finger: a slot is pressed as the finger leaves it.
func _on_tray_input(event: InputEvent) -> void:
	var at := Vector2(-1, -1)
	var down := false
	var id := -2
	if event is InputEventScreenTouch:
		at = (event as InputEventScreenTouch).position
		down = (event as InputEventScreenTouch).pressed
		id = (event as InputEventScreenTouch).index
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		at = (event as InputEventMouseButton).position
		down = (event as InputEventMouseButton).pressed
		id = -1
	else:
		return
	var slot := clampi(int(at.x / (tray.size.x / _slots())), 0, _slots() - 1)
	if down:
		if _slot_down < 0:
			_slot_down = slot
			_slot_touch = id
	elif id == _slot_touch and _slot_down >= 0:
		var was := _slot_down
		_slot_down = -1
		if was == slot:
			press_slot(slot)

## A press on the tray's slot: 0 the shop, then the four places.
func press_slot(slot: int) -> void:
	_chip_at[slot] = _clock
	if slot == 0:
		_open_shop()
		return
	go(Sim.PLACES[slot - 1])

## Shows place `p`: the land slides off one way and the next comes in from
## the other.
func go(p: String, at_once := false) -> void:
	if p == world.place or _sliding:
		return
	var dir := signf(Sim.PLACES.find(p) - Sim.PLACES.find(world.place))
	_fx.touch(1.0 + 0.04 * Sim.PLACES.find(p))
	_feel(Haptics.TAP)
	if Motion.reduce or at_once:
		world.show_place(p)
		return
	_sliding = true
	var tw := create_tween()
	tw.tween_property(world, "position:x", -size.x * dir, SLIDE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		world.show_place(p)
		world.position.x = size.x * dir)
	tw.tween_property(world, "position:x", 0.0, SLIDE + 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _sliding = false)

func _draw_tray() -> void:
	if tray.size.x <= 0.0:
		return
	tray.draw_style_box(CozyTheme.lifted(Color("fcf7ef"), 36, 8), Rect2(Vector2.ZERO, tray.size))
	var still := Motion.reduce
	var fs := 24
	var b := Face.Builder.new()
	# the shop
	var mid := _slot_mid(0)
	var press := 1.0 if still else Motion.bump_scale(_clock - float(_chip_at.get(0, -10.0)), 0.16, 0.22)
	b.disc(mid + Vector2(0, 5.0), 42.0 * press, Color(Pal.TEXT, 0.16))
	b.disc(mid, 42.0 * press, Art.TEAL_DEEP)
	var can_up := false
	for id: String in Sim.UPS:
		if sim.coins >= sim.up_price(id):
			can_up = true
	if can_up:
		b.disc(mid + Vector2(32, -32), 13.0, Color("fffaf0"))
		b.disc(mid + Vector2(32, -32), 9.0 + (0.0 if still else 1.5 * sin(_clock * 4.0)), Pal.SUN)
	for k in Sim.PLACES.size():
		var p: String = Sim.PLACES[k]
		var at := _slot_mid(k + 1)
		var on: bool = world.place == p
		var sc := 1.0 if still else Motion.bump_scale(_clock - float(_chip_at.get(k + 1, -10.0)), 0.16, 0.22)
		if on:
			b.disc(at + Vector2(0, -4.0), 54.0 * sc, Pal.SUN)
			at.y -= 4.0
		b.disc(at + Vector2(0, 5.0), 44.0 * sc, Color(Pal.TEXT, 0.16))
		b.disc(at, 44.0 * sc, Art.PLACE_TINT[p] if on else Art.PLACE_TINT[p].lerp(Color("fcf7ef"), 0.45))
		var alarm: int = sim.alarm(p)
		if alarm > 0 and not on:
			var beat := 0.0 if still else (2.0 * absf(sin(_clock * (6.0 if alarm == 2 else 3.0))))
			b.disc(at + Vector2(34, -34), 15.0 + beat, Color("fffaf0"))
			b.disc(at + Vector2(34, -34), 10.0 + beat, Art.RED if alarm == 2 else Art.AMBER)
	_tray_live = b.mesh()
	tray.draw_mesh(_tray_live, null)
	Icons.paint(tray, "trend", Rect2(mid - Vector2(24, 24) * press, Vector2(48, 48) * press), Pal.SURFACE)
	_caption(tr("GR_SHOP_SHORT"), mid, fs, Art.INK)
	for k in Sim.PLACES.size():
		var p: String = Sim.PLACES[k]
		var at := _slot_mid(k + 1)
		if world.place == p:
			at.y -= 4.0
		tray.draw_mesh(Art.place_icon(p, 56.0), null, Transform2D(0.0, at))
		_caption(tr("GR_PLACE_" + p.to_upper()), _slot_mid(k + 1), fs, Art.INK if world.place == p else Color(Art.INK, 0.7))

func _caption(text: String, mid: Vector2, fs: int, col: Color) -> void:
	var w := tray.size.x / _slots()
	tray.draw_string(_font, Vector2(mid.x - w * 0.5, mid.y + 44.0 + fs + 8.0), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)

# --- the shop ---

func _open_shop() -> void:
	if _busy():
		return
	_fx.touch()
	_feel(Haptics.TAP)
	var shop := Shop.new()
	shop.name = "Shop"
	shop.sim = sim
	shop.page = world.place
	shop.closed.connect(func() -> void:
		_fx.touch(0.94)
		_fx.buzz(Haptics.TAP))
	add_child(shop)
	move_child(_rw, get_child_count() - 1)

# --- chrome ---

func _on_back() -> void:
	sim.save()
	Analytics.track("griddle_leave", {"seconds": int((Time.get_ticks_msec() - _opened_at) / 1000.0), "served": sim.served, "stars": sim.stars, "coins": sim.coins})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if tutor.close():
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	for nm in ["Shop", "Card"]:
		var sheet := get_node_or_null(nm)
		if sheet != null and not sheet.is_queued_for_deletion():
			sheet.closed.emit()
			sheet.queue_free()
			return
	_on_back()
