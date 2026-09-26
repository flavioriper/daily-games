extends "res://core/puzzle_base.gd"

## Light Up as a flat board: a court of flagstones on the host's parchment
## card, rough blocks of stone standing in it with their numbers carved on
## their crowns, a paper lantern on every stone the player lights, and a slate
## chip on every stone they have ruled out. Built beside the island version
## (legacy/puzzles/lightup3d.gd) so the two could be judged against each
## other on the phone; the rules live in puzzles/lightup_state.gd, which this
## only draws.
##
## What flat buys here is the floor. Light Up has no marker for its main
## condition: a stone no lamp reaches is a cold grey, a lit one is warm, and
## that is the whole of "every stone must be lit" -- so the thing the player
## reads is a field of up to forty-nine flat tints. On the island that field
## is seen at seven degrees, where the far rows are a few pixels tall,
## foreshortened, and half in the shade of the blocks standing in front of
## them: precisely the information you look at most, rendered worst. Flat,
## every stone is the same size and the same tint wherever it sits. **And it
## buys the beam** -- the shaft of light itself, drawn down the row and the
## column cell by cell as it travels, which is the rule made into a picture
## and the one thing on this screen the island cannot do at all.
##
## How it is drawn. The court is two meshes, rebuilt only while something
## moves. The **floor** is the display: the mortar bed on its edge, a
## flagstone per cell carrying its own warmth, and the beams over them; it is
## built about the court's centre so its entrance is a transform. The
## **ground** is everything standing on it that is not a lamp: the shade
## under the finger, the blush of a pointed-at stone, every shadow, the
## blocks and the chips. The numbers are drawn over both with one draw_string
## each, because a digit in a mesh cache key would multiply every block state
## by five. Only the lamps are Controls, with the face family's own cached
## meshes behind them (ui/faces/court_lantern.gd), each standing in a slot
## the layout owns.
##
## How it moves. The lamps take the flat boards' vocabulary (core/motion.gd,
## docs/art/flat-motion.md) straight, inside their slots: a lamp pops in with
## the squash, sinks under the finger, drops in from a hint, hops, leans away
## from a neighbour's landing, wobbles on Check and shivers when it refuses.
## The blocks, the chips, the shade and the blush are drawn, so they read the
## same recipes as curves (Motion.pop_in_scale and its siblings; the doc's
## rule 8) and never copy a number. The light travelling out from a lamp,
## stone by stone, is this board's own signature; so are the chips clearing
## away on the win.
## Spec: docs/superpowers/specs/2026-09-18-lightup-flat-design.md, sections 2
## to 7 and the amendment at its end, and the mock it is ported from
## (docs/brainstorm/concepts.html#lightup).

