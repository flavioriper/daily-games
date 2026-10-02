extends "res://core/puzzle_base.gd"

## Hidden Word as a flat board: six rows of five tiles on the host's
## parchment card, a scenery band at its foot, and a keyboard under it.
## Type five letters, press Enter, and the row turns over a tile at a time --
## green in the right place, amber in the word but elsewhere, grey not in it
## at all. The rules live in puzzles/hidden_word_state.gd, which this only
## draws; the keyboard is ui/flat/key_board.gd, which the host builds and
## hands over once through set_tray().
##
## How it is drawn. Two meshes and no Controls. The scenery band is built
## once per layout and never moves; the thirty tiles go into a second mesh
## rebuilt only while something is moving, because none of them has a face on
## it and a Control per tile would be thirty nodes for a field of rounded
## squares. The letters are draw commands over the top (Mosaic.letter, which
## is draw_set_transform then draw_string), as Nonogram draws its clue
## numbers: a glyph in a mesh cache key would multiply every state by
## twenty-six. Everything is drawn, so every moment reads the flat boards'
## vocabulary as curves off core/motion.gd (rule 8 of docs/art/flat-motion.md)
## rather than tweening a node.
##
## **Its signature is the flip**, and it is the one thing on this screen with
## numbers of its own: the row's five tiles turn on their X axis in sequence,
## FLIP_STEP apart, each a scale.y squash to zero and back over FLIP_TIME,
## and a tile takes its colour at the halfway point -- edge-on, so the answer
## arrives *with* the turn and never before it. The keyboard is repainted only
## when the last tile of the row has landed: a key that greened while the
## third tile was still face-down would give the row away.
##
## Spec: docs/superpowers/specs/2026-09-19-hidden-word-flat-design.md,
## sections 3, 5, 7 and 9. Ported number for number from the canvas mock at
## docs/brainstorm/concepts.html#hiddenword, which is the reference for every
## measure and every timing here.
##
## **The polish pass** (2026-09-30, spec 2026-09-30-hidden-word-polish-design.md)
## put in failing, Snail Mail and the rewards. Hard and Insane keep their rows
## (Reset clears only the row being typed) and ask for every clue to be used;
## running out of rows brings Code Break's card -- one more row, or show the
## word. Insane is **Snail Mail**: a row turns over sealed, as a pale envelope,
## and the snail beside it brings its colours when the next row is committed.
## Every row that shows its colours can earn a reaction (Warmer!, So close!,
## Everyone's here!, a clean miss in sunglasses), a new green plucks a note up
## the scale and three in five do something silly (little hearts, a twirl, a
## sprig), and a solve dances, blooms the meadow, cheers and stamps a seal.

const State = preload("res://puzzles/hidden_word_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const SproutFace = preload("res://ui/faces/sprout_face.gd")
const SnailFace = preload("res://ui/faces/snail_face.gd")
const Seal = preload("res://ui/flat/seal.gd")
const RunMesh = preload("res://ui/flat/run_mesh.gd")
const OUT_OF_ROWS := "res://ui/hud/out_of_rows.gd"

# --- this board's own three numbers (spec section 9) ---
## The flip: how far apart the five tiles start turning, and how long one
## tile's turn takes.
const FLIP_STEP := 0.16
const FLIP_TIME := 0.42
## How long a refusal's toast holds before it pops out again. `commit_row`
## raises it on a refused Enter; the number is here with the other two
## because it is one of this board's signature three and nothing else on
## the screen sets it.
const TOAST_HOLD := 1.2

# --- the grid, measured (spec section 5) ---
## Between tiles, and the card's own inset. Both are the mock's.
const GAP := 14.0
const INSET := 28.0
## The scenery band reserved at the card's foot. It is what buys the grid its
## cell: without it the tile is 169 and the six rows fill the card's inner
## height exactly, leaving a cloud nowhere to stand. At 1080x1920 the slot is
## 1140, so the cell is (1140 - 56 - 120 - 70) / 6 = **149**, the block is 801
## by 964 with 143 of side air, and the card comes back to exactly 1140.
const BAND := 120.0
## A tile's corner and the bottom edge under its face, in cells, and how far
## that edge goes toward the ink.
const RADIUS := 0.19
const EDGE := 0.05
const EDGE_MIN := 5.0
const EDGE_MIX := 0.26
## How far an empty tile's own edge goes toward the ink: less, because an
## empty tile is a bed and not a piece.
const EMPTY_MIX := 0.14
## A letter narrower than this fraction of its tile is a smudge rather than a
## letter, so an edge-on tile carries none.
const LETTER_EDGE := 0.12
## The pop a typed letter and its tile arrive with -- the family's recipe at
## its own time, not a constant copied off Motion (docs/art/flat-motion.md).
const TYPE_POP := 0.18
## How long the win screen waits after the solve, so the flip that won it can
## finish first.
const WIN_WAIT := 1.6

# --- the toast (spec section 8) ---
## The refusal pill over the top of the grid: its height, the paper either
## side of the line, the corner, how far above the card's own top it sits and
## the size and the ink of the line inside it. The corner is half the height,
## which is what makes it a pill rather than a card -- Face.Builder.round_rect
## clamps it there anyway, exactly as the mock's own `rr` does.
const TOAST_H := 76.0
const TOAST_PAD := 64.0
const TOAST_RADIUS := 38.0
const TOAST_RISE := 30.0
const TOAST_FONT := 34
const TOAST_INK := 0.92
## The three lines a refusal can say, indexed by the state's own code, and no
## others. OK is index 0 and never shows one.
## Translation keys (locale/ui.csv), read through tr() when drawn.
const TOAST_LINE := ["", "HW_TOAST_LENGTH", "HW_TOAST_NOT_WORD", "HW_TOAST_REPEAT",
	"HW_TOAST_KEEP", "HW_TOAST_USE"]
## The ordinals the clue rule's toast names a place with ("Keep R 2nd").
const PLACE := ["HW_PLACE_1", "HW_PLACE_2", "HW_PLACE_3", "HW_PLACE_4", "HW_PLACE_5"]

# --- the hint (spec section 10) ---
## A hint's letter is a given and not a guess, so it is drawn ghosted.
const GHOST := 0.55

# --- the solve and the reveal (spec section 9's table) ---
## How far the rows that did not win fade back while the winning row hops,
## and how far every row fades once the sixth has been spent. These and the
## four below are the ending's own numbers rather than the vocabulary's:
## core/motion.gd has no reveal, because no other board can run out.
const SOLVE_DIM := 0.3
const OVER_DIM := 0.4
const DIM_TIME := 0.3
## How long the keyboard takes to leave, and the sprout's own rise -- how long
## it waits after the last tile lands, how far below its seat it starts, how
## long it takes and how long it fades in over.
const KEYS_OUT := 0.25
const REVEAL_WAIT := 0.1
const REVEAL_RISE := 200.0
const REVEAL_TIME := 0.35
const REVEAL_FADE := 0.25
## The reveal, laid out on the scenery band: its top, the sprout's centre in
## from the card's left and R, then the word card's left, the paper it leaves
## at the right, its height, corner and edge, and the two lines inside it.
const REVEAL_TOP := -12.0
const SPROUT_AT := Vector2(118.0, 76.0)
const SPROUT_R := 66.0
const WORD_CARD_X := 206.0
const WORD_CARD_RIGHT := 40.0
const WORD_CARD_H := 140.0
const WORD_CARD_RADIUS := 28.0
const WORD_CARD_EDGE := 6.0
const WORD_TEXT_X := 36.0
const WORD_LABEL_Y := 50.0
const WORD_LABEL_FONT := 30
const WORD_Y := 96.0
const WORD_FONT := 48
const WORD_SPACING := 3

# --- the scenery band, ported from the mock's `scenery()` ---
## The turf's top edge, measured up from the foot of the band, and the band's
## corner and the lighter crown along its top.
const TURF_TOP := 44.0
const TURF_RADIUS := 24.0
const CROWN_H := 24.0
const CROWN_RADIUS := 14.0
## Two clouds in the side air the band bought, each x in from its own side of
## the card's inner width, y down from the card's top, and its radius.
const CLOUD_LEFT := Vector3(36.0, 176.0, 20.0)
const CLOUD_RIGHT := Vector3(36.0, 286.0, 17.0)
## Blades standing out of the turf: how many, how far in from each end they
## start, their half-width at the root, and the band their height falls in.
const BLADES := 20
const BLADE_EDGE := 26.0
const BLADE_W := 5.0
const BLADE_ROOT := 3.0
const BLADE_MIN := 9.0
const BLADE_SPREAD := 15.0
const BLADE_LEAN := 7.0
## Three bushes on the ground line: x (from the left, or negative from the
## right, or a fraction of the width when between 0 and 1) and the radius.
const BUSH_LEFT := Vector2(118.0, 36.0)
const BUSH_MID := Vector2(0.47, 25.0)
const BUSH_RIGHT := Vector2(-138.0, 31.0)
## And the mock's three flowers, each x the same way and y below the ground
## line.
const FLOWER_LEFT := Vector2(232.0, 18.0)
const FLOWER_MID := Vector2(0.67, 24.0)
const FLOWER_RIGHT := Vector2(-238.0, 16.0)
const FLOWER_PETALS := 5
const FLOWER_R := 7.0
const PETAL_R := 5.5
const FLOWER_EYE_R := 4.0
## How far each green is lifted toward the card's parchment, so the band
## recedes behind the grid rather than competing with it.
const TURF_WASH := 0.52
const CROWN_WASH := 0.3
const BLADE_WASH := 0.24
const BUSH_DEEP_WASH := 0.3
const BUSH_LIT_WASH := 0.12

## The three marks' faces, in the order HIT, NEAR, MISS.
const MARK := [Pal.GOOD, Pal.WORD_NEAR, Pal.WORD_MISS]

# --- the second polish (2026-09-25; the spec's section 12) ---
## An empty cell is a bed sunk into the card, not a card standing on it: its
## floor a few points under the parchment, with a shadow lip along its top
## BED_LIP of a cell deep. A pale raised card on parchment read as nothing.
const BED := Color("eadcc0")
const BED_SHADE := Color("d9c8a7")
const BED_LIP := 0.055
## The row being typed is lit ROW_LIT toward the sun, and the bed the next
## letter goes into wears a sun rim CARET of a cell wide, so the eye always
## knows where the keyboard is writing.
const ROW_LIT := 0.12
const CARET := 0.032
const CARET_A := 0.75
## A typed letter stands on a paper piece, raised out of its bed: the paper's
## crown is PAPER_CROWN toward SURFACE_HI inside a lit rim, over a lip in LINE.
const PAPER_CROWN := 0.4
const PAPER_LIP := 0.55
## A piece's bevel, in cells: the crown sits this far down and in from the
## rim. A mark's rim is its face RIM_LIGHT toward SURFACE, so it is lit from
## above; TONE is how far lighter or darker a tile's hash moves its face, so
## the rows read as laid by hand.
const BEVEL := 0.055
const RIM_LIGHT := 0.3
const TONE := 0.035
## The flip lifts the tile off the card: at edge-on it has grown FLIP_SWELL
## and risen FLIP_RISE of a cell over a soft shadow, and it lands with a
## LAND_BUMP bump. A squash in place read as a tile folding, not turning.
const FLIP_SWELL := 0.08
const FLIP_RISE := 0.07
const FLIP_SHADOW_A := 0.22
const LAND_BUMP := 0.07
## A light runs across a landed row's green tiles, GLINT_STEP a tile after
## GLINT_DELAY, each shining over GLINT_TIME toward SURFACE by SHINE -- the
## right letters catch the light, and on the winning row all five do.
const GLINT_DELAY := 0.06
const GLINT_STEP := 0.07
const GLINT_TIME := 0.36
const SHINE := 0.35

# --- the polish pass (2026-09-30; its spec, sections 1 to 4) ---
## A tile's three faces: the paper a typed letter stands on, Snail Mail's
## sealed envelope, and its mark.
enum { FACE_PAPER, FACE_POST, FACE_MARK }
## The envelope: moonlit paper, a flap folded down to its middle in a shade
## toward MOON_INK, and a berry wax seal where the flap meets. Cool on purpose:
## the marks are green, amber and a warm grey, and a sealed row must never be
## read as a colour it has not been given.
const POST := Color("e6e8f7")
const POST_FLAP := 0.16
const POST_DEEP := 0.3
const WAX_R := 0.085
## The snail, beside the row it carries (in cells), how long it takes to crawl
## down to the next one, and when the carried row turns: DELIVER_AFTER once
## the newly sealed row has landed.
const SNAIL_PX := 0.5
const SNAIL_OFF := -0.02
const SNAIL_CRAWL := 0.7
const DELIVER_AFTER := 0.12
## The caret glides to the next bed rather than jumping.
const CARET_GLIDE := 0.12
## Five letters typed: the row gives a little eager hop, a tile after a tile.
const READY_HOP := -5.0
const READY_STEP := 0.035
const READY_TIME := 0.26
## The entrance: the rows arrive top to bottom, each rising ENTER_RISE into
## its seat ENTER_ROW apart, inside the grid's own wide pop.
const ENTER_ROW := 0.035
const ENTER_RISE := 16.0
## Out of rows: every tile sags and leans, a tile after a tile, and stays
## drooped until the card is answered; the card follows CARD_AFTER later.
const DROOP := 0.07
const DROOP_TILT := 0.07
const DROOP_STEP := 0.03
const DROOP_TIME := 0.5
const CARD_AFTER := 1.1
const CARD_AFTER_STILL := 0.3
## One more row: the grid makes room for a seventh over GROW_TIME.
const GROW_TIME := 0.45
## A shown row's reaction waits REACT_AT after it lands; its bubble holds.
const REACT_AT := 0.12
const BUBBLE_HOLD := 1.5
const BUBBLE_FONT := 34
## A new green plucks `combo` up the major pentatonic, one step a green found.
const COMBO_STEPS := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]
## Three of every five new greens, by the cell's hash, do something silly.
const GAG_ODDS := 5
const GAGS := 3
const LOVE_HEARTS := 4
const LOVE_TIME := 1.3
const LOVE_RISE := 0.8
const LOVE_R := 0.12
const TWIRL_TIME := 0.55
const TWIRL_HOP := 0.14
const SPRIG_TIME := 1.5
const SPRIG_R := 0.16
## A clean miss puts sunglasses on the row, and Everyone's here! congas.
const GLASSES_TIME := 1.7
const CONGA_STEP := 0.06
const CONGA_HOP := -12.0
## The party after a solve: PARTY_AT after the winning row lands the tiles
## dance DANCE_BEATS beats, flowers bloom along the band, the sprout comes up
## in a party hat with a cheer, and STAMP_AT later the seal drops.
const PARTY_AT := 0.85
const PARTY_EXTRA := 2.1
const DANCE_BEATS := 4
const DANCE_BEAT := 0.24
const DANCE_TILT := 0.16
const DANCE_HOP := -8.0
const BLOOMS := 9
const BLOOM_STEP := 0.05
const BLOOM_TIME := 0.4
const BLOOM_R := 9.0
const CHEERS := 12
const STAMP_AT := 1.1
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 62.0
const STAMP_TILT := -0.22

