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
## - **The grove's own beavers** (2026-10-07, `sim.gnawing`) are the same
##   animal at the same place: a tree one of them is at has its beaver for as
##   long as it is gnawed, rearing as the sim's bite comes due, and the circle
##   on that tree brings no second one. It comes to a new tree ARRIVE after it
##   took it (it is still hopping at the one it felled), and one with no tree
##   to go to sits at the back of the land, each at its own place.
## - **A crate** lies where the sim has it (`sim.crate`), in with the trees by
##   depth: a box the wind leaves alone, as it does the wood. On `washed` it
##   bobs in on the water off the nearer front edge and is thrown up onto the
##   grass (WASH); `opened` bursts its boards as chips.
## - `doubled` says a lucky pile has just come to rest, for whoever writes
##   "x2" over it.
##
## Under reduce motion a beaver is there or not and only changes its face, a
## felled tree fades where it stands, both signals come at once, a pile is
## there with them, nothing is thrown, the raft lies still and a crate is
## there or gone.

signal landed(tree: Dictionary, at: Vector2)
signal gave(tree: Dictionary, give: int, at: Vector2)
## A log thrown from a gathered pile has reached the jetty.
signal carried
## A lucky pile has come to rest: `at` is the place over its stack, in view
## units, for the "x2" that says so.
signal doubled(at: Vector2)

const Sim = preload("res://valley/grove_sim.gd")
const Art = preload("res://valley/grove_art.gd")
const Beaver = preload("res://ui/faces/beaver.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

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
## One of the grove's own beavers is seen at the tree it has taken this long
## after it took it (a cheer is CHEER, and it is not at two trees at once),
## and at its resting place this long after it had no tree to go to.
const ARRIVE := 0.6
const REST_AFTER := 0.7
## Where they rest: along the land's back right edge, off the jetty's side of
## the land and where no tree stands. Ground units: how far along the edge
## from the back corner the first sits, how far apart, how far in from the
## edge; and how big one is drawn.
const REST_FROM := 200.0
const REST_GAP := 90.0
const REST_IN := 30.0
const REST_SIZE := 0.8
## A crate's seconds from the water to the grass, the share of them it bobs
## on the water before the pond throws it up, how far off the land's foot it
## is first seen and how near it comes (ground units), and how high it is
## thrown (view units). One that would come in under the jetty comes in
## WASH_CLEAR to the side of its planks (ground units).
const WASH := 0.6
const WASH_AFLOAT := 0.4
const WASH_FAR := 74.0
const WASH_NEAR := 22.0
const WASH_TOSS := 44.0
const WASH_CLEAR := 44.0
## The boards a crate bursts into.
const BOARDS := 9

## The view's (0, 0) in the holder's pixels, and the pixels a unit.
var origin := Vector2.ZERO
var u := 1.0
## The material for the Control `draw_shade` draws on.
var shade: ShaderMaterial

var _hit := {}        # tree id -> seconds since it was hit
var _falls: Array = []    # {tree, give, t, dir, down, given}
var _beavers := {}    # tree id -> {tree, side, show, rising, seen, bite, cheer, age, size, own}
var _bits: Array = []     # {pos, vel, t, life, turn, spin, col, size, weight, board}: view units
var _bit_mm: MultiMesh
var _board_mm: MultiMesh
var _swing := Sim.SWING
var _rng := RandomNumberGenerator.new()
## Piles the sim has that are not seen yet, by their stack's id: each one's
## tree is still coming down, or it is on its way out of the crown.
var _owed := {}
var _drops: Array = []    # {id, from, to, t}: a pile out of a lying crown; view units
var _throws: Array = []   # {from, t, n, turn}: a log to the jetty, standing for `n` piles
## Piles the sim has on the jetty whose logs are still in the air, and
## whether the jetty's heap was drawn last time.
var _air := 0
var _heaped := false
var _marks: Array = []    # [at, text]: the counts of this frame's draw, view units
## The grove's own beavers, one a place of `sim.gnawing`: {idle, show, rising,
## age}, `idle` the seconds it has had no tree.
var _rests: Array = []
## Seconds since the crate washed up: WASH and over, it lies on the grass.
var _washed := WASH

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
	_step_own(delta, sim)
	_washed += delta
	for id in _beavers.keys():
		var b: Dictionary = _beavers[id]
		b.seen += delta
		b.bite += delta
		b.age += delta
		if b.cheer >= 0.0:
			b.cheer += delta
		var want: bool = b.seen < LINGER or float(b.own) >= 0.0 or (b.cheer >= 0.0 and b.cheer < CHEER)
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
## cheers. `give` is what it leaves, handed back with `gave`. `lucky`: its
## pile is a double one, and `doubled` says so as it comes to rest.
func fell(tree: Dictionary, give: int, lucky := false) -> void:
	var b := _beaver(tree)
	b.cheer = 0.0
	var f := {"tree": tree, "give": give, "t": 0.0, "dir": -float(b.side), "down": false, "given": false, "pile": {}, "lucky": lucky}
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
	if f.given and f.lucky:
		# reduce motion: the pile is there at once, and so is its sign
		f.lucky = false
		doubled.emit(_over(pile))
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
		if f.lucky:
			doubled.emit(_over(pile))
		return
	_drops.append({"id": int(pile.id), "from": _crown_at(f), "to": Art.see(pile.pos), "t": 0.0, "pile": pile, "lucky": f.lucky})

## The place over a stack where a word about it is written, in view units:
## clear of its heap, and of its count when it has one.
func _over(pile: Dictionary) -> Vector2:
	var n := int(pile.n)
	return Art.see(pile.pos) + Vector2(0.0, -Art.heap_tall(n) - (COUNT + 12.0 if n > 1 else 8.0))

## The sim said `crate`: one comes in off the pond.
func washed() -> void:
	_washed = WASH if Motion.reduce else 0.0

## The sim said `opened`: the crate that lay at `pos` (land units) is gone,
## and its boards fly.
func opened(pos: Vector2) -> void:
	_washed = WASH
	if Motion.reduce:
		return
	var at := Art.see(pos) + Vector2(0.0, -Art.CRATE_TALL * 0.5)
	for i in BOARDS:
		_bit(at + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-12.0, 10.0)),
			Vector2(_rng.randf_range(-190.0, 190.0), -_rng.randf_range(150.0, 340.0)), _rng.randf_range(0.55, 0.85),
			[Pal.WOOD, Pal.WOOD_DEEP, Pal.WOOD.lightened(0.2)][i % 3], _rng.randf_range(0.9, 1.35), 0.9, true)

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
			if d.lucky:
				doubled.emit(_over(d.pile))
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

