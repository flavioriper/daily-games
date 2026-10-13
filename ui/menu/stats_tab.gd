extends VBoxContainer

## Stats: three totals, a difficulty strip, and every board's count, best and
## average time at that difficulty, on pages of two across and four down
## (2026-09-28: four across stopped fitting at twenty-nine boards, and a cell
## 240 wide could not letter "Solved: 1" and two times without spilling).
## Spec: docs/superpowers/specs/2026-09-24-stats-streak-design.md, section 4;
## redrawn 2026-09-25 to the user's mock: an icon plaque and a second line on
## each total (the streak one opens Streak), an icon on each chip, and each
## board's cell under its own home-card banner with a done seal.

signal open_streak

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Icons = preload("res://ui/icons.gd")
const Progress = preload("res://core/progress.gd")
const Streak = preload("res://core/streak.gd")
const PlayerStats = preload("res://core/player_stats.gd")
const Registry = preload("res://ui/registry.gd")
const Ink = preload("res://ui/menu/ink.gd")
const PagerPill = preload("res://ui/menu/pager_pill.gd")
const StreakTab = preload("res://ui/menu/streak_tab.gd")
const UiSound = preload("res://ui/ui_sound.gd")
const Motion = preload("res://core/motion.gd")

const GAP := 20
const TILE_H := 160.0
const PLAQUE := 100.0
const CHIP_H := 76.0
const CHIP_ICON := 40.0
const COLS := 2
const ROWS := 4
const PER_PAGE := COLS * ROWS
const CELL_GAP := 16.0
## The pager pill under the grid: the home pager's buttons and dots.
const PAGER_H := 64.0
## A turn: the page slides a share of its width out and the next one in.
const TURN_OUT := 0.12
const TURN_IN := 0.2
const TURN_SHIFT := 0.18
## A swipe past this many px sideways turns the page.
const SWIPE := 60.0
const SEAL_R := 18.0
## How far in from the cell's corner the seal stands, as on a home card.
const SEAL_IN := 38.0
const DIFFS := ["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD", "DIFF_INSANE"]
const CHIP_ICONS := ["leaf", "cloud", "mountain", "sparkle"]

var _log := {}
var _summary := {}
var _recent := {}
var _streak := {}
var _boards := {}
var _diff := 0
var _tiles_ci: Control
var _grid_ci: Control
var _page_ci: Control
var _seals_ci: Control
var _page := 0
var _pager: Control
var _pill: PagerPill
var _turn_tw: Tween
var _swipe_id := -2
var _swipe_from := Vector2.ZERO
var _streak_tap: Button
var _chips: Array[Button] = []
var _banners: Array[Control] = []
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
	_tiles_ci.resized.connect(_place_streak_tap)
	add_child(_tiles_ci)
	# The best-streak tile is the way to Streak, as the mock's chevron says.
	_streak_tap = Button.new()
	_streak_tap.flat = true
	_streak_tap.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		_streak_tap.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_streak_tap.pressed.connect(func() -> void: open_streak.emit())
	_tiles_ci.add_child(_streak_tap)
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", GAP)
	strip.custom_minimum_size.y = CHIP_H
	add_child(strip)
	for i in DIFFS.size():
		var chip := Button.new()
		chip.focus_mode = Control.FOCUS_NONE
		# The mock's chips are clean paper, not CozyTheme.dress()'s wash.
		chip.material = StreakTab.PLAIN
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.pressed.connect(_pick.bind(i))
		chip.draw.connect(_draw_chip.bind(i))
		strip.add_child(chip)
		_chips.append(chip)
	_grid_ci = Control.new()
	_grid_ci.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_ci.resized.connect(_place_banners)
	add_child(_grid_ci)
	# The page is its own layer so a turn slides it and not the pager.
	_page_ci = Control.new()
	_page_ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_ci.draw.connect(_draw_grid)
	_grid_ci.add_child(_page_ci)
	_build_pager()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _tiles_ci != null:
		_tiles_ci.queue_redraw()
		_page_ci.queue_redraw()
		for chip in _chips:
			chip.queue_redraw()

func refresh() -> void:
	_log = Progress.solve_log()
	_summary = PlayerStats.summary(_log)
	_recent = PlayerStats.recent(_log, Daily.date_key())
	_streak = Streak.compute(_log, Daily.date_key())
	_diff = Progress.stats_difficulty()
	_boards = PlayerStats.boards(_log, _diff)
	_build_banners()
	_say_figures()
	_dress_chips()
	_show_page()
	_tiles_ci.queue_redraw()

