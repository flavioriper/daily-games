extends VBoxContainer

## Stats: three totals, a difficulty strip, and every board's count, best and
## average time at that difficulty, four across with no scroll (20 boards
## fit at 1080x1920; a 21st makes a sixth row out of the tile height).
## Spec: docs/superpowers/specs/2026-09-24-stats-streak-design.md, section 4.

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Progress = preload("res://core/progress.gd")
const Streak = preload("res://core/streak.gd")
const PlayerStats = preload("res://core/player_stats.gd")
const Registry = preload("res://ui/registry.gd")
const Ink = preload("res://ui/menu/ink.gd")

const GAP := 20
const TILE_H := 190.0
const CHIP_H := 96.0
const COLS := 4
const CELL_GAP := 16.0
const DIFFS := ["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD", "DIFF_INSANE"]
const UNSOLVED_ALPHA := 0.6

var _log := {}
var _summary := {}
var _best := 0
var _boards := {}
var _diff := 0
var _tiles_ci: Control
var _grid_ci: Control
var _chips: Array[Button] = []
var _big: Font
var _head: Font
var _body: Font

func _init() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big = CozyTheme.display(700)
	_head = CozyTheme.display(700)
	_body = CozyTheme.body(800)
	_tiles_ci = Control.new()
	_tiles_ci.custom_minimum_size.y = TILE_H
	_tiles_ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tiles_ci.draw.connect(_draw_tiles)
	add_child(_tiles_ci)
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", GAP)
	strip.custom_minimum_size.y = CHIP_H
	add_child(strip)
	for i in DIFFS.size():
		var chip := Button.new()
		chip.text = DIFFS[i]
		chip.focus_mode = Control.FOCUS_NONE
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_override("font", _body)
		chip.add_theme_font_size_override("font_size", 32)
		chip.pressed.connect(_pick.bind(i))
		strip.add_child(chip)
		_chips.append(chip)
	_grid_ci = Control.new()
	_grid_ci.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_ci.draw.connect(_draw_grid)
	add_child(_grid_ci)

func refresh() -> void:
	_log = Progress.solve_log()
	_summary = PlayerStats.summary(_log)
	_best = int(Streak.compute(_log, Daily.date_key()).best)
	_diff = Progress.stats_difficulty()
	_boards = PlayerStats.boards(_log, _diff)
	_dress_chips()
	_tiles_ci.queue_redraw()
	_grid_ci.queue_redraw()

func _pick(i: int) -> void:
	if i == _diff:
		return
	Progress.set_stats_difficulty(i)
	_diff = i
	_boards = PlayerStats.boards(_log, _diff)
	_dress_chips()
	_grid_ci.queue_redraw()

## Insane is the night chip, as on the difficulty sheet: ink fill, paper
## lettering, a sun ring when chosen. The others are paper, and the chosen one
## is SUN_TILE ringed in ACCENT_2.
func _dress_chips() -> void:
	for i in _chips.size():
		var on := i == _diff
		var night := i == 3
		var fill: Color = Pal.TEXT if night else (Pal.SUN_TILE if on else Pal.SURFACE)
		var ring: Color = (Pal.SUN if night else Pal.ACCENT_2) if on else Pal.LINE
		var ink: Color = Pal.PAPER if night else (Pal.ACCENT_2 if on else Pal.TEXT)
		var box := CozyTheme.card(fill, 30, ring, 5 if on else 3, 0)
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			_chips[i].add_theme_stylebox_override(state, box)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			_chips[i].add_theme_color_override(c, ink)

func _mmss(t: float) -> String:
	var s := int(round(t))
	return "%d:%02d" % [s / 60, s % 60]

func _draw_tiles() -> void:
	var ci := _tiles_ci
	var w := (ci.size.x - GAP * 2) / 3.0
	var rows := [
		[str(int(_summary.get("solved", 0))), "STATS_SOLVED"],
		[str(int(_summary.get("days", 0))), "STATS_DAYS"],
		[str(_best), "STATS_BEST_STREAK"],
	]
	for i in 3:
		var r := Rect2(i * (w + GAP), 0, w, TILE_H)
		ci.draw_style_box(CozyTheme.card(Pal.SURFACE, 30, Pal.LINE, 6, 0), r)
		Ink.text(ci, _big, rows[i][0], Vector2(r.get_center().x, 104), 72, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		Ink.text(ci, _body, tr(rows[i][1]), Vector2(r.get_center().x, 156), 30, Pal.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_grid() -> void:
	var ci := _grid_ci
	var n := Registry.PUZZLES.size()
	var rows := int(ceil(n / float(COLS)))
	var tw := (ci.size.x - CELL_GAP * (COLS - 1)) / COLS
	var th := (ci.size.y - CELL_GAP * (rows - 1)) / rows
	var box := CozyTheme.card(Pal.SURFACE, 24, Pal.LINE, 4, 0)
	var faded := _faded(box, UNSOLVED_ALPHA)
	for i in n:
		var entry: Dictionary = Registry.PUZZLES[i]
		var row: Dictionary = _boards.get(String(entry.id), {})
		var solved := int(row.get("count", 0)) > 0
		var a := 1.0 if solved else UNSOLVED_ALPHA
		var r := Rect2((i % COLS) * (tw + CELL_GAP), (i / COLS) * (th + CELL_GAP), tw, th)
		ci.draw_style_box(box if solved else faded, r)
		var dot: Color = Pal.CAT[i % Pal.CAT.size()]
		ci.draw_circle(r.position + Vector2(28, 38), 11, Color(dot, dot.a * a))
		var title := String(entry.title)
		var size := Ink.fit(_head, title, 30, tw - 60)
		Ink.text(ci, _head, title, r.position + Vector2(48, 49), size, Color(Pal.TEXT, a))
		if solved:
			Ink.text(ci, _body, tr("STATS_COUNT") % int(row.count), r.position + Vector2(20, th * 0.58), 28, Pal.TEXT)
			if float(row.best) > 0.0:
				Ink.text(ci, _body, "%s · %s" % [_mmss(row.best), _mmss(row.mean)],
					r.position + Vector2(20, th * 0.82), 26, Pal.TEXT_DIM)
		else:
			Ink.text(ci, _body, "—", r.position + Vector2(20, th * 0.66), 34, Color(Pal.TEXT_DIM, a))

func _faded(box: StyleBoxFlat, a: float) -> StyleBoxFlat:
	var b := box.duplicate() as StyleBoxFlat
	b.bg_color.a *= a
	b.border_color.a *= a
	return b
