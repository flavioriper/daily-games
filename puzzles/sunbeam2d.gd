extends "res://core/puzzle_base.gd"

## Sunbeam as a flat board: a greenhouse floor at morning, the sun coming in
## through a gap in the glass as one golden beam, and a handful of brass
## mirrors and copper cups riding wooden rails across the floor. Drag a piece
## along its rail and the light follows it live; light every dewdrop, then end
## the beam in the bud, which blooms. The rules live in
## puzzles/sunbeam_state.gd, which this only draws.
##
## **Nothing wrong can sit on this floor**: the beam is traced after every
## step of a drag and *is* the check. So no Check, no tray and no actions row:
## Undo, Reset and Hint ride in the top bar and the tip card stands alone --
## Pinwheel's shape.
##
## How it is drawn. Five meshes:
##   glass -- the glass wall, the shelf and the window box, made again
##            whenever the card changes size;
##   bed   -- the frame, the floor, the rails, the pots and the window, made
##            once in a reference layout's space (the two joined into one
##            mesh while the layout is that one);
##   lower, upper -- the cups and the light; the drops, the mirrors and
##            the sparks over it: rebuilt only while something is moving,
##            every piece a look made once and copied under its transform;
##   air   -- the sun's turning rays, the motes drifting down the light, the
##            glints and the bud, the only things that move at rest, looks
##            under transforms too.
## Everything but the glass is made in the reference layout and drawn under
## `_relay()`, so the win card's smaller relayout makes nothing again but
## the glass. The pieces are ui/faces/sunbeam_parts.gd, which the menu card
## draws too.
##
## The board checkup (2026-10-02): every piece was drawn in script on every
## frame anything moved -- a drag held still included, 3.2-6 ms a frame on
## Insane -- the air ~1 ms on every idle frame, and the win card's relayout
## made the whole greenhouse again (11-18 ms).
##
## Spec: docs/superpowers/specs/2026-09-26-sunbeam-flat-design.md, section 7.
##
## The polish (2026-10-01, docs/superpowers/specs/2026-10-01-sunbeam-polish-
## design.md): Hard and Insane can be lost. On Hard snails nap on the floor,
## and a move let go with the light on one wakes it; on Insane (Shy Dew) the
## drops are shy, and a move let go with the light on any of them dries it,
## unless it is the move that lights them all at once. Either costs a heart:
## the sleeper wakes or the drop puffs steam, a heart splits on the pill, and
## the piece slides back (`_misstep`). Out of hearts, dusk and the card.
## Rewards ride two more layers: Life (the streak's bubble, rainbows, love
## hearts, butterflies, the seal) over everything, and Hearts (the pill).
## Ported from the canvas mock at docs/brainstorm/concepts.html#sunbeam, the
## reference for every measure.