var state = State.new()
## The board's own effects node, as on every flat board: the hint's ring
## and sparkle (func hint(), below) come through it and nowhere else.
var fx: Node2D
## The keyboard, handed over once by the host after the board is spawned. A
## harness that builds this board without a tray leaves it null, so every use
## of it is guarded.
var _tray: Control = null

## Every drawn thing's moments, each the second it began, read off Motion's
## curve readers in _build_grid and _draw_letters.
## The second each committed row began its flip; -1 while the row is unplayed.
var _row_at: Array[float] = []
## The latest of those, and which row it belongs to -- the flip in hand.
var _flip_at := -100.0
var _flip_row := -1
## Per column of the working row: when its letter was typed, and when a
## letter was erased off it (with the letter that left, which the state has
## already forgotten).
var _typed_at: Array[float] = []
var _gone_at: Array[float] = []
var _gone_ch: Array[String] = []
## Per row: when a refused Enter shivered it.
var _shiver_at: Array[float] = []
## Column -> the second a hint revealed the answer's letter there.
## `_ghost_letter` draws the ghost off it; it is here because the board owns
## its moments.
var _given_at: Dictionary = {}
## The keyboard repaints still owed, in the order they were earned: each is
## `{"at", "marks", "letters"}` -- the second that row's last tile lands, and
## what that row taught, **snapshotted at the moment it was committed**.
##
## Two things about this are load-bearing, and both were bugs first. It is a
## queue and not one slot, because a second Enter inside the 1.06 s a row
## takes to turn used to overwrite the repaint waiting on the first row --
## and `KeyBoard.set_marks` is additive and never re-runs over an older row,
## so those letters stayed unpainted *for the rest of the game* and the
## keyboard silently lied about what had been guessed. And the payload is
## snapshotted rather than re-derived when it comes due, for the very rule
## the delay exists to keep: `state.key_mark` reads every committed row, so a
## repaint resolved late would carry a **newer** row's marks and give that
## row away while its own tiles were still face-down.
var _keys_due: Array = []
## The refusal in hand: an index into TOAST_LINE (0 for none) and the second
## it popped up. One at a time -- a second refusal replaces the first rather
## than stacking, because two pills over one grid is a pile of paper.
var _toast := 0
var _toast_at := -100.0
## The second the winning row landed, and the second the sixth row did. Both
## are in the future while that row is still turning, which is the whole
## point: the hop, the dim, the sprout and the word all wait for the tiles.
var _solved_at := -100.0
var _over_at := -100.0
## When the keyboard is due to leave. Whether it has gone is the tray's own
## `gone`, not a second copy here: the settings sheet's New puzzle spawns a
## fresh board against the same tray, and a board that had just learned the
## keyboard was still on screen would leave it slid out for good.
var _keys_out_at := INF
## Reset's wave: one {"r", "c", "ch", "m", "at"} per committed tile on its way
## out, drawn over the bed that is already underneath it.
var _ghosts: Array = []
## The sparkles still owed, each {"at", "r", "c"}: the solve's five arrive one
## SOLVE_STAGGER after another, so they cannot all be fired at the commit.
var _fx_due: Array = []
## Sounds waiting on a clock, oldest first: each tile's flip as it starts to
## turn, and the win or the loss once the row that decided it has landed.
var _cue_due: Array = []
## The sprout the reveal raises. Built on the first ending and kept, because
## Reset can put the board back into play and a second sixth row can come.
var _sprout: Control = null

# --- the polish pass ---
## Per row, Snail Mail: whether it turned over sealed, and the second the
## snail's delivery began turning it again (-100 until then).
var _sealed: Array[bool] = []
var _deliver_at: Array[float] = []
## The rows the grid is laid out for, and the moment it began growing to
## them from the count before (One more row).
var _grow_from := float(State.ROWS)
var _grow_at := -100.0
## The bed a press went down on, or -1.
var _touch_cell := -1
## Where the caret was, and when it left there.
var _caret_from := 0
var _caret_at := -100.0
## The second the working row filled its fifth bed.
var _ready_at := -100.0
## The second the rows ran out and every tile drooped (-100: they have not).
var _droop_at := -100.0
## Per tile, a gag and the second it began: {Vector2i(r, c): {"kind", "at"}}.
var _gags: Dictionary = {}
## Per row, a reaction still to come: [{"at", "r"}], and the bubble.
var _react_due: Array = []
var _bubble: Control = null
## Per row: when it put its sunglasses on, and when it congaed.
var _glasses_at: Dictionary = {}
var _conga_at: Dictionary = {}
## The most greens any shown row had, and every position ever greened.
var _best := 0
var _greened: Dictionary = {}
## The party: when it began (INF until a solve's), and the seal.
var _party_at := INF
var _stamp: Control = null
var _cheer := 0
## Snail Mail's courier, and where it crawled from and when.
var _snail: Control = null
var _snail_from_row := 0
var _snail_to_row := 0
var _snail_at := -100.0
## Out of rows: the host's hook (it reads `out_of_hearts`), the card, and
## whether this word has had its one more row.
var out_of_hearts := false
var _card: Control = null
var _row_bought := false
## Set while restore_completed_board() lays a finished day back down, so the
## stamp and the cheer stand rather than arrive.
var _restoring := false
## Bumped whenever the board is dealt or reset, so a timer `_after` set for
## the board before it does nothing.
var _gen := 0

var _opened := 0.0
var _anim_until := 0.0
## The band, built once per layout, and the grid, rebuilt while it moves.
var _band_mesh: ArrayMesh
var _grid_mesh: ArrayMesh
## The toast's pill and the reveal's word card, each built once -- when the
## line changes and when the reveal begins -- and drawn with a transform, so
## neither is rebuilt per frame while it moves.
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""
## The line the toast in hand says, settled when it is raised: the clue
## rule's two name a letter, which the state forgets on the next refusal.
var _toast_text := ""
var _reveal_mesh: ArrayMesh
## The meshes the last _draw actually handed to the canvas item. A canvas
## command holds a mesh by RID and not by reference, so dropping the only
## reference to a mesh still on the item's command list leaves the renderer
## drawing a freed RID ("Parameter mesh is null", and an empty card).
var _shown: Array = []
## The grid's pieces (the board checkup, 2026-10-02): every bed, tile, caret
## and shadow is a shape made once at the cell it is laid out at and copied
## natively into a run of vertices its cell owns (`RunMesh`), painted by
## colour fills. Built in script, a vertex at a time, it was 4-8 ms on every
## frame anything on the grid moved -- each typed letter, each flip.
var _rm := RunMesh.new(_shape)
## The cell the shapes and runs were made at; another remakes them.
var _rm_cell := -1.0

enum { SHAPE_SQ, SHAPE_LIP, SHAPE_TOP, SHAPE_BEVEL, SHAPE_CARET, SHAPE_SHADOW, SHAPE_FLAP, SHAPE_WAX }
enum { PART_CARET, PART_CELL }

func puzzle_id() -> String: return "hiddenword"
func title() -> String: return "Hidden Word"

## The rule, then Hard's clue rule, then Insane's snail.
func rules() -> String:
	var out := tr("HW_RULES")
	if state.strict:
		out += "\n\n" + tr("HW_RULES_STRICT")
	if state.snail:
		out += "\n\n" + tr("HW_RULES_SNAIL")
	return out

## Hidden Word has no cycling tip, but it still uses the shared How to play
## card as the door to the rules sheet. Keep its resting line specific to this
## game instead of falling back to Binairo's default tip.
func tip_line() -> Dictionary:
	if state.snail:
		return {"text": tr("HW_TIP_SNAIL"), "mood": Face.Expr.HAPPY}
	return {"text": tr("HW_TIP"), "mood": Face.Expr.HAPPY}

