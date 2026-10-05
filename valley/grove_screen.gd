extends Control

## The Grove: the first place on the Valley tab. A piece of land in a pond,
## trees coming up on it at random spots, and a circle that follows the
## finger and chops whatever stands inside it; nothing chops by itself yet
## (the user's design, 2026-10-05). A felled tree leaves wood, which goes to
## the shared inventory (core/stock.gd) and is never spent here, and energy,
## which stays and buys the six tiles under the land.
## Spec docs/superpowers/specs/2026-10-05-valley-grove-design.md; the rules
## and every number are valley/grove_sim.gd's, the drawings grove_art.gd's.
##
## Like a Versus or Arcade screen it is its own host: ui/menu.gd mounts it
## over the list (`_open_valley`) and it joins the `versus_host` group so
## Android's back reaches it. It has no round, no score and no end: the
## grove is read from its file as it opens, with the trees that came up
## while nobody was here, and written back as tiles are bought, every few
## seconds while trees fall, and as it is left.

signal closed

const Sim = preload("res://valley/grove_sim.gd")
const Art = preload("res://valley/grove_art.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const ScreenTutor = preload("res://ui/hud/screen_tutor.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Analytics = preload("res://core/analytics.gd")

const GAME := "grove"
const MARGIN := 40
const GAP := 20
const HUD_H := 96.0
const INFO_H := 48.0
const TILE_H := 264.0
const TILE_GAP := 16
const FILL := Color("fcf7ef")
## The land keeps this much water round it, and more under its earth edge.
const SHORE := 26.0
const SHORE_FOOT := 64.0
## Seconds: a hit tree's squash, a felled one's fall, a number's rise, a log's
## flight, and how long the circle's rim swells on a chop.
const SQUASH := 0.16
const FALL := 0.4
const NUM := 0.7
const FLIGHT := 0.5
const SWELL := 0.18
## Logs and sparks thrown by one tree, at most, each.
const THROWN := 3
const SAVE_GAP := 5.0
## A chop that hits is heard a little higher or lower each time, so a held
## finger is not one sample on a loop.
const CHOP_PITCH := 0.07
## The tap is a selection moved; a tree down is a piece set down; a tile
## bought is something finished; one that cannot be is a not yet.
const HAPTICS := {"fell": Haptics.TAP, "buy": Haptics.BUMP, "no": Haptics.WARN}
const TILE_NAMES := {"axe": "GROVE_AXE", "reach": "GROVE_REACH", "swing": "GROVE_SWING",
	"sprout": "GROVE_SPROUT", "room": "GROVE_ROOM", "seeds": "GROVE_SEEDS"}

var sim: RefCounted
var top_bar: Control
var settings_sheet: Control
var tutor: RefCounted
var field: Control
var _fx: Node2D
var _margins: MarginContainer
var _over: Control
var _count_l: Label
var _plates := {}   # "energy" / "wood" -> {panel, icon, label}
var _shown := {"energy": 0.0, "wood": 0.0}
var _tiles := {}    # tile -> {button, icon, effect, pill, cost, badge, level}
var _tiles_for := ""
var _ground: ArrayMesh
var _u := 1.0
var _origin := Vector2.ZERO
var _hold := false
var _hold_at := Vector2.ZERO
var _held_back := false
var _since_chop := 10.0
var _hit := {}      # tree id -> seconds since it was last hit
var _falls: Array = []   # {tree, t, dir}
var _nums: Array = []    # {at, text, t, gold}
var _flies: Array = []   # {from, to, t, kind}
var _bump := {}     # plate -> its running bump
var _dirty := false
var _since_save := 0.0
var _opened_at := 0
var _felled_at_open := 0
var _rng := RandomNumberGenerator.new()

func puzzle_id() -> String:
	return GAME

func _ready() -> void:
	add_to_group("versus_host")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	sim = Sim.load_saved(Time.get_unix_time_from_system())
	_opened_at = Time.get_ticks_msec()
	_felled_at_open = sim.felled
	_shown.energy = float(sim.energy)
	_shown.wood = float(Stock.count("wood"))
	_build()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	tutor = ScreenTutor.new(self, puzzle_id(), "Grove", _tutor_hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	top_bar.refresh(self)
	_refresh_tiles()
	_refresh_hud(0.0)
	Analytics.track("valley_enter", {"place": GAME, "trees": sim.trees.size(), "room": sim.room()})

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_hold = false
		_save()
	elif what == NOTIFICATION_EXIT_TREE:
		_save()

# --- building ---

func _build() -> void:
	var page := ColorRect.new()
	page.color = Pal.PAPER
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	_margins.add_child(col)

	top_bar = FlatTopBar.new("Grove", tr("GROVE_MOTTO"), false)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.settings.connect(func() -> void:
		_hold = false
		settings_sheet.open())
	col.add_child(top_bar)

	var hud := HBoxContainer.new()
	hud.name = "Hud"
	hud.custom_minimum_size.y = HUD_H
	hud.add_theme_constant_override("separation", TILE_GAP)
	hud.add_child(_plate("energy", "GROVE_ENERGY"))
	hud.add_child(_plate("wood", "GROVE_WOOD"))
	col.add_child(hud)

	field = Control.new()
	field.name = "Field"
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.resized.connect(_layout_field)
	field.gui_input.connect(_on_field_input)
	col.add_child(field)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	field.add_child(_fx)

	var info := HBoxContainer.new()
	info.custom_minimum_size.y = INFO_H
	_count_l = Label.new()
	_count_l.name = "Count"
	_count_l.theme_type_variation = "CardTitle"
	_count_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_count_l)
	var hint := Label.new()
	hint.text = "GROVE_HINT"
	hint.theme_type_variation = "CardBlurb"
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.add_child(hint)
	col.add_child(info)

	var grid := GridContainer.new()
	grid.name = "Tiles"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	for tile: String in Sim.TILES:
		grid.add_child(_tile(tile))
	col.add_child(grid)

	_over = Control.new()
	_over.name = "Over"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_over)
	add_child(_over)
	_apply_insets()

