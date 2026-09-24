extends Control

## The first screen: the wordmark and the two characters at the top, the day
## row under them, a page of twelve puzzle cards in a grid of three, and the
## bottom bar. Everything on it is drawn in 2D -- there is no stage, no
## World3D and no model anywhere on this screen.
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
const DifficultySheet = preload("res://ui/menu/difficulty_sheet.gd")
const Icons = preload("res://ui/icons.gd")
const Analytics = preload("res://core/analytics.gd")
const StreakTab = preload("res://ui/menu/streak_tab.gd")
const StatsTab = preload("res://ui/menu/stats_tab.gd")
const Streak = preload("res://core/streak.gd")

const MARGIN := 40
const GAP := 20
const COLS := 2
## The narrowest a card may be drawn: two across in the 1000 between the
## margins, less one 20 gap (spec 2026-09-24-painted-menu, section 2).
## `_fit_grid` fits as many columns of it as the screen is wide.
const MIN_CARD_W := 490.0
## How far the gap between card rows may close to keep a row. The day row is
## 200 and the grid has 36 of slack at 1920, so the gap rarely closes; it is
## kept for shorter screens.
const MIN_ROW_GAP := 16
## Eight cards a page: two across and four down is what 80 of margin, 60 of
## gaps, a 380 header, a 200 day row and a 120 bar leave for rows of 246.
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
const TOAST_OVER := 150.0 + 40.0 + 10.0
const TOAST_H := 88.0
## The pager strip, laid over the bar the way the toast is: the header, the
## day row, the grid and the bar already spend the screen exactly (see the
## toast's own comment in _build_list), so this is an overlay on
## `_list_root` rather than a row of the column, and it costs the grid
## nothing -- a card stays 252 whether or not a second page exists.
##
## The screen leaves no free band for it: the true gap between the grid and
## the bar is GAP (20), the same 20 already spent as separation everywhere
## else. Rather than a bare row of tiny controls straddling that seam (which
## reads as ink on the card whose rim it crosses, not a control of its own --
## found by review, 2026-09-20), the pager is its own paper pill (built in
## _build_list below, `CozyTheme.card` -- the HUD's usual card stylebox)
## that floats across the seam: PAGER_MID is the seam's vertical centre,
## and the pill is centred there and centred horizontally, so wherever it
## overlaps a neighbour it reads as a chip laid over the page rather than a
## mark on either one.
##
## That overlap is real and was measured by review, 2026-09-20: the pill's
## buttons sit about 18px inside the last card row's bottom rim. Kept rather
## than pushed lower, on the ruling that the pill is drawn on top and, once
## _enter_pager below stops it being tappable while it is still fading in,
## a tap that lands there correctly belongs to whichever control the player
## can actually see -- and the bar sits directly under it with no spare band
## to push into.
const PAGER_MID := 150.0 + 40.0 + 10.0
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
var _list_root: Control
var _grid: GridContainer
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
	var insets := SafeArea.insets(self)
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

	# --- the cards, a page at a time ---
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = COLS
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	root.add_child(_grid)

	# Stats and Streak take the day row's, the grid's and the pager's room
	# when picked; the header and the bar stay (spec 2026-09-24, section 4).
	streak_tab = StreakTab.new()
	streak_tab.name = "StreakTab"
	streak_tab.visible = false
	root.add_child(streak_tab)
	stats_tab = StatsTab.new()
	stats_tab.name = "StatsTab"
	stats_tab.visible = false
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
	_pager.offset_top = -PAGER_MID - PAGER_SLOT_H * 0.5
	_pager.offset_bottom = -PAGER_MID + PAGER_SLOT_H * 0.5
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
	pill.add_theme_stylebox_override("panel", CozyTheme.card(Pal.SURFACE, 24, Pal.LINE, 4, 8))
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
	_toast.offset_top = -TOAST_OVER - TOAST_H
	_toast.offset_bottom = -TOAST_OVER
	_list_root.add_child(_toast)

	# Built last: _set_pager (called from _build_page) reaches into _pager,
	# _prev, _next and _dots, all built just above -- calling this any
	# earlier (it once sat right after _grid, before any of them existed)
	# left _set_pager silently failing on a null _pager and _dots never
	# getting told how many pages there are, which is why the very first
	# render only ever showed one dot.
	_build_page()

## How many pages the registry needs at PER_PAGE a page; at least one, so an
## empty registry does not divide by nothing.
func _pages() -> int:
	return maxi(1, ceili(float(Registry.PUZZLES.size()) / float(_per_page)))

