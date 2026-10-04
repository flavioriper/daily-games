extends RefCounted

## Peapod as pure data (spec
## docs/superpowers/specs/2026-10-04-arcade-peapod-design.md): a pea cannon
## on a cart at the foot of a garden, firing on its own, and numbered crates
## coming down on it. The screen (arcade/peapod_screen.gd) sets `target_x`
## (or `axis`), calls `step()` at the fixed DT and drains `events`.
##
## The rules of the genre, kept: the cannon only slides and never stops
## firing; a crate takes as many peas as its number; gift crates drop a
## token that must be caught (one more pea a volley, a quicker gun, a
## heavier pea, a helper cart for a while); a firecracker crate takes its
## neighbours with it; and whatever reaches the cart's line ends the run.
## Two waves of crates in a wall, five across, then one of a millipede
## winding down a path -- every plate a number, the head worth six of them,
## and a plate shot off knocks the whole of it back.

enum Phase { READY, PLAY, OVER }
enum Wave { WALL, MILLI }
## What a crate or a plate is. PEA to TWIN are the gifts.
enum Kind { CRATE, GOLD, BOMB, PEA, RATE, POWER, TWIN, HEAD }

const DT := 1.0 / 60.0
const W := 300.0
const H := 460.0
const COLS := 5
const CELL_W := W / COLS
const CELL_H := 40.0
## The grass the cart stands on, the cart's axle and the line nothing may
## reach.
const GROUND := 432.0
const CART_Y := 414.0
const DANGER := 380.0
const CART_HALF := 22.0
const CART_SPEED := 1400.0
const READY_TIME := 1.6
const GAP_TIME := 1.5
const PEA_SPEED := 540.0
const PEA_GAP := 7.5
const MAX_PEAS := 5
const MAX_RATE := 8
const TWIN_TIME := 12.0
const TWIN_OFF := 58.0
const TOKEN_FALL := 120.0
const CATCH := 30.0
## A wall still high up comes down quickly, so a cleared sky never waits.
const RUSH_Y := 150.0
const RUSH := 5.0
const GOLD_WORTH := 5
## The millipede's path: rows ROW apart between X0 and X1, a half circle at
## each end, entered from off the left edge.
const PATH_FROM := -26.0
const X0 := 40.0
const X1 := W - 40.0
const Y0 := 34.0
const ROW := 46.0
const TURN_R := ROW * 0.5
const PATH_ROWS := 8
const SPACING := 31.0
const SEG_R := 15.0
const HEAD_R := 19.0
const HEAD_WORTH := 6
const KNOCK := 16.0
const CATCH_UP := 5.0
## Kills this close together are one streak.
const STREAK_GAP := 0.7

var rng := RandomNumberGenerator.new()
var phase := Phase.READY
var phase_t := 0.0
var t := 0.0
var score := 0
var wave := 0
var wave_kind := Wave.WALL
## Seconds until the next wave is dealt (0: one is on).
var gap_t := 0.0
var x := W * 0.5
## Where the finger wants the cart (NAN: where it is), or the keys' axis.
var target_x := NAN
var axis := 0.0
## The gun: peas a volley, the rate's level, a pea's weight, and the
## helper's seconds left and where it stands.
var peas := 1
var rate_lv := 0
var power := 1
var twin_t := 0.0
var twin_x := W * 0.5
var _cool := 0.0
var shots: Array = []
## Falling gifts: {kind, x, y, vy, id}.
var tokens: Array = []
## The wall, lowest row first: each row COLS cells, null or {kind, hp, max,
## id}. `wall_y` is the lowest row's bottom edge.
var rows: Array = []
var wall_y := 0.0
var wall_speed := 8.0
## The millipede, head first: {kind, hp, max, s, id, dying}.
var segs: Array = []
var milli_speed := 24.0
var _push := 0.0
var events: Array = []
var kills := 0
var caught := 0
var fired := 0
var streak := 0
var best_streak := 0
var _streak_t := 0.0
var _warned := false
var _next_id := 1

