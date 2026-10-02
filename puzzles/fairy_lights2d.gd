extends "res://core/puzzle_base.gd"

## Fairy Lights as a flat board: a pale garden ruled into cells, a lantern
## post in the middle, and a length of garden wire in every other cell. One
## tap turns a piece a quarter turn clockwise, and that is the only gesture
## on the screen. Wire joined all the way back to the post runs warm and
## gold; everything else is pale and cool. Done when every stub meets a stub
## and every lantern is lit. The rules live in
## puzzles/fairy_lights_state.gd, which this only draws.
##
## **The cells abut, and on this board that is not a style choice.** A wire
## crosses the cell boundary and meets the wire on the other side, so the
## 14-pixel alley Word Trail and Nonogram draw between their tiles would put
## a break in the middle of every join. The cell is a round
## `floor((1000 - 2*28) / n)` -- 188, 157, 134 -- with nothing subtracted,
## and the 6-wide fence is drawn *round* the grid rather than inside it,
## which is Sudoku's reason for Sudoku's rule.
##
## **A loose end looks loose.** A stub that meets a stub runs to the cell's
## edge and joins; a stub that meets a wall or a closed neighbour stops at
## LOOSE of the way with a round cap. It is the only thing on this board
## that says "not finished here", and it is half of what the win is defined
## by.
##
## How it is drawn (spec section 6, and section 13's second polish after the
## user's reference). **Two meshes**: a still one, built once a layout --
## the wooden frame, the grout, the paving stones and the vines -- and the
## board's own, rebuilt on change -- the warm wash on a lit stone, the pinned
## washes, the glow under every live run, the wire's shade, face and back,
## the beads and the post. The lanterns are `ui/faces/lantern_face.gd`
## Controls in its `iron` style, in slots this board owns, which is
## Untangle's arrangement, because a lantern has a face and a face is a
## Control here. **The post is in the mesh**: it is iron and glass with no
## face on it.
##
## **The order is fixed**: the glow under *every* live run before any wire,
## widest pass first; then every shade, then every face, then the beads. A
## glow drawn after the wire is a smear over it; a glow drawn per cell as the
## wire is drawn washes out its own neighbour's cable. And the glow never
## stacks round caps at a join (see `_glow`), which is what beaded the first
## pass's halo.
##
## **The spin and the wash** (spec section 7). A turn spins the piece a
## quarter turn with `back_out`'s overshoot over TURN_TIME, pulling its arms
## in ARM_PULL at the middle so it does not reach into its neighbours on the
## way round; a lantern's slot takes that turn and the paper inside it
## counter-turns, because a hanging thing does not cartwheel. Behind the spin
## runs **the wash**, which is this board's signature: Queens' `_settle` with
## the tree's own depth in place of a queen's sight. Every move diffs a
## depth snapshot taken *before* it against `state.depths()` after it, and
## hands each changed cell a moment -- `depth * WAVE_STEP` for a cell just
## reached, and the same wave **reversed, far end first**, for a cell just
## cut off, which reads as the light being pulled back rather than switched
## off.
##
## **Nothing about the wash is stored.** The board keeps the *moments*
## (`_live_at`, `_out_at`, `_wake_at`) and never the live set: what is live
## is `state.depths()`, recomputed on every build and every dress, and the
## moment only says when the eye is allowed to see it. The snapshot a settle
## diffs against is a local taken at the move and thrown away. So an undo
## needs no book to unwind and a stale set cannot exist.
##
## **While anything moves, the mesh is rebuilt every frame**, because the
## spin, the shiver and the wash are all baked into it. `_animating()` is the
## one gate on that, and **every** wave has to be inside it: they all push
## `_anim_until` out through `_busy_for`, so a new wave that forgets to call
## it freezes part-way through and shows on a rendered frame and in no test
## (One Line's two pale lines).
##
## **Keep the mesh the last `_draw` handed over.** A canvas command holds a
## mesh by RID and not by reference, so rebuilding the cache and dropping
## the previous mesh leaves the renderer drawing a freed RID -- "Parameter
## mesh is null", and an empty card -- on any frame rendered without the
## queued redraw flushed first, which is exactly what a harness's
## `force_draw()` does.
##
## Analytics need nothing here: `ui/puzzle_host.gd` already sends every event
## this board has, and there is no `check_used` because there is no Check.
##
## **The polish (2026-09-30, docs/superpowers/specs/2026-09-30-fairylights-
## polish-design.md, sections 1, 2 and 4).** Hard and Insane judge one thing,
## a turn of a piece that is already right (the state's RIGHT): **the fuse**.
## The piece starts its quarter turn, sparks fly, the whole live run flickers
## twice like a brown-out, a heart splits on the paper pill over the frame,
## and the piece swings back and a brass clip snaps onto its stone for good.
## All of it is one clock (`_fuse_at`), read by the curve readers in `_frame`,
## `_flicker` and `_sparks`, and it holds the card through `_busy_for` like
## every other wave; input, Undo, Hint and Reset wait on `_fusing()`. Out of
## hearts, **the dark** runs the wash reversed to the post (`_dark_at`, one
## more moment a cell, never a live set), dusk falls and the out-of-hearts
## card comes up -- Quilt's and Mushroom Patch's machinery, copied rather than
## reinvented. Insane's **Wish Tags** are paper labels tucked into each tagged
## lantern's lower corner on a thread, drawn in the mesh with their number as
## one draw_string each (Nonogram's clues). **The press dip** sinks and shades
## the piece under the finger (press_scale) while the turn still fires on
## release, and **the sway** rocks every lit lantern about the ring it hangs
## by, as Control transforms only, so a settled board never rebuilds its mesh
## for it.
##
## **The rewards (section 3)** hang off three hooks: `_on_turned` (the join
## sparks, and the streak read off the lanterns a turn woke or put out, with
## Quilt's combo, bubble and confetti), `_on_lantern_woke` (a moth, a hum or
## love, three lanterns in five, one a turn) and `_break_streak`. Everything
## that floats over the garden -- sparks, gags, fireflies, the bubble and the
## seal -- lives on one layer over the lanterns as a list of moments, each
## thing one cached mesh drawn through a transform. The party runs after the
## win's chase: the lanterns dance on the beat (a checkerboard, so neighbours
## are half a beat apart), fireflies rise, confetti twice, Wish Tags' tags
## flutter gold, the nap cat hops along the frame's foot and curls up, and
## the seal stamps a flawless or an Insane solve.
##
## Spec: docs/superpowers/specs/2026-09-20-fairy-lights-flat-design.md,
## sections 2, 2.1, 3, 5, 6 and 9. Ported number for number from the canvas
## mock at docs/brainstorm/concepts.html#fairylights, which is the reference
## for every measure here.

