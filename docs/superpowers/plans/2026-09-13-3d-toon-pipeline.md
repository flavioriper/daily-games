# 3D Toon Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the daily puzzle game on a 3D toon-shaded stage with a Blender-to-Godot model pipeline, and convert Binairo as the reference board.

**Architecture:** A Node3D stage (camera rig, sun, sky, table) sits under a CanvasLayer that holds the existing 2D menu and host. A new `PuzzleBase3D` extends `PuzzleBase`, so the host and the nine 2D boards do not change; it mounts a Node3D board in the stage, fits the camera to its own rect, and turns touches into board-plane hits. Every mesh comes through a model library that loads `assets/models/<slot>.glb` when present and a primitive placeholder otherwise, converting materials to a shared toon shader at load time.

**Tech Stack:** Godot 4.7 (GDScript, Compatibility renderer), Blender 5.1 glTF exporter, Python 3 for the Blender-side script.

**Spec:** `docs/superpowers/specs/2026-09-13-3d-toon-pipeline-design.md`

## Global Constraints

- Renderer is `gl_compatibility` on every platform. No shader may read depth, screen, or normal-roughness textures.
- In a spatial `light()` function, never multiply `DIFFUSE_LIGHT` by `ALBEDO`; the pipeline does it afterwards. `LIGHT_COLOR` is colour times energy times PI.
- Outlines are a child `MeshInstance3D` named `Outline` with `cast_shadow` off. Never `material_overlay`, never `next_pass`.
- One world unit equals one board cell. Model origins sit at the centre of the base.
- New scripts follow the repo pattern: no `class_name`, path-based `preload` constants, `extends "res://..."`. Reason: the headless test runner has no global class cache.
- Controls that read taps handle `InputEventScreenTouch` and `InputEventScreenDrag` only. The project emulates touch from mouse, and the viewport delivers both the mouse event and the emulated touch to the same control.
- Tests are static `run(t)` suites registered in `tests/run_tests.gd`; assertions are `t.check(cond, msg)` and `t.eq(a, b, msg)`.
- Unit tests run with `godot --headless --path . --script res://tests/run_tests.gd`. Windowed harnesses run with `godot --path . --resolution 540x960 --script res://tests/_win.gd` and `res://tests/_shot.gd`.
- Colours come from `core/palette.gd`. No literal colours in boards, stage, or chrome.
- Commit after every task. Do not push.

---

### Task 1: Cozy palette

**Files:**
- Modify: `core/palette.gd`
- Create: `tests/test_palette.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Produces: constants `PAPER, BG, SURFACE, SURFACE_HI, LINE, TEXT, TEXT_DIM, ACCENT, ACCENT_2, GOOD, BAD, BAD_TILE, WOOD, OUTLINE, SHADOW_TINT, SKY_TOP, SKY_HORIZON, AMBIENT, CAT` and `static func contrast(a: Color, b: Color) -> float`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_palette.gd`:

```gdscript
extends RefCounted

const Pal = preload("res://core/palette.gd")

static func run(t) -> void:
	_test_contrast_formula(t)
	_test_readability(t)
	_test_categorical(t)

static func _test_contrast_formula(t) -> void:
	var bw: float = Pal.contrast(Color.BLACK, Color.WHITE)
	t.check(bw > 20.9 and bw < 21.1, "black on white is 21:1, got %.2f" % bw)
	t.check(is_equal_approx(Pal.contrast(Color.WHITE, Color.WHITE), 1.0), "same colour is 1:1")
	t.check(is_equal_approx(Pal.contrast(Pal.TEXT, Pal.PAPER), Pal.contrast(Pal.PAPER, Pal.TEXT)), "contrast is symmetric")

static func _test_readability(t) -> void:
	var body: float = Pal.contrast(Pal.TEXT, Pal.PAPER)
	t.check(body >= 4.5, "TEXT on PAPER meets 4.5:1, got %.2f" % body)
	var dim: float = Pal.contrast(Pal.TEXT_DIM, Pal.PAPER)
	t.check(dim >= 3.0, "TEXT_DIM on PAPER meets 3:1, got %.2f" % dim)
	var on_tile: float = Pal.contrast(Pal.TEXT, Pal.SURFACE)
	t.check(on_tile >= 4.5, "TEXT on SURFACE meets 4.5:1, got %.2f" % on_tile)
	t.check(Pal.contrast(Pal.OUTLINE, Pal.SURFACE) >= 7.0, "outline ink is clearly darker than a tile")
	t.check(Pal.BG == Pal.PAPER, "BG stays an alias of PAPER for the 2D boards")

static func _test_categorical(t) -> void:
	t.eq(Pal.CAT.size(), 8, "CAT keeps eight entries")
	for i in Pal.CAT.size():
		for j in range(i + 1, Pal.CAT.size()):
			t.check(Pal.CAT[i] != Pal.CAT[j], "CAT %d and %d differ" % [i, j])
```

Register it in `tests/run_tests.gd` by adding to the `suites` dictionary, before `"binairo"`:

```gdscript
		"palette": "res://tests/test_palette.gd",
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -5`
Expected: a parse error or `FAIL [palette]` lines mentioning `contrast`, and `failed=` greater than 0.

- [ ] **Step 3: Write the palette**

Replace `core/palette.gd` entirely:

```gdscript
class_name Palette
extends RefCounted

## Cozy paper-and-wood palette shared by the 3D stage, the toon materials and
## the 2D chrome. Colour never carries meaning alone (see shapes.gd), so these
## only need to be pleasant and readable.

const PAPER       := Color("f6efe3")
const BG          := PAPER
const SURFACE     := Color("fffdf8")
const SURFACE_HI  := Color("f1e6d2")
const LINE        := Color("b8a892")
const TEXT        := Color("3b3028")
const TEXT_DIM    := Color("8a7b6b")
const ACCENT      := Color("4c9a94")
const ACCENT_2    := Color("e2825f")
const GOOD        := Color("7cb06b")
const BAD         := Color("d9605a")
const BAD_TILE    := Color("f2cfc9")
const WOOD        := Color("c8a17a")
const OUTLINE     := Color("3b2f28")
const SHADOW_TINT := Color("b7a6c4")
const SKY_TOP     := Color("f9f2e7")
const SKY_HORIZON := Color("f3d9c4")
const AMBIENT     := Color("f3e4d4")

# Categorical ramp, same order as before so boards keep their index meaning:
# teal, terracotta, sage, lavender, rose, sky, mustard, stone.
const CAT := [
	Color("4c9a94"), Color("e2825f"), Color("7cb06b"), Color("9b86c9"),
	Color("d9605a"), Color("6bb1d6"), Color("d3b04a"), Color("9a948c"),
]

## WCAG contrast ratio between two sRGB colours, 1.0 to 21.0.
static func contrast(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

static func _relative_luminance(c: Color) -> float:
	var lin := c.srgb_to_linear()
	return 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `failed=0`.

- [ ] **Step 5: Commit**

```bash
git add core/palette.gd tests/test_palette.gd tests/run_tests.gd
git commit -m "feat: warm cozy palette with contrast checks"
```

---

### Task 2: Board geometry

**Files:**
- Create: `core/board_math.gd`
- Create: `tests/test_board_math.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Produces (all static):
  - `ray_plane(origin: Vector3, dir: Vector3, y: float) -> Variant` (Vector3 or null)
  - `cell_origin(cols: int, rows: int) -> Vector3`
  - `cell_center(r: int, c: int, cols: int, rows: int, y: float = 0.0) -> Vector3`
  - `world_to_cell(hit: Vector3, cols: int, rows: int) -> Vector2i` returning `Vector2i(col, row)` or `Vector2i(-1, -1)`
  - `board_aabb(cols: int, rows: int, height: float) -> AABB`

- [ ] **Step 1: Write the failing test**

Create `tests/test_board_math.gd`:

