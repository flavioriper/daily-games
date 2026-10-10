extends "res://core/puzzle_base.gd"

## Word Trail as a flat board: a field of cream letter tiles with grey walls
## carved through it, a row of empty length boxes under it, and the scenery
## band at the card's foot. Drag from a tile to a side-adjacent tile and the
## trail bends around the walls; let go on one of today's words and it locks
## in its own colour, ribbon and all. The rules live in
## puzzles/word_trail_state.gd, which this only draws.
##
## **You are never told the words, only how long each one is.** The slots
## under the field are the whole clue: one group of boxes per word, shortest
## first, and nothing about a word's shape is ever shown. Every open tile
## belongs to exactly one word, so the grid is the scoreboard -- the last
## word locked fills the last tile.
##
## How it is drawn. One mesh and no Controls. The walls, the tile faces, the
## ribbons, the hint glows and the slot boxes all go into a single
## `ArrayMesh`, because none of them has a face on it and a Control per cell
## would be forty-nine nodes for a field of rounded squares; the letters are
## draw commands over the top (`Mosaic.letter`, which is `draw_set_transform`
## then `draw_string`), as Nonogram draws its clue numbers and Hidden Word
## its guesses. A glyph in a mesh cache key would multiply every state by
## twenty-six.
##
## **The order is the only one that works, because a tile is opaque**: the
## walls, then the tile faces, then the ribbons *over* them, then the hint
## glow and the letters. A ribbon drawn under a tile is a ribbon nobody sees,
## and it cost one wrong screenshot on the concept page.
##
## Spec: docs/superpowers/specs/2026-09-20-word-trail-flat-design.md,
## sections 6 and 7. Ported number for number from the canvas mock at
## docs/brainstorm/concepts.html#wordtrail, which is the reference for every
## measure here.

