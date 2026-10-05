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
##
## The second pass (2026-10-04): three pods held for a while (a fan of peas,
## a pea that goes through three, a pea that bursts on its neighbours),
## three more gifts (a magnet for the gifts, a frost on whatever is coming,
## a shove back up) and an iron crate that takes one a pea whatever the pea
## weighs. The helper is a short one now, and the millipede quickens as it
## shortens.
##
## The third pass (2026-10-05): the rotten gift is gone (a gift that took
## something back made no sense). A wave holds more gifts and more crates,
## and its gifts are planned together (`_plan_gifts`), not drawn one by one:
## the gun's own come first and are half of them at least, and a magnet
## only comes with gifts right behind it to pull.

enum Phase { READY, PLAY, OVER }
enum Wave { WALL, MILLI }
## What a crate or a plate is. PEA to TWIN and FAN to SHOVE hold a token
## (`holds_token`); FAN, PIERCE and BURST are the pods.
enum Kind { CRATE, GOLD, BOMB, PEA, RATE, POWER, TWIN, HEAD, FAN, PIERCE, BURST, MAGNET, FROST, SHOVE, IRON }
## How a pea in flight looks and lands.
enum Shot { PEA, PIERCE, BURST }

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
const TWIN_TIME := 6.0
const TWIN_OFF := 58.0
const TOKEN_FALL := 120.0
const CATCH := 30.0
## A token dropped past the cart's reach (the millipede comes in from off
## the left edge) drifts in to where the cart can stand under it.
const TOKEN_DRIFT := 80.0
const POD_TIME := 10.0
const MAGNET_TIME := 10.0
const MAGNET_PULL := 300.0
const FROST_TIME := 5.0
const FROST := 0.35
const SHOVE_WALL := 60.0
const SHOVE_MILLI := 200.0
## The fan's two side peas lean this far off straight up (as vx).
const FAN_VX := 135.0
const PIERCES := 3
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
## A wall's rows on wave 1 (one more every other wave) and at its most, the
## chance a cell is left empty (the lowest row's is its own), and a
## millipede's plates before the wave's number is added.
const WALL_ROWS := 6
const WALL_ROWS_MAX := 12
const WALL_GAP := 0.1
const WALL_GAP_LOW := 0.25
const MILLI_PLATES := 9
const MILLI_PLATES_MAX := 26
## The gun's gifts a wave never holds fewer of, and the gifts that come
## right behind a magnet.
const GUN_GIFTS := 2
const MAGNET_PULLS := 2
const KNOCK := 9.0
## With every plate gone but the head it runs this much quicker.
const MILLI_HURRY := 0.6
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
## The pod held (0: none, else Kind.FAN, PIERCE or BURST) and its seconds
## left; the magnet's and the frost's.
var pod := 0
var pod_t := 0.0
var magnet_t := 0.0
var frost_t := 0.0
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
var milli_n := 1
var _push := 0.0
## Where each plate is, worked out once a step and again when one goes: a
## pea asking the path for every plate it passed was most of a step.
var _seg_pos := PackedVector2Array()
var _seg_dirty := true
var _seg_top := 0.0
var _seg_low := 0.0
var _twin_wave := -9
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
	return 2.4 * pow(1.46, mini(w, 10) - 1) * pow(1.38, maxi(0, w - 10))

static func holds_token(kind: int) -> bool:
	return (kind >= Kind.PEA and kind <= Kind.TWIN) or (kind >= Kind.FAN and kind <= Kind.SHOVE)

## An iron crate's number: the peas it takes, whatever they weigh.
static func iron_hp(w: int) -> int:
	return 10 + 4 * w

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
			_tick_gifts()
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

