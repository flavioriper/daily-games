extends Control

## Bagatelle: the fifteenth game on the Arcade tab, marbles dropped through
## brass pins into wooden cups (spec docs/superpowers/specs/2026-10-15-
## arcade-bagatelle-design.md). **The velvet is the whole screen**, edge to
## edge (the rule since 2026-10-10), and the board -- the dropper's rail,
## the pins, the seven cups -- is laid in the room between the plate row and
## the tray (arcade/bagatelle_board.gd). Over it lie the flat boards' top
## bar, a plate row (the coins and their pace; the stars and what a cash
## out would pay) and the tray: Drop on the left (the thumb's side), then
## Upgrades, the Jar and Stars, each with a dot when it has something.
##
## **A kept game, like Tally**: no run end, no end card, no gold. The sim
## (arcade/bagatelle_sim.gd) is loaded when the screen opens and saved after
## a change, every twenty seconds, when the app loses focus and when the
## screen is left. The board runs only while it is on screen.
##
## The moments (arcade/rewards.gd over everything): a pin touched glows and
## plips, quieter as the marble falls; a cup squashes and floats its coins;
## a big landing sends coins up to the plate; a cup's level rings it; a
## bonus pin rings the marble; a new tier is named with confetti; a cash
## out rains stars.

signal closed

const Sim = preload("res://arcade/bagatelle_sim.gd")
const Art = preload("res://arcade/bagatelle_art.gd")
const Board = preload("res://arcade/bagatelle_board.gd")
const Shop = preload("res://arcade/bagatelle_shop.gd")
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

const GAME := "bagatelle"
const MARGIN := 40
const GAP := 20
const HUD_H := 120.0
const TRAY_H := 150.0
const SAVE_EVERY := 20.0
const SAVE_AFTER := 4.0
const HAPTICS := {}
## The repeating cues, each at most this often.
const PIN_GAP := 0.06
const LAND_GAP := 0.08
const DROP_GAP := 0.09
const CUP_GAP := 0.45
## A landing worth this share of the coins held (or a fourth tier) sends
## coins up to the plate.
const BIG_SHARE := 0.2
## The tray: Drop, then three round buttons.
const TRAY := ["drop", "up", "jar", "stars"]
const DROP_W := 0.38
const BTN_R := 50.0

var sim: RefCounted
var top_bar: Control
var settings_sheet: Control
var tutor: RefCounted
var board: Control
var tray: Control
var hud: Control
var _fx: Node2D
var _rw: Rewards
var _margins: MarginContainer
var _font: Font
var _clock := 0.0
var _knock := -1
var _saved_at := 0.0
var _changed_at := -1.0
var _opened_at := 0
var _at := {}
var _chip_at := {}
var _slot_down := -1
var _slot_touch := -2
var _drop_hold := 0.0
var _hud_down := -1
var _hud_live: ArrayMesh
var _tray_live: ArrayMesh
var _rate := 0.0
var _earned_frame := 0.0
var _shown_coins := 0.0

func puzzle_id() -> String:
	return GAME

func _ready() -> void:
	add_to_group("versus_host")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	_font = theme.get_font("font", "SheetTitle")
	sim = Sim.load_saved()
	_shown_coins = sim.coins
	_build()
	resized.connect(_lay_board)
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	tutor = ScreenTutor.new(self, puzzle_id(), "Bagatelle")
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	top_bar.refresh(self)
	_opened_at = Time.get_ticks_msec()
	_fx.cue("start")
	_first_hint.call_deferred()
	Analytics.track("bagatelle_enter", {"stars": sim.stars_ever, "tier": sim.best_tier})

func _notification(what: int) -> void:
	if sim == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		sim.save()

## A new board says where to begin, once.
func _first_hint() -> void:
	if sim.drops == 0 and sim.stars_ever == 0 and _rw != null:
		_rw.sticker(tr("BG_HINT_START"), _rw.at(self, size * Vector2(0.5, 0.42)), 40, 4.0, false, Color("fff4c2"), false, "hint", 0.0, true)

# --- building ---

