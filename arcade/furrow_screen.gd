extends Control

## Furrow: the eleventh game on the Arcade tab, a small field that grows
## while you are away (spec
## docs/superpowers/specs/2026-10-11-arcade-furrow-design.md). **The field
## is the whole screen**, edge to edge (the user, 2026-10-10: "the screen
## should fit everything, just like the factory does, it's gonna be a
## pattern from now on"). Over it lie the flat boards' top bar, a paper row
## with the seeds held, the chain and how much of the field is ripe, and at
## the foot the tray: the shed's button on the left, where the thumb that
## picks does not rest, and the packets of the crops held.
##
## **A kept game, like Nightlight**: no run, no end card, no gold. The sim
## (arcade/furrow_sim.gd) is loaded when the screen opens, grown by the
## time away, and saved on every purchase, every twenty seconds, when the
## app loses focus and when the screen is left. Crops ripen on the wall
## clock, keep for a while and then wither; nothing is picked while away.
##
## Play: a finger drawn over ripe plants picks them (arcade/furrow_field.gd
## takes the touch), each within the chain's window of the last a link that
## pays more, and a picked lot is bare. A packet tapped is taken in hand
## and stays there: the same finger picks what is ripe and sows what is
## bare; tapped again it is put back. The next plot's signboard, the next
## packet and the two pens are bought where they stand. In the coop the
## finger gathers the eggs off the ground, in the pasture it milks a cow
## that shows her bottle, and a fox at the fence is sent off by a touch.
## Every touch that changes anything is heard and felt; a touch on a plant
## still growing letters its time left and is silent.
##
## **A thing's card** (arcade/furrow_card.gd): the first touch on a crop, a
## hen or a cow shows what it sells for and how long it takes, and a finger
## held on it, or on a packet, shows it again.
##
## The moments (arcade/rewards.gd over everything): a pick's tick climbs a
## semitone a link to five and holds; the chain's sum is lettered as it
## grows; the 5th, 10th, 15th and 20th link are named with a rising phrase;
## the whole field in one chain is a clean sweep with confetti; a chain
## ending sends its stars to the seeds' plate.

signal closed

const Sim = preload("res://arcade/furrow_sim.gd")
const Art = preload("res://arcade/furrow_art.gd")
const Field = preload("res://arcade/furrow_field.gd")
const Shop = preload("res://arcade/furrow_shop.gd")
const Card = preload("res://arcade/furrow_card.gd")
const Animals = preload("res://arcade/furrow_animals.gd")
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

const GAME := "furrow"
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
const TRAY_H := 190.0
## The room kept between the plates and the yard behind the lots.
const FENCE := 16.0
const PACKET := 86.0
const TINT := Color("6fae4a")
const SAVE_EVERY := 20.0
## The cozy rules (docs/agents/sound.md): no cue climbs past five semitones.
const CLIMB := 5
const TICK_VARY := 0.02
## The phrase a bunch plays, a step or two higher each: 0, 2, 4 and 5
## semitones.
const BUNCH_PITCH := [1.0, 1.122, 1.26, 1.335]
const BUNCH_KEYS := ["FW_BUNCH_0", "FW_BUNCH_1", "FW_BUNCH_2", "FW_BUNCH_3"]
## The phone knocks through `_feel`, once a frame with the strongest asked.
const HAPTICS := {}

var sim: RefCounted
var top_bar: Control
var settings_sheet: Control
var tutor: RefCounted
var field: Control
var tray: Control
var _fx: Node2D
var _rw: Rewards
var _margins: MarginContainer
var _seeds_l: Label
var _chain_l: Label
var _ripe_l: Label
## The tray's slot under a finger and when it went down, for a press (the
## slot on its release) and a hold (the packet's card); -1 with none.
var _slot_down := -1
var _slot_at := 0.0
var _slot_touch := -2
## Whether a ripe lot's last quarter has been said, until none is in it.
var _turn_said := false
var _font: Font
var _clock := 0.0
var _knock := -1
var _saved_at := 0.0
var _opened_at := 0
var _shown_seeds := -1
var _shown_chain := -1
var _bumped_at := -10.0
var _all_said := false
var _all_at := -100.0
## When a packet or the shed's button was last pressed, for its bump, and
## when one was refused, for its shiver.
var _chip_at := {}
var _chip_no := {}
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
	tutor = ScreenTutor.new(self, puzzle_id(), "Furrow")
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	top_bar.refresh(self)
	_opened_at = Time.get_ticks_msec()
	_fx.cue("start")
	_welcome.call_deferred(sim.away_ripe, sim.away_secs)
	_hint_bare.call_deferred()
	Analytics.track("furrow_enter", {"plots": sim.opened(), "crops": sim.crops, "seeds": sim.seeds, "away": int(sim.away_secs), "ripe": sim.ripe_count()})

func _notification(what: int) -> void:
	if sim == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		sim.save()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# the phone slept with the screen up: the field grew all the same
		var gap: float = Time.get_unix_time_from_system() - sim.stamp
		if gap > 5.0:
			_welcome(sim.away(gap), gap)