const State = preload("res://puzzles/word_trail_state.gd")
const Pal = preload("res://core/palette.gd")
const Haptics = preload("res://core/haptics.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Face = preload("res://ui/faces/face.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const RunMesh = preload("res://ui/flat/run_mesh.gd")

# --- the screen, measured (spec section 6) ---
## The card's own inset and the gap between two tiles.
const INSET := 28.0
const GAP := 14.0
## The air between the field and the slots, and the band the slots take.
const SLOTS_PAD := 24.0
const SLOTS_H := 150.0
## One length box, the gap between two of them, the gap between two groups,
## and the gap between two wrapped lines.
const SLOT_W := 34.0
const SLOT_H := 52.0
const SLOT_GAP := 5.0
const GROUP_GAP := 22.0
const LINE_GAP := 14.0
## This board's own two, and the only two it needs. The wave's step per tile
## and how long a beam takes to grow or to unwind.
const WAVE_STEP := 0.05
const BEAM_TIME := 0.18
## How long the win waits after the last lock, so the wave that won it can
## finish first.
const WIN_WAIT := 1.4
## Three, as the mock's badge says (spec section 10) -- on Easy and Medium.
## Hard has one and Insane none of its own (polish spec 2026-09-30, section
## 1); a video hint is still offered once they are spent, as on every board
## (the user's call of 2026-09-29).
const HINTS_BY_BAND := [3, 3, 1, 0]
## A moment that has not happened: far enough back that no reader ever sees
## it, and never confused with "a while ago" (`_now() - 100`), which can be
## negative in the first minute after launch.
const NEVER := -1.0e9

# --- the pieces, in cells or in the mock's own pixels ---
## A tile's and a wall's corner, and the bottom edge each wears -- the soft
## lip every card on these screens has. The edges are the mock's pixels
## rather than fractions of a cell: so are INSET, GAP and every slot measure
## above, and this board is drawn in the same 1080-wide design space.
const RADIUS := 0.22
const TILE_EDGE := 7.0
const WALL_EDGE := 6.0
const SLOT_RADIUS := 12.0
const SLOT_EDGE := 5.0
## How far a rim goes toward the ink: a wall's a fifth, a free tile's a
## sixth. A found tile's rim goes that far from its pale face toward its
## word's deep instead.
const WALL_RIM := 0.2
const TILE_RIM := 1.0 / 6.0
const FOUND_RIM := 0.45
const SLOT_RIM := 0.4
## How far a previewed box's face leans to the beam's sun.
const PREVIEW_FILL := 0.55
## The leaf on a wall: where on the cell it starts, how long, how it leans
## and how far its ink is let through.
const WALL_LEAF_AT := Vector2(0.32, 0.52)
const WALL_LEAF := 0.34
const WALL_LEAF_ANGLE := -0.5
const WALL_LEAF_INK := 0.14
## The ribbon over a locked word and the beam under the finger, in cells.
const RIBBON_W := 0.46
const RIBBON_ALPHA := 0.5
const BEAM_W := 0.44
const BEAM_ALPHA := 0.6
const GHOST_ALPHA := 0.55
## A letter on the field, in cells, and one in a slot box, in pixels.
const LETTER := 0.48
const SLOT_FONT := 29
## The hint's glow and the dashed outline over it: each inset from the cell's
## corner, its size taken off the cell, its corner, and the dash's on and off
## runs. All the mock's.
const GLOW_INSET := 7.0
const GLOW_TRIM := Vector2(14.0, 21.0)
const GLOW_RADIUS := 0.19
const GLOW_ALPHA := 0.45
const DASH_INSET := 9.0
const DASH_TRIM := Vector2(18.0, 25.0)
const DASH_RADIUS := 0.18
const DASH_W := 5.0
const DASH_ON := 0.1
const DASH_OFF := 0.08
## The hint's ring, in cells: it starts just outside the tile.
const RING_R := 0.62

# --- the scenery band at the card's foot (spec section 8) ---
## The band is whatever the field and the slots do not spend -- 222, 236 and
## 250 by difficulty -- and it is laid the way Hidden Word's is: the family's
## clouds high in it, a washed turf with a lighter crown, blades standing out
## of that, and three bushes on the ground line. It stands still; only the
## field takes the entrance, so it is built once per layout.
## The turf's top edge measured up from the foot of the band, the band's own
## foot inside the card's inset, and the two corners.
const TURF_TOP := 52.0
const BAND_FOOT := 6.0
const TURF_RADIUS := 26.0
const CROWN_H := 22.0
const CROWN_RADIUS := 14.0
## Two clouds in the air the band bought, each x in from its own side of the
## card's inner width, y down from the band's top, and its radius.
const CLOUD_LEFT := Vector3(150.0, 46.0, 26.0)
const CLOUD_RIGHT := Vector3(170.0, 58.0, 21.0)
## Blades standing out of the turf: how many, how far in from each end they
## start, their half-width at the root, how far below the ground line they
## root, and the band their height and lean fall in.
const BLADES := 22
const BLADE_EDGE := 30.0
const BLADE_W := 5.0
const BLADE_ROOT := 4.0
const BLADE_MIN := 14.0
const BLADE_SPREAD := 20.0
const BLADE_LEAN := 8.0
## Three bushes on the ground line, in the mock's own x convention: from the
## left, or negative from the right, or a fraction of the width when between
## 0 and 1; and the radius.
const BUSHES := [Vector2(52.0, 38.0), Vector2(0.42, 26.0), Vector2(-72.0, 33.0)]
## How far each green is lifted toward the card's parchment, so the band
## recedes behind the field rather than competing with it.
const TURF_WASH := 0.52
const CROWN_WASH := 0.3
const BLADE_WASH := 0.24
const BUSH_DEEP_WASH := 0.3
const BUSH_LIT_WASH := 0.12

## A locked word takes one of the palette's six chip colours, in order, and
## every part of it agrees: the ribbon in the strong one at RIBBON_ALPHA, the
## tile faces in the pale *_TILE, the letters in the deep one. Six is also
## the most words any band has, so nothing ever wraps round. No new colour is
## added to the palette for this board (spec section 7).
const WORD_COLS := [Pal.LEAF, Pal.SUN, Pal.MOON_INK, Pal.BERRY, Pal.ACORN, Pal.FLOWER]
const WORD_TILES := [Pal.LEAF_TILE, Pal.SUN_TILE, Pal.MOON_TILE, Pal.BERRY_TILE, Pal.ACORN_TILE, Pal.FLOWER_TILE]
const WORD_DEEPS := [Pal.LEAF_DEEP, Pal.SUN_DEEP, Pal.MOON_DEEP, Pal.BERRY_DEEP, Pal.ACORN_DEEP, Pal.FLOWER_DEEP]

# --- the second polish (2026-09-25; the spec's section 16) ---
## A wall is a bed sunk into the card rather than a slab standing on it: a
## floor a shade under the stone with a shadow lip BED_LIP of a cell deep
## along its top, the leaf pressed into the floor. A raised grey slab read as
## one more tile with no letter on it.
const BED := Color("e2d4b6")
const BED_SHADE := Color("cdbb98")
const BED_LIP := 0.07
## A tile is a paper piece with a bevel: a lit rim round a crown PAPER_CROWN
## toward SURFACE_HI, over a lip toward LINE. A found tile is the same piece
## in its word's pale, its rim RIM_LIGHT toward SURFACE. BEVEL is in cells;
## TONE is how far a cell's hash moves its face, so the field reads as laid
## by hand.
const PAPER_CROWN := 0.2
const PAPER_LIP := 0.5
const RIM_LIGHT := 0.35
const BEVEL := 0.05
const TONE := 0.03
## A tile on the trail being traced is lit TRAIL_LIT toward the sun, and the
## beam's head sits on the finger's tile as a sun disc HEAD_R of a cell over a
## soft halo HALO_R of a cell, so the finger always shows where it is.
const TRAIL_LIT := 0.32
const HEAD_R := 0.19
const HALO_R := 0.5
const HALO_A := 0.4
## As a lock's wave reaches a tile it hops LOCK_HOP of a cell as well as
## bumping, so the colour arrives as a thing landing and not only a tint.
const LOCK_HOP := -0.07
## Once a word is whole, a light runs down its ribbon from its first letter to
## its last: GLINT_LEN tiles long, GLINT_STEP a tile, SURFACE at GLINT_A over
## GLINT_W of the ribbon's width.
const GLINT_LEN := 1.4
const GLINT_STEP := 0.045
const GLINT_A := 0.6
const GLINT_W := 0.42
## The solve hop is also a light crossing the field: each tile shines SHINE
## toward SURFACE at the top of its hop.
const SHINE := 0.4
## The slots grow into the scenery band until it is BAND_KEEP tall, by at most
## SLOT_ROOM more than SLOTS_H, and a box grows with them up to SLOT_GROW of
## its size -- so a short easy row is a row of real boxes and not a strip of
## pips. An empty box is a bed like a wall, a lit one a bevelled piece in its
## word's pale, and each piece pops into its bed as its letter arrives.
const BAND_KEEP := 150.0
const SLOT_ROOM := 80.0
const SLOT_GROW := 1.45
const SLOT_BEVEL := 3.0

const TIP_CYCLE := 8.0
const TIPS := [
	"WT_TIP_DRAG",
	"WT_TIP_ONE_WORD",
	"WT_TIP_LENGTHS",
	"WT_TIP_FREE",
]
## Hard's tips, where a wrong trail blows a wish away, and Insane's, in the
## dark.
const TIPS_WISHES := ["WT_TIP_DRAG", "WT_TIP_WISHES", "WT_TIP_CANCEL", "WT_TIP_LENGTHS"]
const TIPS_NIGHT := ["WT_TIP_NIGHT", "WT_TIP_WISHES", "WT_TIP_NIGHT_WORDS", "WT_TIP_CANCEL"]

# --- the third polish (2026-09-30; docs/superpowers/specs/2026-09-30-word-trail-polish-design.md) ---
const SproutFace = preload("res://ui/faces/sprout_face.gd")
const LanternFace = preload("res://ui/faces/lantern_face.gd")
const Seal = preload("res://ui/flat/seal.gd")
const OUT_CARD := "res://ui/hud/out_of_rows.gd"
## Motion. The field's tiles pop in on a diagonal cascade inside its wide pop;
## a tile the finger takes hops TAKE_HOP of a cell; a word's slot group hops
## in a wave once its letters have landed; a wrong trail that cost a wish
## shakes its head.
const CASCADE := 0.025
const TAKE_HOP := -0.07
const TAKE_TIME := 0.22
const SLOT_HOP := -9.0
const SLOT_HOP_STEP := 0.04
const MISS_WOBBLE := 0.1
const MISS_TIME := 0.45
## A lifted word's tiles dip as the wave leaves them.
const LIFT_DIP := 0.05
## Out of wishes: every tile sags and leans a little, a tile after another,
## then the card comes.
const DROOP_SAG := 0.07
const DROOP_TILT := 0.08
const DROOP_TIME := 0.5
const DROOP_STEP := 0.012
const CARD_AFTER := 1.8
const CARD_AFTER_STILL := 0.5
## Show the words: one word locks after another, this far apart.
const REVEAL_STEP := 0.5
const SHOWN_ALPHA := 0.28
## Rewards. A lock is a tick a semitone higher a word, across the game and
## never past five (the cozy rules; it was a pluck up two octaves); a word
## found within QUICK of the last is quick; three in a row without a
## plausible miss is a streak; seven letters or more is a big one.
const CLIMB := [0, 1, 2, 3, 4, 5]
const QUICK := 6.0
const STREAK := 3
const BIG := 7
const BUBBLE_FONT := 36
const BUBBLE_HOLD := 1.4
## The gags, one a word, picked off the word: hearts, a conga, a butterfly,
## a twirl, or nothing.
const GAGS := 5
const LOVE_HEARTS := 4
const LOVE_TIME := 1.3
const LOVE_RISE := 0.9
const LOVE_R := 0.11
const CONGA_STEP := 0.06
const CONGA_HOP := -0.12
const FLUTTER_TIME := 2.2
const FLUTTER_R := 0.2
const TWIRL_TIME := 0.6
const TWIRL_HOP := -0.16
## The dandelion on the band: in from the right, its stem's height, the
## head's radius, a seed's length, and how long a blown seed drifts.
const PUFF_RIGHT := 280.0
const PUFF_H := 104.0
const PUFF_R := 38.0
const SEED_LEN := 0.8
const SEED_FLY := 2.4
const PUFF_BACK := 0.5
## Night Walk. How long a tile the lantern has left stays readable, how far
## round the finger it reaches (in cells, every way), the night's colours, the
## lantern's glow over the field, and the dawn on a solve.
const AFTERGLOW := 1.6
const LAMP_REACH := 1
const NIGHT_TILE := Color("4a4d74")
const NIGHT_RIM := Color("5b5f8c")
const NIGHT_LIP := Color("2e3050")
const NIGHT_SKY := Color("363a5e")
const NIGHT_STAR := Color("f4e6b8")
const LAMP_GLOW := Vector2(1.7, 0.22)
const LAMP_SIZE := 0.95
const LAMP_OFFSET := Vector2(-0.62, -0.8)
const LAMP_FOLLOW := 16.0
const DAWN_TIME := 1.5
const DAWN_STEP := 0.03
## The party, PARTY_AT after the solve hop: the tiles dance, every wall
## blooms a flower, the sprout comes up on the band in a party hat beside a
## card with a silly cheer, and STAMP_AT later the seal drops on the card.
const PARTY_AT := 0.35
const DANCE_BEATS := 4
const DANCE_BEAT := 0.3
const DANCE_TILT := 0.12
const DANCE_HOP := -0.08
const BLOOM_STEP := 0.04
const BLOOM_TIME := 0.4
const BLOOM_R := 0.2
const STAMP_AT := 1.1
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 52.0
const STAMP_TILT := -0.22
const CHEERS := 12
const STAGE_RISE := 120.0
const STAGE_TIME := 0.4
const STAGE_X := 150.0
const STAGE_RIGHT := 24.0
const STAGE_H := 104.0
const STAGE_RADIUS := 24.0
const STAGE_EDGE := 6.0
const STAGE_SPROUT_R := 46.0
const STAGE_FONT := 34
const STAGE_LINE := 26

var _state = State.new()
## The board's own effects node, as on every flat board: the hint's ring and
## sparkle come through it and nowhere else.
var fx: Node2D

## The cells the finger has strung together, in order. Empty when nothing is
## being dragged.
var _trail: Array[Vector2i] = []
## When the beam last reached a new tile: the beam grows from the tile before
## it to the finger over BEAM_TIME from here.
var _beam_at := -100.0
## When the trail last grew a tile: the slot box that letter was spelt into
## pops in from here. A retraction does not set it, so nothing pops backwards.
var _grew_at := -100.0
## The tile under the finger, when it went down and when it came up (-1 while
## it is still down): what Motion.press_scale is handed. The trail's other
## tiles sit half-way into the same press.
var _press_cell := Vector2i(-1, -1)
var _press_at := -100.0
var _press_up := -1.0
## The trail a release did not lock, unwinding: {"path": Array, "at": float}.
## Nothing else happens on a wrong trail -- no toast, no shiver, no move
## counted, no hint spent (spec section 3).
var _ghost: Dictionary = {}
## Each locked word's moment, by word index, and each lifted word's. The wave
## reads them; until the motion pass lands, a found word is simply whole.
var _found_at: Dictionary = {}
var _lifted_at: Dictionary = {}

## The rings and sparkles a wave still owes: [{"at", "cell", "colour",
## "ring"}]. A lock's ring lands on the word's last tile when the wave gets
## there, not when the finger let go, so the two arrive together.
var _pending: Array = []

var _opened := 0.0
var _anim_until := 0.0
var _solved_at := -1.0
## The field mesh (walls, tiles, ribbons and hint glows), the slots' mesh and
## the still scenery band. The first two are dropped whenever something
## changed so the next _draw rebuilds them; the band only on a relayout.
var _field: ArrayMesh
var _slots: ArrayMesh
var _band: ArrayMesh
## The meshes the last _draw actually handed to the canvas item. A canvas
## command holds a mesh by RID and not by reference, so dropping the only
## reference to a mesh still on the item's command list leaves the renderer
## drawing a freed RID ("Parameter mesh is null", and an empty card).
var _shown: Array = []
## The field's pieces and the slots' (the board checkup, 2026-10-02): every
## wall, tile, glow, flower and whole ribbon is a shape made once at the
## layout it is drawn at and copied natively into a run of vertices laid for
## it (`RunMesh`), painted by colour fills; only what is moving along a path
## (a ribbon's wave, a glint, the beam) is drawn live, into its own run.
## Built in script a vertex at a time, the field was 8-9 ms and the slots 3
## on every frame anything moved -- every tile a trail took.
var _rm := RunMesh.new(_shape)
var _sm := RunMesh.new(_slot_shape)
## The board the shapes and runs were made for; another remakes them. They
## are made at the first layout's cell (`_ref_cell`, the field then at
## `_ref_origin`) and the slots' scale (`_ref_q`) and drawn scaled after a
## relayout, so the win card's (the board shrinks to half) makes nothing: it
## was a 20 ms frame.
var _rm_key: Array = []
var _sm_key: Array = []
var _ref_cell := 0.0
var _ref_origin := Vector2.ZERO
var _ref_q := 1.0
## The tile transforms worked out this frame, by cell: the field, its glows
## and its letters all ask for the same ones.
var _xf_t := -1.0
var _xf_memo: Dictionary = {}

enum { SHAPE_TILE, SHAPE_WALL, SHAPE_GLOW, SHAPE_LEAVES, SHAPE_HEAD, SHAPE_SKY, SHAPE_LAMP, SHAPE_RIBBON }
enum { PART_SKY, PART_CELL, PART_RIBBON, PART_BEAM, PART_GLOW, PART_FLOWER, PART_LAMP }
enum { SLOT_BED, SLOT_PIECE }
## The live beam's run: the most a trail across the whole field draws.
const BEAM_ROOM := 4000
const GLOWS_KEPT := 2
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

# --- the third polish ---
## Bumped on every build, so a timer from an earlier board does nothing.
var _gen := 0
## When each tile was taken by the finger (it hops), and the last trail that
## cost a wish, shaking its head.
var _taken_at: Dictionary = {}
var _miss_path: Array = []
var _miss_at := -100.0
## The dandelion: when each spent seed was blown (by seed index), and when a
## bought wish grew a new head.
var _blown: Dictionary = {}
var _puff_at := -100.0
## Out of wishes: the host's hook (it reads `out_of_hearts`), the sag, the
## card, and whether this board has had its one more wish.
var out_of_hearts := false
var _droop_at := NEVER
var _card: Control
var _wish_bought := false
var _revealing := false
## Rewards: how many notes up the scale, the words in a row with no
## plausible miss, when the last word locked, the gags by word ({"kind",
## "at"}), and the bubble.
var _notes := 0
var _streak := 0
var _last_lock := -100.0
var _gags: Dictionary = {}
var _bubble: Control
## Bumped for a word when it is lifted, so a lock's timers (note, bubble,
## gag) that have not fired yet do nothing over a word taken back.
var _lock_gen: Dictionary = {}
## The night: when each cell was last in the lantern's reach, whether a
## finger is down lighting, the cell it lights round, where the lantern
## hangs, and the dawn.
var _light: Dictionary = {}
var _lamp_on := false
var _lamp_cell := Vector2i(-1, -1)
var _lamp: Control
var _lamp_pos := Vector2.ZERO
var _dawn_at := NEVER
## The party: when it began, when the meadow bloomed, the cheer, the stage's
## sprout, the seal and its mesh.
var _party_at := NEVER
var _bloom_at := NEVER
var _stage_at := NEVER
var _cheer := 0
var _sprout: Control
var _stamp: Control
var _stage_mesh: ArrayMesh
var _air: ArrayMesh
var _restoring := false
## When a bought wish perked the tiles back up, and the first seed of the
## dandelion's current head.
var _perk_at := -100.0
var _puff_base := 0

func puzzle_id() -> String: return "wordtrail"
func title() -> String: return "Word Trail"

func rules() -> String:
	var out := tr("WT_RULES")
	if _state.counts_wishes():
		out += "\n\n" + tr("WT_RULES_WISHES") % int(State.WISHES[_state.band])
	if _state.night():
		out += "\n\n" + tr("WT_RULES_NIGHT")
	return out

## The tutorial, a lesson a page, played by a little field of the board's
## own (ui/hud/word_trail_tutorial_diagram.gd): tracing a word, the boxes as
## the only clue, Undo and Reset, and as the band has them the bulb, the
## wishes and Night Walk. The board checkup, 2026-10-02.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/word_trail_tutorial_diagram.gd")
	var hints: int = HINTS_BY_BAND[_state.band]
	var wishes: bool = _state.counts_wishes()
	var steps := [
		[Diagram.Lesson.TRACE, "HTP_WT_TRACE", tr("HTP_WT_TRACE_BODY")],
		[Diagram.Lesson.LENGTHS, "HTP_WT_LENGTHS",
			tr("HTP_WT_LENGTHS_BODY_WISH") if wishes else tr("HTP_WT_LENGTHS_BODY")]]
	if wishes:
		steps.append([Diagram.Lesson.WISHES, "HTP_WT_WISHES",
			tr("HTP_WT_WISHES_BODY") % int(State.WISHES[_state.band])])
	if _state.night():
		steps.append([Diagram.Lesson.NIGHT, "HTP_WT_NIGHT", tr("HTP_WT_NIGHT_BODY")])
	steps.append([Diagram.Lesson.UNDO, "HTP_WT_UNDO", tr("HTP_WT_UNDO_BODY")])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_WT_HINT_BODY_ONE") if hints == 1 else tr("HTP_WT_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.wishes = wishes
		if wishes:
			d.wish_count = int(State.WISHES[_state.band])
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func _tips() -> Array:
	if _state.night():
		return TIPS_NIGHT
	return TIPS_WISHES if _state.counts_wishes() else TIPS

## Undo and Hint, and nothing else. There is no Check because nothing wrong
## can be sitting on the board to check: only a right word locks, so the
## registry drops the actions row and Reset rides up into the top bar.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

## What the phone does under each cue (docs/agents/haptics.md). The move is
## the word, not its tiles: `select` ticks the ear a tile at a time and says
## nothing to the hand, and the trail knocks once as it is let go -- a bump
## when it locks (`place`), a bad when it blows a seed (`_missed`: the `miss`
## cue is the last seed's too, and that one is the droop's lose), nothing
## when it only unwinds, was tried before or was put down off the field. The
## word's note, its bubble (big, quick, a streak) and its gag come a beat
## after the bump and add nothing; the seeds running low, the lantern, the
## dawn, Show the words and the party say nothing either. The win waits for
## the last word's wave (`solved` is queued for it); the seal thuds as it
## lands (`_stamp_down`).
const HAPTICS := {
	"place": Haptics.BUMP,
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
	"hint": Haptics.GOOD,
	"wish_back": Haptics.GOOD,
	"droop": Haptics.LOSE,
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
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_state.build(rng, difficulty)
	_trail = []
	_beam_at = -100.0
	_grew_at = -100.0
	_press_cell = Vector2i(-1, -1)
	_press_up = -1.0
	_ghost = {}
	_found_at = {}
	_lifted_at = {}
	_pending = []
	_anim_until = 0.0
	_solved_at = -1.0
	_gen += 1
	_taken_at = {}
	_miss_path = []
	_miss_at = -100.0
	_blown = {}
	_puff_at = -100.0
	out_of_hearts = false
	_droop_at = NEVER
	_close_card()
	_wish_bought = false
	_revealing = false
	_notes = 0
	_streak = 0
	_last_lock = -100.0
	_gags = {}
	_lock_gen = {}
	_drop_bubble()
	_light = {}
	_lamp_on = false
	_lamp_cell = Vector2i(-1, -1)
	_dawn_at = NEVER
	_party_at = NEVER
	_bloom_at = NEVER
	_stage_at = NEVER
	_restoring = false
	if is_instance_valid(_sprout):
		_sprout.visible = false
	if is_instance_valid(_stamp):
		_stamp.queue_free()
	_stamp = null
	_stage_mesh = null
	_air = null
	_make_lamp()
	_layout()
	_enter()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()

# --- layout ---

## The largest cell the card holds. **The width binds at every band** -- 178,
## 146 and 123 at 1080 wide, against Queens' and Nonogram's 103 on their hard
## boards -- because the field is square while the slot is tall. What the
## field and the slots do not spend is the scenery band at the card's foot.
func _cell_for(available: float) -> float:
	if _state.n <= 0:
		return 0.0
	var span := float(_state.n - 1) * GAP
	var across := (size.x - 2.0 * INSET - span) / float(_state.n)
	var down := (available - 2.0 * INSET - SLOTS_H - SLOTS_PAD - span) / float(_state.n)
	return maxf(0.0, minf(across, down))

func _cell() -> float:
	return _cell_for(size.y)

## The field is n cells and the gaps between them, square.
func _field_size() -> float:
	return float(_state.n) * _cell() + float(_state.n - 1) * GAP

## The field's top-left inside this Control's rect: centred across the card,
## its top at the card's own inset.
func _origin() -> Vector2:
	return Vector2((size.x - _field_size()) * 0.5, INSET)

## The centre of the field: what the entrance pops about.
func _field_centre() -> Vector2:
	return _origin() + Vector2.ONE * (_field_size() * 0.5)

## The slots' band: SLOTS_PAD under the field, SLOTS_H tall.
func _slots_top() -> float:
	return _origin().y + _field_size() + SLOTS_PAD

## The top-left of cell (x across, y down).
func _corner(cell: Vector2i) -> Vector2:
	var step := _cell() + GAP
	return _origin() + Vector2(cell) * step

func _centre(cell: Vector2i) -> Vector2:
	return _corner(cell) + Vector2.ONE * (_cell() * 0.5)

## Control-local point over the centre of the cell at (row, column), the name
## every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(Vector2i(c, r))

## The cell under a local point, or (-1, -1). The gap between two tiles
## belongs to neither: a finger crossing it changes nothing until it is over
## the next tile, which is what keeps a fast drag from cutting a corner.
func _cell_at(local: Vector2) -> Vector2i:
	var cell := _cell()
	if cell <= 0.0:
		return Vector2i(-1, -1)
	var step := cell + GAP
	var p := (local - _origin()) / step
	var at := Vector2i(int(floor(p.x)), int(floor(p.y)))
	if at.x < 0 or at.y < 0 or at.x >= _state.n or at.y >= _state.n:
		return Vector2i(-1, -1)
	var corner := _corner(at)
	if local.x > corner.x + cell or local.y > corner.y + cell:
		return Vector2i(-1, -1)
	return at

## The card this board wants: every pixel it is given. The field takes what
## the width allows, the slots their fixed band, and the rest is the scenery
## band -- 222, 236 and 250 by band -- so there is never any slack.
func card_height(available: float) -> float:
	return available

## False, and honestly so: card_height() hands back everything, so the slack
## is zero and there is nothing to centre.
func card_centred() -> bool:
	return false

func _layout() -> void:
	# The band is the only thing that does not move, so it is the only mesh a
	# relayout has to drop by hand -- and the stage's card, which is sized off
	# the band.
	_band = null
	_stage_mesh = null
	if is_instance_valid(_stamp):
		_stamp.position = _stamp_centre() - _stamp.pivot_offset
	_refresh()

## One group of boxes per word, shortest first, wrapped to as many lines as
## it takes -- one on easy, two on the others. Length is the whole clue.
## Returns [{"items": [{"i": int, "w": float}], "w": float}].
func _slot_lines(k := -1.0) -> Array:
	if k < 0.0:
		k = _slot_k()
	var wide := _slots_wide()
	var lines: Array = []
	var cur: Array = []
	var cur_w := 0.0
	for i in _state.words.size():
		var span := float((_state.words[i]["path"] as Array).size())
		var group := span * SLOT_W * k + (span - 1.0) * SLOT_GAP * k
		var add := (GROUP_GAP * k if not cur.is_empty() else 0.0) + group
		if not cur.is_empty() and cur_w + add > wide:
			lines.append({"items": cur, "w": cur_w})
			cur = []
			cur_w = 0.0
			add = group
		cur_w += add
		cur.append({"i": i, "w": group})
	if not cur.is_empty():
		lines.append({"items": cur, "w": cur_w})
	return lines

## How wide a line of slot groups may run, and where a line of `w` starts:
## across the card, each line centred.
func _slots_wide() -> float:
	return size.x - 2.0 * INSET

func _slots_left(w: float) -> float:
	return size.x * 0.5 - w * 0.5

## The height the slots may take: SLOTS_H, and as much of the scenery band as
## leaves it BAND_KEEP tall, up to SLOT_ROOM more. The field never gives up a
## pixel for this -- _cell_for still reads SLOTS_H -- so on a short screen the
## slots are simply what they were.
func _slots_room() -> float:
	var band := size.y - INSET - (_slots_top() + SLOTS_H)
	return SLOTS_H + clampf(band - BAND_KEEP, 0.0, SLOT_ROOM)

## How much bigger than the mock's a box is: the largest scale up to
## SLOT_GROW whose wrapped lines still fit the slots' room, in 0.05 steps.
func _slot_k() -> float:
	var room := _slots_room()
	var k := SLOT_GROW
	while k > 1.0:
		var n := float(_slot_lines(k).size())
		if n * SLOT_H * k + (n - 1.0) * LINE_GAP * k <= room:
			return k
		k -= 0.05
	return 1.0

## The top of the slots' block, centred in their room, for boxes of scale `k`
## over `lines`.
func _slots_block_top(lines: Array, k: float) -> float:
	var n := float(lines.size())
	var tall := n * SLOT_H * k + (n - 1.0) * LINE_GAP * k
	return _slots_top() + (_slots_room() - tall) * 0.5

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.words.is_empty():
		return
	var t := _now()
	_fire_pending(t)
	_light_round(t)
	_ride_lamp(t, delta)
	_ride_sprout(t)
	if _animating(t):
		_refresh()

## Whether anything on this card is still moving, asked wave by wave rather
## than by one deadline. **Every** wave has to be in here: One Line shipped
## two lines frozen at four fifths of a fade because one was left out, and it
## showed in a rendered frame and in no test.
func _animating(t: float) -> bool:
	# A ghost keeps its own frames coming until _ribbons lets go of it: a
	# beam whose unwind ran a frame past the rest would otherwise stay on the
	# card for ever at an alpha nobody can see.
	if not _ghost.is_empty():
		return true
	# Rings, sparkles and anything else that asked for time by the clock.
	if t < _anim_until or not _pending.is_empty():
		return true
	# The night: the lantern lighting as the finger moves, and every tile it
	# left fading back into the dark.
	if _state.night() and (_lamp_on or t < _light_until()):
		return true
	if Motion.reduce:
		return false
	# The entrance: the field's wide pop and its tiles' cascade, then the slot
	# groups dropping in.
	var entrance := Motion.ENTER_DELAY + Motion.ENTER_POP \
		+ Motion.stagger(2 * maxi(_state.n - 1, 0), CASCADE) \
		+ Motion.stagger(maxi(_state.words.size() - 1, 0), Motion.ENTER_STAGGER) \
		+ Motion.DROP_TIME
	if t - _opened < entrance:
		return true
	# Every word's wave, forward off a lock and backwards off an undo or a
	# reset, with the bump and the slot letter's drop the last tile still owes.
	for i in _state.words.size():
		var span := float((_state.words[i]["path"] as Array).size())
		var settled := span * WAVE_STEP + maxf(maxf(Motion.BUMP_TIME, Motion.DROP_TIME),
			maxf(Motion.HOP_TIME, _glint_length(i)))
		# ... and the slot group's hop once every letter has landed.
		settled = maxf(settled, _slot_hop_from(i) - float(_found_at.get(i, 0.0))
			+ span * SLOT_HOP_STEP + Motion.HOP_TIME)
		if _found_at.has(i) and t - float(_found_at[i]) < settled:
			return true
		if _lifted_at.has(i) and t - float(_lifted_at[i]) < span * WAVE_STEP + Motion.HOP_TIME:
			return true
	# The live beam growing to the finger, and the tile under it pressing or
	# springing back.
	if not _trail.is_empty() and t - _beam_at < BEAM_TIME:
		return true
	if not _trail.is_empty() and t - _grew_at < Motion.POP_IN:
		return true
	if _press_cell.x >= 0 and (_press_up < 0.0 or t - _press_up < Motion.RELEASE_TIME):
		return true
	# The solve wave, from the corner the field is hopped from.
	if _solved_at >= 0.0 and t - _solved_at < Motion.SOLVE_DELAY + _solve_span() + Motion.SOLVE_TIME:
		return true
	return false

## How long the solve wave takes to cross the field: the far corner's own
## delay.
func _solve_span() -> float:
	return Motion.stagger(2 * maxi(_state.n - 1, 0), _solve_per())

## The solve wave's pace, a tile: **half the family's**, because this field
## is the biggest grid in the game (7 x 7 at 123 a cell) and its diagonal
## runs to twelve, where every other board's runs to six or eight. It goes
## through Motion.stagger's own `per` rather than a copied number of this
## board's (spec section 9: 0.02 a tile).
func _solve_per() -> float:
	return Motion.SOLVE_STAGGER * 0.5

## Keeps the field redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Drops the field and the slots so the next _draw rebuilds them, and asks
## for that draw. The meshes the last _draw handed over are still held by
## _shown, so the renderer is never left pointing at a freed RID.
func _refresh() -> void:
	_xf_t = -1.0
	_field = null
	_slots = null
	queue_redraw()

## Every ring and sparkle whose moment has come. A lock's pair waits for its
## wave to reach the word's last tile; the solve's gold waits for the hop.
func _fire_pending(t: float) -> void:
	if _pending.is_empty():
		return
	var keep: Array = []
	for e: Dictionary in _pending:
		if t < float(e["at"]):
			keep.append(e)
			continue
		var at := _centre(e["cell"])
		if bool(e["ring"]):
			fx.ring(at, _cell() * RING_R, e["colour"])
		fx.sparkle(at, e["colour"])
		_busy_for(Motion.RING_TIME)
	_pending = keep

## Queues one ring and sparkle on `cell` in `colour`, `after` seconds from
## now. Nothing at all under reduce-motion: ui/fx2d.gd already draws neither
## a ring nor a sparkle there, so this only spares the board the frames it
## would have spent waiting for them.
func _fx_at(cell: Vector2i, colour: Color, after := 0.0, ring := true) -> void:
	if Motion.reduce:
		return
	_pending.append({"at": _now() + after, "cell": cell, "colour": colour, "ring": ring})
	_busy_for(after + Motion.RING_TIME)

# --- the drawing ---

## The band under everything, still; then the field, which pops in wide about
## its centre while it fades (rule 7: a wide thing comes from most of the
## way), as one draw transform over its mesh; then the field's letters over
## that; then the slots, whose groups drop in on their own stagger, and their
## letters.
func _draw() -> void:
	if _state.words.is_empty() or _cell() <= 0.0:
		return
	var t := _now()
	var shown: Array = []
	if _band == null:
		_band = _build_band()
	if _band != null:
		draw_mesh(_band, null)
		shown.append(_band)
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	var grow := Motion.wide_pop_scale(since)
	var mid := _field_centre()
	if seen > 0.0:
		if _field == null:
			_field = _build_field(t)
		if _field != null:
			draw_mesh(_field, null,
				Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow)),
				Color(1.0, 1.0, 1.0, seen))
			shown.append(_field)
		_draw_letters(t, grow, mid, seen)
	if _slots == null:
		_slots = _build_slots(t)
	if _slots != null:
		draw_mesh(_slots, null)
		shown.append(_slots)
	_draw_slot_letters(t)
	# The air over everything: the dandelion and its seeds, hearts and
	# butterflies. Rebuilt with the field, in one mesh.
	_air = _build_air(t)
	if _air != null:
		draw_mesh(_air, null)
		shown.append(_air)
	_draw_stage(t, shown)
	_shown = shown

