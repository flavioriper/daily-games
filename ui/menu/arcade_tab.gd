extends VBoxContainer

## The Arcade tab: games played alone for a score rather than against the
## day's board or against someone: Firefly (arcade/firefly_screen.gd), a
## formation shooter, Molehill (arcade/molehill_screen.gd), whack-a-mole,
## Stackwood (arcade/stackwood_screen.gd), falling blocks that merge, Lucky
## Thirteen (arcade/thirteen_screen.gd), chains of pebbles merged up to 13,
## Posy (arcade/posy_screen.gd), a swap-three garden played a day at a
## time, and Peapod (arcade/peapod_screen.gd), a pea cannon against crates
## that come down with a number on each. Its body takes the day row's and the grid's room, as Versus, Stats
## and Streak do. (Hedgerow TD, Henhouse and Millstream left for a side
## project on 2026-09-27, ~/dev/garden-games.)
##
## One card a game: the game's own cast lying across a painted banner (still,
## drawn once), the name and the best score, a line, and the best stage
## beside Play. A short screen gives up the line and then some of the
## picture before it would push the bar off (_fit, the Versus tab's rule),
## and past that stands the cards two a row.

signal play(game: String)
## The strip's Shop button, or its gold pill: the shop sheet, on `game`.
signal shop(game: String)

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const SunDot = preload("res://ui/sun_dot.gd")
const Record = preload("res://arcade/arcade_record.gd")
const Art = preload("res://arcade/firefly_art.gd")
const Face = preload("res://ui/faces/face.gd")
const MoleArt = preload("res://arcade/molehill_art.gd")
const StackArt = preload("res://arcade/stackwood_art.gd")
const PebbleArt = preload("res://arcade/thirteen_art.gd")
const PosyArt = preload("res://arcade/posy_art.gd")
const PeaArt = preload("res://arcade/peapod_art.gd")
const PeaSim = preload("res://arcade/peapod_sim.gd")
const GoldPill = preload("res://ui/menu/gold_pill.gd")
const Icons = preload("res://ui/icons.gd")

const GAP := 20
const PAD := 24
const RADIUS := 36
const ART_H := 260.0
const ART_H_SHORT := 150.0
const ART_H_TINY := 104.0
const CHIP_H := 84
const GAMES := ["firefly", "molehill", "stackwood", "thirteen", "posy", "peapod"]
const NAMES := {"firefly": "Firefly", "molehill": "Molehill", "stackwood": "Stackwood", "thirteen": "Lucky Thirteen", "posy": "Posy", "peapod": "Peapod"}
const BLURBS := {"firefly": "ARC_FIREFLY_BLURB", "molehill": "ARC_MOLEHILL_BLURB", "stackwood": "ARC_STACKWOOD_BLURB", "thirteen": "ARC_THIRTEEN_BLURB", "posy": "ARC_POSY_BLURB", "peapod": "ARC_PEAPOD_BLURB"}
## How far a game went, in its own words: a stage, a wave, or a streak.
const FURTHEST := {"firefly": "ARC_BEST_STAGE", "molehill": "ARC_BEST_STREAK", "stackwood": "ARC_BEST_BLOCK", "thirteen": "ARC_BEST_NUMBER", "posy": "ARC_BEST_DAY", "peapod": "ARC_BEST_WAVE"}
const PLATE_TINT := {"firefly": Pal.MOON_INK, "molehill": Pal.LEAF_DEEP, "stackwood": Pal.LEAF_DEEP, "thirteen": Pal.LEAF_DEEP, "posy": Pal.LEAF_DEEP, "peapod": Pal.LEAF_DEEP}
const FILL := Color("fcf7ef")
static var PLAIN := CanvasItemMaterial.new()

var _best := {}
var _stage := {}
var _blurbs: Array[Label] = []
var _arts: Array[Control] = []
var _cards: Array[Control] = []
var _goes: Array = []
## The leaf beside a best made with boosters (spec 2026-09-28-gold-gifts).
var _leaves := {}
## The gold and the shop, above the cards (spec 2026-09-28-gold-gifts).
var _strip: HBoxContainer
var gold_pill: Button
## Two cards a row: six cards do not fit one above another on a phone even
## with the smallest pictures, so a short screen pairs them up.
var _paired := false

