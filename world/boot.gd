extends Node

## The game's first scene, since 2026-10-06: the opening (ui/opening.gd) on
## the screen from the first frame, and world/main.tscn loading behind it on
## a thread. Before, main.tscn was the first scene, and the game showed
## nothing until every board it preloads had been read: a second and a half
## of black on this Mac, more on a phone.
##
## This script preloads only what the opening draws with, so it is up at
## once. When the game has loaded and the opening has landed (or was tapped),
## the real scene root is put in the tree under the opening, given a few
## frames to build and draw its first screen out of sight, and then the
## opening leaves while the first screen's own entrance plays again from its
## first beat. main.tscn is then the current scene and this node is gone:
## everything after the handover is as it was when main.tscn was first.
##
## Nothing here starts telemetry, the backend or ads; that is still
## world/main.gd's `_ready`, and a harness that wants the real launch offline
## sets `main_script` (to tests/_offline_main.gd) before this enters the tree.
## Notes: docs/agents/opening.md.

const Motion = preload("res://core/motion.gd")
const Opening = preload("res://ui/opening.gd")

const MAIN := "res://world/main.tscn"
## Over everything main.tscn's own layers draw.
const LAYER := 100
## A tap takes the opening off as soon as the game is loaded, but not before
## the tiles are down: a finger still on the screen from tapping the icon is
## not a wish to skip.
const SOONEST := 0.6
## The frames the first screen gets under the opening before it is shown:
## its build, its first draw, and one to spare.
const UNDER := 3

## Put on the real scene root in place of its own script: a harness's offline
## stand-in.
var main_script: Script
var opening: Opening
var _main: Node
var _hurry := false
var _under := 0

func _ready() -> void:
	# main.gd loads this again with the rest; the opening has to know now.
	Motion.load_settings()
	var layer := CanvasLayer.new()
	layer.name = "OpeningLayer"
	layer.layer = LAYER
	add_child(layer)
	opening = Opening.new()
	opening.skip.connect(func() -> void: _hurry = true)
	opening.left.connect(_done)
	layer.add_child(opening)
	if ResourceLoader.load_threaded_request(MAIN) != OK:
		push_warning("boot: the threaded load would not start; loading on this thread")

func _process(_delta: float) -> void:
	if opening.leaving():
		return
	if _main != null:
		_under += 1
		if _under >= UNDER:
			_reveal()
		return
	var status := ResourceLoader.load_threaded_get_status(MAIN)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if not (opening.settled() or (_hurry and opening.clock >= SOONEST)):
		return
	# Loaded, or the thread failed and this thread loads it (a pause with the
	# opening still up, which is what the game did before with nothing up).
	var scene: PackedScene = ResourceLoader.load_threaded_get(MAIN) if status == ResourceLoader.THREAD_LOAD_LOADED else load(MAIN)
	_main = scene.instantiate()
	if main_script != null:
		_main.set_script(main_script)
	get_tree().root.add_child(_main)

## The first screen is built and drawn under the opening: lift it off.
func _reveal() -> void:
	get_tree().current_scene = _main
	var menu := _main.get_node_or_null("UI/Menu")
	if menu != null and menu.has_method("rise"):
		menu.rise()
	opening.leave()

func _done() -> void:
	queue_free()
