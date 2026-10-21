// SPIKE (throwaway): the model writes the Gumdrop jelly map from the sticker
// drawing with a 0-100 grid over it; the parts are judged by the night's own
// why(), a refusal folded into one retry; rendered flat and gummy; scored by
// the eye beside run 2's pixel-read parts of the same drawing.
//   zsh -ilc 'node spike_jelly_map.js <dir>'
const fs = require("node:fs");
const path = require("node:path");
const F = "/Users/flavioriper/dev/daily/server/functions";
const {ask, cost} = require(F + "/lib/generate.js");
const {why, polygon, RULES} = require(F + "/lib/jelly.js");
const {PNG} = require(F + "/node_modules/pngjs");

const OUT = process.argv[2];
const BAND_NAMES = ["Easy", "Medium", "Hard", "Insane"];
const CARDS = [
  {name: "jelly0_boot", id: "boot", thing: "rain boot", band: 0},
  {name: "jelly1_snail", id: "snail", thing: "snail", band: 1},
  {name: "jelly2_frog", id: "frog", thing: "frog", band: 2},
  {name: "jelly3_kettle", id: "kettle", thing: "kettle", band: 3},
];
const CHOICES = ["rain boot", "snail", "frog", "umbrella", "kettle", "teapot"];
const INKS = {cherry: "#e2495a", orange: "#f39237", lemon: "#f4d44a", lime: "#79c94f", blueberry: "#4a86df", grape: "#9a62d2"};
const run2 = JSON.parse(fs.readFileSync(path.join(OUT, "spike2.json"), "utf8"));

const rules = (band) => {
  const r = RULES[band];
  return `${r.flavours[0] === r.flavours[1] ? `exactly ${r.flavours[0]}` : `${r.flavours[0]} to ${r.flavours[1]}`} flavours in all${r.mixed ? `, at least ${r.mixed} of them mixed (orange, lime or grape)` : ""}; ${r.chunks[0]} to ${r.chunks[1]} chunks in all, where a chunk is one connected blob of one flavour (two shapes of one flavour that touch are one chunk)`;
};
const MAPPER = `You are a sweet-maker drawing the mould of a jelly for a children's puzzle. You are shown a flat sticker drawing of one thing on a plain cyan or magenta background, with a grid over it numbered 0 to 100 along the top and left (and again along the bottom and right). A point's x is read along the top numbers and y along the left numbers, as decimals.

Write the jelly as a list of parts. A part has a flavour, one of: cherry (red), orange, lemon (yellow), lime (green), blueberry (blue), grape (purple), and one to eight shapes. A shape is {"kind":"soft","n":[x1,y1,x2,y2,...]}: a polygon of 6 to 16 points in order round its outline, which is drawn with its corners well rounded. Rules: the parts together make ONE connected piece of jelly in the thing's silhouette, sharp and true to the drawing (every part a child expects, in the drawing's proportions), every shape inside 10 to 90 on both axes; the shapes of neighbouring parts touch or overlap a little so no gap opens between them, and a shape drawn later lies over an earlier one; a shape must be big enough to pour (never thinner than 6 units anywhere); ignore any white sticker border, outlines, highlights or shading in the drawing and give each region the flavour nearest its colour. Use the drawing's colours as the flavours, but keep to the band's counts. Answer with JSON only.`;
const SCHEMA = {type: "object", additionalProperties: false, required: ["parts"], properties: {
  parts: {type: "array", items: {type: "object", additionalProperties: false, required: ["flavour", "shapes"], properties: {
    flavour: {type: "string", enum: Object.keys(INKS)},
    shapes: {type: "array", items: {type: "object", additionalProperties: false, required: ["kind", "n"], properties: {kind: {type: "string", enum: ["soft"]}, n: {type: "array", items: {type: "number"}}}}},
  }}},
}};
const EYE = `You review pictures for a children's puzzle game. You are shown the picture the player will see (a jelly of a few flat candy colours) and, after it, the drawing it was made from. Judge the FIRST picture, strictly and honestly, as a polished product would be judged. Answer one JSON object: "pick" is which thing the first picture shows, exactly one of the choices given or "none"; "score" is 0 to 10 (10 is elegant, complete and polished, 7 is good enough to ship, under 5 is not); "wrong" is an empty string unless something does not belong in a children's game; "notes" is one sentence naming what would most improve it.`;
const RUBRIC = "A flat jelly of the thing in a few candy colours: the silhouette is sharp, clean and true to the thing so a child names it at once; the parts are big and well proportioned; no stray blobs, slivers or ragged edges; it looks elegant and polished.";
const EYE_SCHEMA = {type: "object", additionalProperties: false, required: ["pick", "score", "wrong", "notes"], properties: {pick: {type: "string"}, score: {type: "number"}, wrong: {type: "string"}, notes: {type: "string"}}};

