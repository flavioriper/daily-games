extends Control

## One page of Factory's tutorial (factory/screen.gd's `tutorial_pages`): the
## robot floor drawn by the game's own path (factory/life.gd), played by the
## game's own sim (factory/sim.gd) and, on the pages that change a program,
## the program sheet drawn small beside it (factory/sheet.gd's preview), with
## a finger that does what the page says. Every page plays on a sim of its
## own, so it never touches the player's floor. `lesson` picks the page, set
## before it enters the tree:
##
## - POWER: the floor as it opens, the three robots out on their loops and
##   the three faults showing; a finger taps the Picker.
## - TURN (shown second, made last so the pages' keys kept their numbers):
##   the Picker's program with its first Turn in the middle; the finger
##   rests on the Turn as the Picker, at the intake, turns toward the table,
##   ringed on the floor. No edit.
## - PICKER: its program on the sheet, a Gripper fitted and a Pick inserted
##   after its first Move; the Picker then walks off with a square.
## - BOXER: the stack its gripper falls a tile short of ringed on the
##   floor, and its first Move set to 2 on the sheet; the Picker is already
##   fixed.
## - SHIPPER: its loose wire dragged from the Pick onto the Turn after it;
##   the Picker and the Boxer are already fixed.
## - BOX: all three fixed, the floor run to a few seconds before the first
##   sale; the box pays, the coins count it, the Shipper pauses on the bay.
## - SPEND: the bin's parts on the sheet with the second milestone's rows
##   priced; a finger buys the Fast plug.
##
## A page starts over every LENGTH seconds on a floor of the same seed, so it
## is the same little film each time. Under reduce motion it stands still at
## its telling moment (STILL): the fault in view and the finger on what to
## change, before the edit lands.

const Sim = preload("res://factory/sim.gd")
const Art = preload("res://factory/art.gd")
const Life = preload("res://factory/life.gd")
const Sheet = preload("res://factory/sheet.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { POWER, PICKER, BOXER, SHIPPER, BOX, SPEND, TURN }
## The order the pages are shown in.
const ORDER := [Lesson.POWER, Lesson.TURN, Lesson.PICKER, Lesson.BOXER, Lesson.SHIPPER, Lesson.BOX, Lesson.SPEND]

const SEED := 7
const LENGTH := {Lesson.POWER: 9.0, Lesson.PICKER: 10.0, Lesson.BOXER: 10.0, Lesson.SHIPPER: 10.0, Lesson.BOX: 13.0, Lesson.SPEND: 7.0,
	Lesson.TURN: 5.5}
const STILL := {Lesson.POWER: 5.0, Lesson.PICKER: 1.6, Lesson.BOXER: 1.6, Lesson.SHIPPER: 1.6, Lesson.BOX: 5.5, Lesson.SPEND: 1.6,
	Lesson.TURN: 2.05}
## The moment a page's edit lands (Picker's fit and Pick, Boxer's Moves,
## Shipper's wire, Spend's purchase), in seconds into the page.
const EDIT := 2.0
## The pages that draw a sheet beside the floor, and the robot it shows, and
## the node it brings to its middle.
const SHEETS := {Lesson.PICKER: [0, "a"], Lesson.BOXER: [1, "a"], Lesson.SHIPPER: [2, "g"], Lesson.SPEND: [0, "a"],
	Lesson.TURN: [0, "b"]}
## The Turn page's moment: the Picker's first Turn runs from about 1.9 s to
## 2.2 s on the page's floor (ticks 19 to 22), ringed from TURN_RING on.
const TURN_RING := Vector2(1.5, 3.2)
## How much of the page's height the room takes when a sheet shares it
## (the room is wide and low since 2026-10-22, so the sheet goes under it,
## not beside it), and how tall the sheet is in its own pixels before it is
## scaled to fit the rest (the bin's page needs the taller sheet, for its
## tray under the parts); it is drawn as wide as that scale lets it.
const ROOM_SHARE := 0.4
const SHEET_TALL := 800.0
const SHEET_TALL_TRAY := 960.0
const PAD := 14.0
## Ticks run before a page opens, so the fault it is about already shows:
## the Boxer has reached for the stack and missed, the Shipper stands with
## its "?".
const WARM := {Lesson.BOXER: 40, Lesson.SHIPPER: 40}
## How many seconds before the first sale the BOX page opens.
const BOX_LEAD := 4.5
const SPEND_COINS := 100
## The stack the Boxer falls short of, ringed on its page.
const STACK: Vector2i = Sim.STATIONS.stack

## Tick of the first sale once the three faults are fixed (found once).
static var _sale_tick := -1

var lesson: int = Lesson.POWER

var _sim: RefCounted
var _life: RefCounted
var _world: Node2D
var _sheet: Control
var _over: Control
var _t := 0.0
var _done := 0
var _stood := false
var _sheet_rect := Rect2()
## The finger: where it is (the page's pixels), how long ago it pressed and
## whether it is on show; a wire dragged from `_drag_from` when it is set.
var _finger := Vector2.ZERO
var _pressed := 10.0
var _shows := false
var _drag_from := Vector2.INF
## The coins as the chip counts them, and when they last changed.
var _count := 0.0
var _coined := -10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_life = Life.new()
	# the ground edge to edge, as on the screen: no water (2026-10-21)
	_life.margin = Life.GROUND
	_start()
	_world = _life.mount(self, _sim)
	if SHEETS.has(lesson):
		_sheet = Sheet.new()
		_sheet.name = "Sheet"
		add_child(_sheet)
	_over = Control.new()
	_over.name = "Over"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_over)
	add_child(_over)
	resized.connect(_layout)
	_layout()
	_open_sheet()
	if Motion.reduce:
		set_process(false)
		# stands up at its moment once it has a size (a card may size it later)
		if size.x > 0.0 and size.y > 0.0:
			_stand()

