// SPIKE: the eye on run 2's coarse cuts (today's panels), the same rubric as the model maps
const fs = require("node:fs"); const path = require("node:path");
const F = "/Users/flavioriper/dev/daily/server/functions";
const {ask} = require(F + "/lib/generate.js");
const {PNG} = require(F + "/node_modules/pngjs");
const OUT = process.argv[2];
const run2 = JSON.parse(fs.readFileSync(path.join(OUT, "spike2.json"), "utf8"));
const CARDS = [["snail", "ref"], ["frog", "words"], ["umbrella", "words"], ["kettle", "ref"]];
const CHOICES = ["rain boot", "snail", "frog", "umbrella", "kettle", "teapot"];
const EYE = `You review pictures for a children's puzzle game. You are shown the picture the player will see (a mesh of flat coloured panels) and, after it, the drawing it was made from. Judge the FIRST picture, strictly and honestly, as a polished product would be judged. Answer one JSON object: "pick" is which thing the first picture shows, exactly one of the choices given or "none"; "score" is 0 to 10 (10 is elegant, complete and polished, 7 is good enough to ship, under 5 is not); "wrong" is an empty string unless something does not belong in a children's game; "notes" is one sentence naming what would most improve it.`;
const RUBRIC = "A low-poly picture of the thing: the WHOLE thing is present with every part a child expects, in its true colours; the facets read as soft light and shade; nothing but the thing; it looks elegant and polished and faithful to the drawing.";
const SCHEMA = {type: "object", additionalProperties: false, required: ["pick", "score", "wrong", "notes"], properties: {pick: {type: "string"}, score: {type: "number"}, wrong: {type: "string"}, notes: {type: "string"}}};
function fill(d, i, r, g, b) { d[i * 4] = r; d[i * 4 + 1] = g; d[i * 4 + 2] = b; d[i * 4 + 3] = 255; }
function scan(pts, w, cb) {
  for (let y = 0; y < w; y++) {
    const xs = [];
    for (let i = 0; i < pts.length; i++) { const a = pts[i], b = pts[(i + 1) % pts.length]; if ((a[1] <= y + 0.5) !== (b[1] <= y + 0.5)) xs.push(a[0] + (y + 0.5 - a[1]) * (b[0] - a[0]) / (b[1] - a[1])); }
    xs.sort((p, q) => p - q);
    for (let i = 0; i + 1 < xs.length; i += 2) for (let x = Math.max(0, Math.round(xs[i])); x < Math.min(w, Math.round(xs[i + 1])); x++) cb(x, y);
  }
}
(async () => {
  const out = [];
  for (const [id, variant] of CARDS) {
    const c = run2.hoop.find((h) => h.id === id && h.variant === variant);
    const W = 600, png = new PNG({width: W, height: W});
    for (let i = 0; i < W * W; i++) fill(png.data, i, 0xef, 0xe2, 0xc6);
    for (const m of c.svgPanels.matchAll(/<polygon points="([^"]+)" fill="(#[0-9a-f]{6})"/g)) {
      const pts = m[1].split(" ").map((p) => p.split(",").map((v) => Number(v) * W / 100));
      const col = [1, 3, 5].map((i) => parseInt(m[2].slice(i, i + 2), 16));
      scan(pts, W, (x, y) => fill(png.data, y * W + x, col[0], col[1], col[2]));
    }
    const bytes = PNG.sync.write(png);
    fs.writeFileSync(path.join(OUT, `${id}_${variant}_readercut.png`), bytes);
    const srcFile = fs.readdirSync(OUT).find((f) => f.startsWith(`hoop${c.band}_${id}_${variant}_source2.`));
    const src = fs.readFileSync(path.join(OUT, srcFile));
    const eye = await ask({system: EYE, role: "review", schema: SCHEMA, prompt: `Rubric: ${RUBRIC}\nChoices: ${CHOICES.join(", ")}.`,
      images: [`data:image/png;base64,${bytes.toString("base64")}`, `data:${srcFile.endsWith(".png") ? "image/png" : "image/jpeg"};base64,${src.toString("base64")}`]});
    out.push({id, variant, panels: c.panels, pins: c.pins, eye});
    console.log(`${id} ${variant}: reader's cut ${c.panels} panels; eye ${eye.pick} ${eye.score}: ${eye.notes}`);
  }
  fs.writeFileSync(path.join(OUT, "spike3_reader.json"), JSON.stringify(out, null, 1));
})();
