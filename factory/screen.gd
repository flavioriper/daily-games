extends Control

## Factory: the land, played. Plates in a pond seen corner on, a closed
## forest a tap takes a log from, logs that leave it by its gates and ride
## the belts a finger drags to the market, coins that buy belts, plates, a
## forest's levels and from the first plate bought a fire and a retort. Spec
## docs/superpowers/specs/2026-10-10-factory-board-and-hand-era-design.md;
## the rules and every number are factory/sim.gd's, the drawings
## factory/art.gd's, and what is seen of the land factory/life.gd's.
##
## **It never makes or reads a land.** ui/menu/factory_tab.gd owns the one
## sim; whoever mounts this screen hands it over with `setup(sim)` before it
## enters the tree (a harness makes its own). While it is mounted it is the
## one stepping the land and draining its events, and it keeps it: every two
## seconds while something changed, at once when the app is paused or
## closed, and as it leaves.
##
## Like a Versus or Arcade screen it is its own host: it joins the
## `versus_host` group so Android's back reaches it (the tutorial, the
## settings, a card, the drawer, a picked tile, then the screen). It has no
## round, no score and no end.
##
## The hand (spec section 6). Every finger is a ScreenTouch or a ScreenDrag,
## the desktop mouse read beside them. A press that moves under TAP pixels
## is a tap: on a forest or a fire box with fuel waiting it is the labour;
## on a plus, the market, a machine or a forest's badge it opens the card; on a belt
## it turns it a quarter. A drag pans, unless Belt is picked in the drawer
## (hold and swipe: a straight run of belts is shown from the pressed tile
## to the finger with the way it will flow, and laid as the finger lifts) or a
## machine is (its ghost follows the finger and the release stands it). A
## finger held still for HOLD on a belt or a machine sells it back.

signal closed