## The pod, the magnet and the frost run down.
func _tick_gifts() -> void:
	if pod_t > 0.0:
		pod_t -= DT
		if pod_t <= 0.0:
			pod_t = 0.0
			pod = 0
			events.append({"type": "pod_off"})
	if magnet_t > 0.0:
		magnet_t = maxf(0.0, magnet_t - DT)
	if frost_t > 0.0:
		frost_t -= DT
		if frost_t <= 0.0:
			frost_t = 0.0
			events.append({"type": "frost_off"})

## What the frost leaves of a speed.
func _slow() -> float:
	return FROST if frost_t > 0.0 else 1.0

func _fire() -> void:
	_cool -= DT
	if _cool > 0.0:
		return
	_cool += 1.0 / rate()
	_volley(x, peas, pod)
	events.append({"type": "shot", "x": x, "n": peas})
	if twin_t > 0.0:
		# the helper's is a plain pea, one at a time
		_volley(twin_x, 1, 0)
	fired += 1

func _volley(from: float, n: int, held: int) -> void:
	var look := Shot.PEA
	var left := 0
	if held == Kind.PIERCE:
		look = Shot.PIERCE
		left = PIERCES - 1
	elif held == Kind.BURST:
		look = Shot.BURST
	for i in n:
		shots.append({"x": from + (i - (n - 1) * 0.5) * PEA_GAP, "y": CART_Y - 34.0, "vx": 0.0, "k": look, "left": left, "last": -1})
	if held == Kind.FAN:
		for side in [-1.0, 1.0]:
			shots.append({"x": from + side * 6.0, "y": CART_Y - 34.0, "vx": side * FAN_VX, "k": Shot.PEA, "left": 0, "last": -1})

func _step_shots() -> void:
	var keep: Array = []
	_seg_dirty = true
	var live := phase == Phase.PLAY and gap_t <= 0.0
	for p: Dictionary in shots:
		p.y -= PEA_SPEED * DT
		if p.y < -8.0:
			continue
		if p.vx != 0.0:
			p.x += float(p.vx) * DT
			if p.x < -6.0 or p.x > W + 6.0:
				continue
		if live and _strike(p):
			continue
		keep.append(p)
	shots = keep

## Where every plate is, and the band of the field they are in.
func _place_segs() -> void:
	_seg_dirty = false
	var n := segs.size()
	_seg_pos.resize(n)
	_seg_top = INF
	_seg_low = -INF
	for i in n:
		var at := path_at(segs[i].s)
		_seg_pos[i] = at
		_seg_top = minf(_seg_top, at.y)
		_seg_low = maxf(_seg_low, at.y)

## A pea against whatever is over it. True when it is spent.
func _strike(p: Dictionary) -> bool:
	var px: float = p.x
	var py: float = p.y
	if wave_kind == Wave.WALL:
		if py > wall_y or rows.is_empty() or px < 0.0 or px >= W:
			return false
		var r := int((wall_y - py) / CELL_H)
		var c := clampi(int(px / CELL_W), 0, COLS - 1)
		if r >= rows.size() or rows[r][c] == null:
			return false
		var cell: Dictionary = rows[r][c]
		if int(cell.id) == int(p.last):
			return false
		_hurt_cell(r, c, power, Vector2(px, wall_y - r * CELL_H))
		if int(p.k) == Shot.BURST:
			var half := maxi(1, int(power / 2.0))
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0)]:
				var rr: int = r + d.x
				var cc: int = c + d.y
				if rr < rows.size() and cc >= 0 and cc < COLS and rows[rr][cc] != null:
					_hurt_cell(rr, cc, half, cell_pos(rr, cc), false, true)
		return _spent(p, int(cell.id))
	if _seg_dirty:
		_place_segs()
	if py < _seg_top - HEAD_R - 2.0 or py > _seg_low + HEAD_R + 2.0:
		return false
	for i in segs.size():
		var sg: Dictionary = segs[i]
		if sg.dying >= 0.0 or float(sg.s) < 0.0:
			continue
		var at := _seg_pos[i]
		var rad := (HEAD_R if sg.kind == Kind.HEAD else SEG_R) + 2.0
		if absf(at.x - px) < rad and absf(at.y - py) < rad:
			var id: int = sg.id
			if id == int(p.last):
				continue
			var beside: Array = []
			if int(p.k) == Shot.BURST:
				for j in [i - 1, i + 1]:
					if j >= 0 and j < segs.size():
						beside.append(segs[j].id)
			_hurt_seg(i, power, Vector2(px, at.y + rad * 0.7))
			for other: int in beside:
				var j := _seg_index(other)
				if j >= 0 and float(segs[j].dying) < 0.0 and float(segs[j].s) >= 0.0:
					_hurt_seg(j, maxi(1, int(power / 2.0)), path_at(segs[j].s), true)
			return _spent(p, id)
	return false

