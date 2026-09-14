# Code Break on the island Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat 2D Code Break with a 3D board on the island stage: socket slabs, tinted pegs with pip marks, feedback pips, a lidded code row, and a wooden colour tray in the HUD.

**Architecture:** `puzzles/codebreak3d.gd` extends `core/puzzle_base_3d.gd` exactly as `puzzles/binairo3d.gd` does: it builds pieces from the model library (`core/models.gd`, with primitive placeholders in `core/placeholders.gd` until the Blender exports land), lays them on the shared platform, and animates with the recipes in `core/motion.gd`. The HUD grows one capability, `palette`, served by a new tray row inside `ui/hud/action_bar.gd`. Four new model slots are modelled in the live Blender session into `art/codebreak.blend` and exported through the contract.

**Tech Stack:** Godot 4.7 (GDScript, gl_compatibility renderer), Blender 4.x via the Blender MCP and `tools/blender_export.py`.

**Spec:** `docs/superpowers/specs/2026-09-14-codebreak-3d-design.md`

## Global Constraints

- Godot 4.7; run everything from the repo root with the `godot` binary on the path.
- **No new test files** (MVP rule). Existing tests that name the model slots or drive Code Break are updated. Throwaway checks go under `/tmp`, never into `tests/`.
- **One mesh per layer** in every model; layer and material names exactly as the spec's table in section 1. Materials that must not have an outline end in `_flat`.
- The `.blend` is the source: `art/codebreak.blend` is modelled in the live Blender session (the MCP is a remote control) and tracked in git. Never add a generator script for it.
- Export only through the contract: `Blender -b art/codebreak.blend --python tools/blender_export.py -- Socket Peg Pip Lid`, then `godot --headless --path . --import`.
- Godot re-saves `project.godot` with a header comment after windowed runs: `git checkout project.godot` before committing if it shows as modified.
- Never push. Work on `feat/codebreak-3d`; the branch is merged into `main` locally at the end.
- Performance budget: idle frame time at or under 8 ms at 1080 x 1920 on the Mac, at most 855 draw calls at rest.
- Tests: `godot --headless --path . --script res://tests/run_tests.gd` ends with `passed=N failed=0`. Win harness: `godot --path . --resolution 1080x1920 --script res://tests/_win.gd` ends with `winnable=10/10`.

---

### Task 1: The model library learns the four slots

**Files:**
- Modify: `core/palette.gd` (after the `PARCHMENT` line)
- Modify: `core/shapes.gd` (append)
- Modify: `core/motion.gd` (after `appear`)
- Modify: `core/models.gd` (`SLOTS`, new `set_layer_visible`)
- Modify: `core/placeholders.gd` (constants, `make`, new builders)
- Modify: `tools/blender_export.py` (`LIMITS`)
- Modify: `tests/test_models.gd` (`HEIGHT_BUDGET`, `_test_slots`)

**Interfaces:**
- Produces: `Pal.PEGS: Array[Color]` (7 entries), `Pal.WOOD_DEEP: Color`; `Shapes.PIPS: Array` (7 layouts of `Vector2` offsets) and `Shapes.draw_pips(ci, count, centre, spread, r, col)`; `Motion.vanish(node: Node3D, lift: float, time: float, delay := 0.0) -> Tween`; `Models.set_layer_visible(root: Node, node_name: String, on: bool) -> void`; `Models.SLOTS` with `socket`, `peg`, `pip`, `lid`; `Placeholders.SOCKET_SIDE/SOCKET_H/WELL_R/WELL_PROUD/PEG_R/PEG_H/MARK_R/MARK_SPREAD/PIP_WELL_R/PIP_R/LID_H/KNOB_R/KNOB_H`; placeholder nodes whose mesh instances are named `Socket_Body`, `Socket_Well`, `Peg_Body`, `Peg_Mark_1`..`Peg_Mark_7`, `Pip_Well`, `Pip_Ball`, `Lid_Body`, `Lid_Knob` with materials `Stone`, `Well_flat`, `Shell`, `Mark_flat`, `Pip`, `Lid`, `Knob`.

- [ ] **Step 1: Palette additions**

In `core/palette.gd`, after the `PARCHMENT` constant, add:

```gdscript
# Code Break pegs (docs/art/concept-codebreak.png): red, yellow, blue, green,
# purple, pink, orange. Index order is the difficulty's palette order; every
# peg also carries a pip mark, so colour never stands alone.
const PEGS := [
	Color("e5484d"), Color("f7c948"), Color("3d8bfd"), Color("3fb950"),
	Color("9b6cf6"), Color("f472b6"), Color("fb8c3c"),
]
const WOOD_DEEP    := Color("9c7350")   # the colour tray's bottom edge
```

- [ ] **Step 2: Pip layouts in `core/shapes.gd`**

Append to `core/shapes.gd`:

```gdscript
## Die-face layouts for one to seven pips, as offsets in units of a spread:
## the peg models emboss these on their crowns and the tray buttons draw them.
## Seven is a ring of six around one.
const PIPS := [
	[Vector2(0, 0)],
	[Vector2(-1, -1), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
	[Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 0.87), Vector2(-0.5, 0.87), Vector2(-1, 0), Vector2(-0.5, -0.87), Vector2(0.5, -0.87)],
]

## Draws `count` pips (1..7) of radius `r` around `centre`, `spread` apart.
static func draw_pips(ci: CanvasItem, count: int, centre: Vector2, spread: float, r: float, col: Color) -> void:
	var layout: Array = PIPS[clampi(count, 1, PIPS.size()) - 1]
	for p in layout:
		ci.draw_circle(centre + (p as Vector2) * spread, r, col)
```

- [ ] **Step 3: `Motion.vanish`**

In `core/motion.gd`, after `appear`, add:

```gdscript
## Lifts `node` by `lift` while it shrinks to nothing, then hides it. The
## caller frees the node on `finished` if it wants it gone. Decorative: under
## reduce-motion the node is hidden at once and null returned.
static func vanish(node: Node3D, lift: float, time: float, delay := 0.0) -> Tween:
	if reduce:
		node.visible = false
		return null
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "position:y", node.position.y + lift, time).set_delay(delay) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector3.ONE * 0.01, time).set_delay(delay) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void: node.visible = false)
	return tw
```

- [ ] **Step 4: Slots and layer visibility in `core/models.gd`**

Replace the `SLOTS` line with:

```gdscript
const SLOTS := ["tile", "rim_edge", "rim_corner", "platform", "water", "socket", "peg", "pip", "lid"]
```

After `surface_names`, add:

```gdscript
## Shows or hides the mesh node called `node_name` under `root`. The outline
## shell is a child of its mesh, so it follows. No-op when the name is absent.
## Code Break uses it for the peg marks (one of seven shown), the feedback
## slab's well and the pip balls.
static func set_layer_visible(root: Node, node_name: String, on: bool) -> void:
	var node := root.find_child(node_name, true, false)
	if node is Node3D:
		(node as Node3D).visible = on
```

- [ ] **Step 5: Placeholder constants and builders in `core/placeholders.gd`**

After `const RIM_H := 0.04`, add:

```gdscript
## Code Break pieces (codebreak spec, section 1). The socket is a slab with a
## well disc laid proud on top; the peg an ellipsoid dome with its pip mark on
## the crown; the pip a well disc with a ball in it; the lid a slab with a knob.
const SOCKET_SIDE := 0.94
const SOCKET_H := 0.12
const WELL_R := 0.3
const WELL_PROUD := 0.0015
const PEG_R := 0.3
const PEG_H := 0.44
const MARK_R := 0.035
const MARK_SPREAD := 0.11
const PIP_WELL_R := 0.1
const PIP_R := 0.08
const LID_H := 0.16
const KNOB_R := 0.09
const KNOB_H := 0.08
```

Add `const Shapes = preload("res://core/shapes.gd")` next to the other preloads at the top.

In `make`, inside the `match slot:` block, add these four arms right after the `"tile":` arm (they return directly, like the tile):

```gdscript
		"socket":
			return _socket()
		"peg":
			return _peg()
		"pip":
			return _pip()
		"lid":
			return _lid()
```

At the end of the file add the builders:

