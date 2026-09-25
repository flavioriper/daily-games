extends Control

## The first screen: the wordmark and the two characters at the top, the day
## row under them, a page of eight puzzle cards in a grid of two (490x246
## cards, since the painted menu of 2026-09-24 -- twelve in a grid of three
## before that), and the bottom bar. Everything on it is drawn in 2D -- there
## is no stage, no World3D and no model anywhere on this screen.
##
## It replaced the 3D campsite on 2026-09-18, and the whole 3D game was
## removed from the repo on 2026-09-24. Twelve cards fit on one screen, so
## the campsite's pager went with it -- and came back on 2026-09-20 once a thirteenth card
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
## Spec: docs/superpowers/specs/2026-09-18-flat-menu-design.md.

const Pal = preload("res://core/palette.gd")
const UiSound = preload("res://ui/ui_sound.gd")
const Motion = preload("res://core/motion.gd")
const Progress = preload("res://core/progress.gd")
const Registry = preload("res://ui/registry.gd")
const FlatHost = preload("res://ui/flat/flat_host.gd")
const CozyTheme = preload("res://ui/theme.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const MenuHeader = preload("res://ui/menu/menu_header.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const DayRow = preload("res://ui/menu/day_row.gd")
const PuzzleCard = preload("res://ui/menu/puzzle_card_2d.gd")
const BottomBar = preload("res://ui/menu/bottom_bar.gd")
const DifficultySheet = preload("res://ui/menu/difficulty_sheet.gd")
const Icons = preload("res://ui/icons.gd")
const Analytics = preload("res://core/analytics.gd")
const StreakTab = preload("res://ui/menu/streak_tab.gd")
const StatsTab = preload("res://ui/menu/stats_tab.gd")
const Streak = preload("res://core/streak.gd")

const MARGIN := 40
const GAP := 20
## How far the header's scene runs behind the day card before it has faded
## out.
const BACKDROP_BLEED := 140.0
const COLS := 2
## The narrowest a card may be drawn: two across in the 1000 between the
## margins, less one 20 gap (spec 2026-09-24-painted-menu, section 2).
## `_fit_grid` fits as many columns of it as the screen is wide.
const MIN_CARD_W := 490.0
## How far the gap between card rows may close to keep a row. Restated
## 2026-09-24 (final fix wave): with the pager seam counted in (PAGER_SEAM
## below), the slack at 1080x1920 is 1040 - 4*246 - 3*20 = -4, so the four-row
## gap already closes below GAP on the reference screen -- `_fit_grid` takes
## it to 18 there -- and MIN_ROW_GAP 16 is the floor under that, kept for a
## screen shorter still.
const MIN_ROW_GAP := 16
## Eight cards a page: two across and four down is what 80 of margin, 60 of
## gaps, a 380 header, a 200 day row and a 120 bar leave -- 1080 of 1920 --
## before the pager seam takes its own 20px plus one more 20 gap (PAGER_SEAM
## below), leaving 1040 for four rows of 246 at an 18 gap (1032; see
## MIN_ROW_GAP above for why the gap is 18 and not 20).
## That is the 1080x1920 page, and the one every other screen starts from:
## since 2026-09-23 the page is *fitted* (`_fit_grid`). The canvas is 1080
## wide and never shorter than 1920 (`stretch/aspect="expand"`), so a taller
## phone gets extra height and a wider screen extra width; the grid takes as
## many rows of CARD_H and columns of MIN_CARD_W as that room holds, and a
## screen that holds every card gets one page and no pager. PER_PAGE is the
## default before the first fit and the figure on the phone the game is
## drawn for, not a constant of the grid any more.
## A thirteenth card gets a second page rather than a shorter card -- this is
## not any one board's work, it is the first screen's (see docs/superpowers/
## specs/2026-09-20-mushroom-patch-flat-design.md, section 2, and the sibling
## specs of whichever other board lands beside it). Sudoku made it fourteen
## on 2026-09-20, and Bridges, Quilt, Paper Planes and Pinwheel made it
## fifteen, sixteen, seventeen and eighteen the same day, so page two grew
## from one card to six; nothing here had to change for any of them, which
## is the whole point of paging the grid rather than counting the cards.
const PER_PAGE := 8
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
const TOAST_OVER := BottomBar.HEIGHT + MARGIN + 10.0
const TOAST_H := 88.0
## Room between the grid and the bar, reserved so the pager pill never lies
## over a card's text (spec 2026-09-24-painted-menu: cards are now 490 wide
## with a two-line blurb at their bottom, and the pill used to float on the
## bare 20px seam between the grid and the bar, which put it right over the
## last row's text). The budget at 1920: 1920 - 80 margins - 380 header -
## 200 day - 120 bar - 60 gaps - 20 seam - 20 extra gap = 1040 for four 246
## rows at 18 gaps (1032). `_fit_grid` subtracts it (and one more GAP) from
## `room_h` when the seam is standing, and `_build_list` gives it its own
## spacer control between `_grid` and the bar.
const PAGER_SEAM := 20.0
## The pager strip, laid over the bar the way the toast is: the header, the
## day row, the grid, the seam and the bar already spend the screen exactly
## (see the toast's own comment in _build_list), so this is an overlay on
## `_list_root` rather than a row of the column, and it costs the grid
## nothing -- a card stays 246 whether or not a second page exists.
##
## The pill sits in its own seam since 2026-09-24 (painted menu): PAGER_SEAM
## opened a real gap between the grid and the bar for it, rather than the
## bare 20px separation the rest of the column uses, so PAGER_MID is that
## seam's vertical centre and the pill floats there without lying over
## either neighbour. Before the painted menu the pill overlapped the last
## card row by about 18px; that overlap is gone now that the seam exists.
const PAGER_MID := BottomBar.HEIGHT + MARGIN + GAP + PAGER_SEAM * 0.5
## The pill's own slot: taller than the pill needs, so CenterContainer never
## clips it.
const PAGER_SLOT_H := 64.0
## Chunky, round and bordered, the same visual language as every other
## control on this screen (the bar's tabs, a card's go button) rather than a
## bare vector line -- the first version of this strip used a 16px icon on
## no background at all and read as an artefact, not a button.
const PAGER_BTN := Vector2(44.0, 44.0)
const PAGER_ICON := 20.0
## The pager's dots. Two is what thirteen to twenty-four cards need;
## the row draws as many as it is given, so a twenty-fifth board would cost
## nothing here either -- the seventeenth already did not. The current
## page is a filled disc; every other page is a ring, so the two are never
## just two shades of the same filled dot.
const DOT := 14.0
const DOT_GAP := 10.0
## A swipe across the grid turns the page: this far sideways, and at least
## SWIPE_SLOPE times further sideways than down, so a vertical flick or a
## tap that wanders is never read as one.
const SWIPE := 90.0
const SWIPE_SLOPE := 1.5
## The pointer id a mouse press tracks under, beside a touch's index.
const MOUSE_ID := -2
## The page follows the finger once a press has moved this far sideways
## (and SWIPE_SLOPE times more sideways than down); before that it is still
## a tap. Let go past PAGE_COMMIT of a page's width, or flicked faster than
## PAGE_FLICK px/s, and the turn completes; otherwise the page slides back.
## Past the first or the last page the drag gives only PAGE_EDGE of the
## finger's travel, a rubber band with nothing behind it.
const DRAG_START := 16.0
const PAGE_COMMIT := 0.25
const PAGE_FLICK := 700.0
const PAGE_EDGE := 0.3
## A full page's slide, whether a chevron's or the rest of a let-go drag
## (which takes the share of it that is left, but never less than
## PAGE_SLIDE_MIN).
const PAGE_SLIDE := 0.34
const PAGE_SLIDE_MIN := 0.14

var settings_sheet: Control
var difficulty_sheet: Control
var cards: Array = []
## Invisible padding for a short last row (task 8's width fix, 2026-09-20):
## see _build_page().
var _fillers: Array = []
var header: Control
var day_row: Control
var bar: Control
var streak_tab: Control
var stats_tab: Control
var _tab := "home"
var _tab_tw: Tween
var _backdrop: ColorRect
var _list_root: Control
var _grid: GridContainer
## The page slides in a plain slot of its own: `_grid` holds the page that is
## up and `_peek` the one beside it while a drag or a turn is showing it;
## the two swap when a turn lands. A container would put a child's position
## back on every sort, so the grids are anchored in a plain Control and move
## by their own offset.
var _grid_slot: Control
var _peek: GridContainer
var _peek_page := -1
var _peek_cards: Array = []
var _peek_fillers: Array = []
var _slide_tw: Tween
## Where the running slide is heading: 0 back to rest, +-1 a turn.
var _slide_go := 0
## Where the page stands under a drag, px, and the target page it is heading
## for (the page up, or the one beside it).
var _drag_x := 0.0
var _dragging := false
## The last two pointer samples, for the flick's speed at the let-go.
var _drag_t := 0.0
var _drag_v := 0.0
## The seam-spacer between the grid and the bar; see PAGER_SEAM above.
var _pager_seam: Control
var _page := 0
## The fitted page (`_fit_grid`): cards a page, columns, a row's height.
var _per_page := PER_PAGE
var _cols := COLS
var _row_h := PuzzleCard.CARD_H
var _column: VBoxContainer
var _margins: MarginContainer
var _fit_queued := false
## The press a swipe is measured from, and which finger or mouse it is.
var _swipe_id := -1
var _swipe_from := Vector2.ZERO
## Set once a press became a swipe, so the card it started on does not open
## when the finger lifts; cleared by the next press.
var _swiped := false
var _toast: Label
var _toast_tw: Tween
## The pager strip: prev, dots, next, between the grid and the bar.
var _pager: Control
var _prev: Button
var _next: Button
var _dots: Control
var _pager_tw: Tween
## The date key the list last showed; _check_day refreshes when it moves.
var _shown_day := 0

func _ready() -> void:
	theme = CozyTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ads.banner_changed.connect(func(_visible: bool, _height: float) -> void: _apply_insets())
	_build_list()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	settings_sheet.reduce_changed.connect(header.refresh_motion)
	add_child(settings_sheet)
	difficulty_sheet = DifficultySheet.new()
	difficulty_sheet.name = "DifficultySheet"
	difficulty_sheet.chose.connect(_open_at)
	add_child(difficulty_sheet)
	# A menu left open across 00:00 UTC catches up within a minute.
	var day_timer := Timer.new()
	day_timer.name = "DayTimer"
	day_timer.wait_time = 60.0
	day_timer.autostart = true
	day_timer.timeout.connect(_check_day)
	add_child(day_timer)
	_show_list()

## A resumed app, or one brought back to the front, may be on a new day.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_check_day()

## When the day has changed under a visible list, re-read what _show_list
## reads -- the cards' done marks, Day N, the hearts and the badge, and the
## open tab -- without replaying the entrance.
func _check_day() -> void:
	if _list_root == null or not _list_root.visible or Daily.date_key() == _shown_day:
		return
	Progress.touch()
	_build_page()
	if _tab != "home":
		_pager.visible = false
	_refresh_day()
	if _tab == "streak":
		streak_tab.refresh()
	elif _tab == "stats":
		stats_tab.refresh()

## Day N, today's hearts and the streak badge, from one read of the log.
func _refresh_day() -> void:
	var today := Daily.date_key()
	_shown_day = today
	day_row.set_day(Progress.day(), Progress.island_name())
	var solves := Progress.solve_log()
	day_row.set_hearts(Streak.hearts(solves.get(today, [])))
	header.set_streak(int(Streak.compute(solves, today).current))

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
	# The header's painted scene, full-bleed from the top edge (under the
	# safe area) to past the day card's top, where it fades into the paper;
	# the wordmark stands on its left scrim (spec 2026-09-24-painted-menu,
	# section 5). Laid under the margins, so no row of the column moves.
	_backdrop = Vistas.header_plate()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_list_root.add_child(_backdrop)
	var insets := SafeArea.insets(self)
	_backdrop.offset_bottom = MARGIN + insets.x + MenuHeader.HEIGHT + BACKDROP_BLEED
	## F1 (final fix wave, 2026-09-24): the line above grows the plate by the
	## top inset so the header clears a punch-hole cutout, but Vistas' crop is
	## `cover` and sizes off the plate's own height -- left alone, that inset
	## would rescale and slide the whole painting, walking the sun and moon
	## off the deck (see Vistas.set_top_pad's own comment). Telling the crop
	## to ignore exactly `insets.x` px keeps it pixel-identical to the inset-0
	## case, shifted down by the inset.
	Vistas.set_top_pad(_backdrop, insets.x)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", MARGIN)
	margins.add_theme_constant_override("margin_right", MARGIN)
	margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_list_root.add_child(margins)
	_margins = margins
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", GAP)
	margins.add_child(root)
	_column = root
	root.resized.connect(_queue_fit)

	header = MenuHeader.new()
	header.name = "Header"
	header.settings.connect(func() -> void: settings_sheet.open())
	header.calendar.pressed.connect(func() -> void: _show_tab("streak"))
	root.add_child(header)

	day_row = DayRow.new()
	day_row.name = "DayRow"
	day_row.open_streak.connect(func() -> void: _show_tab("streak"))
	root.add_child(day_row)

	# --- the cards, a page at a time, in a slot they can slide in ---
	_grid_slot = Control.new()
	_grid_slot.name = "GridSlot"
	_grid_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_grid_slot)
	_grid = _new_grid("Grid")
	_peek = _new_grid("Peek")
	_peek.visible = false

	# The seam the pager pill floats in (PAGER_SEAM above): a plain spacer
	# between the grid and the bar, standing only on the home tab (hidden and
	# shown together with _grid in _show_tab), so Stats and Streak do not
	# inherit a stray gap where the grid used to be.
	_pager_seam = Control.new()
	_pager_seam.name = "PagerSeam"
	_pager_seam.custom_minimum_size.y = PAGER_SEAM
	_pager_seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pager_seam)

	# Stats and Streak take the day row's, the grid's and the pager's room
	# when picked; the header and the bar stay (spec 2026-09-24, section 4).
	streak_tab = StreakTab.new()
	streak_tab.name = "StreakTab"
	streak_tab.visible = false
	root.add_child(streak_tab)
	stats_tab = StatsTab.new()
	stats_tab.name = "StatsTab"
	stats_tab.visible = false
	stats_tab.open_streak.connect(func() -> void: _show_tab("streak"))
	root.add_child(stats_tab)

	bar = BottomBar.new()
	bar.name = "BottomBar"
	bar.picked.connect(_on_tab)
	root.add_child(bar)

	# The pager: prev, dots, next, in their own paper pill -- see PAGER_MID
	# above for why it is a pill and not a bare row, and PER_PAGE above and
	# docs/superpowers/specs/2026-09-20-mushroom-patch-flat-design.md,
	# section 2 ("a next and a prev under the grid with a dot each") for
	# what it is answering. Built even at one page and simply hidden
	# (_set_pager, called from _build_page below), the way the toast exists
	# whether or not there is anything to say. Built *before* the toast below
	# so it lands under it in `_list_root`'s children: the toast has to draw
	# over the pager where the two overlap (found by review, 2026-09-20 --
	# a wrapped two-line toast used to read partly under the pill).
	_pager = Control.new()
	_pager.name = "Pager"
	_pager.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pager.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_pager.offset_left = 0.0
	_pager.offset_right = 0.0
	# F2 (final fix wave, 2026-09-24): PAGER_MID is measured off the bar's own
	# height, margin and seam, but the bar itself sits `insets.y` higher than
	# the screen's bottom edge (margin_bottom above), which this anchor
	# (PRESET_BOTTOM_WIDE) does not know about. Without subtracting it, a
	# phone with a bottom inset (the ad banner via Ads.bottom_inset(), or a
	# gesture-bar cutout) draws the pill below the seam it is meant to float
	# in. `insets` is still the one read at the top of this function.
	_pager.offset_top = -PAGER_MID - PAGER_SLOT_H * 0.5 - insets.y
	_pager.offset_bottom = -PAGER_MID + PAGER_SLOT_H * 0.5 - insets.y
	_list_root.add_child(_pager)
	# CenterContainer, not anchors: the pill hugs its own content (prev, the
	# dots, next) rather than spanning the margin-to-margin width every
	# other row on this screen uses, so it reads as a floating chip and not
	# another card.
	var pager_center := CenterContainer.new()
	pager_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pager_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pager.add_child(pager_center)
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, 24, 8))
	pager_center.add_child(pill)
	var pager_row := HBoxContainer.new()
	pager_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pager_row.add_theme_constant_override("separation", 12)
	pill.add_child(pager_row)
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

	# A line about something that is only drawn, laid over the bar rather
	# than given a row of the column: four rows of cards and the bar spend
	# the screen exactly, and a row that is empty most of the time would
	# come out of the cards. Built after the pager (see above) so a wrapped
	# two-line toast always reads on top of the pill where they overlap.
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
	# F2 (final fix wave, 2026-09-24): the same fix as the pager above --
	# TOAST_OVER is measured off the bar's height and margin, not the
	# screen's true bottom edge, so a bottom inset needs subtracting here too
	# or the toast drifts below the bar it is meant to float over.
	_toast.offset_top = -TOAST_OVER - TOAST_H - insets.y
	_toast.offset_bottom = -TOAST_OVER - insets.y
	_list_root.add_child(_toast)

	# Built last: _set_pager (called from _build_page) reaches into _pager,
	# _prev, _next and _dots, all built just above -- calling this any
	# earlier (it once sat right after _grid, before any of them existed)
	# left _set_pager silently failing on a null _pager and _dots never
	# getting told how many pages there are, which is why the very first
	# render only ever showed one dot.
	_build_page()

