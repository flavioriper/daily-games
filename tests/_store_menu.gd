extends "res://ui/menu.gd"

## The store shots' first screen (tests/_store_shots.gd): the registry with
## the pairs in SWAPS traded places, the user's pick of 2026-11-05 for page
## one. Each card keeps its own registry colour.
const SWAPS := [["picket", "binairo"], ["market", "untangle"], ["pie", "nonogram"],
	["quilt", "wordtrail"], ["rings", "caterpillar"], ["pie", "fairylights"]]

func _order() -> Array:
	var out: Array = Registry.PUZZLES.duplicate()
	var ids: Array = out.map(func(e): return e.id)
	for s in SWAPS:
		var a := ids.find(s[0])
		var b := ids.find(s[1])
		var t = out[a]
		out[a] = out[b]
		out[b] = t
		ids[a] = s[1]
		ids[b] = s[0]
	return out

func _page_entries(page := _page, deck := _deck, per := _per_page) -> Array:
	var src := _order()
	var out: Array = []
	for i in range(page * per, mini(page * per + per, src.size())):
		out.append({"i": Registry.PUZZLES.find(src[i]), "entry": src[i]})
	return out
