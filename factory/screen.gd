extends Control

## Factory: the robot floor, played. Ten square tiles by eight seen from
## above, drawn with the land's pieces (one plate on the pond, the land's
## belts, market, engine and tray: the user, 2026-10-21, twice), three
## robots that walk their programs
## over it from the bay, the stations they work (the intake, the box stack,
## the pack table, the deliver pad that sells), and from milestone 1 the
## belts a finger traces. Spec
## docs/superpowers/specs/2026-10-20-factory-rewired-design.md (its section
## 3 amended 2026-10-21); the rules and every number are factory/sim.gd's and
## factory/bots.gd's, the drawings factory/art.gd's, and what is seen of the
## floor factory/life.gd's. The view has no turn (a turn has no purpose on
## a square floor): a Move's arrow on the sheet is the way the robot walks
## on screen.
##
## **It never makes or reads a floor.** ui/menu/factory_tab.gd owns the one
## sim; whoever mounts this screen hands it over with `setup(sim)` before it
## enters the tree (a harness makes its own). While it is mounted it is the
## one stepping the floor and draining its events, and it keeps it: every
## two seconds while something changed, at once when the app is paused or
## closed, and as it leaves.
##
## Like a Versus or Arcade screen it is its own host: it joins the
## `versus_host` group so Android's back reaches it (the tutorial, the
## settings, the pill, the drawer, a picked belt, then the screen). It has no
## round, no score and no end.
##
## The chrome lies over the floor: the top bar, the coins and the pace (a
## box every so many seconds, from the sim's rolling window) on two pills
## with the zoom beside them, and a row of **robot chips**, one a robot in
## the floor's own tints, a red dot on the chip of a robot with a fault the
## player can see from its program (a loose wire, a node its parts do not
## give, stuck). A tap on a chip or on a robot on the floor picks it and
## opens its sheet.
##
## The hand. Every finger is a ScreenTouch or a ScreenDrag, the desktop
## mouse read beside them. A press that moves under TAP pixels is a tap: on
## a chip or a robot it picks the robot; on a belt it opens the belt's
## **pill** (Turn, Flip, Sell, Section, Line: the pill of Tally's paper,
## ui/hud/piece_pill.gd). A drag pans, unless a belt is picked in the
## drawer: then the finger **traces a path** as Tally's belt tool does (the
## user, 2026-10-20: "helpers to create convey based on the tally convey"),
## shown with the way it will flow and laid as the finger lifts, each belt
## facing the next; with **Straight** on (the chip over the drawer) the path
## is a line with at most one bend, the L. A bridge goes one at a time. A
## finger held still for HOLD on a belt sells it back. The drawer has
## nothing in it until milestone 1, and its button is not shown till then.

signal closed