## The corner the robots work in (`work_bounds`) fitted to the page's share
## for it, the outside round it edge to edge; the sheet's rect under it.
func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var room := Rect2(Vector2.ZERO, size)
	_sheet_rect = Rect2()
	if SHEETS.has(lesson):
		var h := roundf(size.y * ROOM_SHARE)
		room = Rect2(0.0, 0.0, size.x, h)
		_sheet_rect = Rect2(PAD, h, size.x - 2.0 * PAD, size.y - h - PAD)
	var box: Rect2 = _life.work_bounds()
	var u := minf((room.size.x - 2.0 * PAD) / box.size.x, (room.size.y - 2.0 * PAD) / box.size.y)
	_world.scale = Vector2(u, u)
	_world.position = room.get_center() - box.get_center() * u
	# a corner narrower than its share stands at the share's left, the
	# room's floor going on to the right, not the outside round it
	if box.size.x * u < room.size.x - 2.0 * PAD:
		_world.position.x = room.position.x + PAD - box.position.x * u
	_open_sheet()
	queue_redraw()
	if Motion.reduce:
		_stand()

## Under reduce motion: plays to STILL once, and on any later layout puts the
## finger and the ring where the new layout has them.
func _stand() -> void:
	if not _stood:
		_stood = true
		_advance(float(STILL[lesson]))
	else:
		_act()
		_over.queue_redraw()

## The sheet drawn into its rect on the sim as it stands.
func _open_sheet() -> void:
	if _sheet == null or _sheet_rect.size.x <= 0.0:
		return
	var row: Array = SHEETS[lesson]
	_sheet.setup(_sim, null)
	var tray := lesson == Lesson.SPEND
	var tall := SHEET_TALL_TRAY if tray else SHEET_TALL
	_sheet.show_preview(int(row[0]), _sheet_rect, _sheet_rect.size.x * tall / maxf(_sheet_rect.size.y, 1.0), String(row[1]), tray)

## The page's floor, as it opens: the faults other pages fixed are fixed, the
## ticks it needs already run.
func _start() -> void:
	_t = 0.0
	_done = 0
	_pressed = 10.0
	_shows = false
	_drag_from = Vector2.INF
	_sim = Sim.new(SEED)
	var warm: int = WARM.get(lesson, 0)
	match lesson:
		Lesson.BOXER:
			_fix_picker(_sim)
		Lesson.SHIPPER:
			_fix_picker(_sim)
			_fix_boxer(_sim)
		Lesson.BOX:
			_fix_picker(_sim)
			_fix_boxer(_sim)
			_fix_shipper(_sim)
			warm = maxi(0, first_sale() - roundi(BOX_LEAD / Sim.TICK))
		Lesson.SPEND:
			_fix_picker(_sim)
			_fix_boxer(_sim)
			_fix_shipper(_sim)
			_sim.milestone = 1
			_sim.coins = SPEND_COINS
	for i in warm:
		_sim.step(Sim.TICK)
		_sim.events.clear()
	_sim.events.clear()
	_count = float(_sim.coins)
	_coined = -10.0
	if _world != null:
		_life.hold(_sim)
		_open_sheet()

