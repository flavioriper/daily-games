extends "res://core/puzzle_base.gd"

## Pinwheel as a flat board: a frame of cells with a handful of paper pieces
## lying on it, each held down through one of its own squares by a pinwheel.
## Tap a pinwheel and its piece swings a quarter turn clockwise about the pin
## -- **the pin itself never moves**. The rules live in
## puzzles/pinwheel_state.gd, which this only draws.
##
## **Overlap is the working state, and the board says so.** A square two
## pieces are on is washed and hatched; a square nobody is on stays bare
## ground. So there is nothing to check: the board already answers,
## continuously, the only question a Check could ask. That is Word Trail's
## and Quilt's shape reached by a third route -- no tray because nothing is
## picked up, no actions row because there is no Check, Reset up in the top
## bar and the tip card alone at 140 -- and it is the first flat board that
## lets a player hold an illegal position **and shows them it is illegal**,
## rather than refusing the move or waiting to be asked.
##
## How it is drawn. Three meshes and no Controls:
##
##  1. `_frame` -- the ground and its cell rules, which never change;
##  2. `_still` -- every piece not swinging;
##  3. `_live`  -- the swinging pieces, so they draw over their neighbours,
##                 then the stain over all of them, then every pinwheel.
##
## A piece is one silhouette and not a row of squares (`ui/faces/patch_cloth.gd`,
## reused unchanged: `loops()` is shape-agnostic, so a turned piece is just
## another cell set), and the cached loops are per **(piece, orientation)** --
## four entries a piece at most -- rather than traced on the frame.
##
## Every part of a piece goes through `Cloth.place` with the span `2 * pin +
## 1`, whose middle is exactly the pin's own centre, so the pop, the lift and
## the swing's turn (`place`'s `rot`) all happen about the pin, and the print
## and the stitch can never be left behind by a swing.
##
## The polish of 2026-10-01 (spec `2026-10-01-pinwheel-polish-design.md`):
## on Hard and Insane turning a piece that is already home **snags** it -- a
## heart, and a gold button sews it down for good; Insane ties the pinwheels
## together with **ribbons**, so a tap tugs the pieces tied below it round
## too; a streak, three gags and a party with a kite and the nap cat.
##
## **Since 2026-10-04 nothing is judged** (docs/agents/flat-screens.md,
## "Insane counts moves"): no band has hearts, so nothing snags and nothing
## is sewn down by one; `_snag` and the hearts are left in place, asleep.
## Ribbons counts moves instead -- `max_moves` off the state's
## `moves_budget()`, "N moves left" on the pill where the hearts sat, one off
## for every tap that turns a piece (`_spend`), and out of moves is the old
## out-of-hearts ending. The streak stays: it reads the bare and stained
## squares the frame shows, never the answer.
##
## Spec: docs/superpowers/specs/2026-09-20-pinwheel-flat-design.md, section 7.
## Ported from the canvas mock at docs/brainstorm/concepts.html#pinwheel,
## which is the reference for every measure here.