## A pea that has landed on `id`: a piercing one with targets left goes on.
func _spent(p: Dictionary, id: int) -> bool:
	if int(p.left) <= 0:
		return true
	p.left = int(p.left) - 1
	p.last = id
	return false

func _seg_index(id: int) -> int:
	for i in segs.size():
		if int(segs[i].id) == id:
			return i
	return -1

## `whole` is a firecracker's (iron takes it whole); `quiet` a burst's
## splash, which lands without a sound of its own.
func _hurt_cell(r: int, c: int, dmg: int, at: Vector2, whole := false, quiet := false) -> void:
	var cell: Dictionary = rows[r][c]
	if cell.kind == Kind.IRON and not whole:
		dmg = 1
	cell.hp = int(cell.hp) - dmg
	if cell.hp > 0:
		events.append({"type": "hit", "pos": at, "id": cell.id, "kind": cell.kind, "hp": cell.hp, "quiet": quiet})
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
					_hurt_cell(rr, cc, blast, cell_pos(rr, cc), true)

func _hurt_seg(i: int, dmg: int, at: Vector2, quiet := false) -> void:
	var sg: Dictionary = segs[i]
	if sg.kind == Kind.IRON:
		dmg = 1
	sg.hp = int(sg.hp) - dmg
	if sg.hp > 0:
		events.append({"type": "hit", "pos": at, "id": sg.id, "kind": sg.kind, "hp": sg.hp, "quiet": quiet})
		return
	_seg_dirty = true
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
	if holds_token(kind):
		var tk := {"kind": kind, "x": pos.x, "y": pos.y, "vy": -90.0, "id": _next_id}
		_next_id += 1
		tokens.append(tk)
		events.append({"type": "token", "pos": pos, "kind": kind, "id": tk.id})

func _step_tokens() -> void:
	var keep: Array = []
	for tk: Dictionary in tokens:
		tk.vy = minf(float(tk.vy) + 420.0 * DT, TOKEN_FALL)
		tk.y = float(tk.y) + float(tk.vy) * DT
		if magnet_t > 0.0:
			var to := x
			if twin_t > 0.0 and absf(twin_x - float(tk.x)) < absf(x - float(tk.x)):
				to = twin_x
			tk.x = move_toward(float(tk.x), to, MAGNET_PULL * DT)
		else:
			tk.x = move_toward(float(tk.x), clampf(float(tk.x), CART_HALF, W - CART_HALF), TOKEN_DRIFT * DT)
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
		Kind.FAN, Kind.PIERCE, Kind.BURST:
			pod = kind
			pod_t = POD_TIME
		Kind.MAGNET:
			magnet_t = MAGNET_TIME
		Kind.FROST:
			frost_t = FROST_TIME
		Kind.SHOVE:
			_shove()
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

## Everything coming goes back a way: the wall up, the millipede along
## its path.
func _shove() -> void:
	if wave_kind == Wave.WALL:
		wall_y = maxf(wall_y - SHOVE_WALL, minf(wall_y, RUSH_Y))
	elif not segs.is_empty() and segs[0].kind == Kind.HEAD:
		var s: float = segs[0].s
		segs[0].s = maxf(s - SHOVE_MILLI, minf(s, 260.0))
		for i in range(1, segs.size()):
			segs[i].s = minf(float(segs[i].s), float(segs[i - 1].s) - SPACING)

