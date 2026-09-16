# Low-Horizon Landscape Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drop the board camera to 7 degrees so the painted lake landscape's horizon, hills and clouds are in frame, lean every board toward the camera so no piece has to be re-cut, and set the water, grass and clouds moving.

**Architecture:** `Stage` stops setting the camera's pitch from the board and starts setting the board anchor's *lean* from it, keeping each board's face angle exactly as it is today. Picking moves into board-local space, the one thing a lean breaks outright. The landscape gains a far hills ring, a procedural cloud bank and three cloud cards beyond the existing meadow, and `shaders/water.gdshader` is rewritten as a port of the source lake's 42-node material.

**Tech Stack:** Godot 4.7 (Compatibility renderer, GDScript), Blender 5.1.2 driven through the Blender MCP, glTF export through `tools/blender_export.py`.

**Spec:** `docs/superpowers/specs/2026-09-16-low-horizon-design.md`

## Global Constraints

- **No new tests.** This is MVP-stage work: the checks are throwaway harness
  runs and rendered frames, not new suite entries. The existing suite must
  keep passing with no new failures.
- **Suite command:** `godot --headless --path . --script tests/run_tests.gd`
  — currently 2055 passing, 0 failures.
- **Board frames:** `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd`
  writes `/tmp/shot_<id>.png` for all twelve boards plus the menu. Must run
  **windowed** — headless saves blank frames.
- **Win harness:** `tests/_win.gd` must stay 10/10 and must be run windowed; it
  silently reports 0/0 headless.
- **Budget:** at most **855** draw calls at rest, idle mean frame time at most
  **8 ms** at 1080x1920.
- **Draw-call arithmetic:** an outlined layer costs 3 passes. The landscape is
  not outlined, so each landscape mesh is 1.
- **Blender rules** (`docs/art/blender-contract.md` and CLAUDE.md): one mesh per
  layer, one material per mesh; the `.blend` is the source and is never
  rebuilt by a script; export only through
  `Blender -b art/<file>.blend --python tools/blender_export.py -- <Collections>`
  then `godot --headless --path . --import`.
- **The landscape is the contract's exception on materials:** its colour is
  painted into its textures and `world/backdrop.gd` loads its `.glb` files
  directly rather than through `core/models.gd`, because `Toon.apply_to()`
  would replace the imported material and throw the painted texture away.
  Keep the painted textures; do not convert the landscape to toon materials.
- **Blender base colours are linear.** Convert palette hex to linear when
  scripting a Base Color, or exports come out washed out.
- **The Blender MCP keeps no Python state.** Redefine every helper in every
  `execute_blender_code` snippet.
- **Shading direction** (`docs/art/shading-direction.md`): soft painted cel,
  warm muted pastels, minimal specular, depth through colour rather than fog.
  Distant hills wash toward `Pal.SKY_HORIZON`, they do not fog.
- **Never name the studio** the look is inspired by, in code, comments, docs or
  commit messages.
- **Godot re-saves `project.godot`** with a header comment after a windowed
  run. Revert that hunk before committing.
- **In a `SceneTree` script, `_ready` is deferred:** run probe assertions from
  `_process`, not `_initialize`.
- Commit messages follow the repo's style: a `type(scope): subject` line, then
  prose paragraphs explaining why, with measured numbers. No attribution
  footer.

---

### Task 1: Export the far hills ring

The appended scene's terrain is a 200x200 sculpted plane. Its middle is
already in the game as `meadow.glb`; this task takes its outer roll — the part
that makes a silhouette against the sky — as a separate slot, and re-enables
the cloud card that has been exported-but-unused since yesterday.

**Files:**
- Modify: `art/landscape.blend` (the live Blender session; save at the end)
- Modify: `tools/build_models.sh:80-87`
- Produces: `assets/models/hills.glb`, and `assets/models/cloud.glb` built again

**Interfaces:**
- Consumes: nothing.
- Produces: slot `hills` — one mesh named `Hills`, one material carrying
  `test_1.jpg`, centred on X and Z, its lowest point at Z 0, spanning roughly
  200 units across. Slot `cloud` — one alpha card carrying `cloud.png`. Both
  read by `world/backdrop.gd` in Task 6.

- [ ] **Step 1: Confirm what is in the file before touching it**

The imported scene is `Stylized Anime Lake Landscape Scene`; the game's own
scene is `Scene`. Run in `execute_blender_code`:

```python
import bpy
print("scenes:", [s.name for s in bpy.data.scenes])
sc = bpy.data.scenes["Stylized Anime Lake Landscape Scene"]
p = sc.objects["Plane"]
print("terrain dims:", [round(v, 2) for v in p.dimensions])
print("modifiers:", [(m.type, m.name) for m in p.modifiers])
print("psys:", [ps.name for ps in p.particle_systems])
print("verts:", len(p.data.vertices), "polys:", len(p.data.polygons))
```

Expected: the terrain is 200 x 200 x 13.01, carries a `NODES` modifier and
three hair particle systems, and has 16641 verts / 16384 polys.

- [ ] **Step 2: Duplicate the terrain and strip it to a plain mesh**

The hair systems are 500 000 strands and the geometry-nodes modifier is the
scatter; neither survives a glTF export or belongs in an APK. Work on a copy
so the imported scene stays intact as the source:

```python
import bpy
sc = bpy.data.scenes["Stylized Anime Lake Landscape Scene"]
bpy.context.window.scene = sc
src = sc.objects["Plane"]
for o in sc.objects:
    o.select_set(False)
src.select_set(True)
bpy.context.view_layer.objects.active = src
bpy.ops.object.duplicate()
hills = bpy.context.active_object
hills.name = "Hills"
hills.data.name = "Hills"
for m in list(hills.modifiers):
    hills.modifiers.remove(m)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
print("hills:", hills.name, "mods:", len(hills.modifiers),
      "psys:", len(hills.particle_systems),
      "verts:", len(hills.data.vertices))
```

Expected: `mods: 0`, `psys: 0`, 16641 verts.

- [ ] **Step 3: Cut the middle out, leaving a ring**

`meadow.glb` covers the middle. Delete the faces inside the radius the meadow
occupies so the two do not z-fight, and so the ring is cheap. The meadow is
21.6 x 15.4 modelled and `Backdrop.SPREAD` stretches it 2.4x, so it covers
about 52 x 37 world units; cut a 30-unit radius in the terrain's own
coordinates, which the export then scales with the rest.

```python
import bpy, bmesh
hills = bpy.data.objects["Hills"]
me = hills.data
bm = bmesh.new()
bm.from_mesh(me)
inner = 30.0
doomed = [f for f in bm.faces if f.calc_center_median().xy.length < inner]
bmesh.ops.delete(bm, geom=doomed, context="FACES")
bm.to_mesh(me)
bm.free()
me.update()
print("faces left:", len(me.polygons))
```

Expected: fewer than 16384 faces, and more than zero. Record the number.

- [ ] **Step 4: Give it one material and stand it on Z 0**

One mesh, one material, per the contract. Keep the painted texture — this is
the landscape exception.

