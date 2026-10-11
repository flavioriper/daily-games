extends RefCounted
## The zoom and the pan of a board too big to play whole (Pixel Garden's and
## Button Box's Hard and Insane pictures). It holds one transform, `xf()`,
## that the board lays over its cached meshes inside `view`; nothing is
## rebuilt for a zoom. At `k` 1 the transform is the identity and the board
## is as it was laid out.
##
## Fingers are read raw (ScreenTouch / ScreenDrag by index: touch is not
## mouse here, and a magnify gesture is not sent on every phone). Two fingers
## pinch and pan. With `one_finger_pan` a single finger dragged past `SLOP`
## pans too, for a board played by taps alone. The wheel zooms on a desk.
##
## The board hands every event of its `_gui_input` to `feed` first:
##   NONE  -- not ours, play it
##   BEGAN -- a gesture has started on this event: drop the press or the
##            stroke in hand, and play nothing
##   TOOK  -- part of a gesture, play nothing
## and calls `step(delta)` from `_process`, redrawing while it returns true.

const Motion = preload("res://core/motion.gd")

enum { NONE, BEGAN, TOOK }

## A finger moved this far is a pan and no longer a tap.
const SLOP := 14.0
## The button's glide between whole and close.
const GLIDE := 0.22
const WHEEL := 1.15

## Where the picture shows, in the board's own coordinates. The zoomed
## picture always covers it.
var view := Rect2()
var k := 1.0
var k_max := 1.0
## What the button zooms to.
var k_near := 1.0
var one_finger_pan := false
var enabled := false
## How far inside the view's low (top left) and high (bottom right) edges the
## picture's own edges may be pulled once it is zoomed to `k_near` or closer,
## growing from nothing at `k` 1: a board with a button laid over a corner
## of its view sets this so what lies under the button can be pushed clear
## of it. Zero, the default, and the zoomed picture always covers the view.
var slack_lo := Vector2.ZERO
var slack_hi := Vector2.ZERO

var _t := Vector2.ZERO
var _touch := {}
var _gesture := false
## Two fingers send an event each. Followed one at a time, a pan is a pinch
## in and a pinch out by turns, and against the view's edge the clamp bites
## between the two: the picture crept back the way it was pushed from. So
## the zoom follows the pair: where the fingers were when it last moved
## (`_held`), and which have moved since (`_stirred`); the first of the two
## to move waits for the other, or for its own next event.
var _held := {}
var _stirred := {}
var _one_from := Vector2.ZERO
var _glide_from_k := 1.0
var _glide_from_t := Vector2.ZERO
var _glide_to_k := 1.0
var _glide_to_t := Vector2.ZERO
var _glide := -1.0
var _going_in := true

## Sets the room and the limits; `near` is the button's zoom. Call from the
## layout. A zoom in hand is kept and clamped to the new room.
func setup(view_: Rect2, near: float, most: float) -> void:
	view = view_
	k_near = maxf(1.0, near)
	k_max = maxf(k_near, most)
	enabled = k_max > 1.001
	if not enabled:
		reset()
	else:
		k = clampf(k, 1.0, k_max)
		_t = _clamp(_t, k)

func reset() -> void:
	k = 1.0
	_t = Vector2.ZERO
	_glide = -1.0
	_touch.clear()
	_held.clear()
	_stirred.clear()
	_gesture = false

func zoomed() -> bool:
	return k > 1.001

## True while fingers are panning or pinching.
func busy() -> bool:
	return _gesture

## From the board as laid out to the board as shown.
func xf() -> Transform2D:
	return Transform2D(Vector2(k, 0.0), Vector2(0.0, k), _t)

## A point of the screen (the board's coordinates) back to the layout's.
func to_layout(p: Vector2) -> Vector2:
	return (p - _t) / k

func to_screen(p: Vector2) -> Vector2:
	return p * k + _t

func _clamp(t: Vector2, kk: float) -> Vector2:
	var give := clampf((kk - 1.0) / maxf(k_near - 1.0, 0.001), 0.0, 1.0)
	var lo := view.end * (1.0 - kk) - slack_hi * give
	var hi := view.position * (1.0 - kk) + slack_lo * give
	return Vector2(clampf(t.x, lo.x, hi.x), clampf(t.y, lo.y, hi.y))

## Zooms to `kk` keeping the layout point under `at` (screen) under `to`.
func _zoom_about(kk: float, at: Vector2, to: Vector2) -> void:
	var p := to_layout(at)
	k = clampf(kk, 1.0, k_max)
	_t = _clamp(to - p * k, k)

