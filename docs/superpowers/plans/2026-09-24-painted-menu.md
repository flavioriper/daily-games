# The Painted First Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the first screen (`ui/menu.gd` and `ui/menu/*`) toward the user's painted mock. It gets two columns paged, painted vista backdrops behind the header, the day card and every card banner with the cast still drawn in code on top, soft shadows, red hearts and a floating bar.

**Architecture:** One canvas shader (`shaders/painted_plate_2d.gdshader`) on a `ColorRect` draws every painted surface in one draw call: a crop of a vista, a rounded mask, and the washes. One static table (`ui/menu/vistas.gd`) names every crop and builds the plates. The grid goes to two columns by changing constants alone, because `_fit_grid` already fits columns of `MIN_CARD_W`.

**Tech Stack:** Godot 4.7, GDScript, gl_compatibility renderer (Android via ANGLE/GLES3).

**Spec:** `docs/superpowers/specs/2026-09-24-painted-menu-design.md`. Concept: `docs/brainstorm/concepts.html#menu2` (open it with `open -a "Google Chrome" "file://$PWD/docs/brainstorm/concepts.html#menu2"`).

## Global Constraints

- Design space is 1080×1920. **Every render harness runs at `--resolution 810x1440`, and the flag goes BEFORE `--script`.** A card wider than 490 in design space (368 px on the 810 shot) means the flag landed after `--script`.
- **No `instance uniform`** anywhere: they return garbage on Android past the 16th instance. Each plate owns its own `ShaderMaterial`.
- **Characters are never images.** Only vista backdrops are images. `ui/menu/card_art.gd` and `ui/faces/` stay code.
- **A missing vista file is a gradient, never an error**: no `push_error`, and nothing printed.
- Painted plates are `ColorRect`s, never Panels, so `CozyTheme.dress()` does not put the paper material on them.
- Draw-call budget: 855. Today: page one 334, page two 181, Streak 142, Stats 148.
- **No new test suites** (the user's MVP rule). The suite `godot --headless --path . --script tests/run_tests.gd` must stay at `failed=0`. Checks are render shots plus throwaway probes that are deleted after use.
- Windowed Godot runs rewrite `project.godot` with a header comment. Run `git checkout -- project.godot` after every windowed run, unless the task changed `project.godot` on purpose (none do).
- Run render harnesses one at a time, never overlapping. Take two sequential readings and quote the second.
- Write code that matches its surroundings: `##` doc comments that explain why, `const` numbers with a comment giving their budget, and tabs for indentation.
- Commit on `feat/painted-menu`. Never push, because pushing main deploys; the user decides that.

## Review Focus

1. **The file is missing.** Rename `vista_night.png` away. Untangle, Light Up and Fairy Lights must show the colour gradient, and the log must stay clean (Task 1, Step 5 and Task 6, Step 4).
2. **Entrance and page-turn fades.** The plates must fade with their card or row. The shader multiplies by the input `COLOR`, and forgetting that leaves painted banners hanging opaque while a page crossfades (Task 1 shader, checked in Task 2, Step 6).
3. **A tall phone (660×1500, 9:20).** The grid must fit 2×5, the header backdrop must still reach behind the day card, and no card is wider than it is designed for (Task 2, Step 6; Task 4, Step 5).
4. **Language switch.** The day vista is keyed on the `ISLAND_n` key and not on translated text, so pt and es show the same vista (Task 3, Step 4).
5. **The Android driver.** Plates render under `--rendering-driver opengl3_angle` with the same draw-call count (Task 6, Step 3).

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `shaders/painted_plate_2d.gdshader` | create | Crop, rounded mask, scrim, wash, fade and fallback, in one pass |
| `ui/menu/vistas.gd` | create | The table of every crop, plus plate builders |
| `assets/art/menu/vista_*.png.import` | create (generated, then edited) | Lossy WebP, no mipmaps |
| `ui/theme.gd` | modify | `lifted()` stylebox, and the `CardName`/`CardBlurb` sizes |
| `core/palette.gd` | modify | `HEART` |
| `ui/menu.gd` | modify | Grid constants, header backdrop, pager and toast offsets |
| `ui/menu/puzzle_card_2d.gd` | modify | Painted banner, text layout, lifted card and go-button |
| `ui/menu/day_row.gd` | modify | Vista plate, red hearts, 200 tall |
| `ui/menu/menu_header.gd` | modify | Bigger pair seated on the deck, lifted buttons |
| `ui/menu/bottom_bar.gd` | modify | 120 tall, round and lifted |
| `CLAUDE.md`, `docs/superpowers/specs/2026-09-18-flat-menu-design.md` | modify | Docs |

---

### Task 1: The plate shader and the vista table

**Files:**
- Create: `shaders/painted_plate_2d.gdshader`
- Create: `ui/menu/vistas.gd`
- Create/modify: `assets/art/menu/vista_{beach,dusk,meadow,night,autumn,sky}.png.import`

**Interfaces:**
- Produces, used by Tasks 2 to 4:
  - `Vistas.card_plate(id: String, tint: Color) -> ColorRect`: a card banner (radius 28, wash on). Uses the fallback gradient in `tint` when `id` is not in `CARDS` or its file is missing.
  - `Vistas.day_plate() -> ColorRect`: a day-card plate (radius 36, left scrim) with no vista set yet.
  - `Vistas.set_day_vista(plate: ColorRect, island_key: String, tint: Color) -> void`
  - `Vistas.header_plate() -> ColorRect`: the header backdrop (radius 0, left scrim, bottom fade).
  - `Vistas.crop(plate: Vector2, tex: Vector2, zoom: float, focus: Vector2) -> Rect2`: the UV rect.

- [ ] **Step 1: Write the shader**

`shaders/painted_plate_2d.gdshader`:

```glsl
shader_type canvas_item;

// One painted plate on the first screen: a crop of a vista, masked to a
// rounded rect, with the menu's washes -- all in one draw call. Drawn on a
// ColorRect (never a Panel, so CozyTheme.dress() leaves it alone); the vista
// is a sampler uniform rather than TEXTURE so a missing file can still draw
// the fallback gradient. No instance uniforms: each plate owns its material.
// Spec: docs/superpowers/specs/2026-09-24-painted-menu-design.md, section 3.

uniform sampler2D vista : source_color, filter_linear, repeat_disable;
// x, y, w, h of the crop in the vista's UV.
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float radius = 0.0;
// strength, from, to (fractions of the width): a wash toward paper from
// the left edge, behind text.
uniform vec3 scrim = vec3(0.0, 0.0, 1.0);
// A radial glow toward paper under the cast (card banners).
uniform float wash = 0.0;
// from, to (fractions of the height): fade to transparent. Past 1 is none.
uniform vec2 fade = vec2(2.0, 3.0);
uniform bool fallback = false;
uniform vec4 tint : source_color = vec4(0.30, 0.60, 0.58, 1.0);
uniform vec4 paper : source_color = vec4(0.965, 0.937, 0.890, 1.0);
uniform vec4 surface : source_color = vec4(1.0, 0.992, 0.973, 1.0);

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec3 c;
	if (fallback) {
		// Sky over a ground band, in the card's own colour let down into
		// paper -- the concept page's gradient fallback.
		float sky_t = clamp(UV.y / 0.62, 0.0, 1.0);
		vec3 sky = mix(tint.rgb, paper.rgb, mix(0.82, 0.70, sky_t));
		vec3 ground = mix(tint.rgb, paper.rgb, mix(0.55, 0.50, clamp((UV.y - 0.62) / 0.38, 0.0, 1.0)));
		c = UV.y < 0.62 ? sky : ground;
	} else {
		c = texture(vista, uv_rect.xy + UV * uv_rect.zw).rgb;
	}
	float s = scrim.x * (1.0 - smoothstep(scrim.y, scrim.z, UV.x));
	c = mix(c, paper.rgb, s);
	float d = length((UV - vec2(0.5, 0.58)) / vec2(0.46, 0.70));
	c = mix(c, surface.rgb, wash * (1.0 - smoothstep(0.0, 1.0, d)));
	vec2 p = (UV - 0.5) * rect_size;
	float edge = clamp(0.5 - rounded_box(p, rect_size * 0.5, radius), 0.0, 1.0);
	float a = edge * (1.0 - smoothstep(fade.x, fade.y, UV.y));
	// Multiply by the incoming COLOR so modulate (entrances, page-turn
	// crossfades) still reaches the plate.
	COLOR = vec4(c, a) * COLOR;
}
```

- [ ] **Step 2: Write the vista table**

`ui/menu/vistas.gd`:

```gdscript
extends RefCounted

## Every painted surface on the first screen, and the one place the art is
## named. Six vistas (assets/art/menu/vista_<name>.png, supplied by the user
## on 2026-09-24) are cropped for the header, the day card and all twenty
## card banners; a plate is a ColorRect with shaders/painted_plate_2d.gdshader,
## one draw call. Crops are fractions of the picture, never pixels, so a
## full-size original can replace a file with no change here.
##
## A vista that is not on disk, or a card this table does not name, draws a
## sky-over-ground gradient in the card's colour instead -- never an error,
## the way Fx2D.cue() plays silence for a missing sound.
## Spec: docs/superpowers/specs/2026-09-24-painted-menu-design.md, section 4.

const Pal = preload("res://core/palette.gd")
const SHADER = preload("res://shaders/painted_plate_2d.gdshader")

const DIR := "res://assets/art/menu/vista_%s.png"

## [vista, zoom, focus]: zoom 1.0 is cover, and focus is where the crop sits
## in the room the zoom leaves (CSS background-position). Copied from the
## concept page's table.
const HEADER := ["dusk", 1.1, Vector2(0.88, 0.70)]
const HEADER_SCRIM := Vector3(0.78, 0.0, 0.62)
const HEADER_FADE := Vector2(0.62, 0.96)
const CARD_RADIUS := 28.0
const CARD_WASH := 0.62
const DAY_RADIUS := 36.0
const DAY_SCRIM := Vector3(0.94, 0.25, 0.66)

const CARDS := {
	"binairo": ["sky", 1.5, Vector2(0.30, 0.30)],
	"mastermind": ["meadow", 1.6, Vector2(0.70, 0.55)],
	"balance": ["sky", 1.4, Vector2(0.80, 0.45)],
	"untangle": ["night", 1.5, Vector2(0.60, 0.40)],
	"shikaku": ["meadow", 1.5, Vector2(0.20, 0.70)],
	"tents": ["autumn", 1.5, Vector2(0.70, 0.40)],
	"lightup": ["night", 1.7, Vector2(0.85, 0.60)],
	"oneline": ["meadow", 1.4, Vector2(0.45, 0.80)],
	"nonogram": ["dusk", 1.5, Vector2(0.20, 0.35)],
	"queens": ["meadow", 1.8, Vector2(0.90, 0.85)],
	"hiddenword": ["dusk", 1.5, Vector2(0.55, 0.55)],
	"wordtrail": ["autumn", 1.6, Vector2(0.40, 0.20)],
	"mushroom": ["autumn", 1.7, Vector2(0.15, 0.80)],
	"sudoku": ["dusk", 1.7, Vector2(0.85, 0.75)],
	"bridges": ["beach", 1.5, Vector2(0.70, 0.65)],
	"quilt": ["dusk", 1.8, Vector2(0.92, 0.70)],
	"fairylights": ["night", 1.6, Vector2(0.20, 0.70)],
	"planes": ["sky", 1.4, Vector2(0.50, 0.20)],
	"pinwheel": ["beach", 1.6, Vector2(0.20, 0.55)],
	"rings": ["meadow", 1.5, Vector2(0.40, 0.30)],
}

## Island key (core/progress.gd's ISLANDS) to the vista its name suggests.
## Keyed on the key, never the translated name, so every language sees the
## same picture.
const DAY := {
	"ISLAND_0": "beach", "ISLAND_1": "meadow", "ISLAND_2": "night",
	"ISLAND_3": "beach", "ISLAND_4": "dusk", "ISLAND_5": "autumn",
	"ISLAND_6": "beach", "ISLAND_7": "meadow", "ISLAND_8": "beach",
	"ISLAND_9": "night", "ISLAND_10": "autumn", "ISLAND_11": "meadow",
	"ISLAND_12": "sky", "ISLAND_13": "dusk", "ISLAND_14": "meadow",
	"ISLAND_15": "autumn", "ISLAND_16": "dusk", "ISLAND_17": "autumn",
	"ISLAND_18": "dusk", "ISLAND_19": "autumn", "ISLAND_20": "sky",
	"ISLAND_21": "beach", "ISLAND_22": "night", "ISLAND_23": "sky",
}
## Where each vista's day-card crop looks (zoom 1.0, cover).
const DAY_FOCUS := {
	"beach": Vector2(0.50, 0.62), "dusk": Vector2(0.30, 0.55),
	"meadow": Vector2(0.50, 0.60), "night": Vector2(0.55, 0.60),
	"autumn": Vector2(0.50, 0.55), "sky": Vector2(0.50, 0.45),
}

static var _cache := {}

## The vista's texture, or null when the file is not there. ResourceLoader
## .exists is asked first so a missing file prints nothing.
static func texture(vista: String) -> Texture2D:
	if _cache.has(vista):
		return _cache[vista]
	var path := DIR % vista
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[vista] = tex
	return tex

## The crop, as a UV rect: cover the plate, zoom past cover, then slide to
## `focus` within the room the zoom leaves.
static func crop(plate: Vector2, tex: Vector2, zoom: float, focus: Vector2) -> Rect2:
	if plate.x <= 0.0 or plate.y <= 0.0 or tex.x <= 0.0 or tex.y <= 0.0:
		return Rect2(0.0, 0.0, 1.0, 1.0)
	var s := maxf(plate.x / tex.x, plate.y / tex.y) * maxf(zoom, 1.0)
	var frac := (plate / s) / tex
	return Rect2((Vector2.ONE - frac) * focus, frac)

static func _plate(radius: float) -> ColorRect:
	var plate := ColorRect.new()
	plate.color = Color.WHITE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("paper", Pal.PAPER)
	mat.set_shader_parameter("surface", Pal.SURFACE)
	plate.material = mat
	plate.resized.connect(func() -> void: _refit(plate))
	return plate

## Points `plate` at a vista (or the fallback in `tint`) and re-crops it.
static func point_at(plate: ColorRect, vista: String, zoom: float, focus: Vector2, tint: Color) -> void:
	var mat := plate.material as ShaderMaterial
	var tex := texture(vista)
	mat.set_shader_parameter("fallback", tex == null)
	mat.set_shader_parameter("vista", tex)
	mat.set_shader_parameter("tint", tint)
	plate.set_meta("zoom", zoom)
	plate.set_meta("focus", focus)
	_refit(plate)

static func _refit(plate: ColorRect) -> void:
	var mat := plate.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", plate.size)
	var tex: Texture2D = mat.get_shader_parameter("vista")
	if tex == null:
		return
	var r := crop(plate.size, tex.get_size(), float(plate.get_meta("zoom", 1.0)), plate.get_meta("focus", Vector2(0.5, 0.5)))
	mat.set_shader_parameter("uv_rect", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))

static func card_plate(id: String, tint: Color) -> ColorRect:
	var plate := _plate(CARD_RADIUS)
	(plate.material as ShaderMaterial).set_shader_parameter("wash", CARD_WASH)
	var row: Array = CARDS.get(id, ["", 1.0, Vector2(0.5, 0.5)])
	point_at(plate, row[0], row[1], row[2], tint)
	return plate

static func day_plate() -> ColorRect:
	var plate := _plate(DAY_RADIUS)
	(plate.material as ShaderMaterial).set_shader_parameter("scrim", DAY_SCRIM)
	return plate

static func set_day_vista(plate: ColorRect, island_key: String, tint: Color) -> void:
	var vista: String = DAY.get(island_key, "beach")
	point_at(plate, vista, 1.0, DAY_FOCUS.get(vista, Vector2(0.5, 0.5)), tint)

static func header_plate() -> ColorRect:
	var plate := _plate(0.0)
	var mat := plate.material as ShaderMaterial
	mat.set_shader_parameter("scrim", HEADER_SCRIM)
	mat.set_shader_parameter("fade", HEADER_FADE)
	point_at(plate, HEADER[0], HEADER[1], HEADER[2], Pal.ACCENT)
	return plate
```

- [ ] **Step 3: Import the vistas as lossy WebP with no mipmaps**

Run: `godot --headless --path . --import`
Then edit each of the six `assets/art/menu/vista_*.png.import` files and set these params (leave the rest as generated):

```
compress/mode=1
compress/lossy_quality=0.85
mipmaps/generate=false
detect_3d/compress_to=0
```

`detect_3d/compress_to=0` stops the editor switching them to VRAM compression later (project memory "detect_3d texture flip").

Run: `godot --headless --path . --import` again.
Expected: no errors, and `.godot/imported/vista_*` regenerated.

- [ ] **Step 4: Render every mode with a throwaway probe**

Create `tests/_probe_plates.gd` (throwaway, deleted in Step 6):

```gdscript
extends SceneTree

const Vistas = preload("res://ui/menu/vistas.gd")
const Pal = preload("res://core/palette.gd")

var _f := 0

func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		var bg := ColorRect.new()
		bg.color = Pal.PAPER
		bg.size = Vector2(1080, 1920)
		root.add_child(bg)
		var h := Vistas.header_plate()
		h.position = Vector2.ZERO
		h.size = Vector2(1080, 560)
		root.add_child(h)
		var d := Vistas.day_plate()
		d.position = Vector2(40, 600)
		d.size = Vector2(1000, 200)
		root.add_child(d)
		Vistas.set_day_vista(d, "ISLAND_6", Pal.ACCENT)
		var ids := ["binairo", "untangle", "bridges", "no_such_board"]
		for i in ids.size():
			var p := Vistas.card_plate(ids[i], Pal.CAT[i])
			p.position = Vector2(40 + (i % 2) * 510, 840 + (i / 2) * 140)
			p.size = Vector2(470, 108)
			root.add_child(p)
	if _f == 20:
		root.get_texture().get_image().save_png("/tmp/shot_plates.png")
		print("saved /tmp/shot_plates.png")
		quit()
	return false
```

Run: `godot --path . --resolution 810x1440 --script res://tests/_probe_plates.gd; git checkout -- project.godot`
Expected: `saved /tmp/shot_plates.png`, and no `ERROR` lines. Read the PNG and check:
- The header shows the treehouse deck at the right, pale on the left, and fades out at the bottom.
- The day card shows the beach, rounded, with paper on the left.
- The Binairo, Untangle and Bridges banners are painted, rounded, and pale in the middle.
- `no_such_board` is a teal-into-paper gradient with a ground band.

- [ ] **Step 5: The missing-file check**

Run: `mv assets/art/menu/vista_beach.png /tmp/ && godot --path . --resolution 810x1440 --script res://tests/_probe_plates.gd 2>&1 | grep -iE "error|warn"; mv /tmp/vista_beach.png assets/art/menu/; git checkout -- project.godot`
Expected: grep prints nothing. The day card and the Bridges plate in `/tmp/shot_plates.png` are gradients.

- [ ] **Step 6: Clean up, run the suite and commit**

Run: `rm tests/_probe_plates.gd tests/_probe_plates.gd.uid 2>/dev/null; godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -3`
Expected: `failed=0`.

```bash
git add shaders/painted_plate_2d.gdshader shaders/painted_plate_2d.gdshader.uid ui/menu/vistas.gd ui/menu/vistas.gd.uid assets/art/menu
git commit -m "feat(menu): painted plate shader and the vista table"
```

---

### Task 2: Two columns, and the card's painted banner

**Files:**
- Modify: `ui/menu.gd` (constants at lines 43-72)
- Modify: `ui/menu/puzzle_card_2d.gd`
- Modify: `ui/theme.gd` (lines 43-44; add `lifted()` after `card()`)

**Interfaces:**
- Consumes: `Vistas.card_plate(id, tint)` from Task 1.
- Produces: `CozyTheme.lifted(fill: Color, radius: int, margin: int) -> StyleBoxFlat`, used by Tasks 3 to 5.

- [ ] **Step 1: Add `lifted()` to `ui/theme.gd`**, directly after `static func card(...)`:

```gdscript
## A card lifted off the page by a soft warm shadow instead of card()'s hard
## bottom edge: the painted first screen's paper (spec 2026-09-24-painted-menu,
## section 8). Only the menu's own widgets wear it.
static func lifted(fill: Color, radius: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0.35, 0.23, 0.12, 0.14)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0.0, 6.0)
	sb.anti_aliasing_size = 1.2
	return sb
```

Change the two label sizes (used only by `ui/menu/puzzle_card_2d.gd`):

```gdscript
	_label(theme, "CardName", display(700), 44, Pal.TEXT)
	_label(theme, "CardBlurb", body(600), 26, Pal.TEXT_DIM)
```

- [ ] **Step 2: Grid constants in `ui/menu.gd`**

- `COLS := 3` → `COLS := 2`.
- `MIN_CARD_W := 320.0` → `MIN_CARD_W := 490.0`, with its comment rewritten: "The narrowest a card may be drawn: two across in the 1000 between the margins, less one 20 gap (spec 2026-09-24-painted-menu, section 2)."
- `PER_PAGE := 12` → `PER_PAGE := 8`.
- Rewrite the first sentence of `PER_PAGE`'s comment block: "Eight cards a page: two across and four down is what 80 of margin, 60 of gaps, a 380 header, a 200 day row and a 120 bar leave for rows of 246." Keep the rest of the block's history as it is.
- The `MIN_ROW_GAP` comment's "The day row measures 188 against the 180" sentence becomes "The day row is 200 and the grid has 36 of slack at 1920, so the gap rarely closes; it is kept for shorter screens."

- [ ] **Step 3: Rebuild the card in `ui/menu/puzzle_card_2d.gd`**

Constants:

```gdscript
const ART_H := 108.0
const CARD_H := 246.0
const ART_GROW := 26.0
## The banner's inset from the card's edge; the text sits TEXT_INSET further in.
const INSET := 10
const TEXT_INSET := 18
const GO := 80.0
```

Delete `ART_TINT`, `ART_RADIUS` and `_art_style()`. Update the comments above `ART_H` and `CARD_H` to the 246 budget: "10 inset + 108 banner + 4 + a 44 name and two 26 blurb lines beside an 80 go-button + 10."

At the top, add `const Vistas = preload("res://ui/menu/vistas.gd")`.

`_make_inner()`: the stylebox becomes

```gdscript
	var paper := CozyTheme.lifted(Pal.SURFACE, 36, INSET)
	paper.set_border_width_all(2)
	paper.border_color = Color(Pal.LINE, 0.35)
	box.add_theme_stylebox_override("panel", paper)
```

`_build()`: replace everything from `var art_plate := PanelContainer.new()` down to just before `# The tap surface` with:

```gdscript
	var art_plate := PanelContainer.new()
	_art_plate = art_plate
	art_plate.custom_minimum_size = Vector2(0.0, ART_H + clampf(card_h - CARD_H, 0.0, ART_GROW))
	art_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_plate.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	col.add_child(art_plate)
	# The painted banner under the cast: one draw call (ui/menu/vistas.gd).
	var banner := Vistas.card_plate(String(entry.get("id", "")), colour)
	banner.modulate.a = SOON_INK if soon else 1.0
	art_plate.add_child(banner)
	art = CardArt.new(String(entry.get("id", "")))
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.modulate.a = SOON_INK if soon else 1.0
	art_plate.add_child(art)

	# Name and blurb in a column beside the go button, centred against both
	# lines together the way the mock sets it; TEXT_INSET in from the banner.
	var text_margin := MarginContainer.new()
	text_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_margin.add_theme_constant_override("margin_left", TEXT_INSET)
	text_margin.add_theme_constant_override("margin_right", TEXT_INSET - INSET)
	col.add_child(text_margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	text_margin.add_child(row)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)

	var name_label := Label.new()
	name_label.theme_type_variation = "CardName"
	name_label.text = "BINAiRO" if String(entry.get("id", "")) == "binairo" else String(entry.get("title", ""))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if soon:
		name_label.add_theme_color_override("font_color", Pal.TEXT_DIM)
	words.add_child(name_label)
	name_label.add_child(SunDot.new(name_label, SOON_INK if soon else 1.0))

	var blurb := Label.new()
	blurb.theme_type_variation = "CardBlurb"
	# The registry's `short` is written to two lines at this width; `blurb`
	# is the long one the rules sheet wants.
	# Every `short` is a translation key, which the Label translates itself.
	blurb.text = String(entry.get("short", entry.get("blurb", "")))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.max_lines_visible = 2
	blurb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	blurb.add_theme_constant_override("line_spacing", -6)
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(blurb)
	if not soon:
		var go := IconButton.new("chevron_right")
		go.custom_minimum_size = Vector2(GO, GO)
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		go.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_paint_go(go)
		row.add_child(go)
	else:
		_build_pill()
```

Keep the existing `col.add_theme_constant_override("separation", 4)` above it.

`_paint_go`: swap the four `CozyTheme.card(...)` calls for lifted discs, keeping the pressed darkening:

```gdscript
func _paint_go(go: Button) -> void:
	var r := int(GO * 0.5)
	var up := CozyTheme.lifted(colour, r, 8)
	up.shadow_size = 6
	up.shadow_offset = Vector2(0.0, 4.0)
	up.border_width_bottom = 5
	up.border_color = colour.darkened(0.14)
	var down := CozyTheme.lifted(colour.darkened(0.12), r, 8)
	down.shadow_size = 2
	for state in ["normal", "hover"]:
		go.add_theme_stylebox_override(state, up)
	go.add_theme_stylebox_override("pressed", down)
	var off := up.duplicate()
	off.bg_color = Color(colour, 0.55)
	go.add_theme_stylebox_override("disabled", off)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		go.add_theme_color_override(state, Pal.SURFACE)
```

In `_build_done_badge`, the seal still hangs off `_art_plate`, which is unchanged apart from the stylebox. Leave it.

- [ ] **Step 4: Check the card fits 246 with a throwaway probe**

Create `tests/_probe_card.gd`:

```gdscript
extends SceneTree

const PuzzleCard = preload("res://ui/menu/puzzle_card_2d.gd")
const Registry = preload("res://ui/registry.gd")
const Pal = preload("res://core/palette.gd")

var _f := 0
var _c: Control

func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_c = PuzzleCard.new(Registry.PUZZLES[0], Pal.CAT[0])
		_c.size = Vector2(490, 246)
		root.add_child(_c)
	if _f == 6:
		print("card min=", _c.get_combined_minimum_size(), " inner min=", _c._inner.get_combined_minimum_size())
		quit()
	return false
```

Run: `godot --headless --path . --script res://tests/_probe_card.gd`
Expected: `inner min` y ≤ 246. If it is over, lower `ART_H` by the excess (never below 96) and re-run. Record the final `ART_H` in its comment. Then `rm tests/_probe_card.gd*`.

- [ ] **Step 5: Shoot the menu**

Run: `godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd; git checkout -- project.godot`, then `godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd -- page2; git checkout -- project.godot`
Expected: a two-column grid of eight cards on `/tmp/shot_menu_1.png`, with painted rounded banners and the cast on top, and cards measuring 490 wide in design space (367-368 px at 810). Page two shows cards 9 to 16. Read both images and compare them with the concept (`docs/brainstorm/concepts.html#menu2`). The name, both blurb lines and the go-button sit inside the card with air under the blurb. Note the printed `max_draw_calls` for each.

- [ ] **Step 6: Tall phone, and the page-turn fade**

Run: `godot --path . --resolution 660x1500 --script res://tests/_shot_menu.gd; git checkout -- project.godot`
Expected: 2×5 on page one. Read the image.

Page-turn fade: read `/tmp/shot_menu_page2.png` from Step 5. No banner from page one may be left standing over page two (a plate that ignored modulate would stay at full opacity through the crossfade).

- [ ] **Step 7: Suite and commit**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -3`, expecting `failed=0`.

```bash
git add ui/menu.gd ui/menu/puzzle_card_2d.gd ui/theme.gd
git commit -m "feat(menu): two columns, painted card banners"
```

---

### Task 3: The day card

**Files:**
- Modify: `ui/menu/day_row.gd`
- Modify: `core/palette.gd` (add `HEART` near `ACCENT_2`)

**Interfaces:**
- Consumes: `Vistas.day_plate()` and `Vistas.set_day_vista(plate, island_key, tint)` from Task 1, and `CozyTheme.lifted()` from Task 2.
- Produces: `set_day(n: int, island: String)`, which keeps its signature. `island` is the `ISLAND_n` key, as `ui/menu.gd:_refresh_day` already passes it.

- [ ] **Step 1: Palette.** In `core/palette.gd`, directly after `const ACCENT_2`:

```gdscript
## An earned heart on the first screen's day card: a warm red that holds up
## over a painted vista, where ACCENT_2's orange sank into the sand.
const HEART := Color("e0574f")
```

- [ ] **Step 2: Rebuild the row.** In `ui/menu/day_row.gd`:

Add `const Vistas = preload("res://ui/menu/vistas.gd")`. Change `HEIGHT := 180.0` to `HEIGHT := 200.0` and `HEART := 46.0` to `HEART := 54.0`. Delete `PLATE` and `TREE`. Add `var _vista: ColorRect`.

Replace `_build()`'s opening, from the stylebox line down to and including `plate.add_child(tree)`, with:

```gdscript
	# The day's vista fills the card under a paper scrim from the left; the
	# stylebox under it only shows at the rim and carries the shadow.
	_inner.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, 40, 0))
	_inner.custom_minimum_size.y = HEIGHT
	_vista = Vistas.day_plate()
	_inner.add_child(_vista)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 24)
	pad.add_theme_constant_override("margin_left", 48)
	_inner.add_child(pad)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	pad.add_child(row)
