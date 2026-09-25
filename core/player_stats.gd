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

## The last `n` days ending on `today`, oldest first: whether each was played,
## and how many boards were solved across them (the Solved tile's "this week"
## and the Days tile's dots).
static func recent(log: Dictionary, today: int, n := 7) -> Dictionary:
	var unix := int(Time.get_unix_time_from_datetime_dict({
		"year": today / 10000, "month": (today / 100) % 100, "day": today % 100,
		"hour": 12, "minute": 0, "second": 0}))
	var played: Array[bool] = []
	var solved := 0
	for i in range(n - 1, -1, -1):
		var d := Time.get_date_dict_from_unix_time(unix - i * 86400)
		var key := int(d.year) * 10000 + int(d.month) * 100 + int(d.day)
		var count := (log.get(key, []) as Array).size()
		played.append(count > 0)
		solved += count
	return {"played": played, "solved": solved}
