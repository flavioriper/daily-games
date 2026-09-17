# Single-Turn Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One shared turn flow and one shared backend, proved end to end by a throwaway turn, so every game in phases 1 to 6 costs a screen, a grader and a content source.

**Architecture:** A `StageView` base extracted from `PuzzleBase3D` carries the stage mounting and picking maths, and `TurnBase` stands on it beside the puzzles. `core/backend.gd` is the client's one way out: anonymous Firebase Auth over REST, Firestore REST for reads, one Cloud Function for writes, a disk cache and an offline queue behind it. The server is Cloud Functions v2 in `peeplet-daily`, publishing content nightly and rolling sharded histograms into one tally document the client reads and computes its own percentile from.

**Tech Stack:** Godot 4.7 / GDScript, gl_compatibility. Node 22 / TypeScript, `firebase-functions` v2, `firebase-admin`. Firestore. Firebase Auth (anonymous). Firebase CLI and emulator suite.

**Spec:** `docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md`

## Global Constraints

- **No new test files.** The project is in MVP mode: spend the time on the feature, not the suite. Every task verifies with throwaway, self-driven checks — commands whose output you read — never a committed `tests/test_*.gd`. The one exception is that the **existing** suite must keep passing.
- Suite command: `godot --headless --path . --script res://tests/run_tests.gd`. Baseline before any change: record the `passed=N failed=0` line and keep `failed=0` at every commit.
- Win harness needs a display; run it windowed: `godot --path . --resolution 540x960 --script res://tests/_win.gd`. Headless it silently reports 0/0.
- Godot re-saves `project.godot` with a header comment after windowed runs. Revert that hunk before committing unless the change is yours.
- A model ships as a model. Never render a `.blend` to a PNG and put it on screen. Card pictures are live dioramas (`ui/hud/card_scene.gd`).
- Firebase project is `peeplet-daily`. Android app id `1:881491152475:android:0e88e9f9a22583fdd0b97e`.
- Day key is `Daily.date_key()` — UTC `yyyymmdd` as an int.
- Nothing reaches the network unless `Backend.start()` ran, and only `world/main.gd` calls it. Same rule as `Analytics.start()`. Neither is an autoload.
- Score is an integer 0 to 100 inclusive; the histogram has 101 buckets.
- Locales are exactly `en`, `pt`, `es`, falling back to `en`.
- Commit style: conventional prefix, lower-case subject, a prose body explaining why. No attribution footer.
- Work on branch `feat/turn-foundation`. Do not push; the user calls the push.

---

### Task 1: Extract `StageView` from `PuzzleBase3D`

**Files:**
- Create: `core/stage_view.gd`
- Modify: `core/puzzle_base.gd:2` (the `extends` line)
- Modify: `core/puzzle_base_3d.gd` (reduced to its puzzle-specific remainder)

**Interfaces:**
- Consumes: nothing.
- Produces: `class_name StageView extends Control` with `board: Node3D`, `stage_enter(board_name: String) -> void`, `stage_exit() -> void`, `accepts_input() -> bool`, `board_size() -> Vector2i`, `board_height() -> float`, `plane_height() -> float`, `board_pitch() -> float`, `board_projection() -> int`, `board_yaw() -> float`, `board_margin() -> float`, `board_depth() -> float`, `board_aabb() -> AABB`, `viewport_rect() -> Rect2`, `local_to_board(local: Vector2) -> Variant`, `local_ray(local: Vector2) -> Array`, `board_to_local(point: Vector3) -> Vector2`, `on_board_press/drag/release(hit: Vector3) -> void`.

- [ ] **Step 1: Record the baseline**

Run and write the number down; it is the gate for every later task.

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3
```

Expected: a line `passed=N failed=0`.

- [ ] **Step 2: Create `core/stage_view.gd`**

This is a move, not a rewrite: the bodies come from `core/puzzle_base_3d.gd` unchanged, including their comments.

```gdscript
class_name StageView
extends Control

## A Control whose picture is a Node3D on the shared stage. It turns its own
## rectangle into a camera frame and its touches into board-plane hits, and
## knows nothing about puzzles or turns: PuzzleBase3D and TurnBase both stand
## on it.
##
## Nothing mounts by itself. A subclass calls stage_enter() from its own
## _ready and stage_exit() from its own _exit_tree, so a Control that
## inherits this and wants no board pays nothing for it.
## Spec: docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md,
## section 2.1.

const BoardMath = preload("res://core/board_math.gd")

var board: Node3D
var _stage: Node
var _pressing := false

# --- to override ---
## Columns and rows of the board, in cells.
func board_size() -> Vector2i: return Vector2i(1, 1)
## How tall the tallest piece is; frames the camera.
func board_height() -> float: return 0.5
## Height of the surface taps land on (the tile tops).
func plane_height() -> float: return 0.0
## The angle this board's face wants to be seen at, in degrees above the
## horizontal; NAN takes the island's own (Stage.DEFAULT_FACE). The camera
## itself never moves off Stage.CAMERA_PITCH -- the board leans to bring its
## face around to that angle instead. Only a board whose pieces mean
## something by their height should ask for a shallower one and lean less
## (see Stage.fit_camera): Balance, whose beams tilt and whose discs stack.
func board_pitch() -> float: return NAN
## Camera projection this board wants, a Camera3D.PROJECTION_* value. Depth is
## the default; a board of stacked blocks reads as a diorama only when its
## parallel edges stay parallel, so it asks for PROJECTION_ORTHOGONAL.
func board_projection() -> int: return Camera3D.PROJECTION_PERSPECTIVE
## Camera yaw this board wants, in degrees around Y. Zero is the island's own,
## which is what every board that does not care should say: the rig keeps
## whatever it was last given, so a board that left the yaw alone would inherit
## the 45 degrees Pipes' island is looked at from and come out standing on its
## corner. A board that can be turned answers with the stop it is showing, so
## that the re-fit after a resize agrees with where the turn left the camera;
## NAN still means "leave it alone" for anything that wants that.
func board_yaw() -> float: return 0.0
## Extra world units framed around the tiles on each side (a platform lip).
func board_margin() -> float: return 0.0
## Depth framed below the tile plane (the platform's thickness).
func board_depth() -> float: return 0.0
## Whether a touch reaches the on_board_* hooks. A finished board says no.
func accepts_input() -> bool: return true
func on_board_press(_hit: Vector3) -> void: pass
func on_board_drag(_hit: Vector3) -> void: pass
func on_board_release(_hit: Vector3) -> void: pass
# -------------------