static func _fix_picker(sim: RefCounted) -> void:
	sim.fit(0, "gripper")
	sim.add_node(0, "a", "out", "pick")

static func _fix_boxer(sim: RefCounted) -> void:
	sim.set_move(1, "a", 2)

static func _fix_shipper(sim: RefCounted) -> void:
	sim.set_next(2, "g", "out", "h")

## The tick the first box is sold on once the three faults are fixed.
static func first_sale() -> int:
	if _sale_tick < 0:
		var sim := Sim.new(SEED)
		_fix_picker(sim)
		_fix_boxer(sim)
		_fix_shipper(sim)
		_sale_tick = 1200
		for i in 3000:
			sim.step(Sim.TICK)
			var sold := sim.events.any(func(e: Dictionary) -> bool: return String(e.type) == "sale")
			sim.events.clear()
			if sold:
				_sale_tick = int(sim.tick_n)
				break
	return _sale_tick

func _process(delta: float) -> void:
	_advance(minf(delta, 0.1))

func _advance(delta: float) -> void:
	var left := delta
	while left > 0.0:
		var dt := minf(left, 0.05)
		left -= dt
		_t += dt
		if _t >= float(LENGTH[lesson]):
			_start()
		_act()
		_pressed += dt
		var coins := int(_sim.coins)
		_sim.step(dt)
		if int(_sim.coins) != coins:
			_coined = _t
		_count = float(_sim.coins) if Motion.reduce else move_toward(_count, float(_sim.coins), 90.0 * dt)
		for e: Dictionary in _sim.events:
			_life.event(e)
			if _sheet != null:
				_sheet.event(e)
		_sim.events.clear()
		_life.step(dt)
	if _over != null:
		_over.queue_redraw()

# --- what the finger does ---

## A point of the floor's view space, in the page's pixels.
func _floor_px(v: Vector2) -> Vector2:
	return _world.position + v * _world.scale.x

## A point of the sheet's pixels, in the page's pixels.
func _sheet_px(v: Vector2) -> Vector2:
	return _sheet.position + v * _sheet.scale.x

## A point part way along `keys` ([[seconds, point], ...]) at `_t`, eased
## between one key and the next.
func _along(keys: Array) -> Vector2:
	if _t <= float(keys[0][0]):
		return keys[0][1]
	for k in range(1, keys.size()):
		if _t <= float(keys[k][0]):
			var a: Array = keys[k - 1]
			var b: Array = keys[k]
			var f := smoothstep(0.0, 1.0, (_t - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])))
			return (a[1] as Vector2).lerp(b[1], f)
	return keys[keys.size() - 1][1]

## Presses the finger once, `at` seconds in.
func _press(at: float, slot: int) -> void:
	if _done <= slot and _t >= at:
		_done = slot + 1
		_pressed = 0.0

func _act() -> void:
	match lesson:
		Lesson.POWER:
			# the Picker is tapped as its fault shows
			_shows = _t > 3.6 and _t < 7.6
			_finger = _floor_px(_life.robot_at(0) + Vector2(0.0, -40.0))
			_press(5.0, 0)
		Lesson.PICKER:
			if _t < EDIT:
				_finger = _along([[0.3, _sheet_px(_sheet.plus_rect("a").get_center()) + Vector2(60.0, 50.0)], [1.4, _sheet_px(_sheet.plus_rect("a").get_center())]])
			_shows = _t > 0.3 and _t < 3.2
			_press(1.5, 0)
			_edit(func() -> void: _fix_picker(_sim))
		Lesson.TURN:
			var turn := _sheet_px(_sheet.node_rect("b").get_center())
			_finger = _along([[0.4, turn + Vector2(60.0, 50.0)], [1.3, turn]])
			_shows = _t > 0.4 and _t < 3.4
			_press(1.5, 0)
		Lesson.BOXER:
			if _t < EDIT:
				var move := _sheet_px(_sheet.node_rect("a").get_center())
				_finger = _along([[0.3, move + Vector2(60.0, 50.0)], [1.2, move]])
			_shows = _t > 0.3 and _t < 3.2
			_press(1.5, 0)
			_edit(func() -> void: _fix_boxer(_sim))
		Lesson.SHIPPER:
			if _t < EDIT:
				var from := _sheet_px(_sheet.out_port("g"))
				var to := _sheet_px(_sheet.in_port("h"))
				_finger = _along([[0.3, from + Vector2(60.0, 50.0)], [0.8, from], [1.0, from], [1.9, to]])
				_drag_from = from if _t >= 1.0 else Vector2.INF
			else:
				_drag_from = Vector2.INF
			_shows = _t > 0.3 and _t < 3.2
			_press(0.9, 0)
			_edit(func() -> void: _fix_shipper(_sim))
		Lesson.SPEND:
			if _t < EDIT:
				var chip := _sheet_px(_sheet.tray_rect("plug").get_center())
				_finger = _along([[0.3, chip + Vector2(60.0, 50.0)], [1.2, chip]])
			_shows = _t > 0.3 and _t < 3.2
			_press(1.5, 0)
			_edit(func() -> void: _sim.fit(0, "plug"))

