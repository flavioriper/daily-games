extends Control

## Gumdrop's table: one piece of clear jelly, cast as a real thing, tinted
## with a needle of syrup to match a card (specs
## docs/superpowers/specs/2026-10-10-arcade-gumdrop-design.md and
## 2026-10-11-gumdrop-daily-design.md). **The kitchen table is the whole
## rect**, edge to edge (CLAUDE.md: a game's world fills the screen): on it
## lie the card with the picture of what is wanted, the tray with the
## mould, the pots of syrup and the two round buttons. Whoever owns it
## lays its chrome over it and says what that covers (`set_clear`): the
## daily board (puzzles/gumdrop2d.gd) under the flat host's rows, and the
## tutorial's bench (ui/hud/gumdrop_tutorial_diagram.gd), which is this
## with a layout of its own. It was the Arcade screen until 2026-10-11.
##
## Play: a finger drawn over the tray moves the needle's tip as far as the
## finger goes (it need not be on the tip, so it never hides it) and a tap
## puts the tip there; a pot touched is the flavour in the needle; the
## pink button squeezes for as long as it is held; the gold one serves the
## mould. The day is puzzles/gumdrop_sim.gd's, stepped at its fixed DT;
## this draws it, plays its events and hands each on (`happened`). How near
## the card the mould is stays hidden while it is played (a ? beside the
## card): serving it is the check, and the number is told then.
##
## Drawing: three Controls one over the other. The field draws the table,
## the tray and the mould's floor. The syrup is the fluid's dye texture
## (puzzles/gumdrop_fluid.gd, a real fluid on the GPU) drawn once through
## shaders/gumdrop_syrup_2d.gdshader. The top draws the jelly's skin over
## it, the card, the pots, the buttons, the needle and one live mesh.
## Every one of those is a cached mesh under a transform; a mould's three
## are built when it is dealt. Each frame the table tells the fluid where
## the tip is and whether it is squeezed (`_drive`), and when the sim asks
## to be judged it reads the fluid back.
##
## The win: the card, the pots, the buttons and the needle fade and the
## tray slides to the middle of the span its owner leaves (`set_clear`
## with `won`), under the tray's one transform, so no mesh is rebuilt.

## Each of the sim's events, after the table has played it.
signal happened(ev: Dictionary)

const Sim = preload("res://puzzles/gumdrop_sim.gd")
const Mould = preload("res://puzzles/gumdrop_mould.gd")
const Art = preload("res://puzzles/gumdrop_art.gd")
const Fluid = preload("res://puzzles/gumdrop_fluid.gd")
const Syrup = preload("res://shaders/gumdrop_syrup_2d.gdshader")
const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
## What the phone knocks for (docs/agents/haptics.md). The events that share
## a frame ask through `_feel` and the frame knocks once, with the
## strongest; no cue is mapped.
const HAPTICS := {}
const Face = preload("res://ui/faces/face.gd")

const Rewards = preload("res://arcade/rewards.gd")

const MARGIN := 40
const GAP := 20
## The card over the tray, the row the pots stand in, the squeeze button's
## radius and the serve button's, and how far apart the pots stand.
const CARD := Vector2(500.0, 180.0)
const POT_H := 150.0
const POT_GAP := 150.0
const SQUEEZE_R := 104.0
const SERVE_R := 66.0
const SERVE_OFF := 250.0
## The drain button (2026-10-14, the user: "we also need another tool to
## remove fluid"): held, it draws syrup back out of the chunk under the
## tip, as the squeeze button puts it in. It stands to the right of the
## squeeze, the serve button's mirror.
const DRAIN_R := 66.0
## The meter (the user, the same day: "a indicator about % of filled, so
## user can have a reference when doing like 50% of each color"): the
## squeeze button's white rim fills clockwise with the chunk under the
## tip, a segment a pigment, 100% the card's shade, and the number sits
## under the drop; more than full climbs a dark ring outside it. It eases
## toward the fluid's reading at this rate and fades at this one when the
## tip is over the tray.
const METER_EASE := 12.0
const METER_FADE := 6.0
const METER_FONT := 28
## The needle's length in pixels and how far it leans.
const DROPPER := 250.0
const LEAN := 0.55
## A finger that has moved less than this far has tapped.
const TAP_PX := 14.0
## The most sim steps one frame may run, so a stall never fast-forwards.
const MAX_STEPS := 6
## Seconds between two of the needle's rings on the jelly while it is
## squeezed.
const POUR_GAP := 0.17
## The pour is liquid (the user, 2026-10-11: "we need a more liquid sound
## for when adding liquid and mixing colors"): a loop of syrup running
## while it goes into a cell, at this level, linear, coming up and going
## down over these seconds; and the bubbles of a second flavour going into
## a cell that holds another, this far apart.
const POUR_TOP := 0.9
const POUR_IN := 0.12
const POUR_OUT := 0.3
const MIX_GAP := 0.6
const DRAIN_PITCH := 0.78
## The cozy rules (docs/agents/sound.md): no cue climbs past five semitones,
## and a tick that repeats varies by TICK_VARY and climbs nothing.
const CLIMB_TOP := 1.335
const TICK_VARY := 0.06
## Seconds the tray takes to the middle of the win's span, the room kept
## under it for its shadow, and how long the fluid still runs once the day
## is done (the last mould settling, or a finished day's fill).
const WIN_TIME := 0.45
const WIN_FOOT := 24.0
const DONE_RUN := 5.0

