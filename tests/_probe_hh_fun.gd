extends SceneTree

## Why Hedgehogs is not fun, measured (headless, scene-free):
##
##     godot --headless --path . --script res://tests/_probe_hh_fun.gd -- [nights=40]
##
## Per band, over `nights` lawns dealt as the game deals them:
## - singles: a player who reads one number at a time (no subsets, no
##   count) -- the nights it stalls and the bare piles left when it does;
## - open: what the opening hands over -- cells it rakes, and how many
##   piles the first reading decides;
## - taps: a full-logic player, a tap a pile (raking or flagging every
##   proved one) against one who taps numbers (a number with its flags rakes
##   the rest, a number whose covered piles are all it still needs flags
##   them all) and only taps a pile when no number decides;
## - spent: at half way, the share of raked numbers with no covered pile
##   left round them (nothing left to read there).

const Gen = preload("res://puzzles/hedgehogs_gen.gd")

func _initialize() -> void:
	var nights := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("nights="):
			nights = int(a.substr(7))
	for d in 4:
		var stall := 0
		var left_sum := 0
		var opened := 0
		var first := 0
		var first_one := 0
		var taps_pile := 0
		var taps_num := 0
		var num_flags := 0
		var hogs := 0
		var spent_sum := 0.0
		var spent_n := 0
		for night in nights:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7919 * (night + 1) + d
			var g := Gen.generate(rng, d)
			var open := PackedByteArray()
			open.resize(g.n)
			opened += Gen.flood(g, open, g.start).size()
			var known := PackedByteArray()
			known.resize(g.n)
			var f0 := Gen.deduce(g, open, known, false)
			var decided: int = (f0.safe.size() + f0.hogs.size()) if not f0.is_empty() else 0
			first += decided
			if decided <= 1:
				first_one += 1
			var s := _singles(g)
			if s > 0:
				stall += 1
				left_sum += s
			taps_pile += _pile_taps(g, d)
			var r := _number_taps(g, d)
			taps_num += int(r.taps)
			num_flags += int(r.flag_chords)
			hogs += int(g.k)
			if r.spent >= 0.0:
				spent_sum += float(r.spent)
				spent_n += 1
		print("band %d: singles stall %d/%d (bare left %.1f) | opening %.1f cells, first reading decides %.1f (%d nights <= 1) | taps a pile %.1f, by numbers %.1f (flag chords %.1f a night, %d hogs) | spent at half %.0f%%" % [
			d, stall, nights, float(left_sum) / maxf(1.0, stall), float(opened) / nights,
			float(first) / nights, first_one, float(taps_pile) / nights, float(taps_num) / nights,
			float(num_flags) / nights, int(hogs / nights), 100.0 * spent_sum / maxf(1.0, spent_n)])
	quit()

## Bare piles a singles-only reader leaves covered (0 = it plays out).
func _singles(g: Dictionary) -> int:
	var open := PackedByteArray()
	open.resize(g.n)
	Gen.flood(g, open, g.start)
	var known := PackedByteArray()
	known.resize(g.n)
	while true:
		var d := _single_only(g, open, known)
		if d.is_empty():
			break
		for r: int in d.hogs:
			known[r] = 1
		for r: int in d.safe:
			if open[r] == 0:
				Gen.flood(g, open, r)
	var left := 0
	for c in int(g.n):
		if g.hog[c] == 0 and open[c] == 0:
			left += 1
	return left

func _single_only(g: Dictionary, open: PackedByteArray, known: PackedByteArray) -> Dictionary:
	var d := Gen.deduce(g, open, known, false)
	if d.is_empty() or d.rule != "single":
		return {}
	return d

## A tap for every proved pile: each bare one raked (a flood is one tap),
## each hedgehog flagged.
func _pile_taps(g: Dictionary, band: int) -> int:
	var open := PackedByteArray()
	open.resize(g.n)
	Gen.flood(g, open, g.start)
	var known := PackedByteArray()
	known.resize(g.n)
	var taps := 0
	for guard in 1000:
		var d := Gen.deduce(g, open, known, band >= 2)
		if d.is_empty():
			break
		for r: int in d.hogs:
			if known[r] == 0:
				known[r] = 1
				taps += 1
		for r: int in d.safe:
			if open[r] == 0:
				Gen.flood(g, open, r)
				taps += 1
	return taps

## Numbers first: a number with all its hedgehogs flagged rakes the rest, a
## number whose covered piles are exactly what it still needs flags them;
## a pile tapped only when no number decides anything. Flags are always
## right here (they come from logic).
func _number_taps(g: Dictionary, band: int) -> Dictionary:
	var n: int = g.n
	var open := PackedByteArray()
	open.resize(n)
	Gen.flood(g, open, g.start)
	var flag := PackedByteArray()
	flag.resize(n)
	var taps := 0
	var chords := 0
	var bare := 0
	for c in n:
		if g.hog[c] == 0:
			bare += 1
	var spent := -1.0
	for guard in 2000:
		var raked := 0
		for c in n:
			raked += open[c]
		if spent < 0.0 and raked * 2 >= bare:
			var nums := 0
			var done := 0
			for c in n:
				if open[c] == 1 and int(g.num[c]) > 0:
					nums += 1
					var cov := 0
					for r: int in g.nb[c]:
						if open[r] == 0 and flag[r] == 0:
							cov += 1
					if cov == 0:
						done += 1
			spent = float(done) / maxf(1.0, nums)
		if raked == bare:
			break
		var acted := false
		for c in n:
			if open[c] == 0 or int(g.num[c]) <= 0:
				continue
			var cov := PackedInt32Array()
			var f := 0
			for r: int in g.nb[c]:
				if flag[r] == 1:
					f += 1
				elif open[r] == 0:
					cov.append(r)
			if cov.is_empty():
				continue
			var v: int = g.num[c]
			if f == v:
				for r in cov:
					Gen.flood(g, open, r)
				taps += 1
				acted = true
				break
			if f + cov.size() == v:
				for r in cov:
					flag[r] = 1
				taps += 1
				chords += 1
				acted = true
				break
		if acted:
			continue
		var d := Gen.deduce(g, open, flag, band >= 2)
		if d.is_empty():
			break
		for r: int in d.hogs:
			if flag[r] == 0:
				flag[r] = 1
				taps += 1
		for r: int in d.safe:
			if open[r] == 0:
				Gen.flood(g, open, r)
				taps += 1
	return {"taps": taps, "flag_chords": chords, "spent": spent}
