extends "res://core/puzzle_base.gd"

## Knight as a flat board: a paper chessboard on a garden table. Your cream
## knight hops in Ls; take the rose king to win. The king never moves, but
## one to three rose knights stand guard and answer every move you make,
## hopping toward you. Land where one can reach and it takes you: the board
## shakes, holds a beat and slides back one move. The rules live in
## puzzles/knight_state.gd, which this only draws.
##
## Nothing wrong can sit on the board (a catch is undone as it happens), so
## no Check, no tray and no actions row: Undo, Reset and Hint ride in the
## top bar -- Pinwheel's shape.
##
## How it is drawn. Two meshes:
##   still -- the frame and the squares, rebuilt only on a relayout;
##   live  -- the trail, the marks and every piece, rebuilt only while
##            something moves. At rest nothing rebuilds.
## The pieces are ui/faces/chess_piece.gd, which the menu card draws too.
##
## Spec: docs/superpowers/specs/2026-09-26-knight-flat-design.md, section 7.
## Ported from the canvas mock at docs/brainstorm/concepts.html#knight, the
## reference for every measure.

const State = preload("res://puzzles/knight_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Piece = preload("res://ui/faces/chess_piece.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

const INSET := 70.0
const CELL_CAP := 170.0
const FRAME := 24.0
const FRAME_R := 30.0
## The hop: how long, and how high its arc rises at mid-flight, in cells.
const JUMP_TIME := 0.3
const HOP_ARC := 0.55
## A landing's squash: how long, and how deep.
const LAND_TIME := 0.2
const LAND_SQUASH := 0.14
## The rose side's answer: the beat after you land, then each next knight's.
const ANSWER_GAP := 0.08
const ANSWER_STEP := 0.09
## A catch: the hold before the board slides back, and the slide.
const CAUGHT_HOLD := 0.55
const SLIDE_BACK := 0.32
## A taken rose knight squashes flat and fades over this.
const TAKE_TIME := 0.25
## The marks fade in over this once the board is still.
const MARK_FADE := 0.2
## The win: the king tips this far (radians) over this long, then the wait.
const TOPPLE := 1.2
const TOPPLE_TIME := 0.45
const WIN_WAIT := 2.2
const HINTS := 3
## Insane's moves-left line under the board.
const BUDGET_FONT := 40
const BUDGET_DROP := 64.0
const TIP_CYCLE := 8.0
const TIPS := ["KN_TIP_TAP", "KN_TIP_GOAL", "KN_TIP_ANSWER", "KN_TIP_CORNERS", "KN_TIP_TAKE"]

var _state = State.new()
var fx: Node2D

## How each piece is travelling: {"from", "to" (squares; -1 off the board),
## "at", "dur", "arc" (cells; 0 slides), "pop" (pops in at `to`)}.
var _you_a := {}
var _foe_a: Array = []
## Rose knights taken this turn, still fading where they stood: {"c", "at"}.
var _gone: Array = []
## A catch in progress: {"at"} when the rose knight lands on you; empty when none.
var _caught := {}
var _shake_at := -100.0
## Which turn the timers _play schedules belong to: a Reset, an Undo, a
## catch's slide-back or a new deal bumps it, and a stale timer does nothing.
var _turn := 0
## Your knight's shiver on a refused tap.
var _bump_at := -100.0
var _rings: Array = []

var _opened := 0.0
## Input waits, and the marks hide, until this.
var _busy_until := -100.0
var _anim_until := 0.0
var _solved_at := -1.0
var _still: ArrayMesh
var _live: ArrayMesh
## The meshes the last _draw handed over: a canvas command holds a mesh by
## RID, so dropping the only reference leaves the renderer a freed one.
var _shown: Array = []
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "knight"
func title() -> String: return "Knight"

func rules() -> String:
	return tr("KN_RULES")

## Undo and Hint; Reset is the host's. No Check: a catch is the check.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_state.build(rng, difficulty)
	_turn += 1
	_snap_to_state()
	_rings = []
	_shake_at = -100.0
	_bump_at = -100.0
	_solved_at = -1.0
	_opened = _now()
	# The marks wait for the pieces' entrance, then fade in.
	if not Motion.reduce:
		_busy_until = _opened + Motion.ENTER_DELAY + 0.2 \
			+ Motion.stagger(_state.foes.size() + 1, 0.07) + Motion.POP_IN
		_busy_for(_busy_until - _now() + MARK_FADE)
	_layout()
	fx.cue("enter")
	_tip_idx = 0
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	_tip_timer.start()

static func _still_at(c: int) -> Dictionary:
	return {"from": c, "to": c, "at": -100.0, "dur": 1.0, "arc": 0.0, "pop": false}

## Every piece drawn where the state has it, nothing moving.
func _snap_to_state() -> void:
	_you_a = _still_at(_state.you)
	_foe_a = []
	for f in _state.foes:
		_foe_a.append(_still_at(f))
	_gone = []
	_caught = {}
	_busy_until = -100.0
	_anim_until = 0.0
	_refresh()

# --- layout ---

func _cell() -> float:
	if _state.w <= 0:
		return 0.0
	return maxf(0.0, minf(CELL_CAP, minf(size.x - 2.0 * INSET, size.y - 2.0 * INSET) / float(_state.w)))

func _grid_size() -> Vector2:
	return Vector2.ONE * float(_state.w) * _cell()

func _origin() -> Vector2:
	return (size - _grid_size()) * 0.5

func _centre(c: int) -> Vector2:
	return _origin() + (Vector2(c % _state.w, c / _state.w) + Vector2(0.5, 0.5)) * _cell()

## Control-local point over the centre of the square at (row, column), the
## name every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(r * _state.w + c)

func card_height(available: float) -> float:
	return available

## The board is square and the slot is tall: halve the slack.
func card_centred() -> bool:
	return true

func _layout() -> void:
	_still = null
	_refresh()

func _square_at(local: Vector2) -> int:
	var s := _cell()
	if s <= 0.0:
		return -1
	var v := (local - _origin()) / s
	var x := int(floor(v.x))
	var y := int(floor(v.y))
	if x < 0 or y < 0 or x >= _state.w or y >= _state.w:
		return -1
	return y * _state.w + x

# --- the pieces in motion ---

## Where a travelling piece is at `t`: {"at" (px), "lift" (px), "land"
## (when it lands)}; empty when it is off the board.
func _where(a: Dictionary, t: float) -> Dictionary:
	if int(a.to) < 0:
		return {}
	var from: int = a.from if int(a.from) >= 0 else a.to
	var u := 1.0 if Motion.reduce else clampf((t - float(a.at)) / maxf(float(a.dur), 0.001), 0.0, 1.0)
	var e := 0.5 - 0.5 * cos(PI * u)
	return {"at": _centre(from).lerp(_centre(a.to), e), "lift": sin(PI * u) * float(a.arc) * _cell(),
		"land": float(a.at) + float(a.dur)}

func _land_squash(land: float, t: float) -> Vector2:
	var u := (t - land) / LAND_TIME
	if Motion.reduce or u < 0.0 or u >= 1.0:
		return Vector2.ONE
	var k := sin(PI * u) * LAND_SQUASH
	return Vector2(1.0 + k * 0.5, 1.0 - k)

func _jump() -> float:
	return 0.0 if Motion.reduce else JUMP_TIME

## One hop of yours and the rose side's answer, animated. A catch holds, then
## everything slides back; the state never kept it.
func _play(to: int, from_hint := false) -> void:
	var t := _now()
	if is_done() or t < _busy_until:
		return
	if not _state.legal().has(to):
		_refuse("KN_L")
		return
	if _state.moves_left() == 0:
		_refuse("KN_NO_MOVES")
		return
	var from: int = _state.you
	var r: Dictionary = _state.play(to)
	var jt := _jump()
	var land := t + jt
	_you_a = {"from": from, "to": to, "at": t, "dur": maxf(jt, 0.001), "arc": HOP_ARC, "pop": false}
	fx.cue("hop")
	var took: int = r.took
	if took >= 0:
		_gone.append({"c": to, "at": land})
		_foe_a[took] = _still_at(-1)
		var turn := _turn
		_later(jt, func():
			if turn != _turn:
				return
			fx.puff(_centre(to), Pal.KNIGHT_ROSE, 7)
			fx.cue("take"))
	var last := land
	var k := 0
	var moved: Array = r.moved
	for i in moved.size():
		var mv: Vector2i = moved[i]
		if i == took or mv.x < 0 or mv.y < 0 or mv.x == mv.y:
			continue
		var at := land + (0.0 if Motion.reduce else ANSWER_GAP + Motion.stagger(k, ANSWER_STEP))
		_foe_a[i] = {"from": mv.x, "to": mv.y, "at": at, "dur": maxf(jt, 0.001), "arc": HOP_ARC, "pop": false}
		last = at + jt
		k += 1
	if k > 0:
		var turn := _turn
		_later(land - t + (0.0 if Motion.reduce else ANSWER_GAP), func():
			if turn == _turn:
				fx.cue("answer"))
	if bool(r.won):
		_busy_until = land
		_busy_for(jt)
		note_move()
		return
	if int(r.caught) >= 0:
		_caught = {"at": last}
		_shake_at = last
		_busy_until = last + CAUGHT_HOLD + (0.0 if Motion.reduce else SLIDE_BACK)
		_busy_for(_busy_until - t + MARK_FADE)
		var turn := _turn
		_later(last - t, func():
			if turn != _turn:
				return
			fx.cue("caught")
			_say(tr("KN_CAUGHT"), Face.Expr.STRAIN))
		_later(last - t + CAUGHT_HOLD, func():
			if turn == _turn and not _caught.is_empty():
				_caught = {}
				_slide_to_state(_now(), 0.0))
		_refresh()
		return
	_busy_until = last
	_busy_for(last - t + MARK_FADE)
	note_move()
	if took >= 0:
		_say(tr("KN_TAKEN"), Face.Expr.HAPPY)
	elif from_hint:
		_say(tr("KN_HINT"), Face.Expr.HAPPY)
	elif _tip_mood == Face.Expr.STRAIN:
		_say(tr(TIPS[1]), Face.Expr.HAPPY)
	if _state.moves_left() == 0:
		_say(tr("KN_LAST_MOVE"), Face.Expr.STRAIN)
	_refresh()

## Every piece slides from where it is drawn to where the state has it:
## after a catch, an Undo or a Reset. A rose knight taken in the undone move
## pops back in where it stood.
func _slide_to_state(t: float, stagger: float) -> void:
	var dur := 0.001 if Motion.reduce else SLIDE_BACK
	_turn += 1
	_caught = {}
	_shake_at = -100.0
	_you_a = {"from": int(_you_a.to), "to": _state.you, "at": t, "dur": dur, "arc": 0.0, "pop": false}
	var k := 0
	for i in _state.foes.size():
		var want: int = _state.foes[i]
		var shown: int = int(_foe_a[i].to)
		var at := t + Motion.stagger(k, stagger)
		if want < 0:
			_foe_a[i] = _still_at(-1)
		elif shown < 0:
			_foe_a[i] = {"from": want, "to": want, "at": at, "dur": dur, "arc": 0.0, "pop": true}
		else:
			_foe_a[i] = {"from": shown, "to": want, "at": at, "dur": dur, "arc": 0.0, "pop": false}
		k += 1
	_gone = []
	_busy_until = t + Motion.stagger(k, stagger) + dur
	_busy_for(_busy_until - t + MARK_FADE)
	_refresh()

func _later(delay: float, fn: Callable) -> void:
	get_tree().create_timer(maxf(0.0, delay)).timeout.connect(fn)

func _refuse(key: String) -> void:
	_bump_at = _now()
	_busy_for(Motion.SHIVER_TIME * 2.0)
	fx.cue("refuse")
	_say(tr(key), Face.Expr.STRAIN)
	_refresh()

# --- frames ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.size() == 0:
		return
	if _animating(_now()):
		_refresh()

## Moving while anything travels, the marks are still fading in, or the
## pieces are still entering.
func _animating(t: float) -> bool:
	if t < _anim_until:
		return true
	if Motion.reduce:
		return false
	var entrance := Motion.ENTER_DELAY + Motion.ENTER_POP \
		+ Motion.stagger(_state.foes.size() + 2, 0.07) + Motion.POP_IN + 0.2
	return t - _opened < entrance

func _busy_for(seconds: float) -> void:
	# the marks pop in over POP_IN plus their stagger after the fade starts
	_anim_until = maxf(_anim_until, _now() + seconds + Motion.POP_IN + 0.2)

func _refresh() -> void:
	_live = null
	queue_redraw()

func _entry(i: int, t: float) -> float:
	if Motion.reduce:
		return 1.0
	var e := t - _opened - Motion.ENTER_DELAY - 0.2 - Motion.stagger(i, 0.07)
	return 0.01 if e <= 0.0 else Motion.pop_in_scale(e).x

# --- the drawing ---

func _draw() -> void:
	if _state.size() == 0 or _cell() <= 0.0:
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var grow := Motion.wide_pop_scale(since)
	var mid := _origin() + _grid_size() * 0.5
	var shake := Motion.shiver_offset(t - _shake_at) * 3.0
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow) + Vector2(shake, 0.0))
	var tint := Color(1.0, 1.0, 1.0, seen)
	if _still == null:
		_still = _build_still()
	if _live == null:
		_live = _build_live(t)
	var shown: Array = []
	for m in [_still, _live]:
		if m != null:
			draw_mesh(m, null, xf, tint)
			shown.append(m)
	_shown = shown
	_draw_budget()