func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	events.append({"type": "ready"})

func is_over() -> bool:
	return phase == Phase.OVER

## Volleys a second.
func rate() -> float:
	return 5.0 + 0.6 * rate_lv

## A crate's number on wave `w`, before its row and its luck.
static func hp_base(w: int) -> float:
	return 2.4 * pow(1.45, mini(w, 10) - 1) * pow(1.25, maxi(0, w - 10))

static func path_len() -> float:
	return (X1 - PATH_FROM) + (PATH_ROWS - 1) * (PI * TURN_R + X1 - X0)

## The path at `s` along it.
static func path_at(s: float) -> Vector2:
	var first := X1 - PATH_FROM
	if s <= first:
		return Vector2(PATH_FROM + s, Y0)
	s -= first
	var straight := X1 - X0
	var leg := PI * TURN_R + straight
	var k := mini(int(s / leg), PATH_ROWS - 2)
	var r := s - k * leg
	var right := k % 2 == 0
	var top := Y0 + k * ROW
	if r < PI * TURN_R:
		var a := r / TURN_R
		var out := sin(a) * TURN_R
		return Vector2(X1 + out if right else X0 - out, top + TURN_R - cos(a) * TURN_R)
	r = minf(r - PI * TURN_R, straight)
	return Vector2(X1 - r if right else X0 + r, top + ROW)

## How near the end is, 0 (far) to 1 (on the line): the screen's warning.
func danger() -> float:
	if phase != Phase.PLAY:
		return 0.0
	if wave_kind == Wave.WALL:
		if rows.is_empty():
			return 0.0
		return clampf((wall_y - (DANGER - 110.0)) / 110.0, 0.0, 1.0)
	if segs.is_empty():
		return 0.0
	var left: float = path_len() - float(segs[0].s)
	return clampf(1.0 - left / 420.0, 0.0, 1.0)

## Where a cell's centre is.
func cell_pos(row: int, col: int) -> Vector2:
	return Vector2((col + 0.5) * CELL_W, wall_y - (row + 0.5) * CELL_H)

func step() -> void:
	phase_t += DT
	match phase:
		Phase.READY:
			_move()
			if phase_t >= READY_TIME:
				phase = Phase.PLAY
				phase_t = 0.0
				events.append({"type": "go"})
				_deal()
		Phase.PLAY:
			t += DT
			_move()
			_fire()
			_step_shots()
			_step_tokens()
			if gap_t > 0.0:
				gap_t -= DT
				if gap_t <= 0.0:
					gap_t = 0.0
					_deal()
			elif wave_kind == Wave.WALL:
				_step_wall()
			else:
				_step_milli()
			_streak_t -= DT
			if _streak_t <= 0.0:
				streak = 0
			var d := danger()
			if d > 0.35 and not _warned:
				_warned = true
				events.append({"type": "warn"})
			elif d < 0.15:
				_warned = false
		Phase.OVER:
			_step_shots()

func _move() -> void:
	var want := x
	if not is_nan(target_x):
		want = target_x
	elif axis != 0.0:
		want = x + axis * 260.0 * DT
	x = move_toward(x, clampf(want, CART_HALF, W - CART_HALF), CART_SPEED * DT)
	if twin_t > 0.0:
		twin_t -= DT
		var side := -1.0 if x + TWIN_OFF > W - CART_HALF else 1.0
		if x - TWIN_OFF < CART_HALF:
			side = 1.0
		elif twin_x < x and x - TWIN_OFF >= CART_HALF and x + TWIN_OFF <= W - CART_HALF:
			# it keeps the side it is on while there is room
			side = -1.0
		twin_x = move_toward(twin_x, x + side * TWIN_OFF, 520.0 * DT)
		if twin_t <= 0.0:
			twin_t = 0.0
			events.append({"type": "twin_off", "x": twin_x})

