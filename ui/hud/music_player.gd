extends PanelContainer

## The soundtrack's player on the settings sheet, every screen's one door to
## it (the user, 2026-11-01: "something like spotify widget"): the track's name
## and place in the list, play or pause, next, then mute and the volume bar.
## core/music.gd holds the state; this only shows it and passes the taps on.

const Music = preload("res://core/music.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const SheetParts = preload("res://ui/hud/sheet_parts.gd")
const Pal = preload("res://core/palette.gd")

const TINT := Color("a8cf9a")
const INK := Color("6aa477")
const ROUND := 92.0
const PLAQUE := 80.0
const BAR_H := 84.0
const TRACK_H := 14.0
const KNOB := 22.0

var title_label: Label
var sub_label: Label
var play_button: Button
var next_button: Button
var mute_button: Button
var bar: Bar

## The volume: a thick line with a knob, as wide as the row is left. A press
## anywhere on it jumps there and a drag follows, by touch or by mouse.
class Bar extends Control:
	const Music = preload("res://core/music.gd")
	const Pal = preload("res://core/palette.gd")
	const UiSound = preload("res://ui/ui_sound.gd")
	var _finger := -1
	var _mouse := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size.y = BAR_H
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch:
			if ev.pressed and _finger < 0:
				_finger = ev.index
				_press(ev.position.x)
			elif not ev.pressed and ev.index == _finger:
				_finger = -1
				_lift(ev.position.x)
			accept_event()
		elif ev is InputEventScreenDrag and ev.index == _finger:
			_take(ev.position.x, false)
			accept_event()
		elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_mouse = true
				_press(ev.position.x)
			elif _mouse:
				_mouse = false
				_lift(ev.position.x)
			accept_event()
		elif ev is InputEventMouseMotion and _mouse:
			_take(ev.position.x, false)
			accept_event()

	func _press(x: float) -> void:
		UiSound.click(self)
		_take(x, false)

	func _lift(x: float) -> void:
		_take(x, true)

	func _take(x: float, save: bool) -> void:
		var inset := KNOB
		Music.set_volume(clampf((x - inset) / max(size.x - inset * 2.0, 1.0), 0.0, 1.0), save)

	func _draw() -> void:
		var y := size.y * 0.5
		var left := KNOB
		var width := size.x - KNOB * 2.0
		var at := 0.0 if Music.muted else Music.volume
		var groove := StyleBoxFlat.new()
		groove.bg_color = Color(Pal.LINE, 0.55)
		groove.set_corner_radius_all(int(TRACK_H * 0.5))
		groove.anti_aliasing_size = 1.0
		draw_style_box(groove, Rect2(left, y - TRACK_H * 0.5, width, TRACK_H))
		var fill := StyleBoxFlat.new()
		fill.bg_color = INK
		fill.set_corner_radius_all(int(TRACK_H * 0.5))
		fill.anti_aliasing_size = 1.0
		draw_style_box(fill, Rect2(left, y - TRACK_H * 0.5, max(width * at, TRACK_H), TRACK_H))
		var x := left + width * at
		draw_circle(Vector2(x, y + 2.0), KNOB, Color(0.3, 0.2, 0.1, 0.14), true, -1.0, true)
		draw_circle(Vector2(x, y), KNOB - 1.0, Pal.SURFACE, true, -1.0, true)
		draw_circle(Vector2(x, y), KNOB - 10.0, INK, true, -1.0, true)

func _init() -> void:
	name = "MusicPlayer"
	add_theme_stylebox_override("panel", _face())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	col.add_child(top)
	var plaque := SheetParts.Plaque.new("music", TINT, PLAQUE)
	plaque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(plaque)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	top.add_child(words)
	title_label = _words(words, CozyTheme.body(800), 36, Pal.TEXT)
	sub_label = _words(words, CozyTheme.body(600), 27, Pal.TEXT_DIM)
	play_button = _round("play")
	play_button.pressed.connect(Music.toggle)
	top.add_child(play_button)
	next_button = _round("next")
	next_button.pressed.connect(Music.next)
	top.add_child(next_button)
	var low := HBoxContainer.new()
	low.add_theme_constant_override("separation", 14)
	col.add_child(low)
	mute_button = _round("speaker")
	mute_button.pressed.connect(func() -> void: Music.set_muted(not Music.muted))
	low.add_child(mute_button)
	bar = Bar.new()
	low.add_child(bar)

func _face() -> StyleBox:
	var face: StyleBox = CozyTheme.soft_button(Pal.SURFACE, 26, false, 0).duplicate()
	if face is StyleBoxFlat:
		var flat := face as StyleBoxFlat
		flat.content_margin_left = 24.0
		flat.content_margin_right = 24.0
		flat.content_margin_top = 18.0
		flat.content_margin_bottom = 14.0
	return face

func _words(into: VBoxContainer, font: Font, size_px: int, ink: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", ink)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	into.add_child(l)
	return l

func _round(icon: String) -> Button:
	var b := IconButton.new(icon, "", "IconButton")
	b.custom_minimum_size = Vector2(ROUND, ROUND)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var r := int(ROUND * 0.5)
	var up := CozyTheme.soft_button(Pal.BG, r, false, 0)
	var down := CozyTheme.soft_button(Pal.BG, r, true, 0)
	for s in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(s, up)
	b.add_theme_stylebox_override("pressed", down)
	return b

func _enter_tree() -> void:
	Music.news.changed.connect(refresh)
	refresh()

func _exit_tree() -> void:
	Music.news.changed.disconnect(refresh)

func refresh() -> void:
	title_label.text = Music.title()
	if Music.held():
		sub_label.text = tr("MUSIC_HELD")
	elif not Music.playing:
		sub_label.text = tr("MUSIC_PAUSED")
	else:
		sub_label.text = tr("MUSIC_TRACK_OF") % [Music.index + 1, Music.TRACKS.size()]
	_glyph(play_button, "pause" if Music.playing else "play")
	_glyph(mute_button, "speaker_off" if Music.muted or Music.volume <= 0.0 else "speaker")
	bar.queue_redraw()

func _glyph(b: Button, icon: String) -> void:
	if b.icon_name != icon:
		b.icon_name = icon
		b.queue_redraw()
		for c in b.get_children():
			if c is Control:
				(c as Control).queue_redraw()
