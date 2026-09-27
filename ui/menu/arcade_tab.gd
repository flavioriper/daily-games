extends VBoxContainer

## The Arcade tab: games played alone for a score rather than against the
## day's board or against someone. Firefly first (arcade/firefly_screen.gd);
## more are to come, and the card under it says so. Its body takes the day
## row's and the grid's room, as Versus, Stats and Streak do.
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
const Face = preload("res://ui/faces/face.gd")

const GAP := 20
const PAD := 24
const RADIUS := 36
const ART_H := 260.0
const ART_H_SHORT := 150.0
const CHIP_H := 84
const GAMES := ["firefly"]
const NAMES := {"firefly": "Firefly"}
const BLURBS := {"firefly": "ARC_FIREFLY_BLURB"}
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
	add_child(_soon_card())

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
	var art := Vistas.card_plate(game, Pal.MOON_INK)
	art.custom_minimum_size.y = ART_H
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.clip_contents = true
	col.add_child(art)
	_arts.append(art)
	var swarm := FireflyBanner.new()
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

func _soon_card() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CozyTheme.lifted(Color("f7f0e4"), RADIUS, PAD))
	card.material = PLAIN
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)
	var head := Label.new()
	head.text = "ARC_SOON"
	head.theme_type_variation = "CardName"
	head.modulate = Color(1, 1, 1, 0.6)
	col.add_child(head)
	var line := Label.new()
	line.text = "ARC_SOON_LINE"
	line.theme_type_variation = "CardBlurb"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	_blurbs.append(line)
	return card

func refresh() -> void:
	for game: String in GAMES:
		var best := Record.best(game)
		(_best[game] as Label).text = tr("ARC_BEST") % Record.grouped(best) if best > 0 else tr("ARC_NO_BEST")
		var st := Record.best_stage(game)
		(_stage[game] as Label).text = tr("ARC_BEST_STAGE") % st if st > 0 else ""
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