func _new_grid(grid_name: String) -> GridContainer:
	var g := GridContainer.new()
	g.name = grid_name
	g.columns = COLS
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.add_theme_constant_override("h_separation", GAP)
	g.add_theme_constant_override("v_separation", GAP)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid_slot.add_child(g)
	return g

## How many pages the registry needs at PER_PAGE a page; at least one, so an
## empty registry does not divide by nothing.
func _pages() -> int:
	return maxi(1, ceili(float(Registry.PUZZLES.size()) / float(_per_page)))

## The entries on the page that is up, with the index each has in the
## registry -- the colour comes off that index, so a card keeps its colour
## whichever page it lands on.
func _page_entries(page := _page) -> Array:
	var out: Array = []
	var from := page * _per_page
	for i in range(from, mini(from + _per_page, Registry.PUZZLES.size())):
		out.append({"i": i, "entry": Registry.PUZZLES[i]})
	return out

func _build_page() -> void:
	_drop_peek()
	_free_nodes(_grid, cards)
	_free_nodes(_grid, _fillers)
	_grid.position.x = 0.0
	_fill(_grid, _page, cards, _fillers)
	_set_pager(_page, _pages())

func _free_nodes(from: Node, nodes: Array) -> void:
	for n: Node in nodes:
		if n.get_parent() == from:
			from.remove_child(n)
		n.queue_free()
	nodes.clear()