## Takes a board onto the stage and starts following this control's rect.
func stage_enter(board_name: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	board = Node3D.new()
	board.name = board_name
	_stage = get_tree().get_first_node_in_group("stage")
	if _stage != null:
		_stage.mount(board)
		# Nothing behind a board for now but flat colour; see Stage.show_setting.
		_stage.show_setting(false)
	else:
		push_warning("StageView: no Stage in group 'stage'; %s will not render and taps will miss" % board.name)
		add_child(board)
	resized.connect(_refit)
	_refit()

## Hands the stage back the way it was found: the menu campsite keeps its
## island.
func stage_exit() -> void:
	if _stage != null and is_instance_valid(_stage):
		_stage.show_setting(true)
	if is_instance_valid(board):
		if _stage != null and is_instance_valid(_stage):
			_stage.unmount(board)
		board.queue_free()

func board_aabb() -> AABB:
	var s := board_size()
	var box := BoardMath.board_aabb(s.x, s.y, board_height())
	var m := board_margin()
	var d := board_depth()
	return AABB(box.position - Vector3(m, d, m), box.size + Vector3(2.0 * m, d, 2.0 * m))

## This control's rectangle in viewport pixels, the space the camera projects into.
func viewport_rect() -> Rect2:
	return get_global_transform_with_canvas() * Rect2(Vector2.ZERO, size)

func _refit() -> void:
	if _stage == null or not is_inside_tree():
		return
	_stage.fit_camera(board_aabb(), viewport_rect(), board_pitch(), board_projection(), board_yaw())

func _camera() -> Camera3D:
	return get_viewport().get_camera_3d()

## Board-plane point under a control-local position, or null when the ray
## misses. The board leans (see Stage._lean), so the plane at plane_height()
## is horizontal in the *board's* space and nowhere else: the ray is taken
## into that space before it is intersected.
func local_to_board(local: Vector2) -> Variant:
	var cam := _camera()
	if cam == null:
		return null
	var vp := get_global_transform_with_canvas() * local
	var inv := board.global_transform.affine_inverse()
	var origin: Vector3 = inv * cam.project_ray_origin(vp)
	var dir: Vector3 = (inv.basis * cam.project_ray_normal(vp)).normalized()
	return BoardMath.ray_plane(origin, dir, plane_height())

## The picking ray through a control-local position, as
## [origin: Vector3, direction: Vector3] in the *board's* own space, or [] when
## there is no camera.
func local_ray(local: Vector2) -> Array:
	var cam := _camera()
	if cam == null:
		return []
	var vp := get_global_transform_with_canvas() * local
	var inv := board.global_transform.affine_inverse()
	return [inv * cam.project_ray_origin(vp),
		(inv.basis * cam.project_ray_normal(vp)).normalized()]

## Control-local position of a board-space point; the inverse of
## local_to_board. The point goes out through the board's transform before it
## is projected, because the board leans.
func board_to_local(point: Vector3) -> Vector2:
	var cam := _camera()
	if cam == null:
		return Vector2.INF
	var world: Vector3 = board.global_transform * point
	return get_global_transform_with_canvas().affine_inverse() * cam.unproject_position(world)

## Touch events only. The project emulates touch from mouse, and the viewport
## hands a control both the mouse event and the emulated touch, so listening
## to both would fire twice per click.
func _gui_input(event: InputEvent) -> void:
	if not accepts_input():
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

- [ ] **Step 3: Re-parent `PuzzleBase`**

In `core/puzzle_base.gd`, change line 2 only:

```gdscript
class_name PuzzleBase
extends StageView
```

Leave the rest of the file exactly as it is.

- [ ] **Step 4: Reduce `core/puzzle_base_3d.gd` to its remainder**

Replace the whole file with:

```gdscript
extends "res://core/puzzle_base.gd"

## A PuzzleBase whose board lives in the 3D stage. Everything that mounts the
## board, frames the camera on it and turns touches into board-plane hits now
## lives in core/stage_view.gd, which PuzzleBase extends; all that is left
## here is what a *puzzle* answers differently. Subclasses build into `board`
## and override the on_board_* hooks exactly as before.

func is_3d() -> bool: return true

## A finished board takes no more taps.
func accepts_input() -> bool: return not is_done()

func _ready() -> void:
	stage_enter("%s_board" % puzzle_id())

func _exit_tree() -> void:
	stage_exit()
```

- [ ] **Step 5: Run the suite and compare against the baseline**

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -5
```

Expected: the same `passed=N failed=0` as Step 1. Any drop in `passed` means a suite aborted — read the `FAIL [...]` lines above it.

- [ ] **Step 6: Run the win harness windowed**

```bash
godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | tail -20
```

Expected: every board reported winnable, e.g. `10/10`. A `0/0` means it ran headless; it needs a display.

- [ ] **Step 7: Check `project.godot` was not touched, then commit**

```bash
git diff --stat project.godot && git checkout -- project.godot 2>/dev/null
git add core/stage_view.gd core/stage_view.gd.uid core/puzzle_base.gd core/puzzle_base_3d.gd
git commit -m "$(cat <<'MSG'
refactor(core): the stage view under both a puzzle and a turn

About ninety of puzzle_base_3d.gd's lines had nothing to do with puzzles:
mounting a Node3D on the stage, turning the control's rect into a camera
frame, and turning touches into board-plane hits. They move to
core/stage_view.gd so a single-turn game can stand on the same floor without
inheriting a puzzle's moves, hints and checks.

GDScript is single-inheritance and PuzzleBase3D already extends PuzzleBase,
so the chain is Control -> StageView -> PuzzleBase -> PuzzleBase3D rather
than a second parent. StageView mounts nothing by itself -- it offers
stage_enter and stage_exit, which PuzzleBase3D calls from its own _ready and
_exit_tree -- so a PuzzleBase that never wanted a board pays nothing.

The bodies moved unchanged, comments included. The suite and the windowed
win harness are the gate on that claim.
MSG
)"
```

---

### Task 2: Server scaffold, Firestore and rules

**Files:**
- Create: `server/firebase.json`, `server/.firebaserc`, `server/firestore.rules`, `server/firestore.indexes.json`, `server/.gdignore`, `server/functions/package.json`, `server/functions/tsconfig.json`, `server/functions/src/index.ts` (stub)
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces: a deployable and emulatable Firebase project in `server/`, and the rule set every later task's reads are checked against.

- [ ] **Step 1: Confirm the prerequisites before building on them**

```bash
firebase projects:list
firebase firestore:databases:list --project peeplet-daily
```

`firestore:databases:list` currently answers `HTTP Error: 403, Cloud Firestore API has not been used in project peeplet-daily`. Enable Firestore (Native mode, a single region — `southamerica-east1` or `us-central1`, pick one and record it) and confirm the same command then lists `(default)`.

Cloud Functions v2 needs the **Blaze** plan. Check it and stop here if the project is on Spark — Tasks 2 and 3 are blocked, Tasks 1 and 4 onward are not:

```bash
gcloud auth login   # run this yourself if gcloud reports expired credentials
gcloud billing projects describe peeplet-daily
```

Enable the **Anonymous** sign-in provider in Authentication → Sign-in method.

- [ ] **Step 2: Create a Web app so the REST key is unrestricted**

The project's only app is the Android one, and an Android API key can carry a package-and-certificate restriction that would demand `X-Android-Package` and `X-Android-Cert` headers on every REST call.

```bash
firebase apps:create WEB "Peeplet Daily Web" --project peeplet-daily
firebase apps:sdkconfig WEB --project peeplet-daily | grep apiKey
```

Record the `apiKey`. Task 4 hardcodes it.

- [ ] **Step 3: Write the Firebase config files**

`server/.firebaserc`:

```json
{
  "projects": {
    "default": "peeplet-daily"
  }
}
```

`server/firebase.json`:

```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "runtime": "nodejs22",
      "ignore": ["node_modules", ".git", "*.log"]
    }
  ],
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "functions": { "port": 5001 },
    "ui": { "enabled": true, "port": 4000 },
    "singleProjectMode": true
  }
}
```

`server/firestore.indexes.json`:

```json
{
  "indexes": [],
  "fieldOverrides": []
}
```

`server/.gdignore` — an empty file. Godot skips any directory containing one, which keeps it from importing `node_modules`.

```bash
touch server/.gdignore
```

- [ ] **Step 4: Write the rules**

`server/firestore.rules`. Nothing is client-writable: every write goes through a function on the admin SDK, which bypasses rules entirely.

```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    // The day's published content, and the crowd's rolled-up tally.
    match /days/{day}/turns/{game} {
      allow read: if request.auth != null;
      allow write: if false;

      // The answer for a game whose answer must not leak. Server only.
      match /secret/{doc} {
        allow read, write: if false;
      }

      // A player reads their own submit and no one else's.
      match /submits/{uid} {
        allow read: if request.auth != null && request.auth.uid == uid;
        allow write: if false;
      }

      // Aggregation internals. Clients read tally/current instead.
      match /shards/{shard} {
        allow read, write: if false;
      }

      match /tally/{doc} {
        allow read: if request.auth != null;
        allow write: if false;
      }
    }

    // Reserved for the leaderboard.
    match /players/{uid} {
      allow read: if request.auth != null;
      allow write: if false;
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

- [ ] **Step 5: Scaffold the functions package**

`server/functions/package.json`:

```json
{
  "name": "peeplet-daily-functions",
  "private": true,
  "type": "commonjs",
  "main": "lib/index.js",
  "engines": { "node": "22" },
  "scripts": {
    "build": "tsc",
    "watch": "tsc --watch",
    "serve": "npm run build && firebase emulators:start --only auth,firestore,functions",
    "deploy": "firebase deploy --only functions"
  },
  "dependencies": {
    "firebase-admin": "^13.0.0",
    "firebase-functions": "^6.1.0"
  },
  "devDependencies": {
    "typescript": "^5.6.0"
  }
}
```

`server/functions/tsconfig.json`:

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es2022",
    "lib": ["es2022"],
    "moduleResolution": "node",
    "outDir": "lib",
    "rootDir": "src",
    "strict": true,
    "noUnusedLocals": true,
    "sourceMap": true
  },
  "include": ["src"]
}
```

`server/functions/src/index.ts`, a stub that only has to compile:

```ts
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

initializeApp();

/** Shared handle; the real functions arrive in the next task. */
export const db = getFirestore();
```

- [ ] **Step 6: Ignore the build output**

Append to `.gitignore`:

```
server/functions/node_modules/
server/functions/lib/
server/.firebase/
```

- [ ] **Step 7: Install, build and check the rules compile**

```bash
cd server/functions && npm install && npm run build && cd ../..
cd server && firebase deploy --only firestore:rules --project peeplet-daily --dry-run; cd ..
```

Expected: `tsc` exits silently, and the rules step reports the rules as valid. If `--dry-run` is unsupported by the installed CLI, deploy them for real — nothing reads them yet.

- [ ] **Step 8: Check Godot still imports the project cleanly**

`server/` must be invisible to the engine.

```bash
godot --headless --path . --import 2>&1 | grep -i -E 'server/|node_modules' | head
```

Expected: no output.

- [ ] **Step 9: Commit**

```bash
git add server .gitignore
git commit -m "$(cat <<'MSG'
feat(server): the Firebase project the turns will talk to

A server/ directory beside the game: firebase.json, the Firestore rules, and
a TypeScript functions package on Node 22 with firebase-functions v2. An
empty server/.gdignore keeps Godot from walking into node_modules, and the
build output is ignored.

The rules are deny-by-default and nothing is client-writable at all: every
write goes through a function on the admin SDK, which bypasses rules. A
player may read the day's content and the rolled-up tally, and their own
submit and no one else's; the secret answers and the histogram shards are
unreadable by any client.
MSG
)"
```

---

### Task 3: `publishDay`, `submitTurn` and `rollupTally`

**Files:**
- Modify: `server/functions/src/index.ts` (replace the stub)

**Interfaces:**
- Consumes: the Firestore layout and rules from Task 2.
- Produces:
  - `POST <functions>/submitTurn`, header `Authorization: Bearer <idToken>`, body `{game: string, day: number, score: number, guess: unknown, locale: "en"|"pt"|"es"}` → `{ok: true, created: boolean, score: number}` or `{error: string}` with 400/401/405/429.
  - `days/{day}/turns/{game}` → `{json: string}` decoding to `{answer: number, prior: {mean: number, spread: number}}`.
  - `days/{day}/turns/{game}/tally/current` → `{json: string}` decoding to `{count: number, histogram: number[101], byLocale: {en: number, pt: number, es: number}}`.
  - `fnv1a(s: string): number`, matched byte for byte by `Daily.fnv1a` in Task 4.

- [ ] **Step 1: Write the functions**

Replace `server/functions/src/index.ts` entirely:

```ts
import {onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

initializeApp();
const db = getFirestore();

/** A score is an integer 0..100 inclusive, so the histogram has 101 buckets. */
export const BUCKETS = 101;
/** One Firestore document takes about one write a second. Ten shards give ten,
 *  and the rollup means a client still reads exactly one document. */
export const SHARDS = 10;

const LOCALES = ["en", "pt", "es"] as const;
type Locale = (typeof LOCALES)[number];

/**
 * FNV-1a, 32 bit. core/daily.gd computes the same hash over the same string,
 * so a phone that has never reached the network derives the same day's
 * content as the one that was published here.
 */
export function fnv1a(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

/** UTC yyyymmdd, the same key Daily.date_key() makes. */
export function dayKey(d: Date): number {
  return d.getUTCFullYear() * 10000 + (d.getUTCMonth() + 1) * 100 + d.getUTCDate();
}

/**
 * The published content, one entry per turn game. guess_number is the phase 0
 * stub and is deleted when How Big? lands.
 */
export const GAMES: Record<string, (day: number) => unknown> = {
  guess_number: (day) => ({
    answer: fnv1a(`guess_number|${day}`) % 101,
    prior: {mean: 50, spread: 28},
  }),
};

function turnDoc(day: number, game: string) {
  return db.doc(`days/${day}/turns/${game}`);
}

/** Tomorrow's content, written a day ahead so a missed night is not a blank day. */
export const publishDay = onSchedule("0 3 * * *", async () => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 1);
  const day = dayKey(d);
  for (const [game, make] of Object.entries(GAMES)) {
    await turnDoc(day, game).set({json: JSON.stringify(make(day))});
  }
});

/**
 * One submit per player per game per day, written once. A repeat answers with
 * what is already stored rather than an error, which is what makes the
 * client's retry and its offline flush safe.
 */
export const submitTurn = onRequest({cors: false}, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({error: "POST only"});
    return;
  }
  const authz = req.get("Authorization") ?? "";
  const token = authz.startsWith("Bearer ") ? authz.slice(7) : "";
  let uid: string;
  try {
    uid = (await getAuth().verifyIdToken(token)).uid;
  } catch {
    res.status(401).json({error: "bad token"});
    return;
  }

  const body = (req.body ?? {}) as Record<string, unknown>;
  const game = body.game;
  const day = body.day;
  const score = body.score;
  if (typeof game !== "string" || !(game in GAMES)) {
    res.status(400).json({error: "unknown game"});
    return;
  }
  if (!Number.isInteger(day) || (day as number) < 20260101) {
    res.status(400).json({error: "bad day"});
    return;
  }
  if (!Number.isInteger(score) || (score as number) < 0 || (score as number) >= BUCKETS) {
    res.status(400).json({error: "bad score"});
    return;
  }
  const locale: Locale = LOCALES.includes(body.locale as Locale) ?
    (body.locale as Locale) : "en";
  const theDay = day as number;
  const theScore = score as number;

  // One submit a second per player, whatever they are submitting to.
  const player = db.doc(`players/${uid}`);
  const now = Date.now();
  const seen = await player.get();
  if (seen.exists && now - (seen.get("lastSubmitMs") ?? 0) < 1000) {
    res.status(429).json({error: "too fast"});
    return;
  }
  await player.set({lastSubmitMs: now}, {merge: true});

  const submit = turnDoc(theDay, game).collection("submits").doc(uid);
  try {
    await submit.create({
      score: theScore,
      guess: body.guess ?? null,
      locale,
      at: FieldValue.serverTimestamp(),
    });
  } catch {
    // Already there: two flushes raced, or the player is retrying.
    const existing = await submit.get();
    res.json({ok: true, created: false, score: existing.get("score") ?? theScore});
    return;
  }

  const shard = Math.floor(Math.random() * SHARDS);
  await turnDoc(theDay, game).collection("shards").doc(String(shard)).set({
    count: FieldValue.increment(1),
    histogram: {[String(theScore)]: FieldValue.increment(1)},
    byLocale: {[locale]: FieldValue.increment(1)},
  }, {merge: true});

  res.json({ok: true, created: true, score: theScore});
});

