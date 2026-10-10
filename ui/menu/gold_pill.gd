extends Button

## The gold: a coin and the count on a paper pill, following the Wallet
## (core/wallet.gd). The count rolls to a new total rather than jumping, and
## `fly_from()` throws coins from a point on the screen into the pill, each
## one bumping it as it lands, before the count catches up. Pressing it is
## the host's to wire (the shop, usually).
## Spec docs/superpowers/specs/2026-09-28-gold-gifts-design.md, section 4.

const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Haptics = preload("res://core/haptics.gd")

const H := 84.0
const COIN := 30.0
const GOLD := Color("f2b632")
const GOLD_DEEP := Color("c98a16")
const GOLD_HI := Color("ffe39a")
const FLIGHT := 0.62
## The clink's climb: a coin's tick is 0.03 up on the last, so the twelve of
## the biggest gift top out at 1.33, inside five semitones (it was 0.05 a
## coin, 1.55 at the twelfth: 7.6 semitones). One draw a throw moves the whole
## run, so no two gifts count alike and the climb stays a climb.
const CLINK_STEP := 0.03
const CLINK_VARY := Vector2(0.94, 1.06)

var _shown := 0.0
## Gold still in the air: the count holds it back until the coins land.
var _held := 0
var _label: Label
var _air: Control
var _coins: Array = []   # {from, to, t, delay, share}
## A tick for each coin that lands, a little higher each time.
var _clink: AudioStreamPlayer
var _landed := 0
var _vary := 1.0
## The running bump or squash. Motion.bump returns to the scale it found, so
## coins landing 0.05 s apart inside a 0.16 s bump each took the last one's
## swell as their rest and the pill was left stuck big; every kick kills the
## last and starts from one.
var _kick_tw: Tween

func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(220, H)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := CozyTheme.lifted(Pal.SURFACE, int(H * 0.5), 8)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(s, box)

func _ready() -> void:
	_label = Label.new()
	_label.theme_type_variation = "SheetTitle"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = COIN * 2.0 + 30.0
	_label.offset_right = -24.0
	add_child(_label)
	_air = Control.new()
	_air.top_level = true
	_air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_air.z_index = 20
	_air.draw.connect(_draw_air)
	add_child(_air)
	_clink = AudioStreamPlayer.new()
	_clink.bus = &"Master"
	if ResourceLoader.exists("res://assets/sfx/wallet/coin.ogg"):
		_clink.stream = load("res://assets/sfx/wallet/coin.ogg")
	_clink.max_polyphony = 4
	add_child(_clink)
	_shown = Wallet.gold()
	Wallet.changed.connect(_on_changed)
	button_down.connect(func() -> void: _kick(Motion.squash.bind(self, 0.08, 0.18)))
	_write()
	set_process(false)

func _on_changed() -> void:
	set_process(true)

func _write() -> void:
	_label.text = Locale.number(int(round(_shown)))
	var w := _label.get_theme_font("font").get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		_label.get_theme_font_size("font_size")).x
	custom_minimum_size.x = maxf(220.0, w + COIN * 2.0 + 30.0 + 40.0)

## Runs `recipe` (a Motion scale recipe bound to this pill) from rest, about
## the pill's centre.
func _kick(recipe: Callable) -> void:
	Motion.stop(_kick_tw)
	scale = Vector2.ONE
	pivot_offset = size * 0.5
	_kick_tw = recipe.call()

## Throws `amount` gold's worth of coins from `global_at` into the pill.
func fly_from(global_at: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	if Motion.reduce or not is_visible_in_tree():
		return
	var n := clampi(amount / 15, 4, 12)
	_held += amount
	_landed = 0
	_vary = randf_range(CLINK_VARY.x, CLINK_VARY.y)
	var share := amount / n
	var to := get_global_rect().position + Vector2(COIN + 16.0, H * 0.5)
	for i in n:
		var s := share if i < n - 1 else amount - share * (n - 1)
		_coins.append({"from": global_at + Vector2(randf_range(-40, 40), randf_range(-30, 30)), "to": to,
			"t": 0.0, "delay": 0.05 * i, "share": s, "lift": randf_range(120.0, 260.0)})
	set_process(true)

func _process(delta: float) -> void:
	for c: Dictionary in _coins:
		c.t += delta
		if c.t - c.delay >= FLIGHT and not c.get("done", false):
			c.done = true
			_held = maxi(0, _held - int(c.share))
			_kick(Motion.bump.bind(self, 0.08, 0.16))
			if _clink.stream != null:
				_clink.pitch_scale = (1.0 + CLINK_STEP * _landed) * _vary
				_clink.play()
				# What is heard is felt: each coin's clink, climbing with it.
				Haptics.play(Haptics.ECHO, 1.0 + 0.1 * _landed)
			_landed += 1
	_coins = _coins.filter(func(c: Dictionary) -> bool: return not c.get("done", false))
	_air.size = get_viewport_rect().size
	_air.queue_redraw()
	var want := float(Wallet.gold() - _held)
	if Motion.reduce:
		_shown = want
	else:
		_shown = move_toward(_shown, want, (40.0 + absf(want - _shown) * 8.0) * delta)
	_write()
	if _coins.is_empty() and is_equal_approx(_shown, want):
		_air.queue_redraw()
		set_process(false)

func _draw() -> void:
	coin(self, Vector2(COIN + 16.0, size.y * 0.5), COIN)

func _draw_air() -> void:
	for c: Dictionary in _coins:
		var k := clampf((float(c.t) - float(c.delay)) / FLIGHT, 0.0, 1.0)
		if float(c.t) < float(c.delay):
			continue
		var e := k * k * (3.0 - 2.0 * k)
		var p: Vector2 = (c.from as Vector2).lerp(c.to, e) - Vector2(0, sin(k * PI) * float(c.lift))
		coin(_air, p - _air.global_position, COIN * lerpf(1.1, 0.8, k))

## A gold coin with a rim, a mark and a shine, drawn into `ci` at `c`.
static func coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c + Vector2(0, r * 0.12), r, GOLD_DEEP)
	ci.draw_circle(c, r, GOLD)
	ci.draw_arc(c, r * 0.72, 0.0, TAU, 28, GOLD_DEEP, maxf(2.0, r * 0.1), true)
	ci.draw_line(c + Vector2(0, -r * 0.34), c + Vector2(0, r * 0.34), GOLD_DEEP, maxf(2.0, r * 0.16), true)
	ci.draw_arc(c, r * 0.86, PI * 1.1, PI * 1.45, 10, GOLD_HI, maxf(2.0, r * 0.12), true)
