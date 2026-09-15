# Code Break's Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dress Code Break's screen as the concept shows it: a plank dock on a turf bank over a river, scenery around it, POM on a rock, glossy pegs, a carved tray, and the wordmark and day card on wooden plaques.

**Architecture:** The board stays as it is and gains two sibling nodes it builds itself: a `Dock` (moss rim plus plank deck, which rises on the entrance) and a `Scenery` root (banks, river, props, POM), composed by `puzzles/codebreak_scenery.gd` from generic helpers in `world/scenery.gd`. New model slots follow the Blender contract with placeholders first, so every task is testable before the art lands; the art is modelled in the live Blender session through the MCP and exported through `tools/blender_export.py`. The HUD change is two style swaps and a plaque panel in the shared top bar.

**Tech Stack:** Godot 4.7 (GDScript, Compatibility renderer), Blender 5.1 through the Blender MCP (`mcp__blender__execute_blender_code`, `mcp__blender__get_viewport_screenshot`), glTF export through `tools/blender_export.py`.

**Spec:** `docs/superpowers/specs/2026-09-15-codebreak-screen-design.md`

## Global Constraints

- No new test files (the project's MVP rule). Existing tests learn the new slots; verification otherwise is the suite, the windowed harnesses, and throwaway probes that are deleted before the commit.
- The unit suite runs headless: `godot --headless --path . --script res://tests/run_tests.gd`. Read the final `passed=N failed=0` line; a failing count blocks the commit.
- Harnesses that render (`tests/_win.gd`, `tests/_shot.gd`, `tests/_shot_anim.gd`, `tests/_shot_model.gd`) must run **windowed**, without `--headless`. `_win.gd` reporting `winnable=0/0` is a failed run, not a pass.
- Models: one mesh per layer, one material per mesh, base at Z = 0, footprint centred on the origin, smooth shading, no split normals, bevel 0.02 with 2 segments where a hard edge is wanted, base colours **linear** (convert the palette's sRGB hex). Full rules: `docs/art/blender-contract.md`. Every model is edited in the live Blender session and saved into its tracked `.blend`; never write a script that rebuilds a model from scratch outside Blender.
- The Blender MCP keeps no Python state between calls: redefine helpers in every snippet. Only one task may drive Blender at a time.
- Export: `/Applications/Blender.app/Contents/MacOS/Blender -b art/<file>.blend --python tools/blender_export.py -- <Collection ...>`, then `godot --headless --path . --import`. The exporter prints `OK <slot> ...` or `SKIP <name>: <rule>`; a SKIP is a failure to fix, not to work around.
- Commit after every task with a message in the repo's voice (imperative summary, a body that says why). Do not push.
- Budget: idle mean at or under 8 ms at 1080 x 1920 on the Mac, draw calls at most 855 (spec section 9).

---

### Task 1: Wooden HUD chrome

**Files:**
- Modify: `core/palette.gd` (after the `WOOD_DEEP` line, ~line 50)
- Modify: `ui/theme.gd` (after `wood_card()`, end of file)
- Modify: `ui/hud/top_bar.gd`
- Modify: `ui/hud/day_card.gd:22`

**Interfaces:**
- Produces: `Palette.DECK`, `Palette.BANK`, `Palette.BOULDER`, `Palette.PLAQUE`, `Palette.PLAQUE_DEEP` (all `Color`); `CozyTheme.plank_card() -> StyleBoxFlat`; `CozyTheme.wood_channel() -> StyleBoxFlat`. Tasks 2, 3 and 6 read these.

- [ ] **Step 1: Add the palette colours**

In `core/palette.gd`, directly after `const WOOD_DEEP    := Color("9c7350")   # the colour tray's bottom edge`, add:

```gdscript

# Code Break's screen (docs/art/concept-codebreak-screen.png): the plank dock
# the board is laid on, the turf bank under it, the boulders beside it, and
# the plaques the wordmark and the day card sit on.
const DECK        := Color("b5825a")   # deck planks
const BANK        := Color("8cb050")   # the turf bank and the far bank
const BOULDER     := Color("9ba5ad")   # a rock beside the deck, cool against the turf
const PLAQUE      := Color("9c6b45")   # the wordmark's and day card's wood
const PLAQUE_DEEP := Color("6e4a2f")   # its bottom edge
```

- [ ] **Step 2: Add the two styleboxes**

At the end of `ui/theme.gd`, after `wood_card()`:

```gdscript

## Dark wood with a thick deeper edge: the plank the wordmark and the day
## card sit on.
static func plank_card() -> StyleBoxFlat:
	return card(Pal.PLAQUE, 18, Pal.PLAQUE_DEEP, 10, 20)

## The trough carved into the colour tray, holding the buttons.
static func wood_channel() -> StyleBoxFlat:
	return card(Pal.WOOD_DEEP, 20, Pal.WOOD_DEEP.darkened(0.25), 4, 10)
```

- [ ] **Step 3: Put the wordmark on a plaque**

In `ui/hud/top_bar.gd`, add three constants after `const LEAF := 36.0`:

```gdscript
const NAIL_R := 6.0
const NAIL_INSET := 18.0
const LEAF_INSET := 10.0
```

Add a field after `var _motto: Label`:

```gdscript
var _plaque: PanelContainer
```

Replace the block in `_build()` that starts at `var words := VBoxContainer.new()` and ends at `_inner.add_child(words)` (four lines) with:

```gdscript
	# The plaque hugs the title and motto and stays centred between the
	# buttons: the CenterContainer takes the expanding slot the words used to.
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner.add_child(centre)
	_plaque = PanelContainer.new()
	_plaque.name = "Plaque"
	_plaque.add_theme_stylebox_override("panel", CozyTheme.plank_card())
	_plaque.draw.connect(_draw_plaque)
	centre.add_child(_plaque)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	_plaque.add_child(words)
```

The rest of `_build()` (title row, leaf, motto) stays as it is. Add after `_button(...)`:

```gdscript

## Two nail heads at the plaque's top corners and a second leaf at its
## bottom-left, mirrored (a negative-width rect flips the icon). The first
## leaf stays at the title's top-right.
func _draw_plaque() -> void:
	var w := _plaque.size.x
	var h := _plaque.size.y
	for x in [NAIL_INSET, w - NAIL_INSET]:
		_plaque.draw_circle(Vector2(x, NAIL_INSET), NAIL_R, Pal.OUTLINE)
	Icons.paint(_plaque, "leaf", Rect2(Vector2(LEAF_INSET + LEAF, h - LEAF - LEAF_INSET), Vector2(-LEAF, LEAF)), Pal.MOSS)
```

`Pal` is already available through `panel.gd` (`const Pal = preload("res://core/palette.gd")`); do not redeclare it.

- [ ] **Step 4: Put the day card on the same wood**

In `ui/hud/day_card.gd`, change

```gdscript
	(_inner as PanelContainer).add_theme_stylebox_override("panel", CozyTheme.slate_card())
```

to

```gdscript
	(_inner as PanelContainer).add_theme_stylebox_override("panel", CozyTheme.plank_card())
```

Update the file's header comment from "The slate day card" to "The wooden day card".

- [ ] **Step 5: Run the suite**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `passed=<N> failed=0` with N at least 1497.

- [ ] **Step 6: Look at it**

Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd 2>&1 | grep saved`
Then open `/tmp/shot_menu.png` and `/tmp/shot_mastermind.png` (the Read tool shows PNGs). Check: the wordmark and motto sit on a dark wood plaque with two nail heads and a leaf at each end; the day card is the same wood with cream text; the plaque is centred between the buttons on both screens and does not overlap the buttons. If the plaque overlaps a button on the menu, reduce the `Wordmark` label's font size is **not** the fix; instead check that `centre` has `SIZE_EXPAND_FILL` and the plaque does not.

- [ ] **Step 7: Commit**

```bash
git add core/palette.gd ui/theme.gd ui/hud/top_bar.gd ui/hud/day_card.gd
git commit -m "feat(hud): the wordmark and the day card sit on wooden plaques

The concept for Code Break's screen puts its title on a carved plank
with nail heads and leaves, and its day card on the same wood. Both
panels are shared, so the menu and every board take the plaque too."
```

---

### Task 2: The carved tray and glossy peg buttons

**Files:**
- Modify: `ui/hud/palette_tray.gd:16-21`
- Modify: `ui/hud/peg_button.gd:15,50-62`

**Interfaces:**
- Consumes: `CozyTheme.wood_channel()` from Task 1.

- [ ] **Step 1: Carve the channel**

In `ui/hud/palette_tray.gd`, replace `_ready()` with:

```gdscript
func _ready() -> void:
	add_theme_stylebox_override("panel", CozyTheme.wood_card())
	# The trough: a darker inset the buttons sit in, so the tray reads as
	# carved rather than painted.
	var channel := PanelContainer.new()
	channel.name = "Channel"
	channel.add_theme_stylebox_override("panel", CozyTheme.wood_channel())
	add_child(channel)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", GAP)
	channel.add_child(_row)
```

- [ ] **Step 2: Add the highlights**

In `ui/hud/peg_button.gd`, change `const SHADE := 0.25` to `const SHADE := 0.3` and add after it:

```gdscript
const SHINE := 0.9
```

Replace the end of `_draw()`, from `draw_circle(centre - Vector2(0.0, r * 0.1), r * 0.88, fill)` to the end of the function, with:

```gdscript
	draw_circle(centre - Vector2(0.0, r * 0.1), r * 0.88, fill)
	# The glossy highlight: a large spot upper-left and a small one above it,
	# the same place the peg model's Shine layer sits.
	var shine := Color(Pal.MOON, SHINE * alpha)
	draw_circle(centre + Vector2(-0.38, -0.42) * r, r * 0.2, shine)
	draw_circle(centre + Vector2(-0.12, -0.6) * r, r * 0.09, shine)
	Shapes.draw_pips(self, mark, centre - Vector2(0.0, r * 0.12), r * 0.3, r * 0.1,
		Color(colour.darkened(MARK_SHADE), alpha))
```

- [ ] **Step 3: Run the suite and look**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -1` → `failed=0`.
Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd 2>&1 | grep mastermind`, open `/tmp/shot_mastermind.png`. Check: the tray has a darker inset band behind the six buttons; each button shows a cream highlight upper-left and the pips still read.

- [ ] **Step 4: Commit**

```bash
git add ui/hud/palette_tray.gd ui/hud/peg_button.gd
git commit -m "feat(hud): the colour tray is a carved trough of glossy pegs

An inset channel behind the buttons and a highlight on each disc, so
the tray matches the pegs it drops on the board."
```

---

### Task 3: Seven new model slots, contract first

**Files:**
- Modify: `core/models.gd:13-21` (SLOTS), `core/models.gd` `_dress` (~line 150)
- Modify: `core/placeholders.gd` (constants near line 44, `make()` near line 339, new builders after `_lantern()`)
- Modify: `tests/test_models.gd:9-34,84-100,120-140`
- Modify: `tools/blender_export.py:29-120` (LIMITS, EXACT)
- Modify: `tools/build_models.sh`, `.gitignore`, `docs/art/blender-contract.md`, `assets/models/README.md`

**Interfaces:**
- Produces: slots `deck`, `pier_post`, `boulder`, `bush`, `daisy`, `tuft`, `signpost` through `Models.instance(slot)`; `Placeholders.PEG_SEAT` (0.09), `Placeholders.WELL_DEPTH` (0.03). Layer and material names as in the table below; Tasks 4, 5, 6, 7 and 8 rely on them.

| slot | layers (node → material) | footprint | height |
|---|---|---|---|
| `deck` | `Deck_Planks` → `Deck` | exactly 1.0 along X, up to 1.0 along Z | 0.6 |
| `pier_post` | `Pier_Body` → `Bark` | 0.4 x 0.4 | 2.1 |
| `boulder` | `Rock_Body` → `Rock`, `Rock_Moss` → `Moss_flat` | 1.0 x 1.0 | 0.6 |
| `bush` | `Bush_Leaves` → `Leaf` | 1.0 x 1.0 | 0.7 |
| `daisy` | `Daisy_Petals` → `Petal_flat`, `Daisy_Centre` → `Centre_flat`, `Daisy_Stem` → `Stem_flat` | 0.3 x 0.3 | 0.25 |
| `tuft` | `Tuft_Blades` → `Grass_sway_flat` | 0.3 x 0.3 | 0.25 |
| `signpost` | `Sign_Post` → `Bark`, `Sign_Board` → `Timber`, `Sign_Paper` → `Paper_flat`, `Sign_Words` → `Ink_flat` | 1.4 x 0.4 | 1.8 |

(The daisy has three layers, not the spec's two: a flower needs a stem to reach the ground, and the contract wants every base at Z = 0. Record this as an amendment in Task 10.)

- [ ] **Step 1: Extend the slot list**

In `core/models.gd`, change the last line of `SLOTS` from

```gdscript
	"snake_head", "burrow"]
```

to

```gdscript
	"snake_head", "burrow",
	"deck", "pier_post", "boulder", "bush", "daisy", "tuft", "signpost"]
