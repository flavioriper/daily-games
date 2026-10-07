extends Control

## The Grove: the first place on the Valley tab. A piece of land in a pond,
## trees coming up on it at random spots, and a circle that follows the
## finger and chops whatever stands inside it, a beaver coming to bite each
## tree it takes (the user's design, 2026-10-05). A felled tree leaves energy,
## which stays and buys the shop's three tiles and the nodes of the tree of
## skills, and wood, which lies where the tree stood as a pile: the circle
## gathers piles to the jetty off the land's front left edge, they are tied
## into bundles there and a raft takes them off the screen (2026-10-07, spec
## docs/superpowers/specs/2026-10-07-grove-tree-and-jetty-design.md). Only
## what the raft has landed (the sim's `owed`) goes to the shared inventory
## (core/stock.gd), never spent here. The land takes the screen and the
## shop and the tree are each a card over it, opened by its button under the
## land's left (the user, 2026-10-06: "game should take most of screen, and
## shop should be a dialog inside the game that opens by clicking a
## button"): the shop is built here, the tree is valley/grove_tree.gd.
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
const Life = preload("res://valley/grove_life.gd")
const Skills = preload("res://valley/grove_tree.gd")
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

const GAME := "grove"
const MARGIN := 40
const GAP := 20
const HUD_H := 96.0
const INFO_H := 104.0
## The two buttons under the land, one width: the row is the column's 1000,
## and what they leave is the count's.
const BUTTON_W := 320.0
## A tile of the shop, top to bottom: its picture on a disc, its name over
## what the next level does, and its price on a bar along its foot. TILE_H
## leaves air round each, so nothing sits on the tile's edge.
const TILE_H := 344.0
const TILE_PAD := 14.0
const DISC_R := 60.0
## How much of the disc's width a picture may take: a big one (a tree) is
## brought down to it, a small one (Swing's three arcs) grown by DISC_GROW at
## most, or its strokes come out twice as thick as its neighbours'.
const DISC_FIT := 0.78
const DISC_GROW := 1.3
const PRICE_H := 64.0
const PRICE_R := 20
## The shop's card: as wide as the screen's own column (the plates, the pond),
## thinly lined.
const CARD_W := 1000.0
const CARD_INSET := 26
const TILE_GAP := 16
const FILL := Color("fcf7ef")
## Where the jetty's plate is, from the near side of the jetty's end, in view
## units: on the water under the land's front left side.
const JETTY_PLATE := Vector2(92.0, Art.DEPTH + 28.0)
## The land keeps this much water round it, and more under its earth edge.
const SHORE := 26.0
const SHORE_FOOT := 64.0
## And this much over the land's back edge, for the crowns that stand there.
const SHORE_TOP := 110.0
## Seconds: a number's rise and how long the circle's rim swells on a chop.
## A hit tree's squash, a felled one's fall and a gathered log's flight are
## valley/grove_life.gd's.
const NUM := 0.7
const SWELL := 0.18
## What the raft has landed rises beside the wood plate for this long.
const GAIN := 1.3
## The jetty's plate keeps the warn colour this long after a gather the full
## jetty refused, and shivers at the first of a run of them, never sooner
## than SHIVER_GAP after the last time: late on nearly every swing is one.
const WARN_HOLD := 2.5
const SHIVER_GAP := 4.0
const SHIVER := 0.3
## A gathered log's landing is heard this far apart at the soonest.
const CARRY_GAP := 0.05
## A keen chop's figure is this many times a chop's, and at most KEEN_RINGS
## of its rings are on the land at once: late on a swing is a dozen trees,
## half of them keen.
const KEEN := 1.5
const KEEN_RINGS := 6
## A tree one of the grove's own beavers brings down is a dry click and no
## more, never two closer than this: five of them fell several a second with
## nobody's hand on the land.
const GNAW_GAP := 0.3
## A crate lets go this many motes: more than any tree does.
const CRATE_MOTES := 16
## "x2" over a lucky pile stays this long: a tree's motes hang about its pile
## for the first half of it. And a felled tree's "+N" stands this much higher
## (view units) when the chop that felled it was keen, clear of its figure.
const TWICE := 1.2
const KEEN_LIFT := 30.0
## Energy is motes of light, Peapod's own (ui/motes.gd): `ORBS` to one energy,
## as there; a sapling lets go MOTES of them and each tier after MOTES_STEP
## more, up to MOTES_MOST.
const ORBS := 4
const MOTES := 4
const MOTES_STEP := 2
const MOTES_MOST := 12
## The wind takes a leaf off a tree now and then and carries it across the
## land: the most in the air, the seconds one lasts, and the seconds between
## two on a land of one tree in a full gust (more trees, more leaves).
const LEAVES := 14
const LEAF_LIFE := 3.2
const LEAF_GAP := 2.6
const SAVE_GAP := 5.0
## What only the beavers did since the grove was last kept is kept this far
## apart: they work for as long as the screen is open.
const SAVE_SLOW := 20.0
## The tree's badge is counted again this long after the last count, at the
## soonest: a land swept late on fells a tree a frame.
const REACH_GAP := 0.25
## A chop that hits is heard a little higher or lower each time, so a held
## finger is not one sample on a loop.
const CHOP_PITCH := 0.07
## The tap is a selection moved; a tree down is a piece set down; a tile
## bought is something finished; one that cannot be is a not yet.
const HAPTICS := {"fell": Haptics.TAP, "buy": Haptics.BUMP, "no": Haptics.WARN}
const TILE_NAMES := {"axe": "GROVE_AXE", "reach": "GROVE_REACH", "swing": "GROVE_SWING"}

