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