const State = preload("res://puzzles/pinwheel_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
## The cloth -- the silhouette, the lip and the eight colours -- and the
## pinwheel over it. Both live in ui/faces/ because the menu card draws the
## same two things and neither should own the other's drawing.
const Cloth = preload("res://ui/faces/patch_cloth.gd")
const PinWheel = preload("res://ui/faces/pin_wheel.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Seal = preload("res://ui/flat/seal.gd")
const NapCat = preload("res://ui/faces/nap_cat.gd")
const RunMesh = preload("res://ui/flat/run_mesh.gd")
const Haptics = preload("res://core/haptics.gd")

# --- the screen, measured (spec section 4) ---
## The card's own inset, all round. At the standard 1000 x 1340 card that
## leaves 944 x 1284, so band 1's cell is 183 -- the largest cell of any flat
## board, and not indulgence: the tap target is the pin cell and nothing
## else, so a generous cell is what stops a mis-tap turning a neighbour.
const INSET := 28.0
## The looks' kinds (`_look`): the kind in the high bits, the piece and its
## orientation (`p * 4 + o`), the cloth, the ribbon or the stain in the low.
const K_SIL := 1 << 16
const K_PRINT := 2 << 16
const K_TRIM := 3 << 16
const K_WHEEL := 4 << 16
const K_WSHADOW := 5 << 16
const K_TACK := 6 << 16
const K_BUTTON := 7 << 16
const K_RIBBON := 8 << 16
const K_STAIN := 9 << 16
const K_LOW := (1 << 16) - 1
## Settled stains kept before the looks start again.
const STAINS_MAX := 300
## The ground's border round the grid, its corner and its rim, in design
## pixels. It is drawn **outside** the cells, so on the band where the cell
## is bound by the width it eats into the inset rather than into the grid --
## 10 px of card is still clear of it, and shrinking the cell for it would
## cost the spec's measured 183.
const FRAME_PAD := 18.0
const FRAME_RADIUS := 26.0
const FRAME_RIM := 7.0

# --- the cloth and the ground, in cells ---
## The faint rules between two cells of the frame.
const RULE_W := 0.018
## A piece's own edge: **solid**, in `Cloth.cloth_stitch`. `Cloth.dash_loop`
## in `Pal.BAD` is Quilt's refusal idiom and a permanent dashed edge would
## steal it.
const EDGE_W := 0.04
## The rose halo a refused piece wears instead of blushing (see `_halo`).
const HALO_W := 0.085
## The pinwheel's radius, in cells. One of this board's own two constants,
## and both are shape rather than timing.
## 0.19 until the polish of 2026-09-26, when it was lost on butter and sky.
const PIN_R := 0.28
## The pinwheel's coloured vanes wear their piece's deep cloth (its lip), not
## the cloth itself, which vanished on its own piece: blue on blue. That the vanes wear the piece's colour is the only thing
## saying whose handle it is, and on a board where a pin can sit underneath
## another piece -- nothing prevents it -- that started as prettiness and is
## now load-bearing. (Until the polish the hub carried it, at a quarter of
## the area.)

# --- the stain ---
## The wash a stained cell takes, and the hatch over it. This board's other
## own constant.
##
## **A wash alone cannot signal state on pieces coloured by index**, which is
## Quilt's "a patch cannot blush" lesson from the other end. A flat wash over
## a piece is a fourth-darker version of that piece's cloth, and on a board
## where every piece is already a different colour the eye reads it as
## *another cloth*: the first rendered frame had a coral under a wash reading
## as maroon and a butter reading as olive. A hatch cannot be a cloth --
## nothing else on this screen is drawn in lines -- so a hatched cell is
## unambiguously "two pieces here" whatever is under it.
## The wash was 0.30 until the polish of 2026-09-26, and it turned a third
## of the board into darker cloths; the hatch and the dashed outline round
## each contested region carry the state now, and the wash only tones it.
const STAIN_ALPHA := 0.12
const HATCH_ALPHA := 0.22
const OUTLINE_W := 0.04
const OUTLINE_ON := 0.12
const OUTLINE_OFF := 0.08
const OUTLINE_ALPHA := 0.4
const HATCH_W := 0.035
const HATCH_STEP := 0.24
## A stained cell's corner, and how it arrives: from a third of its size with
## the back ease. A corner is rounded only where the cell has no stained
## neighbour on either of its two sides, so a group of stained cells reads as
## one contested region with one outline and never double-darkens a seam.
const STAIN_RADIUS := 0.22
const STAIN_POP := 0.20
const STAIN_FROM := 0.35

# --- the swing ---
## A multi-quarter spin -- a hint, or the undo of one -- is longer than one
## quarter but **not n times longer**: at n times a three-quarter spin reads
## as a stall rather than as a spin.
const SWING_EXTRA := 0.6
## The blades keep turning a moment past the cloth, reading the same
## `Motion.turn_angle` with a longer time, so the pinwheel carries the
## overshoot the piece does not.
const HUB_FACTOR := 1.55
## The nudge a pinwheel gives when the player taps a piece somewhere that is
## not its pin: the vocabulary's wobble, wider and slower than a chip's,
## through the recipe's own parameters and never a copied constant.
const WOB_ANGLE := 0.42
const WOB_TIME := 0.46
## The ring a hint pulses, in cells, off the piece's pin.
const RING_R := 0.9
## How long a solved piece's edge takes to warm toward the sun, and how far.
const WARM_TIME := 0.3
const WARM_MIX := 0.7
## Long enough for the solve wave to cross the frame before the win screen
## covers it.
const WIN_WAIT := 1.6
## Three, as every flat board gives.
const HINTS := 3

# --- the polish (spec amendment, 2026-09-26) ---
## The backing is a tufted quilt, as Quilt's is: every cell a soft puff of
## batting inset this far, and a tie of thread where four cells meet, so a
## bare cell reads as an empty socket and not as beige.
const PUFF_INSET := 0.07
const PUFF_R := 0.2
const PUFF_ALPHA := 0.26
const TIE_LEN := 0.055
const TIE_W := 0.028
## Every piece casts a short shadow on whatever it lies over, which is what
## says which of two overlapping pieces is on top. A swinging piece is lifted
## off the frame: it grows by LIFT_GROW, its shadow falls away to
## LIFT_SHADOW, and it comes down on the pin with a squash of LAND_SQUASH
## and a puff of its own cloth.
const REST_SHADOW := Vector2(0.03, 0.07)
const REST_LEVEL := 0.55
const LIFT_SHADOW := Vector2(0.08, 0.22)
const LIFT_GROW := 0.05
const LAND_SQUASH := 0.035
## The idle breeze: every GUST_EVERY seconds (and up to GUST_JITTER more) one
## pinwheel catches a gust and spins GUST_TURN over GUST_TIME. A half turn,
## because the vanes alternate two papers and a half turn lands on the same
## picture it left. Never a continuous spin: a board whose idle rebuilds its
## mesh every frame pays for it every frame (Caterpillar's 12.2 ms).
const GUST_EVERY := 3.2
const GUST_JITTER := 2.4
const GUST_TURN := PI
const GUST_TIME := 1.1
## On the solve the breeze crosses the frame in the solve wave and every
## pinwheel spins a whole turn as it passes.
const WIN_TURN := TAU
const WIN_SPIN := 1.0

const TIP_CYCLE := 8.0
const TIPS := [
	"PW_TIP_TAP",
	"PW_TIP_PIN",
	"PW_TIP_DARK",
	"PW_TIP_DONE",
]
## Hard leads with the hearts; Insane with the ribbons.
const TIPS_HEARTS := ["PW_TIP_HEARTS", "PW_TIP_TAP", "PW_TIP_DARK", "PW_TIP_SEWN"]
const TIPS_RIBBONS := ["TIP_MOVES_SEQ", "PW_TIP_RIBBON", "PW_TIP_CROSSED", "PW_TIP_TOP"]

## A moment far enough in the past that every curve reader is past its end.
const AGO := -1.0e9
const FAR := 1.0e9

# --- the hearts (polish section 1; Quilt's, Fairy Lights' and Paper Planes' pill) ---
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
const MovesPill = preload("res://ui/flat/moves_pill.gd")
const MovesDiagram = preload("res://ui/hud/moves_tutorial_diagram.gd")
## The moves the out-of-moves card's video buys.
const MOVES_BONUS := 5

# --- the snag (polish section 1) ---
## A tap on a piece already home: it starts its quarter, catches on its own
## thread SNAG_ANGLE round (SNAG_OUT), strains there (SNAG_HOLD), and springs
## back home with the back ease's overshoot by SNAG_TIME. The heart splits as
## it catches; the button is sewn on at SNAG_TACK.
const SNAG_ANGLE := 0.42
const SNAG_OUT := 0.14
const SNAG_HOLD := 0.1
const SNAG_TIME := 0.62
const SNAG_TACK := 0.5
## The gold button a sewn piece wears, on its pin cell's lower right: its
## radius and where, in cells off the pin, and how long it takes to pop on.
const BUTTON_R := 0.12
const BUTTON_AT := Vector2(0.28, 0.28)
const BUTTON_POP := 0.26
const THREAD := Color("c2667a")

# --- the ribbons (polish section 2, Insane) ---
## A ribbon's width and bow (a share of its length) in cells; a crossed one
## is an S. TUG_LAG is the wait a tug takes per ribbon down, TUG_TIME how long
## a ribbon stays taut and springs back.
const RIBBON_W := 0.085
const RIBBON_BOW := 0.08
const TUG_LAG := 0.09
const TUG_TIME := 0.45
const SATIN := Color("eba3b2")
const SATIN_DEEP := Color("c16a7f")
const SATIN_X := Color("a3cbe8")
const SATIN_X_DEEP := Color("5c90bb")
## At the party the ribbons slip loose and float up out of the frame.
const UNTIE_AT := 0.5
const UNTIE_TIME := 1.4

# --- the press (polish section 5) ---
## The wheel under a finger sinks to this (Motion's press, deeper: a wheel is
## small).
const PRESS_DIP := 0.84

# --- the rewards (polish section 3; Quilt's, Fairy Lights' and Paper Planes') ---
## The streak: taps in a row that leave the frame tidier (fewer bare or
## doubled squares); a tap that changes nothing is neutral, a messier one,
## a snag, an undo or a reset ends it. `combo` up the pentatonic from the
## second, the bubble from COMBO_FROM, confetti at 4, 7, then every 5.
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0
const COMBO_DEFLATE := 0.25
## The bubble shows its number this long, then deflates on its own; the
## streak itself runs on, and the next right move pops it back in.
const COMBO_HOLD := 1.2
const COMBO_FONT := 44
## Gags on a tidying tap, one in GAG_ODDS (any GAG_SPAN taps share the three
## kinds evenly), one at a time.
enum Gag { NONE = -1, WHIRL, LOVE, BUTTERFLY }
const GAG_ODDS := 4
const GAG_SPAN := 12
const GAG_STEP := 5
## The whirl: the wheel catches a happy gust and spins WHIRL_TURN.
const WHIRL_TURN := TAU * 2.0
const WHIRL_TIME := 1.1
## Love: LOVE_HEARTS hearts out of the pin, rising LOVE_RISE cells over
## LOVE_TIME.
const LOVE_HEARTS := 3
const LOVE_TIME := 1.2
const LOVE_RISE := 0.9
const LOVE_R := 0.13
## The butterfly: in over BFLY_IN, sits on the wheel BFLY_SIT, off over
## BFLY_OUT; BFLY_FLAP beats a second in the air, BFLY_PX across.
const BFLY_IN := 0.7
const BFLY_SIT := 0.8
const BFLY_OUT := 0.8
const BFLY_FLAP := 7.0
const BFLY_PX := Vector2(60.0, 96.0)
const BFLY_WING := Color("f4c95d")
const BFLY_WING_DEEP := Color("e08a4f")
## The party, PARTY_AT after the solve; win_delay() waits PARTY_TIME past it.
const PARTY_AT := 0.35
const PARTY_TIME := 3.2
const CHEERS := 12
## The kite: across the card from the lower left to the upper right over
## KITE_TIME from KITE_AT, bobbing, its tail of KITE_BOWS bows trailing.
const KITE_AT := 0.3
const KITE_TIME := 2.4
const KITE_PX := 0.17
const KITE_BOWS := 4
const KITE_TAIL := 0.07
## The nap cat on the frame's foot (Paper Planes' clock, no straggler).
const CAT_PX := 0.18
const CAT_AT := 0.5
const CAT_POP := 0.22
const CAT_HOPS := 3
const CAT_HOP_TIME := 0.32
const CAT_HOP_H := 0.45
const CAT_SETTLE := 0.25
const CURL_AT := 2.3
## The seal on the frame's lower right corner.
const STAMP_AT := 1.2
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.16
const STAMP_TILT := -0.22

## The out-of-hearts card's Back: the host takes the board away.
signal leave

var _state = State.new()
## The board's own effects node: the hint's ring and every sparkle come
## through it and nowhere else.
var fx: Node2D

## Pinwheels spinning in a gust: piece -> {"at", "turn", "time"}. Only the
## blades read it; the piece does not move.
var _gust: Dictionary = {}
var _next_gust := 0.0
var _gust_rng := RandomNumberGenerator.new()
## Per piece, the moment its last swing came down, for the landing squash.
var _landed: Dictionary = {}
## Each piece's quilting line per orientation: [p][o] -> loops, in cells.
var _insets: Array = []

## The pieces mid-swing: piece -> {"at": float, "quarters": int}. Clockwise
## is positive, so an undo's swing is negative and goes back the way it came.
var _swing: Dictionary = {}
## Per piece, the moment its swing **lands**. The stain wave keys on this and
## not on the tap: keyed on the tap, a mid-swing frame shows the wash sitting
## on a cell the piece is still seventy degrees away from.
var _turned_at := PackedFloat32Array()
## Per piece, when its pinwheel was last nudged by a tap on the wrong cell.
var _wob: Dictionary = {}
## A refused tap on a pinned-fast piece: {"piece": int, "at": float}.
var _refused: Dictionary = {}
## The rings and sparkles a wave still owes: [{"at", "point", "colour", "ring"}].
var _pending: Array = []
## The cell a press landed on, so a release somewhere else is not a tap.
var _pressed := Vector2i(-1, -1)

var _opened := 0.0
var _anim_until := 0.0
var _solved_at := -INF
## The piece the last gesture moved: the solve wave runs out of its pin.
var _last_turned := 0

## The ground, the still pieces, and everything that is moving. Dropped
## whenever something changed so the next _draw rebuilds them.
var _frame_mesh: ArrayMesh
var _still: ArrayMesh
var _live: ArrayMesh
## The checkup of 2026-10-02: every piece, wheel, ribbon and settled stain is
## a look made once and copied natively under a transform (`RunMesh`, no
## rooms), in a reference layout's space and drawn under `_relay()`, so the
## win card's smaller relayout makes nothing again. `_still` is handed back
## while its plan (every resting piece's look, transform and warmth) is the
## one it was built from.
var _rm_still: RunMesh
var _rm_top: RunMesh
var _rm_stain: RunMesh
var _rm_rib: RunMesh
var _rm_wheel: RunMesh
var _still_plan: Array = []
var _still_built := false
## The layers over the lifted pieces, each its own mesh so a live part of
## one never moves where another's looks land (their indices are offset
## once a place), each handed back while its plan is unchanged.
var _stain_mesh: ArrayMesh
var _rib_mesh: ArrayMesh
var _wheel_mesh: ArrayMesh
var _stain_plan = null
var _rib_plan = null
var _wheel_plan = null
var _dirty := true
var _in_ref := false
var _ref_cell := 0.0
var _ref_origin := Vector2.ZERO
var _stain_ids: Dictionary = {}
## The meshes the last _draw actually handed to the canvas item. A canvas
## command holds a mesh by RID and not by reference, so dropping the only
## reference to a mesh still on the item's command list leaves the renderer
## drawing a freed RID ("Parameter mesh is null", and an empty card).
var _shown: Array = []

## Each piece's boundary loops, per orientation, in cell units: [p][o] ->
## Array[PackedVector2Array]. Four entries a piece at most, and tracing on
## the frame is exactly what this cache exists to avoid.
var _loops: Array = []
## Each orientation's quarter turn off the grown one, so a resting pinwheel
## faces the way its piece is lying.
var _quarter: Array = []
## The longest wave any pin can send across this frame, so `_animating` can
## ask one question about the stain instead of one per cell.
var _wave_span := 0.0

var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

## Per piece, [from][to] -> the quarter turns clockwise (`_cw`) and
## anticlockwise (`_ccw`) that carry one orientation onto the other. An index
## step is not a quarter: a skipped orientation makes it two, and a
## symmetric piece lands on its own picture early.
var _cw: Array = []
var _ccw: Array = []

## The hearts (Hard and Insane), Paper Planes' names.
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
## Insane's move counter (ui/flat/moves_pill.gd), since 2026-10-04 in place
## of the hearts: `max_moves` is 0 on a band that does not count (and on the
## tutorial's frames, which `build` never deals). Out of moves with the frame
## unfinished sets `out_of_hearts`.
var moves_left := 0
var max_moves := 0
var _moves_pill := MovesPill.new()
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
## Bumped on every deal, so an `_after` from the last one never lands.
var _gen := 0
## Input, Undo, Hint and Reset wait until this (a snag playing out).
var _busy_until := 0.0
var _was_busy := false
## Per piece, when its gold button was sewn on (AGO: long since; absent:
## not sewn).
var _tack_at: Dictionary = {}
## Per ribbon index, when it last went taut.
var _tug_at: Dictionary = {}
## The pin under a finger: piece, when it landed, when it lifted (-1: down).
var _press_piece := -1
var _press_down := AGO
var _press_up := -1.0
var _press_last := -1

## The rewards. `force_gag` is the harness's: a Gag kind every tidying tap
## plays (one at a time still), NONE for none, -2 to leave it to the day.
var force_gag := -2
var _streak := 0
var _streak_gen := 0
var _taps := 0
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
var _love: Array = []        # [{"at", "t", "phase"}]
var _flies: Array = []       # [{"p", "t", "from"}]
## The piece whirling in a gag, so an undo or a reset can stop it.
var _whirl := -1
var _love_mesh: ArrayMesh
var _bfly_wing: ArrayMesh
var _bfly_body: ArrayMesh
var _kite_mesh: ArrayMesh
var _bow_mesh: ArrayMesh
var _seal_mesh: ArrayMesh
var _party_at := INF
var _stamp_at := INF
var _untie_at := INF
var _cat: Control
var _cat_at := INF
var _cat_curled := false

func puzzle_id() -> String: return "pinwheel"
func title() -> String: return "Pinwheel"

## What a piece and a tap are, then the band's own closing: nothing can be
## lost (Easy to Hard), or the ribbons and the move counter (Insane). The
## hearts' line is asleep with the hearts.
func rules() -> String:
	var out := tr("PW_RULES")
	if _state.ribboned():
		out += "\n\n" + tr("PW_RULES_RIBBONS_MOVES")
	elif max_hearts > 0:
		out += "\n\n" + tr("PW_RULES_HEARTS") % max_hearts
	elif max_moves <= 0:
		out += "\n\n" + tr("PW_RULES_SAFE")
	if max_moves > 0:
		out += "\n\n" + tr("RULES_MOVES_SEQ") % max_moves
	return out

## The tutorial, a page a rule, each played on a little frame of its own
## (`ui/hud/pinwheel_tutorial_diagram.gd`): a tap turns a piece a quarter
## round its pin, the frame is done with every square covered once, what a
## turn of a piece already home costs on a judged band, Ribbons' tugs, Undo
## and Reset, and the bulb on a band that has hints.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/pinwheel_tutorial_diagram.gd")
	var band: int = _state.difficulty
	var hints: int = State.hints_for(band)
	var hearts_n: int = State.hearts_for(band)
	var judged := hearts_n > 0
	var steps := [
		[Diagram.Lesson.TURN, "HTP_PW_TURN", tr("HTP_PW_TURN_BODY")],
		[Diagram.Lesson.DONE, "HTP_PW_DONE", tr("HTP_PW_DONE_BODY")],
	]
	if judged:
		steps.append([Diagram.Lesson.HEARTS, "HTP_TN_HEARTS", tr("PW_RULES_HEARTS") % hearts_n])
	if band == 3:
		steps.append([Diagram.Lesson.RIBBONS, "PW_RIBBONS_SEAL", tr("HTP_PW_RIBBONS_BODY")])
	var undo_body := "HTP_PW_UNDO_BODY"
	if band == 3:
		undo_body = "HTP_PW_RESET_BODY_MOVES" if max_moves > 0 else "HTP_PW_RESET_BODY"
	elif judged:
		undo_body = "HTP_PW_UNDO_BODY_JUDGED"
	steps.append([Diagram.Lesson.UNDO, "HTP_WT_UNDO", tr(undo_body)])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_PW_HINT_BODY_ONE") if hints == 1 else tr("HTP_PW_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = band
		d.hearts = hearts_n
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	if max_moves > 0:
		pages.append(MovesDiagram.page(self, max_moves, true))
	return pages

## The lines the tips cycle, by band.
func _tips() -> Array:
	if _state.ribboned():
		return TIPS_RIBBONS
	if max_hearts > 0:
		return TIPS_HEARTS
	return TIPS

## Undo and Hint, and nothing else. There is no Check because nothing is
## hidden: a bare cell is drawn bare and a stained cell is drawn stained. So
## the registry drops the actions row and Reset rides up into the top bar.
## Insane counts moves and has neither (either would say what was wrong).
func capabilities() -> Array[String]:
	if _state.difficulty >= 3:
		return []
	return ["undo", "hint"]

## What the phone does under each cue (docs/agents/haptics.md). A piece
## turned taps, the one gesture there is (`place`; what its ribbons tug round
## with it is the same move and says nothing). A piece already home tapped on
## Hard and Insane does not turn and does not tap: its one knock is the heart,
## as the thread catches (`snag` is not mapped). A wheel pressed, a piece
## that will not turn (`refused`), a square that is no pin, the gold button
## sewn on (`tack`), the streak's notes, the gags and the party say nothing.
## The seal thuds as it lands (`_party`).
const HAPTICS := {
	"place": Haptics.TAP,
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
	"confetti": Haptics.BUMP,
	"hint": Haptics.GOOD,
	"heart_back": Haptics.GOOD,
	"heart_lost": Haptics.BAD,
	"out_of_hearts": Haptics.LOSE,
	"solved": Haptics.WIN,
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	fx.haptics = HAPTICS
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
	# The rewards over everything on the card: love hearts, the butterfly,
	# the kite, the bubble and the seal.
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
	_state.setup(rng, difficulty)
	max_moves = _state.moves_budget()
	_dealt()

## Everything a new frame starts from once the state holds it: the hearts,
## the rewards, nothing in flight, the shapes traced, the layout and the
## entrance. The tutorial's pages deal their frames by hand and call it too.
func _dealt() -> void:
	max_hearts = State.hearts_for(_state.difficulty) if _state.judged else 0
	_heart_used = false
	_lost_ever = false
	_undo_ever = false
	_flawless = false
	_tack_at = {}
	_tug_at = {}
	_deal()
	_reset_rewards()
	_swing = {}
	_wob = {}
	_refused = {}
	_pending = []
	_gust = {}
	_landed = {}
	_next_gust = 0.0
	_gust_rng.randomize()
	_pressed = Vector2i(-1, -1)
	_anim_until = 0.0
	_solved_at = -INF
	_last_turned = 0
	_turned_at = PackedFloat32Array()
	_turned_at.resize(_state.shapes.size())
	_shape_cache()
	_ref_cell = 0.0
	_layout()
	_enter()
	# The opening stain arrives **with the pieces that make it**, not before
	# them: a piece's landing moment starts as the moment its entrance pop
	# finishes, so the wash and its hatch fan out of the pins as the frame
	# fills rather than lying on bare ground waiting for pieces to appear.
	# The mock draws it from the first frame and reads as a ghost for it.
	for p in _state.shapes.size():
		_turned_at[p] = _opened + Motion.ENTER_DELAY \
			+ Motion.stagger(p, Motion.ENTER_STAGGER) + Motion.POP_IN
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()

## The frame as it is dealt, and as Try again deals it back: every heart,
## the whole move budget, the day's light, nothing snagging.
func _deal() -> void:
	hearts = max_hearts
	moves_left = max_moves
	out_of_hearts = false
	_asleep = false
	_split_index = -1
	_split_at = AGO
	_back_index = -1
	_back_at = AGO
	_busy_until = 0.0
	_press_piece = -1
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	if _heart_layer != null:
		_heart_layer.queue_redraw()

## Every piece's silhouette in every way it can lie, traced once, plus which
## quarter turn off the grown shape each of those is. A piece has at most
## four orientations because the pin will not let it translate, so the whole
## cache is at most four loops a piece -- the alternative is tracing a
## boundary per piece on every frame of a swing.
func _shape_cache() -> void:
	_loops = []
	_quarter = []
	_insets = []
	_cw = []
	_ccw = []
	for p in _state.shapes.size():
		var list: Array = _state.shapes[p]
		var pin := _state.pin_cell(p)
		var loops: Array = []
		var quarters: Array = []
		var insets: Array = []
		for o in list.size():
			loops.append(Cloth.loops(list[o]))
			quarters.append(_quarter_of(list[0], list[o], pin))
			insets.append(Cloth.inset_loops(list[o]))
		_loops.append(loops)
		_quarter.append(quarters)
		_insets.append(insets)
		var cw: Array = []
		var ccw: Array = []
		for a in list.size():
			var row_cw: Array = []
			var row_ccw: Array = []
			for b in list.size():
				row_cw.append(_travel(list[a], list[b], pin, 1))
				row_ccw.append(_travel(list[a], list[b], pin, -1))
			cw.append(row_cw)
			ccw.append(row_ccw)
		_cw.append(cw)
		_ccw.append(ccw)
	# The far corner of the frame from the nearest pin is the longest any
	# stain wave can run; one number, asked once.
	_wave_span = float(maxi(_state.cols, _state.rows)) * Motion.WAVE_STEP + STAIN_POP

## Which quarter turn about `pin` carries `base` onto `want`. A symmetric
## piece matches on more than one; the first is taken, because the pinwheel
## only has to look as though it is lying the way its piece is.
func _quarter_of(base: Array, want: Array, pin: Vector2i) -> int:
	var key := _cell_key(want)
	for q in 4:
		if _cell_key(_rotated(base, pin, q)) == key:
			return q
	return 0

## The fewest quarter turns `way` round (1 clockwise, -1 anticlockwise) that
## carry `from` onto `to` about `pin`; 0 when they are the same picture.
func _travel(from: Array, to: Array, pin: Vector2i, way: int) -> int:
	var key := _cell_key(to)
	if _cell_key(from) == key:
		return 0
	for k in range(1, 4):
		if _cell_key(_rotated(from, pin, k * way)) == key:
			return k
	return 1

func _rotated(cells: Array, pin: Vector2i, quarters: int) -> Array:
	var out: Array = []
	for c: Vector2i in cells:
		var d := c - pin
		for _i in posmod(quarters, 4):
			d = Vector2i(-d.y, d.x)
		out.append(pin + d)
	return out

func _cell_key(cells: Array) -> String:
	var ids: Array = []
	for c: Vector2i in cells:
		ids.append("%d,%d" % [c.x, c.y])
	ids.sort()
	return ";".join(ids)

# --- layout ---

## The cell, bound by whichever of the card's two sides runs out first. The
## frame's border is drawn outside it and takes its 18 out of the inset, so
## the cell itself is the spec's measured one: 188 on band 0, 183 on band 1
## and 157 on band 2.
##
## On Hard and Insane the hearts' strip comes off the top first (HEART_ROW),
## and the frame is centred in what is left under it.
func _cell() -> float:
	if _in_ref:
		return _ref_cell
	if _state.cols <= 0 or _state.rows <= 0:
		return 0.0
	return minf((size.x - 2.0 * INSET) / float(_state.cols),
		(size.y - _heart_row() - 2.0 * INSET) / float(_state.rows))

## The strip the pill takes over the frame: the hearts on a band that has
## them, the move counter on Insane.
func _heart_row() -> float:
	return HEART_ROW if max_hearts > 0 or max_moves > 0 else 0.0

## The top-left of the grid, centred in the card both ways (under the
## hearts' strip when there is one).
func _origin() -> Vector2:
	if _in_ref:
		return _ref_origin
	var cell := _cell()
	var row := _heart_row()
	return Vector2((size.x - float(_state.cols) * cell) * 0.5,
		row + (size.y - row - float(_state.rows) * cell) * 0.5)

## The reference layout's space onto the layout the card has now.
func _relay() -> Transform2D:
	var k := _cell() / _ref_cell
	return Transform2D(0.0, Vector2(k, k), 0.0, _origin() - _ref_origin * k)

## Takes the layout as the reference when there is none or the card has
## grown past it (a look made small would blur drawn large), and starts the
## looks again.
func _take_ref() -> void:
	var cell := _cell()
	if cell <= 0.0 or (_ref_cell > 0.0 and cell <= _ref_cell + 0.5):
		return
	_ref_cell = cell
	_ref_origin = _origin()
	_reset_looks()
	_prime_looks()

func _reset_looks() -> void:
	_rm_still = RunMesh.new(_look)
	_rm_top = RunMesh.new(_look)
	_rm_stain = RunMesh.new(_look)
	_rm_rib = RunMesh.new(_look)
	_rm_wheel = RunMesh.new(_look)
	for rm: RunMesh in [_rm_top, _rm_stain, _rm_rib, _rm_wheel]:
		rm.share_shapes(_rm_still)
	_still_plan = []
	_still_built = false
	_stain_plan = null
	_rib_plan = null
	_wheel_plan = null
	_stain_ids = {}
	_dirty = true

## Makes every look the board can need while it opens -- every piece's
## parts in every orientation, the wheels in their cloths, the tack and the
## button, every ribbon -- so a first turn mid-game copies and makes
## nothing.
func _prime_looks() -> void:
	if _rm_still == null or _ref_cell <= 0.0:
		return
	_in_ref = true
	for p in _state.shapes.size():
		for o in (_state.shapes[p] as Array).size():
			var n: int = p * 4 + o
			for k in [K_SIL, K_PRINT, K_TRIM]:
				_rm_still.shape(k + n)
		_rm_still.shape(K_WHEEL + int(_state.cloth[p]))
	for k in [K_WSHADOW, K_TACK, K_BUTTON]:
		_rm_still.shape(k)
	for i in _state.ribbons.size():
		_rm_still.shape(K_RIBBON + i)
	_in_ref = false

func _grid_centre() -> Vector2:
	var cell := _cell()
	return _origin() + Vector2(float(_state.cols), float(_state.rows)) * cell * 0.5

## The middle of a cell, in board pixels.
func cell_to_local(c: int, r: int) -> Vector2:
	return _origin() + (Vector2(float(c), float(r)) + Vector2(0.5, 0.5)) * _cell()

## The pin of piece `p`, in board pixels.
func _pin_point(p: int) -> Vector2:
	var pin := _state.pin_cell(p)
	return cell_to_local(pin.x, pin.y)

## The cell under a local point, or (-1, -1) off the frame. **Never pack a
## cell as `row * cols + column` here**: Quilt shipped that and a hold one
## cell off the left edge wrapped onto the far right, 2,386 of them coming
## back legal across 120 boards. The column is bounds-checked before
## anything is packed, and `State.idx()` checks it again.
func _cell_at(local: Vector2) -> Vector2i:
	var cell := _cell()
	if cell <= 0.0:
		return Vector2i(-1, -1)
	var at := local - _origin()
	var c := int(floor(at.x / cell))
	var r := int(floor(at.y / cell))
	if c < 0 or r < 0 or c >= _state.cols or r >= _state.rows:
		return Vector2i(-1, -1)
	return Vector2i(c, r)

## The card takes the whole slot it is given, so there is no slack for the
## host to place.
func card_height(available: float) -> float:
	return available

## True, and the answer does nothing on this phone -- Hidden Word's
## precedent. `card_height()` hands every pixel back, so the slack the host
## would halve is zero; the frame is centred *inside* the card instead. It
## says true because on a squarer screen the width would bind and the host's
## half would be the right place for the leftover.
func card_centred() -> bool:
	return true

func _layout() -> void:
	_frame_mesh = null
	_love_mesh = null
	_bfly_wing = null
	_bfly_body = null
	_kite_mesh = null
	_bow_mesh = null
	_seal_mesh = null
	_combo_shown = null
	_take_ref()
	if is_instance_valid(_cat):
		_place_cat(_now())
	if _life_layer != null:
		_life_layer.queue_redraw()
	if _heart_layer != null:
		_heart_layer.queue_redraw()
	_refresh()

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.shapes.is_empty():
		return
	var t := _now()
	# A snag ending lets go of the HUD: it greyed Undo, Hint and Reset.
	var b := busy()
	if _was_busy and not b:
		moved.emit()
	_was_busy = b
	# A swing that has just ended changes the draw order -- the piece drops
	# out of `_live` and back into index order -- so the frame it ends on has
	# to be redrawn even if nothing else on the card is moving.
	var settled := _retire(t)
	settled = _breeze(t) or settled
	_fire_pending(t)
	if settled or _animating(t):
		_refresh()
	if _tick_life(t):
		_life_layer.queue_redraw()
	if t >= _cat_at and not _cat_curled:
		_place_cat(t)
	if max_hearts > 0 and (t - _split_at < SPLIT_TIME + 0.1 or t - _back_at < HEART_BACK_TIME + 0.1 \
			or t - _opened < Motion.ENTER_DELAY + Motion.POP_IN + 0.1):
		_heart_layer.queue_redraw()
	elif max_moves > 0 and _moves_pill.animating(t - 0.1):
		_heart_layer.queue_redraw()

## Every ring and sparkle whose moment has come.
func _fire_pending(t: float) -> void:
	if _pending.is_empty():
		return
	var keep: Array = []
	for e: Dictionary in _pending:
		if t < float(e["at"]):
			keep.append(e)
			continue
		if bool(e.get("puff", false)):
			fx.puff(e["point"], e["colour"], 4)
			continue
		if bool(e["ring"]):
			fx.ring(e["point"], _cell() * RING_R, e["colour"])
		fx.sparkle(e["point"], e["colour"])
		_busy_for(Motion.RING_TIME)
	_pending = keep

## Queues one sparkle, and optionally a ring, on a local point `after`
## seconds from now. Nothing at all under reduce-motion: ui/fx2d.gd already
## draws neither, so this only spares the board the frames it would spend
## waiting for them.
func _fx_at(point: Vector2, colour: Color, after := 0.0, ring := true) -> void:
	if Motion.reduce:
		return
	_pending.append({"at": _now() + after, "point": point, "colour": colour, "ring": ring})
	_busy_for(after + Motion.RING_TIME)

## The idle breeze: retires the gusts that have blown out, and sets a new one
## off on a pinwheel that can turn once the last is due. Nothing under
## reduce-motion, before the frame has filled, or once the board is done
## (the win's own gust is set off by `_on_solved`). True when a gust ended,
## so the frame it ends on is drawn.
func _breeze(t: float) -> bool:
	var gone := false
	for p in _gust.keys():
		var g: Dictionary = _gust[p]
		if t - float(g["at"]) >= float(g["time"]):
			_gust.erase(p)
			gone = true
	if Motion.reduce or _done or out_of_hearts or t < _next_gust:
		return gone
	if _next_gust <= 0.0:
		_next_gust = t + GUST_EVERY + _gust_rng.randf() * GUST_JITTER
		return gone
	var can: Array = []
	for p in _state.shapes.size():
		if not _state.fixed(p) and not _state.is_tacked(p) and not _swing.has(p) \
				and not _gust.has(p):
			can.append(p)
	if not can.is_empty():
		var p: int = can[_gust_rng.randi() % can.size()]
		_gust[p] = {"at": t, "turn": GUST_TURN, "time": GUST_TIME}
	_next_gust = t + GUST_EVERY + _gust_rng.randf() * GUST_JITTER
	return gone

## How far a gust has spun piece `p`'s blades: fast as it hits, coasting to
## a stop on the turn.
func _gusted(p: int, t: float) -> float:
	if not _gust.has(p):
		return 0.0
	var g: Dictionary = _gust[p]
	var u := clampf((t - float(g["at"])) / float(g["time"]), 0.0, 1.0)
	return float(g["turn"]) * (1.0 - pow(1.0 - u, 3.0))

## A swing that has settled -- blades and all -- stops being a swing;
## otherwise `_animating` would have to keep asking about it for ever. The
## landing moment is kept in `_turned_at`, which the stain reads long after
## the piece has stopped moving.
func _retire(t: float) -> bool:
	if _swing.is_empty():
		return false
	var gone := false
	for p in _swing.keys():
		var a: Dictionary = _swing[p]
		if t - float(a["at"]) >= _swing_end(a):
			_swing.erase(p)
			gone = true
	return gone

## When swing `a` is over, blades and all.
func _swing_end(a: Dictionary) -> float:
	if a.has("snag"):
		return SNAG_TIME * HUB_FACTOR
	return _hub_time(int(a["quarters"]))

## Whether anything on this card is still moving, asked wave by wave rather
## than by one deadline. **Every** wave has to be in here -- the entrance,
## the swing and its blades, the stain settling behind it, the refusal and
## the solve hop: One Line shipped two lines frozen at four fifths of a fade
## because one was left out, and it showed in a rendered frame and in no
## test.
func _animating(t: float) -> bool:
	if not _pending.is_empty():
		return true
	if t < _anim_until:
		return true
	if Motion.reduce:
		return false
	# The entrance: the frame's wide pop, then the pieces popping in.
	var entrance := Motion.ENTER_DELAY + Motion.ENTER_POP \
		+ Motion.stagger(maxi(_state.shapes.size() - 1, 0), Motion.ENTER_STAGGER) + Motion.POP_IN
	if t - _opened < entrance:
		return true
	if not _swing.is_empty() or not _gust.is_empty():
		return true
	for p in _landed:
		if t - float(_landed[p]) < Motion.BUMP_TIME:
			return true
	# The stain fans out of a pin *after* the piece that moved has landed.
	for p in _turned_at.size():
		if t - float(_turned_at[p]) < _wave_span:
			return true
	for p in _wob:
		if t - float(_wob[p]) < WOB_TIME:
			return true
	for p in _tack_at:
		if t - float(_tack_at[p]) < BUTTON_POP + 0.05:
			return true
	for i in _tug_at:
		if t - float(_tug_at[i]) < TUG_TIME:
			return true
	if _press_piece >= 0 or (_press_up >= 0.0 and t - _press_up < Motion.RELEASE_TIME):
		return true
	if t >= _untie_at and t - _untie_at < UNTIE_TIME + 0.1:
		return true
	if not _refused.is_empty():
		var since := t - float(_refused["at"])
		if since < maxf(Motion.FLASH_IN + Motion.FLASH_OUT, Motion.SHIVER_TIME):
			return true
	if _solved_at > -INF and t - _solved_at < Motion.SOLVE_DELAY + _solve_span() + Motion.SOLVE_TIME:
		return true
	return false

## How long the solve wave takes to cross the frame: the far pin's delay.
func _solve_span() -> float:
	if Motion.reduce:
		return 0.0
	return float(maxi(_state.cols, _state.rows)) * Motion.WAVE_STEP

## How long a swing of `quarters` quarters runs. Nothing at all under
## reduce-motion, so the piece is already home and the stain lands with it.
func _swing_time(quarters: int) -> float:
	if Motion.reduce:
		return 0.0
	var n := absi(quarters)
	if n <= 1:
		return Motion.TURN_TIME
	return Motion.TURN_TIME * (1.0 + SWING_EXTRA * float(n - 1))

func _hub_time(quarters: int) -> float:
	return _swing_time(quarters) * HUB_FACTOR

## Keeps the card redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Drops the meshes so the next _draw rebuilds them, and asks for that draw.
## What the last _draw handed over is still held by _shown, so the renderer
## is never left pointing at a freed RID.
func _refresh() -> void:
	_dirty = true
	queue_redraw()

# --- where each piece is, this frame ---

## How far piece `p` still has to swing, in radians: zero once it has
## settled. The piece is already drawn in the orientation it has turned *to*,
## so this is the residual that starts it back where it came from --
## `Motion.turn_angle` less the full angle, which is the vocabulary's reader
## read backwards rather than a second curve.
func _swung(p: int, t: float, time_scale := 1.0) -> float:
	if not _swing.has(p):
		return 0.0
	var a: Dictionary = _swing[p]
	if a.has("snag"):
		return _snag_angle((t - float(a["at"])) / time_scale) * (1.0 + 0.4 * (time_scale - 1.0))
	var q := int(a["quarters"])
	var full := float(q) * PI * 0.5
	return Motion.turn_angle(t - float(a["at"]), q, _swing_time(q) * time_scale) - full

## Everything the drawing needs to know about one piece this frame: its pop,
## how far round it still is, where the shiver and the solve hop have moved
## it, and how warm its edge has gone.
func _frame_of(p: int, t: float) -> Dictionary:
	var sc := Motion.pop_in_scale(t - _opened - Motion.ENTER_DELAY
		- Motion.stagger(p, Motion.ENTER_STAGGER))
	var offset := Vector2.ZERO
	if not _refused.is_empty() and int(_refused["piece"]) == p:
		offset.x += Motion.shiver_offset(t - float(_refused["at"]))
	var warm := 0.0
	if _solved_at > -INF:
		var at := _solved_at + _solve_delay(p)
		offset.y += Motion.hop_lift(t - at, Motion.SOLVE_HOP, Motion.SOLVE_TIME)
		warm = 1.0 if Motion.reduce else clampf((t - at) / WARM_TIME, 0.0, 1.0)
	var lift := _lift(p, t)
	var grow := 1.0 + LIFT_GROW * lift
	if _landed.has(p):
		grow *= 2.0 - Motion.bump_scale(t - float(_landed[p]), LAND_SQUASH)
	return {"sc": sc * grow, "angle": _swung(p, t), "offset": offset, "warm": warm,
		"lift": lift}

## How far piece `p` is lifted off the frame, 0 to 1: up over the first fifth
## of its swing, held while it turns, and down over the last quarter, so it
## lands as the turn settles onto the quarter.
func _lift(p: int, t: float) -> float:
	if not _swing.has(p):
		return 0.0
	var a: Dictionary = _swing[p]
	var u := (t - float(a["at"])) / maxf(_swing_len(a), 0.001)
	if u <= 0.0 or u >= 1.0:
		return 0.0
	return smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.75, 1.0, u))

## When the solve wave reaches piece `p`: the delay, then a king move a cell
## out from the pin of the piece that finished the board.
func _solve_delay(p: int) -> float:
	if Motion.reduce:
		return 0.0
	var a := _state.pin_cell(p)
	var b := _state.pin_cell(_last_turned)
	var k := maxi(absi(a.x - b.x), absi(a.y - b.y))
	return Motion.SOLVE_DELAY + float(k) * Motion.WAVE_STEP

# --- the drawing ---

## The ground first, then every piece that is standing still, then everything
## that is moving: the swinging pieces over their neighbours, the stain over
## all of them, and the pinwheels over the lot. The whole group pops in wide
## about the grid's centre while it fades (rule 7: a wide thing comes from
## most of the way).
func _draw() -> void:
	if _state.shapes.is_empty() or _cell() <= 0.0:
		_shown = []
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		_shown = []
		return
	var grow := Motion.wide_pop_scale(since)
	var mid := _grid_centre()
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var tint := Color(1.0, 1.0, 1.0, seen)
	var shown: Array = []
	if _frame_mesh == null:
		_frame_mesh = _build_frame()
	if _frame_mesh != null:
		draw_mesh(_frame_mesh, null, xf, tint)
		shown.append(_frame_mesh)
	if _ref_cell <= 0.0:
		_take_ref()
	if _rm_still == null:
		_reset_looks()
	if _dirty:
		_dirty = false
		if _stain_ids.size() > STAINS_MAX:
			_reset_looks()
			_dirty = false
		_in_ref = true
		_still = _build_still(t)
		_live = _build_live(t)
		_stain_mesh = _build_stain(t)
		_rib_mesh = _build_ribbons(t)
		_wheel_mesh = _build_wheels(t)
		_in_ref = false
	var on := xf * _relay()
	for m: ArrayMesh in [_still, _live, _stain_mesh, _rib_mesh, _wheel_mesh]:
		if m != null:
			draw_mesh(m, null, on, tint)
			shown.append(m)
	_shown = shown

## The ground: one panel of Shikaku's unclaimed plot behind the grid, the
## faint rules between its cells, and a rim round the lot. It carries no
## clock at all, so it is built once a layout and not once a frame.
func _build_frame() -> ArrayMesh:
	var b := Face.Builder.new()
	var cell := _cell()
	var at := _origin() - Vector2.ONE * FRAME_PAD
	var box := Vector2(float(_state.cols), float(_state.rows)) * cell + Vector2.ONE * (2.0 * FRAME_PAD)
	var panel := Face.Builder.round_rect(at, box, FRAME_RADIUS)
	b.polygon(panel, Pal.QUILT_BACK)
	var rule := Pal.QUILT_RULE
	var w := maxf(2.0, cell * RULE_W)
	for c in range(1, _state.cols):
		var x := _origin().x + float(c) * cell
		b.stroke(PackedVector2Array([Vector2(x, _origin().y),
			Vector2(x, _origin().y + float(_state.rows) * cell)]), w, rule, false, false)
	for r in range(1, _state.rows):
		var y := _origin().y + float(r) * cell
		b.stroke(PackedVector2Array([Vector2(_origin().x, y),
			Vector2(_origin().x + float(_state.cols) * cell, y)]), w, rule, false, false)
	var o := _origin()
	var puff := Color(Pal.SURFACE, PUFF_ALPHA)
	for r in _state.rows:
		for c in _state.cols:
			b.polygon(Face.Builder.round_rect(o + (Vector2(c, r) + Vector2.ONE * PUFF_INSET) * cell,
				Vector2.ONE * (1.0 - 2.0 * PUFF_INSET) * cell, PUFF_R * cell), puff)
	var tie := Color(Pal.LINE, 0.85)
	var d := TIE_LEN * cell
	for r in range(1, _state.rows):
		for c in range(1, _state.cols):
			var at2 := o + Vector2(c, r) * cell
			b.stroke(PackedVector2Array([at2 + Vector2(-d, -d), at2 + Vector2(d, d)]), TIE_W * cell, tie)
			b.stroke(PackedVector2Array([at2 + Vector2(d, -d), at2 + Vector2(-d, d)]), TIE_W * cell, tie)
	b.stroke(panel, FRAME_RIM, Pal.LINE, true)
	return _mesh(b)

## Every piece that is not swinging, in index order: each its look under
## its transform, handed back while the plan is the one it was built from.
func _build_still(t: float) -> ArrayMesh:
	var plan: Array = []
	for p in _state.shapes.size():
		if _lifted(p, t):
			continue
		var e := _plan_of(p, _frame_of(p, t))
		if not e.is_empty():
			plan.append(e)
	if _still_built and plan == _still_plan:
		return _still
	_still_plan = plan
	_still_built = true
	_rm_still.begin()
	for e: Array in plan:
		_put_piece(_rm_still, e)
	return _rm_still.mesh()

## Whether piece `p` is off the pile this frame: it is lifted **only while
## its cloth is actually turning**, and not for the extra moment its blades
## keep spinning. Dropping it back into index order is a visible change of
## which neighbour is on top, so it happens on the frame the piece lands --
## the same frame the stain arrives on the cells it has taken, which is
## where the eye already is -- rather than a sixth of a second later with
## nothing else moving to explain it.
func _lifted(p: int, t: float) -> bool:
	if not _swing.has(p):
		return false
	var a: Dictionary = _swing[p]
	return t - float(a["at"]) < _swing_len(a)

## How long swing `a`'s cloth moves (a snag's whole catch and spring).
func _swing_len(a: Dictionary) -> float:
	if a.has("snag"):
		return SNAG_TIME
	return _swing_time(int(a["quarters"]))

## The snag's angle off home, `e` seconds after the tap: out to SNAG_ANGLE,
## straining there with a tremble, then home with the back ease's overshoot
## (a little way past home and back, as cloth on a thread would).
func _snag_angle(e: float) -> float:
	if Motion.reduce or e <= 0.0 or e >= SNAG_TIME:
		return 0.0
	if e < SNAG_OUT:
		return SNAG_ANGLE * sin(e / SNAG_OUT * PI * 0.5)
	if e < SNAG_OUT + SNAG_HOLD:
		return SNAG_ANGLE + 0.03 * sin((e - SNAG_OUT) * 70.0)
	var u := (e - SNAG_OUT - SNAG_HOLD) / (SNAG_TIME - SNAG_OUT - SNAG_HOLD)
	return SNAG_ANGLE * (1.0 - Motion.back_out(u))

## Everything that is moving, in the one order that works: a swinging piece
## has to draw over the neighbours it is turning across, the stain has to
## draw over every piece or it says nothing, and a pinwheel is the handle and
## draws over all of it.
func _build_live(t: float) -> ArrayMesh:
	_rm_top.begin()
	for p in _state.shapes.size():
		if not _lifted(p, t):
			continue
		var e := _plan_of(p, _frame_of(p, t))
		if not e.is_empty():
			_put_piece(_rm_top, e)
	return _rm_top.mesh()

## A builder's mesh, or null when it has nothing in it. Asking an empty
## builder for a mesh is an engine error ("array_len == 0"), and the live
## mesh is empty on any frame with nothing swinging, no stain and the
## entrance still scaling every pinwheel up from nothing.
func _mesh(b) -> ArrayMesh:
	return b.mesh() if not b.verts.is_empty() else null

## Where piece `p` is laid this frame: the frame's origin moved by the
## shiver and the hop, and the span handed to `Cloth.place` -- `2 * pin + 1`,
## whose middle is exactly the pin's own centre -- so the pop, the lift and
## the swing's turn all happen about the pin and not about the piece's
## bounding box. Every part of a piece (its shadow, cloth, print, quilting
## and edge) goes through `Cloth.place` with these, so none can be left
## behind by a swing. A piece of five cells cannot enclose a hole -- it takes
## eight -- so every loop off `Cloth.loops` here is an outer one.
func _span(p: int) -> Vector2i:
	var pin := _state.pin_cell(p)
	return Vector2i(pin.x * 2 + 1, pin.y * 2 + 1)

## Piece `p` this frame as the still mesh's plan has it: [piece,
## orientation, transform, warmth, lift, halo, scale, turn, offset], or []
## while it is popped down to nothing. The transform carries its look (made
## at rest about the frame's origin) to where `Cloth.place` would lay it:
## squashed and turned about its pin, moved by the shiver and the hop. The
## warmth is cut to 32 steps, so a resting piece's plan stays equal.
func _plan_of(p: int, f: Dictionary) -> Array:
	var sc: Vector2 = f["sc"]
	if sc.x <= 0.0 or sc.y <= 0.0:
		return []
	var rot := float(f["angle"])
	var offset: Vector2 = f["offset"]
	var xf := Transform2D(rot, sc, 0.0, Vector2.ZERO)
	var pin := _pin_point(p)
	xf.origin = pin + offset - xf * pin
	var halo := 0.0
	if not _refused.is_empty() and int(_refused["piece"]) == p:
		halo = Motion.flash_level(_now() - float(_refused["at"]))
	return [p, int(_state.turned[p]), xf, roundf(float(f["warm"]) * 32.0) / 32.0,
		float(f["lift"]), halo, sc, rot, offset]

## One piece: its shadow, its cloth over its own lip, the cloth's print, the
## quilting stitch inside its edge, a solid edge round it, and the rose halo
## if it has just been refused. The shadow, the lip and the cloth are one
## silhouette painted three ways; the stitch and the edge one trim painted
## in the thread and the edge, which warm with the solve.
func _put_piece(rm: RunMesh, e: Array) -> void:
	var p: int = e[0]
	var n: int = p * 4 + int(e[1])
	var xf: Transform2D = e[2]
	var warm: float = e[3]
	var lift: float = e[4]
	var cell := _cell()
	var ci := int(_state.cloth[p])
	var edge := Cloth.cloth_stitch(ci)
	var thread := Cloth.cloth_thread(ci)
	if warm > 0.0:
		edge = edge.lerp(Pal.SUN_RAY, warm * WARM_MIX)
		thread = thread.lerp(Pal.SUN_RAY, warm * WARM_MIX)
	var by := REST_SHADOW.lerp(LIFT_SHADOW, lift) * cell
	var level := lerpf(REST_LEVEL, 1.0, lift)
	if level > 0.0 and by != Vector2.ZERO:
		rm.put(K_SIL + n, [Color(Pal.TEXT, Cloth.SHADOW_ALPHA * level)], Transform2D(0.0, by) * xf)
	rm.put(K_SIL + n, [Cloth.cloth_deep(ci)], Transform2D(0.0, Vector2(0.0, Cloth.EDGE * cell)) * xf)
	rm.put(K_SIL + n, [Cloth.cloth(ci)], xf)
	rm.put(K_PRINT + n, [], xf)
	rm.put(K_TRIM + n, [thread, edge], xf)
	_halo(rm, e)

## A piece that is being turned down wears a rose **halo** round its
## silhouette. It does not blush.
##
## **The cloth cannot blush**, and Quilt measured why: the eight cloths run
## right round the wheel, so at 0.30 toward `Pal.BAD` the teal drops to 0.07
## saturation and comes back dead grey, the sage comes back khaki and the sky
## mauve. A greyed piece reads as *disabled* rather than as refused, which on
## a piece that is genuinely pinned fast would be exactly the wrong word. So
## the halo is drawn beside the cloth and the cloth is left alone:
## `docs/art/flat-motion.md`'s rule 9 read for a piece that is its own shape.
func _halo(rm: RunMesh, e: Array) -> void:
	var level: float = e[5]
	if level <= 0.0:
		return
	var p: int = e[0]
	var cell := _cell()
	var b := Face.Builder.new()
	var pos: Vector2 = _origin() + (e[8] as Vector2)
	for loop: PackedVector2Array in (_loops[p] as Array)[int(e[1])]:
		b.stroke(Cloth.laid(loop, pos, cell, _span(p), e[6], e[7]), HALO_W * cell,
			Color(Pal.BAD, level), true)
	rm.put_builder(b)

## Look `id`, made once a reference layout about the frame's origin (a
## piece's parts) or about (0, 0) (a wheel, its shadow, the tack, the
## button), in slot colours where it is painted more than one way.
func _look(id: int) -> Face.Builder:
	var b := Face.Builder.new()
	var kind := id & ~K_LOW
	var n := id & K_LOW
	var cell := _cell()
	match kind:
		K_SIL, K_PRINT, K_TRIM:
			var p := n >> 2
			var o := n & 3
			var pos := _origin()
			var span := _span(p)
			var loops: Array = (_loops[p] as Array)[o]
			if kind == K_SIL:
				for loop: PackedVector2Array in loops:
					if Cloth._area(loop) > 0.0:
						b.polygon(Cloth.laid(loop, pos, cell, span), RunMesh.slot(0))
			elif kind == K_PRINT:
				Cloth.print_cloth(b, (_state.shapes[p] as Array)[o], int(_state.cloth[p]), pos, cell, span)
			else:
				for loop: PackedVector2Array in (_insets[p] as Array)[o]:
					Cloth.dash_loop(b, Cloth.laid(loop, pos, cell, span, Vector2.ONE, 0.0, Cloth.RADIUS * 0.6),
						Cloth.QUILT_W * cell, Cloth.QUILT_ON * cell, Cloth.QUILT_OFF * cell, RunMesh.slot(0))
				for loop: PackedVector2Array in loops:
					b.stroke(Cloth.laid(loop, pos, cell, span), EDGE_W * cell, RunMesh.slot(1), true)
		K_WHEEL:
			PinWheel.wheel(b, Vector2.ZERO, cell * PIN_R, 0.0, Pal.LINE, Pal.SURFACE, PinWheel.BRASS,
				Cloth.cloth_deep(n))
		K_WSHADOW:
			PinWheel.shadow(b, Vector2.ZERO, cell * PIN_R, Pal.TEXT)
		K_TACK:
			PinWheel.pin(b, Vector2.ZERO, cell * PIN_R, Pal.LINE)
		K_BUTTON:
			_button(b, Vector2.ZERO, cell * BUTTON_R)
		K_RIBBON:
			_ribbon(b, n, 0.0, true)
		K_STAIN:
			_stain(b, FAR)
	return b

## The stain's mesh: a look once every stained cell has arrived (one per set
## of stained cells, handed back while the set stands), drawn live while the
## wave is crossing.
func _build_stain(t: float) -> ArrayMesh:
	var occ := _owners()
	var key := PackedInt32Array()
	var settled := true
	for i in occ.size():
		var os: Array = occ[i]
		if os.size() > 1:
			key.append(i)
			if settled and _stain_level(t, _state.cell_of(i), os) < 1.0:
				settled = false
	var rm := _rm_stain
	if key.is_empty():
		_stain_plan = ""
		return null
	if not settled:
		_stain_plan = null
		var b := Face.Builder.new()
		_stain(b, t)
		return _mesh(b)
	var k := str(key)
	if k == _stain_plan:
		return _stain_mesh
	_stain_plan = k
	if not _stain_ids.has(k):
		_stain_ids[k] = K_STAIN + _stain_ids.size()
	rm.begin()
	rm.put(int(_stain_ids[k]), [], Transform2D.IDENTITY)
	return rm.mesh()

## The stain: every cell more than one piece is sitting on, washed and then
## hatched.
##
## **Derived and never stored.** A cell's moment is the *later* of its
## pieces' landings -- the moment that piece finished arriving, not the
## moment it was tapped -- fanned out from that piece's own pin by king-move
## distance. So undo, reset and a hint's three-quarter spin all settle
## correctly, and none of them leaves a wave behind to clean up.
##
## Cells are drawn one at a time and their rects never overlap: a corner is
## rounded only where the cell has no stained neighbour on either of its two
## sides, which merges a group into one outline without laying a second wash
## over the seam between two of them.
func _stain(b, t: float) -> void:
	var cell := _cell()
	var occ := _owners()
	var stained := {}
	for r in _state.rows:
		for c in _state.cols:
			var os: Array = occ[r * _state.cols + c]
			if os.size() > 1:
				stained[Vector2i(c, r)] = os
	if stained.is_empty():
		return
	var wash := Color(Pal.TEXT, STAIN_ALPHA)
	var ink := Color(Pal.TEXT, HATCH_ALPHA)
	var step := cell * HATCH_STEP
	# The hatch's phase comes off the grid, not off a cell, so two stained
	# cells side by side carry one unbroken line across the seam.
	var phase := _origin().x - _origin().y
	for at: Vector2i in stained:
		var k := _stain_level(t, at, stained[at])
		if k <= 0.0:
			continue
		var half := cell * k * 0.5
		var centre := cell_to_local(at.x, at.y)
		var x0 := centre.x - half
		var y0 := centre.y - half
		var x1 := centre.x + half
		var y1 := centre.y + half
		b.polygon(_stain_box(at, stained, Vector2(x0, y0), Vector2(x1, y1),
			minf(cell * STAIN_RADIUS, half)), wash)
		var j := int(ceil(((x0 - y1) - phase) / step))
		while true:
			var cc := phase + float(j) * step
			if cc > x1 - y0:
				break
			var lo := maxf(y0, x0 - cc)
			var hi := minf(y1, x1 - cc)
			if hi > lo:
				b.stroke(PackedVector2Array([Vector2(lo + cc, lo), Vector2(hi + cc, hi)]),
					maxf(3.0, cell * HATCH_W), ink, false, false)
			j += 1
	# One dashed outline round each contested region, over the cells the wave
	# has already reached: the hatch says "two pieces here" and the outline
	# says where that stops, without darkening a cloth to do it.
	var reached: Array = []
	for at: Vector2i in stained:
		if _stain_level(t, at, stained[at]) > 0.0:
			reached.append(at)
	if reached.is_empty():
		return
	var line := Color(Pal.TEXT, OUTLINE_ALPHA)
	for loop: PackedVector2Array in Cloth.loops(reached):
		Cloth.dash_loop(b, Cloth.laid(loop, _origin(), cell, Vector2i.ZERO, Vector2.ONE, 0.0,
			STAIN_RADIUS), OUTLINE_W * cell, OUTLINE_ON * cell, OUTLINE_OFF * cell, line)

## How far a stained cell has arrived: nothing before its moment, then from a
## third of its size to all of it with the back ease.
func _stain_level(t: float, at: Vector2i, owners: Array) -> float:
	if Motion.reduce:
		return 1.0
	var src := int(owners[0])
	for i: int in owners:
		if _turned_at[i] >= _turned_at[src]:
			src = i
	var pin := _state.pin_cell(src)
	var k := maxi(absi(at.x - pin.x), absi(at.y - pin.y))
	var u := (t - (float(_turned_at[src]) + float(k) * Motion.WAVE_STEP)) / STAIN_POP
	if u <= 0.0:
		return 0.0
	return lerpf(STAIN_FROM, 1.0, Motion.back_out(clampf(u, 0.0, 1.0)))

## One stained cell's box, with a corner rounded only where the cell has no
## stained neighbour on either of the two sides that meet there.
func _stain_box(at: Vector2i, stained: Dictionary, lo: Vector2, hi: Vector2, r: float) -> PackedVector2Array:
	var left := stained.has(at + Vector2i(-1, 0))
	var right := stained.has(at + Vector2i(1, 0))
	var up := stained.has(at + Vector2i(0, -1))
	var down := stained.has(at + Vector2i(0, 1))
	var out := PackedVector2Array()
	_corner(out, Vector2(lo.x + r, lo.y + r), Vector2(lo.x, lo.y), r, PI, PI * 1.5, left or up)
	_corner(out, Vector2(hi.x - r, lo.y + r), Vector2(hi.x, lo.y), r, PI * 1.5, TAU, right or up)
	_corner(out, Vector2(hi.x - r, hi.y - r), Vector2(hi.x, hi.y), r, 0.0, PI * 0.5, right or down)
	_corner(out, Vector2(lo.x + r, hi.y - r), Vector2(lo.x, hi.y), r, PI * 0.5, PI, left or down)
	return out

func _corner(out: PackedVector2Array, centre: Vector2, sharp: Vector2, r: float,
		from: float, to: float, square: bool) -> void:
	if square or r <= 0.5:
		out.append(sharp)
		return
	out.append_array(Face.Builder.arc_points(centre, r, from, to))

## Who is sitting on every cell, once a frame. Asking the state per cell
## would walk every piece per cell; this walks every piece once.
func _owners() -> Array:
	var occ: Array = []
	occ.resize(_state.cols * _state.rows)
	for i in occ.size():
		occ[i] = []
	for p in _state.shapes.size():
		for c: Vector2i in _state.cells_of(p):
			var i := _state.idx(c.x, c.y)
			if i >= 0:
				(occ[i] as Array).append(p)
	return occ

## Every pinwheel, over everything. A piece with nowhere to turn gets a plain
## pin instead of a wheel: **a pinwheel that does not turn is a lie**, and
## drawing the difference is cheaper than explaining it in the tip card after
## the tap.
##
## The blades read the same swing with a longer time, so they carry the
## overshoot the cloth does not, and they sit at the quarter their piece is
## lying at, so a settled wheel says which way round its piece is.
func _build_wheels(t: float) -> ArrayMesh:
	var cell := _cell()
	var r0 := cell * PIN_R
	# [look, transform] pairs: every wheel's shadow and wheel, then the
	# buttons, which come and go, after them all so they move no wheel's
	# place.
	var plan: Array = []
	var after: Array = []
	for p in _state.shapes.size():
		var f := _frame_of(p, t)
		var sc: Vector2 = f["sc"]
		if sc.x <= 0.0 or sc.y <= 0.0:
			continue
		# A wheel is a disc; the pop's squash on it is invisible at this size,
		# so it takes the scale that keeps its area rather than two axes it
		# cannot use.
		var r := cell * PIN_R * sqrt(sc.x * sc.y)
		var at := _pin_point(p) + (f["offset"] as Vector2)
		# A lifted piece carries its pinwheel up with it.
		r *= 1.0 + LIFT_GROW * float(f["lift"])
		# The wheel under a finger sinks, and springs as it lets go.
		if p == _press_piece or (p == _press_last and _press_up >= 0.0):
			var held := t - _press_down
			var up := (t - _press_up) if _press_up >= 0.0 else -1.0
			r *= lerpf(1.0, PRESS_DIP, (1.0 - Motion.press_scale(held, up)) / (1.0 - Motion.PRESS_SCALE))
		if r <= 0.0:
			continue
		# One look a part, under the wheel's own scale (and turn).
		var s := r / r0
		var place := Transform2D(0.0, Vector2(s, s), 0.0, at)
		plan.append(K_WSHADOW)
		plan.append(place)
		if _state.fixed(p):
			plan.append(K_TACK)
			plan.append(place)
			continue
		var rest := float((_quarter[p] as Array)[int(_state.turned[p])]) * PI * 0.5
		var wob := 0.0
		if _wob.has(p):
			wob = Motion.wobble_angle(t - float(_wob[p]), WOB_ANGLE, WOB_TIME)
		plan.append(K_WHEEL + int(_state.cloth[p]))
		plan.append(Transform2D(rest + _swung(p, t, HUB_FACTOR) + wob + _gusted(p, t),
			Vector2(s, s), 0.0, at))
		if _tack_at.has(p):
			var bs := Motion.pop_in_scale(t - float(_tack_at[p]), BUTTON_POP).x
			if cell * BUTTON_R * bs > 0.5:
				after.append(K_BUTTON)
				after.append(Transform2D(0.0, Vector2(bs, bs), 0.0, at + BUTTON_AT * cell))
	plan.append_array(after)
	if plan == _wheel_plan:
		return _wheel_mesh
	_wheel_plan = plan
	var rm := _rm_wheel
	rm.begin()
	for k in range(0, plan.size(), 2):
		rm.put(int(plan[k]), [], plan[k + 1])
	return rm.mesh()

## The gold button a sewn piece wears: brass, a darker rim, and a cross of
## rose thread through it. It says "home, and staying" without touching the
## piece's own colour (the board's rule: no state in a shade of the cloth).
func _button(b, at: Vector2, r: float) -> void:
	if r <= 0.5:
		return
	PinWheel.shadow(b, at, r * 1.3, Pal.TEXT)
	b.disc(at, r * 1.42, Pal.SURFACE)
	b.disc(at, r * 1.16, Pal.LINE)
	b.disc(at, r, PinWheel.BRASS)
	b.disc(at + Vector2(-0.3, -0.35) * r, r * 0.28, Color(1.0, 1.0, 1.0, 0.45))
	var d := r * 0.42
	var w := maxf(2.0, r * 0.26)
	b.stroke(PackedVector2Array([at + Vector2(-d, -d), at + Vector2(d, d)]), w, THREAD)
	b.stroke(PackedVector2Array([at + Vector2(d, -d), at + Vector2(-d, d)]), w, THREAD)

## Insane's ribbons, under the pinwheels and over everything else: a satin
## band from the pulling pin to the tied one, rose for the same way round
## and sky blue in an S for a crossed one, two chevrons pointing down it, a
## bow where it is tied on, and at the tied wheel a little curved arrow that
## says which way it will turn. A tug pulls it taut and lets it spring back;
## at the party they slip loose and float up out of the frame.
func _build_ribbons(t: float) -> ArrayMesh:
	if not _state.ribboned():
		return null
	var untie := 0.0
	if t >= _untie_at:
		untie = clampf((t - _untie_at) / UNTIE_TIME, 0.0, 1.0) if not Motion.reduce else 1.0
		if untie >= 1.0:
			return null
	# 1 lying still, 0 not seen, -1 drawn this frame.
	var plan := PackedInt32Array()
	plan.resize(_state.ribbons.size())
	for i in _state.ribbons.size():
		var rib: Dictionary = _state.ribbons[i]
		var seen := minf(_frame_of(int(rib["from"]), t)["sc"].x, _frame_of(int(rib["to"]), t)["sc"].x)
		if seen <= 0.05:
			plan[i] = 0
			continue
		var tugging := false
		if _tug_at.has(i):
			var e := t - float(_tug_at[i])
			tugging = e > 0.0 and e < TUG_TIME
		# A ribbon lying still is its look; a tugged, popping or loosening one
		# is drawn this frame.
		plan[i] = 1 if untie <= 0.0 and not tugging and is_equal_approx(seen, 1.0) else -1
	if plan == _rib_plan:
		return _rib_mesh
	_rib_plan = null if plan.has(-1) else plan
	# The ones lying still first, so their places stay put while others move.
	var rm := _rm_rib
	rm.begin()
	for i in plan.size():
		if plan[i] == 1:
			rm.put(K_RIBBON + i, [], Transform2D.IDENTITY)
	for i in plan.size():
		if plan[i] == -1:
			var b := Face.Builder.new()
			_ribbon(b, i, t, false)
			rm.put_builder(b)
	return rm.mesh()

## Ribbon `i` this frame, or (`rest`) lying still: no tug, no pop, tied on.
func _ribbon(b, i: int, t: float, rest: bool) -> void:
	var cell := _cell()
	var untie := 0.0
	if not rest and t >= _untie_at:
		untie = clampf((t - _untie_at) / UNTIE_TIME, 0.0, 1.0) if not Motion.reduce else 1.0
	var rib: Dictionary = _state.ribbons[i]
	var pa := int(rib["from"])
	var pb := int(rib["to"])
	var crossed := int(rib["sign"]) < 0
	var a := _pin_point(pa)
	var z := _pin_point(pb)
	var seen := 1.0 if rest else minf(_frame_of(pa, t)["sc"].x, _frame_of(pb, t)["sc"].x)
	var amp := RIBBON_BOW * a.distance_to(z)
	if not rest and _tug_at.has(i):
		var e := t - float(_tug_at[i])
		if e > 0.0 and e < TUG_TIME:
			var u := e / TUG_TIME
			# Taut in a flash, then a spring back past its rest and home.
			amp *= 1.0 - 0.9 * sin(minf(u * 3.0, 1.0) * PI * 0.5) * (1.0 - u) \
				+ 0.25 * sin(u * PI * 2.0) * u * (1.0 - u) * 4.0
	var lift := Vector2.ZERO
	var alpha := 1.0
	if untie > 0.0:
		amp *= 1.0 + 2.5 * untie
		lift = Vector2(sin(float(i) * 1.7) * 0.4, -1.6 - 0.3 * float(i % 3)) * cell * untie * untie
		alpha = 1.0 - untie * untie
	var line := _ribbon_line(a + lift, z + lift, amp, crossed, t + float(i) * 0.37, untie)
	var deep := SATIN_X_DEEP if crossed else SATIN_DEEP
	var satin := SATIN_X if crossed else SATIN
	deep.a = alpha * seen
	satin.a = alpha * seen
	b.stroke(line, RIBBON_W * cell, deep, false, true)
	b.stroke(line, RIBBON_W * cell * 0.62, satin, false, true)
	b.stroke(line, RIBBON_W * cell * 0.16, Color(1.0, 1.0, 1.0, 0.35 * alpha * seen), false, true)
	# Two chevrons down the ribbon, pointing at the piece it pulls.
	for k in [0.4, 0.6]:
		var idx := int(round(k * float(line.size() - 1)))
		var here: Vector2 = line[idx]
		var dir: Vector2 = (line[mini(idx + 1, line.size() - 1)] - line[maxi(idx - 1, 0)]).normalized()
		var side := dir.orthogonal()
		var c := cell * 0.06
		b.stroke(PackedVector2Array([here - dir * c + side * c, here + dir * c * 0.4,
			here - dir * c - side * c]), maxf(2.0, cell * 0.022), deep, false, true)
	if untie > 0.0:
		return
	# A knot where it is tied on, just off the pulling wheel.
	var away := (z - a).normalized()
	var knot := a + away * cell * (PIN_R + 0.06)
	b.disc(knot, cell * 0.055, deep)
	b.disc(knot, cell * 0.032, satin)
	# The tied wheel's arrow: a short arc round it on the side away from the
	# ribbon, its head clockwise or anticlockwise.
	var back := (a - z).angle() + PI
	var rr := cell * (PIN_R + 0.1)
	var sweep := 1.1
	var from_a := back - sweep * 0.5
	var to_a := back + sweep * 0.5
	var arc := Face.Builder.arc_points(z, rr, from_a, to_a)
	b.stroke(arc, maxf(2.0, cell * 0.03), deep, false, true)
	var head_at: Vector2 = arc[arc.size() - 1] if not crossed else arc[0]
	var head_ang := (to_a + PI * 0.5) if not crossed else (from_a - PI * 0.5)
	var hd := Vector2.from_angle(head_ang)
	var hs := cell * 0.06
	b.polygon(PackedVector2Array([head_at + hd * hs, head_at - hd * hs * 0.5 + hd.orthogonal() * hs * 0.8,
		head_at - hd * hs * 0.5 - hd.orthogonal() * hs * 0.8]), deep)

## A ribbon's centre line from `a` to `z`, bowed `amp` to one side (an S for
## a crossed one), with a slow flutter along it once it has slipped loose.
func _ribbon_line(a: Vector2, z: Vector2, amp: float, crossed: bool, phase: float,
		loose: float) -> PackedVector2Array:
	var n := (z - a).orthogonal().normalized()
	var out := PackedVector2Array()
	const STEPS := 16
	for k in STEPS + 1:
		var u := float(k) / float(STEPS)
		var bow := sin(u * PI) if not crossed else sin(u * TAU) * 0.6
		var at := a.lerp(z, u) + n * amp * bow
		if loose > 0.0:
			at += n * sin(u * 9.0 + phase * 6.0) * amp * 0.3 * loose
		out.append(at)
	return out

## A little satin bow: two loops and two tails either side of a knot.
func _bow(b, at: Vector2, along: Vector2, s: float, satin: Color, deep: Color) -> void:
	var side := along.orthogonal()
	for k in [-1.0, 1.0]:
		var c: Vector2 = at + side * s * 0.75 * k
		var loop := PackedVector2Array()
		for j in 14:
			var ang := float(j) / 14.0 * TAU
			loop.append(c + side * cos(ang) * s * 0.75 * k + along * sin(ang) * s * 0.45)
		b.polygon(loop, deep)
		var inner := PackedVector2Array()
		for j in 14:
			var ang := float(j) / 14.0 * TAU
			inner.append(c + side * cos(ang) * s * 0.5 * k + along * sin(ang) * s * 0.28)
		b.polygon(inner, satin)
		b.stroke(PackedVector2Array([at, at + side * s * 0.55 * k + along * s * 1.1]),
			s * 0.32, deep, false, true)
	b.disc(at, s * 0.32, deep)

## The chrome is the host's. The frame's entrance is one wide pop about its
## centre while it fades, and the pieces pop in behind it; both are read off
## the clock in _draw, so all this has to do is start it.
func _enter() -> void:
	_opened = _now()
	fx.cue("enter")
	_refresh()

# --- input ---

## A press names a cell and a release on the same cell is the tap. The pin is
## the only tap target on the board: pins never share a cell -- each sits on
## one of its own solution cells and the solution is a partition -- so a tap
## on a pin is never ambiguous, however deep the pieces are stacked over it.
func _gui_input(event: InputEvent) -> void:
	if _done or out_of_hearts:
		return
	if not (event is InputEventScreenTouch or event is InputEventMouseButton):
		return
	if event.pressed:
		_pressed = _cell_at(event.position)
		var held := _state.piece_at_pin(_pressed.x, _pressed.y) if _pressed.x >= 0 else -1
		if held >= 0 and not busy():
			_press_piece = held
			_press_last = held
			_press_down = _now()
			_press_up = -1.0
			_refresh()
		return
	var at := _cell_at(event.position)
	var was := _pressed
	_pressed = Vector2i(-1, -1)
	_let_go()
	if at.x < 0 or at != was:
		return
	_tap(at)
	accept_event()

## The finger lifts: the wheel it held springs back from its dip.
func _let_go() -> void:
	if _press_piece < 0:
		return
	_press_piece = -1
	_press_up = _now()
	_refresh()

## Whether a snag is still playing out: input, Undo, Hint and Reset wait, and
## the host holds its hint video.
func busy() -> bool:
	return _now() < _busy_until

## A tap on a pin. A piece turns (and on Insane tugs what is tied below it,
## and costs a move: `_spend`); on a judged band (none since 2026-10-04) a
## piece **already home** snags instead and costs a heart; a sewn-down or
## pinned-fast piece is refused for free.
func _tap(at: Vector2i) -> void:
	if busy() or out_of_hearts:
		return
	var t := _now()
	var p := _state.piece_at_pin(at.x, at.y)
	if p >= 0 and _state.is_tacked(p):
		# Sewn down: home, and staying. Free, like the pinned-fast refusal,
		# but kinder -- it is not wrong, it is done.
		_wob[p] = t
		_busy_for(WOB_TIME)
		fx.cue("refused", 1.12, -3.0)
		_say(tr("PW_SEWN"), Face.Expr.HAPPY)
		_refresh()
		return
	if p >= 0 and _state.would_snag(p):
		# A piece still swinging home is not on screen yet: the player has not
		# seen it land, so a quick second tap is swallowed rather than judged.
		if _lifted(p, t):
			return
		_snag(p, t)
		return
	if p >= 0 and not _state.fixed(p):
		var before: PackedInt32Array = _state.turned.duplicate()
		var trouble := _trouble()
		var pulls: Array = _state.tugged(p)
		if not _state.turn(p):
			return
		_refused = {}
		var dirs := {}
		var delays := {}
		var deepest := 0
		for pull: Array in pulls:
			dirs[int(pull[0])] = int(pull[1])
			delays[int(pull[0])] = 0.0 if Motion.reduce else TUG_LAG * float(pull[2])
			deepest = maxi(deepest, int(pull[2]))
		_settle(before, t, false, delays, dirs)
		_last_turned = p
		var q := int(_cw[p][int(before[p])][int(_state.turned[p])])
		if pulls.size() > 1:
			_tugs(pulls, t)
		fx.cue("place")
		_taps += 1
		_sparkle_cleared(before, t)
		_on_turned(p, trouble, _trouble(), t + _swing_time(q) + TUG_LAG * float(deepest))
		_speak()
		_refresh()
		note_move()
		_spend(1, t + _swing_time(q) + TUG_LAG * float(deepest))
		return
	if p >= 0:
		# The board's one refusal: a piece with a single in-frame orientation.
		# It costs no move, because nothing moved.
		_refused = {"piece": p, "at": t}
		_wob[p] = t
		_busy_for(maxf(Motion.FLASH_IN + Motion.FLASH_OUT, WOB_TIME))
		fx.cue("refused")
		_say(tr("PW_PINNED"), Face.Expr.STRAIN)
		_refresh()
		return
	# Any other cell: point at the handle rather than only naming it. This is
	# the board's answer to "which pin reaches this square", and it is why the
	# pin can be the only tap target.
	var over: Array = _state.pieces_over(at.x, at.y)
	if over.is_empty():
		_say(tr("PW_BARE"), Face.Expr.HAPPY)
	else:
		for i: int in over:
			_wob[i] = t
		_busy_for(WOB_TIME)
		_say(tr("PW_TURN"), Face.Expr.HAPPY)
	_refresh()

# --- the sprout's line ---

func _left_line() -> String:
	var bare := 0
	var stained := 0
	for i in _state.cover.size():
		var n := int(_state.cover[i])
		if n == 0:
			bare += 1
		elif n > 1:
			stained += 1
	if bare == 0 and stained == 0:
		return tr("PW_DONE")
	if stained == 0:
		return tr("PW_ONE_BARE") if bare == 1 else tr("PW_N_BARE") % bare
	if bare == 0:
		return tr("PW_ONE_DOUBLED") if stained == 1 else tr("PW_N_DOUBLED") % stained
	return tr("PW_BARE_DOUBLED") % [bare, stained]

func _speak() -> void:
	if is_done():
		return
	_say(_left_line(), Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal.
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _tip_mood != Face.Expr.HAPPY or not _state.history.is_empty():
		return
	var list := _tips()
	_tip_idx = (_tip_idx + 1) % list.size()
	_say(tr(list[_tip_idx]), Face.Expr.HAPPY)

## The sprout's own line, rather than Binairo's cycle of broken rules: this
## board answers a turn with a count, and a refusal with the rule.
func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

## One diff of which way round every piece was against the way it is now,
## turned into the swings the drawing reads.
##
## **Every move goes through here** -- a tap, a hint's three-quarter spin, the
## undo that takes the whole spin back, a reset that turns thirteen pieces at
## once -- so no gesture can forget to animate a piece it moved, and none of
## them has to know which pieces those were. Queens' and Sudoku's `_settle`
## diff derived state and Quilt's diffs the pieces themselves; this one diffs
## the pieces too.
##
## The diff cannot see which way round a piece went, so `back` says it: a tap
## and a hint turn clockwise, an undo and a reset take the same quarters back
## the way they came.
##
## `dirs` names a piece's way round where the default would be wrong: a
## crossed ribbon tugs its piece anticlockwise, and the undo of that tug
## turns it back clockwise. The swing's quarters are the true quarter turns
## (`_cw`, `_ccw`), not the index steps: a skipped orientation is two.
func _settle(before: PackedInt32Array, t: float, back: bool, delays := {}, dirs := {}) -> void:
	var longest := 0.0
	for p in _state.shapes.size():
		var was := int(before[p])
		var now := int(_state.turned[p])
		if was == now:
			continue
		var way := int(dirs.get(p, -1 if back else 1))
		var quarters: int = int(_cw[p][was][now]) if way > 0 else -int(_ccw[p][was][now])
		var at := t + float(delays.get(p, 0.0))
		# Under reduce-motion nothing swings, so nothing is lifted out of
		# index order either: a piece that was raised into `_live` for a
		# swing it never takes would drop back a frame later and the player
		# would see two neighbours swap which is on top for no reason.
		if not Motion.reduce:
			_swing[p] = {"at": at, "quarters": quarters}
		_turned_at[p] = at + _swing_time(quarters)
		if not Motion.reduce:
			_landed[p] = at + _swing_time(quarters)
			_pending.append({"at": _landed[p], "point": _pin_point(p),
				"colour": Cloth.cloth(int(_state.cloth[p])), "ring": false, "puff": true})
		_last_turned = p
		longest = maxf(longest, at - t + _hub_time(quarters))
	if longest > 0.0 or not delays.is_empty():
		_busy_for(longest + _wave_span)

## Never on Insane (`undo_allowed`): a tap that tugged four pieces taken
## back would make the ribbons trial and error. Never while a snag plays out
## or once the hearts are gone either.
func can_undo() -> bool:
	return _state.undo_allowed and not is_done() and not out_of_hearts and not busy() \
		and not _state.history.is_empty()

## Takes back the last move -- one quarter for a tap, a hint's whole spin for
## a hint, because an undo that left a hinted piece three quarters wrong
## would be a hint the player had to pay for twice. Counts no move.
func undo() -> bool:
	if is_done() or not can_undo():
		return false
	var before: PackedInt32Array = _state.turned.duplicate()
	var dirs := {}
	var last: Dictionary = _state.history.back()
	for mv: Array in (last.get("moves", []) as Array):
		dirs[int(mv[0])] = -int(mv[3]) if mv.size() > 3 else -1
	var back: Dictionary = _state.undo()
	if back.is_empty():
		return false
	_refused = {}
	_undo_ever = true
	_break_streak()
	_clear_gags()
	_settle(before, _now(), true, {}, dirs)
	_say(tr("PW_TURNED_BACK") + " " + _left_line(), Face.Expr.HAPPY)
	fx.cue("undo")
	_refresh()
	moved.emit()
	check_solved()
	return true

## One more hint beyond the budget (a rewarded video's), kept in the state.
func add_hint() -> void:
	_state.hints_extra += 1

func hints_left() -> int:
	return _state.hints_left()

## Turns the piece furthest from home all the way home, in one spin and one
## history entry. Counts no move, and the hint is not refunded by the undo
## that takes it back.
func hint() -> bool:
	if is_done() or out_of_hearts or busy() or hints_left() <= 0:
		return false
	var before: PackedInt32Array = _state.turned.duplicate()
	var out: Dictionary = _state.hint()
	if out.is_empty():
		_say(tr("PW_ALL_HOME"), Face.Expr.HAPPY)
		return false
	hints_used = _state.hints_used
	var p := int(out["piece"])
	_refused = {}
	_settle(before, _now(), false)
	# On a judged board the piece a hint turned home is sewn down: the hint
	# proved it, as a heart would have.
	if _state.judged:
		_state.tack(p)
		var lands := _swing_time(int(_cw[p][int(out["from"])][int(out["to"])])) + 0.1
		_tack_at[p] = _now() + lands
		_after(lands, fx.cue.bind("tack"))
	_fx_at(_pin_point(p), Pal.LEAF)
	fx.cue("hint")
	_say(tr("PW_HINT") + " " + _left_line(), Face.Expr.HAPPY)
	_refresh()
	moved.emit()
	# A hint can finish the frame, and a board that ends on one still ends.
	check_solved()
	return true

## Every piece goes back the way it opened, in a wave out of the far corner.
## A hint's piece goes back too: nothing here is a given, because a hint only
## turns a piece and the player could have turned it themselves.
##
## A sewn-down piece stays home: a heart (or a hint) bought that, and Reset
## is not Try again. Greyed while a snag plays out and once the hearts are
## gone (Try again is the way back then).
func can_reset() -> bool:
	return not (is_done() or out_of_hearts or busy())

func reset_board() -> void:
	if not can_reset():
		return
	# Insane's moves all come back: a reset is the frame from the top.
	if max_moves > 0:
		moves_left = max_moves
		_moves_pill.bump(_now())
		_heart_layer.queue_redraw()
	_wave_home(true)
	moves = 0
	_running = true
	_say(tr("PW_RESET") + " " + _left_line(), Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()
	moved.emit()

## Every piece that is not sewn down back the way it opened, in a wave out of
## the far corner. True when anything moved.
func _wave_home(_quiet := false) -> bool:
	var before: PackedInt32Array = _state.turned.duplicate()
	var moved_list: Array = _state.reset()
	_break_streak()
	_clear_gags()
	if moved_list.is_empty():
		return false
	# The far corner first, by the pin's distance down the diagonal.
	var order: Array = []
	for e: Dictionary in moved_list:
		var pin := _state.pin_cell(int(e["piece"]))
		order.append({"piece": int(e["piece"]), "rank": pin.x + pin.y})
	order.sort_custom(func(a, b): return int(a["rank"]) > int(b["rank"]))
	var delays := {}
	for k in order.size():
		delays[int((order[k] as Dictionary)["piece"])] = Motion.stagger(k, Motion.RESET_STAGGER)
	_refused = {}
	_pending = []
	_solved_at = -INF
	_settle(before, _now(), true, delays)
	return true

## A completed daily is rebuilt from its seed, so it reopens on its opening
## orientations. Put every piece on its answer and settle the picture at once:
## no swing, no stain wave, no entrance, and the solve wave already run, so
## every edge wears its full warmth and no piece is mid-hop -- exactly a frame
## whose solve has finished. Never `check_solved()`: the host owns the win for
## an already-completed daily and `solved` must not fire a second time.
##
## The hearts it kept come back from the record (the pill shows them), and
## whether it was flawless; the party's leavings stand where it left them:
## the cat asleep on the frame's foot, the seal when the solve earned one,
## and on Ribbons the ribbons long gone.
func restore_completed_board() -> void:
	var t := _now()
	_gen += 1
	_close_card()
	_deal()
	_reset_rewards()
	hearts = clampi(int(completed_record.get("hearts", max_hearts)), 0, max_hearts)
	_flawless = bool(completed_record.get("flawless", false))
	_cat_at = t - 100.0
	_place_cat(t)
	if _flawless or _state.ribboned():
		_stamp_at = t - 100.0
	_untie_at = t - 100.0
	_tack_at = {}
	_tug_at = {}
	_state.untack_all()
	_state.turned = _state.answer.duplicate()
	_state.history = []
	_state.recompute()
	_swing = {}
	_wob = {}
	_refused = {}
	_pending = []
	_gust = {}
	_landed = {}
	_pressed = Vector2i(-1, -1)
	_anim_until = 0.0
	_opened = t - 10.0
	for p in _turned_at.size():
		_turned_at[p] = t - 10.0
	# In the past, so `_frame_of` reads a landed hop and a full warm edge and
	# `_animating` finds nothing left of the wave.
	_solved_at = t - 10.0
	_tip_timer.stop()
	_say(tr("PW_DONE"), Face.Expr.JOY)
	_life_layer.queue_redraw()
	_heart_layer.queue_redraw()
	_refresh()

func is_solved() -> bool:
	return _state.is_solved()

## What a reopened daily needs to look as it was left: the hearts kept and
## whether it was flawless. Plain values only (it goes through a ConfigFile).
func completion_record() -> Dictionary:
	return {"hearts": hearts, "flawless": _flawless}

## The frame's own squares, then the seal's words: `🎀 Ribbons` for any
## Insane solve (and ` · Flawless` when it was), `🏅 Flawless` otherwise.
func share_glyphs() -> String:
	var out := _state.share_glyphs()
	if _state.ribboned() and is_solved():
		out += "🎀 " + tr("PW_RIBBONS_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless:
		out += "🏅 " + tr("BN_FLAWLESS")
	return out

# --- the win ---

## No cast: this board seats no character at all, which puts it with
## Nonogram, Sudoku, Bridges and Quilt. What it adds to `ui/faces/` is a
## **drawing and not a character** -- `ui/faces/pin_wheel.gd`, builder shapes
## exactly as `mosaic_tile.gd` and `patch_cloth.gd` are, because thirteen
## pinwheels batch into one mesh and a Control per pin would be a node per
## pin of a thing with no face on it.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("PW_WIN")}

## Long enough for the solve wave to cross the frame. Under reduce-motion
## there is no wave, so the win follows the last turn.
##
## The party (the kite, the cat curling up, the seal) takes PARTY_TIME from
## its start.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	var party := (_party_at - _now()) if _party_at < INF else PARTY_AT
	return maxf(WIN_WAIT, maxf(0.0, party) + PARTY_TIME)

func _on_solved() -> void:
	_solved_at = _now()
	_tip_timer.stop()
	_let_go()
	# Flawless: no hint, and never out of moves on Insane (no snag on a judged
	# board), or where nothing can be lost never an undo.
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 or max_moves > 0 else not _undo_ever)
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _solved_at
	_streak_gen += 1
	# A gag's sound still to come (a butterfly's second flutter) would land on
	# the party; its picture can finish.
	_gag_gen += 1
	_heart_layer.queue_redraw()
	_party()
	# Gold on each piece as the hop reaches it, and no ring: thirteen rings
	# over a finished frame is a firework.
	for p in _state.shapes.size():
		_fx_at(_pin_point(p), Pal.SUN, _solve_delay(p), false)
		# The breeze crosses the frame with the wave, and every wheel it
		# passes spins a whole turn.
		if not Motion.reduce and not _state.fixed(p):
			_gust[p] = {"at": _solved_at + _solve_delay(p), "turn": WIN_TURN, "time": WIN_SPIN}
	_busy_for(Motion.SOLVE_DELAY + _solve_span() + Motion.SOLVE_TIME)
	_say(tr("PW_DONE"), Face.Expr.JOY)
	fx.cue("solved")
	_refresh()

# --- the move counter ---

## `cost` moves go off Insane's counter. The last one gone with the frame
## unfinished ends the board once the last tugged piece has landed (`land`).
func _spend(cost: int, land: float) -> void:
	if max_moves <= 0 or cost <= 0:
		return
	moves_left = maxi(0, moves_left - cost)
	_moves_pill.bump(_now())
	_heart_layer.queue_redraw()
	if moves_left > 0 or is_done() or _state.is_solved():
		return
	_lost_ever = true
	out_of_hearts = true
	_running = false
	moved.emit()
	_after(maxf(0.0, land - _now()) + (0.0 if Motion.reduce else 0.1), _run_out)

# --- the snag (polish section 1) ---

## A tap on a piece already home, on a judged band: **the snag**. The piece
## starts its quarter, catches on its own thread, strains, and springs back
## home; a heart splits on the pill as it catches, and a gold button is sewn
## onto it for good -- the heart bought the knowledge that it is home. The
## state goes first (`tack`), and nothing turns, so there is nothing to undo
## and no ribbon tugs. Input, Undo, Hint and Reset wait until it is over.
func _snag(p: int, t: float) -> void:
	_state.tack(p)
	_lost_ever = true
	_refused = {}
	_let_go()
	_break_streak()
	_clear_gags()
	hearts = maxi(0, hearts - 1)
	_split_index = hearts
	var catch := 0.0 if Motion.reduce else SNAG_OUT
	_split_at = t + catch
	if not Motion.reduce:
		_swing[p] = {"at": t, "quarters": 0, "snag": true}
		_landed[p] = t + SNAG_TIME
	_tack_at[p] = t + (0.0 if Motion.reduce else SNAG_TACK)
	_busy_until = t + (Motion.REDUCED_TIME if Motion.reduce else SNAG_TIME + 0.05)
	_busy_for(SNAG_TIME * HUB_FACTOR + 0.1)
	_was_busy = true
	if hearts <= 0:
		out_of_hearts = true
	var gen := _gen
	fx.cue("snag")
	_after(catch, func() -> void:
		if gen != _gen:
			return
		fx.cue("heart_lost")
		_fx_at(_pin_point(p), Pal.FLOWER, 0.0, false)
		_heart_layer.queue_redraw())
	_after(_tack_at[p] - t, func() -> void:
		if gen == _gen:
			fx.cue("tack"))
	_say(tr("PW_SNAG") if hearts > 0 else tr("PW_SNAG_LAST"), Face.Expr.STRAIN)
	_heart_layer.queue_redraw()
	_refresh()
	# The HUD greys Undo, Hint and Reset now; `_process` lets go when it ends.
	moved.emit()
	if out_of_hearts:
		_after(SNAG_TIME, _run_out)

## The ribbons a tap pulled taut: each goes taut as the tug reaches the pin
## it hangs from, and `tug` plays once.
func _tugs(pulls: Array, t: float) -> void:
	var depth := {}
	for pull: Array in pulls:
		depth[int(pull[0])] = int(pull[2])
	for i in _state.ribbons.size():
		var rib: Dictionary = _state.ribbons[i]
		if depth.has(int(rib["from"])) and depth.has(int(rib["to"])):
			_tug_at[i] = t + (0.0 if Motion.reduce else TUG_LAG * float(depth[int(rib["from"])]))
	fx.cue("tug", 1.0, -2.0)

## Squares that are neither bare nor doubled are the frame's whole question;
## this is how many are still wrong.
func _trouble() -> int:
	var n := 0
	for k: int in _state.cover:
		if k != 1:
			n += 1
	return n

## A sparkle on up to three squares a turn tidied (no longer doubled), as
## the stain lifts off them.
func _sparkle_cleared(before: PackedInt32Array, t: float) -> void:
	if Motion.reduce:
		return
	var was := PackedInt32Array()
	was.resize(_state.cover.size())
	for p in _state.shapes.size():
		for c: Vector2i in ((_state.shapes[p] as Array)[int(before[p])] as Array):
			was[_state.idx(c.x, c.y)] += 1
	var n := 0
	for i in was.size():
		if was[i] > 1 and _state.cover[i] <= 1 and n < 3:
			var c := _state.cell_of(i)
			_fx_at(cell_to_local(c.x, c.y), Pal.SUN, _swing_time(1) + 0.05 * float(n), false)
			n += 1

# --- the hearts ---

## The hearts over the frame as one mesh on a paper pill (Paper Planes'):
## pink with a small face and a leaf, a faint ghost where one was, the lost
## one's halves falling apart, one coming back popping in.
func _draw_hearts() -> void:
	if max_moves > 0 and _cell() > 0.0:
		_moves_pill.draw(_heart_layer, _hearts_at(), moves_left, _now())
		return
	if max_hearts <= 0 or _cell() <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var mid := _hearts_at()
	var y := mid.y
	var x0 := mid.x - step * (max_hearts - 1) * 0.5
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var corner := mid - pill * 0.5
	var rim := Vector2.ONE * HEART_PILL_RIM
	var enter := Motion.pop_in_scale(now - _opened - Motion.ENTER_DELAY).x
	if enter <= 0.0:
		return
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
	var c := mid
	_heart_layer.draw_set_transform(c * (1.0 - enter), 0.0, Vector2.ONE * enter)
	_heart_layer.draw_mesh(_hearts_shown, null)
	_heart_layer.draw_set_transform(Vector2.ZERO)

## The middle of the hearts' pill: just over the frame's rim, so the pill
## sits with the frame it belongs to on a band whose frame is bound by the
## width and leaves air above it.
func _hearts_at() -> Vector2:
	return Vector2(size.x * 0.5, maxf(HEART_TOP + HEART_PILL_PAD.y + HEART_R,
		_origin().y - FRAME_PAD - FRAME_RIM - HEART_PILL_PAD.y - HEART_R - 10.0))

## A heart's small face: two dots and a smile in ink, a shine at the top
## left, and a leaf on top (Mushroom Patch's).
static func _heart_face(b, at: Vector2, s: float) -> void:
	b.ellipse(at + Vector2(-0.5, -0.5) * s, 0.16 * s, 0.1 * s, Color(1.0, 1.0, 1.0, 0.45))
	for sx in [-1.0, 1.0]:
		b.disc(at + Vector2(sx * 0.28, -0.12) * s, 0.09 * s, Pal.OUTLINE)
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, 0.02) * s, 0.16 * s, PI * 0.2, PI * 0.8), 0.07 * s, Pal.OUTLINE)
	b.ellipse(at + Vector2(0.25, -0.76) * s, 0.24 * s, 0.11 * s, Pal.LEAF)