```

- [ ] **Step 2: Add the placeholder constants**

In `core/placeholders.gd`, after `const KNOB_H := 0.08` (line 61), add:

```gdscript
## The socket's well is a real recess WELL_DEPTH deep (spec 2026-09-15,
## section 1), so a peg seats that far below the socket's top.
const WELL_DEPTH := 0.03
const PEG_SEAT := SOCKET_H - WELL_DEPTH
## Code Break's screen: the plank deck the board is laid on and the scenery
## around it (spec 2026-09-15, sections 1 and 2).
const DECK_H := PLATFORM_H
const DECK_PLANK_W := 0.44
const DECK_GAP := 0.06
const PIER_R := 0.2
const PIER_H := 2.1
const BOULDER_W := 0.9
const BOULDER_H := 0.6
const BUSH_R := 0.3
const DAISY_R := 0.15
const DAISY_H := 0.25
const TUFT_H := 0.25
const SIGN_POST_H := 1.8
```

- [ ] **Step 3: Dispatch the new builders**

In `make()`, after `"burrow": return _burrow()`, add:

```gdscript
		"deck": return _deck()
		"pier_post": return _pier_post()
		"boulder": return _boulder()
		"bush": return _bush()
		"daisy": return _daisy()
		"tuft": return _tuft()
		"signpost": return _signpost()
```

- [ ] **Step 4: Write the seven builders**

Add after `_lantern()` in `core/placeholders.gd` (before `# --- Nonogram and One Line pieces ---`):

```gdscript
# --- Code Break's screen: the dock and the scenery ---

## One strip of deck, a cell deep, two planks side by side as one layer with
## a gap between them and half a gap at each edge, so the outline shells meet
## in the gaps and draw the seams. The board stretches it along X, so the
## planks run along X and nothing about the cross-section changes.
static func _deck() -> Node3D:
	var root := Node3D.new()
	root.name = "deck"
	var off := (DECK_PLANK_W + DECK_GAP) * 0.5
	root.add_child(_layer("Deck_Planks", _merge([
		{"mesh": _bar(1.0, DECK_PLANK_W, DECK_H), "xform": Transform3D(Basis(), Vector3(0.0, 0.0, -off))},
		{"mesh": _bar(1.0, DECK_PLANK_W, DECK_H), "xform": Transform3D(Basis(), Vector3(0.0, 0.0, off))},
	]), "Deck", Pal.DECK, Vector3.ZERO))
	Toon.apply_to(root)
	return root

## A round log with a rounded top: the posts at the deck's far edge, which
## stand in the river and reach above the deck.
static func _pier_post() -> Node3D:
	var root := Node3D.new()
	root.name = "pier_post"
	var shaft := PIER_H - PIER_R
	root.add_child(_layer("Pier_Body", _merge([
		{"mesh": _cylinder(PIER_R, shaft, 16), "xform": Transform3D(Basis(), Vector3(0.0, shaft * 0.5, 0.0))},
		{"mesh": _ball(PIER_R), "xform": Transform3D(Basis(), Vector3(0.0, shaft, 0.0))},
	]), "Bark", Pal.BARK, Vector3.ZERO))
	Toon.apply_to(root)
	return root

## A rounded stone with a moss cap. The rock is the tinted layer; the moss is
## flat so it reads as a patch, not a second stone.
static func _boulder() -> Node3D:
	var root := Node3D.new()
	root.name = "boulder"
	var r := BOULDER_H * 0.5
	var squash := Basis().scaled(Vector3(BOULDER_W * 0.5 / r, 1.0, BOULDER_W * 0.425 / r))
	root.add_child(_layer("Rock_Body", _merge([{"mesh": _ball(r),
		"xform": Transform3D(squash, Vector3(0.0, r, 0.0))}]),
		"Rock", Pal.BOULDER, Vector3.ZERO))
	root.add_child(_layer("Rock_Moss", _cylinder(BOULDER_W * 0.28, 0.01, 16), "Moss_flat", Pal.MOSS,
		Vector3(0.0, BOULDER_H - 0.02, 0.0)))
	Toon.apply_to(root)
	return root

## Five leaf blobs as one layer; the lowest touches the ground.
static func _bush() -> Node3D:
	var root := Node3D.new()
	root.name = "bush"
	var blobs: Array = []
	for p in [Vector3(0.0, 0.4, 0.0), Vector3(-0.18, 0.3, 0.1), Vector3(0.18, 0.3, -0.12),
			Vector3(0.05, 0.32, 0.18), Vector3(-0.08, 0.3, -0.18)]:
		blobs.append({"mesh": _ball(BUSH_R), "xform": Transform3D(Basis(), p)})
	root.add_child(_layer("Bush_Leaves", _merge(blobs), "Leaf", Pal.LEAF, Vector3.ZERO))
	Toon.apply_to(root)
	return root

## Eight petals round a sun-coloured centre on a thin green stem. All three
## layers are flat: a petal is thinner than an outline shell.
static func _daisy() -> Node3D:
	var root := Node3D.new()
	root.name = "daisy"
	var petals: Array = []
	var head_y := DAISY_H - 0.02
	for i in 8:
		var a := TAU * i / 8.0
		var out := Vector3(cos(a), 0.0, sin(a)) * DAISY_R * 0.6
		petals.append({"mesh": _cylinder(DAISY_R * 0.4, 0.01, 10),
			"xform": Transform3D(Basis(), out + Vector3(0.0, head_y, 0.0))})
	root.add_child(_layer("Daisy_Petals", _merge(petals), "Petal_flat", Pal.MOON, Vector3.ZERO))
	root.add_child(_layer("Daisy_Centre", _cylinder(DAISY_R * 0.3, 0.02, 10), "Centre_flat", Pal.SUN,
		Vector3(0.0, head_y + 0.01, 0.0)))
	root.add_child(_layer("Daisy_Stem", _cylinder(0.012, head_y, 8), "Stem_flat", Pal.LEAF,
		Vector3(0.0, head_y * 0.5, 0.0)))
	Toon.apply_to(root)
	return root

## Three grass blades as one swaying layer; the scenery scatters hundreds of
## these as one MultiMesh.
static func _tuft() -> Node3D:
	var root := Node3D.new()
	root.name = "tuft"
	var blades: Array = []
	for i in 3:
		var a := TAU * i / 3.0
		blades.append({"mesh": _bar(0.06, 0.02, TUFT_H),
			"xform": Transform3D(Basis(Vector3.UP, a), Vector3(cos(a), 0.0, sin(a)) * 0.06)})
	root.add_child(_layer("Tuft_Blades", _merge(blades), "Grass_sway_flat", Pal.TURF_TREE, Vector3.ZERO))
	Toon.apply_to(root)
	return root

## A post with an arm, a plank hanging from it, a sheet of paper on the plank
## and the words on the paper. The footprint is centred on the origin, as the
## exporter demands of the model: post at the left end, plank reaching right.
static func _signpost() -> Node3D:
	var root := Node3D.new()
	root.name = "signpost"
	root.add_child(_layer("Sign_Post", _merge([
		{"mesh": _bar(0.12, 0.12, SIGN_POST_H), "xform": Transform3D(Basis(), Vector3(-0.64, 0.0, 0.0))},
		{"mesh": _bar(1.28, 0.08, 0.08), "xform": Transform3D(Basis(), Vector3(0.0, SIGN_POST_H - 0.08, 0.0))},
	]), "Bark", Pal.BARK, Vector3.ZERO))
	root.add_child(_layer("Sign_Board", _bar(1.0, 0.06, 0.7), "Timber", Pal.TIMBER, Vector3(0.2, 0.9, 0.0)))
	root.add_child(_layer("Sign_Paper", _bar(0.86, 0.01, 0.56), "Paper_flat", Pal.PARCHMENT, Vector3(0.2, 0.97, 0.035)))
	root.add_child(_layer("Sign_Words", _bar(0.6, 0.01, 0.3), "Ink_flat", Pal.TEXT, Vector3(0.2, 1.1, 0.045)))
	Toon.apply_to(root)
	return root
```

`_ball` and `_bar` already exist in this file (`_ball` near line 675, `_bar` near line 969); `_layer`, `_merge`, `_cylinder` too.

- [ ] **Step 5: Dress the new slots and the lid**

In `core/models.gd` `_dress`, add cases inside the `match slot:` block, after the `"plinth"` case:

