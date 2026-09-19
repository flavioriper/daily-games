extends Control

## The first screen: the wordmark and the two characters at the top, the day
## row under them, twelve puzzle cards in a grid of three, and the bottom
## bar. Everything on it is drawn in 2D -- there is no stage, no World3D and
## no model anywhere on this screen.
##
## It replaced the campsite (legacy/ui/camp_menu.gd) on 2026-09-18. What the
## campsite did that this does not: a painted 3D setting under a shift lens,
## its own light and soft focus, a live diorama in every card, and pages of
## nine turned with buttons. Twelve cards fit on one screen, so the pager
## went with it.
##
## Opening a card hands the puzzle to a FlatHost and hides the grid; the
## host's close shows it again. The host is always this node's last child
## while it lives, which the harnesses rely on.
##
## The old game is not gone: **More** opens ui/menu/legacy_sheet.gd, and
## picking a line there mounts legacy/world/stage.tscn, builds the island
## host (or the turn host, or the campsite menu itself) and frees the stage
## again on the way back. The live game never mounts it, which is why
## world/main.tscn no longer carries one.
## Spec: docs/superpowers/specs/2026-09-18-flat-menu-design.md.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Progress = preload("res://core/progress.gd")
const Registry = preload("res://ui/registry.gd")
const FlatHost = preload("res://ui/flat/flat_host.gd")
const CozyTheme = preload("res://ui/theme.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const MenuHeader = preload("res://ui/menu/menu_header.gd")
const DayRow = preload("res://ui/menu/day_row.gd")
const PuzzleCard = preload("res://ui/menu/puzzle_card_2d.gd")
const BottomBar = preload("res://ui/menu/bottom_bar.gd")
const LegacySheet = preload("res://ui/menu/legacy_sheet.gd")

## The old game's scene and its two hosts, loaded only when More opens one.
const STAGE_SCENE := "res://legacy/world/stage.tscn"
const ISLAND_HOST := "res://legacy/ui/island_host.gd"
const TURN_HOST := "res://legacy/ui/turn_host.gd"
const CAMP_MENU := "res://legacy/ui/camp_menu.gd"

const MARGIN := 40
const GAP := 20
const COLS := 3
## Entrance delays: the header first, then the day row, then a wave down the
## cards, then the bar.
const ENTER_HEADER := 0.0
const ENTER_DAY := 0.1
const ENTER_CARDS := 0.15
const CARD_STEP := 0.05
const CARD_CAP := 0.4
const ENTER_BAR := 0.5
const ENTER_FADE := 0.3
## How long a line about an unbuilt thing stays up.
const TOAST_TIME := 2.6
const TOAST_FADE := 0.25
## Where the line sits: this far above the screen's bottom, and this tall.
const TOAST_OVER := 150.0 + 40.0 + 10.0
const TOAST_H := 88.0

var settings_sheet: Control
var legacy_sheet: Control
var cards: Array = []
var header: Control
var day_row: Control
var bar: Control
var _list_root: Control
var _grid: GridContainer
var _toast: Label
var _toast_tw: Tween
## The stage, while something from More is open on it.
var _stage: Node

func _ready() -> void:
	theme = CozyTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_list()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	settings_sheet.reduce_changed.connect(header.refresh_motion)
	add_child(settings_sheet)
	legacy_sheet = LegacySheet.new()
	legacy_sheet.name = "LegacySheet"
	legacy_sheet.chose.connect(_open_legacy)
	legacy_sheet.chose_camp.connect(_open_camp)
	legacy_sheet.closed.connect(func() -> void: bar.show_tab("home"))
	add_child(legacy_sheet)
	_show_list()

func _build_list() -> void:
	_list_root = Control.new()
	_list_root.name = "List"
	_list_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_list_root)
	# The page. The campsite used to fill the frame behind the cards, so the
	# menu never painted a background and the viewport's clear colour -- the
	# stage's sky -- showed through the gaps. With no stage there is nothing
	# behind this screen but paper, and it has to draw it.
	var page := ColorRect.new()
	page.name = "Page"
	page.color = Pal.PAPER
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list_root.add_child(page)
	var insets := SafeArea.insets(self)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", MARGIN)
	margins.add_theme_constant_override("margin_right", MARGIN)
	margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_list_root.add_child(margins)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", GAP)
	margins.add_child(root)

	header = MenuHeader.new()
	header.name = "Header"
	header.settings.connect(func() -> void: settings_sheet.open())
	header.calendar.pressed.connect(func() -> void:
		_say("The calendar is a picture for now — there is nothing behind it yet."))
	root.add_child(header)

	day_row = DayRow.new()
	day_row.name = "DayRow"
	root.add_child(day_row)

	# --- the twelve cards, all on one screen ---
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = COLS
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	root.add_child(_grid)
	for i in Registry.PUZZLES.size():
		var entry: Dictionary = Registry.PUZZLES[i]
		var card := PuzzleCard.new(entry, Pal.CAT[i % Pal.CAT.size()])
		card.name = "Card_" + entry.id
		card.open.connect(_open.bind(entry))
		card.blocked.connect(_on_soon.bind(entry))
		cards.append(card)
		_grid.add_child(card)

	bar = BottomBar.new()
	bar.name = "BottomBar"
	bar.picked.connect(_on_tab)
	bar.unbuilt.connect(func(tab: String) -> void:
		_say("%s is drawn but not built yet." % tab.capitalize()))
	root.add_child(bar)

	# A line about something that is only drawn, laid over the bar rather
	# than given a row of the column: four rows of cards and the bar spend
	# the screen exactly, and a row that is empty most of the time would
	# come out of the cards.
	_toast = Label.new()
	_toast.name = "Toast"
	_toast.theme_type_variation = "CardBodyDim"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.offset_left = MARGIN
	_toast.offset_right = -MARGIN
	_toast.offset_top = -TOAST_OVER - TOAST_H
	_toast.offset_bottom = -TOAST_OVER
	_list_root.add_child(_toast)

