extends Control

const Pal = preload("res://core/palette.gd")
const Registry = preload("res://ui/registry.gd")
const Host = preload("res://ui/puzzle_host.gd")
const CozyTheme = preload("res://ui/theme.gd")

var _list_root: Control

func _ready() -> void:
	theme = CozyTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_list()

func _build_list() -> void:
	_list_root = Control.new()
	_list_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_list_root)

	var paper := ColorRect.new()
	paper.color = Color(Pal.PAPER, 0.82)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_root.add_child(paper)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_right = -60
	root.offset_top = 100
	root.offset_bottom = -60
	root.add_theme_constant_override("separation", 28)
	_list_root.add_child(root)

	var title := Label.new()
	title.text = "Daily"
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Pal.TEXT)
	root.add_child(title)

	var sub := Label.new()
	sub.text = "%d prototypes · tap to play" % Registry.PUZZLES.size()
	sub.add_theme_font_size_override("font_size", 34)
	sub.add_theme_color_override("font_color", Pal.TEXT_DIM)
	root.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 20)
	scroll.add_child(col)

	for entry in Registry.PUZZLES:
		col.add_child(_make_row(entry))

func _make_row(entry: Dictionary) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 180)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = "%s\n%s" % [entry.title, entry.blurb]
	btn.add_theme_font_size_override("font_size", 40)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_open.bind(entry))
	return btn

func _open(entry: Dictionary) -> void:
	var host = Host.new()
	host.setup(entry, 1)
	host.closed.connect(func():
		host.queue_free()
		_list_root.visible = true
	)
	add_child(host)
	_list_root.visible = false