```gdscript
# --- Code Break pieces ---

## A mesh instance carrying one layer: `mesh` with a material named
## `mat_name` set on the mesh itself, where Toon.apply_to, Models.tint_named
## and Models.surface_names read it, as they do on an export.
static func _layer(node_name: String, mesh: Mesh, mat_name: String, colour: Color, at: Vector3) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = mat_name
	mat.albedo_color = colour
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = mat
	else:
		(mesh as ArrayMesh).surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = at
	return mi

## Stone slab with a well disc on top. The feedback slab is this with the
## well hidden.
static func _socket() -> Node3D:
	var root := Node3D.new()
	root.name = "socket"
	var body := BoxMesh.new()
	body.size = Vector3(SOCKET_SIDE, SOCKET_H, SOCKET_SIDE)
	root.add_child(_layer("Socket_Body", body, "Stone", Pal.STONE, Vector3(0.0, SOCKET_H * 0.5, 0.0)))
	root.add_child(_layer("Socket_Well", _cylinder(WELL_R, WELL_PROUD * 2.0, 32), "Well_flat", Pal.MARK,
		Vector3(0.0, SOCKET_H, 0.0)))
	Toon.apply_to(root)
	return root

## Dome with seven mark layers on its crown; the game shows one.
static func _peg() -> Node3D:
	var root := Node3D.new()
	root.name = "peg"
	var dome := SphereMesh.new()
	dome.radius = PEG_R
	dome.height = PEG_H
	dome.radial_segments = 32
	dome.rings = 16
	root.add_child(_layer("Peg_Body", dome, "Shell", Pal.PEGS[0], Vector3(0.0, PEG_H * 0.5, 0.0)))
	for k in range(1, Shapes.PIPS.size() + 1):
		root.add_child(_layer("Peg_Mark_%d" % k, _pips_mesh(k), "Mark_flat", Pal.PEGS[0].darkened(0.35), Vector3.ZERO))
	Toon.apply_to(root)
	return root

## `count` pip discs merged into one mesh, each resting on the dome's crown
## at its own height: the dome is an ellipsoid of semi-axes PEG_R and PEG_H / 2.
static func _pips_mesh(count: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var disc := _cylinder(MARK_R, WELL_PROUD * 2.0, 16)
	var a := PEG_R
	var b := PEG_H * 0.5
	for p in Shapes.PIPS[count - 1]:
		var off: Vector2 = (p as Vector2) * MARK_SPREAD
		var d := off.length()
		var y := b + b * sqrt(maxf(0.0, 1.0 - (d * d) / (a * a)))
		st.append_from(disc, 0, Transform3D(Basis.IDENTITY, Vector3(off.x, y, off.y)))
	return st.commit()

## Well disc with a ball resting in it; the ball hides until the row is scored.
static func _pip() -> Node3D:
	var root := Node3D.new()
	root.name = "pip"
	root.add_child(_layer("Pip_Well", _cylinder(PIP_WELL_R, WELL_PROUD * 2.0, 24), "Well_flat", Pal.MARK,
		Vector3(0.0, WELL_PROUD, 0.0)))
	var ball := SphereMesh.new()
	ball.radius = PIP_R
	ball.height = PIP_R * 2.0
	ball.radial_segments = 16
	ball.rings = 8
	root.add_child(_layer("Pip_Ball", ball, "Pip", Pal.MOON, Vector3(0.0, PIP_R, 0.0)))
	Toon.apply_to(root)
	return root

## Stone lid with a wooden knob, covering one code slot.
static func _lid() -> Node3D:
	var root := Node3D.new()
	root.name = "lid"
	var body := BoxMesh.new()
	body.size = Vector3(SOCKET_SIDE, LID_H, SOCKET_SIDE)
	root.add_child(_layer("Lid_Body", body, "Lid", Pal.STONE_GIVEN, Vector3(0.0, LID_H * 0.5, 0.0)))
	root.add_child(_layer("Lid_Knob", _cylinder(KNOB_R, KNOB_H, 24), "Knob", Pal.WOOD,
		Vector3(0.0, LID_H + KNOB_H * 0.5, 0.0)))
	Toon.apply_to(root)
	return root
```

- [ ] **Step 6: Exporter budgets**

In `tools/blender_export.py`, inside `LIMITS`, after the `"tree"` row add:

```python
    # Code Break pieces (docs/superpowers/specs/2026-09-14-codebreak-3d-design.md,
    # section 1): a slab, a dome, a pip and a lid, all inside one cell.
    "socket": (1.0, 1.0, 0.15),
    "peg": (0.7, 0.7, 0.5),
    "pip": (0.3, 0.3, 0.2),
    "lid": (1.0, 1.0, 0.3),
```

- [ ] **Step 7: Update `tests/test_models.gd` for the new slots**

Replace the `HEIGHT_BUDGET` line with:

```gdscript
const HEIGHT_BUDGET := {"tile": 0.9, "rim_edge": 0.12, "rim_corner": 0.12,
	"socket": 0.15, "peg": 0.5, "pip": 0.2, "lid": 0.3}
```

In `_test_slots`, replace the `SLOTS` expectation with:

```gdscript
	t.eq(Models.SLOTS, ["tile", "rim_edge", "rim_corner", "platform", "water", "socket", "peg", "pip", "lid"],
		"slot list matches the polish and codebreak specs")
```

and replace the `outlined` line with:

```gdscript
		var outlined: Array = {"tile": ["Stone", "Sun", "Moon"], "socket": ["Stone"], "peg": ["Shell"],
			"pip": ["Pip"], "lid": ["Lid", "Knob"]}.get(slot, [])
```

- [ ] **Step 8: Run the suite**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -5`
Expected: the last line is `passed=N failed=0` with N at least 1158 plus the new slot checks. If a placeholder fails a footprint or outline check, fix the builder, not the test.

- [ ] **Step 9: Throwaway look at the placeholders**

Run: `for s in socket peg pip lid; do godot --path . --resolution 720x720 --script res://tests/_shot_model.gd -- $s; done; git checkout project.godot 2>/dev/null; ls /tmp/shot_model_*.png`
Open `/tmp/shot_model_peg.png`: a dome with one pip on top (mark 1 is the visible default until the game hides the rest; all seven overlap here, which is fine for a placeholder). No magenta anywhere.

- [ ] **Step 10: Commit**

```bash
git add core/palette.gd core/shapes.gd core/motion.gd core/models.gd core/placeholders.gd tools/blender_export.py tests/test_models.gd
git commit -m "feat: the model library knows the socket, peg, pip and lid, with placeholders

Four slots for Code Break, each a primitive stand-in carrying the layer and
material names art/codebreak.blend will export, so the board runs before the
art lands and the headless tests see one contract. Models.set_layer_visible
shows one of a peg's seven pip marks; Motion.vanish is the pop; Shapes.PIPS
holds the die layouts the models and the tray buttons share."
```

---

### Task 2: The palette capability and the colour tray

**Files:**
- Modify: `core/puzzle_base.gd` (optional hooks block)
- Modify: `ui/theme.gd` (append `wood_card`)
- Create: `ui/hud/peg_button.gd`
- Create: `ui/hud/palette_tray.gd`
- Modify: `ui/hud/action_bar.gd`
- Modify: `ui/puzzle_host.gd` (`_ready` wiring, `_on_check`, new `_on_pick`)

**Interfaces:**
- Consumes: `Pal.PEGS`, `Pal.WOOD_DEEP`, `Shapes.draw_pips`, `Motion.squash` (Task 1).
- Produces: `PuzzleBase.palette() -> Array[Dictionary]` (entries `{"colour": Color, "mark": int, "enabled": bool}`), `PuzzleBase.pick(i: int) -> bool`; `PaletteTray` (`ui/hud/palette_tray.gd`, `extends PanelContainer`) with `signal pick(index: int)`, `buttons: Array`, `refresh(puzzle)`; `PegButton.set_entry(colour, mark, enabled)`; `action_bar.tray`, `action_bar.pick(index)`; `CozyTheme.wood_card()`.

- [ ] **Step 1: Hooks on `core/puzzle_base.gd`**

Inside the optional-for-the-HUD block, after `line_state()`, add:

```gdscript
## The colour tray's entries in order, [] when unsupported:
## {"colour": Color, "mark": int (1..7, the pip count), "enabled": bool}.
func palette() -> Array[Dictionary]: return []
## The player chose tray entry `i`. True when a peg was placed.
func pick(_i: int) -> bool: return false
```

Also extend the comment above `capabilities()` to read `any of "undo", "hint", "check", "lines", "palette"`.

- [ ] **Step 2: Wood card in `ui/theme.gd`**

Append:

```gdscript
static func wood_card() -> StyleBoxFlat:
	return card(Pal.WOOD, 28, Pal.WOOD_DEEP, 8, 16)
```

- [ ] **Step 3: Create `ui/hud/peg_button.gd`**

```gdscript
extends Button

## One colour on the tray: a toon disc in the peg's colour with its pip mark
## and a darker lower crescent for the shadow band, dimmed when the puzzle is
## not taking picks, squishing on press like IconButton.
## Spec: docs/superpowers/specs/2026-09-14-codebreak-3d-design.md, section 3.

const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Shapes = preload("res://core/shapes.gd")

const SIDE := 110.0
const DISC := 0.42
const SHADE := 0.25
const MARK_SHADE := 0.35
const RING := 4.0
const DIM := 0.45
const SQUASH := 0.10
const SQUASH_TIME := 0.18

var colour: Color = Pal.PEGS[0]
var mark := 1
var _press_tw: Tween

func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(SIDE, SIDE)
	text = ""

func _ready() -> void:
	button_down.connect(_squish)
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5

func set_entry(colour_: Color, mark_: int, enabled: bool) -> void:
	colour = colour_
	mark = mark_
	disabled = not enabled
	queue_redraw()

func _squish() -> void:
	Motion.stop(_press_tw)
	scale = Vector2.ONE
	_press_tw = Motion.squash(self, SQUASH, SQUASH_TIME)

func _draw() -> void:
	var centre := size * 0.5
	var r := minf(size.x, size.y) * DISC
	var alpha := DIM if disabled else 1.0
	var fill := Color(colour, alpha)
	draw_circle(centre, r + RING, Color(Pal.OUTLINE, alpha))
	# The shadow band: a darker disc, then the lit disc drawn a little higher
	# over it, leaving a dark crescent along the bottom.
	draw_circle(centre, r, Color(colour.darkened(SHADE), alpha))
	draw_circle(centre - Vector2(0.0, r * 0.1), r * 0.88, fill)
	Shapes.draw_pips(self, mark, centre - Vector2(0.0, r * 0.12), r * 0.3, r * 0.1,
		Color(colour.darkened(MARK_SHADE), alpha))
```

