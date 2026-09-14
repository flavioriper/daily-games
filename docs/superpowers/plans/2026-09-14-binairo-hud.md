# Binairo HUD rebuild (polish sub-project 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the prototype shell around every board with the concept HUD (wordmark, back / undo / hint / settings, day card, rules card, working-line card, Reset and Check, motto footer, settings sheet) with real undo, hint and check on Binairo, on a shared code-built theme with real fonts and vector icons.

**Architecture:** A thin `ui/puzzle_host.gd` coordinates small panel scripts under `ui/hud/` (each builds itself from `ui/theme.gd`, exposes `refresh(puzzle)` and `enter(delay)`). Puzzles advertise what they support through optional `PuzzleBase` methods with "unsupported" defaults, so the nine 2D prototypes keep working and hide what they lack. `core/motion.gd` grows recipes that work on Controls; `core/progress.gd` owns the day counter.

**Tech Stack:** Godot 4.7, GDScript, gl_compatibility renderer, Godot Theme type variations, `FontVariation` over two OFL variable TTFs, `CanvasItem` polygon drawing.

**Spec:** `docs/superpowers/specs/2026-09-14-binairo-hud-design.md`. Read it first; every number and name below comes from it. Its parent, `docs/superpowers/specs/2026-09-13-binairo-polish-design.md`, describes the motion library this builds on.

## Testing policy (user, 2026-09-14 07:58: "let's avoid wasting time with testing for now")