## What the time away did, said once over the field: what is ripe, and
## under it what was lost.
func _welcome(ripened: int, secs: float) -> void:
	if secs < 60.0 or _rw == null:
		return
	var at := _rw.at(self, size * Vector2(0.5, 0.4))
	if ripened > 0:
		var text := tr("FW_BACK_ONE") if ripened == 1 else tr("FW_BACK_N") % ripened
		_rw.sticker(text, at, 56, 2.8, false, Color("fff4c2"), true, "back")
	var lost: Array = []
	if sim.away_dead > 0:
		lost.append(tr("FW_BACK_DEAD_ONE") if sim.away_dead == 1 else tr("FW_BACK_DEAD_N") % sim.away_dead)
	if sim.away_lost > 0:
		lost.append(tr("FW_BACK_FOX_ONE") if sim.away_lost == 1 else tr("FW_BACK_FOX_N") % sim.away_lost)
	for k in lost.size():
		_rw.sticker(lost[k], at + Vector2(0, 76.0 + 56.0 * k), 40, 3.4, false, Color("fffaf0"), false, "back_lost%d" % k, 0.0, true)

## A field with bare earth and no packet in hand says what to do, once as
## the screen opens.
func _hint_bare() -> void:
	if _rw != null and sim.bare_count() > 0 and field.armed < 0 and sim.ripe_count() == 0:
		_rw.sticker(tr("FW_PICK_PACKET"), _rw.at(tray, Vector2(tray.size.x * 0.5, -60.0)), 42, 3.0, false, Color("fffaf0"), false, "packet")

# --- building ---

func _build() -> void:
	field = Field.new()
	field.name = "Field"
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.asked_plot.connect(_buy_plot)
	field.waited.connect(_on_waited)
	field.landed.connect(_on_landed)
	field.bare.connect(_on_bare)
	field.asked_pen.connect(_buy_pen)
	field.opened_pen.connect(func(kind: String) -> void: _open_shop("coop" if kind == "coop" else "cow"))
	field.petted.connect(_on_petted)
	field.cow_waited.connect(_on_cow_waited)
	field.about.connect(_about)
	add_child(field)
	field.lay(sim)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	field.add_child(_fx)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margins.add_child(col)

	top_bar = FlatTopBar.new("Furrow", tr("FW_MOTTO"), false)
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
	for key in ["FW_SEEDS", "FW_CHAIN", "FW_RIPE"]:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plate.size_flags_stretch_ratio = 1.3 if key == "FW_SEEDS" else 1.0
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
		if key == "FW_SEEDS":
			var line := HBoxContainer.new()
			line.alignment = BoxContainer.ALIGNMENT_CENTER
			line.add_theme_constant_override("separation", 8)
			line.add_child(Shop.seed_icon(40.0))
			line.add_child(label)
			value = line
		words.add_child(value)
		row.add_child(plate)
		made.append(label)
	_seeds_l = made[0]
	_chain_l = made[1]
	_ripe_l = made[2]
	return row

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_lay_field()

## The land lies between the plates and the tray.
func _lay_field() -> void:
	if field == null or size.x <= 0.0:
		return
	var insets := SafeArea.insets(self)
	var top := MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + GAP + FENCE
	var foot := MARGIN + insets.y + TRAY_H + GAP
	field.area = Rect2(30.0, top, size.x - 60.0, maxf(60.0, size.y - top - foot))
	field.layout()

# --- the top bar's questions ---

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/furrow_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.PICK, "TUT_FURROW_PICK", tr("TUT_FURROW_PICK_BODY")],
		[Diagram.Lesson.CHAIN, "TUT_FURROW_CHAIN", tr("TUT_FURROW_CHAIN_BODY") % [int(round(Sim.CHAIN_STEP * 100.0)), Sim.MIN_SWEEP]],
		[Diagram.Lesson.AWAY, "TUT_FURROW_AWAY", tr("TUT_FURROW_AWAY_BODY")],
		[Diagram.Lesson.SOW, "TUT_FURROW_SOW", tr("TUT_FURROW_SOW_BODY")],
		[Diagram.Lesson.BUY, "TUT_FURROW_BUY", tr("TUT_FURROW_BUY_BODY")],
		[Diagram.Lesson.PENS, "TUT_FURROW_PENS", tr("TUT_FURROW_PENS_BODY") % Sim.NEST],
		[Diagram.Lesson.HUD, "TUT_FURROW_HUD", tr("TUT_FURROW_HUD_BODY")],
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