## What is held, on a paper plate: its picture, its name and the count.
func _plate(what: String, key: String) -> Control:
	var plate := PanelContainer.new()
	plate.name = what.capitalize()
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.add_theme_stylebox_override("panel", CozyTheme.lifted(FILL, 30, 8))
	plate.resized.connect(func() -> void: plate.pivot_offset = plate.size * 0.5)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	plate.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(72, 72)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		icon.draw_mesh(Art.icon(what), null, Transform2D(-0.3 if what == "wood" else 0.0, icon.size * 0.5)))
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -6)
	row.add_child(words)
	var kicker := Label.new()
	kicker.text = key
	kicker.theme_type_variation = "MenuKicker"
	words.add_child(kicker)
	var value := Label.new()
	value.name = "Value"
	value.text = "0"
	value.theme_type_variation = "SheetTitle"
	words.add_child(value)
	_plates[what] = {"panel": plate, "icon": icon, "label": value}
	return plate

## One of the six: its picture, its name, what the next level does, and the
## energy it asks. A tile that cannot be bought yet is still pressed: it
## shakes its head.
func _tile(tile: String) -> Control:
	var b := Button.new()
	b.name = tile.capitalize()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = TILE_H
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CozyTheme.lift_button(b, FILL, 30, 8)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.pressed.connect(_on_tile.bind(tile))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 12.0
	col.offset_bottom = -16.0
	col.offset_left = 10.0
	col.offset_right = -10.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(0, 108)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_tile_icon.bind(icon, tile))
	col.add_child(icon)
	var name_l := Label.new()
	name_l.text = TILE_NAMES[tile]
	name_l.theme_type_variation = "CardTitle"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_l)
	var effect := Label.new()
	effect.theme_type_variation = "CardBlurb"
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.clip_text = true
	effect.add_theme_font_size_override("font_size", 24)
	col.add_child(effect)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.custom_minimum_size = Vector2(210, 52)
	col.add_child(pill)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var spark := Control.new()
	spark.custom_minimum_size = Vector2(34, 34)
	spark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spark.draw.connect(func() -> void:
		spark.draw_mesh(Art.spark(), null, Transform2D(0.0, Vector2(0.72, 0.72), 0.0, spark.size * 0.5)))
	row.add_child(spark)
	var cost := Label.new()
	cost.theme_type_variation = "CardTitle"
	cost.add_theme_font_size_override("font_size", 34)
	row.add_child(cost)
	# the level, on the tile's corner once there is one
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_top = 10.0
	badge.offset_right = -10.0
	var bb := StyleBoxFlat.new()
	bb.bg_color = Pal.ACCENT
	bb.set_corner_radius_all(18)
	bb.content_margin_left = 14.0
	bb.content_margin_right = 14.0
	bb.content_margin_top = 0.0
	bb.content_margin_bottom = 2.0
	badge.add_theme_stylebox_override("panel", bb)
	var level := Label.new()
	level.theme_type_variation = "Badge"
	badge.add_child(level)
	b.add_child(badge)
	_tiles[tile] = {"button": b, "icon": icon, "effect": effect, "pill": pill, "cost": cost,
		"spark": spark, "badge": badge, "level": level}
	return b