**Do not write new tests and do not create new test files.** Every "Write the
failing test" step below and every new `tests/test_*.gd` or `tests/stub_puzzle.gd`
file is SKIPPED; do not register new suites in `tests/run_tests.gd`. Also skip
the additions this plan describes for `tests/test_motion.gd`,
`tests/test_binairo3d.gd`, `tests/test_ambient.gd` and `tests/test_palette.gd`.
The one check per task is the **existing** suite staying green
(`godot --headless --path . --script res://tests/run_tests.gd` ends with
`failed=0` and prints no `SCRIPT ERROR`), plus the visual or harness step where
a task names one. When an existing test references something a task renames,
update that test minimally so it keeps passing (Task 3's `_ring_pulse` tidy
line, Task 5's comments).

## Global Constraints

- Renderer is `gl_compatibility`. No `GPUParticles3D`, no screen or depth reads.
- Every colour comes from `core/palette.gd`. New constants: `SUN_DEEP` `d88a12`, `PARCHMENT` `f3e9d2`.
- Every `Motion` recipe returns the `Tween` it made, or `null` under reduce-motion with the end state already set. Callers guard with `if tw != null` or `Motion.stop` / `Motion.running`, which are null-safe.
- UI is built in code, never in the editor. No `.tscn` beyond the existing `world/main.tscn`, `world/stage.tscn`, `ui/menu.tscn`.
- Fonts: `assets/fonts/Fredoka-Variable.ttf` (display) and `assets/fonts/Nunito-Variable.ttf` (body), OFL licences beside them. Missing font files fall back to `ThemeDB.fallback_font`.
- Theme type variation names, exactly: `Wordmark`, `Motto`, `CardTitle`, `CardBody`, `OnSlateTitle`, `OnSlateBody`, `Badge` (Labels); `IconButton`, `PrimaryButton`, `DarkButton` (Buttons).
- Capability strings, exactly: `"undo"`, `"hint"`, `"check"`, `"lines"`.
- Tests: `godot --headless --path . --script res://tests/run_tests.gd` must end with `failed=0`. `godot --path . --resolution 540x960 --script res://tests/_win.gd` must print `winnable=10/10`. Run the full suite before every commit; the runner aborts an erroring test function without counting a failure, so also read the output for `SCRIPT ERROR` lines.
- After adding any new `.gd` file run `godot --headless --path . --import` once so Godot writes its `.uid` file, and commit the `.uid` beside the script (the repo tracks them). Same for `.ttf` files and their `.import`.
- Godot re-saves `project.godot` with a header comment after windowed runs (the win and shot harnesses). Revert that with `git checkout project.godot` before committing unless the task changes `project.godot` on purpose.
- Tabs for indentation in GDScript. `##` doc comments above every class and non-trivial function, as the repo does. Static typing where the type is known; use `node.get("scale")` / `node.set(...)` when a recipe accepts both `Node3D` and `Control`, since GDScript rejects `.scale` on a variable typed `Node`.
- Commit after every task in the repo's style: `feat:`, `fix:`, `test:`, `docs:`, lower-case, present tense, one line.
- Do not touch `art/`, `assets/models/`, `tools/`, or any 3D model; no mascot is placed.

## File structure

| File | Responsibility |
|---|---|
| `core/palette.gd` | Adds `SUN_DEEP`, `PARCHMENT`. |
| `assets/fonts/` (new) | Two variable TTFs and two OFL licence files. |
| `ui/theme.gd` | Fonts (`display()`, `body()`), type variations, card styleboxes (`paper_card()`, `slate_card()`, `parchment_card()`), one cached `Theme`. |
| `ui/icons.gd` (new) | Vector icons as unit-square polygons and polylines; `shape()`, `paint()`, `NAMES`. |
| `core/motion.gd` | Adds `slide`, `pulse`, `appear`; `squash` and `hop` accept Controls. |
| `core/progress.gd` (new) | Day counter on disk, island names. |
| `world/main.gd` (new) | Loads settings in `_enter_tree`. |
| `world/stage.gd` | Stops loading settings. |
| `world/ambient.gd`, `world/fx.gd` | Null guards. |
| `core/puzzle_base.gd` | `focus_changed`, `hints_used`, `checks`, capability hooks, `check_solved()`. |
| `puzzles/binairo3d.gd` | History and undo, hint, check, `line_state`, `focus_changed`, focus ported to `Motion.slide` / `pulse`, three-sentence rules. |
| `ui/hud/panel.gd` (new) | Base of every panel: `_inner`, minimum size, `enter(delay)`. |
| `ui/hud/icon_button.gd` (new) | Button with vector icon, label, badge, squish. |
| `ui/hud/top_bar.gd`, `day_card.gd`, `rules_card.gd`, `line_card.gd`, `action_bar.gd`, `settings_sheet.gd` (new) | The panels. |
| `ui/puzzle_host.gd` | The coordinator. |
| `ui/registry.gd` | `motto` and `footer` for Binairo. |
| `shaders/toon_wind.gdshader` | Mirrored pieces lean the right way. |
| `tests/test_theme.gd`, `test_icons.gd`, `test_progress.gd`, `test_hud.gd`, `stub_puzzle.gd` (new) | New suites and the HUD test double. |
| `tests/test_palette.gd`, `test_motion.gd`, `test_binairo3d.gd`, `test_ambient.gd`, `run_tests.gd`, `_win.gd`, `_shot.gd` | Extended. |
| `README.md`, the spec | Docs. |

---

### Task 1: Palette, fonts and theme

**Files:**
- Modify: `core/palette.gd`
- Create: `assets/fonts/Fredoka-Variable.ttf`, `assets/fonts/Nunito-Variable.ttf`, `assets/fonts/OFL-Fredoka.txt`, `assets/fonts/OFL-Nunito.txt`
- Modify: `ui/theme.gd`
- Create: `tests/test_theme.gd`
- Modify: `tests/test_palette.gd`, `tests/run_tests.gd`

**Interfaces:**
- Produces: `CozyTheme.make() -> Theme` (cached), `CozyTheme.display(weight: int) -> FontVariation`, `CozyTheme.body(weight: int) -> FontVariation`, `CozyTheme.card(fill: Color, radius: int, border: Color, border_w: int, margin: int) -> StyleBoxFlat`, `CozyTheme.paper_card()`, `CozyTheme.slate_card()`, `CozyTheme.parchment_card()`, the type variations listed in Global Constraints, `Pal.SUN_DEEP`, `Pal.PARCHMENT`.

- [ ] **Step 1: Add the palette constants and their test**

In `core/palette.gd`, after the `FOCUS` line:

```gdscript
const SUN_DEEP    := Color("d88a12")   # primary button's bottom edge
const PARCHMENT   := Color("f3e9d2")   # rules card
```

In `tests/test_palette.gd`, add `"SUN_DEEP", "PARCHMENT"` to the name list in `_test_island_colours` and add to `_test_readability`:

```gdscript
	t.check(Pal.contrast(Pal.TEXT, Pal.SUN) >= 4.5, "TEXT on SUN meets 4.5:1, got %.2f" % Pal.contrast(Pal.TEXT, Pal.SUN))
	t.check(Pal.contrast(Pal.TEXT, Pal.PARCHMENT) >= 4.5, "TEXT on PARCHMENT meets 4.5:1, got %.2f" % Pal.contrast(Pal.TEXT, Pal.PARCHMENT))
```

- [ ] **Step 2: Run the suite; the two name checks fail**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -5`
Expected: `FAIL [palette] palette defines SUN_DEEP` and `PARCHMENT` before adding the constants; then add them and see `failed=0`.

- [ ] **Step 3: Download the fonts**

```bash
mkdir -p assets/fonts
curl -sL -o assets/fonts/Fredoka-Variable.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/fredoka/Fredoka%5Bwdth%2Cwght%5D.ttf"
curl -sL -o assets/fonts/Nunito-Variable.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito%5Bwght%5D.ttf"
curl -sL -o assets/fonts/OFL-Fredoka.txt "https://raw.githubusercontent.com/google/fonts/main/ofl/fredoka/OFL.txt"
curl -sL -o assets/fonts/OFL-Nunito.txt "https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/OFL.txt"
file assets/fonts/*.ttf     # both must say "TrueType Font data"
godot --headless --path . --import
ls assets/fonts             # the two .ttf.import files now exist
```

- [ ] **Step 4: Write the failing theme test**

Create `tests/test_theme.gd`:

```gdscript
extends RefCounted

## The shared theme: fonts resolve, every type variation the HUD names exists,
## and every text-on-fill pair the HUD uses reads at 4.5:1 or better.

const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")

const LABELS := ["Wordmark", "Motto", "CardTitle", "CardBody", "OnSlateTitle", "OnSlateBody", "Badge"]
const BUTTONS := ["IconButton", "PrimaryButton", "DarkButton"]

static func run(t) -> void:
	_test_fonts(t)
	_test_variations(t)
	_test_contrast(t)
	_test_cards(t)

static func _test_fonts(t) -> void:
	t.check(ResourceLoader.exists(CozyTheme.DISPLAY_PATH), "the display font file is in assets/fonts")
	t.check(ResourceLoader.exists(CozyTheme.BODY_PATH), "the body font file is in assets/fonts")
	var d: FontVariation = CozyTheme.display(700)
	var b: FontVariation = CozyTheme.body(500)
	t.check(d != null and d.base_font != null, "display() has a base font")
	t.check(b != null and b.base_font != null, "body() has a base font")
	t.eq(int(d.variation_opentype.get(CozyTheme.WGHT, 0)), 700, "display(700) sets the wght axis")
	t.check(CozyTheme.display(700) == d, "font variations are cached")

static func _test_variations(t) -> void:
	var theme: Theme = CozyTheme.make()
	t.check(CozyTheme.make() == theme, "make() returns one cached theme")
	for name in LABELS:
		t.eq(theme.get_type_variation_base(name), "Label", "%s is a Label variation" % name)
		t.check(theme.has_font("font", name) and theme.has_font_size("font_size", name) and theme.has_color("font_color", name), "%s sets font, size and colour" % name)
	for name in BUTTONS:
		t.eq(theme.get_type_variation_base(name), "Button", "%s is a Button variation" % name)
		for state in ["normal", "pressed", "disabled"]:
			t.check(theme.has_stylebox(state, name), "%s has a %s stylebox" % [name, state])
		t.check(theme.has_color("font_disabled_color", name), "%s dims its text when disabled" % name)
	t.eq(theme.get_constant("outline_size", "Wordmark"), 8, "the wordmark has its outline")
	t.check(theme.has_font("font", "Label") and theme.has_font("font", "Button"), "plain labels and buttons take the body font")

static func _test_contrast(t) -> void:
	for pair in [[Pal.TEXT, Pal.PAPER], [Pal.TEXT, Pal.SUN], [Pal.MOON, Pal.SLATE], [Pal.TEXT, Pal.PARCHMENT]]:
		var ratio: float = Pal.contrast(pair[0], pair[1])
		t.check(ratio >= 4.5, "%s on %s reads at 4.5:1, got %.2f" % [pair[0].to_html(false), pair[1].to_html(false), ratio])

static func _test_cards(t) -> void:
	var paper: StyleBoxFlat = CozyTheme.paper_card()
	t.check(paper.border_width_bottom == 6 and paper.corner_radius_top_left == 28, "paper card: thick bottom edge, radius 28")
	var slate: StyleBoxFlat = CozyTheme.slate_card()
	t.check(slate.bg_color.is_equal_approx(Color(Pal.SLATE, 0.92)), "slate card fill")
	var parchment: StyleBoxFlat = CozyTheme.parchment_card()
	t.check(parchment.border_width_left == 3 and parchment.border_width_top == 3, "parchment card: a thin border all round")
```

Register it in `tests/run_tests.gd` after `"palette"`: `"theme": "res://tests/test_theme.gd",`.

- [ ] **Step 5: Run; it fails on missing symbols**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "theme|passed"`
Expected: `FAIL [theme] could not load suite` or script errors naming `DISPLAY_PATH`.

- [ ] **Step 6: Rewrite `ui/theme.gd`**

```gdscript
extends RefCounted

## One warm theme for every Control: the display and body fonts, the card
## styles and the button variants the HUD uses, built in code so it stays in
## step with the palette. One Theme instance is built and shared.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 4.

const Pal = preload("res://core/palette.gd")

const DISPLAY_PATH := "res://assets/fonts/Fredoka-Variable.ttf"
const BODY_PATH := "res://assets/fonts/Nunito-Variable.ttf"
## The OpenType 'wght' axis tag: the four ASCII bytes packed big-endian.
const WGHT := 0x77676874

static var _theme: Theme
static var _fonts: Dictionary = {}

## The shared theme, built once.
static func make() -> Theme:
	if _theme != null:
		return _theme
	var theme := Theme.new()
	# Plain labels and buttons: the body face, today's paper button look.
	theme.set_font("font", "Label", body(500))
	theme.set_color("font_color", "Label", Pal.TEXT)
	theme.set_font("font", "Button", body(700))
	_button(theme, "Button", Pal.SURFACE_HI, Pal.LINE, 6, 28, Pal.TEXT)
	# Label variations.
	_label(theme, "Wordmark", display(700), 72, Pal.SURFACE)
	theme.set_color("font_outline_color", "Wordmark", Pal.OUTLINE)
	theme.set_constant("outline_size", "Wordmark", 8)
	_label(theme, "Motto", body(700), 24, Pal.TEXT_DIM)
	_label(theme, "CardTitle", display(600), 40, Pal.TEXT)
	_label(theme, "CardBody", body(500), 30, Pal.TEXT)
	_label(theme, "OnSlateTitle", display(600), 40, Pal.MOON)
	_label(theme, "OnSlateBody", body(500), 30, Pal.MOON)
	_label(theme, "Badge", display(700), 26, Pal.SURFACE)
	# Button variations.
	_variant(theme, "IconButton", body(700), 34, Pal.SURFACE_HI, Pal.LINE, 6, 28, Pal.TEXT)
	_variant(theme, "PrimaryButton", display(700), 40, Pal.SUN, Pal.SUN_DEEP, 8, 32, Pal.TEXT)
	_variant(theme, "DarkButton", display(700), 40, Pal.SLATE, Pal.SLATE_GIVEN, 8, 32, Pal.MOON)
	_theme = theme
	return theme

## The rounded display face at a weight (Fredoka).
static func display(weight: int) -> FontVariation:
	return _font(DISPLAY_PATH, weight)

## The body face at a weight (Nunito).
static func body(weight: int) -> FontVariation:
	return _font(BODY_PATH, weight)

## A cached FontVariation over the file at `path` with the wght axis set. A
## missing file (a stripped test project) falls back to the engine font.
static func _font(path: String, weight: int) -> FontVariation:
	var key := "%s|%d" % [path, weight]
	if _fonts.has(key):
		return _fonts[key]
	var fv := FontVariation.new()
	var base: Font = null
	if ResourceLoader.exists(path):
		base = load(path) as Font
	fv.base_font = base if base != null else ThemeDB.fallback_font
	fv.variation_opentype = {WGHT: weight}
	_fonts[key] = fv
	return fv

static func _label(theme: Theme, name: String, font: Font, size: int, colour: Color) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, colour)

static func _variant(theme: Theme, name: String, font: Font, size: int, fill: Color, border: Color, border_w: int, radius: int, text: Color) -> void:
	theme.set_type_variation(name, "Button")
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	_button(theme, name, fill, border, border_w, radius, text)

## The four button states for a type: normal and hover alike (touch has no
## hover), pressed sinks onto a 2 px edge and darkens toward LINE, disabled
## fades to 55 percent.
static func _button(theme: Theme, type: String, fill: Color, border: Color, border_w: int, radius: int, text: Color) -> void:
	theme.set_stylebox("normal", type, card(fill, radius, border, border_w, 24))
	theme.set_stylebox("hover", type, card(fill, radius, border, border_w, 24))
	theme.set_stylebox("pressed", type, card(fill.lerp(Pal.LINE, 0.15), radius, border, 2, 24))
	theme.set_stylebox("disabled", type, card(Color(fill, 0.55), radius, Color(border, 0.55), border_w, 24))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, type, text)
	theme.set_color("font_disabled_color", type, Color(text, 0.45))

## A rounded card with a thick bottom edge, the HUD's paper.
static func card(fill: Color, radius: int, border: Color, border_w: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.border_width_bottom = border_w
	sb.border_color = border
	return sb

static func paper_card() -> StyleBoxFlat:
	return card(Color(Pal.PAPER, 0.94), 28, Pal.LINE, 6, 24)

static func slate_card() -> StyleBoxFlat:
	return card(Color(Pal.SLATE, 0.92), 24, Pal.SLATE_GIVEN, 0, 20)

static func parchment_card() -> StyleBoxFlat:
	var sb := card(Color(Pal.PARCHMENT, 0.96), 12, Pal.LINE, 0, 24)
	sb.set_border_width_all(3)
	return sb
```

- [ ] **Step 7: Run the suite and the menu**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `failed=0`.

Run: `godot --path . --resolution 540x960 --script res://tests/_shot.gd 2>&1 | tail -2` then look at `/tmp/shot_menu.png` with the image reader. Expected: the menu's text is in Nunito (rounded, wider than the engine font); nothing else changed. Then `git checkout project.godot`.

- [ ] **Step 8: Commit**

```bash
git add core/palette.gd assets/fonts ui/theme.gd tests/test_theme.gd tests/test_theme.gd.uid tests/test_palette.gd tests/run_tests.gd
git commit -m "feat: theme with Fredoka and Nunito, type variations and card styles"
```

---

### Task 2: Vector icons

**Files:**
- Create: `ui/icons.gd`
- Create: `tests/test_icons.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Produces: `Icons.NAMES: Array`, `Icons.shape(name: String) -> Dictionary` with keys `polys: Array[PackedVector2Array]`, `lines: Array[PackedVector2Array]`, optional `hole: PackedVector2Array`; `Icons.paint(ci: CanvasItem, name: String, rect: Rect2, colour: Color, hole := Color.TRANSPARENT) -> void`; `Icons.circle(centre, radius, segments := 24) -> PackedVector2Array`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_icons.gd`:

```gdscript
extends RefCounted

## The HUD's vector icons are pure geometry inside the unit square, so a
## button can paint them at any size in any palette colour.

const Icons = preload("res://ui/icons.gd")

static func run(t) -> void:
	t.eq(Icons.NAMES.size(), 8, "eight icons")
	for name in Icons.NAMES:
		var s: Dictionary = Icons.shape(name)
		t.check(s.polys.size() + s.lines.size() > 0, "%s has a shape" % name)
		for poly in s.polys:
			t.check(poly.size() >= 3, "%s: a polygon has three points or more" % name)
			t.check(_inside(poly), "%s: a polygon stays in the unit square" % name)
		for line in s.lines:
			t.check(line.size() >= 2, "%s: a polyline has two points or more" % name)
			t.check(_inside(line), "%s: a polyline stays in the unit square" % name)
	t.check(Icons.shape("gear").has("hole") and _inside(Icons.shape("gear").hole), "the gear has a hole in the unit square")
	t.check(Icons.shape("nope").polys.is_empty() and Icons.shape("nope").lines.is_empty(), "an unknown name is empty, not an error")
	t.eq(Icons.circle(Vector2(0.5, 0.5), 0.5).size(), 24, "circles have 24 segments by default")

static func _inside(pts: PackedVector2Array) -> bool:
	for p in pts:
		if p.x < -0.001 or p.x > 1.001 or p.y < -0.001 or p.y > 1.001:
			return false
	return true
```

Register after `"theme"`: `"icons": "res://tests/test_icons.gd",`.

- [ ] **Step 2: Run; the suite fails to load**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "icons|passed"`
Expected: `FAIL [icons] could not load suite`.

- [ ] **Step 3: Create `ui/icons.gd`**

```gdscript
extends RefCounted

## Vector icons for the HUD: polygons and polylines in the unit square, so
## they take any colour and any size and can be tested headless. paint()
## draws one into a CanvasItem during that item's draw call.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 4.

const NAMES := ["chevron_left", "undo", "reset", "bulb", "gear", "check", "leaf", "island"]
const SEGMENTS := 24
## Stroke width of polylines as a fraction of the icon's width.
const STROKE := 0.12

## The geometry of one icon: {"polys": [...], "lines": [...]} and, for the
## gear, "hole". Unknown names give an empty shape.
static func shape(name: String) -> Dictionary:
	match name:
		"chevron_left":
			return {"polys": [], "lines": [PackedVector2Array([Vector2(0.62, 0.18), Vector2(0.34, 0.5), Vector2(0.62, 0.82)])]}
		"undo":
			return _arrow_arc(false)
		"reset":
			return _arrow_arc(true)
		"bulb":
			return _bulb()
		"gear":
			return _gear()
		"check":
			return {"polys": [], "lines": [PackedVector2Array([Vector2(0.2, 0.52), Vector2(0.42, 0.74), Vector2(0.8, 0.28)])]}
		"leaf":
			return _leaf()
		"island":
			return _island()
	return {"polys": [], "lines": []}

## Draws `name` into `rect` on `ci` in `colour`. Call only from `ci`'s draw
## callback. `hole`, when opaque, fills the shape's hole polygon on top (the
## gear's centre takes the button's fill).
static func paint(ci: CanvasItem, name: String, rect: Rect2, colour: Color, hole := Color.TRANSPARENT) -> void:
	var s := shape(name)
	var xf := Transform2D(0.0, rect.size, 0.0, rect.position)
	for poly in s.polys:
		ci.draw_colored_polygon(xf * poly, colour)
	var width := STROKE * rect.size.x
	for line in s.lines:
		ci.draw_polyline(xf * line, colour, width, true)
	if hole.a > 0.0 and s.has("hole"):
		ci.draw_colored_polygon(xf * s.hole, hole)

static func circle(centre: Vector2, radius: float, segments := SEGMENTS) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)
	return pts

static func arc(centre: Vector2, radius: float, from: float, to: float, segments := SEGMENTS) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments + 1:
		var a := lerpf(from, to, float(i) / segments)
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)
	return pts

## A three-quarter arc from 12 o'clock with an arrowhead at its end. Undo runs
## anticlockwise and ends at 3 o'clock; reset runs clockwise and ends at 9
## o'clock. At both ends the arc is travelling upward, so the head points up.
static func _arrow_arc(clockwise: bool) -> Dictionary:
	var c := Vector2(0.5, 0.54)
	var r := 0.3
	var start := -PI * 0.5
	var end := start + (PI * 1.5 if clockwise else -PI * 1.5)
	var a := arc(c, r, start, end)
	var tip: Vector2 = a[a.size() - 1]
	var head := PackedVector2Array([tip + Vector2(0.0, -0.2), tip + Vector2(-0.13, 0.02), tip + Vector2(0.13, 0.02)])
	return {"polys": [head], "lines": [a]}

static func _bulb() -> Dictionary:
	var glass := circle(Vector2(0.5, 0.4), 0.24)
	var neck := PackedVector2Array([Vector2(0.38, 0.6), Vector2(0.62, 0.6), Vector2(0.6, 0.78), Vector2(0.4, 0.78)])
	var base := PackedVector2Array([Vector2(0.4, 0.8), Vector2(0.6, 0.8), Vector2(0.58, 0.9), Vector2(0.42, 0.9)])
	var rays := [
		PackedVector2Array([Vector2(0.1, 0.4), Vector2(0.2, 0.4)]),
		PackedVector2Array([Vector2(0.8, 0.4), Vector2(0.9, 0.4)]),
	]
	return {"polys": [glass, neck, base], "lines": rays}

## Eight teeth on a ring: two steps out, two steps in, round the circle.
static func _gear() -> Dictionary:
	var c := Vector2(0.5, 0.5)
	var steps := 32
	var pts := PackedVector2Array()
	for i in steps:
		var a := TAU * i / steps
		var r := 0.42 if (i % 4) < 2 else 0.32
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return {"polys": [pts], "lines": [], "hole": circle(c, 0.13)}

## Two arcs from the stem (bottom-left) to the tip (top-right) closed into one
## polygon, plus a midrib.
static func _leaf() -> Dictionary:
	var a := Vector2(0.15, 0.85)
	var b := Vector2(0.85, 0.15)
	var perp := Vector2(0.7071, 0.7071)
	var pts := PackedVector2Array()
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		pts.append(a.lerp(b, t) - perp * sin(t * PI) * 0.22)
	for i in SEGMENTS + 1:
		var t := 1.0 - float(i) / SEGMENTS
		pts.append(a.lerp(b, t) + perp * sin(t * PI) * 0.22)
	return {"polys": [pts], "lines": [PackedVector2Array([a, a.lerp(b, 0.85)])]}

static func _island() -> Dictionary:
	var mound := PackedVector2Array([Vector2(0.08, 0.86), Vector2(0.2, 0.66), Vector2(0.4, 0.58), Vector2(0.6, 0.58), Vector2(0.8, 0.66), Vector2(0.92, 0.86)])
	var trunk := PackedVector2Array([Vector2(0.5, 0.6), Vector2(0.5, 0.36)])
	var canopy := circle(Vector2(0.5, 0.26), 0.18)
	return {"polys": [mound, canopy], "lines": [trunk]}
```

- [ ] **Step 4: Run; passes**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `failed=0`, and `godot --headless --path . --import` for the `.uid`.

- [ ] **Step 5: Commit**

```bash
git add ui/icons.gd ui/icons.gd.uid tests/test_icons.gd tests/test_icons.gd.uid tests/run_tests.gd
git commit -m "feat: vector icons as unit-square polygons for the HUD"
```

---

### Task 3: Motion recipes for the HUD, and the focus ring ported onto them

**Files:**
- Modify: `core/motion.gd`
- Modify: `puzzles/binairo3d.gd` (the focus ring section: `_focus`, `_start_pulse`, `_focus_fade`, `_stop_all`, the `_ring_pulse` field)
- Modify: `tests/test_motion.gd`, `tests/test_binairo3d.gd` (tidy block near line 252)

**Interfaces:**
- Produces: `Motion.slide(node: Node, property: String, from, to, time: float, delay := 0.0, overshoot := true) -> Tween`; `Motion.pulse(node: Node, property: String, rest, peak, period: float, target: Object = null) -> Tween`; `Motion.appear(item: CanvasItem, from: float, to: float, time: float, delay := 0.0) -> Tween`; `Motion.squash(node: Node, ...)` and `Motion.hop(node: Node, ...)` accepting a `Control`.
- Binairo keeps `_ring_tw`, `_ring_hold`, `_ring_pulse` (scale pulse) and gains `_ring_pulse_a` (alpha pulse on the material).

- [ ] **Step 1: Write the failing tests**

In `tests/test_motion.gd`, add a `Control` to the fixture and call the new tests. Replace `run_in_tree` with:

```gdscript
static func run_in_tree(t) -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var node := Node3D.new()
	root.add_child(node)
	var ctl := Control.new()
	ctl.size = Vector2(100, 50)
	root.add_child(ctl)
	Motion.reduce = false
	_test_settle(t, node)
	_test_hop(t, node)
	_test_squash(t, node)
	_test_wobble(t, node)
	_test_fade(t, node)
	_test_stagger(t)
	_test_stop_and_running(t, node)
	_test_slide(t, node, ctl)
	_test_pulse(t, node)
	_test_appear(t, ctl)
	_test_control_recipes(t, ctl)
	_test_reduce(t, node)
	_test_reduce_2d(t, node, ctl)
	_test_settings(t)
	Motion.reduce = false
	root.remove_child(node)
	node.free()
	root.remove_child(ctl)
	ctl.free()
```

And append:

```gdscript
## slide puts the property at `from` at once and lands exactly on `to`, on a
## Node3D and on a Control, with either ease.
static func _test_slide(t, node: Node3D, ctl: Control) -> void:
	var tw: Tween = Motion.slide(node, "position", Vector3(0, -1, 0), Vector3(2, 0, 0), 0.3)
	t.check(node.position.is_equal_approx(Vector3(0, -1, 0)), "slide starts at from")
	tw.custom_step(0.31)
	t.check(node.position.is_equal_approx(Vector3(2, 0, 0)), "slide lands on to (back ease)")
	var tw2: Tween = Motion.slide(ctl, "position", Vector2(-120, 0), Vector2.ZERO, 0.3, 0.0, false)
	t.check(ctl.position.is_equal_approx(Vector2(-120, 0)), "slide starts at from on a Control")
	tw2.custom_step(0.31)
	t.check(ctl.position.is_equal_approx(Vector2.ZERO), "slide lands on to (sine ease)")
	var tw3: Tween = Motion.slide(ctl, "position:y", 300.0, 0.0, 0.3)
	tw3.custom_step(0.31)
	t.check(is_zero_approx(ctl.position.y), "slide works on a sub-property")

## pulse loops between rest and peak; after a whole period it is back at rest.
static func _test_pulse(t, node: Node3D) -> void:
	node.scale = Vector3.ONE
	var tw: Tween = Motion.pulse(node, "scale", Vector3.ONE, Vector3(1.04, 1.0, 1.04), 1.2)
	t.check(Motion.running(tw), "pulse returns a running tween")
	tw.custom_step(0.6)
	t.check(node.scale.x > 1.03, "half way through, the pulse is at its peak (%.3f)" % node.scale.x)
	tw.custom_step(0.6)
	t.check(node.scale.is_equal_approx(Vector3.ONE), "after a period the pulse is back at rest")
	t.check(Motion.running(tw), "the pulse keeps looping")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.9)
	var tw2: Tween = Motion.pulse(node, "albedo_color:a", 0.9, 0.6, 1.2, mat)
	tw2.custom_step(0.6)
	t.check(is_equal_approx(mat.albedo_color.a, 0.6), "pulse can drive another object's property")
	Motion.stop(tw)
	Motion.stop(tw2)

## appear fades modulate alpha between two values.
static func _test_appear(t, ctl: Control) -> void:
	var tw: Tween = Motion.appear(ctl, 0.0, 1.0, 0.25)
	t.check(is_zero_approx(ctl.modulate.a), "appear starts at from")
	tw.custom_step(0.26)
	t.check(is_equal_approx(ctl.modulate.a, 1.0), "appear lands on to")

## squash and hop take a Control as well as a Node3D.
static func _test_control_recipes(t, ctl: Control) -> void:
	ctl.scale = Vector2.ONE
	ctl.pivot_offset = ctl.size * 0.5
	var sq: Tween = Motion.squash(ctl, 0.1, 0.18)
	t.check(sq != null, "squash accepts a Control")
	sq.custom_step(0.072)
	t.check(ctl.scale.y < 0.95 and ctl.scale.x > 1.02, "a Control squashes flatter and wider (%s)" % ctl.scale)
	sq.custom_step(0.2)
	t.check(ctl.scale.is_equal_approx(Vector2.ONE), "a Control springs back to scale one")
	ctl.position = Vector2(10, 40)
	var hp: Tween = Motion.hop(ctl, -6.0, 0.3)
	t.check(hp != null, "hop accepts a Control")
	hp.custom_step(0.15)
	t.check(ctl.position.y < 36.0, "a Control hop moves position.y (%.2f)" % ctl.position.y)
	hp.custom_step(0.2)
	t.check(is_equal_approx(ctl.position.y, 40.0), "a Control hop comes home")

## Under reduce-motion the new recipes set their end state and return null.
static func _test_reduce_2d(t, node: Node3D, ctl: Control) -> void:
	Motion.reduce = true
	t.check(Motion.slide(ctl, "position", Vector2(-120, 0), Vector2(7, 7), 0.3) == null and ctl.position.is_equal_approx(Vector2(7, 7)), "reduce: slide lands at once")
	node.scale = Vector3(2, 2, 2)
	t.check(Motion.pulse(node, "scale", Vector3.ONE, Vector3(1.04, 1.0, 1.04), 1.2) == null and node.scale.is_equal_approx(Vector3.ONE), "reduce: pulse rests at once")
	t.check(Motion.appear(ctl, 0.0, 1.0, 0.25) == null and is_equal_approx(ctl.modulate.a, 1.0), "reduce: appear lands at once")
	t.check(Motion.squash(ctl) == null and Motion.hop(ctl, -6.0, 0.3) == null, "reduce: squash and hop on a Control return null")
	Motion.reduce = false
```

- [ ] **Step 2: Run; fails on `slide`**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "motion|SCRIPT ERROR|passed" | head`
Expected: a script error naming `slide` (the runner prints `FAIL runner: _initialize did not complete` or the motion suite errors).

- [ ] **Step 3: Add the recipes to `core/motion.gd`**

Replace `hop` and `squash` with versions that accept a `Node`, and add `slide`, `pulse`, `appear` after `stagger`:

```gdscript
## Lifts position.y by `height` and comes back down; a negative height dips.
## `base` is the resting height; it defaults to the node's current height,
## so pass it explicitly for a node that may already be mid-hop. Works on a
## Node3D or a Control (both have a `position` with a y).
static func hop(node: Node, height: float, time: float, delay := 0.0, base := NAN) -> Tween:
	if reduce:
		return null
	if is_nan(base):
		base = node.get("position").y
	var tw := node.create_tween()
	tw.tween_property(node, "position:y", base + height, time * 0.5).set_delay(delay) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position:y", base, time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return tw

## Flattens y by `amount` and widens the other axes by half of it, then
## springs back. A Node3D squashes in x and z; a Control in x, around its
## pivot_offset.
static func squash(node: Node, amount := 0.12, time := 0.18, delay := 0.0) -> Tween:
	if reduce:
		return null
	var base = node.get("scale")
	var squashed
	if base is Vector2:
		squashed = Vector2(base.x * (1.0 + amount * 0.5), base.y * (1.0 - amount))
	else:
		squashed = Vector3(base.x * (1.0 + amount * 0.5), base.y * (1.0 - amount), base.z * (1.0 + amount * 0.5))
	var tw := node.create_tween()
	tw.tween_property(node, "scale", squashed, time * 0.4).set_delay(delay) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base, time * 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw
```

```gdscript
## Puts `property` at `from` at once, then eases it to `to`: with `overshoot`
## the back ease (it passes `to` a little and springs home), otherwise sine
## in-out. Decorative: under reduce-motion `to` is set and null returned.
static func slide(node: Node, property: String, from, to, time: float, delay := 0.0, overshoot := true) -> Tween:
	if reduce:
		node.set_indexed(property, to)
		return null
	node.set_indexed(property, from)
	var tw := node.create_tween()
	var step := tw.tween_property(node, property, to, time).set_delay(delay)
	if overshoot:
		step.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		step.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

## Breathes `property` of `target` (the node itself by default) between `rest`
## and `peak` forever, sine in-out, one cycle per `period`. The caller keeps
## and kills the tween. Under reduce-motion `rest` is set and null returned.
static func pulse(node: Node, property: String, rest, peak, period: float, target: Object = null) -> Tween:
	if target == null:
		target = node
	if reduce:
		target.set_indexed(property, rest)
		return null
	var half := period * 0.5
	var tw := node.create_tween().set_loops()
	tw.tween_property(target, property, peak, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(target, property, rest, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

## Fades a CanvasItem's modulate alpha from `from` to `to`. Under
## reduce-motion `to` is set and null returned.
static func appear(item: CanvasItem, from: float, to: float, time: float, delay := 0.0) -> Tween:
	if reduce:
		item.modulate.a = to
		return null
	item.modulate.a = from
	var tw := item.create_tween()
	tw.tween_property(item, "modulate:a", to, time).set_delay(delay)
	return tw
```

Update the doc comment block at the top of the file to mention the HUD spec as a second spec reference.

- [ ] **Step 4: Run; motion passes**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `failed=0`.

- [ ] **Step 5: Port the focus ring**

In `puzzles/binairo3d.gd`: rename the field comment and add the alpha pulse:

```gdscript
var _ring_tw: Tween       # pop, slide or fade
var _ring_pulse: Tween    # the scale breath while shown
var _ring_pulse_a: Tween  # the alpha breath while shown, on the material
var _ring_hold: Tween     # the pause before the fade
```

In `_stop_all`, add `Motion.stop(_ring_pulse_a)` beside `Motion.stop(_ring_pulse)`.

Replace the `elif shown:` branch of `_focus` with:

```gdscript
	elif shown:
		_ring_tw = Motion.slide(_ring, "position", _ring.position, at, FOCUS_MOVE, 0.0, false)
		if not Motion.running(_ring_pulse):
			# A tap during the fade: bring the ring back up and pulse again.
			_ring_tw.parallel().tween_property(_ring_mat, "albedo_color:a", FOCUS_ALPHA, FOCUS_MOVE)
			_ring_tw.finished.connect(_start_pulse)
```

Replace `_start_pulse` with:

```gdscript
## The breathing loop: a little larger and dimmer, then back, while shown.
func _start_pulse() -> void:
	_stop_pulse()
	if Motion.reduce or not _ring.visible:
		return
	_ring_pulse = Motion.pulse(_ring, "scale", Vector3.ONE, Vector3(1.04, 1.0, 1.04), FOCUS_PULSE)
	_ring_pulse_a = Motion.pulse(_ring, "albedo_color:a", FOCUS_ALPHA, FOCUS_ALPHA_LOW, FOCUS_PULSE, _ring_mat)

func _stop_pulse() -> void:
	Motion.stop(_ring_pulse)
	Motion.stop(_ring_pulse_a)
	_ring_pulse = null
	_ring_pulse_a = null
```

In `_focus` (the `if Motion.reduce:` and `else:` branches) and in `_focus_fade`, replace `Motion.stop(_ring_pulse)` with `_stop_pulse()`.

In `tests/test_binairo3d.gd`, the tidy block around line 252 stops `p._ring_pulse`; add `Motion.stop(p._ring_pulse_a)` under it.

- [ ] **Step 6: Run the suite; the focus ring tests still pass**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "binairo3d|passed"`
Expected: no `FAIL [binairo3d]` lines, `failed=0`.

- [ ] **Step 7: Commit**

```bash
git add core/motion.gd puzzles/binairo3d.gd tests/test_motion.gd tests/test_binairo3d.gd
git commit -m "feat: slide, pulse and appear recipes; squash and hop take Controls; focus ring on the recipes"
```

---

### Task 4: Progress on disk

**Files:**
- Create: `core/progress.gd`
- Create: `tests/test_progress.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `Daily.date_key(dt := {}) -> int` from `core/daily.gd` (a global class).
- Produces: `Progress.path: String` (static, default `user://progress.cfg`), `Progress.touch(date_key: int = Daily.date_key()) -> int`, `Progress.day() -> int`, `Progress.island_name(date_key: int = Daily.date_key()) -> String`, `Progress.ISLANDS: Array`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_progress.gd`:

```gdscript
extends RefCounted

## The day counter: one step per new date the player opens a puzzle on,
## persisted, plus a deterministic island name per date.

const Progress = preload("res://core/progress.gd")

const PATH := "user://_test_progress.cfg"

static func run(t) -> void:
	Progress.path = PATH
	DirAccess.remove_absolute(PATH)
	t.eq(Progress.day(), 0, "no file, day 0")
	t.eq(Progress.touch(20260914), 1, "the first date is day 1")
	t.eq(Progress.touch(20260914), 1, "the same date again is still day 1")
	t.eq(Progress.touch(20260915), 2, "a new date is day 2")
	t.eq(Progress.day(), 2, "day() reads the file back")
	var cfg := ConfigFile.new()
	t.check(cfg.load(PATH) == OK and int(cfg.get_value("progress", "days", 0)) == 2 and int(cfg.get_value("progress", "last_date", 0)) == 20260915, "the file holds days and last_date")
	t.eq(Progress.ISLANDS.size(), 24, "24 island names")
	var a: String = Progress.island_name(20260914)
	t.check(Progress.ISLANDS.has(a), "island_name comes from the list")
	t.eq(Progress.island_name(20260914), a, "island_name is stable for a date")
	var distinct := {}
	for d in range(20260901, 20260931):
		distinct[Progress.island_name(d)] = true
	t.check(distinct.size() >= 8, "a month of dates spreads over the list (%d names)" % distinct.size())
	DirAccess.remove_absolute(PATH)
	Progress.path = "user://progress.cfg"
```

Register after `"icons"`: `"progress": "res://tests/test_progress.gd",`.

- [ ] **Step 2: Run; the suite fails to load**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "progress|passed"`
Expected: `FAIL [progress] could not load suite`.

- [ ] **Step 3: Create `core/progress.gd`**

```gdscript
class_name Progress
extends RefCounted

## The player's progress on disk: how many distinct days they have opened a
## puzzle on (the HUD's "Day N") and a themed island name per date. Kept in
## its own file so it never races the motion settings.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 6.

static var path: String = "user://progress.cfg"

const ISLANDS := [
	"Sunlit Cliffs", "Moss Harbour", "Lantern Cove", "Driftwood Point",
	"Heron Shallows", "Fernwater Isle", "Pebble Reach", "Windmere Rock",
	"Tidepool Terrace", "Quiet Anchorage", "Bramble Key", "Saltgrass Hollow",
	"Kestrel Ledge", "Cinder Shoal", "Lily Landing", "Foxglove Cay",
	"Willow Strand", "Marigold Bank", "Otter Narrows", "Copper Cliffs",
	"Starling Rise", "Seagrass Flats", "Birch Haven", "Puffin Steps",
]

## Records that the player opened a puzzle on `date_key` (a Daily.date_key
## value) and returns the day number. Only a date different from the last
## recorded one counts.
static func touch(date_key: int = Daily.date_key()) -> int:
	var cfg := ConfigFile.new()
	cfg.load(path)  # a missing file is fine
	var days := int(cfg.get_value("progress", "days", 0))
	var last := int(cfg.get_value("progress", "last_date", 0))
	if date_key != last:
		days += 1
		cfg.set_value("progress", "days", days)
		cfg.set_value("progress", "last_date", date_key)
		cfg.save(path)
	return days

## The day number on disk; 0 before the first touch.
static func day() -> int:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return int(cfg.get_value("progress", "days", 0))

## The island name for a date, the same for everyone on that date.
static func island_name(date_key: int = Daily.date_key()) -> String:
	return ISLANDS[posmod(hash(str(date_key)), ISLANDS.size())]
```

- [ ] **Step 4: Run; passes**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `failed=0`. If the month-spread check fails, the hash is fine and the threshold is wrong: lower it to 6 and note it in the commit.

- [ ] **Step 5: Commit**

```bash
godot --headless --path . --import
git add core/progress.gd core/progress.gd.uid tests/test_progress.gd tests/test_progress.gd.uid tests/run_tests.gd
git commit -m "feat: progress file with the day counter and island names"
```

---

### Task 5: Settings load on the scene root; null guards in Ambient and Fx

**Files:**
- Create: `world/main.gd`
- Modify: `world/main.tscn`, `world/stage.gd`, `world/ambient.gd`, `world/fx.gd`
- Modify: `tests/test_ambient.gd`, `tests/test_binairo3d.gd` (comments only)

**Interfaces:**
- Produces: `world/main.gd` on the `Main` node, `_enter_tree()` calling `Motion.load_settings()`. `Stage._ready()` no longer loads settings.

- [ ] **Step 1: Write the failing test**

In `tests/test_ambient.gd`, add a call `_test_detached(t)` at the end of the test list inside `run_in_tree` (before the teardown) and append:

```gdscript
## An Ambient or Fx that never entered the tree (no _ready, so no pollen and
## no pools) must shrug off calls, not error: a board can outlive its stage.
static func _test_detached(t) -> void:
	var loose := Ambient.new()
	loose.refresh()
	loose.splash(Vector3.ZERO)
	t.check(loose.pollen == null, "a detached Ambient has no pollen and did not error on refresh or splash")
	loose.free()
	var fx = load("res://world/fx.gd").new()
	fx.puff(Vector3.ZERO)
	fx.sparkle(Vector3.ZERO)
	t.check(fx.puffs.is_empty(), "a detached Fx has no pools and did not error on puff or sparkle")
	fx.free()
```

- [ ] **Step 2: Run; the ambient suite errors**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "ambient|SCRIPT ERROR|Invalid|passed" | head`
Expected: a script error (`Invalid access to property 'emitting' on a null instance` or the puff pool index error) and the run does not reach `failed=0` cleanly.

- [ ] **Step 3: Add the guards**

`world/ambient.gd`, `refresh()`:

```gdscript
func refresh() -> void:
	RenderingServer.global_shader_parameter_set(GLOBAL, motion_scale())
	if pollen == null:
		return
	var on := not Motion.reduce
	if on and not pollen.emitting:
		pollen.restart()
	pollen.emitting = on
	pollen.visible = on
```

`splash()` and `_process()`: fetch `var mat := Toon.water()` once, `if mat == null: return`, and use `mat.set_shader_parameter(...)` for the three calls.

`world/fx.gd`, at the top of `puff` and `sparkle`, after the reduce check:

```gdscript
	if puffs.is_empty():
		return
```
and
```gdscript
	if sparkles.is_empty():
		return
```

- [ ] **Step 4: Move the settings load**

Create `world/main.gd`:

```gdscript
extends Node

## The scene root. Loads the saved settings in _enter_tree, which runs before
## any child enters the tree, so the stage and its Ambient see the flag on
## their first frame. Nothing else lives here.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 6.

const Motion = preload("res://core/motion.gd")

func _enter_tree() -> void:
	Motion.load_settings()
```

`world/main.tscn` becomes:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://world/main.gd" id="0_main"]
[ext_resource type="PackedScene" path="res://world/stage.tscn" id="1_stage"]
[ext_resource type="PackedScene" path="res://ui/menu.tscn" id="2_menu"]

[node name="Main" type="Node"]
script = ExtResource("0_main")

[node name="Stage" parent="." instance=ExtResource("1_stage")]

[node name="UI" type="CanvasLayer" parent="."]

[node name="Menu" parent="UI" instance=ExtResource("2_menu")]
```

`world/stage.gd`: delete the `Motion.load_settings()` line in `_ready` and the `Motion` preload if nothing else uses it. In `tests/test_ambient.gd` and `tests/test_binairo3d.gd` change the comment that says `Stage._ready()` loads settings to: "A throwaway path: nothing in this suite should touch the developer's real user://settings.cfg."

- [ ] **Step 5: Run the suite and a windowed run**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3` — expected `failed=0`.

Run: `printf '[motion]\nreduce=true\n' > /tmp/reduce.cfg && cp /tmp/reduce.cfg "$HOME/Library/Application Support/Godot/app_userdata/Daily/settings.cfg" && godot --path . --resolution 540x960 --script res://tests/_shot.gd 2>&1 | tail -1` then view `/tmp/shot_binairo.png`: with reduce on, the pollen specks are absent. Then remove the file: `rm "$HOME/Library/Application Support/Godot/app_userdata/Daily/settings.cfg"` and `git checkout project.godot`.

- [ ] **Step 6: Commit**

```bash
godot --headless --path . --import
git add world/main.gd world/main.gd.uid world/main.tscn world/stage.gd world/ambient.gd world/fx.gd tests/test_ambient.gd tests/test_binairo3d.gd
git commit -m "fix: settings load on the scene root; Ambient and Fx shrug off calls before ready"
```

---

### Task 6: Puzzle capabilities; Binairo history, undo, focus signal and line state

**Files:**
- Modify: `core/puzzle_base.gd`
- Modify: `puzzles/binairo3d.gd`
- Modify: `tests/test_binairo3d.gd`

**Interfaces:**
- Produces on `PuzzleBase`: `signal focus_changed`, `var hints_used: int`, `var checks: int`, `capabilities() -> Array[String]`, `can_undo() -> bool`, `undo() -> bool`, `hints_left() -> int`, `hint() -> bool`, `check() -> int`, `line_state() -> Dictionary`, `check_solved() -> void`.
- Produces on Binairo: `_history: Array[Vector3i]` of `(r, c, previous value)`; `_roll(r, c, thirds, delay)` accepting a negative `thirds`; `_on_roll_landed(r, c, away)`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_binairo3d.gd`, insert two calls after `_test_locked_cell(t, p)` and before `_test_reset_wave(t, p)` (the solved-wave test later marks the board done, so everything new must run before it):

```gdscript
	_test_undo(t, p)
	_test_line_state(t, p)
```

Append:

```gdscript
## Undo (HUD spec, section 3): the last tap comes back, the prism rolls one
## third away from the player, a negative turn count still shows the right
## face, and no move is counted.
static func _test_undo(t, p) -> void:
	t.check(p.capabilities().has("undo"), "binairo supports undo")
	var a := _find_cell(p, false)
	var r := a.y
	var c := a.x
	p._settle(r, c)
	p._history = []
	t.check(not p.can_undo() and not p.undo(), "nothing to undo with an empty history")
	var before: int = p._grid[r][c]
	var turns_before: int = p._turns[r][c]
	var focus_count := [0]
	var on_focus := func() -> void: focus_count[0] += 1
	p.focus_changed.connect(on_focus)
	_tap(p, r, c)
	t.check(p.can_undo(), "a tap makes undo available")
	t.eq(focus_count[0], 1, "a tap emits focus_changed")
	t.eq(p._history.size(), 1, "the tap is in the history")
	var moves_after_tap: int = p.moves
	p._settle(r, c)
	t.check(p.undo(), "undo returns true")
	t.eq(p._grid[r][c], before, "undo restores the grid value")
	t.eq(p._turns[r][c], turns_before, "undo takes one third back")
	t.eq(p.moves, moves_after_tap, "undo does not count a move")
	t.check(Motion.running(p._rolls[r][c]), "undo rolls")
	var mid_angle: float = p._cells[r][c].rotation.x
	p._rolls[r][c].custom_step(p.ROLL_TIME * 0.25)
	t.check(p._cells[r][c].rotation.x > mid_angle, "the undo roll turns the other way (away from the player)")
	p._rolls[r][c].custom_step(p.ROLL_TIME)
	t.check(is_equal_approx(p._cells[r][c].rotation.x, p._target_angle(r, c)), "the away roll lands on the face")
	t.eq(p.fx.last_cue, "undo", "undo names its cue")
	t.check(not p.can_undo(), "the history is empty again")
	t.eq(focus_count[0], 2, "undo moves the focus")
	# Negative turn counts pick the right face.
	p._settle(r, c)
	var saved_turns: int = p._turns[r][c]
	p._turns[r][c] = -1
	p._show_faces(r, c, false)
	t.check(p._moons[r][c].visible and not p._suns[r][c].visible and not p._marks[r][c].visible, "turns -1 shows the moon face")
	p._turns[r][c] = -2
	p._show_faces(r, c, false)
	t.check(p._suns[r][c].visible and not p._moons[r][c].visible, "turns -2 shows the sun face")
	p._turns[r][c] = saved_turns
	p._settle(r, c)
	p.focus_changed.disconnect(on_focus)
	p._focus_clear()

## line_state (HUD spec, section 3): empty without a focus, else the focused
## row and column with their indices.
static func _test_line_state(t, p) -> void:
	t.check(p.capabilities().has("lines"), "binairo supports lines")
	p._focus_clear()
	t.check(p.line_state().is_empty(), "no focus, no lines")
	var g := _find_cell(p, true)
	_tap(p, g.y, g.x)
	var s: Dictionary = p.line_state()
	t.eq(s.row.index, g.y, "row index is the focused row")
	t.eq(s.col.index, g.x, "col index is the focused column")
	t.eq(s.row.cells, p._grid[g.y], "row cells match the grid")
	var col := []
	for i in p.n:
		col.append(p._grid[i][g.x])
	t.eq(s.col.cells, col, "col cells match the grid")
	p._settle(g.y, g.x)
	p._focus_clear()
```

- [ ] **Step 2: Run; errors on `capabilities`**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "binairo3d|SCRIPT ERROR|Invalid call|passed" | head`
Expected: an error naming `capabilities` or `_history`.

- [ ] **Step 3: Extend `core/puzzle_base.gd`**

After `signal moved`:

```gdscript
## A board that tracks a focused cell emits this when the focus moves or clears.
signal focus_changed
```

After `var elapsed`:

```gdscript
var hints_used: int = 0
var checks: int = 0
```

After `func is_3d()` in the override block:

```gdscript
# --- optional, for the HUD (docs/superpowers/specs/2026-09-14-binairo-hud-design.md,
# section 3). Defaults mean "unsupported"; the HUD hides what a puzzle lacks. ---
## Which optional actions this puzzle supports: any of "undo", "hint", "check", "lines".
func capabilities() -> Array[String]: return []
func can_undo() -> bool: return false
## Reverts the last move. True when something was undone.
func undo() -> bool: return false
func hints_left() -> int: return 0
## Fills one cell from the solution. True when a cell was filled.
func hint() -> bool: return false
## Marks the cells that differ from the solution. Returns how many; -1 when unsupported.
func check() -> int: return -1
## {} when nothing is focused, else {"row": {"index": r, "cells": [...]},
## "col": {"index": c, "cells": [...]}} with cells -1 empty, 0 sun, 1 moon.
func line_state() -> Dictionary: return {}
```

`start()` also sets `hints_used = 0` and `checks = 0`. Replace `note_move` with:

```gdscript
func note_move() -> void:
	moves += 1
	moved.emit()
	check_solved()

## Ends the puzzle if the board is solved. note_move calls this; hints and
## undos call it directly because they do not count as moves.
func check_solved() -> void:
	if not _done and is_solved():
		_done = true
		_running = false
		solved.emit()
```

- [ ] **Step 4: Extend `puzzles/binairo3d.gd`**

Fields, after `_entrance`:

```gdscript
## Taps on free cells as (r, c, previous value), newest last. Undo pops it.
var _history: Array[Vector3i] = []
```

`build()`: add `_history = []` before `_build_scene()`. `reset_board()`: add `_history = []` before `moves = 0`.

```gdscript
func capabilities() -> Array[String]:
	return ["undo", "hint", "check", "lines"]

func can_undo() -> bool:
	return not is_done() and not _history.is_empty()

## Reverts the last tap: the prism rolls one third away from the player, the
## only unwinding roll in the game (HUD spec, section 3). Counts no move; no
## state in the history was solved, or the game would have ended there.
func undo() -> bool:
	if is_done() or _history.is_empty():
		return false
	var last: Vector3i = _history.pop_back()
	var r := last.x
	var c := last.y
	_settle(r, c)
	_grid[r][c] = last.z
	_turns[r][c] -= 1
	_roll(r, c, -1)
	fx.cue("undo")
	_focus(r, c)
	_bob_neighbours(r, c)
	_recolour()
	moved.emit()
	return true

## The focused row and column for the working-line card, or {} without a focus.
func line_state() -> Dictionary:
	if focus_cell.x < 0:
		return {}
	var r := focus_cell.y
	var c := focus_cell.x
	var col := []
	for i in n:
		col.append(_grid[i][c])
	return {"row": {"index": r, "cells": (_grid[r] as Array).duplicate()}, "col": {"index": c, "cells": col}}
```

`_show_faces`: `var up: int = posmod(_turns[r][c], 3)`.

`_roll`: the time line becomes `var time := ROLL_TIME if absi(thirds) == 1 else ROLL_TIME_TWO` and the connect becomes `tw.finished.connect(_on_roll_landed.bind(r, c, thirds < 0))`. Update its doc comment: "a negative `thirds` rolls away from the player (undo)".

`_on_roll_landed(r: int, c: int, away := false)`: the puff sits at `pivot.position.z + Placeholders.TILE_SIDE * (-0.5 if away else 0.5)`; doc comment: "dust rises from the edge the arriving face touched down on: the near edge for a forward roll, the far edge for an undo".

`on_board_press`: before `_grid[r][c] = ...`, add `_history.append(Vector3i(r, c, v))`.

`_focus`: add `focus_changed.emit()` as the last line (after `fx.cue("focus")`). `_focus_clear`: add `focus_changed.emit()` as the last line.

- [ ] **Step 5: Run; passes**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|SCRIPT ERROR|passed"`
Expected: only `passed=N failed=0`.

- [ ] **Step 6: Commit**

```bash
git add core/puzzle_base.gd puzzles/binairo3d.gd tests/test_binairo3d.gd
git commit -m "feat: puzzle capabilities; binairo history, undo, focus signal and line state"
```

---

### Task 7: Binairo hint and check; reset unlocks hinted cells

**Files:**
- Modify: `puzzles/binairo3d.gd`
- Modify: `tests/test_binairo3d.gd`

**Interfaces:**
- Consumes: `Motion.wobble(node, angle, time)`, `Motion.fade(node, setter, from, to, time, steps)`, `Fx.sparkle(at, colour)`, `PuzzleBase.check_solved()`, `hints_used`, `checks`.
- Produces: `hints_left()`, `hint()`, `check()`, `_hinted: Array`, `_wobbles: Array`, `HINTS`, `CHECK_BLEND`, `_hint_cell() -> Vector2i` (col, row), `_flash(r, c)`.

- [ ] **Step 1: Write the failing tests**

In `run_in_tree`, after `_test_line_state(t, p)` and still before `_test_reset_wave(t, p)`:

```gdscript
	_test_hint(t, p)
	_test_check(t, p)
```

Append:

```gdscript
## Hint (HUD spec, section 3): corrects a wrong cell first, else fills the
## most constrained empty cell from the solution; the cell locks with the
## given tint and sparkles; three per puzzle; reset unlocks but does not refund.
static func _test_hint(t, p) -> void:
	t.check(p.capabilities().has("hint"), "binairo supports hint")
	p.hints_used = 0
	t.eq(p.hints_left(), 3, "three hints per puzzle")
	var a := _find_cell(p, false)
	var r := a.y
	var c := a.x
	# Make one free cell wrong on purpose and leave a history entry on it.
	p._settle(r, c)
	var wrong_value: int = 1 - p._solution[r][c]
	p._grid[r][c] = wrong_value
	p._turns[r][c] = p.FACE[wrong_value]
	p._settle(r, c)
	p._history = [Vector3i(r, c, -1)]
	t.check(p._hint_cell() == Vector2i(c, r), "a wrong cell is the hint's first choice")
	t.check(p.hint(), "hint fills a cell")
	t.eq(p._grid[r][c], p._solution[r][c], "the wrong cell is corrected")
	t.check(p._given[r][c] and p._hinted[r][c], "the hinted cell locks")
	t.check(p._history.is_empty(), "history entries on the hinted cell are dropped")
	t.eq(p.hints_left(), 2, "one hint used")
	t.check(p.focus_cell == Vector2i(c, r), "the hint takes the focus")
	t.eq(p.fx.last_cue, "hint", "the hint names its cue")
	t.check(Motion.running(p._rolls[r][c]), "the hinted cell rolls")
	p._rolls[r][c].custom_step(1.0)
	t.check(is_equal_approx(p._cells[r][c].rotation.x, p._target_angle(r, c)), "and lands on the solution face")
	var want_cap: Color = Pal.STONE_GIVEN.lerp(Pal.BAD, p._blend[r][c])
	t.check(_face_colour(p, r, c, "Cap").is_equal_approx(want_cap), "the hinted cell takes the given tint")
	# With no wrong cell, the hint picks the empty cell with the most filled neighbours in its lines.
	var pick := p._hint_cell()
	t.check(pick.x >= 0 and p._grid[pick.y][pick.x] == -1, "with nothing wrong the pick is an empty cell")
	var best := -1
	for rr in p.n:
		for cc in p.n:
			if p._grid[rr][cc] != -1:
				continue
			var score := 0
			for j in p.n:
				if p._grid[rr][j] != -1:
					score += 1
				if p._grid[j][cc] != -1:
					score += 1
			best = maxi(best, score)
	var pick_score := 0
	for j in p.n:
		if p._grid[pick.y][j] != -1:
			pick_score += 1
		if p._grid[j][pick.x] != -1:
			pick_score += 1
	t.eq(pick_score, best, "the pick has the most filled cells in its row and column")
	t.check(p.hint() and p.hint(), "two more hints fill")
	t.eq(p.hints_left(), 0, "all three used")
	t.check(not p.hint(), "no fourth hint")
	# A tap on a hinted cell only focuses and dips it.
	var v_before: int = p._grid[r][c]
	_tap(p, r, c)
	t.eq(p._grid[r][c], v_before, "a tap on a hinted cell rolls nothing")
	# Reset unlocks the hinted cells, empties them, keeps the count.
	p.reset_board()
	t.check(not p._given[r][c] and not p._hinted[r][c], "reset unlocks the hinted cell")
	t.eq(p._grid[r][c], -1, "reset empties it")
	t.eq(p.hints_left(), 0, "reset does not give hints back")
	for rr in p.n:
		for cc in p.n:
			p._settle(rr, cc)
	p._recolour()
	p.hints_used = 0
	p._focus_clear()

## Check (HUD spec, section 3): counts the filled free cells that differ from
## the solution, wobbles and flashes them, and counts the press.
static func _test_check(t, p) -> void:
	t.check(p.capabilities().has("check"), "binairo supports check")
	p.checks = 0
	for rr in p.n:
		for cc in p.n:
			p._settle(rr, cc)
	t.eq(p.check(), 0, "an all-empty board has nothing wrong")
	t.eq(p.checks, 1, "the press is counted")
	t.eq(p.fx.last_cue, "check_ok", "a clean check names check_ok")
	var a := _find_cell(p, false)
	var r := a.y
	var c := a.x
	var wrong_value: int = 1 - p._solution[r][c]
	p._grid[r][c] = wrong_value
	p._turns[r][c] = p.FACE[wrong_value]
	p._settle(r, c)
	p._recolour()
	t.eq(p.check(), 1, "one wrong cell is counted")
	t.eq(p.fx.last_cue, "check", "a failed check names check")
	t.check(Motion.running(p._wobbles[r][c]), "the wrong cell wobbles")
	t.check(Motion.running(p._fades[r][c]), "the wrong cell flashes")
	var target: float = p._blend_target[r][c]
	p._fades[r][c].custom_step(p.CHECK_IN + 0.01)
	t.check(p._blend[r][c] >= p.CHECK_BLEND - 0.001, "the flash reaches CHECK_BLEND (%.3f)" % p._blend[r][c])
	p._fades[r][c].custom_step(p.CHECK_OUT + 0.01)
	t.check(is_equal_approx(p._blend[r][c], target), "the flash comes back to the line's blend")
	p._wobbles[r][c].custom_step(1.0)
	t.check(is_zero_approx(p._cells[r][c].rotation.z), "the wobble ends upright")
	# A tap mid-wobble settles it upright.
	p.check()
	p._settle(r, c)
	t.check(is_zero_approx(p._cells[r][c].rotation.z) and p._wobbles[r][c] == null, "_settle stops the wobble and snaps upright")
	p._grid[r][c] = -1
	p._turns[r][c] = 0
	p._settle(r, c)
	p._recolour()
	p.checks = 0
	p._focus_clear()
```

- [ ] **Step 2: Run; errors on `_hint_cell`**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "binairo3d|SCRIPT ERROR|Invalid|passed" | head`
Expected: an error naming `_hint_cell` or `hints_left` returning 0.

- [ ] **Step 3: Implement in `puzzles/binairo3d.gd`**

Constants, after `SOLVE_STAGGER`:

```gdscript
## Hint and check (HUD spec, section 3).
const HINTS := 3
const CHECK_BLEND := 0.5     # 8/16: the flash a wrong cell gives on Check
const CHECK_IN := 0.15
const CHECK_OUT := 0.45
const SPARKLE_LIFT := 0.1
```

Fields, after `_blend_target`:

```gdscript
var _hinted: Array = []        # [r][c] -> filled by a hint, so locked like a given
var _wobbles: Array = []       # [r][c] -> the Check shake in flight
```

`_build_scene`: reset both to `[]` with the other arrays; in the per-row loop create `hinted_row` (append `false`) and `wobble_row` (append `null`) and append them to `_hinted` / `_wobbles`. `_stop_all`: add `_wobbles` to the `for rows in [...]` list.

`_settle`: add `Motion.stop(_wobbles[r][c])`, `_wobbles[r][c] = null` and `pivot.rotation.z = 0.0`.

`reset_board`, inside the cell loop right after `_settle(r, c)` and before the `if _given[r][c]:` branch:

```gdscript
			if _hinted[r][c]:
				# A hint is not a clue: reset gives the cell back to the player.
				_hinted[r][c] = false
				_given[r][c] = false
				_paint(_blend[r][c], r, c)
```

New functions, after `undo()`:

```gdscript
func hints_left() -> int:
	return HINTS - hints_used

## Fills one cell from the solution with a sparkle and locks it (HUD spec,
## section 3): a wrong filled cell first, else the empty cell with the most
## filled cells in its row and column. Three per puzzle; reset does not
## refund them. Counts no move but can finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var cell := _hint_cell()
	if cell.x < 0:
		return false
	var r := cell.y
	var c := cell.x
	_settle(r, c)
	var kept: Array[Vector3i] = []
	for h in _history:
		if h.x != r or h.y != c:
			kept.append(h)
	_history = kept
	var old: int = _grid[r][c]
	var target: int = _solution[r][c]
	_grid[r][c] = target
	var thirds: int = posmod(FACE[target] - FACE[old], 3)
	_turns[r][c] += thirds
	_roll(r, c, thirds)
	_given[r][c] = true
	_hinted[r][c] = true
	_paint(_blend[r][c], r, c)
	fx.sparkle(BoardMath.cell_center(r, c, n, n, Placeholders.TILE_RISE + SPARKLE_LIFT))
	fx.cue("hint")
	hints_used += 1
	_focus(r, c)
	_recolour()
	moved.emit()
	check_solved()
	return true

## The cell a hint fills, as (col, row); (-1, -1) when nothing qualifies.
func _hint_cell() -> Vector2i:
	for r in n:
		for c in n:
			if not _given[r][c] and _grid[r][c] != -1 and _grid[r][c] != _solution[r][c]:
				return Vector2i(c, r)
	var best := Vector2i(-1, -1)
	var best_score := -1
	for r in n:
		for c in n:
			if _grid[r][c] != -1:
				continue
			var score := 0
			for j in n:
				if _grid[r][j] != -1:
					score += 1
				if _grid[j][c] != -1:
					score += 1
			if score > best_score:
				best_score = score
				best = Vector2i(c, r)
	return best

## Marks every filled free cell that differs from the solution with a wobble
## and a flash (HUD spec, section 3). Returns how many; the press is counted
## in `checks`. Solving stays automatic; this only points.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong := 0
	for r in n:
		for c in n:
			if _given[r][c] or _grid[r][c] == -1 or _grid[r][c] == _solution[r][c]:
				continue
			wrong += 1
			Motion.stop(_wobbles[r][c])
			_cells[r][c].rotation.z = 0.0
			_wobbles[r][c] = Motion.wobble(_cells[r][c])
			_flash(r, c)
	fx.cue("check" if wrong > 0 else "check_ok")
	return wrong

## A quick blush to CHECK_BLEND and back to whatever blend the cell's line
## is heading for. Replaces the cell's running fade; _blend_target is not
## touched, so a later _recolour does not restart it.
func _flash(r: int, c: int) -> void:
	Motion.stop(_fades[r][c])
	var setter := _paint.bind(r, c)
	var back: float = _blend_target[r][c]
	var tw: Tween = Motion.fade(_tiles[r][c], setter, _blend[r][c], CHECK_BLEND, CHECK_IN, BLUSH_STEPS)
	if tw == null:
		setter.call(back)
		_fades[r][c] = null
		return
	tw.tween_method(setter, CHECK_BLEND, back, CHECK_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fades[r][c] = tw
```

Also rewrite `rules()` as three sentences (the rules card splits on them):

```gdscript
func rules() -> String:
	return "Fill every cell with a sun or a moon. Never three alike in a line. Every line has an equal count of each, and no two lines are identical."
```

- [ ] **Step 4: Run; passes**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|SCRIPT ERROR|passed"`
Expected: only `passed=N failed=0`. If `_test_check`'s "flash comes back" check fails by a quantisation step, compare with `absf(p._blend[r][c] - target) <= 1.0 / p.BLUSH_STEPS + 0.001` and note it in the commit.

- [ ] **Step 5: Commit**

```bash
git add puzzles/binairo3d.gd tests/test_binairo3d.gd
git commit -m "feat: binairo hint and check; reset unlocks hinted cells"
```

---

### Task 8: Panel base and IconButton

**Files:**
- Create: `ui/hud/panel.gd`, `ui/hud/icon_button.gd`

**Interfaces:**
- Consumes: `CozyTheme` variations, `Icons.paint`, `Motion.slide`, `Motion.appear`, `Motion.squash`, `Motion.stop`.
- Produces: `HudPanel` (`ui/hud/panel.gd`): `var enter_from: Vector2`, `var _inner: Container`, `var _entrance: Array[Tween]`, `func _make_inner() -> Container` (override), `func _build() -> void` (override), `func refresh(_puzzle) -> void` (override), `func enter(delay: float) -> void`. `IconButton` (`ui/hud/icon_button.gd`, extends `Button`): `_init(icon := "", label := "", variation := "IconButton")`, `var badge: int` (setter), `func set_enabled(on: bool)`, `func set_label(text: String)`, `func squish()`, `func badge_node() -> Control`, `var badge_rest: Vector2`, `var _press_tw: Tween`.

- [ ] **Step 1: Create `ui/hud/panel.gd`**

```gdscript
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
```

- [ ] **Step 2: Create `ui/hud/icon_button.gd`**

```gdscript
extends Button

## The HUD's one button: a vector icon from ui/icons.gd, an optional label to
## its right, an optional count badge at the top-right corner, and a squish on
## press. The look comes from the theme variation: IconButton (paper),
## PrimaryButton (sun) or DarkButton (slate).
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

const Icons = preload("res://ui/icons.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

const GLYPH := 44.0
const BADGE_R := 22.0
const SQUASH := 0.10
const SQUASH_TIME := 0.18

var icon_name := ""
var label_text := ""
## Count shown in the badge; 0 hides it.
var badge: int = 0:
	set(v):
		badge = v
		_refresh_badge()
## Where the badge rests; the top bar's bounce hops from here.
var badge_rest := Vector2.ZERO
var _press_tw: Tween
var _row: HBoxContainer
var _glyph: Control
var _label: Label
var _badge: Control
var _badge_label: Label

func _init(icon := "", label := "", variation := "IconButton") -> void:
	icon_name = icon
	label_text = label
	theme_type_variation = variation
	text = ""
	focus_mode = Control.FOCUS_NONE

func _ready() -> void:
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 14)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_row)
	_glyph = Control.new()
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.custom_minimum_size = Vector2(GLYPH, GLYPH)
	_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_glyph.draw.connect(_draw_glyph)
	_row.add_child(_glyph)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = label_text
	_label.visible = label_text != ""
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row.add_child(_label)
	_badge = Control.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.size = Vector2(BADGE_R * 2.0, BADGE_R * 2.0)
	_badge.draw.connect(_draw_badge)
	add_child(_badge)
	_badge_label = Label.new()
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_label.theme_type_variation = "Badge"
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_badge.add_child(_badge_label)
	button_down.connect(squish)
	resized.connect(_layout)
	_apply_look()
	_refresh_badge()
	_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _label != null:
		_apply_look()

## Enable or disable, dimming the icon and label with the theme's disabled colour.
func set_enabled(on: bool) -> void:
	disabled = not on
	_apply_look()

func set_label(text_: String) -> void:
	label_text = text_
	if _label != null:
		_label.text = text_
		_label.visible = text_ != ""

## The press squish: flatter and wider, then springs back. Restarts cleanly
## when mashed.
func squish() -> void:
	Motion.stop(_press_tw)
	scale = Vector2.ONE
	_press_tw = Motion.squash(self, SQUASH, SQUASH_TIME)

func badge_node() -> Control:
	return _badge

func _apply_look() -> void:
	if _label == null:
		return
	var colour := _ink()
	_label.add_theme_font_override("font", get_theme_font("font"))
	_label.add_theme_font_size_override("font_size", get_theme_font_size("font_size"))
	_label.add_theme_color_override("font_color", colour)
	_glyph.queue_redraw()

func _ink() -> Color:
	return get_theme_color("font_disabled_color") if disabled else get_theme_color("font_color")

func _layout() -> void:
	pivot_offset = size * 0.5
	badge_rest = Vector2(size.x - BADGE_R * 1.4, -BADGE_R * 0.6)
	if _badge != null:
		_badge.position = badge_rest

func _refresh_badge() -> void:
	if _badge == null:
		return
	_badge.visible = badge > 0
	_badge_label.text = str(badge)
	_badge.queue_redraw()

func _draw_glyph() -> void:
	var fill: Color = get_theme_stylebox("normal").bg_color if get_theme_stylebox("normal") is StyleBoxFlat else Color.TRANSPARENT
	Icons.paint(_glyph, icon_name, Rect2(Vector2.ZERO, _glyph.size), _ink(), fill)

func _draw_badge() -> void:
	_badge.draw_circle(Vector2(BADGE_R, BADGE_R), BADGE_R, Pal.WATER)
```

- [ ] **Step 3: Smoke it in a throwaway scene script and run the suite**

Run: `godot --headless --path . --import` then `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -2` — expected `failed=0`. Then a quick visual: write `/tmp/hud_smoke.gd`:

```gdscript
extends SceneTree
func _initialize() -> void:
	var theme = load("res://ui/theme.gd").make()
	var rootc := Control.new()
	rootc.theme = theme
	rootc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(rootc)
	var IB = load("res://ui/hud/icon_button.gd")
	var names := ["chevron_left", "undo", "bulb", "gear", "reset", "check", "leaf", "island"]
	for i in names.size():
		var b = IB.new(names[i], "" if i < 4 else names[i].capitalize(), "IconButton" if i < 4 else ("PrimaryButton" if i == 5 else "DarkButton"))
		b.position = Vector2(40 + (i % 4) * 250, 100 + (i / 4) * 200)
		b.size = Vector2(110, 110) if i < 4 else Vector2(230, 130)
		if i == 2:
			b.badge = 3
		rootc.add_child(b)
var _f := 0
func _process(_d: float) -> bool:
	_f += 1
	if _f == 10:
		root.get_texture().get_image().save_png("/tmp/hud_smoke.png")
		return true
	return false
```

Run: `cp /tmp/hud_smoke.gd tests/_hud_smoke.gd && godot --path . --resolution 1080x1920 --script res://tests/_hud_smoke.gd; rm tests/_hud_smoke.gd tests/_hud_smoke.gd.uid; git checkout project.godot`, then look at `/tmp/hud_smoke.png`: eight buttons, icons legible in dark ink on paper, the bulb with a blue badge reading 3, sun and slate labelled buttons with icon left of text. Fix geometry until it reads.

- [ ] **Step 4: Commit**

```bash
git add ui/hud/panel.gd ui/hud/panel.gd.uid ui/hud/icon_button.gd ui/hud/icon_button.gd.uid
git commit -m "feat: HUD panel base and icon button with badge and squish"
```

---

### Task 9: Top bar, day card, rules card

**Files:**
- Create: `ui/hud/top_bar.gd`, `ui/hud/day_card.gd`, `ui/hud/rules_card.gd`

**Interfaces:**
- Consumes: `HudPanel`, `IconButton`, `Icons.paint`, `CozyTheme.slate_card()`, `CozyTheme.parchment_card()`, `Motion.hop`, puzzle `capabilities()`, `can_undo()`, `hints_left()`, `is_done()`, `rules()`.
- Produces: `TopBar(title := "", motto := "")` with signals `back`, `undo`, `hint`, `settings` and fields `back_button`, `undo_button`, `hint_button`, `settings_button`; `DayCard.set_day(n: int, island: String)`; `RulesCard.set_rules(text: String)`, `static RulesCard.split_sentences(text: String) -> Array[String]`.

- [ ] **Step 1: Create `ui/hud/top_bar.gd`**

```gdscript
extends "res://ui/hud/panel.gd"

## The HUD's top row: back, the wordmark (title in the display face with a
## leaf, the motto beneath), then undo, hint with its bouncing count badge,
## and settings. Emits one signal per button; the host decides what they do.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

signal back
signal undo
signal hint
signal settings

const IconButton = preload("res://ui/hud/icon_button.gd")
const Icons = preload("res://ui/icons.gd")

const BUTTON := Vector2(110, 110)
const LEAF := 36.0
const BADGE_HOP := -6.0
const BADGE_HOP_TIME := 0.3
const BADGE_CYCLE := 2.4

var title_text := ""
var motto_text := ""
var back_button: Button
var undo_button: Button
var hint_button: Button
var settings_button: Button
var _title: Label
var _motto: Label
var _bounce: Tween

func _init(title := "", motto := "") -> void:
	title_text = title
	motto_text = motto
	enter_from = Vector2(0, -80)

func _make_inner() -> Container:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	return row

func _build() -> void:
	back_button = _button("chevron_left", back)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	_inner.add_child(words)
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 4)
	words.add_child(title_row)
	_title = Label.new()
	_title.theme_type_variation = "Wordmark"
	_title.text = title_text.to_upper()
	title_row.add_child(_title)
	var leaf := Control.new()
	leaf.custom_minimum_size = Vector2(LEAF, LEAF)
	leaf.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	leaf.draw.connect(func() -> void: Icons.paint(leaf, "leaf", Rect2(Vector2.ZERO, leaf.size), Pal.MOSS))
	title_row.add_child(leaf)
	_motto = Label.new()
	_motto.theme_type_variation = "Motto"
	_motto.text = motto_text.to_upper()
	_motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_motto.visible = motto_text != ""
	words.add_child(_motto)
	undo_button = _button("undo", undo)
	hint_button = _button("bulb", hint)
	settings_button = _button("gear", settings)

func _button(icon: String, sig: Signal) -> Button:
	var b := IconButton.new(icon)
	b.custom_minimum_size = BUTTON
	b.pressed.connect(func() -> void: sig.emit())
	_inner.add_child(b)
	return b

func refresh(puzzle) -> void:
	var caps: Array = puzzle.capabilities() if puzzle != null else []
	var done: bool = puzzle != null and puzzle.is_done()
	undo_button.visible = caps.has("undo")
	hint_button.visible = caps.has("hint")
	undo_button.set_enabled(puzzle != null and puzzle.can_undo() and not done)
	var left: int = puzzle.hints_left() if puzzle != null else 0
	hint_button.set_enabled(left > 0 and not done)
	hint_button.badge = left
	_set_bounce(hint_button.visible and left > 0 and not done)

## The badge hops every BADGE_CYCLE seconds while hints remain. Under
## reduce-motion hop returns null and the badge stays still.
func _set_bounce(on: bool) -> void:
	if not on:
		Motion.stop(_bounce)
		_bounce = null
		return
	if Motion.running(_bounce):
		return
	var badge: Control = hint_button.badge_node()
	_bounce = hint_button.create_tween().set_loops()
	_bounce.tween_callback(func() -> void: Motion.hop(badge, BADGE_HOP, BADGE_HOP_TIME, 0.0, hint_button.badge_rest.y))
	_bounce.tween_interval(BADGE_CYCLE)
```

- [ ] **Step 2: Create `ui/hud/day_card.gd`**

```gdscript
extends "res://ui/hud/panel.gd"

## The slate day card: an island icon, "Day N" and the island's name. The host
## sets both from core/progress.gd on every spawn.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 2.

const Icons = preload("res://ui/icons.gd")

const MIN_WIDTH := 420.0
const ICON := 64.0

var _day: Label
var _island: Label

func _init() -> void:
	enter_from = Vector2(-120, 0)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _build() -> void:
	(_inner as PanelContainer).add_theme_stylebox_override("panel", CozyTheme.slate_card())
	_inner.custom_minimum_size.x = MIN_WIDTH
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_inner.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.draw.connect(func() -> void: Icons.paint(icon, "island", Rect2(Vector2.ZERO, icon.size), Pal.MOSS))
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	_day = Label.new()
	_day.theme_type_variation = "OnSlateTitle"
	col.add_child(_day)
	_island = Label.new()
	_island.theme_type_variation = "OnSlateBody"
	col.add_child(_island)
	set_day(1, "")

func set_day(n: int, island: String) -> void:
	_day.text = "Day %d" % n
	_island.text = island
	_island.visible = island != ""
```

- [ ] **Step 3: Create `ui/hud/rules_card.gd`**

```gdscript
extends "res://ui/hud/panel.gd"

## The parchment rules card: a RULES heading and one bullet per sentence of
## the puzzle's rules().
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 2.

const WIDTH := 520.0

var _list: VBoxContainer

func _init() -> void:
	enter_from = Vector2(120, 0)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _build() -> void:
	(_inner as PanelContainer).add_theme_stylebox_override("panel", CozyTheme.parchment_card())
	_inner.custom_minimum_size.x = WIDTH
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_inner.add_child(col)
	var heading := Label.new()
	heading.theme_type_variation = "CardTitle"
	heading.text = "RULES"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(heading)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	col.add_child(_list)

func refresh(puzzle) -> void:
	set_rules(puzzle.rules() if puzzle != null else "")

func set_rules(text: String) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()
	for sentence in split_sentences(text):
		var l := Label.new()
		l.theme_type_variation = "CardBody"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = "•  " + sentence
		_list.add_child(l)

## "One. Two three." -> ["One", "Two three"].
static func split_sentences(text: String) -> Array[String]:
	var out: Array[String] = []
	for part in text.split(". ", false):
		var s := part.strip_edges().trim_suffix(".")
		if s != "":
			out.append(s)
	return out
```

- [ ] **Step 4: Import, run the suite, commit**

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -2
git add ui/hud/top_bar.gd ui/hud/top_bar.gd.uid ui/hud/day_card.gd ui/hud/day_card.gd.uid ui/hud/rules_card.gd ui/hud/rules_card.gd.uid
git commit -m "feat: HUD top bar, day card and rules card"
```

---

### Task 10: Line card and action bar

**Files:**
- Create: `ui/hud/line_card.gd`, `ui/hud/action_bar.gd`

**Interfaces:**
- Consumes: `HudPanel`, `IconButton`, `CozyTheme.slate_card()`, puzzle `line_state()`, `capabilities()`, `is_done()`.
- Produces: `LineCard` (extends `PanelContainer`): `var lines: Array[Dictionary]` (two entries with `label: Label`, `dots: Control`, `count: Label`, `cells: Array`), `refresh(puzzle)`, `show_idle()`. `ActionBar` with signals `reset`, `check`, fields `line_card`, `reset_button`, `check_button`, and `all_good()`.

- [ ] **Step 1: Create `ui/hud/line_card.gd`**

```gdscript
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
```

- [ ] **Step 2: Create `ui/hud/action_bar.gd`**

```gdscript
extends "res://ui/hud/panel.gd"

## The bottom row: the working-line card, Reset in slate and Check in sun.
## Whatever the puzzle does not support is hidden and the rest takes its space.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

signal reset
signal check

const IconButton = preload("res://ui/hud/icon_button.gd")
const LineCard = preload("res://ui/hud/line_card.gd")

const BUTTON := Vector2(260, 130)
const ALL_GOOD_TIME := 1.2

var line_card: PanelContainer
var reset_button: Button
var check_button: Button
var _all_good: Tween

func _init() -> void:
	enter_from = Vector2(0, 100)

func _make_inner() -> Container:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	return row

func _build() -> void:
	line_card = LineCard.new()
	_inner.add_child(line_card)
	reset_button = IconButton.new("reset", "Reset", "DarkButton")
	reset_button.custom_minimum_size = BUTTON
	reset_button.pressed.connect(func() -> void: reset.emit())
	_inner.add_child(reset_button)
	check_button = IconButton.new("check", "Check", "PrimaryButton")
	check_button.custom_minimum_size = BUTTON
	check_button.pressed.connect(func() -> void: check.emit())
	_inner.add_child(check_button)

func refresh(puzzle) -> void:
	var caps: Array = puzzle.capabilities() if puzzle != null else []
	var done: bool = puzzle != null and puzzle.is_done()
	line_card.visible = caps.has("lines")
	check_button.visible = caps.has("check")
	check_button.set_enabled(not done)
	line_card.refresh(puzzle)

## A clean check: the button says so for a moment and squashes.
func all_good() -> void:
	Motion.stop(_all_good)
	check_button.set_label("All good")
	check_button.squish()
	_all_good = check_button.create_tween()
	_all_good.tween_interval(ALL_GOOD_TIME)
	_all_good.tween_callback(func() -> void: check_button.set_label("Check"))
```

- [ ] **Step 3: Import, run the suite, commit**

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -2
git add ui/hud/line_card.gd ui/hud/line_card.gd.uid ui/hud/action_bar.gd ui/hud/action_bar.gd.uid
git commit -m "feat: HUD working-line card and action bar"
```

---

### Task 11: Settings sheet

**Files:**
- Create: `ui/hud/settings_sheet.gd`

**Interfaces:**
- Consumes: `IconButton`, `CozyTheme.paper_card()`, `Motion.slide`, `Motion.appear`, `Motion.reduce`.
- Produces: `SettingsSheet` (extends `Control`) with signals `reduce_changed(on: bool)`, `new_puzzle`, `closed`; fields `toggle: CheckButton`, `new_button`, `close_button`; `open()`, `close()`.

- [ ] **Step 1: Create `ui/hud/settings_sheet.gd`**

```gdscript
extends Control

## A modal bottom sheet: a scrim and a paper card that slides up with the
## Reduce motion toggle, a New puzzle row (a prototype affordance) and Close.
## Hidden until open(); tapping the scrim closes it.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

signal reduce_changed(on: bool)
signal new_puzzle
signal closed

const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Pal = preload("res://core/palette.gd")

const SLIDE := 0.3
const FADE := 0.2
const OFFSET := 300.0
const MARGIN := 40.0
const ROW := 110.0

var toggle: CheckButton
var new_button: Button
var close_button: Button
var _scrim: ColorRect
var _card: PanelContainer
var _tw: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_scrim = ColorRect.new()
	_scrim.color = Color(Pal.OUTLINE, 0.35)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch and ev.pressed:
			close())
	add_child(_scrim)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", CozyTheme.paper_card())
	_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.offset_left = MARGIN
	_card.offset_right = -MARGIN
	_card.offset_bottom = -MARGIN
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	_card.add_child(col)
	var title := Label.new()
	title.theme_type_variation = "CardTitle"
	title.text = "Settings"
	col.add_child(title)
	toggle = CheckButton.new()
	toggle.text = "Reduce motion"
	toggle.custom_minimum_size.y = ROW * 0.8
	toggle.set_pressed_no_signal(Motion.reduce)
	toggle.toggled.connect(func(on: bool) -> void: reduce_changed.emit(on))
	col.add_child(toggle)
	new_button = IconButton.new("reset", "New puzzle (prototype)", "IconButton")
	new_button.custom_minimum_size.y = ROW
	new_button.pressed.connect(func() -> void:
		new_puzzle.emit()
		close())
	col.add_child(new_button)
	close_button = IconButton.new("check", "Close", "PrimaryButton")
	close_button.custom_minimum_size.y = ROW
	close_button.pressed.connect(close)
	col.add_child(close_button)

## The card's resting y: anchored to the bottom above the margin.
func _rest_y() -> float:
	return size.y - MARGIN - _card.size.y

func open() -> void:
	visible = true
	toggle.set_pressed_no_signal(Motion.reduce)
	Motion.stop(_tw)
	var rest := _rest_y()
	_tw = Motion.slide(_card, "position:y", rest + OFFSET, rest, SLIDE)
	Motion.appear(_scrim, 0.0, 1.0, FADE)

func close() -> void:
	if not visible:
		return
	Motion.stop(_tw)
	var rest := _rest_y()
	var slide: Tween = Motion.slide(_card, "position:y", rest, rest + OFFSET, SLIDE, 0.0, false)
	Motion.appear(_scrim, 1.0, 0.0, FADE)
	if slide == null:
		visible = false
		closed.emit()
		return
	_tw = slide
	slide.finished.connect(func() -> void:
		visible = false
		closed.emit())
```

- [ ] **Step 2: Import, run the suite, commit**

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -2
git add ui/hud/settings_sheet.gd ui/hud/settings_sheet.gd.uid
git commit -m "feat: settings sheet with the reduce-motion toggle"
```

---

### Task 12: The host rebuilt on the panels

**Files:**
- Modify: `ui/puzzle_host.gd` (full rewrite), `ui/registry.gd`

**Interfaces:**
- Consumes: every panel from Tasks 8 to 11, `Progress.touch()`, `Progress.day()`, `Progress.island_name()`, `Motion.reduce`, `Motion.save_settings()`, `Motion.appear`, the stage in group `"stage"` with an `ambient` field that has `refresh()`.
- Produces (kept for the harnesses): `setup(entry, difficulty)`, `signal closed`, `_puzzle`, `_overlay`, `_on_new()`, `_on_reset()`. New fields: `top_bar`, `day_card`, `rules_card`, `action_bar`, `settings_sheet`, `footer`.

- [ ] **Step 1: Registry text**

In `ui/registry.gd`, the binairo entry gains two keys after `"blurb"`:

```gdscript
		"motto": "Balance brings harmony",
		"footer": "Think · Balance · Complete",
```

- [ ] **Step 2: Rewrite `ui/puzzle_host.gd`**

```gdscript
extends Control

## Shell around any PuzzleBase: the concept HUD (top bar, day card, rules
## card, board slot, action bar, motto footer), the solved overlay and the
## settings sheet. Puzzles never draw chrome themselves, so they stay
## comparable; the host asks each puzzle what it supports
## (PuzzleBase.capabilities) and the panels hide the rest.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md.

signal closed

const Pal = preload("res://core/palette.gd")
const DailySeed = preload("res://core/daily.gd")
const Progress = preload("res://core/progress.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const TopBar = preload("res://ui/hud/top_bar.gd")
const DayCard = preload("res://ui/hud/day_card.gd")
const RulesCard = preload("res://ui/hud/rules_card.gd")
const ActionBar = preload("res://ui/hud/action_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")

const MARGIN := 40
const GAP := 20
## Entrance delays per panel (spec section 5).
const ENTER_TOP := 0.0
const ENTER_CARDS := 0.1
const ENTER_ACTIONS := 0.2
const ENTER_FOOTER := 0.3
const ENTER_FOOTER_FADE := 0.25

var _puzzle: Control
var _entry: Dictionary
var _difficulty: int = 0

var top_bar: Control
var day_card: Control
var rules_card: Control
var action_bar: Control
var settings_sheet: Control
var footer: Label
var _board_holder: Control
var _card: Panel
var _overlay: Control
var _overlay_label: Label

func setup(entry: Dictionary, difficulty: int) -> void:
	_entry = entry
	_difficulty = difficulty

func _ready() -> void:
	theme = CozyTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets := _safe_insets()
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", MARGIN)
	margins.add_theme_constant_override("margin_right", MARGIN)
	margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	add_child(margins)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", GAP)
	margins.add_child(root)

	# --- top bar ---
	top_bar = TopBar.new(_entry.get("title", ""), _entry.get("motto", ""))
	top_bar.name = "TopBar"
	top_bar.back.connect(func() -> void: closed.emit())
	top_bar.undo.connect(_on_undo)
	top_bar.hint.connect(_on_hint)
	top_bar.settings.connect(_open_settings)
	root.add_child(top_bar)

	# --- cards row ---
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", GAP)
	root.add_child(cards)
	day_card = DayCard.new()
	day_card.name = "DayCard"
	cards.add_child(day_card)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_child(spacer)
	rules_card = RulesCard.new()
	rules_card.name = "RulesCard"
	cards.add_child(rules_card)

	# --- board slot ---
	_board_holder = Control.new()
	_board_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_board_holder)
	_card = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.PAPER
	sb.set_corner_radius_all(32)
	_card.add_theme_stylebox_override("panel", sb)
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_holder.add_child(_card)

	# --- action bar and footer ---
	action_bar = ActionBar.new()
	action_bar.name = "ActionBar"
	action_bar.reset.connect(_on_reset)
	action_bar.check.connect(_on_check)
	root.add_child(action_bar)
	footer = Label.new()
	footer.theme_type_variation = "Motto"
	footer.text = String(_entry.get("footer", "")).to_upper()
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.visible = footer.text != ""
	root.add_child(footer)

	_build_overlay()
	settings_sheet = SettingsSheet.new()
	settings_sheet.name = "SettingsSheet"
	settings_sheet.reduce_changed.connect(_on_reduce_changed)
	settings_sheet.new_puzzle.connect(_on_new)
	add_child(settings_sheet)

	_spawn(DailySeed.seed_for(_entry.id, _difficulty))
	_enter()

## Safe-area insets (top, bottom) in viewport units. Only phones report one
## that matters; the desktop's value describes the screen, not the window.
func _safe_insets() -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var k := get_viewport_rect().size.y / float(win.y)
	return Vector2(maxf(0.0, float(safe.position.y)) * k, maxf(0.0, float(win.y - safe.end.y)) * k)

func _build_overlay() -> void:
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(Pal.PAPER, 0.85)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CozyTheme.paper_card())
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.custom_minimum_size.x = 640
	_overlay.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	var title := Label.new()
	title.theme_type_variation = "CardTitle"
	title.text = "Solved"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_overlay_label = Label.new()
	_overlay_label.theme_type_variation = "CardBody"
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_overlay_label)
	var tap := Button.new()
	tap.flat = true
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap.pressed.connect(func() -> void: _overlay.visible = false)
	_overlay.add_child(tap)

## The HUD arrives: top bar first, cards, then the action bar and the footer.
func _enter() -> void:
	top_bar.enter(ENTER_TOP)
	day_card.enter(ENTER_CARDS)
	rules_card.enter(ENTER_CARDS)
	action_bar.enter(ENTER_ACTIONS)
	Motion.appear(footer, 0.0, 1.0, ENTER_FOOTER_FADE, ENTER_FOOTER)

func _spawn(the_seed: int) -> void:
	if is_instance_valid(_puzzle):
		_puzzle.queue_free()
	var script: GDScript = load(_entry.script)
	_puzzle = script.new()
	_puzzle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_holder.add_child(_puzzle)
	_puzzle.solved.connect(_on_solved)
	_puzzle.moved.connect(_refresh)
	_puzzle.focus_changed.connect(_refresh)
	var rng := RandomNumberGenerator.new()
	rng.seed = the_seed
	_puzzle.start(rng, _difficulty)
	_card.visible = not _puzzle.is_3d()
	_overlay.visible = false
	Progress.touch()
	day_card.set_day(Progress.day(), Progress.island_name())
	_refresh()

## Every panel re-reads the puzzle.
func _refresh() -> void:
	var p = _puzzle if is_instance_valid(_puzzle) else null
	top_bar.refresh(p)
	rules_card.refresh(p)
	action_bar.refresh(p)

func _on_undo() -> void:
	if is_instance_valid(_puzzle):
		_puzzle.undo()
		_refresh()

func _on_hint() -> void:
	if is_instance_valid(_puzzle):
		_puzzle.hint()
		_refresh()

func _on_check() -> void:
	if is_instance_valid(_puzzle):
		var wrong: int = _puzzle.check()
		if wrong == 0:
			action_bar.all_good()
		_refresh()

func _on_reset() -> void:
	if is_instance_valid(_puzzle):
		_puzzle.reset_board()
		_overlay.visible = false
		_refresh()

func _on_new() -> void:
	# Prototype affordance only. The shipped game gets one puzzle per day.
	_spawn(randi())

func _open_settings() -> void:
	settings_sheet.open()

## The reduce-motion toggle: persist, still the world, refresh the chrome.
func _on_reduce_changed(on: bool) -> void:
	Motion.reduce = on
	Motion.save_settings()
	var stage: Node = get_tree().get_first_node_in_group("stage")
	if stage != null and stage.get("ambient") != null:
		stage.ambient.refresh()
	_refresh()

func _on_solved() -> void:
	_overlay_label.text = "%.1fs  ·  %d moves\n\n%s" % [
		_puzzle.elapsed, _puzzle.moves, _puzzle.share_glyphs()
	]
	_overlay.visible = true
	_refresh()
```

- [ ] **Step 3: Run the suite and the harnesses, look at the screen**

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -2        # failed=0
godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | tail -13    # winnable=10/10
godot --path . --resolution 1080x1920 --script res://tests/_shot.gd 2>&1 | tail -1
git checkout project.godot
```

Look at `/tmp/shot_binairo.png` with the image reader and compare with `docs/art/concept-binairo-hud.png`: wordmark BINAIRO with the leaf and the motto under it; back, undo, bulb with a blue 3, gear; slate day card with the island icon; parchment rules card with three bullets; the board framed in the slot without overlap; slate line card reading "Tap a tile" with hollow dots; dark Reset, sun Check; the footer motto. Look at `/tmp/shot_mastermind.png` too: the nine 2D boards must show only back, settings and Reset around their paper card. Fix layout until both read; the usual culprits are a panel with zero height (its `_inner` minimum size did not propagate: call `_update_min()` after `_build()` finishes adding children) and a Label without a width (give the card a `custom_minimum_size.x`).

- [ ] **Step 4: Commit**

```bash
git add ui/puzzle_host.gd ui/registry.gd
git commit -m "feat: puzzle host rebuilt on the HUD panels"
```

---

### Task 13: Harnesses and README

**Files:**
- Modify: `tests/_win.gd`, `tests/_shot.gd`, `README.md`

**Interfaces:**
- Consumes: `_host.top_bar.hint_button`, `_host.action_bar.check_button`, `_puzzle.hints_used`, `_puzzle.checks`.

- [ ] **Step 1: The win harness presses Hint and Check on Binairo**

In `tests/_win.gd`, add a field `var _hud_ok := true`, reset it to `true` at the `slot == 12` branch beside `_fit_ok = true`, include it in the result (`"ok": solved and done and overlay and _fit_ok and _hud_ok`), and add a helper:

```gdscript
## Presses a HUD button through a touch at its centre, like a player would.
func _press(btn: Button) -> void:
	_tap_global(btn.get_global_transform_with_canvas() * (btn.size * 0.5))
```

At the top of `_solve_binairo`, after the camera-fit loop and before the solving loop:

```gdscript
	# The HUD's own buttons: one hint (fills and locks a cell) and one check.
	_press(_host.top_bar.hint_button)
	_press(_host.action_bar.check_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1
```

And the binairo note becomes `"%d moves, hints=%d checks=%d, camera fit=%s" % [_puzzle.moves, _puzzle.hints_used, _puzzle.checks, _fit_ok]`.

- [ ] **Step 2: The shot harness goes time-based**

Rewrite `tests/_shot.gd`:

```gdscript
extends SceneTree

## Walks every registered prototype, screenshots it, and moves on. Keyed on
## elapsed seconds rather than frames, so the shot lands after the board's
## entrance at any frame rate.

const OPEN_AT := 0.1
const SHOT_AT := 2.0
const CLOSE_AT := 2.2

var _menu: Node
var _host: Node
var _t := 0.0
var _phase := 0  # 0 about to open, 1 open, 2 shot taken
var _idx := 0
var _entries: Array = []

func _initialize() -> void:
	_entries = load("res://ui/registry.gd").PUZZLES
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if _idx >= _entries.size():
		root.get_texture().get_image().save_png("/tmp/shot_menu.png")
		print("saved /tmp/shot_menu.png")
		return true
	if _phase == 0 and _t >= OPEN_AT:
		_menu._open(_entries[_idx])
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_phase = 1
	elif _phase == 1 and _t >= SHOT_AT:
		var path := "/tmp/shot_%s.png" % _entries[_idx].id
		root.get_texture().get_image().save_png(path)
		print("saved " + path)
		_phase = 2
	elif _phase == 2 and _t >= CLOSE_AT:
		_host.closed.emit()
		_idx += 1
		_phase = 0
		_t = 0.0
	return false
```

- [ ] **Step 3: README**

In `README.md`: under Running, add a line "The HUD around every board is the concept chrome: wordmark, back / undo / hint / settings, day card, rules card, working-line card, Reset and Check; Binairo has real undo, hint (three) and check." In Layout, `ui/` becomes `ui/         menu, puzzle host shell, registry, theme (fonts, cards, buttons), icons; ui/hud/ the HUD panels`, and `assets/` becomes `assets/     models/<slot>.glb from Blender, placeholders otherwise; fonts/ Fredoka and Nunito (OFL)`. Under Tests, note that the win harness also presses Binairo's Hint and Check. Add to the reduce-motion paragraph: "The settings sheet (gear button) toggles it in the game."

- [ ] **Step 4: Run both harnesses and commit**

```bash
godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | tail -13   # winnable=10/10, binairo note shows hints=1 checks=1
godot --path . --resolution 1080x1920 --script res://tests/_shot.gd 2>&1 | tail -3
git checkout project.godot
git add tests/_win.gd tests/_shot.gd README.md
git commit -m "test: win harness presses hint and check; shot harness keyed on time; README for the HUD"
```

---

### Task 14: Wind on mirrored pieces, performance numbers, spec amendments

**Files:**
- Modify: `shaders/toon_wind.gdshader`, `docs/superpowers/specs/2026-09-14-binairo-hud-design.md`

- [ ] **Step 1: The wind fix**

In `shaders/toon_wind.gdshader`, `vertex()`: after computing `ph`, add `float flip = sign(determinant(mat3(MODEL_MATRIX)));` and change the x line to `VERTEX.x += flip * sin(ph) * sway_amount * h * motion_scale;`. Comment above it: "A piece mirrored with scale.x = -1 (every other rim edge) would lean the other way in world space; flip undoes the mirror so neighbours lean together."

Run `godot --path . --resolution 1080x1920 --script res://tests/_shot_anim.gd 2>&1 | tail -3`, look at `/tmp/anim_binairo_4.png` and `_5.png`: along one rim side every tuft leans the same way in the same frame. `git checkout project.godot`.

- [ ] **Step 2: Performance numbers**

From the same `_shot_anim.gd` run, record the `idle frames=... mean_ms=... max_draw_calls=...` line. Budget: mean at or under 8 ms, draw calls at most 775 (755 + 20).

- [ ] **Step 3: Draw-call baseline on `60c7256`**

```bash
git worktree add /tmp/daily_base 60c7256
cat > /tmp/daily_base/tests/_draw_calls.gd <<'EOS'
extends SceneTree
## Throwaway: open Binairo and print the draw calls of one idle frame.
var _menu: Node
var _t := 0.0
var _opened := false
func _initialize() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")
func _process(delta: float) -> bool:
	_t += delta
	if not _opened and _t >= 0.1:
		_menu._open(load("res://ui/registry.gd").PUZZLES[0])
		_opened = true
	elif _t >= 2.5:
		print("baseline draw_calls=%d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		return true
	return false
EOS
godot --headless --path /tmp/daily_base --import >/dev/null 2>&1
godot --path /tmp/daily_base --resolution 1080x1920 --script res://tests/_draw_calls.gd 2>&1 | grep baseline
git worktree remove --force /tmp/daily_base
```

- [ ] **Step 4: Spec amendments**

Append to the spec, before section 10 or as amendments at the end:

- Section 8 (Testing): "Amendment (2026-09-14): the user suspended new tests for this sub-project. No new suites were written; the existing suite, the win harness (which now presses Hint and Check) and the screenshot harness are the checks. The tests described above remain the intended coverage when testing resumes."
- Section 2: "Amendment: the panels share a base script, `ui/hud/panel.gd`, which owns `_inner`, the minimum-size plumbing and `enter()`. `ui/hud/line_card.gd` is a plain `PanelContainer` inside the action bar, not a panel of its own."
- Section 9: the measured `mean_ms`, `max_draw_calls` and the `60c7256` baseline (or the sentence that the old tree could not run it).
- Section 10 (Files): add `ui/hud/panel.gd`; strike the new test files.

- [ ] **Step 5: Commit**

```bash
git add shaders/toon_wind.gdshader docs/superpowers/specs/2026-09-14-binairo-hud-design.md
git commit -m "fix: mirrored rim pieces lean with the wind; spec amendments and performance numbers"
```