func _process(delta: float) -> void:
	if sim == null:
		return
	if field.area.size.x != size.x - 60.0:
		_lay_field()
	_clock += delta
	if tutor.is_open():
		# the guide is being read: the field waits, so a first field is not
		# found withered under it
		sim.stamp = Time.get_unix_time_from_system()
	else:
		# a fox does not reach the hens behind a card or the shed
		if sim.fox > 0.0 and (get_node_or_null("Card") != null or get_node_or_null("Shop") != null or settings_sheet.is_open()):
			sim.fox += delta
		# a stall is still time gone by: the field grows by all of it
		sim.step(delta)
	_play_events()
	field.fly_to = field.get_global_transform().affine_inverse() * (_seeds_l.get_global_transform() * (_seeds_l.size * 0.5))
	field.tick(delta)
	# a finger resting on a packet asks for its card
	if _slot_down > 0 and _clock - _slot_at >= Field.HOLD:
		var held := _slot_down - 1
		_slot_down = -1
		_slot_touch = -2
		if held < sim.crops:
			_show_crop(held, -1)
	_rw.bounds = Rect2(Vector2.ZERO, size)
	_rw.step(delta)
	_refresh_hud()
	_all_ripe()
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
	if sim.seeds != _shown_seeds:
		_shown_seeds = sim.seeds
		_seeds_l.text = Locale.number(sim.seeds)
	if sim.chain != _shown_chain:
		if sim.chain > _shown_chain and _shown_chain >= 0:
			_chain_l.pivot_offset = _chain_l.size * 0.5
			Motion.bump(_chain_l, 0.2 + 0.02 * mini(sim.chain, 10), 0.22)
		_shown_chain = sim.chain
		_chain_l.text = str(sim.chain) if sim.chain > 0 else (tr("FW_CHAIN_BEST") % sim.best_chain if sim.best_chain > 0 else "–")
	var ripe := "%d/%d" % [sim.ripe_count(), sim.opened()]
	if _ripe_l.text != ripe:
		_ripe_l.text = ripe

## The whole field ripe and no hand on it: said once, for the stroke that
## pays most.
func _all_ripe() -> void:
	_turning()
	var all: bool = sim.opened() >= Sim.MIN_SWEEP and sim.ripe_count() == sim.opened()
	if not all:
		_all_said = false
		return
	if _all_said or sim.chain > 0 or _clock - _all_at < 30.0:
		return
	_all_said = true
	_all_at = _clock
	_rw.sticker(tr("FW_ALL_RIPE"), _tally_at() + Vector2(0, 70.0), 46, 2.2, false, Color("fffaf0"), false, "ready")

## A ripe lot down to its last quarter, with nobody picking: said once
## until none is, so a crop is not lost unseen.
func _turning() -> void:
	var low := false
	for i in sim.plots.size():
		if sim.plots[i].open and sim.plots[i].ripe and not sim.plots[i].dead and sim.fresh(i) < 0.25:
			low = true
	if not low:
		_turn_said = false
	elif not _turn_said and sim.chain == 0:
		_turn_said = true
		_rw.sticker(tr("FW_TURNING"), _tally_at() + Vector2(0, 70.0), 42, 2.4, false, Color("ffe1d6"), false, "turning")

# --- the sim's events ---

func _play_events() -> void:
	if sim.events.is_empty():
		return
	var evs: Array = sim.events.duplicate()
	sim.events.clear()
	for ev: Dictionary in evs:
		field.play(ev)
		match String(ev.type):
			"pick":
				_on_pick(ev)
			"bunch":
				_on_bunch(int(ev.n), int(ev.tier))
			"sweep":
				_on_sweep(int(ev.n), int(ev.bonus))
			"chain_end":
				_on_chain_end(int(ev.n), int(ev.sum))
			"ripe":
				if bool(ev.gold):
					_fx.cue("gold", 1.0, -6.0)
					_rw.spray(_in_rw(field.over(int(ev.i))), Art.GOLD, 6, 260.0, "star", 0.7)
			"sow":
				_fx.cue("sow", randf_range(0.96, 1.04))
				_feel(Haptics.TICK)
			"clear", "dig":
				_fx.cue("clear", randf_range(0.96, 1.04))
				_feel(Haptics.TICK)
			"dead":
				_rw.sticker(tr("FW_WILTED"), _in_rw(field.over(int(ev.i))), 36, 1.6, false, Color("e8dcc0"), false, "dead%d" % int(ev.i), 20.0)
			"gather":
				_on_gather(ev)
			"milk":
				_on_milk(ev)
			"chick":
				_fx.cue("chick")
				_feel(Haptics.GOOD)
				_rw.sticker(tr("FW_CHICK"), _in_rw(field.pen_over("coop")), 46, 1.8, false, Color("fff4c2"), true, "chick")
			"grown":
				_fx.cue("chick", 0.84)
				_rw.sticker(tr("FW_GROWN"), _in_rw(field.pen_over("coop")), 42, 1.6, false, Color("fffaf0"), false, "grown")
			"fox":
				_fx.cue("fox")
				_feel(Haptics.WARN)
				_rw.sticker(tr("FW_FOX"), _in_rw(field.pen_over("coop")), 54, Sim.FOX_TIME, false, Color("ffe1d6"), true, "fox", 0.0, true)
			"shoo":
				_fx.cue("shoo")
				_feel(Haptics.GOOD)
				_drop_sticker("fox")
				_rw.sticker(tr("FW_SHOO"), _in_rw(field.pen_over("coop")), 48, 1.4, false, Color("fff4c2"), false, "shoo")
				Analytics.track("furrow_fox", {"took": 0, "hens": sim.hens})
			"took":
				_fx.cue("nope", 0.9)
				_feel(Haptics.WARN)
				_drop_sticker("fox")
				_rw.sticker(tr("FW_TOOK"), _in_rw(field.pen_over("coop")), 46, 2.4, false, Color("ffe1d6"), false, "took")
				Analytics.track("furrow_fox", {"took": 1, "hens": sim.hens})
				_save()
			"fence_down":
				_fx.cue("nope", 0.8, -4.0)
				_rw.sticker(tr("FW_FENCE_FELL"), _in_rw(field.pen_over("coop")), 44, 2.6, false, Color("ffe1d6"), false, "fence")
			"mile":
				_on_mile(ev)
			"bought":
				_on_bought(ev)
			"plot":
				_on_plot(ev)
			"crop":
				_on_crop(ev)
			"up":
				_fx.cue("level", minf(pow(2.0, (int(ev.level) - 1) * 0.25 / 12.0), 1.335))
				_feel(Haptics.GOOD)
				Analytics.track("furrow_upgrade", {"tile": ev.id, "level": int(ev.level), "seeds": int(ev.paid)})
				_save()

