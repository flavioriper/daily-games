extends Control

## One page of Posy's tutorial: a small bed played by the game itself. The
## page holds a `Bed` -- arcade/posy_screen.gd with its top bar, hedges,
## lettering, sounds, records and cards taken out, so what is left is the
## field, and on the pages that teach them the paper row of goals and moves
## and the row of tools -- standing a `Plot`: arcade/posy_sim.gd laid by hand
## on a few cells, with what falls in next written down, so a lesson plays
## the same every time. A finger drags and taps through the field's own
## input, so a swap is taken or slides back, a special is left and goes off,
## a weed is pulled and the offer comes up exactly as in a game. `lesson`
## picks the page (set before it enters the tree):
##
## - SWAP: a tile dragged onto its neighbour lines up three; one that lines
##   nothing up slides back.
## - GOALS: the day's goals fill, and the moves left over bloom.
## - SPECIALS: a breeze, a seed bomb, a rainbow posy and a bee, each made
##   and then set off, one after another.
## - BLOCKERS: weeds pulled, a stone broken (in a shaped bed), moss creeping
##   and cleared.
## - MOVES: the last move falls short, and the offer of more is taken.
## - TOOLS: the four tools, each armed and used.
## - BUTTONS: Reset and ?, the boosters and the Second chance, drawn as they
##   are beside what they do.
##
## Under reduce motion a page lays one bed, makes at most a move on it and
## stands still.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://arcade/posy_sim.gd")
const Boosters = preload("res://arcade/boosters.gd")
const BoosterIcon = preload("res://arcade/booster_icon.gd")

enum Lesson { SWAP, GOALS, SPECIALS, BLOCKERS, MOVES, TOOLS, BUTTONS }

const CAPTION_H := 64.0
## The finger: how long it takes to a new place, how long it stays down on a
## tap, how long a drag takes, and what it waits once the bed is still.
const GO := 0.5
const TAP_DOWN := 0.14
const DRAG_T := 0.22
const REST := 0.7
const FINGER_ALPHA := 0.16

var lesson: int = Lesson.SWAP

var _bed: Bed
var _over: Control
var _caption: Label
var _icons: Array = []
var _begun := false
var _plan := {}
var _scene := 0
var _ops: Array = []
var _op := 0
var _entered := false
var _t := 0.0
var _stopped := false
var _from := Vector2.ZERO
var _fpos := Vector2.ZERO
var _fdown := false
var _seen := false
var _finger_shown: ArrayMesh
var _hud_shown: ArrayMesh

