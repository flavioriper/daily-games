# Stats and Streak Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the bottom bar's Stats and Streak tabs real, make the day row's
hearts and the header's calendar badge count, and log every solve so both can
be derived.

**Architecture:** An append-only solve log in `core/progress.gd` is the only
new stored state. `core/streak.gd` and `core/player_stats.gd` are pure static
derivations over it. Two new tab bodies (`ui/menu/streak_tab.gd`,
`ui/menu/stats_tab.gd`) replace the day row and the grid in the menu's
column when their tab is picked. `ui/flat/flat_host.gd` logs the solve and
puts the hearts line on the win screen.

**Tech Stack:** Godot 4.7 GDScript, gl_compatibility, ConfigFile persistence,
`locale/ui.csv` translations.

**Spec:** `docs/superpowers/specs/2026-09-24-stats-streak-design.md` (the
concept is `docs/brainstorm/concepts.html#progress`). Read both.

## Global Constraints

- Three distinct boards solved on a `Daily.date_key()` (UTC) day keep it;
  seven kept days in a row earn a rest day; hold at most 2; an unkept day
  spends one automatically.
- Nothing about the streak is stored; it is derived from the log every time.
- A replay never logs twice: one record per (date, id, difficulty).
  `clear_completed` never touches the log.
- **No new test files** (the project's MVP rule): verification is throwaway
  probes kept in the session's scratchpad, never committed, plus the existing
  suite (`godot --headless --path . --script tests/run_tests.gd`, which must
  end `failed=0`).
- `--resolution 810x1440` goes **before** `--script` on any windowed harness.
  Never overlap two windowed harness runs.
- A static Label holds its locale key and auto-translates; anything drawn or
  formatted goes through `tr()`. Board titles stay English.
- gl_compatibility pays per draw command: draw tab contents in one `_draw`
  per card rather than as a node per figure. Budget 855 draw calls.
- Before a harness, `godot --headless --check-only --script <file>` every
  changed `.gd`.
- Commit after each task on `feat/stats-streak`. Never push.

## Review Focus

1. **A fresh install** (no `progress.cfg`): Streak shows 0, no badge, empty
   calendar on today's month, Stats all dashes; nothing errors. Pinned by
   Task 1's probe case "empty".
2. **An old save** with `completed` keys from before the log: migration once,
   no duplicates when the menu's plain-id mark sits beside the suffixed one.
   Pinned by Task 1's migration probe.
3. **Replaying a solved daily and solving again** must not add a heart or a
   stats record. Pinned by Task 1's probe case "replay".
4. **Month and year boundaries** in the walk and the calendar (Sept 30 to Oct
   1, Dec 31 to Jan 1, Feb 29). Pinned by Task 1's `next_day` cases.
5. **Swiping on Stats or Streak** must not turn the hidden grid's page, and
   returning Home must re-fit the grid. Pinned by Task 5's manual check.

---

### Task 1: The solve log and the derivations

**Files:**
- Modify: `core/progress.gd` (append after `clear_completed`)
- Create: `core/streak.gd`
- Create: `core/player_stats.gd`
- Probe (scratchpad, not committed): `$SCRATCH/probe_streak.gd`

**Interfaces:**
- Produces:
  - `Progress.log_solve(id: String, difficulty: int, stats: Dictionary = {}, date_key: int = Daily.date_key()) -> bool` (true when a record was added)
  - `Progress.solve_log() -> Dictionary` of `int date_key -> Array[Dictionary{id, d, t, m, h}]`
  - `Progress.hearts(date_key: int = Daily.date_key()) -> int` (0-3)
  - `Progress.stats_difficulty() -> int` and `Progress.set_stats_difficulty(d: int) -> void`
  - `Streak.KEPT` (3), `Streak.EARN` (7), `Streak.REST_CAP` (2)
  - `Streak.next_day(key: int) -> int`, `Streak.hearts(records: Array) -> int`
  - `Streak.compute(log: Dictionary, today: int) -> Dictionary` with `current`, `best`, `rest`, `toward`, `days` (`int -> "kept"|"rest"|"partial"|"missed"|"today"`), `first` (int, 0 when empty)
  - `PlayerStats.summary(log: Dictionary) -> Dictionary{solved: int, days: int}`
  - `PlayerStats.boards(log: Dictionary, difficulty: int) -> Dictionary` of `id -> {count: int, best: float, mean: float}`

- [ ] **Step 1: Write `core/streak.gd`**

```gdscript
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
```

- [ ] **Step 2: Write `core/player_stats.gd`**

```gdscript
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
```

- [ ] **Step 3: Append the log to `core/progress.gd`**

Add after `clear_completed`:

```gdscript
## --- the solve log (docs/superpowers/specs/2026-09-24-stats-streak-design.md, section 2) ---
## One record per board and difficulty per day, appended on a solve and never
## erased: clear_completed (the replay button) does not touch it, so a replay
## solved again cannot count twice or inflate a best time. Streak and Stats
## are derived from it (core/streak.gd, core/player_stats.gd).

static func log_solve(id: String, difficulty: int, stats: Dictionary = {}, date_key: int = Daily.date_key()) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(path)
	_migrate(cfg)
	var key := str(date_key)
	var day: Array = cfg.get_value("log", key, [])
	if _has_record(day, id, difficulty):
		return false
	day.append({
		"id": id, "d": difficulty,
		"t": float(stats.get("seconds", 0.0)),
		"m": int(stats.get("moves", 0)),
		"h": int(stats.get("hints", 0)),
	})
	cfg.set_value("log", key, day)
	cfg.save(path)
	return true

## Every day's records, keyed by the int date key.
static func solve_log() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(path)
	_migrate(cfg)
	var out := {}
	if cfg.has_section("log"):
		for key in cfg.get_section_keys("log"):
			var day = cfg.get_value("log", key, [])
			if key.is_valid_int() and day is Array:
				out[int(key)] = day
	return out

## Today's hearts: distinct boards solved, up to three.
static func hearts(date_key: int = Daily.date_key()) -> int:
	return Streak.hearts(solve_log().get(date_key, []))

## Which difficulty Stats shows, remembered between visits.
static func stats_difficulty() -> int:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return clampi(int(cfg.get_value("stats", "difficulty", 0)), 0, 3)

static func set_stats_difficulty(d: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("stats", "difficulty", clampi(d, 0, 3))
	cfg.save(path)

static func _has_record(day: Array, id: String, difficulty: int) -> bool:
	for r in day:
		if String(r.get("id", "")) == id and int(r.get("d", -1)) == difficulty:
			return true
	return false

## Folds the completions saved before the log existed into it, once. A key
## is `<date>_<progress_id>`; a progress_id ending `_<digit>` carries its
## difficulty. The menu also marks the plain id, so a plain record is dropped
## when a suffixed one for the same board and day exists. Saves only when it
## ran.
static func _migrate(cfg: ConfigFile) -> void:
	if bool(cfg.get_value("log_meta", "migrated", false)):
		return
	var by_date := {}
	if cfg.has_section("completed"):
		for k in cfg.get_section_keys("completed"):
			var cut := k.find("_")
			if cut <= 0 or not k.substr(0, cut).is_valid_int():
				continue
			var date := k.substr(0, cut)
			var id := k.substr(cut + 1)
			var d := -1
			var tail := id.rfind("_")
			if tail > 0 and id.length() - tail == 2 and id.substr(tail + 1).is_valid_int():
				d = int(id.substr(tail + 1))
				id = id.substr(0, tail)
			var st = cfg.get_value("completed_stats", k, {})
			if not st is Dictionary:
				st = {}
			(by_date.get_or_add(date, []) as Array).append({
				"id": id, "d": d,
				"t": float(st.get("seconds", 0.0)),
				"m": int(st.get("moves", 0)),
				"h": int(st.get("hints", 0)),
			})
	for date in by_date:
		var found: Array = by_date[date]
		var day: Array = cfg.get_value("log", date, [])
		for r in found:
			if int(r.d) == -1 and _has_suffixed(found, String(r.id)):
				continue
			if not _has_record(day, String(r.id), int(r.d)):
				day.append(r)
		if not day.is_empty():
			cfg.set_value("log", date, day)
	cfg.set_value("log_meta", "migrated", true)
	cfg.save(path)

static func _has_suffixed(records: Array, id: String) -> bool:
	for r in records:
		if String(r.id) == id and int(r.d) >= 0:
			return true
	return false
```

`Streak` is referenced by `class_name`; `Daily` already is.

- [ ] **Step 4: Parse-check**

Run: `for f in core/streak.gd core/player_stats.gd core/progress.gd; do godot --headless --check-only --script $f || echo FAIL $f; done`
Expected: no `FAIL`. (A `class_name` added mid-session may need `godot --headless --path . --import` first so the global class cache knows it.)

- [ ] **Step 5: Write the throwaway probe** at `$SCRATCH/probe_streak.gd`
  (`$SCRATCH` is the session's scratchpad directory; the file is never
  committed)

```gdscript
extends SceneTree
# Throwaway: Streak.compute, next_day, PlayerStats and the log's migration.
const Streak = preload("res://core/streak.gd")
const PlayerStats = preload("res://core/player_stats.gd")
const Progress = preload("res://core/progress.gd")
var _ran := false
var fails := 0

func check(what: String, got, want) -> void:
	if got != want:
		fails += 1
		print("FAIL %s: got %s want %s" % [what, got, want])

func days_from(start: int, counts: Array) -> Dictionary:
	# counts[i] boards solved on the i-th day after start; -1 = no entry
	var log := {}
	var d := start
	for n in counts:
		if n >= 0:
			var recs := []
			for b in n:
				recs.append({"id": "b%d" % b, "d": 0, "t": 60.0 + b, "m": 1, "h": 0})
			log[d] = recs
		d = Streak.next_day(d)
	return log

func last_key(start: int, n: int) -> int:
	var d := start
	for i in n - 1:
		d = Streak.next_day(d)
	return d

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	check("next month", Streak.next_day(20260930), 20261001)
	check("next year", Streak.next_day(20261231), 20270101)
	check("leap", Streak.next_day(20280228), 20280229)
	check("empty", Streak.compute({}, 20260924).current, 0)
	# seven kept, today pending
	var s := Streak.compute(days_from(20260901, [3,3,3,3,3,3,3,0]), last_key(20260901, 8))
	check("7 cur", s.current, 7); check("7 rest", s.rest, 1); check("7 toward", s.toward, 0)
	check("today pending", s.days[last_key(20260901, 8)], "today")
	# seven kept, a partial miss covered, two kept
	s = Streak.compute(days_from(20260901, [3,3,3,3,3,3,3,2,3,3]), last_key(20260901, 10))
	check("covered cur", s.current, 9); check("covered rest", s.rest, 0)
	check("covered day", s.days[last_key(20260901, 8)], "rest")
	# three kept, a gap with no entry, two kept
	s = Streak.compute(days_from(20260901, [3,3,3,-1,3,3]), last_key(20260901, 6))
	check("broken cur", s.current, 2); check("broken best", s.best, 3)
	check("missed day", s.days[last_key(20260901, 4)], "missed")
	# cap: 28 kept -> rest stays 2
	var many := []
	for i in 28:
		many.append(3)
	s = Streak.compute(days_from(20260801, many), last_key(20260801, 28))
	check("cap", s.rest, 2); check("cap cur", s.current, 28)
	# today kept joins
	s = Streak.compute(days_from(20260901, [3,3,3]), last_key(20260901, 3))
	check("today kept", s.current, 3)
	# replay: same board thrice is one heart
	check("distinct", Streak.hearts([{"id": "a"}, {"id": "a"}, {"id": "a"}]), 1)
	# stats
	var st := PlayerStats.boards({20260901: [{"id": "q", "d": 1, "t": 90.0}], 20260902: [{"id": "q", "d": 1, "t": 30.0}]}, 1)
	check("stats count", st.q.count, 2); check("stats best", st.q.best, 30.0); check("stats mean", st.q.mean, 60.0)
	# migration and replay dedupe on a scratch file
	var p := OS.get_environment("PROBE_CFG")
	Progress.path = p
	var cfg := ConfigFile.new()
	cfg.set_value("completed", "20260923_queens_1", true)
	cfg.set_value("completed", "20260923_queens", true)
	cfg.set_value("completed", "20260923_oldboard", true)
	cfg.set_value("completed_stats", "20260923_queens_1", {"seconds": 83.0, "moves": 41, "hints": 0})
	cfg.save(p)
	var log := Progress.solve_log()
	check("migrated n", (log[20260923] as Array).size(), 2)
	check("migrated t", log[20260923][0].t if log[20260923][0].id == "queens" else log[20260923][1].t, 83.0)
	check("log once", Progress.log_solve("tents", 0, {"seconds": 10.0}, 20260924), true)
	check("replay", Progress.log_solve("tents", 0, {"seconds": 5.0}, 20260924), false)
	check("hearts", Progress.hearts(20260924), 1)
	check("rerun migration", (Progress.solve_log()[20260923] as Array).size(), 2)
	print("probe fails=%d" % fails)
	quit(fails)
	return true
```

- [ ] **Step 6: Run the probe**

Run: `PROBE_CFG=$SCRATCH/probe_progress.cfg; rm -f $PROBE_CFG; PROBE_CFG=$PROBE_CFG godot --headless --path . --script $SCRATCH/probe_streak.gd`
Expected: `probe fails=0`. Fix the code, not the probe, on any FAIL unless the
probe contradicts the spec.

- [ ] **Step 7: Suite and commit**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | grep passed=`
Expected: `failed=0`.

```bash
git add core/streak.gd core/streak.gd.uid core/player_stats.gd core/player_stats.gd.uid core/progress.gd
git commit -m "feat(progress): a solve log, and the streak and stats derived from it"
```
(Add the `.uid` files only if Godot generated them.)

---

### Task 2: Solves reach the log, and the win screen says so

**Files:**
- Modify: `ui/flat/flat_host.gd` (`_on_solved` near line 395, `_show_win` near line 416)
- Modify: `locale/ui.csv` (append rows)

**Interfaces:**
- Consumes: `Progress.log_solve`, `Progress.hearts`, `Progress.solve_log`, `Streak.compute`
- Produces: nothing for later tasks.

- [ ] **Step 1: Locale rows** (append to `locale/ui.csv`, header is `keys,en,pt,es`)

```
WIN_HEARTS,%d of 3 today,%d de 3 hoje,%d de 3 hoy
WIN_DAY_KEPT,Day kept · streak %d,Dia garantido · sequência %d,Día conseguido · racha %d
WIN_STREAK,Streak %d,Sequência %d,Racha %d
```

- [ ] **Step 2: Log and build the line in `_on_solved`**

Add `const Streak = preload("res://core/streak.gd")` beside the other
preloads, and `var _hearts_line := ""` beside the other vars. In `_on_solved`,
after `Progress.mark_completed(...)` and before `daily_completed.emit`:

```gdscript
	var today := DailySeed.date_key()
	var before := Progress.hearts(today)
	Progress.log_solve(puzzle_id, _difficulty, kept, today)
	var after := Progress.hearts(today)
	var streak := int(Streak.compute(Progress.solve_log(), today).current)
	if after < Streak.KEPT:
		_hearts_line = tr("WIN_HEARTS") % after
	elif before < Streak.KEPT:
		_hearts_line = tr("WIN_DAY_KEPT") % streak
	else:
		_hearts_line = tr("WIN_STREAK") % streak
```

Replace `Analytics.track("puzzle_complete", _stats())` with:

```gdscript
	var event := _stats()
	event["hearts"] = after
	event["streak"] = streak
	Analytics.track("puzzle_complete", event)
```

- [ ] **Step 3: Show it** — in `_show_win`, replace
`stats_card.set_day(Progress.day(), Progress.island_name())` with:

```gdscript
	# After a live solve the island's name gives way to today's hearts; a
	# reopened finished daily has no line and keeps the name.
	stats_card.set_day(Progress.day(),
		_hearts_line if _hearts_line != "" else Progress.island_name())
```

and in `_on_redo`, set `_hearts_line = ""` before `_spawn`.

- [ ] **Step 4: Check**

Run: `godot --headless --path . --import >/dev/null 2>&1; godot --headless --check-only --script ui/flat/flat_host.gd && godot --headless --path . --script tests/run_tests.gd 2>&1 | grep passed=`
Expected: parses; `failed=0`. Then `godot --path . --resolution 810x1440 --script res://tests/_win.gd -- sudoku`
(windowed) prints a solve, and `user://progress.cfg` (`~/Library/Application Support/Godot/app_userdata/Daily/progress.cfg`)
now has a `[log]` section holding a sudoku record. If `_win.gd` does not take
a board argument, read its header and run it the way it documents.

- [ ] **Step 5: Commit**

```bash
git add ui/flat/flat_host.gd locale/ui.csv
git commit -m "feat(win): log the solve, and the day card says how today stands"
```

---

### Task 3: The Streak tab

**Files:**
- Create: `ui/menu/ink.gd` (shared text drawing)
- Create: `ui/menu/streak_tab.gd`
- Modify: `locale/ui.csv`

**Interfaces:**
- Consumes: `Progress.solve_log()`, `Streak.compute`, `Streak.next_day`, `Streak.KEPT`, `Streak.EARN`, `Streak.REST_CAP`
- Produces: `StreakTab` (preload path `res://ui/menu/streak_tab.gd`), a `VBoxContainer` with `refresh() -> void`. `Ink.text(ci: CanvasItem, font: Font, s: String, pos: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void` and `Ink.fit(font: Font, s: String, size: int, width: float, floor_size := 18) -> int`.

- [ ] **Step 1: Locale rows**

```
STREAK_DAYS,day streak,dias seguidos,días seguidos
STREAK_BEST,Best,Recorde,Récord
STREAK_REST,Rest days,Dias de folga,Días de descanso
STREAK_NEXT_REST,Next rest day,Próxima folga,Próximo descanso
TODAY_LINE_0,Solve three to keep the streak,Resolva três para manter a sequência,Resuelve tres para mantener la racha
TODAY_LINE_1,Two more keep the streak,Mais dois mantêm a sequência,Dos más mantienen la racha
TODAY_LINE_2,One more keeps the streak,Mais um mantém a sequência,Uno más mantiene la racha
TODAY_LINE_3,Day kept,Dia garantido,Día conseguido
WEEKDAY_INITIALS,MTWTFSS,STQQSSD,LMXJVSD
MONTH_1,January,Janeiro,Enero
MONTH_2,February,Fevereiro,Febrero
MONTH_3,March,Março,Marzo
MONTH_4,April,Abril,Abril
MONTH_5,May,Maio,Mayo
MONTH_6,June,Junho,Junio
MONTH_7,July,Julho,Julio
MONTH_8,August,Agosto,Agosto
MONTH_9,September,Setembro,Septiembre
MONTH_10,October,Outubro,Octubre
MONTH_11,November,Novembro,Noviembre
MONTH_12,December,Dezembro,Diciembre
```

- [ ] **Step 2: `ui/menu/ink.gd`**

```gdscript
extends RefCounted

## Text drawn straight onto a canvas for the Stats and Streak tabs, where a
## Label per figure would be a node per number (gl_compatibility pays per
## draw command either way, so the saving is nodes, not calls).

static func text(ci: CanvasItem, font: Font, s: String, pos: Vector2, size: int, col: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		pos.x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		pos.x -= w
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## The largest size at or under `size` at which `s` fits `width`, stepping
## down and never under `floor_size` (the top bar's _fit, in small).
static func fit(font: Font, s: String, size: int, width: float, floor_size := 18) -> int:
	while size > floor_size and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size
```

- [ ] **Step 3: `ui/menu/streak_tab.gd`**

```gdscript
extends VBoxContainer

## Streak: the current run huge, best and rest days beside it, today's three
## hearts, and a month calendar that is the history.
## Spec: docs/superpowers/specs/2026-09-24-stats-streak-design.md, section 4.
## Every figure is derived (core/streak.gd); refresh() re-reads the log.

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Icons = preload("res://ui/icons.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Progress = preload("res://core/progress.gd")
const Streak = preload("res://core/streak.gd")
const Ink = preload("res://ui/menu/ink.gd")

const GAP := 20
const STREAK_H := 330.0
const TODAY_H := 190.0
const HEART := 70.0
const HEART_STEP := 86.0
const CHEVRON := 90.0

var _log := {}
var _today := 0
var _st := {}
var _month := 0        # yyyymm on show
var _first_month := 0
var _streak_ci: Control
var _today_ci: Control
var _cal_ci: Control
var _prev: Button
var _next: Button
var _big: Font
var _head: Font
var _body: Font

func _init() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big = CozyTheme.display(700)
	_head = CozyTheme.display(700)
	_body = CozyTheme.body(800)
	_streak_ci = _card(STREAK_H, _draw_streak)
	_today_ci = _card(TODAY_H, _draw_today)
	_cal_ci = _card(0.0, _draw_calendar)
	_cal_ci.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	_prev = _chevron("chevron_left", -1)
	_prev.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_next = _chevron("chevron_right", 1)
	_next.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_next.offset_left = -CHEVRON

func _card(h: float, painter: Callable) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CozyTheme.card(Pal.SURFACE, 36, Pal.LINE, 6, 24))
	card.custom_minimum_size.y = h
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var ci := Control.new()
	ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ci.draw.connect(painter.bind(ci))
	card.add_child(ci)
	return ci

func _chevron(icon: String, step: int) -> Button:
	var b := IconButton.new(icon)
	b.custom_minimum_size = Vector2(CHEVRON, CHEVRON)
	b.size = Vector2(CHEVRON, CHEVRON)
	b.pressed.connect(func() -> void: _turn_month(step))
	_cal_ci.add_child(b)
	return b

func refresh() -> void:
	_log = Progress.solve_log()
	_today = Daily.date_key()
	_st = Streak.compute(_log, _today)
	_month = _today / 100
	_first_month = int(_st.first) / 100 if int(_st.first) > 0 else _month
	_repaint()

func _turn_month(step: int) -> void:
	var y := _month / 100
	var m := _month % 100 + step
	if m < 1:
		m = 12
		y -= 1
	elif m > 12:
		m = 1
		y += 1
	_month = clampi(y * 100 + m, _first_month, _today / 100)
	_repaint()

func _repaint() -> void:
	_prev.disabled = _month <= _first_month
	_next.disabled = _month >= _today / 100
	_prev.modulate.a = 0.35 if _prev.disabled else 1.0
	_next.modulate.a = 0.35 if _next.disabled else 1.0
	_streak_ci.queue_redraw()
	_today_ci.queue_redraw()
	_cal_ci.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _cal_ci != null:
		_repaint()

func _draw_streak(ci: Control) -> void:
	if _st.is_empty():
		return
	var w := ci.size.x
	var cur := int(_st.current)
	Ink.text(ci, _big, str(cur), Vector2(16, 190), 160, Pal.ACCENT_2 if cur > 0 else Pal.TEXT_DIM)
	Ink.text(ci, _body, tr("STREAK_DAYS"), Vector2(22, 252), 38, Pal.TEXT_DIM)
	var x := w * 0.56
	Ink.text(ci, _body, tr("STREAK_BEST"), Vector2(x, 62), 32, Pal.TEXT_DIM)
	Ink.text(ci, _head, str(int(_st.best)), Vector2(w - 8, 66), 46, Pal.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	Ink.text(ci, _body, tr("STREAK_REST"), Vector2(x, 140), 32, Pal.TEXT_DIM)
	for i in Streak.REST_CAP:
		var c := Vector2(w - 40 - (Streak.REST_CAP - 1 - i) * 70, 128)
		if i < int(_st.rest):
			ci.draw_circle(c, 30, Pal.LEAF_TILE)
			Icons.paint(ci, "leaf", Rect2(c - Vector2(22, 22), Vector2(44, 44)), Pal.LEAF_DEEP)
		else:
			ci.draw_arc(c, 27, 0, TAU, 40, Pal.LINE, 4, true)
	Ink.text(ci, _body, tr("STREAK_NEXT_REST"), Vector2(x, 222), 28, Pal.TEXT_DIM)
	var step := (w - 20 - x - 16) / float(Streak.EARN - 1)
	for i in Streak.EARN:
		var c := Vector2(x + 16 + i * step, 262)
		if i < int(_st.toward):
			ci.draw_circle(c, 17, Pal.LEAF)
		else:
			ci.draw_arc(c, 15, 0, TAU, 32, Pal.LINE, 4, true)

func _draw_today(ci: Control) -> void:
	var n := Streak.hearts(_log.get(_today, []))
	Ink.text(ci, _body, tr("MENU_TODAY"), Vector2(18, 40), 28, Pal.TEXT_DIM)
	for i in Streak.KEPT:
		var box := Rect2(Vector2(18 + i * HEART_STEP, 62), Vector2(HEART, HEART))
		if i < n:
			Icons.paint(ci, "heart", box, Pal.ACCENT_2)
		else:
			Icons.paint(ci, "heart_line", box, Pal.LINE)
	Ink.text(ci, _body, tr("TODAY_LINE_%d" % n), Vector2(18 + 3 * HEART_STEP + 24, 110), 34, Pal.TEXT)

func _draw_calendar(ci: Control) -> void:
	if _month == 0:
		return
	var w := ci.size.x
	var h := ci.size.y
	var y := _month / 100
	var m := _month % 100
	Ink.text(ci, _head, "%s %d" % [tr("MONTH_%d" % m), y], Vector2(w * 0.5, 62), 46, Pal.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	var initials := tr("WEEKDAY_INITIALS")
	var cw := w / 7.0
	for i in 7:
		Ink.text(ci, _body, initials.substr(i, 1), Vector2(cw * (i + 0.5), 136), 28, Pal.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_CENTER)
	# Monday-first column of the 1st: Godot's weekday is 0 = Sunday.
	var first := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_datetime_dict(
		{"year": y, "month": m, "day": 1, "hour": 12})))
	var lead := (int(first.weekday) + 6) % 7
	var row_h := minf(112.0, (h - 170.0) / 6.0)
	var r := row_h * 0.36
	var key := y * 10000 + m * 100 + 1
	var cell := lead
	while key / 100 == _month:
		var c := Vector2(cw * (cell % 7 + 0.5), 170 + row_h * (cell / 7 + 0.5))
		var status := String(_st.days.get(key, ""))
		var day := str(key % 100)
		match status:
			"kept":
				ci.draw_circle(c, r, Pal.ACCENT_2)
				Ink.text(ci, _head, day, c + Vector2(0, 11), 32, Pal.SURFACE, HORIZONTAL_ALIGNMENT_CENTER)
			"rest":
				ci.draw_circle(c, r, Pal.LEAF_TILE)
				Icons.paint(ci, "leaf", Rect2(c - Vector2(r, r) * 0.7, Vector2(r, r) * 1.4), Pal.LEAF_DEEP)
			"partial":
				ci.draw_arc(c, r - 3, 0, TAU, 40, Pal.ACCENT_2, 5, true)
				var n := Streak.hearts(_log.get(key, []))
				Ink.text(ci, _head, "%d/3" % n, c + Vector2(0, 9), 26, Pal.ACCENT_2, HORIZONTAL_ALIGNMENT_CENTER)
			_:
				var col := Pal.TEXT_DIM
				if key > _today:
					col.a = 0.35
				Ink.text(ci, _head, day, c + Vector2(0, 11), 32, col, HORIZONTAL_ALIGNMENT_CENTER)
		if key == _today:
			ci.draw_arc(c, r + 8, 0, TAU, 48, Pal.TEXT, 5, true)
		key = Streak.next_day(key)
		cell += 1
```

- [ ] **Step 4: Parse-check**

Run: `godot --headless --path . --import >/dev/null 2>&1; godot --headless --check-only --script ui/menu/streak_tab.gd && godot --headless --check-only --script ui/menu/ink.gd`
Expected: no errors. (Its on-screen check happens in Task 5, once the menu
can show it.)

- [ ] **Step 5: Commit**

```bash
git add ui/menu/ink.gd ui/menu/streak_tab.gd locale/ui.csv
git add ui/menu/*.uid 2>/dev/null
git commit -m "feat(menu): the Streak tab"
```

---

### Task 4: The Stats tab

**Files:**
- Create: `ui/menu/stats_tab.gd`
- Modify: `locale/ui.csv`

**Interfaces:**
- Consumes: `Progress.solve_log()`, `Progress.stats_difficulty()`, `Progress.set_stats_difficulty(d)`, `Daily.date_key()`, `Streak.compute`, `PlayerStats.summary`, `PlayerStats.boards`, `Ink.text`, `Ink.fit`, `Registry.PUZZLES` (`res://ui/registry.gd`, each entry has `id` and `title`)
- Produces: `StatsTab` (preload path `res://ui/menu/stats_tab.gd`), a `VBoxContainer` with `refresh() -> void`.

- [ ] **Step 1: Locale rows**

```
STATS_SOLVED,Solved,Resolvidos,Resueltos
STATS_DAYS,Days played,Dias jogados,Días jugados
STATS_BEST_STREAK,Best streak,Melhor sequência,Mejor racha
STATS_COUNT,%d solved,%d resolvidos,%d resueltos
```

- [ ] **Step 2: `ui/menu/stats_tab.gd`**

```gdscript
extends VBoxContainer

## Stats: three totals, a difficulty strip, and every board's count, best and
## average time at that difficulty, four across with no scroll (20 boards
## fit at 1080x1920; a 21st makes a sixth row out of the tile height).
## Spec: docs/superpowers/specs/2026-09-24-stats-streak-design.md, section 4.

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Progress = preload("res://core/progress.gd")
const Streak = preload("res://core/streak.gd")
const PlayerStats = preload("res://core/player_stats.gd")
const Registry = preload("res://ui/registry.gd")
const Ink = preload("res://ui/menu/ink.gd")

const GAP := 20
const TILE_H := 190.0
const CHIP_H := 96.0
const COLS := 4
const CELL_GAP := 16.0
const DIFFS := ["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD", "DIFF_INSANE"]
const UNSOLVED_ALPHA := 0.6

var _log := {}
var _summary := {}
var _best := 0
var _boards := {}
var _diff := 0
var _tiles_ci: Control
var _grid_ci: Control
var _chips: Array[Button] = []
var _big: Font
var _head: Font
var _body: Font

func _init() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big = CozyTheme.display(700)
	_head = CozyTheme.display(700)
	_body = CozyTheme.body(800)
	_tiles_ci = Control.new()
	_tiles_ci.custom_minimum_size.y = TILE_H
	_tiles_ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tiles_ci.draw.connect(_draw_tiles)
	add_child(_tiles_ci)
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", GAP)
	strip.custom_minimum_size.y = CHIP_H
	add_child(strip)
	for i in DIFFS.size():
		var chip := Button.new()
		chip.text = DIFFS[i]
		chip.focus_mode = Control.FOCUS_NONE
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_override("font", _body)
		chip.add_theme_font_size_override("font_size", 32)
		chip.pressed.connect(_pick.bind(i))
		strip.add_child(chip)
		_chips.append(chip)
	_grid_ci = Control.new()
	_grid_ci.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_ci.draw.connect(_draw_grid)
	add_child(_grid_ci)

func refresh() -> void:
	_log = Progress.solve_log()
	_summary = PlayerStats.summary(_log)
	_best = int(Streak.compute(_log, Daily.date_key()).best)
	_diff = Progress.stats_difficulty()
	_boards = PlayerStats.boards(_log, _diff)
	_dress_chips()
	_tiles_ci.queue_redraw()
	_grid_ci.queue_redraw()

func _pick(i: int) -> void:
	if i == _diff:
		return
	Progress.set_stats_difficulty(i)
	_diff = i
	_boards = PlayerStats.boards(_log, _diff)
	_dress_chips()
	_grid_ci.queue_redraw()

## Insane is the night chip, as on the difficulty sheet: ink fill, paper
## lettering, a sun ring when chosen. The others are paper, and the chosen one
## is SUN_TILE ringed in ACCENT_2.
func _dress_chips() -> void:
	for i in _chips.size():
		var on := i == _diff
		var night := i == 3
		var fill: Color = Pal.TEXT if night else (Pal.SUN_TILE if on else Pal.SURFACE)
		var ring: Color = (Pal.SUN if night else Pal.ACCENT_2) if on else Pal.LINE
		var ink: Color = Pal.PAPER if night else (Pal.ACCENT_2 if on else Pal.TEXT)
		var box := CozyTheme.card(fill, 30, ring, 5 if on else 3, 0)
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			_chips[i].add_theme_stylebox_override(state, box)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			_chips[i].add_theme_color_override(c, ink)

func _mmss(t: float) -> String:
	var s := int(round(t))
	return "%d:%02d" % [s / 60, s % 60]

func _draw_tiles() -> void:
	var ci := _tiles_ci
	var w := (ci.size.x - GAP * 2) / 3.0
	var rows := [
		[str(int(_summary.get("solved", 0))), "STATS_SOLVED"],
		[str(int(_summary.get("days", 0))), "STATS_DAYS"],
		[str(_best), "STATS_BEST_STREAK"],
	]
	for i in 3:
		var r := Rect2(i * (w + GAP), 0, w, TILE_H)
		ci.draw_style_box(CozyTheme.card(Pal.SURFACE, 30, Pal.LINE, 6, 0), r)
		Ink.text(ci, _big, rows[i][0], Vector2(r.get_center().x, 104), 72, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		Ink.text(ci, _body, tr(rows[i][1]), Vector2(r.get_center().x, 156), 30, Pal.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_grid() -> void:
	var ci := _grid_ci
	var n := Registry.PUZZLES.size()
	var rows := int(ceil(n / float(COLS)))
	var tw := (ci.size.x - CELL_GAP * (COLS - 1)) / COLS
	var th := (ci.size.y - CELL_GAP * (rows - 1)) / rows
	var box := CozyTheme.card(Pal.SURFACE, 24, Pal.LINE, 4, 0)
	var faded := _faded(box, UNSOLVED_ALPHA)
	for i in n:
		var entry: Dictionary = Registry.PUZZLES[i]
		var row: Dictionary = _boards.get(String(entry.id), {})
		var solved := int(row.get("count", 0)) > 0
		var a := 1.0 if solved else UNSOLVED_ALPHA
		var r := Rect2((i % COLS) * (tw + CELL_GAP), (i / COLS) * (th + CELL_GAP), tw, th)
		ci.draw_style_box(box if solved else faded, r)
		var dot: Color = Pal.CAT[i % Pal.CAT.size()]
		ci.draw_circle(r.position + Vector2(28, 38), 11, Color(dot, dot.a * a))
		var title := String(entry.title)
		var size := Ink.fit(_head, title, 30, tw - 60)
		Ink.text(ci, _head, title, r.position + Vector2(48, 49), size, Color(Pal.TEXT, a))
		if solved:
			Ink.text(ci, _body, tr("STATS_COUNT") % int(row.count), r.position + Vector2(20, th * 0.58), 28, Pal.TEXT)
			if float(row.best) > 0.0:
				Ink.text(ci, _body, "%s · %s" % [_mmss(row.best), _mmss(row.mean)],
					r.position + Vector2(20, th * 0.82), 26, Pal.TEXT_DIM)
		else:
			Ink.text(ci, _body, "—", r.position + Vector2(20, th * 0.66), 34, Color(Pal.TEXT_DIM, a))

func _faded(box: StyleBoxFlat, a: float) -> StyleBoxFlat:
	var b := box.duplicate() as StyleBoxFlat
	b.bg_color.a *= a
	b.border_color.a *= a
	return b
```

- [ ] **Step 3: Parse-check**

Run: `godot --headless --path . --import >/dev/null 2>&1; godot --headless --check-only --script ui/menu/stats_tab.gd`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add ui/menu/stats_tab.gd locale/ui.csv
git add ui/menu/*.uid 2>/dev/null
git commit -m "feat(menu): the Stats tab"
```

---

### Task 5: The first screen wires it together

**Files:**
- Modify: `ui/menu.gd` (`_build_list` lines 181-312, `_fit_grid` ~401, `_can_swipe` ~453, `_show_list` ~609, `_on_tab` ~663)
- Modify: `ui/menu/bottom_bar.gd` (all tabs live, `unbuilt` removed)
- Modify: `ui/menu/day_row.gd` (real hearts, chevron signal)
- Modify: `ui/menu/menu_header.gd` (streak badge)
- Modify: `locale/ui.csv` (delete `MENU_CALENDAR_SOON`, `MENU_TAB_SOON`)
- Modify: `tests/_shot_menu.gd` (replace the dead `legacy_sheet` path with a tab shot)
- Modify: `CLAUDE.md` (the "decoration" paragraphs), `docs/roadmap-to-release.md`

**Interfaces:**
- Consumes: `StreakTab`, `StatsTab` (each `refresh()`), `Progress.hearts()`, `Progress.solve_log()`, `Streak.compute`
- Produces: `menu._show_tab(key: String) -> void` (used by the harness).

- [ ] **Step 1: `bottom_bar.gd`** — set `"live": true` on stats and streak,
delete the `unbuilt` signal and its doc lines, and make `_on_tab` only
`picked.emit(String(tab.key))`. Update the header comment: all three tabs are
real since 2026-09-24.

- [ ] **Step 2: `day_row.gd`** — real hearts

Replace the header comment's decoration paragraph with: the hearts count
today's distinct boards solved (`Progress.hearts`, three keep the streak) and
the chevron opens Streak (spec 2026-09-24-stats-streak-design.md, section 4).
Delete `const HEARTS_FULL := 2`. Add:

```gdscript
signal open_streak

## The pop waits for the row's own entrance to land.
const POP_DELAY := 0.45

var _hearts_ci: Control
var _hearts := 0
var _known := false
var _popping := -1
var _pop_t := 0.0:
	set(value):
		_pop_t = value
		if is_instance_valid(_hearts_ci):
			_hearts_ci.queue_redraw()

## Today's count. The first call only sets it; a later rise pops the newest
## heart in, so coming back from the solve that earned it shows it arriving.
func set_hearts(n: int) -> void:
	n = clampi(n, 0, HEARTS)
	var rose := _known and n > _hearts
	_hearts = n
	_known = true
	_popping = n - 1 if rose else -1
	if rose and not Motion.reduce:
		_pop_t = 0.0
		create_tween().tween_property(self, "_pop_t", Motion.POP_IN, Motion.POP_IN).set_delay(POP_DELAY)
	else:
		_pop_t = Motion.POP_IN
	if is_instance_valid(_hearts_ci):
		_hearts_ci.queue_redraw()
```

In `_build`, keep a reference: `_hearts_ci = hearts` after creating it, and
connect the chevron: `go.pressed.connect(func() -> void: open_streak.emit())`.
Replace `_draw_hearts` with:

```gdscript
func _draw_hearts(on: Control) -> void:
	for i in HEARTS:
		var centre := Vector2(i * (HEART + HEART_GAP) + HEART * 0.5, HEART * 0.5)
		var s := Motion.pop_in_scale(_pop_t) if i == _popping else Vector2.ONE
		on.draw_set_transform(centre, 0.0, s)
		var box := Rect2(Vector2(-HEART, -HEART) * 0.5, Vector2(HEART, HEART))
		if i < _hearts:
			Icons.paint(on, "heart", box, Pal.ACCENT_2)
		else:
			Icons.paint(on, "heart_line", box, Pal.LINE)
	on.draw_set_transform(Vector2.ZERO)
```

`Motion` comes from the panel base (`ui/hud/panel.gd` preloads it).

- [ ] **Step 3: `menu_header.gd`** — streak badge

Replace the calendar comment (lines ~22-26) with: the calendar badge shows the
current streak and hides at 0; the calendar opens Streak. Keep the badge
Control in a var `_badge`. Add `var _streak := 0` and:

```gdscript
## The current streak on the calendar; hidden at 0, a pill past one digit.
func set_streak(n: int) -> void:
	_streak = maxi(n, 0)
	if _badge == null:
		return
	_badge.visible = _streak > 0
	var w := maxf(BADGE, _badge_font().get_string_size(str(_streak), HORIZONTAL_ALIGNMENT_LEFT, -1, int(BADGE * 0.56)).x + BADGE * 0.5)
	_badge.offset_left = -w - BUTTON.x * 0.06
	_badge.queue_redraw()

func _badge_font() -> Font:
	return CozyTheme.display(700)
```

and `_draw_badge`:

```gdscript
func _draw_badge(ci: Control) -> void:
	var r := BADGE * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.ACCENT_2
	sb.set_corner_radius_all(int(r))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(ci.size.x, BADGE)))
	var sz := int(BADGE * 0.56)
	var s := str(_streak)
	var w := _badge_font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	ci.draw_string(_badge_font(), Vector2(ci.size.x * 0.5 - w * 0.5, r + sz * 0.36), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Pal.SURFACE)
```

Start the badge hidden (`badge.visible = false`) in `_build`.

- [ ] **Step 4: `ui/menu.gd`** — the tabs

Preloads: `const StreakTab = preload("res://ui/menu/streak_tab.gd")`,
`const StatsTab = preload("res://ui/menu/stats_tab.gd")`,
`const Streak = preload("res://core/streak.gd")`. Vars:
`var streak_tab: Control`, `var stats_tab: Control`, `var _tab := "home"`,
`var _tab_tw: Tween`.

In `_build_list`:
- Replace the `header.calendar.pressed` handler with `_show_tab("streak")`.
- After `root.add_child(day_row)`, add
  `day_row.open_streak.connect(func() -> void: _show_tab("streak"))`.
- After `root.add_child(_grid)`, add both tabs, hidden:

```gdscript
	# Stats and Streak take the day row's, the grid's and the pager's room
	# when picked; the header and the bar stay (spec 2026-09-24, section 4).
	streak_tab = StreakTab.new()
	streak_tab.name = "StreakTab"
	streak_tab.visible = false
	root.add_child(streak_tab)
	stats_tab = StatsTab.new()
	stats_tab.name = "StatsTab"
	stats_tab.visible = false
	root.add_child(stats_tab)
```

- Replace the `bar.unbuilt.connect(...)` lines with nothing
  (`bar.picked.connect(_on_tab)` stays).

Replace `_on_tab`:

```gdscript
func _on_tab(tab: String) -> void:
	_show_tab(tab)

## Home is the day row, the grid and the pager; Stats and Streak each put
## their body in that room. A tab's body fades in; Home re-fits the grid,
## which is not measured while it is hidden.
func _show_tab(key: String) -> void:
	_tab = key
	bar.show_tab(key)
	var home := key == "home"
	day_row.visible = home
	_grid.visible = home
	streak_tab.visible = key == "streak"
	stats_tab.visible = key == "stats"
	Motion.stop(_tab_tw)
	if home:
		_set_pager(_page, _pages())
		_queue_fit()
		return
	_pager.visible = false
	var body: Control = streak_tab if key == "streak" else stats_tab
	body.refresh()
	_tab_tw = Motion.appear(body, 0.0, 1.0, ENTER_FADE)
	Analytics.track("tab_opened", {"tab": key})
```

Check `_set_pager`'s body: if it sets `_pager.visible` from the page count,
calling it restores the pill on Home; if it does not, set
`_pager.visible = _pages() > 1` there instead. Read it before writing.

In `_fit_grid`, first line: `if not _grid.visible: return`.
In `_can_swipe`, add `and _grid.visible` to the condition.
In `_show_list`, replace `bar.show_tab("home")` with `_show_tab("home")`,
and after `day_row.set_day(...)` add:

```gdscript
	var today := Daily.date_key()
	day_row.set_hearts(Progress.hearts(today))
	header.set_streak(int(Streak.compute(Progress.solve_log(), today).current))
```

`_show_list` runs on launch and every time a board closes, so the badge and
hearts are always fresh on Home, and the pop plays on the return from the
solve that raised the count.

- [ ] **Step 5: Locale** — delete the `MENU_CALENDAR_SOON` and
`MENU_TAB_SOON` rows from `locale/ui.csv`; `grep -rn "MENU_CALENDAR_SOON\|MENU_TAB_SOON" ui core`
must print nothing.

- [ ] **Step 6: Harness** — in `tests/_shot_menu.gd`, replace the non-page2
branch `_menu.legacy_sheet.open()` (dead since the 3D removal) with a tab
shot: read `var _tab_arg := ""` from the user args (`streak` or `stats`, the
first arg that is one of them), and in phase 0's shot branch call
`_menu._show_tab(_tab_arg)` when it is set; the phase-1 shot then saves
`/tmp/shot_menu_2.png` as before. Print its own
`tab idle ... max_draw_calls=` line the way the page2 branch does (reset
`_idle`/`_draws` after the switch and sample for the last 0.5 s before
`SECOND_AT`). With no arg, phase 1 just shoots Home again. Update the header
comment's usage lines.

- [ ] **Step 7: Parse-check and suite**

Run: `godot --headless --path . --import >/dev/null 2>&1; for f in ui/menu.gd ui/menu/bottom_bar.gd ui/menu/day_row.gd ui/menu/menu_header.gd tests/_shot_menu.gd; do godot --headless --check-only --script $f || echo FAIL $f; done; godot --headless --path . --script tests/run_tests.gd 2>&1 | grep passed=`
Expected: no `FAIL`, `failed=0`. A suite failure that names the bottom bar,
the day row or `unbuilt` is a test asserting the old decoration: update that
assertion to the new behaviour and say so in the commit.

- [ ] **Step 8: Shots** (windowed, one at a time; the first run of a session
compiles shaders, so take each reading twice and quote the second)

Seed a history first so the screens have something to show: write
`$SCRATCH/seed_log.gd` (a SceneTree script that calls `Progress.log_solve`
for 3 distinct registry ids a day over the previous 20 days with one day of
2 and today with 2, then quits), and run it with
`godot --headless --path . --script $SCRATCH/seed_log.gd`. **Back up
`progress.cfg` first**
(`cp ~/Library/Application\ Support/Godot/app_userdata/Daily/progress.cfg $SCRATCH/progress.bak`,
if it exists) and restore it after the shots.

Run:
`godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd -- streak`
then the same with `-- stats`, then with no arg (Home).
Expected: Home reads about 330 draw calls (the control) and shows two filled
hearts and a badge; Streak and Stats each read under 855. Read
`/tmp/shot_menu_1.png` and `/tmp/shot_menu_2.png` (crop with PIL) and check:
the badge number equals the Streak card's number; the calendar marks the
seeded 2-solve day as rest or partial per the rules; twenty stat tiles all
fit with no text overflowing a tile ("Mushroom Patch" fitted smaller); the
Insane chip is dark.

Manual (Review Focus 5): run `godot --path . --resolution 810x1440` windowed,
open Stats, drag horizontally across the tab, go Home: the page has not
turned and the grid is laid out as before.

- [ ] **Step 9: Docs**

`CLAUDE.md`, "The first screen": replace the bullet beginning **"The hearts,
the calendar badge and the day chevron are decoration"** with: the hearts
count today's distinct boards solved and three keep a streak; the badge is
the current streak; the chevron and the badge open Streak; Stats and Streak
are real tabs whose bodies replace the day row and grid; everything is derived
from `Progress.solve_log()` (spec `2026-09-24-stats-streak-design.md`); then
quote the draw-call readings from Step 8. `docs/roadmap-to-release.md`: tick
the first three "Stats and Streak" boxes with the date and a one-line
summary each; leave cloud backup open.

- [ ] **Step 10: Commit**

```bash
git add ui/menu.gd ui/menu/bottom_bar.gd ui/menu/day_row.gd ui/menu/menu_header.gd locale/ui.csv tests/_shot_menu.gd CLAUDE.md docs/roadmap-to-release.md
git commit -m "feat(menu): Stats and Streak are real tabs, and the hearts and badge count"
```