const Art = preload("res://factory/art.gd")
const Sim = preload("res://factory/sim.gd")
const Life = preload("res://factory/life.gd")
const Tile = preload("res://factory/tile.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const ScreenTutor = preload("res://ui/hud/screen_tutor.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Analytics = preload("res://core/analytics.gd")

const GAME := "factory"
const MARGIN := 40
const PILL_H := 84.0
const ZOOM_B := 96.0
## The drawer: its round button on the left edge, this far up from the foot
## of the screen (the right thumb works the lower right), and its tiles.
const DRAWER_B := 128.0
const DRAWER_UP := 250.0
const DRAWER_W := 196.0
const DRAWER_TILE := 206.0
const DRAWER_TILES := ["belt", "firebox", "kiln", "retort", "market"]
const NAMES := {"belt": "FACTORY_BELT", "firebox": "FACTORY_FIREBOX", "kiln": "FACTORY_KILN", "retort": "FACTORY_RETORT",
	"market": "FACTORY_MARKET", "forest": "FACTORY_FOREST", "neutral": "FACTORY_NEUTRAL"}
## A forest's badge, the way to its card (a tap on the forest itself is a
## log): how far over the plate's middle it floats and how big it is, in
## view units.
const BADGE_UP := 250.0
const BADGE_R := 46.0
const CARD_W := 1000.0
const CARD_INSET := 26
const PLATE_TILE := 372.0
## A press that moves less than this is a tap, in the screen's own units.
const TAP := 24.0
## A finger held still this long on a belt or a machine sells it back; its
## ring starts to close after HOLD_SHOWS, so a plain tap shows none.
const HOLD := 0.5
const HOLD_SHOWS := 0.12
## Where the land's middle sits down the screen: under the bar and the pill.
const CENTRE := Vector2(0.5, 0.55)
## The view's middle goes this many tiles past the board's own and no
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
const QUIET := ["busy", "nothing", "same", "lit", "wait", "top"]
const TICK_VARY := 0.06
## A sale's coin: the factory's own `coin` (assets/sfx/factory/) at its own
## pitch and level, and the milliseconds between two of them at least.
const COIN_PITCH := 1.0
const COIN_DB := 0.0
const COIN_GAP := 140
## The tap is a selection moved; a tree down is a piece set down; a thing
## bought is something finished; one that cannot be is a not yet.
const HAPTICS := {"buy": Haptics.BUMP, "no": Haptics.WARN}

var sim: RefCounted
var top_bar: Control
var settings_sheet: Control
var tutor: RefCounted
var field: Control
var life: RefCounted
var world: Node2D

var _fx: Node2D
var _quiet: Node2D
var _coin_fx: Node2D
var _coin_at := -1000
var _margins: MarginContainer
var _water: ArrayMesh
var _light: ArrayMesh
var _light_l: Control
var _over_l: Node2D
var _pill: PanelContainer
var _coins_l: Label
var _zoom_b: Button
var _turn_b: Button
var _drawer_b: Button
var _drawer: VBoxContainer
var _drawer_catch: Control
var _tiles := {}        # drawer tile -> Tile
var _hud_key := ""
var _card: Control
var _card_slot: CenterContainer
var _card_tick := Callable()
var _card_for := ""
var _card_coins: Label
var _shown := 0.0
var _warn := 0.0
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
var _turn_tw: Tween

# the hand
var _touches := {}      # finger -> where it is
var _finger := NO_FINGER
var _mode := ""         # "pan", "belt", "place", "pinch", "done"
var _start := Vector2.ZERO
var _at := Vector2.ZERO
var _moved := false
var _moved_at := 0
var _held := 0.0
var _long := {}         # what a held finger would sell: {tile}
## The tile a swipe with Belt picked began on, and the run it would lay now:
## {tiles, lay (how many of them the coins reach, from the start), facing}.
var _belt_tile := Vector2i.ZERO
var _run := {}
var _facing := 0
var _pinch := 0.0
var _ghost_wob := 10.0
var _held_back := false

var _left := false
var _since_save := 0.0
var _opened_at := 0
var _earned_at_open := 0

## The land this screen plays, handed over before it enters the tree.
func setup(with_sim: RefCounted) -> void:
	sim = with_sim

func puzzle_id() -> String:
	return GAME

func _ready() -> void:
	add_to_group("versus_host")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	if sim == null:
		push_error("factory/screen.gd: setup(sim) was not called; the screen makes no land of its own")
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
	Analytics.track("factory_enter", {"plates": sim.plates.size(), "coins": sim.coins})

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
	# the Grove's four sounds, kept (spec section 10); the screen's own id is
	# the tutorial's and the analytics'
	_fx._puzzle = "grove"
	field.add_child(_fx)
	_quiet = Fx2D.new()
	_quiet.buzzes = false
	_quiet._puzzle = "grove"
	field.add_child(_quiet)
	_coin_fx = Fx2D.new()
	_coin_fx.buzzes = false
	_coin_fx._puzzle = "factory"
	field.add_child(_coin_fx)
	life.coined.connect(_on_coin)
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
	col.add_child(_coin_pill())
	# the zoom and the turn, side by side under the pill, each its own size
	var view_row := HBoxContainer.new()
	view_row.name = "View"
	view_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_row.alignment = BoxContainer.ALIGNMENT_CENTER
	view_row.add_theme_constant_override("separation", 18)
	col.add_child(view_row)
	_zoom_b = IconButton.new("minus", "", "IconButton")
	_zoom_b.name = "Zoom"
	_zoom_b.pressed.connect(func() -> void: set_far(not _far))
	_turn_b = IconButton.new("turn", "", "IconButton")
	_turn_b.name = "Turn"
	_turn_b.pressed.connect(turn_view)
	for b: Button in [_zoom_b, _turn_b]:
		b.custom_minimum_size = Vector2(ZOOM_B, ZOOM_B)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_round(b, int(ZOOM_B * 0.5))
		view_row.add_child(b)

	_drawer_catch = Control.new()
	_drawer_catch.name = "DrawerCatch"
	_drawer_catch.visible = false
	_drawer_catch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawer_catch.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
			close_drawer()
			_fx.touch(0.84))
	add_child(_drawer_catch)
	_drawer = VBoxContainer.new()
	_drawer.name = "Drawer"
	_drawer.visible = false
	_drawer.add_theme_constant_override("separation", 10)
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

	_card = Dialog.scrim()
	_card.name = "CardScrim"
	_card.visible = false
	_card.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
			close_card()
			_fx.touch(0.84))
	_card_slot = CenterContainer.new()
	_card_slot.name = "Center"
	_card_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.add_child(_card_slot)
	add_child(_card)
	_apply_insets()
	_layout_field()

## The coins held, at the top middle: the coin and the count on a white pill.
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
	_drawer.offset_left = 28.0
	_drawer.offset_right = 28.0 + DRAWER_W
	_drawer.offset_bottom = -foot - DRAWER_B - 16.0
	_drawer.offset_top = _drawer.offset_bottom

## The pond and the light are baked for the field's size, and the near zoom
## is the one at which a plate is as wide as the field.
func _layout_field() -> void:
	var s := field.size
	if s.x <= 0.0 or s.y <= 0.0 or _light_l == null:
		return
	_water = Art.water(s, 0.0)
	_light = Art.light(s)
	_near = s.x / (Art.HALF * 2.0)
	if not _laid_out:
		_laid_out = true
		_zoom = _near
		# a new land is two plates: the seam between the market's and the
		# forest behind it, so the gate, the forest's badge and the market are seen
		_cam = life.seen(Vector2(Art.PLATE * 0.5, 0.0))
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

## A point of the view held to where the view's middle may go: the board's
## own tiles and POND tiles of pond past them, measured along the land (a
## box on the screen would leave the view's middle far out on open water
## off a diamond's corners).
func _clamp(v: Vector2) -> Vector2:
	var box: Rect2 = (life.tile_bounds() as Rect2).grow(POND)
	return life.seen((life.tile_at(v) as Vector2).clamp(box.position, box.end))

## The far zoom shows twice as much; the near one a plate across the field.
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

