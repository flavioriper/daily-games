extends SceneTree

## Pixel Garden's feedback latency, measured on the bank (2026-10-29, the
## made-fun pass): each band's pictures seated in reading order with the
## first bead the wrong colour, counting the beads seated after the slip
## until the kit runs out of a colour (`none_left`), until the iron speaks
## (the board full), and until the row the slip sits in is complete (what a
## row's leaf would say). And the counting burden: how far a picture's bead
## is from the nearest board edge or plate seam, in pegs.
##
##     godot --headless --script res://tests/_probe_pg_fun.gd

const State = preload("res://puzzles/pixel_garden_state.gd")

func _initialize() -> void:
	for band in 4:
		var pics: Array = State.band_pictures(band)
		var none_at: Array = []
		var iron_at: Array = []
		var row_at: Array = []
		var far: Array = []
		for pic in pics:
			var st = State.new()
			st.band = band
			st.load_picture(pic)
			var n: int = st.n
			var order: Array = []
			for c in st.size():
				if st.want[c] != State.EMPTY:
					order.append(c)
					var x := c % n
					var y := c / n
					var d := mini(mini(x, n - 1 - x), mini(y, n - 1 - y))
					d = mini(d, mini(absi(x - st.half), absi(x - (st.half - 1))))
					d = mini(d, mini(absi(y - st.half), absi(y - (st.half - 1))))
					far.append(d)
			if st.names.size() < 2:
				continue
			var slip: int = order[0]
			var wrong: int = (st.want[slip] + 1) % st.names.size()
			var row_end := 0
			for i in order.size():
				if int(order[i]) / n == slip / n:
					row_end = i
			row_at.append(row_end)
			st.put(slip, wrong)
			var seated := 0
			var none := -1
			for i in range(1, order.size()):
				var c: int = order[i]
				var r: String = st.put(c, st.want[c])
				if r == "none_left" and none < 0:
					none = seated
				if r == "put":
					seated += 1
			none_at.append(none if none >= 0 else seated)
			iron_at.append(order.size() - 1)
		print("band %d (%d pictures): beads after the slip until none_left median %d max %d; until the iron median %d max %d; until its row ends median %d max %d; bead to edge/seam median %d max %d" % [
			band, pics.size(), _med(none_at), _max(none_at), _med(iron_at), _max(iron_at),
			_med(row_at), _max(row_at), _med(far), _max(far)])
	quit()

static func _med(a: Array) -> int:
	if a.is_empty():
		return -1
	var s := a.duplicate()
	s.sort()
	return int(s[s.size() / 2])

static func _max(a: Array) -> int:
	var m := -1
	for v in a:
		m = maxi(m, int(v))
	return m