```python
import bpy
from mathutils import Vector
hills = bpy.data.objects["Hills"]
hills.data.materials.clear()
hills.data.materials.append(bpy.data.materials["Material.001"])
zs = [(hills.matrix_world @ v.co).z for v in hills.data.vertices]
xs = [(hills.matrix_world @ v.co).x for v in hills.data.vertices]
ys = [(hills.matrix_world @ v.co).y for v in hills.data.vertices]
hills.location -= Vector(((min(xs) + max(xs)) / 2.0,
                          (min(ys) + max(ys)) / 2.0, min(zs)))
bpy.ops.object.select_all(action="DESELECT")
hills.select_set(True)
bpy.context.view_layer.objects.active = hills
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
print("materials:", [m.name for m in hills.data.materials])
print("z range:", round(min((v.co.z for v in hills.data.vertices)), 3),
      round(max((v.co.z for v in hills.data.vertices)), 3))
```

Expected: one material, `Material.001`, and a Z range starting at 0.0.

- [ ] **Step 5: Put it in its own collection named for the slot**

`tools/blender_export.py` takes collection names and writes one `.glb` per
collection, so the collection is the slot.

```python
import bpy
hills = bpy.data.objects["Hills"]
col = bpy.data.collections.get("Hills")
if col is None:
    col = bpy.data.collections.new("Hills")
    bpy.context.scene.collection.children.link(col)
for c in list(hills.users_collection):
    c.objects.unlink(hills)
col.objects.link(hills)
print("collection:", col.name, "objects:", [o.name for o in col.objects])
```

Expected: `collection: Hills objects: ['Hills']`.

- [ ] **Step 6: Save the .blend**

```python
import bpy
bpy.ops.wm.save_mainfile()
print("saved:", bpy.data.filepath, "dirty:", bpy.data.is_dirty)
```

Expected: `dirty: False`. The file is tracked, so this is the source of the
export from here on.

- [ ] **Step 7: Add both slots to the build script**

In `tools/build_models.sh`, replace the comment block at lines 80-87 that says
`Cloud` is deliberately not exported. The pitch has now dropped, which is the
condition that comment names.

```sh
# The backdrop the whole game sits in: a painted landscape. The meadow is two
# meshes -- the rolling ground, with a basin sculpted in it for the pond, and
# 4626 blades of grass baked down from the original hair particles -- and the
# tree clumps and blossom are painted alpha cards the stage billboards. `Hills`
# is the outer roll of the source scene's 200-unit terrain with its middle cut
# out, the silhouette the sky sits behind; `Cloud` is the painted cloud card.
# Both are in frame for the first time now that the camera is pitched at 7
# degrees rather than 68 (world/stage.gd, and the low-horizon spec). None of it
# obeys the cell footprint rules, so the slots are UNBOUNDED in
# blender_export.py.
"$BLENDER" -b art/landscape.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Meadow Foliage Blossom Hills Cloud
```

- [ ] **Step 8: Check `hills` and `cloud` are UNBOUNDED in the exporter**

Run: `grep -n "UNBOUNDED\|Meadow\|meadow\|cloud\|hills" tools/blender_export.py`

If the exporter keys its footprint rules off a slot list, add `hills` and
`cloud` beside `meadow` exactly as `meadow` appears. If `meadow` is not listed
by name, nothing needs adding.

- [ ] **Step 9: Export and import**

Run: `tools/build_models.sh`
Expected: exits 0, and the final `ls` lists `assets/models/hills.glb` and
`assets/models/cloud.glb`. If the contract check rejects `Hills`, read the
message — it names the rule — and fix the mesh in the live session, never by
editing the exporter.

- [ ] **Step 10: Commit**

```bash
git add art/landscape.blend tools/build_models.sh assets/models/hills.glb \
  assets/models/hills.glb.import assets/models/cloud.glb assets/models/cloud.glb.import
git commit -m "feat(art): the landscape gains the hills ring and its cloud card

The source scene the meadow was cut from is appended into
art/landscape.blend as its own scene, and its 200-unit terrain has an
outer roll the meadow does not cover. Hills is that roll with a
30-unit radius cut out of its middle, so it meets the meadow behind a
rise instead of z-fighting with it, stripped of the geometry-nodes
scatter and the three hair systems that made it 500000 strands.

Cloud has been exported-but-unbuilt since the landscape landed, on the
grounds that a 68 degree pitch never has sky in frame. The pitch is
about to become 7."
```

---

### Task 2: The camera drops and the board leans

**Files:**
- Modify: `world/stage.gd:13-20` (constants), `world/stage.gd:111-135` (`fit_camera`, `_fit_ground`, `turn`)
- Modify: `world/camera_rig.gd:14` (`fov_deg` default)
- Modify: `tests/_shot_model.gd:33-40`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `Stage.CAMERA_PITCH: float = 7.0`, `Stage.DEFAULT_FACE: float = 68.0`,
  `Stage._lean(face: float) -> void`, and `Stage.fit_camera(aabb, rect, face := NAN, projection := ..., yaw := NAN)`
  where `aabb` is **board-local** and the stage transforms it. Task 3 relies on
  `Stage.anchor` carrying a non-identity basis.

- [ ] **Step 1: Replace `DEFAULT_PITCH` with the two new constants**

In `world/stage.gd`, replace the `DEFAULT_PITCH` const and its comment:

```gdscript
## The camera's own pitch, in degrees above the horizontal, and the only one
## any board gets. The frame spans pitch - fov/2 to pitch + fov/2 below the
## horizontal, so the horizon sits about 0.5 - pitch/fov down it: at 7 against
## the rig's 40 degree field, a third of the way down. Distance cannot move it
## -- CameraRig.fit only slides along the view direction -- which is why Pipes
## at 35 degrees still showed nothing but meadow to every edge.
const CAMERA_PITCH := 7.0
## The angle a board's face is seen at unless it asks for another. The board
## leans to meet the camera rather than the camera moving to meet the board,
## which is what keeps every piece in core/placeholders.gd readable: the face
## angle here is the pitch the pieces were cut for.
const DEFAULT_FACE := 68.0
```

- [ ] **Step 2: Widen the field of view**

In `world/camera_rig.gd`, change line 14 and document why:

```gdscript
## Wide enough that a 7-degree pitch leaves sky above the horizon: the frame
## spans pitch +/- fov/2, so at 30 degrees the horizon sat exactly on the top
## edge and no sky showed at all.
@export var fov_deg: float = 40.0
```

- [ ] **Step 3: Add the lean, and remember the face angle**

In `world/stage.gd`, add beside the other vars:

```gdscript
## The face angle the last fit used, so a turn can re-lean where it lands.
var _face := DEFAULT_FACE
```

and add the function:

```gdscript
## Leans the board anchor toward the camera until the board's face is seen at
## `face` degrees above the horizontal. The axis is the camera's own right, so
## the board keeps facing the player at all four yaw stops rather than leaning
## off to one side at three of them; rotating that way raises the board's far
## edge, which is what brings its face around to the camera.
func _lean(face: float) -> void:
	_face = face
	var right := Vector3.UP.cross(rig.view_offset_dir())
	if right.length_squared() < 1e-6:
		right = Vector3.RIGHT
	anchor.transform.basis = Basis(right.normalized(), deg_to_rad(face - CAMERA_PITCH))
```