const State = preload("res://puzzles/sunbeam_state.gd")
const Gen = preload("res://puzzles/sunbeam_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Parts = preload("res://ui/faces/sunbeam_parts.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Seal = preload("res://ui/flat/seal.gd")
const NapCat = preload("res://ui/faces/nap_cat.gd")
const SnailFace = preload("res://ui/faces/snail_face.gd")
const Cat = preload("res://ui/faces/caterpillar.gd")
const RunMesh = preload("res://ui/flat/run_mesh.gd")

# --- the screen, measured ---
## The card's inset round the floor, the largest cell any band asks for, the
## card's corner, the iron frame round the floor and its corner, and a tile's
## gap and corner.
const INSET := 44.0
const CELL_CAP := 180.0
const CARD_RADIUS := 32.0
const FRAME := 22.0
const FRAME_R := 30.0
const TILE_GAP := 4.0
const TILE_R := 0.08
## The glass wall's panes: how many across the card, and the mullion's width.
const PANES := 5
const MULLION := 10.0
## How far past the floor's edge light that leaves it is drawn, in cells.
const OUT_STUB := 0.3
## What the light meets, in cells: a mirror's glass reaches this far along
## each axis from its centre; a cup takes light into its mouth this far either
## side of its middle, and its body is a box that deep, sitting this far back;
## a pot, the bud and the lamp are boxes of these half-sizes; and a drop is
## wet by light passing this close. A ray bounces at most MAX_BOUNCES times.
const MIRROR_REACH := 0.35
const CUP_REACH := 0.65
const CUP_DEPTH := 0.4
const CUP_SHIFT := 0.1
const POT_HALF := 0.3
const BUD_HALF := 0.3
const LAMP_HALF := 0.42
const DROP_REACH := 0.22
const MAX_BOUNCES := 64
## The dressing: a band over or under the floor shorter than this gets none;
## the glass's light shafts as (left edge, width) fractions of the card; and
## how many grout crossings grow moss.
const BAND_MIN := 90.0
const SHAFTS := [Vector2(-0.2, 0.13), Vector2(0.02, 0.05), Vector2(0.3, 0.16), Vector2(0.55, 0.06)]
const MOSS := 0.16
## Where ivy trails over the window box's lip, as fractions of its length.
const IVY := [0.0, 0.3, 0.72, 1.0]
const EPS := 1e-4

# --- this board's own motion ---
## The light's speed on its first run out of the lamp, in cells a second;
## how long a let-go piece takes to settle onto its peg (the beam bends with
## it the whole way); and how soon a drop may chime again. Everything else is
## a recipe from core/motion.gd.
const BEAM_SPEED := 34.0
const SNAP_TIME := 0.16
const CHIME_QUIET := 0.3
## The light waits for the pieces' entrance before it leaves the lamp.
const BEAM_DELAY := 0.55
## The sun's rays turn this fast at rest; motes drift down the light this
## fast and this many a cell.
const SUN_TURN := 0.35
const MOTE_SPEED := 1.6
const MOTE_DENSITY := 1.2
## At rest bright pulses flow out of the sun along the beam's core: one every
## PULSE_GAP cells, PULSE_LEN long, at PULSE_SPEED cells a second.
const PULSE_GAP := 2.6
const PULSE_LEN := 0.55
const PULSE_SPEED := 2.4
## A let-go piece lands with a dip and a rebound of LAND over LAND_TIME, and a
## puff off the rail.
const LAND := -0.1
const LAND_TIME := 0.26
## The solve: a gold wave runs the beam from the sun to the bud at
## WAVE_SPEED cells a second (faster on a long beam, so it takes at most
## WAVE_MAX), each drop sparkling as it passes; then the bud opens over
## BLOOM_TIME, petals drift off for PETAL_LIFE, and the win screen waits
## WIN_HOLD past the bloom.
const WAVE_SPEED := 22.0
const WAVE_MAX := 1.0
const BLOOM_TIME := 1.0
const PETAL_LIFE := 2.2
const PETALS := 6
const WIN_HOLD := 1.1
## The light gathers strength from the dew (2026-10-01): it leaves the sun at
## WEAK of its full width and alpha and grows by an even step at every drop
## it passes, full once it has passed them all. The bud it reaches grows by
## that strength -- (drops passed + 1) / (drops + 1) of the way, never the
## bloom, which is the solve's -- easing up over GROW_UP and back over
## GROW_DOWN seconds.
const WEAK_WIDTH := 0.3
const WEAK_ALPHA := 0.28
const GROW_UP := 0.25
const GROW_DOWN := 0.8
## The looks' steps: a held piece's lift, a ring's spread,
## a mote's or a pulse's fade, the bud's bloom and growth, and its sway.
const LIFT_STEPS := 8.0
const RING_STEPS := 16.0
const FADE_STEPS := 8.0
const BUD_STEPS := 40.0
const SWAY_STEPS := 8.0

const TIP_CYCLE := 8.0
const TIPS := ["SB_TIP_DRAG", "SB_TIP_GOAL", "SB_TIP_CUP", "SB_TIP_MIRROR", "SB_TIP_STOP"]
const TIPS_SNAILS := ["SB_TIP_DRAG", "SB_TIP_SNAIL", "SB_TIP_HOLD", "SB_TIP_ORDER", "SB_TIP_HEARTS"]
const TIPS_SHY := ["SB_TIP_SHY", "SB_TIP_HOLD", "SB_TIP_CURTAIN", "SB_TIP_ONCE", "SB_TIP_HEARTS"]

# --- hearts (Hard and Insane) ---
## A wrong move stands EJECT_AFTER, then slides back over SNAP_TIME. The pill
## of hearts over the floor is Caterpillar's, number for number.
const EJECT_AFTER := 0.8
const HEART_ROW := 64.0
const HEART_TOP := 6.0
const HEART_R := 21.0
const HEART_GAP := 12.0
const HEART_PILL_PAD := Vector2(18.0, 8.0)
const HEART_PILL_RIM := 2.0
const SPLIT_TIME := 0.7
const SPLIT_FALL := 56.0
const SPLIT_SPREAD := 14.0
const SPLIT_TURN := 0.7
const HEART_BACK_TIME := 0.3
const DUSK := Color(0.74, 0.76, 0.92)
const DUSK_TIME := 0.8
const CARD_AFTER := 1.1
const CARD_AFTER_STILL := 0.3
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
const AGO := -1.0e9
## A snail, as a share of a cell; how high it jumps when woken, and its
## sleepy z's: one every Z_EVERY seconds, rising Z_RISE cells over Z_LIFE.
const SNAIL_PX := 0.78
const WAKE_HOP := 0.35
const WAKE_TIME := 0.5
const Z_EVERY := 1.4
const Z_LIFE := 2.6
const Z_RISE := 0.7
## A shy drop under the light while a finger holds a piece trembles this
## many pixels; a dried one is pale for DRY_TIME.
const SHY_SHAKE := 2.5
const DRY_TIME := 1.2

# --- the rewards ---
## The streak: moves in a row that light a new drop. A note up the
## pentatonic from the second, the "x3" bubble from the third, confetti at 4,
## 7 and every 5.
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0
const COMBO_DEFLATE := 0.25
const COMBO_FONT := 44
## Gags on one newly lit drop in GAG_ODDS: a rainbow arcs over it, love
## hearts float off it, or a butterfly visits.
enum Gag { NONE = -1, RAINBOW, LOVE, BUTTERFLY }
const GAG_SPAN := 9
const GAG_ODDS := 3
const GAG_STEP := 5
const RAINBOW_TIME := 1.7
const RAINBOW_R := 0.62
const RAINBOW_BANDS := [Color("ef8f8f"), Color("f4b76a"), Color("f2dc76"), Color("9fd38a"), Color("8cc0e8"), Color("b49be0")]
const LOVE_HEARTS := 3
const LOVE_TIME := 1.2
const LOVE_RISE := 0.9
const LOVE_R := 0.13
const FLY_IN := 0.7
const FLY_SIT := 0.9
const FLY_OUT := 0.7
## The party, after the bloom: confetti twice, a rainbow over the glass,
## butterflies off the flower, the nap cat on the window box, the seal, and
## a bit of sunny wisdom.
const PARTY_AT := 0.2
const PARTY_TIME := 3.4
const CHEERS := 12
const ARCH_AT := 0.3
const ARCH_TIME := 2.8
const FLUTTER_AT := 0.6
const FLUTTER_TIME := 2.2
const FLUTTERS := 5
const CAT_PX := 0.18
const CAT_AT := 0.9
const CAT_POP := 0.22
const CAT_HOPS := 3
const CAT_HOP_TIME := 0.32
const CAT_HOP_H := 0.45
const CAT_SETTLE := 0.25
const CURL_AT := 2.7
const STAMP_AT := 1.6
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.16
const STAMP_TILT := -0.22

## The out-of-hearts card's Leave: the host closes the board.
signal leave

var _state = State.new()
var fx: Node2D

## The light this frame (_trace_live's), rebuilt while anything moves.
var _tr := {}
var _tr_dirty := true
## When the light leaves the lamp on its first run.
var _beam_at := -100.0
## Drops the drawn light is wetting now, and when each last chimed.
var _wet := {}
var _chimed := {}
## The arrangement a dry-bud line was said for, so it is said once.
var _bud_told := ""
## How much the bud has been fed by the light now, eased toward _grow_goal().
var _grow := 0.0

## Each piece's settle onto its peg: {"from": float peg, "at": time}.
var _disp: Array = []
## A drag: {"p", "s" (float peg), "off", "before"}; empty when none.
var _drag := {}
## A press on an empty peg, sent there on release: {"p", "q"}.
var _peg_press := {}
## The last refusal: {"at", "p"}.
var _refused := {"at": -100.0, "p": -1}
var _rings: Array = []

var _opened := 0.0
var _anim_until := 0.0
var _solved_at := AGO
## When the solve's wave reaches the bud and it starts to open.
var _bloom_at := AGO
var _wave_speed := WAVE_SPEED
## The glass over the whole card and the bed in the reference layout (see
## the header), and the two joined while the layout is the reference one.
var _glass: ArrayMesh
var _bed: ArrayMesh
var _still: ArrayMesh
var _lower: ArrayMesh
var _upper: ArrayMesh
var _air: ArrayMesh
var _live_dirty := true
var _air_dirty := true
## The layout every mesh but the glass is made at: the board's own space
## while it builds (`_in_ref`), drawn under `_relay()` onto the layout it has
## now.
var _ref_cell := 0.0
var _ref_origin := Vector2.ZERO
var _in_ref := false
## The looks: a key per look, its maker, and the RunMeshes that put them,
## sharing `_rm`'s shapes. The lower and upper meshes give every piece a
## run of its own (`_lay_rooms`), so a piece changing its look (a lift, a
## landing) offsets only its own indices -- on one tail every look after it
## moved and was offset again in script, 1-2 ms a frame through a drag.
var _rm: RunMesh
var _rm_lo: RunMesh
var _rm_hi: RunMesh
var _rm_air: RunMesh
var _rooms_laid := false
var _cache := {}
var _fades := {}
var _look_makers: Array = []
## The streak's digits are rasterised out of sight on the first frame.
var _warm_combo := true
## The meshes the last _draw handed over: a canvas command holds a mesh by
## RID, so dropping the only reference leaves the renderer a freed one.
var _shown: Array = []
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

# --- hearts ---
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
var _lost_ever := false
var _undo_ever := false
var _flawless := false
var _asleep := false
var _heart_card: Control
var _split_index := -1
var _split_at := AGO
var _back_index := -1
var _back_at := AGO
var _heart_layer: Control
var _hearts_shown: ArrayMesh
var _dusk_tw: Tween
var _gen := 0
var _busy_until := 0.0
var _was_busy := false
## A wrong move playing out: {"at", "p", "kind", "cells"}.
var _wrong := {}
## Drops a wrong move dried, and when.
var _dried := {}
## The snails, one face a sleeper, and when each was last woken.
var _snails: Array = []
var _woke_at := {}
## A drop going shy under a held piece's light: said once a drag.
var _shy_told := false

# --- the rewards ---
## Set by a harness: -2 rolls the day's dice, -1 never, else that gag.
var force_gag := -2
var _streak := 0
var _streak_gen := 0
var _lights := 0
var _gag_until := 0.0
var _gag_gen := 0
var _combo_n := 0
var _combo_at := -INF
var _combo_pos := Vector2.ZERO
var _combo_popped := false
var _combo_out_at := -INF
var _combo_shown: ArrayMesh
var _combo_key: Array = []
var _life_layer: Control
var _life_shown: Array = []
var _love: Array = []       # [{"at", "t", "phase"}]
var _bows: Array = []       # [{"at", "t"}] rainbows
var _flies: Array = []      # [{"at", "t", "from"}] butterflies
var _love_mesh: ArrayMesh
var _bow_mesh: ArrayMesh
var _seal_mesh: ArrayMesh
var _party_at := INF
var _stamp_at := INF
var _cat: Control
var _cat_at := INF
var _cat_curled := false

func puzzle_id() -> String: return "sunbeam"
func title() -> String: return "Sunbeam"

## The rules, then the band's own closing: nothing can be lost (Easy,
## Medium), the snails (Hard), or Shy Dew (Insane).
func rules() -> String:
	var out := tr("SB_RULES")
	if _state.shy():
		out += "\n\n" + tr("SB_RULES_SHY") % max_hearts
	elif max_hearts > 0:
		out += "\n\n" + tr("SB_RULES_SNAILS") % max_hearts
	else:
		out += "\n\n" + tr("SB_RULES_SAFE")
	return out

## The how-to-play card's pages, the band's own: bending the light, every
## drop before the bud (Easy to Hard), the cups, the snails (Hard) or Shy
## Dew (Insane), Undo and Reset, and the bulb (bands with hints). Each page
## is the board itself on a small hand-made floor, playing the lesson
## (ui/hud/sunbeam_tutorial_diagram.gd).
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/sunbeam_tutorial_diagram.gd")
	var band: int = _state.difficulty
	var hints: int = State.hints_for(band)
	var hearts_n: int = State.hearts_for(band)
	var steps := [[Diagram.Lesson.DRAG, "HTP_SB_DRAG", tr("HTP_SB_DRAG_BODY")]]
	if band < 3:
		steps.append([Diagram.Lesson.GOAL, "HTP_SB_GOAL", tr("HTP_SB_GOAL_BODY")])
	steps.append([Diagram.Lesson.CUP, "HTP_SB_CUP", tr("HTP_SB_CUP_BODY")])
	if band >= 3:
		steps.append([Diagram.Lesson.SHY, "SB_SHY_SEAL", tr("HTP_SB_SHY_BODY") % hearts_n])
	elif hearts_n > 0:
		steps.append([Diagram.Lesson.SNAILS, "HTP_SB_SNAILS", tr("HTP_SB_SNAILS_BODY") % hearts_n])
	var undo_body := "HTP_SB_UNDO_BODY"
	if band >= 3:
		undo_body = "HTP_SB_RESET_BODY"
	elif hearts_n > 0:
		undo_body = "HTP_SB_UNDO_BODY_JUDGED"
	steps.append([Diagram.Lesson.UNDO, "HTP_WT_UNDO", tr(undo_body)])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_SB_HINT_BODY_ONE") if hints == 1 else tr("HTP_SB_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func _tips() -> Array:
	if _state.shy():
		return TIPS_SHY
	if not _state.snails().is_empty():
		return TIPS_SNAILS
	return TIPS

## Undo and Hint; Reset is the host's. No Check: the beam is the check.
## Insane has neither undo nor hint: can_undo() and hints_left() say so.
func capabilities() -> Array[String]:
	if _state.difficulty >= 3:
		return ["undo"]
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rm = RunMesh.new(_make_look)
	_rm_air = RunMesh.new(_make_look)
	_rm_air.share_shapes(_rm)
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	_heart_layer = Control.new()
	_heart_layer.name = "Hearts"
	_heart_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heart_layer.z_index = 1
	_heart_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_heart_layer.draw.connect(_draw_hearts)
	add_child(_heart_layer)
	_life_layer = Control.new()
	_life_layer.name = "Life"
	_life_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_life_layer.z_index = 3
	_life_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_life_layer.draw.connect(_draw_life)
	add_child(_life_layer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	_close_card()
	_state.build(rng, difficulty, bank_step)
	max_hearts = State.hearts_for(difficulty)
	_heart_used = false
	_lost_ever = false
	_undo_ever = false
	_flawless = false
	_deal()
	_reset_rewards()
	_make_snails()
	_opened = _now()
	_beam_at = _opened + (0.0 if Motion.reduce else BEAM_DELAY)
	_layout()
	fx.cue("enter")
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()

## The floor as it is dealt, and as Try again deals it back: every heart,
## the day's light, the pieces where they opened.
func _deal() -> void:
	hearts = max_hearts
	out_of_hearts = false
	_asleep = false
	_split_index = -1
	_split_at = AGO
	_back_index = -1
	_back_at = AGO
	_busy_until = 0.0
	_wrong = {}
	_dried = {}
	_woke_at = {}
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	_disp = []
	for p in _state.pieces().size():
		_disp.append({"from": float(_state.pos[p]), "at": -100.0, "lift": false})
	_drag = {}
	_peg_press = {}
	_refused = {"at": -100.0, "p": -1}
	_rings = []
	_wet = {}
	_chimed = {}
	_bud_told = ""
	_anim_until = 0.0
	_solved_at = AGO
	_bloom_at = AGO
	_tr = {}
	_tr_dirty = true
	# A new floor: the bed, the light and the pieces' runs are made again.
	_bed = null
	_still = null
	_rooms_laid = false

# --- layout ---

func _cell() -> float:
	if _in_ref:
		return _ref_cell
	if _state.cols <= 0:
		return 0.0
	return maxf(0.0, minf(CELL_CAP, minf((size.x - 2.0 * _inset()) / _state.cols,
		(size.y - _heart_row() - 2.0 * _inset()) / _state.rows)))

## The card kept round the floor (a tutorial page, short and wide, keeps
## less).
func _inset() -> float:
	return INSET

## The strip the hearts take over the floor, on a band that has them.
func _heart_row() -> float:
	return HEART_ROW if max_hearts > 0 else 0.0

func _grid_size() -> Vector2:
	return Vector2(_state.cols, _state.rows) * _cell()

func _origin() -> Vector2:
	if _in_ref:
		return _ref_origin
	return (size - _grid_size()) * 0.5 + Vector2(0.0, _heart_row() * 0.5)

func _mid() -> Vector2:
	return _origin() + _grid_size() * 0.5

## A point in cell units (a cell's centre is its column and row plus a half)
## to a Control-local one.
func _pt(v: Vector2) -> Vector2:
	return _origin() + v * _cell()

func _centre(c: int) -> Vector2:
	return _pt(_cv(c))

func _cv(c: int) -> Vector2:
	return Vector2(c % _state.cols, c / _state.cols) + Vector2(0.5, 0.5)

## Control-local point over the centre of the cell at (row, column), the name
## every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(r * _state.cols + c)

func card_height(available: float) -> float:
	return available

## The floor is taller than wide but the slot is taller still: halve the slack.
func card_centred() -> bool:
	return true

func _layout() -> void:
	_glass = null
	_still = null
	_take_ref()
	_refresh()

## The layout the bed and the looks are made at: the first one with room on
## it, and any larger one after (a look made small and drawn large would
## blur). A smaller one -- the win card's -- keeps it and is drawn under
## `_relay()`.
func _take_ref() -> void:
	if _in_ref:
		return
	var c := _cell()
	if c <= 0.0:
		return
	if _ref_cell <= 0.0 or c > _ref_cell + 0.01:
		_ref_cell = c
		_ref_origin = _origin()
		_bed = null
		_still = null
		_cache = {}
		_fades = {}
		_look_makers = []
		_rm.reset()
		_rm_air.share_shapes(_rm)
		_rooms_laid = false
		_live_dirty = true
		_air_dirty = true

## The reference layout onto the one the board has now.
func _relay() -> Transform2D:
	if _ref_cell <= 0.0:
		return Transform2D.IDENTITY
	var k := _cell() / _ref_cell
	return Transform2D(0.0, Vector2(k, k), 0.0, _origin() - _ref_origin * k)

## The shape id of the look `key`, drawn by `maker(builder)` the first time
## it is put.
func _look(key: String, maker: Callable) -> int:
	var id = _cache.get(key)
	if id == null:
		id = _look_makers.size()
		_look_makers.append(maker)
		_cache[key] = id
	return id

func _make_look(id: int) -> Face.Builder:
	var b := Face.Builder.new()
	_look_makers[id].call(b)
	return b

## `under` and `over` as one mesh, `over` drawn last.
static func _join(under: ArrayMesh, over: ArrayMesh) -> ArrayMesh:
	var a := under.surface_get_arrays(0)
	var b := over.surface_get_arrays(0)
	var verts: PackedVector2Array = b[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = b[Mesh.ARRAY_COLOR]
	var base := verts.size()
	verts.append_array(a[Mesh.ARRAY_VERTEX])
	cols.append_array(a[Mesh.ARRAY_COLOR])
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	for k in idx.size():
		idx[k] += base
	idx.append_array(b[Mesh.ARRAY_INDEX])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

# --- the pieces' geometry ---

## Where piece `p`'s anchor cell is at a float peg `s` (between two pegs
## mid-slide), in cell units.
func _anchor(p: int, s: float) -> Vector2:
	var rail: PackedInt32Array = _state.g.pieces[p].rail
	var i := clampi(int(floor(s)), 0, rail.size() - 1)
	var j := mini(rail.size() - 1, i + 1)
	return _cv(rail[i]).lerp(_cv(rail[j]), clampf(s - float(i), 0.0, 1.0))

## A piece's middle: a mirror's cell, or between a cup's two.
func _piece_mid(p: int, s: float) -> Vector2:
	var pc: Dictionary = _state.g.pieces[p]
	var a := _anchor(p, s)
	if pc.kind == "m":
		return a
	return a + Vector2(Gen.DX[pc.s], Gen.DY[pc.s]) * 0.5

## The float peg a piece is drawn at: the finger's while dragged, else
## settling onto its peg.
func _peg_now(p: int, t: float) -> float:
	if not _drag.is_empty() and int(_drag.p) == p:
		return float(_drag.s)
	var d: Dictionary = _disp[p]
	var u := 1.0 if Motion.reduce else clampf((t - float(d.at)) / SNAP_TIME, 0.0, 1.0)
	if u >= 1.0:
		return float(_state.pos[p])
	return lerpf(float(d.from), float(_state.pos[p]), Motion.back_out(u))

# --- the beam ---

## The light as it looks this frame: a ray cast out of the lamp against every
## piece where it is *drawn* -- under the finger, or settling onto its peg --
## rather than where it stands in the rules, so the beam bends continuously as
## a piece slides instead of jumping a peg at a time. A mirror is its glass, a
## diagonal it can be struck anywhere along; a cup takes light into its mouth
## and hands it back mirrored about its middle, so the U-turn widens and
## narrows as the cup moves; pots, the bud and the lamp are boxes. When every
## piece stands on a peg this is exactly the grid's beam (sunbeam_gen.gd's
## trace), and only that one decides anything: the win, the proof, the dry bud.
## {pts (cell units), len (running length), drop_at {cell: length along},
##  glints [[point, length along]], end}
func _trace_live(t: float) -> Dictionary:
	var g: Dictionary = _state.g
	var mirrors: Array = []
	var cups: Array = []
	for p in _state.pieces().size():
		var pc: Dictionary = g.pieces[p]
		var peg := _peg_now(p, t)
		if pc.kind == "m":
			mirrors.append([_anchor(p, peg), pc.t == "/"])
		else:
			var sv := Vector2(Gen.DX[pc.s], Gen.DY[pc.s])
			cups.append([_anchor(p, peg) + sv * 0.5, sv, Vector2(Gen.DX[pc.f], Gen.DY[pc.f])])
	var boxes: Array = [[_cv(g.bud), BUD_HALF, "bud"], [_cv(g.lamp), LAMP_HALF, "lamp"]]
	for c in g.pots:
		boxes.append([_cv(c), POT_HALF, "pot"])
	var at := _cv(g.lamp)
	var d := Vector2(Gen.DX[g.dir], Gen.DY[g.dir])
	var pts := PackedVector2Array([at])
	var lens := PackedFloat32Array([0.0])
	var glints: Array = []
	var drop_at := {}
	var end := "loop"
	for bounce in MAX_BOUNCES:
		var run: float = lens[lens.size() - 1]
		var best := _exit_t(at, d)
		var what := "out"
		var arg: Array = []
		for bx: Array in boxes:
			var tb := _box_t(at, d, bx[0], Vector2.ONE * float(bx[1]))
			if tb < best:
				best = tb
				what = bx[2]
		for m: Array in mirrors:
			var tm := _mirror_t(at, d, m[0], m[1])
			if tm < best:
				best = tm
				what = "m"
				arg = m
		for cu: Array in cups:
			var mid: Vector2 = cu[0]
			var sv: Vector2 = cu[1]
			var f: Vector2 = cu[2]
			if d.dot(f) < -0.5:
				var e := (at - mid).dot(sv)
				var tc := (at - mid).dot(f)
				if absf(e) <= CUP_REACH and tc > EPS and tc < best:
					best = tc
					what = "u"
					arg = [mid, sv, f, e]
			else:
				var tb := _box_t(at, d, mid - f * CUP_SHIFT, sv.abs() * CUP_REACH + f.abs() * CUP_DEPTH)
				if tb < best:
					best = tb
					what = "cup"
		# the drops (and snails) this straight passes close enough to wet
		for c in _near_cells():
			if drop_at.has(c):
				continue
			var dc := _cv(c) - at
			var along := dc.dot(d)
			if along >= 0.0 and along <= best and absf(dc.cross(d)) <= DROP_REACH:
				drop_at[c] = run + along
		var hit := at + d * best
		match what:
			"out":
				_push(pts, lens, at + d * (best + OUT_STUB))
				end = "out"
				break
			"bud":
				_push(pts, lens, at + d * (best + BUD_HALF))
				end = "bud"
				break
			"m":
				_push(pts, lens, hit)
				glints.append([hit, lens[lens.size() - 1]])
				d = Vector2(-d.y, -d.x) if arg[1] else Vector2(d.y, d.x)
				at = hit
			"u":
				var mid: Vector2 = arg[0]
				var sv: Vector2 = arg[1]
				var f: Vector2 = arg[2]
				var e: float = arg[3]
				var depth := Parts.CUP_BULGE * 2.0 * absf(e)
				_push(pts, lens, hit)
				for k in range(1, 11):
					var q := PI * float(k) / 10.0
					_push(pts, lens, mid + sv * e * cos(q) - f * depth * sin(q))
				at = pts[pts.size() - 1]
				d = f
			_:
				_push(pts, lens, hit)
				end = what
				break
	return {"pts": pts, "len": lens, "drop_at": drop_at, "glints": glints, "end": end}

## Every cell the drawn light can wet or wake: the drops, then the snails.
func _near_cells() -> PackedInt32Array:
	var out: PackedInt32Array = _state.drops().duplicate()
	out.append_array(_state.snails())
	return out

static func _push(pts: PackedVector2Array, lens: PackedFloat32Array, p: Vector2) -> void:
	lens.append(lens[lens.size() - 1] + p.distance_to(pts[pts.size() - 1]))
	pts.append(p)

## How far an axis-aligned ray from `at` along `d` runs before leaving the floor.
func _exit_t(at: Vector2, d: Vector2) -> float:
	if d.x > 0.5:
		return float(_state.cols) - at.x
	if d.x < -0.5:
		return at.x
	if d.y > 0.5:
		return float(_state.rows) - at.y
	return at.y

## Where an axis-aligned ray meets a box of half-size `half` about `c` from
## outside, or INF. A ray that starts inside one (the lamp's, a cup's own
## body after its U-turn) passes out of it untouched.
static func _box_t(at: Vector2, d: Vector2, c: Vector2, half: Vector2) -> float:
	if absf(d.x) > 0.5:
		if absf(at.y - c.y) > half.y:
			return INF
		var tx := (c.x - half.x * signf(d.x) - at.x) * signf(d.x)
		return tx if tx > EPS else INF
	if absf(at.x - c.x) > half.x:
		return INF
	var ty := (c.y - half.y * signf(d.y) - at.y) * signf(d.y)
	return ty if ty > EPS else INF

## Where an axis-aligned ray meets a mirror's glass -- the diagonal through
## `m`, "/" or "\", reaching MIRROR_REACH along each axis -- or INF.
static func _mirror_t(at: Vector2, d: Vector2, m: Vector2, slash: bool) -> float:
	if absf(d.x) > 0.5:
		var off := at.y - m.y
		if absf(off) > MIRROR_REACH:
			return INF
		var x := m.x - off if slash else m.x + off
		var tx := (x - at.x) * signf(d.x)
		return tx if tx > EPS else INF
	var off2 := at.x - m.x
	if absf(off2) > MIRROR_REACH:
		return INF
	var y := m.y - off2 if slash else m.y + off2
	var ty := (y - at.y) * signf(d.y)
	return ty if ty > EPS else INF

func _total() -> float:
	var lens: PackedFloat32Array = _tr.get("len", PackedFloat32Array())
	return lens[lens.size() - 1] if not lens.is_empty() else 0.0

## How much of the beam is drawn at `t`, in cells: all of it, but for the
## light's first run out of the lamp as the floor opens.
func _drawn(t: float) -> float:
	if Motion.reduce:
		return _total()
	return minf(_total(), maxf(0.0, t - _beam_at) * BEAM_SPEED)

## Seconds from `t` until that first run reaches the end of the beam.
func _arrive_in(t: float) -> float:
	if Motion.reduce:
		return 0.0
	return maxf(0.0, _beam_at + _total() / BEAM_SPEED - t)

func _arrived(t: float) -> bool:
	return _drawn(t) >= _total() - 1e-4

## The first `upto` cells of `pts`, in pixels.
func _cut(pts: PackedVector2Array, upto: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.is_empty() or upto <= 0.0:
		return out
	out.append(_pt(pts[0]))
	var acc := 0.0
	for i in range(1, pts.size()):
		var sl := pts[i].distance_to(pts[i - 1])
		if acc + sl >= upto:
			out.append(_pt(pts[i - 1].lerp(pts[i], (upto - acc) / maxf(sl, 1e-6))))
			return out
		out.append(_pt(pts[i]))
		acc += sl
	return out

## The point `at` cells along the beam, in pixels.
func _along(at: float) -> Vector2:
	var pts: PackedVector2Array = _tr.pts
	var lens: PackedFloat32Array = _tr.len
	for i in range(1, lens.size()):
		if lens[i] >= at:
			var u := (at - lens[i - 1]) / maxf(lens[i] - lens[i - 1], 1e-6)
			return _pt(pts[i - 1].lerp(pts[i], u))
	return _pt(pts[pts.size() - 1])

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.size() == 0:
		return
	var t := _now()
	# A wrong move ending lets go of the HUD: it greyed Undo, Hint and Reset.
	var bz := busy()
	if _was_busy and not bz:
		moved.emit()
	_was_busy = bz
	var moving := _animating(t)
	if moving or _tr_dirty or _tr.is_empty():
		_tr = _trace_live(t)
		_tr_dirty = false
	_arrivals(t)
	_feed_bud(delta)
	if moving:
		_refresh()
	elif not Motion.reduce:
		# At rest only the sun's rays and the motes move, and they are their
		# own small mesh.
		_air_dirty = true
		queue_redraw()
	_place_snails(t)
	if _tick_life(t):
		_life_layer.queue_redraw()
	if t >= _cat_at and not _cat_curled:
		_place_cat(t)
	if max_hearts > 0 and (t - _split_at < SPLIT_TIME + 0.1 or t - _back_at < HEART_BACK_TIME + 0.1 \
			or t - _opened < Motion.ENTER_DELAY + Motion.POP_IN + 0.1):
		_heart_layer.queue_redraw()

## The light reaching things: a drop it has just wet rings and chimes (not
## twice inside CHIME_QUIET, so a drag sweeping the light back and forth over
## one does not chatter), and a bud reached with a drop still dry says so,
## once an arrangement, only once the pieces are at rest.
func _arrivals(t: float) -> void:
	var drawn := _drawn(t)
	var now_wet := {}
	for c in _tr.drop_at:
		if drawn >= float(_tr.drop_at[c]) - 1e-4:
			now_wet[c] = true
	var shy := _state.shy() and not _state.is_solved() and _solved_at <= AGO
	var snails := _state.snails()
	for c in now_wet:
		if not _wet.has(c) and t - float(_chimed.get(c, -100.0)) > CHIME_QUIET:
			_chimed[c] = t
			if snails.has(c):
				# a snail under the light stirs: a little worried murmur
				if not _drag.is_empty():
					fx.cue("stir")
			elif shy:
				if not _drag.is_empty():
					fx.cue("shy")
					if not _shy_told:
						_shy_told = true
						_say(tr("SB_SHY_WARN"), Face.Expr.WORRIED)
			else:
				_ring_at(_centre(c), t)
				fx.cue("dew", 1.0 + 0.08 * float(now_wet.size() - 1))
	_wet = now_wet
	var tr_: Dictionary = _state.beam
	var key := str(_state.pos)
	if _drag.is_empty() and _settled(t) and tr_.end == "bud" and not tr_.won and _arrived(t) and _bud_told != key:
		_bud_told = key
		var left: int = _state.drops().size() - _state.lit_drops()
		if not _state.shy():
			_say(tr("SB_BUD_DRY_ONE") if left == 1 else tr("SB_BUD_DRY_N") % left, Face.Expr.STRAIN)
			fx.cue("dry")

## Whether every piece has landed on its peg.
func _settled(t: float) -> bool:
	for d: Dictionary in _disp:
		if t - float(d.at) < SNAP_TIME:
			return false
	return true

func _animating(t: float) -> bool:
	if t < _anim_until:
		return true
	if Motion.reduce:
		return false
	var entrance := Motion.ENTER_DELAY + Motion.ENTER_POP \
		+ Motion.stagger(_state.pieces().size() + 2, Motion.ENTER_STAGGER) + Motion.POP_IN + 0.2
	return t - _opened < entrance or not _drag.is_empty()

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

func _refresh() -> void:
	_tr_dirty = true
	_live_dirty = true
	_air_dirty = true
	queue_redraw()

# --- the drawing ---

func _draw() -> void:
	if _state.size() == 0 or _cell() <= 0.0:
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var grow := Motion.wide_pop_scale(since)
	var mid := _mid()
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var tint := Color(1.0, 1.0, 1.0, seen)
	if _glass == null:
		_glass = _build_glass()
	_take_ref()
	var relay := _relay()
	_in_ref = true
	if _bed == null:
		_bed = _build_bed()
	if _live_dirty:
		_live_dirty = false
		_build_live(t)
	if _air_dirty:
		_air_dirty = false
		_air = _build_air(t)
	_in_ref = false
	var board := xf * relay
	var shown: Array = []
	if relay == Transform2D.IDENTITY:
		if _still == null:
			_still = _join(_glass, _bed)
		draw_mesh(_still, null, xf, tint)
		shown.append(_still)
	else:
		draw_mesh(_glass, null, xf, tint)
		draw_mesh(_bed, null, board, tint)
		shown.append_array([_glass, _bed])
	for m in [_lower, _upper, _air]:
		if m != null:
			draw_mesh(m, null, board, tint)
			shown.append(m)
	_shown = shown

## The greenhouse's glass: a wall of sage panes behind everything, light
## shafts, the potting shelf over the floor and the window box under it.
## Made in the layout the board has now, as it covers the card.
func _build_glass() -> ArrayMesh:
	var b := Face.Builder.new()
	var o := _origin()
	var g := _grid_size()
	var card := Face.Builder.round_rect(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0, CARD_RADIUS - 2.0)
	b.fan(card, Pal.GLASSHOUSE)
	# The panes: white-painted mullions a few across and one rail across the
	# top third, with a long soft glint over two of them.
	var pw := (size.x - 4.0) / float(PANES)
	for k in range(1, PANES):
		var x := 2.0 + pw * float(k)
		b.fan(Face.Builder.round_rect(Vector2(x - MULLION * 0.5, 10.0), Vector2(MULLION, size.y - 20.0), MULLION * 0.5),
			Color(Pal.SURFACE, 0.8))
	b.fan(Face.Builder.round_rect(Vector2(10.0, size.y * 0.3), Vector2(size.x - 20.0, MULLION), MULLION * 0.5),
		Color(Pal.SURFACE, 0.8))
	for k: int in [1, 3]:
		var x0 := 2.0 + pw * float(k) + pw * 0.2
		b.fan(PackedVector2Array([Vector2(x0, 24.0), Vector2(x0 + pw * 0.18, 24.0),
			Vector2(x0 - pw * 0.1, size.y * 0.3 - 8.0), Vector2(x0 - pw * 0.28, size.y * 0.3 - 8.0)]), Color(1.0, 1.0, 1.0, 0.35))
	# Hanging leaves in the two top corners, a vine along the glass.
	for side: float in [1.0, -1.0]:
		var root := Vector2(24.0 if side > 0.0 else size.x - 24.0, 12.0)
		for q in 7:
			var ang := lerpf(0.35, 1.35, float(q) / 6.0)
			ang = ang if side > 0.0 else PI - ang
			var col: Color = [Pal.LEAF_DEEP, Pal.LEAF, Pal.LEAF_LIGHT][q % 3]
			Parts.leaf(b, root + Vector2(side * float(q) * 9.0, float(q) * 5.0), 70.0 - float(q) * 4.0, ang, col)
	_shafts(b, card)
	# the hearts' pill takes the strip just over the frame, so the shelf
	# stands above it
	var top := o.y - FRAME - _heart_row()
	if top > BAND_MIN:
		_shelf(b, top)
	var bottom := o.y + g.y + FRAME + 6.0
	if size.y - bottom > BAND_MIN:
		_window_box(b, bottom, size.y - bottom)
	return b.mesh()

## The iron frame round the floor, its warm tiles, the rails, the pots and
## the window the sun sits in. None of it ever moves; made in the reference
## layout.
func _build_bed() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	var o := _origin()
	var g := _grid_size()
	# The frame, its shadow, and the floor inside it.
	var out := o - Vector2.ONE * FRAME
	var out_size := g + Vector2.ONE * FRAME * 2.0
	Scenery.soft_disc(b, out + out_size * Vector2(0.5, 1.0) + Vector2(0.0, 8.0), out_size.x * 0.55, 36.0, Color(Pal.TEXT, 0.14))
	b.fan(Face.Builder.round_rect(out + Vector2(0.0, 6.0), out_size, FRAME_R), Pal.GLASS_FRAME_DEEP)
	b.fan(Face.Builder.round_rect(out, out_size, FRAME_R), Pal.GLASS_FRAME)
	b.fan(Face.Builder.round_rect(out + Vector2(30.0, 6.0), Vector2(out_size.x * 0.18, 6.0), 3.0), Color(1.0, 1.0, 1.0, 0.55))
	b.fan(Face.Builder.round_rect(out + Vector2(out_size.x * 0.62, out_size.y - 12.0), Vector2(out_size.x * 0.2, 6.0), 3.0),
		Color(1.0, 1.0, 1.0, 0.55))
	b.fan(Face.Builder.round_rect(o, g, 10.0), Pal.FLOOR_GROUT)
	for c in _state.size():
		var x: int = c % _state.cols
		var y: int = c / _state.cols
		var v := _hash(x + 7, y + 3)
		var tone := Pal.FLOOR_TILE_HI if v < 0.33 else (Pal.FLOOR_TILE if v < 0.66 else Pal.FLOOR_TILE.lerp(Pal.FLOOR_GROUT, 0.45))
		# a warmer tile now and then, as terracotta weathers unevenly
		if _hash(x + 31, y + 17) < 0.2:
			tone = tone.lerp(Pal.POT_CLAY, 0.1)
		var at := o + Vector2(x, y) * s + Vector2.ONE * TILE_GAP
		var ts := Vector2.ONE * (s - TILE_GAP * 2.0)
		# each tile a slab: its lower lip in shade, a lit edge along its top
		b.fan(Face.Builder.round_rect(at + Vector2(0.0, 3.0), ts, s * TILE_R), tone.lerp(Pal.FLOOR_GROUT, 0.6))
		b.fan(Face.Builder.round_rect(at, ts - Vector2(0.0, 3.0), s * TILE_R), tone)
		b.fan(Face.Builder.round_rect(at + Vector2(s * 0.12, 3.0), Vector2(ts.x - s * 0.24, 3.0), 1.5), Color(1.0, 1.0, 1.0, 0.28))
	# moss in the grout, where four tiles meet
	for y in range(1, _state.rows):
		for x in range(1, _state.cols):
			if _hash(x * 3 + 5, y * 7 + 11) < MOSS:
				var at := o + Vector2(x, y) * s
				var v := _hash(x + 13, y + 29)
				var r := s * (0.03 + 0.015 * v)
				b.disc(at + Vector2(-r * 0.8, r * 0.3), r, Color(Pal.LEAF_DEEP, 0.75))
				b.disc(at + Vector2(r * 0.7, r * 0.5), r * 0.85, Color(Pal.LEAF, 0.75))
				b.disc(at + Vector2(0.0, -r * 0.5), r * 0.8, Color(Pal.LEAF_LIGHT, 0.8))
	for p in _state.pieces().size():
		var rail: PackedInt32Array = _state.g.pieces[p].rail
		var pegs := PackedVector2Array()
		for q in rail.size():
			pegs.append(_pt(_piece_mid(p, float(q))))
		Parts.rail(b, pegs[0], pegs[pegs.size() - 1], s, pegs)
	for c in _state.g.pots:
		Parts.pot(b, _centre(c), s)
	Parts.window(b, _centre(_state.g.lamp), s)
	return b.mesh()

## Morning light falling slant through the glass wall: a few pale shafts,
## cut to the card. The floor is drawn over them, so they only show on the
## glass.
func _shafts(b: Face.Builder, card: PackedVector2Array) -> void:
	var drift := size.y * 0.42
	for k in SHAFTS.size():
		var sh: Vector2 = SHAFTS[k]
		var x0 := size.x * sh.x
		var w := size.x * sh.y
		var quad := PackedVector2Array([Vector2(x0, 0.0), Vector2(x0 + w, 0.0),
			Vector2(x0 + w + drift, size.y), Vector2(x0 + drift, size.y)])
		for poly: PackedVector2Array in Geometry2D.intersect_polygons(quad, card):
			b.polygon(poly, Color(Pal.BEAM_CORE, 0.55) if k % 2 == 0 else Color(Pal.BEAM, 0.16))

## The potting shelf in the band over the floor: a plank on two brackets with
## three pots on it -- leaves, a flowering one, and a seedling.
func _shelf(b: Face.Builder, band: float) -> void:
	var y := band * 0.74
	var x0 := size.x * 0.16
	var x1 := size.x * 0.84
	for x: float in [x0 + 30.0, x1 - 30.0]:
		b.fan(PackedVector2Array([Vector2(x - 6.0, y), Vector2(x + 6.0, y), Vector2(x + 6.0, y + band * 0.16),
			Vector2(x - 6.0, y + band * 0.1)]), Pal.RAIL_DEEP)
	Scenery.soft_disc(b, Vector2((x0 + x1) * 0.5, y + 22.0), (x1 - x0) * 0.5, 12.0, Color(Pal.TEXT, 0.12))
	b.fan(Face.Builder.round_rect(Vector2(x0, y + 4.0), Vector2(x1 - x0, 14.0), 6.0), Pal.RAIL_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(x0, y), Vector2(x1 - x0, 14.0), 6.0), Pal.RAIL)
	b.fan(Face.Builder.round_rect(Vector2(x0 + 8.0, y + 2.0), Vector2(x1 - x0 - 16.0, 3.0), 1.5), Color(Pal.BEAM_CORE, 0.4))
	var ps := minf(band * 0.72, 130.0)
	for k in 3:
		var at := Vector2(lerpf(x0, x1, 0.22 + 0.28 * float(k)), y - ps * 0.3)
		match k:
			0:
				Parts.pot(b, at, ps)
			1:
				# a pot in flower: the leaves, and three pink heads over them
				Parts.pot(b, at, ps * 0.9)
				for q in 3:
					var fh := at + Vector2((float(q) - 1.0) * ps * 0.16, -ps * (0.38 + 0.08 * float(q % 2)))
					for i in 5:
						b.disc(fh + Vector2.from_angle(float(i) * TAU / 5.0) * ps * 0.045, ps * 0.045, Pal.FLOWER)
					b.disc(fh, ps * 0.035, Pal.SUN)
			_:
				# a seedling: a low pot and two round leaves on a stalk
				Parts.pot(b, at + Vector2(0.0, ps * 0.08), ps * 0.75)
				var stem := at + Vector2(0.0, -ps * 0.1)
				b.stroke(PackedVector2Array([stem, stem + Vector2(0.0, -ps * 0.28)]), ps * 0.04, Pal.LEAF_DEEP)
				b.ellipse(stem + Vector2(-ps * 0.1, -ps * 0.32), ps * 0.1, ps * 0.06, Pal.LEAF_LIGHT)
				b.ellipse(stem + Vector2(ps * 0.1, -ps * 0.34), ps * 0.1, ps * 0.06, Pal.LEAF)

## The window box in the band under the floor: a terracotta trough brimming
## with leaves and a few flowers, ivy trailing over its lip.
func _window_box(b: Face.Builder, y0: float, band: float) -> void:
	var h := minf(band * 0.34, 64.0)
	var y := y0 + band * 0.42
	var x0 := size.x * 0.1
	var x1 := size.x * 0.9
	# the foliage behind the lip: a back row of deep mounds, a front row of
	# lit ones, a few leaves poking up out of them, and flowers on top
	var n := int((x1 - x0) / (h * 0.7))
	for row in 2:
		for i in n:
			var x := lerpf(x0 + h * 0.4, x1 - h * 0.4, (float(i) + 0.5 * float(row)) / float(n))
			var v := _hash(i + 3, 91 + row)
			var r := h * (0.42 + 0.14 * v) * (1.0 if row == 0 else 0.85)
			var c := Vector2(x, y - r * 0.35 + float(row) * h * 0.12)
			b.disc(c, r, Pal.LEAF_DEEP if row == 0 else Pal.LEAF)
			b.disc(c + Vector2(-r * 0.25, -r * 0.3), r * 0.45, Color(Pal.LEAF_LIGHT, 0.55 if row == 1 else 0.3))
	for i in n / 2:
		var x := lerpf(x0 + h, x1 - h, (float(i) + 0.3) / float(maxi(n / 2, 1)))
		var v := _hash(i + 5, 57)
		Parts.leaf(b, Vector2(x, y - h * 0.3), h * (0.55 + 0.3 * v), -PI * 0.5 + (v - 0.5) * 1.2, Pal.LEAF_LIGHT if i % 2 == 0 else Pal.LEAF)
	for i in 5:
		var fh := Vector2(lerpf(x0 + 50.0, x1 - 50.0, float(i) / 4.0) + (_hash(i, 7) - 0.5) * 30.0, y - h * (0.45 + 0.3 * _hash(i, 13)))
		for q in 5:
			b.disc(fh + Vector2.from_angle(float(q) * TAU / 5.0) * h * 0.11, h * 0.11, Pal.FLOWER if i % 2 == 0 else Pal.SURFACE)
		b.disc(fh, h * 0.08, Pal.SUN)
	Scenery.soft_disc(b, Vector2((x0 + x1) * 0.5, y + h + 8.0), (x1 - x0) * 0.52, 14.0, Color(Pal.TEXT, 0.14))
	b.fan(PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1 - 16.0, y + h), Vector2(x0 + 16.0, y + h)]), Pal.POT_CLAY)
	b.fan(Face.Builder.round_rect(Vector2(x0 - 8.0, y - 6.0), Vector2(x1 - x0 + 16.0, 16.0), 6.0), Pal.POT_RIM)
	b.fan(Face.Builder.round_rect(Vector2(x0 + 30.0, y + 18.0), Vector2((x1 - x0) * 0.3, 5.0), 2.5), Color(1.0, 1.0, 1.0, 0.18))
	# ivy trailing over the lip
	for k in IVY.size():
		var at := Vector2(lerpf(x0 + 30.0, x1 - 30.0, IVY[k]), y + 6.0)
		for q in 4:
			var p := at + Vector2(sin(float(q) * 1.3 + float(k)) * 7.0, float(q) * h * 0.3)
			if q > 0:
				b.stroke(PackedVector2Array([at + Vector2(sin(float(q - 1) * 1.3 + float(k)) * 7.0, float(q - 1) * h * 0.3), p]),
					2.5, Pal.LEAF_DEEP)
			Parts.leaf(b, p, h * 0.34, PI * 0.5 + (0.8 if q % 2 == 0 else -0.8), Pal.LEAF if q % 2 == 0 else Pal.LEAF_DEEP)

