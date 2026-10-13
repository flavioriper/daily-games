extends "res://core/puzzle_base.gd"

## Pixel Garden as a flat board: a pegboard of four plates in a wooden tray
## on the garden table, the day's little pattern card in the corner of the
## card, and a clear compartment box of beads in the picture's colours. Pick
## a colour, tap or drag across the pegs to seat beads, and copy the picture
## peg for peg. The rules live in puzzles/pixel_garden_state.gd, which this
## only draws.
##
## The card holds everything, Quilt's way: the header (the pattern card, its
## name, the hearts on Hard and Insane, the bead box with how many beads each
## compartment has left and the tweezers in the chosen one, and a bar of
## beads seated) over the pegboard, and the actions row under it.
##
## **The board is four plates** clipped together, as a big real pegboard is
## (2026-10-01 polish). A plate holding as many beads as the picture puts on
## it is ironed at once by a little iron with a face: right, it fuses for
## good under it, with steam, a twirl and a word; wrong, the iron frowns and
## the beads astray hop back into their compartments.
##
## Since 2026-10-04 no band has hearts. Insane counts moves instead (a bead
## seated or lifted is one; the pill sits where the hearts did) and no plate
## is ironed there until the picture is right: a verdict on a plate was the
## answer (docs/agents/flat-screens.md, "Insane counts moves").
##
## **Big pictures (2026-10-11).** Hard is 24 pegs square and Insane 32, in
## up to twelve colours, and the pattern card always shows the true picture
## (Windblown is gone). A peg of a 32-square board is too small for a
## finger, so those two bands zoom and pan (ui/flat/pan_zoom.gd): two
## fingers pinch and drag, the round button at the tray's lower left goes
## close and back. The zoom is one transform over the meshes below, never a
## new `_cell`. What is in peg space is drawn by two children behind this
## Control's own drawing -- `_ground` (the table and the tray) and `_field`
## (the plates, pegs, beads and marks, clipped to the tray's floor, under
## `zoom.xf()`) -- and the head, the beads in the air, the words, the held
## picture and the toast are drawn here, over them, and never scale. A
## point of the screen becomes a peg through `zoom.to_layout`.
##
## **The iron is this board's signature.** On the solve the beads hop in the
## family's wave, then the iron crosses the whole board along the diagonal
## in a warm band, each bead's hole closing to a dimple under it with a gloss
## coming up, and the bare pegs fade away behind it.
##
## How it is drawn. Four meshes and some text:
##   table -- the card's table and the tray (`_ground`); the four plates
##            (`_plates`) and every peg, on the field. Built once a layout.
##   head  -- the pattern card's frame, the box, the tweezers, the hearts and
##            the bar. Rebuilt when the kit, the chosen colour or the hearts
##            change, or something in it moves.
##   bands -- every resting bead, in bands of BAND rows, one mesh a band,
##            rebuilt only when the look of one of its pegs changes
##            (Hedgehogs' `_band_looks`).
##   live  -- everything moving: beads popping in or out or flying home, the
##            irons, the hearts of love, the butterfly, Check's halos, the
##            hint's ring and the win's band. Rebuilt only while something
##            moves.
## The beads are ui/faces/bead.gd, which the menu card draws too; the iron
## is ui/faces/iron.gd.
##
## Spec: docs/superpowers/specs/2026-09-27-pixel-garden-flat-design.md and
## docs/superpowers/specs/2026-10-01-pixel-garden-polish-design.md.

signal leave

const State = preload("res://puzzles/pixel_garden_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const Bead = preload("res://ui/faces/bead.gd")
const Iron = preload("res://ui/faces/iron.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Rings = preload("res://puzzles/rings2d.gd")
const Seal = preload("res://ui/flat/seal.gd")
const NapCat = preload("res://ui/faces/nap_cat.gd")
const Cat = preload("res://ui/faces/caterpillar.gd")
const Looks = preload("res://puzzles/pixel_garden_looks.gd")

# --- the card ---
const PAD := 30.0
## The header over the board: the pattern card is HEAD square, and the box,
## the name and the bar stand beside it.
const HEAD := 212.0
## A day of more than ROW_MOST colours stands its compartments in two rows,
## in a taller head (the pattern card grows with it): a 24 or 32 square
## board is bound by the card's width, so the head's extra height costs the
## pegs nothing on a phone.
const HEAD_BIG := 300.0
const ROW_MOST := 7
const HEAD_GAP := 26.0
## The tray's rim round the board, the board's own margin round its pegs, and
## the seam between two plates, in cells -- a hairline, as on a real board.
const RIM := 18.0
const MARGIN := 0.35
const GAP := 0.06
const CARD_RADIUS := 32.0
const BOARD_RADIUS := 22.0
## A compartment of the box: its widest slot and the gap between two. Every
## bead left is drawn in it, so the beads are as small as the fullest
## compartment needs (HEAP_MAX the largest, HEAP_MIN the smallest radius).
const CHIP := Vector2(118.0, 124.0)
const CHIP_GAP := 8.0
const HEAP_MAX := 9.0
const HEAP_MIN := 3.0
const NAME_SIZE := 34
const COUNT_SIZE := 28
## The count's size under a compartment of the two-row box.
const COUNT_SMALL := 22
const BAR_H := 20.0
## The still beads are cut into bands of this many rows.
const BAND := 4
## The pattern card's own seam between squares, in its pixels: a hairline.
const THUMB_GAP := 0.25
## The zoom (Hard and Insane): the button goes close enough for a peg to be
## PEG_NEAR px across, fingers may go on to PEG_MOST. The button is ZOOM_B
## across, ZOOM_INSET in from the tray floor's lower left corner (the thumb
## side stays clear), and when close the board may be pushed up by the
## button's height so the pegs under it can be reached.
const PEG_NEAR := 56.0
const PEG_MOST := 84.0
const ZOOM_B := 84.0
const ZOOM_INSET := 12.0

# --- the motion ---
## How long the held picture takes to grow over the board, and how much of
## the board it covers.
const PEEK_TIME := 0.18
const PEEK_COVER := 0.86
## A board past PEEK_BIG pegs a side holds its picture up as wide as the
## card allows, PEEK_EDGE in from its sides.
const PEEK_BIG := 16
const PEEK_EDGE := 10.0
## A bead is seated, not popped: it fades in held above its peg, falls onto
## it over the first SEAT_FALL of SEAT_TIME, and snaps down with a small
## press. Lifting runs the other way over LIFT_TIME.
const SEAT_TIME := 0.24
const SEAT_FALL := 0.62
const SEAT_HIGH := 0.34
const SEAT_NEAR := 0.16
const SEAT_PRESS := 0.06
const LIFT_TIME := 0.16
## A bead seated by a touch flies there from its compartment first, over
## FLY_TIME on an arc FLY_ARC of the way high, and hands over to the seat
## (held above the peg) as it arrives.
const FLY_TIME := 0.26
const FLY_ARC := 0.22
## A bead going home to its compartment (astray, or a reset) flies there on
## an arc over HOME_TIME, HOME_ARC of the way's length high.
const HOME_TIME := 0.5
const HOME_ARC := 0.35
## The tweezers glide to the chosen compartment over TWEEZ_TIME and dip
## TWEEZ_DIP px as they take hold.
const TWEEZ_TIME := 0.22
const TWEEZ_DIP := 8.0
## A plate's iron: it settles on over PLATE_LEAD, crosses the plate's
## diagonals PLATE_STEP each, and lingers PLATE_TAIL (a twirl, or a frown
## while the beads astray hop home). Steam every STEAM_EVERY.
const PLATE_LEAD := 0.22
const PLATE_STEP := 0.05
## However big the plate, its iron crosses it in no more than PLATE_SPAN
## (a 16 square board's 0.8 s), and the win's crosses the board in no more
## than IRON_SPAN (a 16 square board's 1.44 s): a step a diagonal was a
## minute's wait on a thousand beads.
const PLATE_SPAN := 0.8
const IRON_SPAN := 1.44
## A board past BIG pegs a side wins another way, because a thousand beads
## made again on every frame of the wave is a stutter: no bead hops, a bead
## is live only while the iron is on it (IRON_TIME_BIG, half the fuse), and
## the still beads are cut along the iron's diagonals (BAND_DIAG a band) in
## place of rows, so a frame makes again the band the iron enters and the
## one it leaves and no other.
const BIG := 16
const IRON_TIME_BIG := 0.15
const BAND_DIAG := 4
const PLATE_TAIL := 0.45
const STEAM_EVERY := 0.14
const IRON_SIZE := 1.9
## The win: the solve wave, then the iron crosses along the diagonal,
## IRON_STEP a diagonal, each bead fusing over IRON_TIME, and the bare pegs
## fade out over PEGS_GONE once it has passed.
const IRON_AT := 0.55
const IRON_STEP := 0.045
const IRON_TIME := 0.3
const PEGS_GONE := 0.5
## The win screen waits for the party: the cat is curled up by then.
const WIN_WAIT := 2.8
const HINTS := State.HINTS
## The toast: Knight's and Rings' measure for measure.
const TOAST_HOLD := 2.6
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 40.0

# --- hearts ---
const HEART_R := 15.0
const HEART_GAP := 8.0
const SPLIT_TIME := 0.7
const SPLIT_FALL := 40.0
const SPLIT_SPREAD := 10.0
const SPLIT_TURN := 0.7
const HEART_BACK_TIME := 0.3
const DUSK := Color(0.74, 0.76, 0.92)
const DUSK_TIME := 0.8
const CARD_AFTER := 0.9
const CARD_AFTER_STILL := 0.3
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
const MovesPill = preload("res://ui/flat/moves_pill.gd")
const MovesDiagram = preload("res://ui/hud/moves_tutorial_diagram.gd")
## The moves the out-of-moves card's video buys, once a picture.
const MOVES_BONUS := 5
## ...or this share of the budget when that is more: five moves buy nothing
## on a thousand beads.
const MOVES_BONUS_PART := 40
const PanZoom = preload("res://ui/flat/pan_zoom.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")

# --- the rewards ---
## Words that pop over the board: Perfect plate!, N in a row!, Steady hand!
## (a stroke seating STEADY beads), Whoosh! (WHOOSH).
const WORD_TIME := 1.2
const WORD_RISE := 46.0
const WORD_FONT := 48
const STEADY := 8
const WHOOSH := 14
const STEADY_GAP := 5.0
## How far a stroke's finger travels, in cells, before its row or column is
## chosen.
const AXIS_AFTER := 0.7
## The streak's tick, a semitone a plate ironed right in a row and no higher
## than five (the cozy rules; it was a note up [0, 2, 4, 7, 9, 12]).
const COMBO_STEPS := [0, 1, 2, 3, 4, 5]
## Hearts of love off a happy iron; a butterfly that lands on a plate.
const LOVE_HEARTS := 3
const LOVE_TIME := 1.2
const LOVE_RISE := 70.0
const FLY_IN := 0.8
const FLY_SIT := 2.6
const FLY_OUT := 0.8
## The happy iron's twirl before it goes.
const TWIRL_TIME := 0.4
const TWIRL_HOP := 14.0
## The party, after the win's iron: the nap cat hops onto the pattern card
## and curls up, the seal on the tray's corner, a line of bead wisdom.
const CHEERS := 10
const CAT_AT := 0.8
const CAT_POP := 0.22
const CAT_HOPS := 3
const CAT_HOP_TIME := 0.32
const CAT_HOP_H := 0.45
const CAT_SETTLE := 0.25
const CURL_AT := 2.5
const STAMP_AT := 1.5
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.16
const STAMP_TILT := -0.22

## What the phone does (docs/agents/haptics.md). A stroke is the move, and
## its beads click down a peg at a time under the finger with none of them
## felt (`place`, `lift`): it knocks once as it is let go (`_release`, by
## `fx.buzz`), a tap when it seated a bead, a tick when it only lifted some.
## A plate is judged as the iron has crossed it: a bump when it fuses
## (`plate`; the streak's confetti a tenth of a second later is the same
## bump), a warn where beads astray cost nothing (`_plate_done`: `astray`
## rings under the heart too), the heart where they cost one. A hint is a
## good unless it finishes the picture, which is the win (`hint`). The
## picture held, a chip picked, a fused or taken peg, a colour run out, the
## iron setting off, its steam, the words, the gags and the party say
## nothing; the seal knocks as it lands (`_party`).
const HAPTICS := {
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
	"plate": Haptics.BUMP,
	"check_ok": Haptics.GOOD,
	"heart_back": Haptics.GOOD,
	"check": Haptics.WARN,
	"heart_lost": Haptics.BAD,
	"out_of_hearts": Haptics.LOSE,
	"solved": Haptics.WIN,
}

var _state = State.new()
var fx: Node2D
## The chosen colour: an index into the day's colours.
var brush := 0

## Per peg: when its bead arrived, when a refusal shook it, when anything on
## it stops moving, and when a plate's iron passed it (AGO: never).
var _arrive_at := PackedFloat64Array()
var _drop := PackedByteArray()
var _shake_at := PackedFloat64Array()
var _until := PackedFloat64Array()
var _fuse_at := PackedFloat64Array()
## Beads the state has already forgotten, rising off: {peg, colour, at}.
var _leaving: Array = []
## Beads going home to the box: {from, to, colour, at, sits} -- until `at`
## the bead still sits on its peg (shivering when `sits` says so).
var _flying: Array = []
## Beads flying from the box to a peg: {from, peg, colour, at}.
var _incoming: Array = []
## The radius a bead in the box is drawn at, set by the layout.
var _heap_r := 6.0
## Pegs Check pointed at: their halos hold until the next move.
var _halo := {}
var _halo_at := -100.0
var _moving := {}
var _rings: Array = []
## A compartment's moments: when it was chosen, when a refusal shook it.
var _chip_at := PackedFloat64Array()
var _chip_shake := PackedFloat64Array()
var _chip_rects: Array[Rect2] = []
var _box := Rect2()
var _bar_bump := -100.0
## The tweezers: the compartment they left, and when.
var _tweez_from := 0
var _tweez_at := -100.0

var _opened := 0.0
var _anim_until := 0.0
var _solved_at := -1.0
var _won := false
var _cell := 0.0
var _grid := Vector2.ZERO
var _board := Rect2()
var _thumb := Rect2()
var _head_top := 0.0
var _right := Rect2()
var _table: ArrayMesh
var _thumb_mesh: ArrayMesh
## A big picture held up: its squares drawn apart, so they can be counted
## (on the little card they are drawn whole, or the gaps shimmer).
var _peek_mesh: ArrayMesh
## The zoom and what it moves. `_ground` draws the table and the tray and
## `_field` the plates, pegs and beads under `zoom.xf()`, clipped to the
## tray's floor; both stand behind this Control's own drawing. `_plates` is
## the field's floor, `_mask` the tray's round inner corners drawn back over
## a zoomed field (its clip is a plain rectangle).
var zoom := PanZoom.new()
var _ground: Control
var _field: Control
var _zoom_b: Button
var _zoom_icon := ""
var _plates: ArrayMesh
var _mask: ArrayMesh
var _field_shown: Array = []
var _ground_shown: Array = []
## Set by `_refresh`: the bands are looked over again on the next draw. A
## draw for a pan, a toast or a chip leaves them be.
var _stale := true
## The head's height and how the compartments stand, set by the layout.
var _head := HEAD
var _chip_rows := 1
var _heap_most := 0
## What the stroke in hand has done, for a second finger that cancels it:
## [[peg, the bead it held before, the moves it cost], ...], and whether the
## stroke spent the last move.
var _stroke_log: Array = []
var _stroke_ended := false
var _stroke_at := -100.0
var _lost_before := false
## The peg last pressed, as laid out: where the button zooms to.
var _focus := Vector2.INF
var _bands: Array = []
var _band_looks: Array = []
## The pegs of each band: rows of BAND, or (the win of a big board)
## diagonals of BAND_DIAG. `_win_diag` is the next diagonal the win's iron
## has yet to reach.
var _band_sets: Array = []
var _band_key := -1
var _by_diag := false
var _win_diag := 0
var _live: ArrayMesh
## The checkup's copies (puzzles/pixel_garden_looks.gd): the beads' kit made
## at `_kit_cell` and drawn scaled, the pegs' and the box's, the bare and the
## covered pegs, the beads moving and the marks over them (halos, a hint's
## dots), and the head in four layers -- under the heaps, the heaps, over
## them, and what moves on top -- each made again only when it changes.
var _kit
var _kit_cell := 0.0
var _peg_kit
var _heap_kit
var _heap_runs: Array = []
var _pegs_under: ArrayMesh
var _pegs_bare: ArrayMesh
var _live_beads: ArrayMesh
var _leaving_mesh: ArrayMesh
var _marks: ArrayMesh
var _head_under: ArrayMesh
var _head_over: ArrayMesh
var _head_lid: ArrayMesh
var _head_pick: ArrayMesh
var _heaps: ArrayMesh
var _box_key := ""
var _heaps_key := ""
var _top_key := ""
var _shown: Array = []
## Bumped by every deal, Try again and restore: a delayed callback from
## before it does nothing.
var _gen := 0

# --- the irons ---
## One a plate full: {q, at (it settles on), ok, end}. They run one after
## another; input waits until _busy_until.
var _irons: Array = []
var _busy_until := -100.0
var _last_steam := -100.0

# --- hearts ---
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
## Insane's move counter (ui/flat/moves_pill.gd): `max_moves` is 0 on a
## band that does not count. Out of moves unsolved is `out_of_hearts`, the
## name the host and the card already know.
var moves_left := 0
var max_moves := 0
var _moves_pill := MovesPill.new()
var _lost_ever := false
var _flawless := false
var _asleep := false
var _split_index := -1
var _split_at := -100.0
var _back_index := -1
var _back_at := -100.0
var _heart_card: Control
var _dusk_tw: Tween

# --- the rewards ---
var _words: Array = []
var _streak := 0
var _steady_at := -100.0
var _love: Array = []
var _flies: Array = []
var _plates_right := 0
var _party_at := -100.0
var _cat: Control
var _cat_at := INF
var _cat_curled := false
var _stamp_at := INF
var _seal_mesh: ArrayMesh
var _love_mesh: ArrayMesh

# --- the gesture ---
var _stroking := false
var _erase := false
var _refused := false
var _last := -1
## The stroke's first peg and where the finger pressed, and the line it keeps
## to once it has moved AXIS_AFTER of a cell: 0 none yet, 1 its row, 2 its
## column. A fingertip is wider than a peg, so a run must not wander.
var _start := -1
var _start_at := Vector2.ZERO
var _line := 0
var _painted := {}
var _seated_in_stroke := 0
var _peek := false
var _peek_at := -100.0
var _press_finger := -2
var _toast := ""
var _toast_arg := ""
var _toast_at := -100.0
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""

func puzzle_id() -> String: return "pixelgarden"
func title() -> String: return "Pixel Garden"

## A band that counts moves has no Check and no iron on a plate, so it reads
## neither of those lines.
func rules() -> String:
	var out := tr("PG_RULES")
	if "check" in capabilities():
		out += " " + tr("PG_RULES_CHECK")
	if max_moves <= 0:
		out += "\n\n" + tr("PG_RULES_PLATES")
	if max_hearts > 0:
		out += "\n\n" + tr("PG_RULES_HEARTS")
	if _zoomable():
		out += "\n\n" + tr("PG_RULES_ZOOM")
	if max_moves > 0:
		out += "\n\n" + tr("RULES_MOVES") % max_moves
	return out

## The tutorial, one lesson a page (the board checkup, 2026-10-03): pick
## and seat, the kit running out, the plates and the iron (not on a band
## that counts moves, where no plate is ironed), the picture held big, the
## zoom (Hard and Insane), Check, Undo and Reset (bands that have them), the
## bulb (bands with hints) and the move counter (Insane). Each page is the
## board itself on a hand-made 6x6 tulip, playing the lesson
## (ui/hud/pixel_garden_tutorial_diagram.gd).
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/pixel_garden_tutorial_diagram.gd")
	var band: int = _state.band
	var hints: int = State.hints_for(band)
	var hearts_n: int = State.hearts_for(band)
	var steps := [[Diagram.Lesson.SEAT, "HTP_PG_SEAT", tr("HTP_PG_SEAT_BODY")],
		[Diagram.Lesson.KIT, "HTP_PG_KIT", tr("HTP_PG_KIT_BODY")]]
	if hearts_n > 0:
		steps.append([Diagram.Lesson.PLATE, "HTP_PG_PLATE", tr("HTP_PG_PLATE_BODY_HEARTS") % hearts_n])
	elif max_moves <= 0:
		steps.append([Diagram.Lesson.PLATE, "HTP_PG_PLATE", tr("HTP_PG_PLATE_BODY")])
	steps.append([Diagram.Lesson.PEEK, "HTP_PG_PEEK", tr("HTP_PG_PEEK_BODY")])
	if _zoomable():
		steps.append([Diagram.Lesson.ZOOM, "HTP_PG_ZOOM", tr("HTP_PG_ZOOM_BODY")])
	if "check" in capabilities():
		steps.append([Diagram.Lesson.CHECK, "HTP_PG_CHECK", tr("HTP_PG_CHECK_BODY")])
	if "undo" in capabilities():
		steps.append([Diagram.Lesson.UNDO, "HTP_WT_UNDO", tr("HTP_PG_UNDO_BODY")])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_PG_HINT_BODY_ONE") if hints == 1 else tr("HTP_PG_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	if max_moves > 0:
		pages.append(MovesDiagram.page(self, max_moves))
	return pages

## Easy, Medium and Hard keep Undo, Check and their hints. Insane has Undo
## alone: no hint and no Check, which would each say what is wrong (it had
## no Undo either while it counted its moves, until 2026-10-12).
## Insane has the bulb again since 2026-10-13, as many hints as Hard: what is
## said of it above is the history (docs/agents/flat-screens.md).
func capabilities() -> Array[String]:
	match _state.band:
		3: return ["undo", "hint"]
	return ["undo", "hint", "check"]

## Hard and Insane: a board too big to play whole, so it zooms.
func _zoomable() -> bool:
	return _state.band >= 2

## What the zoom button goes to and the most fingers may reach, as scales of
## the board laid out.
func _zoom_limits() -> Vector2:
	return Vector2(maxf(1.0, PEG_NEAR / _cell), maxf(1.0, PEG_MOST / _cell))

## The zoom answers while the board is in play -- and, for the moment
## between a stroke spending the last move and the card coming, to the
## second finger that takes that stroke back.
func _zoom_live() -> bool:
	return zoom.enabled and _zoomable() and not _won and not is_done() \
		and (not out_of_hearts or (_stroke_ended and not _asleep))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for item: Control in [Control.new(), Control.new()]:
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.show_behind_parent = true
		add_child(item)
	_ground = get_child(0)
	_ground.name = "Ground"
	_ground.draw.connect(_draw_ground)
	_field = get_child(1)
	_field.name = "Field"
	_field.clip_contents = true
	_field.draw.connect(_draw_field)
	# The zoom's button: this Control's own child at its own size, in no
	# container. It clicks and knocks as every button does (ui/ui_sound.gd).
	_zoom_b = IconButton.new("plus", "", "IconButton")
	_zoom_b.name = "Zoom"
	_zoom_icon = "plus"
	_zoom_b.visible = false
	_zoom_b.custom_minimum_size = Vector2(ZOOM_B, ZOOM_B)
	var up := CozyTheme.soft_button(Pal.SURFACE, int(ZOOM_B * 0.5), false, 0)
	var down := CozyTheme.soft_button(Pal.SURFACE, int(ZOOM_B * 0.5), true, 0)
	for st in ["normal", "hover", "disabled"]:
		_zoom_b.add_theme_stylebox_override(st, up)
	_zoom_b.add_theme_stylebox_override("pressed", down)
	_zoom_b.pressed.connect(_on_zoom_button)
	add_child(_zoom_b)
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	fx.haptics = HAPTICS
	add_child(fx)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_state.setup(rng, difficulty, bank_step)
	_gen += 1
	max_hearts = State.hearts_for(difficulty)
	hearts = max_hearts
	max_moves = _state.moves_budget()
	moves_left = max_moves
	out_of_hearts = false
	_heart_used = false
	_lost_ever = false
	_flawless = false
	_asleep = false
	_split_index = -1
	_back_index = -1
	modulate = Color.WHITE
	_close_card()
	_reset_looks()
	_solved_at = -1.0
	_won = false
	_toast = ""
	_toast_at = -100.0
	# The colour the picture uses most of is in hand to begin with.
	brush = 0
	for k in _state.need.size():
		if _state.need[k] > _state.need[brush]:
			brush = k
	_tweez_from = brush
	_opened = _now()
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP)
	zoom.reset()
	_focus = Vector2.INF
	_layout()
	fx.cue("enter")
	var tip := "PG_ZOOM_TIP" if _zoomable() else ("PG_HARD_TIP" if max_hearts > 0 else "")
	if tip != "":
		_after(0.6, func() -> void:
			if not is_done():
				_tell(tip))

## Every per-peg and per-moment look back to rest, for a deal, Try again and
## a restore.
func _reset_looks() -> void:
	var n: int = _state.size()
	for a in [_arrive_at, _shake_at, _until]:
		a.resize(n)
		a.fill(-100.0)
	_fuse_at.resize(n)
	_fuse_at.fill(-INF)
	for c in n:
		if _state.locked[c] == State.FUSED:
			_fuse_at[c] = -1000.0
	_drop.resize(n)
	_drop.fill(0)
	_chip_at.resize(_state.names.size())
	_chip_at.fill(-100.0)
	_chip_shake.resize(_state.names.size())
	_chip_shake.fill(-100.0)
	_leaving = []
	_flying = []
	_incoming = []
	_halo = {}
	_moving = {}
	_rings = []
	_irons = []
	_busy_until = -100.0
	_words = []
	_love = []
	_flies = []
	_streak = 0
	_plates_right = 0
	_party_at = -100.0
	_cat_at = INF
	_stamp_at = INF
	_seal_mesh = null
	if is_instance_valid(_cat):
		_cat.queue_free()
	_cat = null
	_cat_curled = false
	_bands = []
	_by_diag = false
	_win_diag = 0
	_table = null
	_thumb_mesh = null
	_peek_mesh = null
	_kit = null
	_heap_kit = null
	_drop_layout_meshes()
	_clear_gesture()
	_stroke_log = []
	_stroke_ended = false

# --- layout ---

func _span() -> float:
	return float(_state.n) + 2.0 * MARGIN + GAP

## The head's height: taller on a day whose compartments stand in two rows.
func _head_for() -> float:
	return HEAD_BIG if _state.names.size() > ROW_MOST else HEAD

func _cell_for(available: float) -> float:
	if _state.n == 0:
		return 0.0
	var span := _span()
	return maxf(0.0, minf((size.x - 2.0 * PAD - 2.0 * RIM) / span,
		(available - 2.0 * PAD - _head_for() - HEAD_GAP - 2.0 * RIM) / span))

func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * _span() + 2.0 * RIM + 2.0 * PAD + _head_for() + HEAD_GAP)