func _build() -> void:
	board = Board.new()
	board.name = "Board"
	board.sim = sim
	board.font = _font
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.touched.connect(func(pitch: float) -> void:
		_fx.touch(pitch)
		_feel(Haptics.TAP))
	board.jar_asked.connect(func() -> void: open_card("jar"))
	add_child(board)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	board.add_child(_fx)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margins.add_child(col)

	top_bar = FlatTopBar.new("Bagatelle", tr("BG_MOTTO"), false)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	col.add_child(top_bar)
	# the velvet is dark: the name and its line in cream and lavender
	top_bar._title.add_theme_color_override("font_color", Art.CREAM)
	top_bar._motto.add_theme_color_override("font_color", Color("cbb7dc"))
	hud = Control.new()
	hud.name = "Hud"
	hud.custom_minimum_size.y = HUD_H
	hud.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.draw.connect(_draw_hud)
	hud.gui_input.connect(_on_hud_input)
	col.add_child(hud)
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

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_lay_board()

## The velvet fills the screen; the board is laid between the plates and
## the tray.
func _lay_board() -> void:
	if board == null or size.x <= 0.0:
		return
	var insets := SafeArea.insets(self)
	var top := MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + GAP
	var foot := MARGIN + insets.y + TRAY_H + GAP
	board.set_view(Rect2(MARGIN * 0.5, top, size.x - MARGIN, maxf(60.0, size.y - top - foot)))

# --- the top bar's questions ---

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/bagatelle_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.DROP, "TUT_BAGATELLE_DROP", tr("TUT_BAGATELLE_DROP_BODY")],
		[Diagram.Lesson.CUPS, "TUT_BAGATELLE_CUPS", tr("TUT_BAGATELLE_CUPS_BODY")],
		[Diagram.Lesson.JAR, "TUT_BAGATELLE_JAR", tr("TUT_BAGATELLE_JAR_BODY")],
		[Diagram.Lesson.STARS, "TUT_BAGATELLE_STARS", tr("TUT_BAGATELLE_STARS_BODY")],
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
	return get_node_or_null("Shop") != null

func _process(delta: float) -> void:
	if sim == null:
		return
	_clock += delta
	if not tutor.is_open():
		sim.step(minf(delta, 0.25))
	_earned_frame = 0.0
	_play_events()
	_play_pins()
	_rate = lerpf(_rate, _earned_frame / maxf(delta, 0.001), 1.0 - exp(-1.2 * delta))
	_shown_coins = sim.coins if Motion.reduce or sim.coins < _shown_coins else lerpf(_shown_coins, sim.coins, 1.0 - exp(-12.0 * delta))
	if _slot_down == 0 and not _busy():
		_drop_hold += delta
		if _drop_hold >= Board.HOLD_EVERY:
			_drop_hold -= Board.HOLD_EVERY
			_drop_button()
	board.tick(delta)
	_rw.bounds = Rect2(Vector2.ZERO, size)
	_rw.step(delta)
	if _knock >= 0:
		_fx.buzz(_knock)
		_knock = -1
	if _changed_at >= 0.0 and _clock - _changed_at > SAVE_AFTER:
		_save()
	elif _clock - _saved_at > SAVE_EVERY:
		_save()
	hud.queue_redraw()
	tray.queue_redraw()

func _save() -> void:
	_saved_at = _clock
	_changed_at = -1.0
	sim.save()

func _changed() -> void:
	if _changed_at < 0.0:
		_changed_at = _clock

## Asks for a knock this frame; the strongest asked for is the one played.
func _feel(kind: int) -> void:
	_knock = maxi(_knock, kind)

func _once(id: String, every: float) -> bool:
	if _clock - float(_at.get(id, -1000.0)) < every:
		return false
	_at[id] = _clock
	return true

# --- the sim's events ---

func _top() -> Vector2:
	return _rw.at(self, size * Vector2(0.5, 0.36))

func _board_rw(p: Vector2) -> Vector2:
	return _rw.at(board, board.screen_of(p))

func _coins_rw() -> Vector2:
	return _rw.at(hud, _coins_rect().position + Vector2(70.0, HUD_H * 0.5))

func _stars_rw() -> Vector2:
	return _rw.at(hud, _stars_rect().position + Vector2(60.0, HUD_H * 0.5))

## The pins touched since last frame: one plip at most every PIN_GAP, a
## step lower the further down the lowest one was.
func _play_pins() -> void:
	var hits: Vector2i = sim.take_pins()
	if hits.x <= 0 or _busy():
		return
	if _once("pin", PIN_GAP):
		var semis := 7.0 - hits.y * 0.75 + randf_range(-0.4, 0.4)
		_fx.cue("pin", pow(2.0, semis / 12.0), -3.0 if hits.x < 4 else -1.0)

