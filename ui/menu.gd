extends Control

## The first screen: the wordmark and the day card over the island, one paper
## card per puzzle beneath, and the motto footer, all in the HUD's own theme
## and motion. Opening a card hands the puzzle to a PuzzleHost and hides the
## list; the host's close shows it again. The host is always this node's last
## child while it lives, which the harnesses rely on.
## Theme: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 4.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Progress = preload("res://core/progress.gd")
const Registry = preload("res://ui/registry.gd")
const Host = preload("res://ui/puzzle_host.gd")
const CozyTheme = preload("res://ui/theme.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const TopBar = preload("res://ui/hud/top_bar.gd")
const DayCard = preload("res://ui/hud/day_card.gd")
const PuzzleCard = preload("res://ui/hud/puzzle_card.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")

## The menu's own sign, rendered from TITLE and MOTTO below by
## tools/build_signs.py.
const SIGN := "daily"
## Taller than a puzzle's row allows: this one only shares its row with the
## settings button, and the first screen's own name should carry more weight
## than the signs listed beneath it.
const SIGN_HEIGHT := 250.0
const TITLE := "Daily"
const MOTTO := "Small puzzles · Brighter days"
const FOOTER := "Pick one · Play · Come back tomorrow"
const MARGIN := 40
const GAP := 20
## Entrance delays: the HUD's own beats, then a wave down the list.
const ENTER_TOP := 0.0
const ENTER_DAY := 0.1
const ENTER_CARDS := 0.15
const CARD_STEP := 0.05
const CARD_CAP := 0.4
const ENTER_FOOTER := 0.3
const ENTER_FOOTER_FADE := 0.25

var top_bar: Control
var day_card: Control
var settings_sheet: Control
var footer: Label
var cards: Array = []
var _list_root: Control

func _ready() -> void:
	theme = CozyTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_list()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	_show_list()

func _build_list() -> void:
	_list_root = Control.new()
	_list_root.name = "List"
	_list_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_list_root)
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

	# --- wordmark and settings ---
	top_bar = TopBar.new(SIGN, TITLE, MOTTO, false)
	top_bar.name = "TopBar"
	top_bar.sign_height = SIGN_HEIGHT
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	root.add_child(top_bar)
	top_bar.refresh(null)

	# --- day card, hugging the left as it does in the game ---
	var day_row := HBoxContainer.new()
	root.add_child(day_row)
	day_card = DayCard.new()
	day_card.name = "DayCard"
	day_row.add_child(day_card)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_row.add_child(spacer)

	# --- the list ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", GAP)
	scroll.add_child(col)
	for i in Registry.PUZZLES.size():
		var entry: Dictionary = Registry.PUZZLES[i]
		var card := PuzzleCard.new(entry)
		card.name = "Card_" + entry.id
		card.open.connect(_open.bind(entry))
		col.add_child(card)
		cards.append(card)

	# --- footer ---
	footer = Label.new()
	footer.theme_type_variation = "Motto"
	footer.text = FOOTER.to_upper()
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(footer)

## Shows the list with the day card current and plays the entrance; at start
## and on every return from a puzzle. Opening the app is what counts a day.
func _show_list() -> void:
	_list_root.visible = true
	Progress.touch()
	day_card.set_day(Progress.day(), Progress.island_name())
	_enter()

func _enter() -> void:
	top_bar.enter(ENTER_TOP)
	day_card.enter(ENTER_DAY)
	for i in cards.size():
		cards[i].enter(ENTER_CARDS + Motion.stagger(i, CARD_STEP, CARD_CAP))
	Motion.appear(footer, 0.0, 1.0, ENTER_FOOTER_FADE, ENTER_FOOTER)

func _open(entry: Dictionary) -> void:
	var host = Host.new()
	host.setup(entry, 1)
	host.closed.connect(func():
		host.queue_free()
		_show_list()
	)
	add_child(host)
	_list_root.visible = false