var sim: RefCounted
var top_bar: Control
var settings_sheet: Control
var tutor: RefCounted
var field: Control
var _fx: Node2D
## The motes land on a click of their own, too many and too close to be felt.
var _quiet: Node2D
var _motes: Control
var _margins: MarginContainer
var _over: Control
var _count_l: Label
var _shop_b: Button
var _shop: Control
var _shop_energy: Label
var _skills_b: Button
## The tree of skills on its card (valley/grove_tree.gd), and the energy its
## button's badge was last counted for.
var _tree: Control
var _reach_for := -1
var _since_reach := 0.0
var _plates := {}   # "energy" / "wood" -> {panel, icon, label}
var _shown := {"energy": 0.0, "wood": 0.0}
var _tiles := {}    # tile -> {button, icon, effect, pill, cost, mote, tick, badge, level}
var _tiles_for := ""
var _ground: ArrayMesh
var _light: ArrayMesh
## What stands on the land, in layers over the ground (the field's own
## draw): the grass, the trees' shadows and the trees each under their wind
## (`Art.wind`, `Life.shade`), the
## leaves it carries, and over them what is not blown about (the bars, the
## circle, the numbers). The trees, their shadows, the beavers, the falls,
## the piles lying, what is on the jetty and the raft are `_life`'s
## (valley/grove_life.gd).
var _life: RefCounted
var _grass: Array[MultiMesh] = []
var _grass_l: Control
var _shade_l: Control
var _trees_l: Control
var _leaves_l: Control
var _top: Control
var _leaves: Array = []   # {pos, vel, t, turn, spin, seed, col}: view units (Art.see)
var _leaf_mm: MultiMesh
var _leaf_wait := 1.0
var _wind := 0.0
var _u := 1.0
var _origin := Vector2.ZERO
var _hold := false
var _finger := -1   # the touch that holds the circle
var _hold_at := Vector2.ZERO
var _held_back := false
var _since_chop := 10.0
var _nums: Array = []    # {at, text, t, gold, size, life}: `at` in view units; `size` and `life` only where they are its own
var _gains: Array = []   # {text, t}: what the raft landed, rising beside the wood plate
## Seconds since the full jetty last refused a gather, since its plate last
## shivered and since a gathered log's landing was last heard.
var _since_full := 100.0
var _since_shiver := 100.0
var _since_carry := 100.0
## Seconds since a beaver's tree was last heard coming down, and the age of
## each keen ring on the land.
var _since_gnaw := 100.0
var _rings: Array[float] = []
var _jetty_box := {}   # warn or not -> the plate's paper
var _bump := {}     # plate -> its running bump
var _dirty := false
## Something changed that only the beavers or the pond did (a tree down with
## nobody's hand on it, a crate washed up): kept too, in less of a hurry.
var _gnawed := false
## The screen has handed itself back (`_on_back`): the grove is kept and is
## the tab's from here on.
var _left := false
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
	_refresh_skills()
	_refresh_hud(0.0)
	Analytics.track("valley_enter", {"place": GAME, "trees": sim.trees.size(), "room": sim.room()})

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_hold = false
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
	# a crown at the back of the land stops at the pond's edge
	field.clip_contents = true
	col.add_child(field)
	_life = Life.new()
	_life.landed.connect(_on_landed)
	_life.gave.connect(_on_gave)
	_life.carried.connect(_on_carried)
	_life.doubled.connect(_on_doubled)
	_grass_l = _layer("Grass", _draw_grass)
	_grass_l.material = Art.wind(true)
	_shade_l = _layer("Shade", func() -> void: _life.draw_shade(_shade_l, sim))
	_shade_l.material = _life.shade
	_trees_l = _layer("Trees", _draw_trees)
	_trees_l.material = Art.wind()
	_leaves_l = _layer("Leaves", _draw_leaves)
	_top = _layer("Top", _draw_top)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	field.add_child(_fx)
	_quiet = Fx2D.new()
	_quiet.buzzes = false
	field.add_child(_quiet)

	# under the land: the shop's button and the tree's on the left, clear of
	# the thumb that chops, and the count on the right
	var info := HBoxContainer.new()
	info.name = "Info"
	info.custom_minimum_size.y = INFO_H
	info.add_theme_constant_override("separation", TILE_GAP)
	_shop_b = IconButton.new("trend", tr("GROVE_SHOP"), "PrimaryButton")
	_shop_b.name = "Shop"
	_shop_b.pressed.connect(open_shop)
	_skills_b = IconButton.new("tree", tr("GROVE_SKILLS"), "IconButton")
	_skills_b.name = "Skills"
	_skills_b.pressed.connect(open_skills)
	for b: Button in [_shop_b, _skills_b]:
		b.custom_minimum_size = Vector2(BUTTON_W, INFO_H)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.add_child(b)
	_count_l = Label.new()
	_count_l.name = "Count"
	_count_l.theme_type_variation = "CardTitle"
	_count_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(_count_l)
	col.add_child(info)

	_over = Control.new()
	_over.name = "Over"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_over)
	add_child(_over)
	_motes = Motes.new()
	_motes.target = _plates.energy.icon
	_motes.landed.connect(_on_motes_landed)
	add_child(_motes)
	_shop = _build_shop()
	add_child(_shop)
	_tree = Skills.new()
	_tree.name = "Skills"
	_tree.setup(sim, tree_name)
	_tree.bought.connect(_on_node_bought)
	_tree.refused.connect(func(_id: String) -> void: _fx.cue("no"))
	add_child(_tree)
	_apply_insets()

