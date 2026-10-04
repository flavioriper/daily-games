extends Control

## One page of Stackwood's tutorial: a small shelf played by the screen
## itself. The page holds a `Shelf` -- stackwood_screen.gd with its top bar,
## score row, banners, cards and endings taken out, so what is left is the
## shelf in its wooden frame (and, on the pages that teach them, the acorn
## bank and the tool chips beside it) -- standing four columns by four rows
## on a hand-made position, and a finger that presses the shelf, slides and
## lets go through the screen's own input, and taps the chips. So a block is
## steered and dropped, merges, chains, tops the shelf out, turns into a
## rainbow block or a bomb, and a zap strikes, exactly as in a run.
## `lesson` picks the page (set before it enters the tree):
##
## - STEER: slide to steer the falling block over a column, let go to drop.
## - MERGE: a block takes in every touching block of its number, doubling
##   once for each (a 4 between two 4s makes 16).
## - CHAIN: the blocks above fall into the gap and merge again, three rounds.
## - LINE: a stack one short of the line glows; a block that comes to rest
##   over the line topples the shelf.
## - RAINBOW: a merge's acorn reaches the bank, the rainbow block is bought
##   and joins the biggest block it lands on.
## - BLAST: the zap clears every smallest block, the bomb the blocks round
##   where it lands.
## - HUD: the top bar's Reset, ? and settings, the two boosters and the
##   Second chance, drawn as they are beside what they do.
##
## Under reduce-motion a page is a still: the block held over the column the
## lesson is about, the finger down under it.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Sim = preload("res://arcade/stackwood_sim.gd")
const Boosters = preload("res://arcade/boosters.gd")
const BoosterIcon = preload("res://arcade/booster_icon.gd")

enum Lesson { STEER, MERGE, CHAIN, LINE, RAINBOW, BLAST, HUD }

## The finger: how long it takes to come over, rests pressed before it
## slides, a column's slide, the wait before it lets go and after.
const APPROACH := 0.38
const PRESS_T := 0.2
const SLIDE_T := 0.24
const HOLD_T := 0.24
const AFTER_T := 0.32
## A chip the bank has just reached is left lit this long before the tap.
const LIT_T := 0.5
const FINGER_R := 30.0
const FINGER_ALPHA := 0.16
## The row of the shelf the finger slides along: its foot, under the numbers.
const FINGER_ROW := -0.45
const HUD_FS := 28

## Each lesson's position: `shelf` is a column a row, bottom up; `deal` the
## blocks that fall, in order; `bank` the acorns held; `tools` the chips that stand beside
## the shelf; `steps` what the finger does, ["drop", column] or
## ["tool", tool]; `rest` the seconds the end is left standing; `still` the
## reduce-motion picture: [the first block's number, a tool bought or -1,
## its column, its height].
const WILD_COST: int = Sim.COSTS[Sim.Tool.WILD]
const BLAST_COST: int = Sim.COSTS[Sim.Tool.ZAP] + Sim.COSTS[Sim.Tool.BOMB]
const PLANS := {
	Lesson.STEER: {"shelf": [[], [8], [], []], "deal": [2, 4, 16, 8], "steps": [["drop", 0], ["drop", 3]],
		"still": [2, -1, 0, 2.3]},
	Lesson.MERGE: {"shelf": [[4], [], [4], [32, 2]], "deal": [2, 4, 8, 16], "steps": [["drop", 3], ["drop", 1]],
		"still": [4, -1, 1, 1.6]},
	Lesson.CHAIN: {"shelf": [[], [2, 8], [8, 16], []], "deal": [2, 64, 64], "steps": [["drop", 0]], "rest": 1.6,
		"still": [2, -1, 0, 1.6]},
	# the tall stack stands under the middle, where a block comes in: the
	# first fills it to the line and the next has nowhere to go
	Lesson.LINE: {"shelf": [[4], [16], [2, 8, 32], []], "deal": [64, 4, 2], "steps": [["drop", 2]], "rest": 2.0,
		"still": [64, -1, 2, 3.45]},
	# one acorn short of the rainbow block: the first merge pays it
	Lesson.RAINBOW: {"shelf": [[2], [], [16], [64]], "deal": [2, 8, 4, 4], "bank": WILD_COST - 1, "tools": [Sim.Tool.WILD],
		"steps": [["drop", 1], ["tool", Sim.Tool.WILD], ["drop", 3]], "rest": 1.6,
		"still": [8, Sim.Tool.WILD, 3, 2.2]},
	Lesson.BLAST: {"shelf": [[2, 8], [16, 2], [32], [2, 64]], "deal": [4, 8, 8], "bank": BLAST_COST, "tools": [Sim.Tool.BOMB, Sim.Tool.ZAP],
		"steps": [["tool", Sim.Tool.ZAP], ["tool", Sim.Tool.BOMB], ["drop", 1]], "rest": 1.6,
		"still": [4, Sim.Tool.BOMB, 1, 3.0]},
}