const State = preload("res://puzzles/fairy_lights_state.gd")
const Gen = preload("res://puzzles/fairy_lights_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const LanternFace = preload("res://ui/faces/lantern_face.gd")
const NapCat = preload("res://ui/faces/nap_cat.gd")
const Seal = preload("res://ui/flat/seal.gd")
const CozyTheme = preload("res://ui/theme.gd")
const RunMesh = preload("res://ui/flat/run_mesh.gd")

# --- the screen, measured (spec section 2.1) ---
## The card's own inset. The grid is what is left of the card's width, cut
## into n cells with **no gap**: 188 at 5x5, 157 at 6x6, 134 at 7x7.
const INSET := 28.0
## The terrace's corner.
const GROUND_RADIUS := 20.0
## The terrace (second polish, 2026-09-26): every cell is a paving stone
## set into a grout of `GROUT`, TILE_GAP in from its cell on every side, so
## the joins read as mortar and not as a ruled line. A stone stands TILE_LIP
## on its own darker edge, is toned off its hash within TONE so the terrace
## reads as laid by hand, and warms toward `SUN_RAY` by WARM as the light
## reaches the wire on it -- the light spilling onto the stone. The wire runs
## straight over the grout, so the joins between cells are never broken.
const TILE_GAP := 3.0
const TILE_RADIUS := 0.12
const TILE_LIP := 4.0
const TONE := 0.35
const WARM := 0.07
const GROUT := Color("e2d5ba")
const TILE_EDGE := Color("dccdb0")
## How much more the stones warm while the win's chase crosses them.
const WIN_WARM := 0.18

# --- the pieces, as fractions of a cell (all the mock's) ---
## The wire's own width, and how far a loose end falls short of the edge.
const WIRE := 0.13
const LOOSE := 0.7
## A junction of three or four arms gets a collar; a straight or an elbow
## does not, because a disc wider than the wire reads as a lump on it rather
## than as a joint.
const COLLAR := 0.62
## How far the wire's shade sits under its face, in pixels -- the soft lip
## every piece on these screens wears. The face carries a paler back, TOP of
## the wire's width and TOP_RISE of it up, so a dark wire reads as a rounded
## cable standing on the stone (the user's reference, 2026-09-26).
const SHADE_DROP := 5.0
const TOP := 0.42
const TOP_RISE := 0.16
const TOP_ALPHA := 0.35
## The highlight along a live cable's back.
const SHEEN := 0.36
const SHEEN_ALPHA := 0.8
## **The glow under a live run**, three passes wide to narrow in `SUN_RAY`.
## Each cell draws its arms as *one* polyline where it can (a straight or an
## elbow is one stroke through the middle) and every end that meets a
## neighbour is left flat, so two cells' glows abut at the edge instead of
## stacking round caps into beads, which is what the first pass's did. A tee
## or a cross doubles in the middle only, where the bead sits anyway.
const GLOWS: Array[Vector2] = [Vector2(3.4, 0.08), Vector2(2.5, 0.11), Vector2(1.7, 0.16)]
## **The beads**: bright points on a live wire, one at every join between two
## cells and one in the middle of every piece, the reference's string of
## fairy lights. BEAD of the wire's width, with a glow of BEAD_GLOW beads.
const BEAD := 0.62
const BEAD_GLOW := 2.6
const BEAD_GLOW_ALPHA := 0.5
const BEAD_SEGMENTS := 10
## A bead pops as the light reaches it, harder than the family's bump,
## because it is a small thing and 0.25 of a small thing is not seen.
const BEAD_BUMP := 0.6
## See _dot.
const DOT_POINTS := 12
const DOT_RING: Array[Vector2] = [
	Vector2(1.0, 0.0), Vector2(0.866, 0.5), Vector2(0.5, 0.866), Vector2(0.0, 1.0),
	Vector2(-0.5, 0.866), Vector2(-0.866, 0.5), Vector2(-1.0, 0.0), Vector2(-0.866, -0.5),
	Vector2(-0.5, -0.866), Vector2(0.0, -1.0), Vector2(0.5, -0.866), Vector2(0.866, -0.5),
]

# --- the frame and its dressing (the reference's wooden border) ---
## A wooden frame FRAME wide round the grid, inside the card's INSET, with a
## lit inner rail and a darker outer lip; vines of leaves and small white
## flowers hang on its corners and on a few places along it.
const FRAME := 22.0
const FRAME_RADIUS := 22.0
const RAIL := 4.0
const LEAF := 0.26
const FLOWER_R := 0.085
## A few stones carry a speck of moss or a fallen leaf, off the hash.
const SPECK_SHARE := 0.22

## A pinned cell: Word Trail's hint mark, unchanged -- a SUN_RAY wash under a
## dotted SUN_DEEP ring. Each inset from the cell's corner, its corner, and
## the dash's on and off runs.
const PIN_INSET := 6.0
const PIN_RADIUS := 0.18
const PIN_ALPHA := 0.4
const DASH_INSET := 9.0
const DASH_RADIUS := 0.16
const DASH_W := 4.0
const DASH_ON := 0.1
const DASH_OFF := 0.08
## The hint's ring, in cells.
const RING_R := 0.3

# --- the post (the mock's `postAt`, in units of its own R) ---
## The post's R, as a fraction of the cell.
const POST_R := 0.34
## Its halo: the one light on the board that is never out.
const POST_GLOW_AT := -0.3
const POST_GLOW_INNER := 0.3
const POST_GLOW_R := 2.3
const POST_GLOW_ALPHA := 0.3
const POST_SHADOW_ALPHA := 0.12
const POST_GLASS_ALPHA := 0.55

# --- the lantern (ui/faces/lantern_face.gd, exactly as Untangle ships it) ---
## A lantern's R, as a fraction of the cell. Its Control is R * SEAT square.
const LANTERN_R := 0.27

# --- this board's own motion constants (spec section 7) ---
## The quarter turn and one step of the wash per depth. They stand here
## because they are this board's signature and nothing in core/motion.gd
## would ever read them. **`WAVE_STEP` is not `Motion.WAVE_STEP`** (0.045):
## GDScript resolves the unqualified name to this script's own const, and
## this one is a step along a tree's depth rather than the king-move ring
## step that constant measures -- Word Trail's own WAVE_STEP stands apart for
## the same reason.
const TURN_TIME := 0.26
const WAVE_STEP := 0.05
## How long the win waits after the last lantern wakes.
const WIN_WAIT := 1.4
## How far a spinning piece pulls its arms in at the middle of the turn, so a
## long arm does not sweep through the cell next door on the way round. The
## mock's own 11%, and the one number the spin needs that no recipe has.
const ARM_PULL := 0.11
## How far into the spin the wash sets off. The light leaves before the piece
## has finished turning, so the two arrive together rather than in sequence.
const WASH_LAG := TURN_TIME * 0.55
## The first wash's own lead: it runs out from the post this long after the
## chrome has slid in, so the screen opens by showing where the power is.
const ENTER_WASH := 0.2
## The refusal's shiver, through the recipe's `px` parameter rather than a
## copied constant (rule 6): a cell here is 134 to 188 across, and the
## family's 2 px on a piece that wide is not a shiver, it is a rounding
## error. Four times it is the mock's own amplitude.
const REFUSE_PX := Motion.SHIVER_PX * 4.0
## How long a cell takes to come up to full light, or go down from it, once
## the wash reaches it. The first pass snapped; this is a lamp warming.
const LIGHT_FADE := 0.16
## How far a turning piece lifts off its stone at the middle of the turn, as
## a scale, and how much further its shade falls, in pixels.
const TURN_LIFT := 0.07
const LIFT_SHADE := 5.0
## **The twinkle**: at rest, one lit bulb somewhere flares every
## TWINKLE_EVERY or so (jittered by TWINKLE_JITTER either way), a star and a
## glow drawn as one cached mesh through a transform, so nothing is rebuilt
## for it. FLARE is its size in bulb radii.
const TWINKLE_EVERY := 0.9
const TWINKLE_JITTER := 0.45
const TWINKLE_IN := 0.12
const TWINKLE_OUT := 0.5
const FLARE := 2.4
## **The win's chase**: once the wash that won has landed, a light runs out
## from the post along the tree a depth every CHASE_STEP -- never more than
## CHASE_SPAN from the post to the far end, so a deep garden is inside
## WIN_WAIT -- flaring every bulb and hopping every lantern as it passes.
const CHASE_LAG := 0.15
const CHASE_STEP := 0.035
const CHASE_SPAN := 0.6
## A moment far enough in the future never to arrive, and one far enough in
## the past that every curve reader is already past the end of it.
const FAR := 1.0e9
const AGO := -1.0e9

# --- the hearts (polish section 1; Quilt's and Mushroom Patch's pill) ---
## The strip the hearts take over the frame on Hard and Insane: the grid gives
## up the room. The pill sits HEART_TOP under the card's top edge.
const HEART_ROW := 76.0
const HEART_TOP := 14.0
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
## The dark pulled back to the post never takes longer than this, however
## deep the garden: the far end goes first and the post's own cell last.
const DARK_SPAN := 0.8

# --- the fuse (polish section 1), on its own clock from the tap ---
## The piece gets FUSE_REACH of its quarter turn in FUSE_START, strains there
## with a buzz of FUSE_BUZZ radians, and swings back from FUSE_BACK over
## FUSE_BACK_TIME on back_out's overshoot. The sparks fly at FUSE_SPARK and the
## live run flickers twice over FLICKER_TIME from then, down to 1 - FLICKER_DIP
## at the bottom of each dip; the heart splits at FUSE_SPLIT and the clip
## snaps on at FUSE_CLIP. Nothing takes a tap until FUSE_END.
const FUSE_REACH := 0.38
const FUSE_START := 0.12
const FUSE_BUZZ := 0.035
const FUSE_SPARK := 0.12
const FLICKER_TIME := 0.46
const FLICKER_DIP := 0.8
const FUSE_SPLIT := 0.42
const FUSE_BACK := 0.6
const FUSE_BACK_TIME := 0.3
const FUSE_CLIP := 0.9
const FUSE_END := 1.15
## The sparks: SPARKS streaks flying SPARK_REACH of a cell off the piece's
## middle over SPARK_TIME, falling as they go.
const SPARKS := 10
const SPARK_TIME := 0.42
const SPARK_REACH := 0.8
## The brass clip on a fused piece's stone, at its upper-left corner where no
## wire ever runs: CLIP_LEN by CLIP_W of a cell, across the corner. Half as
## big again as the first pass's (0.3 by 0.15), which was a crumb at 8x8.
const CLIP_LEN := 0.45
const CLIP_W := 0.225
const CLIP_AT := 0.33
const BRASS := Color("d6a940")
const BRASS_DEEP := Color("97702a")
const BRASS_HI := Color("f7e0a0")

# --- Wish Tags (polish section 2) ---
## A tag hangs on a thread from its lantern's base and is tucked into the
## cell's lower-right corner, where no wire runs and no join sits: its middle
## TAG_AT of a cell from the cell's centre, TAG_SIZE of a cell, tilted
## TAG_TILT, its number TAG_FONT of a cell high. 1.7 times the first pass's
## paper (0.28 by 0.32, a 0.21 number, 25 px at 8x8, unreadable on the
## phone): the number is 42 px at 8x8's 117 px cell, and the paper overhangs
## the stone's lower-right edge a little rather than reach the one arm a
## lantern has.
const TAG_AT := Vector2(0.37, 0.35)
const TAG_SIZE := Vector2(0.46, 0.5)
const TAG_TILT := -0.12
const TAG_FONT := 0.36
const TAG_PAPER := Color("fbf3df")
const TAG_EDGE := Color("c9b48c")
const TAG_WARM := Color("ffe7a6")

# --- the hand, and the idle (polish section 4) ---
## How far a piece's wire goes toward its own shade at the bottom of the press.
const PRESS_SHADE := 0.55
## A lit lantern sways SWAY radians about the ring it hangs by (HOOK of its R
## above its middle), on a period of its own within SWAY_SPREAD of
## SWAY_PERIOD, easing in over SWAY_IN from its wake.
const SWAY := 0.06
const SWAY_PERIOD := 2.8
const SWAY_SPREAD := 0.5
const SWAY_IN := 0.8
const HOOK := 1.2

# --- the rewards (polish section 3; Quilt's and Mushroom Patch's) ---
## The streak: a turn that wakes a lantern plucks `combo` up the pentatonic
## from the second; the bubble from COMBO_FROM; confetti at COMBO_CONFETTI.
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0
const COMBO_CONFETTI := [4, 7]
const COMBO_DEFLATE := 0.25
const COMBO_FONT := 44
## Every new join a turn makes gives off a spark where the two stubs meet,
## JOIN_AT into the turn (the piece has landed), JOIN_TIME long, JOIN_R of a
## cell: the twinkle's own star, drawn through a transform.
const JOIN_AT := TURN_TIME * 0.8
const JOIN_TIME := 0.4
const JOIN_R := 0.2
## Gags: GAGS of every GAG_ODDS lanterns, and one a turn at most.
const GAG_ODDS := 5
const GAGS := 3
const LOVE_HEARTS := 4
const LOVE_TIME := 1.3
const LOVE_RISE := 0.8
const LOVE_R := 0.12
## The hum: the lantern trembles HUM_SHAKE radians over HUM_TIME and NOTES
## notes NOTE_H of a cell tall float up NOTE_RISE over NOTE_TIME.
const HUM_TIME := 0.9
const HUM_SHAKE := 0.07
const NOTES := 3
const NOTE_TIME := 1.5
const NOTE_RISE := 0.9
const NOTE_H := 0.24
## The moth: flutters in over MOTH_IN from MOTH_FROM cells off, circles the
## lantern MOTH_LAPS times MOTH_ORBIT of a cell out over MOTH_CIRCLE, and
## wanders off over MOTH_OUT. Its wings beat MOTH_FLAP times a second and it
## is MOTH_SPAN of a cell across.
const MOTH_IN := 0.55
const MOTH_CIRCLE := 1.7
const MOTH_OUT := 0.9
const MOTH_LAPS := 2
const MOTH_ORBIT := 0.46
const MOTH_FROM := 1.8
const MOTH_FLAP := 7.0
const MOTH_SPAN := 0.46
const MOTH_WING := Color("f1e6cd")
const MOTH_WING_DEEP := Color("c4aa80")
## The party, PARTY_AT after the winning wash has landed (the chase runs in
## between): the dance, the fireflies, confetti twice, the tags turning gold,
## the nap cat and the seal. win_delay() waits PARTY_EXTRA past WIN_WAIT.
const PARTY_AT := 0.75
const PARTY_EXTRA := 1.5
const DANCE_BEATS := 4
const DANCE_BEAT := 0.26
const DANCE_TILT := 0.2
const DANCE_HOP := 0.07
## FIREFLIES rise out of the garden from FIREFLY_AT, FIREFLY_RISE cells over
## FIREFLY_TIME, blinking; FIREFLY_R of a cell each.
const FIREFLIES := 16
const FIREFLY_AT := 0.25
const FIREFLY_TIME := 2.2
const FIREFLY_RISE := 1.4
const FIREFLY_R := 0.085
## Wish Tags' tags turn gold from TAGS_AT, TAG_STEP a depth, each fluttering
## about its eyelet over TAG_FLUTTER.
const TAGS_AT := 0.3
const TAG_STEP := 0.05
const TAG_FLUTTER := 0.7
const TAG_GOLD := Color("ffd560")
const CHEERS := 12
const STAMP_AT := 1.0
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.16
const STAMP_TILT := -0.22
## The nap cat: CAT_PX of the card's width, popping up on the frame's lower
## left corner and hopping CAT_HOPS times along its foot, CAT_HOP_H of her
## size high, then curling up to sleep.
const CAT_PX := 0.18
const CAT_AT := 0.35
const CAT_POP := 0.22
const CAT_HOPS := 3
const CAT_HOP_TIME := 0.32
const CAT_HOP_H := 0.45
const CAT_SETTLE := 0.25

const TIP_CYCLE := 8.0
const TIPS := [
	"FL_TIP_TAP",
	"FL_TIP_POST",
	"FL_TIP_WARM",
	"FL_TIP_DONE",
]
const TIPS_HEARTS := ["FL_TIP_HEARTS", "FL_TIP_TAP", "FL_TIP_POST", "FL_TIP_WARM", "FL_TIP_DONE"]
const TIPS_TAGS := ["FL_TIP_TAGS", "FL_TIP_TAGS_2", "FL_TIP_HEARTS", "FL_TIP_TAP", "FL_TIP_WARM"]

## The out-of-hearts card's Back: the host takes the board away.
signal leave

## The one truth this board draws. Named `state` because tests/_win.gd
## reaches for `_puzzle.state` on every other board.
var state = State.new()

## The board's own effects node, as on every flat board: the hint's ring and
## sparkle come through it and nowhere else.
var fx: Node2D

## The grid's size, the name the win harness and the status line read.
var n: int:
	get: return state.n

var _cell := 0.0
## The grid's top-left corner inside this Control's rect.
var _grid := Vector2.ZERO
## One slot per lantern cell, with its paper inside it: {cell index -> slot}.
## Untangle's arrangement -- the slot owns the place, the paper owns what it
## is doing inside it, so a container can never fight a moving face.
var _slots: Dictionary = {}
var _lanterns: Dictionary = {}
## Which paper each lantern wears, settled once per board so a lantern does
## not change colour when it wakes.
var _hue: Dictionary = {}

## The wash's book, and all of it is *moments* rather than state: when cell
## `i` is allowed to be seen lit, when it is allowed to go dark, and when its
## lantern wakes. What is live is never in here -- see the header.
var _live_at: PackedFloat64Array = PackedFloat64Array()
var _out_at: PackedFloat64Array = PackedFloat64Array()
var _wake_at: PackedFloat64Array = PackedFloat64Array()
## The spin: when cell `i` began turning and how many quarters it is turning
## (negative anticlockwise, which is Undo).
var _spin_at: PackedFloat64Array = PackedFloat64Array()
var _spin_q: PackedInt32Array = PackedInt32Array()
## When cell `i` was last refused, which is when its shiver began.
var _refuse_at: PackedFloat64Array = PackedFloat64Array()
## Nothing on this card moves past this second. Every wave pushes it out
## through _busy_for, and _animating() reads it and nothing else.
var _anim_until := 0.0
## When the wash now running finishes and the last lantern it wakes has
## finished waking. win_delay() spends the same figure, so the win screen and
## the wash can never disagree about how long the wash is.
var _wash_end := 0.0
## The lanterns' wake chimes still to come, oldest first: each lantern chimes
## when the wash reaches it, a little higher the further out along the wire.
var _wake_cues: Array = []
## Whether the last frame was a moving one, so the board can lay one final
## frame at rest rather than stopping wherever the clock left it.
var _moving := false
## The win's chase: when it leaves the post, and its step for this garden's
## depth. FAR until the garden is won.
var _chase_at := FAR
var _chase_step := CHASE_STEP
## The twinkle: when the one now showing began, where it is, when the next is
## due, and whether a frame with one in it still has to be cleared.
var _tw_at := AGO
var _tw_pos := Vector2.ZERO
var _tw_next := 0.0
var _tw_shown := false
## The twinkle's star and glow, built once in unit size and drawn through a
## transform, so a twinkle never rebuilds the board.
var _flare: ArrayMesh

var _opened := 0.0
var _mesh: ArrayMesh
## The mesh the last _draw actually handed to the canvas item -- see the
## header. Never dropped until the next _draw has handed one over.
var _shown: ArrayMesh
## The still mesh (see _build_still), dropped when the layout or the board
## changes, and the one the last _draw handed over, for _shown's reason.
var _still: ArrayMesh
var _still_shown: ArrayMesh
## Whether the garden mesh is owed a rebuild (`_refresh`).
var _dirty := true
## The garden at rest (`_build_rest`), the plan it was built from, and the
## one the last _draw handed over; `_rm` puts it together from shapes.
var _rest_mesh: ArrayMesh
var _rest_shown: ArrayMesh
var _rest_plan := PackedInt32Array()
var _rm := RunMesh.new(_shape)
## Each cell's stubs that meet a stub, for the build in progress.
var _mt := PackedInt32Array()
## The reference layout every garden mesh is built in (Bridges' checkup): the
## largest the board has been laid out at this deal. A smaller relayout (the
## win card) draws the same meshes under `_relay()` and builds nothing again.
var _ref_cell := 0.0
var _ref_grid := Vector2.ZERO
var _ref_n := 0
var _real := [Vector2.ZERO, 0.0]
## Every lantern, painted as one mesh by `_paint` (`_draw_lanterns`): a
## LanternFace node costs two or three draw calls, and an Insane garden hangs
## twenty of them.
var _paint: Control
var _lantern_rm := RunMesh.new(_lantern_shape)
var _lantern_ids: Dictionary = {}  # ArrayMesh -> shape id
var _lantern_meshes: Array = []     # shape id -> ArrayMesh
var _lanterns_shown: ArrayMesh
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

## The hearts (Hard and Insane): how many are left of how many, whether the
## last is gone, and the pill's own moments -- Mushroom Patch's names.
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
## Whether a fuse has ever blown on this deal (the seal reads it).
var _lost_ever := false
var _asleep := false
var _heart_card: Control
var _split_index := -1
var _split_at := AGO
var _back_index := -1
var _back_at := AGO
var _heart_layer: Control
var _hearts_shown: ArrayMesh
## The sparks fly over the lanterns, so they are a layer of their own over the
## board (a lantern is a Control and would hide its own fuse), drawn only
## while a fuse blows.
var _spark_layer: Control
var _sparks_shown: ArrayMesh
var _hearts_y := 0.0
var _dusk_tw: Tween
## Bumped on every deal, so an `_after` from the last one never lands.
var _gen := 0
## The fuse now blowing: its cell, when it was tapped, and when the card
## takes taps again. -1 / AGO / 0 when there is none.
var _fuse_cell := -1
var _fuse_at := AGO
var _fuse_end := 0.0
## When each cell's clip snapped on (AGO for one that is simply there), and
## when each cell goes dark as the hearts run out (FAR: it does not).
var _clip_at: PackedFloat64Array = PackedFloat64Array()
var _dark_at: PackedFloat64Array = PackedFloat64Array()
## The press: the cell under the finger, when it landed, and when it lifted
## (-1 while it is still down).
var _press_cell := -1
var _press_down := AGO
var _press_up := -1.0
## The touch index of the finger that is down (-1 for the mouse).
var _press_finger := -1

## The rewards (polish section 3). Whether the solve was flawless and whether
## an undo was ever taken (Easy and Medium's measure of it); the streak, and a
## count bumped every time it breaks so a note or a bubble scheduled for a
## wake that has since been undone never lands; the turn the last gag played
## on (one a turn); the bubble's own moments (Quilt's names).
var _flawless := false
var _undo_ever := false
var _streak := 0
var _streak_gen := 0
var _gag_turn := -1
var _combo_n := 0
var _combo_at := -INF
var _combo_pos := Vector2.ZERO
var _combo_popped := false
var _combo_out_at := -INF
var _combo_shown: ArrayMesh
var _combo_key: Array = []
## The life over the garden, a layer over the lanterns: the join sparks, the
## gags, the fireflies, the bubble and the seal. Each list holds moments only,
## and every mesh in it is built once a layout and drawn through a transform.
var _life_layer: Control
var _life_shown: Array = []
var _life_alive := false
var _joins: Array = []      # [{"at", "t"}]
var _love: Array = []       # [{"at", "t", "phase"}]
var _notes: Array = []      # [{"at", "t", "phase", "side"}]
var _moths: Array = []      # [{"c", "t", "from", "a0", "dir", "away"}]
var _flies: Array = []      # [{"at", "t", "phase", "drift"}]
var _hum: Dictionary = {}   # lantern cell -> when it hummed
var _love_mesh: ArrayMesh
var _note_mesh: ArrayMesh
var _moth_mesh: ArrayMesh
var _fly_mesh: ArrayMesh
var _seal_mesh: ArrayMesh
## The party's moments: the dance, the tags turning gold, the seal and the
## cat, each INF until the party sets it.
var _dance_at := INF
var _gold_at := INF
var _stamp_at := INF
var _cat: Control
var _cat_at := INF
var _cat_curled := false

func puzzle_id() -> String: return "fairylights"
func title() -> String: return "Fairy Lights"

## The rules in plain words, then the band's own closing: the tags on Wish
## Tags, and either what a heart is for or that nothing here can be lost.
func rules() -> String:
	var out := tr("FL_RULES")
	if state.wish_tags():
		out += "\n\n" + tr("FL_RULES_TAGS")
	if max_hearts > 0:
		out += "\n\n" + tr("FL_RULES_HEARTS") % max_hearts
	else:
		out += "\n\n" + tr("FL_RULES_SAFE")
	return out

## The lines the tips cycle: Wish Tags leads with the tags' two and the
## hearts', a judged garden with the hearts'.
func _tips() -> Array:
	if state.wish_tags():
		return TIPS_TAGS
	if max_hearts > 0:
		return TIPS_HEARTS
	return TIPS

## The tutorial, a page a rule, each played on a little garden of its own
## (`ui/hud/fairylights_tutorial_diagram.gd`): a tap turns a piece and joined
## wire runs gold, done when every lantern is lit, what a turn of a right
## piece costs on a judged band, Wish Tags' tags, Undo and Reset, and the
## bulb on a band that has hints.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/fairylights_tutorial_diagram.gd")
	var band: int = state.band
	var hints: int = State.hints_for(band)
	var judged := State.hearts_for(band) > 0
	var steps := [
		[Diagram.Lesson.TURN, "HTP_FL_TURN", tr("HTP_FL_TURN_BODY")],
		[Diagram.Lesson.DONE, "HTP_FL_DONE", tr("HTP_FL_DONE_BODY")],
	]
	if judged:
		steps.append([Diagram.Lesson.HEARTS, "HTP_TN_HEARTS",
			tr("FL_RULES_HEARTS") % State.hearts_for(band)])
	if band == 3:
		steps.append([Diagram.Lesson.TAGS, "HTP_FL_TAGS", tr("FL_RULES_TAGS")])
	steps.append([Diagram.Lesson.UNDO, "HTP_WT_UNDO",
		tr("HTP_FL_UNDO_BODY_JUDGED") if judged else tr("HTP_FL_UNDO_BODY")])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_FL_HINT_BODY_ONE") if hints == 1 else tr("HTP_FL_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = band
		d.hearts = State.hearts_for(band)
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Undo and Hint, and nothing else. There is no Check because nothing wrong
## can exist on this board: a garden is unfinished or it is done. So the
## registry drops the actions row and Reset rides up into the top bar --
## Untangle's and Word Trail's shape, reached by a third route.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

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
	_heart_layer = Control.new()
	_heart_layer.name = "Hearts"
	_heart_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heart_layer.z_index = 1
	_heart_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_heart_layer.draw.connect(_draw_hearts)
	add_child(_heart_layer)
	_spark_layer = Control.new()
	_spark_layer.name = "Sparks"
	_spark_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spark_layer.z_index = 2
	_spark_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spark_layer.draw.connect(_draw_sparks)
	add_child(_spark_layer)
	_life_layer = Control.new()
	_life_layer.name = "Life"
	_life_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_life_layer.z_index = 3
	_life_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_life_layer.draw.connect(_draw_life)
	add_child(_life_layer)
	# Under the slots in the tree, so a lantern its own node draws (a pressed
	# one) hangs over the painted ones, as it would have anyway.
	_paint = Control.new()
	_paint.name = "Lanterns"
	_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paint.draw.connect(_draw_lanterns)
	add_child(_paint)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	_close_card()
	state.start(rng, difficulty, bank_step)
	_dealt()
	_enter()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()

## Everything a garden now in `state` needs before it is shown: its hearts,
## clean clocks and rewards, its lanterns' papers and nodes, and a layout of
## its own. A deal's (`build`) and the tutorial's hand-dealt gardens'.
func _dealt() -> void:
	max_hearts = State.hearts_for(state.band) if state.judged else 0
	_heart_used = false
	_lost_ever = false
	_deal()
	_clear_clocks()
	_reset_rewards()
	_hue = {}
	for i in state.lanterns():
		# Settled once, off the cell and the board, so a lantern keeps its
		# paper when it wakes and two boards of the same day agree.
		_hue[i] = posmod(hash(Vector2i(i, state.post * 31 + state.n)),
			Pal.LANTERN_PAPER.size())
	_build_lanterns()
	# A new deal is a new reference layout: its stones are its own.
	_ref_cell = 0.0
	_layout()

## The garden as it is dealt, and as Try again deals it back: every heart, the
## day's light, nothing splitting and no card.
func _deal() -> void:
	hearts = max_hearts
	out_of_hearts = false
	_asleep = false
	_split_index = -1
	_back_index = -1
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	if _heart_layer != null:
		_heart_layer.queue_redraw()

## Every clock on the board back to "has not happened yet". A cell that has
## never been lit waits FAR, so it is never seen lit; every other clock sits
## AGO, long enough ago that its curve reader hands back the resting value.
func _clear_clocks() -> void:
	var cells: int = maxi(0, state.n * state.n)
	_live_at = PackedFloat64Array()
	_live_at.resize(cells)
	_live_at.fill(FAR)
	_out_at = PackedFloat64Array()
	_out_at.resize(cells)
	_out_at.fill(AGO)
	_wake_at = PackedFloat64Array()
	_wake_at.resize(cells)
	_wake_at.fill(AGO)
	_wake_cues = []
	_spin_at = PackedFloat64Array()
	_spin_at.resize(cells)
	_spin_at.fill(AGO)
	_refuse_at = PackedFloat64Array()
	_refuse_at.resize(cells)
	_refuse_at.fill(AGO)
	_spin_q = PackedInt32Array()
	_spin_q.resize(cells)
	_spin_q.fill(0)
	_clip_at = PackedFloat64Array()
	_clip_at.resize(cells)
	_clip_at.fill(AGO)
	_dark_at = PackedFloat64Array()
	_dark_at.resize(cells)
	_dark_at.fill(FAR)
	_fuse_cell = -1
	_fuse_at = AGO
	_fuse_end = 0.0
	_press_cell = -1
	_press_down = AGO
	_press_up = -1.0
	_anim_until = 0.0
	_wash_end = 0.0
	_moving = false
	_chase_at = FAR
	_tw_at = AGO
	_tw_shown = false

# --- the cast ---

## One slot per degree-1 cell, with Untangle's paper lantern inside it. The
## slot stands on the cell's centre and the paper hangs in the middle of it,
## so a turn can spin the slot while the paper stays level (spec section 7);
## for now neither moves.
func _build_lanterns() -> void:
	for slot: Control in _slots.values():
		slot.queue_free()
	_slots = {}
	_lanterns = {}
	for i in state.lanterns():
		var slot := Control.new()
		slot.name = "slot_%d" % i
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)
		var lantern := LanternFace.new()
		lantern.name = "lantern_%d" % i
		lantern.hue = int(_hue.get(i, 0))
		lantern.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# An unlit lantern is `plain`: no face at all. The face is what
		# waking up looks like, so a dark garden is quiet paper and no eyes.
		lantern.plain = true
		# And it is washed out (spec section 5: the paper pair 55% toward
		# STONE, its deep edge half-way to FLAGSTONE). A garden is mostly
		# unlit, so full-saturation paper would neither read as dark nor let
		# the gold be told from an unlit amber, which is this screen's one
		# job. `dims` is off everywhere else.
		lantern.dims = true
		# The reference's garden lantern: glass under iron, and every third
		# or so grown over with a sprig.
		lantern.iron = true
		lantern.sprig = posmod(hash(Vector2i(i, state.n)), 3) == 0
		slot.add_child(lantern)
		_slots[i] = slot
		_lanterns[i] = lantern
	if _paint != null:
		_paint.queue_redraw()

# --- layout ---

## The cell: a round `floor((card - 2 * INSET) / n)` with **no gap taken
## out** -- 188, 157 and 134 by band, the largest any flat board has asked
## for. The width binds at every band while the board is played, as it does
## on Word Trail: seven columns is fewer than nine and the slot is tall. The
## win screen's slot is shorter than the card is wide, so the height is a
## bound too, or the grid runs out of its card under the stats.
func _cell_for(available: float) -> float:
	if state.n <= 0:
		return 0.0
	var room := minf(size.x, available - _heart_row()) - 2.0 * _inset()
	return floorf(maxf(0.0, room) / float(state.n))

