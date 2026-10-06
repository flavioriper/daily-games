extends Control

## Nightlight: the seventh game on the Arcade tab, and the one that is kept.
## A small star in the middle of a night sky; the player never moves and only
## throws meteors at it (press on the sky, drag the way it should go, let
## go). The star pulls as hard as it is heavy, bodies cross the sky on their
## own, and a caught one circles, closes in and turns faster and faster until
## the star has it. Mass grows the star, counted in Suns (a new star is
## one); it burns the hydrogen in what it eats and goes dim without any;
## light, which the haze makes of whatever it drags and the star of what it
## burns, buys the hand's four tiles; as it grows it is offered two powers
## and one is picked; at 100 Suns it can go supernova, which gives
## everything back to the sky, leaves a small star among the ashes and pays
## stardust for a perk that lasts (the user's design, 2026-10-06). Spec
## docs/superpowers/specs/2026-10-06-arcade-nightlight-design.md; the rules
## and every number are arcade/nightlight_sim.gd's, the sky is
## arcade/nightlight_sky.gd's, the drawings nightlight_art.gd's.
##
## Like the Grove it has no round, no score and no end, so none of the
## Arcade's end card, record, boosters or Second chance: the star is read
## from its file as the screen opens, exactly as it was left (nothing
## happens while the game is closed), and written back as tiles are bought,
## every few seconds while it eats, and as it is left. ui/menu.gd mounts it
## over the list (`_open_arcade`) and it joins the `versus_host` group so
## Android's back reaches it.

signal closed