var lesson: int = Lesson.STEER

var _art: Shelf
var _over: Control
var _begun := false
var _plan := {}
var _step := 0
## Where the finger is in its step: 0 waiting for the block, 1 coming over,
## 2 pressed, 3 sliding, 4 holding, 5 gone up.
var _ph := 0
var _pt := 0.0
var _lit := 0.0
var _rest := 0.0
var _at := Vector2.ZERO
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _slide := SLIDE_T
var _down := false
## The finger has come (it starts from the shelf's corner), and how much of
## it shows: it fades away once the lesson's last step is done.
var _seen := false
var _fade := 0.0
var _turning: Tween
var _finger_shown: ArrayMesh
var _hud_shown: ArrayMesh
var _badges: Array = []

## The screen, quiet: only the shelf in its frame, the bank and the chips; no
## top bar, score row, banner or card, no sound (`puzzle_id` names no set),
## no knock, no record, and of the lettering only a chain's count. It
## stands WIDE by HIGH.
class Shelf extends "res://arcade/stackwood_screen.gd":
	const WIDE := 4
	const HIGH := 4
	const FRAME_W := 500.0
	const SIDE_W := 290.0
	const SIDE_GAP := 20.0
	## The frame's shadow falls this far under it.
	const FOOT := 14.0
	enum Touch { PRESS, MOVE, RELEASE }

	## The tools whose chips stand beside the shelf, with the bank over them.
	var tools: Array = []
	var _frame: PanelContainer
	var _side: VBoxContainer
	var _stash: Control
	var _frozen := false

	func puzzle_id() -> String:
		return "stackwood_tutorial"

	func _cols() -> int:
		return WIDE

	func _rows() -> int:
		return HIGH

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# what the screen's own code writes to and a page does not show
		_stash = Control.new()
		_stash.visible = false
		# far off the page, which clips: what is thrown from one of them
		# (a chain's stars off the score) is not seen
		_stash.position = Vector2(-4000.0, -4000.0)
		add_child(_stash)
		_banner = Label.new()
		var box := Control.new()
		_banner.set_meta("box", box)
		_sub = Label.new()
		_score_l = Label.new()
		_best_l = Label.new()
		_score_k = Label.new()
		_next_view = Control.new()
		for n: Control in [_banner, box, _sub, _score_l, _best_l, _score_k, _next_view]:
			_stash.add_child(n)
		_frame = PanelContainer.new()
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.add_theme_stylebox_override("panel", _frame_box())
		add_child(_frame)
		field = Control.new()
		field.clip_contents = true
		field.mouse_filter = Control.MOUSE_FILTER_IGNORE
		field.draw.connect(_draw_field)
		field.resized.connect(_layout_field)
		_frame.add_child(field)
		_fx = Fx2D.new()
		_fx.buzzes = false
		field.add_child(_fx)
		_seat_tools()
		_air = Control.new()
		_air.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_air.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_air.draw.connect(_draw_air)
		add_child(_air)
		_air_fx = Fx2D.new()
		_air_fx.buzzes = false
		_air.add_child(_air_fx)
		resized.connect(_fit)
		_fit()

	## The screen's own bank and chips, out of their row: the bank over the
	## chips the page teaches, beside the shelf; the rest kept out of sight.
	func _seat_tools() -> void:
		var row := _build_tools()
		var bank: Control = row.get_child(0)
		row.remove_child(bank)
		for tool: int in _tool_buttons:
			var b: Button = _tool_buttons[tool]
			row.remove_child(b)
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.free()
		if tools.is_empty():
			_stash.add_child(bank)
		else:
			_side = VBoxContainer.new()
			_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_side.alignment = BoxContainer.ALIGNMENT_CENTER
			_side.add_theme_constant_override("separation", 18)
			add_child(_side)
			bank.custom_minimum_size.y = HUD_H
			bank.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_side.add_child(bank)
			var chips := HBoxContainer.new()
			chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chips.alignment = BoxContainer.ALIGNMENT_CENTER
			chips.custom_minimum_size.y = TOOLS_H
			chips.add_theme_constant_override("separation", 12)
			_side.add_child(chips)
			for tool: int in tools:
				var b: Button = _tool_buttons[tool]
				if tools.size() == 1:
					b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					b.custom_minimum_size.x = 150.0
				chips.add_child(b)
		for tool: int in _tool_buttons:
			if not tools.has(tool):
				_stash.add_child(_tool_buttons[tool])

	## The frame in the middle of the page, or it and the chips side by side.
	func _fit() -> void:
		var group := FRAME_W + (SIDE_GAP + SIDE_W if _side != null else 0.0)
		var x0 := floorf((size.x - group) * 0.5)
		var tall := maxf(0.0, size.y - FOOT)
		_frame.position = Vector2(x0, 0.0)
		_frame.size = Vector2(FRAME_W, tall)
		if _side != null:
			_side.position = Vector2(x0 + FRAME_W + SIDE_GAP, 0.0)
			_side.size = Vector2(SIDE_W, tall)

	func _process(delta: float) -> void:
		if not _frozen:
			super(delta)

	func _pause(_on: bool) -> void:
		pass

	func _show_banner(_text: String, _line: String, _hold: float) -> void:
		pass

	## Only a chain's count.
	func _sticker(text: String, at: Vector2, fs: int, life: float, rainbow := true, col := Color.WHITE, rays := false, id := "") -> void:
		if id == "chain":
			super(text, at, fs, life, rainbow, col, rays, id)

	## Acorns fly only to a bank that is there to count them.
	func _launch_acorns(ev: Dictionary) -> void:
		if _side != null:
			super(ev)

	## No record, no gold, no card: the blocks fly off and that is all.
	func _topple() -> void:
		_tumble()

	## A fresh shelf: `shelf` a column a row, bottom up, `deal` the blocks to
	## fall, `bank` the acorns held.
	func lay(shelf: Array, deal: Array, bank: int) -> void:
		sim = Sim.new(1, WIDE, HIGH)
		var top := 2
		for c in shelf.size():
			for v: int in shelf[c]:
				(sim.cols[c] as Array).append({"id": sim._new_id(), "v": v})
				top = maxi(top, v)
		sim.max_v = top
		sim.acorns = bank
		sim.queue = deal.duplicate()
		sim._set_phase(Sim.Phase.FALL)
		sim._next_piece()
		sim.events.clear()
		_clear_show()
		_frozen = false
		_animate(0.0)
		_refresh_hud()

	## The page standing still: the block (a `tool` bought first, -1 for none)
	## held over column `col` at height `y`, the lane lit as under a finger.
	func still(tool: int, col: int, y: float) -> void:
		if tool >= 0:
			sim.use(tool)
		sim.aim(col)
		sim.piece.y = y
		sim.piece.hold = 0.0
		_play_events()
		_dragging = true
		_animate(0.0)
		_refresh_hud()
		_frozen = true
		field.queue_redraw()
		_air.queue_redraw()

	## Whether the falling block can be steered now.
	func steerable() -> bool:
		return sim.phase == Sim.Phase.FALL and not sim.piece.is_empty() and not sim.piece.dropping and float(sim.piece.hold) <= 0.0

	## The acorns the bank shows: the ones still in the air are not in it.
	func bank() -> int:
		return sim.acorns - _owed

	## The middle of cell (c, r), and of a tool's chip, in the page's pixels.
	func cell_at(c: float, r: float) -> Vector2:
		return _in_air(field, px(c, r))

	func chip_at(tool: int) -> Vector2:
		var b: Control = _tool_buttons[tool]
		return _in_air(b, b.size * 0.5)

	## A finger at `at` (the page's pixels) comes down on the shelf, moves or
	## lets go: the screen's own input.
	func touch(at: Vector2, kind: int) -> void:
		var p := field.get_global_transform().affine_inverse() * (get_global_transform() * at)
		if kind == Touch.MOVE:
			var mm := InputEventMouseMotion.new()
			mm.position = p
			_on_field_input(mm)
			return
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = kind == Touch.PRESS
		mb.position = p
		_on_field_input(mb)

	## A tap on a tool's chip.
	func tap(tool: int) -> void:
		(_tool_buttons[tool] as Button).pressed.emit()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if lesson == Lesson.HUD:
		for id: String in Boosters.of("stackwood") + [Boosters.CHANCE]:
			var badge := BoosterIcon.new(id, 68.0)
			add_child(badge)
			_badges.append(badge)
	else:
		_plan = PLANS[lesson]
		_art = Shelf.new()
		_art.tools = _plan.get("tools", [])
		add_child(_art)
		_over = Control.new()
		_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_over.z_index = 6
		_over.draw.connect(_draw_finger)
		add_child(_over)
		_art.field.resized.connect(_over.queue_redraw)
	resized.connect(_layout)
	call_deferred("_layout")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun:
		call_deferred("_reset")