func card_centred() -> bool:
	return true

func _layout() -> void:
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	_head = _head_for()
	var face := _cell * _span()
	var tall := minf(size.y, face + 2.0 * RIM + 2.0 * PAD + _head + HEAD_GAP)
	var top := (size.y - tall) * 0.5 + PAD
	_head_top = top
	var span := maxf(face + 2.0 * RIM, minf(size.x - 2.0 * PAD, 940.0))
	var left := size.x * 0.5 - span * 0.5
	_thumb = Rect2(left, top, _head, _head)
	_right = Rect2(left + _head + 26.0, top, span - _head - 26.0, _head)
	var board_top := top + _head + HEAD_GAP
	_board = Rect2(size.x * 0.5 - face * 0.5 - RIM, board_top, face + 2.0 * RIM, face + 2.0 * RIM)
	_grid = _board.position + Vector2.ONE * (RIM + MARGIN * _cell)
	_place_chips()
	_place_view()
	_table = null
	_bands = []
	_love_mesh = null
	_drop_layout_meshes()
	_refresh()

## The zoom's room (the tray's floor), its limits, and its button, from the
## board as just laid out. A zoom in hand is kept and clamped.
func _place_view() -> void:
	var view := _board.grow(-RIM)
	var lim := _zoom_limits() if _zoomable() and _cell > 0.0 else Vector2.ONE
	# Close, the board may be pushed up clear of the button over its corner.
	zoom.slack_hi = Vector2(0.0, ZOOM_B + 1.5 * ZOOM_INSET)
	zoom.setup(view, lim.x, lim.y)
	if _ground == null:
		return
	_ground.position = Vector2.ZERO
	_ground.size = size
	_zoom_b.size = Vector2(ZOOM_B, ZOOM_B)
	_zoom_b.position = Vector2(view.position.x + ZOOM_INSET, view.end.y - ZOOM_INSET - ZOOM_B)
	_sync_zoom()

## The button shows only while the zoom answers, and reads plus when the
## board is whole, minus when close -- whether it or two fingers did it.
func _sync_zoom() -> void:
	if _zoom_b == null:
		return
	# (a picture small enough that the button would go nowhere has none)
	var on := _zoom_live() and zoom.k_near > 1.001 and not _peek \
		and _now() - _opened >= Motion.ENTER_DELAY + Motion.ENTER_POP
	if _zoom_b.visible != on:
		_zoom_b.visible = on
	var icon := "plus" if zoom.next_in() else "minus"
	if icon != _zoom_icon:
		_zoom_icon = icon
		(_zoom_b as IconButton).set_icon(icon)

## The button: a step closer on the peg last touched (the middle before
## any), whole, half way, close, and back out the same way.
func _on_zoom_button() -> void:
	if not _zoom_live():
		return
	zoom.cycle(Vector2.INF if _focus == Vector2.INF else zoom.to_screen(_focus))
	_view_moved()

## Back to the whole board, gliding: the win, Reset, Try again.
func _zoom_whole() -> void:
	if zoom.zoomed():
		zoom.toggle()
		_view_moved()

## The view moved and nothing else did: the field under its new transform,
## and what this Control draws over it at pegs' places.
func _view_moved() -> void:
	if _field != null:
		_field.queue_redraw()
	queue_redraw()

## Everything laid out at the old size. The bead kit is kept unless the cell
## grew past it (drawn scaled, a relayout makes no bead again); the box's
## kit is made again only if its beads changed size.
func _drop_layout_meshes() -> void:
	_pegs_under = null
	_pegs_bare = null
	_head_under = null
	_head_pick = null
	_head_over = null
	_head_lid = null
	_heaps = null
	_heap_runs = []
	_box_key = ""
	_heaps_key = ""
	_top_key = ""
	_band_looks = []
	_plates = null
	_mask = null

## A few more copies' indices a frame, once the entrance is over, until the
## beads' kit holds the whole board and the box's every bead.
func _prime() -> void:
	if _kit == null or _heap_kit == null or _now() - _opened < Motion.ENTER_DELAY + Motion.ENTER_POP:
		return
	if _kit.count == 0:
		_kit.look(Looks.bead_id(0, 0.0, 0.0, 1.0, 1.0, true))
	if _kit.tiled_count() < _state.size():
		_kit.grow(PRIME_STEP)
		return
	var all := 0
	for i in _state.need.size():
		all += _heap_full(i)
	if _heap_kit.count == 0:
		_heap_kit.look(0)
	if _heap_kit.tiled_count() < all:
		_heap_kit.grow(PRIME_STEP * 4)

