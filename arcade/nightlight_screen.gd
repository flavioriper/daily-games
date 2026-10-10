extends Control

## Nightlight: the seventh game on the Arcade tab, and the one that is kept.
## A star in the middle of a night sky, after a real one (the user,
## 2026-10-06: "I want something that is closer to the star lifecycle"). The
## star is born in a ring of gas that circles it outside its disc and never
## falls by itself, and the player's hand is on the sky: a press brakes what
## is under the finger, held it keeps braking (2026-10-07: "user can click
## into regions to slow it down and make it fall"), and what was braked
## drops into the disc. The gas winds in and feeds the star, and on its way
## round makes grains, rocks and planets that stay; bodies cross the sky on
## their own and the heavier the star the more of them it bends in. Mass
## grows the star, counted in Suns (a new star is
## one). It burns hydrogen into helium and, as its core grows, on up the
## chain to iron, which ends it as a supernova without being asked; a star
## left with nothing to burn lets its layers go instead. Light, which the
## disc makes of whatever it drags and the star of what it burns, buys the
## hand's four tiles; as the star grows it is offered two powers and one is
## picked; an end gives everything back to the sky, leaves a small star
## among the gas and pays stardust for a perk that lasts. Specs, all in
## docs/superpowers/specs/: 2026-10-06-arcade-nightlight-design.md, then
## 2026-10-07-nightlight-universe-design.md (the relics, the three ends, the
## camera) and 2026-10-07-nightlight-ring-design.md (the ring and the press;
## its section 22 is the game as built). The rules
## and every number are arcade/nightlight_sim.gd's, the sky is
## arcade/nightlight_sky.gd's, the drawings nightlight_art.gd's.
##
## Like the Grove it has no round, no score and no end, so none of the
## Arcade's end card, record, boosters or Second chance: the star is read
## from its file as the screen opens, exactly as it was left (nothing
## happens while the game is closed), and written back as tiles are bought,
## every few seconds while it eats, and as it is left. ui/menu.gd mounts it
## over the list (`_open_arcade`) and it joins the `versus_host` group so
## Android's back reaches it.

signal closed