## Everything on the field with no glyph on it, in one mesh and in the one
## order that works: the walls, the tile faces, the ribbons over them and the
## hint glows over those. The slots are their own mesh, because they do not
## take the field's entrance.
func _build_field(t: float) -> ArrayMesh:
	_lay_runs()
	_rm.begin()
	var night: bool = _state.night()
	var levels: Dictionary = _levels(t) if night else {}
	if night:
		_rm.open(PART_SKY, 0)
		_night_sky(t)
	var k := 0
	for cell: Vector2i in _state.walls:
		_rm.open(PART_CELL, k)
		k += 1
		var lv: float = levels.get(cell, 1.0)
		if lv < 1.0:
			_night_piece(cell, t)
		if lv > 0.0:
			_wall(cell, lv, t)
	for cell: Vector2i in _state.letters:
		_rm.open(PART_CELL, k)
		k += 1
		var lv: float = levels.get(cell, 1.0)
		if lv < 1.0:
			_night_piece(cell, t)
		if lv > 0.0:
			_tile(cell, t, lv)
	_ribbons(t)
	for i in _state.words.size():
		_rm.open(PART_GLOW, i)
		_glow(i, t)
	_meadow(t)
	if night:
		_rm.open(PART_LAMP, 0)
		_lamp_glow(t)
	return _rm.mesh()

## Every piece's run, laid in paint order: the night sky, every cell (walls,
## then tiles, each room for a night piece and its own), every word's ribbon
## with its glint, the beam, every word's glows, every wall's flower and the
## lantern's pool. Laid again only when the cell, the field's place or the
## board changes.
func _lay_runs() -> void:
	var key := [_gen, _state.n]
	# Remade for a new board, or for a bigger cell than they were made at (a
	# layout before the host settled): a shape is only ever drawn smaller.
	if _rm.laid() and key == _rm_key and _cell() <= _ref_cell + 0.5:
		return
	_rm_key = key
	_ref_cell = _cell()
	_ref_origin = _origin()
	_rm.reset()
	_rm.room(PART_SKY, 0, _rm.size_of(SHAPE_SKY))
	var tile := _rm.size_of(SHAPE_TILE)
	var cells: int = _state.walls.size() + _state.letters.size()
	var own := maxi(tile, _rm.size_of(SHAPE_WALL))
	for k in cells:
		_rm.room(PART_CELL, k, own + (tile if _state.night() else 0))
	for i in _state.words.size():
		# A ribbon's wave is never longer than the whole ribbon; its glint is
		# a short stroke inside it.
		_rm.room(PART_RIBBON, i, _rm.size_of(SHAPE_RIBBON + i) * 2 + 256)
	_rm.room(PART_BEAM, 0, BEAM_ROOM)
	# Room for GLOWS_KEPT glows a word; a word hinted further than that puts
	# the rest on the tail (it is rare: a hint lights one tile).
	for i in _state.words.size():
		_rm.room(PART_GLOW, i, _rm.size_of(SHAPE_GLOW) * GLOWS_KEPT)
	var flower := _rm.size_of(SHAPE_LEAVES) + _rm.size_of(SHAPE_HEAD)
	for k in _state.walls.size():
		_rm.room(PART_FLOWER, k, flower)
	_rm.room(PART_LAMP, 0, _rm.size_of(SHAPE_LAMP))

## A cell's shape from the reference cell to this layout's, about `corner`.
func _at_corner(corner: Vector2) -> Transform2D:
	var k := _cell() / _ref_cell
	return Transform2D(0.0, Vector2(k, k), 0.0, corner)

## Whether this layout is not the one the shapes were made at. The shapes
## that lie where they are drawn (a whole ribbon, the night sky) cannot be
## scaled to another, because the gap between two tiles is the same pixels
## at every cell, so they are drawn live then (the win card's little board).
func _relaid() -> bool:
	return not is_equal_approx(_cell(), _ref_cell) or not _origin().is_equal_approx(_ref_origin)

## Shape `id` at the cell the runs are laid at, in slot colours: a cell's
## pieces about the cell's top-left corner, a flower's about its middle, a
## word's whole ribbon and the night sky where they lie on the field.
func _shape(id: int) -> Face.Builder:
	var s := _ref_cell
	var b := Face.Builder.new()
	var box := Vector2(s, s)
	match id:
		SHAPE_TILE:
			_piece(b, Vector2.ZERO, box, s * RADIUS, TILE_EDGE, s * BEVEL,
				RunMesh.slot(2), RunMesh.slot(1), RunMesh.slot(0))
		SHAPE_WALL:
			_bed(b, Vector2.ZERO, box, s * RADIUS, s * BED_LIP, RunMesh.slot(1), RunMesh.slot(0))
			var leaf := Transform2D(WALL_LEAF_ANGLE, WALL_LEAF_AT * s + Vector2(0.0, s * BED_LIP * 0.5))
			b.polygon(leaf * _leaf_points(s * WALL_LEAF), RunMesh.slot(2))
		SHAPE_GLOW:
			b.fan(Face.Builder.round_rect(Vector2.ONE * GLOW_INSET, box - GLOW_TRIM, s * GLOW_RADIUS),
				RunMesh.slot(0))
			var ring := Face.Builder.round_rect(Vector2.ONE * DASH_INSET, box - DASH_TRIM, s * DASH_RADIUS)
			for dash in _dashes(ring, s * DASH_ON, s * DASH_OFF):
				b.stroke(dash as PackedVector2Array, DASH_W, RunMesh.slot(1))
		SHAPE_LEAVES:
			var r := BLOOM_R * s
			_leaf(b, Vector2(0.0, r * 0.4), r * 1.3, 0.5, RunMesh.slot(0))
			_leaf(b, Vector2(0.0, r * 0.4), r * 1.1, PI - 0.4, RunMesh.slot(0))
		SHAPE_HEAD:
			var r := BLOOM_R * s
			for k in 5:
				b.disc(Vector2.from_angle(TAU * float(k) / 5.0) * r * 0.62, r * 0.52, RunMesh.slot(0))
			b.disc(Vector2.ZERO, r * 0.42, RunMesh.slot(1))
		SHAPE_SKY:
			_sky_into(b, RunMesh.slot(0), RunMesh.slot(1))
		SHAPE_LAMP:
			Scenery.soft_disc(b, Vector2.ZERO, s * LAMP_GLOW.x, s * LAMP_GLOW.x, RunMesh.slot(0))
		_:
			var i := id - SHAPE_RIBBON
			if i >= 0 and i < _state.words.size():
				_ribbon(b, _state.words[i]["path"], s * RIBBON_W, RunMesh.slot(0))
	return b

## A rounded card: its face over a bottom edge in the rim colour, the soft
## lip every card on these screens wears. The canvas mock's `card()`.
## `xf` is whatever the thing is wearing this frame -- a tile's bump, press
## and hop, or a slot box's drop -- so a moving slab is one rounded rect
## through a transform and never a second recipe.
func _slab(b, at: Vector2, box: Vector2, r: float, edge: float, face: Color, rim: Color,
		xf := Transform2D.IDENTITY) -> void:
	b.fan(xf * Face.Builder.round_rect(at, box, r), rim)
	b.fan(xf * Face.Builder.round_rect(at, Vector2(box.x, box.y - edge), r), face)

## A bevelled piece: the lip in `lip`, the face over it in `rim`, and the
## crown BEVEL down and in from the rim in `face`, so the piece is lit along
## its top and sides. `bevel` is in pixels.
func _piece(b, at: Vector2, box: Vector2, r: float, edge: float, bevel: float,
		face: Color, rim: Color, lip: Color, xf := Transform2D.IDENTITY) -> void:
	b.fan(xf * Face.Builder.round_rect(at, box, r), lip)
	b.fan(xf * Face.Builder.round_rect(at, Vector2(box.x, box.y - edge), r), rim)
	b.fan(xf * Face.Builder.round_rect(at + Vector2(bevel * 0.7, bevel),
		Vector2(box.x - bevel * 1.4, box.y - edge - bevel), maxf(r - bevel * 0.5, 0.0)), face)

## A bed sunk into the card: its shadow lip along the top in `shade`, the
## floor over it `lip` pixels down.
func _bed(b, at: Vector2, box: Vector2, r: float, lip: float, floor_col: Color, shade: Color,
		xf := Transform2D.IDENTITY) -> void:
	b.fan(xf * Face.Builder.round_rect(at, box, r), shade)
	b.fan(xf * Face.Builder.round_rect(at + Vector2(0.0, lip), Vector2(box.x, box.y - lip), r),
		floor_col)

## A wall: a bed sunk into the card in the family's warm stone, with a leaf
## pressed into its floor. It is a hole in the field and not a blank tile.
func _wall(cell: Vector2i, alpha: float, t: float) -> void:
	_rm.put(SHAPE_WALL, [Color(BED_SHADE, alpha), Color(BED, alpha), Color(Pal.TEXT, WALL_LEAF_INK * alpha)],
		_cell_xf(cell, t) * _at_corner(_corner(cell)))

## A cell's own tone, -1 to 1, off its hash.
static func _tone(cell: Vector2i) -> float:
	return _hash(cell.x * 16 + cell.y, 3) * 2.0 - 1.0

static func _toned(c: Color, tone: float) -> Color:
	return c.lightened(tone * TONE) if tone > 0.0 else c.darkened(-tone * TONE)

## One open tile: a paper piece toned off its cell, lit toward the sun while
## it is on the trail being traced, or its word's pale once the wave has
## reached it; shining while the solve hop crosses it, and wearing whatever
## else it is wearing this frame.
func _tile(cell: Vector2i, t: float, alpha := 1.0) -> void:
	var tone := _tone(cell)
	var face: Color = _toned(Pal.SURFACE.lerp(Pal.SURFACE_HI, PAPER_CROWN), tone)
	var rim: Color = Pal.SURFACE
	var lip: Color = Pal.SURFACE_HI.lerp(Pal.LINE, PAPER_LIP)
	var i := _lit_word(cell, t)
	if i >= 0:
		face = _toned(WORD_TILES[i % WORD_TILES.size()], tone)
		if _state.shown.has(i):
			# Shown, not found: the word's pale washed half-way to paper.
			face = face.lerp(Pal.SURFACE, 0.45)
		rim = face.lerp(Pal.SURFACE, RIM_LIGHT)
		lip = face.lerp(WORD_DEEPS[i % WORD_DEEPS.size()], FOUND_RIM)
	elif _trail.has(cell):
		face = face.lerp(Pal.SUN_RAY, TRAIL_LIT)
		rim = rim.lerp(Pal.SUN_RAY, TRAIL_LIT * 0.5)
		lip = lip.lerp(Pal.SUN, TRAIL_LIT)
	var shine := _solve_shine(cell, t)
	if shine > 0.0:
		face = face.lerp(Pal.SURFACE, shine * SHINE)
		rim = rim.lerp(Pal.SURFACE, shine * SHINE)
	_rm.put(SHAPE_TILE, [Color(lip, alpha), Color(rim, alpha), Color(face, alpha)],
		_tile_xf(cell, t) * _at_corner(_corner(cell)))

