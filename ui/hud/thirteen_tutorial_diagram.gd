extends Control

## One page of Lucky Thirteen's tutorial: a small tray played by the screen
## itself. The page holds a `Tray` -- arcade/thirteen_screen.gd with its top
## bar, score row, sounds, knocks, records and cards taken out, showing only
## the last three rows of the tray (`_rows`; the rows above wait over the top
## edge and fall in, as new pebbles do) -- on a `Tide`, the game's own sim
## with a tray laid by hand and the pebbles that roll in named. A finger
## plays it through the screen's own input: the chain lifts and wears its
## ribbon, the pebbles roll into the last one, the tray settles, the thirteen
## is revealed, the stuck card comes up, a tool is armed and used, exactly
## as in a game. `lesson` picks the page (set before it enters the tree):
##
## - CHAIN: drag through three touching pebbles of a number (a diagonal among
##   them) and let go; then a chain of four.
## - LAST: the chain ends beside two of the next number, three times over,
##   and the tray falls in behind it.
## - GOAL: three twelves make the thirteen; the clovers it pays land in the
##   bank.
## - STUCK: the last move, the stuck card, and a Swap that frees the tray.
## - TOOLS: Pluck, Lift, Shuffle and Undo, each bought and used, its price
##   climbing.
## - HUD: the top bar's Restart, the two boosters and the Second chance,
##   drawn as they are beside what they do.
##
## Under reduce motion a page is its lesson's telling moment, standing still.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://arcade/thirteen_sim.gd")
const Boosters = preload("res://arcade/boosters.gd")
const BoosterIcon = preload("res://arcade/booster_icon.gd")

enum Lesson { CHAIN, LAST, GOAL, STUCK, TOOLS, HUD }

## The tray is laid out this wide, the screen's own width inside its margins,
## and scaled onto the page: the chips and the card keep their proportions.
## Wider with the tools under it, so the short field left over them has the
## room the stuck card and the thirteen's reveal need.
const WIDE := 1000.0
const WIDE_TOOLS := 1150.0
## How long an armed tool's line stays over the tray: the finger waits for it.
const LINE := 1.5
const FINGER_R := 40.0
const FINGER_ALPHA := 0.16
## How long a tap's finger stays down.
const TAP_DOWN := 0.14
## Seconds a cell of a drag, and a hover from one spot to the next.
const DRAG := 0.28
const HOVER := 0.5

var lesson: int = Lesson.CHAIN

var _art: Tray
var _over: Control
var _icons: Array = []
var _begun := false
var _stilled := false
## The lesson: [kind, argument, seconds] in order. "go" carries the finger to
## a cell (Vector2i) or a tool (int), dragging when it is down on the tray;
## "down" and "up" press and let go; "rest" waits; "away" takes the finger
## off; "still" is where a page under reduce motion stops.
var _steps: Array = []
var _i := 0
var _t := 0.0
var _from := Vector2.ZERO
var _finger := Vector2.ZERO
var _target = null
var _shown := false
var _down := false
var _on_tray := false
var _finger_mesh: ArrayMesh
var _hud_mesh: ArrayMesh