## A heart `s` half-wide about `at` (side 0), or its left (-1) or right (1)
## half, split along a zigzag crack so the two halves fit together.
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

# --- running out ---

## The last heart is gone: the breeze stops, dusk falls on the card
## (`out_of_hearts`), and the out-of-hearts card comes up.
func _run_out() -> void:
	if _asleep or not out_of_hearts or is_done():
		return
	_asleep = true
	_let_go()
	_break_streak()
	_clear_gags()
	_tip_timer.stop()
	_gust = {}
	fx.cue("out_of_hearts")
	_say(tr("PW_OUT"), Face.Expr.SLEEPY)
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

## The card, over the whole screen: laid on the host so it covers the
## chrome, or on the root when there is none (a probe).
func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, [], MOVES_BONUS) if max_moves > 0 \
		else load(OUT_OF_HEARTS).new(_heart_used, ["PW_OUT_BODY", "PW_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same frame back in Reset's wave, every button unpicked,
## every heart back, the clock and the moves from zero. Hints spent stay
## spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	_gen += 1
	_deal()
	_state.untack_all()
	_tack_at = {}
	_tug_at = {}
	_wave_home()
	_state.history = []
	_solved_at = -INF
	elapsed = 0.0
	moves = 0
	_running = true
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	_heart_layer.queue_redraw()
	_refresh()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	moved.emit()

## One more heart, or MOVES_BONUS more moves (the card's video): once a
## frame. The day comes back and the breeze with it.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	var now := _now()
	_heart_used = true
	if max_moves > 0:
		moves_left = MOVES_BONUS
		_moves_pill.bump(now)
	else:
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
	_say(MovesPill.line(self, moves_left) if max_moves > 0 else tr("PW_HEART_BACK"), Face.Expr.HAPPY)
	_tip_timer.start()
	moved.emit()

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

## Runs `what` after `delay`, unless the board has been dealt again
## meanwhile.
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

# --- the rewards (polish section 3) ---

## Every reward's clock back to nothing: a new board, or a restored one.
func _reset_rewards() -> void:
	_streak = 0
	_streak_gen += 1
	_taps = 0
	_gag_until = 0.0
	_gag_gen += 1
	_combo_n = 0
	_combo_at = -INF
	_combo_out_at = -INF
	_love = []
	_flies = []
	_party_at = INF
	_stamp_at = INF
	_untie_at = INF
	_seal_mesh = null
	_cat_at = INF
	_cat_curled = false
	if is_instance_valid(_cat):
		_cat.queue_free()
	_cat = null
	if _life_layer != null:
		_life_layer.queue_redraw()

## The day's own number: the frame's size and its first pin, so a day always
## deals the same gags and the same bit of wisdom.
func _day_hash() -> int:
	if _state.shapes.is_empty():
		return 0
	return absi(hash([_state.cols, _state.rows, _state.shapes.size(), int(_state.pins[0])]))

## Piece `p` has just turned (not snagged, not refused), from `before` to
## `after` squares still wrong; `lands` is when the last tugged piece comes
## down. A tidier frame grows the streak: a note up the pentatonic from the
## second, the bubble over the pin from the third, confetti at 4, 7 and every
## 5 after, and one tidying tap in GAG_ODDS a gag. A messier one ends the
## streak; one that changes nothing is neutral. The winning tap does none of
## it: the party is coming.
func _on_turned(p: int, before: int, after: int, lands: float) -> void:
	if _state.is_solved():
		return
	if after > before:
		_break_streak()
		return
	if after == before:
		return
	_streak += 1
	var count := _streak
	var gen := _streak_gen
	if count >= 2:
		var step: int = COMBO_STEPS[mini(count - 2, COMBO_STEPS.size() - 1)]
		_after(0.06, func() -> void:
			if gen == _streak_gen:
				fx.cue("combo", pow(2.0, step / 12.0), COMBO_DB))
	var pin := _pin_point(p)
	if count >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = count
		_combo_pos = pin - Vector2(0.0, _cell() * 0.3)
		_combo_at = _now()
		_combo_out_at = -INF
	if _confetti_at(count) and not Motion.reduce:
		fx.confetti(pin, 22)
		fx.cue("confetti")
	_start_gag(p, _pick_gag(), lands)
	_life_layer.queue_redraw()

static func _confetti_at(count: int) -> bool:
	return count == 4 or count == 7 or (count >= 10 and count % 5 == 0)

## Which gag this tidying tap plays: one in GAG_ODDS, stepping round the
## kinds so any GAG_SPAN taps play each evenly. One at a time, never under
## reduce motion.
func _pick_gag() -> int:
	var t := _now()
	if Motion.reduce or t < _gag_until or force_gag == Gag.NONE:
		return Gag.NONE
	if force_gag >= 0:
		return force_gag
	var roll := posmod(_day_hash() + _taps * GAG_STEP, GAG_SPAN)
	if roll >= GAG_SPAN / GAG_ODDS:
		return Gag.NONE
	return roll % 3

## The streak ends: a messier frame, a snag, an undo, a reset, the hearts
## running out. The bubble deflates, and a note still to play is dropped.
func _break_streak() -> void:
	_streak = 0
	_streak_gen += 1
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
	else:
		_combo_n = 0
	if _life_layer != null:
		_life_layer.queue_redraw()

## What a tap set going that an undo or a reset takes back with it.
func _clear_gags() -> void:
	_love = []
	_flies = []
	if _whirl >= 0 and _gust.has(_whirl) and float(_gust[_whirl]["turn"]) == WHIRL_TURN:
		_gust.erase(_whirl)
	_whirl = -1
	_gag_until = 0.0
	_gag_gen += 1
	if _life_layer != null:
		_life_layer.queue_redraw()

## Piece `p`'s gag, as it lands: the wheel catches a happy gust and whirls
## (`whirl`); hearts float out of the pin (`love`); or a butterfly flutters
## in, sits on the wheel a moment and flutters off (`flutter`).
func _start_gag(p: int, gag: int, lands: float) -> void:
	if gag == Gag.NONE:
		return
	var now := _now()
	var wait := maxf(0.0, lands - now)
	var gg := _gag_gen
	var pin := _pin_point(p)
	match gag:
		Gag.WHIRL:
			_gust[p] = {"at": lands, "turn": WHIRL_TURN, "time": WHIRL_TIME}
			_whirl = p
			_busy_for(wait + WHIRL_TIME)
			_after(wait, func() -> void:
				if gg == _gag_gen:
					fx.cue("whirl")
					fx.sparkle(pin, Pal.SUN))
			_gag_until = lands + WHIRL_TIME
		Gag.LOVE:
			for k in LOVE_HEARTS:
				var side := float(k - 1)
				_love.append({"at": pin + Vector2(side * 0.28, -0.1) * _cell(),
					"t": lands + 0.12 * float(k), "phase": float(k) * 2.1})
			_after(wait, func() -> void:
				if gg == _gag_gen:
					fx.cue("love"))
			_gag_until = lands + 0.24 + LOVE_TIME
		Gag.BUTTERFLY:
			var from := -1.0 if pin.x > size.x * 0.5 else 1.0
			_flies.append({"p": p, "t": lands, "from": from})
			_after(wait, func() -> void:
				if gg == _gag_gen:
					fx.cue("flutter"))
			_after(wait + BFLY_IN + BFLY_SIT, func() -> void:
				if gg == _gag_gen:
					fx.cue("flutter", 1.15, -3.0))
			_gag_until = lands + BFLY_IN + BFLY_SIT + BFLY_OUT

# --- the party ---

## After the solve: the breeze already spins every wheel (`_on_solved`'s
## gust); the sprout shares a bit of pinwheel wisdom, confetti twice, a kite
## with a ribbon tail swoops across the card, on Ribbons the ribbons slip
## loose and float away, the nap cat hops onto the frame's foot and curls up,
## and the seal stamps when the solve earned one (flawless, or any Ribbons).
## Under reduce motion the cat and the seal are simply there and the
## ribbons simply gone.
func _party() -> void:
	var now := _now()
	var lead := 0.0 if Motion.reduce else PARTY_AT
	_party_at = now + lead
	_after(lead + 0.6, func() -> void:
		_say(_cheer(), Face.Expr.JOY))
	_cat_at = now if Motion.reduce else _party_at + CAT_AT
	if _flawless or _state.ribboned():
		_stamp_at = now if Motion.reduce else _party_at + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
	if _state.ribboned():
		_untie_at = now if Motion.reduce else _party_at + UNTIE_AT
		if not Motion.reduce:
			_after(_untie_at - now, fx.cue.bind("ribbons"))
			_busy_for(_untie_at - now + UNTIE_TIME)
	if Motion.reduce:
		_life_layer.queue_redraw()
		return
	var field := _field_rect()
	_after(lead + 0.15, func() -> void:
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell() * 0.5), 30, field.size.x * 0.9)
		fx.cue("party"))
	_after(lead + 0.7, func() -> void:
		fx.confetti(field.get_center(), 24, field.size.x * 0.7))
	_after(lead + KITE_AT, fx.cue.bind("kite"))
	_life_layer.queue_redraw()