## The kits for this picture and cell.
func _ensure_kits() -> void:
	if _kit == null or _cell > _kit_cell * 1.001:
		_kit = Looks.bead_kit(_cell, _state.colours)
		_kit_cell = _cell
		_band_looks = []
		_bands = []
	if _peg_kit == null or not is_equal_approx(_peg_kit_cell, _cell):
		_peg_kit = Looks.peg_kit(_cell)
		_peg_kit_cell = _cell
	if _heap_kit == null or not is_equal_approx(_heap_kit_r, _heap_r):
		_heap_kit = Looks.heap_kit(_heap_r, _state.colours)
		_heap_kit_r = _heap_r
		_heap_runs = []

var _peg_kit_cell := 0.0
## How many copies a frame the kits' tiled indices grow by after the
## entrance, so the win (every bead live at once) finds them made.
const PRIME_STEP := 12
var _live_dirty := true
var _heap_kit_r := 0.0

## The compartments stand in a row under the picture's name, centred in the
## room beside the picture, closing up when a day has many colours; past
## ROW_MOST colours they stand in two rows, between the name's line and the
## bar's.
func _place_chips() -> void:
	_chip_rects = []
	var k: int = _state.names.size()
	if k == 0:
		return
	_chip_rows = 2 if k > ROW_MOST else 1
	var per := int(ceil(float(k) / float(_chip_rows)))
	var room := _right.size.x - 12.0
	var gap := minf(CHIP_GAP, maxf(2.0, (room - CHIP.x * per) / maxf(1.0, per - 1)))
	var tall := CHIP.y
	if _chip_rows > 1:
		tall = (_right.size.y - 50.0 - BAR_H - 18.0 - CHIP_GAP) / float(_chip_rows)
	var chip := Vector2(minf(CHIP.x, (room - gap * (per - 1)) / per), tall)
	var run := chip.x * per + gap * (per - 1)
	var x0 := _right.position.x + (_right.size.x - run) * 0.5
	var y := _right.position.y + 50.0
	for i in k:
		_chip_rects.append(Rect2(Vector2(x0 + (i % per) * (chip.x + gap), y + (i / per) * (chip.y + CHIP_GAP)), chip))
	_box = Rect2(Vector2(x0, y), Vector2(run, chip.y * _chip_rows + CHIP_GAP * (_chip_rows - 1))).grow(6.0)
	var most := 1
	for v in _state.need:
		most = maxi(most, v)
	_heap_r = HEAP_MIN
	var r := HEAP_MAX
	while r >= HEAP_MIN:
		if _heap_room(_well(_chip_rects[0]), r) >= most:
			_heap_r = r
			break
		r -= 0.25
	_heap_most = maxi(1, _heap_room(_well(_chip_rects[0]), _heap_r))

## How many beads compartment `i` shows when full, and how many now. A
## colour with more beads than a compartment holds at the smallest size (a
## sky of three hundred) is drawn to scale: full when none is seated, down
## to one bead while any is left.
func _heap_full(i: int) -> int:
	return mini(maxi(0, _state.need[i]), _heap_most)

func _heap_shown(i: int) -> int:
	var left: int = maxi(0, _state.left(i))
	var need: int = _state.need[i]
	if need <= _heap_most or left == 0:
		return left
	return clampi(int(ceil(float(left) * _heap_most / float(need))), 1, _heap_most)

## The floor of a compartment, where its beads lie.
func _well(r: Rect2) -> Rect2:
	return Rect2(r.position, Vector2(r.size.x, r.size.y * 0.74))

## How many beads of radius `r` lie in `well`: rows from the floor up, every
## other one shifted half a bead, under the clear lip.
func _heap_room(well: Rect2, r: float) -> int:
	var cols := int(floor((well.size.x - 6.0) / (2.0 * r)))
	var rows := int(floor((well.size.y - 14.0 - 6.0 - 2.0 * r) / (1.7 * r))) + 1
	return maxi(0, cols * rows - rows / 2)

## Where bead `k` (from 0, the floor's middle first) of compartment `i` lies.
func _slot(i: int, k: int) -> Vector2:
	if i >= _chip_rects.size():
		return _thumb.get_center()
	var well := _well(_chip_rects[i])
	var r := _heap_r
	var cols := int(floor((well.size.x - 6.0) / (2.0 * r)))
	var k2 := maxi(0, k)
	var row := 0
	while true:
		var m := cols - (row % 2)
		if k2 < m:
			break
		k2 -= m
		row += 1
	var m := cols - (row % 2)
	# The middle of the row fills first, then out to either side.
	var off := (k2 + 1) / 2 * (1 if k2 % 2 == 1 else -1)
	if m % 2 == 0:
		off = k2 / 2 if k2 % 2 == 0 else -(k2 / 2 + 1)
	var x := well.get_center().x + float(off) * 2.0 * r + (0.0 if m % 2 == 1 else r)
	x += (_h01(i * 97 + k, 3) - 0.5) * r * 0.25
	var y := well.end.y - 14.0 - r - row * 1.7 * r - _h01(i * 97 + k, 4) * r * 0.2
	return Vector2(x, y)

## A peg's place on the board: its row and column, the seam between plates
## taken into account.
func _centre(c: int) -> Vector2:
	var n: int = _state.n
	var x := float(c % n) + (GAP if c % n >= _state.half else 0.0)
	var y := float(c / n) + (GAP if c / n >= _state.half else 0.0)
	return _grid + (Vector2(x, y) + Vector2(0.5, 0.5)) * _cell

## Control-local point over the centre of the peg at (row, column), the name
## every flat board gives it and the one a harness taps: where the peg shows,
## zoomed as the board is.
func cell_to_local(r: int, c: int) -> Vector2:
	return zoom.to_screen(_centre(r * _state.n + c))

func _axis(v: float) -> int:
	var h := float(_state.half)
	if v >= h + GAP * 0.5:
		v = maxf(v - GAP, h)
	elif v >= h:
		v = h - 0.01
	return int(floor(v))

func _peg_at(local: Vector2) -> int:
	if _cell <= 0.0:
		return -1
	var v := (local - _grid) / _cell
	var x := _axis(v.x)
	var y := _axis(v.y)
	if v.x < 0.0 or v.y < 0.0 or x >= _state.n or y >= _state.n:
		return -1
	return y * _state.n + x

## A plate's face on the board, from its first peg's corner to its last's.
func _plate_rect(q: int) -> Rect2:
	var pegs: PackedInt32Array = _state.plate_pegs(q)
	var a := _centre(pegs[0]) - Vector2.ONE * _cell * 0.5
	var z := _centre(pegs[pegs.size() - 1]) + Vector2.ONE * _cell * 0.5
	return Rect2(a, z - a)

## The local centre of chip `i`, which the win harness taps.
func chip_to_local(i: int) -> Vector2:
	return _chip_rects[i].get_center() if i < _chip_rects.size() else Vector2.ZERO

func _chip_at_point(local: Vector2) -> int:
	for i in _chip_rects.size():
		if _chip_rects[i].grow(4.0).has_point(local):
			return i
	return -1

## Where a bead going home lands: on top of its compartment's beads.
func _home(k: int) -> Vector2:
	return _slot(k, maxi(0, _heap_shown(k) - 1))

# --- frames ---

func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0 or _state.n == 0:
		return
	var t := _now()
	var settled := false
	for c: int in _moving.keys():
		if float(_until[c]) <= t:
			_moving.erase(c)
			settled = true
	_steam(t)
	_prime()
	_win_front(t)
	if is_instance_valid(_cat) or t >= _cat_at:
		_place_cat(t)
	var gliding: bool = zoom.step(delta) or zoom.busy()
	_sync_zoom()
	if settled or t < _anim_until:
		_refresh()
	elif gliding:
		_view_moved()
	elif _toast != "" and t - _toast_at < TOAST_HOLD + 0.1:
		queue_redraw()

## The win of a big board: each diagonal's beads go live as the iron reaches
## them and rest again, fused, once it has passed.
func _win_front(t: float) -> void:
	if not (_won and _by_diag):
		return
	var n: int = _state.n
	var step := _iron_step()
	while _win_diag <= 2 * n - 2:
		var at := _solved_at + IRON_AT + _win_diag * step
		if t < at:
			break
		for x in range(maxi(0, _win_diag - (n - 1)), mini(_win_diag, n - 1) + 1):
			var c := (_win_diag - x) * n + x
			if _state.beads[c] != State.EMPTY:
				_touch(c, at + _iron_time())
		_win_diag += 1

func _big() -> bool:
	return _state.n > BIG

func _iron_time() -> float:
	return IRON_TIME_BIG if _big() else IRON_TIME

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds + 0.05)

func _touch(c: int, until: float) -> void:
	_until[c] = maxf(_until[c], until)
	_moving[c] = true
	_busy_for(until - _now())

func _refresh() -> void:
	_live_dirty = true
	_stale = true
	queue_redraw()
	if _field != null:
		_field.queue_redraw()
		_ground.queue_redraw()

## Runs `what` after `delay`, unless the board has been dealt again.
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

## The HUD's actions wait while an iron is at work, after the last heart,
## and once won. Strokes only wait on the plate under the iron (_plate_busy):
## the rest of the board stays live, so a quick player is never held up.
func _blocked() -> bool:
	return is_done() or out_of_hearts or _now() < _busy_until

func _plate_busy(q: int) -> bool:
	var t := _now()
	for ir: Dictionary in _irons:
		if int(ir.q) == q and t < float(ir.end):
			return true
	return false

# --- the drawing ---

## The entrance's pop as [its transform, how much is seen, its scale].
func _pop(t: float) -> Array:
	var since := t - _opened - Motion.ENTER_DELAY
	var grow := Motion.wide_pop_scale(since)
	return [Transform2D(0.0, Vector2.ONE * grow, 0.0, size * 0.5 * (1.0 - grow)),
		Motion.appear_level(since, Motion.ENTER_POP), grow]

## The field stands on the tray's floor under the entrance's pop, so its clip
## pops with the tray.
func _pose_field(xf: Transform2D, grow: float) -> void:
	var at: Vector2 = xf * zoom.view.position
	if not _field.position.is_equal_approx(at):
		_field.position = at
	if not _field.size.is_equal_approx(zoom.view.size):
		_field.size = zoom.view.size
	if not _field.scale.is_equal_approx(Vector2.ONE * grow):
		_field.scale = Vector2.ONE * grow

## Every mesh the three drawings share, made again where it is stale. The
## first of them to draw in a frame does the work.
func _prepare(t: float) -> void:
	_ensure_kits()
	if _table == null:
		_build_table()
	if _pegs_under == null:
		_build_pegs()
	if _stale or _bands.is_empty():
		_stale = false
		_update_bands(t)
	if _live_dirty:
		_live_dirty = false
		_build_live(t)

## The table and the tray, behind everything.
func _draw_ground() -> void:
	var shown: Array = []
	if _state.n > 0 and _cell > 0.0:
		var t := _now()
		var pop := _pop(t)
		if float(pop[1]) > 0.0:
			_prepare(t)
			_ground.draw_mesh(_table, null, pop[0], Color(1.0, 1.0, 1.0, pop[1]))
			shown.append(_table)
	_ground_shown = shown

## The plates, the pegs, every bead and the marks over them, under the zoom
## and clipped to the tray's floor. Close, what flies about the board (the
## irons, the love, the butterfly, a hint's ring) is clipped with them;
## whole, `_draw` lays it over the tray's rim as it always did.
func _draw_field() -> void:
	var shown: Array = []
	if _state.n > 0 and _cell > 0.0:
		var t := _now()
		var pop := _pop(t)
		var seen: float = pop[1]
		if seen > 0.0:
			_pose_field(pop[0], pop[2])
			_prepare(t)
			var xf: Transform2D = Transform2D(0.0, -zoom.view.position) * zoom.xf()
			# The bare pegs fade once the win's iron has passed: the mesh's
			# alpha, not a rebuild.
			var layers: Array = [_plates, _pegs_under, _pegs_bare]
			layers.append_array(_bands)
			layers.append_array([_leaving_mesh, _live_beads, _marks])
			if zoom.zoomed():
				layers.append(_live)
			for m in layers:
				if m == null:
					continue
				var a := seen * (1.0 - _pegs_gone(t) if m == _pegs_bare else 1.0)
				if a > 0.0:
					_field.draw_mesh(m, null, xf, Color(1.0, 1.0, 1.0, a))
					shown.append(m)
	_field_shown = shown

func _draw() -> void:
	if _state.n == 0 or _cell <= 0.0:
		return
	var t := _now()
	var pop := _pop(t)
	var xf: Transform2D = pop[0]
	var seen: float = pop[1]
	_pose_field(xf, pop[2])
	if seen <= 0.0:
		return
	var tint := Color(1.0, 1.0, 1.0, seen)
	var shown: Array = []
	_prepare(t)
	# Over the field: whole, what flies about the board; close, the tray's
	# round corners back over the field's square clip.
	var over: ArrayMesh = _mask if zoom.zoomed() else _live
	if over != null:
		draw_mesh(over, null, xf, tint)
		shown.append(over)
	_update_head(t)
	for m in [_head_under, _head_pick, _heaps, _head_over, _head_lid]:
		if m != null:
			draw_mesh(m, null, xf, tint)
			shown.append(m)
	_draw_head_text(t, xf, seen)
	# Beads in the air between the box and the board, over both.
	if not (_flying.is_empty() and _incoming.is_empty()):
		var air := Face.Builder.new()
		_draw_flying(air, t)
		_draw_incoming(air, t)
		if not air.verts.is_empty():
			var m := air.mesh()
			draw_mesh(m, null, xf, tint)
			shown.append(m)
	if t >= _stamp_at:
		_draw_stamp(t, shown)
	_draw_words(t)
	_draw_peek(t, shown)
	_draw_toast(t, shown)
	draw_set_transform(Vector2.ZERO)
	_shown = shown