## The view goes round a quarter, clockwise, so that what a tree or a
## building hid is seen (the user, 2026-10-10). Only the view: the turn is
## the life's (factory/life.gd, `seen` and `tile_at`), the sim's tiles and
## facings are what they were, and the tile under the middle of the screen
## stays under it. Nothing is tweened round: the land is laid out again at
## once and comes back in out of a short dip. A preference of this screen,
## not kept: it opens at no turn.
func turn_view() -> void:
	var under: Vector2 = life.tile_at(_cam)
	var going: Vector2 = life.tile_at(_cam_to)
	_let_go()
	life.set_turn(int(life.turn) + 1)
	_cam = life.seen(under)
	_cam_to = life.seen(going)
	_cam_raw = _cam_to
	_place_world()
	Motion.stop(_turn_tw)
	_turn_tw = Motion.appear(world, 0.3, 1.0, 0.16)

## The view goes to show plate `p`.
func look_at_plate(p: Vector2i) -> void:
	_cam_raw = life.plus_at(p)
	_cam_to = _cam_raw

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
	for step: Array in [
			[Diagram.Lesson.TREE, "TUT_FACTORY_TREE", "TUT_FACTORY_TREE_BODY"],
			[Diagram.Lesson.BELT, "TUT_FACTORY_BELT", "TUT_FACTORY_BELT_BODY"],
			[Diagram.Lesson.PLATE, "TUT_FACTORY_PLATE", "TUT_FACTORY_PLATE_BODY"]]:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": tr(step[2])})
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

# --- time ---

func _process(delta: float) -> void:
	if sim == null or _left:
		return
	sim.step(delta)
	_play_events()
	_step_hand(delta)
	_step_view(delta)
	life.ghosts = _ghosts()
	life.step(delta)
	for n: Dictionary in _nums:
		n.t += delta
	_nums = _nums.filter(func(n: Dictionary) -> bool: return n.t < NUM)
	_warn = maxf(0.0, _warn - delta)
	_ghost_wob += delta
	_refresh_hud(delta)
	if _card_tick.is_valid() and _card.visible:
		_card_tick.call()
	_since_save += delta
	if sim.dirty and _since_save >= SAVE_GAP:
		_save()
	_over_l.queue_redraw()

func _play_events() -> void:
	for e: Dictionary in sim.events:
		life.event(e)
		match String(e.type):
			"chop":
				# the hand's log is heard; the forest's own, a second apart, only just
				if e.auto:
					_quiet.cue("chop", 0.9 * _vary(), -10.0)
				else:
					_fx.cue("chop", _vary())
			"laid":
				_quiet.cue("chop", 0.84 * _vary(), -6.0)
			"turned":
				_quiet.cue("chop", 1.12 * _vary(), -6.0)
			"lit":
				_fx.cue("chop", 0.7, -2.0)
			"placed", "level":
				_fx.cue("buy")
			"built":
				_quiet.cue("buy", 1.0, -8.0)
			"sold_back":
				_fx.cue("buy", 0.9)
			"plate":
				_fx.cue("buy")
				look_at_plate(e.plate)
			"refused":
				_on_refused(String(e.why), e.tile)
	sim.events.clear()