## One of CHEERS silly bits of pinwheel wisdom, picked by the frame itself.
func _cheer() -> String:
	return tr("PW_CHEER_%d" % posmod(_day_hash(), CHEERS))

## The grid's rect, and the frame's outer rect (its border and rim).
func _field_rect() -> Rect2:
	return Rect2(_origin(), Vector2(float(_state.cols), float(_state.rows)) * _cell())

func _frame_rect() -> Rect2:
	return _field_rect().grow(FRAME_PAD + FRAME_RIM * 0.5)

# --- the nap cat ---

func _cat_px() -> float:
	return size.x * CAT_PX

## Where she curls up: on the frame's foot, a fifth of the way along from its
## left (the seal takes the right).
func _cat_spot() -> Vector2:
	var box := _frame_rect()
	return Vector2(box.position.x + box.size.x * 0.22, box.end.y - _cat_px() * 0.38)

func _cat_start() -> Vector2:
	var box := _frame_rect()
	return Vector2(box.position.x + _cat_px() * 0.5, box.end.y - _cat_px() * 0.38)

func _cat_walk() -> float:
	return CAT_POP + CAT_HOPS * CAT_HOP_TIME

## Puts the cat where her clock says: nowhere yet; popping up on the corner;
## hopping along the foot; landing with a squash; sitting up; curled up
## asleep, purring. Under reduce motion she is simply curled up there.
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
		var s := 0.1 * sin(u * PI)
		sc = Vector2(1.0 - s, 1.0 + s)
	elif e < _cat_walk() + CAT_SETTLE:
		var u := (e - _cat_walk()) / CAT_SETTLE
		var s := 0.14 * sin(u * PI)
		sc = Vector2(1.0 + s, 1.0 - s)
	_cat.position = at - _cat.size * Vector2(0.5, 0.5)
	_cat.scale = sc