## The card's table and the wooden tray with the seam's floor (`_table`, the
## ground's), the four plates with their clips (`_plates`, the field's), and
## the tray's round inner corners (`_mask`).
func _build_table() -> void:
	var b := Face.Builder.new()
	var clip := Face.Builder.round_rect(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0, CARD_RADIUS - 2.0)
	Rings._clip_polygon(b, clip, Pal.PG_TABLE.lerp(Pal.PARCHMENT, 0.5), clip)
	# A few soft leaf shadows over the table, the way light falls through
	# the garden onto it.
	var seed_i: int = _state.n * 31 + _state.target
	for d in 5:
		var at := Vector2(size.x * _h01(seed_i, d + 10), size.y * _h01(seed_i, d + 20))
		Scenery.soft_disc(b, at, 140.0, 90.0, Color(Pal.LAWN_DEEP, 0.07))
	var r := _board
	Scenery.soft_disc(b, r.get_center() + Vector2(0.0, r.size.y * 0.5 + 6.0), r.size.x * 0.56, 30.0,
		Color(Pal.TEXT, 0.16))
	b.fan(Face.Builder.round_rect(r.position + Vector2(0.0, 6.0), r.size, BOARD_RADIUS + 6.0), Pal.PG_TRAY_DEEP)
	b.fan(Face.Builder.round_rect(r.position, r.size, BOARD_RADIUS + 6.0), Pal.PG_TRAY)
	b.fan(Face.Builder.round_rect(r.position + Vector2.ONE * 3.0, r.size - Vector2.ONE * 6.0, BOARD_RADIUS + 3.0),
		Pal.PG_TRAY_HI)
	var inner := r.grow(-RIM)
	b.fan(Face.Builder.round_rect(inner.position - Vector2.ONE * 2.0, inner.size + Vector2.ONE * 4.0, BOARD_RADIUS),
		Pal.PG_TRAY_DEEP)
	# The seam's floor: the hairline that shows between the four plates, and
	# what shows under a board pushed up clear of the zoom's button.
	b.fan(Face.Builder.round_rect(inner.position, inner.size, BOARD_RADIUS - 2.0), Pal.PG_BOARD_DEEP)
	_table = b.mesh()
	var p := Face.Builder.new()
	var m := MARGIN * _cell
	for q in 4:
		var pr := _plate_rect(q)
		# Each plate runs out to the tray on its outer sides and stops a
		# hairline short of its neighbour on its inner ones; its outer
		# corner is rounded like the tray's, the inner ones barely.
		var seam := maxf(0.0, GAP * _cell * 0.5 - 0.75)
		var a := pr.position - Vector2(m if q % 2 == 0 else seam, m if q < 2 else seam)
		var z := pr.end + Vector2(m if q % 2 == 1 else seam, m if q >= 2 else seam)
		var face := Rect2(a, z - a)
		var rad := BOARD_RADIUS - 4.0
		var radii := [2.0, 2.0, 2.0, 2.0]
		radii[q] = rad
		p.fan(_corners(face, radii), Pal.PG_BOARD_DEEP)
		p.fan(_corners(Rect2(face.position, face.size - Vector2(0.0, 2.0)), radii), Pal.PG_BOARD)
		# (Just inside the plate's top edge: the field is clipped there.)
		_clip(p, Vector2(pr.get_center().x, face.position.y + 1.0 + _cell * 0.08), _cell)
	_plates = p.mesh()
	# The tray's inner corners: what lies between the floor's round corner
	# and the square one the field is clipped to.
	var k := Face.Builder.new()
	var rr := BOARD_RADIUS - 2.0
	var spots := [[inner.position, Vector2(1, 1), PI, 1.5 * PI], [Vector2(inner.end.x, inner.position.y), Vector2(-1, 1), 1.5 * PI, TAU],
		[inner.end, Vector2(-1, -1), 0.0, 0.5 * PI], [Vector2(inner.position.x, inner.end.y), Vector2(1, -1), 0.5 * PI, PI]]
	for sp: Array in spots:
		var corner: Vector2 = sp[0]
		var centre: Vector2 = corner + (sp[1] as Vector2) * rr
		for ring: Array in [[rr, Pal.PG_TRAY_DEEP], [rr + 2.0, Pal.PG_TRAY_HI]]:
			var pts := PackedVector2Array([corner])
			for i in 9:
				var ang := lerpf(float(sp[2]), float(sp[3]), i / 8.0)
				var at := centre + Vector2(cos(ang), sin(ang)) * float(ring[0])
				pts.append(at.clamp(inner.position, inner.end))
			for i in range(1, pts.size() - 1):
				var v0 := k.vertex(pts[0], ring[1])
				var v1 := k.vertex(pts[i], ring[1])
				var v2 := k.vertex(pts[i + 1], ring[1])
				k.tri(v0, v1, v2)
	_mask = k.mesh()

## Every peg, as copies of one: the ones the picture covers, and the bare
## ones, which the win fades (under a bead the peg is hidden anyway).
func _build_pegs() -> void:
	var under := Looks.Copies.new()
	var bare := Looks.Copies.new()
	for c in _state.size():
		var into := bare if _state.want[c] == State.EMPTY else under
		into.add(_peg_kit, 0, Transform2D(0.0, _centre(c)))
	_pegs_under = under.mesh(_peg_kit)
	_pegs_bare = bare.mesh(_peg_kit)