## A stable hash of two ints, 0 to 1: the floor's tile tones.
static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) ^ (a * b * 1274126177)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0x7fffffff) / float(0x7fffffff)

func _entry(i: int, t: float) -> float:
	if Motion.reduce:
		return 1.0
	var e := t - _opened - Motion.ENTER_DELAY - 0.2 - Motion.stagger(i, 0.05)
	return 0.01 if e <= 0.0 else Motion.pop_in_scale(e).x

## The peg a held piece will land on, the cups under the light and the light
## itself (`_lower`), and over it the light's spark, the drops, the mirrors
## and the rings (`_upper`). The
## bud, the glints and everything that moves at rest are the air's. Every
## piece is a look made once in the reference layout and copied under its
## moment's transform (Quilt's and Rings' lesson): drawing them in script
## cost 3.2-6 ms a frame while anything moved, a held piece included.
func _build_live(t: float) -> void:
	var s := _cell()
	var n: int = _state.pieces().size()
	if _tr.is_empty():
		_tr = _trace_live(t)
	var drawn := _drawn(t)
	var bpts: PackedVector2Array = _tr.pts
	if not _rooms_laid:
		_lay_rooms()
	_rm_lo.begin()
	if not _drag.is_empty():
		# the peg the held piece lands on if let go now
		var hp: int = _drag.p
		_rm_lo.open(0, 0)
		_rm_lo.put(_look("target", _mk_target), [], Transform2D(0.0, _pt(_piece_mid(hp, float(_state.pos[hp])))))
	for p in n:
		var pc: Dictionary = _state.g.pieces[p]
		if pc.kind != "u":
			continue
		var peg := _peg_now(p, t)
		var e := _entry(p, t) * _land(p, t)
		var mid := _pt(_piece_mid(p, peg)) + Vector2(_shiver(p, t), 0.0)
		var lift := _stepped(_lift(p, t), LIFT_STEPS)
		var pin: bool = _state.pinned.has(p)
		_rm_lo.open(1, p)
		_rm_lo.put(_cup_look(p, pin, lift), [], Transform2D(0.0, Vector2(e, e), 0.0, mid))
	_rm_lo.close()
	_put_beam(drawn)
	_lower = _rm_lo.mesh()
	_rm_hi.begin()
	_rm_hi.open(0, 0)
	if _arrived(t) and String(_tr.end) in ["pot", "cup", "lamp"]:
		_rm_hi.put(_look("end", _mk_end), [], Transform2D(0.0, _pt(bpts[bpts.size() - 1])))
	elif not _arrived(t) and drawn > 0.0:
		# the light's leading spark on its first run out of the lamp
		var tip := _along(drawn)
		_rm_hi.put(_look("spark", _mk_spark), [], Transform2D(0.0, tip))
		_rm_hi.put(_look("star", _mk_star.bind(0.24, Pal.BEAM_CORE)), [], Transform2D(drawn * 0.4, tip))
	var shy := _state.shy() and _solved_at <= AGO and not _state.is_solved()
	var lift_y := Vector2(0.0, s * 0.17 * 0.2)
	for i in _state.drops().size():
		var c: int = _state.drops()[i]
		var wet: bool = _wet.has(c)
		var sc := Vector2.ONE * _entry(i + 2, t)
		var glow := 1.0
		var at := _centre(c)
		var dry_e := t - float(_dried.get(c, AGO))
		_rm_hi.open(2, i)
		if dry_e < DRY_TIME:
			# dried by a wrong move: it shrinks to a speck in a puff of
			# steam, and fills back up again as the move slides back
			var k := 0.35 + 0.65 * smoothstep(0.35, 1.0, dry_e / DRY_TIME)
			_rm_hi.put(_look("drop0", _mk_drop.bind(false)), [], Transform2D(0.0, sc * k, 0.0, at + lift_y))
			continue
		if wet and shy:
			# a shy drop under a held piece's light: it trembles, blushing
			# by a rose halo (never a shade of the drop), and would dry if
			# the piece were let go here
			if not Motion.reduce:
				at.x += sin(t * 46.0 + float(i)) * SHY_SHAKE
			_rm_hi.put(_look("blush", _mk_blush), [], Transform2D(0.0, at))
			_rm_hi.put(_look("drop0", _mk_drop.bind(false)), [], Transform2D(0.0, sc, 0.0, at + lift_y))
			continue
		if wet:
			var pu := _pulse(t - float(_chimed.get(c, -100.0)), 0.26)
			sc *= Vector2(1.0, 1.0) + Vector2(0.08, -0.16) * pu
			glow += 0.6 * _pulse(t - float(_chimed.get(c, -100.0)), 0.5)
			_rm_hi.put(_look("dew", _mk_dew), [], Transform2D(0.0, Vector2(glow, glow), 0.0, at))
		_rm_hi.put(_look("drop%d" % int(wet), _mk_drop.bind(wet)), [], Transform2D(0.0, sc, 0.0, at + lift_y))
	for p in n:
		var pc: Dictionary = _state.g.pieces[p]
		if pc.kind != "m":
			continue
		var at := _pt(_piece_mid(p, _peg_now(p, t))) + Vector2(_shiver(p, t), 0.0)
		var lift := _stepped(_lift(p, t), LIFT_STEPS)
		var pin: bool = _state.pinned.has(p)
		var slash: bool = pc.t == "/"
		var k := _entry(p, t) * _land(p, t)
		var xf := Transform2D(0.0, Vector2(k, k), 0.0, at)
		_rm_hi.open(3, p)
		_rm_hi.put(_mirror_look(p, pin, lift), [], xf)
		if lift > 0.0:
			# the sheen sliding along the glass with the slide: its own look,
			# so the glass under it stays one
			var u := fposmod(_peg_now(p, t) * 0.8, 1.0)
			var x := lerpf(-0.85, 0.85, u) * s * 0.4
			_rm_hi.put(_look("sheen", _mk_sheen), [],
				xf * Transform2D(-PI * 0.25 if slash else PI * 0.25, Vector2(0.0, -lift * 6.0)) * Transform2D(0.0, Vector2(x, 0.0)))
	_rm_hi.close()
	_drop_rings(t)
	for r: Dictionary in _rings:
		var u := (t - float(r.at)) / Motion.RING_TIME
		if u >= 0.0 and u < 1.0:
			var q := floorf(u * RING_STEPS) / RING_STEPS
			_rm_hi.put(_look("ring%.3f" % q, _mk_ring.bind(q)), [], Transform2D(0.0, _pt(r.pos)))
	_upper = _rm_hi.mesh()

