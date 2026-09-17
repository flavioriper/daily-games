extends "res://core/turn_base.gd"

## How Big? -- phase 1's turn. The scout stands on a dock at a stated height,
## and beside him the day's thing from the model set stands as a black
## silhouette at the scout's own height, plainly the wrong size. The player
## drags its top up or down until it looks right, and locks. The silhouette
## stays where the guess stood, gone see-through, the real thing grows into
## its true size beside it, and the score is how far off the guess was as a
## ratio -- twice too big and half too small score the same.
##
## The camera does not move. The roadmap had it pull back on the reveal, but
## with a table of things that all fit four scout heights there is nothing to
## pull back for, a still camera keeps the finger honest (what it points at
## is what moves), and the landscape does not slide under a zoom. The oak and
## the tall tree stay out of the table for that reason.
## Roadmap: docs/brainstorm/single-turn-roadmap.md, phase 1.

const Models = preload("res://core/models.gd")
const Scenery = preload("res://world/scenery.gd")
const Toon = preload("res://core/toon.gd")
const Motion = preload("res://core/motion.gd")
const Backend = preload("res://core/backend.gd")
const DailySeed = preload("res://core/daily.gd")
const Mascot = preload("res://world/mascot.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Stage = preload("res://world/stage.gd")
const Pal = preload("res://core/palette.gd")

const GAME := "how_big"
## The dock, in cells: strips across, their tops at the board plane. Kept
## narrow on purpose: the slot is portrait and the dock's width is what binds
## the fit, so every unit of width here is more than a unit of empty sky
## framed above the tallest guess.
const DOCK := Vector2i(5, 3)
## Where the scout stands, and the edge the thing's near side is held to: a
## small thing stands right beside him, a big one grows away from him.
const SCOUT_X := -1.9
const SCOUT_YAW := 0.3
const TARGET_LEFT := -0.6
## The thing may grow to here before the frame's edge, whatever its shape.
const TARGET_RIGHT := 2.5
## Headroom framed over the tallest guess.
const HEADROOM := 0.3
## The grade: within this ratio is 100, at this ratio or worse is 0, linear
## in the log between. Tuned from the first week's tally, not by hand.
const EXACT_RATIO := 1.06
const ZERO_RATIO := 5.0
const REVEAL_TIME := 0.7
## The silhouette's ink, and how far it fades once the real thing stands.
const INK := Pal.OUTLINE
const GHOST_ALPHA := 0.3
## The share card's ruler.
const GLYPHS := 10

static var _table: Dictionary = {}

## The day's thing, its true height, and what the player has it at.
var _it: Dictionary = {}
var _truth := 1.0
var _metres := 1.0
var _min_m := 0.1
var _max_m := 4.2
var _scout_m := 1.2
## World units per metre: the scout's modelled height over his stated one.
var _upm := 1.0
var _touched := false
var _dragging := false

var _scout: Node3D
## The silhouette the player sizes; after the lock it is the guess, left standing.
var _target: Node3D
var _target_box: AABB
## The real thing, in colour and at its true size; only after the lock.
var _real: Node3D

func turn_id() -> String: return GAME
func title() -> String: return tr("HOWBIG_TITLE")
func motto() -> String: return tr("HOWBIG_MOTTO")
func footer() -> String: return tr("HOWBIG_FOOTER")
func prompt_text() -> String:
	return tr("HOWBIG_PROMPT") % [Locale.number(_scout_m, 1), tr(str(_it.get("label", "")))]

func board_size() -> Vector2i: return DOCK
func board_height() -> float: return _max_m * _upm + HEADROOM
func plane_height() -> float: return 0.0
## The dock's thickness, framed below the plane.
func board_depth() -> float: return Placeholders.DECK_H
func board_margin() -> float: return 0.3
## Figures standing on a dock are looked at level, the way the campsite is:
## the face angle is the camera's own, so the stage leans the board by
## nothing and nobody stands tilted toward the lens.
func board_pitch() -> float: return Stage.CAMERA_PITCH

func has_input() -> bool: return _touched
func guess() -> Variant: return snappedf(_metres, 0.01)

# --- content ---

static func table() -> Dictionary:
	if _table.is_empty():
		_table = Backend.bundled(GAME)
	return _table

## The day's item and its height. A published day names both, and a
## published height wins over the table's -- that is what lets a day be hand
## picked. A phone that never reached the network, or a day naming a thing
## this build does not know, derives the item from the day key exactly as
## the server does (server/functions/src/index.ts, GAMES).
func _resolve() -> void:
	var t := table()
	_scout_m = float(t.get("scout_m", 1.2))
	_min_m = float(t.get("min_m", 0.1))
	_max_m = float(t.get("max_m", 4.2))
	var items: Array = t.get("items", [])
	_it = {}
	var wanted := str(content.get("item", ""))
	for it in items:
		if str(it.get("id", "")) == wanted:
			_it = it
	if _it.is_empty() and not items.is_empty():
		_it = items[DailySeed.fnv1a("%s|%d" % [GAME, DailySeed.date_key()]) % items.size()]
		_truth = float(_it.get("metres", 1.0))
	else:
		_truth = float(content.get("metres", _it.get("metres", 1.0)))

# --- the scene ---

func build_turn(_content: Dictionary) -> void:
	_resolve()
	board.add_child(Scenery.deck(-DOCK.x * 0.5, DOCK.x * 0.5, -DOCK.y * 0.5, DOCK.y * 0.5))

	_scout = Mascot.new()
	_scout.name = "Scout"
	_scout.position = Vector3(SCOUT_X, 0.0, 0.0)
	_scout.rotation.y = SCOUT_YAW
	board.add_child(_scout)
	# His modelled height is what a metre is measured against. Off the tree
	# the mascot has no model yet; the contract's height for the slot stands in.
	var scout_h := _box_of(_scout.model).size.y if _scout.model != null else 1.07
	_upm = scout_h / _scout_m

	var pivot := Scenery.prop(str(_it.get("slot", "peg")), Vector3(TARGET_LEFT, 0.0, 0.0), 0.0, Vector3.ONE)
	pivot.name = "Target"
	Models.silhouette(pivot.get_child(0), INK)
	board.add_child(pivot)
	_target = pivot
	_target_box = _box_of(pivot.get_child(0))
	# A thing so wide at the tallest guess that it would leave the frame is
	# capped by its width instead: a fence four metres tall is eight wide.
	if _target_box.size.x > 0.0 and _target_box.size.y > 0.0:
		var by_width := (TARGET_RIGHT - TARGET_LEFT) * _target_box.size.y / _target_box.size.x / _upm
		_max_m = minf(_max_m, by_width)
	# It starts at the scout's own height: a neutral wrong size, telling the
	# player nothing about where the truth lies.
	_metres = clampf(_scout_m, _min_m, _max_m)
	_place(_target, _target_box, _metres)
	_refit()

## Every mesh's box under `root`, in the space `root` stands in, outline
## shells excluded. Walked by hand from the local transforms, so it answers
## the same whether or not the model is in the tree yet.
static func _box_of(root: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect(root, Transform3D.IDENTITY, boxes)
	var box := AABB()
	for i in boxes.size():
		box = boxes[i] if i == 0 else box.merge(boxes[i])
	return box

static func _collect(node: Node3D, xf: Transform3D, boxes: Array[AABB]) -> void:
	if node.name == Toon.OUTLINE_NODE:
		return
	var t := xf * node.transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		boxes.append(t * (node as MeshInstance3D).mesh.get_aabb())
	for child in node.get_children():
		if child is Node3D:
			_collect(child, t, boxes)

## Stands `pivot`'s model at `m` metres tall: scaled about its base, and slid
## so its near side stays on TARGET_LEFT as it grows.
func _place(pivot: Node3D, box: AABB, m: float) -> void:
	if box.size.y <= 0.0:
		return
	var s := m * _upm / box.size.y
	var model := pivot.get_child(0) as Node3D
	model.scale = Vector3.ONE * s
	pivot.position.x = TARGET_LEFT - box.position.x * s

# --- the gesture ---

## Direct manipulation: the finger holds the thing's top. StageView's own
## handler only passes a touch on when its ray meets the board plane, and at
## the stage's seven-degree pitch the top half of the screen is sky, where a
## tall thing's top has to be dragged to -- so this takes the raw touch and
## meets the ray with the thing's own frontal plane instead.
func _gui_input(event: InputEvent) -> void:
	if not accepts_input():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_drag_to(event.position)
		else:
			_dragging = false
	elif event is InputEventScreenDrag and _dragging:
		_drag_to(event.position)

func _drag_to(local: Vector2) -> void:
	var ray := local_ray(local)
	if ray.is_empty():
		return
	var origin: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	if absf(dir.z) < 1e-6:
		return
	var t := (0.0 - origin.z) / dir.z
	if t < 0.0:
		return
	var top := origin.y + dir.y * t - plane_height()
	_set_metres(clampf(top / _upm, _min_m, _max_m))

func _set_metres(m: float) -> void:
	# The first touch counts even when it lands on the size already shown: it
	# is what lights Lock, so it has to reach the host.
	var first := not _touched
	_touched = true
	if is_equal_approx(m, _metres) and not first:
		return
	_metres = m
	_place(_target, _target_box, _metres)
	input_changed.emit()

## Puts a restored day's guess back, so a reopened card shows what was
## locked in rather than the fresh turn's start.
func apply_guess(the_guess) -> void:
	_touched = true
	_metres = clampf(float(the_guess), _min_m, _max_m)
	_place(_target, _target_box, _metres)

# --- the reveal ---

## The silhouette stays behind as the guess, gone see-through; the real thing
## appears in its place and grows or shrinks to the truth. With `animate`
## false (a day already played, reopened) both simply stand.
func reveal(animate := true) -> void:
	Models.silhouette(_target.get_child(0), INK, GHOST_ALPHA)
	_real = Scenery.prop(str(_it.get("slot", "peg")), Vector3(TARGET_LEFT, 0.0, 0.0), 0.0, Vector3.ONE)
	_real.name = "Real"
	board.add_child(_real)
	if animate and not Motion.reduce:
		_place(_real, _target_box, _metres)
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(m: float) -> void: _place(_real, _target_box, m), _metres, _truth, REVEAL_TIME)
		await tw.finished
	else:
		_place(_real, _target_box, _truth)

# --- the grade ---

func grade(_answer_in) -> int:
	return score_for(_metres, _truth)

## Symmetric in the ratio: twice too big and half too small score the same.
static func score_for(the_guess: float, truth: float) -> int:
	if the_guess <= 0.0 or truth <= 0.0:
		return 0
	var r := maxf(the_guess / truth, truth / the_guess)
	var e := (log(r) - log(EXACT_RATIO)) / (log(ZERO_RATIO) - log(EXACT_RATIO))
	return clampi(int(round(100.0 * (1.0 - clampf(e, 0.0, 1.0)))), 0, 100)

## "30% too big", "12% too small", or "spot on" inside the exact band.
func _verdict() -> String:
	var r := _metres / _truth if _truth > 0.0 else 1.0
	if maxf(r, 1.0 / r) <= EXACT_RATIO:
		return tr("HOWBIG_SPOT")
	if r > 1.0:
		return tr("HOWBIG_OVER") % Locale.number(round((r - 1.0) * 100.0))
	return tr("HOWBIG_UNDER") % Locale.number(round((1.0 - r) * 100.0))

## Metres, to the precision the thing deserves: centimetres under a metre.
func _fmt(m: float) -> String:
	return Locale.number(m, 2 if _truth < 1.0 else 1)

static func _cap(s: String) -> String:
	return s if s.is_empty() else s[0].to_upper() + s.substr(1)

func result_text() -> String:
	return tr("HOWBIG_RESULT") % [_cap(tr(str(_it.get("label", "")))), _fmt(_truth), _fmt(_metres), _verdict()]

func share_text() -> String:
	return tr("HOWBIG_SHARE") % [str(DailySeed.date_key()), tr(str(_it.get("label", ""))), _fmt(_metres), _fmt(_truth), _verdict()]

func share_glyphs() -> String:
	var lit := int(round(grade(null) / 100.0 * GLYPHS))
	var out := ""
	for i in GLYPHS:
		out += "🟩" if i < lit else "⬜"
	return out