## The card this board wants: the grid and its two insets, and the hearts'
## strip on a garden that has them, and no more. The air the card does not
## want is halved above and below by the host -- Tents' and Queens'
## arrangement, not a new one.
func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * float(state.n) + 2.0 * _inset() + _heart_row())

## The strip the hearts take over the frame, on a garden that has them.
func _heart_row() -> float:
	return HEART_ROW if max_hearts > 0 else 0.0

## The air between the card's edge and the grid, the frame inside it. A
## hook for the tutorial's page, which has less of it to spare.
func _inset() -> float:
	return INSET

## The middle of the hearts' pill: centred over the frame. A hook for the
## tutorial's page, which hangs it beside the garden.
func _hearts_at() -> Vector2:
	return Vector2(size.x * 0.5, _hearts_y)

func card_centred() -> bool:
	return true

func _layout() -> void:
	if state.n <= 0:
		return
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var span := _cell * float(state.n)
	# Centred in whatever height the card ended up with as well as across
	# it, so the grid is square in its card whether or not the host trimmed
	# the card to card_height().
	var row := _heart_row()
	var tall := minf(size.y, span + 2.0 * _inset() + row)
	var top := (size.y - tall) * 0.5
	_grid = Vector2(size.x * 0.5 - span * 0.5, top + _inset() + row)
	_hearts_y = top + HEART_TOP + HEART_R + HEART_PILL_PAD.y
	if _heart_layer != null:
		_heart_layer.queue_redraw()
	# A deal, or a layout bigger than the reference, takes a new reference;
	# a smaller one (the win card) draws the meshes it has, scaled.
	if _ref_cell <= 0.0 or _cell > _ref_cell or _ref_n != state.n:
		_ref_cell = _cell
		_ref_grid = _grid
		_ref_n = state.n
		_still = null
		_rm.reset()
		_rest_plan = PackedInt32Array()
		_rest_mesh = null
	_love_mesh = null
	_note_mesh = null
	_moth_mesh = null
	_fly_mesh = null
	_seal_mesh = null
	_combo_shown = null
	if is_instance_valid(_cat):
		_place_cat(_now())
	if _life_layer != null:
		_life_layer.queue_redraw()
	var seat: float = _cell * LANTERN_R * LanternFace.SEAT
	for i in _slots:
		var slot: Control = _slots[i]
		slot.position = cell_centre(i)
		var lantern: Control = _lanterns[i]
		lantern.size = Vector2.ONE * seat
		lantern.pivot_offset = lantern.size * 0.5
		lantern.position = -lantern.size * 0.5
	_refresh()

## The centre of cell `i`, in this Control's coordinates.
func cell_centre(i: int) -> Vector2:
	if state.n <= 0:
		return Vector2.ZERO
	return _grid + Vector2(float(i % state.n) + 0.5, float(i / state.n) + 0.5) * _cell

## Control-local point over the centre of cell (row, column) -- the name
## every flat board gives it, and the one the win harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return cell_centre(r * state.n + c)

## The cell under a local point, or -1. The cells abut, so there is no alley
## to fall between: anything inside the grid belongs to exactly one cell.
func _cell_at(local: Vector2) -> int:
	if _cell <= 0.0 or state.n <= 0:
		return -1
	var p := (local - _grid) / _cell
	var c := int(floor(p.x))
	var r := int(floor(p.y))
	if c < 0 or r < 0 or c >= state.n or r >= state.n:
		return -1
	return r * state.n + c

# --- the frame ---

## While anything is moving the whole card is rebuilt every frame -- the
## spin, the shiver and the wash are all baked into the mesh -- and the
## lanterns are placed with it. The frame after the last wave ends is laid
## once more, so nothing is left a pixel out from wherever the clock stopped.
func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0 or state.n <= 0:
		return
	var t := _now()
	while not _wake_cues.is_empty() and t >= float(_wake_cues[0].at):
		var due: Dictionary = _wake_cues.pop_front()
		fx.cue("wake", float(due.pitch))
		_on_lantern_woke(int(due.cell), bool(due.by_turn))
	# The pill pops in with the grid, then stands until a heart moves.
	if (_split_index >= 0 and t - _split_at < SPLIT_TIME + 0.1) \
			or (_back_index >= 0 and t - _back_at < HEART_BACK_TIME + 0.1) \
			or t - _opened < Motion.ENTER_DELAY + Motion.POP_IN + 0.1:
		_heart_layer.queue_redraw()
	if _fuse_cell >= 0 and t - _fuse_at < FUSE_SPARK + SPARK_TIME + 0.1:
		_spark_layer.queue_redraw()
	# One more redraw once the life goes quiet, so its last frame is not left
	# standing.
	var alive := _tick_life(t)
	if alive or _life_alive:
		_life_layer.queue_redraw()
	_life_alive = alive
	if t >= _cat_at and not _cat_curled:
		_place_cat(t)
	if _animating(t):
		_moving = true
		_dress(t)
		_refresh()
	elif _moving:
		_moving = false
		_dress(t)
		_refresh()
	else:
		_twinkle(t)
		_sway_all(t)

## At rest, every lit lantern sways on its own clock. Control transforms and
## nothing else: the mesh is not rebuilt and nothing is redrawn for it.
func _sway_all(t: float) -> void:
	if Motion.reduce:
		return
	var any := false
	for i in _lanterns:
		var live := not (_lanterns[i] as LanternFace).plain
		_hang(i, t, live)
		any = any or live
	# The painted lanterns follow: only a lit one sways (or blinks).
	if any:
		_paint.queue_redraw()

## Lantern `i` in its slot at `t`: level against the slot's turn, plus its
## sway about the ring it hangs by. The paper's pivot is its middle (the
## entrance's pop and the counter-turn need that), so a swing about the ring
## is the same turn about the middle and the middle moved by what the ring
## would have moved -- worked out in the slot's own turned frame. The hum's
## tremble and the party's dance ride the same swing, the dance's hop lifting
## the paper off its ring.
func _hang(i: int, t: float, live: bool) -> void:
	var lantern: Control = _lanterns[i]
	var slot: Control = _slots[i]
	var dance := _dance_pose(i, t) if live else Vector2.ZERO
	var s := (_sway(i, t) + _hum_shake(i, t) + dance.x) if live else 0.0
	lantern.rotation = -slot.rotation + s
	var hook := Vector2(0.0, -HOOK * lantern.size.x * LanternFace.RATIO)
	lantern.position = -lantern.size * 0.5 \
		+ (hook - hook.rotated(s) - Vector2(0.0, dance.y)).rotated(-slot.rotation)

## Lantern `i`'s sway at `t`: SWAY on a period and phase of its own off the
## cell's hash, eased in from its wake so a waking lantern does not jump.
func _sway(i: int, t: float) -> float:
	if Motion.reduce:
		return 0.0
	var h: int = absi(hash(Vector2i(i, 977 + state.n)))
	var period := SWAY_PERIOD * (1.0 + SWAY_SPREAD * (float(h % 100) / 100.0 - 0.5))
	var phase := float((h / 100) % 628) / 100.0
	var grow := clampf((t - _wake_at[i]) / SWAY_IN, 0.0, 1.0)
	return SWAY * grow * sin(TAU * t / period + phase)

## At rest, one lit bead somewhere flares now and then. The board is not
## rebuilt for it: _draw lays the cached flare over the cached mesh, so a
## twinkle costs a redraw and one draw call while it shows. Nothing under
## reduce-motion, and none while anything else moves (the process above).
func _twinkle(t: float) -> void:
	if Motion.reduce:
		return
	if t - _tw_at < TWINKLE_IN + TWINKLE_OUT:
		_tw_shown = true
		queue_redraw()
		return
	if _tw_shown:
		_tw_shown = false
		queue_redraw()
	if t < _tw_next:
		return
	_tw_next = t + TWINKLE_EVERY + randf_range(-TWINKLE_JITTER, TWINKLE_JITTER)
	var spots := PackedVector2Array()
	var depths: PackedInt32Array = state.depths()
	for i in state.n * state.n:
		if depths[i] < 0:
			continue
		if i != state.post and not _lanterns.has(i):
			spots.append(cell_centre(i))
		for d in [1, 2]:
			if state.grid[i] & (1 << d) and state.matched(i, 1 << d):
				spots.append(cell_centre(i) + _arm_end(i, d, 1.0))
	if spots.is_empty():
		return
	_tw_pos = spots[randi() % spots.size()]
	_tw_at = t
	_tw_shown = true
	queue_redraw()

## Whether anything on this card is still moving: the entrance, or a wave
## that has not run out yet. **Every** wave has to be accounted for here --
## One Line shipped two lines frozen at four fifths of a fade because one was
## left out, and it showed in a rendered frame and in no test. They are, and
## without a line each: the spin, the wash, a lantern waking, a refusal's
## shiver, Reset's stagger and the solve all end by pushing `_anim_until` out
## through `_busy_for`, so a wave added later is covered the moment it says
## how long it lasts.
func _animating(t: float) -> bool:
	if Motion.reduce:
		return false
	if t - _opened < Motion.ENTER_DELAY + Motion.ENTER_POP \
			+ Motion.ENTER_FACE_LAG + Motion.POP_IN:
		return true
	return t < _anim_until

## Keeps the card moving for `seconds` more. Nothing under reduce-motion,
## where there is nothing to wait for.
func _busy_for(seconds: float) -> void:
	if Motion.reduce:
		return
	_anim_until = maxf(_anim_until, _now() + seconds)

## Drops the mesh so the next _draw rebuilds it, and asks for that draw. The
## mesh the last _draw handed over is still held by _shown, so the renderer
## is never left pointing at a freed RID.
func _refresh() -> void:
	_dirty = true
	queue_redraw()
	if _paint != null:
		_paint.queue_redraw()

## While on, `_grid` and `_cell` answer the reference layout's, so a mesh is
## built in its space; off puts the real ones back.
func _in_ref(on: bool) -> void:
	if on:
		_real = [_grid, _cell]
		_grid = _ref_grid
		_cell = _ref_cell
	else:
		_grid = _real[0]
		_cell = _real[1]

## The reference layout's space onto the one the board has now.
func _relay() -> Transform2D:
	var k := _cell / _ref_cell if _ref_cell > 0.0 else 1.0
	return Transform2D(0.0, Vector2.ONE * k, 0.0, _grid - _ref_grid * k)

# --- the drawing ---

## One mesh, popped in wide about the grid's centre while it fades (rule 7:
## a wide thing comes from most of the way). The lanterns are Controls and
## draw themselves over it.
func _draw() -> void:
	if state.n <= 0 or _cell <= 0.0:
		return
	var now := _now()
	var since := now - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	if _still == null:
		_in_ref(true)
		_still = _build_still()
		_in_ref(false)
	if _dirty:
		_dirty = false
		_in_ref(true)
		_mesh = _build(now)
		_in_ref(false)
	var grow := Motion.wide_pop_scale(since)
	var mid := _grid + Vector2.ONE * (_cell * float(state.n) * 0.5)
	var at := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var tint := Color(1.0, 1.0, 1.0, seen)
	var laid := at * _relay()
	draw_mesh(_still, null, laid, tint)
	if _rest_mesh != null:
		draw_mesh(_rest_mesh, null, laid, tint)
	if _mesh != null:
		draw_mesh(_mesh, null, laid, tint)
	_shown = _mesh
	_still_shown = _still
	_rest_shown = _rest_mesh
	if state.wish_tags():
		_draw_tag_numbers(at, now, seen)
	var k := Motion.flash_level(now - _tw_at, TWINKLE_IN, TWINKLE_OUT)
	if k > 0.0 and not _animating(now):
		if _flare == null:
			_flare = _flare_mesh()
		var r := _cell * WIRE * BEAD * 0.5 * FLARE * (0.6 + 0.4 * k)
		draw_mesh(_flare, null, Transform2D(k * 0.5, Vector2.ONE * r, 0.0, _tw_pos),
			Color(1.0, 1.0, 1.0, k))

## The twinkle's drawing in unit size: a warm glow and a four-pointed star.
func _flare_mesh() -> ArrayMesh:
	var b := Face.Builder.new()
	_halo(b, Vector2.ZERO, 0.2, 1.4, Color(Pal.LANTERN_LIT, 0.8), BEAD_SEGMENTS)
	for a in [0.0, PI * 0.5]:
		var u := Vector2.from_angle(a)
		var v := Vector2.from_angle(a + PI * 0.5)
		b.fan(PackedVector2Array([u * 1.7, v * 0.16, -u * 1.7, -v * 0.16]), Color.WHITE)
	b.disc(Vector2.ZERO, 0.42, Color.WHITE)
	return b.mesh()

## Everything on the board with no face on it, as it stands `t` seconds into
## whatever is moving: the terrace's washes, the pinned cells, the glow under
## every live run, the wire's shade, face and back, the beads, the clips, the
## post and the tags. Every piece standing as it stands at rest is a shape
## made once (`_shape`) and put into the rest mesh, handed back while no
## piece's look changed (`_build_rest`); only a piece turning, pressed,
## shivering, fading, flaring or popping is drawn here, live, into the mesh
## this returns, which is drawn over the rest mesh (checkup 2026-10-02: the
## whole garden was built in script on every moving frame, 7-20 ms on
## Insane).
func _build(t: float) -> ArrayMesh:
	var cells: int = state.n * state.n
	# What is live, recomputed here and never kept; the wash only decides when
	# the eye is allowed to see it and how far up it has come. One frame, one
	# pull, one lift, one level and one chase flare a cell, read once and
	# handed to every pass, so no two passes disagree about a moving piece.
	var depths: PackedInt32Array = state.depths()
	_mt = PackedInt32Array()
	_mt.resize(cells)
	for i in cells:
		_mt[i] = _matched_of(i)
	var frames: Array[Transform2D] = []
	frames.resize(cells)
	var pulls := PackedFloat32Array()
	pulls.resize(cells)
	var lifts := PackedFloat32Array()
	lifts.resize(cells)
	var levels := PackedFloat32Array()
	levels.resize(cells)
	var chase := PackedFloat32Array()
	chase.resize(cells)
	var pops := PackedFloat32Array()
	pops.resize(cells)
	# The fuse's brown-out dims every live cell at once; the press shades the
	# one piece under the finger.
	var flicker := _flicker(t)
	var shades := PackedFloat32Array()
	shades.resize(cells)
	var looks := PackedInt32Array()
	looks.resize(cells)
	for i in cells:
		frames[i] = _frame(i, t)
		pulls[i] = _spin_pull(i, t)
		lifts[i] = _spin_lift(i, t)
		levels[i] = _level(i, depths, t) * flicker
		chase[i] = _chase(i, depths, t)
		shades[i] = _press_shade(i, t)
		pops[i] = Motion.bump_scale(t - _live_at[i], BEAD_BUMP) if depths[i] >= 0 else 1.0
		looks[i] = _look(i, frames[i], pulls[i], lifts[i], shades[i], levels[i], chase[i], pops[i], depths, t)
	_build_rest(looks)
	var b := Face.Builder.new()
	# The light spilling onto the stones: a wash over each lit stone's face,
	# since the stones themselves are in the still mesh.
	for i in cells:
		var warm := WARM * levels[i] + WIN_WARM * chase[i]
		if looks[i] < 0 and warm > 0.0:
			_stone_wash(b, cell_centre(i), Color(Pal.SUN_RAY, warm))
	# The glow under every live run first, widest pass across the whole board
	# before the next, so a narrower band never lands under a wider one.
	for g in GLOWS:
		for i in cells:
			if looks[i] < 0 and levels[i] > 0.0:
				_glow(b, state.grid[i], _mt[i], frames[i], pulls[i], g.x,
					Color(Pal.SUN_RAY, g.y * (levels[i] + 0.8 * chase[i])))
	# Then the wire: every shade first, then every face over the lot, so a
	# neighbour's shade never lands on this cell's cable.
	for i in cells:
		if looks[i] >= 0:
			continue
		var lv := levels[i]
		# A pressed piece sits closer to its stone: its lip shrinks with the dip.
		var drop := Vector2(0.0, SHADE_DROP * (1.0 - 0.5 * shades[i]) + LIFT_SHADE * lifts[i] / TURN_LIFT)
		var col: Color = Pal.FLAGSTONE_DEEP.lerp(Pal.SUN_DEEP, lv)
		_arms(b, state.grid[i], _mt[i], frames[i], pulls[i], 1.0, col, drop)
		if Gen.degree(state.grid[i]) >= 3:
			_dot(b, frames[i] * drop, _cell * WIRE * COLLAR, col)
	for i in cells:
		if looks[i] >= 0:
			continue
		var lv := levels[i]
		var col: Color = Pal.FLAGSTONE.lerp(Pal.SUN, lv)
		if shades[i] > 0.0:
			# The press shades what it sinks (a dip alone is 6%, and 6% of a
			# wire is not seen): the stone darkens under it, the wire toward
			# its own shade.
			_stone_wash(b, cell_centre(i), Color(Pal.TEXT, 0.07 * shades[i]))
			col = col.lerp(Pal.FLAGSTONE_DEEP.lerp(Pal.SUN_DEEP, lv), PRESS_SHADE * shades[i])
		_face(b, state.grid[i], _mt[i], frames[i], pulls[i], lv, col)
	for i in cells:
		if looks[i] < 0 and levels[i] > 0.0:
			_beads(b, state.grid[i], _mt[i], _mid_bead(i), frames[i], pulls[i], levels[i],
				chase[i], pops[i])
	# The clips a fuse left, each on its stone's corner, popping on as it
	# snaps.
	for i in cells:
		if looks[i] < 0 and state.clipped[i] == 1 and t >= _clip_at[i]:
			_clip(b, frames[i].origin, t - _clip_at[i])
	# The post stands level however its own cell is turning, the way a lantern
	# does: it takes the cell's place, not the cell's turn.
	if looks[state.post] < 0:
		_post(b, frames[state.post].origin)
	# Wish Tags' paper last, so no wire or bead crosses a tag; the lanterns are
	# Controls and hang over their own threads.
	if state.wish_tags():
		for key in state.tags:
			var i := int(key)
			if looks[i] < 0:
				var centre := frames[i].origin
				_tag(b, centre, _tag_frame(i, centre, t), _tag_seen(i, depths, t), _tag_gold(i, t))
	return b.mesh() if not b.verts.is_empty() else null

## The rest mesh's passes, in the live mesh's paint order: a cell's piece in
## each is one shape (`_shape`), id `pass << 16 | look`.
const P_WASH := 0
const P_PIN := 1
const P_GLOW := 2  # one a band of GLOWS
const P_SHADE := 5
const P_FACE := 6
const P_BEAD := 7
const P_CLIP := 8
const P_POST := 9
const P_TAG := 10
## A look's bits: the stubs (0-3), which of them meet a stub (4-7), lit (8),
## no bead in the middle (9), a clip on (10), pinned (11); a tag's reading
## (12-13) and gold (14).
const LOOK_LIT := 1 << 8
const LOOK_NO_MID := 1 << 9
const LOOK_CLIP := 1 << 10
const LOOK_PIN := 1 << 11

