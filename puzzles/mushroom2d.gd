extends "res://core/puzzle_base.gd"

## Mushroom Patch as a flat board: a meadow of covered cells on the host's
## parchment card, with some of them turned over to show how many mushrooms
## grow in the eight cells touching them. Plant a mushroom where you have
## proved one is, lay a pebble where you have proved one is not, and the
## patch is done the moment the last mushroom is planted. The rules live in
## puzzles/mushroom_state.gd, which this only draws.
##
## **The count wash is this board's signature.** A number is written in ink
## while its neighbourhood is short of mushrooms, turns green the moment
## exactly that many stand around it, and turns rose if one too many is
## planted. The wash *holds* -- it is a state and not a flash that fades --
## and the numeral bumps as it changes. It is honest, and that is worth
## saying plainly because it looks like a tell: the wash is computed from
## what the player already holds, the number printed on the cell and the
## mushrooms they themselves planted, and never from the answer
## (`state.standing()` reads `marks`, not `mushrooms`). A green number means
## *you have put three here*, not *your three are right*; a board can be
## covered in green and still be wrong, and finding that out is what Check
## is for. This does not break Code Break's "a count and never a map" rule
## for the same reason.
##
## A given of nought draws **no numeral** and takes **no green wash**: it is
## turned over and bare, which is the whole of what it has to say, and a
## field of green nothings would drown the wash that matters. It still
## blushes rose when a mushroom is planted beside it, because that is news.
##
## How it is drawn. Only the mushrooms are nodes (ui/faces/mushroom_face.gd),
## each in a slot of its own so the layout and the motion never fight (rule 2
## of docs/art/flat-motion.md), made the first time a cell is planted and kept
## afterwards. Everything else is two meshes rebuilt only while something
## moves: the floor (the cell backs, each shaded by its mark, sunk under the
## finger and washed by its standing), built about the field's centre so the
## entrance pop is one transform; and the ground (the blushes, the soft discs
## under the mushrooms and every pebble) over it. The numerals are drawn text,
## one draw_set_transform a cell, so they pop, bump and take the wash's ink
## off Motion's readers -- Nonogram's clue numbers are the precedent. Every
## drawn moment reads the flat boards' vocabulary as curves off core/motion.gd
## (rule 8); nothing here needed a new reader. Every move -- a tap, a sweep,
## an undo, a hint, a reset -- goes through one _settle that diffs a snapshot
## of the field against the state and hands each changed cell its moment,
## with one Callable saying when: a sweep's path, Reset's far corner, a
## plant's own instant. **_settle is the wash's only entry point.**
## Spec: docs/superpowers/specs/2026-09-20-mushroom-patch-flat-design.md.
## Concept page: docs/brainstorm/concepts.html#mushroom.
##
## **The polish of 2026-09-30** (spec 2026-09-30-mushroom-polish-design.md).
## Hard and Insane can be failed: every mushroom is judged as she lands, and a
## wrong one worries, costs a heart, wilts back into the soil and leaves a
## pebble there for good (`state.shown`). Insane is **Fairy Rings**: some
## numbers sit in a ring of little violet caps and count the sixteen cells two
## steps out instead of the eight touching. Pressing any number lights the
## cells it counts. A plant builds a streak (a note up the pentatonic, the x3
## bubble, confetti), now and then plays a gag (hearts, a twirl, a sneeze), a
## number whose every cell is marked and whose count holds opens a flower,
## and the solve throws a party: a meadow, a dance, confetti, a silly bit of
## mushroom wisdom and the seal.