const Sim = preload("res://arcade/nightlight_sim.gd")
const Art = preload("res://arcade/nightlight_art.gd")
const NightSky = preload("res://arcade/nightlight_sky.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const ScreenTutor = preload("res://ui/hud/screen_tutor.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Analytics = preload("res://core/analytics.gd")
const Motes = preload("res://ui/motes.gd")

const GAME := "nightlight"
const MARGIN := 40
const GAP := 20
const HUD_H := 96.0
const NOVA_H := 44.0
const INFO_H := 104.0
const SHOP_W := 330.0
const DUST_W := 190.0
## The shop's card and a tile of it, as the Grove's are: its picture on a
## disc, its name over what the next level does, its price on a bar.
const CARD_W := 1000.0
const CARD_INSET := 26
const X_SIZE := 84.0
const TILE_H := 344.0
const TILE_PAD := 14.0
const TILE_GAP := 16
const DISC_R := 60.0
const PRICE_H := 64.0
const PRICE_R := 20
const PRICE_OFF := Color("ede4d3")
const FILL := Color("fcf7ef")
## The star stands a little above the field's middle.
const STAR_AT := 0.47
## A throw: under SLACK pixels of drag (the design's) it is a tap and the
## meteor is let go where it is; FULL of them is the speed of a circle at
## the bare haze's edge, whatever the star weighs, so the hand learns one
## gesture; past MOST a longer drag is no faster.
const SLACK := 24.0
const FULL := 200.0
const MOST := 520.0
## No throw starts this near the star, in its own radii.
const CLEAR := 1.2
## Light is motes, the other games' energy in gold: `ORBS` to one light.
const ORBS := 4
## The supernova: seconds the star swells into a light that takes the sky,
## and seconds that light takes to thin over the new one. Both FADE under
## reduce motion, with no swelling.
const SWELL := 0.8
const THIN := 1.1
const FADE := 0.3
const SAVE_GAP := 5.0
## A throw is a piece set down; a tile bought is something finished; one
## that cannot be is a not yet; the supernova is the heaviest thing here.
const HAPTICS := {"throw": Haptics.TAP, "buy": Haptics.BUMP, "perk": Haptics.BUMP, "no": Haptics.WARN, "nova": Haptics.THUD}
const TILE_NAMES := {"meteor": "NL_METEOR", "volley": "NL_VOLLEY", "stream": "NL_STREAM", "ice": "NL_ICE"}
const POWER_NAMES := {"wind": "NL_POW_WIND", "haze": "NL_POW_HAZE", "beacon": "NL_POW_BEACON", "radiance": "NL_POW_RADIANCE",
	"furnace": "NL_POW_FURNACE", "fusion": "NL_POW_FUSION", "thrift": "NL_POW_THRIFT"}
const MADE_NAMES := ["NL_HYDROGEN", "NL_HELIUM", "NL_ROCK"]
## The light's plate, beside the shop that spends it.
const LIGHT_W := 250.0
## What the star is made of: its bar's height.
const MADE_H := 14.0
## A pick's tile, and the seconds the star has grown past a pick before the
## card comes up over a throw.
const PICK_H := 440.0
const PICK_WAIT := 0.6
## A power held, on a disc in the sky's corner.
const CHIP := 68.0
const CHIP_GAP := 10.0
## Under the stream a throw is felt this often at most, in seconds.
const FELT := 0.2
## The fuel's clock reddens under this many seconds.
const LOW := 10.0
const PERK_NAMES := {"core": "NL_PERK_CORE", "disc": "NL_PERK_DISC", "hand": "NL_PERK_HAND", "crowd": "NL_PERK_CROWD",
	"ember": "NL_PERK_EMBER"}

var sim: RefCounted
var top_bar: Control
var settings_sheet: Control
var tutor: RefCounted
var sky: Control
var _fx: Node2D
var _motes: Control
var _margins: MarginContainer
var _plates := {}   # "light" -> {panel, icon, label}
var _cells := {}    # "mass" / "temp" / "fuel" -> Label
var _made: Control
var _made_l: Array[Label] = []
var _fuel_low := false
var _hint: Label
var _chips: Button
var _chips_for := ""
var _pick: Control
var _pick_title: Label
var _pick_tiles: Array = []   # {button, icon, name, effect, cost, badge, level}
var _pick_now: Array = []
var _pick_wait := 0.0
var _powers: Control
var _powers_list: VBoxContainer
var _stream_t := 0.0
var _streamed := false
var _felt_at := -1000
var _shown := {"mass": 0.0, "light": 0.0}
var _bump := {}
var _dust_b: Button
var _dust_l: Label
var _nova_line: Control
var _nova_l: Label
var _nova_b: Button
var _shop_b: Button
var _shop: Control
var _shop_light: Label
var _tiles := {}    # tile -> {button, icon, effect, pill, cost, mote, tick, badge, level}
var _tiles_for := ""
var _ask: Control
var _ask_body: Label
var _perks: Control
var _perk_dust: Label
var _perk_buy: Button
var _perk_tiles := {}   # perk -> {panel, count}
var _aiming := false
var _finger := -1
var _aim_from := Vector2.ZERO
var _aim_to := Vector2.ZERO
var _held_back := false
var _nova_t := -1.0
var _nova_done := false
var _dirty := false
var _since_save := 0.0
var _opened_at := 0
var _eaten_at_open := 0.0

func puzzle_id() -> String:
	return GAME

func _ready() -> void:
	add_to_group("versus_host")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	sim = Sim.load_saved()
	_opened_at = Time.get_ticks_msec()
	_eaten_at_open = sim.eaten
	_shown.mass = sim.mass
	_shown.light = sim.light
	_build()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	tutor = ScreenTutor.new(self, puzzle_id(), "Nightlight", _tutor_hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	top_bar.refresh(self)
	_refresh_tiles()
	_refresh_hud(0.0)
	Analytics.track("nightlight_enter", {"mass": int(sim.mass), "novas": sim.novas})

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_aiming = false
		_finger = -1
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

	top_bar = FlatTopBar.new("Nightlight", tr("NL_MOTTO"), false)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.settings.connect(func() -> void:
		_aiming = false
		settings_sheet.open())
	col.add_child(top_bar)

	col.add_child(_star_panel())

	# the way to the next power and to the supernova: a bar, and what it
	# would pay
	_nova_line = Control.new()
	_nova_line.name = "NovaLine"
	_nova_line.custom_minimum_size.y = NOVA_H
	_nova_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nova_line.draw.connect(_draw_nova_line)
	_nova_l = Label.new()
	_nova_l.theme_type_variation = "CardBlurb"
	_nova_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_nova_l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_nova_line.add_child(_nova_l)
	col.add_child(_nova_line)

	sky = NightSky.new()
	sky.name = "Field"
	sky.sim = sim
	sky.paper = Pal.PAPER
	sky.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sky.mouse_filter = Control.MOUSE_FILTER_STOP
	sky.gui_input.connect(_on_field_input)
	sky.resized.connect(_layout_field)
	col.add_child(sky)
	# on the left, clear of the thumb that throws
	_nova_b = IconButton.new("sparkle", tr("NL_NOVA"), "PrimaryButton")
	_nova_b.name = "Nova"
	_nova_b.custom_minimum_size = Vector2(400, 104)
	_nova_b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_nova_b.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_nova_b.offset_left = 28.0
	_nova_b.offset_bottom = -28.0
	_nova_b.visible = false
	_nova_b.pressed.connect(open_ask)
	sky.add_child(_nova_b)
	# the powers held, down the sky's left edge: pressed, they say what they do
	_chips = Button.new()
	_chips.name = "Powers"
	_chips.focus_mode = Control.FOCUS_NONE
	_chips.position = Vector2(22.0, 22.0)
	_chips.visible = false
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		_chips.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_chips.draw.connect(_draw_chips)
	_chips.pressed.connect(open_powers)
	sky.add_child(_chips)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	sky.add_child(_fx)

	var info := HBoxContainer.new()
	info.name = "Info"
	info.custom_minimum_size.y = INFO_H
	info.add_theme_constant_override("separation", TILE_GAP)
	_shop_b = IconButton.new("trend", tr("SHOP_TITLE"), "PrimaryButton")
	_shop_b.name = "Shop"
	_shop_b.custom_minimum_size = Vector2(SHOP_W, INFO_H)
	_shop_b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_shop_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shop_b.pressed.connect(open_shop)
	info.add_child(_shop_b)
	var light := _plate("light", "NL_LIGHT")
	light.custom_minimum_size = Vector2(LIGHT_W, HUD_H)
	light.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	light.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(light)
	info.add_child(_dust_plate())
	var hint := Label.new()
	hint.text = "NL_HINT"
	hint.theme_type_variation = "CardBlurb"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(hint)
	_hint = hint
	col.add_child(info)

	_motes = Motes.new()
	_motes.orb_mesh = Art.orb()
	_motes.light_mesh = Art.orb_light()
	_motes.target = _plates.light.icon
	_motes.landed.connect(_on_motes_landed)
	add_child(_motes)
	_shop = _build_shop()
	add_child(_shop)
	_ask = _build_ask()
	add_child(_ask)
	_perks = _build_perks()
	add_child(_perks)
	_powers = _build_powers()
	add_child(_powers)
	_pick = _build_pick()
	add_child(_pick)
	_apply_insets()

## The star, on a paper plate: how many Suns it weighs, how hot it is and how
## long its hydrogen lasts, and under them what it is made of on a bar, with
## each share named (the user, 2026-10-06: "show mass compared to the sun
## ... show also temperature, composition and how much fuel it has to burn").
func _star_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Star"
	panel.add_theme_stylebox_override("panel", CozyTheme.lifted(FILL, 30, 8))
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 18)
	inset.add_theme_constant_override("margin_right", 18)
	inset.add_theme_constant_override("margin_top", 2)
	inset.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(inset)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	inset.add_child(col)
	var row := HBoxContainer.new()
	col.add_child(row)
	for cell: Array in [["mass", "NL_MASS"], ["temp", "NL_TEMP"], ["fuel", "NL_FUEL"]]:
		var words := VBoxContainer.new()
		words.name = String(cell[0]).capitalize()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", -8)
		row.add_child(words)
		var kicker := Label.new()
		kicker.text = cell[1]
		kicker.theme_type_variation = "MenuKicker"
		kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.add_child(kicker)
		var value := Label.new()
		value.name = "Value"
		value.theme_type_variation = "SheetTitle"
		value.add_theme_font_size_override("font_size", 46)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.add_child(value)
		_cells[cell[0]] = value
	_made = Control.new()
	_made.name = "Made"
	_made.custom_minimum_size.y = MADE_H
	_made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_made.draw.connect(_draw_made)
	col.add_child(_made)
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 30)
	col.add_child(legend)
	for i in 3:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 8)
		legend.add_child(item)
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var box := StyleBoxFlat.new()
		box.bg_color = Art.MADE[i]
		box.set_corner_radius_all(8)
		dot.add_theme_stylebox_override("panel", box)
		item.add_child(dot)
		var share := Label.new()
		share.theme_type_variation = "CardBlurb"
		share.add_theme_font_size_override("font_size", 22)
		item.add_child(share)
		_made_l.append(share)
	return panel

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
	var icon := _picture(what, 72.0, 0.85)
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

