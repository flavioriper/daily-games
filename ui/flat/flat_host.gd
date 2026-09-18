extends "res://ui/puzzle_host.gd"

## The flat screen's shell: the same host as every other board's (every
## handler, the sheets, the analytics and the spawn are inherited) with the
## chrome swapped for the reference's cream rows, and the win screen in place
## of the solved overlay. Only Binairo asks for it, through the registry's
## `shell` field; the island boards keep ui/puzzle_host.gd's rows.
##
## Two slots hold the rows above and below the board, each a plain Control
## whose minimum height the win tweens: the top grows by 300 and the bottom
## shrinks to the stats card and the button, and the host's own VBox slides
## the board card down between them, so the win screen is a layout change
## and not a second scene.
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, sections
## 3, 8 (as amended) and 9.3.

const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const FlatDayCard = preload("res://ui/flat/flat_day_card.gd")
const SymbolTray = preload("res://ui/flat/symbol_tray.gd")
const FlatActions = preload("res://ui/flat/flat_actions.gd")
const TipCard = preload("res://ui/flat/tip_card.gd")
const WellDone = preload("res://ui/flat/well_done.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Icons = preload("res://ui/icons.gd")

## The two slots' heights while playing and on the win (spec section 8).
const TOP_PLAY := 180.0 + 20.0 + 120.0
const TOP_WIN := WellDone.HEIGHT
const BOTTOM_PLAY := 150.0 + 20.0 + 130.0 + 20.0 + 140.0
const BOTTOM_WIN := 120.0 + 20.0 + 130.0
const CAMP_BUTTON := 130.0
## Entrance delays per row (the island's order; ENTER_TOP, ENTER_CARDS and
## ENTER_ACTIONS come from the base host).
const ENTER_TRAY := 0.2
const ENTER_TIP := 0.3
## The win: the board's wave first, then the layout change and the panels.
const WIN_AFTER := 0.8
const WIN_AFTER_STILL := 0.2
const SLOT_TIME := 0.45
const CHROME_OUT := 0.25
const ART_DELAY := 0.2
const STATS_DELAY := 0.35
const STATS_SLIDE := 0.35

var tray: Control
var tip_card: Control
var well_done: Control
var stats_card: Control
var camp_button: Button
var _top_slot: Control
var _bottom_slot: Control
var _top_stack: VBoxContainer
var _bottom_stack: VBoxContainer
var _win_stack: VBoxContainer
var _stage: Node
var _won := false

func _ready() -> void:
	super()
	# Nothing 3D shows under the opaque page, so nothing 3D is drawn while
	# this screen is up; the menu's _show_list brings the setting back and
	# _exit_tree shows the stage again.
	_stage = get_tree().get_first_node_in_group("stage")
	if _stage != null:
		_stage.show_setting(false)
		_stage.visible = false

func _exit_tree() -> void:
	if _stage != null and is_instance_valid(_stage):
		_stage.visible = true

func _build_chrome(root: VBoxContainer) -> void:
	# The page: paper under everything, behind the margins.
	var page := ColorRect.new()
	page.name = "Page"
	page.color = Pal.PAPER
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	move_child(page, 0)

	# --- the top slot: top bar and day card, and the win art over them ---
	_top_slot = Control.new()
	_top_slot.name = "TopSlot"
	_top_slot.custom_minimum_size.y = TOP_PLAY
	_top_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_top_slot)
	_top_stack = _stack(_top_slot)
	top_bar = FlatTopBar.new(_entry.get("title", ""), _entry.get("motto", ""))
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.undo.connect(_on_undo)
	top_bar.hint.connect(_on_hint)
	top_bar.settings.connect(_open_settings)
	_top_stack.add_child(top_bar)
	day_card = FlatDayCard.new()
	day_card.name = "DayCard"
	_top_stack.add_child(day_card)
	well_done = WellDone.new()
	well_done.name = "WellDone"
	well_done.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top_slot.add_child(well_done)

	# --- the board card ---
	_board_holder = Control.new()
	_board_holder.name = "BoardSlot"
	_board_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_board_holder)
	_card = Panel.new()
	_card.name = "BoardCard"
	_card.add_theme_stylebox_override("panel", CozyTheme.card(Pal.PARCHMENT, 32, Pal.LINE, 6, 24))
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_holder.add_child(_card)
	# Flat parchment under the grid, as the mock has it: the paper wash the
	# rest of the chrome wears reads as a stain across a field of small tiles.
	_card.material = null

	# --- the bottom slot: palette, actions and tip, then the win's stats and button ---
	_bottom_slot = Control.new()
	_bottom_slot.name = "BottomSlot"
	_bottom_slot.custom_minimum_size.y = BOTTOM_PLAY
	_bottom_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bottom_slot)
	_bottom_stack = _stack(_bottom_slot)
	tray = SymbolTray.new()
	tray.name = "Tray"
	tray.pick.connect(_on_brush)
	_bottom_stack.add_child(tray)
	action_bar = FlatActions.new()
	action_bar.name = "Actions"
	action_bar.reset.connect(_on_reset)
	action_bar.check.connect(_on_check)
	_bottom_stack.add_child(action_bar)
	tip_card = TipCard.new()
	tip_card.name = "TipCard"
	tip_card.open.connect(_open_rules)
	_bottom_stack.add_child(tip_card)
	_win_stack = _stack(_bottom_slot)
	_win_stack.name = "WinStack"
	_win_stack.visible = false
	stats_card = FlatDayCard.new()
	stats_card.name = "StatsCard"
	_win_stack.add_child(stats_card)
	camp_button = IconButton.new("", "Back to camp", "SunButton")
	camp_button.name = "CampButton"
	camp_button.custom_minimum_size.y = CAMP_BUTTON
	camp_button.pressed.connect(_on_back)
	_win_stack.add_child(camp_button)
	# The chevron at the button's right edge, where the reference puts it.
	var chevron := Control.new()
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	chevron.offset_left = -90.0
	chevron.offset_right = -30.0
	chevron.offset_top = -30.0
	chevron.offset_bottom = 30.0
	chevron.draw.connect(func() -> void: Icons.paint(chevron, "chevron_right", Rect2(Vector2.ZERO, chevron.size), Pal.SURFACE))
	camp_button.add_child(chevron)

	# The base host's fields this layout has no panel for.
	help_card = Control.new()
	footer = Label.new()
	footer.visible = false
	add_child(footer)

