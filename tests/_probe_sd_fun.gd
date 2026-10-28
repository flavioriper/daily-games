extends SceneTree
## Scratch: hint kinds when a player leans on the bulb alone, per band.
const Gen = preload("res://puzzles/sudoku_gen.gd")
const State = preload("res://puzzles/sudoku_state.gd")
func _process(_d: float) -> bool:
	for band in 4:
		var kinds := {}
		var bad := 0
		for day in 10:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2000 + day
			var s := State.new()
			s.setup(rng, band, day)
			# one wrong number first
			for i in Gen.CELLS:
				if s.grid[i] == 0:
					s.place(i, (int(s.sol[i]) % Gen.N) + 1)
					break
			while not s.is_solved():
				s.hints_left = 99
				var st := s.hint_step()
				kinds[st.kind] = int(kinds.get(st.kind, 0)) + 1
				var i := s.hint()
				if i < 0 or s.grid[i] != s.sol[i]:
					bad += 1
					break
		print("band %d: %s, failures %d" % [band, kinds, bad])
	return true
