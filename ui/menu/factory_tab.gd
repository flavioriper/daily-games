extends VBoxContainer

## **Not a page since 2026-10-13**: the bottom bar left, Factory became a
## card of the Arcade list (ui/menu/cards/arc_factory.gd) and this node is
## never shown. It is kept as what the next paragraph but one says it is,
## the owner of the one land; its card and the stepping below only run if
## it is shown again.
##
## (Since 2026-10-20 the floor is three robots, not a land of logs; the
## blurb below says so, and the Arcade card that people see is
## ui/menu/cards/arc_factory.gd.)
##
## The Factory tab: one card as wide as the column, with the land on it as
## it stands and goes (the whole board fitted to the card and drawn by the
## game's own path, factory/life.gd, so a glance shows the belts running),
## the coins held on a pill and the word Play. It takes the Valley tab's
## place (ui/menu/valley_tab.gd) and keeps its surface: `play` and
## `refresh()`. Spec
## docs/superpowers/specs/2026-10-10-factory-board-and-hand-era-design.md,
## section 2.
##
## **It owns the one land.** The sim (factory/sim.gd) is made here once, read
## from its file or begun new, and lives as long as the menu does. The land
## only runs while it is seen (spec section 7): this tab steps it while the
## tab is visible in the tree and no screen has it; `lend()` hands it to the
## screen (factory/screen.gd), which steps it from then on, and `returned()`
## takes it back. Whoever steps it drains its events and keeps it: here every
## two seconds while something changed, and at once when the app is paused
## or closed.

signal play(place: String)

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Sim = preload("res://factory/sim.gd")
const Art = preload("res://factory/art.gd")
const Life = preload("res://factory/life.gd")
const Tile = preload("res://factory/tile.gd")

const GAP := 20
const PAD := 24
const RADIUS := 36
const PILL_H := 84.0
const ART_H_MIN := 260.0
const FILL := Color("fcf7ef")
## The floor keeps this much water round it on the card (the floor's view
## units are fitted into what is left), more over its top edge for the
## bubbles over a robot there.
const SHORE := 26.0
const SHORE_TOP := 70.0
const SHORE_FOOT := 60.0
const SAVE_GAP := 2.0

## The one land. Read its tables; only whoever steps it writes.
var sim: RefCounted
## A screen has the land: it steps it and this tab only waits.
var lent := false

var _life: RefCounted = Life.new()
var _world: Node2D
var _art: Control
var _light_l: Control
var _water: ArrayMesh
var _light: ArrayMesh
var _coins_l: Label
var _fitted := false
var _since_save := 0.0

func _init() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

## The land is made as the tab enters the tree, not sooner: a harness points
## `Sim.path` at a file of its own first.
func _ready() -> void:
	sim = Sim.new(randi())
	sim.load_saved()
	sim.events.clear()
	add_child(_card())
	visibility_changed.connect(_wake)
	_wake()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_wake()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		_save()

## The land runs only while this card is seen and no screen has it.
func _wake() -> void:
	set_process(sim != null and is_visible_in_tree() and not lent)

## The screen takes the land: kept first, and not stepped here until it is
## handed back.
func lend() -> RefCounted:
	_save()
	lent = true
	_wake()
	return sim

## The screen is done with the land. What it did was not seen here, so the
## card reads everything again.
func returned() -> void:
	lent = false
	sim.events.clear()
	_life.stale()
	_fitted = false
	refresh()
	_wake()

## Start over (ui/menu.gd's `_start_over`): a new land in place of the
## one held, kept at once so the file never holds the old one again. The
## card's drawing (`_world`, mounted in `_card`) still stands on the old
## land: this tab is never shown since 2026-10-13, so it is left as it is.
func start_over() -> void:
	sim = Sim.new(randi())
	sim.save()
	sim.events.clear()
	_life.stale()
	_fitted = false
	refresh()

## Called as the tab is shown: the land as it stands now.
func refresh() -> void:
	if sim == null:
		return
	_write_coins()
	_fit()

func _card() -> Control:
	var card := PanelContainer.new()
	card.name = "Factory"
	card.add_theme_stylebox_override("panel", CozyTheme.lifted(FILL, RADIUS, PAD))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	_art = Control.new()
	_art.name = "Art"
	_art.custom_minimum_size.y = ART_H_MIN
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.clip_contents = true
	_art.resized.connect(_layout_art)
	_art.draw.connect(func() -> void:
		if _water != null:
			_art.draw_mesh(_water, null))
	col.add_child(_art)
	_world = _life.mount(_art, sim)
	_light_l = Control.new()
	_light_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_light_l.draw.connect(func() -> void:
		if _light != null:
			_light_l.draw_mesh(_light, null))
	_art.add_child(_light_l)
	var name_l := Label.new()
	name_l.text = "Factory"
	name_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_l.theme_type_variation = "CardName"
	col.add_child(name_l)
	var line := Label.new()
	line.text = "FACTORY_BLURB"
	line.theme_type_variation = "CardBlurb"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	col.add_child(row)
	row.add_child(_coin_pill())
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var go := IconButton.new("play", "VS_PLAY", "SunButton")
	go.name = "Play"
	go.custom_minimum_size = Vector2(260, 96)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func() -> void: play.emit("factory"))
	row.add_child(go)
	return card

## The coins held, as the screen's own pill shows them.
func _coin_pill() -> Control:
	var pill := PanelContainer.new()
	pill.name = "Coins"
	pill.custom_minimum_size = Vector2(190, PILL_H)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, int(PILL_H * 0.5), 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	pill.add_child(row)
	var lead := Control.new()
	lead.custom_minimum_size.x = 6
	row.add_child(lead)
	row.add_child(Tile.coin(58.0))
	_coins_l = Label.new()
	_coins_l.name = "Value"
	_coins_l.theme_type_variation = "SheetTitle"
	_coins_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_coins_l)
	var tail := Control.new()
	tail.custom_minimum_size.x = 18
	row.add_child(tail)
	return pill

func _process(delta: float) -> void:
	sim.step(delta)
	for e: Dictionary in sim.events:
		_life.event(e)
	sim.events.clear()
	_life.step(delta)
	if not _fitted:
		_fit()
	_write_coins()
	_since_save += delta
	if sim.dirty and _since_save >= SAVE_GAP:
		_save()

func _save() -> void:
	if sim == null or lent:
		return
	if sim.dirty:
		sim.save()
	_since_save = 0.0

func _write_coins() -> void:
	var text: String = Art.short(sim.coins)
	if _coins_l.text != text:
		_coins_l.text = text

func _layout_art() -> void:
	var s := _art.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	_water = Art.water(s, 26.0)
	_light = Art.light(s)
	_fit()
	_art.queue_redraw()
	_light_l.queue_redraw()

## The whole floor, as big as the picture's room lets it be, water all round.
func _fit() -> void:
	var s := _art.size
	if s.x <= 0.0 or s.y <= 0.0 or _world == null:
		return
	_fitted = true
	var box: Rect2 = _life.bounds()
	var room := Vector2(s.x - SHORE * 2.0, s.y - SHORE_TOP - SHORE_FOOT)
	var u := minf(room.x / box.size.x, room.y / box.size.y)
	_world.scale = Vector2(u, u)
	_world.position = Vector2(s.x * 0.5, SHORE_TOP + (room.y - box.size.y * u) * 0.5) - Vector2(box.get_center().x, box.position.y) * u
