# 3D toon pipeline — design

Date: 2026-09-13. Status: approved for planning.

## Goal

Move the daily puzzle game from flat 2D drawing to a cozy 3D look: Blender
models, cel (toon) shading with warm tinted shadows, dark-brown outlines, a
tilted board-game camera, and a small diorama behind the board. This pass
builds the pipeline end to end and converts one board (Binairo) as the worked
example. The other nine boards keep drawing in 2D and pick up the new palette
until they are converted in later passes.

Decisions already taken with the user:

- Full 3D scene: camera looks down at a board in a diorama. Menu and HUD stay
  2D on top.
- Scope: pipeline plus Binairo. Nothing else is converted.
- Blender models arrive as `.glb` files exported from Blender. No `.blend`
  import.
- Tilted perspective camera, not isometric, not top-down.
- One renderer (Compatibility / OpenGL) on every platform so the Mac
  screenshots show what the phone shows.
- Outlines by inverted hull (a second draw of the mesh with front faces
  culled and vertices pushed along normals). No screen-space post-process.

## Non-goals

- Converting the other nine boards.
- Any real art. Every mesh in this pass is a Godot primitive placeholder that
  a `.glb` of the same name replaces.
- Animation beyond a placement pop and tile tint.
- Physics. Touch hits are computed against a mathematical plane.
- Saving, daily rollover UI, sharing. Untouched.

## 1. Scene layout and the stage

### Main scene

`world/main.tscn` becomes the project's main scene:

```
Main (Node)
├── Stage (Node3D, world/stage.tscn)
│   ├── CameraRig (Node3D, world/camera_rig.gd)
│   │   └── Camera3D
│   ├── Sun (DirectionalLight3D)
│   ├── Env (WorldEnvironment)
│   ├── Table (MeshInstance3D from ModelLibrary "table")
│   └── BoardAnchor (Node3D)
└── UI (CanvasLayer)
    └── Menu (ui/menu.tscn instance)
```

The 3D world renders under every CanvasItem in the same viewport, so the
diorama is always the background. The opaque background `ColorRect` in the
menu and in the host go away. The menu keeps a translucent paper panel behind
its list so the buttons stay readable over the diorama.

### Stage (`world/stage.gd`)

Owns the environment and exposes three calls. It joins the `stage` group in
`_ready` so boards find it with `get_tree().get_first_node_in_group("stage")`.

- `mount(board: Node3D)` parents the board under `BoardAnchor`.
- `unmount(board: Node3D)` removes it.
- `fit_camera(aabb: AABB, rect: Rect2)` forwards to the camera rig.

Environment settings, all warm:

- Sky: `ProceduralSkyMaterial`, cream top, peach horizon, no sun disc.
- Ambient: from sky, energy about 0.6, so unlit faces are never black.
- Sun: warm white, energy about 1.2, pitched about 50 degrees down and yawed
  about 30 degrees so tokens cast a short shadow toward the player. Shadows on.
- Tonemap linear. Glow off. SSAO and SSR off (not on Compatibility anyway).

### Camera rig (`world/camera_rig.gd`)

Fixed direction, fitted distance. Parameters: pitch 55 degrees below
horizontal, yaw 0 (looking straight up the board), vertical FOV 35 degrees.

`fit(aabb: AABB, rect: Rect2)` positions the camera so every corner of the
AABB projects inside `rect` with a 6 percent margin and the projected centre
sits on the rect centre. `rect` is in viewport pixels.

Algorithm, run only on build and resize:

1. Target starts at the AABB centre.
2. Binary search the distance along the fixed view direction over
   `[0.5, 200]` for 24 steps, picking the smallest distance where all eight
   projected corners fall inside the shrunk rect.
3. Compute the pixel offset between the projected corner bounding box centre
   and the rect centre. Move the target along the camera's right and up
   vectors by that offset times world units per pixel at the current
   distance. Repeat steps 2 and 3 three times.

Projection uses `Camera3D.unproject_position`, so the rig must be the current
camera inside a live viewport. This is true in the game and in the win and
screenshot harnesses. It is not true in headless unit tests, which is why the
rig is verified end to end rather than unit tested.

## 2. Toon material, outline, and the model library

### Shaders

`shaders/toon.gdshader` (spatial):

- Uniforms: `albedo` (source colour), `ramp` (sampler2D, nearest filter),
  `shadow_tint` (source colour, default lavender `b7a6c4`), `rim_strength`,
  `rim_width`, `rim_color`.