func _init() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip = HBoxContainer.new()
	_strip.name = "GoldStrip"
	_strip.add_theme_constant_override("separation", GAP)
	gold_pill = GoldPill.new()
	gold_pill.pressed.connect(func() -> void: shop.emit(""))
	_strip.add_child(gold_pill)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(spacer)
	var shop_b := IconButton.new("coin", "SHOP_TITLE", "IconButton")
	shop_b.name = "Shop"
	shop_b.custom_minimum_size.y = GoldPill.H
	shop_b.pressed.connect(func() -> void: shop.emit(""))
	_strip.add_child(shop_b)
	for game: String in GAMES:
		_cards.append(_game_card(game))
	_rows(false)

## Lays the cards out one a row, or two.
func _rows(paired: bool) -> void:
	_paired = paired
	for c in _cards:
		if c.get_parent() != null:
			c.get_parent().remove_child(c)
	if _strip.get_parent() != null:
		_strip.get_parent().remove_child(_strip)
	for r in get_children():
		remove_child(r)
		r.queue_free()
	add_child(_strip)
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
	var swarm: Control = {"firefly": FireflyBanner, "molehill": MolehillBanner, "stackwood": StackwoodBanner, "thirteen": ThirteenBanner, "posy": PosyBanner, "peapod": PeapodBanner}[game].new()
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
	var leaf := Control.new()
	leaf.custom_minimum_size = Vector2(30, 30)
	leaf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leaf.tooltip_text = "ARC_BOOSTED"
	leaf.draw.connect(func() -> void: Icons.paint(leaf, "leaf", Rect2(Vector2.ZERO, leaf.size), Pal.LEAF))
	leaf.visible = false
	line.add_child(leaf)
	_leaves[game] = leaf
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
		(_best[game] as Label).text = tr("ARC_BEST") % Record.grouped(best) if best > 0 else tr("ARC_NO_BEST")
		(_leaves[game] as Control).visible = best > 0 and Record.best_boosted(game)
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
	return total + GAP * rows + _strip.get_combined_minimum_size().y

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
		if PebbleArt.skin() == null:
			texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			PebbleArt.ensure_skin(self, queue_redraw)
		var s := minf(size.y * 0.42, size.x / 8.5)
		var mid := size * Vector2(0.5, 0.56)
		var font := PebbleArt.font()
		var b := Face.Builder.new()
		b.fan(PackedVector2Array([Vector2(0, mid.y - s * 0.8), Vector2(size.x, mid.y - s * 0.8), size, Vector2(0, size.y)]), Color(Pal.PARCHMENT, 0.9))
		# the chain through the three sixes: paper slid under them
		var row := [3, 6, 6, 6, 9, 13]
		var at: Array = []
		for k in row.size():
			at.append(mid + Vector2((k - 2.5) * s * 1.12, (0.18 if k % 2 == 0 else -0.14) * s))
		var chain := PackedVector2Array([at[1], at[2], at[3]])
		for p in chain:
			b.polygon(PebbleArt.tile_outline(p, s * 1.2), Color("fffaf0"))
		b.stroke(chain, s * 0.46, Color("fffaf0"))
		b.stroke(chain, s * 0.3, PebbleArt.paint(6))
		var ground := b.mesh()
		_keep.append(ground)
		draw_mesh(ground, null)
		for k in row.size():
			var sc := 1.1 if k >= 1 and k <= 3 else 1.0
			draw_set_transform(at[k], 0.0, Vector2(sc, sc))
			draw_mesh(PebbleArt.pebble(row[k], s), PebbleArt.skin(), Transform2D.IDENTITY)
			PebbleArt.number(self, font, Vector2.ZERO, row[k], s)
		draw_set_transform(Vector2.ZERO)

