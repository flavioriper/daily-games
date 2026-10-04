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
##
## The polish of 2026-09-30 (docs/superpowers/specs/2026-09-30-lightup-polish-design.md)
## added hearts on Hard and Insane (a fair lamp that is not the answer's
## gutters out and is taken up), Insane's Cat Naps, blocks that hop and cats
## that purr when their numbers are met, right lamps that flare and draw
## moths, the streak, gags, the seal and a party with hats, a garland of
## paper lanterns and sky lanterns (docs/agents/boards/lightup.md).

const State = preload("res://puzzles/lightup_state.gd")
const Gen = preload("res://puzzles/lightup_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const CourtLantern = preload("res://ui/faces/court_lantern.gd")
const NapCat = preload("res://ui/faces/nap_cat.gd")
const SnailFace = preload("res://ui/faces/snail_face.gd")
const Seal = preload("res://ui/flat/seal.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
const MovesPill = preload("res://ui/flat/moves_pill.gd")
const MovesDiagram = preload("res://ui/hud/moves_tutorial_diagram.gd")
## The moves the out-of-moves card's video buys, once a board.
const MOVES_BONUS := 5

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

# --- the polish of 2026-09-30 (docs/superpowers/specs/2026-09-30-lightup-polish-design.md) ---
## The hearts' strip over the court, on Hard and Insane only; Shikaku's and
## Tents' pill, and their numbers.
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
## A wrong lamp worries, and WILT_LAG later sags. Its light is let reach the
## court first; GUTTER_FROM after the tap it draws back along the beam toward
## the lamp, the far stones first, GUTTER_STEP per stone (capped at
## GUTTER_CAP), each cooling over GUTTER_OUT, so the lamp's own stone goes
## dark just before EJECT_AFTER, when it is taken up.
const WILT_LAG := 0.2
const EJECT_AFTER := 0.75
const GUTTER_FROM := 0.26
const GUTTER_STEP := 0.03
const GUTTER_CAP := 0.2
const GUTTER_OUT := 0.25
## Out of hearts: the court slips to dusk over DUSK_TIME -- the floor keeps
## DUSK_WARM of its warmth, every stone goes DUSK_SHADE toward its own deep
## colour and the beams keep DUSK_BEAM of their strength -- and the lanterns
## and cats nod off along the diagonal, SLEEP_STAGGER apart. The card comes
## up CARD_AFTER later (CARD_AFTER_STILL under reduce motion).
const DUSK_TIME := 0.8
const DUSK_WARM := 0.45
const DUSK_SHADE := 0.35
const DUSK_BEAM := 0.35
const SLEEP_STAGGER := 0.05
const CARD_AFTER := 1.1
const CARD_AFTER_STILL := 0.3
## A cat's seat, in cells, and how much of a beam crossing her stone is drawn
## over her (the light passes over her: she is on the floor).
const CAT_SIZE := 0.98
const VEIL_ALPHA := 0.55
## The streak (Binairo's, Shikaku's and Tents'): right lamps in a row, a
## pentatonic step each from the second, the "x3" bubble from COMBO_FROM, and
## confetti at COMBO_CONFETTI.
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0
const COMBO_CONFETTI := [5, 10]
const COMBO_DEFLATE := 0.25
## The bubble shows its number this long, then deflates on its own; the
## streak itself runs on, and the next right move pops it back in.
const COMBO_HOLD := 1.2
const COMBO_FONT := 44
## Gags: three of every five right lamps, by the stone's own hash (Tents').
const GAG_ODDS := 5
const GAGS := 3
const GAG_AT := 0.35
const GLASSES_IN := 0.28
const GLASSES_HOLD := 0.9
const GLASSES_OUT := 0.2
## The lantern's smoke ring: a small heart of smoke puffed off its cap that
## rises SMOKE_RISE cells, grows from SMOKE_FROM to 1 and fades over
## SMOKE_TIME, swaying SMOKE_SWAY cells as it goes; SMOKE_R is its half-width
## at full size, in cells.
const SMOKE_TIME := 1.5
const SMOKE_RISE := 0.9
const SMOKE_FROM := 0.55
const SMOKE_SWAY := 0.08
const SMOKE_R := 0.26
## The snail with her own tiny lantern, sliding across the front of the stone
## over SNAIL_TIME, SNAIL_SIZE cells high.
const SNAIL_TIME := 2.2
const SNAIL_SIZE := 0.62
const SNAIL_REACH := 0.95
## A right lamp's candle flares: the halo swells FLARE_GROW over FLARE_UP and
## settles over FLARE_DOWN.
const FLARE_UP := 0.12
const FLARE_DOWN := 0.45
## A block that has just got its number hops CHEER_HOP cells, after
## CHEER_LAG.
const CHEER_HOP := -0.13
const CHEER_LAG := 0.1
## A cat whose number has just been met purrs PURR_HEARTS little hearts that
## rise PURR_RISE cells over PURR_TIME, PURR_STAGGER apart, PURR_R cells wide.
const PURR_HEARTS := 3
const PURR_TIME := 1.1
const PURR_RISE := 0.6
const PURR_STAGGER := 0.16
const PURR_R := 0.09
## Lanterns and cats within this many stones of the finger look at it.
const GLANCE_REACH := 2
## Moths (Tents' butterflies, drawn to the light): they circle judged lamps
## on Hard and Insane -- one from the first, a second past MOTH_SECOND of the
## answer's lamps -- MOTH_PARTY more at the party on every board, and they go
## FLIES_STAY after it. A moth circles its lamp on an ellipse MOTH_ORBIT
## cells across (x, y), MOTH_LIFT above its centre, at MOTH_TURN radians a
## second, and moves on after MOTH_STAY (plus up to MOTH_JITTER).
const MOTH_SECOND := 0.4
const MOTH_SPEED := 2.4
const MOTH_ORBIT := Vector2(0.46, 0.2)
const MOTH_LIFT := 0.12
const MOTH_TURN := 2.6
const MOTH_STAY := 3.0
const MOTH_JITTER := 2.5
const MOTH_SIZE := 0.2
const MOTH_PARTY := 3
const FLIES_STAY := 5.0
## The moths' wings: pale and dusty, each with a faint tint of its own.
const MOTH_WINGS := [Color("f4ecdc"), Color("ece6f4"), Color("f6e6dc")]
const MOTH_BODY := Color("c9ab86")
const MOTH_LEVELS := 4
## The seal, stamped onto the court's lower right (Tents').
const STAMP_AT := 0.35
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.14
const STAMP_TILT := -0.22
## The party: hats, then the garland of paper lanterns dropping in over the
## top of the court and swinging to rest, then the sky lanterns.
const PARTY_AT := 0.15
const PARTY_HAT := 0.3
const PARTY_HAT_STAGGER := 0.03
const PARTY_EXTRA := 1.3
const GARLAND_TIME := 0.6
const GARLAND_SETTLE := 2.5
const GARLAND_SAG := 0.3
## A lantern on the garland every GARLAND_EVERY cells, GARLAND_SIZE cells
## tall.
const GARLAND_EVERY := 1.1
const GARLAND_SIZE := 0.36
## Every lamp lets a paper sky lantern go SKY_AT after the hats, along the
## diagonal SKY_STAGGER apart: it rises SKY_RISE cells past the card's top
## over SKY_TIME, swaying SKY_SWAY cells, and fades over its last SKY_FADE.
const SKY_AT := 0.35
const SKY_STAGGER := 0.05
const SKY_TIME := 2.8
const SKY_RISE := 1.5
const SKY_SWAY := 0.12
const SKY_FADE := 0.45
const SKY_SIZE := 0.46
## The sweep ticks up a little per stone, as Tents' does.
const SWEEP_PITCH := 0.04
const SWEEP_PITCH_MAX := 1.6

const HINTS := State.HINTS
const TIP_CYCLE := 10.0
const TIPS := [
	"LU_TIP_LIGHT",
	"LU_TIP_NO_SEE",
	"LU_TIP_NUMBER",
]

var state = State.new()
## Back to the menu from the out-of-hearts card; the host listens for it.
signal leave
## The names the win harness and the island board share, so one driver solves
## both twins.
var w: int:
	get: return state.w
var h: int:
	get: return state.h
var _solution_bulbs: Array:
	get: return state.solution

var fx: Node2D
## Hearts (Hard 3, Insane 1) and failing, Tents' names.
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
## Insane's move counter (ui/flat/moves_pill.gd): `max_moves` is 0 on a band
## that does not count. Out of moves unsolved is `out_of_hearts`, the name
## the host and the card already know.
var moves_left := 0
var max_moves := 0
var _moves_pill := MovesPill.new()
var _lost_ever := false
var _asleep := false
var _ejecting := false
var _heart_card: Control
var _split_index := -1
var _split_at := -INF
var _back_index := -1
var _back_at := -INF
## The lamps a tap was judged right on (fair and the answer's, on a board
## with hearts), and every lamp a hint lit: Vector2i -> true. Only these may
## be rewarded as right (JOY now; the moth and the flare hang on it). A lamp
## that turns fair some other way -- a neighbour taken up, an undo -- was
## never charged for, so rewarding it would tell the player for free what a
## heart is meant to cost (Tents' review).
var _judged: Dictionary = {}
## Wrong lamps going out: Vector2i -> {"at": float, "reach": int}. Their light
## draws back toward them from `at`, the far end of the longest beam first.
var _guttering: Dictionary = {}
## The dusk the court slips into out of hearts, 0 day to 1 dusk, moving from
## `_dusk_from` to `_dusk_to` over DUSK_TIME from `_dusk_at`.
var _dusk_from := 0.0
var _dusk_to := 0.0
var _dusk_at := -INF
## Insane's cats: Vector2i -> NapCat, one in a slot on each cat's stone, and
## the state each was last shown in (for the purr and the wake).
var _cats: Dictionary = {}
var _cat_was: Dictionary = {}
var _heart_layer: Control
var _veil_layer: Control
var _hearts_shown: ArrayMesh
## The stretches of beam that cross a cat's stone this frame, drawn again
## over her by the veil layer: [from, to, half, c0, c1] each.
var _veil_segs: Array = []
var _veil_shown: ArrayMesh
## The streak and its bubble (Tents').
var _flawless := false
var _streak := 0
var _combo_n := 0
var _combo_cell := Vector2i.ZERO
var _combo_at := -INF
var _combo_popped := false
var _combo_out_at := -INF
var _combo_layer: Control
var _combo_shown: ArrayMesh
## The gags and the life on the court: the smoke heart {"cell", "at"}, the
## snail {"cell", "at", "dir"}, the moths, a cat's purring hearts
## [{"at": Vector2, "t": float}], the seal, the garland and the sky lanterns
## ({"at": Vector2, "t": float} each).
var _smoke: Dictionary = {}
var _snail: Dictionary = {}
var _snail_node: Control
var _flies: Array = []
var _purrs: Array = []
var _stamp_at := INF
var _garland_at := INF
var _sky: Array = []
var _seal_mesh: ArrayMesh
var _life_layer: Control
var _life_shown: Array = []
## The life's own meshes, built once each and drawn under a transform: a moth
## per wing and opening, the smoke heart, a purring heart, a sky lantern, and
## the garland once it has come to rest.
var _moth_meshes: Dictionary = {}
var _moth_flat: Dictionary = {}
var _smoke_mesh: ArrayMesh
var _purr_mesh: ArrayMesh
var _sky_mesh: ArrayMesh
var _garland_mesh: ArrayMesh
## The numbered blocks whose count is met, as last shown: a block joining
## them hops.
var _blocks_met: Dictionary = {}
var _sweep_n := 0
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
var _gag_tw: Dictionary = {}     # face -> the glasses or the party hat
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
var _ground_dirty := true
## The checkup (2026-10-01): the floor and the ground were built whole, every
## stone and block in script, on every frame anything on the court moved -- a
## press, a hop, a flare -- about 10 ms and 8 ms on a full Insane court.
## Each stone, block, chip and lamp shadow at rest is now made once
## (`_rest_parts`, Vector3i(x, y, code) -> ArrayMesh) and every one at rest is
## baked into `_floor_rest` / `_ground_rest` with native copies
## (Face.FlatBuilder over `_flat_cache`), again only when that set changes
## (`_floor_key`, `_ground_key`). `_floor_live` and `_ground_live` keep only
## what moves, and the beams are built again only while the light moves.
const STILL_NONE := -2
const STILL_LIGHT := -3
const STILL_MOVING := -1
const STILL_CHIP := 1
const STILL_SHADOW := 2
const STILL_BLOCK := 8
const BLOCK_LIT_MOVING := -5
## The parts drawn about their own centre and put through a transform
## (_local_part): a block's shadow, a lamp's shadow, a block's body
## (LOCAL_BODY + its state).
const LOCAL_BLOCK_SHADOW := 300
const LOCAL_LAMP_SHADOW := 301
const LOCAL_BODY := 310
var _rest_parts: Dictionary = {}
var _flat_cache: Dictionary = {}
var _floor_key := PackedInt32Array()
var _ground_key := PackedInt32Array()
var _bed: ArrayMesh
var _floor_rest: ArrayMesh
var _floor_flat: ArrayMesh
var _floor_live: ArrayMesh
## Vector4i(x, y, level, dusk) -> a stone's flat triangle list (_stone_flat).
var _stone_cache: Dictionary = {}
const WARM_LEVELS := 8
var _beams: ArrayMesh
var _beams_dirty := true
var _flares: ArrayMesh
var _ground_rest: ArrayMesh
var _ground_flat: ArrayMesh
var _ground_live: ArrayMesh
## The checkup (2026-10-01): every lamp and cat drew itself, a canvas command
## a layer -- fifty of a full Insane court's 170 draw calls. They still move
## as ever (pops, hops, flickers, blinks and expressions are theirs) but draw
## only their hats and glasses: `_cast`, under them, draws every body in one
## MultiMesh per mesh on show (Tents'), synced every frame since the candles
## always flicker; a buffer is handed over only when it changed.
var _cast: Control
var _cast_mm: Dictionary = {}     # ArrayMesh -> MultiMesh, the meshes on show
var _cast_order: Array = []       # the meshes on show, in drawing order
var _cast_sent: Dictionary = {}   # MultiMesh -> the buffer last handed over
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
	var out := tr("LU_RULES")
	if state.has_cats():
		out += "\n\n" + tr("LU_RULES_CAT")
	if max_moves > 0:
		out += "\n\n" + tr("RULES_MOVES") % max_moves
	return out

## The lines the sprout cycles: a court with cats leads with the question
## the napping cat asks, and a counted one with its moves before that.
func _tips() -> Array:
	var out: Array = TIPS
	if state.has_cats():
		out = ["LU_TIP_CAT"] + out
	if max_moves > 0:
		out = ["TIP_MOVES"] + out
	return out

## The tutorial, a page a rule, each a small court played by the board itself
## (ui/hud/lightup_tutorial_diagram.gd): light and blocks, sight, numbers,
## chips, the hint, then hearts on Hard and Insane and cats on Cat Naps.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/lightup_tutorial_diagram.gd")
	var hints: int = State.HINTS_BY_BAND[clampi(state.band, 0, 3)]
	var steps := [
		[Diagram.Lesson.LIGHT, "HTP_LU_LIGHT", tr("HTP_LU_LIGHT_BODY")],
		[Diagram.Lesson.SEE, "HTP_LU_SEE", tr("HTP_LU_SEE_BODY")],
		[Diagram.Lesson.NUMBERS, "HTP_LU_NUMBERS", tr("HTP_LU_NUMBERS_BODY")],
		[Diagram.Lesson.CHIPS, "HTP_LU_CHIPS", tr("HTP_LU_CHIPS_BODY")]]
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_LU_HINT_BODY_ONE") if hints == 1 else tr("HTP_LU_HINT_BODY_N") % hints])
	if state.has_cats():
		steps.append([Diagram.Lesson.CATS, "LU_CAT_SEAL", tr("LU_RULES_CAT")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.hearts = maxi(1, max_hearts)
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	if max_moves > 0:
		pages.append(MovesDiagram.page(self, max_moves))
	return pages

## Insane counts moves: no Undo (taking a lamp up is the take-back, and it
## costs one), no hint and no Check, which would each say what is wrong.
func capabilities() -> Array[String]:
	if state.band >= 3:
		return []
	return ["undo", "hint", "check"]

## What the phone does under each cue (docs/agents/haptics.md). A lamp set
## down is the faintest knock, fair or not (its face and the blocks say
## that); the streak knocks only where its confetti flies. `strike` and
## `clear` are not here: the board blows a wrong lamp out itself with the
## one and the sweep fires the other a stone, so the tap that takes a lamp
## or a chip up ticks from `_commit` and the sweep once as it is let go
## (`_release`). `purr` fires on Undo and a hint too: a cat whose number
## the hand's own tap met bumps from `_cat_turns` (`_by_hand`). A block or
## a pinned lamp tapped, a block's hop, a cat woken, the streak's pluck, the
## moths and the gags say nothing. The seal thuds as it lands (`_party`).
const HAPTICS := {
	"undo": Haptics.TICK,
	"place": Haptics.TAP,
	"reset": Haptics.TAP,
	"confetti": Haptics.BUMP,
	"hint": Haptics.GOOD,
	"check_ok": Haptics.GOOD,
	"heart_back": Haptics.GOOD,
	"check": Haptics.WARN,
	"heart_lost": Haptics.BAD,
	"out_of_hearts": Haptics.LOSE,
	"solved": Haptics.WIN,
}
## True while the hand's own tap is being put on the court: only then does
## a cat's number met knock.
var _by_hand := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.haptics = HAPTICS
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_cast = _layer("Cast", 0, _draw_cast)
	_veil_layer = _layer("Veil", 1, _draw_veil)
	_life_layer = _layer("Life", 1, _draw_life)
	_heart_layer = _layer("Hearts", 1, _draw_hearts)
	_combo_layer = _layer("Combo", 2, _draw_combo)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

## A full-rect layer over the pieces, drawn by `draw` (Tents').
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
	max_moves = state.moves_budget()
	_heart_used = false
	_lost_ever = false
	_deal()
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
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	_enter()

## The court as it is dealt, and as Try again deals it back: every heart,
## the day's light, nothing judged or going out.
func _deal() -> void:
	hearts = max_hearts
	moves_left = max_moves
	out_of_hearts = false
	_asleep = false
	_ejecting = false
	_split_index = -1
	_back_index = -1
	_judged = {}
	_guttering = {}
	_dusk_from = 0.0
	_dusk_to = 0.0
	_dusk_at = -INF
	_flawless = false
	_streak = 0
	_combo_n = 0
	_combo_out_at = -INF
	_smoke = {}
	_snail = {}
	_flies = []
	_purrs = []
	_sky = []
	_stamp_at = INF
	_garland_at = INF
	_garland_mesh = null
	_seal_mesh = null
	_sweep_n = 0
	_blocks_met = _met_blocks()
	if _snail_node != null:
		_snail_node.visible = false
	for layer: Control in [_heart_layer, _veil_layer, _life_layer, _combo_layer]:
		if layer != null:
			layer.queue_redraw()

# --- the cast ---

## Only the lamps and the cats are nodes. The court, the blocks and the
## chips are drawn. A cat is made once, with her board, and waits unseen
## until the entrance pops her onto her cushion.
func _build_pieces() -> void:
	for piece in _slots:
		_slots[piece].queue_free()
	_slots = {}
	_lamps = {}
	_cats = {}
	_cat_was = {}
	for cell: Vector2i in state.cats:
		var cat := NapCat.new()
		cat.skip_layers = ["base", "tip", "head"]
		cat.need = state.cat_need(cell)
		cat.scale = Vector2.ZERO
		_stand(cat, "cat_%d_%d" % [cell.x, cell.y])
		cat.name = "cat"
		cat.set_idle(true)
		_cats[cell] = cat
		_cat_was[cell] = state.cat_state(cell)

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
	lamp.skip_layers = ["glow", "body"]
	lamp.visible = false
	lamp.scale = Vector2.ZERO
	_stand(lamp, "lamp_%d_%d" % [cell.x, cell.y])
	lamp.set_idle(true)
	_lamps[cell] = lamp
	if _cell > 0.0:
		_seat(lamp, cell_to_local(cell.y, cell.x), _cell * LAMP_SIZE)
	return lamp

## Every lamp and cat takes the look its state asks for. A face is written
## only when its look changes -- a written face redraws. A cat whose number
## has just been met purrs; a napping cat the light has just reached wakes
## (unless `quiet`: a deal, a restore, Try again).
func _refresh_faces(quiet := false) -> void:
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
		# The win writes JOY on each lamp as the wave reaches it; a wrong lamp
		# keeps its worry until it is taken up.
		if _solved_at > NEVER or _guttering.has(cell):
			continue
		_set_expr(lamp, _lamp_expr(cell))
	for cell in _cats:
		var now_state: int = state.cat_state(cell)
		var was := int(_cat_was.get(cell, now_state))
		_cat_was[cell] = now_state
		if now_state != was and not quiet and not is_done():
			_cat_turns(cell, was, now_state)
		if _solved_at > NEVER:
			continue
		_set_expr(_cats[cell], _cat_expr(cell))
	_cheer_blocks(quiet)

## The numbered blocks whose count is met right now.
func _met_blocks() -> Dictionary:
	var out: Dictionary = {}
	for y in state.h:
		for x in state.w:
			var cell := Vector2i(x, y)
			if _is_block(cell) and int(state.grid[y][x]) >= 0 and state.block_state(cell) == State.BLOCK_OK:
				out[cell] = true
	return out

## Every numbered block that has just got its number hops, with a green
## sparkle over it (unless `quiet`: a deal, a restore, a relayout).
func _cheer_blocks(quiet: bool) -> void:
	var met := _met_blocks()
	if not quiet and not is_done() and not Motion.reduce and _cell > 0.0:
		var now := _now()
		for cell in met:
			if _blocks_met.has(cell):
				continue
			_block_hop[cell] = {"at": now + CHEER_LAG, "height": CHEER_HOP * _cell, "time": Motion.HOP_TIME}
			_after(CHEER_LAG, fx.sparkle.bind(cell_to_local(cell.y, cell.x) - Vector2(0.0, _cell * 0.3), Pal.LEAF_LIGHT))
			_busy_for(CHEER_LAG + Motion.HOP_TIME)
	_blocks_met = met

## A lamp's look: asleep with the court, straining in trouble, JOY on a board
## with hearts once a tap on it was judged right and the board can still
## fault nothing about it, and otherwise simply burning.
func _lamp_expr(cell: Vector2i) -> int:
	if _asleep:
		return Face.Expr.SLEEPY
	if state.clash.has(cell):
		return Face.Expr.STRAIN
	if max_hearts > 0 and _judged.has(cell) and state.lamp_fair(cell):
		return Face.Expr.JOY
	return Face.Expr.HAPPY

## A cat's look: waiting while short of her number, JOY with her tail going
## once it is met, cross (STRAIN, ears back) when more light reaches her than
## she wants. A napping cat is asleep while she is dark and cross once lit.
func _cat_expr(cell: Vector2i) -> int:
	if _asleep:
		return Face.Expr.SLEEPY
	match state.cat_state(cell):
		State.CAT_OVER:
			return Face.Expr.STRAIN
		State.CAT_OK:
			return Face.Expr.SLEEPY if state.cat_need(cell) == 0 else Face.Expr.JOY
	return Face.Expr.HAPPY

## A cat's state has just changed under the player's hand: her number met
## (not a napping cat going dark again, who simply sleeps on) purrs and
## hops; a napping cat reached by the light wakes cross with a mew and a
## shiver.
func _cat_turns(cell: Vector2i, was: int, now_state: int) -> void:
	var cat: NapCat = _cats[cell]
	var napping := state.cat_need(cell) == 0
	if now_state == State.CAT_OK and not napping:
		fx.cue("purr")
		if _by_hand:
			fx.buzz(Haptics.BUMP)
		_hop(cat, Motion.HOP, Motion.HOP_TIME, Motion.NUDGE_LAG)
		_on_cat_happy(cell)
	elif napping and now_state == State.CAT_OVER and was == State.CAT_OK:
		fx.cue("wake")
		Motion.stop(_pos_tw.get(cat))
		cat.position = Vector2.ZERO
		_pos_tw[cat] = Motion.shiver(cat, _cell * SHIVER)
		_busy_for(Motion.SHIVER_TIME)

## A cat whose number has just been met: the purr and the hop are above, and
## PURR_HEARTS little hearts rise off her head one after another.
func _on_cat_happy(cell: Vector2i) -> void:
	if Motion.reduce or _cell <= 0.0:
		return
	var now := _now()
	var head := cell_to_local(cell.y, cell.x) + NapCat.HEAD_AT * _cell * CAT_SIZE * 0.5
	for k in PURR_HEARTS:
		var side := (-1.0 if k % 2 == 0 else 1.0) * (0.1 + 0.08 * k)
		_purrs.append({"at": head + Vector2(side * _cell, -0.2 * _cell), "t": now + k * PURR_STAGGER,
			"k": k})
	_life_layer.queue_redraw()

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
		var warm := _shown_warmth(cell, now)
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
	var tall := minf(size.y, court.y + 2.0 * PAD + _heart_row())
	_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
	_grid = Vector2(size.x * 0.5 - court.x * 0.5,
		_card.position.y + _heart_row() + (tall - _heart_row() - court.y) * 0.5)
	for cell in _lamps:
		_seat(_lamps[cell], cell_to_local(cell.y, cell.x), _cell * LAMP_SIZE)
	for cell in _cats:
		_seat(_cats[cell], cell_to_local(cell.y, cell.x), _cell * CAT_SIZE)
	_refresh_faces(true)
	# The life's meshes are drawn in cells: a new cell size builds them again.
	_moth_meshes = {}
	_moth_flat = {}
	_rest_parts = {}
	_flat_cache = {}
	_stone_cache = {}
	_floor_key = PackedInt32Array()
	_ground_key = PackedInt32Array()
	_smoke_mesh = null
	_purr_mesh = null
	_sky_mesh = null
	_garland_mesh = null
	_seal_mesh = null
	for layer: Control in [_heart_layer, _veil_layer, _life_layer, _combo_layer]:
		layer.queue_redraw()
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
	return minf((size.x - 2.0 * PAD) / state.w, (available - 2.0 * PAD - _heart_row()) / state.h)

## The strip the hearts stand in over the court, on a board with hearts.
func _heart_row() -> float:
	return HEART_ROW if max_hearts > 0 or max_moves > 0 else 0.0

## The host cuts its card to the court and centres it, which is what these two
## say. A board that wants neither says nothing and fills the slot.
func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * state.h + 2.0 * PAD + _heart_row())

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
func _relight(t: float, delay: Callable, out_time := LIGHT_OUT) -> void:
	var lit := _lit_now()
	for cell in _floor_cells():
		var target := 1.0 if lit.has(cell) else 0.0
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
		rec.dur = LIGHT_IN if target > cur else out_time
		_anim_until = maxf(_anim_until, float(rec.at) + float(rec.dur))

## The light travelling out from `origin`: LIGHT_STEP per cell away, capped.
func _travel_from(origin: Vector2i) -> Callable:
	return func(cell: Vector2i) -> float:
		return minf(LIGHT_STEP * float(absi(cell.x - origin.x) + absi(cell.y - origin.y)), LIGHT_CAP)

## A wrong lamp's light drawing back toward it along its beams: the far end
## of the longest first, the lamp's own stone last (see _gutter_delay).
func _draw_back(origin: Vector2i) -> Callable:
	return func(cell: Vector2i) -> float:
		var g: Dictionary = _guttering.get(origin, {})
		if g.is_empty():
			return 0.0
		return float(g.at) - _now() + _gutter_delay(g, absi(cell.x - origin.x) + absi(cell.y - origin.y))

## How long after its lamp began to gutter the stone `dist` along its beam
## begins to cool.
static func _gutter_delay(g: Dictionary, dist: int) -> float:
	return GUTTER_FROM + minf(GUTTER_STEP * float(maxi(0, int(g.reach) - dist)), GUTTER_CAP)

## The stones light reaches right now, as the floor should show it: the
## state's own `lit`, less whatever only a guttering lamp lights.
func _lit_now() -> Dictionary:
	if _guttering.is_empty():
		return state.lit
	var out: Dictionary = {}
	for b: Vector2i in state.lamps():
		if _guttering.has(b):
			continue
		out[b] = true
		for d in State.DIRS:
			var p: Vector2i = b + d
			while state.lets_light(p):
				out[p] = true
				p += d
	return out

## The longest of `cell`'s four beams, in stones.
func _reach(cell: Vector2i) -> int:
	var far := 0
	for d in State.DIRS:
		var n := 0
		var p: Vector2i = cell + d
		while state.lets_light(p):
			n += 1
			p += d
		far = maxi(far, n)
	return far

## Every stone of the floor: the open ones and the cats' (light crosses a
## cat, and her stone warms under her like any other).
func _floor_cells() -> Array:
	return state.white_cells() + state.cats

## A block's stone: neither open nor a cat's.
func _is_block(cell: Vector2i) -> bool:
	return state.in_field(cell) and not state.lets_light(cell)

## How far into dusk the court is right now, 0 to 1.
func _dusk(now: float) -> float:
	if Motion.reduce:
		return _dusk_to
	return lerpf(_dusk_from, _dusk_to, _sine_io((now - _dusk_at) / DUSK_TIME))

## The court slips toward dusk (1) or back into the day (0).
func _dusk_toward(level: float) -> void:
	var now := _now()
	_dusk_from = _dusk(now)
	_dusk_to = level
	_dusk_at = now
	_busy_for(DUSK_TIME)
	_redraw()

## The warmth as the court shows it: the light on the stone, dimmed by dusk.
func _shown_warmth(cell: Vector2i, now: float) -> float:
	return _warmth(cell, now) * (1.0 - (1.0 - DUSK_WARM) * _dusk(now))

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
	for cell in _floor_cells():
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
		busy = _build_court(now)
		_ground_dirty = false
	# The court pops in wide once the chrome has slid in, drawn.
	var since := now - _opened - Motion.ENTER_DELAY
	if since < Motion.ENTER_POP:
		busy = true
	var seen := Motion.appear_level(since)
	if seen > 0.0:
		var grown := Motion.wide_pop_scale(since)
		var xf := Transform2D(0.0, Vector2(grown, grown), 0.0, _court_centre())
		for m in [_bed, _floor_rest, _floor_flat, _floor_live, _beams, _flares]:
			if m != null:
				draw_mesh(m, null, xf, Color(1.0, 1.0, 1.0, seen))
				shown.append(m)
	for m in [_ground_rest, _ground_flat, _ground_live]:
		if m != null:
			draw_mesh(m, null)
			shown.append(m)
	_shown = shown
	_draw_numbers(now)
	if busy:
		_anim_until = maxf(_anim_until, now + 0.1)

## Builds what the court shows right now: the bed, the stones and the ground
## at rest (baked again only when that set changes), what moves, and the
## beams (again only while the light moves). Returns whether anything is
## still moving.
func _build_court(now: float) -> bool:
	var origin := -Vector2(_cell * state.w, _cell * state.h) * 0.5
	var dusk := _dusk(now)
	var busy := false
	for cell in _sunk.keys():
		if now >= float(_sunk[cell].up) + Motion.RELEASE_TIME:
			_sunk.erase(cell)
	busy = not _sunk.is_empty()
	# The bed warms toward lamplight once the court is solved.
	var bed := Color(Pal.TEXT, MORTAR_ALPHA)
	var winning := false
	if _solved_at > NEVER:
		var won := _dec((now - _solved_at - Motion.SOLVE_DELAY) / WARM_TIME)
		winning = won < 1.0
		bed = bed.lerp(Color(Pal.SUN, WARM_ALPHA), _sine_io(won))
	var field := Vector2(_cell * state.w, _cell * state.h)
	var bb := Face.Builder.new()
	bb.fan(Face.Builder.round_rect(origin - Vector2.ONE * MORTAR,
		field + Vector2.ONE * 2.0 * MORTAR, MORTAR_RADIUS), bed)
	_bed = bb.mesh()
	# The stones: each at rest is one of four made once (lit or not, dusk or
	# not); a stone sinking, warming or glinting is built again this frame.
	var key := PackedInt32Array()
	key.resize(state.w * state.h)
	var live := Face.Builder.new()
	var flat := Face.FlatBuilder.new()
	var light_moving := winning or not _guttering.is_empty() or not _beam_out.is_empty() \
		or (dusk > 0.0 and dusk < 1.0)
	for y in state.h:
		for x in state.w:
			var cell := Vector2i(x, y)
			var i: int = y * state.w + x
			if not state.lets_light(cell):
				key[i] = STILL_NONE
				continue
			var code := _stone_code(cell, now, dusk)
			key[i] = code
			if code >= 0:
				continue
			light_moving = light_moving or code == STILL_LIGHT
			var glint := _glint(cell, now)
			if not _sunk.has(cell) and (dusk == 0.0 or dusk == 1.0):
				# Only its light moves: the stone at the nearest of
				# WARM_LEVELS, made once, and the light's front over it.
				var level := roundi(_warmth(cell, now) * WARM_LEVELS)
				flat.append_flat(_stone_flat(cell, level, int(dusk), origin))
				if glint > 0.0:
					live.fan(_tile(cell, STONE_EDGE, origin), Color(1.0, 1.0, 1.0, GLINT_ALPHA * glint))
				continue
			var grown := 1.0
			var sink := 0.0
			if _sunk.has(cell):
				var pr: Dictionary = _sunk[cell]
				var released := -1.0 if now < float(pr.up) else now - float(pr.up)
				grown = Motion.press_scale(now - float(pr.down), released)
				sink = clampf((1.0 - grown) / (1.0 - Motion.PRESS_SCALE), 0.0, 1.0)
			_stone(live, cell, origin, _shown_warmth(cell, now), dusk, grown, sink, glint)
	_floor_flat = flat.mesh()
	_floor_live = live.mesh() if not live.verts.is_empty() else null
	if key != _floor_key:
		_floor_key = key
		var fb := Face.FlatBuilder.new(_flat_cache)
		for y in state.h:
			for x in state.w:
				var code: int = key[y * state.w + x]
				if code >= 0:
					fb.append_flat(_stone_flat(Vector2i(x, y), (code & 1) * WARM_LEVELS, code >> 1, origin))
		_floor_rest = fb.mesh()
	if light_moving or _beams_dirty:
		_beams_dirty = false
		var beams := Face.Builder.new()
		_build_beams(beams, now, origin)
		_beams = beams.mesh() if not beams.verts.is_empty() else null
	if light_moving:
		# Built again until it has stopped, and once more at rest: the last
		# frame of a fade is a step short of where the stone lands.
		_beams_dirty = true
		busy = true
	var fl := Face.Builder.new()
	_build_flares(fl, now, origin)
	_flares = fl.mesh() if not fl.verts.is_empty() else null
	busy = _build_ground(now, key) or busy
	return busy

## Where a stone stands: STILL_LIGHT while its light, the solve's glint or
## dusk moves on it, STILL_MOVING while it is sunk under a finger, otherwise
## which of its four resting looks it wears (lit + 2 * dusk).
func _stone_code(cell: Vector2i, now: float, dusk: float) -> int:
	if dusk > 0.0 and dusk < 1.0:
		return STILL_LIGHT
	if not Motion.reduce:
		var rec: Dictionary = _warm.get(cell, {})
		if not rec.is_empty() and now < float(rec.at) + float(rec.dur):
			return STILL_LIGHT
		if _solved_at > NEVER:
			var e := (now - _solved_at - _solve_delay(cell)) / WIN_GLINT
			if e > 0.0 and e < 1.0:
				return STILL_LIGHT
	if _sunk.has(cell):
		return STILL_MOVING
	return int(_warmth(cell, now) >= 0.5) + 2 * int(dusk >= 0.5)

## One stone still at `level` of WARM_LEVELS of warmth (dusk 0 or 1), as a
## flat triangle list made once: the resting looks are its two ends, and a
## stone whose light is moving steps through the rest.
func _stone_flat(cell: Vector2i, level: int, dusk: int, origin: Vector2) -> Array:
	var k := Vector4i(cell.x, cell.y, level, dusk)
	var f: Array = _stone_cache.get(k, [])
	if f.is_empty():
		var b := Face.Builder.new()
		var warm := float(level) / WARM_LEVELS * (1.0 - (1.0 - DUSK_WARM) * dusk)
		_stone(b, cell, origin, warm, float(dusk), 1.0, 0.0, 0.0)
		f = Face.FlatBuilder.flat_of(b)
		_stone_cache[k] = f
	return f

## One flagstone, carrying its own warmth -- the stones *are* the display,
## which is why every one is its own tile rather than a tint over a shared
## field -- `grown` of its size, `sink` into its own shade under a finger,
## and `glint` brightened by the light's front. Built about the court's
## centre, so its pop on the entrance is a transform.
func _stone(b, cell: Vector2i, origin: Vector2, warm: float, dusk: float, grown: float,
		sink: float, glint: float) -> void:
	var deep: Color = Pal.FLAGSTONE_DEEP.lerp(Pal.LAMPLIT_DEEP, warm)
	var face: Color = Pal.FLAGSTONE.lerp(Pal.LAMPLIT_FLOOR, warm)
	if dusk > 0.0:
		face = face.lerp(deep, DUSK_SHADE * dusk)
	var tone := (_hash(cell) - 0.5) * 2.0 * STONE_TONE
	face = face.lightened(tone) if tone > 0.0 else face.darkened(-tone)
	if sink > 0.0:
		face = face.lerp(deep, SINK_SHADE * sink)
	b.fan(_tile(cell, 0.0, origin, grown), deep)
	b.fan(_tile(cell, STONE_EDGE, origin, grown), face)
	_dress_stone(b, cell, origin, grown, deep)
	if glint > 0.0:
		b.fan(_tile(cell, STONE_EDGE, origin, grown), Color(1.0, 1.0, 1.0, GLINT_ALPHA * glint))

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
	strength *= 1.0 - (1.0 - DUSK_BEAM) * _dusk(now)
	_veil_segs = []
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
	if _veil_layer != null:
		_veil_layer.queue_redraw()

## One lamp's four shafts. Each cell's length of shaft fades from the strength
## it enters with to the strength it leaves with, so the fall along the line
## is smooth rather than a stair; a shaft that runs into another lamp is rose
## as far as that lamp.
func _beam(b, cell: Vector2i, now: float, origin: Vector2, strength: float) -> void:
	var half := _cell * BEAM_HALF
	var centre := origin + (Vector2(cell) + Vector2.ONE * 0.5) * _cell
	# A wrong lamp's shafts draw back toward it with the floor it lit, even
	# across stones another lamp keeps warm.
	var g: Dictionary = _guttering.get(cell, {})
	for d in State.DIRS:
		var run: Array = []
		var p: Vector2i = cell + d
		while state.lets_light(p):
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
			if not g.is_empty():
				warm *= 1.0 - _sine_io((now - float(g.at) - _gutter_delay(g, i + 1)) / GUTTER_OUT)
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
			if _cats.has(q):
				# The light passes over her: the same stretch again, over the cat.
				_veil_segs.append([from, to, half, Color(tint, tint.a * a0 * VEIL_ALPHA),
					Color(tint, tint.a * a1 * VEIL_ALPHA)])

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

## Everything standing on the court that is not a lamp: the blush of a
## pointed-at stone, the shadow under every lamp, the blocks with their
## shadows, and the chips arriving, standing and leaving. What is at rest is
## one baked mesh, made again only when that set changes; the rest is built
## again this frame. `floor_key` is the stones' (see _stone_code), so a block
## whose lit neighbour is still warming is drawn live. Returns whether any of
## it is still moving. (A sinking stone is the floor's, since the stone
## itself is what sinks.)
func _build_ground(now: float, floor_key: PackedInt32Array) -> bool:
	var b := Face.Builder.new()
	var flat := Face.FlatBuilder.new(_flat_cache)
	var key := PackedInt32Array()
	key.resize(state.w * state.h)
	var busy := false
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
		if not lamp.visible:
			continue
		if is_equal_approx(lamp.scale.y, 1.0) and lamp.modulate.a >= 1.0:
			key[cell.y * state.w + cell.x] = STILL_SHADOW
		else:
			var seen := clampf(lamp.scale.y, 0.0, 1.0) * clampf(lamp.modulate.a, 0.0, 1.0)
			if seen > 0.0:
				flat.append(_local_part(LOCAL_LAMP_SHADOW, cell), Transform2D(0.0, Vector2(seen, seen), 0.0,
					cell_to_local(cell.y, cell.x) + LAMP_SHADOW_AT * _cell), Color(1.0, 1.0, 1.0, seen))
	# The blocks, each through whatever it is doing.
	var dusk_bit := int(_dusk(now) >= 0.5)
	for y in state.h:
		for x in state.w:
			var cell := Vector2i(x, y)
			if not _is_block(cell):
				continue
			var pose := _block_pose(cell, now)
			if pose.is_empty():
				continue
			busy = busy or bool(pose.busy)
			var code := _block_code(cell, pose, now, floor_key)
			if code >= 0:
				key[y * state.w + x] = STILL_BLOCK + code + 64 * dusk_bit
			elif float(pose.flash) > 0.0:
				_block(b, cell, pose, now)
			else:
				# A block hopping, pressed, bumped or only lit by a light
				# that is moving: its shadow and body made once and put
				# through its pose, its rims drawn now.
				var s := _cell * BLOCK_SIZE
				var at := cell_to_local(y, x)
				var scale: Vector2 = pose.scale
				var seen := clampf(scale.y, 0.0, 1.0)
				flat.append(_local_part(LOCAL_BLOCK_SHADOW, cell), Transform2D(0.0, Vector2(seen, seen),
					0.0, at + BLOCK_SHADOW_AT * s), Color.WHITE if seen >= 1.0 else Color(1.0, 1.0, 1.0, seen))
				var xf := Transform2D(0.0, scale, 0.0, at + (pose.offset as Vector2))
				flat.append(_local_part(LOCAL_BODY + state.block_state(cell), cell), xf)
				_block_rims(b, cell, xf, s, now)
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
		var moving := false
		if _chip_in.has(cell):
			var e: float = now - float(_chip_in[cell])
			grow = Motion.pop_in_scale(e)
			if e < Motion.POP_IN:
				busy = true
				moving = true
			else:
				gone.append(cell)
		var alpha := 1.0
		if _solved_at > NEVER:
			var cleared := _dec((now - _solved_at - CLEAR_DELAY - _hash(cell) * CLEAR_SPREAD) / CLEAR_TIME)
			if cleared >= 1.0:
				continue
			if cleared > 0.0:
				busy = true
				moving = true
				alpha = 1.0 - cleared
				grow *= 1.0 - cleared * CLEAR_SHRINK
			else:
				busy = true
		if not moving:
			key[cell.y * state.w + cell.x] = STILL_CHIP
			continue
		if grow.x <= 0.0 or grow.y <= 0.0:
			continue
		_chip(b, cell_to_local(cell.y, cell.x), _cell * CHIP_SIZE, grow, 0.0, alpha)
	for cell in gone:
		_chip_in.erase(cell)
	_ground_flat = flat.mesh()
	_ground_live = b.mesh() if not b.verts.is_empty() else null
	if key != _ground_key:
		_ground_key = key
		var fb := Face.FlatBuilder.new(_flat_cache)
		for y in state.h:
			for x in state.w:
				var code: int = key[y * state.w + x]
				if code > 0:
					fb.append(_ground_part(Vector2i(x, y), code, now), Transform2D.IDENTITY)
		_ground_rest = fb.mesh()
	return busy

## A part drawn about its own centre, made once (see LOCAL_*); a body is the
## cell's own, since a blank block's chisel marks are.
func _local_part(kind: int, cell: Vector2i) -> ArrayMesh:
	var k := Vector3i(cell.x, cell.y, kind) if kind >= LOCAL_BODY else Vector3i(0, 0, kind)
	var m: ArrayMesh = _rest_parts.get(k)
	if m == null:
		var b := Face.Builder.new()
		var s := _cell * BLOCK_SIZE
		match kind:
			LOCAL_BLOCK_SHADOW:
				Scenery.soft_disc(b, Vector2.ZERO, BLOCK_SHADOW_RX * s, BLOCK_SHADOW_RY * s,
					Color(Pal.TEXT, BLOCK_SHADOW_ALPHA))
			LOCAL_LAMP_SHADOW:
				Scenery.soft_disc(b, Vector2.ZERO, LAMP_SHADOW_RX * _cell, LAMP_SHADOW_RY * _cell,
					Color(Pal.TEXT, SHADOW_ALPHA))
			_:
				var tone := _block_tones(kind - LOCAL_BODY)
				_block_body(b, cell, Transform2D.IDENTITY, s, tone[0], tone[1])
		m = b.mesh()
		_rest_parts[k] = m
	return m

## A block's resting look -- its state and which of its four sides a lit
## stone warms -- or -1 while it moves or a neighbour's light does.
func _block_code(cell: Vector2i, pose: Dictionary, now: float, floor_key: PackedInt32Array) -> int:
	if bool(pose.busy) or float(pose.flash) > 0.0 or pose.scale != Vector2.ONE \
			or pose.offset != Vector2.ZERO:
		return -1
	var code := state.block_state(cell)
	for k in State.DIRS.size():
		var n: Vector2i = cell + State.DIRS[k]
		if not state.lets_light(n):
			continue
		if floor_key[n.y * state.w + n.x] == STILL_LIGHT:
			return BLOCK_LIT_MOVING
		if _shown_warmth(n, now) > BEAM_MIN:
			code |= 4 << k
	return code

## One thing on the ground at rest, made once: a block in its look, a chip
## or a lamp's shadow (see _build_ground's keys).
func _ground_part(cell: Vector2i, code: int, now: float) -> ArrayMesh:
	var k := Vector3i(cell.x, cell.y, code)
	var m: ArrayMesh = _rest_parts.get(k)
	if m == null:
		var b := Face.Builder.new()
		if code == STILL_CHIP:
			_chip(b, cell_to_local(cell.y, cell.x), _cell * CHIP_SIZE, Vector2.ONE, 0.0, 1.0)
		elif code == STILL_SHADOW:
			Scenery.soft_disc(b, cell_to_local(cell.y, cell.x) + LAMP_SHADOW_AT * _cell,
				LAMP_SHADOW_RX * _cell, LAMP_SHADOW_RY * _cell, Color(Pal.TEXT, SHADOW_ALPHA))
		else:
			_block(b, cell, {"scale": Vector2.ONE, "offset": Vector2.ZERO, "flash": 0.0}, now)
		m = b.mesh()
		_rest_parts[k] = m
	return m

## A stone's own outline over `cell`, `grown` of its size about its centre.
func _stone_wash(b, cell: Vector2i, grown: float, colour: Color) -> void:
	if grown <= 0.0:
		return
	var span := (_cell - 2.0 * _cell * GAP) * grown
	b.fan(Face.Builder.round_rect(cell_to_local(cell.y, cell.x) - Vector2.ONE * span * 0.5,
		Vector2.ONE * span, _cell * STONE_RADIUS * grown), colour)

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
func _block(b, cell: Vector2i, pose: Dictionary, now: float, rims := true) -> void:
	var s := _cell * BLOCK_SIZE
	var at := cell_to_local(cell.y, cell.x)
	var scale: Vector2 = pose.scale
	var seen := clampf(scale.y, 0.0, 1.0)
	Scenery.soft_disc(b, at + BLOCK_SHADOW_AT * s, BLOCK_SHADOW_RX * s * seen,
		BLOCK_SHADOW_RY * s * seen, Color(Pal.TEXT, BLOCK_SHADOW_ALPHA * seen))
	var tone := _block_tones(state.block_state(cell))
	var face: Color = tone[0]
	var deep: Color = tone[1]
	var flash := float(pose.flash)
	if flash > 0.0:
		# A refused tap: the block flashes toward its own rose, the way a
		# drawn bed flashes toward its blush.
		face = face.lerp(Pal.BAD, BLOCK_ROSE * flash)
		deep = deep.lerp(Pal.MARKER_DEEP, BLOCK_ROSE * flash)
	var xf := Transform2D(0.0, scale, 0.0, at + (pose.offset as Vector2))
	_block_body(b, cell, xf, s, face, deep)
	if rims:
		_block_rims(b, cell, xf, s, now)

## A block's crown and front in state `st`: plain stone, green once its
## number is met, rose when it is over.
static func _block_tones(st: int) -> Array:
	var face: Color = Pal.BLOCK_STONE
	var deep: Color = Pal.BLOCK_DEEP
	match st:
		State.BLOCK_OK:
			face = face.lerp(Pal.LEAF, BLOCK_GREEN)
			deep = deep.lerp(Pal.LEAF_DEEP, BLOCK_GREEN)
		State.BLOCK_OVER:
			face = face.lerp(Pal.BAD, BLOCK_ROSE)
			deep = deep.lerp(Pal.MARKER_DEEP, BLOCK_ROSE)
	return [face, deep]

## A block's stone itself, about its own centre put through `xf`, `s` its
## size: the crown in `face` over its `deep` front, the cut and the bevel,
## and the plaque its number is carved in or the chisel marks of a blank.
func _block_body(b, cell: Vector2i, xf: Transform2D, s: float, face: Color, deep: Color) -> void:
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

## The light the lit stones beside a block throw on its sides.
func _block_rims(b, cell: Vector2i, xf: Transform2D, s: float, now: float) -> void:
	for d in State.DIRS:
		var n: Vector2i = cell + d
		if not state.lets_light(n):
			continue
		var warm := _shown_warmth(n, now)
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
	# Nothing takes a finger while a wrong lamp goes out or the court sleeps.
	if is_done() or cell.x < 0 or out_of_hearts or _ejecting:
		return
	_press_cell = cell
	_glance(cell)
	var now := _now()
	var node: Control = _lamps.get(cell) if state.mark_at(cell) == State.LAMP else _cats.get(cell)
	if node != null:
		_pressed = node
		Motion.stop(_look_tw.get(_pressed))
		_look_tw[_pressed] = Motion.press(_pressed, true)
		_busy_for(Motion.PRESS_TIME)
	elif _is_block(cell):
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
	if cell != _last_paint:
		_glance(cell)
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
	# The sweep ticks a little higher per stone it will change, so a long run
	# can be heard growing (Tents' and Shikaku's).
	_sweep_n += 1
	fx.cue("chip" if _lay else "clear", minf(SWEEP_PITCH_MAX, 1.0 + SWEEP_PITCH * (_sweep_n - 1)))

func _release() -> void:
	var cell := _press_cell
	var was_drag := _dragged
	var pending := _pending
	var now := _now()
	_release_press()
	_clear_gesture()
	_glance(Vector2i(-1, -1))
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
			fx.buzz(Haptics.TICK)
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
	# Insane counts moves: a lamp set down or taken up is one, a chip taken
	# up is free, and a tap the budget cannot pay for is not a move.
	var cost := 0
	if max_moves > 0:
		cost = state.move_cost(cell, State.LAMP if state.mark_at(cell) == State.BLANK else State.BLANK)
		if cost > moves_left:
			_end_sinks(now)
			_redraw()
			return
	var before: Dictionary = state.marks.duplicate()
	_by_hand = true
	var arrivals := _commit(before, state.tap(cell), now, 0.0, cell)
	_by_hand = false
	_end_sinks(now, arrivals)
	if state.mark_at(cell) == State.LAMP:
		_judge(cell)
	_spend(cost, now)
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
		# A tap: a lantern set down, one blown out, or a chip taken up. A
		# sweep has already ticked stone by stone.
		if state.mark_at(from) == State.LAMP:
			fx.puff(cell_to_local(from.y, from.x), Pal.SUN)
			_nudge_around(from, t)
			fx.cue("place")
		elif int(before.get(from, State.BLANK)) == State.LAMP:
			fx.cue("strike")
			fx.buzz(Haptics.TICK)
		else:
			fx.cue("clear")
			fx.buzz(Haptics.TICK)
	else:
		_relight(t, _at_once)
	_speak()
	_redraw()
	note_move()
	return arrivals

func _clear_gesture() -> void:
	_press_cell = Vector2i(-1, -1)
	_pressed = null
	_dragged = false
	_lay = true
	_sweep_n = 0
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
			_judged.erase(cell)
		if mark == State.CHIP:
			_chip_arrives(cell, at)
		elif mark == State.LAMP:
			_lamp_up(cell, at - t, drop)
		if prev == State.LAMP or mark == State.LAMP:
			_recount_around(cell, at)
	_refresh_faces()
	_want_flies()
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
	lamp.gutter = 0.0
	Motion.stop(_gag_tw.get(lamp))
	lamp.glasses = 0.0
	lamp.hat = 0.0
	lamp.flare = 0.0
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
		if _is_block(n):
			if not Motion.reduce:
				_block_nudge[n] = {"at": t, "dir": Vector2(d)}
			continue
		var node: Control = _cats.get(n)
		if node == null and state.mark_at(n) == State.LAMP:
			node = _lamps.get(n)
		if node != null:
			if Motion.running(_pos_tw.get(node)):
				continue
			_pos_tw[node] = Motion.nudge(node, Vector2(d), Vector2.ZERO)
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
## pinned lamp or a cat shivers while its stone blushes; the sprout says why.
func _refuse(cell: Vector2i) -> void:
	var line := "LU_REFUSE_PINNED"
	if _is_block(cell):
		line = "LU_REFUSE_BLOCK"
	elif state.is_cat(cell):
		line = "LU_REFUSE_CAT"
	_say(tr(line), Face.Expr.PUZZLED)
	fx.cue("locked")
	var now := _now()
	if _is_block(cell):
		if Motion.reduce:
			return
		_block_shiver[cell] = now
		_block_flash[cell] = now
		_busy_for(maxf(Motion.SHIVER_TIME, Motion.FLASH_IN + Motion.FLASH_OUT))
		return
	_blush_stone(cell)
	var lamp: Control = _cats.get(cell, _lamps.get(cell))
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
	var cross := state.over_cats()
	if cross > 0:
		_say(tr("LU_CAT_OVER_ONE") if cross == 1
			else tr("LU_CAT_OVER_N") % cross, Face.Expr.STRAIN)
		return
	var dark := state.dark()
	if dark > 0:
		_say(tr("LU_DARK_ONE") if dark == 1
			else tr("LU_DARK_N") % dark, Face.Expr.HAPPY)
		return
	var short := 0
	for c: Vector2i in state.cats:
		if state.cat_state(c) == State.CAT_IDLE:
			short += 1
	if short > 0:
		_say(tr("LU_CAT_SHORT_ONE") if short == 1
			else tr("LU_CAT_SHORT_N") % short, Face.Expr.HAPPY)
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
	_tip_idx = (_tip_idx + 1) % _tips().size()
	_say(tr(_tips()[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

## A wrong lamp is going out: the host holds a hint video until it has gone.
func busy() -> bool:
	return _ejecting

func can_undo() -> bool:
	return not is_done() and not out_of_hearts and not _ejecting and not state.history.is_empty()

## Takes back the last gesture, however many stones it swept: the reverse of
## Place, stone by stone along the same path. Counts no move.
func undo() -> bool:
	if not can_undo():
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
	return State.HINTS_BY_BAND[state.band] + hints_extra - hints_used

## Lights one lantern from the answer and pins it for good: a ring pulses out
## of the stone, the lamp drops in from above, sparkles rise, and the light
## travels out from it. Counts no move but can finish the puzzle.
func hint() -> bool:
	if is_done() or out_of_hearts or _ejecting or hints_left() <= 0:
		return false
	var before: Dictionary = state.marks.duplicate()
	var target: Vector2i = state.hint()
	if target.x < 0:
		return false
	var now := _now()
	hints_used += 1
	_judged[target] = true
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
	if is_done() or out_of_hearts or _ejecting:
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
	if is_done() or out_of_hearts or _ejecting:
		return
	_break_streak()
	_clear_court()
	moves = 0
	# A cleared court is the board from the top, so the moves come back too.
	moves_left = max_moves
	_heart_layer.queue_redraw()
	_running = true
	_refresh_faces()
	_say(tr("LU_RESET"),
		Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	_redraw()

## Every lamp and chip goes in Reset's wave from the far corner, the light
## cooling with it and the blocks and cats hopping as the court clears round
## them: Reset's and Try again's shared middle.
func _clear_court() -> void:
	_judged = {}
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
				var cell := Vector2i(x, y)
				if _is_block(cell):
					_block_hop[cell] = {"at": now + _reset_wave(cell), "height": Motion.RESET_HOP,
						"time": Motion.HOP_TIME}
		for cell in _cats:
			_hop(_cats[cell], Motion.RESET_HOP, Motion.HOP_TIME, _reset_wave(cell))
		_busy_for(_reset_wave(Vector2i.ZERO) + Motion.HOP_TIME)
	_relight(now, _reset_wave)
	_blush = {}
	_chip_in = {}
	_block_flash = {}
	_flare = {}
	_block_shiver = {}

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
		lamp.gutter = 0.0
		lamp.expression = Face.Expr.JOY
	_deal()
	_judged = {}
	for cell in _cats:
		var cat: NapCat = _cats[cell]
		cat.position = Vector2.ZERO
		cat.rotation = 0.0
		cat.scale = Vector2.ONE
		cat.expression = _cat_won(cell)
	_refresh_faces(true)
	# The garland stays up, and an Insane court keeps its night seal; a
	# restore cannot know whether the solve was flawless, so a gold seal is
	# not claimed.
	_garland_at = now - 10.0
	_stamp_at = now - 10.0 if _insane() else INF
	_life_layer.queue_redraw()
	_say(tr("LU_WIN"), Face.Expr.JOY)
	_redraw()

func is_solved() -> bool:
	return state.is_solved()

## The court, and the seal's words when one was stamped.
func share_glyphs() -> String:
	var out: String = state.share_glyphs()
	if _insane():
		out += "\n🌙 " + tr("LU_CAT_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless:
		out += "\n🏅 " + tr("BN_FLAWLESS")
	return out

# --- the win ---

## The board is the answer, so the win screen shows no cast: the lit court
## stays on the card under it.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("LU_WIN")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT + PARTY_EXTRA

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
	_glance(Vector2i(-1, -1))
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 or max_moves > 0 else checks == 0)
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = now
		_combo_layer.queue_redraw()
	_smoke = {}
	_snail = {}
	var far := 0
	var k := 0
	for cell in state.lamps():
		far = maxi(far, cell.x + cell.y)
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
				var cell := Vector2i(x, y)
				if _is_block(cell):
					_block_hop[cell] = {"at": now + _solve_delay(cell), "height": Motion.SOLVE_HOP,
						"time": Motion.SOLVE_TIME}
	# The cats hop the wave too, grinning -- all but a napping one, who
	# sleeps through the party.
	for cell in _cats:
		var cat: NapCat = _cats[cell]
		var delay := _solve_delay(cell)
		if state.cat_need(cell) > 0:
			_hop(cat, Motion.SOLVE_HOP, Motion.SOLVE_TIME, delay)
		_after(delay, func() -> void: cat.expression = _cat_won(cell))
	for cell in _cats:
		far = maxi(far, cell.x + cell.y)
	_refresh_faces()
	_say(tr("LU_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_party(_solve_delay(Vector2i(far, 0)))
	_busy_for(maxf(_solve_delay(Vector2i(state.w, state.h)) + maxf(Motion.SOLVE_TIME, WIN_GLINT),
		maxf(CLEAR_DELAY + CLEAR_SPREAD + CLEAR_TIME, Motion.SOLVE_DELAY + WARM_TIME)))
	_redraw()

## A cat's look on a solved court: JOY, or asleep for a napping cat.
func _cat_won(cell: Vector2i) -> int:
	return Face.Expr.SLEEPY if state.cat_need(cell) == 0 else Face.Expr.JOY

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

# --- judging a lamp ---

## A lamp just set down by a tap. On Hard and Insane a lamp the board cannot
## fault (`state.lamp_fair`) that is not the answer's costs a heart -- the
## answer is unique, so it is wrong by proof. A lamp the board already shows
## as wrong (a rose beam, a rose block, a cross cat) costs nothing: the board
## has said so. Anything else the board cannot fault is right: the answer's
## on a board with hearts, where it joins `_judged`, or any fair lamp on Easy
## and Medium, which says no more than its face does.
func _judge(cell: Vector2i) -> void:
	# The winning tap: the solve wave owns every hop and spark from here.
	if is_done():
		return
	var fair: bool = state.lamp_fair(cell)
	if max_hearts > 0 and fair and not state.is_answer(cell):
		_wrong_lamp(cell)
		return
	if not fair:
		_break_streak()
		return
	if max_hearts > 0:
		_judged[cell] = true
		_refresh_faces()
		_redraw()
	_on_right_lamp(cell)

## A lamp judged right -- on Hard and Insane fair and the answer's (it is in
## `_judged` already), on Easy and Medium simply fair. It builds the streak
## (the combo pitched up the pentatonic from the second, the bubble from the
## third, confetti at five and ten) and may play a gag. On a board with hearts
## its candle flares and a moth comes to circle it: only there has the board
## judged it, so only there may the light say "right".
func _on_right_lamp(cell: Vector2i) -> void:
	_streak += 1
	if _streak >= 2:
		var step: int = COMBO_STEPS[mini(_streak - 2, COMBO_STEPS.size() - 1)]
		fx.cue("combo", pow(2.0, step / 12.0), COMBO_DB)
	if _streak >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = _streak
		_combo_cell = cell
		_combo_at = _now()
		_combo_out_at = -INF
		_combo_layer.queue_redraw()
	if COMBO_CONFETTI.has(_streak) and not Motion.reduce:
		fx.confetti(cell_to_local(cell.y, cell.x), 22)
		fx.cue("confetti")
	if max_hearts > 0:
		_flare_lamp(cell)
		_want_flies(cell)
	_gag(cell)

## The streak ends: a lamp in trouble, a wrong lamp, a reset, a deal, the
## hearts running out. The bubble deflates.
func _break_streak() -> void:
	_streak = 0
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
		if _combo_layer != null:
			_combo_layer.queue_redraw()
	else:
		_combo_n = 0

## A right lamp's candle flares: its halo swells and settles (a transform on
## its glow), and the wick's warm disc blooms on the floor again under it.
func _flare_lamp(cell: Vector2i) -> void:
	if Motion.reduce:
		return
	var lamp: CourtLantern = _lamps.get(cell)
	if lamp == null:
		return
	var tw := lamp.create_tween()
	tw.tween_property(lamp, "flare", 1.0, FLARE_UP).from(0.0).set_delay(Motion.POP_IN * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(lamp, "flare", 0.0, FLARE_DOWN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flare_at(cell, _now() + Motion.POP_IN * 0.5)
	_after(Motion.POP_IN * 0.5, fx.sparkle.bind(cell_to_local(cell.y, cell.x) - Vector2(0.0, _cell * 0.3), Pal.SUN_RAY))

## `cost` moves go off Insane's counter. The last one gone with the court
## unfinished ends the board once the lamp has landed (`land`).
func _spend(cost: int, land: float) -> void:
	if max_moves <= 0 or cost <= 0:
		return
	moves_left = maxi(0, moves_left - cost)
	_moves_pill.bump(_now())
	_heart_layer.queue_redraw()
	if moves_left > 0 or is_done() or state.is_solved():
		return
	_lost_ever = true
	out_of_hearts = true
	_running = false
	_after(maxf(0.0, land - _now()) + (0.0 if Motion.reduce else Motion.DROP_TIME), _run_out)

## A wrong lamp: a heart goes (its halves fall), the lamp worries and sags,
## its flame gutters while its light draws back along the beam toward it,
## its stone blushes, and after EJECT_AFTER it is taken up as though never
## set down.
func _wrong_lamp(cell: Vector2i) -> void:
	if out_of_hearts or hearts <= 0:
		return
	var now := _now()
	hearts -= 1
	_lost_ever = true
	_break_streak()
	_split_index = hearts
	_split_at = now
	_heart_layer.queue_redraw()
	_ejecting = true
	if hearts <= 0:
		# Input stops now; the dusk waits for the lamp to go.
		out_of_hearts = true
		_running = false
	var lamp: CourtLantern = _lamp_node(cell)
	lamp.expression = Face.Expr.WORRIED
	_guttering[cell] = {"at": now, "reach": _reach(cell)}
	# The light is let land first; the floor is sent dark from GUTTER_FROM
	# (the beam reads `_guttering` from now and fades on the same clock).
	_after(GUTTER_FROM, func() -> void:
		if _guttering.has(cell):
			_relight(_now(), _draw_back(cell), GUTTER_OUT))
	if not Motion.reduce:
		_after(WILT_LAG, func() -> void:
			Motion.stop(_look_tw.get(lamp))
			lamp.scale = Vector2.ONE
			_look_tw[lamp] = Motion.squash(lamp, 0.14, 0.2))
		var tw := lamp.create_tween()
		tw.tween_property(lamp, "gutter", 1.0, EJECT_AFTER).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		lamp.gutter = 1.0
	_blush_stone(cell)
	_say(tr("LU_WRONG_LAMP"), Face.Expr.WORRIED)
	fx.cue("heart_lost")
	_busy_for(EJECT_AFTER + Motion.POP_OUT)
	moved.emit()
	_after(EJECT_AFTER, _eject.bind(cell))

## The wrong lamp is taken up: its tap is taken back with no history left of
## it, and a grey puff goes up where it stood.
func _eject(cell: Vector2i) -> void:
	_ejecting = false
	_guttering.erase(cell)
	# Left mid-gutter through the card or the host: the board is over.
	if is_done():
		return
	var before: Dictionary = state.marks.duplicate()
	var last: Array = [] if state.history.is_empty() else state.history.back()
	if last.size() == 1 and last[0].cell == cell:
		state.undo()
	elif state.mark_at(cell) == State.LAMP and not state.locked.has(cell):
		state.marks.erase(cell)
		state.recompute()
	var now := _now()
	_transition(before, [cell], now, 0.0)
	_relight(now, _at_once)
	if not Motion.reduce:
		fx.puff(cell_to_local(cell.y, cell.x), Pal.FLAGSTONE.lerp(Pal.LINE, 0.5), 6)
	# The candle blown out: heart_lost has said what it cost, this is it going.
	fx.cue("strike", 1.0, -5.0)
	if not out_of_hearts:
		_speak()
	moved.emit()
	_redraw()
	if out_of_hearts:
		_run_out()

## The last heart is gone: the court slips to dusk, the lanterns and cats nod
## off along the diagonal, and the card comes up once they have.
func _run_out() -> void:
	if _asleep:
		return
	_asleep = true
	_clear_gesture()
	_break_streak()
	fx.cue("out_of_hearts")
	_say(tr("LU_OUT"), Face.Expr.SLEEPY)
	_dusk_toward(1.0)
	_nod_all()
	for f in _flies:
		f.leave = true
	_life_layer.queue_redraw()
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

## Every lamp and cat takes its look along the diagonal: asleep, or awake
## again after a heart came back.
func _nod_all() -> void:
	for cell in _lamps:
		_after(Motion.stagger(cell.x + cell.y, SLEEP_STAGGER), func() -> void:
			if _solved_at == NEVER and state.mark_at(cell) == State.LAMP and not _guttering.has(cell):
				_lamps[cell].expression = _lamp_expr(cell))
	for cell in _cats:
		_after(Motion.stagger(cell.x + cell.y, SLEEP_STAGGER), func() -> void:
			if _solved_at == NEVER:
				_cats[cell].expression = _cat_expr(cell))

## The card, over the whole screen: laid on the host so it covers the chrome,
## or on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, [], MOVES_BONUS) if max_moves > 0 \
		else load(OUT_OF_HEARTS).new(_heart_used, ["LU_OUT_BODY", "LU_OUT_REST"] if state.has_cats() else ["LU_OUT_BODY_LAMPS", "LU_OUT_REST_LAMPS"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same court from the top, every heart back, the day's light,
## the clock and the moves from zero; hints spent stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	moves = 0
	elapsed = 0.0
	checks = 0
	_running = true
	_clear_court()
	var dusk := _dusk(_now())
	_deal()
	# _deal() put the day back at once; hold the dusk so _dusk_toward fades it.
	_dusk_from = dusk
	_dusk_to = dusk
	_dusk_toward(0.0)
	_nod_all()
	_refresh_faces(true)
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	moved.emit()
	_redraw()

## One more heart (the card's video): once a board. The court's light comes
## back and it wakes along the diagonal.
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
	_heart_layer.queue_redraw()
	out_of_hearts = false
	_asleep = false
	_running = true
	fx.cue("heart_back")
	_dusk_toward(0.0)
	_nod_all()
	_speak()
	moved.emit()

## Back from the card: the board ends unsolved first, so the host logs
## puzzle_complete {solved: false} and not an abandon.
func _leave() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

# --- the hearts ---

## The hearts over the court as one mesh on a paper pill, Shikaku's, Tents'
## and Binairo's: pink with a small face and a leaf, a faint ghost where one
## was, the lost one's halves falling apart, and one coming back popping in.
func _draw_hearts() -> void:
	if max_moves > 0 and _cell > 0.0:
		_moves_pill.draw(_heart_layer, Vector2(size.x * 0.5, _grid.y - MORTAR - HEART_ROW * 0.5 - 4.0),
			moves_left, _now())
		return
	if max_hearts <= 0 or _cell <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var y := _grid.y - MORTAR - HEART_ROW * 0.5 - 4.0
	var x0 := size.x * 0.5 - step * (max_hearts - 1) * 0.5
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var corner := Vector2(size.x * 0.5, y) - pill * 0.5
	var rim := Vector2.ONE * HEART_PILL_RIM
	b.polygon(Face.Builder.round_rect(corner - rim, pill + 2.0 * rim, pill.y * 0.5 + HEART_PILL_RIM), Pal.LINE)
	b.polygon(Face.Builder.round_rect(corner, pill, pill.y * 0.5), Pal.SURFACE)
	for i in max_hearts:
		var at := Vector2(x0 + step * i, y)
		if i < hearts:
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
	_heart_layer.draw_mesh(_hearts_shown, null)

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

## The streak's paper bubble at the upper right of its lamp, "x3" and up in
## ink: it pops in the first time, bumps at each step and deflates when the
## streak ends. One mesh for the paper and one string (Binairo's, Tents').
func _draw_combo() -> void:
	if _combo_n < COMBO_FROM or _cell <= 0.0:
		return
	var now := _now()
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
	var centre_cell := cell_to_local(_combo_cell.y, _combo_cell.x)
	var tail := centre_cell + Vector2(_cell * 0.25, -_cell * 0.3)
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

# --- gags, glances and the life on the court ---

## A right lamp now and then plays a gag, picked by the stone's own hash so a
## court replays the same: the lantern slides on sunglasses, it puffs a small
## heart of smoke off its cap, or a snail with a tiny lantern of her own
## slides past in front of it. Under reduce-motion, none.
func _gag(cell: Vector2i) -> void:
	if Motion.reduce or is_done():
		return
	var roll := posmod(hash(cell * 13 + Vector2i(7, 3)), GAG_ODDS)
	if roll >= GAGS:
		return
	var now := _now()
	match roll:
		0:
			var lamp: CourtLantern = _lamp_node(cell)
			Motion.stop(_gag_tw.get(lamp))
			var tw := lamp.create_tween()
			tw.tween_property(lamp, "glasses", 1.0, GLASSES_IN).from(0.0).set_delay(GAG_AT) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(GLASSES_HOLD)
			tw.tween_property(lamp, "glasses", 0.0, GLASSES_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			_gag_tw[lamp] = tw
			_after(GAG_AT, func() -> void: fx.cue("cool"))
		1:
			_smoke = {"cell": cell, "at": now + GAG_AT}
			_after(GAG_AT, func() -> void: fx.cue("puff"))
			_life_layer.queue_redraw()
		2:
			_snail = {"cell": cell, "at": now + GAG_AT, "dir": 1.0 if posmod(cell.x + cell.y, 2) == 0 else -1.0}
			_snail_face()
			_after(GAG_AT, func() -> void: fx.cue("snail"))

## The lanterns and cats within GLANCE_REACH of `cell` look at it; (-1, -1)
## and every one looks ahead again. One on the stone itself looks up.
func _glance(cell: Vector2i) -> void:
	var faces: Dictionary = {}
	for at in _lamps:
		if _lamps[at].visible and state.mark_at(at) == State.LAMP:
			faces[at] = _lamps[at]
	for at in _cats:
		faces[at] = _cats[at]
	for at in faces:
		var face: Face = faces[at]
		var look := Vector2.ZERO
		if cell.x >= 0 and not Motion.reduce:
			var d := Vector2(cell - at)
			if maxf(absf(d.x), absf(d.y)) <= GLANCE_REACH:
				look = d.normalized() if d != Vector2.ZERO else Vector2(0.0, -1.0)
		if face.look != look:
			face.look = look

## The snail, made the first time a gag wants her and kept: the One Line
## walker (ui/faces/snail_face.gd) with a court lantern of her own, lit,
## riding on her shell. She lives on the life layer, over the lamps, and
## crossing a stone is her transform, never a rebuild.
func _snail_face() -> Control:
	if _snail_node != null:
		return _snail_node
	var snail := SnailFace.new()
	snail.name = "Snail"
	snail.visible = false
	var lamp := CourtLantern.new()
	lamp.name = "lamp"
	lamp.casts = false
	lamp.lit = 1.0
	lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	snail.add_child(lamp)
	_life_layer.add_child(snail)
	snail.set_idle(true)
	lamp.set_idle(true)
	_snail_node = snail
	return snail

## Where the snail is on her way across the stone, `e` seconds in: sliding
## from one side of the stone's front to the other with a slow bob, fading in
## and out at the ends, turned the way she goes.
func _place_snail(now: float) -> void:
	if _snail_node == null:
		return
	if _snail.is_empty():
		_snail_node.visible = false
		return
	var e := now - float(_snail.at)
	var snail := _snail_node
	if e > SNAIL_TIME or state.mark_at(_snail.cell) != State.LAMP:
		_snail = {}
		snail.visible = false
		return
	if e < 0.0:
		return
	var px := SNAIL_SIZE * _cell * SnailFace.SEAT / 1.84
	var sr := px * SnailFace.RATIO
	if snail.size.x != px:
		snail.size = Vector2.ONE * px
		var lamp: Control = snail.get_node("lamp")
		var lr := sr * 0.42
		lamp.size = Vector2.ONE * lr * CourtLantern.SEAT
		lamp.position = snail.size * 0.5 + Vector2(-0.26 * sr, -0.8 * sr - 1.02 * lr) - lamp.size * 0.5
	var cell: Vector2i = _snail.cell
	var dir: float = _snail.dir
	var u := e / SNAIL_TIME
	var centre := cell_to_local(cell.y, cell.x)
	var at := Vector2(centre.x + dir * lerpf(-SNAIL_REACH, SNAIL_REACH, u) * _cell,
		centre.y + _cell * 0.36 - absf(sin(u * PI * 5.0)) * _cell * 0.012)
	snail.visible = true
	snail.position = at - snail.size * 0.5
	snail.scale = Vector2(dir, 1.0)
	snail.modulate.a = clampf(minf(u, 1.0 - u) * 7.0, 0.0, 1.0)

## Where moths may go: every lamp still standing that a tap was judged right
## on, burning and fair; once the court is solved, every lamp.
func _perches() -> Array:
	var out: Array = []
	if _asleep:
		return out
	for at in _lamps:
		if state.mark_at(at) != State.LAMP or not _lamps[at].visible or _guttering.has(at):
			continue
		if _solved_at > NEVER or (_judged.has(at) and state.lamp_fair(at)):
			out.append(at)
	return out

## Moths come to a court with judged lamps, on Hard and Insane only: one from
## the first, a second past MOTH_SECOND of the answer's lamps, none under
## reduce-motion. `fresh`, a lamp just judged right, gets a moth of its own
## -- a new one, or the one that has circled its lamp longest. One too many
## flies off.
func _want_flies(fresh := Vector2i(-1, -1)) -> void:
	if Motion.reduce or _cell <= 0.0 or _asleep or _solved_at > NEVER or max_hearts <= 0:
		return
	var judged := _perches().size()
	var want := 0
	if judged > 0:
		want = 1
		if float(judged) / maxf(1.0, state.solution.size()) >= MOTH_SECOND:
			want = 2
	var staying: Array = []
	for f in _flies:
		if not f.leave:
			staying.append(f)
	var arrived := false
	while staying.size() < want:
		staying.append(_spawn_fly(_flies.size(), fresh))
		arrived = true
	while staying.size() > want:
		staying.pop_back().leave = true
	if fresh.x >= 0 and not arrived and not staying.is_empty():
		var pick: Dictionary = staying[0]
		for f in staying:
			if float(f.since) < float(pick.since):
				pick = f
		_send(pick, fresh)
	if arrived:
		fx.cue("moth")

## A moth flying in from off the card's nearer side toward `to`'s lamp.
func _spawn_fly(k: int, to := Vector2i(-1, -1)) -> Dictionary:
	var from_left := k % 2 == 0
	var start := Vector2(-40.0 if from_left else size.x + 40.0, _grid.y + _cell * state.h * (0.2 + 0.25 * (k % 3)))
	var f := {"pos": start, "cell": to, "since": _now(), "until": -1.0, "angle": k * 2.1,
		"wing": (k + posmod(hash(start), 7)) % MOTH_WINGS.size(), "phase": k * 1.7, "leave": false}
	_flies.append(f)
	_life_layer.queue_redraw()
	return f

## `f` goes to circle the lamp on `cell`.
func _send(f: Dictionary, cell: Vector2i) -> void:
	f.cell = cell
	f.since = _now()
	f.until = -1.0

## Moves every moth `dt` along: toward a point going round its lamp, so it
## flutters in and then circles; after a while on to another lamp. A leaving
## one flies off the top and is gone.
func _fly(dt: float) -> void:
	var now := _now()
	var perches := _perches()
	var speed := MOTH_SPEED * _cell
	var keep: Array = []
	for f in _flies:
		if not f.leave and not perches.has(f.cell):
			if perches.is_empty():
				f.leave = true
			else:
				_send(f, perches[posmod(hash(Vector2i(int(now * 10.0), int(f.phase * 10.0))), perches.size())])
		var to: Vector2
		if f.leave:
			to = Vector2(f.pos.x + (1.0 if f.pos.x > size.x * 0.5 else -1.0) * 60.0, -80.0)
		else:
			f.angle += MOTH_TURN * dt * (1.0 if int(f.wing) % 2 == 0 else -1.0)
			var c: Vector2 = cell_to_local(f.cell.y, f.cell.x) - Vector2(0.0, MOTH_LIFT * _cell)
			to = c + Vector2(cos(f.angle) * MOTH_ORBIT.x, sin(f.angle) * MOTH_ORBIT.y) * _cell
			if f.pos.distance_to(to) < _cell * 0.25:
				if f.until < 0.0:
					f.until = now + MOTH_STAY + fposmod(f.phase * 3.1, 1.0) * MOTH_JITTER
				elif now >= f.until and perches.size() > 1:
					var i := posmod(hash(Vector2i(int(now * 10.0), int(f.phase * 10.0))), perches.size())
					if perches[i] == f.cell:
						i = (i + 1) % perches.size()
					_send(f, perches[i])
		var d: Vector2 = to - f.pos
		if d.length() > 0.5:
			f.pos += d.normalized() * minf(d.length(), speed * dt)
		if f.leave and f.pos.y < -60.0:
			continue
		keep.append(f)
	_flies = keep

## Forgets whatever on the life layer has finished. Returns whether anything
## on it is still moving.
func _tick_life(now: float) -> bool:
	var still: Array = []
	for p in _purrs:
		if now < float(p.t) + PURR_TIME:
			still.append(p)
	_purrs = still
	still = []
	for s in _sky:
		if now < float(s.t) + SKY_TIME:
			still.append(s)
	_sky = still
	if not _smoke.is_empty() and now > float(_smoke.at) + SMOKE_TIME:
		_smoke = {}
	_place_snail(now)
	return not _flies.is_empty() or not _purrs.is_empty() or not _sky.is_empty() \
		or not _smoke.is_empty() or not _snail.is_empty() \
		or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1) \
		or (now >= _garland_at and now - _garland_at < GARLAND_SETTLE + 0.1 and not Motion.reduce)

## The life on the court, over the pieces: the garland, the sky lanterns
## going up, the smoke heart, a cat's purring hearts and the moths, each a
## mesh built once and drawn under its own transform (the garland is rebuilt
## only while it swings); and the seal after the solve, with its words.
func _draw_life() -> void:
	if _cell <= 0.0:
		_life_shown = []
		return
	var now := _now()
	var shown: Array = []
	if now >= _garland_at:
		_draw_garland(now - _garland_at, shown)
	if not _sky.is_empty():
		var mesh := _sky_lantern()
		shown.append(mesh)
		for s in _sky:
			var e: float = now - float(s.t)
			if e <= 0.0:
				continue
			var u := e / SKY_TIME
			var from := cell_to_local(s.cell.y, s.cell.x) - Vector2(0.0, _cell * 0.2)
			var top := _card.position.y - SKY_RISE * _cell
			var sway := sin(e * 2.2 + float(s.phase)) * SKY_SWAY * _cell * minf(1.0, u * 3.0)
			var at := Vector2(from.x + sway, lerpf(from.y, top, pow(u, 1.3)))
			var grow := lerpf(0.5, 1.0, Motion.back_out(minf(1.0, u * 6.0))) * lerpf(1.0, 0.82, u)
			var alpha := minf(1.0, u * 12.0) * clampf((1.0 - u) / SKY_FADE, 0.0, 1.0)
			_life_layer.draw_mesh(mesh, null, Transform2D(cos(e * 2.2 + float(s.phase)) * 0.07,
				Vector2(grow, grow), 0.0, at), Color(1.0, 1.0, 1.0, alpha))
	if not _smoke.is_empty():
		var e: float = now - float(_smoke.at)
		if e > 0.0:
			var u := e / SMOKE_TIME
			var rise := 1.0 - (1.0 - u) * (1.0 - u)
			var cell: Vector2i = _smoke.cell
			var at := cell_to_local(cell.y, cell.x) + Vector2(sin(u * TAU) * SMOKE_SWAY * _cell,
				-_cell * (0.5 + SMOKE_RISE * rise))
			var k := lerpf(SMOKE_FROM, 1.0, rise)
			var mesh := _smoke_heart()
			shown.append(mesh)
			_life_layer.draw_mesh(mesh, null, Transform2D(sin(u * TAU) * 0.12, Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, minf(1.0, u * 8.0) * pow(1.0 - u, 1.4)))
	if not _purrs.is_empty():
		var mesh := _purr_heart()
		shown.append(mesh)
		for p in _purrs:
			var e: float = now - float(p.t)
			if e <= 0.0:
				continue
			var u := e / PURR_TIME
			var at: Vector2 = p.at + Vector2(sin(u * TAU + int(p.k)) * 0.05 * _cell, -PURR_RISE * _cell * (1.0 - (1.0 - u) * (1.0 - u)))
			var k := Motion.pop_in_scale(e, 0.2).x
			_life_layer.draw_mesh(mesh, null, Transform2D(sin(u * TAU) * 0.15, Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.4, 0.0, 1.0)))
	# Every moth in one mesh, its cached wings copied natively under its
	# transform (checkup 2026-10-01: a draw call a moth before).
	if not _flies.is_empty():
		var fb := Face.FlatBuilder.new(_moth_flat)
		for f in _flies:
			var circling: bool = not f.leave and f.until >= 0.0
			var beat: float = absf(sin(now * (9.0 if circling else 15.0) + f.phase))
			var level := roundi(beat * (MOTH_LEVELS - 1))
			var bob := Vector2(0.0, sin(now * 6.0 + f.phase) * _cell * 0.03)
			fb.append(_moth(int(f.wing), level), Transform2D(sin(now * 3.0 + f.phase) * 0.18, f.pos + bob))
		var moths := fb.mesh()
		if moths != null:
			shown.append(moths)
			_life_layer.draw_mesh(moths, null)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_life_shown = shown

## A moth, `wing` its tint and `level` of MOTH_LEVELS how far its wings are
## open: soft pale wings with a dusty spot and a deeper rim, a fluffy body, a
## ruff at its neck, two dots of eyes and a pair of feathery antennae. Built
## once per tint and opening.
func _moth(wing: int, level: int) -> ArrayMesh:
	var key := wing * 16 + level
	if _moth_meshes.has(key):
		return _moth_meshes[key]
	var b := Face.Builder.new()
	var s := _cell * MOTH_SIZE
	var open := lerpf(0.3, 1.0, float(level) / float(MOTH_LEVELS - 1))
	var col: Color = MOTH_WINGS[wing]
	var rim := col.lerp(MOTH_BODY.darkened(0.25), 0.75)
	for sx: float in [-1.0, 1.0]:
		var w_ := s * open
		b.ellipse(Vector2(sx * w_ * 0.4, s * 0.3), w_ * 0.5 + 1.5, s * 0.36 + 1.5, rim)
		b.ellipse(Vector2(sx * w_ * 0.4, s * 0.3), w_ * 0.5, s * 0.36, col.darkened(0.04))
		b.ellipse(Vector2(sx * w_ * 0.62, -s * 0.12), w_ * 0.7 + 1.5, s * 0.5 + 1.5, rim)
		b.ellipse(Vector2(sx * w_ * 0.62, -s * 0.12), w_ * 0.7, s * 0.5, col)
		b.ellipse(Vector2(sx * w_ * 0.78, -s * 0.18), w_ * 0.18, s * 0.16, Color(MOTH_BODY, 0.5))
		b.ellipse(Vector2(sx * w_ * 0.42, -s * 0.34), w_ * 0.26, s * 0.12, Color(1.0, 1.0, 1.0, 0.45))
	b.ellipse(Vector2(0.0, s * 0.12), s * 0.2, s * 0.5, MOTH_BODY)
	for k in 2:
		b.stroke(PackedVector2Array([Vector2(-s * 0.16, s * (0.18 + 0.18 * k)), Vector2(s * 0.16, s * (0.18 + 0.18 * k))]),
			maxf(1.0, s * 0.05), MOTH_BODY.darkened(0.18))
	b.disc(Vector2(0.0, -s * 0.34), s * 0.27, MOTH_BODY.lightened(0.35))
	for sx: float in [-1.0, 1.0]:
		b.disc(Vector2(sx * s * 0.1, -s * 0.38), maxf(1.2, s * 0.055), Pal.OUTLINE)
		var foot := Vector2(sx * s * 0.08, -s * 0.56)
		var tip := Vector2(sx * s * 0.42, -s * 0.9)
		var arc := Face.Builder.bezier2(foot, Vector2(sx * s * 0.12, -s * 0.9), tip, 8)
		arc.append(tip)
		b.stroke(arc, maxf(1.2, s * 0.06), MOTH_BODY.darkened(0.3))
		b.ellipse(tip, s * 0.1, s * 0.07, MOTH_BODY.darkened(0.15))
	var mesh := b.mesh()
	_moth_meshes[key] = mesh
	return mesh

## The heart of smoke a lantern puffs: a soft ring in the shape of a heart,
## a wide faint stroke under a narrower pale one.
func _smoke_heart() -> ArrayMesh:
	if _smoke_mesh != null:
		return _smoke_mesh
	var b := Face.Builder.new()
	var s := SMOKE_R * _cell
	var pts := _heart(Vector2(0.0, 0.0), s, 0)
	b.stroke(pts, s * 0.4, Color(Pal.SHADOW_TINT, 0.45), true)
	b.stroke(pts, s * 0.2, Color(Pal.SURFACE, 0.95), true)
	_smoke_mesh = b.mesh()
	return _smoke_mesh

## A purring cat's little heart: the hearts' pink with a shine.
func _purr_heart() -> ArrayMesh:
	if _purr_mesh != null:
		return _purr_mesh
	var b := Face.Builder.new()
	var s := PURR_R * _cell
	b.polygon(_heart(Vector2.ZERO, s * 1.14, 0), Pal.SURFACE)
	b.polygon(_heart(Vector2.ZERO, s, 0), Pal.FLOWER)
	b.ellipse(Vector2(-0.45, -0.5) * s, 0.2 * s, 0.13 * s, Color(1.0, 1.0, 1.0, 0.6))
	_purr_mesh = b.mesh()
	return _purr_mesh

## A paper sky lantern, SKY_SIZE cells tall about its middle: a soft glow
## round it, a paper body wider at the top with its ribs and a shaded side,
## a cap, and the flame showing warm through the open foot.
func _sky_lantern() -> ArrayMesh:
	if _sky_mesh != null:
		return _sky_mesh
	var b := Face.Builder.new()
	var s := SKY_SIZE * _cell
	Scenery.soft_disc(b, Vector2(0.0, s * 0.05), s * 0.95, s * 0.95, Color(Pal.SUN_RAY, 0.42))
	var paper: Color = (Pal.LANTERN_PAPER[0][0] as Color).lerp(Pal.LANTERN_LIT, 0.55)
	var deep: Color = Pal.LANTERN_PAPER[0][1]
	var body := PackedVector2Array([Vector2(-0.34, -0.46) * s, Vector2(0.34, -0.46) * s,
		Vector2(0.25, 0.4) * s, Vector2(-0.25, 0.4) * s])
	var rim := PackedVector2Array()
	for p in body:
		rim.append(p * 1.08 + Vector2(0.0, 0.01 * s))
	b.fan(rim, deep)
	b.fan(body, paper)
	# The shaded right side and the ribs.
	b.fan(PackedVector2Array([Vector2(0.14, -0.46) * s, Vector2(0.34, -0.46) * s,
		Vector2(0.25, 0.4) * s, Vector2(0.1, 0.4) * s]), Color(deep, 0.35))
	for x in [-0.12, 0.12]:
		b.stroke(PackedVector2Array([Vector2(x * 1.3, -0.44) * s, Vector2(x, 0.38) * s]),
			maxf(1.0, s * 0.03), Color(deep, 0.4))
	b.fan(Face.Builder.round_rect(Vector2(-0.3, -0.5) * s, Vector2(0.6, 0.1) * s, 0.04 * s), deep)
	# The glow from inside, strongest low where the flame is.
	b.ellipse(Vector2(0.0, 0.14) * s, 0.2 * s, 0.24 * s, Color(Pal.LANTERN_LIT, 0.8))
	b.ellipse(Vector2(0.0, 0.41) * s, 0.25 * s, 0.06 * s, Color(deep.darkened(0.2), 1.0))
	b.ellipse(Vector2(0.0, 0.4) * s, 0.09 * s, 0.05 * s, Pal.SUN_RAY)
	b.ellipse(Vector2(-0.18, -0.25) * s, 0.06 * s, 0.14 * s, Color(1.0, 1.0, 1.0, 0.35))
	_sky_mesh = b.mesh()
	return _sky_mesh

## The party's garland: small round paper lanterns on a string across the top
## of the court, `e` seconds after it began to drop in, swinging to rest. It
## is rebuilt while it swings and kept once it has come to rest.
func _draw_garland(e: float, shown: Array) -> void:
	var still := Motion.reduce or e >= GARLAND_SETTLE
	if still and _garland_mesh != null:
		shown.append(_garland_mesh)
		_life_layer.draw_mesh(_garland_mesh, null)
		return
	var b := Face.Builder.new()
	_build_garland(b, GARLAND_SETTLE if still else e)
	var mesh := b.mesh()
	if still:
		_garland_mesh = mesh
	shown.append(mesh)
	_life_layer.draw_mesh(mesh, null)

func _build_garland(b, e: float) -> void:
	var field := Rect2(_grid, Vector2(_cell * state.w, _cell * state.h))
	var left := field.position + Vector2(-_cell * 0.12, -_cell * 0.1)
	var right := Vector2(field.end.x + _cell * 0.12, left.y)
	var drop := 1.0 if Motion.reduce else Motion.back_out(clampf(e / GARLAND_TIME, 0.0, 1.0))
	var sag := _cell * GARLAND_SAG * drop
	var calm := 0.0 if Motion.reduce else maxf(0.0, 1.0 - e / GARLAND_SETTLE)
	var swing := sin(e * 4.0) * 0.22 * calm * calm
	var pts := PackedVector2Array()
	const STEPS := 28
	for i in STEPS + 1:
		var u := float(i) / STEPS
		pts.append(left.lerp(right, u) + Vector2(0.0, sag * 4.0 * u * (1.0 - u)))
	b.stroke(pts, maxf(2.0, _cell * 0.025), Pal.CORD_DEEP)
	for p in [left, right]:
		b.disc(p, _cell * 0.04, Pal.CORD_DEEP)
	var n := maxi(5, int(field.size.x / (_cell * GARLAND_EVERY)))
	var s := _cell * GARLAND_SIZE
	for k in n:
		var u := (k + 0.5) / n
		var p := left.lerp(right, u) + Vector2(0.0, sag * 4.0 * u * (1.0 - u))
		var turn := swing * (1.0 if k % 2 == 0 else -0.8) * (0.6 + 0.4 * sin(k * 1.7))
		var xf := Transform2D(turn, Vector2(drop, drop), 0.0, p)
		var paper: Array = Pal.LANTERN_PAPER[(k * 2) % Pal.LANTERN_PAPER.size()]
		var skin: Color = (paper[0] as Color).lerp(Pal.LANTERN_LIT, 0.3)
		var edge: Color = paper[1]
		var mid := Vector2(0.0, 0.62 * s)
		_shape(b, xf, PackedVector2Array([Vector2(-0.02 * s, 0.0), Vector2(0.02 * s, 0.0),
			Vector2(0.02 * s, 0.2 * s), Vector2(-0.02 * s, 0.2 * s)]), Pal.CORD_DEEP)
		_shape(b, xf, Face.Builder.ring(mid + Vector2(0.0, 0.03 * s), 0.42 * s, 0.4 * s), edge)
		_shape(b, xf, Face.Builder.ring(mid, 0.42 * s, 0.37 * s), skin)
		_shape(b, xf, Face.Builder.ring(mid + Vector2(0.0, 0.04 * s), 0.18 * s, 0.2 * s), Color(Pal.LANTERN_LIT, 0.85))
		for sx: float in [-1.0, 1.0]:
			var rib := PackedVector2Array()
			for j in 7:
				var a := lerpf(-1.2, 1.2, j / 6.0)
				rib.append(xf * (mid + Vector2(sx * 0.22 * s * cos(a * 0.9), 0.37 * s * sin(a))))
			b.stroke(rib, maxf(1.0, s * 0.04), Color(edge, 0.55))
		_shape(b, xf, Face.Builder.round_rect(Vector2(-0.17, 0.17) * s, Vector2(0.34, 0.1) * s, 0.04 * s), Pal.LANTERN)
		_shape(b, xf, Face.Builder.round_rect(Vector2(-0.14, 0.99) * s, Vector2(0.28, 0.09) * s, 0.04 * s), Pal.LANTERN)
		_shape(b, xf, Face.Builder.ring(mid + Vector2(-0.18, -0.14) * s, 0.07 * s, 0.1 * s), Color(1.0, 1.0, 1.0, 0.4))

## After the solve wave (`lead` from now): the seal, when the solve earned
## one (flawless, or any Insane court), stamps onto the court's lower right;
## hats pop onto every lantern and cat along the diagonal, the garland drops
## in across the top, confetti sweeps the court, the moths come out, and every
## lamp lets a paper sky lantern go. Under reduce-motion the seal and the
## garland stand still and there is no more.
func _party(lead: float) -> void:
	var now := _now()
	if _flawless or _insane():
		_stamp_at = now if Motion.reduce else now + lead + CLEAR_TIME + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
	_garland_at = now if Motion.reduce else now + lead + PARTY_AT
	_garland_mesh = null
	_after(_garland_at - now, func() -> void: _life_layer.queue_redraw())
	if Motion.reduce:
		return
	var at := lead + PARTY_AT
	var faces: Array = []
	for cell in state.lamps():
		faces.append([cell, _lamp_node(cell)])
	for cell in _cats:
		faces.append([cell, _cats[cell]])
	for pair in faces:
		var cell: Vector2i = pair[0]
		var face: Face = pair[1]
		face.hat_style = posmod(hash(cell), 7)
		var tw: Tween = face.create_tween()
		tw.tween_property(face, "hat", 1.0, PARTY_HAT).from(0.0) \
			.set_delay(at + Motion.stagger(cell.x + cell.y, PARTY_HAT_STAGGER)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_gag_tw[face] = tw
	_after(at, func() -> void:
		var field := Rect2(_grid, Vector2(_cell * state.w, _cell * state.h))
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell), 30, field.size.x * 0.8)
		fx.cue("party")
		for k in MOTH_PARTY:
			_spawn_fly(_flies.size() + k))
	_after(at + 0.45, func() -> void:
		var field := Rect2(_grid, Vector2(_cell * state.w, _cell * state.h))
		fx.confetti(field.get_center(), 24, field.size.x * 0.6))
	var sky := at + PARTY_HAT + SKY_AT
	for cell in state.lamps():
		_sky.append({"cell": cell, "t": now + sky + Motion.stagger(cell.x + cell.y, SKY_STAGGER),
			"phase": _hash(cell) * TAU})
	_after(sky, func() -> void: fx.cue("lanterns"))
	# The moths stay for the win screen's first look and then fly off, so the
	# solved court goes quiet instead of redrawing for ever.
	_after(at + FLIES_STAY, func() -> void:
		for f in _flies:
			f.leave = true)
	_anim_until = maxf(_anim_until, now + at + PARTY_HAT + 1.0)

## An Insane court: Cat Naps, or the old band 3 when the bank is empty.
func _insane() -> bool:
	return state.band == 3

## The seal on the court's lower right, dropping in from STAMP_FROM its size
## and settling with the back ease's overshoot, its words over it.
func _draw_stamp(now: float, shown: Array) -> void:
	var field := Rect2(_grid, Vector2(_cell * state.w, _cell * state.h))
	var rad := field.size.x * STAMP_R
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, _insane())
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := field.end - Vector2(rad, rad) * 1.05
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if _insane():
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02], [tr("LU_CAT_SEAL") if not _flawless else tr("BN_FLAWLESS"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

# --- the light over the cats ---

## The stretches of beam that cross a cat's stone, drawn again over her so
## the light is seen to pass over her, in the floor's own transform.
func _draw_veil() -> void:
	if _veil_segs.is_empty() or _cell <= 0.0:
		_veil_shown = null
		return
	var b := Face.Builder.new()
	for seg: Array in _veil_segs:
		_shaft(b, seg[0], seg[1], seg[2], seg[3], seg[4])
	var since := _now() - _opened - Motion.ENTER_DELAY
	var grown := Motion.wide_pop_scale(since)
	_veil_shown = b.mesh()
	_veil_layer.draw_mesh(_veil_shown, null,
		Transform2D(0.0, Vector2(grown, grown), 0.0, _court_centre()),
		Color(1.0, 1.0, 1.0, Motion.appear_level(since)))

# --- entrance ---

## The chrome is the host's; here the court pops in wide and the blocks pop
## onto it a beat later with the squash, along the diagonal from the top-left
## corner, each block's number and shadow arriving with it.
func _enter() -> void:
	_opened = _now()
	var far := 0
	for y in state.h:
		for x in state.w:
			if not state.is_white(Vector2i(x, y)):
				far = maxi(far, x + y)
	# The cats land on their cushions with the blocks, along the same diagonal.
	for cell in _cats:
		var cat: NapCat = _cats[cell]
		Motion.stop(_look_tw.get(cat))
		_look_tw[cat] = Motion.pop_in(cat, Motion.POP_IN, _enter_delay(cell.x + cell.y))
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
	for tw in _gag_tw.values():
		Motion.stop(tw)
	_pos_tw = {}
	_look_tw = {}
	_gag_tw = {}

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
	if (_split_index >= 0 and now - _split_at < SPLIT_TIME + 0.1) \
			or (_back_index >= 0 and now - _back_at < HEART_BACK_TIME + 0.1) \
			or _moves_pill.animating(now - 0.1):
		_heart_layer.queue_redraw()
	if _combo_n >= COMBO_FROM and (now - _combo_at < COMBO_HOLD + 0.1 or _combo_out_at > -INF):
		_combo_layer.queue_redraw()
	if _tick_life(now):
		_fly(delta)
		_life_layer.queue_redraw()
	_sync_cast()

# --- the cast: every lamp's and cat's body in a few MultiMesh draws ---

## Copies every cat's and lamp's place, turn, look and tint into the cast's
## MultiMeshes (see `_cast`).
func _sync_cast() -> void:
	if _cell <= 0.0 or _cast == null:
		return
	var groups: Dictionary = {}   # mesh -> [Transform2D, Color, ...]
	var order: Array = []
	for cell in _cats:
		var cat: Control = _cats[cell]
		_cast_face(cat, _slots[cat], groups, order)
	for cell in _lamps:
		var lamp: Control = _lamps[cell]
		_cast_face(lamp, _slots[lamp], groups, order)
	for mesh in _cast_mm.keys():
		if not groups.has(mesh):
			_cast_sent.erase(_cast_mm[mesh])
			_cast_mm.erase(mesh)
	for mesh: ArrayMesh in order:
		var list: Array = groups[mesh]
		var count := list.size() / 2
		var buf := PackedFloat32Array()
		buf.resize(count * 12)
		for k in count:
			_put(buf, k, list[2 * k], list[2 * k + 1])
		var mm: MultiMesh = _cast_mm.get(mesh)
		if mm == null:
			mm = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_2D
			mm.use_colors = true
			mm.mesh = mesh
			_cast_mm[mesh] = mm
		if mm.instance_count != count:
			mm.instance_count = count
			_cast_sent.erase(mm)
		if _cast_sent.get(mm) != buf:
			mm.buffer = buf
			_cast_sent[mm] = buf
	if order != _cast_order:
		_cast_order = order
		_cast.queue_redraw()

## Puts the layers of `f` the cast draws (its `skip_layers`) into `groups`,
## under its slot's transform. Returns whether the face is on show at all.
func _cast_face(f: Face, slot: Control, groups: Dictionary, order: Array) -> bool:
	if not f.visible or not slot.visible:
		return false
	var xf := slot.get_transform() * f.get_transform()
	var tone := f.modulate * f.self_modulate * slot.modulate
	if is_zero_approx(xf.determinant()) or tone.a <= 0.0:
		return false
	var R := roundf(f._R_for(minf(f.size.x, f.size.y)) / Face.R_STEP) * Face.R_STEP
	if R <= 0.0:
		return false
	var eye := f._eye_level()
	var centre := f.size * 0.5
	for layer in f._layers():
		if not f.skip_layers.has(layer[0]):
			continue
		var mesh: ArrayMesh = f._mesh_for(layer[0], layer[1], R, eye)
		if not groups.has(mesh):
			groups[mesh] = []
			order.append(mesh)
		groups[mesh].append(xf * f._layer_transform(layer[0], R, centre))
		groups[mesh].append(tone)
	return true

## Instance `i` of a 2D MultiMesh buffer: the basis and origin in the
## server's row order, then the colour (Binairo's).
static func _put(buf: PackedFloat32Array, i: int, xf: Transform2D, col: Color) -> void:
	var o := i * 12
	buf[o] = xf.x.x
	buf[o + 1] = xf.y.x
	buf[o + 3] = xf.origin.x
	buf[o + 4] = xf.x.y
	buf[o + 5] = xf.y.y
	buf[o + 7] = xf.origin.y
	buf[o + 8] = col.r
	buf[o + 9] = col.g
	buf[o + 10] = col.b
	buf[o + 11] = col.a

func _draw_cast() -> void:
	for mesh in _cast_order:
		var mm: MultiMesh = _cast_mm.get(mesh)
		if mm != null:
			_cast.draw_multimesh(mm, null)

## Something on the court changed: rebuild it on the next draw.
func _redraw() -> void:
	_ground_dirty = true
	_beams_dirty = true
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
