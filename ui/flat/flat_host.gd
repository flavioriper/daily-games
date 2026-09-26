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
const Streak = preload("res://core/streak.gd")
const Registry = preload("res://ui/registry.gd")
const Vistas = preload("res://ui/menu/vistas.gd")

## Asks the menu to swap this board for the same card at `difficulty` (the
## win's invite to the next level up); the menu mounts a fresh host.
signal play_level(difficulty: int)

## The two slots' heights while playing and on the win (spec section 8). The
## bottom's playing height is measured in _build_chrome from the rows it
## built, because a screen may have no actions row and a tray of its own
## height.
const TOP_PLAY := 180.0 + 20.0 + 120.0
const TOP_WIN := WellDone.HEIGHT
const BOTTOM_WIN := 120.0 + 20.0 + 130.0
const CAMP_BUTTON := 130.0
## The invite to the next level up, a row of its own over Redo and Back; the
## win's bottom slot grows by it (and a gap) only when there is one to make.
const NEXT_BUTTON := 130.0
## Registry level names to their locale keys (the difficulty sheet's table).
const LEVEL_KEYS := {"Easy": "DIFF_EASY", "Medium": "DIFF_MEDIUM", "Hard": "DIFF_HARD", "Insane": "DIFF_INSANE"}
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
## How far the board's painting runs down past the day card before it has
## faded into the paper (the menu's BACKDROP_BLEED, for a shorter header).
const BACKDROP_BLEED := 90.0
const BUTTON_RADIUS := 40

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
var _backdrop: ColorRect
## The colour of the card this board was opened from (the menu's
## `Pal.CAT[index]`), worn by Check and the win's lead button.
var _accent := Pal.SUN
var _won := false
var redo_button: Button
var next_button: Button
var _next_name: Label
var _next_line: Label
var _camp_chevron: Control
## The level the win's invite would open, or -1 when there is none.
var _next_level := -1
## The bottom slot's playing height, summed from the rows this screen has.
var _bottom_play := 0.0
## set_tray is a one-time handoff, not a per-move refresh: _refresh() runs on
## every move and every focus change, and re-handing the same tray each time
## would be harmless today but is not what "the host hands it over once,
## after the board is spawned" means. Cleared by _spawn so a new board gets
## its own handoff.
var _tray_given := false
var _hearts_line := ""
## The date key of the daily this board was dealt from, taken when the daily
## seed spawned it; 0 for a board from a random seed (the settings sheet's
## New). A solve is logged under this day, not the one it ends on, so a board
## opened before 00:00 UTC and solved after still counts for its own day; a
## non-daily board earns no heart and no best time.
var _day_key := 0
## The card's span (_card_span) the board was laid out at when the win's
## slide froze it.
var _frozen := Vector2.ZERO

func _ready() -> void:
	# puzzle_host's _ready spawns the daily seed; the day is taken with it.
	_day_key = DailySeed.date_key()
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
	else:
		_warm_win()

## Draws the win's art and its stats and buttons for a couple of frames,
## all but invisible, while the board comes in: a panel's first draw is where
## its meshes are built, its glyphs are rasterised and, on gl_compatibility,
## any shader it is the first to use is compiled (the renderer precompiles
## nothing there), and on a phone that first draw landing on the win's first
## frame is a visible hitch.
func _warm_win() -> void:
	for panel: CanvasItem in [well_done, _win_stack]:
		panel.modulate.a = 0.01
		panel.visible = true
	for i in 2:
		await get_tree().process_frame
	if _won or not is_inside_tree():
		return
	for panel: CanvasItem in [well_done, _win_stack]:
		panel.visible = false
		panel.modulate.a = 1.0