```

The rest of `_build()` (the text column, hearts and chevron) stays, apart from the chevron's styleboxes:

```gdscript
	go.add_theme_stylebox_override("normal", CozyTheme.lifted(Pal.SURFACE, int(CHEVRON * 0.5), 8))
	go.add_theme_stylebox_override("hover", CozyTheme.lifted(Pal.SURFACE, int(CHEVRON * 0.5), 8))
	go.add_theme_stylebox_override("pressed", CozyTheme.lifted(Pal.SURFACE_HI.darkened(0.06), int(CHEVRON * 0.5), 8))
```

`_draw_hearts`: an earned heart is `Pal.HEART`. An unearned heart is a paper fill under the line, because a bare outline vanishes on a painting:

```gdscript
		if i < _hearts:
			Icons.paint(on, "heart", box, Pal.HEART)
		else:
			Icons.paint(on, "heart", box, Color(Pal.SURFACE, 0.92))
			Icons.paint(on, "heart_line", box, Pal.LINE)
```

`set_day`: after setting the labels, add `Vistas.set_day_vista(_vista, island, Pal.ACCENT)`.

Update the file's header comment: "a tree on a pale plate" becomes "the day's island painted behind it (ui/menu/vistas.gd)", and add "Spec: docs/superpowers/specs/2026-09-24-painted-menu-design.md, section 6."

- [ ] **Step 3: Shoot**

Run: `godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd; git checkout -- project.godot`
Expected: the day card shows today's island vista, with the text on paper on the left, red earned hearts, paper-filled empty hearts, and the chevron. Its height is 200 in design space (150 px at 810). Page one still holds 8 cards.

- [ ] **Step 4: Language check**

Temporarily set pt in a throwaway probe: create `tests/_probe_locale.gd`, a copy of `tests/_shot_menu.gd` whose `_initialize` begins with `TranslationServer.set_locale("pt_BR")`, run it windowed, and compare its day-card vista with Step 3's. It must be the same picture, and the island's name in Portuguese. Delete the probe and `git checkout -- project.godot`.

- [ ] **Step 5: Suite and commit**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -3`, expecting `failed=0`.

