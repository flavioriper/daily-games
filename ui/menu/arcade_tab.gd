extends VBoxContainer

## The Arcade tab: games played alone for a score rather than against the
## day's board or against someone: Firefly (arcade/firefly_screen.gd) and
## Hedgerow (arcade/hedgerow_screen.gd). Its body takes the day
## row's and the grid's room, as Versus, Stats and Streak do. Molehill
## (arcade/molehill_screen.gd) is the third, Henhouse
## (arcade/henhouse_screen.gd) the fourth, whose best is a time, and
## Millstream (arcade/millstream_screen.gd) the fifth, a small factory, and
## Stackwood (arcade/stackwood_screen.gd) the sixth, falling blocks that merge,
## and Lucky Thirteen (arcade/thirteen_screen.gd) the seventh, chains of
## pebbles merged up to 13.
##
## One card a game: the game's own cast lying across a painted banner (still,
## drawn once), the name and the best score, a line, and the best stage
## beside Play. A short screen gives up the line and then some of the
## picture before it would push the bar off (_fit, the Versus tab's rule),
## and past that stands the cards two a row.

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
const HenArt = preload("res://arcade/henhouse_art.gd")
const MillArt = preload("res://arcade/millstream_art.gd")
const MillSim = preload("res://arcade/millstream_sim.gd")
const StackArt = preload("res://arcade/stackwood_art.gd")
const PebbleArt = preload("res://arcade/thirteen_art.gd")

const GAP := 20
const PAD := 24
const RADIUS := 36
const ART_H := 260.0
const ART_H_SHORT := 150.0
const ART_H_TINY := 104.0
const CHIP_H := 84
const GAMES := ["firefly", "hedgerow", "molehill", "henhouse", "millstream", "stackwood", "thirteen"]
const NAMES := {"firefly": "Firefly", "hedgerow": "Hedgerow TD", "molehill": "Molehill", "henhouse": "Henhouse", "millstream": "Millstream", "stackwood": "Stackwood", "thirteen": "Lucky Thirteen"}
const BLURBS := {"firefly": "ARC_FIREFLY_BLURB", "hedgerow": "ARC_HEDGEROW_BLURB", "molehill": "ARC_MOLEHILL_BLURB", "henhouse": "ARC_HENHOUSE_BLURB", "millstream": "ARC_MILLSTREAM_BLURB", "stackwood": "ARC_STACKWOOD_BLURB", "thirteen": "ARC_THIRTEEN_BLURB"}
## Games whose best is the quickest time rather than the highest score.
const TIMED := ["henhouse", "millstream"]
## What a timed game says before its first finish.
const NO_TIME := {"henhouse": "ARC_NOT_RETIRED", "millstream": "ARC_NOT_BUILT"}
## How far a game went, in its own words: a stage, a wave, or a streak.
const FURTHEST := {"firefly": "ARC_BEST_STAGE", "hedgerow": "ARC_BEST_WAVE", "molehill": "ARC_BEST_STREAK", "henhouse": "ARC_BEST_FLOCK", "millstream": "ARC_BEST_MILESTONE", "stackwood": "ARC_BEST_BLOCK", "thirteen": "ARC_BEST_NUMBER"}
const PLATE_TINT := {"firefly": Pal.MOON_INK, "hedgerow": Pal.LEAF_DEEP, "molehill": Pal.LEAF_DEEP, "henhouse": Pal.LEAF_DEEP, "millstream": Pal.LEAF_DEEP, "stackwood": Pal.LEAF_DEEP, "thirteen": Pal.LEAF_DEEP}
const FILL := Color("fcf7ef")
static var PLAIN := CanvasItemMaterial.new()

var _best := {}
var _stage := {}
var _blurbs: Array[Label] = []
var _arts: Array[Control] = []
var _cards: Array[Control] = []
var _goes: Array = []
## Two cards a row: six cards do not fit one above another on a phone even
## with the smallest pictures, so a short screen pairs them up.
var _paired := false

func _init() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for game: String in GAMES:
		_cards.append(_game_card(game))
	_rows(false)