## A sale's coin has come up out of the hatch (`life.coined`): a coin is
## heard, a real one dropped on felt in a wooden box, a little lower (the
## user, 2026-10-11, of the wallet's wooden tock there: "something that
## sound closer to a coin", and of a wooden run of notches: "not a general
## wood toc ... some coin clank ... in a cozier way"), never two inside
## COIN_GAP at a market that sells many a second, and the count is on its
## way up beside it.
func _on_coin(amount: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _coin_at >= COIN_GAP:
		_coin_at = now
		_coin_fx.cue("coin", COIN_PITCH * _vary(), COIN_DB)
	var hatch: Vector2 = life.seen(Vector2(Sim.MARKET_AT) + Life.MID) + Art.MARKET_TOP
	_nums.append({"at": hatch + Vector2(_rng.randf_range(40.0, 52.0), -30.0), "text": "+" + Art.short(amount), "t": 0.0})
	_kick()

## The sim did not do it. Most of the time that is a no: the thing shakes
## its head, and when it was the coins the pill does too.
func _on_refused(why: String, tile: Vector2i) -> void:
	if QUIET.has(why):
		return
	_fx.cue("no")
	life.shake(tile)
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
	if _card_coins != null and is_instance_valid(_card_coins):
		_card_coins.text = text
	var key := "%d|%d|%d|%s" % [sim.coins, sim.plates.size(), int(sim.market.level), sim.picked]
	if key != _hud_key:
		_hud_key = key
		_refresh_drawer()

# --- the drawer ---

func _refresh_drawer() -> void:
	for kind: String in DRAWER_TILES:
		var t: Dictionary = _tiles[kind]
		if kind == "market":
			var cost: int = sim.upgrade_price("market")
			Tile.price(t, Art.short(cost), sim.coins >= cost)
			Tile.level(t, int(sim.market.level))
		else:
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

func _on_drawer_tile(kind: String) -> void:
	if kind == "market":
		if not sim.upgrade("market"):
			Motion.shiver(_tiles[kind].button, 6.0)
		else:
			Motion.bump(_tiles[kind].button, 0.05, 0.2)
		return
	pick(kind)
	close_drawer()

## What the hand lays now: "belt", a machine, or "" for nothing.
func pick(kind: String) -> void:
	sim.picked = kind
	_let_go()
	_refresh_drawer()

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

# --- the hand ---

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
	_vel = Vector2.ZERO
	_cam_raw = _cam
	_cam_to = _cam
	var picked: String = sim.picked
	if picked == "belt":
		_mode = "belt"
		_belt_tile = Vector2i(tile_under(pos).floor())
	elif picked != "":
		_mode = "place"
	else:
		_mode = "pan"
	if _mode != "place":
		var h := hit(pos)
		if h.what == "belt" or h.what == "module":
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
				_lay_run(_run_to(tile_under(pos)))
			else:
				_tap(pos)
			_run = {}
		"place":
			_place(pos)

## Every finger is let go: a card went up, the app lost the focus.
func _let_go() -> void:
	_touches.clear()
	_finger = NO_FINGER
	_mode = ""
	_long = {}
	_run = {}
	_cam_raw = _cam_to

## What is under a point of the field: {what, tile} and for a module its
## `id`, for a plus its `plate`. What stands is tried by its body, the
## nearest to the eye first (a crown is tapped a good way over its tile);
## then what lies flat on the tile under the point.
func hit(pos: Vector2) -> Dictionary:
	var v: Vector2 = (pos - world.position) / _zoom
	var best := {}
	var best_d := -INF
	for p: Vector2i in sim.forests:
		if (v - badge_at(p)).length() <= BADGE_R + 10.0:
			return {"what": "badge", "tile": p * Art.PLATE, "plate": p}
	for id: int in sim.trees:
		var tr: Dictionary = sim.trees[id]
		var tall: float = Art.height(tr.look)
		var wide: float = float(Art.RADIUS[int(tr.look)]) * Art.TREE_SCALE + 12.0
		var rel: Vector2 = v - (life.mid(tr.tile) - Vector2(0.0, tall * 0.5))
		if pow(rel.x / wide, 2.0) + pow(rel.y / (tall * 0.5 + 12.0), 2.0) > 1.0:
			continue
		var d: float = life.depth(Vector2(tr.tile) + Vector2(0.5, 0.5))
		if d > best_d:
			best_d = d
			best = {"what": "forest", "tile": tr.tile}
	# a building's body covers the ground behind it: the tiles a little
	# further down the screen are asked whose body this point is on
	for lift: float in [84.0, 56.0, 28.0, 0.0]:
		var t := Vector2i((life.tile_at(v + Vector2(0.0, lift)) as Vector2).floor())
		var found := {}
		if sim.is_market(t):
			found = {"what": "market", "tile": t}
		elif lift <= 56.0:
			var m: Dictionary = sim.module_at(t)
			if not m.is_empty():
				found = {"what": "module", "tile": m.root, "id": int(m.id)}
		var td: float = life.depth(Vector2(t) + Vector2(0.5, 0.5))
		if not found.is_empty() and td > best_d:
			best_d = td
			best = found
	if not best.is_empty():
		return best
	# a belt's bed stands over its tile: the bed under the point first
	var bed := Vector2i((life.tile_at(v - Art.BELT_LIFT) as Vector2).floor())
	if sim.belts.has(bed):
		return {"what": "belt", "tile": bed}
	var tile := Vector2i((life.tile_at(v) as Vector2).floor())
	if sim.belts.has(tile):
		return {"what": "belt", "tile": tile}
	for p: Vector2i in sim.free_edges():
		var rel: Vector2 = v - life.plus_at(p)
		if pow(rel.x / 104.0, 2.0) + pow(rel.y / (104.0 * Art.DEEP), 2.0) <= 1.0:
			return {"what": "plus", "tile": p * Art.PLATE, "plate": p}
	if sim.is_forest(tile):
		return {"what": "forest", "tile": tile}
	return {"what": "ground", "tile": tile}

## Where forest `p`'s badge floats, in view units: over the middle of it.
func badge_at(p: Vector2i) -> Vector2:
	return life.plus_at(p) + Vector2(0.0, -BADGE_UP)

func _tap(pos: Vector2) -> void:
	var h := hit(pos)
	var tile: Vector2i = h.tile
	match String(h.what):
		"forest":
			sim.tap(tile)
		"badge":
			open_forest(h.plate)
			_fx.touch()
		"module":
			var m: Dictionary = sim.modules[int(h.id)]
			if m.kind == "firebox" and m.built and not m.lit and not (m.hopper as Array).is_empty():
				sim.tap(tile)
			else:
				open_module(int(h.id))
				_fx.touch()
		"market":
			open_market()
			_fx.touch()
		"plus":
			open_plate(h.plate)
			_fx.touch()
		"belt":
			sim.turn(tile)
		"ground":
			if sim.picked == "belt" and sim.can_lay(tile):
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
			coins -= sim.price("belt")
		if coins >= 0:
			lay = tiles.size()
	if tiles.is_empty():
		return {}
	var swipe := Art.DIRS.find(step) if n > 0 else _facing
	return {"tiles": tiles, "lay": lay, "facing": run_facing(sim, tiles, swipe)}

## Whether the belt on `tile` hands on to something: a belt, the market, a
## fire box, or the way in of a kiln or a retort in front of it.
static func _feeds(land: RefCounted, tile: Vector2i) -> bool:
	return _takes(land, tile + Art.DIRS[int(land.belts[tile])])

## Whether `tile` is somewhere a belt may deliver into: the market, a fire
## box, the way in of a kiln or a retort.
static func _takes_in(land: RefCounted, tile: Vector2i) -> bool:
	if land.is_market(tile):
		return true
	var m: Dictionary = land.module_at(tile)
	return not m.is_empty() and (m.kind == "firebox" or m.root == tile)

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
## 1. the tile beyond it, along the line, is a belt pointing into it, or a
##    kiln or retort whose way out it is: the run flows AWAY from this end;
## 2. the tile beyond it is a belt that does not point into it, the market,
##    a fire box, or a kiln's or retort's way in: the run flows TOWARD it;
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
		var m: Dictionary = land.module_at(beyond)
		if not m.is_empty() and m.kind != "firebox" and land.out_tile(m) == e:
			return away
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
	for i in int(run.lay):
		var tile: Vector2i = tiles[i]
		if not sim.belts.has(tile):
			sim.lay_belt(tile, f)
		elif int(sim.belts[tile]) != f and (tiles.size() == 1 or (tile == source and not _feeds(sim, tile))):
			sim.lay_belt(tile, f)
	if int(run.lay) < tiles.size() and not sim.belts.has(tiles[int(run.lay)]):
		# the coins ran out along the way: the sim refuses the next and the pill says so
		sim.lay_belt(tiles[int(run.lay)], f)
	_facing = f

## The facing a machine picked would stand at on `tile`: the last belt's,
## or the next quarter it fits.
func _fit(kind: String, tile: Vector2i) -> int:
	for q in 4:
		var f := (_facing + q) % 4
		if sim.can_place(kind, tile, f):
			return f
	return _facing

func _place(pos: Vector2) -> void:
	var kind: String = sim.picked
	var tile := Vector2i(tile_under(pos).floor())
	if sim.place(kind, tile, _fit(kind, tile)):
		pick("")
	else:
		_ghost_wob = 0.0

## The ghost of a machine held over the land: its footprint, green where it
## fits and the coins reach, and it shivers when a release placed nothing.
func _ghosts() -> Array:
	if _mode == "belt" and not _run.is_empty():
		return _run_ghosts()
	if _mode != "place" or _finger == NO_FINGER:
		return []
	var kind: String = sim.picked
	var tile := Vector2i(tile_under(_at).floor())
	var f := _fit(kind, tile)
	# the footprint as it is seen: a machine of two tiles lies the other way a quarter on
	var foot: Array = Life.footprint(kind, life.seen_tile(tile), life.seen_facing(f))
	var ok: bool = sim.can_place(kind, tile, f) and sim.coins >= sim.price(kind)
	var shift := Vector2(Motion.shiver_offset(_ghost_wob, 0.06, 0.3), 0.0)
	return [[Art.ghost(foot[1].x, foot[1].y, ok), Art.flat(Vector2(foot[0] as Vector2i) + shift)]]

## The run a swipe would lay, as beds on their way: paper where a belt will
## go, the warn tone past what the coins reach, nothing over a belt that is
## there already.
func _run_ghosts() -> Array:
	var out: Array = []
	var tiles: Array = _run.tiles
	var lift := Transform2D(0.0, Art.BELT_LIFT)
	for i in tiles.size():
		var tile: Vector2i = tiles[i]
		if sim.belts.has(tile):
			continue
		var short: bool = i >= int(_run.lay)
		out.append([Art.belt(), lift * Art.flat(Vector2(life.seen_tile(tile)), life.seen_facing(int(_run.facing))),
			Color(1.0, 0.5, 0.45, 0.8) if short else Color(1.0, 1.0, 1.0, 0.92)])
	return out

## A finger held still on a belt or a machine sells it back.
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

# --- the cards ---

func card_open() -> bool:
	return _card.visible

func close_card() -> void:
	_card.visible = false
	_card_tick = Callable()
	_card_for = ""
	for c in _card_slot.get_children():
		_card_slot.remove_child(c)
		c.queue_free()

## A card on the scrim: its head (the title, the coins held, an X) and what
## `fill(col)` puts under it.
func _open_card(title: String, what: String, fill: Callable) -> void:
	close_card()
	close_drawer()
	_let_go()
	_card_for = what
	var card := Dialog.card(CARD_W, CARD_INSET)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var title_l := Label.new()
	title_l.theme_type_variation = "SheetTitle"
	title_l.text = title
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_l.clip_text = true
	head.add_child(title_l)
	var pill := PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 12))
	var held := HBoxContainer.new()
	held.add_theme_constant_override("separation", 10)
	pill.add_child(held)
	held.add_child(Tile.coin(46.0))
	_card_coins = Label.new()
	_card_coins.theme_type_variation = "SheetTitle"
	_card_coins.text = _coins_l.text
	held.add_child(_card_coins)
	head.add_child(pill)
	var x := IconButton.new("cross", "", "IconButton")
	x.name = "Close"
	x.custom_minimum_size = Vector2(Dialog.X_SIZE, Dialog.X_SIZE)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_round(x, int(Dialog.X_SIZE * 0.5))
	x.pressed.connect(close_card)
	head.add_child(x)
	col.add_child(head)
	fill.call(col)
	_card_slot.add_child(card)
	_card.visible = true
	Motion.appear(_card, 0.0, 1.0, 0.2)

