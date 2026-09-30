extends SceneTree
## Throwaway: the live carry (segment hand->hole, apply_toward) equals Gen.apply.
const Gen = preload("res://puzzles/untangle_gen.gd")
func _initialize() -> void:
	var bad := 0
	var total := 0
	var rng := RandomNumberGenerator.new()
	for band in 4:
		for seed in 12:
			rng.seed = seed * 31 + band
			var deal: Dictionary = Gen.generate(rng, band)
			var at: PackedInt32Array = deal.start if deal.has("start") else deal.at
			var tw: PackedInt32Array = deal.start_tw if deal.has("start_tw") else deal.tw
			var holes: int = deal.holes
			var ropes: int = at.size() / 2
			var occ := Gen.occupancy(at, holes)
			for p in at.size():
				for h in holes:
					if occ[h] >= 0:
						continue
					var a1 := at.duplicate(); var t1 := tw.duplicate()
					Gen.apply(a1, t1, ropes, p, h)
					for frac in [0.97, 1.0]:
						var A := _px(at[p], holes)
						var P := A.lerp(_px(h, holes), frac)
						var over := 0
						for y in ropes:
							if y != p >> 1 and Geometry2D.segment_intersects_segment(A, P, _px(at[2*y], holes), _px(at[2*y+1], holes)) != null:
								over |= 1 << y
						var t2 := tw.duplicate()
						if over != 0:
							var d := P - A
							var far := A + d * (-2.0 * A.dot(d) / d.length_squared())
							var to := fposmod((far.angle() + PI * 0.5) / TAU * holes, float(holes))
							Gen.apply_toward(at, t2, ropes, p, to, over)
						total += 1
						if t2 != t1:
							bad += 1
	print("live==apply: ", total - bad, "/", total)
	quit()
func _px(h: int, n: int) -> Vector2:
	return Vector2.from_angle(TAU * float(h) / n - PI * 0.5) * 300.0