# --- the waves ---

func _deal() -> void:
	wave += 1
	wave_kind = Wave.MILLI if wave % 3 == 0 else Wave.WALL
	if wave_kind == Wave.WALL:
		_deal_wall()
	else:
		_deal_milli()
	events.append({"type": "wave", "wave": wave, "kind": wave_kind})

## How many gift crates (or plates) wave `w` holds.
static func gift_count(w: int) -> int:
	return mini(3 + int(w / 3.0), 6)

## A gift for the gun, with `p` peas a volley and the rate at `r`: more peas
## and a quicker gun while there is room for them, a heavier pea always.
## `last` is the one drawn before it in the wave, left out while there is
## another to give, so a wave's are not all the one gift.
func _gun_gift(p: int, r: int, last := -1) -> int:
	var bag: Array = []
	if p < MAX_PEAS and last != Kind.PEA:
		bag.append_array([Kind.PEA, Kind.PEA, Kind.PEA])
	if r < MAX_RATE and last != Kind.RATE:
		bag.append_array([Kind.RATE, Kind.RATE, Kind.RATE])
	if last != Kind.POWER or bag.is_empty():
		bag.append_array([Kind.POWER, Kind.POWER])
	return bag[rng.randi_range(0, bag.size() - 1)]

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held = a[i]
		a[i] = a[j]
		a[j] = held

## What a wave's `count` gifts are, in the order they are met. Drawn one by
## one a wave could hold a magnet and a frost and nothing for the gun, and
## the next wave's numbers were past it. So the gun's gifts are half of them
## at least (never fewer than two) and the first met is one of them; the
## rest are one each at most of a pod, the magnet, the frost, the helper and
## the shove. A magnet only comes to a wave of four or more, with two gifts
## still to come after it.
func _plan_gifts(count: int) -> Array:
	var extras: Array = []
	if wave >= 3:
		extras.append([Kind.FAN, Kind.PIERCE, Kind.BURST][rng.randi_range(0, 2)])
		if count >= 4:
			extras.append(Kind.MAGNET)
	if wave >= 4:
		extras.append(Kind.FROST)
		# one helper at most every other wave
		if wave - _twin_wave >= 2:
			extras.append(Kind.TWIN)
	if wave >= 5:
		extras.append(Kind.SHOVE)
	_shuffle(extras)
	var guns := maxi(GUN_GIFTS, int(ceil(count * 0.5)))
	extras.resize(clampi(count - guns, 0, extras.size()))
	if extras.has(Kind.TWIN):
		_twin_wave = wave
	var p := peas
	var r := rate_lv
	var plan: Array = []
	for i in count - extras.size():
		var got := _gun_gift(p, r, -1 if plan.is_empty() else int(plan.back()))
		p += int(got == Kind.PEA)
		r += int(got == Kind.RATE)
		plan.append(got)
	var first: int = plan.pop_back()
	plan.append_array(extras)
	_shuffle(plan)
	plan.push_front(first)
	var m := plan.find(Kind.MAGNET)
	if m > count - 1 - MAGNET_PULLS:
		var to := count - 1 - MAGNET_PULLS
		plan[m] = plan[to]
		plan[to] = Kind.MAGNET
	return plan

## Where a wave's gifts go among `n` places (a wall's rows over the lowest,
## a millipede's plates), in the order they are met: spread along them, each
## on a place of its own, and the ones a magnet is to pull right behind it.
func _gift_places(plan: Array, n: int) -> Array:
	var count := plan.size()
	var m := plan.find(Kind.MAGNET)
	var places: Array = []
	for i in count:
		var at := int((i + rng.randf()) * n / count)
		if m >= 0 and i > m and i <= m + MAGNET_PULLS:
			at = 0
		var low: int = 0 if i == 0 else int(places[i - 1]) + 1
		places.append(clampi(at, low, n - count + i))
	return places