## The stardust held, once there has been a supernova: pressed, it opens the
## perks.
func _dust_plate() -> Control:
	_dust_b = Button.new()
	_dust_b.name = "Dust"
	_dust_b.focus_mode = Control.FOCUS_NONE
	_dust_b.custom_minimum_size = Vector2(DUST_W, HUD_H)
	_dust_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dust_b.visible = false
	CozyTheme.lift_button(_dust_b, FILL, 30, 8)
	_dust_b.pressed.connect(open_perks)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dust_b.add_child(row)
	row.add_child(_picture("dust", 60.0))
	_dust_l = Label.new()
	_dust_l.theme_type_variation = "SheetTitle"
	row.add_child(_dust_l)
	return _dust_b

## One of Art's pictures in a box `side` square, Art.R of it drawn `fill` of
## the box's side.
func _picture(what: String, side: float, fill := 0.5) -> Control:
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(side, side)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		var s := side * fill / Art.R
		icon.draw_mesh(Art.icon(what), null, Transform2D(0.0, Vector2(s, s), 0.0, icon.size * 0.5)))
	return icon

## A dialog's scrim with its card in the middle; a touch outside the card
## calls `out`.
func _dialog(called: String, width: float, out: Callable) -> Array:
	var scrim := Dialog.scrim()
	scrim.name = called
	scrim.visible = false
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
			out.call())
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	var card := Dialog.card(width, CARD_INSET)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	card.add_child(col)
	return [scrim, col]

## What a dialog's head carries at its right: something held, on a pill.
func _held_pill(what: String, label: Label) -> Control:
	var pill := PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 14))
	var held := HBoxContainer.new()
	held.add_theme_constant_override("separation", 10)
	pill.add_child(held)
	held.add_child(_picture(what, 46.0))
	label.theme_type_variation = "SheetTitle"
	held.add_child(label)
	return pill

## The shop: the hand's four tiles on a card over the sky, the light held on
## a pill at its head and an X beside it. The sky goes on behind it.
func _build_shop() -> Control:
	var made := _dialog("Shop", CARD_W, close_shop)
	var col: VBoxContainer = made[1]
	var trailing := HBoxContainer.new()
	trailing.add_theme_constant_override("separation", 16)
	_shop_light = Label.new()
	_shop_light.name = "Light"
	trailing.add_child(_held_pill("light", _shop_light))
	var x := IconButton.new("cross", "", "IconButton")
	x.name = "Close"
	x.custom_minimum_size = Vector2(X_SIZE, X_SIZE)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var r := int(X_SIZE * 0.5)
	var up := CozyTheme.soft_button(Pal.SURFACE, r, false, 0)
	var down := CozyTheme.soft_button(Pal.SURFACE, r, true, 0)
	for st in ["normal", "hover", "disabled"]:
		x.add_theme_stylebox_override(st, up)
	x.add_theme_stylebox_override("pressed", down)
	x.pressed.connect(close_shop)
	trailing.add_child(x)
	col.add_child(Dialog.head("SHOP_TITLE", "trend", trailing))
	var grid := GridContainer.new()
	grid.name = "Tiles"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	for tile: String in Sim.TILES:
		grid.add_child(_tile(tile))
	col.add_child(grid)
	return made[0]

func open_shop() -> void:
	if _shop.visible or _nova_t >= 0.0:
		return
	_aiming = false
	_refresh_tiles()
	_shop.visible = true
	Motion.appear(_shop, 0.0, 1.0, 0.2)

func close_shop() -> void:
	_shop.visible = false

## One of the four, on the shop's card: its picture on a piece of the night,
## its name, what the next level does, and the light it asks on a bar along
## its foot. A tile that cannot be bought yet is still pressed: it shakes
## its head.
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
	col.offset_top = 22.0
	col.offset_bottom = -TILE_PAD - 2.0
	col.offset_left = TILE_PAD
	col.offset_right = -TILE_PAD
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(0, DISC_R * 2.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		var c := icon.size * 0.5
		icon.draw_circle(c, DISC_R, Art.SKY[1], true, -1.0, true)
		var s := DISC_R * 0.78 / Art.R
		icon.draw_mesh(Art.icon(tile), null, Transform2D(0.0, Vector2(s, s), 0.0, c)))
	col.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -4)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(words)
	var name_l := Label.new()
	name_l.text = TILE_NAMES[tile]
	name_l.theme_type_variation = "CardTitle"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	words.add_child(name_l)
	var effect := Label.new()
	effect.theme_type_variation = "CardBlurb"
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.clip_text = true
	effect.add_theme_font_size_override("font_size", 24)
	words.add_child(effect)
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.custom_minimum_size.y = PRICE_H
	col.add_child(pill)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var mote := _picture("light", 38.0)
	row.add_child(mote)
	# a tile with no level left wears a tick where its price was
	var tick := Control.new()
	tick.custom_minimum_size = Vector2(34, 34)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick.draw.connect(func() -> void:
		Icons.paint(tick, "check", Rect2(Vector2.ZERO, tick.size), Pal.LEAF_DEEP))
	row.add_child(tick)
	var cost := Label.new()
	cost.theme_type_variation = "CardTitle"
	cost.add_theme_font_size_override("font_size", 38)
	row.add_child(cost)
	# the level, on the tile's corner once there is one
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_top = 12.0
	badge.offset_right = -12.0
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
		"mote": mote, "tick": tick, "badge": badge, "level": level}
	return b

