extends RefCounted

## One indexed mesh put together, every frame if need be, from shapes made
## once: Nonogram's floor (2026-10-02) made shared at Queens' checkup.
##
## A shape is drawn once about its own origin in slot colours (`slot`), so its
## colour runs are known and painting it any colours is one fill a run, and
## copied natively under its transform. Every piece owns a run of vertices
## laid out for it at layout (`room`), as long as its largest look, so a
## shape's indices are offset once per run and kept; a piece that outgrows
## its run goes on the tail, after every run, its indices offset in script.
## Pieces must be put in the order their runs were laid: that order is the
## paint order.
##
##     var rm := RunMesh.new(func(id: int) -> Face.Builder: ...)
##     rm.reset()                       # on layout: forget runs and shapes
##     rm.room(PART_X, k, rm.size_of(SHAPE_X) * 2)
##     rm.begin()                       # every build
##     rm.open(PART_X, k); rm.put(SHAPE_X, [ink], xf)
##     var m := rm.mesh()

const Face = preload("res://ui/faces/face.gd")

## How many colour slots a shape can have.
const SLOTS := 8.0
## The painted colours kept before the cache starts again.
const PAINTED_MAX := 4000
## The same for indices offset to a place on the tail.
const OFFSETS_MAX := 2000

var _make: Callable
var _shapes: Dictionary = {}   # id -> [verts, indices, colour runs]
var _inked: Dictionary = {}    # [id, colours...] -> PackedColorArray
var _offsets: Dictionary = {}  # Vector2i(id, at) -> indices offset to at
var _tail_offsets: Dictionary = {}  # Vector2i(id, at) on the tail -> the same
var _runs: Dictionary = {}     # Vector2i(part, index) -> Vector2i(start, size)
var _fixed := 0
var _cursor := 0
var _run_end := -1
var _fv := PackedVector2Array()
var _fc := PackedColorArray()
var _fi := PackedInt32Array()
var _tv := PackedVector2Array()
var _tc := PackedColorArray()

## `make(id)` draws shape `id` about its origin into a Face.Builder, in slot
## colours.
func _init(make: Callable) -> void:
	_make = make

## The colour a shape is drawn in for slot `k`, read back by `shape`.
static func slot(k: int) -> Color:
	return Color(float(k) / SLOTS, 0.0, 0.0, 1.0)

## Forgets every run, shape and painted colour: the layout changed.
func reset() -> void:
	_runs = {}
	_shapes = {}
	_inked = {}
	_offsets = {}
	_tail_offsets = {}
	_fixed = 0

## Whether runs have been laid since the last reset.
func laid() -> bool:
	return not _runs.is_empty()

## Lays the next run, `verts` long, for piece (`part`, `index`).
func room(part: int, index: int, verts: int) -> void:
	_runs[Vector2i(part, index)] = Vector2i(_fixed, verts)
	_fixed += verts

## How many vertices shape `id` has.
func size_of(id: int) -> int:
	return (shape(id)[0] as PackedVector2Array).size()

## Shape `id` as [verts, indices, colour runs, colours as drawn], made the
## first time it is asked for. Its colour runs are (count, slot * 2 + clear)
## pairs: a fan's body is one run and its feather another.
func shape(id: int) -> Array:
	var hit = _shapes.get(id)
	if hit != null:
		return hit
	var b: Face.Builder = _make.call(id)
	var runs := PackedInt32Array()
	var last := -1
	for c in b.cols:
		var code := roundi(c.r * SLOTS) * 2 + (1 if c.a < 0.5 else 0)
		if code == last:
			runs[runs.size() - 2] += 1
		else:
			runs.append(1)
			runs.append(code)
			last = code
	var out := [b.verts, b.idx, runs, b.cols]
	_shapes[id] = out
	return out