/** Shards into the one document a client reads. Today and yesterday, because
 *  the day rolls over in UTC and somebody is always mid-turn. */
export const rollupTally = onSchedule("every 5 minutes", async () => {
  const now = new Date();
  const yesterday = new Date(now.getTime() - 86400000);
  for (const day of [dayKey(yesterday), dayKey(now)]) {
    for (const game of Object.keys(GAMES)) {
      const shards = await turnDoc(day, game).collection("shards").get();
      if (shards.empty) continue;
      const histogram = new Array<number>(BUCKETS).fill(0);
      const byLocale: Record<string, number> = {en: 0, pt: 0, es: 0};
      let count = 0;
      for (const s of shards.docs) {
        count += (s.get("count") as number) ?? 0;
        const h = (s.get("histogram") ?? {}) as Record<string, number>;
        for (const [k, v] of Object.entries(h)) {
          const i = Number(k);
          if (Number.isInteger(i) && i >= 0 && i < BUCKETS) histogram[i] += v;
        }
        const l = (s.get("byLocale") ?? {}) as Record<string, number>;
        for (const [k, v] of Object.entries(l)) byLocale[k] = (byLocale[k] ?? 0) + v;
      }
      await turnDoc(day, game).collection("tally").doc("current")
        .set({json: JSON.stringify({count, histogram, byLocale})});
    }
  }
});
```

- [ ] **Step 2: Build**

```bash
cd server/functions && npm run build && cd ../..
```

Expected: silence. `noUnusedLocals` is on, so an unused import fails the build.

- [ ] **Step 3: Start the emulators**

In a terminal you leave running:

```bash
cd server && firebase emulators:start --only auth,firestore,functions --project peeplet-daily
```

Expected: the auth emulator on 9099, Firestore on 8080, functions on 5001, and `submitTurn` listed.

- [ ] **Step 4: Drive the whole path by hand and read each answer**

A throwaway shell check — not a committed test. `DAY` is today in UTC.

```bash
DAY=$(date -u +%Y%m%d)
HOST=127.0.0.1
BASE="http://$HOST:8080/v1/projects/peeplet-daily/databases/(default)/documents"

# 1. Publish today's content by hand (publishDay writes tomorrow's).
ANSWER=42
curl -s -X PATCH "$BASE/days/$DAY/turns/guess_number" \
  -H 'Authorization: Bearer owner' -H 'Content-Type: application/json' \
  -d "{\"fields\":{\"json\":{\"stringValue\":\"{\\\"answer\\\":$ANSWER,\\\"prior\\\":{\\\"mean\\\":50,\\\"spread\\\":28}}\"}}}" | head -5

# 2. An anonymous player.
TOK=$(curl -s -X POST "http://$HOST:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=any" \
  -H 'Content-Type: application/json' -d '{"returnSecureToken":true}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["idToken"])')
echo "token length ${#TOK}"

# 3. Submit.
curl -s -X POST "http://$HOST:5001/peeplet-daily/us-central1/submitTurn" \
  -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' \
  -d "{\"game\":\"guess_number\",\"day\":$DAY,\"score\":87,\"guess\":40,\"locale\":\"pt\"}"
echo
# 4. Submit again: must be idempotent.
sleep 2
curl -s -X POST "http://$HOST:5001/peeplet-daily/us-central1/submitTurn" \
  -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' \
  -d "{\"game\":\"guess_number\",\"day\":$DAY,\"score\":12,\"guess\":9,\"locale\":\"pt\"}"
echo
```

Expected: step 3 answers `{"ok":true,"created":true,"score":87}`; step 4 answers `{"ok":true,"created":false,"score":87}` — the second score is *not* recorded. A `429` from step 4 means the `sleep 2` was skipped.

- [ ] **Step 5: Roll up and read the tally**

The scheduler does not fire in the emulator; call the rollup through the emulator shell.

```bash
cd server/functions && npx firebase functions:shell --project peeplet-daily <<'EOF'
rollupTally()
EOF
cd ../..

DAY=$(date -u +%Y%m%d)
curl -s "http://127.0.0.1:8080/v1/projects/peeplet-daily/databases/(default)/documents/days/$DAY/turns/guess_number/tally/current" \
  -H 'Authorization: Bearer owner'
```

Expected: a document whose `json` string decodes to `count: 1`, `histogram[87] == 1`, `byLocale.pt == 1`, everything else zero.

- [ ] **Step 6: Deploy to the real project**

```bash
cd server && firebase deploy --only functions,firestore:rules --project peeplet-daily; cd ..
gcloud scheduler jobs list --project peeplet-daily 2>/dev/null | head
```

Expected: three functions deployed and two scheduler jobs created. Note the deployed region — Task 4's `FUNCTIONS` constant must match it.

- [ ] **Step 7: Seed today and tomorrow in production**

`publishDay` only writes tomorrow's, so today's has to be put there once:

```bash
cd server/functions && npx firebase functions:shell --project peeplet-daily <<'EOF'
publishDay()
EOF
cd ../..
```

Then confirm in the console that `days/<tomorrow>/turns/guess_number` exists, and write today's by the same route as Step 4 if it is missing.

- [ ] **Step 8: Commit**

```bash
git add server/functions/src/index.ts
git commit -m "$(cat <<'MSG'
feat(server): publish, submit and the rolled-up tally

Three functions. publishDay writes tomorrow's content a day ahead, so a
missed night is not a blank day. submitTurn verifies the player's id token,
writes their submit once -- a repeat answers with what is already stored
rather than an error, which is what makes the client's retry and its offline
flush safe -- and increments one bucket of one shard. rollupTally merges the
shards into the single document a client reads.

Shards exist because a Firestore document takes about one write a second and
a popular day would pass that; ten give ten, and the client still reads one
document. They hold plain numeric fields rather than this codebase's usual
single json string, because FieldValue.increment cannot reach inside a
string and nothing but these functions ever reads them.

The day's content is derived with FNV-1a over the day key, which core/daily.gd
computes identically, so a phone that has never reached the network plays the
same day as the one that was published.

Driven end to end against the emulator suite: publish, sign up anonymously,
submit, submit again and see the first score kept, roll up, read the tally.
MSG
)"
```

---

### Task 4: `core/backend.gd`

**Files:**
- Create: `core/backend.gd`
- Modify: `core/daily.gd` (add `fnv1a`)
- Modify: `world/main.gd` (start it)
- Create: `tools/_backend_probe.gd` (throwaway harness, committed so the check is repeatable)

**Interfaces:**
- Consumes: the endpoints and document shapes from Task 3.
- Produces:
  - `Daily.fnv1a(s: String) -> int`
  - `Backend.start(host: Node) -> void`, `Backend.started() -> bool`, `Backend.stop() -> void`, `Backend.uid() -> String`
  - `await Backend.day_content(game: String, date_key: int) -> Dictionary` → `{ok: bool, data: Dictionary, error: String}`
  - `await Backend.tally(game: String, date_key: int) -> Dictionary` → `{ok: bool, data: Dictionary, error: String}` where `data` is `{count, histogram, byLocale}`
  - `await Backend.submit(game: String, date_key: int, payload: Dictionary) -> Dictionary` with `payload` `{score: int, guess: Variant, locale: String}`
  - `Backend.percentile(tally_data: Dictionary, score: int) -> int` — 0..100, or `-1` when the crowd is empty

- [ ] **Step 1: Add the shared hash to `core/daily.gd`**

Append to `core/daily.gd`:

```gdscript
## FNV-1a, 32 bit. server/functions/src/index.ts computes the same hash over
## the same string, so a phone that has never reached the network derives the
## same day's content as the one that was published.
static func fnv1a(s: String) -> int:
	var h := 0x811c9dc5
	for b in s.to_utf8_buffer():
		h ^= b
		h = (h * 0x01000193) & 0xFFFFFFFF
	return h
```

- [ ] **Step 2: Check it agrees with the server's**

```bash
cat > /tmp/fnv_check.gd <<'EOF'
extends SceneTree
func _initialize() -> void:
	var Daily = load("res://core/daily.gd")
	for s in ["guess_number|20260917", "guess_number|20260918", ""]:
		print("%s -> %d" % [s, Daily.fnv1a(s)])
	quit(0)
EOF
cp /tmp/fnv_check.gd tests/_fnv_check.gd
godot --headless --path . --script res://tests/_fnv_check.gd
rm tests/_fnv_check.gd
node -e '
function fnv1a(s){let h=0x811c9dc5;for(let i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,0x01000193)>>>0;}return h>>>0;}
for (const s of ["guess_number|20260917","guess_number|20260918",""]) console.log(s,"->",fnv1a(s));
'
```

Expected: the three numbers match line for line. `""` must give `2166136261`.

- [ ] **Step 3: Write `core/backend.gd`**

Substitute the real web API key from Task 2 Step 2 and the real region from Task 3 Step 6.

```gdscript
extends RefCounted

## The game's one way to the backend: an anonymous identity, the day's
## content, the crowd's tally and a player's submit. Modelled on
## core/analytics.gd -- static, woken by world/main.gd and nobody else.
##
## Unstarted means offline. Every call then answers from the cache on disk or
## from content bundled in res://, so the suite and the harnesses build these
## same screens without ever reaching the network. That is why this is not an
## autoload, exactly as with Analytics.
##
## Nothing here ever blocks a frame, and in particular nothing blocks Lock:
## a turn grades against whatever is in hand and the crowd number catches up
## on the next read.
## Spec: docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md,
## section 3.

const PROJECT := "peeplet-daily"
## A public client key, the same kind that sits in every Firebase web app.
const API_KEY := "PASTE_WEB_API_KEY_HERE"
const REGION := "us-central1"

const CACHE_DIR := "user://backend_cache"
const PLAYER_PATH := "user://player.cfg"
const QUEUE_PATH := "user://backend_queue.json"
const TIMEOUT := 5.0
## Renew the id token when less than this is left on it.
const RENEW_MARGIN := 300.0
## Content bundled with the game, so a phone that has never been online plays.
const BUNDLED := "res://content/%s.json"

static var _node: Node = null
static var _uid := ""
static var _refresh_token := ""
static var _id_token := ""
static var _expires_at := 0.0
## Set from FIREBASE_EMULATOR ("127.0.0.1") to point every host at the suite.
static var _emulator := ""

# --- lifecycle ---

## Wakes the backend under `host`, which must be in the tree. Signs in,
## flushes anything the last run could not send, and warms the cache.
static func start(host: Node) -> void:
	if started():
		return
	_emulator = OS.get_environment("FIREBASE_EMULATOR").strip_edges()
	var n := Node.new()
	n.name = "Backend"
	host.add_child(n)
	_node = n
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	_load_player()
	if await _ensure_token():
		await _flush_queue()

static func started() -> bool:
	return _node != null and is_instance_valid(_node)

## Silences the backend again. Harnesses that build the real main scene call
## this so a probe run never submits.
static func stop() -> void:
	if started():
		_node.queue_free()
	_node = null
	_id_token = ""
	_expires_at = 0.0

static func uid() -> String:
	return _uid

# --- hosts ---