func _fire() -> void:
	_cool -= DT
	if _cool > 0.0:
		return
	_cool += 1.0 / rate()
	_volley(x)
	events.append({"type": "shot", "x": x, "n": peas})
	if twin_t > 0.0:
		_volley(twin_x)
	fired += 1

func _volley(from: float) -> void:
	for i in peas:
		shots.append({"x": from + (i - (peas - 1) * 0.5) * PEA_GAP, "y": CART_Y - 34.0})

func _step_shots() -> void:
	var keep: Array = []
	for p: Dictionary in shots:
		p.y -= PEA_SPEED * DT
		if p.y < -8.0:
			continue
		if phase == Phase.PLAY and gap_t <= 0.0 and _strike(p):
			continue
		keep.append(p)
	shots = keep

## A pea against whatever is over it. True when it landed.
func _strike(p: Dictionary) -> bool:
	if wave_kind == Wave.WALL:
		if p.y > wall_y or rows.is_empty():
			return false
		var r := int((wall_y - float(p.y)) / CELL_H)
		var c := clampi(int(float(p.x) / CELL_W), 0, COLS - 1)
		if r >= rows.size() or rows[r][c] == null:
			return false
		_hurt_cell(r, c, power, Vector2(p.x, wall_y - r * CELL_H))
		return true
	for i in segs.size():
		var sg: Dictionary = segs[i]
		if sg.dying >= 0.0 or float(sg.s) < 0.0:
			continue
		var at := path_at(sg.s)
		var rad := (HEAD_R if sg.kind == Kind.HEAD else SEG_R) + 2.0
		if absf(at.x - float(p.x)) < rad and absf(at.y - float(p.y)) < rad:
			_hurt_seg(i, power, Vector2(p.x, at.y + rad * 0.7))
			return true
	return false

func _hurt_cell(r: int, c: int, dmg: int, at: Vector2) -> void:
	var cell: Dictionary = rows[r][c]
	cell.hp = int(cell.hp) - dmg
	if cell.hp > 0:
		events.append({"type": "hit", "pos": at, "id": cell.id, "kind": cell.kind})
		return
	var pos := cell_pos(r, c)
	rows[r][c] = null
	_killed(cell, pos)
	if cell.kind == Kind.BOMB:
		events.append({"type": "boom", "pos": pos})
		var blast := maxi(2, int(ceilf(hp_base(wave) * 3.0)))
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				var rr: int = r + dr
				var cc: int = c + dc
				if rr >= 0 and rr < rows.size() and cc >= 0 and cc < COLS and rows[rr][cc] != null:
					_hurt_cell(rr, cc, blast, cell_pos(rr, cc))

func _hurt_seg(i: int, dmg: int, at: Vector2) -> void:
	var sg: Dictionary = segs[i]
	sg.hp = int(sg.hp) - dmg
	if sg.hp > 0:
		events.append({"type": "hit", "pos": at, "id": sg.id, "kind": sg.kind})
		return
	var pos := path_at(sg.s)
	if sg.kind == Kind.HEAD:
		# the head gone, the rest goes off plate by plate
		segs.remove_at(i)
		_killed(sg, pos)
		for k in segs.size():
			segs[k].dying = 0.12 + 0.07 * k
		return
	segs.remove_at(i)
	_killed(sg, pos)
	_push += KNOCK
	events.append({"type": "knock"})

## A crate or a plate gone: the score, the streak, and a gift's token.
func _killed(cell: Dictionary, pos: Vector2, popped := false) -> void:
	var kind: int = cell.kind
	var worth: int = int(cell.max)
	if kind == Kind.GOLD:
		worth *= GOLD_WORTH
	score += worth
	kills += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	_streak_t = STREAK_GAP
	events.append({"type": "kill", "pos": pos, "kind": kind, "points": worth, "max": cell.max, "id": cell.id,
		"streak": streak, "popped": popped})
	if kind >= Kind.PEA and kind <= Kind.TWIN:
		var tk := {"kind": kind, "x": pos.x, "y": pos.y, "vy": -90.0, "id": _next_id}
		_next_id += 1
		tokens.append(tk)
		events.append({"type": "token", "pos": pos, "kind": kind, "id": tk.id})