## Makes the page's edit as EDIT passes, once.
func _edit(change: Callable) -> void:
	if _t >= EDIT and _done < 8:
		_done = 8
		change.call()
		_pressed = 0.0

# --- drawing over the floor ---

func _draw_over() -> void:
	if lesson == Lesson.BOXER and _t < 4.5:
		_draw_ring(_floor_px(_life.mid(STACK)))
	if lesson == Lesson.TURN and _t > TURN_RING.x and _t < TURN_RING.y:
		_draw_ring(_floor_px(_life.robot_pos(0)))
	if _drag_from != Vector2.INF:
		var pts := PackedVector2Array([_drag_from, _finger])
		_over.draw_polyline(pts, Color(Pal.ACCENT, 0.85), 5.0, true)
	if _shows:
		var down := 1.0 - clampf(_pressed / 0.3, 0.0, 1.0)
		var r := 28.0 - 7.0 * down
		_over.draw_circle(_finger, r, Color(1.0, 1.0, 1.0, 0.35 + 0.3 * down), true, -1.0, true)
		_over.draw_arc(_finger, r, 0.0, TAU, 40, Color(0.23, 0.19, 0.16, 0.7), 4.0, true)
		_over.draw_circle(_finger, 8.0, Pal.ACCENT, true, -1.0, true)
	if lesson == Lesson.BOX or lesson == Lesson.SPEND:
		_draw_chip()

## A ring that breathes round a tile of the floor.
func _draw_ring(at: Vector2) -> void:
	var u: float = _world.scale.x
	var pulse := 0.0 if Motion.reduce else 0.5 + 0.5 * sin(_t * TAU / 1.1)
	var r := Art.TILE.x * u * (0.62 + 0.1 * pulse)
	_over.draw_circle(at, r, Color(Pal.ACCENT, 0.16), true, -1.0, true)
	_over.draw_arc(at, r, 0.0, TAU, 40, Pal.ACCENT, 5.0, true)

## The coins held, as the screen's pill shows them: the coin and the count
## on a white pill, kicked as it changes.
func _draw_chip() -> void:
	var font := get_theme_font("font", "SheetTitle")
	var text := Art.amount(roundf(_count), Art.comma())
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	var h := 62.0
	var w := 14.0 + 46.0 + 10.0 + tw + 20.0
	var grow := 1.0
	if not Motion.reduce:
		grow += 0.14 * maxf(0.0, 1.0 - (_t - _coined) / 0.4)
	var box := Rect2(Vector2(16.0, 16.0), Vector2(w, h))
	_over.draw_set_transform(Vector2(16.0, 16.0 + h * 0.5), 0.0, Vector2(grow, grow))
	var local := Rect2(Vector2(0.0, -h * 0.5), box.size)
	var face := StyleBoxFlat.new()
	face.bg_color = Pal.SURFACE
	face.set_corner_radius_all(int(h * 0.5))
	face.shadow_color = Color(0.23, 0.19, 0.16, 0.18)
	face.shadow_size = 6
	face.shadow_offset = Vector2(0.0, 3.0)
	_over.draw_style_box(face, local)
	_over.draw_mesh(Art.icon("coin"), null, Transform2D(0.0, Vector2(0.5, 0.5), 0.0, Vector2(14.0 + 23.0, 0.0)))
	_over.draw_string(font, Vector2(14.0 + 46.0 + 10.0, 12.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Pal.TEXT)
	_over.draw_set_transform(Vector2.ZERO)