## Builds `page`'s cards into `grid`, appending them to `into` and any
## fillers to `pad`.
func _fill(grid: GridContainer, page: int, into: Array, pad: Array) -> void:
	var today: Array = Progress.solve_log().get(Daily.date_key(), [])
	for row in _page_entries(page):
		var entry: Dictionary = row.entry
		var card := PuzzleCard.new(entry, Pal.CAT[int(row.i) % Pal.CAT.size()],
			Progress.completed(String(entry.id)), Progress.levels_in(today, String(entry.id)))
		card.name = "Card_" + entry.id
		card.fit_height(_row_h)
		card.open.connect(_open.bind(entry))
		card.blocked.connect(_on_soon.bind(entry))
		into.append(card)
		grid.add_child(card)
	# A short last row -- one whose cards do not fill COLS -- hands the real
	# columns it does have the empty
	# one's
	# leftover width: GridContainer sizes a column to the widest cell it
	# actually has, and a column with no cell in that row does not compete
	# for the row's stretch at all. Padding out to COLS with zero-minimum,
	# EXPAND_FILL fillers keeps both columns competing on every row, on any
	# page, so a card is 490 wide everywhere rather than however many empty
	# columns' worth wider (COLS was three and a card 320 before the painted
	# menu, 2026-09-24). The mirror of the height floor
	# puzzle_card_2d.gd's CARD_H sets on the other axis.
	#
	# **At eighteen cards this does not run**: page two holds six, COLS is
	# three, 6 % 3 is zero, so no filler is made. It ran at seventeen, where
	# page two held five, and it went unused at fifteen, where page two's
	# three over three columns was a full row -- which is why the path stays
	# exactly where it is rather than being deleted the moment a page happens
	# to come out square. Whether it runs is a property of today's card
	# count, never of the pager.
	var short := into.size() % _cols
	if short > 0:
		for i in _cols - short:
			var filler := Control.new()
			filler.name = "Filler_%d" % i
			filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pad.append(filler)
			grid.add_child(filler)