func _pick(i: int) -> void:
	if i == _diff:
		return
	Progress.set_stats_difficulty(i)
	_diff = i
	_boards = PlayerStats.boards(_log, _diff)
	_say_figures()
	_dress_chips()
	_page_ci.queue_redraw()
	_seals_ci.queue_redraw()

# --- the three totals ---

func _place_streak_tap() -> void:
	var w := (_tiles_ci.size.x - GAP * 2) / 3.0
	_streak_tap.position = Vector2(2 * (w + GAP), 0.0)
	_streak_tap.size = Vector2(w, TILE_H)

func _draw_tiles() -> void:
	var ci := _tiles_ci
	var w := (ci.size.x - GAP * 2) / 3.0
	var box := CozyTheme.lifted(Pal.SURFACE, 30, 0)
	var rows := [
		[str(int(_summary.get("solved", 0))), "STATS_SOLVED", "puzzle", Pal.LEAF_TILE, Pal.LEAF, Color.TRANSPARENT],
		[str(int(_summary.get("days", 0))), "STATS_DAYS", "calendar", Pal.ACORN_TILE, Pal.ACCENT_2, Color.TRANSPARENT],
		[str(int(_streak.get("best", 0))), "STATS_BEST_STREAK", "flame", Pal.BERRY_TILE, Pal.ACCENT_2, Pal.SUN_RAY],
	]
	for i in 3:
		var r := Rect2(i * (w + GAP), 0, w, TILE_H)
		ci.draw_style_box(box, r)
		var plaque := Rect2(r.position + Vector2(20, (TILE_H - PLAQUE) * 0.5), Vector2.ONE * PLAQUE)
		ci.draw_style_box(CozyTheme.card(rows[i][3], 26, Pal.LINE, 0, 0), plaque)
		var glyph := plaque.grow(-PLAQUE * 0.2)
		Icons.paint(ci, rows[i][2], glyph, rows[i][4], rows[i][5])
		if i == 1:
			# The mock's calendar carries a heart: a day played.
			var h := glyph.size.x * 0.34
			Icons.paint(ci, "heart", Rect2(glyph.position + glyph.size * Vector2(0.5, 0.66) - Vector2.ONE * h * 0.5,
				Vector2.ONE * h), rows[i][3])
		var x := plaque.end.x + 18.0
		var room := r.end.x - x - (44.0 if i == 2 else 16.0)
		Ink.text(ci, _big, rows[i][0], Vector2(x, 76), Ink.fit(_big, rows[i][0], 60, room), Pal.TEXT)
		var label := tr(rows[i][1])
		Ink.text(ci, _body, label, Vector2(x, 108), Ink.fit(_body, label, 26, room), Pal.TEXT_DIM)
		match i:
			0:
				var week := int(_recent.get("solved", 0))
				var col: Color = Pal.LEAF_DEEP if week > 0 else Pal.TEXT_DIM
				Icons.paint(ci, "trend", Rect2(x, 124, 24, 24), col)
				var line := tr("STATS_WEEK") % week
				Ink.text(ci, _body, line, Vector2(x + 32, 144), Ink.fit(_body, line, 20, room - 32), col)
			1:
				var played: Array = _recent.get("played", [])
				for d in played.size():
					var on := bool(played[d])
					ci.draw_circle(Vector2(x + 8 + d * 20, 136), 7.0,
						Pal.ACCENT_2 if on else Color(Pal.LINE, 0.35), true, -1.0, true)
			2:
				var going := int(_streak.get("current", 0)) > 0
				var line := tr("STATS_KEEP_GOING" if going else "STATS_START_STREAK")
				Ink.text(ci, _body, line, Vector2(x, 144), Ink.fit(_body, line, 22, room), Pal.ACCENT_2)
				Icons.paint(ci, "chevron_right", Rect2(r.end.x - 46, TILE_H * 0.5 - 20, 32, 40), Pal.TEXT_DIM)

# --- the difficulty strip ---

## Insane is the night chip, as on the difficulty sheet: ink fill, paper
## lettering, a sun ring when chosen. The others are paper, and the chosen one
## is SUN_TILE ringed in ACCENT_2.
func _dress_chips() -> void:
	for i in _chips.size():
		var on := i == _diff
		var night := i == 3
		var fill: Color = Pal.TEXT if night else (Pal.SUN_TILE if on else Pal.SURFACE)
		var box := CozyTheme.lifted(fill, int(CHIP_H * 0.5), 0)
		box.shadow_size = 8
		box.shadow_offset = Vector2(0.0, 4.0)
		if on:
			box.set_border_width_all(4)
			box.border_color = Pal.SUN if night else Pal.ACCENT_2
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			_chips[i].add_theme_stylebox_override(state, box)
		_chips[i].queue_redraw()

