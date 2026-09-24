class_name Streak
extends RefCounted

## The streak, derived and never stored
## (docs/superpowers/specs/2026-09-24-stats-streak-design.md, section 1).
## Three distinct boards keep a day; every seventh kept day in a row earns a
## rest day, held two at most; a day that ends unkept spends one, or breaks
## the run. Today is pending until it is kept, never missed.

const KEPT := 3
const EARN := 7
const REST_CAP := 2

## The date key after `key`, stepped through Time so month and year ends and
## leap days come out right. Keys are Daily.date_key() values (UTC).
static func next_day(key: int) -> int:
	var unix := Time.get_unix_time_from_datetime_dict({
		"year": key / 10000, "month": (key / 100) % 100, "day": key % 100,
		"hour": 12, "minute": 0, "second": 0})
	var d := Time.get_date_dict_from_unix_time(int(unix) + 86400)
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)

## Distinct boards in one day's records, capped at KEPT.
static func hearts(records: Array) -> int:
	var ids := {}
	for r in records:
		ids[String(r.get("id", ""))] = true
	return mini(ids.size(), KEPT)

static func compute(log: Dictionary, today: int) -> Dictionary:
	var out := {"current": 0, "best": 0, "rest": 0, "toward": 0, "days": {}, "first": 0}
	var first := 0
	for k in log:
		if (log[k] as Array).size() > 0 and (first == 0 or int(k) < first):
			first = int(k)
	if first == 0 or first > today:
		return out
	out.first = first
	var cur := 0
	var best := 0
	var rest := 0
	var toward := 0
	var d := first
	var guard := 0
	while d <= today and guard < 40000:
		guard += 1
		var n := hearts(log.get(d, []))
		if n >= KEPT:
			cur += 1
			toward += 1
			if toward == EARN:
				toward = 0
				rest = mini(REST_CAP, rest + 1)
			best = maxi(best, cur)
			out.days[d] = "kept"
		elif d == today:
			out.days[d] = "today"
		elif rest > 0:
			rest -= 1
			out.days[d] = "rest"
		else:
			cur = 0
			toward = 0
			out.days[d] = "partial" if n > 0 else "missed"
		d = next_day(d)
	out.current = cur
	out.best = best
	out.rest = rest
	out.toward = toward
	return out