## The plate card: the two kinds, each a tile with its picture, its name,
## a line and the price on its bar. Pressing one buys the plate at `p`.
func open_plate(p: Vector2i) -> void:
	_open_card(tr("FACTORY_PLATE_TITLE"), "plate", func(col: VBoxContainer) -> void:
		var row := HBoxContainer.new()
		row.name = "Kinds"
		row.add_theme_constant_override("separation", 16)
		col.add_child(row)
		var made := {}
		for kind: String in Sim.KINDS:
			var t := Tile.make(kind, NAMES[kind], PLATE_TILE, 70.0, 64.0, NAMES[kind] + "_LINE")
			(t.button as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			(t.button as Button).pressed.connect(func() -> void:
				if sim.buy_plate(p, kind):
					close_card()
				else:
					Motion.shiver(t.button, 6.0))
			row.add_child(t.button)
			made[kind] = t
		_card_tick = func() -> void:
			for kind: String in made:
				Tile.price(made[kind], Art.short(sim.plate_price()), sim.coins >= sim.plate_price())
		_card_tick.call())

## A machine's card: its picture, what it makes from what, its cycle at the
## heat it has now, its level and the next one's price where it has levels,
## Turn for a machine of two tiles, and Sell for all that was paid.
func open_module(id: int) -> void:
	if not sim.modules.has(id):
		return
	var kind: String = sim.modules[id].kind
	_open_card(tr(NAMES[kind]), "module", func(col: VBoxContainer) -> void:
		var lines := _card_body(col, kind, [tr(NAMES[kind] + "_MAKES"), "", tr("FACTORY_RETORT_NOTE") if kind == "retort" else ""])
		var row := HBoxContainer.new()
		row.name = "Buttons"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		col.add_child(row)
		var up: Button = null
		if kind == "firebox":
			up = _card_button(row, "trend", "", "PrimaryButton")
			up.pressed.connect(func() -> void:
				if not sim.upgrade(sim.modules[id].root):
					Motion.shiver(up, 6.0))
		else:
			_card_button(row, "turn", tr("FACTORY_TURN"), "IconButton").pressed.connect(func() -> void: sim.turn(sim.modules[id].root))
		var sell := _card_button(row, "coin", "", "IconButton")
		sell.pressed.connect(func() -> void:
			var root: Vector2i = sim.modules[id].root
			close_card()
			sim.sell(root))
		_card_tick = func() -> void:
			if not sim.modules.has(id):
				close_card()
				return
			var m: Dictionary = sim.modules[id]
			(lines[1] as Label).text = _state_line(m)
			_say(sell, tr("FACTORY_SELL_FOR") % Art.short(sim.sell_price(m.root)))
			if up != null:
				var cost: int = sim.upgrade_price(m.root)
				up.visible = cost >= 0
				if cost >= 0:
					_say(up, tr("FACTORY_LEVEL_FOR") % [int(m.level) + 1, Art.short(cost)])
				(lines[2] as Label).text = tr("FACTORY_FIRE_LEVEL") % [int(m.level), int(m.cap)]
		_card_tick.call())

## A forest's card: what a tap gives, what it makes by itself, what it holds
## of what it can, and the next level's price. Nothing else is done to a
## forest: it is not built in, turned or sold.
func open_forest(p: Vector2i) -> void:
	if not sim.forests.has(p):
		return
	_open_card(tr("FACTORY_FOREST"), "forest", func(col: VBoxContainer) -> void:
		var lines := _card_body(col, "forest", [tr("FACTORY_FOREST_MAKES"), "", ""])
		var row := HBoxContainer.new()
		row.name = "Buttons"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(row)
		var up := _card_button(row, "trend", "", "PrimaryButton")
		up.pressed.connect(func() -> void:
			if not sim.upgrade(p * Art.PLATE):
				Motion.shiver(up, 6.0))
		_card_tick = func() -> void:
			var f: Dictionary = sim.forests[p]
			var rate := int(sim.forest_rate(p))
			(lines[1] as Label).text = tr("FACTORY_FOREST_HAND") if rate == 0 else (tr("FACTORY_FOREST_RATE_ONE") if rate == 1 else tr("FACTORY_FOREST_RATE_N") % rate)
			(lines[2] as Label).text = tr("FACTORY_FOREST_HOLDS") % [int(f.stock), Sim.FOREST_ROOM]
			var cost: int = sim.upgrade_price(p * Art.PLATE)
			up.visible = cost >= 0
			if cost >= 0:
				if int(f.level) == 0:
					_say(up, tr("FACTORY_FOREST_AUTO_FOR") % Art.short(cost))
				else:
					_say(up, tr("FACTORY_LEVEL_FOR") % [int(f.level) + 1, Art.short(cost)])
		_card_tick.call())

## The market's card: its level, the seconds a sale, the next level's price.
func open_market() -> void:
	_open_card(tr("FACTORY_MARKET"), "market", func(col: VBoxContainer) -> void:
		var lines := _card_body(col, "market", [tr("FACTORY_MARKET_MAKES"), "", ""])
		var row := HBoxContainer.new()
		row.name = "Buttons"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(row)
		var up := _card_button(row, "trend", "", "PrimaryButton")
		up.pressed.connect(func() -> void:
			if not sim.upgrade("market"):
				Motion.shiver(up, 6.0))
		_card_tick = func() -> void:
			(lines[1] as Label).text = tr("FACTORY_MARKET_RATE") % _seconds(sim.market_interval())
			(lines[2] as Label).text = tr("FACTORY_LEVEL") % int(sim.market.level)
			_say(up, tr("FACTORY_LEVEL_FOR") % [int(sim.market.level) + 1, Art.short(sim.upgrade_price("market"))])
		_card_tick.call())

## A card's body: the picture on a disc at the left and three lines beside
## it (an empty one is hidden until it is written). Returns the lines.
func _card_body(col: VBoxContainer, kind: String, texts: Array) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(220, 220)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.draw.connect(func() -> void: Tile.picture(pic, kind, 104.0))
	row.add_child(pic)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 8)
	row.add_child(words)
	var lines := []
	for i in texts.size():
		var l := Label.new()
		l.theme_type_variation = "SheetBody" if i < 2 else "SheetBodyDim"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = texts[i]
		words.add_child(l)
		lines.append(l)
	return lines

