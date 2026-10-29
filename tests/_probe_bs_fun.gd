extends SceneTree

## Birdsong, measured (2026-10-29 made-fun pass): a tapper who remembers the
## rhythm but whose timing drifts like a person's without a beat to lean on
## (error grows with the time since their first knock), and one who hears a
## guide beat (error stays flat). Reports per band: slips a round, which
## knocks slip (late in the bar, quick ones), and the share of knocks good.

const State = preload("res://puzzles/birdsong_state.gd")

func _initialize() -> void:
	for guide in [false, true]:
		for band in 4:
			var rng := RandomNumberGenerator.new()
			var noise := RandomNumberGenerator.new()
			noise.seed = 7
			var rounds := 0
			var slips := 0
			var goods := 0
			var oks := 0
			var late_slips := 0
			var early_slips := 0
			var quick_slips := 0
			var clean_days := 0
			var forgot := 0
			var whys := [0, 0, 0, 0]
			for day in 60:
				rng.seed = 1000 + day
				var st = State.new()
				st.deal(rng, band)
				var guard := 0
				var day_slips := 0
				while not st.solved() and guard < 200:
					guard += 1
					rounds += 1
					st.begin_turn()
					var t0 := 10.0
					var drift := noise.randfn(0.0, 0.05) if not guide else noise.randfn(0.0, 0.015)
					var slipped := false
					var ks: Array[int] = st.knocks.duplicate()
					# a person forgets one knock now and then, more in a longer bar
					var forget := -1
					if noise.randf() < 0.04 * (ks.size() - 1):
						forget = noise.randi_range(1, ks.size() - 1)
					for i in ks.size():
						var ideal := t0 + ks[i] * st.slot_time()
						var el := ideal - t0
						var sd := 0.035 + (0.0 if guide else 0.03 * el)
						var t := ideal + el * drift + (noise.randfn(0.0, sd) if i > 0 else 0.0)
						if forget == i:
							continue
						var missed: int = st.missed(t)
						if missed >= 0:
							slipped = true
							if forget >= 0 and forget < i: forgot += 1
							else: late_slips += 1
							break
						var h = st.heard(t)
						if h == State.Heard.SLIP:
							slipped = true
							if forget >= 0 and forget < i:
								forgot += 1
								break
							if t > ideal: late_slips += 1
							else: early_slips += 1
							if st.grid() == 16 and ks[i] % 2 == 1: quick_slips += 1
							break
						if st.last_grade == 0: goods += 1
						else: oks += 1
						if h == State.Heard.ROUND or h == State.Heard.SOLVED:
							break
					if not slipped and forget >= 0:
						# left the last knock out: its place passes
						slipped = true
						forgot += 1
						st.missed(INF)
					if slipped:
						whys[st.why] += 1
						slips += 1
						day_slips += 1
				if day_slips == 0: clean_days += 1
			print("guide=%s band %d: %.2f slips/round, good %d%% of knocks, slips late %d early %d quick %d, clean days %d/60, memory slips %d, why early/late/extra/missed %s" % [
				guide, band, float(slips) / rounds, 100 * goods / maxi(1, goods + oks), late_slips, early_slips, quick_slips, clean_days, forgot, str(whys)])
	quit()