var sim: RefCounted
## What of the rect the owner's chrome covers at the top and the foot, and
## whether the day is won (`set_clear`).
var clear := Vector2.ZERO
var won := false
var _won_at := -10.0
var _win_tray := Rect2()
## The fluid's passes are off while this is set (a card over the table).
var held := false
var _refund := 0
var field: Control
var _syrup: Control
var _top: Control
## The fluid, and where the tip was last frame (its drag).
var _fluid: Node
var _tip_was := Vector2.ZERO
var _fx: Node2D
var _match_l: Label
var _need_l: Label
var _acc := 0.0
var _shown_index := -1
var _shown_match := -2

## The knock this frame's events asked for, the strongest of them (-1: none).
var _knock := -1
## Where everything lies on the table (`_place`): the tray's square, pixels
## a mould unit, the card, each pot's foot, and the two buttons' middles.
var _tray := Rect2()
var _u := 6.0
var _card := Rect2()
var _pot_at: Array = []
var _squeeze_at := Vector2.ZERO
var _serve_at := Vector2.ZERO
var _drain_at := Vector2.ZERO
## The buttons' radii as laid (the tutorial's bench lays them smaller).
var _squeeze_r := SQUEEZE_R
var _serve_r := SERVE_R
var _drain_r := DRAIN_R
## The meter: the chunk's pigments as shown (eased), how far it is shown,
## and its mesh, handed over each frame.
var _level := Vector3.ZERO
var _meter_k := 0.0
var _meter: ArrayMesh
var _table: ArrayMesh
var _table_of := Vector2.ZERO
## The dealt mould's meshes and what they were built for.
var _floor: ArrayMesh
var _walls: ArrayMesh
var _picture: ArrayMesh
var _built_for := {}
var _built_u := 0.0
var _live: ArrayMesh
## The screen's own clock, for motion the sim does not own.
var _clock := 0.0
## The fingers: the one drawing the needle about (-1 none, -2 the mouse),
## where it was last and how far it has gone, and the one on the squeeze
## button.
var _aim_by := -1
var _aim_moved := 0.0
var _squeeze_by := -1
var _drain_by := -1
var _serve_down := -10.0
## The needle as drawn: its tip eased to the sim's, and how far in its
## plunger is.
var _tip := Vector2(50, 50)
var _squash := 0.0
var _pour_at := -10.0
var _pour_snd: AudioStreamPlayer
var _mix_at := -10.0
## The pots that have gone into each cell of the mould on the tray:
## {cell: {flavour: true}}.
var _cell_pots := {}
var _pick_at := -10.0
var _deal_at := -10.0
var _verdict_at := -10.0
var _wobble := 0.0
var _slid := false
## Rings on the jelly, in mould units: {pos, t, life, r, col}.
var _bits: Array = []
## The loud rewards over the whole table (arcade/rewards.gd).
var _rw: Rewards

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = CozyTheme.make()
	var table := _build_field()
	table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(table)
	_rw = Rewards.new()
	add_child(_rw)
	_build_pour()

## The loop of syrup running, silent until something is poured. A table
## that is not the board's (the tutorial's bench) has no set and no loop.
func _build_pour() -> void:
	var path := "res://assets/sfx/%s/pour.ogg" % (call("puzzle_id") if has_method("puzzle_id") else "gumdrop")
	if not ResourceLoader.exists(path):
		return
	_pour_snd = AudioStreamPlayer.new()
	_pour_snd.volume_db = -80.0
	var stream: AudioStreamOggVorbis = (load(path) as AudioStreamOggVorbis).duplicate()
	stream.loop = true
	_pour_snd.stream = stream
	add_child(_pour_snd)

## The table: the field, the syrup over it, the top over that, the card's
## two lines, the lettering and the effects.
func _build_field() -> Control:
	field = Control.new()
	field.name = "Field"
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.resized.connect(_layout_field)
	field.gui_input.connect(_on_field_input)
	_syrup = Control.new()
	_syrup.name = "Syrup"
	_syrup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_syrup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_syrup.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_syrup.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var mat := ShaderMaterial.new()
	mat.shader = Syrup
	_syrup.material = mat
	_syrup.draw.connect(_draw_syrup)
	field.add_child(_syrup)
	_top = Control.new()
	_top.name = "Top"
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top.draw.connect(_draw_top)
	field.add_child(_top)
	_fluid = Fluid.new()
	_fluid.name = "Fluid"
	field.add_child(_fluid)

	# a ? while the mould is played, its number once it is served
	_match_l = Label.new()
	_match_l.theme_type_variation = "DayBig"
	_match_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_match_l.text = "?"
	field.add_child(_match_l)
	_need_l = Label.new()
	_need_l.theme_type_variation = "MenuKicker"
	_need_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_need_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(_need_l)

	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	field.add_child(_fx)
	return field