## How far into the solve hop `cell` is, as the light's level: nothing either
## side of its hop, all of it at the top.
func _solve_shine(cell: Vector2i, t: float) -> float:
	if _solved_at < 0.0 or Motion.reduce:
		return 0.0
	var since := t - _solved_at - Motion.SOLVE_DELAY - Motion.stagger(cell.x + cell.y, _solve_per())
	if since <= 0.0 or since >= Motion.SOLVE_TIME:
		return 0.0
	return sin(PI * since / Motion.SOLVE_TIME)

## The word whose colour this cell is wearing, or -1: the one that owns it,
## once its wave has reached this far. A lock's wave runs from the word's
## first tile to its last, an undo's and a reset's run back the other way,
## and nothing else lights a tile.
func _lit_word(cell: Vector2i, t: float) -> int:
	var i := _state.word_at(cell)
	if i < 0:
		return -1
	var idx := (_state.words[i]["path"] as Array).find(cell)
	return i if idx >= 0 and float(idx) < _front(i, t) else -1

## How far word `i`'s wave has run, in tiles. A found word fills from 0 to
## its length over `length * WAVE_STEP`; a word that was just lifted drains
## the same way backwards, so the last tile it took is the first it gives up.
## Under reduce-motion there is no wave: a word is whole or it is nothing.
func _front(i: int, t: float) -> float:
	var span := float((_state.words[i]["path"] as Array).size())
	if bool(_state.words[i]["found"]):
		if Motion.reduce or not _found_at.has(i):
			return span
		return clampf((t - float(_found_at[i])) / (span * WAVE_STEP), 0.0, 1.0) * span
	if Motion.reduce or not _lifted_at.has(i):
		return 0.0
	return (1.0 - clampf((t - float(_lifted_at[i])) / (span * WAVE_STEP), 0.0, 1.0)) * span

## What any cell wears this frame, wall or tile, as a rotation, a scale and
## a lift about its own centre: the entrance's cascade, the droop when the
## wishes run out, and the party's dance.
func _cell_pose(cell: Vector2i, t: float) -> Vector3:
	var grow := 1.0
	var lift := 0.0
	var turn := 0.0
	if Motion.reduce:
		return Vector3(turn, grow, lift)
	var s := _cell()
	var since := t - _opened - Motion.ENTER_DELAY - Motion.stagger(cell.x + cell.y, CASCADE)
	if since < Motion.POP_IN:
		grow *= Motion.pop_in_scale(since).x
	if t - _perk_at < 1.5:
		grow *= Motion.bump_scale(t - _perk_at - Motion.stagger(cell.x + cell.y, CASCADE))
	if _droop_at > NEVER:
		var u := clampf((t - _droop_at - float(cell.x + cell.y * _state.n) * DROOP_STEP) / DROOP_TIME, 0.0, 1.0)
		var e := u * u * (3.0 - 2.0 * u)
		lift += e * DROOP_SAG * s
		turn += e * DROOP_TILT * (_hash(cell.x, cell.y) * 2.0 - 1.0)
	if _party_at > NEVER:
		var d := t - _party_at
		if d >= 0.0 and d < float(DANCE_BEATS) * DANCE_BEAT:
			var beat := int(d / DANCE_BEAT)
			var side := 1.0 if (cell.x + cell.y + beat) % 2 == 0 else -1.0
			var k := sin(PI * fmod(d, DANCE_BEAT) / DANCE_BEAT)
			turn += side * DANCE_TILT * k
			lift += DANCE_HOP * s * k
	return Vector3(turn, grow, lift)

## A pose about `mid` as a transform: turn and scale about the centre, then
## lift.
static func _posed(mid: Vector2, turn: float, grow: float, lift: float) -> Transform2D:
	var xf := Transform2D(turn, Vector2.ONE * grow, 0.0, Vector2.ZERO)
	xf.origin = mid + Vector2(0.0, lift) - xf.basis_xform(mid)
	return xf

func _cell_xf(cell: Vector2i, t: float) -> Transform2D:
	var p := _cell_pose(cell, t)
	return _posed(_centre(cell), p.x, p.y, p.z)

## What a tile wears this frame, as one transform about its own centre: the
## wave's bump as the colour reaches it, the finger's press (the tile under
## it, and the rest of the trail half-way into the same press) and the hop
## as it is taken, a wrong trail's head-shake, the gags, and the solve
## wave's hop from the top-left corner -- over the pose every cell wears.
## Every one of them is a reader off core/motion.gd handed the seconds since
## its moment began.
func _tile_xf(cell: Vector2i, t: float) -> Transform2D:
	if t != _xf_t:
		_xf_t = t
		_xf_memo.clear()
	var hit = _xf_memo.get(cell)
	if hit != null:
		return hit
	var xf := _tile_pose(cell, t)
	_xf_memo[cell] = xf
	return xf

func _tile_pose(cell: Vector2i, t: float) -> Transform2D:
	var pose := _cell_pose(cell, t)
	var turn := pose.x
	var grow := pose.y
	var lift := pose.z
	var s := _cell()
	var i := _lit_word(cell, t)
	if i >= 0 and _found_at.has(i):
		var idx := (_state.words[i]["path"] as Array).find(cell)
		var wave := float(_found_at[i]) + float(idx) * _wave_step()
		grow *= Motion.bump_scale(t - wave)
		lift += Motion.hop_lift(t - wave, LOCK_HOP * s)
	if cell == _press_cell:
		grow *= Motion.press_scale(t - _press_at, -1.0 if _press_up < 0.0 else t - _press_up)
	elif not Motion.reduce and _trail.has(cell):
		grow *= lerpf(1.0, Motion.PRESS_SCALE, 0.5)
	if not Motion.reduce:
		if _taken_at.has(cell) and _trail.has(cell):
			lift += Motion.hop_lift(t - float(_taken_at[cell]), TAKE_HOP * s, TAKE_TIME)
		if _miss_path.has(cell):
			turn += Motion.wobble_angle(t - _miss_at - float(_miss_path.find(cell)) * 0.02,
				MISS_WOBBLE, MISS_TIME)
		var owner := _state.word_at(cell)
		if owner >= 0 and _lifted_at.has(owner):
			var idx := (_state.words[owner]["path"] as Array).find(cell)
			var span := (_state.words[owner]["path"] as Array).size()
			var gone := float(_lifted_at[owner]) + float(span - 1 - idx) * WAVE_STEP
			lift += Motion.hop_lift(t - gone, LIFT_DIP * s)
		if owner >= 0 and _gags.has(owner):
			var g: Dictionary = _gags[owner]
			var idx := (_state.words[owner]["path"] as Array).find(cell)
			var since := t - float(g["at"])
			if g["kind"] == "conga":
				for lap in 2:
					lift += Motion.hop_lift(since - float(idx + lap * 4) * CONGA_STEP,
						CONGA_HOP * s, Motion.HOP_TIME)
			elif g["kind"] == "twirl" and idx == 0 and since >= 0.0 and since < TWIRL_TIME:
				var u := since / TWIRL_TIME
				turn += TAU * (u * u * (3.0 - 2.0 * u))
				lift += sin(PI * u) * TWIRL_HOP * s
	if _solved_at >= 0.0:
		lift += Motion.hop_lift(t - _solved_at - Motion.SOLVE_DELAY
			- Motion.stagger(cell.x + cell.y, _solve_per()), Motion.SOLVE_HOP, Motion.SOLVE_TIME)
	return _posed(_centre(cell), turn, grow, lift)

## Every locked word's ribbon, then the beam under the finger and the one a
## release let go of. A ribbon is a rounded polyline through the path's cell
## centres: the corners are filleted into the centreline rather than joined,
## because a stroke's own join pinches at ninety degrees and two overlapping
## strokes at half alpha would darken where they cross.
func _ribbons(t: float) -> void:
	var s := _cell()
	for i in _state.words.size():
		var front := _front(i, t)
		if front <= 0.0:
			continue
		_rm.open(PART_RIBBON, i)
		var colour := Color(WORD_COLS[i % WORD_COLS.size()], SHOWN_ALPHA if _state.shown.has(i) else RIBBON_ALPHA)
		var span := float((_state.words[i]["path"] as Array).size())
		var b := Face.Builder.new()
		if front >= span and not _relaid():
			# A whole ribbon is the word's own shape, made once.
			_rm.put(SHAPE_RIBBON + i, [colour], Transform2D.IDENTITY)
		else:
			# `front` counts tiles and `reach` segments, and the partial one is
			# interpolated, so the head of the ribbon travels rather than
			# jumping from tile to tile.
			_ribbon(b, _state.words[i]["path"], s * RIBBON_W, colour, maxf(front - 1.0, 0.0))
		_glint(b, i, t)
		_rm.put_builder(b)
	_rm.open(PART_BEAM, 0)
	var b := Face.Builder.new()
	_beam(b, t)
	_rm.put_builder(b)

## The beam under the finger and the one a release let go of, drawn live.
func _beam(b, t: float) -> void:
	var s := _cell()
	if not _ghost.is_empty():
		var u := clampf((t - float(_ghost["at"])) / BEAM_TIME, 0.0, 1.0)
		if u >= 1.0 or Motion.reduce:
			_ghost = {}
		else:
			var path: Array = _ghost["path"]
			_ribbon(b, path, s * BEAM_W,
				Color(Pal.SUN_RAY, GHOST_ALPHA * (1.0 - u)),
				float(path.size() - 1) * (1.0 - u))
	if not _trail.is_empty():
		# The beam grows from the tile before the finger to the finger over
		# BEAM_TIME; a retraction takes it straight back, because the finger
		# has already gone. No growth under reduce-motion.
		var span := float(_trail.size() - 1)
		var reach := span
		if not Motion.reduce and span > 0.0:
			reach = minf(span, maxf(span - 1.0, 0.0)
				+ clampf((t - _beam_at) / BEAM_TIME, 0.0, 1.0))
		_ribbon(b, _trail, s * BEAM_W, Color(Pal.SUN_RAY, BEAM_ALPHA), reach)
		# The head: a sun disc over a soft halo, wherever the beam has got to.
		var pts := PackedVector2Array()
		for cell: Vector2i in _trail:
			pts.append(_centre(cell))
		var head := _upto(pts, reach)[-1]
		Scenery.soft_disc(b, head, s * HALO_R, s * HALO_R, Color(Pal.SUN_RAY, HALO_A))
		b.disc(head, s * HEAD_R, Color(Pal.SUN, BEAM_ALPHA))

## The light running down word `i`'s ribbon once its wave has finished: a
## short, pale stroke inside the ribbon, head first from the first letter to
## the last. Nothing under reduce-motion or on a word with no moment.
func _glint(b, i: int, t: float) -> void:
	if Motion.reduce or not _found_at.has(i) or not bool(_state.words[i]["found"]):
		return
	var path: Array = _state.words[i]["path"]
	var span := float(path.size() - 1)
	var since := t - float(_found_at[i]) - float(path.size()) * WAVE_STEP
	if since <= 0.0 or span <= 0.0:
		return
	var lead := since / GLINT_STEP
	var from := clampf(lead - GLINT_LEN, 0.0, span)
	var to := clampf(lead, 0.0, span)
	if to - from <= 0.01:
		return
	var pts := PackedVector2Array()
	for cell: Vector2i in path:
		pts.append(_centre(cell))
	var fade := 1.0 - clampf((lead - span) / GLINT_LEN, 0.0, 1.0)
	b.stroke(_between(pts, from, to), _cell() * RIBBON_W * GLINT_W,
		Color(Pal.SURFACE, GLINT_A * fade))

## How long word `i`'s glint runs after its wave, head in to tail out.
func _glint_length(i: int) -> float:
	return (float((_state.words[i]["path"] as Array).size() - 1) + GLINT_LEN) * GLINT_STEP

## The part of `pts` from `a` segments along to `b` segments along.
static func _between(pts: PackedVector2Array, a: float, b: float) -> PackedVector2Array:
	var upto := _upto(pts, b)
	var whole := clampi(int(floor(a)), 0, upto.size() - 1)
	var out := PackedVector2Array()
	if whole + 1 < upto.size():
		out.append(upto[whole].lerp(upto[whole + 1], a - float(whole)))
	for k in range(whole + 1, upto.size()):
		out.append(upto[k])
	return out

## One ribbon along `cells`, `reach` segments of it (all of them by default).
func _ribbon(b, cells: Array, width: float, colour: Color, reach := -1.0) -> void:
	if cells.is_empty() or width <= 0.0:
		return
	var pts := PackedVector2Array()
	for cell: Vector2i in cells:
		pts.append(_centre(cell))
	if reach >= 0.0:
		pts = _upto(pts, reach)
	if pts.size() < 2:
		if pts.size() == 1:
			b.disc(pts[0], width * 0.5, colour)
		return
	var line := _filleted(pts, width * 0.5)
	b.stroke(line, width, colour, false, false)
	_cap(b, line[0], line[0] - line[1], width * 0.5, colour)
	_cap(b, line[-1], line[-1] - line[-2], width * 0.5, colour)

## A round end on a flat-ended stroke: the half disc facing `out`. A whole
## disc laid over the stroke's end, which is what the builder's own caps are,
## doubles the alpha where the two overlap, and a half-alpha ribbon wore a
## darker crescent at each end.
static func _cap(b, at: Vector2, out: Vector2, r: float, colour: Color) -> void:
	if out.length_squared() <= 0.0:
		return
	var a := out.angle()
	b.fan(Face.Builder.arc_points(at, r, a - PI * 0.5, a + PI * 0.5), colour)

## The first `reach` segments of `pts`, the last one cut part-way.
static func _upto(pts: PackedVector2Array, reach: float) -> PackedVector2Array:
	if pts.size() < 2:
		return pts
	var out := PackedVector2Array([pts[0]])
	var whole := clampi(int(floor(reach)), 0, pts.size() - 1)
	for i in range(1, whole + 1):
		out.append(pts[i])
	var frac := reach - float(whole)
	if frac > 0.0 and whole + 1 < pts.size():
		out.append(pts[whole].lerp(pts[whole + 1], frac))
	return out

## `pts` with every corner cut back by `r` and bridged with a quadratic, so a
## stroke along it turns rather than pinching. A straight run is left alone.
static func _filleted(pts: PackedVector2Array, r: float) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var here := pts[i]
		var back := (pts[i - 1] - here).normalized()
		var on := (pts[i + 1] - here).normalized()
		if back.dot(on) < -0.99:
			continue
		var cut := minf(r, minf(pts[i - 1].distance_to(here), pts[i + 1].distance_to(here)) * 0.5)
		var a := here + back * cut
		var c := here + on * cut
		out.append_array(Face.Builder.bezier2(a, here, c, 6))
		out.append(c)
	out.append(pts[pts.size() - 1])
	return out

## A leaf: the mock's two quadratics, turned by `angle` about its stem.
func _leaf(b, at: Vector2, length: float, angle: float, colour: Color) -> void:
	b.polygon(Transform2D(angle, at) * _leaf_points(length), colour)

static func _leaf_points(length: float) -> PackedVector2Array:
	var tip := Vector2(length, 0.0)
	var pts := Face.Builder.bezier2(Vector2.ZERO, Vector2(length * 0.55, -length * 0.42), tip, 10)
	pts.append_array(Face.Builder.bezier2(tip, Vector2(length * 0.55, length * 0.42), Vector2.ZERO, 10))
	return pts