## Cell `i`'s look when every piece on it stands as it does at rest -- turned
## home, unpressed, still, fully lit or fully dark, no flare, no bead popping,
## a clip on or not there yet, its tag still and its gold either way -- and
## -1 while anything on it moves, which draws it live. A pinned cell keeps
## its pin in the rest mesh either way.
func _look(i: int, frame: Transform2D, pull: float, lift: float, shade: float,
		level: float, flare: float, pop: float, depths: PackedInt32Array, t: float) -> int:
	if frame.origin != cell_centre(i) or frame.x != Vector2.RIGHT or frame.y != Vector2.DOWN \
			or pull != 1.0 or lift != 0.0 or shade != 0.0 or flare != 0.0 or pop != 1.0 \
			or (level != 0.0 and level != 1.0):
		return -1
	var look: int = state.grid[i] | (_mt[i] << 4)
	if level == 1.0:
		look |= LOOK_LIT
	if not _mid_bead(i):
		look |= LOOK_NO_MID
	if state.clipped[i] == 1 and t >= _clip_at[i]:
		if t - _clip_at[i] < Motion.POP_IN:
			return -1
		look |= LOOK_CLIP
	if state.wish_tags() and state.tags.has(i):
		var gold := _tag_gold(i, t)
		if _tag_flutter(i, t) != 0.0 or (gold != 0.0 and gold != 1.0):
			return -1
		look |= (_tag_seen(i, depths, t) << 12) | (int(gold) << 14)
	return look

## Whether cell `i` wears a bead in its middle: the post and a lantern have
## their own light there.
func _mid_bead(i: int) -> bool:
	return i != state.post and not _lanterns.has(i)

## The mask of cell `i`'s stubs that meet a stub back.
func _matched_of(i: int) -> int:
	var out := 0
	for d in 4:
		if state.matched(i, 1 << d):
			out |= 1 << d
	return out

## The rest mesh: every cell at rest (`looks` >= 0) as its shapes, pass by
## pass, and every pin. Handed back while the plan -- each cell's look, and
## which are pinned -- is the one it was built from.
func _build_rest(looks: PackedInt32Array) -> void:
	var cells: int = looks.size()
	var plan := looks.duplicate()
	for i in cells:
		if state.pinned[i] == 1:
			plan[i] = plan[i] | LOOK_PIN if plan[i] >= 0 else -2
	if plan == _rest_plan:
		return
	_rest_plan = plan
	_rm.begin()
	for i in cells:
		if looks[i] >= 0 and looks[i] & LOOK_LIT:
			_rm.put(P_WASH << 16, [], Transform2D(0.0, cell_centre(i)))
	for i in cells:
		if state.pinned[i] == 1:
			_rm.put(P_PIN << 16, [], Transform2D(0.0, cell_centre(i)))
	for g in GLOWS.size():
		for i in cells:
			if looks[i] >= 0 and looks[i] & LOOK_LIT:
				_rm.put((P_GLOW + g) << 16 | (looks[i] & 0xff), [], Transform2D(0.0, cell_centre(i)))
	for p in [P_SHADE, P_FACE]:
		for i in cells:
			if looks[i] >= 0 and state.grid[i] != 0:
				_rm.put(p << 16 | (looks[i] & 0x1ff), [], Transform2D(0.0, cell_centre(i)))
	for i in cells:
		if looks[i] >= 0 and looks[i] & LOOK_LIT:
			_rm.put(P_BEAD << 16 | (looks[i] & 0x3ff), [], Transform2D(0.0, cell_centre(i)))
	for i in cells:
		if looks[i] >= 0 and looks[i] & LOOK_CLIP:
			_rm.put(P_CLIP << 16, [], Transform2D(0.0, cell_centre(i)))
	if looks[state.post] >= 0:
		_rm.put(P_POST << 16, [], Transform2D(0.0, cell_centre(state.post)))
	if state.wish_tags():
		for key in state.tags:
			var i := int(key)
			if looks[i] >= 0:
				_rm.put(P_TAG << 16 | ((looks[i] >> 12) & 7), [], Transform2D(0.0, cell_centre(i)))
	_rest_mesh = _rm.mesh()

## Shape `id` (`pass << 16 | look`) about a cell's centre at the origin, in
## the colours it is drawn in: what the live passes draw for a piece at rest.
func _shape(id: int) -> Face.Builder:
	var b := Face.Builder.new()
	var pass_ := id >> 16
	var m := id & 0xf
	var mt := (id >> 4) & 0xf
	var lv := 1.0 if id & LOOK_LIT else 0.0
	match pass_:
		P_WASH:
			_stone_wash(b, Vector2.ZERO, Color(Pal.SUN_RAY, WARM))
		P_PIN:
			_pin(b, Vector2.ZERO)
		P_GLOW, P_GLOW + 1, P_GLOW + 2:
			var g: Vector2 = GLOWS[pass_ - P_GLOW]
			_glow(b, m, mt, Transform2D.IDENTITY, 1.0, g.x, Color(Pal.SUN_RAY, g.y))
		P_SHADE:
			var drop := Vector2(0.0, SHADE_DROP)
			var col: Color = Pal.FLAGSTONE_DEEP.lerp(Pal.SUN_DEEP, lv)
			_arms(b, m, mt, Transform2D.IDENTITY, 1.0, 1.0, col, drop)
			if Gen.degree(m) >= 3:
				_dot(b, drop, _cell * WIRE * COLLAR, col)
		P_FACE:
			_face(b, m, mt, Transform2D.IDENTITY, 1.0, lv, Pal.FLAGSTONE.lerp(Pal.SUN, lv))
		P_BEAD:
			_beads(b, m, mt, id & LOOK_NO_MID == 0, Transform2D.IDENTITY, 1.0, 1.0, 0.0, 1.0)
		P_CLIP:
			_clip(b, Vector2.ZERO, Motion.POP_IN)
		P_POST:
			_post(b, Vector2.ZERO)
		P_TAG:
			var seen := id & 3
			var gold := float((id >> 2) & 1)
			_tag(b, Vector2.ZERO, Transform2D(TAG_TILT, TAG_AT * _cell), seen, gold)
	return b

## A piece's wire face over its shade: the arms, the collar on a tee or a
## cross, and the lit back along the top (the sheen once it is live).
func _face(b, m: int, mt: int, frame: Transform2D, pull: float, lv: float, col: Color) -> void:
	_arms(b, m, mt, frame, pull, 1.0, col)
	if Gen.degree(m) >= 3:
		_dot(b, frame.origin, _cell * WIRE * COLLAR, col)
	var back := Color(Pal.SURFACE.lerp(Pal.LANTERN_LIT, lv), TOP_ALPHA + (SHEEN_ALPHA - TOP_ALPHA) * lv)
	_glow(b, m, mt, frame, pull, TOP if lv <= 0.0 else SHEEN, back,
		Vector2(0.0, -_cell * WIRE * TOP_RISE * (1.0 - lv)))

## A wash over the stone face of the cell centred on `centre`: an octagon
## inside its rounded face, a rounded rect's arcs cost more than everything
## else in the wash together.
func _stone_wash(b, centre: Vector2, colour: Color) -> void:
	var at := centre - Vector2.ONE * (_cell * 0.5 - TILE_GAP)
	var sz := Vector2.ONE * (_cell - 2.0 * TILE_GAP) - Vector2(0.0, TILE_LIP)
	var c := _cell * TILE_RADIUS * 0.6
	b.fan(PackedVector2Array([at + Vector2(c, 0.0), at + Vector2(sz.x - c, 0.0),
		at + Vector2(sz.x, c), at + Vector2(sz.x, sz.y - c), at + Vector2(sz.x - c, sz.y),
		at + Vector2(c, sz.y), at + Vector2(0.0, sz.y - c), at + Vector2(0.0, c)]), colour)

# --- the fuse's drawing, the clip and the tags ---

## The brass clip a fuse leaves on cell `i`: a little bulldog clip gripping
## its stone's upper-left corner, across it, with a wire handle, a lit edge and
## a dark jaw. It pops on over POP_IN `since` seconds after it snaps.
func _clip(b, centre: Vector2, since: float) -> void:
	var k := Motion.pop_in_scale(since).x
	if k <= 0.01:
		return
	var at := centre + Vector2(-1.0, -1.0) * _cell * CLIP_AT
	var u := Vector2(1.0, -1.0).normalized()  # along the clip, across the corner
	var v := Vector2(1.0, 1.0).normalized()   # into the stone
	var L := _cell * CLIP_LEN * 0.5 * k
	var W := _cell * CLIP_W * 0.5 * k
	var quad := func(c: Vector2, hl: float, hw: float) -> PackedVector2Array:
		return PackedVector2Array([c - u * hl - v * hw, c + u * hl - v * hw,
			c + u * hl + v * hw, c - u * hl + v * hw])
	# Its shade on the stone, the body, the jaw's dark lip and its lit back.
	b.fan(quad.call(at + Vector2(0.0, 3.0), L, W), Color(Pal.TEXT, 0.18))
	b.fan(quad.call(at + v * W * 0.35, L, W * 0.72), BRASS_DEEP)
	b.fan(quad.call(at - v * W * 0.1, L * 0.96, W * 0.8), BRASS)
	b.stroke(PackedVector2Array([at - u * L * 0.8 - v * W * 0.55, at + u * L * 0.8 - v * W * 0.55]),
		maxf(1.5, W * 0.28), BRASS_HI)
	b.stroke(PackedVector2Array([at - u * L * 0.9 + v * W * 0.62, at + u * L * 0.9 + v * W * 0.62]),
		maxf(1.5, W * 0.22), Color(Pal.TEXT, 0.35))
	# The wire handle folded back over it, away from the stone's middle.
	var handle := PackedVector2Array([at - u * L * 0.55 - v * W * 0.7,
		at - u * L * 0.45 - v * W * 2.0, at + u * L * 0.45 - v * W * 2.0, at + u * L * 0.55 - v * W * 0.7])
	b.stroke(handle, maxf(2.0, W * 0.3), BRASS_DEEP)

## The sparks layer: the fuse now blowing, if its sparks are in the air.
func _draw_sparks() -> void:
	if _fuse_cell < 0 or _cell <= 0.0:
		return
	var b := Face.Builder.new()
	_sparks(b, _fuse_cell, _frame(_fuse_cell, _now()).origin, _now())
	if b.verts.is_empty():
		return
	_sparks_shown = b.mesh()
	_spark_layer.draw_mesh(_sparks_shown, null)

## The sparks off a fuse at cell `i`: a white-gold flash at its middle and
## SPARKS streaks flying out and falling, each off the cell's hash.
func _sparks(b, i: int, centre: Vector2, t: float) -> void:
	var e := t - _fuse_at - FUSE_SPARK
	if e < 0.0 or e > SPARK_TIME:
		return
	var u := e / SPARK_TIME
	var fade := 1.0 - u * u
	if u < 0.35:
		_halo(b, centre, _cell * 0.05, _cell * (0.18 + 0.4 * u),
			Color(Pal.LANTERN_LIT, 0.9 * (1.0 - u / 0.35)), BEAD_SEGMENTS)
	for k in SPARKS:
		var h: int = absi(hash(Vector2i(i * 31 + k, int(_fuse_at * 10.0))))
		var ang := TAU * (float(k) + float(h % 100) / 140.0) / float(SPARKS)
		var reach := _cell * SPARK_REACH * (0.6 + 0.4 * float((h / 100) % 100) / 100.0)
		var dir := Vector2.from_angle(ang)
		var go := 1.0 - (1.0 - u) * (1.0 - u)
		var tip := centre + dir * reach * go + Vector2(0.0, _cell * 0.35 * u * u)
		var tail := tip - (dir * reach * 0.22 + Vector2(0.0, _cell * 0.1 * u)) * (1.0 - 0.6 * u)
		var w := maxf(2.0, _cell * 0.035 * (1.0 - 0.5 * u))
		b.stroke(PackedVector2Array([tail, tip]), w, Color(Pal.SUN_RAY, fade))
		_dot(b, tip, w * 0.8, Color(Color.WHITE, fade))

## What a tag shows at `t`: what the wire says once the wash has lit its
## lantern (the state's TAG_MATCH or TAG_OFF), plain while it is dark.
func _tag_seen(i: int, depths: PackedInt32Array, t: float) -> int:
	if not _shown_live(i, depths, t) or _flicker(t) < 0.6:
		return State.TAG_UNLIT
	return state.tag_state(i, depths)

## Where tag `i` hangs, and its turn: tucked into the lower-right corner of
## its cell (where no wire runs and no join sits), a little tilted, and at the
## party fluttering about its eyelet.
func _tag_frame(i: int, centre: Vector2, t: float) -> Transform2D:
	var xf := Transform2D(TAG_TILT, centre + TAG_AT * _cell)
	var f := _tag_flutter(i, t)
	if f != 0.0:
		var hole := Vector2(0.0, -TAG_SIZE.y * _cell * 0.3)
		xf = xf * Transform2D(0.0, hole) * Transform2D(f, Vector2.ZERO) * Transform2D(0.0, -hole)
	return xf

## How gold tag `i` has turned at the party, 0 to 1: a depth's TAG_STEP after
## the one before it, so the gold runs out from the post as the light did.
func _tag_gold(i: int, t: float) -> float:
	if _gold_at >= INF:
		return 0.0
	if Motion.reduce:
		return 1.0
	var e := t - _gold_at - _tag_delay(i)
	return clampf(e / 0.25, 0.0, 1.0)

## Tag `i`'s flutter at `t`, radians about its eyelet: three dying swings as
## it turns gold.
func _tag_flutter(i: int, t: float) -> float:
	if _gold_at >= INF or Motion.reduce:
		return 0.0
	var e := t - _gold_at - _tag_delay(i)
	if e <= 0.0 or e >= TAG_FLUTTER:
		return 0.0
	var u := e / TAG_FLUTTER
	return 0.35 * sin(u * 3.0 * TAU) * (1.0 - u)

func _tag_delay(i: int) -> float:
	return float(maxi(0, int(state.tags.get(i, 0)))) * TAG_STEP

## Wish Tags' paper label for the lantern centred on `centre`, hanging in
## `xf` (`_tag_frame`): a thread from its lantern's base to the hole, a
## luggage tag with its top corners cut, and the reading once the lantern is
## lit -- a gold tick and warm paper when its depth is the tag, `gold` of the
## way to the party's gold. The number itself is drawn text
## (`_draw_tag_numbers`).
func _tag(b, centre: Vector2, xf: Transform2D, seen: int, gold: float) -> void:
	var s := TAG_SIZE * _cell
	var hole := xf * Vector2(0.0, -s.y * 0.3)
	# The thread, tied to the lantern's base and sagging to the hole.
	var tie := centre + Vector2(0.2, 0.2) * _cell
	b.stroke(Face.Builder.bezier2(tie, (tie + hole) * 0.5 + Vector2(0.0, _cell * 0.05), hole, 8),
		maxf(1.5, _cell * 0.016), Pal.CORD_DEEP)
	var half := s * 0.5
	var cut := s.x * 0.28
	var shape := PackedVector2Array([Vector2(-half.x + cut, -half.y), Vector2(half.x - cut, -half.y),
		Vector2(half.x, -half.y + cut), Vector2(half.x, half.y), Vector2(-half.x, half.y),
		Vector2(-half.x, -half.y + cut)])
	var paper: Color = (TAG_WARM if seen == State.TAG_MATCH else TAG_PAPER).lerp(TAG_GOLD, gold)
	var edge := PackedVector2Array()
	var face := PackedVector2Array()
	var low := PackedVector2Array()
	for p in shape:
		low.append(xf * (p * 1.08) + Vector2(0.0, 3.0))
		edge.append(xf * (p * 1.08))
		face.append(xf * p)
	b.fan(low, Color(Pal.TEXT, 0.16))
	b.fan(edge, TAG_EDGE if seen != State.TAG_MATCH and gold <= 0.0 else Pal.SUN_DEEP)
	b.fan(face, paper)
	# The eyelet the thread goes through.
	_dot(b, hole, _cell * 0.028, TAG_EDGE)
	_dot(b, hole, _cell * 0.016, Pal.CORD_DEEP)
	if seen == State.TAG_MATCH:
		# The gold tick: a sun-gold seal on the top-right corner with a white
		# check on it, so it never sits on the number.
		var at := xf * Vector2(half.x * 0.78, -half.y * 0.72)
		var r := _cell * 0.075
		_dot(b, at + Vector2(0.0, 2.0), r, Color(Pal.TEXT, 0.18))
		_dot(b, at, r, Pal.SUN_DEEP)
		_dot(b, at, r * 0.8, Pal.SUN)
		b.stroke(PackedVector2Array([at + Vector2(-0.45, 0.02) * r, at + Vector2(-0.12, 0.36) * r,
			at + Vector2(0.48, -0.32) * r]), maxf(2.0, r * 0.28), Color.WHITE)

## Each tag's number, inked brown on its paper (rose when the lit wire puts
## its lantern at some other depth), one draw_string a tag through the same
## transform as the mesh -- Nonogram's clues.
func _draw_tag_numbers(at: Transform2D, t: float, seen: float) -> void:
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(_cell * TAG_FONT))
	var depths: PackedInt32Array = state.depths()
	for key in state.tags:
		var i := int(key)
		var text := str(int(state.tags[key]))
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		var rise := font.get_height(px) * 0.5 - font.get_descent(px)
		var shown := _tag_seen(i, depths, t)
		var ink: Color = Pal.BERRY_DEEP if shown == State.TAG_OFF else Pal.PLAQUE_DEEP
		var centre := cell_centre(i)
		centre.x += Motion.shiver_offset(t - _refuse_at[i], REFUSE_PX)
		draw_set_transform_matrix(at * _tag_frame(i, centre, t))
		draw_string(font, Vector2(-wide * 0.5, TAG_SIZE.y * _cell * 0.14 + rise), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Color(ink, seen))
	draw_set_transform_matrix(Transform2D.IDENTITY)

## A piece's arms -- stubs `m`, of which `mt` meet a stub -- in its own
## `frame`, `weight` times the wire's width and `pull` of their full length,
## offset by `drop`. An arm runs from the cell's middle to its edge when it
## meets a stub on the other side and stops at LOOSE of the way with a round
## cap when it does not -- which is the whole of "a loose end looks loose".
## The drop rides inside the frame, as the mock's own `translate(0, 4)` does,
## so a piece's lip turns with it.
func _arms(b, m: int, mt: int, frame: Transform2D, pull: float, weight: float,
		colour: Color, drop := Vector2.ZERO) -> void:
	if m == 0:
		return
	var mid := frame * drop
	var w := _cell * WIRE * weight
	# Flat-ended strokes with one disc in the middle and a cap only on a
	# loose end: a round cap on both ends of every arm was most of what a
	# moving frame cost (10 ms of the wire's 17 on a lit 7x7).
	_dot(b, mid, w * 0.5, colour)
	for d in 4:
		if m & (1 << d) == 0:
			continue
		var end := frame * (drop + _arm_end_m(mt, d, pull))
		b.stroke(PackedVector2Array([mid, end]), w, colour, false, false)
		if mt & (1 << d) == 0:
			_dot(b, end, w * 0.5, colour)

## Where arm `d` of cell `i` ends, in the cell's own frame: its edge when it
## meets a stub, LOOSE of the way when it does not.
func _arm_end(i: int, d: int, pull: float) -> Vector2:
	return _arm_end_m(_matched_of(i), d, pull)

## The same for a piece whose met stubs are `mt`.
func _arm_end_m(mt: int, d: int, pull: float) -> Vector2:
	var half := _cell * 0.5
	var reach := (half if mt & (1 << d) else half * LOOSE) * pull
	return Vector2(float(Gen.DC[d]), float(Gen.DR[d])) * reach