## The screen, quiet: only the tray in its frame (and the clovers and tools
## under it when `tools_shown`), no sound, no knock, nothing saved, no card
## but the stuck one.
class Tray extends "res://arcade/thirteen_screen.gd":
	const ROWS_SHOWN := 3

	var tools_shown := false

	## The game with the tray laid by hand: the pebbles that roll in come
	## from `feed`, in turn.
	class Tide extends "res://arcade/thirteen_sim.gd":
		var feed: Array = []
		var _fed := 0

		func _spawn_value() -> int:
			if feed.is_empty():
				return super()
			_fed += 1
			return int(feed[(_fed - 1) % feed.size()])

	## The settings sheet the screen asks before it takes a touch.
	class NoSheet extends Control:
		func is_open() -> bool:
			return false

	func puzzle_id() -> String:
		return "thirteen_tutorial"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		_build()
		# the card is the paper; the bar and the score row stay off the page
		(get_child(0) as Control).visible = false
		_backdrop.visible = false
		var col: Control = _margins.get_child(0)
		top_bar.visible = false
		(col.get_child(1) as Control).visible = false
		(col.get_node("Tools") as Control).visible = tools_shown
		settings_sheet = NoSheet.new()
		settings_sheet.visible = false
		add_child(settings_sheet)
		_fx.buzzes = false
		_air_fx.buzzes = false

	## No safe area on a page: only room for the frame's shadow.
	func _apply_insets() -> void:
		_margins.add_theme_constant_override("margin_left", 8)
		_margins.add_theme_constant_override("margin_right", 8)
		_margins.add_theme_constant_override("margin_top", 4)
		_margins.add_theme_constant_override("margin_bottom", 16)

	func _rows() -> int:
		return ROWS_SHOWN

	func _process(delta: float) -> void:
		super(delta)
		# no move is shown to a page left alone: the finger knows its own
		_idle = 0.0

	## Where a thing off the page would be: over its top edge.
	func _in_air(c: Control, at: Vector2) -> Vector2:
		if not c.is_visible_in_tree():
			return Vector2(_air.size.x * 0.5, -160.0)
		return super(c, at)

	## A word under a sunburst is lettered for the whole screen: on a page
	## the thirteen's reveal says it alone.
	func _sticker(text: String, at: Vector2, size: int, life: float, rainbow := true, col := Color.WHITE, rays := false, id := "") -> void:
		if not rays:
			super(text, at, size, life, rainbow, col, rays, id)

	func _new_game() -> void:
		pass

	func _ask(_by_hand := true) -> void:
		pass

	func _offer_chance() -> bool:
		return false

	## A page's tray never ends: no record, no gold, no card.
	func _game_over() -> void:
		_disarm()
		_dragging = false
		_stuck_box.visible = false

	func _on_back() -> void:
		pass

	func _on_reset() -> void:
		pass

	## A tray laid by hand, at rest: `rows` top to bottom, each COLS numbers.
	func lay(rows: Array, clovers: int, feed: Array) -> void:
		var tide := Tide.new(0)
		tide.feed = feed
		for c in Sim.COLS:
			for r in Sim.ROWS:
				tide.grid[c][r] = {"id": tide._new_id(), "v": int(rows[r][c])}
		tide.max_v = tide._biggest()
		tide.clovers = clovers
		tide.events.clear()
		sim = tide
		_wipe()
		Motion.stop(_banner_tw)
		(_banner.get_meta("box") as Control).modulate.a = 0.0
		for c in Sim.COLS:
			for r in Sim.ROWS:
				var cell: Dictionary = tide.grid[c][r]
				_vis[cell.id] = _new_vis(Vector2(c, r), int(cell.v))
		# a tray laid with no move in it says so
		tide._check()
		_refresh_hud()
		_play_events()

	## A touch on the tray at `at`, in the field's pixels: down (1), moved (0)
	## or up (-1), through the screen's own input.
	func poke(at: Vector2, kind: int) -> void:
		if kind == 0:
			var move := InputEventMouseMotion.new()
			move.position = at
			_on_field_input(move)
			return
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = kind > 0
		press.position = at
		_on_field_input(press)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if lesson == Lesson.HUD:
		for id: String in Boosters.of("thirteen") + [Boosters.CHANCE]:
			var icon := BoosterIcon.new(id)
			add_child(icon)
			_icons.append(icon)
	else:
		_art = Tray.new()
		_art.tools_shown = lesson in [Lesson.GOAL, Lesson.STUCK, Lesson.TOOLS]
		add_child(_art)
		# over the tray: the finger, and a stop for any touch on the page
		_over = Control.new()
		_over.mouse_filter = Control.MOUSE_FILTER_STOP
		_over.draw.connect(_draw_finger)
		add_child(_over)
	resized.connect(_layout)
	call_deferred("_layout")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun:
		call_deferred("_reset")

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if lesson == Lesson.HUD:
		queue_redraw()
		return
	var wide := WIDE_TOOLS if _art.tools_shown else WIDE
	var k := size.x / wide
	_art.position = Vector2.ZERO
	_art.scale = Vector2(k, k)
	_art.size = Vector2(wide, floorf(size.y / k))
	_over.position = Vector2.ZERO
	_over.size = size
	if not _begun and is_inside_tree():
		_begun = true
		_reset()