## The shop: its three tiles on a card over the grove, the energy held on a
## pill at its head and an X beside it. Built once and shown; the grove goes
## on behind it (trees come up, motes land), but nothing is chopped.
func _build_shop() -> Control:
	var scrim := Dialog.scrim()
	scrim.name = "Shop"
	scrim.visible = false
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
			close_shop())
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	var card := Dialog.card(CARD_W, CARD_INSET)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	card.add_child(col)
	var head := Dialog.energy_head("GROVE_SHOP", "trend", close_shop)
	_shop_energy = head.energy
	col.add_child(head.head)
	var grid := GridContainer.new()
	grid.name = "Tiles"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	for tile: String in Sim.SHOP:
		grid.add_child(_tile(tile))
	col.add_child(grid)
	return scrim

func open_shop() -> void:
	if _shop.visible:
		return
	_hold = false
	_refresh_tiles()
	_shop.visible = true
	Motion.appear(_shop, 0.0, 1.0, 0.2)

func close_shop() -> void:
	_shop.visible = false

## The tree of skills, on its own card: the grove goes on behind it as it
## does behind the shop, and nothing is chopped.
func open_skills() -> void:
	if _tree.is_open():
		return
	_hold = false
	_tree.held((_plates.energy.label as Label).text)
	_tree.open()

## One layer of the land, over the ground and as big as the field.
func _layer(called: String, draws: Callable) -> Control:
	var layer := Control.new()
	layer.name = called
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.draw.connect(draws)
	field.add_child(layer)
	return layer

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

## One of the three, on the shop's card: its picture, its name, what the next
## level does, and the energy it asks on a bar along its foot. A tile that
## cannot be bought yet is still pressed: it shakes its head.
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
	icon.draw.connect(_draw_tile_icon.bind(icon, tile))
	col.add_child(icon)
	# the words take what is left between the picture and the price, and
	# stand in the middle of it
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
	var mote := Motes.icon(38.0)
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

## A tile's picture, fitted to its disc: a tree and an axe take the same room.
func _draw_tile_icon(icon: Control, tile: String) -> void:
	var c := icon.size * 0.5
	var done: bool = sim.is_done(tile)
	icon.draw_circle(c, DISC_R, Pal.LEAF_TILE if done else Pal.PARCHMENT, true, -1.0, true)
	var mesh := Art.icon(tile, Sim.look_of(int(sim.lv.seeds) + 1))
	var box := mesh.get_aabb()
	var fit := minf(DISC_GROW, DISC_R * 2.0 * DISC_FIT / maxf(1.0, maxf(box.size.x, box.size.y)))
	var mid := Vector2(box.get_center().x, box.get_center().y)
	icon.draw_mesh(mesh, null, Transform2D(0.0, Vector2(fit, fit), 0.0, c - mid * fit))

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
	var view: Rect2 = Art.VIEW
	_u = minf((s.x - SHORE * 2.0) / view.size.x, (s.y - SHORE_TOP - SHORE_FOOT) / view.size.y)
	_origin = Vector2((s.x - view.size.x * _u) * 0.5, SHORE_TOP + (s.y - SHORE_TOP - SHORE_FOOT - view.size.y * _u) * 0.5) - view.position * _u
	_ground = Art.ground(s, _origin, _u)
	_grass = Art.grass(_origin, _u)
	_light = Art.light(s)
	_life.place(_origin, _u, field.get_global_transform())
	field.queue_redraw()
	_grass_l.queue_redraw()