func _layout() -> void:
	if lesson == Lesson.HUD:
		queue_redraw()
		return
	_art.position = Vector2.ZERO
	_art.size = size
	_over.position = Vector2.ZERO
	_over.size = size
	if not _begun and is_inside_tree() and size.x > 0.0 and size.y > 0.0:
		_begun = true
		_reset()

# --- the lessons ---

## The lesson from its top: the shelf laid, the finger away.
func _reset() -> void:
	if lesson == Lesson.HUD or not is_inside_tree() or size.x <= 0.0:
		return
	Motion.stop(_turning)
	_turning = null
	_art.field.modulate.a = 1.0
	_lay()

func _lay() -> void:
	_step = 0
	_ph = 0
	_pt = 0.0
	_lit = 0.0
	_rest = 0.0
	_down = false
	_seen = false
	var st: Array = _plan.still
	var deal: Array = _plan.deal
	var bank := int(_plan.get("bank", 0))
	if Motion.reduce:
		deal = [st[0], deal[0], deal[1]]
		if int(st[1]) >= 0:
			bank = maxi(bank, int(Sim.COSTS[int(st[1])]))
	_fade = 0.0
	_art.lay(_plan.shelf, deal, bank)
	if Motion.reduce:
		_art.still(int(st[1]), int(st[2]), float(st[3]))
		_at = _art.cell_at(float(st[2]), FINGER_ROW)
		_down = true
		_seen = true
		_fade = 1.0
	_over.queue_redraw()