# --- the lessons ---

static func _tap() -> Array:
	return [["down"], ["rest", TAP_DOWN], ["up"]]

## A chain drawn through `cells` and let go, then `rest` seconds for the tray
## to settle. `still` marks the chain held as the page's standing picture.
static func _chain(cells: Array, rest: float, still := false) -> Array:
	var out: Array = [["go", cells[0], HOVER], ["down"]]
	for k in range(1, cells.size()):
		out.append(["go", cells[k], DRAG])
	out.append(["rest", 0.35])
	if still:
		out.append(["still"])
	out.append(["up"])
	out.append(["rest", rest])
	return out

## The lesson from its top: the tray laid, the finger off the page.
func _reset() -> void:
	if lesson == Lesson.HUD or not is_inside_tree() or size.x <= 0.0:
		return
	var T := Sim.Tool
	var rows: Array = []
	var feed: Array = []
	var clovers: int = Sim.START_CLOVERS
	_steps = [["rest", 0.5]]
	match lesson:
		Lesson.CHAIN:
			rows = [[4, 3, 4, 3, 4], [3, 4, 3, 4, 3], [1, 4, 3, 5, 4],
				[3, 1, 4, 3, 1], [2, 2, 1, 1, 4], [4, 3, 2, 1, 3]]
			feed = [4, 3, 5, 4, 3, 5]
			_steps += _chain([Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 5)], 1.2, true)
			_steps += _chain([Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(3, 5)], 1.7)
		Lesson.LAST:
			rows = [[3, 1, 5, 2, 1], [1, 2, 1, 3, 5], [6, 1, 6, 2, 2],
				[5, 1, 5, 1, 5], [2, 2, 3, 4, 1], [1, 2, 3, 5, 4]]
			feed = [1, 3, 2, 6, 1, 3]
			_steps += _chain([Vector2i(0, 4), Vector2i(1, 5), Vector2i(1, 4)], 1.0, true)
			_steps += _chain([Vector2i(1, 5), Vector2i(2, 5), Vector2i(2, 4)], 1.0)
			_steps += _chain([Vector2i(2, 5), Vector2i(3, 4), Vector2i(4, 5)], 1.6)
		Lesson.GOAL:
			var g: int = Sim.GOAL
			rows = [[g - 5, g - 3, g - 4, g - 6, g - 5], [g - 3, g - 6, g - 5, g - 3, g - 4], [g - 4, g - 5, g - 3, g - 6, g - 2],
				[g - 4, g - 3, g - 2, g - 3, g - 4], [g - 2, g - 1, g - 1, g - 3, g - 2], [g - 3, g - 2, g - 1, g - 4, g - 3]]
			feed = [g - 4, g - 5, g - 6, g - 4]
			_steps += _chain([Vector2i(1, 4), Vector2i(2, 4), Vector2i(2, 5)], 0.0, true)
			_steps += [["away"], ["rest", 5.4]]
		Lesson.STUCK:
			# every pebble among neighbours of other numbers, but for the three
			# twos down the middle: the last move
			rows = _quiet_rows()
			# a three beside where the last chain ends, so the tray plays on
			rows[4][3] = 3
			feed = [2, 1, 5, 4, 1, 2]
			# a Swap and an Undo's worth, nothing dearer
			clovers = int(Sim.COSTS[T.SWAP]) + 5
			if Motion.reduce:
				rows[5][2] = 3
				_steps = [["still"]]
			else:
				rows[4][2] = 2
				_steps += _chain([Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5)], 0.0)
				_steps += [["away"], ["rest", 2.6], ["go", T.SWAP, HOVER + 0.1]] + _tap() + [["rest", LINE]]
				_steps += [["go", Vector2i(1, 4), HOVER]] + _tap() + [["rest", 0.3]]
				_steps += [["go", Vector2i(0, 3), HOVER - 0.1]] + _tap() + [["rest", 0.9]]
				_steps += _chain([Vector2i(0, 5), Vector2i(1, 4), Vector2i(2, 3)], 1.5)
		Lesson.TOOLS:
			rows = _quiet_rows()
			rows[3][0] = 3
			rows[3][1] = 2
			rows[3][2] = 3
			rows[4][3] = 2
			feed = [5, 4]
			clovers = 0
			for tool: int in [T.PLUCK, T.LIFT, T.SHUFFLE, T.UNDO]:
				clovers += int(Sim.COSTS[tool])
			clovers += 15
			_steps += [["go", T.PLUCK, HOVER]] + _tap() + [["still"], ["rest", LINE]]
			_steps += [["go", Vector2i(1, 4), HOVER]] + _tap() + [["rest", 1.1]]
			_steps += [["go", T.LIFT, HOVER]] + _tap() + [["rest", LINE]]
			_steps += [["go", Vector2i(2, 4), HOVER]] + _tap() + [["rest", 1.0]]
			_steps += [["go", T.SHUFFLE, HOVER]] + _tap() + [["rest", 1.4]]
			_steps += [["go", T.UNDO, HOVER]] + _tap() + [["rest", 1.6]]
	_i = 0
	_t = 0.0
	_shown = false
	_down = false
	_on_tray = false
	_target = null
	_stilled = false
	_art.lay(rows, clovers, feed)
	_over.queue_redraw()