## The tutorial (the board checkup, 2026-10-02): one page a rule, each two
## rows of the board itself over the game's own keyboard
## (ui/hud/hidden_word_tutorial_diagram.gd) -- a guess and its colours, the
## keys that keep them, a tapped bed and the back key, the bulb where the band
## has one, running out of rows, and the clue rule on Hard and Snail Mail on
## Insane.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/hidden_word_tutorial_diagram.gd")
	# The band's own count (State.HINTS_BY_BAND), read off the rules it set.
	var hints: int = State.HINTS_BY_BAND[3 if state.no_hints else (2 if state.strict else 0)]
	var steps := [
		[Diagram.Lesson.GUESS, "HTP_HW_GUESS", tr("HTP_HW_GUESS_BODY")],
		[Diagram.Lesson.CLUES, "HTP_HW_CLUES", tr("HTP_HW_CLUES_BODY")],
		[Diagram.Lesson.TAP, "HTP_HW_TAP", tr("HTP_HW_TAP_BODY")]]
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_HW_HINT_BODY_ONE") if hints == 1 else tr("HTP_HW_HINT_BODY_N") % hints])
	steps.append([Diagram.Lesson.ROWS, "HTP_HW_ROWS",
		tr("HTP_HW_ROWS_BODY_INK") if state.keeps_rows else tr("HTP_HW_ROWS_BODY")])
	if state.strict:
		steps.append([Diagram.Lesson.STRICT, "HTP_HW_STRICT", tr("HTP_HW_STRICT_BODY")])
	if state.snail:
		steps.append([Diagram.Lesson.SNAIL, "HTP_HW_SNAIL", tr("HTP_HW_SNAIL_BODY")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.hints = hints
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Hint alone. Every Enter *is* the check, and taking a committed guess back
## is not this game, so there is no Check and no Undo -- the top bar hides
## what is not named here.
func capabilities() -> Array[String]:
	return [] if state.no_hints else ["hint"]

func _ready() -> void:
	# The keyboard takes the letters; the card answers only a tap on a bed
	# of the row in hand (_has_point), which moves the caret there.
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	resized.connect(_layout)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	# Insane's word comes out of the Snail Mail bank (content/insane/
	# hiddenword.json, the words the delayed colours make hardest, graded by
	# tools/insane/hiddenword_ladder.py); an empty bank falls back to the list.
	var banked := ""
	if difficulty >= 3:
		banked = String(InsaneBank.pick(puzzle_id(), bank_step).get("answer", ""))
	state.setup(rng, difficulty, banked)
	state.seen = 0
	_gen += 1
	if _tray != null:
		_tray.match_locale()
	_clear_rows()
	_grow_from = float(state.tries)
	_grow_at = -100.0
	_row_bought = false
	_clear_working()
	_given_at = {}
	_flip_at = -100.0
	_flip_row = -1
	_keys_due = []
	_clear_endings()
	_layout()
	_enter()

## Everything a finished board leaves behind: the refusal in hand, the solve,
## the reveal and the waves either of them owns. Both build() (a new word) and
## reset_board() (the same word again) go through it, because a board that
## kept `_over_at` would raise the sprout over an empty grid.
func _clear_endings() -> void:
	_toast = 0
	_toast_at = -100.0
	_solved_at = -100.0
	_over_at = -100.0
	_ghosts = []
	_fx_due = []
	_cue_due = []
	_react_due = []
	_droop_at = -100.0
	_party_at = INF
	out_of_hearts = false
	_close_card()
	_drop_bubble()
	if is_instance_valid(_stamp):
		_stamp.queue_free()
	_stamp = null
	if _sprout != null:
		_sprout.visible = false
		_sprout.hat = 0.0
		_sprout.glasses = 0.0
	_bring_keys_back()

## Every row's moments, for a board whose rows are all going: a new word, a
## Reset on Easy and Medium, a restore.
func _clear_rows() -> void:
	_row_at = []
	_shiver_at = []
	_sealed = []
	_deliver_at = []
	for _r in State.MAX_ROWS:
		_row_at.append(-100.0)
		_shiver_at.append(-100.0)
		_sealed.append(false)
		_deliver_at.append(-100.0)
	_gags = {}
	_glasses_at = {}
	_conga_at = {}
	_best = 0
	_greened = {}
	_caret_from = 0
	_caret_at = -100.0
	_ready_at = -100.0
	_snail_from_row = 0
	_snail_to_row = 0
	_snail_at = -100.0
	_seat_snail()

## Puts a keyboard that was sent away back on screen. `slide_out` is
## reversible: the same tray slides back from the same `enter_from`, fades in
## and re-enables every key, so nothing here has to be undone by hand.
func _bring_keys_back() -> void:
	_keys_out_at = INF
	if _tray != null and _tray.gone:
		_tray.enter(0.0)

## The keyboard, handed over by the host once per spawn. The board paints it
## from the row it has just marked; nothing else writes to it.
func set_tray(t: Control) -> void:
	_tray = t
	_tray.match_locale()
	# A handoff is once per board, and the same tray outlives the board that
	# had it: the settings sheet's New puzzle spawns a fresh one against it.
	# So the new word starts with the keys untouched, and with the keyboard
	# on screen even if the board before it ran out of rows and sent it away.
	_tray.clear_marks()
	_bring_keys_back()

# --- layout ---

## The largest tile six rows of five hold inside a card of `available`
## height, once the band at its foot has been paid for. Height binds on a
## 9:16 phone -- 149 against the 177.6 the width would allow -- which is why
## the band costs the grid its cell rather than its air.
func _cell_for(available: float) -> float:
	var w := size.x - INSET * 2.0
	var h := available - INSET * 2.0 - BAND
	var n := _rows_f()
	return maxf(0.0, minf((w - GAP * float(State.LEN - 1)) / float(State.LEN),
		(h - GAP * (n - 1.0)) / n))

## The rows the grid is laid out for right now: the word's own count, or on
## the way there from the count before while One more row makes room.
func _rows_f() -> float:
	var since := _now() - _grow_at
	if Motion.reduce or since >= GROW_TIME or since < 0.0:
		return float(state.tries)
	return lerpf(_grow_from, float(state.tries), Motion.back_out(since / GROW_TIME))

func _cell() -> float:
	return _cell_for(size.y)

## The grid block's own size: five tiles across, six down, with the gaps.
func _block() -> Vector2:
	var c := _cell()
	var n := _rows_f()
	return Vector2(float(State.LEN) * c + GAP * float(State.LEN - 1),
		n * c + GAP * (n - 1.0))

## The card this board wants: the block, the band and the inset either side.
## At 1140 of slot that is 964 + 120 + 56 = 1140 again, so the card fills the
## slot exactly and the slack card_centred() would halve is zero.
func card_height(available: float) -> float:
	var c := _cell_for(available)
	if c <= 0.0:
		return available
	var n := _rows_f()
	return minf(available, n * c + GAP * (n - 1.0) + BAND + INSET * 2.0)

## True, and honestly so: the height binds in a 9:16 slot with the band or
## without it, so **the slack is zero at 1080x1920 and this call does nothing
## on the phone this game is built for**. It earns its keep on a squarer
## screen, where the width binds instead and the block wants centring.
func card_centred() -> bool:
	return true

## The card's top inside this Control's rect. The host centres the card in
## the slot when card_centred() is true, and the block has to be seated
## against the card and not against the slot, or the two drift apart on a
## screen where the slack is not zero.
func _card_top() -> float:
	return maxf(0.0, (size.y - card_height(size.y)) * 0.5)

## The grid block's top-left inside this Control's rect.
func _origin() -> Vector2:
	return Vector2((size.x - _block().x) * 0.5, _card_top() + INSET)

## The centre of the block: what the entrance pops about.
func _grid_centre() -> Vector2:
	return _origin() + _block() * 0.5

## The top-left of the tile at (row, column).
func _tile_at(r: int, c: int) -> Vector2:
	var cell := _cell()
	return _origin() + Vector2(float(c) * (cell + GAP), float(r) * (cell + GAP))

## Control-local point over the centre of the tile at (row, column), the name
## every flat board gives it.
func cell_to_local(r: int, c: int) -> Vector2:
	return _tile_at(r, c) + Vector2.ONE * (_cell() * 0.5)

## The band's top, which the reveal stands on.
func _reveal_top() -> float:
	return _origin().y + _block().y + REVEAL_TOP

func _layout() -> void:
	_band_mesh = null
	_reveal_mesh = null
	_toast_mesh = null
	_toast_mesh_for = ""
	_refresh()

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	var now := _now()
	_deliver_keys(now)
	_deliver_fx(now)
	_deliver_cues(now)
	_expire(now)
	_send_keys_away(now)
	_ride_sprout(now)
	_deliver_reacts(now)
	_ride_snail(now)
	if now < _grow_at + GROW_TIME + 0.1:
		_refit_card()
	if _laid_out() and _animating(now):
		queue_redraw()

## Drops what has finished: the toast once its pop-out is spent, and Reset's
## tiles once theirs is. Both are drawn off their own moment, so leaving them
## in the list would only cost work -- but the toast must go, or _draw would
## keep asking pop_out_scale for a scale it has already answered zero to.
func _expire(now: float) -> void:
	var dropped := false
	if _toast > 0 and now - _toast_at >= TOAST_HOLD + Motion.POP_OUT:
		_toast = 0
		dropped = true
	for i in range(_ghosts.size() - 1, -1, -1):
		if now - float(_ghosts[i].at) >= Motion.POP_OUT:
			_ghosts.remove_at(i)
			dropped = true
	for key in _gags.keys():
		if now - float(_gags[key].at) >= maxf(LOVE_TIME + 0.5, SPRIG_TIME):
			_gags.erase(key)
			dropped = true
	for r in _glasses_at.keys():
		if now - float(_glasses_at[r]) >= GLASSES_TIME:
			_glasses_at.erase(r)
			dropped = true
	# The frame that drops the last of them may be the first frame
	# `_animating` has answered false on, and then nothing would ask for the
	# draw that takes it off the screen. Asking here costs one draw and does
	# not depend on `_busy_for` having been given a hair more than it needs.
	if dropped:
		_refresh()

## The keyboard leaves when the sixth row has landed and not a moment before:
## it slides out over KEYS_OUT and every key stops taking input.
func _send_keys_away(now: float) -> void:
	if now < _keys_out_at:
		return
	_keys_out_at = INF
	if _tray != null:
		_tray.slide_out(KEYS_OUT)

## The engine runs _process and _draw from the moment the node enters the
## tree; the board only exists once build() has been through and the host's
## layout has given it a rect.
func _laid_out() -> bool:
	return _row_at.size() == State.MAX_ROWS and _cell() > 0.0

## True while **any** wave on this board is still running. Two moments are
## named outright -- the entrance and the flip -- and every other one
## registers its own end through `_busy_for`, so a wave says how long it needs
## at the moment it starts rather than being remembered here. In full, what
## `_anim_until` is holding open for:
##
## - the typed letter's pop and the erased one's turn out (TYPE_POP, POP_OUT);
## - the refused row's shiver and **the toast** over it, which outlives the
##   shiver five times over (TOAST_HOLD + POP_OUT);
## - **the hint's** ghost letter dropping in and the key greening behind it
##   (DROP_TIME + BUMP_TIME; the ring and the sparkles are the Fx2D node's
##   own children and animate themselves);
## - the row's flip and the keyboard's repaint after it (the `landed` window
##   plus BUMP_TIME, which commit_row posts);
## - **the solve**, from the moment the row lands through the last tile's hop
##   (SOLVE_DELAY + four SOLVE_STAGGERs + SOLVE_TIME) -- longer than the dim
##   behind it, so the one figure covers both;
## - **the reveal**, from the same landing through the sprout's rise
##   (REVEAL_WAIT + REVEAL_TIME) -- longer than the rows' dim and the
##   keyboard's exit;
## - **Reset's** wave, the last tile's delay plus its turn out.
##
## There is deliberately no branch for the keyboard's pending repaint. The
## window before it lands is the flip's own, which the line below already
## covers, and the BUMP_TIME after it is covered by commit_row's `_busy_for`.
## A branch here read `_keys_due`'s due time a frame after _process had
## already delivered and dropped it, so it never saw the window it claimed to
## hold open. One Line froze two lines at four fifths of their fade by asking
## about the entrance alone; it showed on a rendered frame and in no test.
func _animating(t: float) -> bool:
	if t < _opened + Motion.ENTER_DELAY + Motion.ENTER_POP:
		return true
	if _flip_row >= 0 and t < _flip_at + _flip_length():
		return true
	if t < _grow_at + GROW_TIME:
		return true
	return t < _anim_until

## Keeps the board redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Drops the grid mesh so the next _draw rebuilds it, and asks for that draw.
## The mesh the last _draw handed over is still held by _shown, so the
## renderer is never left pointing at a freed RID.
func _refresh() -> void:
	_grid_mesh = null
	queue_redraw()

# --- the drawing ---

## The band under everything, still; then the grid, which pops in wide about
## its centre (rule 7: a wide thing comes from most of the way) while it
## fades, as one draw transform over the mesh; then the letters over that,
## one draw command each.
func _draw() -> void:
	if not _laid_out():
		return
	var now := _now()
	var shown: Array = []
	# The band stands on the grid's foot, which moves while One more row
	# makes room: rebuilt every frame of that and never otherwise.
	if _band_mesh == null or now < _grow_at + GROW_TIME:
		_band_mesh = _build_band()
	if _band_mesh != null:
		draw_mesh(_band_mesh, null)
		shown.append(_band_mesh)
	if _grid_mesh == null or _animating(now):
		_grid_mesh = _build_grid(now)
	if _grid_mesh != null:
		var since := now - _opened - Motion.ENTER_DELAY
		var seen := Motion.appear_level(since, Motion.ENTER_POP)
		if seen > 0.0:
			var grow := Motion.wide_pop_scale(since)
			var mid := _grid_centre()
			draw_mesh(_grid_mesh, null,
				Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow)),
				Color(1.0, 1.0, 1.0, seen))
			shown.append(_grid_mesh)
	_draw_letters(now)
	_draw_glasses(now, shown)
	_draw_reveal(now, shown)
	_draw_toast(now, shown)
	_shown = shown

## The scenery band at the card's foot: two clouds high in the side air the
## band bought, a washed turf with a lighter crown along its top, blades
## standing out of it, three bushes on the ground line and the mock's three
## flowers. It stands still -- only the grid takes the entrance -- so it is
## built once per layout and drawn with no transform.
##
## The clouds are the family's own (ui/flat/scenery.gd, the shape and the
## lift Balance's card wears); they go into this board's builder rather than
## into a Scenery node of their own so the whole band costs one draw call.
func _build_band() -> ArrayMesh:
	var cell := _cell()
	if cell <= 0.0:
		return null
	var b := Face.Builder.new()
	var x0 := INSET
	var w := size.x - INSET * 2.0
	var top := _card_top()
	var y0 := _origin().y + _block().y
	var ground := y0 + BAND - TURF_TOP
	var puff: Color = Pal.PARCHMENT.lerp(Pal.SURFACE, Scenery.CLOUD_LIFT)
	Scenery.cloud(b, Vector2(x0 + CLOUD_LEFT.x, top + CLOUD_LEFT.y), CLOUD_LEFT.z, puff)
	Scenery.cloud(b, Vector2(x0 + w - CLOUD_RIGHT.x, top + CLOUD_RIGHT.y), CLOUD_RIGHT.z, puff)
	var turf: Color = Pal.LEAF.lerp(Pal.PARCHMENT, TURF_WASH)
	var crown: Color = Pal.LEAF_LIGHT.lerp(Pal.PARCHMENT, CROWN_WASH)
	b.fan(Face.Builder.round_rect(Vector2(x0, ground), Vector2(w, BAND - TURF_TOP), TURF_RADIUS), turf)
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
	for bush: Vector2 in [BUSH_LEFT, BUSH_MID, BUSH_RIGHT]:
		_bush(b, _span(x0, w, bush.x), ground, bush.y, deep, lit)
	for flower: Vector2 in [FLOWER_LEFT, FLOWER_MID, FLOWER_RIGHT]:
		_flower(b, Vector2(_span(x0, w, flower.x), ground + flower.y))
	return b.mesh() if not b.verts.is_empty() else null

## The mock's own x convention for a thing on the band: a fraction of the
## width between 0 and 1, so many pixels in from the left above that, and so
## many in from the right when it is negative.
func _span(x0: float, w: float, x: float) -> float:
	if x > 0.0 and x < 1.0:
		return x0 + w * x
	return x0 + (x if x >= 0.0 else w + x)

## Three deep puffs with a lit one on the shoulder, seated on the ground line.
func _bush(b, x: float, ground: float, r: float, deep: Color, lit: Color) -> void:
	b.disc(Vector2(x, ground - r * 0.58), r, deep)
	b.disc(Vector2(x - r * 0.82, ground - r * 0.24), r * 0.64, deep)
	b.disc(Vector2(x + r * 0.84, ground - r * 0.26), r * 0.6, deep)
	b.disc(Vector2(x - r * 0.24, ground - r * 0.9), r * 0.4, lit)

## Five petals round a sun-coloured eye.
func _flower(b, at: Vector2) -> void:
	for k in FLOWER_PETALS:
		var a := float(k) / float(FLOWER_PETALS) * TAU
		b.disc(at + Vector2(cos(a), sin(a)) * FLOWER_R, PETAL_R, Pal.SURFACE)
	b.disc(at, FLOWER_EYE_R, Pal.SUN)

## The cells, in one mesh. Every cell is a bed sunk into the card; a typed
## letter stands on a paper piece popping into its bed, and a committed tile
## is that piece turning over -- into its mark's colour, or on Insane into a
## sealed envelope that turns again when the snail brings its colours --
## lifted off the card while it turns and bumping as it lands. The row being
## typed is lit and the bed its next letter goes into wears a caret that
## glides there. A refused row shivers as one, so the offset is read per row
## and not per tile; everything else a tile does (the ready hop, the solve's
## hop and dance, a conga, a twirl, the droop) comes out of `_move`, which the
## letters read too, so a glyph never leaves its tile.
##
## There is no `Mosaic.socket` here: a bed is this board's own, because the
## piece that lands in it is a card and not a tile, and it has to show under a
## piece squashed edge-on by the flip.
func _build_grid(t: float) -> ArrayMesh:
	var cell := _cell()
	_lay_runs(cell)
	_rm.begin()
	# What has no run of its own (the party's meadow, Reset's ghosts, the
	# gags) goes on the tail, after every run.
	var b := Face.Builder.new()
	var work := _working_row()
	var lit_row := -1 if state.is_solved() or out_of_hearts else work
	for r in state.tries:
		var shake := Motion.shiver_offset(t - _shiver_at[r])
		var fade := _row_alpha(r, t)
		var rise := _enter_rise(r, t)
		if r == lit_row:
			_rm.open(PART_CARET, r)
			_caret(r, t, cell, fade, shake, rise)
		for c in State.LEN:
			_rm.open(PART_CELL, r * State.LEN + c)
			var seat := _tile_at(r, c) + Vector2(shake, rise)
			_bed(seat, cell, fade, 1.0 if r == lit_row else 0.0)
			var move := _move(r, c, t)
			var at := seat + Vector2(move.x, move.y)
			if r < state.rows.size():
				var pose := _pose(r, c, t)
				var up := at + Vector2(0.0, pose.z * cell)
				var swell := _swell(r, c, t)
				if swell > 0.0:
					_rm.put(SHAPE_SHADOW, [Color(Pal.TEXT, FLIP_SHADOW_A * swell * fade)],
						Transform2D(0.0, at + Vector2(cell * 0.5, cell * 0.96)))
				var grow := Vector2(pose.x, pose.y)
				match _face_at(r, c, t):
					FACE_MARK:
						_mark_tile(up, cell, int(state.marks[r][c]), r, c, grow, fade,
							move.z, _shine(r, c, t))
					FACE_POST:
						_post_tile(up, cell, grow, fade, move.z)
					_:
						_paper_tile(up, cell, grow, fade, move.z)
			elif r == work and state.letter_at(c) != "":
				_paper_tile(at, cell, Motion.pop_in_scale(t - _typed_at[c], TYPE_POP), fade, move.z)
			elif _party_at < INF and r > state.rows.size() - 1:
				_bloom(b, seat + Vector2.ONE * (cell * 0.5), cell, r, c, t)
	# Reset's wave, over the beds the tiles have just gone back to being: a
	# committed tile keeps its mark's colour and turns out where it stood.
	_rm.open(-1, 0)
	for g in _ghosts:
		var elapsed: float = t - float(g.at)
		var at := _tile_at(int(g.r), int(g.c))
		if elapsed < 0.0:
			_mark_tile(at, cell, int(g.m), int(g.r), int(g.c), Vector2.ONE)
			continue
		var out := Motion.pop_out_scale(elapsed)
		if out <= 0.0:
			continue
		_mark_tile(at, cell, int(g.m), int(g.r), int(g.c), Vector2.ONE * out, 1.0,
			_turn_out(elapsed))
	_draw_gags(b, t, cell)
	_rm.put_builder(b)
	return _rm.mesh()

