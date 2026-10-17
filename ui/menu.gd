extends Control

## The first screen: the wordmark and the two characters at the top, the day
## row under them, a page of eight puzzle cards in a grid of two (490x246
## cards, since the painted menu of 2026-09-24 -- twelve in a grid of three
## before that), and the pager under them. The categories (Puzzles, Versus,
## Arcade) are a row under the header since 2026-10-13
## (ui/menu/category_row.gd); a bottom bar of six tabs held them before, and
## "the bar" in the older notes below is that one. Everything on it is drawn in 2D -- there
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
const AgeGate = preload("res://core/age_gate.gd")
const UiSound = preload("res://ui/ui_sound.gd")
const Motion = preload("res://core/motion.gd")
const Progress = preload("res://core/progress.gd")
const Registry = preload("res://ui/registry.gd")
const FlatHost = preload("res://ui/flat/flat_host.gd")
const CozyTheme = preload("res://ui/theme.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const RemoveAdsSheet = preload("res://ui/hud/remove_ads_sheet.gd")
const GiftsSheet = preload("res://ui/hud/gifts_sheet.gd")
const ShopSheet = preload("res://ui/hud/shop_sheet.gd")
const MenuHeader = preload("res://ui/menu/menu_header.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const DayRow = preload("res://ui/menu/day_row.gd")
const PuzzleCard = preload("res://ui/menu/puzzle_card_2d.gd")
const CategoryRow = preload("res://ui/menu/category_row.gd")
const DifficultySheet = preload("res://ui/menu/difficulty_sheet.gd")
const Icons = preload("res://ui/icons.gd")
const Analytics = preload("res://core/analytics.gd")
const StreakTab = preload("res://ui/menu/streak_tab.gd")
const StatsTab = preload("res://ui/menu/stats_tab.gd")
const VersusTab = preload("res://ui/menu/versus_tab.gd")
const VersusSheet = preload("res://ui/menu/versus_sheet.gd")
const SnookerScreen = preload("res://versus/snooker_screen.gd")
const ChessScreen = preload("res://versus/chess_screen.gd")
const CheckersScreen = preload("res://versus/checkers_screen.gd")
const HockeyScreen = preload("res://versus/hockey_screen.gd")
const BoatsScreen = preload("res://versus/boats_screen.gd")
const PennyScreen = preload("res://versus/penny_screen.gd")
const DominoesScreen = preload("res://versus/dominoes_screen.gd")
const ReversiScreen = preload("res://versus/reversi_screen.gd")
const ArcadeTab = preload("res://ui/menu/arcade_tab.gd")
const PagerPill = preload("res://ui/menu/pager_pill.gd")
const FireflyScreen = preload("res://arcade/firefly_screen.gd")
const MolehillScreen = preload("res://arcade/molehill_screen.gd")
const StackwoodScreen = preload("res://arcade/stackwood_screen.gd")
const BeelineScreen = preload("res://arcade/beeline_screen.gd")
const DeckchairScreen = preload("res://arcade/deckchair_screen.gd")
const EddyScreen = preload("res://arcade/eddy_screen.gd")
const FurrowScreen = preload("res://arcade/furrow_screen.gd")
const GriddleScreen = preload("res://arcade/griddle_screen.gd")
const TrivetScreen = preload("res://arcade/trivet_screen.gd")
const TallyScreen = preload("res://arcade/tally_screen.gd")
const BagatelleScreen = preload("res://arcade/bagatelle_screen.gd")
const ThirteenScreen = preload("res://arcade/thirteen_screen.gd")
const PeapodScreen = preload("res://arcade/peapod_screen.gd")
const PosyScreen = preload("res://arcade/posy_screen.gd")
const NightlightScreen = preload("res://arcade/nightlight_screen.gd")
const FactoryTab = preload("res://ui/menu/factory_tab.gd")
const ArcadeRecord = preload("res://arcade/arcade_record.gd")
const FurrowSim = preload("res://arcade/furrow_sim.gd")
const GriddleSim = preload("res://arcade/griddle_sim.gd")
const TallySim = preload("res://arcade/tally_sim.gd")
const BagatelleSim = preload("res://arcade/bagatelle_sim.gd")
const FactoryScreen = preload("res://factory/screen.gd")
const Streak = preload("res://core/streak.gd")
const FriendsSheet = preload("res://ui/menu/friends_sheet.gd")
const InviteCard = preload("res://ui/menu/invite_card.gd")
const Social = preload("res://core/social.gd")
const Online = preload("res://versus/online/online.gd")
const Record = preload("res://versus/versus_record.gd")
const Haptics = preload("res://core/haptics.gd")

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
const ENTER_BAR := 0.05
const ENTER_FADE := 0.3
## How long a line about an unbuilt thing stays up.
const TOAST_TIME := 2.6
const TOAST_FADE := 0.25
## Where the line sits: this far above the screen's bottom, and this tall.
## Over the pager's seam since the bar left the foot of the screen
## (2026-10-13), on a paper plate of its own, so it reads over the pill.
const TOAST_OVER := MARGIN - 18.0
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
##
## **52 since 2026-10-13**, when the bar left the foot of the screen for the
## category row under the header (ui/menu/category_row.gd, 88 tall where the
## bar was 120): the 32 came here, so the pill stands in room of its own
## with nothing under it to lean on, and the budget is the same 1040:
## 1920 - 80 margins - 380 header - 88 categories - 200 day - 60 gaps -
## 52 seam - 20 extra gap.
const PAGER_SEAM := 52.0
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
## Since 2026-10-13 the seam is the last row of the column, over the bottom
## margin.
const PAGER_MID := MARGIN + PAGER_SEAM * 0.5
## The pill's own slot: taller than the pill needs, so CenterContainer never
## clips it.
const PAGER_SLOT_H := 64.0
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
## A page out of sight stands this many spans to the side (see `_spare`).
const PARK := 3.0
## Where a friend's card is drawn: over any sheet (10) and a sheet's own
## dialog (12 more).
const CARD_Z := 30
## The line friend_link_failed says: its slot's height, the text's width and
## how long it stands.
const WORD_H := 150.0
const WORD_W := 720.0
const WORD_TIME := 4.0

var settings_sheet: Control
## The purchase sheet: the header's remove-ads button, settings' row and
## (through world/main.gd) the banner's tab all open it.
var remove_ads_sheet: Control
var difficulty_sheet: Control
var versus_sheet: Control
## The daily gifts and the shop (spec 2026-09-28-gold-gifts-design.md).
var gifts_sheet: Control
var shop_sheet: Control
## Friends (spec 2026-10-04-friends-design.md): the sheet behind the Versus
## tab's row, and the one card a friend raises over whatever is open -- an
## invite to a game or a new friend (ui/menu/invite_card.gd). The card is
## built when there is something to say and freed after, and is this node's
## last child while it lives, over a host.
var friends_sheet: Control
var friend_card: Control
## Set while open_friend_game closes what is open, so a screen's `closed`
## neither shows the list nor offers an interstitial on the way to the game.
var _switching := false
var cards: Array = []
## Invisible padding for a short last row (task 8's width fix, 2026-09-20):
## see _build_page().
var _fillers: Array = []
var header: Control
var day_row: Control
var bar: Control
var streak_tab: Control
var stats_tab: Control
var versus_tab: Control
var arcade_tab: Control
var factory_tab: Control
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
## The pages beside the one that is up, built ahead and kept hidden: page ->
## {grid, cards, fillers}. Building eight cards and drawing them for the
## first time is tens of milliseconds on a phone, and it used to be paid on
## the frame a drag began, every drag (the user, 2026-10-09: the swipe
## "feels waaay too laggy"). Now a drag only shows what is already there:
## `_warm` builds a neighbour a moment after the page comes to rest, and a
## page turned away from stays built as the peek.
##
## **A page out of sight is parked, never hidden** (`_park`: shown, PARK
## spans off to the side, where the canvas culls it). Showing a hidden grid
## made every card on it draw again, 10 to 40 ms on this Mac on the frame
## the finger first moved, which was most of the lag that building ahead
## was meant to remove. `_peek_shown` says whether the peek is in the slide.
var _spare := {}
var _peek_shown := false
var _warm_gen := 0
## The fitted gap between rows, for a grid made after the fit.
var _row_gap := GAP
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
## Which list of cards the grid is showing: the Puzzles ("home"), "versus"
## or "arcade". One grid, one swipe, one slide and one pager for all three;
## only the list and the row above it change (the day row, the Friends row,
## the gold strip). Each keeps the page it was left on.
var _deck := "home"
var _deck_page := {"home": 0, "versus": 0, "arcade": 0}
## The lists the grid is not showing, kept built as they were left: deck ->
## the bundle `_keep_deck` packs (its page, the page's neighbours, the fit
## it was built at). A tab used to free its cards and build the next list's
## on the tap, 80-120 ms headless on this Mac every switch and ~440 ms more
## the first time, compiling the faces' scripts (2026-10-15: the user, "check
## why menu is so laggy"); now a tap swaps a kept grid in, and `_warm` bakes
## the lists not yet seen while the menu sits idle.
var _kept := {}
## The day the page up was built on, kept with it: a list kept across 00:00
## UTC is built again rather than shown with yesterday's marks.
var _built_day := 0
## The page being baked a card a frame (`_bake_step`), or empty: {gen,
## deck, page, rows, fit, made, done}.
var _baking := {}
## Card faces' scripts still loading on a thread, and the ones loaded, held
## so the cache keeps them (`_load_faces`).
var _faces_loading: Array = []
var _faces: Array = []
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
var _pill: PagerPill
var _pager_tw: Tween
## The date key the list last showed; _check_day refreshes when it moves.
var _shown_day := 0

func _ready() -> void:
	theme = CozyTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ads.banner_changed.connect(func(_visible: bool, _height: float) -> void: _apply_insets())
	_build_list()
	_load_faces()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	settings_sheet.reduce_changed.connect(header.refresh_motion)
	add_child(settings_sheet)
	remove_ads_sheet = RemoveAdsSheet.new()
	remove_ads_sheet.name = "RemoveAdsSheet"
	add_child(remove_ads_sheet)
	header.remove_ads.connect(func() -> void: remove_ads_sheet.open_from("header"))
	settings_sheet.remove_ads.connect(func() -> void: remove_ads_sheet.open_from("settings"))
	gifts_sheet = GiftsSheet.new()
	gifts_sheet.name = "GiftsSheet"
	add_child(gifts_sheet)
	header.gifts.connect(func() -> void: gifts_sheet.open())
	shop_sheet = ShopSheet.new()
	shop_sheet.name = "ShopSheet"
	add_child(shop_sheet)
	arcade_tab.shop.connect(func(game: String) -> void: shop_sheet.open_for(game, "arcade"))
	Wallet.changed.connect(func() -> void: header.set_gifts(Wallet.claimable()))
	difficulty_sheet = DifficultySheet.new()
	difficulty_sheet.name = "DifficultySheet"
	difficulty_sheet.chose.connect(_open_at)
	add_child(difficulty_sheet)
	# A Versus card asks who to play on the same sheet's rows.
	versus_sheet = VersusSheet.new()
	versus_sheet.name = "VersusSheet"
	versus_sheet.picked.connect(func(game: String, level: int) -> void:
		Record.set_last_level(game, level)
		_open_versus(game, level))
	add_child(versus_sheet)
	versus_tab.open.connect(versus_sheet.ask_game)
	friends_sheet = FriendsSheet.new()
	friends_sheet.name = "FriendsSheet"
	friends_sheet.play.connect(func(game: String, uid: String) -> void: open_friend_game(game, uid, false))
	add_child(friends_sheet)
	versus_tab.friends.connect(func() -> void: friends_sheet.open())
	var hub := Social.hub()
	hub.invited.connect(_on_invited)
	hub.withdrawn.connect(_on_withdrawn)
	hub.befriended.connect(_on_befriended)
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
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()

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
	header.set_gifts(Wallet.claimable(today))

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

	# The categories, over the list they pick (the bottom bar until
	# 2026-10-13).
	bar = CategoryRow.new()
	bar.name = "Categories"
	bar.picked.connect(_on_tab)
	root.add_child(bar)

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
	streak_tab.open_stats.connect(func() -> void: _show_tab("stats"))
	root.add_child(stats_tab)
	versus_tab = VersusTab.new()
	versus_tab.name = "VersusTab"
	versus_tab.visible = false
	root.add_child(versus_tab)
	arcade_tab = ArcadeTab.new()
	arcade_tab.name = "ArcadeTab"
	arcade_tab.visible = false
	arcade_tab.play.connect(_open_arcade)
	root.add_child(arcade_tab)
	# Each is the row over the grid on its own tab, where the day row stands
	# on Puzzles.
	root.move_child(versus_tab, day_row.get_index() + 1)
	root.move_child(arcade_tab, day_row.get_index() + 2)
	# Factory is a card of the Arcade list since 2026-10-13 and this is no
	# page any more: it stays, never shown, as the owner of the one land
	# (it makes the sim, keeps it and lends it to the screen).
	factory_tab = FactoryTab.new()
	factory_tab.name = "FactoryTab"
	factory_tab.visible = false
	root.add_child(factory_tab)
	arcade_tab.factory = factory_tab

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
	# The pill every list of the first screen wears (ui/menu/pager_pill.gd).
	_pill = PagerPill.new(true)
	_pill.turned.connect(_turn_page)
	pager_center.add_child(_pill)

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
	# A plate of its own: there is no bar under it any more, only the pager
	# and the last row's foot.
	_toast.add_theme_stylebox_override("normal", CozyTheme.lifted(Pal.SURFACE, int(TOAST_H * 0.5), 12))
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
	# and _pill, built just above -- calling this any
	# earlier (it once sat right after _grid, before any of them existed)
	# left _set_pager silently failing on a null _pager and _dots never
	# getting told how many pages there are, which is why the very first
	# render only ever showed one dot.
	_build_page()

func _new_grid(grid_name: String) -> GridContainer:
	var g := GridContainer.new()
	g.name = grid_name
	g.columns = _cols
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.add_theme_constant_override("h_separation", GAP)
	g.add_theme_constant_override("v_separation", _row_gap)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid_slot.add_child(g)
	return g

## How many pages the registry needs at PER_PAGE a page; at least one, so an
## empty registry does not divide by nothing.
func _pages(deck := _deck, per := _per_page) -> int:
	return maxi(1, ceili(float(_source(deck).size()) / float(per)))

## The list the grid is showing (or `deck`'s): the registry, or a tab's own
## games.
func _source(deck := _deck) -> Array:
	match deck:
		"arcade":
			return arcade_tab.entries()
		"versus":
			return versus_tab.entries()
	return Registry.PUZZLES

## The row that stands over the grid for the list that is up.
func _top_row(deck := _deck) -> Control:
	match deck:
		"arcade":
			return arcade_tab
		"versus":
			return versus_tab
	return day_row

## The entries on the page that is up, with the index each has in the
## registry -- the colour comes off that index, so a card keeps its colour
## whichever page it lands on.
func _page_entries(page := _page, deck := _deck, per := _per_page) -> Array:
	var out: Array = []
	var from := page * per
	var source := _source(deck)
	for i in range(from, mini(from + per, source.size())):
		out.append({"i": i, "entry": source[i]})
	return out

func _build_page() -> void:
	_drop_peek()
	_free_nodes(_grid, cards)
	_free_nodes(_grid, _fillers)
	_grid.position.x = 0.0
	_fill(_grid, _page, cards, _fillers)
	_built_day = Daily.date_key()
	_set_pager(_page, _pages())
	# once the menu's entrance has played
	_queue_warm(0.9)

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
	var done := Progress.completed_on()
	for row in _page_entries(page):
		var card := _make_card(row, _deck, today, done, _row_h)
		into.append(card)
		grid.add_child(card)
	_pad(grid, into, pad, _cols)

## One card of `deck`'s list, `row` as _page_entries gives it, fitted to a
## row of `row_h`.
func _make_card(row: Dictionary, deck: String, today: Array, done: Dictionary, row_h: float) -> PuzzleCard:
	var entry: Dictionary = row.entry
	var colour: Color = Pal.CAT[int(row.i) % Pal.CAT.size()]
	var card: PuzzleCard
	# A board is the same card on any list (Marigold stands on Arcade).
	if deck == "home" or not Registry.arcade(String(entry.id)).is_empty():
		card = PuzzleCard.new(entry, colour,
			done.has(String(entry.id)), Progress.levels_in(today, String(entry.id)))
		card.open.connect(_open.bind(entry))
		card.blocked.connect(_on_soon.bind(entry))
	else:
		# A tab's game: the same card, opened through the tab's own
		# signal; a swipe that started on it does not open it.
		var game := String(entry.id)
		card = PuzzleCard.new(entry, colour)
		if deck == "arcade":
			card.say(arcade_tab.line(game), arcade_tab.boosted(game))
			card.open.connect(func() -> void:
				if not _swiped:
					arcade_tab.play.emit(game))
		else:
			card.open.connect(func() -> void:
				if not _swiped:
					versus_tab.open.emit(game))
	card.name = "Card_" + entry.id
	card.fit_height(row_h)
	return card

## Pads `grid`'s short last row out to `cols` with fillers, appended to `pad`.
func _pad(grid: GridContainer, into: Array, pad: Array, cols: int) -> void:
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
	var short := into.size() % cols
	if short > 0:
		for i in cols - short:
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
	var fit := _measure_fit(_deck, _pager_seam.visible)
	var gap: int = fit.gap
	_row_gap = gap
	for g: GridContainer in [_grid, _peek] + _spare_grids():
		g.add_theme_constant_override("v_separation", gap)
	var per: int = fit.per
	var cols: int = fit.cols
	var row_h: float = fit.row_h
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
		for card in cards + _peek_cards + _spare_cards():
			card.fit_height(row_h)

## The page `deck`'s list fits on this screen, with or without the pager's
## seam: {per, cols, row_h, gap} (see _fit_grid).
func _measure_fit(deck: String, seam: bool) -> Dictionary:
	var room_w := _list_root.size.x - _margins.get_theme_constant("margin_left") \
		- _margins.get_theme_constant("margin_right")
	var room_h := _list_root.size.y - _margins.get_theme_constant("margin_top") \
		- _margins.get_theme_constant("margin_bottom") - header.size.y - _top_h(deck) - bar.size.y - GAP * 3
	if seam:
		room_h -= PAGER_SEAM + GAP
	var cols := maxi(1, floori((room_w + GAP + 0.5) / (MIN_CARD_W + GAP)))
	var rows := maxi(1, floori((room_h + MIN_ROW_GAP) / (PuzzleCard.CARD_H + MIN_ROW_GAP)))
	var slack := room_h - rows * PuzzleCard.CARD_H - (rows - 1) * GAP
	var grow := floorf(clampf(slack / rows, 0.0, PuzzleCard.ART_GROW))
	var gap := GAP
	if rows > 1:
		gap = maxi(MIN_ROW_GAP, GAP + floori((slack - grow * rows) / (rows - 1)))
	return {"per": cols * rows, "cols": cols, "row_h": PuzzleCard.CARD_H + grow, "gap": gap}

## How tall the row over the grid is: its laid height, or its minimum when
## it has only just been shown and has none yet.
func _top_h(deck := _deck) -> float:
	var row := _top_row(deck)
	return maxf(row.size.y if row.visible else 0.0, row.get_combined_minimum_size().y)

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
			# The card under the lifting finger is still pressed; it does
			# not open (`_open`) and must not click either.
			if _swiped:
				UiSound.hush()
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
	if _peek_shown and _peek_page >= 0:
		var dir := _peek_page - _page
		var toward := -dir * _drag_x
		var fling := -dir * _drag_v
		if toward > span * PAGE_COMMIT or (fling > PAGE_FLICK and toward > 0.0):
			go = dir
	_slide_to(go)

## Stands `page` in the peek grid if it is not the one there: the page built
## ahead for it (`_spare`) when there is one, so nothing is built under the
## finger; the page that was the peek is kept as a spare.
func _show_peek(page: int) -> void:
	if _peek_page != page:
		if _peek_page >= 0:
			_park(_peek)
			_peek.name = "Spare_%d" % _peek_page
			_spare[_peek_page] = {"grid": _peek, "cards": _peek_cards, "fillers": _peek_fillers}
			_peek = null
			_peek_cards = []
			_peek_fillers = []
		if _spare.has(page):
			var e: Dictionary = _spare[page]
			_spare.erase(page)
			if _peek != null:
				_grid_slot.remove_child(_peek)
				_peek.queue_free()
			_peek = e.grid
			_peek_cards = e.cards
			_peek_fillers = e.fillers
			_peek.name = "Peek"
		else:
			if _peek == null:
				_peek = _new_grid("Peek")
			_fill(_peek, page, _peek_cards, _peek_fillers)
		_peek_page = page
	_peek.visible = true
	_peek_shown = true

func _hide_peek() -> void:
	_peek_shown = false
	_park(_peek)

## Stands a grid out of sight without hiding it.
func _park(g: Control) -> void:
	g.position.x = _span() * PARK

func _spare_grids() -> Array:
	var out: Array = []
	for e: Dictionary in _spare.values():
		out.append(e.grid)
	return out

func _spare_cards() -> Array:
	var out: Array = []
	for e: Dictionary in _spare.values():
		out.append_array(e.cards)
	return out

func _free_spare(page: int) -> void:
	var e: Dictionary = _spare[page]
	_spare.erase(page)
	_grid_slot.remove_child(e.grid)
	(e.grid as Node).queue_free()

## Asks for the pages beside this one to be built, `delay` from now; a later
## ask replaces an earlier one.
func _queue_warm(delay: float) -> void:
	_warm_gen += 1
	if is_inside_tree():
		get_tree().create_timer(maxf(delay, 0.03)).timeout.connect(_warm.bind(_warm_gen))

## Builds one page beside the one that is up, the next before the previous,
## and asks again for the other. It is parked as it is built, shown, so its
## first layout and its first drawing are paid now and not on the frame a
## finger first pulls it in. Never under a drag or a slide: the landing asks
## again.
##
## Then, with both neighbours built, the lists the grid is not showing:
## each the page it was left on, at the fit it will have, kept as if it had
## been shown and left (`_kept`), so the tap on its tab only swaps it in.
## Every page is baked a card a frame (`_bake`), never a page in one frame.
func _warm(gen: int) -> void:
	if gen != _warm_gen or _dragging or Motion.running(_slide_tw) \
			or _list_root == null or not _list_root.visible or not _grid_slot.visible:
		return
	if _can_swipe():
		for page: int in [_page + 1, _page - 1]:
			if page < 0 or page >= _pages() or page == _peek_page or _spare.has(page):
				continue
			var fit := {"per": _per_page, "cols": _cols, "row_h": _row_h, "gap": _row_gap}
			_bake(gen, _deck, page, fit, func(made: Dictionary) -> void:
				if page == _peek_page or _spare.has(page) or page >= _pages():
					_free_grid(made.grid)
					return
				made.grid.name = "Spare_%d" % page
				_spare[page] = made
				_queue_warm(0.15))
			return
	for key: String in ["home", "versus", "arcade"]:
		if key == _deck or _kept.has(key):
			continue
		var fit := _measure_fit(key, key == "home" or _pages(key) > 1)
		var page := clampi(int(_deck_page[key]), 0, _pages(key, fit.per) - 1)
		_bake(gen, key, page, fit, func(made: Dictionary) -> void:
			if key == _deck or _kept.has(key):
				_free_grid(made.grid)
				return
			var peek := _new_grid("KeptPeek_" + key)
			peek.columns = fit.cols
			peek.visible = false
			made.grid.name = "Kept_" + key
			_kept[key] = {"grid": made.grid, "cards": made.cards, "fillers": made.fillers,
				"peek": peek, "peek_cards": [], "peek_fillers": [], "peek_page": -1, "spare": {},
				"page": page, "per": fit.per, "cols": fit.cols, "row_h": fit.row_h,
				"day": Daily.date_key(), "ids": _ids(key)}
			_queue_warm(0.15))
		return

## Starts baking `deck`'s `page` into a parked grid of its own, one card a
## frame from _process, and hands {grid, cards, fillers} to `done` once the
## last is in. Dropped, grid and all, once a later warm is asked for; held
## under a drag or a slide, while the list is not up, and while the next
## card's face is still loading.
func _bake(gen: int, deck: String, page: int, fit: Dictionary, done: Callable) -> void:
	if not _baking.is_empty():
		_free_grid(_baking.made.grid)
	var g := _new_grid("Baking")
	g.columns = fit.cols
	g.add_theme_constant_override("v_separation", fit.gap)
	_park(g)
	_baking = {"gen": gen, "deck": deck, "rows": _page_entries(page, deck, fit.per),
		"fit": fit, "made": {"grid": g, "cards": [], "fillers": []}, "done": done,
		"today": Progress.solve_log().get(Daily.date_key(), []), "done_ids": Progress.completed_on()}
	set_process(true)

func _bake_step() -> void:
	var b := _baking
	if int(b.gen) != _warm_gen:
		_free_grid(b.made.grid)
		_baking = {}
		return
	if _dragging or Motion.running(_slide_tw) or not _list_root.visible:
		return
	var made: Dictionary = b.made
	var rows: Array = b.rows
	if rows.is_empty():
		_baking = {}
		_pad(made.grid, made.cards, made.fillers, int(b.fit.cols))
		(b.done as Callable).call(made)
		return
	var entry: Dictionary = rows[0].entry
	if _faces_loading.has(String(entry.get("card", ""))):
		return
	var card := _make_card(rows.pop_front(), String(b.deck), b.today, b.done_ids, float(b.fit.row_h))
	made.cards.append(card)
	(made.grid as Node).add_child(card)

func _free_grid(g: Node) -> void:
	if is_instance_valid(g):
		if g.get_parent() != null:
			g.get_parent().remove_child(g)
		g.queue_free()

## The ids `deck` lists, to tell a kept list the list has since changed.
func _ids(deck: String) -> Array:
	var out: Array = []
	for e: Dictionary in _source(deck):
		out.append(String(e.id))
	return out

func _drop_peek() -> void:
	Motion.stop(_slide_tw)
	for page: int in _spare.keys():
		_free_spare(page)
	_free_nodes(_peek, _peek_cards)
	_free_nodes(_peek, _peek_fillers)
	_peek_page = -1
	_peek_shown = false
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
	_pill.show_page(page, pages)

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
	if go == 0 and not _peek_shown:
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
		if _peek_shown:
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
		# the page turned away from stays built, as the peek: a swipe back
		# shows it as it is
		var was := _page
		_page = _peek_page
		_peek_page = was
		_peek.name = "Turned"
		_grid.name = "Grid"
		_peek.name = "Peek"
		for page: int in _spare.keys():
			if absi(page - _page) > 1:
				_free_spare(page)
	_hide_peek()
	_drag_x = 0.0
	_grid.position.x = 0.0
	_set_pager(_page, _pages())
	_queue_warm(0.05)

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
func _show_list(tab := "home") -> void:
	_list_root.visible = true
	Progress.touch()
	var clamped := clampi(_page, 0, _pages() - 1)
	# A new day since the list was last shown (a board left open across
	# 00:00 UTC) rebuilds the page, so yesterday's done marks come off.
	if clamped != _page or (_shown_day != 0 and Daily.date_key() != _shown_day):
		_page = clamped
		_build_page()
	_refresh_day()
	# Coming back to a tab that is already the open one still has to lay it
	# out again (the Versus tab's record has moved).
	if tab != "home":
		_tab = ""
	_show_tab(tab)
	_enter()
	_queue_warm(0.9)
	# The week's gift, once a day, by itself, once the menu has risen.
	if tab == "home" and Wallet.calendar_open():
		get_tree().create_timer(0.9).timeout.connect(func() -> void:
			if is_instance_valid(gifts_sheet) and _list_root.visible and _tab == "home" \
					and not gifts_sheet.is_open() and Wallet.should_auto_open() \
					and (AgeGate.known() or not OS.has_feature("mobile")):
				gifts_sheet.open())

## The opening has lifted off the first screen (world/boot.gd): the entrance
## again from its first beat, since the one `_ready` played went by under
## it. Nothing when a board or a screen is up over the list.
func rise() -> void:
	if _list_root != null and _list_root.visible:
		_enter()

func _enter() -> void:
	header.enter(ENTER_HEADER, ENTER_FADE)
	day_row.enter(ENTER_DAY)
	for i in cards.size():
		cards[i].enter(ENTER_CARDS + Motion.stagger(i, CARD_STEP, CARD_CAP))
	bar.enter(ENTER_BAR)
	if _tab == "home":
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
	var deck := key in _deck_page
	day_row.visible = home
	streak_tab.visible = key == "streak"
	stats_tab.visible = key == "stats"
	versus_tab.visible = key == "versus"
	arcade_tab.visible = key == "arcade"
	_grid_slot.visible = deck
	Motion.stop(_tab_tw)
	if deck:
		# One grid for the three lists: the list changes under it and the
		# page it was left on comes back.
		var changed := _deck != key
		if changed:
			_keep_deck()
			_deck = key
		if not home:
			(_top_row() as Control).refresh()
		if changed:
			# The list as it was left (or as `_warm` baked it), else built now
			# at the fit it will have, so the fit does not build it twice.
			if not _take_deck(key):
				var fit := _measure_fit(key, home or _pages(key) > 1)
				_per_page = fit.per
				_cols = fit.cols
				_row_h = fit.row_h
				_row_gap = fit.gap
				_grid.columns = _cols
				_peek.columns = _cols
				_grid.add_theme_constant_override("v_separation", _row_gap)
				_page = clampi(int(_deck_page[key]), 0, _pages() - 1)
				_build_page()
		else:
			_page = clampi(_page, 0, _pages() - 1)
			if not home:
				# Back from one of the tab's games: its best moved, the cards stay.
				_refresh_cards()
		_pager_seam.visible = home or _pages() > 1
		_set_pager(_page, _pages())
		_pager.modulate.a = 1.0
		_queue_fit()
		# Back on a list from Stats or Streak, where warming stood still.
		_queue_warm(0.3)
		if not home:
			_tab_tw = Motion.appear(_top_row(), 0.0, 1.0, ENTER_FADE)
			Analytics.track("tab_opened", {"tab": key})
		return
	_pager_seam.visible = false
	# A pager fade still queued from the entrance would bring the pill back
	# over the tab.
	Motion.stop(_pager_tw)
	_pager.visible = false
	var body: Control = {"streak": streak_tab, "stats": stats_tab}[key]
	body.refresh()
	_tab_tw = Motion.appear(body, 0.0, 1.0, ENTER_FADE)
	Analytics.track("tab_opened", {"tab": key})

## Parks the list that is up, its page, its neighbours and its fit, in
## `_kept` for its tab to take back.
func _keep_deck() -> void:
	_grab_slide()
	_hide_peek()
	_deck_page[_deck] = _page
	if _kept.has(_deck):
		_drop_kept(_deck)
	_park(_grid)
	_grid.name = "Kept_" + _deck
	_peek.name = "KeptPeek_" + _deck
	_kept[_deck] = {"grid": _grid, "cards": cards, "fillers": _fillers,
		"peek": _peek, "peek_cards": _peek_cards, "peek_fillers": _peek_fillers,
		"peek_page": _peek_page, "spare": _spare, "page": _page,
		"per": _per_page, "cols": _cols, "row_h": _row_h,
		"day": _built_day, "ids": _ids(_deck)}
	_grid = null
	_peek = null

## Stands `key`'s kept list up as the grid; false, with an empty grid up in
## its place, when there is none, or it was built on another day or before
## its list changed.
func _take_deck(key: String) -> bool:
	var b: Dictionary = _kept.get(key, {})
	_kept.erase(key)
	if b.is_empty() or int(b.day) != Daily.date_key() or b.ids != _ids(key):
		if not b.is_empty():
			_free_bundle(b)
		_grid = _new_grid("Grid")
		_peek = _new_grid("Peek")
		_peek.visible = false
		cards = []
		_fillers = []
		_peek_cards = []
		_peek_fillers = []
		_peek_page = -1
		_spare = {}
		return false
	_grid = b.grid
	_peek = b.peek
	cards = b.cards
	_fillers = b.fillers
	_peek_cards = b.peek_cards
	_peek_fillers = b.peek_fillers
	_peek_page = int(b.peek_page)
	_spare = b.spare
	_page = int(b.page)
	_per_page = int(b.per)
	_cols = int(b.cols)
	_row_h = float(b.row_h)
	_built_day = int(b.day)
	_grid.name = "Grid"
	_peek.name = "Peek"
	_peek_shown = false
	_drag_x = 0.0
	_grid.position.x = 0.0
	_refresh_cards()
	_queue_warm(0.3)
	return true

func _drop_kept(key: String) -> void:
	_free_bundle(_kept[key])
	_kept.erase(key)

func _free_bundle(b: Dictionary) -> void:
	_free_grid(b.grid)
	_free_grid(b.peek)
	for e: Dictionary in (b.spare as Dictionary).values():
		_free_grid(e.grid)

## What a kept card may have missed while it was out of sight: a board's
## done marks and rings, an Arcade game's best.
func _refresh_cards() -> void:
	var today: Array = Progress.solve_log().get(Daily.date_key(), [])
	var done_ids := Progress.completed_on()
	for card: PuzzleCard in cards + _peek_cards + _spare_cards():
		if not is_instance_valid(card):
			continue
		var id := String(card.entry.get("id", ""))
		if _deck == "home" or not Registry.arcade(id).is_empty():
			var lv: Array = Progress.levels_in(today, id)
			if lv != card.levels:
				card.set_levels(lv)
			var done: bool = done_ids.has(id) or not lv.is_empty()
			if done != card.completed:
				card.set_completed(done)
		elif _deck == "arcade":
			card.say(arcade_tab.line(id), arcade_tab.boosted(id))

## Asks for every card face's script on a thread, so no tab's first tap
## compiles them (~440 ms for the 58 on this Mac).
func _load_faces() -> void:
	for source: Array in [Registry.all(), VersusTab.entries(), ArcadeTab.entries()]:
		for e: Dictionary in source:
			var path := String(e.get("card", ""))
			if path.is_empty() or _faces_loading.has(path) or ResourceLoader.has_cached(path):
				continue
			if ResourceLoader.load_threaded_request(path) == OK:
				_faces_loading.append(path)
	set_process(true)

func _process(_delta: float) -> void:
	for path: String in _faces_loading.duplicate():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_faces.append(ResourceLoader.load_threaded_get(path))
			_faces_loading.erase(path)
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_faces_loading.erase(path)
	if not _baking.is_empty():
		_bake_step()
	if _faces_loading.is_empty() and _baking.is_empty():
		set_process(false)

## A card that names a board nobody has drawn flat yet.
func _on_soon(entry: Dictionary) -> void:
	_say(tr("MENU_NO_FLAT") % entry.get("title", ""))

## Android's back (`quit_on_go_back` is off, so it arrives through
## _notification): the topmost thing open goes first -- a sheet, then the
## first-play card, then the board -- then Stats or Streak go Home, and only
## Home quits.
func go_back() -> void:
	# The age question (ui/hud/age_screen.gd) has no way out but an answer.
	if get_node_or_null("../AgeScreen") != null:
		return
	var nodes := find_children("*", "", true, false)
	nodes.reverse()
	for node in nodes:
		# A Live.Stream answers is_open() too and is no card: closing one
		# would leave a game online deaf.
		if node is CanvasItem and node.has_method("is_open") and node.is_open():
			node.close()
			return
	var host: Node = null
	for child in get_children():
		if child.is_in_group("versus_host") and not child.is_queued_for_deletion():
			child.go_back()
			return
		if child is FlatHost and not child.is_queued_for_deletion():
			host = child
	if host != null:
		var card := host.get_node_or_null("HowToPlay")
		if card != null:
			card._continue()
			return
		host._on_back()
		return
	# Stats is reached from Streak, so it goes back there.
	if _tab == "stats":
		_show_tab("streak")
		return
	if _tab != "home":
		_show_tab("home")
		return
	get_tree().quit()

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

## A game on the Versus tab: its own screen over the list, and back to the
## Versus tab when it closes.
func _open_versus(game: String, level: int) -> void:
	var screen: Control
	match game:
		"snooker":
			screen = SnookerScreen.new(level)
			screen.name = "Snooker"
		"chess":
			screen = ChessScreen.new(level)
			screen.name = "Chess"
		"checkers":
			screen = CheckersScreen.new(level)
			screen.name = "Checkers"
		"hockey":
			screen = HockeyScreen.new(level)
			screen.name = "Hockey"
		"boats":
			screen = BoatsScreen.new(level)
			screen.name = "Boats"
		"penny":
			screen = PennyScreen.new(level)
			screen.name = "Penny"
		"dominoes":
			screen = DominoesScreen.new(level)
			screen.name = "Dominoes"
		"reversi":
			screen = ReversiScreen.new(level)
			screen.name = "Reversi"
		_:
			return
	screen.closed.connect(func() -> void:
		screen.queue_free()
		_left_game("versus"))
	add_child(screen)
	_raise_card()
	# Not over a game online (level 3): the lobby is up, and then a stranger's
	# clock is running. The screen opens it itself if the player takes the
	# computer instead.
	if screen.get("online") == null:
		screen.tutor.first_play()
	_list_root.visible = false

## A game on the Arcade tab: its own screen over the list, and back to the
## Arcade tab when it closes.
func _open_arcade(game: String) -> void:
	# A board on this tab (Marigold) opens as a board does: its levels, the
	# flat host, and back here when it closes.
	var board: Dictionary = Registry.arcade(game)
	if not board.is_empty():
		_open(board)
		return
	if game == "factory":
		_open_factory(game)
		return
	var screen: Control
	match game:
		"firefly":
			screen = FireflyScreen.new()
			screen.name = "Firefly"
		"molehill":
			screen = MolehillScreen.new()
			screen.name = "Molehill"
		"stackwood":
			screen = StackwoodScreen.new()
			screen.name = "Stackwood"
		"thirteen":
			screen = ThirteenScreen.new()
			screen.name = "Thirteen"
		"posy":
			screen = PosyScreen.new()
			screen.name = "Posy"
		"peapod":
			screen = PeapodScreen.new()
			screen.name = "Peapod"
		"nightlight":
			screen = NightlightScreen.new()
			screen.name = "Nightlight"
		"beeline":
			screen = BeelineScreen.new()
			screen.name = "Beeline"
		"deckchair":
			screen = DeckchairScreen.new()
			screen.name = "Deckchair"
		"eddy":
			screen = EddyScreen.new()
			screen.name = "Eddy"
		"furrow":
			screen = FurrowScreen.new()
			screen.name = "Furrow"
		"griddle":
			screen = GriddleScreen.new()
			screen.name = "Griddle"
		"trivet":
			screen = TrivetScreen.new()
			screen.name = "Trivet"
		"tally":
			screen = TallyScreen.new()
			screen.name = "Tally"
		"bagatelle":
			screen = BagatelleScreen.new()
			screen.name = "Bagatelle"
		_:
			return
	# Nightlight, Furrow, Griddle, Tally and Bagatelle are kept and have no run to finish: like the Factory's land
	# tab it is looked in on, so leaving it is not a moment for an
	# interstitial.
	screen.closed.connect(func() -> void:
		screen.queue_free()
		if game != "nightlight" and game != "furrow" and game != "griddle" and game != "tally" and game != "bagatelle":
			_left_game("arcade")
		elif not _switching:
			_show_list("arcade"))
	add_child(screen)
	_ask_start_over(screen, game)
	_raise_card()
	screen.tutor.first_play()
	_list_root.visible = false

## Every Arcade game can be put back to nothing from its settings sheet (the
## user, 2026-10-17: "all arcade games must have a button to reset all
## progress"). The sheet asks first (ui/hud/start_over_sheet.gd); on its yes
## the screen goes, keeping what it keeps as it leaves, then what it kept is
## wiped and the game opens again as on its first visit. Nightlight asks
## and starts its star over itself, as it did first (2026-10-06).
func _ask_start_over(screen: Control, game: String) -> void:
	if game == "nightlight":
		return
	var sheet: Control = screen.settings_sheet
	sheet.with_reset = true
	sheet.reset_asks = ArcadeTab.NAMES[game]
	sheet.start_over.connect(_start_over.bind(screen, game), CONNECT_DEFERRED | CONNECT_ONE_SHOT)

func _start_over(screen: Control, game: String) -> void:
	if not is_instance_valid(screen):
		return
	Analytics.track("arcade_reset", {"game": game})
	# freed here, not queued: its last save lands before the wipe below
	remove_child(screen)
	screen.free()
	ArcadeRecord.wipe(game)
	if game == "factory":
		factory_tab.returned()
		factory_tab.start_over()
		_open_factory(game)
		return
	var kept := ""
	match game:
		"furrow":
			kept = FurrowSim.path
		"griddle":
			kept = GriddleSim.path
		"tally":
			kept = TallySim.path
		"bagatelle":
			kept = BagatelleSim.path
	if not kept.is_empty() and FileAccess.file_exists(kept):
		DirAccess.remove_absolute(kept)
	_open_arcade(game)

## Factory, a card of the Arcade list (a tab of its own until 2026-10-13):
## its own screen over the list, and back to Arcade when it closes. The
## hidden tab still owns the land (one sim, so nothing is
## sold twice by two holders) and lends it for as long as the screen is up.
## A land is looked in on for a minute, so leaving it is not a moment for an
## interstitial, as leaving a board or an Arcade run is (`_left_game`).
func _open_factory(_game: String) -> void:
	var screen: Control = FactoryScreen.new()
	screen.name = "Factory"
	screen.setup(factory_tab.lend())
	screen.closed.connect(func() -> void:
		factory_tab.returned()
		screen.queue_free()
		if not _switching:
			_show_list("arcade"))
	add_child(screen)
	_ask_start_over(screen, "factory")
	_raise_card()
	screen.tutor.first_play()
	_list_root.visible = false

func _mount_host(host: Control) -> void:
	if host.has_signal("daily_completed"):
		host.daily_completed.connect(_on_daily_completed)
	# The win's invite to the next level: this board leaves and the same
	# card opens at that level, without a stop at the list in between.
	if host.has_signal("play_level"):
		host.play_level.connect(func(difficulty: int) -> void:
			host.queue_free()
			_open_at(host._entry, difficulty))
	# Back to the list its card stands in: the grid, or Arcade (Marigold).
	var deck: String = Registry.deck(host._entry)
	host.closed.connect(func() -> void:
		host.queue_free()
		_left_game(deck))
	add_child(host)
	_raise_card()
	_list_root.visible = false

## A board or a game has closed: back to the list on its tab, and the moment
## an interstitial may be shown. Neither while open_friend_game is closing it
## to open a friend's game in its place.
func _left_game(tab: String) -> void:
	if _switching:
		return
	_show_list(tab)
	Ads.leaving_game()

# --- friends ---

## Opens `game` (snooker, chess, checkers, boats, penny, dominoes, reversi) against the friend `uid`: asking
## them (`accept` false: the lobby waits on their answer) or taking the
## invite they sent (`accept` true). Whatever is open goes first -- a board,
## an Arcade or Versus screen, any sheet, a card -- with no interstitial in
## between, and the game closes back to the Versus tab. False if `game` is
## not one played online (air hockey has no game online), or a live game online
## is on (Social.in_game): that
## one is not walked out of for another.
func open_friend_game(game: String, uid: String, accept: bool) -> bool:
	if not VersusTab.plays_online(game) or uid.is_empty() or Social.in_game:
		return false
	_switching = true
	if is_instance_valid(friend_card):
		friend_card.leave()
	for node in find_children("*", "", true, false):
		if node is CanvasItem and node.has_method("is_open") and node.is_open():
			node.close()
	for child in get_children():
		if child.is_queued_for_deletion():
			continue
		if child.is_in_group("versus_host") or child is FlatHost:
			# Its own way out, so a game left half played is still counted as
			# abandoned; a screen that would ask first (a game online that is
			# not live any more) is simply closed.
			if child.get("online") != null:
				child.closed.emit()
			else:
				child._on_back()
			if not child.is_queued_for_deletion():
				child.queue_free()
	_switching = false
	Online.with_friend = {"uid": uid, "accept": accept}
	_open_versus(game, Record.ONLINE)
	return true

## A friend asks for a game: their card, over whatever is open. Social never
## says this during a live game online (it declines for the player). One card
## at a time: an invite that arrives under another waits its turn (_next_ask).
func _on_invited(from: String, game: String) -> void:
	if Social.in_game or get_node_or_null("../AgeScreen") != null:
		return
	if is_instance_valid(friend_card) and friend_card.is_open():
		# A new friend's card gives way to someone asking for a game.
		if friend_card.kind == InviteCard.Kind.INVITE:
			return
		friend_card.leave()
	var card := InviteCard.invite(from, game)
	card.play.connect(func(g: String) -> void:
		Analytics.track("versus_friend_answer", {"game": g, "choice": "play"})
		if not open_friend_game(g, from, true):
			Social.decline(from))
	card.dismissed.connect(func() -> void:
		Analytics.track("versus_friend_answer", {"game": game, "choice": "not_now"})
		Social.decline(from)
		_next_ask.call_deferred(from))
	_show_card(card)
	Haptics.play(Haptics.GOOD)

## The invite went before it was answered: its card goes with it.
func _on_withdrawn(from: String) -> void:
	if is_instance_valid(friend_card) and friend_card.is_open() \
			and friend_card.kind == InviteCard.Kind.INVITE and friend_card.uid == from:
		Analytics.track("versus_friend_answer", {"game": friend_card.game, "choice": "expired"})
		friend_card.leave()
		_next_ask.call_deferred(from)

## Another friend may have been asking under the card that just went.
func _next_ask(not_from: String) -> void:
	for uid in Social.friends():
		if uid == not_from:
			continue
		var game := Social.invite_from(uid)
		if not game.is_empty():
			_on_invited(uid, game)
			return

## Someone opened this player's link, or this player theirs: the new friend's
## card, with Play (which asks which game) and Close. Not over the code
## dialog, which says who was added itself; not over an invite.
func _on_befriended(uid: String) -> void:
	if friends_sheet.adding() or get_node_or_null("../AgeScreen") != null:
		return
	if is_instance_valid(friend_card) and friend_card.is_open():
		return
	var card := InviteCard.friend(uid)
	# No Play while a live game online is on: it would mean walking out of it.
	card.can_play = not Social.in_game
	# versus_friend_invite is Online's, sent as the asking begins.
	card.play.connect(func(game: String) -> void: open_friend_game(game, uid, false))
	_show_card(card)
	Haptics.play(Haptics.GOOD)

## An invite link that made no friend (world/main.gd, from Social.add's
## answer): `why` is "self", "unknown" or "offline". One line over whatever
## is open, gone by itself; a link that worked needs no word, the new
## friend's card is it.
func friend_link_failed(why: String) -> void:
	var key: String = {"self": "FRIENDS_ADD_SELF", "unknown": "FRIENDS_ADD_UNKNOWN"}.get(why, "FRIENDS_ADD_OFFLINE")
	var old := get_node_or_null("FriendWord")
	if old != null:
		old.name = "FriendWordOld"
		old.queue_free()
	var word := CenterContainer.new()
	word.name = "FriendWord"
	word.z_index = CARD_Z
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	word.offset_left = MARGIN
	word.offset_right = -MARGIN
	word.offset_bottom = -TOAST_OVER - SafeArea.insets(self).y
	word.offset_top = word.offset_bottom - WORD_H
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := CozyTheme.lifted(Pal.SURFACE, 30, 22)
	paper.content_margin_left = 36
	paper.content_margin_right = 36
	pill.add_theme_stylebox_override("panel", paper)
	word.add_child(pill)
	var line := Label.new()
	line.text = key
	line.theme_type_variation = "CardBody"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = WORD_W
	pill.add_child(line)
	add_child(word)
	Haptics.play(Haptics.WARN)
	Motion.appear(word, 0.0, 1.0, TOAST_FADE)
	get_tree().create_timer(WORD_TIME).timeout.connect(func() -> void:
		if not is_instance_valid(word):
			return
		var tw := Motion.appear(word, word.modulate.a, 0.0, TOAST_FADE)
		if tw == null:
			word.queue_free()
		else:
			tw.finished.connect(word.queue_free))

func _show_card(card: Control) -> void:
	friend_card = card
	# Over a sheet and over a card of the sheet's own (each a z step up).
	card.z_index = CARD_Z
	add_child(card)

## The card stays over a host mounted after it: a later sibling takes the
## taps, whatever z_index draws.
func _raise_card() -> void:
	if is_instance_valid(friend_card) and friend_card.get_parent() == self:
		move_child(friend_card, -1)
	var word := get_node_or_null("FriendWord")
	if word != null:
		move_child(word, -1)

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