## The glow under a piece's wire (`m`, `mt` as for `_arms`), `weight` wires
## wide. A straight or an elbow is one polyline through the middle, so it
## never overlaps itself; a tee or a cross is one polyline and the odd arm. An
## end that meets a neighbour is flat, so the two cells' glows meet edge to
## edge; a loose end is round.
func _glow(b, m: int, mt: int, frame: Transform2D, pull: float, weight: float, colour: Color,
		drop := Vector2.ZERO) -> void:
	if m == 0 or colour.a <= 0.0:
		return
	var arms: Array[int] = []
	for d in 4:
		if m & (1 << d):
			arms.append(d)
	var w := _cell * WIRE * weight
	var mid := frame * drop
	var loose := func(d: int) -> bool: return mt & (1 << d) == 0
	if arms.size() == 1:
		_glow_run(b, [frame * (drop + _arm_end_m(mt, arms[0], pull)), mid], loose.call(arms[0]), false, w, colour)
		return
	_glow_run(b, [frame * (drop + _arm_end_m(mt, arms[0], pull)), mid,
		frame * (drop + _arm_end_m(mt, arms[1], pull))], loose.call(arms[0]), loose.call(arms[1]), w, colour)
	for k in range(2, arms.size()):
		_glow_run(b, [mid, frame * (drop + _arm_end_m(mt, arms[k], pull))], false, loose.call(arms[k]), w, colour)

## One glow stroke along `pts`, with a round cap at an end that is a loose
## arm (`head`/`tail`; the middle, which the bead covers, never is) and flat
## everywhere else.
func _glow_run(b, pts: Array, head: bool, tail: bool, w: float, colour: Color) -> void:
	b.stroke(PackedVector2Array(pts), w, colour, false, false)
	if head:
		_dot(b, pts[0], w * 0.5, colour)
	if tail:
		_dot(b, pts[pts.size() - 1], w * 0.5, colour)

## The beads on a live piece: one in its middle when `mid` (the post and a
## lantern have their own light there) and one on every join it makes to the
## east or the south, so a join shared by two cells gets one bead and not
## two. Each pops by `pop` (BEAD_BUMP as the light reaches it) and flares
## with the win's chase.
func _beads(b, m: int, mt: int, mid: bool, frame: Transform2D, pull: float, level: float,
		flare: float, pop: float) -> void:
	var r := _cell * WIRE * BEAD * 0.5 * pop * frame.get_scale().x
	if mid:
		_bead(b, frame.origin, r, level, flare)
	for d in [1, 2]:
		if m & (1 << d) and mt & (1 << d):
			_bead(b, frame * _arm_end_m(mt, d, pull), r, level, flare)

func _bead(b, at: Vector2, r: float, level: float, flare: float) -> void:
	var k := clampf(level + flare, 0.0, 1.6)
	_halo(b, at, r * 0.6, r * (BEAD_GLOW + 1.4 * flare),
		Color(Pal.LANTERN_LIT, BEAD_GLOW_ALPHA * k), BEAD_SEGMENTS)
	_dot(b, at, r * (1.0 + 0.3 * flare), Color(Pal.LANTERN_LIT.lerp(Color.WHITE, 0.5), level))