## Each piece's run of vertices in the lower and upper meshes, as long as its
## largest look: the target peg, every cup; the light's spark, every drop
## (its glow or blush and its body), every mirror (and its sheen). Rings go
## on the tail.
func _lay_rooms() -> void:
	_rooms_laid = true
	_rm_lo = RunMesh.new(_make_look)
	_rm_hi = RunMesh.new(_make_look)
	_rm_lo.share_shapes(_rm)
	_rm_hi.share_shapes(_rm)
	_rm_lo.room(0, 0, _rm.size_of(_look("target", _mk_target)))
	var n: int = _state.pieces().size()
	for p in n:
		if _state.g.pieces[p].kind == "u":
			_rm_lo.room(1, p, maxi(_rm.size_of(_cup_look(p, true, 0.0)), _rm.size_of(_cup_look(p, false, 0.0))))
	_rm_hi.room(0, 0, maxi(_rm.size_of(_look("end", _mk_end)),
		_rm.size_of(_look("spark", _mk_spark)) + _rm.size_of(_look("star", _mk_star.bind(0.24, Pal.BEAM_CORE)))))
	var body := maxi(_rm.size_of(_look("drop0", _mk_drop.bind(false))), _rm.size_of(_look("drop1", _mk_drop.bind(true))))
	var halo := maxi(_rm.size_of(_look("dew", _mk_dew)), _rm.size_of(_look("blush", _mk_blush)))
	for i in _state.drops().size():
		_rm_hi.room(2, i, body + halo)
	var sheen := _rm.size_of(_look("sheen", _mk_sheen))
	for p in n:
		if _state.g.pieces[p].kind == "m":
			_rm_hi.room(3, p, maxi(_rm.size_of(_mirror_look(p, true, 0.0)), _rm.size_of(_mirror_look(p, false, 0.0))) + sheen)

func _cup_look(p: int, pin: bool, lift: float) -> int:
	var pc: Dictionary = _state.g.pieces[p]
	return _look("u%d.%d.%d.%.3f" % [pc.s, pc.f, int(pin), lift], _mk_cup.bind(int(pc.s), int(pc.f), pin, lift))

func _mirror_look(p: int, pin: bool, lift: float) -> int:
	var slash: bool = _state.g.pieces[p].t == "/"
	return _look("m%d.%d.%.3f" % [int(slash), int(pin), lift], _mk_mirror.bind(slash, pin, lift))

## `v` (0 to 1) to the nearest of `steps` steps: a look's key.
static func _stepped(v: float, steps: float) -> float:
	return roundf(clampf(v, 0.0, 1.0) * steps) / steps

# --- the looks, each about its own origin at the reference cell ---

func _mk_target(b: Face.Builder) -> void:
	var s := _cell()
	Scenery.soft_disc(b, Vector2.ZERO, s * 0.42, s * 0.42, Color(Pal.BEAM, 0.45))
	b.stroke(Face.Builder.ring(Vector2.ZERO, s * 0.2, s * 0.2), 3.0, Color(Pal.BEAM_CORE, 0.9), true)

## A cup about its middle: `sd` the side its second cell is on, `fd` the way
## its mouth faces.
func _mk_cup(b: Face.Builder, sd: int, fd: int, pinned: bool, lift: float) -> void:
	var s := _cell()
	var sv := Vector2(Gen.DX[sd], Gen.DY[sd])
	var f := Vector2(Gen.DX[fd], Gen.DY[fd])
	Parts.cup(b, Parts.cup_path(-sv * s * 0.5, sv * s * 0.5, s, f), s, f, lift, pinned)

func _mk_mirror(b: Face.Builder, slash: bool, pinned: bool, lift: float) -> void:
	Parts.mirror(b, Vector2.ZERO, _cell(), slash, lift, pinned)

## Parts.mirror's sheen at the middle of the glass, in the glass's frame.
func _mk_sheen(b: Face.Builder) -> void:
	var th := _cell() * 0.075
	b.fan(PackedVector2Array([Vector2(-th * 0.2, -th * 0.9), Vector2(th * 0.5, -th * 0.9),
		Vector2(th * 0.2, th * 0.9), Vector2(-th * 0.5, th * 0.9)]), Color(1.0, 1.0, 1.0, 0.9))

func _mk_end(b: Face.Builder) -> void:
	b.disc(Vector2.ZERO, _cell() * 0.07, Color(Pal.BEAM, 0.8))

func _mk_spark(b: Face.Builder) -> void:
	var s := _cell()
	Scenery.soft_disc(b, Vector2.ZERO, s * 0.4, s * 0.4, Color(Pal.BEAM, 0.7))