## How many iron crates wave `w` holds.
static func iron_count(w: int) -> int:
	return 0 if w < 5 else mini(1 + int((w - 5) / 4.0), 4)

func _cell(kind: int, hp: int) -> Dictionary:
	_next_id += 1
	return {"kind": kind, "hp": maxi(1, hp), "max": maxi(1, hp), "id": _next_id - 1}

## A wall: rows of crates, the higher the heavier, with gaps, three to six
## gifts up it, a firecracker from wave four and a golden crate now and then.
func _deal_wall() -> void:
	rows.clear()
	var n := mini(WALL_ROWS + int(wave / 2.0), WALL_ROWS_MAX)
	var base := hp_base(wave)
	for r in n:
		var row: Array = []
		for c in COLS:
			var gap := WALL_GAP if r > 0 else WALL_GAP_LOW
			if rng.randf() < gap:
				row.append(null)
				continue
			var hp := base * (1.0 + 0.3 * r) * rng.randf_range(0.7, 1.3)
			if rng.randf() < 0.08:
				hp *= 2.0
			row.append(_cell(Kind.CRATE, roundi(hp)))
		rows.append(row)
	var plan := _plan_gifts(gift_count(wave))
	var at := _gift_places(plan, n - 1)
	for i in plan.size():
		var r: int = int(at[i]) + 1
		rows[r][rng.randi_range(0, COLS - 1)] = _cell(plan[i], roundi(base * (0.5 + 0.12 * r)))
	if wave >= 4:
		_scatter(1 + int(wave >= 9), n, func(r: int) -> Dictionary: return _cell(Kind.BOMB, roundi(base * (0.8 + 0.2 * r))))
	if wave >= 2 and rng.randf() < 0.6:
		_scatter(1, n, func(r: int) -> Dictionary: return _cell(Kind.GOLD, roundi(base * (1.6 + 0.3 * r))))
	_scatter(iron_count(wave), n, func(_r: int) -> Dictionary: return _cell(Kind.IRON, iron_hp(wave)))
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
	wall_y += wall_speed * (RUSH if wall_y < RUSH_Y else _slow()) * DT
	if wall_y >= DANGER:
		_end("wall")

static func _row_empty(row: Array) -> bool:
	for c in row:
		if c != null:
			return false
	return true

## The millipede: a head and so many plates behind it, its gifts spread
## down its length.
func _deal_milli() -> void:
	segs.clear()
	_push = 0.0
	var n := mini(MILLI_PLATES + wave, MILLI_PLATES_MAX)
	var plan := _plan_gifts(gift_count(wave))
	var at := _gift_places(plan, n)
	var base := hp_base(wave) * 1.5
	var head := _cell(Kind.HEAD, roundi(base * HEAD_WORTH))
	head.s = 0.0
	head.dying = -1.0
	segs.append(head)
	for i in n:
		var kind := Kind.CRATE
		if at.has(i):
			kind = plan[at.find(i)]
		elif i % 7 == 5:
			kind = Kind.GOLD
		elif i % 5 == 3 and wave >= 9:
			kind = Kind.IRON
		var hp := base * rng.randf_range(0.7, 1.3) * (0.5 if holds_token(kind) else (1.6 if kind == Kind.GOLD else 1.0))
		if kind == Kind.IRON:
			hp = iron_hp(wave) * 0.5
		var sg := _cell(kind, roundi(hp))
		sg.s = -(i + 1) * SPACING
		sg.dying = -1.0
		segs.append(sg)
	milli_n = n
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
	# the shorter it is, the quicker it runs
	var hurry := 1.0 + MILLI_HURRY * (1.0 - float(segs.size() - 1) / maxf(1.0, milli_n))
	var speed := milli_speed * (RUSH if float(head.s) < 260.0 else hurry * _slow())
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