## A small round dot of `r`: DOT_POINTS round, where Builder.disc spends a
## point every three pixels. On a wire joint, a cap or a bead the difference
## cannot be seen and is most of a moving frame's vertices.
static func _dot(b, at: Vector2, r: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	pts.resize(DOT_POINTS)
	for k in DOT_POINTS:
		pts[k] = at + DOT_RING[k] * r
	b.fan(pts, colour)

## The top-left corner of cell `i`'s stone.
func _stone_at(i: int) -> Vector2:
	return _grid + Vector2(float(i % state.n), float(i / state.n)) * _cell \
		+ Vector2.ONE * TILE_GAP

## Everything on the card that never moves -- the frame, the grout, the
## stones and the vines -- built once a layout and drawn under the board's
## own mesh, so a moving frame rebuilds only what moves. It was all in the
## one mesh on the first draft of this pass, and a frame of the wash cost
## 22.7 ms against 5.6 before it.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var span := _cell * float(state.n)
	_frame_wood(b, span)
	b.fan(Face.Builder.round_rect(_grid, Vector2.ONE * span, GROUND_RADIUS), GROUT)
	for i in state.n * state.n:
		_stone(b, i)
	_vines(b, span)
	return b.mesh()

## A paving stone: set TILE_GAP into its cell, standing TILE_LIP on its own
## edge, toned off its hash, with a lit line along its top.
func _stone(b, i: int) -> void:
	var at := _stone_at(i)
	var sz := Vector2.ONE * (_cell - 2.0 * TILE_GAP)
	var r := _cell * TILE_RADIUS
	var h: int = absi(hash(Vector2i(i, state.post * 17 + state.n)))
	var tone := float(h % 1000) / 999.0
	var face: Color = Pal.SURFACE.lerp(Pal.PARCHMENT, 0.3 + TONE * tone)
	b.fan(Face.Builder.round_rect(at, sz, r), TILE_EDGE)
	b.fan(Face.Builder.round_rect(at, sz - Vector2(0.0, TILE_LIP), r), face)
	b.stroke(PackedVector2Array([at + Vector2(r, 1.5), at + Vector2(sz.x - r, 1.5)]),
		2.0, Color(Pal.SURFACE, 0.9))
	# A speck of moss or a fallen leaf in one corner of some stones.
	if float((h / 1000) % 100) / 100.0 < SPECK_SHARE:
		var corner := Vector2(0.2 if (h >> 3) & 1 else 0.8, 0.8 if (h >> 4) & 1 else 0.22)
		var p := at + sz * corner
		var ang := float((h >> 5) % 628) / 100.0
		var lr := _cell * 0.045
		b.ellipse(p, lr * 1.5, lr, Color(Pal.MOSS, 0.55))
		b.ellipse(p + Vector2.from_angle(ang) * lr * 1.4, lr * 1.1, lr * 0.7, Color(Pal.LEAF_DEEP, 0.4))

## The wooden frame round the grid: a darker outer lip, the wood, and a lit
## rail along its inner edge. It sits inside the card's INSET.
func _frame_wood(b, span: float) -> void:
	var out := _grid - Vector2.ONE * FRAME
	var size := Vector2.ONE * (span + 2.0 * FRAME)
	b.fan(Face.Builder.round_rect(out + Vector2(0.0, 5.0), size, FRAME_RADIUS), Pal.PLAQUE_DEEP)
	b.fan(Face.Builder.round_rect(out, size, FRAME_RADIUS), Pal.PLAQUE)
	b.fan(Face.Builder.round_rect(out + Vector2.ONE * 3.0, size - Vector2.ONE * 6.0,
		FRAME_RADIUS - 3.0), Pal.WOOD)
	b.fan(Face.Builder.round_rect(_grid - Vector2.ONE * RAIL, Vector2.ONE * (span + 2.0 * RAIL),
		GROUND_RADIUS + RAIL), Pal.PLAQUE)
	# The grain: a few long faint strokes along each side.
	var grain := Color(Pal.PLAQUE_DEEP, 0.22)
	var mid := FRAME * 0.5 + RAIL * 0.5
	for k: float in [-1.0, 1.0]:
		var off: float = k * 3.5
		b.stroke(PackedVector2Array([_grid + Vector2(span * 0.12, -mid + off), _grid + Vector2(span * 0.46, -mid + off)]), 1.5, grain)
		b.stroke(PackedVector2Array([_grid + Vector2(span * 0.58, span + mid + off), _grid + Vector2(span * 0.9, span + mid + off)]), 1.5, grain)
		b.stroke(PackedVector2Array([_grid + Vector2(-mid + off, span * 0.3), _grid + Vector2(-mid + off, span * 0.7)]), 1.5, grain)
		b.stroke(PackedVector2Array([_grid + Vector2(span + mid + off, span * 0.16), _grid + Vector2(span + mid + off, span * 0.52)]), 1.5, grain)

## Vines on the frame: a cluster of leaves and a flower or two on every
## corner, and a smaller sprig at a few places along the sides, off the
## board's own hash so a day keeps its garden. Drawn after the stones, so a
## leaf may reach a little way over the terrace's edge, never over a wire's
## middle.
func _vines(b, span: float) -> void:
	var seed_h: int = absi(hash(Vector2i(state.post, state.n * 7)))
	var spots: Array = [
		[Vector2(0.0, 0.0), 1.0], [Vector2(1.0, 0.0), 0.8], [Vector2(0.0, 1.0), 0.9],
		[Vector2(1.0, 1.0), 1.0],
	]
	var sides := [Vector2(0.5, 0.0), Vector2(0.0, 0.5), Vector2(1.0, 0.5), Vector2(0.5, 1.0)]
	for k in 6:
		var side: Vector2 = sides[(k + (seed_h >> (k * 2))) % 4]
		var along := 0.2 + 0.6 * float((seed_h >> (k * 3 + 5)) % 100) / 100.0
		var p := side
		if side.x == 0.5:
			p.x = along
		else:
			p.y = along
		spots.append([p, 0.6])
	for s_i in spots.size():
		var where: Vector2 = spots[s_i][0]
		var size: float = spots[s_i][1]
		var at := _grid + where * span
		# Pushed out onto the wood, so the cluster sits on the frame.
		at += (where - Vector2(0.5, 0.5)).sign() * Vector2(where.x != 0.5, where.y != 0.5) * FRAME * 0.5
		_cluster(b, at, size, absi(hash(Vector2i(seed_h, s_i))))

func _cluster(b, at: Vector2, size: float, h: int) -> void:
	var L := _cell * LEAF * size
	var leaves := 5 + h % 3
	for k in leaves:
		var ang := TAU * float(k) / float(leaves) + float((h >> (k + 2)) % 100) / 100.0
		var len := L * (0.8 + 0.4 * float((h >> (k * 2)) % 10) / 10.0)
		var c := at + Vector2.from_angle(ang) * len * 0.55
		var tip := at + Vector2.from_angle(ang) * len * 1.3
		var side := Vector2.from_angle(ang + PI * 0.5) * len * 0.34
		var green: Color = Pal.MOSS if k % 2 == 0 else Pal.LEAF_DEEP
		b.polygon(Face.Builder.bezier2(at, c + side * 1.6, tip, 6) \
			+ Face.Builder.bezier2(tip, c - side * 1.6, at, 6), green)
		b.stroke(PackedVector2Array([at.lerp(tip, 0.1), at.lerp(tip, 0.8)]), 1.5,
			Color(Pal.LEAF_TILE, 0.45))
	var flowers := 1 + int(size > 0.7) + (h >> 9) % 2 * int(size > 0.9)
	for k in flowers:
		var ang := float((h >> (k * 4 + 3)) % 628) / 100.0
		var p := at + Vector2.from_angle(ang) * L * (0.55 + 0.25 * float(k))
		_flower(b, p, _cell * FLOWER_R * (0.8 + 0.3 * size))

func _flower(b, at: Vector2, r: float) -> void:
	for k in 5:
		b.disc(at + Vector2.from_angle(TAU * k / 5.0 - PI * 0.5) * r * 0.62, r * 0.5,
			Pal.SURFACE)
	b.disc(at, r * 0.36, Pal.SUN_RAY)

# --- the spin, and the wash behind it ---

## Where cell `i` stands and how far round it is, `t` seconds in: its centre,
## shifted by whatever a refusal is shaking out of it, turned by the spin.
## One frame, read by every pass of the build and by the lantern in its slot.
func _frame(i: int, t: float) -> Transform2D:
	var at := cell_centre(i)
	at.x += Motion.shiver_offset(t - _refuse_at[i], REFUSE_PX)
	var lift := 1.0 + _spin_lift(i, t)
	var angle := _spin_angle(i, t)
	if i == _fuse_cell:
		var f := _fuse_angle(t)
		angle += f
		lift += TURN_LIFT * clampf(f / (FUSE_REACH * PI * 0.5), 0.0, 1.0)
	return Transform2D(angle, Vector2.ONE * lift * _press_scale(i, t), 0.0, at)

## How far round the fuse has the piece, `t` seconds in (clockwise is
## positive): FUSE_REACH of a quarter turn on the sine over FUSE_START, a
## strained buzz there while the sparks fly, and back home on back_out's
## overshoot from FUSE_BACK. The grid never changed, so home is zero.
func _fuse_angle(t: float) -> float:
	if Motion.reduce or _fuse_cell < 0:
		return 0.0
	var e := t - _fuse_at
	if e <= 0.0 or e >= FUSE_BACK + FUSE_BACK_TIME:
		return 0.0
	var reach := FUSE_REACH * PI * 0.5
	if e < FUSE_START:
		return reach * sin(e / FUSE_START * PI * 0.5)
	if e < FUSE_BACK:
		return reach + FUSE_BUZZ * sin(e * 90.0)
	return reach * (1.0 - Motion.back_out((e - FUSE_BACK) / FUSE_BACK_TIME))

## The brown-out, as a multiplier on every live cell's light at `t`: two dips
## over FLICKER_TIME from the sparks, snapping down and easing back, and one
## everywhere else.
func _flicker(t: float) -> float:
	if Motion.reduce or _fuse_cell < 0:
		return 1.0
	var e := t - _fuse_at - FUSE_SPARK
	if e <= 0.0 or e >= FLICKER_TIME:
		return 1.0
	return 1.0 - FLICKER_DIP * sqrt(absf(sin(e / FLICKER_TIME * TAU)))

## The press on cell `i` as a scale: down to PRESS_SCALE under the finger and
## springing home once it lifts (Motion.press_scale), one on every other cell.
func _press_scale(i: int, t: float) -> float:
	if i != _press_cell:
		return 1.0
	return Motion.press_scale(t - _press_down, (t - _press_up) if _press_up >= 0.0 else -1.0)

## The same press as a shade, 0 at rest to 1 at the bottom of the dip.
func _press_shade(i: int, t: float) -> float:
	if i != _press_cell:
		return 0.0
	return clampf((1.0 - _press_scale(i, t)) / (1.0 - Motion.PRESS_SCALE), 0.0, 1.0)

## How far cell `i` still has to turn, `t` seconds in. The piece is already
## where the turn put it, so the angle runs from a quarter turn *behind* (or
## ahead, for an anticlockwise undo) home to nothing on `back_out`'s
## overshoot. A spin of several quarters -- a hint's -- takes proportionally
## longer, so the piece does not blur. Zero before it begins, which is what
## lets Reset set every piece spinning at a moment of its own.
func _spin_angle(i: int, t: float) -> float:
	var q: int = _spin_q[i]
	if Motion.reduce or q == 0:
		return 0.0
	var u := clampf((t - _spin_at[i]) / _spin_time(q), 0.0, 1.0)
	if u >= 1.0:
		return 0.0
	return -float(q) * (PI * 0.5) * (1.0 - Motion.back_out(u))

## How far cell `i`'s arms are pulled in, `t` seconds in: ARM_PULL at the
## middle of the turn and nothing at either end, so a full-length arm never
## sweeps through the piece next door.
func _spin_pull(i: int, t: float) -> float:
	if i == _fuse_cell and not Motion.reduce:
		var f := clampf(_fuse_angle(t) / (FUSE_REACH * PI * 0.5), 0.0, 1.0)
		if f > 0.0:
			return 1.0 - ARM_PULL * f
	if Motion.reduce or _spin_q[i] == 0:
		return 1.0
	var u := clampf((t - _spin_at[i]) / TURN_TIME, 0.0, 1.0)
	if u >= 1.0:
		return 1.0
	return 1.0 - ARM_PULL * sin(PI * u)

## How far cell `i` is lifted off its stone, `t` seconds in, as a scale over
## one: TURN_LIFT at the middle of its spin and nothing at either end, so the
## piece is picked up, turned and set down.
func _spin_lift(i: int, t: float) -> float:
	var q: int = _spin_q[i]
	if Motion.reduce or q == 0:
		return 0.0
	var u := (t - _spin_at[i]) / _spin_time(q)
	if u <= 0.0 or u >= 1.0:
		return 0.0
	return TURN_LIFT * sin(PI * u)

## How far up cell `i`'s light has come at `t`, 0 to 1. A live cell warms up
## over LIGHT_FADE from the moment the wash reaches it; a cut-off cell cools
## over the same from the moment the wave pulls it back, and never shows more
## than it had reached. Under reduce-motion it is on or off.
func _level(i: int, depths: PackedInt32Array, t: float) -> float:
	if Motion.reduce:
		return 1.0 if _shown_live(i, depths, t) else 0.0
	var on := clampf((t - _live_at[i]) / LIGHT_FADE, 0.0, 1.0)
	# The hearts ran out: the dark pulls the light back to the post.
	on = minf(on, 1.0 - clampf((t - _dark_at[i]) / LIGHT_FADE, 0.0, 1.0))
	if depths[i] >= 0:
		return on
	return minf(on, 1.0 - clampf((t - _out_at[i]) / LIGHT_FADE, 0.0, 1.0))

## The win's chase at cell `i`: a flash as the light running out from the
## post passes its depth. Nothing before the win and nothing on a dark cell.
func _chase(i: int, depths: PackedInt32Array, t: float) -> float:
	if depths[i] < 0 or _chase_at >= FAR:
		return 0.0
	return Motion.flash_level(t - _chase_at - float(depths[i]) * _chase_step)

static func _spin_time(q: int) -> float:
	return TURN_TIME * (0.7 * maxf(1.0, float(absi(q))) + 0.3)

## Sets cell `i` spinning `q` quarters (negative anticlockwise) from `at`, and
## keeps the card alive until it lands. Nothing under reduce-motion: the
## piece is simply round the other way.
func _spin(i: int, q: int, at: float) -> void:
	if Motion.reduce or q == 0:
		return
	_spin_at[i] = at
	_spin_q[i] = q
	_busy_for(at - _now() + _spin_time(q))

## Whether cell `i` may be *seen* lit at `t`. `depths` is the truth, computed
## fresh by the caller; the moment is only the wash's permission to show it.
## A cell that is live waits for the light to reach it; a cell that has been
## cut off keeps its light until the wave pulls it back.
func _shown_live(i: int, depths: PackedInt32Array, t: float) -> bool:
	if t >= _dark_at[i]:
		return false
	if depths[i] >= 0:
		return t >= _live_at[i]
	return t < _out_at[i]

## One step of the wash, or none at all under reduce-motion, where the whole
## live set changes in one frame.
func _step(rings: int) -> float:
	return 0.0 if Motion.reduce else float(maxi(0, rings)) * WAVE_STEP

## How far into a spin the wash sets off, from now.
func _lag() -> float:
	return 0.0 if Motion.reduce else WASH_LAG

## **The wash.** `before` is `state.depths()` as it stood *before* the move;
## the state now holds the move's result. Every cell whose reachability
## changed takes a moment from `at`: a cell just reached lights its own depth
## in steps later, so the light walks out along the wire from the post; a cell
## just cut off goes dark on the same wave **reversed**, the far end first, so
## the light reads as pulled back down the branch rather than switched off.
## Queens' `_settle` with the tree's own depth in place of a queen's sight.
## Nothing derived is stored: only the moments, and the truth is read fresh
## wherever it is wanted. `by_turn` marks the lanterns a player's turn woke
## (the rewards' `_on_lantern_woke`), as against the entrance, Try again and
## One more heart.
func _settle(before: PackedInt32Array, at: float, by_turn := false) -> void:
	var now_d: PackedInt32Array = state.depths()
	var cells: int = state.n * state.n
	# The far end of what *was* live, which is where a cut-off branch starts
	# going dark from.
	var far := 0
	for i in cells:
		if before[i] > far:
			far = before[i]
	var lanterns: Dictionary = {}
	for i in state.lanterns():
		lanterns[i] = true
	# A chime still to come for a lantern this move put out is dropped with
	# it: an undo or a reset that cuts a lantern off before the wash reached
	# it would otherwise still ring it awake -- and play its gag -- over a
	# lantern going dark.
	_wake_cues = _wake_cues.filter(func(c): return now_d[int(c.cell)] >= 0)
	var last := at
	for i in cells:
		var was := before[i] >= 0
		var is_live := now_d[i] >= 0
		if is_live == was:
			continue
		var moment := at + (_step(now_d[i]) if is_live else _step(far - before[i]))
		if is_live:
			_live_at[i] = moment
			if lanterns.has(i):
				# The lantern wakes as the wash reaches it, and its face
				# arrives with the bump: seventeen of them in a ripple rather
				# than together, because each is on its own depth.
				_wake_at[i] = moment
				_wake_cues.append({"at": moment, "cell": i, "by_turn": by_turn,
					"pitch": minf(1.0 + 0.03 * float(now_d[i]), 1.5)})
				last = maxf(last, moment + Motion.BUMP_TIME)
		else:
			_out_at[i] = moment
		last = maxf(last, moment)
	# **Never behind a wash still in flight.** `last` covers only the cells
	# *this* settle changed, so a move that changes nothing (a turn on an
	# isolated piece, most of a Reset's stagger) would otherwise drop
	# `_wash_end` back to `at` while a longer wash is still running -- and
	# `win_delay()` and `_on_solved()` both spend this figure as the wash's
	# whole length. Task 4's review measured it behind on 2,757 of 2,880
	# settles, worst by 0.84 s. It only ever grows within a deal;
	# `_clear_clocks()` puts it back to zero when a new board is dealt, and a
	# wash whose end is in the past costs nothing, both readers taking
	# `maxf(0.0, _wash_end - now)`.
	_wash_end = maxf(_wash_end, last)
	_wake_cues.sort_custom(func(a, b): return float(a.at) < float(b.at))
	_busy_for(last - _now() + LIGHT_FADE + Motion.BUMP_TIME)

## A pinned cell (centred on `centre`) reads as a given, in the language every board in this game
## uses: a pale sun wash under a dotted ring. Word Trail's hint mark.
func _pin(b, centre: Vector2) -> void:
	var at := centre - Vector2.ONE * (_cell * 0.5)
	b.fan(Face.Builder.round_rect(at + Vector2.ONE * PIN_INSET,
		Vector2.ONE * (_cell - 2.0 * PIN_INSET), _cell * PIN_RADIUS),
		Color(Pal.SUN_RAY, PIN_ALPHA))
	var ring := Face.Builder.round_rect(at + Vector2.ONE * DASH_INSET,
		Vector2.ONE * (_cell - 2.0 * DASH_INSET), _cell * DASH_RADIUS)
	for dash in _dashes(ring, _cell * DASH_ON, _cell * DASH_OFF):
		b.stroke(dash as PackedVector2Array, DASH_W, Pal.SUN_DEEP)

## The closed outline `pts` cut into dashes of `on` with `off` between them.
## Word Trail's own, which is the mock's `setLineDash`.
static func _dashes(pts: PackedVector2Array, on: float, off: float) -> Array:
	var out: Array = []
	if pts.size() < 2 or on <= 0.0 or off <= 0.0:
		return out
	var cur := PackedVector2Array([pts[0]])
	var lit := true
	var spent := 0.0
	for i in pts.size():
		var a := pts[i]
		var z := pts[(i + 1) % pts.size()]
		var span := a.distance_to(z)
		if span <= 0.001:
			continue
		var walked := 0.0
		while walked < span:
			# Never zero: a dash that ended exactly on a corner would other-
			# wise walk nowhere for ever.
			var want := maxf((on if lit else off) - spent, 0.001)
			if walked + want >= span:
				spent += span - walked
				walked = span
				if lit:
					cur.append(z)
			else:
				walked += want
				var p := a.lerp(z, walked / span)
				if lit:
					cur.append(p)
					if cur.size() >= 2:
						out.append(cur)
					cur = PackedVector2Array()
				else:
					cur = PackedVector2Array([p])
				lit = not lit
				spent = 0.0
	if lit and cur.size() >= 2:
		out.append(cur)
	return out

## The post: the one thing on the board that is never paper and never dark.
## Light Up's `LANTERN` iron, a sun in the glass, and a halo that is always
## on. It has no face, so it is drawn into this mesh rather than seated as a
## Control -- see the header.
func _post(b, at: Vector2) -> void:
	var R := _cell * POST_R
	b.ellipse(at + Vector2(0.0, 1.02) * R, 0.8 * R, 0.2 * R,
		Color(Pal.TEXT, POST_SHADOW_ALPHA))
	_halo(b, at + Vector2(0.0, POST_GLOW_AT) * R, POST_GLOW_INNER * R,
		POST_GLOW_R * R, Color(Pal.SUN, POST_GLOW_ALPHA))
	var iron: Color = Pal.LANTERN
	b.fan(Face.Builder.round_rect(at + Vector2(-0.46, 0.76) * R,
		Vector2(0.92, 0.22) * R, 0.1 * R), iron)
	b.fan(Face.Builder.round_rect(at + Vector2(-0.13, -0.1) * R,
		Vector2(0.26, 0.96) * R, 0.06 * R), iron)
	b.disc(at + Vector2(0.0, -0.42) * R, 0.52 * R, Pal.SUN_DEEP)
	b.disc(at + Vector2(0.0, -0.46) * R, 0.46 * R, Pal.SUN)
	b.disc(at + Vector2(-0.1, -0.56) * R, 0.2 * R,
		Color(Pal.LANTERN_LIT, POST_GLASS_ALPHA))
	b.fan(Face.Builder.round_rect(at + Vector2(-0.34, -1.08) * R,
		Vector2(0.68, 0.24) * R, 0.1 * R), iron)
	b.fan(Face.Builder.round_rect(at + Vector2(-0.08, -1.28) * R,
		Vector2(0.16, 0.24) * R, 0.06 * R), iron)

## A disc of light at `inner` fading to nothing at `outer`, built as two
## rings and the band between them -- what a canvas radial gradient comes to
## once it is triangles. `ui/faces/lantern_face.gd`'s own halo, in the
## board's coordinates rather than a face's.
func _halo(b, at: Vector2, inner: float, outer: float, warm: Color,
		segments: int = LanternFace.GLOW_SEGMENTS) -> void:
	if warm.a <= 0.0:
		return
	var clear := Color(warm, 0.0)
	var centre: int = b.vertex(at, warm)
	var ring_i: int = b.verts.size()
	for i in segments:
		b.vertex(at + Vector2.from_angle(TAU * i / segments) * inner, warm)
	var ring_o: int = b.verts.size()
	for i in segments:
		b.vertex(at + Vector2.from_angle(TAU * i / segments) * outer, clear)
	for i in segments:
		var j := (i + 1) % segments
		b.tri(centre, ring_i + i, ring_i + j)
		b.tri(ring_i + i, ring_o + i, ring_o + j)
		b.tri(ring_i + i, ring_o + j, ring_i + j)

## What each lantern is wearing and where it is standing at `t`: lit and
## smiling once the wash has reached its cell, plain paper while it has not.
## `lit` is snapped to five levels before it reaches the mesh cache, so
## seventeen lanterns cost at most five meshes a paper.
##
## **The slot takes the cell's frame and the paper counter-turns inside it.**
## The slot carries the shiver, the quarter turn and the wake's bump; the
## paper carries the entrance's own pop (a tween) and the turn back, so the
## two hands never write the same property (rule 2) and a hanging thing never
## cartwheels (spec section 7).
func _dress(t: float) -> void:
	if state.n <= 0:
		return
	var depths: PackedInt32Array = state.depths()
	var done := is_done()
	# The fuse's brown-out flickers the lanterns with the wire.
	var flicker := _flicker(t)
	for i in _lanterns:
		var lantern: LanternFace = _lanterns[i]
		var slot: Control = _slots[i]
		var live := _shown_live(i, depths, t)
		var want := (1.0 if live else 0.0) * flicker
		if lantern.lit != want:
			lantern.lit = want
		if lantern.plain != (not live):
			lantern.plain = not live
			# A lit paper is alive and blinks on a clock of its own; an
			# unlit one is plain paper with no eyes to blink. set_idle does
			# nothing under reduce-motion.
			lantern.set_idle(live)
		var expr := Face.Expr.JOY if done else Face.Expr.HAPPY
		if live and lantern.expression != expr:
			lantern.expression = expr
		var frame := _frame(i, t)
		slot.position = frame.origin
		slot.rotation = frame.get_rotation()
		var bump := 1.0
		if live:
			bump = Motion.bump_scale(t - _wake_at[i])
			if _chase_at < FAR:
				bump *= Motion.bump_scale(t - _chase_at - float(depths[i]) * _chase_step)
		slot.scale = frame.get_scale() * bump
		_hang(i, t, live)
		# The press shades the paper too, not only the wire under it.
		var shade := 1.0 - 0.12 * _press_shade(i, t)
		lantern.modulate = Color(shade, shade, shade)
	_paint.queue_redraw()

## Every lantern as one mesh: each one's layers, as its node would draw
## them, put under its slot's and its own transform. A lantern its node must
## draw itself -- shaded by a press, or hidden -- is left to it.
func _draw_lanterns() -> void:
	_lanterns_shown = _lanterns_mesh()
	if _lanterns_shown != null:
		_paint.draw_mesh(_lanterns_shown, null)

func _lanterns_mesh() -> ArrayMesh:
	_lantern_rm.begin()
	for i in _lanterns:
		var lantern: LanternFace = _lanterns[i]
		var slot: Control = _slots[i]
		var paint := lantern.modulate == Color.WHITE and lantern.visible and slot.visible \
			and lantern.self_modulate == Color.WHITE
		if lantern.painted != paint:
			lantern.painted = paint
		if not paint:
			continue
		# The renderer puts a node's origin on a whole pixel; so does the
		# paint, or every lantern moves by a fraction of one (measured against
		# the nodes' frames, 2026-10-02).
		var xf := slot.get_transform() * lantern.get_transform()
		xf.origin = xf.origin.round()
		for layer in lantern.layers_now():
			_lantern_rm.put(_lantern_id(layer[0]), [], xf * (layer[1] as Transform2D))
	return _lantern_rm.mesh()

## The shape id of a lantern layer's mesh (Face's shared cache hands every
## lantern of a look the same one).
func _lantern_id(m: ArrayMesh) -> int:
	var id = _lantern_ids.get(m)
	if id == null:
		id = _lantern_meshes.size()
		_lantern_ids[m] = id
		_lantern_meshes.append(m)
	return id

func _lantern_shape(id: int) -> Face.Builder:
	var b := Face.Builder.new()
	var a := (_lantern_meshes[id] as ArrayMesh).surface_get_arrays(0)
	b.verts = a[Mesh.ARRAY_VERTEX]
	b.cols = a[Mesh.ARRAY_COLOR]
	b.idx = a[Mesh.ARRAY_INDEX]
	return b

# --- the moments ---

## The chrome is the host's. The grid's own entrance is one wide pop about
## its centre while it fades in (rule 7), read off the clock in _draw, and
## the lanterns pop in on their cells a beat after it. Then the first wash
## runs out from the post, so the screen opens by showing where the power is
## (spec section 7) -- settled against an all-dark board, which is what makes
## every reached cell a cell "just reached".
func _enter() -> void:
	_opened = _now()
	fx.cue("enter")
	for i in _lanterns:
		Motion.pop_in(_lanterns[i], Motion.POP_IN,
			Motion.ENTER_DELAY + Motion.ENTER_POP + Motion.ENTER_FACE_LAG)
	var dark := PackedInt32Array()
	dark.resize(state.n * state.n)
	dark.fill(-1)
	_settle(dark, _opened + (0.0 if Motion.reduce else Motion.ENTER_DELAY + ENTER_WASH))
	_dress(_now())
	_refresh()

# --- input ---

## One tap, one quarter turn clockwise, and nothing else on the screen. No
## drag, no long press and no second direction. The press sinks and shades
## the piece under the finger (and springs it if the finger slides off); the
## turn fires on the release, and only over the piece the finger went down
## on while it is still held -- a finger that slid off has let go, which is
## what the spring already told it.
##
## **One finger turns a piece** (Quilt's review): the press keeps its touch
## index (-1 for the mouse), and another finger's press, slide and release
## are ignored outright, so a thumb resting on the garden neither turns a
## second piece nor steals the dip -- on Hard and Insane a stray turn can be
## a fuse. A touch the system cancels springs the piece and turns nothing. A
## new press from the same finger replaces a press whose release never came.
func _gui_input(event: InputEvent) -> void:
	if _done or out_of_hearts:
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	var finger: int = event.index if (event is InputEventScreenTouch or event is InputEventScreenDrag) else -1
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _held() and finger == _press_finger and _cell_at(event.position) != _press_cell:
			_release_press()
		return
	if not (event is InputEventScreenTouch or event is InputEventMouseButton):
		return
	var i := _cell_at(event.position)
	if event.pressed:
		if _held() and finger != _press_finger:
			accept_event()
			return
		# A fuse holds every tap until it has played out.
		if i >= 0 and not _fusing():
			accept_event()
			_press_finger = finger
			_press(i)
		return
	if not _held() or finger != _press_finger:
		return
	var pressed_on := _press_cell
	_release_press()
	accept_event()
	if event.is_canceled() or i != pressed_on or _fusing():
		return
	_turn(i)

## Whether a finger is down on a piece now.
func _held() -> bool:
	return _press_cell >= 0 and _press_up < 0.0

## The finger lands on cell `i`: it starts to sink.
func _press(i: int) -> void:
	_press_cell = i
	_press_down = _now()
	_press_up = -1.0
	_busy_for(Motion.PRESS_TIME + 0.05)
	_refresh()

## The finger lifts or slides off: the piece springs home from wherever the
## press had got to.
func _release_press() -> void:
	if not _held():
		return
	_press_up = _now()
	_busy_for(Motion.RELEASE_TIME + 0.05)
	_refresh()

## Whether a fuse is still playing out (input, Undo, Hint and Reset wait).
func _fusing() -> bool:
	return _now() < _fuse_end

## A tap on cell `i`. A cross is already every way round, a pinned cell is a
## given and a clipped one was shown right by a fuse: none turns, and a
## refusal is a line from the sprout and never a silence (Hidden Word's rule).
## On a judged garden a piece that is already right blows a fuse.
func _turn(i: int) -> void:
	# Taken before the move: what the wash diffs against, and a local of this
	# move rather than anything the board keeps.
	var before: PackedInt32Array = state.depths()
	var now := _now()
	match state.turn(i):
		State.PINNED:
			_refuse(i, now, tr("FL_PINNED"))
			return
		State.CROSS:
			_refuse(i, now, tr("FL_CROSS"))
			return
		State.CLIPPED:
			_refuse(i, now, tr("FL_CLIPPED"))
			return
		State.RIGHT:
			_fuse(i)
			return
	fx.cue("place")
	_spin(i, 1, now)
	_settle(before, now + _lag(), true)
	_dress(now)
	_refresh()
	_speak()
	_on_turned(i, before)
	# note_move() counts the turn and ends the board if that was the last
	# loose end; the host raises the win screen after win_delay().
	note_move()

## A move the rules will not take: the piece shivers where it stands and the
## sprout says why, because a refusal is never a silence.
func _refuse(i: int, now: float, line: String) -> void:
	_say(line, Face.Expr.PUZZLED)
	fx.cue("refuse")
	if Motion.reduce:
		return
	_refuse_at[i] = now
	_busy_for(Motion.SHIVER_TIME)

# --- the fuse, and running out ---

## A tap on a piece that was already right, on Hard or Insane (the state has
## clipped it and changed nothing else): the piece starts its quarter turn,
## sparks fly off it, the live run flickers twice like a brown-out, a heart
## splits, and the piece swings back and a brass clip snaps onto it. All of
## it off one clock (`_fuse_at`) through `_busy_for`. Under reduce motion
## there is no spin: the heart splits and the clip is simply there.
func _fuse(i: int) -> void:
	if hearts <= 0 or is_done():
		return
	var now := _now()
	hearts -= 1
	_lost_ever = true
	_break_streak()
	_split_index = hearts
	if hearts <= 0:
		out_of_hearts = true
		_running = false
	# The undo log lost this piece's turns; the HUD re-reads it.
	moved.emit()
	if Motion.reduce:
		_split_at = now
		_clip_at[i] = AGO
		fx.cue("fuse")
		fx.cue("heart_lost")
		_after(0.2, fx.cue.bind("clip"))
		_say(tr("FL_FUSE"), Face.Expr.WORRIED)
		_heart_layer.queue_redraw()
		_dress(now)
		_refresh()
		if out_of_hearts:
			_after(0.25, _run_out)
		return
	_fuse_cell = i
	_fuse_at = now
	_fuse_end = now + FUSE_END
	_split_at = now + FUSE_SPLIT
	_clip_at[i] = now + FUSE_CLIP
	_busy_for(FUSE_END + Motion.POP_IN)
	fx.cue("place")
	_after(FUSE_SPARK, func() -> void:
		fx.cue("fuse")
		fx.sparkle(cell_centre(i), Pal.SUN_RAY)
		_say(tr("FL_FUSE"), Face.Expr.WORRIED))
	_after(FUSE_SPLIT, func() -> void:
		fx.cue("heart_lost")
		_heart_layer.queue_redraw())
	_after(FUSE_CLIP, func() -> void:
		fx.cue("clip"))
	_after(FUSE_END, func() -> void:
		_fuse_cell = -1
		moved.emit()
		if out_of_hearts:
			_run_out())
	_dress(now)
	_refresh()

## The last heart is gone: the light is pulled back down every branch to the
## post, the far end first (the wash reversed, on `_dark_at`), the lanterns
## go plain, dusk falls on the card, and the out-of-hearts card comes up.
func _run_out() -> void:
	if _asleep or not out_of_hearts:
		return
	_asleep = true
	_release_press()
	_break_streak()
	# The garden goes dark: no lantern still to wake chimes into it.
	_wake_cues = []
	_tip_timer.stop()
	fx.cue("out_of_hearts")
	_say(tr("FL_OUT"), Face.Expr.SLEEPY)
	var now := _now()
	var depths: PackedInt32Array = state.depths()
	var far := 1
	for d in depths:
		far = maxi(far, d)
	var step := 0.0 if Motion.reduce else minf(WAVE_STEP, DARK_SPAN / float(far))
	for i in state.n * state.n:
		if depths[i] >= 0:
			_dark_at[i] = now + float(far - depths[i]) * step
	var span := float(far) * step + LIGHT_FADE
	_busy_for(span + 0.05)
	_dusk_toward(DUSK)
	_dress(now)
	_refresh()
	_after(CARD_AFTER_STILL if Motion.reduce else maxf(CARD_AFTER, span + 0.3), _open_card)

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
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["FL_OUT_BODY", "FL_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same garden in Reset's wave with every heart back and every
## clip gone, the day's light, the clock and the moves from zero. Hints spent
## stay spent, and a hint's pin stays. The light washes out from the post
## again, since the garden went dark.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	_gen += 1
	var now := _now()
	state.clear_clips()
	var grid_before: PackedInt32Array = state.grid.duplicate()
	state.reset_board()
	_deal()
	_dark_at.fill(FAR)
	_clip_at.fill(AGO)
	_fuse_cell = -1
	_fuse_end = 0.0
	_reset_spins(grid_before, now)
	var dark := PackedInt32Array()
	dark.resize(state.n * state.n)
	dark.fill(-1)
	_settle(dark, now + _lag())
	elapsed = 0.0
	moves = 0
	_running = true
	# _deal() puts the light back at once; hold the dusk so it fades.
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	_dress(now)
	_refresh()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	moved.emit()

## One more heart (the card's video): once a garden. The light comes back out
## from the post and the lanterns wake.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	var now := _now()
	_heart_used = true
	hearts = 1
	_back_index = 0
	_back_at = now
	_heart_layer.queue_redraw()
	out_of_hearts = false
	_asleep = false
	_running = true
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	_dark_at.fill(FAR)
	var dark := PackedInt32Array()
	dark.resize(state.n * state.n)
	dark.fill(-1)
	_settle(dark, now + (0.0 if Motion.reduce else ENTER_WASH))
	_dress(now)
	_refresh()
	_say(tr("FL_HEART_BACK"), Face.Expr.HAPPY)
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

## Holds the host's hint video while a fuse is still playing out.
func busy() -> bool:
	return _fusing()

## Runs `what` after `delay`, unless the board has been dealt again meanwhile.
func _after(delay: float, what: Callable) -> void:
	if not is_inside_tree():
		return
	var gen := _gen
	get_tree().create_timer(maxf(delay, 0.0)).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

# --- the rewards (polish section 3) ---

## Every reward's clock back to nothing: a new board, or a restored one.
func _reset_rewards() -> void:
	_flawless = false
	_undo_ever = false
	_streak = 0
	_streak_gen += 1
	_gag_turn = -1
	_combo_n = 0
	_combo_at = -INF
	_combo_out_at = -INF
	_joins = []
	_love = []
	_notes = []
	_moths = []
	_flies = []
	_hum = {}
	_dance_at = INF
	_gold_at = INF
	_stamp_at = INF
	_seal_mesh = null
	_cat_at = INF
	_cat_curled = false
	if is_instance_valid(_cat):
		_cat.queue_free()
	_cat = null
	if _life_layer != null:
		_life_layer.queue_redraw()

## A turn of cell `i` went through (not refused, no fuse), before
## note_move(). `before` is `state.depths()` as it stood before it; the state
## holds the result. Every new join the turn made gives off a spark as the
## piece lands (and `join` once a turn). Then the streak, read off the
## lanterns alone so it says nothing the garden does not show: a turn that
## puts a lantern out ends it, one that wakes a lantern builds it -- a note up
## the pentatonic from the second, the bubble from the third, confetti at
## four and seven, each as the wash reaches the first lantern it woke -- and
## one that does neither leaves it be. The winning turn does none of it: the
## party is about to start (Mushroom Patch's review found a combo landing
## over the party).
func _on_turned(i: int, before: PackedInt32Array) -> void:
	_join_sparks(i)
	if is_done() or state.is_solved():
		return
	var after: PackedInt32Array = state.depths()
	var woke: Array[int] = []
	for c in state.lanterns():
		if before[c] >= 0 and after[c] < 0:
			_break_streak()
			return
		if before[c] < 0 and after[c] >= 0:
			woke.append(c)
	if woke.is_empty():
		return
	var who: int = woke[0]
	for c in woke:
		if _wake_at[c] < _wake_at[who]:
			who = c
	var land := maxf(0.0, _wake_at[who] - _now())
	_streak += 1
	var count := _streak
	var gen := _streak_gen
	var live := func() -> bool: return gen == _streak_gen and not is_done()
	if count >= 2:
		var step: int = COMBO_STEPS[mini(count - 2, COMBO_STEPS.size() - 1)]
		_after(land + 0.05, func() -> void:
			if live.call():
				fx.cue("combo", pow(2.0, step / 12.0), COMBO_DB))
	if count >= COMBO_FROM:
		_after(land, func() -> void:
			if not live.call():
				return
			_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
			_combo_n = count
			_combo_pos = cell_centre(who) - Vector2(0.0, _cell * 0.3)
			_combo_at = _now()
			_combo_out_at = -INF
			_life_layer.queue_redraw())
	if COMBO_CONFETTI.has(count) and not Motion.reduce:
		_after(land, func() -> void:
			if not live.call():
				return
			fx.confetti(cell_centre(who), 22)
			fx.cue("confetti"))

## A spark at every join cell `i`'s turn has just made: an arm that meets a
## stub now and was pointing elsewhere before (its neighbours did not move, so
## an arm that pointed there before met it before).
func _join_sparks(i: int) -> void:
	var m: int = state.grid[i]
	var was: int = Gen.cw(Gen.cw(Gen.cw(m)))
	var made := false
	var land := _now() + (0.0 if Motion.reduce else JOIN_AT)
	for d in 4:
		var bit := 1 << d
		if was & bit or not state.matched(i, bit):
			continue
		made = true
		if not Motion.reduce:
			_joins.append({"at": cell_centre(i) + _arm_end(i, d, 1.0), "t": land})
	if made:
		_after(land - _now(), fx.cue.bind("join"))

## What a turn set going that an undo or a reset takes back with it: a moth
## round a lantern that may be going dark, notes, love, a hum, a join's spark.
func _clear_gags() -> void:
	_joins = []
	_love = []
	_notes = []
	_moths = []
	_hum = {}
	if _life_layer != null:
		_life_layer.queue_redraw()

## The streak ends: a fuse, an undo, a reset, a turn that puts a lantern out,
## the hearts running out. The bubble deflates, and anything the streak had
## still to play is dropped.
func _break_streak() -> void:
	_streak = 0
	_streak_gen += 1
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
	else:
		_combo_n = 0
	if _life_layer != null:
		_life_layer.queue_redraw()

## Lantern `i` has just woken: the wash reached it this frame. A lantern a
## player's turn woke plays, three times in five, a gag -- a moth, a hum or
## love -- one a turn at most. Which lantern plays which is the day's: the
## garden picks where the cycle starts and each lantern steps two along it,
## so any five lanterns share the three gags evenly (Quilt's rule; a plain
## hash per lantern clumps). None under reduce motion, and none on the
## winning turn, whose party is coming.
func _on_lantern_woke(i: int, by_turn: bool) -> void:
	if not by_turn or Motion.reduce or is_done() or out_of_hearts or _gag_turn == state.turns:
		return
	var k: int = state.lanterns().find(i)
	var roll := posmod(hash(str(state.sol) + str(state.post)) + k * 2, GAG_ODDS)
	if roll >= GAGS:
		return
	_gag_turn = state.turns
	var now := _now()
	var top := cell_centre(i) - Vector2(0.0, _cell * 0.25)
	match roll:
		0:
			var h: int = absi(hash(Vector2i(i, state.turns)))
			var from := Vector2.from_angle(-PI * 0.5 + (float(h % 100) / 100.0 - 0.5) * 2.4)
			_moths.append({"c": cell_centre(i) - Vector2(0.0, _cell * 0.06), "t": now,
				"from": from * _cell * MOTH_FROM, "a0": from.angle(),
				"dir": 1.0 if h & 256 else -1.0,
				"away": Vector2.from_angle(from.angle() + PI * (0.5 if h & 512 else -0.5) * 0.8)})
			fx.cue("moth")
		1:
			_hum[i] = now
			for n in NOTES:
				_notes.append({"at": top + Vector2((float(n) - 1.0) * 0.18 * _cell, 0.0),
					"t": now + float(n) * 0.16, "phase": float(n) * 2.1, "side": 1.0 if n % 2 == 0 else -1.0})
			fx.cue("hum")
		2:
			for n in LOVE_HEARTS:
				var off := Vector2((float(n) - (LOVE_HEARTS - 1) * 0.5) * 0.22, 0.0) * _cell
				_love.append({"at": top + off, "t": now + float(n) * 0.08,
					"phase": float(posmod(hash([i, n]), 100)) / 100.0 * TAU})
			fx.cue("love")
	_life_layer.queue_redraw()

## The hum's tremble on lantern `i` at `t`, radians: quick and dying.
func _hum_shake(i: int, t: float) -> float:
	if Motion.reduce or not _hum.has(i):
		return 0.0
	var e := t - float(_hum[i])
	if e <= 0.0 or e >= HUM_TIME:
		return 0.0
	return HUM_SHAKE * sin(e * 46.0) * (1.0 - e / HUM_TIME)

## Lantern `i`'s dance at `t`: (tilt, hop in pixels). A hop on every beat, its
## lean swapping side each beat, on its own half of the beat: a checkerboard
## over the garden, so neighbours are always half a beat apart.
func _dance_pose(i: int, t: float) -> Vector2:
	if Motion.reduce or t < _dance_at:
		return Vector2.ZERO
	var side: int = ((i / state.n) + (i % state.n)) % 2
	var e := t - _dance_at - float(side) * DANCE_BEAT * 0.5
	if e < 0.0 or e >= DANCE_BEAT * DANCE_BEATS:
		return Vector2.ZERO
	var beat := int(e / DANCE_BEAT)
	var up := sin(fmod(e, DANCE_BEAT) / DANCE_BEAT * PI)
	return Vector2((1.0 if beat % 2 == 0 else -1.0) * DANCE_TILT * up, DANCE_HOP * _cell * up)

# --- the party ---

## After the win's chase: the lanterns dance on the beat, fireflies rise out
## of the garden, confetti twice, on Wish Tags every tag flutters and turns
## gold, the nap cat hops along the frame's foot and curls up, the seal
## stamps when the solve earned one (flawless, or any Insane garden), and the
## sprout shares a bit of lantern wisdom. Under reduce motion the cat, the
## gold and the seal are simply there.
func _party() -> void:
	var now := _now()
	var lead := 0.0 if Motion.reduce else maxf(0.0, _wash_end - now) + PARTY_AT
	_after(lead, func() -> void:
		_say(_cheer(), Face.Expr.JOY))
	_cat_at = now + (0.0 if Motion.reduce else lead + CAT_AT)
	if state.wish_tags():
		_gold_at = now + (0.0 if Motion.reduce else lead + TAGS_AT)
		var deepest := 0
		for k in state.tags:
			deepest = maxi(deepest, int(state.tags[k]))
		_busy_for(lead + TAGS_AT + float(deepest) * TAG_STEP + TAG_FLUTTER + 0.1)
		_after(_gold_at - now, func() -> void:
			fx.cue("tags")
			_refresh())
	if _flawless or state.band == 3:
		_stamp_at = now + (0.0 if Motion.reduce else lead + STAMP_AT)
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
	if Motion.reduce:
		_life_layer.queue_redraw()
		return
	var field := Rect2(_grid, Vector2.ONE * _cell * float(state.n))
	_after(lead + 0.15, func() -> void:
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell * 0.4), 30, field.size.x * 0.9)
		fx.cue("party"))
	_after(lead + 0.6, func() -> void:
		fx.confetti(field.get_center(), 24, field.size.x * 0.7))
	_dance_at = now + lead
	_busy_for(lead + DANCE_BEAT * (DANCE_BEATS + 1))
	_after(lead, fx.cue.bind("dance"))
	_after(lead + FIREFLY_AT, _release_fireflies)

