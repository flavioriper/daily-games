extends Control

## The first screen: the campsite (world/camp.gd) on the stage under the
## title letters, a page of puzzle cards over the grass, and the fence sign
## closing the frame at the bottom. Opening a card hands the puzzle to a
## PuzzleHost and hides the list; the host's close shows it again. The host is
## always this node's last child while it lives, which the harnesses rely on.
##
## The cards come in pages of nine rather than a scroll, turned with the
## buttons under the grid.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Progress = preload("res://core/progress.gd")
const Registry = preload("res://ui/registry.gd")
const Host = preload("res://ui/puzzle_host.gd")
const TurnHost = preload("res://ui/turn_host.gd")
const CozyTheme = preload("res://ui/theme.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const TitleView = preload("res://ui/hud/title_view.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const PuzzleCard = preload("res://ui/hud/puzzle_card.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const Camp = preload("res://world/camp.gd")

const TITLE := "Daily"
const MOTTO := "Small puzzles\nBrighter days"
const MARGIN := 40
const GAP := 20
const COLS := 3
const PER_PAGE := 9
## The title letters' slot; the view letterboxes the word inside it. About a
## third of the width, as the concept banner sets its name.
const TITLE_SIZE := Vector2(560.0, 150.0)
## The least the campsite gets above the cards; a taller screen gives it more.
const HERO_MIN := 250.0
## The strip the fence diorama is stood along at the bottom.
const FOOTER_H := 200.0
## The camera on this screen is a shift lens (world/camera_rig.gd,
## shift_fov_deg): aimed straight at the camp at the banner's gentle pitch, a
## little over the scout's eye level, with the frame slid so the camp lands in
## the strip above the cards. The field is the banner's, measured across that
## strip; the ordinary perspective would have to aim under the camp through a
## narrow field to hold it up there, which is what flattened and shrank it.
const PITCH := 12.0
const SHIFT_FOV := 54.0
const BUTTON := Vector2(110, 110)
const PAGE_BUTTON := Vector2(96, 64)
## Entrance delays: the title first, then a wave down the cards.
const ENTER_TITLE := 0.0
const ENTER_CARDS := 0.15
const CARD_STEP := 0.05
const CARD_CAP := 0.4
const ENTER_FADE := 0.3

var settings_sheet: Control
var camp: Node3D
var cards: Array = []
var _stage: Node
var _list_root: Control
var _title_block: Control
var _gear: Button
var _hero: Control
var _grid: GridContainer
var _pager: Control
var _prev: Button
var _next: Button
var _dots: Label
var _footer_slot: Control
var _page := 0
## The grid's height with a full page on it, so a short last page does not
## let the campsite grow and the cards jump.
var _full_grid_h := 0.0
var _fit_pending := false

func _ready() -> void:
	theme = CozyTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = get_tree().get_first_node_in_group("stage")
	camp = Camp.new()
	if _stage != null:
		_stage.mount(camp)
	_build_list()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	resized.connect(_request_fit)
	_show_list()

func _build_list() -> void:
	_list_root = Control.new()
	_list_root.name = "List"
	_list_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_list_root)
	var insets := SafeArea.insets(self)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", MARGIN)
	margins.add_theme_constant_override("margin_right", MARGIN)
	margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_list_root.add_child(margins)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", GAP)
	margins.add_child(root)

	# --- the title letters and the settings button, over the sky ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	root.add_child(top)
	_title_block = VBoxContainer.new()
	_title_block.name = "Title"
	_title_block.add_theme_constant_override("separation", 0)
	top.add_child(_title_block)
	var title := TitleView.new()
	title.custom_minimum_size = TITLE_SIZE
	title.set_title(TITLE)
	_title_block.add_child(title)
	var motto := Label.new()
	motto.theme_type_variation = "TitleMotto"
	motto.text = MOTTO.to_upper()
	_title_block.add_child(motto)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_gear = IconButton.new("gear")
	_gear.custom_minimum_size = BUTTON
	_gear.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_gear.pressed.connect(func() -> void: settings_sheet.open())
	top.add_child(_gear)

	# --- the campsite shows through here ---
	_hero = Control.new()
	_hero.name = "Hero"
	_hero.custom_minimum_size = Vector2(0.0, HERO_MIN)
	_hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The camera follows the slots, not the other way round: whenever the
	# layout moves them -- cards re-added, a page turned, the list shown
	# again -- the camp is framed afresh.
	_hero.resized.connect(_request_fit)
	root.add_child(_hero)

	# --- the cards, a page at a time ---
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	root.add_child(_grid)
	for i in Registry.PUZZLES.size():
		var entry: Dictionary = Registry.PUZZLES[i]
		var card := PuzzleCard.new(entry, Pal.CAT[i % Pal.CAT.size()])
		card.name = "Card_" + entry.id
		card.open.connect(_open.bind(entry))
		cards.append(card)

	# --- page turning ---
	_pager = HBoxContainer.new()
	_pager.name = "Pager"
	_pager.alignment = BoxContainer.ALIGNMENT_CENTER
	_pager.add_theme_constant_override("separation", 24)
	root.add_child(_pager)
	_prev = IconButton.new("chevron_left")
	_prev.custom_minimum_size = PAGE_BUTTON
	_prev.pressed.connect(func() -> void: show_page(_page - 1))
	_pager.add_child(_prev)
	_dots = Label.new()
	_dots.theme_type_variation = "CardTitle"
	_dots.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pager.add_child(_dots)
	_next = IconButton.new("chevron_right", "", "PrimaryButton")
	_next.custom_minimum_size = PAGE_BUTTON
	_next.pressed.connect(func() -> void: show_page(_page + 1))
	_pager.add_child(_next)

	# --- the fence diorama stands along the bottom of this ---
	_footer_slot = Control.new()
	_footer_slot.name = "Footer"
	_footer_slot.custom_minimum_size = Vector2(0.0, FOOTER_H)
	_footer_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer_slot.resized.connect(_request_fit)
	root.add_child(_footer_slot)