## The entries on the page that is up, with the index each has in the
## registry -- the colour comes off that index, so a card keeps its colour
## whichever page it lands on.
func _page_entries() -> Array:
	var out: Array = []
	var from := _page * _per_page
	for i in range(from, mini(from + _per_page, Registry.PUZZLES.size())):
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
		var card := PuzzleCard.new(entry, Pal.CAT[int(row.i) % Pal.CAT.size()],
			Progress.completed(String(entry.id)))
		card.name = "Card_" + entry.id
		card.fit_height(_row_h)
		card.open.connect(_open.bind(entry))
		card.blocked.connect(_on_soon.bind(entry))
		cards.append(card)
		_grid.add_child(card)
	# A short last row -- one whose cards do not fill COLS -- hands the real
	# columns it does have the empty
	# one's
	# leftover width: GridContainer sizes a column to the widest cell it
	# actually has, and a column with no cell in that row does not compete
	# for the row's stretch at all. Padding out to COLS with zero-minimum,
	# EXPAND_FILL fillers keeps three columns competing on every row, on any
	# page, so a card is 320 wide everywhere rather than however many empty
	# columns' worth wider. The mirror of the height floor
	# puzzle_card_2d.gd's CARD_H sets on the other axis.
	#
	# **At eighteen cards this does not run**: page two holds six, COLS is
	# three, 6 % 3 is zero, so no filler is made. It ran at seventeen, where
	# page two held five, and it went unused at fifteen, where page two's
	# three over three columns was a full row -- which is why the path stays
	# exactly where it is rather than being deleted the moment a page happens
	# to come out square. Whether it runs is a property of today's card
	# count, never of the pager.
	var short := cards.size() % _cols
	if short > 0:
		for i in _cols - short:
			var filler := Control.new()
			filler.name = "Filler_%d" % i
			filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_fillers.append(filler)
			_grid.add_child(filler)
	_set_pager(_page, _pages())

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
	if not _grid.visible:
		return
	if _column == null or _column.size.x <= 0.0:
		return
	var room_w := _list_root.size.x - _margins.get_theme_constant("margin_left") \
		- _margins.get_theme_constant("margin_right")
	var room_h := _list_root.size.y - _margins.get_theme_constant("margin_top") \
		- _margins.get_theme_constant("margin_bottom") - header.size.y - day_row.size.y - bar.size.y - GAP * 3
	var cols := maxi(1, floori((room_w + GAP + 0.5) / (MIN_CARD_W + GAP)))
	var rows := maxi(1, floori((room_h + MIN_ROW_GAP) / (PuzzleCard.CARD_H + MIN_ROW_GAP)))
	var slack := room_h - rows * PuzzleCard.CARD_H - (rows - 1) * GAP
	var grow := floorf(clampf(slack / rows, 0.0, PuzzleCard.ART_GROW))
	var gap := GAP
	if rows > 1:
		gap = maxi(MIN_ROW_GAP, GAP + floori((slack - grow * rows) / (rows - 1)))
	_grid.add_theme_constant_override("v_separation", gap)
	var per := cols * rows
	var row_h := PuzzleCard.CARD_H + grow
	if per != _per_page or cols != _cols:
		var first := _page * _per_page
		_per_page = per
		_cols = cols
		_grid.columns = cols
		_page = clampi(first / per, 0, _pages() - 1)
		_row_h = row_h
		_build_page()
	elif row_h != _row_h:
		_row_h = row_h
		for card in cards:
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
		and not settings_sheet.visible and _grid.visible

func _swipe_press(event: InputEvent, id: int, pressed: bool) -> void:
	if not pressed:
		if id == _swipe_id:
			_swipe_id = -1
		return
	if _swipe_id != -1:
		return
	_swiped = false
	var at: Vector2 = _grid.make_input_local(event).position
	if Rect2(Vector2.ZERO, _grid.size).has_point(at):
		_swipe_id = id
		_swipe_from = at

func _swipe_move(event: InputEvent) -> void:
	var d: Vector2 = _grid.make_input_local(event).position - _swipe_from
	if absf(d.x) < SWIPE or absf(d.x) < absf(d.y) * SWIPE_SLOPE:
		return
	_swipe_id = -1
	_swiped = true
	_turn_page(-1 if d.x > 0.0 else 1)

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
		# `add_child` appends, which would draw a fading card over the pager
		# pill -- right where the finger just pressed to turn the page (found
		# by review, 2026-09-20). `_pager` is built before `_toast` (see
		# _build_list) specifically so this puts the card under both.
		_list_root.move_child(card, _pager.get_index())
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
	_grid.visible = home
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
			break