## A banner arriving or leaving changes the bottom inset after the list was
## built, so everything _build_list placed off `insets` is placed again: the
## margins (the column resizes and refits its grid), the header plate and
## its crop, and the pager and toast that float over the bar. Pinwheel's
## merge (57c8539) dropped this hook; the board host kept its own.
func _apply_insets() -> void:
	if not is_instance_valid(_margins):
		return
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_backdrop.offset_bottom = MARGIN + insets.x + MenuHeader.HEIGHT + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)
	_pager.offset_top = -PAGER_MID - PAGER_SLOT_H * 0.5 - insets.y
	_pager.offset_bottom = -PAGER_MID + PAGER_SLOT_H * 0.5 - insets.y
	_toast.offset_top = -TOAST_OVER - TOAST_H - insets.y
	_toast.offset_bottom = -TOAST_OVER - insets.y

## The fit is worked out once the column has its size, and never inside the
## layout pass that resized it: rebuilding the page there would resize the
## grid under the container still sorting it.
func _queue_fit() -> void:
	if _fit_queued:
		return
	_fit_queued = true
	_fit_grid.call_deferred()

## Fits the page to the screen. The grid's room is what the column has left
## after the header, the day row and the bar (measured off the column rather
## than the grid, because the grid's own size is at least its content's and
## a page too tall for the screen would report the overflow as room).
## Not off the column's own size either: a VBoxContainer grows to its
## content's minimum too, so a full page a few pixels over the screen
## measured those pixels as room, the next (shorter) page measured without
## them, and on a phone sitting on a row boundary the page size flipped on
## the turn -- Quilt stood on page one, again on page two, and then on
## neither (2026-09-24). The room is the full-rect list root less the
## margins, which no page's content can move.
## Columns of MIN_CARD_W and rows of CARD_H go in as many as fit; what is
## left over grows every row's picture up to ART_GROW and then opens the
## gaps between rows, so a tall phone gets bigger pictures and a little air
## rather than one empty band under the last row. When the page size
## changes the page is rebuilt on whichever page holds the card that was
## first on screen, so a rotation or a resize never jumps the player back.
func _fit_grid() -> void:
	_fit_queued = false
	if not _grid_slot.visible:
		return
	if _column == null or _column.size.x <= 0.0:
		return
	var room_w := _list_root.size.x - _margins.get_theme_constant("margin_left") \
		- _margins.get_theme_constant("margin_right")
	var room_h := _list_root.size.y - _margins.get_theme_constant("margin_top") \
		- _margins.get_theme_constant("margin_bottom") - header.size.y - day_row.size.y - bar.size.y - GAP * 3
	if _pager_seam.visible:
		room_h -= PAGER_SEAM + GAP
	var cols := maxi(1, floori((room_w + GAP + 0.5) / (MIN_CARD_W + GAP)))
	var rows := maxi(1, floori((room_h + MIN_ROW_GAP) / (PuzzleCard.CARD_H + MIN_ROW_GAP)))
	var slack := room_h - rows * PuzzleCard.CARD_H - (rows - 1) * GAP
	var grow := floorf(clampf(slack / rows, 0.0, PuzzleCard.ART_GROW))
	var gap := GAP
	if rows > 1:
		gap = maxi(MIN_ROW_GAP, GAP + floori((slack - grow * rows) / (rows - 1)))
	for g: GridContainer in [_grid, _peek]:
		g.add_theme_constant_override("v_separation", gap)
	var per := cols * rows
	var row_h := PuzzleCard.CARD_H + grow
	if per != _per_page or cols != _cols:
		var first := _page * _per_page
		_per_page = per
		_cols = cols
		_grid.columns = cols
		_peek.columns = cols
		_page = clampi(first / per, 0, _pages() - 1)
		_row_h = row_h
		_build_page()
	elif row_h != _row_h:
		_row_h = row_h
		for card in cards + _peek_cards:
			card.fit_height(row_h)

