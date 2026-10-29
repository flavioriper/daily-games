extends SceneTree

## How Big?, measured (2026-10-29 made-fun pass). A player who guesses each
## round off by a random ratio (log-normal, `spread` wide) and locks. Reports
## per band: points p50, the stars the day ends on, the best run of close
## rounds, how often the card names a thing the guess was the size of, and
## a few of the card's notes as written.
##
##     godot --headless --path . --script res://tests/_probe_hb_fun.gd

const State = preload("res://puzzles/how_big_state.gd")
const Board = preload("res://puzzles/how_big2d.gd")

func _initialize() -> void:
	for spread: float in [0.25, 0.5]:
		print("--- spread %.2f" % spread)
		for band in 4:
			_band(band, spread)
	quit()

func _band(band: int, spread: float) -> void:
	var rng := RandomNumberGenerator.new()
	var me := RandomNumberGenerator.new()
	me.seed = 3
	var totals := []
	var stars := [0, 0, 0, 0]
	var runs := []
	var likes := 0
	var notes := 0
	var rounds := 0
	var said := []
	for day in 40:
		rng.seed = 9000 + day
		var st = State.new()
		st.setup(rng, band)
		for r in st.round_count():
			var g: float = st.truth() * exp(me.randfn(0.0, spread))
			var res: Dictionary = st.lock(g)
			rounds += 1
			var n: Dictionary = Board.note_line(st.tgt(), st.ref(), g)
			if n.text != "":
				notes += 1
			if not State.like(st.tgt(), g).is_empty():
				likes += 1
			if said.size() < 4 and n.text != "" and day % 7 == 0:
				said.append("%s (%d)" % [n.text, int(res.score)])
			if not st.advance():
				break
		totals.append(st.total() * 100 / maxi(1, st.best_total()))
		stars[st.stars()] += 1
		runs.append(st.best_run)
	totals.sort()
	runs.sort()
	print("band %d: points p50 %d%%, stars 0/1/2/3 %s, best run p50 %d, notes %d/%d, like %d; %s" % [
		band, totals[totals.size() / 2], str(stars), runs[runs.size() / 2], notes, rounds, likes, " | ".join(said)])