## A point of the land, in the field's pixels: the land is seen in
## isometric (Art.see), across as it is and Art.DEEP as deep.
func px(p: Vector2) -> Vector2:
	return _origin + Art.see(p) * _u

## The point of the land under a point of the field.
func unit(at: Vector2) -> Vector2:
	var v := (at - _origin) / _u
	return Vector2(v.x, v.y / Art.DEEP)

## A point of the view (what Art.see gives), in the field's pixels.
func _at(v: Vector2) -> Vector2:
	return _origin + v * _u

# --- what the top bar and the tutorial ask ---

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/grove_tutorial_diagram.gd")
	var pages := []
	for step: Array in [
			[Diagram.Lesson.CHOP, "TUT_GROVE_CHOP", _chops_line()],
			[Diagram.Lesson.GIFTS, "TUT_GROVE_GIFTS", tr("TUT_GROVE_GIFTS_BODY")],
			[Diagram.Lesson.WAIT, "TUT_GROVE_WAIT", tr("TUT_GROVE_WAIT_BODY")],
			[Diagram.Lesson.SEND, "TUT_GROVE_SEND", tr("TUT_GROVE_SEND_BODY")]]:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## The first page's words, with the chops a sapling takes on this grove as
## it is now: its Soft bough and the axe's levels counted, whole chops.
func _chops_line() -> String:
	var chops := maxi(1, ceili(sim.hp(0) / sim.power() - 0.0001))
	return tr("TUT_GROVE_CHOP_BODY_ONE") if chops == 1 else tr("TUT_GROVE_CHOP_BODY_N") % chops

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
	if sim == null or _left:
		return
	var holding: bool = _hold and not _held_back and not _shop.visible and not _tree.is_open() and not settings_sheet.is_open()
	sim.step(delta, holding, unit(_hold_at))
	# what the raft has landed is wood in the valley now. The grove is kept
	# with it: one kept from before the landing would land it again.
	var landed_wood: int = sim.take_owed()
	if landed_wood > 0:
		Stock.add("wood", landed_wood, GAME)
		_save()
	_since_chop += delta
	_since_reach += delta
	_since_full += delta
	_since_shiver += delta
	_since_carry += delta
	_since_gnaw += delta
	if not _rings.is_empty():
		for i in _rings.size():
			_rings[i] += delta
		_rings = _rings.filter(func(age: float) -> bool: return age < Motion.RING_TIME)
	# the land may have moved on the screen (an inset, the banner): the
	# shadows are kept to where it is now
	_life.place(_origin, _u, field.get_global_transform())
	_life.step(delta, sim, holding, unit(_hold_at))
	_play_events()
	for item: Dictionary in _nums:
		item.t += delta
	_nums = _nums.filter(func(n: Dictionary) -> bool: return n.t < float(n.get("life", NUM)))
	if not _gains.is_empty():
		for g: Dictionary in _gains:
			g.t += delta
		_gains = _gains.filter(func(g: Dictionary) -> bool: return g.t < GAIN)
	_refresh_hud(delta)
	if _dirty or _gnawed:
		_since_save += delta
		if _since_save >= (SAVE_GAP if _dirty else SAVE_SLOW):
			_save()
	_wind = Art.blow()
	_step_leaves(delta)
	# the ground and the grass are drawn once: the wind moves the grass
	_shade_l.queue_redraw()
	_trees_l.queue_redraw()
	_leaves_l.queue_redraw()
	_top.queue_redraw()
	_over.queue_redraw()

## The wind takes a leaf off a tree, sooner in a gust and on a fuller land,
## and carries it off to the right, sinking and turning over, until it is
## gone or past the land's edge.
func _step_leaves(delta: float) -> void:
	if Motion.reduce:
		_leaves.clear()
		return
	var across := field.get_global_transform().origin.x
	var n: int = sim.trees.size()
	if n > 0:
		_leaf_wait -= delta * (0.25 + 0.75 * Art.gust(across + field.size.x * 0.5, _wind)) * sqrt(float(n))
		if _leaf_wait <= 0.0 and _leaves.size() < LEAVES:
			_leaf_wait = LEAF_GAP * _rng.randf_range(0.6, 1.4)
			var tree: Dictionary = sim.trees[_rng.randi() % n]
			var r: float = Sim.radius_of(tree.tier)
			_leaves.append({"pos": Art.see(tree.pos) + Vector2(_rng.randf_range(-0.6, 0.6) * r, -r * _rng.randf_range(1.3, 2.3)) * Art.TREE,
				"vel": Vector2(20.0, -10.0), "t": 0.0, "turn": _rng.randf() * TAU, "spin": _rng.randf_range(-5.0, 5.0),
				"seed": _rng.randf() * 100.0, "col": Art.LEAF[Sim.look_of(tree.tier)]})
	for l: Dictionary in _leaves:
		l.t += delta
		var at: Vector2 = l.pos
		var g: float = Art.gust(across + _at(at).x, _wind)
		var want := Vector2(50.0 + 170.0 * g, 22.0 + 20.0 * sin(float(l.t) * 4.4 + float(l.seed)))
		l.vel = (l.vel as Vector2).lerp(want, minf(1.0, delta * 2.2))
		l.pos = at + (l.vel as Vector2) * delta
		l.turn = float(l.turn) + float(l.spin) * (0.4 + g) * delta
	_leaves = _leaves.filter(func(l: Dictionary) -> bool: return l.t < LEAF_LIFE and l.pos.x < Art.VIEW.end.x + 30.0)

