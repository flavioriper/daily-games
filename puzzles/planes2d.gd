extends "res://core/puzzle_base.gd"

## Paper Planes as a flat board: a lattice of faint dots with bent ink trails
## laid over it, each one ending in a folded paper dart. Tap a plane and it
## launches -- if, and only if, every cell straight ahead of its dart is empty
## out to the edge of the board. Clear the sky and the board is done. The
## rules live in puzzles/planes_state.gd, which this only draws.
##
## **On Easy and Medium nothing here can go wrong.** A launch only ever empties
## cells, so it can never block another plane: there is no Check, no lose, and
## no order of taps that can dead-end the board (spec section 3). Undo and
## Reset are convenience rather than repair, and a refused tap costs nothing
## at all -- no life, no counter, no mark left behind.
##
## **The polish (2026-09-30, docs/superpowers/specs/2026-09-30-paper-planes-
## polish-design.md, sections 1, 3 and 5).** Hard and Insane judge a tap
## (`State.judged`): a tap on a blocked plane is **a crash**. The plane takes
## off anyway, flies up its lane to whatever is in the way, bonks its nose,
## crumples a little and flutters home while a heart splits on the paper pill
## over the card; the blocker shivers (a plane) or puffs (a cloud). Nothing
## in the state changes -- `launch()` refuses -- so the crash is all picture,
## on one clock (`_crash`) that holds input, Undo, Hint and Reset (`busy()`).
## Out of hearts the planes left droop, dusk falls and the out-of-hearts card
## comes up (Fairy Lights' and Quilt's family). **Insane is Windy Day**: soft
## clouds over the sky, one cached mesh drawn under a transform each on a
## layer of their own (`_sky_layer`), which glide a cell downwind on every
## launch or gust; a dotted ghost shows where each will be next and a wind
## sock on the panel's rim points the way. When the clouds close in
## (`State.stuck()`), a tap on a cloud spends a heart to blow the wind on.
## A **press dip** sinks and shades a plane under one finger, and the plane
## goes only when that finger lifts from it (a stray tap now costs a heart);
## an **idle flutter** lifts one resting plane's wing tip now and then.
##
## How it is drawn. Two meshes and no Controls, because nothing here has a face
## on it and a Control per plane would be fifty-two nodes on the hard band. The
## **still** mesh is the paper panel, the hint's glow and every plane at rest;
## the **live** one is the dots, the leaves, the refusal's band, the contrails
## and every plane that is moving. The still one is rebuilt only when the set
## of moving planes changes, so a flight rebuilds one plane and not fifty. The
## planes themselves are `ui/faces/paper_plane.gd`'s drawing, which the menu
## card makes too. Each mesh the last `_draw` handed over is kept (`_shown`,
## `_still_shown`) until the next replaces it: **a canvas command holds a mesh by RID and not by reference**,
## so dropping the only reference to a mesh still on the item's command list
## leaves the renderer drawing a freed one ("Parameter mesh is null", and an
## empty card) on any frame a harness forces with
## `RenderingServer.force_draw()`.
##
## How it moves (spec section 10). Nothing here tweens a node, because there
## is no node to tween: every moment is a **book of moments** -- a plane index
## against the second something began -- read off the clock in `_draw` through
## `core/motion.gd`'s curve readers, which is docs/art/flat-motion.md's rule 8.
## There are four books (`_fly`, `_beat`, `_shiver`, `_nudge`) and one record
## (`_refuse`), and `_animating()` asks about **every one of them**: One Line
## shipped two lines frozen at four fifths of a fade because a second wave was
## left out of that function, and this board has six waves able to overlap.
## Every book is emptied as its moment expires (`_retire`), so the quiet board
## is quiet and none of it is state: **the wake in particular is derived from
## a diff of `free_planes()` and never stored**, which is Queens' `_settle`,
## so an undo leaves nothing behind to clean up.
##
## Spec: docs/superpowers/specs/2026-09-20-paper-planes-flat-design.md,
## sections 7 to 10. Ported from the canvas mock at
## docs/brainstorm/concepts.html#planes, which is the reference for every
## measure here; the two places the mock and the spec differ are named at the
## constants they differ on, and each says which number was taken and why.