```bash
git add core/palette.gd ui/menu/day_row.gd
git commit -m "feat(menu): the day card wears its island's vista, hearts go red"
```

---

### Task 4: The header scene

**Files:**
- Modify: `ui/menu.gd` (`_build_list`, after the `Page` ColorRect)
- Modify: `ui/menu/menu_header.gd`

**Interfaces:**
- Consumes: `Vistas.header_plate()` from Task 1, and `CozyTheme.lifted()` from Task 2.

- [ ] **Step 1: The backdrop.** In `ui/menu.gd`, add `const Vistas = preload("res://ui/menu/vistas.gd")` beside the other preloads. Add a member `var _backdrop: ColorRect`. Then, in `_build_list()` right after `_list_root.add_child(page)` and before `var insets := SafeArea.insets(self)`, add:

```gdscript
	# The header's painted scene, full-bleed from the top edge (under the
	# safe area) to past the day card's top, where it fades into the paper;
	# the wordmark stands on its left scrim (spec 2026-09-24-painted-menu,
	# section 5). Laid under the margins, so no row of the column moves.
	_backdrop = Vistas.header_plate()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_list_root.add_child(_backdrop)
```

After `var insets := ...`, set its height:

```gdscript
	_backdrop.offset_bottom = MARGIN + insets.x + MenuHeader.HEIGHT + BACKDROP_BLEED
```