func _play_events() -> void:
	# the tree the last keen chop landed on, for the "+N" of the fall it made
	var keen_on := -1
	for e: Dictionary in sim.events:
		match String(e.kind):
			"hit":
				var tree: Dictionary = e.tree
				_life.hit(tree)
				# a beaver's bite is seen in its teeth and says no figure
				if String(e.get("by", "axe")) == "beaver":
					continue
				var tall: float = Art.height(Sim.look_of(tree.tier)) * Art.TREE
				var keen: bool = e.get("keen", false)
				_nums.append({"at": Art.see(tree.pos) + Vector2(_rng.randf_range(-16.0, 16.0), -tall * 0.86),
					"text": Art.amount(float(e.amount), _comma()), "t": 0.0, "gold": keen, "size": 40.0 * (KEEN if keen else 1.0)})
				# a keen chop: its figure large and gold, a ring going out from the tree
				keen_on = int(tree.id) if keen else -1
				if keen and not Motion.reduce and _rings.size() < KEEN_RINGS:
					_rings.append(0.0)
					_fx.ring(_at(Art.see(tree.pos) + Vector2(0.0, -tall * 0.5)), Sim.radius_of(tree.tier) * Art.TREE * 0.8 * _u, Art.MARK)
			"fell":
				var tree: Dictionary = e.tree
				var give := int(e.give)
				_life.fell(tree, give, bool(e.get("lucky", false)))
				if String(e.get("by", "axe")) == "beaver":
					# nobody's hand is on it: no figure, no `fell` and nothing
					# felt. Its motes and its pile say what it left
					if _since_gnaw >= GNAW_GAP:
						_since_gnaw = 0.0
						_quiet.cue("chop", 0.7 + _rng.randf_range(-CHOP_PITCH, CHOP_PITCH), -12.0)
					_gnawed = true
					continue
				_nums.append({"at": Art.see(tree.pos) + Vector2(0.0, -Art.height(Sim.look_of(tree.tier)) * Art.TREE - 18.0 - (KEEN_LIFT if keen_on == int(tree.id) else 0.0)),
					"text": "+" + Art.short(give), "t": 0.0, "gold": true})
				_fx.cue("fell")
				_dirty = true
			"crate":
				_life.washed()
				_gnawed = true
			"opened":
				# the crate under the circle bursts: dust and its boards, its
				# energy let go as motes, heard and felt as a tree down is
				var pos: Vector2 = e.pos
				_life.opened(pos)
				var at := _at(Art.see(pos) + Vector2(0.0, -Art.CRATE_TALL * 0.6))
				_fx.puff(at, Color("f3ecd2"), 8)
				_fx.cue("fell")
				if not Motion.reduce:
					_motes.u = size.x / 810.0 * 2.2
					_motes.drop(field.get_global_transform() * at, float(int(e.give)) * ORBS, CRATE_MOTES)
				_dirty = true
			"swing":
				_since_chop = 0.0
				if int(e.hits) > 0:
					_fx.cue("chop", 1.0 + _rng.randf_range(-CHOP_PITCH, CHOP_PITCH))
			"log":
				# the pile that fell's wood came down as: seen when its tree has landed
				_life.left(e.log)
			"gather":
				_life.gather(e.pos, int(e.n))
				_dirty = true
			"full":
				# a swing over a ripe pile the jetty had no room for
				if _since_full >= WARN_HOLD and _since_shiver >= SHIVER_GAP:
					_since_shiver = 0.0
				_since_full = 0.0
			"landed":
				# the raft is off the screen when it gets there: the wood plate
				# is the only sign (the wood itself is `take_owed`'s, above).
				# Heard low and felt as a tree down is: it is seconds apart
				_kick("wood")
				_fx.cue("fell", 1.0, -9.0)
				_gains.append({"text": "+" + Art.short(int(e.wood)), "t": 0.0})
	sim.events.clear()
	if _tiles_for != _tiles_key():
		_refresh_tiles()
	if _reach_for != int(sim.energy) and _since_reach >= REACH_GAP:
		_refresh_skills()

## A tree's crown has come down at `at` (view units): dust off the grass.
func _on_landed(tree: Dictionary, at: Vector2) -> void:
	_fx.puff(_at(at) + Vector2(0.0, Sim.radius_of(tree.tier) * 0.5 * _u), Color("f3ecd2"), 5)

