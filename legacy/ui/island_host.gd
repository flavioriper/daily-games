extends "res://ui/puzzle_host.gd"

## The island shell: the concept HUD the twelve boards were built under --
## the carved sign in the top bar, the wooden day card, the How to play card,
## the board slot on parchment, the action bar and the motto footer. It is
## everything ui/puzzle_host.gd used to build itself, moved out on 2026-09-18
## so the live flat game loads none of it.
##
## Reached only from the first screen's More sheet. Nothing new should be
## built on it.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md.

const TopBar = preload("res://legacy/ui/hud/top_bar.gd")
const DayCard = preload("res://legacy/ui/hud/day_card.gd")
const HelpCard = preload("res://legacy/ui/hud/help_card.gd")
const ActionBar = preload("res://legacy/ui/hud/action_bar.gd")

## The rows of the HUD, top to bottom, into `root`: the top bar, the cards
## row, the board slot, the action bar and the motto footer. The flat host
## (ui/flat/flat_host.gd) overrides this and nothing else of the layout; every
## handler below reads the panels through the fields this fills.
func _build_chrome(root: VBoxContainer) -> void:
	# --- top bar ---
	top_bar = TopBar.new(_entry.get("title", ""), _entry.get("motto", ""))
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.undo.connect(_on_undo)
	top_bar.hint.connect(_on_hint)
	top_bar.settings.connect(_open_settings)
	root.add_child(top_bar)

	# --- cards row ---
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", GAP)
	root.add_child(cards)
	day_card = DayCard.new()
	day_card.name = "DayCard"
	cards.add_child(day_card)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_child(spacer)
	help_card = HelpCard.new()
	help_card.name = "HelpCard"
	help_card.open.connect(_open_rules)
	cards.add_child(help_card)

	# --- board slot ---
	_board_holder = Control.new()
	_board_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_board_holder)
	_card = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.PAPER
	sb.set_corner_radius_all(32)
	_card.add_theme_stylebox_override("panel", sb)
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_holder.add_child(_card)

	# --- action bar and footer ---
	action_bar = ActionBar.new()
	action_bar.name = "ActionBar"
	action_bar.reset.connect(_on_reset)
	action_bar.check.connect(_on_check)
	action_bar.pick.connect(_on_pick)
	action_bar.piece_pick.connect(_on_pick)
	action_bar.turn_view.connect(_on_turn_view)
	action_bar.peek.connect(_on_peek)
	root.add_child(action_bar)
	footer = Label.new()
	footer.theme_type_variation = "Motto"
	footer.text = String(_entry.get("footer", "")).to_upper()
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.visible = footer.text != ""
	root.add_child(footer)


## The HUD arrives: top bar first, cards, then the action bar and the footer.
func _enter() -> void:
	top_bar.enter(ENTER_TOP)
	day_card.enter(ENTER_CARDS)
	help_card.enter(ENTER_CARDS)
	action_bar.enter(ENTER_ACTIONS)
	Motion.appear(footer, 0.0, 1.0, ENTER_FOOTER_FADE, ENTER_FOOTER)