## The game laid by hand: `scene.bed` is the bed's rows, a cell two letters
## -- a kind (f l d m b a: flower, leaf, drop, mushroom, berry, acorn; r a
## rainbow posy) and a mark (- none, w a weed under it, = and | a breeze
## across and down, o a seed bomb, z a bee), `..` a hole, `##` a stone, `%%`
## moss -- and every cell outside them a hole. `feed` is what falls in, in
## order, `goals` [kind, need, got] (a need below nought counts what stands).
class Plot extends "res://arcade/posy_sim.gd":
	const KINDS := "fldmba"
	const SEED := 11

	var cols := 0
	var rows := 0
	var _laid := false
	var _feed := ""
	var _fed := 0

	func _init(scene: Dictionary) -> void:
		super(SEED)
		_lay(scene)

	func _lay(scene: Dictionary) -> void:
		var bed: Array = scene.bed
		rows = bed.size()
		cols = String(bed[0]).split(" ").size()
		events.clear()
		rng.seed = int(scene.get("seed", SEED))
		kinds = 5
		day = 1
		moves_left = int(scene.get("moves", day_plan(1).moves))
		for c in COLS:
			for r in ROWS:
				block[c][r] = Block.HOLE
				hp[c][r] = 0
				weed[c][r] = 0
				grid[c][r] = {}
		var marks := {"=": Sp.ROW, "|": Sp.COL, "o": Sp.BOMB, "z": Sp.BEE}
		for r in rows:
			var cells := String(bed[r]).split(" ")
			for c in cols:
				var what: String = cells[c]
				if what == "..":
					continue
				block[c][r] = Block.NONE
				if what == "##":
					block[c][r] = Block.STONE
					hp[c][r] = 1
				elif what == "%%":
					block[c][r] = Block.MOSS
				elif what[0] == "r":
					grid[c][r] = _new_tile(-1, Sp.RAINBOW)
				else:
					grid[c][r] = _new_tile(KINDS.find(what[0]), int(marks.get(what[1], Sp.NONE)))
					if what[1] == "w":
						weed[c][r] = 1
		goals.clear()
		for g: Array in scene.get("goals", [[5, 99]]):
			var need := int(g[1])
			if need < 0:
				match int(g[0]):
					GOAL_WEED:
						need = _count_weeds()
					GOAL_STONE:
						need = _count_blocks(Block.STONE)
					GOAL_MOSS:
						need = _count_blocks(Block.MOSS)
			goals.append({"k": int(g[0]), "need": need, "got": int(g[2]) if g.size() > 2 else 0})
		_feed = String(scene.get("feed", "dmb"))
		_fed = 0
		_laid = true
		events.append({"type": "deal", "day": day, "tiles": _all_tiles(), "moves": moves_left,
			"goals": goals.duplicate(true), "cells": _all_cells()})

	## What falls in is the scene's own, in order.
	func _new_tile(k: int, sp := Sp.NONE) -> Dictionary:
		if _laid and _feed != "":
			k = KINDS.find(_feed[_fed % _feed.length()])
			_fed += 1
		return super(k, sp)

	## Only the plot's own ground: the holes round it are not the bed's.
	func _all_cells() -> Array:
		var out: Array = []
		for g: Dictionary in super():
			var cell: Vector2i = g.cell
			if cell.x < cols and cell.y < rows:
				out.append(g)
		return out

	## A day done deals nothing: the page lays the next bed itself.
	func _start_day() -> void:
		if not _laid:
			super()