## A four-pointed star `r` cells across, unturned.
func _mk_star(b: Face.Builder, r: float, col: Color) -> void:
	Parts.star(b, Vector2.ZERO, _cell() * r, col)

## A drop's body about its belly (Parts.drop's, without its glow).
func _mk_drop(b: Face.Builder, lit: bool) -> void:
	var r := _cell() * 0.17
	var shape := Parts._drop_shape(r)
	b.polygon(Parts._grow(shape, 3.0), Pal.DEW_LIT_EDGE if lit else Pal.DEW_EDGE)
	b.polygon(shape, Pal.DEW_LIT if lit else Pal.DEW)
	b.ellipse(Vector2(-r * 0.35, -r * 0.05), r * 0.16, r * 0.26, Color(1.0, 1.0, 1.0, 0.9))

## A lit drop's glow (Parts.drop's).
func _mk_dew(b: Face.Builder) -> void:
	var s := _cell()
	Scenery.soft_disc(b, Vector2.ZERO, s * 0.5, s * 0.5, Color(Pal.BEAM, 0.55))

func _mk_blush(b: Face.Builder) -> void:
	var s := _cell()
	b.stroke(Face.Builder.ring(Vector2.ZERO, s * 0.3, s * 0.3), s * 0.05, Color(Pal.FLOWER, 0.85), true)

## A drop's ring `u` of the way through.
func _mk_ring(b: Face.Builder, u: float) -> void:
	var s := _cell()
	var rad := s * (0.3 + 0.4 * u)
	b.stroke(Face.Builder.ring(Vector2.ZERO, rad, rad), s * 0.05 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)

## How far along the beam each drop it passes lies, in order: the steps at
## which the light gathers strength. Snails are not dew.
func _drop_marks() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var dm: Dictionary = _tr.get("drop_at", {})
	for c in _state.drops():
		if dm.has(c):
			out.append(float(dm[c]))
	out.sort()
	return out

## The light's strength `at` cells along the beam, 0 (straight out of the
## sun) to 1 (every drop passed).
func _power_at(at: float, marks := _drop_marks()) -> float:
	var n: int = _state.drops().size()
	if n <= 0:
		return 1.0
	var k := 0
	for m in marks:
		if m <= at:
			k += 1
	return float(k) / float(n)

## The beam drawn up to `drawn` cells, a stretch per drop it passes, each
## fuller and brighter than the last: Parts.beam's three passes a stretch,
## each run's body a strip drawn here and its round caps a disc look (the
## caps were most of the beam's vertices), on the lower mesh's tail.
func _put_beam(drawn: float) -> void:
	var s := _cell()
	var n: int = _state.drops().size()
	var marks := _drop_marks()
	var from := 0.0
	for i in marks.size() + 1:
		var to: float = marks[i] if i < marks.size() else _total()
		var z := minf(to, drawn)
		if z > from:
			var pw := float(i) / float(n) if n > 0 else 1.0
			var alpha := lerpf(WEAK_ALPHA, 1.0, pw)
			var width := lerpf(WEAK_WIDTH, 1.0, pw)
			var runs := Parts._runs(_span(from, z))
			for pass_i: Vector2 in [Parts.BEAM_GLOW, Parts.BEAM_HALO, Parts.BEAM_CORE]:
				var col := Color(Pal.BEAM_CORE if pass_i == Parts.BEAM_CORE else Pal.BEAM, pass_i.y * alpha)
				var w := s * pass_i.x * width
				var body := Face.Builder.new()
				var caps: Array = []
				for r: PackedVector2Array in runs:
					if r.size() >= 2 and r[0].distance_to(r[r.size() - 1]) > 0.5:
						body.stroke(r, w, col, false, false)
						caps.append(r[0])
						caps.append(r[r.size() - 1])
				_rm_lo.put_builder(body)
				var cap := _look("cap%.3f.%s" % [w, col.to_html()], _mk_cap.bind(w * 0.5, col))
				for at: Vector2 in caps:
					_rm_lo.put(cap, [], Transform2D(0.0, at))
		from = to
		if from >= drawn:
			break

func _mk_cap(b: Face.Builder, r: float, col: Color) -> void:
	b.disc(Vector2.ZERO, r, col)

## How much the light reaching the bud feeds it now: nothing unless the
## drawn beam ends there, else (drops passed + 1) / (drops + 1).
func _grow_goal() -> float:
	if _tr.is_empty() or String(_tr.end) != "bud" or not _arrived(_now()):
		return 0.0
	var n: int = _state.drops().size()
	return float(_drop_marks().size() + 1) / float(n + 1)

## Eases the bud toward what the light feeds it: up quickly, down slowly.
func _feed_bud(delta: float) -> void:
	var goal := _grow_goal()
	if Motion.reduce:
		_grow = goal
		return
	var tau := GROW_UP if goal > _grow else GROW_DOWN
	_grow = lerpf(_grow, goal, 1.0 - exp(-delta / tau))
	if absf(_grow - goal) < 0.002:
		_grow = goal

## How far the bloom has got, 0 to 1, linear (the bud eases it).
func _bloom(t: float) -> float:
	if _bloom_at <= AGO:
		return 0.0
	if Motion.reduce:
		return 1.0
	return clampf((t - _bloom_at) / BLOOM_TIME, 0.0, 1.0)

## A let-go piece's scale as it lands on its peg: a dip and a rebound.
func _land(p: int, t: float) -> float:
	var d: Dictionary = _disp[p]
	if not d.get("lift", false):
		return 1.0
	return Motion.bump_scale(t - float(d.at) - SNAP_TIME, LAND, LAND_TIME)

## 0 to 1 and back over `time`, once: a drop's squash as it is wet.
func _pulse(e: float, time: float) -> float:
	if Motion.reduce or e < 0.0 or e >= time:
		return 0.0
	return sin(PI * e / time)

## How far piece `p` is raised off the floor: up over LIFT_TIME as a finger
## takes it, down again as it settles onto its peg.
func _lift(p: int, t: float) -> float:
	if not _drag.is_empty() and int(_drag.p) == p:
		return 1.0 if Motion.reduce else clampf((t - float(_drag.at)) / Motion.LIFT_TIME, 0.0, 1.0)
	var d: Dictionary = _disp[p]
	if Motion.reduce or not d.get("lift", false):
		return 0.0
	return 1.0 - clampf((t - float(d.at)) / SNAP_TIME, 0.0, 1.0)

func _shiver(p: int, t: float) -> float:
	if int(_refused.p) != p:
		return 0.0
	return Motion.shiver_offset(t - float(_refused.at)) * 3.0

## Everything that moves at rest, rebuilt every frame and nothing else: the
## sun's turning rays, the motes drifting down the light, the pulses flowing
## along its core, a twinkling glint on every mirror it strikes, the bud (it
## sways once open), and on the solve the gold wave and the drifting petals.
## The sun, the motes, the pulses' glow, the glints and the bud are looks
## under transforms (a mote's and a pulse's fade in steps); only the pulses'
## cores, the z's, the wave and the petals are drawn live.
func _build_air(t: float) -> ArrayMesh:
	var s := _cell()
	_rm_air.begin()
	var lamp := _centre(_state.g.lamp)
	var k0 := _entry(0, t)
	var turn := 0.0 if Motion.reduce else t * SUN_TURN
	_rm_air.put(_look("rays", _mk_rays), [], Transform2D(turn, Vector2(k0, k0), 0.0, lamp))
	_rm_air.put(_look("sun", _mk_sun), [], Transform2D(0.0, Vector2(k0, k0), 0.0, lamp))
	var tot := _drawn(t)
	if not Motion.reduce:
		var count := int(tot * MOTE_DENSITY)
		for k in count:
			var at := fmod(float(k) / MOTE_DENSITY + t * MOTE_SPEED, tot)
			var p := _along(at) + Vector2(sin(float(k) + t), cos(float(k) * 1.3 + t)) * s * 0.05
			var a := roundi((0.4 * sin(float(k) * 1.7 + t * 3.0) + 0.4) / 0.8 * FADE_STEPS)
			_rm_air.put(_faded("mote", a, _mk_mote), [], Transform2D(0.0, p))
		if _arrived(t) and tot > PULSE_LEN:
			var marks := _drop_marks()
			var cores := Face.Builder.new()
			var ends: Array = []
			var n := int(ceil(tot / PULSE_GAP))
			for k in n:
				var head := fmod(t * PULSE_SPEED + float(k) * PULSE_GAP, float(n) * PULSE_GAP)
				if head > tot:
					continue
				var fade := clampf(head / 0.8, 0.0, 1.0) * clampf((tot - head) / 0.8, 0.0, 1.0)
				var pw := _power_at(head, marks)
				var wd := lerpf(WEAK_WIDTH, 1.0, pw)
				fade *= lerpf(WEAK_ALPHA + 0.25, 1.0, pw)
				var f := roundi(clampf(fade, 0.0, 1.0) * FADE_STEPS)
				if f > 0:
					_rm_air.put(_faded("pulse", f, _mk_pulse), [], Transform2D(0.0, Vector2(wd, wd), 0.0, _along(head)))
				# the core a strip, its round ends a disc look each
				var core := _span(head - PULSE_LEN, head)
				if core.size() >= 2:
					cores.stroke(core, s * 0.09 * wd, Color(Pal.BEAM_CORE, 0.9 * fade), false, false)
					if f > 0:
						var cap := _faded("pcap", f, _mk_pcap)
						ends.append([cap, Transform2D(0.0, Vector2(wd, wd), 0.0, core[0])])
						ends.append([cap, Transform2D(0.0, Vector2(wd, wd), 0.0, core[core.size() - 1])])
			_rm_air.put_builder(cores)
			for e: Array in ends:
				_rm_air.put(e[0], [], e[1])
	# a glint where the drawn light strikes each mirror's glass
	for k in _tr.glints.size():
		var gl: Array = _tr.glints[k]
		if float(gl[1]) <= tot:
			var tw := 1.0 if Motion.reduce else 0.85 + 0.25 * sin(t * 2.2 + float(k) * 1.7)
			var at := _pt(gl[0])
			_rm_air.put(_look("glow", _mk_glow), [], Transform2D(0.0, at))
			_rm_air.put(_look("glint", _mk_star.bind(0.21, Pal.BEAM_CORE)), [],
				Transform2D(0.0 if Motion.reduce else t * 0.5 + float(k), Vector2(tw, tw), 0.0, at))
			_rm_air.put(_look("glint_eye", _mk_glint_eye), [], Transform2D(0.0, at))
	var live := Face.Builder.new()
	_zs(live, t)
	# the solve's wave, from the sun to the bud
	if _solved_at > AGO and not Motion.reduce:
		var head := (t - _solved_at) * _wave_speed
		if head > 0.0 and head < _total() + 1.5:
			_stroke(live, _span(head - 1.8, head), s * 0.26, Color(Pal.BEAM_CORE, 0.5))
			_stroke(live, _span(head - 1.0, head), s * 0.12, Color.WHITE)
			if head < _total():
				Scenery.soft_disc(live, _along(head), s * 0.5, s * 0.5, Color(Pal.BEAM, 0.7))
	_rm_air.put_builder(live)
	var open := _stepped(_bloom(t), BUD_STEPS)
	var glow: bool = _tr.end == "bud" and _arrived(t) and _solved_at <= AGO
	var sway := 0.0
	if open >= 1.0 and not Motion.reduce:
		sway = roundf(sin((t - _bloom_at) * 1.3) * SWAY_STEPS) / SWAY_STEPS * 0.07
	var grow := 0.0 if open > 0.0 else _stepped(_grow, BUD_STEPS)
	var bud := _centre(_state.g.bud)
	var kb := _entry(_state.pieces().size() + 1, t)
	var bid := _look("bud%.3f.%d.%.4f.%.3f" % [open, int(glow), sway, grow], _mk_bud.bind(open, glow, sway, grow))
	_rm_air.put(bid, [], Transform2D(0.0, Vector2(kb, kb), 0.0, bud))
	if _bloom_at > AGO and not Motion.reduce:
		var e := t - _bloom_at - BLOOM_TIME * 0.4
		if e > 0.0 and e < PETAL_LIFE:
			var petals := Face.Builder.new()
			var u := e / PETAL_LIFE
			for i in PETALS:
				var ang := -PI * 0.5 + (float(i) - float(PETALS - 1) * 0.5) * 0.6
				var out := Vector2.from_angle(ang) * s * (0.3 + 1.3 * (1.0 - exp(-2.2 * e)))
				var at := bud + Vector2(0.0, -s * 0.06) + out \
					+ Vector2(sin(e * 3.0 + float(i) * 1.9) * s * 0.14, e * e * s * 0.22)
				Parts.petal(petals, at, s * 0.09, e * 2.4 + float(i), 1.0 - u * u)
			_rm_air.put_builder(petals)
	return _rm_air.mesh()

## The look `name` faded to step `k` of FADE_STEPS, its id kept in a row a
## name (a mote's and a pulse's every frame at rest).
func _faded(name: String, k: int, maker: Callable) -> int:
	var row: PackedInt32Array = _fades.get(name, PackedInt32Array())
	if row.is_empty():
		for i in int(FADE_STEPS) + 1:
			var f := float(i) / FADE_STEPS
			row.append(_look("%s%.3f" % [name, f], maker.bind(f)))
		_fades[name] = row
	return row[clampi(k, 0, row.size() - 1)]

func _mk_rays(b: Face.Builder) -> void:
	var s := _cell()
	for i in 10:
		var d := Vector2.from_angle(float(i) * PI / 5.0)
		var n := d.orthogonal()
		b.fan(PackedVector2Array([d * s * 0.22 + n * s * 0.045, d * s * 0.36, d * s * 0.22 - n * s * 0.045]), Pal.BEAM)

## The sun's disc and its shine (Parts.sun's, without the rays).
func _mk_sun(b: Face.Builder) -> void:
	var s := _cell()
	b.disc(Vector2.ZERO, s * 0.2, Pal.SUN)
	b.disc(Vector2(-s * 0.05, -s * 0.05), s * 0.1, Pal.BEAM)

## A mote, `a` of the way from its faintest to its brightest.
func _mk_mote(b: Face.Builder, a: float) -> void:
	b.disc(Vector2.ZERO, _cell() * 0.018, Color(1.0, 1.0, 1.0, 0.1 + 0.8 * a))

## A pulse's glow at full width, faded to `f`.
func _mk_pulse(b: Face.Builder, f: float) -> void:
	var s := _cell()
	Scenery.soft_disc(b, Vector2.ZERO, s * 0.2, s * 0.2, Color(Pal.BEAM, 0.45 * f))

## A pulse's round end at full width, faded to `f`.
func _mk_pcap(b: Face.Builder, f: float) -> void:
	b.disc(Vector2.ZERO, _cell() * 0.045, Color(Pal.BEAM_CORE, 0.9 * f))

func _mk_glow(b: Face.Builder) -> void:
	var s := _cell()
	Scenery.soft_disc(b, Vector2.ZERO, s * 0.22, s * 0.22, Color(Pal.BEAM, 0.55))

func _mk_glint_eye(b: Face.Builder) -> void:
	b.disc(Vector2.ZERO, _cell() * 0.05, Color.WHITE)

func _mk_bud(b: Face.Builder, open: float, glow: bool, sway: float, grow: float) -> void:
	Parts.bud(b, Vector2.ZERO, _cell(), open, glow, 0.0, sway, grow)

## A stroke along `pts`, if there is one to draw.
static func _stroke(b: Face.Builder, pts: PackedVector2Array, w: float, col: Color) -> void:
	if pts.size() >= 2:
		b.stroke(pts, w, col)

## The beam between `a` and `z` cells along it, in pixels.
func _span(a: float, z: float) -> PackedVector2Array:
	var pts: PackedVector2Array = _tr.pts
	var lens: PackedFloat32Array = _tr.len
	a = maxf(a, 0.0)
	z = minf(z, _total())
	var out := PackedVector2Array()
	if z <= a:
		return out
	out.append(_along(a))
	for i in range(1, lens.size() - 1):
		if lens[i] > a and lens[i] < z:
			out.append(_pt(pts[i]))
	out.append(_along(z))
	return out