```gdscript
		"lid":
			# From above the knob has to read as the dark hole in the concept's
			# lids, not a pale wooden stud; the model keeps its own colour.
			tint_named(node, "Knob", Pal.BARK)
		"deck":
			# A strip laid on the bank casts into a 0.1 gap nobody sees.
			set_shadow_off_named(node, "Deck")
		"boulder":
			set_shadow_off_named(node, "Moss_flat")
		"daisy":
			set_shadow_off_named(node, "Petal_flat")
			set_shadow_off_named(node, "Centre_flat")
			set_shadow_off_named(node, "Stem_flat")
		"signpost":
			set_shadow_off_named(node, "Paper_flat")
			set_shadow_off_named(node, "Ink_flat")
```

`core/models.gd` does not yet preload the palette; add near the top, after `const Placeholders = preload(...)`:

```gdscript
const Pal = preload("res://core/palette.gd")
```

- [ ] **Step 6: Teach the model test the new slots**

In `tests/test_models.gd`:

`HEIGHT_BUDGET`: change the last entry line to

```gdscript
	"horse": 0.9, "fence": 0.5, "apple": 0.45, "snake_head": 0.5, "burrow": 0.14,
	"deck": 0.62, "pier_post": 2.1, "boulder": 0.6, "bush": 0.7, "daisy": 0.25,
	"tuft": 0.25, "signpost": 1.8}
```

`FOOTPRINT`: change the last line to

```gdscript
	"snake_head": Vector2(0.9, 0.9),
	"pier_post": Vector2(0.4, 0.4), "daisy": Vector2(0.3, 0.3), "tuft": Vector2(0.3, 0.3),
	"signpost": Vector2(1.4, 0.4)}
```

`LAYERS`: change the last line to

```gdscript
	"snake_head": ["Eye_flat", "Scale"], "burrow": ["Earth", "Hole_flat"],
	"deck": ["Deck"], "pier_post": ["Bark"], "boulder": ["Moss_flat", "Rock"],
	"bush": ["Leaf"], "daisy": ["Centre_flat", "Petal_flat", "Stem_flat"],
	"tuft": ["Grass_sway_flat"], "signpost": ["Bark", "Ink_flat", "Paper_flat", "Timber"]}
```

Do **not** touch `"peg"` in `LAYERS` yet: `Models.instance("peg")` loads the export, which gains its shine only in Task 8.

In `_test_slots`, the expected `SLOTS` literal: change its last line to

```gdscript
		"snake_head", "burrow",
		"deck", "pier_post", "boulder", "bush", "daisy", "tuft", "signpost"],
```

The `outlined` dictionary in the same function: change its last line to

```gdscript
			"apple": ["Fruit"], "snake_head": ["Scale"], "burrow": ["Earth"],
			"deck": ["Deck"], "pier_post": ["Bark"], "boulder": ["Rock"], "bush": ["Leaf"],
			"daisy": [], "tuft": [], "signpost": ["Bark", "Timber"]}.get(slot, [])
```

- [ ] **Step 7: Run the suite**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`
Expected: no FAIL lines, `failed=0`. If a new slot fails "base sits at y=0" or "fits a footprint", fix the placeholder's numbers, not the test.

- [ ] **Step 8: Exporter budgets and the build script**

In `tools/blender_export.py`, add to `LIMITS` after the `"burrow"` line:

```python
    # Code Break's screen (docs/superpowers/specs/2026-09-15-codebreak-screen-design.md):
    # the deck strip the board is laid on -- exactly a cell long because the
    # board stretches it along X, and tiled edge to edge along Y with half a
    # gap at each edge, so its depth is budgeted, not exact -- and the
    # scenery around it. The signpost is wider than a cell on purpose: the
    # plank hangs from an arm beside the post.
    "deck": (1.0, 1.0, 0.62),
    "pier_post": (0.4, 0.4, 2.1),
    "boulder": (1.0, 1.0, 0.6),
    "bush": (1.0, 1.0, 0.7),
    "daisy": (0.3, 0.3, 0.25),
    "tuft": (0.3, 0.3, 0.25),
    "signpost": (1.4, 0.4, 1.8),
```

Change the `EXACT` line to end with `"fence": (1.0, None), "deck": (1.0, None)}`.

In `tools/build_models.sh`, before the `if ! godot --headless` line, add:

```sh
# Code Break's screen: the deck strip and six scenery pieces, modelled in the
# live session into one .blend.
"$BLENDER" -b art/scenery.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Deck Pier_Post Boulder Bush Daisy Tuft Signpost
```

In `.gitignore`, after the `!art/snake.blend` line, add:

```
# Code Break's screen: the deck strip and the scenery around the dock.
!art/scenery.blend
```

- [ ] **Step 9: Document the slots**

In `docs/art/blender-contract.md`, add rows to the slot table before the `mascot_<name>` row:

```markdown
| `deck` | **exactly 1.0** x up to 1.0 | 0.6 | one strip of Code Break's dock, running along X: `Deck_Planks` (`Deck`), two planks side by side as one layer with a 0.06 gap between them and 0.03 at each edge, so the outline shells meet in the gaps and draw the seams. The board stretches it along X and lays one per unit of depth, edge to edge |
| `pier_post` | 0.4 x 0.4 | 2.1 | a round log with a rounded top, `Pier_Body` (`Bark`); stands in the river at the deck's far edge and reaches above the deck |
| `boulder` | 1.0 x 1.0 | 0.6 | a rounded stone beside the deck: `Rock_Body` (`Rock`) and `Rock_Moss` (`Moss_flat`), a cap on top. Placed at varied yaw and scale, one flattened as POM's seat |
| `bush` | 1.0 x 1.0 | 0.7 | `Bush_Leaves` (`Leaf`), four or five overlapping blobs as one layer, the lowest touching the ground |
| `daisy` | 0.3 x 0.3 | 0.25 | `Daisy_Petals` (`Petal_flat`), `Daisy_Centre` (`Centre_flat`), `Daisy_Stem` (`Stem_flat`); all flat, a petal being thinner than an outline shell |
| `tuft` | 0.3 x 0.3 | 0.25 | `Tuft_Blades` (`Grass_sway_flat`), three blades as one layer; the scenery scatters it as one MultiMesh, and the wind shader sways each instance |
| `signpost` | 1.4 x 0.4 | 1.8 | a post with an arm at the **left** end, `Sign_Post` (`Bark`); a plank hanging from the arm, `Sign_Board` (`Timber`); `Sign_Paper` (`Paper_flat`) on the plank's face, on Blender **-Y** (Godot +Z); `Sign_Words` (`Ink_flat`), the words as mesh on the paper. Wider than a cell on purpose; the footprint is still centred on the origin |
```

In `assets/models/README.md`, add rows to the table:

```markdown
| `deck` | one strip of Code Break's dock along X, `Deck` planks with a seam gap; the board stretches it |
| `pier_post` | a log at the deck's far edge, `Bark`, standing in the river |
| `boulder` | a rock beside the deck: `Rock` body, `Moss_flat` cap |
| `bush` | a cluster of leaf blobs, `Leaf` |
| `daisy` | a flower on the bank: `Petal_flat`, `Centre_flat`, `Stem_flat` |
| `tuft` | three grass blades, `Grass_sway_flat`, scattered as one MultiMesh |
| `signpost` | the hanging sign: `Bark` post, `Timber` plank, `Paper_flat` sheet, `Ink_flat` words |
```

- [ ] **Step 10: Run the suite once more and commit**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -1` → `failed=0`.

```bash
git add core/models.gd core/placeholders.gd tests/test_models.gd tools/blender_export.py tools/build_models.sh .gitignore docs/art/blender-contract.md assets/models/README.md
git commit -m "feat(models): seven scenery slots for Code Break's dock, placeholders first

deck, pier_post, boulder, bush, daisy, tuft and signpost, each with a
primitive placeholder carrying the layer names the contract fixes, the
exporter's budgets, the build line and the docs, so the board can be
built and tested before the art lands. The lid's knob goes bark so it
reads as a hole from above, and the peg's seat moves 0.03 down into the
socket's coming recess."
```

---

### Task 4: Scenery helpers and the platform's slab argument

**Files:**
- Create: `world/scenery.gd`
- Modify: `core/platform.gd:19-26`

**Interfaces:**
- Consumes: `Models.instance(slot)`, `Models.meshes(root)`, `Toon.material(colour)`, `Toon.water()`, `Placeholders.PLATFORM_H`.
- Produces:
  - `Platform.build(cols: int, rows: int, slab := "platform") -> Node3D` (`""` lays the rim alone)
  - `Scenery.ground(size: Vector3, centre: Vector3, colour: Color) -> MeshInstance3D`
  - `Scenery.water(size: Vector2, centre: Vector3) -> MeshInstance3D`
  - `Scenery.deck(x0: float, x1: float, z0: float, z1: float) -> Node3D` (named `Deck`, strips named `deck_<i>`)
  - `Scenery.prop(slot: String, at: Vector3, yaw := 0.0, scale := Vector3.ONE) -> Node3D` (a pivot named `<slot>` at `at` turned by `yaw`, holding the scaled model as its only child)
  - `Scenery.scatter(slot: String, transforms: Array[Transform3D]) -> MultiMeshInstance3D`

- [ ] **Step 1: The platform's optional slab**

In `core/platform.gd`, change the signature and the slab block:

```gdscript
## `slab` is the model stretched under the rim; "" lays the rim alone, for a
## board that brings its own floor (Code Break's plank deck).
static func build(cols: int, rows: int, slab := "platform") -> Node3D:
	var root := Node3D.new()
	root.name = "Platform"

	if slab != "":
		var slab_node := Models.instance(slab)
		slab_node.name = "Slab"
		slab_node.scale = Vector3(cols + 2.0 * LIP, 1.0, rows + 2.0 * LIP)
		slab_node.position = Vector3(0.0, -Placeholders.PLATFORM_H, 0.0)
		root.add_child(slab_node)
```

The rest of the function is unchanged.

- [ ] **Step 2: Write the helpers**

Create `world/scenery.gd`:

```gdscript
extends RefCounted

## Pieces a board dresses its surroundings with: a slab of ground, a sheet
## of water, a run of deck strips, a placed prop and a scattered MultiMesh.
## Pure node building with no board knowledge, so it runs headless and any
## board can use it. Code Break composes these in
## puzzles/codebreak_scenery.gd.
## Spec: docs/superpowers/specs/2026-09-15-codebreak-screen-design.md, sections 2 and 7.

const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Toon = preload("res://core/toon.gd")

## A box of ground in one toon colour, centred at `centre`. No outline: a
## forty-unit box's shell would draw a dark band along the horizon. Casts no
## shadow (nothing stands under the ground) but receives them.
static func ground(size: Vector3, centre: Vector3, colour: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = box
	mi.material_override = Toon.material(colour)
	mi.position = centre
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## A sheet of the stage's own water, so a splash rings it. `size` is x by z.
static func water(size: Vector2, centre: Vector3) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = plane
	mi.material_override = Toon.water()
	mi.position = centre
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## A run of `deck` strips with their tops at y = 0, covering x from `x0` to
## `x1` and z from `z0` to `z1`: one strip per unit of z, each stretched
## along x. The strip is modelled exactly one unit long so the stretch is a
## plain scale, and its planks run along x so nothing about their
## cross-section changes.
static func deck(x0: float, x1: float, z0: float, z1: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Deck"
	var strips := int(roundf(z1 - z0))
	for i in strips:
		var strip := Models.instance("deck")
		strip.name = "deck_%d" % i
		strip.position = Vector3((x0 + x1) * 0.5, -Placeholders.PLATFORM_H, z0 + 0.5 + i)
		strip.scale.x = x1 - x0
		root.add_child(strip)
	return root

## One library model at `at`, turned `yaw` about Y and scaled, under a pivot.
## The pivot carries position and yaw and the model the scale, so an
## entrance can pop the pivot from nothing to one without disturbing a
## prop's own size.
static func prop(slot: String, at: Vector3, yaw := 0.0, scale := Vector3.ONE) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = slot
	pivot.position = at
	pivot.rotation.y = yaw
	var model := Models.instance(slot)
	model.scale = scale
	pivot.add_child(model)
	return pivot

## Every instance of `slot`'s first layer as one MultiMesh: one draw call for
## a whole meadow of tufts. The mesh and its toon (or wind) material come
## from a throwaway instance of the model, so the scatter matches a placed
## prop exactly, placeholder or export.
static func scatter(slot: String, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var sample := Models.instance(slot)
	var layers := Models.meshes(sample)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mmi := MultiMeshInstance3D.new()
	mmi.name = slot + "_field"
	if not layers.is_empty():
		var mi: MeshInstance3D = layers[0]
		mm.mesh = mi.mesh
		var mat: Material = mi.get_surface_override_material(0)
		if mat != null:
			mmi.material_override = mat
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sample.free()
	return mmi
```

- [ ] **Step 3: Probe it headless (throwaway)**

Create `tests/_probe_scenery.gd`:

```gdscript
extends SceneTree
## Throwaway: the helpers build what they say, headless.
const Scenery = preload("res://world/scenery.gd")
const Platform = preload("res://core/platform.gd")
func _initialize() -> void:
	var rim: Node3D = Platform.build(5, 9, "")
	print("rim only, no Slab: ", rim.get_node_or_null("Slab") == null, " children=", rim.get_child_count())
	var full: Node3D = Platform.build(5, 9)
	print("default keeps Slab: ", full.get_node_or_null("Slab") != null)
	var d: Node3D = Scenery.deck(-4.0, 4.0, -6.0, 7.0)
	print("deck strips=", d.get_child_count(), " (want 13) first=", d.get_child(0).position, " scale.x=", d.get_child(0).scale.x, " last z=", d.get_child(12).position.z)
	var p: Node3D = Scenery.prop("boulder", Vector3(4.6, -0.7, -3.2), -0.4, Vector3(1.4, 0.7, 1.4))
	print("prop pivot=", p.name, " at ", p.position, " child scale=", p.get_child(0).scale)
	var xf: Array[Transform3D] = []
	for i in 5:
		xf.append(Transform3D(Basis(), Vector3(i, 0, 0)))
	var s: MultiMeshInstance3D = Scenery.scatter("tuft", xf)
	print("scatter count=", s.multimesh.instance_count, " mesh=", s.multimesh.mesh != null, " material=", s.material_override)
	var g := Scenery.ground(Vector3(40, 1.1, 21.8), Vector3(0, -1.25, 5.1), Color.GREEN)
	print("ground size=", (g.mesh as BoxMesh).size, " shadow=", g.cast_shadow)
	var w := Scenery.water(Vector2(40, 40), Vector3(0, -1.4, 0))
	print("water material is the shared one: ", w.material_override != null)
	quit()
```

Run: `godot --headless --path . --script res://tests/_probe_scenery.gd 2>&1 | grep -v "^$"`
Expected: `rim only, no Slab: true children=32` (28 edges plus 4 corners), `default keeps Slab: true`, `deck strips=13 ... first=(0, -0.6, -5.5) scale.x=8 last z=6.5`, `prop pivot=boulder ... child scale=(1.4, 0.7, 1.4)`, `scatter count=5 mesh=true material=<ShaderMaterial...>`, `ground ... shadow=0`, `water ... true`.

Then delete the probe: `rm tests/_probe_scenery.gd tests/_probe_scenery.gd.uid`.

- [ ] **Step 4: Run the suite and commit**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -1` → `failed=0` (the platform test's default call is untouched).

```bash
git add world/scenery.gd core/platform.gd
git commit -m "feat(world): scenery helpers -- ground, water, deck strips, props, a scattered field

Pure node builders any board can dress its surroundings with, and a
platform that can lay its rim alone for a board bringing its own floor."
```

---

### Task 5: The board on its dock

**Files:**
- Create: `puzzles/codebreak_scenery.gd` (the `dock()` half; `build()` comes in Task 6)
- Modify: `puzzles/codebreak3d.gd`

**Interfaces:**
- Consumes: `Platform.build(cols, rows, "")`, `Scenery.deck(...)`, `Placeholders.PEG_SEAT`.
- Produces: `CodebreakScenery.dock(cols: int, rows: int) -> Node3D` named `Dock`, holding `Platform` (rim only) and `Deck`; constants `DECK_APRON`, `DECK_FAR`, `DECK_NEAR`.

- [ ] **Step 1: The dock builder**

Create `puzzles/codebreak_scenery.gd`:

```gdscript
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
```

- [ ] **Step 2: Wire the dock into the board**

In `puzzles/codebreak3d.gd`:

Add after `const Stage = preload("res://world/stage.gd")`:

```gdscript
const CodebreakScenery = preload("res://puzzles/codebreak_scenery.gd")
```

Change `const LID_SLIDE := 1.3` to `const LID_SLIDE := 2.7` and replace

```gdscript
const LID_FALL := Stage.WATER_DEPTH   # the lid sinks to the water
```

with

```gdscript
## Deck top to the river's surface: a lid that slides off falls this far.
const RIVER_DROP := 1.4
const LID_FALL := RIVER_DROP
## Where the entrance splash rings the river, in board space.
const SPLASH_AT := Vector3(0.0, 0.0, -7.0)
```

Change `board_height()` to

```gdscript
func board_height() -> float: return Placeholders.PEG_SEAT + Placeholders.PEG_H + FRAME_SLACK
```

In `_build_scene`, replace

```gdscript
	var size := board_size()
	board.add_child(Platform.build(size.x, size.y))
```

with

```gdscript
	var size := board_size()
	board.add_child(CodebreakScenery.dock(size.x, size.y))
```

Every peg seat moves from `Placeholders.SOCKET_H` to `Placeholders.PEG_SEAT`. There are exactly these occurrences; change each:

- `pick()`: `peg.position.y = Placeholders.SOCKET_H` and the `Motion.hop(... , Placeholders.SOCKET_H)` base on the next line.
- `_place()`: `peg.position = Vector3(0.0, Placeholders.SOCKET_H + PLACE_DROP, 0.0)` and `Motion.settle(peg, "position:y", Placeholders.SOCKET_H, ...)`.
- `_on_peg_landed()`: `fx.puff(_cell(g, s, Placeholders.SOCKET_H))`.
- `_settle()`: `peg.position.y = Placeholders.SOCKET_H`.
- `_on_solved()`: `peg.position.y = Placeholders.SOCKET_H` and the `Motion.hop(peg, SOLVE_HOP, SOLVE_TIME, ..., Placeholders.SOCKET_H)` base.

Leave `plane_height()` (taps land on the socket's top), the pip heights (`Placeholders.SOCKET_H + Placeholders.WELL_PROUD`) and the sparkle heights (`Placeholders.SOCKET_H + SPARKLE_LIFT`) as they are.

In `_enter`, change

```gdscript
	var platform: Node3D = board.get_node("Platform")
	platform.position.y = -ENTER_DROP
	var rise: Tween = Motion.settle(platform, "position:y", 0.0, ENTER_PLATFORM)
```

to

```gdscript
	var dock: Node3D = board.get_node("Dock")
	dock.position.y = -ENTER_DROP
	var rise: Tween = Motion.settle(dock, "position:y", 0.0, ENTER_PLATFORM)
```

In `_stop_entrance`, change

```gdscript
	var platform: Node3D = board.get_node_or_null("Platform")
	if platform != null:
		platform.position.y = 0.0
```

to

```gdscript
	var dock: Node3D = board.get_node_or_null("Dock")
	if dock != null:
		dock.position.y = 0.0
```

In `_splash`, change `_stage.splash(board.global_position)` to `_stage.splash(board.to_global(SPLASH_AT))`.

Update the file's header comment: "Eight guess rows of socket slabs stand on the platform" becomes "Eight guess rows of socket slabs stand on a plank dock", and "the lids slide off the far edge into the sea" becomes "the lids slide off the far edge into the river". Add the new spec to the header's `Spec:` line: `docs/superpowers/specs/2026-09-15-codebreak-screen-design.md` for the dock and scenery.

- [ ] **Step 3: Run the suite, the win harness and the shot**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -1` → `failed=0`.
Run: `godot --path . --resolution 1080x1920 --script res://tests/_win.gd 2>&1 | grep -E "mastermind|winnable"`
Expected: a `mastermind` line with `cracked in 1 guesses, camera fit=true`, and `winnable=12/12` (or the current total; not `0/0`).
Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd 2>&1 | grep mastermind`, open `/tmp/shot_mastermind.png`. Check: the board sits on a wide brown strip deck (placeholder planks, seams visible as dark lines between strips), the moss rim is where it was, the deck runs one cell past the rim on each side, one at the top and two at the bottom, the sea is still blue around it.

- [ ] **Step 4: Commit**

```bash
git add puzzles/codebreak_scenery.gd puzzles/codebreak3d.gd
git commit -m "feat(codebreak): the board is laid on a plank dock

The rim now stands on a run of stretched deck strips that reach past it
on every side, the dock rises as one on the entrance, the lids slide far
enough to clear its far edge and fall to a river's depth, and pegs seat
into the socket's coming recess."
```

---

### Task 6: The scenery around the dock

**Files:**
- Modify: `puzzles/codebreak_scenery.gd` (add `build()`)
- Modify: `puzzles/codebreak3d.gd` (`_build_scene`, `_enter`, `_stop_entrance`, `_stop_all`, `_on_solved`, `reset_board`)

**Interfaces:**
- Consumes: `Scenery.ground/water/prop/scatter`, `Models.tint_named`, `Motion.pulse/hop/settle/stagger/stop`.
- Produces: `CodebreakScenery.build(cols: int) -> Dictionary` with `"root": Node3D` (named `Scenery`), `"props": Array[Node3D]` (pivots that pop in, in entrance order) and `"pom": Node3D` (the POM pivot, or null when no such model loads); `CodebreakScenery.POM_REST_Y`.

- [ ] **Step 1: The scenery table and builder**

Append to `puzzles/codebreak_scenery.gd`:

```gdscript

