extends RefCounted

## Three stars on a count line: what the way a player is on would earn,
## read once a move. Sun up to the stars it stands at, hollow past them; a
## star lost falls off its seat turning, a star won back (an Undo) pops in.
## Market Sums' first (2026-10-26), Super Slider's the same day.
##
## One per board, kept in a var: the mesh a draw handed over stays alive
## until the next replaces it. One draw_mesh.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")

## Radius and gap at a scale of 1, and a lost star's fall.
const R := 17.0
const GAP := 8.0
const FALL := 0.7
const DROP := 70.0

## The stars the line stands at.
var stars := 3
var _from := 3
var _fell_at := -INF
var _back_at := -INF
var _shown: ArrayMesh

## Back to three, nothing falling (a new day, a reset).
func clear(n := 3) -> void:
	stars = n
	_from = n
	_fell_at = -INF
	_back_at = -INF

## Sets the stars at `now`: -1 when one or more were lost (they fall), 1 when
## won back (the last pops in), 0 when unchanged. `shown`: false sets them
## quietly (a restore).
func rate(n: int, now: float, shown := true) -> int:
	var out := 0
	if shown and n < stars:
		_fell_at = now
		_from = stars
		out = -1
	elif shown and n > stars:
		_back_at = now
		out = 1
	stars = n
	return out

## Whether a star is falling or popping in at `now` (the board keeps drawing).
func busy(now: float) -> bool:
	return not Motion.reduce and (now - _fell_at < FALL or now - _back_at < Motion.POP_IN)

## The line's width at scale `s`.
static func width(s: float) -> float:
	return 3.0 * 2.0 * R * s + 2.0 * GAP * s

## Draws the line on `ci` from `at` (the first star's middle) at scale `s`,
## faded to `alpha` (a board still coming in).
func draw(ci: CanvasItem, at: Vector2, s: float, now: float, alpha := 1.0) -> void:
	var b := Face.Builder.new()
	var r := R * s
	var step := 2.0 * r + GAP * s
	var fell := now - _fell_at
	var back := now - _back_at
	for i in 3:
		var c := at + Vector2(i * step, 0.0)
		var lit := i < stars
		var k := 1.0
		if lit and i == stars - 1 and back >= 0.0 and back < Motion.POP_IN and not Motion.reduce:
			k = Motion.pop_in_scale(back).x
		star(b, c, r, 0.0, Color(Pal.LINE, 0.45))
		if lit:
			star(b, c, r * k, 0.0, Pal.SUN)
		# the stars just lost, falling off their seats
		if i >= stars and i < _from and fell >= 0.0 and fell < FALL and not Motion.reduce:
			var f := fell / FALL
			star(b, c + Vector2(f * r * 0.8, f * f * DROP * s), r * (1.0 - 0.3 * f), f * 2.4,
				Color(Pal.SUN, 1.0 - f))
	_shown = b.mesh()
	ci.draw_mesh(_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))

## A five-pointed star about `c`, turned `turn`.
static func star(b: Face.Builder, c: Vector2, r: float, turn: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := turn - PI * 0.5 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.46))
	b.polygon(pts, colour)
