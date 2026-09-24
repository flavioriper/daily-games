class_name PlayerStats
extends RefCounted

## Stats' figures, derived from Progress.solve_log() and never stored
## (docs/superpowers/specs/2026-09-24-stats-streak-design.md, section 3).

static func summary(log: Dictionary) -> Dictionary:
	var solved := 0
	var days := 0
	for k in log:
		var n := (log[k] as Array).size()
		solved += n
		if n > 0:
			days += 1
	return {"solved": solved, "days": days}

## Per board at one difficulty: how many, the best time and the mean. A
## record with no time (t <= 0, from an old save) counts but is not timed.
static func boards(log: Dictionary, difficulty: int) -> Dictionary:
	var out := {}
	for k in log:
		for r in log[k]:
			if int(r.get("d", -1)) != difficulty:
				continue
			var id := String(r.get("id", ""))
			var row: Dictionary = out.get_or_add(id, {"count": 0, "best": 0.0, "mean": 0.0, "_sum": 0.0, "_timed": 0})
			row.count += 1
			var t := float(r.get("t", 0.0))
			if t > 0.0:
				row.best = t if row._timed == 0 else minf(row.best, t)
				row._sum += t
				row._timed += 1
	for id in out:
		var row: Dictionary = out[id]
		row.mean = row._sum / row._timed if row._timed > 0 else 0.0
		row.erase("_sum")
		row.erase("_timed")
	return out
