extends SceneTree

## The line's geometry, headless:
##     godot --headless --path . --script res://tests/_probe_dominoes_line.gd -- [games]
## Whole hands by a random legal move; after every tile laid, no two tiles of
## the line may overlap, every tile but the first must touch the one it was
## laid against along a side of the half with the matching number, and the
## line must stay inside a row's width. Prints the largest line seen.

const Rules = preload("res://versus/dominoes_rules.gd")
const Board = preload("res://versus/dominoes_board.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 300
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var fails := 0
	var widest := Vector2.ZERO
	var most := 0
	for g in games:
		var r := Rules.new()
		r.deal(rng.randi() & 0x7fffffff)
		while not r.hand_over:
			var legal := r.legal_moves()
			r.make(legal[rng.randi() % legal.size()])
			var why := check(r.plays)
			if why != "":
				fails += 1
				if fails <= 5:
					print("FAIL game ", g, ": ", why, "\n  ", r.plays)
				break
		var box := bounds(Board.lay_line(r.plays))
		widest = Vector2(maxf(widest.x, box.size.x), maxf(widest.y, box.size.y))
		most = maxi(most, r.plays.size())
	print("games %d, longest line %d tiles, widest %.1f, tallest %.1f halves" % [games, most, widest.x, widest.y])
	print("FAILS ", fails)
	quit(1 if fails > 0 else 0)

static func rect(e: Dictionary) -> Rect2:
	var h := Vector2(1.0, 0.5) if int(e.o) % 2 == 0 else Vector2(0.5, 1.0)
	return Rect2(Vector2(e.c) - h, h * 2.0)

static func bounds(lay: Array) -> Rect2:
	var box := Rect2()
	for i in lay.size():
		box = rect(lay[i]) if i == 0 else box.merge(rect(lay[i]))
	return box

## The middle of the half of tile `e` that shows `n`: for a double either,
## or the tile's own middle.
static func half_of(tile: int, e: Dictionary, n: int) -> Array:
	var along := Vector2(0.0, 0.5) if int(e.o) % 2 == 1 else Vector2(0.5, 0.0)
	var first: int = Rules.LO[tile] if int(e.o) < 2 else Rules.HI[tile]
	var second: int = Rules.HI[tile] if int(e.o) < 2 else Rules.LO[tile]
	var out := []
	# a double lying across is touched at the middle of its long side
	if first == second and n == first:
		out.append(Vector2(e.c))
	if first == n:
		out.append(Vector2(e.c) - along)
	if second == n:
		out.append(Vector2(e.c) + along)
	return out

static func check(plays: Array) -> String:
	var lay := Board.lay_line(plays)
	for i in lay.size():
		for j in i:
			if rect(lay[i]).grow(-0.01).intersects(rect(lay[j]).grow(-0.01)):
				return "tiles %d and %d overlap" % [j, i]
	if bounds(lay).size.x > 2.0 * Board.ROW + 0.01:
		return "wider than a row"
	# the tile each was laid against: the last of its arm, or the first
	var last := [0, 0]
	for i in range(1, plays.size()):
		var p: Vector3i = plays[i]
		var prev: int = last[p.y]
		var mine := half_of(p.x, lay[i], p.z)
		var theirs := half_of(plays[prev].x, lay[prev], p.z)
		var touch := false
		for a: Vector2 in mine:
			for b: Vector2 in theirs:
				var d := (a - b).abs()
				if (is_equal_approx(d.x, 1.0) and d.y < 0.01) or (is_equal_approx(d.y, 1.0) and d.x < 0.01):
					touch = true
		if not touch:
			return "tile %d does not touch tile %d on its %d" % [i, prev, p.z]
		last[p.y] = i
	return ""
