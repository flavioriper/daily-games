extends SceneTree
## Throwaway: Four Shelves' and Five Clues' bank picks for a few days, to
## diff against server/functions (bankDay in shelves.ts and clues.ts).
const SH = preload("res://puzzles/shelves_state.gd")
const CL = preload("res://puzzles/clues_state.gd")
func _initialize() -> void:
	for k in [20261022, 20261023, 20261101, 20270315]:
		var s := PackedStringArray()
		for b in 4:
			var t: Array = SH.tiers()[b]
			s.append(SH.bank_pick(t, k).id if not t.is_empty() else "-")
		print("shelves %d %s" % [k, ",".join(s)])
		var c := PackedStringArray()
		for b in 4:
			var ids := PackedStringArray()
			for r in CL.bank_band(k, b):
				ids.append(r.id)
			c.append("+".join(ids))
		print("clues %d %s" % [k, ",".join(c)])
	quit()