## The chip's icon and word, drawn over the Button's own stylebox as one
## centred pair.
func _draw_chip(i: int) -> void:
	var chip := _chips[i]
	var night := i == 3
	var ink: Color = Pal.PAPER if night else (Pal.ACCENT_2 if i == _diff else Pal.TEXT)
	var word := tr(DIFFS[i])
	var size := Ink.fit(_body, word, 30, chip.size.x - CHIP_ICON - 44.0)
	var tw := _body.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := (chip.size.x - (CHIP_ICON + 12.0 + tw)) * 0.5
	var icon := Rect2(x, (chip.size.y - CHIP_ICON) * 0.5, CHIP_ICON, CHIP_ICON)
	match i:
		0: Icons.paint(chip, "leaf", icon, Pal.LEAF)
		1: Icons.paint(chip, "cloud", icon, Pal.CLOUD)
		2: Icons.paint(chip, "mountain", icon, Pal.MOON_DEEP, Pal.SURFACE)
		3: Icons.paint(chip, "sparkle", icon, Pal.SUN)
	var base := chip.size.y * 0.5 + _body.get_ascent(size) * 0.5 - _body.get_descent(size) * 0.35
	Ink.text(chip, _body, word, Vector2(icon.end.x + 12.0, base), size, ink)

# --- the boards ---

## Each board's cell is its home card's own face (ui/menu/cards/<id>.gd),
## laid over the whole cell, saying the figures where the card says its
## blurb. Built on the first refresh rather than at startup, so a player who
## never opens Stats pays nothing for the pictures, and only the page's
## eight are shown.
func _build_banners() -> void:
	if not _banners.is_empty():
		return
	for i in Registry.PUZZLES.size():
		var entry: Dictionary = Registry.PUZZLES[i]
		var face: Control = load(String(entry["card"])).new(entry, Pal.CAT[i % Pal.CAT.size()])
		_page_ci.add_child(face)
		_banners.append(face)
	_say_figures()
	# The seals ride over every banner, so they are the last child.
	_seals_ci = Control.new()
	_seals_ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seals_ci.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_seals_ci.draw.connect(_draw_seals)
	_page_ci.add_child(_seals_ci)
	_place_banners()

func _pages() -> int:
	return maxi(1, ceili(Registry.PUZZLES.size() / float(PER_PAGE)))

## The boards on the page that is up, as registry indices.
func _on_page() -> Array[int]:
	var out: Array[int] = []
	for i in range(_page * PER_PAGE, mini((_page + 1) * PER_PAGE, Registry.PUZZLES.size())):
		out.append(i)
	return out

## The page's slot `k` (0..PER_PAGE-1), in the page layer's space: always
## four rows' height, so a short last page keeps its cells the same size.
func _cell(k: int) -> Rect2:
	var tw := (_page_ci.size.x - CELL_GAP * (COLS - 1)) / COLS
	var th := (_page_ci.size.y - CELL_GAP * (ROWS - 1)) / ROWS
	return Rect2((k % COLS) * (tw + CELL_GAP), (k / COLS) * (th + CELL_GAP), tw, th)

func _banner(cell: Rect2) -> Rect2:
	return cell

## What each face says under its name at this difficulty: how many solved
## over the best and the mean time, or that it is not solved yet.
func _say_figures() -> void:
	for i in _banners.size():
		var row: Dictionary = _boards.get(String(Registry.PUZZLES[i].id), {})
		var line := tr("STATS_NOT_YET")
		if int(row.get("count", 0)) > 0:
			line = "%s %d" % [tr("STATS_SOLVED"), int(row.count)]
			if float(row.get("best", 0.0)) > 0.0:
				line += " · %s %s\n%s %s" % [tr("STATS_BEST"), _mmss(row.best), tr("STATS_MEAN"), _mmss(row.mean)]
		_banners[i].say(line)

func _place_banners() -> void:
	var many := _pages() > 1
	var pager_room := PAGER_H + CELL_GAP if many else 0.0
	_page_ci.position.y = 0.0
	_page_ci.size = Vector2(_grid_ci.size.x, maxf(_grid_ci.size.y - pager_room, 0.0))
	_pager.visible = many
	_pager.position = Vector2(0.0, _grid_ci.size.y - PAGER_H)
	_pager.size = Vector2(_grid_ci.size.x, PAGER_H)
	if _seals_ci == null:
		return
	var shown := _on_page()
	for i in _banners.size():
		var k := shown.find(i)
		_banners[i].visible = k >= 0
		if k >= 0:
			var r := _banner(_cell(k))
			_banners[i].position = r.position
			_banners[i].size = r.size
	_page_ci.queue_redraw()
	_seals_ci.queue_redraw()