## A rectangle with its own radius at each corner: top left, top right,
## bottom left, bottom right (plate q's outer corner is radii[q]).
static func _corners(r: Rect2, radii: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var spots := [[r.position, PI, 1.5 * PI, 0], [Vector2(r.end.x, r.position.y), 1.5 * PI, TAU, 1],
		[r.end, 0.0, 0.5 * PI, 3], [Vector2(r.position.x, r.end.y), 0.5 * PI, PI, 2]]
	for sp: Array in spots:
		var rad: float = minf(float(radii[int(sp[3])]), minf(r.size.x, r.size.y) * 0.5)
		var corner: Vector2 = sp[0]
		var inward := Vector2(rad if corner.x == r.position.x else -rad, rad if corner.y == r.position.y else -rad)
		var c := corner + inward
		for k in 6:
			var ang := lerpf(float(sp[1]), float(sp[2]), k / 5.0)
			pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	return pts

## A plate's clip: a little wooden tab on its top edge, `s` a cell.
func _clip(b: Face.Builder, at: Vector2, s: float) -> void:
	var w := s * 0.7
	var h := s * 0.16
	var ink: Color = Pal.PG_TRAY_HI
	b.polygon(Face.Builder.round_rect(at + Vector2(-w * 0.5, -h * 0.5 + h * 0.18), Vector2(w, h), h * 0.45), ink.darkened(0.25))
	b.polygon(Face.Builder.round_rect(at + Vector2(-w * 0.5, -h * 0.5), Vector2(w, h), h * 0.45), ink)

## The win's iron takes this long a diagonal, and a plate's this long: their
## own steps on a small board, less on a big one (IRON_SPAN, PLATE_SPAN).
func _iron_step() -> float:
	return minf(IRON_STEP, IRON_SPAN / maxf(1.0, 2.0 * _state.n))

func _plate_step() -> float:
	return minf(PLATE_STEP, PLATE_SPAN / maxf(1.0, 2.0 * _state.half))

func _pegs_gone(t: float) -> float:
	if not _won:
		return 0.0
	if Motion.reduce:
		return 1.0
	var start := _solved_at + IRON_AT + float(_state.n) * _iron_step()
	return clampf((t - start) / PEGS_GONE, 0.0, 1.0)

## The pegs of each band, cut again when the board or the way of cutting
## changes.
func _cut_bands() -> void:
	var n: int = _state.n
	var key := n * 2 + (1 if _by_diag else 0)
	if key == _band_key and not _band_sets.is_empty():
		return
	_band_key = key
	_band_sets = []
	if _by_diag:
		# (a packed array in an Array is a copy when taken out: fill each
		# band's own, then put it in)
		for k in int(ceil(float(2 * n - 1) / float(BAND_DIAG))):
			var pegs := PackedInt32Array()
			for d in range(k * BAND_DIAG, mini(2 * n - 1, (k + 1) * BAND_DIAG)):
				for x in range(maxi(0, d - (n - 1)), mini(d, n - 1) + 1):
					pegs.append((d - x) * n + x)
			_band_sets.append(pegs)
	else:
		for k in int(ceil(float(n) / float(BAND))):
			_band_sets.append(PackedInt32Array(range(k * BAND * n, mini(_state.size(), (k + 1) * BAND * n))))
	_bands = []
	_band_looks = []

func _update_bands(t: float) -> void:
	_cut_bands()
	var count := _band_sets.size()
	if _bands.size() != count or _band_looks.size() != count:
		_bands.resize(count)
		_bands.fill(null)
		_band_looks.resize(count)
		_band_looks.fill(PackedInt32Array())
	for k in count:
		var pegs: PackedInt32Array = _band_sets[k]
		var looks := PackedInt32Array()
		looks.resize(pegs.size())
		for i in pegs.size():
			looks[i] = -2 if _moving.has(pegs[i]) else _look(pegs[i], t)
		if _bands[k] != null and looks == _band_looks[k]:
			continue
		var cp := Looks.Copies.new()
		for c in pegs:
			if not _moving.has(c):
				_put_bead(cp, c, t)
		_bands[k] = cp.mesh(_kit)
		_band_looks[k] = looks

## Everything a resting bead's drawing depends on (its marks are drawn over
## it apart, _build_live).
func _look(c: int, t: float) -> int:
	var fused := 1 if _fused(c, t) >= 1.0 else 0
	return (_state.beads[c] + 1) | (fused << 9)

## The moving beads (copies), what else moves on the board (a Builder), and
## the marks over every bead -- Check's halos and a hint's sun dots.
func _build_live(t: float) -> void:
	_leaving_mesh = _build_leaving(t)
	var cp := Looks.Copies.new()
	for c: int in _moving:
		_put_bead(cp, c, t)
	_live_beads = cp.mesh(_kit)
	var marks := Face.Builder.new()
	for c in _state.size():
		if _state.locked[c] == State.HINTED or _halo.has(c):
			_mark(marks, c, t)
	_marks = marks.mesh() if not marks.verts.is_empty() else null
	_live = _build_air(t)

## Beads lifting off their pegs, under the moving ones (a hint's swap: the
## right bead drops in over the wrong one rising).
func _build_leaving(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var keep: Array = []
	for g: Dictionary in _leaving:
		var u: float = t - float(g.at)
		if u < LIFT_TIME and not Motion.reduce:
			keep.append(g)
		if u >= 0.0 and u < LIFT_TIME and not Motion.reduce:
			# Lifted off its peg: rising, nearer, fading.
			var k := u / LIFT_TIME
			var h := 1.0 - (1.0 - k) * (1.0 - k)
			Bead.bead(b, _centre(int(g.peg)), _cell, g.colour, Vector2.ONE * (1.0 + SEAT_NEAR * h),
				1.0 - k * k, _cell * SEAT_HIGH * h)
	_leaving = keep
	return b.mesh() if not b.verts.is_empty() else null

func _build_air(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	_draw_iron(b, t)
	for ir: Dictionary in _irons:
		_draw_plate_iron(b, ir, t)
	_draw_love(b, t)
	for f: Dictionary in _flies:
		_fly(b, f, t)
	var rings: Array = []
	for r: Dictionary in _rings:
		var u := (t - float(r.at)) / Motion.RING_TIME
		if u < 1.0:
			rings.append(r)
		if u >= 0.0 and u < 1.0:
			var rad := _cell * (0.5 + 0.5 * u)
			b.stroke(Face.Builder.ring(r.pos, rad, rad), _cell * 0.08 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)
	_rings = rings
	return b.mesh() if not b.verts.is_empty() else null

## One peg's bead: popping in (or dropping in, from a hint), shaking when a
## press is refused, hopping on the solve, fused by an iron. As [where, lift,
## grow, alpha], or empty while it is still in the air from the box
## (_draw_incoming draws it then) or there is no bead.
func _pose(c: int, t: float) -> Array:
	var k: int = _state.beads[c]
	if k == State.EMPTY:
		return []
	var at := _centre(c)
	at.x += Motion.shiver_offset(t - float(_shake_at[c]), _cell * 0.05)
	var since := t - float(_arrive_at[c])
	var grow := 1.0
	var lift := 0.0
	var alpha := 1.0
	if _drop[c] == 1:
		lift = Motion.drop_in_lift(since, _cell * 0.9)
		alpha = Motion.appear_level(since)
	elif since < SEAT_TIME and not Motion.reduce:
		if since < 0.0 and _drop[c] == 2:
			return []
		var seat := _seat(since)
		lift = seat.x
		grow = seat.y
		alpha = 1.0 if _drop[c] == 2 else seat.z
	lift += _hop(c, t)
	return [at, lift, grow, alpha]

## Bead `c` as it is now, a copy of its look: the shade left on the board,
## the bead lifted off it.
func _put_bead(cp, c: int, t: float) -> void:
	var p := _pose(c, t)
	if p.is_empty() or float(p[3]) <= 0.0:
		return
	var at: Vector2 = p[0]
	var lift: float = p[1]
	var id := Looks.bead_id(_state.beads[c], _fused(c, t), _shine(c, t), p[3],
		clampf(1.0 - lift / (_cell * 0.8), 0.3, 1.0), lift <= _cell * 0.05)
	var sc := Vector2.ONE * (float(p[2]) * _cell / _kit_cell)
	cp.add2(_kit, id, Transform2D(0.0, sc, 0.0, at), Transform2D(0.0, sc, 0.0, at - Vector2(0.0, lift)))

## A peg's marks: the sun dot of a hint (on a bare peg it cleared, or on its
## bead until an iron fuses it), and the rose halo Check points with.
func _mark(b: Face.Builder, c: int, t: float) -> void:
	var at := _centre(c)
	at.x += Motion.shiver_offset(t - float(_shake_at[c]), _cell * 0.05)
	if _state.beads[c] == State.EMPTY:
		if _state.locked[c] == State.HINTED:
			b.disc(at + Vector2(_cell * 0.24, _cell * 0.24), _cell * 0.06, Color(Pal.SUN, 0.8))
		return
	var p := _pose(c, t)
	if p.is_empty():
		return
	if _state.locked[c] == State.HINTED and _fused(c, t) <= 0.0:
		b.disc(at + Vector2(_cell * 0.3, _cell * 0.3), _cell * 0.07, Pal.SUN)
	if _halo.has(c):
		var ha := Motion.appear_level(t - _halo_at, 0.12)
		Bead.halo(b, at - Vector2(0.0, float(p[1])), _cell, ha)

## A seating bead `since` seconds in: its lift, its scale and its alpha.
func _seat(since: float) -> Vector3:
	var u := clampf(since / SEAT_TIME, 0.0, 1.0)
	if u < SEAT_FALL:
		var k := u / SEAT_FALL
		var h := 1.0 - k * k
		return Vector3(_cell * SEAT_HIGH * h, 1.0 + SEAT_NEAR * h, clampf(k * 3.0, 0.0, 1.0))
	var v := (u - SEAT_FALL) / (1.0 - SEAT_FALL)
	return Vector3(0.0, 1.0 - SEAT_PRESS * sin(v * PI), 1.0)

## Beads going home: sitting on their peg until their moment (shivering if
## the iron found them astray), then an arc up and over into their
## compartment, shrinking to a heap bead's size as they land.
func _draw_flying(b: Face.Builder, t: float) -> void:
	var keep: Array = []
	var zk: float = zoom.k
	for g: Dictionary in _flying:
		var u: float = (t - float(g.at)) / HOME_TIME
		if u >= 1.0 or Motion.reduce:
			continue
		keep.append(g)
		# Its peg is where the zoom shows it; one out of sight sets off from
		# the edge of the tray's floor.
		var from: Vector2 = zoom.to_screen(g.from)
		var seen: bool = zoom.view.has_point(from)
		if u < 0.0:
			if seen:
				if bool(g.sits):
					from.x += sin(t * 38.0) * _cell * zk * 0.03
				Bead.bead(b, from, _cell * zk, g.colour)
			continue
		if not seen:
			from = from.clamp(zoom.view.position, zoom.view.end)
		var to: Vector2 = g.to
		var e := u * u * (3.0 - 2.0 * u)
		var arc := (to - from).length() * HOME_ARC * 4.0 * u * (1.0 - u)
		var p := from.lerp(to, e) - Vector2(0.0, arc)
		var s := lerpf((1.0 + 0.25 * sin(u * PI)) * zk, _heap_r / (_cell * Bead.R), e)
		Bead.bead(b, p, _cell * s, g.colour, Vector2.ONE, 1.0, 0.0, 0.0, 0.0, Pal.PG_BOARD, false)
	_flying = keep

## Beads on their way from the box: lifted off the heap, over an arc, and
## growing from a box bead's size to a peg's, held SEAT_HIGH above the peg as
## they arrive -- where the seat takes them over and presses them home.
func _draw_incoming(b: Face.Builder, t: float) -> void:
	var keep: Array = []
	var zk: float = zoom.k
	for g: Dictionary in _incoming:
		var u: float = (t - float(g.at)) / FLY_TIME
		if u >= 1.0 or Motion.reduce or _state.beads[int(g.peg)] == State.EMPTY:
			continue
		keep.append(g)
		if u < 0.0:
			continue
		var from: Vector2 = g.from
		var to: Vector2 = zoom.to_screen(_centre(int(g.peg)) - Vector2(0.0, _cell * SEAT_HIGH))
		var e := 1.0 - (1.0 - u) * (1.0 - u)
		var arc := (to - from).length() * FLY_ARC * 4.0 * u * (1.0 - u)
		var p := from.lerp(to, e) - Vector2(0.0, arc)
		var sc := lerpf(_heap_r / (_cell * Bead.R), (1.0 + SEAT_NEAR) * zk, e)
		Bead.bead(b, p, _cell * sc, g.colour, Vector2.ONE, 1.0, 0.0, 0.0, 0.0, Pal.PG_BOARD, false)
	_incoming = keep

## The diagonal a peg stands on, from the top left.
func _diag(c: int) -> int:
	return c % _state.n + c / _state.n

func _hop(c: int, t: float) -> float:
	if not _won or Motion.reduce or _big():
		return 0.0
	var at := _solved_at + Motion.stagger(_diag(c), Motion.SOLVE_STAGGER * 0.5, 0.5)
	return -Motion.hop_lift(t - at, Motion.SOLVE_HOP * _cell / 90.0, Motion.SOLVE_TIME)

## How far bead `c` has fused: under its plate's iron, or the win's.
func _fused(c: int, t: float) -> float:
	var f := 0.0
	if _fuse_at[c] > -INF:
		f = 1.0 if Motion.reduce else clampf((t - _fuse_at[c]) / _iron_time(), 0.0, 1.0)
	if not _won:
		return f
	if Motion.reduce:
		return 1.0
	return maxf(f, clampf((t - _solved_at - IRON_AT - _diag(c) * _iron_step()) / _iron_time(), 0.0, 1.0))

## The glint as an iron passes a bead: a bell over IRON_TIME.
func _shine(c: int, t: float) -> float:
	var out := 0.0
	if _fuse_at[c] > -INF:
		var u := (t - _fuse_at[c]) / _iron_time()
		if u > 0.0 and u < 1.0:
			out = sin(u * PI)
	if _won:
		var w := (t - _solved_at - IRON_AT - _diag(c) * _iron_step()) / _iron_time()
		if w > 0.0 and w < 1.0:
			out = maxf(out, sin(w * PI))
	return out

## The win's band: a warm soft strip along the diagonal it has reached,
## crossing the board from the top left, the iron riding it.
func _draw_iron(b: Face.Builder, t: float) -> void:
	if not _won or Motion.reduce:
		return
	var d := (t - _solved_at - IRON_AT) / _iron_step()
	var n := float(_state.n)
	if d < -2.0 or d > 2.0 * n + 2.0:
		return
	var along := Vector2(1.0, -1.0).normalized()
	var across := Vector2(1.0, 1.0).normalized()
	var tl := _grid
	var br := _centre(_state.size() - 1) + Vector2.ONE * _cell * 0.5
	var centre := tl.lerp(br, (d + 1.0) / (2.0 * n))
	var reach := n * _cell * 1.5
	var wide := _cell * 1.1
	var a := 0.28 * clampf(minf(d + 2.0, 2.0 * n + 2.0 - d) / 3.0, 0.0, 1.0)
	var inner := _board.grow(-RIM)
	var clip := Face.Builder.round_rect(inner.position, inner.size, BOARD_RADIUS - 2.0)
	for k in 3:
		var w := wide * (1.0 - k * 0.3)
		var strip := PackedVector2Array([centre - along * reach - across * w, centre + along * reach - across * w,
			centre + along * reach + across * w, centre - along * reach + across * w])
		Rings._clip_polygon(b, strip, Color(Pal.SUN.lerp(Color.WHITE, 0.4), a * (0.5 + 0.25 * k)), clip)
	var fade := clampf(minf(d + 2.0, 2.0 * n + 2.0 - d) / 2.0, 0.0, 1.0)
	Iron.iron(b, centre, _iron_px() * 1.2, PI * 0.25, Iron.Mood.HAPPY, fade, _cell * 0.15, 1.0)

func _iron_px() -> float:
	return clampf(_cell * IRON_SIZE, 70.0, 150.0)

# --- the plates' irons ---

## Once the whole board is full and not the picture, irons every plate there
## is a verdict on, one after another (`State.plates_due`); a plate filled on
## its own brings no iron, which read as the finish playing four times
## (2026-10-04). The state judges at once (a wrong plate's beads astray are
## back in the kit); the board shows it as the iron gets there, and holds
## input until it has. One pass costs one heart at most, on its first wrong
## plate, however many are wrong. Never on a band that counts moves: there
## a verdict on a plate would be the answer, and the beads it sent home
## would be moves made for the player.
func _maybe_iron() -> void:
	if max_moves > 0:
		return
	var full: PackedInt32Array = _state.plates_due()
	if full.is_empty():
		return
	var costs := true
	var t := _now()
	var start := maxf(t, _busy_until)
	var still := Motion.reduce
	var lead := 0.0 if still else PLATE_LEAD
	var step := 0.0 if still else _plate_step()
	var tail := 0.0 if still else PLATE_TAIL
	for q in full:
		var res: Dictionary = _state.iron_plate(q)
		var travel := float(2 * _state.half) * step
		var end := start + lead + travel + tail
		var ok: bool = res.ok
		var ir := {"q": q, "at": start, "ok": ok, "end": end}
		_irons.append(ir)
		var rect := _plate_rect(q)
		if ok:
			for c in _state.plate_pegs(q):
				var local := Vector2(_centre(c) - rect.position) / _cell
				_fuse_at[c] = start + lead + (local.x + local.y) * 0.5 * step
				if _state.beads[c] != State.EMPTY:
					_touch(c, _fuse_at[c] + _iron_time())
		else:
			var reveal := start + lead + travel
			var i := 0
			for e: Array in res.astray:
				var c := int(e[0])
				var k := int(e[1])
				_flying.append({"from": _centre(c), "to": _home(k), "colour": _state.colours[k],
					"at": reveal + 0.15 + Motion.stagger(i, 0.05, 0.3), "sits": true})
				i += 1
		_after(start - t, func() -> void: fx.cue("iron", 0.96 + 0.08 * _h01(q, 7)))
		_after(start - t + lead + travel, _plate_done.bind(ir, res.astray.size(), costs and not ok))
		if not ok:
			costs = false
		start = end
		_busy_until = maxf(_busy_until, end - 0.05)
	_busy_for(start - t + HOME_TIME + 0.3)
	_halo = {}
	_refresh()

## The iron has crossed plate `ir.q`: a right plate cheers, a wrong one
## sends its beads home, and on Hard and Insane costs a heart.
func _plate_done(ir: Dictionary, astray: int, costs := true) -> void:
	# A verdict still queued behind the one that took the last heart, or
	# behind the solve, says nothing: the card or the party has the floor.
	if is_done() or (max_hearts > 0 and out_of_hearts):
		return
	var rect := _plate_rect(int(ir.q))
	var top := rect.get_center()
	if bool(ir.ok):
		_plates_right += 1
		_streak += 1
		fx.cue("plate")
		if _streak >= 2:
			_word(tr("PG_WORD_ROW") % _streak, top)
			var step: int = COMBO_STEPS[mini(_streak - 2, COMBO_STEPS.size() - 1)]
			_after(0.25, func() -> void: fx.cue("combo", pow(2.0, step / 12.0), -2.0))
		else:
			_word(tr("PG_WORD_PLATE"), top)
		if not Motion.reduce and zoom.view.has_point(zoom.to_screen(top)):
			fx.sparkle(zoom.to_screen(top), Pal.SUN)
			if _streak >= 3:
				fx.confetti(zoom.to_screen(top), 18, rect.size.x * 0.8)
				_after(0.1, func() -> void: fx.cue("confetti"))
		_gag(int(ir.q))
		return
	_streak = 0
	_lost_ever = true
	fx.cue("astray")
	if max_hearts > 0 and costs:
		_lose_heart()
		fx.cue("heart_lost")
		_tell_hearts("PG_PLATE_HEART_ONE" if astray == 1 else "PG_PLATE_HEART_N", astray)
		if out_of_hearts:
			_after(HOME_TIME + 0.5, _run_out)
	else:
		fx.buzz(Haptics.WARN)
		_tell("PG_PLATE_OFF_ONE" if astray == 1 else "PG_PLATE_OFF_N", "" if astray == 1 else str(astray))
	moved.emit()

## A plate's iron: it settles onto the plate's top left corner, glides down
## the diagonal (its lamp lit, steam behind it), and then either twirls off
## happy or stops worried while the beads astray hop home.
func _draw_plate_iron(b: Face.Builder, ir: Dictionary, t: float) -> void:
	var e := t - float(ir.at)
	var end := float(ir.end)
	if e < 0.0 or t > end + 0.25 or Motion.reduce:
		return
	var rect := _plate_rect(int(ir.q))
	var travel := float(2 * _state.half) * _plate_step()
	var k := clampf((e - PLATE_LEAD) / travel, 0.0, 1.0)
	var at := rect.position.lerp(rect.end, 0.08 + 0.84 * k)
	var lift := 0.0
	var alpha := 1.0
	var angle := PI * 0.25
	var mood := Iron.Mood.HAPPY
	if e < PLATE_LEAD:
		var u := e / PLATE_LEAD
		lift = (1.0 - u * u) * _cell * 0.9
		alpha = clampf(u * 2.0, 0.0, 1.0)
	var after := e - PLATE_LEAD - travel
	if after > 0.0:
		if bool(ir.ok):
			var u := clampf(after / TWIRL_TIME, 0.0, 1.0)
			angle += TAU * (u * u * (3.0 - 2.0 * u))
			lift = 4.0 * u * (1.0 - u) * TWIRL_HOP
		else:
			mood = Iron.Mood.WORRIED
			at.x += sin(after * 30.0) * 2.0 * clampf(1.0 - after * 2.0, 0.0, 1.0)
		alpha = clampf((end + 0.25 - t) / 0.25, 0.0, 1.0)
	Iron.iron(b, at, _iron_px(), angle, mood, alpha, lift, 1.0 if k > 0.0 and k < 1.0 else 0.4)

## Steam off any iron at work, every STEAM_EVERY.
func _steam(t: float) -> void:
	if Motion.reduce or t - _last_steam < STEAM_EVERY:
		return
	var keep: Array = []
	for ir: Dictionary in _irons:
		if t <= float(ir.end) + 0.3:
			keep.append(ir)
		var e := t - float(ir.at) - PLATE_LEAD
		var travel := float(2 * _state.half) * _plate_step()
		if e > 0.0 and e < travel:
			var rect := _plate_rect(int(ir.q))
			var at := zoom.to_screen(rect.position.lerp(rect.end, 0.08 + 0.84 * e / travel)
				- Vector2(_iron_px() * 0.25, _iron_px() * 0.1))
			# (an iron at work out of sight puffs nothing over the head)
			if zoom.view.has_point(at):
				fx.puff(at, Color(Color.WHITE, 0.8), 2)
			_last_steam = t
			if fmod(e, 0.5) < STEAM_EVERY:
				fx.cue("steam", 0.95 + 0.1 * randf(), -4.0)
	_irons = keep

# --- the silly bits ---

## A right plate's gag, alternating off the day: hearts of love off the iron,
## or a butterfly that lands on the plate and rests a while.
func _gag(q: int) -> void:
	if Motion.reduce:
		return
	var rect := _plate_rect(q)
	var t := _now()
	if (_plates_right + _state.n) % 2 == 0:
		var at := rect.position.lerp(rect.end, 0.92)
		for i in LOVE_HEARTS:
			_love.append({"pos": at, "t": t + i * 0.12, "k": i, "phase": _h01(q, i) * TAU})
		_busy_for(LOVE_TIME + 0.5)
	else:
		_flies.append({"t": t + 0.2, "pos": rect.get_center() + Vector2(_cell * 0.3, -_cell * 0.2),
			"from": -1.0 if q % 2 == 1 else 1.0})
		_after(0.25, func() -> void: fx.cue("flutter"))
		_busy_for(FLY_IN + FLY_SIT + FLY_OUT + 0.4)

func _draw_love(b: Face.Builder, t: float) -> void:
	var keep: Array = []
	for l: Dictionary in _love:
		var e: float = t - float(l.t)
		if e > LOVE_TIME:
			continue
		keep.append(l)
		if e <= 0.0:
			continue
		var u := e / LOVE_TIME
		var at: Vector2 = l.pos + Vector2((float(l.k) - 1.0) * _cell * 0.4 + sin(u * TAU + float(l.phase)) * 8.0,
			-LOVE_RISE * (1.0 - (1.0 - u) * (1.0 - u)) - _cell * 0.4)
		var r := maxf(10.0, _cell * 0.16) * Motion.pop_in_scale(e, 0.2).x
		var al := clampf((1.0 - u) / 0.4, 0.0, 1.0)
		b.polygon(_heart(at, r * 1.15, 0), Color(Pal.FLOWER_DEEP, al))
		b.polygon(_heart(at, r, 0), Color(Pal.FLOWER, al))
	_love = keep

## A butterfly's visit: in on a curve from the side, a rest on the plate,
## and off up the other way.
func _fly(b: Face.Builder, f: Dictionary, t: float) -> void:
	var e := t - float(f.t)
	if e <= 0.0 or e > FLY_IN + FLY_SIT + FLY_OUT:
		return
	var s := _cell
	var spot: Vector2 = f.pos
	var side: float = f.from
	var at := spot
	var beat := 0.3 + 0.7 * absf(sin(e * 14.0))
	var lean := 0.0
	if e < FLY_IN:
		var u := e / FLY_IN
		var from := spot + Vector2(side * s * 4.0, -s * 3.0)
		at = from.lerp(spot, 1.0 - (1.0 - u) * (1.0 - u)) + Vector2(0.0, -sin(PI * u) * s * 0.6)
		lean = -side * 0.3
	elif e < FLY_IN + FLY_SIT:
		beat = 0.25 + 0.5 * absf(sin((e - FLY_IN) * 3.0))
	else:
		var u := (e - FLY_IN - FLY_SIT) / FLY_OUT
		var to := spot + Vector2(-side * s * 3.6, -s * 4.2)
		at = spot.lerp(to, u * u) + Vector2(sin(u * 14.0) * s * 0.1, 0.0)
		lean = side * 0.3
	Cat.butterfly(b, at, maxf(34.0, s * 0.75), beat, lean)

## A word popping up over the board and floating off.
func _word(text: String, at: Vector2) -> void:
	if Motion.reduce:
		_tell_raw(text)
		return
	_words.append({"text": text, "pos": at, "t": _now()})
	_busy_for(WORD_TIME + 0.1)

func _draw_words(t: float) -> void:
	if _words.is_empty():
		return
	var font: Font = CozyTheme.display(700)
	var keep: Array = []
	for w: Dictionary in _words:
		var e: float = t - float(w.t)
		if e > WORD_TIME:
			continue
		keep.append(w)
		var u := e / WORD_TIME
		var k := Motion.pop_in_scale(e, 0.25).x
		var al := clampf((1.0 - u) / 0.35, 0.0, 1.0)
		var text: String = w.text
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, WORD_FONT).x
		# Over its place on the board as the zoom shows it, kept on the tray.
		var at: Vector2 = zoom.to_screen(w.pos).clamp(zoom.view.position + Vector2(0.0, WORD_RISE + 40.0), zoom.view.end)
		at.y -= WORD_RISE * (1.0 - (1.0 - u) * (1.0 - u))
		at.x = clampf(at.x, tw * 0.5 + 12.0, size.x - tw * 0.5 - 12.0)
		draw_set_transform(at, sin(e * 5.0) * 0.04, Vector2.ONE * k)
		var base := Vector2(-tw * 0.5, font.get_ascent(WORD_FONT) * 0.35)
		draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, WORD_FONT, 12,
			Color(Pal.SURFACE, al))
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, WORD_FONT, Color(Pal.SUN_DEEP, al))
	draw_set_transform(Vector2.ZERO)
	_words = keep

# --- the header ---