## Shape `id`'s colours with its slots painted `colours`: kept, since most
## pieces wear the same ones frame after frame.
func ink(id: int, colours: Array) -> PackedColorArray:
	var key := [id] + colours
	var hit = _inked.get(key)
	if hit != null:
		return hit
	if _inked.size() > PAINTED_MAX:
		_inked = {}
	var runs: PackedInt32Array = shape(id)[2]
	var out := PackedColorArray()
	var run := PackedColorArray()
	for i in range(0, runs.size(), 2):
		var code := runs[i + 1]
		var c: Color = colours[code >> 1]
		run.resize(runs[i])
		run.fill(Color(c, 0.0) if code & 1 else c)
		out.append_array(run)
	_inked[key] = out
	return out

## A new build.
func begin() -> void:
	_fv = PackedVector2Array()
	_fc = PackedColorArray()
	_fi = PackedInt32Array()
	_tv = PackedVector2Array()
	_tc = PackedColorArray()
	_close()

## The next pieces go into run (`part`, `index`).
func open(part: int, index: int) -> void:
	var run: Vector2i = _runs.get(Vector2i(part, index), Vector2i(0, -1))
	if run.y < 0:
		_close()
		return
	_cursor = run.x
	_run_end = run.x + run.y

## The next pieces go on the tail, after every run (a live drawing that has
## no run of its own; the indices keep the order things are put in).
func close() -> void:
	_close()

func _close() -> void:
	_cursor = 0
	_run_end = -1

## Shape `id` painted `colours` under `xf`, into the open run while it has
## room, or on the tail. No `colours` puts the shape in the colours it was
## drawn in: a still drawing with more colours than slots (Sudoku's tray).
func put(id: int, colours: Array, xf: Transform2D) -> void:
	var s := shape(id)
	var verts: PackedVector2Array = s[0]
	var n := verts.size()
	var cols: PackedColorArray = s[3] if colours.is_empty() else ink(id, colours)
	if _cursor + n > _run_end:
		_tail(verts, cols, s[1], xf, id)
		return
	_fv.resize(_cursor)
	_fc.resize(_cursor)
	_fv.append_array(verts if xf == Transform2D.IDENTITY else xf * verts)
	_fc.append_array(cols)
	var key := Vector2i(id, _cursor)
	var ix = _offsets.get(key)
	if ix == null:
		ix = (s[1] as PackedInt32Array).duplicate()
		for k in ix.size():
			ix[k] += _cursor
		_offsets[key] = ix
	_fi.append_array(ix)
	_cursor += n

## A drawing made this frame (a Builder): into the open run while it has
## room, its indices offset in script, or on the tail when no run is open or
## it does not fit.
func put_builder(b: Face.Builder) -> void:
	var n := b.verts.size()
	if n == 0:
		return
	if _cursor + n > _run_end:
		_tail(b.verts, b.cols, b.idx, Transform2D.IDENTITY)
		return
	_fv.resize(_cursor)
	_fc.resize(_cursor)
	_fv.append_array(b.verts)
	_fc.append_array(b.cols)
	var ix := b.idx.duplicate()
	for k in ix.size():
		ix[k] += _cursor
	_fi.append_array(ix)
	_cursor += n

## A shape (`id` >= 0) put on the tail keeps its offset indices for that
## place, as a run does: pieces put first on the tail (Sudoku's washes, one
## shape cell after cell) land on the same places build after build, so a
## piece that comes and goes needs no run reserved for it.
func _tail(verts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, xf: Transform2D, id := -1) -> void:
	var base := _fixed + _tv.size()
	_tv.append_array(verts if xf == Transform2D.IDENTITY else xf * verts)
	_tc.append_array(cols)
	var key := Vector2i(id, base)
	var ix = _tail_offsets.get(key) if id >= 0 else null
	if ix == null:
		ix = idx.duplicate()
		for k in ix.size():
			ix[k] += base
		if id >= 0:
			if _tail_offsets.size() > OFFSETS_MAX:
				_tail_offsets = {}
			_tail_offsets[key] = ix
	_fi.append_array(ix)

## The build as one mesh, or null when nothing was put.
func mesh() -> ArrayMesh:
	if _fi.is_empty():
		return null
	_fv.resize(_fixed)
	_fc.resize(_fixed)
	_fv.append_array(_tv)
	_fc.append_array(_tc)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _fv
	arrays[Mesh.ARRAY_COLOR] = _fc
	arrays[Mesh.ARRAY_INDEX] = _fi
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