const Art = preload("res://factory/art.gd")
const Sim = preload("res://factory/sim.gd")
const Bots = preload("res://factory/bots.gd")
const Life = preload("res://factory/life.gd")
const Tile = preload("res://factory/tile.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const ScreenTutor = preload("res://ui/hud/screen_tutor.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Analytics = preload("res://core/analytics.gd")
const PiecePill = preload("res://ui/hud/piece_pill.gd")
const Sheet = preload("res://factory/sheet.gd")

const GAME := "factory"
const MARGIN := 40
const PILL_H := 84.0
const ZOOM_B := 96.0
## The robot chips under the pills: a chip's height and width, the air
## between two, and the red dot of a fault on a chip's corner.
const CHIP_H := 84.0
const CHIP_W := 236.0
const CHIP_GAP := 16.0
const DOT_R := 12.0
## The drawer: its round button on the left edge, this far up from the foot
## of the screen (the right thumb works the lower right), and its tiles.
const DRAWER_B := 128.0
## The debug build's "everything built is free" button, beside the drawer's.
const FREE_B := 96.0
const DRAWER_UP := 250.0
const DRAWER_W := 196.0
const DRAWER_TILE := 206.0
const DRAWER_TILES := ["belt", "fast", "bridge"]
## The drawer stands this many tiles tall before it takes another column.
const DRAWER_ROWS := 5
const NAMES := {"belt": "FACTORY_BELT", "fast": "FACTORY_FAST", "bridge": "FACTORY_BRIDGE"}
## A press that moves less than this is a tap, in the screen's own units; a
## robot is tapped within twice it of where it is drawn.
const TAP := 24.0
## The middle of a robot's body over its feet (view units), where a tap on
## it is measured from.
const ROBOT_MID := Vector2(0.0, -40.0)
## A finger held still this long on a belt sells it back; its ring starts to
## close after HOLD_SHOWS, so a plain tap shows none.
const HOLD := 0.5
const HOLD_SHOWS := 0.12
## Where the floor's middle sits down the screen: under the bar, the pills
## and the chips.
const CENTRE := Vector2(0.5, 0.55)
## The view's middle goes this many tiles past the floor's own and no
## further, and a drag past that gives this much of what the finger asks.
const POND := 2.0
const SOFT := 0.35
## How fast the view catches up with where it is going, and how much of a
## flick's speed carries on after the finger lifts (seconds of it).
const CAM_EASE := 9.0
const FLING := 0.16
## Two fingers this much further apart, or nearer, change the zoom.
const PINCH := 1.18
const NUM := 0.9
const SAVE_GAP := 2.0
const MOUSE := -2
const NO_FINGER := -99
## A refusal that is not a no: the tap simply did nothing.
const QUIET := ["nothing", "same", "station", "edge", "off"]
const TICK_VARY := 0.06
## A sale's coin: the factory's own `coin` (assets/sfx/factory/) at its own
## pitch and level, and the milliseconds between two of them at least.
const COIN_PITCH := 1.0
const COIN_DB := 0.0
const COIN_GAP := 140
## Seconds a milestone's name stays on the pace pill once it opens.
const NAMED := 4.0
## The player's own hand is felt (docs/agents/haptics.md): a node set down,
## a wire landed, a part fitted, a refusal; a sale's coin and a milestone are
## played by hand (`buzz`), since neither rings under its own name here. The
## robots' hands are heard and never felt.
const HAPTICS := {"node": Haptics.TAP, "wire": Haptics.TICK, "fit": Haptics.BUMP, "coin": Haptics.GOOD, "no": Haptics.WARN, "milestone": Haptics.GOOD}
## The belt pill's buttons and captions; Tally's words where they are the same.
const PILL_PLAIN := ["turn", "flip", "sell", "run", "line"]
const PILL_ONE := ["turn", "sell"]
const PILL_CAP := {"turn": "TL_TURN", "flip": "TL_FLIP", "sell": "FACTORY_PILL_SELL", "run": "TL_ERASE_RUN", "line": "TL_ERASE_LINE"}
## The Straight chip over the drawer's button.
const LINE_W := 210.0
const LINE_H := 84.0
## A finger this near the field's edge while tracing a path moves the view,
## this many pixels a second.
const EDGE := 70.0
const EDGE_SPEED := 620.0

var sim: RefCounted
var top_bar: Control
var settings_sheet: Control
var tutor: RefCounted
var field: Control
var life: RefCounted
var world: Node2D
## The program sheet (factory/sheet.gd), over the field's lower part.
var sheet: Control
## The robot the chips mark: the one tapped last.
var selected := 0

var _fx: Node2D
var _quiet: Node2D
## The floor's own voice, felt by no one: the robots' hands, a charge, a
## fault, the sale's coin.
var _floor_fx: Node2D
## Robots whose chain was open or held a node they cannot do, and those
## whose fix has been told this visit (`factory_fix`, once a robot).
var _broken := {}
var _fix_told := {}
var _coin_at := -1000
var _margins: MarginContainer
var _water: ArrayMesh
var _light: ArrayMesh
var _light_l: Control
var _over_l: Node2D
var _pill: PanelContainer
var _coins_l: Label
var _pace_l: Label
var _next_l: Label
var _chips_l: Control
var _chips_key := ""
var _zoom_b: Button
var _drawer_b: Button
var _free_b: Button
var _drawer: GridContainer
var _drawer_catch: Control
var _tiles := {}        # drawer tile -> Tile
var _hud_key := ""
var _shown := 0.0
var _warn := 0.0
var _named := 0.0       # seconds left of a milestone's name on the pace pill
var _named_text := ""
var _bump: Tween
var _nums: Array = []   # {at, text, t}: view units
var _rng := RandomNumberGenerator.new()

# the view
var _cam := Vector2.ZERO
var _cam_to := Vector2.ZERO
var _cam_raw := Vector2.ZERO
var _vel := Vector2.ZERO
var _zoom := 1.0
var _near := 1.0
var _far := false
var _laid_out := false

# the hand
var _touches := {}      # finger -> where it is
var _finger := NO_FINGER
var _mode := ""         # "pan", "belt", "chip", "pinch", "pill", "done"
var _start := Vector2.ZERO
var _at := Vector2.ZERO
var _moved := false
var _moved_at := 0
var _held := 0.0
var _long := {}         # what a held finger would sell: {tile}
var _chip_down := -1    # the chip a press landed on
## The tile a swipe with Belt picked began on, and the run it would lay now:
## {tiles, lay (how many of them the coins reach, from the start), facing}.
var _belt_tile := Vector2i.ZERO
var _run := {}
var _facing := 0
var _pinch := 0.0
var _held_back := false
## The path a finger traces with a belt picked: tiles in the order drawn,
## the axis Straight holds it to (-1 till the finger leaves the first tile)
## and the way its last step went.
var _path: Array = []
var _axis := -1
var _trace_f := 0
## The belt pill: {tile, buttons, at} while it is up; the button a press
## landed on; whether the press was the pill's.
var _piece := {}
var _piece_hit := ""
var _consumed := false
var _btn_at := {}
var _clock := 0.0
var _pill_ui: PiecePill
var _pill_l: Control
var _line_b: Button
var _line_at := -10.0
## Straight lines for the path, on from the start (Tally's default, the
## user, 2026-10-15); kept while the app runs.
static var straight := true

var _left := false
var _since_save := 0.0
var _opened_at := 0
var _earned_at_open := 0

## The floor this screen plays, handed over before it enters the tree.
func setup(with_sim: RefCounted) -> void:
	sim = with_sim

func puzzle_id() -> String:
	return GAME

func _ready() -> void:
	add_to_group("versus_host")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	if sim == null:
		push_error("factory/screen.gd: setup(sim) was not called; the screen makes no floor of its own")
		set_process(false)
		return
	sim.picked = ""
	sim.events.clear()
	_opened_at = Time.get_ticks_msec()
	_earned_at_open = sim.earned
	_shown = float(sim.coins)
	_build()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	tutor = ScreenTutor.new(self, GAME, "Factory", _tutor_hold)
	tutor.wire(top_bar, settings_sheet)
	# the banner moves the safe area; asked for by path so the script parses
	# where no autoload is (a check, a bare harness)
	var ads := get_node_or_null("/root/Ads")
	if ads != null:
		ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	top_bar.refresh(self)
	_refresh_hud(0.0)
	for i in sim.robots.size():
		if not chain_whole(i):
			_broken[i] = true
	Analytics.track("factory_enter", {"milestone": sim.milestone, "coins": sim.coins})

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_let_go()
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		_save()

# --- building ---

func _build() -> void:
	field = Control.new()
	field.name = "Field"
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.clip_contents = true
	field.draw.connect(func() -> void:
		if _water != null:
			field.draw_mesh(_water, null))
	field.gui_input.connect(_on_field_input)
	add_child(field)
	life = Life.new()
	world = life.mount(field, sim)
	_over_l = life.layer(_draw_over)
	field.resized.connect(_layout_field)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	_fx._puzzle = GAME
	field.add_child(_fx)
	# a belt laid, turned or flipped is still the Grove's chop, heard and
	# never felt (docs/agents/sound.md: board foley stays till the user asks)
	_quiet = Fx2D.new()
	_quiet.buzzes = false
	_quiet._puzzle = "grove"
	field.add_child(_quiet)
	_floor_fx = Fx2D.new()
	_floor_fx.buzzes = false
	_floor_fx._puzzle = GAME
	field.add_child(_floor_fx)
	_pill_ui = PiecePill.new(PILL_CAP)
	_pill_l = Control.new()
	_pill_l.name = "Pill"
	_pill_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pill_l.draw.connect(_draw_piece)
	field.add_child(_pill_l)
	_light_l = Control.new()
	_light_l.name = "Light"
	_light_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_light_l.draw.connect(func() -> void:
		if _light != null:
			_light_l.draw_mesh(_light, null))
	add_child(_light_l)

	_margins = MarginContainer.new()
	_margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margins)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 14)
	_margins.add_child(col)
	top_bar = FlatTopBar.new("Factory", tr("FACTORY_MOTTO"), false)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.settings.connect(func() -> void:
		_let_go()
		settings_sheet.open())
	col.add_child(top_bar)
	# the coins, the pace and the zoom, side by side, each its own size
	var pills := HBoxContainer.new()
	pills.name = "Pills"
	pills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pills.alignment = BoxContainer.ALIGNMENT_CENTER
	pills.add_theme_constant_override("separation", 18)
	col.add_child(pills)
	pills.add_child(_coin_pill())
	pills.add_child(_pace_pill())
	_zoom_b = IconButton.new("minus", "", "IconButton")
	_zoom_b.name = "Zoom"
	_zoom_b.pressed.connect(func() -> void: set_far(not _far))
	for b: Button in [_zoom_b]:
		b.custom_minimum_size = Vector2(ZOOM_B, ZOOM_B)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_round(b, int(ZOOM_B * 0.5))
		pills.add_child(b)

	# the robot chips: drawn, not buttons, so a finger on one reaches the
	# field and is read there with every other (`_press`, `robot_chip_rect`)
	_chips_l = Control.new()
	_chips_l.name = "Chips"
	_chips_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips_l.custom_minimum_size.y = CHIP_H
	_chips_l.draw.connect(_draw_chips)
	col.add_child(_chips_l)

	_drawer_catch = Control.new()
	_drawer_catch.name = "DrawerCatch"
	_drawer_catch.visible = false
	_drawer_catch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawer_catch.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
			close_drawer()
			_fx.touch(0.84))
	add_child(_drawer_catch)
	_drawer = GridContainer.new()
	_drawer.name = "Drawer"
	_drawer.visible = false
	_drawer.add_theme_constant_override("h_separation", 10)
	_drawer.add_theme_constant_override("v_separation", 10)
	_drawer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_drawer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_drawer)
	for kind: String in DRAWER_TILES:
		var t := Tile.make(kind, NAMES[kind], DRAWER_TILE, 44.0, 50.0)
		(t.button as Button).custom_minimum_size.x = DRAWER_W
		(t.button as Button).pressed.connect(_on_drawer_tile.bind(kind))
		_drawer.add_child(t.button)
		_tiles[kind] = t
	_drawer_b = Button.new()
	_drawer_b.name = "DrawerButton"
	_drawer_b.focus_mode = Control.FOCUS_NONE
	_drawer_b.custom_minimum_size = Vector2(DRAWER_B, DRAWER_B)
	_drawer_b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	CozyTheme.lift_button(_drawer_b, Tile.FILL, int(DRAWER_B * 0.5), 0)
	_drawer_b.draw.connect(_draw_drawer_button)
	_drawer_b.pressed.connect(_on_drawer_button)
	add_child(_drawer_b)
	_line_b = Button.new()
	_line_b.name = "Straight"
	_line_b.focus_mode = Control.FOCUS_NONE
	_line_b.flat = true
	_line_b.visible = false
	_line_b.custom_minimum_size = Vector2(LINE_W, LINE_H)
	_line_b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_line_b.draw.connect(_draw_line_chip)
	_line_b.pressed.connect(toggle_straight)
	add_child(_line_b)
	if OS.is_debug_build():
		# never in a release: the phone's test builds are debug exports
		_free_b = Button.new()
		_free_b.name = "FreeButton"
		_free_b.focus_mode = Control.FOCUS_NONE
		_free_b.custom_minimum_size = Vector2(FREE_B, FREE_B)
		_free_b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		CozyTheme.lift_button(_free_b, Tile.FILL, int(FREE_B * 0.5), 0)
		_free_b.draw.connect(_draw_free_button)
		_free_b.pressed.connect(_on_free_button)
		add_child(_free_b)
	# over the drawer and its buttons, under the settings and the tutor
	sheet = Sheet.new()
	sheet.name = "Sheet"
	sheet.setup(sim, _fx)
	sheet.closed.connect(func() -> void:
		# the view may have gone down under the sheet: back inside the floor's
		_cam_raw = _clamp(_cam_to)
		_cam_to = _cam_raw
		_chips_l.queue_redraw())
	add_child(sheet)
	_apply_insets()
	_layout_field()

## The coins held: the coin and the count on a white pill.
func _coin_pill() -> Control:
	_pill = PanelContainer.new()
	_pill.name = "Coins"
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.custom_minimum_size = Vector2(190, PILL_H)
	_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pill.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, int(PILL_H * 0.5), 8))
	_pill.resized.connect(func() -> void: _pill.pivot_offset = _pill.size * 0.5)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_pill.add_child(row)
	var lead := Control.new()
	lead.custom_minimum_size.x = 6
	row.add_child(lead)
	row.add_child(Tile.coin(58.0))
	_coins_l = Label.new()
	_coins_l.name = "Value"
	_coins_l.theme_type_variation = "SheetTitle"
	_coins_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_coins_l)
	var tail := Control.new()
	tail.custom_minimum_size.x = 18
	row.add_child(tail)
	return _pill

