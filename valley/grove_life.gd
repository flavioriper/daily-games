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
## - **The wood on its way** (2026-10-07, the jetty): the piles lying on the
##   land, sorted in with the trees, a stack as one heap that grows in a few
##   steps and says its count; on the jetty the loose piles as a heap and the
##   bundles waiting (six drawn, then a count); the raft at the jetty's end,
##   rocking, or on its way off the field's left edge with its bundles and
##   back without. All of it read off the sim each frame; none of it sways
##   (the art hangs these meshes under their own y = 0). A pile is not seen
##   until its tree has landed (`left`, then `gave`): it drops out of the
##   lying crown to where the sim has it. `gather` throws logs from a pile
##   to the jetty, and the jetty's heap counts them as they land (`carried`).
##
## Under reduce motion a beaver is there or not and only changes its face, a
## felled tree fades where it stands, both signals come at once, a pile is
## there with them, nothing is thrown and the raft lies still.

signal landed(tree: Dictionary, at: Vector2)
signal gave(tree: Dictionary, give: int, at: Vector2)
## A log thrown from a gathered pile has reached the jetty.
signal carried

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
## Seconds a pile takes out of the lying crown to where it rests: with the
## fall's 0.7 it is there before the sim lets it be gathered (Sim.LIES).
const DROP_IN := 0.18
## Logs thrown by one gathered pile at most, the seconds between them, a
## log's seconds in the air, how high it goes, and how many fly at once.
const THROWN := 3
const THROW_GAP := 0.06
const FLIGHT := 0.45
const ARC := 70.0
const THROWS := 18
## Bundles drawn on the jetty before the rest are a count.
const BUNDLES := 6
## The raft at home: how far it turns and bobs, and how fast.
const ROCK := 0.035
const BOB := 1.4
## A count's size over a stack, in view units.
const COUNT := 25.0

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
## Piles the sim has that are not seen yet, by their stack's id: each one's
## tree is still coming down, or it is on its way out of the crown.
var _owed := {}
var _drops: Array = []    # {id, from, to, t}: a pile out of a lying crown; view units
var _throws: Array = []   # {from, t, n, turn}: a log to the jetty, standing for `n` piles
## Piles the sim has on the jetty whose logs are still in the air.
var _air := 0
var _marks: Array = []    # [at, text]: the counts of this frame's draw, view units

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
		if f.given and not (f.pile as Dictionary).is_empty():
			_let_go(f)
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
	_step_wood(delta, sim)

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
	var f := {"tree": tree, "give": give, "t": 0.0, "dir": -float(b.side), "down": false, "given": false, "pile": {}}
	_falls.append(f)
	if Motion.reduce:
		f.down = true
		f.given = true
		var at := Art.see(tree.pos) + Vector2(0.0, -Sim.radius_of(tree.tier) * 1.7 * Art.TREE)
		landed.emit(tree, at)
		gave.emit(tree, give, at)

## The sim said `log`, right after the `fell` it belongs to: `pile` is the
## stack that tree's wood came down as, or the one it joined. One pile of it
## is not seen until the tree has landed and gone into what it gives.
func left(pile: Dictionary) -> void:
	if _falls.is_empty():
		return
	var f: Dictionary = _falls[-1]
	if f.given or not (f.pile as Dictionary).is_empty():
		return
	f.pile = pile
	_owed[pile.id] = int(_owed.get(pile.id, 0)) + 1

## The sim said `gather`: `n` piles went from the stack at `pos` (land units)
## to the jetty. A log or three are thrown there, and the jetty's heap has
## them when the last lands.
func gather(pos: Vector2, n: int) -> void:
	if Motion.reduce or n <= 0:
		return
	var logs := mini(mini(THROWN, n), THROWS - _throws.size())
	for i in logs:
		_throws.append({"from": Art.see(pos) + Vector2(_rng.randf_range(-12.0, 12.0), -8.0 - _rng.randf_range(0.0, 10.0)),
			"t": -THROW_GAP * i, "n": n if i == logs - 1 else 0, "turn": _rng.randf_range(-1.0, 1.0)})
	if logs > 0:
		_air += n

## A felled tree has gone into what it gives: its pile leaves the crown.
func _let_go(f: Dictionary) -> void:
	var pile: Dictionary = f.pile
	f.pile = {}
	if Motion.reduce:
		_show(int(pile.id))
		return
	_drops.append({"id": int(pile.id), "from": _crown_at(f), "to": Art.see(pile.pos), "t": 0.0})

## One more pile of a stack is seen.
func _show(id: int) -> void:
	var n := int(_owed.get(id, 0)) - 1
	if n > 0:
		_owed[id] = n
	else:
		_owed.erase(id)

## The piles on their way: out of a crown to the grass, and off to the jetty.
func _step_wood(delta: float, sim: RefCounted) -> void:
	for d: Dictionary in _drops:
		d.t += delta
		if d.t >= DROP_IN:
			_show(int(d.id))
	_drops = _drops.filter(func(d: Dictionary) -> bool: return d.t < DROP_IN)
	var home := false
	for t: Dictionary in _throws:
		t.t += delta
		if t.t >= FLIGHT:
			home = true
			_air -= int(t.n)
			carried.emit()
	if home:
		_throws = _throws.filter(func(t: Dictionary) -> bool: return t.t < FLIGHT)
	if _throws.is_empty():
		_air = 0
	# a stack the sim no longer has owes nothing
	if not _owed.is_empty():
		var ids := {}
		for pile: Dictionary in sim.logs:
			ids[pile.id] = true
		for id in _owed.keys():
			if not ids.has(id):
				_owed.erase(id)

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