static func _host(which: String) -> String:
	if _emulator.is_empty():
		match which:
			"firestore": return "https://firestore.googleapis.com/v1"
			"identity": return "https://identitytoolkit.googleapis.com/v1"
			"securetoken": return "https://securetoken.googleapis.com/v1"
			"functions": return "https://%s-%s.cloudfunctions.net" % [REGION, PROJECT]
	else:
		match which:
			"firestore": return "http://%s:8080/v1" % _emulator
			"identity": return "http://%s:9099/identitytoolkit.googleapis.com/v1" % _emulator
			"securetoken": return "http://%s:9099/securetoken.googleapis.com/v1" % _emulator
			"functions": return "http://%s:5001/%s/%s" % [_emulator, PROJECT, REGION]
	return ""

static func _docs() -> String:
	return "%s/projects/%s/databases/(default)/documents" % [_host("firestore"), PROJECT]

# --- identity ---

static func _load_player() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PLAYER_PATH)  # a missing file is fine
	_uid = str(cfg.get_value("player", "uid", ""))
	_refresh_token = str(cfg.get_value("player", "refresh_token", ""))

static func _save_player() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PLAYER_PATH)
	cfg.set_value("player", "uid", _uid)
	cfg.set_value("player", "refresh_token", _refresh_token)
	cfg.save(PLAYER_PATH)

## A live id token, signing up or refreshing as needed. False means the game
## runs offline this launch and tries again on the next.
static func _ensure_token() -> bool:
	if not _id_token.is_empty() and Time.get_unix_time_from_system() < _expires_at - RENEW_MARGIN:
		return true
	if not _refresh_token.is_empty() and await _refresh():
		return true
	return await _sign_up()

static func _sign_up() -> bool:
	var res := await _http("%s/accounts:signUp?key=%s" % [_host("identity"), API_KEY],
		HTTPClient.METHOD_POST, ["Content-Type: application/json"],
		JSON.stringify({"returnSecureToken": true}))
	var d = JSON.parse_string(str(res.body))
	if not res.ok or typeof(d) != TYPE_DICTIONARY:
		return false
	_uid = str(d.get("localId", ""))
	_refresh_token = str(d.get("refreshToken", ""))
	_id_token = str(d.get("idToken", ""))
	_expires_at = Time.get_unix_time_from_system() + float(str(d.get("expiresIn", "3600")))
	_save_player()
	return not _uid.is_empty()

static func _refresh() -> bool:
	var body := "grant_type=refresh_token&refresh_token=%s" % _refresh_token.uri_encode()
	var res := await _http("%s/token?key=%s" % [_host("securetoken"), API_KEY],
		HTTPClient.METHOD_POST,
		["Content-Type: application/x-www-form-urlencoded"], body)
	var d = JSON.parse_string(str(res.body))
	if not res.ok or typeof(d) != TYPE_DICTIONARY:
		# A rejected refresh token is dead; drop it so the next call signs up.
		_refresh_token = ""
		return false
	_uid = str(d.get("user_id", _uid))
	_refresh_token = str(d.get("refresh_token", _refresh_token))
	_id_token = str(d.get("id_token", ""))
	_expires_at = Time.get_unix_time_from_system() + float(str(d.get("expires_in", "3600")))
	_save_player()
	return not _id_token.is_empty()

# --- the three calls ---

## The day's content. Answers from the cache at once when it has one and
## refreshes behind the caller; only a cold cache waits on the network, and a
## cold cache with no network falls back to what is bundled in res://.
static func day_content(game: String, date_key: int) -> Dictionary:
	var cached := _read_cache(game, date_key, "content")
	if not cached.is_empty():
		_fetch(game, date_key, "content")  # deliberately not awaited
		return {"ok": true, "data": cached, "error": ""}
	var got := await _fetch(game, date_key, "content")
	if got.ok:
		return got
	return {"ok": false, "data": bundled(game), "error": got.error}

## The crowd so far: {count, histogram, byLocale}. Always asks the network
## when there is one, because this is the number that moves.
static func tally(game: String, date_key: int) -> Dictionary:
	var got := await _fetch(game, date_key, "tally")
	if got.ok:
		return got
	var cached := _read_cache(game, date_key, "tally")
	if not cached.is_empty():
		return {"ok": true, "data": cached, "error": "cache"}
	return {"ok": false, "data": {}, "error": got.error}

## Records this player's turn. The submit is queued first and then sent, so a
## failure leaves it on disk for the next launch; the server keys on
## uid + day + game, which makes a double flush harmless.
static func submit(game: String, date_key: int, payload: Dictionary) -> Dictionary:
	_queue_push({
		"game": game,
		"day": date_key,
		"score": int(payload.get("score", 0)),
		"guess": payload.get("guess"),
		"locale": str(payload.get("locale", "en")),
	})
	return await _flush_queue()

## Where `score` stands in the day's crowd: the share of players it beats,
## 0 to 100, or -1 when there is no crowd yet. Computed here rather than
## asked of the server, so the reveal costs no round trip and survives
## offline (spec 3.4).
static func percentile(data: Dictionary, score: int) -> int:
	var hist = data.get("histogram", [])
	var total := int(data.get("count", 0))
	if total <= 0 or typeof(hist) != TYPE_ARRAY or hist.is_empty():
		return -1
	var below := 0
	for i in mini(hist.size(), maxi(score, 0)):
		below += int(hist[i])
	return int(round(100.0 * float(below) / float(total)))

# --- fetching and caching ---

static func _path_for(game: String, date_key: int, what: String) -> String:
	if what == "tally":
		return "days/%d/turns/%s/tally/current" % [date_key, game]
	return "days/%d/turns/%s" % [date_key, game]

## GETs one document and unwraps its single `json` field. Firestore's REST
## API answers in typed values, and every document this game reads carries
## exactly one string field, which is what keeps that from becoming a decoder.
static func _fetch(game: String, date_key: int, what: String) -> Dictionary:
	if not started() or not await _ensure_token():
		return {"ok": false, "data": {}, "error": "offline"}
	var res := await _http("%s/%s" % [_docs(), _path_for(game, date_key, what)],
		HTTPClient.METHOD_GET, ["Authorization: Bearer %s" % _id_token], "")
	if not res.ok:
		return {"ok": false, "data": {}, "error": str(res.error)}
	var doc = JSON.parse_string(str(res.body))
	if typeof(doc) != TYPE_DICTIONARY:
		return {"ok": false, "data": {}, "error": "bad document"}
	var fields = doc.get("fields", {})
	var raw = fields.get("json", {}).get("stringValue", "") if typeof(fields) == TYPE_DICTIONARY else ""
	var parsed = JSON.parse_string(str(raw))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "data": {}, "error": "bad payload"}
	_write_cache(game, date_key, what, parsed)
	return {"ok": true, "data": parsed, "error": ""}

static func _cache_file(game: String, date_key: int, what: String) -> String:
	return "%s/%s-%d-%s.json" % [CACHE_DIR, game, date_key, what]

static func _read_cache(game: String, date_key: int, what: String) -> Dictionary:
	var path := _cache_file(game, date_key, what)
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if typeof(d) == TYPE_DICTIONARY else {}

static func _write_cache(game: String, date_key: int, what: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var f := FileAccess.open(_cache_file(game, date_key, what), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))

## The copy shipped in the build, for a phone that has never been online.
static func bundled(game: String) -> Dictionary:
	var path := BUNDLED % game
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if typeof(d) == TYPE_DICTIONARY else {}

# --- the offline queue ---

static func _queue_read() -> Array:
	if not FileAccess.file_exists(QUEUE_PATH):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(QUEUE_PATH))
	return d if typeof(d) == TYPE_ARRAY else []

static func _queue_write(items: Array) -> void:
	var f := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(items))

static func _queue_push(item: Dictionary) -> void:
	var items := _queue_read()
	for existing in items:
		if existing.get("game") == item.game and int(existing.get("day", 0)) == item.day:
			return  # already waiting; one submit per game per day
	items.append(item)
	_queue_write(items)

## Sends everything waiting, keeping whatever would not go. Answers with the
## result for the item that was just pushed, or an offline verdict.
static func _flush_queue() -> Dictionary:
	var items := _queue_read()
	if items.is_empty():
		return {"ok": true, "data": {}, "error": ""}
	if not started() or not await _ensure_token():
		return {"ok": false, "data": {}, "error": "offline"}
	var kept: Array = []
	var last := {"ok": false, "data": {}, "error": "offline"}
	for item in items:
		var res := await _http("%s/submitTurn" % _host("functions"),
			HTTPClient.METHOD_POST,
			["Content-Type: application/json", "Authorization: Bearer %s" % _id_token],
			JSON.stringify(item))
		if res.ok:
			var d = JSON.parse_string(str(res.body))
			last = {"ok": true, "data": d if typeof(d) == TYPE_DICTIONARY else {}, "error": ""}
		elif int(res.code) >= 400 and int(res.code) < 500 and int(res.code) != 429:
			# The server will never accept this one; dropping it beats
			# retrying it every launch forever.
			last = {"ok": false, "data": {}, "error": str(res.error)}
		else:
			kept.append(item)
			last = {"ok": false, "data": {}, "error": str(res.error)}
	_queue_write(kept)
	return last

# --- one request ---

static func _http(url: String, method: int, headers: PackedStringArray, body: String) -> Dictionary:
	if not started():
		return {"ok": false, "code": 0, "body": "", "error": "offline"}
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	_node.add_child(req)
	if req.request(url, headers, method, body) != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "body": "", "error": "request failed"}
	var out: Array = await req.request_completed
	req.queue_free()
	var code := int(out[1])
	var text := (out[3] as PackedByteArray).get_string_from_utf8()
	return {
		"ok": code >= 200 and code < 300,
		"code": code,
		"body": text,
		"error": "" if code >= 200 and code < 300 else "HTTP %d" % code,
	}
```

- [ ] **Step 4: Start it from `world/main.gd`**

Add the preload beside the others and the call in `_ready`, after `Analytics.start`:

```gdscript
const Backend = preload("res://core/backend.gd")
```

```gdscript
func _ready() -> void:
	Analytics.start(self)
	Analytics.track("game_open", {"day": Progress.day()})
	# The backend wakes here and nowhere else, same as telemetry: the suite
	# and the harnesses build these screens and stay offline.
	Backend.start(self)
```

`Backend.start` is a coroutine; calling it without `await` is deliberate — the launch does not wait on the network.

- [ ] **Step 5: Write the throwaway probe**

`tools/_backend_probe.gd`. It is committed so the check can be repeated, but it is a harness, not a suite entry — do not add it to `tests/run_tests.gd`.

```gdscript
extends SceneTree

## Drives core/backend.gd against the Firebase emulator suite and prints what
## came back. Not a test: a harness, for reading with your eyes.
##
##   cd server && firebase emulators:start --only auth,firestore,functions &
##   FIREBASE_EMULATOR=127.0.0.1 godot --headless --path . \
##     --script res://tools/_backend_probe.gd

const Backend = preload("res://core/backend.gd")
const DailySeed = preload("res://core/daily.gd")

var _done := false

func _process(_delta: float) -> bool:
	if not _done:
		_done = true
		_run()
	return false

func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	await Backend.start(host)
	print("started=%s uid=%s" % [Backend.started(), Backend.uid()])
	var day := DailySeed.date_key()

	var content := await Backend.day_content("guess_number", day)
	print("content ok=%s error=%s data=%s" % [content.ok, content.error, content.data])

	var sent := await Backend.submit("guess_number", day,
		{"score": 73, "guess": 30, "locale": "es"})
	print("submit ok=%s error=%s data=%s" % [sent.ok, sent.error, sent.data])

	var crowd := await Backend.tally("guess_number", day)
	print("tally ok=%s error=%s data=%s" % [crowd.ok, crowd.error, crowd.data])
	print("percentile(73)=%d" % Backend.percentile(crowd.data, 73))
	quit(0)