## The pace: a full box and how often one is sold, from the sim's rolling
## window ("a box every 37 s"), on a white pill beside the coins; under it,
## small, what the next milestone asks, or the name of one just opened.
func _pace_pill() -> Control:
	var pill := PanelContainer.new()
	pill.name = "Pace"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.custom_minimum_size = Vector2(0, PILL_H)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, int(PILL_H * 0.5), 8))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	pill.add_child(row)
	var lead := Control.new()
	lead.custom_minimum_size.x = 6
	row.add_child(lead)
	var box := Control.new()
	box.custom_minimum_size = Vector2(54.0, 54.0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(func() -> void:
		box.draw_mesh(Art.icon("box"), null, Transform2D(0.0, Vector2(0.56, 0.56), 0.0, box.size * 0.5)))
	row.add_child(box)
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", -6)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lines)
	_pace_l = Label.new()
	_pace_l.name = "Value"
	_pace_l.theme_type_variation = "SheetBody"
	_pace_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lines.add_child(_pace_l)
	_next_l = Label.new()
	_next_l.name = "Next"
	_next_l.theme_type_variation = "SheetBodyDim"
	_next_l.add_theme_font_size_override("font_size", 24)
	_next_l.visible = false
	lines.add_child(_next_l)
	var tail := Control.new()
	tail.custom_minimum_size.x = 18
	row.add_child(tail)
	return pill

## What the pace pill says: a full box every so many seconds, or that none
## has been sold often enough to say (the sim reads nothing under two).
func pace_text() -> String:
	return Art.pace_text(sim)

## The pace pill's second line: a milestone's name for NAMED seconds after it
## opens, else what the next one asks, "" past what this build fills.
func next_text() -> String:
	return _named_text if _named > 0.0 else Art.next_text(sim)

## A white round face for a button that keeps its own size.
static func _round(b: Button, r: int) -> void:
	var up := CozyTheme.soft_button(Pal.SURFACE, r, false, 0)
	var down := CozyTheme.soft_button(Pal.SURFACE, r, true, 0)
	for st in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(st, up)
	b.add_theme_stylebox_override("pressed", down)

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	var foot := DRAWER_UP + insets.y
	_drawer_b.offset_left = 28.0
	_drawer_b.offset_right = 28.0 + DRAWER_B
	_drawer_b.offset_bottom = -foot
	_drawer_b.offset_top = -foot - DRAWER_B
	if _free_b != null:
		_free_b.offset_left = 28.0 + DRAWER_B + 16.0
		_free_b.offset_right = _free_b.offset_left + FREE_B
		_free_b.offset_bottom = -foot - (DRAWER_B - FREE_B) * 0.5
		_free_b.offset_top = _free_b.offset_bottom - FREE_B
	_line_b.offset_left = 28.0
	_line_b.offset_right = 28.0 + LINE_W
	_line_b.offset_bottom = -foot - DRAWER_B - 16.0
	_line_b.offset_top = _line_b.offset_bottom - LINE_H
	_drawer.offset_left = 28.0
	_drawer.offset_right = 28.0 + DRAWER_W
	_drawer.offset_bottom = -foot - DRAWER_B - 16.0
	_drawer.offset_top = _drawer.offset_bottom
	if field != null and field.size.y > 0.0:
		sheet.fit_to(field.size, insets.y)

## The pond and the light are baked for the field's size, and the near zoom
## is the one at which the whole floor is as wide as the field.
func _layout_field() -> void:
	var s := field.size
	if s.x <= 0.0 or s.y <= 0.0 or _light_l == null:
		return
	_water = Art.water(s, 0.0)
	_light = Art.light(s)
	_near = s.x / (life.bounds() as Rect2).size.x
	if sheet != null:
		sheet.fit_to(s, SafeArea.insets(self).y)
	if not _laid_out:
		_laid_out = true
		_zoom = _near
		# the floor's middle, the whole of it in view
		_cam = life.seen(Vector2(Sim.COLS * 0.5, Sim.ROWS * 0.5))
		_cam_to = _cam
		_cam_raw = _cam
	_place_world()
	field.queue_redraw()
	_light_l.queue_redraw()

# --- the view ---

func _place_world() -> void:
	world.scale = Vector2(_zoom, _zoom)
	world.position = field.size * CENTRE - _cam * _zoom

## A point of the view (view units), in the field's own pixels.
func to_field(v: Vector2) -> Vector2:
	return world.position + v * _zoom

## A point of tile space (a tile's middle is tile + (0.5, 0.5)) in the
## field's pixels, for the hand and for a harness that presses.
func screen_of(t: Vector2) -> Vector2:
	return to_field(life.seen(t))

## The point of tile space under a point of the field.
func tile_under(pos: Vector2) -> Vector2:
	return life.tile_at((pos - world.position) / _zoom)

## A point of the view held to where the view's middle may go: the floor's
## own tiles and POND tiles of pond past them.
func _clamp(v: Vector2) -> Vector2:
	var inside := _clamp_tiles(v)
	if sheet != null and sheet.is_open() and v.y > inside.y:
		# the sheet hides the lower part of the field: the view may go as
		# far down as it covers, so a robot on the front row can stand above it
		var down := minf(v.y - inside.y, sheet.size.y / _zoom)
		return _clamp_tiles(v - Vector2(0.0, down)) + Vector2(0.0, down)
	return inside

func _clamp_tiles(v: Vector2) -> Vector2:
	var box: Rect2 = (life.tile_bounds() as Rect2).grow(POND)
	return life.seen((life.tile_at(v) as Vector2).clamp(box.position, box.end))

## The far zoom shows twice as much; the near one the floor across the field.
func set_far(on: bool) -> void:
	_far = on
	(_zoom_b as IconButton).set_icon("plus" if on else "minus")

## A pinch or the wheel: the zoom has no button's click under it, so it ticks
## when it changes.
func _zoom_by_hand(on: bool) -> void:
	if on == _far:
		return
	set_far(on)
	_fx.touch(1.0 if on else 0.84)

func _step_view(delta: float) -> void:
	var want := _near * (0.5 if _far else 1.0)
	var panning := _mode == "pan" and _moved
	if Motion.reduce:
		_zoom = want
		_cam = _cam_to
	else:
		var k := 1.0 - exp(-CAM_EASE * delta)
		_zoom = lerpf(_zoom, want, k)
		if absf(_zoom - want) < 0.0005:
			_zoom = want
		if not panning:
			_cam = _cam.lerp(_cam_to, k)
	_place_world()

# --- what the top bar and the tutorial ask ---

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/factory_tutorial_diagram.gd")
	var pages := []
	for lesson: int in [Diagram.Lesson.POWER, Diagram.Lesson.PICKER, Diagram.Lesson.BOXER,
			Diagram.Lesson.SHIPPER, Diagram.Lesson.BOX, Diagram.Lesson.SPEND]:
		var d: Control = Diagram.new()
		d.lesson = lesson
		pages.append({"diagram": d, "title": "TUT_FACTORY_%d" % (lesson + 1), "body": tr("TUT_FACTORY_%d_BODY" % (lesson + 1))})
	return pages

func capabilities() -> Array:
	return []

func is_done() -> bool:
	return false

func is_solved() -> bool:
	return false

func can_undo() -> bool:
	return false

func hints_left() -> int:
	return 0

## A card over the screen (the tutorial): the finger is let go.
func _tutor_hold(on: bool) -> void:
	_held_back = on
	if on:
		_let_go()
		sheet.let_go()

# --- time ---

func _process(delta: float) -> void:
	if sim == null or _left:
		return
	_clock += delta
	sim.step(delta)
	_play_events()
	_step_hand(delta)
	_edge_pan(delta)
	if sheet.is_open():
		_keep_in_view(false)
	_step_view(delta)
	if not _piece.is_empty() and not sim.belts.has(_piece.tile):
		_close_piece()
	life.ghosts = _ghosts()
	life.step(delta)
	for n: Dictionary in _nums:
		n.t += delta
	_nums = _nums.filter(func(n: Dictionary) -> bool: return n.t < NUM)
	_warn = maxf(0.0, _warn - delta)
	_named = maxf(0.0, _named - delta)
	_refresh_hud(delta)
	_since_save += delta
	if sim.dirty and _since_save >= SAVE_GAP:
		_save()
	_over_l.queue_redraw()
	_pill_l.queue_redraw()

## The sim's events, to the life and to the ear. The robots' hands, a charge
## and a fault are the floor's voice (felt by no one: they are not the
## player's), a sale is the coin, a milestone the two notes and a knock.
func _play_events() -> void:
	for e: Dictionary in sim.events:
		life.event(e)
		sheet.event(e)
		match String(e.type):
			"laid":
				_quiet.cue("chop", 0.84 * _vary(), -6.0)
			"turned", "flipped":
				_quiet.cue("chop", 1.12 * _vary(), -6.0)
			"sold_back", "sold_line":
				_fx.cue("buy", 0.9)
			"milestone":
				# what it opens is in the drawer now
				_fx.cue("buy", 1.12)
				_fx.buzz(HAPTICS.milestone)
				_hud_key = ""
				Motion.bump(_drawer_b, 0.12, 0.3)
				_named = NAMED
				_named_text = Art.milestone_name(String(e.id))
				Analytics.track("factory_milestone", {"id": String(e.id)})
			"pick", "release":
				if String(e.kind) != "":
					_floor_fx.cue(String(e.type), _vary())
				if String(e.type) == "release" and String(e.kind) == "box" and e.tile == Sim.STATIONS.table:
					_tell_fix(int(e.robot))
			"charging":
				_floor_fx.cue("charge", _vary())
			"stuck", "flat":
				_floor_fx.cue("no", 0.94 * _vary())
			"edited":
				_check_fix(int(e.robot))
			"sale":
				_on_coin(int(e.amount), e.tile)
			"refused":
				_on_refused(String(e.why))
	sim.events.clear()

## A sale on the deliver pad: a coin is heard, the jar coin the user picked
## by ear on 2026-10-15 (docs/agents/sound.md), and felt, never two inside
## COIN_GAP, and the count is on its way up over the pad.
func _on_coin(amount: int, tile: Vector2i) -> void:
	if amount <= 0:
		return
	var now := Time.get_ticks_msec()
	if now - _coin_at >= COIN_GAP:
		_coin_at = now
		_floor_fx.cue("coin", COIN_PITCH * _vary(), COIN_DB)
		_fx.buzz(HAPTICS.coin)
	var hatch: Vector2 = life.mid(tile) + Life.STATION_BACK + Art.MARKET_TOP
	_nums.append({"at": hatch + Vector2(_rng.randf_range(40.0, 52.0), -30.0), "text": "+" + Art.short(amount), "t": 0.0})
	_kick()

## The sim did not do it. Most of the time that is a no, and when it was the
## coins the pill shakes its head.
func _on_refused(why: String) -> void:
	if QUIET.has(why):
		return
	_fx.cue("no")
	if why == "coins":
		_warn = 0.7
		Motion.shiver(_pill, 7.0)

func _vary() -> float:
	return _rng.randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY)