- [ ] **Step 4: Rewrite `fit_camera` to lean the board instead of pitching the camera**

Replace the body of `fit_camera` and re-word its doc comment. The parameter is
renamed `face` because that is what its three overriding numbers now mean:

```gdscript
## Frames `aabb` -- the board's own, board-local box -- in `rect`. `face` is
## the angle the board's face wants to be seen at, in degrees above the
## horizontal; NAN means the island's own. The camera no longer moves to find
## that angle: it stays at CAMERA_PITCH so the landscape reads the same behind
## every board, and the board leans to meet it. A board whose pieces mean
## something by their height asks for a shallower face and leans less --
## Balance, whose beams tilt and whose discs stack. `projection` is the same
## story for perspective against parallel: Pipes wants its blocks parallel,
## every other board wants depth. `yaw` is the exception -- NAN leaves the
## rig's own yaw where it is, which is what a board that turns needs, or every
## re-fit would undo the turn.
func fit_camera(aabb: AABB, rect: Rect2, face := NAN, projection := Camera3D.PROJECTION_PERSPECTIVE, yaw := NAN) -> void:
	rig.orthographic = projection == Camera3D.PROJECTION_ORTHOGONAL
	rig.pitch_deg = CAMERA_PITCH
	if not is_nan(yaw):
		rig.yaw_deg = yaw
	# Before the box is measured: the lean is what puts the board where the
	# rig has to frame it.
	_lean(DEFAULT_FACE if is_nan(face) else face)
	var world := anchor.transform * aabb
	rig.fit(world, rect)
	ambient.fit_to(world)
	_fit_ground(world)
```

- [ ] **Step 5: Re-lean after a turn**

`CameraRig.turn` re-fits from its own callback, which does not go through
`fit_camera`, so the lean would be left on the yaw the turn started from.
Replace `Stage.turn`:

```gdscript
## Swings the view a quarter turn per step, so a board asks the stage rather
## than reaching into the rig. The lean is measured from the camera's right,
## so it has to be re-taken where the turn lands. Returns the tween, or null
## off-tree.
func turn(steps: int) -> Tween:
	var tw := rig.turn(steps)
	if tw != null:
		tw.tween_callback(func() -> void: _lean(_face))
	return tw
```

- [ ] **Step 6: Keep the model previewer upright at eye level**

`tests/_shot_model.gd` mounts a bare model in the anchor and wants its own
pitch. Both now fight `fit_camera`. Change the two branches at lines 33-40 to
bypass it:

```gdscript
	if _frames == 2:
		_model = Models.instance(_slot)
		_stage.mount(_model)
		_stage.rig.pitch_deg = PITCH
		# A model is not a board: it should stand up, not lean, so the stage's
		# lean is undone and the rig is fitted directly rather than through
		# Stage.fit_camera, which would re-pitch and re-lean.
		_stage.anchor.transform.basis = Basis()
	elif _frames == 5:
		var box := AABB(_model.position, Vector3.ZERO)
		for mi in Models.meshes(_model):
			box = box.merge(mi.transform * mi.mesh.get_aabb())
		_stage.rig.fit(box, root.get_visible_rect())
```

- [ ] **Step 7: Run the suite**

Run: `godot --headless --path . --script tests/run_tests.gd | tail -5`
Expected: 0 failures. The count may move if a suite asserts the old pitch; if
one fails, read it — a test asserting `DEFAULT_PITCH` is asserting the thing
this task changes, and its expectation is updated, not its subject.

- [ ] **Step 8: Commit**

```bash
git add world/stage.gd world/camera_rig.gd tests/_shot_model.gd
git commit -m "feat(world): the camera drops to the horizon and the board leans to meet it

The frame spans pitch +/- fov/2 below the horizontal, so the horizon
sits about 0.5 - pitch/fov down it and no amount of fitting can move
it: CameraRig.fit only slides the camera along the view direction. At
68 degrees and a 30 degree field that put the horizon at -1.27, far
off the top of the screen. At 7 and 40 it sits a third of the way
down, which is the first time this game has had a sky.

A grid lying flat under a 7 degree camera keeps a quarter of its
depth, so the board leans instead. The lean is board_face minus
CAMERA_PITCH about the camera's own right axis, which preserves every
board's face angle exactly -- 68 by default, and the 72, 44 and 35
that Horse Pen, Balance and Pipes already asked for -- so not one
piece in core/placeholders.gd has to be re-cut and the board's screen
footprint stays roughly square instead of squashing.

board_pitch() keeps its name and its numbers, re-read as the angle the
face is seen at rather than the angle the camera is held at, which is
what it always meant to a board."
```

---

### Task 3: Picking in board-local space

This is the one thing a lean breaks outright rather than merely making ugly:
`local_to_board` intersects the camera ray with a *world-horizontal* plane.

**Files:**
- Modify: `core/puzzle_base_3d.gd:88-115` (`local_to_board`, `local_ray`, `board_to_local`)

**Interfaces:**
- Consumes: `Stage.anchor` carrying a lean (Task 2).
- Produces: `local_to_board`, `local_ray` and `board_to_local` unchanged in
  signature. All fifteen callers in `puzzles/` keep passing and receiving
  board-local points and need no edit.

- [ ] **Step 1: Take the ray into the board's own space**

Replace `local_to_board`:

```gdscript
## Board-plane point under a control-local position, or null when the ray
## misses. The board leans (see Stage._lean), so the plane at plane_height()
## is horizontal in the *board's* space and nowhere else: the ray is taken
## into that space before it is intersected. Boards already read the hit as
## board-local -- it only happened to equal world while the anchor sat
## untransformed at the origin.
func local_to_board(local: Vector2) -> Variant:
	var cam := _camera()
	if cam == null:
		return null
	var vp := get_global_transform_with_canvas() * local
	var inv := board.global_transform.affine_inverse()
	var origin: Vector3 = inv * cam.project_ray_origin(vp)
	var dir: Vector3 = (inv.basis * cam.project_ray_normal(vp)).normalized()
	return BoardMath.ray_plane(origin, dir, plane_height())
```

- [ ] **Step 2: Take the raw ray into the same space**

Replace `local_ray`:

```gdscript
## The picking ray through a control-local position, as
## [origin: Vector3, direction: Vector3] in the *board's* own space, or [] when
## there is no camera. Where local_to_board answers with the one point on the
## board plane, this hands back the ray itself, for a board whose pieces stand
## at many heights and has to march the ray through its own cells to find out
## what was tapped -- and those cells are in board space, so the ray must be
## too.
func local_ray(local: Vector2) -> Array:
	var cam := _camera()
	if cam == null:
		return []
	var vp := get_global_transform_with_canvas() * local
	var inv := board.global_transform.affine_inverse()
	return [inv * cam.project_ray_origin(vp),
		(inv.basis * cam.project_ray_normal(vp)).normalized()]
```