const State = preload("res://puzzles/mushroom_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const MushroomFace = preload("res://ui/faces/mushroom_face.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Seal = preload("res://ui/flat/seal.gd")
const RunMesh = preload("res://ui/flat/run_mesh.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"

# --- the patch ---
## The card's inset round the field.
const PAD := 34.0
## The tally strip over the field, inside the card. It comes out of the
## field's height, which is why card_height subtracts it.
const TALLY := 72.0
## A cell's back: the gap it leaves round itself, its corner, and the lip of
## rim left showing under its face -- the mock's own numbers.
const CELL_INSET := 0.035
const CELL_RADIUS := 0.18
const FACE_DROP := 0.015
const FACE_SHORT := 0.05
## The pieces, each as a fraction of a cell: the mushroom's R (the face's
## own radius, which MushroomFace takes as RATIO of the seat it is given),
## the pebble's R and its body against that R, and the numeral's font.
const MUSHROOM := 0.33
const PEBBLE := 0.26
const PEBBLE_BODY := 0.82
const NUM_SIZE := 0.52
## The soft disc under a planted mushroom, in cells.
const SHADOW_AT := Vector2(0.0, 0.3)
const SHADOW_RX := 0.3
const SHADOW_RY := 0.09
const SHADOW_ALPHA := 0.22
## A plant's and a hint's ring, in cells.
const RING_R := 0.45
## How far a refused cell shivers, in cells. The family's SHIVER_PX is two
## pixels on a 147 px tile; a cell here is 116 to 155, so it is read as a
## fraction of the cell the way Queens' and Nonogram's are.
const SHIVER := 0.03
## The family's rose itself rather than the pale tile tint, at less than
## half: a blush on the meadow's yellow-green has to be the colour and not
## the tint to read at all.
const BLUSH_ALPHA := 0.42

# --- this board's own motion: the count wash ---
## How long a number's wash takes to settle when its standing changes: the
## old colour crosses to the new over this, so a number that goes green
## while a wave of mushrooms is still arriving does not snap.
const WASH_TIME := 0.35
## How deep the green sits on the cell.
const WASH_LEVEL := 0.30
## And the rose, deeper, because BAD is darker than LEAF and reads lighter
## on the meadow at the same level.
const WASH_OVER := 0.34
## How long a refused pinned mushroom strains before her face settles.
const STRAIN_TIME := 0.6
## The win screen waits for the solve wave to hop every mushroom.
const WIN_WAIT := 1.6

# --- the second polish (2026-09-25; the spec's section 16) ---
## A covered cell is a sod of turf standing on the card and a turned one is a
## bed sunk into it, so what is still to find and what is known read as
## relief and not only as colour. The turf's face is toned off its cell's
## hash within TONE, lit BEVEL of a cell round its crown TURF_LIT toward
## SURFACE, and stands on a foot TURF_FOOT of the way to TURF.
const TONE := 0.03
const BEVEL := 0.055
const TURF_LIT := 0.34
const TURF_FOOT := 0.6
## A bed's wall is its floor BED_WALL toward TEXT and shows BED_LIP of a cell
## along the top, where the card's edge shades the hole.
const BED_WALL := 0.16
const BED_LIP := 0.06
## One sod in TUFT_SHARE carries a small tuft of three blades TUFT_H of a
## cell tall, in TURF at TUFT_ALPHA, so the meadow reads as grass.
const TUFT_SHARE := 0.42
const TUFT_H := 0.17
const TUFT_ALPHA := 0.75
## The sod lifts off a cell as a mark lands in it, shrinking over SOD_TIME
## and rising SOD_LIFT of a cell, and settles back with the pop when the mark
## is taken away.
const SOD_TIME := 0.18
const SOD_LIFT := 0.12
## The sod settles back this long after the piece on its cell starts to go.
const SOD_BACK_LAG := 0.12
## A planted mushroom sprouts: after SPROUT_LAG, as her sod lifts, a closed
## button BUTTON_W wide pushes up to BUTTON_H of her height over SPROUT_PUSH,
## then her cap opens CAP_FLARE past its width over SPROUT_OPEN and settles
## over SPROUT_SETTLE. Soil puffs at her foot, SOIL_AT of a cell below the
## centre, as she breaks through.
const SPROUT_LAG := 0.05
const SPROUT_PUSH := 0.24
const SPROUT_OPEN := 0.2
const SPROUT_SETTLE := 0.2
const BUTTON_W := 0.42
const BUTTON_H := 1.08
const CAP_FLARE := 0.14
const SOIL_AT := 0.3
## A mushroom pulled up rises this much of a cell as she shrinks out.
const PLUCK := 0.2
## A number that has just come right glints: its bed shines SHINE toward
## SURFACE over GLINT_TIME, GLINT_LAG after its wash starts crossing.
const GLINT_TIME := 0.42
const GLINT_LAG := 0.12
const SHINE := 0.5
## On the win a light crosses the patch along the diagonal: when it sets off
## and its step a diagonal.
const WIN_GLINT_AT := 0.3
const WIN_GLINT_STEP := 0.035
## Every SWAY_EVERY seconds one planted mushroom sways about her foot.
const SWAY_EVERY := 3.4
const SWAY_ANGLE := 0.06
const SWAY_TIME := 0.9
## The tally's paper pill: its padding round the run, washed LEAF_TILE once
## every mushroom is planted and BAD_TILE past that. It bumps as it recounts.
const PILL_PAD := Vector2(22.0, 10.0)
const PILL_EDGE := 4.0

## A board's own hints, per band (State.HINTS_BY_BAND).
const HINTS := 3

# --- the polish (2026-09-30) ---
## Pressing a number lights the cells it counts: in and out over these, at
## this level, in leaf for a plain number and violet for a fairy ring.
const REACH_IN := 0.12
const REACH_OUT := 0.3
const REACH_ALPHA := 0.62
## A fairy ring: RING_CAPS little violet caps RING_CAP of a cell wide on a
## circle RING_AT of a cell round the numeral, which is lettered RING_NUM of
## the plain size. They grow in one by one RING_STEP apart after the patch's
## entrance (RING_LEAD later), a ring RING_WAVE after its diagonal neighbour.
const RING_CAPS := 10
const RING_CAP := 0.06
const RING_AT := 0.37
const RING_NUM := 0.8
const RING_LEAD := 0.25
const RING_STEP := 0.035
const RING_WAVE := 0.05
const RING_GLOW := 0.6
## The hearts' strip over the tally (Queens', One Line's).
const HEART_ROW := 64.0
const HEART_R := 21.0
const HEART_GAP := 12.0
const HEART_PILL_PAD := Vector2(18.0, 8.0)
const HEART_PILL_RIM := 2.0
const SPLIT_TIME := 0.7
const SPLIT_FALL := 56.0
const SPLIT_SPREAD := 14.0
const SPLIT_TURN := 0.7
const HEART_BACK_TIME := 0.3
## A wrong mushroom stands worried this long after she lands, then wilts:
## droops WILT_DROOP over the first third of WILT_TIME and sinks into the
## soil over the rest, and her pebble drops in as she goes.
const EJECT_AFTER := 0.75
const WILT_TIME := 0.6
const WILT_DROOP := 0.45
## A pebble a heart showed stands on a rose halo this much of a cell across.
const SHOWN_HALO := 0.4
## A pebble drops this much of a cell as it pops in.
const PEBBLE_DROP := 0.14
const DUSK := Color(0.74, 0.76, 0.92)
const DUSK_TIME := 0.8
const CARD_AFTER := 1.1
const CARD_AFTER_STILL := 0.3
## The streak: a plant that holds (the answer's on Hard and Insane, one that
## sends no number over on Easy and Medium) plucks `combo` up the pentatonic
## from the second; the bubble from COMBO_FROM; confetti at COMBO_CONFETTI.
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0
const COMBO_CONFETTI := [5, 10]
const COMBO_DEFLATE := 0.25
const COMBO_FONT := 44
## Gags: GAGS of every GAG_ODDS plants, by the cell's hash.
const GAG_ODDS := 5
const GAGS := 3
const LOVE_HEARTS := 4
const LOVE_TIME := 1.3
const LOVE_RISE := 0.7
const LOVE_R := 0.14
const TWIRL_TIME := 0.55
const TWIRL_HOP := 0.16
const SNEEZE_WIND := 0.22
const SNEEZE_BLOW := 0.12
const SNEEZE_BACK := 0.3
## A finished number's flower, in the bed's upper right corner.
const BLOOM_R := 0.12
const BLOOM_AT := Vector2(0.3, -0.3)
const BLOOM_PETALS := 5
const BLOOM_TIME := 0.45
const BLOOM_FOLD := 0.2
## The party, PARTY_AT after the solve: the meadow along the diagonal
## (MEADOW_STEP a diagonal), the dance, confetti twice, the seal STAMP_AT
## later. win_delay() waits PARTY_EXTRA more for it.
const PARTY_AT := 1.2
const PARTY_EXTRA := 1.6
const MEADOW_STEP := 0.04
const MEADOW_R := 0.2
const DANCE_BEATS := 4
const DANCE_BEAT := 0.22
const DANCE_TILT := 0.2
const CHEERS := 12
const STAMP_AT := 0.9
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.16
const STAMP_TILT := -0.22
## How long a teaching line stands before the next, the family's own cycle.
const TIP_CYCLE := 10.0
## Translation keys (locale/ui.csv), read through tr() when said.
const TIPS := ["MP_TIP_COUNT", "MP_TIP_PLANT", "MP_TIP_GREEN"]
## The tally strip and the sprout count in words, as the mock does: the
## strip is a label and not a score, and a numeral there would read as a
## second clue beside the ones on the field.
## Keys MP_NUM_0 to MP_NUM_14 (locale/ui.csv): "no", "one" ... "fourteen".
## A word here always stands alone or counts mushrooms; a sentence that needs
## "one" in front of a noun, or a feminine two, has a key of its own.
const WORDS := 15

## The tally strip's own geometry, the mock's: the little mushroom's seat and
## where it and the line sit in the run, and the line's font.
const TALLY_GLYPH := 53.0
const TALLY_GLYPH_X := 26.0
const TALLY_TEXT_X := 70.0
const TALLY_SIZE := 34

## The floor's shapes (`_floor_shape`), and its one run per cell.
const SHAPE_BED := 0
const SHAPE_TURF := 1
const SHAPE_TUFT := 1000   # + the cell's index: each sod's own tuft
const SHAPE_RING := 100000 # + the cell's index: each fairy ring, grown
const PART_CELL := 0
## The ground's shapes (`_ground_shape`) and its runs, in paint order.
const G_SQUARE := 0
const G_DISC := 1
const G_PEBBLE := 2
const G_PEBBLE_SHADOW := 3
const G_HALO := 4
const G_FLOWER := 5
const PART_PILL := 0
const PART_BLUSH := 1
const PART_REACH := 2
const PART_FLOWER := 3
const PART_DISC := 4
const PART_PEBBLE := 5

## The out-of-hearts card's Back: the host takes the board away.
signal leave

var state = State.new()
## Which chip the tray has armed: State.FOUND or State.CLEAR. The tray only
## asks; this owns it, and tile_tray.gd reads it back.
var brush: int = State.FOUND

## The field's size, the name the win harness reads.
var n: int:
	get: return state.n

var fx: Node2D
var _cell := 0.0
var _grid := Vector2.ZERO
var _tally_y := 0.0
var _caps: Dictionary = {}     # Vector2i -> MushroomFace, kept once made
var _slots: Dictionary = {}    # face -> its slot
var _pos_tw: Dictionary = {}   # face -> the hop, the shiver, the drop
var _look_tw: Dictionary = {}  # face -> the pop, the press, the wobble
var _tally_face: MushroomFace
var _gen := 0
var _card := Rect2()
var _hearts_y := 0.0

## The polish's state: hearts, the judged mushroom, the streak, the flowers,
## the party and the life over the patch.
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
var _lost_ever := false
var _asleep := false
var _ejecting := false
var _heart_card: Control
var _split_index := -1
var _split_at := -INF
var _back_index := -1
var _back_at := -INF
var _heart_layer: Control
var _hearts_shown: ArrayMesh
var _dusk_tw: Tween
var _bad: Dictionary = {}       # cell -> true: a wrong mushroom waiting to wilt
var _flawless := false
var _streak := 0
var _combo_n := 0
var _combo_cell := Vector2i.ZERO
var _combo_at := -INF
var _combo_popped := false
var _combo_out_at := -INF
var _combo_layer: Control
var _combo_shown: ArrayMesh
var _bloom: Dictionary = {}     # given -> {"at", "open"}: its flower opening or folding
var _meadow_at := INF
var _rings_at := INF
var _glow_at := INF
var _reach: Dictionary = {}     # {"cell", "down", "up"}: a number held, its cells lit
var _life_layer: Control
var _life_shown: Array = []
var _life_alive := false
var _love: Array = []
var _love_mesh: ArrayMesh
var _stamp_at := INF
var _seal_mesh: ArrayMesh

## Every drawn moment, each the second it begins, read off Motion's curve
## readers in _build_floor, _build_ground and _draw_numerals.
var _pebble_in: Dictionary = {}  # cell -> at: its pebble pops in then
var _pebble_out: Array = []      # [{"cell", "at"}]: pebbles shrinking out
var _wash: Dictionary = {}       # cell -> the wash it is crossing from
var _bump: Dictionary = {}       # cell -> at: its numeral was recounted
var _blush: Dictionary = {}      # cell -> at: Check pointed at it, or a refusal
var _shiver: Dictionary = {}     # cell -> at: a refused press
var _wobble: Dictionary = {}     # cell -> at: Check pointed at a drawn pebble
var _sunk: Dictionary = {}       # cell -> {"down", "up"}: the finger has it
var _sod: Dictionary = {}        # cell -> {"at", "back"}: its turf lifting off or settling back
var _glint: Dictionary = {}      # cell -> at: a light crosses its bed then
var _tally_at := -100.0          # the tally recounted then
var _sway_timer: Timer
var _floor: ArrayMesh
## The floor is put together from shapes made once (the board checkup,
## 2026-10-02): a bed, a sod, each sod's tuft and each fairy ring's caps,
## made at the cell `_ref` and copied natively into a run of vertices per
## cell, painted by fills. A floor of 28k vertices built in script was 12 ms a
## frame on a full Insane patch while anything on it moved.
var _frm := RunMesh.new(_floor_shape)
var _ref := 0.0
## The ground the same way: blushes, the reach's glow, flowers, the soft discs
## under the mushrooms and every pebble, a run per cell for each (a full
## Insane patch's ground was 6-12 ms in script a frame).
var _grm := RunMesh.new(_ground_shape)
var _ground_shown := -1   # how many shown cells the ground's runs were laid for
var _turf_cols: Array = []   # per cell index: [foot, rim, face], toned off its hash
## The mushrooms at rest, baked into one mesh (`_bake_caps`); a flattened copy
## of each face mesh it copies, thrown away with the layout.
var _cap_bake: CapBake
var _cap_key: Array = []
var _flat_cache: Dictionary = {}
var _ground: ArrayMesh
var _ground_dirty := true
## The meshes the last _draw handed the canvas item. A canvas command holds a
## mesh by RID and not by reference; dropping the only reference to a mesh
## still on the item's command list leaves the renderer drawing a freed RID.
var _shown: Array = []

# --- the gesture ---
var _press_cell := Vector2i(-1, -1)
var _pressed: Control       # the mushroom under the finger, if one
var _dragged := false
var _lay := true            # a sweep lays pebbles, or rubs the player's out
var _swept: Dictionary = {}
var _pending: Array[Vector2i] = []
var _last_paint := Vector2i(-1, -1)

## Whether a wave was running last frame, so one settled frame follows it.
var _tail := false

var _opened := -1.0e9
var _solved_at := -1.0
var _anim_until := 0.0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "mushroom"
func title() -> String: return "Mushroom Patch"

func rules() -> String:
	var out := tr("MP_RULES")
	if not state.rings.is_empty():
		out += "\n\n" + tr("MP_RULES_RINGS")
	if max_hearts > 0:
		out += "\n\n" + tr("MP_RULES_HEARTS") % _word(max_hearts)
	else:
		out += " " + tr("MP_RULES_SAFE")
	return out

## The lines the sprout cycles: Fairy Rings leads with the rings' two, a
## judged patch with the hearts'.
func _tips() -> Array:
	if not state.rings.is_empty():
		return ["MP_TIP_RINGS", "MP_TIP_RINGS_2", "MP_TIP_HEARTS"] + TIPS
	if max_hearts > 0:
		return ["MP_TIP_HEARTS"] + TIPS
	return TIPS

## The tutorial (the board checkup, 2026-10-02): one lesson a page, each
## played by a real, quietened board on a 5 by 5 patch
## (ui/hud/mushroom_tutorial_diagram.gd), the pages this band needs: Fairy
## Rings on Insane, the hearts on a judged band, the bulb while the band has
## hints.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/mushroom_tutorial_diagram.gd")
	var hints: int = State.HINTS_BY_BAND[clampi(state.band, 0, 3)]
	var steps := [
		[Diagram.Lesson.COUNT, "HTP_MP_COUNT", tr("HTP_MP_COUNT_BODY")],
		[Diagram.Lesson.PEBBLE, "HTP_MP_PEBBLE", tr("HTP_MP_PEBBLE_BODY")]]
	if not state.rings.is_empty():
		steps.append([Diagram.Lesson.RINGS, "MP_RINGS_SEAL", tr("MP_RULES_RINGS")])
	if max_hearts > 0:
		steps.append([Diagram.Lesson.HEARTS, "HTP_TN_HEARTS",
			tr("HTP_MP_HEARTS_BODY_ONE") if max_hearts == 1 else tr("HTP_MP_HEARTS_BODY_N") % max_hearts])
	steps.append([Diagram.Lesson.UNDO, "HTP_WT_UNDO",
		tr("HTP_MP_UNDO_BODY_JUDGED") if state.judged() else tr("HTP_MP_UNDO_BODY")])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_MP_HINT_BODY_ONE") if hints == 1 else tr("HTP_MP_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.hearts = maxi(1, max_hearts)
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

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
	_sway_timer = Timer.new()
	_sway_timer.wait_time = SWAY_EVERY
	_sway_timer.timeout.connect(_sway)
	add_child(_sway_timer)
	_cap_bake = CapBake.new()
	_cap_bake.name = "CapBake"
	_cap_bake.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap_bake.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cap_bake)
	_life_layer = _layer("Life", 3, _draw_life)
	_heart_layer = _layer("Hearts", 1, _draw_hearts)
	_combo_layer = _layer("Combo", 4, _draw_combo)
	resized.connect(_layout)
	solved.connect(_on_solved)

## A full-rect layer over the patch, drawn by `draw` (One Line's).
func _layer(nm: String, z: int, draw: Callable) -> Control:
	var layer := Control.new()
	layer.name = nm
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = z
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.draw.connect(draw)
	add_child(layer)
	return layer

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_stop_all()
	state.setup(rng, difficulty, bank_step)
	max_hearts = State.HEARTS[state.band]
	_heart_used = false
	_lost_ever = false
	_deal()
	_frm.reset()
	_grm.reset()
	_ref = 0.0
	brush = State.FOUND
	_pebble_in = {}
	_pebble_out = []
	_wash = {}
	_bump = {}
	_blush = {}
	_shiver = {}
	_wobble = {}
	_sunk = {}
	_sod = {}
	_glint = {}
	_tally_at = -100.0
	_clear_gesture()
	_solved_at = -1.0
	_build_pieces()
	_layout()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	_sway_timer.start()
	_enter()

## The patch as it is dealt, and as Try again deals it back: every heart, the
## day's light, nothing judged, blooming or partying.
func _deal() -> void:
	hearts = max_hearts
	out_of_hearts = false
	_asleep = false
	_ejecting = false
	_split_index = -1
	_back_index = -1
	_bad = {}
	_flawless = false
	_streak = 0
	_combo_n = 0
	_combo_out_at = -INF
	_love = []
	_bloom = {}
	_meadow_at = INF
	_rings_at = INF
	_glow_at = INF
	_stamp_at = INF
	_seal_mesh = null
	_reach = {}
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	for layer: Control in [_heart_layer, _life_layer, _combo_layer]:
		if layer != null:
			layer.queue_redraw()

# --- the cast ---

## Only the mushrooms are nodes; the field, the numerals and the pebbles are
## drawn. The tally strip's own little mushroom is the one that is always
## here, so it is made once and kept with the board.
func _build_pieces() -> void:
	for cell in _caps:
		var face = _caps[cell]
		if _slots.has(face):
			_slots[face].queue_free()
			_slots.erase(face)
	_caps = {}
	if _tally_face == null:
		_tally_face = MushroomFace.new()
		_stand(_tally_face, "TallyMushroom")
	_tally_face.visible = state.n > 0

## Puts `face` in a slot of its own under the board. The slot takes the
## layout; the face inside it takes the motion.
func _stand(face: Control, node_name: String) -> void:
	var slot := Control.new()
	slot.name = node_name
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	face.name = "mushroom"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(face)
	_slots[face] = slot

## The mushroom on `cell`, made the first time one is planted there and kept
## afterwards: a cell tapped twice would otherwise build and free a node with
## a mesh cache behind it on every tap.
func _cap_node(cell: Vector2i) -> MushroomFace:
	if _caps.has(cell):
		return _caps[cell]
	var face := MushroomFace.new()
	face.visible = false
	face.scale = Vector2.ZERO
	_stand(face, "mushroom_%d_%d" % [cell.x, cell.y])
	_caps[cell] = face
	if _cell > 0.0:
		_seat(face, cell_centre(cell), _seat_px())
	return face

## The seat a mushroom of MUSHROOM of a cell needs: the face takes its own
## radius as MushroomFace.RATIO of the box it is given.
func _seat_px() -> float:
	return _cell * MUSHROOM / MushroomFace.RATIO

## Every planted mushroom takes the look her state asks for; a face is
## written only when her look changes, since a written face redraws.
func _refresh_faces() -> void:
	for cell in _caps:
		var face: MushroomFace = _caps[cell]
		if int(state.marks.get(cell, State.BLANK)) != State.FOUND:
			continue
		var pinned: bool = state.pinned.has(cell)
		if face.sprig != pinned:
			face.sprig = pinned
		# The win writes JOY on each mushroom as the wave reaches her, and a
		# refusal's strain settles on its own clock.
		if _solved_at >= 0.0 or face.expression == Face.Expr.STRAIN:
			continue
		if _asleep:
			_set_expr(face, Face.Expr.SLEEPY)
		elif _bad.has(cell):
			_set_expr(face, Face.Expr.WORRIED)
		else:
			_set_expr(face, Face.Expr.HAPPY)

func _set_expr(face: Face, expr: int) -> void:
	if face.expression != expr:
		face.expression = expr

# --- layout ---

## The field is the largest grid the card holds under the tally strip, and
## the card is cut to the two and centred in the slot (card_height,
## card_centred): the grid is square while its space is tall, so the cell is
## capped by the width at every step and there is slack however the card is
## cut -- about 22 px of it, which moves the card by eleven.
func _layout() -> void:
	if state.n <= 0:
		return
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	# The floor's shapes are drawn scaled after a smaller relayout (the win
	# card's), and made again for a bigger one.
	if _cell > _ref + 0.01:
		_frm.reset()
		_grm.reset()
		_ref = _cell
	var field: Vector2 = Vector2.ONE * (_cell * state.n)
	var row := _heart_row()
	var tall := minf(size.y, field.y + 2.0 * _pad() + _tally_h() + row)
	var top := (size.y - tall) * 0.5
	_card = Rect2(0.0, top, size.x, tall)
	_hearts_y = top + _pad() * 0.6 + row * 0.5
	_grid = Vector2(size.x * 0.5 - field.x * 0.5, top + _pad() + row + _tally_h())
	_tally_y = top + _pad() + row + _tally_h() * 0.5
	for cell in _caps:
		_seat(_caps[cell], cell_centre(cell), _seat_px())
	_layout_tally()
	_flat_cache = {}
	_cap_key = []
	_love_mesh = null
	_seal_mesh = null
	_refresh_faces()
	_redraw()
	for layer: Control in [_heart_layer, _life_layer, _combo_layer]:
		if layer != null:
			layer.queue_redraw()

## The air round the field inside the card, and the tally strip's height:
## hooks a tutorial's patch lays out without (the board's are PAD and TALLY).
func _pad() -> float:
	return PAD

func _tally_h() -> float:
	return TALLY

## The strip the hearts take over the tally, on a patch that has them.
func _heart_row() -> float:
	return HEART_ROW if max_hearts > 0 else 0.0

## Seats `face` `px` square about `centre`: her slot takes the place, and her
## own place inside it is left to the motion. She turns and scales about the
## foot of her stem, not her middle (set after the size, which Face resets it
## on): the pop grows her up out of the soil, the press squashes her into it
## and a sway or a wobble rocks her on her root.
func _seat(face: Control, centre: Vector2, px: float) -> void:
	var seat := Vector2.ONE * px
	var slot: Control = _slots[face]
	slot.size = seat
	slot.position = centre - seat * 0.5
	face.size = seat
	face.pivot_offset = seat * 0.5 + Vector2(0.0, px * MushroomFace.RATIO * MushroomFace.FOOT)

## The cell a slot of `available` height holds, capped by the width. The
## tally strip comes out of the height before the field is measured.
func _cell_for(available: float) -> float:
	if state.n <= 0:
		return 0.0
	return minf((size.x - 2.0 * _pad()) / state.n,
		(available - 2.0 * _pad() - _tally_h() - _heart_row()) / state.n)

func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * state.n + 2.0 * _pad() + _tally_h() + _heart_row())

func card_centred() -> bool:
	return true

## Control-local point over the centre of `cell`. The win harness taps these.
func cell_centre(cell: Vector2i) -> Vector2:
	return _grid + (Vector2(cell) + Vector2.ONE * 0.5) * _cell

## The island boards' name for the same point, in (row, column) order, which
## is what every other flat board answers to.
func cell_to_local(r: int, c: int) -> Vector2:
	return cell_centre(Vector2i(c, r))

func _cell_at(local: Vector2) -> Vector2i:
	if _cell <= 0.0:
		return Vector2i(-1, -1)
	var p := (local - _grid) / _cell
	var cell := Vector2i(int(floor(p.x)), int(floor(p.y)))
	return cell if _in_field(cell) else Vector2i(-1, -1)

