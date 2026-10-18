extends Control

## One page of Tally's tutorial: the paper played by the game itself. The
## page holds the game's own board (arcade/tally_board.gd) on a sim of its
## own (arcade/tally_sim.gd), never saved, with numbers written near the box
## for the page, and a finger that goes from square to square along the
## page's script and presses, drags and lifts through the board as a
## player's would. The tool in hand is a chip in the corner. `lesson` picks
## the page (set before it enters the tree):
##
## - DIG: the Dig tool taps a 1 (its ghost and the builder pill come up),
##   the finger presses Place, then the Belt tool traces a path from the dig
##   to the box, and the 1s ride in.
## - BOX: the box asks for 1s; the tokens it wants wear a sun ring, a 3s
##   line comes in plain; ten 1s finish the level and the adder is handed
##   over.
## - MACHINE: the adder's ghost (four squares) is dropped facing north, Turn
##   faces it east, Place sets it down, and 3 into the back of its A square
##   and 4 into the back of its B square make 7.
## - BELTS: the 2s line ends on the 1s line and joins it, the two taking
##   turns, and a path traced across the 1s line makes a crossing; its loose
##   end goes as far as its last square's middle.
## - UPGRADE: the 1s coming in fill the belt's upgrade (drawn as the
##   upgrades card draws a row); the finger presses Up and the belts run
##   twice as fast.
##
## A keyframe's point is a square (Vector2) or a pill button's name
## ("place", "turn"), found through the board's `pill_button_rect` as the
## finger goes, so the script presses the pill where the board puts it.

const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")
const Sim = preload("res://arcade/tally_sim.gd")
const Art = preload("res://arcade/tally_art.gd")
const Board = preload("res://arcade/tally_board.gd")

enum Lesson { DIG, BOX, MACHINE, BELTS, UPGRADE }

## The squares seen across the page, and where the page looks. The box
## stands on (57, 57) to (62, 62); a dig covers the squares round its number.
const ACROSS := 13.0
const LOOK := {Lesson.DIG: Vector2(54.6, 59.4), Lesson.BOX: Vector2(54.8, 60.0), Lesson.MACHINE: Vector2(53.0, 59.2),
	Lesson.BELTS: Vector2(52.4, 58.6), Lesson.UPGRADE: Vector2(54.6, 59.6)}
## Each lesson's finger: [second, square (its middle is + 0.5), down].
const SCRIPTS := {
	Lesson.DIG: [[0.0, Vector2(54.5, 63.5), false], [0.8, Vector2(50.5, 59.5), false], [1.0, Vector2(50.5, 59.5), true], [1.15, Vector2(50.5, 59.5), false],
		[1.7, "place", false], [1.85, "place", true], [2.0, "place", false],
		[2.8, Vector2(51.5, 59.5), false], [3.0, Vector2(51.5, 59.5), true], [3.9, Vector2(56.5, 59.5), true], [4.05, Vector2(56.5, 59.5), false],
		[4.7, Vector2(54.5, 63.5), false]],
	Lesson.BOX: [[0.0, Vector2(54.5, 64.0), false]],
	Lesson.MACHINE: [[0.0, Vector2(51.5, 63.5), false], [0.8, Vector2(55.5, 58.5), false], [1.0, Vector2(55.5, 58.5), true], [1.15, Vector2(55.5, 58.5), false],
		[1.9, "turn", false], [2.05, "turn", true], [2.2, "turn", false],
		[3.0, "place", false], [3.15, "place", true], [3.3, "place", false], [4.1, Vector2(51.5, 63.5), false]],
	Lesson.BELTS: [[0.0, Vector2(46.5, 62.5), false], [3.4, Vector2(50.5, 57.5), false], [3.6, Vector2(50.5, 57.5), true], [4.6, Vector2(50.5, 61.5), true], [4.75, Vector2(50.5, 61.5), false],
		[5.4, Vector2(46.5, 62.5), false]],
	Lesson.UPGRADE: [[0.0, Vector2(54.0, 64.0), false]],
}
## When the tool in hand changes: [second, tool].
const TOOLS := {
	Lesson.DIG: [[0.0, "dig"], [2.5, "belt"]],
	Lesson.BOX: [[0.0, "move"]],
	Lesson.MACHINE: [[0.0, "add"]],
	Lesson.BELTS: [[0.0, "belt"]],
	Lesson.UPGRADE: [[0.0, "move"]],
}
const LENGTHS := {Lesson.DIG: 10.0, Lesson.BOX: 9.0, Lesson.MACHINE: 10.0, Lesson.BELTS: 10.0, Lesson.UPGRADE: 9.5}