## FIREFLIES rise out of the garden, each from a stone of its own (the
## garden's hash), a little apart in time.
func _release_fireflies() -> void:
	var now := _now()
	var cells: int = state.n * state.n
	var seed_h: int = absi(hash(str(state.sol)))
	for k in FIREFLIES:
		var h: int = absi(hash(Vector2i(seed_h, k)))
		var c := h % cells
		var jitter := Vector2(float((h >> 8) % 100) / 100.0 - 0.5, float((h >> 15) % 100) / 100.0 - 0.3) * _cell * 0.6
		_flies.append({"at": cell_centre(c) + jitter, "t": now + float(k) * 0.07,
			"phase": float((h >> 3) % 628) / 100.0, "drift": 1.0 if h & 1 else -1.0})
	fx.cue("fireflies")
	_life_layer.queue_redraw()

## One of CHEERS silly bits of lantern wisdom, picked by the garden itself, so
## a day always gets the same one.
func _cheer() -> String:
	return tr("FL_CHEER_%d" % posmod(hash(str(state.sol) + str(state.post)), CHEERS))

# --- the nap cat ---

func _cat_px() -> float:
	return size.x * CAT_PX

## Where she curls up: on the frame's foot, her cushion on the wood, along
## the bottom row where she hides the fewest lanterns (a lantern's paper is
## the middle LANTERN_R * SEAT of its cell) and a little toward the left --
## the seal takes the right.
func _cat_spot() -> Vector2:
	var span := _cell * float(state.n)
	var px := _cat_px()
	var y := _grid.y + span + FRAME - px * 0.38
	var half := px * 0.42
	var paper := _cell * LANTERN_R * LanternFace.SEAT * 0.5
	var row: int = (state.n - 1) * state.n
	var best_x := _grid.x + span * 0.24
	var best := INF
	var steps: int = 2 * state.n
	for k in steps + 1:
		var x := _grid.x + half + (span * 0.72 - half) * float(k) / float(steps)
		var hide := 0.0
		for c in state.n:
			var cell: int = row + c
			if not _lanterns.has(cell) and cell != state.post:
				continue
			var mid := _grid.x + (float(c) + 0.5) * _cell
			hide += maxf(0.0, minf(x + half, mid + paper) - maxf(x - half, mid - paper))
		var score := hide + absf(x - (_grid.x + span * 0.24)) * 0.05
		if score < best:
			best = score
			best_x = x
	return Vector2(best_x, y)

## Where she pops up: the frame's lower left corner.
func _cat_start() -> Vector2:
	var span := _cell * float(state.n)
	return Vector2(_grid.x - FRAME * 0.5, _grid.y + span + FRAME - _cat_px() * 0.38)

func _cat_walk() -> float:
	return CAT_POP + CAT_HOPS * CAT_HOP_TIME

## Puts the cat where her clock says: nowhere yet; popping up on the corner;
## hopping along the foot; landing with a squash; curled up asleep, purring.
## Under reduce motion she is simply curled up there.
func _place_cat(t: float) -> void:
	if t < _cat_at or _cell <= 0.0:
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
		_cat.pivot_offset = _cat.size * 0.5
	var e := t - _cat_at
	var spot := _cat_spot()
	var start := _cat_start()
	var at := spot
	var sc := Vector2.ONE
	if Motion.reduce or e >= _cat_walk() + CAT_SETTLE or _cat_curled:
		if not _cat_curled:
			_curl_cat(e > _cat_walk() + CAT_SETTLE + 1.0)
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
		# Tall in the air, squashed at each take-off and landing.
		var s := 0.1 * sin(u * PI)
		sc = Vector2(1.0 - s, 1.0 + s)
	else:
		var u := (e - _cat_walk()) / CAT_SETTLE
		var s := 0.14 * sin(u * PI)
		sc = Vector2(1.0 + s, 1.0 - s)
	_cat.position = at - _cat.size * 0.5
	_cat.scale = sc

## She curls up: the sleepy face and the drifting "z", and a purr -- unless
## she was already asleep when the board opened (a restore), who is quiet.
func _curl_cat(quiet: bool) -> void:
	_cat_curled = true
	_cat.expression = Face.Expr.SLEEPY
	_cat.scale = Vector2.ONE
	if not quiet:
		fx.cue("purr")

# --- the life over the garden ---

## Drops what has finished and says whether anything on the life layer still
## moves.
func _tick_life(now: float) -> bool:
	_joins = _joins.filter(func(j): return now < float(j.t) + JOIN_TIME)
	_love = _love.filter(func(l): return now < float(l.t) + LOVE_TIME)
	_notes = _notes.filter(func(l): return now < float(l.t) + NOTE_TIME)
	_moths = _moths.filter(func(m): return now < float(m.t) + MOTH_IN + MOTH_CIRCLE + MOTH_OUT)
	_flies = _flies.filter(func(f): return now < float(f.t) + FIREFLY_TIME)
	return not (_joins.is_empty() and _love.is_empty() and _notes.is_empty()
			and _moths.is_empty() and _flies.is_empty()) \
		or (_combo_n >= COMBO_FROM and (now - _combo_at < Motion.POP_IN + 0.1 or _combo_out_at > -INF)) \
		or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1)

## The life over the garden, each thing one cached mesh through a transform:
## join sparks, fireflies, love hearts, notes, moths, then the seal and the
## streak's bubble with their words.
func _draw_life() -> void:
	if _cell <= 0.0 or state.n <= 0:
		_life_shown = []
		return
	var now := _now()
	var shown: Array = []
	if not _joins.is_empty():
		if _flare == null:
			_flare = _flare_mesh()
		shown.append(_flare)
		for j in _joins:
			var e: float = now - float(j.t)
			if e <= 0.0:
				continue
			var u := e / JOIN_TIME
			var level := sin(PI * minf(u * 1.6, 1.0)) if u < 0.3125 else 1.0 - (u - 0.3125) / 0.6875
			var r := _cell * JOIN_R * 0.5 * (0.5 + 0.7 * sin(PI * u))
			_life_layer.draw_mesh(_flare, null, Transform2D(u * 1.4, Vector2.ONE * r, 0.0, j.at),
				Color(1.0, 1.0, 1.0, clampf(level, 0.0, 1.0)))
	if not _flies.is_empty():
		var mesh := _firefly()
		shown.append(mesh)
		for f in _flies:
			var e: float = now - float(f.t)
			if e <= 0.0:
				continue
			var u := e / FIREFLY_TIME
			var at: Vector2 = f.at + Vector2(sin(u * 5.0 + float(f.phase)) * 0.3 * float(f.drift),
				-FIREFLY_RISE * (1.0 - (1.0 - u) * (1.0 - u))) * _cell
			var blink := 0.6 + 0.4 * sin(e * 11.0 + float(f.phase))
			var alpha := sqrt(sin(PI * u)) * blink
			_life_layer.draw_mesh(mesh, null, Transform2D(0.0, at), Color(1.0, 1.0, 1.0, alpha))
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
	if not _notes.is_empty():
		var mesh := _note()
		shown.append(mesh)
		for l in _notes:
			var e: float = now - float(l.t)
			if e <= 0.0:
				continue
			var u := e / NOTE_TIME
			var at: Vector2 = l.at + Vector2(float(l.side) * (0.12 * u + 0.06 * sin(u * 9.0 + float(l.phase))),
				-NOTE_RISE * (1.0 - (1.0 - u) * (1.0 - u))) * _cell
			var k := Motion.pop_in_scale(e, 0.2).x
			_life_layer.draw_mesh(mesh, null, Transform2D(0.3 * sin(u * 7.0 + float(l.phase)), Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.35, 0.0, 1.0)))
	if not _moths.is_empty():
		var mesh := _moth()
		shown.append(mesh)
		for m in _moths:
			var e: float = now - float(m.t)
			if e <= 0.0:
				continue
			var at := _moth_at(m, e)
			var ahead := _moth_at(m, e + 0.03) - at
			var heading := ahead.angle() + PI * 0.5 if ahead.length() > 0.01 else 0.0
			var flap := 0.3 + 0.7 * absf(cos(e * MOTH_FLAP * PI))
			var end := MOTH_IN + MOTH_CIRCLE + MOTH_OUT
			var alpha := clampf(e / 0.15, 0.0, 1.0) * clampf((end - e) / (MOTH_OUT * 0.5), 0.0, 1.0)
			_life_layer.draw_mesh(mesh, null, Transform2D(heading, Vector2(flap, 1.0), 0.0, at),
				Color(1.0, 1.0, 1.0, alpha))
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_draw_combo(now, shown)
	_life_shown = shown