## A button on a card's row, at its own size.
func _card_button(row: HBoxContainer, icon: String, text: String, look: String) -> Button:
	var b := IconButton.new(icon, text, look)
	b.custom_minimum_size = Vector2(430, 112)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	return b

## A button's words, written only when they change (it measures itself).
static func _say(b: Button, text: String) -> void:
	if (b as IconButton).label_text != text:
		(b as IconButton).set_label(text)

## What a machine is doing now, in a line.
func _state_line(m: Dictionary) -> String:
	if not m.built:
		return tr("FACTORY_BUILDING") % int(float(m.build) * 100.0)
	if m.kind == "firebox":
		var held: int = (m.hopper as Array).size()
		if m.lit:
			return tr("FACTORY_FIRE_LIT") % [int(round(float(m.draw))), int(m.cap), held]
		return tr("FACTORY_FIRE_TAP") if held > 0 else tr("FACTORY_FIRE_EMPTY")
	var secs: float = sim.cycle_seconds(m)
	if secs < 0.0:
		return tr("FACTORY_NEEDS_FIRE")
	return tr("FACTORY_CYCLE") % _seconds(secs)

## Seconds as the card writes them: "4 s", "2.5 s", "3 min 50 s".
func _seconds(secs: float) -> String:
	if secs >= 60.0:
		var whole := int(round(secs))
		@warning_ignore("integer_division")
		return tr("FACTORY_MIN_S") % [whole / 60, whole % 60]
	return tr("FACTORY_S") % Art.amount(snappedf(secs, 0.1), Art.comma())