# --- the bank, the river and the props (spec section 2) ---

## The turf bank the dock is laid on, 0.1 below the deck's underside, and the
## river beyond its far edge.
const BANK_TOP := -0.7
const BANK_BOTTOM := -1.8
const BANK_WIDTH := 40.0
const BANK_NEAR_END := 16.0
const BANK_FAR_END := -30.0
const RIVER_Y := -1.4
const RIVER_NEAR := -5.8   # the near bank ends here, 0.2 short of the deck's far edge
const RIVER_FAR := -10.0   # the far bank starts here
const RIVER_SIZE := 40.0
## Pier posts stand in the river under the deck's far edge, clear of every
## lid's slide path at both board widths.
const POST_Z := -5.7
const POST_Y := -1.6
const POSTS_X := [-3.8, -2.7, 2.7, 3.8]
## The prop tables are laid for a five-column board; wider boards push every
## x outward by half a unit per extra column.
const REF_COLS := 5
## [x, z, yaw, scale] per boulder; two of them are seats.
const BOULDERS := [
	[-4.4, -4.6, 0.3, 1.3], [-5.3, -3.4, 1.2, 0.9], [-4.6, 0.5, 2.0, 1.0],
	[-4.5, 2.8, 0.7, 1.5], [-5.4, 4.6, 2.6, 1.1],
	[4.6, -3.2, -0.4, 1.4], [5.5, -4.6, 1.7, 1.0], [4.4, -0.6, 0.9, 1.2],
	[4.5, 1.8, 2.3, 1.6], [5.3, 4.2, 0.2, 0.9],
]
const SEAT_LANTERN := 2   # index into BOULDERS
const SEAT_POM := 5       # index into BOULDERS; flattened to 0.7 of its height
const SEAT_POM_FLAT := 0.7
const BUSHES := [
	[-5.6, -5.4, 0.4, 1.2], [5.8, -5.3, 1.1, 1.1], [-5.6, -1.4, 2.2, 1.0],
	[5.9, 0.6, 0.6, 1.3], [-5.2, 6.2, 1.5, 1.4], [5.4, 6.4, 2.8, 1.3],
	[-2.0, -10.6, 0.9, 1.5], [4.0, -10.5, 2.0, 1.3],
]
const DAISIES := [
	[-4.3, -2.0, 0.0, 1.0], [-4.3, 1.6, 0.8, 1.2], [-5.0, 3.6, 1.6, 1.0],
	[-4.4, 5.8, 2.4, 1.3], [4.3, -1.9, 0.4, 1.1], [4.2, 0.7, 1.2, 1.0],
	[4.9, 3.2, 2.0, 1.2], [4.4, 5.6, 2.8, 1.0], [-5.6, -2.6, 0.6, 1.1], [5.7, 2.8, 1.4, 1.3],
]
const TREES := [
	[-5.5, -11.0, 0.3, 1.2], [-2.5, -10.9, 1.4, 1.0], [0.5, -11.3, 2.5, 1.3],
	[3.0, -10.8, 0.8, 1.1], [6.0, -11.1, 1.9, 1.2],
]
const SIGN := [-4.7, -2.5, 0.44, 1.0]
const LANTERN_SCALE := 1.5
const POM_SCALE := 1.2
const POM_YAW := -0.52   # about 30 degrees, face toward the board on its left
## A boulder's top at scale s is BANK_TOP + BOULDER_H * s; POM's seat is
## flattened, so this is where its pivot rests.
const POM_REST_Y := BANK_TOP + Placeholders.BOULDER_H * SEAT_POM_FLAT
const TUFT_COUNT := 200
const TUFT_SEED := 20260915

## Everything around the dock: the banks and river, the props in entrance
## order, and POM. `cols` widens the prop tables for the five-slot board.
static func build(cols: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "Scenery"
	var props: Array[Node3D] = []
	var dx := (cols - REF_COLS) * 0.5

	var bank_h := BANK_TOP - BANK_BOTTOM
	var bank_y := (BANK_TOP + BANK_BOTTOM) * 0.5
	root.add_child(Scenery.ground(Vector3(BANK_WIDTH, bank_h, BANK_NEAR_END - RIVER_NEAR),
		Vector3(0.0, bank_y, (BANK_NEAR_END + RIVER_NEAR) * 0.5), Pal.BANK))
	var far := Scenery.ground(Vector3(BANK_WIDTH, bank_h, RIVER_FAR - BANK_FAR_END),
		Vector3(0.0, bank_y, (RIVER_FAR + BANK_FAR_END) * 0.5), Pal.BANK)
	far.name = "FarBank"
	root.add_child(far)
	root.add_child(Scenery.water(Vector2(RIVER_SIZE, RIVER_SIZE), Vector3(0.0, RIVER_Y, 0.0)))
	root.add_child(Scenery.scatter("tuft", _tuft_transforms(cols)))

	for x in POSTS_X:
		props.append(_prop(root, "pier_post", Vector3(_spread(x, dx), POST_Y, POST_Z), 0.0, 1.0))
	for i in BOULDERS.size():
		var b: Array = BOULDERS[i]
		var scale := Vector3.ONE * float(b[3])
		if i == SEAT_POM:
			scale.y *= SEAT_POM_FLAT
		props.append(_prop(root, "boulder", Vector3(_spread(b[0], dx), BANK_TOP, b[1]), b[2], 1.0, scale))
	for b in BUSHES:
		props.append(_prop(root, "bush", Vector3(_spread(b[0], dx), BANK_TOP, b[1]), b[2], b[3]))
	for d in DAISIES:
		props.append(_prop(root, "daisy", Vector3(_spread(d[0], dx), BANK_TOP, d[1]), d[2], d[3]))
	var lantern_seat: Array = BOULDERS[SEAT_LANTERN]
	var lantern := _prop(root, "lantern",
		Vector3(_spread(lantern_seat[0], dx), BANK_TOP + Placeholders.BOULDER_H * float(lantern_seat[3]), lantern_seat[1]),
		0.6, LANTERN_SCALE)
	Models.tint_named(lantern.get_child(0), "Glass", Pal.SUN)
	props.append(lantern)
	props.append(_prop(root, "signpost", Vector3(_spread(SIGN[0], dx), BANK_TOP, SIGN[1]), SIGN[2], SIGN[3]))
	for t in TREES:
		props.append(_prop(root, "tree", Vector3(_spread(t[0], dx), BANK_TOP, t[1]), t[2], t[3]))

	var pom: Node3D = null
	if Models.has_model("mascot_pom"):
		var seat: Array = BOULDERS[SEAT_POM]
		pom = _prop(root, "mascot_pom", Vector3(_spread(seat[0], dx), POM_REST_Y, seat[1]), POM_YAW, POM_SCALE)
	return {"root": root, "props": props, "pom": pom}

## Pushes an x outward for a wider board: props keep their distance from the
## deck's edge, not from the origin.
static func _spread(x: float, dx: float) -> float:
	return x + signf(x) * dx

static func _prop(root: Node3D, slot: String, at: Vector3, yaw: float, scale: float, scale3 := Vector3.ZERO) -> Node3D:
	var s := scale3 if scale3 != Vector3.ZERO else Vector3.ONE * scale
	var pivot := Scenery.prop(slot, at, yaw, s)
	root.add_child(pivot)
	return pivot

## Where the tufts stand: a seeded scatter over both banks, never under the
## deck or its shadow line, varied in yaw and size. The seed is fixed so the
## meadow is the same every day.
static func _tuft_transforms(cols: int) -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = TUFT_SEED
	var hx := cols * 0.5 + Platform.LIP + DECK_APRON + 0.25
	var out: Array[Transform3D] = []
	while out.size() < TUFT_COUNT:
		var far_bank := rng.randf() < 0.15
		var x := rng.randf_range(-7.0, 7.0)
		var z := rng.randf_range(RIVER_FAR - 1.6, RIVER_FAR - 0.2) if far_bank else rng.randf_range(RIVER_NEAR + 0.2, 9.0)
		if not far_bank and absf(x) < hx and z < 7.4:
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3))
		out.append(Transform3D(basis, Vector3(x, BANK_TOP, z)))
	return out
```

Note `Placeholders.BOULDER_H` exists from Task 3.

- [ ] **Step 2: Add the scenery to the board and animate it**

In `puzzles/codebreak3d.gd`:

Add constants after `const LOCKED_STAGGER := 0.05`:

```gdscript
## The scenery's entrance and POM's motion (spec 2026-09-15, sections 3 and 4).
const ENTER_PROPS := 0.3
const PROP_STAGGER := 0.03
const ENTER_POM := 0.9
const POM_BREATH := 0.03
const POM_PERIOD := 3.0
const POM_HOP := 0.15
const POM_HOP_TIME := 0.4
```

Add fields after `var _code_pegs: Array = []`:

```gdscript
var _props: Array[Node3D] = []   # scenery pivots that pop in on the entrance
var _pom: Node3D                 # POM's pivot, or null without the model
```

and after `var _entrance: Array = []`:

```gdscript
var _pom_tw: Tween            # the breath, on POM's model
var _pom_hop_tw: Tween        # the win hop, on POM's pivot
```

In `_stop_all`, after `_entrance = []`, add:

```gdscript
	Motion.stop(_pom_tw)
	Motion.stop(_pom_hop_tw)
	_pom_tw = null
	_pom_hop_tw = null
```

In `_build_scene`, after `board.add_child(CodebreakScenery.dock(size.x, size.y))`, add:

```gdscript
	var scene: Dictionary = CodebreakScenery.build(size.x)
	board.add_child(scene.root)
	_props = scene.props
	_pom = scene.pom
	if _pom != null:
		var model: Node3D = _pom.get_child(0)
		_pom_tw = Motion.pulse(model, "scale:y", model.scale.y, model.scale.y * (1.0 + POM_BREATH), POM_PERIOD)
```

In `_enter`, before `fx.cue("enter")`, add:

```gdscript
	for i in _props.size():
		_pop_in(_props[i], ENTER_PLATFORM + ENTER_PROPS + Motion.stagger(i, PROP_STAGGER))
	if _pom != null:
		_pop_in(_pom, ENTER_PLATFORM + ENTER_POM)
```

In `_stop_entrance`, after the dock block, add:

```gdscript
	for prop in _props:
		prop.scale = Vector3.ONE
	if _pom != null:
		_pom.scale = Vector3.ONE