```gdscript
extends RefCounted

const BM = preload("res://core/board_math.gd")

static func run(t) -> void:
	_test_ray_plane(t)
	_test_cells(t)
	_test_aabb(t)

static func _test_ray_plane(t) -> void:
	var hit = BM.ray_plane(Vector3(0, 5, 0), Vector3(0, -1, 0), 0.0)
	t.check(hit != null and hit.is_equal_approx(Vector3.ZERO), "straight down hits the origin")
	hit = BM.ray_plane(Vector3(0, 5, 5), Vector3(0, -1, -1).normalized(), 0.0)
	t.check(hit != null and hit.is_equal_approx(Vector3.ZERO), "45 degree ray lands where expected")
	hit = BM.ray_plane(Vector3(0, 5, 0), Vector3(0, 0, -1), 0.0)
	t.check(hit == null, "parallel ray misses")
	hit = BM.ray_plane(Vector3(0, 5, 0), Vector3(0, 1, 0), 0.0)
	t.check(hit == null, "ray pointing away misses")
	hit = BM.ray_plane(Vector3(0, 5, 0), Vector3(0, -1, 0), 0.12)
	t.check(hit != null and is_equal_approx(hit.y, 0.12), "plane height respected")

static func _test_cells(t) -> void:
	var n := 6
	t.check(BM.cell_origin(n, n).is_equal_approx(Vector3(-3, 0, -3)), "6x6 board is centred on the origin")
	for r in n:
		for c in n:
			var centre: Vector3 = BM.cell_center(r, c, n, n, 0.0)
			t.eq(BM.world_to_cell(centre, n, n), Vector2i(c, r), "centre of (r%d,c%d) maps back" % [r, c])
	t.eq(BM.world_to_cell(Vector3(-3.01, 0, 0), n, n), Vector2i(-1, -1), "just left of the board is outside")
	t.eq(BM.world_to_cell(Vector3(3.0, 0, 0), n, n), Vector2i(-1, -1), "right edge is exclusive")
	t.eq(BM.world_to_cell(Vector3(0, 0, 3.0), n, n), Vector2i(-1, -1), "bottom edge is exclusive")
	t.eq(BM.world_to_cell(Vector3(-2.999, 0, -2.999), n, n), Vector2i(0, 0), "min corner is cell (0,0)")
	t.eq(BM.world_to_cell(Vector3(2.999, 0, 2.999), n, n), Vector2i(5, 5), "max corner is the last cell")
	t.check(is_equal_approx(BM.cell_center(0, 0, n, n, 0.4).y, 0.4), "cell_center carries the height")
	# Rectangular board: columns along X, rows along Z.
	t.eq(BM.world_to_cell(BM.cell_center(1, 3, 4, 2), 4, 2), Vector2i(3, 1), "4 cols x 2 rows maps (r1,c3)")
	t.check(BM.cell_center(0, 0, 4, 2).z < BM.cell_center(1, 0, 4, 2).z, "row index grows along +Z")
	t.check(BM.cell_center(0, 0, 4, 2).x < BM.cell_center(0, 1, 4, 2).x, "column index grows along +X")

static func _test_aabb(t) -> void:
	var box: AABB = BM.board_aabb(6, 6, 0.5)
	t.check(box.position.is_equal_approx(Vector3(-3, 0, -3)), "aabb starts at the min corner")
	t.check(box.size.is_equal_approx(Vector3(6, 0.5, 6)), "aabb spans the board and its height")
	for r in 6:
		for c in 6:
			t.check(box.has_point(BM.cell_center(r, c, 6, 6, 0.25)), "aabb contains cell (r%d,c%d)" % [r, c])
```

Register in `tests/run_tests.gd` after `"palette"`:

```gdscript
		"board_math": "res://tests/test_board_math.gd",
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "board_math|failed=" | head -5`
Expected: `FAIL [board_math] could not load suite` or parse errors; `failed=` greater than 0.

- [ ] **Step 3: Write the geometry**

Create `core/board_math.gd`:

```gdscript
extends RefCounted

## Pure geometry for boards laid out on the XZ plane, one cell per world unit,
## centred on the board anchor. Columns run along +X, rows along +Z, so with a
## camera on the +Z side looking toward -Z, row 0 is the far edge (top of the
## screen) and column 0 is on the left. Nothing here touches a camera or a
## node, so it runs headless and is covered by tests/test_board_math.gd.

const CELL := 1.0

## Where a ray from `origin` heading `dir` crosses the horizontal plane at
## height `y`. Null when the ray is parallel to the plane or moving away.
static func ray_plane(origin: Vector3, dir: Vector3, y: float) -> Variant:
	if absf(dir.y) < 1e-6:
		return null
	var t := (y - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t

## Min corner of cell (row 0, col 0) for a `cols` by `rows` board centred on
## the origin.
static func cell_origin(cols: int, rows: int) -> Vector3:
	return Vector3(-cols * CELL * 0.5, 0.0, -rows * CELL * 0.5)

## Centre of cell (r, c) at height y.
static func cell_center(r: int, c: int, cols: int, rows: int, y: float = 0.0) -> Vector3:
	var o := cell_origin(cols, rows)
	return Vector3(o.x + (c + 0.5) * CELL, y, o.z + (r + 0.5) * CELL)

## Cell under a world point as Vector2i(col, row), or (-1, -1) outside.
static func world_to_cell(hit: Vector3, cols: int, rows: int) -> Vector2i:
	var o := cell_origin(cols, rows)
	var c := floori((hit.x - o.x) / CELL)
	var r := floori((hit.z - o.z) / CELL)
	if c < 0 or r < 0 or c >= cols or r >= rows:
		return Vector2i(-1, -1)
	return Vector2i(c, r)

## Bounding box of the whole board, from the table surface up to `height`.
static func board_aabb(cols: int, rows: int, height: float) -> AABB:
	return AABB(cell_origin(cols, rows), Vector3(cols * CELL, height, rows * CELL))
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `failed=0`.

- [ ] **Step 5: Commit**

```bash
git add core/board_math.gd tests/test_board_math.gd tests/run_tests.gd
git commit -m "feat: board plane geometry helpers"
```

---

### Task 3: Toon shaders and material factory

**Files:**
- Create: `shaders/toon.gdshader`
- Create: `shaders/outline.gdshader`
- Create: `core/toon.gd`
- Create: `tests/test_toon.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `Palette.SHADOW_TINT`, `Palette.OUTLINE`.
- Produces (all static on `core/toon.gd`):
  - `const OUTLINE_NODE := "Outline"`, `const FLAT_SUFFIX := "_flat"`
  - `ramp() -> GradientTexture1D`
  - `material(albedo: Color) -> ShaderMaterial` (cached per colour)
  - `outline() -> ShaderMaterial` (one shared instance)
  - `add_outline(mi: MeshInstance3D) -> MeshInstance3D` (idempotent)
  - `apply_to(root: Node) -> void`

- [ ] **Step 1: Write the failing test**

Create `tests/test_toon.gd`:

```gdscript
extends RefCounted

const Toon = preload("res://core/toon.gd")

static func run(t) -> void:
	_test_material_cache(t)
	_test_apply_converts_and_outlines(t)
	_test_flat_gets_no_outline(t)
	_test_shader_material_left_alone(t)
	_test_apply_twice_is_idempotent(t)

static func _mesh_with(mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.material = mat
	mi.mesh = box
	return mi

static func _test_material_cache(t) -> void:
	var a = Toon.material(Color("4c9a94"))
	var b = Toon.material(Color("4c9a94"))
	var c = Toon.material(Color("e2825f"))
	t.check(a is ShaderMaterial, "material() builds a ShaderMaterial")
	t.check(a == b, "same colour returns the cached instance")
	t.check(a != c, "different colours are different materials")
	t.check(Color(a.get_shader_parameter("albedo")).is_equal_approx(Color("4c9a94")), "albedo parameter carries the colour")
	t.check(a.get_shader_parameter("ramp") is GradientTexture1D, "ramp texture is wired")
	t.check(Toon.outline() == Toon.outline(), "one shared outline material")

static func _test_apply_converts_and_outlines(t) -> void:
	var std := StandardMaterial3D.new()
	std.albedo_color = Color("c8a17a")
	std.resource_name = "Wood"
	var root := Node3D.new()
	var mi := _mesh_with(std)
	root.add_child(mi)
	Toon.apply_to(root)
	var over = mi.get_surface_override_material(0)
	t.check(over is ShaderMaterial, "StandardMaterial3D surface converted to toon")
	t.check(over != null and Color(over.get_shader_parameter("albedo")).is_equal_approx(Color("c8a17a")), "base colour preserved")
	var shell = mi.get_node_or_null("Outline")
	t.check(shell is MeshInstance3D, "outline shell added")
	t.check(shell != null and shell.mesh == mi.mesh, "shell shares the mesh")
	t.check(shell != null and shell.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "shell casts no shadow")
	t.check(shell != null and shell.material_override == Toon.outline(), "shell uses the shared outline material")
	root.free()

static func _test_flat_gets_no_outline(t) -> void:
	var std := StandardMaterial3D.new()
	std.albedo_color = Color("c8a17a")
	std.resource_name = "Wood_flat"
	var mi := _mesh_with(std)
	Toon.apply_to(mi)
	t.check(mi.get_surface_override_material(0) is ShaderMaterial, "_flat surface still gets the toon material")
	t.check(mi.get_node_or_null("Outline") == null, "_flat mesh gets no outline shell")
	mi.free()

static func _test_shader_material_left_alone(t) -> void:
	var custom := ShaderMaterial.new()
	var mi := _mesh_with(custom)
	Toon.apply_to(mi)
	t.check(mi.get_surface_override_material(0) == null, "ShaderMaterial surface is not overridden")
	t.check(mi.get_node_or_null("Outline") != null, "authored ShaderMaterial still gets an outline")
	mi.free()

static func _test_apply_twice_is_idempotent(t) -> void:
	var mi := _mesh_with(StandardMaterial3D.new())
	Toon.apply_to(mi)
	Toon.apply_to(mi)
	var shells := 0
	for child in mi.get_children():
		if String(child.name).begins_with("Outline"):
			shells += 1
	t.eq(shells, 1, "second apply_to adds no second shell")
	mi.free()
```

Register in `tests/run_tests.gd` after `"board_math"`:

```gdscript
		"toon": "res://tests/test_toon.gd",
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "toon|failed=" | head -5`
Expected: `FAIL [toon] could not load suite`; `failed=` greater than 0.

- [ ] **Step 3: Write the shaders**

Create `shaders/toon.gdshader`:

```glsl
shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// Cozy cel shading. Spec: docs/superpowers/specs/2026-09-13-3d-toon-pipeline-design.md
// section 2. Runs on gl_compatibility: nothing here reads depth or screen.

uniform vec4 albedo : source_color = vec4(1.0);
// Red channel = lit factor across NdotL remapped to 0..1. Nearest filtering
// keeps the bands hard. core/toon.gd ramp() builds the default.
uniform sampler2D ramp : filter_nearest, repeat_disable, hint_default_white;
// Shadow is a hue shift toward this tint, never a multiply toward black.
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.65, 0.77, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.18;
uniform float rim_width : hint_range(0.0, 1.0) = 0.30;
uniform vec4 rim_color : source_color = vec4(1.0);

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = step(1.0 - rim_width, 1.0 - facing);
	EMISSION = rim_color.rgb * albedo.rgb * rim * rim_strength;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float t = clamp(ndl * 0.5 + 0.5, 0.0, 1.0) * clamp(ATTENUATION, 0.0, 1.0);
	float band = texture(ramp, vec2(t, 0.5)).r;
	// LIGHT_COLOR is colour * energy * PI, and the pipeline multiplies this
	// result by ALBEDO afterwards (scene.glsl: diffuse_light *= albedo), so
	// neither factor belongs here.
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint.rgb, vec3(1.0), band);
}
```

Create `shaders/outline.gdshader`:

```glsl
shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

// Inverted hull: the mesh drawn again with front faces culled and every
// vertex pushed out along its normal, so only a rim of back faces shows
// around the silhouette. Lives on a child MeshInstance3D with shadow casting
// off (core/toon.gd add_outline). Never material_overlay or next_pass: both
// would draw the hull into the shadow map too.

uniform vec4 color : source_color = vec4(0.23, 0.18, 0.16, 1.0);
// World units at distance_scale 0. Raise distance_scale so far pieces keep a
// visible line.
uniform float width : hint_range(0.0, 0.2) = 0.02;
uniform float distance_scale : hint_range(0.0, 0.2) = 0.0;

void vertex() {
	float view_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	VERTEX += normalize(NORMAL) * width * (1.0 + distance_scale * view_dist);
}

void fragment() {
	ALBEDO = color.rgb;
}
```

- [ ] **Step 4: Write the factory**

Create `core/toon.gd`:

```gdscript
extends RefCounted

## Factory for the cozy toon look. Every 3D thing in the game gets its
## materials from here, so the shading contract lives in one place.
## Materials are cached per colour; a board of a hundred same-coloured tiles
## costs one material.

const TOON_SHADER := preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const Pal = preload("res://core/palette.gd")

const OUTLINE_NODE := "Outline"
## A Blender material whose name ends in this gets toon shading but no
## outline shell (the table, ground, anything that should not read as a piece).
const FLAT_SUFFIX := "_flat"

static var _ramp: GradientTexture1D
static var _outline: ShaderMaterial
static var _cache: Dictionary = {}

## Three hard bands: tinted shadow, half light, full light.
static func ramp() -> GradientTexture1D:
	if _ramp == null:
		var g := Gradient.new()
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		g.offsets = PackedFloat32Array([0.0, 0.42, 0.70])
		g.colors = PackedColorArray([Color(0, 0, 0), Color(0.55, 0.55, 0.55), Color(1, 1, 1)])
		_ramp = GradientTexture1D.new()
		_ramp.gradient = g
		_ramp.width = 64
	return _ramp

static func material(albedo: Color) -> ShaderMaterial:
	var key := albedo.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("ramp", ramp())
	m.set_shader_parameter("shadow_tint", Pal.SHADOW_TINT)
	_cache[key] = m
	return m

static func outline() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
		_outline.set_shader_parameter("color", Pal.OUTLINE)
	return _outline

## Adds the inverted-hull shell as a child of `mi`, sharing its mesh. Safe to
## call twice. The shell casts no shadow, otherwise every piece would throw a
## fattened silhouette onto the table.
static func add_outline(mi: MeshInstance3D) -> MeshInstance3D:
	var existing := mi.get_node_or_null(OUTLINE_NODE)
	if existing != null:
		return existing
	var shell := MeshInstance3D.new()
	shell.name = OUTLINE_NODE
	shell.mesh = mi.mesh
	shell.material_override = outline()
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(shell)
	return shell

## Converts every StandardMaterial3D surface under `root` to the toon material
## with the same base colour and gives each mesh an outline shell, unless every
## surface name ends in FLAT_SUFFIX. ShaderMaterial surfaces are left as they
## are. This is the whole Blender-to-toon step, done at load time.
static func apply_to(root: Node) -> void:
	if root is MeshInstance3D:
		_apply_mesh(root)
	for child in root.get_children():
		if child.name == OUTLINE_NODE:
			continue
		apply_to(child)

static func _apply_mesh(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var wants_outline := false
	for i in mi.mesh.get_surface_count():
		var src: Material = mi.get_active_material(i)
		if src is StandardMaterial3D:
			mi.set_surface_override_material(i, material(src.albedo_color))
		if src == null or not src.resource_name.ends_with(FLAT_SUFFIX):
			wants_outline = true
	if wants_outline:
		add_outline(mi)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `failed=0`. If the shader files fail to parse, the output shows `SHADER ERROR` lines with the line number; fix the shader, not the test.

- [ ] **Step 6: Commit**

```bash
git add shaders/toon.gdshader shaders/outline.gdshader core/toon.gd tests/test_toon.gd tests/run_tests.gd
git commit -m "feat: toon and outline shaders with a cached material factory"
```

---

### Task 4: Placeholders and the model library

**Files:**
- Create: `core/placeholders.gd`
- Create: `core/models.gd`
- Create: `assets/models/README.md`
- Create: `tests/test_models.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `core/toon.gd` (`material`, `add_outline`, `apply_to`, `OUTLINE_NODE`), palette.
- Produces:
  - `core/placeholders.gd`: `const TILE_H := 0.12`, `const TOKEN_H := 0.18`, `static func make(slot: String) -> Node3D`
  - `core/models.gd`: `const SLOTS`, `static func has_model(slot) -> bool`, `static func instance(slot: String) -> Node3D`, `static func meshes(root: Node) -> Array[MeshInstance3D]`, `static func tint(root: Node, color: Color) -> void`, `static func height(root: Node) -> float`

Every returned node is a `Node3D` root with its origin at the centre of its base. Square pieces are 4-sided `CylinderMesh` prisms rotated 45 degrees rather than `BoxMesh`, because a `BoxMesh` has split flat normals and the outline hull would open at the corners; cylinder sides share vertices so the hull closes.

- [ ] **Step 1: Write the failing test**

Create `tests/test_models.gd`:

```gdscript
extends RefCounted

const Models = preload("res://core/models.gd")

static func run(t) -> void:
	_test_slots(t)
	_test_fallback(t)
	_test_tint_and_height(t)

## World-space min/max of every face vertex under `root`, outline shells excluded.
static func _bounds(root: Node3D) -> Array:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for mi in Models.meshes(root):
		for p in mi.mesh.get_faces():
			var w: Vector3 = mi.transform * p
			lo = lo.min(w)
			hi = hi.max(w)
	return [lo, hi]

static func _test_slots(t) -> void:
	for slot in Models.SLOTS:
		var node = Models.instance(slot)
		t.check(node is Node3D, "%s yields a Node3D" % slot)
		var ms = Models.meshes(node)
		t.check(ms.size() >= 1, "%s has a mesh" % slot)
		var b := _bounds(node)
		var lo: Vector3 = b[0]
		var hi: Vector3 = b[1]
		t.check(absf(lo.y) < 0.001, "%s base sits at y=0 (min y %.3f)" % [slot, lo.y])
		if slot != "table":
			t.check(lo.x >= -0.5 and hi.x <= 0.5 and lo.z >= -0.5 and hi.z <= 0.5,
				"%s fits a 1x1 footprint (%s .. %s)" % [slot, lo, hi])
			t.check(hi.y <= 0.6, "%s is under 0.6 tall" % slot)
		for mi in ms:
			var has_outline := mi.get_node_or_null("Outline") != null
			t.check(has_outline == (slot != "table"), "%s outline present=%s" % [slot, has_outline])
		node.free()

static func _test_fallback(t) -> void:
	t.check(not Models.has_model("no_such_thing"), "has_model is false for a missing file")
	var unknown = Models.instance("no_such_thing")
	t.check(unknown is Node3D and Models.meshes(unknown).size() == 1, "unknown slot falls back to a placeholder")
	unknown.free()
	var a = Models.instance("tile")
	var b = Models.instance("tile")
	t.check(a != b, "instances are distinct nodes")
	a.free()
	b.free()

static func _test_tint_and_height(t) -> void:
	var tok = Models.instance("token_circle")
	Models.tint(tok, Color("d9605a"))
	var over = Models.meshes(tok)[0].get_surface_override_material(0)
	t.check(over != null and Color(over.get_shader_parameter("albedo")).is_equal_approx(Color("d9605a")), "tint swaps the toon colour")
	tok.free()
	var tile = Models.instance("tile")
	t.check(is_equal_approx(Models.height(tile), 0.12), "tile placeholder is 0.12 tall, measured %.3f" % Models.height(tile))
	tile.free()
```

