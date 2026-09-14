extends Control

## Shell around any PuzzleBase: the concept HUD (top bar, day card, rules
## card, board slot, action bar, motto footer), the solved overlay and the
## settings sheet. Puzzles never draw chrome themselves, so they stay
## comparable; the host asks each puzzle what it supports
## (PuzzleBase.capabilities) and the panels hide the rest.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md.

signal closed

const Pal = preload("res://core/palette.gd")
const DailySeed = preload("res://core/daily.gd")
const Progress = preload("res://core/progress.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const TopBar = preload("res://ui/hud/top_bar.gd")
const DayCard = preload("res://ui/hud/day_card.gd")
const RulesCard = preload("res://ui/hud/rules_card.gd")
const ActionBar = preload("res://ui/hud/action_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")

const MARGIN := 40
const GAP := 20
## Entrance delays per panel (spec section 5).
const ENTER_TOP := 0.0
const ENTER_CARDS := 0.1
const ENTER_ACTIONS := 0.2
const ENTER_FOOTER := 0.3
const ENTER_FOOTER_FADE := 0.25

var _puzzle: Control
var _entry: Dictionary
var _difficulty: int = 0

var top_bar: Control
var day_card: Control
var rules_card: Control
var action_bar: Control
var settings_sheet: Control
var footer: Label
var _board_holder: Control
var _card: Panel
var _overlay: Control
var _overlay_label: Label

func setup(entry: Dictionary, difficulty: int) -> void:
	_entry = entry
	_difficulty = difficulty

func _ready() -> void:
	theme = CozyTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets := _safe_insets()
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", MARGIN)
	margins.add_theme_constant_override("margin_right", MARGIN)
	margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	add_child(margins)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", GAP)
	margins.add_child(root)

	# --- top bar ---
	top_bar = TopBar.new(_entry.get("title", ""), _entry.get("motto", ""))
	top_bar.name = "TopBar"
	top_bar.back.connect(func() -> void: closed.emit())
	top_bar.undo.connect(_on_undo)
	top_bar.hint.connect(_on_hint)
	top_bar.settings.connect(_open_settings)
	root.add_child(top_bar)

	# --- cards row ---
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", GAP)
	root.add_child(cards)
	day_card = DayCard.new()
	day_card.name = "DayCard"
	cards.add_child(day_card)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_child(spacer)
	rules_card = RulesCard.new()
	rules_card.name = "RulesCard"
	cards.add_child(rules_card)

	# --- board slot ---
	_board_holder = Control.new()
	_board_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_board_holder)
	_card = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.PAPER
	sb.set_corner_radius_all(32)
	_card.add_theme_stylebox_override("panel", sb)
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_holder.add_child(_card)

	# --- action bar and footer ---
	action_bar = ActionBar.new()
	action_bar.name = "ActionBar"
	action_bar.reset.connect(_on_reset)
	action_bar.check.connect(_on_check)
	root.add_child(action_bar)
	footer = Label.new()
	footer.theme_type_variation = "Motto"
	footer.text = String(_entry.get("footer", "")).to_upper()
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.visible = footer.text != ""
	root.add_child(footer)

	_build_overlay()
	settings_sheet = SettingsSheet.new()
	settings_sheet.name = "SettingsSheet"
	settings_sheet.reduce_changed.connect(_on_reduce_changed)
	settings_sheet.new_puzzle.connect(_on_new)
	add_child(settings_sheet)

	_spawn(DailySeed.seed_for(_entry.id, _difficulty))
	_enter()

## Safe-area insets (top, bottom) in viewport units. Only phones report one
## that matters; the desktop's value describes the screen, not the window.
func _safe_insets() -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var k := get_viewport_rect().size.y / float(win.y)
	return Vector2(maxf(0.0, float(safe.position.y)) * k, maxf(0.0, float(win.y - safe.end.y)) * k)

func _build_overlay() -> void:
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(Pal.PAPER, 0.85)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CozyTheme.paper_card())
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.custom_minimum_size.x = 640
	_overlay.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	var title := Label.new()
	title.theme_type_variation = "CardTitle"
	title.text = "Solved"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_overlay_label = Label.new()
	_overlay_label.theme_type_variation = "CardBody"
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_overlay_label)
	var tap := Button.new()
	tap.flat = true
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap.pressed.connect(func() -> void: _overlay.visible = false)
	_overlay.add_child(tap)

## The HUD arrives: top bar first, cards, then the action bar and the footer.
func _enter() -> void:
	top_bar.enter(ENTER_TOP)
	day_card.enter(ENTER_CARDS)
	rules_card.enter(ENTER_CARDS)
	action_bar.enter(ENTER_ACTIONS)
	Motion.appear(footer, 0.0, 1.0, ENTER_FOOTER_FADE, ENTER_FOOTER)

func _spawn(the_seed: int) -> void:
	if is_instance_valid(_puzzle):
		_puzzle.queue_free()
	var script: GDScript = load(_entry.script)
	_puzzle = script.new()
	_puzzle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_holder.add_child(_puzzle)
	_puzzle.solved.connect(_on_solved)
	_puzzle.moved.connect(_refresh)
	_puzzle.focus_changed.connect(_refresh)
	var rng := RandomNumberGenerator.new()
	rng.seed = the_seed
	_puzzle.start(rng, _difficulty)
	_card.visible = not _puzzle.is_3d()
	_overlay.visible = false
	Progress.touch()
	day_card.set_day(Progress.day(), Progress.island_name())
	_refresh()

## Every panel re-reads the puzzle.
func _refresh() -> void:
	var p = _puzzle if is_instance_valid(_puzzle) else null
	top_bar.refresh(p)
	rules_card.refresh(p)
	action_bar.refresh(p)

func _on_undo() -> void:
	if is_instance_valid(_puzzle):
		_puzzle.undo()
		_refresh()

func _on_hint() -> void:
	if is_instance_valid(_puzzle):
		_puzzle.hint()
		_refresh()

func _on_check() -> void:
	if is_instance_valid(_puzzle):
		var wrong: int = _puzzle.check()
		if wrong == 0:
			action_bar.all_good()
		_refresh()

func _on_reset() -> void:
	if is_instance_valid(_puzzle):
		_puzzle.reset_board()
		_overlay.visible = false
		_refresh()

func _on_new() -> void:
	# Prototype affordance only. The shipped game gets one puzzle per day.
	_spawn(randi())

func _open_settings() -> void:
	settings_sheet.open()

## The reduce-motion toggle: persist, still the world, refresh the chrome.
func _on_reduce_changed(on: bool) -> void:
	Motion.reduce = on
	Motion.save_settings()
	var stage: Node = get_tree().get_first_node_in_group("stage")
	if stage != null and stage.get("ambient") != null:
		stage.ambient.refresh()
	_refresh()

func _on_solved() -> void:
	_overlay_label.text = "%.1fs  ·  %d moves\n\n%s" % [
		_puzzle.elapsed, _puzzle.moves, _puzzle.share_glyphs()
	]
	_overlay.visible = true
	_refresh()
