extends "res://ui/puzzle_host.gd"

## The flat screen's shell: the same host as every other board's (every
## handler, the sheets, the analytics and the spawn are inherited) with the
## chrome swapped for the reference's cream rows, and the win screen in place
## of the solved overlay. All eighteen grid cards ask for it through the
## registry's `shell` field, Binairo through Rings; the island boards keep
## ui/puzzle_host.gd's rows.
##
## The one row the flat screens do not share is the tray: Binairo arms a
## brush from three symbol chips, Code Break seats a friend from six or
## seven, Balance steps a weight from one card per fruit, Nonogram paints
## with one of two tile chips, and Shikaku picks nothing up at all. Queens
## arms a queen or a cross chip in the same tile tray, built with
## `TileTray.QUEENS` in place of Nonogram's `TileTray.MOSAIC`, and Mushroom
## Patch arms a mushroom or a pebble chip in that same tray again, built with
## `TileTray.PATCH`. Hidden Word types instead: its tray is a keyboard. And
## Sudoku's ten digit chips fire straight through `_on_pick` to the board's
## own `pick()`, the way Code Break's friends do, rather than through
## `_on_brush`: nothing on that row stays armed except the pencil, which the
## board owns. The registry names which (`"tray": "friends"`, `"weights"`,
## `"tiles"`, `"queens"`, `"patch"`, `"keys"`, `"digits"`, `"none"`), because
## the host lays out its rows before it has a puzzle to ask.
##
## Nor do they all carry an actions row. A board that is its own continuous
## check has nothing to put in one -- no Check, and Reset riding up in the
## top bar instead -- so the registry can say `"actions": false` and the row
## is never built; the bottom slot is then measured from whatever rows it
## actually got rather than from a constant, since the three screens no
## longer agree on its height.
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
const FriendTray = preload("res://ui/flat/friend_tray.gd")
const WeightTray = preload("res://ui/flat/weight_tray.gd")
const TileTray = preload("res://ui/flat/tile_tray.gd")
const KeyBoard = preload("res://ui/flat/key_board.gd")
const DigitPad = preload("res://ui/flat/digit_pad.gd")
const FlatActions = preload("res://ui/flat/flat_actions.gd")
const WellDone = preload("res://ui/flat/well_done.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Icons = preload("res://ui/icons.gd")

## The two slots' heights while playing and on the win (spec section 8). The
## bottom's playing height is measured in _build_chrome from the rows it
## built, because a screen may have no actions row and a tray of its own
## height.
const TOP_PLAY := 180.0 + 20.0 + 120.0
const TOP_WIN := WellDone.HEIGHT
const BOTTOM_WIN := 120.0 + 20.0 + 130.0
const CAMP_BUTTON := 130.0
## Entrance delays per row (the island's order; ENTER_TOP, ENTER_CARDS and
## ENTER_ACTIONS come from the base host).
const ENTER_TRAY := 0.2
## The win: the board's wave first, then the layout change and the panels.
const WIN_AFTER := 0.8
const WIN_AFTER_STILL := 0.2
const SLOT_TIME := 0.45
const CHROME_OUT := 0.25
const ART_DELAY := 0.2
const STATS_DELAY := 0.35
const STATS_SLIDE := 0.35

var tray: Control
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
## The bottom slot's playing height, summed from the rows this screen has.
var _bottom_play := 0.0
## set_tray is a one-time handoff, not a per-move refresh: _refresh() runs on
## every move and every focus change, and re-handing the same tray each time
## would be harmless today but is not what "the host hands it over once,
## after the board is spawned" means. Cleared by _spawn so a new board gets
## its own handoff.
var _tray_given := false

func _ready() -> void:
	super()
	# Nothing 3D shows under the opaque page, so nothing 3D is drawn while
	# this screen is up; the menu's _show_list brings the setting back and
	# _exit_tree shows the stage again.
	_stage = get_tree().get_first_node_in_group("stage")
	if _stage != null:
		_stage.show_setting(false)
		_stage.visible = false
	if _completed_daily:
		call_deferred("_restore_completed_daily")

## A completed daily has no saved move history to replay. Restore the board's
## terminal lifecycle state, then use the same solved presentation as a live
## solve so the player lands on the finished screen immediately.
func _restore_completed_daily() -> void:
	if _won or not is_instance_valid(_puzzle):
		return
	if _puzzle.has_method("restore_completed"):
		_puzzle.restore_completed()
	_refresh()
	_show_win()

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
	var with_actions: bool = bool(_entry.get("actions", true))
	top_bar = FlatTopBar.new(
		_entry.get("title", ""),
		_entry.get("motto", ""),
		not with_actions,
		str(_entry.get("id", "")) == "binairo"
	)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.undo.connect(_on_undo)
	top_bar.reset.connect(_on_reset)
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
	# A board that caps its own height keeps the card to it on every relayout,
	# including the win's slide.
	_board_holder.resized.connect(_fit_card)
	# Flat parchment under the grid, as the mock has it: the paper wash the
	# rest of the chrome wears reads as a stain across a field of small tiles.
	_card.material = null

	# --- the bottom slot: palette and actions, then the win's stats and button ---
	_bottom_slot = Control.new()
	_bottom_slot.name = "BottomSlot"
	_bottom_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bottom_slot)
	_bottom_stack = _stack(_bottom_slot)
	# The rows this screen actually has, so the slot's playing height is the
	# sum of them and the gaps between them -- never a constant, since the
	# four screens no longer agree on either row.
	var rows: Array[float] = []
	match str(_entry.get("tray", "symbols")):
		"none":
			# Shikaku picks nothing up: there is no brush, no seat and no
			# weight, so the row is never built.
			tray = null
		"friends":
			tray = FriendTray.new()
			tray.pick.connect(_on_pick)
			rows.append(FriendTray.HEIGHT)
		"weights":
			tray = WeightTray.new()
			tray.step.connect(_on_step)
			rows.append(WeightTray.HEIGHT)
		"tiles":
			tray = TileTray.new()
			tray.pick.connect(_on_brush)
			rows.append(TileTray.HEIGHT)
		"queens":
			# Queens' pair: the same tray as Nonogram's, with the queen set.
			tray = TileTray.new(TileTray.QUEENS)
			tray.pick.connect(_on_brush)
			rows.append(TileTray.HEIGHT)
		"patch":
			# Mushroom Patch's pair: the same tray again, with the patch set.
			tray = TileTray.new(TileTray.PATCH)
			tray.pick.connect(_on_brush)
			rows.append(TileTray.HEIGHT)
		"keys":
			# Hidden Word types: the tray is a keyboard, and the board takes
			# its three signals directly rather than through a brush.
			tray = KeyBoard.new()
			tray.key.connect(func(l: String) -> void:
				if is_instance_valid(_puzzle) and _puzzle.has_method("type_letter"):
					_puzzle.type_letter(l))
			tray.commit.connect(func() -> void:
				if is_instance_valid(_puzzle) and _puzzle.has_method("commit_row"):
					_puzzle.commit_row())
			tray.erase.connect(func() -> void:
				if is_instance_valid(_puzzle) and _puzzle.has_method("erase_letter"):
					_puzzle.erase_letter())
			rows.append(KeyBoard.HEIGHT)
		"digits":
			# Sudoku's ten chips. A chip is a direct action, so it goes to
			# _on_pick and the board's pick(), not to _on_brush: nothing here
			# stays armed except the pencil, and the board owns that.
			tray = DigitPad.new()
			tray.pick.connect(_on_pick)
			rows.append(DigitPad.HEIGHT)
		_:
			tray = SymbolTray.new()
			tray.pick.connect(_on_brush)
			rows.append(SymbolTray.HEIGHT)
	if tray != null:
		tray.name = "Tray"
		_bottom_stack.add_child(tray)
	if with_actions:
		action_bar = FlatActions.new()
		action_bar.name = "Actions"
		action_bar.reset.connect(_on_reset)
		action_bar.check.connect(_on_check)
		_bottom_stack.add_child(action_bar)
		rows.append(FlatActions.BUTTON.y)
	_bottom_play = GAP * maxi(rows.size() - 1, 0)
	for row in rows:
		_bottom_play += row
	_bottom_slot.custom_minimum_size.y = _bottom_play
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
	if tray != null:
		tray.enter(ENTER_TRAY)
	if action_bar != null:
		action_bar.enter(ENTER_ACTIONS)

