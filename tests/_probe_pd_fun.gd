extends SceneTree

## Pearl Dive made fun (2026-10-29), headless: over every bank prompt, how
## the judge takes what a hand types. Plurals and "X bridge"-style lines that
## the list lacks but hold a listed form whole now count (`whole`); two slips
## are "so close" and free (`close`); a line nothing like any form is still
## a miss. Prints the counts; fails on a line that counts as an answer of
## another prompt's thing (a whole match that lands on a different answer
## than the form it was made from).
##   godot --headless --script res://tests/_probe_pd_fun.gd

const S = preload("res://puzzles/pearl_state.gd")

func _initialize() -> void:
	var whole := 0
	var whole_wrong := 0
	var close := 0
	var tried := 0
	for lv: Array in S.levels():
		for p: Dictionary in lv:
			var st = S.new()
			st.setup_fixed(0, [p])
			for a in (p.answers as Array).size():
				var form := S.norm(str(p.answers[a].en[0]))
				if form.length() < 4:
					continue
				tried += 1
				# a plural the writer did not list
				var got: int = st.find(form + "s")
				if got >= 0:
					whole += 1
					if int(p.answers[got].t) != int(p.answers[a].t) and got != a:
						whole_wrong += 1
				# two slips: letters 1 and 3 swapped for a z
				if form.length() >= S.CLOSE_FROM:
					var bad := form.substr(0, 1) + "z" + form.substr(2, 1) + "z" + form.substr(4)
					if st.find(bad) < 0 and st.close(bad):
						close += 1
	print("forms %d: plural counted %d (on another tier %d); two-slip lines said close %d" % [tried, whole, whole_wrong, close])
	quit()