## Lays the cards out one a row, or two.
func _rows(paired: bool) -> void:
	_paired = paired
	for c in _cards:
		if c.get_parent() != null:
			c.get_parent().remove_child(c)
	for r in get_children():
		remove_child(r)
		r.queue_free()
	var per := 2 if paired else 1
	var i := 0
	while i < _cards.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", GAP)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		for k in per:
			if i < _cards.size():
				_cards[i].size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(_cards[i])
			i += 1
	# paired, Play loses its word and the furthest line goes, to leave the
	# name its room
	for g: Array in _goes:
		(g[0] as Control).custom_minimum_size.x = 110 if paired else 260
		g[0].set_label("" if paired else tr("VS_PLAY"))
		(_stage[g[1]] as Label).visible = not paired

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
	var swarm: Control = {"firefly": FireflyBanner, "hedgerow": HedgerowBanner, "molehill": MolehillBanner, "henhouse": HenhouseBanner, "millstream": MillstreamBanner, "stackwood": StackwoodBanner, "thirteen": ThirteenBanner}[game].new()
	swarm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.add_child(swarm)

	# The name with the best under it, and Play beside them: one row, so
	# four cards stand on a phone.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(words)
	var name_l := Label.new()
	name_l.text = NAMES[game]
	name_l.theme_type_variation = "CardName"
	words.add_child(name_l)
	name_l.add_child(SunDot.new(name_l))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	words.add_child(line)
	var best := Label.new()
	best.theme_type_variation = "CardBlurb"
	line.add_child(best)
	_best[game] = best
	var stage := Label.new()
	stage.theme_type_variation = "CardBlurb"
	stage.modulate.a = 0.8
	line.add_child(stage)
	_stage[game] = stage
	var go := IconButton.new("chevron_right", tr("VS_PLAY"), "SunButton")
	go.name = "Play_" + game
	go.custom_minimum_size = Vector2(260, CHIP_H)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func() -> void: play.emit(game))
	head.add_child(go)
	_goes.append([go, game])
	var blurb := Label.new()
	blurb.text = BLURBS[game]
	blurb.theme_type_variation = "CardBlurb"
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(blurb)
	_blurbs.append(blurb)
	return card

func refresh() -> void:
	for game: String in GAMES:
		var best := Record.best(game)
		var shown := "%d:%02d" % [best / 60, best % 60] if game in TIMED else Record.grouped(best)
		(_best[game] as Label).text = tr("ARC_BEST") % shown if best > 0 else tr(NO_TIME.get(game, "ARC_NO_BEST"))
		var st := Record.best_stage(game)
		(_stage[game] as Label).text = "· " + tr(FURTHEST[game]) % st if st > 0 else ""
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
## else with shorter pictures too, else two cards a row (six do not stand
## one above another on a phone).
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
	var bare := _need(false)
	var lines := 0.0
	for b in _blurbs:
		var holder := b.get_parent() as Control
		var font := b.get_theme_font("font")
		var fs := b.get_theme_font_size("font_size")
		var w := holder.size.x if holder != null and holder.size.x > 0.0 and not _paired else size.x - PAD * 2
		lines += font.get_multiline_string_size(tr(b.text), HORIZONTAL_ALIGNMENT_LEFT, w, fs).y
		lines += (holder as BoxContainer).get_theme_constant("separation") if holder is BoxContainer else 0
	var paired := false
	if bare + lines <= room:
		_compact(0)
	elif bare > room:
		_compact(2)
		if _need(false) > room:
			_compact(3)
			if _need(false) > room:
				# one a row will not fit: two a row, with the taller pictures
				# back if they fit
				paired = true
				_compact(2)
				if _need(true) > room:
					_compact(3)
	if paired != _paired:
		_rows(paired)

## The height the cards want one or two a row, at the pictures' current size.
func _need(paired: bool) -> float:
	var per := 2 if paired else 1
	var total := 0.0
	var i := 0
	var rows := 0
	while i < _cards.size():
		var tall := 0.0
		for k in per:
			if i < _cards.size():
				tall = maxf(tall, _cards[i].get_combined_minimum_size().y)
			i += 1
		total += tall
		rows += 1
	return total + GAP * maxi(0, rows - 1)

func _compact(level: int) -> void:
	for b in _blurbs:
		b.visible = level == 0
	for a in _arts:
		a.custom_minimum_size.y = ART_H_TINY if level >= 3 else (ART_H_SHORT if level >= 2 else ART_H)

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