## Turns the page when a press on the grid travels far enough sideways:
## finger moving left is the next page, right the previous, the way a book
## turns. Read in `_input`, ahead of the cards, because every card is a
## full-rect Button that would otherwise swallow the drag; nothing is
## marked handled, so a press that stays a tap still reaches its card, and
## `_open` refuses the one card a swipe started on. Touch and mouse are
## both read (the project does not emulate one from the other), and only
## one pointer is tracked at a time.
func _input(event: InputEvent) -> void:
	if not _can_swipe():
		if _swipe_id != -1 and _dragging:
			_let_go()
		_swipe_id = -1
		return
	if event is InputEventScreenTouch:
		_swipe_press(event, event.index, event.pressed)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_swipe_press(event, MOUSE_ID, event.pressed)
	elif event is InputEventScreenDrag and event.index == _swipe_id:
		_swipe_move(event)
	elif event is InputEventMouseMotion and _swipe_id == MOUSE_ID:
		_swipe_move(event)

func _can_swipe() -> bool:
	return _list_root != null and _list_root.visible and _pages() > 1 \
		and not settings_sheet.visible and _grid_slot.visible

func _swipe_press(event: InputEvent, id: int, pressed: bool) -> void:
	if not pressed:
		if id == _swipe_id:
			_swipe_id = -1
			if _dragging:
				_let_go()
		return
	if _swipe_id != -1:
		return
	_swiped = false
	_dragging = false
	var at: Vector2 = _grid_slot.make_input_local(event).position
	if Rect2(Vector2.ZERO, _grid_slot.size).has_point(at):
		_swipe_id = id
		_swipe_from = at