## Every cell's run, laid in paint order -- a row's caret, then its five
## cells -- each as long as the most a cell ever puts (a bed, a flip's
## shadow, a sealed tile with its flap and wax). Laid again only when the
## cell changes (a new layout, One more row making room).
func _lay_runs(cell: float) -> void:
	if _rm.laid() and is_equal_approx(cell, _rm_cell):
		return
	_rm_cell = cell
	_rm.reset()
	var sq := _rm.size_of(SHAPE_SQ)
	var room := sq + _rm.size_of(SHAPE_LIP) + _rm.size_of(SHAPE_SHADOW) \
		+ sq + _rm.size_of(SHAPE_TOP) + _rm.size_of(SHAPE_BEVEL) \
		+ _rm.size_of(SHAPE_FLAP) + _rm.size_of(SHAPE_WAX)
	for r in State.MAX_ROWS:
		_rm.room(PART_CARET, r, _rm.size_of(SHAPE_CARET))
		for c in State.LEN:
			_rm.room(PART_CELL, r * State.LEN + c, room)

## Shape `id` about its own centre at the cell `_rm_cell`, in slot colours.
func _shape(id: int) -> Face.Builder:
	var s := _rm_cell
	var b := Face.Builder.new()
	var r := s * RADIUS
	var corner := -Vector2.ONE * (s * 0.5)
	var edge := maxf(EDGE_MIN, s * EDGE)
	var ink := RunMesh.slot(0)
	match id:
		SHAPE_SQ:
			b.fan(Face.Builder.round_rect(corner, Vector2(s, s), r), ink)
		SHAPE_LIP:
			var lip := s * BED_LIP
			b.fan(Face.Builder.round_rect(corner + Vector2(0.0, lip), Vector2(s, s - lip), r), ink)
		SHAPE_TOP:
			b.fan(Face.Builder.round_rect(corner, Vector2(s, s - edge), r), ink)
		SHAPE_BEVEL:
			var bev := s * BEVEL
			b.fan(Face.Builder.round_rect(corner + Vector2(bev * 0.7, bev),
				Vector2(s - bev * 1.4, s - edge - bev), maxf(r - bev * 0.5, 0.0)), ink)
		SHAPE_CARET:
			var w := s * CARET
			b.fan(Face.Builder.round_rect(corner - Vector2.ONE * w, Vector2.ONE * (s + w * 2.0), r + w), ink)
		SHAPE_SHADOW:
			Scenery.soft_disc(b, Vector2.ZERO, s * 0.5, s * 0.12, ink)
		SHAPE_FLAP:
			b.polygon(PackedVector2Array([Vector2(-0.4, -0.4) * s, Vector2(0.4, -0.4) * s,
				Vector2(0.0, -0.08) * s]), ink)
		SHAPE_WAX:
			b.disc(Vector2.ZERO, s * WAX_R, ink)
	return b

## The flip in effect on tile (r, c) at `t`: when it began, and the face it
## turns from and to. A row turns once from paper into its marks -- or, on
## Snail Mail, into a sealed envelope, and again when the snail brings it.
func _turning(r: int, c: int, t: float) -> Array:
	var step := float(c) * FLIP_STEP
	if _sealed[r]:
		if _deliver_at[r] > -50.0 and t >= _deliver_at[r] + step:
			return [_deliver_at[r] + step, FACE_POST, FACE_MARK]
		return [_row_at[r] + step, FACE_PAPER, FACE_POST]
	return [_row_at[r] + step, FACE_PAPER, FACE_MARK]

## The face a committed tile shows at `t`: the one it turns to once it is
## past edge-on, the one it turns from before.
func _face_at(r: int, c: int, t: float) -> int:
	var turning := _turning(r, c, t)
	return int(turning[2]) if _flip(r, c, t).y >= 1.0 else int(turning[1])

## When row `r` began turning into its colours, or -100 while it is sealed.
func _revealed_at(r: int) -> float:
	return _deliver_at[r] if _sealed[r] else _row_at[r]

## Everything a tile does on top of its seat: x and y its offset in pixels,
## z its turn. The solve's hop and the party's dance on the winning row, the
## eager hop of a full row, a conga, a twirl and the droop when the rows run
## out. Nothing under reduce motion but the solve's own hop, which the
## reader already answers zero to there.
func _move(r: int, c: int, t: float) -> Vector3:
	var out := Vector3(0.0, _solve_lift(r, c, t), 0.0)
	if Motion.reduce:
		return out
	var cell := _cell()
	if r == _working_row() and state.filled() and c < State.LEN:
		out.y += Motion.hop_lift(t - (_ready_at + float(c) * READY_STEP), READY_HOP, READY_TIME)
	if _conga_at.has(r):
		for lap in 2:
			out.y += Motion.hop_lift(t - (float(_conga_at[r]) + float(lap * State.LEN + c) * CONGA_STEP),
				CONGA_HOP, Motion.HOP_TIME)
	var gag: Dictionary = _gags.get(Vector2i(r, c), {})
	if gag.get("kind", "") == "twirl":
		var u := clampf((t - float(gag.at)) / TWIRL_TIME, 0.0, 1.0)
		if u > 0.0 and u < 1.0:
			out.z += TAU * _ease_io(u)
			out.y -= TWIRL_HOP * cell * sin(PI * u)
	if r == state.rows.size() - 1 and state.is_solved() and t >= _party_at:
		var p := (t - _party_at) / DANCE_BEAT
		if p < float(DANCE_BEATS):
			var fall := 1.0 - p / float(DANCE_BEATS)
			out.z += DANCE_TILT * sin(PI * p) * fall
			out.y += DANCE_HOP * absf(sin(PI * (p + float(c) * 0.25))) * fall
	if _droop_at > -50.0 and r < state.rows.size():
		var u := clampf((t - _droop_at - float(r * State.LEN + c) * DROOP_STEP) / DROOP_TIME, 0.0, 1.0)
		var sag := 1.0 - pow(1.0 - u, 3.0)
		out.y += DROOP * cell * sag
		out.z += DROOP_TILT * sag * (1.0 if _hash(r * State.LEN + c, 11) > 0.5 else -1.0)
	return out

static func _ease_io(u: float) -> float:
	return 0.5 - 0.5 * cos(PI * u)

## How far row `r` still is below its seat on the way in: the rows arrive top
## to bottom inside the grid's own wide pop, and a row One more row has just
## added rises the same way.
func _enter_rise(r: int, t: float) -> float:
	if Motion.reduce:
		return 0.0
	var since := t - (_opened + Motion.ENTER_DELAY + float(r) * ENTER_ROW)
	if r >= State.ROWS and _grow_at > -50.0:
		since = t - _grow_at
	return ENTER_RISE * (1.0 - Motion.back_out(clampf(since / Motion.ENTER_POP, 0.0, 1.0)))

## The sun rim round the bed the next letter goes into -- the next empty
## one, or whichever the player tapped -- gliding there from the bed it was
## round over CARET_GLIDE.
func _caret(r: int, t: float, cell: float, alpha: float, shake: float, rise: float) -> void:
	var to: int = state.cursor
	if to >= State.LEN or alpha <= 0.0:
		return
	var u := 1.0 if Motion.reduce else clampf((t - _caret_at) / CARET_GLIDE, 0.0, 1.0)
	var col := lerpf(float(_caret_from), float(to), 1.0 - pow(1.0 - u, 3.0))
	var at := _tile_at(r, 0) + Vector2(col * (cell + GAP) + shake, rise)
	_rm.put(SHAPE_CARET, [Color(Pal.SUN, CARET_A * alpha)], Transform2D(0.0, at + Vector2.ONE * (cell * 0.5)))

## A committed tile's pose at `t`: x and y its scale, z how far it has risen,
## in cells (negative is up). The flip squashes y; the swell grows both and
## lifts it; the landing bumps both once it is face-up again.
func _pose(r: int, c: int, t: float) -> Vector3:
	var turn := _flip(r, c, t)
	var swell := _swell(r, c, t)
	var grow := (1.0 + FLIP_SWELL * swell) * _land(r, c, t)
	return Vector3(grow, grow * turn.x, -FLIP_RISE * swell)

## How far into its lift a turning tile is: nothing at either end of its turn
## and all of it edge-on, where the colour changes.
func _swell(r: int, c: int, t: float) -> float:
	if Motion.reduce:
		return 0.0
	var since := t - float(_turning(r, c, t)[0])
	if since <= 0.0 or since >= FLIP_TIME:
		return 0.0
	return sin(PI * since / FLIP_TIME)

## The bump a tile lands with, the family's own reader at this board's size.
func _land(r: int, c: int, t: float) -> float:
	return Motion.bump_scale(t - (float(_turning(r, c, t)[0]) + FLIP_TIME), LAND_BUMP)

## How far a landed green tile is into its glint. Only HITs catch the light,
## a tile after the one before, once the whole row is face-up; a row put back
## by a restore has no moment and never glints.
func _shine(r: int, c: int, t: float) -> float:
	var from := _revealed_at(r)
	if Motion.reduce or from < -50.0 or int(state.marks[r][c]) != State.HIT:
		return 0.0
	var since := t - (from + _flip_length() + GLINT_DELAY + float(c) * GLINT_STEP)
	if since <= 0.0 or since >= GLINT_TIME:
		return 0.0
	return sin(PI * since / GLINT_TIME)

## How long a landed row's glint runs, from the landing to the last tile's end.
func _glint_length() -> float:
	return GLINT_DELAY + float(State.LEN - 1) * GLINT_STEP + GLINT_TIME

## The quarter turn a thing leaving takes with it, `elapsed` into its pop out.
func _turn_out(elapsed: float) -> float:
	return PI * 0.5 * clampf(elapsed / Motion.POP_OUT, 0.0, 1.0)

## How lit row `r` is. The solve leaves the winning row alone and takes the
## rows that came before it back to SOLVE_DIM, so the answer is the only
## thing burning; the reveal takes the whole grid to OVER_DIM, because there
## is no winning row to spare. An empty bed keeps its own light either way,
## which is the mock's own reading: a bed is not a guess. A row One more row
## has just added fades in as the grid makes room for it.
func _row_alpha(r: int, t: float) -> float:
	var a := 1.0
	if _over_at > -50.0:
		a = lerpf(1.0, OVER_DIM, Motion.appear_level(t - _over_at, DIM_TIME))
	if _solved_at > -50.0 and r < state.rows.size() and r != state.rows.size() - 1:
		a *= lerpf(1.0, SOLVE_DIM, Motion.appear_level(t - _solved_at, Motion.SOLVE_TIME))
	if r >= State.ROWS and _grow_at > -50.0 and not Motion.reduce:
		a *= clampf((t - _grow_at) / GROW_TIME, 0.0, 1.0)
	return a

## The solve's hop: the winning row's tiles lift SOLVE_HOP letter by letter,
## SOLVE_STAGGER apart after SOLVE_DELAY, from the moment the row **landed**
## and not from the Enter that won it.
func _solve_lift(r: int, c: int, t: float) -> float:
	if _solved_at <= -50.0 or r != state.rows.size() - 1:
		return 0.0
	return Motion.hop_lift(t - (_solved_at + Motion.SOLVE_DELAY + float(c) * Motion.SOLVE_STAGGER),
		Motion.SOLVE_HOP, Motion.SOLVE_TIME)

## A tile's turn at `t`: x is its scale.y, y is 1 once it has taken its new
## face. `abs(cos(PI * u))` squashes it to nothing and back over FLIP_TIME,
## and the face arrives at the halfway point -- edge-on, so the answer comes
## *with* the turn. Under reduce motion the row turns in one frame.
func _flip(r: int, c: int, t: float) -> Vector2:
	var since := t - float(_turning(r, c, t)[0])
	if Motion.reduce or since >= FLIP_TIME:
		return Vector2(1.0, 1.0)
	if since <= 0.0:
		return Vector2(1.0, 0.0)
	var u := since / FLIP_TIME
	return Vector2(absf(cos(PI * u)), 1.0 if u >= 0.5 else 0.0)