## Henhouse's banner: a strip of pen with hens in their three plumages, a
## chick, the rooster, eggs in the straw and a boxed one on its way to the
## crate. Drawn once.
class HenhouseBanner extends Control:
	var _keep: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		_keep.clear()
		var u := minf(size.y / 50.0, size.x / 190.0)
		var foot := size.y * 0.8
		var mid := size.x * 0.5
		var b := Face.Builder.new()
		b.fan(PackedVector2Array([Vector2(0, foot - 16.0 * u), Vector2(size.x, foot - 16.0 * u), size, Vector2(0, size.y)]), Color("d8bf8c", 0.8))
		for k in 22:
			var x := size.x * k / 21.0
			b.stroke(PackedVector2Array([Vector2(x, foot - 12.0 * u + (k % 3) * 3.0 * u), Vector2(x + 7.0 * u, foot - 14.0 * u + (k % 2) * 6.0 * u)]), 1.0 * u, Color("ecd08a"))
		# a rail of fence behind them
		for rail in [26.0, 16.0]:
			b.stroke(PackedVector2Array([Vector2(0, foot - rail * u), Vector2(size.x, foot - rail * u)]), 2.4 * u, HenArt.WOOD_DEEP)
		for k in 8:
			var x := size.x * (k + 0.5) / 8.0
			b.fan(Face.Builder.round_rect(Vector2(x - 2.0 * u, foot - 32.0 * u), Vector2(4.0 * u, 20.0 * u), 1.4 * u), HenArt.WOOD)
		for q in [[-40.0, false, false], [-34.0, true, false], [26.0, false, false], [62.0, false, true]]:
			HenArt.egg(b, Vector2(mid + float(q[0]) * u, foot - 4.0 * u), 4.2 * u, q[2], q[1], false, false, false)
		HenArt.egg(b, Vector2(mid + 80.0 * u, foot - 5.0 * u), 4.2 * u, false, false, true, true, true)
		var ground := b.mesh()
		_keep.append(ground)
		draw_mesh(ground, null)
		var cast := [[HenArt.Look.ROOSTER, 0, -62.0, 1.0], [HenArt.Look.HEN, 0, -18.0, 1.0], [HenArt.Look.HEN_PECK, 1, 10.0, -1.0],
			[HenArt.Look.CHICK, 0, 40.0, -1.0], [HenArt.Look.HEN_HAPPY, 2, 50.0 + 20.0, -1.0]]
		for c: Array in cast:
			draw_mesh(HenArt.mesh(c[0], u, c[1]), null, Transform2D(0.0, Vector2(c[3], 1.0), 0.0, Vector2(mid + float(c[2]) * u, foot)))

## Millstream's banner: a strip of the valley -- the stream, the Mill with
## its wheel, a kiln at work and a heap of iron ore. Drawn once.
class MillstreamBanner extends Control:
	var _keep: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		_keep.clear()
		# a strip of grass three and a half tiles tall across the banner, the
		# pieces stood along it: the stream and the Mill, a kiln, a deposit
		var T := MillArt.TILE
		var k := size.y / (3.4 * T)
		var w := size.x / k
		var b := Face.Builder.new()
		b.fan(PackedVector2Array([Vector2(0, 0.6 * T), Vector2(w, 0.6 * T), Vector2(w, 3.4 * T), Vector2(0, 3.4 * T)]), Color(MillArt.GRASS, 0.92))
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for i in int(w / 40.0):
			var p := Vector2(rng.randf() * w, rng.randf_range(0.9, 3.2) * T)
			b.stroke(PackedVector2Array([p, p + Vector2(0, -8)]), 2.4, MillArt.GRASS_DEEP)
		var mid := w * 0.5
		# the stream down the left of the Mill
		var sx := mid - 4.8 * T
		b.fan(PackedVector2Array([Vector2(sx - 0.2 * T, 0.6 * T), Vector2(sx + 1.4 * T, 0.6 * T), Vector2(sx + 1.2 * T, 3.4 * T), Vector2(sx - 0.4 * T, 3.4 * T)]), MillArt.BANK)
		b.fan(PackedVector2Array([Vector2(sx - 0.1 * T, 0.6 * T), Vector2(sx + 1.3 * T, 0.6 * T), Vector2(sx + 1.1 * T, 3.4 * T), Vector2(sx - 0.3 * T, 3.4 * T)]), MillArt.WATER)
		var ground := b.mesh()
		_keep.append(ground)
		draw_mesh(ground, null, Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO))
		# the Mill and its wheel are drawn where the valley has them: moved
		var mill := Face.Builder.new()
		MillArt.wheel(mill, 0.4)
		MillArt.mill(mill)
		var mm := mill.mesh()
		_keep.append(mm)
		var mill_at := Vector2(mid - 3.2 * T, 0.2 * T) - Vector2(MillSim.MILL.position) * T
		draw_mesh(mm, null, Transform2D(0.0, Vector2(k, k), 0.0, mill_at * k))
		var rest := Face.Builder.new()
		var kc := Vector2(mid + 0.6 * T, 0.8 * T)
		MillArt.kiln(rest, kc)
		var mouth := kc + Vector2(T, T) + Vector2(0, 18)
		rest.ellipse(mouth, 16.0, 12.0, MillArt.EMBER)
		rest.ellipse(mouth + Vector2(0, 3), 9.0, 6.0, MillArt.EMBER_HOT)
		for j in 3:
			rest.disc(kc + Vector2(T, T) + Vector2(28.0 + j * 6.0, -84.0 - j * 22.0), 10.0 + j * 5.0, Color(0.93, 0.9, 0.86, 0.55 - j * 0.15))
		for j in 5:
			MillArt.ingot(rest, kc + Vector2(T, T) + Vector2(62 + (j % 2) * 4, 44 - j * 7), 20.0)
		for j in 7:
			MillArt.ore(rest, Vector2(mid + 4.2 * T, 2.2 * T) + Vector2((j % 4) * 20 - 30, -(j / 4) * 16), 14.0)
		var rm := rest.mesh()
		_keep.append(rm)
		draw_mesh(rm, null, Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO))