const State = preload("res://puzzles/planes_state.gd")
const PaperPlane = preload("res://ui/faces/paper_plane.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const NapCat = preload("res://ui/faces/nap_cat.gd")
const Seal = preload("res://ui/flat/seal.gd")
const CozyTheme = preload("res://ui/theme.gd")

# --- the screen, measured (spec section 7) ---
## The board card's own inset: 28 off a 1000 by 1340 card leaves a field box
## of 944 by 1284, and the cell is the largest whole number of pixels that
## fits the band's grid in it -- 91 on easy, 71 on medium, 58 on hard.
const INSET := 28.0

# --- the pieces, every one of them a fraction of the cell (spec section 8) ---
## An empty cell's dot, and how far its LINE is let through. This is what
## makes the occupancy read at a glance, and it is the one thing the
## reference's picture gets exactly right.
const DOT := 0.05
const DOT_ALPHA := 0.45
## The paper panel the field is pressed into: how far it stands out round the
## grid, its rim, and its corner. Pixels, because the card's own inset is.
const PANEL_PAD := 13.0
const PANEL_RIM := 7.0
const PANEL_RADIUS := 22.0
## Leaves lying between the cells: one lattice corner in this many that has
## room for one, never fewer than MIN_SPRIGS, and how big one is.
const SPRIG_EVERY := 4
const MIN_SPRIGS := 4
const SPRIG_R := 0.4
## The lane band a refusal lays down the cells ahead of a dart. **0.34 was drawn
## against 0.86 at the hard band's 58 px cell and kept** (Task 4): a stripe
## a third of a cell wide runs down the middle of the lane and leaves the
## dots on either side of it showing, so the band reads as *the way out* --
## the line the plane would take -- while 0.86 floods the cells kerb to kerb,
## swallows those dots and reads as a highlighted region, which is a
## different sentence about the same rule. The stripe is also what the mock
## draws (its `WASH_W`, 0.34, for the refusal, the press preview and the
## hint's glow alike); the spec's "0.86 wash" was a misreading of it, and the
## spec's section 8 is amended to say so rather than to record a
## disagreement that was never there.
## A refusal's own band is `BAD_TILE` at the flash's level and needs no alpha
## of its own, so this is the only lane width on the board. **The mock's
## second lane -- `SUN` at 0.35 under a held finger, previewing a lane that
## *is* clear -- was struck rather than built** (Task 6). Two reasons, and
## the first is the binding one: **this board acts on press-down**, so there
## is no held-finger state to preview with. A preview would have to wait for
## a press that has already launched the plane, which means either a gate on
## the press (the one thing `_tap` is written not to have) or a second,
## slower input path -- and either would change what a single press does,
## which is what `tests/_win.gd`'s `_tap_local` drives and what the whole
## one-frame solve depends on. The second is that it would be saying a thing
## already said better: **the flight is the preview**. Tap a plane with a
## clear lane and it flies down that exact band, so the lane is shown by the
## plane taking it rather than by a stripe promising it could.
const LANE_W := 0.34
## The wash that stays under a hinted plane until it goes, and the ring that
## lands on its head: the only glow on this board. **This one is wider than
## the mock's** -- the mock draws every wash at its single `WASH_W` of 0.34 --
## and it is kept wide on purpose, because it is doing a different job: the
## lane band above names a *path* and wants to read as a line, and this names
## a *piece* and wants to read as a halo round the body it sits under. Shot
## both ways at 58 px (Task 4): 0.34 under a 0.17 trail leaves a gold rim
## barely a stroke wider than the ink, which reads as the trail having been
## outlined rather than as a light standing under the plane, and under the
## dart itself it all but disappears.
const GLOW_W := 0.86
const GLOW_ALPHA := 0.32
const RING_R := 0.5

## A hint only ever *names* a plane that can go -- it never launches it.
## How many a band starts with is the state's (`State.hints_for`: 3, 3, 1
## and none on Windy Day).
## The entrance's stagger cap. A plane pops in ENTER_STAGGER after the one a
## king-move nearer the top-left corner, and **the cap is this board's own**:
## fifty-two planes at the family's uncapped 0.6 is a minute of entrance, so
## the number goes through `Motion.stagger`'s `cap` parameter rather than
## into a copied constant (docs/art/flat-motion.md's rule for a number that
## has to differ).
const ENTER_CAP := 0.5

# --- this board's own motion, and no more of it (spec section 10) ---
## **Three constants, and nothing added to `core/motion.gd`.** Everything
## else below is a recipe from the vocabulary read as a curve, or a number
## handed to a recipe through its own parameter (rule 6).
##
## Cells a second along the track. Nothing else in the game moves a piece
## along its own body, so nothing else can want this number. The floor under
## a short flight is **not a fourth constant**: it is the family's
## `Motion.POP_IN`, because a launch is never quicker than the pop a piece
## arrives with, and a two-cell dart on a one-cell lane would otherwise blink
## out rather than fly.
const LAUNCH_SPEED := 22.0
## One ring of the wake per king-move step out from the departing plane's
## head. `Motion.WAVE_STEP` is 0.045 and measures a queen's *sight*, which is
## a fact about the piece that moved; this measures a *departure*, and the
## field it crosses is twenty-two rows rather than a court of eight.
const WAKE_STEP := 0.04
## How long the refused lane holds its band. The family's own flash runs
## `FLASH_IN` + `FLASH_OUT` = 0.6 s; this one is shorter because a refusal
## here is frequent by design and 0.6 s of rose across half the board reads
## as a scolding. The *shape* is still the family's, compressed into this:
## see `_flash_now`.
const BLOCK_FLASH := 0.35
## How long a stretch of contrail holds after the dart has passed over it.
const CONTRAIL := 0.55
## How long a dart takes to rise off the paper as it launches.
const LIFT_TIME := 0.14

## How long the win screen waits behind the board, and **it is arithmetic
## rather than taste** -- the two things that still have to happen when the
## last plane is tapped, added up at their worst:
##
## - **The last flight: 1.364 s.** A flight is `_s_end / LAUNCH_SPEED` with a
##   `Motion.POP_IN` floor. **The plane a first draft of this comment
##   described cannot exist**: a ten-cell plane's head on row 0 of the
##   22-row hard band, pointing off that edge, needs a cell at row -1 for
##   `add_plane` to derive its direction from -- the head is never the first
##   row a plane can point off of. The true ceiling is a head on **row 1**:
##   a body of 9 cells behind the head, a lane of 20 to the far edge, and one
##   more cell for the tail to leave on, for `_s_end` 30. 30 / 22 = 1.364 s,
##   the longest flight this game can generate; the worst actually measured
##   over 120 generated boards was `_s_end` 29 (1.318 s). **Since the
##   polish pass the tail flies on past the card's margin** rather than one
##   cell, which is at most about a cell more on the hard band: 1.41 s.
## - **The solve wave after it: 1.25 s.** `SOLVE_DELAY` (0.25) plus the far
##   corner's own stagger, which `Motion.stagger` caps at 0.6 however wide
##   the field is (rule 4, and a 16 x 22 field reaches that cap), plus
##   `SOLVE_TIME` (0.4).
##
## 1.41 + 1.25 = 2.66, rounded up. `WIN_WAIT` stays at 2.7, with 0.04 s to
## spare now that the tail clears the margin.
## It is the longest wait of any flat board -- Shikaku's 2.2 was the previous
## -- and the cost is named rather than hidden: when the last plane's flight
## is a short one, which is the common case, the board stands empty and still
## for up to a second after the wave before the win screen arrives. That is
## the price of a constant, which is the shape every sibling uses; the
## alternative is a `win_delay()` that measures the flight it is actually
## waiting for, and nothing in the family does that yet.
const WIN_WAIT := 2.7

const TIP_CYCLE := 8.0
const TIPS := [
	"PP_TIP_TAP",
	"PP_TIP_LANE",
	"PP_TIP_SAFE",
	"PP_TIP_FRONT",
]
## Hard leads with what a heart is for; Windy Day with the wind's two lines.
const TIPS_HEARTS := ["PP_TIP_HEARTS", "PP_TIP_TAP", "PP_TIP_LANE", "PP_TIP_FRONT"]
const TIPS_WIND := ["PP_TIP_WIND", "PP_TIP_WIND_2", "PP_TIP_HEARTS", "PP_TIP_FRONT"]

## A moment far enough in the future never to arrive, and one far enough in
## the past that every curve reader is already past the end of it.
const FAR := 1.0e9
const AGO := -1.0e9

# --- the hearts (polish section 1; Quilt's and Fairy Lights' pill) ---
## The strip the hearts take over the panel on Hard and Insane: the grid
## gives up the room (Quilt's 64). The pill sits HEART_TOP under the card's
## top edge, clear of the panel's rim below it.
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
## While the clouds have closed in, the pill breathes: this much bigger at
## the top of a breath, one breath a PILL_BREATH seconds. It is the pill
## saying "a heart buys a gust" without a word.
const PILL_PULSE := 0.08
const PILL_BREATH := 0.9
const DUSK := Color(0.74, 0.76, 0.92)
const DUSK_TIME := 0.8
const CARD_AFTER := 1.1
const CARD_AFTER_STILL := 0.3
## The planes left sink and dim over this as the hearts run out.
const DROOP_TIME := 0.5
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"

# --- the crash (polish section 1), on its own clock from the tap ---
## Cells a second the plane rushes up its lane at (slower than a launch, so
## the bonk is seen coming), and the least it lunges when the blocker is the
## very next cell. The nose stops CRASH_INTO short of the blocker's centre:
## the dart's tip reaches into its cell a hair.
const CRASH_SPEED := 13.0
const CRASH_MIN := 0.3
const CRASH_INTO := 0.92
const CRASH_OUT_MIN := 0.14
## The bonk: the nose held on the blocker this long, knocked back this many
## cells, the dart crumpled this much along its length.
const BONK_HOLD := 0.16
const BONK_BACK := 0.14
const CRUMPLE := 0.24
## The flutter home: how long, how far a wing-rock carries it across its own
## line (cells) and how far it rocks (radians), dying out as it lands.
const HOME_TIME := 0.55
const HOME_SWAY := 0.12
const HOME_ROCK := 0.32
## The heart splits this long after the bonk.
const SPLIT_LAG := 0.08

# --- Windy Day (polish section 3) ---
## How long a cloud takes to glide its one cell, and the longest a Reset or a
## Try again takes to blow every cloud back to where the day began.
const GLIDE := 0.35
const GLIDE_BACK_MAX := 0.8
## The clouds: drawn at this much opacity over the planes, so a body under
## one still reads; the ghost of the next position at this.
const CLOUD_ALPHA := 0.8
const GHOST_ALPHA := 0.42
## How much a cloud swells when it is bonked or pressed (a bump).
const CLOUD_POKE := 0.18
## `drift` under each glide, quietly: it plays on every launch.
const DRIFT_DB := -9.0
## The wind sock: how far it swings about its pole (radians) and how long a
## swing takes; it also ripples along its length.
const SOCK_SWAY := 0.1
const SOCK_PERIOD := 2.4

# --- the idle flutter (polish section 5) ---
## One resting plane lifts a wing tip about every IDLE_EVERY seconds (give or
## take a third), for IDLE_TIME; only that plane leaves the still mesh.
const IDLE_EVERY := 3.6
const IDLE_TIME := 0.7
const IDLE_LIFT := 0.12

# --- the rewards (polish section 4; Fairy Lights' and Quilt's) ---
## The streak: a launch plucks `combo` up the pentatonic from the second; the
## bubble from COMBO_FROM; confetti at 5, 10, 20 and every 10 after.
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0
const COMBO_DEFLATE := 0.25
const COMBO_FONT := 44
## Gags: one launch in GAG_ODDS, the kind the plane's own (any GAG_SPAN
## planes share the four kinds evenly), one at a time.
enum Gag { NONE = -1, LOOP, BIRD, ROLL, LOVE }
const GAG_ODDS := 4
const GAG_SPAN := 16
const GAG_STEP := 5
## The loop-the-loop: a circle LOOP_R cells across the lane's last stretch
## inside the grid (its far side LOOP_CLEAR short of the edge), on the side
## toward the middle of the sky; the plane slows to LOOP_SPEED cells a second
## through it, faster at the ends than over the top (LOOP_EASE).
const LOOP_R := 0.75
const LOOP_CLEAR := 0.1
const LOOP_SPEED := 9.0
const LOOP_MIN := 0.55
const LOOP_EASE := 0.6
## The barrel roll: the flight runs ROLL_SLOW times as long and the dart turns
## over ROLLS times while its head crosses the sky.
const ROLL_SLOW := 1.5
const ROLLS := 2
## Hearts in the contrail: up to LOVE_HEARTS, LOVE_GAP cells apart, each
## rising LOVE_RISE cells over LOVE_TIME.
const LOVE_HEARTS := 5
const LOVE_GAP := 0.85
const LOVE_TIME := 1.2
const LOVE_RISE := 0.7
const LOVE_R := 0.16
## The little bird: it pops up at the plane's tail, flaps after it along its
## trail at BIRD_SPEED cells a second, stops at the edge of the sky, hovers BIRD_HOVER looking for it and
## flutters off over BIRD_LEAVE. BIRD_FLAP beats a second, BIRD_PX across.
const BIRD_POP := 0.2
const BIRD_SPEED := 6.5
const BIRD_HOVER := 0.45
const BIRD_LEAVE := 0.6
const BIRD_FLAP := 9.0
const BIRD_PX := Vector2(40.0, 60.0)
const BIRD_BODY := Color("8f6a4a")
const BIRD_BREAST := Color("f0915a")
const BIRD_WING := Color("6e4f37")
## The last few: when this many planes are left, the tip counts them down
## and each wears a soft glow.
const LAST_FEW := 3
const LAST_GLOW := 0.2
## The party, PARTY_AT after the last flight lands; win_delay() waits
## PARTY_TIME past its start.
const PARTY_AT := 0.1
const PARTY_TIME := 3.3
const CHEERS := 12
## The flock: up to FLOCK_MAX darts FLOCK_PX across in a V (FLOCK_LAG
## seconds a row behind, FLOCK_SPREAD pixels a row out), from the left at
## FLOCK_IN, sweeping across at FLOCK_SPEED pixels a second, looping a circle
## FLOCK_LOOP of the card's width round and out to the right.
const FLOCK_MAX := 9
const FLOCK_PX := 64.0
const FLOCK_AT := 0.25
const FLOCK_LAG := 0.06
const FLOCK_SPREAD := 34.0
const FLOCK_SPEED := 1250.0
const FLOCK_LOOP := 0.25
## The straggler: one late plane skims the panel's foot past the cat at
## STRAGGLE_SPEED, gets batted (BAT_AT) and tumbles up and away.
const STRAGGLE_SPEED := 620.0
const BAT_AT := 2.15
const BAT_TIME := 0.4
const CURL_AT := 2.7
## The nap cat: CAT_PX of the card's width, popping up on the panel's lower
## left corner at CAT_AT and hopping CAT_HOPS times along its foot.
const CAT_PX := 0.18
const CAT_AT := 0.35
const CAT_POP := 0.22
const CAT_HOPS := 3
const CAT_HOP_TIME := 0.32
const CAT_HOP_H := 0.45
const CAT_SETTLE := 0.25
## The seal on the panel's lower right corner.
const STAMP_AT := 1.1
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.16
const STAMP_TILT := -0.22
## Windy Day's send-off: the clouds turn gold over GOLD_TIME, smile, and from
## CLOUDS_GO drift away downwind and up, fading out by CLOUDS_GONE.
const GOLD_TIME := 0.4
const CLOUDS_GO := 0.8
const CLOUDS_GONE := 2.0

## The press's targets beside a plane's index: nothing, or a cloud on a
## stuck sky (a gust).
const NO_TARGET := -1
const GUST_TARGET := -2

## The out-of-hearts card's Back: the host takes the board away.
signal leave

## What the sprout says after a launch, and **it stops** (spec section 13).
## The first few launches are still teaching the rule, so each gets a line;
## after that a launch says nothing at all and whatever was on the card
## stays. **It never counts planes**: the board is its own scoreboard, and
## "forty-one planes left" said forty-one times on the hard band is noise
## over a picture that already says it better -- the sky empties in front of
## the player. That is Mushroom Patch's rule about a running commentary,
## taken further because this field is five times the size of that patch.
const SAID := [
	"PP_SAID_1",
	"PP_SAID_2",
	"PP_SAID_3",
]

var _state = State.new()
## The board's own effects node, as on every flat board: the hint's ring
## comes through it and nowhere else.
var fx: Node2D

## The layout, recomputed on a resize and on a new board rather than on every
## read: the cell's side in pixels and the grid's top-left inside this
## Control's rect.
var _cell := 0.0
var _origin := Vector2.ZERO

## The field: the dots, the hint's wash, the trails, the darts and the
## creases, in one mesh. Dropped whenever something changed so the next
## _draw rebuilds it.
var _field: ArrayMesh
## The mesh the last _draw actually handed to the canvas item. See the note
## at the top: a canvas command holds it by RID, so it is kept until the next
## one takes its place.
var _shown: ArrayMesh
## The still mesh, the key of the moving planes it was built without, and the
## one last handed over.
var _still: ArrayMesh
var _still_key := ""
var _still_shown: ArrayMesh
## The leaves on the paper: {"at": lattice corner, "ang", "flower"}, chosen
## once a board off its own layout.
var _sprigs: Array[Dictionary] = []

var _opened := 0.0
var _anim_until := 0.0
## The plane a hint named, or -1: it keeps a soft wash under it until it goes.
var _hint_lit := -1
## The second the solve wave begins, or -1 while there is no wave. It is a
## record and not a book, exactly like `_refuse`: `_retire` clears it the
## frame it runs out, so the quiet board is quiet.
var _solved_at := -1.0
## The cell the last plane's head stood on, which is where the solve wave is
## staggered out from -- the point the sky was emptied at.
var _solve_from := Vector2i.ZERO

# --- the books of moments ---
## The flights in the air: plane index -> {"at", "dur", "s_end", "back"}.
## **Not state.** The state is launched on the tap and this only draws the
## going, which is what lets several planes be in the air at once and what
## lets `tests/_win.gd` clear a whole board inside a single frame. A `back`
## flight is an undo's or a reset's, the same track run the other way.
var _fly: Dictionary = {}
## The wake: plane index -> the second its wings beat. Written by `_wake`
## off a diff of `free_planes()` across the tap and never read for anything
## but the beat, so an undo has nothing to undo here.
var _beat: Dictionary = {}
## The refusal's two movers: the blocking plane's shiver and the tapped
## plane's nudge, each plane index -> the second it began.
var _shiver: Dictionary = {}
var _nudge: Dictionary = {}
## The refused lane itself: {"cells": Array[Vector2i], "at": float}, or empty.
var _refuse: Dictionary = {}
## Sparkles waiting for the plane they belong to to reach the edge of the
## board: {"at": float, "pos": Vector2, "i": int}. `ui/fx2d.gd` has no delay
## of its own and fifty CPU timers is fifty too many, so `_process` fires
## them. The plane index rides along so `_fly_back` can drop a puff whose
## flight reversed before it fired.
var _puffs: Array[Dictionary] = []

var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

## The hearts (Hard and Insane): how many are left of how many, whether they
## have run out, and the pill's own moments -- Fairy Lights' names.
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
## Whether a heart has ever been spent on this deal, by a crash or a gust
## (the seal reads it in the rewards pass).
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
var _hearts_y := 0.0
var _dusk_tw: Tween
## When the planes left began to droop (FAR: they have not).
var _droop_at := FAR
## Bumped on every deal, so an `_after` from the last one never lands.
var _gen := 0
## The crash in the air: {"i", "at", "bonk", "adv", "end", "cloud"}, or
## empty. Input, Undo, Hint and Reset wait until `_busy_until`.
var _crash: Dictionary = {}
var _busy_until := 0.0
## Under reduce motion a crash has no flight: the blocker's cell is ringed
## for a moment instead ({"cell", "until"}, or empty).
var _ringed: Dictionary = {}

## The press: what is under the finger (a plane's index or GUST_TARGET),
## when it landed, when it lifted (-1 while still down), and the touch index
## of that finger (-1 for the mouse).
var _press_target := NO_TARGET
var _press_down := AGO
var _press_up := -1.0
var _press_finger := -1

## The idle flutter: the plane lifting a wing tip and when, and when the next
## one is due.
var _idle_plane := -1
var _idle_at := AGO
var _idle_next := FAR

## Windy Day. The clouds are drawn at a continuous count that glides from
## `_glide_from` to the state's `count()` over `_glide_dur` from `_glide_at`,
## so a launch, a gust, a Reset and a Try again all move them the same way.
var _sky_layer: Control
var _glide_from := 0.0
var _glide_to := 0.0
var _glide_at := AGO
var _glide_dur := GLIDE
## One cloud, built once a layout and drawn under a transform per cloud; the
## dotted ghosts of the next position, rebuilt only when the count moves.
var _cloud_mesh: ArrayMesh
var _ghost: ArrayMesh
var _ghost_count := -1
var _ghost_shown: ArrayMesh
var _sock_mesh: ArrayMesh
## A cloud's bump: its index in `clouds` -> when it was bonked or tapped.
var _cloud_poke: Dictionary = {}
## The count a stuck sky was last announced at, so the sound plays once.
var _stuck_told := -1

## The rewards (polish section 4). The streak, and a count bumped every time
## it breaks so nothing scheduled for a broken streak lands; the bubble's own
## moments (Quilt's names); when the gag playing now is over (one at a time).
## `force_gag` is the harness's: a Gag kind every launch plays (one at a
## time still), or NONE for none at all; -2 leaves it to the day.
var force_gag := -2
var _streak := 0
var _streak_gen := 0
var _gag_until := 0.0
var _gag_gen := 0
var _combo_n := 0
var _combo_at := -INF
var _combo_pos := Vector2.ZERO
var _combo_popped := false
var _combo_out_at := -INF
var _combo_shown: ArrayMesh
var _combo_key: Array = []
## The life over the sky, a layer over everything on the card: love hearts,
## birds, the flock, the straggler, the bubble and the seal. Each list holds
## moments only, and every mesh is built once a layout and drawn through a
## transform.
var _life_layer: Control
var _life_shown: Array = []
var _life_alive := false
var _love: Array = []       # [{"at", "t", "phase"}]
var _birds: Array = []      # [{"i", "f", "t", "side"}]
var _love_mesh: ArrayMesh
var _bird_mesh: ArrayMesh
var _wing_mesh: ArrayMesh
var _flock_meshes: Array = []
var _seal_mesh: ArrayMesh
var _gold_cloud: ArrayMesh
## The party's moments, each INF until the party sets it: its start (the
## flock leaves then), the seal, the cat, the bat, the clouds' send-off; and
## the flock's colours (plane indices, the last launched leading).
var _party_at := INF
var _stamp_at := INF
var _cat: Control
var _cat_at := INF
var _cat_curled := false
var _clouds_at := INF
var _flock: Array[int] = []
var _last_plane := 0

func puzzle_id() -> String: return "planes"
func title() -> String: return "Paper Planes"

## What a lane is and what a tap does, then the band's own closing: that
## nothing can be lost (Easy, Medium), what a heart is for (Hard), or the
## wind (Insane).
func rules() -> String:
	var out := tr("PP_RULES")
	if _state.windy():
		out += "\n\n" + tr("PP_RULES_WIND") % max_hearts
	elif max_hearts > 0:
		out += "\n\n" + tr("PP_RULES_HEARTS") % max_hearts
	else:
		out += "\n\n" + tr("PP_RULES_SAFE")
	return out

## The lines the tips cycle, by band.
func _tips() -> Array:
	if _state.windy():
		return TIPS_WIND
	if max_hearts > 0:
		return TIPS_HEARTS
	return TIPS

## Undo and Hint, and nothing else. There is no Check because nothing wrong
## can ever be sitting on the board: a launch only empties cells, so the
## registry drops the actions row and Reset rides up into the top bar.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# **The card is the wall a plane disappears behind**, and this is the one
	# flat board that clips: a launch runs its track a whole body-length past
	# the edge of the grid, which is out of this Control and over the top bar
	# unless it is cut off. The Control is a full-rect child of the board
	# slot, and the board card fills that slot, so the cut lands exactly on
	# the card's own edge -- the mock's picture, where a plane flies off the
	# grid, across the hem and is gone.
	clip_contents = true
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	# The clouds and the sock, over the planes and under the hearts. A layer
	# of its own so the sock's sway and a glide redraw only it, never the
	# field.
	_sky_layer = Control.new()
	_sky_layer.name = "Sky"
	_sky_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_layer.z_index = 1
	_sky_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky_layer.draw.connect(_draw_sky)
	add_child(_sky_layer)
	_heart_layer = Control.new()
	_heart_layer.name = "Hearts"
	_heart_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heart_layer.z_index = 1
	_heart_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_heart_layer.draw.connect(_draw_hearts)
	add_child(_heart_layer)
	# The rewards over everything on the card: hearts and birds, the flock,
	# the bubble and the seal.
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
	max_hearts = State.hearts_for(_state.difficulty) if _state.judged else 0
	_heart_used = false
	_lost_ever = false
	_undo_ever = false
	_flawless = false
	_hint_lit = -1
	_anim_until = 0.0
	_solved_at = -1.0
	_solve_from = Vector2i.ZERO
	_forget()
	_deal()
	_reset_rewards()
	_place_sprigs()
	_layout()
	_enter()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()

## The sky as it is dealt, and as Try again deals it back: every heart, the
## day's light, no crash, the clouds where the clock says.
func _deal() -> void:
	hearts = max_hearts
	out_of_hearts = false
	_asleep = false
	_split_index = -1
	_split_at = AGO
	_back_index = -1
	_back_at = AGO
	_droop_at = FAR
	_crash = {}
	_busy_until = 0.0
	_stuck_told = -1
	_cloud_poke = {}
	_glide_from = float(_state.count())
	_glide_to = _glide_from
	_glide_at = AGO
	_ghost = null
	_clear_press()
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	_idle_plane = -1
	_idle_next = _now() + IDLE_EVERY
	if _heart_layer != null:
		_heart_layer.queue_redraw()
	if _sky_layer != null:
		_sky_layer.queue_redraw()

# --- layout ---

## The largest whole cell the card holds, and the grid centred in it. **Every
## band is bound by the height** -- 91, 71 and 58 against the 944 the width
## would allow -- so the few pixels left over go into the centring and there
## is nothing else to spend them on.
##
## On Hard and Insane the hearts' strip comes off the top first (HEART_ROW),
## and the grid is centred in what is left under it.
func _layout() -> void:
	_cell = 0.0
	_origin = Vector2.ZERO
	var row := _heart_row()
	if _state.cols > 0 and _state.rows > 0:
		_cell = maxf(0.0, floorf(minf(
			(size.x - 2.0 * INSET) / float(_state.cols),
			(size.y - row - 2.0 * INSET) / float(_state.rows))))
		_origin = Vector2((size.x - float(_state.cols) * _cell) * 0.5,
			row + (size.y - row - float(_state.rows) * _cell) * 0.5)
	_hearts_y = HEART_TOP + HEART_PILL_PAD.y + HEART_R
	_cloud_mesh = null
	_sock_mesh = null
	_ghost = null
	_gold_cloud = null
	_love_mesh = null
	_bird_mesh = null
	_wing_mesh = null
	_flock_meshes = []
	_seal_mesh = null
	_combo_shown = null
	if is_instance_valid(_cat):
		_place_cat(_now())
	if _life_layer != null:
		_life_layer.queue_redraw()
	if _heart_layer != null:
		_heart_layer.queue_redraw()
	if _sky_layer != null:
		_sky_layer.queue_redraw()
	_refresh_all()

## The strip the hearts take over the panel, on a sky that has them.
func _heart_row() -> float:
	return HEART_ROW if max_hearts > 0 else 0.0

## The card this board wants: every pixel it is given. The grid is taller
## than it is wide in a slot that is taller than it is wide, so the height
## binds and there is no slack worth capping.
func card_height(available: float) -> float:
	return available

## False, and honestly so: card_height() hands back everything, so the slack
## is zero and there is nothing to centre. Word Trail's answer, for Word
## Trail's reason.
func card_centred() -> bool:
	return false

func _centre(cell: Vector2i) -> Vector2:
	return _origin + (Vector2(cell) + Vector2.ONE * 0.5) * _cell

## Control-local point over the centre of the cell at (row, column), the name
## every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(Vector2i(c, r))

## The cell under a local point, or (-1, -1). There are no gaps between cells
## on this board -- the lattice is continuous -- so every point inside the
## grid belongs to one.
func _cell_at(local: Vector2) -> Vector2i:
	if _cell <= 0.0:
		return Vector2i(-1, -1)
	var p := (local - _origin) / _cell
	var at := Vector2i(int(floorf(p.x)), int(floorf(p.y)))
	return at if _state.in_board(at) else Vector2i(-1, -1)

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _state.planes.is_empty():
		return
	var t := _now()
	_spend_puffs(t)
	# Sudoku's lesson: decide once a frame, here, and never again in _draw --
	# two asks disagreeing on the frame a moment expires is the One Line bug
	# in another costume. A moment that has just landed still owes one frame,
	# which is what _retire's answer buys. It runs **before** the cell guard
	# on purpose: a board with no layout yet still has to let its books empty,
	# or `_animating()` is true for ever the moment one is ever given a size.
	var dirty := _retire(t)
	if _cell <= 0.0:
		return
	_idle_tick(t)
	if dirty or _animating(t):
		_refresh()
	# The droop rebuilds the still mesh (every plane at rest sinks), so it is
	# asked for here and not through the live field.
	if _droop_at < FAR and t - _droop_at < DROOP_TIME + 0.05:
		_refresh_all()
	# The pill pops in with the field, splits, takes a heart back, and
	# breathes while the clouds have closed in.
	if max_hearts > 0 and ((_split_index >= 0 and t - _split_at < SPLIT_TIME + 0.1)
			or (_back_index >= 0 and t - _back_at < HEART_BACK_TIME + 0.1)
			or t - _opened < Motion.ENTER_DELAY + Motion.POP_IN + 0.1
			or _pill_breathing()):
		_heart_layer.queue_redraw()
	# The sky: the sock sways for ever on a windy day (one transform, no
	# rebuild), and a glide or a bump moves the clouds.
	if _state.windy() and (not Motion.reduce or t - _glide_at < _glide_dur + 0.1
			or t - _opened < 1.0):
		_sky_layer.queue_redraw()
	# The life over the sky, and one more redraw once it goes quiet so its
	# last frame is not left standing; the cat on her own clock.
	var alive := _tick_life(t)
	if alive or _life_alive:
		_life_layer.queue_redraw()
	_life_alive = alive
	if t >= _cat_at and not _cat_curled:
		_place_cat(t)

## Whether anything on this card is still moving, and **every wave is in
## here** -- the entrance, the hint's ring (through `_anim_until`), the
## flights, the wake's beats, the refusal's band, its shiver and its nudge.
## One Line shipped two lines frozen at four fifths of a fade because one
## wave was left out of its own version of this, and it showed in a rendered
## frame and in no test. The books are asked directly as well as through
## `_anim_until`, so a moment cannot outlive the window that was booked for
## it: whichever is longer wins.
func _animating(t: float) -> bool:
	if t < _anim_until:
		return true
	if not _fly.is_empty() or not _beat.is_empty():
		return true
	if not _shiver.is_empty() or not _nudge.is_empty() or not _refuse.is_empty():
		return true
	# The crash, the press (down, or springing back) and the idle flutter.
	if not _crash.is_empty() or _press_target >= 0 or _idle_plane >= 0 or not _ringed.is_empty():
		return true
	# The solve wave, which `_retire` clears the frame it runs out; while it
	# is set, the dots are still hopping (or waiting for the last flight to
	# land before they start).
	if _solved_at >= 0.0:
		return true
	if Motion.reduce:
		return false
	# The field's wide pop, then the last plane's own pop at the far end of
	# the capped stagger.
	return t - _opened < Motion.ENTER_DELAY + ENTER_CAP + Motion.POP_IN

## Closes every moment that has run out, so a landed plane is drawn from the
## state again and a quiet board goes quiet. Answers true when something
## actually left, because that frame is the first one drawn without it.
func _retire(t: float) -> bool:
	var dirty := false
	for i in _fly.keys():
		var f: Dictionary = _fly[i]
		# An outbound flight stays in the book until its contrail has faded.
		var tail := 0.0 if bool(f["back"]) else CONTRAIL
		if t >= float(f["at"]) + float(f["dur"]) + tail:
			_fly.erase(i)
			dirty = true
	for i in _beat.keys():
		if t >= float(_beat[i]) + Motion.BUMP_TIME:
			_beat.erase(i)
			dirty = true
	for i in _shiver.keys():
		if t >= float(_shiver[i]) + Motion.SHIVER_TIME:
			_shiver.erase(i)
			dirty = true
	for i in _nudge.keys():
		if t >= float(_nudge[i]) + Motion.NUDGE_LAG + Motion.NUDGE_TIME:
			_nudge.erase(i)
			dirty = true
	if not _refuse.is_empty() and t >= float(_refuse["at"]) + BLOCK_FLASH:
		_refuse = {}
		dirty = true
	if _solved_at >= 0.0 and t >= _solved_at + _wave_span():
		_solved_at = -1.0
		dirty = true
	if not _crash.is_empty() and t >= float(_crash["end"]):
		_crash = {}
		dirty = true
	if not _ringed.is_empty() and t >= float(_ringed["until"]):
		_ringed = {}
		dirty = true
	if _idle_plane >= 0 and t >= _idle_at + IDLE_TIME:
		_idle_plane = -1
		dirty = true
	# A press that has let go and sprung all the way home.
	if _press_target != NO_TARGET and _press_up >= 0.0 and t >= _press_up + Motion.RELEASE_TIME:
		_press_target = NO_TARGET
		dirty = true
	for k in _cloud_poke.keys():
		if t >= float(_cloud_poke[k]) + Motion.BUMP_TIME:
			_cloud_poke.erase(k)
	return dirty

## How long the solve wave takes from the second it begins: the family's own
## delay, the far corner's stagger off `_solve_from` (capped at 0.6 by
## `Motion.stagger`, which a 16 by 22 field reaches), and one hop.
func _wave_span() -> float:
	return Motion.SOLVE_DELAY \
		+ Motion.stagger(_wave_reach(), Motion.SOLVE_STAGGER) + Motion.SOLVE_TIME

## The king-move distance from `_solve_from` to the furthest cell of the
## field, which is always one of the four corners.
func _wave_reach() -> int:
	return maxi(maxi(_solve_from.x, _state.cols - 1 - _solve_from.x),
		maxi(_solve_from.y, _state.rows - 1 - _solve_from.y))

## Every book emptied at once: a new board inherits nobody's flight.
func _forget() -> void:
	_fly = {}
	_beat = {}
	_shiver = {}
	_nudge = {}
	_refuse = {}
	_puffs = []
	_crash = {}
	_ringed = {}
	_idle_plane = -1
	_cloud_poke = {}

## The sparkles a launch leaves where it crossed the edge of the board, each
## fired on the frame its own plane reaches that point rather than when the
## tap happened. `ui/fx2d.gd` has no delay of its own; a `SceneTreeTimer` a
## plane would be fifty timers on the hard band and a generation counter to
## guard them, where this is four lines and dies with the board.
func _spend_puffs(t: float) -> void:
	var i := 0
	while i < _puffs.size():
		if t >= float(_puffs[i]["at"]):
			fx.puff(_puffs[i]["pos"], _puffs[i].get("colour", Pal.SUN_RAY))
			_puffs.remove_at(i)
		else:
			i += 1

## Drops any puff still booked for plane `i`: its flight reversed before the
## sparkle fired, and there is nothing left at that edge to mark.
func _forget_puff(i: int) -> void:
	var j := 0
	while j < _puffs.size():
		if int(_puffs[j]["i"]) == i:
			_puffs.remove_at(j)
		else:
			j += 1

## Keeps the field redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Drops the field so the next _draw rebuilds it, and asks for that draw. The
## mesh the last _draw handed over is still held by _shown, so the renderer is
## never left pointing at a freed RID.
func _refresh() -> void:
	_field = null
	queue_redraw()

## Drops both meshes: the layout moved, or the board changed under the still
## one without a plane starting or stopping (an undo under reduce motion).
func _refresh_all() -> void:
	_still = null
	_refresh()

# --- the drawing ---

## Two meshes, one transform over both: the field pops in wide about its
## centre (rule 7 -- a wide thing comes from most of the way) while each plane
## pops in about its own head. The still mesh is rebuilt only when its key
## moves -- which planes are moving, which have gone, which is hinted.
func _draw() -> void:
	if _cell <= 0.0 or _state.planes.is_empty():
		return
	var t := _now()
	var moving := _moving(t)
	var key := _key(moving)
	if _still == null or key != _still_key:
		_still = _build_still(moving)
		_still_key = key
	if _field == null:
		_field = _build_field(t, moving)
	var grow := Motion.wide_pop_scale(t - _opened - Motion.ENTER_DELAY)
	var mid := _origin + Vector2(float(_state.cols), float(_state.rows)) * _cell * 0.5
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	draw_mesh(_still, null, xf)
	_still_shown = _still
	if _field != null:
		draw_mesh(_field, null, xf)
	_shown = _field

## Every plane that has to be drawn frame by frame right now: in the air (or
## still trailing its contrail), beating, shivering, nudging, or not yet done
## popping in.
func _moving(t: float) -> Dictionary:
	var out: Dictionary = {}
	for book in [_fly, _beat, _shiver, _nudge]:
		for i in book:
			out[i] = true
	if not _crash.is_empty():
		out[int(_crash["i"])] = true
	if _press_target >= 0:
		out[_press_target] = true
	if _idle_plane >= 0:
		out[_idle_plane] = true
	if not Motion.reduce and t - _opened < Motion.ENTER_DELAY + ENTER_CAP + Motion.POP_IN:
		for i in _state.planes.size():
			out[i] = true
	return out

func _key(moving: Dictionary) -> String:
	var k := PackedStringArray([str(_hint_lit), "d%d" % int(_droop_level(_now()) * 10.0)])
	for i in _state.planes.size():
		k.append("m" if moving.has(i) else ("g" if _state.planes[i]["gone"] else "."))
	return "".join(k)

## The paper panel, the hint's glow and every plane at rest.
func _build_still(moving: Dictionary) -> ArrayMesh:
	var b := Face.Builder.new()
	_panel(b)
	if _hint_lit >= 0 and not _state.planes[_hint_lit]["gone"]:
		PaperPlane.band(b, _cell_pts(_state.planes[_hint_lit]["cells"]), _cell,
			GLOW_W * _cell, Color(Pal.SUN_RAY, GLOW_ALPHA))
	# The last few planes each wear a soft glow (a halo under the body, never
	# a shade of its own paper).
	if _last_few():
		for i in _state.planes.size():
			if not _state.planes[i]["gone"] and i != _hint_lit:
				PaperPlane.band(b, _cell_pts(_state.planes[i]["cells"]), _cell,
					GLOW_W * _cell, Color(Pal.SUN_RAY, LAST_GLOW))
	var droop := _droop_level(_now())
	for i in _state.planes.size():
		if not moving.has(i) and not _state.planes[i]["gone"]:
			_plane(b, i, 1e9, droop)
	return b.mesh()

## Whether the sky is down to its last few planes (and still being played).
func _last_few() -> bool:
	var left := _state.left()
	return left > 0 and left <= LAST_FEW and not is_done() and not out_of_hearts

## How far the planes left have drooped, 0 to 1: they sink over DROOP_TIME
## as the hearts run out, at once under reduce motion.
func _droop_level(t: float) -> float:
	if _droop_at >= FAR:
		return 0.0
	if Motion.reduce:
		return 1.0
	var u := clampf((t - _droop_at) / DROOP_TIME, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)

## The field pressed into the card: a soft drop under it, a tan rim with a lit
## inner edge, and a paper a shade creamier than the card's own.
func _panel(b) -> void:
	var span := Vector2(float(_state.cols), float(_state.rows)) * _cell
	var at := _origin - Vector2.ONE * (PANEL_PAD + PANEL_RIM)
	var sz := span + Vector2.ONE * 2.0 * (PANEL_PAD + PANEL_RIM)
	b.fan(Face.Builder.round_rect(at + Vector2(0.0, 3.0), sz, PANEL_RADIUS),
		Color(Pal.ACORN_DEEP, 0.18))
	b.fan(Face.Builder.round_rect(at, sz, PANEL_RADIUS), PaperPlane.rim_colour())
	var inner := _origin - Vector2.ONE * PANEL_PAD
	var isz := span + Vector2.ONE * 2.0 * PANEL_PAD
	var ir := PANEL_RADIUS - PANEL_RIM
	b.fan(Face.Builder.round_rect(inner, isz, ir), Pal.ACORN.lerp(Pal.STONE_GIVEN, 0.55))
	b.fan(Face.Builder.round_rect(inner + Vector2(0.0, 3.0), isz - Vector2(0.0, 3.0), ir),
		Pal.SURFACE.lerp(Pal.PARCHMENT, 0.45))
	if _state.windy():
		# The wind sock's pole, standing on the rim at the upwind corner: a
		# little wooden stick and its knob. The sock itself sways on the sky
		# layer (`_draw_sky`).
		var top := _sock_root()
		var foot := Vector2(top.x, _origin.y - PANEL_PAD - PANEL_RIM * 0.5)
		b.stroke(PackedVector2Array([foot + Vector2(2.0, 2.0), top + Vector2(2.0, 2.0)]),
			_sock_px() * 0.07, Color(Pal.ACORN_DEEP, 0.25))
		b.stroke(PackedVector2Array([foot, top]), _sock_px() * 0.07, Pal.WOOD_DEEP)
		b.disc(top, _sock_px() * 0.06, Pal.ACORN_DEEP)

## The wind sock's size: about a cell, but never so tall that its pole runs
## off the top of the card.
func _sock_px() -> float:
	return minf(_cell * 0.95, 82.0)

## The top of the pole: over the panel's upwind top corner, inside its round.
func _sock_root() -> Vector2:
	var span := float(_state.cols) * _cell
	var x := _origin.x - PANEL_PAD + PANEL_RADIUS * 0.6
	if _state.wind.x < 0:
		x = _origin.x + span + PANEL_PAD - PANEL_RADIUS * 0.6
	return Vector2(x, _origin.y - PANEL_PAD - PANEL_RIM - _sock_px() * 0.62)

## The dots, the leaves, the refusal's band, the contrails and every moving
## plane, rebuilt on every frame something moves.
func _build_field(t: float, moving: Dictionary) -> ArrayMesh:
	var b := Face.Builder.new()
	_dots(b, _covers(t), t)
	_draw_sprigs(b, t)
	if not _refuse.is_empty():
		var lv := _flash_now(t - float(_refuse["at"]))
		if lv > 0.0:
			PaperPlane.band(b, _cell_pts(_refuse["cells"]), _cell, LANE_W * _cell,
				Color(Pal.BAD_TILE.lerp(Pal.BAD, 0.25), lv))
	if not _ringed.is_empty():
		b.stroke(Face.Builder.arc_points(_centre(_ringed["cell"]), _cell * 0.46, 0.0, TAU),
			maxf(3.0, _cell * 0.07), Color(Pal.BAD, 0.85), true)
	for i in _fly:
		_contrail(b, i, t)
	var droop := _droop_level(t)
	for i in moving:
		# A plane in the air is drawn from its flight and not from the state:
		# the state let it go on the tap, and a returning one is back in the
		# state before it has flown home.
		if _fly.has(i) or not _state.planes[i]["gone"]:
			_plane(b, i, t, droop)
	return b.mesh() if not b.verts.is_empty() else null

## A faint dot on every cell no plane stands on, and a **fading** one on
## every cell a plane is in the act of leaving. This is the lattice, and it
## is why a launch reads as emptying the board rather than as a jump cut: the
## cells a plane leaves are places, not holes, and each of them comes back
## the moment the tail passes over it.
##
## The solve wave rides here too: when the sky is empty the dots and the
## leaves are the only things left on the card, so the family's wave is a hop
## on each of them, read as a curve off `Motion` -- the whole of it is `_hop`.
func _dots(b, cover: Dictionary, t: float) -> void:
	var r := DOT * _cell
	for y in _state.rows:
		for x in _state.cols:
			var cell := Vector2i(x, y)
			var shown := 1.0
			if cover.has(cell):
				shown = 1.0 - float(cover[cell])
			elif _state.plane_at(cell) >= 0:
				shown = 0.0
			if shown > 0.004:
				b.disc(_centre(cell) + Vector2(0.0, _hop(cell, t)), r,
					Color(Pal.LINE, DOT_ALPHA * shown))

## One dot's place in the solve wave: the family's `hop_lift`, handed the
## seconds since this cell's own moment began -- `SOLVE_DELAY` after the wave
## starts, plus `SOLVE_STAGGER` per king-move step out from the cell the last
## plane's head stood on. Zero before the moment, after it, and under
## reduce-motion (`_solved_at` is never set there, and `hop_lift` answers
## zero anyway, so it is stilled twice over).
func _hop(cell: Vector2i, t: float) -> float:
	if _solved_at < 0.0:
		return 0.0
	return Motion.hop_lift(t - _solved_at - Motion.SOLVE_DELAY
		- Motion.stagger(_king(cell, _solve_from), Motion.SOLVE_STAGGER),
		Motion.SOLVE_HOP, Motion.SOLVE_TIME)

## How much of each cell is still under a plane in flight, 0 to 1, for every
## cell of every flight in the air. The fade is the family's own
## (`appear_level`), read against the second that plane's **tail** crosses
## that cell rather than against a distance -- which is how the dot's return
## costs this board no constant of its own. A flight home runs it backwards:
## the dot goes out as the tail arrives.
func _covers(t: float) -> Dictionary:
	var out: Dictionary = {}
	for i in _fly:
		var f: Dictionary = _fly[i]
		var cells: Array = _state.planes[i]["cells"]
		var back: bool = f["back"]
		for j in cells.size():
			var when := _when(f, float(j))
			var lv := Motion.appear_level(t - when)
			out[cells[j]] = lv if back else 1.0 - lv
	return out

## Leaves lie on lattice corners -- between four cells, never on one -- where
## no dart's wing can reach, so a resting trail never covers one and a leaf
## never hides whether a cell is empty. Chosen off the board's own layout, so
## a day keeps its leaves.
func _place_sprigs() -> void:
	_sprigs = []
	var room: Array[Vector2i] = []
	# Which way each corner's free cells lie: a leaf points into them, so one
	# beside a trail lies away from it.
	var lean: Dictionary = {}
	for y in range(1, _state.rows):
		for x in range(1, _state.cols):
			var free := 0
			var head := false
			var toward := Vector2.ZERO
			for c in [Vector2i(x - 1, y - 1), Vector2i(x, y - 1), Vector2i(x - 1, y), Vector2i(x, y)]:
				var i := _state.plane_at(c)
				if i < 0:
					free += 1
					toward += Vector2(c) + Vector2.ONE * 0.5 - Vector2(x, y)
				elif (_state.planes[i]["cells"] as Array).back() == c:
					head = true
			if free >= 2 and not head:
				room.append(Vector2i(x, y))
				lean[Vector2i(x, y)] = toward
	var want := maxi(MIN_SPRIGS, room.size() / SPRIG_EVERY)
	var seed_h: int = absi(hash(Vector2i(_state.cols * 31 + _state.rows, _state.planes.size())))
	var k := 0
	while not room.is_empty() and _sprigs.size() < want:
		var h: int = absi(hash(Vector2i(seed_h, k)))
		var corner: Vector2i = room[h % room.size()]
		room.erase(corner)
		k += 1
		# Never two leaves side by side: a clump reads as a bush, not a leaf.
		var near := false
		for sp in _sprigs:
			if _king(sp["at"], corner) < 2:
				near = true
		if near:
			continue
		var toward: Vector2 = lean[corner]
		var ang := float(h % 628) / 100.0
		if toward.length() > 0.1:
			ang = toward.angle() + float((h >> 3) % 60 - 30) / 100.0 - 0.45
		_sprigs.append({"at": corner, "ang": ang,
			"flower": (h >> 7) % 3 == 0})

## The leaves, each fluttering as a plane goes by and hopping with the dots on
## the solve.
func _draw_sprigs(b, t: float) -> void:
	for sp in _sprigs:
		var corner: Vector2i = sp["at"]
		var at := _origin + Vector2(corner) * _cell
		var lift := 0.0
		if _solved_at >= 0.0:
			lift = Motion.hop_lift(t - _solved_at - Motion.SOLVE_DELAY
				- Motion.stagger(_king(corner, _solve_from), Motion.SOLVE_STAGGER),
				Motion.SOLVE_HOP, Motion.SOLVE_TIME)
		PaperPlane.sprig(b, at + Vector2(0.0, lift), SPRIG_R * _cell,
			float(sp["ang"]) + _flutter(corner, t), sp["flower"])

## How far a leaf is turned by the planes going past it: the family's wobble,
## timed from the moment a dart's head draws level with it. A leaf beside a
## lane is passed once on the way out and once again on an undo's way home.
func _flutter(corner: Vector2i, t: float) -> float:
	var angle := 0.0
	for i in _fly:
		var f: Dictionary = _fly[i]
		var cells: Array = _state.planes[i]["cells"]
		var n := cells.size()
		var dir := Vector2(_state.planes[i]["dir"])
		var rel := Vector2(corner) - (Vector2(cells[n - 1]) + Vector2.ONE * 0.5)
		var along := rel.dot(dir)
		if absf(rel.cross(dir)) > 0.75 or along < -0.5:
			continue
		var x := float(n - 1) + along
		var lp: Dictionary = f.get("loop", {})
		if not lp.is_empty() and along > float(lp["e0"]):
			x += float(lp["lp"])
		var when := _when(f, clampf(x, 0.0, float(f["s_end"])))
		angle += Motion.wobble_angle(t - when, Motion.WOBBLE_ANGLE * 2.5)
	return angle

## The dashed line a launched dart leaves down its lane, each stretch fading
## CONTRAIL after the dart went over it. Only on the way out: a plane coming
## home is going back to where it was, not somewhere new.
func _contrail(b, i: int, t: float) -> void:
	var f: Dictionary = _fly[i]
	if bool(f["back"]):
		return
	var cells: Array = _state.planes[i]["cells"]
	var n := cells.size()
	var reach := float(f["s_end"]) - float(n - 1)
	# In cells along the track, so a loop-the-loop leaves a dashed loop.
	var on := PaperPlane.STITCH_ON * 1.3
	var gap := PaperPlane.STITCH_OFF * 1.6
	var e := 0.3
	var colour := PaperPlane.paper(i)
	while e < reach:
		var since := t - _when(f, clampf(float(n - 1) + e + 0.3, 0.0, float(f["s_end"])))
		if since >= 0.0 and since < CONTRAIL:
			var a := 0.7 * (1.0 - since / CONTRAIL)
			b.stroke(PackedVector2Array([_track(i, float(n - 1) + e), _track(i, float(n - 1) + e + on)]),
				PaperPlane.STITCH_W * _cell * 1.25, Color(colour, a), false, true)
		e += on + gap

## One plane: its groove and its dart, wearing every moment it is in at once
## -- the entrance's pop about its **head** (that is where the eye is; a body
## scaling about its tail swings), the wake's beat across its wings, the lift
## off the paper as it launches, and the refusal's shiver or nudge under the
## whole of it. While it is in the air the body is the slice of its track
## between the tail and the head, so the tail follows the head through every
## bend the plane ever made, and the stitch travels with it.
##
## The polish adds four more: the crash (a slice of the same track, out to
## the bonk and home again, crumpled and rocking), the press dip (the whole
## plane sinks about its middle and shades), the idle flutter (one wing tip
## lifts) and the droop (the planes left sink and dim as the hearts run out).
func _plane(b, i: int, t: float, droop := 0.0) -> void:
	var cells: Array = _state.planes[i]["cells"]
	var n := cells.size()
	var dir := Vector2(_state.planes[i]["dir"])
	var crashing := not _crash.is_empty() and int(_crash["i"]) == i
	var flying := _fly.has(i) or crashing
	var s := 0.0
	if _fly.has(i):
		s = _flown(i, t)
	elif crashing:
		s = _crash_s(t)
	var head: Vector2 = _track(i, s + float(n - 1)) if flying else _centre(cells[n - 1])
	var since := t - _opened - Motion.ENTER_DELAY \
		- Motion.stagger(_king(cells[n - 1], Vector2i.ZERO),
			Motion.ENTER_STAGGER, ENTER_CAP)
	var grow := Motion.pop_in_scale(since)
	var seen := Motion.appear_level(since)
	if grow.x <= 0.0 or seen <= 0.0:
		return
	# The refusal's two movers, both read as curves: the blocker shivers
	# across the board and the tapped plane leans the way it wanted to go.
	# Both take the vocabulary's own pixels, so neither costs a constant.
	var off := Vector2(Motion.shiver_offset(t - float(_shiver.get(i, -1e9))), 0.0) \
		+ dir * Motion.nudge_offset(t - float(_nudge.get(i, -1e9)))
	var angle := dir.angle()
	var wings := Vector2.ONE
	var dim := 0.0
	var lift := _lift(i, t)
	if _fly.has(i):
		var f: Dictionary = _fly[i]
		# A loop-the-loop: the dart points along the curve it is on.
		if f.has("loop"):
			var ahead := _track(i, s + float(n - 1) + 0.05) - head
			if ahead.length() > 0.01:
				angle = ahead.angle()
		# A barrel roll: the dart turns over about its spine as its head
		# crosses the sky, its underside showing halfway round.
		if f.has("roll"):
			var span := maxf(1.2, float(_state.lane(i).size()) + 0.5)
			var turn := cos(clampf(s / span, 0.0, 1.0) * TAU * ROLLS)
			wings.y *= signf(turn) * maxf(absf(turn), 0.08) if turn != 0.0 else 0.08
	if crashing:
		# Home is a flutter: the plane rocks its wings and drifts across
		# its own line, both dying out as it lands.
		var rock := _crash_rock(t)
		off += dir.orthogonal() * rock * HOME_SWAY * _cell
		angle += rock * HOME_ROCK
		var c := _crumple(t)
		wings = Vector2(1.0 - CRUMPLE * c, 1.0 + 0.1 * c)
		angle += 0.14 * c
		lift = _crash_lift(t)
	# The press dip: the plane sinks about the middle of its body under the
	# finger and shades -- a sink of 0.94 alone is invisible on a 58 px
	# cell, so the paper darkens with it.
	var press := 1.0
	if i == _press_target:
		press = Motion.press_scale(t - _press_down, (t - _press_up) if _press_up >= 0.0 else -1.0)
		dim = maxf(dim, (1.0 - press) / (1.0 - Motion.PRESS_SCALE) * 0.55)
	# The idle flutter: one wing tip lifts a hair and settles.
	if i == _idle_plane:
		var u := clampf((t - _idle_at) / IDLE_TIME, 0.0, 1.0)
		var w := sin(u * PI) * sin(u * PI * 3.0)
		angle += w * IDLE_LIFT * 0.6
		wings.y *= 1.0 + absf(w) * IDLE_LIFT
		lift = maxf(lift, absf(w) * 0.35)
	if droop > 0.0:
		dim = maxf(dim, droop * 0.5)
		wings *= Vector2(1.0 - 0.06 * droop, 1.0 - 0.16 * droop)
		off += Vector2(0.0, 0.05 * _cell * droop)
	var sc := grow * press
	var mid: Vector2 = _centre(cells[(n - 1) / 2]) if not flying else head
	var pivot := mid if press < 1.0 else head
	var xf := Transform2D(0.0, sc, 0.0, pivot - pivot * sc + off)
	var pts: PackedVector2Array = xf * (_body(i, s) if flying else _cell_pts(cells))
	PaperPlane.trail(b, pts, _cell * sc.x, i, seen, s * _cell, dim)
	var beat := Motion.bump_scale(t - float(_beat.get(i, -1e9)))
	PaperPlane.dart(b, xf * head, angle, _cell * sc.x, i, seen,
		Vector2(1.0 + (beat - 1.0) * 0.3, beat) * wings, lift, dim)

## How far a dart has risen off the paper: up over LIFT_TIME as it launches,
## and down again over the same as a plane coming home lands.
func _lift(i: int, t: float) -> float:
	if not _fly.has(i):
		return 0.0
	var f: Dictionary = _fly[i]
	var u := clampf((t - float(f["at"])) / LIFT_TIME, 0.0, 1.0)
	if bool(f["back"]):
		u = clampf((float(f["at"]) + float(f["dur"]) - t) / LIFT_TIME, 0.0, 1.0)
	return Motion.back_out(u)

## The centres of `cells`, which is what a plane standing still is drawn
## along. A plane in flight hands its track's points instead.
func _cell_pts(cells: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for cell: Vector2i in cells:
		pts.append(_centre(cell))
	return pts

## King-move distance, the step every wave on this board is staggered by.
static func _king(a: Vector2i, z: Vector2i) -> int:
	return maxi(absi(a.x - z.x), absi(a.y - z.y))

# --- the track: the launch's one piece of arithmetic ---

## A point on plane `i`'s **track**, `x` cells along it: its own body
## polyline from the tail at 0 to the head at `len - 1`, and then straight on
## down the lane and out past the edge of the board. Everything about the
## launch is a slice of this -- the body drawn is the track between `s` and
## `s + len - 1` -- and that is why the tail follows the head through every
## bend the plane ever made instead of sliding sideways off it. **Nothing
## else in the game moves a piece along its own body.**
##
## A loop-the-loop (a gag, `_fly[i]["loop"]`) is a circle spliced into the
## lane: `e0` cells past the head the track turns up and right round a circle
## of `LOOP_R` and carries on, `lp` cells longer, so the body follows the head
## round it like a ribbon.
func _track(i: int, x: float) -> Vector2:
	var cells: Array = _state.planes[i]["cells"]
	var n := cells.size()
	if x < float(n - 1):
		var j := clampi(int(floorf(x)), 0, n - 2)
		return _centre(cells[j]).lerp(_centre(cells[j + 1]), x - float(j))
	var dir := Vector2(_state.planes[i]["dir"])
	var head := _centre(cells[n - 1])
	var e := x - float(n - 1)
	var lp: Dictionary = (_fly[i] as Dictionary).get("loop", {}) if _fly.has(i) else {}
	if not lp.is_empty() and e > float(lp["e0"]):
		var e0 := float(lp["e0"])
		if e < e0 + float(lp["lp"]):
			var th := (e - e0) / LOOP_R
			var up: Vector2 = lp["up"]
			return head + (dir * e0 + up * LOOP_R + (dir * sin(th) - up * cos(th)) * LOOP_R) * _cell
		e -= float(lp["lp"])
	return head + dir * e * _cell

## The body as a polyline, `s` cells along the track: the tail, every bend
## between it and the head, and the head. The bends are the whole-numbered
## points, because those are the cell centres the plane was drawn through.
func _body(i: int, s: float) -> PackedVector2Array:
	var n: int = (_state.planes[i]["cells"] as Array).size()
	var pts := PackedVector2Array([_track(i, s)])
	# Round a loop the body is sampled every quarter cell (which still lands
	# on every whole-numbered bend exactly).
	var per := 4 if _fly.has(i) and (_fly[i] as Dictionary).has("loop") else 1
	for k in range(int(floorf(s * per)) + 1, int(ceilf((s + float(n - 1)) * per))):
		pts.append(_track(i, float(k) / float(per)))
	pts.append(_track(i, s + float(n - 1)))
	return pts

## The whole flight, in cells: the body's own length, the lane it crosses,
## half a cell to the edge of the grid, and then however far it is from there
## to the edge of this Control -- where the clip is -- plus the groove's round
## cap, so the tail is gone and not parked in the margin round the panel.
## `lane()` is geometry and not occupancy, so this is the same number before
## the launch, during it, and on the way home.
func _s_end(i: int) -> float:
	var n: int = (_state.planes[i]["cells"] as Array).size()
	var dir: Vector2i = _state.planes[i]["dir"]
	var span := Vector2(float(_state.cols), float(_state.rows)) * _cell
	var margin := _origin.y if dir.y < 0 else (size.y - _origin.y - span.y if dir.y > 0
		else (_origin.x if dir.x < 0 else size.x - _origin.x - span.x))
	var out := 0.5 + (maxf(margin, 0.0) + PaperPlane.WIDTH * 0.6 * _cell) / maxf(_cell, 1.0)
	return float(n - 1 + _state.lane(i).size()) + out

## How long that flight takes. The floor is the family's `POP_IN` rather than
## a constant of this board's: a launch is never quicker than the pop a piece
## arrives with.
func _dur(i: int) -> float:
	return maxf(Motion.POP_IN, _s_end(i) / LAUNCH_SPEED)

## The launch's ease, and it is **the family's own curve read backwards**:
## `pop_out_scale` is a quarter-cosine falling from one to nothing, so one
## minus it rises from nothing and accelerates away, which is a launch. No
## new curve, no new constant, and nothing added to `core/motion.gd`.
static func _ease(u: float) -> float:
	return 1.0 - Motion.pop_out_scale(clampf(u, 0.0, 1.0), 1.0)

## Its inverse: the fraction of the flight at which the plane has covered `e`
## of its track. Two things need it -- the puff, which has to know the frame
## the head crosses the edge of the board, and every cell's dot, which has to
## know the frame the tail passed over it.
static func _ease_inv(e: float) -> float:
	return acos(clampf(1.0 - e, -1.0, 1.0)) * 2.0 / PI

## Where plane `i` has got to, in cells along its track. A flight home reads
## the same curve from the far end, so an undo is the launch played
## backwards and not a second animation.
func _flown(i: int, t: float) -> float:
	var f: Dictionary = _fly[i]
	var dur := float(f["dur"])
	var e := clampf(t - float(f["at"]), 0.0, dur)
	return _s_at(f, dur - e if bool(f["back"]) else e)

## The second flight `f` brings its tail `s` cells along the track: the
## outbound reading off `_tau_at`, the other way round for a flight home.
func _when(f: Dictionary, s: float) -> float:
	var tau := _tau_at(f, s)
	return float(f["at"]) + (float(f["dur"]) - tau if bool(f["back"]) else tau)

## Where flight `f`'s tail is `tau` seconds into its outbound reading, in
## cells along the track. A plain flight is the launch's ease over the whole
## of it. A loop-the-loop flight is that same flight with the stretch from
## the head entering the loop to the tail leaving it slowed to LOOP_SPEED
## (`tl` seconds where the plain one took `d0`), quicker at the ends than
## over the top.
func _s_at(f: Dictionary, tau: float) -> float:
	var lp: Dictionary = f.get("loop", {})
	if lp.is_empty():
		return float(f["s_end"]) * _ease(tau / maxf(float(f["dur"]), 0.0001))
	var s0 := float(lp["s0"])
	var dur0 := float(lp["dur0"])
	var e0 := float(lp["e0"])
	var tl := float(lp["tl"])
	var ta := dur0 * _ease_inv(e0 / s0)
	if tau < ta:
		return s0 * _ease(tau / dur0)
	if tau < ta + tl:
		return e0 + float(lp["seg"]) * _loop_w((tau - ta) / tl)
	return s0 * _ease((tau - tl + float(lp["d0"])) / dur0) + float(lp["lp"])

## Its inverse: how many seconds into the outbound reading the tail is `s`
## cells along.
func _tau_at(f: Dictionary, s: float) -> float:
	var lp: Dictionary = f.get("loop", {})
	if lp.is_empty():
		return float(f["dur"]) * _ease_inv(clampf(s / float(f["s_end"]), 0.0, 1.0))
	var s0 := float(lp["s0"])
	var dur0 := float(lp["dur0"])
	var e0 := float(lp["e0"])
	var seg := float(lp["seg"])
	var ta := dur0 * _ease_inv(clampf(e0 / s0, 0.0, 1.0))
	if s <= e0:
		return dur0 * _ease_inv(clampf(s / s0, 0.0, 1.0))
	if s < e0 + seg:
		return ta + float(lp["tl"]) * _loop_w_inv((s - e0) / seg)
	return dur0 * _ease_inv(clampf((s - float(lp["lp"])) / s0, 0.0, 1.0)) \
		+ float(lp["tl"]) - float(lp["d0"])

## The loop's own pace, 0 to 1 over its stretch: quicker at both ends than
## over the top, the way a real loop slows as it climbs.
static func _loop_w(v: float) -> float:
	return v + LOOP_EASE * sin(TAU * v) / TAU

static func _loop_w_inv(w: float) -> float:
	var v := clampf(w, 0.0, 1.0)
	for k in 6:
		v = clampf(v - (_loop_w(v) - w) / (1.0 + LOOP_EASE * cos(TAU * v)), 0.0, 1.0)
	return v

## Plane `i`'s flight out: its length, how long it takes, and a gag's shape
## -- a loop spliced into the lane, or a barrel roll's slower flight.
func _flight(i: int, gag: int) -> Dictionary:
	var s_end := _s_end(i)
	var dur := _dur(i)
	var f := {"s_end": s_end, "dur": dur}
	if gag == Gag.ROLL:
		f["dur"] = dur * ROLL_SLOW
		f["roll"] = true
	elif gag == Gag.LOOP:
		var cells: Array = _state.planes[i]["cells"]
		var n := cells.size()
		var dir := Vector2(_state.planes[i]["dir"])
		# The loop's far side LOOP_CLEAR short of the grid's edge, and on the
		# side toward the middle of the sky so it stays on the card.
		var e0 := maxf(0.0, float(_state.lane(i).size()) + 0.5 - LOOP_R - LOOP_CLEAR)
		var up := dir.orthogonal()
		var mid := _origin + Vector2(float(_state.cols), float(_state.rows)) * _cell * 0.5
		if (mid - _centre(cells[n - 1])).dot(up) < 0.0:
			up = -up
		var lp := TAU * LOOP_R
		var seg := float(n - 1) + lp
		var d0 := dur * (_ease_inv(clampf((e0 + float(n - 1)) / s_end, 0.0, 1.0))
			- _ease_inv(clampf(e0 / s_end, 0.0, 1.0)))
		var tl := maxf(LOOP_MIN, seg / LOOP_SPEED)
		f["loop"] = {"e0": e0, "up": up, "lp": lp, "seg": seg, "s0": s_end, "dur0": dur,
			"d0": d0, "tl": tl}
		f["s_end"] = s_end + lp
		f["dur"] = dur + tl - d0
	return f

## The refusal's band level: **the family's flash, compressed into
## `BLOCK_FLASH`**. `flash_level` takes its two halves as parameters, so the
## rise and the fall keep the vocabulary's own proportion (0.15 against 0.45)
## at a quarter less than the vocabulary's length -- a recipe's parameter,
## never a copied curve (rule 6).
static func _flash_now(elapsed: float) -> float:
	var span := Motion.FLASH_IN + Motion.FLASH_OUT
	return Motion.flash_level(elapsed, BLOCK_FLASH * Motion.FLASH_IN / span,
		BLOCK_FLASH * Motion.FLASH_OUT / span)

# --- the crash's curves, all read off `_crash` ---

## Where the crashing plane has got to along its own track, in cells: out to
## the bonk on the launch's own accelerating ease, knocked back BONK_BACK as
## the nose hits, then home on a sine.
func _crash_s(t: float) -> float:
	var adv := float(_crash["adv"])
	var at := float(_crash["at"])
	var bonk := float(_crash["bonk"])
	if t < bonk:
		return adv * _ease((t - at) / maxf(bonk - at, 0.001))
	var e := t - bonk
	if e < BONK_HOLD:
		return adv - BONK_BACK * sin(clampf(e / BONK_HOLD, 0.0, 1.0) * PI * 0.5)
	var u := clampf((e - BONK_HOLD) / HOME_TIME, 0.0, 1.0)
	return (adv - BONK_BACK) * (0.5 + 0.5 * cos(u * PI))

## How crumpled the dart is, 0 to 1: it folds in the instant the nose hits,
## stays folded through the bonk, and smooths out on the way home.
func _crumple(t: float) -> float:
	var e := t - float(_crash["bonk"])
	if e <= 0.0:
		return 0.0
	if e < 0.06:
		return e / 0.06
	if e < BONK_HOLD:
		return 1.0
	var u := clampf((e - BONK_HOLD) / HOME_TIME, 0.0, 1.0)
	return 1.0 - u * u * (3.0 - 2.0 * u)

## The flutter home's rock, -1 to 1: three swings dying out as it lands.
func _crash_rock(t: float) -> float:
	var e := t - float(_crash["bonk"]) - BONK_HOLD
	if e <= 0.0:
		return 0.0
	var u := clampf(e / HOME_TIME, 0.0, 1.0)
	return sin(u * PI * 3.0) * (1.0 - u)

## The dart lifts off the paper as it rushes out and settles as it lands,
## the launch's own lift at both ends.
func _crash_lift(t: float) -> float:
	var up := clampf((t - float(_crash["at"])) / LIFT_TIME, 0.0, 1.0)
	var down := clampf((float(_crash["end"]) - t) / LIFT_TIME, 0.0, 1.0)
	return Motion.back_out(minf(up, down))

# --- the moments ---

## The chrome is the host's. The field's own entrance is one wide pop about
## its centre with each plane popping in about its head, staggered by its
## king-move distance from the top-left corner; it is read off the clock in
## _draw, so all this has to do is start it.
func _enter() -> void:
	_opened = _now()
	fx.cue("enter")
	_refresh()

# --- input ---

## A tap, and nothing else: there is no drag on this board and no cell to
## focus. The cell under the finger names a plane (or, on a stuck Windy Day
## sky, a cloud), and it answers when the finger lifts.
##
## **One finger launches a plane** (Fairy Lights' review, fde0e7a), and it
## matters more here than anywhere, because on Hard and Insane a stray tap is
## a crash and a heart. The press keeps its touch index (-1 for the mouse);
## another finger's press, slide and release are ignored outright, so a thumb
## resting on the sky neither launches a second plane nor steals the dip. The
## plane goes only when the finger that went down on it lifts from it: a
## finger that slid off, a release with no press, a release on another plane
## and a touch the system cancelled launch nothing (the dip springs back). A
## press while a crash plays out is ignored. A new press from the same finger
## replaces a press whose release never came.
func _gui_input(event: InputEvent) -> void:
	if _done or out_of_hearts:
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	var finger: int = event.index if (event is InputEventScreenTouch or event is InputEventScreenDrag) else -1
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _held() and finger == _press_finger and _target_at(event.position) != _press_target:
			_release_press()
		return
	if not (event is InputEventScreenTouch or event is InputEventMouseButton):
		return
	var target := _target_at(event.position)
	if event.pressed:
		if _held() and finger != _press_finger:
			accept_event()
			return
		if target != NO_TARGET and not busy():
			accept_event()
			_press_finger = finger
			_press(target)
		return
	if not _held() or finger != _press_finger:
		return
	var pressed_on := _press_target
	_release_press()
	accept_event()
	if event.is_canceled() or target != pressed_on or busy():
		return
	if pressed_on == GUST_TARGET:
		_gust()
	else:
		_tap(pressed_on)

## What a finger at `local` would press. **A cloud only answers on a stuck
## sky**: then a tap on any cloud's cell blows the wind on, whatever lies
## under it. Otherwise a cloud is weather and the tap goes to the plane under
## it -- a cloud may sit on part of a plane's body, and a plane that cannot
## be tapped through its cloud would be a plane that cannot be tapped.
func _target_at(local: Vector2) -> int:
	var cell := _cell_at(local)
	if cell.x < 0:
		return NO_TARGET
	if _state.windy() and _state.stuck() and _state.cloud_at(cell) and hearts > 0:
		return GUST_TARGET
	var i := _state.plane_at(cell)
	return i if i >= 0 else NO_TARGET

## Whether a finger is down on something now.
func _held() -> bool:
	return _press_target != NO_TARGET and _press_up < 0.0

## The finger lands on `target`: a plane starts to sink, a cloud swells.
func _press(target: int) -> void:
	_press_target = target
	_press_down = _now()
	_press_up = -1.0
	_busy_for(Motion.PRESS_TIME + 0.05)
	if target == GUST_TARGET:
		_sky_layer.queue_redraw()
	_refresh()

## The finger lifts or slides off: the plane springs home from wherever the
## press had got to (the launch, if one follows, takes it from there).
func _release_press() -> void:
	if not _held():
		return
	_press_up = _now()
	_busy_for(Motion.RELEASE_TIME + 0.05)
	_refresh()

## No press at all: a new deal, or the hearts running out.
func _clear_press() -> void:
	_press_target = NO_TARGET
	_press_down = AGO
	_press_up = -1.0
	_press_finger = -1

## Whether a crash is still playing out: input, Undo, Hint and Reset wait,
## and the host holds its hint video.
func busy() -> bool:
	return _now() < _busy_until

## The whole game. A free plane goes. A blocked one is refused for free on
## Easy and Medium, and on Hard and Insane it crashes and costs a heart.
##
## **The state goes first and the picture follows.** The plane is out of the
## state on the frame of the tap, which is what makes the freed planes right
## while the flight is still in the air -- the wake is diffed against a
## snapshot taken a line earlier -- and what lets the departing plane be
## drawn from its flight rather than from a board it has already left.
##
## **Launches never wait for one another**: several planes may be in the air
## at once, and a player who taps quickly is playing well rather than
## fighting the board. It is also what lets `tests/_win.gd` clear a whole
## board inside a single frame. **A crash does hold the board** (`busy()`):
## it is a heart going, and the next tap should be read, not queued.
func _tap(i: int) -> void:
	if _state.planes[i]["gone"] or busy() or out_of_hearts or is_done():
		return
	var t := _now()
	# A plane's index, State.CLOUD on a Windy Day sky, or -1 when clear.
	var blocked := _state.blocker(i)
	if blocked != -1:
		if _state.judged:
			_crash_tap(i, blocked, t)
		else:
			_refuse_tap(i, blocked, t)
			_break_streak()
		_refresh()
		return
	var before := _free_set()
	if not _state.launch(i):
		return
	if _hint_lit == i:
		_hint_lit = -1
	_refuse = {}
	_beat.erase(i)
	if _idle_plane == i:
		_idle_plane = -1
	var cells: Array = _state.planes[i]["cells"]
	# Where the wake runs out of, and -- if this was the last plane -- where
	# the solve wave runs out of too. Written before `note_move()`, which is
	# what emits `solved` and calls `_on_solved` on this same frame.
	_solve_from = cells[cells.size() - 1]
	_last_plane = i
	var gag := _pick_gag(i, t)
	_fly_out(i, t, gag)
	_wake(before, _solve_from, t)
	fx.cue("place")
	if _state.windy():
		# The clock ticked: every cloud glides a cell downwind.
		_glide(t)
		fx.cue("drift", 1.0, DRIFT_DB)
	_speak()
	_refresh()
	_on_launched(i, gag)
	# note_move() counts the move and ends the puzzle if that was the last
	# plane; the host raises the win screen after win_delay().
	note_move()
	if _state.windy() and not is_done():
		# The clouds may have closed in. Said once they have settled, so the
		# sound lands on the picture.
		_after(0.0 if Motion.reduce else GLIDE, _check_stuck)

## A tap on a blocked plane on Hard or Insane: **the crash**. Nothing in the
## state changes (`launch()` refused); it is all picture, on one clock. The
## plane rushes up its lane to the blocker (`blocker_cell`), bonks its nose
## (`crash`), crumples, and flutters home (`flutter`); the lane flashes up to
## the blocker, which shivers (a plane) or puffs and swells (a cloud), and a
## heart splits on the pill (`heart_lost`). The board holds every tap, Undo,
## Hint and Reset until it lands. Under reduce motion there is no flight: the
## heart splits and the blocker is ringed.
func _crash_tap(i: int, blocked: int, t: float) -> void:
	var cloud := blocked == State.CLOUD
	var stop := _state.blocker_cell(i)
	var lane: Array[Vector2i] = []
	for c in _state.lane(i):
		lane.append(c)
		if c == stop:
			break
	_lost_ever = true
	_break_streak()
	var had := hearts > 0
	hearts = maxi(0, hearts - 1)
	_split_index = hearts if had else -1
	if hearts <= 0:
		out_of_hearts = true
		_running = false
	_say(tr("PP_CRASH_CLOUD" if cloud else "PP_CRASH"), Face.Expr.WORRIED)
	moved.emit()
	if Motion.reduce:
		_split_at = t
		_busy_until = t + Motion.REDUCED_TIME
		fx.cue("crash")
		fx.cue("heart_lost")
		_ringed = {"cell": stop, "until": t + 0.9}
		_heart_layer.queue_redraw()
		if out_of_hearts:
			_after(0.25, _run_out)
		return
	var adv := maxf(CRASH_MIN, float(lane.size()) - CRASH_INTO)
	var out_t := maxf(CRASH_OUT_MIN, adv / CRASH_SPEED * 1.6)
	var bonk := t + out_t
	var end := bonk + BONK_HOLD + HOME_TIME
	_crash = {"i": i, "at": t, "bonk": bonk, "adv": adv, "end": end, "cloud": cloud}
	_busy_until = end
	_busy_for(end - t + 0.05)
	_refuse = {"cells": lane, "at": bonk - 0.04}
	_split_at = bonk + SPLIT_LAG
	var dir := Vector2(_state.planes[i]["dir"])
	var nose := _centre(stop) - dir * 0.5 * _cell
	if cloud:
		var k := _cloud_index(stop)
		if k >= 0:
			_cloud_poke[k] = bonk
		_puffs.append({"at": bonk, "pos": _centre(stop), "i": -1, "colour": Color.WHITE})
	else:
		_shiver[blocked] = bonk
		_puffs.append({"at": bonk, "pos": nose, "i": -1, "colour": PaperPlane.paper(i)})
	fx.cue("place", 1.0, -4.0)
	var gen := _gen
	_after(out_t, func() -> void:
		fx.cue("crash"))
	_after(out_t + SPLIT_LAG, func() -> void:
		fx.cue("heart_lost")
		_heart_layer.queue_redraw())
	_after(out_t + BONK_HOLD, func() -> void:
		fx.cue("flutter"))
	_after(end - t, func() -> void:
		if gen != _gen:
			return
		moved.emit()
		if out_of_hearts:
			_run_out())

## Which cloud stands on `cell` now, as an index into the state's `clouds`,
## or -1.
func _cloud_index(cell: Vector2i) -> int:
	var now_at: Array[Vector2i] = _state.cloud_cells()
	for k in now_at.size():
		if now_at[k] == cell:
			return k
	return -1

## A tap on a cloud while the sky is stuck: **a gust**. A heart goes and the
## wind blows on a tick without a launch (`State.gust()`), so every cloud
## glides a cell. The last heart can buy a gust: the sky is only lost when it
## is stuck again with none left, or a plane crashes with none left (a
## decision, recorded in the spec's section 8 -- otherwise One more heart on a
## stuck sky would be spent before it could be used).
func _gust() -> void:
	if not _state.windy() or not _state.stuck() or hearts <= 0 or busy() or is_done():
		return
	if not _state.gust():
		return
	var t := _now()
	hearts -= 1
	_split_index = hearts
	_split_at = t
	_lost_ever = true
	_break_streak()
	for k in _state.clouds.size():
		_cloud_poke[k] = t
	_glide(t)
	fx.cue("gust")
	_after(SPLIT_LAG, func() -> void: fx.cue("heart_lost"))
	_say(tr("PP_GUST"), Face.Expr.HAPPY)
	_heart_layer.queue_redraw()
	_stuck_told = -1
	moved.emit()
	_after(0.0 if Motion.reduce else GLIDE, _check_stuck)

## The clouds have settled: if they have closed in, say so -- `stuck` once a
## count, the tip, and the pill breathes (`_pill_breathing`) -- or, with no
## heart left to blow them on, the sky is lost.
func _check_stuck() -> void:
	if is_done() or out_of_hearts or not _state.windy() or not _state.stuck():
		return
	if _stuck_told == _state.count():
		return
	_stuck_told = _state.count()
	fx.cue("stuck")
	_break_streak()
	if hearts <= 0:
		out_of_hearts = true
		_running = false
		_say(tr("PP_TIP_STUCK_OUT"), Face.Expr.WORRIED)
		moved.emit()
		_after(0.35, _run_out)
		return
	_say(tr("PP_TIP_STUCK"), Face.Expr.PUZZLED)
	_heart_layer.queue_redraw()

## Whether the pill is breathing: the clouds have closed in and a heart can
## blow them on.
func _pill_breathing() -> bool:
	return _state.windy() and hearts > 0 and not out_of_hearts and not is_done() \
		and _state.stuck()

## Every plane that can go right now, as a set to diff against.
func _free_set() -> Dictionary:
	var out: Dictionary = {}
	for i in _state.free_planes():
		out[i] = true
	return out

## Puts plane `i` in the air, and books the sparkles for the moment its head
## crosses the edge of the board -- `(lane + 0.5)` cells past the head is the
## edge, and `_ease_inv` says which frame that is. Under reduce-motion a
## launch is an instant removal: no flight, no puff, nothing to retire.
##
## **A plane turns around in the air; it never snaps home first.** `undo()`
## and `reset_board()` put a plane back in the state the instant its flight
## home *begins*, not when it lands -- the board has to be correct before the
## picture is -- so its cells are tappable again while it is still out over
## the edge, and there is deliberately no busy gate to stop that. A fresh
## flight starting at `s = 0` would therefore teleport the plane back to its
## resting cells and only then launch it, which on a Reset wave is a whole
## field of planes jumping. So a launch that finds a flight already in the
## air for that plane **starts at the phase whose eased position is where the
## plane actually is**: the position is `s_end * _ease((t - at) / dur)`, so
## sliding `at` back by `u0 * dur` puts the new flight exactly under the old
## one's last frame and leaves `(1 - u0) * dur` of it to run -- shorter,
## because there is less track left. The turn is continuous in the dots too:
## a cell is covered while the tail is short of it, which both directions
## agree on at the moment of the switch.
##
## The edge's sparkles are skipped when that phase is already past the edge:
## a plane still off the board when it is re-launched never crosses it again.
func _fly_out(i: int, t: float, gag := Gag.NONE) -> void:
	if Motion.reduce:
		return
	var f := _flight(i, gag)
	var at := t
	if _fly.has(i):
		# Turned round in the air: the old flight's shape, so the track under
		# the plane does not move.
		var old: Dictionary = _fly[i]
		f = old.duplicate()
		at = t - _tau_at(f, _flown(i, t))
	f["at"] = at
	f["back"] = false
	_fly[i] = f
	var dur := float(f["dur"])
	_busy_for(at + dur - t)
	var cells: Array = _state.planes[i]["cells"]
	var out := float(_state.lane(i).size()) + 0.5
	var lp: Dictionary = f.get("loop", {})
	var crosses := at + _tau_at(f, out + (float(lp["lp"]) if not lp.is_empty() else 0.0))
	if crosses >= t:
		_puffs.append({
			"at": crosses,
			"pos": _centre(cells[cells.size() - 1])
				+ Vector2(_state.planes[i]["dir"]) * out * _cell,
			"i": i,
		})

## Flies plane `i` home along the same track, `delay` from now: an undo's
## flight, or one of Reset's wave. The state already has it back, so the
## board is correct the instant the button is pressed and only the picture
## is late.
##
## **The same turn as `_fly_out`'s, the other way round**, and for the same
## reason: Undo takes back the last launch, which on a quick finger is still
## in the air, and Reset takes back a whole handful of them. Starting the
## flight home at the far end of the track would throw the plane off the
## board first and only then bring it in. So a plane already in the air turns
## where it is -- `at` slides back by `(1 - u0) * dur`, the backward phase
## whose eased position is the plane's own -- and **it does not wait its turn
## in the wave**: `delay` is dropped for it, because a piece that is already
## moving has nothing to queue for and holding it would be the teleport
## again, one beat later.
func _fly_back(i: int, t: float, delay: float) -> void:
	# The flight has reversed, so any puff still booked for this plane's old
	# outbound crossing is for an edge it is no longer headed toward. Undo
	# during a flight, and Reset's whole wave, both come through here, and
	# both used to leave that puff to fire at an empty edge.
	_forget_puff(i)
	if Motion.reduce:
		return
	var f := _flight(i, Gag.NONE)
	var at := t + delay
	if _fly.has(i):
		# Turned round where it is, on the track it was flying (a loop and
		# all: a plane called back mid-loop flies home back round it).
		var old: Dictionary = _fly[i]
		f = old.duplicate()
		at = t - (float(f["dur"]) - _tau_at(f, _flown(i, t)))
	f["at"] = at
	f["back"] = true
	_fly[i] = f
	_busy_for(at + float(f["dur"]) - t)

## **The board answers the move.** This is Queens' `_settle` with a departure
## in place of a queen's sight: the free planes were snapshotted before the
## launch, they are asked again after it, and every plane that was not free
## and now is beats its wings once, `WAKE_STEP` a king-move step out from the
## departing plane's head. The set is **derived and never stored** -- nothing
## remembers who was freed by what -- so an undo leaves nothing behind to
## clean up, which is the whole reason the shape is worth copying.
func _wake(before: Dictionary, from: Vector2i, t: float) -> void:
	if Motion.reduce:
		return
	for q in _state.free_planes():
		if before.has(q):
			continue
		var cells: Array = _state.planes[q]["cells"]
		var at := t + Motion.stagger(_king(cells[cells.size() - 1], from), WAKE_STEP)
		_beat[q] = at
		_busy_for(at - t + Motion.BUMP_TIME)

## A refused tap, and **nothing is lost by it**: the lane flashes in
## `BAD_TILE` from the dart as far as the plane that is in the way, that
## plane shivers, the tapped one leans the way it wanted to go and settles,
## and the tip card says why. No toast (the flash already is the sentence, and
## a refusal here is frequent by design), no counter, no analytics event, no
## move counted, and no mark left on the board once the band has gone.
func _refuse_tap(i: int, blocked: int, t: float) -> void:
	_say(tr("PP_REFUSE"), Face.Expr.PUZZLED)
	if Motion.reduce:
		return
	var cells: Array[Vector2i] = []
	var stop := _state.blocker_cell(i)
	for c in _state.lane(i):
		cells.append(c)
		if c == stop:
			break
	_refuse = {"cells": cells, "at": t}
	if blocked >= 0:
		_shiver[blocked] = t
	_nudge[i] = t
	_busy_for(maxf(BLOCK_FLASH, Motion.NUDGE_LAG + Motion.NUDGE_TIME))
	fx.cue("refuse")

# --- the sprout's line ---

## What a launch says, which after the first few is nothing at all. The line
## is picked by how many planes have gone rather than by how many are left,
## so it is a lesson running out and not a countdown running down -- see
## `SAID`. The win's own line comes from `_on_solved`, not from here.
func _speak() -> void:
	# Windy Day's tips say what matters there; "any order you like" is the
	# one thing that is not true of it.
	if is_done() or _state.windy():
		return
	var gone: int = _state.planes.size() - _state.left()
	if gone < 1 or gone > SAID.size():
		return
	_say(tr(SAID[gone - 1]), Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal.
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _state.left() < _state.planes.size():
		return
	var tips := _tips()
	_tip_idx = (_tip_idx + 1) % tips.size()
	_say(tr(tips[_tip_idx]), Face.Expr.HAPPY)

## The sprout's own line, rather than Binairo's cycle of broken rules: there
## is no rule a tap can break on this board.
func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func is_solved() -> bool:
	return _state.solved()

## Something has gone, so something can come back. The state keeps the
## launch history itself, and a plane is on the board or it is not, so this
## needs no book of its own.
##
## Never on Windy Day (`undo_allowed`): a plane in the wind never comes back,
## and Undo would turn the timetable into trial and error. Never while a crash
## plays out or once the hearts are gone either.
func can_undo() -> bool:
	return _state.undo_allowed and not is_done() and not out_of_hearts and not busy() \
		and _state.left() < _state.planes.size()

## Calls the last plane back, flying it home along the track it left on.
## Counts no move.
func undo() -> bool:
	if is_done() or not can_undo():
		return false
	var i := _state.undo()
	if i < 0:
		return false
	_undo_ever = true
	_break_streak()
	_clear_gags()
	_hint_lit = -1
	_refuse = {}
	# Nothing to unwind in the wake: who was freed by what was never written
	# down. The one thing that is this plane's own is its beat, and only
	# because a plane mid-beat that is also mid-flight reads as a stutter.
	_beat.erase(i)
	_fly_back(i, _now(), 0.0)
	_say(tr("PP_UNDO"), Face.Expr.HAPPY)
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

func hints_left() -> int:
	return maxi(0, State.hints_for(_state.difficulty) + hints_extra - hints_used)

## Rings a plane that can go and leaves a wash under it until it does. It
## never launches it: **naming a legal move is the whole of the help this
## board can give**, because there is no wrong move to save anyone from. The
## pick is the state's -- the generator's own order while the player is still
## on it, any free plane once they are not.
func hint() -> bool:
	if is_done() or out_of_hearts or busy() or hints_left() <= 0:
		return false
	var i: int = _state.hint_plane()
	if i < 0:
		return false
	hints_used += 1
	_hint_lit = i
	var cells: Array = _state.planes[i]["cells"]
	fx.ring(_centre(cells[cells.size() - 1]), _cell * RING_R, Pal.LEAF)
	# It beats its wings once, out of the wake's own book: the hint names a
	# plane that can go, and that is exactly what a beat means here.
	if not Motion.reduce:
		_beat[i] = _now()
	_busy_for(Motion.RING_TIME)
	fx.cue("hint")
	_say(tr("PP_HINT"), Face.Expr.HAPPY)
	_refresh()
	moved.emit()
	check_solved()
	return true

## Whether Reset can do anything now: the top bar greys it while a crash
## plays out and once the hearts are gone (Try again is the way back then),
## so the host never logs a board_reset that did nothing.
func can_reset() -> bool:
	return not (is_done() or out_of_hearts or busy())

## Every plane back on the field, and on Windy Day the clock back to the
## deal's (the clouds blow back to where the day began). What a hint gave
## stays given: the hints spent are not refunded, only unpinned. The hearts
## stay as they are: only Try again gives those back.
func reset_board() -> void:
	if not can_reset():
		return
	_release_press()
	_break_streak()
	_clear_gags()
	_fly_all_home()
	_hint_lit = -1
	_refuse = {}
	_solved_at = -1.0
	moves = 0
	_running = true
	_say(tr("PP_RESET"), Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()
	moved.emit()

## Every launched plane flies home in the family's reset wave and the state
## goes back to the deal, clock and all; the clouds glide back with it.
func _fly_all_home() -> void:
	var t := _now()
	var k0 := _cloud_k(t)
	var far := Vector2i(_state.cols - 1, _state.rows - 1)
	# Pulled back one at a time rather than with `reset()`, because each one
	# needs a flight home of its own and the state's `undo()` is the only
	# thing that knows what went and in what order. `reset()` afterwards is a
	# no-op that keeps this honest if the history and the board ever part.
	while true:
		var i := _state.undo()
		if i < 0:
			break
		_beat.erase(i)
		var cells: Array = _state.planes[i]["cells"]
		# The family's reset wave, from the far corner (rule 4's cap and all).
		_fly_back(i, t, Motion.stagger(
			_king(cells[cells.size() - 1], far), Motion.RESET_STAGGER))
	_state.reset()
	_stuck_told = -1
	if _state.windy():
		_glide(t, k0)

## A completed daily is rebuilt from its seed, so it reopens with a full sky.
## Launch every plane in the state's own solve order and settle the picture
## at once: no flight, no wake, no puff, no entrance and no solve wave left
## to run -- the empty lattice a finished board shows once its wave has gone.
## Never `check_solved()`: the host owns the win for an already-completed
## daily and `solved` must not fire a second time.
##
## The hearts it kept come back from the record (the pill shows them), and
## whether it was flawless; the party's leavings stand where it left them
## (the cat asleep, the seal, a Windy Day sky clear of clouds).
func restore_completed_board() -> void:
	var t := _now()
	_gen += 1
	_close_card()
	for i in _state.solve_order():
		_state.launch(i)
	# Clears the launch history (every cell is already empty), so nothing is
	# left for an undo to call back.
	_state.clear_occupancy()
	_forget()
	_deal()
	_reset_rewards()
	hearts = clampi(int(completed_record.get("hearts", max_hearts)), 0, max_hearts)
	_flawless = bool(completed_record.get("flawless", false))
	# The party's leavings and none of its motion: the cat asleep on the
	# panel's foot, the seal when the solve earned one, and on Windy Day the
	# clouds long gone off with the wind.
	_cat_at = t - 100.0
	_place_cat(t)
	if _flawless or _state.windy():
		_stamp_at = t - 100.0
	if _state.windy():
		_clouds_at = t - 100.0
	_life_layer.queue_redraw()
	_idle_next = FAR
	_hint_lit = -1
	_solved_at = -1.0
	_anim_until = 0.0
	_opened = t - 10.0
	_tip_timer.stop()
	_say(tr("PP_WIN"), Face.Expr.JOY)
	_heart_layer.queue_redraw()
	_sky_layer.queue_redraw()
	_refresh()

## What a reopened daily needs to look as it was left: the hearts kept and
## whether it was flawless. Plain values only (it goes through a ConfigFile).
func completion_record() -> Dictionary:
	return {"hearts": hearts, "flawless": _flawless}

## No glyphs of its own (a sky of planes says nothing about how it was
## played), only the seal's words: `🌬️ Windy Day` for any Insane sky (and
## ` · Flawless` when it was), `🏅 Flawless` otherwise.
func share_glyphs() -> String:
	if _state.windy() and is_solved():
		return "🌬️ " + tr("PP_WINDY_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	if _flawless:
		return "🏅 " + tr("BN_FLAWLESS")
	return ""

# --- the win ---

## No cast and a subtitle, so the win screen keeps the family's sun and moon.
## The host's `faces` are Controls out of `ui/faces/` and **this board has
## none** (spec section 9): a dart drawn up there would be a new Control for
## one screen's sake, which is exactly the bargain that section declines.
## Nonogram, Word Trail and Sudoku all answer this way for the same reason.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("PP_WIN")}

## How long the host holds the win screen back. See `WIN_WAIT` for the
## arithmetic; under reduce-motion there is neither a flight nor a wave to
## wait for, so the win follows the last tap (spec section 10's
## reduce-motion row).
##
## The party comes after the last flight lands (`_party_at`) and takes
## PARTY_TIME: the flock, the straggler batted, the cat curled up.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	var party := (_party_at - _now()) if _party_at < INF else _flight_left(_now()) + PARTY_AT
	return maxf(WIN_WAIT, maxf(0.0, party) + PARTY_TIME)

## **The wave waits for the plane that won the board.** The last launch is
## still in the air when `note_move()` ends the puzzle -- the state let it go
## on the tap -- and a field hopping under a plane that has not left yet is
## two hands at once, which is Word Trail's lesson at its own solve. So the
## wave is booked for the second the last flight lands, and rolls out from
## `_solve_from`, the cell that plane's head stood on: the sky empties from
## the place the last plane left it.
##
## Nothing here is a book, because nothing here needs retiring one entry at
## a time: the wave is one second (`_solved_at`) and one origin, read by
## every dot in `_hop`, and `_retire` drops it when it has run.
func _on_solved() -> void:
	var t := _now()
	_tip_timer.stop()
	_hint_lit = -1
	_refuse = {}
	_idle_plane = -1
	_idle_next = FAR
	_say(tr("PP_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_heart_layer.queue_redraw()
	_refresh()
	# Flawless: no hint, and no crash or gust on a judged sky, or on Easy and
	# Medium never an undo (spec section 4; the seal is the rewards pass's).
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 else not _undo_ever)
	# The streak's bubble goes; the party takes over.
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = t
	_streak_gen += 1
	_party()
	if Motion.reduce:
		return
	_solved_at = t + _flight_left(t)
	_busy_for(_solved_at - t + _wave_span())

## How much of the longest flight still in the air is left to run. Zero on a
## quiet board, and zero under reduce-motion, where a launch is an instant
## removal and `_fly` is never written.
func _flight_left(t: float) -> float:
	var left := 0.0
	for i in _fly:
		var f: Dictionary = _fly[i]
		left = maxf(left, float(f["at"]) + float(f["dur"]) - t)
	return maxf(0.0, left)

# --- the idle flutter (polish section 5) ---

## Every few seconds, on a quiet board, one resting plane lifts a wing tip a
## hair. Only that plane leaves the still mesh, for IDLE_TIME. Never under
## reduce motion, never while anything else moves, never once done or dark.
func _idle_tick(t: float) -> void:
	if _idle_plane >= 0 or t < _idle_next:
		return
	var h: int = absi(hash(Vector2i(int(t * 10.0), _state.planes.size())))
	_idle_next = t + IDLE_EVERY * (0.67 + float(h % 67) / 100.0)
	if Motion.reduce or is_done() or out_of_hearts or busy() or _animating(t):
		return
	var resting: Array[int] = []
	for i in _state.planes.size():
		if not _state.planes[i]["gone"] and not _fly.has(i):
			resting.append(i)
	if resting.is_empty():
		return
	_idle_plane = resting[(h >> 4) % resting.size()]
	_idle_at = t
	_refresh()

# --- Windy Day's sky (polish section 3) ---

## The clock ticked (a launch, a gust, a Reset or a Try again): the clouds
## glide from wherever they are drawn now to the state's count. One cell takes
## GLIDE; a Reset's long way back takes longer, up to GLIDE_BACK_MAX. Under
## reduce motion they jump.
func _glide(t: float, from := NAN) -> void:
	if is_nan(from):
		from = _cloud_k(t)
	var to := float(_state.count())
	_glide_from = to if Motion.reduce else from
	_glide_to = to
	_glide_at = t
	_glide_dur = clampf(GLIDE + 0.04 * (absf(to - from) - 1.0), GLIDE, GLIDE_BACK_MAX)
	_sky_layer.queue_redraw()

## The count the clouds are drawn at: continuous, gliding on a sine in-out.
## It reads the glide's own end and not the state's count, so a glide asked
## for after the state has already ticked still starts where the clouds were.
func _cloud_k(t: float) -> float:
	var u := clampf((t - _glide_at) / maxf(_glide_dur, 0.001), 0.0, 1.0)
	if Motion.reduce or u >= 1.0:
		return _glide_to
	return lerpf(_glide_from, _glide_to, 0.5 - 0.5 * cos(u * PI))

## The sky layer: the ghosts of where the clouds will be after the next
## launch (one mesh, rebuilt when the count moves), every cloud (one cached
## mesh under a transform each; a cloud sliding off one edge is drawn twice,
## fading out there and in at the other), and the wind sock swaying.
func _draw_sky() -> void:
	if not _state.windy() or _cell <= 0.0 or _state.planes.is_empty():
		return
	var t := _now()
	var seen := Motion.appear_level(t - _opened - Motion.ENTER_DELAY - 0.15, 0.3)
	if seen <= 0.0:
		return
	var settled := Motion.reduce or t >= _glide_at + _glide_dur
	if settled and not is_done() and not out_of_hearts:
		if _ghost == null or _ghost_count != _state.count():
			_ghost = _build_ghost()
			_ghost_count = _state.count()
		if _ghost != null:
			_sky_layer.draw_mesh(_ghost, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, seen))
		_ghost_shown = _ghost
	if _cloud_mesh == null:
		_cloud_mesh = _build_cloud()
	var k := _cloud_k(t)
	if t >= _clouds_at:
		_draw_send_off(t, k, seen)
	else:
		_draw_clouds(t, k, seen)
	_draw_sock(t, seen)

## Every cloud where the count `k` puts it, a cloud sliding off one edge drawn
## twice (out there, in at the other), each bumping when poked.
func _draw_clouds(t: float, k: float, seen: float) -> void:
	var cols := float(_state.cols)
	var pressed := Motion.press_scale(t - _press_down, (t - _press_up) if _press_up >= 0.0 else -1.0) \
		if _press_target == GUST_TARGET else 1.0
	for j in _state.clouds.size():
		var c: Vector2i = _state.clouds[j]
		var x := fposmod(float(c.x) + float(_state.wind.x) * k, cols)
		var bump := 1.0 + (Motion.bump_scale(t - float(_cloud_poke.get(j, AGO)), CLOUD_POKE) - 1.0)
		# A slow bob of its own, a pixel or two, so the sky is never stone.
		var bob := 0.0 if Motion.reduce else sin(t * 1.3 + float(j) * 1.7) * 0.025 * _cell
		for twin in [0.0, -cols, cols]:
			var cx: float = x + twin
			var out := maxf(0.0, maxf(-cx, cx - (cols - 1.0)))
			if out >= 1.0:
				continue
			var at := _origin + (Vector2(cx, float(c.y)) + Vector2.ONE * 0.5) * _cell + Vector2(0.0, bob)
			var sc := bump * pressed
			_sky_layer.draw_mesh(_cloud_mesh, null, Transform2D(0.0, Vector2(sc, sc), 0.0, at),
				Color(1.0, 1.0, 1.0, CLOUD_ALPHA * seen * (1.0 - out)))

## Windy Day's send-off after the last flight: every cloud turns gold and
## smiles (the white one fading under the gold one), then from CLOUDS_GO
## drifts off downwind and up, fading out by CLOUDS_GONE. Under reduce
## motion, and once it has run, there is nothing left to draw.
func _draw_send_off(t: float, k: float, seen: float) -> void:
	var e := t - _clouds_at
	if Motion.reduce or e >= CLOUDS_GONE:
		return
	if _gold_cloud == null:
		_gold_cloud = _build_cloud(true)
	var gold := clampf(e / GOLD_TIME, 0.0, 1.0)
	var go := maxf(0.0, e - CLOUDS_GO)
	var fade := 1.0 - clampf((e - CLOUDS_GO) / (CLOUDS_GONE - CLOUDS_GO), 0.0, 1.0)
	var cols := float(_state.cols)
	for j in _state.clouds.size():
		var c: Vector2i = _state.clouds[j]
		var x := fposmod(float(c.x) + float(_state.wind.x) * k, cols)
		# Each sets off a moment after the last, away downwind and up.
		var mine := maxf(0.0, go - float(j) * 0.05)
		var drift := Vector2(float(_state.wind.x) * (2.2 * mine + 5.0 * mine * mine), -1.4 * mine)
		var bob := sin(t * 3.0 + float(j) * 1.7) * 0.04 * _cell
		var at := _origin + (Vector2(x, float(c.y)) + Vector2.ONE * 0.5 + drift) * _cell + Vector2(0.0, bob)
		var sc := 1.0 + 0.12 * sin(gold * PI)
		var xf := Transform2D(0.0, Vector2(sc, sc), 0.0, at)
		var a := seen * fade
		if gold < 1.0:
			_sky_layer.draw_mesh(_cloud_mesh, null, xf, Color(1.0, 1.0, 1.0, CLOUD_ALPHA * a * (1.0 - gold)))
		_sky_layer.draw_mesh(_gold_cloud, null, xf, Color(1.0, 1.0, 1.0, a * gold))

## The wind sock swaying on its pole.
func _draw_sock(t: float, seen: float) -> void:
	if _sock_mesh == null:
		_sock_mesh = _build_sock()
	var sway := 0.0 if Motion.reduce else sin(t * TAU / SOCK_PERIOD) * SOCK_SWAY \
		+ sin(t * TAU / SOCK_PERIOD * 2.7) * SOCK_SWAY * 0.3
	var flip := Vector2(1.0 if _state.wind.x >= 0 else -1.0, 1.0)
	_sky_layer.draw_mesh(_sock_mesh, null,
		Transform2D(sway * flip.x, flip, 0.0, _sock_root()), Color(1.0, 1.0, 1.0, seen))

## One cloud, centred on the origin, a little wider than its cell so two
## neighbours merge into one big cloud: a few overlapping puffs taken as one
## outline (the union, traced round from the middle), so the soft alpha it is
## drawn at never shows a seam between them. A cool underside, the white
## body, and a brighter cap.
##
## The party's gold cloud is the same shape in sun colours, with a happy
## face: two closed eyes, a smile and rosy cheeks.
func _build_cloud(gold := false) -> ArrayMesh:
	var c := _cell
	var puffs := [[Vector2(-0.36, 0.08), 0.26], [Vector2(-0.12, -0.12), 0.33],
		[Vector2(0.2, -0.07), 0.3], [Vector2(0.42, 0.1), 0.22], [Vector2(0.02, 0.13), 0.3]]
	var b := Face.Builder.new()
	var under: Color = Pal.SUN_DEEP if gold else Pal.CLOUD_DEEP
	var body: Color = Pal.SUN if gold else Pal.CLOUD_TILE.lerp(Pal.CLOUD, 0.3)
	var top: Color = Pal.SUN_RAY if gold else Color("fbfcfe")
	b.polygon(_union(puffs, c, Vector2(0.0, 0.08 * c), 1.0), Color(under, 0.3))
	b.polygon(_union(puffs, c, Vector2.ZERO, 1.0), body)
	b.polygon(_union(puffs, c, Vector2(0.0, -0.05 * c), 0.9), top)
	var cap := [[Vector2(-0.14, -0.15), 0.2], [Vector2(0.14, -0.1), 0.17]]
	b.polygon(_union(cap, c, Vector2(-0.02 * c, -0.07 * c), 1.0),
		Pal.SUN_SPARK if gold else Color(1.0, 1.0, 1.0))
	if gold:
		var w := maxf(1.6, 0.035 * c)
		for sx in [-1.0, 1.0]:
			b.stroke(Face.Builder.arc_points(Vector2(sx * 0.15, 0.02) * c, 0.065 * c, PI * 1.15, PI * 1.85),
				w, Pal.OUTLINE)
			b.ellipse(Vector2(sx * 0.27, 0.12) * c, 0.07 * c, 0.045 * c, Color(Pal.CHEEK, 0.75))
		b.stroke(Face.Builder.arc_points(Vector2(0.0, 0.06) * c, 0.09 * c, PI * 0.15, PI * 0.85),
			w, Pal.OUTLINE)
	return b.mesh()

## The outline of a union of discs ({centre, radius} in cells), traced round
## from the origin: for every heading the farthest point any disc reaches.
## Fine for a cloud, whose puffs all reach back over its middle.
static func _union(puffs: Array, cell: float, shift: Vector2, grow: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	const N := 56
	for a in N:
		var d := Vector2.from_angle(TAU * float(a) / float(N))
		var far := 0.0
		for p in puffs:
			var ctr: Vector2 = p[0] * grow
			var r: float = float(p[1]) * grow
			var along := d.dot(ctr)
			var disc := r * r - ctr.length_squared() + along * along
			if disc >= 0.0:
				far = maxf(far, along + sqrt(disc))
		pts.append(d * far * cell + shift)
	return pts

## The dotted ghosts of where every cloud will stand after the next launch:
## a ring of dots round each such cell, faint, in the clouds' cool ink.
func _build_ghost() -> ArrayMesh:
	var b := Face.Builder.new()
	var next: Array[Vector2i] = _state.cloud_cells(_state.count() + 1)
	var r := 0.4 * _cell
	var dot := maxf(1.6, 0.035 * _cell)
	for cell in next:
		var at := _centre(cell)
		const N := 14
		for a in N:
			b.disc(at + Vector2.from_angle(TAU * float(a) / float(N)) * Vector2(r * 1.15, r * 0.9),
				dot, Color(Pal.CLOUD_DEEP, GHOST_ALPHA))
	return b.mesh() if not b.verts.is_empty() else null

## The wind sock, streaming along +x from its pole top at the origin: a
## tapered sleeve in coral and cream bands, sagging a little toward its tip,
## with a darker hoop at the mouth. The board flips it for a west wind.
func _build_sock() -> ArrayMesh:
	var L := _sock_px()
	var h0 := L * 0.2
	var h1 := L * 0.08
	var b := Face.Builder.new()
	const BANDS := 4
	for k in BANDS:
		var u0 := float(k) / BANDS
		var u1 := float(k + 1) / BANDS
		var x0 := L * (0.06 + 0.94 * u0)
		var x1 := L * (0.06 + 0.94 * u1)
		var y0 := L * 0.12 * u0 * u0
		var y1 := L * 0.12 * u1 * u1
		var w0 := lerpf(h0, h1, u0)
		var w1 := lerpf(h0, h1, u1)
		var colour := Pal.BERRY.lerp(Pal.CHEEK, 0.25) if k % 2 == 0 else Pal.SURFACE
		b.polygon(PackedVector2Array([Vector2(x0, y0 - w0), Vector2(x1, y1 - w1),
			Vector2(x1, y1 + w1), Vector2(x0, y0 + w0)]), colour)
		# The shaded underside of each band.
		b.polygon(PackedVector2Array([Vector2(x0, y0 + w0 * 0.35), Vector2(x1, y1 + w1 * 0.35),
			Vector2(x1, y1 + w1), Vector2(x0, y0 + w0)]), Color(Pal.TEXT, 0.08))
	b.ellipse(Vector2(L * 0.06, 0.0), L * 0.035, h0 * 1.05, Pal.BERRY.lerp(Pal.TEXT, 0.25))
	b.stroke(PackedVector2Array([Vector2.ZERO, Vector2(L * 0.06, 0.0)]), L * 0.03, Pal.WOOD_DEEP)
	return b.mesh()

# --- the hearts (polish section 1) ---

## The hearts over the panel as one mesh on a paper pill (Quilt's and Fairy
## Lights'): pink with a small face and a leaf, a faint ghost where one was,
## the lost one's halves falling apart, one coming back popping in, and the
## whole pill breathing while the clouds have closed in.
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
	if enter <= 0.0:
		return
	if _pill_breathing() and not Motion.reduce:
		enter *= 1.0 + PILL_PULSE * (0.5 - 0.5 * cos(now * TAU / PILL_BREATH))
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

## A heart's small face: two dots and a smile in ink, a shine at the top
## left, and a leaf on top (Mushroom Patch's).
static func _heart_face(b, at: Vector2, s: float) -> void:
	b.ellipse(at + Vector2(-0.5, -0.5) * s, 0.16 * s, 0.1 * s, Color(1.0, 1.0, 1.0, 0.45))
	for sx in [-1.0, 1.0]:
		b.disc(at + Vector2(sx * 0.28, -0.12) * s, 0.09 * s, Pal.OUTLINE)
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, 0.02) * s, 0.16 * s, PI * 0.2, PI * 0.8), 0.07 * s, Pal.OUTLINE)
	b.ellipse(at + Vector2(0.25, -0.76) * s, 0.24 * s, 0.11 * s, Pal.LEAF)

## A heart `s` half-wide about `at` (side 0), or its left (-1) or right (1)
## half, split along a zigzag crack so the two halves fit together
## (Binairo's, by way of Mushroom Patch and Fairy Lights).
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

## The last heart is gone: the planes left droop, dusk falls on the card
## (`out_of_hearts`), and the out-of-hearts card comes up.
func _run_out() -> void:
	if _asleep or not out_of_hearts:
		return
	_asleep = true
	_clear_press()
	_break_streak()
	_tip_timer.stop()
	_idle_plane = -1
	fx.cue("out_of_hearts")
	_say(tr("PP_OUT"), Face.Expr.SLEEPY)
	_droop_at = _now()
	_busy_for(DROOP_TIME + 0.05)
	_dusk_toward(DUSK)
	_refresh_all()
	_sky_layer.queue_redraw()
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
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["PP_OUT_BODY", "PP_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same sky back in Reset's wave, the clouds blown back to
## the deal, every heart back, the clock and the moves from zero. Hints spent
## stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	_gen += 1
	_forget()
	_break_streak()
	_clear_gags()
	# Dealt first, so the planes' flights home and the clouds' glide back
	# (both in _fly_all_home) are not wiped by it.
	_deal()
	_fly_all_home()
	_hint_lit = -1
	_solved_at = -1.0
	elapsed = 0.0
	moves = 0
	_running = true
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	_refresh_all()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	moved.emit()

## One more heart (the card's video): once a sky. The planes perk up and the
## day comes back; on a stuck Windy Day sky the heart is there to blow the
## wind on.
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
	_droop_at = FAR
	_stuck_told = -1
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	_refresh_all()
	_heart_layer.queue_redraw()
	_sky_layer.queue_redraw()
	_say(tr("PP_HEART_BACK"), Face.Expr.HAPPY)
	_tip_timer.start()
	moved.emit()
	if _state.windy() and _state.stuck():
		_after(0.3, _check_stuck)

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

# --- the rewards (polish section 4) ---

## Every reward's clock back to nothing: a new board, or a restored one.
func _reset_rewards() -> void:
	_streak = 0
	_streak_gen += 1
	_gag_until = 0.0
	_gag_gen += 1
	_combo_n = 0
	_combo_at = -INF
	_combo_out_at = -INF
	_love = []
	_birds = []
	_party_at = INF
	_stamp_at = INF
	_seal_mesh = null
	_cat_at = INF
	_cat_curled = false
	_clouds_at = INF
	_flock = []
	if is_instance_valid(_cat):
		_cat.queue_free()
	_cat = null
	if _life_layer != null:
		_life_layer.queue_redraw()
	if _sky_layer != null:
		_sky_layer.queue_redraw()

## The day's own number: the sky's size and its first plane, so a day always
## deals the same gags and the same bit of wisdom.
func _day_hash() -> int:
	if _state.planes.is_empty():
		return 0
	return absi(hash([_state.cols, _state.rows, _state.planes.size(), _state.planes[0]["cells"]]))

## Which gag plane `i`'s launch plays, if any: one plane in GAG_ODDS, the kind
## its own -- the day picks where the cycle starts and each plane steps
## GAG_STEP along it, so any GAG_SPAN planes share the four gags evenly
## (Quilt's rule; a plain hash a plane clumps). One at a time, never under
## reduce motion, never on the winning launch (its party is coming), and
## never on a plane turned round in the air (its flight already has a shape).
func _pick_gag(i: int, t: float) -> int:
	if Motion.reduce or _state.solved() or _fly.has(i) or t < _gag_until or force_gag == Gag.NONE:
		return Gag.NONE
	var roll := posmod(_day_hash() + i * GAG_STEP, GAG_SPAN)
	if force_gag >= 0:
		roll = force_gag
	elif roll >= GAG_SPAN / GAG_ODDS:
		return Gag.NONE
	# A roll needs sky to turn over in: on a plane at the edge it would turn
	# out past the hem, so it loops instead (the loop sits on its own head).
	if roll == Gag.ROLL and _state.lane(i).size() < 2:
		return Gag.LOOP
	return roll

## Plane `i` has just launched (not refused, not crashed), before
## note_move(), with the gag its flight was shaped for. The streak: a note
## up the pentatonic from the second, the bubble over the launch spot from
## the third, confetti at 5, 10, 20 and every 10 after. The last few planes
## are counted down. The winning launch does none of it: the party is coming
## (Mushroom Patch's review found a combo landing over the party).
func _on_launched(i: int, gag: int) -> void:
	if _state.solved():
		return
	var cells: Array = _state.planes[i]["cells"]
	var head := _centre(cells[cells.size() - 1])
	_streak += 1
	var count := _streak
	var gen := _streak_gen
	if count >= 2:
		var step: int = COMBO_STEPS[mini(count - 2, COMBO_STEPS.size() - 1)]
		_after(0.06, func() -> void:
			if gen == _streak_gen:
				fx.cue("combo", pow(2.0, step / 12.0), COMBO_DB))
	if count >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = count
		_combo_pos = head - Vector2(0.0, _cell * 0.3)
		_combo_at = _now()
		_combo_out_at = -INF
	if _confetti_at(count) and not Motion.reduce:
		fx.confetti(head, 22)
		fx.cue("confetti")
	var left := _state.left()
	if left <= LAST_FEW:
		_say(tr("PP_LAST_%d" % left), Face.Expr.JOY)
	_start_gag(i, gag)
	_life_layer.queue_redraw()

## The streak's confetti counts: 5, 10, 20 and every 10 after.
static func _confetti_at(count: int) -> bool:
	return count == 5 or count == 10 or (count >= 20 and count % 10 == 0)

## The streak ends: a refusal, a crash, an undo, a reset, a gust, the clouds
## closing in, the hearts running out. The bubble deflates, and a note the
## streak still had to play is dropped.
func _break_streak() -> void:
	_streak = 0
	_streak_gen += 1
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
	else:
		_combo_n = 0
	if _life_layer != null:
		_life_layer.queue_redraw()

## What a launch set going that an undo or a reset takes back with it: a bird
## after a plane coming home, hearts in a contrail it no longer leaves. A
## loop or a roll is the flight's own shape and turns round with it.
func _clear_gags() -> void:
	_love = []
	_birds = []
	_gag_until = 0.0
	_gag_gen += 1
	if _life_layer != null:
		_life_layer.queue_redraw()

## Plane `i`'s gag, its flight already shaped for it (`_flight`): the loop's
## `loop` as the head enters it, the roll's `whoosh`, the bird popping up
## beside it (`tweet`), or hearts left along its contrail (`love`). The next
## gag waits for this one to finish.
func _start_gag(i: int, gag: int) -> void:
	if gag == Gag.NONE or not _fly.has(i):
		return
	var f: Dictionary = _fly[i]
	var now := _now()
	var at := float(f["at"])
	var gg := _gag_gen
	match gag:
		Gag.LOOP:
			var lp: Dictionary = f["loop"]
			_after(maxf(0.0, at + _tau_at(f, float(lp["e0"])) - now), func() -> void:
				if gg == _gag_gen:
					fx.cue("loop"))
			_gag_until = at + float(f["dur"])
		Gag.ROLL:
			fx.cue("whoosh")
			_gag_until = at + float(f["dur"])
		Gag.BIRD:
			var cells: Array = _state.planes[i]["cells"]
			var n := cells.size()
			var dir := Vector2(_state.planes[i]["dir"])
			var side := dir.orthogonal()
			var mid := _origin + Vector2(float(_state.cols), float(_state.rows)) * _cell * 0.5
			if (mid - _centre(cells[n - 1])).dot(side) < 0.0:
				side = -side
			# It follows the plane's own trail from the tail, through every
			# bend, to where the sky ends -- on the card whatever the lane.
			var stop := float(n - 1) + maxf(0.0, float(_state.lane(i).size()) - 0.1)
			var chase := stop / BIRD_SPEED + BIRD_POP
			var bird := {"i": i, "t": now, "side": side, "stop": stop,
				"chase": chase, "end": chase + BIRD_HOVER + BIRD_LEAVE}
			_birds.append(bird)
			_after(0.08, func() -> void:
				if gg == _gag_gen:
					fx.cue("tweet"))
			_gag_until = now + float(bird["end"])
		Gag.LOVE:
			var cells: Array = _state.planes[i]["cells"]
			var n := cells.size()
			var dir := Vector2(_state.planes[i]["dir"])
			# Along the trail it leaves (its own body, then the lane), each
			# popping as the tail passes -- on the card whatever the lane.
			var room := float(n - 1) + float(_state.lane(i).size()) + 0.3
			var count := clampi(int(room / LOVE_GAP), 2, LOVE_HEARTS)
			var gap := room / float(count)
			var last := now
			for k in count:
				var x := gap * (float(k) + 0.5)
				var when := at + _tau_at(f, clampf(x, 0.0, float(f["s_end"])))
				var wob := dir.orthogonal() * _cell * 0.16 * (1.0 if k % 2 == 0 else -1.0)
				_love.append({"at": _track(i, x) + wob, "t": when,
					"phase": float(posmod(hash([i, k]), 100)) / 100.0 * TAU})
				last = maxf(last, when)
			fx.cue("love")
			_gag_until = last + LOVE_TIME * 0.5

# --- the party ---

## After the last flight: the sprout shares a bit of paper plane wisdom,
## confetti twice, the planes that flew come back as a flock in a V and loop
## out, one straggler skims the panel's foot, the nap cat hops on, bats at it
## and curls up, the seal stamps when the solve earned one (flawless, or any
## Windy Day), and on Windy Day the clouds turn gold, smile and drift away.
## Under reduce motion the cat and the seal are simply there and the clouds
## simply gone.
func _party() -> void:
	var now := _now()
	var lead := 0.0 if Motion.reduce else _flight_left(now) + PARTY_AT
	_party_at = now + lead
	_after(lead, func() -> void:
		_say(_cheer(), Face.Expr.JOY))
	_cat_at = now if Motion.reduce else _party_at + CAT_AT
	if _flawless or _state.windy():
		_stamp_at = now if Motion.reduce else _party_at + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
	if _state.windy():
		_clouds_at = _party_at
		if not Motion.reduce:
			_after(lead, fx.cue.bind("clouds"))
		_sky_layer.queue_redraw()
	if Motion.reduce:
		_life_layer.queue_redraw()
		return
	_flock = []
	var n := mini(FLOCK_MAX, _state.planes.size())
	for k in n:
		_flock.append(posmod(_last_plane - k, _state.planes.size()))
	var field := Rect2(_origin, Vector2(float(_state.cols), float(_state.rows)) * _cell)
	_after(lead + 0.15, func() -> void:
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell * 0.6), 30, field.size.x * 0.9)
		fx.cue("party"))
	_after(lead + 0.6, func() -> void:
		fx.confetti(field.get_center(), 24, field.size.x * 0.7))
	_after(lead + FLOCK_AT, fx.cue.bind("flock"))
	_after(lead + BAT_AT, fx.cue.bind("whoosh", 1.2, -6.0))
	_life_layer.queue_redraw()

## One of CHEERS silly bits of paper plane wisdom, picked by the sky itself,
## so a day always gets the same one.
func _cheer() -> String:
	return tr("PP_CHEER_%d" % posmod(_day_hash(), CHEERS))

## The flock's leader's path, `dist` pixels along it, as [where, heading,
## how far round the loop, 0 to 1]: in from the left low, across and up to a
## loop of FLOCK_LOOP of the card's width round, and on out to the right.
func _flock_path(dist: float) -> Array:
	var W := size.x
	var H := size.y
	var S := Vector2(-0.12 * W, 0.66 * H)
	var P := Vector2(0.56 * W, 0.46 * H)
	var d := (P - S).normalized()
	var up := d.orthogonal()
	var R := FLOCK_LOOP * W
	var la := S.distance_to(P)
	var lc := TAU * R
	if dist < la:
		return [S + d * dist, d, 0.0]
	if dist < la + lc:
		var th := (dist - la) / R
		return [P + up * R + (d * sin(th) - up * cos(th)) * R, d * cos(th) + up * sin(th), th / TAU]
	return [P + d * (dist - la - lc), d, 0.0]

## How long the flock takes, from FLOCK_AT, until its last row is off the
## card.
func _flock_time() -> float:
	var W := size.x
	var H := size.y
	var S := Vector2(-0.12 * W, 0.66 * H)
	var P := Vector2(0.56 * W, 0.46 * H)
	var d := (P - S).normalized()
	var out := (1.15 * W - P.x) / maxf(d.x, 0.1)
	var rows := (FLOCK_MAX + 1) / 2
	return (S.distance_to(P) + TAU * FLOCK_LOOP * W + out) / FLOCK_SPEED + rows * FLOCK_LAG

## The darts of the party, one mesh a paper (three), each about its own head
## and pointing along +x, with no shadow (they turn over in the loop).
func _flock_mesh(i: int) -> ArrayMesh:
	if _flock_meshes.size() < 3:
		_flock_meshes = []
		for c in 3:
			var b := Face.Builder.new()
			PaperPlane.dart(b, Vector2.ZERO, 0.0, FLOCK_PX, c, 1.0, Vector2.ONE, 1.0, 0.0, false)
			_flock_meshes.append(b.mesh())
	return _flock_meshes[posmod(i, 3)]

## The flock: the leader on the path, each row FLOCK_LAG behind it and
## FLOCK_SPREAD further out to either side, so the V holds its shape round the
## loop. Their wings shimmer a little.
func _draw_flock(now: float, shown: Array) -> void:
	var tau := now - _party_at - FLOCK_AT
	if tau < 0.0 or tau > _flock_time() or _flock.is_empty():
		return
	for k in _flock.size():
		var row := (k + 1) / 2
		var side := 0.0 if k == 0 else (1.0 if k % 2 == 1 else -1.0)
		var dist := FLOCK_SPEED * (tau - float(row) * FLOCK_LAG)
		var at: Array = _flock_path(dist)
		var heading: Vector2 = at[1]
		# The V closes up round the loop, so its inner wing never crosses
		# the middle of it.
		var close := 1.0 - 0.6 * sin(PI * float(at[2]))
		var pos: Vector2 = at[0] + heading.orthogonal() * side * float(row) * FLOCK_SPREAD * close
		if pos.x < -FLOCK_PX or pos.x > size.x + FLOCK_PX:
			continue
		var mesh := _flock_mesh(_flock[k])
		shown.append(mesh)
		var flap := 1.0 + 0.1 * sin(now * 14.0 + float(k) * 1.3)
		_life_layer.draw_mesh(mesh, null, Transform2D(heading.angle(), Vector2(1.0, flap), 0.0, pos))

## The straggler, the last plane to have flown: it skims in low along the
## panel's foot, wobbling, just over the cat's head; she bats at it and it
## tumbles up and away to the right.
func _draw_straggler(now: float, shown: Array) -> void:
	if not is_instance_valid(_cat):
		return
	var spot := _cat_spot()
	var y0 := spot.y - _cat_px() * 0.62
	var bat := _party_at + BAT_AT
	var from := -FLOCK_PX
	var start := bat - (spot.x - from) / STRAGGLE_SPEED
	var e := now - start
	if e < 0.0 or e > 3.0:
		return
	var pos: Vector2
	var angle: float
	if now < bat:
		pos = Vector2(from + STRAGGLE_SPEED * e, y0 + sin(e * 9.0) * 5.0)
		angle = 0.12 * sin(e * 9.0 + 1.0)
	else:
		var u := now - bat
		pos = Vector2(spot.x + STRAGGLE_SPEED * 0.85 * u, y0 - 820.0 * u + 260.0 * u * u)
		angle = -0.5 + u * TAU * 1.4 * maxf(0.0, 1.0 - u * 0.8)
	if pos.x > size.x + FLOCK_PX or pos.y < -FLOCK_PX:
		return
	var mesh := _flock_mesh(_last_plane)
	shown.append(mesh)
	_life_layer.draw_mesh(mesh, null, Transform2D(angle, Vector2.ONE * 0.85, 0.0, pos))

# --- the nap cat ---

func _cat_px() -> float:
	return size.x * CAT_PX

## The panel's outer rect (rim and all).
func _panel_rect() -> Rect2:
	var span := Vector2(float(_state.cols), float(_state.rows)) * _cell
	var pad := Vector2.ONE * (PANEL_PAD + PANEL_RIM)
	return Rect2(_origin - pad, span + pad * 2.0)

## Where she curls up: on the panel's foot, a fifth of the way along from
## its left (the seal takes the right), her cushion on the rim. The sky is
## empty by then, so she hides nothing.
func _cat_spot() -> Vector2:
	var box := _panel_rect()
	return Vector2(box.position.x + box.size.x * 0.22, box.end.y - _cat_px() * 0.38)

## Where she pops up: the panel's lower left corner.
func _cat_start() -> Vector2:
	var box := _panel_rect()
	return Vector2(box.position.x + _cat_px() * 0.5, box.end.y - _cat_px() * 0.38)

func _cat_walk() -> float:
	return CAT_POP + CAT_HOPS * CAT_HOP_TIME

## Puts the cat where her clock says: nowhere yet; popping up on the corner;
## hopping along the foot; landing with a squash; sitting up awake; batting
## at the straggler (up on her hind legs, leaning into it); curled up asleep,
## purring. Under reduce motion she is simply curled up there.
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
		_cat.pivot_offset = _cat.size * Vector2(0.5, 0.85)
	var e := t - _cat_at
	var spot := _cat_spot()
	var start := _cat_start()
	var at := spot
	var sc := Vector2.ONE
	var turn := 0.0
	var bat := BAT_AT - CAT_AT
	if Motion.reduce or e >= CURL_AT - CAT_AT or _cat_curled:
		if not _cat_curled:
			_curl_cat(e > CURL_AT - CAT_AT + 1.0)
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
	elif e < _cat_walk() + CAT_SETTLE:
		var u := (e - _cat_walk()) / CAT_SETTLE
		var s := 0.14 * sin(u * PI)
		sc = Vector2(1.0 + s, 1.0 - s)
	elif e >= bat - 0.12 and e < bat + BAT_TIME:
		# Up she goes at the passing plane, leaning into it, and down.
		var u := clampf((e - bat + 0.12) / (BAT_TIME + 0.12), 0.0, 1.0)
		var up := sin(u * PI)
		at = spot - Vector2(0.0, 0.3 * px * up)
		sc = Vector2(1.0 - 0.08 * up, 1.0 + 0.12 * up)
		turn = -0.32 * up
	_cat.position = at - _cat.size * Vector2(0.5, 0.5)
	_cat.scale = sc
	_cat.rotation = turn

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

# --- the life over the sky ---

## Drops what has finished and says whether anything on the life layer still
## moves.
func _tick_life(now: float) -> bool:
	_love = _love.filter(func(l): return now < float(l.t) + LOVE_TIME)
	_birds = _birds.filter(func(b): return now < float(b.t) + float(b.end))
	var party := not Motion.reduce and now >= _party_at - 0.05 and now < _party_at + PARTY_TIME + 0.5
	return not (_love.is_empty() and _birds.is_empty()) or party \
		or (_combo_n >= COMBO_FROM and (now - _combo_at < Motion.POP_IN + 0.1 or _combo_out_at > -INF)) \
		or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1)

## The life over the sky, each thing one cached mesh through a transform:
## love hearts, birds, the flock and the straggler, then the seal and the
## streak's bubble with their words.
func _draw_life() -> void:
	if _cell <= 0.0 or _state.planes.is_empty():
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
			var at: Vector2 = l.at + Vector2(sin(u * TAU + float(l.phase)) * 0.1 * _cell,
				-LOVE_RISE * _cell * (1.0 - (1.0 - u) * (1.0 - u)))
			var k := Motion.pop_in_scale(e, 0.2).x
			_life_layer.draw_mesh(mesh, null, Transform2D(sin(u * TAU) * 0.2, Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.4, 0.0, 1.0)))
	for bird in _birds:
		_draw_bird(bird, now, shown)
	if not Motion.reduce and now >= _party_at:
		_draw_flock(now, shown)
		_draw_straggler(now, shown)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_draw_combo(now, shown)
	_life_shown = shown

