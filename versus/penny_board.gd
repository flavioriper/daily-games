extends Control

## Penny Drop's rack, seen from the front as it stands on the deck: a painted
## wooden face seven holes wide and six high on a wooden foot, the pennies
## showing through the holes. The player's pennies are the sun's (brass, a
## sun stamped on each), the other player's the moon's (a silvery blue, a
## crescent stamped on each), whichever of them drops first. Each side's
## pennies still to play lie in a roll of its own: the moon's above the rack,
## the sun's below it, by the thumb.
##
## The penny about to be dropped waits over the rack. A finger anywhere on a
## column brings it over that column and lights the column, since the thumb
## hides the holes it is on; letting go drops it. It falls behind the face,
## knocks once on what it lands on, and lies still.
##
## Everything that does not move is two baked meshes, the back and the face.
## A penny is one cached mesh a side, drawn under a transform wherever it is:
## lying in a hole, in its roll, waiting, falling. What changes shape (the
## column's light, the rings round a line) is one small mesh rebuilt only
## while it moves.
##
## The rolls lie in pine trays lined with the rack's own felt, baked into the
## back. The moments -- a knock, pennies of a side meeting, a line stopped, a
## slot filled, the four, a rack with no line, the waiting penny's life -- are
## the pennies' own transforms and soft round light in the mesh over the face,
## so none of them is a draw call; none of them runs under reduce motion.
##
## A trick is told as one too: a heavy penny breaks each penny under it out
## through the face (`play_heavy`), a spark burns down on a penny and those
## above it fall a place (`play_spark`), and the waiting penny wears what it is
## (`set_trick`).
##
## The board shows what it has been told (`play`, `rewind`), not the rules it
## was set up from, so a penny is in its hole only once it has landed.

## The player let go over a column that has room.
signal chosen(col: int)
## What was being shown has finished: the rack is set, a penny has landed, a
## penny taken back is out.
signal settled
## The finger crossed to another column.
signal moved
## A finger has come onto `col`, whose mark (penny_ai.gd's MARK_*) is `kind`.
signal peeked(col: int, kind: int)
## With a spark in hand, a penny of the other side's was touched.
signal aimed(cell: int)
## A heavy penny broke one more, this many so far; the hole it was in.
signal crushed_one(n: int, at: Vector2)
## A spark went off, at this point of the board.
signal sparked(at: Vector2)
## The column let go over is full.
signal refused(reason: String)

