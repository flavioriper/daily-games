extends Control

## Tally's card for one thing on the paper, laid over it by the screen: a
## piece's, from its pill's Info (what it holds, the side a machine has
## waited on, turn it, lift it, empty a crate) or the counting box's (the
## level, the next targets and what each hands over, and the numbers the box
## holds most of). Spec docs/superpowers/specs/2026-10-15-arcade-tally-design.md.

signal closed
signal chose(id: String)

const Sim = preload("res://arcade/tally_sim.gd")
const Art = preload("res://arcade/tally_art.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")

const WIDE := 860.0
const NEXT := 5
const TALLY := 8

var sim: RefCounted
## The square of the piece, or the box's corner for the box's card.
var tile := Vector2i(-1, -1)
var box := false
var _font: Font
var _live: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 8
	_font = CozyTheme.display(700)
	add_child(Dialog.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := Dialog.card(WIDE)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	var kd: int = Sim.BOX if box else sim.kind_at(tile)
	col.add_child(Dialog.head("TL_PIECE_" + String(Sim.KIND_IDS.get(kd, "box")).to_upper(), "help"))
	_live = Control.new()
	_live.custom_minimum_size = Vector2(WIDE - 80, _tall(kd))
	_live.draw.connect(_draw_box if box else _draw_piece)
	col.add_child(_live)
	if not box:
		var line := Label.new()
		line.text = "TL_PIECE_%s_LINE" % String(Sim.KIND_IDS[kd]).to_upper()
		line.theme_type_variation = "CardBlurb"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = WIDE - 120
		col.add_child(line)
	var first: Button
	var second: Button
	if Sim.is_op(kd):
		first = Dialog.primary("turn", tr("TL_TURN"))
		first.pressed.connect(func() -> void: chose.emit("turn"))
		second = Dialog.secondary("bin", tr("TL_LIFT"))
		second.pressed.connect(_pick.bind("lift"))
	elif kd == Sim.CRATE:
		first = Dialog.primary("check", tr("TL_DONE"))
		first.pressed.connect(_pick.bind(""))
		second = Dialog.secondary("bin", tr("TL_EMPTY"))
		second.pressed.connect(func() -> void:
			chose.emit("empty")
			_live.queue_redraw())
	elif kd == Sim.BOX:
		first = Dialog.primary("check", tr("TL_DONE"))
		first.pressed.connect(_pick.bind(""))
	else:
		first = Dialog.primary("check", tr("TL_DONE"))
		first.pressed.connect(_pick.bind(""))
		second = Dialog.secondary("bin", tr("TL_LIFT"))
		second.pressed.connect(_pick.bind("lift"))
	Dialog.buttons(col, first, second)
	if not Motion.reduce:
		card.pivot_offset = Vector2(WIDE * 0.5, 300)
		card.scale = Vector2.ONE * 0.9
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

func _tall(kd: int) -> float:
	if kd == Sim.BOX:
		return 150.0 + NEXT * 62.0 + 64.0 + ceilf(TALLY / 4.0) * 80.0
	if Sim.is_op(kd):
		return 270.0
	return 230.0

func _pick(id: String) -> void:
	if id != "":
		chose.emit(id)
	closed.emit()
	queue_free()

func _process(_delta: float) -> void:
	# what a machine holds changes as it works
	if _live != null:
		_live.queue_redraw()

func _text(c: Control, s: String, at: Vector2, fs: int, col: Color, centre := false) -> void:
	var x := at.x
	if centre:
		x -= _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5
	c.draw_string(_font, Vector2(x, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _token(c: Control, v: int, at: Vector2, sc := 1.0) -> void:
	c.draw_mesh(Art.token(v == sim.target()), null, Transform2D(0.0, Vector2.ONE * sc, 0.0, at))
	var txt := Sim.short(v)
	var fs := int((30 if txt.length() <= 2 else (25 if txt.length() == 3 else 20)) * sc)
	_text(c, txt, at + Vector2(0, fs * 0.36 - 2.0), fs, Art.INK, true)

## A row of tokens from `x`, at most `most`.
func _tokens(c: Control, q: Array, at: Vector2, most := 4) -> void:
	if q.is_empty():
		_text(c, "–", at + Vector2(0, 10), 30, Pal.TEXT_DIM)
		return
	for j in mini(q.size(), most):
		_token(c, int(q[j]), at + Vector2(j * 70.0, 0), 1.0)

func _draw_piece() -> void:
	var c := _live
	var kd: int = sim.kind_at(tile)
	var i := Sim._i(tile)
	var at := Vector2(100, 110)
	var rot := int(sim.face[i]) * PI * 0.5 if Sim.is_op(kd) else 0.0
	var m: ArrayMesh = Art.machine(kd) if Sim.is_op(kd) else Art.icon(kd)
	c.draw_mesh(m, null, Transform2D(rot, Vector2.ONE * 1.5, 0.0, at))
	var x := 240.0
	if Sim.is_op(kd):
		if not sim.machines.has(i):
			return
		var mm: Dictionary = sim.machines[i]
		_text(c, tr("TL_SIDE_A"), Vector2(x, 50), 26, Pal.TEXT_DIM)
		_tokens(c, mm.a, Vector2(x + 110, 40))
		_text(c, tr("TL_SIDE_B"), Vector2(x, 130), 26, Pal.TEXT_DIM)
		_tokens(c, mm.b, Vector2(x + 110, 120))
		var made := tr("TL_MAKES") % (Sim.short(int(mm.last)) if bool(mm.has_last) else "–")
		_text(c, made, Vector2(x, 205), 28, Pal.TEXT)
		_text(c, tr("TL_PER_S") % String.num(sim.op_speed(kd), 2).trim_suffix("0").trim_suffix("."), Vector2(x + 380, 205), 26, Pal.TEXT_DIM)
		# a side it has waited on: said in amber, as the board shows its pips
		var side: int = sim.starving(i)
		if side >= 0:
			var waiting := tr("TL_WAITING_SIDE") % [tr("TL_SIDE_A" if side == 0 else "TL_SIDE_B"), tr("TL_SIDE_ONE_DOT" if side == 0 else "TL_SIDE_TWO_DOT")]
			_text(c, waiting, Vector2(x, 250), 26, Art.AMBER.darkened(0.2))
	elif kd == Sim.DIG:
		var v := int(sim.dep[i])
		_token(c, v, Vector2(x + 40, 70), 1.2)
		var n := (sim.digs[i].outs as PackedInt32Array).size() if sim.digs.has(i) else 0
		_text(c, tr("TL_DIG_BELTS") % [n, sim.dig_belts()], Vector2(x + 100, 80), 30, Pal.TEXT)
		_text(c, tr("TL_PER_S") % String.num(mini(n, sim.dig_belts()) * sim.belt_speed(), 1).trim_suffix(".0"), Vector2(x, 170), 28, Pal.TEXT_DIM)
	elif kd == Sim.CRATE:
		var cr: Dictionary = sim.crates.get(i, {"v": 0, "n": 0})
		if int(cr.n) > 0:
			_token(c, int(cr.v), Vector2(x + 40, 80), 1.2)
		_text(c, tr("TL_CRATE_HOLDS") % [int(cr.n), Sim.CRATE_MAX], Vector2(x + 100, 90), 30, Pal.TEXT)

func _draw_box() -> void:
	var c := _live
	var w := c.size.x
	_text(c, tr("TL_LEVEL") % sim.level, Vector2(0, 40), 30, Pal.ACCENT_2)
	_token(c, sim.target(), Vector2(60, 100), 1.3)
	_text(c, tr("TL_BOX_ASKS") % [Sim.short(sim.got), Sim.short(sim.count())], Vector2(130, 112), 34, Pal.TEXT)
	var y := 180.0
	_text(c, tr("TL_NEXT"), Vector2(0, y), 24, Pal.TEXT_DIM)
	y += 20.0
	for j in NEXT:
		var n: int = sim.level + j
		var row_y := y + j * 62.0 + 31.0
		_text(c, tr("TL_LEVEL") % n, Vector2(0, row_y + 10), 26, Pal.TEXT_DIM)
		_token(c, sim.target_of(n), Vector2(200, row_y), 0.8)
		_text(c, "× " + Sim.short(sim.count_of(n)), Vector2(240, row_y + 10), 26, Pal.TEXT)
		var r: int = sim.reward_of(n)
		if r != 0:
			var what := tr("TL_GIVES_DIG") % -r if r < 0 else tr("TL_GIVES") % tr("TL_PIECE_" + String(Sim.KIND_IDS[r]).to_upper())
			_text(c, what, Vector2(w - 20, row_y + 10) - Vector2(_font.get_string_size(what, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x, 0), 26, Pal.ACCENT_DEEP)
	y += NEXT * 62.0 + 40.0
	_text(c, tr("TL_HELD"), Vector2(0, y), 24, Pal.TEXT_DIM)
	var rows: Array = sim.tally_rows(TALLY)
	if rows.is_empty():
		_text(c, "–", Vector2(0, y + 50), 30, Pal.TEXT_DIM)
	for j in rows.size():
		var at := Vector2(50 + (j % 4) * (w / 4.0), y + 50 + int(j / 4) * 80.0)
		_token(c, int(rows[j][0]), at, 0.8)
		_text(c, "× " + Sim.short(int(rows[j][1])), at + Vector2(36, 10), 24, Pal.TEXT)