## The trees, the ones coming down, their stumps, the beavers and the piles
## lying among them, from the back of the land to the front; then the jetty
## and the raft, and over them what is in the air and the stacks' counts.
func draw(ci: CanvasItem, sim: RefCounted) -> void:
	var list: Array = []
	for tree: Dictionary in sim.trees:
		list.append([float(tree.pos.y), 0, tree])
	for f: Dictionary in _falls:
		list.append([float(f.tree.pos.y), 1, f])
	for id in _beavers:
		list.append([float(_beavers[id].tree.pos.y) + 2.0, 2, _beavers[id]])
	for pile: Dictionary in sim.logs:
		if int(pile.n) > int(_owed.get(pile.id, 0)):
			list.append([float(pile.pos.y) + 1.0, 3, pile])
	for d: Dictionary in _drops:
		list.append([(d.to as Vector2).y / Art.DEEP + 1.5, 4, d])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_marks.clear()
	var one := Vector2(u, u)
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
			3:
				var pile: Dictionary = item[2]
				var n := int(pile.n) - int(_owed.get(pile.id, 0))
				ci.draw_mesh(Art.pile(n, pile.lucky), null, Art.still(_px(pile.pos), one))
				if n > 1:
					_marks.append([Art.see(pile.pos) + Vector2(0.0, -Art.heap_tall(n) - 6.0), Art.short(n)])
			4:
				var d: Dictionary = item[2]
				var k := clampf(float(d.t) / DROP_IN, 0.0, 1.0)
				var at := (d.from as Vector2).lerp(d.to, k * k) + Vector2(0.0, -sin(k * PI) * 14.0)
				ci.draw_mesh(Art.pile(1), null, Art.still(origin + at * u, one * (0.6 + 0.4 * k)))
	_draw_jetty(ci, sim)
	_draw_throws(ci)
	_draw_marks(ci)
	_draw_bits(ci)

## What is on the jetty and at its end, in front of all the land: the loose
## piles as a heap (less the ones still in the air), the bundles that wait
## from its end back, and the raft where the sim has it, with its bundles on
## the way out. A raft gone past the holder's left edge is not drawn.
func _draw_jetty(ci: CanvasItem, sim: RefCounted) -> void:
	var one := Vector2(u, u)
	var loose := int(sim.loose.n) - _air
	if loose > 0:
		ci.draw_mesh(Art.pile(loose, false, true), null, Art.still(origin + Art.jetty() * u, one))
	var waiting: int = sim.bundles.size()
	for i in range(mini(waiting, BUNDLES) - 1, -1, -1):
		ci.draw_mesh(Art.bundle(), null, Art.still(origin + Art.slot(i) * u, one))
	if waiting > BUNDLES:
		_marks.append([Art.slot(BUNDLES - 2) + Vector2(0.0, -40.0), Art.short(waiting)])
	var at := Art.raft_at(sim.raft_at())
	if origin.x + (at.x + Art.RAFT_LONG) * u < 0.0:
		return
	var turn := 0.0
	if not Motion.reduce:
		# it rocks where it lies and steadies as it gets under way
		var calm := 1.0 - 0.6 * minf(1.0, sim.raft_at() * 4.0)
		turn = ROCK * calm * sin(float(sim.clock) * 1.7)
		at.y += BOB * sin(float(sim.clock) * 2.3 + 1.0)
	ci.draw_mesh(Art.raft(int(sim.raft.bundles) if sim.raft.away else 0), null, Art.still(origin + at * u, one, turn))

## The logs in the air between a gathered pile and the jetty.
func _draw_throws(ci: CanvasItem) -> void:
	var to := Art.jetty() + Vector2(0.0, -10.0)
	for t: Dictionary in _throws:
		if t.t <= 0.0:
			continue
		var k := clampf(float(t.t) / FLIGHT, 0.0, 1.0)
		var at := (t.from as Vector2).lerp(to, k * (0.4 + 0.6 * k)) + Vector2(0.0, -sin(k * PI) * ARC)
		ci.draw_mesh(Art.billet(), null, Art.still(origin + at * u, Vector2(u, u), float(t.turn) * (1.0 - k) * 2.4))

## The counts over the stacks: every outline, then every figure, so each is
## one run of glyphs for the renderer.
func _draw_marks(ci: CanvasItem) -> void:
	if _marks.is_empty():
		return
	var font := (ci as Control).get_theme_font("font", "SheetTitle")
	var fs := maxi(12, int(COUNT * u))
	var placed: Array = []
	for m: Array in _marks:
		var text: String = m[1]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		placed.append([origin + (m[0] as Vector2) * u + Vector2(-w * 0.5, 0.0), text])
	for m: Array in placed:
		ci.draw_string_outline(font, m[0], m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, int(7.0 * u)), Color(0.23, 0.19, 0.16, 0.7))
	for m: Array in placed:
		ci.draw_string(font, m[0], m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

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