- [ ] **Step 3: Send board points back out through the board's transform**

Replace `board_to_local`:

```gdscript
## Control-local position of a board-space point; the inverse of
## local_to_board. The point goes out through the board's transform before it
## is projected, because the board leans.
func board_to_local(point: Vector3) -> Vector2:
	var cam := _camera()
	if cam == null:
		return Vector2.INF
	var world: Vector3 = board.global_transform * point
	return get_global_transform_with_canvas().affine_inverse() * cam.unproject_position(world)
```

- [ ] **Step 4: Run the suite**

Run: `godot --headless --path . --script tests/run_tests.gd | tail -5`
Expected: 0 failures. `tests/test_board_math.gd` tests `ray_plane` directly and
is untouched by this — it is pure geometry either way.

- [ ] **Step 5: Prove a tap still lands, on a real board**

Run: `godot --path . --resolution 1080x1920 --script res://tests/_tap.gd 2>&1 | tail -20`

Read `tests/_tap.gd` first to learn what it drives and what it prints. If it
takes a board id, run it for `binairo`. Expected: the taps it reports as
landing on cells still land on the same cells they did before this task. If
`_tap.gd` does not cover this, drive one board instead: open Binairo through
`tests/_shot.gd`, then tap the centre of the frame and confirm from the
printed cell that the hit is the cell under the finger, not one several rows
away.

- [ ] **Step 6: Commit**

```bash
git add core/puzzle_base_3d.gd
git commit -m "fix(core): picking follows the board into its own space

The board leans now, and picking intersected a world-horizontal plane
at plane_height(). That plane is horizontal in the board's space and
nowhere else, so every tap on every board landed on a cell that was
not under the finger.

The ray goes into board space before it is intersected and points come
back out through the board's transform. All fifteen callers keep
passing board-local points from BoardMath and are untouched: the hit
was always read as board-local, it only happened to equal world while
the anchor sat untransformed at the origin."
```

---

### Task 4: The framing gate

Nothing else proceeds until the lean is judged on a rendered frame. This task
produces a decision, not code.

**Files:**
- Produces: `/tmp/shot_*.png` for all twelve boards and the menu.

**Interfaces:**
- Consumes: Tasks 2 and 3.
- Produces: a written verdict per board — readable / leaning wrongly / needs a
  shallower face — carried into Task 8.

- [ ] **Step 1: Render every board**

Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd`
Expected: `saved /tmp/shot_<id>.png` thirteen times. Windowed, not headless.

- [ ] **Step 2: Revert the project.godot header Godot re-saved**

Run: `git diff --stat project.godot`
If it is the header comment only: `git checkout -- project.godot`

- [ ] **Step 3: Look at all thirteen frames and write the verdict**

Read each `/tmp/shot_<id>.png`. For each board answer three questions:

1. Is the grid still readable — can you tell the cells apart and see which
   piece sits in which?
2. Does anything look like it is toppling backwards? The pieces at risk are
   Horse Pen's horse, Tents' conifers, Light Up's lanterns and Untangle's
   mooring posts.
3. Is there sky and hills above the board, and does the board sit in the
   landscape rather than floating in front of it?

Write the answers into the plan under this task as a table. This is the gate.

- [ ] **Step 4: Decide whether to go on**

If the grids read and only the standing pieces look wrong, continue: that is
Task 8's job and it is expected.

If the *grids* do not read, stop and report. The spec names the retreat:
island-in-the-sky framing keeps the 68-degree pitch, ends the meadow inside
the frame and stands the hills and clouds beyond its edge, which needs Tasks 5
through 7 and none of 2, 3 or 8.

- [ ] **Step 5: Commit the verdict**

```bash
git add docs/superpowers/plans/2026-09-16-low-horizon.md
git commit -m "docs(art): the framing verdict for all twelve leaning boards"
```

---

### Task 5: Port the lake

`Material.005` in the source scene is 42 nodes and no image textures, so it
ports to GLSL rather than baking to a texture. Four layers, in the order they
stack in the node tree.

**Files:**
- Modify: `shaders/water.gdshader` (rewrite the `fragment()` body; keep the
  uniforms, the `varying`, and `light()`)

**Interfaces:**
- Consumes: nothing.
- Produces: the same uniform names the rest of the game already sets —
  `splash_origin: vec3`, `splash_age: float`, and the `motion_scale` global.
  `world/ambient.gd` sets those two through `Toon.water()` and must keep
  working untouched.

- [ ] **Step 1: Read the source material's numbers out of Blender**

They are already recorded in the spec's section 5, but re-read them so the
port is against the file rather than against prose:

```python
import bpy
nt = bpy.data.materials["Material.005"].node_tree
for n in nt.nodes:
    if n.type == "VALTORGB":
        print(n.name, n.color_ramp.interpolation,
              [(round(e.position, 3), [round(c, 4) for c in e.color])
               for e in n.color_ramp.elements])
    elif n.type in ("TEX_NOISE", "TEX_WAVE", "TEX_MAGIC"):
        print(n.name, n.type,
              {i.name: round(i.default_value, 3) for i in n.inputs
               if not i.is_linked and isinstance(i.default_value, float)})
```

Expected: the depth ramp's four linear stops `(0,1,0.7223)`, `(0,0.4492,1)`,
`(0,0.2765,0.9636)`, `(0,0.12,1)` at 0.15 / 0.359 / 0.673 / 1.0; the magic
field at scale 4.4, distortion 0.5, depth 2; the wave at scale 9, distortion
-1.2; noise at scale 3.3 distortion 7.4 and at scale 1.1 distortion -0.5.

- [ ] **Step 2: Rewrite the shader**

Those four stops are `#00ffdd`, `#00b3ff`, `#008ffb`, `#0061ff` in sRGB — far
more saturated than `docs/art/shading-direction.md` allows. They are muted
toward `Pal.WATER` (`#2f8fd6`) and `Pal.WATER_HI` (`#5fb0e8`) as the defaults
below, and settled on a frame in Step 4.

Replace `shaders/water.gdshader` with:

```glsl
shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// The lake, ported from the painted source scene's 42-node water material
// (art/landscape.blend, Material.005) rather than baked from it: the material
// has no image textures at all, so it is cheaper as maths than as a texture in
// the APK. Four layers, in the order the node tree stacks them -- a depth
// gradient out from the middle, a mottle, the white foam curls that make it
// read as painted rather than shaded, and the long streak dashes. Plus the one
// splash ring the stage triggers when a board lands, which is why the pond has
// to stay a single shared material.
//
// The source's stops are far more saturated than this project's direction
// (docs/art/shading-direction.md), so they are muted toward the palette's
// WATER and WATER_HI. Every time term is scaled by the motion_scale global so
// reduce-motion stills the whole lake. Lit with the same two-band step as the
// toon shader so the platform's shadow still falls on it. Runs on
// gl_compatibility: nothing here reads depth or screen.
// Spec: docs/superpowers/specs/2026-09-16-low-horizon-design.md, section 5.

global uniform float motion_scale;

// The depth gradient, shallow at the shore to deep in the middle.
uniform vec4 shore_color : source_color = vec4(0.42, 0.78, 0.82, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.37, 0.69, 0.91, 1.0);
uniform vec4 base_color : source_color = vec4(0.18, 0.56, 0.84, 1.0);
uniform vec4 deep_color : source_color = vec4(0.13, 0.42, 0.74, 1.0);
// The foam curls and the streak dashes, both near-white.
uniform vec4 foam_color : source_color = vec4(0.96, 0.98, 0.99, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.65, 0.77, 1.0);
// World units from the pond's middle to its rim, for the depth gradient.
uniform float pond_radius = 15.0;
// The source's own field scales, in the source's units.
uniform float mottle_scale = 3.3;
uniform float foam_scale = 4.4;
uniform float streak_scale = 9.0;
uniform vec3 splash_origin = vec3(0.0);
// Seconds since the splash began; negative means no splash. Driven by
// world/ambient.gd from its own clock so the ring is deterministic.
uniform float splash_age = -1.0;

varying vec3 world_pos;

// Value noise, smoothed. Stands in for Blender's Noise Texture: the port needs
// the same broad mottle, not the same bytes.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Blender's Magic Texture is iterated sin of the coordinates fed back into
// themselves; two iterations is its depth of 2. This is where the curls come
// from.
float magic(vec2 p, float distortion) {
	vec3 v = vec3(p, p.x * 0.5 + p.y * 0.5);
	for (int i = 0; i < 2; i++) {
		v = vec3(sin(v.x + v.z * distortion),
			sin(v.y - v.x * distortion),
			sin(v.z + v.y * distortion));
	}
	return (v.x + v.y + v.z) / 3.0 * 0.5 + 0.5;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * motion_scale;
	vec2 p = world_pos.xz;

	// 1. Depth gradient: the source uses a quadratic-sphere gradient in object
	// space, which on a flat disc is the squared distance from the middle.
	float r = clamp(length(p - splash_origin.xz * 0.0) / pond_radius, 0.0, 1.0);
	float depth = 1.0 - r * r;
	vec3 col = mix(shore_color.rgb, shallow_color.rgb,
		smoothstep(0.15, 0.359, depth));
	col = mix(col, base_color.rgb, smoothstep(0.359, 0.673, depth));
	col = mix(col, deep_color.rgb, smoothstep(0.673, 1.0, depth));

	// 2. Mottle: broad, slow, and barely there -- it only breaks the gradient
	// up so the lake is not a smooth wash.
	float mottle = noise2(p * mottle_scale * 0.06 + vec2(t * 0.012, t * -0.008));
	col = mix(col, shallow_color.rgb, smoothstep(0.55, 0.85, mottle) * 0.25);

	// 3. Foam curls. The constant ramps in the source are hard cuts, which is
	// what makes them read as painted rather than as a gradient.
	float curl = magic(p * foam_scale * 0.05 + vec2(t * 0.02, t * 0.015), 0.5);
	float curl_mask = smoothstep(0.62, 0.66, curl) * smoothstep(0.30, 0.22, r);
	col = mix(col, foam_color.rgb, curl_mask);

	// 4. Streak dashes: a wave field half-mixed with noise, through a narrow
	// window, so the streaks come out as long broken dashes rather than stripes.
	float wave = sin((p.x * 0.55 + p.y * 0.35) * streak_scale * 0.1
		- t * 0.10 + noise2(p * 0.11 + t * 0.01) * 2.4) * 0.5 + 0.5;
	float streak = smoothstep(0.532, 0.56, wave) * smoothstep(0.66, 0.63, wave);
	col = mix(col, foam_color.rgb, streak * 0.9);

	if (splash_age >= 0.0 && splash_age < 2.0) {
		float d = distance(p, splash_origin.xz);
		float ring = step(abs(d - splash_age * 3.0), 0.15) * (1.0 - splash_age / 2.0);
		col = mix(col, foam_color.rgb, ring);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float t = clamp(ndl * 0.5 + 0.5, 0.0, 1.0) * clamp(ATTENUATION, 0.0, 1.0);
	float band = step(0.5, t);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint.rgb, vec3(1.0), band);
}
```

- [ ] **Step 3: Check nothing else set the uniforms that went away**

Run: `grep -rn "band_color\|sparkle_color" --include="*.gd" --include="*.gdshader" .`
Expected: no hits outside the file just rewritten. If `world/ambient.gd`,
`core/toon.gd` or a test sets `band_color` or `sparkle_color`, point it at
`shallow_color` or `foam_color` instead.

- [ ] **Step 4: Look at the lake and settle the colours**

Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd`
then read `/tmp/shot_binairo.png` and `/tmp/shot_pipes.png`.

Judge three things and tune the uniform defaults until each holds:
- The curls read as painted white strokes, not as a grid or as noise. If they
  grid, lower `foam_scale`; if they wash out, narrow the `smoothstep(0.62, 0.66, curl)`
  window.
- The dashes are long and broken, like the source painting's, not continuous
  stripes.
- The lake is muted enough to sit beside the meadow's greens without shouting.
  `#00b3ff` is the source; `#2f8fd6` is this project.

Record the final hex values in the commit message.

- [ ] **Step 5: Check reduce-motion stills it**

Run the suite: `godot --headless --path . --script tests/run_tests.gd | tail -5`
Expected: 0 failures, `tests/test_ambient.gd` included — it covers the
`motion_scale` global and the splash clock.

Then confirm by eye that with `Motion.reduce` on, the lake is static: every
time term in `fragment()` is multiplied by `motion_scale`, so a zero global
must freeze all four layers. Read the shader back and check there is no bare
`TIME` anywhere in it.

- [ ] **Step 6: Commit**

```bash
git add shaders/water.gdshader
git commit -m "feat(art): the lake is the painted one, and it drifts

The pond was a toon shader of drifting bands and sparkle dots, which
at 68 degrees was a flat blue card nobody looked at. At 7 degrees it
is half the frame, so it is now a port of the source scene's own water
material: a depth gradient out from the middle, a broad mottle, the
white foam curls that make it read as painted rather than shaded, and
the long broken streak dashes.

A port and not a bake. The source material is 42 nodes and no image
textures at all, so it is cheaper as maths than as a texture in the
APK -- and it animates, which a baked sheet would only do by sliding.
Blender's Magic Texture is iterated sin of the coordinates fed back
into themselves, which is where the curls come from and is four lines
of GLSL.

The source's stops are #00ffdd, #00b3ff, #008ffb and #0061ff, which
are louder than this project's direction allows; muted toward the
palette's WATER and WATER_HI. Every time term is scaled by
motion_scale, so reduce-motion stills all four layers, and the splash
ring and the two-band light() survive unchanged."
```

---

### Task 6: The horizon: hills, cloud bank, clouds, and a bigger pond

**Files:**
- Create: `shaders/backdrop_sky.gdshader`
- Create: `shaders/backdrop_cloud.gdshader`
- Modify: `world/backdrop.gd` (the "no sky is ever in view" comment block at
  lines 45-56, plus new builders)
