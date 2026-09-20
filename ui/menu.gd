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
## went with it -- and came back on 2026-09-20 once a thirteenth card
## needed a second page, in its own strip between the grid and the bottom
## bar (`_pager`, built the way `_toast` already is: an overlay on
## `_list_root`, not a row of the column). A prev chevron first grew out of
## the day row's own dead one instead, and the user overturned that: the
## day row's chevron is decoration by their own 2026-09-18 decision, and a
## pager beside "Day N" reads as *next day*. The day row is untouched by
## any of this.
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
const Icons = preload("res://ui/icons.gd")

## The old game's scene and its two hosts, loaded only when More opens one.
const STAGE_SCENE := "res://legacy/world/stage.tscn"
const ISLAND_HOST := "res://legacy/ui/island_host.gd"
const TURN_HOST := "res://legacy/ui/turn_host.gd"
const CAMP_MENU := "res://legacy/ui/camp_menu.gd"

const MARGIN := 40
const GAP := 20
const COLS := 3
## Twelve cards a page: three across and four down is what 80 of margin, 60
## of gaps, a 380 header, a 180 day row and a 150 bar leave for rows of 252.
## A thirteenth card gets a second page rather than a shorter card -- this is
## not any one board's work, it is the first screen's (see docs/superpowers/
## specs/2026-09-20-mushroom-patch-flat-design.md, section 2, and the sibling
## specs of whichever other board lands beside it).
const PER_PAGE := 12
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
## The pager strip, laid over the bar the way the toast is: the header, the
## day row, the grid and the bar already spend the screen exactly (see the
## toast's own comment in _build_list), so this is an overlay on
## `_list_root` rather than a row of the column, and it costs the grid
## nothing -- a card stays 252 whether or not a second page exists. It sits
## a little closer to the bar than the toast does (the toast is a rare
## message that can afford to sit over the last row's cards for a moment;
## this is up on every multi-page screen, so it is kept as short as a
## usable tap target allows to leave the cards' own bottom edge alone as
## much as it can).
const PAGER_OVER := 150.0 + 40.0 + 6.0
const PAGER_H := 32.0
const PAGER_ICON := 16.0
const PAGER_TAP := Vector2(56.0, PAGER_H)
## The pager's dots. Two is what thirteen cards need; the row draws as many
## as it is given, so a fourteenth board costs nothing here.
const DOT := 10.0
const DOT_GAP := 10.0

var settings_sheet: Control
var legacy_sheet: Control
var cards: Array = []
## Invisible padding for a short last row (task 8's width fix, 2026-09-20):
## see _build_page().
var _fillers: Array = []
var header: Control
var day_row: Control
var bar: Control
var _list_root: Control
var _grid: GridContainer
var _page := 0
var _toast: Label
var _toast_tw: Tween
## The pager strip: prev, dots, next, between the grid and the bar.
var _pager: Control
var _prev: Button
var _next: Button
var _dots: Control
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

	# --- the cards, a page at a time ---
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = COLS
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	root.add_child(_grid)
	_build_page()

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

	# The pager: prev, dots, next -- see PAGER_OVER above for why it is
	# sized and placed the way it is, and PER_PAGE above and
	# docs/superpowers/specs/2026-09-20-mushroom-patch-flat-design.md,
	# section 2 ("a next and a prev under the grid with a dot each") for
	# what it is answering. Built even at one page and simply hidden
	# (_set_pager, called from _build_page), the way the toast exists
	# whether or not there is anything to say.
	_pager = Control.new()
	_pager.name = "Pager"
	_pager.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pager.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_pager.offset_left = MARGIN
	_pager.offset_right = -MARGIN
	_pager.offset_top = -PAGER_OVER - PAGER_H
	_pager.offset_bottom = -PAGER_OVER
	_list_root.add_child(_pager)
	var pager_row := HBoxContainer.new()
	pager_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pager_row.add_theme_constant_override("separation", 16)
	pager_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pager.add_child(pager_row)
	_prev = _page_button("chevron_left")
	_prev.pressed.connect(func() -> void: _turn_page(-1))
	pager_row.add_child(_prev)
	_dots = Control.new()
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.draw.connect(_draw_dots.bind(_dots))
	pager_row.add_child(_dots)
	_next = _page_button("chevron_right")
	_next.pressed.connect(func() -> void: _turn_page(1))
	pager_row.add_child(_next)