Register in `tests/run_tests.gd` after `"toon"`:

```gdscript
		"models": "res://tests/test_models.gd",
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "models|failed=" | head -5`
Expected: `FAIL [models] could not load suite`; `failed=` greater than 0.

- [ ] **Step 3: Write the placeholders**

Create `core/placeholders.gd`:

```gdscript
extends RefCounted

## Primitive stand-ins for every model slot, so the 3D boards render before a
## single Blender file exists. Each follows docs/art/blender-contract.md:
## one unit per cell, origin at the centre of the base, shared vertices so the
## outline hull closes. Square pieces are four-sided cylinder prisms turned
## 45 degrees, not BoxMesh: a BoxMesh has split flat normals and the hull
## would open at every corner.

const Toon = preload("res://core/toon.gd")
const Pal = preload("res://core/palette.gd")

const TILE_H := 0.12
const TOKEN_H := 0.18

static func make(slot: String) -> Node3D:
	var root := Node3D.new()
	root.name = slot
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var color := Color.MAGENTA
	var height := 0.4
	var outline := true
	match slot:
		"tile":
			mi.mesh = _prism(0.46, TILE_H)
			mi.rotation.y = PI / 4.0
			color = Pal.SURFACE
			height = TILE_H
		"token_circle":
			mi.mesh = _cylinder(0.30, TOKEN_H, 32)
			color = Pal.ACCENT
			height = TOKEN_H
		"token_square":
			mi.mesh = _prism(0.25, TOKEN_H)
			mi.rotation.y = PI / 4.0
			color = Pal.ACCENT_2
			height = TOKEN_H
		"given_ring":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.38
			torus.outer_radius = 0.44
			torus.rings = 48
			torus.ring_segments = 12
			mi.mesh = torus
			color = Pal.TEXT_DIM
			height = torus.outer_radius - torus.inner_radius
		"table":
			var box := BoxMesh.new()
			box.size = Vector3(14.0, 0.4, 14.0)
			mi.mesh = box
			color = Pal.WOOD
			height = 0.4
			outline = false
		_:
			# Unknown slot: a small magenta block so the gap is obvious on screen.
			mi.mesh = _prism(0.2, 0.4)
	mi.position.y = height * 0.5
	mi.set_surface_override_material(0, Toon.material(color))
	if outline:
		Toon.add_outline(mi)
	root.add_child(mi)
	return root

## Square prism of half-width `half` and height `h`, built as a four-sided
## cylinder so the side vertices are shared. Rotate 45 degrees to align faces.
static func _prism(half: float, h: float) -> CylinderMesh:
	return _cylinder(half * sqrt(2.0), h, 4)

static func _cylinder(radius: float, h: float, segments: int) -> CylinderMesh:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = h
	cyl.radial_segments = segments
	cyl.rings = 0
	return cyl
```

- [ ] **Step 4: Write the model library**

Create `core/models.gd`:

```gdscript
extends RefCounted

## The model library. Every 3D piece in the game comes through instance(): a
## Blender export at assets/models/<slot>.glb when one exists, otherwise the
## primitive placeholder. Drop a .glb with the right name and it appears.

const Toon = preload("res://core/toon.gd")
const Placeholders = preload("res://core/placeholders.gd")

const DIR := "res://assets/models/"
## The model names the game asks for. docs/art/blender-contract.md lists the
## same names with their footprint rules.
const SLOTS := ["tile", "token_circle", "token_square", "given_ring", "table"]

static var _scenes: Dictionary = {}

static func path_for(slot: String) -> String:
	return DIR + slot + ".glb"

static func has_model(slot: String) -> bool:
	return ResourceLoader.exists(path_for(slot))

static func instance(slot: String) -> Node3D:
	if has_model(slot):
		var scene: PackedScene = _scenes.get(slot)
		if scene == null:
			scene = load(path_for(slot))
			if scene == null:
				push_warning("Models: %s exists but did not load (not imported?); using placeholder" % path_for(slot))
				return Placeholders.make(slot)
			_scenes[slot] = scene
		var node := scene.instantiate() as Node3D
		node.name = slot
		Toon.apply_to(node)
		return node
	return Placeholders.make(slot)

## Every renderable mesh under `root`, outline shells excluded.
static func meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for child in root.get_children():
		if child.name == Toon.OUTLINE_NODE:
			continue
		out.append_array(meshes(child))
	return out

## Recolours every surface under `root` with the toon material for `color`.
static func tint(root: Node, color: Color) -> void:
	for mi in meshes(root):
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, Toon.material(color))

## Height of the model above its base, measured from the mesh bounds.
static func height(root: Node) -> float:
	var top := 0.0
	for mi in meshes(root):
		var box: AABB = mi.transform * mi.mesh.get_aabb()
		top = maxf(top, box.end.y)
	return top
```

Create `assets/models/README.md`:

```markdown
# Models

Drop Blender exports here as `<slot>.glb`. The game looks for these names
(see `core/models.gd` SLOTS) and falls back to a primitive placeholder for
any that are missing:

| slot | what it is |
|---|---|
| `tile` | one board cell, 1 x 1 footprint |
| `token_circle` | the "circle" token in Binairo |
| `token_square` | the "square" token in Binairo |
| `given_ring` | ring laid over a locked clue cell |
| `table` | the surface the board sits on |

Modelling rules and the export script: `docs/art/blender-contract.md`.
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `failed=0`. If `mi.mesh.get_faces()` returns an empty array headless, the footprint checks print `INF`; in that case switch `_bounds` in the test to use `mi.transform * mi.mesh.get_aabb()` endpoints instead and note it in the commit message.

- [ ] **Step 6: Commit**

```bash
git add core/placeholders.gd core/models.gd assets/models/README.md tests/test_models.gd tests/run_tests.gd
git commit -m "feat: model library with primitive placeholders per slot"
```

---

### Task 5: Stage, camera rig, main scene, renderer settings

**Files:**
- Create: `world/camera_rig.gd`
- Create: `world/stage.gd`
- Create: `world/stage.tscn`
- Create: `world/main.tscn`
- Modify: `project.godot`
- Modify: `ui/menu.gd` (remove opaque background, add translucent panel)
- Modify: `ui/puzzle_host.gd` (remove opaque background only; the rest of the chrome is Task 8)
- Modify: `tests/_shot.gd`, `tests/_win.gd`, `tests/_tap.gd` (`_initialize` only)

**Interfaces:**
- Consumes: `core/models.gd` (`instance("table")`), palette.
- Produces:
  - `world/camera_rig.gd`: `var camera: Camera3D`, `func fit(aabb: AABB, rect: Rect2) -> void`
  - `world/stage.gd`: group `"stage"`, `func mount(board: Node3D)`, `func unmount(board: Node3D)`, `func fit_camera(aabb: AABB, rect: Rect2)`
  - `world/main.tscn` with the menu at `UI/Menu`.

- [ ] **Step 1: Write the camera rig**

Create `world/camera_rig.gd`:

```gdscript
extends Node3D

## Fixed-direction board camera. The direction never changes (pitch below the
## horizontal, yaw around Y); fit() only moves the camera along that direction
## and slides its target so a given AABB fills a given screen rect.
## Projection needs a live viewport, so this is verified by the win and
## screenshot harnesses rather than by headless tests.

@export var pitch_deg: float = 55.0
@export var yaw_deg: float = 0.0
@export var fov_deg: float = 35.0
## Fraction of the rect's shorter side kept clear around the board.
@export var margin: float = 0.06

var camera: Camera3D
var _target := Vector3.ZERO
var _distance := 10.0

func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = fov_deg
	camera.near = 0.05
	camera.far = 200.0
	add_child(camera)
	camera.current = true
	_place()

## Unit vector from the target toward the camera: toward +Z (the player) and up.
func view_offset_dir() -> Vector3:
	var pitch := deg_to_rad(pitch_deg)
	var yaw := deg_to_rad(yaw_deg)
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()

func _place() -> void:
	camera.global_position = _target + view_offset_dir() * _distance
	camera.look_at(_target, Vector3.UP)