```

- [ ] **Step 6: Run the probe against the emulator**

With the emulators from Task 3 still running, and today's content present:

```bash
rm -rf ~/Library/Application\ Support/Godot/app_userdata/Daily/backend_cache \
       ~/Library/Application\ Support/Godot/app_userdata/Daily/player.cfg \
       ~/Library/Application\ Support/Godot/app_userdata/Daily/backend_queue.json
FIREBASE_EMULATOR=127.0.0.1 godot --headless --path . --script res://tools/_backend_probe.gd
```

Expected, in order: `started=true` with a non-empty uid; `content ok=true` with the `answer` you published; `submit ok=true` with `created:true`; `tally ok=true`. `percentile` may be `-1` until `rollupTally()` has been called again from the functions shell — call it and re-run to see a real number.

- [ ] **Step 7: Prove the offline path**

```bash
# No emulator host and no network path: every call must fall back, not hang.
rm -f ~/Library/Application\ Support/Godot/app_userdata/Daily/backend_queue.json
FIREBASE_EMULATOR=127.0.0.1 godot --headless --path . --script res://tools/_backend_probe.gd
# ^ with the emulators STOPPED this time
cat ~/Library/Application\ Support/Godot/app_userdata/Daily/backend_queue.json
```

Expected: the run finishes inside about fifteen seconds rather than hanging, `submit ok=false error=...`, and the queue file holds the one pending submit. Restart the emulators and run once more: the queue flushes and the file is left as `[]`.

- [ ] **Step 8: Confirm the suite is still silent and green**

`Backend` must never be started by a test.

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3
```

Expected: the Task 1 baseline, `failed=0`.

- [ ] **Step 9: Commit**

```bash
git add core/backend.gd core/backend.gd.uid core/daily.gd world/main.gd tools/_backend_probe.gd tools/_backend_probe.gd.uid
git commit -m "$(cat <<'MSG'
feat(core): the client's one way to the backend

core/backend.gd: an anonymous Firebase identity over the Identity Toolkit
REST API, the day's content and the crowd's tally read straight from
Firestore's REST API, and a submit posted to the one function that writes.
Static and woken by world/main.gd alone, exactly like telemetry -- unstarted
means offline, which is how the suite and the harnesses build these screens
without ever reaching the network, and why neither is an autoload.

Every document it reads carries a single json field, which is what keeps
Firestore's typed values from becoming a decoder here. The percentile is
computed from the histogram on the device rather than asked of the server:
no round trip on the reveal, and it still works on a phone that has been
offline since the morning.

A submit is written to the queue before it is sent, so a failure leaves it
for the next launch; the server keys on uid, day and game, so a double flush
is harmless. Nothing waits on the network: every request times out in five
seconds and a cold cache falls back to the content bundled in res://.

Daily.fnv1a matches the server's hash byte for byte, checked against node.
tools/_backend_probe.gd drives the whole path against the emulator suite and
prints what came back; it is a harness for reading, not a suite entry.
MSG
)"
```

---

### Task 5: `TurnBase` and `TurnHost`

**Files:**
- Create: `core/turn_base.gd`
- Create: `ui/turn_host.gd`

**Interfaces:**
- Consumes: `StageView` (Task 1); `Backend.day_content`, `Backend.tally`, `Backend.submit`, `Backend.percentile` (Task 4).
- Produces:
  - `core/turn_base.gd`: `enum State {INPUT, LOCKED, REVEALED}`, `state: int`, `elapsed: float`, `score: int`, `content: Dictionary`, signals `locked`, `revealed`, `graded(score: int)`, `input_changed`; overridables `turn_id() -> String`, `title() -> String`, `motto() -> String`, `footer() -> String`, `prompt_text() -> String`, `build_turn(content: Dictionary) -> void`, `has_input() -> bool`, `guess() -> Variant`, `grade(answer) -> int`, `reveal() -> void`, `share_text() -> String`, `share_glyphs() -> String`; given `start_turn(content: Dictionary) -> void`, `lock() -> void`, `is_done() -> bool`.
  - `ui/turn_host.gd`: `setup(entry: Dictionary) -> void`, `signal closed`.

- [ ] **Step 1: Write `core/turn_base.gd`**

```gdscript
extends StageView

## One committed input a day, an immediate reveal, and a graded result.
## Never a pass or a fail: a bad day still produces a number and a picture
## worth posting.
##
## Deliberately not a PuzzleBase. A turn has no moves, no hints, no checks
## and nothing to undo, and inheriting that vocabulary would hand the
## mismatch to every game built on this.
## Spec: docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md,
## section 2.2.

signal locked
signal revealed
signal graded(score: int)
## The player changed what they are about to commit; the host re-reads.
signal input_changed

enum State { INPUT, LOCKED, REVEALED }

var state: int = State.INPUT
var elapsed: float = 0.0
## -1 until the turn has been graded.
var score: int = -1
var content: Dictionary = {}

# --- to override ---
func turn_id() -> String: return "unnamed"
func title() -> String: return "Untitled"
func motto() -> String: return ""
func footer() -> String: return ""
## The day's question, already localised by the subclass.
func prompt_text() -> String: return ""
## Stand the scene from the day's content. Called once, before the first frame.
func build_turn(_content: Dictionary) -> void: pass
## Whether the player has committed enough for Lock to light up.
func has_input() -> bool: return false
## What the player committed, as it goes to the server.
func guess() -> Variant: return null
## 0 to 100. Never negative, never a fail.
func grade(_answer) -> int: return 0
## The camera move and the comparison. Runs once, on lock.
func reveal() -> void: pass
func share_text() -> String: return ""
func share_glyphs() -> String: return ""
# -------------------

func _ready() -> void:
	stage_enter("%s_turn" % turn_id())

func _exit_tree() -> void:
	stage_exit()

## A turn stops taking input the instant it is locked.
func accepts_input() -> bool:
	return state == State.INPUT

func is_done() -> bool:
	return state != State.INPUT

## Stands the turn up from the day's content.
func start_turn(the_content: Dictionary) -> void:
	content = the_content
	state = State.INPUT
	elapsed = 0.0
	score = -1
	build_turn(content)
	set_process(true)

func _process(delta: float) -> void:
	if state == State.INPUT:
		elapsed += delta

## One way, once. There is no undo on a turn.
func lock() -> void:
	if state != State.INPUT:
		return
	state = State.LOCKED
	locked.emit()
	reveal()
	state = State.REVEALED
	revealed.emit()
	score = clampi(grade(content.get("answer")), 0, 100)
	graded.emit(score)

## Puts a turn straight into its revealed state, for a day already played.
func restore(the_content: Dictionary, the_score: int) -> void:
	content = the_content
	build_turn(content)
	state = State.REVEALED
	score = clampi(the_score, 0, 100)
	reveal()
```

- [ ] **Step 2: Write `ui/turn_host.gd`**

```gdscript
extends Control

## Shell around any TurnBase: the concept HUD's top bar and day card, the
## turn's prompt, the stage slot, one Lock button, and the graded reveal.
## The sibling of ui/puzzle_host.gd, and it reuses that screen's furniture so
## a turn and a board feel like the same game.
##
## A turn is played once a day. Opening a day already played shows the stored
## result with a refreshed crowd number, never the input again.
## Spec: docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md,
## section 2.3.

signal closed

const Pal = preload("res://core/palette.gd")
const DailySeed = preload("res://core/daily.gd")
const Progress = preload("res://core/progress.gd")
const Analytics = preload("res://core/analytics.gd")
const Backend = preload("res://core/backend.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const TopBar = preload("res://ui/hud/top_bar.gd")
const DayCard = preload("res://ui/hud/day_card.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")

const MARGIN := 40
const GAP := 20
const ENTER_TOP := 0.0
const ENTER_CARDS := 0.1
const ENTER_ACTIONS := 0.2
## Where a played day is remembered, so reopening shows the result.
const PLAYED_PATH := "user://turns.cfg"

var _entry: Dictionary
var _turn: Control
var _day: int = 0

var top_bar: Control
var day_card: Control
var prompt: Label
var lock_button: Button
var reveal_panel: PanelContainer
var score_bar: ProgressBar
var score_label: Label
var crowd_label: Label
var share_button: Button
var settings_sheet: Control
var _slot: Control

func setup(entry: Dictionary) -> void:
	_entry = entry

func _ready() -> void:
	theme = CozyTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_day = DailySeed.date_key()
	_build()
	Progress.touch()
	day_card.set_day(Progress.day(), Progress.island_name())
	_enter()
	_open_turn()

func _build() -> void:
	var insets := SafeArea.insets(self)
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

	top_bar = TopBar.new(_entry.get("title", ""), _entry.get("motto", ""))
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	root.add_child(top_bar)

	day_card = DayCard.new()
	day_card.name = "DayCard"
	root.add_child(day_card)

	prompt = Label.new()
	prompt.name = "Prompt"
	prompt.theme_type_variation = "CardBody"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(prompt)

	_slot = Control.new()
	_slot.name = "Slot"
	_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_slot)

	lock_button = IconButton.new("check", "Lock", "PrimaryButton")
	lock_button.name = "Lock"
	lock_button.custom_minimum_size.y = 110
	lock_button.pressed.connect(_on_lock)
	root.add_child(lock_button)

	_build_reveal(root)

	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)

func _build_reveal(root: Control) -> void:
	reveal_panel = PanelContainer.new()
	reveal_panel.name = "Reveal"
	reveal_panel.add_theme_stylebox_override("panel", CozyTheme.paper_card())
	reveal_panel.visible = false
	root.add_child(reveal_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	reveal_panel.add_child(col)
	score_label = Label.new()
	score_label.theme_type_variation = "CardTitle"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(score_label)
	score_bar = ProgressBar.new()
	score_bar.min_value = 0
	score_bar.max_value = 100
	score_bar.show_percentage = false
	score_bar.custom_minimum_size.y = 28
	col.add_child(score_bar)
	crowd_label = Label.new()
	crowd_label.theme_type_variation = "CardBody"
	crowd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(crowd_label)
	share_button = IconButton.new("chevron_right", "Share", "IconButton")
	share_button.custom_minimum_size.y = 96
	share_button.pressed.connect(_on_share)
	col.add_child(share_button)

func _enter() -> void:
	top_bar.enter(ENTER_TOP)
	day_card.enter(ENTER_CARDS)
	Motion.appear(prompt, 0.0, 1.0, 0.25, ENTER_CARDS)
	Motion.appear(lock_button, 0.0, 1.0, 0.25, ENTER_ACTIONS)

## Reads the day, stands the turn up, and shows either the input or the
## result the player already committed.
func _open_turn() -> void:
	var game: String = str(_entry.get("id", ""))
	var got := await Backend.day_content(game, _day)
	var content: Dictionary = got.data if got.data is Dictionary else {}
	var script: GDScript = load(_entry.script)
	_turn = script.new()
	_turn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot.add_child(_turn)
	_turn.input_changed.connect(_refresh)
	_turn.graded.connect(_on_graded)
	prompt.text = _turn.prompt_text()

	var played := _played_score(game)
	if played >= 0:
		_turn.restore(content, played)
		await _show_result(played, false)
	else:
		_turn.start_turn(content)
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(_turn):
		return
	lock_button.visible = not _turn.is_done()
	lock_button.set_enabled(_turn.has_input())

func _on_lock() -> void:
	if not is_instance_valid(_turn) or _turn.is_done():
		return
	_turn.lock()

func _on_graded(the_score: int) -> void:
	var game: String = str(_entry.get("id", ""))
	_remember(game, the_score)
	Analytics.track("turn_lock", {
		"turn_id": game, "day": Progress.day(),
		"score": the_score, "seconds": _turn.elapsed,
	})
	await _show_result(the_score, true)
	Analytics.track("turn_reveal", {"turn_id": game, "score": the_score})

## Shows the graded panel and the crowd's verdict. `send` is false when the
## day was already played and we are only refreshing the number.
func _show_result(the_score: int, send: bool) -> void:
	var game: String = str(_entry.get("id", ""))
	lock_button.visible = false
	reveal_panel.visible = true
	score_label.text = "%d / 100" % the_score
	score_bar.value = the_score
	crowd_label.text = "…"
	Motion.appear(reveal_panel, 0.0, 1.0, 0.3, 0.0)
	if send:
		await Backend.submit(game, _day, {
			"score": the_score, "guess": _turn.guess(),
			"locale": TranslationServer.get_locale().substr(0, 2),
		})
	var crowd := await Backend.tally(game, _day)
	if not is_instance_valid(crowd_label):
		return
	var pct := Backend.percentile(crowd.data, the_score)
	crowd_label.text = "Closer than %d%% of players" % pct if pct >= 0 \
		else "You are the first today"
	Analytics.track("crowd_reveal_opened", {"turn_id": game, "count": int(crowd.data.get("count", 0))})

func _on_share() -> void:
	var text := "%s\n%s" % [_turn.share_text(), _turn.share_glyphs()]
	DisplayServer.clipboard_set(text)
	Analytics.track("turn_share", {"turn_id": str(_entry.get("id", ""))})

func _on_back() -> void:
	closed.emit()

# --- the day already played ---

static func _played_score(game: String) -> int:
	var cfg := ConfigFile.new()
	cfg.load(PLAYED_PATH)
	return int(cfg.get_value(game, str(DailySeed.date_key()), -1))

static func _remember(game: String, the_score: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PLAYED_PATH)
	cfg.set_value(game, str(DailySeed.date_key()), the_score)
	cfg.save(PLAYED_PATH)
```