- [ ] **Step 4: Create `ui/hud/palette_tray.gd`**

```gdscript
extends PanelContainer

## The wooden colour tray: one PegButton per palette entry, in order. Reads
## PuzzleBase.palette(); the action bar hides it for puzzles without one.
## Spec: docs/superpowers/specs/2026-09-14-codebreak-3d-design.md, section 3.

signal pick(index: int)

const CozyTheme = preload("res://ui/theme.gd")
const PegButton = preload("res://ui/hud/peg_button.gd")

const GAP := 14

var buttons: Array = []
var _row: HBoxContainer

func _ready() -> void:
	add_theme_stylebox_override("panel", CozyTheme.wood_card())
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", GAP)
	add_child(_row)

## Rebuilds the buttons when the palette's size changes (a new puzzle), then
## updates every entry's colour, mark and enabled state.
func refresh(puzzle) -> void:
	var entries: Array = puzzle.palette() if puzzle != null else []
	if entries.size() != buttons.size():
		for b in buttons:
			_row.remove_child(b)
			b.queue_free()
		buttons = []
		for i in entries.size():
			var b := PegButton.new()
			b.name = "Peg%d" % i
			b.pressed.connect(func() -> void: pick.emit(i))
			_row.add_child(b)
			buttons.append(b)
	for i in entries.size():
		var e: Dictionary = entries[i]
		buttons[i].set_entry(e.colour, int(e.mark), bool(e.enabled))
```

- [ ] **Step 5: The action bar grows a tray row**

Rewrite `ui/hud/action_bar.gd` as:

```gdscript
extends "res://ui/hud/panel.gd"

## The bottom rows: the colour tray above (palette puzzles only), then the
## working-line card, Reset in slate and Check in sun. Whatever the puzzle
## does not support is hidden and the rest takes its space.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5;
## docs/superpowers/specs/2026-09-14-codebreak-3d-design.md, section 3.

signal reset
signal check
signal pick(index: int)

const IconButton = preload("res://ui/hud/icon_button.gd")
const LineCard = preload("res://ui/hud/line_card.gd")
const PaletteTray = preload("res://ui/hud/palette_tray.gd")

const BUTTON := Vector2(260, 130)
const ALL_GOOD_TIME := 1.2

var tray: PanelContainer
var line_card: PanelContainer
var reset_button: Button
var check_button: Button
var _row: HBoxContainer
var _all_good: Tween

func _init() -> void:
	enter_from = Vector2(0, 100)

func _make_inner() -> Container:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	return col

func _build() -> void:
	tray = PaletteTray.new()
	tray.name = "Tray"
	tray.visible = false
	tray.pick.connect(func(i: int) -> void: pick.emit(i))
	_inner.add_child(tray)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 20)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_inner.add_child(_row)
	line_card = LineCard.new()
	_row.add_child(line_card)
	reset_button = IconButton.new("reset", "Reset", "DarkButton")
	reset_button.custom_minimum_size = BUTTON
	reset_button.pressed.connect(func() -> void: reset.emit())
	_row.add_child(reset_button)
	check_button = IconButton.new("check", "Check", "PrimaryButton")
	check_button.custom_minimum_size = BUTTON
	check_button.pressed.connect(func() -> void: check.emit())
	_row.add_child(check_button)

func refresh(puzzle) -> void:
	var caps: Array = puzzle.capabilities() if puzzle != null else []
	var done: bool = puzzle != null and puzzle.is_done()
	tray.visible = caps.has("palette")
	tray.refresh(puzzle if tray.visible else null)
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

- [ ] **Step 6: Host wiring in `ui/puzzle_host.gd`**

In `_ready`, right after `action_bar.check.connect(_on_check)`, add:

```gdscript
	action_bar.pick.connect(_on_pick)
```

Replace `_on_check` with:

```gdscript
func _on_check() -> void:
	if is_instance_valid(_puzzle):
		var wrong: int = _puzzle.check()
		# A winning Check ends the game under the solved card; only a clean
		# check on a live board earns the "All good" squash.
		if wrong == 0 and not _puzzle.is_done():
			action_bar.all_good()
		_refresh()
```

After `_on_check`, add:

```gdscript
func _on_pick(i: int) -> void:
	if is_instance_valid(_puzzle):
		_puzzle.pick(i)
		_refresh()
```

- [ ] **Step 7: Suite and a throwaway tray check**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `passed=N failed=0`, N unchanged from Task 1.

Write `/tmp/tray_check.gd` (throwaway, not committed):

```gdscript
extends SceneTree

const ActionBar = preload("res://ui/hud/action_bar.gd")

class Stub extends PuzzleBase:
	var picked: Array = []
	func capabilities() -> Array[String]: return ["check", "palette"]
	func palette() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for i in 6:
			out.append({"colour": Color.RED, "mark": i + 1, "enabled": true})
		return out
	func pick(i: int) -> bool:
		picked.append(i)
		return true

func _initialize() -> void:
	var bar := ActionBar.new()
	root.add_child(bar)
	var stub := Stub.new()
	bar.pick.connect(func(i: int) -> void: stub.pick(i))
	bar.refresh(stub)
	assert(bar.tray.visible, "tray shows for a palette puzzle")
	assert(bar.tray.buttons.size() == 6, "six buttons")
	assert(not bar.line_card.visible, "no line card without lines")
	bar.tray.buttons[3].pressed.emit()
	assert(stub.picked == [3], "pick forwards the index, got %s" % [stub.picked])
	var plain := PuzzleBase.new()
	bar.refresh(plain)
	assert(not bar.tray.visible, "tray hides for a plain puzzle")
	print("tray ok")
	quit(0)
```

Run: `godot --headless --path . --script /tmp/tray_check.gd 2>&1 | tail -2`
Expected: `tray ok`.

- [ ] **Step 8: Binairo unchanged on screen**

Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd > /tmp/shot.log 2>&1; git checkout project.godot 2>/dev/null; grep saved /tmp/shot.log | head -3`
Open `/tmp/shot_binairo.png`: the action bar is the line card, Reset and Check on one row, no tray.

- [ ] **Step 9: Commit**

Godot writes a `.uid` beside each new script on import; generate and track them:

```bash
godot --headless --path . --import > /dev/null 2>&1; git checkout project.godot 2>/dev/null
git add core/puzzle_base.gd ui/theme.gd ui/hud/peg_button.gd ui/hud/peg_button.gd.uid ui/hud/palette_tray.gd ui/hud/palette_tray.gd.uid ui/hud/action_bar.gd ui/puzzle_host.gd
git commit -m "feat: a colour tray in the HUD behind a palette capability

PuzzleBase.palette() lists tray entries and pick(i) takes one. The action
bar becomes two rows, the wooden tray of PegButtons above the line card,
Reset and Check, shown only for puzzles that declare palette; the host
forwards picks. A winning Check no longer squashes All good under the
solved card."
```

---

### Task 3: The Code Break board

**Files:**
- Create: `puzzles/codebreak3d.gd`
- Delete: `puzzles/mastermind.gd`, `puzzles/mastermind.gd.uid`
- Modify: `ui/registry.gd` (the `mastermind` entry)
- Modify: `tests/_win.gd` (`_note`, `_solve_mastermind`)

**Interfaces:**
- Consumes: everything Task 1 and Task 2 produce; `PuzzleBase3D` (`board`, `_stage`, `_refit`, `board_to_local`, `on_board_press`), `BoardMath.cell_center / world_to_cell`, `Platform.build(cols, rows)` and `Platform.LIP`, `Fx.puff / sparkle / cue`, `Gen.make_code / score` from `puzzles/mastermind_gen.gd`.
- Produces: `puzzles/codebreak3d.gd` with `length`, `palette_size`, `max_guesses`, `_code`, `_guesses`, `cell_to_local(g, s)`, the capability methods; the registry entry pointing at it.

- [ ] **Step 1: Create `puzzles/codebreak3d.gd`**

