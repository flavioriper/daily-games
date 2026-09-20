extends Control

## Shell around any PuzzleBase, with no chrome of its own: the board slot,
## the solved overlay, the rules and settings sheets, the spawn, the
## analytics and every button handler. Puzzles never draw chrome themselves,
## so they stay comparable; the host asks each puzzle what it supports
## (PuzzleBase.capabilities) and the panels hide the rest.
##
## The rows are the subclass's business. `_build_chrome` and `_enter` are the
## two methods a shell fills, and there are two shells: ui/flat/flat_host.gd
## (the nine flat screens) and legacy/ui/island_host.gd (the boards on the
## stage). Until 2026-09-18 the island rows were built here and the flat host
## inherited and overrode them, which meant every flat board loaded the
## carved sign, the model views and the whole toon pipeline behind them.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md.

signal closed

const Pal = preload("res://core/palette.gd")
const DailySeed = preload("res://core/daily.gd")
const Progress = preload("res://core/progress.gd")
const Analytics = preload("res://core/analytics.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const SafeArea = preload("res://ui/safe_area.gd")
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

## The rows of this shell's chrome, top to bottom, into `root`. The host
## itself has no opinion about them: it fills `top_bar`, `day_card` and
## (optionally) `action_bar`, and every handler below talks to the puzzle
## through those fields. Two shells implement it -- ui/flat/flat_host.gd for
## the nine flat screens and legacy/ui/island_host.gd for the boards still on
## the stage -- and neither is the default, because a host with no chrome is
## a bug rather than a fallback.
func _build_chrome(_root: VBoxContainer) -> void:
	push_error("PuzzleHost: a shell must override _build_chrome")


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

## The chrome arrives. Each shell plays its own rows in; the base has none.
func _enter() -> void:
	pass


func _spawn(the_seed: int) -> void:
	if is_instance_valid(_puzzle):
		_puzzle.queue_free()
	var script: GDScript = load(_entry.script)
	_puzzle = script.new()
	_puzzle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_holder.add_child(_puzzle)
	_puzzle.solved.connect(_on_solved)
	# Hidden Word's ending that is not a solve (PuzzleBase.finish_unsolved).
	# The thirteen legacy boards stand on legacy/core/stage_board.gd, a frozen
	# copy of this contract that predates `ended` and must stay frozen (see
	# spec 2026-09-19-hidden-word-flat-design.md, section 8): connecting
	# unconditionally throws on every one of them, and the throw aborts this
	# function before start() ever runs, leaving a blank dead board.
	if _puzzle.has_signal("ended"):
		_puzzle.ended.connect(_refresh)
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