const Sim = preload("res://arcade/nightlight_sim.gd")
const Art = preload("res://arcade/nightlight_art.gd")
const NightSky = preload("res://arcade/nightlight_sky.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const ScreenTutor = preload("res://ui/hud/screen_tutor.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Analytics = preload("res://core/analytics.gd")
const Motes = preload("res://ui/motes.gd")

const GAME := "nightlight"
const MARGIN := 40
const GAP := 20
const HUD_H := 96.0
const NOVA_H := 44.0
const INFO_H := 104.0
const SHOP_W := 250.0
const DUST_W := 170.0
## The shop's card and a tile of it, as the Grove's are: its picture on a
## disc, its name over what the next level does, its price on a bar.
const CARD_W := 1000.0
const CARD_INSET := 26
const X_SIZE := 84.0
const TILE_H := 344.0
const TILE_PAD := 14.0
const TILE_GAP := 16
const DISC_R := 60.0
const PRICE_H := 64.0
const PRICE_R := 20
const PRICE_OFF := Color("ede4d3")
const FILL := Color("fcf7ef")
## The star stands a little above the field's middle.
const STAR_AT := 0.47
## Light is motes, the other games' energy in gold: `ORBS` to one light.
## What the disc drags out of a body comes a piece at a time, a mote each;
## a solid the star eats pays all it still owes at once (a planet about one
## light, twenty pieces' worth), and that is a mote for each orb of it,
## SHED_ORBS at most: a handful of lights, all of it counted on the plate
## whatever is drawn.
const ORBS := 4
const SHED_ORBS := 12
const SAVE_GAP := 5.0
## A press that braked something is a piece set down; a tile bought and a
## stage lit are something finished; a tile that cannot be bought is a not
## yet; the supernova is the heaviest thing here, and a star letting go a
## soft one.
##
## The sounds (assets/sfx/nightlight, tools/gen_sfx.py nightlight; the user,
## 2026-10-06: "generate and wire the cozy sounds to the nightlight"). What
## goes on for as long as the game does is a click and plays through
## `_quiet`, which knocks for nothing: a mote of light landing (`light`, a
## short run up) and a solid falling into the star (`eat`, lower and louder
## the bigger it was, one in EAT_GAP at most). A press that braked something
## is `pour`, as often as it is felt. The rest happens now and then: `tear`
## (one in TEAR_GAP: a torn body's pieces are torn again), `ignite`, `dim`,
## `wake`, `pick` as the two powers come up, `perk`, `buy`, `no`, `nova`,
## `fade`, and `born` as the small star comes up after an end or a Start
## over. A grain forming, two bodies meeting and gas eaten are silent:
## several a second.
## The set was heard on 2026-10-09 and was "too harsh": the files are
## darker and 4 to 6 dB down, and what is added here is less (`light` at -6
## up LIGHT_RUN semitones, `eat` at -4 at most; -2 since the redo below).
## Redone on 2026-10-10 against the cozy rules (docs/agents/sound.md): made
## dark and quiet, a phone did not play ten of the fourteen. The ticks are
## wood on felt at 530 to 750 Hz (`pour` a block, `light`, `eat`, `pick` and
## `no` a lighter button), the star's life and its ends phrases of one
## muffled kalimba note, `tear` a puff of air. So nothing is played higher
## to be heard (LOW_TAP), `eat` is held inside five semitones and has 2 dB
## back (EAT_PITCH), and the ticks under a finger vary by TICK_VARY.
const EAT_GAP := 0.12
## `eat` by the body's radius: 1.0 for the smallest down to 0.8, which with
## its 3% either way is inside five semitones. It was
## clampf(1.25 - 0.045 * r, 0.7, 1.15), near nine.
const EAT_PITCH := Vector3(1.044, 0.02, 0.8)
## A tick that repeats is never the same twice: this much either way.
const TICK_VARY := 0.06
## The run of `light` clicks climbs this many semitones and stays there: a
## whole octave up, the tick was the sharpest thing in the game (the user,
## 2026-10-09: "too harsh").
const LIGHT_RUN := 5
## `light` and `pour` were dull taps whose body sat under 300 Hz, where a
## phone's speaker has nothing, and were played 1.6 times higher. Their
## takes sit at 630 and 740 Hz since 2026-10-10 and are played as they are:
## at 1.6 the run of `light` would top out at 1.35 kHz.
const LOW_TAP := 1.0
const TEAR_GAP := 0.3
## The supernova's take was a breath and then the thump: it is started this
## long before the core has fallen in, so the thump was the layers leaving.
## Since 2026-10-10 it is six notes up and over with no thump, and the top
## note is written this far in (tools/gen_sfx.py, `nova`).
const NOVA_LEAD := 0.65
const HAPTICS := {"pour": Haptics.TAP, "buy": Haptics.BUMP, "perk": Haptics.BUMP, "no": Haptics.WARN, "ignite": Haptics.BUMP, "nova": Haptics.THUD,
	"fade": Haptics.BUMP}
const TILE_NAMES := {"reach": "NL_REACH", "flow": "NL_STREAM", "rich": "NL_RICH", "pure": "NL_PURE"}
const POWER_NAMES := {"wind": "NL_POW_WIND", "haze": "NL_POW_HAZE", "beacon": "NL_POW_BEACON", "radiance": "NL_POW_RADIANCE",
	"furnace": "NL_POW_FURNACE", "fusion": "NL_POW_FUSION", "thrift": "NL_POW_THRIFT"}
## What the star is made of, in Sim.CHAIN's order: the elements by their
## symbols, which are the same in every language, and rock by its name.
const MADE_NAMES := ["H", "He", "C", "Ne", "O", "Si", "Fe", "NL_ROCK"]
## What the sky says as each stage of the chain lights.
const LIT_NAMES := ["", "NL_LIT_HE", "NL_LIT_C", "NL_LIT_NE", "NL_LIT_O", "NL_LIT_SI"]
const GOALS := {"he": "NL_GOAL_HE", "c": "NL_GOAL_C", "fe": "NL_GOAL_FE"}
## Seconds a line stays over the sky, the last NOTE_OUT of them going.
const NOTE := 5.0
const NOTE_OUT := 0.6
## The light's plate, beside the shop that spends it.
const LIGHT_W := 220.0
## What the star is made of: its bar's height.
const MADE_H := 14.0
## A pick's tile, and the seconds the star has grown past a pick before the
## card comes up. A card that comes up by itself (a pick, the perks after an
## end) never comes up under a finger: not while one is on the sky nor for
## OFFER_CALM seconds after the last one lifted. Once it is up, a press that
## lands in its first PICK_DEAF seconds does nothing, whenever it lifts: a
## tile answers as the finger lifts, and a hold is what this game teaches.
const PICK_H := 440.0
const PICK_WAIT := 0.6
const OFFER_CALM := 0.6
const PICK_DEAF := 0.5
## A power held, on a disc in the sky's corner.
const CHIP := 68.0
const CHIP_GAP := 10.0
## The line that names the system: where it starts on the sky, and its top
## with no power held (under the discs when there are any).
const SYSTEM_X := 28.0
const SYSTEM_Y := 22.0
## The sim's bodies are counted for that line this often, in seconds.
const SYSTEM_EVERY := 0.25
## A held finger's brakes are heard and felt this often at most, in seconds.
const FELT := 0.2
## A touch that also arrives as a mouse press (were mouse-from-touch or
## touch-from-mouse ever turned on) is one press: a press of the other kind
## within this many milliseconds is dropped.
const TWICE_MS := 60
## The fuel's clock reddens under this many seconds.
const LOW := 10.0
const PERK_NAMES := {"core": "NL_PERK_CORE", "disc": "NL_PERK_DISC", "hand": "NL_PERK_HAND", "crowd": "NL_PERK_CROWD",
	"ember": "NL_PERK_EMBER"}

var sim: RefCounted
var top_bar: Control
var settings_sheet: Control
var tutor: RefCounted
var sky: Control
var _fx: Node2D
var _quiet: Node2D
var _ate_at := -1000
var _tore_at := -1000
var _end_cued := false
var _motes: Control
var _margins: MarginContainer
var _plates := {}   # "light" -> {panel, icon, label}
var _cells := {}    # "mass" / "temp" / "fuel" -> Label
var _made: Control
var _made_l: Array[Label] = []
var _fuel_low := false
var _hint: Label
## True once a press of this visit has braked something: the hint has been
## read. Not kept, so it is said again each time the game is opened.
var _braked := false
var _chips: Button
var _chips_for := ""
var _system: Label
var _system_for := ""
var _system_wait := 0.0
var _pick: Control
var _pick_title: Label
var _pick_tiles: Array = []   # {button, icon, name, effect, cost, badge, level}
var _pick_now: Array = []
var _pick_wait := 0.0
## The perks an end owes, until no finger is in their way.
var _perks_due := false
## Over every card for PICK_DEAF seconds after one came up by itself at
## `_raised_at`: the presses that land then land on it, and their lifts too.
var _shield: Control
var _raised_at := -100000
var _powers: Control
var _powers_list: VBoxContainer
var _reset: Control
var _felt_at := -1000
var _shown := {"mass": 0.0, "light": 0.0}
var _bump := {}
var _dust_b: Button
var _dust_l: Label
var _nova_line: Control
var _nova_l: Label
var _pick_l: Label
var _note: Label
var _note_t := 0.0
var _shop_b: Button
var _shop: Control
var _shop_light: Label
var _tiles := {}    # tile -> {button, icon, effect, pill, cost, mote, tick, badge, level}
var _tiles_for := ""
var _perks: Control
var _perk_dust: Label
var _perk_buy: Button
var _perk_tiles := {}   # perk -> {panel, count}
## Fingers down on the sky: index (-1 the mouse) to where it is, in the sky's
## pixels, and the seconds since it last braked.
var _fingers := {}
## Every finger on the sky, read or not (under a card, through an end): what
## a card that comes up by itself waits for.
var _touching := {}
var _lifted_at := -100000
var _pressed_at := -100000
var _pressed_mouse := false
var _held_back := false
var _end_how := ""
var _end_done := false
## What the end being played leaves (Sim.Relic), read as it begins: once the
## sim has ended, `remnant()` has nothing to say.
var _end_rem := 0
## The sky is playing a star's birth (a first star, a Start over): it holds
## the sim like an end, but there is nothing to end and no perks after it.
var _birth := false
var _dirty := false
var _since_save := 0.0
var _opened_at := 0
var _eaten_at_open := 0.0

func puzzle_id() -> String:
	return GAME

func _ready() -> void:
	add_to_group("versus_host")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	sim = Sim.load_saved()
	_opened_at = Time.get_ticks_msec()
	_eaten_at_open = sim.eaten
	_shown.mass = sim.mass
	_shown.light = sim.light
	_build()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	tutor = ScreenTutor.new(self, puzzle_id(), "Nightlight", _tutor_hold)
	tutor.wire(top_bar, settings_sheet)
	settings_sheet.with_reset = true
	settings_sheet.start_over.connect(open_reset)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	top_bar.refresh(self)
	_refresh_tiles()
	_refresh_hud(0.0)
	# a first star, with no file before it, comes up out of its cloud
	if sim.fresh:
		_begin_birth()
	Analytics.track("nightlight_enter", {"mass": int(sim.mass), "novas": sim.novas})

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		# its lift may never be told
		_touching.clear()
		_drop_fingers()
		_save()
	elif what == NOTIFICATION_EXIT_TREE:
		_save()

# --- building ---

func _build() -> void:
	var page := ColorRect.new()
	page.color = Pal.PAPER
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	_margins.add_child(col)

	top_bar = FlatTopBar.new("Nightlight", tr("NL_MOTTO"), false)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.settings.connect(func() -> void:
		_drop_fingers()
		settings_sheet.open())
	col.add_child(top_bar)

	col.add_child(_star_panel())

	# the way to the next power and to the supernova: a bar, and what it
	# would pay
	_nova_line = Control.new()
	_nova_line.name = "NovaLine"
	_nova_line.custom_minimum_size.y = NOVA_H
	_nova_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nova_line.draw.connect(_draw_nova_line)
	_nova_l = Label.new()
	_nova_l.theme_type_variation = "CardBlurb"
	_nova_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_nova_l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_nova_line.add_child(_nova_l)
	_pick_l = Label.new()
	_pick_l.theme_type_variation = "CardBlurb"
	_pick_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pick_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_pick_l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_nova_line.add_child(_pick_l)
	col.add_child(_nova_line)

	sky = NightSky.new()
	sky.name = "Field"
	sky.sim = sim
	sky.paper = Pal.PAPER
	sky.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# the sky is the hand's: a press on it brakes what is under the finger.
	# It took no press for a day (the user, 2026-10-06: "instead of user
	# clicking anywhere on screen to place items, let's add buttons near
	# bottom ... right now it happens that user click on the screen to place
	# item and click on upgrade that popup"), and the user took that back on
	# 2026-10-07 ("user can click into regions to slow it down and make it
	# fall"), with the pick card still coming up by itself, guarded. The
	# guard is `_deaf()` (no press is read under a card), `_offer` (no card
	# comes up by itself under a finger) and `_raised` (a press that lands as
	# such a card shows does nothing, whenever it lifts)
	sky.mouse_filter = Control.MOUSE_FILTER_STOP
	sky.gui_input.connect(_on_sky_input)
	sky.resized.connect(_layout_field)
	col.add_child(sky)
	# what the star has just done, said once over the sky's head
	_note = Label.new()
	_note.name = "Note"
	_note.theme_type_variation = "CardBlurb"
	_note.add_theme_color_override("font_color", Art.VEIL)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_note.offset_left = 120.0
	_note.offset_right = -120.0
	_note.offset_top = 26.0
	_note.modulate.a = 0.0
	sky.add_child(_note)
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "NL_HINT"
	hint.theme_type_variation = "CardBlurb"
	hint.add_theme_color_override("font_color", Color(Art.VEIL, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_bottom = -26.0
	sky.add_child(hint)
	_hint = hint
	# the powers held, down the sky's left edge: pressed, they say what they do
	_chips = Button.new()
	_chips.name = "Powers"
	_chips.focus_mode = Control.FOCUS_NONE
	_chips.position = Vector2(22.0, 22.0)
	_chips.visible = false
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		_chips.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_chips.draw.connect(_draw_chips)
	_chips.pressed.connect(open_powers)
	sky.add_child(_chips)
	# what circles the star, named: one quiet line under the powers' discs
	_system = Label.new()
	_system.name = "System"
	_system.theme_type_variation = "CardBlurb"
	_system.add_theme_color_override("font_color", Color(Art.VEIL, 0.8))
	_system.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_system.position = Vector2(SYSTEM_X, SYSTEM_Y)
	_system.visible = false
	sky.add_child(_system)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	sky.add_child(_fx)
	_quiet = Fx2D.new()
	_quiet.buzzes = false
	sky.add_child(_quiet)

	var info := HBoxContainer.new()
	info.name = "Info"
	info.custom_minimum_size.y = INFO_H
	info.add_theme_constant_override("separation", TILE_GAP)
	_shop_b = IconButton.new("trend", tr("SHOP_TITLE"), "PrimaryButton")
	_shop_b.name = "Shop"
	_shop_b.custom_minimum_size = Vector2(SHOP_W, INFO_H)
	_shop_b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_shop_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shop_b.pressed.connect(open_shop)
	info.add_child(_shop_b)
	var light := _plate("light", "NL_LIGHT")
	light.custom_minimum_size = Vector2(LIGHT_W, HUD_H)
	light.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	light.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(light)
	info.add_child(_dust_plate())
	col.add_child(info)

	_motes = Motes.new()
	_motes.orb_mesh = Art.orb()
	_motes.light_mesh = Art.orb_light()
	_motes.target = _plates.light.icon
	_motes.landed.connect(_on_motes_landed)
	add_child(_motes)
	_shop = _build_shop()
	add_child(_shop)
	_perks = _build_perks()
	add_child(_perks)
	_powers = _build_powers()
	add_child(_powers)
	_pick = _build_pick()
	add_child(_pick)
	_reset = _build_reset()
	add_child(_reset)
	_shield = Control.new()
	_shield.name = "Shield"
	_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shield)
	_apply_insets()

## The star, on a paper plate: how many Suns it weighs, how hot it is and how
## long its hydrogen lasts, and under them what it is made of on a bar, with
## each share named (the user, 2026-10-06: "show mass compared to the sun
## ... show also temperature, composition and how much fuel it has to burn").
func _star_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Star"
	panel.add_theme_stylebox_override("panel", CozyTheme.lifted(FILL, 30, 8))
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 18)
	inset.add_theme_constant_override("margin_right", 18)
	inset.add_theme_constant_override("margin_top", 2)
	inset.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(inset)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	inset.add_child(col)
	var row := HBoxContainer.new()
	col.add_child(row)
	for cell: Array in [["mass", "NL_MASS"], ["temp", "NL_TEMP"], ["fuel", "NL_FUEL"]]:
		var words := VBoxContainer.new()
		words.name = String(cell[0]).capitalize()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", -8)
		row.add_child(words)
		var kicker := Label.new()
		kicker.text = cell[1]
		kicker.theme_type_variation = "MenuKicker"
		kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.add_child(kicker)
		var value := Label.new()
		value.name = "Value"
		value.theme_type_variation = "SheetTitle"
		value.add_theme_font_size_override("font_size", 46)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.add_child(value)
		_cells[cell[0]] = value
	_made = Control.new()
	_made.name = "Made"
	_made.custom_minimum_size.y = MADE_H
	_made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_made.draw.connect(_draw_made)
	col.add_child(_made)
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 22)
	col.add_child(legend)
	for i in MADE_NAMES.size():
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 8)
		legend.add_child(item)
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var box := StyleBoxFlat.new()
		box.bg_color = Art.MADE[i]
		box.set_corner_radius_all(8)
		dot.add_theme_stylebox_override("panel", box)
		item.add_child(dot)
		var share := Label.new()
		share.theme_type_variation = "CardBlurb"
		share.add_theme_font_size_override("font_size", 22)
		item.add_child(share)
		_made_l.append(share)
	return panel