```gdscript
extends "res://core/puzzle_base_3d.gd"

## Code Break on the island stage. Eight guess rows of socket slabs stand on
## the platform under a shielded code row: the code's pegs sit hidden under
## stone lids on row 0 and the guesses fill rows 1 to 8 from the far edge
## toward the player. A colour picked on the HUD's tray drops a peg into the
## first empty slot of the active row; a tap on a placed peg pops it out;
## Check scores the row on its feedback slab -- a slate pip per right colour
## in the right place, a cream pip per right colour in the wrong place -- and
## the next row takes the lighter tint and starts to breathe. When the game
## ends the lids slide off the far edge into the sea. Every peg is a tinted
## dome carrying one of seven pip marks, so colour never stands alone.
## Spec: docs/superpowers/specs/2026-09-14-codebreak-3d-design.md.

const Gen = preload("res://puzzles/mastermind_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Platform = preload("res://core/platform.gd")
const Motion = preload("res://core/motion.gd")
const Fx = preload("res://world/fx.gd")

const CODE_ROW := 0
const HINTS := 3
const MARKS := 7
const PIP_GAP := 0.26
## Tints (spec section 1): the socket blend runs 0 (STONE, active) to 1
## (STONE_GIVEN, resting) on an 8-step grid.
const ROW_FADE := 0.3
const ROW_STEPS := 8
const MARK_SHADE := 0.35
## Motion (spec section 4).
const BREATH_RISE := 0.02
const BREATH_PERIOD := 2.4
const PLACE_DROP := 0.5
const PLACE_TIME := 0.3
const POP_LIFT := 0.25
const POP_TIME := 0.22
const NUDGE_HOP := 0.05
const NUDGE_TIME := 0.25
const DIP := 0.02
const DIP_TIME := 0.35
const COMMIT_DIP := 0.03
const BALL_POP := 0.25
const BALL_STAGGER := 0.06
const WOBBLE_ANGLE := 0.1
const WOBBLE_TIME := 0.4
const LID_SLIDE := 1.3
const LID_SLIDE_TIME := 0.4
const LID_FALL := 4.0          # Stage.WATER_DEPTH: the lid sinks to the water
const LID_FALL_TIME := 0.5
const LID_STAGGER := 0.12
const LID_DROP := 0.6
const LID_DROP_TIME := 0.45
const LID_RETURN_STAGGER := 0.06
const SOLVE_HOP := 0.08
const SOLVE_TIME := 0.4
const SOLVE_STAGGER := 0.05
const ENTER_DROP := 0.5
const ENTER_PLATFORM := 0.5
const ENTER_POP := 0.25
const ENTER_STAGGER := 0.02
const ENTER_LIDS := 0.3
const RESET_STAGGER := 0.02
const SPARKLE_LIFT := 0.1
const LOCKED_STAGGER := 0.05

var length: int = 4
var palette_size: int = 6
var max_guesses: int = 8

var _code: Array = []
var _guesses: Array = []
var _marks: Array = []
var _row: Array = []          # the active row's colours, -1 empty
var _locked: Array = []       # per slot: filled by a hint, fixed for the game
var _revealed := false
## Places and pops in the active row, newest last; undo pops one.
var _history: Array[Dictionary] = []

# --- scene ---
var fx: Node3D                # pooled one-shot particles, a child of the board
var _pivots: Array = []       # [g][s] -> Node3D at the cell centre: dips, wobbles
var _breaths: Array = []      # [g][s] -> Node3D under the pivot: the active row's rise
var _sockets: Array = []      # [g][s] -> socket model
var _pegs: Array = []         # [g][s] -> peg model or null
var _feedback: Array = []     # [g] -> feedback slab
var _pips: Array = []         # [g][k] -> pip model on the slab
var _lids: Array = []         # [s] -> lid over code slot s
var _lid_gone: Array = []     # [s] -> true once the lid has slid off
var _code_pegs: Array = []    # [s] -> the code peg, hidden until revealed
# --- tweens ---
var _dips: Array = []         # [g][s]
var _wobbles: Array = []      # [g][s]
var _peg_tw: Array = []       # [g][s] the peg's drop, hop or nudge
var _breath_tw: Array = []    # [g][s]
var _fades: Array = []        # [g][s] socket tint fade
var _blend: Array = []        # [g][s] painted blend, 0 active .. 1 resting
var _pip_tw: Array = []       # [g][k]
var _lid_tw: Array = []       # [s]
var _code_tw: Array = []      # [s]
var _entrance: Array = []     # the board entrance, killed by reset

func _ready() -> void:
	super()
	solved.connect(_on_solved)

func puzzle_id() -> String: return "mastermind"
func title() -> String: return "Code Break"

func rules() -> String:
	var count := "five" if length == 5 else "four"
	return "Crack the hidden row of %s colours. Fill a row from the tray and press Check. A slate pip is a right colour in the right place, a cream pip a right colour in the wrong place." % count

func board_size() -> Vector2i: return Vector2i(length + 1, max_guesses + 1)
## A socket with a peg on it; nothing stands higher at rest. A placed peg
## drops from PLACE_DROP above, which the camera's margin absorbs.
func board_height() -> float: return Placeholders.SOCKET_H + Placeholders.PEG_H + 0.04
func plane_height() -> float: return Placeholders.SOCKET_H
func board_margin() -> float: return Platform.LIP
func board_depth() -> float: return Placeholders.PLATFORM_H

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var repeats := true
	match difficulty:
		0: length = 4; palette_size = 6; repeats = false
		1: length = 4; palette_size = 6; repeats = true
		_: length = 5; palette_size = 7; repeats = true
	max_guesses = 8
	_code = Gen.make_code(rng, length, palette_size, repeats)
	_guesses = []
	_marks = []
	_revealed = false
	_history = []
	_row = []
	_locked = []
	for s in length:
		_row.append(-1)
		_locked.append(false)
	_build_scene()
	_activate_row(0, true)
	_refit()
	_enter()

## Reset as a wave: every peg in a guess row vanishes from the far row to the
## near one, the pips hide, any lid that slid off drops back, and the first
## row takes the active tint again. Hints already used stay used.
func reset_board() -> void:
	_stop_entrance()
	for g in max_guesses:
		for s in length:
			_settle(g, s)
			_vanish_peg(g, s, Motion.stagger(g * length + s, RESET_STAGGER))
		for k in length:
			Motion.stop(_pip_tw[g][k])
			_pip_tw[g][k] = null
			Models.set_layer_visible(_pips[g][k], "Pip_Ball", false)
	for s in length:
		_lid_back(s, Motion.stagger(s, LID_RETURN_STAGGER))
		_locked[s] = false
		_row[s] = -1
	_guesses = []
	_marks = []
	_history = []
	_revealed = false
	_running = true
	moves = 0
	_activate_row(0)
	fx.cue("reset")

func is_solved() -> bool:
	return _marks.size() > 0 and int(_marks[-1].exact) == length

func share_glyphs() -> String:
	# Structurally identical to Wordle's share grid, with zero language content.
	var out := ""
	for m in _marks:
		out += "🟩".repeat(int(m.exact)) + "🟨".repeat(int(m.colour))
		out += "⬛".repeat(length - int(m.exact) - int(m.colour)) + "\n"
	return out

# --- capabilities (HUD spec section 3, codebreak spec sections 2 and 3) ---

func capabilities() -> Array[String]:
	return ["undo", "hint", "check", "palette"]

## The board takes picks, pops, undos and hints: not solved, not lost.
func _open() -> bool:
	return not is_done() and not _revealed

## Index of the active guess; its board row is one more.
func _active() -> int:
	return _guesses.size()

func palette() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in palette_size:
		out.append({"colour": Pal.PEGS[i % Pal.PEGS.size()], "mark": i + 1, "enabled": _open()})
	return out

## A tray colour drops into the first empty, unlocked slot of the active row.
## With none free the row's pegs nudge and nothing is placed.
func pick(i: int) -> bool:
	if not _open() or i < 0 or i >= palette_size:
		return false
	var g := _active()
	var slot := _free_slot()
	if slot < 0:
		for s in length:
			var peg: Node3D = _pegs[g][s]
			if peg == null:
				continue
			Motion.stop(_peg_tw[g][s])
			peg.position.y = Placeholders.SOCKET_H
			_peg_tw[g][s] = Motion.hop(peg, NUDGE_HOP, NUDGE_TIME, 0.0, Placeholders.SOCKET_H)
		fx.cue("full")
		return false
	_row[slot] = i
	_history.append({"op": "place", "slot": slot, "colour": i})
	_place(g, slot, i)
	moved.emit()
	return true

func _free_slot() -> int:
	for s in length:
		if _row[s] == -1 and not _locked[s]:
			return s
	return -1

func can_undo() -> bool:
	return _open() and not _history.is_empty()

## Takes back the last place or pop in the active row. Submitted guesses
## stay: their feedback is information the player has already seen.
func undo() -> bool:
	if not _open() or _history.is_empty():
		return false
	var last: Dictionary = _history.pop_back()
	var g := _active()
	var s: int = int(last.slot)
	if last.op == "place":
		_row[s] = -1
		_vanish_peg(g, s)
	else:
		_row[s] = int(last.colour)
		_place(g, s, int(last.colour))
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Reveals the leftmost code slot not yet revealed: its lid slides off, the
## code peg drops into the active row there with a sparkle, and the slot is
## locked so every later row starts with it in place. Counts no move; not
## refunded by reset.
func hint() -> bool:
	if not _open() or hints_left() <= 0:
		return false
	var slot := -1
	for s in length:
		if not _locked[s]:
			slot = s
			break
	if slot < 0:
		return false
	var g := _active()
	_locked[slot] = true
	_lid_away(slot)
	var kept: Array[Dictionary] = []
	for h in _history:
		if int(h.slot) != slot:
			kept.append(h)
	_history = kept
	_vanish_peg(g, slot)
	_row[slot] = _code[slot]
	_place(g, slot, _code[slot])
	fx.sparkle(_cell(g, slot, Placeholders.SOCKET_H + SPARKLE_LIFT))
	hints_used += 1
	fx.cue("hint")
	moved.emit()
	return true

## Check submits the active row. An incomplete row only wobbles its empty
## sockets and returns -1. A full row is scored and locked; then the game is
## won, lost, or the next row activates. Returns the count of wrong places.
func check() -> int:
	if not _open():
		return -1
	checks += 1
	var g := _active()
	var missing := false
	for s in length:
		if _row[s] != -1:
			continue
		missing = true
		Motion.stop(_wobbles[g][s])
		_pivots[g][s].rotation.z = 0.0
		_wobbles[g][s] = Motion.wobble(_pivots[g][s], WOBBLE_ANGLE, WOBBLE_TIME)
	if missing:
		fx.cue("check")
		return -1
	var m: Dictionary = Gen.score(_row, _code)
	_guesses.append(_row.duplicate())
	_marks.append(m)
	_history = []
	_score_row(g, m)
	var fresh := []
	for s in length:
		fresh.append(-1)
	_row = fresh
	if int(m.exact) == length:
		pass  # note_move ends the game; _on_solved does the rest
	elif _guesses.size() >= max_guesses:
		_lose()
	else:
		_activate_row(g + 1)
	note_move()
	return length - int(m.exact)

# --- scene ---

## Kills every tween the previous board still tracks, so a rebuild never
## inherits motion aimed at nodes about to go.
func _stop_all() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for rows in [_dips, _wobbles, _peg_tw, _breath_tw, _fades, _pip_tw]:
		for row in rows:
			for tw in row:
				Motion.stop(tw)
	for tws in [_lid_tw, _code_tw]:
		for tw in tws:
			Motion.stop(tw)

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_pivots = []
	_breaths = []
	_sockets = []
	_pegs = []
	_feedback = []
	_pips = []
	_lids = []
	_lid_gone = []
	_code_pegs = []
	_dips = []
	_wobbles = []
	_peg_tw = []
	_breath_tw = []
	_fades = []
	_blend = []
	_pip_tw = []
	_lid_tw = []
	_code_tw = []

	var size := board_size()
	board.add_child(Platform.build(size.x, size.y))
	fx = Fx.new()
	board.add_child(fx)

	for g in max_guesses:
		var pivots := []
		var breaths := []
		var sockets := []
		var pegs := []
		var dips := []
		var wobbles := []
		var peg_tw := []
		var breath_tw := []
		var fades := []
		var blend := []
		for s in length:
			# The pivot carries the dip and the Check wobble; the breath under
			# it carries the active row's rise; the socket and the peg ride
			# both, so no node ever runs two height tweens.
			var pivot := Node3D.new()
			pivot.name = "cell_%d_%d" % [g, s]
			pivot.position = _cell(g, s, 0.0)
			board.add_child(pivot)
			var breath := Node3D.new()
			breath.name = "breath"
			pivot.add_child(breath)
			var socket := Models.instance("socket")
			breath.add_child(socket)
			pivots.append(pivot)
			breaths.append(breath)
			sockets.append(socket)
			pegs.append(null)
			dips.append(null)
			wobbles.append(null)
			peg_tw.append(null)
			breath_tw.append(null)
			fades.append(null)
			blend.append(1.0)
		_pivots.append(pivots)
		_breaths.append(breaths)
		_sockets.append(sockets)
		_pegs.append(pegs)
		_dips.append(dips)
		_wobbles.append(wobbles)
		_peg_tw.append(peg_tw)
		_breath_tw.append(breath_tw)
		_fades.append(fades)
		_blend.append(blend)
		# The feedback slab: a socket without its well, always resting tint,
		# with `length` pips on it, two across.
		var slab := Models.instance("socket")
		slab.name = "feedback_%d" % g
		slab.position = _cell(g, length, 0.0)
		Models.set_layer_visible(slab, "Socket_Well", false)
		Models.tint_named(slab, "Stone", Pal.STONE_GIVEN)
		board.add_child(slab)
		_feedback.append(slab)
		var pips := []
		var pip_tw := []
		for k in length:
			var pip := Models.instance("pip")
			pip.name = "pip_%d" % k
			pip.position = _pip_offset(k, Placeholders.SOCKET_H + Placeholders.WELL_PROUD)
			Models.set_layer_visible(pip, "Pip_Ball", false)
			slab.add_child(pip)
			pips.append(pip)
			pip_tw.append(null)
		_pips.append(pips)
		_pip_tw.append(pip_tw)

	# The code row: a hidden peg per slot under a lid.
	for s in length:
		var peg := _make_peg(int(_code[s]))
		peg.name = "code_%d" % s
		peg.position = _code_pos(s)
		peg.visible = false
		board.add_child(peg)
		_code_pegs.append(peg)
		_code_tw.append(null)
		var lid := Models.instance("lid")
		lid.name = "lid_%d" % s
		lid.position = _code_pos(s)
		board.add_child(lid)
		_lids.append(lid)
		_lid_tw.append(null)
		_lid_gone.append(false)

	for g in max_guesses:
		for s in length:
			_paint(1.0, g, s)

## Board-space centre of guess `g`, slot `s` (the feedback slab is slot `length`).
func _cell(g: int, s: int, y: float) -> Vector3:
	var size := board_size()
	return BoardMath.cell_center(g + 1, s, size.x, size.y, y)

func _code_pos(s: int) -> Vector3:
	var size := board_size()
	return BoardMath.cell_center(CODE_ROW, s, size.x, size.y, 0.0)

## Where pip `k` sits on its slab: two columns, ceil(length / 2) rows, centred;
## an odd last pip takes the middle.
func _pip_offset(k: int, y: float) -> Vector3:
	var deep := (length + 1) / 2
	var col := k % 2
	var row := k / 2
	var x := (col - 0.5) * PIP_GAP
	if length % 2 == 1 and k == length - 1:
		x = 0.0
	var z := (row - (deep - 1) * 0.5) * PIP_GAP
	return Vector3(x, y, z)

## A peg of colour index `colour`: the dome tinted, its mark a darker shade,
## and only the matching one of the seven marks shown.
func _make_peg(colour: int) -> Node3D:
	var peg := Models.instance("peg")
	var c: Color = Pal.PEGS[colour % Pal.PEGS.size()]
	Models.tint_named(peg, "Shell", c)
	Models.tint_named(peg, "Mark_flat", c.darkened(MARK_SHADE))
	for k in range(1, MARKS + 1):
		Models.set_layer_visible(peg, "Peg_Mark_%d" % k, k == colour + 1)
	return peg

# --- pieces ---

## Drops a peg of `colour` onto socket (g, s), replacing whatever is there at
## once. The drop is the state change, so it is essential and survives
## reduce-motion shortened.
func _place(g: int, s: int, colour: int, delay := 0.0) -> void:
	_clear_peg(g, s)
	var peg := _make_peg(colour)
	peg.name = "peg"
	peg.position = Vector3(0.0, Placeholders.SOCKET_H + PLACE_DROP, 0.0)
	_breaths[g][s].add_child(peg)
	_pegs[g][s] = peg
	var tw: Tween = Motion.settle(peg, "position:y", Placeholders.SOCKET_H, PLACE_TIME, delay, true)
	if tw != null:
		tw.finished.connect(_on_peg_landed.bind(g, s))
		_peg_tw[g][s] = tw
	else:
		_on_peg_landed(g, s)
	fx.cue("place")

func _on_peg_landed(g: int, s: int) -> void:
	fx.puff(_cell(g, s, Placeholders.SOCKET_H))
	fx.cue("land")

## Removes the peg on (g, s) at once, no motion.
func _clear_peg(g: int, s: int) -> void:
	Motion.stop(_peg_tw[g][s])
	_peg_tw[g][s] = null
	var peg: Node3D = _pegs[g][s]
	if peg != null:
		peg.queue_free()
		_pegs[g][s] = null

## The pop: the peg lifts and shrinks away, then is freed. The slot forgets it
## at once, so a place that follows never fights it.
func _vanish_peg(g: int, s: int, delay := 0.0) -> void:
	var peg: Node3D = _pegs[g][s]
	if peg == null:
		return
	Motion.stop(_peg_tw[g][s])
	_peg_tw[g][s] = null
	_pegs[g][s] = null
	var tw: Tween = Motion.vanish(peg, POP_LIFT, POP_TIME, delay)
	if tw == null:
		peg.queue_free()
	else:
		tw.finished.connect(peg.queue_free)

## Scores guess `g` on its slab: the row's sockets dip together, then one ball
## per hit pops in, slate for exact then cream for colour, with a sparkle
## when anything was exact.
func _score_row(g: int, m: Dictionary) -> void:
	for s in length:
		_dip(g, s, COMMIT_DIP)
	var exact := int(m.exact)
	var hits := exact + int(m.colour)
	for k in hits:
		var pip: Node3D = _pips[g][k]
		Models.tint_named(pip, "Pip", Pal.SLATE if k < exact else Pal.MOON)
		Models.set_layer_visible(pip, "Pip_Ball", true)
		var ball := pip.find_child("Pip_Ball", true, false)
		if ball is Node3D:
			(ball as Node3D).scale = Vector3.ONE * 0.01
			Motion.stop(_pip_tw[g][k])
			_pip_tw[g][k] = Motion.settle(ball, "scale", Vector3.ONE, BALL_POP, Motion.stagger(k, BALL_STAGGER))
			if _pip_tw[g][k] == null:
				(ball as Node3D).scale = Vector3.ONE
	if exact > 0:
		fx.sparkle(_cell(g, length, Placeholders.SOCKET_H + SPARKLE_LIFT))
	fx.cue("score")

## Row `g` becomes the active one: its sockets fade to STONE and breathe, every
## other row rests in STONE_GIVEN and stands still, and each locked slot gets
## its code peg. `g == max_guesses` means no row is active (the game is lost).
## `instant` paints without a fade (the first build).
func _activate_row(g: int, instant := false) -> void:
	for gg in max_guesses:
		var active := gg == g
		var target := 0.0 if active else 1.0
		for s in length:
			Motion.stop(_breath_tw[gg][s])
			_breath_tw[gg][s] = null
			_breaths[gg][s].position.y = 0.0
			if instant:
				Motion.stop(_fades[gg][s])
				_fades[gg][s] = null
				_paint(target, gg, s)
			elif not is_equal_approx(_blend[gg][s], target):
				Motion.stop(_fades[gg][s])
				_fades[gg][s] = Motion.fade(_sockets[gg][s], _paint.bind(gg, s), _blend[gg][s], target, ROW_FADE, ROW_STEPS)
			if active:
				_breath_tw[gg][s] = Motion.pulse(_breaths[gg][s], "position:y", 0.0, BREATH_RISE, BREATH_PERIOD)
	if g >= max_guesses:
		return
	for s in length:
		if _locked[s] and _row[s] == -1:
			_row[s] = _code[s]
			_place(g, s, int(_code[s]), Motion.stagger(s, LOCKED_STAGGER))

## The socket's tint at a blend from STONE (0) to STONE_GIVEN (1), snapped to
## the 8-step grid so a fade asks the toon cache for at most nine colours.
func _paint(blend: float, g: int, s: int) -> void:
	blend = roundf(blend * ROW_STEPS) / ROW_STEPS
	_blend[g][s] = blend
	Models.tint_named(_sockets[g][s], "Stone", Pal.STONE.lerp(Pal.STONE_GIVEN, blend))

## The lid over code slot `s` slides off the far edge, falls to the water and
## rings it; the code peg pops in beneath as the slide ends.
func _lid_away(s: int, delay := 0.0) -> void:
	if _lid_gone[s]:
		return
	_lid_gone[s] = true
	var lid: Node3D = _lids[s]
	Motion.stop(_lid_tw[s])
	var rest := _code_pos(s)
	lid.position = rest
	lid.visible = true
	var tw: Tween = Motion.slide(lid, "position:z", rest.z, rest.z - LID_SLIDE, LID_SLIDE_TIME, delay, false)
	if tw == null:
		lid.visible = false
		_show_code_peg(s, 0.0)
		return
	tw.tween_property(lid, "position:y", rest.y - LID_FALL, LID_FALL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_on_lid_sunk.bind(s))
	_lid_tw[s] = tw
	_show_code_peg(s, delay + LID_SLIDE_TIME)
	fx.cue("lid")

func _on_lid_sunk(s: int) -> void:
	var lid: Node3D = _lids[s]
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(lid.global_position)
	lid.visible = false
	fx.cue("splash")

func _show_code_peg(s: int, delay: float) -> void:
	var peg: Node3D = _code_pegs[s]
	Motion.stop(_code_tw[s])
	peg.visible = true
	peg.scale = Vector3.ONE * 0.01
	_code_tw[s] = Motion.settle(peg, "scale", Vector3.ONE, ENTER_POP, delay)
	if _code_tw[s] == null:
		peg.scale = Vector3.ONE

## A lid that slid off drops back onto its slot (reset); the code peg hides.
func _lid_back(s: int, delay := 0.0) -> void:
	Motion.stop(_code_tw[s])
	_code_tw[s] = null
	_code_pegs[s].visible = false
	if not _lid_gone[s]:
		return
	_lid_gone[s] = false
	var lid: Node3D = _lids[s]
	Motion.stop(_lid_tw[s])
	var rest := _code_pos(s)
	lid.visible = true
	lid.position = rest + Vector3(0.0, LID_DROP, 0.0)
	_lid_tw[s] = Motion.settle(lid, "position:y", rest.y, LID_DROP_TIME, delay)
	if _lid_tw[s] == null:
		lid.position = rest

# --- motion helpers ---

## A dip and return on socket (g, s), replacing any dip already on it.
func _dip(g: int, s: int, depth: float) -> void:
	Motion.stop(_dips[g][s])
	_pivots[g][s].position.y = 0.0
	_dips[g][s] = Motion.hop(_pivots[g][s], -depth, DIP_TIME, 0.0, 0.0)

## Ends every motion on cell (g, s) at once: the socket flat and level, the
## peg (if any) seated at full size.
func _settle(g: int, s: int) -> void:
	Motion.stop(_dips[g][s])
	Motion.stop(_wobbles[g][s])
	Motion.stop(_peg_tw[g][s])
	_dips[g][s] = null
	_wobbles[g][s] = null
	_peg_tw[g][s] = null
	var pivot: Node3D = _pivots[g][s]
	pivot.position.y = 0.0
	pivot.rotation.z = 0.0
	var peg: Node3D = _pegs[g][s]
	if peg != null:
		peg.position.y = Placeholders.SOCKET_H
		peg.scale = Vector3.ONE

## The board arrives: the platform rises and rings the water, the sockets and
## slabs pop in along a diagonal wave, then the lids drop onto the code row.
func _enter() -> void:
	_stop_entrance()
	var platform: Node3D = board.get_node("Platform")
	platform.position.y = -ENTER_DROP
	var rise: Tween = Motion.settle(platform, "position:y", 0.0, ENTER_PLATFORM)
	if rise != null:
		_entrance.append(rise)
		var splash := board.create_tween()
		splash.tween_interval(ENTER_PLATFORM * 0.9)
		splash.tween_callback(_splash)
		_entrance.append(splash)
	for g in max_guesses:
		for s in length:
			_pop_in(_pivots[g][s], ENTER_PLATFORM + Motion.stagger(g + s, ENTER_STAGGER))
		_pop_in(_feedback[g], ENTER_PLATFORM + Motion.stagger(g + length, ENTER_STAGGER))
	for s in length:
		if _lid_gone[s]:
			continue
		var lid: Node3D = _lids[s]
		var rest := _code_pos(s)
		lid.position = rest + Vector3(0.0, LID_DROP, 0.0)
		var drop: Tween = Motion.settle(lid, "position:y", rest.y, LID_DROP_TIME,
			ENTER_PLATFORM + ENTER_LIDS + Motion.stagger(s, LID_RETURN_STAGGER))
		if drop != null:
			_entrance.append(drop)
	fx.cue("enter")

func _pop_in(node: Node3D, delay: float) -> void:
	node.scale = Vector3.ONE * 0.01
	var pop: Tween = Motion.settle(node, "scale", Vector3.ONE, ENTER_POP, delay)
	if pop != null:
		_entrance.append(pop)

## Cuts the entrance short: everything lands where it was going.
func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	if _pivots.is_empty():
		return
	var platform: Node3D = board.get_node_or_null("Platform")
	if platform != null:
		platform.position.y = 0.0
	for g in max_guesses:
		for s in length:
			_pivots[g][s].scale = Vector3.ONE
		_feedback[g].scale = Vector3.ONE
	for s in length:
		if not _lid_gone[s]:
			_lids[s].position = _code_pos(s)

## Rings the water under the board, when there is a stage to ask.
func _splash() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(board.global_position)

## The guess matched: the lids slide off one by one and the winning row's
## pegs hop in a wave. Its sockets keep the active tint; the breathing stops.
func _on_solved() -> void:
	var g := _guesses.size() - 1
	for gg in max_guesses:
		for s in length:
			Motion.stop(_breath_tw[gg][s])
			_breath_tw[gg][s] = null
			_breaths[gg][s].position.y = 0.0
	for s in length:
		_lid_away(s, Motion.stagger(s, LID_STAGGER))
		var peg: Node3D = _pegs[g][s]
		if peg == null:
			continue
		Motion.stop(_peg_tw[g][s])
		peg.position.y = Placeholders.SOCKET_H
		_peg_tw[g][s] = Motion.hop(peg, SOLVE_HOP, SOLVE_TIME, Motion.stagger(s, SOLVE_STAGGER), Placeholders.SOCKET_H)
	fx.cue("solved")

## Out of guesses: the lids slide off to show the code, the timer stops, and
## the board goes quiet until reset.
func _lose() -> void:
	_revealed = true
	_running = false
	_activate_row(max_guesses)
	for s in length:
		_lid_away(s, Motion.stagger(s, LID_STAGGER))
	fx.cue("reveal")

# --- input ---

## A tap on a placed, unlocked peg in the active row pops it; any other
## socket only dips. The feedback column and the code row do nothing.
func on_board_press(hit: Vector3) -> void:
	var size := board_size()
	var cell := BoardMath.world_to_cell(hit, size.x, size.y)
	if cell.x < 0 or cell.y == CODE_ROW or cell.x >= length:
		return
	var g := cell.y - 1
	var s := cell.x
	if _open() and g == _active() and _row[s] != -1 and not _locked[s]:
		_settle(g, s)
		_history.append({"op": "pop", "slot": s, "colour": _row[s]})
		_row[s] = -1
		_vanish_peg(g, s)
		fx.cue("pop")
		moved.emit()
		return
	_dip(g, s, DIP)
	fx.cue("focus")

## Control-local point over the centre of socket (g, s). The win harness
## checks the camera fit with this.
func cell_to_local(g: int, s: int) -> Vector2:
	return board_to_local(_cell(g, s, plane_height()))
```