## The beaver a tree has, made if it has none: `seen` is how long ago the
## circle was on the tree, for a new one (LINGER and over: it is not here for
## the circle). `own` is how near the next bite of one of the grove's own
## beavers at it is, 0 to 1, and under 0 when none is.
func _beaver(tree: Dictionary, seen := 0.0) -> Dictionary:
	if not _beavers.has(tree.id):
		_beavers[tree.id] = {"tree": tree, "side": -1.0 if int(tree.id) % 2 == 0 else 1.0, "show": 0.0, "rising": true,
			"seen": seen, "bite": 10.0, "cheer": -1.0, "age": 0.0, "size": 0.7 + 0.004 * Sim.radius_of(tree.tier), "own": -1.0}
	return _beavers[tree.id]

## The grove's own beavers, as the sim has them now. One at a standing tree
## is that tree's beaver, the one the circle would bring: it is kept for as
## long as the tree is gnawed, and comes ARRIVE after it took the tree, since
## until then it is hopping at the one it felled. One with no tree sits at
## its place at the back of the land once it has had none for REST_AFTER (a
## frame without one, between two trees, is not a rest).
func _step_own(delta: float, sim: RefCounted) -> void:
	for id in _beavers:
		_beavers[id].own = -1.0
	var team: Array = sim.gnawing
	while _rests.size() < team.size():
		_rests.append({"idle": REST_AFTER, "show": 0.0, "rising": true, "age": 0.0})
	_rests.resize(team.size())
	if team.is_empty():
		return
	var standing := {}
	for tree: Dictionary in sim.trees:
		standing[int(tree.id)] = tree
	for i in team.size():
		var g: Dictionary = team[i]
		var r: Dictionary = _rests[i]
		r.age += delta
		if standing.has(int(g.tree)):
			r.idle = 0.0
			var b := _beaver(standing[int(g.tree)], LINGER)
			if float(b.show) > 0.0 or float(g.t) >= ARRIVE:
				b.own = clampf(float(g.t) / Sim.BITE_EVERY, 0.0, 1.0)
		else:
			r.idle += delta
		var want: bool = r.idle >= REST_AFTER
		r.rising = want
		r.show = move_toward(float(r.show), 1.0 if want else 0.0, delta / (SHOW_IN if want else SHOW_OUT))

## Where the `i`th of the grove's own beavers rests, in land units: along the
## back right edge from the back corner, REST_IN inside it.
static func rest_at(i: int) -> Vector2:
	var k := sqrt(0.5)
	return Vector2(Sim.HALF, 0.0) + Vector2(k, k) * (REST_FROM + REST_GAP * i) + Vector2(-k, k) * REST_IN

## A crate at `pos` (land units) on its way in, `k` of the way (0 to 1), in
## view units, and how far it is turned: it bobs toward the land's foot on
## the water off the nearer of the two front edges, and the pond throws it up
## over the earth onto the grass.
static func _wash(pos: Vector2, k: float) -> Array:
	var d := pos - Sim.LAND * 0.5
	var side := -1.0 if d.x < 0.0 else 1.0
	var out := Vector2(side, 1.0) * sqrt(0.5)
	var edge := pos + out * ((Sim.HALF - (side * d.x + d.y)) * sqrt(0.5))
	if side < 0.0:
		# the jetty stands off the middle of the front left edge: a crate
		# does not float through its posts, it comes in beside them
		var along := Vector2(1.0, 1.0) * sqrt(0.5)
		var off := (edge - Vector2(Sim.HALF * 0.5, Sim.HALF * 1.5)).dot(along)
		var clear := Art.JETTY_WIDE * 0.5 + WASH_CLEAR
		if absf(off) < clear:
			edge += along * ((clear if off >= 0.0 else -clear) - off)
	var foot := Vector2(0.0, Art.DEPTH)
	var near := Art.see(edge + out * WASH_NEAR) + foot
	if k < WASH_AFLOAT:
		var a := k / WASH_AFLOAT
		return [(Art.see(edge + out * WASH_FAR) + foot).lerp(near, a * (2.0 - a)) + Vector2(0.0, 3.0 * sin(a * TAU)), 0.12 * side * sin(a * TAU)]
	var b := (k - WASH_AFLOAT) / (1.0 - WASH_AFLOAT)
	return [near.lerp(Art.see(pos), b) + Vector2(0.0, -sin(b * PI) * WASH_TOSS), -0.3 * side * sin(b * PI)]