## A tray with no three of a number touching: two numbers down every even
## column, two others down every odd one.
static func _quiet_rows() -> Array:
	var rows: Array = []
	for r in Sim.ROWS:
		var row: Array = []
		for c in Sim.COLS:
			row.append([[1, 2], [4, 5]][c % 2][r % 2])
		rows.append(row)
	return rows

func _process(delta: float) -> void:
	if lesson == Lesson.HUD or not _begun or _art.field.size.x <= 0.0:
		return
	if Motion.reduce:
		if not _stilled:
			_stilled = true
			_stand()
			_over.queue_redraw()
		return
	_play(delta)
	_over.queue_redraw()

## The finger, a step at a time; the lesson again once it is through.
func _play(delta: float) -> void:
	while true:
		if _i >= _steps.size():
			_reset()
			return
		var s: Array = _steps[_i]
		match String(s[0]):
			"go":
				if _t == 0.0:
					# it comes onto the page from under it
					_from = _finger if _shown else Vector2(size.x * 0.5, size.y + FINGER_R * 2.0)
					_shown = true
				_t += delta
				var k := minf(1.0, _t / float(s[2]))
				var e := k if _down else k * k * (3.0 - 2.0 * k)
				_finger = _from.lerp(_spot(s[1]), e)
				if _on_tray:
					_art.poke(_to_field(_finger), 0)
				if k < 1.0:
					return
				_target = s[1]
			"down":
				# a tray still settling takes no touch
				if _art.busy():
					return
				_press()
			"up":
				_lift()
			"rest":
				_t += delta
				if _t < float(s[1]):
					return
			"away":
				_shown = false
		_i += 1
		_t = 0.0
		delta = 0.0