func _play_events() -> void:
	if sim.events.is_empty():
		return
	var evs: Array = sim.events.duplicate()
	sim.events.clear()
	var coins_before: float = sim.coins
	for ev: Dictionary in evs:
		board.play(ev)
		match String(ev.type):
			"drop":
				_changed()
				if _once("drop", DROP_GAP) and not _busy():
					_fx.cue("drop", randf_range(0.95, 1.06), 0.0 if bool(ev.get("aimed", true)) else -5.0)
			"land":
				_on_land(ev, coins_before)
			"cup":
				_on_cup(int(ev.cup), int(ev.level))
			"bonus":
				_on_bonus(ev)
			"upgrade":
				_on_upgrade(String(ev.id), int(ev.level), int(ev.n))
			"ready":
				_on_ready(String(ev.id))
			"merge":
				_fx.cue("merge", minf(pow(2.0, int(ev.tier) / 12.0), 1.6))
				_feel(Haptics.GOOD)
				_chip_at["jar"] = _clock
				_changed()
			"tier":
				_on_tier(int(ev.tier))
			"cashout":
				_on_cashout(int(ev.stars))
			"shop":
				_fx.cue("star_buy")
				_feel(Haptics.GOOD)
				_chip_at["stars"] = _clock
				Analytics.track("bagatelle_shop", {"id": String(ev.id), "level": int(ev.level)})
				_changed()
			"moved":
				_fx.cue("place", randf_range(0.95, 1.05))
				_feel(Haptics.TAP)
				_rw.ring(_board_rw(Sim.pin_pos(int(ev.to))), 50.0, Art.HALO)
				_changed()
			"empty":
				if _once("empty", 1.4):
					_fx.cue("nope")
					_feel(Haptics.WARN)
					_rw.sticker(tr("BG_SAY_EMPTY"), _top() + Vector2(0, 120.0), 34, 1.8, false, Color("fffaf0"), false, "nope", 20.0)

func _on_land(ev: Dictionary, coins_before: float) -> void:
	var c := int(ev.cup)
	var pay := float(ev.pay)
	_earned_frame += pay
	_chip_at["coins"] = _clock
	if _busy():
		return
	if _once("land", LAND_GAP):
		# the edges pay most and pop a little higher
		var semis := absf(c - 3) * 1.2 + randf_range(-0.3, 0.3)
		_fx.cue("land", pow(2.0, semis / 12.0))
		_feel(Haptics.TICK)
	var big := int(ev.tier) >= 3 or (coins_before > 50.0 and pay >= coins_before * BIG_SHARE)
	if big and _once("big", 0.35):
		var from := _rw.at(board, board.cup_mid(c))
		_rw.spray(from, Color("f5c04a"), 6, 520.0, "coin", 0.9, 0.0, _coins_rw())
		_rw.ring(from, 70.0, Color("ffe08a"))
	_changed()

func _on_cup(c: int, level: int) -> void:
	var at := _rw.at(board, board.cup_mid(c))
	if not _once("cup%d" % c, 0.1) or _busy():
		return
	_rw.ring(at, 80.0 * board.k, Color("ffe08a"))
	if _once("cup", CUP_GAP):
		_fx.cue("cup", minf(pow(2.0, mini(level, 60) / 48.0), 1.8))
		_feel(Haptics.TAP)
		if level % 5 == 0:
			_rw.spray(at, Pal.SUN, 8, 340.0, "star", 0.8)
			_rw.sticker(tr("BG_CUP_UP") % [level, "×" + Board._mult_text(sim.cup_mult(c))], at + Vector2(0, -90.0), 34, 1.5, false, Color("fff4c2"), false, "cup", 30.0)

func _on_bonus(ev: Dictionary) -> void:
	if _busy():
		return
	var at := _board_rw(Sim.pin_pos(int(ev.pin)))
	_rw.ring(at, 44.0 * board.k, Art.PLUS if String(ev.kind) == "plus" else Art.TIMES, 0.0, 0.35)
	if _once("bonus", 0.12):
		_fx.cue("bonus", randf_range(0.97, 1.05) * (1.12 if String(ev.kind) == "times" else 1.0), -3.0)