## Before the drag has started, a press that wanders further down than
## sideways is let go (a tap or a scroll, never a turn); once it has, the
## page follows the finger and the speed is sampled for the flick.
func _swipe_move(event: InputEvent) -> void:
	var d: Vector2 = _grid_slot.make_input_local(event).position - _swipe_from
	if not _dragging:
		if absf(d.x) >= DRAG_START and absf(d.x) >= absf(d.y) * SWIPE_SLOPE:
			_dragging = true
			_swiped = true
			# A drag caught mid-slide picks the page up where the slide
			# has it, so a quick second swipe never jumps.
			_grab_slide()
			_swipe_from.x = _grid_slot.make_input_local(event).position.x - _drag_x
			_drag_t = Time.get_ticks_msec() / 1000.0
			_drag_v = 0.0
		elif absf(d.y) >= DRAG_START * SWIPE_SLOPE:
			_swipe_id = -1
		return
	var x := d.x
	var now := Time.get_ticks_msec() / 1000.0
	var dt := now - _drag_t
	if dt > 0.0:
		# Smoothed, so one jittery sample at the let-go does not decide it.
		_drag_v = lerpf(_drag_v, (x - _drag_x) / dt, 0.6)
	_drag_t = now
	_drag_to(x)

## The page's width plus the margin, so the page beside it waits just off
## the screen's edge and the two travel a margin apart.
func _span() -> float:
	return _grid_slot.size.x + MARGIN

## Stands the page at `x` (finger travel), with the one beside it in view
## on the side it is being pulled from; past either end there is none, and
## the page only gives a little.
func _drag_to(x: float) -> void:
	var dir := 1 if x < 0.0 else -1
	var target := _page + dir
	if x == 0.0 or target < 0 or target >= _pages():
		_drag_x = x * PAGE_EDGE
		_hide_peek()
	else:
		_drag_x = x
		_show_peek(target)
		_peek.position.x = _drag_x + dir * _span()
	_grid.position.x = _drag_x

## Finishes a drag: on to the page beside if it was pulled far or fast
## enough toward it, back to rest otherwise.
func _let_go() -> void:
	_dragging = false
	var span := _span()
	var go := 0
	if _peek.visible and _peek_page >= 0:
		var dir := _peek_page - _page
		var toward := -dir * _drag_x
		var fling := -dir * _drag_v
		if toward > span * PAGE_COMMIT or (fling > PAGE_FLICK and toward > 0.0):
			go = dir
	_slide_to(go)

## Builds `page` into the peek grid if it is not the one standing there.
func _show_peek(page: int) -> void:
	if _peek_page != page:
		_free_nodes(_peek, _peek_cards)
		_free_nodes(_peek, _peek_fillers)
		_fill(_peek, page, _peek_cards, _peek_fillers)
		_peek_page = page
	_peek.visible = true

func _hide_peek() -> void:
	_peek.visible = false

func _drop_peek() -> void:
	Motion.stop(_slide_tw)
	_free_nodes(_peek, _peek_cards)
	_free_nodes(_peek, _peek_fillers)
	_peek_page = -1
	_peek.visible = false
	_peek.position.x = 0.0
	_grid.position.x = 0.0
	_drag_x = 0.0

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

