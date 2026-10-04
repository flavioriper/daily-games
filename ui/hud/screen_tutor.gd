extends RefCounted

## The tutorial of a screen that is its own host: the Versus and Arcade games
## are not registry boards, so ui/puzzle_host.gd never mounts them and its
## card, its ? and its How to play never reached them. A screen keeps one of
## these and hands it its top bar and settings sheet; the card is the boards'
## own (ui/hud/how_to_play.gd), the pages the screen's `tutorial_pages()`.
##
## Only ui/menu.gd asks for the first play's card (`first_play`), so a harness
## that builds a screen by hand opens on the game, not on a card over it.

const HowToPlay = preload("res://ui/hud/how_to_play.gd")
const Progress = preload("res://core/progress.gd")
const Analytics = preload("res://core/analytics.gd")

var _screen: Control
var _id := ""
var _title := ""
## Called with true as the card goes up and false as it leaves: a game with a
## clock stops it there.
var _hold := Callable()
var _card: Control

func _init(screen: Control, id: String, title: String, hold := Callable()) -> void:
	_screen = screen
	_id = id
	_title = title
	_hold = hold

## The top bar's ? and the settings sheet's How to play both open the card.
func wire(top_bar: Control, settings_sheet: Control) -> void:
	top_bar.help.connect(open)
	settings_sheet.with_rules = true
	settings_sheet.rules.connect(open)

## The card on a first play, once.
func first_play() -> void:
	if not Progress.tutorial_seen(_id):
		show()

func open() -> void:
	Analytics.track("rules_opened", {"puzzle_id": _id})
	show()

func show() -> void:
	if is_instance_valid(_card):
		return
	_card = HowToPlay.new()
	_card.name = "HowToPlay"
	_card.setup({"id": _id, "title": _title}, _screen)
	_held(true)
	# Gone any way at all: its Continue, Android's back, a harness freeing it.
	_card.tree_exited.connect(_held.bind(false))
	_screen.add_child(_card)

func is_open() -> bool:
	return is_instance_valid(_card) and not _card.is_queued_for_deletion()

## Android's back: the card first. True when there was one to close.
func close() -> bool:
	if not is_open():
		return false
	_card._continue()
	return true

func _held(on: bool) -> void:
	if _hold.is_valid() and is_instance_valid(_screen):
		_hold.call(on)