# --- input ---

func _gui_input(event: InputEvent) -> void:
	if _done or out_of_hearts or busy():
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
		accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and not _drag.is_empty():
		_move(event.position)
		accept_event()

## The piece under a local point, or -1: a mirror's cell, or either of a
## cup's two; where two rails cross, the one drawn last (a mirror) wins.
func _piece_at(local: Vector2) -> int:
	var t := _now()
	var s := _cell()
	var hit := -1
	for kind in ["u", "m"]:
		for p in _state.pieces().size():
			var pc: Dictionary = _state.g.pieces[p]
			if pc.kind != kind:
				continue
			# The box round the piece's cells: one cell for a mirror, both of a
			# cup's -- whose middle is the line between them, so testing each
			# cell on its own would miss the very point a thumb aims at.
			var a := _pt(_anchor(p, _peg_now(p, t)))
			var box := Rect2(a - Vector2.ONE * s * 0.5, Vector2.ONE * s)
			if kind == "u":
				box = box.merge(Rect2(a + Vector2(Gen.DX[pc.s], Gen.DY[pc.s]) * s - Vector2.ONE * s * 0.5, Vector2.ONE * s))
			if box.has_point(local):
				hit = p
	return hit

## An empty peg under a local point: {"p", "q"} or {}.
func _peg_at(local: Vector2) -> Dictionary:
	var s := _cell()
	var v := (local - _origin()) / s
	var x := int(floor(v.x))
	var y := int(floor(v.y))
	if x < 0 or y < 0 or x >= _state.cols or y >= _state.rows:
		return {}
	var c: int = y * _state.cols + x
	for p in _state.pieces().size():
		var q: int = _state.g.pieces[p].rail.find(c)
		if q >= 0:
			return {"p": p, "q": q}
	return {}

## The float peg under the finger, projected onto piece `p`'s rail.
func _rail_s(p: int, local: Vector2) -> float:
	var n: int = _state.g.pieces[p].rail.size()
	var a := _pt(_piece_mid(p, 0.0))
	var z := _pt(_piece_mid(p, float(n - 1)))
	var d := z - a
	return clampf((local - a).dot(d) / maxf(d.length_squared(), 1e-6) * float(n - 1), 0.0, float(n - 1))

func _press(local: Vector2) -> void:
	var t := _now()
	_peg_press = {}
	var p := _piece_at(local)
	if p >= 0:
		if _state.pinned.has(p):
			_refuse(p, t)
			return
		var s := _peg_now(p, t)
		_drag = {"p": p, "s": s, "off": s - _rail_s(p, local), "before": _state.pos.duplicate(), "at": t}
		_shy_told = false
		fx.cue("lift")
		_refresh()
		return
	var pg := _peg_at(local)
	if not pg.is_empty():
		_peg_press = pg

func _move(local: Vector2) -> void:
	var t := _now()
	var p: int = _drag.p
	var n: int = _state.g.pieces[p].rail.size()
	_drag.s = clampf(_rail_s(p, local) + float(_drag.off), 0.0, float(n - 1))
	var q: int = _state.snap(p, float(_drag.s))
	if q != _state.pos[p] and _state.place(p, q):
		fx.cue("step")
	_refresh()

func _release(local: Vector2) -> void:
	var t := _now()
	if not _drag.is_empty():
		var p: int = _drag.p
		_disp[p] = {"from": float(_drag.s), "at": t, "lift": true}
		var before: PackedInt32Array = _drag.before
		_drag = {}
		_busy_for(SNAP_TIME + LAND_TIME)
		_land_puff(p)
		if _state.commit(before):
			if not _judged_wrong(p, before, t):
				fx.cue("slide")
				note_move()
				_after_move(before)
		else:
			fx.cue("drop")
		_refresh()
		return
	if _peg_press.is_empty():
		return
	var pg := _peg_at(local)
	var want := _peg_press
	_peg_press = {}
	if pg.is_empty() or int(pg.p) != int(want.p) or int(pg.q) != int(want.q):
		return
	var p: int = pg.p
	if _state.pinned.has(p):
		_refuse(p, t)
		return
	if _state.taken(p, pg.q):
		_refuse(p, t, "SB_TAKEN")
		return
	var before: PackedInt32Array = _state.pos.duplicate()
	var from := float(_state.pos[p])
	if _state.place(p, pg.q):
		_disp[p] = {"from": from, "at": t, "lift": true}
		_busy_for(SNAP_TIME + LAND_TIME)
		_land_puff(p)
		_state.commit(before)
		if not _judged_wrong(p, before, t):
			fx.cue("slide")
			note_move()
			_after_move(before)
		_refresh()

## A little puff off the rail where piece `p` lands, as it lands.
func _land_puff(p: int) -> void:
	if Motion.reduce:
		return
	var at := _pt(_piece_mid(p, float(_state.pos[p]))) + Vector2(0.0, _cell() * 0.22)
	get_tree().create_timer(SNAP_TIME).timeout.connect(func(): fx.puff(at, Pal.SURFACE, 4))

func _refuse(p: int, t: float, line := "SB_PINNED") -> void:
	_refused = {"at": t, "p": p}
	_busy_for(Motion.SHIVER_TIME * 2.0)
	fx.cue("refuse")
	_say(tr(line), Face.Expr.STRAIN)
	_refresh()

## A ring out of `at` (Control-local), kept in cell units: it is drawn in
## the reference layout.
func _ring_at(at: Vector2, when: float) -> void:
	if Motion.reduce:
		return
	_rings.append({"pos": (at - _origin()) / _cell(), "at": when})
	_busy_for(when - _now() + Motion.RING_TIME)

func _drop_rings(t: float) -> void:
	var keep: Array = []
	for r: Dictionary in _rings:
		if t - float(r.at) < Motion.RING_TIME:
			keep.append(r)
	_rings = keep

# --- the sprout's line ---

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _state.can_undo():
		return
	var tips := _tips()
	_tip_idx = (_tip_idx + 1) % tips.size()
	_say(tr(tips[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

## Every piece whose peg changed since `before` settles onto its new one.
func _settle(before: PackedInt32Array, t: float, stagger := 0.0) -> void:
	var k := 0
	for p in before.size():
		if before[p] != _state.pos[p]:
			_disp[p] = {"from": float(before[p]), "at": t + Motion.stagger(k, stagger), "lift": false}
			k += 1
	_busy_for(Motion.stagger(k, stagger) + SNAP_TIME)

func can_undo() -> bool:
	return _state.can_undo() and not is_done() and not out_of_hearts and not busy() \
		and _state.difficulty < 3

## Puts the pieces back as they were before the last move. Counts no move.
func undo() -> bool:
	if not can_undo():
		return false
	var before: PackedInt32Array = _state.pos.duplicate()
	if not _state.undo():
		return false
	_undo_ever = true
	_break_streak()
	_clear_gags()
	var t := _now()
	_settle(before, t)
	_say(tr("SB_UNDONE"), Face.Expr.HAPPY)
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

func hints_left() -> int:
	return maxi(0, State.hints_for(_state.difficulty) + hints_extra - hints_used)

## Slides the next piece along the answer's beam home and pins it there (on
## Hard, the first such piece that wakes no snail).
func hint() -> bool:
	if is_done() or out_of_hearts or busy() or hints_left() <= 0:
		return false
	var t := _now()
	var before: PackedInt32Array = _state.pos.duplicate()
	var r: Dictionary = _state.hint()
	if r.is_empty():
		return false
	hints_used += 1
	_break_streak()
	_settle(before, t)
	var p: int = r.piece
	_ring_at(_pt(_piece_mid(p, float(_state.pos[p]))), t + SNAP_TIME)
	_say(tr("SB_HINT"), Face.Expr.HAPPY)
	fx.cue("hint")
	_refresh()
	moved.emit()
	check_solved()
	return true

func can_reset() -> bool:
	return not (is_done() or out_of_hearts or busy())

func reset_board() -> void:
	if not can_reset():
		return
	var before: PackedInt32Array = _state.pos.duplicate()
	_break_streak()
	_clear_gags()
	_state.reset_board()
	var t := _now()
	_drag = {}
	_settle(before, t, Motion.RESET_STAGGER)
	_rings = []
	_solved_at = AGO
	_bloom_at = AGO
	moves = 0
	_running = true
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()
	moved.emit()

func is_solved() -> bool:
	return _state.is_solved()

## The shape of the day and never its answer: the sun, a drop each, the bud.
func share_glyphs() -> String:
	var out := "☀️" + "💧".repeat(_state.drops().size()) + "🌸"
	if _state.shy() and is_solved():
		out += " 🫣 " + tr("SB_SHY_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless:
		out += " 🏅 " + tr("BN_FLAWLESS")
	return out

## What a reopened daily needs: the hearts kept and whether it was flawless.
func completion_record() -> Dictionary:
	return {"hearts": hearts, "flawless": _flawless}

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("SB_WIN")}

## The win screen waits for the light to reach the bud, the wave to run the
## beam, and the bloom.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	var bloom := maxf(0.0, _bloom_at - _now()) + BLOOM_TIME + WIN_HOLD
	var party := maxf(0.0, _party_at - _now()) + PARTY_TIME if _party_at < INF else bloom
	return maxf(bloom, party)

func _on_solved() -> void:
	var t := _now()
	_drag = {}
	# The wave waits for the let-go piece to land, and on a first-run beam
	# for the light to get there; the bloom waits for the wave.
	_solved_at = t + maxf(_arrive_in(t), 0.0 if Motion.reduce else SNAP_TIME + LAND_TIME * 0.5)
	_tip_timer.stop()
	# Flawless: no hint, and no heart lost on Hard and Insane, or never an
	# Undo on Easy and Medium.
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 else not _undo_ever)
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = t
	_streak_gen += 1
	_clear_gags()
	if not Motion.reduce:
		_wave_speed = maxf(WAVE_SPEED, _total() / WAVE_MAX)
		_bloom_at = _solved_at + _total() / _wave_speed
		var drops: PackedInt32Array = _state.drops()
		for c in drops:
			# Shy Dew: every drop catches the light at once, the moment it
			# arrives; elsewhere each sparkles as the wave passes.
			var along: float = 0.0 if _state.shy() else float(_tr.drop_at.get(c, 0.0))
			get_tree().create_timer(_solved_at - t + along / _wave_speed).timeout.connect(
				func(): fx.sparkle(_centre(c), Pal.SUN))
		if _state.shy():
			get_tree().create_timer(_solved_at - t).timeout.connect(func():
				fx.cue("chorus")
				for c in drops:
					_ring_at(_centre(c), _now()))
		for gl: Array in _tr.glints:
			var gat := _pt(gl[0])
			get_tree().create_timer(_solved_at - t + float(gl[1]) / _wave_speed).timeout.connect(
				func(): fx.puff(gat, Pal.BEAM_CORE, 4))
		var bud := _centre(_state.g.bud)
		get_tree().create_timer(_bloom_at - t + 0.25).timeout.connect(func(): fx.sparkle(bud, Pal.FLOWER))
		get_tree().create_timer(_bloom_at - t + 0.4).timeout.connect(func(): fx.puff(bud, Pal.SUN, 8))
		get_tree().create_timer(_solved_at - t).timeout.connect(func(): fx.cue("solved"))
	else:
		_bloom_at = _solved_at
		fx.cue("solved")
	_busy_for(_bloom_at - t + BLOOM_TIME)
	_say(tr("SB_WIN"), Face.Expr.JOY)
	_heart_layer.queue_redraw()
	_party()
	_refresh()

## A reopened daily that was already solved: every piece home, the light
## already there and the bud open. Never check_solved(): `solved` must not
## fire twice.
func restore_completed_board() -> void:
	_gen += 1
	_close_card()
	_deal()
	_reset_rewards()
	_make_snails()
	hearts = clampi(int(completed_record.get("hearts", max_hearts)), 0, max_hearts)
	_flawless = bool(completed_record.get("flawless", false))
	_state.pos = _state.home_pos()
	_state.retrace()
	var t := _now()
	_beam_at = t - 100.0
	for p in _disp.size():
		_disp[p] = {"from": float(_state.pos[p]), "at": -100.0, "lift": false}
	# Every drop already wet, so reopening a solved day chimes nothing.
	_wet = {}
	for c in _state.drops():
		_wet[c] = true
	_tr = _trace_live(t)
	_solved_at = t - 100.0
	_bloom_at = t - 100.0
	_anim_until = 0.0
	_opened = t - 100.0
	_cat_at = t - 100.0
	_place_cat(t)
	if _flawless or _state.shy():
		_stamp_at = t - 100.0
	_tip_timer.stop()
	_say(tr("SB_WIN"), Face.Expr.JOY)
	_heart_layer.queue_redraw()
	_life_layer.queue_redraw()
	_refresh()

# --- the judge (Hard and Insane) ---

## Whether a move just let go is wrong -- the light rests on a snail, or on
## Shy Dew on a drop -- and if so plays it out (`_misstep`).
func _judged_wrong(p: int, before: PackedInt32Array, t: float) -> bool:
	if max_hearts <= 0:
		return false
	var kind: String = _state.judge()
	if kind.is_empty():
		return false
	_state.history.pop_back()
	_misstep(p, before, kind, t)
	return true

## A wrong move: it lands, the snails it lit wake with a start (or the drops
## dry in a puff of steam), a heart splits on the pill, and EJECT_AFTER later
## the piece slides back where it was. Input, Undo, Hint and Reset wait.
func _misstep(p: int, before: PackedInt32Array, kind: String, t: float) -> void:
	_lost_ever = true
	_break_streak()
	_clear_gags()
	var cells: PackedInt32Array = _state.woken()
	hearts = maxi(0, hearts - 1)
	_split_index = hearts
	var lands := 0.0 if Motion.reduce else SNAP_TIME
	_split_at = t + lands
	_wrong = {"at": t, "p": p, "kind": kind, "cells": cells}
	var eject := Motion.REDUCED_TIME if Motion.reduce else EJECT_AFTER
	_busy_until = t + eject + (0.0 if Motion.reduce else SNAP_TIME) + 0.05
	_was_busy = true
	_busy_for(maxf(DRY_TIME, eject + SNAP_TIME) + 0.1)
	if hearts <= 0:
		out_of_hearts = true
	_after(lands, func() -> void:
		var now := _now()
		for c in cells:
			if kind == "snail":
				_woke_at[c] = now
			else:
				_dried[c] = now
				if not Motion.reduce:
					fx.puff(_centre(c) - Vector2(0.0, _cell() * 0.15), Pal.SURFACE, 7)
		fx.cue("wake" if kind == "snail" else "sizzle")
		fx.cue("heart_lost")
		_heart_layer.queue_redraw()
		_refresh())
	var line := "SB_WOKE" if kind == "snail" else "SB_DRIED"
	_say(tr(line) + " " + (tr("SB_HEARTS_ONE") if hearts == 1 else (tr("SB_HEARTS_N") % hearts if hearts > 1 else "")),
		Face.Expr.WORRIED)
	_heart_layer.queue_redraw()
	moved.emit()
	_after(eject, _slide_back.bind(before))

## The take-back: every piece the wrong move shifted slides home again.
func _slide_back(before: PackedInt32Array) -> void:
	var now := _now()
	var cur: PackedInt32Array = _state.pos.duplicate()
	_state.take_back(before)
	_settle(cur, now)
	fx.cue("slip")
	_refresh()
	if out_of_hearts:
		_after(SNAP_TIME, _run_out)

## Whether a wrong move is still playing out: input, Undo, Hint and Reset
## wait, and the host holds its hint video.
func busy() -> bool:
	return _now() < _busy_until

# --- the snails ---

## One sleeping snail face on every snail cell, made once a deal.
func _make_snails() -> void:
	for f in _snails:
		if is_instance_valid(f):
			f.queue_free()
	_snails = []
	for i in _state.snails().size():
		var f := SnailFace.new()
		f.name = "Snail%d" % i
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.expression = Face.Expr.SLEEPY
		add_child(f)
		move_child(f, 0)
		f.set_idle(true)
		_snails.append(f)

## Each snail on its cell: asleep; worried while a held piece's light lies on
## it; startled, with a hop, when a let-go move wakes it; dozing off again.
func _place_snails(t: float) -> void:
	var cells := _state.snails()
	var s := _cell()
	if _snails.size() != cells.size() or s <= 0.0:
		return
	var since := t - _opened - Motion.ENTER_DELAY
	var grow := Motion.wide_pop_scale(since) if not Motion.reduce else 1.0
	var mid := _mid()
	for i in cells.size():
		var f: Control = _snails[i]
		var c: int = cells[i]
		var px := s * SNAIL_PX
		if f.size.x != px:
			f.size = Vector2(px, px)
			f.pivot_offset = f.size * 0.5
		var at := mid + (_centre(c) + Vector2(0.0, s * 0.08) - mid) * grow
		var woke := t - float(_woke_at.get(c, AGO))
		var expr := Face.Expr.SLEEPY
		var hop := 0.0
		if woke < EJECT_AFTER + SNAP_TIME + 0.6:
			expr = Face.Expr.STRAIN if woke < EJECT_AFTER else Face.Expr.WORRIED
			if not Motion.reduce and woke < WAKE_TIME:
				hop = sin(PI * woke / WAKE_TIME) * WAKE_HOP * s
		elif _wet.has(c):
			expr = Face.Expr.WORRIED
		if f.expression != expr:
			f.expression = expr
		var flip := -1.0 if _hash(c, 5) < 0.5 else 1.0
		var k := _entry(i + 3, t) * grow
		f.scale = Vector2(flip * k, k)
		f.position = at - f.size * 0.5 - Vector2(0.0, hop)

## Sleepy z's drifting up off each sleeping snail, in the air mesh, and a
## startled "!" over one a let-go move has just woken.
func _zs(b: Face.Builder, t: float) -> void:
	var s := _cell()
	var cells := _state.snails()
	for c in cells:
		var woke := t - float(_woke_at.get(c, AGO))
		if woke >= 0.0 and woke < EJECT_AFTER + SNAP_TIME:
			var k := 1.0 if Motion.reduce else Motion.pop_in_scale(woke, 0.25).x
			var top := _centre(c) + Vector2(s * 0.3, -s * 0.62)
			b.stroke(PackedVector2Array([top, top + Vector2(0.0, s * 0.2 * k)]), s * 0.08 * k, Pal.FLOWER_DEEP)
			b.disc(top + Vector2(0.0, s * 0.32 * k), s * 0.045 * k, Pal.FLOWER_DEEP)
	if Motion.reduce:
		return
	for i in cells.size():
		var c: int = cells[i]
		if _wet.has(c) or t - float(_woke_at.get(c, AGO)) < EJECT_AFTER + SNAP_TIME + 1.2:
			continue
		for k in 2:
			var e := fposmod(t + float(i) * 0.9 + float(k) * Z_EVERY, Z_EVERY * 2.0)
			if e > Z_LIFE:
				continue
			var u := e / Z_LIFE
			var at := _centre(c) + Vector2(s * (0.22 + 0.12 * sin(u * 5.0 + float(i))), -s * (0.3 + Z_RISE * u))
			var r := s * (0.05 + 0.04 * u)
			var a := clampf(u * 4.0, 0.0, 1.0) * clampf((1.0 - u) * 3.0, 0.0, 1.0)
			b.stroke(PackedVector2Array([at + Vector2(-r, -r), at + Vector2(r, -r), at + Vector2(-r, r), at + Vector2(r, r)]),
				maxf(2.0, s * 0.022), Color(Pal.MOON_DEEP, 0.75 * a))

# --- hearts ---

func _draw_hearts() -> void:
	if max_hearts <= 0 or _cell() <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var y := maxf(HEART_TOP + HEART_PILL_PAD.y + HEART_R,
		_origin().y - FRAME - HEART_PILL_PAD.y - HEART_R - 10.0)
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var c := _hearts_at(pill, y)
	y = c.y
	var left := c.x - pill.x * 0.5
	var corner := Vector2(left, y - pill.y * 0.5)
	var rim := Vector2.ONE * HEART_PILL_RIM
	var enter := Motion.pop_in_scale(now - _opened - Motion.ENTER_DELAY).x
	if enter <= 0.0:
		return
	b.polygon(Face.Builder.round_rect(corner - rim, pill + 2.0 * rim, pill.y * 0.5 + HEART_PILL_RIM), Pal.LINE)
	b.polygon(Face.Builder.round_rect(corner, pill, pill.y * 0.5), Pal.SURFACE)
	var x0 := left + HEART_PILL_PAD.x + HEART_R
	for i in max_hearts:
		var at := Vector2(x0 + step * i, y)
		if i < hearts or (i == _split_index and now < _split_at):
			var r := HEART_R
			if i == _back_index and not Motion.reduce:
				r *= Motion.pop_in_scale(now - _back_at, HEART_BACK_TIME).x
			if r > 0.5:
				b.polygon(_heart(at, r, -1), Pal.FLOWER)
				b.polygon(_heart(at, r, 1), Pal.FLOWER_DEEP)
				_heart_face(b, at, r)
			continue
		b.polygon(_heart(at, HEART_R, 0), Color(Pal.FLOWER, 0.22))
		var u := (now - _split_at) / SPLIT_TIME
		if i == _split_index and u < 1.0 and not Motion.reduce:
			var fade := 1.0 - u * u
			for side in [-1, 1]:
				var turn: float = side * SPLIT_TURN * u
				var shift := Vector2(side * SPLIT_SPREAD * u, SPLIT_FALL * u * u)
				var pts := _heart(Vector2.ZERO, HEART_R, side)
				for k in pts.size():
					pts[k] = at + shift + pts[k].rotated(turn)
				b.polygon(pts, Color(Pal.FLOWER if side < 0 else Pal.FLOWER_DEEP, fade))
	_hearts_shown = b.mesh()
	_heart_layer.draw_set_transform(c * (1.0 - enter), 0.0, Vector2.ONE * enter)
	_heart_layer.draw_mesh(_hearts_shown, null)
	_heart_layer.draw_set_transform(Vector2.ZERO)

## The middle of the hearts' pill (`pill` its size): over the floor, at
## height `y` (a tutorial page hangs it beside the floor).
func _hearts_at(_pill: Vector2, y: float) -> Vector2:
	return Vector2(size.x * 0.5, y)

static func _heart_face(b, at: Vector2, s: float) -> void:
	b.ellipse(at + Vector2(-0.5, -0.5) * s, 0.16 * s, 0.1 * s, Color(1.0, 1.0, 1.0, 0.45))
	for sx in [-1.0, 1.0]:
		b.disc(at + Vector2(sx * 0.28, -0.12) * s, 0.09 * s, Pal.OUTLINE)
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, 0.02) * s, 0.16 * s, PI * 0.2, PI * 0.8), 0.07 * s, Pal.OUTLINE)
	b.ellipse(at + Vector2(0.25, -0.76) * s, 0.24 * s, 0.11 * s, Pal.LEAF)