## Before the supernova: what goes and what it pays, and a way back. It takes
## the tiles with it, so it is never one touch.
func _build_ask() -> Control:
	var made := _dialog("Ask", 860.0, close_ask)
	var col: VBoxContainer = made[1]
	col.add_child(Dialog.head("NL_NOVA", "sparkle"))
	_ask_body = Label.new()
	_ask_body.theme_type_variation = "CardBlurb"
	_ask_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ask_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_ask_body)
	var go := Dialog.primary("sparkle", tr("NL_NOVA_GO"))
	go.name = "Go"
	go.pressed.connect(_go_nova)
	var stay := Dialog.secondary("chevron_left", tr("NL_NOVA_STAY"))
	stay.name = "Stay"
	stay.pressed.connect(close_ask)
	Dialog.buttons(col, go, stay)
	return made[0]

func open_ask() -> void:
	if _ask.visible or _nova_t >= 0.0 or not sim.can_nova():
		return
	_aiming = false
	_ask_body.text = _count("NL_NOVA_ASK", sim.dust_for())
	_ask.visible = true
	Motion.appear(_ask, 0.0, 1.0, 0.2)

func close_ask() -> void:
	_ask.visible = false

## The perks: the stardust held, the five with how many of each there are,
## and a button that draws one at random for what the next costs.
func _build_perks() -> Control:
	var made := _dialog("Perks", CARD_W, close_perks)
	var col: VBoxContainer = made[1]
	_perk_dust = Label.new()
	_perk_dust.name = "Dust"
	col.add_child(Dialog.head("NL_PERKS", "sparkle", _held_pill("dust", _perk_dust)))
	var body := Label.new()
	body.text = "NL_PERKS_BODY"
	body.theme_type_variation = "CardBlurb"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	var grid := GridContainer.new()
	grid.name = "Perks"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	for which: String in Sim.PERKS:
		grid.add_child(_perk_tile(which))
	col.add_child(grid)
	_perk_buy = Dialog.primary("sparkle", "")
	_perk_buy.name = "Buy"
	_perk_buy.pressed.connect(_on_perk)
	var back := Dialog.secondary("chevron_left", tr("NL_PERKS_BACK"))
	back.name = "Back"
	back.pressed.connect(close_perks)
	Dialog.buttons(col, _perk_buy, back)
	return made[0]

func _perk_tile(which: String) -> Control:
	var panel := PanelContainer.new()
	panel.name = which.capitalize()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 18))
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", -4)
	row.add_child(words)
	var name_l := Label.new()
	name_l.text = PERK_NAMES[which]
	name_l.theme_type_variation = "CardTitle"
	name_l.clip_text = true
	words.add_child(name_l)
	var effect := Label.new()
	effect.text = PERK_NAMES[which] + "_FX"
	effect.theme_type_variation = "CardBlurb"
	effect.add_theme_font_size_override("font_size", 24)
	effect.clip_text = true
	words.add_child(effect)
	var count := Label.new()
	count.theme_type_variation = "CardTitle"
	count.add_theme_color_override("font_color", Pal.SUN_DEEP)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)
	_perk_tiles[which] = {"panel": panel, "count": count}
	return panel

func open_perks() -> void:
	if _perks.visible or _nova_t >= 0.0:
		return
	_aiming = false
	_refresh_perks()
	_perks.visible = true
	Motion.appear(_perks, 0.0, 1.0, 0.2)

func close_perks() -> void:
	_perks.visible = false

func _refresh_perks() -> void:
	_perk_dust.text = str(sim.dust)
	for which: String in Sim.PERKS:
		var n := int(sim.perk[which])
		(_perk_tiles[which].count as Label).text = "×%d" % n if n > 0 else ""
		(_perk_tiles[which].panel as Control).modulate.a = 1.0 if n > 0 else 0.5
	(_perk_buy as IconButton).set_label(_count("NL_PERK_BUY", sim.perk_cost()))
	(_perk_buy as IconButton).set_enabled(sim.dust >= sim.perk_cost())

func _on_perk() -> void:
	var which: String = sim.buy_perk()
	if which == "":
		_fx.cue("no")
		Motion.shiver(_perk_buy, 6.0)
		return
	_fx.cue("perk")
	_refresh_perks()
	Motion.bump(_perk_tiles[which].panel, 0.06, 0.24)
	Analytics.track("nightlight_perk", {"perk": which, "count": int(sim.perk[which]), "dust": sim.perk_cost() - 1})
	_save()

## A pick: the star has grown past one of Sim.MILES and offers two powers
## that go different ways. One is taken; the card has no way out but that,
## and the sky waits behind it. A power already held says its level.
func _build_pick() -> Control:
	var made := _dialog("Pick", CARD_W, func() -> void: pass)
	var col: VBoxContainer = made[1]
	var head := Dialog.head("", "sparkle")
	_pick_title = head.get_child(1) as Label
	col.add_child(head)
	var body := Label.new()
	body.text = "NL_PICK_BODY"
	body.theme_type_variation = "CardBlurb"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	var two := HBoxContainer.new()
	two.name = "Two"
	two.add_theme_constant_override("separation", TILE_GAP)
	col.add_child(two)
	for i in 2:
		two.add_child(_pick_tile(i))
	return made[0]