## What the owner's chrome covers at the top and the foot of this rect, in
## its own pixels; `now_won` is the day won, the tray going to the middle
## of what is left (`instant`: already there, a finished day reopened).
func set_clear(top: float, bottom: float, now_won := false, instant := false) -> void:
	clear = Vector2(top, bottom)
	if now_won and not won:
		_won_at = _clock - (WIN_TIME if instant or Motion.reduce else 0.0)
	won = now_won
	_layout_field()

func _bands() -> Vector2:
	return clear

## How many pots the mould has stood by it.
func _pots() -> int:
	return sim.pots.size() if sim != null else 2

## Lays the table: the card, the tray under it as big as the room allows,
## the pots under the tray and the buttons at the foot, the squeeze in the
## middle where either thumb reaches it and the serve to its left (the
## right thumb hides the lower right).
func _place() -> void:
	var bands := _bands()
	var s := field.size
	var room := maxf(1.0, s.y - bands.x - bands.y)
	var fixed := CARD.y + GAP * 2.0 + POT_H + GAP + SQUEEZE_R * 2.0 + GAP
	var side := clampf(minf(s.x - MARGIN * 2.0 - 30.0, room - fixed), 160.0, 1000.0)
	var y := bands.x + maxf(0.0, (room - fixed - side) * 0.5)
	_card = Rect2((s.x - CARD.x) * 0.5, y + 8.0, CARD.x, CARD.y)
	y += CARD.y + GAP * 2.0
	_tray = Rect2((s.x - side) * 0.5, y, side, side)
	_u = side / Mould.SIDE
	y += side + GAP + POT_H
	_pot_at.clear()
	var n := _pots()
	for i in n:
		_pot_at.append(Vector2(s.x * 0.5 + (i - (n - 1) * 0.5) * POT_GAP, y - 14.0))
	y += GAP + SQUEEZE_R
	_squeeze_at = Vector2(s.x * 0.5, y)
	_serve_at = Vector2(s.x * 0.5 - SERVE_OFF, y + 10.0)
	_drain_at = Vector2(s.x * 0.5 + SERVE_OFF, y + 10.0)
	# the win's tray: as big as the span allows, in its middle
	var big := clampf(minf(s.x - MARGIN * 2.0 - 30.0, room - WIN_FOOT), 160.0, 1000.0)
	_win_tray = Rect2((s.x - big) * 0.5, bands.x + maxf(0.0, (room - WIN_FOOT - big) * 0.5), big, big)

func _layout_field() -> void:
	if field.size.x <= 0.0 or field.size.y <= 0.0:
		return
	if _table == null or _table_of != field.size:
		_table_of = field.size
		_table = Art.table(field.size)
	_place()
	_place_labels()
	_redraw()

func _place_labels() -> void:
	var right := Rect2(_card.position + Vector2(CARD.y + 10.0, 0), Vector2(_card.size.x - CARD.y - 30.0, _card.size.y))
	_match_l.size = Vector2(right.size.x, 96.0)
	_match_l.position = right.position + Vector2(0, 22.0)
	_need_l.size = Vector2(right.size.x, 40.0)
	_need_l.position = right.position + Vector2(0, 118.0)

func _redraw() -> void:
	field.queue_redraw()
	_syrup.queue_redraw()
	_top.queue_redraw()

## A point of the mould on the field, and back.
func px(p: Vector2) -> Vector2:
	return _group() * (p * _u)

func to_mould(p: Vector2) -> Vector2:
	return (p - _tray.position) / _u

## How far the win has gone, 0 to 1: the chrome of the table fading and
## the tray on its way to the middle.
func _win_k() -> float:
	if not won:
		return 0.0
	var k := clampf((_clock - _won_at) / WIN_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)

## The tray's own transform: where it lies, slid aside as a served mould
## leaves and the next comes, shaken as a jelly is when it is judged, and
## carried to the middle on the win.
func _group() -> Transform2D:
	var at := _tray.position
	var sc := Vector2.ONE
	if not Motion.reduce:
		at.x += _slide() * field.size.x
		var since := _clock - _verdict_at
		if since >= 0.0 and since < 1.6:
			var w := _wobble * sin(since * 19.0) * exp(-since * 3.0)
			sc = Vector2(1.0 + w, 1.0 - w)
	var mid := _tray.size * 0.5
	var xf := Transform2D(0.0, sc, 0.0, at + mid - mid * sc)
	var k := _win_k()
	if k > 0.0:
		var grow := lerpf(1.0, _win_tray.size.x / _tray.size.x, k)
		xf = Transform2D(0.0, Vector2(grow, grow), 0.0, _tray.position.lerp(_win_tray.position, k)) \
			* Transform2D(0.0, sc, 0.0, mid - mid * sc)
	return xf