func _refresh() -> void:
	# The one board that talks back to its tray: Hidden Word paints the keys
	# from the row it has just marked. Every other tray is driven by the host.
	# Handed over once per spawn, not on every move/focus refresh -- _refresh
	# runs on both.
	if not _tray_given and tray != null and is_instance_valid(_puzzle) and _puzzle.has_method("set_tray"):
		_puzzle.set_tray(tray)
		_tray_given = true
	super()
	var p = _puzzle if is_instance_valid(_puzzle) else null
	if tray != null:
		tray.refresh(p)

## The weights tray asked for one unit onto or off a kind. The board decides
## -- it owns the rules and the sprout's reason for a refusal -- and the row
## is re-read either way.
func _on_step(i: int, delta: int) -> void:
	if is_instance_valid(_puzzle) and _puzzle.has_method("step_weight"):
		_puzzle.step_weight(i, delta)
		_refresh()

## A board may want less of the slot than it was given: Balance caps its
## bands, so a short column leaves the rest as air above the weight cards
## rather than a tall card half full of nothing. A board that says nothing
## fills the slot, as the first three do.
##
## Where the leftover goes is the board's too (`card_centred`). Balance keeps
## it all below, because a gap under the day card reads as a mistake and a gap
## above the cards reads as room. Tents halves it: its grid is square while
## its space is tall, so the cell is capped by the width and there is slack
## however it is cut -- air above and below reads as centring where all of it
## below reads as a board that fell over.
func _fit_card() -> void:
	if _board_holder == null or _card == null:
		return
	var want: float = _board_holder.size.y
	var centred := false
	if is_instance_valid(_puzzle) and _puzzle.has_method("card_height"):
		want = minf(want, _puzzle.card_height(_board_holder.size.y))
		centred = _puzzle.has_method("card_centred") and _puzzle.card_centred()
	var slack: float = _board_holder.size.y - want
	var above: float = slack * 0.5 if centred else 0.0
	_card.offset_top = above
	_card.offset_bottom = above - slack

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
		_bottom_slot.custom_minimum_size.y = _bottom_play
		well_done.visible = false
		_win_stack.visible = false
		for stack in [_top_stack, _bottom_stack]:
			stack.visible = true
			stack.modulate.a = 1.0
			stack.position.y = 0.0
		_enter()
	_tray_given = false
	super(the_seed)
	_fit_card()