func _on_upgrade(id: String, level: int, n: int) -> void:
	_fx.cue("buy", randf_range(0.97, 1.03))
	_feel(Haptics.GOOD)
	_chip_at["up"] = _clock
	if n > 1:
		_rw.sticker(tr("BG_UPGRADED_N") % [tr("BG_UP_" + id.to_upper()), level, n], _top(), 40, 1.4, false, Color("fff4c2"), true, "up")
	else:
		_rw.sticker(tr("BG_UPGRADED") % [tr("BG_UP_" + id.to_upper()), level], _top(), 40, 1.2, false, Color("fff4c2"), true, "up")
	Analytics.track("bagatelle_upgrade", {"id": id, "level": level})
	_changed()

func _on_ready(id: String) -> void:
	if _busy() or not _once("ready", 8.0):
		return
	_fx.cue("ready")
	_feel(Haptics.TAP)
	_chip_at["up"] = _clock
	var at := _rw.at(tray, _slot_mid(1))
	_rw.ring(at, 80.0, Pal.SUN)
	_rw.sticker(tr("BG_READY") % tr("BG_UP_" + id.to_upper()), at + Vector2(0, -110.0), 32, 2.0, false, Color("fff4c2"), false, "ready")

func _on_tier(k: int) -> void:
	_fx.cue("tier")
	_feel(Haptics.WIN)
	var at := _top()
	_rw.sticker(tr("BG_NEW_TIER") % tr("BG_TIER_" + String(Sim.TIER_IDS[k]).to_upper()), at, 60, 2.6, true, Color.WHITE, true, "tier")
	_rw.sticker(tr("BG_TIER_WORTH") % Sim.short(Sim.worth(k)), at + Vector2(0, 86.0), 36, 2.6, false, Color("fff4c2"), false, "worth", 0.0, true)
	_rw.rain(1.2, ["confetti", "star"], Rewards.CONFETTI)
	Analytics.track("bagatelle_tier", {"tier": k})
	_save()

func _on_cashout(stars: int) -> void:
	_fx.cue("cashout")
	_feel(Haptics.WIN)
	board.let_go()
	var at := _top()
	_rw.sticker(tr("BG_CASHED_ONE") if stars == 1 else tr("BG_CASHED_N") % stars, at, 66, 2.6, true, Color.WHITE, true, "cash")
	_rw.sticker(tr("BG_CASHED_LINE"), at + Vector2(0, 90.0), 34, 2.8, false, Color("fff4c2"), false, "cash_line", 0.0, true)
	_rw.rain(1.8, ["star", "confetti"], Rewards.CONFETTI)
	_rw.spray(at, Pal.SUN, 16, 640.0, "star", 1.1, 0.0, _stars_rw())
	_shown_coins = 0.0
	_rate = 0.0
	Analytics.track("bagatelle_cashout", {"stars": stars, "outs": sim.cashouts})
	_save()

# --- the plate row ---

func _coins_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(hud.size.x * 0.56 - 10.0, hud.size.y))

func _stars_rect() -> Rect2:
	var x := hud.size.x * 0.56 + 10.0
	return Rect2(Vector2(x, 0.0), Vector2(hud.size.x - x, hud.size.y))