## The wooden frame, its shadow and the squares. None of it ever moves.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	var o := _origin()
	var g := _grid_size()
	var out := o - Vector2.ONE * FRAME
	var out_size := g + Vector2.ONE * FRAME * 2.0
	Scenery.soft_disc(b, out + out_size * Vector2(0.5, 1.0) + Vector2(0.0, 10.0), out_size.x * 0.55, 36.0, Color(Pal.TEXT, 0.14))
	b.fan(Face.Builder.round_rect(out + Vector2(0.0, 8.0), out_size, FRAME_R), Pal.CHESS_FRAME_DEEP)
	b.fan(Face.Builder.round_rect(out, out_size, FRAME_R), Pal.CHESS_FRAME)
	b.fan(Face.Builder.round_rect(out + Vector2(FRAME, 6.0), Vector2(out_size.x - FRAME * 2.0, 6.0), 3.0),
		Color(1.0, 0.925, 0.784, 0.3))
	b.fan(PackedVector2Array([o, o + Vector2(g.x, 0.0), o + g, o + Vector2(0.0, g.y)]), Pal.CHESS_LIGHT)
	for c in _state.size():
		var x: int = c % _state.w
		var y: int = c / _state.w
		if (x + y) % 2 == 0:
			continue
		var at := o + Vector2(x, y) * s
		b.fan(PackedVector2Array([at, at + Vector2(s, 0.0), at + Vector2(s, s), at + Vector2(0.0, s)]), Pal.CHESS_DARK)
		b.fan(PackedVector2Array([at + Vector2(0.0, s - 5.0), at + Vector2(s, s - 5.0), at + Vector2(s, s), at + Vector2(0.0, s)]),
			Color(Pal.CHESS_DARK_EDGE, 0.5))
	return b.mesh()

