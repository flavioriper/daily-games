extends VBoxContainer

## An Arcade end card's gold line, and under it the offer to double it for a
## video: doubles gold, never the score, and
## never past the day's Arcade cap. Once a run.
## Plan docs/superpowers/plans/2026-09-29-fair-ads.md, task 9.

const BoosterIcon = preload("res://arcade/booster_icon.gd")
const Dialog = preload("res://ui/hud/dialog.gd")

var _gold := 0
var _line: Control
var _button: Button
var _used := false
var _offered := false

func _init(run_gold: int) -> void:
	_gold = run_gold
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 10)

func _ready() -> void:
	_line = BoosterIcon.gold_line(_gold)
	add_child(_line)
	Ads.rewards_changed.connect(_sync)
	_sync()

func _extra() -> int:
	return mini(_gold, Wallet.arcade_room())

func _sync() -> void:
	var show := not _used and _gold > 0 and _extra() > 0 and Ads.can_reward("double")
	if show and _button == null:
		_button = Dialog.secondary("play", tr("AD_DOUBLE") % Locale.number(_extra()))
		_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_button.pressed.connect(_on_press)
		add_child(_button)
		if not _offered:
			_offered = true
			Ads.offered("double")
	elif not show and _button != null:
		_button.queue_free()
		_button = null

func _on_press() -> void:
	if _used:
		return
	_used = true
	_button.disabled = true
	Ads.show_rewarded("double", func(earned: bool) -> void:
		if not is_inside_tree():
			return
		if not earned:
			_used = false
			if _button != null:
				_button.disabled = false
			_sync()
			return
		var got := Wallet.pay_bonus(_gold)
		_line.queue_free()
		_line = BoosterIcon.gold_line(_gold + got)
		add_child(_line)
		move_child(_line, 0)
		_sync())
