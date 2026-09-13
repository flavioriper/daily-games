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
- `flat(albedo: Color) -> ShaderMaterial`: unshaded matte. For the table top
  and anything whose Blender material name ends in `_flat`.
- `outline() -> ShaderMaterial`: the one shared outline material.
- `add_outline(mesh_instance: MeshInstance3D)`: adds the `Outline` shell
  child described above. Idempotent: a second call finds the existing shell.
- `apply_to(root: Node)`: walks `MeshInstance3D` descendants. For each surface
  whose material is a `StandardMaterial3D`, sets a surface override to
  `material(albedo_color)`, or `flat(albedo_color)` when the source material
  name ends in `_flat`. A mesh gets an outline shell unless every surface is
  flat. Materials that are already `ShaderMaterial` are left alone. This is
  how a plain Blender export becomes toon at load time with no editor import
  configuration.

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
  | `table` | BoxMesh | 14, 0.4, 14 | `WOOD`, flat |

  Every placeholder has its origin at the centre of its base so it sits on
  y = 0 of whatever it is placed on, the same rule the contract gives to
  Blender models.

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
  Name a material with the suffix `_flat` to get an unshaded matte with no
  outline instead.
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
  when the puzzle is not a `PuzzleBase3D`, so 2D boards keep contrast.
- Solved overlay becomes `PAPER` at 85 percent alpha with `GOOD` text.
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
  using the flat material and adding no shell, and leaves `ShaderMaterial`
  surfaces untouched; calling `apply_to` twice adds no second shell.
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