- [ ] **Step 2: Registry and the old board**

In `ui/registry.gd`, replace the `mastermind` entry with:

```gdscript
	{
		"id": "mastermind",
		"title": "Code Break",
		"blurb": "Crack the hidden row from the feedback.",
		"motto": "Crack the hidden code",
		"footer": "Small puzzles · Brighter days",
		"script": "res://puzzles/codebreak3d.gd",
		"difficulties": [0, 1, 2],
	},
```

Then: `git rm -q puzzles/mastermind.gd puzzles/mastermind.gd.uid`

- [ ] **Step 3: The win harness drives the 3D board**

In `tests/_win.gd`, replace the `"mastermind"` line of `_note` with:

```gdscript
		"mastermind": return "cracked in %d guesses, camera fit=%s" % [_puzzle._guesses.size(), _fit_ok]
```

Replace `_solve_mastermind` with:

```gdscript
func _solve_mastermind() -> void:
	var length: int = _puzzle.length
	# Camera fit check: every socket centre must project inside the board slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for g in _puzzle.max_guesses:
		for s in length:
			if not slot.has_point(_puzzle.cell_to_local(g, s)):
				_fit_ok = false
	# The HUD's tray fills the active row with the code, then the real Check.
	var tray = _host.action_bar.tray
	for s in length:
		_press(tray.buttons[int(_puzzle._code[s])])
	_press(_host.action_bar.check_button)
```