## A felled tree, lying with its crown at `at` (view units), goes into what
## it gives: its energy is let go as motes of light, which drift out of its
## crown, hang a moment and are drawn in to the energy plate, the count
## rolling up as they land. Its wood is the pile that drops out of the same
## crown and lies (valley/grove_life.gd): no plate counts it yet.
func _on_gave(tree: Dictionary, give: int, at: Vector2) -> void:
	if Motion.reduce:
		return
	var from: Vector2 = field.get_global_transform() * _at(at)
	_motes.u = size.x / 810.0 * 2.2
	_motes.drop(from, float(give) * ORBS, mini(MOTES + MOTES_STEP * int(tree.tier), MOTES_MOST))

## A lucky pile has come to rest: "x2" rises over it (`at`, view units) as a
## felled tree's gold figure does over the tree.
func _on_doubled(at: Vector2) -> void:
	_nums.append({"at": at, "text": "x2", "t": 0.0, "gold": true, "life": TWICE})

## A log thrown from a gathered pile has come down on the jetty: the mote's
## own quiet click, lower, and never two closer than CARRY_GAP.
func _on_carried() -> void:
	if _since_carry < CARRY_GAP:
		return
	_since_carry = 0.0
	_quiet.cue("chop", 0.8 + _rng.randf_range(-CHOP_PITCH, CHOP_PITCH), -11.0)

## Motes came down on the energy plate: it swells, unless it still is from
## the one before, and a click is heard, each a semitone up a short run.
func _on_motes_landed(_count: int, note: int) -> void:
	if (_plates.energy.panel as Control).scale.x <= 1.01:
		_kick("energy")
	if note >= 0:
		_quiet.cue("chop", 1.5 * pow(2.0, mini(note, 14) / 12.0), -13.0)

## A plate swells as something lands on it. Each kick ends the last, or
## landings a moment apart would leave it stuck big (ui/menu/gold_pill.gd).
func _kick(kind: String) -> void:
	var panel: Control = _plates[kind].panel
	Motion.stop(_bump.get(kind))
	panel.scale = Vector2.ONE
	_bump[kind] = Motion.bump(panel, 0.06, 0.18)

func _refresh_hud(delta: float) -> void:
	# the energy plate counts what has landed, not what is still in the air
	var want := {"energy": float(sim.energy - ceili(_motes.due / ORBS - 0.001)), "wood": float(Stock.count("wood"))}
	for kind: String in want:
		var held: float = want[kind]
		var s: float = _shown[kind]
		if Motion.reduce or delta <= 0.0 or absf(held - s) < 0.6:
			s = held
		else:
			s = lerpf(s, held, minf(1.0, delta * 10.0))
		_shown[kind] = s
		(_plates[kind].label as Label).text = Art.short(int(round(s)))
	_shop_energy.text = (_plates.energy.label as Label).text
	_tree.held(_shop_energy.text)
	_count_l.text = tr("GROVE_TREES") % [sim.trees.size(), sim.room()]

# --- the tiles ---

func _tiles_key() -> String:
	var key := ""
	for tile: String in Sim.SHOP:
		key += "%d%s" % [int(sim.lv[tile]), "y" if sim.can_buy(tile) else "n"]
	return key

func _refresh_tiles() -> void:
	_tiles_for = _tiles_key()
	# the shop's button says how many tiles the energy reaches
	var reach := 0
	for tile: String in Sim.SHOP:
		if sim.can_buy(tile):
			reach += 1
	(_shop_b as IconButton).badge = reach
	for tile: String in Sim.SHOP:
		var t: Dictionary = _tiles[tile]
		var done: bool = sim.is_done(tile)
		var can: bool = sim.can_buy(tile)
		var level := int(sim.lv[tile])
		(t.effect as Label).text = tr("GROVE_DONE") if done else _effect(tile)
		(t.cost as Label).text = tr("GROVE_MAX") if done else Art.short(sim.cost(tile))
		(t.mote as Control).visible = not done
		(t.tick as Control).visible = done
		# the price's bar: the sun button's own when the energy reaches it,
		# paper when it does not, a leaf when there is nothing left to buy
		var box := StyleBoxFlat.new()
		box.bg_color = Pal.LEAF_TILE if done else (Pal.SUN if can else Art.PRICE_OFF)
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
		(t.icon as Control).queue_redraw()

## The tree's button says how many of its nodes the energy reaches, and the
## tree, if it is open, takes the new energy. Counted when the energy has
## changed and REACH_GAP apart, never a frame: `reachable` lists every node
## shown (a quarter of a millisecond on a late grove).
func _refresh_skills() -> void:
	_reach_for = int(sim.energy)
	_since_reach = 0.0
	(_skills_b as IconButton).badge = sim.reachable()
	if _tree.is_open():
		_tree.refresh()