func _in_field(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < state.n and cell.y < state.n

## The field's centre in board pixels: what the floor pops about.
func _field_centre() -> Vector2:
	return _grid + Vector2.ONE * (_cell * state.n * 0.5)

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	_bake_caps()
	var now := _now()
	if _cell > 0.0 and _heart_layer != null:
		# The pill pops in with the tally, then stands until a heart moves.
		if (_split_index >= 0 and now - _split_at < SPLIT_TIME + 0.1) \
				or (_back_index >= 0 and now - _back_at < HEART_BACK_TIME + 0.1) \
				or now - _opened < Motion.ENTER_DELAY + Motion.POP_IN + 0.1:
			_heart_layer.queue_redraw()
		if _combo_n >= COMBO_FROM and (now - _combo_at < Motion.POP_IN + 0.1 or _combo_out_at > -INF):
			_combo_layer.queue_redraw()
		# One more redraw once the life goes quiet, so its last frame is not
		# left standing.
		var alive := _tick_life(now)
		if alive or _life_alive:
			_life_layer.queue_redraw()
		_life_alive = alive
	if now < _anim_until:
		_tail = true
		queue_redraw()
	elif _tail:
		# One last **rebuilt** frame once everything has landed, and the
		# rebuild is the whole of it: _draw only rebuilds the cached meshes
		# while `_ground_dirty` or `now < _anim_until`, so a plain
		# queue_redraw() here would re-issue the stale floor and leave a
		# half-faded field under numerals that had recomputed -- worse than
		# the freeze it is here to prevent. _redraw() sets the flag.
		#
		# It is needed because this board bakes the entrance's per-cell fade
		# into the floor mesh's vertex colours (_build_floor writes
		# _entered(cell, now) into every rim and face), which it has to: the
		# fade runs as a diagonal wave, a cell at a time. Queens has no wave
		# -- its whole floor fades together, as one modulate on the draw call
		# (queens2d.gd:355-358), recomputed every frame -- so it cannot freeze
		# mid-fade and needs nothing like this. Measured on this Mac on
		# 2026-09-20: the first, cold run of tests/_shot_anim.gd on this board
		# stalled one frame clean over the end of the wave and kept a field
		# frozen at four fifths for the whole run.
		_tail = false
		_redraw()

## Keeps the field redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Something on the field changed: rebuild it on the next draw.
func _redraw() -> void:
	_ground_dirty = true
	queue_redraw()

# --- the drawing ---

## The field pops in wide about its centre once the chrome has slid in
## (rule 7), as one draw transform over the floor mesh, with the cells fading
## in in a diagonal wave under it; the numerals ride the same transform, and
## the ground is drawn over it as it is, the way Queens draws its pebbles.
func _draw() -> void:
	if _cell <= 0.0 or state.n <= 0:
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
	var since := now - _opened - Motion.ENTER_DELAY
	if since < Motion.ENTER_POP + Motion.stagger(2 * state.n - 2, Motion.ENTER_STAGGER):
		busy = true
	var grown := Motion.wide_pop_scale(since)
	if _floor != null:
		draw_mesh(_floor, null,
			Transform2D(0.0, Vector2(grown, grown), 0.0, _field_centre()))
		shown.append(_floor)
	_draw_numerals(now, grown)
	if _ground != null:
		draw_mesh(_ground, null)
		shown.append(_ground)
	_draw_tally(now)
	_shown = shown
	if busy:
		_anim_until = maxf(_anim_until, now + 0.1)

## The second cell `cell` begins to fade in, and how far it has got: the
## field arrives in a diagonal wave after the family's delay.
func _enter_at(cell: Vector2i) -> float:
	return _opened + Motion.ENTER_DELAY + Motion.stagger(cell.x + cell.y, Motion.ENTER_STAGGER)

func _entered(cell: Vector2i, now: float) -> float:
	if Motion.reduce:
		return 1.0
	return clampf((now - _enter_at(cell)) / Motion.ENTER_POP, 0.0, 1.0)

## The field, built about its centre: one back per cell, in the colour its
## mark asks for, sunk under the finger, shivering when refused and washed by
## its standing. Each back is a faint rim with its face laid on top a little
## lower and a little shorter, so every cell wears the family's bottom lip.
func _build_floor(now: float) -> ArrayMesh:
	if not _frm.laid():
		_lay_floor()
	_frm.begin()
	var q := _cell / _ref
	var origin: Vector2 = -Vector2.ONE * (_cell * state.n * 0.5)
	var gone: Array = []
	var settled: Array = []
	var lifted: Array = []
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			var seen := _entered(cell, now)
			if seen <= 0.0:
				continue
			var ix: int = y * state.n + x
			var given: bool = state.given.has(cell)
			var mark: int = int(state.marks.get(cell, State.BLANK))
			var base: Color = Pal.SURFACE if given else Pal.SOCKET_OUT
			if not given and mark == State.FOUND:
				base = Pal.MUSHROOM_TILE
			if given:
				var w := _wash_of(cell, now)
				if not bool(w.moving):
					# It has finished crossing: the record it was crossing
					# from says nothing any more, and _worn without it draws
					# the same colour.
					settled.append(cell)
				base = base.lerp(w.from_colour, float(w.from_level)) \
					.lerp(w.colour, float(w.level))
			var sink := 1.0
			if _sunk.has(cell):
				var pr: Dictionary = _sunk[cell]
				var released := -1.0 if now < float(pr.up) else now - float(pr.up)
				if released >= Motion.RELEASE_TIME:
					gone.append(cell)
				else:
					sink = Motion.press_scale(now - float(pr.down), released)
			var at := origin + (Vector2(cell) + Vector2.ONE * 0.5) * _cell
			at.x += Motion.shiver_offset(now - float(_shiver.get(cell, -100.0)), _cell * SHIVER)
			var shine := _shine(cell, now)
			var sod := _sod_pose(cell, now, not given and mark == State.BLANK, lifted)
			_frm.open(PART_CELL, ix)
			# The bed shows wherever the sod is not wholly down: under a mark,
			# and under a sod on its way off or back.
			if given or mark != State.BLANK or sod.x < 1.0 or sod.z < 1.0:
				var floor_col := base.lerp(Pal.SURFACE, shine * SHINE)
				_frm.put(SHAPE_BED, [Color(floor_col.lerp(Pal.TEXT, BED_WALL), seen), Color(floor_col, seen)],
					Transform2D(0.0, Vector2.ONE * (q * sink), 0.0, at))
			if sod.z > 0.0:
				var cols: Array = _turf_cols[ix]
				var rim: Color = cols[1]
				var face: Color = cols[2]
				if shine > 0.0:
					face = face.lerp(Pal.SURFACE, shine * SHINE)
					rim = rim.lerp(Pal.SURFACE, shine * SHINE)
				var xf := Transform2D(0.0, Vector2(sod.x, sod.z) * (q * sink), 0.0,
					at + Vector2(0.0, sod.y * _cell))
				_frm.put(SHAPE_TURF, [Color(cols[0], seen), Color(rim, seen), Color(face, seen)], xf)
				if _hash(cell, 1) < TUFT_SHARE:
					_frm.put(SHAPE_TUFT + ix, [Color(Pal.TURF, TUFT_ALPHA * seen)], xf)
			if given and state.rings.has(cell):
				if _ring_grown(cell, now):
					var cs := _ring_colours(cell, now)
					var a := seen * sink
					_frm.put(SHAPE_RING + ix, [Color(cs[0], a), Color(cs[1], a)],
						Transform2D(0.0, Vector2.ONE * q, 0.0, at))
				else:
					var live := Face.Builder.new()
					_ring_caps(live, at, cell, now, seen * sink)
					_frm.put_builder(live)
	for cell in gone:
		_sunk.erase(cell)
	for cell in lifted:
		_sod.erase(cell)
	gone = []
	for cell in _glint:
		if now - float(_glint[cell]) >= GLINT_TIME:
			gone.append(cell)
	for cell in gone:
		_glint.erase(cell)
	for cell in settled:
		_wash.erase(cell)
		_bump.erase(cell)
	# Nothing has entered yet on the board's first frames, and a mesh with no
	# surface in it is an error rather than an empty drawing (mesh() is null).
	return _frm.mesh()

## One run per cell, in reading order, as long as everything the cell can
## wear at once: its bed, its sod and tuft (a covered cell), and its fairy
## ring (the caps drawn live while they grow in can overshoot it onto the
## tail, which only paints them after the other cells: a ring stays inside
## its own). Each sod's tones are read off its hash once here.
func _lay_floor() -> void:
	_frm.reset()
	_turf_cols = []
	var bed := _frm.size_of(SHAPE_BED)
	var turf := _frm.size_of(SHAPE_TURF)
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			var ix: int = y * state.n + x
			# A turned-over cell never wears a sod.
			var room := bed
			if not state.given.has(cell):
				room += turf
				if _hash(cell, 1) < TUFT_SHARE:
					room += _frm.size_of(SHAPE_TUFT + ix)
			if state.rings.has(cell):
				room += _frm.size_of(SHAPE_RING + ix)
			_frm.room(PART_CELL, ix, room)
			var tone := _hash(cell) * 2.0 - 1.0
			var face: Color = Pal.TURF_REACH.lightened(tone * TONE) if tone > 0.0 \
				else Pal.TURF_REACH.darkened(-tone * TONE)
			_turf_cols.append([face.lerp(Pal.TURF, TURF_FOOT), face.lerp(Pal.SURFACE, TURF_LIT), face])

## Floor shape `id` about its own origin at the cell `_ref`, in slot colours
## (`RunMesh.slot`): a bed (wall, floor), a sod (foot, rim, crown), a cell's
## tuft, a cell's fairy ring grown (stems, caps).
func _floor_shape(id: int) -> Face.Builder:
	var b := Face.Builder.new()
	var side := _ref * (1.0 - 2.0 * CELL_INSET)
	var radius := _ref * CELL_RADIUS
	if id == SHAPE_BED:
		_bed(b, Vector2.ZERO, side, radius, _ref, RunMesh.slot(0), RunMesh.slot(1))
	elif id == SHAPE_TURF:
		_turf(b, side, radius, _ref, RunMesh.slot(0), RunMesh.slot(1), RunMesh.slot(2))
	elif id >= SHAPE_RING:
		var ix := id - SHAPE_RING
		_ring_shape(b, Vector2i(ix % state.n, ix / state.n), _ref, RunMesh.slot(0), RunMesh.slot(1))
	else:
		var ix := id - SHAPE_TUFT
		var cell := Vector2i(ix % state.n, ix / state.n)
		var root := Vector2((_hash(cell, 2) - 0.5) * 0.5, 0.2 + 0.12 * _hash(cell, 3)) * side
		_tuft(b, Transform2D.IDENTITY, root, _ref * TUFT_H, RunMesh.slot(0))
	return b

## Where `cell`'s sod is at `now`: x and z its scale across and down, y how
## far it has risen, in cells (negative is up); z of nought means no sod is
## drawn. A covered cell with no moment owed stands in its sod; a sod lifting
## off shrinks and rises with pop_out's curve, and one settling back pops in.
## A finished moment is added to `lifted` for the caller to forget.
func _sod_pose(cell: Vector2i, now: float, covered: bool, lifted: Array) -> Vector3:
	if not _sod.has(cell):
		return Vector3(1.0, 0.0, 1.0) if covered else Vector3.ZERO
	var e: float = now - float(_sod[cell].at)
	if bool(_sod[cell].back):
		if e >= Motion.POP_IN:
			lifted.append(cell)
		var grow := Motion.pop_in_scale(e)
		return Vector3(grow.x, 0.0, grow.y)
	if e >= SOD_TIME:
		lifted.append(cell)
		return Vector3.ZERO
	var u := Motion.pop_out_scale(e, SOD_TIME)
	return Vector3(u, -SOD_LIFT * (1.0 - u), u)

## A bed sunk into the card about `at`, for a cell `cell` across: its wall
## (`wall`), showing BED_LIP of a cell along the top, and its floor
## (`floor_col`) under it.
static func _bed(b: Face.Builder, at: Vector2, side: float, radius: float, cell: float,
		wall: Color, floor_col: Color) -> void:
	var corner := at - Vector2.ONE * (side * 0.5)
	var lip := cell * BED_LIP
	b.fan(Face.Builder.round_rect(corner, Vector2.ONE * side, radius), wall)
	b.fan(Face.Builder.round_rect(corner + Vector2(0.0, lip), Vector2(side, side - lip), radius),
		floor_col)

## A sod of turf about the origin, for a cell `cell` across: a foot, a lit
## rim and the crown (`foot`, `rim`, `face`; the board tones each sod off its
## hash and lights it with the win's shine).
static func _turf(b: Face.Builder, side: float, radius: float, cell: float,
		foot: Color, rim: Color, face: Color) -> void:
	var corner := -Vector2.ONE * (side * 0.5)
	var edge := side * (FACE_SHORT + FACE_DROP)
	var bev := cell * BEVEL
	b.fan(Face.Builder.round_rect(corner, Vector2.ONE * side, radius), foot)
	b.fan(Face.Builder.round_rect(corner, Vector2(side, side - edge), radius), rim)
	b.fan(Face.Builder.round_rect(corner + Vector2(bev * 0.7, bev),
		Vector2(side - bev * 1.4, side - edge - bev), maxf(radius - bev * 0.5, 0.0)), face)

## Three slim blades from `root`, the middle one tallest, under `xf`.
static func _tuft(b: Face.Builder, xf: Transform2D, root: Vector2, h: float, col: Color) -> void:
	for blade in [Vector2(0.0, -1.0), Vector2(-0.52, -0.7), Vector2(0.55, -0.66)]:
		var tip: Vector2 = root + blade * h
		var side := (tip - root).orthogonal().normalized() * h * 0.13
		b.fan(xf * PackedVector2Array([root - side, tip, root + side]), col)

## How far into its glint `cell` is, 0 to 1 and back.
func _shine(cell: Vector2i, now: float) -> float:
	if Motion.reduce or not _glint.has(cell):
		return 0.0
	var e: float = now - float(_glint[cell])
	if e <= 0.0 or e >= GLINT_TIME:
		return 0.0
	return sin(PI * e / GLINT_TIME)

## A fairy ring about `at`: RING_CAPS little violet caps on a circle round
## the numeral, each growing in on its own beat after the patch's entrance,
## and all of them warming to gold at the party. Drawn live while any cap is
## still growing; once all are up the floor copies the ring's shape.
func _ring_caps(b: Face.Builder, at: Vector2, cell: Vector2i, now: float, alpha: float) -> void:
	var cs := _ring_colours(cell, now)
	var stem := Color(cs[0], alpha)
	var cap := Color(cs[1], alpha)
	var spin := _hash(cell, 5) * TAU
	for i in RING_CAPS:
		var grow := 1.0
		if not Motion.reduce:
			var e := now - (_rings_at + (cell.x + cell.y) * RING_WAVE + i * RING_STEP)
			grow = Motion.pop_in_scale(e).x
		if grow <= 0.0:
			continue
		_ring_cap(b, at + Vector2.from_angle(spin + TAU * i / RING_CAPS) * _cell * RING_AT,
			_cell * RING_CAP * grow, stem, cap)

## One of a ring's caps about `p`, `k` its size: a stem and a dome.
static func _ring_cap(b: Face.Builder, p: Vector2, k: float, stem: Color, cap: Color) -> void:
	b.fan(Face.Builder.round_rect(p + Vector2(-k * 0.35, -k * 0.1), Vector2(k * 0.7, k * 1.0), k * 0.3), stem)
	var dome := Face.Builder.arc_points(p, k, PI, TAU)
	dome.append(p + Vector2(k, 0.0))
	b.fan(dome, cap)

## `cell`'s whole ring about the origin at a cell `cell_px` across, every cap
## up.
func _ring_shape(b: Face.Builder, cell: Vector2i, cell_px: float, stem: Color, cap: Color) -> void:
	var spin := _hash(cell, 5) * TAU
	for i in RING_CAPS:
		_ring_cap(b, Vector2.from_angle(spin + TAU * i / RING_CAPS) * cell_px * RING_AT,
			cell_px * RING_CAP, stem, cap)

## Whether every cap of `cell`'s ring is up at `now`.
func _ring_grown(cell: Vector2i, now: float) -> bool:
	return Motion.reduce or now - (_rings_at + (cell.x + cell.y) * RING_WAVE
		+ (RING_CAPS - 1) * RING_STEP) >= Motion.POP_IN

## A ring's stem and cap colours at `now`: violet, warming to gold at the
## party.
func _ring_colours(cell: Vector2i, now: float) -> Array:
	var cap: Color = Pal.MG_PURPLE
	var stem: Color = Pal.SURFACE
	if now >= _glow_at:
		var u := 1.0 if Motion.reduce else clampf((now - _glow_at - (cell.x + cell.y) * MEADOW_STEP) / RING_GLOW, 0.0, 1.0)
		cap = cap.lerp(Pal.SUN, u)
		stem = stem.lerp(Pal.SUN_TILE, u)
	return [stem, cap]

## A steady 0-1 value per cell, so a sod's tone and tuft never change.
static func _hash(cell: Vector2i, salt := 0) -> float:
	var h := sin(float(cell.x) * 12.9898 + float(cell.y) * 78.233 + float(salt) * 37.719) * 43758.5453
	return h - floorf(h)

## What `cell`'s number is washed with now: the colour its standing asks for
## at the level it asks for, crossed over WASH_TIME from whatever it wore
## when it last changed. `standing()` is derived from the player's own marks
## and never from the answer -- the wash's whole honesty is in that one call.
## A given of nought takes no green: it is settled from the moment the board
## is built, and a field of green nothings would drown the wash that matters.
func _wash_of(cell: Vector2i, now: float) -> Dictionary:
	return _worn(cell, now, state.standing(cell))

## The same, against a standing named rather than read: _settle_wash needs
## what the number was wearing a moment ago, and the state's own standing()
## already describes the move that has just been made.
func _worn(cell: Vector2i, now: float, standing: int) -> Dictionary:
	var target := _wash_target(standing, int(state.given.get(cell, 0)), state.rings.has(cell))
	if not _wash.has(cell):
		return {"colour": target.colour, "level": target.level, "ink": target.ink,
			"from_colour": target.colour, "from_level": 0.0, "moving": false}
	var was: Dictionary = _wash[cell]
	var u := 1.0 if Motion.reduce else clampf((now - float(was.at)) / WASH_TIME, 0.0, 1.0)
	return {
		"colour": target.colour,
		"level": float(target.level) * u,
		"ink": (was.ink as Color).lerp(target.ink, u),
		"from_colour": was.colour,
		"from_level": float(was.level) * (1.0 - u),
		"moving": u < 1.0,
	}

## The wash a number of `value` standing `standing` asks for, with nothing
## moving. Nought takes no green, as the file comment says.
static func _wash_target(standing: int, value: int, is_ring := false) -> Dictionary:
	if standing == State.OVER:
		return {"colour": Pal.BAD, "level": WASH_OVER, "ink": Pal.BAD}
	if standing == State.SETTLED and value > 0:
		return {"colour": Pal.LEAF, "level": WASH_LEVEL, "ink": Pal.LEAF_DEEP}
	# A fairy ring's numeral is lettered in violet while it is short, so the
	# ring and its number read as one thing.
	return {"colour": Pal.LEAF, "level": 0.0, "ink": Pal.MG_PURPLE_DEEP if is_ring else Pal.TEXT}

## The numerals, over the floor's mesh and inside the entrance pop: one
## draw_set_transform a cell, so a numeral sinks with its cell, bumps when it
## is recounted and takes the wash's ink off Motion's readers. **A given of
## nought draws nothing**: it is turned over and bare, and that is all it has
## to say.
func _draw_numerals(now: float, grown: float) -> void:
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(_cell * NUM_SIZE))
	if px <= 0:
		return
	var rise := font.get_ascent(px) * 0.5
	var centre := _field_centre()
	for cell in state.given:
		var v: int = int(state.given[cell])
		# A plain nought is bare and says so by being bare; a fairy ring's
		# nought is a clue about cells two steps out, so it is lettered.
		if v <= 0 and not state.rings.has(cell):
			continue
		var seen := _entered(cell, now)
		if seen <= 0.0:
			continue
		var ink: Color = _wash_of(cell, now).ink
		var scale := grown * _sink(cell, now) * Motion.bump_scale(now - float(_bump.get(cell, -100.0)))
		if scale <= 0.0:
			continue
		var at := cell_centre(cell) + Vector2(0.0, _cell * BED_LIP * 0.5)
		at.x += Motion.shiver_offset(now - float(_shiver.get(cell, -100.0)), _cell * SHIVER)
		at = centre + (at - centre) * grown
		var ring: bool = state.rings.has(cell)
		draw_set_transform(at, 0.0, Vector2.ONE * scale * (RING_NUM if ring else 1.0))
		var text := str(v)
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		draw_string(font, Vector2(-wide * 0.5, rise), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Color(ink, seen))
	draw_set_transform(Vector2.ZERO)

