extends RefCounted

## Paper Box's rules, scene-free (spec
## docs/superpowers/specs/2026-10-22-paperbox-design.md). Five rounds a day:
## a flat paper net of six coloured squares lies on the cutting mat, and
## three or four boxes stand under it. Exactly one of them is the box the
## net folds into; pick it. A wrong pick is struck off and counted; the
## right one folds the net and puts the box on the shelf. Five boxes on the
## shelf is the solve.
##
## **A wrong box is proven wrong, never assumed**: each is a change of the
## right picture (puzzles/paperbox_fold.gd), kept only when none of the
## folded box's 24 turns shows it. The kinds of change, by band:
##
## - OPPOSITE: a face takes the colour of the side opposite another shown
##   face, so the box shows two sides that never meet.
## - FLIPPED: a face takes the colour (and stamp) of its own opposite side,
##   a real corner of the box but turned the wrong way round.
## - MIRROR: the whole picture seen in a mirror.
## - TURNED: Insane (Stamped) only, a face's stamp turned a quarter or more.
##
## Nothing here knows time or the screen.

enum Picked { RIGHT, WRONG, IGNORED }
enum Kind { OPPOSITE, FLIPPED, MIRROR, TURNED }

const Fold = preload("res://puzzles/paperbox_fold.gd")

const ROUNDS := 5
## Per band, Easy to Insane: the boxes to pick from, the bulb's strikes,
## whether every face carries a stamp (Insane's rule, Stamped), and whether
## the nets are only the crosses.
const CHOICES := [3, 3, 4, 4]
const HINTS := [3, 2, 1, 1]
const STAMPED := [false, false, false, true]
const CROSSES_ONLY := [true, false, false, false]
## The six paper colours, by index (ui/faces/paperbox_art.gd's PAPER).
const COLOURS := 6

var band := 0
## Per round: {"net": Array[Vector2i], "root": int, "colours": Array[int],
## "ways": Array[int] (-1 unstamped), "turn": int (into Fold.turns()),
## "options": Array of pictures, "answer": int, "kinds": Array[int]
## (-1 for the answer)}.
var rounds: Array = []
var current := 0
## The boxes struck off this round, by option.
var struck: Array[bool] = []
## Wrong picks per round, the bulb's strikes not counted.
var wrong_in: Array[int] = []
var wrongs := 0
## Whether this round's box is picked (its fold still playing).
var picked := false

func deal(rng: RandomNumberGenerator, the_band: int) -> void:
	band = clampi(the_band, 0, CHOICES.size() - 1)
	rounds.clear()
	var used: Array[int] = []
	for r in ROUNDS:
		rounds.append(_deal_round(rng, used))
	restart()

func restart() -> void:
	current = 0
	wrongs = 0
	wrong_in.clear()
	for r in ROUNDS:
		wrong_in.append(0)
	picked = false
	_fresh_round()

func _fresh_round() -> void:
	struck.clear()
	if current < rounds.size():
		for o in (rounds[current].options as Array).size():
			struck.append(false)