```

In `_on_solved`, before `fx.cue("solved")`, add:

```gdscript
	if _pom != null:
		Motion.stop(_pom_hop_tw)
		_pom.position.y = CodebreakScenery.POM_REST_Y
		_pom_hop_tw = Motion.hop(_pom, POM_HOP, POM_HOP_TIME, 0.0, CodebreakScenery.POM_REST_Y)
```

In `reset_board`, after `_stop_entrance()`, add:

```gdscript
	if _pom != null:
		Motion.stop(_pom_hop_tw)
		_pom_hop_tw = null
		_pom.position.y = CodebreakScenery.POM_REST_Y
```

- [ ] **Step 3: Run the suite, the win harness and the shot**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -1` → `failed=0`.
Run: `godot --path . --resolution 1080x1920 --script res://tests/_win.gd 2>&1 | grep -E "mastermind|winnable"` → `camera fit=true`, `winnable=` not `0/0`.
Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd 2>&1 | grep mastermind`, open `/tmp/shot_mastermind.png`. Check: no blue sea anywhere; green bank around the dock; a blue river band behind the deck's far edge with four posts standing in it; grey placeholder boulders and green blobs along both sides; the lantern on a rock at the left, the placeholder sign left of the top rows, POM (the real model) on a flat rock right of the top rows facing left; trees along the top edge; tufts on the bank. Nothing overlaps the board's sockets. If a prop hides a socket, move it in the table, never the board.

Also check reduce-motion still works: nothing to run; `pulse` and `hop` are recipes that already honour it.

- [ ] **Step 4: Commit**

```bash
git add puzzles/codebreak_scenery.gd puzzles/codebreak3d.gd
git commit -m "feat(codebreak): a bank, a river and the props around the dock, with POM on a rock

The blue sea is gone: two turf banks and the shared water between them
as a river, pier posts, boulders, bushes, daisies, a field of tufts as
one MultiMesh, the lantern, the hanging sign and the far treeline, all
from a fixed table so the screen is the same every day. Props pop in
after the dock lands; POM breathes and hops on a win."
```

---

### Task 7: Blender: the seven scenery models

**Files:**
- Create: `art/scenery.blend` (tracked; un-ignored in Task 3)
- Create: `assets/models/{deck,pier_post,boulder,bush,daisy,tuft,signpost}.glb` (exported)

**Interfaces:**
- Consumes: the layer/material names from Task 3's table; `tools/blender_export.py` budgets from Task 3.
- Produces: the seven exports the game loads in place of the placeholders.

All modelling goes through `mcp__blender__execute_blender_code` against the live Blender. Every snippet must redefine its helpers. Take `mcp__blender__get_viewport_screenshot` after each model to check it. Blender is Z-up; Godot +Z is Blender -Y.

- [ ] **Step 1: A fresh file with seven collections**

```python
import bpy
bpy.ops.wm.read_homefile(use_empty=True)
for name in ["Deck", "Pier_Post", "Boulder", "Bush", "Daisy", "Tuft", "Signpost", "Scenery_Helpers"]:
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
bpy.ops.wm.save_as_mainfile(filepath="/Users/flavioriper/dev/daily/art/scenery.blend")
print([c.name for c in bpy.data.collections])
```

- [ ] **Step 2: Helpers to paste at the top of every snippet**

```python
import bpy, bmesh, math
from mathutils import Vector, Matrix

def lin(hexstr):
    c = [int(hexstr[i:i+2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple((v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in c) + (1.0,)

def mat(name, hexstr):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin(hexstr)
    return m

def into(obj, coll_name, name, material):
    """Name it, give it one material, move it into its collection alone, smooth it."""
    obj.name = name
    obj.data.name = name
    obj.data.materials.clear()
    obj.data.materials.append(material)
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    bpy.data.collections[coll_name].objects.link(obj)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj

def bevel(obj, width=0.02, segments=2):
    b = obj.modifiers.new("Bevel", "BEVEL")
    b.width = width
    b.segments = segments
    b.harden_normals = False
    b.limit_method = "ANGLE"

def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    j = bpy.context.view_layer.objects.active
    j.name = name
    return j

def apply_all(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def bounds(coll_name):
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in bpy.data.collections[coll_name].objects:
        for v in o.bound_box:
            w = o.matrix_world @ Vector(v)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    return lo, hi
```

Palette hex values (sRGB, convert with `lin`): DECK `b5825a`, BARK `8a6a4a`, BOULDER `9ba5ad`, MOSS `7fa84a`, LEAF `6ba845`, MOON `f6f1e6`, SUN `f5a623`, TURF_TREE `7fa550`, TIMBER `c49a63`, PARCHMENT `f3e9d2`, TEXT `3b3028`.

- [ ] **Step 3: Deck**

Two cubes 1.0 x 0.44 x 0.6 at y = ±0.25, joined into `Deck_Planks`, material `Deck`, bevel 0.02. The x extent must be exactly ±0.5 (the bevel does not move face planes).

```python
# (helpers)
planks = []
for y in (-0.25, 0.25):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, y, 0.3))
    o = bpy.context.active_object
    o.scale = (1.0, 0.44, 0.6)
    apply_all(o)
    planks.append(o)
deck = join(planks, "Deck_Planks")
into(deck, "Deck", "Deck_Planks", mat("Deck", "b5825a"))
bevel(deck)
print(bounds("Deck"))
bpy.ops.wm.save_mainfile()
```

Expected bounds: (-0.5, -0.47, 0) .. (0.5, 0.47, 0.6).

- [ ] **Step 4: Pier post**

```python
# (helpers)
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.2, depth=1.9, location=(0, 0, 0.95))
shaft = bpy.context.active_object
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.2, location=(0, 0, 1.9))
cap = bpy.context.active_object
post = join([shaft, cap], "Pier_Body")
into(post, "Pier_Post", "Pier_Body", mat("Bark", "8a6a4a"))
bevel(post, 0.015, 2)
print(bounds("Pier_Post"))
bpy.ops.wm.save_mainfile()
```

Expected: (-0.2, -0.2, 0) .. (0.2, 0.2, 2.1).

- [ ] **Step 5: Boulder**

Optionally try one BlenderKit rock first (`bpy.ops.scene.blenderkit_download(asset_base_id="91fcaade-b47e-43f2-920f-78ac3f6d97a2", model_location=(3,0,0), model_rotation=(0,0,0))`, inspect in the next call, keep one rock, decimate to under 600 faces, strip materials, scale to 0.9 x 0.76 x 0.6, base at Z = 0). If that takes more than two snippets to clean or the result is over 600 faces, delete it and use the hand-built rock:

```python
# (helpers)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.5, location=(0, 0, 0))
rock = bpy.context.active_object
rock.scale = (0.9, 0.76, 0.6)
apply_all(rock)
bm = bmesh.new(); bm.from_mesh(rock.data)
import random; random.seed(7)
for v in bm.verts:
    v.co += Vector((random.uniform(-0.03, 0.03), random.uniform(-0.03, 0.03), random.uniform(-0.02, 0.02)))
bm.to_mesh(rock.data); bm.free()
lo = min(v.co.z for v in rock.data.vertices)
for v in rock.data.vertices:
    v.co.z -= lo
hi = max(v.co.z for v in rock.data.vertices)
for v in rock.data.vertices:
    v.co.z *= 0.6 / hi
into(rock, "Boulder", "Rock_Body", mat("Rock", "9ba5ad"))
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.28, location=(0.02, -0.02, 0.55))
moss = bpy.context.active_object
moss.scale = (1.0, 0.9, 0.12)
apply_all(moss)
into(moss, "Boulder", "Rock_Moss", mat("Moss_flat", "7fa84a"))
print(bounds("Boulder"))
bpy.ops.wm.save_mainfile()
```

Expected: x within ±0.5, y within ±0.4, z 0 .. under 0.6. If the moss's top passes 0.6, lower it.

- [ ] **Step 6: Bush**

```python
# (helpers)
blobs = []
for (x, y, z) in [(0, 0, 0.4), (-0.18, -0.1, 0.3), (0.18, 0.12, 0.3), (0.05, -0.18, 0.32), (-0.08, 0.18, 0.3)]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=0.3, location=(x, y, z))
    blobs.append(bpy.context.active_object)
bush = join(blobs, "Bush_Leaves")
into(bush, "Bush", "Bush_Leaves", mat("Leaf", "6ba845"))
print(bounds("Bush"))
bpy.ops.wm.save_mainfile()
```

Expected: z from 0.0 to 0.7, x and y within ±0.48.

- [ ] **Step 7: Daisy**

```python
# (helpers)
petals = []
for i in range(8):
    a = math.tau * i / 8
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=0.05,
        location=(math.cos(a) * 0.075, math.sin(a) * 0.075, 0.22))
    p = bpy.context.active_object
    p.rotation_euler = (0, 0, a)
    p.scale = (1.4, 0.8, 0.25)
    apply_all(p)
    petals.append(p)
pet = join(petals, "Daisy_Petals")
into(pet, "Daisy", "Daisy_Petals", mat("Petal_flat", "f6f1e6"))
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.04, location=(0, 0, 0.225))
c = bpy.context.active_object
c.scale = (1.0, 1.0, 0.5); apply_all(c)
into(c, "Daisy", "Daisy_Centre", mat("Centre_flat", "f5a623"))
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.012, depth=0.22, location=(0, 0, 0.11))
s = bpy.context.active_object
into(s, "Daisy", "Daisy_Stem", mat("Stem_flat", "6ba845"))
print(bounds("Daisy"))
bpy.ops.wm.save_mainfile()
```

Expected: x and y within ±0.15, z from 0.0 to under 0.25.

- [ ] **Step 8: Tuft**

```python
# (helpers)
blades = []
for i in range(3):
    a = math.tau * i / 3
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    b = bpy.context.active_object
    b.scale = (0.06, 0.02, 0.25)
    apply_all(b)
    bm = bmesh.new(); bm.from_mesh(b.data)
    for v in bm.verts:
        if v.co.z > 0.1:
            v.co.x *= 0.25   # taper to a tip
    bm.to_mesh(b.data); bm.free()
    b.rotation_euler = (math.radians(15) * math.cos(a), math.radians(15) * math.sin(a), a)
    b.location = (math.cos(a) * 0.06, math.sin(a) * 0.06, 0.125)
    apply_all(b)
    blades.append(b)
tuft = join(blades, "Tuft_Blades")
lo = min((tuft.matrix_world @ v.co).z for v in tuft.data.vertices)
for v in tuft.data.vertices:
    v.co.z -= lo
