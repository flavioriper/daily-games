extends "res://core/puzzle_base.gd"

## Rings as a flat board: wooden dowels standing on two mossy planks on a
## sunny terrace, rings dealt over them, and a post standing proud of every
## stack. Lift the top
## ring off a peg and set it down on an empty peg or on a ring of its own
## colour; the rules live in puzzles/rings_state.gd and the deal and its
## proof in puzzles/rings_gen.gd, which this only draws.
##
## **A ring is a donut seen from a little above** (2026-09-25 polish, after
## the user's reference, docs/art/concept-rings-ref.png): a band, a lighter
## top face and a dark hole, and the post goes *into* the top ring's hole
## rather than standing behind a pill. The ring above covers the one below
## down past its hole, so only a lip of each lower top face shows, the seam
## the reference draws between its rings. An emblem is inlaid on the band,
## because colour never stands alone on this board (core/palette.gd's Code
## Break rule). Since 2026-09-26 (docs/art/concept-rings-ref.png again) the
## ring has a cream inner lip round its hole, the post is a wooden dowel
## with its end grain on top, and a ring stands straight on its plank. Every proportion is a fraction of the ring's width (`_append_donut`,
## `_append_peg`), so the menu card draws the same peg at 41 px wide.
##
## **Every move goes through one door, _settle**, so the lock, the toast and
## the tip line are decided in exactly one place -- Queens' _settle with a
## peg in place of a queen's sight. A tap on a peg lifts an empty hand's top
## ring, puts a held one back where it came from, or drops it (_tap);
## _peg_at tests the whole station column plus the held ring's headroom.
##
## **The motion.** A lifted ring slides up its post, stretching, and pops
## clear to breathe over it. A drop flies (_fly, _pose): up off its post if
## it starts on one (an undo, a hint), over in an arc that leans into its
## travel, and then **threaded down the target post** -- the board's
## signature, the post drawn back over the ring while it slides so the ring
## is visibly on it. It lands with a squash and a small bump that runs down
## the stack under it, and a puff of dust when it lands on the wood. A ring
## in hand turns slowly on its post's axis -- only its emblem shows it,
## walking round the band -- and a flight whirls it on to the next half
## turn, so it always lands with an emblem to the front. A refused drop dips the held ring toward the peg that
## refused it and shivers that peg. A peg that locks keeps its colours --
## a glint runs down the stack and a daisy pops onto the post and stays,
## the lasting mark -- because a wash toward gold turned four pink rings
## orange, and on a board coloured by index no state may be a shade of the
## piece's own colour (Pinwheel's rule). A reset drops every peg back on
## `Motion.RESET_STAGGER`, and a solve hops every peg on `Motion.SOLVE_HOP`
## with a stretch in the rings and a half turn, neighbours turning opposite.
##
## **Drawn in a design box and scaled to the card.** Everything below is laid
## out in design pixels (DESIGN_W wide, at least MIN_H tall) and drawn under
## one transform (`_s`), so the win screen, which shrinks the card, shrinks
## the board with it instead of spilling its second row over the stats.
## Spare height is shared between the air above, the gap between the rows
## and the bushes at the foot, so the two rows sit in the middle of the card.
##
## **Meshes.** The terrace and the planks are built once a layout and never
## again; each station is its own mesh in its rest pose, rebuilt only when
## what is *on* it changes (a ring, a squash, a glint, the cap, the solve's
## spin -- `_station_look`'s key); the ring in hand or in flight is its own
## small mesh rebuilt every frame it moves. Everything that moves a station
## whole -- the entrance's pop and fade, the reset hop, the solve hop, the
## shiver -- is the draw's transform and modulate, never a rebuild.
## (2026-09-27: one mesh of every station and plank cost ~30 ms to build on
## this Mac and was rebuilt on every tap and every frame of a landing; the
## phone lagged on it.) Caterpillar's lesson again: a board that rebuilt its
## whole mesh for one moving part paid for all of it every frame. All are
## kept in `_shown` until the next ones replace them (a canvas command holds
## a mesh by RID).
## (2026-10-02, the board checkup: a station's rebuild still drew its rings
## in script, 2.5-5 ms each, every frame of a squash, a glint or the solve's
## spin. Every ring part is now a look made once -- `_make_look` -- and a
## station or the ring in hand is those looks copied under the moment's
## squash, lean and turn, ~0.4 ms a station.)
##
## **The 2026-10-01 polish** (`docs/superpowers/specs/2026-10-01-rings-polish-design.md`)
## brought the rewards: the streak (drops onto their own colour in a row,
## the pentatonic, the bubble, confetti), the twirl, love and bee gags, a
## happy hop on every lock, and the party -- confetti, a runaway hoop
## rolling across the terrace, the nap cat, the seal and a bit of ring
## wisdom. A press dips the peg under the finger. Its hearts are asleep since
## 2026-10-04 (no band has any) and its doomed drop and Tumble's two-tone
## rings are gone.
##
## **A move carries the run** (2026-10-16, the user's reference): a tap
## lifts every ring of the top colour lying together, a drop lands as many
## as the peg has room for, and the rest thread back down their own post
## beside it (`_flights`). Insane is bigger and blind: eight colours on ten
## pegs, every ring under a top dealt face down -- a slate ring with a
## question mark -- that turns over when it comes to the top (`_reveal_at`).
##
## Spec: docs/superpowers/specs/2026-09-20-rings-flat-design.md (the 2026-09-25
## and 2026-09-26 amendments are this drawing). `ui/menu/card_art.gd`'s "rings" branch calls
## `_append_peg` and `RING_COLOURS` on purpose: one ring shape, not two, so a
## change here is checked on `tests/_shot_menu.gd -- page2` too.