- Modify: `world/stage.gd:22-32` (`POND`)

**Interfaces:**
- Consumes: slots `hills` and `cloud` from Task 1.
- Produces: `Backdrop.hills: Node3D`, `Backdrop.clouds: Array[Node3D]`,
  `Backdrop.sky: MeshInstance3D`. `Backdrop.refresh()` stops being a no-op
  only if something moves from script; it should not — see Step 6.

- [ ] **Step 1: The cloud bank shader**

Ported from the source scene's `Material.003`, which is a node group of two
noise fields: one through a ramp from white to a pale blue for the colour, one
through a hard ramp inverted for the alpha.

Create `shaders/backdrop_sky.gdshader`:

```glsl
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, unshaded, specular_disabled,
	blend_mix;

// The far cloud bank the hills stand against, ported from the source scene's
// backdrop material (art/landscape.blend, Material.003): two noise fields,
// one through a soft ramp from white to the source's own pale blue for the
// colour, one through a hard ramp for the alpha, so the bank has a cut edge
// rather than fading out. One wide card, built as a QuadMesh in
// world/backdrop.gd because it is a rectangle and does not need exporting.
//
// Drifts on the motion_scale global, so reduce-motion stills it along with
// the grass and the lake. Unshaded: the landscape's light is painted into it.

global uniform float motion_scale;

uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// The source's own pale blue, within a hair of Pal.SKY_TOP.
uniform vec4 bank_color : source_color = vec4(0.765, 0.863, 0.925, 1.0);
uniform float drift = 0.004;
uniform float bank_scale = 2.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise2(p) * 0.6 + noise2(p * 2.1) * 0.3 + noise2(p * 4.3) * 0.1;
}

void fragment() {
	vec2 uv = UV * bank_scale + vec2(TIME * drift * motion_scale, 0.0);
	float body = fbm(uv);
	// The alpha ramp is a hard cut in the source, at 0.541 to 0.564.
	float a = smoothstep(0.541, 0.564, fbm(uv * 1.7 + vec2(3.1, 1.7)));
	// Higher up the card is more sky, less bank.
	a *= smoothstep(0.0, 0.45, UV.y);
	ALBEDO = mix(bank_color.rgb, cloud_color.rgb, smoothstep(0.495, 0.623, body));
	ALPHA = a;
}
```

- [ ] **Step 2: The cloud card shader**

The three `cloud.png` cards need to drift, and they must drift in shader so
`motion_scale` stills them. Create `shaders/backdrop_cloud.gdshader`:

```glsl
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, unshaded, specular_disabled,
	blend_mix;

// The painted cloud cards, drifting. The card's own texture carries the
// painting's light, so this is unshaded like every other landscape layer; the
// drift is a world-space offset in vertex() rather than a UV scroll, because
// scrolling a card's UV slides the painting across its own alpha and the cloud
// comes apart at the edge.
//
// Billboarding is left to the StandardMaterial3D path in world/backdrop.gd for
// the other cards; a cloud sits far enough away and near enough the frame's
// top that it reads without it, and a billboard would fight the drift.

global uniform float motion_scale;

uniform sampler2D albedo : source_color, filter_linear_mipmap, hint_default_white;
// World units per second the card slides, and how far before it wraps back.
uniform float drift_speed = 0.06;
uniform float drift_span = 40.0;

void vertex() {
	float d = mod(TIME * drift_speed * motion_scale, drift_span) - drift_span * 0.5;
	VERTEX.x += d;
}

void fragment() {
	vec4 c = texture(albedo, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
```

- [ ] **Step 3: Grow the pond**

In `world/stage.gd`, `POND` is 30 because the pond sat in a basin under the
board. It now runs to a shoreline in frame. Change the constant and extend its
comment:

```gdscript
## The pond's width in world units. It was 30 when the pond sat in a basin
## under a board seen from 68 degrees and only had to fill that basin. At 7
## degrees the water runs from the near bank to the hills, so it is sized to
## reach them instead. What the player reads as the near edge is still the
## meadow's basin rising out of it, not this plane's rim. The pond is also what
## keeps Ambient.splash alive -- the ring is drawn by the shared water
## material.
const POND := 90.0
```

Then set the lake shader's `pond_radius` to match from `Backdrop` or `Stage`
wherever the water material is reached (`Toon.water()`), so the depth gradient
spans the new pond rather than a third of it:

```gdscript
	var wm := Toon.water()
	if wm != null:
		wm.set_shader_parameter("pond_radius", POND * 0.5)
```

Put that in `Stage._ready()` after `water` is built. Check `core/toon.gd` for
how `water()` caches the material before writing this.

- [ ] **Step 4: Replace the "no sky" comment and build the three new layers**

In `world/backdrop.gd`, delete the comment block at lines 45-56 that explains
why the cloud is not built, and put the new one plus the constants in its
place:

```gdscript
## The painting's sky, in frame for the first time. At 68 degrees the top of
## the view still pointed 53 degrees below the horizon and all eight corners of
## a cloud card projected between y = -1926 and y = -6746 on a 1920-tall frame,
## so none of this was worth its draw call. The camera sits at 7 degrees now
## (world/stage.gd), the horizon is about a third of the way down the frame,
## and the hills, the bank behind them and three cloud cards are what fills it.
const HILLS_SHADER := preload("res://shaders/backdrop_sky.gdshader")
const CLOUD_SHADER := preload("res://shaders/backdrop_cloud.gdshader")
## How far out the hills ring stands and how big it is drawn. The ring is the
## outer roll of the source terrain with a 30-unit hole cut in its middle, so
## it already meets the meadow behind a rise.
const HILLS_SPREAD := 2.4
## The cloud bank: one card, wide enough to fill the frame's width at the
## distance it stands, and stood beyond the hills.
const BANK_SIZE := Vector2(400.0, 120.0)
const BANK_AT := Vector3(0.0, 8.0, -150.0)
## Three cloud cards between the hills and the bank, at the heights and spans
## the source painting puts them at.
const CLOUD_SPOTS := [
	Vector3(-60.0, 16.0, -110.0),
	Vector3(20.0, 22.0, -125.0),
	Vector3(75.0, 14.0, -100.0),
]
const CLOUD_SCALES := [1.0, 1.3, 0.9]
```

and beside `meadow`, `clumps`, `blossoms`:

```gdscript
var hills: Node3D
var sky: MeshInstance3D
var clouds: Array[Node3D] = []
```

- [ ] **Step 5: Add the builders and call them**

Add to `_ready()`, after `_build_clumps()`:

```gdscript
	hills = _build_hills()
	sky = _build_sky()
	_build_clouds()
```

and the three functions:

```gdscript
## The far roll of the source terrain, standing outside the meadow so the sky
## has a silhouette to sit behind rather than meeting flat ground. Washed
## toward the sky's own horizon colour with distance: depth through colour, not
## fog (docs/art/shading-direction.md).
func _build_hills() -> Node3D:
	var node := _instance("hills")
	if node == null:
		return null
	node.scale = Vector3(HILLS_SPREAD, 1.0, HILLS_SPREAD)
	node.position = Vector3(0.0, _meadow_y, 0.0)
	for mi in _meshes(node):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := _flat(mi.mesh.surface_get_material(0), false)
		# Lighter and cooler than the near meadow, so distance reads as colour.
		m.albedo_color = Color(0.86, 0.92, 0.95)
		mi.set_surface_override_material(0, m)
	add_child(node)
	return node

## One wide card of procedural cloud bank behind the hills.
func _build_sky() -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = BANK_SIZE
	var mi := MeshInstance3D.new()
	mi.name = "CloudBank"
	mi.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = HILLS_SHADER
	mi.set_surface_override_material(0, sm)
	mi.position = BANK_AT
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

## The painting's three cloud cards, drifting on the motion_scale global.
func _build_clouds() -> void:
	for i in CLOUD_SPOTS.size():
		var node := _instance("cloud")
		if node == null:
			return
		node.position = CLOUD_SPOTS[i]
		node.scale = Vector3.ONE * float(CLOUD_SCALES[i])
		for mi in _meshes(node):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var src := mi.mesh.surface_get_material(0)
			var sm := ShaderMaterial.new()
			sm.shader = CLOUD_SHADER
			if src is StandardMaterial3D:
				sm.set_shader_parameter("albedo", (src as StandardMaterial3D).albedo_texture)
			sm.set_shader_parameter("drift_speed", 0.04 + 0.02 * float(i))
			mi.set_surface_override_material(0, sm)
		add_child(node)
		clouds.append(node)
```

- [ ] **Step 6: Update `refresh()`'s comment, not its body**

`Backdrop.refresh()` is a no-op because everything that moves reads the
`motion_scale` global. That is still true and must stay true. Update the
comment to name the new movers:

```gdscript
## Nothing to do: every moving thing in the landscape -- the grass, the three
## cloud cards and the bank behind them -- reads the motion_scale shader global
## that world/ambient.gd owns. Kept so the settings sheet can call it without
## knowing that, and so a later moving piece has somewhere to go.
func refresh() -> void:
	pass
```

- [ ] **Step 7: Render and place by eye**

Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd`
then read `/tmp/shot_binairo.png`.

`CLOUD_SPOTS`, `BANK_AT`, `BANK_SIZE` and `HILLS_SPREAD` are first guesses.
Tune them until: the hills make a continuous silhouette with no gap to the
meadow and no hard straight edge; the bank fills the frame's width with no
visible card edge; the clouds sit above the horizon and inside the frame. The
last landscape pass wasted a round placing cards that projected off-screen at
y = -92 to -341, so check each is actually visible before tuning its look.

- [ ] **Step 8: Run the suite**

Run: `godot --headless --path . --script tests/run_tests.gd | tail -5`
Expected: 0 failures. `tests/test_models.gd` walks the model slots; if it
asserts the slot list, add `hills` to its expectation.

- [ ] **Step 9: Commit**

```bash
git add shaders/backdrop_sky.gdshader shaders/backdrop_sky.gdshader.uid \
  shaders/backdrop_cloud.gdshader shaders/backdrop_cloud.gdshader.uid \
  world/backdrop.gd world/stage.gd
git commit -m "feat(art): the landscape gets its horizon, and the clouds drift

The backdrop carried a comment explaining why the painting's cloud was
exported but never built: at 68 degrees all eight of its corners
projected between y = -1926 and y = -6746 on a 1920-tall frame. The
camera is at 7 degrees now, so that paragraph is replaced by the three
layers it was refusing -- the hills ring for a silhouette, a wide card
of procedural cloud bank behind it, and the three painted cloud cards.

The bank is ported from the source scene's backdrop material, which is
two noise fields, one through a soft ramp for colour and one through a
hard ramp for alpha so the bank has a cut edge instead of fading out.
The hills are washed toward the sky's horizon colour rather than
fogged, which is what the shading direction asks for: depth through
colour.

The clouds drift in shader, not from _process, so the motion_scale
global stills them with the grass and the lake and Backdrop.refresh()
stays the no-op it should be. The pond grows from 30 to 90: it was
sized to fill a basin under a board seen from above, and now runs from
the near bank to the hills."
```

**Uid files:** `.gdshader.uid` files are generated on first import. If they do
not exist after a Godot run, run `godot --headless --path . --import` and add
them — a fresh checkout regenerates different ids and breaks every reference
otherwise.

---

### Task 7: Re-measure the light

**Files:**
- Modify: `world/stage.gd:48-62` (`sun.light_energy`, `env.ambient_light_energy`,
  `sun.look_at_from_position`, and their comments)

**Interfaces:**
- Consumes: Tasks 2 and 6.
- Produces: two measured numbers and an updated comment.

- [ ] **Step 1: Understand what the current numbers are**

`sun.light_energy = 0.46` and `env.ambient_light_energy = 0.115` were
calibrated against a lit `STONE` tile face at 68 degrees, measured off
`/tmp/shot_binairo.png`: at 4:1 they rendered `#fbe0b8` against an `#ede2cc`
albedo, every channel within 12 percent and none clipping. The comment says
the `gl_compatibility` pipeline is brighter than the shader maths predicts, so
these are measured, not derived.

- [ ] **Step 2: Measure the same face on the new framing**

Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd`

Then sample a lit tile top in `/tmp/shot_binairo.png`. Read the pixel values
with Python:

```bash
python3 - <<'EOF'
from PIL import Image
im = Image.open("/tmp/shot_binairo.png").convert("RGB")
w, h = im.size
# Print a grid of samples across the middle of the board so a lit tile top can
# be picked out by eye from the values.
for y in range(int(h * 0.45), int(h * 0.75), 40):
    print(y, [im.getpixel((x, y)) for x in range(int(w * 0.25), int(w * 0.75), 80)])
EOF
```

Find a lit tile top's value. The albedo is `#ede2cc`.

- [ ] **Step 3: Adjust until the face lands in the same place**

A face leaning 61 degrees toward a camera 7 degrees off the horizontal takes
the sun differently from a face lying flat under one at 68. Adjust
`sun.light_energy` and `env.ambient_light_energy`, keeping their 4:1 ratio,
until the lit tile top renders within 12 percent of `#fbe0b8` on every channel
with nothing clipping — the same test the old numbers passed. Re-render between
attempts.

- [ ] **Step 4: Re-aim the sun so shadows still fall toward the player**

The sun is aimed with
`sun.look_at_from_position(Vector3(3.0, 8.0, -6.0), Vector3.ZERO, Vector3.UP)`,
chosen so shadows fall toward the player and to the left. Across a board
leaning 61 degrees, check on the render that they still do; if the board's own
shadow now falls up the face or off the top, move the position and say in the
comment what it is aimed for.

- [ ] **Step 5: Update the comment with the new numbers and today's date**

Keep the shape of the existing comment — what was measured, against what, on
which file, and the warning that the pipeline is brighter than the maths — and
replace the numbers and the reference frame with the new ones.

- [ ] **Step 6: Commit**