## The tally strip: a small mushroom and what the field is worth against what
## is spoken for. It is the only number this screen gives you free, and it is
## a clue and not decoration -- the generator carves against the global count,
## so a board played without it would be unfair. It counts in words, because a
## numeral here would read as a fourteenth clue on the field -- but only as
## far as the words go (see _word).
func _draw_tally(now: float) -> void:
	var font: Font = CozyTheme.display(700)
	var left := state.left()
	var line := _tally_line(left)
	var start := size.x * 0.5 - _tally_run() * 0.5
	var grow := _tally_grow(now)
	if grow.x <= 0.0 or grow.y <= 0.0:
		return
	var ink: Color = Pal.TEXT if left >= 0 else Pal.BAD
	if left == 0:
		ink = Pal.LEAF_DEEP
	var at := Vector2(start + TALLY_TEXT_X, _tally_y)
	draw_set_transform(at, 0.0, grow)
	draw_string(font, Vector2(0.0, font.get_ascent(TALLY_SIZE) * 0.5), line,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TALLY_SIZE, ink)
	draw_set_transform(Vector2.ZERO)
	if _tally_face != null and _slots.has(_tally_face):
		var slot: Control = _slots[_tally_face]
		var want := Vector2(start + TALLY_GLYPH_X, _tally_y) - Vector2.ONE * (TALLY_GLYPH * 0.5)
		if slot.position != want:
			slot.position = want

## The tally's run, its little mushroom and its line, in pixels.
func _tally_run() -> float:
	var font: Font = CozyTheme.display(700)
	return font.get_string_size(_tally_line(state.left()), HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		TALLY_SIZE).x + TALLY_TEXT_X

## The tally's scale at `now`: its pop in with the field, and its bump when it
## recounts.
func _tally_grow(now: float) -> Vector2:
	return Motion.pop_in_scale(now - _opened - Motion.ENTER_DELAY) \
		* Motion.bump_scale(now - _tally_at, Motion.BUMP * 0.4)

## The tally's paper pill under its run, washed with how the count stands,
## growing about the run's own centre with the tally's pop and bump.
func _tally_pill(b: Face.Builder, now: float) -> void:
	var grow := _tally_grow(now)
	if grow.x <= 0.0 or grow.y <= 0.0:
		return
	var left := state.left()
	var paper: Color = Pal.SURFACE
	if left == 0:
		paper = Pal.LEAF_TILE
	elif left < 0:
		paper = Pal.BAD_TILE
	var box := Vector2(_tally_run(), TALLY_GLYPH) + PILL_PAD * 2.0
	var xf := Transform2D(0.0, grow, 0.0, Vector2(size.x * 0.5, _tally_y))
	var corner := -box * 0.5
	b.fan(xf * Face.Builder.round_rect(corner + Vector2(0.0, PILL_EDGE), box, box.y * 0.5),
		Color(Pal.LINE, 0.55))
	b.fan(xf * Face.Builder.round_rect(corner, box, box.y * 0.5), paper)

## How many mushrooms are still hidden, in words; nought is *every mushroom
## is planted*, and an over-planted field says so rather than clamping.
func _tally_line(left: int) -> String:
	if left > 0:
		return tr("MP_TALLY_ONE") if left == 1 else tr("MP_TALLY_N") % _word(left)
	if left == 0:
		return tr("MP_TALLY_ALL")
	return tr("MP_TALLY_OVER") % _word(-left)

## `k` in words while there is a word for it, and as a numeral past that.
## Counting in words is a choice about how the strip and the sprout read;
## clamping at fourteen would have been a choice to state a number the board
## knows is false -- on hard a player can plant fifty-two wrong marks, and
## "Fourteen marks are wrong" is worse than a numeral, not better.
func _word(k: int) -> String:
	if k < 0 or k >= WORDS:
		return str(k)
	return tr("MP_NUM_%d" % k)

func _layout_tally() -> void:
	if _tally_face == null or not _slots.has(_tally_face):
		return
	_seat(_tally_face, Vector2(size.x * 0.5, _tally_y), TALLY_GLYPH)

## Everything standing on the field, in one mesh: the tally's pill, the
## blushes, the reach's glow, the flowers, the soft discs under the mushrooms,
## the pebbles on their way out and the pebbles that are here -- each a shape
## made once (`_ground_shape`) copied into its cell's run (`_lay_ground`).
func _build_ground(now: float) -> Dictionary:
	if not _grm.laid() or _ground_shown != state.shown.size():
		_lay_ground()
	_grm.begin()
	var q := _cell / _ref
	var busy := not _sunk.is_empty()
	var pill := Face.Builder.new()
	_tally_pill(pill, now)
	_grm.open(PART_PILL, 0)
	_grm.put_builder(pill)
	# The blush: toward the family's rose and back.
	var gone: Array = []
	for cell in _blush:
		var e: float = now - float(_blush[cell])
		if e >= Motion.FLASH_IN + Motion.FLASH_OUT:
			gone.append(cell)
			continue
		busy = true
		_grm.open(PART_BLUSH, _ix(cell))
		_grm.put(G_SQUARE, [Color(Pal.BAD, BLUSH_ALPHA * Motion.flash_level(e))],
			Transform2D(0.0, Vector2(q, q), 0.0, cell_centre(cell)))
	for cell in gone:
		_blush.erase(cell)
	if _reach_glow(now, q):
		busy = true
	if _flowers(now, q):
		busy = true
	# The soft discs under the mushrooms, anchored at the cell and read off
	# each face's own scale and alpha, so one arrives with the pop and stays
	# put when she hops.
	for cell in _caps:
		var face: MushroomFace = _caps[cell]
		if not face.visible:
			continue
		var seen := clampf(face.scale.y, 0.0, 1.0) * clampf(face.modulate.a, 0.0, 1.0)
		if seen <= 0.0:
			continue
		_grm.open(PART_DISC, _ix(cell))
		_grm.put(G_DISC, [Color(Pal.TEXT, SHADOW_ALPHA * seen)],
			Transform2D(0.0, Vector2.ONE * (q * seen), 0.0, cell_centre(cell) + SHADOW_AT * _cell))
	# Pebbles on their way out, drawn from the shape the state has forgotten,
	# on the tail: a run for every cell's leaving pebble was most of the
	# ground's vertices, for a moment a stroke or a reset has now and then.
	_grm.open(-1, 0)
	var still: Array = []
	for out in _pebble_out:
		var e: float = now - float(out.at)
		var shrunk := Motion.pop_out_scale(e)
		if shrunk <= 0.0:
			continue
		still.append(out)
		busy = true
		var turn := PI * 0.5 * clampf(e / Motion.POP_OUT, 0.0, 1.0)
		_put_pebble(cell_centre(out.cell), Vector2.ONE * shrunk * q, 1.0, turn)
	_pebble_out = still
	# The pebbles that are here: waiting for their wave, popping in with the
	# squash, standing, shivering when refused or wobbling under Check.
	gone = []
	var shook: Array = []
	for cell in state.marks:
		if int(state.marks[cell]) != State.CLEAR:
			continue
		var seen := _entered(cell, now)
		if seen <= 0.0:
			continue
		var grow := Vector2.ONE
		if _pebble_in.has(cell):
			var e: float = now - float(_pebble_in[cell])
			if e < 0.0:
				busy = true
				continue
			grow = Motion.pop_in_scale(e)
			if e < Motion.POP_IN:
				busy = true
			else:
				gone.append(cell)
		grow *= _sink(cell, now)
		if _solved_at >= 0.0:
			# The pebbles clear away in the solve wave, leaving the patch to
			# the mushrooms and their numbers.
			var left := now - _solved_at - _solve_delay(cell)
			grow *= Motion.pop_out_scale(left)
			if left < Motion.POP_OUT:
				busy = true
		if grow.x <= 0.0 or grow.y <= 0.0:
			continue
		var at := cell_centre(cell)
		if _pebble_in.has(cell):
			at.y -= Motion.drop_in_lift(now - float(_pebble_in[cell]), _cell * PEBBLE_DROP, Motion.POP_IN)
		var since: float = now - float(_shiver.get(cell, -100.0))
		if since < Motion.SHIVER_TIME:
			busy = true
			at.x += Motion.shiver_offset(since, _cell * SHIVER)
		elif _shiver.has(cell):
			shook.append(cell)
		_grm.open(PART_PEBBLE, _ix(cell))
		if state.shown.has(cell):
			# A heart showed this cell bare: its pebble stands on a rose halo,
			# never a shade of its own colour.
			_grm.put(G_HALO, [Color(Pal.BAD, 0.55 * seen), Color(Pal.BAD_TILE, seen)],
				Transform2D(0.0, grow * q, 0.0, cell_centre(cell)))
		var turn := Motion.wobble_angle(now - float(_wobble.get(cell, -100.0)))
		if turn != 0.0:
			busy = true
		_put_pebble(at, grow * q, seen, turn)
	for cell in gone:
		_pebble_in.erase(cell)
	for cell in shook:
		_shiver.erase(cell)
	return {"mesh": _grm.mesh(), "busy": busy}

## Mosaic.pebble's pebble about `at`, grown `grow` (with the layout's
## scale), `alpha` and turned `angle`: its shadow unturned, then its body
## and glint.
func _put_pebble(at: Vector2, grow: Vector2, alpha: float, angle: float) -> void:
	_grm.put(G_PEBBLE_SHADOW, [Color(Pal.TEXT, Mosaic.PEBBLE_SHADOW_A * alpha)],
		Transform2D(0.0, grow, 0.0, at))
	_grm.put(G_PEBBLE, [Color(Pal.SOCKET_PEBBLE, Mosaic.PEBBLE_ALPHA * alpha),
		Color(1.0, 1.0, 1.0, Mosaic.GLINT_ALPHA * alpha)], Transform2D(angle, grow, 0.0, at))

## `cell`'s index in reading order.
func _ix(cell: Vector2i) -> int:
	return cell.y * state.n + cell.x

## The ground's runs, in paint order: the pill, then every cell's blush,
## every cell's glow, flower, disc and pebble (with room for a rose halo
## under it only on a cell a heart showed bare, laid again when one is).
func _lay_ground() -> void:
	_grm.reset()
	_ground_shown = state.shown.size()
	var pill := Face.Builder.new()
	_tally_pill(pill, INF)
	_grm.room(PART_PILL, 0, pill.verts.size())
	var sq := _grm.size_of(G_SQUARE)
	var pebble := _grm.size_of(G_PEBBLE) + _grm.size_of(G_PEBBLE_SHADOW)
	var sizes := {PART_BLUSH: sq, PART_REACH: sq, PART_FLOWER: _grm.size_of(G_FLOWER),
		PART_DISC: _grm.size_of(G_DISC), PART_PEBBLE: pebble}
	for part in [PART_BLUSH, PART_REACH, PART_FLOWER, PART_DISC, PART_PEBBLE]:
		for k in state.n * state.n:
			var cell := Vector2i(k % state.n, k / state.n)
			# A turned-over cell has no mushroom and no pebble on it.
			if state.given.has(cell) and part >= PART_DISC:
				continue
			var room: int = sizes[part]
			if part == PART_PEBBLE and state.shown.has(cell):
				room += _grm.size_of(G_HALO)
			_grm.room(part, k, room)