const State = preload("res://puzzles/rings_state.gd")
const Gen = preload("res://puzzles/rings_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Seal = preload("res://ui/flat/seal.gd")
const RunMesh = preload("res://ui/flat/run_mesh.gd")
const NapCat = preload("res://ui/faces/nap_cat.gd")
const Haptics = preload("res://core/haptics.gd")
const World = preload("res://puzzles/rings_world.gd")
const FLAT_HOST := "res://ui/flat/flat_host.gd"
## The slide into the win's span (the host's SLOT_TIME), and the air the
## block keeps inside that span.
const WIN_SLIDE := 0.45
const WIN_PAD := 20.0

signal leave

# --- the design box ---
## The card's width in design pixels; the board scales to whatever it gets.
const DESIGN_W := 1000.0
const INSET := 28.0
const STATION_W := 236.0
const RING_W := 184.0

# --- a peg's shape, every figure a fraction of the ring's width ---
## The band's height between the top face's centre and the bottom's.
const SIDE := 0.30
## The top face's half height: how far "from above" the ring is seen.
const FACE := 0.16
## One slot to the next. SIDE + FACE - PITCH is how far a ring covers the
## one under it past that one's face centre -- more than the hole's depth,
## so no lower hole ever shows.
const PITCH := 0.40
const HOLE_X := 0.12
const HOLE_Y := 0.035
## The wooden dowel's width.
const POST := 0.15
## How far the post stands proud of a **full** stack's top face: what tells
## a player at a glance that a peg has room.
const POST_UP := 0.38
## Ground to the bottom ring's lower face centre: the ring stands on the
## plank, its bottom rim a little below the ground line.
const SEAT := 0.10
## The daisy a locked post wears, its petals' reach.
const CAP_R := 0.11
## Clear air between a held ring and the post top under it.
const HOVER := 0.09
## The inlaid emblem's half size, and how far round the band its centre sits.
const EMBLEM := 0.078
const EMBLEM_REACH := 0.84

# --- the layout, in design pixels ---
## Ground to post top of a station. The 3 is Gen.CAP - 1, written out
## because a const from another script's constant does not always fold in
## GDScript.
const STATION_H := (SEAT + 3.0 * PITCH + SIDE + POST_UP) * RING_W
## A held ring's room over its post, plus a little air.
const HEAD := (SIDE + 2.0 * FACE + HOVER) * RING_W + 16.0
## The shelf a row stands on, below its ground line.
const SHELF_H := 58.0
const MID_GAP := 96.0
const BAND_H := 96.0
const MIN_H := HEAD + 2.0 * STATION_H + 2.0 * SHELF_H + MID_GAP + BAND_H

# --- this board's own motion (everything else is a recipe off core/motion.gd) ---
## Up the post and clear of it, for a lift.
const RISE_TIME := 0.16
## Its idle breath while it waits to be put down, and how long a breath takes.
const BOB := 5.0
const BOB_CYCLE := 1.9
## The arc from one peg to the next, how high it arches and how far it leans.
const ARC_TIME := 0.26
const ARC_LIFT := 40.0
const TILT := 0.16
## Down the target post.
const THREAD_TIME := 0.15
## The landing's bump running down the stack, a ring a step.
const BUMP_STEP := 0.035
## How far a refused ring dips toward the peg that refused it.
const DIP := 18.0
## A held ring turns slowly on its post's axis, radians a second -- read off
## the emblem walking round its band -- and a flight whirls it on to the next
## half turn, so it always lands with an emblem to the front.
const HOLD_SPIN := 1.4
const HOLD_SPIN_IN := 0.5
## How long "Nothing can move" stays up.
const TOAST_HOLD := 2.6
## The customary win wait: every board that plays a solve wave keeps its own
## copy of this name and this number.
const WIN_WAIT := 1.4

## The card's own rounded rect radius (ui/flat/flat_host.gd's stylebox), so
## the terrace is clipped to it rather than showing square corners.
const CARD_RADIUS := 32.0

## The ring colours, and the emblem inlaid on each one's band. core/palette.gd
## says it about Code Break's pegs -- "every peg also carries a pip mark, so
## colour never stands alone" -- and a game whose whole mechanic is matching
## colour is the game that rule was written for. The emblems replaced pips on
## 2026-09-26 (the user's reference): a shape reads at a glance where a count
## of dots had to be counted.
## Insane's two more (2026-10-16) are a leaf green and a lemon, with a star
## and a square; `VEIL` is a face-down ring's slate and its question mark,
## never a shade of a ring's own colour.
const RING_COLOURS := [Pal.BERRY, Pal.SUN, Pal.MOON_INK, Pal.ACORN, Pal.FLOWER, Pal.ACCENT,
	Pal.LEAF, Color("e6cf3e"), Color("5f5a62")]
enum Emblem { HEART, SPROUT, CIRCLE, FLOWER, DIAMOND, TRIANGLE, STAR, SQUARE, QUESTION }
const EMBLEMS := [Emblem.HEART, Emblem.SPROUT, Emblem.CIRCLE, Emblem.FLOWER, Emblem.DIAMOND, Emblem.TRIANGLE,
	Emblem.STAR, Emblem.SQUARE, Emblem.QUESTION]
## A face-down ring's colour and emblem index.
const VEIL := 8

## One coloured square per ring colour, in RING_COLOURS' own order, for
## share_glyphs() -- the same language Word Trail's green squares speak.
const SHARE_GLYPHS := ["🟥", "🟧", "🟦", "🟫", "🟪", "🟩", "🟢", "🟨"]

const TIP_CYCLE := 8.0
const TIPS := [
	"RG_TIP_LIFT",
	"RG_TIP_RUN",
	"RG_TIP_LANDS",
	"RG_TIP_LOCKS",
	"RG_TIP_UNDO",
]
const TIPS_HEARTS := ["RG_TIP_HEARTS", "RG_TIP_LANDS", "RG_TIP_AHEAD", "RG_TIP_LOCKS"]
const TIPS_HIDDEN := ["RG_TIP_RUN", "RG_TIP_HIDDEN", "RG_TIP_TURNS", "RG_TIP_LOCKS"]

const STUCK_MSG := "RG_STUCK"

# --- the hearts (Hard and Insane), Pinwheel's numbers, in the control's px ---
const AGO := -1.0e9
## Design pixels the heart pill takes off the top of the card.
const HEART_ROW := 96.0
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

# --- a face-down ring coming up ---
## How long it takes to turn over: it squashes to its edge and opens again
## face up.
const REVEAL_TIME := 0.32

# --- a press ---
## How far the peg under a finger sinks, and how fast it springs back.
const PRESS_DIP := 7.0
const PRESS_IN := 0.08
const PRESS_OUT := 0.22

# --- a lock's happy hop ---
const LOCK_HOP := -18.0
const LOCK_HOP_TIME := 0.42

# --- the rewards (Pinwheel's) ---
const COMBO_FROM := 3
## The streak's `combo` is a tick a semitone a step, five in all (the cozy
## rules, 2026-10-10; it was a pluck up fourteen: [-5, -3, 0, 2, 4, 7, 9]).
const COMBO_STEPS := [-2, -1, 0, 1, 2, 3]
const COMBO_DB := -4.0
const COMBO_DEFLATE := 0.25
## The bubble shows its number this long, then deflates on its own; the
## streak itself runs on, and the next right move pops it back in.
const COMBO_HOLD := 1.2
const COMBO_FONT := 44
## One streak drop in GAG_ODDS plays a gag, stepping round the kinds so any
## GAG_SPAN drops play each kind evenly.
const GAG_ODDS := 4
const GAG_SPAN := 12
const GAG_STEP := 5
enum Gag { NONE = -1, TWIRL, LOVE, BEE }
const TWIRL_TIME := 0.8
const LOVE_HEARTS := 3
const LOVE_TIME := 1.2
const LOVE_RISE := 150.0
const LOVE_R := 22.0
## The bee: in, twice round the post, and off; px of the control.
const BEE_IN := 0.45
const BEE_ROUND := 1.1
const BEE_OUT := 0.55
const BEE_PX := 62.0
## The party, from the solve.
const PARTY_AT := 0.35
const PARTY_TIME := 3.4
const CHEERS := 12
const HOOP_AT := 0.5
const HOOP_TIME := 2.6
const CAT_AT := 0.6
const CAT_POP := 0.22
const CAT_HOPS := 3
const CAT_HOP_TIME := 0.32
const CAT_HOP_H := 0.45
const CAT_SETTLE := 0.25
const CURL_AT := 2.4
const CAT_PX := 0.16
const STAMP_AT := 1.3
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.15
const STAMP_TILT := -0.22

# --- the looks (the 2026-10-02 checkup) ---
## Shape ids in `_looks`: every part of a ring made once at RING_W about its
## own origin (the ring's top face centred on it), and copied natively under
## a transform -- a squash, a lean, a hop or a flight is that transform.
const LOOK_BODY := 0          # + the ring's ink (`_ink`): the band, under the emblems
const LOOK_FACE := 100        # + its ink: the top face and the hole
const LOOK_EMBLEM := 200      # + the emblem's kind, in slots (shade, inlay, eye)
const LOOK_GLINT := 300       # the lock's shine, in a slot
const LOOK_SHADOW := 301      # a stack's shadow, about (cx, ground)
const LOOK_SOCKET := 302      # an empty peg's socket, about (cx, ground)
const LOOK_DAISY := 303       # the cap, about its centre, full size
const LOOK_HOVER := 304       # the soft disc under a ring in the air
const LOOK_MARK := 305        # Easy and Medium's leaf ring round a post it may land on
const LOOK_POST := 1000       # + its length in whole design px: the dowel from its top
## The steps a glint or an emblem fades in, so their paint is kept.
const FADE_STEPS := 16.0

const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 66.0

var _state = State.new()

var _opened := 0.0
## Design pixels to the control's own: `_s` scale, and the design box's size.
var _s := 1.0
var _dsize := Vector2(DESIGN_W, MIN_H)
## Where the design box hangs, in the control's pixels: the whole card, or,
## in a world of its own, the span the host's rows leave (`set_clear`).
var _box := Rect2()
## The terrace edge to edge (puzzles/rings_world.gd), made on the first
## `set_clear`: a board in a card, and the tutorial's yard, have none.
var _world: Control
var _bled := false
var _clear := Vector2.ZERO
## The board's own transform on the win: the block's middle while playing,
## how far it moves and how small it gets, and how far along it is.
var _slid_from := Vector2.ZERO
var _slid_by := Vector2.ZERO
var _slid_scale := 1.0
var _slid := 0.0
var _won := false
var _win_clear := Vector2.ZERO
var _stood := false
## The host's slide on a change of level (set_shift).
var _shift := 0.0
var _slide_tw: Tween
## The two rows' ground lines, set by _layout() and read by _station().
var _ground: Array[float] = [HEAD + STATION_H, HEAD + 2.0 * STATION_H + SHELF_H + MID_GAP]

## The terrace under everything, built once a layout: it never moves.
var _still_mesh: ArrayMesh
## The two planks, in their rest pose, built once a layout.
var _plank_mesh: ArrayMesh
## Each station in its rest pose, and the look (`_station_look`'s key) it
## was built for.
var _station_meshes: Array = []
var _station_keys: Array = []
## The ring in hand or in flight, rebuilt every frame it moves.
var _live_mesh: ArrayMesh
## Every ring part, made once; the stations and the ring in hand are put
## together from them (`_build_station`, `_build_live`).
var _looks := RunMesh.new(_make_look)
var _shown: Array = []

var _tip_timer: Timer
var _tip_idx := 0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY

var fx: Fx2D

## Peg index -> the second it locked, for the glint and the cap. Derived, not
## truth: cleared for a peg that is no longer locked on every _settle.
var _lock_at: Dictionary = {}
## Peg index -> the second a drop on it was last refused, for its shiver.
var _shake_at: Dictionary = {}
## The last refusal, for the held ring's dip toward the peg that refused it.
var _refuse_at := -100.0
var _refuse_to := -1
var _press_i := -1
var _toast := ""
var _toast_at := -100.0
var _reset_at := -100.0
var _held_at := -100.0
## The rings in flight, a stack a flight: "codes" (bottom first),
## "from"/"to" (pegs), "slot" (the lowest's landing slot), "from_slot" (the
## lowest's slot it rises off, or -1 when they start in the hand), "at",
## "dur" and "settle" (whether it calls _settle when it lands -- a drop or a
## hint does, an undo never can lock a peg). A drop whose run does not all
## fit flies its leftover rings home beside it.
var _flights: Array = []
## Peg -> when its top ring turns face up (Insane), for the turn.
var _reveal_at: Dictionary = {}
var _land_peg := -1
var _land_slot := -1
var _land_at := -100.0
var _solved_at := -INF
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""

## The press: the peg under a finger, when it went down and when it lifted.
var _press_at := AGO
var _press_up := AGO
var _press_shown := -1
## Peg -> when its lock's happy hop started.
var _hop_at: Dictionary = {}

## The hearts (Hard and Insane), Pinwheel's names.
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
## Insane's move counter (ui/flat/moves_pill.gd): `max_moves` is 0 on a band
## that does not count. Out of moves unsolved sets `out_of_hearts`.
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
## Input, Undo, Hint and Reset wait until this (a doomed drop hopping back).
var _busy_until := 0.0
var _was_busy := false

## The rewards. `force_gag` is the harness's: a Gag every streak drop plays
## (one at a time still), NONE for none, -2 to leave it to the day.
var force_gag := -2
var _streak := 0
var _streak_gen := 0
var _drops := 0
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
var _love: Array = []        # [{"at": Vector2, "t": float, "phase": float}]
var _bees: Array = []        # [{"peg": int, "t": float, "from": float}]
## A twirl: {"peg", "at"}, the top ring spinning a whole turn.
var _twirl: Dictionary = {}
var _love_mesh: ArrayMesh
var _bee_mesh: ArrayMesh
var _wing_mesh: ArrayMesh
var _hoop_mesh: ArrayMesh
var _seal_mesh: ArrayMesh
var _party_at := INF
var _stamp_at := INF
var _cat: Control
var _cat_at := INF
var _cat_curled := false

func puzzle_id() -> String: return "rings"
func title() -> String: return "Rings"

## What a move is, then the band's own closing: nothing can be lost (Easy to
## Hard), or the face-down rings (Insane).
func rules() -> String:
	var line := tr("RG_RULES")
	if _state.difficulty == 3:
		line += "\n\n" + tr("RG_RULES_HIDDEN")
	elif max_hearts > 0:
		line += "\n\n" + tr("RG_RULES_HEARTS") % max_hearts
	elif max_moves <= 0:
		line += "\n\n" + tr("RG_RULES_SAFE")
	if max_moves > 0:
		line += "\n\n" + tr("RULES_MOVES_SEQ") % max_moves
	return line

## The tutorial, a page a rule, each played on a row of pegs of its own
## (`ui/hud/rings_tutorial_diagram.gd`): a lift and a drop, four of a colour
## locking a peg and the board done, Insane's face-down rings, Undo and Reset,
## the bulb on a band that has hints, and Insane's move counter (the shared
## page). The HEARTS lesson is asleep with the hearts.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/rings_tutorial_diagram.gd")
	var band: int = _state.difficulty
	var hints: int = State.hints_for(band)
	var hearts_n: int = State.hearts_for(band)
	var steps := [
		[Diagram.Lesson.LIFT, "HTP_RG_LIFT", tr("HTP_RG_LIFT_BODY")],
		[Diagram.Lesson.SORT, "HTP_RG_SORT", tr("HTP_RG_SORT_BODY")],
	]
	if band == 3:
		steps.append([Diagram.Lesson.HIDDEN, "RG_HIDDEN_SEAL", tr("HTP_RG_HIDDEN_BODY")])
	var undo_body := "HTP_RG_UNDO_BODY"
	if hearts_n > 0:
		undo_body = "HTP_RG_UNDO_BODY_JUDGED"
	steps.append([Diagram.Lesson.UNDO, "HTP_WT_UNDO", tr(undo_body)])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_RG_HINT_BODY_ONE") if hints == 1 else tr("HTP_RG_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	if max_moves > 0:
		pages.append(MovesDiagram.page(self, max_moves, true))
	return pages

func _tips() -> Array:
	if _state.difficulty == 3:
		return TIPS_HIDDEN
	if max_hearts > 0:
		return TIPS_HEARTS
	return TIPS

## Undo and the bulb on every band: since 2026-10-16 Insane counts no moves
## (its face-down rings are its own difficulty), and Undo turns no ring back
## face down.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

func can_undo() -> bool:
	return _state.undo_allowed and not is_done() and not out_of_hearts and not busy() \
		and not _state.log.is_empty()

## One more hint beyond the budget (a rewarded video's), kept here and in
## the state, which guards its own hint.
func add_hint() -> void:
	hints_extra += 1
	_state.hints_extra += 1

func hints_left() -> int:
	return State.hints_for(_state.difficulty) + hints_extra - hints_used

## Greyed while a doomed ring hops back and once the hearts are gone (Try
## again is the way back then).
func can_reset() -> bool:
	return not (is_done() or out_of_hearts or busy())

## Whether a doomed drop is still playing out: input, Undo, Hint and Reset
## wait, and the host holds its hint video.
func busy() -> bool:
	return _now() < _busy_until

func card_height(available: float) -> float:
	return available

## False: card_height() hands back everything, and _layout centres the rows.
func card_centred() -> bool:
	return false

## What the phone does under each cue (docs/agents/haptics.md). The `drop`
## cue is a ring put down on a new peg, one put back on its own and a doomed
## one setting off, so it is not mapped: `_tap` and `_doom` tap for the ring
## that goes somewhere, by `fx.buzz`. `lock` and the stuck toast come out of
## `_settle`, which a hint's ring lands through too: they knock only under
## `_by_hand`, as the ring lands. `solved` fires under the finger with the
## last ring still in the air, so the win is played from `_on_solved` at the
## landing. A ring lifted, turned over or put back, a peg that will not give
## or take one (`refused`), the wobble, the hop home, the streak's notes, the
## gags and the party say nothing. The seal thuds as it lands (`_party`).
const HAPTICS := {
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
	"confetti": Haptics.BUMP,
	"hint": Haptics.GOOD,
	"heart_back": Haptics.GOOD,
	"heart_lost": Haptics.BAD,
	"out_of_hearts": Haptics.LOSE,
}
## True while the ring landing is one the hand dropped (not a hint's).
var _by_hand := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	fx = Fx2D.new()
	fx.z_index = 2
	fx.haptics = HAPTICS
	add_child(fx)
	_heart_layer = Control.new()
	_heart_layer.name = "Hearts"
	_heart_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heart_layer.z_index = 1
	_heart_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_heart_layer.draw.connect(_draw_hearts)
	add_child(_heart_layer)
	# The rewards over everything on the card: love hearts, the bee, the
	# hoop, the bubble and the seal.
	_life_layer = Control.new()
	_life_layer.name = "Life"
	_life_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_life_layer.z_index = 3
	_life_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_life_layer.draw.connect(_draw_life)
	add_child(_life_layer)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	_close_card()
	_state.build(rng, difficulty, bank_step)
	_dealt()

## Everything a new deal starts from once the state holds it: the hearts, the
## rewards, nothing in flight, the layout and the entrance. The tutorial's
## pages deal their pegs by hand (`State.take`) and call it too.
func _dealt() -> void:
	max_hearts = State.hearts_for(_state.difficulty)
	hearts = max_hearts
	max_moves = _state.moves_budget()
	moves_left = max_moves
	out_of_hearts = false
	_asleep = false
	_heart_used = false
	_lost_ever = false
	_undo_ever = false
	_flawless = false
	_split_index = -1
	_split_at = AGO
	_back_index = -1
	_back_at = AGO
	_busy_until = 0.0
	_was_busy = false
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	_reset_rewards()
	_layout()
	_enter()
	_tip_idx = 0
	_tip_text = tr(_tips()[0])
	_tip_mood = Face.Expr.HAPPY
	_press_i = -1
	_press_at = AGO
	_press_up = AGO
	_press_shown = -1
	_hop_at = {}
	_shake_at = {}
	_refuse_at = -100.0
	_refuse_to = -1
	_toast = ""
	_toast_at = -100.0
	_reset_at = -100.0
	_lock_at = {}
	_held_at = -100.0
	_flights = []
	_reveal_at = {}
	_land_peg = -1
	_land_slot = -1
	_land_at = -100.0
	_solved_at = -INF
	_tip_timer.start()

# --- layout ---

## The pegs a row: `_rows_of` this deal (the tutorial's one row overrides it).
func _row_counts() -> Array:
	return _rows_of(_state.pegs.size())

## The design box's least height, the heart strip aside.
func _min_h() -> float:
	return MIN_H

## Rows of four and three at the hard and medium bands, three and three at
## the easy one, five and five on Insane.
static func _rows_of(peg_count: int) -> Array:
	if peg_count <= 6 or peg_count >= 9:
		return [int(ceil(peg_count / 2.0)), int(floor(peg_count / 2.0))]
	return [4, peg_count - 4]

## The design box's width: DESIGN_W, or wider when a row holds more stations
## than that fits (Insane's five), so the whole board scales down to fit.
func _design_w() -> float:
	var most := 0
	for n in _row_counts():
		most = maxi(most, int(n))
	return maxf(DESIGN_W, float(most) * STATION_W + 2.0 * INSET)

## Fits the design box to the card: as wide as the card at DESIGN_W, and never
## shorter than MIN_H, whichever binds. What height is left over goes four
## tenths above the rows, three between them and three to the foot, so the
## rows sit in the middle of the card rather than hanging from its top.
func _layout() -> void:
	var min_h := _min_h() + _top_pad()
	# In a card the box is the card. In a world of its own (`_bled`) it is
	# the span the host's rows leave, on the host's side margin.
	_box = Rect2(Vector2.ZERO, size)
	if _bled:
		var side := _side()
		_box = Rect2(side, _clear.x, size.x - 2.0 * side, size.y - _clear.x - _clear.y)
		_world.size = size
	if _box.size.x > 0.0 and _box.size.y > 0.0:
		_s = minf(_box.size.x / _design_w(), _box.size.y / min_h)
		_dsize = _box.size / _s
	else:
		_s = 1.0
		_dsize = Vector2(_design_w(), min_h)
	var extra := maxf(_dsize.y - min_h, 0.0)
	# Bled, the rows hang from the top of the span, right under the host's
	# tools row, and what is left over is open terrace at the foot.
	var above := 0.0 if _bled else extra * 0.4
	var g0 := _top_pad() + HEAD + above + STATION_H
	var g1 := g0 + SHELF_H + MID_GAP + extra * 0.3 + STATION_H
	_ground = [g0, g1]
	# The effects and the two layers over the pegs are laid on the box, so
	# everything they are told is the box's own pixels.
	if fx != null:
		fx.position = _box.position
	for layer: Control in [_heart_layer, _life_layer]:
		if layer != null:
			layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
			layer.position = _box.position
			layer.size = _box.size
	if _won:
		_aim()
		if _slid <= 0.0 and not (_slide_tw != null and _slide_tw.is_valid()):
			_slid = 1.0
	_stand()
	_toast_mesh = null
	_toast_mesh_for = ""
	_still_mesh = null
	_plank_mesh = null
	_station_meshes = []
	_station_keys = []
	_love_mesh = null
	_bee_mesh = null
	_wing_mesh = null
	_hoop_mesh = null
	_seal_mesh = null
	if _cat_curled and is_instance_valid(_cat):
		_cat.size = Vector2.ONE * _cat_px()
		_cat.position = _box.position + _cat_spot() - _cat.size * 0.5
	if _heart_layer != null:
		_heart_layer.queue_redraw()
	_refresh()

## What the host's rows cover, in this board's own pixels (it is laid full
## rect: the registry's `bleed`). The first call makes the world and turns
## the layout over to the span. On the win nothing is laid out again: the
## board slides and shrinks into the win's span under its own transform.
func set_clear(top: float, bottom: float, won := false) -> void:
	Motion.stop(_slide_tw)
	if not _bled:
		_bled = true
		_world = World.new()
		_world.name = "World"
		_world.show_behind_parent = true
		_world.painter = _paint_world
		add_child(_world)
		move_child(_world, 0)
		_still_mesh = null
		if won:
			_layout()
	_won = won
	if not won:
		_clear = Vector2(top, bottom)
		_slid = 0.0
		_layout()
		return
	_win_clear = Vector2(top, bottom)
	# A day reopened solved is told before it has a size: _layout aims then.
	if _box.size.x <= 0.0 or _state.pegs.is_empty():
		return
	_aim()
	if Motion.reduce or not is_inside_tree() or _slid >= 1.0:
		_slide(1.0)
		return
	_slide_tw = create_tween()
	_slide_tw.tween_method(_slide, _slid, 1.0, WIN_SLIDE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Where the win's slide ends: the block is the pill, both rows and the
## strip of terrace under them where the cat curls up and the seal lands.
func _aim() -> void:
	var g1: float = _ground[1]
	var tall := minf((g1 + SHELF_H) * _s + _cat_px() * 1.1, _box.size.y)
	var block := Vector2(_box.size.x, tall)
	var span := size.y - _win_clear.x - _win_clear.y
	_slid_from = _box.position + block * 0.5
	_slid_scale = clampf(minf((size.x - 2.0 * _side()) / block.x, (span - 2.0 * WIN_PAD) / block.y), 0.1, 1.0)
	_slid_by = Vector2(size.x * 0.5, _win_clear.x + span * 0.5) - _slid_from

## The host's side margin, which the pegs keep although the terrace does not.
func _side() -> float:
	return float(load(FLAT_HOST).MARGIN)

func _slide(t: float) -> void:
	_slid = t
	_stand()

## The host slides the board `x` aside on a change of level; the terrace
## stays where it is, and the board that is leaving shows none.
func set_shift(x: float, leaving := false) -> void:
	_shift = x
	if _world != null:
		_world.visible = not leaving
	_stand()

## The host deals this board into a screen already standing: it arrives
## whole, without the planks' pop and the pegs' drop.
func skip_entrance() -> void:
	_opened = _now() - 60.0
	_refresh()
	if _heart_layer != null:
		_heart_layer.queue_redraw()

## The board's transform at `_slid`, and the world's against it, so the
## terrace stays where it is while the pegs and everything on them go.
func _stand() -> void:
	if _world == null or (_slid <= 0.0 and _shift == 0.0 and not _stood):
		return
	_stood = _slid > 0.0 or _shift != 0.0
	var k := lerpf(1.0, _slid_scale, _slid)
	var by := _slid_by * _slid + Vector2(_shift, 0.0)
	pivot_offset = _slid_from
	scale = Vector2(k, k)
	position = by
	_world.pivot_offset = _slid_from
	_world.scale = Vector2.ONE / k
	_world.position = -by / k

## The board's own things on the world's terrace, painted into the world's
## one mesh (the world cannot load the board: the board loads it). In the
## gap of the host's tools row, two fallen leaves and a daisy; along the
## foot, the bushes that spilt into the old card, a short spare plank with
## one short peg half filled, a ring lying on the stones beside it and a few
## leaves. None of it has an emblem or a face, and it is smaller than the
## pieces, so nothing down there reads as a peg to tap.
func _paint_world(b: Face.Builder, wsize: Vector2, u: float) -> void:
	var none := Callable()
	var w := wsize.x
	var h := wsize.y
	var all := PackedVector2Array([Vector2(-40.0, -40.0), Vector2(w + 40.0, -40.0),
		Vector2(w + 40.0, h + 40.0), Vector2(-40.0, h + 40.0)])
	# The tools row's gap: small and pale, since the win's title lies there.
	_append_leaf(b, Vector2(w * 0.405, h * 0.240), -0.5, 26.0 * u, 15.0 * u, Color(Pal.LEAF_LIGHT, 0.7), none)
	_append_leaf(b, Vector2(w * 0.690, h * 0.228), 2.5, 22.0 * u, 13.0 * u, Color(Pal.MOSS, 0.6), none)
	_append_daisy(b, Vector2(w * 0.560, h * 0.236), 15.0 * u, none, 0.9)
	# Fallen leaves on the foot's stones.
	for f in 9:
		var at := Vector2(w * (0.06 + 0.88 * _h(71, f + 500)), h * (0.895 + 0.085 * _h(71, f + 600)))
		var lng := (15.0 + 9.0 * _h(71, f + 800)) * u
		var col: Color = [Pal.LEAF_LIGHT, Pal.MOSS, Pal.LEAF][f % 3]
		Scenery.soft_disc(b, at + Vector2(3.0, 4.0) * u, lng * 0.7, lng * 0.4, Color(Pal.TEXT, 0.08))
		_append_leaf(b, at, _h(71, f + 700) * TAU, lng, lng * 0.6, col, none)
	# The spare plank and its peg, and a ring that rolled off.
	var rw := RING_W * 0.5 * u
	var g := h - 60.0 * u
	var px := w * 0.555
	_append_plank(b, px, g, rw * 1.9, rw, none, 5)
	var cx := px + rw * 0.95
	b.fan(Face.Builder.ring(Vector2(cx + 0.07 * rw, g - SEAT * rw + FACE * rw * 0.75), 0.55 * rw, FACE * rw * 0.85),
		Color(Pal.TEXT, 0.16))
	var into := g
	for k in 2:
		into = _ring_yt(g, rw, k)
		_donut_body(b, cx, into, rw, RING_COLOURS[2], 1.0, none)
		_donut_face(b, cx, into, rw, RING_COLOURS[2], 1.0, none)
	_append_post(b, cx, into - 0.5 * rw, into, rw, 1.0, none)
	var lone := Vector2(w * 0.405, h - 92.0 * u)
	Scenery.soft_disc(b, lone + Vector2(0.06, SIDE + FACE * 0.9) * rw, 0.56 * rw, FACE * rw * 0.9, Color(Pal.TEXT, 0.14))
	_donut_body(b, lone.x, lone.y, rw, RING_COLOURS[0], 1.0, none)
	_donut_face(b, lone.x, lone.y, rw, RING_COLOURS[0], 1.0, none)
	_append_daisy(b, Vector2(w * 0.475, h - 40.0 * u), 17.0 * u, none)
	# The bushes along the very foot.
	_foot_bush(b, Vector2(54.0 * u, h + 14.0 * u), 124.0 * u, 3, all)
	_foot_bush(b, Vector2(w - 50.0 * u, h + 14.0 * u), 136.0 * u, 4, all)
	_foot_bush(b, Vector2(w * 0.27, h + 18.0 * u), 62.0 * u, 6, all)

## The pill's strip off the top of the design box: the hearts on a judged
## band, the move counter on Insane.
func _top_pad() -> float:
	return HEART_ROW if max_hearts > 0 or max_moves > 0 else 0.0

## Where peg `i` stands, in design pixels: a short row is centred.
func _station(i: int) -> Dictionary:
	var counts := _row_counts()
	var a: int = counts[0]
	var row := 0 if i < a else 1
	var k := i if row == 0 else i - a
	var n := a if row == 0 else int(counts[1])
	var x := (_dsize.x - float(n) * STATION_W) * 0.5 + float(k) * STATION_W
	var ground: float = _ground[row]
	return {"row": row, "x": x, "cx": x + STATION_W * 0.5, "ground": ground,
		"top": _post_top(ground, RING_W)}

## A ring's top face centre in slot `k` of a peg standing on `ground`.
static func _ring_yt(ground: float, w: float, k: int) -> float:
	return ground - (SEAT + float(k) * PITCH + SIDE) * w

static func _post_top(ground: float, w: float) -> float:
	return _ring_yt(ground, w, Gen.CAP - 1) - POST_UP * w

## A ring in hand: its bottom clear of the post top by HOVER.
static func _held_yt(ground: float, w: float) -> float:
	return _post_top(ground, w) - (SIDE + FACE + HOVER) * w

func _loc(p: Vector2) -> Vector2:
	return p * _s

# --- input and the one door every move goes through ---

## The peg under design point `p`: the station's column from its held ring's
## headroom down through its shelf. The second row's headroom stops at the
## first row's shelf, so the two never overlap.
func _peg_at(p: Vector2) -> int:
	for i in _state.pegs.size():
		var st := _station(i)
		var x: float = st["x"]
		var ground: float = st["ground"]
		var top: float = float(st["top"]) - HEAD
		if int(st["row"]) == 1:
			top = maxf(top, float(_ground[0]) + SHELF_H)
		if p.x >= x and p.x <= x + STATION_W and p.y >= top and p.y <= ground + SHELF_H:
			return i
	return -1

## Touch only, as every flat board takes it: the viewport hands a control
## both the mouse event and the emulated touch, and two would fire twice.
## A press dips the peg under the finger (`_press_i`), and the release on the
## same peg is the tap.
func _gui_input(event: InputEvent) -> void:
	if is_done() or out_of_hearts:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		var p: Vector2 = (event.position - _box.position) / _s
		if event.pressed:
			_press_i = _peg_at(p) if not busy() else -1
			if _press_i >= 0:
				_press_at = _now()
				_press_up = AGO
				_press_shown = _press_i
				queue_redraw()
		else:
			var i := _press_i
			_press_i = -1
			if _press_shown >= 0:
				_press_up = _now()
				queue_redraw()
			if i >= 0 and i == _peg_at(p):
				_tap(i)
				accept_event()

## The one tap gesture this board takes: lift an empty hand's run off peg
## `i`, put a held run back where it came from, or drop it on `i` -- the only
## place state.drop() is ever called. As many rings of the run as `i` has
## room for go; the rest thread back down their own post. On a band that
## counts moves (none since 2026-10-16) a drop that lands costs one.
func _tap(i: int) -> void:
	if is_done() or out_of_hearts or busy():
		return
	if not _state.holding():
		# A ring still threading down onto this peg lands first, or it would
		# be drawn twice: in flight and rising into the hand.
		for f: Dictionary in _flights:
			if int(f["to"]) == i:
				_land_flight(_now())
				break
		var src: Array = _state.pegs[i]
		var under := src.size() - Gen.run(src) - 1
		var uncovers := under >= 0 and Gen.hidden(int(src[under]))
		if _state.lift(i):
			_held_at = _now()
			fx.cue("lift", randf_range(0.94, 1.06))
			if uncovers:
				_reveal_at[i] = _now() + (0.0 if Motion.reduce else RISE_TIME * 0.5)
				_after(RISE_TIME * 0.5, fx.cue.bind("tumble"))
			_say(tr("RG_HELD") if _state.held.size() == 1 else tr("RG_HELD_RUN") % _state.held.size(), Face.Expr.HAPPY)
		elif src.is_empty():
			_shake_at[i] = _now()
			fx.cue("refused")
			_say(tr("RG_EMPTY_PEG"), Face.Expr.HAPPY)
		else:
			_shake_at[i] = _now()
			fx.cue("refused")
			_say(tr("RG_HOME_PEG"), Face.Expr.HAPPY)
	elif i == _state.held_from:
		# Back down its own post: the same thread a drop ends on.
		var codes: Array = _state.held.duplicate()
		var turn := _held_turn(_now())
		_state.put_back()
		_held_at = -100.0
		_pops(codes.size(), 0.0)
		_fly(codes, i, i, (_state.pegs[i] as Array).size() - codes.size(), -1, _now(), false, turn)
		_say(tr("RG_PUT_BACK"), Face.Expr.HAPPY)
	else:
		var from: int = _state.held_from
		var codes: Array = _state.held.duplicate()
		var turn := _held_turn(_now())
		var onto := not (_state.pegs[i] as Array).is_empty()
		var slot := _state.drop(i)
		if slot == -1:
			_shake_at[i] = _now()
			_refuse_at = _now()
			_refuse_to = i
			fx.cue("refused")
			_say(tr(_state.refusal(i)), Face.Expr.WORRIED)
		else:
			var k: int = _state.log.back().z
			var stay := codes.slice(0, codes.size() - k)
			_held_at = -100.0
			_pops(k, ARC_TIME + THREAD_TIME * 0.6)
			fx.buzz(Haptics.TAP)
			# The flight has to exist before note_move()'s check_solved() can
			# fire solved -- _on_solved reads the flights for the landing
			# moment its hop wave waits on.
			_by_hand = true
			_fly(codes.slice(codes.size() - k), from, i, slot, -1, _now(), true, turn)
			_by_hand = false
			if not stay.is_empty():
				_fly(stay, from, from, (_state.pegs[from] as Array).size() - stay.size(), -1, _now(), false,
					turn, true)
			note_move()
			_on_dropped(i, onto)
			_spend(1, _now() + (0.0 if Motion.reduce else ARC_TIME + THREAD_TIME))
	_refresh()

## A run of `n` pops, a ring a step, from `lead` seconds on: the sound rides
## the rings down the post.
func _pops(n: int, lead: float) -> void:
	var gen := _gen
	for q in n:
		var at := 0.0 if Motion.reduce else lead + float(q) * BUMP_STEP * 2.0
		_after(at, func() -> void:
			if gen == _gen:
				fx.cue("drop", randf_range(0.94, 1.06) * pow(2.0, float(q) / 12.0)))

## `cost` moves go off Insane's counter. The last one gone with the pegs
## unsorted ends the board once the ring has landed (`land`).
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
	_after(maxf(0.0, land - _now()) + (0.0 if Motion.reduce else _LAND_SQUASH_TIME), _run_out)

## Sends the rings `codes` (bottom first) from `from` to `to`, the lowest
## landing in `slot`: up off `from`'s post first when `from_slot` says they
## start on one (the lowest's slot), over, and down `to`'s post, one stack.
## Under reduce motion there is no flight: they are simply on their new peg,
## and _settle runs at once if asked.
##
## **Never blocks a second move.** Flights already live when a new one
## starts are landed on the spot (_land_flight), so a _settle -- and the
## lock it may carry -- is never lost to a player tapping faster than the
## arc. `also` keeps them: a drop's leftover rings going home fly beside it.
##
## `turn` is how far round the rings already are (a held run has been
## turning); the flight whirls them on to the next half turn but one, so they
## land with an emblem square to the front.
func _fly(codes: Array, from: int, to: int, slot: int, from_slot: int, at: float, settle: bool,
		turn := 0.0, also := false) -> void:
	if not also:
		_land_flight(at)
	if Motion.reduce:
		if settle:
			_settle(to, at)
		return
	var dur := ARC_TIME + THREAD_TIME + (RISE_TIME if from_slot >= 0 else 0.0)
	if from == to:
		dur = THREAD_TIME * 1.4
	var turn_to := ceilf(turn / PI + 0.001) * PI
	if from != to:
		turn_to += PI
	_flights.append({"codes": codes, "from": from, "to": to, "slot": slot, "from_slot": from_slot,
		"at": at, "dur": dur, "settle": settle, "turn": turn, "turn_to": turn_to, "hand": _by_hand})

## Resolves every flight in the air right now, as if it had just landed at
## `at`. A no-op when nothing is flying.
func _land_flight(at: float) -> void:
	if _flights.is_empty():
		return
	var flights := _flights
	_flights = []
	for f: Dictionary in flights:
		_land_one(f, at)

## Lands the flights whose time is up by `t`, each at its own moment.
func _land_due(t: float) -> void:
	var due: Array = []
	for f: Dictionary in _flights:
		if t >= float(f["at"]) + float(f["dur"]):
			due.append(f)
	for f: Dictionary in due:
		_flights.erase(f)
		_land_one(f, float(f["at"]) + float(f["dur"]))

## One flight's rings on their post: the squash, the dust on bare wood, and
## the _settle a drop or a hint asks for.
func _land_one(f: Dictionary, at: float) -> void:
	# The flight's own last frame is in _live_mesh: once the rings are on
	# their post nothing else rebuilds that mesh, so a stale copy would hang
	# over the ones now drawn in their slots -- the "double ring".
	_live_mesh = null
	queue_redraw()
	var to: int = f["to"]
	var slot: int = f["slot"]
	if f.get("settle", false) or _land_at < at - 0.01 or _land_peg < 0:
		_land_peg = to
		_land_slot = slot + (f["codes"] as Array).size() - 1
		_land_at = at
	if not Motion.reduce and slot == 0:
		var st := _station(to)
		var foot := Vector2(float(st["cx"]), _ring_yt(float(st["ground"]), RING_W, 0) + (SIDE + FACE) * RING_W)
		fx.puff(_loc(foot), Pal.ACORN_TILE.lerp(Pal.WOOD, 0.35), 4)
	if f.get("settle", false):
		# (A flight landed early by the next tap's: that one's flag is kept.)
		var was := _by_hand
		_by_hand = f.get("hand", false)
		_settle(to, at)
		_by_hand = was

## When the last flight in the air lands, or now.
func _flights_land() -> float:
	var land := _now()
	for f: Dictionary in _flights:
		land = maxf(land, float(f["at"]) + float(f["dur"]))
	return land

## Drops `_lock_at`'s entry for any peg that is no longer locked, checked
## against the state fresh rather than trusted.
func _reconcile_locks() -> void:
	for i in _lock_at.keys().duplicate():
		if not _state.locked(int(i)):
			_lock_at.erase(i)

## Every move that can change the pegs comes through here, so the lock and
## the toast are decided in exactly one place. A lock glints, wears its
## daisy, and hops for joy with a pinch of confetti.
func _settle(j: int, at: float) -> void:
	_reconcile_locks()
	if _state.locked(j):
		_lock_at[j] = at
		_hop_at[j] = at + float(Gen.CAP - 1) * Motion.WAVE_STEP
		var st := _station(j)
		var top_pt := _loc(Vector2(float(st["cx"]), float(st["top"])))
		var colour: Color = RING_COLOURS[Gen.top(int(_state.pegs[j][0]))]
		fx.ring(top_pt, RING_W * 0.5 * _s, Pal.SUN)
		fx.sparkle(top_pt, colour)
		fx.sparkle(top_pt, Pal.SUN)
		if not _state.is_solved():
			fx.cue("lock")
			if _by_hand:
				fx.buzz(Haptics.BUMP)
			if not Motion.reduce:
				fx.confetti(top_pt, 10, RING_W * _s * 0.6)
	if _state.is_solved():
		_say(tr("RG_WIN"), Face.Expr.JOY)
	elif _state.locked(j):
		_say(_home_line(), Face.Expr.JOY)
	else:
		_say(_left_line(), Face.Expr.HAPPY)
	if not _state.is_solved() and _state.is_stuck():
		_toast = "RG_STUCK_MOVES" if max_moves > 0 else STUCK_MSG
		_toast_at = at
		if _by_hand:
			fx.buzz(Haptics.WARN)
	queue_redraw()

func _colours_left() -> int:
	return _state.colours - _state.home_count()

func _home_line() -> String:
	var left := _colours_left()
	if left <= 0:
		return tr("RG_WIN")
	if left == 1:
		return tr("RG_ONE_LEFT")
	return tr("RG_HOME_N_LEFT") % left

func _left_line() -> String:
	var left := _colours_left()
	if left == _state.colours:
		return tr("RG_START")
	if left == 1:
		return tr("RG_ONE_LEFT")
	return tr("RG_N_LEFT") % left

## Sets the tip line and tells the host to re-read it.
func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

# --- undo, hint and reset ---

## Takes the last drop back exactly -- the rings it carried up off the peg
## they landed on, over and down the one they came from. Counts no move,
## clears the toast and ends the streak.
func undo() -> bool:
	if not can_undo():
		return false
	var m: Vector3i = _state.undo()
	if m.x < 0:
		return false
	_toast = ""
	_toast_at = -100.0
	_undo_ever = true
	_break_streak()
	_clear_gags()
	# Immediate, not deferred to the flight's landing: a peg that just lost
	# its top ring is not locked the instant it loses it.
	_reconcile_locks()
	_held_at = -100.0
	var dst: Array = _state.pegs[m.x]
	var slot := dst.size() - m.z
	_fly(dst.slice(slot), m.y, m.x, slot, (_state.pegs[m.y] as Array).size(), _now(), false)
	fx.cue("undo")
	_say(tr("RG_TAKEN_BACK") + " " + _left_line(), Face.Expr.HAPPY)
	_refresh()
	moved.emit()
	check_solved()
	return true

## Plays the solver's own next move exactly like a tapped drop, through the
## same _settle. A hint never dooms (it is a step on a proved line), and it
## is neutral to the streak.
func hint() -> bool:
	if is_done() or out_of_hearts or busy():
		return false
	_toast = ""
	_toast_at = -100.0
	_held_at = -100.0
	var m: Vector3i = _state.hint()
	if m.x < 0:
		if _state.is_stuck():
			_toast = "RG_STUCK_MOVES" if max_moves > 0 else STUCK_MSG
			_toast_at = _now()
		_refresh()
		return false
	hints_used += 1
	fx.cue("hint")
	var dst: Array = _state.pegs[m.y]
	var slot := dst.size() - m.z
	_fly(dst.slice(slot), m.x, m.y, slot, (_state.pegs[m.x] as Array).size(), _now(), true)
	check_solved()
	_refresh()
	moved.emit()
	return true

## Back to the dealt position in one step. Hints spent are not refunded, and
## the hearts are not given back (Try again is that). Insane's moves are: a
## reset is the board from the top.
func reset_board() -> void:
	if not can_reset():
		return
	_state.reset_board()
	if max_moves > 0:
		moves_left = max_moves
		_moves_pill.bump(_now())
		_heart_layer.queue_redraw()
	_lock_at = {}
	_hop_at = {}
	_shake_at = {}
	_refuse_at = -100.0
	_refuse_to = -1
	_toast = ""
	_toast_at = -100.0
	_reset_at = _now()
	_held_at = -100.0
	_flights = []
	_reveal_at = {}
	_land_peg = -1
	_land_slot = -1
	_land_at = -100.0
	_solved_at = -INF
	_break_streak()
	_clear_gags()
	fx.cue("reset")
	_say(tr("RG_RESET"), Face.Expr.HAPPY)
	_refresh()
	moved.emit()

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _state.pegs.is_empty():
		return
	var t := _now()
	# A doomed ring home again lets go of the HUD: it greyed Undo, Hint and
	# Reset.
	var b := busy()
	if _was_busy and not b:
		moved.emit()
	_was_busy = b
	_land_due(t)
	for j in _reveal_at.keys():
		if t - float(_reveal_at[j]) < REVEAL_TIME + 0.05:
			queue_redraw()
	var redraw := false
	if _stations_moving(t):
		redraw = true
	if _ring_moving():
		_live_mesh = null
		redraw = true
	if _toast != "" and t - _toast_at < TOAST_HOLD:
		redraw = true
	if redraw:
		queue_redraw()
	if _tick_life(t):
		_life_layer.queue_redraw()
	if t >= _cat_at and not _cat_curled:
		_place_cat(t)
	if max_hearts > 0 and (t - _split_at < SPLIT_TIME + 0.1 or t - _back_at < HEART_BACK_TIME + 0.1 \
			or t - _opened < Motion.ENTER_DELAY + Motion.POP_IN + 0.1):
		_heart_layer.queue_redraw()
	elif max_moves > 0 and _moves_pill.animating(t - 0.1):
		_heart_layer.queue_redraw()

## The ring in hand breathes and the ring in flight flies: the small mesh.
func _ring_moving() -> bool:
	if Motion.reduce:
		return false
	return _state.holding() or not _flights.is_empty()

## Whether anything in the stations' mesh is still moving, asked wave by
## wave: the entrance, the landing squash and its bump down the stack, the
## refusal shiver, the lock's glint, cap and hop, the press, the twirl, the
## reset and the solve. A board that rebuilds only while it is moving has to
## ask about **every** wave (oneline2d.gd once froze two lines at four fifths
## of their fade).
func _stations_moving(t: float) -> bool:
	if Motion.reduce:
		return false
	var n := maxi(_state.pegs.size() - 1, 0)
	var entrance := Motion.ENTER_DELAY + Motion.stagger(n, Motion.ENTER_STAGGER) + Motion.DROP_TIME
	if t - _opened < entrance:
		return true
	if t - _land_at < _LAND_SQUASH_TIME + float(Gen.CAP) * BUMP_STEP:
		return true
	if t - _reset_at < Motion.stagger(n, Motion.RESET_STAGGER) + Motion.HOP_TIME:
		return true
	if _press_shown >= 0 and (_press_i >= 0 or t - _press_up < PRESS_OUT + 0.05):
		return true
	for i in _shake_at.keys():
		var e := t - float(_shake_at[i])
		if e > -1.5 and e < Motion.SHIVER_TIME:
			return true
	for j in _lock_at.keys():
		if t - float(_lock_at[j]) < float(Gen.CAP - 1) * Motion.WAVE_STEP + Motion.FLASH_IN + Motion.FLASH_OUT:
			return true
	for j in _hop_at.keys():
		if t - float(_hop_at[j]) < LOCK_HOP_TIME + 0.05:
			return true
	if not _twirl.is_empty() and t - float(_twirl["at"]) < TWIRL_TIME + 0.05:
		return true
	if _solved_at > -INF and t - _solved_at < Motion.SOLVE_DELAY + Motion.stagger(n, Motion.SOLVE_STAGGER) + Motion.SOLVE_TIME:
		return true
	return false

## Every colour on a peg of its own: every peg hops on the family's wave, off
## the moment the winning ring actually lands, and the party starts.
func _on_solved() -> void:
	var land := _flights_land()
	_solved_at = land + (0.0 if Motion.reduce else float(Gen.CAP) * Motion.WAVE_STEP)
	_tip_timer.stop()
	# Flawless: no hint, and never out of moves on Insane (no heart lost on a
	# judged band), or where nothing can be lost never an undo.
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 or max_moves > 0 else not _undo_ever)
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
	_streak_gen += 1
	_gag_gen += 1
	fx.cue("solved")
	_after(land - _now(), fx.buzz.bind(Haptics.WIN))
	_heart_layer.queue_redraw()
	_party(maxf(0.0, _solved_at - _now()))
	_refresh()

func _refresh() -> void:
	_live_mesh = null
	queue_redraw()

func _enter() -> void:
	_opened = _now()
	fx.cue("enter")
	_refresh()

func _draw() -> void:
	if _state.pegs.is_empty():
		return
	var t := _now()
	draw_set_transform(_box.position, 0.0, Vector2(_s, _s))
	if _still_mesh == null and not _bled:
		_still_mesh = _build_terrace()
	if _still_mesh != null:
		draw_mesh(_still_mesh, null)
	_draw_stations(t)
	draw_set_transform(_box.position, 0.0, Vector2(_s, _s))
	if _live_mesh == null:
		_live_mesh = _build_live(t)
	if _live_mesh != null:
		draw_mesh(_live_mesh, null)
	_shown = [_still_mesh, _plank_mesh, _live_mesh]
	_shown.append_array(_station_meshes)
	_draw_toast(t, _shown)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- the stations' mesh ---

## The planks and every station, each from its rest-pose mesh under this
## moment's transform: the entrance's pop about the board's centre (`wide`),
## and per station its drop, hops and shiver as an offset and its fade as a
## modulate. A station's mesh is rebuilt only when its look changed.
func _draw_stations(t: float) -> void:
	var centre := Vector2(_dsize.x * 0.5, (float(_ground[0]) + float(_ground[1]) - STATION_H) * 0.5)
	var wide := 1.0
	if not Motion.reduce:
		wide = Motion.wide_pop_scale(t - _opened - Motion.ENTER_DELAY)
	if _plank_mesh == null:
		_plank_mesh = _build_planks()
	_place(centre, wide, Vector2.ZERO)
	if _plank_mesh != null:
		draw_mesh(_plank_mesh, null)
	var n: int = _state.pegs.size()
	if _station_meshes.size() != n:
		_station_meshes.resize(n)
		_station_keys.resize(n)
	for i in n:
		var pose := _station_pose(i, t)
		var seen: float = pose["seen"]
		if seen <= 0.0:
			continue
		var look := _station_look(i, t, float(pose["hop"]))
		var key := var_to_str(look)
		if _station_meshes[i] == null or _station_keys[i] != key:
			var st := _station(i)
			_station_meshes[i] = _build_station(float(st["cx"]), float(st["ground"]), look)
			_station_keys[i] = key
		if _station_meshes[i] != null:
			_place(centre, wide, pose["off"])
			draw_mesh(_station_meshes[i], null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, seen))