## The screen, quiet: only the field, the paper row and the tools, laid at
## the game's own size (the page scales it down), with no lettering, sound,
## knock, record or end.
class Bed extends "res://arcade/posy_screen.gd":
	const CELL := 118.0
	const PAD := 8.0
	const TOOLS_W := 758.0
	## How far a tool's badge stands over its chip.
	const BADGE_RISE := 18.0
	const OFFER_SCALE := 0.74
	enum Touch { DOWN, MOVE, UP }

	var cols := 6
	var rows := 4
	var with_hud := false
	var with_tools := false
	## Whether the field's own banner may speak (a tool's line).
	var speaks := false
	var _hud: Control
	var _tools: Control
	var _dealing := false

	## The top bar and the settings sheet the screen asks after.
	class NoBar extends Control:
		func refresh(_host: Variant) -> void:
			pass

	class NoSheet extends Control:
		func is_open() -> bool:
			return false

	func puzzle_id() -> String:
		return "posy_tutorial"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_bar = NoBar.new()
		top_bar.visible = false
		add_child(top_bar)
		settings_sheet = NoSheet.new()
		settings_sheet.visible = false
		add_child(settings_sheet)
		_hud = _build_hud()
		_hud.get_child(0).visible = false
		_hud.visible = with_hud
		add_child(_hud)
		add_child(_build_field())
		field.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.buzzes = false
		_tools = _build_tools()
		_tools.visible = with_tools
		add_child(_tools)
		_air = Control.new()
		_air.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_air.draw.connect(_draw_air)
		add_child(_air)
		_air_fx = Fx2D.new()
		_air_fx.buzzes = false
		_air.add_child(_air_fx)

	func _field_size() -> Vector2:
		return Vector2(cols, rows) * CELL + Vector2(PAD, PAD) * 2.0

	## The room the bed wants, at the game's size.
	func content_size() -> Vector2:
		var f := _field_size()
		var s := Vector2(maxf(f.x, TOOLS_W if with_tools else 0.0), f.y)
		if with_hud:
			s.y += HUD_H + GAP
		if with_tools:
			s.y += GAP + BADGE_RISE + TOOLS_H
		return s

	## Stands the row, the field and the tools in the middle of `room`.
	func place(room: Vector2) -> void:
		size = room
		var need := content_size()
		var f := _field_size()
		var at := ((room - need) * 0.5).floor()
		var y := at.y
		if with_hud:
			_hud.position = Vector2(at.x + (need.x - f.x) * 0.5, y)
			_hud.size = Vector2(f.x, HUD_H)
			y += HUD_H + GAP
		field.position = Vector2(at.x + (need.x - f.x) * 0.5, y)
		field.size = f
		y += f.y + GAP + BADGE_RISE
		_tools.position = Vector2(at.x + (need.x - TOOLS_W) * 0.5, y)
		_tools.size = Vector2(TOOLS_W, TOOLS_H)
		_air.position = Vector2.ZERO
		_air.size = room

	func _layout_field() -> void:
		_u = CELL
		_origin = Vector2(PAD, PAD)
		_bed = _build_bed()
		var box: Control = _banner.get_meta("box")
		box.position = Vector2(24, field.size.y * 0.32)
		box.size = Vector2(field.size.x - 48, 0)
		field.queue_redraw()

	func _bed_at(fx: float, fy: float) -> Vector2:
		return _in_air(field, field.size * Vector2(fx, fy))

	## A new plot: the one before drops away under it, as a day's does.
	func lay(plot: RefCounted) -> void:
		_disarm()
		if _offer != null:
			_offer.queue_free()
			_offer = null
		_press = Vector2i(-1, -1)
		_selected = Vector2i(-1, -1)
		_hint = []
		_queue.clear()
		_wait = 0.0
		_settle = false
		_over_said = false
		_stars = {}
		_rain = 0.0
		_flights.clear()
		_gift_owed.clear()
		sim = plot
		_take_events()
		for tool: int in _badges:
			_badges[tool].queue_redraw()

	## A gift is flown to its tool: only where the tools stand.
	func _take_events() -> void:
		for ev: Dictionary in sim.events:
			if String(ev.type) != "gift" or with_tools:
				_queue.append(ev)
		sim.events.clear()

	func _on_deal(ev: Dictionary) -> void:
		_dealing = true
		super(ev)
		_dealing = false

	func _on_clear(ev: Dictionary) -> void:
		super(ev)
		if not with_hud:
			# no plate to fly to
			_flights.clear()
			_owed.clear()

	## No move is shown to a bed left alone: the finger knows its own.
	func _animate(delta: float) -> void:
		_idle = 0.0
		super(delta)

	func _sticker(_text: String, _at: Vector2, _size: int, _life: float, _rainbow := true, _col := Color.WHITE, _rays := false, _id := "") -> void:
		pass

	func _show_banner(text: String, sub: String, hold: float, at_y := 0.32) -> void:
		if speaks and not _dealing:
			super(text, sub, hold, at_y)

	func _game_over() -> void:
		pass

	## The offer's card, small enough for the page.
	func _show_offer() -> void:
		super()
		_offer.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_offer.scale = Vector2(OFFER_SCALE, OFFER_SCALE)
		_offer.position = Vector2.ZERO
		_offer.size = size / OFFER_SCALE

	func offer_up() -> bool:
		return _offer != null

	## The finger on the field: down on `cell`, moved from it toward a
	## neighbour, or up.
	func touch(kind: int, cell: Vector2i, toward := Vector2i(-1, -1)) -> void:
		var at := px(cell.x, cell.y)
		if toward.x >= 0:
			at += Vector2(toward - cell) * _u * 0.5
		if kind == Touch.MOVE:
			var m := InputEventMouseMotion.new()
			m.position = at
			_on_field_input(m)
			return
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = kind == Touch.DOWN
		b.position = at
		_on_field_input(b)

	## Where a cell, a tool's chip and the offer's first button are, on the
	## canvas.
	func cell_spot(cell: Vector2i) -> Vector2:
		return field.get_global_transform() * px(cell.x, cell.y)

	func tool_spot(tool: int) -> Vector2:
		var b: Control = _tool_buttons[tool]
		return b.get_global_transform() * (b.size * 0.5)

	func take_spot() -> Vector2:
		var b: Control = _offer.find_child("Take", true, false) if _offer != null else null
		return b.get_global_transform() * (b.size * 0.5) if b != null else get_global_transform() * (size * 0.5)

# --- the lessons ---