static func _heart(at: Vector2, s: float, side: int) -> PackedVector2Array:
	const STEPS := 36
	var k := s / 16.0
	var off := Vector2(0.0, -2.5)
	var pts := PackedVector2Array()
	var from := 0.0 if side >= 0 else PI
	var to := TAU if side == 0 else from + PI
	var count := STEPS if side == 0 else STEPS / 2 + 1
	for i in count:
		var t := lerpf(from, to, float(i) / float(STEPS if side == 0 else STEPS / 2))
		var p := Vector2(16.0 * pow(sin(t), 3.0),
			-(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)))
		pts.append(at + (p + off) * k)
	if side == 0:
		return pts
	var zig := [Vector2(0.0, 13.0), Vector2(1.5, 8.0), Vector2(-1.5, 3.0), Vector2(1.0, -2.0)]
	if side < 0:
		zig.reverse()
	for z: Vector2 in zig:
		pts.append(at + (z + off) * k)
	return pts

## The last heart is gone: dusk falls on the greenhouse, the snails and the
## sun doze, and the out-of-hearts card comes up.
func _run_out() -> void:
	if _asleep or not out_of_hearts or is_done():
		return
	_asleep = true
	_drag = {}
	_break_streak()
	_clear_gags()
	_tip_timer.stop()
	fx.cue("out_of_hearts")
	_say(tr("SB_OUT"), Face.Expr.SLEEPY)
	_dusk_toward(DUSK)
	_refresh()
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

func _dusk_toward(tint: Color) -> void:
	Motion.stop(_dusk_tw)
	if Motion.reduce:
		modulate = tint
		return
	_dusk_tw = create_tween()
	_dusk_tw.tween_property(self, "modulate", tint, DUSK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["SB_OUT_BODY", "SB_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same floor at its opening, every heart back, the clock and
## the moves from zero. Hints spent stay spent, and so do their pins.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	_gen += 1
	var before: PackedInt32Array = _state.pos.duplicate()
	_state.reset_board()
	_state.history.clear()
	_deal()
	_settle(before, _now(), Motion.RESET_STAGGER)
	_break_streak()
	_clear_gags()
	elapsed = 0.0
	moves = 0
	_running = true
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	_heart_layer.queue_redraw()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	_refresh()
	moved.emit()

## One more heart (the card's video): once a floor. Morning comes back.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	var now := _now()
	_heart_used = true
	hearts = 1
	_back_index = 0
	_back_at = now
	out_of_hearts = false
	_asleep = false
	_running = true
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	_heart_layer.queue_redraw()
	_refresh()
	_say(tr("SB_HEART_BACK"), Face.Expr.HAPPY)
	_tip_timer.start()
	moved.emit()

func _leave_board() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

## Runs `what` after `delay`, unless the floor has been dealt again meanwhile.
func _after(delay: float, what: Callable) -> void:
	if not is_inside_tree():
		return
	var gen := _gen
	if delay <= 0.0:
		what.call()
		return
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

# --- the rewards ---

func _reset_rewards() -> void:
	_streak = 0
	_streak_gen += 1
	_lights = 0
	_gag_until = 0.0
	_gag_gen += 1
	_combo_n = 0
	_combo_at = -INF
	_combo_out_at = -INF
	_love = []
	_bows = []
	_flies = []
	_party_at = INF
	_stamp_at = INF
	_seal_mesh = null
	_cat_at = INF
	_cat_curled = false
	if is_instance_valid(_cat):
		_cat.queue_free()
	_cat = null
	if _life_layer != null:
		_life_layer.queue_redraw()

## The day's own number, so a day always deals the same gags and wisdom.
func _day_hash() -> int:
	if _state.size() == 0:
		return 0
	return absi(hash([_state.cols, int(_state.g.lamp), int(_state.g.bud), _state.drops().size()]))

## A move let go and judged fine: did it light a drop the light had not
## reached before? The streak grows; a move that lights fewer drops ends it.
func _after_move(before: PackedInt32Array) -> void:
	if _state.is_solved():
		return
	var had: Dictionary = Gen.trace(_state.g, before).lit
	var lit: Dictionary = _state.beam.get("lit", {})
	var fresh: Array = []
	var lost := false
	for c in _state.drops():
		if lit.has(c) and not had.has(c):
			fresh.append(c)
		elif had.has(c) and not lit.has(c):
			lost = true
	if not fresh.is_empty():
		_on_drops(fresh)
	elif lost:
		_break_streak()

## The streak grows -- a note up the pentatonic from the second, the bubble
## over the drop from the third, confetti at 4, 7 and every 5 -- and one newly
## lit drop in GAG_ODDS gets a gag.
func _on_drops(cells: Array) -> void:
	_lights += 1
	_streak += 1
	var count := _streak
	var gen := _streak_gen
	var c: int = cells[0]
	var lands := _now() + SNAP_TIME + 0.1
	if count >= 2:
		var step: int = COMBO_STEPS[mini(count - 2, COMBO_STEPS.size() - 1)]
		_after(SNAP_TIME + 0.05, func() -> void:
			if gen == _streak_gen:
				fx.cue("combo", pow(2.0, step / 12.0), COMBO_DB))
	var at := _centre(c)
	if count >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = count
		_combo_pos = at - Vector2(0.0, _cell() * 0.3)
		_combo_at = _now()
		_combo_out_at = -INF
	if _confetti_at(count) and not Motion.reduce:
		_after(SNAP_TIME, func() -> void:
			if gen == _streak_gen:
				fx.confetti(at, 22)
				fx.cue("confetti"))
	_start_gag(c, _pick_gag(), lands)
	_life_layer.queue_redraw()

static func _confetti_at(count: int) -> bool:
	return count == 4 or count == 7 or (count >= 10 and count % 5 == 0)

func _pick_gag() -> int:
	var t := _now()
	if Motion.reduce or t < _gag_until or force_gag == Gag.NONE:
		return Gag.NONE
	if force_gag >= 0:
		return force_gag
	var roll := posmod(_day_hash() + _lights * GAG_STEP, GAG_SPAN)
	if roll >= GAG_SPAN / GAG_ODDS:
		return Gag.NONE
	return roll % 3

## The streak ends: a move that darkens a drop, a wrong move, an undo, a
## hint, a reset, the hearts running out. The bubble deflates.
func _break_streak() -> void:
	_streak = 0
	_streak_gen += 1
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
	else:
		_combo_n = 0
	if _life_layer != null:
		_life_layer.queue_redraw()

func _clear_gags() -> void:
	_love = []
	_bows = []
	_flies = []
	_gag_until = 0.0
	_gag_gen += 1
	if _life_layer != null:
		_life_layer.queue_redraw()

## The gag for drop `c`, once the piece has landed: a little rainbow arcs
## over it (light through dew), love hearts float off it, or a butterfly
## flutters in, sips at it a moment and flies off.
func _start_gag(c: int, gag: int, lands: float) -> void:
	if gag == Gag.NONE:
		return
	var wait := maxf(0.0, lands - _now())
	var gg := _gag_gen
	var at := _centre(c)
	var cue := ""
	match gag:
		Gag.RAINBOW:
			_bows.append({"at": at, "t": lands})
			cue = "rainbow"
			_gag_until = lands + RAINBOW_TIME
		Gag.LOVE:
			for k in LOVE_HEARTS:
				_love.append({"at": at + Vector2(float(k - 1) * 0.28, -0.1) * _cell(),
					"t": lands + 0.12 * float(k), "phase": float(k) * 2.1})
			cue = "love"
			_gag_until = lands + 0.24 + LOVE_TIME
		Gag.BUTTERFLY:
			_flies.append({"at": at, "t": lands, "from": -1.0 if at.x > size.x * 0.5 else 1.0})
			cue = "flutter"
			_gag_until = lands + FLY_IN + FLY_SIT + FLY_OUT
	_after(wait, func() -> void:
		if gg == _gag_gen:
			fx.cue(cue))

# --- the party ---

## After the bloom: confetti twice, a rainbow over the glass, a flutter of
## butterflies off the flower, the nap cat hopping onto the frame's foot and
## curling up, a bit of sunny wisdom, and the seal when the solve earned one
## (flawless, or any Shy Dew). Under reduce motion the cat and the seal are
## simply there.
func _party() -> void:
	var now := _now()
	var lead := 0.0 if Motion.reduce else maxf(0.0, _bloom_at - now) + BLOOM_TIME * 0.5 + PARTY_AT
	_party_at = now + lead
	_after(lead + 0.8, func() -> void:
		_say(_cheer(), Face.Expr.JOY))
	_cat_at = now if Motion.reduce else _party_at + CAT_AT
	if _flawless or _state.shy():
		_stamp_at = now if Motion.reduce else _party_at + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
	if Motion.reduce:
		_life_layer.queue_redraw()
		return
	var field := _field_rect()
	_after(lead + 0.1, func() -> void:
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell() * 0.5), 30, field.size.x * 0.9)
		fx.cue("party"))
	_after(lead + 0.7, func() -> void:
		fx.confetti(field.get_center(), 24, field.size.x * 0.7))
	_after(lead + ARCH_AT, fx.cue.bind("rainbow"))
	_after(lead + FLUTTER_AT, fx.cue.bind("flutter"))
	_life_layer.queue_redraw()

