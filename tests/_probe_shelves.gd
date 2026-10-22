extends SceneTree
## Throwaway: Four Shelves' bank. Every puzzle valid for its band, the pick
## for a few days (to compare with server/functions bankPick), and the rules
## played to a solve, a close guess, a wrong one and a repeat.
const S = preload("res://puzzles/shelves_state.gd")
func _initialize() -> void:
	var tiers := S.tiers()
	for b in tiers.size():
		print("band %d: %d puzzles" % [b, (tiers[b] as Array).size()])
		for key in [20261022, 20261023, 20261101]:
			print("  %d -> %s" % [key, S.bank_pick(tiers[b], key).id])
	var st = S.new()
	st.setup(20261022, 1)
	var g0: Array = st.groups[0].words
	var g1: Array = st.groups[1].words
	for w in [g0[0], g0[1], g0[2], g1[0]]:
		st.toggle(w)
	print("close: ", st.submit() == S.Said.CLOSE, " hearts ", st.hearts)
	for w in [g0[0], g0[1], g0[2], g1[0]]:
		st.toggle(w)
	print("repeat: ", st.submit() == S.Said.REPEAT, " hearts ", st.hearts)
	st.clear_picks()
	for g in st.count():
		for w in st.groups[g].words:
			st.toggle(w)
		var said = st.submit()
		print("shelf %d: %d" % [g, said])
	print("solved ", st.solved(), " mistakes ", st.mistakes, " q ", st.quality(), "\n", st.share_glyphs())
	quit()