## What is held, on a paper plate: its picture, its name and the count.
func _plate(what: String, key: String) -> Control:
	var plate := PanelContainer.new()
	plate.name = what.capitalize()
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.add_theme_stylebox_override("panel", CozyTheme.lifted(FILL, 30, 8))
	plate.resized.connect(func() -> void: plate.pivot_offset = plate.size * 0.5)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	plate.add_child(row)
	var icon := _picture(what, 72.0, 0.85)
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -6)
	row.add_child(words)
	var kicker := Label.new()
	kicker.text = key
	kicker.theme_type_variation = "MenuKicker"
	words.add_child(kicker)
	var value := Label.new()
	value.name = "Value"
	value.text = "0"
	value.theme_type_variation = "SheetTitle"
	words.add_child(value)
	_plates[what] = {"panel": plate, "icon": icon, "label": value}
	return plate

## The stardust held, once there has been a supernova: pressed, it opens the
## perks.
func _dust_plate() -> Control:
	_dust_b = Button.new()
	_dust_b.name = "Dust"
	_dust_b.focus_mode = Control.FOCUS_NONE
	_dust_b.custom_minimum_size = Vector2(DUST_W, HUD_H)
	_dust_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dust_b.visible = false
	CozyTheme.lift_button(_dust_b, FILL, 30, 8)
	_dust_b.pressed.connect(open_perks)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dust_b.add_child(row)
	row.add_child(_picture("dust", 60.0))
	_dust_l = Label.new()
	_dust_l.theme_type_variation = "SheetTitle"
	row.add_child(_dust_l)
	return _dust_b

## One of Art's pictures in a box `side` square, Art.R of it drawn `fill` of
## the box's side.
func _picture(what: String, side: float, fill := 0.5) -> Control:
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(side, side)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		var s := side * fill / Art.R
		icon.draw_mesh(Art.icon(what), null, Transform2D(0.0, Vector2(s, s), 0.0, icon.size * 0.5)))
	return icon

## A dialog's scrim with its card in the middle; a touch outside the card
## calls `out`.
func _dialog(called: String, width: float, out: Callable) -> Array:
	var scrim := Dialog.scrim()
	scrim.name = called
	scrim.visible = false
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
			out.call())
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	var card := Dialog.card(width, CARD_INSET)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	card.add_child(col)
	return [scrim, col]

## What a dialog's head carries at its right: something held, on a pill.
func _held_pill(what: String, label: Label) -> Control:
	var pill := PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 14))
	var held := HBoxContainer.new()
	held.add_theme_constant_override("separation", 10)
	pill.add_child(held)
	held.add_child(_picture(what, 46.0))
	label.theme_type_variation = "SheetTitle"
	held.add_child(label)
	return pill

## The shop: the hand's four tiles on a card over the sky, the light held on
## a pill at its head and an X beside it. The sky goes on behind it.
func _build_shop() -> Control:
	var made := _dialog("Shop", CARD_W, close_shop)
	var col: VBoxContainer = made[1]
	var trailing := HBoxContainer.new()
	trailing.add_theme_constant_override("separation", 16)
	_shop_light = Label.new()
	_shop_light.name = "Light"
	trailing.add_child(_held_pill("light", _shop_light))
	var x := IconButton.new("cross", "", "IconButton")
	x.name = "Close"
	x.custom_minimum_size = Vector2(X_SIZE, X_SIZE)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var r := int(X_SIZE * 0.5)
	var up := CozyTheme.soft_button(Pal.SURFACE, r, false, 0)
	var down := CozyTheme.soft_button(Pal.SURFACE, r, true, 0)
	for st in ["normal", "hover", "disabled"]:
		x.add_theme_stylebox_override(st, up)
	x.add_theme_stylebox_override("pressed", down)
	x.pressed.connect(close_shop)
	trailing.add_child(x)
	col.add_child(Dialog.head("SHOP_TITLE", "trend", trailing))
	var grid := GridContainer.new()
	grid.name = "Tiles"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	for tile: String in Sim.TILES:
		grid.add_child(_tile(tile))
	col.add_child(grid)
	return made[0]

func open_shop() -> void:
	if _shop.visible or sky.ending():
		return
	_drop_fingers()
	_refresh_tiles()
	_shop.visible = true
	Motion.appear(_shop, 0.0, 1.0, 0.2)

func close_shop() -> void:
	_shop.visible = false