## An empty bed at `at` (its top-left): the lip in BED_SHADE, the floor over
## it a little down, lit `lit` of ROW_LIT toward the sun on the row being
## typed. The caret round the next one is `_caret`'s, drawn first.
func _bed(at: Vector2, s: float, alpha: float, lit: float) -> void:
	if alpha <= 0.0:
		return
	var floor_col: Color = BED.lerp(Pal.SUN, ROW_LIT * lit)
	var shade: Color = BED_SHADE.lerp(Pal.SUN, ROW_LIT * lit * 0.5)
	var xf := Transform2D(0.0, at + Vector2.ONE * (s * 0.5))
	_rm.put(SHAPE_SQ, [Color(shade, alpha)], xf)
	_rm.put(SHAPE_LIP, [Color(floor_col, alpha)], xf)

## A typed letter's piece: paper with a lit rim round a crown a shade toward
## SURFACE_HI, over a lip toward LINE.
func _paper_tile(at: Vector2, s: float, grow: Vector2, alpha: float, angle := 0.0) -> void:
	var crown: Color = Pal.SURFACE.lerp(Pal.SURFACE_HI, PAPER_CROWN)
	var deep: Color = Pal.SURFACE_HI.lerp(Pal.LINE, PAPER_LIP)
	_tile_face(at, s, crown, deep, grow, alpha, angle, Pal.SURFACE)

## Snail Mail's sealed tile: a moonlit envelope, its flap folded down in a
## shade toward MOON_INK, a berry wax seal in its corner, the letter over it.
func _post_tile(at: Vector2, s: float, grow: Vector2, alpha: float, angle := 0.0) -> void:
	var deep: Color = POST.lerp(Pal.MOON_INK, POST_DEEP)
	_tile_face(at, s, POST, deep, grow, alpha, angle, POST.lerp(Pal.SURFACE, 0.6))
	if grow.x <= 0.0 or grow.y <= 0.0 or alpha <= 0.0:
		return
	var xf := Transform2D(angle, grow, 0.0, at + Vector2.ONE * (s * 0.5))
	_rm.put(SHAPE_FLAP, [Color(POST.lerp(Pal.MOON_INK, POST_FLAP), alpha)], xf)
	_rm.put(SHAPE_WAX, [Color(Pal.BERRY, alpha)],
		Transform2D(0.0, Vector2.ONE * minf(grow.x, grow.y), 0.0, xf * (Vector2(0.3, 0.27) * s)))

## A committed tile in mark `m`'s colour, toned off its cell's hash, bevelled,
## and shining `shine` of SHINE toward SURFACE at the top of a glint.
func _mark_tile(at: Vector2, s: float, m: int, r: int, c: int, grow: Vector2,
		alpha := 1.0, angle := 0.0, shine := 0.0) -> void:
	var fill: Color = MARK[m]
	var tone := _hash(r * State.LEN + c, 3) * 2.0 - 1.0
	fill = fill.lightened(tone * TONE) if tone > 0.0 else fill.darkened(-tone * TONE)
	var deep: Color = fill.lerp(Pal.TEXT, EDGE_MIX)
	var rim: Color = fill.lerp(Pal.SURFACE, RIM_LIGHT)
	if shine > 0.0:
		fill = fill.lerp(Pal.SURFACE, shine * SHINE)
		rim = rim.lerp(Pal.SURFACE, shine * SHINE)
	_tile_face(at, s, fill, deep, grow, alpha, angle, rim)

## One piece: its face over a bottom edge in a darker shade of itself, the
## soft lip every card on these screens wears, drawn at `grow` of its size
## about its own centre so the flip's squash reads. With a `rim`, the face is
## the rim and the crown sits BEVEL down and in from it, so the piece is lit
## along its top and sides. The shapes are the cell's own (`_shape`), so `s`
## is the cell they were made at.
func _tile_face(at: Vector2, s: float, fill: Color, deep: Color, grow: Vector2,
		alpha := 1.0, angle := 0.0, rim := Color(0.0, 0.0, 0.0, 0.0)) -> void:
	if grow.x <= 0.0 or grow.y <= 0.0 or alpha <= 0.0:
		return
	var xf := Transform2D(angle, grow, 0.0, at + Vector2.ONE * (s * 0.5))
	_rm.put(SHAPE_SQ, [Color(deep, deep.a * alpha)], xf)
	if rim.a <= 0.0:
		_rm.put(SHAPE_TOP, [Color(fill, fill.a * alpha)], xf)
		return
	_rm.put(SHAPE_TOP, [Color(rim, rim.a * alpha)], xf)
	_rm.put(SHAPE_BEVEL, [Color(fill, fill.a * alpha)], xf)

## The letters, over the grid's mesh and inside the same entrance: the
## working row's in ink, a committed row's in paper once its tile has turned
## far enough to carry one (in ink on a sealed envelope), and the letter an
## erase took away turning out where it stood. Every glyph takes its tile's
## `_move`, so a dancing, drooping or twirling tile carries its letter.
func _draw_letters(t: float) -> void:
	var cell := _cell()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var pop := Motion.wide_pop_scale(since)
	var mid := _grid_centre()
	var font: Font = CozyTheme.display(700)
	var work := _working_row()
	for r in state.tries:
		var shake := Motion.shiver_offset(t - _shiver_at[r])
		var fade := _row_alpha(r, t) * seen
		var rise := _enter_rise(r, t)
		for c in State.LEN:
			var move := _move(r, c, t)
			var seat := cell_to_local(r, c) + Vector2(shake + move.x, move.y + rise)
			seat = mid + (seat - mid) * pop
			if r < state.rows.size():
				var turn := _flip(r, c, t)
				if absf(turn.x) <= LETTER_EDGE:
					continue
				var pose := _pose(r, c, t)
				var ink: Color = Pal.PAPER if _face_at(r, c, t) == FACE_MARK else Pal.TEXT
				_glyph(seat + Vector2(0.0, pose.z * cell * pop), cell, state.rows[r][c],
					Vector2(pose.x, pose.y) * pop, move.z, ink, font, fade)
			elif r == work:
				if state.letter_at(c) != "":
					var grow := Motion.pop_in_scale(t - _typed_at[c], TYPE_POP)
					_glyph(seat, cell, state.letter_at(c), grow * pop, move.z, Pal.TEXT, font, fade)
				elif _gone_at[c] > 0.0 and t - _gone_at[c] < Motion.POP_OUT and not Motion.reduce:
					if t < _gone_at[c]:
						_glyph(seat, cell, _gone_ch[c], Vector2.ONE * pop, 0.0, Pal.TEXT, font, fade)
					else:
						_letter_out(seat, cell, _gone_ch[c], t - _gone_at[c], pop, fade, font)
				elif state.given.has(c):
					# What a hint gave: the answer's own letter, dropping into
					# the column it belongs to and standing there ghosted
					# until the player types over it.
					_ghost_letter(seat, cell, state.answer[c],
						t - float(_given_at.get(c, -100.0)), pop, fade, font)
	# Reset's wave carries the letters out with the tiles.
	for g in _ghosts:
		var elapsed: float = t - float(g.at)
		var seat := cell_to_local(int(g.r), int(g.c))
		seat = mid + (seat - mid) * pop
		if elapsed < 0.0:
			Mosaic.letter(self, seat, cell, String(g.ch), Vector2.ONE * pop, Pal.PAPER, font, seen)
			continue
		_letter_out(seat, cell, String(g.ch), elapsed, pop, seen, font, Pal.PAPER)

## One letter seated on its tile's centre at `grow` and turned `angle` with
## it -- Mosaic.letter's own measure, which takes no angle because nothing
## else in the game turns a glyph.
func _glyph(seat: Vector2, cell: float, ch: String, grow: Vector2, angle: float,
		ink: Color, font: Font, alpha: float) -> void:
	if absf(angle) < 0.0001:
		Mosaic.letter(self, seat, cell, ch, grow, ink, font, alpha)
		return
	if ch.is_empty() or alpha <= 0.0 or grow.x <= 0.0 or grow.y <= 0.0:
		return
	var px := int(cell * Mosaic.LETTER_SIZE)
	var text := ch.to_upper()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var where := Vector2(-w * 0.5, font.get_height(px) * 0.5 - font.get_descent(px))
	draw_set_transform(seat, angle, grow)
	font.draw_string(get_canvas_item(), where, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(ink, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- the gags, the sunglasses and the meadow (polish spec, section 3) ---

## The gags still running, into the grid's mesh: little hearts floating up
## off a new green, and a sprig of two leaves popping out of its shoulder and
## waving. A twirl is the tile's own turn (`_move`). Spent ones are dropped
## by `_expire`.
func _draw_gags(b, t: float, cell: float) -> void:
	if Motion.reduce:
		return
	for key in _gags:
		var gag: Dictionary = _gags[key]
		var since: float = t - float(gag.at)
		if since < 0.0:
			continue
		var top := _tile_at(key.x, key.y) + Vector2(cell * 0.5, 0.0)
		match String(gag.kind):
			"love":
				for k in LOVE_HEARTS:
					var u := (since - float(k) * 0.14) / LOVE_TIME
					if u <= 0.0 or u >= 1.0:
						continue
					var sway := sin(u * TAU * 1.5 + float(k)) * cell * 0.1
					var x := (float(k) - 1.5) * cell * 0.18 + sway
					var at := top + Vector2(x, -u * LOVE_RISE * cell)
					var a := minf(1.0, (1.0 - u) * 2.5) * minf(1.0, u * 8.0)
					_heart(b, at, LOVE_R * cell * (0.8 + 0.4 * _hash(k, key.y)), Color(Pal.BERRY, a))
			"sprig":
				var u := since / SPRIG_TIME
				if u >= 1.0:
					continue
				var grow := Motion.back_out(clampf(since / 0.3, 0.0, 1.0))
				var a := minf(1.0, (1.0 - u) * 4.0)
				var wave := sin(since * 9.0) * 0.25 * (1.0 - u)
				var foot := _tile_at(key.x, key.y) + Vector2(cell * 0.82, cell * 0.08)
				_leaf(b, foot, SPRIG_R * cell * grow, -0.7 + wave, Color(Pal.LEAF, a))
				_leaf(b, foot, SPRIG_R * cell * 0.8 * grow, 0.5 + wave, Color(Pal.LEAF_LIGHT, a))

## A little heart, point down, centred on `at`.
static func _heart(b, at: Vector2, r: float, colour: Color) -> void:
	if colour.a <= 0.0 or r <= 0.0:
		return
	b.disc(at + Vector2(-r * 0.5, 0.0), r * 0.58, colour)
	b.disc(at + Vector2(r * 0.5, 0.0), r * 0.58, colour)
	b.polygon(PackedVector2Array([at + Vector2(-r * 1.04, r * 0.16), at + Vector2(r * 1.04, r * 0.16),
		at + Vector2(0.0, r * 1.15)]), colour)

## A leaf `len` long from `foot`, turned `angle` off straight up.
static func _leaf(b, foot: Vector2, len: float, angle: float, colour: Color) -> void:
	if len <= 0.5 or colour.a <= 0.0:
		return
	var dir := Vector2(sin(angle), -cos(angle))
	var side := Vector2(-dir.y, dir.x) * len * 0.42
	var tip := foot + dir * len
	var pts := Face.Builder.bezier2(foot, foot + dir * len * 0.5 + side, tip, 6)
	var back := Face.Builder.bezier2(tip, foot + dir * len * 0.5 - side, foot, 6)
	for i in range(1, back.size()):
		pts.append(back[i])
	b.polygon(pts, colour)

## A flower opening in bed (r, c) of a row the solve left unplayed -- the
## meadow the party grows -- with a twist and a stagger down the grid.
func _bloom(b, centre: Vector2, cell: float, r: int, c: int, t: float) -> void:
	var order := float((r - state.rows.size()) * State.LEN + c)
	var since := t - (_party_at + order * BLOOM_STEP)
	var grow := 1.0 if Motion.reduce else Motion.back_out(clampf(since / BLOOM_TIME, 0.0, 1.0))
	if grow <= 0.0 or (since < 0.0 and not Motion.reduce):
		return
	var petal: Color = [Pal.FLOWER, Pal.SUN_RAY, Pal.SURFACE, Pal.BERRY_TILE][posmod(r * 3 + c, 4)]
	var rad := cell * 0.13 * grow
	var turn := (1.0 - grow) * 1.2 + _hash(r, c) * TAU
	for k in FLOWER_PETALS:
		var a := turn + float(k) / float(FLOWER_PETALS) * TAU
		b.disc(centre + Vector2(cos(a), sin(a)) * rad * 1.25, rad, petal)
	b.disc(centre, rad * 0.75, Pal.SUN)
	for k in 2:
		_leaf(b, centre + Vector2(0.0, rad * 1.6), cell * 0.18 * grow, -0.9 + 1.8 * float(k), Pal.LEAF)

## The sunglasses a clean miss puts on its row: two dark lenses over its
## second and fourth tiles and a bridge between, dropping in and lifting off.
## Their own small mesh, drawn after the letters so they cover two of them --
## that is the joke.
func _draw_glasses(t: float, shown: Array) -> void:
	if _glasses_at.is_empty() or Motion.reduce:
		return
	var cell := _cell()
	for r in _glasses_at:
		var since: float = t - float(_glasses_at[r])
		if since < 0.0 or since > GLASSES_TIME:
			continue
		var lift := Motion.drop_in_lift(since, cell * 0.6, 0.28)
		var off := since - (GLASSES_TIME - 0.3)
		if off > 0.0:
			lift -= cell * 0.8 * (off / 0.3) * (off / 0.3)
		var a := 1.0 - clampf(off / 0.3, 0.0, 1.0)
		var left := cell_to_local(r, 1)
		var right := cell_to_local(r, 3)
		var b := Face.Builder.new()
		var ink := Color(Pal.OUTLINE, 0.94 * a)
		var lens := Vector2(cell * 0.86, cell * 0.5)
		for at: Vector2 in [left, right]:
			var tl := at - lens * 0.5 + Vector2(0.0, -cell * 0.04 - lift)
			b.fan(Face.Builder.round_rect(tl, lens, cell * 0.2), ink)
			b.fan(Face.Builder.round_rect(tl + Vector2(lens.x * 0.14, lens.y * 0.16),
				Vector2(lens.x * 0.22, lens.y * 0.12), lens.y * 0.06), Color(Pal.SURFACE, 0.55 * a))
		var bridge_y := left.y - cell * 0.16 - lift
		b.fan(Face.Builder.round_rect(Vector2(left.x + lens.x * 0.45, bridge_y),
			Vector2(right.x - left.x - lens.x * 0.9, cell * 0.08), cell * 0.04), ink)
		var mesh := b.mesh()
		draw_mesh(mesh, null)
		shown.append(mesh)

## A hint's letter: it drops in from DROP above its column with the fade and
## then stands at GHOST in LEAF_DEEP, a given rather than a guess. Drawn
## whether or not the board is moving, because the ghost outlives its drop --
## it is there until the player types over that column, and under reduce
## motion it is simply there from the first frame.
func _ghost_letter(seat: Vector2, cell: float, ch: String, elapsed: float,
		pop: float, seen: float, font: Font) -> void:
	var a := Motion.appear_level(elapsed, Motion.DROP_FADE) * GHOST * seen
	if a <= 0.0:
		return
	var lift := Motion.drop_in_lift(elapsed)
	Mosaic.letter(self, seat - Vector2(0.0, lift * pop), cell, ch,
		Vector2.ONE * pop, Pal.LEAF_DEEP, font, a)

## The letter an erase took away: it shrinks out with the quarter turn where
## it stood, the family's own way out for a drawn thing. Mosaic.letter takes
## no angle -- nothing else in the game turns a glyph -- so this seats the
## same string itself, with Mosaic's own measure, rather than growing that
## call an argument its two other callers would never pass.
func _letter_out(seat: Vector2, cell: float, ch: String, elapsed: float,
		pop: float, seen: float, font: Font, ink: Color = Pal.TEXT) -> void:
	if ch.is_empty():
		return
	var grow := Motion.pop_out_scale(elapsed)
	if grow <= 0.0:
		return
	var angle := _turn_out(elapsed)
	var px := int(cell * Mosaic.LETTER_SIZE)
	var text := ch.to_upper()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var where := Vector2(-w * 0.5, font.get_height(px) * 0.5 - font.get_descent(px))
	draw_set_transform(seat, angle, Vector2.ONE * (grow * pop))
	font.draw_string(get_canvas_item(), where, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		px, Color(ink, seen))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- the toast (spec section 8) ---

## The refusal's pill, over the top of the grid and over the card's own edge:
## TEXT at TOAST_INK with the line in PAPER, popping in about its centre,
## holding TOAST_HOLD and popping out. Both scales are the family's readers
## at their own lengths, so the pill arrives and leaves like every other
## small thing on these screens and this board adds no number for it.
##
## Refusals do not get a card and they never get a colour: nothing here goes
## red, because a word this board does not know is not the player's mistake.
func _draw_toast(t: float, shown: Array) -> void:
	if _toast <= 0:
		return
	var since := t - _toast_at
	if since < 0.0:
		return
	var grow: Vector2
	if since < TOAST_HOLD:
		grow = Motion.pop_in_scale(since)
	else:
		var out := Motion.pop_out_scale(since - TOAST_HOLD)
		if out <= 0.0:
			return
		grow = Vector2.ONE * out
	if grow.x <= 0.0 or grow.y <= 0.0:
		return
	var font: Font = CozyTheme.body(700)
	var line: String = _toast_text
	var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x + TOAST_PAD
	if _toast_mesh == null or _toast_mesh_for != line:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-w, -TOAST_H) * 0.5, Vector2(w, TOAST_H), TOAST_RADIUS),
			Color(Pal.TEXT, TOAST_INK))
		_toast_mesh = b.mesh() if not b.verts.is_empty() else null
		_toast_mesh_for = line
	if _toast_mesh == null:
		return
	var mid := Vector2(size.x * 0.5, _card_top() - TOAST_RISE + TOAST_H * 0.5)
	draw_mesh(_toast_mesh, null, Transform2D(0.0, grow, 0.0, mid))
	shown.append(_toast_mesh)
	var where := Vector2(-w * 0.5 + TOAST_PAD * 0.5,
		font.get_height(TOAST_FONT) * 0.5 - font.get_descent(TOAST_FONT))
	draw_set_transform(mid, 0.0, grow)
	font.draw_string(get_canvas_item(), where, line, HORIZONTAL_ALIGNMENT_LEFT, -1,
		TOAST_FONT, Color(Pal.PAPER, TOAST_INK))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- the reveal (spec section 8) ---