- `fragment()`: `ALBEDO = albedo`, roughness 1, specular 0, rim as a hard
  step on `1 - dot(NORMAL, VIEW)` written to `EMISSION`.
- `light()`: `t = ndl * 0.5 + 0.5` scaled by `ATTENUATION`, banded through
  the ramp, then
  `DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint, 1, band)`.
  No `ALBEDO` factor here: the Compatibility scene shader multiplies
  `diffuse_light` by albedo afterwards (verified in `scene.glsl`), and
  `LIGHT_COLOR` arrives as colour times energy times PI. Tinted shadows
  instead of darkened ones are what make the look cozy.
- `render_mode cull_back, depth_draw_opaque`. Nothing here needs depth or
  screen textures, so it runs on Compatibility.

`shaders/outline.gdshader` (spatial):

- `render_mode cull_front, unshaded, depth_draw_opaque`.
- Uniforms: `color` (default dark brown `3b2f28`), `width` (world units,
  default 0.02), `distance_scale` (default 0, so width is constant; raise it
  if far pieces look thin).
- `vertex()`: `VERTEX += NORMAL * width * (1 + distance_scale * view_dist)`.

The outline is attached as a child `MeshInstance3D` named `Outline` that
shares the parent's mesh, uses the outline material as `material_override`,
and has shadow casting off. Not `material_overlay` and not `next_pass`: both
draw the inflated hull into the shadow map too, so every piece would cast a
fattened shadow (found and fixed the same way in the peeplet project).

Inverted hull needs smooth shading with shared vertices. That rule goes in
the Blender contract, and the placeholder primitives already satisfy it.

### Toon factory (`core/toon.gd`, static)

- `ramp() -> GradientTexture1D`: three constant steps at offsets 0, 0.35,
  0.7 with values 0.45, 0.8, 1.0. Built once and cached.
- `material(albedo: Color) -> ShaderMaterial`: toon material. Cached per
  albedo (dictionary keyed by `Color.to_html()`), so tinting a hundred tiles
  the same colour costs one material.
- `outline() -> ShaderMaterial`: the one shared outline material.
- `add_outline(mesh_instance: MeshInstance3D)`: adds the `Outline` shell
  child described above. Idempotent: a second call finds the existing shell.