## How far aside the tray is, in screens: off to the left as a mould that
## passed is taken away, in from the right as the next is set down.
func _slide() -> float:
	if sim == null:
		return 0.0
	if sim.phase == Sim.Phase.SHOW and bool(sim.verdict.get("pass", false)):
		var k := clampf((sim.phase_t - (Sim.SHOW_T - 0.4)) / 0.4, 0.0, 1.0)
		return -k * k * 1.1
	var k2 := clampf((_clock - _deal_at) / 0.45, 0.0, 1.0)
	return (1.0 - Motion.back_out(k2)) * 1.1 if _slid else 0.0

# --- the game ---

## A day (or a tutorial page's round) laid on the table from its start.
func lay(game: RefCounted) -> void:
	sim = game
	_acc = 0.0
	_bits.clear()
	_aim_by = -1
	_squeeze_by = -1
	_drain_by = -1
	_level = Vector3.ZERO
	_meter_k = 0.0
	_deal_at = -10.0
	_verdict_at = -10.0
	_slid = false
	_shown_index = -1
	_shown_match = -2
	_cell_pots.clear()
	won = false
	held = false
	_tip = sim.tip
	_tip_was = sim.tip
	_fluid.calm = Motion.reduce
	_fluid.lay(sim.mould)
	sim.events.clear()
	_rw.clear()
	_layout_field()
	_refresh_hud()

## A cue and a knock of the owner's (the day run out, a serve bought back).
func cue(cue_name: String, knock := -1) -> void:
	_fx.cue(cue_name)
	if knock >= 0:
		_fx.buzz(knock)

## The gold the boosters of its Arcade days came back as: lettered over
## the tray on the first frame the table has its size.
func told_refund(gold: int) -> void:
	_refund = gold

## The day's first sound. No words over the tray: no other board has
## them, and the ? has the tutorial (the user, 2026-10-11: "remove this
## tutorial text on gumdrop, no other game have it").
func greet() -> void:
	_fx.cue("start")

func _process(delta: float) -> void:
	if sim == null:
		return
	_clock += delta
	_acc += minf(delta, Sim.DT * MAX_STEPS)
	while _acc >= Sim.DT:
		_acc -= Sim.DT
		_hand()
		sim.step()
		_play_events()
	_drive(delta)
	_animate(delta)
	_refresh_hud()
	_knock_now()
	_redraw()

## The tutorial's hand works the sim from here.
func _hand() -> void:
	pass

## The frame's state into the fluid: the tip in mould widths, its cell,
## the squeeze, the pigment, how fast the tip is being drawn, and any cell
## a tutorial page wants coloured before it starts.
func _drive(delta: float) -> void:
	_fluid.set_running(_fluid_runs())
	_fluid.tip = sim.tip / Mould.SIDE
	var cell: int = sim.tip_cell()
	_fluid.tip_cell = cell
	_fluid.tip_squares = sim.count[cell] if cell >= 0 and cell < sim.count.size() else 0
	_fluid.squeezing = sim.squeezing and sim.phase <= Sim.Phase.PLAY
	_fluid.draining = sim.draining and sim.phase <= Sim.Phase.PLAY
	_fluid.pigment = Mould.PIGMENT[int(sim.pots[sim.picked].flavour)]
	_fluid.drag = (sim.tip - _tip_was) / Mould.SIDE / maxf(delta, 0.001)
	_tip_was = sim.tip
	if not sim.prefill.is_empty() and _fluid.clear_done():
		var pre: Dictionary = sim.prefill.pop_front()
		_fluid.fill_cell = int(pre.cell)
		_fluid.fill_pig = pre.pigment
	_fluid.tick(delta)

## Whether the fluid's passes run this frame: not under a card, and not
## long after the day is done.
func _fluid_runs() -> bool:
	return sim != null and not held and is_visible_in_tree() \
		and not (sim.is_done() and sim.phase_t > Sim.SHOW_T + DONE_RUN)

func _feel(kind: int) -> void:
	_knock = maxi(_knock, kind)

func _knock_now() -> void:
	if _knock >= 0:
		_fx.buzz(_knock)
		_knock = -1

