extends Control

## Shell around any TurnBase: the concept HUD's top bar and day card, the
## turn's prompt, the stage slot, one Lock button, and the graded reveal.
## The sibling of ui/puzzle_host.gd, and it reuses that screen's furniture so
## a turn and a board feel like the same game.
##
## A turn is played once a day. Opening a day already played shows the stored
## result with a refreshed crowd number, never the input again.
## Spec: docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md,
## section 2.3.

signal closed

const Pal = preload("res://core/palette.gd")
const DailySeed = preload("res://core/daily.gd")
const Progress = preload("res://core/progress.gd")
const Analytics = preload("res://core/analytics.gd")
const Backend = preload("res://core/backend.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const TopBar = preload("res://ui/hud/top_bar.gd")
const DayCard = preload("res://ui/hud/day_card.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")

const MARGIN := 40
const GAP := 20
const ENTER_TOP := 0.0
const ENTER_CARDS := 0.1
const ENTER_ACTIONS := 0.2
## Where a played day is remembered, so reopening shows the result.
const PLAYED_PATH := "user://turns.cfg"

var _entry: Dictionary
var _turn: Control
var _day: int = 0

var top_bar: Control
var day_card: Control
var prompt: Label
var lock_button: Button
var reveal_panel: PanelContainer
var score_bar: ProgressBar
var score_label: Label
var crowd_label: Label
var share_button: Button
var settings_sheet: Control
var _slot: Control

func setup(entry: Dictionary) -> void:
	_entry = entry

func _ready() -> void:
	theme = CozyTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_day = DailySeed.date_key()
	_build()
	Progress.touch()
	day_card.set_day(Progress.day(), Progress.island_name())
	_enter()
	_open_turn()

func _build() -> void:
	var insets := SafeArea.insets(self)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", MARGIN)
	margins.add_theme_constant_override("margin_right", MARGIN)
	margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	add_child(margins)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", GAP)
	margins.add_child(root)

	top_bar = TopBar.new(_entry.get("title", ""), _entry.get("motto", ""))
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	root.add_child(top_bar)

	day_card = DayCard.new()
	day_card.name = "DayCard"
	root.add_child(day_card)

	prompt = Label.new()
	prompt.name = "Prompt"
	prompt.theme_type_variation = "CardBody"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(prompt)

	_slot = Control.new()
	_slot.name = "Slot"
	_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_slot)

	lock_button = IconButton.new("check", "Lock", "PrimaryButton")
	lock_button.name = "Lock"
	lock_button.custom_minimum_size.y = 110
	lock_button.pressed.connect(_on_lock)
	root.add_child(lock_button)

	_build_reveal(root)

	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)

	# A turn has nothing to undo and no hints, ever; refresh(null) hides both
	# buttons that TopBar shows by default (top_bar.gd, refresh()).
	top_bar.refresh(null)

func _build_reveal(root: Control) -> void:
	reveal_panel = PanelContainer.new()
	reveal_panel.name = "Reveal"
	reveal_panel.add_theme_stylebox_override("panel", CozyTheme.paper_card())
	reveal_panel.visible = false
	root.add_child(reveal_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	reveal_panel.add_child(col)
	score_label = Label.new()
	score_label.theme_type_variation = "CardTitle"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(score_label)
	score_bar = ProgressBar.new()
	score_bar.min_value = 0
	score_bar.max_value = 100
	score_bar.show_percentage = false
	score_bar.custom_minimum_size.y = 28
	col.add_child(score_bar)
	crowd_label = Label.new()
	crowd_label.theme_type_variation = "CardBody"
	crowd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(crowd_label)
	share_button = IconButton.new("chevron_right", "Share", "IconButton")
	share_button.custom_minimum_size.y = 96
	share_button.pressed.connect(_on_share)
	col.add_child(share_button)

func _enter() -> void:
	top_bar.enter(ENTER_TOP)
	day_card.enter(ENTER_CARDS)
	Motion.appear(prompt, 0.0, 1.0, 0.25, ENTER_CARDS)
	Motion.appear(lock_button, 0.0, 1.0, 0.25, ENTER_ACTIONS)

## Reads the day, stands the turn up, and shows either the input or the
## result the player already committed.
func _open_turn() -> void:
	var game: String = str(_entry.get("id", ""))
	var got := await Backend.day_content(game, _day)
	var content: Dictionary = got.data if got.data is Dictionary else {}
	var script: GDScript = load(_entry.script)
	_turn = script.new()
	_turn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot.add_child(_turn)
	_turn.input_changed.connect(_refresh)
	_turn.graded.connect(_on_graded)
	prompt.text = _turn.prompt_text()

	var played := _played_score(game)
	if played >= 0:
		_turn.restore(content, played)
		await _show_result(played, false)
	else:
		_turn.start_turn(content)
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(_turn):
		return
	lock_button.visible = not _turn.is_done()
	lock_button.set_enabled(_turn.has_input())

func _on_lock() -> void:
	if not is_instance_valid(_turn) or _turn.is_done():
		return
	_turn.lock()

func _on_graded(the_score: int) -> void:
	var game: String = str(_entry.get("id", ""))
	_remember(game, the_score)
	Analytics.track("turn_lock", {
		"turn_id": game, "day": Progress.day(),
		"score": the_score, "seconds": _turn.elapsed,
	})
	await _show_result(the_score, true)
	Analytics.track("turn_reveal", {"turn_id": game, "score": the_score})

## Shows the graded panel and the crowd's verdict. `send` is false when the
## day was already played and we are only refreshing the number.
func _show_result(the_score: int, send: bool) -> void:
	var game: String = str(_entry.get("id", ""))
	lock_button.visible = false
	reveal_panel.visible = true
	score_label.text = "%d / 100" % the_score
	score_bar.value = the_score
	crowd_label.text = "…"
	Motion.appear(reveal_panel, 0.0, 1.0, 0.3, 0.0)
	if send:
		await Backend.submit(game, _day, {
			"score": the_score, "guess": _turn.guess(),
			"locale": TranslationServer.get_locale().substr(0, 2),
		})
	var crowd := await Backend.tally(game, _day)
	if not is_instance_valid(crowd_label):
		return
	var pct := Backend.percentile(crowd.data, the_score)
	if pct >= 0:
		crowd_label.text = "Closer than %d%% of players" % pct
	else:
		crowd_label.text = "You are the first today"
	Analytics.track("crowd_reveal_opened", {"turn_id": game, "count": int(crowd.data.get("count", 0))})

func _on_share() -> void:
	var text := "%s\n%s" % [_turn.share_text(), _turn.share_glyphs()]
	DisplayServer.clipboard_set(text)
	Analytics.track("turn_share", {"turn_id": str(_entry.get("id", ""))})

func _on_back() -> void:
	closed.emit()

# --- the day already played ---

static func _played_score(game: String) -> int:
	var cfg := ConfigFile.new()
	cfg.load(PLAYED_PATH)
	return int(cfg.get_value(game, str(DailySeed.date_key()), -1))

static func _remember(game: String, the_score: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PLAYED_PATH)
	cfg.set_value(game, str(DailySeed.date_key()), the_score)
	cfg.save(PLAYED_PATH)