## Where moth `m` is `e` seconds in: fluttering in from off the lantern to its
## orbit, round the lantern MOTH_LAPS times on a flattened circle, and
## wandering off with a wobble.
func _moth_at(m: Dictionary, e: float) -> Vector2:
	var c: Vector2 = m.c
	var R := _cell * MOTH_ORBIT
	var a0: float = m.a0
	var dir: float = m.dir
	var orbit := func(a: float) -> Vector2: return c + Vector2(cos(a) * R, sin(a) * R * 0.62)
	if e < MOTH_IN:
		var u := e / MOTH_IN
		var ease := 1.0 - (1.0 - u) * (1.0 - u)
		return (c + (m.from as Vector2)).lerp(orbit.call(a0), ease) + Vector2(0.0, sin(u * TAU) * _cell * 0.08)
	if e < MOTH_IN + MOTH_CIRCLE:
		var u := (e - MOTH_IN) / MOTH_CIRCLE
		return orbit.call(a0 + dir * TAU * MOTH_LAPS * u) + Vector2(0.0, sin(u * TAU * 5.0) * _cell * 0.04)
	var u := minf((e - MOTH_IN - MOTH_CIRCLE) / MOTH_OUT, 1.2)
	var away: Vector2 = m.away
	var side := away.orthogonal()
	return orbit.call(a0) + away * _cell * 2.2 * u * u + away * _cell * 0.4 * u \
		+ side * sin(u * TAU * 1.5) * _cell * 0.18

## A moth, head up, about its middle: pale fore and hind wings on a deeper
## edge with a spot each, a brown body, and two feathery feelers.
func _moth() -> ArrayMesh:
	if _moth_mesh == null:
		var b := Face.Builder.new()
		var s := _cell * MOTH_SPAN * 0.5
		for sx in [-1.0, 1.0]:
			var fore := Vector2(sx * 0.5, -0.12) * s
			var hind := Vector2(sx * 0.36, 0.3) * s
			b.polygon(_oval(fore, 0.6 * s, 0.4 * s, sx * -0.5), MOTH_WING_DEEP)
			b.polygon(_oval(hind, 0.42 * s, 0.31 * s, sx * 0.45), MOTH_WING_DEEP)
			b.polygon(_oval(fore, 0.53 * s, 0.33 * s, sx * -0.5), MOTH_WING)
			b.polygon(_oval(hind, 0.35 * s, 0.25 * s, sx * 0.45), MOTH_WING.lerp(MOTH_WING_DEEP, 0.3))
			b.disc(fore + Vector2(sx * 0.12, -0.02) * s, 0.1 * s, Color(Pal.PLAQUE_DEEP, 0.45))
			b.stroke(Face.Builder.bezier2(Vector2(sx * 0.05, -0.4) * s, Vector2(sx * 0.12, -0.72) * s,
				Vector2(sx * 0.32, -0.8) * s, 6), maxf(1.5, 0.05 * s), Pal.PLAQUE_DEEP)
			b.disc(Vector2(sx * 0.32, -0.8) * s, 0.06 * s, Pal.PLAQUE_DEEP)
		b.polygon(_oval(Vector2(0.0, 0.06) * s, 0.14 * s, 0.42 * s, 0.0), Pal.PLAQUE_DEEP)
		b.disc(Vector2(0.0, -0.36) * s, 0.14 * s, Pal.PLAQUE_DEEP)
		for sx in [-1.0, 1.0]:
			b.disc(Vector2(sx * 0.06, -0.39) * s, 0.04 * s, Color.WHITE)
		_moth_mesh = b.mesh()
	return _moth_mesh

## A little music note in sun-deep ink on a pale rim, about its head.
func _note() -> ArrayMesh:
	if _note_mesh == null:
		var b := Face.Builder.new()
		var h := _cell * NOTE_H
		for pass_i in 2:
			var col: Color = Pal.SURFACE if pass_i == 0 else Pal.SUN_DEEP
			var grow := 0.06 * h if pass_i == 0 else 0.0
			b.polygon(_oval(Vector2.ZERO, 0.3 * h + grow, 0.22 * h + grow, -0.35), col)
			b.stroke(PackedVector2Array([Vector2(0.26, -0.02) * h, Vector2(0.26, -1.0) * h]), 0.09 * h + 2.0 * grow, col)
			b.stroke(Face.Builder.bezier2(Vector2(0.26, -1.0) * h, Vector2(0.66, -0.72) * h,
				Vector2(0.52, -0.38) * h, 8), 0.1 * h + 2.0 * grow, col)
		_note_mesh = b.mesh()
	return _note_mesh

## A little pink heart for the love gag, built once a layout.
func _love_heart() -> ArrayMesh:
	if _love_mesh == null:
		var b := Face.Builder.new()
		var r := _cell * LOVE_R
		b.polygon(_heart(Vector2.ZERO, r * 1.15, 0), Pal.FLOWER_DEEP)
		b.polygon(_heart(Vector2.ZERO, r, 0), Pal.FLOWER)
		b.ellipse(Vector2(-0.45, -0.45) * r, 0.18 * r, 0.1 * r, Color(1.0, 1.0, 1.0, 0.5))
		_love_mesh = b.mesh()
	return _love_mesh

## A firefly: a gold glow round a pale spark, and the little brown bug it
## hangs from, so it reads on the pale terrace as well as over the light.
func _firefly() -> ArrayMesh:
	if _fly_mesh == null:
		var b := Face.Builder.new()
		var r := _cell * FIREFLY_R
		_halo(b, Vector2.ZERO, r * 0.5, r * 2.4, Color(Pal.SUN_RAY, 0.7), BEAD_SEGMENTS)
		_dot(b, Vector2.ZERO, r * 0.62, Pal.SUN)
		_dot(b, Vector2(0.0, 0.08) * r, r * 0.42, Pal.SUN_SPARK)
		b.polygon(_oval(Vector2(0.0, -0.72) * r, 0.3 * r, 0.42 * r, 0.0), Pal.PLAQUE_DEEP)
		_fly_mesh = b.mesh()
	return _fly_mesh

## An ellipse `rx` by `ry` about `at`, turned `angle`.
static func _oval(at: Vector2, rx: float, ry: float, angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 16:
		var a := TAU * float(k) / 16.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	return pts

## The streak's paper bubble over the lantern that woke, "x3" and up in leaf
## ink: it pops in the first time, bumps at each turn and deflates when the
## streak ends. Rebuilt only when its words or its tail change (Quilt's).
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
		HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color(Pal.LEAF_DEEP, alpha))
	_life_layer.draw_set_transform(Vector2.ZERO)

## The seal on the frame's lower right, dropping in from STAMP_FROM its size
## and settling with the back ease's overshoot, its words over it: Flawless;
## on Insane "Insane" over Flawless or Wish Tags, on the night seal.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := size.x * STAMP_R * 0.75
	var insane: bool = state.band == 3
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	# Over the frame's lower right corner, hanging off it like a stamp on a
	# parcel, so it hides as little of the garden as it can.
	var corner := _grid + Vector2.ONE * (_cell * float(state.n) + FRAME)
	var centre := corner - Vector2(rad * 0.85, rad * 0.72)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless else tr("FL_TAGS_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

# --- the hearts ---

## The hearts over the frame as one mesh on a paper pill (Queens', Mushroom
## Patch's): pink with a small face and a leaf, a faint ghost where one was,
## the lost one's halves falling apart, and one coming back popping in.
func _draw_hearts() -> void:
	if max_hearts <= 0 or _cell <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var c := _hearts_at()
	var y := c.y
	var x0 := c.x - step * (max_hearts - 1) * 0.5
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var corner := c - pill * 0.5
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
	_heart_layer.draw_set_transform(c * (1.0 - enter), 0.0, Vector2.ONE * enter)
	_heart_layer.draw_mesh(_hearts_shown, null)
	_heart_layer.draw_set_transform(Vector2.ZERO)

## A heart's small face: two dots and a smile in ink, a shine at the top left,
## and a leaf on top (Mushroom Patch's).
static func _heart_face(b, at: Vector2, s: float) -> void:
	b.ellipse(at + Vector2(-0.5, -0.5) * s, 0.16 * s, 0.1 * s, Color(1.0, 1.0, 1.0, 0.45))
	for sx in [-1.0, 1.0]:
		b.disc(at + Vector2(sx * 0.28, -0.12) * s, 0.09 * s, Pal.OUTLINE)
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, 0.02) * s, 0.16 * s, PI * 0.2, PI * 0.8), 0.07 * s, Pal.OUTLINE)
	b.ellipse(at + Vector2(0.25, -0.76) * s, 0.24 * s, 0.11 * s, Pal.LEAF)

## A heart `s` half-wide about `at` (side 0), or its left (-1) or right (1)
## half, split along a zigzag crack so the two halves fit together
## (Binairo's, by way of Mushroom Patch).
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

# --- the sprout's line ---

## What is left to do, in the mock's own words: the loose ends first, because
## while there is one the board cannot be finished, and the dark cells after,
## because once there are none it is.
func _left_line() -> String:
	var loose := 0
	var dark := 0
	var depths: PackedInt32Array = state.depths()
	for i in state.n * state.n:
		loose += _bits(state.loose(i))
		if depths[i] < 0:
			dark += 1
	if loose == 0:
		return tr("FL_NO_LOOSE")
	return tr("FL_ONE_DARK") if dark == 1 else tr("FL_N_DARK") % dark

static func _bits(m: int) -> int:
	return (m & 1) + ((m >> 1) & 1) + ((m >> 2) & 1) + ((m >> 3) & 1)

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
	if is_done() or _tip_mood != Face.Expr.HAPPY or state.turns > 0:
		return
	var tips := _tips()
	_tip_idx = (_tip_idx + 1) % tips.size()
	_say(tr(tips[_tip_idx]), Face.Expr.HAPPY)

## The sprout's own line, rather than Binairo's cycle of broken rules.
func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not out_of_hearts and not _fusing() and not state.history.is_empty()

## Turns the last tapped piece back a quarter turn, in tap order. Counts no
## move, and the wash comes back with it for free -- live is derived, so
## there is no highlight to put back.
func undo() -> bool:
	if is_done() or out_of_hearts or _fusing() or state.history.is_empty():
		return false
	_release_press()
	_break_streak()
	var before: PackedInt32Array = state.depths()
	var i := state.undo()
	if i < 0:
		return false
	_undo_ever = true
	_clear_gags()
	# The same spin the other way round, and the wash runs backwards behind
	# it for free: the diff is symmetric, so a branch that was reached goes
	# dark from its far end exactly as it lit from the post.
	var now := _now()
	_spin(i, -1, now)
	_settle(before, now + _lag())
	_dress(now)
	_refresh()
	_say(tr("FL_TURNED_BACK") + " " + _left_line(), Face.Expr.HAPPY)
	fx.cue("undo")
	moved.emit()
	return true

## The band's own (3, 3, 1 and none, `State.hints_for`), less what was spent,
## plus any a video bought.
func hints_left() -> int:
	return maxi(0, State.hints_for(state.band) + hints_extra - hints_used)

## Turns the first unsolved cell in reading order to its proven orientation
## and pins it there, so it can never be turned again. Reading order rather
## than anything cleverer, for Word Trail's reason: it is predictable, it
## needs no state, and a hint that guesses what the player wanted can guess
## wrong. A hint also empties the undo log (Shikaku's rule) -- what it
## settled is not a move to take back.
func hint() -> bool:
	if is_done() or out_of_hearts or _fusing() or hints_left() <= 0:
		return false
	var before: PackedInt32Array = state.depths()
	var grid_before: PackedInt32Array = state.grid.duplicate()
	# -1 is every cell already where the answer wants it. Nothing is spent
	# and nothing is rung: there was no hint to give.
	var at := state.hint()
	if at < 0:
		return false
	hints_used += 1
	var now := _now()
	# However many quarters it needs, in one spin rather than a stutter of
	# them -- the piece turns straight to where the solver proved it goes.
	_spin(at, _quarters(grid_before[at], state.grid[at]), now)
	_settle(before, now + _lag())
	fx.ring(cell_centre(at), _cell * RING_R, Pal.LEAF)
	fx.cue("hint")
	_dress(now)
	_refresh()
	_say(tr("FL_HINT"), Face.Expr.HAPPY)
	moved.emit()
	# A hint can finish the garden, and a finished garden is a win however it
	# was reached.
	check_solved()
	return true

## Whether Reset can do anything now: the top bar greys it while a fuse plays
## out and once the hearts are gone (Try again is the way back then), so the
## host never logs a board_reset that did nothing.
func can_reset() -> bool:
	return not (is_done() or out_of_hearts or _fusing())

## Every unpinned piece back to the scramble it was dealt. A pinned piece
## stays, because a hint is a given.
## The hearts and the clips stay as they are: only Try again gives those back.
func reset_board() -> void:
	if not can_reset():
		return
	_release_press()
	_break_streak()
	_clear_gags()
	var before: PackedInt32Array = state.depths()
	var grid_before: PackedInt32Array = state.grid.duplicate()
	state.reset_board()
	var now := _now()
	_reset_spins(grid_before, now)
	moves = 0
	_running = true
	_settle(before, now + _lag())
	_dress(now)
	_refresh()
	_say(tr("FL_RESET") + " " + _left_line(), Face.Expr.HAPPY)
	fx.cue("reset")

## Every piece that moved turns back at once, on the family's corner-out
## stagger: a cell goes its row plus its column steps after the top-left one.
## A pinned or clipped piece never moves, so it never spins.
func _reset_spins(grid_before: PackedInt32Array, now: float) -> void:
	for i in state.n * state.n:
		if grid_before[i] != state.grid[i]:
			var wait := 0.0 if Motion.reduce else Motion.stagger(
				i / state.n + i % state.n, Motion.RESET_STAGGER)
			_spin(i, 1, now + wait)

## A completed daily is dealt again from its seed, so the fresh board comes up
## scrambled and mid-entrance. Put every piece on its answer, light the whole
## run with every clock in the past, and reseat the lanterns (new Controls, so
## the entrance's untracked pop_in tweens go with the old ones) already awake
## and grinning. Never check_solved(): the host owns the win for a restore.
##
## The hearts it kept and the clips its fuses left come back from the record,
## and the party's leavings: the cat asleep, the tags gold, the seal.
func restore_completed_board() -> void:
	var t := _now()
	_gen += 1
	_close_card()
	_tip_timer.stop()
	_reset_rewards()
	state.grid = state.sol.duplicate()
	state.pinned.fill(0)
	state.clipped.fill(0)
	for c in completed_record.get("clips", []):
		if int(c) >= 0 and int(c) < state.clipped.size():
			state.clipped[int(c)] = 1
	state.history = PackedInt32Array()
	_deal()
	hearts = clampi(int(completed_record.get("hearts", max_hearts)), 0, max_hearts)
	_clear_clocks()
	# Every cell seen lit and every lantern long since woken.
	_live_at.fill(AGO)
	_opened = t - 10.0
	_build_lanterns()
	_layout()
	_dress(t)
	for i in _lanterns:
		var lantern: LanternFace = _lanterns[i]
		lantern.scale = Vector2.ONE
		lantern.expression = Face.Expr.JOY
	# The party's leavings and none of its motion: the cat asleep on the
	# frame's foot, the tags gold, and the seal when the solve earned one.
	_flawless = bool(completed_record.get("flawless", false))
	_cat_at = t - 100.0
	_place_cat(t)
	if state.wish_tags():
		_gold_at = t - 100.0
	if _flawless or state.band == 3:
		_stamp_at = t - 100.0
	_life_layer.queue_redraw()
	_say(tr("FL_WIN"), Face.Expr.JOY)
	_refresh()

## How many quarter turns clockwise take `from` to `to`; 0 if it is already
## there (which is a hint that only pinned a cell, and spins nothing).
static func _quarters(from: int, to: int) -> int:
	var m := from
	for q in 4:
		if m == to:
			return q
		m = Gen.cw(m)
	return 0

## Solved is the rule and never the answer: every stub meets a stub and every
## cell is live. The `state.n > 0` guard is what keeps an unstarted board
## from reporting itself finished -- both of the state's loops run over no
## cells at all and come back true.
func is_solved() -> bool:
	return state.n > 0 and state.is_solved()

## What a reopened daily needs to look as it was left: the hearts kept, the
## pieces a fuse clipped, and whether it was flawless (the seal). Plain
## values only (it goes through a ConfigFile).
func completion_record() -> Dictionary:
	var clips: Array = []
	for i in state.clipped.size():
		if state.clipped[i] == 1:
			clips.append(i)
	return {"hearts": hearts, "clips": clips, "flawless": _flawless}

## One glyph a lantern, so a shared board shows how big the garden was and
## never how it was wired; then the seal's words on a line of their own:
## `🏷️ Wish Tags` for any Insane garden (and ` · Flawless` when it was),
## `🏅 Flawless` otherwise.
func share_glyphs() -> String:
	var out := "🏮".repeat(state.lanterns().size())
	var seal := ""
	if state.band == 3:
		seal = "🏷️ " + tr("FL_TAGS_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless:
		seal = "🏅 " + tr("BN_FLAWLESS")
	return out if seal.is_empty() else out + "\n" + seal

# --- the win ---

## Five lit paper lanterns laid across the win screen -- this board's own
## cast, which is the lanterns. `ui/flat/well_done.gd` lays a cast of faces
## and draws no cord, so the cord the mock strings between them is not
## shipped and nobody edits `well_done.gd` for it.
func flat_win() -> Dictionary:
	var faces: Array[Control] = []
	for i in Pal.LANTERN_PAPER.size():
		var lantern := LanternFace.new()
		lantern.hue = i
		lantern.lit = 1.0
		lantern.iron = true
		faces.append(lantern)
	return {"faces": faces, "subtitle": tr("FL_WIN")}

## Long enough for the last wash to finish and every lantern to wake, and
## WIN_WAIT after that. It spends the wash's own clock (`_wash_end`, set by
## `_settle`), so the win screen and the wash can never disagree about how
## long the wash is -- Bridges' arrangement. Under reduce-motion there is no
## wash, so the win follows the last turn. PARTY_EXTRA more lets the cat
## curl up and the seal land before the win screen covers them.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return maxf(0.0, _wash_end - _now()) + WIN_WAIT + PARTY_EXTRA

## The garden is lit. There is no solve wave of its own here: the wash that
## won it *is* the wave, running out from the post over the branch the last
## turn joined, and every lantern grins as it arrives. The card stays alive
## until the last of them has woken.
func _on_solved() -> void:
	_tip_timer.stop()
	_dress(_now())
	_refresh()
	_say(tr("FL_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	# The chase leaves the post once the winning wash has landed.
	var depths: PackedInt32Array = state.depths()
	var far := 1
	for d in depths:
		far = maxi(far, d)
	_chase_step = minf(CHASE_STEP, CHASE_SPAN / float(far))
	_chase_at = _now() + maxf(0.0, _wash_end - _now()) + CHASE_LAG
	_busy_for(_chase_at - _now() + float(far) * _chase_step
		+ Motion.FLASH_IN + Motion.FLASH_OUT + Motion.BUMP_TIME)
	# Flawless: no hint, and no fuse on a judged garden, or on Easy and Medium
	# never an undo. The streak's bubble goes; the party takes over.
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 else not _undo_ever)
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
	_streak_gen += 1
	_party()

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