func _pick_tile(i: int) -> Control:
	var b := Button.new()
	b.name = "Pick%d" % i
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = PICK_H
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CozyTheme.lift_button(b, FILL, 30, 8)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.pressed.connect(_on_pick.bind(i))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 26.0
	col.offset_bottom = -TILE_PAD - 2.0
	col.offset_left = TILE_PAD + 6.0
	col.offset_right = -TILE_PAD - 6.0
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(0, 168.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		if i >= _pick_now.size():
			return
		var c := icon.size * 0.5
		icon.draw_circle(c, 84.0, Art.SKY[1], true, -1.0, true)
		var s := 84.0 * 0.78 / Art.R
		icon.draw_mesh(Art.icon(_pick_now[i]), null, Transform2D(0.0, Vector2(s, s), 0.0, c)))
	col.add_child(icon)
	var name_l := Label.new()
	name_l.theme_type_variation = "CardTitle"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	col.add_child(name_l)
	var effect := Label.new()
	effect.theme_type_variation = "CardBlurb"
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(effect)
	# what it costs: the hydrogen it burns, on the bar a price would be on
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.custom_minimum_size.y = PRICE_H
	var box := StyleBoxFlat.new()
	box.bg_color = Pal.SUN
	box.set_corner_radius_all(PRICE_R)
	box.border_width_bottom = 5
	box.border_color = Pal.SUN_DEEP
	pill.add_theme_stylebox_override("panel", box)
	col.add_child(pill)
	var cost := Label.new()
	cost.theme_type_variation = "CardTitle"
	cost.add_theme_font_size_override("font_size", 30)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.add_child(cost)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_top = 12.0
	badge.offset_right = -12.0
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
	_pick_tiles.append({"button": b, "icon": icon, "name": name_l, "effect": effect, "cost": cost, "badge": badge, "level": level})
	return b

## What a power burns, in its own words.
func _burns(which: String) -> String:
	if which == "thrift":
		return tr("NL_POW_SAVE")
	return tr("NL_POW_BURN") % int(round(float(Sim.COST[which]) * 100.0))

func open_pick() -> void:
	var two: Array = sim.offering()
	if two.is_empty() or _pick.visible:
		return
	_aiming = false
	_finger = -1
	_pick_now = two
	_pick_title.text = tr("NL_PICK_TITLE") % Art.short(Sim.mile(sim.picks), _comma())
	for i in 2:
		var t: Dictionary = _pick_tiles[i]
		var which: String = two[i]
		var held := int(sim.power[which])
		(t.name as Label).text = POWER_NAMES[which]
		(t.effect as Label).text = POWER_NAMES[which] + "_FX"
		(t.cost as Label).text = _burns(which)
		(t.badge as Control).visible = held > 0
		(t.level as Label).text = str(held)
		(t.icon as Control).queue_redraw()
	_pick.visible = true
	Motion.appear(_pick, 0.0, 1.0, 0.2)

func _on_pick(i: int) -> void:
	var which: String = sim.pick(i)
	if which == "":
		_pick.visible = false
		return
	_fx.cue("perk")
	Analytics.track("nightlight_power", {"power": which, "level": int(sim.power[which]), "suns": int(Sim.mile(sim.picks - 1))})
	_pick.visible = false
	_pick_wait = 0.0
	_save()

## The powers held: what each does, how many times it was picked and what it
## burns.
func _build_powers() -> Control:
	var made := _dialog("PowersCard", CARD_W, close_powers)
	var col: VBoxContainer = made[1]
	col.add_child(Dialog.head("NL_POWERS", "sparkle"))
	var body := Label.new()
	body.text = "NL_POWERS_BODY"
	body.theme_type_variation = "CardBlurb"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	_powers_list = VBoxContainer.new()
	_powers_list.name = "List"
	_powers_list.add_theme_constant_override("separation", 12)
	col.add_child(_powers_list)
	var back := Dialog.secondary("chevron_left", tr("NL_PERKS_BACK"))
	back.name = "Back"
	back.pressed.connect(close_powers)
	Dialog.buttons(col, back)
	return made[0]

func open_powers() -> void:
	if _powers.visible or _nova_t >= 0.0:
		return
	_aiming = false
	for old in _powers_list.get_children():
		_powers_list.remove_child(old)
		old.queue_free()
	for which: String in Sim.POWERS:
		var held := int(sim.power[which])
		if held <= 0:
			continue
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 14))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		panel.add_child(row)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(72, 72)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.draw.connect(func() -> void:
			icon.draw_circle(icon.size * 0.5, 36.0, Art.SKY[1], true, -1.0, true)
			var s := 36.0 * 0.78 / Art.R
			icon.draw_mesh(Art.icon(which), null, Transform2D(0.0, Vector2(s, s), 0.0, icon.size * 0.5)))
		row.add_child(icon)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", -4)
		row.add_child(words)
		var name_l := Label.new()
		name_l.text = POWER_NAMES[which]
		name_l.theme_type_variation = "CardTitle"
		words.add_child(name_l)
		var effect := Label.new()
		effect.text = "%s %s" % [tr(POWER_NAMES[which] + "_FX"), tr("NL_POW_EACH") % _burns(which)]
		effect.theme_type_variation = "CardBlurb"
		effect.add_theme_font_size_override("font_size", 24)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(effect)
		var count := Label.new()
		count.text = "×%d" % held
		count.theme_type_variation = "CardTitle"
		count.add_theme_color_override("font_color", Pal.SUN_DEEP)
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(count)
		_powers_list.add_child(panel)
	_powers.visible = true
	Motion.appear(_powers, 0.0, 1.0, 0.2)

func close_powers() -> void:
	_powers.visible = false

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))

## The sky is drawn in the design's pixels, 1080 to the screen's width, with
## the star a little above the field's middle.
func _layout_field() -> void:
	sky.u = size.x / 1080.0 if size.x > 0.0 else 1.0
	sky.centre = Vector2(sky.size.x * 0.5, sky.size.y * STAR_AT)

# --- what the top bar and the tutorial ask ---

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/nightlight_tutorial_diagram.gd")
	var pages := []
	for step: Array in [
			[Diagram.Lesson.THROW, "TUT_NL_THROW", tr("TUT_NL_THROW_BODY")],
			[Diagram.Lesson.LIGHT, "TUT_NL_LIGHT", tr("TUT_NL_LIGHT_BODY")],
			[Diagram.Lesson.FUEL, "TUT_NL_STAR", tr("TUT_NL_STAR_BODY")],
			[Diagram.Lesson.NOVA, "TUT_NL_NOVA", tr("TUT_NL_NOVA_BODY") % Art.short(Sim.NOVA / Sim.START, _comma())]]:
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

## A card over the screen (the tutorial): the sky waits, and no throw.
func _tutor_hold(on: bool) -> void:
	_held_back = on
	if on:
		_aiming = false

# --- time ---