func _cheer() -> String:
	return tr("SB_CHEER_%d" % posmod(_day_hash(), CHEERS))

func _field_rect() -> Rect2:
	return Rect2(_origin(), _grid_size())

func _frame_rect() -> Rect2:
	return _field_rect().grow(FRAME)

# --- the nap cat ---

func _cat_px() -> float:
	return size.x * CAT_PX

## Where she curls up: on the frame's foot, a fifth of the way along from its
## left (the seal takes the right).
func _cat_spot() -> Vector2:
	var box := _frame_rect()
	return Vector2(box.position.x + box.size.x * 0.22, box.end.y - _cat_px() * 0.3)

func _cat_start() -> Vector2:
	var box := _frame_rect()
	return Vector2(box.position.x + _cat_px() * 0.5, box.end.y - _cat_px() * 0.3)

func _cat_walk() -> float:
	return CAT_POP + CAT_HOPS * CAT_HOP_TIME

func _place_cat(t: float) -> void:
	if t < _cat_at or _cell() <= 0.0:
		return
	if not is_instance_valid(_cat):
		_cat = NapCat.new()
		_cat.name = "Cat"
		_cat.need = 0
		_cat.z_index = 3
		_cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cat.expression = Face.Expr.JOY
		add_child(_cat)
		_cat.set_idle(true)
		_cat_curled = false
	var px := _cat_px()
	if _cat.size.x != px:
		_cat.size = Vector2(px, px)
		_cat.pivot_offset = _cat.size * Vector2(0.5, 0.85)
	var e := t - _cat_at
	var spot := _cat_spot()
	var start := _cat_start()
	var at := spot
	var sc := Vector2.ONE
	if Motion.reduce or e >= CURL_AT - CAT_AT or _cat_curled:
		if not _cat_curled:
			_curl_cat(e > CURL_AT - CAT_AT + 1.0)
		else:
			_cat.position = _cat_spot() - _cat.size * 0.5
		return
	elif e < CAT_POP:
		at = start
		sc = Motion.pop_in_scale(e, CAT_POP)
	elif e < _cat_walk():
		var h := (e - CAT_POP) / CAT_HOP_TIME
		var n := int(h)
		var u := h - float(n)
		var from := start.lerp(spot, float(n) / CAT_HOPS)
		var to := start.lerp(spot, float(n + 1) / CAT_HOPS)
		at = from.lerp(to, u) - Vector2(0.0, 4.0 * u * (1.0 - u) * CAT_HOP_H * px)
		var sq := 0.1 * sin(u * PI)
		sc = Vector2(1.0 - sq, 1.0 + sq)
	elif e < _cat_walk() + CAT_SETTLE:
		var u := (e - _cat_walk()) / CAT_SETTLE
		var sq := 0.14 * sin(u * PI)
		sc = Vector2(1.0 + sq, 1.0 - sq)
	_cat.position = at - _cat.size * Vector2(0.5, 0.5)
	_cat.scale = sc

func _curl_cat(quiet: bool) -> void:
	_cat_curled = true
	_cat.expression = Face.Expr.SLEEPY
	_cat.scale = Vector2.ONE
	_cat.rotation = 0.0
	_cat.position = _cat_spot() - _cat.size * 0.5
	if not quiet:
		fx.cue("purr")

# --- the life over the floor ---

func _tick_life(now: float) -> bool:
	_love = _love.filter(func(l): return now < float(l.t) + LOVE_TIME)
	_bows = _bows.filter(func(l): return now < float(l.t) + RAINBOW_TIME)
	_flies = _flies.filter(func(f): return now < float(f.t) + FLY_IN + FLY_SIT + FLY_OUT)
	var party := not Motion.reduce and now >= _party_at - 0.05 and now < _party_at + PARTY_TIME + 0.5
	return not (_love.is_empty() and _bows.is_empty() and _flies.is_empty()) or party \
		or (_combo_n >= COMBO_FROM and (now - _combo_at < Motion.POP_IN + 0.1 or _combo_out_at > -INF)) \
		or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1)

## Each thing one cached mesh through a transform where it can be: love
## hearts and rainbows; the butterflies and the party's arch and flutter one
## mesh a frame; then the seal and the streak's bubble with their words.
func _draw_life() -> void:
	if _warm_combo:
		# The streak's numbers, rasterised out of sight on the first frame:
		# drawn cold, "x3" cost its frame 26-60 ms (Caterpillar's lesson).
		_warm_combo = false
		_life_layer.draw_string(CozyTheme.display(700), Vector2(-4000.0, -4000.0), "x0123456789",
			HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color.WHITE)
	if _cell() <= 0.0 or _state.size() == 0:
		_life_shown = []
		return
	var now := _now()
	var shown: Array = []
	var s := _cell()
	if not _love.is_empty():
		var mesh := _love_heart()
		shown.append(mesh)
		for l in _love:
			var e: float = now - float(l.t)
			if e <= 0.0:
				continue
			var u := e / LOVE_TIME
			var at: Vector2 = l.at + Vector2(sin(u * TAU + float(l.phase)) * 0.1 * s,
				-LOVE_RISE * s * (1.0 - (1.0 - u) * (1.0 - u)))
			var k := Motion.pop_in_scale(e, 0.2).x
			_life_layer.draw_mesh(mesh, null, Transform2D(sin(u * TAU) * 0.2, Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.4, 0.0, 1.0)))
	if not _bows.is_empty():
		var mesh := _bow()
		shown.append(mesh)
		for l in _bows:
			var e: float = now - float(l.t)
			if e <= 0.0:
				continue
			var u := e / RAINBOW_TIME
			# it springs up out of the drop, hangs, and fades rising
			var k := Motion.pop_in_scale(e, 0.35).x
			var at: Vector2 = l.at + Vector2(0.0, -s * (0.05 + 0.25 * u))
			_life_layer.draw_mesh(mesh, null, Transform2D(0.0, Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.35, 0.0, 1.0)))
	if not _flies.is_empty():
		var b := Face.Builder.new()
		for f in _flies:
			_fly(b, f, now)
		if not b.verts.is_empty():
			var m := b.mesh()
			shown.append(m)
			_life_layer.draw_mesh(m, null)
	if not Motion.reduce and _party_at < INF:
		var e := now - _party_at
		if e >= ARCH_AT and e < ARCH_AT + ARCH_TIME:
			_draw_arch(e - ARCH_AT, shown)
		if e >= FLUTTER_AT and e < FLUTTER_AT + FLUTTER_TIME:
			_draw_flutter(e - FLUTTER_AT, shown)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_draw_combo(now, shown)
	_life_shown = shown

func _love_heart() -> ArrayMesh:
	if _love_mesh == null:
		var b := Face.Builder.new()
		var r := maxf(12.0, _cell() * LOVE_R)
		b.polygon(_heart(Vector2.ZERO, r * 1.15, 0), Pal.FLOWER_DEEP)
		b.polygon(_heart(Vector2.ZERO, r, 0), Pal.FLOWER)
		b.ellipse(Vector2(-0.45, -0.45) * r, 0.18 * r, 0.1 * r, Color(1.0, 1.0, 1.0, 0.5))
		_love_mesh = b.mesh()
	return _love_mesh

## A little rainbow standing on its feet at the origin, RAINBOW_R cells wide,
## with a puff of cloud at each foot.
func _bow() -> ArrayMesh:
	if _bow_mesh == null:
		var b := Face.Builder.new()
		var r := _cell() * RAINBOW_R
		var band := r * 0.09
		for i in RAINBOW_BANDS.size():
			var rr := r - band * float(i)
			b.stroke(Face.Builder.arc_points(Vector2.ZERO, rr, PI, TAU), band * 1.05, Color(RAINBOW_BANDS[i], 0.9))
		for sx in [-1.0, 1.0]:
			var foot := Vector2(sx * (r - band * 2.5), 0.0)
			b.disc(foot + Vector2(-band, band * 0.3), band * 1.4, Pal.SURFACE)
			b.disc(foot + Vector2(band, band * 0.4), band * 1.2, Pal.SURFACE)
			b.disc(foot + Vector2(0.0, -band * 0.6), band * 1.3, Pal.SURFACE)
		_bow_mesh = b.mesh()
	return _bow_mesh

## A butterfly's visit: in on a curve from the card's side, a sip on the
## drop with its wings slowly opening and closing, and off up the other way.
func _fly(b: Face.Builder, f: Dictionary, now: float) -> void:
	var e := now - float(f.t)
	if e <= 0.0:
		return
	var s := _cell()
	var spot: Vector2 = f.at + Vector2(0.0, -s * 0.28)
	var side: float = f.from
	var at := spot
	var beat := 0.3 + 0.7 * absf(sin(e * 14.0))
	var lean := 0.0
	if e < FLY_IN:
		var u := e / FLY_IN
		var from := spot + Vector2(side * s * 3.0, -s * 2.2)
		at = from.lerp(spot, 1.0 - (1.0 - u) * (1.0 - u)) + Vector2(0.0, -sin(PI * u) * s * 0.5)
		lean = -side * 0.3
	elif e < FLY_IN + FLY_SIT:
		var w := e - FLY_IN
		beat = 0.25 + 0.5 * absf(sin(w * 3.0))
	else:
		var u := (e - FLY_IN - FLY_SIT) / FLY_OUT
		var to := spot + Vector2(-side * s * 2.8, -s * 3.4)
		at = spot.lerp(to, u * u) + Vector2(sin(u * 14.0) * s * 0.08, 0.0)
		lean = side * 0.3
	Cat.butterfly(b, at, s * 0.42, beat, lean)

## The party's rainbow: a wide arch over the floor, drawn out from its left
## foot to its right, then fading.
func _draw_arch(e: float, shown: Array) -> void:
	var box := _frame_rect()
	var r := box.size.x * 0.48
	var centre := Vector2(box.get_center().x, box.position.y + r * 0.55)
	var grow := clampf(e / 0.7, 0.0, 1.0)
	grow = 1.0 - (1.0 - grow) * (1.0 - grow)
	var alpha := clampf((ARCH_TIME - e) / 0.8, 0.0, 1.0) * 0.55
	var band := r * 0.045
	var b := Face.Builder.new()
	for i in RAINBOW_BANDS.size():
		var pts := Face.Builder.arc_points(centre, r - band * float(i), PI, PI + PI * grow)
		if pts.size() >= 2:
			b.stroke(pts, band * 1.05, Color(RAINBOW_BANDS[i], alpha))
	if b.verts.is_empty():
		return
	var m := b.mesh()
	shown.append(m)
	_life_layer.draw_mesh(m, null)

## The party's flutter: little butterflies rising off the open flower,
## staggered, spiralling up and out of the card. One mesh a frame.
func _draw_flutter(e: float, shown: Array) -> void:
	var s := _cell()
	var b := Face.Builder.new()
	var start := _centre(_state.g.bud) - Vector2(0.0, s * 0.2)
	for k in FLUTTERS:
		var u := (e - 0.14 * float(k)) / (FLUTTER_TIME - 0.6)
		if u <= 0.0 or u >= 1.0:
			continue
		var side := 1.0 if k % 2 == 0 else -1.0
		var spread := (float(k) - float(FLUTTERS - 1) * 0.5) * s * 0.5
		var at := start + Vector2(spread * u + side * sin(u * 5.0) * s * 0.6, -u * u * size.y * 0.8 - u * s)
		var open := clampf(u * 6.0, 0.0, 1.0)
		var beat := lerpf(0.2, 0.3 + 0.7 * absf(sin(e * 14.0 + float(k))), open)
		var alpha := clampf((1.0 - u) / 0.25, 0.0, 1.0)
		Cat.butterfly(b, at, s * 0.34 * lerpf(0.4, 1.0, open), beat, cos(u * 5.0) * 0.3 * side, alpha)
	if b.verts.is_empty():
		return
	var m := b.mesh()
	shown.append(m)
	_life_layer.draw_mesh(m, null)

func _draw_combo(now: float, shown: Array) -> void:
	if _combo_n < COMBO_FROM:
		return
	var k := 1.0
	var alpha := 1.0
	if _combo_out_at > -INF:
		var u := (now - _combo_out_at) / COMBO_DEFLATE
		if u >= 1.0 or Motion.reduce:
			_combo_n = 0
			return
		k = 1.0 - 0.75 * u * u
		alpha = 1.0 - u
	elif not Motion.reduce:
		var e := now - _combo_at
		k = Motion.pop_in_scale(e).x if _combo_popped else Motion.bump_scale(e)
	if k <= 0.01:
		return
	var font: Font = CozyTheme.display(700)
	var text := "x%d" % _combo_n
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT).x
	var box := Vector2(tw + 30.0, COMBO_FONT + 16.0)
	var tail := _combo_pos
	var centre := tail + Vector2(box.x * 0.35, -box.y * 0.95)
	centre.x = clampf(centre.x, box.x * 0.5 + 4.0, size.x - box.x * 0.5 - 4.0)
	centre.y = maxf(centre.y, box.y * 0.5 + 4.0)
	var tip := (tail - centre).round()
	var key := [text, tip]
	if _combo_shown == null or _combo_key != key:
		var b := Face.Builder.new()
		var root := Vector2(clampf(tip.x, -box.x * 0.3, box.x * 0.3), box.y * 0.3)
		b.polygon(PackedVector2Array([root + Vector2(-9.0, 0.0), tip, root + Vector2(9.0, 0.0)]), Pal.LINE)
		b.polygon(Face.Builder.round_rect(-box * 0.5 - Vector2(2.0, 2.0), box + Vector2(4.0, 4.0), box.y * 0.5 + 2.0), Pal.LINE)
		b.polygon(PackedVector2Array([root + Vector2(-6.5, -2.0), tip + (root - tip).normalized() * 3.0, root + Vector2(6.5, -2.0)]), Pal.SURFACE)
		b.polygon(Face.Builder.round_rect(-box * 0.5, box, box.y * 0.5), Pal.SURFACE)
		_combo_shown = b.mesh()
		_combo_key = key
	shown.append(_combo_shown)
	_life_layer.draw_set_transform(centre, 0.0, Vector2.ONE * k)
	_life_layer.draw_mesh(_combo_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	var ascent := font.get_ascent(COMBO_FONT)
	var descent := font.get_descent(COMBO_FONT)
	_life_layer.draw_string(font, Vector2(-tw * 0.5, (ascent - descent) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color(Pal.SUN_DEEP, alpha))
	_life_layer.draw_set_transform(Vector2.ZERO)

## The seal on the frame's lower right corner, dropping in and settling, its
## words over it: Flawless; on Shy Dew "Insane" over Flawless or Shy Dew, on
## the night seal.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := size.x * STAMP_R * 0.75
	var insane: bool = _state.shy()
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var corner := _frame_rect().end
	var centre := corner - Vector2(rad * 0.85, rad * 0.72)
	centre.x = minf(centre.x, size.x - rad * 1.08)
	centre.y = minf(centre.y, size.y - rad * 1.02)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless else tr("SB_SHY_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
