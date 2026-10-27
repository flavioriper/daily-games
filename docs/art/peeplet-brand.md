# The Peeplet is the brand

The user, 2026-10-27: "make the peeplet chars the new brand character", "the
daily generated images should contains peeplets (we must make sure to properly
calibrate the reviewer to catch peeplet deformed limbs)". The design is
`docs/superpowers/specs/2026-10-27-peeplet-brand-design.md`; this file holds
the rules that outlive it. The night side (Part C) is written here; the
history and the numbers are in `docs/agents/days-dashboard.md`.

## What a Peeplet is

The real Peeplet is a 3D model shown flat through `ui/peeplet_view.gd`, one
SubViewport and World3D each (CLAUDE.md, "The game is 2D only"). A Peeplet on
a screen is that view, never a hand drawing and never an image of the model;
the 2D vector port was rejected on 2026-10-23.

**The one carve-out is the reference sheet.** The painter that makes the
day's vistas is a text-to-image model and cannot be given a node, so it is
given a picture: `server/functions/assets/peeplet_sheet.png`, 2048 x 1024,
eight cells (front, three-quarter, side, back, sitting, laughing at its bounce
peak, a sunhat coat, round glasses), rendered from the live look. It is never
hand-edited, never imported by Godot (`server/` is `.gdignore`d) and never
shipped to a phone. Rebuild it by rerunning its harness whenever the
Peeplet's look changes (ink, shade, eyes); the exact command, the pose notes
and the `ink` flag are in `docs/agents/days-dashboard.md`, "The Peeplet
sheet":

    godot --path . --resolution 2048x1024 --always-on-top --script res://tests/_shot_peeplet_sheet.gd -- out=server/functions/assets/peeplet_sheet.png

`npm run build` in `server/functions` copies it to `lib/peeplet_sheet.png`.

## The night's Peeplets

Every themed day's four vistas (morning, afternoon, dusk, night) have the
day's two Peeplets in them. A day publishes its vistas only with all four, so
a painting that fails never reaches a phone; the phone keeps the bundled ones.

**The cast** (`server/functions/src/cast.ts`). `seeded(day)` picks two
personas from the eligible ones: a flat coat (`PeepletPalette.BODY` 0..7) and
a plain hat (`PLAIN_HATS`), so the painter is never asked to invent a
propeller cap from a word. The seed is FNV-1a over `"cast-a-" + day` and
`"cast-b-" + day`; the phone's `core/cast.gd` (the app plan adds it) must pick the same pair. When fewer than two personas are eligible, the pair is [0, 1], the first two of ALL. `describe(i)` is total: a coat index outside `COAT_WORDS` reads "coloured" and a hat outside `HAT_WORDS` "a plain hat", never `undefined`. The
test vector is in `days-dashboard.md`. A vistas document carries `cast: [a, b]`.

**The painter** (`vistas.ts`). The morning is given the style picture and the
sheet. It is told: two Peeplets as drawn on the sheet, a round body, two short
arms, two stubby legs, two eyes, no fingers, no neck, both standing with arms
and legs in plain view in poses from the sheet (a seated pair hides its legs,
so a missing-leg decoy shows nothing: 2026-10-27 final review); each body one plain
colour all over, named by `describe()` ("its whole round body is red"), no
clothes, only the hat worn (flash dressed them in robes until the wording said
so); in the right two thirds, each about a seventh of the painting's height,
never the main subject. The afternoon, dusk and night are edits of the
morning and are told to keep the same creatures in the same spots and poses.
`NEVER` allows no humans and says the Peeplets are the only creatures with faces.

**The reviewer** (`reviewPainting` in `vistas.ts`). It is shown the sheet
first and the full-size painting (never the shrunk phone JPEG, where a limb
is invisible; for an edit, the morning beside it is the shrunk JPEG, as at
paint time), and answers `{wrong, peeplets}`. A painting passes only with
nothing wrong and one to three Peeplets counted. It is turned down for a
human, a wrong number of arms or legs, a fused, melted, doubled, bent or
overlong limb, fingers, a neck, a second head, more than two eyes, a body that
is not one round blob, a Peeplet in the left third (the day card's words go
there), no Peeplet or more than three, and a body (hat excluded) larger than
a quarter (past about 27%; the user, 2026-10-27: 22-24% is fine) or smaller than a twentieth of the painting's height. Lights lit at dusk or night (windows, lanterns, the fire, their glow) are the time of day, never a different place. An edit's Peeplets must be the morning's: the same number, body colours and hats. The model writes a `limbs` note for each Peeplet before it answers. Hats and coats
are not judged. The size rule is the one the user may overrule: a borderline
size is never copied into a bench label.

## The bench

`tools/days/peeplet-bench/` holds paintings, decoys (a painting edited to
carry one named defect, `cli.js decoys`), the user's hand labels
(`labels.json`) and `index.html`, the page the user labels on
(`python3 -I tools/peeplet_bench.py`). Its README names every file.
`node lib/cli.js review-bench <dir> [--rescore]` (from `server/functions`,
Anthropic's API) runs the reviewer over it and writes `report.json`.

**The gate:** no deformed painting passes (`deformedPassed` empty) and fewer
than a third of the good ones are rejected, in at most three reviewer passes;
if it is not met, stop and ask the user before any crop-and-enlarge. Rerun the
bench after any change to `REVIEWER`, `REVIEW_FIRST` or `REVIEW_EDIT`; the
report's `rubric` hash says which rubric it judged.

**What the gate does and does not prove (2026-10-27, pass 1; superseded: on the user's labels pass 3 fails the gate, 3 deformed passed and 7 of 31 good rejected, see `days-dashboard.md`).** It held:
0 deformed passed, 0 good rejected. But only the fingers, human, neck and text
defects are labelled. The reviewer passed every unlabelled limb decoy (third
arm, fused, long arm, missing leg), so limb defects are not yet shown caught.
Label those decoys on `index.html`, then `--rescore`, before saying the
reviewer is calibrated. The subtle decoys are a tracked rate, not part of the gate.

Deploying `themeDay` (`tools/deploy_functions.sh`) is the user's call, after
the gate holds.

## Where things are

| Thing | Place |
|---|---|
| The sheet and its harness | `server/functions/assets/peeplet_sheet.png`, `tests/_shot_peeplet_sheet.gd` |
| The day's cast | `server/functions/src/cast.ts`, `cast_personas.json` (`tools/export_personas.gd`), `core/cast.gd` |
| Painter, reviewer, tries | `server/functions/src/vistas.ts` |
| The bench, labels, report | `tools/days/peeplet-bench/` |
| Tries and counts on the dashboard | "Themed days", `tools/dashboard.src.html` |
| The numbers and each pass | `docs/agents/days-dashboard.md` |