const Rules = preload("res://versus/penny_rules.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const AI = preload("res://versus/penny_ai.gd")

## A hole's pitch in the meshes' own space, whose origin is the top left of
## the grid of holes.
const U := 100.0
const GRID := Vector2(Rules.W * U, Rules.H * U)
## The frame round the grid, the foot's reach past the frame and its height.
const FRAME := 30.0
const FOOT_OUT := 30.0
const FOOT_H := 36.0
## A hole's radius and a penny's.
const HOLE_R := 41.0
const PENNY_R := 45.0
## Where the waiting penny hangs, and the middle of each roll.
const HOVER_Y := -74.0
const ROLL_R := 34.0
const ROLL_TOP_Y := -176.0
const ROLL_BOTTOM_Y := 708.0
## The space the rack takes, without its rolls and with them.
const SPACE := Rect2(-(FRAME + FOOT_OUT), -128.0, GRID.x + 2.0 * (FRAME + FOOT_OUT), 128.0 + 664.0)
const SPACE_ROLLS := Rect2(-(FRAME + FOOT_OUT), -216.0, GRID.x + 2.0 * (FRAME + FOOT_OUT), 216.0 + 748.0)

const PAINT := Color("4c9a94")
const PAINT_LIT := Color("6cb5ae")
const PAINT_DEEP := Color("357a75")
const INSIDE := Color("1f4f4c")
const WOOD := Color("b98457")
const WOOD_LIT := Color("d3a273")
const WOOD_DEEP := Color("7d5334")
## A penny's rim, face, shine and stamp, by look: the sun's, the moon's.
const RIM := [Color("c47f17"), Color("5767b4")]
const COIN := [Color("f4b23a"), Color("8c9ce4")]
const SHINE := [Color("ffd980"), Color("bcc7f6")]
const STAMP := [Color("d18d1c"), Color("6878c8")]
const HALO := Color("fff6e0")
const HINT := Color("f9c04a")

## Local units a second squared, and what a penny keeps of its speed when it
## knocks. Seconds: the look at a landing before the game goes on, a penny
## taken back, the rack emptied.
const GRAVITY := 4600.0
const BOUNCE := 0.24
const WATCH := 0.14
const REWIND := 0.22
const SPILL := 0.7
## What repeats is never the same sound twice (the cozy rules): the finger's
## tick, the penny let go, one taken back and a full column each play a
## little either way. They were 1.0 every time. `land` is pitched by its
## fall alone (1.08 down to 0.92), so it is left out.
const TICK_VARY := Vector2(0.94, 1.06)
const HOVER_SPEED := 14.0

## The trays the rolls lie in: how far past the grid they reach, their height.
const TRAY_OUT := 14.0
const TRAY_H := 92.0
const PINE := Color("e6c896")
const PINE_LIT := Color("f3ddb4")
const PINE_DEEP := Color("b88f5c")

## The heavy penny: how much harder it falls, what it keeps of its speed through
## each penny it breaks, how hard the rack shakes at each, and how a broken
## penny comes out through the face. The spark's fuse, its seconds.
const HEAVY_FALL := 1.5
const CRUSH_KEEP := 0.72
const QUAKE_PX := 9.0
const QUAKE_TIME := 0.34
const FLING_LIFE := 0.8
const FLING_GROW := 0.5
const FUSE := 0.34
const IRON := Color("5a5f6e")
const IRON_LIT := Color("8b91a3")
const IRON_DEEP := Color("3a3e4a")
const WARN := Color("e8603c")
const SAFE := Color("6fc7e8")

## --- the moments ---
## A knock: how far the pennies under it are driven (each `Motion.NUDGE_LAG`
## after the one above, and less), how far the face dips on its foot, how
## much the penny that knocked is squashed, and the light under it.
const KNOCK_PX := 5.0
const KNOCK_FADE := 0.8
const RACK_PX := 4.0
const SQUASH := 0.1
const KNOCK_LIGHT := 0.32
## Pennies of one side meeting: the light at each seam and the motes off it,
## the hop and the lean of the ones that answer, and the step from one seam
## to the next along a run of three.
const JOIN_TIME := 0.75
const JOIN_MOTES := 3
const JOIN_HOP := -6.0
const JOIN_LEAN := 0.16
const JOIN_STEP := 0.07
## A line of three stopped: the ring that closes on the penny that stopped it
## and the shiver of the three.
const BLOCK_TIME := 0.6
const BLOCK_PX := 3.0
## A slot filled to the top: its pennies settle and its frame glints.
const LID_TIME := 0.7
const LID_PX := 2.5
## The four: the step from one winner to the next, how often the light and
## the hop run the line again, and how far every other penny draws back into
## its hole (a ring of the dark inside round it, never a shade).
const RUN_STEP := 0.09
const RUN_EVERY := 1.7
const RUN_TRAVEL := 0.6
const STEP_BACK := 0.86
## A rack full with no line: every penny sinks once, a row after a row.
const SIGH_PX := 6.0
const SIGH_TIME := 0.7
const SIGH_STEP := 0.05
## A full slot tried: its pennies shiver.
const FULL_PX := 3.0
## The waiting penny: the flight from its roll and its swell on the way, how
## it leans the way it goes, and how often it rocks while it is the player's.
const FETCH := 0.28
const AIR := 0.14
const LEAN := 0.22
const BECKON := 2.6

var rules: RefCounted
## The rules' side the player is: its pennies are the sun's.
var player := 0
var interactive := false
## A picture, not a game (the Versus tab's card): drawn when asked, no input,
## no rolls, as wide as the control and standing on its bottom edge.
var still := false
## Whether the rolls of pennies still to play are drawn (not on a tutorial
## page).
var rolls := true
## A tutorial page's rack: it moves as a game's does, but hears no finger and
## makes no sound.
var deaf := false
## The rectangle the rack takes.
var used_rect := Rect2()

var _xf := Transform2D.IDENTITY
var _back: ArrayMesh
var _front: ArrayMesh
var _penny: Array[ArrayMesh] = []
var _glow: ArrayMesh
var _over_mesh: ArrayMesh
var _shown: Array = []
var _fx: Node2D
var _run := 0
var _t := 0.0
var _busy_until := 0.0
## What lies in each hole as shown: 0 empty, else a look plus one.
var _cells := PackedByteArray()
## Pennies in the air: {look, x, y, v, to, cell, hit, from, wait, spill}.
var _air: Array[Dictionary] = []
## A penny going back up: {look, x, from, at}.
var _back_up := {}
## The waiting penny: whose (-1 none), where it is and where it is going, in
## columns, and how much of it is there.
var _hover_look := -1
var _hover_x := 3.0
var _hover_to := 3.0
var _hover_a := 0.0
var _thinking := false
## The column under the finger (-1 none), and whether a finger is down.
var _over := -1
var _down := false
var _hint := -1
## What the waiting penny is: 0 plain, Rules.HEAVY or Rules.TWIN.
var _trick := 0
## With a spark in hand: whose pennies can be touched, -1 not aiming.
var _aim_look := -1
## What each slot would do, for the hand that is learning (`set_marks`).
var _marks := {}
## {at, cell}: a spark burning down, and pennies coming out through the face:
## {look, at, v, spin, turn, t}.
var _fuse := {}
var _flung: Array[Dictionary] = []
var _quake_at := -10.0
var _crushed := 0
var _landing_left := 0
var _iron: ArrayMesh
var _last := -1
var _line := PackedInt32Array()
## How the game ended, "" while it is on.
var _mood := ""
var _won_at := -1.0
var _shake_at := -10.0
var _shake_col := -1
## The moments, each by the clock it was set off on. The harness reads
## `moments` (a kind and when it last began) to shoot one while it shows.
var moments := {}
var _knock_at := -10.0
var _knock_col := -1
var _knock_row := -1
var _knock_k := 0.0
## Each {at, look, cells, k0, n}: a run of a side through the penny just
## landed, the cells in order along it, k0 the landed one's place in them.
var _joins: Array[Dictionary] = []
## {at, cell, cells}: the penny that stopped a line and the three it stopped.
var _block := {}
var _lid_at := -10.0
var _lid_col := -1
## The line's cells in order along it, and whether they are one straight run.
var _line_order := PackedInt32Array()
var _line_straight := false
var _fetch_at := -10.0
var _fetch_from := Vector2.ZERO
var _wait_at := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if still or deaf else Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	if not still and not deaf:
		_fx = Fx2D.new()
		add_child(_fx)
	_layout()

# --- setting up ---

## A rack showing `the_rules` as they stand, the player being `side`. With
## `enter`, whatever lay in the rack before falls out of it first, and
## `settled` is said once it is empty and ready.
func setup(the_rules: RefCounted, side: int, enter := false) -> void:
	_run += 1
	var old := _cells
	rules = the_rules
	player = side
	_cells = PackedByteArray()
	_cells.resize(Rules.CELLS)
	for c in Rules.CELLS:
		if rules.cells[c] != Rules.EMPTY:
			_cells[c] = look_of(rules.cells[c] - 1) + 1
	_air.clear()
	_flung.clear()
	_fuse = {}
	_trick = 0
	_aim_look = -1
	_marks = {}
	_landing_left = 0
	_back_up = {}
	_hover_look = -1
	_hover_a = 0.0
	_thinking = false
	_over = -1
	_down = false
	_hint = -1
	_last = -1
	_line = PackedInt32Array()
	_mood = ""
	_won_at = -1.0
	_calm()
	_fetch_at = -10.0
	var wait := 0.0
	if enter and not Motion.reduce and old.size() == Rules.CELLS:
		# The bar under the rack is drawn and everything in it drops out, the
		# bottom row first.
		var any := false
		for c in Rules.CELLS:
			if old[c] != 0:
				any = true
				var at := mid(c)
				_air.append({"look": old[c] - 1, "x": at.x, "y": at.y, "v": 0.0, "to": SPACE_ROLLS.end.y + 300.0,
					"cell": -1, "hit": true, "from": at.y, "wait": 0.03 * (c / Rules.W) + 0.012 * (c % Rules.W), "spill": true})
		if any:
			_cue("spill")
			wait = SPILL
	if enter:
		_after(wait + (0.05 if Motion.reduce else 0.25), func() -> void: settled.emit())
	_busy(wait + 0.4)
	_touch()

## The look of a rules' side: 0 the sun's (the player's), 1 the moon's.
func look_of(side: int) -> int:
	return 0 if side == player else 1

## The middle of a hole, in the meshes' space.
static func mid(c: int) -> Vector2:
	return Vector2((c % Rules.W + 0.5) * U, (Rules.H - (c / Rules.W) - 0.5) * U)

## A point of the meshes' space, in the board's own.
func point_of(p: Vector2) -> Vector2:
	return _xf * p

## Where a line of words can stand without hiding the rack: over the far
## roll.
func toast_point() -> Vector2:
	return _xf * Vector2(GRID.x * 0.5, ROLL_TOP_Y if rolls else HOVER_Y)

# --- what the screen tells it ---

## The penny of the rules' `side` is dropped, to land in `cell`.
func play(cell: int, side: int) -> void:
	var look := look_of(side)
	var to := mid(cell)
	_hint = -1
	_over = -1
	_down = false
	_thinking = false
	_hover_look = -1
	_hover_a = 0.0
	if Motion.reduce:
		_cells[cell] = look + 1
		_last = cell
		_cue("land", 1.0)
		_after(Motion.REDUCED_TIME, func() -> void: settled.emit())
		_touch()
		return
	_cue("drop", randf_range(TICK_VARY.x, TICK_VARY.y))
	_air.append({"look": look, "x": to.x, "y": HOVER_Y, "v": 0.0, "to": to.y, "cell": cell, "hit": false,
		"from": HOVER_Y, "wait": 0.0, "spill": false})
	_busy(2.0)

## The heavy penny of `side` goes down, breaking `crushed` (Rules.crushed), to
## lie in `cell`.
func play_heavy(cell: int, side: int, crushed: PackedInt32Array) -> void:
	var look := look_of(side)
	var to := mid(cell)
	_hint = -1
	_over = -1
	_down = false
	_thinking = false
	_hover_look = -1
	_hover_a = 0.0
	_trick = 0
	_crushed = 0
	if Motion.reduce:
		for x in crushed:
			_cells[x % Rules.CELLS] = 0
		_cells[cell] = look + 1
		_last = cell
		_cue("crush", 1.0)
		_after(Motion.REDUCED_TIME, func() -> void: settled.emit())
		_touch()
		return
	_cue("drop", 0.8)
	var rows := PackedInt32Array()
	for x in crushed:
		rows.append(x % Rules.CELLS)
	_air.append({"look": look, "x": to.x, "y": HOVER_Y, "v": 900.0, "to": to.y, "cell": cell, "hit": false,
		"from": HOVER_Y, "wait": 0.0, "spill": false, "heavy": rows})
	_mark("heavy")
	_busy(2.4)

## A spark burns down on the penny at `cell`, then `fell` (Rules.fell) move.
func play_spark(cell: int, fell: Array[Vector2i]) -> void:
	_hint = -1
	_over = -1
	_down = false
	_thinking = false
	_aim_look = -1
	_hover_look = -1
	_hover_a = 0.0
	var drop := func() -> void:
		_fuse = {}
		var look := _cells[cell] - 1
		_cells[cell] = 0
		_cue("spark")
		sparked.emit(_xf * mid(cell))
		if not Motion.reduce:
			_quake_at = _t
			_fling(cell, look, 1.0)
		for f in fell:
			var was := _cells[f.x]
			_cells[f.x] = 0
			if Motion.reduce:
				_cells[f.y] = was
			else:
				_air.append({"look": was - 1, "x": mid(f.y).x, "y": mid(f.x).y, "v": 0.0, "to": mid(f.y).y, "cell": f.y,
					"hit": false, "from": mid(f.x).y, "wait": 0.14, "spill": false, "group": true})
		_landing_left = 0 if Motion.reduce else fell.size()
		if _landing_left == 0:
			_after(Motion.REDUCED_TIME if Motion.reduce else WATCH + 0.2, func() -> void: settled.emit())
		_busy(1.2)
		_touch()
	if Motion.reduce:
		drop.call()
		return
	_fuse = {"at": _t, "cell": cell}
	_cue("fuse")
	_mark("fuse")
	_busy(FUSE + 0.2)
	_after(FUSE, drop)

## A penny comes out through the face, turning, and falls away.
func _fling(cell: int, look: int, k: float) -> void:
	_flung.append({"look": look, "at": mid(cell), "v": Vector2(randf_range(-520.0, 520.0), randf_range(-760.0, -420.0) * k),
		"spin": randf_range(-9.0, 9.0), "turn": 0.0, "t": 0.0})

## The penny in `cell` is taken back out of the top of its column.
func rewind(cell: int) -> void:
	var look := _cells[cell] - 1
	_cells[cell] = 0
	_last = -1
	_hint = -1
	_line = PackedInt32Array()
	_calm()
	if Motion.reduce or look < 0:
		_after(Motion.REDUCED_TIME, func() -> void: settled.emit())
		_touch()
		return
	_cue("lift", randf_range(TICK_VARY.x, TICK_VARY.y))
	_back_up = {"look": look, "x": mid(cell).x, "from": mid(cell).y, "at": _t}
	_busy(REWIND + 0.1)
	_after(REWIND, func() -> void:
		_back_up = {}
		settled.emit())

## The bulb's column, -1 for none.
func set_hint(col: int) -> void:
	_hint = col
	if col >= 0:
		_hover_to = float(col)
	_busy(0.2)
	_touch()

## Whose penny waits over the rack: the rules' `side`, or -1 for nobody's.
func set_waiting(side: int) -> void:
	var was := _hover_look
	_hover_look = -1 if side < 0 else look_of(side)
	if side < 0:
		_thinking = false
	elif _hover_look != was:
		_wait_at = _t
		if rolls and not still and not Motion.reduce and _hover_look == 1:
			# The moon's comes off the end of its roll, which lies just over
			# where it waits. The sun's roll is under the rack: a penny flying
			# up across the face read as one lying in the wrong hole.
			_fetch_from = _roll_at(_hover_look, _roll_left()[_hover_look])
			_fetch_at = _t
			_busy(FETCH + 0.1)
	_busy(0.3)
	_touch()

## What the waiting penny is: 0 plain, Rules.HEAVY, Rules.TWIN.
func set_trick(kind: int) -> void:
	_trick = kind
	_busy(0.3)
	_touch()

## A spark is in hand and the pennies of `look` can be touched; -1 puts it
## away.
func set_aim(look: int) -> void:
	_aim_look = look
	_busy(0.3)
	_touch()

## What each slot would do (`penny_ai.gd`'s `marks`), shown only under a
## finger on that slot.
func set_marks(marks: Dictionary) -> void:
	_marks = marks

## The other player is choosing: its penny drifts over the columns.
func set_thinking(on: bool) -> void:
	_thinking = on
	_busy(0.3)

## The other player has chosen `col`: its penny goes over it.
func set_lifted(col: int) -> void:
	_thinking = false
	if col >= 0:
		_hover_to = float(col)
	_busy(0.5)

## The game is over. A line, if there is one, is ringed.
func finish(outcome: String, line := PackedInt32Array()) -> void:
	_mood = outcome
	_line = line
	_won_at = _t
	_hover_look = -1
	_hint = -1
	_over = -1
	_down = false
	_thinking = false
	_line_order = line.duplicate()
	_line_order.sort()
	_line_straight = _line_order.size() >= 2
	for i in range(2, _line_order.size()):
		if _line_order[i] - _line_order[i - 1] != _line_order[1] - _line_order[0]:
			_line_straight = false
	if not Motion.reduce:
		if not line.is_empty():
			_mark("run")
		elif outcome == "draw":
			_mark("sigh")
			_busy(SIGH_TIME + SIGH_STEP * Rules.H + 0.2)
	_busy(1.2)
	_touch()

func _mark(kind: String) -> void:
	moments[kind] = _t

## Nothing of a moment is left showing.
func _calm() -> void:
	_joins.clear()
	_block = {}
	_knock_col = -1
	_lid_col = -1
	_shake_col = -1
	_line_order = PackedInt32Array()

## A penny has come to rest in `cell`: what it made there, read off the rack
## as it is shown.
func _landed(cell: int, look: int) -> void:
	_joins.clear()
	_block = {}
	if Motion.reduce:
		return
	var col := cell % Rules.W
	var row := cell / Rules.W
	var stopped := PackedInt32Array()
	var longest := 1
	for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		# the run of its own side through it
		var run := PackedInt32Array([cell])
		var k0 := 0
		for way in [-1, 1]:
			var x: int = col + d.x * way
			var y: int = row + d.y * way
			while x >= 0 and x < Rules.W and y >= 0 and y < Rules.H and _cells[x + y * Rules.W] == look + 1:
				if way < 0:
					run.insert(0, x + y * Rules.W)
					k0 += 1
				else:
					run.append(x + y * Rules.W)
				x += d.x * way
				y += d.y * way
		if run.size() >= 2:
			_joins.append({"at": _t, "look": look, "cells": run, "k0": k0, "n": run.size()})
			longest = maxi(longest, run.size())
		# a line of the other side it stands in the way of: any four in a row
		# through it whose other three are the other side's
		for start in range(-3, 1):
			var three := PackedInt32Array()
			for i in 4:
				var x: int = col + d.x * (start + i)
				var y: int = row + d.y * (start + i)
				if x < 0 or x >= Rules.W or y < 0 or y >= Rules.H:
					break
				var c := x + y * Rules.W
				if c != cell and _cells[c] == 2 - look:
					three.append(c)
			if three.size() == 3:
				for c in three:
					if not stopped.has(c):
						stopped.append(c)
	if longest >= 2:
		_mark("three" if longest >= 3 else "pair")
		_busy(JOIN_TIME + JOIN_STEP * 4.0 + 0.1)
	if not stopped.is_empty():
		_block = {"at": _t, "cell": cell, "cells": stopped}
		_mark("block")
		_busy(BLOCK_TIME + 0.1)
	if row == Rules.H - 1:
		_lid_at = _t
		_lid_col = col
		_mark("lid")
		_busy(LID_TIME + 0.1)

## Whether a penny is in the air, on its way down or back up.
func is_busy() -> bool:
	return not _air.is_empty() or not _back_up.is_empty()

# --- layout and time ---

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var space := SPACE_ROLLS if rolls and not still else SPACE
	var s := size.x / space.size.x if still else minf(size.x / space.size.x, size.y / space.size.y)
	var at := Vector2((size.x - space.size.x * s) * 0.5, size.y - space.size.y * s if still else (size.y - space.size.y * s) * 0.5)
	_xf = Transform2D(0.0, Vector2(s, s), 0.0, at - space.position * s)
	used_rect = Rect2(at, space.size * s)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	var live := _t < _busy_until or not _air.is_empty() or not _flung.is_empty() or _down or _thinking or _aim_look >= 0
	# The waiting penny comes and goes, and follows its column.
	var want := 1.0 if _hover_look >= 0 else 0.0
	if _hover_a != want:
		_hover_a = move_toward(_hover_a, want, delta * 6.0)
		live = true
	if _hover_look >= 0:
		if _thinking and not Motion.reduce:
			_hover_to = 3.0 + 2.3 * sin(_t * 1.25)
		if _hover_x != _hover_to:
			_hover_x = _hover_to if Motion.reduce else lerpf(_hover_x, _hover_to, minf(1.0, delta * HOVER_SPEED))
			if absf(_hover_x - _hover_to) < 0.004:
				_hover_x = _hover_to
			live = true
		# Waiting for the player it bobs a little, so it is seen to be theirs.
		if interactive and not Motion.reduce:
			live = true
	_fall(delta)
	_fly(delta)
	if live:
		queue_redraw()

## Moves what is in the air: a dropped penny falls, knocks once and lies
## still; a spilled one falls away.
func _fall(delta: float) -> void:
	var g := GRAVITY
	var i := 0
	while i < _air.size():
		var p: Dictionary = _air[i]
		if float(p.wait) > 0.0:
			p.wait = float(p.wait) - delta
			i += 1
			continue
		var rows: PackedInt32Array = p.get("heavy", PackedInt32Array())
		p.v = float(p.v) + g * (HEAVY_FALL if p.has("heavy") else 1.0) * delta
		p.y = float(p.y) + float(p.v) * delta
		# through what is under it, one penny at a time
		while not rows.is_empty() and float(p.y) + PENNY_R >= mid(rows[0]).y - PENNY_R * 0.5:
			var c := rows[0]
			var look := _cells[c] - 1
			rows.remove_at(0)
			p.heavy = rows
			_cells[c] = 0
			_crushed += 1
			_cue("crush", 0.9 + 0.09 * mini(_crushed, 5))
			_quake_at = _t
			_fling(c, look, 1.0 + 0.1 * _crushed)
			p.v = float(p.v) * CRUSH_KEEP
			crushed_one.emit(_crushed, _xf * mid(c))
		if float(p.y) >= float(p.to):
			if bool(p.spill):
				_air.remove_at(i)
				continue
			if not bool(p.hit):
				# The knock: louder and lower the further it fell.
				var fell := clampf((float(p.to) - float(p.from)) / GRID.y, 0.0, 1.0)
				_cue("land", 1.12 - 0.2 * fell, lerpf(-7.0, 0.0, fell))
				p.hit = true
				p.y = float(p.to)
				p.v = -float(p.v) * BOUNCE
				if not Motion.reduce:
					_knock_at = _t
					_knock_col = int(p.cell) % Rules.W
					_knock_row = int(p.cell) / Rules.W
					_knock_k = lerpf(0.5, 1.0, fell)
					_mark("knock")
			else:
				_cells[int(p.cell)] = int(p.look) + 1
				var grouped := p.has("group")
				if not grouped:
					_last = int(p.cell)
				_air.remove_at(i)
				if grouped:
					_landing_left -= 1
					_busy(WATCH + 0.3)
					if _landing_left == 0:
						_after(WATCH, func() -> void: settled.emit())
					continue
				_landed(int(p.cell), int(p.look))
				_busy(WATCH + 0.3)
				_after(WATCH, func() -> void: settled.emit())
				continue
		i += 1

## Moves the pennies that came out through the face.
func _fly(delta: float) -> void:
	var i := 0
	while i < _flung.size():
		var f: Dictionary = _flung[i]
		f.t = float(f.t) + delta
		f.v = (f.v as Vector2) + Vector2(0.0, GRAVITY * 0.6 * delta)
		f.at = (f.at as Vector2) + (f.v as Vector2) * delta
		f.turn = float(f.turn) + float(f.spin) * delta
		if float(f.t) >= FLING_LIFE:
			_flung.remove_at(i)
			continue
		i += 1

func _busy(seconds: float) -> void:
	_busy_until = maxf(_busy_until, _t + seconds)

func _touch() -> void:
	queue_redraw()

func _after(seconds: float, what: Callable) -> void:
	var run := _run
	if not is_inside_tree():
		return
	get_tree().create_timer(maxf(seconds, 0.01)).timeout.connect(func() -> void:
		if run == _run and is_inside_tree():
			what.call())

func _cue(cue_name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if _fx != null:
		_fx.cue(cue_name, pitch, volume_db)

# --- input ---

## The column a point of the board is over, -1 off the rack's sides.
func column_at(p: Vector2) -> int:
	var q := _xf.affine_inverse() * p
	if q.x < -FRAME or q.x > GRID.x + FRAME:
		return -1
	return clampi(int(floorf(q.x / U)), 0, Rules.W - 1)

## The cell of the hole under a point of the board, -1 for none.
func cell_at(p: Vector2) -> int:
	var q := _xf.affine_inverse() * p
	if q.x < 0.0 or q.x >= GRID.x or q.y < 0.0 or q.y >= GRID.y:
		return -1
	return int(q.x / U) + (Rules.H - 1 - int(q.y / U)) * Rules.W

func _gui_input(event: InputEvent) -> void:
	if still or deaf or not interactive:
		return
	var press := false
	var release := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventScreenDrag and event.index == 0:
		at = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		at = event.position
	else:
		return
	accept_event()
	if _aim_look >= 0:
		if press:
			var c := cell_at(at)
			if c >= 0 and _cells[c] == _aim_look + 1:
				_cue("tick")
				aimed.emit(c)
			else:
				_cue("refused", randf_range(TICK_VARY.x, TICK_VARY.y))
				refused.emit("aim")
		return
	var col := column_at(at)
	if release:
		if not _down:
			return
		_down = false
		if col < 0 and _over >= 0:
			# let go off the rack: the press is given up with no drop
			_cue("tick", 0.84)
		_over = -1
		if col >= 0:
			if rules.can(col) or _trick == Rules.HEAVY:
				_hover_x = float(col)
				_hover_to = float(col)
				chosen.emit(col)
			else:
				_shake_at = _t
				_shake_col = col
				_busy(0.4)
				_cue("refused", randf_range(TICK_VARY.x, TICK_VARY.y))
				refused.emit("full")
		_touch()
		return
	if press:
		_down = true
	if not _down:
		return
	if col != _over:
		_over = col
		if col >= 0:
			# A press ticks too when it sends the penny to another column; one
			# on the column it already hangs over is answered by the drop.
			var shifts := _hover_to != float(col)
			_hover_to = float(col)
			peeked.emit(col, int(_marks.get(col, 0)))
			if not press:
				_cue("tick", randf_range(TICK_VARY.x, TICK_VARY.y))
				moved.emit()
			elif shifts:
				_cue("tick", randf_range(TICK_VARY.x, TICK_VARY.y))
		_busy(0.3)
	_touch()

# --- drawing ---

func _draw() -> void:
	if rules == null or used_rect.size.x <= 0.0:
		return
	if _back == null:
		_back = _build_back()
		_front = _build_front()
		_iron = _build_iron()
		_penny = [_build_penny(0), _build_penny(1)]
		_glow = _build_glow()
	_over_mesh = _build_over()
	_shown = [_back, _front, _penny, _iron, _glow, _over_mesh]
	# The face dips on its foot at a knock and shivers when the rack is full
	# with no line; the foot, the trays and the shadow stay where they are.
	var xf := _xf
	var live := not Motion.reduce
	if live:
		var shift := Vector2(0.0, Motion.nudge_offset(_t - _knock_at, RACK_PX * _knock_k, Motion.NUDGE_TIME, 0.0))
		if _mood == "draw" and _line.is_empty():
			shift.x += Motion.shiver_offset(_t - _won_at, FULL_PX, 0.3)
		shift += Vector2(Motion.shiver_offset(_t - _quake_at, QUAKE_PX, QUAKE_TIME), Motion.nudge_offset(_t - _quake_at, QUAKE_PX * 0.7, Motion.NUDGE_TIME, 0.0))
		xf = _xf * Transform2D(0.0, shift)
	draw_mesh(_back, null, _xf)
	var lit := _over if _down else -1
	if lit >= 0:
		draw_mesh(_glow, null, xf * Transform2D(0.0, Vector2(lit * U, 0.0)))
	for c in Rules.CELLS:
		if _cells[c] != 0:
			draw_mesh(_penny[_cells[c] - 1], null, xf * (_cell_xf(c) if live else Transform2D(0.0, mid(c))))
	for p: Dictionary in _air:
		var a := 1.0
		var squash := Vector2.ONE
		if bool(p.spill):
			a = clampf((SPACE_ROLLS.end.y + 200.0 - float(p.y)) / 300.0, 0.0, 1.0)
		elif bool(p.hit):
			# the knock flattens it once
			var q := Motion.bump_scale(_t - _knock_at, SQUASH * _knock_k, Motion.BUMP_TIME) - 1.0
			squash = Vector2(1.0 + q, 1.0 - q)
		var fall := xf * Transform2D(0.0, squash, 0.0, Vector2(float(p.x), float(p.y) + (squash.x - 1.0) * PENNY_R))
		draw_mesh(_penny[int(p.look)], null, fall, Color(1, 1, 1, a))
		if p.has("heavy"):
			draw_mesh(_iron, null, fall)
	if not _back_up.is_empty():
		var f := clampf((_t - float(_back_up.at)) / REWIND, 0.0, 1.0)
		var y := lerpf(float(_back_up.from), HOVER_Y, ease(f, 0.5))
		draw_mesh(_penny[int(_back_up.look)], null, xf * Transform2D(0.0, Vector2(float(_back_up.x), y)), Color(1, 1, 1, 1.0 - f * f))
	draw_mesh(_front, null, xf)
	if rolls and not still:
		_draw_rolls()
	for f: Dictionary in _flung:
		var u := float(f.t) / FLING_LIFE
		var k := 1.0 + FLING_GROW * sin(minf(u * 2.0, 1.0) * PI * 0.5)
		draw_mesh(_penny[int(f.look)], null, xf * Transform2D(float(f.turn), Vector2.ONE * k, 0.0, f.at), Color(1, 1, 1, 1.0 - u * u * u))
	# what a mark warns of: the other side's penny in the place you would lift
	# it onto
	if _down and int(_marks.get(_over, 0)) == AI.MARK_GIVES and rules.landing(_over) >= 0:
		draw_mesh(_penny[1 - look_of(rules.turn)], null, xf * Transform2D(0.0, mid(rules.landing(_over) + Rules.W)), Color(1, 1, 1, 0.6))
	if _hover_look >= 0 and _hover_a > 0.0:
		var at := _hover_at()
		var sc := 0.8 + 0.2 * _hover_a
		var a := _hover_a
		var lean := 0.0
		if live:
			var shake := _t - _shake_at
			if shake < 0.3:
				at.x += sin(shake * 60.0) * 7.0 * (1.0 - shake / 0.3)
			# It leans the way it is going, and rocks now and then while it is
			# the player's to drop.
			lean = clampf((_hover_to - _hover_x) * LEAN, -0.4, 0.4)
			if interactive and not _down:
				lean += Motion.wobble_angle(fposmod(_t - _wait_at, BECKON) - BECKON * 0.5)
			var u := (_t - _fetch_at) / FETCH
			if u < 1.0:
				# on its way from the roll, swelling at the middle of the way
				var e := 1.0 - (1.0 - u) * (1.0 - u)
				at = _fetch_from.lerp(at, e)
				sc = lerpf(ROLL_R / PENNY_R, 1.0, e) * (1.0 + AIR * sin(PI * u))
				a = 1.0
				lean = 0.0
		var hang := _xf * Transform2D(lean, Vector2.ONE * sc, 0.0, at)
		if _trick == Rules.TWIN:
			draw_mesh(_penny[_hover_look], null, hang * Transform2D(0.0, Vector2(-26.0, 0.0)), Color(1, 1, 1, a))
			draw_mesh(_penny[_hover_look], null, hang * Transform2D(0.0, Vector2(26.0, 0.0)), Color(1, 1, 1, a))
		else:
			draw_mesh(_penny[_hover_look], null, hang, Color(1, 1, 1, a))
		if _trick == Rules.HEAVY:
			draw_mesh(_iron, null, hang, Color(1, 1, 1, a))
	if _over_mesh != null:
		draw_mesh(_over_mesh, null, xf)

## Where the waiting penny hangs.
func _hover_at() -> Vector2:
	var at := Vector2((_hover_x + 0.5) * U, HOVER_Y)
	if interactive and not _down and not Motion.reduce:
		at.y += sin(_t * 3.2) * 5.0
	return at

## A penny lying in `c` as it is this frame: driven down by a knock above it,
## answering one of its side that landed beside it, shivering in a line that
## was stopped or a slot that is full, hopping in the four or drawn back
## into its hole beside it. Never called under reduce motion.
func _cell_xf(c: int) -> Transform2D:
	var at := mid(c)
	var col := c % Rules.W
	var row := c / Rules.W
	var sc := 1.0
	var lean := 0.0
	if col == _knock_col and row < _knock_row:
		var depth := _knock_row - row
		at.y += Motion.nudge_offset(_t - _knock_at, KNOCK_PX * _knock_k * pow(KNOCK_FADE, depth - 1), Motion.NUDGE_TIME, Motion.NUDGE_LAG * depth)
	if col == _lid_col:
		at.y += Motion.nudge_offset(_t - _lid_at, LID_PX, Motion.NUDGE_TIME, Motion.NUDGE_LAG * row)
	if col == _shake_col:
		at.x += Motion.shiver_offset(_t - _shake_at, FULL_PX, 0.3)
	if not _line.is_empty():
		var since := _t - _won_at
		var k := _line_order.find(c)
		if k >= 0:
			at.y += Motion.hop_lift(fposmod(since, RUN_EVERY) - 0.1 - RUN_STEP * k, Motion.SOLVE_HOP, Motion.SOLVE_TIME)
		else:
			var u := clampf((since - 0.25) / 0.4, 0.0, 1.0)
			sc = lerpf(1.0, STEP_BACK, u * u * (3.0 - 2.0 * u))
		return Transform2D(0.0, Vector2(sc, sc), 0.0, at)
	for j: Dictionary in _joins:
		var k: int = (j.cells as PackedInt32Array).find(c)
		# the one that landed has only just come to rest: in a pair the other
		# answers, in a three all of them do, one after another
		if k >= 0 and (int(j.n) >= 3 or k != int(j.k0)):
			var since: float = _t - float(j.at) - JOIN_STEP * absi(k - int(j.k0))
			at.y += Motion.hop_lift(since, JOIN_HOP, Motion.HOP_TIME)
			lean += Motion.wobble_angle(since, JOIN_LEAN)
	if not _block.is_empty() and (_block.cells as PackedInt32Array).has(c):
		at.x += Motion.shiver_offset(_t - float(_block.at) - 0.08, BLOCK_PX, 0.3)
	if _mood == "draw":
		at.y += Motion.hop_lift(_t - _won_at - SIGH_STEP * row, SIGH_PX, SIGH_TIME)
	return Transform2D(lean, Vector2(sc, sc), 0.0, at)

## How many pennies lie in each roll: one fewer for the one waiting over the
## rack or in the air.
func _roll_left() -> Array:
	var left := [Rules.CELLS / 2, Rules.CELLS / 2]
	for c in Rules.CELLS:
		if _cells[c] != 0:
			left[_cells[c] - 1] -= 1
	for p: Dictionary in _air:
		if not bool(p.spill):
			left[int(p.look)] -= 1
	if not _back_up.is_empty():
		left[int(_back_up.look)] -= 1
	if _hover_look >= 0:
		left[_hover_look] -= 1
	return left

## The middle of the `i`th penny of a roll.
static func _roll_at(look: int, i: int) -> Vector2:
	var step := (GRID.x - 2.0 * ROLL_R) / (Rules.CELLS / 2 - 1)
	return Vector2(ROLL_R + maxi(i, 0) * step, ROLL_BOTTOM_Y if look == 0 else ROLL_TOP_Y)

## Each side's pennies not yet played, lying in a roll.
func _draw_rolls() -> void:
	var left := _roll_left()
	var k := ROLL_R / PENNY_R
	for look in 2:
		for i in maxi(0, left[look]):
			draw_mesh(_penny[look], null, _xf * Transform2D(0.0, Vector2(k, k), 0.0, _roll_at(look, i)))

## A pine tray lined with the felt of the rack's inside, seen from above: its
## shadow, its walls and the floor inside them, darker under the near wall.
static func _tray(b: Face.Builder, at: Vector2, sz: Vector2, wall := 8.0) -> void:
	var r := sz.y * 0.5
	b.fan(Face.Builder.round_rect(at + Vector2(0.0, 7.0), sz, r), Color(0.1, 0.06, 0.02, 0.24))
	b.fan(Face.Builder.round_rect(at + Vector2(0.0, 4.0), sz, r), PINE_DEEP)
	b.fan(Face.Builder.round_rect(at, sz, r), PINE)
	b.stroke(Face.Builder.round_rect(at + Vector2(3.0, 3.0), sz - Vector2(6.0, 6.0), r - 3.0), 2.0, Color(PINE_LIT, 0.9), true)
	var inner := at + Vector2(wall, wall)
	var isz := sz - Vector2(wall, wall) * 2.0
	b.fan(Face.Builder.round_rect(inner, isz, r - wall), INSIDE.darkened(0.2))
	b.fan(Face.Builder.round_rect(inner + Vector2(0.0, 5.0), isz - Vector2(0.0, 5.0), r - wall), INSIDE.lightened(0.08))

## The shadow the rack throws on the deck, its wooden foot, and the dark
## inside seen through the holes.
func _build_back() -> ArrayMesh:
	var b := Face.Builder.new()
	var foot_at := Vector2(-(FRAME + FOOT_OUT), GRID.y + FRAME * 0.5)
	var foot := Vector2(GRID.x + 2.0 * (FRAME + FOOT_OUT), FOOT_H)
	if rolls and not still:
		for y: float in [ROLL_TOP_Y, ROLL_BOTTOM_Y]:
			_tray(b, Vector2(-TRAY_OUT, y - TRAY_H * 0.5), Vector2(GRID.x + 2.0 * TRAY_OUT, TRAY_H))
	Scenery.soft_disc(b, Vector2(GRID.x * 0.5, GRID.y + FRAME + FOOT_H * 0.7), GRID.x * 0.62, 30.0, Color(0.15, 0.08, 0.03, 0.3))
	b.fan(Face.Builder.round_rect(foot_at + Vector2(0.0, 5.0), foot, 14.0), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(foot_at, foot - Vector2(0.0, 5.0), 14.0), WOOD)
	b.stroke(PackedVector2Array([foot_at + Vector2(18.0, 8.0), foot_at + Vector2(foot.x - 18.0, 8.0)]), 5.0, Color(WOOD_LIT, 0.8))
	b.fan(Face.Builder.round_rect(Vector2(-4.0, -4.0), GRID + Vector2(8.0, 8.0), 10.0), INSIDE)
	return b.mesh()

## The painted face: a tile a hole, each a square with a round hole through
## it, then the frame round them and each hole's rim and the shade the face
## throws into it.
func _build_front() -> ArrayMesh:
	var b := Face.Builder.new()
	var n := 32
	for c in Rules.CELLS:
		var centre := mid(c)
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var d0 := Vector2.from_angle(a0)
			var d1 := Vector2.from_angle(a1)
			var v0 := b.vertex(centre + d0 * HOLE_R, PAINT)
			var v1 := b.vertex(centre + d1 * HOLE_R, PAINT)
			var v2 := b.vertex(centre + d1 * (U * 0.5 / maxf(absf(d1.x), absf(d1.y))), PAINT)
			var v3 := b.vertex(centre + d0 * (U * 0.5 / maxf(absf(d0.x), absf(d0.y))), PAINT)
			b.tri(v0, v1, v2)
			b.tri(v0, v2, v3)
	# the frame, lit along its top and shaded along its bottom
	var half := FRAME * 0.5
	b.stroke(Face.Builder.round_rect(Vector2(-half, -half + 4.0), GRID + Vector2(FRAME, FRAME), 26.0), FRAME + 2.0, PAINT_DEEP, true)
	b.stroke(Face.Builder.round_rect(Vector2(-half, -half), GRID + Vector2(FRAME, FRAME - 4.0), 26.0), FRAME + 2.0, PAINT_LIT, true)
	b.stroke(PackedVector2Array([Vector2(8.0, -FRAME + 9.0), Vector2(GRID.x - 8.0, -FRAME + 9.0)]), 5.0, Color(1, 1, 1, 0.28))
	for c in Rules.CELLS:
		var centre := mid(c)
		b.stroke(Face.Builder.ring(centre, HOLE_R + 1.0, HOLE_R + 1.0), 5.0, PAINT_DEEP, true)
		b.stroke(Face.Builder.arc_points(centre, HOLE_R + 4.5, PI * 0.15, PI * 0.85), 3.0, Color(1, 1, 1, 0.22))
		b.stroke(Face.Builder.arc_points(centre, HOLE_R - 4.0, PI * 1.1, PI * 1.9), 7.0, Color(0.05, 0.12, 0.12, 0.22))
	return b.mesh()

## One penny about the origin: a rim, a face, a raised ring, a shine, and the
## side's stamp -- a sun with its rays, or a crescent -- so the two are told
## apart by more than their colour.
func _build_penny(look: int) -> ArrayMesh:
	var b := Face.Builder.new()
	var r := PENNY_R
	b.disc(Vector2(0.0, 2.0), r, RIM[look].darkened(0.25))
	b.disc(Vector2.ZERO, r - 1.0, RIM[look])
	b.disc(Vector2(0.0, -1.5), r - 6.0, COIN[look])
	b.stroke(Face.Builder.ring(Vector2.ZERO, r - 12.0, r - 12.0), 2.5, Color(STAMP[look], 0.7), true)
	b.stroke(Face.Builder.arc_points(Vector2.ZERO, r - 8.5, PI * 1.08, PI * 1.55), 4.0, Color(SHINE[look], 0.9))
	if look == 0:
		b.disc(Vector2.ZERO, 11.0, STAMP[look])
		for k in 8:
			var d := Vector2.from_angle(TAU * k / 8.0)
			b.stroke(PackedVector2Array([d * 16.5, d * 23.0]), 5.0, STAMP[look])
	else:
		# a crescent: the outer arc of one disc, then back along another's
		var pts := Face.Builder.arc_points(Vector2(-2.0, 0.0), 19.0, PI * 0.32, PI * 1.68)
		var inner := Face.Builder.arc_points(Vector2(7.0, 0.0), 15.5, PI * 1.5, PI * 0.5)
		pts.append_array(inner)
		b.polygon(pts, STAMP[look])
	return b.mesh()

## The iron band a heavy penny wears over its own stamp, with its rivets.
func _build_iron() -> ArrayMesh:
	var b := Face.Builder.new()
	var r := PENNY_R + 3.0
	b.stroke(Face.Builder.ring(Vector2(0.0, 2.0), r - 4.0, r - 4.0), 15.0, IRON_DEEP, true)
	b.stroke(Face.Builder.ring(Vector2.ZERO, r - 4.0, r - 4.0), 14.0, IRON, true)
	b.stroke(Face.Builder.arc_points(Vector2.ZERO, r - 3.0, PI * 1.05, PI * 1.6), 4.0, IRON_LIT)
	for k in 8:
		var d := Vector2.from_angle(TAU * k / 8.0 + PI / 8.0) * (r - 4.0)
		b.disc(d + Vector2(0.0, 1.0), 4.5, IRON_DEEP)
		b.disc(d, 3.8, IRON_LIT)
	return b.mesh()

## The light down a column, drawn behind the pennies for column 0.
func _build_glow() -> ArrayMesh:
	var b := Face.Builder.new()
	b.fan(Face.Builder.round_rect(Vector2(4.0, 0.0), Vector2(U - 8.0, GRID.y), 8.0), Color(1.0, 0.96, 0.8, 0.26))
	return b.mesh()

## What lies over the face: the arrow over the column under the finger, the
## dot on the last penny dropped, the bulb's ring, the rings round a line.
func _build_over() -> ArrayMesh:
	var b := Face.Builder.new()
	if not Motion.reduce:
		_light_wait(b)
		_light_knock(b)
		_light_joins(b)
		_light_lid(b)
	if _down and _over >= 0:
		var x := (_over + 0.5) * U
		var full: bool = not rules.can(_over)
		var col := Color(Pal.BAD, 0.9) if full else Color(HALO, 0.95)
		b.stroke(Face.Builder.round_rect(Vector2(_over * U + 3.0, 3.0), Vector2(U - 6.0, GRID.y - 6.0), 12.0), 5.0, col, true)
		var land: int = rules.landing(_over)
		if land >= 0:
			b.stroke(Face.Builder.ring(mid(land), HOLE_R - 7.0, HOLE_R - 7.0), 5.0, Color(HALO, 0.8), true)
			_mark_slot(b, land, int(_marks.get(_over, 0)))
		else:
			b.stroke(PackedVector2Array([Vector2(x - 16.0, HOVER_Y - 16.0), Vector2(x + 16.0, HOVER_Y + 16.0)]), 8.0, col)
			b.stroke(PackedVector2Array([Vector2(x + 16.0, HOVER_Y - 16.0), Vector2(x - 16.0, HOVER_Y + 16.0)]), 8.0, col)
	if _last >= 0 and _line.is_empty():
		b.disc(mid(_last), 7.0, Color(HALO, 0.95))
	if _hint >= 0 and rules.landing(_hint) >= 0:
		var at := mid(rules.landing(_hint))
		var beat := 0.0 if Motion.reduce else 0.5 + 0.5 * sin(_t * 5.0)
		b.stroke(Face.Builder.ring(at, HOLE_R - 8.0 + 3.0 * beat, HOLE_R - 8.0 + 3.0 * beat), 7.0, HINT, true)
		var x := (_hint + 0.5) * U
		var tip := Vector2(x, HOVER_Y + 26.0 + 6.0 * beat)
		b.polygon(PackedVector2Array([tip + Vector2(-20.0, -28.0), tip + Vector2(20.0, -28.0), tip]), HINT)
		_busy(0.2)
	_light_aim(b)
	if not Motion.reduce:
		_light_block(b)
		_light_run(b)
	if not _line.is_empty():
		var since := _t - _won_at
		for i in _line.size():
			var grow := 1.0 if Motion.reduce else clampf((since - 0.09 * i) / 0.25, 0.0, 1.0)
			if grow <= 0.0:
				continue
			var beat := 0.0 if Motion.reduce else sin(_t * 4.0 + i * 0.7)
			var r := (PENNY_R + 1.0 + 2.5 * beat) * (0.6 + 0.4 * ease(grow, 0.4))
			b.stroke(Face.Builder.ring(mid(_line[i]), r, r), 9.0, HALO, true)
			b.stroke(Face.Builder.ring(mid(_line[i]), r + 7.0, r + 7.0), 3.0, Color(Pal.SUN_RAY, 0.9), true)
		if not Motion.reduce:
			_busy(0.2)
	return null if b.verts.is_empty() else b.mesh()

## What the slot under the finger would do, on the place it lands in: gold a
## win, sky a line stopped, red a place handed to the other side. Never a
## shade of a penny; a ring of its own weight.
func _mark_slot(b: Face.Builder, land: int, kind: int) -> void:
	if kind == 0:
		return
	var at := mid(land)
	var col: Color = {AI.MARK_WIN: HINT, AI.MARK_BLOCK: SAFE, AI.MARK_GIVES: WARN}[kind]
	var target := land + Rules.W if kind == AI.MARK_GIVES else land
	b.stroke(Face.Builder.ring(mid(target), HOLE_R - 3.0, HOLE_R - 3.0), 9.0, col, true)
	if kind == AI.MARK_GIVES:
		b.stroke(PackedVector2Array([at + Vector2(0.0, -HOLE_R + 2.0), at + Vector2(0.0, -U + HOLE_R)]), 7.0, col)

## A spark in hand: every penny it could take stands in a beating ring, and
## one burning down is closed on by its fuse.
func _light_aim(b: Face.Builder) -> void:
	if _aim_look >= 0:
		var beat := 0.0 if Motion.reduce else 0.5 + 0.5 * sin(_t * 6.0)
		for c in Rules.CELLS:
			if _cells[c] == _aim_look + 1:
				b.stroke(Face.Builder.ring(mid(c), PENNY_R + 1.0 + 3.0 * beat, PENNY_R + 1.0 + 3.0 * beat), 6.0, WARN, true)
	if _fuse.is_empty():
		return
	var u := clampf((_t - float(_fuse.at)) / FUSE, 0.0, 1.0)
	var at := mid(int(_fuse.cell))
	var r := lerpf(PENNY_R + 34.0, PENNY_R * 0.4, u)
	b.stroke(Face.Builder.ring(at, r, r), 7.0, HINT, true)
	Scenery.soft_disc(b, at, 60.0 + 40.0 * u, 60.0 + 40.0 * u, Color(HINT, 0.25 + 0.5 * u))

# --- the moments' light: soft and round, all of it in the mesh over the face ---

## A mote: a soft round light with a paler heart.
static func _mote(b: Face.Builder, at: Vector2, r: float, col: Color, a: float) -> void:
	Scenery.soft_disc(b, at, r, r, Color(col, a))
	Scenery.soft_disc(b, at, r * 0.5, r * 0.5, Color(HALO, a))

## The penny that is the player's to drop stands in a breath of light.
func _light_wait(b: Face.Builder) -> void:
	if _hover_look < 0 or not interactive or _down or _t - _fetch_at < FETCH:
		return
	var breath := 0.5 + 0.5 * sin(_t * 2.4)
	var r := PENNY_R * (1.7 + 0.15 * breath)
	Scenery.soft_disc(b, _hover_at(), r, r, Color(HALO, (0.2 + 0.14 * breath) * _hover_a))

## Where a penny knocked: a low breath of light along what it landed on.
func _light_knock(b: Face.Builder) -> void:
	var since := _t - _knock_at
	if _knock_col < 0 or since < 0.0 or since >= KNOCK_LIGHT:
		return
	var u := since / KNOCK_LIGHT
	var out := 1.0 - (1.0 - u) * (1.0 - u)
	var at := mid(_knock_col + _knock_row * Rules.W) + Vector2(0.0, PENNY_R)
	Scenery.soft_disc(b, at, U * (0.45 + 0.5 * out), 20.0 + 14.0 * out, Color(HALO, 0.75 * _knock_k * (1.0 - u)))

## Pennies of one side that now touch: light in the side's own colour where
## each two meet, spreading and fading, and motes of it drifting off. Along a
## run of three it goes from seam to seam, and brighter.
func _light_joins(b: Face.Builder) -> void:
	for j: Dictionary in _joins:
		var cells: PackedInt32Array = j.cells
		var col: Color = (SHINE[int(j.look)] as Color).lightened(0.25)
		var strong: bool = int(j.n) >= 3
		for i in cells.size() - 1:
			# the seam nearest the penny that landed lights first
			var away := mini(absi(i - int(j.k0)), absi(i + 1 - int(j.k0)))
			var since: float = _t - float(j.at) - JOIN_STEP * away
			if since < 0.0 or since >= JOIN_TIME:
				continue
			var u := since / JOIN_TIME
			var out := 1.0 - (1.0 - u) * (1.0 - u)
			var seam := (mid(cells[i]) + mid(cells[i + 1])) * 0.5
			var reach := (44.0 if strong else 36.0) + 34.0 * out
			Scenery.soft_disc(b, seam, reach, reach, Color(col, (1.0 if strong else 0.85) * (1.0 - u)))
			Scenery.soft_disc(b, seam, reach * 0.5, reach * 0.5, Color(HALO, 0.85 * (1.0 - u)))
			for m in JOIN_MOTES:
				var a := TAU * m / JOIN_MOTES + float(j.at) * 3.0 + i * 1.3
				var at := seam + Vector2(cos(a), sin(a) * 0.8) * (16.0 + 46.0 * out) + Vector2(0.0, -18.0 * u)
				_mote(b, at, 13.0 * (1.0 - 0.5 * u), col.lightened(0.4), 1.0 - u)

## A slot filled to the top: its frame glints once and light lies on its lid.
func _light_lid(b: Face.Builder) -> void:
	var since := _t - _lid_at
	if _lid_col < 0 or since < 0.0 or since >= LID_TIME:
		return
	var u := since / LID_TIME
	var a := sin(minf(u * 3.0, 1.0) * PI * 0.5) * (1.0 - u)
	b.stroke(Face.Builder.round_rect(Vector2(_lid_col * U + 3.0, 3.0), Vector2(U - 6.0, GRID.y - 6.0), 12.0), 4.0, Color(HALO, 0.8 * a), true)
	Scenery.soft_disc(b, Vector2((_lid_col + 0.5) * U, -FRAME * 0.5), U * 0.62, 22.0, Color(HALO, 0.9 * a))

## A line of three stopped: a ring of light closes on the penny that stopped
## it.
func _light_block(b: Face.Builder) -> void:
	if _block.is_empty():
		return
	var since := _t - float(_block.at)
	if since < 0.0 or since >= BLOCK_TIME:
		return
	var u := since / BLOCK_TIME
	var shut := 1.0 - (1.0 - u) * (1.0 - u) * (1.0 - u)
	var r := PENNY_R + 2.0 + 30.0 * (1.0 - shut)
	var a := sin(minf(u * 4.0, 1.0) * PI * 0.5) * (1.0 - u * u)
	var at := mid(int(_block.cell))
	b.stroke(Face.Builder.ring(at, r, r), 6.0, Color(HALO, 0.95 * a), true)
	Scenery.soft_disc(b, at, r + 26.0, r + 26.0, Color(HALO, 0.3 * a))

## The four: light comes up on one after another as each hops, a soft light
## runs a straight line from end to end, and motes rise off them once.
func _light_run(b: Face.Builder) -> void:
	if _line_order.is_empty() or _line.is_empty():
		return
	var since := _t - _won_at
	var cyc := fposmod(since, RUN_EVERY) - 0.1
	var n := _line_order.size()
	for k in n:
		var at := mid(_line_order[k])
		var lvl := Motion.flash_level(cyc - RUN_STEP * k)
		if lvl > 0.0:
			Scenery.soft_disc(b, at, PENNY_R * 1.7, PENNY_R * 1.7, Color(HALO, 0.55 * lvl))
		var up := (since - 0.2 - RUN_STEP * k) / 1.1
		if up > 0.0 and up < 1.0:
			for m in 3:
				var a := TAU * m / 3.0 + k * 1.7
				_mote(b, at + Vector2(cos(a) * (26.0 + 30.0 * up), sin(a) * 18.0 - 70.0 * up), 12.0 * (1.0 - 0.5 * up), Pal.SUN_RAY.lightened(0.5), 1.0 - up)
	if _line_straight:
		var u := cyc / (RUN_TRAVEL + RUN_STEP * n)
		if u > 0.0 and u < 1.0:
			var at := mid(_line_order[0]).lerp(mid(_line_order[n - 1]), u)
			Scenery.soft_disc(b, at, 70.0, 70.0, Color(HALO, 0.7 * sin(u * PI)))