Also add the constant near `MARGIN`: `const BACKDROP_BLEED := 140.0 ## how far the header's scene runs behind the day card before it has faded out`.

- [ ] **Step 2: The pair on the deck, and lifted buttons.** In `ui/menu/menu_header.gd`:
- `SUN_SEAT := 190.0` → `250.0`, and `MOON_SEAT := 166.0` → `220.0`.
- `PAIR_TOP` and `PAIR_RIGHT` get set in Step 3 from the frame.
- In `_button()`, after `b.size = BUTTON`, add:

```gdscript
	var r := int(BUTTON.x * 0.29)
	b.add_theme_stylebox_override("normal", CozyTheme.lifted(Pal.SURFACE, r, 8))
	b.add_theme_stylebox_override("hover", CozyTheme.lifted(Pal.SURFACE, r, 8))
	b.add_theme_stylebox_override("pressed", CozyTheme.lifted(Pal.SURFACE_HI.darkened(0.06), r, 8))
```

In `_place_pair`, the moon currently sits `(SUN_SEAT - MOON_SEAT) * 0.5 + 8.0` lower than the sun. Keep that expression. Both bottoms have to rest on the deck.

- [ ] **Step 3: Seat the pair on the deck, against the frame**

Run: `godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd; git checkout -- project.godot`, then read `/tmp/shot_menu_1.png`. Find the deck's floor line (the horizontal plank edge under the cushion, at the right) in design pixels (shot pixels ÷ 0.75). Set `PAIR_TOP` so the sun seat's bottom (`PAIR_TOP + SUN_SEAT`, in header coordinates, header top = 40) sits about 10 px above the floor line, and set `PAIR_RIGHT` so the moon clears the lantern. Re-shoot, and repeat at most three times. Write the final values with a comment: "measured against the dusk vista's deck on the 810x1440 frame, 2026-09-24".