## The pill swells as a sale lands. Each kick ends the last, or two a moment
## apart would leave it stuck big (ui/menu/gold_pill.gd).
func _kick() -> void:
	Motion.stop(_bump)
	_pill.scale = Vector2.ONE
	_bump = Motion.bump(_pill, 0.08, 0.2)

func _refresh_hud(delta: float) -> void:
	var held := float(sim.coins)
	if Motion.reduce or delta <= 0.0 or absf(held - _shown) < 0.6:
		_shown = held
	else:
		_shown = lerpf(_shown, held, minf(1.0, delta * 10.0))
	var text := Art.short(int(round(_shown)))
	if _coins_l.text != text:
		_coins_l.text = text
	_coins_l.add_theme_color_override("font_color", Pal.BAD if _warn > 0.0 else Pal.TEXT)
	var pace := pace_text()
	if _pace_l.text != pace:
		_pace_l.text = pace
	var next := next_text()
	if _next_l.text != next:
		_next_l.text = next
		_next_l.visible = next != ""
	var key := "%d|%d|%s|%d|%s" % [sim.coins, sim.milestone, sim.picked, sim.earned, sim.no_cost]
	if key != _hud_key:
		_hud_key = key
		_refresh_drawer()
	var chips := _chips_state()
	if chips != _chips_key:
		_chips_key = chips
		_chips_l.queue_redraw()

# --- the robot chips ---

## Where robot `i`'s chip is, in the field's pixels (`Rect2()` for no such
## robot): the chips stand in a row under the pills, in the middle.
func robot_chip_rect(i: int) -> Rect2:
	if _chips_l == null or i < 0 or i >= sim.robots.size():
		return Rect2()
	var off := _chips_l.get_global_rect().position - field.get_global_rect().position
	return Rect2(off + _chip_at(i).position, _chip_at(i).size)

## Chip `i` in the chips' own row.
func _chip_at(i: int) -> Rect2:
	var n: int = sim.robots.size()
	var whole := n * CHIP_W + (n - 1) * CHIP_GAP
	var x0 := (_chips_l.size.x - whole) * 0.5
	return Rect2(Vector2(x0 + i * (CHIP_W + CHIP_GAP), 0.0), Vector2(CHIP_W, CHIP_H))

## The chip under a point of the field, -1 for none.
func _chip_under(pos: Vector2) -> int:
	for i in sim.robots.size():
		if robot_chip_rect(i).has_point(pos):
			return i
	return -1

## Whether robot `i` has a fault the player can see from its program: its
## chain does not come back to the body (a loose wire), it runs a node no
## part of it gives, or it is stuck. A fault of the floor (a Move a tile
## short) is not one: nothing but watching it says so.
func robot_fault(i: int) -> bool:
	return String(sim.robots[i].stuck) != "" or not chain_whole(i)

## Whether robot `i`'s chain closes back on its body with every node on it
## one its parts can do.
func chain_whole(i: int) -> bool:
	var b: Dictionary = sim.robots[i]
	var w: Dictionary = Bots.walk(b)
	if not w.closed:
		return false
	for id: String in w.ids:
		if not Bots.can(b, String(b.nodes[id].kind)):
			return false
	return true

## After an edit of robot `i`: a chain that was open, or held a node its
## parts cannot do (at the visit's start or after an edit of the player's
## own), and is whole now is a fix. That catches the Picker's (no gripper)
## and the Shipper's (a loose wire); the Boxer's Move one short keeps its
## chain whole, so its fix is told by the first box a robot sets down on the
## table instead (`_play_events`), which on a floor already working is the
## visit's first box there.
func _check_fix(i: int) -> void:
	if i < 0 or i >= sim.robots.size():
		return
	if not chain_whole(i):
		_broken[i] = true
	elif _broken.has(i):
		_broken.erase(i)
		_tell_fix(i)

## `factory_fix` by robot `i`'s name, once a robot a visit.
func _tell_fix(i: int) -> void:
	if i < 0 or i >= sim.robots.size() or _fix_told.has(i):
		return
	_fix_told[i] = true
	Analytics.track("factory_fix", {"robot": String(sim.robots[i].name)})

## What the chips show, as a key that changes only when they would.
func _chips_state() -> String:
	var key := "%d|%d" % [selected, sim.robots.size()]
	for i in sim.robots.size():
		key += "|%s%s" % [sim.robots[i].stuck, "!" if robot_fault(i) else ""]
	return key

## A chip a robot: a white capsule ringed in the accent when it is the one
## picked, the robot in its floor tint with its face, its name, and a red dot
## on the corner while it has a fault.
func _draw_chips() -> void:
	var font := get_theme_font("font", "SheetTitle")
	for i in sim.robots.size():
		var b: Dictionary = sim.robots[i]
		var r := _chip_at(i)
		var rad := CHIP_H * 0.5
		_chips_l.draw_style_box(_chip_box(Color(Pal.TEXT, 0.16), rad), Rect2(r.position + Vector2(0.0, 5.0), r.size))
		var face := _chip_box(Pal.SURFACE, rad)
		if i == selected:
			face.border_color = Pal.ACCENT
			face.set_border_width_all(6)
		_chips_l.draw_style_box(face, r)
		# the robot stands on its feet: they go under the chip's middle
		var xf := Transform2D(0.0, Vector2(0.62, 0.62), 0.0, r.position + Vector2(rad + 4.0, rad + 27.0))
		_chips_l.draw_mesh(Art.robot(), null, xf, Life.TINTS[i % Life.TINTS.size()])
		_chips_l.draw_mesh(Art.face(String(b.stuck)), null, xf)
		var key := "FACTORY_" + String(b.name).to_upper()
		var said := tr(key) if tr(key) != key else String(b.name)
		_chips_l.draw_string(font, Vector2(r.position.x + CHIP_H + 6.0, r.position.y + rad + 11.0), said,
			HORIZONTAL_ALIGNMENT_LEFT, CHIP_W - CHIP_H - 20.0, 32, Pal.TEXT)
		if robot_fault(i):
			var at := r.position + Vector2(r.size.x - DOT_R * 0.6, DOT_R * 0.6)
			_chips_l.draw_circle(at, DOT_R + 4.0, Pal.SURFACE, true, -1.0, true)
			_chips_l.draw_circle(at, DOT_R, Pal.BAD, true, -1.0, true)

## The robot's sheet, where its program is read and changed: it slides up
## over the field's lower part (or turns to this robot if it is up), the
## chips stay over it, and the view goes where the robot stands in the strip
## of floor left between them.
func open_sheet(i: int) -> void:
	if i < 0 or i >= sim.robots.size():
		return
	_let_go()
	if _drawer.visible:
		close_drawer()
	if sim.picked != "":
		pick("")
	selected = i
	_fx.touch()
	_chips_l.queue_redraw()
	sheet.open(i)
	_keep_in_view(true)

## With the sheet up the picked robot is kept in the strip of floor between
## the chips and the sheet: at once (`now`, as it opens) or, as it walks,
## once it nears either edge. Only the view's height moves.
func _keep_in_view(now: bool) -> void:
	if _mode == "pan" and _moved:
		return
	var top := _chips_l.get_global_rect().end.y - field.get_global_rect().position.y
	var foot := field.size.y - sheet.size.y
	# where the robot will stand once the view has come to rest
	var at: Vector2 = life.robot_pos(selected)
	var y := field.size.y * CENTRE.y + (at.y - _cam_to.y) * _zoom
	var edge := (foot - top) * 0.2
	if not now and y > top + edge and y < foot - edge:
		return
	var want := (top + foot) * 0.5
	_cam_raw = _clamp(Vector2(_cam_to.x, at.y - (want - field.size.y * CENTRE.y) / _zoom))
	_cam_to = _cam_raw