## What the next level of `tile` does, in the tile's own words. A node of the
## tree says its own on the tree's card (valley/grove_tree.gd).
func _effect(tile: String) -> String:
	match tile:
		"axe":
			return tr("GROVE_FX_AXE") % [Art.amount(sim.power(), _comma()), Art.amount(sim.power() + Sim.AXE_STEP, _comma())]
		"reach":
			return tr("GROVE_FX_REACH")
		"swing":
			return _decimal(tr("GROVE_FX_SWING") % [sim.swing_time(), sim.swing_time() * Sim.SWING_STEP])
	return ""

## Seconds are written 0,47 where the language writes them so (pt, es).
static func _decimal(text: String) -> String:
	return Art.decimal(text)

static func _comma() -> bool:
	return Art.comma()

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

## A level of a node, bought on the tree's card.
func _on_node_bought(id: String, paid: int) -> void:
	_fx.cue("buy")
	Analytics.track("grove_upgrade", {"tile": id, "level": int(sim.level(id)), "energy": paid})
	_refresh_tiles()
	_refresh_skills()
	_save()

# --- the hand ---

## A finger is a ScreenTouch and never a mouse button: the project turned
## mouse-from-touch off on 2026-09-22 (b707b9a, doubled taps on Android). The
## screen read the mouse alone until 2026-10-06, so on a phone the circle
## never came up and nothing could be chopped (the user: "the click is not
## working (can't farm) on device"). One finger holds the circle; a second
## is left alone.
func _on_field_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and (_finger == -1 or not _hold):
			_finger = t.index
			_hold = not _held_back
			_hold_at = t.position
		elif not t.pressed and t.index == _finger:
			_finger = -1
			_hold = false
	elif event is InputEventScreenDrag:
		if (event as InputEventScreenDrag).index == _finger and _hold:
			_hold_at = (event as InputEventScreenDrag).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_hold = (event as InputEventMouseButton).pressed and not _held_back
		_hold_at = (event as InputEventMouseButton).position
	elif event is InputEventMouseMotion and _hold:
		_hold_at = (event as InputEventMouseMotion).position

# --- drawing ---

func _draw_field() -> void:
	if _ground != null:
		field.draw_mesh(_ground, null)

func _draw_grass() -> void:
	for mm: MultiMesh in _grass:
		_grass_l.draw_multimesh(mm, null)

## The trees, the ones coming down, their stumps, the beavers at them and
## the piles lying among them, from the back of the land to the front, then
## the jetty's wood and the raft (valley/grove_life.gd). The wind leans what
## stands in the layer's material, and leaves the wood alone.
func _draw_trees() -> void:
	_life.draw(_trees_l, sim)

## The loose leaves, one MultiMesh: each turning over as it goes (its width
## closing and opening), in and out of sight at its ends.
func _draw_leaves() -> void:
	if _leaves.is_empty():
		return
	if _leaf_mm == null:
		_leaf_mm = MultiMesh.new()
		_leaf_mm.transform_format = MultiMesh.TRANSFORM_2D
		_leaf_mm.use_colors = true
		_leaf_mm.mesh = Art.leaf()
		_leaf_mm.instance_count = LEAVES
	var n := 0
	for l: Dictionary in _leaves:
		var t: float = l.t
		var a := minf(1.0, t / 0.25) * clampf((LEAF_LIFE - t) / 0.7, 0.0, 1.0)
		var flat := 0.35 + 0.65 * absf(cos(t * 5.0 + float(l.seed)))
		_leaf_mm.set_instance_transform_2d(n, Transform2D(float(l.turn), Vector2(_u, _u * flat), 0.0, _at(l.pos)))
		_leaf_mm.set_instance_color(n, Color(l.col as Color, a))
		n += 1
	_leaf_mm.visible_instance_count = n
	_leaves_l.draw_multimesh(_leaf_mm, null)