func _drop_sticker(id: String) -> void:
	_rw.stickers = _rw.stickers.filter(func(st: Dictionary) -> bool: return String(st.id) != id)

## A link of the chain's tick: a semitone higher a link, to five and no
## further.
func _tick_pitch(n: int) -> float:
	return pow(2.0, mini(n - 1, CLIMB) / 12.0) * randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY)

## The chain's sum lettered over the field as it grows, or one link's pay
## where it was picked.
func _tally(n: int, pay: int, at: Vector2) -> void:
	if n >= 2:
		_rw.sticker("+" + Locale.number(sim.chain_sum), _tally_at(), mini(50 + n * 2, 84), Sim.WINDOW + 0.5, false, Color("fff4c2"), false, "tally", 0.0, true)
	else:
		_rw.sticker("+" + Locale.number(pay), at, 40, 0.8, false, Color("fffaf0"), false, "one", 40.0)

## An egg off the ground: the chain's tick on its own cue.
func _on_gather(ev: Dictionary) -> void:
	_fx.cue("egg", _tick_pitch(int(ev.n)))
	_feel(Haptics.TICK)
	_tally(int(ev.n), int(ev.pay), _in_rw(field.pen_over("coop")))

func _on_milk(ev: Dictionary) -> void:
	_fx.cue("milk", _tick_pitch(int(ev.n)))
	_feel(Haptics.BUMP)
	_tally(int(ev.n), int(ev.pay), _in_rw(field.cow_at(int(ev.k)) - Vector2(0, 70.0)))

## An animal's milestone: named with rays, its seeds to the plate.
func _on_mile(ev: Dictionary) -> void:
	var egg: bool = ev.kind == "egg"
	_fx.cue("mile")
	_feel(Haptics.WIN)
	var at := _rw.at(self, size * Vector2(0.5, 0.4))
	_rw.sticker((tr("FW_MILE_EGG_HIT") if egg else tr("FW_MILE_MILK_HIT")) % Locale.number(int(ev.count)), at, 62, 2.2, true, Color.WHITE, true, "mile")
	_rw.sticker("+" + Locale.number(int(ev.prize)) + "  ·  " + tr("FW_MILE_MORE") % int(round(Sim.MILE_UP * 100.0)), at + Vector2(0, 86.0), 42, 2.2, false, Color("fff4c2"), false, "mile_line", 0.0, true)
	_rw.spray(at, Pal.SUN, 14, 640.0, "star", 1.0, 0.1, _plate_at(_seeds_l))
	_rw.rain(1.2, ["confetti", "star"], Rewards.CONFETTI)
	Analytics.track("furrow_mile", {"tile": ev.kind, "n": int(ev.n), "seeds": int(ev.prize)})
	_save()

## A pen built, an animal bought, the fence mended.
func _on_bought(ev: Dictionary) -> void:
	var what := String(ev.what)
	var pen := "cow" if what in ["pasture", "cow"] else "coop"
	var at := _in_rw(field.pen_at(pen)) if field.has_pens() else _rw.at(self, size * 0.5)
	match what:
		"coop", "pasture":
			_fx.cue("crop")
			_feel(Haptics.WIN)
			_rw.sticker(tr("FW_BUILT_COOP" if what == "coop" else "FW_BUILT_PASTURE"), at - Vector2(0, 110.0), 56, 2.0, true, Color.WHITE, true, "built")
			_rw.spray(at, Pal.SUN, 12, 520.0, "star", 1.0)
			_rw.spray(at, Art.CREAM, 12, 460.0, "confetti", 1.0)
			_rw.ring(at, 200.0, Color(Art.CREAM, 0.9))
		"fence":
			_fx.cue("plot", 0.9)
			_feel(Haptics.GOOD)
			_rw.sticker(tr("FW_MENDED"), at - Vector2(0, 90.0), 46, 1.6, false, Color("fffaf0"), true, "mended")
			_rw.ring(at, 170.0, Color(Art.WOOD_HI, 0.9))
		_:
			_fx.cue("level", 1.0 if what != "rooster" else 1.12)
			_feel(Haptics.GOOD)
			_rw.spray(at, Pal.SUN, 8, 420.0, "star", 0.9)
			_rw.ring(at, 150.0, Color(Art.CREAM, 0.9))
	Analytics.track("furrow_buy", {"tile": what, "seeds": int(ev.paid)})
	_save()