## Posy's banner: a strip of the bed's pale cells with a row of garden
## tiles, a breeze sweeping through the middle and the rainbow posy at the
## end. Drawn once.
class PosyBanner extends Control:
	var _keep: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		_keep.clear()
		var s := minf(size.y * 0.5, size.x / 8.6)
		var mid := size * Vector2(0.5, 0.56)
		var b := Face.Builder.new()
		var row := [0, 1, 1, 2, 1, 3, 4, -1]
		var at: Array = []
		for k in row.size():
			at.append(mid + Vector2((k - 3.5) * s * 1.06, 0))
		var strip := Vector2(s * 1.06 * row.size() + s * 0.3, s * 1.3)
		b.polygon(Face.Builder.round_rect(mid - strip * 0.5, strip, s * 0.3), Color(PosyArt.BOARD, 0.92))
		for p: Vector2 in at:
			b.polygon(Face.Builder.round_rect(p - Vector2(s, s) * 0.48, Vector2(s, s) * 0.96, s * 0.18), PosyArt.CELL)
		var ground := b.mesh()
		_keep.append(ground)
		draw_mesh(ground, null)
		for k in row.size():
			draw_mesh(PosyArt.tile(row[k], s * 0.84), null, Transform2D(0.0, at[k]))
		# the three leaves lined up, and a breeze streaking through them
		draw_mesh(PosyArt.breeze(s * 0.84), null, Transform2D(0.0, at[2]))
		draw_mesh(PosyArt.bomb_glow(s * 0.84), null, Transform2D(0.0, at[5]))
		draw_mesh(PosyArt.tile(3, s * 0.84), null, Transform2D(0.0, at[5]))

## Peapod's banner: a strip of numbered crates over the plate, a gift among
## them and one just burst, the cart on the grass under them with a volley
## of peas on its way up. Drawn once.
class PeapodBanner extends Control:
	var _keep: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		_keep.clear()
		var u := minf(size.y / 110.0, size.x / 330.0)
		var mid := size.x * 0.5
		var turf := size.y - 12.0 * u
		var b := Face.Builder.new()
		b.fan(PackedVector2Array([Vector2(0, turf), Vector2(size.x, turf), size, Vector2(0, size.y)]), Color("84c957", 0.95))
		b.fan(PackedVector2Array([Vector2(0, turf), Vector2(size.x, turf), Vector2(size.x, turf + 2.0 * u), Vector2(0, turf + 2.0 * u)]), Color("a9dc7f"))
		var cart_x := mid + 22.0 * u
		for k in 3:
			for side in [-0.5, 0.5]:
				PeaArt.pea(b, Vector2(cart_x + side * 7.5 * u, turf - 52.0 * u - k * 13.0 * u), 3.3 * u)
		var ground := b.mesh()
		_keep.append(ground)
		draw_mesh(ground, null)
		var crates := [[-2, 0, PeaSim.Kind.CRATE, 35], [-1, 0, PeaSim.Kind.PEA, 0], [0, 0, PeaSim.Kind.CRATE, 120], [1, 0, PeaSim.Kind.CRATE, 8],
			[2, 0, PeaSim.Kind.GOLD, 60], [-2, 1, PeaSim.Kind.CRATE, 3], [-1, 1, PeaSim.Kind.CRATE, 17], [2, 1, PeaSim.Kind.BOMB, 0]]
		var font := PeaArt.font()
		var top := 6.0 * u + (PeaSim.CELL_H - 3.0) * u * 0.5
		for c: Array in crates:
			var at := Vector2(mid + c[0] * PeaSim.CELL_W * u, top + c[1] * PeaSim.CELL_H * u)
			var kind: int = c[2]
			draw_mesh(PeaArt.crate(kind, PeaArt.tier_of(c[3]) if kind == PeaSim.Kind.CRATE else 0, u), null, Transform2D(0.0, at))
			if c[3] > 0:
				PeaArt.number(self, font, at + Vector2(0, -2.2 * u), c[3], (PeaSim.CELL_H - 3.0) * u)
		var foot := Vector2(cart_x, turf - 9.0 * u)
		draw_mesh(PeaArt.barrel(u), null, Transform2D(0.0, foot + Vector2(0, -12.0 * u)))
		draw_mesh(PeaArt.cart(u), null, Transform2D(0.0, foot))
		for side in [-1.0, 1.0]:
			draw_mesh(PeaArt.wheel(u), null, Transform2D(0.4, foot + Vector2(side * 13.0 * u, 0)))
		draw_mesh(PeaArt.token(PeaSim.Kind.RATE, u), null, Transform2D(-0.15, Vector2(mid - 60.0 * u, turf - 30.0 * u)))