## Ground shape `id` about its own origin at the cell `_ref`, in slot colours.
func _ground_shape(id: int) -> Face.Builder:
	var b := Face.Builder.new()
	var side := _ref * (1.0 - 2.0 * CELL_INSET)
	var s := _ref * PEBBLE * PEBBLE_BODY / Mosaic.PEBBLE_R
	var r := Mosaic.PEBBLE_R * s
	match id:
		G_SQUARE:
			b.fan(Face.Builder.round_rect(-Vector2.ONE * (side * 0.5), Vector2.ONE * side,
				_ref * CELL_RADIUS), RunMesh.slot(0))
		G_DISC:
			Scenery.soft_disc(b, Vector2.ZERO, SHADOW_RX * _ref, SHADOW_RY * _ref, RunMesh.slot(0))
		G_PEBBLE_SHADOW:
			Scenery.soft_disc(b, Vector2(0.0, (Mosaic.PEBBLE_Y + Mosaic.PEBBLE_SHADOW_Y) * s),
				r * Mosaic.PEBBLE_SHADOW.x, r * Mosaic.PEBBLE_SHADOW.y, RunMesh.slot(0))
		G_PEBBLE:
			b.fan(Face.Builder.ring(Vector2(0.0, Mosaic.PEBBLE_Y * s), r, r), RunMesh.slot(0))
			b.fan(Face.Builder.ring(Mosaic.GLINT_AT * s, Mosaic.GLINT_R * s, Mosaic.GLINT_R * s),
				RunMesh.slot(1))
		G_HALO:
			var halo := _ref * SHOWN_HALO
			b.fan(Face.Builder.ring(Vector2.ZERO, halo * 1.08, halo * 1.08), RunMesh.slot(0))
			b.fan(Face.Builder.ring(Vector2.ZERO, halo, halo), RunMesh.slot(1))
		G_FLOWER:
			_flower(b, Vector2.ZERO, _ref * BLOOM_R, 0.0, RunMesh.slot(0), RunMesh.slot(1), RunMesh.slot(2))
	return b

## The cell Mosaic.pebble is handed. It measures everything off that cell and
## draws its body at Mosaic.PEBBLE_R of it; this board's mock draws a pebble
## PEBBLE of a cell in its own R, PEBBLE_BODY of that across, so the cell it
## is handed is scaled to put it there.
func _pebble_px() -> float:
	return _cell * PEBBLE * PEBBLE_BODY / Mosaic.PEBBLE_R

## press_scale for the cell under the finger, one when it is not.
func _sink(cell: Vector2i, now: float) -> float:
	if not _sunk.has(cell):
		return 1.0
	var pr: Dictionary = _sunk[cell]
	var released := -1.0 if now < float(pr.up) else now - float(pr.up)
	return Motion.press_scale(now - float(pr.down), released)

# --- the moments ---

## The chrome is the host's; here the field pops in wide after the family's
## delay, its cells fading in in a diagonal wave. Nothing stands on it yet.
func _enter() -> void:
	_opened = _now()
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP
		+ Motion.stagger(2 * state.n - 2, Motion.ENTER_STAGGER))
	fx.cue("enter")
	# Fairy Rings: once the patch is down, the rings grow in cap by cap in a
	# diagonal wave.
	_rings_at = _opened + Motion.ENTER_DELAY + Motion.ENTER_POP + RING_LEAD
	if not state.rings.is_empty() and not Motion.reduce:
		_busy_for(_rings_at - _opened + (2 * state.n) * RING_WAVE + RING_CAPS * RING_STEP + Motion.POP_IN)
		_after(_rings_at - _opened, fx.cue.bind("rings"))

## The cell under the finger sinks (the Press moment) and stays down until the
## piece it is waiting for lands or the finger lets it go.
func _sink_cell(cell: Vector2i) -> void:
	if _sunk.has(cell) and is_inf(float(_sunk[cell].up)):
		return
	_sunk[cell] = {"down": _now(), "up": INF}
	_busy_for(Motion.PRESS_TIME)

## Lets go of every cell the gesture still holds down: each springs back when
## the piece it is under arrives, or now.
func _end_sinks(now: float, arrivals: Dictionary = {}) -> void:
	var last := now
	for cell in _sunk:
		var pr: Dictionary = _sunk[cell]
		if is_inf(float(pr.up)):
			pr.up = float(arrivals.get(cell, now))
			last = maxf(last, float(pr.up))
	_anim_until = maxf(_anim_until, last + Motion.RELEASE_TIME)

## Every cell of the field as the state marks it now: what _settle diffs
## against after a move.
func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			out[cell] = int(state.marks.get(cell, State.BLANK))
	return out

## Every cell whose mark differs between `before` (a _snapshot) and the state
## now takes its moment -- a mushroom pops in (or drops in, from a hint) or
## shrinks out, a pebble pops in or shrinks out -- `delay_of.call(cell,
## leaving)` seconds after `t`. **And every given whose standing changed bumps
## and takes its wash**: this is the wash's only entry point, so a number can
## never go green by any route but a move that was actually made. Returns the
## second each changed cell's piece arrives, for the sinks to wait on.
func _settle(before: Dictionary, t: float, delay_of: Callable, drop := false,
		quiet: Dictionary = {}) -> Dictionary:
	var arrivals: Dictionary = {}
	var planted_before := 0
	for cell in before:
		if int(before[cell]) == State.FOUND:
			planted_before += 1
	for cell in before:
		var prev := int(before[cell])
		var mark := int(state.marks.get(cell, State.BLANK))
		if prev == mark or quiet.has(cell):
			continue
		var going: float = t + float(delay_of.call(cell, true))
		var coming: float = t + float(delay_of.call(cell, false))
		# The sod lifts off as a mark lands in a covered cell and settles back
		# as the last mark leaves it; a mushroom swapped for a pebble keeps
		# the bed open.
		if not Motion.reduce and not state.given.has(cell):
			if prev == State.BLANK:
				_sod[cell] = {"at": coming, "back": false}
				_busy_for(coming - t + SOD_TIME)
			elif mark == State.BLANK:
				# Once the piece leaving it is most of the way gone.
				var back := going + SOD_BACK_LAG
				_sod[cell] = {"at": back, "back": true}
				_busy_for(back - t + Motion.POP_IN)
		if prev == State.FOUND:
			_cap_down(cell, going - t)
		elif prev == State.CLEAR:
			_pebble_leaves(cell, going)
		if mark == State.FOUND:
			_cap_up(cell, coming - t, drop)
			arrivals[cell] = coming
		elif mark == State.CLEAR:
			_pebble_arrives(cell, coming)
			arrivals[cell] = coming
	_settle_wash(before, t, delay_of)
	var planted := 0
	for cell in state.marks:
		if int(state.marks[cell]) == State.FOUND:
			planted += 1
	if planted != planted_before:
		_recount()
	_refresh_faces()
	_update_blooms(before, t, delay_of)
	return arrivals

## The tally has a new count: its pill bumps and its little mushroom hops.
func _recount() -> void:
	if Motion.reduce:
		return
	_tally_at = _now()
	_busy_for(Motion.BUMP_TIME)
	if _tally_face != null:
		_hop(_tally_face, Motion.HOP, Motion.HOP_TIME)

## The count wash, after a move: every given whose standing changed takes the
## colour its new standing asks for, crossing from the one it wore, and its
## numeral bumps. A given of nought is left alone unless the change is to or
## from OVER -- it draws no numeral and takes no green, so a bump and a wash
## on it would be a beat with nothing behind it.
func _settle_wash(before: Dictionary, t: float, delay_of: Callable) -> void:
	for g in state.given:
		var was := _standing_in(before, g)
		var is_now: int = state.standing(g)
		if was == is_now:
			continue
		if int(state.given[g]) == 0 and was != State.OVER and is_now != State.OVER:
			continue
		var at: float = t + float(delay_of.call(g, false))
		var worn := _worn(g, t, was)
		_wash[g] = {"at": at, "colour": worn.colour, "level": float(worn.level),
			"ink": worn.ink}
		if not Motion.reduce:
			_bump[g] = at
			# A number that has just come right catches the light.
			if is_now == State.SETTLED and int(state.given[g]) > 0:
				_glint[g] = at + GLINT_LAG
		_busy_for(at - t + maxf(WASH_TIME, GLINT_LAG + GLINT_TIME))

## `g`'s standing read off a snapshot rather than off the state: what the
## number said before the move. The state's own standing() reads `marks`,
## which the move has already changed.
func _standing_in(before: Dictionary, g: Vector2i) -> int:
	var need: int = int(state.given[g])
	var have := 0
	for p in state.reach(g):
		if int(before.get(p, State.BLANK)) == State.FOUND:
			have += 1
	if have > need:
		return State.OVER
	return State.SETTLED if have == need else State.SHORT

## A sweep's wave: along the finger's path at the family's stagger.
func _along(path: Array) -> Callable:
	return func(cell: Vector2i, _leaving: bool) -> float:
		if Motion.reduce:
			return 0.0
		return Motion.stagger(maxi(path.find(cell), 0), Motion.ENTER_STAGGER)

## Reset's wave from the far corner.
func _from_far_corner() -> Callable:
	return func(cell: Vector2i, _leaving: bool) -> float:
		if Motion.reduce:
			return 0.0
		return Motion.stagger(2 * state.n - 2 - cell.x - cell.y, Motion.RESET_STAGGER)

func _at_once() -> Callable:
	return func(_cell_: Vector2i, _leaving: bool) -> float:
		return 0.0

## A mushroom is planted on `cell`: she pops in with the squash after
## `delay`, or drops in from above when a hint planted her.
func _cap_up(cell: Vector2i, delay: float, drop: bool) -> void:
	var face := _cap_node(cell)
	face.visible = true
	Motion.stop(_look_tw.get(face))
	Motion.stop(_pos_tw.get(face))
	face.rotation = 0.0
	face.position = Vector2.ZERO
	face.modulate.a = 1.0
	face.eye_open = 1.0
	_set_expr(face, Face.Expr.HAPPY)
	if drop:
		face.scale = Vector2.ONE
		_pos_tw[face] = Motion.drop_in(face, Motion.DROP, Motion.DROP_TIME, delay)
		_busy_for(delay + Motion.DROP_TIME)
	else:
		_look_tw[face] = _sprout(face, delay)
		_busy_for(delay + SPROUT_LAG + SPROUT_PUSH + SPROUT_OPEN + SPROUT_SETTLE)
		if not Motion.reduce:
			_after(delay + SPROUT_LAG, func() -> void:
				if face.visible and _slots.has(face):
					fx.puff(cell_centre(cell) + Vector2(0.0, _cell * SOIL_AT), Pal.PLOT_SOIL, 4))