func _step_tokens() -> void:
	var keep: Array = []
	for tk: Dictionary in tokens:
		tk.vy = minf(float(tk.vy) + 420.0 * DT, TOKEN_FALL)
		tk.y = float(tk.y) + float(tk.vy) * DT
		var near_cart := absf(float(tk.x) - x) < CATCH or (twin_t > 0.0 and absf(float(tk.x) - twin_x) < CATCH)
		if float(tk.y) > CART_Y - 34.0 and near_cart:
			_take(int(tk.kind), Vector2(tk.x, tk.y))
			continue
		if float(tk.y) > GROUND + 6.0:
			events.append({"type": "token_lost", "pos": Vector2(tk.x, GROUND), "kind": tk.kind})
			continue
		keep.append(tk)
	tokens = keep

## A gift caught. One already at its most is a heavier pea instead.
func _take(kind: int, at: Vector2) -> void:
	caught += 1
	var got := kind
	match kind:
		Kind.PEA:
			if peas < MAX_PEAS:
				peas += 1
			else:
				got = Kind.POWER
		Kind.RATE:
			if rate_lv < MAX_RATE:
				rate_lv += 1
			else:
				got = Kind.POWER
		Kind.TWIN:
			if twin_t <= 0.0:
				twin_x = x
			twin_t = TWIN_TIME
	if got == Kind.POWER:
		power += 1
	events.append({"type": "catch", "pos": at, "kind": kind, "got": got})

# --- the waves ---

func _deal() -> void:
	wave += 1
	wave_kind = Wave.MILLI if wave % 3 == 0 else Wave.WALL
	if wave_kind == Wave.WALL:
		_deal_wall()
	else:
		_deal_milli()
	events.append({"type": "wave", "wave": wave, "kind": wave_kind})

## Which gift a gift crate holds: more peas and a quicker gun while there is
## room for them, a heavier pea always, the helper now and then.
func _gift() -> int:
	var bag: Array = [Kind.POWER, Kind.POWER]
	if peas < MAX_PEAS:
		bag.append_array([Kind.PEA, Kind.PEA, Kind.PEA])
	if rate_lv < MAX_RATE:
		bag.append_array([Kind.RATE, Kind.RATE, Kind.RATE])
	if wave >= 2:
		bag.append(Kind.TWIN)
	return bag[rng.randi_range(0, bag.size() - 1)]

func _cell(kind: int, hp: int) -> Dictionary:
	_next_id += 1
	return {"kind": kind, "hp": maxi(1, hp), "max": maxi(1, hp), "id": _next_id - 1}

## A wall: rows of crates, the higher the heavier, with gaps, two or three
## gifts, a firecracker from wave four and a golden crate now and then.
func _deal_wall() -> void:
	rows.clear()
	var n := mini(4 + int(wave / 2.0), 9)
	var base := hp_base(wave)
	for r in n:
		var row: Array = []
		for c in COLS:
			var gap := 0.14 if r > 0 else 0.3
			if rng.randf() < gap:
				row.append(null)
				continue
			var hp := base * (1.0 + 0.3 * r) * rng.randf_range(0.7, 1.3)
			if rng.randf() < 0.08:
				hp *= 2.0
			row.append(_cell(Kind.CRATE, roundi(hp)))
		rows.append(row)
	var gifts := 2 + (1 if wave % 4 == 0 else 0)
	_scatter(gifts, n, func(r: int) -> Dictionary: return _cell(_gift(), roundi(base * (0.5 + 0.12 * r))))
	if wave >= 4:
		_scatter(1 + int(wave >= 9), n, func(r: int) -> Dictionary: return _cell(Kind.BOMB, roundi(base * (0.8 + 0.2 * r))))
	if wave >= 2 and rng.randf() < 0.6:
		_scatter(1, n, func(r: int) -> Dictionary: return _cell(Kind.GOLD, roundi(base * (1.6 + 0.3 * r))))
	wall_y = 0.0
	wall_speed = 6.5 + 0.45 * mini(wave, 20)