## One of the four, on the shop's card: its picture on a piece of the night,
## its name, what the next level does, and the light it asks on a bar along
## its foot. A tile that cannot be bought yet is still pressed: it shakes
## its head.
func _tile(tile: String) -> Control:
	var b := Button.new()
	b.name = tile.capitalize()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = TILE_H
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CozyTheme.lift_button(b, FILL, 30, 8)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.pressed.connect(_on_tile.bind(tile))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 22.0
	col.offset_bottom = -TILE_PAD - 2.0
	col.offset_left = TILE_PAD
	col.offset_right = -TILE_PAD
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(0, DISC_R * 2.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		var c := icon.size * 0.5
		icon.draw_circle(c, DISC_R, Art.SKY[1], true, -1.0, true)
		var s := DISC_R * 0.78 / Art.R
		icon.draw_mesh(Art.icon(tile), null, Transform2D(0.0, Vector2(s, s), 0.0, c)))
	col.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -4)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(words)
	var name_l := Label.new()
	name_l.text = TILE_NAMES[tile]
	name_l.theme_type_variation = "CardTitle"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	words.add_child(name_l)
	var effect := Label.new()
	effect.theme_type_variation = "CardBlurb"
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.clip_text = true
	effect.add_theme_font_size_override("font_size", 24)
	words.add_child(effect)
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.custom_minimum_size.y = PRICE_H
	col.add_child(pill)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var mote := _picture("light", 38.0)
	row.add_child(mote)
	# a tile with no level left wears a tick where its price was
	var tick := Control.new()
	tick.custom_minimum_size = Vector2(34, 34)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick.draw.connect(func() -> void:
		Icons.paint(tick, "check", Rect2(Vector2.ZERO, tick.size), Pal.LEAF_DEEP))
	row.add_child(tick)
	var cost := Label.new()
	cost.theme_type_variation = "CardTitle"
	cost.add_theme_font_size_override("font_size", 38)
	row.add_child(cost)
	# the level, on the tile's corner once there is one
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_top = 12.0
	badge.offset_right = -12.0
	var bb := StyleBoxFlat.new()
	bb.bg_color = Pal.ACCENT
	bb.set_corner_radius_all(18)
	bb.content_margin_left = 14.0
	bb.content_margin_right = 14.0
	bb.content_margin_top = 0.0
	bb.content_margin_bottom = 2.0
	badge.add_theme_stylebox_override("panel", bb)
	var level := Label.new()
	level.theme_type_variation = "Badge"
	badge.add_child(level)
	b.add_child(badge)
	_tiles[tile] = {"button": b, "icon": icon, "effect": effect, "pill": pill, "cost": cost,
		"mote": mote, "tick": tick, "badge": badge, "level": level}
	return b

## Before the supernova: what goes and what it pays, and a way back. It takes
## the tiles with it, so it is never one touch.
## The perks: the stardust held, the five with how many of each there are,
## and a button that draws one at random for what the next costs.
func _build_perks() -> Control:
	var made := _dialog("Perks", CARD_W, close_perks)
	var col: VBoxContainer = made[1]
	_perk_dust = Label.new()
	_perk_dust.name = "Dust"
	col.add_child(Dialog.head("NL_PERKS", "sparkle", _held_pill("dust", _perk_dust)))
	var body := Label.new()
	body.text = "NL_PERKS_BODY"
	body.theme_type_variation = "CardBlurb"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	var grid := GridContainer.new()
	grid.name = "Perks"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	for which: String in Sim.PERKS:
		grid.add_child(_perk_tile(which))
	col.add_child(grid)
	_perk_buy = Dialog.primary("sparkle", "")
	_perk_buy.name = "Buy"
	_perk_buy.pressed.connect(_on_perk)
	var back := Dialog.secondary("chevron_left", tr("NL_PERKS_BACK"))
	back.name = "Back"
	back.pressed.connect(close_perks)
	Dialog.buttons(col, _perk_buy, back)
	return made[0]

func _perk_tile(which: String) -> Control:
	var panel := PanelContainer.new()
	panel.name = which.capitalize()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 18))
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", -4)
	row.add_child(words)
	var name_l := Label.new()
	name_l.text = PERK_NAMES[which]
	name_l.theme_type_variation = "CardTitle"
	name_l.clip_text = true
	words.add_child(name_l)
	var effect := Label.new()
	effect.text = PERK_NAMES[which] + "_FX"
	effect.theme_type_variation = "CardBlurb"
	effect.add_theme_font_size_override("font_size", 24)
	effect.clip_text = true
	words.add_child(effect)
	var count := Label.new()
	count.theme_type_variation = "CardTitle"
	count.add_theme_color_override("font_color", Pal.SUN_DEEP)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)
	_perk_tiles[which] = {"panel": panel, "count": count}
	return panel

## The perks, from the stardust's plate, or `by_itself` after an end.
func open_perks(by_itself := false) -> void:
	if _perks.visible or sky.ending():
		return
	_drop_fingers()
	if by_itself:
		_raised()
	_refresh_perks()
	_perks.visible = true
	Motion.appear(_perks, 0.0, 1.0, 0.2)

func close_perks() -> void:
	_perks.visible = false

func _refresh_perks() -> void:
	_perk_dust.text = str(sim.dust)
	for which: String in Sim.PERKS:
		var n := int(sim.perk[which])
		(_perk_tiles[which].count as Label).text = "×%d" % n if n > 0 else ""
		(_perk_tiles[which].panel as Control).modulate.a = 1.0 if n > 0 else 0.5
	(_perk_buy as IconButton).set_label(_count("NL_PERK_BUY", sim.perk_cost()))
	(_perk_buy as IconButton).set_enabled(sim.dust >= sim.perk_cost())

func _on_perk() -> void:
	var which: String = sim.buy_perk()
	if which == "":
		_fx.cue("no")
		Motion.shiver(_perk_buy, 6.0)
		return
	_fx.cue("perk")
	_refresh_perks()
	Motion.bump(_perk_tiles[which].panel, 0.06, 0.24)
	Analytics.track("nightlight_perk", {"perk": which, "count": int(sim.perk[which]), "dust": sim.perk_cost() - 1})
	_save()

## A pick: the star has grown past one of Sim.MILES and offers two powers
## that go different ways. One is taken; the card has no way out but that,
## and the sky waits behind it. A power already held says its level.
func _build_pick() -> Control:
	var made := _dialog("Pick", CARD_W, func() -> void: pass)
	var col: VBoxContainer = made[1]
	var head := Dialog.head("", "sparkle")
	_pick_title = head.get_child(1) as Label
	col.add_child(head)
	var body := Label.new()
	body.text = "NL_PICK_BODY"
	body.theme_type_variation = "CardBlurb"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	var two := HBoxContainer.new()
	two.name = "Two"
	two.add_theme_constant_override("separation", TILE_GAP)
	col.add_child(two)
	for i in 2:
		two.add_child(_pick_tile(i))
	return made[0]

func _pick_tile(i: int) -> Control:
	var b := Button.new()
	b.name = "Pick%d" % i
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = PICK_H
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CozyTheme.lift_button(b, FILL, 30, 8)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.pressed.connect(_on_pick.bind(i))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 26.0
	col.offset_bottom = -TILE_PAD - 2.0
	col.offset_left = TILE_PAD + 6.0
	col.offset_right = -TILE_PAD - 6.0
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(0, 168.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		if i >= _pick_now.size():
			return
		var c := icon.size * 0.5
		icon.draw_circle(c, 84.0, Art.SKY[1], true, -1.0, true)
		var s := 84.0 * 0.78 / Art.R
		icon.draw_mesh(Art.icon(_pick_now[i]), null, Transform2D(0.0, Vector2(s, s), 0.0, c)))
	col.add_child(icon)
	var name_l := Label.new()
	name_l.theme_type_variation = "CardTitle"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	col.add_child(name_l)
	var effect := Label.new()
	effect.theme_type_variation = "CardBlurb"
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(effect)
	# what it costs: the hydrogen it burns, on the bar a price would be on
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.custom_minimum_size.y = PRICE_H
	var box := StyleBoxFlat.new()
	box.bg_color = Pal.SUN
	box.set_corner_radius_all(PRICE_R)
	box.border_width_bottom = 5
	box.border_color = Pal.SUN_DEEP
	pill.add_theme_stylebox_override("panel", box)
	col.add_child(pill)
	var cost := Label.new()
	cost.theme_type_variation = "CardTitle"
	cost.add_theme_font_size_override("font_size", 30)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.add_child(cost)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_top = 12.0
	badge.offset_right = -12.0
	var bb := StyleBoxFlat.new()
	bb.bg_color = Pal.ACCENT
	bb.set_corner_radius_all(18)
	bb.content_margin_left = 14.0
	bb.content_margin_right = 14.0
	bb.content_margin_top = 0.0
	bb.content_margin_bottom = 2.0
	badge.add_theme_stylebox_override("panel", bb)
	var level := Label.new()
	level.theme_type_variation = "Badge"
	badge.add_child(level)
	b.add_child(badge)
	_pick_tiles.append({"button": b, "icon": icon, "name": name_l, "effect": effect, "cost": cost, "badge": badge, "level": level})
	return b