## The current page is a filled disc; every other page is an outlined
## ring, so "which page" reads at a glance rather than as two shades of the
## same dot (found by review, 2026-09-20 -- the fix for the missing second
## dot was the build-order bug in _build_list, but the ring makes the two
## states unmistakable even so).
func _draw_dots(on: Control) -> void:
	var page: int = on.get_meta("page", 0)
	var pages: int = on.get_meta("pages", 1)
	for i in pages:
		var x := i * (DOT + DOT_GAP) + DOT * 0.5
		var center_pt := Vector2(x, DOT * 0.5)
		if i == page:
			on.draw_circle(center_pt, DOT * 0.5, Pal.TEXT)
		else:
			on.draw_arc(center_pt, DOT * 0.5 - 1.5, 0.0, TAU, 24, Pal.TEXT_DIM, 2.5, true)

## One chunky round button for the pager -- CozyTheme's usual card
## stylebox rather than a bare vector line on no background, so it reads
## as a button the way the bar's tabs and a card's own go button do.
func _page_button(icon: String) -> Button:
	var btn := Button.new()
	# The turn plays the page's slide (_slide_to), not the button's click.
	btn.set_meta("silent", true)
	btn.custom_minimum_size = PAGER_BTN
	btn.focus_mode = Control.FOCUS_NONE
	var r := int(PAGER_BTN.y * 0.5)
	btn.add_theme_stylebox_override("normal", CozyTheme.card(Pal.SURFACE_HI, r, Pal.LINE, 3, 0))
	btn.add_theme_stylebox_override("hover", CozyTheme.card(Pal.SURFACE_HI, r, Pal.LINE, 3, 0))
	btn.add_theme_stylebox_override("pressed", CozyTheme.card(Pal.SURFACE_HI.darkened(0.08), r, Pal.LINE, 2, 0))
	btn.add_theme_stylebox_override("disabled", CozyTheme.card(Color(Pal.SURFACE_HI, 0.55), r, Color(Pal.LINE, 0.55), 2, 0))
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
## stay where they are, and the page slides -- the one up leaves to one side
## as the next comes in from the other, a margin apart, the way the drag
## moves them. A chevron plays the whole slide; a turn asked for while one
## is still sliding lands that one first, then plays its own.
func _turn_page(by: int) -> void:
	_grab_slide()
	var want := clampi(_page + by, 0, _pages() - 1)
	if want == _page:
		return
	if _peek_page != want:
		_drag_x = 0.0
		_grid.position.x = 0.0
	_show_peek(want)
	_peek.position.x = _drag_x + signf(want - _page) * _span()
	_slide_to(want - _page)

## Slides the page up to rest (`go` 0) or off to the side so the peek page
## lands (`go` +-1, the direction of the turn), over the share of
## PAGE_SLIDE the distance left asks for.
func _slide_to(go: int) -> void:
	Motion.stop(_slide_tw)
	if go != 0:
		UiSound.page(self)
	var span := _span()
	var end_x := -go * span
	if go == 0 and not _peek.visible:
		end_x = 0.0
	var peek_dir := signf(_peek_page - _page) if _peek_page >= 0 else 0.0
	if Motion.reduce:
		_land(go)
		return
	_slide_go = go
	var share := absf(end_x - _drag_x) / span
	var time := maxf(PAGE_SLIDE_MIN, PAGE_SLIDE * share)
	_slide_tw = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tw.tween_method(func(x: float) -> void:
		_drag_x = x
		_grid.position.x = x
		_peek.position.x = x + peek_dir * span, _drag_x, end_x, time)
	_slide_tw.chain().tween_callback(_land.bind(go))
	if go != 0:
		# The dots and chevrons answer at the start of the slide, not its end.
		_set_pager(_page + go, _pages())

## Where a slide ends: on a turn the peek grid becomes the page up and the
## old one is emptied into the peek's place; either way both stand at rest.
func _land(go: int) -> void:
	Motion.stop(_slide_tw)
	if go != 0 and _peek_page >= 0:
		var g := _grid
		_grid = _peek
		_peek = g
		var c := cards
		cards = _peek_cards
		_peek_cards = c
		var f := _fillers
		_fillers = _peek_fillers
		_peek_fillers = f
		_page = _peek_page
		_peek_page = -1
		_free_nodes(_peek, _peek_cards)
		_free_nodes(_peek, _peek_fillers)
		_grid.name = "Grid"
		_peek.name = "Peek"
	_hide_peek()
	_drag_x = 0.0
	_grid.position.x = 0.0
	_peek.position.x = 0.0
	_set_pager(_page, _pages())

## A slide still running is landed where it was heading before anything
## else moves the page, except a drag, which picks it up mid-way.
func _grab_slide() -> void:
	if not Motion.running(_slide_tw):
		return
	Motion.stop(_slide_tw)
	if _dragging:
		return
	# Land it on the page it was going to: the dots already say which.
	_land(_slide_go)

## Shows the grid with the day current and plays the entrance; at start and
## on every return from a puzzle. Opening the app is what counts a day.
##
## The page is *kept*, not reset to zero (found by review, 2026-09-20: this
## used to force `_page = 0` every time, so finishing a board on page two
## silently dropped the player back on page one). The ruling is the ordinary
## one for "where does closing something put you back": you return to where
## you were, and only a fresh app open starts cold on page one, which
## `_page`'s own default of 0 already gives it. `_page` is clamped rather
## than trusted outright, in case a registry that shrinks below the current
## page count ever makes today's "cannot happen" possible.
func _show_list() -> void:
	_list_root.visible = true
	Progress.touch()
	var clamped := clampi(_page, 0, _pages() - 1)
	# A new day since the list was last shown (a board left open across
	# 00:00 UTC) rebuilds the page, so yesterday's done marks come off.
	if clamped != _page or (_shown_day != 0 and Daily.date_key() != _shown_day):
		_page = clamped
		_build_page()
	_refresh_day()
	_show_tab("home")
	_enter()