## She curls up: the sleepy face and the drifting "z", and a purr -- unless
## she was already asleep when the board opened (a restore), who is quiet.
func _curl_cat(quiet: bool) -> void:
	_cat_curled = true
	_cat.expression = Face.Expr.SLEEPY
	_cat.scale = Vector2.ONE
	_cat.rotation = 0.0
	_cat.position = _cat_spot() - _cat.size * 0.5
	if not quiet:
		fx.cue("purr")

# --- the life over the frame ---

## Drops what has finished and says whether anything on the life layer still
## moves.
func _tick_life(now: float) -> bool:
	_love = _love.filter(func(l): return now < float(l.t) + LOVE_TIME)
	_flies = _flies.filter(func(f): return now < float(f.t) + BFLY_IN + BFLY_SIT + BFLY_OUT)
	var party := not Motion.reduce and now >= _party_at - 0.05 and now < _party_at + PARTY_TIME + 0.5
	return not (_love.is_empty() and _flies.is_empty()) or party \
		or (_combo_n >= COMBO_FROM and (now - _combo_at < COMBO_HOLD + 0.1 or _combo_out_at > -INF)) \
		or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1)

## Each thing one cached mesh through a transform: love hearts, butterflies,
## the kite and its tail, then the seal and the streak's bubble with their
## words.
func _draw_life() -> void:
	if _cell() <= 0.0 or _state.shapes.is_empty():
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
			var at: Vector2 = l.at + Vector2(sin(u * TAU + float(l.phase)) * 0.1 * _cell(),
				-LOVE_RISE * _cell() * (1.0 - (1.0 - u) * (1.0 - u)))
			var k := Motion.pop_in_scale(e, 0.2).x
			_life_layer.draw_mesh(mesh, null, Transform2D(sin(u * TAU) * 0.2, Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.4, 0.0, 1.0)))
	for f in _flies:
		_draw_butterfly(f, now, shown)
	if not Motion.reduce and now >= _party_at + KITE_AT and now < _party_at + KITE_AT + KITE_TIME:
		_draw_kite(now - _party_at - KITE_AT, shown)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_draw_combo(now, shown)
	_life_shown = shown