# --- the drawer ---

func _refresh_drawer() -> void:
	var shown := 0
	for kind: String in DRAWER_TILES:
		if sim.unlocked(kind):
			shown += 1
	# nothing to lay before milestone 1: no button for an empty drawer
	_drawer_b.visible = shown > 0 or sim.picked != ""
	# a column of five, then another beside it
	var columns := maxi(1, ceili(shown / float(DRAWER_ROWS)))
	if _drawer.columns != columns:
		_drawer.columns = columns
		_drawer.offset_top = _drawer.offset_bottom
		_drawer.offset_right = _drawer.offset_left
	for kind: String in DRAWER_TILES:
		var t: Dictionary = _tiles[kind]
		(t.button as Control).visible = sim.unlocked(kind)
		Tile.price(t, Art.short(sim.price(kind)), sim.coins >= sim.price(kind))
		Tile.mark(t, sim.picked == kind)
	_drawer_b.queue_redraw()

func drawer_open() -> bool:
	return _drawer.visible

func open_drawer() -> void:
	_let_go()
	_refresh_drawer()
	_drawer.visible = true
	_drawer_catch.visible = true
	Motion.appear(_drawer, 0.0, 1.0, 0.16)
	_drawer_b.queue_redraw()

func close_drawer() -> void:
	_drawer.visible = false
	_drawer_catch.visible = false
	_drawer_b.queue_redraw()

## The drawer's button: with something picked it is the way out of it; else
## it opens the drawer, or shuts it.
func _on_drawer_button() -> void:
	if sim.picked != "":
		pick("")
	elif _drawer.visible:
		close_drawer()
	else:
		open_drawer()

## The debug button: what is built costs nothing while it is on. Not kept.
func _on_free_button() -> void:
	sim.no_cost = not sim.no_cost
	_fx.touch()
	_hud_key = ""
	_free_b.queue_redraw()

## A coin and a nought; ringed in the accent while it is on.
func _draw_free_button() -> void:
	var c := _free_b.size * 0.5
	if sim.no_cost:
		_free_b.draw_arc(c, FREE_B * 0.5 - 6.0, 0.0, TAU, 40, Pal.ACCENT, 6.0, true)
	_free_b.draw_mesh(Art.icon("coin"), null, Transform2D(0.0, Vector2(0.42, 0.42), 0.0, c + Vector2(-15.0, 0.0)), Color(1.0, 1.0, 1.0, 1.0 if sim.no_cost else 0.55))
	var font := get_theme_font("font", "SheetTitle")
	_free_b.draw_string(font, c + Vector2(8.0, 14.0), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Pal.TEXT if sim.no_cost else Pal.TEXT_DIM)

func _on_drawer_tile(kind: String) -> void:
	pick(kind)
	close_drawer()

## What the hand lays now: a belt kind, or "" for nothing.
func pick(kind: String) -> void:
	sim.picked = kind
	_let_go()
	_refresh_drawer()
	_line_b.visible = traces()

## Whether the hand traces paths: a belt or a fast belt picked (a bridge
## goes one at a time).
func traces() -> bool:
	return Sim.BELTS.has(sim.picked) and not Sim.ONE_TILE.has(sim.picked)

## Straight lines on or off for the path (the chip, or a harness).
func toggle_straight() -> void:
	straight = not straight
	_line_at = _clock
	_fx.touch(1.06 if straight else 0.94)
	_line_b.queue_redraw()

## The Straight chip, Tally's: a paper capsule, a ruler line and its
## caption; on, it wears the sun and the line is straight; off, it bends.
func _draw_line_chip() -> void:
	var r := Rect2(Vector2.ZERO, _line_b.size)
	var sc := 1.0 if Motion.reduce else Motion.bump_scale(_clock - _line_at, 0.12, 0.2)
	var c := r.get_center()
	_line_b.draw_set_transform(c - c * sc, 0.0, Vector2(sc, sc))
	var ink := PiecePill.INK
	var rad := LINE_H * 0.5
	_line_b.draw_style_box(_chip_box(Color(Pal.TEXT, 0.16), rad), Rect2(r.position + Vector2(0, 5.0), r.size))
	_line_b.draw_style_box(_chip_box(Pal.SUN if straight else PiecePill.PAPER, rad), r)
	var g := Vector2(r.position.x + 40.0, c.y)
	var col := ink if straight else Color(ink, 0.55)
	if straight:
		_line_b.draw_line(g + Vector2(-16, 12), g + Vector2(16, -12), col, 7.0, true)
	else:
		_line_b.draw_polyline(PackedVector2Array([g + Vector2(-16, 12), g + Vector2(-16, -8), g + Vector2(16, -8)]), col, 7.0, true)
	var font := get_theme_font("font", "SheetTitle")
	var cap := tr("TL_STRAIGHT_ON") if straight else tr("TL_STRAIGHT_OFF")
	_line_b.draw_string(font, Vector2(r.position.x + 66.0, c.y + 9.0), cap, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 80.0, 26, col)
	_line_b.draw_set_transform(Vector2.ZERO)