func _animate(delta: float) -> void:
	for bit: Dictionary in _bits:
		bit.t += delta
	_bits = _bits.filter(func(bit: Dictionary) -> bool: return bit.t < bit.life)
	_tip = _tip.lerp(sim.tip, minf(1.0, delta * 30.0))
	var cell: int = sim.tip_cell()
	var playing: bool = sim.phase <= Sim.Phase.PLAY and cell >= 0
	var pouring: bool = sim.squeezing and playing
	var draining: bool = sim.draining and not sim.squeezing and playing
	_squash = lerpf(_squash, 1.0 if sim.squeezing else (-0.5 if sim.draining else 0.0), minf(1.0, delta * 16.0))
	if (pouring or draining) and _clock - _pour_at >= POUR_GAP:
		_pour_at = _clock
		# rings out of the tip as it pours, into it as it draws out
		_ring(sim.tip, 4.0, 0.5, Color(1, 1, 1, 0.8), draining)
	_pour_sound(delta, pouring, draining)
	# the meter: the chunk under the tip, eased; gone when the tip is over
	# the tray or the mould is served
	if playing and not won:
		var read: Vector3 = _fluid.level(cell)
		if DisplayServer.get_name() != "headless":
			sim.learn(cell, read.x + read.y + read.z)
			# a chunk drawn back to nothing forgets what went into it
			if not sim.squeezing and read.x + read.y + read.z < Sim.WET:
				_cell_pots.erase(cell)
		_level = _level.lerp(read, minf(1.0, delta * METER_EASE))
		_meter_k = minf(1.0, _meter_k + delta * METER_FADE)
	else:
		_meter_k = maxf(0.0, _meter_k - delta * METER_FADE)
		if _meter_k <= 0.0:
			_level = Vector3.ZERO
	_rw.bounds = Rect2(_rw.at(field, Vector2.ZERO), field.size)
	if _refund > 0 and field.size.x > 0.0:
		_rw.sticker(tr("GD_REFUND") % _refund, _rw.at(field, _tray.get_center() + Vector2(0, _tray.size.y * 0.32)), 44, 3.5, false, Color("fff4c2"), false, "refund")
		_refund = 0
	_rw.step(delta)

## What a pour sounds like: the loop up while syrup goes into a cell and
## down when it stops, and the bubbles while this flavour goes into a cell
## that another has gone into.
func _pour_sound(delta: float, pouring: bool, draining := false) -> void:
	if pouring:
		var cell: int = sim.tip_cell()
		var flavour := int(sim.pots[sim.picked].flavour)
		var into: Dictionary = _cell_pots.get(cell, {})
		var mixing := not into.is_empty() and not (into.size() == 1 and into.has(flavour))
		into[flavour] = true
		_cell_pots[cell] = into
		if mixing and _clock - _mix_at >= MIX_GAP:
			_mix_at = _clock
			_fx.cue("mix", randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY))
	if _pour_snd == null:
		return
	# the same loop runs for a drain, slower and lower: the syrup drawn out
	var want := POUR_TOP if (pouring or draining) and not held else 0.0
	var now := db_to_linear(_pour_snd.volume_db)
	now = move_toward(now, want, delta * POUR_TOP / (POUR_IN if want > now else POUR_OUT))
	_pour_snd.volume_db = linear_to_db(maxf(now, 0.0001))
	if now > 0.002 and not _pour_snd.playing:
		_pour_snd.pitch_scale = randf_range(0.97, 1.03) * (DRAIN_PITCH if draining else 1.0)
		_pour_snd.play(randf() * 2.0)
	elif now <= 0.002 and _pour_snd.playing:
		_pour_snd.stop()

# --- the fingers ---

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position)
		else:
			_release(touch.index, touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_drag(drag.index, drag.relative)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var click := event as InputEventMouseButton
		if click.pressed:
			_press(-2, click.position)
		else:
			_release(-2, click.position)
	elif event is InputEventMouseMotion:
		_drag(-2, (event as InputEventMouseMotion).relative)

func _busy() -> bool:
	return sim == null or held or won or sim.phase > Sim.Phase.PLAY

func _press(index: int, at: Vector2) -> void:
	if _busy():
		return
	if at.distance_to(_squeeze_at) <= _squeeze_r + 14.0:
		if _squeeze_by == -1:
			_squeeze_by = index
			sim.squeeze(true)
			# in the jelly the first of the syrup is heard; over the tray
			# nothing comes and the button only clicks
			if sim.tip_cell() >= 0:
				_fx.cue("drop", randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY))
			else:
				_fx.touch(randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY))
			_fx.buzz(Haptics.TAP)
		return
	if at.distance_to(_drain_at) <= _drain_r + 14.0:
		if _drain_by == -1:
			_drain_by = index
			sim.drain(true)
			_fx.touch(randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY) * DRAIN_PITCH)
			_fx.buzz(Haptics.TAP)
		return
	if at.distance_to(_serve_at) <= _serve_r + 14.0:
		_serve_down = _clock
		_fx.buzz(Haptics.TAP)
		if sim.can_serve():
			sim.serve()
		else:
			# nothing in the mould yet: the button answers and says why
			_fx.touch(0.94)
			_rw.sticker(tr("GD_NOTHING_YET"), _rw.at(field, _serve_at + Vector2(60.0, -SERVE_R - 30.0)), 40, 1.3, false, Color("fffaf0"), false, "nothing")
		return
	for i in _pot_at.size():
		var foot: Vector2 = _pot_at[i]
		if Rect2(foot.x - POT_GAP * 0.5, foot.y - Art.JAR_H - 16.0, POT_GAP, Art.JAR_H + 44.0).has_point(at):
			sim.pick(i)
			_pick_at = _clock
			_fx.touch(randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY))
			_fx.buzz(Haptics.TAP)
			return
	if _tray.grow(24.0).has_point(at) and _aim_by == -1:
		_aim_by = index
		_aim_moved = 0.0
		_fx.touch(randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY))
		_fx.buzz(Haptics.TICK)