## Frames `aabb` inside `rect` (viewport pixels): binary-search the distance
## until every corner projects inside the margin-shrunk rect, then slide the
## target so the projected centre lands on the rect centre. Three passes
## converge well past a pixel.
func fit(aabb: AABB, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not is_inside_tree():
		return
	var inner := rect.grow(-minf(rect.size.x, rect.size.y) * margin)
	_target = aabb.get_center()
	for _pass in 3:
		_distance = _search_distance(aabb, inner)
		_place()
		var box := _projected(aabb)
		if box.size == Vector2.ZERO:
			return
		var delta := box.get_center() - inner.get_center()
		var per_px := _world_per_pixel()
		var b := camera.global_transform.basis
		_target += b.x * delta.x * per_px - b.y * delta.y * per_px
		_place()

func _search_distance(aabb: AABB, inner: Rect2) -> float:
	var lo := 0.5
	var hi := 200.0
	for _i in 28:
		_distance = (lo + hi) * 0.5
		_place()
		var box := _projected(aabb)
		if box.size != Vector2.ZERO and inner.encloses(box):
			hi = _distance
		else:
			lo = _distance
	return hi

## Screen bounding box of the AABB corners, or a zero rect when any corner is
## behind the camera.
func _projected(aabb: AABB) -> Rect2:
	var box := Rect2()
	for i in 8:
		var p := aabb.get_endpoint(i)
		if camera.is_position_behind(p):
			return Rect2()
		var s := camera.unproject_position(p)
		box = Rect2(s, Vector2.ZERO) if i == 0 else box.expand(s)
	return box

## World units per viewport pixel on the plane through the target, using the
## vertical FOV (Godot keeps height by default).
func _world_per_pixel() -> float:
	var vh := camera.get_viewport().get_visible_rect().size.y
	return 2.0 * _distance * tan(deg_to_rad(camera.fov) * 0.5) / maxf(vh, 1.0)
```

- [ ] **Step 2: Write the stage**

Create `world/stage.gd`:

```gdscript
extends Node3D

## The cozy diorama every board sits in: camera rig, warm sun, sky, table.
## Boards find this through the "stage" group and mount their Node3D here.

const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const CameraRig = preload("res://world/camera_rig.gd")

var rig: Node3D
var sun: DirectionalLight3D
var anchor: Node3D
var table: Node3D

func _ready() -> void:
	add_to_group("stage")

	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	# From behind-right and above, so shadows fall toward the player and left.
	sun.look_at_from_position(Vector3(3.0, 8.0, -6.0), Vector3.ZERO, Vector3.UP)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Pal.SKY_TOP
	sky_mat.sky_horizon_color = Pal.SKY_HORIZON
	sky_mat.ground_horizon_color = Pal.SKY_HORIZON
	sky_mat.ground_bottom_color = Pal.SKY_HORIZON
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Pal.AMBIENT
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	var world_env := WorldEnvironment.new()
	world_env.name = "Env"
	world_env.environment = env
	add_child(world_env)

	table = Models.instance("table")
	table.name = "Table"
	# The table model's origin is at its base; sink it so its top is y = 0.
	table.position = Vector3(0.0, -Models.height(table), 0.0)
	add_child(table)

	anchor = Node3D.new()
	anchor.name = "BoardAnchor"
	add_child(anchor)

func mount(board: Node3D) -> void:
	anchor.add_child(board)

func unmount(board: Node3D) -> void:
	if board.get_parent() == anchor:
		anchor.remove_child(board)

func fit_camera(aabb: AABB, rect: Rect2) -> void:
	rig.fit(aabb, rect)
```

Create `world/stage.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://world/stage.gd" id="1_stage"]

[node name="Stage" type="Node3D"]
script = ExtResource("1_stage")
```

Create `world/main.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://world/stage.tscn" id="1_stage"]
[ext_resource type="PackedScene" path="res://ui/menu.tscn" id="2_menu"]

[node name="Main" type="Node"]

[node name="Stage" parent="." instance=ExtResource("1_stage")]

[node name="UI" type="CanvasLayer" parent="."]

[node name="Menu" parent="UI" instance=ExtResource("2_menu")]
```

- [ ] **Step 3: Project settings**

In `project.godot`, change `run/main_scene` and the `[rendering]` section:

```
run/main_scene="res://world/main.tscn"
```

```
[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
anti_aliasing/quality/msaa_3d=1
environment/defaults/default_clear_color=Color(0.976, 0.949, 0.906, 1)
```

- [ ] **Step 4: Let the diorama show through the menu and host**

In `ui/menu.gd`, replace the opaque background in `_ready` with a translucent paper panel behind the list. The `_ready` becomes:

```gdscript
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_list()
```

and at the top of `_build_list`, right after `add_child(_list_root)`, add:

```gdscript
	var paper := ColorRect.new()
	paper.color = Color(Pal.PAPER, 0.9)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_root.add_child(paper)
```

In `ui/puzzle_host.gd` `_ready`, delete the five lines that create `bg` (from `var bg := ColorRect.new()` through `add_child(bg)`).

- [ ] **Step 5: Point the harnesses at the main scene**

In `tests/_shot.gd` and `tests/_win.gd`, replace the two menu lines in `_initialize` with:

```gdscript
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")
```

In `tests/_tap.gd`, replace the two lines in `_initialize` the same way.

- [ ] **Step 6: Run the full verification**

Run, in order:

```bash
godot --headless --path . --import 2>&1 | tail -2
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -2
godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | tail -14
godot --path . --resolution 540x960 --script res://tests/_shot.gd 2>&1 | tail -3
```

Expected: `failed=0`; `winnable=10/10` (Binairo is still 2D here); `/tmp/shot_menu.png` and `/tmp/shot_binairo.png` written. Open `/tmp/shot_menu.png` and confirm the cream sky and wooden table are visible behind the translucent menu panel and no black background remains. Any `SHADER ERROR` or `ERROR:` in the output is a failure.

- [ ] **Step 7: Commit**

```bash
git add project.godot world/ ui/menu.gd ui/puzzle_host.gd tests/_shot.gd tests/_win.gd tests/_tap.gd
git add -A '*.uid'
git commit -m "feat: 3D stage with camera rig, warm sun and sky under the 2D UI"
```

---

### Task 6: `PuzzleBase3D`

**Files:**
- Create: `core/puzzle_base_3d.gd`
- Modify: `core/puzzle_base.gd` (add `is_3d()`)

**Interfaces:**
- Consumes: `world/stage.gd` (`mount`, `unmount`, `fit_camera`), `core/board_math.gd`.
- Produces, on `core/puzzle_base_3d.gd` (extends `res://core/puzzle_base.gd`):
  - `var board: Node3D`
  - overridables `board_size() -> Vector2i` (cols, rows), `board_height() -> float`, `plane_height() -> float`, `on_board_press(hit: Vector3)`, `on_board_drag(hit: Vector3)`, `on_board_release(hit: Vector3)`
  - `board_aabb() -> AABB`, `viewport_rect() -> Rect2`, `local_to_board(local: Vector2) -> Variant`, `board_to_local(world: Vector3) -> Vector2`, `is_3d() -> bool` (true), `_refit()`
- `core/puzzle_base.gd` gains `func is_3d() -> bool: return false`.

Verified in Task 7 through the Binairo board and the win harness; there is no headless test because projection needs a viewport.

- [ ] **Step 1: Add the 2D default**

In `core/puzzle_base.gd`, after `func reset_board() -> void: pass`, add:

```gdscript
func is_3d() -> bool: return false
```

- [ ] **Step 2: Write the base**

Create `core/puzzle_base_3d.gd`:

```gdscript
extends "res://core/puzzle_base.gd"

## A PuzzleBase whose board lives in the 3D stage. The host still sees a
## Control filling the board slot: this class turns that slot into a camera
## frame and its touches into board-plane hits. Subclasses build into `board`
## and override the on_board_* hooks.

const BoardMath = preload("res://core/board_math.gd")

var board: Node3D
var _stage: Node
var _pressing := false

func is_3d() -> bool: return true

# --- to override ---
## Columns and rows of the board, in cells.
func board_size() -> Vector2i: return Vector2i(1, 1)
## How tall the tallest piece is; frames the camera.
func board_height() -> float: return 0.5
## Height of the surface taps land on (the tile tops).
func plane_height() -> float: return 0.0
func on_board_press(_hit: Vector3) -> void: pass
func on_board_drag(_hit: Vector3) -> void: pass
func on_board_release(_hit: Vector3) -> void: pass
# -------------------

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	board = Node3D.new()
	board.name = "%s_board" % puzzle_id()
	_stage = get_tree().get_first_node_in_group("stage")
	if _stage != null:
		_stage.mount(board)
	else:
		add_child(board)
	resized.connect(_refit)
	_refit()

func _exit_tree() -> void:
	if is_instance_valid(board):
		if _stage != null and is_instance_valid(_stage):
			_stage.unmount(board)
		board.queue_free()

func board_aabb() -> AABB:
	var s := board_size()
	return BoardMath.board_aabb(s.x, s.y, board_height())

## This control's rectangle in viewport pixels, the space the camera projects into.
func viewport_rect() -> Rect2:
	return get_global_transform_with_canvas() * Rect2(Vector2.ZERO, size)

func _refit() -> void:
	if _stage == null or not is_inside_tree():
		return
	_stage.fit_camera(board_aabb(), viewport_rect())

func _camera() -> Camera3D:
	return get_viewport().get_camera_3d()

## Board-plane point under a control-local position, or null when the ray misses.
func local_to_board(local: Vector2) -> Variant:
	var cam := _camera()
	if cam == null:
		return null
	var vp := get_global_transform_with_canvas() * local
	return BoardMath.ray_plane(cam.project_ray_origin(vp), cam.project_ray_normal(vp), plane_height())

## Control-local position of a world point; the inverse of local_to_board.
func board_to_local(world: Vector3) -> Vector2:
	var cam := _camera()
	if cam == null:
		return Vector2.INF
	return get_global_transform_with_canvas().affine_inverse() * cam.unproject_position(world)

## Touch events only. The project emulates touch from mouse, and the viewport
## hands a control both the mouse event and the emulated touch, so listening
## to both would fire twice per click.
func _gui_input(event: InputEvent) -> void:
	if is_done():
		return
	if event is InputEventScreenTouch:
		var hit = local_to_board(event.position)
		if event.pressed:
			if hit == null:
				return
			_pressing = true
			on_board_press(hit)
		elif _pressing:
			_pressing = false
			if hit != null:
				on_board_release(hit)
	elif event is InputEventScreenDrag and _pressing:
		var hit = local_to_board(event.position)
		if hit != null:
			on_board_drag(hit)
```

- [ ] **Step 3: Confirm it parses**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -2`
Expected: `failed=0` and no `SCRIPT ERROR` lines. (The runner does not load this file; the point is that the palette test still runs and nothing else broke. The real check is Task 7.)

Also parse the file directly:

```bash
godot --headless --path . --check-only --script res://core/puzzle_base_3d.gd 2>&1 | tail -3
```

Expected: no error output.

- [ ] **Step 4: Commit**

```bash
git add core/puzzle_base.gd core/puzzle_base_3d.gd
git add -A '*.uid'
git commit -m "feat: PuzzleBase3D mounts a board in the stage and raycasts touches"
```

---

### Task 7a: Move Binairo rule feedback into the generator

**Files:**
- Modify: `puzzles/binairo_gen.gd`
- Modify: `tests/test_binairo.gd`

**Interfaces:**
- Produces: `static func bad_lines(grid: Array) -> Dictionary` with keys `"rows"` and `"cols"`, each a Dictionary whose keys are the offending line indices (values `true`).

The logic is lifted from `_recheck` and `_line_bad` in `puzzles/binairo.gd` so the 3D board holds no rule code.

- [ ] **Step 1: Write the failing test**

In `tests/test_binairo.gd`, add `_test_bad_lines(t)` to `run` and the function:

```gdscript
static func _test_bad_lines(t) -> void:
	var clean: Dictionary = Gen.bad_lines(_grid(GOOD))
	t.check(clean.rows.is_empty() and clean.cols.is_empty(), "a valid grid has no bad lines")

	var empty: Dictionary = Gen.bad_lines(_grid(["......", "......", "......", "......", "......", "......"]))
	t.check(empty.rows.is_empty() and empty.cols.is_empty(), "an empty grid has no bad lines")

	var triple: Dictionary = Gen.bad_lines(_grid(["000...", "......", "......", "......", "......", "......"]))
	t.check(triple.rows.has(0) and triple.rows.size() == 1, "three in a row flags only that row")
	t.check(triple.cols.is_empty(), "three in a row flags no column")

	var too_many: Dictionary = Gen.bad_lines(_grid(["1.1.1.", "1.....", "......", "1.....", "1.....", "......"]))
	t.check(too_many.rows.has(0), "four ones in a six-row is over half")
	t.check(too_many.cols.has(0), "four ones in a six-column is over half")

	var twin_rows: Dictionary = Gen.bad_lines(_grid(["010011", "010011", "......", "......", "......", "......"]))
	t.check(twin_rows.rows.has(0) and twin_rows.rows.has(1), "identical complete rows flag both rows")

	var partial_twins: Dictionary = Gen.bad_lines(_grid(["01001.", "01001.", "......", "......", "......", "......"]))
	t.check(not partial_twins.rows.has(0), "incomplete rows are never compared")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "binairo|failed=" | head -5`
Expected: errors mentioning `bad_lines`; `failed=` greater than 0.

- [ ] **Step 3: Write bad_lines**

Append to `puzzles/binairo_gen.gd`:

```gdscript
## Rule feedback for a partial grid: which rows and columns already break a
## rule (three alike in a row, more than half of one symbol, or two identical
## complete lines). Boards tint these so players learn the rules by touch.
static func bad_lines(grid: Array) -> Dictionary:
	var n: int = grid.size()
	var rows := {}
	var cols := {}
	var half: int = n / 2
	for i in n:
		var row := []
		var col := []
		for j in n:
			row.append(grid[i][j])
			col.append(grid[j][i])
		if _line_bad(row, half):
			rows[i] = true
		if _line_bad(col, half):
			cols[i] = true
	for a in n:
		for b in range(a + 1, n):
			if not (grid[a] as Array).has(-1) and grid[a] == grid[b]:
				rows[a] = true
				rows[b] = true
			var ca := []
			var cb := []
			for i in n:
				ca.append(grid[i][a])
				cb.append(grid[i][b])
			if not ca.has(-1) and ca == cb:
				cols[a] = true
				cols[b] = true
	return {"rows": rows, "cols": cols}

static func _line_bad(line: Array, half: int) -> bool:
	var zeros := 0
	var ones := 0
	for v in line:
		if v == 0:
			zeros += 1
		elif v == 1:
			ones += 1
	if zeros > half or ones > half:
		return true
	for i in range(line.size() - 2):
		if line[i] != -1 and line[i] == line[i + 1] and line[i + 1] == line[i + 2]:
			return true
	return false
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -2`
Expected: `failed=0`.

- [ ] **Step 5: Commit**

```bash
git add puzzles/binairo_gen.gd tests/test_binairo.gd
git commit -m "refactor: Binairo rule feedback lives in the generator as bad_lines"
```

---

### Task 7b: Binairo on the stage

**Files:**
- Create: `puzzles/binairo3d.gd`
- Delete: `puzzles/binairo.gd`, `puzzles/binairo.gd.uid`
- Modify: `ui/registry.gd` (binairo entry `script`)
- Modify: `tests/_win.gd` (`_solve_binairo`, `_note`, result `ok`)
- Modify: `tests/_tap.gd`

**Interfaces:**
- Consumes: `core/puzzle_base_3d.gd`, `core/models.gd`, `core/board_math.gd`, `core/placeholders.gd` (`TOKEN_H`), `binairo_gen.gd` (`generate`, `is_valid_complete`, `bad_lines`).
- Produces: `puzzles/binairo3d.gd` with the `PuzzleBase` interface plus `var n: int`, `var _grid`, `var _given`, `var _solution`, `func cell_to_local(r: int, c: int) -> Vector2`.

- [ ] **Step 1: Write the board**

Create `puzzles/binairo3d.gd`:

```gdscript
extends "res://core/puzzle_base_3d.gd"

## Binairo on the 3D stage. Tap a tile to cycle empty -> circle -> square ->
## empty. Tiles in a line that already breaks a rule blush, so the player
## learns the rules by touching rather than by reading them.

const Gen = preload("res://puzzles/binairo_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")

const POP_TIME := 0.18

var n: int = 6
var _grid: Array = []
var _given: Array = []
var _solution: Array = []
var _bad: Dictionary = {"rows": {}, "cols": {}}

var _tile_h: float = Placeholders.TILE_H
var _tiles: Array = []     # [r][c] -> Node3D
var _circles: Array = []   # [r][c] -> Node3D
var _squares: Array = []   # [r][c] -> Node3D

func puzzle_id() -> String: return "binairo"
func title() -> String: return "Binairo"

func rules() -> String:
	return "Fill every cell. Never three alike in a line, an equal count of each per line, and no two lines identical."

func board_size() -> Vector2i: return Vector2i(n, n)
func board_height() -> float: return _tile_h + Placeholders.TOKEN_H + 0.1
func plane_height() -> float: return _tile_h

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var min_clues := 0
	match difficulty:
		0: n = 6; min_clues = 16
		1: n = 6; min_clues = 0
		_: n = 8; min_clues = 0
	var out: Dictionary = Gen.generate(rng, n, min_clues)
	_solution = out.solution
	_grid = []
	_given = []
	for r in n:
		var row: Array = []
		var given_row: Array = []
		for c in n:
			var v = out.puzzle[r][c]
			row.append(v)
			given_row.append(v != -1)
		_grid.append(row)
		_given.append(given_row)
	_build_scene()
	_recheck()
	_refit()

func reset_board() -> void:
	for r in n:
		for c in n:
			if not _given[r][c]:
				_grid[r][c] = -1
			_show_token(r, c, false)
	moves = 0
	_recheck()

func is_solved() -> bool:
	return Gen.is_valid_complete(_grid)

func share_glyphs() -> String:
	var out := ""
	for r in n:
		for c in n:
			out += "🟦" if _grid[r][c] == 0 else "🟧"
		out += "\n"
	return out

# --- scene ---

func _build_scene() -> void:
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_tiles = []
	_circles = []
	_squares = []
	for r in n:
		var tile_row := []
		var circle_row := []
		var square_row := []
		for c in n:
			var at := BoardMath.cell_center(r, c, n, n, 0.0)
			var tile := Models.instance("tile")
			tile.position = at
			board.add_child(tile)
			tile_row.append(tile)
			if r == 0 and c == 0:
				_tile_h = Models.height(tile)
			var top := at + Vector3(0.0, _tile_h, 0.0)
			var circle := Models.instance("token_circle")
			circle.position = top
			board.add_child(circle)
			circle_row.append(circle)
			var square := Models.instance("token_square")
			square.position = top
			board.add_child(square)
			square_row.append(square)
			if _given[r][c]:
				var ring := Models.instance("given_ring")
				ring.position = top
				board.add_child(ring)
		_tiles.append(tile_row)
		_circles.append(circle_row)
		_squares.append(square_row)
	for r in n:
		for c in n:
			_show_token(r, c, false)

func _show_token(r: int, c: int, pop: bool) -> void:
	var v: int = _grid[r][c]
	var circle: Node3D = _circles[r][c]
	var square: Node3D = _squares[r][c]
	circle.visible = v == 0
	square.visible = v == 1
	circle.scale = Vector3.ONE
	square.scale = Vector3.ONE
	if pop and v != -1:
		var token: Node3D = circle if v == 0 else square
		token.scale = Vector3.ONE * 0.01
		var tw := create_tween()
		tw.tween_property(token, "scale", Vector3.ONE, POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _recheck() -> void:
	_bad = Gen.bad_lines(_grid)
	for r in n:
		for c in n:
			var bad: bool = _bad.rows.has(r) or _bad.cols.has(c)
			var col: Color
			if bad:
				col = Pal.BAD_TILE.lerp(Pal.SURFACE_HI, 0.3) if _given[r][c] else Pal.BAD_TILE
			else:
				col = Pal.SURFACE_HI if _given[r][c] else Pal.SURFACE
			Models.tint(_tiles[r][c], col)

# --- input ---

func on_board_press(hit: Vector3) -> void:
	var cell := BoardMath.world_to_cell(hit, n, n)
	if cell.x < 0:
		return
	var c := cell.x
	var r := cell.y
	if _given[r][c]:
		return
	# empty -> 0 -> 1 -> empty
	var v: int = _grid[r][c]
	_grid[r][c] = 0 if v == -1 else (1 if v == 0 else -1)
	_show_token(r, c, true)
	_recheck()
	note_move()

## Control-local point over the centre of cell (r, c). The win harness taps
## this; it is the 3D counterpart of the 2D boards' origin + (c+.5, r+.5) * cell.
func cell_to_local(r: int, c: int) -> Vector2:
	return board_to_local(BoardMath.cell_center(r, c, n, n, _tile_h))
```

- [ ] **Step 2: Swap the registry entry and delete the 2D board**

In `ui/registry.gd`, change the binairo entry's script:

```gdscript
		"script": "res://puzzles/binairo3d.gd",
```

Then:

```bash
git rm -q puzzles/binairo.gd puzzles/binairo.gd.uid
```

- [ ] **Step 3: Teach the win harness the 3D board**

In `tests/_win.gd`:

Add a field after `var _results: Array = []`:

```gdscript
var _fit_ok := true
```

Replace `_solve_binairo` with:

```gdscript
func _solve_binairo() -> void:
	var n: int = _puzzle.n
	# Camera fit check: every cell centre must project inside the board slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in n:
		for c in n:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	for r in n:
		for c in n:
			if _puzzle.is_done():
				return
			if _puzzle._given[r][c]:
				continue
			var target: int = _puzzle._solution[r][c]
			# empty -> 0 is one tap, empty -> 1 is two.
			for k in (1 if target == 0 else 2):
				_tap_local(_puzzle.cell_to_local(r, c))
```

In `_process`, at `slot == 12` before `_solve(...)`, add `_fit_ok = true`. In the `_results.append` dictionary change `"ok": solved and done and overlay,` to `"ok": solved and done and overlay and _fit_ok,`.

In `_note`, change the binairo line to:

```gdscript
		"binairo": return "%d moves, camera fit=%s" % [_puzzle.moves, _fit_ok]
```

In `tests/_tap.gd`, replace the body of `_tap` with:

```gdscript
func _tap(r: int, c: int) -> void:
	var at: Vector2 = _puzzle.get_global_transform_with_canvas() * _puzzle.cell_to_local(r, c)
	for pressed in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = pressed
		ev.position = at
		root.push_input(ev, true)
```

and change its `print("grid n=", ...)` line to `print("grid n=", _puzzle.n, " slot=", _puzzle.size)`.

- [ ] **Step 4: Run the full verification**

```bash
godot --headless --path . --import 2>&1 | tail -2
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -2
godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | tail -14
godot --path . --resolution 540x960 --script res://tests/_shot.gd 2>&1 | tail -3
```

Expected: `failed=0`; `winnable=10/10` with the binairo line reading `camera fit=true`; `/tmp/shot_binairo.png` shows a 6 by 6 board of cream tiles with teal and terracotta tokens, dark outlines, lavender-tinted shadows on the wood, fully inside the board slot below the rules text. `/tmp/won_binairo.png` shows the solved overlay.

If `winnable` drops below 10 for binairo with `solved=false`: taps are landing on the wrong cells. Print `_puzzle.cell_to_local(0, 0)` and `_puzzle.local_to_board(_puzzle.cell_to_local(0, 0))` from the harness; the second should be near `BoardMath.cell_center(0, 0, n, n, 0.12)`. A mismatch means the canvas transform is applied on one side only.

- [ ] **Step 5: Commit**

```bash
git add puzzles/binairo3d.gd ui/registry.gd tests/_win.gd tests/_tap.gd
git add -A '*.uid'
git commit -m "feat: Binairo as the first 3D toon board, win suite drives it by projection"
```

---

### Task 8: Cozy 2D chrome

**Files:**
- Create: `ui/theme.gd`
- Modify: `ui/menu.gd`
- Modify: `ui/puzzle_host.gd`

**Interfaces:**
- Consumes: `PuzzleBase.is_3d()`, palette.
- Produces: `ui/theme.gd` `static func make() -> Theme`.

- [ ] **Step 1: Write the theme**

Create `ui/theme.gd`:

```gdscript
extends RefCounted

## One warm theme for every Control. Buttons are rounded paper cards with dark
## text; labels default to the ink colour. Built in code so it stays in step
## with the palette.

const Pal = preload("res://core/palette.gd")

static func make() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("normal", "Button", _card(Pal.SURFACE_HI))
	theme.set_stylebox("hover", "Button", _card(Pal.SURFACE))
	theme.set_stylebox("pressed", "Button", _card(Pal.LINE))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", Pal.TEXT)
	theme.set_color("font_hover_color", "Button", Pal.TEXT)
	theme.set_color("font_pressed_color", "Button", Pal.TEXT)
	theme.set_color("font_focus_color", "Button", Pal.TEXT)
	theme.set_color("font_color", "Label", Pal.TEXT)
	return theme

static func _card(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(28)
	sb.set_content_margin_all(24)
	sb.border_width_bottom = 6
	sb.border_color = Pal.LINE
	return sb
```

- [ ] **Step 2: Apply it in the menu**

In `ui/menu.gd`, add the preload:

```gdscript
const CozyTheme = preload("res://ui/theme.gd")
```

and as the first line of `_ready`:

```gdscript
	theme = CozyTheme.make()
```

The host is a child of the menu, so it inherits the theme.

- [ ] **Step 3: Paper card behind 2D boards and a warm overlay**

In `ui/puzzle_host.gd`:

Add a field:

```gdscript
var _card: Panel
```

In `_ready`, right after `_board_holder = Control.new()` ... `root.add_child(_board_holder)`, add:

```gdscript
	_card = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.PAPER
	sb.set_corner_radius_all(32)
	_card.add_theme_stylebox_override("panel", sb)
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_holder.add_child(_card)
```

In `_spawn`, after `_puzzle.start(rng, _difficulty)`, add:

```gdscript
	_card.visible = not _puzzle.is_3d()
```

In `_build_overlay`, change the overlay colour and label colour:

```gdscript
	(_overlay as ColorRect).color = Color(Pal.PAPER, 0.85)
```

```gdscript
	_overlay_label.add_theme_color_override("font_color", Pal.TEXT)
```

- [ ] **Step 4: Verify by screenshot**

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -2
godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | tail -3
godot --path . --resolution 540x960 --script res://tests/_shot.gd 2>&1 | tail -2
```

Expected: `failed=0`, `winnable=10/10`. Open `/tmp/shot_menu.png`, `/tmp/shot_binairo.png`, `/tmp/shot_pipes.png`, `/tmp/won_binairo.png`: buttons are rounded cream cards with dark text; the Pipes board sits on a paper card while Binairo sits directly on the wood; the solved overlay is translucent paper with dark text.

- [ ] **Step 5: Commit**

```bash
git add ui/theme.gd ui/menu.gd ui/puzzle_host.gd
git add -A '*.uid'
git commit -m "feat: warm paper chrome, card behind 2D boards, translucent solved overlay"
```

---

### Task 9: Blender contract, export script, repo hygiene

**Files:**
- Create: `docs/art/blender-contract.md`
- Create: `tools/blender_export.py`
- Create: `.gitattributes`
- Modify: `.gitignore`
- Modify: `README.md`

**Interfaces:**
- Consumes: slot names from `core/models.gd`.
- Produces: the artist-facing contract and a Blender-side exporter writing `assets/models/<slot>.glb`.

- [ ] **Step 1: Write the contract**

Create `docs/art/blender-contract.md`:

```markdown
# Blender contract

The whole agreement between a model made in Blender and the game. If a model
follows these rules, exporting it to `assets/models/<slot>.glb` is the entire
integration: the game finds it by name, converts its materials to the toon
shader, adds the outline, and places it. Nothing else to configure.

## Slots

| slot | footprint (X by Y in Blender) | max height (Z) | notes |
|---|---|---|---|
| `tile` | 1.0 x 1.0, use about 0.92 | 0.12 | pieces sit on its top face |
| `token_circle` | inside 0.8 x 0.8 | 0.6 | the "circle" state in Binairo |
| `token_square` | inside 0.8 x 0.8 | 0.6 | the "square" state in Binairo |
| `given_ring` | inside 1.0 x 1.0 | 0.1 | lies on a tile to mark a clue |
| `table` | any, about 14 x 14 | any | the game sinks it so its top is at 0 |

The list lives in code as `SLOTS` in `core/models.gd`. New puzzles add rows.

## Rules

1. **Units.** Metric, unit scale 1.0. One Blender unit is one board cell.
2. **Origin at the centre of the base.** The lowest vertex is at Z = 0 and
   the footprint is centred on X = Y = 0. Blender is Z-up; the glTF exporter
   converts to Godot's Y-up for you, so model with Z as up and do nothing else.
3. **Apply transforms.** Rotation (0, 0, 0), scale (1, 1, 1) before export.
4. **Shade smooth with shared vertices.** No split edges, no flat shading,
   no Edge Split modifier. Hard-edge looks come from Shade Auto Smooth
   (Smooth by Angle) or Weighted Normal instead. Reason: the outline draws a
   second copy of the mesh pushed out along the vertex normals; split
   vertices leave visible gaps at every corner.
5. **Materials are colours.** One Principled BSDF per material, Base Color set,
   nothing else needed. The game replaces every material with the toon shader
   using that base colour. Textures export fine but are ignored by the toon
   shader for now.
6. **`_flat` suffix.** A material named like `Wood_flat` gets toon shading but
   no outline. Use it for the table and any surface that should not read as a
   piece.
7. **Export settings.** glTF Binary (`.glb`), +Y Up, Apply Modifiers,
   Selected Objects, Materials: Export, no cameras, no lights, no animation.
   File name is the slot name. The script below does all of this.

## Export script

`tools/blender_export.py` checks the rules and exports. Inside Blender, open
the Scripting tab, load the file and run it with the objects selected, or
from a shell:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b art/pieces.blend \
  --python tools/blender_export.py -- tile token_circle token_square
```

With no names it exports the selected objects; with nothing selected, every
top-level mesh. Object names are lowercased to form the slot name. Each
object prints one line, `OK` with the output path or `SKIP` with the rule it
broke, and the process exits non-zero if anything was skipped.

## Seeing it in the game

```bash
godot --headless --path . --import          # register the new .glb
godot --path . --resolution 540x960 --script res://tests/_shot.gd
open /tmp/shot_binairo.png
```
```

- [ ] **Step 2: Write the exporter**

Create `tools/blender_export.py`:

```python
"""Export selected Blender objects to the game's model slots.

Run inside Blender (Scripting tab) or from a shell:

    /Applications/Blender.app/Contents/MacOS/Blender -b my.blend \
        --python tools/blender_export.py -- [ObjectName ...]

Each object is checked against docs/art/blender-contract.md and, if it passes,
written to assets/models/<object name lowercased>.glb. One line per object:
"OK <slot> <path> <bytes>" or "SKIP <name>: <rule broken>". Exit status is 1
when anything was skipped.
"""

import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "models"
TOLERANCE = 0.001
FOOTPRINT = 1.0
MAX_HEIGHT = 0.6
UNBOUNDED = {"table"}


def world_bounds(obj):
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    if not pts:
        return None, None
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def problems(obj):
    """Every contract rule the object breaks, as short strings."""
    found = []
    if obj.type != "MESH":
        return ["not a mesh"]
    if any(abs(a) > 1e-6 for a in obj.rotation_euler):
        found.append("rotation not applied")
    if any(abs(s - 1.0) > 1e-6 for s in obj.scale):
        found.append("scale not applied")
    lo, hi = world_bounds(obj)
    if lo is None:
        return ["mesh has no vertices"]
    origin = obj.matrix_world.translation
    if abs(lo.z - origin.z) > TOLERANCE:
        found.append("base not at origin height (lowest vertex %.3f above origin)" % (lo.z - origin.z))
    centre_x = (lo.x + hi.x) * 0.5 - origin.x
    centre_y = (lo.y + hi.y) * 0.5 - origin.y
    if abs(centre_x) > TOLERANCE or abs(centre_y) > TOLERANCE:
        found.append("origin not at footprint centre (off by %.3f, %.3f)" % (centre_x, centre_y))
    if not all(p.use_smooth for p in obj.data.polygons):
        found.append("not shaded smooth")
    slot = obj.name.lower()
    if slot not in UNBOUNDED:
        if hi.x - lo.x > FOOTPRINT + TOLERANCE or hi.y - lo.y > FOOTPRINT + TOLERANCE:
            found.append("footprint %.2f x %.2f exceeds 1 x 1" % (hi.x - lo.x, hi.y - lo.y))
        if hi.z - lo.z > MAX_HEIGHT + TOLERANCE:
            found.append("height %.2f exceeds %.1f" % (hi.z - lo.z, MAX_HEIGHT))
    return found


def export(obj):
    slot = obj.name.lower()
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / (slot + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    for child in obj.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = obj
    parked = obj.location.copy()
    obj.location = Vector((0.0, 0.0, 0.0))
    bpy.context.view_layer.update()
    try:
        bpy.ops.export_scene.gltf(
            filepath=str(path),
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_cameras=False,
            export_lights=False,
            export_animations=False,
        )
    finally:
        obj.location = parked
        bpy.context.view_layer.update()
    return path


def pick_objects(names):
    if names:
        missing = [n for n in names if bpy.data.objects.get(n) is None]
        if missing:
            raise SystemExit("no such object: " + ", ".join(missing))
        return [bpy.data.objects[n] for n in names]
    selected = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    if selected:
        return selected
    return [o for o in bpy.data.objects if o.type == "MESH" and o.parent is None]


def main():
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    skipped = 0
    for obj in pick_objects(names):
        bad = problems(obj)
        if bad:
            skipped += 1
            print("SKIP %s: %s" % (obj.name, "; ".join(bad)))
            continue
        path = export(obj)
        print("OK %s %s %d" % (obj.name.lower(), path, path.stat().st_size))
    if skipped:
        print("%d object(s) skipped" % skipped)
        if bpy.app.background:
            sys.exit(1)


main()
```

- [ ] **Step 3: Repo hygiene and README**

Create `.gitattributes`:

```
*.glb binary
*.blend binary
```

Append to `.gitignore`:

```
# Blender backups
*.blend1
```

In `README.md`: change the "Deliberately unfinished art" sentence in Running to:

```
Boards sit on a 3D toon-shaded stage. Models are primitive placeholders until
Blender exports land in `assets/models/` (see `docs/art/blender-contract.md`).
```

Add to the Layout block:

```
world/      3D stage: camera rig, sun, sky, table; main scene
shaders/    toon and outline spatial shaders
assets/     models/<slot>.glb from Blender, placeholders otherwise
tools/      blender_export.py, run inside Blender
```

Add to Docs:

```
- `docs/art/blender-contract.md` — modelling rules and export for 3D pieces
```

- [ ] **Step 4: Verify the exporter against the real Blender**

Run the exporter on a fresh scene with one contract-following cube, in background mode, writing to a temp copy of the repo path so the real `assets/models/` stays clean:

```bash
cat > /tmp/contract_cube.py <<'EOF'
import bpy, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_cube_add(size=0.9)
cube = bpy.context.active_object
cube.name = "Tile"
# Sit the base on Z = 0 and apply it into the mesh so the origin rule holds.
cube.location.z = 0.45
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
cube.scale = (1.0, 1.0, 0.1333)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bpy.ops.object.shade_smooth()
mat = bpy.data.materials.new("Cream")
mat.use_nodes = True
mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1.0, 0.99, 0.97, 1.0)
cube.data.materials.append(mat)
sys.argv = [sys.argv[0], "--", "Tile"]
exec(open("/Users/flavioriper/dev/daily/tools/blender_export.py").read())
EOF
cd /tmp && /Applications/Blender.app/Contents/MacOS/Blender -b --python /tmp/contract_cube.py 2>&1 | grep -E "^(OK|SKIP)|Error|Traceback" 
```

Expected: one line `OK tile /Users/flavioriper/dev/daily/assets/models/tile.glb <bytes>`. Note `ROOT` in the script resolves from the script file, so the export lands in the real repo. That is the intended next check:

```bash
cd /Users/flavioriper/dev/daily
godot --headless --path . --import 2>&1 | tail -1
godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | grep -E "binairo|winnable"
godot --path . --resolution 540x960 --script res://tests/_shot.gd 2>&1 | tail -1
```

Expected: binairo `PASS` with `camera fit=true`, `winnable=10/10`, and `/tmp/shot_binairo.png` shows the imported cube tiles (visually a slightly different tile from the placeholder prism: sharper corners). Then remove the test export so the repo ships placeholders only:

```bash
git status --short assets/
rm -f assets/models/tile.glb assets/models/tile.glb.import
git status --short assets/
```

Expected: nothing left under `assets/models/` except `README.md`.

- [ ] **Step 5: Final full run and commit**

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -2
godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | tail -3
git add docs/art/blender-contract.md tools/blender_export.py .gitattributes .gitignore README.md
git commit -m "docs: Blender contract and export script for model slots"
```

Expected: `failed=0`, `winnable=10/10`, clean commit.