## The word on its own small card at the foot of the board, beside the sprout
## the board raises with it. It rises with the sprout and fades in with it,
## off the same two readers, because one is a node and the other is drawn and
## they have to arrive as one thing.
func _draw_reveal(t: float, shown: Array) -> void:
	var from := _stage_at()
	if from <= -50.0:
		return
	var since := t - from - REVEAL_WAIT
	var a := Motion.appear_level(since, REVEAL_FADE)
	if a <= 0.0:
		return
	if _reveal_mesh == null:
		var b := Face.Builder.new()
		var w := size.x - WORD_CARD_X - WORD_CARD_RIGHT
		b.fan(Face.Builder.round_rect(Vector2(WORD_CARD_X, 0.0), Vector2(w, WORD_CARD_H),
			WORD_CARD_RADIUS), Pal.LINE)
		b.fan(Face.Builder.round_rect(Vector2(WORD_CARD_X, 0.0),
			Vector2(w, WORD_CARD_H - WORD_CARD_EDGE), WORD_CARD_RADIUS), Pal.SURFACE)
		_reveal_mesh = b.mesh() if not b.verts.is_empty() else null
	if _reveal_mesh == null:
		return
	var top := _reveal_top() + _reveal_rise(since)
	draw_mesh(_reveal_mesh, null, Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0.0, top)),
		Color(1.0, 1.0, 1.0, a))
	shown.append(_reveal_mesh)
	var x := WORD_CARD_X + WORD_TEXT_X
	if state.is_solved():
		# The party's card: the word found, and the sprout's silly cheer.
		_line(CozyTheme.display(700, WORD_SPACING), WORD_FONT, Vector2(x, top + WORD_LABEL_Y + 2.0),
			state.written.to_upper(), Color(Pal.GOOD, a))
		_line(CozyTheme.body(500), WORD_LABEL_FONT - 4, Vector2(x, top + WORD_Y + 4.0),
			tr("HW_CHEER_%d" % _cheer), Color(Pal.TEXT_DIM, a))
		return
	_line(CozyTheme.body(500), WORD_LABEL_FONT, Vector2(x, top + WORD_LABEL_Y),
		tr("HW_WORD_WAS"), Color(Pal.TEXT_DIM, a))
	_line(CozyTheme.display(700, WORD_SPACING), WORD_FONT, Vector2(x, top + WORD_Y),
		state.written.to_upper(), Color(Pal.GOOD, a))

## How far below its seat the reveal still is, `since` seconds in: REVEAL_RISE
## taken home by the back ease, the curve `Motion.slide` would have used on a
## node. Nothing under reduce motion -- the sprout and the card are simply
## there.
func _reveal_rise(since: float) -> float:
	if Motion.reduce:
		return 0.0
	return REVEAL_RISE * (1.0 - Motion.back_out(clampf(since / REVEAL_TIME, 0.0, 1.0)))

## One line of text seated by its left edge and its middle, the way the mock
## lays every line out; draw_string wants a baseline instead.
func _line(font: Font, px: int, at: Vector2, text: String, colour: Color) -> void:
	font.draw_string(get_canvas_item(),
		at + Vector2(0.0, font.get_height(px) * 0.5 - font.get_descent(px)),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, colour)

## The sprout rides the board's clock, as One Line's walker does: it is a
## node (ui/faces/sprout_face.gd draws itself), but the card beside it is
## drawn, and a tween on one of them and a reader on the other would arrive a
## frame apart. Both read `_over_at` every frame instead.
func _ride_sprout(t: float) -> void:
	if _sprout == null or not _sprout.visible:
		return
	var since := t - _stage_at() - REVEAL_WAIT
	var seat := Vector2(SPROUT_AT.x, _reveal_top() + SPROUT_AT.y + _reveal_rise(since))
	_sprout.position = seat - _sprout.size * 0.5
	_sprout.modulate.a = Motion.appear_level(since, REVEAL_FADE)

## When the band's stage -- the sprout and the card beside it -- came up: the
## reveal's moment, or the party's, or -100 for neither.
func _stage_at() -> float:
	if _over_at > -50.0:
		return _over_at
	if _party_at < INF:
		return _party_at
	return -100.0