const State = preload("res://puzzles/lightup_state.gd")
const Gen = preload("res://puzzles/lightup_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const CourtLantern = preload("res://ui/faces/court_lantern.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

# --- the court ---
const PAD := 34.0
## The mortar bed the stones are set into: a hair of shade outside the grid,
## which is what keeps a court of pale tints from floating on the parchment.
## It wears no edge of its own: the family's lip under it sat 14 px above the
## card's and read as a doubled line, because the bed is a shade and not a
## surface (the polish amendment in the spec).
const MORTAR := 6.0
const MORTAR_RADIUS := 20.0
const MORTAR_ALPHA := 0.07
## The joint between two stones, the corner they are cut with and the soft lip
## along the bottom of each, all in cells.
const GAP := 0.035
const STONE_RADIUS := 0.13
const STONE_EDGE := 0.05
## The beam: how wide it runs down a line, how strong it is on the stone next
## to the lamp, and how it thins per cell travelled.
const BEAM_HALF := 0.3
const BEAM_ALPHA := 0.5
const BEAM_FALL := 0.22
## Below this there is no light on the stone worth drawing.
const BEAM_MIN := 0.02
## The shaft is soft: clear at its sides, full down the middle, with a
## narrower bright core of BEAM_CORE of its half-width at CORE_ALPHA over it.
const BEAM_CORE := 0.4
const CORE_ALPHA := 0.35
## The stretch of beam between two lamps that can see each other runs rose
## rather than white: the broken rule drawn where it is broken.
const CLASH_ALPHA := 0.55
## Every stone is cut a little differently: its tone within STONE_TONE, a
## light along its crest, and a few specks (SPECK_SHARE of the stones) or a
## hairline crack (CRACK_SHARE), all off fixed hashes of the stone.
const STONE_TONE := 0.05
const CREST_ALPHA := 0.13
const SPECK_SHARE := 0.55
const SPECK_ALPHA := 0.22
const CRACK_SHARE := 0.18
const CRACK_ALPHA := 0.3
## The front of the light: a stone flashes toward white as it warms, peaking
## half-way, so the travel out from a lamp reads as a bright edge moving.
const GLINT_ALPHA := 0.4
## The wick catching: a warm disc on the floor under a lamp as it lands,
## FLARE_R cells across at its widest and gone over FLARE_TIME.
const FLARE_R := 0.62
const FLARE_ALPHA := 0.55
const FLARE_TIME := 0.45
## The light a lit stone throws on the side of a block beside it.
const RIM_ALPHA := 0.7
const RIM_WIDTH := 0.07
## The win warms the mortar bed toward lamplight over WARM_TIME, and a glint
## crosses every stone on the solve wave over WIN_GLINT.
const WARM_ALPHA := 0.3
const WARM_TIME := 0.9
const WIN_GLINT := 0.5
## Once every stone is lit the shafts have nothing left to say, and ten of
## them crossing wash the court white: on the win they sink into the floor,
## down to WIN_BEAM of their strength over WARM_TIME.
const WIN_BEAM := 0.25
## How far a sinking stone goes into its own shade at the bottom of the
## press, and the blush a stone takes when Check points at its lamp or a tap
## is refused on it.
const SINK_SHADE := 0.5
const BLUSH_ALPHA := 0.9

# --- the pieces, in cells ---
const BLOCK_SIZE := 0.94
const CHIP_SIZE := 0.9
## The lamp's seat. The mock draws it at R = 0.38 of a cell and the lantern's
## drawing is SEAT (2.4) R tall, so this is the seat that gives it that R.
const LAMP_SIZE := 0.38 * CourtLantern.SEAT
const NUM_SIZE := 0.4
## How far a numbered block goes toward LEAF when its count is met and
## toward BAD when it is over; a refused tap flashes it the same way.
const BLOCK_GREEN := 0.55
const BLOCK_ROSE := 0.6
## The shadows on the ground: the mock's ellipses, as the family's soft disc.
## The lamp's is in cells (the lantern drew it at (0.05, 1.1) R, 0.78 by
## 0.19 R, with R at 0.38 of a cell); the block's and the chip's are in the
## piece's own size. The peaks are about double the flat ellipses they
## replace, because a disc that fades to its rim reads at about half its
## centre (Shikaku measured it).
const LAMP_SHADOW_AT := Vector2(0.02, 0.42)
const LAMP_SHADOW_RX := 0.3
const LAMP_SHADOW_RY := 0.075
const BLOCK_SHADOW_AT := Vector2(0.0, 0.44)
const BLOCK_SHADOW_RX := 0.42
const BLOCK_SHADOW_RY := 0.1
const CHIP_SHADOW_AT := Vector2(0.0, 0.16)
const CHIP_SHADOW_RX := 0.26
const CHIP_SHADOW_RY := 0.08
const SHADOW_ALPHA := 0.24
const BLOCK_SHADOW_ALPHA := 0.26

# --- motion: what is this board's own ---
## A stone warms over LIGHT_IN and cools over LIGHT_OUT, and waits LIGHT_STEP
## per cell of beam it is away from the lamp that changed, capped at
## LIGHT_CAP. This is what makes the light read as travelling out rather than
## switching on along the whole line at once, and it is the island's own
## quartet.
const LIGHT_IN := 0.22
const LIGHT_OUT := 0.3
const LIGHT_STEP := 0.035
const LIGHT_CAP := 0.25
## A refused piece's shiver, in cells; the family's 2 px is a tremor on a
## block this size.
const SHIVER := 0.04
## The chips clear away on the win, in a scatter rather than a wave, so the
## last picture is the lit court rather than the working-out.
const CLEAR_DELAY := 0.2
const CLEAR_SPREAD := 0.3
const CLEAR_TIME := 0.5
const CLEAR_SHRINK := 0.4
## How long the host waits before the win screen: the solve wave and the
## clearing both have to run their length first.
const WIN_WAIT := 1.6

const HINTS := State.HINTS
const TIP_CYCLE := 10.0
const TIPS := [
	"LU_TIP_LIGHT",
	"LU_TIP_NO_SEE",
	"LU_TIP_NUMBER",
]

var state = State.new()
## The names the win harness and the island board share, so one driver solves
## both twins.
var w: int:
	get: return state.w
var h: int:
	get: return state.h
var _solution_bulbs: Array:
	get: return state.solution

var fx: Node2D
var _cell := 0.0
var _grid := Vector2.ZERO
var _card := Rect2()
var _lamps: Dictionary = {}      # Vector2i -> CourtLantern, kept once made
## Lamp -> the Control it stands in. The slot is what the layout moves and
## the lamp is what the motion moves (a hop, a nudge, a shiver), so a
## relayout mid-flight never fights a pop.
var _slots: Dictionary = {}
var _pos_tw: Dictionary = {}     # lamp -> the hop, the nudge, the shiver, the drop
var _look_tw: Dictionary = {}    # lamp -> the pop, the press, the wobble
## Bumped on every rebuild; a pending callback from the last board checks it.
var _gen := 0

# --- the light ---
## Vector2i -> {"from", "to", "at", "dur"}: the warmth actually painted on a
## stone, which is what a retarget has to start from. Ask for a lamp and take
## it away again inside the fade and a single target would carry the stone all
## the way to lamplight and leave it there -- a lit floor with nothing
## lighting it.
var _warm: Dictionary = {}
## Lamps whose light is going out: [{"cell": Vector2i, "at": float}]. Their
## beams are drawn withdrawing with the floor they lit, over LIGHT_OUT from
## `at`, rather than vanishing on the frame the lamp is taken up.
var _beam_out: Array = []

# --- what the ground is doing ---
## Vector2i -> the second a chip begins to arrive.
var _chip_in: Dictionary = {}
## Chips leaving: [{"cell": Vector2i, "at": float}], drawn shrinking from
## `at` since the state no longer has them.
var _chip_out: Array = []
## Vector2i -> the second a stone began to blush.
var _blush: Dictionary = {}
## Vector2i -> {"down": float, "up": float}: a bare stone or a chip's stone
## sunk under the finger, pressed from `down` and springing back from `up`
## (INF while the gesture still holds it; a swept stone's is the second its
## chip lands).
var _sunk: Dictionary = {}
## What the blocks are doing, each Vector2i -> when it began: the press under
## the finger ({"down", "up"}, `up` INF while it is held), the Count bump,
## the hop ({"at", "height", "time"}), the lean away from a landing lamp
## ({"at", "dir"}), the refused shiver and the flash toward rose.
var _block_press: Dictionary = {}
var _block_bump: Dictionary = {}
var _block_hop: Dictionary = {}
var _block_nudge: Dictionary = {}
var _block_shiver: Dictionary = {}
var _block_flash: Dictionary = {}
## Vector2i -> the second a lamp's wick catches on it (FLARE_*).
var _flare: Dictionary = {}
var _floor: ArrayMesh
var _ground: ArrayMesh
var _ground_dirty := true
## The meshes the last _draw handed over that the next may let go of: a
## canvas command holds a mesh by RID, and a frame rendered before the queued
## redraw is flushed would otherwise draw a freed one (see CLAUDE.md).
var _shown: Array = []

# --- the gesture ---
var _press_cell := Vector2i(-1, -1)
## The lamp under the finger, sunk by the press, if the press landed on one.
var _pressed: Control
var _dragged := false
var _lay := true
var _swept: Dictionary = {}
var _pending: Array = []
var _last_paint := Vector2i(-1, -1)

var _opened := -1.0e9
## When the court was solved, or NEVER. Not a negative number: a completed
## daily is restored as solved ten seconds ago, which is before zero on a
## clock that started a moment earlier.
const NEVER := -1.0e9
var _solved_at := NEVER
## Redraw every frame until this second: a pop, a wave, the light moving.
var _anim_until := 0.0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "lightup"
func title() -> String: return "Light Up"

func rules() -> String:
	return tr("LU_RULES")

func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
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
	_stop_all()
	state.setup(rng, difficulty)
	_beam_out = []
	_chip_in = {}
	_chip_out = []
	_blush = {}
	_sunk = {}
	_block_press = {}
	_block_bump = {}
	_block_hop = {}
	_block_nudge = {}
	_block_shiver = {}
	_block_flash = {}
	_flare = {}
	_clear_gesture()
	_solved_at = NEVER
	_build_pieces()
	_settle()
	_layout()
	_tip_idx = 0
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	_enter()

# --- the cast ---

## Only the lamps are nodes. The court, the blocks and the chips are drawn.
func _build_pieces() -> void:
	for lamp in _slots:
		_slots[lamp].queue_free()
	_slots = {}
	_lamps = {}

## Puts `lamp` in a slot of its own under the board. The slot takes the
## layout; the lamp inside it takes the motion.
func _stand(lamp: Control, node_name: String) -> void:
	var slot := Control.new()
	slot.name = node_name
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	lamp.name = "lamp"
	lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(lamp)
	_slots[lamp] = slot

## The lamp on `cell`, made the first time one is set down there and kept
## afterwards: a stone the player taps twice would otherwise build and free a
## node with a mesh cache behind it on every tap.
func _lamp_node(cell: Vector2i) -> CourtLantern:
	if _lamps.has(cell):
		return _lamps[cell]
	var lamp := CourtLantern.new()
	# The shadow is the board's, on the ground (see _build_ground).
	lamp.casts = false
	lamp.visible = false
	lamp.scale = Vector2.ZERO
	_stand(lamp, "lamp_%d_%d" % [cell.x, cell.y])
	lamp.set_idle(true)
	_lamps[cell] = lamp
	if _cell > 0.0:
		_seat(lamp, cell_to_local(cell.y, cell.x), _cell * LAMP_SIZE)
	return lamp

## Every lamp takes the look its state asks for. A lamp is written only when
## its look changes -- a written face redraws.
func _refresh_faces() -> void:
	for cell in _lamps:
		var lamp: CourtLantern = _lamps[cell]
		if state.mark_at(cell) != State.LAMP:
			continue
		var pinned: bool = state.locked.has(cell)
		if lamp.pinned != pinned:
			lamp.pinned = pinned
		var bad: bool = not is_done() and state.clash.has(cell)
		if lamp.bad != bad:
			lamp.bad = bad
		# The win writes JOY on each lamp as the wave reaches it.
		if _solved_at > NEVER:
			continue
		_set_expr(lamp, Face.Expr.STRAIN if bad else Face.Expr.HAPPY)

func _set_expr(face: Face, expr: int) -> void:
	if face.expression != expr:
		face.expression = expr

## Each lamp's glow follows the warmth of the stone it stands on, so a lamp
## that has just landed brightens with its floor and one being taken up goes
## out with it. Written only when the light has moved.
func _place_light(now: float) -> void:
	for cell in _lamps:
		var lamp: CourtLantern = _lamps[cell]
		if not lamp.visible:
			continue
		var warm := _warmth(cell, now)
		if absf(lamp.lit - warm) > 0.001:
			lamp.lit = warm

# --- layout ---

## The court is the largest grid the card holds, and the card is cut to the
## court and centred in the slot rather than pinned under the day card the way
## most of the flat boards are. This is the second board of the nine whose
## grid is square while its space is tall -- and here there is no count band
## to spend width on, so the cell is capped by the width at every step and
## there is slack however the card is cut.
func _layout() -> void:
	if state.grid.is_empty():
		return
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var court := Vector2(_cell * state.w, _cell * state.h)
	var tall := minf(size.y, court.y + 2.0 * PAD)
	_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
	_grid = Vector2(size.x * 0.5 - court.x * 0.5, _card.position.y + (tall - court.y) * 0.5)
	for cell in _lamps:
		_seat(_lamps[cell], cell_to_local(cell.y, cell.x), _cell * LAMP_SIZE)
	_refresh_faces()
	_redraw()

## Seats `lamp` `px` square about `centre`: its slot takes the place, and the
## lamp's own place inside the slot is left to the motion.
func _seat(lamp: Control, centre: Vector2, px: float) -> void:
	var seat := Vector2.ONE * px
	var slot: Control = _slots[lamp]
	slot.size = seat
	slot.position = centre - seat * 0.5
	lamp.size = seat
	lamp.pivot_offset = seat * 0.5

## The cell a slot of `available` height holds, capped by the width.
func _cell_for(available: float) -> float:
	if state.grid.is_empty():
		return 0.0
	return minf((size.x - 2.0 * PAD) / state.w, (available - 2.0 * PAD) / state.h)

## The host cuts its card to the court and centres it, which is what these two
## say. A board that wants neither says nothing and fills the slot.
func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * state.h + 2.0 * PAD)

func card_centred() -> bool:
	return true

## Control-local point over the centre of cell (r, c). The win harness taps
## these, exactly as it does on the island board.
func cell_to_local(r: int, c: int) -> Vector2:
	return _grid + Vector2(c + 0.5, r + 0.5) * _cell

func _cell_at(local: Vector2) -> Vector2i:
	if _cell <= 0.0:
		return Vector2i(-1, -1)
	var p := (local - _grid) / _cell
	var cell := Vector2i(int(floor(p.x)), int(floor(p.y)))
	return cell if state.in_field(cell) else Vector2i(-1, -1)

