extends Control

## A booster's badge: its glyph in paper on a disc of its game's colour
## (arcade/boosters.gd), with the count held in a small pill on its
## shoulder when `count` is set (-1 hides it). Gold is drawn as a coin.

const Boosters = preload("res://arcade/boosters.gd")
const Icons = preload("res://ui/icons.gd")
const Pal = preload("res://core/palette.gd")
const GoldPill = preload("res://ui/menu/gold_pill.gd")

var item := ""
var count := -1:
	set(v):
		count = v
		queue_redraw()

func _init(id := "", side := 96.0) -> void:
	item = id
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	if item == "gold":
		GoldPill.coin(self, c, r * 0.8)
	else:
		var col := Boosters.tint(item)
		draw_circle(c + Vector2(0, r * 0.08), r, col.darkened(0.25), true, -1.0, true)
		draw_circle(c, r, col, true, -1.0, true)
		draw_arc(c, r * 0.86, PI * 1.1, PI * 1.5, 12, Color(1, 1, 1, 0.3), r * 0.1, true)
		var g := r * 1.1
		Icons.paint(self, Boosters.icon(item), Rect2(c - Vector2(g, g) * 0.5, Vector2(g, g)), Pal.SURFACE, col)
	if count >= 0:
		var font := get_theme_font("font", "Label")
		var fs := int(r * 0.52)
		var s := "x%d" % count
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + r * 0.3
		var at := Vector2(size.x - w * 0.7, size.y - fs * 1.2)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Pal.TEXT if count > 0 else Pal.TEXT_DIM
		sb.set_corner_radius_all(int(fs * 0.7))
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(at, Vector2(w, fs * 1.3)))
		draw_string(font, at + Vector2(r * 0.15, fs * 1.02), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.SURFACE)

## The end card's line for the gold a run earned: a coin and "+25 gold".
static func gold_line(amount: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(load("res://arcade/booster_icon.gd").new("gold", 60))
	var l := Label.new()
	l.theme_type_variation = "SheetTitle"
	l.text = "+%s %s" % [Locale.number(amount), TranslationServer.translate("GOLD_WORD")]
	row.add_child(l)
	return row