func _draw_hud() -> void:
	if hud.size.x <= 0.0:
		return
	var cr := _coins_rect()
	var sr := _stars_rect()
	var b := Face.Builder.new()
	b.polygon(Face.Builder.round_rect(cr.position + Vector2(0, 6), cr.size, 30.0), Color(0, 0, 0, 0.22))
	b.polygon(Face.Builder.round_rect(cr.position, cr.size, 30.0), Color("fcf7ef"))
	b.polygon(Face.Builder.round_rect(sr.position + Vector2(0, 6), sr.size, 30.0), Color(0, 0, 0, 0.22))
	var can: bool = sim.can_cash_out()
	b.polygon(Face.Builder.round_rect(sr.position, sr.size, 30.0), Color("f6ecfa") if can else Color("fcf7ef"))
	if can and not Motion.reduce:
		var beat := 0.5 + 0.5 * sin(_clock * 3.0)
		b.stroke(Face.Builder.round_rect(sr.position, sr.size, 30.0), 4.0, Color(Color("b07fd0"), 0.4 + 0.5 * beat), true)
	_hud_live = b.mesh()
	hud.draw_mesh(_hud_live, null)
	var hop := Motion.bump_scale(_clock - float(_chip_at.get("coins", -10.0)), 0.06, 0.14)
	var cm := cr.position + Vector2(64.0, cr.size.y * 0.5)
	hud.draw_mesh(Art.coin(34.0), null, Transform2D(0.0, Vector2.ONE * hop, 0.0, cm))
	hud.draw_string(_font, cr.position + Vector2(118.0, 62.0), Sim.short(_shown_coins), HORIZONTAL_ALIGNMENT_LEFT, cr.size.x - 130.0, 48, Pal.TEXT)
	hud.draw_string(_font, cr.position + Vector2(120.0, 98.0), tr("BG_PER_SECOND") % Sim.short(_rate), HORIZONTAL_ALIGNMENT_LEFT, cr.size.x - 130.0, 24, Pal.TEXT_DIM)
	var shop := Motion.bump_scale(_clock - float(_chip_at.get("stars", -10.0)), 0.1, 0.2)
	var sm := sr.position + Vector2(58.0, sr.size.y * 0.5)
	hud.draw_mesh(Art.star(36.0), null, Transform2D(0.0, Vector2.ONE * shop, 0.0, sm))
	hud.draw_string(_font, sr.position + Vector2(104.0, 62.0), Sim.short(float(sim.stars)), HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - 112.0, 44, Pal.TEXT)
	var line := tr("BG_CASH_PLATE") % sim.stars_for() if can else tr("BG_NEXT_STAR") % Sim.short(sim.next_star_at())
	hud.draw_string(_font, sr.position + Vector2(106.0, 98.0), line, HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - 112.0, 22, Color("8a5fae") if can else Pal.TEXT_DIM)

func _on_hud_input(event: InputEvent) -> void:
	var at := Vector2(-1, -1)
	var down := false
	if event is InputEventScreenTouch:
		at = (event as InputEventScreenTouch).position
		down = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		at = (event as InputEventMouseButton).position
		down = (event as InputEventMouseButton).pressed
	else:
		return
	var which := 1 if _stars_rect().has_point(at) else (0 if _coins_rect().has_point(at) else -1)
	if down:
		_hud_down = which
	elif which == _hud_down and which >= 0:
		_hud_down = -1
		open_card("stars" if which == 1 else "up")

# --- the tray ---

func _slot_rect(i: int) -> Rect2:
	var w := tray.size.x
	if i == 0:
		return Rect2(Vector2(0, 8.0), Vector2(w * DROP_W, TRAY_H - 16.0))
	var rest := w * (1.0 - DROP_W) - 10.0
	var cw := rest / 3.0
	return Rect2(Vector2(w * DROP_W + 10.0 + cw * (i - 1), 0.0), Vector2(cw, TRAY_H))

func _slot_mid(i: int) -> Vector2:
	var r := _slot_rect(i)
	return Vector2(r.get_center().x, r.position.y + (r.size.y * 0.5 if i == 0 else 56.0))

func _dot(id: String) -> int:
	match id:
		"up":
			var n := 0
			for u: String in Sim.UPS:
				if sim.can_buy(u):
					n += 1
			return n
		"jar":
			var n := 0
			for k in Sim.TIERS - 1:
				if sim.jar[k] >= Sim.MERGE:
					n += 1
			return n
		"stars":
			var n := 0
			for s: String in Sim.SHOP:
				if sim.can_shop(s):
					n += 1
			return n + (1 if sim.can_cash_out() else 0)
	return 0