var lesson: int = Lesson.DIG

var _board: Control
var _over_l: Control
var _sim: RefCounted
var _begun := false
var _t := 0.0
var _down := false
var _font: Font
var _tool_i := 0
var _said := ""
var _said_at := -10.0
var _bought_at := -10.0
var _press_at := -10.0
## The upgrade page: the finger goes to Up once the row is met.
var _up_t := -1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_font = CozyTheme.display(700)
	_board = Board.new()
	_board.interactive = false
	_board.font = _font
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)
	_over_l = Control.new()
	_over_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over_l.draw.connect(_draw_over)
	add_child(_over_l)
	resized.connect(_layout)
	call_deferred("_layout")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun:
		call_deferred("_reset")

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_board.position = Vector2.ZERO
	_board.size = size
	_board.set_view(Rect2(Vector2.ZERO, size))
	_board.k = size.x / ACROSS
	_board.look_at_square(LOOK[lesson], true)
	_over_l.size = size
	if not _begun:
		_reset()

## A dig written straight onto the paper, past the ladder's rules.
func _dig(t: Vector2i, v: int) -> void:
	_sim.dep[Sim._i(t)] = v
	_sim._stamp(Sim.DIG, t, 0)

func _run(a: Vector2i, b: Vector2i, f: int) -> void:
	var tiles := []
	var t := a
	while true:
		tiles.append(t)
		if t == b:
			break
		t += Sim.DIRS[f]
	_sim.lay_run(tiles, f)

func _reset() -> void:
	_begun = true
	_t = 0.0
	_down = false
	_tool_i = 0
	_said = ""
	_said_at = -10.0
	_bought_at = -10.0
	_press_at = -10.0
	_up_t = -1.0
	_sim = Sim.new(9)
	_sim.dep.fill(0)
	match lesson:
		Lesson.DIG:
			_sim.lv.belt = 3
			_sim.dep[Sim._i(Vector2i(50, 59))] = 1
			_sim.dep[Sim._i(Vector2i(52, 63))] = 1
			_sim.dep[Sim._i(Vector2i(53, 55))] = 2
		Lesson.BOX:
			_sim.lv.belt = 3
			_sim.got = 5
			_dig(Vector2i(50, 58), 1)
			_dig(Vector2i(50, 62), 3)
			_sim._wire()
			_run(Vector2i(52, 58), Vector2i(56, 58), 0)
			_run(Vector2i(52, 62), Vector2i(56, 62), 0)
		Lesson.MACHINE:
			_sim.level = 2
			_sim.lv.belt = 3
			_sim.lv.add = 8
			# 3 and 4 come round to where the adder's A and B squares will be;
			# its answer squares' belts lead into the box
			_dig(Vector2i(49, 57), 3)
			_dig(Vector2i(49, 61), 4)
			_sim._wire()
			_sim.lay_path([Vector2i(51, 57), Vector2i(52, 57), Vector2i(52, 58), Vector2i(53, 58)], 0)
			_sim.lay_path([Vector2i(51, 61), Vector2i(52, 61), Vector2i(52, 60), Vector2i(52, 59), Vector2i(53, 59)], 0)
			_run(Vector2i(56, 58), Vector2i(56, 58), 0)
			_run(Vector2i(56, 59), Vector2i(56, 59), 0)
		Lesson.BELTS:
			_sim.level = 6
			_sim.lv.belt = 3
			_dig(Vector2i(47, 59), 1)
			_dig(Vector2i(54, 55), 2)
			_dig(Vector2i(49, 55), 3)
			_sim._wire()
			_run(Vector2i(49, 59), Vector2i(56, 59), 0)
			# the 2s come down onto the line and join it: they take turns
			_sim.lay_path([Vector2i(54, 57), Vector2i(54, 58), Vector2i(54, 59)], 1)
		Lesson.UPGRADE:
			_sim.level = 2
			_sim.ledger[1] = 36
			_dig(Vector2i(51, 57), 1)
			_dig(Vector2i(51, 61), 1)
			_sim._wire()
			_run(Vector2i(53, 57), Vector2i(56, 57), 0)
			_run(Vector2i(53, 61), Vector2i(56, 61), 0)
	_sim.events.clear()
	_board.sim = _sim
	_board.place_face = 3 if lesson == Lesson.MACHINE else 0
	_board.set("_printed_at", -1)
	_board.relay()
	_board.set_tool(String(TOOLS[lesson][0][1]))

