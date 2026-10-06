extends RefCounted

## What stands and moves on the Grove's land, for whoever shows it (the
## screen, the tab's card, the tutorial's pages): the trees, the shadow each
## throws, the beavers that bite them and the way one comes down. The rules
## stay the sim's (valley/grove_sim.gd) and the drawings the art's
## (valley/grove_art.gd, ui/faces/beaver.gd); this keeps only what is seen
## between two of the sim's events. From the user, 2026-10-06: "for each
## chop show a beaver that bite the tree, also improve the falling animation
## to something better animated, right now even shadow rotate. I would love
## to see some subtle lightning shadows casted upon trees dynamic instead of
## a round".
##
## A holder calls `place` when its land moves, `step` every frame after the
## sim's own, `hit` and `fell` for the sim's events, and draws two things:
## `draw_shade` on a Control wearing `shade` (under the trees) and `draw` on
## one wearing `Art.wind()`. Every draw is a kept mesh under a transform.
##
## - **A shadow is its tree's own outline** laid on the ground to the right
##   (`Art.shade`, `Art.cast`), leaning on the same gust as the crown over
##   it, kept to the land by `shade`. When the tree turns over, its shadow
##   does not: it runs out along the ground and ends under the lying tree.
## - **A beaver comes to every tree the circle takes** and stays while it
##   does (LINGER after, so a sweep does not flicker): it rears back as the
##   next chop comes due and its teeth are in the wood on the frame the sim
##   says `hit`, a chip or two flying. It sits on the left of an even tree
##   and the right of an odd one, and the tree comes down away from it.
## - **A tree comes down in four beats**: it creaks back (CREAK), goes over
##   as a thing that falls does, slowly then fast (DROP), lands and bounces
##   once with a burst of its leaves (`landed`, SETTLE), and is gone into
##   what it gives (`gave`, GONE). Its stump stays STUMP longer.
##
## Under reduce motion a beaver is there or not and only changes its face, a
## felled tree fades where it stands, and both signals come at once.

signal landed(tree: Dictionary, at: Vector2)
signal gave(tree: Dictionary, give: int, at: Vector2)

const Sim = preload("res://valley/grove_sim.gd")
const Art = preload("res://valley/grove_art.gd")
const Beaver = preload("res://ui/faces/beaver.gd")
const Motion = preload("res://core/motion.gd")

## Seconds a hit tree's squash lasts.
const SQUASH := 0.16
const CREAK := 0.1
const DROP := 0.42
const SETTLE := 0.18
const GONE := 0.2
const STUMP := 0.5
## How far over a lying tree is, in radians, and how far it leans back first.
const LIE := 1.5
const BACK := 0.07
## A beaver's seconds in and out, how long it waits by a tree the circle has
## left, a bite's length and a cheer's.
const SHOW_IN := 0.16
const SHOW_OUT := 0.14
const LINGER := 0.4
const BITE := 0.26
const CHEER := 0.56
## Chips and burst leaves in the air at most, and how fast they come down.
const BITS := 48
const FALLS := 900.0

## The view's (0, 0) in the holder's pixels, and the pixels a unit.
var origin := Vector2.ZERO
var u := 1.0
## The material for the Control `draw_shade` draws on.
var shade: ShaderMaterial

var _hit := {}        # tree id -> seconds since it was hit
var _falls: Array = []    # {tree, give, t, dir, down, given}
var _beavers := {}    # tree id -> {tree, side, show, rising, seen, bite, cheer, age}
var _bits: Array = []     # {pos, vel, t, life, turn, spin, col, size, weight}: view units
var _bit_mm: MultiMesh
var _swing := Sim.SWING
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	shade = Art.shade_wind()
	_rng.seed = 20261006

## The land as the holder lays it: `xf` is the holder's own place on the
## screen (its global transform), for the shadows to be kept to the land.
func place(at: Vector2, unit: float, xf: Transform2D) -> void:
	origin = at
	u = unit
	Art.keep_to(shade, xf, at, unit)

# --- time ---

