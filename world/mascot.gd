@tool
extends Node3D

## A mascot that is alive on screen. It mounts a model slot the way the
## campsite mounts its camper, blinks by itself, and can be asked to talk;
## anything on the model marked to sway -- the scout's map -- moves in the
## shader without this node touching it.
##
## The model's face is driven by blend shapes rather than by moving layers
## about: a Meshy character arrives as one fused shell, so a separated eye
## would tear at its seam. `Blink` and `Mouth` come out of
## art/mascot_scout.blend as glTF morph targets (see the contract's
## "Textured props").
##
## @tool, so the editor shows the real model with its real materials instead
## of an empty node -- but the motion itself only runs in the game.

const Models = preload("res://core/models.gd")
const Toon = preload("res://core/toon.gd")
const Motion = preload("res://core/motion.gd")

const BLINK_SHAPE := "Blink"
const MOUTH_SHAPE := "Mouth"
## A blink: lids down fast, a beat shut, lids up a little slower.
const BLINK_CLOSE := 0.06
const BLINK_HOLD := 0.05
const BLINK_OPEN := 0.09
## Seconds between blinks, drawn fresh each time so he never looks metronomic.
const BLINK_GAP := Vector2(2.5, 6.5)
## One open-and-shut of the mouth while talking, and how far it shuts. Not
## all the way: the paint under a Meshy mouth was drawn to be seen open, and
## the last of the travel only squashes the tongue.
const TALK_BEAT := 0.22
const TALK_DEPTH := 0.8

@export var slot: String = "mascot_scout":
	set(value):
		slot = value
		if is_inside_tree():
			_build()

var model: Node3D

## Every instance that carries the shapes: the layer's own mesh and the
## outline shell beside it, which is a second MeshInstance3D sharing that
## mesh and keeping its own blend-shape values.
var _faces: Array[MeshInstance3D] = []
var _blink_in := 0.0
var _blink: Tween
var _talk: Tween
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_build()
	_blink_in = _rng.randf_range(BLINK_GAP.x, BLINK_GAP.y)
	set_process(not Engine.is_editor_hint())

func _build() -> void:
	if model != null:
		model.queue_free()
	model = Models.instance(slot)
	add_child(model)
	_faces.clear()
	for mi in Models.meshes(model):
		if mi.mesh == null or mi.mesh.get_blend_shape_count() == 0:
			continue
		_faces.append(mi)
		var shell := mi.get_node_or_null(Toon.OUTLINE_NODE)
		if shell is MeshInstance3D:
			_faces.append(shell as MeshInstance3D)

func _process(delta: float) -> void:
	# Reduce-motion stops the blinking the way it stops every other
	# decoration; the map stops with it, through the motion_scale global the
	# sway shaders read.
	if Motion.reduce:
		return
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink_in = _rng.randf_range(BLINK_GAP.x, BLINK_GAP.y)
		blink()

## One blink. Safe to call while one is running: the new tween replaces it.
func blink() -> void:
	Motion.stop(_blink)
	_blink = create_tween()
	_blink.tween_method(_set_blink, 0.0, 1.0, BLINK_CLOSE)
	_blink.tween_interval(BLINK_HOLD)
	_blink.tween_method(_set_blink, 1.0, 0.0, BLINK_OPEN)

## Works the mouth for `seconds`, then leaves it open again. Under
## reduce-motion the mouth simply stays as modelled.
func talk(seconds := 1.2) -> void:
	Motion.stop(_talk)
	if Motion.reduce:
		_set_mouth(0.0)
		return
	var beats := maxi(1, int(roundf(seconds / TALK_BEAT)))
	_talk = create_tween().set_loops(beats)
	_talk.tween_method(_set_mouth, 0.0, TALK_DEPTH, TALK_BEAT * 0.5)
	_talk.tween_method(_set_mouth, TALK_DEPTH, 0.0, TALK_BEAT * 0.5)

## Sets one shape on the layer and on its line together. A shell left behind
## would ring the open eye while the eye is shut.
func set_shape(name: String, value: float) -> void:
	for mi in _faces:
		var i := mi.find_blend_shape_by_name(name)
		if i >= 0:
			mi.set_blend_shape_value(i, value)

func _set_blink(value: float) -> void:
	set_shape(BLINK_SHAPE, value)

func _set_mouth(value: float) -> void:
	set_shape(MOUTH_SHAPE, value)