## The glow a hint leaves on a tile: a pale wash under a dashed outline,
## which stays until that word is found. A hint is a given, and every board
## in this game says so in the same language.
func _glow(i: int, t: float) -> void:
	if bool(_state.words[i]["found"]):
		return
	var shown := _state.hint_shown(i)
	if shown <= 0:
		return
	var path: Array = _state.words[i]["path"]
	for k in mini(shown, path.size()):
		# The glow rides its tile: it is part of that cell's face, so it takes
		# the press and the hop with it rather than sitting still under one.
		_rm.put(SHAPE_GLOW, [Color(Pal.SUN_RAY, GLOW_ALPHA), Pal.SUN_DEEP],
			_tile_xf(path[k], t) * _at_corner(_corner(path[k])))

## The closed outline `pts` cut into dashes of `on` with `off` between them.
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

## The slot group the trail being traced is spelt into, or -1: the smallest
## unfound word it still fits, the first of those in the slots' order, so a
## growing trail steps along to the next size up as it outgrows each one.
## It says nothing about whether the trail is right -- only lengths are a
## clue here, and the preview spends no more of one than the slots already do.
func _preview_slot() -> int:
	if _trail.is_empty():
		return -1
	var best := -1
	var best_len := 0
	for i in _state.words.size():
		if bool(_state.words[i]["found"]):
			continue
		var n := (_state.words[i]["path"] as Array).size()
		if n >= _trail.size() and (best < 0 or n < best_len):
			best = i
			best_len = n
	return best

## The empty length boxes, and the ones a word's wave has reached. Each line
## is centred across the card and the block is centred in the slots' band.
## The groups drop in after the field, ENTER_STAGGER apart -- a group and not
## a box, because six boxes 0.03 apart is one box.
func _build_slots(t: float) -> ArrayMesh:
	var q := _slot_k()
	var lines := _slot_lines(q)
	if lines.is_empty():
		return null
	var box := Vector2(SLOT_W, SLOT_H) * q
	_lay_slot_runs(q)
	_sm.begin()
	var y := _slots_block_top(lines, q)
	var group := 0
	var run := 0
	var preview := _preview_slot()
	for line in lines:
		var x := _slots_left(float(line["w"]))
		for item in line["items"]:
			var i: int = item["i"]
			var since := _slot_since(group, t)
			var seen := Motion.appear_level(since)
			var span: int = (_state.words[i]["path"] as Array).size()
			if seen > 0.0:
				var drop := Transform2D(0.0, Vector2(0.0, -Motion.drop_in_lift(since)))
				var front := _front(i, t)
				var deep: Color = WORD_DEEPS[i % WORD_DEEPS.size()]
				for k in span:
					_sm.open(0, run + k)
					var at := Vector2(x + float(k) * (SLOT_W + SLOT_GAP) * q, y)
					var rest := BED.lerp(Pal.SUN_RAY, PREVIEW_FILL * 0.4) \
						if i == preview and k >= _trail.size() else BED
					_sm.put(SLOT_BED, [Color(BED_SHADE, seen), Color(rest, seen)],
						drop * Transform2D(0.0, Vector2.ONE * (q / _ref_q), 0.0, at))
					# A lit box is a piece in its word's pale popping into its
					# bed as the wave brings its letter; the trail being traced,
					# spelt into the slot it fits, stands on paper lit toward
					# the sun, each piece popping in as the finger reaches it.
					var face := Color(0.0, 0.0, 0.0, 0.0)
					var rim: Color
					var lip: Color
					var moment := -100.0
					if float(k) < front:
						face = WORD_TILES[i % WORD_TILES.size()]
						rim = face.lerp(Pal.SURFACE, RIM_LIGHT)
						lip = face.lerp(deep, SLOT_RIM)
						moment = _slot_wave(i, k, t)
					elif i == preview and k < _trail.size():
						face = Pal.SURFACE.lerp(Pal.SUN_RAY, PREVIEW_FILL)
						rim = Pal.SURFACE
						lip = Pal.SUN
						if k == _trail.size() - 1:
							moment = _grew_at
					if face.a <= 0.0:
						continue
					var pop := Motion.pop_in_scale(t - moment)
					if pop.x <= 0.0:
						continue
					var mid := at + box * 0.5
					var hop := _slot_hop(i, k, t) * q if float(k) < front else 0.0
					var xf := Transform2D(0.0, Vector2(0.0, hop)) * drop \
						* Transform2D(0.0, pop, 0.0, mid - mid * pop)
					_sm.put(SLOT_PIECE, [Color(lip, seen), Color(rim, seen), Color(face, seen)],
						xf * Transform2D(0.0, Vector2.ONE * (q / _ref_q), 0.0, at))
			x += float(item["w"]) + GROUP_GAP * q
			group += 1
			run += span
		y += (SLOT_H + LINE_GAP) * q
	return _sm.mesh()

## A run for every box, a bed and a piece long, laid in the slots' order;
## again only when the boxes' scale or the board changes.
func _lay_slot_runs(q: float) -> void:
	var key := [_gen]
	if _sm.laid() and key == _sm_key and q <= _ref_q + 0.01:
		return
	_sm_key = key
	_ref_q = q
	_sm.reset()
	var room := _sm.size_of(SLOT_BED) + _sm.size_of(SLOT_PIECE)
	var boxes := 0
	for w in _state.words:
		boxes += (w["path"] as Array).size()
	for k in boxes:
		_sm.room(0, k, room)

## A slot box's bed or piece about its top-left corner, at the scale the
## slot runs are laid at, in slot colours.
func _slot_shape(id: int) -> Face.Builder:
	var q := _ref_q
	var b := Face.Builder.new()
	var box := Vector2(SLOT_W, SLOT_H) * q
	var r := SLOT_RADIUS * q
	if id == SLOT_BED:
		_bed(b, Vector2.ZERO, box, r, SLOT_EDGE * q, RunMesh.slot(1), RunMesh.slot(0))
	else:
		_piece(b, Vector2.ZERO, box, r, SLOT_EDGE * q, SLOT_BEVEL * q,
			RunMesh.slot(2), RunMesh.slot(1), RunMesh.slot(0))
	return b

## The seconds since slot group `index` was due to drop in: after the field's
## own pop, then the stagger.
func _slot_since(index: int, t: float) -> float:
	return t - _opened - Motion.ENTER_DELAY - Motion.ENTER_POP \
		- Motion.stagger(index, Motion.ENTER_STAGGER)

## The field's letters, over the mesh: ink on a free tile, the word's deep
## once the wave has reached it. One draw command each, and only when
## something changed. Each letter takes its own tile's transform and the
## field's entrance on top of it, so the glyph and the slab under it are one
## piece (Nonogram's clue numbers, through draw_set_transform).
func _draw_letters(t: float, grow: float, mid: Vector2, seen: float) -> void:
	var s := _cell()
	var font: Font = CozyTheme.display(700)
	# Mosaic.letter sizes a glyph at its own LETTER_SIZE of the box it is
	# handed; this board's letter is LETTER of the cell, so the box is scaled
	# rather than the constant copied.
	var box := s * LETTER / Mosaic.LETTER_SIZE
	var px := int(box * Mosaic.LETTER_SIZE)
	var levels: Dictionary = _levels(t) if _state.night() else {}
	for cell: Vector2i in _state.letters:
		var lv: float = levels.get(cell, 1.0)
		if lv <= 0.0:
			continue
		var i := _lit_word(cell, t)
		var ink: Color = WORD_DEEPS[i % WORD_DEEPS.size()] if i >= 0 else Pal.TEXT
		var xf := _tile_xf(cell, t)
		var at := (xf * _centre(cell)) * grow + mid * (1.0 - grow)
		_letter(font, px, at, String(_state.letters[cell]), xf.get_rotation(),
			xf.get_scale().x * grow, ink, seen * lv)

## A word's letters, dropping into its slot group in its own deep as the
## wave reaches each tile. The box's own entrance drop carries the letter
## with it; the letter's arrival is a third of the family's drop over it, so
## it settles into a box that has already landed.
func _draw_slot_letters(t: float) -> void:
	var q := _slot_k()
	var lines := _slot_lines(q)
	if lines.is_empty():
		return
	var font: Font = CozyTheme.display(700)
	var px := int(round(SLOT_FONT * q))
	var y := _slots_block_top(lines, q)
	var group := 0
	var preview := _preview_slot()
	# The glyph sits on the piece's crown, which is the edge's height up.
	var seat := (SLOT_H - SLOT_EDGE) * 0.5 * q
	for line in lines:
		var x := _slots_left(float(line["w"]))
		for item in line["items"]:
			var i: int = item["i"]
			var since := _slot_since(group, t)
			var seen := Motion.appear_level(since)
			var front := _front(i, t)
			if seen > 0.0 and i == preview:
				var lift := Motion.drop_in_lift(since)
				for k in _trail.size():
					var grew := Motion.pop_in_scale(t - (_grew_at if k == _trail.size() - 1 else -100.0))
					# A glyph smaller than this is not there yet, and a font
					# size of nought is an engine error.
					if px * grew.y < 4.0:
						continue
					_glyph(font, int(round(px * grew.y)), String(_state.letters[_trail[k]]),
						Color(Pal.TEXT, seen),
						Vector2(x + (float(k) * (SLOT_W + SLOT_GAP) + SLOT_W * 0.5) * q,
							y + seat - lift))
			if seen > 0.0 and front > 0.0:
				var word: String = _state.words[i]["word"]
				var ink: Color = WORD_DEEPS[i % WORD_DEEPS.size()]
				var box_lift := Motion.drop_in_lift(since)
				for k in mini(word.length(), int(ceil(front))):
					if float(k) >= front:
						break
					var wave := _slot_wave(i, k, t)
					# A quarter of its own box, through the recipe's own
					# height: the family's 40 is most of a 52-tall slot, and
					# a letter would arrive from the line above.
					var fell := Motion.drop_in_lift(t - wave, SLOT_H * 0.25 * q)
					_glyph(font, px, word.substr(k, 1),
						Color(ink, ink.a * seen * Motion.appear_level(t - wave)),
						Vector2(x + (float(k) * (SLOT_W + SLOT_GAP) + SLOT_W * 0.5) * q,
							y + seat - box_lift - fell + _slot_hop(i, k, t) * q))
			x += float(item["w"]) + GROUP_GAP * q
			group += 1
		y += (SLOT_H + LINE_GAP) * q

## When word `i`'s slot group starts its hop: once its last letter has
## dropped into its box.
func _slot_hop_from(i: int) -> float:
	var span := float((_state.words[i]["path"] as Array).size())
	return float(_found_at.get(i, -100.0)) + span * WAVE_STEP + Motion.DROP_TIME

## How far box `k` of word `i` is lifted this frame by that hop, in the
## mock's pixels. Nothing for a shown word, which is not a win.
func _slot_hop(i: int, k: int, t: float) -> float:
	if Motion.reduce or not _found_at.has(i) or _state.shown.has(i) or not bool(_state.words[i]["found"]):
		return 0.0
	return Motion.hop_lift(t - _slot_hop_from(i) - float(k) * SLOT_HOP_STEP, SLOT_HOP)

## When word `i`'s wave reached its k-th tile, and so when that letter is due
## in its box. A word being lifted has no moment to drop from -- it is going,
## not coming -- so its letters are simply there until the wave passes them.
func _slot_wave(i: int, k: int, t: float) -> float:
	if Motion.reduce or not bool(_state.words[i]["found"]) or not _found_at.has(i):
		return -100.0
	return float(_found_at[i]) + float(k) * WAVE_STEP

# --- the scenery band ---

## The band the field and the slots leave at the card's foot, laid the way
## Balance's and Hidden Word's are: two of the family's clouds high in it, a
## washed turf with a lighter crown along its top, blades standing out of
## that, and three bushes on the ground line. The clouds are
## ui/flat/scenery.gd's own shape, appended to this board's builder rather
## than standing a Scenery node up for two of them, so the whole band is one
## draw call. It never moves -- only the field takes the entrance -- so it is
## built once per layout and drawn with no transform.
func _build_band() -> ArrayMesh:
	var top := _slots_top() + _slots_room()
	var tall := size.y - INSET - top
	if _cell() <= 0.0 or tall <= 0.0:
		return null
	var b := Face.Builder.new()
	var x0 := INSET
	var w := size.x - 2.0 * INSET
	var ground := top + tall - BAND_FOOT - TURF_TOP
	var puff: Color = Pal.PARCHMENT.lerp(Pal.SURFACE, Scenery.CLOUD_LIFT)
	Scenery.cloud(b, Vector2(x0 + CLOUD_LEFT.x, top + CLOUD_LEFT.y), CLOUD_LEFT.z, puff)
	Scenery.cloud(b, Vector2(x0 + w - CLOUD_RIGHT.x, top + CLOUD_RIGHT.y), CLOUD_RIGHT.z, puff)
	var turf: Color = Pal.LEAF.lerp(Pal.PARCHMENT, TURF_WASH)
	var crown: Color = Pal.LEAF_LIGHT.lerp(Pal.PARCHMENT, CROWN_WASH)
	b.fan(Face.Builder.round_rect(Vector2(x0, ground),
		Vector2(w, tall - BAND_FOOT - (ground - top)), TURF_RADIUS), turf)
	b.fan(Face.Builder.round_rect(Vector2(x0, ground), Vector2(w, CROWN_H), CROWN_RADIUS), crown)
	var blade: Color = Pal.LEAF.lerp(Pal.PARCHMENT, BLADE_WASH)
	var step := (w - BLADE_EDGE * 2.0) / float(BLADES - 1)
	for i in BLADES:
		var x := x0 + BLADE_EDGE + float(i) * step
		var h := BLADE_MIN + _hash(i, 5) * BLADE_SPREAD
		var lean := (_hash(i, 9) - 0.5) * BLADE_LEAN
		var foot := Vector2(x - BLADE_W, ground + BLADE_ROOT)
		var tip := Vector2(x + BLADE_W, ground + BLADE_ROOT)
		var pts := Face.Builder.bezier2(foot, Vector2(x + lean, ground - h), tip, 8)
		pts.append(tip)
		b.polygon(pts, blade)
	var deep: Color = Pal.LEAF_DEEP.lerp(Pal.PARCHMENT, BUSH_DEEP_WASH)
	var lit: Color = Pal.LEAF.lerp(Pal.PARCHMENT, BUSH_LIT_WASH)
	for bush: Vector2 in BUSHES:
		_bush(b, _span(x0, w, bush.x), ground, bush.y, deep, lit)
	return b.mesh() if not b.verts.is_empty() else null

## The mock's own x convention for a thing on the band: a fraction of the
## width between 0 and 1, so many pixels in from the left above that, and so
## many in from the right when it is negative.
static func _span(x0: float, w: float, x: float) -> float:
	if x > 0.0 and x < 1.0:
		return x0 + w * x
	return x0 + (x if x >= 0.0 else w + x)

## Three deep puffs with a lit one on the shoulder, seated on the ground
## line: the same bush Hidden Word's band stands on its turf.
func _bush(b, x: float, ground: float, r: float, deep: Color, lit: Color) -> void:
	b.disc(Vector2(x, ground - r * 0.58), r, deep)
	b.disc(Vector2(x - r * 0.82, ground - r * 0.24), r * 0.64, deep)
	b.disc(Vector2(x + r * 0.84, ground - r * 0.26), r * 0.6, deep)
	b.disc(Vector2(x - r * 0.24, ground - r * 0.9), r * 0.4, lit)

## A settled number in 0..1 from two ints: what keeps the blades from
## standing in a comb without a seeded generator in the drawing.
static func _hash(a: int, b: int) -> float:
	return float(posmod(hash(Vector2i(a, b)), 1000)) / 1000.0

