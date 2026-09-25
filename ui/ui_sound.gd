extends RefCounted

## The interface's click: one soft paper-and-wood tap for every button in the
## game (back, pager, tabs, sheets, tray chips...). CozyTheme's dress() wires
## it to every BaseButton that enters the tree, so a new button needs nothing.
## A press the board answers with its own cue in the same frame (a tray chip
## that places, Undo, Hint) stays quiet: the board's sound is the answer, and
## two at once only muddy each other. That is why the click waits for the end
## of the frame before it plays. A button with the meta "silent" never clicks.
## The file is assets/sfx/ui/click.ogg (tools/gen_sfx.py ui).

const CLICK := "res://assets/sfx/ui/click.ogg"
## The menu's page turn: a paper slide in place of the click (ui/menu.gd).
const PAGE := "res://assets/sfx/ui/page.ogg"

## The frame a board last played a cue in; ui/fx2d.gd stamps it.
static var board_frame := -1
static var _player: AudioStreamPlayer
static var _stream: AudioStream
static var _pending := false
static var _page_player: AudioStreamPlayer

## Wire `button` to click when pressed, once however often it re-enters.
static func wire(button: BaseButton) -> void:
	if button.has_meta("ui_click"):
		return
	button.set_meta("ui_click", true)
	button.pressed.connect(func() -> void: click(button))

## Ask for a click; it plays at the end of the frame unless a board cue did.
static func click(from: Node) -> void:
	if from.has_meta("silent") or _pending or not from.is_inside_tree():
		return
	_pending = true
	_flush.call_deferred(from.get_tree())

static func _flush(tree: SceneTree) -> void:
	_pending = false
	if board_frame == Engine.get_process_frames():
		return
	if _stream == null:
		if not ResourceLoader.exists(CLICK):
			return
		_stream = load(CLICK)
	if not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		_player.name = "UiClick"
		tree.root.add_child(_player)
	_player.stream = _stream
	_player.play()

## The page turn's slide, played at once on its own player so a quick second
## turn restarts it rather than waiting on the click's frame. A missing file
## is silence, like every other cue.
static func page(from: Node) -> void:
	if not from.is_inside_tree() or not ResourceLoader.exists(PAGE):
		return
	if not is_instance_valid(_page_player):
		_page_player = AudioStreamPlayer.new()
		_page_player.name = "UiPage"
		_page_player.stream = load(PAGE)
		from.get_tree().root.add_child(_page_player)
	_page_player.play()