- [ ] **Step 4: Suite, win harness, screenshot**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `passed=N failed=0`.

Run: `godot --path . --resolution 1080x1920 --script res://tests/_win.gd 2>&1 | tail -14; git checkout project.godot 2>/dev/null`
Expected: a `PASS  mastermind   solved=true done=true overlay=true  cracked in 1 guesses, camera fit=true` line and `winnable=10/10`.

Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd > /tmp/shot.log 2>&1; git checkout project.godot 2>/dev/null`
Open `/tmp/shot_mastermind.png` and compare with `docs/art/concept-codebreak.png`: eight rows of five slabs on the mossy platform, the top row covered by four lids, the first guess row lighter, the wooden tray of six discs above Reset and Check, no magenta. Note anything off for Task 5.

- [ ] **Step 5: Throwaway play-through**

Write `/tmp/codebreak_play.gd` (throwaway, not committed) and run it with `godot --headless --path . --script /tmp/codebreak_play.gd 2>&1 | tail -3`:

```gdscript
extends SceneTree

## Drives the board's public surface without a stage: pick, pop, undo, an
## incomplete check, a wrong guess, a hint, a loss, a reset, then a win.

func _initialize() -> void:
	var Motion = load("res://core/motion.gd")
	Motion.settings_path = "/tmp/codebreak_play.cfg"
	Motion.reduce = true  # instant motion; the logic is what is under test
	var script: GDScript = load("res://puzzles/codebreak3d.gd")
	var p = script.new()
	root.add_child(p)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	p.start(rng, 1)
	assert(p.length == 4 and p.max_guesses == 8 and p.palette_size == 6)
	assert(p.palette().size() == 6)
	assert(p.check() == -1, "empty row does not submit")
	assert(p.pick(2) and p._row[0] == 2, "first pick fills slot 0")
	assert(p.pick(3) and p._row[1] == 3)
	assert(p.undo() and p._row[1] == -1, "undo frees the slot")
	assert(not p.undo() or p._row[0] == -1)
	while p._free_slot() >= 0:
		p.pick(0)
	assert(not p.pick(0), "a full row takes no more")
	var before := p._guesses.size()
	var wrong: int = p.check()
	assert(p._guesses.size() == before + 1 and wrong >= 0, "a full row submits")
	assert(p.moves == 1, "a guess is one move")
	assert(p.hint(), "a hint places the code peg")
	assert(p._locked[0] and p._row[0] == p._code[0] and p.hints_used == 1)
	assert(p._lid_gone[0], "the hinted lid is gone")
	# Lose: slot 1 is unlocked, so a colour that is wrong there can never win.
	var miss := (int(p._code[1]) + 1) % p.palette_size
	var guard := 0
	while not p._revealed and guard < 20:
		guard += 1
		while p._free_slot() >= 0:
			p.pick(miss)
		p.check()
	assert(p._revealed and not p.is_done(), "the game is lost after eight guesses")
	assert(p._guesses.size() == 8)
	assert(not p.pick(0) and p.check() == -1 and not p.hint() and not p.undo(), "a lost board is quiet")
	p.reset_board()
	assert(p._guesses.is_empty() and not p._revealed and not p._locked[0] and not p._lid_gone[0], "reset restores the board")
	assert(p.hints_used == 1, "hints are not refunded")
	# Win: play the code.
	for s in p.length:
		p.pick(int(p._code[s]))
	assert(p.check() == 0 and p.is_done() and p.is_solved(), "the code wins")
	assert(p.share_glyphs().ends_with("🟩🟩🟩🟩\n"))
	print("codebreak play ok")
	quit(0)