## What a power burns, in its own words.
func _burns(which: String) -> String:
	if which == "thrift":
		return tr("NL_POW_SAVE")
	return tr("NL_POW_BURN") % int(round(float(Sim.COST[which]) * 100.0))

func open_pick() -> void:
	var two: Array = sim.offering()
	if two.is_empty() or _pick.visible:
		return
	_drop_fingers()
	_raised()
	_pick_now = two
	_pick_title.text = tr("NL_PICK_TITLE") % Art.short(Sim.mile(sim.picks), _comma())
	for i in 2:
		var t: Dictionary = _pick_tiles[i]
		var which: String = two[i]
		var held := int(sim.power[which])
		(t.name as Label).text = POWER_NAMES[which]
		(t.effect as Label).text = POWER_NAMES[which] + "_FX"
		(t.cost as Label).text = _burns(which)
		(t.badge as Control).visible = held > 0
		(t.level as Label).text = str(held)
		(t.icon as Control).queue_redraw()
	_pick.visible = true
	Motion.appear(_pick, 0.0, 1.0, 0.2)
	_fx.cue("pick")

func _on_pick(i: int) -> void:
	var which: String = sim.pick(i)
	if which == "":
		_pick.visible = false
		return
	_fx.cue("perk")
	Analytics.track("nightlight_power", {"power": which, "level": int(sim.power[which]), "suns": int(Sim.mile(sim.picks - 1))})
	_pick.visible = false
	_pick_wait = 0.0
	_save()

## The powers held: what each does, how many times it was picked and what it
## burns.
func _build_powers() -> Control:
	var made := _dialog("PowersCard", CARD_W, close_powers)
	var col: VBoxContainer = made[1]
	col.add_child(Dialog.head("NL_POWERS", "sparkle"))
	var body := Label.new()
	body.text = "NL_POWERS_BODY"
	body.theme_type_variation = "CardBlurb"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	_powers_list = VBoxContainer.new()
	_powers_list.name = "List"
	_powers_list.add_theme_constant_override("separation", 12)
	col.add_child(_powers_list)
	var back := Dialog.secondary("chevron_left", tr("NL_PERKS_BACK"))
	back.name = "Back"
	back.pressed.connect(close_powers)
	Dialog.buttons(col, back)
	return made[0]

func open_powers() -> void:
	if _powers.visible or sky.ending():
		return
	_drop_fingers()
	for old in _powers_list.get_children():
		_powers_list.remove_child(old)
		old.queue_free()
	for which: String in Sim.POWERS:
		var held := int(sim.power[which])
		if held <= 0:
			continue
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 14))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		panel.add_child(row)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(72, 72)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.draw.connect(func() -> void:
			icon.draw_circle(icon.size * 0.5, 36.0, Art.SKY[1], true, -1.0, true)
			var s := 36.0 * 0.78 / Art.R
			icon.draw_mesh(Art.icon(which), null, Transform2D(0.0, Vector2(s, s), 0.0, icon.size * 0.5)))
		row.add_child(icon)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", -4)
		row.add_child(words)
		var name_l := Label.new()
		name_l.text = POWER_NAMES[which]
		name_l.theme_type_variation = "CardTitle"
		words.add_child(name_l)
		var effect := Label.new()
		effect.text = "%s %s" % [tr(POWER_NAMES[which] + "_FX"), tr("NL_POW_EACH") % _burns(which)]
		effect.theme_type_variation = "CardBlurb"
		effect.add_theme_font_size_override("font_size", 24)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(effect)
		var count := Label.new()
		count.text = "×%d" % held
		count.theme_type_variation = "CardTitle"
		count.add_theme_color_override("font_color", Pal.SUN_DEEP)
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(count)
		_powers_list.add_child(panel)
	_powers.visible = true
	Motion.appear(_powers, 0.0, 1.0, 0.2)

func close_powers() -> void:
	_powers.visible = false

## Start over, from the settings sheet (the user, 2026-10-06: "add a button
## on config to reset game to 0"): a card that says what is lost and asks,
## since nothing brings it back. The way out that keeps the star is the sun
## button; the sky waits behind the card.
func _build_reset() -> Control:
	var made := _dialog("ResetCard", CARD_W, close_reset)
	var col: VBoxContainer = made[1]
	col.add_child(Dialog.head("NL_RESET_TITLE", "reset"))
	var body := Label.new()
	body.text = "NL_RESET_BODY"
	body.theme_type_variation = "CardBlurb"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	var keep := Dialog.primary("check", tr("NL_RESET_NO"))
	keep.name = "Keep"
	keep.pressed.connect(close_reset)
	var yes := Dialog.secondary("reset", tr("NL_RESET_YES"))
	yes.name = "StartOver"
	yes.pressed.connect(_on_reset)
	Dialog.buttons(col, keep, yes)
	return made[0]

func open_reset() -> void:
	if _reset.visible:
		return
	_drop_fingers()
	_reset.visible = true
	Motion.appear(_reset, 0.0, 1.0, 0.2)

func close_reset() -> void:
	_reset.visible = false

## A new star in place of this one, and nothing kept: its mass, its light,
## the hand's tiles, its powers, the stardust, the perks and the clouds its
## supernovas left in the sky. An end being played is dropped with it.
func _on_reset() -> void:
	Analytics.track("nightlight_reset", {"suns": int(sim.suns()), "novas": sim.novas, "fades": sim.fades, "dust": sim.dust})
	sim = Sim.new()
	sim.born()
	sky.sim = sim
	sky.finish_end()
	sky.started()
	_motes.clear()
	_end_how = ""
	_end_done = false
	_pick_wait = 0.0
	_perks_due = false
	_braked = false
	_eaten_at_open = 0.0
	_shown.mass = sim.mass
	_shown.light = sim.light
	for card: Control in [_shop, _perks, _powers, _pick, _reset]:
		card.visible = false
	_drop_fingers()
	_refresh_tiles()
	_refresh_hud(0.0)
	_begin_birth()
	_save()

## The star condenses out of the cloud round it: the close of an end alone,
## the sim held for it (see `_step_end`).
func _begin_birth() -> void:
	sky.begin_birth()
	_birth = true

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))

## The sky is drawn in the design's pixels, 1080 to the screen's width, with
## the star a little above the field's middle.
func _layout_field() -> void:
	sky.u = size.x / 1080.0 if size.x > 0.0 else 1.0
	sky.centre = Vector2(sky.size.x * 0.5, sky.size.y * STAR_AT)

# --- what the top bar and the tutorial ask ---

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/nightlight_tutorial_diagram.gd")
	var c := _comma()
	var pages := []
	for step: Array in [
			[Diagram.Lesson.GAS, "TUT_NL_GAS", tr("TUT_NL_GAS_BODY")],
			[Diagram.Lesson.WORLDS, "TUT_NL_WORLDS", tr("TUT_NL_WORLDS_BODY")],
			[Diagram.Lesson.BURN, "TUT_NL_BURN", tr("TUT_NL_BURN_BODY") % [_hundredths(Sim.FLASH), Art.short(Sim.HEAVY, c)]],
			[Diagram.Lesson.END, "TUT_NL_END", tr("TUT_NL_END_BODY") % [Art.short(Sim.IRON, c), Art.short(Sim.HEAVY, c), Art.short(Sim.COLLAPSE, c)]]]:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func capabilities() -> Array:
	return []

func is_done() -> bool:
	return false

func is_solved() -> bool:
	return false

func can_undo() -> bool:
	return false

func hints_left() -> int:
	return 0