into(tuft, "Tuft", "Tuft_Blades", mat("Grass_sway_flat", "7fa550"))
print(bounds("Tuft"))
bpy.ops.wm.save_mainfile()
```

Expected: z from 0.0 (within 0.001) to under 0.25, x and y within ±0.15. If the top passes 0.25, scale the mesh's z down.

- [ ] **Step 9: Signpost**

The post stands at the left end (x = -0.64), the plank hangs at x = 0.2 and is 1.0 wide, so the union spans exactly -0.70 .. 0.70 and is centred. The paper and the words face **-Y**.

```python
# (helpers)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.64, 0, 0.9)); post = bpy.context.active_object
post.scale = (0.12, 0.12, 1.8); apply_all(post)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0, 1.76)); arm = bpy.context.active_object
arm.scale = (1.28, 0.08, 0.08); apply_all(arm)
sp = join([post, arm], "Sign_Post")
into(sp, "Signpost", "Sign_Post", mat("Bark", "8a6a4a")); bevel(sp, 0.01, 2)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.2, 0, 0.9)); board = bpy.context.active_object
board.scale = (1.0, 0.06, 0.7); apply_all(board)
into(board, "Signpost", "Sign_Board", mat("Timber", "c49a63")); bevel(board, 0.02, 2)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.2, -0.035, 0.97)); paper = bpy.context.active_object
paper.scale = (0.86, 0.01, 0.56); apply_all(paper)
into(paper, "Signpost", "Sign_Paper", mat("Paper_flat", "f3e9d2"))
font = bpy.data.fonts.load("/Users/flavioriper/dev/daily/assets/fonts/Fredoka-Variable.ttf")
bpy.ops.object.text_add(location=(0.2, -0.041, 0.97))
txt = bpy.context.active_object
txt.data.body = "THINK\nTEST\nADJUST\nSOLVE!"
txt.data.font = font
txt.data.size = 0.11
txt.data.space_line = 1.05
txt.data.align_x = "CENTER"
txt.data.align_y = "CENTER"
txt.data.extrude = 0.005
txt.rotation_euler = (math.radians(90), 0, 0)
bpy.ops.object.convert(target="MESH")
words = bpy.context.active_object
apply_all(words)
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0005); bpy.ops.object.mode_set(mode="OBJECT")
into(words, "Signpost", "Sign_Words", mat("Ink_flat", "3b3028"))
print(bounds("Signpost"))
bpy.ops.wm.save_mainfile()
```

Expected: x -0.70 .. 0.70 (centred within 0.001), y within ±0.06 and centred, z 0 .. 1.8. If the words poke out of the paper (x beyond ±0.43 from 0.2, or z outside 0.69 .. 1.25), reduce `size`. If the exporter later reports the words "not shaded smooth", `into` has already set every polygon smooth; re-run that loop after the convert.

- [ ] **Step 10: Export, import, preview**

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b art/scenery.blend --python-exit-code 1 --python tools/blender_export.py -- Deck Pier_Post Boulder Bush Daisy Tuft Signpost 2>&1 | grep -E "^(OK|SKIP|WARN)"
godot --headless --path . --import > /tmp/import.log 2>&1; tail -2 /tmp/import.log
for s in deck pier_post boulder bush daisy tuft signpost; do godot --path . --resolution 720x720 --script res://tests/_shot_model.gd -- $s 2>&1 | grep saved; done
```

Expected: seven `OK` lines, no `SKIP`. Open each `/tmp/shot_model_<slot>.png`: outlines closed at every corner (no gaps), seams between the two deck planks visible as a dark line, the sign's words legible at this size. Fix any SKIP in Blender (the rule is in the message), save, re-export.

