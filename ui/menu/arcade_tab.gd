extends VBoxContainer

## The Arcade tab: games played alone for a score rather than against the
## day's board or against someone: Firefly (arcade/firefly_screen.gd) and
## Hedgerow (arcade/hedgerow_screen.gd). Its body takes the day
## row's and the grid's room, as Versus, Stats and Streak do. Molehill
## (arcade/molehill_screen.gd) is the third.
##
## One card a game: the game's own cast lying across a painted banner (still,
## drawn once), the name and the best score, a line, and the best stage
## beside Play. A short screen gives up the line and then some of the
## picture before it would push the bar off (_fit, the Versus tab's rule).

signal play(game: String)

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const SunDot = preload("res://ui/sun_dot.gd")
const Record = preload("res://arcade/arcade_record.gd")
const Art = preload("res://arcade/firefly_art.gd")
const HedgeArt = preload("res://arcade/hedgerow_art.gd")
const HedgeSim = preload("res://arcade/hedgerow_sim.gd")
const Face = preload("res://ui/faces/face.gd")
const MoleArt = preload("res://arcade/molehill_art.gd")

const GAP := 20
const PAD := 24
const RADIUS := 36
const ART_H := 260.0
const ART_H_SHORT := 150.0
const CHIP_H := 84
const GAMES := ["firefly", "hedgerow", "molehill"]
const NAMES := {"firefly": "Firefly", "hedgerow": "Hedgerow TD", "molehill": "Molehill"}
const BLURBS := {"firefly": "ARC_FIREFLY_BLURB", "hedgerow": "ARC_HEDGEROW_BLURB", "molehill": "ARC_MOLEHILL_BLURB"}
## How far a game went, in its own words: a stage, a wave, or a streak.
const FURTHEST := {"firefly": "ARC_BEST_STAGE", "hedgerow": "ARC_BEST_WAVE", "molehill": "ARC_BEST_STREAK"}
const PLATE_TINT := {"firefly": Pal.MOON_INK, "hedgerow": Pal.LEAF_DEEP, "molehill": Pal.LEAF_DEEP}
const FILL := Color("fcf7ef")
static var PLAIN := CanvasItemMaterial.new()

var _best := {}
var _stage := {}
var _blurbs: Array[Label] = []
var _arts: Array[Control] = []

func _init() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for game: String in GAMES:
		add_child(_game_card(game))

func _game_card(game: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CozyTheme.lifted(FILL, RADIUS, PAD))
	card.material = PLAIN
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(col)
	var art := Vistas.card_plate(game, PLATE_TINT[game])
	art.custom_minimum_size.y = ART_H
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.clip_contents = true
	col.add_child(art)
	_arts.append(art)
	var swarm: Control = {"firefly": FireflyBanner, "hedgerow": HedgerowBanner, "molehill": MolehillBanner}[game].new()
	swarm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.add_child(swarm)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	var name_l := Label.new()
	name_l.text = NAMES[game]
	name_l.theme_type_variation = "CardName"
	head.add_child(name_l)
	name_l.add_child(SunDot.new(name_l))
	var best := Label.new()
	best.theme_type_variation = "CardBlurb"
	best.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	best.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(best)
	_best[game] = best
	var blurb := Label.new()
	blurb.text = BLURBS[game]
	blurb.theme_type_variation = "CardBlurb"
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(blurb)
	_blurbs.append(blurb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var stage := Label.new()
	stage.theme_type_variation = "CardBlurb"
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(stage)
	_stage[game] = stage
	var go := IconButton.new("chevron_right", tr("VS_PLAY"), "SunButton")
	go.name = "Play_" + game
	go.custom_minimum_size = Vector2(300, CHIP_H)
	go.pressed.connect(func() -> void: play.emit(game))
	row.add_child(go)
	return card

func refresh() -> void:
	for game: String in GAMES:
		var best := Record.best(game)
		(_best[game] as Label).text = tr("ARC_BEST") % Record.grouped(best) if best > 0 else tr("ARC_NO_BEST")
		var st := Record.best_stage(game)
		(_stage[game] as Label).text = tr(FURTHEST[game]) % st if st > 0 else ""
	_fit.call_deferred()

func _ready() -> void:
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _fit.call_deferred())
	var outer := _outer()
	if outer != null:
		outer.resized.connect(_fit)
	# A wrapped line measures its height off its width, which is not known
	# until the cards are laid out, so the fit runs again once they are.
	resized.connect(func() -> void: _fit.call_deferred())

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_fit.call_deferred()

func _outer() -> Control:
	var parent := get_parent()
	if parent != null and parent.get_parent() is MarginContainer:
		return parent.get_parent().get_parent() as Control
	return null