func _draw_tile_icon(icon: Control, tile: String) -> void:
	var c := icon.size * 0.5
	var done: bool = sim.is_done(tile)
	icon.draw_circle(c, 52.0, Pal.LEAF_TILE if done else Pal.PARCHMENT, true, -1.0, true)
	var look: int = Sim.look_of(int(sim.lv.seeds) + 1)
	icon.draw_mesh(Art.icon(tile, look), null, Transform2D(0.0, Vector2(0.88, 0.88), 0.0, c))

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))

## The land is as big as the field lets it be, with water all round, and the
## pond and the land are baked once for that size.
func _layout_field() -> void:
	var s := field.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	_u = minf((s.x - SHORE * 2.0) / Sim.LAND.x, (s.y - SHORE - SHORE_FOOT) / Sim.LAND.y)
	_origin = Vector2((s.x - Sim.LAND.x * _u) * 0.5, SHORE + (s.y - SHORE - SHORE_FOOT - Sim.LAND.y * _u) * 0.5)
	_ground = Art.ground(s, Rect2(_origin, Sim.LAND * _u))
	field.queue_redraw()

## A point of the land, in the field's pixels, and back.
func px(p: Vector2) -> Vector2:
	return _origin + p * _u

func unit(at: Vector2) -> Vector2:
	return (at - _origin) / _u

# --- what the top bar and the tutorial ask ---

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/grove_tutorial_diagram.gd")
	var pages := []
	for step: Array in [
			[Diagram.Lesson.CHOP, "TUT_GROVE_CHOP", tr("TUT_GROVE_CHOP_BODY") % Sim.hp_of(0)],
			[Diagram.Lesson.GIFTS, "TUT_GROVE_GIFTS", tr("TUT_GROVE_GIFTS_BODY")],
			[Diagram.Lesson.WAIT, "TUT_GROVE_WAIT", tr("TUT_GROVE_WAIT_BODY")]]:
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

## A card over the screen (the tutorial): the finger is let go.
func _tutor_hold(on: bool) -> void:
	_held_back = on
	if on:
		_hold = false

# --- time ---

func _process(delta: float) -> void:
	if sim == null:
		return
	var holding: bool = _hold and not _held_back and not settings_sheet.is_open()
	sim.step(delta, holding, unit(_hold_at))
	_since_chop += delta
	_play_events()
	for id in _hit.keys():
		_hit[id] += delta
		if _hit[id] > SQUASH:
			_hit.erase(id)
	for list: Array in [_falls, _nums]:
		for item: Dictionary in list:
			item.t += delta
	_falls = _falls.filter(func(f: Dictionary) -> bool: return f.t < FALL)
	_nums = _nums.filter(func(n: Dictionary) -> bool: return n.t < NUM)
	var landed := false
	for f: Dictionary in _flies:
		f.t += delta
		if f.t >= FLIGHT:
			landed = true
			_kick(String(f.kind))
	if landed:
		_flies = _flies.filter(func(f: Dictionary) -> bool: return f.t < FLIGHT)
	_refresh_hud(delta)
	if _dirty:
		_since_save += delta
		if _since_save >= SAVE_GAP:
			_save()
	field.queue_redraw()
	_over.queue_redraw()