## What the wind leaves alone, over the trees: the light, a lap's gold marks
## at a foot, a hurt tree's bar, the jetty's plate, the circle and the numbers. The circle is
## one on the ground, so the screen sees it flatter than it is wide.
func _draw_top() -> void:
	if _light != null:
		_top.draw_mesh(_light, null)
	for tree: Dictionary in sim.trees:
		var at := px(tree.pos)
		var laps: int = Sim.lap_of(tree.tier)
		for i in laps:
			_top.draw_circle(at + Vector2((i - (laps - 1) * 0.5) * 18.0, -4.0) * _u, 7.0 * _u, Art.MARK, true, -1.0, true)
		var full: float = sim.hp(tree.tier)
		if float(tree.hp) < full:
			var w := maxf(54.0, Sim.radius_of(tree.tier) * 1.6) * _u
			var bar := Rect2(at + Vector2(-w * 0.5, 12.0 * _u), Vector2(w, 12.0 * _u))
			_top.draw_rect(bar, Color(0.23, 0.19, 0.16, 0.35))
			_top.draw_rect(Rect2(bar.position, Vector2(maxf(4.0, w * float(tree.hp) / full), bar.size.y)), Color("fff6e6"))
	_draw_jetty_plate()
	if _hold and not _held_back:
		var r: float = sim.reach() * _u
		var swell := 0.0 if Motion.reduce else maxf(0.0, 1.0 - _since_chop / SWELL)
		_top.draw_colored_polygon(Art.oval(_hold_at, r), Color(1.0, 1.0, 1.0, 0.22 + swell * 0.2))
		for line: Array in [[r + swell * 8.0, Color(0.23, 0.19, 0.16, 0.75), 5.0], [r - 5.0, Color(1.0, 1.0, 1.0, 0.8), 3.0]]:
			var edge := Art.oval(_hold_at, line[0])
			edge.append(edge[0])
			_top.draw_polyline(edge, line[1], line[2], true)
	var font := get_theme_font("font", "SheetTitle")
	for n: Dictionary in _nums:
		var k: float = n.t / float(n.get("life", NUM))
		var fs := int(float(n.get("size", 50.0 if n.gold else 40.0)) * _u)
		var w := font.get_string_size(n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := _at(n.at) + Vector2(-w * 0.5, 0.0 if Motion.reduce else -k * 56.0 * _u)
		var a := 1.0 - k * k * k
		_top.draw_string_outline(font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.23, 0.19, 0.16, 0.7 * a))
		_top.draw_string(font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Art.MARK if n.gold else Color.WHITE, a))

## The jetty's plate, on the water by it: how many piles it holds of how many
## it has room for. It wears the warn colour while a full jetty is refusing
## what the circle gathers, and shivers as that starts.
func _draw_jetty_plate() -> void:
	# not on a jetty the raft has since half emptied
	var warn: bool = _since_full < WARN_HOLD and sim.jetty_held() * 2 >= sim.jetty_room()
	if not _jetty_box.has(warn):
		_jetty_box[warn] = CozyTheme.lifted(Pal.BAD_TILE if warn else FILL, 22, 0)
	var font := get_theme_font("font", "SheetTitle")
	var fs := int(30.0 * _u)
	var room := Art.short(sim.jetty_room())
	var text := "%s / %s" % [Art.short(sim.jetty_held()), room]
	# as wide as its fullest reading, so it does not breathe as piles come
	var most := font.get_string_size("%s / %s" % [room, room], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var icon := 44.0 * _u
	var box := Rect2(Vector2.ZERO, Vector2(most + icon + 34.0 * _u, 50.0 * _u))
	box.position = _at(Art.deck(0.5, 0.86) + JETTY_PLATE) - box.size * 0.5 + Vector2(Motion.shiver_offset(_since_shiver, 5.0 * _u, SHIVER), 0.0)
	_top.draw_style_box(_jetty_box[warn], box)
	_top.draw_mesh(Art.icon("wood"), null, Transform2D(-0.3, Vector2(0.44, 0.44) * _u, 0.0, box.position + Vector2(10.0 * _u + icon * 0.5, box.size.y * 0.5)))
	_top.draw_string(font, box.position + Vector2(icon + 16.0 * _u + (most - w) * 0.5, box.size.y * 0.5 + fs * 0.36), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.BAD if warn else Pal.TEXT)

## What the raft has landed, in gold beside the wood plate's count, over
## everything: it rises and goes.
func _draw_over() -> void:
	if _gains.is_empty():
		return
	var label: Control = _plates.wood.label
	var at: Vector2 = _over.get_global_transform().affine_inverse() * (label.get_global_transform() * Vector2(label.size.x + 18.0, label.size.y * 0.74))
	var font := get_theme_font("font", "SheetTitle")
	for g: Dictionary in _gains:
		var k: float = g.t / GAIN
		var a := minf(1.0, (1.0 - k) * 4.0)
		var rise := 0.0 if Motion.reduce else -22.0 * (1.0 - pow(1.0 - k, 3.0))
		_over.draw_string_outline(font, at + Vector2(0.0, rise), g.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 8, Color(0.23, 0.19, 0.16, 0.7 * a))
		_over.draw_string(font, at + Vector2(0.0, rise), g.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(Art.MARK, a))

# --- leaving ---

func _save() -> void:
	if sim == null or _left:
		return
	sim.save(Time.get_unix_time_from_system())
	Stock.flush()
	_dirty = false
	_gnawed = false
	_since_save = 0.0

## The grove is kept and the screen stops there, before it says it is closed:
## the menu frees it at the end of the frame and shows the tab, which reads
## the same file at once. A screen that went on stepping beside the tab
## could see the raft land in that frame, and the tab see it too, and one
## load would be wood twice; one that kept the grove again as it left the
## tree would write over what the tab had kept since.
func _on_back() -> void:
	_save()
	_left = true
	set_process(false)
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
	if _shop.visible:
		close_shop()
		return
	if _tree.is_open():
		_tree.close()
		return
	_on_back()