## The head's four layers, each made again only when what it shows changes:
## under the heaps (the card's frame, the box, the wells, the chosen one lit)
## on the chosen colour or a compartment shaking; the heaps on a count or a
## compartment bumped or shaking; over them (the lips, labels, dividers) with
## the first; the tweezers, hearts and bar on top while they move or their
## numbers change.
func _update_head(t: float) -> void:
	# The pattern card's pixels are made about the card's own corner (its
	# size never changes), so a relayout only moves them.
	if _thumb_mesh == null:
		_thumb_mesh = _build_thumb_pixels(Rect2(Vector2.ZERO, _thumb.size))
	var shaking := false
	var bumping := false
	for k in _chip_at.size():
		if t - float(_chip_shake[k]) < Motion.SHIVER_TIME + 0.05:
			shaking = true
		if t - float(_chip_at[k]) < Motion.BUMP_TIME + 0.05:
			bumping = true
	var box_key := "%d|%d" % [brush, 1 if _won else 0]
	if _head_under == null or shaking:
		var under := Face.Builder.new()
		var over := Face.Builder.new()
		var pick := Face.Builder.new()
		_draw_thumb_frame(under, _thumb)
		_draw_box(under, over, pick, t)
		_head_under = under.mesh()
		_head_over = over.mesh() if not over.verts.is_empty() else null
		_head_pick = pick.mesh() if not pick.verts.is_empty() else null
		# A shake's last frame leaves the key unset, so the chosen
		# compartment is made once more at rest.
		_box_key = "" if shaking else box_key
	elif box_key != _box_key:
		var pick := Face.Builder.new()
		_draw_chosen(pick, t)
		_head_pick = pick.mesh() if not pick.verts.is_empty() else null
		_box_key = box_key
	var heaps_key := ""
	for k in _state.seated.size():
		heaps_key += "%d," % _state.left(k)
	if _heaps_key != heaps_key or shaking or bumping or _heaps == null:
		_heaps = _build_heaps(t)
		_heaps_key = "" if shaking or bumping else heaps_key
	var top_key := "%d|%d|%d|%d" % [brush, _state.placed(), 1 if _won else 0, hearts]
	var top_moving := t - _tweez_at < maxf(TWEEZ_TIME, 0.3) + 0.05 or t - _split_at < SPLIT_TIME + 0.05 \
		or t - _back_at < HEART_BACK_TIME + 0.05 or t - _bar_bump < Motion.BUMP_TIME + 0.05
	if _head_lid == null or top_key != _top_key or top_moving:
		_head_lid = _build_head_lid(t)
		_top_key = "" if top_moving else top_key

## The chosen compartment lit from under, a layer of its own so a pick makes
## only this: its glow, its warm floor, and the next compartment's floor
## again over the glow's edge, as the box draws them left to right.
func _draw_chosen(pick: Face.Builder, t: float) -> void:
	if _won or brush < 0 or brush >= _chip_rects.size():
		return
	for i in range(brush, mini(brush + 2, _chip_rects.size())):
		var r := _chip_rects[i]
		var shake := Motion.shiver_offset(t - float(_chip_shake[i]), 4.0)
		var well := Rect2(r.position + Vector2(shake, 0.0), Vector2(r.size.x, r.size.y * 0.74))
		if i == brush:
			pick.fan(Face.Builder.round_rect(well.position - Vector2.ONE * 3.0, well.size + Vector2.ONE * 6.0, 13.0),
				Color(Pal.SUN, 0.75))
		pick.fan(Face.Builder.round_rect(well.position, well.size, 11.0), Color("fff3d6" if i == brush else "d3e7ee"))
		pick.fan(Face.Builder.round_rect(well.position, Vector2(well.size.x, 6.0), 3.0), Color("bdd6de"))

## The tweezers, the hearts and the bar of beads seated.
func _build_head_lid(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	_draw_tweezers(b, t)
	_draw_hearts(b, t)
	var bar := Rect2(_right.position.x, _right.end.y - BAR_H - 4.0, _right.size.x - _tally_room(), BAR_H)
	var bump := Motion.bump_scale(t - _bar_bump, 0.08)
	bar = Rect2(bar.position - Vector2(0.0, (bump - 1.0) * BAR_H * 0.5), Vector2(bar.size.x, BAR_H * bump))
	b.fan(Face.Builder.round_rect(bar.position + Vector2(0.0, 2.0), bar.size, BAR_H * 0.5), Color(Pal.TEXT, 0.12))
	b.fan(Face.Builder.round_rect(bar.position, bar.size, BAR_H * 0.5), Pal.PG_BOARD_DEEP)
	var frac := float(_state.placed()) / maxf(1.0, float(_state.target))
	if frac > 0.0:
		var full := Vector2(maxf(BAR_H, bar.size.x * frac), BAR_H * bump)
		var ink: Color = Pal.GOOD if _won or frac < 1.0 else Pal.SUN
		b.fan(Face.Builder.round_rect(bar.position, full, BAR_H * 0.5), ink)
		b.fan(Face.Builder.round_rect(bar.position + Vector2(4.0, 3.0), Vector2(maxf(0.0, full.x - 8.0), 5.0), 2.5),
			Color(Color.WHITE, 0.35))
	return b.mesh()

## The room the tally takes at the bar's right end: 150, or what its widest
## reading needs (a thousand beads).
func _tally_room() -> float:
	var font: Font = CozyTheme.display(700)
	var widest := "%d / %d" % [_state.target, _state.target]
	return maxf(150.0, font.get_string_size(widest, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NAME_SIZE).x + 18.0)

func _draw_thumb_frame(b: Face.Builder, r: Rect2) -> void:
	Scenery.soft_disc(b, r.get_center() + Vector2(0.0, r.size.y * 0.5 + 2.0), r.size.x * 0.55, 14.0,
		Color(Pal.TEXT, 0.14))
	b.fan(Face.Builder.round_rect(r.position + Vector2(0.0, 4.0), r.size, 20.0), Pal.PG_TRAY_DEEP)
	b.fan(Face.Builder.round_rect(r.position, r.size, 20.0), Pal.PG_TRAY)
	b.fan(Face.Builder.round_rect(r.position + Vector2.ONE * 8.0, r.size - Vector2.ONE * 16.0, 13.0),
		Pal.PG_BOARD_DEEP.darkened(0.12))

## The pattern card: four squares like the board's four plates, and the
## picture's pixels on them. In the card's own frame so the peek can grow
## the one mesh over the board by a transform.
func _build_thumb_pixels(r: Rect2, apart := false) -> ArrayMesh:
	var b := Face.Builder.new()
	var n: int = _state.n
	var h: int = _state.half
	var inner := r.grow(-8.0)
	var s := (inner.size.x - 12.0) / (float(n) + THUMB_GAP)
	var at := inner.position + Vector2.ONE * 6.0
	for q in 4:
		var o := at + Vector2(float(q % 2) * (h + THUMB_GAP), float(q / 2) * (h + THUMB_GAP)) * s
		var pad := minf(0.15, THUMB_GAP * 0.4) * s
		var tile := Rect2(o - Vector2.ONE * pad, Vector2.ONE * (h * s + 2.0 * pad))
		b.fan(Face.Builder.round_rect(tile.position, tile.size, s * 0.6), Pal.PG_BOARD)
		for v in h:
			for u in h:
				var k: int = _state.want[((q / 2) * h + v) * n + (q % 2) * h + u]
				var px := o + (Vector2(u, v) + Vector2(0.5, 0.5)) * s
				if _big() and k != State.EMPTY:
					# A thousand pixels: a plain square each (Bead.pixel's
					# round one with its hole is eighty vertices), whole on
					# the card and a hair apart when it is held up.
					var e := s * (0.46 if apart else 0.5)
					var col: Color = _state.colours[k]
					var v0 := b.vertex(px + Vector2(-e, -e), col)
					b.vertex(px + Vector2(e, -e), col)
					b.vertex(px + Vector2(e, e), col)
					b.vertex(px + Vector2(-e, e), col)
					b.tri(v0, v0 + 1, v0 + 2)
					b.tri(v0, v0 + 2, v0 + 3)
					continue
				Bead.pixel(b, px, s, _state.colours[k] if k != State.EMPTY else Color.WHITE, k == State.EMPTY)
	return b.mesh()

## The clear plastic box: a compartment a colour, each heaped with beads as
## many as are left (HEAP for a full one), a paper label strip for the count,
## and the chosen compartment lit from under.
func _draw_box(b: Face.Builder, over: Face.Builder, pick: Face.Builder, t: float) -> void:
	if _chip_rects.is_empty():
		return
	var box := _box
	Scenery.soft_disc(b, Vector2(box.get_center().x, box.end.y + 4.0), box.size.x * 0.52, 12.0, Color(Pal.TEXT, 0.14))
	b.fan(Face.Builder.round_rect(box.position + Vector2(0.0, 5.0), box.size, 16.0), Color("b9d3dc"))
	b.fan(Face.Builder.round_rect(box.position, box.size, 16.0), Color("e4f1f5"))
	for i in _chip_rects.size():
		var r := _chip_rects[i]
		var shake := Motion.shiver_offset(t - float(_chip_shake[i]), 4.0)
		var bump := Motion.bump_scale(t - float(_chip_at[i]), 0.06)
		var well := Rect2(r.position + Vector2(shake, 0.0), Vector2(r.size.x, r.size.y * 0.74))
		b.fan(Face.Builder.round_rect(well.position, well.size, 11.0), Color("d3e7ee"))
		b.fan(Face.Builder.round_rect(well.position, Vector2(well.size.x, 6.0), 3.0), Color("bdd6de"))
		# (The heap lies here, _build_heaps.) The box's front wall: a clear
		# lip with a gloss along it.
		var lip := Rect2(well.position + Vector2(0.0, well.size.y - 12.0), Vector2(well.size.x, 12.0))
		over.fan(Face.Builder.round_rect(lip.position, lip.size, 5.0), Color(Color.WHITE, 0.35))
		over.fan(Face.Builder.round_rect(lip.position + Vector2(5.0, 2.0), Vector2(lip.size.x - 10.0, 3.0), 1.5),
			Color(Color.WHITE, 0.6))
		# The label strip with the count.
		var label := Rect2(r.position + Vector2(4.0 + shake, r.size.y * 0.77), Vector2(r.size.x - 8.0, r.size.y * 0.21))
		over.fan(Face.Builder.round_rect(label.position, label.size, label.size.y * 0.4), Pal.PAPER)
		over.fan(Face.Builder.round_rect(label.position + Vector2(label.size.x * 0.5 - 7.0, -3.0), Vector2(14.0, 6.0), 3.0),
			_state.colours[i])
	_draw_chosen(pick, t)
	# The dividers, a hair of clear plastic between two compartments of a
	# row.
	for i in range(1, _chip_rects.size()):
		var r := _chip_rects[i]
		if not is_equal_approx(r.position.y, _chip_rects[i - 1].position.y):
			continue
		var x := (_chip_rects[i - 1].end.x + r.position.x) * 0.5
		over.fan(Face.Builder.round_rect(Vector2(x - 1.5, r.position.y - 2.0), Vector2(3.0, (r.size.y + 12.0) * 0.74), 1.5),
			Color("c7dde4"))

## Every compartment's beads: every one left, lying flat with its hole
## showing, from the floor's middle up. A bead flying out has already left.
## A compartment's whole heap is laid out once (`_heap_runs`) and its first
## `left` beads are a slice of it; a bumped compartment's beads swell about
## their own places, a copy each.
func _build_heaps(t: float) -> ArrayMesh:
	if _chip_rects.is_empty():
		return null
	var cp := Looks.Copies.new()
	if _heap_runs.size() != _chip_rects.size():
		_heap_runs = []
		for i in _chip_rects.size():
			var full := Looks.Copies.new()
			for k in _heap_full(i):
				full.add(_heap_kit, i, Transform2D(0.0, _slot(i, k)))
			_heap_runs.append(full)
	for i in _chip_rects.size():
		var left: int = mini(_heap_shown(i), _heap_runs[i].n)
		if left == 0:
			continue
		var shake := Motion.shiver_offset(t - float(_chip_shake[i]), 4.0)
		var bump := Motion.bump_scale(t - float(_chip_at[i]), 0.06)
		if not is_equal_approx(bump, 1.0):
			for k in left:
				cp.add(_heap_kit, i, Transform2D(0.0, Vector2.ONE * bump, 0.0, _slot(i, k) + Vector2(shake, 0.0)))
			continue
		var full: Looks.Copies = _heap_runs[i]
		var count: int = _heap_kit.count
		var verts := full.v.slice(0, left * count)
		if shake != 0.0:
			verts = Transform2D(0.0, Vector2(shake, 0.0)) * verts
		cp.add_run(verts, full.c.slice(0, left * count), left)
	return cp.mesh(_heap_kit)

## The steel tweezers, resting in the chosen compartment with their tips in
## the heap; they glide there from the last one and dip as they take hold.
func _draw_tweezers(b: Face.Builder, t: float) -> void:
	if _chip_rects.is_empty() or _won:
		return
	var u := 1.0 if Motion.reduce else clampf((t - _tweez_at) / TWEEZ_TIME, 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u)
	var from := _chip_rects[clampi(_tweez_from, 0, _chip_rects.size() - 1)]
	var to := _chip_rects[clampi(brush, 0, _chip_rects.size() - 1)]
	var tip := from.get_center().lerp(to.get_center(), e) + Vector2(4.0, -4.0)
	tip.y -= sin(u * PI) * 14.0
	var since := t - _tweez_at - TWEEZ_TIME
	if since > 0.0 and since < 0.3 and not Motion.reduce:
		tip.y += sin(since / 0.3 * PI) * TWEEZ_DIP
	var back := tip + Vector2(minf(to.size.x, 80.0) * 0.6, -to.size.y * 0.5)
	var dir := (back - tip).normalized()
	var side := Vector2(-dir.y, dir.x)
	Scenery.soft_disc(b, tip + Vector2(10.0, 8.0), 10.0, 6.0, Color(Pal.TEXT, 0.18))
	for sx: float in [-1.0, 1.0]:
		var a := tip + side * sx * 2.0
		var z := back + side * sx * 7.0
		var arm := PackedVector2Array([a, a.lerp(z, 0.55) + side * sx * 1.5, z])
		b.stroke(arm, 5.0, Color("8d96a3"))
		b.stroke(arm, 2.5, Color("e3e8ee"))
	b.disc(back, 5.0, Color("8d96a3"))

## The hearts on Hard and Insane, on the name's line at its right end: full
## ones smiling, a lost one splitting and falling, one back popping in.
func _draw_hearts(b: Face.Builder, t: float) -> void:
	if max_hearts <= 0:
		return
	var step := 2.0 * HEART_R + HEART_GAP
	var y := _right.position.y + 20.0
	var x0 := _right.end.x - HEART_R - 4.0 - step * (max_hearts - 1)
	for i in max_hearts:
		var at := Vector2(x0 + step * i, y)
		if i < hearts or (i == _split_index and t < _split_at):
			var r := HEART_R
			if i == _back_index and not Motion.reduce:
				r *= Motion.pop_in_scale(t - _back_at, HEART_BACK_TIME).x
			if r > 0.5:
				b.polygon(_heart(at, r, -1), Pal.FLOWER)
				b.polygon(_heart(at, r, 1), Pal.FLOWER_DEEP)
				b.ellipse(at + Vector2(-0.45, -0.5) * r, 0.16 * r, 0.1 * r, Color(1.0, 1.0, 1.0, 0.5))
			continue
		b.polygon(_heart(at, HEART_R, 0), Color(Pal.FLOWER, 0.22))
		var u := (t - _split_at) / SPLIT_TIME
		if i == _split_index and u < 1.0 and u >= 0.0 and not Motion.reduce:
			var fade := 1.0 - u * u
			for sd: int in [-1, 1]:
				var turn: float = sd * SPLIT_TURN * u
				var shift := Vector2(sd * SPLIT_SPREAD * u, SPLIT_FALL * u * u)
				var pts := _heart(Vector2.ZERO, HEART_R, sd)
				for k in pts.size():
					pts[k] = at + shift + pts[k].rotated(turn)
				b.polygon(pts, Color(Pal.FLOWER if sd < 0 else Pal.FLOWER_DEEP, fade))

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

func _draw_head_text(t: float, xf: Transform2D, seen: float) -> void:
	draw_set_transform_matrix(xf)
	var font: Font = CozyTheme.display(700)
	var name := tr(_state.pic_name)
	var hearts_w := 0.0 if max_hearts <= 0 else max_hearts * (2.0 * HEART_R + HEART_GAP) + 8.0
	# The moves' pill where the hearts sat: the right end of the name's line.
	var pill_w := 0.0
	if max_moves > 0:
		pill_w = font.get_string_size(MovesPill.line(self, moves_left), HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			MovesPill.FONT).x + 2.0 * MovesPill.PAD
		hearts_w = pill_w + 12.0
	draw_string(font, Vector2(_right.position.x + 4.0, _right.position.y + font.get_ascent(NAME_SIZE)),
		name, HORIZONTAL_ALIGNMENT_LEFT, _right.size.x - 8.0 - hearts_w, NAME_SIZE, Color(Pal.TEXT, seen))
	var count_size := COUNT_SMALL if _chip_rows > 1 else COUNT_SIZE
	for i in _chip_rects.size():
		var r := _chip_rects[i]
		var shake := Motion.shiver_offset(t - float(_chip_shake[i]), 4.0)
		var left: int = maxi(0, _state.left(i))
		var text := str(left)
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, count_size).x
		var y := r.position.y + r.size.y * 0.875 + font.get_ascent(count_size) * 0.38
		draw_string(font, Vector2(r.get_center().x + shake - wide * 0.5, y), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, count_size, Color(Pal.TEXT_DIM if left == 0 else Pal.TEXT, seen))
	var tally := "%d / %d" % [_state.placed(), _state.target]
	var tw := font.get_string_size(tally, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NAME_SIZE).x
	var bar_y := _right.end.y - BAR_H * 0.5 - 4.0
	draw_string(font, Vector2(_right.end.x - tw, bar_y + font.get_ascent(NAME_SIZE) * 0.38), tally,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, NAME_SIZE, Color(Pal.TEXT, seen))
	draw_set_transform(Vector2.ZERO)
	if max_moves > 0 and seen >= 1.0:
		_moves_pill.draw(self, xf * Vector2(_right.end.x - pill_w * 0.5 - 4.0, _right.position.y + 17.0),
			moves_left, t)
	if _thumb_mesh != null:
		draw_mesh(_thumb_mesh, null, xf * Transform2D(0.0, _thumb.position), Color(1.0, 1.0, 1.0, seen))