## The Versus tab's fit: whole if the cards fit, else without the lines,
## else with shorter pictures too.
func _fit() -> void:
	var parent := get_parent() as Control
	if parent == null or not is_visible_in_tree():
		return
	var sep := parent.get_theme_constant("separation") if parent is BoxContainer else 0
	var other := 0.0
	var shown := 0
	for c in parent.get_children():
		if c is Control and c != self and (c as Control).visible and not (c as Control).top_level:
			other += (c as Control).get_combined_minimum_size().y
			shown += 1
	var height := parent.size.y
	var outer := _outer()
	if outer != null:
		var margins := parent.get_parent() as MarginContainer
		height = outer.size.y - margins.get_theme_constant("margin_top") - margins.get_theme_constant("margin_bottom")
	var room := height - other - sep * shown
	# The lines are measured off the font at the column's width rather than
	# read off the labels: a wrapped label hidden before its first layout
	# has no width, and measures thousands of pixels tall.
	_compact(1)
	var bare := get_combined_minimum_size().y
	var lines := 0.0
	for b in _blurbs:
		var holder := b.get_parent() as Control
		var font := b.get_theme_font("font")
		var fs := b.get_theme_font_size("font_size")
		var w := holder.size.x if holder != null and holder.size.x > 0.0 else size.x - PAD * 2
		lines += font.get_multiline_string_size(tr(b.text), HORIZONTAL_ALIGNMENT_LEFT, w, fs).y
		lines += (holder as BoxContainer).get_theme_constant("separation") if holder is BoxContainer else 0
	if bare + lines <= room:
		_compact(0)
	elif bare > room:
		_compact(2)

func _compact(level: int) -> void:
	for b in _blurbs:
		b.visible = level == 0
	for a in _arts:
		a.custom_minimum_size.y = ART_H_SHORT if level >= 2 else ART_H

## Firefly's banner: a strip of the swarm in its rows over the night plate,
## a moth diving with its beam half open, and the firefly under them with a
## spark on its way up. Drawn once.
class FireflyBanner extends Control:
	var _keep: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		_keep.clear()
		var u := minf(size.y / 60.0, size.x / 150.0)
		var mid := size.x * 0.5
		var b := Face.Builder.new()
		# the night laid over the plate, so the cast reads
		b.fan(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), Color(0.11, 0.12, 0.28, 0.45))
		var rng := RandomNumberGenerator.new()
		rng.seed = 4
		for i in 40:
			b.disc(Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(1.0, 2.6), Color(1.0, 0.96, 0.8, rng.randf_range(0.3, 0.8)))
		# the beam from the diving moth down toward the firefly
		var moth_at := Vector2(mid + 30.0 * u, size.y * 0.52)
		var fly_at := Vector2(mid - 18.0 * u, size.y - 9.0 * u)
		b.fan(PackedVector2Array([moth_at + Vector2(-3 * u, 6 * u), moth_at + Vector2(3 * u, 6 * u),
			Vector2(moth_at.x + 12 * u, size.y), Vector2(moth_at.x - 12 * u, size.y)]), Color(0.85, 0.86, 1.0, 0.16))
		# the spark
		var spark := fly_at + Vector2(0, -16 * u)
		b.ellipse(spark, 2.2 * u, 3.6 * u, Color(Art.GLOW, 0.25))
		b.ellipse(spark, 0.9 * u, 2.4 * u, Color("fff1a8"))
		var ground := b.mesh()
		_keep.append(ground)
		draw_mesh(ground, null)
		var rows := [[Art.Look.MOTH, [-1.5, -0.5, 0.5, 1.5], 0.0], [Art.Look.BEETLE, [-3.5, -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 3.5], 0.0],
			[Art.Look.GNAT, [-4.5, -3.5, -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 3.5, 4.5], 1.0]]
		var top := 10.0 * u
		for r in rows.size():
			var row: Array = rows[r]
			for x: float in row[1]:
				if row[0] == Art.Look.MOTH and x == 1.5:
					continue
				var at := Vector2(mid + x * 14.0 * u, top + r * 12.0 * u)
				_put(row[0], int(x * 2.0 + r) % 2, u, Transform2D(PI, at))
		_put(Art.Look.MOTH, 1, u, Transform2D(PI * 1.1, moth_at))
		_put(Art.Look.FIREFLY, 0, u, Transform2D(0.0, fly_at))

	func _put(look: int, frame: int, u: float, xf: Transform2D) -> void:
		var m := Art.mesh(look, frame, u)
		draw_mesh(m, null, xf)