func _drag(index: int, by: Vector2) -> void:
	if index != _aim_by or _busy():
		return
	_aim_moved += by.length()
	if _aim_moved >= TAP_PX:
		sim.aim(sim.tip + by / _u)

func _release(index: int, at: Vector2) -> void:
	if index == _squeeze_by:
		_squeeze_by = -1
		if sim != null:
			sim.squeeze(false)
	if index == _drain_by:
		_drain_by = -1
		if sim != null:
			sim.drain(false)
	if index == _aim_by:
		_aim_by = -1
		if not _busy() and _aim_moved < TAP_PX:
			sim.aim(to_mould(at))

func _let_go() -> void:
	_aim_by = -1
	_squeeze_by = -1
	_drain_by = -1
	if sim != null:
		sim.squeeze(false)
		sim.drain(false)

# --- events ---

func _play_events() -> void:
	var evs: Array = sim.events.duplicate()
	sim.events.clear()
	for ev: Dictionary in evs:
		match String(ev.type):
			"deal":
				_on_deal()
			"again":
				_on_again()
			"serve":
				_let_go()
				_fx.cue("serve")
			"judge":
				var m: Dictionary = _fluid.measure()
				sim.judge(m.near, m.all)
				# the verdict and the day's end are this frame's too
				evs.append_array(sim.events)
				sim.events.clear()
			"served":
				_on_served(ev)
		happened.emit(ev)

func _on_deal() -> void:
	_deal_at = _clock
	_slid = sim.index > 0
	_cell_pots.clear()
	_fluid.lay(sim.mould)
	_tip = sim.tip
	_tip_was = sim.tip
	_bits.clear()
	_place()
	if sim.index > 0:
		_fx.cue("deal")
		_feel(Haptics.TICK)

## The mould on the tray is clear again: one under its mark, or Reset.
func _on_again() -> void:
	_cell_pots.clear()
	_fluid.lay(sim.mould)
	_tip = sim.tip
	_tip_was = sim.tip
	_bits.clear()
	_verdict_at = -10.0
	_fx.cue("deal", 0.94)
	_feel(Haptics.TICK)

func _on_served(ev: Dictionary) -> void:
	_verdict_at = _clock
	var pct := int(ev.pct)
	var at := _rw.at(field, _tray.get_center())
	if bool(ev.perfect) and bool(ev["pass"]):
		_wobble = 0.09
		_fx.cue("perfect")
		_feel(Haptics.GOOD)
		_rw.sticker("%d%%" % pct, at, 110, 1.9, true, Color.WHITE, true, "pct")
		_rw.sticker(tr("GD_PERFECT"), at + Vector2(0, 110.0), 54, 1.9, false, Color("fff4c2"), false, "word")
		_rw.rain(1.6, ["confetti", "star"], Rewards.CONFETTI)
	elif bool(ev["pass"]):
		_wobble = 0.06
		_fx.cue("good", minf(1.0 + 0.04 * sim.index, CLIMB_TOP))
		_feel(Haptics.GOOD)
		_rw.sticker("%d%%" % pct, at, 100, 1.9, false, Color("fffaf0"), true, "pct")
		_rw.sticker(tr("GD_GOOD"), at + Vector2(0, 104.0), 50, 1.9, false, Color("fff4c2"), false, "word")
	else:
		_wobble = 0.03
		_fx.cue("flop")
		_feel(Haptics.BAD)
		_rw.sticker("%d%%" % pct, at, 100, 2.2, false, Color("fffaf0"), false, "pct")
		_rw.sticker(tr("GD_NEEDED") % int(ev.need), at + Vector2(0, 104.0), 46, 2.2, false, Color("ffd9c2"), false, "word")

func _ring(at: Vector2, r: float, life: float, col: Color, inward := false) -> void:
	if Motion.reduce:
		return
	_bits.append({"pos": at, "t": 0.0, "life": life, "r": r, "col": col, "in": inward})