## The sprout the reveal brings, built on the first ending and kept after it.
## It is sized so R comes out at SPROUT_R once the face's own REACH -- the
## room its leaves need above the blob -- has been paid for.
func _raise_sprout(mood: int = Face.Expr.HAPPY, party := false) -> void:
	if _sprout == null:
		_sprout = SproutFace.new()
		_sprout.name = "Sprout"
		_sprout.z_index = 1
		add_child(_sprout)
	var px := SPROUT_R * 2.0 * SproutFace.REACH
	_sprout.size = Vector2(px, px)
	_sprout.expression = mood
	_sprout.visible = true
	_sprout.modulate.a = 0.0
	_sprout.hat = 1.0 if party and (Motion.reduce or _restoring) else 0.0
	_ride_sprout(_now())
	_sprout.set_idle(true)
	if party and not Motion.reduce and not _restoring:
		var tw := _sprout.create_tween()
		tw.tween_interval(REVEAL_WAIT + REVEAL_TIME)
		tw.tween_property(_sprout, "hat", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- the three moves ---

## The row being typed, or -1 once all six are committed.
func _working_row() -> int:
	return state.rows.size() if state.rows.size() < state.tries else -1

## A letter off the keyboard. The tile takes it with the pop and the caret
## glides on to the next empty bed; the letter that fills the row makes it
## hop, ready.
func type_letter(letter: String) -> void:
	if out_of_hearts:
		return
	var was_full: bool = state.filled()
	var i: int = state.type_letter(letter)
	if i < 0:
		return
	var now := _now()
	_typed_at[i] = now
	_gone_at[i] = -100.0
	_gone_ch[i] = ""
	_caret_from = i
	_caret_at = now
	_busy_for(maxf(TYPE_POP, CARET_GLIDE))
	fx.cue("type")
	if state.filled() and not was_full:
		_ready_at = now + TYPE_POP * 0.5
		_busy_for(TYPE_POP * 0.5 + READY_TIME + float(State.LEN - 1) * READY_STEP)
		fx.cue("ready")
	_refresh()

## Backspace. The letter under the caret -- or, on an empty bed, the nearest
## one to its left -- shrinks out with the quarter turn; the tile it was on
## stays where it is and goes back to being a bed, and the caret glides to it.
func erase_letter() -> void:
	if out_of_hearts:
		return
	var from: int = mini(state.cursor, State.LEN - 1)
	var before: String = state.typed
	var i: int = state.erase()
	if i < 0:
		return
	var ch: String = before[i]
	var now := _now()
	_typed_at[i] = -100.0
	_gone_at[i] = now
	_gone_ch[i] = ch
	_caret_from = from
	_caret_at = now
	_busy_for(maxf(Motion.POP_OUT, CARET_GLIDE))
	fx.cue("erase")
	_refresh()

## A tap on a bed of the row in hand: the caret glides there and the next
## letter goes into it, over whatever it holds.
func select_cell(c: int) -> void:
	if out_of_hearts or is_done() or _working_row() < 0:
		return
	var from: int = mini(state.cursor, State.LEN - 1)
	if not state.select(c):
		return
	_caret_from = from
	_caret_at = _now()
	_busy_for(CARET_GLIDE)
	fx.cue("type")
	_refresh()

## The bed of the row in hand under a board-local point, or -1.
func _cell_at(local: Vector2) -> int:
	var r := _working_row()
	if r < 0 or not _laid_out():
		return -1
	var cell := _cell()
	for c in State.LEN:
		if Rect2(_tile_at(r, c) - Vector2.ONE * GAP * 0.5, Vector2.ONE * (cell + GAP)).has_point(local):
			return c
	return -1

## Only the row in hand takes a tap; everywhere else the card lets it
## through to whatever lies under.
func _has_point(point: Vector2) -> bool:
	return _cell_at(point) >= 0

## Press and release on the same bed selects it, as Code Break's seats do.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventMouseButton):
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	var c := _cell_at(event.position)
	if event.pressed:
		_touch_cell = c
		accept_event()
		return
	if _touch_cell >= 0 and c == _touch_cell:
		select_cell(c)
		accept_event()
	_touch_cell = -1

## Enter. On OK the row turns over, a tile at a time; on any refusal nothing
## commits, nothing counts, and the row shivers where it is while the toast
## names the rule.
##
## On Snail Mail an OK row turns over **sealed** -- unless it is the answer,
## or the last row there is -- and the row the snail was carrying turns into
## its colours once the new one has landed; then the snail crawls down to the
## new one. The keyboard, the reactions and the ending all wait for the rows
## they read to show their colours, never for the Enter.
func commit_row() -> void:
	if is_done() or out_of_hearts:
		return
	# The row that shivers is the one being typed. A commit that fills the
	# last row always ends the board or raises the card before commit_row
	# returns, so a call that gets this far finds rows.size() < state.tries.
	var row: int = state.rows.size()
	var code := state.commit()
	if code != State.OK:
		_refuse(row, code)
		return
	var now := _now()
	_flip_row = row
	_flip_at = now
	_row_at[row] = now
	var sealed: bool = state.snail and state.delivered() < state.rows.size()
	_sealed[row] = sealed
	_clear_working()
	_caret_from = 0
	_caret_at = -100.0
	var landed := now + _flip_length()
	# One flip a tile as it starts to turn, a touch higher each, so the row
	# is heard going over the way it is seen; under reduce motion, one. A
	# sealed row folds like paper instead.
	for c in (1 if Motion.reduce else State.LEN):
		_cue_due.append({"at": now + float(c) * FLIP_STEP, "cue": "post" if sealed else "flip",
			"pitch": 1.0 + 0.04 * float(c)})
	# The rows this Enter shows the colours of, each with when it has landed.
	var shown: Array = []
	for r in row:
		if not _sealed[r] or _deliver_at[r] > -50.0 or r >= state.delivered():
			continue
		# Good news travels fast: with the answer or the last row, the snail
		# brings the row it carries while the new one turns.
		var at := now if not sealed or Motion.reduce else landed + DELIVER_AFTER
		_deliver_at[r] = at
		shown.append([r, at + _flip_length()])
		_cue_due.append({"at": at, "cue": "snail" if sealed else "snail_hurry"})
	# The new row after the ones the snail brought, so a row reacts against
	# what the rows before it found and never the other way round.
	if not sealed:
		shown.append([row, landed])
	if sealed and row > 0:
		_snail_from_row = row - 1
		_snail_to_row = row
		_snail_at = (landed + DELIVER_AFTER if not Motion.reduce else now) + SNAIL_CRAWL * 0.3
	_cue_due.sort_custom(func(a, b) -> bool: return float(a.at) < float(b.at))
	var last := now
	var letters: Array = []
	for pair in shown:
		last = maxf(last, float(pair[1]))
		letters.append(int(pair[0]))
	if not letters.is_empty():
		var due := _keys_payload_rows(letters)
		due["at"] = last
		due["seen"] = state.delivered()
		_keys_due.append(due)
		if Motion.reduce:
			_deliver_keys(last)
	_busy_for(last - now + maxf(Motion.BUMP_TIME, _glint_length()))
	if sealed:
		_busy_for(landed - now + DELIVER_AFTER + SNAIL_CRAWL * 1.3)
	if state.is_solved():
		_solved_at = landed
		_cue_due.append({"at": landed, "cue": "solved"})
		if not Motion.reduce:
			for c in State.LEN:
				_fx_due.append({
					"at": landed + Motion.SOLVE_DELAY + float(c) * Motion.SOLVE_STAGGER,
					"r": row, "c": c, "colour": Pal.SUN,
				})
		_party(landed)
	else:
		for pair in shown:
			_react_due.append({"at": float(pair[1]) + REACT_AT, "r": int(pair[0])})
		_react_due.sort_custom(func(a, b) -> bool:
			return float(a.at) < float(b.at) or (float(a.at) == float(b.at) and int(a.r) < int(b.r)))
		if state.is_over():
			_run_out(last)
	_refresh()
	note_move()

## A refused Enter: the row shivers, the toast names the rule -- the clue
## rule's two name the letter and the place -- and nothing counts.
func _refuse(row: int, code: int) -> void:
	_shiver_at[row] = _now()
	_toast = code
	_toast_at = _now()
	_toast_text = tr(TOAST_LINE[code])
	var broken: Dictionary = state.broken
	if code == State.KEEP_GREEN and not broken.is_empty():
		_toast_text = _toast_text % [String(broken.letter).to_upper(), tr(PLACE[int(broken.at)])]
	elif code == State.USE_LETTER and not broken.is_empty():
		_toast_text = _toast_text % String(broken.letter).to_upper()
	_busy_for(maxf(Motion.SHIVER_TIME, TOAST_HOLD + Motion.POP_OUT))
	fx.cue("refused")
	_refresh()

# --- what a row that shows its colours earns (polish spec, section 3) ---

## Runs the reactions that have come due, oldest first.
func _deliver_reacts(now: float) -> void:
	while not _react_due.is_empty() and now >= float(_react_due[0].at):
		var due: Dictionary = _react_due.pop_front()
		_react(int(due.r))

## Row `r` has landed face-up. Every green it found at a place no row had
## greened plucks a note a step up the scale, and three in five of them do
## something silly. Then the row as a whole may earn a word: a clean miss
## puts on sunglasses ("Cool. Five crossed off."), every letter found congas
## ("Everyone's here!"), and more greens than any row before is "Warmer!" --
## "So close!" with confetti at four.
func _react(r: int) -> void:
	if r < 0 or r >= state.rows.size():
		return
	var now := _now()
	var hits := 0
	var near := 0
	var fresh: Array[int] = []
	for c in State.LEN:
		var m := int(state.marks[r][c])
		if m == State.HIT:
			hits += 1
			if not _greened.has(c):
				fresh.append(c)
		elif m == State.NEAR:
			near += 1
	var gagged := false
	for i in fresh.size():
		var c: int = fresh[i]
		_greened[c] = true
		var step: int = COMBO_STEPS[mini(_greened.size() - 1, COMBO_STEPS.size() - 1)]
		_cue_due.append({"at": now + float(i) * 0.09, "cue": "combo", "pitch": pow(2.0, float(step) / 12.0)})
		if Motion.reduce or gagged:
			continue
		var h := posmod(hash(Vector3i(r, c, state.answer.hash())), 1000)
		if h % GAG_ODDS >= GAGS:
			continue
		# One gag a row, so a row of greens is funny and not a fairground.
		gagged = true
		var kind: String = ["love", "twirl", "sprig"][(h / GAG_ODDS) % 3]
		var at := now + float(i) * 0.09 + 0.15
		_gags[Vector2i(r, c)] = {"kind": kind, "at": at}
		_cue_due.append({"at": at, "cue": {"love": "love", "twirl": "twirl", "sprig": "sprout"}[kind]})
	_cue_due.sort_custom(func(a, b) -> bool: return float(a.at) < float(b.at))
	var best_before := _best
	_best = maxi(_best, hits)
	_busy_for(maxf(LOVE_TIME + 0.6, SPRIG_TIME + 0.3))
	if Motion.reduce or state.is_solved():
		return
	if hits + near == 0:
		_glasses_at[r] = now
		_bubble_at(r, tr("HW_COOL"))
		fx.cue("cool")
		_busy_for(GLASSES_TIME)
	elif hits + near == State.LEN:
		_conga_at[r] = now
		_bubble_at(r, tr("HW_ALL_HERE"))
		fx.cue("all_here")
		_busy_for(float(State.LEN * 2) * CONGA_STEP + Motion.HOP_TIME)
	elif hits > best_before:
		var close := hits == State.LEN - 1
		_bubble_at(r, tr("HW_SO_CLOSE") if close else tr("HW_WARMER"))
		fx.cue("so_close" if close else "warmer")
		if close:
			var left := cell_to_local(r, 0)
			var right := cell_to_local(r, State.LEN - 1)
			fx.confetti((left + right) * 0.5, 28, right.x - left.x)
			fx.cue("confetti")
	_refresh()

## A paper bubble over the row's right shoulder, popping in and fading after
## a hold -- Code Break's, which says the same things about its rows.
func _bubble_at(r: int, text: String) -> void:
	_drop_bubble()
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
	var over := _tile_at(r, State.LEN - 1) + Vector2(_cell(), 0.0)
	var pos := over + Vector2(-bubble.size.x + 16.0, -bubble.size.y + 8.0)
	pos.x = clampf(pos.x, 8.0, size.x - bubble.size.x - 8.0)
	pos.y = maxf(pos.y, 4.0)
	bubble.position = pos
	bubble.pivot_offset = Vector2(bubble.size.x * 0.75, bubble.size.y)
	_bubble = bubble
	Motion.pop_in(bubble)
	var gen := _gen
	get_tree().create_timer(BUBBLE_HOLD).timeout.connect(func() -> void:
		if not is_instance_valid(bubble):
			return
		var out: Tween = Motion.appear(bubble, 1.0, 0.0, Motion.POP_OUT * 2.0)
		if out == null or gen != _gen:
			bubble.queue_free()
		else:
			out.finished.connect(bubble.queue_free))

func _drop_bubble() -> void:
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = null

## Calls `fn` `seconds` from now, unless the board has been dealt or reset
## again by then.
func _after(seconds: float, fn: Callable) -> void:
	if seconds <= 0.0:
		fn.call()
		return
	var gen := _gen
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if gen == _gen and is_instance_valid(self):
			fn.call())

# --- out of rows (polish spec, section 1) ---

## The last row has landed and the word is still hiding: every tile sags and
## leans a little, the snail (if there is one) nods off, and the card asks --
## one more row, or show the word. Until it is answered the board takes no
## keys; the host's Back ends it unsolved (it reads `out_of_hearts`).
func _run_out(landed: float) -> void:
	out_of_hearts = true
	var now := _now()
	_droop_at = landed + (0.0 if Motion.reduce else 0.25)
	_cue_due.append({"at": _droop_at, "cue": "droop"})
	_cue_due.append({"at": _droop_at + 0.5, "cue": "out_of_rows"})
	_cue_due.sort_custom(func(a, b) -> bool: return float(a.at) < float(b.at))
	_busy_for(_droop_at - now + float(state.tries * State.LEN) * DROOP_STEP + DROOP_TIME)
	_after(landed - now + (CARD_AFTER_STILL if Motion.reduce else CARD_AFTER), func() -> void:
		if is_instance_valid(_snail):
			_snail.expression = Face.Expr.SLEEPY
		_open_card())

## The card, over the whole screen: on the host so it covers the chrome, or
## on the root when there is none (a probe). Code Break's card in this
## board's words.
func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_card):
		return
	var card: Control = load(OUT_OF_ROWS).new(_row_bought, {
		"title": "HW_OUT_TITLE", "body": "HW_OUT_BODY", "body_rest": "HW_OUT_BODY_REST",
		"more": "HW_ONE_ROW", "show": "HW_SHOW_WORD", "placement": "row"})
	_card = card
	card.one_more_row.connect(row_back)
	card.show_code.connect(show_word)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

func _close_card() -> void:
	if is_instance_valid(_card) and not _card.is_queued_for_deletion():
		_card.queue_free()
	_card = null

## Asks the flat host to fit its parchment to card_height() again: it only
## does on spawn and on resize, and a seventh row makes the card taller
## wherever the width, not the height, binds the cell.
func _refit_card() -> void:
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self) and host.has_method("_fit_card"):
		host._fit_card()

## One more row (the card's video), once a word: the tiles perk back up, the
## grid makes room for a seventh row, and it rises into place.
func row_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	if not state.add_row():
		return
	_row_bought = true
	out_of_hearts = false
	var now := _now()
	_droop_at = -100.0
	_grow_from = float(state.tries - 1)
	_grow_at = now
	_clear_working()
	if is_instance_valid(_snail):
		_snail.expression = Face.Expr.HAPPY
	_band_mesh = null
	_busy_for(GROW_TIME + Motion.ENTER_POP)
	fx.cue("row_back")
	_refresh()
	moved.emit()

## Show the word: the old ending -- the keyboard slides away and the sprout
## rises with the word on its card -- and the board ends unsolved.
func show_word() -> void:
	if is_done():
		return
	_close_card()
	out_of_hearts = false
	var now := _now()
	_over_at = now
	_keys_out_at = now
	fx.cue("lost")
	_raise_sprout(Face.Expr.HAPPY)
	_busy_for(REVEAL_WAIT + REVEAL_TIME + DIM_TIME)
	finish_unsolved()
	_refresh()

## True while the board is between a thing and its answer -- a row still
## turning, the card coming -- so the host holds its hint video back.
func busy() -> bool:
	return out_of_hearts or _now() < _flip_at + _flip_length() + DELIVER_AFTER + _flip_length()

# --- the party and the seal (polish spec, section 3) ---

## The solve's party, from the winning row's landing: after its hop the
## tiles dance, the rows it never needed bloom into a meadow, the sprout comes
## up on the band in a party hat with a silly cheer, confetti flies twice,
## and the seal drops onto the cheer's card.
func _party(landed: float) -> void:
	var now := _now()
	_party_at = landed + (0.0 if Motion.reduce else PARTY_AT)
	_cheer = posmod(state.answer.hash(), CHEERS)
	_after(_party_at - now, _party_on)
	_after(_party_at - now + (0.0 if Motion.reduce else STAMP_AT), _stamp_down)
	_busy_for(_party_at - now + maxf(float(DANCE_BEATS) * DANCE_BEAT,
		float(State.MAX_ROWS * State.LEN) * BLOOM_STEP + BLOOM_TIME) + REVEAL_WAIT + REVEAL_TIME)

func _party_on() -> void:
	if not state.is_solved():
		return
	_raise_sprout(Face.Expr.JOY, true)
	if Motion.reduce:
		return
	fx.cue("party")
	_after(0.15, fx.cue.bind("dance"))
	var row: int = state.rows.size() - 1
	var left := cell_to_local(row, 0)
	var right := cell_to_local(row, State.LEN - 1)
	fx.confetti((left + right) * 0.5, 44, right.x - left.x)
	_after(0.35, func() -> void:
		fx.confetti(Vector2(size.x * 0.5, _reveal_top()), 30, size.x * 0.6)
		fx.cue("confetti"))
	if is_instance_valid(_snail):
		_snail.expression = Face.Expr.JOY
		var tw := _snail.create_tween()
		tw.tween_property(_snail, "hat", 1.0, 0.3).from(0.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh()

## The seal's word for a solve in `rows` rows: HW_STAMP_1 .. HW_STAMP_6, and
## HW_STAMP_MORE for a word that needed the row the card gave.
func stamp_key() -> String:
	if state.rows.size() > State.ROWS:
		return "HW_STAMP_MORE"
	return "HW_STAMP_%d" % clampi(state.rows.size(), 1, State.ROWS)

## The seal drops onto the right end of the cheer's card from STAMP_FROM its
## size, squashes and rings: gold with the stamp's word, or on Insane the
## night-blue seal with "Snail Mail" over it. It is the result, so it shows
## under reduce motion too, standing still.
func _stamp_down() -> void:
	if is_instance_valid(_stamp) or not state.is_solved():
		return
	var rad := STAMP_R
	var insane: bool = state.snail
	var stamp := Control.new()
	stamp.name = "Stamp"
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.z_index = 3
	stamp.size = Vector2.ONE * rad * 2.0
	stamp.pivot_offset = stamp.size * 0.5
	var centre := Vector2(size.x - WORD_CARD_RIGHT - rad * 0.9, _reveal_top() + WORD_CARD_H * 0.45)
	stamp.position = centre - stamp.pivot_offset
	stamp.rotation = STAMP_TILT
	var mesh := Seal.mesh(rad, insane)
	var word: String = tr(stamp_key())
	var lines := [[Seal.tr_static("HW_SNAIL_SEAL"), 0.26, 0.02], [word, 0.22, 0.36]] if insane \
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
		fx.ring(centre, rad * 0.9, Pal.MOON_INK if insane else Pal.SUN))

