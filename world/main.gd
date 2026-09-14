extends Node

## The scene root. Loads the saved settings in _enter_tree, which runs before
## any child enters the tree, so the stage and its Ambient see the flag on
## their first frame. Nothing else lives here.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 6.

const Motion = preload("res://core/motion.gd")

func _enter_tree() -> void:
	Motion.load_settings()
