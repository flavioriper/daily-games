extends Control

## Shell around any PuzzleBase: header, rules, board, footer, solved overlay.
## Puzzles never draw chrome themselves, so they stay comparable.

signal closed

const Pal = preload("res://core/palette.gd")
const DailySeed = preload("res://core/daily.gd")

var _puzzle: Control
var _entry: Dictionary
var _difficulty: int = 0

var _title_label: Label
var _stats_label: Label
var _rules_label: Label
var _board_holder: Control
var _overlay: Control
var _overlay_label: Label

func setup(entry: Dictionary, difficulty: int) -> void:
	_entry = entry
	_difficulty = difficulty

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 24)
	root.offset_left = 40
	root.offset_right = -40
	root.offset_top = 80
	root.offset_bottom = -60
	add_child(root)

	# --- header ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	root.add_child(header)

	var back := Button.new()
	back.text = "<"
	back.custom_minimum_size = Vector2(110, 110)
	back.add_theme_font_size_override("font_size", 48)
	back.pressed.connect(func(): closed.emit())
	header.add_child(back)

	_title_label = Label.new()
	_title_label.text = _entry.get("title", "")
	_title_label.add_theme_font_size_override("font_size", 52)
	_title_label.add_theme_color_override("font_color", Pal.TEXT)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_title_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 36)
	_stats_label.add_theme_color_override("font_color", Pal.TEXT_DIM)
	_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_stats_label)

	# --- rules ---
	_rules_label = Label.new()
	_rules_label.add_theme_font_size_override("font_size", 34)
	_rules_label.add_theme_color_override("font_color", Pal.TEXT_DIM)
	_rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_rules_label)

	# --- board ---
	_board_holder = Control.new()
	_board_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_board_holder)

	# --- footer ---
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 20)
	root.add_child(footer)

	var reset := Button.new()
	reset.text = "Reset"
	reset.custom_minimum_size = Vector2(0, 120)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.add_theme_font_size_override("font_size", 40)
	reset.pressed.connect(_on_reset)
	footer.add_child(reset)

	var again := Button.new()
	again.text = "New"
	again.custom_minimum_size = Vector2(0, 120)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.add_theme_font_size_override("font_size", 40)
	again.pressed.connect(_on_new)
	footer.add_child(again)

	_build_overlay()
	_spawn(DailySeed.seed_for(_entry.id, _difficulty))

func _build_overlay() -> void:
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0, 0, 0, 0.72)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)

	_overlay_label = Label.new()
	_overlay_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_label.add_theme_font_size_override("font_size", 56)
	_overlay_label.add_theme_color_override("font_color", Pal.GOOD)
	_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay.add_child(_overlay_label)

	var tap := Button.new()
	tap.flat = true
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap.pressed.connect(func(): _overlay.visible = false)
	_overlay.add_child(tap)

func _spawn(the_seed: int) -> void:
	if is_instance_valid(_puzzle):
		_puzzle.queue_free()
	var script: GDScript = load(_entry.script)
	_puzzle = script.new()
	_puzzle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_holder.add_child(_puzzle)
	_puzzle.solved.connect(_on_solved)
	_puzzle.moved.connect(_update_stats)
	var rng := RandomNumberGenerator.new()
	rng.seed = the_seed
	_puzzle.start(rng, _difficulty)
	_rules_label.text = _puzzle.rules()
	_overlay.visible = false
	_update_stats()

func _on_reset() -> void:
	if is_instance_valid(_puzzle):
		_puzzle.reset_board()
		_overlay.visible = false
		_update_stats()

func _on_new() -> void:
	# Prototype affordance only. The shipped game gets one puzzle per day.
	_spawn(randi())

func _on_solved() -> void:
	_overlay_label.text = "Solved\n%.1fs  ·  %d moves\n\n%s" % [
		_puzzle.elapsed, _puzzle.moves, _puzzle.share_glyphs()
	]
	_overlay.visible = true

func _update_stats() -> void:
	if is_instance_valid(_puzzle):
		_stats_label.text = "%d" % _puzzle.moves

func _process(_delta: float) -> void:
	if is_instance_valid(_puzzle) and not _puzzle.is_done():
		_stats_label.text = "%02d:%02d · %d" % [
			int(_puzzle.elapsed) / 60, int(_puzzle.elapsed) % 60, _puzzle.moves
		]