## A lesson's bed, what stands with it, its scenes (each a bed and the
## finger's steps: say, swap, tap, tool, take, wait) and the bed it stands
## still on.
static func plan_of(which: int) -> Dictionary:
	var T := Sim.Tool
	match which:
		Lesson.SWAP:
			var bed := ["l- d- f- b- m- d-", "f- f- l- d- m- b-", "d- m- b- l- f- l-", "b- l- d- m- d- f-"]
			return {"scenes": [{"bed": bed, "feed": "bmd", "steps": [
					["swap", Vector2i(2, 0), Vector2i(2, 1)], ["wait", 0.5], ["swap", Vector2i(4, 2), Vector2i(5, 2)]]}],
				"still": {"bed": bed, "steps": [["tap", Vector2i(2, 0)]]}}
		Lesson.GOALS:
			var bed := ["d- f- b- m- l- d-", "f- m- f- d- b- l-", "b- d- m- l- d- l-", "m- b- d- b- l- m-"]
			var goals := [[0, 3], [1, 3]]
			return {"hud": true, "scenes": [{"bed": bed, "goals": goals, "moves": 4, "feed": "bdm", "steps": [
					["swap", Vector2i(1, 0), Vector2i(1, 1)], ["swap", Vector2i(4, 3), Vector2i(4, 2)], ["wait", 2.2]]}],
				"still": {"bed": bed, "goals": goals, "moves": 4, "feed": "bdm", "steps": [["swap", Vector2i(1, 0), Vector2i(1, 1)]]}}
		Lesson.SPECIALS:
			return {"cols": 7, "caption": true, "scenes": [
				{"bed": ["d- m- f- b- l- d- m-", "b- l- f- d- m- b- l-", "m- d- b- f- d- l- b-", "l- b- f- m- b- m- d-"],
					"feed": "dmlb", "steps": [["say", "TUT_POSY_CAP_BREEZE"], ["swap", Vector2i(3, 2), Vector2i(2, 2)],
						["say", "TUT_POSY_CAP_BREEZE_GO"], ["tap", Vector2i(2, 3)]]},
				{"bed": ["d- m- b- f- l- d- m-", "b- l- d- f- m- b- l-", "m- d- f- l- f- l- b-", "l- b- m- f- d- m- d-"],
					"feed": "dblm", "steps": [["say", "TUT_POSY_CAP_BOMB"], ["swap", Vector2i(3, 3), Vector2i(3, 2)],
						["say", "TUT_POSY_CAP_BOMB_GO"], ["tap", Vector2i(3, 2)]]},
				{"bed": ["d- m- b- l- m- d- b-", "b- l- d- f- l- b- m-", "m- f- f- d- f- f- l-", "l- b- m- d- b- m- d-"],
					"feed": "bddmddlddlmdbbbd", "steps": [["say", "TUT_POSY_CAP_RAINBOW"], ["swap", Vector2i(3, 1), Vector2i(3, 2)],
						["say", "TUT_POSY_CAP_RAINBOW_GO"], ["swap", Vector2i(3, 2), Vector2i(3, 3)]]},
				{"bed": ["d- m- l- d- m- l- b-", "m- f- f- l- d- m- d-", "l- f- d- f- m- l- m-", "d- l- m- d- l- d- l-"],
					"goals": [[4, 99]], "feed": "dmddmllldmdmdmdd", "steps": [["say", "TUT_POSY_CAP_BEE"], ["swap", Vector2i(3, 2), Vector2i(2, 2)],
						["say", "TUT_POSY_CAP_BEE_GO"], ["tap", Vector2i(2, 2)]]}],
				"still": {"bed": ["d- m- b- l- m- d- b-", "b- l= d- mo l- b- m-", "m- d- f- b- r- dz f-", "l- b- m- d- b- m- d-"],
					"steps": [["say", "TUT_POSY_CAP_STILL"]]}}
		Lesson.BLOCKERS:
			return {"cols": 7, "caption": true, "scenes": [
				{"bed": ["d- m- b- l- m- d- b-", "b- l- f- m- l- b- m-", "m- fw dw fw lw d- l-", "l- bw mw dw b- m- d-"],
					"feed": "mbmbmdddlbdldmmm", "steps": [["say", "TUT_POSY_CAP_WEED"],
						["swap", Vector2i(2, 1), Vector2i(2, 2)], ["wait", 0.6]]},
				{"bed": [".. m- f- l- m- d- ..", "b- f- l- f- l- b- m-", "m- d- ## b- d- l- b-", "l- b- ## d- b- m- d-"],
					"feed": "dmb", "steps": [["say", "TUT_POSY_CAP_STONE"],
						["swap", Vector2i(2, 0), Vector2i(2, 1)], ["wait", 0.6]]},
				{"bed": ["d- m- b- l- m- d- b-", "b- l- d- m- l- f- m-", "l- d- l- b- f- d- f-", "%% b- m- d- b- m- d-"],
					"feed": "dmb", "steps": [["say", "TUT_POSY_CAP_MOSS"],
						["swap", Vector2i(5, 1), Vector2i(5, 2)], ["wait", 0.5], ["say", "TUT_POSY_CAP_MOSS_GO"],
						["swap", Vector2i(1, 1), Vector2i(1, 2)]]}],
				"still": {"bed": [".. m- b- l- m- d- ..", "b- lw dw m- l- b- m-", "m- dw fw b- ## d- f-", "l- b- m- d- ## %% %%"],
					"steps": [["say", "TUT_POSY_CAP_STILL_BLOCK"]]}}
		Lesson.MOVES:
			var bed := ["l- d- f- b- m- d-", "f- f- l- d- m- b-", "d- m- b- l- f- l-", "b- l- d- m- d- f-"]
			var goals := [[0, 6, 1], [1, 6, 5]]
			return {"hud": true, "scenes": [{"bed": bed, "goals": goals, "moves": 1, "feed": "bmd", "steps": [
					["wait", 0.6], ["swap", Vector2i(2, 0), Vector2i(2, 1)], ["take"], ["wait", 1.2]]}],
				"still": {"bed": bed, "goals": goals, "moves": 1, "feed": "bmd", "steps": [["swap", Vector2i(2, 0), Vector2i(2, 1)]]}}
		Lesson.TOOLS:
			var bed := ["d- m- d- l- m- d- b-", "b- d- l- m- l- b- m-", "m- d- f- b- d- l- f-", "l- b- m- d- b- m- d-"]
			return {"cols": 7, "tools": true, "scenes": [{"bed": bed, "feed": "lfmdb", "steps": [
					["tool", T.TROWEL], ["tap", Vector2i(2, 2)],
					["tool", T.SWAP], ["tap", Vector2i(4, 0)], ["tap", Vector2i(5, 0)],
					["tool", T.BOMB], ["tap", Vector2i(5, 2)],
					["tool", T.RAINBOW], ["tap", Vector2i(1, 2)], ["wait", 0.8]]}],
				"still": {"bed": bed, "steps": [["tool", T.TROWEL]]}}
	return {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_plan = plan_of(lesson)
	if lesson == Lesson.BUTTONS:
		for id: String in Boosters.of("posy") + [Boosters.CHANCE]:
			var icon := BoosterIcon.new(id, 88.0)
			add_child(icon)
			_icons.append(icon)
	else:
		_bed = Bed.new()
		_bed.cols = int(_plan.get("cols", 6))
		_bed.with_hud = bool(_plan.get("hud", false))
		_bed.with_tools = bool(_plan.get("tools", false))
		_bed.speaks = _bed.with_tools
		add_child(_bed)
		_over = Control.new()
		_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_over.z_index = 6
		_over.draw.connect(_draw_finger)
		add_child(_over)
		_caption = Label.new()
		_caption.theme_type_variation = "SheetBodyDim"
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# One short line: a wrapping label measured before layout grows tall.
		_caption.clip_text = true
		_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_caption.visible = bool(_plan.get("caption", false))
		add_child(_caption)
	resized.connect(_layout)
	call_deferred("_layout")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun:
		call_deferred("_restart")

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if lesson == Lesson.BUTTONS:
		var row_h := size.y / 4.0
		for i in _icons.size():
			var icon: Control = _icons[i]
			icon.size = Vector2(88, 88)
			# the game's two boosters side by side, the Second chance under them
			icon.position = Vector2(36.0 + (100.0 * i if i < 2 else 50.0), row_h * (2.5 if i < 2 else 3.5) - 44.0)
		queue_redraw()
		return
	var cap := CAPTION_H if _caption.visible else 0.0
	var room := Vector2(size.x, size.y - cap)
	var need := _bed.content_size()
	var k := minf(1.0, minf(room.x / need.x, room.y / need.y))
	_bed.scale = Vector2(k, k)
	_bed.position = Vector2.ZERO
	_bed.place(room / k)
	_caption.position = Vector2(20.0, size.y - CAPTION_H)
	_caption.size = Vector2(size.x - 40.0, CAPTION_H - 6.0)
	_over.position = Vector2.ZERO
	_over.size = size
	if not _begun and is_inside_tree():
		_begun = true
		_restart()

func _restart() -> void:
	if lesson == Lesson.BUTTONS or not is_inside_tree() or size.x <= 0.0:
		return
	_stopped = false
	_seen = false
	_fdown = false
	_fpos = Vector2(size.x * 0.5, size.y + 60.0)
	_scene = 0
	_caption.text = ""
	_open(_plan.still if Motion.reduce else _plan.scenes[0])

## Lays a scene and writes the finger's steps out as what it does a moment
## at a time.
func _open(scene: Dictionary) -> void:
	_bed.lay(Plot.new(scene))
	var T := Bed.Touch
	_ops = []
	var dealt := false
	for s: Array in scene.steps:
		# the scene's first words come with its bed, then the deal settles
		if not dealt and String(s[0]) != "say":
			dealt = true
			_ops.append({"op": "rest", "secs": 0.3})
		match String(s[0]):
			"say":
				_ops.append({"op": "say", "key": s[1]})
			"wait":
				_ops.append({"op": "wait", "secs": s[1]})
			"swap":
				_ops.append({"op": "go", "to": ["cell", s[1]], "secs": GO})
				_ops.append({"op": "touch", "kind": T.DOWN, "cell": s[1]})
				_ops.append({"op": "wait", "secs": TAP_DOWN})
				_ops.append({"op": "touch", "kind": T.MOVE, "cell": s[1], "toward": s[2]})
				_ops.append({"op": "go", "to": ["cell", s[2]], "secs": DRAG_T})
				_ops.append({"op": "touch", "kind": T.UP, "cell": s[2]})
				_ops.append({"op": "rest", "secs": REST})
			"tap":
				_ops.append({"op": "go", "to": ["cell", s[1]], "secs": GO})
				_ops.append({"op": "touch", "kind": T.DOWN, "cell": s[1]})
				_ops.append({"op": "wait", "secs": TAP_DOWN})
				_ops.append({"op": "touch", "kind": T.UP, "cell": s[1]})
				_ops.append({"op": "rest", "secs": REST})
			"tool":
				_ops.append({"op": "go", "to": ["tool", s[1]], "secs": GO})
				_ops.append({"op": "press", "down": true})
				_ops.append({"op": "tool", "tool": s[1]})
				_ops.append({"op": "wait", "secs": TAP_DOWN})
				_ops.append({"op": "press", "down": false})
				_ops.append({"op": "wait", "secs": 0.8})
			"take":
				_ops.append({"op": "offer"})
				_ops.append({"op": "wait", "secs": 1.6})
				_ops.append({"op": "go", "to": ["take"], "secs": GO})
				_ops.append({"op": "press", "down": true})
				_ops.append({"op": "wait", "secs": TAP_DOWN})
				_ops.append({"op": "take"})
				_ops.append({"op": "press", "down": false})
				_ops.append({"op": "rest", "secs": REST})
	_ops.append({"op": "wait", "secs": 1.0})
	_op = 0
	_entered = false

func _process(delta: float) -> void:
	if lesson == Lesson.BUTTONS or not _begun or _stopped:
		return
	_t += delta
	while _op < _ops.size():
		var o: Dictionary = _ops[_op]
		if not _entered:
			_entered = true
			_t = 0.0
			_enter(o)
		if not _done(o):
			_over.queue_redraw()
			return
		_op += 1
		_entered = false
	_over.queue_redraw()
	if Motion.reduce:
		# standing still on what the steps left
		_stopped = true
		return
	_scene = (_scene + 1) % (_plan.scenes as Array).size()
	_open(_plan.scenes[_scene])

## What a moment does as it starts.
func _enter(o: Dictionary) -> void:
	match String(o.op):
		"say":
			_caption.text = tr(String(o.key))
		"go":
			_from = _fpos
			_seen = true
		"touch":
			if int(o.kind) != Bed.Touch.MOVE:
				_fdown = int(o.kind) == Bed.Touch.DOWN
			_bed.touch(int(o.kind), o.cell, o.get("toward", Vector2i(-1, -1)))
		"press":
			_fdown = bool(o.down)
		"tool":
			_bed._on_tool(int(o.tool))
		"take":
			_bed._take_offer()

## Whether a moment is over: the finger there, the wait up, the bed still.
func _done(o: Dictionary) -> bool:
	var still := Motion.reduce
	match String(o.op):
		"go":
			var k := 1.0 if still else clampf(_t / float(o.secs), 0.0, 1.0)
			_fpos = _from.lerp(_spot(o.to), k * k * (3.0 - 2.0 * k))
			return k >= 1.0
		"wait":
			return still or _t >= float(o.secs)
		"rest":
			if _bed.busy():
				_t = 0.0
				return false
			return still or _t >= float(o.secs)
		"offer":
			return _bed.offer_up()
	return true

## Where the finger is going, on the page.
func _spot(to: Array) -> Vector2:
	var at: Vector2
	match String(to[0]):
		"cell":
			at = _bed.cell_spot(to[1])
		"tool":
			at = _bed.tool_spot(int(to[1]))
		_:
			at = _bed.take_spot()
	return get_global_transform().affine_inverse() * at

# --- drawing ---

func _draw_finger() -> void:
	if not _seen or Motion.reduce:
		_finger_shown = null
		return
	var u: float = _bed.scale.x
	var r := 44.0 * u * (0.85 if _fdown else 1.0)
	var at := _fpos + Vector2(0, 0.0 if _fdown else -12.0 * u)
	var b := Face.Builder.new()
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.8 if _fdown else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.5), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)