```bash
git add world/stage.gd
git commit -m "fix(world): the sun is re-measured against a leaning face

sun.light_energy 0.46 and ambient 0.115 were calibrated against a lit
STONE tile face lying flat under a 68 degree camera, on a pipeline the
comment warns is brighter than the shader maths predicts. The face now
leans 61 degrees toward a camera 7 degrees off the horizontal, which
takes the sun differently.

Re-measured the same way -- off a rendered frame, not derived -- with
the same test: a lit tile top within 12 percent of #fbe0b8 on every
channel against its #ede2cc albedo, nothing clipping."
```

---

### Task 8: The per-board readability pass

The bulk of the work, and the risk the design names. One commit per board, in
the order the verdict from Task 4 ranks them worst-first.

**Files:**
- Modify: whichever of `puzzles/*.gd` and `core/placeholders.gd` each board needs
- Possibly modify: each board's `board_pitch()`

**Interfaces:**
- Consumes: the Task 4 verdict, and `Stage._lean`.
- Produces: for boards that need it, a helper used the same way everywhere.

- [ ] **Step 1: Add the one shared lever**

A piece that reads as *standing in a place* leans with the board and looks
like it is toppling. Add to `core/puzzle_base_3d.gd` the counter-rotation, so
every board that needs it spells it the same way:

```gdscript
## Stands `node` world-up out of a leaning board, about its own base. For a
## piece that reads as standing in a place -- a horse, a conifer, a lantern, a
## mooring post -- which otherwise leans with the board and looks like it is
## toppling backwards. Costs a gap at the base and can occlude the cell behind
## it, so it is a per-piece decision made on a rendered frame, not a default.
func stand_upright(node: Node3D) -> void:
	var lean := board.global_transform.basis.get_rotation_quaternion()
	node.transform.basis = Basis(lean.inverse()) * node.transform.basis
```

- [ ] **Step 2: Work the boards worst-first, one commit each**

For each board the Task 4 verdict marked wrong, in that order:

1. Render it alone. `tests/_shot.gd` walks all thirteen; if that is too slow to
   iterate on, read it and drive the single entry.
2. Choose one of the two levers the spec names: `stand_upright()` on the pieces
   that must stand, or a shallower `board_pitch()` so the board leans less and
   trades grid depth for uprightness.
3. Re-render and confirm the grid still reads and nothing topples.
4. Run the suite: `godot --headless --path . --script tests/run_tests.gd | tail -5`
5. Commit with the board's name in the subject and the lever in the body,
   saying what the frame showed before and after.

The boards at risk, from the spec: Horse Pen's horse, Tents' conifers, Light
Up's lanterns, Untangle's mooring posts. Do not pre-empt the others — the Task
4 verdict decides, not this list.

- [ ] **Step 3: Re-render everything once the pass is done**

Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot.gd`
Read all thirteen. Expected: every grid readable, nothing toppling, the
horizon behind each.

---

### Task 9: Budget, harnesses, and the phone

**Files:**
- Modify: `docs/superpowers/specs/2026-09-16-low-horizon-design.md` (section 8,
  the measured numbers)

**Interfaces:**
- Consumes: every task before it.
- Produces: recorded numbers, and a merged branch.

- [ ] **Step 1: Measure frame time and draw calls**

Run `tests/_shot_anim.gd` — read it first for its arguments; it prints
`idle frames=<n> mean_ms=<x> max_draw_calls=<d>`. Measure with the board at
rest, on Binairo and on Pipes (the heaviest).

Expected: `mean_ms` at or under 8.0 and `max_draw_calls` at or under 855. The
landscape adds roughly seven draw calls — the hills ring, the cloud bank,
three cloud cards, and headroom — against 728 measured when the landscape
landed.

If over budget: the cloud bank and the hills ring are one draw call each and
cannot be cut further, so reach for `Ambient.POLLEN_AMOUNT` first, then
`Fx.PUFF_POOL`, and record what was changed.

- [ ] **Step 2: Run the suite**

Run: `godot --headless --path . --script tests/run_tests.gd | tail -5`
Expected: 0 failures.

- [ ] **Step 3: Run the win harness windowed**

Run: `godot --path . --resolution 1080x1920 --script res://tests/_win.gd 2>&1 | tail -20`
Expected: 10/10. It reports 0/0 headless, so a headless run proves nothing.
This is the check that the new picking actually plays: a board that cannot be
tapped cannot be won.

- [ ] **Step 4: Record the numbers in the spec**

Add the measured `mean_ms`, `max_draw_calls`, suite result and win result to
section 8 of the spec, with the date, the way the Pipes spec records its own.

- [ ] **Step 5: Revert the project.godot header**

Run: `git diff --stat project.godot`
If it is the header comment only: `git checkout -- project.godot`

- [ ] **Step 6: Commit and put it on a phone**

```bash
git add docs/superpowers/specs/2026-09-16-low-horizon-design.md
git commit -m "docs(art): the low-horizon spec records its measured numbers"
```

Then run `tools/deploy_android.sh` and look at it on the phone. A horizon and
a lean are exactly the things a 6-inch screen judges differently from a
1080x1920 window on a Mac. Report what it looks like; do not merge on the
strength of the Mac frames alone.

- [ ] **Step 7: Hand back for the merge decision**

Merge locally when the frames and the phone agree, and leave the push to the
user: a push to `main` runs the GitHub Actions workflow that builds the APK and
distributes it through Firebase App Distribution, so it is their call.

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
| --- | --- |
| 0. What is replaced and kept | 2, 5, 6 |
| 1. Framing geometry | 2 |
| 2. The lean, and the pieces it breaks | 2, 8 |
| 3. Input | 3 |
| 4. The landscape at a raking angle | 1, 6 |
| 5. The lake | 5 |
| 6. Wind | 5 (water), 6 (clouds), 8/9 (grass re-tune) |
| 7. Light | 7 |
| 8. Budget and verification | 4, 9 |
| 9. Build order | the task order itself |

**Gap found and closed:** the spec's section 6 asks for `sway_amount` and
`gust_scale` in `shaders/backdrop_grass.gdshader` to be re-tuned for a field
seen edge-on. No task owned it. It belongs with the frames, so it is folded
into Task 6 Step 7's tuning round — add `shaders/backdrop_grass.gdshader` to
that task's file list and to its commit when the values move.

**Placeholder scan:** the tuning steps (Task 5 Step 4, Task 6 Step 7, Task 7
Step 3, Task 8 Step 2) deliberately name a judgement rather than a value,
because the values are measured off a rendered frame. Each names the exact
test that settles it. Task 4 produces a verdict table that Task 8 consumes.

**Type consistency:** `board_pitch()` keeps its name and signature throughout;
`Stage.fit_camera`'s third parameter is renamed `face` in Task 2 and is passed
positionally by `core/puzzle_base_3d.gd:82`, which needs no edit.
`Stage._lean(face: float)`, `Stage._face`, `Backdrop.hills`, `Backdrop.sky`,
`Backdrop.clouds` and `stand_upright(node: Node3D)` are each defined once and
referred to by those names only.