## A little pink heart for the love gag, built once a layout.
func _love_heart() -> ArrayMesh:
	if _love_mesh == null:
		var b := Face.Builder.new()
		var r := maxf(12.0, _cell() * LOVE_R)
		b.polygon(_heart(Vector2.ZERO, r * 1.15, 0), Pal.FLOWER_DEEP)
		b.polygon(_heart(Vector2.ZERO, r, 0), Pal.FLOWER)
		b.ellipse(Vector2(-0.45, -0.45) * r, 0.18 * r, 0.1 * r, Color(1.0, 1.0, 1.0, 0.5))
		_love_mesh = b.mesh()
	return _love_mesh

# --- the butterfly ---

func _bfly_px() -> float:
	return clampf(_cell() * 0.6, BFLY_PX.x, BFLY_PX.y)

## One wing, its root at the origin, reaching to +x: a big round forewing
## over a smaller hindwing, butter with an apricot rim and a dot.
func _wing() -> ArrayMesh:
	if _bfly_wing == null:
		var s := _bfly_px() * 0.5
		var b := Face.Builder.new()
		b.ellipse(Vector2(0.55, -0.32) * s, 0.62 * s, 0.5 * s, BFLY_WING_DEEP)
		b.ellipse(Vector2(0.55, -0.32) * s, 0.52 * s, 0.41 * s, BFLY_WING)
		b.ellipse(Vector2(0.42, 0.34) * s, 0.42 * s, 0.34 * s, BFLY_WING_DEEP)
		b.ellipse(Vector2(0.42, 0.34) * s, 0.33 * s, 0.26 * s, BFLY_WING)
		b.disc(Vector2(0.68, -0.36) * s, 0.13 * s, BFLY_WING_DEEP)
		b.disc(Vector2(0.5, 0.36) * s, 0.08 * s, Pal.SURFACE)
		_bfly_wing = b.mesh()
	return _bfly_wing