func _play_events() -> void:
	for e: Dictionary in sim.events:
		match String(e.kind):
			"hit":
				var tree: Dictionary = e.tree
				_hit[tree.id] = 0.0
				_nums.append({"at": tree.pos + Vector2(_rng.randf_range(-16.0, 16.0), -Art.height(Sim.look_of(tree.tier)) * 0.86),
					"text": Art.short(int(e.amount)), "t": 0.0, "gold": false})
			"fell":
				var tree: Dictionary = e.tree
				var give := int(e.give)
				_falls.append({"tree": tree, "t": 0.0, "dir": -1.0 if _rng.randf() < 0.5 else 1.0})
				_nums.append({"at": tree.pos + Vector2(0.0, -Art.height(Sim.look_of(tree.tier)) - 18.0),
					"text": "+" + Art.short(give), "t": 0.0, "gold": true})
				Stock.add("wood", give, GAME)
				_throw(tree, give)
				_fx.cue("fell")
				_dirty = true
			"swing":
				_since_chop = 0.0
				if int(e.hits) > 0:
					_fx.cue("chop", 1.0 + _rng.randf_range(-CHOP_PITCH, CHOP_PITCH))
	sim.events.clear()
	if _tiles_for != _tiles_key():
		_refresh_tiles()

## A felled tree throws its logs at the wood plate and its sparks at the
## energy plate; the counts roll up as they land.
func _throw(tree: Dictionary, give: int) -> void:
	if Motion.reduce:
		return
	var from: Vector2 = field.get_global_transform() * px(tree.pos + Vector2(0.0, -Sim.radius_of(tree.tier)))
	var inv := _over.get_global_transform().affine_inverse()
	for kind: String in ["wood", "energy"]:
		var icon: Control = _plates[kind].icon
		var to: Vector2 = inv * (icon.get_global_transform() * (icon.size * 0.5))
		for i in mini(THROWN, give):
			_flies.append({"from": inv * from + Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-20.0, 20.0)),
				"to": to, "t": -0.05 * i - (0.04 if kind == "energy" else 0.0), "kind": kind})

## A plate swells as something lands on it. Each kick ends the last, or
## landings a moment apart would leave it stuck big (ui/menu/gold_pill.gd).
func _kick(kind: String) -> void:
	var panel: Control = _plates[kind].panel
	Motion.stop(_bump.get(kind))
	panel.scale = Vector2.ONE
	_bump[kind] = Motion.bump(panel, 0.06, 0.18)

func _refresh_hud(delta: float) -> void:
	var want := {"energy": float(sim.energy), "wood": float(Stock.count("wood"))}
	for kind: String in want:
		var held: float = want[kind]
		var s: float = _shown[kind]
		if Motion.reduce or delta <= 0.0 or absf(held - s) < 0.6:
			s = held
		else:
			s = lerpf(s, held, minf(1.0, delta * 10.0))
		_shown[kind] = s
		(_plates[kind].label as Label).text = Art.short(int(round(s)))
	_count_l.text = tr("GROVE_TREES") % [sim.trees.size(), sim.room()]

# --- the tiles ---

func _tiles_key() -> String:
	var key := ""
	for tile: String in Sim.TILES:
		key += "%d%s" % [int(sim.lv[tile]), "y" if sim.can_buy(tile) else "n"]
	return key