## A column of rows across the top of `slot`, sized to its own content, so a
## tween on the slot's minimum height moves the rows around it and not them.
func _stack(slot: Control) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", GAP)
	slot.add_child(stack)
	# Placed and sized by hand rather than anchored: a Control with opposite
	# anchors set warns when its size is written, and this one is written
	# on every relayout.
	var fit := func() -> void:
		stack.position = Vector2(0.0, stack.position.y)
		stack.size = Vector2(slot.size.x, stack.get_combined_minimum_size().y)
	slot.resized.connect(fit)
	stack.minimum_size_changed.connect(fit)
	fit.call()
	return stack

func _enter() -> void:
	top_bar.enter(ENTER_TOP)
	day_card.enter(ENTER_CARDS)
	tray.enter(ENTER_TRAY)
	action_bar.enter(ENTER_ACTIONS)
	tip_card.enter(ENTER_TIP)

func _refresh() -> void:
	super()
	var p = _puzzle if is_instance_valid(_puzzle) else null
	tray.refresh(p)
	tip_card.refresh(p)

func _on_brush(v: int) -> void:
	if is_instance_valid(_puzzle) and _puzzle.has_method("set_brush"):
		_puzzle.set_brush(v)
		_refresh()

## A new board (Reset never spawns one, but the settings sheet's New does):
## the win screen, if it was up, goes back to the playing rows at once.
func _spawn(the_seed: int) -> void:
	if _won:
		_won = false
		_top_slot.custom_minimum_size.y = TOP_PLAY
		_bottom_slot.custom_minimum_size.y = BOTTOM_PLAY
		well_done.visible = false
		_win_stack.visible = false
		for stack in [_top_stack, _bottom_stack]:
			stack.visible = true
			stack.modulate.a = 1.0
			stack.position.y = 0.0
		_enter()
	super(the_seed)

## The board's wave plays first; then the rows make way for the win screen.
func _on_solved() -> void:
	Analytics.track("puzzle_complete", _stats())
	_refresh()
	var wait := WIN_AFTER_STILL if Motion.reduce else WIN_AFTER
	get_tree().create_timer(wait).timeout.connect(_show_win)

func _show_win() -> void:
	if _won or not is_instance_valid(_puzzle):
		return
	_won = true
	stats_card.set_day(Progress.day(), Progress.island_name())
	stats_card.set_stats(_stats_text())
	# The playing rows leave: up and out above, down and out below.
	Motion.slide(_top_stack, "position:y", 0.0, -60.0, CHROME_OUT, 0.0, false)
	Motion.appear(_top_stack, 1.0, 0.0, CHROME_OUT)
	Motion.slide(_bottom_stack, "position:y", 0.0, 100.0, CHROME_OUT, 0.0, false)
	Motion.appear(_bottom_stack, 1.0, 0.0, CHROME_OUT)
	get_tree().create_timer(CHROME_OUT).timeout.connect(func() -> void:
		_top_stack.visible = false
		_bottom_stack.visible = false)
	# The slots make room; the VBox slides the board card down between them.
	Motion.slide(_top_slot, "custom_minimum_size:y", TOP_PLAY, TOP_WIN, SLOT_TIME, 0.0, false)
	Motion.slide(_bottom_slot, "custom_minimum_size:y", BOTTOM_PLAY, BOTTOM_WIN, SLOT_TIME, 0.0, false)
	well_done.enter(ART_DELAY)
	_win_stack.visible = true
	Motion.slide(_win_stack, "position:y", 120.0, 0.0, STATS_SLIDE, STATS_DELAY)
	Motion.appear(_win_stack, 0.0, 1.0, 0.2, STATS_DELAY)

## "m:ss · N moves · N hints" for the stats card.
func _stats_text() -> String:
	var secs := int(round(_puzzle.elapsed))
	var hints: int = _puzzle.hints_used
	return "%d:%02d · %d moves · %d %s" % [secs / 60, secs % 60, _puzzle.moves, hints, "hint" if hints == 1 else "hints"]