## She grows the way a mushroom does, about the foot of her stem: a narrow
## closed button pushes up out of the soil, a little taller than she will
## stand, then her cap unfurls wide past its size and settles, and her eyes
## open as it does. Under reduce-motion she is simply there.
func _sprout(face: MushroomFace, delay: float) -> Tween:
	if Motion.reduce:
		face.scale = Vector2.ONE
		return null
	face.scale = Vector2(BUTTON_W, 0.0)
	face.eye_open = 0.0
	var tw := face.create_tween()
	tw.tween_interval(delay + SPROUT_LAG)
	tw.tween_property(face, "scale", Vector2(BUTTON_W, BUTTON_H), SPROUT_PUSH) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(face, "scale", Vector2(1.0 + CAP_FLARE, 1.0 - CAP_FLARE * 0.5), SPROUT_OPEN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(face, "eye_open", 1.0, SPROUT_OPEN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(face, "scale", Vector2.ONE, SPROUT_SETTLE) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw

## A mushroom is pulled up off `cell`: she shrinks to nothing with the quarter
## turn after `delay` and is hidden once gone, unless something planted her
## again.
func _cap_down(cell: Vector2i, delay: float) -> void:
	var face: MushroomFace = _caps.get(cell)
	if face == null:
		return
	Motion.stop(_look_tw.get(face))
	Motion.stop(_pos_tw.get(face))
	face.position = Vector2.ZERO
	face.modulate.a = 1.0
	var tw := Motion.pop_out(face, Motion.POP_OUT * 1.5, delay, _cell * PLUCK)
	if tw == null:
		face.visible = false
		return
	_look_tw[face] = tw
	_busy_for(delay + Motion.POP_OUT * 1.5)
	tw.chain().tween_callback(func() -> void:
		if int(state.marks.get(cell, State.BLANK)) != State.FOUND:
			face.visible = false
			face.rotation = 0.0
			face.position = Vector2.ZERO)

func _pebble_arrives(cell: Vector2i, at: float) -> void:
	_pebble_in[cell] = at
	_busy_for(at - _now() + Motion.POP_IN)

## A pebble leaves `cell` at `at`. Under reduce-motion it is simply gone, as
## pop_out would have it.
func _pebble_leaves(cell: Vector2i, at: float) -> void:
	_pebble_in.erase(cell)
	_shiver.erase(cell)
	if Motion.reduce:
		return
	_pebble_out.append({"cell": cell, "at": at})
	_busy_for(at - _now() + Motion.POP_OUT)

## A cell blushes toward the family's rose and settles: Check pointing at a
## mark on it, or a press refused on it.
func _blush_cell(cell: Vector2i) -> void:
	if Motion.reduce:
		return
	_blush[cell] = _now()
	_busy_for(Motion.FLASH_IN + Motion.FLASH_OUT)

## `face` hops `height` over `time` after `delay`; she rests at her slot's
## origin, so the base is always zero.
func _hop(face: Control, height: float, time: float, delay := 0.0) -> void:
	Motion.stop(_pos_tw.get(face))
	face.position = Vector2.ZERO
	# A drop's fade is stopped here too (drop_in and hop share _pos_tw), and
	# it must not be left half done: a hop always finds her fully seen.
	face.modulate.a = 1.0
	_pos_tw[face] = Motion.hop(face, height, time, delay, 0.0)
	_busy_for(delay + time)

## Check pointing at a mushroom: she wobbles where she stands.
func _wobble_cap(face: Control) -> void:
	Motion.stop(_look_tw.get(face))
	face.rotation = 0.0
	face.scale = Vector2.ONE
	face.eye_open = 1.0
	_look_tw[face] = Motion.wobble2d(face)
	_busy_for(Motion.WOBBLE_TIME)

## A press refused on a given: the cell shivers and blushes, and the sprout
## says why. There is nothing there to be right or wrong about, which is the
## only reason this board ever turns a move down -- a *wrong* mark is never
## refused, or tapping every cell in turn would read the answer off what
## stuck.
##
## Since the polish a press on a number is not a refusal at all: it lights
## the cells the number counts (_reach_glow) while the finger is down, and on
## the tap the sprout says what it counts -- on Insane that is how a player
## tells a fairy ring's sixteen from a plain number's eight.
func _refuse_given(cell: Vector2i) -> void:
	_say(tr("MP_REACH_RING") if state.rings.has(cell) else tr("MP_REACH"), Face.Expr.HAPPY)

## A press refused on a hint's mushroom, with either chip: she shivers and
## strains for a beat while her cell blushes, and the sprout says why.
func _refuse_pinned(cell: Vector2i) -> void:
	_say(tr("MP_PINNED"), Face.Expr.PUZZLED)
	fx.cue("locked")
	_blush_cell(cell)
	var face: MushroomFace = _caps.get(cell)
	if face == null:
		return
	# The face is the refusal's answer and not its decoration: reduce-motion
	# stills the shiver, the blush and the ring (spec section 10), and a
	# player who has reduce-motion on would otherwise get no answer at all.
	_set_expr(face, Face.Expr.STRAIN)
	_after(STRAIN_TIME, func() -> void:
		if face.expression == Face.Expr.STRAIN and _solved_at < 0.0:
			face.expression = Face.Expr.HAPPY)
	if Motion.reduce:
		return
	_shiver[cell] = _now()
	Motion.stop(_pos_tw.get(face))
	face.position = Vector2.ZERO
	face.modulate.a = 1.0
	_pos_tw[face] = Motion.shiver(face, _cell * SHIVER)
	_busy_for(Motion.SHIVER_TIME)

# --- input ---

## Touch and drag only, as every flat board takes them. With the mushroom
## chip a tap plants or pulls up on the cell it was pressed on, and only if
## the finger is let go over that cell; with the pebble chip a tap lays or
## rubs out, and a drag sweeps.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(_cell_at(event.position))
		else:
			_release(_cell_at(event.position))
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _press_cell.x >= 0:
		_drag(event.position)

func _press(cell: Vector2i) -> void:
	_release_press()
	_end_sinks(_now())
	_clear_gesture()
	if is_done() or out_of_hearts or _ejecting or cell.x < 0:
		return
	_press_cell = cell
	if state.given.has(cell):
		_reach = {"cell": cell, "down": _now(), "up": INF}
		fx.cue("reach")
	var mark := int(state.marks.get(cell, State.BLANK))
	# A mushroom under the finger sinks whichever chip is armed: every
	# tappable piece takes the press, including one that will do nothing on
	# release.
	if mark == State.FOUND and _caps.has(cell):
		_pressed = _caps[cell]
		Motion.stop(_look_tw.get(_pressed))
		_pressed.eye_open = 1.0
		_look_tw[_pressed] = Motion.press(_pressed, true)
	if brush == State.FOUND:
		_sink_cell(cell)
	else:
		# The stroke's job is read off the cell it began on: a stroke that
		# begins on the player's own pebble rubs out, any other lays.
		_lay = mark != State.CLEAR
		_paint(cell, true)
	_redraw()

## The mushroom under the finger springs back.
func _release_press() -> void:
	if _pressed == null:
		return
	if is_instance_valid(_pressed):
		Motion.stop(_look_tw.get(_pressed))
		_look_tw[_pressed] = Motion.press(_pressed, false)
		_busy_for(Motion.RELEASE_TIME)
	_pressed = null

## With the pebble chip, every cell between the last one painted and this one
## is swept, so a fast finger leaves no holes. **No line lock**: this field's
## deductions run round a number as often as along a row. The mushroom chip
## does not sweep and does not place on release either -- see below.
func _drag(at: Vector2) -> void:
	# The mushroom chip does not sweep and does not follow the finger either:
	# the gesture is abandoned if it leaves the cell it pressed, which is
	# Queens' rule and every other flat board's. A slide that committed a
	# placement is how a scroll becomes an accidental move on a phone, and
	# this would be the only board where that happened.
	if brush != State.CLEAR:
		return
	var cell := _cell_at(at)
	if cell.x < 0 or cell == _last_paint:
		return
	_dragged = true
	if _last_paint.x >= 0:
		var steps := maxi(absi(cell.x - _last_paint.x), absi(cell.y - _last_paint.y))
		for i in range(1, steps):
			_paint(Vector2i(roundi(lerpf(_last_paint.x, cell.x, float(i) / steps)),
				roundi(lerpf(_last_paint.y, cell.y, float(i) / steps))))
	_paint(cell)
	_redraw()

## A stroke paints a cell once. The cell the finger landed on (`pressed`)
## always takes the press, even a given's or a planted one's, which the
## stroke cannot change; a cell the stroke only passes over sinks only when it
## can change it, Light Up's own rule for a sweep. A stroke runs past a given
## and a planted mushroom without stopping and without refusing.
func _paint(cell: Vector2i, pressed := false) -> void:
	if not _in_field(cell):
		return
	_last_paint = cell
	if _swept.has(cell):
		return
	_swept[cell] = true
	if pressed:
		_sink_cell(cell)
	if state.given.has(cell) or state.pinned.has(cell) or state.shown.has(cell):
		return
	var mark := int(state.marks.get(cell, State.BLANK))
	if _lay:
		if mark != State.BLANK:
			return
	elif mark != State.CLEAR:
		return
	_sink_cell(cell)
	_pending.append(cell)

func _release(at_cell: Vector2i) -> void:
	var cell := _press_cell
	var was_drag := _dragged
	var lay := _lay
	var pending := _pending
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_reach(now)
	if cell.x < 0 or is_done() or out_of_hearts or _ejecting:
		_end_sinks(now)
		_redraw()
		return
	if brush == State.CLEAR and was_drag:
		if not pending.is_empty():
			var before := _snapshot()
			var changed: Array = state.sweep(pending, lay)
			var arrivals := _settle(before, now, _along(pending))
			_end_sinks(now, arrivals)
			if not changed.is_empty():
				# One stroke is one move, however many cells it crossed, and
				# a sweep puffs none of its pebbles.
				fx.cue("pebble" if lay else "remove")
				_speak()
				_redraw()
				note_move()
				return
		_end_sinks(now)
		_redraw()
		return
	_end_sinks(now)
	# A press is a tap only if it is let go on the cell it landed on; a
	# finger that wandered off has changed its mind.
	if at_cell == cell:
		_tap(cell, now)
	_redraw()

## The armed chip on `cell`. The state answers with a reason code and this
## answers the reason: a given and a hint's mushroom are refused, a pebble
## aimed at a planted mushroom does nothing at all (Queens' rule -- a pebble
## must never be the thing that lifts a mushroom), and anything else is a
## move.
func _tap(cell: Vector2i, now: float) -> void:
	var before := _snapshot()
	var why: int = state.place(cell, brush)
	match why:
		State.GIVEN:
			_refuse_given(cell)
			return
		State.PINNED:
			_refuse_pinned(cell)
			return
		State.SHOWN:
			_refuse_shown(cell)
			return
		State.COVERED:
			return
	_settle(before, now, _at_once())
	var at := cell_centre(cell)
	var mark := int(state.marks.get(cell, State.BLANK))
	# A mark on a covered cell throws its sod off in a puff of turf.
	var dug: bool = int(before.get(cell, State.BLANK)) == State.BLANK
	var land := 0.0 if Motion.reduce else SPROUT_LAG + SPROUT_PUSH + SPROUT_OPEN
	if mark == State.FOUND:
		fx.ring(at, _cell * RING_R, Pal.SUN_RAY)
		fx.puff(at, Pal.TURF if dug else Pal.LEAF)
		fx.cue("place")
		if state.judged() and not state.mushrooms.has(cell):
			_wrong_plant(cell, land)
			note_move()
			return
		if state.judged() or not _sent_over(before):
			_on_right_plant(cell, land)
		else:
			_break_streak()
	elif mark == State.CLEAR:
		fx.puff(at, Pal.TURF if dug else Pal.SOCKET_PEBBLE)
		fx.cue("pebble")
	else:
		fx.cue("remove")
		_break_streak()
	_speak()
	note_move()

## Whether the move just made sent some number over its count: a plant on
## Easy or Medium that does is not a streak's.
func _sent_over(before: Dictionary) -> bool:
	for g in state.given:
		if state.standing(g) == State.OVER and _standing_in(before, g) != State.OVER:
			return true
	return false

func _clear_gesture() -> void:
	_press_cell = Vector2i(-1, -1)
	_dragged = false
	_lay = true
	_swept = {}
	_pending = []
	_last_paint = Vector2i(-1, -1)

## The tray armed a chip.
func set_brush(v: int) -> void:
	brush = v

# --- the sprout's line ---

## What the tip card says: the rules while the field is bare, then how many
## mushrooms are planted and how many are to go.
func _speak() -> void:
	if is_done():
		return
	var planted: int = state.mushrooms.size() - state.left()
	var left: int = state.left()
	if planted <= 0:
		var tips := _tips()
		_say(tr(tips[_tip_idx % tips.size()]), Face.Expr.HAPPY)
		return
	if left > 0:
		_say(tr("MP_FOUND_ONE") % _word(left) if planted == 1
			else tr("MP_FOUND_N") % [_word(planted), _word(left)], Face.Expr.HAPPY)
		return
	_say(tr("MP_MISPLACED"),
		Face.Expr.STRAIN)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal.
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _tip_mood != Face.Expr.HAPPY or not state.marks.is_empty():
		return
	var tips := _tips()
	_tip_idx = (_tip_idx + 1) % tips.size()
	_say(tr(tips[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not out_of_hearts and not _ejecting and not state.history.is_empty()

## The host holds its hint video while a wrong mushroom is wilting.
func busy() -> bool:
	return _ejecting

## Takes back the last gesture, however many cells it painted, in a wave along
## the cells it touched. Counts no move.
func undo() -> bool:
	if is_done() or out_of_hearts or _ejecting or state.history.is_empty():
		return false
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	var before := _snapshot()
	var cells: Array = state.undo()
	_settle(before, now, _along(cells) if cells.size() > 1 else _at_once())
	_break_streak()
	_speak()
	fx.cue("undo")
	_redraw()
	moved.emit()
	return true

func hints_left() -> int:
	return State.HINTS_BY_BAND[state.band] + hints_extra - hints_used

## Plants the answer's next mushroom in reading order and pins it: a ring
## pulses out of the cell, she drops in from above, sparkles rise, and she
## wears a leaf sprig from then on. Counts no move but can finish the patch.
func hint() -> bool:
	if is_done() or out_of_hearts or _ejecting or hints_left() <= 0:
		return false
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	var before := _snapshot()
	var target: Vector2i = state.hint()
	if target.x < 0:
		return false
	hints_used += 1
	_settle(before, now, _at_once(), true)
	var at := cell_centre(target)
	fx.ring(at, _cell * RING_R, Pal.LEAF)
	fx.sparkle(at, Pal.LEAF)
	fx.cue("hint")
	_say(tr("MP_HINT"), Face.Expr.HAPPY)
	_redraw()
	moved.emit()
	check_solved()
	return true

## Every mark that contradicts the patch wobbles and its cell blushes -- a
## mushroom on bare ground **and** a pebble on a mushroom, checked both ways,
## since a wrong pebble is exactly as wrong as a wrong mushroom. It plants
## nothing and rubs nothing out. The pebble counts for nothing towards the
## win, but it is still a claim, and Check answers claims.
func check() -> int:
	if is_done() or out_of_hearts or _ejecting:
		return 0
	checks += 1
	# On Hard and Insane no wrong mushroom ever stays, so Check looks at the
	# pebbles -- and only counts them, since pointing at a pebble on a
	# mushroom would hand the mushroom over for nothing.
	if state.judged():
		return _check_pebbles()
	var wrong: Array = state.wrong_marks()
	for cell in wrong:
		if int(state.marks.get(cell, State.BLANK)) == State.FOUND and _caps.has(cell):
			_wobble_cap(_caps[cell])
		else:
			_wobble[cell] = _now()
			_busy_for(Motion.WOBBLE_TIME)
		_blush_cell(cell)
	if not wrong.is_empty():
		var count := wrong.size()
		_say(tr("MP_WRONG_ONE") if count == 1 else tr("MP_WRONG_TWO") if count == 2
			else tr("MP_WRONG_N") % _word(count).capitalize(), Face.Expr.STRAIN)
	elif state.marks.is_empty():
		_say(tr("MP_PLANT_FIRST"), Face.Expr.HAPPY)
	else:
		_say(tr("MP_ALL_RIGHT"), Face.Expr.JOY)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	_redraw()
	return wrong.size()

## Everything the player laid shrinks out in a wave from the far corner; a
## hint's mushroom hops and stays. Hints spent are not refunded.
func reset_board() -> void:
	if out_of_hearts or _ejecting:
		return
	_break_streak()
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	var before := _snapshot()
	state.reset_board()
	var wave := _from_far_corner()
	_settle(before, now, wave)
	if not Motion.reduce:
		for cell in state.pinned:
			if _caps.has(cell):
				_hop(_caps[cell], Motion.RESET_HOP, Motion.HOP_TIME,
					float(wave.call(cell, false)))
	_blush = {}
	_shiver = {}
	_wobble = {}
	moves = 0
	_running = true
	_say(tr("MP_RESET"), Face.Expr.HAPPY)
	fx.cue("reset")
	_redraw()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	var out: String = state.share_glyphs()
	if state.band == 3:
		out += "🌙 " + tr("MP_RINGS_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless:
		out += "🏅 " + tr("BN_FLAWLESS")
	return out

## Whether the solve was flawless, so a reopened daily keeps its seal.
func completion_record() -> Dictionary:
	return {"flawless": _flawless, "hearts": hearts}

# --- the win ---

## One mushroom in JOY, and the words. The board stays on the card as it
## slides down, every mushroom planted and every number green.
func flat_win() -> Dictionary:
	return {"faces": [MushroomFace.new()], "subtitle": tr("MP_WIN")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT + PARTY_EXTRA

## The mushrooms hop in the family's wave along the diagonal with JOY and a
## spark each, and the pebbles clear away in the same wave, leaving the patch
## to the mushrooms and their numbers -- every one of which is already green.
func _on_solved() -> void:
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	_tip_timer.stop()
	_solved_at = now
	_blush = {}
	_shiver = {}
	_wobble = {}
	var k := 0
	for cell in state.mushrooms:
		var face := _cap_node(cell)
		var delay := _solve_delay(cell)
		_hop(face, Motion.SOLVE_HOP, Motion.SOLVE_TIME, delay)
		_grin(face, delay)
		_after(delay, _spark_at.bind(k, cell_centre(cell)))
		k += 1
	# A light crosses the patch along the diagonal behind the hops.
	if not Motion.reduce:
		for y in state.n:
			for x in state.n:
				_glint[Vector2i(x, y)] = now + WIN_GLINT_AT + float(x + y) * WIN_GLINT_STEP
		_busy_for(WIN_GLINT_AT + float(2 * state.n - 2) * WIN_GLINT_STEP + GLINT_TIME)
	_say(tr("MP_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_busy_for(_solve_delay(Vector2i(state.n, state.n)) + Motion.SOLVE_TIME)
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 else checks == 0)
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = now
		_combo_layer.queue_redraw()
	_reach = {}
	_party()
	_redraw()

## A completed daily is rebuilt from its seed, so it opens on a bare patch.
## Plant every mushroom of the answer and settle the patch as it stands once
## the solve's wave has passed: every mushroom standing in JOY, every number
## in its settled green, the entrance over and no moment still owed. Not
## check_solved(): the host owns the win screen and `solved` must not fire a
## second time.
func restore_completed_board() -> void:
	var now := _now()
	_stop_all()
	_clear_gesture()
	_tip_timer.stop()
	state.marks = {}
	for cell in state.mushrooms:
		state.marks[cell] = State.FOUND
	state.pinned = {}
	state.history = []
	_pebble_in = {}
	_pebble_out = []
	_wash = {}
	_bump = {}
	_blush = {}
	_shiver = {}
	_wobble = {}
	_sunk = {}
	_sod = {}
	_glint = {}
	_tally_at = -100.0
	_opened = now - 10.0
	_solved_at = now - 10.0
	_anim_until = 0.0
	_tail = false
	# The meadow stands, the rings glow and the seal is down (a flawless solve
	# kept that in its record; any Insane solve earns the night seal).
	_deal()
	_rings_at = now - 20.0
	_meadow_at = now - 10.0
	_glow_at = now - 10.0
	_flawless = bool(completed_record.get("flawless", false))
	hearts = clampi(int(completed_record.get("hearts", max_hearts)), 0, max_hearts)
	for g in state.given:
		if int(state.given[g]) > 0:
			_bloom[g] = {"at": now - 10.0, "open": true}
	if _flawless or state.band == 3:
		_stamp_at = now - 10.0
	for cell in state.mushrooms:
		var face := _cap_node(cell)
		face.visible = true
		face.scale = Vector2.ONE
		face.eye_open = 1.0
		face.rotation = 0.0
		face.position = Vector2.ZERO
		face.modulate.a = 1.0
		face.sprig = false
		_set_expr(face, Face.Expr.JOY)
	_say(tr("MP_WIN"), Face.Expr.JOY)
	_layout()
	_redraw()

func _solve_delay(cell: Vector2i) -> float:
	if Motion.reduce:
		return 0.0
	return Motion.SOLVE_DELAY + Motion.stagger(cell.x + cell.y, Motion.SOLVE_STAGGER)

## `face` goes to JOY as the wave reaches her; at once under reduce-motion.
func _grin(face: Face, delay: float) -> void:
	if delay <= 0.0:
		face.expression = Face.Expr.JOY
	else:
		_after(delay, func() -> void: face.expression = Face.Expr.JOY)

## A spark as mushroom `k` hops, the two pools used in turn so a run of twelve
## a few hundredths apart does not recycle one pool fast enough to cut each
## burst in half.
func _spark_at(k: int, at: Vector2) -> void:
	if k % 2 == 0:
		fx.sparkle(at, Pal.SUN)
	else:
		fx.puff(at, Pal.SUN, 4)

# --- a number's reach ---

## The finger has let go: a held number's cells fade back out.
func _end_reach(now: float) -> void:
	if _reach.is_empty() or not is_inf(float(_reach.up)):
		return
	_reach.up = now
	_busy_for(REACH_OUT)

## The cells a held number counts, lit in leaf (violet for a fairy ring) while
## the finger is down and fading after. True while it is still moving.
func _reach_glow(now: float, q: float) -> bool:
	if _reach.is_empty():
		return false
	var cell: Vector2i = _reach.cell
	var level := 1.0 if Motion.reduce else clampf((now - float(_reach.down)) / REACH_IN, 0.0, 1.0)
	var moving := level < 1.0
	if not is_inf(float(_reach.up)):
		var u := 1.0 if Motion.reduce else clampf((now - float(_reach.up)) / REACH_OUT, 0.0, 1.0)
		level *= 1.0 - u
		moving = true
		if u >= 1.0:
			_reach = {}
			return false
	if level <= 0.0:
		return moving
	# Pale on the meadow's green, never a shade of it: sunlight for a plain
	# number, a lilac haze for a ring.
	var col: Color = Pal.MG_PURPLE_HI if state.rings.has(cell) else Pal.SUN_TILE
	for p in state.reach(cell):
		_grm.open(PART_REACH, _ix(p))
		_grm.put(G_SQUARE, [Color(col, REACH_ALPHA * level)], Transform2D(0.0, Vector2(q, q), 0.0, cell_centre(p)))
	return moving

# --- flowers ---

## After a move: every number that has just finished (each cell it counts
## marked, its count holding) opens its flower as the move's piece lands, and
## one that stopped being finished folds it. Read off the player's own marks,
## never the answer.
func _update_blooms(_before: Dictionary, t: float, delay_of: Callable) -> void:
	var opened := false
	for g in state.given:
		var done: bool = _solved_at < 0.0 and state.finished(g) and not _judged_wrong_in(g)
		var was: bool = bool(_bloom.get(g, {}).get("open", false))
		if done and not was:
			var at: float = t + float(delay_of.call(g, false)) + (0.0 if Motion.reduce else Motion.POP_IN)
			_bloom[g] = {"at": at, "open": true}
			opened = true
		elif not done and was:
			_bloom[g] = {"at": t, "open": false}
	if opened and not is_done():
		_after(0.0 if Motion.reduce else Motion.POP_IN, fx.cue.bind("bloom"))
	_busy_for(Motion.POP_IN + BLOOM_TIME + 0.1)

## Whether a mushroom the answer does not grow stands in `g`'s reach on a
## judged band: she is about to wilt, and a flower for her would be a reward
## for a wrong move.
func _judged_wrong_in(g: Vector2i) -> bool:
	if not state.judged():
		return false
	for p in state.reach(g):
		if int(state.marks.get(p, State.BLANK)) == State.FOUND and not state.mushrooms.has(p):
			return true
	return false

## The finished numbers' flowers, each in its bed's upper right corner, and
## at the party the meadow: a flower on every bare cell along the diagonal.
## True while any of them is still opening or folding.
func _flowers(now: float, q: float) -> bool:
	var busy := false
	for g in _bloom:
		var d: Dictionary = _bloom[g]
		var e: float = now - float(d.at)
		var k := 0.0
		if bool(d.open):
			if e <= 0.0:
				busy = true
				continue
			if Motion.reduce or e >= BLOOM_TIME:
				k = 1.0
			else:
				busy = true
				k = Motion.back_out(e / BLOOM_TIME)
		elif not Motion.reduce and e < BLOOM_FOLD:
			busy = true
			k = 1.0 - clampf(e / BLOOM_FOLD, 0.0, 1.0)
		if k <= 0.01:
			continue
		_put_flower(g, cell_centre(g) + BLOOM_AT * _cell, q * k,
			(1.0 - minf(k, 1.0)) * 1.2 + _hash(g, 4) * TAU, Pal.SURFACE)
	if now >= _meadow_at:
		for y in state.n:
			for x in state.n:
				var cell := Vector2i(x, y)
				if state.mushrooms.has(cell) or state.given.has(cell):
					continue
				var e: float = now - _meadow_at - (0.0 if Motion.reduce else (x + y) * MEADOW_STEP)
				if e <= 0.0:
					busy = true
					continue
				var kk := 1.0 if Motion.reduce or e >= BLOOM_TIME else Motion.back_out(e / BLOOM_TIME)
				if kk < 1.0:
					busy = true
				var h := _hash(cell, 6)
				var petal: Color = [Pal.SURFACE, Pal.FLOWER, Pal.SUN_TILE, Pal.SURFACE][int(h * 4.0) % 4]
				var at := cell_centre(cell) + Vector2(h - 0.5, _hash(cell, 8) - 0.5) * _cell * 0.3
				_put_flower(cell, at, q * kk * MEADOW_R / BLOOM_R, h * TAU + (1.0 - kk) * 1.2, petal)
	return busy

## The flower in `cell`'s run about `at`, `k` times the bloom's size at the
## cell `_ref`, turned `turn`, its petals `petal`.
func _put_flower(cell: Vector2i, at: Vector2, k: float, turn: float, petal: Color) -> void:
	if _ref * BLOOM_R * k <= 0.5:
		return
	_grm.open(PART_FLOWER, _ix(cell))
	_grm.put(G_FLOWER, [Pal.PETAL_EDGE, petal, Pal.SUN], Transform2D(turn, Vector2(k, k), 0.0, at))

## One flower of radius `r` about `at`, turned `turn`: BLOOM_PETALS petals
## rimmed in `edge` (the daisies'), and a heart (sun-gold; Queens').
static func _flower(b: Face.Builder, at: Vector2, r: float, turn: float, edge: Color, petal: Color,
		heart: Color) -> void:
	for p in BLOOM_PETALS:
		var a := turn + TAU * p / BLOOM_PETALS
		var dir := Vector2.from_angle(a)
		b.fan(_oval(at + dir * r * 0.55, r * 0.52, r * 0.3, a), edge)
		b.fan(_oval(at + dir * r * 0.55, r * 0.45, r * 0.23, a), petal)
	b.fan(Face.Builder.ring(at, r * 0.32, r * 0.32), heart)

static func _oval(at: Vector2, rx: float, ry: float, angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 12:
		var a := TAU * k / 12.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	return pts

# --- judging a mushroom ---

## Check on Hard and Insane: how many of the player's pebbles sit on a
## mushroom, counted and never pointed at.
func _check_pebbles() -> int:
	var wrong: Array = state.wrong_pebbles()
	var count := wrong.size()
	if count == 1:
		_say(tr("MP_PEBBLES_ONE"), Face.Expr.WORRIED)
	elif count > 1:
		_say(tr("MP_PEBBLES_N") % _word(count).capitalize(), Face.Expr.WORRIED)
	elif state.marks.size() == state.shown.size() + state.pinned.size():
		_say(tr("MP_PLANT_FIRST"), Face.Expr.HAPPY)
	else:
		_say(tr("MP_ALL_RIGHT"), Face.Expr.JOY)
	fx.cue("check" if count > 0 else "check_ok")
	_redraw()
	return count

## A press on a pebble a heart showed: it shivers, and the sprout says why.
func _refuse_shown(cell: Vector2i) -> void:
	_say(tr("MP_SHOWN"), Face.Expr.WORRIED)
	fx.cue("locked")
	if Motion.reduce:
		return
	_shiver[cell] = _now()
	_busy_for(Motion.SHIVER_TIME)
	_redraw()

## A plant that holds builds the streak (a note up the pentatonic from the
## second, the bubble from the third, confetti at five and ten) and now and
## then plays a gag. `land` is when she has opened, from now.
func _on_right_plant(cell: Vector2i, land: float) -> void:
	if is_done():
		return
	_streak += 1
	if _streak >= 2:
		var step: int = COMBO_STEPS[mini(_streak - 2, COMBO_STEPS.size() - 1)]
		_after(land, func() -> void:
			if not is_done():
				fx.cue("combo", pow(2.0, step / 12.0), COMBO_DB))
	if _streak >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = _streak
		_combo_cell = cell
		_combo_at = _now()
		_combo_out_at = -INF
		_combo_layer.queue_redraw()
	if COMBO_CONFETTI.has(_streak) and not Motion.reduce:
		_after(land, func() -> void:
			if is_done():
				return
			fx.confetti(cell_centre(cell), 22)
			fx.cue("confetti"))
	_gag(cell, land)

## The streak ends: a pull, a wrong mushroom, an undo, a reset, the hearts
## running out. The bubble deflates.
func _break_streak() -> void:
	_streak = 0
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
		if _combo_layer != null:
			_combo_layer.queue_redraw()
	else:
		_combo_n = 0

# --- failing ---

## A mushroom the answer does not grow there, on Hard or Insane: she sprouts
## like any other, then goes WORRIED as her cell blushes and a heart splits,
## and EJECT_AFTER later she wilts back into the soil and a pebble drops in
## where she stood, for good.
func _wrong_plant(cell: Vector2i, land: float) -> void:
	if hearts <= 0 or is_done():
		return
	hearts -= 1
	_lost_ever = true
	_break_streak()
	_split_index = hearts
	_split_at = _now() + land
	_ejecting = true
	if hearts <= 0:
		out_of_hearts = true
		_running = false
	_bad[cell] = true
	_after(land, func() -> void:
		_heart_layer.queue_redraw()
		fx.cue("heart_lost")
		if not Motion.reduce:
			fx.puff(cell_centre(cell), Pal.BAD, 4)
		_blush_cell(cell)
		_refresh_faces()
		_say(tr("MP_WRONG_PLANT"), Face.Expr.WORRIED)
		_redraw())
	_busy_for(land + EJECT_AFTER + WILT_TIME)
	moved.emit()
	_after(land + (0.0 if Motion.reduce else EJECT_AFTER), _wilt.bind(cell))

## The wrong mushroom wilts: she droops over, sinks into the soil and fades,
## and a pebble drops in where she stood and stays -- the heart has shown the
## cell bare. Every number she had counted settles back as she goes.
func _wilt(cell: Vector2i) -> void:
	_ejecting = false
	if is_done() or not _bad.has(cell):
		return
	_bad.erase(cell)
	var now := _now()
	var before := _snapshot()
	state.reveal(cell)
	_wilt_away(cell)
	var sink := 0.0 if Motion.reduce else WILT_TIME * 0.45
	_settle(before, now, func(_c: Vector2i, _leaving: bool) -> float: return sink,
		false, {cell: true})
	_pebble_arrives(cell, now + sink)
	fx.cue("wilt")
	moved.emit()
	_redraw()
	if out_of_hearts:
		_after(0.0 if Motion.reduce else WILT_TIME, _run_out)
	else:
		_after(0.0 if Motion.reduce else WILT_TIME, _speak)

## Her own wilt: a droop to one side over the first third, then a sink into
## the soil, squashing wide and fading; hidden and put back once gone.
func _wilt_away(cell: Vector2i) -> void:
	var face: MushroomFace = _caps.get(cell)
	if face == null:
		return
	Motion.stop(_pos_tw.get(face))
	Motion.stop(_look_tw.get(face))
	var home := func() -> void:
		if int(state.marks.get(cell, State.BLANK)) != State.FOUND:
			face.visible = false
		face.position = Vector2.ZERO
		face.rotation = 0.0
		face.scale = Vector2.ONE
		face.modulate.a = 1.0
	if Motion.reduce:
		home.call()
		return
	_set_expr(face, Face.Expr.SLEEPY)
	var side := -1.0 if _hash(cell, 9) < 0.5 else 1.0
	var tw := face.create_tween()
	tw.tween_property(face, "rotation", WILT_DROOP * side, WILT_TIME / 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(u: float) -> void:
		face.scale = Vector2(1.0 + 0.3 * u, 1.0 - u)
		face.modulate.a = 1.0 - u * u, 0.0, 1.0, WILT_TIME * 2.0 / 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(home)
	_look_tw[face] = tw
	_after(WILT_TIME * 0.4, func() -> void:
		fx.puff(cell_centre(cell) + Vector2(0.0, _cell * SOIL_AT), Pal.PLOT_SOIL, 5))

## The last heart is gone: the patch slips to dusk, the mushrooms doze off
## along the diagonal, and the card comes up.
func _run_out() -> void:
	if _asleep:
		return
	_asleep = true
	_release_press()
	_clear_gesture()
	_end_sinks(_now())
	_break_streak()
	fx.cue("out_of_hearts")
	_say(tr("MP_OUT"), Face.Expr.SLEEPY)
	for cell in _caps:
		var face: MushroomFace = _caps[cell]
		if face.visible and int(state.marks.get(cell, State.BLANK)) == State.FOUND:
			_after(0.0 if Motion.reduce else (cell.x + cell.y) * 0.04, func() -> void:
				if _asleep:
					_set_expr(face, Face.Expr.SLEEPY))
	_dusk_toward(DUSK)
	_redraw()
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

func _dusk_toward(tint: Color) -> void:
	Motion.stop(_dusk_tw)
	if Motion.reduce:
		modulate = tint
		return
	_dusk_tw = create_tween()
	_dusk_tw.tween_property(self, "modulate", tint, DUSK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## The card, over the whole screen: laid on the host so it covers the chrome,
## or on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["MP_OUT_BODY", "MP_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same patch from the top in Reset's wave, every heart back,
## the shown pebbles gone, the day's light, the clock and the moves from
## zero; hints spent stay spent, and a hint's mushrooms keep their places.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	elapsed = 0.0
	checks = 0
	moves = 0
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	var before := _snapshot()
	state.reset_board(true)
	_deal()
	_settle(before, now, _from_far_corner())
	_blush = {}
	_shiver = {}
	_wobble = {}
	# _deal() puts the light back at once; hold the dusk so it fades.
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	_refresh_faces()
	_heart_layer.queue_redraw()
	_running = true
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	moved.emit()
	_redraw()

## One more heart (the card's video): once a board. The light comes back and
## the mushrooms wake.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_heart_used = true
	hearts = 1
	_back_index = 0
	_back_at = _now()
	_heart_layer.queue_redraw()
	out_of_hearts = false
	_asleep = false
	_running = true
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	_refresh_faces()
	_speak()
	moved.emit()
	_redraw()

## Back from the card: the board ends unsolved first, so the host logs
## puzzle_complete {solved: false} and not an abandon.
func _leave_board() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

# --- the hearts ---

## The hearts over the tally as one mesh on a paper pill (Queens'): pink with
## a small face and a leaf, a faint ghost where one was, the lost one's halves
## falling apart, and one coming back popping in.
func _draw_hearts() -> void:
	if max_hearts <= 0 or _cell <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var y := _hearts_y
	var x0 := size.x * 0.5 - step * (max_hearts - 1) * 0.5
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var corner := Vector2(size.x * 0.5, y) - pill * 0.5
	var rim := Vector2.ONE * HEART_PILL_RIM
	var enter := Motion.pop_in_scale(now - _opened - Motion.ENTER_DELAY).x
	b.polygon(Face.Builder.round_rect(corner - rim, pill + 2.0 * rim, pill.y * 0.5 + HEART_PILL_RIM), Pal.LINE)
	b.polygon(Face.Builder.round_rect(corner, pill, pill.y * 0.5), Pal.SURFACE)
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
	var c := Vector2(size.x * 0.5, y)
	_heart_layer.draw_set_transform(c * (1.0 - enter), 0.0, Vector2.ONE * enter)
	_heart_layer.draw_mesh(_hearts_shown, null)
	_heart_layer.draw_set_transform(Vector2.ZERO)

## A heart's small face: two dots and a smile in ink, a shine at the top left,
## and a leaf on top.
static func _heart_face(b, at: Vector2, s: float) -> void:
	b.ellipse(at + Vector2(-0.5, -0.5) * s, 0.16 * s, 0.1 * s, Color(1.0, 1.0, 1.0, 0.45))
	for sx in [-1.0, 1.0]:
		b.disc(at + Vector2(sx * 0.28, -0.12) * s, 0.09 * s, Pal.OUTLINE)
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, 0.02) * s, 0.16 * s, PI * 0.2, PI * 0.8), 0.07 * s, Pal.OUTLINE)
	b.ellipse(at + Vector2(0.25, -0.76) * s, 0.24 * s, 0.11 * s, Pal.LEAF)

## A heart `s` half-wide about `at` (side 0), or its left (-1) or right (1)
## half, split along a zigzag crack so the two halves fit together
## (Binairo's; its notes say why the crack leaves the tip straight up).
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

# --- the streak's bubble ---

## The streak's paper bubble at the upper right of the plant, "x3" and up in
## ink: it pops in the first time, bumps at each plant and deflates when the
## streak ends (One Line's).
func _draw_combo() -> void:
	if _combo_n < COMBO_FROM or _cell <= 0.0:
		return
	var now := _now()
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
	var cell := cell_centre(_combo_cell)
	var tail := cell + Vector2(_cell * 0.25, -_cell * 0.4)
	var centre := tail + Vector2(box.x * 0.35, -box.y * 0.75)
	centre.x = clampf(centre.x, box.x * 0.5 + 4.0, size.x - box.x * 0.5 - 4.0)
	centre.y = maxf(centre.y, box.y * 0.5 + 4.0)
	var b := Face.Builder.new()
	var tip := tail - centre
	var root := Vector2(clampf(tip.x, -box.x * 0.3, box.x * 0.3), box.y * 0.3)
	b.polygon(PackedVector2Array([root + Vector2(-9.0, 0.0), tip, root + Vector2(9.0, 0.0)]), Pal.LINE)
	b.polygon(Face.Builder.round_rect(-box * 0.5 - Vector2(2.0, 2.0), box + Vector2(4.0, 4.0), box.y * 0.5 + 2.0), Pal.LINE)
	b.polygon(PackedVector2Array([root + Vector2(-6.5, -2.0), tip + (root - tip).normalized() * 3.0, root + Vector2(6.5, -2.0)]), Pal.SURFACE)
	b.polygon(Face.Builder.round_rect(-box * 0.5, box, box.y * 0.5), Pal.SURFACE)
	_combo_shown = b.mesh()
	_combo_layer.draw_set_transform(centre, 0.0, Vector2.ONE * k)
	_combo_layer.draw_mesh(_combo_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	var ascent := font.get_ascent(COMBO_FONT)
	var descent := font.get_descent(COMBO_FONT)
	_combo_layer.draw_string(font, Vector2(-tw * 0.5, (ascent - descent) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color(Pal.LEAF_DEEP, alpha))
	_combo_layer.draw_set_transform(Vector2.ZERO)

# --- gags and the life over the patch ---

## A plant that holds now and then plays a gag, picked by the cell's hash so
## a day replays the same: little hearts float up off her; she twirls a whole
## turn on a hop; or she winds up and sneezes a puff of glittering spores.
## Under reduce-motion, none.
func _gag(cell: Vector2i, land: float) -> void:
	if Motion.reduce or is_done():
		return
	var roll := posmod(hash(Vector2i(cell.x * 13 + 7, cell.y * 5 + _streak)), GAG_ODDS)
	if roll >= GAGS:
		return
	# The plant that solves the patch hands the stage to the party.
	if state.is_solved():
		return
	match roll:
		0:
			var at := cell_centre(cell) - Vector2(0.0, _cell * 0.2)
			var now := _now() + land
			for k in LOVE_HEARTS:
				var off := Vector2((k - (LOVE_HEARTS - 1) * 0.5) * 0.22, -0.2) * _cell
				_love.append({"at": at + off, "t": now + k * 0.08, "phase": _hash(cell, k + 11) * TAU})
			_after(land, fx.cue.bind("love"))
		1:
			_after(land, _twirl.bind(cell))
		2:
			_after(land, _sneeze.bind(cell))

## She twirls a whole turn on a little hop with a sparkle.
func _twirl(cell: Vector2i) -> void:
	var face: MushroomFace = _caps.get(cell)
	if face == null or is_done() or _bad.has(cell) \
			or int(state.marks.get(cell, State.BLANK)) != State.FOUND:
		return
	Motion.stop(_look_tw.get(face))
	face.scale = Vector2.ONE
	face.eye_open = 1.0
	var tw := face.create_tween()
	tw.tween_property(face, "rotation", TAU, TWIRL_TIME).from(0.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void: face.rotation = 0.0)
	_look_tw[face] = tw
	_hop(face, _cell * TWIRL_HOP, TWIRL_TIME)
	fx.sparkle(cell_centre(cell) - Vector2(0.0, _cell * 0.3), Pal.SUN)
	fx.cue("twirl")

## She winds up (a slow squash, her eyes shut), sneezes (a quick stretch up)
## and a puff of glittering spores flies off her cap; then she settles.
func _sneeze(cell: Vector2i) -> void:
	var face: MushroomFace = _caps.get(cell)
	if face == null or is_done() or _bad.has(cell) \
			or int(state.marks.get(cell, State.BLANK)) != State.FOUND:
		return
	Motion.stop(_look_tw.get(face))
	face.rotation = 0.0
	var tw := face.create_tween()
	tw.tween_property(face, "scale", Vector2(1.12, 0.86), SNEEZE_WIND) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(face, "eye_open", 0.0, SNEEZE_WIND)
	tw.tween_property(face, "scale", Vector2(0.88, 1.16), SNEEZE_BLOW) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		var top := cell_centre(cell) - Vector2(0.0, _cell * 0.3)
		fx.puff(top, Pal.SURFACE_HI, 6)
		fx.sparkle(top, Pal.SUN_TILE))
	tw.tween_property(face, "scale", Vector2.ONE, SNEEZE_BACK) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(face, "eye_open", 1.0, SNEEZE_BACK * 0.5)
	_look_tw[face] = tw
	_after(SNEEZE_WIND * 0.6, fx.cue.bind("sneeze"))

## Keeps the life layer drawing while anything on it moves.
func _tick_life(now: float) -> bool:
	var still: Array = []
	for l in _love:
		if now < float(l.t) + LOVE_TIME:
			still.append(l)
	_love = still
	return not _love.is_empty() or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1)

## The life over the patch: love hearts floating off a mushroom, and the seal
## after the solve, with its words.
func _draw_life() -> void:
	if _cell <= 0.0:
		_life_shown = []
		return
	var now := _now()
	var shown: Array = []
	if not _love.is_empty():
		var mesh := _love_heart()
		shown.append(mesh)
		for l in _love:
			var e: float = now - float(l.t)
			if e <= 0.0:
				continue
			var u := e / LOVE_TIME
			var at: Vector2 = l.at + Vector2(sin(u * TAU + float(l.phase)) * 0.08 * _cell,
				-LOVE_RISE * _cell * (1.0 - (1.0 - u) * (1.0 - u)))
			var k := Motion.pop_in_scale(e, 0.2).x
			_life_layer.draw_mesh(mesh, null, Transform2D(sin(u * TAU) * 0.2, Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.4, 0.0, 1.0)))
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_life_shown = shown

## A little pink heart for the love gag, built once.
func _love_heart() -> ArrayMesh:
	if _love_mesh == null:
		var b := Face.Builder.new()
		var r := _cell * LOVE_R
		b.polygon(_heart(Vector2.ZERO, r * 1.15, 0), Pal.FLOWER_DEEP)
		b.polygon(_heart(Vector2.ZERO, r, 0), Pal.FLOWER)
		b.ellipse(Vector2(-0.45, -0.45) * r, 0.18 * r, 0.1 * r, Color(1.0, 1.0, 1.0, 0.5))
		_love_mesh = b.mesh()
	return _love_mesh

# --- the party ---

## After the solve wave: the patch turns into a meadow, a flower opening on
## every bare cell along the diagonal; on Insane the fairy rings glow gold;
## the mushrooms dance; confetti sweeps the patch twice; the seal stamps when
## the solve earned one (flawless, or any Insane patch); and the sprout shares
## a silly bit of mushroom wisdom. Under reduce-motion the meadow, the glow
## and the seal stand at once.
func _party() -> void:
	var now := _now()
	var lead := 0.0 if Motion.reduce else PARTY_AT
	_meadow_at = now + lead
	_busy_for(lead + BLOOM_TIME + 2.0 * state.n * MEADOW_STEP)
	_after(lead, func() -> void:
		_say(_cheer(), Face.Expr.JOY)
		fx.cue("meadow"))
	if not state.rings.is_empty():
		_glow_at = now + lead * 0.5
		_busy_for(lead * 0.5 + RING_GLOW + 2.0 * state.n * MEADOW_STEP)
		_after(lead * 0.5, fx.cue.bind("rings_glow"))
	if _flawless or state.band == 3:
		_stamp_at = now if Motion.reduce else now + lead + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
	if Motion.reduce:
		return
	var field := Rect2(_grid, Vector2.ONE * state.n * _cell)
	_after(lead + 0.15, func() -> void:
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell * 0.3), 30, field.size.x * 0.9)
		fx.cue("party"))
	_after(lead + 0.6, func() -> void:
		fx.confetti(field.get_center(), 24, field.size.x * 0.7))
	_after(lead + 0.35, _dance)

## Every mushroom sways left and right on the beat, DANCE_BEATS times, and
## settles -- about her foot, so she dances from the ground.
func _dance() -> void:
	fx.cue("dance")
	for cell in state.mushrooms:
		var face: MushroomFace = _caps.get(cell)
		if face == null or not face.visible:
			continue
		Motion.stop(_look_tw.get(face))
		face.scale = Vector2.ONE
		var tw := face.create_tween()
		for i in DANCE_BEATS:
			var side := DANCE_TILT * (1.0 if (i + cell.x + cell.y) % 2 == 0 else -1.0)
			tw.tween_property(face, "rotation", side, DANCE_BEAT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(face, "rotation", 0.0, DANCE_BEAT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_look_tw[face] = tw
	_busy_for(DANCE_BEAT * (DANCE_BEATS + 1))

## One of CHEERS silly bits of mushroom wisdom, picked by the patch itself, so
## a day always gets the same one.
func _cheer() -> String:
	var cells: Array = state.mushrooms.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	return tr("MP_CHEER_%d" % posmod(hash(str(cells)), CHEERS))

## The seal on the card's lower right, dropping in from STAMP_FROM its size
## and settling with the back ease's overshoot, its words over it.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := size.x * STAMP_R * 0.75
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, state.band == 3)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := _card.end - Vector2(rad * 1.2, rad * 0.95)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if state.band == 3:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless else tr("MP_RINGS_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

# --- odds and ends ---

## Now and then one planted mushroom sways on her root, so a patch left alone
## still breathes. Only a mushroom with nothing else moving her takes it, and
## the sway is her own node turning: nothing on the field is rebuilt for it.
func _sway() -> void:
	if Motion.reduce or _cell <= 0.0:
		return
	var standing: Array = []
	for cell in _caps:
		var face: MushroomFace = _caps[cell]
		if face.visible and face != _pressed \
				and int(state.marks.get(cell, State.BLANK)) == State.FOUND \
				and not _tweening(_look_tw.get(face)) and not _tweening(_pos_tw.get(face)):
			standing.append(face)
	if standing.is_empty():
		return
	var face: MushroomFace = standing[randi() % standing.size()]
	_look_tw[face] = Motion.wobble2d(face, SWAY_ANGLE, SWAY_TIME)

## The mushrooms, baked (the board checkup, 2026-10-02): each was two draw
## calls, a full Insane patch's fourteen a quarter of the board's. Every
## frame, each one standing still in her slot -- no pop, hop, press, sway or
## wilt on her -- is drawn by `_cap_bake` as one mesh, eyes open and looking
## ahead, and her slot hidden; a moving one draws herself. The bake is remade
## only when one joins or leaves it or changes her look. One only blinking
## or glancing draws herself over her baked twin, without her shadow (the
## twin's is there), so blinks never ask for a bake.
func _bake_caps() -> void:
	if _cap_bake == null:
		return
	var key: Array = [_cell]
	var still: Dictionary = {}
	for cell in _caps:
		var face: MushroomFace = _caps[cell]
		var ok := _cap_still(face)
		still[cell] = ok
		key.append([cell, face.expression, face.sprig, (_slots[face] as Control).position, face.size] if ok else null)
	if key != _cap_key:
		_cap_key = key
		var b := Face.FlatBuilder.new(_flat_cache)
		for cell in _caps:
			if still[cell]:
				var face: MushroomFace = _caps[cell]
				# Her twin keeps her shadow, which she drops while baked.
				var bare := face.shadowless
				face.shadowless = false
				face.bake_into(b, (_slots[face] as Control).get_transform() * face.get_transform(), Color.WHITE, true)
				face.shadowless = bare
		_cap_bake.mesh = b.mesh() if not b.verts.is_empty() else null
		_cap_bake.queue_redraw()
	for cell in _caps:
		var face: MushroomFace = _caps[cell]
		var slot: Control = _slots[face]
		var baked: bool = still[cell]
		var own := not baked or not face.at_rest()
		if slot.visible != own:
			slot.visible = own
		if face.shadowless != baked:
			face.shadowless = baked

## Whether `face` stands still in her slot, as her bake would draw her.
func _cap_still(face: MushroomFace) -> bool:
	return face.visible and not face.is_queued_for_deletion() and face.size.x > 0.0 \
		and face.position == Vector2.ZERO and face.scale == Vector2.ONE and face.rotation == 0.0 \
		and face.modulate == Color.WHITE and face.self_modulate == Color.WHITE \
		and face.hat == 0.0 and face.glasses == 0.0

## The still mushrooms' one mesh (see _bake_caps).
class CapBake extends Control:
	var mesh: ArrayMesh

	func _draw() -> void:
		if mesh != null:
			draw_mesh(mesh, null)

static func _tweening(tw) -> bool:
	return tw != null and (tw as Tween).is_valid() and (tw as Tween).is_running()

## Kills every tween the previous board still tracks and retires its pending
## callbacks, so a rebuild never inherits a hop aimed at a mushroom that is
## gone.
func _stop_all() -> void:
	_gen += 1
	_pressed = null
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

## Seconds since the scene started, the clock every animation here reads.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