## A little pink heart for the love gag, built once a layout.
func _love_heart() -> ArrayMesh:
	if _love_mesh == null:
		var b := Face.Builder.new()
		var r := _love_r()
		b.polygon(_heart(Vector2.ZERO, r * 1.15, 0), Pal.FLOWER_DEEP)
		b.polygon(_heart(Vector2.ZERO, r, 0), Pal.FLOWER)
		b.ellipse(Vector2(-0.45, -0.45) * r, 0.18 * r, 0.1 * r, Color(1.0, 1.0, 1.0, 0.5))
		_love_mesh = b.mesh()
	return _love_mesh

## A love heart's size: a share of the cell, but never a crumb on the hard
## band's small one.
func _love_r() -> float:
	return maxf(11.0, _cell * LOVE_R)

# --- the bird ---

func _bird_px() -> float:
	return clampf(_cell * 0.62, BIRD_PX.x, BIRD_PX.y)

## A little robin facing right about its middle: a tail, a round brown body
## with an orange breast, a head with a beak and a bright eye. Its wing is a
## mesh of its own (`_bird_wing`) so it can flap.
func _bird_body() -> ArrayMesh:
	if _bird_mesh == null:
		var b := Face.Builder.new()
		var s := _bird_px() * 0.5
		b.polygon(PackedVector2Array([Vector2(-0.5, -0.05) * s, Vector2(-1.0, -0.32) * s,
			Vector2(-0.98, 0.12) * s]), BIRD_WING)
		b.ellipse(Vector2(0.0, 0.05) * s, 0.62 * s, 0.5 * s, BIRD_BODY)
		b.ellipse(Vector2(0.2, 0.2) * s, 0.38 * s, 0.3 * s, BIRD_BREAST)
		b.disc(Vector2(0.45, -0.3) * s, 0.34 * s, BIRD_BODY)
		b.polygon(PackedVector2Array([Vector2(0.72, -0.37) * s, Vector2(1.0, -0.28) * s,
			Vector2(0.72, -0.19) * s]), Pal.SUN_DEEP)
		b.disc(Vector2(0.55, -0.36) * s, 0.075 * s, Pal.OUTLINE)
		b.disc(Vector2(0.57, -0.39) * s, 0.025 * s, Color.WHITE)
		b.ellipse(Vector2(0.62, -0.18) * s, 0.07 * s, 0.045 * s, Color(Pal.CHEEK, 0.7))
		_bird_mesh = b.mesh()
	return _bird_mesh

