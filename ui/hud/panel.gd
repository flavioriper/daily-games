extends Control

## Base of every HUD panel. Visuals live under `_inner`, so the entrance can
## slide `_inner` without fighting the container the panel sits in; the panel
## reports `_inner`'s minimum size as its own so the host's VBox gives it
## room. Subclasses override _make_inner (the container type), _build (fill
## it) and refresh (read the puzzle).
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")

const ENTER_SLIDE := 0.35
const ENTER_FADE := 0.25

## Where `_inner` starts its entrance, relative to its resting place.
var enter_from := Vector2.ZERO
var _inner: Container
var _entrance: Array[Tween] = []

func _ready() -> void:
	# The panel's own rect takes no input; its contents do. While a panel's
	# entrance still has `_inner` displaced, a neighbour's displaced buttons
	# can lie over this rect, and a Control that stopped input here would
	# swallow their taps (found by tests/_win.gd on the flat screen).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner = _make_inner()
	add_child(_inner)
	_inner.minimum_size_changed.connect(_update_min)
	resized.connect(_fit_inner)
	_build()
	_update_min()

## The container the visuals live in.
func _make_inner() -> Container:
	return PanelContainer.new()

## Fill `_inner`. Called once from _ready.
func _build() -> void:
	pass

## Re-read the puzzle. Every panel tolerates null.
func refresh(_puzzle) -> void:
	pass

func _update_min() -> void:
	custom_minimum_size = _inner.get_combined_minimum_size()
	_fit_inner()

func _fit_inner() -> void:
	_inner.size = size

## The entrance: `_inner` slides in from enter_from with the back ease while
## the panel fades in. Under reduce-motion both land at once.
func enter(delay: float) -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	var slide: Tween = Motion.slide(_inner, "position", enter_from, Vector2.ZERO, ENTER_SLIDE, delay)
	if slide != null:
		_entrance.append(slide)
	var fade: Tween = Motion.appear(self, 0.0, 1.0, ENTER_FADE, delay)
	if fade != null:
		_entrance.append(fade)