func _in_rw(p: Vector2) -> Vector2:
	return _rw.at(field, p)

func _plate_at(l: Control) -> Vector2:
	return _rw.at(l, l.size * 0.5)

## Where the chain's sum is lettered: under the plates, over the yard.
func _tally_at() -> Vector2:
	return _in_rw(Vector2(size.x * 0.5, field.area.position.y + 40.0))

## A crop picked: the tick a semitone higher a link, to five and no further,
## and the chain's sum lettered over the field as it grows.
func _on_pick(ev: Dictionary) -> void:
	var n := int(ev.n)
	_fx.cue("pick", _tick_pitch(n))
	_feel(Haptics.TICK)
	var at := _in_rw(field.over(int(ev.i)))
	if bool(ev.gold):
		_fx.cue("gold")
		_feel(Haptics.BUMP)
		_rw.sticker("+" + Locale.number(int(ev.pay)), at, 54, 1.1, false, Art.GOLD, true, "", 50.0)
		_rw.spray(at, Art.GOLD, 10, 480.0, "star", 1.0)
		_rw.ring(at, 120.0, Color(Art.GOLD, 0.9))
	if n >= 2 or not bool(ev.gold):
		_tally(n, int(ev.pay), at)

func _on_bunch(n: int, tier: int) -> void:
	_fx.cue("bunch", BUNCH_PITCH[tier])
	_feel(Haptics.GOOD)
	var at := _tally_at() + Vector2(0, 96.0)
	_rw.sticker(tr(BUNCH_KEYS[tier]) + " ×%d" % n, at, 56 + tier * 6, 1.3, tier >= 2, Color("fffaf0"), tier >= 1, "bunch")
	_rw.spray(at, Pal.SUN, 6 + tier * 4, 520.0, "star", 0.9 + 0.1 * tier)
	_rw.ring(at, 150.0 + 40.0 * tier, Color(Pal.SUN, 0.9))

func _on_sweep(n: int, bonus: int) -> void:
	_fx.cue("sweep")
	_feel(Haptics.WIN)
	var at := _rw.at(self, size * Vector2(0.5, 0.42))
	_rw.sticker(tr("FW_SWEEP"), at, 84, 2.0, true, Color.WHITE, true, "sweep", 0.0, true)
	_rw.sticker("+" + Locale.number(bonus), at + Vector2(0, 100.0), 60, 2.0, false, Color("fff4c2"), false, "sweep_bonus", 0.0, true)
	_rw.rain(1.8, ["confetti", "star"], Rewards.CONFETTI)
	_rw.spray(at, Pal.SUN, 16, 720.0, "star", 1.1, 0.1, _plate_at(_seeds_l))
	Analytics.track("furrow_sweep", {"n": n, "seeds": sim.chain_sum})

## A chain over: its sum goes to the plate as stars, and a basket is set
## down. A link or two is no chain and says nothing more.
func _on_chain_end(n: int, sum: int) -> void:
	if n < 3:
		return
	_fx.cue("tally")
	_feel(Haptics.BUMP)
	var from := _tally_at()
	_rw.stickers = _rw.stickers.filter(func(st: Dictionary) -> bool: return String(st.id) != "tally")
	_rw.sticker("+" + Locale.number(sum), from, 64, 0.9, false, Color("fff4c2"), false, "tally_end", -60.0, true)
	_rw.spray(from, Art.SEED, mini(4 + n, 16), 420.0, "spark", 1.0, 0.0, _plate_at(_seeds_l))
	_rw.spray(from, Pal.SUN, mini(2 + n / 3, 8), 420.0, "star", 0.8, 0.1, _plate_at(_seeds_l))
	_bump_seeds(0.3)
	_save()

func _on_plot(ev: Dictionary) -> void:
	_fx.cue("plot")
	_feel(Haptics.GOOD)
	var at := _in_rw(field.bed_at(int(ev.i)))
	_rw.sticker(tr("FW_NEW_PLOT"), at - Vector2(0, 110.0), 50, 1.4, false, Color("fffaf0"), true, "plot")
	_rw.spray(at, Art.SOIL_HI, 10, 420.0, "clod", 1.0)
	_rw.spray(at, Pal.SUN, 5, 420.0, "star", 0.8)
	_rw.ring(at, 170.0, Color(Art.CREAM, 0.9))
	Analytics.track("furrow_plot", {"n": sim.opened(), "seeds": int(ev.paid)})
	_save()