## A completed daily has no saved move history to replay. Restore the board's
## terminal lifecycle state, then use the same solved presentation as a live
## solve so the player lands on the finished screen immediately.
func _restore_completed_daily() -> void:
	if _won or not is_instance_valid(_puzzle):
		return
	var saved := Progress.completed_stats(_progress_id())
	if _puzzle.has_method("restore_completed"):
		var record = saved.get("board", {})
		_puzzle.completed_record = record if record is Dictionary else {}
		_puzzle.restore_completed()
	if not saved.is_empty():
		_puzzle.elapsed = float(saved.get("seconds", _puzzle.elapsed))
		_puzzle.moves = int(saved.get("moves", _puzzle.moves))
		_puzzle.hints_used = int(saved.get("hints", _puzzle.hints_used))
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
	# The board's own banner, painted full-bleed behind the top bar and the
	# day card and faded into the paper under them: the first screen's
	# header, with the picture of the card that was tapped.
	var id := String(_entry.get("id", ""))
	for i in Registry.PUZZLES.size():
		if String(Registry.PUZZLES[i].get("id", "")) == id:
			_accent = Pal.CAT[i % Pal.CAT.size()]
	_backdrop = Vistas.board_plate(id, _accent)
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(_backdrop)
	move_child(_backdrop, 1)
	_place_backdrop()

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
		tr(String(_entry.get("motto", ""))),
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
	var paper := CozyTheme.lifted(Pal.PARCHMENT, 36, 24)
	paper.border_width_left = 2
	paper.border_width_top = 2
	paper.border_width_right = 2
	paper.border_width_bottom = 2
	paper.border_color = Color(Pal.LINE, 0.35)
	_card.add_theme_stylebox_override("panel", paper)
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_holder.add_child(_card)
	# A board that caps its own height keeps the card to it on every relayout,
	# including the win's slide.
	_board_holder.resized.connect(_fit_card)
	# Flat parchment under the grid, as the mock has it: the paper wash the
	# rest of the chrome wears reads as a stain across a field of small tiles.
	_card.material = null

	# --- the bottom slot: palette and actions, then the win's stats and buttons ---
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
		action_bar.accent = _accent
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
	_build_next_button()
	var win_buttons := HBoxContainer.new()
	win_buttons.name = "WinButtons"
	win_buttons.add_theme_constant_override("separation", GAP)
	win_buttons.custom_minimum_size.y = CAMP_BUTTON
	_win_stack.add_child(win_buttons)
	redo_button = IconButton.new("reset", "WIN_REDO", "IconButton")
	redo_button.name = "RedoButton"
	redo_button.custom_minimum_size.y = CAMP_BUTTON
	CozyTheme.lift_button(redo_button, Pal.SURFACE, BUTTON_RADIUS)
	redo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	redo_button.pressed.connect(_on_redo)
	win_buttons.add_child(redo_button)
	camp_button = IconButton.new("", "WIN_BACK", "SunButton")
	camp_button.name = "CampButton"
	camp_button.custom_minimum_size.y = CAMP_BUTTON
	camp_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camp_button.pressed.connect(_on_back)
	win_buttons.add_child(camp_button)
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
	_camp_chevron = chevron

	# The base host's fields this layout has no panel for.
	help_card = Control.new()
	footer = Label.new()
	footer.visible = false
	add_child(footer)

## The win's invite to the next level up: the level's name and its line on
## the sun (the night's ink for Insane, as on the difficulty sheet), and a
## chevron. Hidden until _show_win finds a level to offer.
func _build_next_button() -> void:
	next_button = Button.new()
	next_button.name = "NextButton"
	next_button.focus_mode = Control.FOCUS_NONE
	next_button.theme_type_variation = "SunButton"
	next_button.custom_minimum_size.y = NEXT_BUTTON
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.visible = false
	next_button.button_down.connect(func() -> void: Motion.squash(next_button, 0.10, 0.18))
	next_button.resized.connect(func() -> void: next_button.pivot_offset = next_button.size * 0.5)
	next_button.pressed.connect(_on_next)
	_win_stack.add_child(next_button)
	var text := HBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 40.0
	text.offset_right = -110.0
	text.add_theme_constant_override("separation", 20)
	next_button.add_child(text)
	_next_name = Label.new()
	_next_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_name.add_theme_font_override("font", CozyTheme.display(700))
	_next_name.add_theme_font_size_override("font_size", 44)
	_next_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_child(_next_name)
	_next_line = Label.new()
	_next_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_line.add_theme_font_override("font", CozyTheme.body(600))
	_next_line.add_theme_font_size_override("font_size", 30)
	_next_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_next_line.clip_text = true
	text.add_child(_next_line)
	var chevron := Control.new()
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	chevron.offset_left = -90.0
	chevron.offset_right = -30.0
	chevron.offset_top = -30.0
	chevron.offset_bottom = 30.0
	chevron.draw.connect(func() -> void:
		Icons.paint(chevron, "chevron_right", Rect2(Vector2.ZERO, chevron.size),
			Pal.MOON if _next_level == 3 else Pal.SURFACE))
	next_button.add_child(chevron)

