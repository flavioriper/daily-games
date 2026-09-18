extends Control

## Shell around any PuzzleBase: the concept HUD (top bar, day card, help
## card, board slot, action bar, motto footer), the solved overlay, the rules
## sheet and the settings sheet. Puzzles never draw chrome themselves, so they stay
## comparable; the host asks each puzzle what it supports
## (PuzzleBase.capabilities) and the panels hide the rest.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md.

signal closed

const Pal = preload("res://core/palette.gd")
const DailySeed = preload("res://core/daily.gd")
const Progress = preload("res://core/progress.gd")
const Analytics = preload("res://core/analytics.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const TopBar = preload("res://ui/hud/top_bar.gd")
const DayCard = preload("res://ui/hud/day_card.gd")
const HelpCard = preload("res://ui/hud/help_card.gd")
const ActionBar = preload("res://ui/hud/action_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const RulesSheet = preload("res://ui/hud/rules_sheet.gd")

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
var help_card: Control
var action_bar: Control
var settings_sheet: Control
var rules_sheet: Control
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
	var insets := SafeArea.insets(self)
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

	_build_chrome(root)
	_build_overlay()
	rules_sheet = RulesSheet.new()
	rules_sheet.name = "RulesSheet"
	add_child(rules_sheet)
	settings_sheet = SettingsSheet.new()
	settings_sheet.name = "SettingsSheet"
	settings_sheet.reduce_changed.connect(_on_reduce_changed)
	settings_sheet.new_puzzle.connect(_on_new)
	add_child(settings_sheet)

	# A second card for the same board (the island Binairo beside the flat one)
	# names the entry it shares its day with, so both show the same puzzle.
	_spawn(DailySeed.seed_for(String(_entry.get("seed_as", _entry.id)), _difficulty))
	_enter()

## The rows of the HUD, top to bottom, into `root`: the top bar, the cards
## row, the board slot, the action bar and the motto footer. The flat host
## (ui/flat/flat_host.gd) overrides this and nothing else of the layout; every
## handler below reads the panels through the fields this fills.
func _build_chrome(root: VBoxContainer) -> void:
	# --- top bar ---
	top_bar = TopBar.new(_entry.get("title", ""), _entry.get("motto", ""))
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
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
	help_card = HelpCard.new()
	help_card.name = "HelpCard"
	help_card.open.connect(_open_rules)
	cards.add_child(help_card)

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
	action_bar.pick.connect(_on_pick)
	action_bar.piece_pick.connect(_on_pick)
	action_bar.turn_view.connect(_on_turn_view)
	action_bar.peek.connect(_on_peek)
	root.add_child(action_bar)
	footer = Label.new()
	footer.theme_type_variation = "Motto"
	footer.text = String(_entry.get("footer", "")).to_upper()
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.visible = footer.text != ""
	root.add_child(footer)


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
	help_card.enter(ENTER_CARDS)
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
	Analytics.track("puzzle_start", {
		"puzzle_id": _entry.get("id", ""),
		"difficulty": _difficulty,
		"day": Progress.day(),
	})
	_refresh()

## Every panel re-reads the puzzle. The action bar is optional: a screen
## whose board is its own continuous check has nothing to put in the row and
## never builds it (ui/flat/flat_host.gd).
func _refresh() -> void:
	var p = _puzzle if is_instance_valid(_puzzle) else null
	top_bar.refresh(p)
	rules_sheet.refresh(p)
	if action_bar != null:
		action_bar.refresh(p)

func _on_undo() -> void:
	if is_instance_valid(_puzzle):
		if _puzzle.undo():
			Analytics.track("undo_used", {"puzzle_id": _entry.get("id", "")})
		_refresh()

func _on_hint() -> void:
	if is_instance_valid(_puzzle):
		if _puzzle.hint():
			Analytics.track("hint_used", {
				"puzzle_id": _entry.get("id", ""),
				"difficulty": _difficulty,
				"hints": _puzzle.hints_used,
			})
		_refresh()

func _on_check() -> void:
	if is_instance_valid(_puzzle):
		var wrong: int = _puzzle.check()
		# A winning Check ends the game under the solved card; only a clean
		# check on a live board earns the "All good" squash.
		if wrong == 0 and not _puzzle.is_done() and action_bar != null:
			action_bar.all_good()
		Analytics.track("check_used", {
			"puzzle_id": _entry.get("id", ""),
			"difficulty": _difficulty,
			"wrong": wrong,
		})
		_refresh()

func _on_pick(i: int) -> void:
	if is_instance_valid(_puzzle):
		_puzzle.pick(i)
		_refresh()

## Turning is a look, not a move, so it never touches the move count; it is
## tracked because the point of the third dimension is whether players use it.
func _on_turn_view() -> void:
	if is_instance_valid(_puzzle):
		_puzzle.turn_view()
		Analytics.track("view_turn", {"puzzle_id": _entry.get("id", "")})
		_refresh()

## Only the press is worth an event: the release always follows it.
func _on_peek(on: bool) -> void:
	if is_instance_valid(_puzzle):
		_puzzle.peek(on)
		if on:
			Analytics.track("peek_used", {"puzzle_id": _entry.get("id", "")})
		_refresh()

func _on_reset() -> void:
	if is_instance_valid(_puzzle):
		_puzzle.reset_board()
		_overlay.visible = false
		Analytics.track("board_reset", {"puzzle_id": _entry.get("id", "")})
		_refresh()

func _on_new() -> void:
	# Prototype affordance only. The shipped game gets one puzzle per day.
	Analytics.track("new_puzzle", {"puzzle_id": _entry.get("id", "")})
	_spawn(randi())

func _open_settings() -> void:
	settings_sheet.open()

func _open_rules() -> void:
	Analytics.track("rules_opened", {"puzzle_id": _entry.get("id", "")})
	rules_sheet.open()

## The settings sheet has already persisted the toggle and stilled the world;
## the chrome re-reads it.
func _on_reduce_changed(_on: bool) -> void:
	Analytics.track("reduce_motion", {"on": _on})
	_refresh()

func _on_solved() -> void:
	_overlay_label.text = "%.1fs  ·  %d moves\n\n%s" % [
		_puzzle.elapsed, _puzzle.moves, _puzzle.share_glyphs()
	]
	_overlay.visible = true
	Analytics.track("puzzle_complete", _stats())
	_refresh()

## Leaving a board unsolved is the signal that it was too hard, too long
## or too dull, so it is worth an event of its own.
func _on_back() -> void:
	if is_instance_valid(_puzzle) and not _puzzle.is_done():
		Analytics.track("puzzle_abandon", _stats())
	closed.emit()

## What a board-level event carries: which puzzle, how hard, and how far
## the player had got.
func _stats() -> Dictionary:
	return {
		"puzzle_id": _entry.get("id", ""),
		"difficulty": _difficulty,
		"day": Progress.day(),
		"seconds": _puzzle.elapsed,
		"moves": _puzzle.moves,
		"hints": _puzzle.hints_used,
		"checks": _puzzle.checks,
	}
