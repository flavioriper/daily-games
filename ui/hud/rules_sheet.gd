extends "res://ui/hud/sheet.gd"

## The rules as a parchment sheet: a How to play heading, one bullet per
## sentence of the puzzle's rules(), and Got it. The help card in the cards
## row opens it; the board keeps the room the inline rules card used to take.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 2
## (amendment 2026-09-15).

const DOT := 30.0
const SEP := 8.0

var close_button: Button
var _list: VBoxContainer

func _card_style() -> StyleBox:
	return CozyTheme.parchment_card()

func _build_sheet(col: VBoxContainer) -> void:
	var heading := Label.new()
	heading.theme_type_variation = "CardTitle"
	heading.text = "How to play"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(heading)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	col.add_child(_list)
	close_button = IconButton.new("check", "Got it", "PrimaryButton")
	close_button.custom_minimum_size.y = ROW
	close_button.pressed.connect(close)
	col.add_child(close_button)

func refresh(puzzle) -> void:
	set_rules(puzzle.rules() if puzzle != null else "")

func set_rules(text: String) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()
	# A wrapped label measures its height at whatever width it has when first
	# asked, and a fresh one has none. Hand it the width it will get so the
	# sheet is the right height before it is ever shown.
	var text_width := maxf(content_width() - DOT - SEP, 1.0)
	for sentence in split_sentences(text):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(SEP))
		var dot := Label.new()
		dot.theme_type_variation = "CardBody"
		dot.text = "•"
		dot.custom_minimum_size.x = DOT
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(dot)
		var l := Label.new()
		l.theme_type_variation = "CardBody"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text = sentence
		row.add_child(l)
		_list.add_child(row)
		l.size.x = text_width

## "One. Two three." -> ["One", "Two three"].
static func split_sentences(text: String) -> Array[String]:
	var out: Array[String] = []
	for part in text.split(". ", false):
		var s := part.strip_edges().trim_suffix(".")
		if s != "":
			out.append(s)
	return out