func _refresh_tiles() -> void:
	_tiles_for = _tiles_key()
	for tile: String in Sim.TILES:
		var t: Dictionary = _tiles[tile]
		var done: bool = sim.is_done(tile)
		var can: bool = sim.can_buy(tile)
		var level := int(sim.lv[tile])
		(t.effect as Label).text = tr("GROVE_DONE") if done else _effect(tile)
		(t.pill as Control).visible = not done
		(t.cost as Label).text = Art.short(sim.cost(tile))
		var box := StyleBoxFlat.new()
		box.bg_color = Pal.SUN if can else Color("e6dccb")
		box.set_corner_radius_all(26)
		box.content_margin_left = 16.0
		box.content_margin_right = 20.0
		(t.pill as Control).add_theme_stylebox_override("panel", box)
		(t.cost as Label).add_theme_color_override("font_color", Pal.SURFACE if can else Pal.TEXT_DIM)
		(t.badge as Control).visible = level > 0
		(t.level as Label).text = tr("GROVE_MAX") if done else str(level)
		(t.button as Control).modulate.a = 1.0 if can or done else 0.78
		(t.icon as Control).queue_redraw()

## What the next level of `tile` does, in the tile's own words.
func _effect(tile: String) -> String:
	match tile:
		"axe":
			return tr("GROVE_FX_AXE") % [sim.power(), sim.power() + 1]
		"reach":
			return tr("GROVE_FX_REACH")
		"swing":
			return _decimal(tr("GROVE_FX_SWING") % [sim.swing_time(), sim.swing_time() * Sim.SWING_STEP])
		"sprout":
			return _decimal(tr("GROVE_FX_SPROUT") % [sim.spawn_time(), sim.spawn_time() * Sim.SPROUT_STEP])
		"room":
			return tr("GROVE_FX_ROOM") % [sim.room(), sim.room() + 1]
	return tr("GROVE_FX_SEEDS") % tree_name(int(sim.lv.seeds) + 1)

## Seconds are written 0,47 where the language writes them so (pt, es).
static func _decimal(text: String) -> String:
	return text if TranslationServer.get_locale().begins_with("en") else text.replace(".", ",")

## A tier's tree by name; the second time the looks come round it is
## "Birch II", then "Birch III" (the fonts carry no star).
func tree_name(tier: int) -> String:
	var lap: int = Sim.lap_of(tier)
	return tr("GROVE_TREE_%d" % Sim.look_of(tier)) + ("" if lap == 0 else " " + _roman(lap + 1))