## `delta` seconds pass; `holding` with the circle's centre `at`, as the
## sim was just stepped with.
func step(delta: float, sim: RefCounted, holding := false, at := Vector2.ZERO) -> void:
	_swing = sim.swing_time()
	for id in _hit.keys():
		_hit[id] += delta
		if _hit[id] > SQUASH:
			_hit.erase(id)
	for f: Dictionary in _falls:
		f.t += delta
		if Motion.reduce and not f.given:
			# reduce motion came on with the tree half way down
			f.down = true
			f.given = true
			gave.emit(f.tree, int(f.give), _crown_at(f))
		if not f.down and f.t >= CREAK + DROP:
			f.down = true
			_burst(f)
			landed.emit(f.tree, _crown_at(f))
		if not f.given and f.t >= CREAK + DROP + SETTLE:
			f.given = true
			gave.emit(f.tree, int(f.give), _crown_at(f))
	var whole := Motion.REDUCED_TIME if Motion.reduce else CREAK + DROP + SETTLE + GONE + STUMP
	_falls = _falls.filter(func(f: Dictionary) -> bool: return f.t < whole)
	if holding:
		for tree: Dictionary in sim.trees:
			if sim.reaches(tree, at):
				_beaver(tree).seen = 0.0
	for id in _beavers.keys():
		var b: Dictionary = _beavers[id]
		b.seen += delta
		b.bite += delta
		b.age += delta
		if b.cheer >= 0.0:
			b.cheer += delta
		var want: bool = b.seen < LINGER or (b.cheer >= 0.0 and b.cheer < CHEER)
		b.rising = want
		b.show = move_toward(float(b.show), 1.0 if want else 0.0, delta / (SHOW_IN if want else SHOW_OUT))
		if not want and float(b.show) <= 0.0:
			_beavers.erase(id)
	for bit: Dictionary in _bits:
		bit.t += delta
		var vel: Vector2 = bit.vel
		vel.y += FALLS * float(bit.weight) * delta
		vel.x *= 1.0 - minf(1.0, delta * 1.6)
		bit.vel = vel
		bit.pos = (bit.pos as Vector2) + vel * delta
		bit.turn = float(bit.turn) + float(bit.spin) * delta
	_bits = _bits.filter(func(bit: Dictionary) -> bool: return bit.t < bit.life)

## The sim said `hit`: the tree is squashed, and its beaver's teeth are in.
func hit(tree: Dictionary) -> void:
	_hit[tree.id] = 0.0
	var b := _beaver(tree)
	b.bite = 0.0
	b.seen = 0.0
	if Motion.reduce:
		return
	# a chip or two off the trunk, toward the beaver and up
	var side: float = b.side
	var at := Art.see(tree.pos) + Vector2(side * Art.girth(Sim.look_of(tree.tier)), -22.0 * float(b.size))
	for i in 2:
		_bit(at, Vector2(side * _rng.randf_range(40.0, 150.0), -_rng.randf_range(120.0, 260.0)), 0.42,
			Art.PITH if i == 0 else Art.BARK.lightened(0.25), _rng.randf_range(0.5, 0.8), 1.0)

## The sim said `fell`: the tree starts down, away from its beaver, which
## cheers. `give` is what it leaves, handed back with `gave`.
func fell(tree: Dictionary, give: int) -> void:
	var b := _beaver(tree)
	b.cheer = 0.0
	var f := {"tree": tree, "give": give, "t": 0.0, "dir": -float(b.side), "down": false, "given": false}
	_falls.append(f)
	if Motion.reduce:
		f.down = true
		f.given = true
		var at := Art.see(tree.pos) + Vector2(0.0, -Sim.radius_of(tree.tier) * 1.7 * Art.TREE)
		landed.emit(tree, at)
		gave.emit(tree, give, at)

func _beaver(tree: Dictionary) -> Dictionary:
	if not _beavers.has(tree.id):
		_beavers[tree.id] = {"tree": tree, "side": -1.0 if int(tree.id) % 2 == 0 else 1.0, "show": 0.0, "rising": true,
			"seen": 0.0, "bite": 10.0, "cheer": -1.0, "age": 0.0, "size": 0.7 + 0.004 * Sim.radius_of(tree.tier)}
	return _beavers[tree.id]

func _bit(at: Vector2, vel: Vector2, life: float, colour: Color, size: float, weight: float) -> void:
	if _bits.size() >= BITS:
		return
	_bits.append({"pos": at, "vel": vel, "t": 0.0, "life": life, "turn": _rng.randf() * TAU,
		"spin": _rng.randf_range(-9.0, 9.0), "col": colour, "size": size, "weight": weight})

## A crown hits the ground: its leaves jump out of it.
func _burst(f: Dictionary) -> void:
	var look: int = Sim.look_of(f.tree.tier)
	var r: float = Sim.radius_of(f.tree.tier) * Art.TREE
	var at := _crown_at(f)
	for i in 5 + look:
		_bit(at + Vector2(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.5, 0.2)) * r,
			Vector2(float(f.dir) * _rng.randf_range(10.0, 150.0) + _rng.randf_range(-70.0, 70.0), -_rng.randf_range(110.0, 300.0)),
			_rng.randf_range(0.7, 1.1), Art.LEAF[look], _rng.randf_range(0.9, 1.4), 0.5)