Also confirm the backdrop reaches the top edge, stays pale behind `Daily` and the motto, and fades out behind the top of the day card.

- [ ] **Step 4: Tabs.** Run `godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd -- streak; git checkout -- project.godot` and the same with `-- stats`. The header scene stands over both tabs, and the tab bodies are unaffected.

- [ ] **Step 5: Tall phone.** Run `godot --path . --resolution 660x1500 --script res://tests/_shot_menu.gd; git checkout -- project.godot`. The backdrop spans the full width and still fades behind the day card.

- [ ] **Step 6: Suite and commit**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -3`, expecting `failed=0`.

```bash
git add ui/menu.gd ui/menu/menu_header.gd
git commit -m "feat(menu): the header stands in the treehouse at dusk"
```

---

### Task 5: The floating bar and the pager

**Files:**
- Modify: `ui/menu/bottom_bar.gd`
- Modify: `ui/menu.gd` (`TOAST_OVER`, `PAGER_MID`, the pager pill's stylebox)

**Interfaces:**
- Consumes: `CozyTheme.lifted()` from Task 2.

- [ ] **Step 1: The bar.** In `ui/menu/bottom_bar.gd`, `HEIGHT := 150.0` becomes `HEIGHT := 120.0`, and in `_build()`:

```gdscript
	_inner.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, int(HEIGHT * 0.5), 12))