- [ ] **Step 11: Run the suite and the board shot**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="` → `failed=0`. The model test now checks the exports' layers against `LAYERS`; a mismatch names the slot.
Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd 2>&1 | grep mastermind`, open `/tmp/shot_mastermind.png`. Check the real planks, rocks, bushes, daisies, tufts and sign against `docs/art/concept-codebreak-screen.png`. **Sign legibility:** if the four words cannot be read in this shot, note it for Task 10's amendment (the fallback is a carved leaf on the paper; do not implement it in this task).

- [ ] **Step 12: Commit**

```bash
git add art/scenery.blend assets/models/deck.glb assets/models/pier_post.glb assets/models/boulder.glb assets/models/bush.glb assets/models/daisy.glb assets/models/tuft.glb assets/models/signpost.glb assets/models/*.glb.import
git commit -m "feat(art): the deck strip and six scenery pieces, modelled and exported

Deck planks with a seam gap, a pier post, a mossy boulder, a bush, a
daisy, a grass tuft and the hanging sign with its four words in the
display face, all through the contract from art/scenery.blend."
```

---

### Task 8: Blender: the socket's recess and the peg's shine

**Files:**
- Modify: `art/codebreak.blend`
- Modify: `assets/models/socket.glb`, `assets/models/peg.glb` (re-exported)
- Modify: `core/placeholders.gd` `_peg()` (add the shine layer), `tests/test_models.gd` `LAYERS["peg"]`

**Interfaces:**
- Consumes: `Placeholders.WELL_DEPTH` (Task 3).
- Produces: `peg` carries `Shine_flat`; `socket`'s well sits 0.03 deep.

- [ ] **Step 1: Open the file**

```python
import bpy
bpy.ops.wm.open_mainfile(filepath="/Users/flavioriper/dev/daily/art/codebreak.blend")
print([(o.name, [m.name for m in o.modifiers]) for o in bpy.data.objects])
```

Expected to list `Socket_Body` with `['Bevel']`, `Socket_Well`, `Peg_Body`, `Peg_Mark_1..7`, `Pip_*`, `Lid_*`.

- [ ] **Step 2: Cut the recess**

A cutter cylinder in a helper collection (never exported), a Boolean before the Bevel so the hole's rim is bevelled too, and the well disc lowered to Z = 0.09.

```python
import bpy
helpers = bpy.data.collections.get("Codebreak_Helpers") or bpy.data.collections.new("Codebreak_Helpers")
if helpers.name not in [c.name for c in bpy.context.scene.collection.children]:
    bpy.context.scene.collection.children.link(helpers)
bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.3, depth=0.2, location=(0, 0, 0.19))
cut = bpy.context.active_object
cut.name = "Socket_Cutter"; cut.data.name = "Socket_Cutter"
for p in cut.data.polygons: p.use_smooth = True
for c in list(cut.users_collection): c.objects.unlink(cut)
helpers.objects.link(cut)
cut.hide_render = True; cut.display_type = "WIRE"
body = bpy.data.objects["Socket_Body"]
b = body.modifiers.new("Recess", "BOOLEAN")
b.operation = "DIFFERENCE"; b.object = cut; b.solver = "EXACT"
bpy.context.view_layer.objects.active = body
bpy.ops.object.modifier_move_to_index(modifier="Recess", index=0)
well = bpy.data.objects["Socket_Well"]
well.location.z -= 0.03
print([m.name for m in body.modifiers], well.location.z)
bpy.ops.wm.save_mainfile()
```

Expected: `['Recess', 'Bevel']` and the well at about `0.09` (its own origin may sit at the disc's centre; the disc must span Z 0.088 .. 0.092).

- [ ] **Step 3: The shine on the peg**

The dome is an ellipsoid of semi-axes 0.3, 0.3, 0.22 centred at Z = 0.22. The shine sits on its surface at the player's upper-left (Blender -X, +Y), 45 degrees up, aligned to the surface normal, half buried.

```python
import bpy, math
from mathutils import Vector
a, b, c = 0.3, 0.3, 0.22
d = Vector((-0.5, 0.5, 0.7071))
p = Vector((d.x * a, d.y * b, 0.22 + d.z * c))
n = Vector((p.x / a**2, p.y / b**2, (p.z - 0.22) / c**2)).normalized()
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.05, location=p)
s = bpy.context.active_object
s.rotation_euler = n.to_track_quat("Z", "Y").to_euler()
s.scale = (1.0, 0.6, 0.35)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
s.name = "Peg_Shine"; s.data.name = "Peg_Shine"
m = bpy.data.materials.get("Shine_flat") or bpy.data.materials.new("Shine_flat")
m.use_nodes = True
def lin(h):
    cc = [int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple((v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in cc) + (1.0,)
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin("f6f1e6")
s.data.materials.clear(); s.data.materials.append(m)
for poly in s.data.polygons: poly.use_smooth = True
for col in list(s.users_collection): col.objects.unlink(s)
bpy.data.collections["Peg"].objects.link(s)
print(s.location, [round(v, 3) for v in s.dimensions])
bpy.ops.wm.save_mainfile()
```

- [ ] **Step 4: Export, import, preview**

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b art/codebreak.blend --python-exit-code 1 --python tools/blender_export.py -- Socket Peg Pip Lid 2>&1 | grep -E "^(OK|SKIP|WARN)"
godot --headless --path . --import > /tmp/import.log 2>&1; tail -1 /tmp/import.log
godot --path . --resolution 720x720 --script res://tests/_shot_model.gd -- socket 2>&1 | grep saved
godot --path . --resolution 720x720 --script res://tests/_shot_model.gd -- peg 2>&1 | grep saved
```

Expected: four `OK`. Open `/tmp/shot_model_socket.png`: a round dimple in the slab with the well disc at its floor; if a dark ring sits on the recess wall (the outline shell pushed inward), that is the ink line the design accepts, but if it fills the whole well black, shrink the cutter's radius to 0.29 and re-export. Open `/tmp/shot_model_peg.png`: a cream highlight upper-left on the dome, the pips still on the crown.

- [ ] **Step 5: The placeholder and the test follow the export**

In `core/placeholders.gd` `_peg()`, after the `for k in range(1, Shapes.PIPS.size() + 1):` loop and before `Toon.apply_to(root)`, add:

```gdscript
	# The glossy highlight, a flat patch on the dome's upper-left as the
	# player sees it (-X, -Z), half buried like the marks.
	var shine := _ball(0.05)
	var at := Vector3(-0.5 * PEG_R, PEG_H * 0.5 + 0.7071 * PEG_H * 0.5, -0.5 * PEG_R)
	root.add_child(_layer("Peg_Shine", _merge([{"mesh": shine,
		"xform": Transform3D(Basis().scaled(Vector3(1.0, 0.35, 0.6)), at)}]),
		"Shine_flat", Pal.MOON, Vector3.ZERO))
```

In `tests/test_models.gd` `LAYERS`, change `"peg": ["Mark_flat", "Shell"]` to `"peg": ["Mark_flat", "Shell", "Shine_flat"]`.

- [ ] **Step 6: Suite, board shot, commit**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="` → `failed=0`.
Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd 2>&1 | grep mastermind`, open `/tmp/shot_mastermind.png`: the sockets show dimples; the lids' knobs are dark.

```bash
git add art/codebreak.blend assets/models/socket.glb assets/models/peg.glb core/placeholders.gd tests/test_models.gd
git commit -m "feat(art): the socket's well is a recess and the peg wears a highlight

A boolean cut 0.03 deep under the bevel so the well shades as a dimple,
and a flat cream patch on the dome's upper-left for the glossy toy look
the concept has."
```

---

### Task 9: Blender: POM's arms, backpack and map

**Files:**
- Modify: `art/mascot_pom.blend`
- Modify: `assets/models/mascot_pom.glb` (re-exported)
- Modify: `assets/models/README.md` (the `mascot_pom` row)

**Interfaces:**
- Produces: `mascot_pom` with layers `Pom_Arms` (`Pom_Arm`), `Pom_Pack` (`Pom_Pack`), `Pom_Map` (`Pom_Map_flat`) in addition to its fifteen.

The exporter demands the assembly's footprint stay centred on the origin: today it spans y from -0.59 (nose) to 0.59 (tail) and x ±0.63 (ears). Nothing new may pass those: the pack's back stays under y = 0.588, the map's front above y = -0.585.

- [ ] **Step 1: Open and measure**

```python
import bpy
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath="/Users/flavioriper/dev/daily/art/mascot_pom.blend")
lo = Vector((1e9,)*3); hi = Vector((-1e9,)*3)
for o in bpy.data.collections["Mascot_Pom"].objects:
    for v in o.bound_box:
        w = o.matrix_world @ Vector(v); lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
print("assembly", lo, hi)
print([m.name for m in bpy.data.materials])
```

Expected: about (-0.63, -0.59, 0.0) .. (0.63, 0.59, 1.13).

- [ ] **Step 2: Arms, pack, map**

```python
import bpy, math
from mathutils import Vector
def lin(h):
    cc = [int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple((v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in cc) + (1.0,)
def mat(name, rgba):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = rgba
    return m
def finish(o, name, material):
    o.name = name; o.data.name = name
    o.data.materials.clear(); o.data.materials.append(material)
    for p in o.data.polygons: p.use_smooth = True
    for c in list(o.users_collection): c.objects.unlink(o)
    bpy.data.collections["Mascot_Pom"].objects.link(o)
def apply(o):
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

body_rgba = tuple(bpy.data.materials["Pom_Body"].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value)
# Arms: two capsule-ish lobes from the body's sides to the paws in front.
arms = []
for side in (-1, 1):
    start = Vector((side * 0.40, -0.25, 0.46))
    end = Vector((side * 0.13, -0.50, 0.38))
    mid = (start + end) / 2
    d = end - start
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.1, location=mid)
    a = bpy.context.active_object
    a.rotation_euler = d.to_track_quat("Y", "Z").to_euler()
    a.scale = (1.0, d.length / 0.2 + 0.4, 0.9)
    apply(a)
    arms.append(a)
bpy.ops.object.select_all(action="DESELECT")
for a in arms: a.select_set(True)
bpy.context.view_layer.objects.active = arms[0]
bpy.ops.object.join()
finish(bpy.context.view_layer.objects.active, "Pom_Arms", mat("Pom_Arm", body_rgba))
# Pack: a rounded bag on the back, its back face under y = 0.588.
bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=0.28, location=(0, 0.42, 0.75))
pack = bpy.context.active_object
pack.scale = (1.0, 0.6, 1.1); apply(pack)
finish(pack, "Pom_Pack", mat("Pom_Pack", lin("7fa84a")))
# Map: a folded sheet between the paws, tilted so its face points up and forward.
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.50, 0.42))
m = bpy.context.active_object
m.scale = (0.36, 0.01, 0.26)
m.rotation_euler = (math.radians(-30), 0, 0)
apply(m)
finish(m, "Pom_Map", mat("Pom_Map_flat", lin("f3e9d2")))
lo = Vector((1e9,)*3); hi = Vector((-1e9,)*3)
for o in bpy.data.collections["Mascot_Pom"].objects:
    for v in o.bound_box:
        w = o.matrix_world @ Vector(v); lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
print("assembly", lo, hi)
bpy.ops.wm.save_mainfile()
```

Expected: the assembly's y extremes unchanged at -0.59 .. 0.59 (within 0.001) and x at ±0.63; z top under 1.4. If the pack's y max exceeds 0.59, move it to y = 0.41; if the map's y min drops under -0.59, move it to y = -0.48. Take a viewport screenshot (`mcp__blender__get_viewport_screenshot`) and check the paws meet the map and the pack sits on the back, not through the ears.

- [ ] **Step 3: Export, import, preview**

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b art/mascot_pom.blend --python-exit-code 1 --python tools/blender_export.py -- Mascot_Pom 2>&1 | grep -E "^(OK|SKIP|WARN)"
godot --headless --path . --import > /tmp/import.log 2>&1; tail -1 /tmp/import.log
godot --path . --resolution 720x720 --script res://tests/_shot_model.gd -- mascot_pom 2>&1 | grep saved
```

Expected: `OK mascot_pom ...`. Open `/tmp/shot_model_mascot_pom.png`: arms, a green pack behind, a cream map in front. The model preview looks from above; that is expected.

- [ ] **Step 4: README, board shot, commit**

In `assets/models/README.md`, change the `mascot_pom` row to:

```markdown
| `mascot_pom` | POM the puppy, an assembly of 18 layered parts, one mesh per layer, with arms, a moss backpack and a parchment map; Code Break seats it on a boulder beside its top rows |
```

Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd 2>&1 | grep mastermind`, open `/tmp/shot_mastermind.png`: POM on its rock at the right of the top rows, turned toward the board, map visible.

```bash
git add art/mascot_pom.blend assets/models/mascot_pom.glb assets/models/README.md
git commit -m "feat(art): POM holds a map and wears a backpack

Three layers on the mascot for its seat beside Code Break's board, kept
inside the footprint the exporter already accepted."
```

---

### Task 10: Measure, amend the spec, final checks

**Files:**
- Modify: `tests/_shot_anim.gd`
- Modify: `docs/superpowers/specs/2026-09-15-codebreak-screen-design.md` (amendments at the end)

- [ ] **Step 1: The animation probe takes a puzzle id**

In `tests/_shot_anim.gd`:

Add a field after `var _draws := 0`:

```gdscript
var _id := ""
var _entry: Dictionary = {}
```

In `_initialize`, before `var main: Node = ...`, add:

```gdscript
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_id = args[0]
```

Replace `_menu._open(load("res://ui/registry.gd").PUZZLES[0])` with:

```gdscript
			var entries: Array = load("res://ui/registry.gd").PUZZLES
			_entry = entries[0]
			for e in entries:
				if e.id == _id:
					_entry = e
			_menu._open(_entry)
```

Replace the tap line `_tap_first_free()` with:

```gdscript
		# The tap walks Binairo's givens; a board without them idles instead.
		if _puzzle.get("_given") != null:
			_tap_first_free()
```

Replace `var path := "/tmp/anim_binairo_%d.png" % _shot` with `var path := "/tmp/anim_%s_%d.png" % [_entry.id, _shot]`.

Update the header comment: the usage line gains `[-- <puzzle id>]` and the saved path becomes `/tmp/anim_<id>_<n>.png`.

- [ ] **Step 2: Measure Code Break**

Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot_anim.gd -- mastermind 2>&1 | grep -E "idle|saved"`
Record the `idle frames=... mean_ms=... max_draw_calls=...` line. Expected under 8 ms and under 855 calls. Then run the Binairo default once to confirm it still works: `godot --path . --resolution 1080x1920 --script res://tests/_shot_anim.gd 2>&1 | grep idle`.

If Code Break's mean passes 7 ms or calls pass 800, cut `DAISIES` to six and `TREES` to three in `puzzles/codebreak_scenery.gd`, re-measure, and record both numbers.

- [ ] **Step 3: The full verification pass**

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -1
godot --path . --resolution 1080x1920 --script res://tests/_win.gd 2>&1 | grep -E "winnable|mastermind"
godot --path . --resolution 1080x1920 --script res://tests/_shot.gd 2>&1 | grep -c saved
```

Expected: `failed=0`; `winnable=N/N` with N equal to the number of boards, not `0/0`; 13 shots saved. Open `/tmp/shot_mastermind.png`, `/tmp/shot_menu.png` and `/tmp/shot_binairo.png`: Code Break against the concept, the menu's plaque, and Binairo unchanged apart from the plaque and day card.

- [ ] **Step 4: Amend the spec**

Append to `docs/superpowers/specs/2026-09-15-codebreak-screen-design.md`:

```markdown

## Amendments (implementation, 2026-09-15)

- The `daisy` has three layers, not two: `Daisy_Stem` (`Stem_flat`) reaches
  the ground, since the contract puts every base at Z = 0.
- The placeholder socket keeps its well disc on top; only the export carries
  the recess. The tests read layers and bounds, not holes.
- The `deck` slot is exact along X only (`EXACT["deck"] = (1.0, None)`); its
  depth is 0.94, the planks plus half a gap at each edge, so adjacent strips
  leave the same seam the two planks do.
- Sign words: <legible in the stage shot at 1080 x 1920 / replaced by the leaf>.
- Measured on the Mac at 1080 x 1920 with `tests/_shot_anim.gd -- mastermind`:
  `idle mean_ms=<x> max_draw_calls=<n>`; Binairo unchanged at `<x>` / `<n>`.
  Suite `passed=<N> failed=0`, win harness `<N>/<N>`.
```

Fill every angle-bracketed value from the runs above; leave none.

- [ ] **Step 5: Commit**

```bash
git add tests/_shot_anim.gd docs/superpowers/specs/2026-09-15-codebreak-screen-design.md
git commit -m "chore: the animation probe takes a puzzle id; spec amended with the measurements

Code Break's dock and scenery measured against the 8 ms and 855-call
budgets, and the three small departures from the design recorded."
```

---

## Self-review notes

- Spec coverage: section 1 (deck, posts, socket, lid, peg, tray) → Tasks 2, 3, 5, 7, 8; section 2 (banks, river, props, tufts, sign, lantern, trees, POM placement) → Tasks 4, 6, 7; section 3 (POM layers, motion) → Tasks 6, 9; section 4 (motion) → Tasks 5, 6; section 5 (HUD) → Task 1; section 6 (library, exporter, docs) → Task 3, README rows in Tasks 3 and 9; section 7 (code structure, `_shot_anim` arg) → Tasks 4, 5, 6, 10; sections 8 and 9 → Task 10.
- Names used across tasks: `CodebreakScenery.dock/build/POM_REST_Y`, `Scenery.ground/water/deck/prop/scatter`, `Placeholders.PEG_SEAT/WELL_DEPTH/BOULDER_H`, `CozyTheme.plank_card/wood_channel`, `Pal.DECK/BANK/BOULDER/PLAQUE/PLAQUE_DEEP` are defined before they are used and spelled the same everywhere.