```

Expected: `codebreak play ok` (a `PuzzleBase3D: no Stage` warning is fine; the harness runs without the stage).

- [ ] **Step 6: Commit**

```bash
godot --headless --path . --import > /dev/null 2>&1; git checkout project.godot 2>/dev/null
git add puzzles/codebreak3d.gd puzzles/codebreak3d.gd.uid ui/registry.gd tests/_win.gd
git commit -m "feat: Code Break is a stone board on the island

Eight guess rows of socket slabs under a lidded code row, tinted domes with
one of seven pip marks, a feedback slab of slate and cream pips per row. The
tray fills the next empty slot, a tap pops a peg, Check submits, hints lift
a lid and lock the slot, and the lids slide off into the sea when the game
ends. The 2D board is gone; the id and the share grid are unchanged."
```

---

### Task 4: The pieces in Blender

**Files:**
- Create: `art/codebreak.blend` (in the live Blender session)
- Create: `assets/models/socket.glb`, `peg.glb`, `pip.glb`, `lid.glb` (and their `.import` files, written by Godot)
- Modify: `tools/build_models.sh`, `.gitignore`, `docs/art/blender-contract.md`, `assets/models/README.md`

**Interfaces:**
- Consumes: the layer and material names from Task 1; the exporter budgets from Task 1.
- Produces: exports the game loads in place of the placeholders; docs rows.

This task runs through the Blender MCP (`mcp__blender__execute_blender_code`) against the live session. Run the snippets one at a time; after each, read the returned output. Blender is Z-up: model with Z as up and the exporter converts. Colours are given in sRGB hex and converted to linear in the snippet.

- [ ] **Step 1: A fresh file and the helpers**

```python
import bpy, bmesh, math
bpy.ops.wm.read_homefile(use_empty=True)
for c in list(bpy.data.collections):
    bpy.data.collections.remove(c)

def lin(hexstr):
    out = []
    for i in (0, 2, 4):
        c = int(hexstr[i:i+2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)

def material(name, hexstr):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin(hexstr)
    return m

def collection(name):
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    return col

def finish(obj, col, mat, bevel=True):
    for c in obj.users_collection:
        c.objects.unlink(obj)
    col.objects.link(obj)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth()
    if bevel:
        b = obj.modifiers.new("Bevel", "BEVEL")
        b.width = 0.02
        b.segments = 2
        b.harden_normals = False
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)

print("helpers ready")
```

Note: the helpers are plain Python names in the session; every following snippet is run in the same session and can use them. If the session restarts, run this step again (it also clears the scene).

- [ ] **Step 2: The socket**

```python
col = collection("Socket")
stone = material("Stone", "ede2cc")
well = material("Well_flat", "cbbd9f")
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.06))
body = bpy.context.active_object
body.name = "Socket_Body"
body.scale = (0.94, 0.94, 0.12)
finish(body, col, stone)
bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=0.003, vertices=48, location=(0, 0, 0.12))
disc = bpy.context.active_object
disc.name = "Socket_Well"
finish(disc, col, well, bevel=False)
print([o.name for o in col.objects])
```

- [ ] **Step 3: The peg with seven marks**

```python
col = collection("Peg")
shell = material("Shell", "e5484d")
mark = material("Mark_flat", "8f2d30")
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.3, segments=48, ring_count=24, location=(0, 0, 0.22))
dome = bpy.context.active_object
dome.name = "Peg_Body"
dome.scale = (1.0, 1.0, 0.22 / 0.3)
finish(dome, col, shell, bevel=False)
PIPS = [
    [(0, 0)],
    [(-1, -1), (1, 1)],
    [(-1, -1), (0, 0), (1, 1)],
    [(-1, -1), (1, -1), (-1, 1), (1, 1)],
    [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
    [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)],
    [(0, 0), (1, 0), (0.5, 0.87), (-0.5, 0.87), (-1, 0), (-0.5, -0.87), (0.5, -0.87)],
]
a, b, spread = 0.3, 0.22, 0.11
for k, layout in enumerate(PIPS, start=1):
    parts = []
    for (px, py) in layout:
        x, y = px * spread, py * spread
        d = math.hypot(x, y)
        z = b + b * math.sqrt(max(0.0, 1.0 - (d * d) / (a * a)))
        bpy.ops.mesh.primitive_cylinder_add(radius=0.035, depth=0.003, vertices=24, location=(x, -y, z))
        parts.append(bpy.context.active_object)
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    m = bpy.context.active_object
    m.name = "Peg_Mark_%d" % k
    finish(m, col, mark, bevel=False)
print([o.name for o in col.objects])
```

(Blender's -Y is the game's +Z toward the player, hence `-y`, so the layouts read the same way as on the tray buttons.)

- [ ] **Step 4: The pip and the lid**

```python
col = collection("Pip")
well = bpy.data.materials["Well_flat"]
pipm = material("Pip", "f6f1e6")
bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=0.003, vertices=32, location=(0, 0, 0.0015))
w = bpy.context.active_object
w.name = "Pip_Well"
finish(w, col, well, bevel=False)
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.08, segments=24, ring_count=12, location=(0, 0, 0.08))
ball = bpy.context.active_object
ball.name = "Pip_Ball"
finish(ball, col, pipm, bevel=False)