func _show_page() -> void:
	_page = clampi(_page, 0, _pages() - 1)
	_place_banners()
	_pill.show_page(_page, _pages())

## A cell: the banner, the title, then three figures side by side -- a
## small dim label over a bold value -- or one dim line for a board not yet
## solved at this difficulty.
func _draw_grid() -> void:
	var ci := _page_ci
	var box := CozyTheme.lifted(Pal.SURFACE, 36, 0)
	box.set_border_width_all(2)
	box.border_color = Color(Pal.LINE, 0.35)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0.0, 4.0)
	for k in _on_page().size():
		ci.draw_style_box(box, _cell(k))

## A green check seal on a board solved at this difficulty, an empty ring on
## one not yet: pinned over the banner's top right corner like the home card's.
func _draw_seals() -> void:
	var ci := _seals_ci
	var shown := _on_page()
	for k in shown.size():
		var b := _banner(_cell(k))
		var c := Vector2(b.end.x - SEAL_IN, b.position.y + SEAL_IN)
		var row: Dictionary = _boards.get(String(Registry.PUZZLES[shown[k]].id), {})
		if int(row.get("count", 0)) > 0:
			ci.draw_circle(c, SEAL_R + 3.0, Pal.SURFACE, true, -1.0, true)
			ci.draw_circle(c, SEAL_R, Pal.GOOD, true, -1.0, true)
			var s := SEAL_R
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.46, 0.02) * s,
				c + Vector2(-0.14, 0.34) * s, c + Vector2(0.48, -0.30) * s]), Pal.SURFACE, s * 0.3, true)
		else:
			ci.draw_circle(c, SEAL_R, Color(Pal.SURFACE, 0.7), true, -1.0, true)
			ci.draw_arc(c, SEAL_R, 0.0, TAU, 32, Color(Pal.LINE, 0.55), 2.5, true)

# --- the pager ---

## The pager every list of the first screen wears (ui/menu/pager_pill.gd).
func _build_pager() -> void:
	_pager = CenterContainer.new()
	_pager.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_ci.add_child(_pager)
	_pill = PagerPill.new(true)
	_pill.turned.connect(turn)
	_pager.add_child(_pill)

## Turns `by` pages (clamped): the page slides out towards the side it is
## leaving by, fading, and the next one slides in from the other side.
func turn(by: int) -> void:
	var want := clampi(_page + by, 0, _pages() - 1)
	if want == _page:
		return
	UiSound.page(self)
	if _turn_tw != null and _turn_tw.is_valid():
		_turn_tw.kill()
	var dir := signf(want - _page)
	var shift := _page_ci.size.x * TURN_SHIFT
	if Motion.reduce:
		_page = want
		_show_page()
		_page_ci.position.x = 0.0
		_page_ci.modulate.a = 1.0
		return
	_turn_tw = create_tween()
	_turn_tw.tween_property(_page_ci, "position:x", -dir * shift, TURN_OUT) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_turn_tw.parallel().tween_property(_page_ci, "modulate:a", 0.0, TURN_OUT)
	_turn_tw.tween_callback(func() -> void:
		_page = want
		_show_page()
		_page_ci.position.x = dir * shift)
	_turn_tw.tween_property(_page_ci, "position:x", 0.0, TURN_IN) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_turn_tw.parallel().tween_property(_page_ci, "modulate:a", 1.0, TURN_IN)

## A sideways swipe over the grid turns the page (finger left is next), read
## from touch and mouse alike, as the home grid's is.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _pages() < 2:
		_swipe_id = -2
		return
	var id := -2
	var pressed := false
	if event is InputEventScreenTouch:
		id = event.index
		pressed = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		id = -1
		pressed = event.pressed
	else:
		return
	var at: Vector2 = _grid_ci.make_input_local(event).position
	if pressed:
		if _swipe_id == -2 and Rect2(Vector2.ZERO, _page_ci.size).has_point(at):
			_swipe_id = id
			_swipe_from = at
	elif id == _swipe_id:
		_swipe_id = -2
		var d := at - _swipe_from
		if absf(d.x) > SWIPE and absf(d.x) > absf(d.y) * 1.5:
			UiSound.hush()
			turn(1 if d.x < 0.0 else -1)

func _mmss(t: float) -> String:
	var s := int(round(t))
	return "%d:%02d" % [s / 60, s % 60]
