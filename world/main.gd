extends Node

## The scene root. Loads the saved settings in _enter_tree, which runs before
## any child enters the tree, so the stage and its Ambient see the flag on
## their first frame. Nothing else lives here.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 6.

const Motion = preload("res://core/motion.gd")
const Progress = preload("res://core/progress.gd")
const Analytics = preload("res://core/analytics.gd")
const Backend = preload("res://core/backend.gd")
const Locale = preload("res://core/locale.gd")
const CozyTheme = preload("res://ui/theme.gd")

func _enter_tree() -> void:
	Motion.load_settings()
	Locale.apply()
	# Every paper face in the HUD takes its painted wash from here on, the
	# one place that runs before any screen builds (ui/theme.gd dress()).
	CozyTheme.dress(get_tree())

## Telemetry wakes up here and nowhere else, so only a real launch counts;
## tests and harnesses build these screens without ever starting it.
func _ready() -> void:
	Analytics.start(self)
	Analytics.track("game_open", {"day": Progress.day()})
	# The backend wakes here and nowhere else, same as telemetry: the suite
	# and the harnesses build these screens and stay offline.
	Backend.start(self)