## The body: a little brown bean with two curled feelers.
func _body() -> ArrayMesh:
	if _bfly_body == null:
		var s := _bfly_px() * 0.5
		var b := Face.Builder.new()
		b.ellipse(Vector2.ZERO, 0.13 * s, 0.6 * s, Pal.LINE)
		for k in [-1.0, 1.0]:
			b.stroke(PackedVector2Array([Vector2(0.0, -0.5) * s, Vector2(0.2 * k, -0.85) * s,
				Vector2(0.32 * k, -0.95) * s]), maxf(2.0, 0.06 * s), Pal.LINE)
			b.disc(Vector2(0.34 * k, -0.96) * s, 0.07 * s, Pal.LINE)
		_bfly_body = b.mesh()
	return _bfly_body

## The butterfly's clock: in along an arc from the side of the card away from
## the pin, flapping; sitting on the wheel with its wings slowly opening and
## closing; then off up and out the same side, flapping fast.
func _draw_butterfly(f: Dictionary, now: float, shown: Array) -> void:
	var e := now - float(f.t)
	if e <= 0.0:
		return
	var pin := _pin_point(int(f.p)) - Vector2(0.0, _cell() * 0.3)
	var side := float(f.from)
	var far := pin + Vector2(side * _cell() * 2.2, -_cell() * 1.6)
	var at := pin
	var flap := 0.0
	var tilt := 0.0
	if e < BFLY_IN:
		var u := e / BFLY_IN
		var w := 1.0 - (1.0 - u) * (1.0 - u)
		at = far.lerp(pin, w) + Vector2(0.0, -sin(u * PI) * _cell() * 0.5)
		flap = absf(cos(e * BFLY_FLAP * PI))
		tilt = side * -0.25 * (1.0 - u)
	elif e < BFLY_IN + BFLY_SIT:
		var u := (e - BFLY_IN) / BFLY_SIT
		flap = 0.75 + 0.25 * cos(u * TAU * 1.5)
	else:
		var u := (e - BFLY_IN - BFLY_SIT) / BFLY_OUT
		at = pin.lerp(far + Vector2(0.0, -_cell()), u * u) + Vector2(sin(u * TAU * 2.0) * _cell() * 0.15, 0.0)
		flap = absf(cos(e * BFLY_FLAP * 1.3 * PI))
		tilt = side * 0.3 * u
	var wing := _wing()
	var body := _body()
	shown.append(wing)
	shown.append(body)
	var open := lerpf(0.18, 1.0, flap)
	_life_layer.draw_mesh(wing, null, Transform2D(tilt, Vector2(open, 1.0), 0.0, at))
	_life_layer.draw_mesh(wing, null, Transform2D(tilt, Vector2(-open, 1.0), 0.0, at))
	_life_layer.draw_mesh(body, null, Transform2D(tilt, Vector2.ONE, 0.0, at))