## The next level up that today has not been solved yet, or -1: past one the
## player has already done is the one after it, and above Insane is nothing.
func _find_next_level() -> int:
	for level: Dictionary in _entry.get("levels", []):
		var d := int(level.get("difficulty", -1))
		if d > _difficulty and not Progress.completed(Registry.progress_id(_entry, d)):
			return d
	return -1

## Fills the invite for `_next_level` and gives the win's buttons their
## looks: the invite takes the sun and Back steps down to paper, or, with no
## invite, Back keeps the sun as it always had.
func _dress_win_buttons() -> void:
	var inviting := _next_level >= 0
	next_button.visible = inviting
	camp_button.theme_type_variation = "IconButton" if inviting else "SunButton"
	# Back leads when there is nothing to invite to, in the board's colour;
	# under an invite it steps down to lifted paper beside Redo.
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		camp_button.remove_theme_color_override(state)
	if inviting:
		CozyTheme.lift_button(camp_button, Pal.SURFACE, BUTTON_RADIUS)
	else:
		CozyTheme.accent_button(camp_button, _accent, BUTTON_RADIUS)
	_camp_chevron.visible = not inviting
	if not inviting:
		return
	var level := {}
	for l: Dictionary in _entry.get("levels", []):
		if int(l.get("difficulty", -1)) == _next_level:
			level = l
	var name_key := String(level.get("name", ""))
	var night := _next_level == 3
	next_button.theme_type_variation = "DarkButton" if night else "SunButton"
	if night:
		CozyTheme.lift_button(next_button, Pal.SLATE, BUTTON_RADIUS)
	else:
		CozyTheme.accent_button(next_button, _accent, BUTTON_RADIUS)
	_next_name.text = tr("WIN_NEXT") % tr(LEVEL_KEYS.get(name_key, name_key))
	_next_name.add_theme_color_override("font_color", Pal.MOON if night else Pal.SURFACE)
	_next_line.text = tr(String(level.get("line", "")))
	_next_line.add_theme_color_override("font_color",
		Color(Pal.MOON, 0.72) if night else Color(Pal.SURFACE, 0.85))

func _on_next() -> void:
	if _next_level < 0:
		return
	Analytics.track("next_level", {
		"puzzle_id": _entry.get("id", ""),
		"difficulty": _difficulty,
		"to": _next_level,
	})
	play_level.emit(_next_level)

## The painting runs from the screen's top edge (under the safe area) to a
## little past the day card, as the menu's does; its crop ignores the top
## inset so a punch-hole phone sees the same picture, shifted down.
func _place_backdrop() -> void:
	if _backdrop == null:
		return
	var insets := SafeArea.insets(self)
	_backdrop.offset_bottom = MARGIN + insets.x + TOP_PLAY + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

func _apply_insets() -> void:
	super()
	_place_backdrop()

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
	var span := _card_span(_board_holder.size.y)
	_card.offset_top = span.x
	_card.offset_bottom = span.x + span.y - _board_holder.size.y

## Where the card stands in a slot `h` tall: its top (x) and its height (y).
func _card_span(h: float) -> Vector2:
	var want := h
	var centred := false
	if is_instance_valid(_puzzle) and _puzzle.has_method("card_height"):
		want = minf(want, _puzzle.card_height(h))
		centred = _puzzle.has_method("card_centred") and _puzzle.card_centred()
	return Vector2((h - want) * 0.5 if centred else 0.0, want)