func _refresh_hud() -> void:
	if sim == null:
		return
	# the number is told only once the mould is served: a ? until then
	var pct := int(sim.verdict.get("pct", -1)) if sim.phase >= Sim.Phase.SHOW else -1
	if pct == _shown_match and sim.index == _shown_index and not won:
		return
	_shown_match = pct
	_shown_index = sim.index
	_match_l.text = "?" if pct < 0 else "%d%%" % pct
	# over the mark the number is the leaf's green, under it the ink
	_match_l.add_theme_color_override("font_color", Pal.LEAF_DEEP if pct >= sim.mark() else Art.INK)
	_need_l.text = tr("GD_NEED") % sim.mark()
	if sim.moulds.size() > 1:
		_need_l.text += "  ·  %d/%d" % [sim.index + 1, sim.moulds.size()]
	# the card's two lines go with the card on the win
	_match_l.modulate.a = 1.0 - _win_k()
	_need_l.modulate.a = _match_l.modulate.a
	if won and _win_k() < 1.0:
		_shown_match = -2

# --- drawing ---

func _meshes() -> void:
	if sim == null:
		return
	if _built_u == _u and is_same(_built_for, sim.mould) and _floor != null:
		return
	_built_u = _u
	_built_for = sim.mould
	_floor = Art.floor_of(sim.mould, _u)
	_walls = Art.gloss_of(sim.mould, _u)
	_picture = Art.picture(sim.mould, (CARD.y - 36.0) / Mould.SIDE)

func _draw_field() -> void:
	if _table == null:
		_layout_field()
	if _table == null:
		return
	field.draw_mesh(_table, null)
	if sim == null:
		return
	_meshes()
	var xf := _group()
	field.draw_mesh(Art.tray(_tray.size.x), null, xf)
	field.draw_mesh(_floor, null, xf)

func _draw_syrup() -> void:
	if sim == null or _fluid == null:
		return
	_syrup.draw_set_transform_matrix(_group())
	_syrup.draw_texture_rect(_fluid.texture(), Rect2(Vector2.ZERO, _tray.size), false)

func _draw_top() -> void:
	if sim == null or _walls == null:
		return
	var xf := _group()
	_top.draw_mesh(_walls, null, xf)
	# everything but the tray fades on the win
	var fade := Color(1, 1, 1, 1.0 - _win_k())
	if fade.a <= 0.0:
		_draw_live()
		return
	# the card and its picture
	_top.draw_mesh(Art.card(_card.size), null, Transform2D(-0.012, _card.position), fade)
	_top.draw_mesh(_picture, null, Transform2D(0.0, _card.position + Vector2(18.0, 18.0)), fade)
	# the pots: the picked one stands in its ring, a little nearer
	for i in mini(_pot_at.size(), sim.pots.size()):
		var pot: Dictionary = sim.pots[i]
		var foot: Vector2 = _pot_at[i]
		var on: bool = i == sim.picked
		var sc := 1.0
		if on:
			sc = 1.08
			if not Motion.reduce and _clock - _pick_at < 0.25:
				sc += 0.1 * sin((_clock - _pick_at) / 0.25 * PI)
		var at := Transform2D(0.0, Vector2(sc, sc), 0.0, foot)
		_top.draw_mesh(Art.jar_shadow(), null, at, fade)
		if on:
			_top.draw_mesh(Art.jar_ring(), null, at, fade)
		_top.draw_mesh(Art.syrup(int(pot.flavour), 1.0), null, at, fade)
		_top.draw_mesh(Art.jar(), null, at, fade)
	# the buttons: a pressed one sinks and shades
	var can: bool = sim.can_serve()
	var sd := 0.94 if _clock - _serve_down < 0.12 else 1.0
	_top.draw_mesh(Art.serve_button(_serve_r), null, Transform2D(0.0, Vector2(sd, sd), 0.0, _serve_at),
		fade * Color(1, 1, 1, 1.0 if can else 0.45) * (Color(0.88, 0.88, 0.88) if sd < 1.0 else Color.WHITE))
	var down: bool = _squeeze_by != -1 or sim.squeezing
	var qd := 0.94 if down else 1.0
	var squeeze_xf := Transform2D(0.0, Vector2(qd, qd), 0.0, _squeeze_at)
	_top.draw_mesh(Art.squeeze_button(_squeeze_r), null, squeeze_xf,
		fade * (Color(0.86, 0.86, 0.86) if down else Color.WHITE))
	_draw_meter(squeeze_xf, fade)
	# the drain: greyed while nothing is in the mould to draw out
	var pulling: bool = _drain_by != -1 or sim.draining
	var dd := 0.94 if pulling else 1.0
	_top.draw_mesh(Art.drain_button(_drain_r), null, Transform2D(0.0, Vector2(dd, dd), 0.0, _drain_at),
		fade * Color(1, 1, 1, 1.0 if sim.wet() else 0.45) * (Color(0.86, 0.86, 0.86) if pulling else Color.WHITE))
	_draw_live()
	# the needle over all of it, leaning away to the upper right
	if sim.phase <= Sim.Phase.PLAY and not won:
		var tip := px(_tip)
		var bob := 0.0 if Motion.reduce or sim.squeezing else 3.0 * sin(_clock * 2.4)
		var lean := Transform2D(LEAN, tip + Vector2(0, -bob))
		# the plunger first, so it sinks into the barrel as it is squeezed
		_top.draw_mesh(Art.plunger(DROPPER), null, lean * Transform2D(0.0, Vector2(0, -DROPPER * 0.74 + DROPPER * 0.13 * _squash)))
		_top.draw_mesh(Art.needle(int(sim.pots[sim.picked].flavour), DROPPER), null, lean)

