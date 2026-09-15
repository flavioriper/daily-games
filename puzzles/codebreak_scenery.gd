extends RefCounted

## Code Break's surroundings: the plank dock the board is laid on, and the
## bank, river and props around it. Pure node building from world/scenery.gd
## and the model library; the board animates what this returns.
## Spec: docs/superpowers/specs/2026-09-15-codebreak-screen-design.md, sections 0 to 3.

const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Platform = preload("res://core/platform.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Scenery = preload("res://world/scenery.gd")

## How far the deck runs past the moss rim: one cell each side, one at the
## far end for the pier posts, two at the near end under the tray.
const DECK_APRON := 1.0
const DECK_FAR := 1.0
const DECK_NEAR := 2.0

## The rim and the deck as one node: the dock the entrance raises.
static func dock(cols: int, rows: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Dock"
	root.add_child(Platform.build(cols, rows, ""))
	var hx := cols * 0.5 + Platform.LIP + DECK_APRON
	var hz := rows * 0.5 + Platform.LIP
	root.add_child(Scenery.deck(-hx, hx, -hz - DECK_FAR, hz + DECK_NEAR))
	return root