## The wing, its root at the origin (the shoulder), reaching back and up.
func _bird_wing() -> ArrayMesh:
	if _wing_mesh == null:
		var b := Face.Builder.new()
		var s := _bird_px() * 0.5
		var pts := PackedVector2Array()
		for k in 16:
			var a := TAU * float(k) / 16.0
			pts.append((Vector2(-0.3, -0.22) + Vector2(cos(a) * 0.42, sin(a) * 0.2).rotated(-0.45)) * s)
		b.polygon(pts, BIRD_WING)
		_wing_mesh = b.mesh()
	return _wing_mesh

## Where bird `bird` is `e` seconds in, which way it faces and how much of
## it shows: popping up over the plane's tail, flapping after it along its
## trail (through every bend it made), stopping where the sky ends, hovering
## there looking round, then fluttering off and up, fading.
func _bird_at(bird: Dictionary, e: float) -> Array:
	var i: int = bird.i
	var dir := Vector2(_state.planes[i]["dir"])
	var side: Vector2 = bird.side
	var lift := Vector2(0.0, -_cell * 0.3)
	var stop := _track(i, float(bird.stop)) + lift
	var chase := float(bird.chase)
	var bob := Vector2(0.0, sin(e * 11.0) * _cell * 0.05)
	var face := signf(dir.x) if dir.x != 0.0 else (signf(side.x) if side.x != 0.0 else 1.0)
	if e < chase:
		var x := clampf((e - BIRD_POP) * BIRD_SPEED, 0.0, float(bird.stop))
		var at := _track(i, x)
		var ahead := _track(i, minf(x + 0.3, float(bird.stop) + 0.3)) - at
		if absf(ahead.x) > 0.5:
			face = signf(ahead.x)
		return [at + lift + bob, face, 1.0]
	if e < chase + BIRD_HOVER:
		# Where did it go? A look one way, then the other.
		var u := (e - chase) / BIRD_HOVER
		return [stop + bob, face if u < 0.5 else -face, 1.0]
	var u := clampf((e - chase - BIRD_HOVER) / BIRD_LEAVE, 0.0, 1.0)
	var away := (side * 1.2 - dir * 0.8 + Vector2(0.0, -1.2)).normalized()
	var at := stop + away * _cell * 3.0 * u * u + Vector2(0.0, sin(u * TAU * 2.0) * _cell * 0.12)
	return [at, signf(away.x) if away.x != 0.0 else face, 1.0 - u]