```

In `_make_tab`, `holder.custom_minimum_size.y = HEIGHT - 24.0` stays. The pill's radius `26` becomes `int((HEIGHT - 24.0) * 0.5)`, so the highlight is fully round. If the icon (56) plus the label no longer fit 96, `ICON := 56.0` becomes `ICON := 44.0`; check this in Step 3.

- [ ] **Step 2: Overlay offsets and the pill.** In `ui/menu.gd` (`BottomBar` is already preloaded there), change:

```gdscript
const TOAST_OVER := BottomBar.HEIGHT + MARGIN + 10.0
const PAGER_MID := BottomBar.HEIGHT + MARGIN + 10.0
```

In each of their comments, replace the `150` bar figure with "the bar's own HEIGHT". The pager pill's stylebox, `CozyTheme.card(Pal.SURFACE, 24, Pal.LINE, 4, 8)`, becomes `CozyTheme.lifted(Pal.SURFACE, 24, 8)`.

- [ ] **Step 3: Shoot**

Run `godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd; git checkout -- project.godot`. Check that:
- the bar is a round floating pill;
- each tab's icon and label sit inside the bar;
- the Home highlight is round;
- the pager pill floats in the seam between the last card row and the bar, with three dots;
- nothing is clipped.

- [ ] **Step 4: Suite and commit**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -3`, expecting `failed=0`.