## The board's wave plays first; then the rows make way for the win screen.
func _on_solved() -> void:
	daily_completed.emit(String(_entry.get("id", "")))
	Analytics.track("puzzle_complete", _stats())
	_refresh()
	# A board whose win has an animation of its own to play out first says
	# how long it needs; Code Break's lids and code take nearly two seconds.
	var wait := WIN_AFTER_STILL if Motion.reduce else WIN_AFTER
	if is_instance_valid(_puzzle) and _puzzle.has_method("win_delay"):
		wait = _puzzle.win_delay()
	get_tree().create_timer(wait).timeout.connect(_show_win)

func _show_win() -> void:
	if _won or not is_instance_valid(_puzzle):
		return
	_won = true
	# A board whose answer is a row of characters shows it instead of the
	# sun and the moon (flat_win).
	if _puzzle.has_method("flat_win"):
		var art: Dictionary = _puzzle.flat_win()
		well_done.set_cast(art.get("faces", []), String(art.get("subtitle", "")),
			art.get("labels", []))
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
	Motion.slide(_bottom_slot, "custom_minimum_size:y", _bottom_play, BOTTOM_WIN, SLOT_TIME, 0.0, false)
	well_done.enter(ART_DELAY)
	_win_stack.visible = true
	Motion.slide(_win_stack, "position:y", 120.0, 0.0, STATS_SLIDE, STATS_DELAY)
	Motion.appear(_win_stack, 0.0, 1.0, 0.2, STATS_DELAY)

## "m:ss · N moves · N hints" for the stats card.
func _stats_text() -> String:
	var secs := int(round(_puzzle.elapsed))
	var hints: int = _puzzle.hints_used
	var moves: int = _puzzle.moves
	return "%d:%02d · %d %s · %d %s" % [
		secs / 60, secs % 60,
		moves, "move" if moves == 1 else "moves",
		hints, "hint" if hints == 1 else "hints"]