## Shows the grid with the day current and plays the entrance; at start and
## on every return from a puzzle. Opening the app is what counts a day.
func _show_list() -> void:
	_list_root.visible = true
	Progress.touch()
	day_row.set_day(Progress.day(), Progress.island_name())
	bar.show_tab("home")
	_enter()

func _enter() -> void:
	header.enter(ENTER_HEADER, ENTER_FADE)
	day_row.enter(ENTER_DAY)
	for i in cards.size():
		cards[i].enter(ENTER_CARDS + Motion.stagger(i, CARD_STEP, CARD_CAP))
	bar.enter(ENTER_BAR)

## One line under the grid, for a tap on something that is only drawn.
func _say(text: String) -> void:
	Motion.stop(_toast_tw)
	_toast.text = text
	_toast_tw = Motion.appear(_toast, _toast.modulate.a, 1.0, TOAST_FADE, 0.0)
	var hide := get_tree().create_timer(TOAST_TIME)
	hide.timeout.connect(func() -> void:
		if is_instance_valid(_toast):
			Motion.stop(_toast_tw)
			_toast_tw = Motion.appear(_toast, _toast.modulate.a, 0.0, TOAST_FADE, 0.0))

func _on_tab(tab: String) -> void:
	match tab:
		"home":
			legacy_sheet.close()
		"more":
			bar.show_tab("more")
			legacy_sheet.open()

## A card that names a board nobody has drawn flat yet.
func _on_soon(entry: Dictionary) -> void:
	_say("%s has no flat board yet. Its island version is under More." % entry.get("title", ""))

## Opens one of the twelve. A `soon` card never gets here.
func _open(entry: Dictionary) -> void:
	if Registry.is_soon(entry):
		return
	var host: Control = FlatHost.new()
	host.setup(entry, 1)
	_mount_host(host)

## Opens something from the old game: the stage goes up first, because the
## island boards and the turn are Node3Ds that look for it by group, and
## comes down again when the host closes.
func _open_legacy(entry: Dictionary) -> void:
	legacy_sheet.close()
	_raise_stage()
	var host: Control
	if Registry.kind(entry) == "turn":
		host = load(TURN_HOST).new()
		host.setup(entry)
	else:
		host = load(ISLAND_HOST).new()
		host.setup(entry, 1)
	_mount_host(host)

## The campsite menu itself, the screen the game used to open on.
func _open_camp() -> void:
	legacy_sheet.close()
	_raise_stage()
	var camp_menu: Control = load(CAMP_MENU).new()
	camp_menu.embedded = true
	_mount_host(camp_menu)

func _mount_host(host: Control) -> void:
	host.closed.connect(func() -> void:
		host.queue_free()
		_drop_stage()
		_show_list())
	add_child(host)
	_list_root.visible = false

## Puts legacy/world/stage.tscn in the tree above this screen's canvas, for
## as long as something needs it. world/main.tscn has not carried one since
## 2026-09-18, so the flat game never pays for a World3D.
func _raise_stage() -> void:
	if get_tree().get_first_node_in_group("stage") != null:
		return
	var root := _world_root()
	if root == null:
		return
	_stage = load(STAGE_SCENE).instantiate()
	root.add_child(_stage)
	root.move_child(_stage, 0)

func _drop_stage() -> void:
	if is_instance_valid(_stage):
		_stage.queue_free()
	_stage = null

## The node under the window root that the stage belongs beside: Main in the
## shipped tree, and whatever a harness put at the top in a harness.
func _world_root() -> Node:
	var n: Node = self
	while n.get_parent() != null and not (n.get_parent() is Window):
		n = n.get_parent()
	return n