## Hedgerow TD's banner: a strip of lawn with a cobbled path winding between towers,
## pests coming down it in their elements' colours. Drawn once.
class HedgerowBanner extends Control:
	var _keep: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		_keep.clear()
		var u := minf(size.y / 2.6, size.x / 7.5)
		var mid := size * 0.5
		var b := Face.Builder.new()
		# the lawn, and a cobbled path snaking across it
		var lawn := Vector2(u * 7.2, u * 2.3)
		var at := mid - lawn * 0.5
		b.fan(Face.Builder.round_rect(at - Vector2(5, 5), lawn + Vector2(10, 10), 16.0), Color("7fa84a", 0.9))
		b.fan(Face.Builder.round_rect(at, lawn, 12.0), Color("9cc46a", 0.95))
		var walk := PackedVector2Array()
		for i in 25:
			var x := at.x + lawn.x * i / 24.0
			walk.append(Vector2(x, mid.y + sin(i / 24.0 * TAU * 1.5) * u * 0.62))
		b.stroke(walk, u * 0.58, Color("8c8475"))
		b.stroke(walk, u * 0.48, Color("c9bea9"))
		for i in range(walk.size() - 1):
			for k in 3:
				var q := walk[i].lerp(walk[i + 1], k / 3.0) + Vector2(0, ((i + k) % 3 - 1) * u * 0.12)
				b.disc(q, u * 0.07, Color("ddd3bf") if (i + k) % 2 else Color("b3a78f"))
		var mesh := b.mesh()
		_keep.append(mesh)
		draw_mesh(mesh, null)
		# towers above and below the walk
		var spots := [[0.12, -1, "thorn", 1], [0.3, 1, "sun", 1], [0.47, -1, "acorn", 0], [0.63, 1, "lightning", 1], [0.82, -1, "rain", 2]]
		for sp: Array in spots:
			var x: float = at.x + lawn.x * sp[0]
			var y: float = mid.y + sin(float(sp[0]) * TAU * 1.5) * u * 0.62 + float(sp[1]) * u * 0.78
			draw_mesh(HedgeArt.tower(sp[2], sp[3], u * 0.9), null, Transform2D(0.0, Vector2(x, y)))
		# pests on the walk, each in its element
		var pests := [[0.05, HedgeSim.Kind.APHID, HedgeSim.El.RAIN], [0.2, HedgeSim.Kind.ANT, HedgeSim.El.EMBER],
			[0.39, HedgeSim.Kind.BEETLE, HedgeSim.El.LEAF], [0.55, HedgeSim.Kind.SLUG, HedgeSim.El.SUN], [0.72, HedgeSim.Kind.BOSS, HedgeSim.El.SHADE]]
		for pe: Array in pests:
			var f: float = pe[0]
			var p := Vector2(at.x + lawn.x * f, mid.y + sin(f * TAU * 1.5) * u * 0.62)
			var ahead := Vector2(at.x + lawn.x * (f + 0.01), mid.y + sin((f + 0.01) * TAU * 1.5) * u * 0.62)
			var rot := (ahead - p).angle() + PI * 0.5
			draw_mesh(HedgeArt.creep(pe[1], pe[2], 0, u * (0.45 if pe[1] == HedgeSim.Kind.BOSS else 0.62)), null, Transform2D(rot, p))

## Molehill's banner: three mounds on a strip of lawn, a mole up in the
## middle one with the mallet coming down on it, a golden one peeking out
## and the rabbit at the end. Drawn once.
class MolehillBanner extends Control:
	var _keep: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		_keep.clear()
		var u := minf(size.y / 95.0, size.x / 260.0)
		var foot := size.y * 0.8
		var xs := [size.x * 0.5 - 90.0 * u, size.x * 0.5, size.x * 0.5 + 90.0 * u]
		var looks := [MoleArt.Look.GOLD, MoleArt.Look.MOLE_DIZZY, MoleArt.Look.BUNNY]
		var rises := [0.8, 1.0, 1.0]
		var back := Face.Builder.new()
		back.fan(PackedVector2Array([Vector2(0, foot - 22.0 * u), Vector2(size.x, foot - 22.0 * u), size, Vector2(0, size.y)]), Color("a9cf78", 0.9))
		for x: float in xs:
			MoleArt.mound_back(back, Vector2(x, foot), u)
		var bm := back.mesh()
		_keep.append(bm)
		draw_mesh(bm, null)
		var front := Face.Builder.new()
		for x: float in xs:
			MoleArt.mound_front(front, Vector2(x, foot), u)
		var fm := front.mesh()
		_keep.append(fm)
		for k in 3:
			# the part of each creature below the hole's mouth is under the lip
			var drop: float = (1.0 - rises[k]) * 60.0 * u
			draw_mesh(MoleArt.mesh(looks[k], u), null, Transform2D(0.0, Vector2(xs[k], foot + drop)))
		draw_mesh(fm, null)
		# the mallet, just landed on the middle mole's head
		var head := Vector2(xs[1], foot - 50.0 * u)
		var hand := head - Vector2(0, -MoleArt.HEAD_AT * u).rotated(-0.55)
		draw_mesh(MoleArt.mallet(u), null, Transform2D(-0.55, hand))
