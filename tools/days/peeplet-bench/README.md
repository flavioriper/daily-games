# The Peeplet review bench

Paintings of the Peeplet vistas (`server/functions/src/vistas.ts`) and decoys
(paintings edited to carry one named defect, `cli.js decoys`), each judged by
hand in `labels.json`, so the night's reviewer can be measured against them
(Task 5's review-bench). `index.html` is built by `python3 -I tools/peeplet_bench.py`.

Only the phone-size JPEGs (`<day>_vista-<time>-<try>.jpg`, and
`..._decoy-<n>-<defect>.jpg`, about 80 KB each), the day JSONs (`{day, theme}`
plus `vistaTries`, the reviewer's word at paint time), `labels.json`, this file
and `index.html` are committed. The painter's full-size PNGs
(`*-full.png` and the decoys' `.png`, about 1.2 MB each) stay on disk,
uncommitted (`.gitignore`): the reviewer judges full-size images at paint
time, and the review-bench reads a full PNG when it is on disk and falls back
to the JPEG when it is not.

A painting's full PNG is `<name>-full.png` for `<name>.jpg`; a decoy's is
`<name>.png`. Labels are keyed by the JPEG's name. Paintings and decoys left
out of `labels.json` are the ones waiting for the user's word (the subtle
decoys and the paintings the labeller was unsure of). The `other` fails are
text in the painting (20261016 morning-0 and -1, 20261202 morning-0); a
size verdict is never copied from the reviewer into a label (20261015
morning-1 was, and was taken out: a borderline size is the user's call).

The bench days: 20261014-20261019 are the six themed days already made (stripped
to `{day, theme}`), 20261101 and 20261102 were written by `cli.js theme`,
and 20261201 and 20261202 are second paintings of the tide pool and the bakery
(the same themes, a new cast), made because the first two stopped at the
morning. Day 20261018's first night try failed on a Vertex 429 and has no image.

## Making a decoy: confirm the defect by eye

A decoy's defect must be confirmed by eye, at full size, before it is
labelled: crop the Peeplet from the decoy's PNG and look. An edit that did not
take is deleted, never labelled pass (a pass label on a decoy would score the
reviewer for turning down nothing). Edits (flash) often redo the whole scene,
so also check the Peeplets are still there, and are standing: a seated pair
shows no legs, so a missing-leg decoy on it shows nothing (the first
`20261019_vista-night-0_decoy-2-missing-leg` was made so, on seated Peeplets,
and its defect is read by eye only at the JPEG; its PNG is gone and the bench
falls back to the JPEG). The painter's morning prompt now asks for the pair
standing, arms and legs in view (`FIRST` in `vistas.ts`).

Eight edits on standing Peeplets were made on 2026-10-27 (final review fix);
one was kept, `20261202_vista-morning-1_decoy-1-third-arm` (the blue Peeplet
has a third arm in front, gripping the basket; unlabelled, waiting for the
user). That painting was itself turned down for size by the reviewer in pass 1,
so the decoy's verdict says "too large", not the arm: it proves nothing about
limb count until the user labels it and a size-clean base is used. Dropped:

- `20261101_vista-morning-0_decoy-1-third-arm`: the purple Peeplet turned
  three-quarters with two arms; no third arm.
- `20261101_vista-morning-0_decoy-2-missing-leg`: the purple Peeplet was
  painted out; a missing Peeplet, not a leg.
- `20261101_vista-morning-0_decoy-7-long-arm`: one arm gone and the face
  redrawn; no longer arm.
- `20261014_vista-morning-0_decoy-1-third-arm`: two arms each; no third.
- `20261014_vista-morning-0_decoy-2-missing-leg` (twice): first, both
  Peeplets kept two feet; second, both Peeplets painted out.
- `20261202_vista-morning-1_decoy-2-missing-leg`: both blue feet still there,
  the green's second foot hidden behind the basket; nothing visibly removed.

To review just new decoys: `node lib/cli.js review-bench <dir> --only
<file.jpg>...` (a few cents), then label them and `--rescore`.