## The held picture: the pattern card grown over the board, so it can be
## read peg for peg beside nothing at all.
func _draw_peek(t: float, shown: Array) -> void:
	if _thumb_mesh == null:
		return
	var u := clampf((t - _peek_at) / PEEK_TIME, 0.0, 1.0)
	if Motion.reduce:
		u = 1.0
	var k := u if _peek else 1.0 - u
	if k <= 0.0:
		return
	var e := Motion.back_out(k) if _peek else k * k
	var target := _board.size.x * PEEK_COVER
	var big := Rect2(_board.get_center() - Vector2.ONE * target * 0.5, Vector2.ONE * target)
	if _state.n > PEEK_BIG:
		# A big picture as large as the card allows, over the board and as
		# much of the head as it needs.
		target = minf(size.x, size.y) - 2.0 * PEEK_EDGE
		big = Rect2(Vector2(size.x * 0.5 - target * 0.5,
			clampf(_board.get_center().y - target * 0.5, PEEK_EDGE, maxf(PEEK_EDGE, size.y - PEEK_EDGE - target))),
			Vector2.ONE * target)
	var r := Rect2(_thumb.position.lerp(big.position, e), _thumb.size.lerp(big.size, e))
	var sc := r.size.x / _thumb.size.x
	var xf := Transform2D(0.0, Vector2.ONE * sc, 0.0, r.position - _thumb.position * sc)
	var b := Face.Builder.new()
	_draw_thumb_frame(b, _thumb)
	var frame := b.mesh()
	draw_mesh(frame, null, xf, Color(1.0, 1.0, 1.0, minf(1.0, k * 2.0)))
	var pic := _thumb_mesh
	if _big():
		if _peek_mesh == null:
			_peek_mesh = _build_thumb_pixels(Rect2(Vector2.ZERO, _thumb.size), true)
		pic = _peek_mesh
	draw_mesh(pic, null, xf * Transform2D(0.0, _thumb.position), Color(1.0, 1.0, 1.0, minf(1.0, k * 2.0)))
	shown.append(frame)
	shown.append(pic)

# --- the toast ---

func _draw_toast(t: float, shown: Array) -> void:
	if _toast == "":
		return
	var since := t - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE),
		Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var line := _toast_line()
	var font: Font = CozyTheme.body(600)
	var room := maxf(TOAST_PAD, size.x - 120.0)
	var text_room := room - TOAST_PAD
	var one: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x
	var lines := 1
	var text_w := one
	if one > text_room:
		var wrapped: Vector2 = font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, text_room, TOAST_FONT)
		var lh := font.get_height(TOAST_FONT)
		lines = maxi(1, int(round(wrapped.y / lh)))
		text_w = minf(text_room, wrapped.x)
	var w := minf(room, text_w + TOAST_PAD)
	var h := TOAST_H + float(lines - 1) * font.get_height(TOAST_FONT)
	var key := "%s|%d|%d" % [line, int(w), lines]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-w, -h) * 0.5, Vector2(w, h), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh() if not b.verts.is_empty() else null
		_toast_mesh_for = key
	if _toast_mesh == null:
		return
	# (over the zoom's button, where there is one)
	var lift := ZOOM_B + ZOOM_INSET if _zoomable() and zoom.enabled else 0.0
	var mid := Vector2(size.x * 0.5, _board.end.y - TOAST_MARGIN - h * 0.5 - lift)
	draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var top := mid.y - h * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - w * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		draw_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		draw_multiline_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_CENTER, w - TOAST_PAD,
			TOAST_FONT, lines, Color(Pal.PAPER, alpha))

## The toast's words: a key (with its argument), or text already put
## together (a key starting "=").
func _toast_line() -> String:
	if _toast.begins_with("="):
		return _toast.substr(1)
	var line := tr(_toast)
	if _toast_arg != "":
		line = line % _toast_arg
	return line

func _tell(key: String, arg := "") -> void:
	_toast = key
	_toast_arg = arg
	_toast_at = _now()
	queue_redraw()

func _tell_raw(text: String) -> void:
	_tell("=" + text)

## A line about a lost heart, with how many beads went home and how many
## hearts are left.
func _tell_hearts(key: String, astray: int) -> void:
	var line := tr(key)
	if astray != 1:
		line = line % astray
	if hearts > 0:
		line += " " + (tr("SB_HEARTS_ONE") if hearts == 1 else tr("SB_HEARTS_N") % hearts)
	_tell_raw(line)

# --- input ---

## One finger holds the gesture. A press on a compartment picks its colour;
## on the pattern card it holds the card up over the board; on a peg it
## starts a stroke that seats the chosen colour -- or lifts it, when the peg
## it began on already holds that colour -- on every peg the finger crosses.
## On a board that zooms the zoom reads every event first: a second finger
## makes the first the start of a pinch, and what it had begun is taken back.
func _gui_input(event: InputEvent) -> void:
	if _zoom_live():
		match zoom.feed(event):
			PanZoom.BEGAN:
				accept_event()
				_pinch_began()
				return
			PanZoom.TOOK:
				accept_event()
				_view_moved()
				return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		var finger: int = event.index if event is InputEventScreenTouch else -1
		if event.pressed:
			if _press_finger != -2:
				return
			_press_finger = finger
			_press(event.position)
		else:
			if finger != _press_finger:
				return
			_press_finger = -2
			_release()
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		var finger: int = event.index if event is InputEventScreenDrag else -1
		if _stroking and finger == _press_finger:
			_drag(event.position)

## Two fingers are down: whatever the first had begun never happened. The
## card it held is set down; the stroke it started is taken back bead for
## bead, with the moves it spent -- and the board's end, if it spent the
## last one and the card is not yet up.
func _pinch_began() -> void:
	if _peek:
		_release()
	_cancel_stroke()
	_press_finger = -2
	_pinch_tick()
	_view_moved()

## A pinch is heard and felt as it takes hold: no ghost touch.
func _pinch_tick() -> void:
	fx.touch(0.84)

func _cancel_stroke() -> void:
	if _asleep or not (_stroking or _stroke_ended):
		return
	var t := _now()
	var back: Array = _state.cancel_stroke()
	var pegs := {}
	for e: Array in back:
		var c := int(e[0])
		pegs[c] = true
		# The peg is as it was before the press: nothing is arriving on it.
		_arrive_at[c] = -100.0
		_shake_at[c] = -100.0
		_drop[c] = 0
		_until[c] = t
		_moving[c] = true
	var refund := 0
	for e: Array in _stroke_log:
		refund += int(e[2])
	var air: Array = []
	for g: Dictionary in _incoming:
		if not pegs.has(int(g.peg)):
			air.append(g)
	_incoming = air
	air = []
	for g: Dictionary in _flying:
		if not (pegs.has(int(g.get("peg", -1))) and float(g.at) >= _stroke_at):
			air.append(g)
	_flying = air
	if max_moves > 0:
		moves_left = mini(max_moves, moves_left + refund)
		if _stroke_ended and out_of_hearts:
			out_of_hearts = false
			_running = true
			_lost_ever = _lost_before
	_stroke_ended = false
	_stroke_log = []
	_clear_gesture()
	_busy_for(0.1)
	moved.emit()
	_refresh()

func _press(at: Vector2) -> void:
	_clear_gesture()
	_stroke_log = []
	_stroke_ended = false
	if _thumb.has_point(at):
		_peek = true
		_peek_at = _now()
		_busy_for(PEEK_TIME)
		fx.cue("peek")
		queue_redraw()
		return
	if is_done() or out_of_hearts:
		return
	var chip := _chip_at_point(at)
	if chip >= 0:
		_pick(chip)
		return
	# A peg is found where the zoom shows it, and only on the tray's floor.
	if not zoom.view.has_point(at):
		return
	var p: Vector2 = zoom.to_layout(at)
	var c := _peg_at(p)
	if c < 0 or _plate_busy(_state.plate_of(c)):
		return
	_stroking = true
	_start = c
	_start_at = p
	_stroke_at = _now()
	_lost_before = _lost_ever
	_focus = _centre(c)
	_line = 0
	_erase = _state.beads[c] == brush
	_state.begin_stroke()
	_paint(c)
	_refresh()

func _drag(screen: Vector2) -> void:
	# The finger as the board was laid out; one that has left the tray's floor
	# paints no peg that is out of sight.
	var at: Vector2 = zoom.to_layout(screen.clamp(zoom.view.position, zoom.view.end - Vector2.ONE * 0.01))
	# The run keeps to the row or the column it set off along: whichever way
	# the finger first went farther, once it has gone AXIS_AFTER of a cell.
	if _line == 0:
		var d := at - _start_at
		if d.length() < _cell * AXIS_AFTER:
			return
		_line = 1 if absf(d.x) >= absf(d.y) else 2
	var home := _centre(_start)
	var c := _peg_at(Vector2(at.x, home.y) if _line == 1 else Vector2(home.x, at.y))
	if c < 0 or c == _last:
		return
	# Every peg between the last one painted and this one, so a quick finger
	# leaves no gaps in its run.
	if _last >= 0:
		var n: int = _state.n
		var a := Vector2i(_last % n, _last / n)
		var z := Vector2i(c % n, c / n)
		var steps := maxi(absi(z.x - a.x), absi(z.y - a.y))
		for i in range(1, steps):
			var q := Vector2i(roundi(lerpf(a.x, z.x, float(i) / steps)), roundi(lerpf(a.y, z.y, float(i) / steps)))
			_paint(q.y * n + q.x)
	_paint(c)
	_refresh()

## Seats or lifts on peg `c` once a stroke; a stroke never repaints a peg it
## has already crossed.
func _paint(c: int) -> void:
	_last = c
	if out_of_hearts or _painted.has(c) or _plate_busy(_state.plate_of(c)):
		return
	_painted[c] = true
	var had: int = _state.beads[c]
	# Lifting only ever lifts the chosen colour.
	if _erase and had != brush:
		return
	var to: int = State.EMPTY if _erase else brush
	# Insane counts moves: a bead seated or lifted is one, and the stroke
	# stops where the budget does.
	var cost: int = _state.move_cost(c, to) if max_moves > 0 else 0
	if cost > moves_left:
		return
	var r: String = _state.put(c, to)
	var t := _now()
	match r:
		"put":
			_stroke_log.append([c, had, cost])
			if had != State.EMPTY:
				_go_home(c, had, t)
			if _state.beads[c] != State.EMPTY:
				var k: int = _state.beads[c]
				var fly := 0.0 if Motion.reduce else FLY_TIME
				if fly > 0.0:
					# Out of the box from the top of its beads, the one the
					# kit just gave up.
					_incoming.append({"from": _slot(k, _heap_shown(k)), "peg": c, "colour": _state.colours[k], "at": t})
				_arrive_at[c] = t + fly
				_drop[c] = 2 if fly > 0.0 else 0
				_touch(c, t + fly + SEAT_TIME)
				_seated_in_stroke += 1
				# A run climbs a little as it goes, like beads clicking down
				# a row one after another.
				var climb := minf(0.12, 0.008 * _seated_in_stroke)
				fx.cue("place", 0.94 + climb + 0.06 * _h01(c, _painted.size()), 0.0)
			else:
				_touch(c, t + LIFT_TIME)
				fx.cue("lift", 0.96 + 0.08 * _h01(c, 3))
			_busy_for(FLY_TIME + SEAT_TIME)
			_bar_bump = t
			_busy_for(Motion.BUMP_TIME)
			_spend(cost, t + (0.0 if Motion.reduce else FLY_TIME + SEAT_TIME))
		"locked":
			_shake_at[c] = t
			_touch(c, t + Motion.SHIVER_TIME)
			if not _refused:
				_refused = true
				fx.cue("refuse")
				_tell("PG_FUSED")
		"taken":
			_shake_at[c] = t
			_touch(c, t + Motion.SHIVER_TIME)
			if not _refused:
				_refused = true
				fx.cue("refuse")
				_tell("PG_TAKEN")
		"none_left":
			_shake_at[c] = t
			_touch(c, t + Motion.SHIVER_TIME)
			if not _refused:
				_refused = true
				_chip_shake[brush] = t
				_busy_for(Motion.SHIVER_TIME)
				fx.cue("refuse")
				_tell("PG_NONE_LEFT")

func _release() -> void:
	if _peek:
		_peek = false
		_peek_at = _now()
		_busy_for(PEEK_TIME)
		# The card set back down: its own sound, a little lower.
		fx.cue("peek", 0.84)
		queue_redraw()
		return
	if _stroke_ended:
		# The stroke that spent the last move, closed as its finger lifts.
		_state.end_stroke()
		_stroke_ended = false
		_stroke_log = []
		_clear_gesture()
		_refresh()
		return
	if not _stroking:
		return
	_stroking = false
	_stroke_log = []
	var seated := _seated_in_stroke
	var changed: PackedInt32Array = _state.end_stroke()
	var mid := Vector2.ZERO
	for c in changed:
		mid += _centre(c)
	_clear_gesture()
	if changed.is_empty():
		_refresh()
		return
	_halo = {}
	if not _state.is_solved():
		# the stroke's one knock; the one that finishes the picture is the win
		fx.buzz(Haptics.TAP if seated > 0 else Haptics.TICK)
		_maybe_iron()
	# Under reduce motion a word is a toast; a plate's verdict this frame
	# keeps the floor.
	if seated >= STEADY and _now() - _steady_at > STEADY_GAP and not (Motion.reduce and _now() - _toast_at < 0.05):
		_steady_at = _now()
		mid /= float(changed.size())
		_word(tr("PG_WORD_WHOOSH" if seated >= WHOOSH else "PG_WORD_STEADY"), mid)
		fx.cue("steady")
		if not Motion.reduce and seated >= WHOOSH:
			fx.sparkle(zoom.to_screen(mid), Pal.SUN)
	note_move()
	_refresh()