## Where the middle of a lying tree's crown is, in view units.
func _crown_at(f: Dictionary) -> Vector2:
	var r: float = Sim.radius_of(f.tree.tier) * Art.TREE * 1.7
	return Art.see(f.tree.pos) + Vector2(float(f.dir) * sin(LIE), -cos(LIE)) * r

# --- drawing ---

func _px(p: Vector2) -> Vector2:
	return origin + Art.see(p) * u

## How big a standing tree is drawn: grown in, and squashed if just hit.
func _size(tree: Dictionary, sim: RefCounted) -> Vector2:
	var grown := 1.0 if Motion.reduce else clampf((sim.clock - float(tree.born)) / Sim.GROW, 0.0, 1.0)
	var size := (0.15 + 0.85 * Motion.back_out(grown)) * u * Art.TREE
	var squash := 0.0
	if _hit.has(tree.id) and not Motion.reduce:
		squash = sin(float(_hit[tree.id]) / SQUASH * PI) * 0.16
	return Vector2(size * (1.0 + squash), size * (1.0 - squash))

## A falling tree at its moment: how far over (to the right when over 0),
## how flat it is pressed along its length, how much of it is left (1 to 0
## as it goes into what it gives) and how much of its shadow.
func _pose(f: Dictionary) -> Array:
	var t: float = f.t
	if Motion.reduce:
		var left := 1.0 - t / Motion.REDUCED_TIME
		return [0.0, 0.0, 1.0, left, left]
	var dir: float = f.dir
	if t < CREAK:
		return [-dir * BACK * sin(t / CREAK * PI * 0.5), 0.0, 1.0, 1.0, 1.0]
	t -= CREAK
	if t < DROP:
		return [dir * lerpf(-BACK, LIE, pow(t / DROP, 2.4)), 0.0, 1.0, 1.0, 1.0]
	t -= DROP
	if t < SETTLE:
		var k := t / SETTLE
		return [dir * (LIE - 0.14 * sin(k * PI) * (1.0 - k)), 0.1 * sin(minf(1.0, k * 2.0) * PI), 1.0, 1.0, 1.0]
	t -= SETTLE
	var g := clampf(t / GONE, 0.0, 1.0)
	return [dir * LIE, 0.0, (1.0 + 0.3 * g) * (1.0 - g * g), 0.0 if g >= 1.0 else 1.0, 1.0 - g]

## The shadows, each under its own tree's lean and no other: for a Control
## under the trees wearing `shade`.
func draw_shade(ci: CanvasItem, sim: RefCounted) -> void:
	for tree: Dictionary in sim.trees:
		ci.draw_mesh(Art.shade(Sim.look_of(tree.tier)), null, Art.cast(_px(tree.pos), _size(tree, sim)))
	for f: Dictionary in _falls:
		var pose := _pose(f)
		if float(pose[4]) <= 0.0:
			continue
		var size := u * Art.TREE
		ci.draw_mesh(Art.shade(Sim.look_of(f.tree.tier)), null, Art.cast(_px(f.tree.pos), Vector2(size, size), pose[0]),
			Color(1.0, 1.0, 1.0, pose[4]))

## The trees, the ones coming down, their stumps and the beavers, from the
## back of the land to the front, and over them what is in the air.
func draw(ci: CanvasItem, sim: RefCounted) -> void:
	var list: Array = []
	for tree: Dictionary in sim.trees:
		list.append([float(tree.pos.y), 0, tree])
	for f: Dictionary in _falls:
		list.append([float(f.tree.pos.y), 1, f])
	for id in _beavers:
		list.append([float(_beavers[id].tree.pos.y) + 2.0, 2, _beavers[id]])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for item: Array in list:
		match int(item[1]):
			0:
				var tree: Dictionary = item[2]
				var size := _size(tree, sim)
				ci.draw_mesh(Art.tree(Sim.look_of(tree.tier)), null, Transform2D(0.0, size, 0.0, _px(tree.pos)))
			1:
				_draw_fall(ci, item[2])
			2:
				_draw_beaver(ci, item[2])
	_draw_bits(ci)