## One field letter centred on `at`, turned and scaled with its tile --
## Mosaic.letter's recipe with the tile's turn, because a twirling or
## dancing tile carries its glyph.
func _letter(font: Font, px: int, at: Vector2, ch: String, turn: float, grow: float,
		ink: Color, alpha: float) -> void:
	if ch.is_empty() or alpha <= 0.0 or grow <= 0.0 or px <= 0:
		return
	var text := ch.to_upper()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var where := Vector2(-w * 0.5, font.get_height(px) * 0.5 - font.get_descent(px))
	draw_set_transform(at, turn, Vector2.ONE * grow)
	font.draw_string(get_canvas_item(), where, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(ink, ink.a * alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## One glyph centred on `at`, as Nonogram centres a clue number.
func _glyph(font: Font, px: int, text: String, ink: Color, at: Vector2) -> void:
	if ink.a <= 0.0:
		return
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	var rise := font.get_height(px) * 0.5 - font.get_descent(px)
	draw_string(font, at + Vector2(-wide * 0.5, rise), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, ink)

# --- the moments ---

## The chrome is the host's. The field's own entrance is one wide pop about
## its centre while it fades in (rule 7), and the slot groups drop in behind
## it; both are read off the clock in _draw, so all this has to do is start
## it. _animating() knows how long it runs.
func _enter() -> void:
	_opened = _now()
	fx.cue("enter")
	_refresh()

# --- input ---

## A press, a drag and a release, as every flat board takes them. A trail
## grows one side-adjacent tile at a time and never crosses a wall or a word
## already found; dragging back over the tile before the last one retracts
## the beam rather than doubling it.
func _gui_input(event: InputEvent) -> void:
	if _done or out_of_hearts or _revealing:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed
		var cell := _cell_at(event.position)
		if pressed:
			if cell.x >= 0 and _state.can_trace(cell):
				_trail = [cell]
				_take(cell)
				_tick()
				_lamp_to(cell, true)
				_refresh()
				accept_event()
			elif _state.night() and _near_cell(event.position).x >= 0:
				# In the dark a press anywhere on the field lights the lantern,
				# a wall or a found word included: looking is free.
				_lamp_to(_near_cell(event.position), true)
				_refresh()
				accept_event()
		else:
			if _press_cell.x >= 0 and _press_up < 0.0:
				_press_up = _now()
				_busy_for(Motion.RELEASE_TIME)
			if not _trail.is_empty():
				# Let go off the field and the trail is put down, never tried:
				# the way out of a trail without spending a wish.
				_release(_off_field(event.position))
				accept_event()
			_lamp_off()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _lamp_on and _trail.is_empty():
		var near := _near_cell(event.position)
		if near.x >= 0 and near != _lamp_cell:
			_lamp_to(near)
			_refresh()
		accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and not _trail.is_empty():
		var cell := _cell_at(event.position)
		if cell.x < 0:
			return
		var at := _trail.find(cell)
		# `at >= 0` matters: on a trail of one, find()'s -1 for a cell that is
		# not on it is also `size - 2`, and the retraction would empty the
		# trail mid-drag and leave the finger holding nothing.
		if at >= 0 and at == _trail.size() - 2:
			_trail.resize(_trail.size() - 1)          # retracting takes the beam back
			_take(_trail[_trail.size() - 1], false)
			_tick()
		elif at < 0 and _state.can_trace(cell) and _adjacent(_trail[_trail.size() - 1], cell):
			_trail.append(cell)
			_take(cell)
			_tick()
		if _lamp_on:
			_lamp_to(_trail[_trail.size() - 1])
		_refresh()
		accept_event()

## The cell nearest a local point on the field, gaps included, or (-1, -1)
## off it: where the lantern shines when the finger is between two tiles.
func _near_cell(local: Vector2) -> Vector2i:
	var cell := _cell()
	if cell <= 0.0 or _off_field(local):
		return Vector2i(-1, -1)
	var p := (local - _origin() + Vector2.ONE * GAP * 0.5) / (cell + GAP)
	return Vector2i(clampi(int(floor(p.x)), 0, _state.n - 1), clampi(int(floor(p.y)), 0, _state.n - 1))

## Whether a local point is off the field, by more than half a gap.
func _off_field(local: Vector2) -> bool:
	var o := _origin() - Vector2.ONE * GAP * 0.5
	var w := _field_size() + GAP
	return local.x < o.x or local.y < o.y or local.x > o.x + w or local.y > o.y + w

## The finger has arrived on `cell`: the beam starts growing toward it and
## the tile under it starts sinking. The tile it left springs back to the
## trail's own shallower press, which is the mock's behaviour and the reason
## a single pressed cell is enough here.
func _take(cell: Vector2i, grew := true) -> void:
	var t := _now()
	_beam_at = t
	if grew:
		_grew_at = t
		_taken_at[cell] = t
	_press_cell = cell
	_press_at = t
	_press_up = -1.0
	_busy_for(maxf(maxf(BEAM_TIME, Motion.PRESS_TIME), Motion.POP_IN))

## A tile taken or given back: one soft tick that climbs with the trail's
## length (Shikaku's count tick), so a word's size can be heard as it grows
## and a retraction steps back down. Five semitones at most (the cozy rules).
func _tick() -> void:
	fx.cue("select", minf(1.0 + 0.05 * float(_trail.size() - 1), 1.33))

## Side-adjacent, never diagonal. The bending is the whole puzzle, and a
## diagonal step would make a straight line of it.
static func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1

## Let go. A trail locks only if it is one of today's unfound words traced
## along that word's own cells, in order; **anything else simply unwinds** --
## no toast, no shiver, no move counted and no hint spent. The board never
## says no, because it never had to say yes (spec section 3).
func _release(cancel := false) -> void:
	var path := _trail
	_trail = []
	var t := _now()
	# A right word always locks, even let go off the field: it never costs,
	# and a finger drifting past an edge tile must not throw it away.
	# Letting go off the field only spares a wrong trail its wish.
	var i: int = _state.trace(path)
	if i < 0:
		if path.size() > 1 and not Motion.reduce:
			_ghost = {"path": path, "at": t}
			_busy_for(BEAM_TIME)
		if not cancel:
			_missed(path, t)
		_refresh()
		return
	_found_at[i] = t
	_lifted_at.erase(i)
	var cells: Array = _state.words[i]["path"]
	var last: Vector2i = cells[-1]
	var colour: Color = WORD_COLS[i % WORD_COLS.size()]
	# The ring and the sparkles land on the word's last tile when the wave
	# gets there, not when the finger let go, so the colour and the flourish
	# arrive together.
	_fx_at(last, colour, float(cells.size()) * _wave_step())
	_busy_for(float(cells.size()) * _wave_step() + Motion.BUMP_TIME)
	fx.cue("place")
	_rewards(i, t)
	_speak()
	_refresh()
	# note_move() counts the move and ends the puzzle if that was the last
	# word; the host raises the win screen after win_delay().
	note_move()

## A trail let go that is not a word. On Easy and Medium nothing happens (it
## unwinds). On Hard and Insane a trail that could have been a word -- as
## long as one still hiding -- and was never tried blows a seed off the
## dandelion; the last seed is the card. A trail tried before is free, and
## the sprout says so.
func _missed(path: Array, t: float) -> void:
	var plausible: bool = _state.could_be(path)
	var again: bool = plausible and _state.tried.has(State._key(path))
	var cost: bool = _state.miss(path)
	if plausible and not again:
		_streak = 0
	if again and _state.counts_wishes():
		_say(tr("WT_TRIED"), Face.Expr.HAPPY)
		return
	if not cost:
		return
	_miss_path = path
	_miss_at = t
	_blown[_state.misses - 1] = t
	fx.cue("miss")
	# The seed's knock; the last seed's is the droop's.
	if not _state.is_out():
		fx.buzz(Haptics.BAD)
	_after(0.14, fx.cue.bind("wish"))
	_busy_for(maxf(MISS_TIME + 0.02 * float(path.size()), SEED_FLY))
	var left: int = _state.wishes_left()
	if _state.is_out():
		_run_out(t)
	elif left <= 2:
		_after(0.6, fx.cue.bind("wish_low"))
		_say(tr("WT_WISHES_ONE") if left == 1 else tr("WT_WISHES_N") % left, Face.Expr.WORRIED)
	else:
		_say(tr("WT_WISH_GONE") % left, Face.Expr.HAPPY)

# --- the sprout's line ---

func _left_line() -> String:
	var left: int = _state.words.size() - _state.found_count()
	if left <= 0:
		return tr("WT_FILLED")
	return tr("WT_ONE_LEFT") if left == 1 else tr("WT_N_LEFT") % left

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
	if is_done() or _tip_mood != Face.Expr.HAPPY or not _state.order.is_empty():
		return
	var tips := _tips()
	_tip_idx = (_tip_idx + 1) % tips.size()
	_say(tr(tips[_tip_idx]), Face.Expr.HAPPY)

## The sprout's own line, rather than Binairo's cycle of broken rules: there
## is no rule a tap can break on this board.
func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not _state.order.is_empty() and not out_of_hearts and not _revealing

## Reset tells nothing new and gives no wish back, so it is always free --
## but not while the card is up or the words are being shown.
func can_reset() -> bool:
	return not (out_of_hearts or _revealing or is_done())

## Lifts the last word locked. Counts no move.
func undo() -> bool:
	if is_done() or _state.order.is_empty() or out_of_hearts or _revealing:
		return false
	var i: int = _state.order[-1]
	if not _state.undo():
		return false
	_lifted_at[i] = _now()
	_found_at.erase(i)
	# The lock's ring was queued for the moment its wave would have reached
	# the last tile. The word is gone before then, so the ring goes with it
	# -- reset_board() already drops _pending for the same reason.
	var keep: Array = []
	for e: Dictionary in _pending:
		if not (_state.words[i]["path"] as Array).has(e["cell"]):
			keep.append(e)
	_pending = keep
	_trail = []
	_gags.erase(i)
	_lock_gen[i] = int(_lock_gen.get(i, 0)) + 1
	# Undo and lock again is no streak.
	_streak = 0
	_notes = maxi(_notes - 1, 0)
	# The same wave backwards: the last tile the word took is the first it
	# gives up, and its letters leave the slots with it.
	_busy_for(float((_state.words[i]["path"] as Array).size()) * _wave_step()
		+ (0.0 if Motion.reduce else Motion.HOP_TIME))
	_say(tr("WT_TAKEN_BACK") + " " + _left_line(), Face.Expr.HAPPY)
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

func hints_left() -> int:
	return maxi(0, int(HINTS_BY_BAND[_state.band]) + hints_extra - hints_used)

## Lights the next tile of the shortest unfound word's path -- its first
## tile, then its second. That is the one hint this game can give: the words
## are hidden but the letters are not, so the only thing a player can be
## short of is where a word starts.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or out_of_hearts or _revealing:
		return false
	var pick := _state.hint_target()
	if pick < 0:
		return false
	var shown := _state.hint_shown(pick)
	var cell := _state.hint_cell(pick)
	if not _state.hint():
		return false
	hints_used += 1
	if cell.x >= 0:
		_fx_at(cell, Pal.LEAF)
	fx.cue("hint")
	_say(tr("WT_HINT_START") if shown == 0 else tr("WT_HINT_MORE"), Face.Expr.HAPPY)
	_refresh()
	moved.emit()
	return true

## Every locked word unwinds. What a hint gave stays given: the hints spent
## are not refunded, only unpinned.
func reset_board() -> void:
	if not can_reset():
		return
	var t := _now()
	var longest := 0
	for i in _state.order:
		_lifted_at[i] = t
		longest = maxi(longest, (_state.words[i]["path"] as Array).size())
	_state.reset_board()
	_found_at = {}
	_pending = []
	_trail = []
	_ghost = {}
	_press_cell = Vector2i(-1, -1)
	_solved_at = -1.0
	_gags = {}
	_miss_path = []
	_drop_bubble()
	for i in _state.words.size():
		_lock_gen[i] = int(_lock_gen.get(i, 0)) + 1
	_streak = 0
	# Every locked word unwinds at once, each on its own reversed wave, so
	# the board is clear when the longest of them has run.
	_busy_for(float(longest) * _wave_step() + (0.0 if Motion.reduce else Motion.HOP_TIME))
	moves = 0
	_running = true
	_say(tr("WT_CLEAN") + " " + _left_line(), Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

## Shown words fill the field but are no solve.
func is_solved() -> bool:
	return _state.is_solved() and _state.shown.is_empty()

## One line per word in lock order, a tile glyph per letter, so a shared
## board shows the shape of the day and never its answers.
func share_glyphs() -> String:
	var out: Array[String] = []
	for i in _state.order:
		out.append(("🟨" if _state.shown.has(i) else "🟩").repeat((_state.words[i]["path"] as Array).size()))
	if _state.is_solved() and _state.shown.is_empty():
		out.append(("🌙 %s · " % tr("WT_NIGHT_SEAL") if _state.night() else "") + "🏅 " + tr(stamp_key()))
	return "\n".join(out)

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("WT_WIN")}

## Long enough for the wave that won the board and the solve wave after it.
## Under reduce-motion there is neither, so the win follows the last lock
## (spec section 9's reduce-motion row).
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	# The party and the seal play out first (polish spec, section 3).
	return maxf(WIN_WAIT, _party_at + STAMP_AT + STAMP_DROP + 1.2 - _now())

## The solve wave waits for the wave that won it: the last word locked is
## still colouring its way down its own ribbon, and a field hopping through
## that would be two hands at once.
func _on_solved() -> void:
	var t := _now()
	_trail = []
	_ghost = {}
	_press_cell = Vector2i(-1, -1)
	_lamp_on = false
	_drop_bubble()
	var start := t + _wave_left(t)
	if _state.night():
		# Night Walk's dawn: the sky behind the field fades and every tile
		# comes up in a wave from the top-left, then the solve hop.
		_dawn_at = start if not Motion.reduce else t - 100.0
		if not Motion.reduce:
			_after(start - t, fx.cue.bind("dawn"))
			start += DAWN_TIME
	_solved_at = start
	_tip_timer.stop()
	# Gold across the field as the hop reaches each word's last tile, which
	# is the one place on this board a sparkle has ever landed.
	for i in _state.words.size():
		var last: Vector2i = (_state.words[i]["path"] as Array)[-1]
		_fx_at(last, Pal.SUN, _solved_at - t + Motion.SOLVE_DELAY
			+ Motion.stagger(last.x + last.y, _solve_per()), false)
	_busy_for(_solved_at - t + Motion.SOLVE_DELAY + _solve_span() + Motion.SOLVE_TIME)
	_say(tr("WT_WIN"), Face.Expr.JOY)
	_after(_solved_at - t, fx.cue.bind("solved"))
	_party(t)
	_refresh()

## A reopened daily that was already solved: every word of the answer is
## locked at once, in index order, with its ribbon drawn whole, its tiles in
## its colour and its letters in their slots -- no wave, no entrance, no solve
## hop and no sparkle left to run. `order` keeps every word so share_glyphs()
## still has the day's shape; Undo stays off because the board is done. Never
## check_solved(): `solved` must not fire a second time.
func restore_completed_board() -> void:
	_state.order.clear()
	for i in _state.words.size():
		_state.words[i]["found"] = true
		_state.order.append(i)
	# A word with no moment is simply whole (`_front`), so emptying these is
	# what settles every ribbon, tile and slot.
	_found_at = {}
	_lifted_at = {}
	_pending = []
	_trail = []
	_ghost = {}
	_beam_at = -100.0
	_grew_at = -100.0
	_press_cell = Vector2i(-1, -1)
	_press_up = -1.0
	_solved_at = -1.0
	_anim_until = 0.0
	# The field's pop and the slots' drop have already played.
	_opened = _now() - 100.0
	_tip_timer.stop()
	_say(tr("WT_WIN"), Face.Expr.JOY)
	# The party's lasting marks, standing still: the meadow, the sprout in its
	# hat with the cheer, the seal, and on Insane the dawn already up.
	_restoring = true
	_state.misses = int(completed_record.get("misses", 0))
	_wish_bought = bool(completed_record.get("more", false))
	var now := _now()
	_dawn_at = now - 100.0
	_bloom_at = now - 100.0
	_party_at = NEVER
	_cheer = _cheer_for()
	_raise_stage(now - 100.0)
	_stamp_down()
	_restoring = false
	_refresh()

## How much of any word's lock wave is still to run.
func _wave_left(t: float) -> float:
	var left := 0.0
	for i in _found_at:
		var span := float((_state.words[i]["path"] as Array).size())
		left = maxf(left, float(_found_at[i]) + span * _wave_step() - t)
	return maxf(left, 0.0)

## The wave's step a tile: nothing under reduce-motion, where a word takes
## its colour and its letters in one frame.
func _wave_step() -> float:
	return 0.0 if Motion.reduce else WAVE_STEP

# --- the third polish (docs/superpowers/specs/2026-09-30-word-trail-polish-design.md) ---

## Calls `fn` `seconds` from now, unless the board has been dealt again by
## then.
func _after(seconds: float, fn: Callable) -> void:
	if seconds <= 0.0:
		fn.call()
		return
	var gen := _gen
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if gen == _gen and is_instance_valid(self):
			fn.call())

## True while the board is between a thing and its answer -- the card coming
## or up, the words being shown -- so the host holds its hint video back.
func busy() -> bool:
	return out_of_hearts or _revealing

## What the host keeps with a solved daily, for the seal on a reopen.
func completion_record() -> Dictionary:
	return {"misses": _state.misses, "more": _wish_bought}

# --- rewards (section 3) ---

## A word has locked: a note up the scale as its wave lands, one reaction in
## a bubble (a big word, a quick one, a streak), and one gag picked off the
## word -- hearts, a conga, a butterfly, a twirl, or nothing. The word that
## wins the board gets its note and leaves the rest to the party.
func _rewards(i: int, t: float) -> void:
	var span: int = (_state.words[i]["path"] as Array).size()
	var land := float(span) * _wave_step()
	var quick := _last_lock > -50.0 and t - _last_lock < QUICK
	_last_lock = t
	_streak += 1
	var step: int = CLIMB[mini(_notes, CLIMB.size() - 1)]
	_notes += 1
	var lock := int(_lock_gen.get(i, 0))
	var live := func() -> bool: return int(_lock_gen.get(i, 0)) == lock and bool(_state.words[i]["found"])
	_after(land + 0.05, func() -> void:
		if live.call():
			fx.cue("combo", pow(2.0, float(step) / 12.0)))
	if _state.is_solved() or Motion.reduce:
		return
	var last: Vector2i = (_state.words[i]["path"] as Array)[-1]
	var word: String = _state.words[i]["word"]
	if span >= BIG:
		_after(land + 0.1, func() -> void:
			if not live.call():
				return
			_bubble_over(last, tr("WT_BIG"))
			fx.cue("big")
			var a := _centre((_state.words[i]["path"] as Array)[0])
			var z := _centre(last)
			fx.confetti((a + z) * 0.5, 22, maxf(absf(z.x - a.x), _cell())))
	elif quick:
		_after(land + 0.1, func() -> void:
			if not live.call():
				return
			_bubble_over(last, tr("WT_QUICK"))
			fx.cue("quick"))
	elif _streak >= STREAK:
		var n := _streak
		_after(land + 0.1, func() -> void:
			if not live.call():
				return
			_bubble_over(last, tr("WT_STREAK") % n)
			fx.cue("streak"))
	var kind: String = ["love", "conga", "flutter", "twirl", ""][posmod(word.hash(), GAGS)]
	if kind.is_empty():
		return
	var at := t + land + _glint_length(i) * 0.5
	_gags[i] = {"kind": kind, "at": at}
	_after(at - t, func() -> void:
		if live.call():
			fx.cue(kind))
	var long := {"love": LOVE_TIME + 0.4, "conga": float(span + 4) * CONGA_STEP + Motion.HOP_TIME,
		"flutter": FLUTTER_TIME, "twirl": TWIRL_TIME}
	_busy_for(at - t + float(long[kind]))

## A paper bubble over a cell's right shoulder, popping in and fading after a
## hold -- Hidden Word's and Code Break's.
func _bubble_over(cell: Vector2i, text: String) -> void:
	_drop_bubble()
	if not is_inside_tree() or is_done():
		return
	var bubble := PanelContainer.new()
	bubble.name = "Bubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.z_index = 3
	var paper := StyleBoxFlat.new()
	paper.bg_color = Pal.SURFACE
	paper.set_corner_radius_all(22)
	paper.set_border_width_all(2)
	paper.border_width_bottom = 5
	paper.border_color = Pal.LINE
	paper.content_margin_left = 20
	paper.content_margin_right = 20
	paper.content_margin_top = 6
	paper.content_margin_bottom = 8
	bubble.add_theme_stylebox_override("panel", paper)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", CozyTheme.display(700))
	label.add_theme_font_size_override("font_size", BUBBLE_FONT)
	label.add_theme_color_override("font_color", Pal.ACORN_DEEP)
	bubble.add_child(label)
	add_child(bubble)
	bubble.reset_size()
	var over := _corner(cell) + Vector2(_cell() * 0.7, 0.0)
	var pos := over + Vector2(-bubble.size.x * 0.5, -bubble.size.y + 6.0)
	pos.x = clampf(pos.x, 8.0, size.x - bubble.size.x - 8.0)
	pos.y = maxf(pos.y, 4.0)
	bubble.position = pos
	bubble.pivot_offset = Vector2(bubble.size.x * 0.5, bubble.size.y)
	_bubble = bubble
	Motion.pop_in(bubble)
	# A weakref, not the node: the bubble can be dropped before the timer
	# fires, and a lambda holding a freed capture complains.
	var ref: WeakRef = weakref(bubble)
	get_tree().create_timer(BUBBLE_HOLD).timeout.connect(func() -> void:
		var it = ref.get_ref()
		if it == null or not is_instance_valid(it) or it.is_queued_for_deletion():
			return
		var out: Tween = Motion.appear(it, 1.0, 0.0, Motion.POP_OUT * 2.0)
		if out == null:
			it.queue_free()
		else:
			out.finished.connect(it.queue_free))

func _drop_bubble() -> void:
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = null

# --- the air: the dandelion, hearts and butterflies ---

## The band's top, its height and its ground line, as _build_band lays them.
func _band_top() -> float:
	return _slots_top() + _slots_room()

func _ground() -> float:
	return size.y - INSET - BAND_FOOT - TURF_TOP

func _build_air(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	if _state.counts_wishes():
		_dandelion(b, t)
	if not Motion.reduce:
		for i in _gags:
			var g: Dictionary = _gags[i]
			if not bool(_state.words[i]["found"]):
				continue
			var since := t - float(g["at"])
			var last: Vector2i = (_state.words[i]["path"] as Array)[-1]
			if g["kind"] == "love":
				_hearts(b, _centre(last), since)
			elif g["kind"] == "flutter":
				_butterfly(b, _centre(last), since, WORD_COLS[i % WORD_COLS.size()], posmod(i, 2) * 2 - 1)
	return b.mesh() if not b.verts.is_empty() else null

## The dandelion clock at the band's right: a stem, two leaves, a pale head,
## and a seed for every wish left; a seed a wrong trail spent drifts off on
## the breeze. It shakes after a miss, stands bare when the wishes are gone,
## and a bought wish grows a new head. It bows out when the stage comes up.
func _dandelion(b, t: float) -> void:
	var fade := 1.0 - _stage_level(t)
	if fade <= 0.0:
		return
	var base := _puff_foot()
	var h := _puff_height(base)
	if h <= 20.0:
		return
	var shake := 0.0
	if not Motion.reduce and t - _miss_at < 1.2:
		shake = sin((t - _miss_at) * 22.0) * 0.06 * (1.0 - (t - _miss_at) / 1.2)
	var head := base + Vector2(8.0 + sin(shake) * h, -h)
	var stem: Color = Pal.LEAF_DEEP.lerp(Pal.PARCHMENT, 0.25)
	b.stroke(Face.Builder.bezier2(base, base + Vector2(-8.0, -h * 0.55), head, 12), 4.0, Color(stem, fade))
	_leaf(b, base + Vector2(0.0, -2.0), 26.0, -2.6, Color(stem, fade))
	_leaf(b, base + Vector2(0.0, -2.0), 22.0, -0.5, Color(stem, fade))
	var grow := 1.0 if Motion.reduce else Motion.pop_in_scale(t - _puff_at, PUFF_BACK).x
	var r := PUFF_R * grow
	var left: int = _state.wishes_left()
	if left > 0 and grow > 0.0:
		b.disc(head, r * 1.08, Color(Pal.LINE, 0.35 * fade))
		b.disc(head, r, Color(Pal.SURFACE, 0.75 * fade))
	var count := maxi(_state.wishes - _puff_base, 1)
	for k in range(_puff_base, _state.wishes):
		var angle := -PI * 0.5 + TAU * float(k - _puff_base) / float(count) + shake * 3.0
		var dir := Vector2.from_angle(angle)
		if k < _state.misses:
			if not _blown.has(k) or Motion.reduce:
				continue
			var u := (t - float(_blown[k])) / SEED_FLY
			if u < 0.0 or u >= 1.0:
				continue
			var from := head + dir * r
			var at := from + Vector2(u * 300.0 - 40.0 * u * u, -u * 150.0 + sin(u * 10.0) * 12.0)
			_seed(b, at, Vector2.from_angle(-PI * 0.5 + sin(u * 7.0) * 0.5), r * SEED_LEN, (1.0 - u) * fade)
		elif grow > 0.0:
			_seed(b, head + dir * r * 0.2, dir, r * SEED_LEN, fade)
	b.disc(head, 5.0 * maxf(grow, 0.6), Color(Pal.ACORN, fade))

## Where the dandelion's stem stands, and how tall it may grow from there:
## on the band, in from the card's right.
func _puff_foot() -> Vector2:
	return Vector2(size.x - INSET - PUFF_RIGHT, _ground() + BLADE_ROOT)

func _puff_height(base: Vector2) -> float:
	return minf(PUFF_H, base.y - _band_top() - PUFF_R - 8.0)

## One seed: a fine stalk from `at` along `dir`, and a fluffy tuft at its end.
func _seed(b, at: Vector2, dir: Vector2, length: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var tip := at + dir * length
	b.stroke(PackedVector2Array([at, tip]), 2.5, Color(Pal.TEXT, 0.35 * alpha))
	b.disc(tip, 7.5, Color(Pal.LINE, 0.9 * alpha))
	b.disc(tip, 5.5, Color(Pal.SURFACE_HI, alpha))

## Little hearts floating up off a word's last tile, swaying as they go.
func _hearts(b, from: Vector2, since: float) -> void:
	var s := _cell()
	for h in LOVE_HEARTS:
		var u := (since - float(h) * 0.12) / LOVE_TIME
		if u <= 0.0 or u >= 1.0:
			continue
		var at := from + Vector2((float(h) - 1.5) * 0.22 * s + sin(u * 7.0 + float(h)) * 0.08 * s,
			-0.25 * s - u * LOVE_RISE * s)
		var r := LOVE_R * s * minf(u * 6.0, 1.0)
		_heart(b, at, r, Color(Pal.BERRY, 1.0 - u * u))

static func _heart(b, at: Vector2, r: float, colour: Color) -> void:
	if r <= 0.0:
		return
	b.disc(at + Vector2(-r * 0.5, 0.0), r * 0.56, colour)
	b.disc(at + Vector2(r * 0.5, 0.0), r * 0.56, colour)
	b.polygon(PackedVector2Array([at + Vector2(-r * 1.02, r * 0.18), at + Vector2(r * 1.02, r * 0.18),
		at + Vector2(0.0, r * 1.15)]), colour)

## A butterfly in the word's colour lifting off its last tile, flapping and
## wandering up out of the card.
func _butterfly(b, from: Vector2, since: float, colour: Color, side: int) -> void:
	var u := since / FLUTTER_TIME
	if u <= 0.0 or u >= 1.0:
		return
	var s := _cell()
	var at := from + Vector2(sin(u * 6.0) * 0.7 * s + float(side) * u * 1.4 * s, -u * 3.4 * s)
	var r := FLUTTER_R * s * minf(u * 8.0, 1.0)
	var flap := 0.25 + 0.75 * absf(sin(since * 20.0))
	var a := 1.0 - clampf((u - 0.7) / 0.3, 0.0, 1.0)
	var wing := Color(colour, a)
	var low := Color(colour.lerp(Pal.SURFACE, 0.3), a)
	for sx in [-1.0, 1.0]:
		b.ellipse(at + Vector2(sx * r * 0.55 * flap, -r * 0.25), r * 0.6 * flap, r * 0.5, wing)
		b.ellipse(at + Vector2(sx * r * 0.4 * flap, r * 0.3), r * 0.4 * flap, r * 0.34, low)
	b.ellipse(at, r * 0.13, r * 0.55, Color(Pal.TEXT, a))

# --- out of wishes (section 1) ---

## The last wish is gone and words are still hiding: every tile sags and
## leans a little, a lullaby, and the card -- one more wish, or show the
## words. The board takes no trails while it is up; the host's Back ends it
## unsolved (it reads `out_of_hearts`).
func _run_out(t: float) -> void:
	out_of_hearts = true
	_trail = []
	_droop_at = t + (0.0 if Motion.reduce else 0.35)
	_after(_droop_at - t, fx.cue.bind("droop"))
	_after(_droop_at - t + 0.6, fx.cue.bind("out_of_wishes"))
	_busy_for(_droop_at - t + float(_state.n * _state.n) * DROOP_STEP + DROOP_TIME)
	_say(tr("WT_OUT_LINE"), Face.Expr.SLEEPY)
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

## Code Break's card in this board's words, over the whole screen: on the
## host so it covers the chrome, or on the root when there is none (a probe).
func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_card):
		return
	var card: Control = load(OUT_CARD).new(_wish_bought, {
		"title": "WT_OUT_TITLE", "body": "WT_OUT_BODY", "body_rest": "WT_OUT_BODY_REST",
		"more": "WT_ONE_WISH", "show": "WT_SHOW_WORDS", "placement": "wish"})
	_card = card
	card.one_more_row.connect(wish_back)
	card.show_code.connect(show_words)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

func _close_card() -> void:
	if is_instance_valid(_card) and not _card.is_queued_for_deletion():
		_card.queue_free()
	_card = null

## One more wish (the card's video), once a board: the tiles perk back up
## and the dandelion grows a new head of WISH_BACK seeds.
func wish_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_state.add_wishes()
	_wish_bought = true
	out_of_hearts = false
	var t := _now()
	_droop_at = NEVER
	_perk_at = t
	_puff_base = _state.misses
	_puff_at = t
	_busy_for(maxf(PUFF_BACK, Motion.BUMP_TIME + Motion.stagger(2 * _state.n, CASCADE)))
	fx.cue("wish_back")
	_say(tr("WT_WISH_BACK") % _state.wishes_left(), Face.Expr.HAPPY)
	_refresh()
	moved.emit()

## Show the words: the tiles perk up and every word still hiding locks, one
## after another in a paler ribbon, then the board ends unsolved with the
## sprout's kind line on the band.
func show_words() -> void:
	if is_done():
		return
	_close_card()
	# out_of_hearts stays up through the reveal, so the host's Back still ends
	# the board unsolved rather than logging an abandon.
	_revealing = true
	var t := _now()
	_droop_at = NEVER
	_perk_at = t
	var left: int = _state.words.size() - _state.found_count()
	var step := 0.05 if Motion.reduce else REVEAL_STEP
	for k in left:
		_after(0.3 + float(k) * step, func() -> void:
			var i: int = _state.reveal_next()
			if i < 0:
				return
			_found_at[i] = _now()
			_lifted_at.erase(i)
			fx.cue("reveal", maxf(1.0 - 0.03 * float(k), 0.75))
			_busy_for(float((_state.words[i]["path"] as Array).size()) * _wave_step() + Motion.BUMP_TIME)
			_refresh())
	var end := 0.3 + float(left) * step + 8.0 * _wave_step()
	_after(end, func() -> void:
		_revealing = false
		out_of_hearts = false
		if _state.night():
			_dawn_at = _now() if not Motion.reduce else _now() - 100.0
			_busy_for(DAWN_TIME)
		fx.cue("lost")
		_say(tr("WT_SHOWN_LINE"), Face.Expr.HAPPY)
		_raise_stage(_now())
		finish_unsolved()
		_refresh())
	_busy_for(end + Motion.BUMP_TIME)
	_refresh()

# --- Night Walk (section 2) ---

## The lantern, a paper one off Untangle's string, built on a night board and
## kept hidden on the others.
func _make_lamp() -> void:
	if not _state.night():
		if is_instance_valid(_lamp):
			_lamp.visible = false
		return
	if not is_instance_valid(_lamp):
		_lamp = LanternFace.new()
		_lamp.name = "Lantern"
		_lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lamp.z_index = 2
		_lamp.hue = 1
		add_child(_lamp)
	_lamp.visible = true
	_lamp.modulate.a = 1.0
	_lamp.lit = 0.5
	_lamp.set_idle(true)
	_lamp_pos = Vector2(-1.0, -1.0)

## The lantern shines round `cell`; `first` when a finger has just come down.
func _lamp_to(cell: Vector2i, first := false) -> void:
	if not _state.night():
		return
	_lamp_on = true
	_lamp_cell = cell
	_light_round(_now())
	if first:
		fx.cue("lantern")
		if is_instance_valid(_lamp):
			_lamp.lit = 1.0

func _lamp_off() -> void:
	if not _lamp_on:
		return
	_light_round(_now())
	_lamp_on = false
	if is_instance_valid(_lamp):
		_lamp.lit = 0.5
	_refresh()

## While a finger is down in the dark, every cell within LAMP_REACH of the
## lantern and every tile on the trail is lit now.
func _light_round(t: float) -> void:
	if not _lamp_on or not _state.night():
		return
	for dy in range(-LAMP_REACH, LAMP_REACH + 1):
		for dx in range(-LAMP_REACH, LAMP_REACH + 1):
			var c := _lamp_cell + Vector2i(dx, dy)
			if c.x >= 0 and c.y >= 0 and c.x < _state.n and c.y < _state.n:
				_light[c] = t
	for c: Vector2i in _trail:
		_light[c] = t

func _light_until() -> float:
	var last := -100.0
	for c in _light:
		last = maxf(last, float(_light[c]))
	return last + AFTERGLOW

## How lit each cell is, 0 dark to 1 read: the lantern's afterglow, easing
## out over AFTERGLOW; every found or shown word lights its own tiles and
## their neighbours for good, as a string of lanterns does; a hint's tiles;
## and the dawn.
func _levels(t: float) -> Dictionary:
	var out := {}
	var dawn := _dawn_at > NEVER
	for y in _state.n:
		for x in _state.n:
			var cell := Vector2i(x, y)
			var lv := 0.0
			if _light.has(cell):
				var u := (t - float(_light[cell])) / AFTERGLOW
				lv = 1.0 - smoothstep(0.35, 1.0, u)
			if dawn:
				lv = maxf(lv, clampf((t - _dawn_at - DAWN_STEP * float(x + y)) / 0.5, 0.0, 1.0))
			out[cell] = lv
	for i in _state.words.size():
		var path: Array = _state.words[i]["path"]
		var front := ceili(_front(i, t))
		for idx in mini(front, path.size()):
			var c: Vector2i = path[idx]
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var k := c + Vector2i(dx, dy)
					if out.has(k):
						out[k] = 1.0
		for idx in mini(_state.hint_shown(i), path.size()):
			out[path[idx]] = 1.0
	return out

## The night sky under the field: a deep blue pond the tiles stand in, with a
## few stars where four tiles meet. It fades at dawn.
func _night_sky(t: float) -> void:
	var a := 1.0
	if _dawn_at > NEVER:
		a = 1.0 - clampf((t - _dawn_at) / DAWN_TIME, 0.0, 1.0)
	if a <= 0.0:
		return
	if _relaid():
		var b := Face.Builder.new()
		_sky_into(b, Color(NIGHT_SKY, a), Color(NIGHT_STAR, a * 0.8))
		_rm.put_builder(b)
	else:
		_rm.put(SHAPE_SKY, [Color(NIGHT_SKY, a), Color(NIGHT_STAR, a * 0.8)], Transform2D.IDENTITY)

## The night sky under the field as this layout lays it: a deep blue pond
## the tiles stand in, with a star at some of the corners where four meet.
func _sky_into(b, sky: Color, star: Color) -> void:
	var o := _origin() - Vector2.ONE * GAP * 0.5
	var w := _field_size() + GAP
	b.fan(Face.Builder.round_rect(o, Vector2(w, w), _cell() * RADIUS + GAP * 0.5), sky)
	var step := _cell() + GAP
	for y in range(1, _state.n):
		for x in range(1, _state.n):
			if _hash(x * 7, y * 13) < 0.3:
				b.disc(_origin() + Vector2(x, y) * step - Vector2.ONE * GAP * 0.5, GAP * 0.3, star)

## A cell in the dark: the same piece for a wall and a tile, so the night
## tells nothing of the field's shape.
func _night_piece(cell: Vector2i, t: float) -> void:
	_rm.put(SHAPE_TILE, [NIGHT_LIP, NIGHT_RIM, _toned(NIGHT_TILE, _tone(cell))],
		_cell_xf(cell, t) * _at_corner(_corner(cell)))

## The lantern's warm pool over the tiles round the finger.
func _lamp_glow(_t: float) -> void:
	if not _lamp_on or _lamp_cell.x < 0:
		return
	_rm.put(SHAPE_LAMP, [Color(Pal.SUN_RAY, LAMP_GLOW.y)], _at_corner(_centre(_lamp_cell)))

## The lantern floats after the finger, up and to the left of it so the
## finger never hides it, and hangs on the band's left when nothing is held.
## At dawn it floats up and away: its night's work is done.
func _ride_lamp(t: float, delta: float) -> void:
	if not is_instance_valid(_lamp) or not _lamp.visible:
		return
	var s := _cell()
	var px := s * LAMP_SIZE
	_lamp.size = Vector2(px, px)
	var target := _lamp_rest()
	if _lamp_on and _lamp_cell.x >= 0:
		target = _centre(_lamp_cell) + LAMP_OFFSET * s
	var away := 0.0
	if _dawn_at > NEVER:
		away = clampf((t - _dawn_at) / DAWN_TIME, 0.0, 1.0)
		target += Vector2(0.0, -260.0 * away)
		_lamp.modulate.a = 1.0 - away
		if away >= 1.0:
			_lamp.visible = false
			return
	if _lamp_pos.x < 0.0 or Motion.reduce:
		_lamp_pos = target
	else:
		_lamp_pos = _lamp_pos.lerp(target, 1.0 - exp(-LAMP_FOLLOW * delta))
	_lamp.position = _lamp_pos - _lamp.size * 0.5

## Where the lantern hangs while nothing is held: on the band's left.
func _lamp_rest() -> Vector2:
	return Vector2(INSET + 110.0, _band_top() + 40.0)

# --- the party and the seal (section 3) ---

func _cheer_for() -> int:
	var key := ""
	for w in _state.words:
		key += String(w["word"])
	return posmod(key.hash(), CHEERS)

## After the solve hop: the tiles dance, every wall blooms a flower, the
## sprout comes up on the band in a party hat with a silly cheer, confetti
## flies twice, and STAMP_AT later the seal drops on the cheer's card.
func _party(t: float) -> void:
	_cheer = _cheer_for()
	if Motion.reduce:
		_party_at = t
		_bloom_at = t - 100.0
		_raise_stage(t - 100.0)
		_stamp_down()
		return
	_party_at = _solved_at + Motion.SOLVE_DELAY + _solve_span() + Motion.SOLVE_TIME + PARTY_AT
	_after(_party_at - t, _party_on)
	_after(_party_at - t + STAMP_AT, _stamp_down)
	_busy_for(_party_at - t + maxf(float(DANCE_BEATS) * DANCE_BEAT,
		Motion.stagger(2 * _state.n, BLOOM_STEP) + BLOOM_TIME) + STAGE_TIME)

func _party_on() -> void:
	if not _state.is_solved():
		return
	var t := _now()
	_bloom_at = t + 0.2
	_raise_stage(t)
	fx.cue("party")
	_after(0.15, fx.cue.bind("dance"))
	_after(0.5, fx.cue.bind("bloom"))
	var mid := _field_centre()
	fx.confetti(mid - Vector2(0.0, _field_size() * 0.25), 44, _field_size() * 0.8)
	_after(0.4, func() -> void:
		fx.confetti(Vector2(size.x * 0.5, _band_top() + 20.0), 30, size.x * 0.6)
		fx.cue("confetti"))
	_refresh()

## Every wall blooms a flower in one of the day's colours, popping open in a
## wave from the top-left; they stay.
func _meadow(t: float) -> void:
	if _bloom_at <= NEVER:
		return
	var s := _cell()
	var k := -1
	for cell: Vector2i in _state.walls:
		k += 1
		var grow := 1.0
		if not Motion.reduce and t - _bloom_at < 5.0:
			grow = Motion.pop_in_scale(t - _bloom_at - Motion.stagger(cell.x + cell.y, BLOOM_STEP, 1.2),
				BLOOM_TIME).x
		if grow <= 0.0:
			continue
		_rm.open(PART_FLOWER, k)
		var xf := _cell_xf(cell, t)
		var mid := xf * _centre(cell) + Vector2(0.0, s * BED_LIP * 0.5)
		var petal: Color = WORD_COLS[int(_hash(cell.x, cell.y + 40) * float(_state.words.size())) % WORD_COLS.size()]
		var spin := _hash(cell.y, cell.x) * TAU
		var sz := Vector2.ONE * (grow * s / _ref_cell)
		_rm.put(SHAPE_LEAVES, [Pal.LEAF], Transform2D(0.0, sz, 0.0, mid))
		_rm.put(SHAPE_HEAD, [petal, Pal.SUN], Transform2D(spin, sz, 0.0, mid))

## The stage on the band: the sprout and the card beside it rise together at
## `at` -- the cheer on a solve, a kind line on shown words.
func _raise_stage(at: float) -> void:
	_stage_at = at
	var party: bool = _state.is_solved() and _state.shown.is_empty()
	if not is_instance_valid(_sprout):
		_sprout = SproutFace.new()
		_sprout.name = "Sprout"
		_sprout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sprout.z_index = 1
		add_child(_sprout)
	var px := STAGE_SPROUT_R * 2.0 * SproutFace.REACH
	_sprout.size = Vector2(px, px)
	_sprout.expression = Face.Expr.JOY if party else Face.Expr.HAPPY
	_sprout.visible = true
	_sprout.hat = 1.0 if party and (Motion.reduce or _restoring) else 0.0
	_sprout.set_idle(true)
	_ride_sprout(_now())
	if party and not Motion.reduce and not _restoring:
		var tw := _sprout.create_tween()
		tw.tween_interval(STAGE_TIME)
		tw.tween_property(_sprout, "hat", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_busy_for(STAGE_TIME + 0.4)

## How far the stage has come up, 0 to 1.
func _stage_level(t: float) -> float:
	if _stage_at <= NEVER:
		return 0.0
	return Motion.appear_level(t - _stage_at, 0.25)

func _stage_rise(t: float) -> float:
	if Motion.reduce:
		return 0.0
	return STAGE_RISE * (1.0 - Motion.back_out(clampf((t - _stage_at) / STAGE_TIME, 0.0, 1.0)))

func _stage_top() -> float:
	var tall := size.y - INSET - _band_top()
	return _band_top() + maxf((tall - STAGE_H) * 0.5, 0.0)

func _ride_sprout(t: float) -> void:
	if not is_instance_valid(_sprout) or not _sprout.visible:
		return
	var seat := Vector2(INSET + STAGE_X * 0.5, _stage_top() + STAGE_H * 0.5 + _stage_rise(t))
	_sprout.position = seat - _sprout.size * 0.5
	_sprout.modulate.a = _stage_level(t)

## The stage's card and its two lines, drawn: the day's line and the cheer,
## or the kind line under shown words.
func _draw_stage(t: float, shown: Array) -> void:
	if _stage_at <= NEVER:
		return
	var a := _stage_level(t)
	if a <= 0.0:
		return
	var x := INSET + STAGE_X
	var w := size.x - INSET - STAGE_RIGHT - x
	if _stage_mesh == null:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(x, 0.0), Vector2(w, STAGE_H), STAGE_RADIUS), Pal.LINE)
		b.fan(Face.Builder.round_rect(Vector2(x, 0.0), Vector2(w, STAGE_H - STAGE_EDGE), STAGE_RADIUS), Pal.SURFACE)
		_stage_mesh = b.mesh()
	var top := _stage_top() + _stage_rise(t)
	draw_mesh(_stage_mesh, null, Transform2D(0.0, Vector2(0.0, top)), Color(1.0, 1.0, 1.0, a))
	shown.append(_stage_mesh)
	var party: bool = _state.is_solved() and _state.shown.is_empty()
	var head := tr("WT_WIN") if party else tr("WT_SHOWN_TITLE")
	var line := tr("WT_CHEER_%d" % _cheer) if party else tr("WT_SHOWN_LINE")
	var room := w - 48.0 - (STAMP_R * 1.6 if party else 0.0)
	_stage_line(CozyTheme.display(700), STAGE_FONT, Vector2(x + 26.0, top + 34.0), head,
		Color(Pal.GOOD if party else Pal.TEXT, a), room)
	_stage_line(CozyTheme.body(500), STAGE_LINE, Vector2(x + 26.0, top + 72.0), line,
		Color(Pal.TEXT_DIM, a), room)

## One line seated by its left edge and middle, shrunk to fit `room`.
func _stage_line(font: Font, px: int, at: Vector2, text: String, colour: Color, room: float) -> void:
	var size_px := px
	while size_px > 14 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > room:
		size_px -= 2
	font.draw_string(get_canvas_item(),
		at + Vector2(0.0, font.get_height(size_px) * 0.5 - font.get_descent(size_px)),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, colour)

## The seal's word: by the plausible wrong trails the solve took, or Second
## wind for a board that needed the card's wish.
func stamp_key() -> String:
	if _wish_bought:
		return "WT_STAMP_MORE"
	var m: int = _state.misses
	if m == 0:
		return "WT_STAMP_0"
	if m <= 2:
		return "WT_STAMP_1"
	return "WT_STAMP_2" if m <= 5 else "WT_STAMP_3"

func _stamp_centre() -> Vector2:
	return Vector2(size.x - INSET - STAGE_RIGHT - STAMP_R * 0.95, _stage_top() + STAGE_H * 0.45)

## The seal drops onto the right end of the stage's card, squashes and
## rings: gold with its word, or on Insane the night seal with "Night Walk"
## over it. It is the result, so it shows under reduce motion too, still.
func _stamp_down() -> void:
	if is_instance_valid(_stamp) or not _state.is_solved() or not _state.shown.is_empty():
		return
	var rad := STAMP_R
	var insane: bool = _state.night()
	var stamp := Control.new()
	stamp.name = "Stamp"
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.z_index = 3
	stamp.size = Vector2.ONE * rad * 2.0
	stamp.pivot_offset = stamp.size * 0.5
	var centre := _stamp_centre()
	stamp.position = centre - stamp.pivot_offset
	stamp.rotation = STAMP_TILT
	var mesh := Seal.mesh(rad, insane)
	var word: String = tr(stamp_key())
	var lines := [[Seal.tr_static("WT_NIGHT_SEAL"), 0.26, 0.02], [word, 0.22, 0.36]] if insane \
		else [[word, 0.3, 0.12]]
	stamp.draw.connect(func() -> void:
		stamp.draw_mesh(mesh, null, Transform2D(0.0, stamp.pivot_offset))
		Seal.text(stamp, rad, lines))
	add_child(stamp)
	_stamp = stamp
	if _restoring or Motion.reduce:
		return
	fx.cue("stamp")
	stamp.scale = Vector2.ONE * STAMP_FROM
	stamp.modulate.a = 0.0
	var tw := stamp.create_tween()
	tw.set_parallel(true)
	tw.tween_property(stamp, "scale", Vector2.ONE, STAMP_DROP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(stamp, "modulate:a", 1.0, STAMP_DROP * 0.6)
	tw.chain().tween_callback(func() -> void:
		Motion.squash(stamp, 0.22, 0.26)
		fx.buzz(Haptics.THUD)
		fx.ring(centre, rad * 0.9, Pal.MOON_INK if insane else Pal.SUN))

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