func _deal_round(rng: RandomNumberGenerator, used: Array[int]) -> Dictionary:
	for tries in 50:
		var count: int = Fold.CROSSES if CROSSES_ONLY[band] else Fold.NETS.size()
		var index := rng.randi_range(0, count - 1)
		# a net not dealt yet today, when one is left
		if used.has(index) and used.size() < count and tries < 20:
			continue
		var net := Fold.placed(index, rng.randi_range(0, 3), rng.randf() < 0.5)
		# the net lies wide on the mat, never tall past four squares
		var ext := Fold.extent(net)
		if ext.y > ext.x:
			net = _swap(net)
		var root := _root(net, rng)
		var colours: Array[int] = []
		for c in COLOURS:
			colours.append(c)
		for i in range(colours.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := colours[i]
			colours[i] = colours[j]
			colours[j] = t
		var ways: Array[int] = []
		for i in net.size():
			ways.append(rng.randi_range(0, 3) if STAMPED[band] else -1)
		var sides := Fold.folded(net, root, colours, ways)
		var turn := rng.randi_range(0, Fold.turns().size() - 1)
		var right: Array = Fold.picture(sides, Fold.turns()[turn])
		var wrong := _wrongs(rng, sides, right)
		if wrong.size() < int(CHOICES[band]) - 1:
			continue
		used.append(index)
		var options := []
		var kinds: Array[int] = []
		for w: Array in wrong:
			options.append(w[1])
			kinds.append(int(w[0]))
		var answer := rng.randi_range(0, options.size())
		options.insert(answer, right)
		kinds.insert(answer, -1)
		return {"net": net, "root": root, "colours": colours, "ways": ways, "turn": turn,
			"options": options, "answer": answer, "kinds": kinds, "net_index": index}
	push_error("paperbox: no round dealt")
	return {}

## A net turned on its side (x and y swapped).
static func _swap(net: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in net:
		out.append(Vector2i(p.y, p.x))
	return out

## The square the fold keeps flat: one of those with the most neighbours,
## so the paper folds up round it.
static func _root(net: Array[Vector2i], rng: RandomNumberGenerator) -> int:
	var best: Array[int] = []
	var most := -1
	for i in net.size():
		var n := 0
		for j in net.size():
			if absi(net[i].x - net[j].x) + absi(net[i].y - net[j].y) == 1:
				n += 1
		if n > most:
			most = n
			best = [i]
		elif n == most:
			best.append(i)
	return best[rng.randi_range(0, best.size() - 1)]

## The band's wrong boxes: [kind, picture], each proven unseen from every
## turn of the box and none twice. Each starts from its own turn of the box,
## never the right picture's, or the right box would be the one the others
## agree with face by face.
func _wrongs(rng: RandomNumberGenerator, sides: Dictionary, right: Array) -> Array:
	var seen: Dictionary = Fold.pictures(sides)
	var taken := {Fold.key(right): true}
	# what each band asks for, in order: a kind per wrong box
	var want: Array[int] = []
	match band:
		0:
			want = [Kind.OPPOSITE, Kind.OPPOSITE]
		1:
			want = [Kind.OPPOSITE, Kind.FLIPPED if rng.randf() < 0.7 else Kind.MIRROR]
		2:
			want = [Kind.FLIPPED, Kind.FLIPPED, Kind.FLIPPED if rng.randf() < 0.6 else Kind.MIRROR]
		_:
			want = [Kind.TURNED, Kind.TURNED, Kind.FLIPPED if rng.randf() < 0.6 else Kind.MIRROR]
	var out := []
	for k: int in want:
		for tries in 40:
			var turn: Basis = Fold.turns()[rng.randi_range(0, Fold.turns().size() - 1)]
			var pool := _changes(k, sides, turn)
			var pic: Array = pool[rng.randi_range(0, pool.size() - 1)]
			var key := Fold.key(pic)
			if seen.has(key) or taken.has(key):
				continue
			taken[key] = true
			out.append([k, pic])
			break
	return out

## Every change of `kind` to the box seen turned by `turn`.
func _changes(kind: int, sides: Dictionary, turn: Basis) -> Array:
	var base: Array = Fold.picture(sides, turn)
	var out := []
	match kind:
		Kind.MIRROR:
			out.append(_mirror(base))
		Kind.OPPOSITE:
			for k in 3:
				for j in 3:
					if j != k:
						var pic := _copy(base)
						pic[k] = [int(Fold.opposite(sides, turn, j)[0]), (base[k] as Array)[1]]
						out.append(pic)
		Kind.FLIPPED:
			for k in 3:
				var pic := _copy(base)
				pic[k] = Fold.opposite(sides, turn, k)
				out.append(pic)
		Kind.TURNED:
			for k in 3:
				var n := Vector3(Fold.SHOWN[k] as Vector3i)
				for q in [1, 2, 3]:
					var pic := _copy(base)
					var v := Vector3((base[k] as Array)[1] as Vector3i)
					for i in q:
						v = n.cross(v)
					pic[k] = [int((base[k] as Array)[0]), Vector3i(roundi(v.x), roundi(v.y), roundi(v.z))]
					out.append(pic)
	return out

## The picture in a mirror stood on the box's near edge: the right face and
## the left trade places, and every stamp's way is mirrored (x and y swap).
static func _mirror(pic: Array) -> Array:
	var out := []
	for slot in [0, 2, 1]:
		var f: Array = pic[slot]
		var m: Vector3i = f[1]
		out.append([int(f[0]), Vector3i(m.y, m.x, m.z)])
	return out

static func _copy(pic: Array) -> Array:
	var out := []
	for f: Array in pic:
		out.append([int(f[0]), f[1]])
	return out

func solved() -> bool:
	return current >= ROUNDS

func stamped() -> bool:
	return bool(STAMPED[band])

func now() -> Dictionary:
	return rounds[mini(current, rounds.size() - 1)]

func options() -> Array:
	return now().options

## The player picked box `i` this round.
func pick(i: int) -> Picked:
	if solved() or picked or i < 0 or i >= struck.size() or struck[i]:
		return Picked.IGNORED
	if i == int(now().answer):
		picked = true
		return Picked.RIGHT
	struck[i] = true
	wrongs += 1
	wrong_in[current] += 1
	return Picked.WRONG

## The fold is over: the next round's net comes to the mat.
func advance() -> void:
	if not picked:
		return
	picked = false
	current += 1
	_fresh_round()

## The bulb: a wrong box still standing, struck off; -1 when none is left.
func strike() -> int:
	if solved() or picked:
		return -1
	var left: Array[int] = []
	for i in struck.size():
		if not struck[i] and i != int(now().answer):
			left.append(i)
	if left.is_empty():
		return -1
	# the day's own pick, so a hint is the same on every phone
	var i: int = left[(current * 7 + wrongs * 3 + struck.count(true)) % left.size()]
	struck[i] = true
	return i

## The brain report: a wrong pick costs a fifth.
func quality() -> float:
	return clampf(1.0 - 0.2 * float(wrongs), 0.0, 1.0)

## A finished day, put back from its record.
func finish(the_wrongs: Array) -> void:
	wrongs = 0
	for r in ROUNDS:
		wrong_in[r] = int(the_wrongs[r]) if r < the_wrongs.size() else 0
		wrongs += wrong_in[r]
	current = ROUNDS
	picked = false
	struck.clear()

## The day for the share line: a box a square, green right first time,
## yellow after one wrong pick, red after more.
func share_glyphs() -> String:
	var out := ""
	for r in ROUNDS:
		out += "🟩" if wrong_in[r] == 0 else ("🟨" if wrong_in[r] == 1 else "🟥")
	return out
