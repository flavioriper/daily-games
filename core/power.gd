extends RefCounted

## Rest (2026-10-22, the battery checkup in docs/agents/checkup.md): the
## game draws every frame at the display's rate whether or not anything
## moves, and the faces' idles and the menu's pulses keep the canvas
## changing, so a phone left on the menu burns as if it were played. After
## REST_AFTER seconds without a touch the game rests: every face stops
## its idle where it is (`set_idle(false)`, the blinks and the sun's turn)
## and every tween that loops forever pauses (the pulses; a one-shot in
## flight, a sim's hop or fly-in, plays out),
## the frame cap drops to REST_FPS, and the engine's low-processor mode
## skips the draw of a frame nothing changed. A touch, a key, or the
## window coming back wakes it: the faces idle again, the loops play on, the cap and
## the mode go back. After STREAM_REST_AFTER the friends stream closes too
## (core/social.gd `rest`) and reopens on the wake; the app sent to the
## background closes it at once, the window merely unfocused (the shade,
## an ad, the purchase sheet) only rests the frame. A live online game or
## a lobby waiting on a friend never rests: the player is watching for
## the other side.
##
## Woken only by world/main.gd (`start(host)`), and not under a `--script`
## run: a harness launching the main scene would otherwise measure a
## resting game after twenty idle seconds (tests/_probe_battery.gd asks
## for it with `force`). `Engine.max_fps` is put back to what it was, so a
## harness that uncapped it is uncapped again after a wake.

const Social = preload("res://core/social.gd")

const REST_AFTER := 20.0
const STREAM_REST_AFTER := 60.0
const REST_FPS := 30

static var enabled := true
static var resting := false
static var _idle := 0.0
static var _fps_before := 0
static var _paused: Array[Tween] = []
static var _idled: Array[Node] = []
static var _stream_rested := false

## The node that watches the input and the clock. Processes while the
## tree is paused, so a pause screen left up still rests and still wakes.
class Watcher extends Node:
	# An inner class does not see the outer one's functions; the script
	# is already in memory, so this is a lookup.
	var _power: Script

	func _init() -> void:
		name = "Power"
		process_mode = Node.PROCESS_MODE_ALWAYS
		_power = load("res://core/power.gd")

	func _input(event: InputEvent) -> void:
		# A touch, a drag, a button or a key; not the bare mouse crossing
		# the window, which a desktop sends without the player meaning it.
		if event is InputEventScreenTouch or event is InputEventScreenDrag \
				or event is InputEventMouseButton or event is InputEventKey:
			_power.touch()

	func _process(delta: float) -> void:
		_power._tick(delta)

	func _notification(what: int) -> void:
		match what:
			NOTIFICATION_APPLICATION_PAUSED:
				_power.rest_now(true)
			NOTIFICATION_APPLICATION_FOCUS_OUT:
				_power.rest_now(false)
			NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
				_power.touch()

static func start(host: Node, force := false) -> void:
	if host.has_node("Power"):
		return
	if not force and "--script" in OS.get_cmdline_args():
		return
	host.add_child(Watcher.new())

## The player did something: the clock restarts and a resting game wakes.
static func touch() -> void:
	_idle = 0.0
	if resting:
		_wake()

## Rest at once: the window unfocused rests the frame, the app sent to
## the background (`stream`) closes the stream too.
static func rest_now(stream: bool) -> void:
	if not enabled:
		return
	_idle = STREAM_REST_AFTER if stream else REST_AFTER
	if not resting:
		_rest()
	if stream:
		_rest_stream()

static func _tick(delta: float) -> void:
	if not enabled:
		return
	# A live online game, or a lobby waiting on a friend: the player is
	# watching for the other side, so the game never rests on them.
	if Social.in_game or Social.busy_with != "":
		_idle = 0.0
		return
	_idle += delta
	if not resting:
		if _idle >= REST_AFTER:
			_rest()
	elif not _stream_rested and _idle >= STREAM_REST_AFTER:
		_rest_stream()

static func _rest() -> void:
	resting = true
	_fps_before = Engine.max_fps
	Engine.max_fps = REST_FPS if _fps_before == 0 or _fps_before > REST_FPS else _fps_before
	OS.low_processor_usage_mode = true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	# The faces first: an idle is a blink wait chained anew each time, not
	# a loop, so it is stopped by the face's own switch and the tweens it
	# kills never reach the list below.
	var stack: Array[Node] = [tree.root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(true):
			stack.append(c)
		if n.has_method("set_idle") and n.get("_idle") == true:
			n.set_idle(false)
			_idled.append(n)
	for tw: Tween in tree.get_processed_tweens():
		# -1 loops left is a tween that loops forever (Tween.get_loops_left).
		if tw.is_valid() and tw.is_running() and tw.get_loops_left() == -1:
			tw.pause()
			_paused.append(tw)

static func _rest_stream() -> void:
	if _stream_rested:
		return
	_stream_rested = true
	Social.rest(true)

static func _wake() -> void:
	resting = false
	Engine.max_fps = _fps_before
	OS.low_processor_usage_mode = false
	for tw: Tween in _paused:
		if is_instance_valid(tw) and tw.is_valid():
			tw.play()
	_paused.clear()
	for n: Node in _idled:
		if is_instance_valid(n) and n.is_inside_tree():
			n.set_idle(true)
	_idled.clear()
	if _stream_rested:
		_stream_rested = false
		Social.rest(false)