func _process(delta: float) -> void:
	if lesson == Lesson.HUD or not _begun or Motion.reduce or _turning != null:
		return
	_play(delta)
	_fade = move_toward(_fade, 1.0 if _seen and _step < (_plan.steps as Array).size() else 0.0, delta * 5.0)
	_over.queue_redraw()

## The finger, a step at a time; then the end is left standing a moment and
## the lesson starts over.
func _play(delta: float) -> void:
	var sim: RefCounted = _art.sim
	var steps: Array = _plan.steps
	if _step >= steps.size():
		_rest = 0.0 if sim.phase == Sim.Phase.RESOLVE else _rest + delta
		if _rest >= float(_plan.get("rest", 1.3)):
			_again()
		return
	var step: Array = steps[_step]
	var drop: bool = String(step[0]) == "drop"
	_pt += delta
	match _ph:
		0:
			var ready: bool = _art.steerable()
			if ready and not drop:
				ready = sim.can_use(int(step[1])) and _art.bank() >= int(Sim.COSTS[int(step[1])])
			_lit = _lit + delta if ready else 0.0
			if _lit >= (0.12 if drop else LIT_T):
				_lit = 0.0
				if not _seen:
					_at = _art.cell_at(Shelf.WIDE - 0.5, FINGER_ROW)
				_from = _at
				_to = _art.cell_at(float(sim.piece.col), FINGER_ROW) if drop else _art.chip_at(int(step[1]))
				_seen = true
				_turn(1)
		1:
			_at = _from.lerp(_to, smoothstep(0.0, 1.0, _pt / APPROACH))
			if _pt >= APPROACH:
				_at = _to
				_down = true
				if drop:
					_art.touch(_at, Shelf.Touch.PRESS)
				_turn(2)
		2:
			if drop:
				_art.touch(_at, Shelf.Touch.MOVE)
			if _pt >= PRESS_T:
				if not drop:
					_down = false
					_art.tap(int(step[1]))
					_turn(5)
				else:
					_from = _at
					_to = _art.cell_at(float(step[1]), FINGER_ROW)
					_slide = SLIDE_T * maxf(1.0, absf(float(step[1]) - float(sim.piece.col)))
					_turn(3 if _from.distance_to(_to) > 1.0 else 4)
		3:
			_at = _from.lerp(_to, smoothstep(0.0, 1.0, _pt / _slide))
			_art.touch(_at, Shelf.Touch.MOVE)
			if _pt >= _slide:
				_at = _to
				_turn(4)
		4:
			_art.touch(_at, Shelf.Touch.MOVE)
			if _pt >= HOLD_T:
				_down = false
				_art.touch(_at, Shelf.Touch.RELEASE)
				_turn(5)
		5:
			if _pt >= AFTER_T:
				_step += 1
				_turn(0)