## Sets the canvas transform to carry design point `p` to
## `(centre + (p + off - centre) * wide) * _s` -- what the old per-vertex map
## did, as one affine transform.
func _place(centre: Vector2, wide: float, off: Vector2) -> void:
	draw_set_transform(_box.position + (centre * (1.0 - wide) + off * wide) * _s, 0.0, Vector2(_s * wide, _s * wide))

func _build_planks() -> ArrayMesh:
	var b := Face.Builder.new()
	var counts := _row_counts()
	for row in 2:
		var n: int = counts[row]
		if n <= 0:
			continue
		var w := float(n) * STATION_W + 40.0
		_append_plank(b, (_dsize.x - w) * 0.5, float(_ground[row]), w, RING_W, Callable(), row * 7 + n)
	return b.mesh() if not b.verts.is_empty() else null

## A wooden plank a row of pegs stands on, `ring_w` setting the scale of its
## detail so the menu card's small one is the same plank: a soft shadow on
## the terrace, a darker front board with a crack or two, a lit top with
## its grain and a knot, moss along the back edge, and a clump of leaves
## with a daisy or two on each end. `g` is the ground line the rings stand
## on, a little behind the top face's front edge.
static func _append_plank(b, x: float, g: float, w: float, ring_w: float, map: Callable, seed_i: int) -> void:
	var k := ring_w / RING_W
	var top := 44.0 * k
	var lip := 16.0 * k
	var front := SHELF_H * k - lip
	var r := 14.0 * k
	var y0 := g - top
	var y1 := g + lip
	var y2 := y1 + front
	# The shadow it casts down and to the right on the ground.
	_fan_mapped(b, Face.Builder.round_rect(Vector2(x + 10.0 * k, y2 - 16.0 * k), Vector2(w, 30.0 * k), 16.0 * k),
		Color(Pal.TEXT, 0.10), map)
	_fan_mapped(b, Face.Builder.round_rect(Vector2(x + 4.0 * k, y2 - 12.0 * k), Vector2(w, 18.0 * k), 10.0 * k),
		Color(Pal.TEXT, 0.08), map)
	var front_col: Color = Pal.PLAQUE.lerp(Pal.WOOD, 0.3)
	var top_col: Color = Pal.WOOD.lerp(Pal.SCALE_WOOD, 0.4)
	_fan_mapped(b, Face.Builder.round_rect(Vector2(x, y0), Vector2(w, y2 - y0), r), Pal.PLAQUE_DEEP.lerp(front_col, 0.45), map)
	_fan_mapped(b, Face.Builder.round_rect(Vector2(x, y0), Vector2(w, y2 - y0 - 4.0 * k), r), front_col, map)
	_fan_mapped(b, Face.Builder.round_rect(Vector2(x, y0), Vector2(w, y1 - y0 + r * 0.6), r), top_col, map)
	# The lit back edge and the rounded front edge catching the light.
	_stroke_mapped(b, PackedVector2Array([Vector2(x + r, y0 + 3.0 * k), Vector2(x + w - r, y0 + 3.0 * k)]),
		3.0 * k, Color(top_col.lerp(Color.WHITE, 0.4), 0.8), map)
	_stroke_mapped(b, PackedVector2Array([Vector2(x + r * 0.6, y1 + r * 0.45), Vector2(x + w - r * 0.6, y1 + r * 0.45)]),
		2.5 * k, Color(top_col.lerp(Color.WHITE, 0.25), 0.7), map)
	# The grain: long faint waves along the top, a crack or two down the front.
	var grain := Color(Pal.PLAQUE, 0.28)
	for gi in 4:
		var gy := y0 + (8.0 + 9.0 * float(gi)) * k
		var gx0 := x + w * (0.06 + 0.1 * _h(seed_i, gi))
		var gx1 := x + w * (0.55 + 0.4 * _h(seed_i, gi + 9))
		var pts := PackedVector2Array()
		for q in 9:
			var u := float(q) / 8.0
			pts.append(Vector2(lerpf(gx0, gx1, u), gy + sin(u * 5.0 + float(gi)) * 1.6 * k))
		_stroke_mapped(b, pts, 1.6 * k, grain, map)
	var knot := Vector2(x + w * (0.3 + 0.4 * _h(seed_i, 3)), y0 + top * 0.55)
	_fan_mapped(b, Face.Builder.ring(knot, 9.0 * k, 4.0 * k), Color(Pal.PLAQUE, 0.3), map)
	_fan_mapped(b, Face.Builder.ring(knot, 4.0 * k, 1.8 * k), Color(Pal.PLAQUE_DEEP, 0.35), map)
	var crack := Color(Pal.PLAQUE_DEEP, 0.3)
	for ci in 2:
		var cx := x + w * (0.12 + 0.45 * float(ci) + 0.2 * _h(seed_i, ci + 20))
		var cl := w * (0.12 + 0.1 * _h(seed_i, ci + 24))
		var cy := y1 + r * 0.6 + front * (0.3 + 0.25 * float(ci))
		_stroke_mapped(b, PackedVector2Array([Vector2(cx, cy), Vector2(cx + cl * 0.5, cy + 1.5 * k),
			Vector2(cx + cl, cy)]), 1.4 * k, crack, map)
	# Moss along the back edge, lumpy, lit on top.
	for mi in 3:
		var mx := x + w * (0.12 + 0.34 * float(mi) + 0.12 * _h(seed_i, mi + 30))
		var mw := (26.0 + 26.0 * _h(seed_i, mi + 40)) * k
		var at := Vector2(mx, y1 + r * 0.3)
		_fan_mapped(b, _blob(at, mw, 6.0 * k, seed_i * 11 + mi), Pal.MOSS.lerp(Pal.LEAF_DEEP, 0.25), map)
		_fan_mapped(b, _blob(at + Vector2(-mw * 0.15, -1.5 * k), mw * 0.7, 3.5 * k, seed_i * 13 + mi), Pal.MOSS.lerp(Pal.LEAF_LIGHT, 0.4), map)
	# A clump of leaves and a daisy on each end, spilling off the wood.
	for side in 2:
		var ex := x + (10.0 * k if side == 0 else w - 10.0 * k)
		var out := -1.0 if side == 0 else 1.0
		_append_clump(b, Vector2(ex, y1 + 4.0 * k), 50.0 * k, out, map, seed_i * 5 + side)