## The BUTTONS page: Reset and ? as the top bar has them, the game's two
## boosters and the Second chance, each beside what it does.
func _draw() -> void:
	if lesson != Lesson.BUTTONS or size.x <= 0.0:
		return
	var rows := [["reset", tr("TUT_POSY_HUD_RESET")], ["help", tr("TUT_POSY_HUD_HELP")],
		["", tr("TUT_POSY_HUD_BOOST")], ["", tr("TUT_POSY_HUD_CHANCE") % Boosters.PO_CHANCE_MOVES]]
	var row_h := size.y / rows.size()
	var chip := 88.0
	var x0 := 36.0
	var wide := 188.0
	var b := Face.Builder.new()
	var rects: Array = []
	for k in rows.size():
		var r := Rect2(Vector2(x0 + (wide - chip) * 0.5, row_h * (k + 0.5) - chip * 0.5), Vector2(chip, chip))
		rects.append(r)
		if String(rows[k][0]) != "":
			b.polygon(Face.Builder.round_rect(r.position + Vector2(0, 6.0), r.size, 26.0), Color(Pal.TEXT, 0.16))
			b.polygon(Face.Builder.round_rect(r.position, r.size, 26.0), Pal.SURFACE)
	_hud_shown = b.mesh()
	draw_mesh(_hud_shown, null)
	var font: Font = CozyTheme.display(700)
	var tx := x0 + wide + 28.0
	for k in rows.size():
		var r: Rect2 = rects[k]
		if String(rows[k][0]) != "":
			Icons.paint(self, String(rows[k][0]), Rect2(r.get_center() - Vector2(chip, chip) * 0.27, Vector2(chip, chip) * 0.54), Pal.TEXT, Pal.SURFACE)
		var line := String(rows[k][1])
		var lines := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, size.x - tx - 24.0, 28)
		draw_multiline_string(font, Vector2(tx, r.get_center().y - lines.y * 0.5 + 28.0 * 0.82), line, HORIZONTAL_ALIGNMENT_LEFT, size.x - tx - 24.0, 28, -1, Pal.TEXT)