func _enter() -> void:
	header.enter(ENTER_HEADER, ENTER_FADE)
	day_row.enter(ENTER_DAY)
	for i in cards.size():
		cards[i].enter(ENTER_CARDS + Motion.stagger(i, CARD_STEP, CARD_CAP))
	bar.enter(ENTER_BAR)
	_enter_pager()

## Fades the pager in with the last card, the way Motion.appear would -- but
## Motion.appear only zeroes `modulate.a`, and a Control at alpha 0 is still
## `visible` and still hands its buttons every tap by hit rect (found by
## review, 2026-09-20): during the ~0.85s before this fade starts, `_prev`
## and `_next` sat there fully transparent and fully live, `_prev` refusing
## every tap silently because page one starts it disabled. Hiding the node
## outright for the wait and only setting it visible the instant the fade
## begins is what keeps it untappable for exactly as long as it reads
## invisible, rather than trying to chase every button's mouse_filter by hand.
func _enter_pager() -> void:
	Motion.stop(_pager_tw)
	if _pages() <= 1:
		return
	if Motion.reduce:
		_pager.visible = true
		_pager.modulate.a = 1.0
		return
	_pager.visible = false
	_pager.modulate.a = 0.0
	_pager_tw = create_tween()
	_pager_tw.tween_callback(func() -> void: _pager.visible = true) \
		.set_delay(ENTER_CARDS + CARD_CAP)
	_pager_tw.tween_property(_pager, "modulate:a", 1.0, ENTER_FADE)

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
	_show_tab(tab)

## Home is the day row, the grid and the pager; Stats and Streak each put
## their body in that room. A tab's body fades in; Home re-fits the grid,
## which is not measured while it is hidden.
func _show_tab(key: String) -> void:
	# Re-picking the open tab does nothing; Home always runs, because
	# _show_list relies on it to restore the grid and fit it.
	if key == _tab and key != "home":
		return
	_tab = key
	bar.show_tab(key)
	var home := key == "home"
	day_row.visible = home
	_grid_slot.visible = home
	_pager_seam.visible = home
	streak_tab.visible = key == "streak"
	stats_tab.visible = key == "stats"
	Motion.stop(_tab_tw)
	if home:
		_set_pager(_page, _pages())
		_pager.modulate.a = 1.0
		_queue_fit()
		return
	# A pager fade still queued from the entrance would bring the pill back
	# over the tab.
	Motion.stop(_pager_tw)
	_pager.visible = false
	var body: Control = streak_tab if key == "streak" else stats_tab
	body.refresh()
	_tab_tw = Motion.appear(body, 0.0, 1.0, ENTER_FADE)
	Analytics.track("tab_opened", {"tab": key})

## A card that names a board nobody has drawn flat yet.
func _on_soon(entry: Dictionary) -> void:
	_say(tr("MENU_NO_FLAT") % entry.get("title", ""))

## Opens one of the seventeen. A `soon` card never gets here.
func _open(entry: Dictionary) -> void:
	if Registry.is_soon(entry) or _swiped:
		return
	# A card whose difficulties are different boards (Sudoku's 6x6 and 9x9)
	# asks which first; the sheet calls _open_at with the answer.
	if bool(entry.get("pick_difficulty", false)):
		difficulty_sheet.ask(entry)
		return
	_open_at(entry, 1)

func _open_at(entry: Dictionary, difficulty: int) -> void:
	var host: Control = FlatHost.new()
	host.setup(entry, difficulty, Progress.completed(Registry.progress_id(entry, difficulty)))
	_mount_host(host)

func _mount_host(host: Control) -> void:
	if host.has_signal("daily_completed"):
		host.daily_completed.connect(_on_daily_completed)
	# The win's invite to the next level: this board leaves and the same
	# card opens at that level, without a stop at the list in between.
	if host.has_signal("play_level"):
		host.play_level.connect(func(difficulty: int) -> void:
			host.queue_free()
			_open_at(host._entry, difficulty))
	host.closed.connect(func() -> void:
		host.queue_free()
		_show_list())
	add_child(host)
	_list_root.visible = false

## Marks the day the board was dealt on. A board dealt yesterday and solved
## after 00:00 UTC completes yesterday's card, so today's stays open.
func _on_daily_completed(puzzle_id: String, date_key: int) -> void:
	if puzzle_id.is_empty():
		return
	Progress.mark_completed(puzzle_id, date_key)
	if date_key != _shown_day:
		return
	for card in cards:
		if is_instance_valid(card) and String(card.entry.get("id", "")) == puzzle_id:
			card.set_completed(true)
			card.set_levels(Progress.levels_done(puzzle_id, date_key))
			break