## Puts `count` cells made by `make` on rows of their own, clear of the
## lowest and of each other.
func _scatter(count: int, n: int, make: Callable) -> void:
	for i in count:
		for tries in 12:
			var r := rng.randi_range(1 if n > 1 else 0, n - 1)
			var c := rng.randi_range(0, COLS - 1)
			var here = rows[r][c]
			if here == null or int(here.kind) == Kind.CRATE:
				rows[r][c] = make.call(r)
				break

func _step_wall() -> void:
	while not rows.is_empty() and _row_empty(rows[0]):
		rows.pop_front()
		wall_y -= CELL_H
	if rows.is_empty():
		_cleared()
		return
	wall_y += wall_speed * (RUSH if wall_y < RUSH_Y else 1.0) * DT
	if wall_y >= DANGER:
		_end("wall")

static func _row_empty(row: Array) -> bool:
	for c in row:
		if c != null:
			return false
	return true

## The millipede: a head and so many plates behind it, a gift every few.
func _deal_milli() -> void:
	segs.clear()
	_push = 0.0
	var n := mini(7 + int(wave * 0.8), 24)
	var base := hp_base(wave) * 1.5
	var head := _cell(Kind.HEAD, roundi(base * HEAD_WORTH))
	head.s = 0.0
	head.dying = -1.0
	segs.append(head)
	for i in n:
		var kind := Kind.CRATE
		if i % 6 == 2:
			kind = _gift()
		elif i % 7 == 5:
			kind = Kind.GOLD
		var hp := base * rng.randf_range(0.7, 1.3) * (0.5 if kind >= Kind.PEA else (1.6 if kind == Kind.GOLD else 1.0))
		var sg := _cell(kind, roundi(hp))
		sg.s = -(i + 1) * SPACING
		sg.dying = -1.0
		segs.append(sg)
	milli_speed = 20.0 + 0.7 * mini(wave, 24)

func _step_milli() -> void:
	if segs.is_empty():
		_cleared()
		return
	# the tail going off after the head
	if segs[0].kind != Kind.HEAD:
		var i := 0
		while i < segs.size():
			var sg: Dictionary = segs[i]
			sg.dying = float(sg.dying) - DT
			if sg.dying <= 0.0:
				segs.remove_at(i)
				_killed(sg, path_at(sg.s), true)
			else:
				i += 1
		return
	var head: Dictionary = segs[0]
	var speed := milli_speed * (RUSH if float(head.s) < 260.0 else 1.0)
	var back := minf(_push, 150.0 * DT)
	_push -= back
	head.s = maxf(0.0, float(head.s) + speed * DT - back)
	for i in range(1, segs.size()):
		var sg: Dictionary = segs[i]
		var want: float = float(segs[i - 1].s) - SPACING
		if float(sg.s) > want:
			sg.s = want
		else:
			sg.s = minf(want, float(sg.s) + speed * CATCH_UP * DT)
	if float(head.s) >= path_len():
		_end("milli")

func _cleared() -> void:
	var bonus := 50 * wave
	score += bonus
	events.append({"type": "clear", "wave": wave, "bonus": bonus, "kind": wave_kind})
	gap_t = GAP_TIME

func _end(why: String) -> void:
	phase = Phase.OVER
	phase_t = 0.0
	events.append({"type": "over", "why": why})

## The Second chance (arcade/boosters.gd): the wall is shoved back up four
## rows, the millipede a long way back along its path.
func revive() -> void:
	if phase != Phase.OVER:
		return
	phase = Phase.PLAY
	phase_t = 0.0
	_warned = false
	if wave_kind == Wave.WALL:
		wall_y = minf(wall_y, DANGER) - CELL_H * 4.5
	elif not segs.is_empty():
		segs[0].s = maxf(float(segs[0].s) - 700.0, 260.0)
	events.append({"type": "revive"})