## A clump of broad leaves fanned up and out of `root`, deep ones behind and
## lit ones in front, with a daisy or two over them.
static func _append_clump(b, root: Vector2, size: float, out: float, map: Callable, seed_i: int) -> void:
	var layers := [[Pal.LEAF_DEEP, 5, 0.95], [Pal.LEAF, 4, 0.78], [Pal.LEAF_LIGHT, 3, 0.55]]
	for li in layers.size():
		var layer: Array = layers[li]
		var n: int = layer[1]
		for q in n:
			var u := float(q) / float(n - 1) - 0.5
			var ang := -PI * 0.5 + out * 0.35 + u * 2.6 + (_h(seed_i, q + li * 7) - 0.5) * 0.4
			var lng := size * float(layer[2]) * (0.8 + 0.35 * _h(seed_i, q + li * 7 + 50))
			_append_leaf(b, root, ang, lng, lng * 0.62, layer[0], map)
	_append_daisy(b, root + Vector2(out * size * 0.35, -size * 0.45), size * 0.24, map)
	if _h(seed_i, 99) < 0.6:
		_append_daisy(b, root + Vector2(-out * size * 0.2, -size * 0.7), size * 0.18, map)

## One leaf from `root` along `ang`: two curves meeting at a tip, with a vein.
static func _append_leaf(b, root: Vector2, ang: float, lng: float, wide: float, col: Color, map: Callable) -> void:
	var dir := Vector2.from_angle(ang)
	var side := dir.orthogonal() * wide * 0.5
	var tip := root + dir * lng
	var pts := Face.Builder.bezier2(root, root + dir * lng * 0.45 + side, tip, 7)
	pts.append_array(Face.Builder.bezier2(tip, root + dir * lng * 0.45 - side, root, 7))
	var mapped := pts
	if not map.is_null():
		mapped = PackedVector2Array()
		for p in pts:
			mapped.append(map.call(p))
	b.polygon(mapped, col)
	_stroke_mapped(b, PackedVector2Array([root.lerp(tip, 0.15), root.lerp(tip, 0.8)]), maxf(lng * 0.05, 0.6),
		Color(col.lerp(Color.WHITE, 0.35), 0.5), map)

## A small white daisy: petals round a sun-yellow eye, on a faint shade.
static func _append_daisy(b, at: Vector2, r: float, map: Callable, alpha := 1.0) -> void:
	for q in 6:
		var a := TAU * float(q) / 6.0 - PI * 0.5
		var c := at + Vector2.from_angle(a) * r * 0.6
		_fan_mapped(b, Face.Builder.ring(c + Vector2(0.0, r * 0.12), r * 0.42, r * 0.34),
			Color(Pal.SURFACE.lerp(Pal.LINE, 0.45), alpha), map)
		_fan_mapped(b, Face.Builder.ring(c, r * 0.42, r * 0.34), Color(Pal.SURFACE, alpha), map)
	_fan_mapped(b, Face.Builder.ring(at, r * 0.32, r * 0.3), Color(Pal.SUN_DEEP, alpha), map)
	_fan_mapped(b, Face.Builder.ring(at - Vector2(r * 0.05, r * 0.06), r * 0.25, r * 0.23), Color(Pal.SUN_RAY, alpha), map)

## A lumpy, roughly round outline off the hash, so no two tufts match.
static func _blob(c: Vector2, rx: float, ry: float, seed_i: int) -> PackedVector2Array:
	var pts := Face.Builder.ring(c, rx, ry)
	var ph := _h(seed_i, 29) * TAU
	for q in pts.size():
		var a := TAU * float(q) / float(pts.size())
		pts[q] = c + (pts[q] - c) * (1.0 + 0.08 * sin(3.0 * a + ph) + 0.05 * sin(5.0 * a + ph * 2.0))
	return pts

## A stable 0..1 off two integers.
static func _h(a: int, b: int) -> float:
	return float(absi(hash(Vector2i(a, b))) % 10007) / 10006.0

## Where station `i` stands as a whole at `t`: its fade (`seen`), the offset
## its entrance drop, reset hop, solve hop and shiver add up to (`off`), and
## the solve hop alone (`hop`), which also stretches its rings.
func _station_pose(i: int, t: float) -> Dictionary:
	var since := t - _opened - Motion.ENTER_DELAY - Motion.stagger(i, Motion.ENTER_STAGGER)
	var seen := 1.0
	var lift := 0.0
	if not Motion.reduce:
		seen = Motion.appear_level(since)
		lift = Motion.drop_in_lift(since)
	lift += -Motion.hop_lift(t - _reset_at - Motion.stagger(i, Motion.RESET_STAGGER), Motion.RESET_HOP, Motion.HOP_TIME)
	var hop := 0.0
	if _solved_at > -INF:
		var e := t - _solved_at - Motion.SOLVE_DELAY - Motion.stagger(i, Motion.SOLVE_STAGGER)
		hop = -Motion.hop_lift(e, Motion.SOLVE_HOP, Motion.SOLVE_TIME)
		lift += hop * 2.2
	if _hop_at.has(i) and not Motion.reduce:
		lift += -Motion.hop_lift(t - float(_hop_at[i]), LOCK_HOP, LOCK_HOP_TIME)
	var dx := Motion.shiver_offset(t - float(_shake_at.get(i, -100.0)), Motion.SHIVER_PX * 2.0)
	return {"seen": seen, "off": Vector2(dx, -lift + _press_dip(i, t)), "hop": hop}

## How far peg `i` sinks under a finger at `t`: down over PRESS_IN while it is
## held, back up on the back ease's overshoot over PRESS_OUT once it lifts.
func _press_dip(i: int, t: float) -> float:
	if Motion.reduce or i != _press_shown:
		return 0.0
	var down := clampf((t - _press_at) / PRESS_IN, 0.0, 1.0)
	if _press_i == i:
		return PRESS_DIP * down
	var u := (t - _press_up) / PRESS_OUT
	if u >= 1.0:
		return 0.0
	return PRESS_DIP * down * (1.0 - Motion.back_out(clampf(u, 0.0, 1.0)))

## What is on station `i` at `t` -- its rings and this moment's squash, glint,
## turn and cap: everything its rest-pose mesh is built from, so it doubles as
## the key that says when that mesh is stale.
func _station_look(i: int, t: float, hop: float) -> Dictionary:
	var turn := 0.0
	var turn_top := 1.0
	if _solved_at > -INF and not Motion.reduce:
		# The solve spins every ring a half turn on its post while it hops.
		var e := t - _solved_at - Motion.SOLVE_DELAY - Motion.stagger(i, Motion.SOLVE_STAGGER)
		var u := clampf(e / Motion.SOLVE_TIME, 0.0, 1.0)
		turn = PI * u * u * (3.0 - 2.0 * u)
	var pegs: Array = (_state.pegs[i] as Array).duplicate()
	# The slots a live flight lands in are drawn by the flight itself.
	var flying := false
	for f: Dictionary in _flights:
		if int(f["to"]) == i and t < float(f["at"]) + float(f["dur"]):
			pegs.resize(mini(pegs.size(), int(f["slot"])))
			flying = true
	# A face-down ring coming to the top turns over: still face down until
	# half way, squashed to its edge, then face up.
	if _reveal_at.has(i) and not pegs.is_empty() and not Motion.reduce:
		var u := (t - float(_reveal_at[i])) / REVEAL_TIME
		if u < 1.0:
			var fp := _flip_pose(int(pegs.back()) | Gen.HIDDEN, int(pegs.back()), maxf(u, 0.0))
			pegs[pegs.size() - 1] = fp[0]
			turn_top = float(fp[1])
	var scales: Array = []
	var glints: Array = []
	var turns: Array = []
	var stretch := hop / absf(Motion.SOLVE_HOP)
	for k in pegs.size():
		var sc := Vector2(1.0 - 0.04 * stretch, 1.0 + 0.07 * stretch)
		if k == pegs.size() - 1:
			sc.y *= turn_top
		if i == _land_peg and k <= _land_slot:
			var e := t - _land_at - float(_land_slot - k) * BUMP_STEP
			var amount := 0.14 if k == _land_slot else 0.06
			sc *= _land_squash(e, amount)
		scales.append(sc)
		var glint := 0.0
		if _lock_at.has(i):
			glint = Motion.flash_level(t - float(_lock_at[i]) - float(Gen.CAP - 1 - k) * Motion.WAVE_STEP)
		glints.append(glint)
		var spin := turn * (1.0 if k % 2 == 0 else -1.0)
		if not _twirl.is_empty() and int(_twirl["peg"]) == i and k == pegs.size() - 1 and not Motion.reduce:
			# The twirl gag: the top ring spins a whole turn, stretching up.
			var u := clampf((t - float(_twirl["at"])) / TWIRL_TIME, 0.0, 1.0)
			if u > 0.0 and u < 1.0:
				spin += TAU * (1.0 - pow(1.0 - u, 3.0))
				scales[k] = (scales[k] as Vector2) * Vector2(1.0 - 0.05 * sin(u * PI), 1.0 + 0.12 * sin(u * PI))
		turns.append(spin)
	var cap := 0.0
	if _state.locked(i) and not flying:
		cap = 1.0
		if _lock_at.has(i) and not Motion.reduce:
			cap = Motion.pop_in_scale(t - float(_lock_at[i]) - float(Gen.CAP - 1) * Motion.WAVE_STEP).x
	return {"pegs": pegs, "scales": scales, "glints": glints, "turns": turns, "cap": cap}