## The trail, the marks, every piece (lowest first, anything in the air
## over the rest), and a hint's ring.
func _build_live(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	_draw_trail(b, s)
	if not is_done() and t >= _busy_until:
		var fade := 1.0 if Motion.reduce else clampf((t - _busy_until) / MARK_FADE, 0.0, 1.0)
		_draw_marks(b, s, fade, t)
	var items: Array = []
	var kc := _centre(_state.king)
	var tip := 0.0
	if _solved_at >= 0.0:
		tip = -TOPPLE if Motion.reduce else -TOPPLE * Motion.back_out(clampf((t - _solved_at) / TOPPLE_TIME, 0.0, 1.0))
	var fallen := _solved_at >= 0.0 and t >= _solved_at
	var king_e := _entry(0, t)
	items.append({"air": 0, "y": kc.y, "fn": func(): Piece.king(b, kc, s, tip, king_e, fallen)})
	var you_now := _where(_you_a, t)
	for i in _foe_a.size():
		var a: Dictionary = _foe_a[i]
		var w := _where(a, t)
		if w.is_empty():
			continue
		var e: Vector2 = Motion.pop_in_scale(maxf(0.0, t - float(a.at))) if bool(a.pop) else Vector2.ONE * _entry(i + 1, t)
		var sq: Vector2 = e * _land_squash(float(w.land), t)
		var look := -1.0 if not you_now.is_empty() and you_now.at.x < w.at.x else 1.0
		items.append({"air": 1 if float(w.lift) > 0.5 else 0, "y": w.at.y,
			"fn": func(): Piece.knight(b, w.at, s, Piece.ROSE, look, w.lift, sq)})
	for gn: Dictionary in _gone:
		var gs := t - float(gn.at)
		var gc := _centre(gn.c)
		if gs < 0.0:
			items.append({"air": 0, "y": gc.y, "fn": func(): Piece.knight(b, gc, s, Piece.ROSE, 1.0)})
		elif gs < TAKE_TIME and not Motion.reduce:
			var k := 1.0 - gs / TAKE_TIME
			items.append({"air": 0, "y": gc.y,
				"fn": func(): Piece.knight(b, gc, s, Piece.ROSE, 1.0, 0.0, Vector2(1.0 + 0.3 * (1.0 - k), k), false, k)})
	if not you_now.is_empty():
		var look := -1.0 if kc.x < you_now.at.x else 1.0
		if not _caught.is_empty() and t >= float(_caught.at):
			items.append({"air": 0, "y": you_now.at.y - 1.0,
				"fn": func(): Piece.knight(b, you_now.at, s, Piece.CREAM, look, 0.0, Vector2(1.0, 0.9), false, 0.45)})
		else:
			var sh := Motion.shiver_offset(t - _bump_at) * 4.0
			var sq: Vector2 = Vector2.ONE * _entry(_foe_a.size() + 1, t) * _land_squash(float(you_now.land), t)
			var joy := fallen
			items.append({"air": 1 if float(you_now.lift) > 0.5 else 0, "y": you_now.at.y,
				"fn": func(): Piece.knight(b, you_now.at + Vector2(sh, 0.0), s, Piece.CREAM, look, you_now.lift, sq, joy)})
	items.sort_custom(func(p, q): return p.y < q.y if p.air == q.air else p.air < q.air)
	for it: Dictionary in items:
		it.fn.call()
	_drop_rings(t)
	for r: Dictionary in _rings:
		var u := (t - float(r.at)) / Motion.RING_TIME
		if u >= 0.0 and u < 1.0:
			var rad := s * (0.3 + 0.4 * u)
			b.stroke(Face.Builder.ring(r.pos, rad, rad), s * 0.05 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)
	return b.mesh() if not b.verts.is_empty() else null

## A faint dashed line through every square you have landed on.
func _draw_trail(b: Face.Builder, s: float) -> void:
	var route: PackedInt32Array = _state.route()
	var period := s * 0.14
	var dash := s * 0.05
	var col := Color(Pal.KNIGHT_CREAM_LINE, 0.22)
	for i in range(1, route.size()):
		var a := _centre(route[i - 1])
		var z := _centre(route[i])
		var ln := a.distance_to(z)
		var n := int(ln / period)
		for k in n:
			var p0 := a.lerp(z, float(k) * period / ln)
			var p1 := a.lerp(z, minf(1.0, (float(k) * period + dash) / ln))
			b.stroke(PackedVector2Array([p0, p1]), s * 0.035, col)

## Rose corners in every square a rose knight reaches right now, a sage dot
## on each square you can hop to -- a rose ring instead where that square is
## in reach, and a sage ring round a rose knight or the king you can take.
func _draw_marks(b: Face.Builder, s: float, fade: float, t: float) -> void:
	var reach: Dictionary = _state.reach()
	var reach_col := Color(Pal.KNIGHT_REACH, 0.55 * fade)
	var gap := s * 0.1
	var tick := s * 0.16
	for q: int in reach:
		if q == _state.king:
			continue
		var o := _origin() + Vector2(q % _state.w, q / _state.w) * s
		for cn: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var corner := o + Vector2(gap + cn.x * (s - 2.0 * gap), gap + cn.y * (s - 2.0 * gap))
			var dx := 1.0 if cn.x == 0.0 else -1.0
			var dy := 1.0 if cn.y == 0.0 else -1.0
			b.stroke(PackedVector2Array([corner + Vector2(0.0, dy * tick), corner, corner + Vector2(dx * tick, 0.0)]),
				s * 0.035, reach_col)
	if _state.moves_left() == 0:
		return
	var legal: PackedInt32Array = _state.legal()
	for i in legal.size():
		var q: int = legal[i]
		var at := _centre(q)
		var e := 1.0 if Motion.reduce else maxf(0.05, Motion.pop_in_scale(maxf(0.0, t - _busy_until - float(i) * 0.025)).x)
		if q == _state.king or _state.foes.has(q):
			var r := s * 0.44 * e
			b.stroke(Face.Builder.ring(at, r, r), s * 0.05, Color(Pal.KNIGHT_MOVE, 0.85 * fade), true)
		elif reach.has(q):
			var r := s * 0.13 * e
			b.stroke(Face.Builder.ring(at, r, r), s * 0.035, Color(Pal.KNIGHT_REACH, 0.7 * fade), true)
		else:
			b.disc(at, s * 0.13 * e, Color(Pal.KNIGHT_MOVE, 0.8 * fade))

## Insane's moves left, centred under the board.
func _draw_budget() -> void:
	var left: int = _state.moves_left()
	if left < 0:
		return
	var text := tr("KN_ONE_MOVE_LEFT") if left == 1 else tr("KN_MOVES_LEFT") % left
	var font: Font = CozyTheme.body(700)
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BUDGET_FONT).x
	var y := _origin().y + _grid_size().y + FRAME + BUDGET_DROP
	var ink: Color = Pal.BAD if left == 0 and not _state.is_solved() else Pal.TEXT
	draw_string(font, Vector2((size.x - w) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, BUDGET_FONT, ink)

func _ring_at(at: Vector2, when: float) -> void:
	if Motion.reduce:
		return
	_rings.append({"pos": at, "at": when})
	_busy_for(when - _now() + Motion.RING_TIME)

func _drop_rings(t: float) -> void:
	var keep: Array = []
	for r: Dictionary in _rings:
		if t - float(r.at) < Motion.RING_TIME:
			keep.append(r)
	_rings = keep

# --- input ---

## A tap on release: on a square your knight can reach, the hop; on your own
## knight, the first tip again; anywhere else on the board, a refusal.
func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if event.pressed:
			return
		var c := _square_at(event.position)
		if c < 0:
			return
		if c == _state.you:
			_bump_at = _now()
			_say(tr(TIPS[0]), Face.Expr.HAPPY)
			_refresh()
		else:
			_play(c)

# --- the sprout's line ---

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _state.can_undo():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return _state.can_undo() and not is_done()

## Slides everything back to before your last kept hop. Counts no move.
func undo() -> bool:
	if is_done() or _now() < _busy_until or not _state.undo():
		return false
	_slide_to_state(_now(), 0.0)
	_say(tr("KN_UNDONE"), Face.Expr.HAPPY)
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## Plays the next hop of the shortest line from here for you.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or _now() < _busy_until:
		return false
	var m: int = _state.hint_move()
	if m < 0:
		_say(tr("KN_STUCK"), Face.Expr.STRAIN)
		fx.cue("refuse")
		return false
	hints_used += 1
	_ring_at(_centre(m), _now() + _jump())
	fx.cue("hint")
	_play(m, true)
	return true

func reset_board() -> void:
	_state.reset_board()
	_slide_to_state(_now(), Motion.RESET_STAGGER)
	_rings = []
	_solved_at = -1.0
	moves = 0
	_running = true
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	fx.cue("reset")

func is_solved() -> bool:
	return _state.is_solved()

## The shape of the day and never its answer: you, a rose each, the crown.
func share_glyphs() -> String:
	return "🐴" + "🌹".repeat(_state.foes.size()) + "👑"

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("KN_WIN")}