## How many pages the registry fills.
func page_count() -> int:
	return maxi(1, int(ceil(cards.size() / float(PER_PAGE))))

## Puts page `p` of cards on the grid and plays their entrance.
func show_page(p: int) -> void:
	_page = clampi(p, 0, page_count() - 1)
	for card in cards:
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
	var first := _page * PER_PAGE
	var shown: Array = cards.slice(first, first + PER_PAGE)
	for card in shown:
		_grid.add_child(card)
		card.redraw()
	_grid.custom_minimum_size.y = _full_grid_h if shown.size() < PER_PAGE else 0.0
	_prev.set_enabled(_page > 0)
	_next.set_enabled(_page < page_count() - 1)
	_pager.visible = page_count() > 1
	var marks := ""
	for k in page_count():
		marks += "●" if k == _page else "○"
	_dots.text = marks
	for i in shown.size():
		shown[i].enter(ENTER_CARDS + Motion.stagger(i, CARD_STEP, CARD_CAP))
	_request_fit()

## One fit per frame however many slots moved, after the layout has settled.
func _request_fit() -> void:
	if _fit_pending:
		return
	_fit_pending = true
	_fit_stage.call_deferred()

## Shows the list with the day sign current and plays the entrance; at start
## and on every return from a puzzle. Opening the app is what counts a day.
func _show_list() -> void:
	_list_root.visible = true
	if _stage != null:
		if not camp.is_inside_tree():
			_stage.mount(camp)
		_stage.show_setting(true)
	Progress.touch()
	camp.set_day(Progress.day(), Progress.island_name())
	show_page(_page)
	_enter()

## Frames the campsite in the screen above the cards and stands the fence
## along the bottom. After layout, so the slots have their rects.
func _fit_stage() -> void:
	_fit_pending = false
	if _stage == null or camp == null or not camp.is_inside_tree() or not _list_root.visible:
		return
	if _hero == null or _hero.size.y <= 0.0:
		return
	if _grid.get_child_count() >= PER_PAGE:
		_full_grid_h = maxf(_full_grid_h, _grid.size.y)
	var vw := get_viewport_rect().size.x
	var hero := Rect2(0.0, 0.0, vw, _hero.get_global_rect().end.y)
	# The camp stands upright: its face angle is the camera's own pitch, so
	# the stage leans it by nothing. Yaw 0, undoing any turn a board left.
	_stage.fit_camera(camp.hero_box(), hero, PITCH, Camera3D.PROJECTION_PERSPECTIVE, 0.0, PITCH, SHIFT_FOV)
	var f: Rect2 = _footer_slot.get_global_rect()
	camp.place_footer(_stage.rig, Rect2(0.0, f.position.y, vw, f.size.y))

func _enter() -> void:
	Motion.appear(_title_block, 0.0, 1.0, ENTER_FADE, ENTER_TITLE)
	Motion.appear(_gear, 0.0, 1.0, ENTER_FADE, ENTER_TITLE)
	Motion.appear(_pager, 0.0, 1.0, ENTER_FADE, ENTER_CARDS + CARD_CAP)

## A card opens either a board or a turn; the registry says which, and both
## hosts close the same way.
func _open(entry: Dictionary) -> void:
	var host: Control
	if Registry.kind(entry) == "turn":
		host = TurnHost.new()
		host.setup(entry)
	else:
		host = Host.new()
		host.setup(entry, 1)
	host.closed.connect(func():
		host.queue_free()
		_show_list()
	)
	add_child(host)
	_list_root.visible = false
	if _stage != null:
		_stage.unmount(camp)