## A new packet: named with rays, and taken in hand so it can be sown at once.
func _on_crop(ev: Dictionary) -> void:
	var crop := int(ev.crop)
	_fx.cue("crop")
	_feel(Haptics.WIN)
	var at := _rw.at(self, size * Vector2(0.5, 0.4))
	_rw.sticker(tr("FW_CROP_" + String(Sim.CROPS[crop].id).to_upper()) + "!", at, 76, 2.0, true, Color.WHITE, true, "crop")
	_rw.sticker(tr("FW_NEW_CROP"), at + Vector2(0, 92.0), 44, 2.0, false, Color("fff4c2"), false, "crop_line", 0.0, true)
	_rw.spray(_rw.at(tray, _slot_mid(crop + 1)), Art.TONE[crop], 14, 620.0, "confetti", 1.0)
	_rw.spray(_rw.at(tray, _slot_mid(crop + 1)), Pal.SUN, 8, 520.0, "star", 0.9)
	_arm(crop)
	Analytics.track("furrow_crop", {"crop": Sim.CROPS[crop].id, "seeds": int(ev.paid)})
	_save()

func _on_landed(_gold: bool) -> void:
	_bump_seeds(0.12)

func _bump_seeds(amount: float) -> void:
	if _clock - _bumped_at < 0.12:
		return
	_bumped_at = _clock
	_seeds_l.pivot_offset = _seeds_l.size * 0.5
	Motion.bump(_seeds_l, amount, 0.22)

## A plant still growing, touched: its time left, and no sound.
func _on_waited(i: int) -> void:
	_rw.sticker(span(sim.left(i)), _in_rw(field.over(i)), 40, 1.0, false, Color("fffaf0"), false, "wait", 20.0)

## Bare earth touched with no packet in hand: said, and the packets hop.
func _on_bare(i: int) -> void:
	field.nod(i)
	_rw.sticker(tr("FW_PICK_PACKET"), _in_rw(field.over(i)), 40, 1.6, false, Color("fffaf0"), false, "packet", 20.0)
	for crop in sim.crops:
		_chip_at[crop + 1] = _clock + 0.05 * crop

## A hen touched with no egg by her: a hop and the button's click.
func _on_petted(at: Vector2) -> void:
	_fx.touch(1.18)
	_feel(Haptics.TAP)
	_rw.spray(_in_rw(at), Color("f28aa4"), 1, 120.0, "heart", 0.8)

## A cow touched before she is full: her time left, and no sound.
func _on_cow_waited(k: int) -> void:
	_rw.sticker(span(sim.cow_left(k)), _in_rw(field.cow_at(k) - Vector2(0, 70.0)), 40, 1.0, false, Color("fffaf0"), false, "wait", 20.0)

# --- a thing's card ---

func _about(kind: String, i: int) -> void:
	match kind:
		"crop":
			_show_crop(int(sim.plots[i].crop), i)
		"hen":
			_show_card(tr("FW_HEN"), Color("fbe9c8"), func(c: Control, mid: Vector2) -> void: c.draw_mesh(Animals.hen(150.0), null, Transform2D(0.0, mid + Vector2(-14, 74))),
				[[tr("FW_ABOUT_LAYS"), span(sim.lay_time()), false], [tr("FW_ABOUT_EGG"), Locale.number(sim.egg_worth()), true], [tr("FW_ABOUT_GROUND"), str(Sim.NEST), false]],
				tr("FW_ABOUT_HEN_NOTE"))
		"cow":
			_show_card(tr("FW_COW"), Color("d9e8f4"), func(c: Control, mid: Vector2) -> void: c.draw_mesh(Animals.cow(180.0), null, Transform2D(0.0, mid + Vector2(-8, 66))),
				[[tr("FW_ABOUT_FILLS"), span(sim.milk_time()), false], [tr("FW_ABOUT_MILK"), Locale.number(sim.milk_worth()), true]],
				tr("FW_ABOUT_COW_NOTE"))

## Crop `crop`'s card; `plot` is the lot it was asked on, growing still
## (-1: a packet's), which the card can dig up.
func _show_crop(crop: int, plot: int) -> void:
	if crop < 0:
		return
	sim.see(String(Sim.CROPS[crop].id))
	var can_dig: bool = plot >= 0 and not sim.plots[plot].ripe and not sim.plots[plot].dead
	var card := _show_card(tr("FW_CROP_" + String(Sim.CROPS[crop].id).to_upper()), Art.TONE_HI[crop].lerp(Art.CREAM, 0.55),
		func(c: Control, mid: Vector2) -> void: c.draw_mesh(Art.produce(crop, 78.0), null, Transform2D(0.0, mid + Vector2(0, 4))),
		[[tr("FW_ABOUT_SELLS"), Locale.number(sim.worth(crop)), true], [tr("FW_ABOUT_READY"), span(sim.grow_time(crop)), false], [tr("FW_ABOUT_KEEPS"), span(sim.keep_time(crop)), false]],
		tr("FW_ABOUT_CROP_NOTE"), tr("FW_ABOUT_DIG") if can_dig else "")
	if card != null and can_dig:
		card.dug.connect(func() -> void: sim.dig(plot))