## The button: whole to close on `at` (screen; the view's middle by
## default), close to whole. Glides unless motion is reduced.
func toggle(at := Vector2.INF) -> void:
	if not enabled:
		return
	if at == Vector2.INF:
		at = view.get_center()
	_glide_from_k = k
	_glide_from_t = _t
	if zoomed():
		_glide_to_k = 1.0
		_glide_to_t = Vector2.ZERO
	else:
		_glide_to_k = k_near
		_glide_to_t = _clamp(view.get_center() - to_layout(at) * k_near, k_near)
	if Motion.reduce:
		k = _glide_to_k
		_t = _glide_to_t
		_glide = -1.0
	else:
		_glide = 0.0

## The button, a step at a time (the user, 2026-10-11: "user should be able
## to do another step of zoom out"): whole, half way, close, and back out
## the same way. `at` (screen) is kept under the view's middle on the way
## in; the way out keeps the middle of what is seen.
func cycle(at := Vector2.INF) -> void:
	if not enabled:
		return
	var goes_in := next_in()
	_going_in = goes_in
	var mid := sqrt(k_near)
	var to_k := 1.0
	# from where a glide in hand is going, so two quick presses are two steps
	var cur := _glide_to_k if _glide >= 0.0 else k
	if goes_in:
		to_k = mid if cur < mid * 0.98 else k_near
	else:
		to_k = mid if cur > mid * 1.02 else 1.0
	if at == Vector2.INF or not goes_in:
		at = view.get_center()
	_glide_from_k = k
	_glide_from_t = _t
	_glide_to_k = to_k
	_glide_to_t = _clamp(view.get_center() - to_layout(at) * to_k, to_k)
	if Motion.reduce:
		k = _glide_to_k
		_t = _glide_to_t
		_glide = -1.0
	else:
		_glide = 0.0

## Whether the button's next step goes closer (a plus) or back out (a minus).
func next_in() -> bool:
	var goal := _glide_to_k if _glide >= 0.0 else k
	if goal <= 1.001:
		return true
	if goal >= k_near * 0.98:
		return false
	return _going_in

## Brings the layout point `p` into the view, zoomed as it is (a hint's
## square, a refusal's).
func show_point(p: Vector2) -> void:
	if not zoomed():
		return
	var s := to_screen(p)
	if view.grow(-view.size.x * 0.12).has_point(s):
		return
	_glide_from_k = k
	_glide_from_t = _t
	_glide_to_k = k
	_glide_to_t = _clamp(view.get_center() - p * k, k)
	if Motion.reduce:
		_t = _glide_to_t
	else:
		_glide = 0.0

## Advances the button's glide. True while the board must redraw.
func step(delta: float) -> bool:
	if _glide < 0.0:
		return false
	_glide += delta
	var u := clampf(_glide / GLIDE, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, 3.0)
	k = lerpf(_glide_from_k, _glide_to_k, e)
	_t = _glide_from_t.lerp(_glide_to_t, e)
	if u >= 1.0:
		_glide = -1.0
	return true

func feed(event: InputEvent) -> int:
	if not enabled:
		return NONE
	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP
				or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if view.has_point(event.position):
				_glide = -1.0
				var f := WHEEL if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / WHEEL
				_zoom_about(k * f, event.position, event.position)
				return TOOK
		return NONE
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch.is_empty() and not view.has_point(event.position):
				return NONE
			_touch[event.index] = event.position
			_held = _touch.duplicate()
			_stirred.clear()
			if _touch.size() == 1:
				_one_from = event.position
				return NONE
			if _touch.size() == 2 and not _gesture:
				_gesture = true
				_glide = -1.0
				return BEGAN
			return TOOK
		if not _touch.has(event.index):
			return NONE
		_touch.erase(event.index)
		_held = _touch.duplicate()
		_stirred.clear()
		if _gesture:
			if _touch.is_empty():
				_gesture = false
			return TOOK
		return NONE
	if event is InputEventScreenDrag:
		if not _touch.has(event.index):
			return NONE
		var was: Vector2 = _touch[event.index]
		if _touch.size() >= 2:
			var other := was
			var other_was := was
			for i: int in _touch:
				if i != event.index:
					other = _touch[i]
					other_was = _held.get(i, other)
					break
			_touch[event.index] = event.position
			if _stirred.is_empty():
				_stirred[event.index] = true
				return TOOK
			was = _held.get(event.index, was)
			var d0 := maxf(was.distance_to(other_was), 1.0)
			var d1 := maxf(event.position.distance_to(other), 1.0)
			_zoom_about(k * d1 / d0, (was + other_was) * 0.5, (event.position + other) * 0.5)
			_held = _touch.duplicate()
			_stirred.clear()
			return TOOK
		_touch[event.index] = event.position
		if _gesture:
			_t = _clamp(_t + event.position - was, k)
			return TOOK
		if one_finger_pan and zoomed() and event.position.distance_to(_one_from) > SLOP:
			_gesture = true
			_glide = -1.0
			_t = _clamp(_t + event.position - _one_from, k)
			return BEGAN
		return NONE
	return NONE
