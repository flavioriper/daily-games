extends "res://ui/hud/panel.gd"

## The parchment rules card: a RULES heading and one bullet per sentence of
## the puzzle's rules().
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 2.

const WIDTH := 520.0

var _list: VBoxContainer

func _init() -> void:
	enter_from = Vector2(120, 0)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _build() -> void:
	(_inner as PanelContainer).add_theme_stylebox_override("panel", CozyTheme.parchment_card())
	_inner.custom_minimum_size.x = WIDTH
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_inner.add_child(col)
	var heading := Label.new()
	heading.theme_type_variation = "CardTitle"
	heading.text = "RULES"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(heading)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	col.add_child(_list)

func refresh(puzzle) -> void:
	set_rules(puzzle.rules() if puzzle != null else "")

func set_rules(text: String) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()
	for sentence in split_sentences(text):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var dot := Label.new()
		dot.theme_type_variation = "CardBody"
		dot.text = "•"
		dot.custom_minimum_size.x = 30
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(dot)
		var l := Label.new()
		l.theme_type_variation = "CardBody"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text = sentence
		row.add_child(l)
		_list.add_child(row)

## "One. Two three." -> ["One", "Two three"].
static func split_sentences(text: String) -> Array[String]:
	var out: Array[String] = []
	for part in text.split(". ", false):
		var s := part.strip_edges().trim_suffix(".")
		if s != "":
			out.append(s)
	return out