## The win's slots slide by tweening their minimum heights, so the board's
## slot changes size on every frame of it -- and a board lays itself out and
## rebuilds its whole mesh, and every face on it, on every resize. On a phone
## that is the stutter. So for the slide the board keeps the size it was laid
## out at and is scaled and moved to follow its card instead, and it is laid
## out once, at the new size, when the slide is over (_thaw_board).
func _freeze_board() -> void:
	if not is_instance_valid(_puzzle) or _board_holder.size.y <= 0.0:
		return
	_frozen = _card_span(_board_holder.size.y)
	if _frozen.y <= 0.0:
		return
	# set_anchor keeps the rect by moving the offsets, so the board is never
	# resized on the way into the freeze.
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_puzzle.set_anchor(side, 0.0)
	_puzzle.pivot_offset = Vector2(_puzzle.size.x * 0.5, 0.0)
	_board_holder.resized.connect(_follow_board)

## The frozen board, scaled so its card lands on the card's own span.
func _follow_board() -> void:
	if not is_instance_valid(_puzzle):
		return
	var span := _card_span(_board_holder.size.y)
	var k := span.y / _frozen.y
	_puzzle.scale = Vector2(k, k)
	_puzzle.position.y = span.x - k * _frozen.x

func _thaw_board() -> void:
	if _board_holder.resized.is_connected(_follow_board):
		_board_holder.resized.disconnect(_follow_board)
	if not is_instance_valid(_puzzle):
		return
	_puzzle.scale = Vector2.ONE
	_puzzle.pivot_offset = Vector2.ZERO
	# Placed at the slot's size first, then anchored in place: a preset
	# writes one side at a time, and every side in between is a resize, and
	# so a whole relayout of the board.
	_puzzle.position = Vector2.ZERO
	_puzzle.size = _board_holder.size
	_puzzle.set_anchor(SIDE_RIGHT, 1.0)
	_puzzle.set_anchor(SIDE_BOTTOM, 1.0)

func _on_brush(v: int) -> void:
	if is_instance_valid(_puzzle) and _puzzle.has_method("set_brush"):
		_puzzle.set_brush(v)
		_refresh()

## A new board (Reset never spawns one, but the settings sheet's New does):
## the win screen, if it was up, goes back to the playing rows at once.
func _spawn(the_seed: int) -> void:
	if _won:
		_won = false
		_thaw_board()
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
	day_card.set_hearts(Progress.hearts())
	_fit_card()