## Under reduce motion: the lesson run at once as far as its `still`.
func _stand() -> void:
	for s: Array in _steps:
		match String(s[0]):
			"go":
				_shown = true
				_finger = _spot(s[1])
				_target = s[1]
				if _on_tray:
					_art.poke(_to_field(_finger), 0)
			"down":
				_press()
			"up":
				_lift()
			"away":
				_shown = false
			"still":
				return

func _press() -> void:
	_down = true
	if _target is Vector2i:
		_on_tray = true
		_art.poke(_to_field(_finger), 1)
	else:
		_art._on_tool(int(_target))

func _lift() -> void:
	if _on_tray:
		_art.poke(_to_field(_finger), -1)
	_down = false
	_on_tray = false

## Where the finger goes for a cell of the tray or a tool's chip, on the page.
func _spot(target) -> Vector2:
	if target is Vector2i:
		return _to_page(_art.field, _art.px(target.x, target.y))
	var chip: Control = _art._tool_buttons[int(target)]
	return _to_page(chip, chip.size * Vector2(0.5, 0.42))

func _to_page(c: Control, at: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * (c.get_global_transform() * at)

func _to_field(at: Vector2) -> Vector2:
	return _art.field.get_global_transform().affine_inverse() * (get_global_transform() * at)

# --- drawing ---

func _draw_finger() -> void:
	if not _shown:
		_finger_mesh = null
		return
	var b := Face.Builder.new()
	var r := FINGER_R * (0.85 if _down else 1.0)
	b.disc(_finger, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
	b.stroke(Face.Builder.ring(_finger, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_mesh = b.mesh()
	_over.draw_mesh(_finger_mesh, null)

## The HUD page: the top bar's Restart, the two boosters of the card before a
## run and the Second chance, each as it is on the screen beside what it
## does.
func _draw() -> void:
	if lesson != Lesson.HUD or size.x <= 0.0:
		return
	var lines := [tr("TUT_THIRTEEN_HUD_RESET"), tr("TUT_THIRTEEN_HUD_BOOST") % Boosters.LT_CLOVERS, tr("TUT_THIRTEEN_HUD_CHANCE")]
	var row_h := size.y / lines.size()
	var chip := minf(104.0, row_h * 0.72)
	var x0 := 36.0
	var wide := chip * 2.1
	# Restart's chip, as the top bar wears it
	var r := Rect2(Vector2(x0 + (wide - chip) * 0.5, row_h * 0.5 - chip * 0.5), Vector2(chip, chip))
	var b := Face.Builder.new()
	b.polygon(Face.Builder.round_rect(r.position + Vector2(0, 6.0), r.size, 26.0), Color(Pal.TEXT, 0.16))
	b.polygon(Face.Builder.round_rect(r.position, r.size, 26.0), Pal.SURFACE)
	_hud_mesh = b.mesh()
	draw_mesh(_hud_mesh, null)
	Icons.paint(self, "reset", Rect2(r.get_center() - Vector2(chip, chip) * 0.27, Vector2(chip, chip) * 0.54), Pal.TEXT)
	# the boosters side by side, the Second chance alone
	var side := chip * 0.94
	for k in _icons.size():
		var icon: Control = _icons[k]
		icon.size = Vector2(side, side)
		var cx := x0 + wide * (0.5 if k == 2 else 0.25 + 0.5 * k)
		icon.position = Vector2(cx - side * 0.5, row_h * ((1.5 if k < 2 else 2.5)) - side * 0.5)
	var font: Font = CozyTheme.display(700)
	var tx := x0 + wide + 28.0
	for k in lines.size():
		var room := size.x - tx - 24.0
		var tall := font.get_multiline_string_size(lines[k], HORIZONTAL_ALIGNMENT_LEFT, room, 30).y
		draw_multiline_string(font, Vector2(tx, row_h * (k + 0.5) - tall * 0.5 + 30.0 * 0.82), lines[k], HORIZONTAL_ALIGNMENT_LEFT, room, 30, -1, Pal.TEXT)