## How many pages the registry needs at PER_PAGE a page; at least one, so an
## empty registry does not divide by nothing.
func _pages() -> int:
	return maxi(1, ceili(float(Registry.PUZZLES.size()) / float(PER_PAGE)))

## The entries on the page that is up, with the index each has in the
## registry -- the colour comes off that index, so a card keeps its colour
## whichever page it lands on.
func _page_entries() -> Array:
	var out: Array = []
	var from := _page * PER_PAGE
	for i in range(from, mini(from + PER_PAGE, Registry.PUZZLES.size())):
		out.append({"i": i, "entry": Registry.PUZZLES[i]})
	return out

func _build_page() -> void:
	for c in cards:
		_grid.remove_child(c)
		c.queue_free()
	cards.clear()
	for f in _fillers:
		_grid.remove_child(f)
		f.queue_free()
	_fillers.clear()
	for row in _page_entries():
		var entry: Dictionary = row.entry
		var card := PuzzleCard.new(entry, Pal.CAT[int(row.i) % Pal.CAT.size()])
		card.name = "Card_" + entry.id
		card.open.connect(_open.bind(entry))
		card.blocked.connect(_on_soon.bind(entry))
		cards.append(card)
		_grid.add_child(card)
	# A short last row (thirteen over twelve leaves one) hands its one real
	# column every column's leftover width -- GridContainer sizes a column
	# to the widest cell it actually has, and a column with no cell in that
	# row does not compete for the row's stretch at all. Padding out to COLS
	# with zero-minimum, EXPAND_FILL fillers keeps three columns competing
	# on every row, on any page, so a card is 320 wide everywhere rather
	# than however many empty columns' worth wider. The mirror of the
	# height floor puzzle_card_2d.gd's CARD_H sets on the other axis.
	var short := cards.size() % COLS
	if short > 0:
		for i in COLS - short:
			var filler := Control.new()
			filler.name = "Filler_%d" % i
			filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_fillers.append(filler)
			_grid.add_child(filler)
	_set_pager(_page, _pages())

## Which page is up, and how many there are. One page hides the whole strip
## (nothing on the grid or the bar moves either way -- it is an overlay);
## the next chevron disables itself once the last page is up, and the prev
## once the first is.
func _set_pager(page: int, pages: int) -> void:
	var many := pages > 1
	_pager.visible = many
	_prev.disabled = page <= 0
	_next.disabled = page >= pages - 1
	(_prev.get_meta("glyph") as Control).queue_redraw()
	(_next.get_meta("glyph") as Control).queue_redraw()
	_dots.custom_minimum_size = Vector2(pages * DOT + (pages - 1) * DOT_GAP, DOT)
	_dots.set_meta("page", page)
	_dots.set_meta("pages", pages)
	_dots.queue_redraw()

func _draw_dots(on: Control) -> void:
	var page: int = on.get_meta("page", 0)
	var pages: int = on.get_meta("pages", 1)
	for i in pages:
		var x := i * (DOT + DOT_GAP) + DOT * 0.5
		var c: Color = Pal.TEXT if i == page else Pal.LINE
		on.draw_circle(Vector2(x, DOT * 0.5), DOT * 0.5, c)