## The win screen waits for your knight to land and the king to fall.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return maxf(0.0, _solved_at - _now()) + WIN_WAIT

func _on_solved() -> void:
	var t := _now()
	_solved_at = maxf(t, float(_you_a.at) + float(_you_a.dur))
	_tip_timer.stop()
	var kc := _centre(_state.king)
	if not Motion.reduce:
		_later(_solved_at - t, func():
			fx.sparkle(kc, Pal.SUN)
			fx.ring(kc, _cell() * 0.6)
			fx.cue("solved"))
		_later(_solved_at - t + 0.2, func(): fx.sparkle(kc, Pal.CROWN))
	else:
		fx.cue("solved")
	_busy_for(_solved_at - t + TOPPLE_TIME)
	_say(tr("KN_WIN"), Face.Expr.JOY)
	_refresh()

## A reopened daily that was already solved: the day's line replayed through
## the state, your knight on the king's square and the king already fallen.
## Never check_solved(): `solved` must not fire twice.
func restore_completed_board() -> void:
	_state.reset_board()
	for m in _state.g.line:
		_state.play(m)
	_snap_to_state()
	var t := _now()
	_solved_at = t - 100.0
	_opened = t - 100.0
	_tip_timer.stop()
	_say(tr("KN_WIN"), Face.Expr.JOY)
	_refresh()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