## `board`: a crate's board, not a chip or a leaf.
func _bit(at: Vector2, vel: Vector2, life: float, colour: Color, size: float, weight: float, board := false) -> void:
	if _bits.size() >= BITS:
		return
	_bits.append({"pos": at, "vel": vel, "t": 0.0, "life": life, "turn": _rng.randf() * TAU,
		"spin": _rng.randf_range(-9.0, 9.0), "col": colour, "size": size, "weight": weight, "board": board})

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
	for i in _rests.size():
		if float(_rests[i].show) > 0.0:
			list.append([rest_at(i).y, 5, i])
	# a crate ashore lies among the trees; one still coming in is over them
	# all, since it comes from the front
	var crate: Dictionary = sim.crate
	var ashore: bool = _washed >= WASH or Motion.reduce
	if not crate.is_empty() and ashore:
		list.append([float(crate.pos.y) + 0.5, 6, crate])
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
			5:
				_draw_rest(ci, int(item[2]))
			6:
				ci.draw_mesh(Art.crate(), null, Art.still(_px(item[2].pos), one))
	if not crate.is_empty() and not ashore:
		var way := _wash(crate.pos, _washed / WASH)
		ci.draw_mesh(Art.crate(), null, Art.still(origin + (way[0] as Vector2) * u, one, way[1]))
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
	# a bundle tied out of piles whose logs are still coming leaves fewer
	# than are in the air: a heap that was there keeps a log, not a blink
	if loose <= 0 and _heaped and int(sim.loose.n) > 0:
		loose = 1
	_heaped = loose > 0
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
		elif float(b.own) >= 0.0:
			# one of the grove's own, with no circle on its tree: its bite
			# comes due on the sim's count, not on the swing
			rear = smoothstep(0.5, 1.0, float(b.own))
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

## One of the grove's own beavers with no tree to go to, sitting at its
## place at the back of the land and looking into it: the same three meshes,
## popped in, its tail and its head barely moving.
func _draw_rest(ci: CanvasItem, i: int) -> void:
	var r: Dictionary = _rests[i]
	var show: float = r.show
	var grow := 1.0
	var wag := 0.0
	var nod := 0.0
	if not Motion.reduce:
		grow = Motion.back_out(show) if r.rising else show
		wag = 0.05 * sin(float(r.age) * 2.2 + i * 1.7)
		nod = 0.04 * sin(float(r.age) * 1.3 + i * 2.3)
	var s := REST_SIZE * u * grow
	var xf := Transform2D(0.0, Vector2(-s, s), 0.0, _px(rest_at(i)))
	ci.draw_mesh(Beaver.tail(), null, xf * Transform2D(wag, Beaver.TAIL_AT))
	ci.draw_mesh(Beaver.body(), null, xf)
	ci.draw_mesh(Beaver.head(false), null, xf * Transform2D(nod, Beaver.NECK))

## Chips and burst leaves, one MultiMesh, and a crate's boards while any
## fly, a second.
func _draw_bits(ci: CanvasItem) -> void:
	if _bits.is_empty():
		return
	if _bit_mm == null:
		_bit_mm = _bits_of(Art.leaf())
		_board_mm = _bits_of(Art.board())
	var n := 0
	var boards := 0
	for bit: Dictionary in _bits:
		var t: float = bit.t
		var a := clampf((float(bit.life) - t) / 0.2, 0.0, 1.0)
		var flat := 0.35 + 0.65 * absf(cos(t * 9.0 + float(bit.turn)))
		var s: float = float(bit.size) * u
		var xf := Transform2D(float(bit.turn), Vector2(s, s * flat), 0.0, origin + (bit.pos as Vector2) * u)
		if bit.board:
			_board_mm.set_instance_transform_2d(boards, xf)
			_board_mm.set_instance_color(boards, Color(bit.col as Color, a))
			boards += 1
		else:
			_bit_mm.set_instance_transform_2d(n, xf)
			_bit_mm.set_instance_color(n, Color(bit.col as Color, a))
			n += 1
	if n > 0:
		_bit_mm.visible_instance_count = n
		ci.draw_multimesh(_bit_mm, null)
	if boards > 0:
		_board_mm.visible_instance_count = boards
		ci.draw_multimesh(_board_mm, null)

func _bits_of(mesh: ArrayMesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = BITS
	return mm