- [ ] **Step 3: Check both files parse**

Nothing instantiates them yet; a parse error is the only thing to catch here.

```bash
godot --headless --path . --import 2>&1 | grep -i -E 'turn_base|turn_host|error|parse' | head
```

Expected: no error lines.

- [ ] **Step 4: Confirm `IconButton.set_enabled` and `TopBar`'s signals exist**

The host calls `lock_button.set_enabled(...)`, `top_bar.back`, `top_bar.settings`, `top_bar.enter(...)`, `day_card.set_day(...)`, `day_card.enter(...)` and `CozyTheme.paper_card()`. Confirm each before running:

```bash
grep -n 'func set_enabled\|func enter\|signal ' ui/hud/icon_button.gd ui/hud/top_bar.gd ui/hud/day_card.gd
grep -n 'static func paper_card' ui/theme.gd
```

Expected: every one of them is found. If `IconButton.new(icon, label, variation)` has a different signature, match the call sites already in `ui/hud/settings_sheet.gd`.

- [ ] **Step 5: Suite still green**

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3
```

- [ ] **Step 6: Commit**

```bash
git add core/turn_base.gd core/turn_base.gd.uid ui/turn_host.gd ui/turn_host.gd.uid
git commit -m "$(cat <<'MSG'
feat(core): the turn, and the shell it is played in

core/turn_base.gd stands on StageView beside the puzzles: one committed
input, an immediate reveal, a graded result, and never a pass or a fail. The
state only moves forwards, INPUT to LOCKED to REVEALED, and accepts_input is
false the instant Lock is pressed, so the stage base does the freezing. It is
deliberately not a PuzzleBase -- a turn has no moves, no hints, no checks and
nothing to undo, and inheriting that vocabulary would hand the mismatch to
every game built on this.

ui/turn_host.gd is the sibling of puzzle_host.gd and reuses its furniture, so
a turn and a board feel like the same game: the same top bar, the same day
card, the same margins and the same staggered entrance. What differs is that
the action bar is one Lock button and the solved overlay is a graded panel --
the score out of a hundred and where it stands in the crowd.

A turn is played once a day. The score is remembered in user://turns.cfg, so
reopening the card shows the result with a refreshed crowd number rather than
the input again. Nothing waits on the network to grade: the submit and the
tally are awaited after the panel is already on screen.
MSG
)"
```

---

### Task 6: The stub turn, on the menu

**Files:**
- Create: `turns/guess_number.gd`
- Create: `content/guess_number.json`
- Modify: `ui/registry.gd` (a `kind` on every entry, plus the new one)
- Modify: `ui/menu.gd` (`_open` routes on `kind`)
- Modify: `ui/hud/card_scene.gd` (one builder)

**Interfaces:**
- Consumes: `TurnBase` and `TurnHost` (Task 5), `Daily.fnv1a` (Task 4).
- Produces: registry entry `{"id": "guess_number", "kind": "turn", ...}` and a playable turn.

- [ ] **Step 1: Write the stub turn**

`turns/guess_number.gd`. Throwaway — it is deleted when How Big? lands — but it must exercise the real path: content, drag picking on the stage, grading, reveal.

```gdscript
extends "res://core/turn_base.gd"

## The phase 0 stub. The day publishes a number from 0 to 100; a row of pegs
## is the dial, dragged along to set a guess, and the reveal raises the true
## answer's peg beside it. Deleted when How Big? lands in phase 1 -- it exists
## to prove publish, read, play, grade, submit, roll up and re-read.

const Models = preload("res://core/models.gd")
const Scenery = preload("res://world/scenery.gd")
const Toon = preload("res://core/toon.gd")
const Pal = preload("res://core/palette.gd")
const DailySeed = preload("res://core/daily.gd")

## The dial is ten pegs wide; a guess of 100 fills all ten.
const PEGS := 10
const RAISE := 0.45

var value: int = 50
var _pegs: Array[Node3D] = []
var _answer_peg: Node3D

func turn_id() -> String: return "guess_number"
func title() -> String: return "Guess"
func motto() -> String: return "One number, one go"
func footer() -> String: return "Guess · Lock · Reveal"
func prompt_text() -> String: return "What number is the camp thinking of, 0 to 100?"

func board_size() -> Vector2i: return Vector2i(PEGS, 1)
func board_height() -> float: return 1.0
func plane_height() -> float: return 0.0
func board_margin() -> float: return 0.5

func has_input() -> bool: return true
func guess() -> Variant: return value

## The published answer, or the same number derived from the day when the
## phone has never reached the network. Both sides use the same hash.
func _answer() -> int:
	if content.has("answer"):
		return clampi(int(content.answer), 0, 100)
	return DailySeed.fnv1a("guess_number|%d" % DailySeed.date_key()) % 101

func build_turn(_content: Dictionary) -> void:
	for i in PEGS:
		var pivot := Scenery.prop("peg", _at(i), 0.0, Vector3.ONE)
		board.add_child(pivot)
		_pegs.append(pivot.get_child(0))
	_paint()

static func _at(i: int) -> Vector3:
	return Vector3(i - (PEGS - 1) * 0.5, 0.0, 0.0)

## A drag anywhere along the row sets the guess from its x.
func on_board_press(hit: Vector3) -> void:
	_set_from(hit)

func on_board_drag(hit: Vector3) -> void:
	_set_from(hit)

func _set_from(hit: Vector3) -> void:
	var t := (hit.x + (PEGS - 1) * 0.5) / float(PEGS - 1)
	var next := clampi(int(round(t * 100.0)), 0, 100)
	if next == value:
		return
	value = next
	_paint()
	input_changed.emit()

## Pegs up to the guess stand raised and warm; the rest sit flat and pale.
func _paint() -> void:
	var lit := int(round(value / 100.0 * PEGS))
	for i in _pegs.size():
		var on := i < lit
		_pegs[i].position.y = RAISE if on else 0.0
		Models.tint_named(_pegs[i], "Peg", Pal.CAT[0] if on else Pal.PLOT_SOIL)

## The answer stands up as an eleventh peg, taller and in its own colour.
func reveal() -> void:
	var a := _answer()
	var x := (a / 100.0) * (PEGS - 1) - (PEGS - 1) * 0.5
	var pivot := Scenery.prop("peg", Vector3(x, 0.0, -1.2), 0.0, Vector3.ONE * 1.3)
	board.add_child(pivot)
	_answer_peg = pivot.get_child(0)
	Models.tint_named(_answer_peg, "Peg", Pal.CAT[2])

## 100 when exact, falling a point per unit away.
func grade(_answer_in) -> int:
	return clampi(100 - absi(value - _answer()), 0, 100)

func share_text() -> String:
	return "Guess %d — I said %d, it was %d" % [DailySeed.date_key(), value, _answer()]

func share_glyphs() -> String:
	var lit := int(round(grade(null) / 100.0 * PEGS))
	var out := ""
	for i in PEGS:
		out += "🟩" if i < lit else "⬜"
	return out
```

- [ ] **Step 2: Bundle the offline fallback**

`content/guess_number.json` — the prior only. The answer is derived from the day key by `_answer()` above, so there is nothing to ship for it.

```json
{
  "prior": { "mean": 50, "spread": 28 }
}
```

- [ ] **Step 3: Add `kind` to the registry**

In `ui/registry.gd`, add `"kind": "puzzle",` to each of the twelve existing entries, and append the turn as a thirteenth:

```gdscript
	{
		"id": "guess_number",
		"kind": "turn",
		"title": "Guess",
		"blurb": "One number, one go. How close can you land?",
		"motto": "One number, one go",
		"footer": "Guess · Lock · Reveal",
		"script": "res://turns/guess_number.gd",
		"difficulties": [0],
	},
```

Add the accessor below `find`:

```gdscript
## "puzzle" or "turn"; an entry without a kind is a puzzle, as all twelve
## were before turns existed.
static func kind(entry: Dictionary) -> String:
	return str(entry.get("kind", "puzzle"))
```

- [ ] **Step 4: Route the menu on `kind`**

In `ui/menu.gd`, add the preload beside `Host`:

```gdscript
const TurnHost = preload("res://ui/turn_host.gd")
```

and replace `_open`:

```gdscript
## A card opens either a board or a turn; the registry says which, and both
## hosts close the same way.
func _open(entry: Dictionary) -> void:
	var host: Control
	if Registry.kind(entry) == "turn":
		host = TurnHost.new()
		host.setup(entry)
	else:
		host = Host.new()
		host.setup(entry, 1)
	host.closed.connect(func():
		host.queue_free()
		_show_list()
	)
	add_child(host)
	_list_root.visible = false
	if _stage != null:
		_stage.unmount(camp)
```

- [ ] **Step 5: Give the card a picture**

In `ui/hud/card_scene.gd`, add to the `match id` block, above the `_:` fallback:

```gdscript
		"guess_number": _guess_number()
```

and the builder beside the others:

```gdscript
## Guess: the dial, a short row of pegs with the near ones raised.
func _guess_number() -> void:
	for i in 5:
		var peg := _put("peg", Vector3(i - 2.0, 0.6 if i < 3 else 0.0, 0.0))
		Models.tint_named(peg, "Peg", Pal.CAT[0] if i < 3 else Pal.PLOT_SOIL)