## A whole peg, `w` the ring's width: its shadow on the plank, the rings
## bottom-up, the dowel above the top ring (into its hole, or into a socket
## in the plank when the peg is empty) and, on a locked peg, the daisy on the
## post top scaled by `cap`. The menu card draws its pegs through this too.
static func _append_peg(b, cx: float, ground: float, w: float, colours: Array, map: Callable,
		alpha := 1.0, scales: Array = [], glints: Array = [], cap := 0.0, turns: Array = []) -> void:
	var foot := ground - SEAT * w
	var top_y := _post_top(ground, w)
	var into := foot
	if colours.is_empty():
		_fan_mapped(b, Face.Builder.ring(Vector2(cx, foot), HOLE_X * w * 1.15, HOLE_Y * w * 2.0),
			Color(Pal.PLAQUE_DEEP, 0.55 * alpha), map)
		_fan_mapped(b, Face.Builder.ring(Vector2(cx + POST * w * 0.3, foot + HOLE_Y * w * 0.9), POST * w * 0.9, HOLE_Y * w * 1.2),
			Color(Pal.TEXT, 0.12 * alpha), map)
	else:
		# The stack's shadow, falling down and to the right across the wood.
		_fan_mapped(b, Face.Builder.ring(Vector2(cx + 0.07 * w, foot + FACE * w * 0.75), 0.55 * w, FACE * w * 0.85),
			Color(Pal.TEXT, 0.16 * alpha), map)
	for k in colours.size():
		var code: int = colours[k]
		var ci := _ink(code)
		var sc: Vector2 = scales[k] if k < scales.size() else Vector2.ONE
		var glint: float = glints[k] if k < glints.size() else 0.0
		var turn: float = turns[k] if k < turns.size() else 0.0
		var yt := _ring_yt(ground, w, k)
		# A squash sits the ring on its own bottom rather than its middle.
		yt += (1.0 - sc.y) * (SIDE + FACE) * w
		_append_donut(b, cx, yt, w, RING_COLOURS[ci], ci, alpha, map, sc, glint, 0.0, turn)
		into = yt
	_append_post(b, cx, top_y, into, w, alpha, map)
	if cap > 0.0:
		var at := Vector2(cx, top_y + POST * w * 0.2)
		_append_daisy(b, at, CAP_R * w * cap, map, alpha)

## The wooden dowel from its rounded top down to `bottom_y`, ending on the
## front half of its own cross-section there -- which is what makes it read
## as going *into* a hole at `bottom_y` rather than stopping in front of it.
## Lit down its left, shaded down its right, with its end grain on top.
static func _append_post(b, cx: float, top_y: float, bottom_y: float, w: float, alpha: float, map: Callable) -> void:
	if bottom_y <= top_y:
		return
	var r := POST * w * 0.5
	var ry := HOLE_Y * w * 0.7
	var body := Face.Builder.arc_points(Vector2(cx, top_y + r), r, PI, TAU)
	var bottom := Face.Builder.arc_points(Vector2.ZERO, 1.0, 0.0, PI)
	for p in bottom:
		body.append(Vector2(cx + p.x * r, maxf(bottom_y + p.y * ry, top_y + r)))
	var wood: Color = Pal.WOOD.lerp(Pal.ACORN_DEEP, 0.35)
	_fan_mapped(b, body, Color(wood, alpha), map)
	var h := bottom_y - top_y - r
	if h > 2.0:
		_fan_mapped(b, Face.Builder.round_rect(Vector2(cx + r * 0.28, top_y + r * 0.7), Vector2(r * 0.62, h + ry * 0.3), r * 0.3),
			Color(Pal.PLAQUE, 0.45 * alpha), map)
		_fan_mapped(b, Face.Builder.round_rect(Vector2(cx - r * 0.62, top_y + r * 0.7), Vector2(r * 0.38, h - r * 0.1), r * 0.19),
			Color(wood.lerp(Color.WHITE, 0.45), 0.7 * alpha), map)
	# The end grain: a lighter disc on the dome, a ring in it.
	var cap_c := Vector2(cx - r * 0.08, top_y + r * 0.55)
	_fan_mapped(b, Face.Builder.ring(cap_c, r * 0.72, r * 0.42), Color(wood.lerp(Color.WHITE, 0.3), alpha), map)
	_fan_mapped(b, Face.Builder.ring(cap_c + Vector2(-r * 0.15, -r * 0.08), r * 0.3, r * 0.16),
		Color(Color.WHITE, 0.35 * alpha), map)

## An ellipse's top half at `y0` joined to its bottom half at `y1`: the
## outline of a band seen from a little above -- a ring's.
static func _capsule(cx: float, y0: float, y1: float, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in Face.Builder.arc_points(Vector2.ZERO, 1.0, PI, TAU):
		pts.append(Vector2(cx + p.x * rx, y0 + p.y * ry))
	for p in Face.Builder.arc_points(Vector2.ZERO, 1.0, 0.0, PI):
		pts.append(Vector2(cx + p.x * rx, y1 + p.y * ry))
	return pts

## The front of a band between two levels: the near half of the ellipse at
## `y0` down to the near half of the one at `y1` -- a two-tone ring's lower
## layer, curving round the ring rather than bulging over its upper half.
static func _front_band(cx: float, y0: float, y1: float, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	const N := 18
	for q in N + 1:
		var a := lerpf(PI, 0.0, float(q) / N)
		pts.append(Vector2(cx + cos(a) * rx, y0 + sin(a) * ry))
	for q in N + 1:
		var a := lerpf(0.0, PI, float(q) / N)
		pts.append(Vector2(cx + cos(a) * rx, y1 + sin(a) * ry))
	return pts

## `points`, each carried through `map`, as one (triangulated) polygon.
static func _poly_mapped(b, points: PackedVector2Array, colour: Color, map: Callable) -> void:
	if map.is_null():
		b.polygon(points, colour)
		return
	var mapped := PackedVector2Array()
	mapped.resize(points.size())
	for i in points.size():
		mapped[i] = map.call(points[i])
	b.polygon(mapped, colour)

## One ring, `w` wide, its top face centred on (cx, yt): the band with its
## rounded shoulders, its sheen, the inlaid emblem, the lighter top face with
## its cream inner lip, and the hole. `sc` squashes it and `tilt` leans it
## about its own middle, before `map`; `glint` lays white over it, the lock's
## shine; `turn` is how far round the ring has turned on its axis, which only
## the emblems show -- two of them, opposite, so one is always to the front
## when the turn is a whole number of half turns.
static func _append_donut(b, cx: float, yt: float, w: float, colour: Color, emblem: int, alpha: float,
		map: Callable, sc := Vector2.ONE, glint := 0.0, tilt := 0.0, turn := 0.0) -> void:
	var smap := map
	if sc != Vector2.ONE or tilt != 0.0:
		var about := Vector2(cx, yt + SIDE * w * 0.5)
		var rot := Transform2D(tilt, Vector2.ZERO)
		if map.is_null():
			smap = func(p: Vector2) -> Vector2:
				return about + rot * ((p - about) * sc)
		else:
			smap = func(p: Vector2) -> Vector2:
				return map.call(about + rot * ((p - about) * sc))
	_donut_body(b, cx, yt, w, colour, alpha, smap)
	_donut_emblems(b, cx, yt, w, colour, emblem, alpha, smap, turn)
	_donut_face(b, cx, yt, w, colour, alpha, smap)
	if glint > 0.0:
		_donut_glint(b, cx, yt, w, Color(Color.WHITE, 0.55 * glint * alpha), smap)

## A ring's band: its rim and body, the tube's shading and the sheen spot --
## everything under the emblems.
static func _donut_body(b, cx: float, yt: float, w: float, colour: Color, alpha: float, smap: Callable) -> void:
	var rx := w * 0.5
	var ry := FACE * w
	var yb := yt + SIDE * w
	var edge := w * 0.03
	var rim := colour.lerp(Pal.TEXT, 0.26)
	var band := colour.lerp(Pal.TEXT, 0.03)
	_fan_mapped(b, _capsule(cx, yt, yb, rx, ry), Color(rim, alpha), smap)
	_fan_mapped(b, _capsule(cx, yt, yb - edge, rx * 0.99, ry), Color(band, alpha), smap)
	# The tube's roundness: its lower third turned from the light, and a lit
	# shoulder just under the top face, both edged on the ring's own ellipse
	# so the shading curves round it the way a torus's does.
	_fan_mapped(b, _capsule(cx, yt + SIDE * w * 0.62, yb - edge, rx * 0.99, ry), Color(rim, 0.38 * alpha), smap)
	_fan_mapped(b, _capsule(cx, yt, yt + SIDE * w * 0.3, rx * 0.985, ry), Color(Color.WHITE, 0.2 * alpha), smap)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx - rx * 0.66, yt + ry + SIDE * w * 0.36), rx * 0.1, SIDE * w * 0.22),
		Color(Color.WHITE, 0.22 * alpha), smap)

## Where an emblem `q` (0 or 1, opposite each other) sits on a ring whose
## top face is centred on (cx, yt), turned `turn` round: [centre, how square
## to the eye, fade], or [] when it is round the back.
static func _emblem_spot(cx: float, yt: float, w: float, turn: float, q: int) -> Array:
	var a := turn + PI * float(q)
	var c := cos(a)
	if c < 0.1:
		return []
	var rx := w * 0.5
	var ry := FACE * w
	var y := yt + ry + SIDE * w * 0.48 + ry * (c - 1.0)
	return [Vector2(cx + sin(a) * rx * EMBLEM_REACH, y), c, clampf((c - 0.1) / 0.3, 0.0, 1.0)]

## The emblems inlaid on the band, two of them opposite each other so one is
## always to the front when the turn is a whole number of half turns.
static func _donut_emblems(b, cx: float, yt: float, w: float, colour: Color, emblem: int, alpha: float,
		smap: Callable, turn: float) -> void:
	for q in 2:
		var spot := _emblem_spot(cx, yt, w, turn, q)
		if spot.is_empty():
			continue
		_append_emblem(b, emblem, spot[0], EMBLEM * w, spot[1], colour, float(spot[2]) * alpha, smap)

## The lighter top face, its cream inner lip and the hole.
static func _donut_face(b, cx: float, yt: float, w: float, colour: Color, alpha: float, smap: Callable) -> void:
	var rx := w * 0.5
	var ry := FACE * w
	var face := colour.lerp(Color.WHITE, 0.24)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, yt), rx, ry), Color(face, alpha), smap)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, yt + ry * 0.04), rx * 0.66, ry * 0.62),
		Color(colour.lerp(Color.WHITE, 0.45), alpha), smap)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx - rx * 0.4, yt - ry * 0.5), rx * 0.24, ry * 0.18),
		Color(Color.WHITE, 0.35 * alpha), smap)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, yt), HOLE_X * w * 1.12, HOLE_Y * w * 1.75),
		Color(colour.lerp(Pal.TEXT, 0.2), alpha), smap)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, yt), HOLE_X * w, HOLE_Y * w * 1.6), Color(colour.lerp(Pal.TEXT, 0.58), alpha), smap)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, yt + HOLE_Y * w * 0.5), HOLE_X * w * 0.8, HOLE_Y * w * 0.9),
		Color(colour.lerp(Pal.TEXT, 0.34), alpha), smap)

## The lock's shine laid over the whole ring.
static func _donut_glint(b, cx: float, yt: float, w: float, colour: Color, smap: Callable) -> void:
	_fan_mapped(b, _capsule(cx, yt, yt + SIDE * w, w * 0.5, FACE * w), colour, smap)

## The emblem inlaid on a band at `at`, `s` its half size, `sx` how square to
## the eye it is (a cosine: it narrows as it turns away round the band). A
## cream inlay over a thin shade just under it, so it reads as set into the
## ring rather than printed on it.
static func _append_emblem(b, kind: int, at: Vector2, s: float, sx: float, colour: Color, alpha: float, map: Callable,
		inks: Array = []) -> void:
	if inks.is_empty():
		inks = _emblem_inks(colour, alpha)
	var deep: Color = inks[0]
	var ink: Color = inks[1]
	var drop := Vector2(0.0, s * 0.16)
	for pass_i in 2:
		var col := deep if pass_i == 0 else ink
		var off := drop if pass_i == 0 else Vector2.ZERO
		var to := func(p: Vector2) -> Vector2:
			var q := at + off + Vector2(p.x * s * sx, p.y * s)
			return q if map.is_null() else map.call(q)
		match EMBLEMS[kind % EMBLEMS.size()]:
			Emblem.HEART:
				var pts := PackedVector2Array()
				for q in 28:
					var u := TAU * float(q) / 28.0
					var hx := 16.0 * pow(sin(u), 3.0)
					var hy := -(13.0 * cos(u) - 5.0 * cos(2.0 * u) - 2.0 * cos(3.0 * u) - cos(4.0 * u))
					pts.append(to.call(Vector2(hx, hy - 2.5) / 16.0))
				b.polygon(pts, col)
			Emblem.SPROUT:
				_stroke_to(b, [Vector2(0.0, 0.95), Vector2(0.0, 0.2)], 0.26, s, col, to)
				_leaf_to(b, Vector2(0.05, 0.3), Vector2(-1.0, -0.45), 0.95, col, to)
				_leaf_to(b, Vector2(-0.05, 0.25), Vector2(1.0, -0.75), 1.05, col, to)
			Emblem.CIRCLE:
				var ring := Face.Builder.ring(Vector2.ZERO, 0.7, 0.7)
				_stroke_to(b, Array(ring), 0.34, s, col, to, true)
			Emblem.FLOWER:
				for q in 5:
					var c := Vector2.from_angle(TAU * float(q) / 5.0 - PI * 0.5) * 0.52
					var petal := Face.Builder.ring(c, 0.4, 0.4)
					var mapped := PackedVector2Array()
					for p in petal:
						mapped.append(to.call(p))
					b.fan(mapped, col)
				if pass_i == 1:
					var eye := PackedVector2Array()
					for p in Face.Builder.ring(Vector2.ZERO, 0.28, 0.28):
						eye.append(to.call(p))
					b.fan(eye, inks[2])
			Emblem.DIAMOND:
				_stroke_to(b, [Vector2(0.0, -0.95), Vector2(0.78, 0.0), Vector2(0.0, 0.95), Vector2(-0.78, 0.0)],
					0.3, s, col, to, true)
			Emblem.TRIANGLE:
				_stroke_to(b, [Vector2(0.0, -0.82), Vector2(0.9, 0.7), Vector2(-0.9, 0.7)], 0.3, s, col, to, true)
			Emblem.STAR:
				var star := PackedVector2Array()
				for q in 10:
					var r := 1.0 if q % 2 == 0 else 0.45
					star.append(to.call(Vector2.from_angle(TAU * float(q) / 10.0 - PI * 0.5) * r))
				b.polygon(star, col)
			Emblem.SQUARE:
				_stroke_to(b, [Vector2(-0.68, -0.68), Vector2(0.68, -0.68), Vector2(0.68, 0.68), Vector2(-0.68, 0.68)],
					0.3, s, col, to, true)
			Emblem.QUESTION:
				# A hook and a dot: what a face-down ring keeps to itself.
				var hook: Array = []
				for q in 9:
					hook.append(Vector2.from_angle(PI * 1.05 + PI * 1.45 * float(q) / 8.0) * 0.48 + Vector2(0.0, -0.42))
				hook.append(Vector2(0.06, 0.12))
				hook.append(Vector2(0.06, 0.36))
				_stroke_to(b, hook, 0.28, s, col, to)
				var dot := PackedVector2Array()
				for p in Face.Builder.ring(Vector2(0.06, 0.78), 0.17, 0.17):
					dot.append(to.call(p))
				b.fan(dot, col)

## An emblem's three inks on a ring of `colour`: the shade under it, the
## cream inlay and a flower's eye.
static func _emblem_inks(colour: Color, alpha: float) -> Array:
	return [Color(colour.lerp(Pal.TEXT, 0.45), 0.45 * alpha), Color(colour.lerp(Color.WHITE, 0.78), 0.95 * alpha),
		Color(colour.lerp(Pal.TEXT, 0.1), alpha)]

static func _stroke_to(b, pts: Array, width: float, s: float, col: Color, to: Callable, closed := false) -> void:
	var mapped := PackedVector2Array()
	for p in pts:
		mapped.append(to.call(p))
	var scale: float = (to.call(Vector2(0.0, 1.0)) - to.call(Vector2.ZERO)).length()
	b.stroke(mapped, width * scale, col, closed)

static func _leaf_to(b, root: Vector2, tip: Vector2, wide: float, col: Color, to: Callable) -> void:
	var side := (tip - root).orthogonal().normalized() * wide * 0.5
	var mid := root.lerp(tip, 0.5)
	var pts := Face.Builder.bezier2(root, mid + side, tip, 6)
	pts.append_array(Face.Builder.bezier2(tip, mid - side, root, 6))
	var mapped := PackedVector2Array()
	for p in pts:
		mapped.append(to.call(p))
	b.polygon(mapped, col)