func _pick(i: int) -> void:
	if i != brush:
		fx.cue("pick")
		_tweez_from = brush
		_tweez_at = _now()
	elif _now() - _tweez_at > TWEEZ_TIME:
		# Picking the same one again: a dip and nothing more.
		_tweez_from = brush
		_tweez_at = _now() - TWEEZ_TIME
	brush = i
	_chip_at[i] = _now()
	_busy_for(maxf(Motion.BUMP_TIME, TWEEZ_TIME + 0.3))
	queue_redraw()

func _clear_gesture() -> void:
	_stroking = false
	_erase = false
	_refused = false
	_last = -1
	_start = -1
	_line = 0
	_painted = {}
	_seated_in_stroke = 0

## The chosen colour, for a harness.
func set_brush(v: int) -> void:
	_pick(clampi(v, 0, _state.names.size() - 1))

# --- the HUD's actions ---

func can_undo() -> bool:
	return max_moves <= 0 and _state.can_undo() and not _blocked()

## Takes back the last stroke: its beads pop back off (or back on), last
## first. Putting beads back can fill a plate, and the iron comes. Never on
## a band that counts moves.
func undo() -> bool:
	if max_moves > 0 or _blocked() or _stroking:
		return false
	var before: PackedInt32Array = _state.beads.duplicate()
	var pegs: PackedInt32Array = _state.undo()
	if pegs.is_empty():
		return false
	_show_changes(before, pegs, Motion.RESET_STAGGER)
	_halo = {}
	_streak = 0
	fx.cue("undo")
	if not _state.is_solved():
		_maybe_iron()
	moved.emit()
	check_solved()
	_refresh()
	return true

## Every peg in `pegs` goes from what `before` had to what the state has
## now, the i-th `per` seconds after the first.
func _show_changes(before: PackedInt32Array, pegs: PackedInt32Array, per: float, drop := false) -> void:
	var t := _now()
	for i in pegs.size():
		var c := pegs[i]
		var at := t + (0.0 if Motion.reduce else Motion.stagger(i, per))
		if before[c] != State.EMPTY and before[c] != _state.beads[c]:
			_leaving.append({"peg": c, "colour": _state.colours[before[c]], "at": at})
		if _state.beads[c] != State.EMPTY and before[c] != _state.beads[c]:
			_arrive_at[c] = at
			_drop[c] = 1 if drop else 0
			_touch(c, at + (Motion.DROP_TIME if drop else SEAT_TIME))
		else:
			_touch(c, at + LIFT_TIME)
	_bar_bump = t
	_busy_for(Motion.BUMP_TIME + Motion.stagger(pegs.size(), per))

func hints_left() -> int:
	return maxi(0, State.hints_for(_state.band) + hints_extra - hints_used)

## Puts one peg right and fixes it: a bead out of place is lifted (or turned
## the right colour), else a missing bead drops in, under the hint's ring.
func hint() -> bool:
	if _blocked() or hints_left() <= 0 or _stroking:
		return false
	var before: PackedInt32Array = _state.beads.duplicate()
	var h: Dictionary = _state.hint()
	if h.is_empty():
		return false
	hints_used += 1
	var c: int = h.peg
	var pegs := PackedInt32Array()
	for o in _state.size():
		if before[o] != _state.beads[o]:
			pegs.append(o)
	_show_changes(before, pegs, 0.0, true)
	_halo = {}
	if not Motion.reduce:
		_rings.append({"pos": _centre(c), "at": _now()})
		_busy_for(Motion.RING_TIME)
	# A peg out of sight is brought into view; its sparkle is for one in it.
	if zoom.view.has_point(zoom.to_screen(_centre(c))):
		fx.sparkle(zoom.to_screen(_centre(c)), Pal.SUN)
	_show_peg(c)
	fx.cue("hint")
	if not _state.is_solved():
		fx.buzz(Haptics.GOOD)
	if int(h.was) != State.EMPTY and _state.beads[c] == State.EMPTY:
		_tell("PG_HINT_LIFT")
	elif int(h.was) != State.EMPTY:
		_tell("PG_HINT_SWAP")
	else:
		_tell("PG_HINT_SEAT")
	if not _state.is_solved():
		_maybe_iron()
	moved.emit()
	check_solved()
	_refresh()
	return true

## Every bead that is not where the picture wants it gets a rose halo and a
## shake, held until the next move. Counts a check. Easy and Medium only.
func check() -> int:
	if _blocked() or _state.band >= 3:
		return 0
	checks += 1
	var wrong: PackedInt32Array = _state.wrong()
	var t := _now()
	_halo = {}
	_halo_at = t
	for c in wrong:
		_halo[c] = true
		_shake_at[c] = t
		_touch(c, t + Motion.SHIVER_TIME)
	if wrong.is_empty():
		var missing: int = _state.target - _state.placed()
		if missing > 0:
			_tell("PG_CHECK_OK_ONE" if missing == 1 else "PG_CHECK_OK_N", "" if missing == 1 else str(missing))
		else:
			_tell("PG_CHECK_OK")
		fx.cue("check_ok")
	else:
		_tell("PG_CHECK_ONE" if wrong.size() == 1 else "PG_CHECK_N", "" if wrong.size() == 1 else str(wrong.size()))
		fx.cue("check")
		_show_peg(wrong[0])
	_refresh()
	return wrong.size()

## Brings peg `c` into view on a board zoomed close.
func _show_peg(c: int) -> void:
	if zoom.zoomed():
		zoom.show_point(_centre(c))
		_view_moved()

## Every bead back in its compartment but the ones a hint or an iron fixed,
## flying home in a wave from the far corner. A bare board is the picture
## from the top, so the moves come back too.
func reset_board() -> void:
	if _blocked():
		return
	moves_left = max_moves
	_zoom_whole()
	var before: PackedInt32Array = _state.beads.duplicate()
	var pegs: PackedInt32Array = _state.reset()
	_send_home(before, pegs)
	_halo = {}
	_streak = 0
	moves = 0
	_running = true
	_tell("PG_RESET")
	fx.cue("reset")
	_refresh()

## A bead lifted by a touch flies back to its compartment.
func _go_home(c: int, k: int, t: float) -> void:
	if Motion.reduce:
		return
	_flying.append({"from": _centre(c), "to": _home(k), "colour": _state.colours[k], "at": t, "sits": false, "peg": c})
	_busy_for(HOME_TIME + 0.1)

func _send_home(before: PackedInt32Array, pegs: PackedInt32Array) -> void:
	var t := _now()
	var far: int = 2 * (_state.n - 1)
	for c in pegs:
		var k := before[c]
		var at := t + (0.0 if Motion.reduce else Motion.stagger(far - _diag(c), Motion.RESET_STAGGER, 0.5))
		_flying.append({"from": _centre(c), "to": _home(k), "colour": _state.colours[k], "at": at, "sits": false})
	_bar_bump = t
	_busy_for(0.5 + HOME_TIME + 0.1)

func is_solved() -> bool:
	return _state.is_solved()

## The finished picture, and Insane and Flawless when earned.
func share_glyphs() -> String:
	var out: String = _state.share_glyphs()
	if _state.insane() and is_solved():
		out += "\n🏅 " + tr("BN_INSANE_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless:
		out += "\n🏅 " + tr("BN_FLAWLESS")
	return out

# --- hearts ---

## `cost` moves go off Insane's counter. The last one gone with the
## picture unfinished ends the board once the bead has landed (`land`); a
## stroke in hand ends where it is.
func _spend(cost: int, land: float) -> void:
	if max_moves <= 0 or cost <= 0:
		return
	moves_left = maxi(0, moves_left - cost)
	_moves_pill.bump(_now())
	_busy_for(Motion.BUMP_TIME)
	queue_redraw()
	if moves_left > 0 or is_done() or _state.is_solved():
		return
	_lost_ever = true
	out_of_hearts = true
	_running = false
	if _stroking:
		# The stroke paints no more, and is closed as its finger lifts or the
		# card comes: until then a second finger can still take it back.
		_stroking = false
		_stroke_ended = true
	moved.emit()
	_after(maxf(0.0, land - _now()) + (0.0 if Motion.reduce else 0.3), _run_out)

func _lose_heart() -> void:
	hearts = maxi(0, hearts - 1)
	_split_index = hearts
	_split_at = _now()
	if hearts <= 0:
		out_of_hearts = true
		# A stroke in hand when the last heart goes ends where it is.
		if _stroking:
			_state.end_stroke()
			_clear_gesture()
	_busy_for(SPLIT_TIME)
	queue_redraw()

## The last heart is gone: dusk falls over the table, and the out-of-hearts
## card comes up.
func _run_out() -> void:
	if _asleep or not out_of_hearts or is_done():
		return
	_asleep = true
	if _stroke_ended:
		_state.end_stroke()
		_stroke_ended = false
		_stroke_log = []
	zoom.reset()
	_view_moved()
	fx.cue("out_of_hearts")
	_dusk_toward(DUSK)
	_refresh()
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

func _dusk_toward(tint: Color) -> void:
	if _dusk_tw != null and _dusk_tw.is_valid():
		_dusk_tw.kill()
	if Motion.reduce:
		modulate = tint
		return
	_dusk_tw = create_tween()
	_dusk_tw.tween_property(self, "modulate", tint, DUSK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, [], _moves_bonus()) if max_moves > 0 \
		else load(OUT_OF_HEARTS).new(_heart_used, ["PG_OUT_BODY", "PG_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## What the out-of-moves card's video buys.
func _moves_bonus() -> int:
	return maxi(MOVES_BONUS, max_moves / MOVES_BONUS_PART)

## Try again: the same picture on a bare board (a hint's pegs kept), every
## heart and the whole budget of moves back, the clock and the moves made
## from zero. Hints spent stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	var before: PackedInt32Array = _state.beads.duplicate()
	_state.restart()
	_gen += 1
	_reset_looks()
	var pegs := PackedInt32Array()
	for c in _state.size():
		if before[c] != State.EMPTY and _state.beads[c] == State.EMPTY:
			pegs.append(c)
	_send_home(before, pegs)
	hearts = max_hearts
	moves_left = max_moves
	out_of_hearts = false
	_asleep = false
	_split_index = -1
	elapsed = 0.0
	moves = 0
	_running = true
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	fx.cue("reset")
	_refresh()
	moved.emit()

## One more heart (the card's video): once a picture. Morning comes back and
## play goes on from where it was.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_heart_used = true
	if max_moves > 0:
		moves_left = _moves_bonus()
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
	if max_moves <= 0:
		_tell("PG_HEART_BACK")
	_busy_for(maxf(HEART_BACK_TIME, Motion.BUMP_TIME))
	_refresh()
	moved.emit()

func _leave_board() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("PG_WIN") % tr(_state.pic_name)}

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return IRON_AT + 2.0 * _state.n * _iron_step() + _iron_time() + WIN_WAIT

func _on_solved() -> void:
	var t := _now()
	_solved_at = t
	_won = true
	_clear_gesture()
	_zoom_whole()
	_halo = {}
	_flawless = hints_used == 0 and checks == 0 and not _lost_ever
	for q in 4:
		if _state.ironed[q] == 0:
			_state.iron_plate(q)
	var span: float = IRON_AT + 2.0 * _state.n * _iron_step() + _iron_time()
	if not _big():
		# Every bead is live while the wave and the iron cross it.
		for c in _state.size():
			if _state.beads[c] != State.EMPTY:
				_touch(c, t + span)
	elif not Motion.reduce:
		# A big board: a diagonal at a time, as the iron gets there
		# (_win_front), the still beads cut its way.
		_by_diag = true
		_win_diag = 0
	_busy_for(span + PEGS_GONE)
	fx.cue("solved")
	if not Motion.reduce:
		_after(IRON_AT, func() -> void:
			if _solved_at == t:
				fx.cue("iron"))
	_party(span)
	_refresh()

func completion_record() -> Dictionary:
	return {"hearts": hearts, "flawless": _flawless, "moves": moves_left}

## A reopened daily that was already solved: the whole picture seated and
## fused, the bare pegs gone, the cat asleep on the pattern card and the
## seal. Never check_solved(): `solved` must not fire twice.
func restore_completed_board() -> void:
	_close_card()
	_gen += 1
	_state.fill()
	_reset_looks()
	zoom.reset()
	hearts = clampi(int(completed_record.get("hearts", max_hearts)), 0, max_hearts)
	moves_left = clampi(int(completed_record.get("moves", max_moves)), 0, max_moves)
	_flawless = bool(completed_record.get("flawless", false))
	out_of_hearts = false
	modulate = Color.WHITE
	_toast = ""
	var t := _now()
	_solved_at = t - 100.0
	_won = true
	_opened = t - 100.0
	_cat_at = t - 100.0
	_cat_curled = false
	if _flawless or _state.insane():
		_stamp_at = t - 100.0
	_place_cat(t)
	_refresh()

# --- the party ---

## After the win's iron: confetti, the nap cat hopping onto the pattern card
## and curling up, a line of bead wisdom, and the seal when the solve earned
## one (flawless, or any Insane).
func _party(span: float) -> void:
	var now := _now()
	var lead := 0.0 if Motion.reduce else span + 0.15
	_party_at = now + lead
	_after(lead + 0.6, func() -> void: _tell("PG_CHEER_%d" % posmod(_state.pic_id.hash(), CHEERS)))
	_cat_at = now if Motion.reduce else _party_at + CAT_AT
	if _flawless or _state.insane():
		_stamp_at = now if Motion.reduce else _party_at + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_busy_for(STAMP_DROP * 2.0 + 0.1))
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
	if Motion.reduce:
		return
	var field := _board
	_after(lead, func() -> void:
		fx.confetti(Vector2(field.get_center().x, field.position.y + 40.0), 30, field.size.x * 0.9)
		fx.cue("party"))
	_after(lead + 0.6, func() -> void:
		fx.confetti(field.get_center(), 24, field.size.x * 0.7))
	_after(lead + 0.3, func() -> void:
		# The iron's last bow: hearts of love off the tray's far corner.
		for i in LOVE_HEARTS:
			_love.append({"pos": field.end - Vector2(RIM + _cell, RIM + _cell), "t": _now() + i * 0.12,
				"k": i, "phase": float(i)})
		_busy_for(LOVE_TIME + 0.5))

# --- the nap cat ---

func _cat_px() -> float:
	return _thumb.size.x * 0.82

## Where she curls up: on the pattern card.
func _cat_spot() -> Vector2:
	return _thumb.get_center() + Vector2(0.0, _thumb.size.y * 0.06)

func _cat_start() -> Vector2:
	return Vector2(_right.position.x + _right.size.x * 0.35, _thumb.get_center().y + _thumb.size.y * 0.06)

func _cat_walk() -> float:
	return CAT_POP + CAT_HOPS * CAT_HOP_TIME

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

## The seal on the tray's lower right corner, dropping in and settling, its
## words over it: Flawless; on Insane "Insane" over Flawless or the board's
## motto, on the night seal.
func _draw_stamp(t: float, shown: Array) -> void:
	var rad := size.x * STAMP_R * 0.75
	var insane: bool = _state.insane()
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := t - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := _board.end - Vector2(rad * 0.7, rad * 0.6)
	centre.x = clampf(centre.x, rad * 1.08, size.x - rad * 1.08)
	centre.y = minf(centre.y, size.y - rad * 1.02)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	draw_set_transform_matrix(xf)
	draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless else tr("PG_MOTTO"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(self, rad, lines)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## A fixed pseudo-random number per pair, 0..1.
static func _h01(a: int, b: int) -> float:
	return float(posmod(hash(Vector2i(a, b)), 1000)) / 1000.0