func _chip_box(fill: Color, rad: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	return sb

## The button says what is picked (and wears a cross: press to put it down),
## or shows the belt, the first thing a drawer here holds.
func _draw_drawer_button() -> void:
	var c := _drawer_b.size * 0.5
	var picked: String = sim.picked
	if picked != "":
		_drawer_b.draw_arc(c, DRAWER_B * 0.5 - 7.0, 0.0, TAU, 48, Pal.ACCENT, 7.0, true)
	var mesh: ArrayMesh = Art.icon(picked if picked != "" else "belt")
	_drawer_b.draw_mesh(mesh, null, Transform2D(0.0, Vector2(0.82, 0.82), 0.0, c))
	if picked != "" or _drawer.visible:
		var at := Vector2(_drawer_b.size.x - 22.0, 22.0)
		_drawer_b.draw_circle(at, 22.0, Pal.ACCENT, true, -1.0, true)
		Icons.paint(_drawer_b, "cross", Rect2(at - Vector2(13.0, 13.0), Vector2(26.0, 26.0)), Pal.SURFACE)


## A finger is a ScreenTouch and never a mouse button: the project turned
## mouse-from-touch off on 2026-09-22, and the Grove could not be chopped on
## a phone until its screen read touches (2026-10-06).
func _on_field_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_press(t.index, t.position)
		else:
			_release(t.index, t.position)
	elif event is InputEventScreenDrag:
		_drag((event as InputEventScreenDrag).index, (event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT:
			if b.pressed:
				_press(MOUSE, b.position)
			else:
				_release(MOUSE, b.position)
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by_hand(true)
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by_hand(false)
	elif event is InputEventMouseMotion and _touches.has(MOUSE):
		_drag(MOUSE, (event as InputEventMouseMotion).position)


func _press(finger: int, pos: Vector2) -> void:
	if _held_back:
		return
	_touches[finger] = pos
	if _touches.size() == 2:
		# a second finger: whatever the first was doing is a pinch now
		var all := _touches.values()
		_pinch = maxf(1.0, (all[0] as Vector2).distance_to(all[1]))
		_mode = "pinch"
		_finger = NO_FINGER
		_long = {}
		return
	if _touches.size() > 2:
		return
	_finger = finger
	_start = pos
	_at = pos
	_moved = false
	_held = 0.0
	_run = {}
	_long = {}
	_path = []
	_axis = -1
	_vel = Vector2.ZERO
	_cam_raw = _cam
	_cam_to = _cam
	_piece_hit = ""
	_consumed = false
	if not _piece.is_empty():
		# a press on the pill is its button's; anywhere else it closes the pill
		_consumed = true
		_mode = "pill"
		_piece_hit = PiecePill.button_at(_piece_layout(), pos)
		if _piece_hit == "":
			_close_piece()
			_fx.touch(0.84)
		return
	# a chip lies over the floor: a press on it is the chip's, belt or none
	_chip_down = _chip_under(pos)
	if _chip_down >= 0:
		_mode = "chip"
		return
	if Sim.BELTS.has(sim.picked):
		_mode = "belt"
		_belt_tile = Vector2i(tile_under(pos).floor())
		_path = [_belt_tile]
	else:
		_mode = "pan"
	var h := hit(pos)
	if h.what == "belt":
		_long = {"tile": h.tile}

func _drag(finger: int, pos: Vector2) -> void:
	if not _touches.has(finger):
		return
	var before: Vector2 = _touches[finger]
	_touches[finger] = pos
	if _mode == "pinch":
		if _touches.size() == 2:
			var all := _touches.values()
			var ratio := (all[0] as Vector2).distance_to(all[1]) / _pinch
			if ratio > PINCH and _far:
				_zoom_by_hand(false)
				_mode = "done"
			elif ratio < 1.0 / PINCH and not _far:
				_zoom_by_hand(true)
				_mode = "done"
		return
	if finger != _finger:
		return
	_at = pos
	if not _moved and pos.distance_to(_start) >= TAP:
		_moved = true
		_long = {}
	match _mode:
		"pan":
			if _moved:
				var now := Time.get_ticks_msec()
				var step := (pos - before) / _zoom
				_vel = _vel.lerp(-step / maxf(0.008, (now - _moved_at) / 1000.0), 0.6)
				_moved_at = now
				_cam_raw -= step
				var inside := _clamp(_cam_raw)
				_cam_to = inside + (_cam_raw - inside) * SOFT
				_cam = _cam_to
		"belt":
			if _moved:
				if traces():
					_trace_to(Vector2i(tile_under(pos).floor()))
					_run = _path_run()
				else:
					_run = _run_to(tile_under(pos))


func _release(finger: int, pos: Vector2) -> void:
	if not _touches.has(finger):
		return
	_touches.erase(finger)
	if _mode == "pinch" or _mode == "done":
		if _touches.is_empty():
			_mode = ""
		return
	if finger != _finger:
		return
	_finger = NO_FINGER
	var mode := _mode
	_mode = ""
	_long = {}
	match mode:
		"pill":
			if _piece_hit != "" and PiecePill.button_at(_piece_layout(), pos) == _piece_hit:
				_piece_press(_piece_hit)
			_piece_hit = ""
			_consumed = false
		"chip":
			if not _moved and _chip_under(pos) == _chip_down:
				open_sheet(_chip_down)
			_chip_down = -1
		"pan":
			if _moved:
				# the view runs on a little and comes to rest inside its bounds
				if Time.get_ticks_msec() - _moved_at < 90:
					_cam_raw += _vel * FLING
				_cam_raw = _clamp(_cam_raw)
				_cam_to = _cam_raw
			else:
				_tap(pos)
		"belt":
			if _moved:
				if traces():
					_at = pos
					_trace_to(Vector2i(tile_under(pos).floor()))
					_lay_path(_path_run())
				else:
					_lay_run(_run_to(tile_under(pos)))
			else:
				_tap(pos)
			_run = {}
			_path = []

## Every finger is let go: a card went up, the app lost the focus.
func _let_go() -> void:
	_touches.clear()
	_finger = NO_FINGER
	_mode = ""
	_long = {}
	_run = {}
	_path = []
	_chip_down = -1
	_cam_raw = _cam_to
	_close_piece()

## What is under a point of the field: {what, tile} and for a robot its
## index as `id`. A chip first (it lies over the floor), then a robot within
## twice TAP of the middle of its body, the nearest, then a belt (its bed
## stands over its tile: the bed under the point first), then the floor.
func hit(pos: Vector2) -> Dictionary:
	var tile := Vector2i(tile_under(pos).floor())
	var chip := _chip_under(pos)
	if chip >= 0:
		return {"what": "chip", "id": chip, "tile": tile}
	var best := -1
	var best_d := TAP * 2.0
	for i in sim.robots.size():
		var d := pos.distance_to(to_field(life.robot_at(i) + ROBOT_MID))
		if d <= best_d:
			best = i
			best_d = d
	if best >= 0:
		return {"what": "robot", "id": best, "tile": tile}
	var bed := Vector2i(tile_under(pos - Art.BELT_LIFT * _zoom).floor())
	if sim.belts.has(bed):
		return {"what": "belt", "tile": bed}
	if sim.belts.has(tile):
		return {"what": "belt", "tile": tile}
	return {"what": "ground", "tile": tile}

func _tap(pos: Vector2) -> void:
	var h := hit(pos)
	var tile: Vector2i = h.tile
	match String(h.what):
		"chip", "robot":
			open_sheet(int(h.id))
		"belt":
			# a belt of another kind than the one in hand becomes it, as it
			# lies; else the tap opens its pill and never turns it by itself
			if Sim.BELTS.has(sim.picked) and sim.belt_kind(tile) != sim.picked:
				sim.lay_belt(tile, int(sim.belts[tile]), sim.picked)
			else:
				_open_piece(tile)
		"ground":
			if Sim.BELTS.has(sim.picked) and sim.can_lay(tile):
				# a run of one: it flows as what it meets says, else as the last did
				_belt_tile = tile
				_lay_run(_run_to(Vector2(tile) + Vector2(0.5, 0.5)))

## The run a swipe from `_belt_tile` to `to` (a point of sim tile space)
## would lay: a straight line of tiles along whichever tile axis the finger
## is further along, from the pressed tile to the finger's, cut short at the
## first tile a belt cannot go on. Belts already on the line are part of it
## and cost nothing; `lay` is how many tiles, from the start, the coins
## reach. The user, 2026-10-10: "user should be able to hold and swip to add
## multiples (only straight line)".
func _run_to(to: Vector2) -> Dictionary:
	var kind: String = sim.picked if Sim.BELTS.has(sim.picked) else "belt"
	if Sim.ONE_TILE.has(kind):
		# one at a time, where the finger is
		_belt_tile = Vector2i(to.floor())
	var from := _belt_tile
	var d := to - (Vector2(from) + Vector2(0.5, 0.5))
	var along_x := absf(d.x) >= absf(d.y)
	var end := Vector2i(to.floor())
	var n := absi(end.x - from.x) if along_x else absi(end.y - from.y)
	var step := Vector2i(1 if d.x >= 0.0 else -1, 0) if along_x else Vector2i(0, 1 if d.y >= 0.0 else -1)
	var tiles: Array = []
	var lay := 0
	var coins: int = sim.coins
	for i in n + 1:
		var tile := from + step * i
		if not sim.can_lay(tile):
			break
		tiles.append(tile)
		if not sim.belts.has(tile):
			coins -= sim.price(kind)
		elif sim.belt_kind(tile) != kind and not Sim.ONE_TILE.has(kind):
			coins -= sim.price(kind) - sim.price(sim.belt_kind(tile))
		if coins >= 0:
			lay = tiles.size()
	if tiles.is_empty():
		return {}
	var swipe := Art.DIRS.find(step) if n > 0 else _facing
	var f := run_facing(sim, tiles, swipe)
	var faces: Array = []
	faces.resize(tiles.size())
	faces.fill(f)
	return {"tiles": tiles, "lay": lay, "facing": f, "faces": faces}

## Whether the belt on `tile` hands on to something: a belt, the table or
## the deliver pad in front of it.
static func _feeds(land: RefCounted, tile: Vector2i) -> bool:
	return _takes(land, tile + Art.DIRS[int(land.belts[tile])])

## Whether `tile` is somewhere a belt delivers into but a belt: the table,
## the deliver pad (the sim's own rule, `_takes_in`).
static func _takes_in(land: RefCounted, tile: Vector2i) -> bool:
	var s: String = land.station_at(tile)
	return s == "table" or s == "deliver"

static func _takes(land: RefCounted, tile: Vector2i) -> bool:
	return land.belts.has(tile) or _takes_in(land, tile)

## The way a run of belts flows: `tiles` in the sim's coordinates from where
## the swipe began to where it ended, `swipe` the facing from its first tile
## to its last. Returns a sim facing, `swipe` or its opposite. The user,
## 2026-10-10: "If the convey didn't connect to any other convey, show a
## direction reference line (it always move into the direction of the
## movement), if it connect to another one, the direction become the
## direction from the one already placed".
##
## Each end of the run is asked what it meets, the start first (where the
## two disagree the start wins), and the first answer at an end stands:
## 1. the tile beyond it, along the line, is a belt pointing into it: the
##    run flows AWAY from this end;
## 2. the tile beyond it is a belt that does not point into it, the table or
##    the deliver pad: the run flows TOWARD it;
## 3. the end tile is itself a laid belt (and the run is longer than it):
##    pointing along the run already, or leading nowhere, the run carries on
##    from it, AWAY; leading on to something else, the run joins it, TOWARD;
## 4. a belt beside the end tile points into it: AWAY.
## With no answer at either end the run flows the way the finger moved.
static func run_facing(land: RefCounted, tiles: Array, swipe: int) -> int:
	var back := (swipe + 2) % 4
	for at_start: bool in [true, false]:
		var out := back if at_start else swipe       # the way off this end
		var away := swipe if at_start else back      # the flow that leaves this end
		var e: Vector2i = tiles[0] if at_start else tiles[tiles.size() - 1]
		var beyond: Vector2i = e + Art.DIRS[out]
		if land.belts.has(beyond):
			return away if int(land.belts[beyond]) == (out + 2) % 4 else out
		if _takes_in(land, beyond):
			return out
		if tiles.size() > 1 and land.belts.has(e):
			return away if int(land.belts[e]) == away or not _feeds(land, e) else out
		for side: int in [(out + 1) % 4, (out + 3) % 4]:
			var beside: Vector2i = e + Art.DIRS[side]
			if land.belts.has(beside) and int(land.belts[beside]) == (side + 2) % 4:
				return away
	return swipe

## The finger lifted on a run: every tile of it the coins reach that has no
## belt gets one, flowing the run's way. Belts already on the line are left
## as they lie, but for the one the run flows out of when it led nowhere
## (it turns into the run: the corner of an L), and a run of one tile.
func _lay_run(run: Dictionary) -> void:
	if run.is_empty():
		return
	var tiles: Array = run.tiles
	var f: int = run.facing
	# the end the run flows out of
	var source: Vector2i = tiles[0]
	if tiles.size() > 1 and Art.DIRS[f] != (tiles[1] as Vector2i) - (tiles[0] as Vector2i):
		source = tiles[tiles.size() - 1]
	var kind: String = sim.picked if Sim.BELTS.has(sim.picked) else "belt"
	for i in int(run.lay):
		var tile: Vector2i = tiles[i]
		if not sim.belts.has(tile):
			sim.lay_belt(tile, f, kind)
		elif int(sim.belts[tile]) != f and (tiles.size() == 1 or (tile == source and not _feeds(sim, tile))):
			sim.lay_belt(tile, f, kind)
		elif sim.belt_kind(tile) != kind and (not Sim.ONE_TILE.has(kind) or tiles.size() == 1):
			# a run of another kind over belts that lie there: they become it, facing as they did
			sim.lay_belt(tile, int(sim.belts[tile]), kind)
	if int(run.lay) < tiles.size() and (not sim.belts.has(tiles[int(run.lay)]) or sim.belt_kind(tiles[int(run.lay)]) != kind):
		# the coins ran out along the way: the sim refuses the next and the pill says so
		sim.lay_belt(tiles[int(run.lay)], f, kind)
	_facing = f

# --- the traced path (Tally's belt tool) ---

## The path follows the finger to tile `t`: between the path's end and `t`
## it steps the larger axis first, then the other, a tile at a time. A step
## onto a tile already on the path takes the path back to it.
func _trace_to(t: Vector2i) -> void:
	if _path.is_empty():
		_path = [t]
		return
	if straight:
		_trace_straight(t)
		return
	var cur: Vector2i = _path[-1]
	var d := t - cur
	if d == Vector2i.ZERO:
		return
	var along_x := absi(d.x) >= absi(d.y)
	var first := Vector2i(signi(d.x), 0) if along_x else Vector2i(0, signi(d.y))
	var second := Vector2i(0, signi(d.y)) if along_x else Vector2i(signi(d.x), 0)
	var steps := []
	for j in (absi(d.x) if along_x else absi(d.y)):
		steps.append(first)
	for j in (absi(d.y) if along_x else absi(d.x)):
		steps.append(second)
	for st: Vector2i in steps:
		var nxt: Vector2i = (_path[-1] as Vector2i) + st
		var at := _path.find(nxt)
		if at >= 0:
			_path.resize(at + 1)
		else:
			_path.append(nxt)
		if _path.size() >= 2:
			_trace_f = Art.DIRS.find((_path[-1] as Vector2i) - (_path[-2] as Vector2i))

## Straight: the run from the first tile along the axis the finger first
## left it by, as far as the finger has gone along it; a finger gone off
## that axis bends it once into a second leg across to the finger (Tally's
## L, the user, 2026-10-19: "if user moves finger up or down, it make a L
## shape"); back on the axis, the leg goes.
func _trace_straight(t: Vector2i) -> void:
	var p0: Vector2i = _path[0]
	var d := t - p0
	if _axis < 0:
		if d == Vector2i.ZERO:
			return
		_axis = 0 if absi(d.x) >= absi(d.y) else 1
	var n := d.x if _axis == 0 else d.y
	# off the axis by the finger itself, not its tile: a quarter tile of
	# slack past a row's edge before the line bends into it
	var off: Vector2 = tile_under(_at) - (Vector2(p0) + Vector2(0.5, 0.5))
	var across := off.y if _axis == 0 else off.x
	var m := int(signf(across) * floorf(absf(across) + 0.25))
	var step := Vector2i(signi(n), 0) if _axis == 0 else Vector2i(0, signi(n))
	var step2 := Vector2i(0, signi(m)) if _axis == 0 else Vector2i(signi(m), 0)
	_path = [p0]
	for j in absi(n):
		_path.append((_path[-1] as Vector2i) + step)
	for j in absi(m):
		_path.append((_path[-1] as Vector2i) + step2)
	if m != 0:
		_trace_f = Art.DIRS.find(step2)
	elif n != 0:
		_trace_f = Art.DIRS.find(step)

## What the traced path would lay: {tiles, faces, acts, lay}. The path is
## cut at the first tile a belt cannot go on, and its last belt then faces
## into that tile (the table, the deliver pad). Each belt faces
## the next, the finger's way: a path never flows against the finger (the
## user in Tally, 2026-10-18, belts "always follow the finger"); Flip on the
## pill turns a line round. The last faces the way of the last step, or
## into what takes things beside it. What it does to each tile (`acts`):
## "lay" a new belt; "face" a belt it starts on that led nowhere, turned
## into it (the corner of an L); "kind" a belt of another kind, made the
## kind in hand as it lies; "bridge" a belt crossed straight across, made a
## bridge when the bridge is open (Tally's crossings); "keep" any other
## belt, left as it lies (a path never turns a belt it crosses). `lay` is
## how many of them, from the start, the coins reach.
func _path_run() -> Dictionary:
	var kind: String = sim.picked if traces() else "belt"
	var tiles: Array = []
	var f_last := _trace_f
	for i in _path.size():
		var t: Vector2i = _path[i]
		if not sim.can_lay(t):
			if i > 0:
				f_last = Art.DIRS.find(t - (_path[i - 1] as Vector2i))
			break
		tiles.append(t)
	if tiles.is_empty():
		return {}
	var n := tiles.size()
	if n == 1 and _path.size() == 1:
		# a swipe inside one tile: the way the finger went
		var sw: Vector2 = tile_under(_at) - tile_under(_start)
		if absf(sw.x) >= absf(sw.y):
			f_last = 0 if sw.x >= 0.0 else 2
		else:
			f_last = 1 if sw.y >= 0.0 else 3
	var last: Vector2i = tiles[n - 1]
	var prev: Vector2i = tiles[n - 2] if n > 1 else Sim.NONE
	if not _takes(sim, last + Art.DIRS[f_last]):
		for d in 4:
			var to: Vector2i = last + Art.DIRS[d]
			if to != prev and _takes_in(sim, to):
				f_last = d
				break
	var faces: Array = []
	for i in n - 1:
		faces.append(Art.DIRS.find((tiles[i + 1] as Vector2i) - (tiles[i] as Vector2i)))
	faces.append(f_last)
	var acts: Array = []
	var lay := 0
	var coins: int = sim.coins
	for i in n:
		var t: Vector2i = tiles[i]
		var act := "lay"
		var cost: int = sim.price(kind)
		if sim.belts.has(t):
			var was: String = sim.belt_kind(t)
			var plain := not Sim.ONE_TILE.has(was)
			var into: int = faces[i - 1] if i > 0 else faces[i]
			act = "keep"
			cost = 0
			if plain and i > 0 and i < n - 1 and into == int(faces[i]) and int(sim.belts[t]) % 2 != into % 2:
				if sim.unlocked("bridge"):
					act = "bridge"
					cost = sim.price("bridge") - sim.price(was)
			elif plain and (n == 1 or (i == 0 and not _feeds(sim, t))) and int(sim.belts[t]) != int(faces[i]):
				act = "face"
				cost = sim.price(kind) - sim.price(was) if was != kind else 0
			elif plain and was != kind:
				act = "kind"
				cost = sim.price(kind) - sim.price(was)
		acts.append(act)
		coins -= cost
		if coins >= 0:
			lay = i + 1
	return {"tiles": tiles, "faces": faces, "acts": acts, "lay": lay, "facing": f_last}

## The traced path laid as the finger lifts (Tally: "keep it as preview
## until user release, no confirm dialog"), as far as the coins reach; the
## sim refuses the first tile past them, and the pill says so.
func _lay_path(run: Dictionary) -> void:
	if run.is_empty():
		return
	var kind: String = sim.picked if traces() else "belt"
	var tiles: Array = run.tiles
	var reach := mini(int(run.lay) + 1, tiles.size())
	for i in reach:
		var t: Vector2i = tiles[i]
		var f: int = run.faces[i]
		match String(run.acts[i]):
			"lay":
				sim.lay_belt(t, f, kind)
			"face":
				sim.lay_belt(t, f, kind)
			"kind":
				sim.lay_belt(t, int(sim.belts[t]), kind)
			"bridge":
				sim.lay_belt(t, int(sim.belts[t]), "bridge")
	_facing = int(run.facing)

## While a path is traced near the field's edge, the view moves that way
## and the path follows the finger on.
func _edge_pan(delta: float) -> void:
	if _mode != "belt" or not _moved or _finger == NO_FINGER or not traces():
		return
	var push := Vector2.ZERO
	var s := field.size
	if _at.x < EDGE:
		push.x = -1.0
	elif _at.x > s.x - EDGE:
		push.x = 1.0
	if _at.y < EDGE:
		push.y = -1.0
	elif _at.y > s.y - EDGE:
		push.y = 1.0
	if push == Vector2.ZERO:
		return
	_cam_raw = _clamp(_cam_to + push * EDGE_SPEED * delta / _zoom)
	_cam_to = _cam_raw
	_cam = _cam_to
	_place_world()
	_trace_to(Vector2i(tile_under(_at).floor()))
	_run = _path_run()


# --- the belt pill ---

func piece_open() -> bool:
	return not _piece.is_empty()

func _open_piece(tile: Vector2i) -> void:
	var one: bool = Sim.ONE_TILE.has(sim.belt_kind(tile))
	_piece = {"tile": tile, "buttons": PILL_ONE if one else PILL_PLAIN, "at": _clock}
	_fx.touch()

func _close_piece() -> void:
	_piece = {}
	_piece_hit = ""

## Where the belt pill stands: by its belt, kept between the chips at the
## top and the drawer at the foot.
func _piece_layout() -> Dictionary:
	if _piece.is_empty() or field == null:
		return {}
	var m := to_field(life.mid(_piece.tile) + Art.BELT_LIFT)
	var half := Vector2(0.0, Art.K * Art.DEEP * _zoom)
	var top := _chips_l.get_global_rect().end.y - field.get_global_rect().position.y
	var foot: float = field.size.y - SafeArea.insets(self).y - DRAWER_UP * 0.5
	var view := Rect2(0.0, top, field.size.x, maxf(foot - top, 1.0))
	return PiecePill.layout(_piece.buttons, m - half, m + half, view)

## Where pill button `name` is in the field's pixels (a harness presses it).
func piece_button_rect(name: String) -> Rect2:
	var lay := _piece_layout()
	return Rect2() if lay.is_empty() else lay.buttons.get(name, Rect2())

## A pill button let go on: what it does. Turn and Flip leave the pill up;
## the sales close it.
func _piece_press(name: String) -> void:
	if _piece.is_empty():
		return
	var tile: Vector2i = _piece.tile
	_btn_at[name] = _clock
	# every button is heard through its deed's event (turned, flipped, sold)
	match name:
		"turn":
			sim.turn(tile)
		"flip":
			sim.flip_line(tile)
		"sell":
			_close_piece()
			sim.sell(tile)
		"run", "line":
			_close_piece()
			sim.sell_belts(sim.line_tiles(tile, name == "run"))

func _draw_piece() -> void:
	var lay := _piece_layout()
	if lay.is_empty():
		return
	var title := tr(String(NAMES.get(sim.belt_kind(_piece.tile), "FACTORY_BELT")))
	_pill_ui.draw(_pill_l, lay, _piece.buttons, title, get_theme_font("font", "SheetTitle"), _clock, float(_piece.at), _btn_at, false)


## The run a swipe would lay, as beds on their way: paper where a belt will
## go, the warn tone past what the coins reach, nothing over a belt that is
## there already.
func _ghosts() -> Array:
	if _mode != "belt" or _run.is_empty():
		return []
	var out: Array = []
	var tiles: Array = _run.tiles
	for i in tiles.size():
		var tile: Vector2i = tiles[i]
		if _run.has("acts"):
			if String(_run.acts[i]) == "keep":
				continue
		elif sim.belts.has(tile) and (sim.belt_kind(tile) == sim.picked or Sim.ONE_TILE.has(sim.picked)):
			continue
		var short: bool = i >= int(_run.lay)
		out.append([Art.belt(), Transform2D(0.0, Art.BELT_LIFT) * Art.flat(Vector2(tile), int(_run.faces[i])),
			Color(1.0, 0.5, 0.45, 0.8) if short else Color(1.0, 1.0, 1.0, 0.92)])
	return out

## A finger held still on a belt sells it back.
func _step_hand(delta: float) -> void:
	if _long.is_empty() or _finger == NO_FINGER:
		return
	_held += delta
	if _held >= HOLD:
		var tile: Vector2i = _long.tile
		_long = {}
		_mode = "done"
		_finger = NO_FINGER
		sim.sell(tile)

# --- drawing ---

## Over the floor and moving with it: the way a path being laid will flow,
## the sun ring of the belt the pill is for, the ring of a finger held on a
## belt it would sell, and what a sale was worth.
func _draw_over(ci: CanvasItem) -> void:
	if _mode == "belt" and not _run.is_empty():
		_draw_flow(ci)
	if not _piece.is_empty():
		# the belt the pill is for wears a sun ring, lying on its bed
		ci.draw_set_transform(life.mid(_piece.tile) + Art.BELT_LIFT, 0.0, Vector2(1.0, Art.DEEP))
		ci.draw_arc(Vector2.ZERO, Art.K * 0.95, 0.0, TAU, 48, Color(Pal.SUN, 0.95), 8.0, true)
		ci.draw_set_transform(Vector2.ZERO)
	if not _long.is_empty() and _held >= HOLD_SHOWS:
		var k := clampf((_held - HOLD_SHOWS) / (HOLD - HOLD_SHOWS), 0.0, 1.0)
		ci.draw_set_transform(life.mid(_long.tile) + Art.BELT_LIFT, 0.0, Vector2(1.0, Art.DEEP))
		ci.draw_arc(Vector2.ZERO, 74.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.35), 9.0, true)
		ci.draw_arc(Vector2.ZERO, 74.0, -PI * 0.5, -PI * 0.5 + TAU * k, 48, Pal.ACCENT, 9.0, true)
		ci.draw_set_transform(Vector2.ZERO)
	var font := get_theme_font("font", "SheetTitle")
	for n: Dictionary in _nums:
		var k: float = float(n.t) / NUM
		var w := font.get_string_size(n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
		var at: Vector2 = (n.at as Vector2) + Vector2(-w * 0.5, 0.0 if Motion.reduce else -k * 60.0)
		var a := 1.0 - k * k * k
		ci.draw_string_outline(font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, 8, Color(0.23, 0.19, 0.16, 0.7 * a))
		ci.draw_string(font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(Art.GOLD_HI, a))

## The direction reference line of a run or a path being laid: a soft line
## along its beds and a chevron a tile pointing the way things will move
## there, the last one a full arrowhead in the sun. Drawn, not lettered:
## the fonts have no arrow.
func _draw_flow(ci: CanvasItem) -> void:
	var tiles: Array = _run.tiles
	var faces: Array = _run.faces
	var n := tiles.size()
	var pts := PackedVector2Array()
	for tile: Vector2i in tiles:
		pts.append(life.mid(tile) + Art.BELT_LIFT)
	# half a tile of the way each belt flows, on the screen
	var halves: Array = []
	for i in n:
		var d := Vector2(Art.DIRS[int(faces[i])])
		halves.append((life.seen(Vector2(tiles[i]) + Vector2(0.5, 0.5) + d * 0.5) + Art.BELT_LIFT) - pts[i])
	var line := PackedVector2Array()
	var into0: Vector2 = halves[0] if n == 1 else (pts[1] - pts[0]).normalized() * (halves[0] as Vector2).length()
	line.append(pts[0] - into0 * 0.7)
	for p in pts:
		line.append(p)
	line.append(pts[n - 1] + (halves[n - 1] as Vector2) * 0.7)
	var ink := Color(0.23, 0.19, 0.16, 0.45)
	ci.draw_polyline(line, ink, 13.0, true)
	ci.draw_polyline(line, Color(1.0, 1.0, 1.0, 0.92), 6.0, true)
	for i in n:
		var half: Vector2 = halves[i]
		var way := half.normalized()
		var across := Vector2(-way.y, way.x)
		var head := i == n - 1
		var size := 1.5 if head else 1.0
		var c: Vector2 = pts[i] + (half * 0.7 if head else Vector2.ZERO)
		var arrow := PackedVector2Array([c - way * 13.0 * size + across * 15.0 * size, c + way * 5.0 * size, c - way * 13.0 * size - across * 15.0 * size])
		ci.draw_polyline(arrow, ink, 13.0, true)
		ci.draw_polyline(arrow, Color(1.0, 1.0, 1.0, 0.95) if not head else Pal.SUN, 6.0, true)

# --- leaving ---

func _save() -> void:
	if sim == null or _left:
		return
	sim.save()
	_since_save = 0.0

## The floor is kept and the screen stops stepping it before it says it is
## closed: from here on it is the tab's again.
func _on_back() -> void:
	if sheet.is_open():
		sheet.close()
		return
	sim.picked = ""
	_save()
	_left = true
	set_process(false)
	Analytics.track("factory_leave", {"seconds": int((Time.get_ticks_msec() - _opened_at) / 1000.0),
		"earned": sim.earned - _earned_at_open, "milestone": sim.milestone})
	closed.emit()

## Android's back, through the menu: a card or a sheet first, then the
## pill, the drawer, what is picked, and the screen.
func go_back() -> void:
	if tutor.close():
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	if sheet.is_open():
		sheet.close()
		return
	if not _piece.is_empty():
		_close_piece()
		return
	if _drawer.visible:
		close_drawer()
		return
	if sim.picked != "":
		pick("")
		return
	_on_back()