## A card over the screen (the tutorial): the sky waits, and no press.
func _tutor_hold(on: bool) -> void:
	_held_back = on
	if on:
		_drop_fingers()

# --- time ---

func _process(delta: float) -> void:
	if sim == null:
		return
	if _shield.mouse_filter == Control.MOUSE_FILTER_STOP and Time.get_ticks_msec() - _raised_at >= int(PICK_DEAF * 1000.0):
		_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ending: bool = sky.ending()
	var waits: bool = _held_back or settings_sheet.is_open() or _pick.visible or _reset.visible or ending
	_hold(delta)
	if not waits:
		sim.advance(delta)
	_play_events()
	_offer(delta)
	_step_end(delta)
	# an end is the sky's own to play, whatever the sim is doing
	sky.refresh(delta if ending else (0.0 if waits else delta))
	_refresh_hud(delta)
	_nova_line.queue_redraw()
	if _note_t > 0.0:
		_note_t -= delta
		_note.modulate.a = clampf(_note_t / NOTE_OUT, 0.0, 1.0)
	if _dirty:
		_since_save += delta
		if _since_save >= SAVE_GAP:
			_save()

## A card comes up by itself: the perks an end owes, then a pick the star
## has grown past, a moment later. Never over another card (`_deaf`) and
## never under a finger (`_calm`); a pick's wait starts again while one is
## in the way.
func _offer(delta: float) -> void:
	if _perks_due:
		if not _deaf() and _calm():
			_perks_due = false
			open_perks(true)
		return
	if sim.owed() <= 0 or _pick.visible:
		_pick_wait = 0.0
		# a card with nothing left to offer is not left up
		if _pick.visible and sim.owed() <= 0:
			_pick.visible = false
		return
	if _deaf():
		return
	if not _calm():
		_pick_wait = 0.0
		return
	_pick_wait += delta
	if _pick_wait >= PICK_WAIT:
		open_pick()

## No finger is on the sky, and none has been for OFFER_CALM seconds.
func _calm() -> bool:
	return _touching.is_empty() and _fingers.is_empty() and Time.get_ticks_msec() - _lifted_at >= int(OFFER_CALM * 1000.0)

## A card has come up by itself: for PICK_DEAF seconds the shield is in
## front of it, and of everything. A press that lands on the shield stays
## the shield's until it lifts, however long it is held, so nothing under it
## is pressed by a finger that was already on its way; a press that lands
## after is the card's own.
func _raised() -> void:
	_raised_at = Time.get_ticks_msec()
	_shield.mouse_filter = Control.MOUSE_FILTER_STOP

func _play_events() -> void:
	var origin: Transform2D = sky.get_global_transform()
	for e: Dictionary in sim.events:
		match String(e.kind):
			"eat":
				sky.ate(float(e.m), bool(e.gas))
				_dirty = true
				if not bool(e.gas):
					_hear_eaten(float(e.m))
			"shed":
				var orbs := float(e.e) * ORBS
				_motes.drop(origin * sky.px(e.at), orbs, clampi(ceili(orbs), 1, SHED_ORBS))
			"form":
				sky.formed(e.at)
			"merge":
				sky.met(e.at)
			"tear":
				sky.tore(e.at, float(e.m))
				var now := Time.get_ticks_msec()
				if now - _tore_at >= int(TEAR_GAP * 1000.0):
					_tore_at = now
					_fx.cue("tear", randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY))
			"shine":
				# the star's own light, off its own face, wherever the camera has it
				_motes.drop(origin * sky.world(Vector2.ZERO), float(e.e) * ORBS, 1)
				_dirty = true
			"ignite":
				sky.lit_up()
				_say(LIT_NAMES[int(e.stage)])
				_fx.cue("ignite")
				Analytics.track("nightlight_ignite", {"stage": Sim.CHAIN[int(e.stage)], "suns": int(sim.suns())})
				_save()
			"dim":
				_say("NL_DIM")
				_fx.cue("dim")
			"wake":
				_fx.cue("wake")
	sim.events.clear()
	if _tiles_for != _tiles_key():
		_refresh_tiles()