static func _roman(n: int) -> String:
	var out := ""
	for pair: Array in [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"],
			[50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]:
		while n >= int(pair[0]):
			out += String(pair[1])
			n -= int(pair[0])
	return out

func _on_tile(tile: String) -> void:
	var button: Control = _tiles[tile].button
	var paid: int = sim.cost(tile)
	if sim.buy(tile):
		_fx.cue("buy")
		Motion.bump(button, 0.05, 0.2)
		Analytics.track("grove_upgrade", {"tile": tile, "level": int(sim.lv[tile]), "energy": paid})
		_refresh_tiles()
		_save()
	elif not sim.is_done(tile):
		_fx.cue("no")
		Motion.shiver(button, 6.0)

# --- the hand ---

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_hold = (event as InputEventMouseButton).pressed and not _held_back
		_hold_at = (event as InputEventMouseButton).position
	elif event is InputEventMouseMotion and _hold:
		_hold_at = (event as InputEventMouseMotion).position

# --- drawing ---

func _draw_field() -> void:
	if _ground == null:
		return
	field.draw_mesh(_ground, null)
	var standing: Array = sim.trees.duplicate()
	standing.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.y < b.pos.y)
	var now := Time.get_ticks_msec() / 1000.0
	for f: Dictionary in _falls:
		var tree: Dictionary = f.tree
		var k: float = f.t / FALL
		field.draw_mesh(Art.tree(Sim.look_of(tree.tier)), null,
			Transform2D(0.0 if Motion.reduce else float(f.dir) * k * k * 1.3, Vector2(_u, _u), 0.0, px(tree.pos)),
			Color(1.0, 1.0, 1.0, 1.0 - k * k))
	for tree: Dictionary in standing:
		var look: int = Sim.look_of(tree.tier)
		var grown := 1.0 if Motion.reduce else clampf((sim.clock - float(tree.born)) / Sim.GROW, 0.0, 1.0)
		var size := (0.15 + 0.85 * Motion.back_out(grown)) * _u
		var squash := 0.0
		if _hit.has(tree.id) and not Motion.reduce:
			squash = sin(float(_hit[tree.id]) / SQUASH * PI) * 0.16
		var sway := 0.0 if Motion.reduce else sin(now * 1.4 + float(tree.id)) * 0.02
		var at := px(tree.pos)
		field.draw_mesh(Art.tree(look), null, Transform2D(sway, Vector2(size * (1.0 + squash), size * (1.0 - squash)), 0.0, at))
		for i in Sim.lap_of(tree.tier):
			field.draw_circle(at + Vector2((i - (Sim.lap_of(tree.tier) - 1) * 0.5) * 18.0, -4.0) * _u, 7.0 * _u, Art.MARK, true, -1.0, true)
		var full: int = Sim.hp_of(tree.tier)
		if int(tree.hp) < full:
			var w := maxf(54.0, Sim.radius_of(tree.tier) * 1.6) * _u
			var bar := Rect2(at + Vector2(-w * 0.5, 12.0 * _u), Vector2(w, 12.0 * _u))
			field.draw_rect(bar, Color(0.23, 0.19, 0.16, 0.35))
			field.draw_rect(Rect2(bar.position, Vector2(maxf(4.0, w * float(tree.hp) / full), bar.size.y)), Color("fff6e6"))
	if _hold and not _held_back:
		var r: float = sim.reach() * _u
		var swell := 0.0 if Motion.reduce else maxf(0.0, 1.0 - _since_chop / SWELL)
		field.draw_circle(_hold_at, r, Color(1.0, 1.0, 1.0, 0.22 + swell * 0.2), true, -1.0, true)
		field.draw_arc(_hold_at, r + swell * 8.0, 0.0, TAU, 72, Color(0.23, 0.19, 0.16, 0.75), 5.0, true)
		field.draw_arc(_hold_at, r - 5.0, 0.0, TAU, 72, Color(1.0, 1.0, 1.0, 0.8), 3.0, true)
	var font := get_theme_font("font", "SheetTitle")
	for n: Dictionary in _nums:
		var k: float = n.t / NUM
		var fs := int((50.0 if n.gold else 40.0) * _u)
		var w := font.get_string_size(n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := px(n.at) + Vector2(-w * 0.5, 0.0 if Motion.reduce else -k * 56.0 * _u)
		var a := 1.0 - k * k * k
		field.draw_string_outline(font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.23, 0.19, 0.16, 0.7 * a))
		field.draw_string(font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Art.MARK if n.gold else Color.WHITE, a))

## Logs and sparks in the air, over everything, on their way to the plates.
func _draw_over() -> void:
	for f: Dictionary in _flies:
		if f.t <= 0.0:
			continue
		var k := clampf(f.t / FLIGHT, 0.0, 1.0)
		var at: Vector2 = (f.from as Vector2).lerp(f.to, k * k) + Vector2(0.0, -sin(k * PI) * 110.0)
		if f.kind == "wood":
			_over.draw_mesh(Art.log_mesh(), null, Transform2D(-0.3 + k * 4.0, Vector2(0.7, 0.7), 0.0, at))
		else:
			_over.draw_mesh(Art.spark(), null, Transform2D(k * 3.0, Vector2(0.9, 0.9), 0.0, at))

# --- leaving ---

func _save() -> void:
	if sim == null:
		return
	sim.save(Time.get_unix_time_from_system())
	Stock.flush()
	_dirty = false
	_since_save = 0.0

func _on_back() -> void:
	_save()
	Analytics.track("valley_leave", {"place": GAME, "seconds": int((Time.get_ticks_msec() - _opened_at) / 1000.0),
		"felled": sim.felled - _felled_at_open})
	closed.emit()

## Android's back, through the menu: a card or a sheet first, then the screen.
func go_back() -> void:
	if tutor.close():
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	_on_back()