const dataUrl = (mime, bytes) => `data:${mime};base64,${bytes.toString("base64")}`;
function fill(d, i, r, g, b) { d[i * 4] = r; d[i * 4 + 1] = g; d[i * 4 + 2] = b; d[i * 4 + 3] = 255; }
function scan(pts, w, k, cb) {
  const p = pts.map(([x, y]) => [x * k, y * k]);
  for (let y = 0; y < w; y++) {
    const xs = [];
    for (let i = 0; i < p.length; i++) { const a = p[i], b = p[(i + 1) % p.length]; if ((a[1] <= y + 0.5) !== (b[1] <= y + 0.5)) xs.push(a[0] + (y + 0.5 - a[1]) * (b[0] - a[0]) / (b[1] - a[1])); }
    xs.sort((a, b) => a - b);
    for (let i = 0; i + 1 < xs.length; i += 2) for (let x = Math.max(0, Math.round(xs[i])); x < Math.min(w, Math.round(xs[i + 1])); x++) cb(x, y);
  }
}
function renderPng(parts) {
  const W = 480, png = new PNG({width: W, height: W});
  for (let i = 0; i < W * W; i++) fill(png.data, i, 0xf3, 0xea, 0xd8);
  for (const part of parts) {
    const c = [1, 3, 5].map((i) => parseInt(INKS[part.flavour].slice(i, i + 2), 16));
    for (const s of part.shapes) scan(polygon(s), W, W / 100, (x, y) => fill(png.data, y * W + x, c[0], c[1], c[2]));
  }
  return PNG.sync.write(png);
}
const GUM = `<defs><filter id="gum" x="-20%" y="-20%" width="140%" height="140%" primitiveUnits="userSpaceOnUse">
  <feGaussianBlur in="SourceAlpha" stdDeviation="2.2" result="bump"/>
  <feSpecularLighting in="bump" surfaceScale="7" specularConstant="0.85" specularExponent="18" lighting-color="#ffffff" result="spec"><fePointLight x="20" y="-10" z="120"/></feSpecularLighting>
  <feComposite in="spec" in2="SourceAlpha" operator="in" result="specIn"/>
  <feGaussianBlur in="SourceAlpha" stdDeviation="3.5" result="soft"/>
  <feComposite in="soft" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="innerA"/>
  <feFlood flood-color="#3a1a30" flood-opacity="0.35" result="dark"/><feComposite in="dark" in2="innerA" operator="in" result="rim"/>
  <feGaussianBlur in="SourceAlpha" stdDeviation="2" result="sh"/><feOffset in="sh" dx="1.5" dy="2.5" result="shOff"/>
  <feFlood flood-color="#5a3a2a" flood-opacity="0.25"/><feComposite in2="shOff" operator="in" result="shadow"/>
  <feMerge><feMergeNode in="shadow"/><feMergeNode in="SourceGraphic"/><feMergeNode in="rim"/><feMergeNode in="specIn"/></feMerge></filter></defs>`;
function svg(parts, glossy) {
  let out = `<svg viewBox="0 0 100 100" width="300" height="300" style="background:#f3ead8;border-radius:8px">${glossy ? GUM : ""}<g${glossy ? ' filter="url(#gum)"' : ""}>`;
  for (const part of parts) for (const s of part.shapes) out += `<polygon points="${polygon(s).map((v) => v.map((x) => x.toFixed(2)).join(",")).join(" ")}" fill="${INKS[part.flavour]}" stroke="${INKS[part.flavour]}" stroke-width="0.4" stroke-linejoin="round"/>`;
  return out + `</g></svg>`;
}

