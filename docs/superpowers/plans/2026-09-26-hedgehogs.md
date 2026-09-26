# Hedgehogs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Hedgehogs, the twenty-fourth flat board: rake an autumn lawn's leaf piles, flag where the hedgehogs sleep, and a wrong rake only wakes one up grumpy.

**Architecture:** Three layers, the way every flat board is built:
- **`puzzles/hedgehogs_gen.gd`** (scene-free): the deal, the flood and the logic proof.
- **`puzzles/hedgehogs_state.gd`** (scene-free): raked, flags, woken, pins, gestures, Undo, Reset, Hint and Check.
- **`puzzles/hedgehogs2d.gd`**: draws the state as two baked meshes plus text and animates the gust.

The drawings are `ui/faces/leaf_pile.gd` (builder shapes: ground, pile, flag, rake) and `ui/faces/hedgehog_face.gd` (a Face). Mushroom Patch is the template for the tray and the rows, and Knight (commits `34ec7dd`..`565ca0b`) for every other integration point.

**Tech Stack:** Godot 4.7 GDScript, gl_compatibility, `Face.Builder` meshes, `core/motion.gd` curve readers.

**Spec:** `docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md`. The canvas mock at `docs/brainstorm/concepts.html#hedgehogs` is the reference for every measure.

**Every code block in this plan was run before it was written down** (2026-09-26, while planning):
- the generator probe passed over 160 lawns;
- a throwaway state probe passed;
- every file passed `--check-only`;
- a headless drive of the board passed (wake, flag, refused rake, Check, Undo, rake, Reset, hints to the solve, `solved` firing once, restore);
- the bare board rendered through the real host at 79 draw calls.

Then the tree was reverted. Paste the code as written. If a step's expected output differs, stop and find out why rather than editing around it.

## Global Constraints

- **Naming.**
  - It is called **Hedgehogs** in code, comments, commit messages and on screen, in every language.
  - The genre's usual name and the reference app's name appear only in the spec, once, to forbid them. Never write either anywhere else.
  - Registry id `hedgehogs`; locale keys prefixed `HH_` (and `TRAY_RAKE`, `TRAY_FLAG`).
- **Draw calls and meshes.**
  - The 855 draw-call budget holds.
  - A drawing is one baked `ArrayMesh` per layer, never per-piece `draw_*` calls; the numbers and the tally are the only drawn text.
  - Keep the last meshes handed to the canvas in `_shown` (a canvas command holds a mesh by RID).
- **No uniform tricks.** No `instance uniform` anywhere.
- **Harness runs.**
  - Engine flags go before `--script`: `godot --path . --resolution 810x1440 --always-on-top --script res://tests/<harness>.gd -- <args>`.
  - Run windowed harnesses one at a time, and take two readings, quoting the second.
  - Commit before any windowed run (the `project.godot` trap). Afterwards `git status --short project.godot`, and `git checkout project.godot` if Godot touched it.
- **Tests.** No new suite tests (MVP rule).
  - Verification is throwaway probes (written to the session scratchpad or as `tests/_tmp_*.gd` and deleted before the commit), plus the committed generator probe `tests/_probe_hedgehogs_gen.gd`.
  - The suite's registry guard loads every entry's script, so a parse error fails `tests/run_tests.gd`.
  - Run `godot --headless --check-only --path . --script <file>` on every new `.gd` before any harness. `ui/flat/flat_host.gd` always reports `Identifier not found: Ads` under `--check-only` (an autoload); that one is not yours.
- **Motion.** `Motion.reduce` makes every animation land at once: the gust, the pops, the win wave.
- **Input.** A tap during a gust is taken, not refused. Only the entrance blocks input (spec section 7).
- **Sound.** Missing sound files are silence. Do not generate sounds; only add the prompts.
- **Translations.** After editing `locale/boards.csv`, run `godot --headless --path . --import` once, or `tr()` hands back raw keys and every `%d` string errors with "not all arguments converted".
- **Git.** Work in place on branch `feat/hedgehogs`. Commit per task. Do not push.

## Review Focus

