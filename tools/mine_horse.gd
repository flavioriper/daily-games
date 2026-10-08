extends SceneTree

## Mines Horse Pen's meadows: lays one for the band (puzzles/horse_gen.gd),
## searches long for the best pen its stock of bales can close, and prints
## the survivors as JSON lines.
##
##     godot --headless --script res://tools/mine_horse.gd -- <band> <count> [seed]
##
## Then `python3 tools/merge_horse.py` gathers the bands' lines into
## content/horse.json. `best` is the best pen a long search found, which is
## what the day's target is a share of; it is not a proof of the optimum.
##
##     ... -- <band> <count> <seed> check
##
## prints, for each meadow, the phone's own short search beside the miner's
## and a search four times as long again, with the milliseconds each took.

const Gen = preload("res://puzzles/horse_gen.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var band := int(args[0])
	var count := int(args[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[2]) if args.size() > 2 else 7000 + band
	if args.size() > 3 and args[3] == "show":
		for k in count:
			var t0 := Time.get_ticks_msec()
			var m := Gen.generate(rng, band)
			print("live %d ms" % (Time.get_ticks_msec() - t0))
			if not m.is_empty():
				_show(m)
		quit()
		return
	if args.size() > 3 and args[3] == "check":
		_check(rng, band, count)
		quit()
		return
	var made := 0
	var tries := 0
	var seen := {}
	while made < count and tries < count * 6:
		tries += 1
		var m := Gen.generate(rng, band, Gen.GROWS_MINE, Gen.STEPS_MINE)
		if m.is_empty():
			continue
		var packed := Gen.pack(m)
		var key := JSON.stringify([packed.water, packed.stones, packed.horse])
		if seen.has(key):
			continue
		seen[key] = true
		made += 1
		print(JSON.stringify(packed))
		printerr("band %d %d/%d: best %d with %d of %d" % [band, made, count, packed.best,
			(packed.sol as Array).size(), packed.budget])
	quit()

func _check(rng: RandomNumberGenerator, band: int, count: int) -> void:
	for k in count:
		var t0 := Time.get_ticks_msec()
		var m := Gen.generate(rng, band)
		var live_ms := Time.get_ticks_msec() - t0
		if m.is_empty():
			print("no meadow")
			continue
		var budget: int = m.budget
		t0 = Time.get_ticks_msec()
		var mine := Gen.search(rng, m, budget, Gen.GROWS_MINE, Gen.STEPS_MINE)
		var mine_ms := Time.get_ticks_msec() - t0
		t0 = Time.get_ticks_msec()
		var deep := Gen.search(rng, m, budget, Gen.GROWS_MINE * 2, Gen.STEPS_MINE * 4)
		var deep_ms := Time.get_ticks_msec() - t0
		var again := Gen.search(rng, m, budget, Gen.GROWS_MINE, Gen.STEPS_MINE)
		print("band %d #%d: live %d (%d ms)  mine %d / %d (%d ms)  deep %d (%d ms)  grow-only %d" % [
			band, k, m.best, live_ms, mine.score, again.score, mine_ms, deep.score, deep_ms,
			int(Gen.search(rng, m, budget, 80, 0).score)])

## The meadow as text: ~ water, o boulder, H horse, a apple, G golden apple,
## b hive, T tunnel, # the answer's bales.
func _show(m: Dictionary) -> void:
	var w: int = m.w
	var twin: PackedInt32Array = m.twin
	var out := "best %d, %d of %d bales\n" % [m.best, (m.sol as Array).size(), m.budget]
	for i in int(m.w) * int(m.h):
		var ch := "."
		if m.block[i] == Gen.WATER: ch = "~"
		elif m.block[i] == Gen.STONE: ch = "o"
		elif i == int(m.horse): ch = "H"
		elif m.item[i] == Gen.APPLE: ch = "a"
		elif m.item[i] == Gen.GOLD: ch = "G"
		elif m.item[i] == Gen.BEE: ch = "b"
		elif twin[i] >= 0: ch = "T"
		elif (m.sol as Array).has(i): ch = "#"
		out += ch + (" " if i % w < w - 1 else "\n")
	print(out)