## `points` carried through `map` and stroked, the width scaled by the map.
static func _stroke_mapped(b, points: PackedVector2Array, width: float, colour: Color, map: Callable, closed := false) -> void:
	if map.is_null():
		b.stroke(points, width, colour, closed)
		return
	var mapped := PackedVector2Array()
	mapped.resize(points.size())
	for i in points.size():
		mapped[i] = map.call(points[i])
	var scale: float = (map.call(points[0] + Vector2(1.0, 0.0)) - mapped[0]).length()
	b.stroke(mapped, width * scale, colour, closed)

## `points`, each carried through `map`, as one fan.
static func _fan_mapped(b, points: PackedVector2Array, colour: Color, map: Callable) -> void:
	if map.is_null():
		b.fan(points, colour)
		return
	var mapped := PackedVector2Array()
	mapped.resize(points.size())
	for i in points.size():
		mapped[i] = map.call(points[i])
	b.fan(mapped, colour)

## The span Motion.squash's own tween plays, read as a curve, for a drawn
## ring (Motion has no reader for squash). 0.18 is that recipe's default time.
const _LAND_SQUASH_TIME := 0.18
static func _land_squash(elapsed: float, amount := 0.12) -> Vector2:
	if Motion.reduce or elapsed < 0.0 or elapsed >= _LAND_SQUASH_TIME:
		return Vector2.ONE
	var squashed := Vector2(1.0 + amount * 0.5, 1.0 - amount)
	var split := _LAND_SQUASH_TIME * 0.4
	if elapsed < split:
		return Vector2.ONE.lerp(squashed, sin(elapsed / split * PI * 0.5))
	return squashed.lerp(Vector2.ONE, Motion.back_out((elapsed - split) / (_LAND_SQUASH_TIME - split)))

# --- the looks ---

## Shape `id` of `_looks` (LOOK_*), drawn about its own origin.
func _make_look(id: int) -> Face.Builder:
	var b := Face.Builder.new()
	var w := RING_W
	var none := Callable()
	if id < LOOK_FACE:
		_donut_body(b, 0.0, 0.0, w, RING_COLOURS[id - LOOK_BODY], 1.0, none)
	elif id < LOOK_EMBLEM:
		_donut_face(b, 0.0, 0.0, w, RING_COLOURS[id - LOOK_FACE], 1.0, none)
	elif id < LOOK_GLINT:
		# At the size it is drawn, so its feather stays a pixel and a half.
		_append_emblem(b, id - LOOK_EMBLEM, Vector2.ZERO, EMBLEM * w, 1.0, Color.WHITE, 1.0, none,
			[RunMesh.slot(0), RunMesh.slot(1), RunMesh.slot(2)])
	elif id == LOOK_GLINT:
		_donut_glint(b, 0.0, 0.0, w, RunMesh.slot(0), none)
	elif id == LOOK_SHADOW or id == LOOK_SOCKET:
		# What `_append_peg` lays first, under the rings, about (cx, ground).
		var foot := -SEAT * w
		if id == LOOK_SOCKET:
			b.fan(Face.Builder.ring(Vector2(0.0, foot), HOLE_X * w * 1.15, HOLE_Y * w * 2.0), Color(Pal.PLAQUE_DEEP, 0.55))
			b.fan(Face.Builder.ring(Vector2(POST * w * 0.3, foot + HOLE_Y * w * 0.9), POST * w * 0.9, HOLE_Y * w * 1.2),
				Color(Pal.TEXT, 0.12))
		else:
			b.fan(Face.Builder.ring(Vector2(0.07 * w, foot + FACE * w * 0.75), 0.55 * w, FACE * w * 0.85), Color(Pal.TEXT, 0.16))
	elif id == LOOK_DAISY:
		_append_daisy(b, Vector2.ZERO, CAP_R * w, none)
	elif id == LOOK_HOVER:
		_ring_shadow(b, 0.0, -6.0, none)
	elif id == LOOK_MARK:
		_landing_mark(b, 0.0, -6.0, none)
	elif id >= LOOK_POST:
		_append_post(b, 0.0, 0.0, float(id - LOOK_POST), w, 1.0, none)
	return b

## A station from the looks, the drawing `_append_peg` makes (the menu card
## still draws through that): the shadow or socket, each ring under its
## squash and turn, the post into the top ring's hole, and the cap.
func _build_station(cx: float, ground: float, look: Dictionary) -> ArrayMesh:
	var w := RING_W
	var rings: Array = look["pegs"]
	var top_y := _post_top(ground, w)
	_looks.begin()
	_looks.put(LOOK_SOCKET if rings.is_empty() else LOOK_SHADOW, [], Transform2D(0.0, Vector2(cx, ground)))
	var into := ground - SEAT * w
	for k in rings.size():
		var sc: Vector2 = look["scales"][k]
		# A squash sits the ring on its own bottom rather than its middle.
		var yt := _ring_yt(ground, w, k) + (1.0 - sc.y) * (SIDE + FACE) * w
		_put_ring(cx, yt, int(rings[k]), sc, 0.0, float(look["turns"][k]), float(look["glints"][k]))
		into = yt
	_put_post(cx, top_y, into)
	var cap: float = look["cap"]
	if cap > 0.0:
		_looks.put(LOOK_DAISY, [], Transform2D(0.0, Vector2(cap, cap), 0.0, Vector2(cx, top_y + POST * w * 0.2)))
	return _looks.mesh()

## One ring by its code, its top face centred on (cx, yt): `_append_donut`'s
## drawing from the looks, squashed by `sc` and leaned by `tilt` about its
## own middle, its emblems walked round the band by `turn`, `glint` the
## lock's shine over it.
func _put_ring(cx: float, yt: float, code: int, sc := Vector2.ONE, tilt := 0.0, turn := 0.0, glint := 0.0) -> void:
	var half := SIDE * RING_W * 0.5
	var xf := Transform2D(tilt, sc, 0.0, Vector2(cx, yt + half)) * Transform2D(0.0, Vector2(0.0, -half))
	var ci := _ink(code)
	_looks.put(LOOK_BODY + ci, [], xf)
	for q in 2:
		var spot := _emblem_spot(0.0, 0.0, RING_W, turn, q)
		if spot.is_empty():
			continue
		_put_emblem(xf, ci, spot)
	_looks.put(LOOK_FACE + ci, [], xf)
	if glint > 0.0:
		_looks.put(LOOK_GLINT, [Color(Color.WHITE, 0.55 * roundf(glint * FADE_STEPS) / FADE_STEPS)], xf)

## What a ring is drawn as: its colour, or VEIL while it lies face down.
static func _ink(code: int) -> int:
	return VEIL if Gen.hidden(code) else Gen.top(code)

## An emblem at `spot` (`_emblem_spot`) on the ring under `xf`, narrowed as
## it turns away and faded in steps.
func _put_emblem(xf: Transform2D, kind: int, spot: Array) -> void:
	var fade := roundf(float(spot[2]) * FADE_STEPS) / FADE_STEPS
	if fade <= 0.0:
		return
	_looks.put(LOOK_EMBLEM + kind, _emblem_inks(RING_COLOURS[kind], fade),
		xf * Transform2D(Vector2(float(spot[1]), 0.0), Vector2(0.0, 1.0), spot[0]))

## The dowel down into a ring at `bottom_y`, a look a whole design pixel of
## length (the half pixel it can be short of a sliding ring is in its hole).
func _put_post(cx: float, top_y: float, bottom_y: float) -> void:
	var h := roundi(bottom_y - top_y)
	if h > 0:
		_looks.put(LOOK_POST + h, [], Transform2D(0.0, Vector2(cx, top_y)))

## The soft disc at a post top under a ring in the air.
func _put_hover(cx: float, top_y: float) -> void:
	_looks.put(LOOK_HOVER, [], Transform2D(0.0, Vector2(cx, top_y + 6.0)))

# --- the ring in hand and the ring in flight ---

func _build_live(t: float) -> ArrayMesh:
	if not _state.holding() and _flights.is_empty():
		return null
	_looks.begin()
	if _state.holding():
		_build_held(t)
	for f: Dictionary in _flights:
		_build_flight(f, t)
	return _looks.mesh()

## A ring turning over at `u` (0..1 across its turn): which face is up -- the
## `from` code until the middle, the `to` code after -- and how tall it is
## drawn (it squashes to its edge at the middle).
static func _flip_pose(from: int, to: int, u: float) -> Array:
	if from == to or u >= 1.0:
		return [to, 1.0]
	if u <= 0.0:
		return [from, 1.0]
	return [from if u < 0.5 else to, maxf(absf(cos(PI * u)), 0.08)]

## A stack of rings `codes` (bottom first) whose top ring's face is at `yt`,
## the rest a slot apart under it, all under one squash, lean and turn; the
## post from `post_top` goes into the lowest one's hole when it is on one
## (`post_top` < INF), drawn before the rings above it so they cover it.
func _put_stack(cx: float, yt: float, codes: Array, sc: Vector2, tilt: float, turn: float, post_top := INF) -> void:
	var n := codes.size()
	for q in n:
		var dy := float(n - 1 - q) * PITCH * RING_W
		var at := Vector2(cx, yt) + Vector2(-sin(tilt), cos(tilt)) * dy
		_put_ring(at.x, at.y, int(codes[q]), sc, tilt, turn)
		if q == 0 and post_top < INF:
			_put_post(cx, post_top, at.y)

## The run in hand: up its post on the back ease over RISE_TIME, stretched
## while it slides, then breathing BOB px for as long as it waits, its top
## ring clear of the post and the rest a slot apart under it. A refusal dips
## it toward the peg that refused it and shivers it there. On Easy and
## Medium a soft leaf ring marks every post it may land on. Under reduce
## motion it is simply up and still.
func _build_held(t: float) -> void:
	var st := _station(_state.held_from)
	var cx: float = st["cx"]
	var ground: float = st["ground"]
	var up := _held_yt(ground, RING_W)
	var y := up
	var sc := Vector2.ONE
	var codes: Array = _state.held
	if _state.difficulty <= 1:
		# Breathing: the look made at rest, scaled about its middle.
		var k := 1.0 + 0.06 * sin(t * 4.0)
		for j in _state.pegs.size():
			if j != _state.held_from and _state.can_drop(j):
				var sj := _station(j)
				_looks.put(LOOK_MARK, [], Transform2D(0.0, Vector2(k, k), 0.0, Vector2(float(sj["cx"]), float(sj["top"]) + 6.0)))
	if not Motion.reduce:
		var since := t - _held_at
		var from_y := _ring_yt(ground, RING_W, (_state.pegs[_state.held_from] as Array).size() + codes.size() - 1)
		var u := clampf(since / RISE_TIME, 0.0, 1.0)
		y = lerpf(from_y, up, Motion.back_out(u))
		var s := sin(PI * u)
		sc = Vector2(1.0 - 0.05 * s, 1.0 + 0.09 * s)
		var breath := clampf((since - RISE_TIME) / 0.3, 0.0, 1.0)
		y += BOB * sin(maxf(since - RISE_TIME, 0.0) * TAU / BOB_CYCLE) * breath
		if _refuse_to >= 0:
			var to := _station(_refuse_to)
			var dir := signf(float(to["cx"]) - cx)
			var e := t - _refuse_at
			cx += dir * Motion.nudge_offset(e, DIP, Motion.NUDGE_TIME, 0.0)
			cx += Motion.shiver_offset(e - Motion.NUDGE_TIME * 0.5, Motion.SHIVER_PX * 2.5)
	_put_hover(float(st["cx"]), float(st["top"]))
	# Still on its post while it slides: the post into the lowest ring's hole.
	_put_stack(cx, y, codes, sc, 0.0, _held_turn(t), float(st["top"]))

## A soft leaf-green ring breathing round a post top the held ring may land
## on (Easy and Medium only: the harder bands read the pegs themselves).
## It breathes by its put's scale (`_build_held`).
static func _landing_mark(b, cx: float, y: float, map: Callable) -> void:
	var pts := Face.Builder.ring(Vector2(cx, y + 6.0), RING_W * 0.24, 13.0)
	_stroke_mapped(b, pts, 4.0, Color(Pal.LEAF, 0.55), map, true)

## Where the top ring of a flying stack of `n` is `e` seconds into a flight:
## {x, yt, tilt, peg, u} -- `peg` the post it is on (rising off or threading
## down), or -1 while it is in the air, and `u` how far down the thread it
## is. `slot` and `from_slot` are the lowest ring's.
func _leg_pose(from: int, to: int, slot: int, from_slot: int, n: int, dur: float, e: float) -> Dictionary:
	var a := _station(from)
	var d := _station(to)
	var ya := _held_yt(float(a["ground"]), RING_W)
	var yd := _held_yt(float(d["ground"]), RING_W)
	var y_land := _ring_yt(float(d["ground"]), RING_W, slot + n - 1)
	if from == to:
		var u0 := clampf(e / dur, 0.0, 1.0)
		return {"x": float(d["cx"]), "yt": lerpf(yd, y_land, u0 * u0), "tilt": 0.0, "peg": to, "u": u0}
	if from_slot >= 0:
		if e < RISE_TIME:
			var u := e / RISE_TIME
			var y0 := _ring_yt(float(a["ground"]), RING_W, from_slot + n - 1)
			return {"x": float(a["cx"]), "yt": lerpf(y0, ya, 1.0 - (1.0 - u) * (1.0 - u)), "tilt": 0.0,
				"peg": from, "u": 0.0}
		e -= RISE_TIME
	if e < ARC_TIME:
		var u := e / ARC_TIME
		var ease := 0.5 - 0.5 * cos(PI * u)
		var x := lerpf(float(a["cx"]), float(d["cx"]), ease)
		var y := lerpf(ya, yd, ease) - ARC_LIFT * sin(PI * u)
		y = maxf(y, FACE * RING_W + 8.0)
		var lean := TILT * sin(PI * u) * signf(float(d["cx"]) - float(a["cx"]))
		return {"x": x, "yt": y, "tilt": lean, "peg": -1, "u": 0.0}
	var v := clampf((e - ARC_TIME) / THREAD_TIME, 0.0, 1.0)
	return {"x": float(d["cx"]), "yt": lerpf(yd, y_land, v * v), "tilt": 0.0, "peg": to, "u": v}

func _build_flight(f: Dictionary, t: float) -> void:
	var codes: Array = f["codes"]
	var p := _leg_pose(int(f["from"]), int(f["to"]), int(f["slot"]), int(f["from_slot"]), codes.size(),
		float(f["dur"]), t - float(f["at"]))
	var peg: int = p["peg"]
	if peg < 0:
		var d := _station(int(f["to"]))
		_put_hover(float(p["x"]), float(d["top"]))
	var sc := Vector2(1.0 + 0.04 * float(p["u"]), 1.0 - 0.02 * float(p["u"]))
	var u := clampf((t - float(f["at"])) / float(f["dur"]), 0.0, 1.0)
	var turn := lerpf(float(f.get("turn", 0.0)), float(f.get("turn_to", 0.0)), 1.0 - pow(1.0 - u, 3.0))
	var post := INF
	if peg >= 0:
		post = float(_station(peg)["top"])
	_put_stack(float(p["x"]), float(p["yt"]), codes, sc, float(p["tilt"]), turn, post)

## How far round the run in hand has turned: still as it rises, then easing
## into a slow turn on its post's axis for as long as it waits.
func _held_turn(t: float) -> float:
	if Motion.reduce or not _state.holding():
		return 0.0
	var since := maxf(t - _held_at - RISE_TIME, 0.0)
	if since < HOLD_SPIN_IN:
		return HOLD_SPIN * since * since / (2.0 * HOLD_SPIN_IN)
	return HOLD_SPIN * (since - HOLD_SPIN_IN * 0.5)

## A soft disc at the post top under a ring in the air: where it will go.
static func _ring_shadow(b, cx: float, y: float, map: Callable) -> void:
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, y + 6.0), RING_W * 0.3, 10.0), Color(Pal.TEXT, 0.08), map)