- `apply_to(root: Node)`: walks `MeshInstance3D` descendants. For each surface
  whose material is a `StandardMaterial3D`, sets a surface override to
  `material(albedo_color)`. A mesh gets an outline shell unless every surface
  material name ends in `_flat` (toon shading stays; only the outline is
  skipped, so the table still receives the pieces' shadows). Materials that
  are already `ShaderMaterial` are left alone. This is how a plain Blender
  export becomes toon at load time with no editor import configuration.

### Model library (`core/models.gd`, static)

- `SLOTS`: the model names the game asks for. This pass:
  `tile`, `token_circle`, `token_square`, `given_ring`, `table`.
- `instance(name: String) -> Node3D`: if `res://assets/models/<name>.glb`
  exists, load it, instantiate, run `Toon.apply_to`, return. Otherwise return
  `Placeholders.make(name)`. Loaded scenes are cached.
- `Placeholders.make(name)` (`core/placeholders.gd`) builds a
  `MeshInstance3D` from Godot primitives with a toon material from the
  palette, matching the footprint rules in the Blender contract:

  | slot | primitive | size (x, y, z) | colour |
  |---|---|---|---|
  | `tile` | BoxMesh | 0.92, 0.12, 0.92 | `SURFACE` |
  | `token_circle` | CylinderMesh | r 0.30, h 0.18 | `ACCENT` |
  | `token_square` | BoxMesh | 0.50, 0.18, 0.50 | `ACCENT_2` |
  | `given_ring` | TorusMesh | inner 0.38, outer 0.44 | `TEXT_DIM` |
  | `table` | BoxMesh | 14, 0.4, 14 | `WOOD`, no outline |

  Square pieces are four-sided `CylinderMesh` prisms turned 45 degrees
  rather than `BoxMesh`: a `BoxMesh` has split flat normals and the outline
  hull opens at every corner, while cylinder sides share vertices. Every
  placeholder is a `Node3D` root whose origin is at the centre of its base, so
  it sits on y = 0 of whatever it is placed on, the same rule the contract
  gives to Blender models.

## 3. Blender contract

Written to `docs/art/blender-contract.md` and linked from the README. It is
the whole agreement between the Blender side and the Godot side; if a model
follows it, dropping the file in `assets/models/` is the entire integration.

- Units metric, 1 Blender unit = 1 board cell. A tile is 1 by 1 in footprint.
  Pieces stay inside a 0.8 by 0.8 footprint and under 0.6 tall.
- Origin at the centre of the base. y = 0 is the surface the model rests on.
  Blender is Z-up; the glTF exporter converts to Y-up, so model with Z as up
  in Blender and do nothing special.
- Apply all transforms before export. Scale 1, rotation 0.
- Shade smooth with shared vertices. No split edges, no flat shading. Reason:
  the outline pass grows vertices along normals, and split vertices leave gaps.
  Use Auto Smooth or Weighted Normal for hard-edge looks.
- Materials: plain Principled BSDF, base colour only. No textures needed. The
  game replaces every material with the toon shader using that base colour.
  Name a material with the suffix `_flat` to skip the outline on that mesh
  (the table, ground, anything that should not read as a piece).
- Export: glTF Binary (`.glb`), +Y up, Apply Modifiers, Selected Objects,
  Materials export, no cameras, no lights, no animations. File name equals
  the slot name from the table above.
- `tools/blender_export.py`: run inside Blender (Scripting tab or
  `Blender --background file.blend --python tools/blender_export.py`). For each
  selected object it checks the rules above (applied scale and rotation,
  smooth shading, origin at base within 1 mm) and exports to
  `assets/models/<object_name>.glb`. It prints one line per object: exported,
  or the rule it broke.

Repo hygiene: `.gitattributes` marks `*.glb` and `*.blend` as binary.
`.gitignore` adds `*.blend1`.

## 4. `PuzzleBase3D` and the Binairo reference board

### `core/puzzle_base_3d.gd`

`class_name PuzzleBase3D extends PuzzleBase`. From the host's side it is
still a `PuzzleBase`: same signals, same overridable interface, same lifecycle.
Inside, it is a transparent `Control` that occupies the board slot and owns a
`Node3D` board in the stage.

- `board: Node3D` created in `_ready`, mounted on the stage found via the
  `stage` group. Freed and unmounted in `_exit_tree`.
- `board_size() -> Vector2i` and `plane_height() -> float` are overridable.
  The board's AABB is derived from them.
- `resized` triggers `_refit()`, which calls
  `stage.fit_camera(aabb, viewport_rect)` where `viewport_rect` is this
  control's global rect in viewport pixels
  (`get_global_transform_with_canvas() * get_rect()`).
- `_gui_input` accepts the same touch and mouse events the 2D boards accept,
  converts the position to viewport pixels, casts a ray from the camera, and
  intersects the plane at `plane_height()`. The hit is passed to
  `on_board_press(hit: Vector3)`, `on_board_drag(hit)`, `on_board_release(hit)`,
  all overridable. Rays that miss the plane are ignored.
- `cell_to_local(r, c) -> Vector2`: projects the cell centre back to this
  control's local coordinates. This is what the win harness taps, and it is
  the 3D counterpart of the 2D boards' `origin + (c + 0.5, r + 0.5) * cell`.
- `_draw` draws nothing.

### `core/board_math.gd` (static, pure)

Everything geometric that does not need a camera, so it is unit testable:

- `ray_plane(origin: Vector3, dir: Vector3, y: float) -> Variant`: the hit
  point, or `null` when the ray is parallel or points away.
- `cell_origin(cols, rows) -> Vector3`: the world position of cell (0, 0)'s
  corner for a board centred on the anchor.
- `cell_center(r, c, cols, rows, y) -> Vector3`.
- `world_to_cell(hit: Vector3, cols, rows) -> Vector2i`: `(-1, -1)` when
  outside.
- `board_aabb(cols, rows, height) -> AABB`.

### Binairo in 3D (`puzzles/binairo3d.gd`)

Replaces `puzzles/binairo.gd`. Same generator, same rules text, same share
glyphs, same tap-cycle. Rule feedback (`_recheck`, `_line_bad`) moves into
`binairo_gen.gd` as `static func bad_lines(grid) -> Dictionary` with `rows`
and `cols` keys, so the board holds no rule logic and the existing generator
suite can cover it.

Scene contents, built in `build`:

- One `tile` per cell at `cell_center(r, c)`, tinted `SURFACE_HI` for givens.
  Tiles in a broken row or column swap to the `BAD_TILE` material. Four
  materials cover every combination, all served from the toon cache.
- One `token_circle` and one `token_square` per cell, sitting on the tile top,
  visibility toggled by cell state. Placing a token runs a 0.18 second pop
  (superseded by the trilon roll in Amendment B)
  tween (scale 0 to 1, back ease). Removal hides immediately.
- One `given_ring` per given cell, resting on the tile.

Input: `on_board_press(hit)` maps to a cell with `world_to_cell`, ignores
givens, cycles empty to circle to square to empty, re-tints, and calls
`note_move()`, exactly the 2D flow. Input is refused once `is_done()`.

The registry entry for `binairo` points at `puzzles/binairo3d.gd`. The 2D
file is deleted; git keeps it.

## 5. Cozy palette and 2D chrome

`core/palette.gd` is replaced. The nine unconverted boards read these same
constants, so they shift to the warm scheme without edits.

| name | hex | use |
|---|---|---|
| `BG` / `PAPER` | `f6efe3` | paper card behind 2D boards, menu panel |
| `SURFACE` | `fffdf8` | tile face |
| `SURFACE_HI` | `f1e6d2` | given tile |
| `LINE` | `b8a892` | grid lines, pipes off |
| `TEXT` | `3b3028` | primary text |
| `TEXT_DIM` | `8a7b6b` | secondary text |
| `ACCENT` | `4c9a94` | teal, primary token |
| `ACCENT_2` | `e2825f` | terracotta, secondary token |
| `GOOD` | `7cb06b` | sage |
| `BAD` | `d9605a` | rose |
| `BAD_TILE` | `f2cfc9` | tile tint on a broken line |
| `WOOD` | `c8a17a` | table |
| `OUTLINE` | `3b2f28` | hull outline |
| `SHADOW_TINT` | `b7a6c4` | toon shadow tint |
| `SKY_TOP` | `f9f2e7` | sky gradient top |
| `SKY_HORIZON` | `f3d9c4` | sky gradient horizon |

`CAT` stays eight entries, warm-shifted, in the same order so existing boards
keep their colour-to-index meaning: teal, terracotta, sage, lavender, rose,
sky blue, mustard, stone.

Chrome changes in `ui/puzzle_host.gd` and `ui/menu.gd`:

- Opaque background rects removed.
- Host draws a `PAPER` card with rounded corners behind the board slot only
  when the puzzle reports `is_3d()` false, so 2D boards keep contrast.
- A code-built `Theme` (`ui/theme.gd`) gives buttons rounded paper cards with
  ink text and labels the ink colour, set on the menu so the host inherits it.
- Solved overlay becomes `PAPER` at 85 percent alpha with `TEXT` ink (sage on
  paper is too light for body text).
- Menu list sits on a `PAPER` panel at 90 percent alpha.

## 6. Project settings and tests

### `project.godot`

- `renderer/rendering_method="gl_compatibility"` for desktop as well as
  mobile.
- `anti_aliasing/quality/msaa_3d=1` (2x) for clean outline edges.
- `environment/defaults/default_clear_color` set to `SKY_TOP`.
- `run/main_scene="res://world/main.tscn"`.

### Unit tests (headless, added to `run_tests.gd`)

- `test_board_math.gd`: ray-plane hit and miss cases, `world_to_cell` at cell
  edges and outside the board, `cell_center` round-trips through
  `world_to_cell`, AABB encloses every cell centre.
- `test_toon.gd`: `material()` returns a `ShaderMaterial` with the requested
  albedo; the same colour returns the same instance; `apply_to` converts a
  `StandardMaterial3D` surface to toon with its albedo preserved, adds one
  `Outline` shell with shadow casting off, honours the `_flat` suffix by
  adding no shell, and leaves `ShaderMaterial` surfaces untouched; calling
  `apply_to` twice adds no second shell.
- `test_models.gd`: an unknown slot falls back to a placeholder; every slot in
  `SLOTS` yields a `Node3D`; every placeholder except `table` has an AABB
  inside a 1 by 1 footprint with its base at y = 0.
- `test_palette.gd`: `TEXT` on `PAPER` and `TEXT_DIM` on `PAPER` meet WCAG
  contrast 4.5 and 3.0 respectively; `CAT` still has eight entries.
- `test_binairo.gd` gains cases for `bad_lines`.

### End-to-end harnesses

- `_win.gd`, `_shot.gd`, `_tap.gd` instantiate `world/main.tscn` and locate
  the menu under `UI`.
- The Binairo solver taps `_puzzle.cell_to_local(r, c)` instead of computing
  from origin and cell size. It also asserts every cell projects inside the
  board slot rect, which is the camera fit check.
- Everything else in the win suite is unchanged and must stay 10 of 10.

### Visual check

`_shot.gd` output for Binairo and the menu is inspected by eye after the
build: toon bands visible on tokens, outlines present, tinted shadows, board
fully inside the slot, HUD readable over the diorama.

## Files

New:

```
world/main.tscn            main scene: stage + UI layer
world/stage.tscn           camera rig, sun, environment, table, anchor
world/stage.gd
world/camera_rig.gd
shaders/toon.gdshader
shaders/outline.gdshader
core/toon.gd
core/models.gd
core/placeholders.gd
core/board_math.gd
core/puzzle_base_3d.gd
ui/theme.gd
puzzles/binairo3d.gd
assets/models/README.md    points to the contract; .glb files land here
docs/art/blender-contract.md
tools/blender_export.py
tests/test_board_math.gd
tests/test_toon.gd
tests/test_models.gd
tests/test_palette.gd
.gitattributes
```

Changed: `project.godot`, `core/palette.gd`, `ui/menu.gd`, `ui/puzzle_host.gd`,
`ui/registry.gd`, `puzzles/binairo_gen.gd`, `tests/run_tests.gd`,
`tests/test_binairo.gd`, `tests/_win.gd`, `tests/_shot.gd`, `tests/_tap.gd`,
`README.md`, `.gitignore`.

Deleted: `puzzles/binairo.gd` and its `.uid`.

## Risks

- Camera fit under `canvas_items` stretch: control rects are in design pixels
  while `unproject_position` returns viewport pixels. Both sides go through
  `get_global_transform_with_canvas`, which is the same conversion the
  existing tap harness already relies on.
- Compatibility renderer shader quirks: the toon `light()` function uses
  only `NORMAL`, `LIGHT`, `ATTENUATION`, `LIGHT_COLOR`, `ALBEDO`,
  `DIFFUSE_LIGHT`, all supported there. The screenshot harness runs on the
  same renderer, so a break shows up locally.
- Blender 5.1 exporter option names: the export script is written against
  the `export_scene.gltf` operator and verified by running it once against a
  cube from the command line before the pass is called done.

## Amendment A: island concept (2026-09-13, after Task 4)

The user supplied a concept image, kept at `docs/art/concept-binairo-island.png`:
a Binairo board of chunky cream stone tiles on a mossy stone platform that
floats over blue water among small cliffs and trees, seen almost top-down with
mild perspective. Sun cells are cream tiles with an orange sun emblem; moon
cells are dark slate tiles with an ivory crescent; empty cells carry a small
diamond mark. Givens are not visually distinct in the concept; the game keeps
a slightly darker tile for them so locked cells stay discoverable.

This amendment supersedes the earlier sections where they disagree. Tasks
already complete (1 to 4) are patched by a delta task rather than redone.

### Camera (replaces the pitch and FOV in section 1)

Pitch 68 degrees below horizontal, vertical FOV 30 degrees. The fit routine is
unchanged. `PuzzleBase3D` gains `board_margin() -> float` (default 0) and
`board_aabb()` grows the XZ extent by that margin and extends downward by the
platform depth, so the platform is framed with the tiles.

### Slots (replaces the slot table in section 2 and the contract table in section 3)

| slot | placeholder | size (x, y, z) | colour | outline | footprint rule |
|---|---|---|---|---|---|
| `tile` | 4-sided prism, 45 degrees | 0.94, 0.14, 0.94 | `STONE` | yes | inside 1 x 1, under 0.6 |
| `emblem_sun` | CylinderMesh 32 | r 0.22, h 0.05 | `SUN` | yes | inside 1 x 1, under 0.6 |
| `emblem_moon` | CylinderMesh 32 | r 0.18, h 0.05 | `MOON` | yes | inside 1 x 1, under 0.6 |
| `empty_mark` | 4-sided prism, not rotated (a diamond) | 0.14, 0.03, 0.14 | `MARK` | no | inside 1 x 1, under 0.6 |
| `platform` | BoxMesh | 1, 0.6, 1 | `ROCK` | no | unit slab; the board scales it to (cols + 1, 1, rows + 1) |
| `water` | PlaneMesh | 60 x 60 | `WATER` | no | unbounded; flat at y = 0 |

The `tile` row is superseded by the trilon in Amendment B.

`token_circle`, `token_square`, `given_ring` and `table` are removed. Emblems
sit on the tile top. The Blender contract exempts `platform` and `water` from
the footprint rule and notes that `platform` is a 1 x 1 slab stretched by the
board, so its material should be a plain colour (moss trim can come later as
per-size models).

### Palette additions (section 5)

| name | hex | use |
|---|---|---|
| `STONE` | `ede2cc` | tile face, sun and empty cells |
| `STONE_GIVEN` | `dccfb3` | locked sun tile |
| `SLATE` | `3f4652` | moon tile |
| `SLATE_GIVEN` | `2f353e` | locked moon tile |
| `SUN` | `f5a623` | sun emblem |
| `MOON` | `f6f1e6` | crescent emblem |
| `MARK` | `cbbd9f` | empty-cell diamond |
| `MOSS` | `7fa84a` | reserved for platform trim models |
| `ROCK` | `b9ab92` | platform stone |
| `WATER` | `2f8fd6` | water plane |

`SKY_TOP` becomes `bfe3f5` (light blue) and `SKY_HORIZON` becomes `e8f2f7`,
so the world reads as island daylight while the UI keeps its paper and ink.
`WOOD` stays defined for the palette test but nothing uses it.

### Stage (section 1)

No table. The stage holds the camera rig, sun, sky, and a `water` plane at
y = -4. Boards bring their own `platform`.

### Binairo (section 4)

Per cell: one `tile`, one `emblem_sun`, one `emblem_moon`, one `empty_mark`,
visibility driven by cell state. Tile tint: empty or sun on `STONE`
(`STONE_GIVEN` when locked), moon on `SLATE` (`SLATE_GIVEN` when locked); a
cell in a broken line lerps 35 percent toward `BAD`. One `platform` under the
board, top at y = 0, scaled to (n + 1, 1, n + 1). Placing an emblem pops it
in over 0.18 s (superseded by the trilon roll in Amendment B). Share glyphs are
🌞 for sun and 🌙 for moon.
`board_margin()` returns 0.5.

### Verification note

The earlier acceptance check "cream sky visible behind the menu" was
ambiguous: a cream sky behind a 90 percent cream panel is indistinguishable
from an opaque panel. With blue sky and water the check is unambiguous.

### Tuned constants (as built)

The numbers that were settled by looking at the screen rather than derived, so
a later change has something to compare against.

- Toon ramp: three constant bands at offsets 0 / 0.42 / 0.70 with values 0 /
  0.55 / 1.0 (`core/toon.gd`).
- Sun energy 0.46 and ambient energy 0.115, calibrated against a lit `STONE`
  tile face reading within 12 percent of `ede2cc` (`world/stage.gd`).
- Menu paper panel alpha 0.82 (`ui/menu.gd`); host header panel alpha 0.88
  (`ui/puzzle_host.gd`).
- Outline width 0.02 world units at `distance_scale` 0 (`shaders/outline.gdshader`).
- Camera pitch 68 degrees, FOV 30 degrees (`world/camera_rig.gd`).

## Amendment B: island pieces and the trilon roll (2026-09-13, after Task 9)

The first pass at the concept used primitive stand-ins. This pass fills the
slots with real models and adds the interaction the user asked for: a tapped
cell rotates to reveal its new figure. Scenery beyond the platform (cliff
rock, water foam, islets, trees, house) is still to come as Amendment C.

### Models (sections 2 and 3)

All Binairo pieces are generated by `tools/build_pieces.py` in headless
Blender and exported through `tools/blender_export.py`; `tools/build_models.sh`
runs both and re-imports. The script is the source of truth, `art/pieces.blend`
is a git-ignored by-product. Recipe for every piece: a flat outline extruded to
height, every edge bevelled (smooth, shared vertices, no hardened normals),
then each flat face inset by a hair so the bevel's tilted normals stay in a
thin band and the face reads as one toon tone.

| slot | shape | size | materials |
|---|---|---|---|
| `tile` | trilon: equilateral three-sided prism along X, side 0.84, length 0.94, flat face up, bevel 0.035 x 2 | 0.94 x 0.84 x 0.73 | `Face_Empty`, `Face_Sun`, `Face_Moon`, `Cap`; coloured by name |
| `emblem_sun` | disc r 0.16 plus 8 tapered rays to r 0.29 | inside 0.56, h 0.05 | `Sun` |
| `emblem_moon` | crescent: disc r 0.215 minus disc r 0.19 offset (0.105, 0.07), horns to the upper right | inside 0.43, h 0.05 | `Moon` |
| `empty_mark` | diamond, half 0.07 | 0.13 x 0.13 x 0.03 | `Mark_flat` |
| `rim_edge` (new) | moss slab 1 x 0.5 x 0.03 with 4 grass mounds and a flower | h 0.10 | `Moss_flat`, `Grass_flat`, `Petal_flat`, `Pollen_flat` |
| `rim_corner` (new) | moss slab 0.5 x 0.5 x 0.03 with 2 mounds and a flower | h 0.11 | same |

Rim materials are lighter than the moss (`Grass_flat` `a3c95e`) so mounds
read as highlights; they are not palette entries because the toon step reads
colours from the glTF material, not from `palette.gd`.

### Platform (section 4)

`core/platform.gd` builds the platform for any board: the stretched
`platform` slab as before, plus a ring of rim pieces resting on its lip at
y = 0: one `rim_edge` per cell along each side (turned so its outward side,
Godot +Z in the model and Blender -Y when authored, faces the water; every
second one mirrored along its length for variety) and a `rim_corner` at each
corner. `Platform.LIP` is 0.5, one rim piece deep;
`board_margin()` returns it. Binairo no longer lays its own slab.

### Trilon roll (section 4)

The user asked for the piece to be "a triangle with 3 faces": each Binairo
cell is a trilon, an equilateral three-sided stone prism lying along X on a
pivot through its axis, with one face per state. At rest the empty face (with
the diamond) is up and stands `TILE_RISE` (0.12) above the platform; the sun
face waits on the near slope and the moon face on the far slope, both inside
the platform, where its top surface hides them. Each emblem stands on the
centre of its own face, one apothem (`TILE_APOTHEM`, side * sqrt(3) / 6) from
the axis and pointing along the face normal, so nothing is ever toggled:
the pivot's angle alone says which face is up.

A tap changes the grid at once and rolls the pivot a third of a turn about X
toward the player over 0.3 s (cubic ease out), the old face going over the
far side and the new one rising from the near side. The turn count only ever
grows, so empty -> sun -> moon -> empty is one full turn, never an unwind. A
tap on a cell mid-roll snaps that roll home first. Reset snaps every cell.
Face colours are set by material name: stone (`STONE`, `STONE_GIVEN` when
locked) on the empty and sun faces and the caps, slate on the moon face,
all blushed toward `BAD` on a broken line. The card flip and `core/flip.gd`
from the first cut of this amendment are gone.

Geometry that keeps the roll clean: the flat face is 0.84 wide and the
prism narrows toward its apex, so at the platform surface, 0.12 below the
face, each cell is 0.70 wide and neighbours never touch. The axis sits one
apothem (0.2425) below the face, 0.1225 below the platform top. A rolling
prism's edges sweep two apothems (0.485) from the axis: they rise 0.36 above
the platform at most, which `board_height()` frames, and stay about 0.14
clear of a resting neighbour's nearest edge, 0.63 away. The pivot height
comes from the design constants, not the mesh: bevelling shaves the prism's
bounds but never moves its faces.

Draw calls: a trilon with three emblems is about 20 draws per cell on the
compatibility renderer once outlines and shadows are counted, so the two
emblems buried in the platform are made invisible between rolls (all three
show while a roll is in motion). Measure an 8 x 8 board on a phone before
shipping; if it is still heavy, the next step is a two-material tile, since
the empty face, sun face and caps always share a colour today.

### Test runner (section 6)

Suites that need a live tree (a `PuzzleBase3D` mounting in `_ready`, a
node-bound tween) define `run_in_tree(t)`, which the runner calls on the
first process frame; `run(t)` still executes during `_initialize`, before the
root enters the tree. The runner also skips a suite that fails to parse
instead of calling into it, which used to hang the run.