1. **A second tap mid-gust** (raking again, or chording, before the first gust's leaves have landed) must leave the drawing matching the state once everything settles:
   - no cell drawn covered that the state has raked;
   - no pile left hanging mid-blow.

   Every cell carries its own `_blow_at`/`_until`, and `_process` settles a cell only when its own `_until` passes. Task 4's step 6 drive rakes twice in one frame and checks `_moving` empties and `_still` rebuilds.
2. **Undo right after a gesture that also woke a hedgehog** (a chord over a wrong flag) re-covers the raked cells and keeps the woken one awake, with its face still seated and `woken` unchanged. Task 2's state probe covers the state; Task 4's step 6 drive covers the face.
3. **Long press then release.** The release after a long press must not act a second time.
   - A quick tap must never fire the long press, even though `_later` timers outlive the press.

   `_press_id` guards both. Task 4's step 6 drive pushes a press, advances 0.5 s, releases, and checks one flag and no rake.
4. **Hint when the player's own flags are right but unproved.** The hint must never trust a player's flag. When logic has proved a hedgehog the player already flagged, the hint moves on to the next deduction instead of pinning it.
   - Task 2's probe solves 40 lawns by hint alone with zero woken.
5. **Reopening an already-solved daily** (`restore_completed_board`) shows every bare cell raked and every hedgehog awake on its cell, and never fires `solved` again. Task 4's drive covers it.

---

### Task 1: The generator

**Files:**
- Create: `puzzles/hedgehogs_gen.gd`
- Create: `tests/_probe_hedgehogs_gen.gd`

**Interfaces:**
- Produces (Tasks 2 and 4 rely on these exact names):
  - `BANDS`, `ATTEMPTS`, `band(d) -> Dictionary`;
  - `neighbours(cols, rows, c) -> PackedInt32Array`;
  - `blank(cols, rows, k) -> Dictionary`, `count(g)`;
  - `flood(g, open: PackedByteArray, c) -> Array[Vector2i]` (x = cell, y = ring);
  - `deduce(g, open, known, subsets) -> Dictionary` (`{rule, safe: PackedInt32Array, hogs: PackedInt32Array}` or `{}`);
  - `prove(g, subsets) -> {ok, rounds, sub, cnt}`;
  - `generate(rng, d) -> Dictionary`, with keys `cols rows n k nb hog num start graded attempts opened proof`.
- Cells are ints `y * cols + x`. `hog` is a `PackedByteArray` (1 = hedgehog); `num` is a `PackedInt32Array` (-1 on a hedgehog); `nb[c]` is `c`'s neighbour table.

- [ ] **Step 1: Write the generator**

`puzzles/hedgehogs_gen.gd`:

```gdscript
extends RefCounted

## Hedgehogs' day, scene-free: the lawn, the flood and the logic that proves
## it.
##
## A cols x rows lawn under leaf piles, k hedgehogs asleep under some of
## them. The day opens with one bare patch already raked: the opening cell
## and its eight neighbours are kept clear of hedgehogs, so the opening is a
## nought and floods. A deal is kept only if a solver that never guesses,
## starting from that opening, rakes every bare cell -- singles (a number's
## covered neighbours are all bare, or all hedgehogs), subsets (one number's
## covered set inside another's) where the level allows them, and the global
## count. Hard must need a subset at least once and Insane twice; Easy and
## Medium never may. A board logic plays out from the opening has one answer
## consistent with what it shows, so no separate uniqueness test is asked.
##
## Cells are ints, y * cols + x. Ported line for line from the concept
## page's mock (docs/brainstorm/concepts.html#hedgehogs: hedgehogBoard,
## hFlood, hDeduce, hProve).
## Spec: docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md, section 5.

## Per level: the lawn, the hedgehogs, whether the proof may subtract
## subsets and how many rounds must need one, and the opening flood's range
## in cells. Insane's row is provisional (CLAUDE.md, "Insane is a fourth
## level").
const BANDS := [
	{"cols": 8, "rows": 10, "k": 12, "subsets": false, "need_sub": 0, "open": Vector2i(12, 40)},
	{"cols": 9, "rows": 11, "k": 17, "subsets": false, "need_sub": 0, "open": Vector2i(12, 36)},
	{"cols": 10, "rows": 11, "k": 21, "subsets": true, "need_sub": 1, "open": Vector2i(8, 30)},
	{"cols": 10, "rows": 11, "k": 24, "subsets": true, "need_sub": 2, "open": Vector2i(6, 28)},
]
## Deals tried before the first proved one is handed back ungraded.
const ATTEMPTS := 400

static func band(d: int) -> Dictionary:
	return BANDS[clampi(d, 0, BANDS.size() - 1)]

## The up to eight cells round `c`, in row order.
static func neighbours(cols: int, rows: int, c: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x := c % cols
	var y := c / cols
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if nx >= 0 and ny >= 0 and nx < cols and ny < rows:
				out.append(ny * cols + nx)
	return out

## An empty lawn's dictionary: its size, a neighbour table built once, no
## hedgehogs yet.
static func blank(cols: int, rows: int, k: int) -> Dictionary:
	var n := cols * rows
	var nb: Array = []
	for c in n:
		nb.append(neighbours(cols, rows, c))
	var hog := PackedByteArray()
	hog.resize(n)
	var num := PackedInt32Array()
	num.resize(n)
	return {"cols": cols, "rows": rows, "n": n, "k": k, "nb": nb, "hog": hog, "num": num,
		"start": 0, "graded": true, "attempts": 0, "opened": 0, "proof": {}}

## Counts every bare cell's hedgehog neighbours; a hedgehog's own is -1.
static func count(g: Dictionary) -> void:
	var hog: PackedByteArray = g.hog
	var num: PackedInt32Array = g.num
	for c in int(g.n):
		if hog[c] == 1:
			num[c] = -1
			continue
		var s := 0
		for r: int in g.nb[c]:
			s += hog[r]
		num[c] = s

## Rakes `c` on `open` (1 = raked): a nought floods through its neighbours
## that are neither raked nor hedgehogs, and on through every nought it
## reaches. Returns Vector2i(cell, ring) in breadth-first order, `ring`
## being the distance from `c` -- the gust's timing. A hedgehog or a raked
## cell returns nothing.
static func flood(g: Dictionary, open: PackedByteArray, c: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var hog: PackedByteArray = g.hog
	var num: PackedInt32Array = g.num
	if open[c] == 1 or hog[c] == 1:
		return out
	open[c] = 1
	var q: Array[Vector2i] = [Vector2i(c, 0)]
	var head := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		out.append(p)
		if num[p.x] != 0:
			continue
		for r: int in g.nb[p.x]:
			if open[r] == 0 and hog[r] == 0:
				open[r] = 1
				q.append(Vector2i(r, p.y + 1))
	return out

## One round of logic from what is known: `open` (raked cells, whose numbers
## are read) and `known` (1 = a hedgehog known to be there: woken, pinned or
## proved). Returns {"rule": "single"|"subset"|"count", "safe", "hogs"} for
## the first rule family that decides anything, both sorted ascending, or {}
## when none does. **The player's flags are never read**: a flag may be
## wrong.
static func deduce(g: Dictionary, open: PackedByteArray, known: PackedByteArray, subsets: bool) -> Dictionary:
	var num: PackedInt32Array = g.num
	var cons: Array = []  # [PackedInt32Array unknowns, need]
	for c in int(g.n):
		if open[c] == 0:
			continue
		var u := PackedInt32Array()
		var need: int = num[c]
		for r: int in g.nb[c]:
			if known[r] == 1:
				need -= 1
			elif open[r] == 0:
				u.append(r)
		if not u.is_empty():
			cons.append([u, need])
	var safe := {}
	var hogs := {}
	for k: Array in cons:
		var u: PackedInt32Array = k[0]
		if int(k[1]) == 0:
			for r in u:
				safe[r] = true
		elif int(k[1]) == u.size():
			for r in u:
				hogs[r] = true
	if not safe.is_empty() or not hogs.is_empty():
		return _found("single", safe, hogs)
	if subsets:
		for a: Array in cons:
			var au: PackedInt32Array = a[0]
			for b: Array in cons:
				var bu: PackedInt32Array = b[0]
				if a == b or au.size() >= bu.size():
					continue
				var inside := true
				for r in au:
					if not bu.has(r):
						inside = false
						break
				if not inside:
					continue
				var diff := PackedInt32Array()
				for r in bu:
					if not au.has(r):
						diff.append(r)
				var dn: int = int(b[1]) - int(a[1])
				if dn == 0:
					for r in diff:
						safe[r] = true
				elif dn == diff.size():
					for r in diff:
						hogs[r] = true
		if not safe.is_empty() or not hogs.is_empty():
			return _found("subset", safe, hogs)
	var left: int = g.k
	var unk := {}
	for c in int(g.n):
		if known[c] == 1:
			left -= 1
		elif open[c] == 0:
			unk[c] = true
	if not unk.is_empty() and left == 0:
		return _found("count", unk, {})
	if not unk.is_empty() and left == unk.size():
		return _found("count", {}, unk)
	return {}

static func _found(rule: String, safe: Dictionary, hogs: Dictionary) -> Dictionary:
	var s := PackedInt32Array(safe.keys())
	s.sort()
	var h := PackedInt32Array(hogs.keys())
	h.sort()
	return {"rule": rule, "safe": s, "hogs": h}

## Plays the whole lawn out by logic from the opening. {"ok", "rounds",
## "sub" (rounds that needed a subset), "cnt" (rounds that needed the count)}.
static func prove(g: Dictionary, subsets: bool) -> Dictionary:
	var n: int = g.n
	var open := PackedByteArray()
	open.resize(n)
	var known := PackedByteArray()
	known.resize(n)
	flood(g, open, g.start)
	var hog: PackedByteArray = g.hog
	var safe_left := 0
	for c in n:
		if hog[c] == 0 and open[c] == 0:
			safe_left += 1
	var rounds := 0
	var sub := 0
	var cnt := 0
	while safe_left > 0:
		var d := deduce(g, open, known, subsets)
		if d.is_empty():
			return {"ok": false, "rounds": rounds, "sub": sub, "cnt": cnt}
		rounds += 1
		if d.rule == "subset":
			sub += 1
		elif d.rule == "count":
			cnt += 1
		for r: int in d.hogs:
			known[r] = 1
		for r: int in d.safe:
			if open[r] == 0:
				safe_left -= flood(g, open, r).size()
	return {"ok": true, "rounds": rounds, "sub": sub, "cnt": cnt}

## The day's lawn for level `d`, seeded only by `rng`. The opening is dealt
## away from the edge with its 3x3 kept clear; the hedgehogs are the first k
## of the rest, shuffled. Kept only if the opening flood is in the level's
## range and `prove` plays the lawn out; a proof short of the level's subset
## quota is kept aside as the fallback, handed back ungraded after ATTEMPTS.
static func generate(rng: RandomNumberGenerator, d: int) -> Dictionary:
	var bd := band(d)
	var cols: int = bd.cols
	var rows: int = bd.rows
	var fallback := {}
	for attempt in range(1, ATTEMPTS + 1):
		var g := blank(cols, rows, bd.k)
		var sx := rng.randi_range(1, cols - 2)
		var sy := rng.randi_range(1, rows - 2)
		g.start = sy * cols + sx
		var free: Array[int] = []
		for c in int(g.n):
			if absi(c % cols - sx) > 1 or absi(c / cols - sy) > 1:
				free.append(c)
		for i in range(free.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := free[i]
			free[i] = free[j]
			free[j] = t
		var hog: PackedByteArray = g.hog
		for i in int(bd.k):
			hog[free[i]] = 1
		count(g)
		var probe := PackedByteArray()
		probe.resize(g.n)
		var opened := flood(g, probe, g.start).size()
		var span: Vector2i = bd.open
		if opened < span.x or opened > span.y:
			continue
		var p := prove(g, bd.subsets)
		if not p.ok:
			continue
		g.attempts = attempt
		g.opened = opened
		g.proof = p
		if int(p.sub) < int(bd.need_sub):
			if fallback.is_empty():
				fallback = g
			continue
		g.graded = true
		return g
	if not fallback.is_empty():
		fallback.graded = false
		fallback.attempts = ATTEMPTS
	return fallback
```

- [ ] **Step 2: Write the probe**

`tests/_probe_hedgehogs_gen.gd`:

```gdscript
extends SceneTree

## Hedgehogs' generator, timed and checked: forty seeds a level, the mean and
## worst wall time in GDScript, the deals it took, the opening's range, and
## every lawn re-proved from scratch -- the opening clear, every number right,
## logic raking every bare cell, the subset quota met or the board marked
## ungraded. A harness, not a suite entry.
##     godot --headless --path . --script tests/_probe_hedgehogs_gen.gd
const G := preload("res://puzzles/hedgehogs_gen.gd")

func _initialize() -> void:
	var failures := 0
	for d in 4:
		var bd := G.band(d)
		var worst := 0.0
		var sum := 0.0
		var att_max := 0
		var att_sum := 0
		var lo := 999
		var hi := 0
		var ungraded := 0
		var sub_sum := 0
		var cnt := 40
		for s in cnt:
			var rng := RandomNumberGenerator.new()
			rng.seed = s * 7919 + d
			var t0 := Time.get_ticks_usec()
			var g := G.generate(rng, d)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			worst = maxf(worst, ms)
			sum += ms
			if g.is_empty():
				print("FAIL d=%d seed=%d: no board at all" % [d, s])
				failures += 1
				continue
			att_max = maxi(att_max, int(g.attempts))
			att_sum += int(g.attempts)
			lo = mini(lo, int(g.opened))
			hi = maxi(hi, int(g.opened))
			if not g.graded:
				ungraded += 1
			sub_sum += int(g.proof.sub)
			failures += _check(g, bd, d, s)
		print("d=%d %dx%d k=%d: mean %.1f ms, worst %.1f ms; deals mean %.1f, worst %d; opening %d-%d; subset rounds mean %.2f; ungraded %d/%d" % [
			d, bd.cols, bd.rows, bd.k, sum / cnt, worst, float(att_sum) / cnt, att_max, lo, hi, float(sub_sum) / cnt, ungraded, cnt])
	print("PROBE %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit()

## Re-checks one lawn from its hedgehogs alone.
func _check(g: Dictionary, bd: Dictionary, d: int, s: int) -> int:
	var bad := 0
	var hog: PackedByteArray = g.hog
	var total := 0
	for c in int(g.n):
		total += hog[c]
	if total != int(bd.k):
		print("FAIL d=%d seed=%d: %d hedgehogs, not %d" % [d, s, total, bd.k])
		bad += 1
	var cols: int = g.cols
	var sx: int = int(g.start) % cols
	var sy: int = int(g.start) / cols
	for c in int(g.n):
		if hog[c] == 1 and absi(c % cols - sx) <= 1 and absi(c / cols - sy) <= 1:
			print("FAIL d=%d seed=%d: a hedgehog in the opening" % [d, s])
			bad += 1
		if hog[c] == 0:
			var want := 0
			for r in G.neighbours(cols, g.rows, c):
				want += hog[r]
			if int(g.num[c]) != want:
				print("FAIL d=%d seed=%d: cell %d says %d, not %d" % [d, s, c, g.num[c], want])
				bad += 1
	var p := G.prove(g, bd.subsets)
	if not p.ok:
		print("FAIL d=%d seed=%d: logic cannot play it out" % [d, s])
		bad += 1
	if not bool(bd.subsets) and int(p.sub) > 0:
		print("FAIL d=%d seed=%d: needs a subset on a level without them" % [d, s])
		bad += 1
	if g.graded and int(p.sub) < int(bd.need_sub):
		print("FAIL d=%d seed=%d: graded but short of the subset quota" % [d, s])
		bad += 1
	return bad
```

- [ ] **Step 3: Parse check and run**

Run: `godot --headless --check-only --path . --script puzzles/hedgehogs_gen.gd`, then `godot --headless --path . --script tests/_probe_hedgehogs_gen.gd 2>&1 | grep -e "^d=" -e PROBE`

Expected, with times within noise of these:
```
d=0 8x10 k=12: mean 1.6 ms, worst 4.7 ms; deals mean 4.1, worst 14; opening 12-40; subset rounds mean 0.00; ungraded 0/40
d=1 9x11 k=17: mean 4.0 ms, worst 12.5 ms; deals mean 9.3, worst 33; opening 12-36; subset rounds mean 0.00; ungraded 0/40
d=2 10x11 k=21: mean 5.7 ms, worst 26.8 ms; deals mean 9.9, worst 61; opening 9-30; subset rounds mean 2.00; ungraded 0/40
d=3 10x11 k=24: mean 16.0 ms, worst 53.6 ms; deals mean 29.2, worst 104; opening 9-28; subset rounds mean 3.12; ungraded 0/40
PROBE PASS (0 failures)
```

Two things must hold:
- every worst case is under the 194 ms gate;
- `PROBE PASS`.

- [ ] **Step 4: Commit**

```bash
git add puzzles/hedgehogs_gen.gd puzzles/hedgehogs_gen.gd.uid tests/_probe_hedgehogs_gen.gd tests/_probe_hedgehogs_gen.gd.uid
git commit -m "feat(hedgehogs): the generator -- the opening, the flood, the logic proof, the deal"
```

(If Godot has not written the `.uid` files yet, drop them from the `git add`.)

---

### Task 2: The state

**Files:**
- Create: `puzzles/hedgehogs_state.gd`
- Throwaway: `tests/_tmp_probe_hedgehogs_state.gd` (deleted before the commit)

**Interfaces:**
- Consumes: Task 1's `Gen.generate`, `Gen.flood`, `Gen.deduce`, and `g.nb` / `g.hog` / `g.num` / `g.start` / `g.k`.
- Produces (Tasks 3 to 5 rely on these exact names):
  - `RAKE` 0, `FLAG` 1, `Gen`;
  - `g`, and the `PackedByteArray`s `open`, `flag`, `woke`, `pin`, `wrong`;
  - `woken: int`, `history: Array`;
  - `setup(rng, difficulty)`, `cols()`, `rows()`, `size()`, `is_hog(c)`, `number(c)`, `is_solved()`, `marked_around(c)`, `flags_left()`, `can_undo()`;
  - `rake(c)`: `{kind, cells, rings, from}`, `kind` in `raked woke refused_flag refused_pin none` (or chord's kinds, since a raked number forwards);
  - `chord(c)`: `{kind, cells, rings, woke, from}`, `kind` in `chord too_few too_many none`;
  - `toggle_flag(c)`: `{kind}`, `kind` in `laid lifted refused_pin none`;
  - `undo()`: `{raked, flags}` or `{}`;
  - `reset_board() -> PackedInt32Array`;
  - `hint_step()`: `{kind: "rake"|"flag", cell}` or `{}`;
  - `apply_hint(step)`: `rake()`'s result or `{kind: "pinned", cell}`;
  - `check() -> PackedInt32Array`;
  - `share_glyphs() -> String`.

- [ ] **Step 1: Write the state**

`puzzles/hedgehogs_state.gd`:

```gdscript
extends RefCounted

## Hedgehogs' rules as the board plays them, scene-free, as every flat
## board's are. The board (puzzles/hedgehogs2d.gd) draws this and nothing
## else.
##
## Rake a covered cell: bare, it shows its number and a nought floods; a
## hedgehog **wakes** -- it becomes a known hedgehog for good, `woken` goes
## up, and the day goes on. A flag keeps the rake off. A raked number whose
## flags and woken hedgehogs match it rakes its other neighbours (a chord).
## Done when every bare cell is raked; flags are never needed.
##
## Nothing here reads the answer to judge a flag except Check, which is
## paid for. A woken hedgehog and a hint's pinned flag are facts: Undo and
## Reset keep both.
## Spec: docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md, section 6.

const Gen = preload("res://puzzles/hedgehogs_gen.gd")

## The two chips: what a tap on a covered cell does.
const RAKE := 0
const FLAG := 1

## The generated lawn (hedgehogs_gen.gd's dictionary).
var g: Dictionary = {}
var open := PackedByteArray()   # 1 = raked
var flag := PackedByteArray()   # 1 = the player's flag (or a hint's)
var woke := PackedByteArray()   # 1 = a hedgehog a rake woke
var pin := PackedByteArray()    # 1 = a hint's flag, not the player's to lift
## Flags Check found wrong; cleared by any move.
var wrong := PackedByteArray()
var woken := 0
## One entry per gesture, newest last:
## {"raked": PackedInt32Array, "flags": [[cell, was]]}.
var history: Array = []

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	g = Gen.generate(rng, difficulty)
	var n: int = g.n
	for a: PackedByteArray in [open, flag, woke, pin, wrong]:
		a.resize(n)
		a.fill(0)
	woken = 0
	history = []
	Gen.flood(g, open, g.start)

func cols() -> int: return int(g.get("cols", 0))
func rows() -> int: return int(g.get("rows", 0))
func size() -> int: return int(g.get("n", 0))
func is_hog(c: int) -> bool: return g.hog[c] == 1
func number(c: int) -> int: return int(g.num[c])

## Every bare cell raked.
func is_solved() -> bool:
	if g.is_empty():
		return false
	var hog: PackedByteArray = g.hog
	for c in size():
		if hog[c] == 0 and open[c] == 0:
			return false
	return true

## Flags and woken hedgehogs around `c`.
func marked_around(c: int) -> int:
	var s := 0
	for r: int in g.nb[c]:
		if flag[r] == 1 or woke[r] == 1:
			s += 1
	return s

## The tally: hedgehogs less flags less woken. Negative means too many flags.
func flags_left() -> int:
	var s: int = g.k
	for c in size():
		if flag[c] == 1 or woke[c] == 1:
			s -= 1
	return s

func can_undo() -> bool:
	return not history.is_empty()

## Floods from `c` (already known bare and covered), lifting any flag the
## flood crosses, and returns the flood with rings offset by `ring0`.
func _rake_from(c: int, ring0: int, out_cells: PackedInt32Array, out_rings: PackedInt32Array) -> void:
	for p: Vector2i in Gen.flood(g, open, c):
		if flag[p.x] == 1 and pin[p.x] == 0:
			flag[p.x] = 0
		out_cells.append(p.x)
		out_rings.append(p.y + ring0)

## A tap with the rake on `c`. {"kind", "cells", "rings", "from"}, `kind`
## one of "raked", "woke", "refused_flag", "refused_pin", "none"; a raked
## number forwards to chord().
func rake(c: int) -> Dictionary:
	var res := {"kind": "none", "cells": PackedInt32Array(), "rings": PackedInt32Array(), "from": c}
	if is_solved():
		return res
	if open[c] == 1:
		return chord(c)
	if woke[c] == 1:
		return res
	if flag[c] == 1:
		res.kind = "refused_pin" if pin[c] == 1 else "refused_flag"
		return res
	wrong.fill(0)
	if is_hog(c):
		woke[c] = 1
		woken += 1
		res.kind = "woke"
		res.cells.append(c)
		res.rings.append(0)
		return res
	var cells := PackedInt32Array()
	var rings := PackedInt32Array()
	_rake_from(c, 0, cells, rings)
	history.append({"raked": cells, "flags": []})
	res.kind = "raked"
	res.cells = cells
	res.rings = rings
	return res

## A tap on a raked number: if its flags and woken hedgehogs match it, every
## other covered neighbour is raked (a wrong flag among them can wake one).
## {"kind" ("chord", "too_few", "too_many", "none"), "cells", "rings",
## "woke" (PackedInt32Array), "from"}; rings count from the number, so its
## neighbours are ring 1.
func chord(c: int) -> Dictionary:
	var res := {"kind": "none", "cells": PackedInt32Array(), "rings": PackedInt32Array(),
		"woke": PackedInt32Array(), "from": c}
	if open[c] == 0 or is_solved():
		return res
	var v := number(c)
	var covered := PackedInt32Array()
	for r: int in g.nb[c]:
		if open[r] == 0 and flag[r] == 0 and woke[r] == 0:
			covered.append(r)
	if v <= 0 or covered.is_empty():
		return res
	var m := marked_around(c)
	if m != v:
		res.kind = "too_few" if m < v else "too_many"
		return res
	wrong.fill(0)
	var cells := PackedInt32Array()
	var rings := PackedInt32Array()
	for r in covered:
		if open[r] == 1:
			continue
		if is_hog(r):
			woke[r] = 1
			woken += 1
			res.woke.append(r)
			continue
		_rake_from(r, 1, cells, rings)
	if not cells.is_empty():
		history.append({"raked": cells, "flags": []})
	res.kind = "chord"
	res.cells = cells
	res.rings = rings
	return res

## Lays or lifts a flag on a covered cell. {"kind"}: "laid", "lifted",
## "refused_pin" or "none".
func toggle_flag(c: int) -> Dictionary:
	if is_solved() or open[c] == 1 or woke[c] == 1:
		return {"kind": "none"}
	if pin[c] == 1:
		return {"kind": "refused_pin"}
	wrong.fill(0)
	history.append({"raked": PackedInt32Array(), "flags": [[c, int(flag[c])]]})
	flag[c] = 1 - flag[c]
	return {"kind": "laid" if flag[c] == 1 else "lifted"}

## Takes back the last gesture: {"raked" (re-covered, in flood order),
## "flags" ([[cell, restored value]])}, or {} with nothing to undo. A woken
## hedgehog stays awake.
func undo() -> Dictionary:
	if history.is_empty():
		return {}
	wrong.fill(0)
	var h: Dictionary = history.pop_back()
	var raked: PackedInt32Array = h.raked
	for c in raked:
		open[c] = 0
	var flags: Array = []
	for f: Array in h.flags:
		flag[int(f[0])] = int(f[1])
		flags.append([int(f[0]), int(f[1])])
	# A flood lifts the unpinned flags it crosses; they are not put back,
	# since logic had proved those cells bare.
	return {"raked": raked, "flags": flags}

## Back to the opening. Woken hedgehogs and a hint's flags stay. Returns the
## cells re-covered.
func reset_board() -> PackedInt32Array:
	var keep := PackedByteArray()
	keep.resize(size())
	Gen.flood(g, keep, g.start)
	var covered := PackedInt32Array()
	for c in size():
		if open[c] == 1 and keep[c] == 0:
			open[c] = 0
			covered.append(c)
		if flag[c] == 1 and pin[c] == 0:
			flag[c] = 0
	wrong.fill(0)
	history = []
	return covered

## The next thing logic can prove from what the player can see (raked
## numbers, woken hedgehogs, a hint's flags -- never the player's flags):
## {"kind": "rake", "cell"} for a cell that must be bare, else {"kind":
## "flag", "cell"} for one that must be a hedgehog and is not yet flagged;
## {} when solved. A hedgehog the player already flagged counts as known once
## logic proves it, and the search moves on.
func hint_step() -> Dictionary:
	if is_solved():
		return {}
	var known := PackedByteArray()
	known.resize(size())
	for c in size():
		if woke[c] == 1 or pin[c] == 1:
			known[c] = 1
	for guard in size():
		var d := Gen.deduce(g, open, known, true)
		if d.is_empty():
			return {}
		for c: int in d.safe:
			if open[c] == 0:
				return {"kind": "rake", "cell": c}
		for c: int in d.hogs:
			if flag[c] == 0:
				return {"kind": "flag", "cell": c}
		for c: int in d.hogs:
			known[c] = 1
	return {}

## Plays a hint_step: a rake (lifting a flag on the cell first) returns
## rake()'s result; a flag is laid and pinned and returns {"kind": "pinned",
## "cell"}.
func apply_hint(step: Dictionary) -> Dictionary:
	var c: int = step.cell
	if step.kind == "rake":
		if flag[c] == 1 and pin[c] == 0:
			flag[c] = 0
		return rake(c)
	wrong.fill(0)
	flag[c] = 1
	pin[c] = 1
	return {"kind": "pinned", "cell": c}

## The flags with no hedgehog under them, marked in `wrong` until the next
## move.
func check() -> PackedInt32Array:
	var out := PackedInt32Array()
	wrong.fill(0)
	for c in size():
		if flag[c] == 1 and not is_hog(c):
			wrong[c] = 1
			out.append(c)
	return out

## A row per lawn row -- a leaf for a covered pile, green for a raked cell, a
## hedgehog for a woken one -- then how many woke. The shape of the day and
## never its answer: a hedgehog left asleep is a leaf like any other pile.
func share_glyphs() -> String:
	var lines := PackedStringArray()
	for y in rows():
		var s := ""
		for x in cols():
			var c := y * cols() + x
			s += "🦔" if woke[c] == 1 else ("🟩" if open[c] == 1 else "🍂")
		lines.append(s)
	return "\n".join(lines)
```

- [ ] **Step 2: Write the throwaway probe**

`tests/_tmp_probe_hedgehogs_state.gd`:

```gdscript
extends SceneTree

## The state, driven the way the board drives it (throwaway: deleted before
## the commit).
const S := preload("res://puzzles/hedgehogs_state.gd")
var fails := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL ", what)

func fresh(d: int, seed: int) -> Object:
	var st := S.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	st.setup(rng, d)
	return st

func _initialize() -> void:
	for d in 4:
		for s in 10:
			var st = fresh(d, s * 31 + d)
			ok(st.open.size() == st.size() and st.flag.size() == st.size(), "arrays sized d=%d" % d)
			ok(st.open[st.g.start] == 1, "opening raked")
			# hints alone play every board out, never waking anything
			var guard := 0
			while not st.is_solved() and guard < 400:
				guard += 1
				var h: Dictionary = st.hint_step()
				ok(not h.is_empty(), "hint stuck d=%d s=%d" % [d, s])
				if h.is_empty():
					break
				var r: Dictionary = st.apply_hint(h)
				ok(r.kind != "woke", "a hint woke a hedgehog")
			ok(st.is_solved() and st.woken == 0, "hints solve d=%d s=%d" % [d, s])
	# waking: a rake on a hedgehog adds no history and is kept by undo/reset
	var st = fresh(1, 5)
	var hogc := -1
	for c in st.size():
		if st.is_hog(c):
			hogc = c
			break
	var r: Dictionary = st.rake(hogc)
	ok(r.kind == "woke" and st.woken == 1 and st.woke[hogc] == 1 and st.history.is_empty(), "woke")
	ok(st.rake(hogc).kind == "none", "raking a woken one does nothing")
	ok(st.flags_left() == st.g.k - 1, "woken counts against the tally")
	# a flag refuses the rake; a flood crossing an unpinned flag lifts it
	var bare := -1
	for c in st.size():
		if not st.is_hog(c) and st.open[c] == 0:
			bare = c
			break
	ok(st.toggle_flag(bare).kind == "laid", "flag laid")
	ok(st.rake(bare).kind == "refused_flag", "flag refuses the rake")
	var chk: PackedInt32Array = st.check()
	ok(chk.size() == 1 and chk[0] == bare and st.wrong[bare] == 1, "check finds the wrong flag")
	ok(st.toggle_flag(bare).kind == "lifted" and st.wrong[bare] == 0, "a move clears the check")
	var h0: int = st.history.size()
	r = st.rake(bare)
	ok(r.kind == "raked" and st.open[bare] == 1 and st.history.size() == h0 + 1, "raked")
	var u: Dictionary = st.undo()
	ok(st.open[bare] == 0 and (u.raked as PackedInt32Array).has(bare), "undo re-covers")
	ok(st.woken == 1 and st.woke[hogc] == 1, "undo keeps the woken")
	# reset keeps woken and pins, drops the player's flags and rakes
	var st2 = fresh(2, 9)
	var hs: Dictionary = st2.hint_step()
	while hs.kind != "flag":
		st2.apply_hint(hs)
		hs = st2.hint_step()
	st2.apply_hint(hs)
	var pinned: int = hs.cell
	ok(st2.pin[pinned] == 1 and st2.toggle_flag(pinned).kind == "refused_pin", "pinned flag stays")
	ok(st2.rake(pinned).kind == "refused_pin", "pinned refuses the rake")
	st2.reset_board()
	ok(st2.flag[pinned] == 1 and st2.pin[pinned] == 1, "reset keeps pins")
	var keep := 0
	for c in st2.size():
		keep += st2.open[c]
	ok(keep == S.Gen.flood(st2.g, PackedByteArray(Array(range(st2.size())).map(func(_x): return 0)), st2.g.start).size(), "reset back to the opening")
	# chord: flag a number's hedgehogs correctly, chord rakes the rest
	var st3 = fresh(1, 77)
	var did := false
	for c in st3.size():
		if st3.open[c] == 1 and st3.number(c) > 0:
			var cov := 0
			for n2: int in st3.g.nb[c]:
				if st3.open[n2] == 0 and not st3.is_hog(n2):
					cov += 1
			if cov == 0:
				continue
			ok(st3.chord(c).kind == "too_few", "chord refused with too few")
			for n2: int in st3.g.nb[c]:
				if st3.is_hog(n2):
					st3.toggle_flag(n2)
			var rc: Dictionary = st3.chord(c)
			ok(rc.kind == "chord" and (rc.woke as PackedInt32Array).is_empty() and not (rc.cells as PackedInt32Array).is_empty(), "chord rakes")
			ok((rc.rings as PackedInt32Array)[0] >= 1, "chord rings start at 1")
			did = true
			break
	ok(did, "found a chord to test")
	# a wrong flag in a chord wakes a hedgehog
	var st4 = fresh(0, 3)
	var tested := false
	for c in st4.size():
		if st4.open[c] == 1 and st4.number(c) == 1:
			var hog_n := -1
			var bare_n := -1
			for n2: int in st4.g.nb[c]:
				if st4.open[n2] == 0:
					if st4.is_hog(n2):
						hog_n = n2
					elif bare_n < 0:
						bare_n = n2
			if hog_n < 0 or bare_n < 0:
				continue
			st4.toggle_flag(bare_n)
			var rw: Dictionary = st4.chord(c)
			ok(rw.kind == "chord" and (rw.woke as PackedInt32Array).has(hog_n) and st4.woken == 1, "wrong flag chord wakes")
			tested = true
			break
	ok(tested, "found a wrong-flag chord to test")
	print(st4.share_glyphs())
	print("STATE PROBE %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
```

- [ ] **Step 3: Run it**

Run: `godot --headless --check-only --path . --script puzzles/hedgehogs_state.gd`, then `godot --headless --path . --script tests/_tmp_probe_hedgehogs_state.gd 2>&1 | tail -12`

Expected: a 10-row grid of 🟩/🍂/🦔 followed by `STATE PROBE PASS (0 failures)`.

- [ ] **Step 4: Delete the probe and commit**

```bash
rm -f tests/_tmp_probe_hedgehogs_state.gd tests/_tmp_probe_hedgehogs_state.gd.uid
git add puzzles/hedgehogs_state.gd puzzles/hedgehogs_state.gd.uid
git commit -m "feat(hedgehogs): the state -- rake, wake, flag, chord; undo and reset keep the woken; hint trusts no player flag"
```

---

### Task 3: The palette, the drawings and the tray

**Files:**
- Modify: `core/palette.gd` (append a block at the end)
- Create: `ui/faces/leaf_pile.gd`
- Create: `ui/faces/hedgehog_face.gd`
- Modify: `ui/flat/tile_tray.gd` (two preloads, the `LAWN` set, two glyph branches)
- Modify: `ui/flat/flat_host.gd` (a `"lawn"` tray branch)

**Interfaces:**
- Consumes: Task 2's `HedgehogsState.RAKE` and `FLAG`.
- Produces (Tasks 4 and 6 rely on these):
  - `Pal.LAWN`, `LAWN_DEEP`, `RAKED`, `RAKED_EDGE`, `PILE`, `PILE_DEEP`, `AUTUMN_LEAVES`, `HOG_*`, `PENNANT`, `PENNANT_DEEP`, `NUM_INK`;
  - `Lawn.h01(a, b)`, `Lawn.ground(b, centre, s, cell_id, raked, woke, alpha := 1.0)`;
  - `Lawn.pile(b, centre, s, cell_id, blow := 0.0, dir := Vector2.UP, scale := Vector2.ONE, alpha := 1.0)`;
  - `Lawn.flag(b, centre, R, wrong := false, scale := Vector2.ONE, alpha := 1.0)`, `Lawn.rake(b, centre, s)`;
  - `HedgehogFace` (a Face; `expression` SLEEPY, STRAIN, JOY or HAPPY picks the look);
  - `TileTray.LAWN`, and `"tray": "lawn"` in the host.

- [ ] **Step 1: The palette**

Append to the end of `core/palette.gd`:

```gdscript
# --- Hedgehogs (2026-09-26): an autumn lawn under leaf piles, and the
# hedgehogs asleep under them. The mock's own values
# (docs/brainstorm/concepts.html#hedgehogs, HG). ---
const LAWN          := Color("9fc27c")   # a covered cell's turf
const LAWN_DEEP     := Color("7fa362")   # its rim and its grass tufts
const RAKED         := Color("e4ecc9")   # a raked cell's grass
const RAKED_EDGE    := Color("cfdab0")
const PILE          := Color("e3b574")   # a leaf pile's mound
const PILE_DEEP     := Color("c8924f")
const AUTUMN_LEAVES := [Color("e0913f"), Color("c9652f"), Color("e8b54a"), Color("b5532e"), Color("d9a441")]
const HOG_SPINE      := Color("8b6a4c")
const HOG_SPINE_DEEP := Color("6e5139")
const HOG_SPINE_HI   := Color("a8876a")
const HOG_FACE       := Color("f2dcbc")
const HOG_FACE_DEEP  := Color("dcbf98")
const PENNANT        := SUN               # a flag's pennant
const PENNANT_DEEP   := SUN_DEEP
## A number's ink by its count: 1 leaf, 2 teal, 3 brick, 4 plum, 5 bark,
## 6 teal, 7 and 8 ink. Index 0 is never drawn.
const NUM_INK := [TEXT, Color("4a7a36"), Color("2f6f7c"), Color("b0483f"), Color("6c4a8c"),
	Color("7f4f22"), Color("2f6f7c"), TEXT, TEXT]
```

- [ ] **Step 2: The lawn's drawings**

`ui/faces/leaf_pile.gd`:

```gdscript
extends RefCounted

## Hedgehogs' lawn as builder shapes rather than Controls: a cell's ground,
## a leaf pile and a flag, the drawings the board (puzzles/hedgehogs2d.gd),
## the tray's flag chip (ui/flat/tile_tray.gd) and the menu card
## (ui/menu/card_art.gd) all make, so none of them can drift apart. A hard
## lawn carries a hundred piles, so they are batched into one mesh the way
## `ui/faces/patch_cloth.gd`'s patches and `paper_plane.gd`'s darts are.
##
## A pile is a mound and five almond leaves in the autumn colours, each
## leaf's place, turn and colour hashed from the cell so the same pile is
## drawn every frame. `blow` carries the leaves off: 0 is a pile at rest,
## 0..1 is the gust taking them (they fly along `dir`, spin and fade, and the
## mound is gone), 1 is nothing.
## Ported from the concept page's mock (docs/brainstorm/concepts.html#hedgehogs:
## pile, almond, flagMark, and drawCell's ground).
## Spec: docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md, section 7.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")

const LEAVES := 5
## A leaf's length, and how far its hashed seat strays from the cell's
## middle, as fractions of the cell.
const LEAF_LEN := 0.34
const SPREAD := Vector2(0.5, 0.4)
## The mound under the leaves: its half-size and its lip, in cells.
const MOUND := Vector2(0.37, 0.26)
const MOUND_LIP := 0.05
## How far a blown leaf travels, in cells, and how high it lifts on the way.
const FLY := 0.9
const LOFT := 0.3
## A cell's ground: the gap round it, its corner, and the rim under it, in
## cells.
const INSET := 0.04
const RADIUS := 0.18
const RIM := 0.05
const RAKED_RIM := 0.03
## A woken hedgehog's cell: how far the raked grass washes toward BAD.
const WOKE_WASH := 0.38

## A small stable hash of two ints into [0, 1), the mock's `hash`.
static func h01(a: int, b: int) -> float:
	var x := (a * 374761393 + b * 668265263) ^ (a * b * 1274126177)
	x = ((x ^ (x >> 13)) * 1274126177) & 0xffffffff
	return float((x ^ (x >> 16)) & 0xffffffff) / 4294967296.0

## One almond leaf, `length` long, centred on `at` and turned `angle`, with a
## faint vein down its middle.
static func almond(b: Face.Builder, at: Vector2, length: float, angle: float, colour: Color) -> void:
	var xf := Transform2D(angle, at)
	var half := length * 0.5
	var pts := Face.Builder.bezier2(Vector2(-half, 0.0), Vector2(0.0, -length * 0.36), Vector2(half, 0.0), 8)
	pts.append_array(Face.Builder.bezier2(Vector2(half, 0.0), Vector2(0.0, length * 0.36), Vector2(-half, 0.0), 8))
	b.fan(xf * pts, colour)
	var vein := Color(0.35, 0.2, 0.08, 0.35 * colour.a)
	b.stroke(xf * PackedVector2Array([Vector2(-length * 0.42, 0.0), Vector2(length * 0.4, 0.0)]),
		maxf(1.5, length * 0.05), vein)

## A cell's ground, the cell `s` wide centred on `centre`: the lawn's turf
## with its tufts while covered, the raked grass once raked -- washed toward
## BAD when a woken hedgehog lies on it. `alpha` fades it.
static func ground(b: Face.Builder, centre: Vector2, s: float, cell_id: int, raked: bool, woke: bool, alpha := 1.0) -> void:
	var inset := s * INSET
	var at := centre - Vector2.ONE * (s * 0.5 - inset)
	var box := Vector2.ONE * (s - 2.0 * inset)
	var r := s * RADIUS
	if raked:
		var fill: Color = Pal.RAKED.lerp(Pal.BAD, WOKE_WASH) if woke else Pal.RAKED
		b.fan(Face.Builder.round_rect(at, box, r), Color(Pal.RAKED_EDGE, alpha))
		b.fan(Face.Builder.round_rect(at, box - Vector2(0.0, s * RAKED_RIM), r), Color(fill, alpha))
		return
	b.fan(Face.Builder.round_rect(at, box, r), Color(Pal.LAWN_DEEP, alpha))
	b.fan(Face.Builder.round_rect(at, box - Vector2(0.0, s * RIM), r), Color(Pal.LAWN, alpha))
	var tuft := Color(Pal.LAWN_DEEP, 0.5 * alpha)
	for i in 3:
		var tx := centre.x + (h01(cell_id, i + 70) - 0.5) * s * 0.7
		var ty := centre.y + s * 0.3
		b.stroke(PackedVector2Array([Vector2(tx, ty), Vector2(tx - s * 0.03, ty - s * 0.08)]), s * 0.025, tuft)
		b.stroke(PackedVector2Array([Vector2(tx, ty), Vector2(tx + s * 0.03, ty - s * 0.09)]), s * 0.025, tuft)

## A leaf pile on the cell `s` wide centred on `centre`. `blow` 0 is at rest;
## above it the mound is gone and the leaves fly along `dir` (a unit vector),
## spinning and fading, until 1. `scale` squashes the whole pile about its
## centre (an Undo's pop back in); `alpha` fades it (a flagged pile, pressed
## down under its twig).
static func pile(b: Face.Builder, centre: Vector2, s: float, cell_id: int, blow := 0.0,
		dir := Vector2.UP, scale := Vector2.ONE, alpha := 1.0) -> void:
	if blow >= 1.0 or alpha <= 0.0:
		return
	if blow <= 0.0:
		b.ellipse(centre + Vector2(0.0, s * (0.05 + MOUND_LIP)) * scale,
			s * (MOUND.x + 0.03) * scale.x, s * (MOUND.y + 0.04) * scale.y, Color(Pal.PILE_DEEP, alpha))
		b.ellipse(centre + Vector2(0.0, s * 0.05) * scale, s * MOUND.x * scale.x, s * MOUND.y * scale.y,
			Color(Pal.PILE, alpha))
	var u := clampf(blow, 0.0, 1.0)
	for i in LEAVES:
		var off := Vector2((h01(cell_id * 7 + i, 11) - 0.5) * s * SPREAD.x,
			(h01(cell_id * 5 + i, 23) - 0.5) * s * SPREAD.y)
		var angle := h01(cell_id + i * 3, 31) * TAU
		var colour: Color = Pal.AUTUMN_LEAVES[int(h01(cell_id * 3 + i, 47) * Pal.AUTUMN_LEAVES.size()) % Pal.AUTUMN_LEAVES.size()]
		var at := centre + off * scale
		if u > 0.0:
			var fly := u * u * FLY * s
			var drift := (h01(i, cell_id * 2) - 0.5) * u * s * 0.5
			at += dir * fly + Vector2(drift, -sin(PI * u) * s * LOFT)
			angle += u * (h01(i, cell_id) - 0.5) * 6.0
		almond(b, at, s * LEAF_LEN * scale.x, angle, Color(colour, alpha * (1.0 - u)))

## A flag: a bark twig pushed into the pile with a two-tone pennant, `R`
## (about 0.46 of a cell on the lawn) sized about `centre`. `wrong` turns the
## pennant rose (Check's answer); `scale` pops it in and out.
static func flag(b: Face.Builder, centre: Vector2, R: float, wrong := false, scale := Vector2.ONE, alpha := 1.0) -> void:
	if scale.x <= 0.0 or scale.y <= 0.0 or alpha <= 0.0:
		return
	var xf := Transform2D(0.0, scale, 0.0, centre)
	b.ellipse(centre + Vector2(0.0, R * 0.62) * scale, R * 0.34 * scale.x, R * 0.1 * scale.y, Color(Pal.TEXT, 0.16 * alpha))
	b.stroke(xf * PackedVector2Array([Vector2(-0.08, 0.62) * R, Vector2(-0.08, -0.7) * R]), R * 0.12 * scale.x,
		Color(Pal.BARK, alpha))
	var lit: Color = Pal.BAD if wrong else Pal.PENNANT
	var deep: Color = Color("b54a45") if wrong else Pal.PENNANT_DEEP
	b.polygon(xf * PackedVector2Array([Vector2(-0.02, -0.7) * R, Vector2(0.66, -0.44) * R, Vector2(-0.02, -0.16) * R]),
		Color(lit, alpha))
	b.polygon(xf * PackedVector2Array([Vector2(-0.02, -0.44) * R, Vector2(0.66, -0.44) * R, Vector2(-0.02, -0.16) * R]),
		Color(deep, alpha))

## The rake chip's picture: a bark handle leaning right and a five-tined
## head, `s` across, centred on `centre`.
static func rake(b: Face.Builder, centre: Vector2, s: float) -> void:
	var xf := Transform2D(-0.5, centre)
	b.stroke(xf * PackedVector2Array([Vector2(0.0, 0.5) * s, Vector2(0.0, -0.2) * s]), s * 0.1, Pal.BARK)
	b.stroke(xf * PackedVector2Array([Vector2(-0.3, -0.2) * s, Vector2(0.3, -0.2) * s]), s * 0.09, Pal.PILE_DEEP)
	for i in 5:
		var tx := -0.28 + float(i) * 0.14
		b.stroke(xf * PackedVector2Array([Vector2(tx, -0.2) * s, Vector2(tx, -0.42) * s]), s * 0.06, Pal.PILE_DEEP)
```

- [ ] **Step 3: The hedgehog**

`ui/faces/hedgehog_face.gd`:

```gdscript
extends "res://ui/faces/face.gd"

## The hedgehog, Hedgehogs' one character and the cast's first new animal
## since the bee: a brown dome of spines over a cream snout, looking left.
## Nothing else in the cast sleeps under leaves, which is what earns it a
## drawing of its own (CLAUDE.md, "check ui/faces/ before drawing a new
## character").
##
## Its looks are its expressions, so each is keyed into the mesh cache for
## free (the body layer carries the face):
##   SLEEPY -- upright, eyes shut in a downward arc: a sleeper under a pile;
##   STRAIN -- curled into a ball of spines with the snout tucked in and a
##             frown: a hedgehog a wrong rake woke;
##   JOY    -- up on its feet, eyes shut in a smile, mouth open: the win;
##   HAPPY  -- up on its feet, one round eye with a catchlight.
## Ported from the concept page's mock (docs/brainstorm/concepts.html#hedgehogs,
## `hedgehog`). Spec: docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md,
## section 7.


## R as a fraction of the seat.
const RATIO := 0.36
## The spines round the dome and round the ball.
const DOME_SPINES := 16
const BALL_SPINES := 22

func _kind() -> String:
	return "hedgehog"

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	return [["shadow", false], ["body", true]]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 0.62 * R), 1.05 * R, 0.2 * R, Color(Pal.TEXT, 0.14))
		"body":
			if expression == Expr.STRAIN:
				_curled(b, R)
			else:
				_upright(b, R, eye)

## A ball of spines with the snout tucked in, a cheek and a frown.
func _curled(b: Builder, R: float) -> void:
	var ball := PackedVector2Array()
	for i in BALL_SPINES * 2:
		var a := float(i) / float(BALL_SPINES * 2) * TAU
		var r := (0.78 if i % 2 == 1 else 0.95) * R
		ball.append(Vector2(cos(a) * r, sin(a) * r * 0.92))
	b.polygon(ball, Pal.HOG_SPINE_DEEP)
	b.ellipse(Vector2.ZERO, 0.74 * R, 0.68 * R, Pal.HOG_SPINE)
	b.ellipse(Vector2(-0.2, 0.18) * R, 0.44 * R, 0.36 * R, Pal.HOG_FACE)
	b.disc(Vector2(-0.56, 0.16) * R, 0.09 * R, Pal.TEXT)
	b.ellipse(Vector2(-0.04, 0.3) * R, 0.1 * R, 0.07 * R, Color(Pal.CHEEK, 0.9))
	for ex: float in [-0.34, -0.06]:
		b.stroke(PackedVector2Array([Vector2(ex - 0.07, 0.02) * R, Vector2(ex + 0.07, 0.07) * R]), 0.06 * R, Pal.TEXT)
	b.stroke(Builder.arc_points(Vector2(-0.24, 0.42) * R, 0.1 * R, PI * 1.15, PI * 1.85), 0.05 * R, Pal.TEXT)

## Up on its feet: the spiny back, a paler dome with a few spine strokes, the
## snout to the left with its nose, a cheek, and the eye the expression says.
func _upright(b: Builder, R: float, eye: float) -> void:
	var up := expression == Expr.JOY or expression == Expr.HAPPY
	if up:
		b.ellipse(Vector2(-0.45, 0.55) * R, 0.14 * R, 0.1 * R, Pal.HOG_FACE_DEEP)
		b.ellipse(Vector2(0.35, 0.55) * R, 0.14 * R, 0.1 * R, Pal.HOG_FACE_DEEP)
	var back := PackedVector2Array([Vector2(1.0, 0.45) * R])
	for i in DOME_SPINES * 2 + 1:
		var a := float(i) / float(DOME_SPINES * 2) * PI
		var r := (0.86 if i % 2 == 1 else 1.04) * 1.02 * R
		back.append(Vector2(cos(a) * r, 0.45 * R - sin(a) * r))
	b.polygon(back, Pal.HOG_SPINE_DEEP)
	var dome := Builder.arc_points(Vector2(0.05, 0.45) * R, 0.84 * R, PI, TAU)
	b.polygon(dome, Pal.HOG_SPINE)
	for i in 7:
		var a := PI * (0.2 + float(i) * 0.1)
		var dir := Vector2(cos(a), -sin(a))
		var o := Vector2(0.05, 0.45) * R
		b.stroke(PackedVector2Array([o + dir * 0.4 * R, o + dir * 0.66 * R]), 0.05 * R, Pal.HOG_SPINE_HI)
	var snout := PackedVector2Array()
	snout.append_array(Builder.bezier2(Vector2(-0.35, -0.05) * R, Vector2(-1.05, 0.12) * R, Vector2(-1.08, 0.32) * R, 10))
	snout.append_array(Builder.bezier2(Vector2(-1.08, 0.32) * R, Vector2(-0.9, 0.58) * R, Vector2(-0.2, 0.52) * R, 10))
	snout.append_array(Builder.bezier2(Vector2(-0.2, 0.52) * R, Vector2(-0.1, 0.2) * R, Vector2(-0.35, -0.05) * R, 8))
	b.polygon(snout, Pal.HOG_FACE)
	b.disc(Vector2(-1.06, 0.3) * R, 0.1 * R, Pal.TEXT)
	b.ellipse(Vector2(-0.42, 0.38) * R, 0.11 * R, 0.07 * R, Color(Pal.CHEEK, 0.85))
	var e := Vector2(-0.55, 0.16) * R
	if expression == Expr.HAPPY and eye > 0.5:
		b.disc(e, 0.075 * R, Pal.TEXT)
		b.disc(e + Vector2(-0.025, -0.03) * R, 0.025 * R, Color(1.0, 1.0, 1.0, 0.9))
	elif expression == Expr.JOY:
		b.stroke(Builder.arc_points(e + Vector2(0.0, -0.03 * R), 0.08 * R, PI * 1.1, PI * 1.9), 0.05 * R, Pal.TEXT)
		b.stroke(Builder.arc_points(Vector2(-0.74, 0.4) * R, 0.08 * R, PI * 0.1, PI * 0.9), 0.045 * R, Pal.TEXT)
	else:
		b.stroke(Builder.arc_points(e, 0.08 * R, PI * 0.1, PI * 0.9), 0.05 * R, Pal.TEXT)
```

It uses the parent's `Pal`: `face.gd` already declares `const Pal`, and redeclaring it in a subclass is a parse error.

- [ ] **Step 4: The tray's lawn set, and the host's branch**

Apply this diff (it is exactly what was checked):

```diff
diff --git a/ui/flat/flat_host.gd b/ui/flat/flat_host.gd
index 0328285..91f4f5a 100644
--- a/ui/flat/flat_host.gd
+++ b/ui/flat/flat_host.gd
@@ -296,6 +296,11 @@ func _build_chrome(root: VBoxContainer) -> void:
 			tray = TileTray.new(TileTray.PATCH)
 			tray.pick.connect(_on_brush)
 			rows.append(TileTray.HEIGHT)
+		"lawn":
+			# Hedgehogs' rake and flag: the same tray, with the lawn set.
+			tray = TileTray.new(TileTray.LAWN)
+			tray.pick.connect(_on_brush)
+			rows.append(TileTray.HEIGHT)
 		"keys":
 			# Hidden Word types: the tray is a keyboard, and the board takes
 			# its three signals directly rather than through a brush.
diff --git a/ui/flat/tile_tray.gd b/ui/flat/tile_tray.gd
index f8976dc..cf4312c 100644
--- a/ui/flat/tile_tray.gd
+++ b/ui/flat/tile_tray.gd
@@ -31,11 +31,13 @@ signal pick(v: int)
 const NonogramState = preload("res://puzzles/nonogram_state.gd")
 const QueensState = preload("res://puzzles/queens_state.gd")
 const MushroomState = preload("res://puzzles/mushroom_state.gd")
+const HedgehogsState = preload("res://puzzles/hedgehogs_state.gd")
 const BeeFace = preload("res://ui/faces/bee_face.gd")
 const MushroomFace = preload("res://ui/faces/mushroom_face.gd")
 const Face = preload("res://ui/faces/face.gd")
 const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
 const CrossMark = preload("res://ui/faces/cross_mark.gd")
+const Lawn = preload("res://ui/faces/leaf_pile.gd")
 
 const CHIP := Vector2(300.0, 130.0)
 const GAP := 40.0
@@ -78,6 +80,14 @@ const PATCH := {
 	"names": ["MushroomChip", "PebbleChip"],
 	"glyphs": ["mushroom", "pebble"],
 }
+## Hedgehogs' rake and flag, asked for with `"tray": "lawn"`: the chip armed
+## is what a tap on a covered pile does, and a long press does the other.
+const LAWN := {
+	"values": [HedgehogsState.RAKE, HedgehogsState.FLAG],
+	"labels": ["TRAY_RAKE", "TRAY_FLAG"],
+	"names": ["RakeChip", "FlagChip"],
+	"glyphs": ["rake", "flag"],
+}
 
 var chips: Array[Button] = []
 var _set: Dictionary = MOSAIC
@@ -157,6 +167,11 @@ func _draw_glyph(glyph: Control, i: int) -> void:
 		b.fan(Face.Builder.round_rect(Vector2.ZERO, glyph.size, SOCKET_RADIUS),
 			Pal.SOCKET_OUT)
 		CrossMark.draw(b, centre, GLYPH, Vector2.ONE, 1.0)
+	elif str(_set.glyphs[i]) == "rake":
+		# Hedgehogs' rake and flag, the drawings the lawn itself uses.
+		Lawn.rake(b, centre, GLYPH)
+	elif str(_set.glyphs[i]) == "flag":
+		Lawn.flag(b, centre + Vector2(-GLYPH * 0.1, GLYPH * 0.05), GLYPH * 0.5)
 	else:
 		b.fan(Face.Builder.round_rect(Vector2.ZERO, glyph.size, SOCKET_RADIUS),
 			Pal.SOCKET_OUT)
```

- [ ] **Step 5: Parse check**

Run `godot --headless --check-only --path . --script <f>` for `ui/faces/leaf_pile.gd`, `ui/faces/hedgehog_face.gd` and `ui/flat/tile_tray.gd`.

Expected: no output containing `error`.

- [ ] **Step 6: Commit**

```bash
git add core/palette.gd ui/faces/leaf_pile.gd ui/faces/leaf_pile.gd.uid ui/faces/hedgehog_face.gd ui/faces/hedgehog_face.gd.uid ui/flat/tile_tray.gd ui/flat/flat_host.gd
git commit -m "feat(hedgehogs): the lawn's colours, the pile, the flag, the hedgehog, and the rake and flag chips"
```

---

### Task 4: The board, its registry entry and its strings

**Files:**
- Create: `puzzles/hedgehogs2d.gd`
- Modify: `ui/registry.gd` (append an entry after Knight's, the last in `PUZZLES`)
- Modify: `locale/boards.csv` (append rows at the end)
- Throwaway: `tests/_tmp_drive_hedgehogs.gd` (deleted before the commit)

**Interfaces:**
- Consumes:
  - Task 2's state API;
  - Task 3's `Lawn.*`, `HedgehogFace` and `Pal` names;
  - PuzzleBase (`start`, `note_move()`, `moves`, `hints_used`, `checks`, `_done`, `_running`, `is_done()`, signals `solved`/`moved`/`focus_changed`).
- Produces (Task 5's harnesses read these):
  - `_state`, `brush`, `set_brush(v)`;
  - `cell_to_local(r, c) -> Vector2`, `_busy_until`, `_layout()`;
  - `_act(c, use)`, `hint()`, `check()`, `undo()`, `reset_board()`;
  - `hints_used`, `checks`.

- [ ] **Step 1: Write the board**

`puzzles/hedgehogs2d.gd`:

```gdscript
extends "res://core/puzzle_base.gd"

## Hedgehogs as a flat board: an autumn lawn under leaf piles, with
## hedgehogs asleep under some of them. Rake a pile and the grass under it
## shows how many hedgehogs sleep in the eight cells around; a nought blows
## its neighbours clear. Flag the piles a hedgehog must be under. Rake every
## bare cell and the day is done. A wrong rake is never a loss: the hedgehog
## wakes, curls up grumpy on a rose cell, and the day goes on. The rules live
## in puzzles/hedgehogs_state.gd, which this only draws.
##
## **The gust is this board's signature.** A raked cell's leaves blow off
## when the gust reaches it -- its flood ring times Motion.WAVE_STEP after the
## rake -- flying away from the cell that was raked, and its number pops in
## just after.
##
## How it is drawn. Two meshes and some text:
##   still -- every cell at rest: its ground, its pile, its flag. Rebuilt only
##            when a cell settles or the layout changes.
##   live  -- every cell with something moving on it (a gust, a pile popping
##            back in, a flag popping, a refusal's shiver) and the hint's
##            ring. Rebuilt only while something moves.
##   the numbers and the tally line are drawn text, one draw_set_transform a
##            cell (Mushroom Patch's precedent).
## The woken hedgehogs, and on the win every hedgehog, are HedgehogFace nodes
## in slots of their own (docs/art/flat-motion.md rule 2). The pile and the
## flag are ui/faces/leaf_pile.gd, which the tray and the menu card draw too.
##
## Spec: docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md, section 7.
## Ported from the canvas mock at docs/brainstorm/concepts.html#hedgehogs, the
## reference for every measure.

const State = preload("res://puzzles/hedgehogs_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const HedgehogFace = preload("res://ui/faces/hedgehog_face.gd")
const Lawn = preload("res://ui/faces/leaf_pile.gd")
const CozyTheme = preload("res://ui/theme.gd")

# --- the lawn ---
## The card's inset round the lawn, and the tally strip over it.
const PAD := 34.0
const TALLY := 72.0
const TALLY_SIZE := 34
const TALLY_GLYPH := 60.0
const TALLY_GAP := 14.0
## The numeral, as a fraction of a cell.
const NUM_SIZE := 0.54
## A flag's R, and a hint's sun dot at its foot, as fractions of a cell.
const FLAG_R := 0.46
const PIN_DOT := 0.06
## A hedgehog's seat, as a fraction of a cell.
const SEAT := 1.0

# --- the motion ---
## The gust: how long a pile's leaves take to go, and how long after they go
## the number pops in.
const LEAF_TIME := 0.45
const NUM_LAG := 0.12
## A flag shrinks out over this.
const FLAG_OUT := 0.2
## An Undo re-covers its flood back to front, this apart.
const UNDO_STEP := 0.012
## How long a press must be held to do the other chip's action.
const LONG_PRESS := 0.4
## The win: the sleepers' wave starts this long after the last rake, and
## the win screen waits this long after the wave.
const WIN_LEAD := 0.3
const WIN_WAIT := 2.2
const HINTS := 3
## A flood bigger than this sounds a gust rather than a rake.
const GUST_CELLS := 6
## The toast: Knight's and Rings' measure for measure.
const TOAST_HOLD := 2.6
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 40.0
const TIP_CYCLE := 8.0
const TIPS := ["HH_TIP_RAKE", "HH_TIP_NUMBER", "HH_TIP_FLAG", "HH_TIP_CHORD", "HH_TIP_WOKE"]

var _state = State.new()
var fx: Node2D
## The armed chip, read by the tray (ui/flat/tile_tray.gd's refresh).
var brush: int = State.RAKE

## Per cell: when the gust reaches it (its leaves go), the cell it blows
## from, when an Undo or a Reset re-covered it, when a flag went in or out,
## when it was refused, and when anything on it stops moving.
var _blow_at := PackedFloat64Array()
var _blow_from := PackedInt32Array()
var _cover_at := PackedFloat64Array()
var _flag_at := PackedFloat64Array()
var _unflag_at := PackedFloat64Array()
var _bump_at := PackedFloat64Array()
var _until := PackedFloat64Array()
## Cells with something moving on them: cell -> true. They are drawn in the
## live mesh and left out of the still one until they settle.
var _moving := {}
## HedgehogFace per cell, each in a slot of its own: cell -> face, face -> slot.
var _faces := {}
var _slots := {}
var _tally_face: Control
var _rings: Array = []
## The last cell raked, where the win's wave starts.
var _last := 0
## Which deal the timers belong to: a new build bumps it and a stale timer
## does nothing.
var _turn := 0

var _opened := 0.0
## Input waits for the entrance.
var _busy_until := -100.0
var _anim_until := 0.0
var _solved_at := -1.0
var _cell := 0.0
var _grid := Vector2.ZERO
var _tally_y := 0.0
var _still: ArrayMesh
var _live: ArrayMesh
## The meshes the last _draw handed over: a canvas command holds a mesh by
## RID, so dropping the only reference leaves the renderer a freed one.
var _shown: Array = []
## The press in progress: its cell, and whether its long press has fired.
var _press_cell := -1
var _press_id := 0
var _long_fired := false
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer
var _toast := ""
var _toast_arg := ""
var _toast_at := -100.0
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""

func puzzle_id() -> String: return "hedgehogs"
func title() -> String: return "Hedgehogs"

func rules() -> String:
	return tr("HH_RULES")

func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_state.setup(rng, difficulty)
	_turn += 1
	brush = State.RAKE
	var n: int = _state.size()
	for a in [_blow_at, _cover_at, _flag_at, _unflag_at, _bump_at, _until]:
		a.resize(n)
		a.fill(-100.0)
	_blow_from.resize(n)
	_blow_from.fill(-1)
	_moving = {}
	_clear_faces()
	_rings = []
	_solved_at = -1.0
	_toast = ""
	_toast_at = -100.0
	_last = int(_state.g.start)
	_opened = _now()
	# The opening's gust plays once the card has popped in.
	var gust_at := _opened + (0.0 if Motion.reduce else Motion.ENTER_DELAY + Motion.ENTER_POP)
	var opening := PackedByteArray()
	opening.resize(n)
	var flood: Array[Vector2i] = State.Gen.flood(_state.g, opening, _state.g.start)
	_gust_cells(flood, int(_state.g.start), gust_at, 0)
	_busy_until = gust_at
	if _tally_face == null:
		_tally_face = HedgehogFace.new()
		_tally_face.expression = Face.Expr.SLEEPY
		_tally_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tally_face)
	_layout()
	fx.cue("enter")
	_tip_idx = 0
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	_tip_timer.start()

func _clear_faces() -> void:
	for face in _faces.values():
		var slot: Control = _slots[face]
		slot.queue_free()
	_faces = {}
	_slots = {}

# --- layout ---

func _cell_for(available: float) -> float:
	if _state.size() == 0:
		return 0.0
	return maxf(0.0, minf((size.x - 2.0 * PAD) / float(_state.cols()),
		(available - 2.0 * PAD - TALLY) / float(_state.rows())))

func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * float(_state.rows()) + 2.0 * PAD + TALLY)

func card_centred() -> bool:
	return true

func _layout() -> void:
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var field := Vector2(_state.cols(), _state.rows()) * _cell
	var tall := minf(size.y, field.y + 2.0 * PAD + TALLY)
	var top := (size.y - tall) * 0.5
	_grid = Vector2(size.x * 0.5 - field.x * 0.5, top + PAD + TALLY)
	_tally_y = top + PAD + TALLY * 0.5
	for c: int in _faces:
		_seat(_faces[c], _centre(c))
	if _tally_face != null:
		_tally_face.size = Vector2.ONE * TALLY_GLYPH
		_tally_face.pivot_offset = _tally_face.size * 0.5
	_still = null
	_refresh()

func _centre(c: int) -> Vector2:
	return _grid + (Vector2(c % _state.cols(), c / _state.cols()) + Vector2(0.5, 0.5)) * _cell

## Control-local point over the centre of the cell at (row, column), the name
## every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(r * _state.cols() + c)

func _cell_at(local: Vector2) -> int:
	if _cell <= 0.0:
		return -1
	var v := (local - _grid) / _cell
	var x := int(floor(v.x))
	var y := int(floor(v.y))
	if x < 0 or y < 0 or x >= _state.cols() or y >= _state.rows():
		return -1
	return y * _state.cols() + x

## A hedgehog seated on the cell `centre`, in a slot of its own so the pop
## and the hop never fight the layout.
func _seat(face: Control, centre: Vector2) -> void:
	var seat := Vector2.ONE * _cell * SEAT
	var slot: Control = _slots[face]
	slot.size = seat
	slot.position = centre - seat * 0.5
	face.size = seat
	face.pivot_offset = seat * 0.5

func _face_at(c: int, expr: int) -> Control:
	if _faces.has(c):
		var have: Control = _faces[c]
		have.expression = expr
		return have
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	var face := HedgehogFace.new()
	face.expression = expr
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(face)
	_faces[c] = face
	_slots[face] = slot
	_seat(face, _centre(c))
	return face

# --- the moments ---

## Marks `c` as moving until `until`: drawn live, left out of the still mesh.
func _touch(c: int, until: float) -> void:
	_until[c] = maxf(_until[c], until)
	_moving[c] = true
	_still = null
	_busy_for(until - _now())

## A flood's gust: each cell's leaves go at its ring (offset by `ring0`)
## times WAVE_STEP after `at`, blowing away from `from`.
func _gust_cells(flood: Array, from: int, at: float, ring0: int) -> void:
	for p: Vector2i in flood:
		var when := at + (0.0 if Motion.reduce else float(p.y + ring0) * Motion.WAVE_STEP)
		_blow_at[p.x] = when
		_blow_from[p.x] = from
		_touch(p.x, when + LEAF_TIME + NUM_LAG + Motion.POP_IN)

func _gust(cells: PackedInt32Array, rings: PackedInt32Array, from: int) -> void:
	var t := _now()
	var flood: Array = []
	for i in cells.size():
		flood.append(Vector2i(cells[i], rings[i]))
	_gust_cells(flood, from, t, 0)
	if not cells.is_empty():
		_last = cells[cells.size() - 1]
		fx.cue("gust" if cells.size() > GUST_CELLS else "rake")

## A hedgehog a rake woke: its cell washes rose, it pops in curled and
## shivers, and the toast says so kindly.
func _wake(c: int) -> void:
	var t := _now()
	_blow_at[c] = t
	_blow_from[c] = c
	_touch(c, t + LEAF_TIME)
	var face := _face_at(c, Face.Expr.STRAIN)
	Motion.pop_in(face)
	Motion.shiver(face, Motion.SHIVER_PX * 3.0, Motion.SHIVER_TIME * 2.0)
	fx.cue("woke")
	_tell("HH_WOKE_FIRST" if _state.woken == 1 else "HH_WOKE_AGAIN", Face.Expr.STRAIN)

func _refuse(c: int, key: String) -> void:
	_bump_at[c] = _now()
	_touch(c, _now() + Motion.SHIVER_TIME)
	fx.cue("refuse")
	_tell(key, Face.Expr.STRAIN)

## One tap's worth on cell `c`, with the rake or the flag. A raked number
## always chords.
func _act(c: int, use: int) -> void:
	if is_done() or c < 0 or _now() < _busy_until:
		return
	if _state.open[c] == 1:
		_show_chord(_state.chord(c), c)
		return
	if use == State.FLAG:
		var f: Dictionary = _state.toggle_flag(c)
		match String(f.kind):
			"laid":
				_flag_at[c] = _now()
				_touch(c, _now() + Motion.POP_IN)
				fx.cue("flag")
				_after_move()
			"lifted":
				_unflag_at[c] = _now()
				_touch(c, _now() + FLAG_OUT)
				fx.cue("unflag")
				_after_move()
			"refused_pin":
				_refuse(c, "HH_PINNED")
		return
	_show_rake(_state.rake(c), c)

func _show_rake(r: Dictionary, c: int) -> void:
	match String(r.kind):
		"raked":
			_gust(r.cells, r.rings, c)
			_after_move()
		"woke":
			_last = c
			_wake(c)
			_after_move()
		"refused_flag":
			_refuse(c, "HH_FLAGGED")
		"refused_pin":
			_refuse(c, "HH_PINNED")
		"chord", "too_few", "too_many":
			_show_chord(r, c)

func _show_chord(r: Dictionary, c: int) -> void:
	match String(r.kind):
		"chord":
			_gust(r.cells, r.rings, c)
			for w: int in r.woke:
				_wake(w)
			fx.cue("chord")
			_after_move()
		"too_few":
			_refuse(c, "HH_CHORD_FEW")
		"too_many":
			_refuse(c, "HH_CHORD_MANY")

func _after_move() -> void:
	note_move()
	moved.emit()
	_refresh()

## Runs `fn` after `delay`, unless the board has left the tree meanwhile or
## a new deal has begun.
func _later(delay: float, fn: Callable) -> void:
	var turn := _turn
	get_tree().create_timer(maxf(0.0, delay)).timeout.connect(func():
		if is_inside_tree() and turn == _turn:
			fn.call())

# --- frames ---

func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0 or _state.size() == 0:
		return
	var t := _now()
	var settled := false
	for c: int in _moving.keys():
		if float(_until[c]) <= t:
			_moving.erase(c)
			settled = true
	if settled:
		_still = null
	if settled or _animating(t):
		_refresh()
	elif _toast != "" and t - _toast_at < TOAST_HOLD + 0.1:
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()

func _animating(t: float) -> bool:
	if not _moving.is_empty() or t < _anim_until:
		return true
	if Motion.reduce:
		return false
	return t - _opened < Motion.ENTER_DELAY + Motion.ENTER_POP + 0.1

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds + 0.05)

func _refresh() -> void:
	_live = null
	queue_redraw()

# --- the drawing ---

func _draw() -> void:
	if _state.size() == 0 or _cell <= 0.0:
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var grow := Motion.wide_pop_scale(since)
	var mid := _grid + Vector2(_state.cols(), _state.rows()) * _cell * 0.5
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var tint := Color(1.0, 1.0, 1.0, seen)
	if _still == null:
		_still = _build_still(t)
	if _live == null:
		_live = _build_live(t)
	var shown: Array = []
	for m in [_still, _live]:
		if m != null:
			draw_mesh(m, null, xf, tint)
			shown.append(m)
	_draw_numbers(t, xf, seen)
	_draw_tally(t, seen)
	_draw_toast(t, shown)
	_shown = shown

## Every cell with nothing moving on it.
func _build_still(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	for c in _state.size():
		if not _moving.has(c):
			_draw_cell(b, c, t)
	return b.mesh() if not b.verts.is_empty() else null

## Every moving cell, and the hint's ring.
func _build_live(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	for c: int in _moving:
		_draw_cell(b, c, t)
	var keep: Array = []
	for r: Dictionary in _rings:
		var u := (t - float(r.at)) / Motion.RING_TIME
		if u < 1.0:
			keep.append(r)
		if u >= 0.0 and u < 1.0:
			var rad := _cell * (0.3 + 0.4 * u)
			b.stroke(Face.Builder.ring(r.pos, rad, rad), _cell * 0.05 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)
	_rings = keep
	return b.mesh() if not b.verts.is_empty() else null

## Whether cell `c` shows as raked at `t`: raked (or woken, or a sleeper
## uncovered by the win) and the gust has reached it.
func _shows_raked(c: int, t: float) -> bool:
	var uncovered: bool = _state.open[c] == 1 or _state.woke[c] == 1 \
		or (_solved_at >= 0.0 and _state.is_hog(c))
	return uncovered and t >= float(_blow_at[c])

## One cell: its ground, its pile at rest or blowing off, its flag.
func _draw_cell(b: Face.Builder, c: int, t: float) -> void:
	var s := _cell
	var at := _centre(c)
	at.x += Motion.shiver_offset(t - float(_bump_at[c]), s * 0.03)
	var raked := _shows_raked(c, t)
	Lawn.ground(b, at, s, c, raked, _state.woke[c] == 1)
	if raked:
		var u := 1.0 if Motion.reduce else (t - float(_blow_at[c])) / LEAF_TIME
		if u < 1.0:
			Lawn.pile(b, at, s, c, maxf(u, 0.001), _blow_dir(c))
	else:
		var cover := t - float(_cover_at[c])
		var sc := Motion.pop_in_scale(cover) if cover >= 0.0 and cover < Motion.POP_IN else Vector2.ONE
		Lawn.pile(b, at, s, c, 0.0, Vector2.UP, sc, 0.45 if _state.flag[c] == 1 else 1.0)
	_draw_flag(b, c, at, t)

func _blow_dir(c: int) -> Vector2:
	var from: int = _blow_from[c]
	if from < 0 or from == c:
		return Vector2(Lawn.h01(c, 5) - 0.5, -0.6).normalized()
	var d := _centre(c) - _centre(from)
	return d.normalized() if d.length() > 0.001 else Vector2.UP

func _draw_flag(b: Face.Builder, c: int, at: Vector2, t: float) -> void:
	var s := _cell
	var foot := at + Vector2(0.0, -s * 0.02)
	var up: bool = _state.flag[c] == 1 and _state.woke[c] == 0 and _state.open[c] == 0 \
		and not (_solved_at >= 0.0 and t >= float(_blow_at[c]))
	if up:
		var sc := Motion.pop_in_scale(t - float(_flag_at[c]))
		Lawn.flag(b, foot, s * FLAG_R, _state.wrong[c] == 1, sc)
		if _state.pin[c] == 1:
			b.disc(at + Vector2(0.3, 0.3) * s, s * PIN_DOT, Pal.SUN)
		return
	var out := t - float(_unflag_at[c])
	if out >= 0.0 and out < FLAG_OUT and not Motion.reduce:
		var k := 1.0 - out / FLAG_OUT
		Lawn.flag(b, foot, s * FLAG_R, false, Vector2(k, k))

## The numerals, over the meshes and inside the entrance pop: one
## draw_set_transform a cell, so each pops in just after its leaves go. A
## nought draws nothing.
func _draw_numbers(t: float, xf: Transform2D, seen: float) -> void:
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(_cell * NUM_SIZE))
	if px <= 0:
		return
	var rise := font.get_ascent(px) * 0.5
	for c in _state.size():
		if _state.open[c] == 0:
			continue
		var v: int = _state.number(c)
		if v <= 0:
			continue
		var since := t - float(_blow_at[c]) - NUM_LAG
		if since < 0.0 and not Motion.reduce:
			continue
		var sc: Vector2 = Motion.pop_in_scale(since) if not Motion.reduce else Vector2.ONE
		var at := _centre(c) + Vector2(Motion.shiver_offset(t - float(_bump_at[c]), _cell * 0.03), _cell * 0.02)
		draw_set_transform_matrix(xf * Transform2D(0.0, sc, 0.0, at))
		var text := str(v)
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		draw_string(font, Vector2(-wide * 0.5, rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px,
			Color(Pal.NUM_INK[mini(v, Pal.NUM_INK.size() - 1)], seen))
	draw_set_transform(Vector2.ZERO)

## The tally strip: a sleeping hedgehog and how many are still asleep and
## unflagged -- the global count the proof uses, given free. BAD when there
## are more flags than hedgehogs.
func _tally_line() -> String:
	var left: int = _state.flags_left()
	if _solved_at >= 0.0:
		return tr("HH_TALLY_DONE")
	if left < 0:
		return tr("HH_TALLY_OVER_ONE") if left == -1 else tr("HH_TALLY_OVER_N") % -left
	return tr("HH_TALLY_ONE") if left == 1 else tr("HH_TALLY_N") % left

func _draw_tally(_t: float, seen: float) -> void:
	var font: Font = CozyTheme.display(700)
	var line := _tally_line()
	var wide := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TALLY_SIZE).x
	var run := TALLY_GLYPH + TALLY_GAP + wide
	var start := size.x * 0.5 - run * 0.5
	var ink: Color = Pal.BAD if _state.flags_left() < 0 and _solved_at < 0.0 else Pal.TEXT
	draw_string(font, Vector2(start + TALLY_GLYPH + TALLY_GAP, _tally_y + font.get_ascent(TALLY_SIZE) * 0.4),
		line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TALLY_SIZE, Color(ink, seen))
	if _tally_face != null:
		var want := Vector2(start, _tally_y - TALLY_GLYPH * 0.5)
		if _tally_face.position != want:
			_tally_face.position = want
		_tally_face.modulate.a = seen

## The toast over the foot of the card, fading in and out over
## Motion.DROP_FADE -- Knight's `_draw_toast`, in the card's own pixels and
## wrapped to the card's width.
func _draw_toast(t: float, shown: Array) -> void:
	if _toast == "":
		return
	var since := t - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE),
		Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var line := tr(_toast)
	if _toast_arg != "":
		line = line % _toast_arg
	var font: Font = CozyTheme.body(600)
	var room := maxf(TOAST_PAD, size.x - 120.0)
	var text_room := room - TOAST_PAD
	var one: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x
	var lines := 1
	var text_w := one
	if one > text_room:
		var wrapped: Vector2 = font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, text_room, TOAST_FONT)
		var lh := font.get_height(TOAST_FONT)
		lines = maxi(1, int(round(wrapped.y / lh)))
		text_w = minf(text_room, wrapped.x)
	var w := minf(room, text_w + TOAST_PAD)
	var h := TOAST_H + float(lines - 1) * font.get_height(TOAST_FONT)
	var key := "%s|%d|%d" % [line, int(w), lines]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-w, -h) * 0.5, Vector2(w, h), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh() if not b.verts.is_empty() else null
		_toast_mesh_for = key
	if _toast_mesh == null:
		return
	var mid := Vector2(size.x * 0.5, size.y - TOAST_MARGIN - h * 0.5)
	draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var top := mid.y - h * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - w * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		draw_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		draw_multiline_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_CENTER, w - TOAST_PAD,
			TOAST_FONT, lines, Color(Pal.PAPER, alpha))

func _ring_at(c: int) -> void:
	if Motion.reduce:
		return
	_rings.append({"pos": _centre(c), "at": _now()})
	_busy_for(Motion.RING_TIME)

# --- input ---

## A touch resolves on release; a press held LONG_PRESS fires the other
## chip's action at once and the release is then ignored.
func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		var c := _cell_at(event.position)
		if event.pressed:
			_press_cell = c
			_long_fired = false
			_press_id += 1
			var id := _press_id
			if c >= 0:
				_later(LONG_PRESS, func():
					if id == _press_id and _press_cell == c and not _long_fired:
						_long_fired = true
						_act(c, State.FLAG if brush == State.RAKE else State.RAKE))
			return
		var was := _press_cell
		_press_cell = -1
		_press_id += 1
		if _long_fired or c < 0 or c != was:
			return
		_act(c, brush)

## The tray armed a chip.
func set_brush(v: int) -> void:
	brush = v

# --- the sprout's line and the toast ---

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

## An explanation of what just happened: the sprout's line (which no screen
## shows since the tip card left every board) and the toast, which one does.
func _tell(key: String, mood: int, arg := "") -> void:
	_say(tr(key) % arg if arg != "" else tr(key), mood)
	_toast = key
	_toast_arg = arg
	_toast_at = _now()
	queue_redraw()

func _cycle_tip() -> void:
	if is_done() or _state.can_undo():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return _state.can_undo() and not is_done()

## Takes back the last gesture: its cells' piles pop back in, back to front;
## its flag pops in or out. A woken hedgehog stays awake.
func undo() -> bool:
	if is_done():
		return false
	var u: Dictionary = _state.undo()
	if u.is_empty():
		return false
	var t := _now()
	var raked: PackedInt32Array = u.raked
	for i in raked.size():
		var c := raked[i]
		var at := t + (0.0 if Motion.reduce else float(raked.size() - 1 - i) * UNDO_STEP)
		_cover_at[c] = at
		_blow_at[c] = -100.0
		_touch(c, at + Motion.POP_IN)
	for f: Array in u.flags:
		var c: int = f[0]
		if int(f[1]) == 1:
			_flag_at[c] = t
			_touch(c, t + Motion.POP_IN)
		else:
			_unflag_at[c] = t
			_touch(c, t + FLAG_OUT)
	fx.cue("undo")
	_tell("HH_UNDONE", Face.Expr.HAPPY)
	moved.emit()
	_refresh()
	return true

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## The next thing logic can prove from what the player can see: a bare cell
## raked, else a hedgehog flagged and pinned.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or _now() < _busy_until:
		return false
	var step: Dictionary = _state.hint_step()
	if step.is_empty():
		return false
	hints_used += 1
	var c: int = step.cell
	if step.kind == "rake" and _state.flag[c] == 1:
		_unflag_at[c] = _now()
	var r: Dictionary = _state.apply_hint(step)
	_ring_at(c)
	fx.cue("hint")
	if String(r.kind) == "pinned":
		_flag_at[c] = _now()
		_touch(c, _now() + Motion.POP_IN)
		_tell("HH_HINT_FLAG", Face.Expr.HAPPY)
		_after_move()
	else:
		_show_rake(r, c)
		_tell("HH_HINT_RAKE", Face.Expr.HAPPY)
	return true

## Every wrong flag's pennant turns rose and shivers, and holds until the
## next move. Counts a check.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong: PackedInt32Array = _state.check()
	var t := _now()
	for c in wrong:
		_bump_at[c] = t
		_touch(c, t + Motion.SHIVER_TIME)
	_still = null
	if wrong.is_empty():
		_tell("HH_CHECK_OK", Face.Expr.JOY)
		fx.cue("check_ok")
	else:
		_tell("HH_CHECK_ONE" if wrong.size() == 1 else "HH_CHECK_N", Face.Expr.STRAIN,
			"" if wrong.size() == 1 else str(wrong.size()))
		fx.cue("check")
	_refresh()
	return wrong.size()

## Back to the opening, the piles popping back in out from it; woken
## hedgehogs and a hint's flags stay.
func reset_board() -> void:
	var before: PackedByteArray = _state.flag.duplicate()
	var covered: PackedInt32Array = _state.reset_board()
	var t := _now()
	var start: int = _state.g.start
	var cols: int = _state.cols()
	for c in covered:
		var d := absi(c % cols - start % cols) + absi(c / cols - start / cols)
		var at := t + (0.0 if Motion.reduce else Motion.stagger(d, Motion.RESET_STAGGER))
		_cover_at[c] = at
		_blow_at[c] = -100.0
		_touch(c, at + Motion.POP_IN)
	for c in _state.size():
		if before[c] == 1 and _state.flag[c] == 0:
			_unflag_at[c] = t
			_touch(c, t + FLAG_OUT)
	_last = start
	moves = 0
	_running = true
	_tell("HH_RESET", Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

func is_solved() -> bool:
	return _state.is_solved()

## The day's shape, never its answer, and how many woke.
func share_glyphs() -> String:
	var tail := tr("HH_SHARE_NONE") if _state.woken == 0 else (tr("HH_SHARE_ONE") if _state.woken == 1
		else tr("HH_SHARE_N") % _state.woken)
	return _state.share_glyphs() + "\n" + tail

# --- the win ---

func flat_win() -> Dictionary:
	var faces: Array = []
	for i in 3:
		faces.append(HedgehogFace.new())
	var sub := tr("HH_WIN_NONE") if _state.woken == 0 else (tr("HH_WIN_WOKE_ONE") if _state.woken == 1
		else tr("HH_WIN_WOKE_N") % _state.woken)
	return {"faces": faces, "subtitle": sub}

## The wave's length: the farthest sleeper from the last rake.
func _wave_span() -> float:
	var cols: int = _state.cols()
	var far := 0
	for c in _state.size():
		if _state.is_hog(c) and _state.woke[c] == 0:
			far = maxi(far, maxi(absi(c % cols - _last % cols), absi(c / cols - _last / cols)))
	return Motion.stagger(far, Motion.WAVE_STEP * 2.0)

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_LEAD + _wave_span() + WIN_WAIT

## Every sleeper's leaves blow off in a wave out of the last cell raked, and
## each hedgehog pops up awake and hops; the woken ones cheer up too.
func _on_solved() -> void:
	var t := _now()
	_solved_at = t
	_tip_timer.stop()
	var cols: int = _state.cols()
	for c in _state.size():
		if not _state.is_hog(c):
			continue
		if _state.woke[c] == 1:
			var woken_face: Control = _faces.get(c)
			if woken_face != null:
				woken_face.expression = Face.Expr.JOY
			continue
		var d := maxi(absi(c % cols - _last % cols), absi(c / cols - _last / cols))
		var delay := 0.0 if Motion.reduce else WIN_LEAD + Motion.stagger(d, Motion.WAVE_STEP * 2.0)
		_blow_at[c] = t + delay
		_blow_from[c] = _last
		_touch(c, t + delay + LEAF_TIME)
		var face := _face_at(c, Face.Expr.JOY)
		Motion.pop_in(face, Motion.POP_IN, delay)
		Motion.hop(face, -_cell * 0.12, 0.4, delay + 0.15)
	if not Motion.reduce:
		_later(WIN_LEAD, func():
			fx.sparkle(_centre(_last), Pal.SUN)
			fx.cue("solved"))
	else:
		fx.cue("solved")
	_say(tr("HH_WIN_NONE") if _state.woken == 0 else tr("HH_TIP_WOKE"), Face.Expr.JOY)
	_refresh()

## A reopened daily that was already solved: every bare cell raked and every
## hedgehog awake on it. Never check_solved(): `solved` must not fire twice.
func restore_completed_board() -> void:
	for c in _state.size():
		if not _state.is_hog(c):
			_state.open[c] = 1
	_state.history = []
	var t := _now()
	_solved_at = t - 100.0
	_opened = t - 100.0
	_blow_at.fill(-100.0)
	_moving = {}
	for c in _state.size():
		if _state.is_hog(c):
			_face_at(c, Face.Expr.JOY)
	_tip_timer.stop()
	_say(tr("HH_WIN_NONE"), Face.Expr.JOY)
	_still = null
	_refresh()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
```

- [ ] **Step 2: Add the registry entry**

In `ui/registry.gd`, after Knight's entry (the dictionary whose `"id"` is `"knight"`, closing with `},` just before the `]` that ends `PUZZLES`), insert:

```gdscript
	{
		"id": "hedgehogs",
		"kind": "puzzle",
		"title": "Hedgehogs",
		"blurb": "HH_BLURB",
		"short": "HH_SHORT",
		"motto": "HH_MOTTO",
		"footer": "Rake · Count · Flag",
		# Mushroom Patch's rows: the two-chip tray (Rake, Flag) and the
		# actions row (Reset, Check); Undo and Hint ride in the top bar.
		"script": "res://puzzles/hedgehogs2d.gd",
		"shell": "flat",
		"tray": "lawn",
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each lawn (hedgehogs_gen.gd's BANDS) is its own
		# daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "HH_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "HH_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "HH_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "HH_LVL_3"},
		],
	},
```

- [ ] **Step 3: Add the strings**

Append to `locale/boards.csv` (columns: keys, en, pt, es; make sure the file ends in a newline before appending):

```csv
TRAY_RAKE,Rake,Rastelo,Rastrillo
TRAY_FLAG,Flag,Bandeira,Bandera
HH_TIP_RAKE,Rake a pile. The number is how many hedgehogs sleep around it.,Rastele um monte. O número diz quantos ouriços dormem em volta.,Rastrilla un montón. El número dice cuántos erizos duermen alrededor.
HH_TIP_NUMBER,"A number counts the eight cells touching it, corners too.","Um número conta as oito casas em volta, cantos também.","Un número cuenta las ocho casillas que lo tocan, esquinas incluidas."
HH_TIP_FLAG,Flag a pile a hedgehog must be under. A flag keeps the rake off.,Marque com bandeira o monte onde um ouriço tem de estar. A bandeira segura o rastelo.,Marca con bandera el montón donde debe haber un erizo. La bandera frena el rastrillo.
HH_TIP_CHORD,Tap a number whose flags are all laid to rake the rest around it.,Toque num número com todas as bandeiras postas para rastelar o resto em volta.,Toca un número con todas sus banderas puestas para rastrillar el resto alrededor.
HH_TIP_WOKE,A wrong rake only wakes a hedgehog. It curls up grumpy and you carry on.,Rastelar errado só acorda um ouriço. Ele se enrola emburrado e você segue.,Rastrillar mal solo despierta a un erizo. Se enrolla gruñón y sigues.
HH_WOKE_FIRST,Oh! You woke a hedgehog. It curls up grumpy. Carry on.,Ops! Você acordou um ouriço. Ele se enrolou emburrado. Siga em frente.,¡Uy! Despertaste a un erizo. Se enrolla gruñón. Sigue adelante.
HH_WOKE_AGAIN,Another one woke up grumpy.,Mais um acordou emburrado.,Otro se despertó gruñón.
HH_FLAGGED,A flag keeps the rake off. Lift it first.,A bandeira segura o rastelo. Tire-a primeiro.,La bandera frena el rastrillo. Quítala primero.
HH_PINNED,A hint put that flag there.,Uma dica pôs essa bandeira aí.,Una pista puso esa bandera ahí.
HH_CHORD_FEW,Flag every hedgehog around this number first.,Marque primeiro todos os ouriços em volta deste número.,Marca primero todos los erizos alrededor de este número.
HH_CHORD_MANY,Too many flags around this number.,Bandeiras demais em volta deste número.,Demasiadas banderas alrededor de este número.
HH_UNDONE,One move taken back.,Um lance desfeito.,Una jugada deshecha.
HH_RESET,Back to the first patch.,De volta ao primeiro pedaço.,De vuelta al primer claro.
HH_HINT_RAKE,That one must be bare: raked.,Esse só pode estar vazio: rastelado.,Ese tiene que estar vacío: rastrillado.
HH_HINT_FLAG,A hedgehog must sleep there: flagged.,Um ouriço tem de dormir ali: marcado.,Ahí tiene que dormir un erizo: marcado.
HH_CHECK_OK,Every flag is right so far.,Todas as bandeiras estão certas até aqui.,Todas las banderas están bien por ahora.
HH_CHECK_ONE,One flag has no hedgehog under it.,Uma bandeira não tem ouriço embaixo.,Una bandera no tiene erizo debajo.
HH_CHECK_N,%s flags have no hedgehog under them.,%s bandeiras não têm ouriço embaixo.,%s banderas no tienen erizo debajo.
HH_TALLY_ONE,1 hedgehog asleep,1 ouriço dormindo,1 erizo dormido
HH_TALLY_N,%d hedgehogs asleep,%d ouriços dormindo,%d erizos dormidos
HH_TALLY_OVER_ONE,1 flag too many,1 bandeira a mais,1 bandera de más
HH_TALLY_OVER_N,%d flags too many,%d bandeiras a mais,%d banderas de más
HH_TALLY_DONE,Every hedgehog is awake,Todos os ouriços acordaram,Todos los erizos despertaron
HH_WIN_NONE,Not one hedgehog woke.,Nenhum ouriço acordou.,Ningún erizo se despertó.
HH_WIN_WOKE_ONE,One hedgehog woke up grumpy.,Um ouriço acordou emburrado.,Un erizo se despertó gruñón.
HH_WIN_WOKE_N,%d hedgehogs woke up grumpy.,%d ouriços acordaram emburrados.,%d erizos se despertaron gruñones.
HH_SHARE_NONE,Not one hedgehog woke.,Nenhum ouriço acordou.,Ningún erizo se despertó.
HH_SHARE_ONE,1 hedgehog woke.,1 ouriço acordou.,1 erizo se despertó.
HH_SHARE_N,%d hedgehogs woke.,%d ouriços acordaram.,%d erizos se despertaron.
HH_RULES,"Hedgehogs sleep under some of the leaf piles. Rake a pile and the grass under it shows how many hedgehogs sleep in the eight cells touching it; a pile with none around it rakes its neighbours too. Flag a pile a hedgehog must be under, and the rake leaves it alone. Tap a number whose flags are all laid to rake the rest around it, and hold a pile to use the other tool. Rake every pile with no hedgehog under it to finish. Rake a hedgehog by mistake and it only wakes up grumpy: nothing is lost.","Ouriços dormem sob alguns montes de folhas. Rastele um monte e a grama embaixo mostra quantos ouriços dormem nas oito casas em volta; um monte sem nenhum em volta rastela os vizinhos também. Marque com bandeira o monte onde um ouriço tem de estar, e o rastelo o deixa em paz. Toque num número com todas as bandeiras postas para rastelar o resto em volta, e segure um monte para usar a outra ferramenta. Rastele todos os montes sem ouriço para terminar. Rastele um ouriço por engano e ele só acorda emburrado: nada se perde.","Hay erizos durmiendo bajo algunos montones de hojas. Rastrilla un montón y la hierba de debajo muestra cuántos erizos duermen en las ocho casillas que lo tocan; un montón sin ninguno alrededor rastrilla también a sus vecinos. Marca con bandera el montón donde debe haber un erizo, y el rastrillo lo deja en paz. Toca un número con todas sus banderas puestas para rastrillar el resto alrededor, y mantén pulsado un montón para usar la otra herramienta. Rastrilla todos los montones sin erizo para terminar. Si rastrillas un erizo por error, solo se despierta gruñón: no se pierde nada."
HH_BLURB,Rake the leaves and let the sleeping hedgehogs lie.,Rastele as folhas e deixe os ouriços dormirem.,Rastrilla las hojas y deja dormir a los erizos.
HH_SHORT,"Rake the leaves,\nlet them sleep.","Rastele as folhas,\ndeixe-os dormir.","Rastrilla las hojas,\ndéjalos dormir."
HH_MOTTO,Let sleeping ones lie,Deixe quem dorme dormir,Deja dormir a quien duerme
HH_LVL_0,"8 × 10 lawn, 12 hedgehogs","Gramado 8 × 10, 12 ouriços","Césped 8 × 10, 12 erizos"
HH_LVL_1,"9 × 11 lawn, 17 hedgehogs","Gramado 9 × 11, 17 ouriços","Césped 9 × 11, 17 erizos"
HH_LVL_2,"10 × 11 lawn, 21 hedgehogs","Gramado 10 × 11, 21 ouriços","Césped 10 × 11, 21 erizos"
HH_LVL_3,"10 × 11 lawn, 24 hedgehogs","Gramado 10 × 11, 24 ouriços","Césped 10 × 11, 24 erizos"
```

Then run `godot --headless --path . --import` once, so the new keys translate.

- [ ] **Step 4: Parse check and the suite**

Run: `godot --headless --check-only --path . --script puzzles/hedgehogs2d.gd`, then `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -5`.

Expected:
- no parse error;
- the suite's last line reports `failed=0`. The registry guard now loads `hedgehogs2d.gd`; a new failure naming `hedgehogs` is this task's to fix.

- [ ] **Step 5: First windowed shot**

`git add -A && git commit -m "wip(hedgehogs): board before first shot"` first (the `project.godot` trap). Then run:

`godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_anim.gd -- hedgehogs empty`

Expected: `idle frames=... max_draw_calls=` near **79** (the planning run's figure).

Look at `/tmp/anim_hedgehogs_1.png` (mid-gust) and `/tmp/anim_hedgehogs_5.png` (settled). Crop with PIL from the repo directory. Check:
- the lawn is centred under the tally ("17 ... asleep" on Medium);
- the piles sit in their cells;
- the opening is raked with coloured numbers;
- the tray shows the Rake chip armed and the Flag chip;
- the actions row shows Reset and Check.

Fix anything that reads wrong against the mock before going on.

- [ ] **Step 6: The review-focus drive (throwaway)**

`tests/_tmp_drive_hedgehogs.gd`:

```gdscript
extends SceneTree

## Hedgehogs' board driven headless through the review focus (throwaway).
## Real time passes between phases, since the board's timers are real.
const B := preload("res://puzzles/hedgehogs2d.gd")
var board
var fails := 0
var solved_n := 0
var phase := 0
var t0 := 0.0
var pair := PackedInt32Array()
var long_cell := -1
var chord_hog := -1

func ok(c: bool, w: String) -> void:
	if not c:
		fails += 1
		print("FAIL ", w)

func _initialize() -> void:
	board = B.new()
	board.size = Vector2(1000, 1180)
	root.add_child(board)

func now() -> float:
	return Time.get_ticks_msec() / 1000.0

func deal(seed: int, d: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	board.start(rng, d)
	board._busy_until = -100.0

func touch(c: int, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = pressed
	ev.position = board.cell_to_local(c / board._state.cols(), c % board._state.cols())
	board._gui_input(ev)

func _process(_d: float) -> bool:
	var st = board._state
	match phase:
		0:
			board.solved.connect(func(): solved_n += 1)
			deal(42, 2)
			ok(st.size() == 110 and board._cell > 90.0, "a 10x11 lawn at a cell over 90 (%f)" % board._cell)
			# 1. two rakes in one frame, mid-gust
			for c in st.size():
				if not st.is_hog(c) and st.open[c] == 0 and pair.size() < 2:
					var probe: PackedByteArray = st.open.duplicate()
					if st.Gen.flood(st.g, probe, c).size() > 0:
						board._act(c, st.RAKE)
						pair.append(c)
			ok(pair.size() == 2 and st.open[pair[0]] == 1 and st.open[pair[1]] == 1, "two rakes in one frame both taken")
			t0 = now()
			phase = 1
		1:
			if now() - t0 < 1.5:
				return false
			board._draw()
			ok(board._moving.is_empty(), "every gust settled")
			ok(board._still != null, "the still mesh rebuilt")
			for c in st.size():
				if st.open[c] == 1:
					ok(board._shows_raked(c, now()), "cell %d drawn raked" % c)
			# 3. a long press lays a flag (rake armed) and the release does nothing more
			for c in st.size():
				if st.open[c] == 0 and st.flag[c] == 0 and st.woke[c] == 0:
					long_cell = c
					break
			touch(long_cell, true)
			t0 = now()
			phase = 2
		2:
			if now() - t0 < 0.55:
				return false
			touch(long_cell, false)
			ok(st.flag[long_cell] == 1 and st.open[long_cell] == 0 and st.woke[long_cell] == 0,
				"a long press flags once and the release does not rake")
			# a quick tap never fires the long press
			var quick := -1
			for c in st.size():
				if not st.is_hog(c) and st.open[c] == 0 and st.flag[c] == 0:
					quick = c
					break
			touch(quick, true)
			touch(quick, false)
			ok(st.open[quick] == 1, "a quick tap rakes")
			long_cell = quick
			t0 = now()
			phase = 3
		3:
			if now() - t0 < 0.55:
				return false
			ok(st.flag[long_cell] == 0, "the quick tap's long press never fired")
			# 2. a chord over a wrong flag wakes one; undo keeps it awake with its face
			deal(3, 0)
			for c in st.size():
				if st.open[c] == 1 and st.number(c) == 1:
					var hog_n := -1
					var bare_n := -1
					for n2: int in st.g.nb[c]:
						if st.open[n2] == 0:
							if st.is_hog(n2):
								hog_n = n2
							elif bare_n < 0:
								bare_n = n2
					if hog_n < 0 or bare_n < 0:
						continue
					board._act(bare_n, st.FLAG)
					board._act(c, st.RAKE)
					chord_hog = hog_n
					break
			ok(chord_hog >= 0 and st.woken == 1 and board._faces.has(chord_hog), "a wrong-flag chord wakes one, seated")
			var had_undo: bool = st.can_undo()
			if had_undo:
				board.undo()
			ok(st.woken == 1 and st.woke[chord_hog] == 1 and board._faces.has(chord_hog), "undo keeps the woken and its face")
			# the rest: check, reset, hints to the solve, restore
			deal(42, 2)
			var bare := -1
			for c in st.size():
				if not st.is_hog(c) and st.open[c] == 0:
					bare = c
					break
			board._act(bare, st.FLAG)
			board._act(bare, st.RAKE)
			ok(st.open[bare] == 0, "a flag refuses the rake")
			ok(board.check() == 1 and st.wrong[bare] == 1, "check marks the wrong flag")
			ok(board.undo() and st.flag[bare] == 0 and st.wrong[bare] == 0, "undo lifts it and clears the mark")
			board.reset_board()
			var guard := 0
			while not board.is_done() and guard < 400:
				guard += 1
				if st.hint_step().is_empty():
					break
				board.hints_used = 0
				board.hint()
			ok(board.is_done() and solved_n == 1 and st.woken == 0, "hints solve, nothing woken, solved once (%d)" % solved_n)
			ok(board.flat_win().faces.size() == 3 and board.win_delay() > 0.0, "the win's faces and wait")
			t0 = now()
			phase = 4
		4:
			if now() - t0 < 1.0:
				return false
			board.restore_completed_board()
			ok(solved_n == 1, "restore does not fire solved again")
			var faces := 0
			for c in st.size():
				if st.is_hog(c):
					faces += 1 if board._faces.has(c) else 0
			ok(faces == int(st.g.k), "every hedgehog seated on restore")
			print("DRIVE %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
			return true
	return false
```

Run: `godot --headless --path . --script tests/_tmp_drive_hedgehogs.gd 2>&1 | grep -e FAIL -e DRIVE`

Expected: `DRIVE PASS (0 failures)` and no `FAIL` line. The "Drawing is only allowed inside this node's `_draw()`" errors come from the drive calling `_draw()` by hand to exercise the mesh builders headless; they are the drive's, not the board's.

- [ ] **Step 7: Delete the drive and commit**

```bash
rm -f tests/_tmp_drive_hedgehogs.gd tests/_tmp_drive_hedgehogs.gd.uid
git reset --soft HEAD~1
git add puzzles/hedgehogs2d.gd puzzles/hedgehogs2d.gd.uid ui/registry.gd locale/boards.csv
git status --short   # project.godot must not be listed; if it is: git checkout project.godot
git commit -m "feat(hedgehogs): the board -- the gust, the numbers, flags, the woken, the chord, the win wave"
```

---

### Task 5: The harness hooks and the measurements

**Files:**
- Modify: `tests/_win.gd`:
  - `_note` gets a `"hedgehogs"` line after `"knight"`'s;
  - `_solve` gets a `"hedgehogs"` case after `"knight": _solve_knight()`;
  - add `_solve_hedgehogs()` after `_solve_knight()`.
- Modify: `tests/_shot_anim.gd`:
  - a dispatch line after `elif _entry.id == "knight" and not _empty:` / `_tap_knight()`;
  - add `_tap_hedgehogs()` after `_tap_knight()`.

**Interfaces:**
- Consumes: Task 4's `_puzzle._state`, `_puzzle.cell_to_local`, `_puzzle._busy_until`, `_puzzle._layout()`, `_puzzle.hints_used`, `_puzzle.checks`; `_host.top_bar.hint_button`, `_host.action_bar.check_button`.

- [ ] **Step 1: `_win.gd`**

In `_note`, after the `"knight": return ...` entry (it spans three lines, the last `			_puzzle.moves, _puzzle.hints_used, _fit_ok, _hud_ok]`, just before `"pinwheel": return`):

```gdscript
		"hedgehogs": return "%dx%d lawn, %d hedgehogs, woken=%d, hints=%d, checks=%d, board fit=%s, hud=%s" % [
			_puzzle._state.cols(), _puzzle._state.rows(), int(_puzzle._state.g.k), _puzzle._state.woken,
			_puzzle.hints_used, _puzzle.checks, _fit_ok, _hud_ok]
```

In `_solve`'s match, after `"knight": _solve_knight()`:

```gdscript
		"hedgehogs": _solve_hedgehogs()
```

After `func _solve_knight()` ends:

```gdscript
## Hedgehogs: Check spent first on the opening, where nothing is flagged and
## it must find nothing wrong; one hint through the HUD; then every bare cell
## logic proves is raked by real touch with the rake chip the tray arms by
## default. A hedgehog logic proves is flagged through the state, since the
## win never needs a flag.
func _solve_hedgehogs() -> void:
	var st = _puzzle._state
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in st.rows():
		for c in st.cols():
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	_puzzle._busy_until = -100.0
	_press(_host.action_bar.check_button)
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1 and st.woken == 0
	for i in 400:
		if _puzzle.is_done():
			break
		var h: Dictionary = st.hint_step()
		if h.is_empty():
			break
		if h.kind == "flag":
			st.apply_hint(h)
			continue
		var c: int = h.cell
		_tap_local(_puzzle.cell_to_local(c / st.cols(), c % st.cols()))
```

- [ ] **Step 2: `_shot_anim.gd`**

After the Knight dispatch:

```gdscript
		elif _entry.id == "hedgehogs" and not _empty:
			_tap_hedgehogs()
```

After `_tap_knight()` ends:

```gdscript
## Hedgehogs: one real touch, with the rake chip the tray arms by default.
## By default the touch rakes the next cell logic proves bare, so the strip
## catches a gust. `woke` rakes a hedgehog beside the opening instead, so the
## strip catches the rose wash, the curl and the shiver. `solve` rakes
## everything but the last bare cell through the state and touches that one,
## so the strip shows the sleepers' wave and every hedgehog hopping awake.
func _tap_hedgehogs() -> void:
	var st = _puzzle._state
	var target := -1
	if _mode == "woke":
		for c in st.size():
			if st.is_hog(c) and st.woke[c] == 0:
				for r: int in st.g.nb[c]:
					if st.open[r] == 1:
						target = c
						break
			if target >= 0:
				break
	else:
		for i in 400:
			var h: Dictionary = st.hint_step()
			if h.is_empty():
				break
			if h.kind == "flag":
				st.apply_hint(h)
				continue
			if _mode != "solve":
				target = h.cell
				break
			var left := 0
			for c in st.size():
				if not st.is_hog(c) and st.open[c] == 0:
					left += 1
			var probe: PackedByteArray = st.open.duplicate()
			if st.Gen.flood(st.g, probe, h.cell).size() == left:
				target = h.cell
				break
			st.apply_hint(h)
		_puzzle._layout()
	if target < 0:
		return
	_puzzle._busy_until = -100.0
	_tap_global(_puzzle.get_global_transform_with_canvas() * _puzzle.cell_to_local(target / st.cols(), target % st.cols()))
```

`_mode` takes any word from the command line (`_mode = args[i]`), so `woke` needs no registration.

- [ ] **Step 3: Run the win harness**

Commit first, per the `project.godot` trap: `git add -A && git commit -m "wip(hedgehogs): harness hooks"`. Then:

`godot --path . --resolution 810x1440 --always-on-top --script res://tests/_win.gd 2>&1 | grep -i -e hedgehogs -e "passed\|failed"`

Expected: Hedgehogs' line reports solved, the overlay appeared, `board fit=true`, `hud=true` and `woken=0`. Every other board keeps its earlier result.

- [ ] **Step 4: Measure** (one run at a time; two readings each, quote the second)

```
godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_anim.gd -- hedgehogs empty
godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_anim.gd -- hedgehogs
godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_anim.gd -- hedgehogs woke
godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_anim.gd -- hedgehogs solve
godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_shot_anim.gd -- hedgehogs
```

Write down the draw calls and idle ms of each. The planning runs (one reading each, first of the session) read `empty` 79, `woke` 83 and `solve` 115; expect about those. Then:
- look at the frames from `woke`: a rose cell with a curled, frowning hedgehog shivering on it;
- look at the frames from `solve`: leaves blowing off the sleepers in a wave and hedgehogs hopping awake.

`solve` is the heaviest state (up to 24 faces at two layers each), so check it against the 855 budget. Run Mushroom Patch (`-- mushroom`) once in the same session as the control.

- [ ] **Step 5: Commit**

```bash
git reset --soft HEAD~1
git add tests/_win.gd tests/_shot_anim.gd
git status --short   # no project.godot
git commit -m "test(hedgehogs): win and animation harness hooks"
```

---

### Task 6: The card, the sounds' prompts, and the docs

**Files:**
- Modify: `ui/menu/vistas.gd` (`CARDS`: a `"hedgehogs"` row after `"knight"`'s)
- Modify: `ui/menu/card_art.gd`:
  - two preloads and constants;
  - a mesh var;
  - a `_build` match arm and a `_draw` match arm;
  - `_draw_hedgehogs()` at the end.
- Modify: `tools/gen_sfx.py` (a `"hedgehogs"` set after `"knight"`'s)
- Modify: `docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md` (sections 7 and 8, as built)
- Modify: `CLAUDE.md` (a Hedgehogs bullet after Knight's)

- [ ] **Step 1: The vista**

In `ui/menu/vistas.gd`'s `CARDS`, after `"knight": ["meadow", 1.6, Vector2(0.30, 0.60)],`:

```gdscript
	"hedgehogs": ["autumn", 1.6, Vector2(0.60, 0.70)],
```

- [ ] **Step 2: The card picture**

In `ui/menu/card_art.gd`:

- below `const ChessPiece = preload("res://ui/faces/chess_piece.gd")`:

```gdscript
const HedgehogFace = preload("res://ui/faces/hedgehog_face.gd")
const Lawn = preload("res://ui/faces/leaf_pile.gd")
```

- below the `KN_KING` constant:

```gdscript
## Hedgehogs' card: a 6 by 2 strip of the lawn -- raked cells with their
## numbers, three leaf piles (one flagged), and one hedgehog asleep on a
## raked cell. The numbers agree with the two hedgehogs the strip holds (the
## flagged pile and the sleeper), so the card never shows a wrong count.
const HH_CELL := 42.0
const HH_COLS := 6
const HH_ROWS := 2
const HH_ORIGIN := Vector2(-126.0, -42.0)
const HH_PILES := [Vector2i(3, 0), Vector2i(4, 1), Vector2i(5, 1)]
const HH_FLAG := Vector2i(3, 0)
const HH_HOG := Vector2i(4, 0)
const HH_NUMS := {Vector2i(2, 0): 1, Vector2i(5, 0): 1, Vector2i(2, 1): 1, Vector2i(3, 1): 2}
```

- below `var _knight_mesh: ArrayMesh`:

```gdscript
var _hedgehogs_mesh: ArrayMesh
```

- in `_build()`'s match, as a new arm (anywhere among the others, e.g. after `"mushroom":`'s arm ends):

```gdscript
		"hedgehogs":
			# One hedgehog asleep on the raked strip _draw lays under it.
			var hog := HedgehogFace.new()
			hog.expression = Face.Expr.SLEEPY
			_seat(hog, HH_CELL * 1.05, HH_ORIGIN.x + (HH_HOG.x + 0.5) * HH_CELL,
				HH_ORIGIN.y + (HH_HOG.y + 0.5) * HH_CELL)
```

- in `_draw()`'s match, after `"knight": _draw_knight()`:

```gdscript
		"hedgehogs": _draw_hedgehogs()
```

- at the end of the file:

```gdscript
## Hedgehogs: the board's own drawing, through `ui/faces/leaf_pile.gd`, the
## file `puzzles/hedgehogs2d.gd` draws with, so the card and the board cannot
## drift apart. One mesh, then the numbers as text.
## Spec: docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md, section 4.
func _draw_hedgehogs() -> void:
	var cell := HH_CELL * _u
	var b := Face.Builder.new()
	for r in HH_ROWS:
		for c in HH_COLS:
			var p := Vector2i(c, r)
			var centre := at(HH_ORIGIN.x + (float(c) + 0.5) * HH_CELL, HH_ORIGIN.y + (float(r) + 0.5) * HH_CELL)
			var id := r * HH_COLS + c
			var covered := HH_PILES.has(p)
			Lawn.ground(b, centre, cell, id, not covered, false)
			if covered:
				Lawn.pile(b, centre, cell, id, 0.0, Vector2.UP, Vector2.ONE, 0.45 if p == HH_FLAG else 1.0)
	var fc := at(HH_ORIGIN.x + (float(HH_FLAG.x) + 0.5) * HH_CELL, HH_ORIGIN.y + (float(HH_FLAG.y) + 0.5) * HH_CELL)
	Lawn.flag(b, fc, cell * 0.46)
	_hedgehogs_mesh = b.mesh()
	draw_mesh(_hedgehogs_mesh, null)
	for p: Vector2i in HH_NUMS:
		var n: int = HH_NUMS[p]
		_text(str(n), HH_ORIGIN.x + (float(p.x) + 0.5) * HH_CELL, HH_ORIGIN.y + (float(p.y) + 0.5) * HH_CELL + HH_CELL * 0.19,
			HH_CELL * 0.54, Pal.NUM_INK[n])
```

Check it: commit first (the `project.godot` trap), then `godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_menu.gd -- page3`. At 810x1440 it is the eighth card of page three, beside Knight (a planning run read that page at 175 draw calls). The picture is saved as `/tmp/shot_menu_page2.png`, the script's one name for the turned page. Look at the Hedgehogs card:
- an autumn banner;
- a lawn strip with sage piles and pale raked cells;
- a flag with a sun pennant;
- the numbers 1, 1, 1, 2;
- a sleeping hedgehog.

Its go button is whatever `Pal.CAT` colour its index draws (grey at 24 cards). That is `ui/menu.gd`'s cycle and not this card's to change.

- [ ] **Step 3: The sounds' prompts**

In `tools/gen_sfx.py`'s `SETS`, after the `"knight": {...},` block:

```python
    # Hedgehogs: rake autumn leaf piles off a lawn; hedgehogs sleep under
    # some. A wrong rake wakes one, grumpy -- a snuffle, never a buzzer.
    "hedgehogs": {
        "rake":     ("a short soft sweep of a rake through dry autumn leaves, cozy, very short", 0.4, -10),
        "gust":     ("a soft airy flurry of dry leaves blown off a lawn by a light breeze, cozy", 0.8, -9),
        "flag":     ("a small wooden twig pushed softly into a pile of dry leaves, very short", 0.3, -10),
        "unflag":   ("a small twig pulled out of dry leaves with a tiny rustle, very short", 0.3, -11),
        "woke":     ("a tiny grumpy hedgehog snuffle and huff, then a soft gentle two-note downward marimba, cute, never harsh", 0.9, -9),
        "chord":    ("two quick soft rake sweeps through dry leaves, very short", 0.5, -10),
        "refuse":   ("a tiny soft muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "check":    ("a soft two-note downward kalimba, gentle, not yet", 0.6, -9),
        "check_ok": ("a soft bright three-note rising kalimba, all good", 0.7, -8),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a soft rustle of leaves settling back onto a lawn, gentle", 1.0, -8),
        "solved":   ("a warm celebratory marimba run rising with a soft leaf flurry and tiny happy squeaks, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy rustle of autumn leaves settling onto grass", 1.0, -9),
    },
```

Do not run the generator.

- [ ] **Step 4: Amend the spec to what shipped**

In `docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md`:

- **Section 7.** If anything was changed while fixing Task 4 step 5's shot, say what and why (the mock stays the reference; record the difference).
- **Section 8.** Replace the "Filled in at build" list with the figures from Task 1 step 3 and Task 5 step 4:
  - the generator's worst case per level;
  - draw calls bare, raked, woke and solve;
  - ANGLE's count and pixel agreement;
  - the reduce-motion pair;
  - the Mushroom Patch control.

- [ ] **Step 5: CLAUDE.md**

After the `- **Knight is the twenty-third card** ...` bullet (it ends `...rewinds to the last one that still has a line (\`KN_REWOUND\`).`), add:

```markdown
- **Hedgehogs is the twenty-fourth card** (2026-09-26,
  `puzzles/hedgehogs2d.gd`, spec `2026-09-26-hedgehogs-flat-design.md`, mock
  `docs/brainstorm/concepts.html#hedgehogs`). Rake an autumn lawn's leaf
  piles; a number counts the hedgehogs asleep in the eight cells round it,
  a nought blows its neighbours clear, and a wrong rake only wakes one up
  grumpy (`woken`, on the win screen and the share line). It is the
  dig-and-flag game Mushroom Patch was drawn *away* from, off the same
  reference; **it is called Hedgehogs**. Two things travel: **a proof that
  plays the day out from its opening is also its uniqueness** --
  `hedgehogs_gen.gd`'s `prove` rakes every bare cell by singles, subsets and
  the count, never guessing, so no separate second-answer search is asked --
  and **a board whose moves all resolve in the state at once needs no input
  lock**: every cell carries its own gust timers, so a tap mid-gust is taken
  and the drawing still lands on the state. Its drawings are
  `ui/faces/leaf_pile.gd` (shared with the tray and the card) and
  `ui/faces/hedgehog_face.gd`. <draw calls from Task 5>, ANGLE agreeing.
  Sounds are prompts in `tools/gen_sfx.py`, not yet generated.
```

Replace `<draw calls from Task 5>` with the measured figures, e.g. `NN draw calls bare, NN on the win wave`.

- [ ] **Step 6: The suite, then commit**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -3`
Expected: `failed=0`.

```bash
git add ui/menu/vistas.gd ui/menu/card_art.gd tools/gen_sfx.py docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md CLAUDE.md
git status --short   # no project.godot
git commit -m "feat(hedgehogs): the card, the sounds' prompts, the spec's figures and CLAUDE.md"
```