## The court's centre in board pixels: what the floor is built about.
func _court_centre() -> Vector2:
	return _grid + Vector2(_cell * state.w, _cell * state.h) * 0.5

# --- the light ---

## The warmth painted on a stone right now: 0 is the cold grey of FLAGSTONE, 1
## is full lamplight.
func _warmth(cell: Vector2i, t: float) -> float:
	var rec: Dictionary = _warm.get(cell, {})
	if rec.is_empty():
		return 0.0
	if Motion.reduce:
		return float(rec.to)
	var u := (t - float(rec.at)) / float(rec.dur)
	if u <= 0.0:
		return float(rec.from)
	if u >= 1.0:
		return float(rec.to)
	return lerpf(float(rec.from), float(rec.to), _sine_io(u))

## Sends every stone toward the light it now stands in, each waiting what
## `delay` says for it: the travel out from a changed lamp (_travel_from),
## nothing at all (_at_once: an undo, a swept run) or Reset's wave.
func _relight(t: float, delay: Callable) -> void:
	for cell in state.white_cells():
		var target := 1.0 if state.lit.has(cell) else 0.0
		var cur := _warmth(cell, t)
		var rec: Dictionary = _warm.get(cell, {})
		if rec.is_empty():
			_warm[cell] = {"from": cur, "to": target, "at": t, "dur": LIGHT_IN}
			_anim_until = maxf(_anim_until, t + LIGHT_IN)
			continue
		if float(rec.to) == target and absf(cur - target) < 0.001:
			continue
		if float(rec.to) == target and t >= float(rec.at):
			continue
		rec.from = cur
		rec.to = target
		rec.at = t + float(delay.call(cell))
		rec.dur = LIGHT_IN if target > cur else LIGHT_OUT
		_anim_until = maxf(_anim_until, float(rec.at) + float(rec.dur))

## The light travelling out from `origin`: LIGHT_STEP per cell away, capped.
func _travel_from(origin: Vector2i) -> Callable:
	return func(cell: Vector2i) -> float:
		return minf(LIGHT_STEP * float(absi(cell.x - origin.x) + absi(cell.y - origin.y)), LIGHT_CAP)

## A change with no one place to travel from lands everywhere at once.
func _at_once(_cell_: Vector2i) -> float:
	return 0.0

## Reset's wave, from the far corner: what everything on the court leaves by.
func _reset_wave(cell: Vector2i) -> float:
	return Motion.stagger((state.h - 1 - cell.y) + (state.w - 1 - cell.x), Motion.RESET_STAGGER)

## The court as it opens: every stone already at the light it stands in, so
## the entrance is the court arriving and not a wave crossing an empty one.
func _settle() -> void:
	_warm = {}
	for cell in state.white_cells():
		var target := 1.0 if state.lit.has(cell) else 0.0
		_warm[cell] = {"from": target, "to": target, "at": -100.0, "dur": LIGHT_IN}

# --- the drawing ---

func _draw() -> void:
	if _cell <= 0.0 or state.grid.is_empty():
		return
	var now := _now()
	var busy := false
	var shown: Array = []
	if _ground_dirty or now < _anim_until:
		_floor = _build_floor(now)
		var out := _build_ground(now)
		_ground = out.mesh
		busy = out.busy
		_ground_dirty = false
	# The court pops in wide once the chrome has slid in, drawn.
	var since := now - _opened - Motion.ENTER_DELAY
	if since < Motion.ENTER_POP:
		busy = true
	var seen := Motion.appear_level(since)
	if seen > 0.0 and _floor != null:
		var grown := Motion.wide_pop_scale(since)
		draw_mesh(_floor, null,
			Transform2D(0.0, Vector2(grown, grown), 0.0, _court_centre()),
			Color(1.0, 1.0, 1.0, seen))
		shown.append(_floor)
	if _ground != null:
		draw_mesh(_ground, null)
		shown.append(_ground)
	_shown = shown
	_draw_numbers(now)
	if busy:
		_anim_until = maxf(_anim_until, now + 0.1)