## Stackwood's banner: a strip of shelf with stacks of numbered blocks on
## it, a pair about to merge and one falling in from above. Drawn once.
class StackwoodBanner extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var s := minf(size.y * 0.3, size.x / 9.0)
		var foot := size.y - s * 0.3
		var mid := size.x * 0.5
		var font := StackArt.font()
		draw_rect(Rect2(Vector2(0, foot), Vector2(size.x, size.y - foot)), StackArt.WOOD_DEEP)
		draw_rect(Rect2(Vector2(0, foot), Vector2(size.x, s * 0.12)), StackArt.WOOD)
		# column by column, bottom up; 0 is the rainbow block
		var stacks := [[16, 4], [64, 8, 2], [128, 32], [8, 8], [256, 64, 0], [32]]
		for k in stacks.size():
			var x := mid + (k - 2.5) * s * 1.04
			var col: Array = stacks[k]
			for i in col.size():
				var c := Vector2(x, foot - s * 0.5 - i * s * 0.96)
				draw_mesh(StackArt.block(col[i], s), null, Transform2D(0.0, c))
				if int(col[i]) > 0:
					StackArt.number(self, font, c, col[i], s)
		# one falling in over the pair of eights, with a trail
		var fx := mid + 0.5 * s * 1.04
		var fy := foot - s * 2.9
		for j in 3:
			draw_rect(Rect2(Vector2(fx - s * 0.06 + (j - 1) * s * 0.22, fy - s * 1.0), Vector2(s * 0.05, s * 0.4)), Color(1, 1, 1, 0.5))
		var fc := Vector2(fx, fy)
		draw_mesh(StackArt.block(8, s), null, Transform2D(0.0, fc))
		StackArt.number(self, font, fc, 8, s)

## Lucky Thirteen's banner: a row of pebbles on raked sand, three sixes
## strung on a chain toward a seven, and the gold thirteen at the end.
## Drawn once.
class ThirteenBanner extends Control:
	var _keep: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		_keep.clear()
		var s := minf(size.y * 0.42, size.x / 8.5)
		var mid := size * Vector2(0.5, 0.56)
		var font := PebbleArt.font()
		var b := Face.Builder.new()
		b.fan(PackedVector2Array([Vector2(0, mid.y - s * 0.8), Vector2(size.x, mid.y - s * 0.8), size, Vector2(0, size.y)]), Color(PebbleArt.SAND, 0.85))
		var y := mid.y - s * 0.6
		while y < size.y:
			var pts := PackedVector2Array()
			for i in 17:
				var t := i / 16.0
				pts.append(Vector2(size.x * t, y + sin(t * TAU * 1.5) * 4.0))
			b.stroke(pts, 2.0, Color(PebbleArt.SAND_DEEP, 0.6))
			y += 16.0
		# the chain through the three sixes
		var row := [3, 6, 6, 6, 9, 13]
		var at: Array = []
		for k in row.size():
			at.append(mid + Vector2((k - 2.5) * s * 1.12, (0.18 if k % 2 == 0 else -0.14) * s))
		var chain := PackedVector2Array([at[1], at[2], at[3]])
		b.stroke(chain, s * 0.26, Color(PebbleArt.paint(6).darkened(0.2), 0.9))
		b.stroke(chain, s * 0.13, Color(PebbleArt.paint(6).lightened(0.45), 0.95))
		var ground := b.mesh()
		_keep.append(ground)
		draw_mesh(ground, null)
		for k in row.size():
			var sc := 1.1 if k >= 1 and k <= 3 else 1.0
			draw_set_transform(at[k], 0.0, Vector2(sc, sc))
			draw_mesh(PebbleArt.pebble(row[k], s), null, Transform2D.IDENTITY)
			PebbleArt.number(self, font, Vector2.ZERO, row[k], s)
		draw_set_transform(Vector2.ZERO)
