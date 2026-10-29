extends SceneTree

## Throwaway: on proofs missing one member, at the first snap, does the joint
## moved furthest (the hinge) or the snapped member's lower end sit on an end
## of the member that was taken out?

const Sim = preload("res://puzzles/trestle_sim.gd")
const Gen = preload("res://puzzles/trestle_gen.gd")
const State = preload("res://puzzles/trestle_state.gd")

func _initialize() -> void:
	var bands := Gen.bank()
	for band in 3:
		var n := 0
		var hinge_hit := 0
		var end_hit := 0
		var near_hit := 0
		for lv in bands[band]:
			var st := State.new()
			st.setup(lv)
			var proof := []
			for d in st.proof: proof.append({"a": d.a, "b": d.b, "m": d.m})
			for i in proof.size():
				var gone: Dictionary = proof[i]
				var d := proof.duplicate()
				d.remove_at(i)
				var s := Sim.new()
				s.setup(st.level, d)
				while not s.done() and s.t < Sim.TIME_OUT and s.broken.is_empty():
					s.step()
				if s.broken.is_empty():
					continue
				n += 1
				var pts := {}
				for m in d:
					pts[m.a] = true; pts[m.b] = true
				var best := Vector2i(-99, -99)
				var bd := -1.0
				for p in pts.keys():
					var j := s.joint_at(p)
					if j < 0 or s.jfix[j] == 1: continue
					var dd := s.jp[j].distance_to(Vector2(p))
					if dd > bd:
						bd = dd; best = p
				if best == gone.a or best == gone.b: hinge_hit += 1
				var sm: Dictionary = d[s.broken[0]]
				var ja := s.joint_at(sm.a)
				var jb := s.joint_at(sm.b)
				var da := s.jp[ja].distance_to(Vector2(sm.a)) if ja >= 0 and s.jfix[ja] == 0 else -1.0
				var db := s.jp[jb].distance_to(Vector2(sm.b)) if jb >= 0 and s.jfix[jb] == 0 else -1.0
				var e: Vector2i = sm.a if da >= db else sm.b
				if e == gone.a or e == gone.b: end_hit += 1
				if Vector2(best).distance_to(Vector2(gone.a + gone.b) * 0.5) <= 1.6: near_hit += 1
		print("band %d: fails %d; hinge on the missing member %d; snapped member's moving end %d; hinge within 1.6 of its middle %d" % [band, n, hinge_hit, end_hit, near_hit])
	quit()