## The meter on the squeeze button: the white rim filled clockwise with
## the chunk's pigments, 100% the card's shade, the number under the drop.
func _draw_meter(xf: Transform2D, fade: Color) -> void:
	if _meter_k <= 0.0:
		return
	var total: float = (_level.x + _level.y + _level.z) / Sim.C_FULL
	var alpha := fade * Color(1, 1, 1, _meter_k)
	_meter = Art.meter(_squeeze_r, _meter_segments(sim.tip_cell(), _level / Sim.C_FULL), total)
	if _meter != null:
		_top.draw_mesh(_meter, null, xf, alpha)
	var font: Font = CozyTheme.display(700)
	var text := "%d%%" % int(round(total * 100.0))
	var fs := int(METER_FONT * _squeeze_r / SQUEEZE_R)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	var at := xf * Vector2(-tw * 0.5, _squeeze_r * 0.62 + font.get_ascent(fs) * 0.35)
	_top.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs,
		(Art.INK if total > 1.0 + Art.METER_SLACK else Color("fffdf8")) * alpha)

## The meter's segments for the chunk: a segment a pot that has gone into
## it, in the order they went in, each the share of the reading its
## flavour's pigment accounts for (the user, 2026-10-14: "if there is
## orange on bucket for example, it should show 100% filled of orange, not
## 50% of yellow and 50% red, the split % is only shown if the slot is
## manual filled with both colors"). A chunk no pot is known to have gone
## into (a tutorial's prefill) shows the one flavour its pigments make, or
## else a segment a pigment, as the pots' shares do when they cannot be
## told apart (cherry, lemon and orange all in one chunk).
func _meter_segments(cell: int, fill: Vector3) -> Array:
	var total := fill.x + fill.y + fill.z
	if total <= 0.0:
		return []
	var pots: Array = _cell_pots.get(cell, {}).keys()
	var shares := _pot_shares(fill, pots)
	var out: Array = []
	if not shares.is_empty():
		for i in pots.size():
			if shares[i] > 0.0:
				out.append([pots[i], shares[i]])
		return out
	var mix := fill / total
	for f in Mould.PIGMENT.size():
		if (mix - (Mould.PIGMENT[f] as Vector3)).length() < 0.04:
			return [[f, total]]
	for i in 3:
		if fill[i] > 0.0:
			out.append([Mould.PRIMARIES[i], fill[i]])
	return out

## How much of `fill` each of these pots' pigments accounts for, least
## squares, no share under nothing and all of them summing to the fill;
## empty when there is no pot or they cannot be told apart.
static func _pot_shares(fill: Vector3, pots: Array) -> PackedFloat32Array:
	var total := fill.x + fill.y + fill.z
	var out := PackedFloat32Array()
	match pots.size():
		1:
			out.append(total)
		2:
			var p1: Vector3 = Mould.PIGMENT[int(pots[0])]
			var p2: Vector3 = Mould.PIGMENT[int(pots[1])]
			var det := p1.dot(p1) * p2.dot(p2) - p1.dot(p2) * p1.dot(p2)
			if det < 1e-6:
				return out
			out.append((fill.dot(p1) * p2.dot(p2) - fill.dot(p2) * p1.dot(p2)) / det)
			out.append((fill.dot(p2) * p1.dot(p1) - fill.dot(p1) * p1.dot(p2)) / det)
		3:
			var m := Basis(Mould.PIGMENT[int(pots[0])], Mould.PIGMENT[int(pots[1])], Mould.PIGMENT[int(pots[2])])
			if absf(m.determinant()) < 1e-6:
				return out
			var a: Vector3 = m.inverse() * fill
			out.append(a.x)
			out.append(a.y)
			out.append(a.z)
		_:
			return out
	var sum := 0.0
	for i in out.size():
		out[i] = maxf(out[i], 0.0)
		sum += out[i]
	if sum <= 0.0:
		return PackedFloat32Array()
	for i in out.size():
		out[i] *= total / sum
	return out

func _draw_live() -> void:
	if _bits.is_empty():
		return
	var b := Face.Builder.new()
	for bit: Dictionary in _bits:
		var k: float = bit.t / bit.life
		var grow := 1.0 - k if bool(bit.get("in", false)) else k
		var r: float = float(bit.r) * _u * (0.3 + 0.7 * grow)
		b.stroke(Face.Builder.ring(px(bit.pos), r, r), maxf(1.5, 0.9 * _u * (1.0 - k)), Color(bit.col, bit.col.a * (1.0 - k)), true)
	_live = b.mesh()
	if _live != null:
		_top.draw_mesh(_live, null)