func _draw_bird(bird: Dictionary, now: float, shown: Array) -> void:
	var e := now - float(bird.t)
	if e < 0.0:
		return
	var where: Array = _bird_at(bird, e)
	var k := Motion.pop_in_scale(e, 0.2).x
	if k <= 0.0:
		return
	var body := _bird_body()
	var wing := _bird_wing()
	shown.append(body)
	shown.append(wing)
	var xf := Transform2D(0.0, Vector2(float(where[1]) * k, k), 0.0, where[0])
	var alpha := Color(1.0, 1.0, 1.0, float(where[2]))
	_life_layer.draw_mesh(body, null, xf, alpha)
	var flap := 0.15 + 0.85 * cos(e * BIRD_FLAP * TAU)
	var shoulder := Vector2(-0.05, -0.08) * _bird_px() * 0.5
	_life_layer.draw_mesh(wing, null, xf * Transform2D(0.0, Vector2(1.0, flap), 0.0, shoulder), alpha)

# --- the bubble and the seal ---

## The streak's paper bubble over the launch spot, "x3" and up in leaf ink:
## it pops in the first time, bumps at each launch and deflates when the
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

## The seal on the panel's lower right corner, dropping in from STAMP_FROM
## its size and settling with the back ease's overshoot, its words over it:
## Flawless; on Windy Day "Insane" over Flawless or Windy Day, on the night
## seal.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := size.x * STAMP_R * 0.75
	var insane: bool = _state.windy()
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	# Over the panel's lower right corner, hanging off it like a stamp on a
	# parcel.
	var corner := _panel_rect().end
	var centre := corner - Vector2(rad * 0.85, rad * 0.72)
	# Never past the card's hem (Hard's panel runs nearly to it).
	centre.x = minf(centre.x, size.x - rad * 1.08)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless else tr("PP_WINDY_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