# --- the kite ---

## The kite's size: a share of the card's width.
func _kite_px() -> float:
	return size.x * KITE_PX

## A diamond kite in four of the cloths, a darker spar cross and a tiny
## smiling face, its nose at -y about its middle.
func _kite() -> ArrayMesh:
	if _kite_mesh == null:
		var s := _kite_px() * 0.5
		var b := Face.Builder.new()
		var top := Vector2(0.0, -1.2) * s
		var right := Vector2(0.85, -0.25) * s
		var bottom := Vector2(0.0, 1.25) * s
		var left := Vector2(-0.85, -0.25) * s
		var mid := Vector2(0.0, -0.25) * s
		b.polygon(PackedVector2Array([top, right, bottom, left]), Pal.LINE)
		var inset := 0.86
		b.polygon(PackedVector2Array([top * inset + mid * (1.0 - inset), right * inset + mid * (1.0 - inset), mid]), Cloth.cloth(0))
		b.polygon(PackedVector2Array([right * inset + mid * (1.0 - inset), bottom * inset + mid * (1.0 - inset), mid]), Cloth.cloth(2))
		b.polygon(PackedVector2Array([bottom * inset + mid * (1.0 - inset), left * inset + mid * (1.0 - inset), mid]), Cloth.cloth(1))
		b.polygon(PackedVector2Array([left * inset + mid * (1.0 - inset), top * inset + mid * (1.0 - inset), mid]), Cloth.cloth(5))
		b.stroke(PackedVector2Array([top, bottom]), maxf(2.0, 0.05 * s), Pal.LINE)
		b.stroke(PackedVector2Array([left, right]), maxf(2.0, 0.05 * s), Pal.LINE)
		for sx in [-1.0, 1.0]:
			b.disc(mid + Vector2(sx * 0.2, -0.12) * s, 0.06 * s, Pal.OUTLINE)
		b.stroke(Face.Builder.arc_points(mid + Vector2(0.0, -0.02) * s, 0.12 * s, PI * 0.2, PI * 0.8), 0.045 * s, Pal.OUTLINE)
		_kite_mesh = b.mesh()
	return _kite_mesh

## A little bow on the kite's tail.
func _tail_bow() -> ArrayMesh:
	if _bow_mesh == null:
		var b := Face.Builder.new()
		var s := _kite_px() * 0.16
		_bow(b, Vector2.ZERO, Vector2.UP, s, SATIN, SATIN_DEEP)
		_bow_mesh = b.mesh()
	return _bow_mesh

## Where the kite is `e` seconds into its flight: up from below the frame's
## lower left, a long swoop with a bob, out past the upper right.
func _kite_at(e: float) -> Vector2:
	var u := clampf(e / KITE_TIME, 0.0, 1.0)
	var box := _frame_rect()
	var from := Vector2(box.position.x - _kite_px(), box.end.y)
	var to := Vector2(size.x + _kite_px(), box.position.y - _kite_px())
	var w := u * u * (3.0 - 2.0 * u)
	var at := from.lerp(to, w)
	at.y -= sin(u * PI) * box.size.y * 0.18
	at += Vector2(0.0, sin(u * TAU * 2.0) * _kite_px() * 0.25)
	return at

## The kite, nosing along its path with a gentle rock, and its tail: a
## string through where it has just been, KITE_BOWS bows along it.
func _draw_kite(e: float, shown: Array) -> void:
	var at := _kite_at(e)
	var ahead := _kite_at(e + 0.05)
	var heading := (ahead - at).angle() + PI * 0.5
	var tilt := clampf(heading, -0.6, 0.6) * 0.5 + sin(e * 5.0) * 0.12
	var tail := PackedVector2Array()
	var nose_off := Vector2(0.0, 1.2) * _kite_px() * 0.5
	for k in 18:
		var back := e - float(k) * KITE_TAIL * 0.4
		tail.append(_kite_at(back) + nose_off.rotated(tilt) + Vector2(sin(back * 7.0 + float(k)) * 6.0, float(k) * 2.0))
	_life_layer.draw_polyline(tail, Pal.LINE, maxf(2.0, _kite_px() * 0.02), true)
	var bow := _tail_bow()
	shown.append(bow)
	for k in KITE_BOWS:
		var idx := 3 + k * 4
		if idx < tail.size():
			_life_layer.draw_mesh(bow, null, Transform2D(sin(e * 6.0 + float(k)) * 0.4, tail[idx]))
	var mesh := _kite()
	shown.append(mesh)
	_life_layer.draw_mesh(mesh, null, Transform2D(tilt, at))

# --- the bubble and the seal ---

## The streak's paper bubble over the pin, "x3" and up in leaf ink: it pops
## in the first time, bumps at each tidying tap and deflates when the streak
## ends. Rebuilt only when its words or its tail change (Quilt's).
func _draw_combo(now: float, shown: Array) -> void:
	if _combo_n < COMBO_FROM:
		return
	var k := 1.0
	var alpha := 1.0
	if _combo_out_at == -INF and now - _combo_at >= COMBO_HOLD:
		_combo_out_at = now
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
		HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color(Pal.LEAF_DEEP, alpha))
	_life_layer.draw_set_transform(Vector2.ZERO)

## The seal on the frame's lower right corner, dropping in from STAMP_FROM
## its size and settling with the back ease's overshoot, its words over it:
## Flawless; on Ribbons "Insane" over Flawless or Ribbons, on the night seal.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := size.x * STAMP_R * 0.75
	var insane: bool = _state.ribboned()
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
			[tr("BN_FLAWLESS") if _flawless else tr("PW_RIBBONS_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