## The board's wave plays first; then the rows make way for the win screen.
func _on_solved() -> void:
	var puzzle_id := String(_entry.get("id", ""))
	# Keep the result metrics with the completion flag. The menu still listens
	# to daily_completed for its card state, while a reopened daily can restore
	# the same time, moves and hints on its finished screen.
	var kept := _stats()
	if is_instance_valid(_puzzle) and _puzzle.has_method("completion_record"):
		var record: Dictionary = _puzzle.completion_record()
		if not record.is_empty():
			kept["board"] = record
	var event := _stats()
	event["solved"] = true
	if _day_key == 0:
		Progress.mark_completed(_progress_id(), DailySeed.date_key(), kept)
	else:
		var day := _day_key
		Progress.mark_completed(_progress_id(), day, kept)
		# One read of the log: the heart count before, the write, and the
		# count and the streak after, with the new record appended in memory
		# only when log_solve took it (its own dedupe).
		var solves := Progress.solve_log()
		var records: Array = (solves.get(day, []) as Array).duplicate()
		var before := Streak.hearts(records)
		if Progress.log_solve(puzzle_id, _difficulty, kept, day):
			records.append({
				"id": puzzle_id, "d": _difficulty,
				"t": float(kept.get("seconds", 0.0)),
				"m": int(kept.get("moves", 0)),
				"h": int(kept.get("hints", 0)),
			})
			solves[day] = records
		var after := Streak.hearts(records)
		var streak := int(Streak.compute(solves, day).current)
		if after < Streak.KEPT:
			_hearts_line = tr("WIN_HEARTS") % after
		elif before < Streak.KEPT:
			_hearts_line = tr("WIN_DAY_KEPT") % streak
		else:
			_hearts_line = tr("WIN_STREAK") % streak
		event["hearts"] = after
		event["streak"] = streak
	daily_completed.emit(puzzle_id, _day_key if _day_key != 0 else DailySeed.date_key())
	Analytics.track("puzzle_complete", event)
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
	# Every completed flat board gets the same compact result line: elapsed
	# time, move count and hints used. Prepare it independently of the
	# optional celebration art below.
	# After a live solve the island's name gives way to today's hearts; a
	# reopened finished daily has no line and keeps the name.
	stats_card.set_day(Progress.day(),
		_hearts_line if _hearts_line != "" else Progress.island_name())
	stats_card.set_stats(_stats_text())
	_next_level = _find_next_level()
	_dress_win_buttons()
	var bottom_win := BOTTOM_WIN + (NEXT_BUTTON + GAP if _next_level >= 0 else 0.0)
	# A board whose answer is a row of characters shows it instead of the
	# sun and the moon (flat_win).
	if _puzzle.has_method("flat_win"):
		var art: Dictionary = _puzzle.flat_win()
		well_done.set_cast(art.get("faces", []), String(art.get("subtitle", "")),
			art.get("labels", []))
	# The playing rows leave: up and out above, down and out below.
	Motion.slide(_top_stack, "position:y", 0.0, -60.0, CHROME_OUT, 0.0, false)
	Motion.appear(_top_stack, 1.0, 0.0, CHROME_OUT)
	Motion.slide(_bottom_stack, "position:y", 0.0, 100.0, CHROME_OUT, 0.0, false)
	Motion.appear(_bottom_stack, 1.0, 0.0, CHROME_OUT)
	get_tree().create_timer(CHROME_OUT).timeout.connect(func() -> void:
		_top_stack.visible = false
		_bottom_stack.visible = false)
	# The slots make room; the VBox slides the board card down between them.
	_freeze_board()
	var slots := Motion.slide(_top_slot, "custom_minimum_size:y", TOP_PLAY, TOP_WIN, SLOT_TIME, 0.0, false)
	if slots == null:
		_thaw_board()
	else:
		slots.finished.connect(_thaw_board)
	Motion.slide(_bottom_slot, "custom_minimum_size:y", _bottom_play, bottom_win, SLOT_TIME, 0.0, false)
	well_done.enter(ART_DELAY)
	_win_stack.visible = true
	Motion.slide(_win_stack, "position:y", 120.0, 0.0, STATS_SLIDE, STATS_DELAY)
	Motion.appear(_win_stack, 0.0, 1.0, 0.2, STATS_DELAY)

## Replay the same daily from a fresh board. Completion is cleared before the
## new board starts so leaving the replay unsolved cannot restore the old DONE
## card or its old result stats.
func _on_redo() -> void:
	var puzzle_id := String(_entry.get("id", ""))
	if puzzle_id.is_empty():
		return
	Progress.clear_completed(_progress_id(), DailySeed.date_key())
	_completed_daily = false
	_hearts_line = ""
	Analytics.track("puzzle_redo", {"puzzle_id": puzzle_id})
	_bank_step = 0
	_day_key = DailySeed.date_key()
	_spawn(DailySeed.seed_for(String(_entry.get("seed_as", puzzle_id)), _difficulty))

## The settings sheet's New deals from a random seed: not a daily, so its
## solve is not logged (see _day_key).
func _on_new() -> void:
	_day_key = 0
	_hearts_line = ""
	super()

## Where today's completion is saved: the card's id, or the id and the
## difficulty for a card that asks which (ui/registry.gd `progress_id`).
func _progress_id() -> String:
	return load("res://ui/registry.gd").progress_id(_entry, _difficulty)

## "m:ss · N moves · N hints" for the stats card.
func _stats_text() -> String:
	var secs := int(round(_puzzle.elapsed))
	var hints: int = _puzzle.hints_used
	var moves: int = _puzzle.moves
	return "%d:%02d · %s · %s" % [
		secs / 60, secs % 60,
		tr("WIN_ONE_MOVE") if moves == 1 else tr("WIN_N_MOVES") % moves,
		tr("WIN_ONE_HINT") if hints == 1 else tr("WIN_N_HINTS") % hints]