func _process(delta: float) -> void:
	if sim == null:
		return
	var waits: bool = _held_back or settings_sheet.is_open() or _pick.visible or (_nova_t >= 0.0 and not _nova_done)
	if not waits:
		_stream(delta)
		sim.advance(delta)
	_play_events()
	_offer(delta)
	_step_nova(delta)
	sky.aim = _aim()
	sky.refresh(0.0 if waits else delta)
	_refresh_hud(delta)
	_nova_line.queue_redraw()
	if _dirty:
		_since_save += delta
		if _since_save >= SAVE_GAP:
			_save()

## With Stream, meteors keep leaving while the finger is down, the way it is
## dragged now.
func _stream(delta: float) -> void:
	var gap: float = sim.stream_gap()
	if not _aiming or gap <= 0.0:
		return
	_stream_t += delta
	if _stream_t >= gap:
		_stream_t = 0.0
		_streamed = true
		_throw()

## A pick the star has grown past comes up by itself, a moment later and
## never over another card.
func _offer(delta: float) -> void:
	if sim.owed() <= 0 or _pick.visible:
		_pick_wait = 0.0
		# a card with nothing left to offer is not left up
		if _pick.visible and sim.owed() <= 0:
			_pick.visible = false
		return
	if _held_back or _nova_t >= 0.0 or settings_sheet.is_open() or _shop.visible or _ask.visible or _perks.visible or _powers.visible:
		return
	_pick_wait += delta
	if _pick_wait >= PICK_WAIT:
		open_pick()

func _play_events() -> void:
	var origin: Transform2D = sky.get_global_transform()
	for e: Dictionary in sim.events:
		match String(e.kind):
			"eat":
				sky.ate(float(e.m))
				_dirty = true
			"shed":
				_motes.drop(origin * sky.px(e.at), float(e.e) * ORBS, 1)
			"merge":
				sky.met(e.at)
			"tear":
				sky.tore(e.at, float(e.m))
			"shine":
				# the star's own light, off its own face
				_motes.drop(origin * sky.centre, float(e.e) * ORBS, 1)
				_dirty = true
	sim.events.clear()
	if _tiles_for != _tiles_key():
		_refresh_tiles()

## The star swells into a warm light that takes the whole sky; under it the
## sim gives everything back and a small star is left among the ashes; the
## light thins, and the perks are offered.
func _step_nova(delta: float) -> void:
	if _nova_t < 0.0:
		return
	_nova_t += delta
	var up := FADE if Motion.reduce else SWELL
	var down := FADE if Motion.reduce else THIN
	if not _nova_done:
		var k := minf(1.0, _nova_t / up)
		sky.swell = 0.0 if Motion.reduce else k
		sky.veil = k * k
		if k >= 1.0:
			var was := int(sim.mass)
			var paid: int = sim.nova()
			_nova_done = true
			sky.swell = 0.0
			_motes.clear()
			_shown.mass = sim.mass
			_shown.light = 0.0
			Analytics.track("nightlight_nova", {"n": sim.novas, "mass": was, "dust": paid})
			_refresh_tiles()
			_save()
	else:
		var k := (_nova_t - up) / down
		sky.veil = maxf(0.0, 1.0 - k)
		if k >= 1.0:
			_nova_t = -1.0
			open_perks()

func _go_nova() -> void:
	close_ask()
	if not sim.can_nova() or _nova_t >= 0.0:
		return
	_aiming = false
	_nova_t = 0.0
	_nova_done = false
	_fx.cue("nova")

## Motes came down on the light plate: it swells, unless it still is from
## the one before.
func _on_motes_landed(_n: int, _note: int) -> void:
	if (_plates.light.panel as Control).scale.x <= 1.01:
		_kick("light")

## A plate swells as something lands on it. Each kick ends the last, or
## landings a moment apart would leave it stuck big (ui/menu/gold_pill.gd).
func _kick(kind: String) -> void:
	var panel: Control = _plates[kind].panel
	Motion.stop(_bump.get(kind))
	panel.scale = Vector2.ONE
	_bump[kind] = Motion.bump(panel, 0.06, 0.18)

func _refresh_hud(delta: float) -> void:
	# the light plate counts what has landed, not what is still in the air
	var want := {"mass": sim.mass, "light": maxf(0.0, sim.light - _motes.due / ORBS)}
	for kind: String in want:
		var held: float = want[kind]
		var s: float = _shown[kind]
		if Motion.reduce or delta <= 0.0 or absf(held - s) < 0.06:
			s = held
		else:
			s = lerpf(s, held, minf(1.0, delta * 10.0))
		_shown[kind] = s
	var c := _comma()
	(_cells.mass as Label).text = Art.short(_shown.mass / Sim.START, c) + "×"
	(_cells.temp as Label).text = _kelvin(sim.temp())
	var fuel_l: Label = _cells.fuel
	var lasts: float = sim.fuel_time()
	fuel_l.text = _clock(lasts) if sim.awake else tr("NL_FUEL_OUT")
	var low: bool = not sim.awake or lasts < LOW
	if low != _fuel_low:
		_fuel_low = low
		if low:
			fuel_l.add_theme_color_override("font_color", Pal.HEART)
		else:
			fuel_l.remove_theme_color_override("font_color")
	var h := int(round(100.0 * sim.fuel / sim.mass))
	var he := mini(100 - h, int(round(100.0 * sim.spent / sim.mass)))
	var shares := [h, he, 100 - h - he]
	for i in 3:
		_made_l[i].text = "%s %d%%" % [tr(MADE_NAMES[i]), shares[i]]
	_made.queue_redraw()
	_refresh_chips()
	(_plates.light.label as Label).text = Art.short(floorf(_shown.light), c)
	_shop_light.text = Art.short(floorf(sim.light), _comma())
	_dust_b.visible = sim.novas > 0 or sim.dust > 0
	# with stardust on the row there is no room for the hint, and whoever has
	# been through a supernova has thrown a meteor
	_hint.visible = not _dust_b.visible
	_dust_l.text = str(sim.dust)
	var ready: bool = sim.can_nova() and _nova_t < 0.0
	_nova_b.visible = ready
	if ready:
		_nova_l.text = tr("NL_NOVA_READY") % [sim.dust_for(), sim.dust_for() + 1, Art.short(sim.next_dust_mass() / Sim.START, c), Art.short(sim.next_pick(), c)]
	else:
		_nova_l.text = tr("NL_NOVA_AT") % [Art.short(sim.next_pick(), c), Art.short(Sim.NOVA / Sim.START, c)]

