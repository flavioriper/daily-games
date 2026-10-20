extends VBoxContainer

## The Versus tab: games played against someone rather than against the
## day's board. Snooker, chess, checkers, air hockey, Toy Boats and Penny Drop
## (versus/snooker_screen.gd, versus/chess_screen.gd,
## versus/checkers_screen.gd, versus/hockey_screen.gd, versus/boats_screen.gd,
## versus/penny_screen.gd), and the someone is the
## computer at one of three levels or, on the fourth chip, another player:
## online for the five games of turns (level Record.ONLINE; versus/online/),
## across the same phone for air hockey (level Record.LOCAL), which has no
## turns for the live transport to carry. Its body takes the day row's and
## the grid's room, the way Stats and Streak do, under the same header and
## over the same bar.
##
## One card a game, and **the cards stand in the Puzzles tab's own grid**
## (ui/menu.gd: one grid, one swipe, one slide, one pager for Puzzles,
## Versus and Arcade), each with a face of its own
## (ui/menu/cards/vs_<game>.gd). The whole card is the button, and `open`
## asks the menu for the sheet that picks who to play
## (ui/menu/versus_sheet.gd).
##
## This is the row over that grid, where the day row stands on Puzzles:
## Friends, with how many of them are online now. It opens the Friends
## sheet (ui/menu/friends_sheet.gd, through `friends`), where a friend is
## asked to one of these games.

## A card was pressed: the menu asks who to play.
signal open(game: String)
## The Friends row was pressed.
signal friends

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Record = preload("res://versus/versus_record.gd")
const Social = preload("res://core/social.gd")
const SheetParts = preload("res://ui/hud/sheet_parts.gd")
const Icons = preload("res://ui/icons.gd")

const GAP := 20
const PAD := 24
const RADIUS := 36
## The chips, as [key, level]: three of the computer's, then the other
## player -- online, or for a game in LOCAL_GAMES across the same phone.
const LEVELS := [["DIFF_EASY", 0], ["DIFF_MEDIUM", 1], ["DIFF_HARD", 2], ["VS_ONLINE", Record.ONLINE]]
const LEVELS_LOCAL := [["DIFF_EASY", 0], ["DIFF_MEDIUM", 1], ["DIFF_HARD", 2], ["VS_TWO", Record.LOCAL]]
## Best first by how many play each game on the stores (2026-10-20,
## docs/agents/versus.md).
const GAMES := ["snooker", "chess", "dominoes", "checkers", "penny", "reversi", "boats", "hockey"]
## The games with no game online (and so none against a friend): their fourth
## chip is two players on this phone.
const LOCAL_GAMES := ["hockey"]
const NAMES := {"snooker": "Snooker", "chess": "Chess", "checkers": "Checkers", "hockey": "Air Hockey",
	"boats": "Toy Boats", "penny": "Penny Drop", "dominoes": "Dominoes", "reversi": "Reversi"}
## Each card's line: two lines at half the screen's width at most.
const SHORTS := {"snooker": "VS_SNOOKER_SHORT", "chess": "VS_CHESS_SHORT", "checkers": "VS_CHECKERS_SHORT",
	"hockey": "VS_HOCKEY_SHORT", "boats": "VS_BOATS_SHORT", "penny": "VS_PENNY_SHORT",
	"dominoes": "VS_DOMINOES_SHORT", "reversi": "VS_REVERSI_SHORT"}
const FILL := Color("fcf7ef")
## The Friends row: its height, the plaque on it and the plaque's tint.
const FRIENDS_H := 108.0
const FRIENDS_PLAQUE := 72.0
const FRIENDS_TINT := Color("f4b8a4")
const ONLINE_INK := Color("4f8a31")
static var PLAIN := CanvasItemMaterial.new()

var friends_row: Button
var _friends_sub: Label
var _friends_dot: Control
## How many friends the row last counted online.
var _friends_on := 0

func _init() -> void:
	add_theme_constant_override("separation", GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_friends_row())