col = collection("Lid")
lidm = material("Lid", "dccfb3")
knobm = material("Knob", "c8a17a")
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.08))
lid = bpy.context.active_object
lid.name = "Lid_Body"
lid.scale = (0.94, 0.94, 0.16)
finish(lid, col, lidm)
bpy.ops.mesh.primitive_cylinder_add(radius=0.09, depth=0.08, vertices=32, location=(0, 0, 0.20))
knob = bpy.context.active_object
knob.name = "Lid_Knob"
finish(knob, col, knobm)
print([(c.name, [o.name for o in c.objects]) for c in bpy.data.collections])
```

- [ ] **Step 5: Check and save**

```python
import os
bad = []
for o in bpy.data.objects:
    if o.type != "MESH":
        continue
    if o.parent is not None:
        bad.append(o.name + ": parented")
    if "." in o.name:
        bad.append(o.name + ": suffixed name")
    if len(o.data.materials) != 1:
        bad.append(o.name + ": %d materials" % len(o.data.materials))
    for poly in o.data.polygons:
        if not poly.use_smooth:
            bad.append(o.name + ": flat faces")
            break
print("problems:", bad)
path = os.path.expanduser("~/dev/daily/art/codebreak.blend")
bpy.ops.wm.save_as_mainfile(filepath=path)
print("saved", path)
```

Expected: `problems: []` and `saved .../art/codebreak.blend`. Fix any listed problem before going on (a `.001` name means a step ran twice: delete the duplicate and re-run only that step).

- [ ] **Step 6: Export through the contract and import**

Run:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b art/codebreak.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Socket Peg Pip Lid 2>&1 | grep -v '^$' | tail -20
godot --headless --path . --import > /tmp/godot_import.log 2>&1; tail -3 /tmp/godot_import.log
ls -la assets/models/socket.glb assets/models/peg.glb assets/models/pip.glb assets/models/lid.glb
```

Expected: the exporter prints one `OK` line per slot with its measured footprint and height inside budget (socket 0.94 x 0.94 x 0.12, peg about 0.6 x 0.6 x 0.44, pip 0.2 x 0.2 x 0.16, lid 0.94 x 0.94 x 0.24) and no `REJECT`. If it rejects a bevel result over budget, shrink that piece by the overshoot and re-export.

- [ ] **Step 7: Look at each piece on the stage, then the board**

Run: `for s in socket peg pip lid; do godot --path . --resolution 720x720 --script res://tests/_shot_model.gd -- $s; done; git checkout project.godot 2>/dev/null`
Open the four `/tmp/shot_model_<slot>.png`: outlines on the body, none on the wells or marks; the peg shows all seven marks stacked (the game hides six).

Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd > /tmp/shot.log 2>&1; git checkout project.godot 2>/dev/null`
Open `/tmp/shot_mastermind.png`: the exports in place of the placeholders. Compare with `docs/art/concept-codebreak.png`.

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `passed=N failed=0` (the slot test now measures the exports).

- [ ] **Step 8: Tooling and docs**

In `tools/build_models.sh`, after the tile export block, add:

```sh
# Code Break's pieces are hand-modelled too: four collections in one .blend,
# one .glb each.
"$BLENDER" -b art/codebreak.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Socket Peg Pip Lid
```

In `.gitignore`, after the `!art/tree.blend` line, add:

```
# So are Code Break's socket, peg, pip and lid
!art/codebreak.blend
```

In `docs/art/blender-contract.md`, add to the slot table after the `tree` row:

```markdown
| `socket` | 0.94 x 0.94 | 0.15 | Code Break's slab, an **assembly**: `Socket_Body` (`Stone`, tinted by whether its row is active) and `Socket_Well` (`Well_flat`, a disc laid 0.0015 proud on top). The feedback slab is a socket with its well hidden |
| `peg` | 0.6 across | 0.5 | a colour peg, an **assembly**: `Peg_Body` (`Shell`, tinted per colour) and `Peg_Mark_1` … `Peg_Mark_7` (`Mark_flat`, one to seven pips on the crown in die layouts); the game shows the one mark matching the colour |
| `pip` | 0.2 across | 0.2 | a feedback pip, an **assembly**: `Pip_Well` (`Well_flat`) and `Pip_Ball` (`Pip`, tinted slate or cream, hidden until scored) |
| `lid` | 0.94 x 0.94 | 0.3 | the stone lid over one code slot: `Lid_Body` (`Lid`) and `Lid_Knob` (`Knob`) |
```

and in the paragraph under the table that lists tinted material names for rule 6, add: "the `socket` tints `Stone`, the `peg` tints `Shell` and `Mark_flat`, the `pip` tints `Pip`."

In `assets/models/README.md`, add rows to the table:

```markdown
| `socket` | Code Break's slab: `Stone` body tinted by whether its row is active, plus a `Well_flat` disc; the feedback slab hides the well |
| `peg` | a colour peg: `Shell` dome tinted per colour, seven `Mark_flat` pip layers of which the game shows one |
| `pip` | a feedback pip: `Well_flat` disc and a `Pip` ball tinted slate or cream, hidden until scored |
| `lid` | the stone lid over one code slot, `Lid` body and wooden `Knob` |
```

and extend the last paragraph: "Code Break's four pieces are hand-modelled too, in `art/codebreak.blend`, one collection per slot."

- [ ] **Step 9: Commit**

```bash
git add art/codebreak.blend assets/models/socket.glb assets/models/socket.glb.import assets/models/peg.glb assets/models/peg.glb.import assets/models/pip.glb assets/models/pip.glb.import assets/models/lid.glb assets/models/lid.glb.import tools/build_models.sh .gitignore docs/art/blender-contract.md assets/models/README.md
git commit -m "feat: Code Break's socket, peg, pip and lid, modelled and exported

art/codebreak.blend holds four collections, one mesh per layer: the slab and
its well disc, the dome with seven pip-mark layers on its crown, the pip well
and ball, the lid and its knob. Exported through the contract; the exporter
knows their budgets and build_models.sh exports them with the tile."
```

---

### Task 5: Verification, numbers and the merge

**Files:**
- Modify: `docs/superpowers/specs/2026-09-14-codebreak-3d-design.md` (section 8 amendment)
- Possibly modify: `puzzles/codebreak3d.gd` (tuning found on screen)

- [ ] **Step 1: Full suite and harnesses**

Run all three and keep the tails:

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -2
godot --path . --resolution 1080x1920 --script res://tests/_win.gd 2>&1 | tail -13
godot --path . --resolution 1080x1920 --script res://tests/_shot.gd 2>&1 | grep saved
git checkout project.godot 2>/dev/null
```

Expected: `failed=0`, `winnable=10/10`, eleven `saved` lines.

- [ ] **Step 2: Measure idle frame time and draw calls on Code Break**

Copy `tests/_shot_anim.gd` to `/tmp/_anim_cb.gd` (throwaway), change the opened entry from Binairo to `mastermind` (it opens `_entries` by id; find the `binairo` string and the `anim_binairo` file prefix and change both to `mastermind`), and run:

```bash
cp tests/_shot_anim.gd /tmp/_anim_cb.gd && sed -i '' 's/binairo/mastermind/g' /tmp/_anim_cb.gd
cp /tmp/_anim_cb.gd tests/_anim_cb_tmp.gd
godot --path . --resolution 1080x1920 --script res://tests/_anim_cb_tmp.gd 2>&1 | grep -i 'idle\|draw'
rm tests/_anim_cb_tmp.gd tests/_anim_cb_tmp.gd.uid 2>/dev/null; git checkout project.godot 2>/dev/null
```

If the copied script errors on a Binairo-only member (`n`, `_grid`, a roll), delete that line from the copy; only the idle window and the counters matter here.

Expected: `mean_ms` at or under 8 and `max_draw_calls` at or under 855. Record both numbers.

- [ ] **Step 3: Look at the strip and the still**

Open `/tmp/anim_mastermind_*.png` and `/tmp/shot_mastermind.png`. Check against the spec: the first guess row lighter than the rest, lids on the code row, tray above Reset and Check, pegs with a visible mark, no magenta, outlines on the bodies only. Fix anything wrong in `puzzles/codebreak3d.gd` or the placeholders and re-run step 1.

- [ ] **Step 4: Record the numbers in the spec**

Append to section 8 of `docs/superpowers/specs/2026-09-14-codebreak-3d-design.md`:

```markdown
Amendment (2026-09-14): measured on the Mac at 1080 x 1920 with a throwaway
copy of `_shot_anim.gd` opening Code Break: `idle mean_ms=<value>
max_draw_calls=<value>`. Suite `passed=<N> failed=0`, win harness 10/10.
```

with the real values.

- [ ] **Step 5: Commit and merge locally**

```bash
git checkout project.godot 2>/dev/null
git add docs/superpowers/specs/2026-09-14-codebreak-3d-design.md puzzles/codebreak3d.gd core/placeholders.gd
git commit -m "docs: Code Break spec records the measured frame time and draw calls"
git checkout main && git merge --ff-only feat/codebreak-3d && git branch -d feat/codebreak-3d
git log --oneline -6
```

Do not push: a push to `main` deploys.