# --- drawing ---

## Over the land and moving with it: the ghost's machine, the ring of a
## finger held on something it would sell, and what a sale was worth.
func _draw_over(ci: CanvasItem) -> void:
	if _mode == "place" and _finger != NO_FINGER:
		var kind: String = sim.picked
		var tile := Vector2i(tile_under(_at).floor())
		var f := _fit(kind, tile)
		var vf: int = life.seen_facing(f)
		var mesh: ArrayMesh = Art.firebox() if kind == "firebox" else (Art.kiln(vf) if kind == "kiln" else Art.retort(vf))
		ci.draw_mesh(mesh, null, Transform2D(0.0, life.mid(tile) + Vector2(Motion.shiver_offset(_ghost_wob, 5.0, 0.3), 0.0)), Color(1.0, 1.0, 1.0, 0.6))
	if _mode == "belt" and not _run.is_empty():
		_draw_flow(ci)
	if not _long.is_empty() and _held >= HOLD_SHOWS:
		var k := clampf((_held - HOLD_SHOWS) / (HOLD - HOLD_SHOWS), 0.0, 1.0)
		ci.draw_set_transform(life.mid(_long.tile), 0.0, Vector2(1.0, Art.DEEP))
		ci.draw_arc(Vector2.ZERO, 74.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.35), 9.0, true)
		ci.draw_arc(Vector2.ZERO, 74.0, -PI * 0.5, -PI * 0.5 + TAU * k, 48, Pal.ACCENT, 9.0, true)
		ci.draw_set_transform(Vector2.ZERO)
	var font := get_theme_font("font", "SheetTitle")
	for p: Vector2i in sim.forests:
		_draw_badge(ci, font, p)
	for n: Dictionary in _nums:
		var k: float = float(n.t) / NUM
		var w := font.get_string_size(n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
		var at: Vector2 = (n.at as Vector2) + Vector2(-w * 0.5, 0.0 if Motion.reduce else -k * 60.0)
		var a := 1.0 - k * k * k
		ci.draw_string_outline(font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, 8, Color(0.23, 0.19, 0.16, 0.7 * a))
		ci.draw_string(font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(Art.MARK, a))

## A forest's badge: a round sign over it with an arrow up, the sun's own
## when the coins reach the next level and paper when they do not, the price
## under it; at the last level a plain one with its level. A tap opens the
## forest's card.
func _draw_badge(ci: CanvasItem, font: Font, p: Vector2i) -> void:
	var at := badge_at(p)
	var cost: int = sim.upgrade_price(p * Art.PLATE)
	var can: bool = cost >= 0 and sim.coins >= cost
	var ink := Color(0.23, 0.19, 0.16)
	ci.draw_circle(at + Vector2(0.0, 5.0), BADGE_R, Color(ink, 0.28))
	ci.draw_circle(at, BADGE_R, Pal.SUN if can else Art.PRICE_OFF)
	ci.draw_arc(at, BADGE_R, 0.0, TAU, 40, Color(ink, 0.5), 3.0, true)
	if cost < 0:
		var top := str(int(sim.forests[p].level))
		ci.draw_string(font, at + Vector2(-font.get_string_size(top, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x * 0.5, 16.0), top, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, ink)
		return
	var arrow := Color(ink, 0.9 if can else 0.5)
	ci.draw_polyline(PackedVector2Array([at + Vector2(-17.0, 2.0), at + Vector2(0.0, -17.0), at + Vector2(17.0, 2.0)]), arrow, 8.0, true)
	ci.draw_line(at + Vector2(0.0, -13.0), at + Vector2(0.0, 21.0), arrow, 8.0, true)
	var text := Art.short(cost)
	var foot := at + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x * 0.5, BADGE_R + 40.0)
	ci.draw_string_outline(font, foot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, 8, Color(ink, 0.7))
	ci.draw_string(font, foot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.WHITE)

## The direction reference line of a run being swiped: a soft line along
## its beds and a chevron a tile pointing the way things will move, the last
## one a full arrowhead. Drawn, not lettered: the fonts have no arrow.
func _draw_flow(ci: CanvasItem) -> void:
	var tiles: Array = _run.tiles
	var f: int = _run.facing
	var d := Vector2(Art.DIRS[f])
	var pts := PackedVector2Array()
	for tile: Vector2i in tiles:
		pts.append(life.mid(tile) + Art.BELT_LIFT)
	# the way of the flow on the screen, and half a tile of it
	var half: Vector2 = (life.seen(Vector2(tiles[0]) + Vector2(0.5, 0.5) + d * 0.5) + Art.BELT_LIFT) - pts[0]
	var way := half.normalized()
	var across := Vector2(-way.y, way.x)
	var first := pts[0]
	var last := pts[pts.size() - 1]
	if (last - first).dot(way) < 0.0:
		first = last
		last = pts[0]
	var line := PackedVector2Array([first - half * 0.7, last + half * 0.7])
	var ink := Color(0.23, 0.19, 0.16, 0.45)
	ci.draw_polyline(line, ink, 13.0, true)
	ci.draw_polyline(line, Color(1.0, 1.0, 1.0, 0.92), 6.0, true)
	for i in pts.size():
		var p := pts[i]
		var head := p == last
		var size := 1.5 if head else 1.0
		var c: Vector2 = p + (half * 0.7 if head else Vector2.ZERO)
		var arrow := PackedVector2Array([c - way * 13.0 * size + across * 15.0 * size, c + way * 5.0 * size, c - way * 13.0 * size - across * 15.0 * size])
		ci.draw_polyline(arrow, ink, 13.0, true)
		ci.draw_polyline(arrow, Color(1.0, 1.0, 1.0, 0.95) if not head else Pal.SUN, 6.0, true)

# --- leaving ---

func _save() -> void:
	if sim == null or _left:
		return
	sim.save()
	_since_save = 0.0

## The land is kept and the screen stops stepping it before it says it is
## closed: from here on it is the tab's again.
func _on_back() -> void:
	sim.picked = ""
	_save()
	_left = true
	set_process(false)
	Analytics.track("factory_leave", {"seconds": int((Time.get_ticks_msec() - _opened_at) / 1000.0),
		"earned": sim.earned - _earned_at_open, "plates": sim.plates.size()})
	closed.emit()

## Android's back, through the menu: a card or a sheet first, then the
## drawer, what is picked, and the screen.
func go_back() -> void:
	if tutor.close():
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	if _card.visible:
		close_card()
		return
	if _drawer.visible:
		close_drawer()
		return
	if sim.picked != "":
		pick("")
		return
	_on_back()
