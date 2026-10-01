extends SceneTree
const State = preload("res://puzzles/sunbeam_state.gd")
func _initialize() -> void:
	var woke := 0
	var hints := 0
	for seed_i in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + seed_i
		var st = State.new()
		st.build(rng, 2)
		while not st.is_solved():
			if st.hint().is_empty():
				break
			hints += 1
			if not st.woken().is_empty() and not st.is_solved():
				woke += 1
	print("hard: %d hints, %d left a snail lit" % [hints, woke])
	quit()