```

- [ ] **Step 6: Check the pieces the stub leans on actually exist**

The peg model, its tintable layer name and the palette entries are assumptions until checked.

```bash
grep -n '"peg"' core/models.gd | head
grep -n 'func tint_named\|func prop' core/models.gd world/scenery.gd
grep -n 'PLOT_SOIL\|const CAT' core/palette.gd
grep -rn 'tint_named(.*"Peg"' puzzles/ | head -3
```

Expected: `peg` is in `SLOTS`, `Models.tint_named` and `Scenery.prop` exist with the signatures used, `Pal.CAT` and `Pal.PLOT_SOIL` exist, and at least one puzzle already tints a layer literally called `Peg`. If the layer is named differently, use the name the puzzles use.

- [ ] **Step 7: Suite, then play it**

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3
godot --path . --resolution 540x960
```

Expected in the window: a thirteenth card, *Guess*, on page two of the menu, with a row of pegs as its picture. Opening it shows the prompt, the peg dial and a Lock button. Dragging across the pegs raises them; Lock replaces the button with the graded panel, the answer peg appears behind the dial, and the crowd line resolves to either a percentage or "You are the first today". Going back and reopening the card shows the same result and never the dial.

- [ ] **Step 8: Revert Godot's `project.godot` header and commit**

```bash
git checkout -- project.godot 2>/dev/null
git add turns content ui/registry.gd ui/menu.gd ui/hud/card_scene.gd
git commit -m "$(cat <<'MSG'
feat(turns): Guess, the throwaway that proves the whole path

A turn is a card in the camp grid like any puzzle, with its own live diorama;
the registry entries grow a kind and the menu routes on it, defaulting to
puzzle so the twelve boards are untouched.

Guess is the phase 0 stub and is deleted when How Big? lands. It is here to
exercise the path rather than to be good: the day publishes a number, a row
of pegs is the dial and is dragged through the stage's own picking, Lock
grades on distance, and the reveal stands the answer up behind the dial. Its
answer falls back to the same FNV-1a over the day key that the server
publishes, so a phone that has never been online plays the same day.
MSG
)"
```

---

### Task 7: Localisation

**Files:**
- Create: `core/locale.gd`, `locale/turn.csv`
- Modify: `project.godot` (register the translations)
- Modify: `ui/hud/settings_sheet.gd` (a language row)
- Modify: `turns/guess_number.gd`, `ui/turn_host.gd` (route their strings through keys)

**Interfaces:**
- Consumes: nothing.
- Produces: `Locale.current() -> String`, `Locale.set_current(code: String) -> void`, `Locale.number(n: float, decimals: int = 0) -> String`, `Locale.parse_number(s: String) -> float`, `Locale.CODES: Array[String]`.

- [ ] **Step 1: Write the strings**

`locale/turn.csv`. Godot imports a CSV whose first column is the key and whose header names the locales.

```csv
keys,en,pt,es
TURN_LOCK,Lock,Fechar,Cerrar
TURN_SHARE,Share,Partilhar,Compartir
TURN_SCORE,%d / 100,%d / 100,%d / 100
TURN_CROWD,Closer than %d%% of players,Mais perto do que %d%% dos jogadores,Más cerca que el %d%% de los jugadores
TURN_FIRST,You are the first today,És o primeiro hoje,Eres el primero hoy
TURN_LANGUAGE,Language,Idioma,Idioma
GUESS_TITLE,GUESS,ADIVINHA,ADIVINA
GUESS_MOTTO,One number one go,Um número uma vez,Un número una vez
GUESS_FOOTER,Guess · Lock · Reveal,Adivinha · Fecha · Revela,Adivina · Cierra · Revela
GUESS_PROMPT,"What number is the camp thinking of, 0 to 100?","Em que número está o acampamento a pensar, de 0 a 100?","¿En qué número está pensando el campamento, de 0 a 100?"
GUESS_BLURB,"One number, one go. How close can you land?","Um número, uma tentativa. Quão perto chegas?","Un número, un intento. ¿Qué tan cerca llegas?"
```

Note `GUESS_TITLE` is upper-case in all three: a carved sign upper-cases its title, and the accent check in Step 6 is exactly about what that does to Á and Ñ.

- [ ] **Step 2: Register the translations**

Add to `project.godot`, after the `[application]` block:

```
[internationalization]

locale/translations=PackedStringArray("res://locale/turn.en.translation", "res://locale/turn.pt.translation", "res://locale/turn.es.translation")
```

Then import so Godot generates the `.translation` files:

```bash
godot --headless --path . --import 2>&1 | tail -5
ls locale/
```

Expected: `turn.en.translation`, `turn.pt.translation`, `turn.es.translation` alongside the CSV.

- [ ] **Step 3: Write `core/locale.gd`**

```gdscript
class_name Locale
extends RefCounted

## Which of the three languages the game is speaking, and the number
## formatting that goes with it. Strings themselves go through
## TranslationServer (locale/turn.csv); this is the part TranslationServer
## does not do.
##
## Only the turn flow is keyed so far. The twelve boards keep their hardcoded
## English until their own pass.
## Spec: docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md,
## section 6.

const CODES: Array[String] = ["en", "pt", "es"]
const NAMES := {"en": "English", "pt": "Português", "es": "Español"}
const PATH := "user://player.cfg"

## The phone's language when it is one of ours, the saved override when there
## is one, English otherwise.
static func current() -> String:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	var saved := str(cfg.get_value("player", "locale", ""))
	if saved in CODES:
		return saved
	var sys := OS.get_locale_language()
	return sys if sys in CODES else "en"

## Applies `code` to TranslationServer and remembers it.
static func set_current(code: String) -> void:
	var c := code if code in CODES else "en"
	TranslationServer.set_locale(c)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("player", "locale", c)
	cfg.save(PATH)

## Reads the saved or detected language and applies it. Called once, from
## world/main.gd, before anything draws.
static func apply() -> void:
	TranslationServer.set_locale(current())

## A number as this language writes it: 1,234.5 in English, 1.234,5 in
## Portuguese and Spanish.
static func number(n: float, decimals: int = 0) -> String:
	var s := String.num(absf(n), decimals)
	var parts := s.split(".")
	var whole := parts[0]
	var grouped := ""
	for i in whole.length():
		if i > 0 and (whole.length() - i) % 3 == 0:
			grouped += " "
		grouped += whole[i]
	var thousands := "," if current() == "en" else "."
	var point := "." if current() == "en" else ","
	grouped = grouped.replace(" ", thousands)
	var out := grouped if parts.size() == 1 else "%s%s%s" % [grouped, point, parts[1]]
	return "-" + out if n < 0.0 else out

## The inverse: reads a number written in any of the three.
static func parse_number(s: String) -> float:
	var t := s.strip_edges().replace(" ", "")
	if current() == "en":
		t = t.replace(",", "")
	else:
		t = t.replace(".", "").replace(",", ".")
	return float(t)
```

- [ ] **Step 4: Apply it at launch and use the keys**

In `world/main.gd`, add the preload and call it in `_enter_tree`, before anything draws:

```gdscript
const Locale = preload("res://core/locale.gd")
```

```gdscript
func _enter_tree() -> void:
	Motion.load_settings()
	Locale.apply()
```

In `ui/turn_host.gd`, replace the four literals:

- `IconButton.new("check", "Lock", "PrimaryButton")` → `IconButton.new("check", tr("TURN_LOCK"), "PrimaryButton")`
- `IconButton.new("chevron_right", "Share", "IconButton")` → `IconButton.new("chevron_right", tr("TURN_SHARE"), "IconButton")`
- `score_label.text = "%d / 100" % the_score` → `score_label.text = tr("TURN_SCORE") % the_score`
- the crowd line → `tr("TURN_CROWD") % pct` and `tr("TURN_FIRST")`

In `turns/guess_number.gd`:

```gdscript
func title() -> String: return tr("GUESS_TITLE")
func motto() -> String: return tr("GUESS_MOTTO")
func footer() -> String: return tr("GUESS_FOOTER")
func prompt_text() -> String: return tr("GUESS_PROMPT")
```

`tr()` is a `Node` method, and both classes are Controls, so this needs no import.

In `ui/registry.gd`, the turn's `title`, `blurb`, `motto` and `footer` are read by the card and the top bar outside any node, so leave them as English defaults and let the turn's own `title()`/`prompt_text()` carry the translated text.

- [ ] **Step 5: Add the language row to the settings sheet**

In `ui/hud/settings_sheet.gd`, inside `_build_sheet`, after the `toggle`:

```gdscript
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 10)
	var lang_label := Label.new()
	lang_label.text = tr("TURN_LANGUAGE")
	lang_label.add_theme_font_size_override("font_size", 30)
	lang_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(lang_label)
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = ROW * 0.8
	for i in Locale.CODES.size():
		picker.add_item(Locale.NAMES[Locale.CODES[i]], i)
	picker.select(Locale.CODES.find(Locale.current()))
	picker.item_selected.connect(func(i: int) -> void:
		Locale.set_current(Locale.CODES[i])
		close())
	lang_row.add_child(picker)
	col.add_child(lang_row)
```

and the preload at the top beside the others:

```gdscript
const Locale = preload("res://core/locale.gd")
```

Closing the sheet is enough: the next screen built reads the new locale. A running screen is not re-translated, which is acceptable for a settings change.

- [ ] **Step 6: Check the accented capitals extrude**

This is the one real unknown in the section. `TextMesh` already drops this display face's digits 8 and 9 at weight 700 (`core/lettering.gd`), and É, Ã, Ç and Ñ can fail the same way.

```bash
cat > tests/_accent_check.gd <<'EOF'
extends SceneTree

## Throwaway: does the display face extrude the accented capitals, or do they
## come out empty the way 8 and 9 do at weight 700?
const Lettering = preload("res://core/lettering.gd")

func _process(_delta: float) -> bool:
	for word in ["ADIVINHA", "ADIVINA", "ÁÉÍÓÚ", "ÃÕÇÑ", "GUESS"]:
		var mesh := Lettering.text_mesh(word)
		var box: AABB = mesh.get_aabb() if mesh != null else AABB()
		print("%s -> faces=%d size=%s" % [word,
			mesh.get_faces().size() if mesh != null else -1, box.size])
	quit(0)
	return true
EOF
godot --path . --resolution 540x960 --script res://tests/_accent_check.gd 2>&1 | tail -10
rm tests/_accent_check.gd
```

Adjust the call to whatever `core/lettering.gd` actually exposes — read it first (`grep -n 'static func\|^func' core/lettering.gd`). Expected: every word reports a non-zero face count and a box wider than it is tall. A zero face count or a box the same width as `GUESS` despite more glyphs means the accents dropped; the fix is the one already in that file — drop the offending line's weight to 550 and re-run.

- [ ] **Step 7: See all three**

```bash
godot --path . --resolution 540x960
```

Open the gear, switch to Português, reopen the Guess card: the prompt, the Lock button and the reveal are in Portuguese. Repeat for Español and back to English.

- [ ] **Step 8: Suite, revert the header, commit**

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3
git diff project.godot   # keep the [internationalization] block, drop Godot's header comment
git add locale core/locale.gd core/locale.gd.uid project.godot ui/hud/settings_sheet.gd ui/turn_host.gd turns/guess_number.gd world/main.gd
git commit -m "$(cat <<'MSG'
feat(core): English, Portuguese and Spanish, wired on the turn