func _show_card(title: String, tint: Color, picture: Callable, facts: Array, note: String, dig := "") -> Control:
	if get_node_or_null("Card") != null or get_node_or_null("Shop") != null:
		return null
	_fx.touch()
	_feel(Haptics.TAP)
	var card := Card.new()
	card.name = "Card"
	card.title = title
	card.tint = tint
	card.picture = picture
	card.facts = facts
	card.note = note
	card.dig = dig
	card.closed.connect(func() -> void:
		_fx.touch(0.94)
		_fx.buzz(Haptics.TAP))
	add_child(card)
	move_child(_rw, get_child_count() - 1)
	return card

## Seconds as a few characters: 8.5 s, 45 s, 12 min, 2.5 h.
static func span(secs: float) -> String:
	if secs < 9.95:
		return Locale.number(secs, 1) + " s"
	if secs < 59.5:
		return "%d s" % int(round(secs))
	if secs < 3570.0:
		return "%d min" % int(round(secs / 60.0))
	var h := secs / 3600.0
	return (Locale.number(h, 1) if h < 9.95 and absf(h - round(h)) > 0.05 else str(int(round(h)))) + " h"

# --- buying where it stands ---

func _buy_plot() -> void:
	var i: int = sim.next_plot()
	if i < 0:
		return
	if sim.buy_plot() < 0:
		_refuse()
		field.nod(i)
		_rw.sticker(tr("FW_SHORT") % Locale.number(sim.plot_price() - sim.seeds), _in_rw(field.over(i)), 40, 1.2, false, Color("fffaf0"), false, "short", 20.0)

## A pen's signboard pressed: built for its price, or said short.
func _buy_pen(kind: String) -> void:
	var what := "coop" if kind == "coop" else "pasture"
	if not sim.buy(what):
		_refuse()
		_rw.sticker(tr("FW_SHORT") % Locale.number(sim.price(what) - sim.seeds), _in_rw(field.pen_over(kind)), 40, 1.2, false, Color("fffaf0"), false, "short", 20.0)

func _refuse() -> void:
	_fx.cue("nope")
	_feel(Haptics.WARN)

# --- the tray ---

func _slots() -> int:
	return Sim.CROPS.size() + 1

func _slot_mid(slot: int) -> Vector2:
	return Vector2(tray.size.x * (slot + 0.5) / _slots(), 78.0)

## The tray under a finger: a slot is pressed as the finger leaves it, and
## a packet a finger rests on shows its card (`_process`).
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
			_slot_at = _clock
			_slot_touch = id
	elif id == _slot_touch and _slot_down >= 0:
		var was := _slot_down
		_slot_down = -1
		if was == slot:
			press_slot(slot)

## A press on the tray's slot: 0 the shed, then the crops in order.
func press_slot(slot: int) -> void:
	if slot == 0:
		_chip_at[0] = _clock
		_open_shop()
		return
	var crop := slot - 1
	if crop < sim.crops:
		_chip_at[slot] = _clock
		_fx.touch(1.0 if field.armed != crop else 0.94)
		_feel(Haptics.TAP)
		_arm(-1 if field.armed == crop else crop)
	elif crop == sim.crops:
		if not sim.buy_crop():
			_chip_no[slot] = _clock
			_refuse()
			_rw.sticker(tr("FW_SHORT") % Locale.number(sim.crop_price() - sim.seeds), _rw.at(tray, _slot_mid(slot) - Vector2(0, 90.0)), 40, 1.2, false, Color("fffaf0"), false, "short", 20.0)
		else:
			_chip_at[slot] = _clock
	# a packet further on is not for sale yet: nothing happens, and silently

## Takes a packet in hand (-1: puts it back, and the hand picks again).
func _arm(crop: int) -> void:
	field.armed = crop