## The finger's keyframes: the page's script, or the upgrade's, made once
## the row is met.
func _script() -> Array:
	if lesson != Lesson.UPGRADE:
		return SCRIPTS[lesson]
	var rest := Vector2(52.5, 63.5)
	if _up_t < 0.0:
		return [[0.0, rest, false]]
	var up: Vector2 = _board.squares_at(_up_button().get_center())
	return [[0.0, rest, false], [_up_t + 0.7, up, false], [_up_t + 0.9, up, true], [_up_t + 1.1, up, false], [_up_t + 1.9, rest, false]]

func _process(delta: float) -> void:
	if _sim == null or not is_visible_in_tree():
		return
	_t += delta
	if _t >= float(LENGTHS[lesson]):
		_reset()
		return
	var tools: Array = TOOLS[lesson]
	while _tool_i + 1 < tools.size() and float(tools[_tool_i + 1][0]) <= _t:
		_tool_i += 1
		_board.set_tool(String(tools[_tool_i][1]))
	if lesson == Lesson.UPGRADE and _up_t < 0.0 and _sim.can_buy("belt"):
		_up_t = _t
	var script := _script()
	var at := 0
	while at + 1 < script.size() and float(script[at + 1][0]) <= _t:
		at += 1
	var pos: Vector2 = _point(script[at][1])
	if at + 1 < script.size():
		var u := clampf((_t - float(script[at][0])) / maxf(0.01, float(script[at + 1][0]) - float(script[at][0])), 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		pos = pos.lerp(_point(script[at + 1][1]), u)
	var down := bool(script[at][2])
	if lesson == Lesson.UPGRADE:
		if down and not _down:
			_press_at = _t
			if _sim.buy("belt"):
				_bought_at = _t
	elif down and not _down:
		_press_at = _t
		_board.press(pos)
	elif down:
		_board.drag(pos)
	elif _down:
		_board.release(pos)
	_down = down
	_finger = pos if script.size() > 1 else Vector2.INF
	_sim.step(delta)
	for ev: Dictionary in _sim.events:
		_board.play(ev)
		if String(ev.type) == "unlock" and int(ev.reward) > 0:
			_said = tr("TL_NEW_PIECE") % tr("TL_PIECE_" + String(Sim.KIND_IDS[int(ev.reward)]).to_upper())
			_said_at = _t
	_sim.events.clear()
	_board.tick(delta)
	_over_l.queue_redraw()

var _finger := Vector2.INF
var _last_point := Vector2.ZERO

## A keyframe's point in page pixels: a square's, or a pill button's middle
## (the board's pixels are the page's: it fills it). A button not up yet
## keeps the finger where it was.
func _point(p) -> Vector2:
	if p is String:
		var r: Rect2 = _board.pill_button_rect(String(p))
		if r.size == Vector2.ZERO:
			return _last_point
		_last_point = r.position + Vector2(r.size.x * 0.5, Board.BTN * 0.5)
		return _last_point
	_last_point = _board.screen_of(p)
	return _last_point

## The upgrade row's button, in page pixels.
func _up_button() -> Rect2:
	var row := _up_row()
	return Rect2(Vector2(row.end.x - 128.0, row.position.y + (row.size.y - 64.0) * 0.5), Vector2(112.0, 64.0))

func _up_row() -> Rect2:
	return Rect2(Vector2(20.0, size.y - 136.0), Vector2(size.x - 40.0, 120.0))

func _text(s: String, at: Vector2, fs: int, col: Color, centre := false) -> void:
	var x := at.x
	if centre:
		x -= _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5
	_over_l.draw_string(_font, Vector2(x, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _draw_over() -> void:
	if _sim == null:
		return
	# the tool in hand
	var tool: String = _board.tool
	var chip := Vector2(58.0, 58.0)
	_over_l.draw_circle(chip + Vector2(0, 4.0), 40.0, Color(Pal.TEXT, 0.16), true, -1.0, true)
	_over_l.draw_circle(chip, 40.0, Color("fcf7ef"), true, -1.0, true)
	var kd := int(Board.TOOL_KINDS.get(tool, -1))
	if kd >= 0:
		_over_l.draw_mesh(Art.icon(kd), null, Transform2D(0.0, Vector2.ONE * 0.6, 0.0, chip))
	else:
		_over_l.draw_circle(chip, 14.0, Pal.TEXT_DIM, true, -1.0, true)
	_text(tr("TL_TOOL_" + tool.to_upper()), chip + Vector2(52.0, 10.0), 28, Pal.TEXT)
	if lesson == Lesson.UPGRADE:
		_draw_row()
	if _said != "" and _t - _said_at < 2.6:
		var pop := 1.0 if Motion.reduce else Motion.bump_scale(_t - _said_at, 0.2, 0.22)
		_over_l.draw_set_transform(Vector2(size.x * 0.5, size.y * 0.2), 0.0, Vector2(pop, pop))
		_over_l.draw_string_outline(_font, Vector2(-size.x * 0.5, 0), _said, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, 10, Art.INK)
		_over_l.draw_string(_font, Vector2(-size.x * 0.5, 0), _said, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, Color("fff4c2"))
		_over_l.draw_set_transform(Vector2.ZERO)
	if _finger != Vector2.INF:
		var r := 30.0 if _down else 38.0
		_over_l.draw_circle(_finger + Vector2(0, 4.0), r, Color(Art.INK, 0.18), true, -1.0, true)
		_over_l.draw_circle(_finger, r, Color(1, 1, 1, 0.92), true, -1.0, true)
		_over_l.draw_circle(_finger, r * 0.62, Color(Pal.SUN, 0.9 if _down else 0.5), true, -1.0, true)

## The belt's upgrade as the upgrades card draws its row: the piece, the
## level and what the next does, the 1s held over the 1s asked, and Up.
func _draw_row() -> void:
	var row := _up_row()
	_over_l.draw_style_box(CozyTheme.lifted(Pal.SURFACE, 26, 8), row)
	_over_l.draw_mesh(Art.icon(Sim.BELT), null, Transform2D(0.0, Vector2.ONE * 0.8, 0.0, row.position + Vector2(62.0, row.size.y * 0.5)))
	var l := int(_sim.lv.belt)
	_text(tr("TL_TRACK_BELT"), row.position + Vector2(124.0, 36.0), 30, Pal.TEXT)
	var line := tr("TL_TRACK_LINE") % [l, tr("TL_PER_S") % str(int(Sim.speed_for("belt", l))), tr("TL_PER_S") % str(int(Sim.speed_for("belt", l + 1)))]
	_text(line, row.position + Vector2(124.0, 64.0), 20, Pal.ACCENT_2)
	var tok := row.position + Vector2(150.0, 94.0)
	_over_l.draw_mesh(Art.token(false), null, Transform2D(0.0, Vector2.ONE * 0.8, 0.0, tok))
	_text("1", tok + Vector2(0, 9.0), 26, Art.INK, true)
	var asks: Array = _sim.asks("belt")
	var need := int(asks[0][1]) if int(asks[0][0]) == 1 else 40
	var have: int = _sim.held(1)
	var count := "%d/%d" % [mini(have, need), need]
	_text(count, tok + Vector2(34.0, 9.0), 24, Color("4f8f45") if have >= need else Pal.TEXT_DIM)
	var b := _up_button()
	var met: bool = _sim.can_buy("belt")
	var press := 1.0 if Motion.reduce else Motion.bump_scale(_t - _press_at, 0.12, 0.2)
	var bb := Rect2(b.get_center() - b.size * 0.5 * press, b.size * press)
	_over_l.draw_style_box(CozyTheme.lifted(Pal.SUN if met or _t - _bought_at < 0.6 else Color(Pal.SUN, 0.45), 22, 0), bb)
	_text(tr("TL_BUY"), bb.get_center() + Vector2(0, 10.0), 28, Pal.TEXT, true)
	if _t - _bought_at < 2.2:
		_text(tr("TL_UPGRADED") % [tr("TL_TRACK_BELT"), l], Vector2(size.x * 0.5, row.position.y - 24.0), 30, Pal.ACCENT_DEEP, true)