The mechanism, proved on the only screens that need it yet. locale/turn.csv
carries the turn flow's strings in three languages and Godot imports it as
translations; core/locale.gd picks the language from the phone or from the
player's override and does the part TranslationServer does not -- the
thousands separator and the decimal comma, which Portuguese and Spanish write
the other way round and which phase 4 will have to parse.

The twelve boards keep their hardcoded English until their own pass; keying
three hundred strings, the rules text most of all, is not what phase 0 is
for.

The settings sheet grows a language picker, mostly so all three can be seen
without changing the phone.
MSG
)"
```

---

### Task 8: Analytics

**Files:**
- Modify: `core/analytics.gd` (a `locale` parameter on every event)

**Interfaces:**
- Consumes: `Locale.current()` (Task 7).
- Produces: every `Analytics.track()` payload carries `locale`.

- [ ] **Step 1: Add the parameter centrally**

The four turn events are already emitted by `ui/turn_host.gd` (Task 5). What is missing is the locale, and adding it at every call site would be a hundred edits and one forgotten one. In `core/analytics.gd`:

```gdscript
const Locale = preload("res://core/locale.gd")
```

In `track()`, beside the two parameters it already adds:

```gdscript
	p["session_id"] = _session_id
	p["engagement_time_msec"] = 1
	p["locale"] = Locale.current()
```

And in `_clean`, the reservation comment and count go from three to four:

```gdscript
		if out.size() >= MAX_PARAMS - 4:  # room for the four we add
```

- [ ] **Step 2: Confirm the events carry it**

`Analytics.validate = true` posts to GA4's validation endpoint and prints the verdict instead of recording.

```bash
grep -n 'validate\|debug_mode' tools/_analytics_ping.gd | head
GA_API_SECRET="$(python3 -c 'import configparser,sys; c=configparser.ConfigParser(); c.read("analytics_secret.cfg"); print(c["analytics"]["api_secret"].strip().strip(chr(34)))' 2>/dev/null)" \
  godot --headless --path . --script res://tools/_analytics_ping.gd 2>&1 | tail -10
```

Expected: `analytics: HTTP 200` with an empty `validationMessages` list. If there is no secret on this machine the ping is a no-op — that is the designed behaviour, and the parameter can instead be confirmed by reading the payload:

```bash
grep -n 'p\["locale"\]' core/analytics.gd
```

- [ ] **Step 3: Suite, then commit**

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3
git add core/analytics.gd
git commit -m "$(cat <<'MSG'
feat(analytics): every event says which language it was played in

The turn events land with the turn host; what was missing is the locale, and
the one place to add it is track() rather than a hundred call sites and the
one that gets forgotten. GA4 drops an event whose parameters run long, so the
reservation in _clean goes from three to four.

Phase 3's rarity pools are decided on this number: if one language passes
about eighty per cent of players, rarity moves to within-language pools.
MSG
)"
```

---

### Task 9: On the phone, offline, and the documentation

**Files:**
- Modify: `CLAUDE.md` (a Turns and backend section)
- Modify: `README.md` (the emulator and probe commands)
- Create: `tools/deploy_functions.sh`

**Interfaces:**
- Consumes: everything above.
- Produces: the spec's five verification gates, met and recorded.

- [ ] **Step 1: Write the deploy script**

`tools/deploy_functions.sh`:

```bash
#!/usr/bin/env bash
# Deploys the turn backend: the three functions and the Firestore rules.
# Nothing here is wired into CI yet -- that needs a deploy service account
# secret, and is a follow-up rather than part of phase 0.
set -euo pipefail
cd "$(dirname "$0")/../server"
(cd functions && npm ci && npm run build)
firebase deploy --only functions,firestore:rules --project peeplet-daily
```

```bash
chmod +x tools/deploy_functions.sh
./tools/deploy_functions.sh
```

- [ ] **Step 2: Gate 1 — the suite and the win harness**

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3
godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | tail -20
```

Expected: the Task 1 baseline with `failed=0`, and every board still winnable.

- [ ] **Step 3: Gate 3 — on the phone**

```bash
tools/deploy_android.sh
```

On the phone, through Firebase App Tester: open the app, find the *Guess* card, play it, lock it. Then confirm the write landed:

```bash
DAY=$(date -u +%Y%m%d)
cd server && firebase firestore:documents:list "days/$DAY/turns/guess_number/submits" --project peeplet-daily 2>/dev/null | head
cd ..
```

If that subcommand is unavailable in the installed CLI, read the document in the Firebase console instead. Expected: one submit, with the score the phone showed.

Then wait for `rollupTally` (five minutes) and reopen the card: the crowd line must have moved off "You are the first today" once a second player, or a second install, has submitted.

- [ ] **Step 4: Gate 4 — airplane mode**

Clear the app's data on the phone, turn airplane mode on, open the app and play the turn.

Expected: the prompt, the dial, the grading and the reveal all work; the crowd line says it has no crowd. Turn airplane mode off, force-quit, reopen the app, and check the submit appears in Firestore — `Backend.start()` flushes the queue on launch.

- [ ] **Step 5: Gate 5 — three locales, and the sign**

Already covered by Task 7 Steps 6 and 7. Re-run the language switch on the phone and confirm the reveal reads correctly in Portuguese and Spanish at phone size.

- [ ] **Step 6: Measure the draw calls**

The thirteenth card adds a diorama to the menu, whose 855-call budget is the binding constraint.

```bash
grep -rn 'draw call\|get_rendering_info\|RENDER_INFO' tests/ tools/ | head
```

Use whatever the repo already has for this; if there is nothing, read `RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)` from a throwaway script on the menu, with and without the new card, and record both numbers.

- [ ] **Step 7: Document it in `CLAUDE.md`**

Add a section after Analytics:

```markdown
## Turns and the backend

A **turn** is one committed input a day, an immediate reveal and a graded
result — never a pass or a fail. Turns sit on the camp grid as cards beside
the boards (`ui/registry.gd` says `"kind": "turn"`), and cost a
`core/turn_base.gd` subclass plus a registry line, the way a puzzle costs a
`PuzzleBase3D`. Both stand on `core/stage_view.gd`, which owns the stage
mounting, the camera fit and the picking maths; `PuzzleBase` extends it too,
because GDScript is single-inheritance.

`core/backend.gd` is the only way out of the game. It is static and woken by
`world/main.gd` alone, exactly like `Analytics` — **unstarted means offline**,
which is how the suite and the harnesses build these screens without touching
the network, and why neither is an autoload.

- Identity is **Firebase Auth anonymous** over the Identity Toolkit REST API,
  not an install id: a security rule cannot verify an unsigned id, and the
  leaderboard is coming. It upgrades in place to a real account later.
- Reads go straight to **Firestore's REST API**; writes go to one Cloud
  Function. Every document a client reads carries a **single `json` field**,
  which is what keeps Firestore's typed values from becoming a decoder.
- There is **no percentile endpoint**: the tally ships the 101-bucket
  histogram and `Backend.percentile()` does the arithmetic on the device.
  Instant reveal, works offline, and "the number moves if you come back" is
  just a second read.
- A submit is queued to disk before it is sent and flushed on the next
  launch. The server keys on uid, day and game, so a double flush is
  harmless. Nothing waits on the network, and in particular **nothing blocks
  Lock**.
- Server lives in `server/` (Cloud Functions v2, TypeScript, Node 22).
  `tools/deploy_functions.sh` deploys the functions and the rules; it is not
  in CI yet. `server/.gdignore` keeps Godot out of `node_modules`.
- `tools/_backend_probe.gd` drives the whole path against the emulator suite
  and prints what came back. It is a harness, not a suite entry.

`core/locale.gd` picks between `en`, `pt` and `es` and does the number
formatting `TranslationServer` does not. Only the turn flow's strings are
keyed (`locale/turn.csv`); the twelve boards are still hardcoded English.
Upper-case accented capitals on a carved sign have the same risk as digits
8 and 9 — check they extrude before putting a localised title on a board.

Roadmap: `docs/brainstorm/single-turn-roadmap.md`. Phase 0's design:
`docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md`.
```

- [ ] **Step 8: Document the commands in `README.md`**

Add beside the existing run lines:

```markdown
    cd server && firebase emulators:start --only auth,firestore,functions
    FIREBASE_EMULATOR=127.0.0.1 godot --headless --path . --script res://tools/_backend_probe.gd
    tools/deploy_functions.sh      # the three functions and the Firestore rules
```

- [ ] **Step 9: Commit**

```bash
git checkout -- project.godot 2>/dev/null
git add CLAUDE.md README.md tools/deploy_functions.sh
git commit -m "$(cat <<'MSG'
docs: how a turn is built and where the backend lives

CLAUDE.md gains the arrangement an agent needs before touching any of this:
that a turn is a card beside the boards and costs a TurnBase subclass and a
registry line, that StageView is under both, that Backend is static and
offline until world/main.gd wakes it, that every document carries one json
field, and that there is no percentile endpoint because the histogram comes
to the device.

tools/deploy_functions.sh deploys the functions and the rules by hand; wiring
it into the Actions workflow needs a deploy service account secret and is a
follow-up.
MSG
)"
```

---

## Self-review

**Spec coverage.**

| Spec section | Task |
|---|---|
| 1 — the six decisions | carried through 4, 5, 6, 7 |
| 2.1 `StageView` and the hierarchy | 1 |
| 2.2 `TurnBase` | 5 |
| 2.3 `TurnHost` | 5 |
| 2.4 registry, menu, `Progress.touch` | 6 (registry/menu), 5 (`Progress.touch` in `TurnHost._ready`) |
| 3.1 shape and the offline rule | 4 |
| 3.2 identity, the Web app key | 4 (client), 2 Step 2 (the key) |
| 3.3 the three calls, the single `json` field | 4 |
| 3.4 no percentile endpoint | 4 (`Backend.percentile`) |
| 3.5 cache and the offline queue | 4, verified again in 9 Step 4 |
| 4.1 layout, `.gdignore`, `.gitignore` | 2 |
| 4.2 Firestore layout | 2 (rules), 3 (writers) |
| 4.3 the three functions | 3 |
| 4.4 rules | 2 |
| 4.5 scoring and what is accepted | 3 (the rate limit; the grading hook is the `GAMES` map) |
| 4.6 deploy | 9 Step 1 |
| 4.7 prerequisites | 2 Step 1 |
| 5 the stub | 6 |
| 6 localisation | 7 |
| 7 analytics | 5 (the events), 8 (the locale parameter) |
| 8 verification, gates 1 to 5 | 1, 3, 4, 7, 9 |
| 9 risks | the extraction gated in 1, draw calls measured in 9 Step 6 |

**Type consistency.** `Backend` answers `{ok, data, error}` from `day_content`, `tally` and `submit`, and `{ok, code, body, error}` from `_http`; the two shapes are never mixed. `percentile` takes the `data` dictionary, not the wrapper — `TurnHost` passes `crowd.data`. `TurnBase.grade(answer)` takes the published answer and the stub ignores it in favour of `_answer()`, which is the offline fallback; that is deliberate and commented. `Registry.kind(entry)` is the only reader of the new field.

**Known soft spots, flagged rather than hidden.** Task 5 Step 4 exists because `IconButton`, `TopBar` and `DayCard` signatures are used from memory of the files rather than re-derived; check them before running. Task 7 Step 6 depends on whatever `core/lettering.gd` actually exposes and says to read it first. Task 3 Step 5 assumes `firebase functions:shell` can drive a scheduled function in the installed CLI version; if it cannot, call the rollup's body through a temporary `onRequest` wrapper and remove it before Step 8.