## A solid has fallen into the star: a soft click, lower and louder the
## bigger it was, and one in EAT_GAP at most (a torn body's pieces arrive
## together).
func _hear_eaten(m: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _ate_at < int(EAT_GAP * 1000.0):
		return
	_ate_at = now
	var r := Sim.body_r(m)
	# it was -11.0 + 0.6 * r between -10 and -4: at -10 the file reads -25 dB
	# on a phone's side, so 2 dB are given back
	_quiet.cue("eat", clampf(EAT_PITCH.x - EAT_PITCH.y * r, EAT_PITCH.z, 1.0) * randf_range(0.97, 1.03), clampf(-9.0 + 0.6 * r, -8.0, -2.0))

## A line over the sky's head, for a few seconds.
func _say(key: String) -> void:
	_note.text = tr(key)
	_note_t = NOTE

## The star ends by itself (the user, asked how a life ends: "the star
## decides"): once the sim says so and no card is in the way, the sky plays
## the layers leaving; partway through the sim gives everything back and a
## small star is left among the gas; when the sky is done the perks are
## offered.
func _step_end(delta: float) -> void:
	if not sky.ending():
		var how: String = sim.ending()
		if how == "" or _held_back or settings_sheet.is_open() or _pick.visible or _reset.visible:
			return
		for card: Control in [_shop, _perks, _powers]:
			card.visible = false
		_drop_fingers()
		_end_how = how
		_end_done = false
		_end_rem = sim.remnant()
		_end_cued = how != "nova"
		if how == "nova":
			_say("NL_END_NOVA_BH" if _end_rem == Sim.Relic.BH else "NL_END_NOVA_NS")
		else:
			_say("NL_END_NEBULA" if how == "nebula" else "NL_END_FADE")
		sky.begin_end(how, sim.layers(), _end_rem)
		# a nebula lets go as slowly as a fade does, and is felt as one
		if _end_cued:
			_fx.cue("fade")
		return
	# a first star's birth waits behind the first play's card, to be seen,
	# and is heard as it starts
	if _birth and _held_back:
		return
	if _birth and sky.end_t() <= 0.0:
		_fx.cue("born")
	sky.step_end(delta)
	if _birth:
		if sky.end_t() >= sky.end_time():
			_birth = false
			sky.finish_end()
		return
	if not _end_cued and sky.end_t() >= float(NightSky.END.nova.fall) - NOVA_LEAD:
		_end_cued = true
		_fx.cue("nova")
	if not _end_done:
		if sky.end_t() >= sky.end_swap():
			var was := int(sim.suns())
			var paid: int = sim.end()
			_end_done = true
			sky.swapped(sim.last_birth)
			_fx.cue("born")
			_motes.clear()
			_shown.mass = sim.mass
			_shown.light = 0.0
			Analytics.track("nightlight_nova", {"n": sim.novas, "suns": was, "dust": paid, "how": _end_how, "remnant": ["wd", "ns", "bh"][_end_rem]})
			_refresh_tiles()
			_save()
	elif sky.end_t() >= sky.end_time():
		# the perks come up by themselves, so `_offer` raises them
		sky.finish_end()
		_perks_due = true

## Motes came down on the light plate: it swells, unless it still is from
## the one before, and a click is heard, each a semitone up a short run.
func _on_motes_landed(_n: int, note: int) -> void:
	if (_plates.light.panel as Control).scale.x <= 1.01:
		_kick("light")
	if note >= 0:
		_quiet.cue("light", LOW_TAP * pow(2.0, mini(note, LIGHT_RUN) / 12.0), -6.0)

## A plate swells as something lands on it. Each kick ends the last, or
## landings a moment apart would leave it stuck big (ui/menu/gold_pill.gd).
func _kick(kind: String) -> void:
	var panel: Control = _plates[kind].panel
	Motion.stop(_bump.get(kind))
	panel.scale = Vector2.ONE
	_bump[kind] = Motion.bump(panel, 0.06, 0.18)

func _refresh_hud(delta: float) -> void:
	# the light plate counts what has landed, not what is still in the air
	var want := {"mass": sim.mass, "light": maxf(0.0, sim.light - _motes.due / ORBS)}
	for kind: String in want:
		var held: float = want[kind]
		var s: float = _shown[kind]
		if Motion.reduce or delta <= 0.0 or absf(held - s) < 0.06:
			s = held
		else:
			s = lerpf(s, held, minf(1.0, delta * 10.0))
		_shown[kind] = s
	var c := _comma()
	(_cells.mass as Label).text = Art.short(_shown.mass / Sim.START, c) + "×"
	(_cells.temp as Label).text = _kelvin(sim.temp())
	var fuel_l: Label = _cells.fuel
	var lasts: float = sim.fuel_time()
	fuel_l.text = _clock(lasts) if sim.h_on else tr("NL_FUEL_OUT")
	var low: bool = not sim.h_on or lasts < LOW
	if low != _fuel_low:
		_fuel_low = low
		if low:
			fuel_l.add_theme_color_override("font_color", Pal.HEART)
		else:
			fuel_l.remove_theme_color_override("font_color")
	# only what there is half a hundredth of is named
	var shares: Array = sim.layers()
	for i in shares.size():
		var pc := int(round(100.0 * float(shares[i])))
		var named: String = MADE_NAMES[i]
		(_made_l[i].get_parent() as Control).visible = pc >= 1 or i < 2
		_made_l[i].text = "%s %d%%" % [tr(named) if named.begins_with("NL_") else named, pc]
	_made.queue_redraw()
	_refresh_chips()
	_refresh_system(delta)
	(_plates.light.label as Label).text = Art.short(floorf(_shown.light), c)
	_shop_light.text = Art.short(floorf(sim.light), _comma())
	_dust_b.visible = sim.novas + sim.fades > 0 or sim.dust > 0
	# said until a press of this visit has braked something (a star kept from
	# before the ring has eaten plenty and never been pressed, and a new star
	# eats its falling few with no hand at all)
	_hint.visible = not _braked and _fingers.is_empty() and not sky.ending()
	_dust_l.text = str(sim.dust)
	var goal: Dictionary = sim.goal()
	var core := _core_temp(sim.core_temp())
	if String(goal.which) == "dim":
		_nova_l.text = tr("NL_GOAL_DIM") % _clock(maxf(0.0, float(goal.need) - float(goal.have)))
	elif not bool(goal.heavy):
		_nova_l.text = tr("NL_GOAL_C_WAIT") % [_hundredths(float(goal.have)), _hundredths(float(goal.need)), Art.short(Sim.HEAVY, c), core]
	else:
		_nova_l.text = tr(GOALS[goal.which]) % [_hundredths(float(goal.have)), _hundredths(float(goal.need)), core]
	_pick_l.text = tr("NL_PICK_AT") % Art.short(sim.next_pick(), c)

## The core's temperature, from millions of kelvin: 15 million K, 1.2 billion K.
func _core_temp(mk: float) -> String:
	if mk >= 1000.0:
		return tr("NL_BILLION_K") % Art.short(mk / 1000.0, _comma())
	return tr("NL_MILLION_K") % Art.short(mk, _comma())

## Kelvin, to the nearest ten (a hundred past ten thousand), with the
## language's own mark between the thousands.
func _kelvin(v: float) -> String:
	var k := int(round(v / 100.0)) * 100 if v >= 10000.0 else int(round(v / 10.0)) * 10
	var text := str(k)
	if k >= 1000:
		text = "%d%s%03d" % [k / 1000, "." if _comma() else ",", k % 1000]
	return text + " K"

## Seconds as minutes and seconds, 7:48, and past an hour as hours and
## minutes, 2 h 40: a new star's hydrogen lasts longer than a sitting.
func _clock(seconds: float) -> String:
	var t := int(seconds)
	if t >= 3600:
		return "%d h %02d" % [t / 3600, (t % 3600) / 60]
	return "%d:%02d" % [t / 60, t % 60]

## The discs of the powers held are drawn again only when one changes.
func _refresh_chips() -> void:
	var key := "y" if sim.awake else "n"
	var held := 0
	for which: String in Sim.POWERS:
		key += str(int(sim.power[which]))
		if int(sim.power[which]) > 0:
			held += 1
	if key == _chips_for:
		return
	_chips_for = key
	_chips.visible = held > 0
	_chips.size = Vector2(CHIP, held * (CHIP + CHIP_GAP))
	_chips.queue_redraw()

## What circles the star, in its own words: "3 planets · 1 giant · 22
## rocks · 4 comets", a kind with none left out. `n` is `sim.system()`.
func _system_line(n: Dictionary) -> String:
	var parts: PackedStringArray = []
	for row: Array in [["planets", "NL_SYS_PLANETS"], ["giants", "NL_SYS_GIANTS"], ["rocks", "NL_SYS_ROCKS"], ["comets", "NL_SYS_COMETS"]]:
		if int(n[row[0]]) > 0:
			parts.append(_count(row[1], int(n[row[0]])))
	return " · ".join(parts)

## The bodies are counted every SYSTEM_EVERY seconds (and at once with no
## time passed: the screen opening, a new star), and the line is written
## again only when a count changes. It is not shown with nothing to name or
## while the sky plays an end, it sits under the powers' discs when there
## are any, and it gives way to a note said across it.
func _refresh_system(delta: float) -> void:
	_system_wait -= delta
	if delta <= 0.0 or _system_wait <= 0.0:
		_system_wait = SYSTEM_EVERY
		var n: Dictionary = sim.system()
		var key := "%d %d %d %d" % [int(n.planets), int(n.giants), int(n.rocks), int(n.comets)]
		if key != _system_for:
			_system_for = key
			_system.text = _system_line(n)
	_system.visible = _system.text != "" and not sky.ending()
	_system.position.y = _chips.position.y + _chips.size.y if _chips.visible else SYSTEM_Y
	var under_note: bool = _note_t > 0.0 and _system.position.y < _note.position.y + _note.size.y
	_system.modulate.a = 1.0 - _note.modulate.a if under_note else 1.0

## A disc for each power held, its level on it past the first; all of them
## faint while the star is dim and they sleep.
func _draw_chips() -> void:
	var font := get_theme_font("font", "Badge")
	var faint := 1.0 if sim.awake else 0.4
	var y := 0.0
	for which: String in Sim.POWERS:
		var held := int(sim.power[which])
		if held <= 0:
			continue
		var c := Vector2(CHIP * 0.5, y + CHIP * 0.5)
		_chips.draw_circle(c, CHIP * 0.5, Color(Pal.PAPER, 0.85 * faint), true, -1.0, true)
		_chips.draw_circle(c, CHIP * 0.5 - 4.0, Color(Art.SKY[1], faint), true, -1.0, true)
		var s := (CHIP * 0.5 - 4.0) * 0.8 / Art.R
		_chips.draw_mesh(Art.icon(which), null, Transform2D(0.0, Vector2(s, s), 0.0, c), Color(1, 1, 1, faint))
		if held > 1:
			var at := c + Vector2(CHIP * 0.3, CHIP * 0.3)
			_chips.draw_circle(at, 15.0, Color(Pal.ACCENT, faint), true, -1.0, true)
			_chips.draw_string(font, at + Vector2(-15.0, 8.0), str(held), HORIZONTAL_ALIGNMENT_CENTER, 30.0, 22, Color(Pal.SURFACE, faint))
		y += CHIP + CHIP_GAP

# --- the tiles ---

func _tiles_key() -> String:
	var key := ""
	for tile: String in Sim.TILES:
		key += "%d%s" % [int(sim.lv[tile]), "y" if sim.can_buy(tile) else "n"]
	return key

func _refresh_tiles() -> void:
	_tiles_for = _tiles_key()
	# the shop's button says how many tiles the light reaches
	var reach := 0
	for tile: String in Sim.TILES:
		if sim.can_buy(tile):
			reach += 1
	(_shop_b as IconButton).badge = reach
	for tile: String in Sim.TILES:
		var t: Dictionary = _tiles[tile]
		var done: bool = sim.is_done(tile)
		var can: bool = sim.can_buy(tile)
		var level := int(sim.lv[tile])
		# Reach and Pure are the two with a last level, and each says its own
		(t.effect as Label).text = tr("NL_DONE_REACH" if tile == "reach" else "NL_DONE") if done else _effect(tile)
		(t.cost as Label).text = tr("NL_MAX") if done else Art.short(sim.cost(tile), _comma())
		(t.mote as Control).visible = not done
		(t.tick as Control).visible = done
		# the price's bar: the sun button's own when the light reaches it,
		# paper when it does not, a leaf when there is nothing left to buy
		var box := StyleBoxFlat.new()
		box.bg_color = Pal.LEAF_TILE if done else (Pal.SUN if can else PRICE_OFF)
		box.set_corner_radius_all(PRICE_R)
		box.content_margin_left = 12.0
		box.content_margin_right = 16.0
		if can:
			box.border_width_bottom = 5
			box.border_color = Pal.SUN_DEEP
		(t.pill as Control).add_theme_stylebox_override("panel", box)
		(t.cost as Label).add_theme_color_override("font_color",
			Pal.LEAF_DEEP if done else (Pal.TEXT if can else Pal.TEXT_DIM))
		(t.badge as Control).visible = level > 0
		(t.level as Label).text = str(level)

## What the next level of `tile` does, in the tile's own words.
func _effect(tile: String) -> String:
	var c := _comma()
	match tile:
		"reach":
			var level := int(sim.lv.reach)
			return tr("NL_FX_REACH") % [Art.short(1.0 + Sim.REACH_STEP * level, c), Art.short(1.0 + Sim.REACH_STEP * (level + 1), c)]
		"flow":
			var gap: float = sim.flow_gap()
			return tr("NL_FX_STREAM") % [_hundredths(gap), _hundredths(maxf(Sim.FLOW_LEAST, gap * Sim.FLOW_STEP))]
		"rich":
			var level := int(sim.lv.rich)
			return tr("NL_FX_RICH") % [Art.short(1.0 + Sim.RICH_STEP * level, c), Art.short(1.0 + Sim.RICH_STEP * (level + 1), c)]
	var h: float = sim.puff_h()
	return tr("NL_FX_PURE") % [int(round(h * 100.0)), int(round(minf(0.95, h + Sim.PURE_STEP) * 100.0))]

## Seconds to two decimals: 0.43, or 0,43 where the language writes it so.
func _hundredths(v: float) -> String:
	var text := "%.2f" % v
	return text.replace(".", ",") if _comma() else text

static func _comma() -> bool:
	return not TranslationServer.get_locale().begins_with("en")

## A line that counts: `key`_ONE for one, `key`_N otherwise.
func _count(key: String, n: int) -> String:
	return tr(key + "_ONE") if n == 1 else tr(key + "_N") % n

func _on_tile(tile: String) -> void:
	var button: Control = _tiles[tile].button
	var paid: int = sim.cost(tile)
	if sim.buy(tile):
		_fx.cue("buy")
		Motion.bump(button, 0.05, 0.2)
		Analytics.track("nightlight_upgrade", {"tile": tile, "level": int(sim.lv[tile]), "light": paid})
		_refresh_tiles()
		_save()
	elif not sim.is_done(tile):
		_fx.cue("no")
		Motion.shiver(button, 6.0)

# --- the hand ---

## No press is read under a card, while the tutorial holds the screen, or
## while a star ends or is born.
func _deaf() -> bool:
	return _held_back or settings_sheet.is_open() or _pick.visible or _shop.visible or _perks.visible or _powers.visible or _reset.visible or sky.ending() or sim.ending() != ""

## The sky's fingers. A ScreenTouch and a ScreenDrag, never a mouse button
## alone (the project has mouse-from-touch off, and the Grove shipped unable
## to be chopped on a phone for reading the mouse alone); the mouse is for
## this Mac. Every finger that comes down brakes, and each is followed.
func _on_sky_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touching[t.index] = true
			_press_at(t.index, t.position)
		else:
			_lift(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _fingers.has(d.index):
			_fingers[d.index].at = d.position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_touching[-1] = true
			_press_at(-1, (event as InputEventMouseButton).position)
		else:
			_lift(-1)
	elif event is InputEventMouseMotion and _fingers.has(-1):
		_fingers[-1].at = (event as InputEventMouseMotion).position

## `finger` (-1 the mouse) comes down at `px` of the sky: it brakes there at
## once, and is held. A touch and a mouse press a moment apart are one press.
func _press_at(finger: int, px: Vector2) -> void:
	var now := Time.get_ticks_msec()
	var mouse := finger == -1
	if mouse != _pressed_mouse and now - _pressed_at < TWICE_MS:
		return
	_pressed_at = now
	_pressed_mouse = mouse
	if _deaf() or _fingers.has(finger):
		return
	_fingers[finger] = {"at": px, "t": 0.0}
	_brake(px)

## `finger` leaves the sky, whether or not its press was read.
func _lift(finger: int) -> void:
	var was: bool = _touching.erase(finger)
	if _fingers.erase(finger) or was:
		_lifted_at = Time.get_ticks_msec()

## Every finger is let go of: a card is coming up, or the game is left. It
## may still be on the sky (`_touching`); it brakes nothing more.
func _drop_fingers() -> void:
	if not _fingers.is_empty():
		_fingers.clear()
		_lifted_at = Time.get_ticks_msec()

## One brake where a finger is. Heard and felt when it caught something,
## though not every one of a held finger's.
func _brake(px: Vector2) -> void:
	var at: Vector2 = sky.unworld(px)
	var r: float = sim.press_r()
	sky.set_down(at, r)
	if sim.brake(at, r) == 0:
		return
	_braked = true
	var now := Time.get_ticks_msec()
	if now - _felt_at >= int(FELT * 1000.0):
		_felt_at = now
		_fx.cue("pour", LOW_TAP * randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY))
	_dirty = true

## Held, a finger brakes again where it is now, as often as Flow lets it.
func _hold(delta: float) -> void:
	if _deaf():
		_drop_fingers()
		return
	var gap: float = sim.flow_gap()
	for finger in _fingers:
		var f: Dictionary = _fingers[finger]
		f.t += delta
		if f.t >= gap:
			f.t = 0.0
			_brake(f.at)

# --- drawing ---

## The bar toward what the star is on its way to: the core it needs for the
## next thing to light, the iron that ends it, or the seconds a dim star has
## left.
func _draw_nova_line() -> void:
	var w := _nova_line.size.x
	var h := 12.0
	var goal: Dictionary = sim.goal()
	var share := clampf(float(goal.have) / float(goal.need), 0.0, 1.0)
	var last := String(goal.which) == "fe" or String(goal.which) == "dim"
	_bar(_nova_line, Rect2(0.0, 0.0, w, h), Pal.SURFACE_HI)
	_bar(_nova_line, Rect2(0.0, 0.0, maxf(h, w * share), h), Pal.SUN if last else Pal.SUN_RAY)

## What the star is made of, hydrogen from the left and on down the chain,
## rock last: each a bar from the left as long as everything up to it, the
## heaviest drawn first.
func _draw_made() -> void:
	var w := _made.size.x
	var h := _made.size.y
	var shares: Array = sim.layers()
	var upto := PackedFloat32Array()
	var sum := 0.0
	for share: float in shares:
		sum += share
		upto.append(sum)
	for i in range(shares.size() - 1, -1, -1):
		if i == shares.size() - 1:
			_bar(_made, Rect2(0.0, 0.0, w, h), Art.MADE[i])
		elif float(shares[i]) > 0.002:
			_bar(_made, Rect2(0.0, 0.0, maxf(h, w * minf(1.0, upto[i])), h), Art.MADE[i])

func _bar(on: Control, rect: Rect2, col: Color) -> void:
	var r := rect.size.y * 0.5
	on.draw_rect(Rect2(rect.position + Vector2(r, 0.0), rect.size - Vector2(r * 2.0, 0.0)), col)
	on.draw_circle(rect.position + Vector2(r, r), r, col, true, -1.0, true)
	on.draw_circle(rect.position + Vector2(rect.size.x - r, r), r, col, true, -1.0, true)

# --- leaving ---

func _save() -> void:
	if sim == null:
		return
	sim.save()
	_dirty = false
	_since_save = 0.0

func _on_back() -> void:
	_save()
	Analytics.track("nightlight_leave", {"seconds": int((Time.get_ticks_msec() - _opened_at) / 1000.0),
		"eaten": int(sim.eaten - _eaten_at_open), "mass": int(sim.mass), "novas": sim.novas})
	closed.emit()

## Android's back, through the menu: a card or a sheet first, then the screen.
func go_back() -> void:
	if tutor.close():
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	for card: Control in [_reset, _shop, _perks, _powers]:
		if card.visible:
			card.visible = false
			return
	_on_back()