## The list the grid shows: one entry a game, in GAMES' order.
static func entries() -> Array:
	var out: Array = []
	for game: String in GAMES:
		out.append({"id": game, "title": NAMES[game], "short": SHORTS[game],
			"card": "res://ui/menu/cards/vs_%s.gd" % game})
	return out

## A game's four chips, as [key, level].
static func levels_of(game: String) -> Array:
	return LEVELS_LOCAL if LOCAL_GAMES.has(game) else LEVELS

## Whether `game` can be played online, and so against a friend.
static func plays_online(game: String) -> bool:
	return GAMES.has(game) and not LOCAL_GAMES.has(game)

## The row above the cards: a plaque, Friends over a line that counts who is
## online, and a chevron. A Button whose face is drawn by its children, the
## way the settings rows are.
func _friends_row() -> Button:
	var row := Button.new()
	row.name = "Friends"
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size.y = FRIENDS_H
	row.material = PLAIN
	var up := CozyTheme.soft_button(FILL, RADIUS, false, 0)
	var down := CozyTheme.soft_button(FILL, RADIUS, true, 0)
	for st in ["normal", "hover", "focus"]:
		row.add_theme_stylebox_override(st, up)
	for st in ["pressed", "hover_pressed"]:
		row.add_theme_stylebox_override(st, down)
	row.pressed.connect(func() -> void: friends.emit())
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = PAD
	line.offset_right = -PAD
	line.add_theme_constant_override("separation", 22)
	row.add_child(line)
	line.add_child(SheetParts.Plaque.new("friends", FRIENDS_TINT, FRIENDS_PLAQUE))
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -6)
	line.add_child(words)
	var title := Label.new()
	title.text = "FRIENDS_TITLE"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override("font", CozyTheme.display(700))
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Pal.TEXT)
	words.add_child(title)
	var sub := HBoxContainer.new()
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_theme_constant_override("separation", 10)
	words.add_child(sub)
	# A filled dot beside the count, so "2 online" is not said by a colour.
	_friends_dot = Control.new()
	_friends_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_friends_dot.custom_minimum_size = Vector2(16, 16)
	_friends_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_friends_dot.draw.connect(func() -> void:
		_friends_dot.draw_circle(_friends_dot.size * 0.5, 7.0, Pal.GOOD, true, -1.0, true))
	sub.add_child(_friends_dot)
	_friends_sub = Label.new()
	_friends_sub.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_friends_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_friends_sub.theme_type_variation = "CardBlurb"
	_friends_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friends_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_friends_sub.clip_text = true
	sub.add_child(_friends_sub)
	var chevron := Control.new()
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.custom_minimum_size = Vector2(36, 36)
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chevron.draw.connect(func() -> void:
		Icons.paint(chevron, "chevron_right", Rect2(Vector2.ZERO, chevron.size), Pal.TEXT_DIM))
	line.add_child(chevron)
	friends_row = row
	return row

## The row's line: how many friends are online, by the last read of their
## presence; what to do with the row when there is nobody to count.
func _paint_friends() -> void:
	var all := Social.friends()
	_friends_on = 0
	for uid in all:
		if Social.is_online(uid):
			_friends_on += 1
	_friends_dot.visible = _friends_on > 0
	if all.is_empty():
		_friends_sub.text = tr("FRIENDS_ROW_NONE")
	elif _friends_on == 0:
		_friends_sub.text = tr("FRIENDS_ROW_AWAY")
	else:
		_friends_sub.text = tr("FRIENDS_ONLINE_ONE" if _friends_on == 1 else "FRIENDS_ONLINE_N") % _friends_on
	_friends_sub.add_theme_color_override("font_color", ONLINE_INK if _friends_on > 0 else Pal.TEXT_DIM)

## Reads the friends' presence, for a player who has friends: as the tab
## comes up, not on a clock (the sheet keeps its own while it is open).
func _read_friends() -> void:
	if not Social.started() or Social.friends().is_empty():
		return
	@warning_ignore("redundant_await")
	await Social.refresh_presence()
	_paint_friends()

func refresh() -> void:
	_paint_friends()

func _ready() -> void:
	Social.hub().changed.connect(_paint_friends)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_read_friends()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and _friends_sub != null:
		_paint_friends()