func _draw_tray() -> void:
	if tray.size.x <= 0.0:
		return
	var b := Face.Builder.new()
	var still := Motion.reduce
	# Drop: a wide sun pill
	var dr := _slot_rect(0)
	var dp := 0.96 if _slot_down == 0 else (1.0 if still else Motion.bump_scale(_clock - float(_chip_at.get("drop", -10.0)), 0.05, 0.16))
	var dc := dr.get_center()
	var dsz := dr.size * dp
	b.polygon(Face.Builder.round_rect(dc - dsz * 0.5 + Vector2(0, 7), dsz, dsz.y * 0.5), Pal.SUN_DEEP)
	b.polygon(Face.Builder.round_rect(dc - dsz * 0.5, dsz, dsz.y * 0.5), Pal.SUN)
	for i in range(1, 4):
		var id: String = TRAY[i]
		var at := _slot_mid(i)
		var sc := 0.94 if _slot_down == i else (1.0 if still else Motion.bump_scale(_clock - float(_chip_at.get(id, -10.0)), 0.12, 0.2))
		b.disc(at + Vector2(0, 5.0), BTN_R * sc, Color(0, 0, 0, 0.25))
		b.disc(at, BTN_R * sc, Color("fcf7ef"))
		var n := _dot(id)
		if n > 0:
			var beat := 0.0 if still else 1.5 * sin(_clock * 4.0)
			b.disc(at + Vector2(38, -38), 20.0, Color("fffaf0"))
			b.disc(at + Vector2(38, -38), 16.0 + beat, Pal.SUN if id != "stars" else Color("b07fd0"))
	_tray_live = b.mesh()
	tray.draw_mesh(_tray_live, null)
	# the marks
	tray.draw_mesh(Art.marble(maxi(0, sim.best_in_jar())), null, Transform2D(0.0, Vector2.ONE * 1.9 * dp, 0.0, dc + Vector2(-dsz.x * 0.5 + 56.0, 0)))
	var dcap := tr("BG_DROP")
	tray.draw_string(_font, Vector2(dr.position.x + 92.0, dc.y + 14.0), dcap, HORIZONTAL_ALIGNMENT_CENTER, dr.size.x - 110.0, 38, Pal.TEXT)
	Icons.paint(tray, "trend", Rect2(_slot_mid(1) - Vector2(24, 24), Vector2(48, 48)), Pal.TEXT)
	tray.draw_mesh(Art.marble(maxi(1, mini(sim.best_tier, Sim.TIERS - 1))), null, Transform2D(0.0, Vector2.ONE * 1.7, 0.0, _slot_mid(2)))
	tray.draw_mesh(Art.star(26.0), null, Transform2D(0.0, _slot_mid(3)))
	for i in range(1, 4):
		var id: String = TRAY[i]
		var r := _slot_rect(i)
		tray.draw_string(_font, Vector2(r.position.x, _slot_mid(i).y + BTN_R + 30.0), tr("BG_TRAY_" + id.to_upper()), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Art.CREAM)
		var n := _dot(id)
		if n > 0:
			var s := str(n)
			var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
			tray.draw_string(_font, _slot_mid(i) + Vector2(38.0 - w * 0.5, -38.0 + 19.0 * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Pal.TEXT)

func _slot_at(p: Vector2) -> int:
	for i in TRAY.size():
		if _slot_rect(i).grow(4.0).has_point(p):
			return i
	return -1

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
	var slot := _slot_at(at)
	if down:
		if _slot_down < 0 and slot >= 0:
			_slot_down = slot
			_slot_touch = id
			if slot == 0:
				# Drop answers on the press, and keeps dropping while held
				_drop_hold = 0.0
				_drop_button()
	elif id == _slot_touch and _slot_down >= 0:
		var was := _slot_down
		_slot_down = -1
		if was == slot and slot > 0:
			press_slot(slot)

## Drop: a marble from the middle of the board, a little to either side.
func _drop_button() -> void:
	_chip_at["drop"] = _clock
	sim.drop(Sim.W * 0.5 + randf_range(-60.0, 60.0))

## A press on one of the round buttons (the tray, or a harness).
func press_slot(i: int) -> void:
	match TRAY[i]:
		"drop":
			_drop_button()
		"up":
			open_card("up")
		"jar":
			open_card("jar")
		"stars":
			open_card("stars")

# --- cards ---

func open_card(mode: String) -> void:
	if _busy():
		return
	_chip_at[mode] = _clock
	_fx.touch()
	_feel(Haptics.TAP)
	board.let_go()
	var shop := Shop.new()
	shop.name = "Shop"
	shop.sim = sim
	shop.mode = mode
	shop.closed.connect(func() -> void:
		_fx.touch(0.94)
		_fx.buzz(Haptics.TAP)
		_save())
	shop.refused.connect(func() -> void:
		_fx.cue("nope")
		_fx.buzz(Haptics.WARN))
	add_child(shop)
	move_child(_rw, get_child_count() - 1)

# --- chrome ---

func _on_back() -> void:
	sim.save()
	Analytics.track("bagatelle_leave", {"seconds": int((Time.get_ticks_msec() - _opened_at) / 1000.0), "stars": sim.stars_ever, "tier": sim.best_tier})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if tutor.close():
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	var sheet := get_node_or_null("Shop")
	if sheet != null and not sheet.is_queued_for_deletion():
		sheet.close()
		return
	_on_back()