## One small chevron button for the pager: the vector icon at PAGER_ICON
## rather than the HUD's IconButton (whose glyph is a fixed 44), because
## the strip is only PAGER_H (32) tall.
func _page_button(icon: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = PAGER_TAP
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(center)
	var glyph := Control.new()
	glyph.custom_minimum_size = Vector2(PAGER_ICON, PAGER_ICON)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.draw.connect(func() -> void:
		Icons.paint(glyph, icon, Rect2(Vector2.ZERO, glyph.size),
			Pal.TEXT_DIM if btn.disabled else Pal.TEXT))
	center.add_child(glyph)
	btn.set_meta("glyph", glyph)
	return btn

## A page change is not an entrance: the header, the day row and the bar
## stay where they are, the outgoing cards fade rather than cut, and the
## incoming ones play the same per-page stagger the first page gets. The
## outgoing cards are handed to `_fade_out_page` and `cards` is emptied
## before `_build_page` runs, so its own free-the-old-page loop finds
## nothing to do and only builds.
func _turn_page(by: int) -> void:
	var want := clampi(_page + by, 0, _pages() - 1)
	if want == _page:
		return
	_page = want
	_fade_out_page(cards)
	cards = []
	_build_page()
	for i in cards.size():
		cards[i].enter(Motion.stagger(i, CARD_STEP, CARD_CAP))

## Pulls every card the page turn is leaving behind out of the grid, so the
## grid is free to lay out the incoming page without the outgoing cards
## still claiming a cell, and onto the list root at the exact spot it was
## already standing -- a plain Control with no layout of its own, so it can
## hold a card at an arbitrary position while the grid moves on without it.
## It lands there *after* `margins` (which holds `_grid`), so for the whole
## fade it sits on top of the incoming page at the same screen rect, which
## is the point of a crossfade -- and also why `disable_tap()` matters: the
## card's own hit surface is a full-rect Button (`_tap`, in
## puzzle_card_2d.gd), and Godot hands input to the front-most one under
## the finger regardless of fade alpha, so a card left tappable here would
## win every tap over whatever just arrived underneath it. Each card then
## fades on its own tween (Motion.appear, reusing the screen's own
## ENTER_FADE rather than a new constant) and frees itself when that tween
## lands, mirroring how a leaving face is freed elsewhere (binairo2d.gd's
## `_swap_face`). A second page turn before this one's fades land only ever
## calls this again with whatever `cards` holds by then -- a fresh page
## `_build_page` only just built, never the nodes already fading -- so no
## card is ever asked to fade or free twice, and every card that starts
## fading is guaranteed its own free.
func _fade_out_page(leaving: Array) -> void:
	for card in leaving:
		var rect: Rect2 = card.get_global_rect()
		_grid.remove_child(card)
		_list_root.add_child(card)
		card.global_position = rect.position
		card.disable_tap()
		# A card turned onto this page moments ago may still be mid-entrance
		# (panel.gd's `_entrance`, driving the same modulate:a this fade
		# drives): stop those first, or a fast page-turn-and-back leaves two
		# tweens racing the alpha and a one-frame flicker before this card
		# frees itself.
		for tw in card._entrance:
			Motion.stop(tw)
		var out := Motion.appear(card, card.modulate.a, 0.0, ENTER_FADE)
		if out == null:
			card.queue_free()
		else:
			out.finished.connect(card.queue_free)

## Shows the grid with the day current and plays the entrance; at start and
## on every return from a puzzle. Opening the app is what counts a day.
func _show_list() -> void:
	_list_root.visible = true
	Progress.touch()
	if _page != 0:
		_page = 0
		_build_page()
	day_row.set_day(Progress.day(), Progress.island_name())
	bar.show_tab("home")
	_enter()

func _enter() -> void:
	header.enter(ENTER_HEADER, ENTER_FADE)
	day_row.enter(ENTER_DAY)
	for i in cards.size():
		cards[i].enter(ENTER_CARDS + Motion.stagger(i, CARD_STEP, CARD_CAP))
	bar.enter(ENTER_BAR)
	Motion.appear(_pager, 0.0, 1.0, ENTER_FADE, ENTER_CARDS + CARD_CAP)

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