## Kelvin, to the nearest ten (a hundred past ten thousand), with the
## language's own mark between the thousands.
func _kelvin(v: float) -> String:
	var k := int(round(v / 100.0)) * 100 if v >= 10000.0 else int(round(v / 10.0)) * 10
	var text := str(k)
	if k >= 1000:
		text = "%d%s%03d" % [k / 1000, "." if _comma() else ",", k % 1000]
	return text + " K"

## Seconds as minutes and seconds: 7:48, and no more than 99:59.
func _clock(seconds: float) -> String:
	var t := mini(int(seconds), 99 * 60 + 59)
	return "%d:%02d" % [t / 60, t % 60]

## The discs of the powers held are drawn again only when one changes.
func _refresh_chips() -> void:
	var key := "y" if sim.awake else "n"
	var held := 0
	for which: String in Sim.POWERS:
		key += str(int(sim.power[which]))
		if int(sim.power[which]) > 0:
			held += 1
	if key == _chips_for:
		return
	_chips_for = key
	_chips.visible = held > 0
	_chips.size = Vector2(CHIP, held * (CHIP + CHIP_GAP))
	_chips.queue_redraw()

## A disc for each power held, its level on it past the first; all of them
## faint while the star is dim and they sleep.
func _draw_chips() -> void:
	var font := get_theme_font("font", "Badge")
	var faint := 1.0 if sim.awake else 0.4
	var y := 0.0
	for which: String in Sim.POWERS:
		var held := int(sim.power[which])
		if held <= 0:
			continue
		var c := Vector2(CHIP * 0.5, y + CHIP * 0.5)
		_chips.draw_circle(c, CHIP * 0.5, Color(Pal.PAPER, 0.85 * faint), true, -1.0, true)
		_chips.draw_circle(c, CHIP * 0.5 - 4.0, Color(Art.SKY[1], faint), true, -1.0, true)
		var s := (CHIP * 0.5 - 4.0) * 0.8 / Art.R
		_chips.draw_mesh(Art.icon(which), null, Transform2D(0.0, Vector2(s, s), 0.0, c), Color(1, 1, 1, faint))
		if held > 1:
			var at := c + Vector2(CHIP * 0.3, CHIP * 0.3)
			_chips.draw_circle(at, 15.0, Color(Pal.ACCENT, faint), true, -1.0, true)
			_chips.draw_string(font, at + Vector2(-15.0, 8.0), str(held), HORIZONTAL_ALIGNMENT_CENTER, 30.0, 22, Color(Pal.SURFACE, faint))
		y += CHIP + CHIP_GAP

# --- the tiles ---

func _tiles_key() -> String:
	var key := ""
	for tile: String in Sim.TILES:
		key += "%d%s" % [int(sim.lv[tile]), "y" if sim.can_buy(tile) else "n"]
	return key

func _refresh_tiles() -> void:
	_tiles_for = _tiles_key()
	# the shop's button says how many tiles the light reaches
	var reach := 0
	for tile: String in Sim.TILES:
		if sim.can_buy(tile):
			reach += 1
	(_shop_b as IconButton).badge = reach
	for tile: String in Sim.TILES:
		var t: Dictionary = _tiles[tile]
		var done: bool = sim.is_done(tile)
		var can: bool = sim.can_buy(tile)
		var level := int(sim.lv[tile])
		(t.effect as Label).text = tr("NL_DONE") if done else _effect(tile)
		(t.cost as Label).text = tr("NL_MAX") if done else Art.short(sim.cost(tile), _comma())
		(t.mote as Control).visible = not done
		(t.tick as Control).visible = done
		# the price's bar: the sun button's own when the light reaches it,
		# paper when it does not, a leaf when there is nothing left to buy
		var box := StyleBoxFlat.new()
		box.bg_color = Pal.LEAF_TILE if done else (Pal.SUN if can else PRICE_OFF)
		box.set_corner_radius_all(PRICE_R)
		box.content_margin_left = 12.0
		box.content_margin_right = 16.0
		if can:
			box.border_width_bottom = 5
			box.border_color = Pal.SUN_DEEP
		(t.pill as Control).add_theme_stylebox_override("panel", box)
		(t.cost as Label).add_theme_color_override("font_color",
			Pal.LEAF_DEEP if done else (Pal.TEXT if can else Pal.TEXT_DIM))
		(t.badge as Control).visible = level > 0
		(t.level as Label).text = str(level)

## What the next level of `tile` does, in the tile's own words.
func _effect(tile: String) -> String:
	var c := _comma()
	match tile:
		"meteor":
			# against a first meteor, since the star's own mass is in Suns
			var level := int(sim.lv.meteor)
			return tr("NL_FX_METEOR") % [Art.short(level + 1.0, c), Art.short(level + 2.0, c)]
		"volley":
			return tr("NL_FX_VOLLEY") % [sim.volley(), sim.volley() + 1]
		"stream":
			var gap: float = sim.stream_gap()
			if gap <= 0.0:
				return tr("NL_FX_STREAM_NEW")
			return tr("NL_FX_STREAM") % [_hundredths(gap), _hundredths(maxf(Sim.STREAM_LEAST, gap * Sim.STREAM_STEP))]
	var h: float = sim.meteor_h()
	return tr("NL_FX_ICE") % [int(round(h * 100.0)), int(round(minf(0.9, h + Sim.ICE_STEP) * 100.0))]

## Seconds to two decimals: 0.43, or 0,43 where the language writes it so.
func _hundredths(v: float) -> String:
	var text := "%.2f" % v
	return text.replace(".", ",") if _comma() else text

static func _comma() -> bool:
	return not TranslationServer.get_locale().begins_with("en")

## A line that counts: `key`_ONE for one, `key`_N otherwise.
func _count(key: String, n: int) -> String:
	return tr(key + "_ONE") if n == 1 else tr(key + "_N") % n

