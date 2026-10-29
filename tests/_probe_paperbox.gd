extends SceneTree
## Throwaway: Paper Box's days. Every net folds into six sides; 365 days a
## band, each round with exactly one option some turn of its box shows, the
## band's count of boxes, and the worst deal time.
const Fold = preload("res://puzzles/paperbox_fold.gd")
const PS = preload("res://puzzles/paperbox_state.gd")
func _initialize() -> void:
	var bad := 0
	for i in Fold.NETS.size():
		for q in 4:
			for flip in [false, true]:
				var net := Fold.placed(i, q, flip)
				for root in net.size():
					var sides := Fold.folded(net, root, [0, 1, 2, 3, 4, 5], [0, 1, 2, 3, 0, 1])
					if sides.size() != 6 or Fold.pictures(sides).size() != 24:
						bad += 1
						print("net %d q%d flip %s root %d: %d sides, %d pictures" % [i, q, flip, root, sides.size(), Fold.pictures(sides).size()])
	print("nets: %d bad" % bad)
	var f := Fold.frames(Fold.placed(0, 0, false), 1, PI * 0.5)
	print("frame +x of root: normal ", f[2].basis * Vector3(0, 0, 1), " origin ", f[2].origin)
	for band in 4:
		var worst := 0
		var wrong_days := 0
		var kinds := {}
		var consensus := 0
		var odd := 0
		var whys := {}
		var no_opp := 0
		for s in 365:
			var rng := RandomNumberGenerator.new()
			rng.seed = 20261022 + s * 7919 + band
			var st = PS.new()
			var t := Time.get_ticks_msec()
			st.deal(rng, band)
			worst = maxi(worst, Time.get_ticks_msec() - t)
			for r: Dictionary in st.rounds:
				if r.is_empty():
					wrong_days += 1
					continue
				var sides := Fold.folded(r.net, r.root, r.colours, r.ways)
				var seen := Fold.pictures(sides)
				var ok := 0
				var at := -1
				var keys := {}
				for o in (r.options as Array).size():
					var k := Fold.key(r.options[o])
					keys[k] = true
					if seen.has(k):
						ok += 1
						at = o
				# the answer must not be the picture the others agree with
				var agree := []
				for o in (r.options as Array).size():
					var n := 0
					for o2 in (r.options as Array).size():
						if o2 != o:
							for slot in 3:
								if (r.options[o][slot] as Array)[0] == (r.options[o2][slot] as Array)[0] and (r.options[o][slot] as Array)[1] == (r.options[o2][slot] as Array)[1]:
									n += 1
					agree.append(n)
				var most: int = agree.max()
				if agree[int(r.answer)] == most and agree.count(most) == 1:
					consensus += 1
				var least: int = agree.min()
				if agree[int(r.answer)] == least and agree.count(least) == 1:
					odd += 1
				for k in r.kinds:
					kinds[k] = int(kinds.get(k, 0)) + 1
				var has_opp := false
				for o in (r.options as Array).size():
					var w := PS.why(r, o)
					if o == int(r.answer):
						continue
					if w.is_empty() or (w.squares as Array).is_empty():
						whys["none"] = int(whys.get("none", 0)) + 1
						continue
					var name: String = ["opp", "corner", "stamp"][int(w.why)]
					if int(w.why) == PS.Why.CORNER:
						var sd := Fold.folded(r.net, r.root, r.colours, r.ways)
						var nn := {}
						for n: Vector3i in sd:
							nn[int(sd[n][0])] = n
						var shown := int(r.options[o][w.faces[0]][0])
						if nn[shown] != -(nn[int(w.real)] as Vector3i) or (w.keep as Array) != [0, 1]:
							name += "_BAD" if nn[shown] != -(nn[int(w.real)] as Vector3i) else "_keep%s" % str(w.keep)
						name += "_row" if PS.in_a_row(r.net, w.squares[0], w.squares[1]) else "_bent"
					if int(w.why) == PS.Why.OPPOSITE:
						has_opp = true
						name += "_row" if PS.in_a_row(r.net, w.squares[0], w.squares[1]) else "_bent"
					var pair := "%d>%s" % [int(r.kinds[o]), name]
					whys[pair] = int(whys.get(pair, 0)) + 1
				if not has_opp:
					no_opp += 1
				if ok != 1 or at != int(r.answer) or keys.size() != PS.CHOICES[band] or (r.options as Array).size() != PS.CHOICES[band]:
					wrong_days += 1
					print("  band %d day %d: %d right, answer %d at %d, %d options" % [band, s, ok, r.answer, at, (r.options as Array).size()])
		print("band %d whys (kind>why): %s, rounds with no opposite box %d" % [band, str(whys), no_opp])
		print("band %d: %d bad rounds, worst deal %d ms, kinds %s, answer alone agreed most %d, least %d of 1825" % [band, wrong_days, worst, str(kinds), consensus, odd])
	quit()