func _draw_fall(ci: CanvasItem, f: Dictionary) -> void:
	var tree: Dictionary = f.tree
	var look: int = Sim.look_of(tree.tier)
	var at := _px(tree.pos)
	var size := u * Art.TREE
	var pose := _pose(f)
	var left: float = pose[2]
	if Motion.reduce:
		ci.draw_mesh(Art.tree(look), null, Transform2D(0.0, Vector2(size, size), 0.0, at), Color(1.0, 1.0, 1.0, pose[3]))
		return
	if float(pose[3]) > 0.0 and left > 0.02:
		var flat: float = pose[1]
		var xf := Transform2D(float(pose[0]), Vector2(size * (1.0 + flat * 0.6), size * (1.0 - flat)), 0.0, at)
		if left != 1.0:
			# it goes into what it gives: drawn in toward its crown's middle
			var crown := xf * Vector2(0.0, -Sim.radius_of(tree.tier) * 1.7)
			xf = Transform2D(0.0, Vector2(left, left), 0.0, crown * (1.0 - left)) * xf
		ci.draw_mesh(Art.tree(look), null, xf)
	var stump := Art.stump(look)
	if stump != null and f.t > CREAK:
		var end: float = CREAK + DROP + SETTLE + GONE + STUMP
		var s := Motion.pop_out_scale(float(f.t) - (end - Motion.POP_OUT)) * size
		if s > 0.0:
			ci.draw_mesh(stump, null, Transform2D(0.0, Vector2(s, s), 0.0, at))

## A beaver by its tree, looking at it: popped in, reared back as the next
## chop comes due, its teeth in the wood on a hit, hopping when the tree is
## down.
func _draw_beaver(ci: CanvasItem, b: Dictionary) -> void:
	var tree: Dictionary = b.tree
	var side: float = b.side
	var s: float = float(b.size) * u
	var show: float = b.show
	if show <= 0.0:
		return
	var grow := 1.0
	var snap := 0.0
	var rear := 0.0
	var hop := 0.0
	var cheering: bool = float(b.cheer) >= 0.0 and float(b.cheer) < CHEER
	if not Motion.reduce:
		grow = Motion.back_out(show) if b.rising else show
		snap = pow(1.0 - clampf(float(b.bite) / BITE, 0.0, 1.0), 2.0)
		if cheering:
			hop = Motion.hop_lift(fmod(float(b.cheer), CHEER * 0.5), -11.0, CHEER * 0.5)
		elif float(b.seen) < 0.1:
			rear = smoothstep(0.5, 1.0, float(b.bite) / maxf(_swing, 0.05))
	var reach: float = Art.girth(Sim.look_of(tree.tier)) + (Beaver.NECK.x + Beaver.TEETH.x - 2.0) * float(b.size)
	var at := _px(tree.pos) + Vector2(side * (reach - 3.0 * snap * float(b.size)), 3.0 + hop) * u
	# it looks at the trunk: right when it sits on the left
	var xf := Transform2D(0.0, Vector2(-side * s * grow * (1.0 + 0.06 * snap), s * grow * (1.0 - 0.06 * snap)), 0.0, at)
	var wag := 0.5 * rear - 0.12 * snap + (0.3 * absf(sin(float(b.cheer) * 22.0)) if cheering else 0.04 * sin(float(b.age) * 3.0))
	ci.draw_mesh(Beaver.tail(), null, xf * Transform2D(wag, Beaver.TAIL_AT))
	ci.draw_mesh(Beaver.body(), null, xf)
	var nod := 0.22 * snap - 0.3 * rear - (0.28 if cheering else 0.0)
	var neck := Beaver.NECK + Vector2(3.0 * snap - 4.0 * rear, -2.0 * rear)
	ci.draw_mesh(Beaver.head(float(b.bite) < BITE * 0.6), null, xf * Transform2D(nod, neck))

## Chips and burst leaves, one MultiMesh.
func _draw_bits(ci: CanvasItem) -> void:
	if _bits.is_empty():
		return
	if _bit_mm == null:
		_bit_mm = MultiMesh.new()
		_bit_mm.transform_format = MultiMesh.TRANSFORM_2D
		_bit_mm.use_colors = true
		_bit_mm.mesh = Art.leaf()
		_bit_mm.instance_count = BITS
	var n := 0
	for bit: Dictionary in _bits:
		var t: float = bit.t
		var a := clampf((float(bit.life) - t) / 0.2, 0.0, 1.0)
		var flat := 0.35 + 0.65 * absf(cos(t * 9.0 + float(bit.turn)))
		var s: float = float(bit.size) * u
		_bit_mm.set_instance_transform_2d(n, Transform2D(float(bit.turn), Vector2(s, s * flat), 0.0, origin + (bit.pos as Vector2) * u))
		_bit_mm.set_instance_color(n, Color(bit.col as Color, a))
		n += 1
	_bit_mm.visible_instance_count = n
	ci.draw_multimesh(_bit_mm, null)