func _on_tile(tile: String) -> void:
	var button: Control = _tiles[tile].button
	var paid: int = sim.cost(tile)
	if sim.buy(tile):
		_fx.cue("buy")
		Motion.bump(button, 0.05, 0.2)
		Analytics.track("nightlight_upgrade", {"tile": tile, "level": int(sim.lv[tile]), "light": paid})
		_refresh_tiles()
		_save()
	elif not sim.is_done(tile):
		_fx.cue("no")
		Motion.shiver(button, 6.0)

# --- the hand ---

## A finger is a ScreenTouch and never a mouse button (the project has
## mouse-from-touch off, and the Grove shipped unable to be chopped on a
## phone for reading the mouse alone). One finger aims; a second is left
## alone. The mouse is for this Mac.
func _on_field_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _finger == -1:
			if _aim_start(t.position):
				_finger = t.index
		elif not t.pressed and t.index == _finger:
			_finger = -1
			_aim_end()
	elif event is InputEventScreenDrag:
		if (event as InputEventScreenDrag).index == _finger and _aiming:
			_aim_to = (event as InputEventScreenDrag).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_aim_start((event as InputEventMouseButton).position)
		else:
			_aim_end()
	elif event is InputEventMouseMotion and _aiming and _finger == -1:
		_aim_to = (event as InputEventMouseMotion).position

## A meteor waits under the finger at `at`. False where none can: on the
## star, under a card, during the supernova.
func _aim_start(at: Vector2) -> bool:
	if _held_back or _nova_t >= 0.0 or at.distance_to(sky.centre) < sky.star_px() * CLEAR:
		return false
	_aiming = true
	_aim_from = at
	_aim_to = at
	_stream_t = 0.0
	_streamed = false
	return true

## Letting go throws, unless the stream has only just let one go.
func _aim_end() -> void:
	if not _aiming:
		return
	_aiming = false
	if not _streamed or _stream_t >= sim.stream_gap() * 0.5:
		_throw()

## A throw from where the finger went down, the way it is dragged now: one
## meteor, or a volley. Felt, though not every one of a stream.
func _throw() -> void:
	sim.throw_at(sky.unit(_aim_from), _aim_vel())
	var now := Time.get_ticks_msec()
	if now - _felt_at >= int(FELT * 1000.0):
		_felt_at = now
		_fx.cue("throw")
	_dirty = true

## The speed a throw would leave with, in the sim's units: the way the
## finger was dragged, as fast as the drag is long.
func _aim_vel() -> Vector2:
	var drag: Vector2 = (_aim_to - _aim_from) / sky.u
	var far := drag.length()
	if far < SLACK:
		return Vector2.ZERO
	return drag / far * (minf(far, MOST) / FULL * sim.throw_speed())

## What the sky draws of a throw being aimed: the meteor under the finger,
## the line of the drag, and the dots of where it would really go.
func _aim() -> Dictionary:
	if not _aiming:
		return {}
	var where: Dictionary = sim.predict(sky.unit(_aim_from), _aim_vel())
	return {"from": _aim_from, "to": _aim_to, "pts": where.pts, "hit": where.hit}

# --- drawing ---

## The bar toward the supernova, by the logarithm of the star's Suns (each
## doubling as long as the last) with a notch at every pick on the way; past
## the supernova's mark, toward one more stardust.
func _draw_nova_line() -> void:
	var w := _nova_line.size.x
	var h := 12.0
	var top := log(Sim.NOVA / Sim.START)
	var share: float = log(maxf(1.0, sim.suns())) / top
	if sim.can_nova():
		var from: float = Sim.NOVA * pow(sim.dust_for() / Sim.DUST, 2.0)
		share = (sim.mass - from) / maxf(1.0, sim.next_dust_mass() - from)
	_bar(_nova_line, Rect2(0.0, 0.0, w, h), Pal.SURFACE_HI)
	_bar(_nova_line, Rect2(0.0, 0.0, maxf(h, w * clampf(share, 0.0, 1.0)), h), Pal.SUN if sim.can_nova() else Pal.SUN_RAY)
	if not sim.can_nova():
		for at: float in Sim.MILES:
			_nova_line.draw_rect(Rect2(w * log(at) / top - 2.0, 0.0, 4.0, h), Pal.PAPER)

## What the star is made of: hydrogen from the left, then helium, then rock.
func _draw_made() -> void:
	var w := _made.size.x
	var h := _made.size.y
	_bar(_made, Rect2(0.0, 0.0, w, h), Art.MADE[2])
	var burnt: float = clampf((sim.fuel + sim.spent) / sim.mass, 0.0, 1.0)
	if burnt > 0.0:
		_bar(_made, Rect2(0.0, 0.0, maxf(h, w * burnt), h), Art.MADE[1])
	var left: float = clampf(sim.fuel / sim.mass, 0.0, 1.0)
	if left > 0.005:
		_bar(_made, Rect2(0.0, 0.0, maxf(h, w * left), h), Art.MADE[0])

func _bar(on: Control, rect: Rect2, col: Color) -> void:
	var r := rect.size.y * 0.5
	on.draw_rect(Rect2(rect.position + Vector2(r, 0.0), rect.size - Vector2(r * 2.0, 0.0)), col)
	on.draw_circle(rect.position + Vector2(r, r), r, col, true, -1.0, true)
	on.draw_circle(rect.position + Vector2(rect.size.x - r, r), r, col, true, -1.0, true)

# --- leaving ---

func _save() -> void:
	if sim == null:
		return
	sim.save()
	_dirty = false
	_since_save = 0.0

func _on_back() -> void:
	_save()
	Analytics.track("nightlight_leave", {"seconds": int((Time.get_ticks_msec() - _opened_at) / 1000.0),
		"eaten": int(sim.eaten - _eaten_at_open), "mass": int(sim.mass), "novas": sim.novas})
	closed.emit()

## Android's back, through the menu: a card or a sheet first, then the screen.
func go_back() -> void:
	if tutor.close():
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	for card: Control in [_shop, _ask, _perks, _powers]:
		if card.visible:
			card.visible = false
			return
	_on_back()
