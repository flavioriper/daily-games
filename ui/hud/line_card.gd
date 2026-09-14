extends PanelContainer

## The working-line card: the focused cell's row and its column, each with a
## label, one dot per cell (sun-orange, moon-slate or hollow) and a filled
## count. Reads PuzzleBase.line_state(); idle before the first tap.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 2.

const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")

const MIN_WIDTH := 420.0
const DOT_R := 9.0
const DOT_GAP := 8.0
const LABEL_W := 110.0
const COUNT_W := 80.0

var lines: Array[Dictionary] = []
var n := 6

func _ready() -> void:
	add_theme_stylebox_override("panel", CozyTheme.slate_card())
	custom_minimum_size.x = MIN_WIDTH
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	for i in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		col.add_child(row)
		var label := Label.new()
		label.theme_type_variation = "OnSlateBody"
		label.custom_minimum_size.x = LABEL_W
		row.add_child(label)
		var dots := Control.new()
		dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dots.custom_minimum_size.y = DOT_R * 2.0 + 4.0
		row.add_child(dots)
		var count := Label.new()
		count.theme_type_variation = "OnSlateBody"
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.custom_minimum_size.x = COUNT_W
		row.add_child(count)
		var entry := {"label": label, "dots": dots, "count": count, "cells": []}
		dots.draw.connect(_draw_dots.bind(entry))
		lines.append(entry)
	show_idle()

func refresh(puzzle) -> void:
	if puzzle == null:
		show_idle()
		return
	var state: Dictionary = puzzle.line_state()
	if state.is_empty():
		show_idle()
		return
	_set_line(0, "Row %d" % (int(state.row.index) + 1), state.row.cells, true)
	_set_line(1, "Col %d" % (int(state.col.index) + 1), state.col.cells, true)

## No focus yet: "Tap a tile" over hollow dots, no counts.
func show_idle() -> void:
	var blank := []
	for i in n:
		blank.append(-1)
	_set_line(0, "Tap a tile", blank, false)
	_set_line(1, "", blank, false)

func _set_line(i: int, label: String, cells: Array, counted: bool) -> void:
	var e: Dictionary = lines[i]
	e.label.text = label
	e.label.modulate.a = 1.0 if counted else 0.6
	e.cells = cells
	n = cells.size()
	var filled := 0
	for v in cells:
		if int(v) != -1:
			filled += 1
	e.count.text = ("%d/%d" % [filled, cells.size()]) if counted else ""
	e.dots.queue_redraw()

func _draw_dots(entry: Dictionary) -> void:
	var dots: Control = entry.dots
	var y := dots.size.y * 0.5
	for i in entry.cells.size():
		var centre := Vector2(DOT_R + i * (DOT_R * 2.0 + DOT_GAP), y)
		match int(entry.cells[i]):
			0:
				dots.draw_circle(centre, DOT_R, Pal.SUN)
			1:
				dots.draw_circle(centre, DOT_R, Pal.MOON)
			_:
				dots.draw_arc(centre, DOT_R - 1.0, 0.0, TAU, 24, Color(Pal.MOON, 0.5), 2.0, true)