func _turn(ph: int) -> void:
	_ph = ph
	_pt = 0.0

## The shelf fades, is laid again and comes back.
func _again() -> void:
	_turning = create_tween()
	_turning.tween_property(_art.field, "modulate:a", 0.0, 0.2)
	_turning.tween_callback(_lay)
	_turning.tween_property(_art.field, "modulate:a", 1.0, 0.24)
	_turning.tween_callback(func() -> void: _turning = null)

# --- drawing ---

func _draw_finger() -> void:
	if _fade <= 0.01:
		_finger_shown = null
		return
	if Motion.reduce:
		# the still is laid before the shelf has its size
		_at = _art.cell_at(float(_plan.still[2]), FINGER_ROW)
	var b := Face.Builder.new()
	var r := FINGER_R * (0.85 if _down else 1.0)
	b.disc(_at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0) * _fade))
	b.stroke(Face.Builder.ring(_at, r, r), 3.0, Color(Pal.TEXT, 0.45 * _fade), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)

## The HUD page: the top bar's Reset, its ? and settings, the two boosters
## and the Second chance, each drawn as it is beside what it does.
func _draw() -> void:
	if lesson != Lesson.HUD or size.x <= 0.0:
		return
	var rows := [
		[["reset"], tr("TUT_STACKWOOD_HUD_RESET")],
		[["help", "gear"], tr("TUT_STACKWOOD_HUD_PAUSE")],
		[[], tr("TUT_STACKWOOD_HUD_POUCH") % Boosters.SW_ACORNS],
		[[], tr("TUT_STACKWOOD_HUD_LOW") % Boosters.SW_SMALL],
		[[], tr("TUT_STACKWOOD_HUD_CHANCE")],
	]
	var row_h := size.y / rows.size()
	var chip := minf(68.0, row_h * 0.74)
	var gap := 12.0
	var x0 := 30.0
	var slot := chip * 2.0 + gap
	var b := Face.Builder.new()
	var marks: Array = []
	var badge := 0
	for k in rows.size():
		var cy := row_h * (k + 0.5)
		var icons: Array = rows[k][0]
		if icons.is_empty():
			var bd: Control = _badges[badge]
			badge += 1
			bd.size = Vector2(chip, chip)
			bd.position = Vector2(x0 + (slot - chip) * 0.5, cy - chip * 0.5)
			continue
		var wide := chip * icons.size() + gap * (icons.size() - 1)
		for i in icons.size():
			var r := Rect2(Vector2(x0 + (slot - wide) * 0.5 + i * (chip + gap), cy - chip * 0.5), Vector2(chip, chip))
			b.polygon(Face.Builder.round_rect(r.position + Vector2(0, 5.0), r.size, 20.0), Color(Pal.TEXT, 0.16))
			b.polygon(Face.Builder.round_rect(r.position, r.size, 20.0), Pal.SURFACE)
			marks.append([String(icons[i]), r])
	_hud_shown = b.mesh()
	draw_mesh(_hud_shown, null)
	for m: Array in marks:
		var r: Rect2 = m[1]
		Icons.paint(self, m[0], Rect2(r.get_center() - Vector2(chip, chip) * 0.27, Vector2(chip, chip) * 0.54), Pal.TEXT, Pal.SURFACE)
	var font: Font = CozyTheme.display(700)
	var tx := x0 + slot + 26.0
	var room := size.x - tx - 20.0
	for k in rows.size():
		var cy := row_h * (k + 0.5)
		var line := String(rows[k][1])
		var tall := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, room, HUD_FS).y
		draw_multiline_string(font, Vector2(tx, cy - tall * 0.5 + HUD_FS * 0.82), line, HORIZONTAL_ALIGNMENT_LEFT, room, HUD_FS, -1, Pal.TEXT)