# --- Snail Mail's courier (polish spec, section 2) ---

## The snail stands in the side air to the right of the row it carries,
## facing the grid; only Snail Mail has one. Built once and kept.
func _seat_snail() -> void:
	if not state.snail:
		if is_instance_valid(_snail):
			_snail.visible = false
		return
	if not is_instance_valid(_snail):
		_snail = SnailFace.new()
		_snail.name = "Courier"
		_snail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_snail.z_index = 2
		add_child(_snail)
		_snail.set_idle(true)
	_snail.visible = true
	_snail.expression = Face.Expr.HAPPY
	_snail.hat = 0.0

## The snail's seat beside row `r`: in the side air right of the grid.
func _snail_seat(r: int) -> Vector2:
	var cell := _cell()
	var right := _origin().x + _block().x
	var x := right + (size.x - right) * 0.5 - cell * SNAIL_OFF
	return Vector2(x, cell_to_local(r, 0).y + cell * 0.12)

## Rides the board's clock: sat beside the row it carries, or crawling down
## from the one it just delivered, stretching as it goes.
func _ride_snail(t: float) -> void:
	if not is_instance_valid(_snail) or not _snail.visible or not _laid_out():
		return
	var px := _cell() * SNAIL_PX
	_snail.size = Vector2(px, px)
	_snail.pivot_offset = _snail.size * 0.5
	var u := 1.0 if Motion.reduce else clampf((t - _snail_at) / SNAIL_CRAWL, 0.0, 1.0)
	var from := _snail_seat(_snail_from_row)
	var to := _snail_seat(_snail_to_row)
	var at := from.lerp(to, _ease_io(u))
	var stretch := 0.0 if Motion.reduce or u <= 0.0 or u >= 1.0 else sin(u * PI * 3.0) * 0.06
	_snail.scale = Vector2(-(1.0 + stretch), 1.0 - stretch)
	_snail.position = at - _snail.size * 0.5
	_snail.modulate.a = Motion.appear_level(t - _opened - Motion.ENTER_DELAY, Motion.ENTER_POP)

## How long a whole row takes to turn over: the last tile starts four steps
## after the first and turns for FLIP_TIME. Nothing under reduce motion.
func _flip_length() -> float:
	if Motion.reduce:
		return 0.0
	return float(State.LEN - 1) * FLIP_STEP + FLIP_TIME

## What the keys the rows in `rows` touched should say, and which of them
## bump. The marks are read back off the state (`key_mark`, which resolves
## best-mark-wins across every row the snail has brought), so a letter amber
## on row one and green on row three stays green. Called the moment the rows
## are committed or brought, so `key_mark` sees exactly what they show.
func _keys_payload_rows(rows: Array) -> Dictionary:
	var marks: Dictionary = {}
	var letters: Array = []
	for row in rows:
		if row < 0 or row >= state.rows.size():
			continue
		var word: String = state.rows[row]
		for i in State.LEN:
			var ch := word[i]
			if not marks.has(ch):
				letters.append(ch)
			marks[ch] = state.key_mark(ch)
	return {"marks": marks, "letters": letters}

## Hands the keyboard every repaint that has come due, oldest first.
func _deliver_keys(now: float) -> void:
	while not _keys_due.is_empty() and now >= float(_keys_due[0].at):
		var due: Dictionary = _keys_due.pop_front()
		if due.has("seen"):
			state.seen = maxi(state.seen, int(due.seen))
		if _tray == null:
			continue
		_tray.set_marks(due.marks)
		_tray.bump(due.letters)

## Fires the sparkles that have come due. The solve's five are staggered
## across the winning row, so they cannot all be fired at the Enter that won
## it; Fx2D is the only place a spark comes from on this board.
func _deliver_fx(now: float) -> void:
	while not _fx_due.is_empty() and now >= float(_fx_due[0].at):
		var due: Dictionary = _fx_due.pop_front()
		fx.sparkle(cell_to_local(int(due.r), int(due.c)), due.get("colour", Pal.SUN))

## Plays the sounds that have come due (see `_cue_due`).
func _deliver_cues(now: float) -> void:
	while not _cue_due.is_empty() and now >= float(_cue_due[0].at):
		var due: Dictionary = _cue_due.pop_front()
		fx.cue(due.cue, due.get("pitch", 1.0))

func _clear_working() -> void:
	_typed_at = []
	_gone_at = []
	_gone_ch = []
	for _c in State.LEN:
		_typed_at.append(-100.0)
		_gone_at.append(-100.0)
		_gone_ch.append("")

# --- the moments the chrome asks for ---

## The chrome is the host's; here the grid pops in wide after the family's
## delay (in _draw), and the keyboard's own rows slide up under it.
func _enter() -> void:
	_opened = _now()
	_anim_until = _opened
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP)
	fx.cue("enter")

func is_solved() -> bool:
	return state.is_solved()

## The grid, and on a solve the seal's line under it: "🏅 Genius", or on
## Insane "🌙 Snail Mail · Genius".
func share_glyphs() -> String:
	var out: String = state.share_glyphs()
	if state.is_solved():
		var word: String = tr(stamp_key())
		out += "\n" + (("🌙 %s · %s" % [tr("HW_SNAIL_SEAL"), word]) if state.snail else ("🏅 " + word))
	return out

## One more hint beyond the budget (a rewarded video's), kept in the state.
func add_hint() -> void:
	state.hints_left += 1

func hints_left() -> int:
	return state.hints_left

## A hint gives the leftmost letter the player has not greened: a ring over
## its column, the letter dropping into the working row ghosted at GHOST,
## sparkles in leaf, and that key greening with a bump.
##
## **It is a given and not a guess.** It never commits a row, it never counts
## as a move (`hints_used` rises; `moves` does not, so nothing here calls
## `note_move`), and the player still has to type the letter for it to be
## part of a guess. The key's own green goes through `_keys_due` like every
## other repaint on this board, so a hint taken while a row is still turning
## waits its turn behind that row rather than painting over it.
func hint() -> bool:
	var at := state.hint()
	if at < 0:
		return false
	# state.hint() answers -1 on a solved or a spent board, so there is always
	# a working row under the column it chose.
	var work: int = state.rows.size()
	if not Motion.reduce:
		fx.ring(cell_to_local(work, at), _cell() * 0.6, Pal.LEAF)
		_fx_due.append({"at": _now() + Motion.DROP_TIME * 0.5,
			"r": work, "c": at, "colour": Pal.LEAF})
	# Outside the reduce guard on purpose: the ghost is not decoration, it is
	# the letter the hint gave, and under reduce motion it has to be on the
	# board from the next frame rather than not at all.
	_given_at[at] = _now()
	var ch: String = state.answer[at]
	_keys_due.append({
		"at": _now() + (0.0 if Motion.reduce else Motion.DROP_TIME),
		"marks": {ch: State.HIT}, "letters": [ch],
	})
	hints_used += 1
	fx.cue("hint")
	_busy_for(Motion.DROP_TIME + Motion.BUMP_TIME)
	_refresh()
	check_solved()
	return true

## Replays the same day from the first row: every committed row's tiles turn
## out in a wave from the last row up, RESET_STAGGER a tile, and the keys go
## back to their untouched face together.
##
## **What a hint gave stays given.** `state.reset()` clears `rows`, `marks`
## and `typed` and leaves `hints_left` and `given` exactly where they were --
## Queens' own rule, and here it is load-bearing rather than tidy: Reset
## replays the *same word*, so refunding a hint would make the limit of two
## meaningless (hint, Reset, hint, Reset would spell the answer out a letter
## at a time) and discarding `given` would charge the player twice for the
## same letter. `_given_at` therefore survives too, and the ghost is back on
## the first row the moment the wave has passed.
##
## It also has to put a **finished** board back into play. Nothing else on
## this screen can be over without being solved, so nothing else has ever had
## to clear `_done`; a Reset that left it set would hand the player a board
## that took no keys and never ticked again.
func reset_board() -> void:
	if not can_reset():
		return
	if state.keeps_rows:
		_reset_row()
		return
	var wave: Array = []
	if not Motion.reduce:
		for r in state.rows.size():
			for c in State.LEN:
				wave.append({
					"r": r, "c": c, "ch": state.rows[r][c], "m": int(state.marks[r][c]),
					"at": _now() + Motion.stagger(
						(state.rows.size() - 1 - r) * State.LEN + c, Motion.RESET_STAGGER),
				})
	_gen += 1
	state.reset()
	_clear_rows()
	_clear_working()
	_flip_at = -100.0
	_flip_row = -1
	_keys_due = []
	# After _clear_endings, which empties the wave list along with the rest
	# of what the last ending left behind.
	_clear_endings()
	_ghosts = wave
	if _tray != null:
		_tray.clear_marks()
	moves = 0
	_done = false
	_running = true
	_busy_for(Motion.stagger(state.tries * State.LEN - 1, Motion.RESET_STAGGER) + Motion.POP_OUT)
	fx.cue("reset")
	_refresh()

## Hard and Insane: the rows are ink, so Reset sends back only the letters
## typed into the row in hand, right to left, and the caret glides home.
func _reset_row() -> void:
	var now := _now()
	var n: int = state.typed.length()
	for i in n:
		_typed_at[i] = -100.0
		_gone_at[i] = now + float(n - 1 - i) * Motion.RESET_STAGGER * 2.0
		_gone_ch[i] = state.letter_at(i)
	state.reset()
	_caret_from = mini(n, State.LEN - 1)
	_caret_at = now
	_busy_for(float(n) * Motion.RESET_STAGGER * 2.0 + Motion.POP_OUT + CARET_GLIDE)
	fx.cue("reset")
	_refresh()

## Reset gives nothing once the rows have run out (the card is up, or the
## word was shown): on every band it would retire the card, and on Easy and
## Medium it would replay a word already all but read. A live board resets --
## the whole of it on Easy and Medium, the row in hand on Hard and Insane.
func can_reset() -> bool:
	return not (out_of_hearts or state.is_over() or is_done())

## The rows the player committed, oldest first, so a reopened daily can lay
## the same ending back down. Plain strings, because it goes through a
## ConfigFile.
func completion_record() -> Dictionary:
	var out: Array = []
	for word in state.rows:
		out.append(String(word))
	return {"guesses": out}

## A reopened daily that was already solved: the rows go back down already
## committed and turned, in their marks' colours, the keyboard painted from
## them, and nothing moving -- no entrance, no flip, no hop, no sparkle. A
## save from before `completion_record()` existed has no rows to replay, so
## the answer alone stands on row one. Never check_solved(): the day was
## solved once and `solved` must not fire a second time.
func restore_completed_board() -> void:
	var guesses: Array[String] = _recorded_guesses()
	state.rows.clear()
	state.marks.clear()
	state.typed = ""
	state.tries = maxi(State.ROWS, guesses.size())
	_row_bought = guesses.size() > State.ROWS
	_grow_from = float(state.tries)
	_grow_at = -100.0
	for word in guesses:
		state.rows.append(word)
		state.marks.append(State.mark_guess(word, state.answer))
	state.sent = state.rows.size()
	state.seen = state.rows.size()
	var now := _now()
	_gen += 1
	_clear_rows()
	_clear_working()
	_given_at = {}
	_flip_at = -100.0
	_flip_row = -1
	_keys_due = []
	_clear_endings()
	# Settled rather than unset: the rows before the winning one stand at
	# SOLVE_DIM and its hop has long since landed, which is how a live solve
	# leaves the card under the win screen. Ten seconds back and not a
	# hundred: anything under -50 reads as "never solved" (`_row_alpha`).
	_solved_at = now - 10.0
	# The entrance has already played, and so has the party: the meadow
	# stands in the rows it never needed, the sprout is up in its hat with the
	# cheer, and the seal is on the card.
	_opened = now - 10.0
	_anim_until = 0.0
	_party_at = now - 10.0
	_cheer = posmod(state.answer.hash(), CHEERS)
	_restoring = true
	_raise_sprout(Face.Expr.JOY, true)
	_stamp_down()
	_restoring = false
	_refit_card.call_deferred()
	_snail_from_row = state.rows.size() - 1
	_snail_to_row = state.rows.size() - 1
	if is_instance_valid(_snail):
		_snail.expression = Face.Expr.JOY
		_snail.hat = 1.0
	if _tray != null:
		_tray.clear_marks()
		var marks: Dictionary = {}
		for word in state.rows:
			for i in State.LEN:
				marks[word[i]] = state.key_mark(word[i])
		_tray.set_marks(marks)
	_refresh()

## The record's rows if they are a real ending for today's word -- at most six
## five-letter words, none repeated, the last one the answer -- and the answer
## alone otherwise.
func _recorded_guesses() -> Array[String]:
	var out: Array[String] = []
	var raw = completed_record.get("guesses", [])
	if raw is Array and not raw.is_empty() and raw.size() <= State.MAX_ROWS:
		for w in raw:
			var word := String(w).to_lower()
			if word.length() != State.LEN or out.has(word):
				out = []
				break
			out.append(word)
	if out.is_empty() or out[out.size() - 1] != state.answer:
		out = [state.answer]
	return out

## The win screen shows no cast: five green tiles spelling the word are what
## stays on the card under it, the way Nonogram leaves its picture.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("HW_WIN")}

## WIN_WAIT after the winning row has **landed**, not from the Enter that won
## it: `solved` fires the moment Enter is pressed, so a flat WIN_WAIT would
## raise the win screen 0.54 s after the last tile turned -- on top of the
## solve's own hop (`_solve_lift`, above), which starts a quarter of a
## second after the landing and runs for 0.4.
func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else _flip_length() + WIN_WAIT + PARTY_EXTRA

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## A fixed pseudo-random number per blade, so the band's grass is uneven in
## the same way on every launch.
static func _hash(a: int, b: int) -> float:
	return float(posmod(hash(Vector2i(a, b)), 1000)) / 1000.0