## The display: the mortar bed on its edge, a flagstone per cell carrying its
## own warmth -- the stones *are* the display, which is why every one is its
## own tile rather than a tint over a shared field -- and the beams over
## them. Built about the court's centre, so its pop on the entrance is a
## transform.
func _build_floor(now: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var field := Vector2(_cell * state.w, _cell * state.h)
	var origin := -field * 0.5
	# The bed warms toward lamplight once the court is solved.
	var bed := Color(Pal.TEXT, MORTAR_ALPHA)
	if _solved_at > NEVER:
		var won := _dec((now - _solved_at - Motion.SOLVE_DELAY) / WARM_TIME)
		bed = bed.lerp(Color(Pal.SUN, WARM_ALPHA), _sine_io(won))
	b.fan(Face.Builder.round_rect(origin - Vector2.ONE * MORTAR,
		field + Vector2.ONE * 2.0 * MORTAR, MORTAR_RADIUS), bed)
	var gone: Array = []
	for y in state.h:
		for x in state.w:
			if int(state.grid[y][x]) != Gen.WHITE:
				continue
			var cell := Vector2i(x, y)
			var warm := _warmth(cell, now)
			var deep: Color = Pal.FLAGSTONE_DEEP.lerp(Pal.LAMPLIT_DEEP, warm)
			var face: Color = Pal.FLAGSTONE.lerp(Pal.LAMPLIT_FLOOR, warm)
			var tone := (_hash(cell) - 0.5) * 2.0 * STONE_TONE
			face = face.lightened(tone) if tone > 0.0 else face.darkened(-tone)
			# A stone under the finger sinks, drawn (press_scale), and goes
			# a little into its own shade as it does.
			var grown := 1.0
			if _sunk.has(cell):
				var pr: Dictionary = _sunk[cell]
				var released := -1.0 if now < float(pr.up) else now - float(pr.up)
				if released >= Motion.RELEASE_TIME:
					gone.append(cell)
				else:
					grown = Motion.press_scale(now - float(pr.down), released)
					var depth := clampf((1.0 - grown) / (1.0 - Motion.PRESS_SCALE), 0.0, 1.0)
					face = face.lerp(deep, SINK_SHADE * depth)
			b.fan(_tile(cell, 0.0, origin, grown), deep)
			b.fan(_tile(cell, STONE_EDGE, origin, grown), face)
			_dress_stone(b, cell, origin, grown, deep)
			var glint := _glint(cell, now)
			if glint > 0.0:
				b.fan(_tile(cell, STONE_EDGE, origin, grown), Color(1.0, 1.0, 1.0, GLINT_ALPHA * glint))
	for cell in gone:
		_sunk.erase(cell)
	_build_beams(b, now, origin)
	_build_flares(b, now, origin)
	return b.mesh()

## What makes a flagstone a stone and not a tile: a light along its crest,
## and on some a few specks or a hairline crack in its own deep colour. All of
## it is placed off two fixed hashes, so a court is the same court every time
## it is drawn.
func _dress_stone(b, cell: Vector2i, origin: Vector2, grown: float, deep: Color) -> void:
	var centre := origin + (Vector2(cell) + Vector2.ONE * 0.5) * _cell
	var s := _cell * grown
	var wide := s * (1.0 - 2.0 * GAP - 2.0 * STONE_RADIUS)
	var top := centre.y - s * (0.5 - GAP) + s * 0.07
	b.fan(Face.Builder.round_rect(Vector2(centre.x - wide * 0.5, top - s * 0.03), Vector2(wide, s * 0.06),
		s * 0.03), Color(1.0, 1.0, 1.0, CREST_ALPHA))
	var h1 := _hash(cell)
	var h2 := _hash2(cell)
	if h2 < SPECK_SHARE:
		for i in 3:
			var at := Vector2(fposmod(h1 * 7.3 + i * 0.37, 0.56) - 0.28, fposmod(h2 * 5.1 + i * 0.29, 0.44) - 0.24)
			b.ellipse(centre + at * s, s * (0.022 + 0.01 * i), s * (0.018 + 0.008 * i), Color(deep, SPECK_ALPHA))
	elif h2 > 1.0 - CRACK_SHARE:
		var side := 1.0 if h1 > 0.5 else -1.0
		var p0 := centre + Vector2(0.4 * side, -0.1 + h1 * 0.2) * s
		var p1 := centre + Vector2(0.2 * side, 0.02 + h1 * 0.08) * s
		var p2 := centre + Vector2(0.08 * side, 0.2) * s
		b.stroke(PackedVector2Array([p0, p1, p2]), s * 0.022, Color(deep, CRACK_ALPHA))

## How bright the front of the light is on `cell` right now: a sine hump over
## the stone's own warming, and on the win over the solve wave reaching it.
func _glint(cell: Vector2i, now: float) -> float:
	if Motion.reduce:
		return 0.0
	var level := 0.0
	var rec: Dictionary = _warm.get(cell, {})
	if not rec.is_empty() and float(rec.to) > float(rec.from):
		var u := (now - float(rec.at)) / float(rec.dur)
		if u > 0.0 and u < 1.0:
			level = sin(PI * u) * (float(rec.to) - float(rec.from))
	if _solved_at > NEVER:
		var e := (now - _solved_at - _solve_delay(cell)) / WIN_GLINT
		if e > 0.0 and e < 1.0:
			level = maxf(level, sin(PI * e))
	return level

## The wick catching under each lamp that has just landed: a warm disc that
## swells and fades.
func _build_flares(b, now: float, origin: Vector2) -> void:
	var gone: Array = []
	for cell in _flare:
		var u: float = (now - float(_flare[cell])) / FLARE_TIME
		if u >= 1.0:
			gone.append(cell)
			continue
		if u <= 0.0:
			continue
		var r := _cell * FLARE_R * (0.55 + 0.45 * Motion.back_out(u))
		Scenery.soft_disc(b, origin + (Vector2(cell) + Vector2.ONE * 0.5) * _cell, r, r,
			Color(Pal.SUN_RAY, FLARE_ALPHA * (1.0 - u) * (1.0 - u)))
	for cell in gone:
		_flare.erase(cell)

## The wick catches on `cell` at `at`. Under reduce-motion nothing flares.
func _flare_at(cell: Vector2i, at: float) -> void:
	if Motion.reduce:
		return
	_flare[cell] = at
	_anim_until = maxf(_anim_until, at + FLARE_TIME)

## The outline of one stone, `short` of a cell shorter than the joint allows,
## with the court's top-left corner at `origin` and the stone `grown` of its
## size about its own centre: the fill sits on the deeper tile, which is the
## soft lip every card and tile on the flat screens wears.
func _tile(cell: Vector2i, short: float, origin: Vector2, grown := 1.0) -> PackedVector2Array:
	var gap := _cell * GAP
	var span := Vector2(_cell - 2.0 * gap, _cell - 2.0 * gap - _cell * short) * grown
	var centre := origin + (Vector2(cell) + Vector2.ONE * 0.5) * _cell
	return Face.Builder.round_rect(centre - Vector2(span.x, (_cell - 2.0 * gap) * grown) * 0.5,
		span, _cell * STONE_RADIUS * grown)

## The shafts themselves, cell by cell out from each lamp, each one as bright
## as the warmth already painted on the stone it crosses -- so the beam
## travels with the light rather than switching on along the whole line. A
## lamp on its way out keeps its beam, withdrawing with the floor it lit.
func _build_beams(b, now: float, origin: Vector2) -> void:
	var strength := 1.0
	if _solved_at > NEVER:
		strength = lerpf(1.0, WIN_BEAM, _sine_io(_dec((now - _solved_at - Motion.SOLVE_DELAY) / WARM_TIME)))
	for cell in state.lamps():
		_beam(b, cell, now, origin, strength)
	var still: Array = []
	for out in _beam_out:
		var gone := clampf((now - float(out.at)) / LIGHT_OUT, 0.0, 1.0)
		if gone >= 1.0 or state.mark_at(out.cell) == State.LAMP:
			continue
		still.append(out)
		_beam(b, out.cell, now, origin, 1.0 - gone)
	_beam_out = still

## One lamp's four shafts. Each cell's length of shaft fades from the strength
## it enters with to the strength it leaves with, so the fall along the line
## is smooth rather than a stair; a shaft that runs into another lamp is rose
## as far as that lamp.
func _beam(b, cell: Vector2i, now: float, origin: Vector2, strength: float) -> void:
	var half := _cell * BEAM_HALF
	var centre := origin + (Vector2(cell) + Vector2.ONE * 0.5) * _cell
	for d in State.DIRS:
		var run: Array = []
		var p: Vector2i = cell + d
		while state.is_white(p):
			run.append(p)
			p += d
		var seen := run.size()
		if not is_done():
			for i in run.size():
				if state.mark_at(run[i]) == State.LAMP:
					seen = i
					break
		var dv := Vector2(d)
		for i in run.size():
			var q: Vector2i = run[i]
			var warm := _warmth(q, now) * strength
			if warm <= BEAM_MIN:
				continue
			var n := float(i + 1)
			var a0 := warm / (1.0 + BEAM_FALL * (n - 0.5))
			var a1 := warm / (1.0 + BEAM_FALL * (n + 0.5))
			var tint := Color(Pal.BAD, CLASH_ALPHA) if i < seen and seen < run.size() else Color(1.0, 1.0, 1.0, BEAM_ALPHA)
			# From the near edge of the stone to the far one, along the line.
			var from := centre + dv * _cell * (float(i) + 0.5)
			var to := from + dv * _cell
			_shaft(b, from, to, half, Color(tint, tint.a * a0), Color(tint, tint.a * a1))
			_shaft(b, from, to, half * BEAM_CORE,
				Color(1.0, 1.0, 1.0, CORE_ALPHA * a0), Color(1.0, 1.0, 1.0, CORE_ALPHA * a1))

## A length of soft shaft from `from` to `to`, `half` wide each side: clear
## at both sides, `c0` down the middle where it starts and `c1` where it ends.
static func _shaft(b, from: Vector2, to: Vector2, half: float, c0: Color, c1: Color) -> void:
	var side := (to - from).normalized().orthogonal() * half
	var i: int = b.vertex(from - side, Color(c0, 0.0))
	b.vertex(from, c0)
	b.vertex(from + side, Color(c0, 0.0))
	b.vertex(to - side, Color(c1, 0.0))
	b.vertex(to, c1)
	b.vertex(to + side, Color(c1, 0.0))
	b.tri(i, i + 1, i + 4)
	b.tri(i, i + 4, i + 3)
	b.tri(i + 1, i + 2, i + 5)
	b.tri(i + 1, i + 5, i + 4)

## Everything standing on the court that is not a lamp, in one mesh: the
## blush of a pointed-at stone, the shadow under every lamp, the blocks with
## their shadows, and the chips arriving, standing and leaving. Returns the
## mesh and whether any of it is still moving. (A sinking stone is the
## floor's, since the stone itself is what sinks.)
func _build_ground(now: float) -> Dictionary:
	var b := Face.Builder.new()
	var busy := not _sunk.is_empty()
	# The blush: toward the family's rose and back, read off flash_level.
	var gone: Array = []
	for cell in _blush:
		var e: float = now - float(_blush[cell])
		if e >= Motion.FLASH_IN + Motion.FLASH_OUT:
			gone.append(cell)
			continue
		busy = true
		var level := Motion.flash_level(e)
		if level > 0.0:
			_stone_wash(b, cell, 1.0, Color(Pal.BAD_TILE, BLUSH_ALPHA * level))
	for cell in gone:
		_blush.erase(cell)
	# The lamps' shadows, anchored at the stone and read off each lamp's own
	# height, so one arrives with the pop and stays put when the lamp hops.
	for cell in _lamps:
		var lamp: CourtLantern = _lamps[cell]
		if lamp.visible:
			_lamp_shadow(b, lamp, cell)
	# The blocks, each through whatever it is doing.
	for y in state.h:
		for x in state.w:
			if int(state.grid[y][x]) == Gen.WHITE:
				continue
			var cell := Vector2i(x, y)
			var pose := _block_pose(cell, now)
			if pose.is_empty():
				continue
			busy = busy or bool(pose.busy)
			_block(b, cell, pose, now)
	# Chips on their way out, drawn from the shape the state has forgotten.
	var still: Array = []
	for out in _chip_out:
		var e: float = now - float(out.at)
		var shrunk := Motion.pop_out_scale(e)
		if shrunk <= 0.0:
			continue
		still.append(out)
		busy = true
		var turn := PI * 0.5 * clampf(e / Motion.POP_OUT, 0.0, 1.0)
		_chip(b, cell_to_local(out.cell.y, out.cell.x), _cell * CHIP_SIZE,
			Vector2(shrunk, shrunk), turn, 1.0)
	_chip_out = still
	# The chips that are here: popping in with the squash, standing, or
	# clearing away on the win.
	gone = []
	for cell in state.marks:
		if int(state.marks[cell]) != State.CHIP:
			continue
		var grow := Vector2.ONE
		if _chip_in.has(cell):
			var e: float = now - float(_chip_in[cell])
			grow = Motion.pop_in_scale(e)
			if e < Motion.POP_IN:
				busy = true
			else:
				gone.append(cell)
		var alpha := 1.0
		if _solved_at > NEVER:
			var cleared := _dec((now - _solved_at - CLEAR_DELAY - _hash(cell) * CLEAR_SPREAD) / CLEAR_TIME)
			if cleared >= 1.0:
				continue
			busy = true
			alpha = 1.0 - cleared
			grow *= 1.0 - cleared * CLEAR_SHRINK
		if grow.x <= 0.0 or grow.y <= 0.0:
			continue
		_chip(b, cell_to_local(cell.y, cell.x), _cell * CHIP_SIZE, grow, 0.0, alpha)
	for cell in gone:
		_chip_in.erase(cell)
	if b.verts.is_empty():
		return {"mesh": null, "busy": busy}
	return {"mesh": b.mesh(), "busy": busy}

## A stone's own outline over `cell`, `grown` of its size about its centre.
func _stone_wash(b, cell: Vector2i, grown: float, colour: Color) -> void:
	if grown <= 0.0:
		return
	var span := (_cell - 2.0 * _cell * GAP) * grown
	b.fan(Face.Builder.round_rect(cell_to_local(cell.y, cell.x) - Vector2.ONE * span * 0.5,
		Vector2.ONE * span, _cell * STONE_RADIUS * grown), colour)

## The family's soft disc under `lamp` on `cell`, scaled by how much of the
## lamp is there and faded with it while it drops in.
func _lamp_shadow(b, lamp: Control, cell: Vector2i) -> void:
	var seen := clampf(lamp.scale.y, 0.0, 1.0) * clampf(lamp.modulate.a, 0.0, 1.0)
	if seen <= 0.0:
		return
	Scenery.soft_disc(b, cell_to_local(cell.y, cell.x) + LAMP_SHADOW_AT * _cell,
		LAMP_SHADOW_RX * _cell * seen, LAMP_SHADOW_RY * _cell * seen,
		Color(Pal.TEXT, SHADOW_ALPHA * seen))

## What a block is doing right now, read off the curves: its scale (the
## entrance pop, the press, the Count bump), its offset (a hop, a lean, a
## shiver) and its flash toward rose. Empty before it has entered. Finished
## moments are forgotten here, so the dictionaries never grow.
func _block_pose(cell: Vector2i, now: float) -> Dictionary:
	var scale := Motion.pop_in_scale(now - _opened - _enter_delay(cell.x + cell.y))
	if scale.x <= 0.0 or scale.y <= 0.0:
		return {}
	var busy := now < _opened + _enter_delay(cell.x + cell.y) + Motion.POP_IN
	var offset := Vector2.ZERO
	var flash := 0.0
	if _block_press.has(cell):
		var pr: Dictionary = _block_press[cell]
		var released := -1.0 if is_inf(float(pr.up)) else now - float(pr.up)
		if released >= Motion.RELEASE_TIME:
			_block_press.erase(cell)
		else:
			scale *= Motion.press_scale(now - float(pr.down), released)
			busy = true
	if _block_bump.has(cell):
		var e: float = now - float(_block_bump[cell])
		if e >= Motion.BUMP_TIME:
			_block_bump.erase(cell)
		else:
			scale *= Motion.bump_scale(e)
			busy = true
	if _block_hop.has(cell):
		var hp: Dictionary = _block_hop[cell]
		var e: float = now - float(hp.at)
		if e >= float(hp.time):
			_block_hop.erase(cell)
		else:
			offset.y += Motion.hop_lift(e, float(hp.height), float(hp.time))
			busy = true
	if _block_nudge.has(cell):
		var nd: Dictionary = _block_nudge[cell]
		var e: float = now - float(nd.at)
		if e >= Motion.NUDGE_LAG + Motion.NUDGE_TIME:
			_block_nudge.erase(cell)
		else:
			offset += (nd.dir as Vector2) * Motion.nudge_offset(e)
			busy = true
	if _block_shiver.has(cell):
		var e: float = now - float(_block_shiver[cell])
		if e >= Motion.SHIVER_TIME:
			_block_shiver.erase(cell)
		else:
			offset.x += Motion.shiver_offset(e, _cell * SHIVER)
			busy = true
	if _block_flash.has(cell):
		var e: float = now - float(_block_flash[cell])
		if e >= Motion.FLASH_IN + Motion.FLASH_OUT:
			_block_flash.erase(cell)
		else:
			flash = Motion.flash_level(e)
			busy = true
	return {"scale": scale, "offset": offset, "flash": flash, "busy": busy}

## A block of rough stone through its pose: its shadow on the ground first,
## anchored at the stone so a hop leaves it behind, then the block about its
## own centre put through the pose's transform. A block with no number has
## nothing to be satisfied about, so it never goes green: half of a generated
## court's stone says nothing, and a blank block is information too -- it
## stops the light.
func _block(b, cell: Vector2i, pose: Dictionary, now: float) -> void:
	var s := _cell * BLOCK_SIZE
	var at := cell_to_local(cell.y, cell.x)
	var scale: Vector2 = pose.scale
	var seen := clampf(scale.y, 0.0, 1.0)
	Scenery.soft_disc(b, at + BLOCK_SHADOW_AT * s, BLOCK_SHADOW_RX * s * seen,
		BLOCK_SHADOW_RY * s * seen, Color(Pal.TEXT, BLOCK_SHADOW_ALPHA * seen))
	var face: Color = Pal.BLOCK_STONE
	var deep: Color = Pal.BLOCK_DEEP
	match state.block_state(cell):
		State.BLOCK_OK:
			face = face.lerp(Pal.LEAF, BLOCK_GREEN)
			deep = deep.lerp(Pal.LEAF_DEEP, BLOCK_GREEN)
		State.BLOCK_OVER:
			face = face.lerp(Pal.BAD, BLOCK_ROSE)
			deep = deep.lerp(Pal.MARKER_DEEP, BLOCK_ROSE)
	var flash := float(pose.flash)
	if flash > 0.0:
		# A refused tap: the block flashes toward its own rose, the way a
		# drawn bed flashes toward its blush.
		face = face.lerp(Pal.BAD, BLOCK_ROSE * flash)
		deep = deep.lerp(Pal.MARKER_DEEP, BLOCK_ROSE * flash)
	var xf := Transform2D(0.0, scale, 0.0, at + (pose.offset as Vector2))
	_shape(b, xf, Face.Builder.round_rect(-Vector2.ONE * 0.46 * s, Vector2.ONE * 0.92 * s, 0.15 * s), deep)
	_shape(b, xf, Face.Builder.round_rect(-Vector2.ONE * 0.46 * s, Vector2(0.92, 0.8) * s, 0.15 * s), face)
	# Cut stone, lit from up and left: the right side of the crown in shade,
	# a bevel of light along the top and down the left.
	_shape(b, xf, Face.Builder.round_rect(Vector2(0.22, -0.46) * s, Vector2(0.24, 0.8) * s, 0.15 * s),
		Color(0.0, 0.0, 0.0, 0.1))
	_line(b, xf, [Vector2(-0.3, -0.4), Vector2(0.28, -0.4)], s, 0.045, Color(1.0, 1.0, 1.0, 0.16))
	_line(b, xf, [Vector2(-0.4, -0.3), Vector2(-0.4, 0.2)], s, 0.04, Color(1.0, 1.0, 1.0, 0.09))
	if int(state.grid[cell.y][cell.x]) >= 0:
		# The number is carved into a plaque sunk in the crown, with the light
		# catching the plaque's lower lip.
		_shape(b, xf, Face.Builder.round_rect(Vector2(-0.25, -0.31) * s, Vector2(0.5, 0.5) * s, 0.14 * s),
			Color(deep, 0.55))
		_line(b, xf, [Vector2(-0.14, 0.2), Vector2(0.14, 0.2)], s, 0.035, Color(1.0, 1.0, 1.0, 0.12))
	else:
		# A blank block wears two chisel marks instead.
		var h := _hash(cell)
		_scratch(b, xf, [Vector2(-0.2 + 0.1 * h, -0.12), Vector2(0.02 + 0.1 * h, -0.02)], s, 0.035,
			Color(0.0, 0.0, 0.0, 0.14))
		_scratch(b, xf, [Vector2(-0.06, 0.12 - 0.1 * h), Vector2(0.14, 0.2 - 0.1 * h)], s, 0.03,
			Color(0.0, 0.0, 0.0, 0.1))
	# The light the lit stones beside it throw on its sides.
	for d in State.DIRS:
		var n: Vector2i = cell + d
		if not state.is_white(n):
			continue
		var warm := _warmth(n, now)
		if warm <= BEAM_MIN:
			continue
		var along := Vector2(d).orthogonal() * 0.3
		# A side is centred on the crown; the bottom is the front face's hem.
		var edge := Vector2(d) * 0.44
		if d.x != 0:
			edge.y = -0.06
		_line(b, xf, [edge - along, edge + along], s, RIM_WIDTH, Color(Pal.SUN_RAY, RIM_ALPHA * warm))

## The chip the player has ruled a stone out with: cool slate, never a small
## warm block of the court's own stone. Drawn about `at` through `grow` and
## `turn`, so a pop is a transform on the same shapes; its shadow scales with
## it and does not turn.
func _chip(b, at: Vector2, s: float, grow: Vector2, turn: float, alpha: float) -> void:
	var seen := clampf(grow.y, 0.0, 1.0)
	Scenery.soft_disc(b, at + CHIP_SHADOW_AT * s * grow.y, CHIP_SHADOW_RX * s * grow.x,
		CHIP_SHADOW_RY * s * grow.y, Color(Pal.TEXT, SHADOW_ALPHA * alpha * seen))
	var xf := Transform2D(turn, grow, 0.0, at)
	_shape(b, xf, Face.Builder.round_rect(Vector2(-0.26, -0.16) * s, Vector2(0.52, 0.3) * s, 0.09 * s),
		Color(Pal.CHIP_DEEP, alpha))
	_shape(b, xf, Face.Builder.round_rect(Vector2(-0.26, -0.16) * s, Vector2(0.52, 0.24) * s, 0.09 * s),
		Color(Pal.CHIP, alpha))
	_shape(b, xf, Face.Builder.round_rect(Vector2(-0.19, -0.11) * s, Vector2(0.2, 0.07) * s, 0.035 * s),
		Color(1.0, 1.0, 1.0, 0.16 * alpha))

## A straight bar on a piece from `a` to `b_` (axis-aligned), `width` thick,
## all in units of `s`, rounded at its ends and put through the piece's
## transform. A fan rather than a stroke: a stroke's round caps overlap its
## body and double the alpha at each end, which on a highlight reads as a
## groove.
func _line(b, xf: Transform2D, pts: Array, s: float, width: float, colour: Color) -> void:
	var a: Vector2 = pts[0]
	var z: Vector2 = pts[1]
	var lo := Vector2(minf(a.x, z.x), minf(a.y, z.y)) - Vector2.ONE * width * 0.5
	var hi := Vector2(maxf(a.x, z.x), maxf(a.y, z.y)) + Vector2.ONE * width * 0.5
	_shape(b, xf, Face.Builder.round_rect(lo * s, (hi - lo) * s, width * 0.5 * s), colour)

## A mark at any angle on a piece, flat-ended so no cap doubles its ends.
func _scratch(b, xf: Transform2D, pts: Array, s: float, width: float, colour: Color) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(xf * ((p as Vector2) * s))
	b.stroke(out, width * s * absf(xf.get_scale().y), colour, false, false)

## One shape of a piece, put through the piece's transform.
func _shape(b, xf: Transform2D, pts: PackedVector2Array, colour: Color) -> void:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = xf * pts[i]
	b.fan(out, colour)

## The numerals, over the court's meshes, each through its block's own pose
## so a number squashes, sinks, bumps and hops with the stone it is carved
## on. One draw_string each rather than geometry in the cache: a hard court
## carries about seven of them, and a digit in a mesh key would multiply
## every block state by five.
func _draw_numbers(now: float) -> void:
	if _cell <= 0.0 or state.grid.is_empty():
		return
	var font: Font = CozyTheme.display(700)
	var s := _cell * BLOCK_SIZE
	var px := int(roundf(s * NUM_SIZE))
	if px <= 0:
		return
	for y in state.h:
		for x in state.w:
			var number := int(state.grid[y][x])
			if number < 0:
				continue
			var cell := Vector2i(x, y)
			var pose := _block_pose(cell, now)
			if pose.is_empty():
				continue
			var ink: Color = Pal.BLOCK_NUM
			if state.block_state(cell) != State.BLOCK_IDLE:
				ink = Color.WHITE
			var text := str(number)
			var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
			draw_set_transform(cell_to_local(y, x) + (pose.offset as Vector2), 0.0, pose.scale as Vector2)
			draw_string(font, Vector2(-wide * 0.5, font.get_ascent(px) * 0.5 - 0.02 * s), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, ink)
	draw_set_transform(Vector2.ZERO)

# --- input ---

## Touch and drag only, as every flat board takes them. A tap sets a lantern
## down, takes one up or clears a chip; a drag sweeps chips, and its direction
## is read off the stone it started on.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(_cell_at(event.position))
		else:
			_release()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _press_cell.x >= 0:
		_drag(event.position)

## The press: a lamp sinks under the finger, and so does a block, drawn, and
## so does a bare stone or a chip's -- the stone itself. Every tappable stone
## does this, including one that will refuse on release.
func _press(cell: Vector2i) -> void:
	_release_press()
	_clear_gesture()
	if is_done() or cell.x < 0:
		return
	_press_cell = cell
	var now := _now()
	if state.mark_at(cell) == State.LAMP and _lamps.has(cell):
		_pressed = _lamps[cell]
		Motion.stop(_look_tw.get(_pressed))
		_look_tw[_pressed] = Motion.press(_pressed, true)
		_busy_for(Motion.PRESS_TIME)
	elif not state.is_white(cell):
		_block_press[cell] = {"down": now, "up": INF}
		_busy_for(Motion.PRESS_TIME)
	else:
		_sunk[cell] = {"down": now, "up": INF}
		_busy_for(Motion.PRESS_TIME)
	_redraw()

## Whatever the finger sank springs back, on release or when the finger
## leaves it for a sweep.
func _release_press() -> void:
	if _pressed != null:
		Motion.stop(_look_tw.get(_pressed))
		_look_tw[_pressed] = Motion.press(_pressed, false)
		_busy_for(Motion.RELEASE_TIME)
		_pressed = null
	var now := _now()
	for cell in _block_press:
		var pr: Dictionary = _block_press[cell]
		if is_inf(float(pr.up)):
			pr.up = now
			_busy_for(Motion.RELEASE_TIME)

func _drag(at: Vector2) -> void:
	var cell := _cell_at(at)
	if cell.x < 0:
		return
	if not _dragged and cell != _press_cell:
		_dragged = true
		# Begin on a chip and the sweep rubs out; begin anywhere else and it
		# lays.
		_lay = state.mark_at(_press_cell) != State.CHIP
		_release_press()
		_paint(_press_cell)
	if not _dragged:
		return
	# Every stone between the last one painted and this one, so a fast finger
	# does not leave holes in its run. The mock paints only what it is handed.
	if _last_paint.x >= 0:
		var steps := maxi(absi(cell.x - _last_paint.x), absi(cell.y - _last_paint.y))
		for i in range(1, steps):
			_paint(Vector2i(
				roundi(lerpf(_last_paint.x, cell.x, float(i) / steps)),
				roundi(lerpf(_last_paint.y, cell.y, float(i) / steps))))
	_paint(cell)
	_redraw()

## A sweep never disturbs a lantern or a block: the gesture is for ruling
## stones out, and losing a lamp to a stray finger would be the worst bug on
## the board. The stones the finger can change sink under it as it passes.
func _paint(cell: Vector2i) -> void:
	_last_paint = cell
	if _swept.has(cell):
		return
	_swept[cell] = true
	if state.fixed(cell) or state.mark_at(cell) == State.LAMP:
		return
	if not _sunk.has(cell):
		_sunk[cell] = {"down": _now(), "up": INF}
		_busy_for(Motion.PRESS_TIME)
	var to := State.CHIP if _lay else State.BLANK
	if state.mark_at(cell) == to:
		return
	_pending.append({"cell": cell, "to": to})

func _release() -> void:
	var cell := _press_cell
	var was_drag := _dragged
	var pending := _pending
	var now := _now()
	_release_press()
	_clear_gesture()
	if cell.x < 0 or is_done():
		_end_sinks(now)
		_redraw()
		return
	if was_drag:
		var arrivals: Dictionary = {}
		if not pending.is_empty():
			var before: Dictionary = state.marks.duplicate()
			# One gesture is one move, however many stones it touched; the
			# chips arrive in a wave along the finger's path. Chips change no
			# light, and a swept run has no one place to travel from anyway.
			arrivals = _commit(before, state.apply(pending), now, Motion.ENTER_STAGGER, Vector2i(-1, -1))
		_end_sinks(now, arrivals)
		_redraw()
		return
	if state.fixed(cell):
		# A block's stone, or a lamp a hint lit: a shiver, a blush and a
		# word, rather than a move.
		_refuse(cell)
		_end_sinks(now)
		_redraw()
		return
	var before: Dictionary = state.marks.duplicate()
	var arrivals := _commit(before, state.tap(cell), now, 0.0, cell)
	_end_sinks(now, arrivals)
	_redraw()

## Puts the stones `changed` by a move on the screen (see _transition), sends
## the light out from `from` when the move has one stone it came from, and
## counts the move. A tap that set a lamp down also puffs and leans the
## neighbours away. Returns each stone's arrival time.
func _commit(before: Dictionary, changed: Array, t: float, per: float, from: Vector2i) -> Dictionary:
	if changed.is_empty():
		_redraw()
		return {}
	var arrivals := _transition(before, changed, t, per)
	if from.x >= 0:
		_relight(t, _travel_from(from))
		if state.mark_at(from) == State.LAMP:
			fx.puff(cell_to_local(from.y, from.x), Pal.SUN)
			_nudge_around(from, t)
	else:
		_relight(t, _at_once)
	fx.cue("place")
	_speak()
	_redraw()
	note_move()
	return arrivals

func _clear_gesture() -> void:
	_press_cell = Vector2i(-1, -1)
	_pressed = null
	_dragged = false
	_lay = true
	_swept = {}
	_pending = []
	_last_paint = Vector2i(-1, -1)

## Lets go of every stone the gesture still holds down: each springs back
## when the piece it is under arrives, or now.
func _end_sinks(now: float, arrivals: Dictionary = {}) -> void:
	var last := now
	for cell in _sunk:
		var pr: Dictionary = _sunk[cell]
		if is_inf(float(pr.up)):
			pr.up = float(arrivals.get(cell, now))
			last = maxf(last, float(pr.up))
	_anim_until = maxf(_anim_until, last + Motion.RELEASE_TIME)

# --- what the pieces do ---

## Every stone in `cells` moves from what `before` had on it to what the
## state has now, the k-th one `per` seconds after the first: a lamp pops in
## or out, a chip arrives or leaves, and each numbered block a lamp joined or
## left is recounted. Returns the second each stone's piece arrives.
func _transition(before: Dictionary, cells: Array, t: float, per: float, drop := false) -> Dictionary:
	var arrivals: Dictionary = {}
	for k in cells.size():
		var cell: Vector2i = cells[k]
		var at := t + Motion.stagger(k, per)
		arrivals[cell] = at
		var prev := int(before.get(cell, State.BLANK))
		var mark := state.mark_at(cell)
		if prev == mark:
			continue
		if prev == State.CHIP:
			_chip_leaves(cell, at)
		elif prev == State.LAMP:
			_lamp_down(cell, at - t)
		if mark == State.CHIP:
			_chip_arrives(cell, at)
		elif mark == State.LAMP:
			_lamp_up(cell, at - t, drop)
		if prev == State.LAMP or mark == State.LAMP:
			_recount_around(cell, at)
	_refresh_faces()
	return arrivals

## A lamp goes down on `cell`: it pops in with the squash after `delay`, or
## drops in from above when a hint lit it.
func _lamp_up(cell: Vector2i, delay: float, drop: bool) -> void:
	var lamp := _lamp_node(cell)
	lamp.visible = true
	Motion.stop(_look_tw.get(lamp))
	Motion.stop(_pos_tw.get(lamp))
	lamp.rotation = 0.0
	lamp.position = Vector2.ZERO
	lamp.modulate.a = 1.0
	if drop:
		lamp.scale = Vector2.ONE
		_pos_tw[lamp] = Motion.drop_in(lamp, Motion.DROP, Motion.DROP_TIME, delay)
		_busy_for(delay + Motion.DROP_TIME)
		_flare_at(cell, _now() + delay + Motion.DROP_TIME * 0.8)
	else:
		_look_tw[lamp] = Motion.pop_in(lamp, Motion.POP_IN, delay)
		_busy_for(delay + Motion.POP_IN)
		_flare_at(cell, _now() + delay)

## A lamp comes up off `cell`: it shrinks to nothing with the quarter turn
## after `delay`, its beam withdrawing with the floor, and is hidden once gone
## unless something put it back.
func _lamp_down(cell: Vector2i, delay: float) -> void:
	var lamp: CourtLantern = _lamps.get(cell)
	if lamp == null:
		return
	Motion.stop(_look_tw.get(lamp))
	var tw := Motion.pop_out(lamp, Motion.POP_OUT, delay)
	if tw == null:
		lamp.visible = false
		return
	_beam_out.append({"cell": cell, "at": _now() + delay})
	_look_tw[lamp] = tw
	_busy_for(delay + maxf(Motion.POP_OUT, LIGHT_OUT))
	tw.chain().tween_callback(func() -> void:
		if state.mark_at(cell) != State.LAMP:
			lamp.visible = false
			lamp.rotation = 0.0)

func _chip_arrives(cell: Vector2i, at: float) -> void:
	_chip_in[cell] = at
	_anim_until = maxf(_anim_until, at + Motion.POP_IN)

## A chip leaves `cell` from `at`. Under reduce-motion it is simply gone, as
## pop_out would have it.
func _chip_leaves(cell: Vector2i, at: float) -> void:
	_chip_in.erase(cell)
	if Motion.reduce:
		return
	_chip_out.append({"cell": cell, "at": at})
	_anim_until = maxf(_anim_until, at + Motion.POP_OUT)

## The Count moment: every numbered block beside `cell` has just been
## recounted, and bumps as the lamp arrives or leaves.
func _recount_around(cell: Vector2i, at: float) -> void:
	if Motion.reduce:
		return
	for d in State.DIRS:
		var n: Vector2i = cell + d
		if state.in_field(n) and int(state.grid[n.y][n.x]) >= 0:
			_block_bump[n] = at
	_busy_for(at - _now() + Motion.BUMP_TIME)

## A stone blushes toward the family's rose and settles: Check pointing at
## its lamp, or a tap refused on a pinned one.
func _blush_stone(cell: Vector2i) -> void:
	if Motion.reduce:
		return
	_blush[cell] = _now()
	_busy_for(Motion.FLASH_IN + Motion.FLASH_OUT)

## The blocks and lamps beside a lamp that has just been set down lean away
## from it and back. A lamp already mid-hop is left to land.
func _nudge_around(cell: Vector2i, t: float) -> void:
	for d in State.DIRS:
		var n: Vector2i = cell + d
		if not state.in_field(n):
			continue
		if not state.is_white(n):
			if not Motion.reduce:
				_block_nudge[n] = {"at": t, "dir": Vector2(d)}
		elif state.mark_at(n) == State.LAMP and _lamps.has(n):
			var lamp: CourtLantern = _lamps[n]
			if Motion.running(_pos_tw.get(lamp)):
				continue
			_pos_tw[lamp] = Motion.nudge(lamp, Vector2(d), Vector2.ZERO)
	_busy_for(Motion.NUDGE_LAG + Motion.NUDGE_TIME)

## `lamp` hops `height` over `time` after `delay`; it rests at its slot's
## origin, so the base is always zero.
func _hop(lamp: Control, height: float, time: float, delay := 0.0) -> void:
	Motion.stop(_pos_tw.get(lamp))
	lamp.position = Vector2.ZERO
	_pos_tw[lamp] = Motion.hop(lamp, height, time, delay, 0.0)
	_busy_for(delay + time)

## Check pointing at a lamp: it wobbles where it stands.
func _wobble(lamp: Control) -> void:
	Motion.stop(_look_tw.get(lamp))
	lamp.rotation = 0.0
	lamp.scale = Vector2.ONE
	_look_tw[lamp] = Motion.wobble2d(lamp)
	_busy_for(Motion.WOBBLE_TIME)

## A tap refused on `cell`: a block shivers and flashes toward its rose; a
## pinned lamp shivers while its stone blushes; the sprout says why.
func _refuse(cell: Vector2i) -> void:
	_say(tr("LU_REFUSE_BLOCK")
		if not state.is_white(cell)
		else tr("LU_REFUSE_PINNED"), Face.Expr.PUZZLED)
	fx.cue("locked")
	var now := _now()
	if not state.is_white(cell):
		if Motion.reduce:
			return
		_block_shiver[cell] = now
		_block_flash[cell] = now
		_busy_for(maxf(Motion.SHIVER_TIME, Motion.FLASH_IN + Motion.FLASH_OUT))
		return
	_blush_stone(cell)
	var lamp: CourtLantern = _lamps.get(cell)
	if lamp == null:
		return
	Motion.stop(_pos_tw.get(lamp))
	lamp.position = Vector2.ZERO
	_pos_tw[lamp] = Motion.shiver(lamp, _cell * SHIVER)
	_busy_for(Motion.SHIVER_TIME)

# --- the sprout's line ---

## What the tip card says: the rules while the court is dark, then whichever
## rule the board can currently see being broken, then the count of stones
## still in the dark -- which is the one rule the court itself has no marker
## for.
func _speak() -> void:
	if is_done():
		return
	var seen: int = state.clash.size()
	if seen > 0:
		_say(tr("LU_SEEN_TWO") if seen <= 2
			else tr("LU_SEEN_N") % seen, Face.Expr.STRAIN)
		return
	var over := state.over_blocks()
	if over > 0:
		_say(tr("LU_OVER_ONE") if over == 1
			else tr("LU_OVER_N") % over,
			Face.Expr.STRAIN)
		return
	var dark := state.dark()
	if dark > 0:
		_say(tr("LU_DARK_ONE") if dark == 1
			else tr("LU_DARK_N") % dark, Face.Expr.HAPPY)
		return
	_say(tr("LU_UNSATISFIED"), Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal.
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _tip_mood != Face.Expr.HAPPY or not state.marks.is_empty():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not state.history.is_empty()

## Takes back the last gesture, however many stones it swept: the reverse of
## Place, stone by stone along the same path. Counts no move.
func undo() -> bool:
	if is_done() or state.history.is_empty():
		return false
	var now := _now()
	var before: Dictionary = state.marks.duplicate()
	_transition(before, state.undo(), now, Motion.ENTER_STAGGER)
	_relight(now, _at_once)
	_speak()
	fx.cue("undo")
	_redraw()
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Lights one lantern from the answer and pins it for good: a ring pulses out
## of the stone, the lamp drops in from above, sparkles rise, and the light
## travels out from it. Counts no move but can finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var before: Dictionary = state.marks.duplicate()
	var target: Vector2i = state.hint()
	if target.x < 0:
		return false
	var now := _now()
	hints_used += 1
	_transition(before, [target], now, 0.0, true)
	_relight(now, _travel_from(target))
	var at := cell_to_local(target.y, target.x)
	fx.ring(at, _cell * 0.5, Pal.LEAF)
	fx.sparkle(at, Pal.LEAF)
	fx.cue("hint")
	_say(tr("LU_PINNED"), Face.Expr.HAPPY)
	_redraw()
	moved.emit()
	check_solved()
	return true

## Every lantern the answer does not put there wobbles and its stone blushes,
## and the sprout says how many.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong: Array = state.wrong_lamps()
	for cell in wrong:
		if _lamps.has(cell):
			_wobble(_lamps[cell])
		_blush_stone(cell)
	_say((tr("LU_WRONG_ONE") if wrong.size() == 1 else tr("LU_WRONG_N")) % wrong.size()
		if not wrong.is_empty() else tr("LU_ALL_RIGHT"),
		Face.Expr.STRAIN if not wrong.is_empty() else Face.Expr.JOY)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	_redraw()
	return wrong.size()

## Every lamp and chip goes, in a wave from the far corner, the light cooling
## in the same wave and the blocks hopping as the court clears around them.
## The hints a player spent are not refunded, only unpinned.
func reset_board() -> void:
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	var before: Dictionary = state.marks.duplicate()
	var cleared := state.reset()
	for cell in cleared:
		var at: float = now + _reset_wave(cell)
		if int(before[cell]) == State.CHIP:
			_chip_leaves(cell, at)
		else:
			_lamp_down(cell, at - now)
			_recount_around(cell, at)
	if not Motion.reduce:
		for y in state.h:
			for x in state.w:
				if int(state.grid[y][x]) != Gen.WHITE:
					var cell := Vector2i(x, y)
					_block_hop[cell] = {"at": now + _reset_wave(cell), "height": Motion.RESET_HOP,
						"time": Motion.HOP_TIME}
		_busy_for(_reset_wave(Vector2i.ZERO) + Motion.HOP_TIME)
	_relight(now, _reset_wave)
	_blush = {}
	_chip_in = {}
	_block_flash = {}
	_flare = {}
	_block_shiver = {}
	moves = 0
	_running = true
	_refresh_faces()
	_say(tr("LU_RESET"),
		Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	_redraw()

## A completed daily is rebuilt from its seed, so the court opens dark. Set the
## generator's lanterns back down and settle everything as the finished solve
## leaves it: every stone already warm, every beam drawn, every numbered block
## satisfied, every lamp standing and grinning, no chips and no entrance. Not
## check_solved(): the host owns the win presentation for a daily that was
## already solved.
func restore_completed_board() -> void:
	var now := _now()
	_stop_all()
	_clear_gesture()
	_tip_timer.stop()
	state.marks = {}
	state.locked = {}
	state.history.clear()
	for cell in state.solution:
		state.marks[cell] = State.LAMP
	state.recompute()
	# Every stone straight to the light it stands in, with no wave crossing.
	_settle()
	_beam_out = []
	_chip_in = {}
	_chip_out = []
	_blush = {}
	_sunk = {}
	_block_press = {}
	_block_bump = {}
	_block_hop = {}
	_block_nudge = {}
	_block_shiver = {}
	_block_flash = {}
	_flare = {}
	# The entrance and the clearing both long over.
	_opened = now - 10.0
	_solved_at = now - 10.0
	_anim_until = 0.0
	for cell in _lamps:
		_lamps[cell].visible = false
	for cell in state.solution:
		var lamp := _lamp_node(cell)
		lamp.visible = true
		lamp.position = Vector2.ZERO
		lamp.rotation = 0.0
		lamp.scale = Vector2.ONE
		lamp.modulate.a = 1.0
		lamp.expression = Face.Expr.JOY
	_refresh_faces()
	_say(tr("LU_WIN"), Face.Expr.JOY)
	_redraw()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

# --- the win ---

## The board is the answer, so the win screen shows no cast: the lit court
## stays on the card under it.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("LU_WIN")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## Every lamp and block hops the solve wave along the diagonal, each lamp
## grinning as the wave reaches it with a spark, and the chips clear away in
## a scatter behind them.
func _on_solved() -> void:
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	_tip_timer.stop()
	_solved_at = now
	var k := 0
	for cell in state.lamps():
		var lamp := _lamp_node(cell)
		var delay := _solve_delay(cell)
		_hop(lamp, Motion.SOLVE_HOP, Motion.SOLVE_TIME, delay)
		_grin(lamp, delay)
		_flare_at(cell, now + delay)
		_after(delay, _spark_at.bind(k, cell_to_local(cell.y, cell.x)))
		k += 1
	if not Motion.reduce:
		for y in state.h:
			for x in state.w:
				if int(state.grid[y][x]) != Gen.WHITE:
					var cell := Vector2i(x, y)
					_block_hop[cell] = {"at": now + _solve_delay(cell), "height": Motion.SOLVE_HOP,
						"time": Motion.SOLVE_TIME}
	_refresh_faces()
	_say(tr("LU_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_busy_for(maxf(_solve_delay(Vector2i(state.w, state.h)) + maxf(Motion.SOLVE_TIME, WIN_GLINT),
		maxf(CLEAR_DELAY + CLEAR_SPREAD + CLEAR_TIME, Motion.SOLVE_DELAY + WARM_TIME)))
	_redraw()

func _solve_delay(cell: Vector2i) -> float:
	if Motion.reduce:
		return 0.0
	return Motion.SOLVE_DELAY + Motion.stagger(cell.x + cell.y, Motion.SOLVE_STAGGER)

## `lamp` goes to JOY as the wave reaches it; at once under reduce-motion.
func _grin(lamp: Face, delay: float) -> void:
	if delay <= 0.0:
		lamp.expression = Face.Expr.JOY
	else:
		_after(delay, func() -> void: lamp.expression = Face.Expr.JOY)

## A spark as lamp `k` hops. The two pools are used in turn: a run of ten a
## few hundredths apart would otherwise recycle one pool fast enough to cut
## each burst in half.
func _spark_at(k: int, at: Vector2) -> void:
	if k % 2 == 0:
		fx.sparkle(at, Pal.SUN)
	else:
		fx.puff(at, Pal.SUN, 4)

# --- entrance ---

## The chrome is the host's; here the court pops in wide and the blocks pop
## onto it a beat later with the squash, along the diagonal from the top-left
## corner, each block's number and shadow arriving with it.
func _enter() -> void:
	_opened = _now()
	var far := 0
	for y in state.h:
		for x in state.w:
			if int(state.grid[y][x]) != Gen.WHITE:
				far = maxi(far, x + y)
	_busy_for(maxf(_enter_delay(far) + Motion.POP_IN, Motion.ENTER_DELAY + Motion.ENTER_POP))
	fx.cue("enter")

func _enter_delay(diagonal: int) -> float:
	return Motion.ENTER_DELAY + Motion.ENTER_FACE_LAG + Motion.stagger(diagonal, Motion.ENTER_STAGGER)

# --- odds and ends ---

## Kills every tween the previous board still tracks and retires its pending
## callbacks, so a rebuild never inherits a hop aimed at a lamp that is gone.
func _stop_all() -> void:
	_gen += 1
	for tw in _pos_tw.values():
		Motion.stop(tw)
	for tw in _look_tw.values():
		Motion.stop(tw)
	_pos_tw = {}
	_look_tw = {}

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	var gen := _gen
	get_tree().create_timer(maxf(delay, 0.0)).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

## Keeps the court redrawing for `seconds` more: something on it, a shadow's
## owner or the light is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

func _process(delta: float) -> void:
	super(delta)
	var now := _now()
	if now < _anim_until:
		_place_light(now)
		queue_redraw()

## Something on the court changed: rebuild it on the next draw.
func _redraw() -> void:
	_ground_dirty = true
	_place_light(_now())
	queue_redraw()

## Seconds since the scene started, the clock every animation here reads.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _dec(u: float) -> float:
	return 1.0 if Motion.reduce else clampf(u, 0.0, 1.0)

## The light's own easing: in and out, so a stone warms the way a lamp is
## carried in rather than the way a switch is thrown.
static func _sine_io(u: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(u, 0.0, 1.0))

## A fixed pseudo-random number per stone, so the chips clear away in a
## scatter rather than a wave.
static func _hash(cell: Vector2i) -> float:
	return float(posmod(hash(cell), 1000)) / 1000.0

## A second one, independent of the first, for a stone's dressing.
static func _hash2(cell: Vector2i) -> float:
	return float(posmod(hash(cell * 7 + Vector2i(3, 11)), 997)) / 997.0