```bash
git add ui/menu/bottom_bar.gd ui/menu.gd
git commit -m "feat(menu): a floating bar, a lifted pager"
```

---

### Task 6: Measure, and write it down

**Files:**
- Modify: `CLAUDE.md` ("The first screen" section)
- Modify: `docs/superpowers/specs/2026-09-18-flat-menu-design.md` (one line at the top)
- Modify: `docs/superpowers/specs/2026-09-24-painted-menu-design.md` (add a "Measured" section at the end)

- [ ] **Step 1: Draw calls and idle.** Run each of these twice, one after another (never overlapping), running `git checkout -- project.godot` after each, and record the second reading's `max_draw_calls` and `mean_ms`:
  - `godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd`
  - `... -- page2`
  - `... -- streak`
  - `... -- stats`

Expected: all well under 855. Page one should be near today's 334 or below it, since 8 cards replace 12.

- [ ] **Step 2: Card width.** On `/tmp/shot_menu_1.png`, measure a card's width in pixels. Expected: 367-368 (490 × 0.75). A card noticeably wider than 368 means the flag landed after `--script`.

- [ ] **Step 3: ANGLE.** Run `godot --path . --rendering-driver opengl3_angle --resolution 810x1440 --script res://tests/_shot_menu.gd; git checkout -- project.godot`, saving the default-driver shot from Step 1 first as `/tmp/shot_default.png`. Expected: the same draw-call count, and plates drawn on every card. Compare with PIL:

```bash
python3 -c "
from PIL import Image, ImageChops
a=Image.open('/tmp/shot_default.png').convert('RGB'); b=Image.open('/tmp/shot_menu_1.png').convert('RGB')
d=ImageChops.difference(a,b); print('max delta', max(x[1] for x in d.getextrema()), 'bbox', d.getbbox())"
```

A small max delta (edge antialiasing, or the sun-dot's glint) is fine. A painted plate that is missing or garbled is not.

- [ ] **Step 4: Missing vista.** Run `mv assets/art/menu/vista_night.png /tmp/`, then the Step 1 page-one shot with `2>&1 | grep -iE "error|warn"`, then `mv /tmp/vista_night.png assets/art/menu/; git checkout -- project.godot`. Expected: no lines. Untangle and Light Up show the gradient banner.

- [ ] **Step 5: Docs.**
  - `CLAUDE.md`, "The first screen": replace "a page of puzzle cards three across and four down" with "two across and four down". Replace "Eighteen cards ... twelve on the first" with "Twenty cards, so three pages at 1080x1920: eight, eight and four". Replace the heights bullet with the new budget (80 margin, 60 gaps, 380 header, 200 day card, 120 bar, rows of 246 spent as a 10 inset, a 108 banner and the name and blurb beside an 80 go-button). Replace "A card's picture is the board's own cast" with a bullet on **painted plates**: `ui/menu/vistas.gd`, `shaders/painted_plate_2d.gdshader`, six user-supplied vistas, the fallback gradient, and "characters are still never images". Add the Step 1 readings with the date. Keep the historical figures that are labelled as history and mark them as before 2026-09-24.
  - Flat-menu spec, first line under its title: `> Layout superseded by 2026-09-24-painted-menu-design.md (two columns, painted plates); behaviour unchanged.`
  - The painted-menu spec: append `## 13. Measured` with the Step 1 to Step 4 figures.

- [ ] **Step 6: Suite and commit**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -3`, expecting `failed=0`.

```bash
git add CLAUDE.md docs/superpowers/specs/2026-09-18-flat-menu-design.md docs/superpowers/specs/2026-09-24-painted-menu-design.md
git commit -m "docs(menu): the painted first screen, measured"
```