const results = [];
const t0 = Date.now();
const log = (s) => console.log(`[${((Date.now() - t0) / 1000).toFixed(0)}s] ${s}`);
async function one(card) {
  const r = {...card, tries: []};
  results.push(r);
  try {
    const grid = fs.readFileSync(path.join(OUT, card.name + "_grid.png"));
    const srcFile = fs.readdirSync(OUT).find((f) => f.startsWith(card.name + "_source2."));
    const src = fs.readFileSync(path.join(OUT, srcFile));
    const srcMime = srcFile.endsWith(".png") ? "image/png" : "image/jpeg";
    let parts = null, refused = "";
    for (let n = 0; n < 2 && parts === null; n++) {
      const before = cost(), t1 = Date.now();
      const got = await ask({system: MAPPER, role: "review", schema: SCHEMA, images: [dataUrl("image/png", grid)],
        prompt: `The drawing is of a ${card.thing}. The band is ${BAND_NAMES[card.band]}: ${rules(card.band)}; at most 8 parts.${refused ? `\nYour last answer was refused by the board's checker: "${refused}". Write it again so it passes.` : ""}\nWrite the jelly.`});
      const w = why(got.parts, card.band);
      r.tries.push({seconds: Math.round((Date.now() - t1) / 1000), dollars: Math.round((cost() - before) * 100) / 100, parts: got.parts?.length, why: w});
      fs.writeFileSync(path.join(OUT, `${card.name}_map${n}.json`), JSON.stringify(got));
      if (w === "") parts = got.parts; else { refused = w; r.last = got.parts; }
    }
    const shown = parts ?? r.last;
    r.passed = parts !== null;
    r.flavours = [...new Set(shown.map((p) => p.flavour))].join(", ");
    r.svgFlat = svg(shown, false);
    r.svgGlossy = svg(shown, true);
    const png = renderPng(shown);
    fs.writeFileSync(path.join(OUT, card.name + "_map.png"), png);
    const eye = await ask({system: EYE, role: "review", schema: EYE_SCHEMA, images: [dataUrl("image/png", png), dataUrl(srcMime, src)], prompt: `Rubric: ${RUBRIC}\nChoices: ${CHOICES.join(", ")}.`});
    r.eye = {pick: String(eye.pick ?? "").toLowerCase(), score: Number(eye.score ?? 0), wrong: String(eye.wrong ?? ""), notes: String(eye.notes ?? "")};
    const prev = run2.jelly.find((c) => c.id === card.id);
    r.prev = prev ? {score: prev.eye.score, notes: prev.eye.notes, parts: prev.parts, why: prev.why, svg: prev.svgFlat} : null;
    log(`${card.name}: ${r.tries.map((t) => `${t.parts} parts in ${t.seconds}s $${t.dollars}${t.why ? ` refused "${t.why}"` : " passed"}`).join("; ")} · eye ${r.eye.pick} ${r.eye.score} (reader was ${r.prev?.score}${r.prev?.why ? ", refused" : ""}): ${r.eye.notes}`);
  } catch (e) {
    r.error = String(e).slice(0, 300);
    log(`${card.name} FAILED ${r.error}`);
  }
  fs.writeFileSync(path.join(OUT, "spike4.json"), JSON.stringify(results, null, 1));
  page();
}
function page() {
  const esc = (s) => String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;");
  let h = `<!doctype html><meta charset="utf-8"><title>Gumdrop jelly by a model</title><style>
  body{font-family:-apple-system,Helvetica,sans-serif;background:#f6f1e8;color:#2a2420;margin:24px} h1{font-size:22px}
  .card{background:#fff;border-radius:12px;padding:14px;margin:14px 0;display:flex;gap:14px;flex-wrap:wrap;align-items:flex-start}
  .col{display:flex;flex-direction:column;align-items:center;gap:6px;font-size:12px;color:#6b5f55} .col img{width:300px;height:300px;object-fit:contain;border-radius:8px;background:#fff}
  .col svg{width:300px;height:300px} .meta{width:100%;font-size:14px} .good{color:#2c6e2f} .bad{color:#a33} .note{font-size:13px;color:#6b5f55;max-width:960px} i{color:#555}
  </style><h1>Gumdrop jelly written by a model · ${new Date().toISOString().slice(0, 16)}</h1>
  <p class="note">Throwaway. The run-2 sticker drawing with a 0-100 grid over it goes to the reviewer model (Opus), which writes the jelly's parts (flavour + soft polygons) under the band's rules. The night's own checker (why) judges the parts; a refusal is folded into one retry. The jelly is shown flat as the card draws it and with a gummy finish, and scored by the eye. "Today's pipeline" is run 2's pixel reader on the same drawing.</p>`;
  for (const r of results) {
    h += `<div class="card"><div class="meta"><b>${esc(r.thing)}</b> · ${BAND_NAMES[r.band]} · ${esc(rules(r.band))}` +
      (r.tries ? r.tries.map((t, i) => ` · try ${i + 1}: ${t.parts} parts in ${t.seconds}s for $${t.dollars}, <span class="${t.why ? "bad" : "good"}">${t.why ? "refused: " + esc(t.why) : "passed the checker"}</span>`).join("") : "") +
      (r.flavours ? ` · ${esc(r.flavours)}` : "") + `</div>`;
    if (r.error) { h += `<p class="bad">failed: ${esc(r.error)}</p></div>`; continue; }
    h += `<div class="col"><img src="${r.name}_grid.png"><span>the mapping field</span></div>` +
      `<div class="col">${r.svgFlat}<span>the model's jelly${r.passed ? "" : " (last try, refused)"}</span></div>` +
      `<div class="col">${r.svgGlossy}<span>with the gummy finish</span></div>` +
      (r.prev ? `<div class="col">${r.prev.svg}<span>today's pipeline: ${r.prev.parts} parts${r.prev.why ? ", refused: " + esc(r.prev.why) : ""} · eye ${r.prev.score}</span></div>` : "") +
      `<div class="meta"><p class="${r.eye.score >= 7 && r.eye.pick === r.thing ? "good" : "bad"}">eye on the model's jelly: <b>${esc(r.eye.pick)}</b> · score <b>${r.eye.score}</b> · <i>${esc(r.eye.notes)}</i></p>` +
      (r.prev ? `<p>eye on today's pipeline: score <b>${r.prev.score}</b> · <i>${esc(r.prev.notes)}</i></p>` : "") + `</div></div>`;
  }
  fs.writeFileSync(path.join(OUT, "spike4.html"), h);
}
(async () => {
  for (const c of CARDS) await one(c);
  log(`done: ${path.join(OUT, "spike4.html")} · $${cost().toFixed(2)}`);
})();