## The one thing this board can say that no other move answers: a position
## still legal and already lost. **Deliberately not announced past this
## pill** -- no dimming, no forced ending. Measured while the concept page
## was built (2026-09-20): the true stuck rate is 4%, 9% and 11% by band,
## common enough that silence would read as a bug, rare enough that a modal
## would be a bigger interruption than the problem deserves.
func _draw_toast(t: float, shown: Array) -> void:
	if _toast == "":
		return
	var line := tr(_toast)
	var since := t - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE),
		Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var font: Font = CozyTheme.body(600)
	var w: float = minf(_dsize.x - 120.0,
		font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x + TOAST_PAD)
	if _toast_mesh == null or _toast_mesh_for != line:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-w, -TOAST_H) * 0.5, Vector2(w, TOAST_H), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh() if not b.verts.is_empty() else null
		_toast_mesh_for = line
	if _toast_mesh == null:
		return
	var mid := Vector2(_dsize.x * 0.5, _dsize.y - TOAST_MARGIN - TOAST_H * 0.5)
	draw_set_transform(_box.position + mid * _s, 0.0, Vector2(_s, _s))
	draw_mesh(_toast_mesh, null, Transform2D.IDENTITY, Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var where := Vector2(-w * 0.5 + TOAST_PAD * 0.5,
		font.get_height(TOAST_FONT) * 0.5 - font.get_descent(TOAST_FONT))
	font.draw_string(get_canvas_item(), where, line, HORIZONTAL_ALIGNMENT_LEFT, -1,
		TOAST_FONT, Color(Pal.PAPER, alpha))
	draw_set_transform(_box.position, 0.0, Vector2(_s, _s))

# --- the terrace under everything ---

## The sunny terrace the planks stand on (the user's reference, 2026-09-26):
## pale flagstones in a sandy grout, dappled leaf shade, a few fallen leaves,
## and leafy corners with daisies -- bushes spilling in along the foot and
## foliage hanging into the top corners. It never moves, so it is built once
## a layout into a mesh of its own, clipped to the card's rounded rect: the
## stations' mesh, rebuilt while anything moves, stays as small as before.
func _build_terrace() -> ArrayMesh:
	if _bled:
		return null
	var b := Face.Builder.new()
	var clip := _clip_rect()
	var w: float = _dsize.x
	var h: float = _dsize.y
	var seed_i: int = _state.pegs.size() * 31 + _state.colours
	_clip_polygon(b, clip, Pal.ACORN_TILE.lerp(Pal.ACORN, 0.13), clip)
	# Flagstones: a jittered grid, rows offset, every stone rounded and toned.
	var cell := Vector2(260.0, 190.0)
	var cols := int(ceil(w / cell.x)) + 2
	var rows := int(ceil(h / cell.y)) + 1
	var corner := func(c: int, r: int) -> Vector2:
		var jx := (_h(seed_i + c * 7, r * 13) - 0.5) * 60.0
		var jy := (_h(seed_i + c * 11, r * 17 + 3) - 0.5) * 40.0
		var shift := cell.x * 0.5 if r % 2 == 1 else 0.0
		return Vector2(float(c) * cell.x - shift - cell.x * 0.5 + jx, float(r) * cell.y - 20.0 + jy)
	for r in rows:
		for c in cols:
			var quad := PackedVector2Array([corner.call(c, r), corner.call(c + 1, r),
				corner.call(c + 1, r + 1), corner.call(c, r + 1)])
			# The rows share their corners' x only within a row; across a row
			# the next row's corners are offset, so each stone is its own quad.
			var shrunk := Geometry2D.offset_polygon(quad, -14.0, Geometry2D.JOIN_ROUND)
			if shrunk.is_empty():
				continue
			var stone: PackedVector2Array = Geometry2D.offset_polygon(shrunk[0], 10.0, Geometry2D.JOIN_ROUND)[0]
			var tone := _h(seed_i + r * 101, c * 37)
			var face: Color = Pal.ACORN_TILE.lerp(Pal.SURFACE, 0.12 + 0.3 * tone)
			var under := PackedVector2Array()
			for p in stone:
				under.append(p + Vector2(0.0, 3.0))
			_clip_polygon(b, under, Pal.ACORN_TILE.lerp(Pal.ACORN, 0.2), clip)
			_clip_polygon(b, stone, face, clip)
	# Dappled shade: soft clusters of leaf shadow, heavier toward the top.
	var shade := Color(Pal.ACORN_DEEP.lerp(Pal.TEXT, 0.3), 0.075)
	for d in 6:
		var at := Vector2(w * _h(seed_i, d + 200), h * (0.08 + 0.84 * _h(seed_i, d + 300)))
		if d < 2:
			at = Vector2(w * float(d), 60.0)
		for q in 6:
			var off := Vector2((_h(d, q + 1) - 0.5) * 260.0, (_h(d, q + 7) - 0.5) * 140.0)
			var r := 55.0 + 45.0 * _h(d, q + 13)
			var c := at + off
			c.x = clampf(c.x, r, w - r)
			c.y = clampf(c.y, r * 0.6, h - r * 0.6)
			Scenery.soft_disc(b, c, r, r * 0.6, shade)
	# Fallen leaves, here and there on the stones.
	for f in 12:
		var at := Vector2(40.0 + (w - 80.0) * _h(seed_i, f + 500), 60.0 + (h - 160.0) * _h(seed_i, f + 600))
		var ang := _h(seed_i, f + 700) * TAU
		var lng := 16.0 + 10.0 * _h(seed_i, f + 800)
		var col: Color = [Pal.LEAF_LIGHT, Pal.MOSS, Pal.LEAF][f % 3]
		var ident := func(p: Vector2) -> Vector2: return p
		Scenery.soft_disc(b, at + Vector2(3.0, 4.0), lng * 0.7, lng * 0.4, Color(Pal.TEXT, 0.08))
		_append_leaf(b, at, ang, lng, lng * 0.6, col, ident)
		if f % 4 == 0:
			_append_leaf(b, at, ang + 1.2, lng * 0.85, lng * 0.55, col.lerp(Pal.LEAF_DEEP, 0.3), ident)
	# Foliage hanging into the top corners and bushes along the foot.
	_corner_foliage(b, Vector2(0.0, 0.0), 1.0, seed_i + 1, clip)
	_corner_foliage(b, Vector2(w, 0.0), -1.0, seed_i + 2, clip)
	var foot := h - 10.0
	_foot_bush(b, Vector2(50.0, foot + 10.0), 110.0, seed_i + 3, clip)
	_foot_bush(b, Vector2(w - 50.0, foot + 10.0), 118.0, seed_i + 4, clip)
	_foot_bush(b, Vector2(w * 0.56, foot + 8.0), 60.0, seed_i + 5, clip)
	_foot_bush(b, Vector2(w * 0.3, foot + 12.0), 44.0, seed_i + 6, clip)
	return b.mesh() if not b.verts.is_empty() else null

## Leaves hanging in from a top corner, `out` +1 at the left and -1 at the
## right: a spray of leaves reaching down and in, deep behind and lit in front.
func _corner_foliage(b, root: Vector2, out: float, seed_i: int, clip: PackedVector2Array) -> void:
	var layers := [[Pal.LEAF_DEEP, 9, 1.0], [Pal.LEAF, 7, 0.8], [Pal.LEAF_LIGHT, 4, 0.55]]
	for li in layers.size():
		var layer: Array = layers[li]
		var n: int = layer[1]
		for q in n:
			var u := float(q) / float(n - 1)
			var ang := lerpf(0.0, PI * 0.5, u)
			if out < 0.0:
				ang = PI - ang
			ang += (_h(seed_i, q + li * 11) - 0.5) * 0.3
			var lng := 120.0 * float(layer[2]) * (0.7 + 0.5 * _h(seed_i, q + li * 11 + 40))
			var from := root + Vector2(out * 16.0 * _h(seed_i, q + 90), -10.0)
			_clip_leaf(b, from, ang, lng, lng * 0.6, layer[0], clip)

## A bush along the foot: a dome of leaves with two or three daisies on it.
func _foot_bush(b, root: Vector2, size: float, seed_i: int, clip: PackedVector2Array) -> void:
	Scenery.soft_disc(b, root + Vector2(size * 0.2, -size * 0.1), size * 1.2, size * 0.45, Color(Pal.TEXT, 0.08))
	var layers := [[Pal.LEAF_DEEP, 9, 1.0], [Pal.LEAF, 7, 0.78], [Pal.LEAF_LIGHT, 4, 0.52]]
	for li in layers.size():
		var layer: Array = layers[li]
		var n: int = layer[1]
		for q in n:
			var u := float(q) / float(n - 1)
			var ang := lerpf(-PI + 0.25, -0.25, u) + (_h(seed_i, q + li * 11) - 0.5) * 0.3
			var lng := size * float(layer[2]) * (0.75 + 0.4 * _h(seed_i, q + li * 11 + 40))
			_clip_leaf(b, root, ang, lng, lng * 0.62, layer[0], clip)
	var ident := func(p: Vector2) -> Vector2: return p
	var daisies := 2 + int(_h(seed_i, 77) * 2.0)
	for q in daisies:
		var a := lerpf(-PI + 0.6, -0.6, (float(q) + 0.5) / float(daisies))
		var at := root + Vector2.from_angle(a) * size * (0.45 + 0.25 * _h(seed_i, q + 80))
		if Geometry2D.is_point_in_polygon(at, clip):
			_append_daisy(b, at, size * 0.2, ident)

func _clip_leaf(b, root: Vector2, ang: float, lng: float, wide: float, col: Color, clip: PackedVector2Array) -> void:
	var dir := Vector2.from_angle(ang)
	var side := dir.orthogonal() * wide * 0.5
	var tip := root + dir * lng
	var pts := Face.Builder.bezier2(root, root + dir * lng * 0.45 + side, tip, 7)
	pts.append_array(Face.Builder.bezier2(tip, root + dir * lng * 0.45 - side, root, 7))
	_clip_polygon(b, pts, col, clip)

## The card's own rounded rect in design pixels, a couple of pixels inside
## its edge so a clipped shape never rides over the panel's own border.
func _clip_rect() -> PackedVector2Array:
	var pad := 2.0 / _s
	var r := maxf(CARD_RADIUS / _s - pad, 0.0)
	return Face.Builder.round_rect(Vector2(pad, pad), _dsize - Vector2(pad, pad) * 2.0, r)

static func _clip_polygon(b, points: PackedVector2Array, colour: Color, clip: PackedVector2Array) -> void:
	for piece in Geometry2D.intersect_polygons(points, clip):
		b.polygon(piece, colour)

# --- the tip card ---

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

## Idles through the band's opening tips while nothing has happened yet; the
## moment a ring is lifted or a move is logged, _settle and _tap are the only
## things allowed to speak, or a stale rule would paper over a live status
## line.
func _cycle_tip() -> void:
	if is_done() or out_of_hearts or not _state.log.is_empty() or _state.holding():
		return
	var tips := _tips()
	_tip_idx = (_tip_idx + 1) % tips.size()
	_say(tr(tips[_tip_idx]), Face.Expr.HAPPY)

# --- the state PuzzleBase asks for ---

func is_solved() -> bool:
	return _state.is_solved()

## What a reopened daily needs to look as it was left: the hearts kept and
## whether it was flawless. Plain values only (it goes through a ConfigFile).
func completion_record() -> Dictionary:
	return {"hearts": hearts, "flawless": _flawless}

## One coloured square per colour already home, in the order it actually
## came home: replays `log` from the dealt position rather than trusting
## anything stored, the same way every other derived read on this board
## does. Then the seal's words: `🙈 Hidden` for any Insane solve (and
## ` · Flawless` when it was), `🏅 Flawless` otherwise.
func share_glyphs() -> String:
	var pegs: Array = []
	for s in _state.deal:
		pegs.append((s as Array).duplicate())
	var out := ""
	var insane: bool = _state.difficulty == 3
	for m: Vector3i in _state.log:
		Gen.apply(pegs, m.x, m.y)
		if Gen.locked(pegs[m.y]):
			out += SHARE_GLYPHS[Gen.top(int(pegs[m.y][0]))]
	if (insane or _flawless) and is_solved():
		out += "\n"
	if insane and is_solved():
		out += "🙈 " + tr("RG_HIDDEN_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless and is_solved():
		out += "🏅 " + tr("BN_FLAWLESS")
	return out

## A completed daily is rebuilt from its seed, so it reopens on its deal. Put
## every colour home at once -- the solve wave already run, no entrance --
## and the party's leavings where it left them: the cat asleep by the foot
## and the seal when the solve earned one. The hearts it kept come back from
## the record. Never `check_solved()`: the host owns the win here.
func restore_completed_board() -> void:
	var t := _now()
	_gen += 1
	_close_card()
	_reset_rewards()
	hearts = clampi(int(completed_record.get("hearts", max_hearts)), 0, max_hearts)
	_flawless = bool(completed_record.get("flawless", false))
	var home: Array = []
	for c in _state.colours:
		home.append([c, c, c, c])
	while home.size() < _state.pegs.size():
		home.append([])
	_state.pegs = home
	_state.log = []
	_state.held = []
	_state.held_from = -1
	_flights = []
	_reveal_at = {}
	_lock_at = {}
	_hop_at = {}
	_shake_at = {}
	_toast = ""
	_opened = t - 10.0
	_solved_at = t - 10.0
	_cat_at = t - 100.0
	_place_cat(t)
	if _flawless or _state.difficulty == 3:
		_stamp_at = t - 100.0
	_tip_timer.stop()
	_say(tr("RG_WIN"), Face.Expr.JOY)
	_life_layer.queue_redraw()
	_heart_layer.queue_redraw()
	_refresh()

# --- the win ---

## The day's colours as rings, one per colour with its own emblem, in place
## of the sun and the moon -- flat_win()'s "characters of the answer".
func flat_win() -> Dictionary:
	var faces: Array = []
	for i in _state.colours:
		var icon := RingIcon.new()
		icon.ring_colour = RING_COLOURS[i]
		icon.emblem = i
		faces.append(icon)
	return {"faces": faces, "subtitle": tr("RG_WIN")}

## The hop wave, then the party (the hoop, the cat curling up, the seal).
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	var party := (_party_at - _now()) if _party_at < INF else PARTY_AT
	return maxf(WIN_WAIT, maxf(0.0, party) + PARTY_TIME)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# --- the hearts (polish section 1) ---

## The hearts over the pegs as one mesh on a paper pill (Pinwheel's): pink
## with a small face and a leaf, a faint ghost where one was, the lost one's
## halves falling apart, one coming back popping in. In the strip _top_pad()
## keeps clear at the top of the card.
func _draw_hearts() -> void:
	if max_moves > 0 and not _state.pegs.is_empty():
		_moves_pill.draw(_heart_layer, Vector2(_box.size.x * 0.5, HEART_ROW * 0.55 * _s), moves_left, _now())
		return
	if max_hearts <= 0 or _state.pegs.is_empty():
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var y := HEART_ROW * 0.55 * _s
	var x0 := _box.size.x * 0.5 - step * (max_hearts - 1) * 0.5
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var corner := Vector2(_box.size.x * 0.5, y) - pill * 0.5
	var rim := Vector2.ONE * HEART_PILL_RIM
	var enter := 1.0 if Motion.reduce else Motion.pop_in_scale(now - _opened - Motion.ENTER_DELAY).x
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
	var c := Vector2(_box.size.x * 0.5, y)
	_heart_layer.draw_set_transform(c * (1.0 - enter), 0.0, Vector2.ONE * enter)
	_heart_layer.draw_mesh(_hearts_shown, null)
	_heart_layer.draw_set_transform(Vector2.ZERO)

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

## The last heart is gone: dusk falls on the terrace (`out_of_hearts`), and
## the out-of-hearts card comes up.
func _run_out() -> void:
	if _asleep or not out_of_hearts or is_done():
		return
	_asleep = true
	_press_i = -1
	_break_streak()
	_clear_gags()
	_tip_timer.stop()
	fx.cue("out_of_hearts")
	_say(tr("RG_OUT_HEARTS"), Face.Expr.SLEEPY)
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
		else load(OUT_OF_HEARTS).new(_heart_used, ["RG_OUT_BODY", "RG_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same deal back in Reset's wave, every heart and the whole
## move budget back, the clock and the moves from zero. Hints spent stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	_gen += 1
	hearts = max_hearts
	moves_left = max_moves
	out_of_hearts = false
	_asleep = false
	_split_index = -1
	_busy_until = 0.0
	_state.reset_board()
	_lock_at = {}
	_hop_at = {}
	_shake_at = {}
	_refuse_to = -1
	_toast = ""
	_flights = []
	_reveal_at = {}
	_land_peg = -1
	_held_at = -100.0
	_reset_at = _now()
	_solved_at = -INF
	_reset_rewards()
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
## board. The sun comes back.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_heart_used = true
	if max_moves > 0:
		moves_left = MOVES_BONUS
		_moves_pill.bump(_now())
	else:
		hearts = 1
		_back_index = 0
		_back_at = _now()
	out_of_hearts = false
	_asleep = false
	_running = true
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	_heart_layer.queue_redraw()
	_refresh()
	_say(MovesPill.line(self, moves_left) if max_moves > 0 else tr("RG_HEART_BACK"), Face.Expr.HAPPY)
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

## Every reward's clock back to nothing: a new board, a restored one, Try
## again.
func _reset_rewards() -> void:
	_streak = 0
	_streak_gen += 1
	_drops = 0
	_gag_until = 0.0
	_gag_gen += 1
	_combo_n = 0
	_combo_at = -INF
	_combo_out_at = -INF
	_love = []
	_bees = []
	_twirl = {}
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

## The day's own number: the deal itself, so a day always plays the same gags
## and the same bit of wisdom.
func _day_hash() -> int:
	return absi(hash(_state.deal))

## A ring has landed on peg `i`: on its own colour (`onto`) it grows the
## streak -- a note up the pentatonic from the second, the bubble over the
## post from the third, confetti at 4, 7 and every 5 after, and one streak
## drop in GAG_ODDS a gag. A drop onto an empty peg is neutral; a doomed
## drop, an undo or a reset ends the streak. The winning drop does none of
## it: the party is coming.
func _on_dropped(i: int, onto: bool) -> void:
	_drops += 1
	if not onto or _state.is_solved():
		return
	_streak += 1
	var count := _streak
	var gen := _streak_gen
	var lands := _now() + (0.0 if Motion.reduce else ARC_TIME + THREAD_TIME)
	if count >= 2:
		var step: int = COMBO_STEPS[mini(count - 2, COMBO_STEPS.size() - 1)]
		_after(lands - _now() + 0.02, func() -> void:
			if gen == _streak_gen:
				fx.cue("combo", pow(2.0, step / 12.0), COMBO_DB))
	var st := _station(i)
	var top := _loc(Vector2(float(st["cx"]), float(st["top"])))
	if count >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = count
		_combo_pos = top
		_combo_at = lands
		_combo_out_at = -INF
	if _confetti_at(count) and not Motion.reduce:
		_after(lands - _now(), func() -> void:
			if gen == _streak_gen:
				fx.confetti(top, 22)
				fx.cue("confetti"))
	_start_gag(i, _pick_gag(), lands)
	_life_layer.queue_redraw()

static func _confetti_at(count: int) -> bool:
	return count == 4 or count == 7 or (count >= 10 and count % 5 == 0)

## Which gag this streak drop plays: one in GAG_ODDS, stepping round the
## kinds so any GAG_SPAN drops play each evenly. One at a time, never under
## reduce motion.
func _pick_gag() -> int:
	var t := _now()
	if Motion.reduce or t < _gag_until or force_gag == Gag.NONE:
		return Gag.NONE
	if force_gag >= 0:
		return force_gag
	var roll := posmod(_day_hash() + _drops * GAG_STEP, GAG_SPAN)
	if roll >= GAG_SPAN / GAG_ODDS:
		return Gag.NONE
	return roll % 3

## The streak ends. The bubble deflates, and a note still to play is dropped.
func _break_streak() -> void:
	_streak = 0
	_streak_gen += 1
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
	else:
		_combo_n = 0
	if _life_layer != null:
		_life_layer.queue_redraw()

## What a drop set going that an undo or a reset takes back with it.
func _clear_gags() -> void:
	_love = []
	_bees = []
	_twirl = {}
	_gag_until = 0.0
	_gag_gen += 1
	if _life_layer != null:
		_life_layer.queue_redraw()

## Peg `i`'s gag, as its ring lands: the top ring **twirls** a whole turn on
## its post (`twirl`); **love hearts** float up off the post (`love`); or a
## **bumblebee** buzzes in, loops twice round the post and drifts off (`buzz`).
func _start_gag(i: int, gag: int, lands: float) -> void:
	if gag == Gag.NONE:
		return
	var wait := maxf(0.0, lands - _now())
	var gg := _gag_gen
	var st := _station(i)
	var top := _loc(Vector2(float(st["cx"]), float(st["top"])))
	match gag:
		Gag.TWIRL:
			_twirl = {"peg": i, "at": lands + 0.05}
			_after(wait + 0.05, func() -> void:
				if gg == _gag_gen:
					fx.cue("twirl")
					fx.sparkle(top, Pal.SUN))
			_gag_until = lands + TWIRL_TIME
		Gag.LOVE:
			for k in LOVE_HEARTS:
				var side := float(k - 1)
				_love.append({"at": top + Vector2(side * 22.0, 6.0) * maxf(_s, 0.5),
					"t": lands + 0.12 * float(k), "phase": float(k) * 2.1})
			_after(wait, func() -> void:
				if gg == _gag_gen:
					fx.cue("love"))
			_gag_until = lands + 0.24 + LOVE_TIME
		Gag.BEE:
			var from := -1.0 if top.x > _box.size.x * 0.5 else 1.0
			_bees.append({"peg": i, "t": lands, "from": from})
			_after(wait, func() -> void:
				if gg == _gag_gen:
					fx.cue("buzz"))
			_gag_until = lands + BEE_IN + BEE_ROUND + BEE_OUT

# --- the party ---

## After the solve: every peg already hops on the solve wave; the sprout
## shares a bit of ring wisdom, confetti twice, a runaway hoop rolls across
## the terrace and spins down flat, the nap cat hops in by the foot and curls
## up, and the seal stamps when the solve earned one (flawless, or any
## Insane). Under reduce motion the cat and the seal are simply there.
func _party(wave: float) -> void:
	var now := _now()
	var lead := 0.0 if Motion.reduce else wave + PARTY_AT
	_party_at = now + lead
	_after(lead + 0.6, func() -> void:
		_say(_cheer(), Face.Expr.JOY))
	_cat_at = now if Motion.reduce else _party_at + CAT_AT
	if _flawless or _state.difficulty == 3:
		_stamp_at = now if Motion.reduce else _party_at + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
	if Motion.reduce:
		_life_layer.queue_redraw()
		return
	var field := Rect2(Vector2.ZERO, _box.size)
	_after(lead + 0.15, func() -> void:
		fx.confetti(Vector2(field.get_center().x, _box.size.y * 0.2), 30, _box.size.x * 0.9)
		fx.cue("party"))
	_after(lead + 0.7, func() -> void:
		fx.confetti(field.get_center(), 24, _box.size.x * 0.7))
	_after(lead + HOOP_AT, fx.cue.bind("hoop"))
	_life_layer.queue_redraw()

## One of CHEERS silly bits of ring wisdom, picked by the deal itself.
func _cheer() -> String:
	return tr("RG_CHEER_%d" % posmod(_day_hash(), CHEERS))

## The terrace under the second plank, in the control's pixels: where the hoop
## rolls and the cat curls up.
func _foot_y() -> float:
	var g1: float = _ground[1]
	return minf((g1 + SHELF_H + 44.0) * _s, _box.size.y - _cat_px() * 0.42)

# --- the nap cat ---

func _cat_px() -> float:
	return _box.size.x * CAT_PX

func _cat_spot() -> Vector2:
	return Vector2(_box.size.x * 0.2, _foot_y())

func _cat_start() -> Vector2:
	return Vector2(_cat_px() * 0.5 + 6.0, _foot_y())

func _cat_walk() -> float:
	return CAT_POP + CAT_HOPS * CAT_HOP_TIME

## Puts the cat where her clock says: nowhere yet; popping up at the edge;
## hopping along the foot; landing with a squash; curled up asleep, purring.
## Under reduce motion she is simply curled up there.
func _place_cat(t: float) -> void:
	if t < _cat_at or _box.size.x <= 0.0:
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
			_cat.position = _box.position + _cat_spot() - _cat.size * 0.5
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
	_cat.position = _box.position + at - _cat.size * Vector2(0.5, 0.5)
	_cat.scale = sc

## She curls up: the sleepy face and the drifting "z", and a purr -- unless
## she was already asleep when the board opened (a restore), who is quiet.
func _curl_cat(quiet: bool) -> void:
	_cat_curled = true
	_cat.expression = Face.Expr.SLEEPY
	_cat.scale = Vector2.ONE
	_cat.rotation = 0.0
	_cat.position = _box.position + _cat_spot() - _cat.size * 0.5
	if not quiet:
		fx.cue("purr")

# --- the life over the pegs ---

## Drops what has finished and says whether anything on the life layer still
## moves.
func _tick_life(now: float) -> bool:
	_love = _love.filter(func(l): return now < float(l.t) + LOVE_TIME)
	_bees = _bees.filter(func(f): return now < float(f.t) + BEE_IN + BEE_ROUND + BEE_OUT)
	var party := not Motion.reduce and now >= _party_at - 0.05 and now < _party_at + PARTY_TIME + 0.5
	return not (_love.is_empty() and _bees.is_empty()) or party \
		or (_combo_n >= COMBO_FROM and (now - _combo_at < COMBO_HOLD + 0.1 or _combo_out_at > -INF)) \
		or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1)

## Each thing one cached mesh through a transform: love hearts, bees, the
## hoop, then the seal and the streak's bubble with their words.
func _draw_life() -> void:
	if _state.pegs.is_empty() or _box.size.x <= 0.0:
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
			var at: Vector2 = l.at + Vector2(sin(u * TAU + float(l.phase)) * 14.0,
				-LOVE_RISE * _s * (1.0 - (1.0 - u) * (1.0 - u)))
			var k := Motion.pop_in_scale(e, 0.2).x
			_life_layer.draw_mesh(mesh, null, Transform2D(sin(u * TAU) * 0.2, Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.4, 0.0, 1.0)))
	for f in _bees:
		_draw_bee(f, now, shown)
	if not Motion.reduce and now >= _party_at + HOOP_AT and now < _party_at + HOOP_AT + HOOP_TIME:
		_draw_hoop(now - _party_at - HOOP_AT, shown)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_draw_combo(now, shown)
	_life_shown = shown

## A little pink heart for the love gag, built once a layout.
func _love_heart() -> ArrayMesh:
	if _love_mesh == null:
		var b := Face.Builder.new()
		var r := LOVE_R * maxf(_s, 0.6)
		b.polygon(_heart(Vector2.ZERO, r * 1.15, 0), Pal.FLOWER_DEEP)
		b.polygon(_heart(Vector2.ZERO, r, 0), Pal.FLOWER)
		b.ellipse(Vector2(-0.45, -0.45) * r, 0.18 * r, 0.1 * r, Color(1.0, 1.0, 1.0, 0.5))
		_love_mesh = b.mesh()
	return _love_mesh

# --- the bee ---

func _bee_px() -> float:
	return BEE_PX * maxf(_s, 0.6)

## A round bumblebee drawn in code, facing +x: a butter body with two cocoa
## stripes, a sting, a smiling face and blush. The wings are their own mesh.
func _bee() -> ArrayMesh:
	if _bee_mesh == null:
		var s := _bee_px() * 0.5
		var b := Face.Builder.new()
		b.ellipse(Vector2.ZERO, 1.04 * s, 0.8 * s, Pal.LINE)
		b.ellipse(Vector2.ZERO, 0.96 * s, 0.72 * s, Pal.SUN)
		for x in [-0.32, 0.12]:
			var band := PackedVector2Array()
			for q in 13:
				var a := lerpf(-PI * 0.5, PI * 0.5, float(q) / 12.0)
				band.append(Vector2(x * s + cos(a) * 0.1 * s, sin(a) * 0.7 * s * sqrt(maxf(0.0, 1.0 - x * x))))
			b.stroke(band, 0.18 * s, Pal.ACORN_DEEP)
		b.polygon(PackedVector2Array([Vector2(-0.95, -0.12) * s, Vector2(-1.3, 0.0) * s, Vector2(-0.95, 0.12) * s]), Pal.ACORN_DEEP)
		b.disc(Vector2(0.62, -0.14) * s, 0.1 * s, Pal.OUTLINE)
		b.stroke(Face.Builder.arc_points(Vector2(0.58, 0.08) * s, 0.14 * s, PI * 0.15, PI * 0.75), 0.07 * s, Pal.OUTLINE)
		b.ellipse(Vector2(0.4, 0.2) * s, 0.12 * s, 0.07 * s, Color(Pal.FLOWER, 0.7))
		b.ellipse(Vector2(-0.2, -0.45) * s, 0.25 * s, 0.1 * s, Color(1.0, 1.0, 1.0, 0.45))
		_bee_mesh = b.mesh()
	return _bee_mesh

## One wing, its root at the origin, reaching up.
func _bee_wing() -> ArrayMesh:
	if _wing_mesh == null:
		var s := _bee_px() * 0.5
		var b := Face.Builder.new()
		b.ellipse(Vector2(0.0, -0.55) * s, 0.42 * s, 0.6 * s, Color(Pal.LINE, 0.55))
		b.ellipse(Vector2(0.0, -0.55) * s, 0.36 * s, 0.54 * s, Color(1.0, 1.0, 1.0, 0.85))
		_wing_mesh = b.mesh()
	return _wing_mesh

## The bee's clock: in along an arc from the side of the card away from the
## post, twice round the post top (in front and behind, smaller behind), and
## off up and out the same side, its wings a blur the whole way.
func _draw_bee(f: Dictionary, now: float, shown: Array) -> void:
	var e := now - float(f.t)
	if e <= 0.0:
		return
	var st := _station(int(f.peg))
	var post := _loc(Vector2(float(st["cx"]), float(st["top"]) - 10.0))
	var rx := RING_W * 0.42 * _s
	var ry := RING_W * 0.14 * _s
	var side := float(f.from)
	var far := post + Vector2(side * _box.size.x * 0.45, -RING_W * _s * 0.8)
	var at := post
	var face := -side
	var depth := 1.0
	var entry := post + Vector2(side * rx, 0.0)
	if e < BEE_IN:
		var u := e / BEE_IN
		var w := 1.0 - (1.0 - u) * (1.0 - u)
		at = far.lerp(entry, w) + Vector2(0.0, -sin(u * PI) * 30.0 * _s)
	elif e < BEE_IN + BEE_ROUND:
		var u := (e - BEE_IN) / BEE_ROUND
		var a := u * TAU * 2.0
		at = post + Vector2(side * cos(a) * rx, sin(a) * ry + sin(a * 3.0) * 6.0)
		face = -side * signf(sin(a) + 0.001)
		depth = 0.85 + 0.15 * sin(a)
	else:
		var u := (e - BEE_IN - BEE_ROUND) / BEE_OUT
		at = entry.lerp(far + Vector2(0.0, -RING_W * _s), u * u) + Vector2(0.0, sin(u * TAU * 2.0) * 8.0)
		face = side
	at.y += sin(e * 9.0) * 3.0
	var body := _bee()
	var wing := _bee_wing()
	shown.append(body)
	shown.append(wing)
	var flap := 0.5 + 0.5 * absf(sin(e * 38.0))
	var sc := Vector2(face * depth, depth)
	_life_layer.draw_mesh(wing, null, Transform2D(-0.35 * face, Vector2(depth, flap * depth), 0.0, at + Vector2(-2.0 * face, -6.0)))
	_life_layer.draw_mesh(body, null, Transform2D(0.0, sc, 0.0, at))
	_life_layer.draw_mesh(wing, null, Transform2D(0.25 * face, Vector2(depth, flap * depth), 0.0, at + Vector2(4.0 * face, -6.0)))

# --- the runaway hoop ---

## A ring stood on its edge, seen from the front: a fat wooden hoop in the
## day's own colour with four cream inlays that show it rolling.
func _hoop() -> ArrayMesh:
	if _hoop_mesh == null:
		var r := _hoop_r()
		var col: Color = RING_COLOURS[posmod(_day_hash(), _state.colours)]
		var b := Face.Builder.new()
		var circle := Face.Builder.ring(Vector2.ZERO, r, r)
		b.stroke(circle, r * 0.34, col.lerp(Pal.TEXT, 0.26), true)
		b.stroke(circle, r * 0.26, col, true)
		b.stroke(Face.Builder.arc_points(Vector2.ZERO, r * 1.04, PI * 1.1, PI * 1.6), r * 0.07, Color(1.0, 1.0, 1.0, 0.5))
		for q in 4:
			b.disc(Vector2.from_angle(TAU * float(q) / 4.0) * r, r * 0.08, Color(col.lerp(Color.WHITE, 0.78), 0.95))
		_hoop_mesh = b.mesh()
	return _hoop_mesh

func _hoop_r() -> float:
	return RING_W * 0.3 * _s

## The hoop's run: in from the left, rolling and slowing across the foot of
## the terrace, a wobble as it runs out of roll, and down flat on the stones
## (its height closing to a sliver), then it fades.
func _draw_hoop(e: float, shown: Array) -> void:
	var r := _hoop_r()
	var u := clampf(e / HOOP_TIME, 0.0, 1.0)
	var run := minf(u / 0.72, 1.0)
	var x0 := -r * 1.4
	var x1 := _box.size.x * 0.66
	var x := lerpf(x0, x1, 1.0 - pow(1.0 - run, 2.2))
	var roll := (x - x0) / r
	var ground := _foot_y() + _cat_px() * 0.25
	var at := Vector2(x, ground - r)
	var sc := Vector2.ONE
	var tilt := 0.0
	var alpha := 1.0
	if u > 0.62:
		var w := (u - 0.62) / 0.38
		tilt = sin(w * 18.0) * 0.25 * (1.0 - w)
		sc = Vector2(1.0, lerpf(1.0, 0.22, w * w))
		at.y = ground - r * sc.y
		alpha = clampf((1.0 - u) / 0.12, 0.0, 1.0)
	var mesh := _hoop()
	shown.append(mesh)
	_life_layer.draw_set_transform(at, tilt, sc)
	_life_layer.draw_mesh(mesh, null, Transform2D(roll, Vector2.ZERO), Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform(Vector2.ZERO)

# --- the bubble and the seal ---

## The streak's paper bubble over the post, "x3" and up in leaf ink: it pops
## in the first time, bumps at each streak drop and deflates when the streak
## ends. Rebuilt only when its words or its tail change (Quilt's).
func _draw_combo(now: float, shown: Array) -> void:
	if _combo_n < COMBO_FROM or now < _combo_at:
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
	centre.x = clampf(centre.x, box.x * 0.5 + 4.0, _box.size.x - box.x * 0.5 - 4.0)
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

## The seal at the card's lower right, dropping in from STAMP_FROM its size
## and settling with the back ease's overshoot, its words over it: Flawless;
## on Insane "Insane" over Flawless or Hidden, on the night seal.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := _box.size.x * STAMP_R * 0.75
	var insane: bool = _state.difficulty == 3
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := Vector2(_box.size.x - rad * 1.15, minf(_foot_y(), _box.size.y - rad * 1.1))
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless else tr("RG_HIDDEN_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

## A ring drawn on its own, for the win screen's cast: the board's own donut
## (`_append_donut`, reached through the script's own path because a nested
## class cannot call the outer script's statics unqualified), scaled to
## whatever square seat well_done.gd hands it.
class RingIcon extends Control:
	var ring_colour: Color = Color.WHITE
	var emblem: int = 0
	## Set by ui/flat/well_done.gd's set_cast on every face it seats; a ring
	## has no expression of its own, but the property has to exist.
	var expression: int = 0
	## Kept past the frame that builds it -- a canvas command holds a mesh by
	## RID, not by reference.
	var _mesh: ArrayMesh

	## well_done.gd's enter() calls this on every face it seats; a ring has
	## nothing to idle.
	func set_idle(_on: bool) -> void:
		pass

	func _draw() -> void:
		var board = load("res://puzzles/rings2d.gd")
		var w := size.x * 0.9
		var tall: float = (board.SIDE + 2.0 * board.FACE) * w
		var yt: float = (size.y - tall) * 0.5 + board.FACE * w
		var b := Face.Builder.new()
		var ident := func(p: Vector2) -> Vector2: return p
		board._append_donut(b, size.x * 0.5, yt, w, ring_colour, emblem, 1.0, ident)
		_mesh = b.mesh()
		if _mesh != null:
			draw_mesh(_mesh, null)

## The day as dealt, for tools/export_days.gd: a column a peg, its top ring
## on top, a face-down ring noted "?". The answer is the
## hint's own line from the deal (`Gen.solve`: a way home, not the shortest)
## and the pegs it ends on.
func day_dict() -> Dictionary:
	if _state.deal.is_empty():
		return {}
	var deal: Array = _state.deal
	var cap: int = Gen.CAP
	var end: Array = []
	var rings := 0
	for s: Array in deal:
		end.append(s.duplicate())
		rings += s.size()
	var line: Array = []
	for m: Vector2i in Gen.solve(deal):
		Gen.apply(end, m.x, m.y)
		line.append([m.x, m.y])
	var slot := func(peg: Array, k: int) -> Dictionary:
		if k >= peg.size():
			return {}
		var ring := int(peg[k])
		var cell := {"c": Gen.top(ring)}
		if Gen.hidden(ring):
			cell["note"] = "?"
		return cell
	var puzzle: Array = []
	var answer: Array = []
	for y in cap:
		for x in deal.size():
			puzzle.append(slot.call(deal[x], cap - 1 - y))
			answer.append(slot.call(end[x], cap - 1 - y))
	var metrics := {"pegs": deal.size(), "colours": int(_state.colours), "rings": rings,
		"cap": cap, "hidden": _state.difficulty == 3, "line": line.size(),
		"hints": State.hints_for(_state.difficulty), "hearts": max_hearts, "moves": max_moves}
	if _state.par > 0:
		metrics["par"] = int(_state.par)
	return {
		"source": "generator", "kind": "grid",
		"payload": {"pegs": deal, "cap": cap},
		"solution": {"moves": line, "pegs": end} if not line.is_empty() else {},
		"metrics": metrics,
		"view": {"w": deal.size(), "h": cap, "puzzle": puzzle, "solution": answer},
	}