func _draw_tray() -> void:
	if tray.size.x <= 0.0:
		return
	tray.draw_style_box(CozyTheme.lifted(Color("fcf7ef"), 36, 8), Rect2(Vector2.ZERO, tray.size))
	var still := Motion.reduce
	var fs := 26
	# the shed
	var mid := _slot_mid(0)
	var press := 1.0 if still else Motion.bump_scale(_clock - float(_chip_at.get(0, -10.0)), 0.16, 0.22)
	var b := Face.Builder.new()
	b.disc(mid + Vector2(0, 5.0), 42.0 * press, Color(Pal.TEXT, 0.16))
	b.disc(mid, 42.0 * press, TINT)
	var can_up := false
	for id: String in Sim.UPS + (Sim.COOP_UPS if sim.coop else []) + (Sim.COW_UPS if sim.pasture else []):
		if sim.seeds >= sim.up_price(id):
			can_up = true
	# the fence down is the shed's business too
	if sim.price("fence") >= 0 and sim.seeds >= sim.price("fence"):
		can_up = true
	if can_up:
		b.disc(mid + Vector2(32, -32), 13.0, Color("fffaf0"))
		b.disc(mid + Vector2(32, -32), 9.0 + (0.0 if still else 1.5 * sin(_clock * 4.0)), Pal.SUN)
	# the packet in hand stands on a ring of light
	if field.armed >= 0:
		var held := _slot_mid(field.armed + 1) - Vector2(0, 8.0)
		b.fan(Face.Builder.round_rect(held - Vector2(PACKET * 0.5 + 7.0, PACKET * 0.5 + 7.0), Vector2(PACKET + 14.0, PACKET + 14.0), 24.0), Pal.SUN)
	_tray_live = b.mesh()
	tray.draw_mesh(_tray_live, null)
	Icons.paint(tray, "trend", Rect2(mid - Vector2(24, 24) * press, Vector2(48, 48) * press), Pal.SURFACE)
	_caption(tr("FW_SHOP_SHORT"), mid, fs, Art.INK)
	for crop in Sim.CROPS.size():
		var slot := crop + 1
		var at := _slot_mid(slot)
		var sc := 1.0 if still else Motion.bump_scale(_clock - float(_chip_at.get(slot, -10.0)), 0.16, 0.22)
		if not still:
			at.x += Motion.shiver_offset(_clock - float(_chip_no.get(slot, -10.0)), 6.0, 0.3)
		if crop < sim.crops:
			if crop == field.armed:
				at.y -= 8.0
			tray.draw_mesh(Art.packet(crop, PACKET), null, Transform2D(0.0, Vector2(sc, sc), 0.0, at))
			_caption(span(sim.grow_time(crop)), _slot_mid(slot), fs, Art.INK)
		elif crop == sim.crops:
			var can: bool = sim.seeds >= sim.crop_price()
			if can and not still:
				at.y -= absf(sin(_clock * 3.0)) * 6.0
			tray.draw_mesh(Art.packet(crop, PACKET), null, Transform2D(0.0, Vector2(sc, sc), 0.0, at), Color(1, 1, 1, 1.0 if can else 0.5))
			_price(sim.crop_price(), _slot_mid(slot), fs - 2, can)
		else:
			tray.draw_mesh(Art.packet(crop, PACKET), null, Transform2D(0.0, Vector2(0.8, 0.8), 0.0, at), Color(1, 1, 1, 0.22))

func _caption(text: String, mid: Vector2, fs: int, col: Color) -> void:
	var w := tray.size.x / _slots()
	tray.draw_string(_font, Vector2(mid.x - w * 0.5, mid.y + PACKET * 0.5 + fs + 8.0), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)

## A price under a packet: a seed and a short number (12k, 3M).
func _price(n: int, mid: Vector2, fs: int, can: bool) -> void:
	var text := short(n)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y := mid.y + PACKET * 0.5 + fs + 8.0
	var x := mid.x - (tw + fs * 0.8) * 0.5
	tray.draw_mesh(Art.seed_icon(fs * 0.9), null, Transform2D(0.0, Vector2(x + fs * 0.3, y - fs * 0.34)))
	tray.draw_string(_font, Vector2(x + fs * 0.8, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK if can else Color(Art.INK, 0.6))

## A big number in a slot's width: 950, 6k, 50k, 3M.
static func short(n: int) -> String:
	if n < 1000:
		return str(n)
	if n < 1000000:
		return ("%dk" % (n / 1000)) if n % 1000 == 0 or n >= 10000 else Locale.number(n / 1000.0, 1) + "k"
	return ("%dM" % (n / 1000000)) if n % 1000000 == 0 or n >= 10000000 else Locale.number(n / 1000000.0, 1) + "M"

# --- the shed ---

func _open_shop(page := "field") -> void:
	if get_node_or_null("Shop") != null or get_node_or_null("Card") != null:
		return
	_fx.touch()
	_feel(Haptics.TAP)
	var shop := Shop.new()
	shop.name = "Shop"
	shop.sim = sim
	shop.page = page
	shop.closed.connect(func() -> void:
		_fx.touch(0.94)
		_fx.buzz(Haptics.TAP))
	add_child(shop)
	move_child(_rw, get_child_count() - 1)

# --- chrome ---

func _on_back() -> void:
	sim.save()
	Analytics.track("furrow_leave", {"seconds": int((Time.get_ticks_msec() - _opened_at) / 1000.0), "seeds": sim.seeds, "picked": sim.picked, "sweeps": sim.sweeps})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if tutor.close():
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	var shop := get_node_or_null("Shop")
	if shop != null and not shop.is_queued_for_deletion():
		shop.closed.emit()
		shop.queue_free()
		return
	var card := get_node_or_null("Card")
	if card != null and not card.is_queued_for_deletion():
		card.closed.emit()
		card.queue_free()
		return
	if field.armed >= 0:
		_fx.touch(0.94)
		_arm(-1)
		return
	_on_back()
