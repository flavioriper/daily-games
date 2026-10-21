// SPIKE (throwaway): can a vision model write the Yarn Hoop map itself?
// Each saved run-2 drawing goes to the reviewer model with a numbered grid
// over it (the mapping field); the model answers pins and panels in grid
// coordinates; the mesh is snapped, checked, coloured off the drawing,
// rendered and scored by the eye; shown beside the pixel reader's cut.
//   zsh -ilc 'node spike_map.js <dir>'
const fs = require("node:fs");
const path = require("node:path");
const F = "/Users/flavioriper/dev/daily/server/functions";
const {ask, cost} = require(F + "/lib/generate.js");
const fx = require(F + "/lib/facets.js");
const {PNG} = require(F + "/node_modules/pngjs");

const OUT = process.argv[2];
const BAND_NAMES = ["Easy", "Medium", "Hard", "Insane"];
const CARDS = [
  {name: "hoop0_snail_ref", id: "snail", thing: "snail", band: 0, N: 20, most: 40},
  {name: "hoop1_frog_words", id: "frog", thing: "frog", band: 1, N: 24, most: 60},
  {name: "hoop2_umbrella_words", id: "umbrella", thing: "umbrella", band: 2, N: 30, most: 95},
  {name: "hoop3_kettle_ref", id: "kettle", thing: "kettle", band: 3, N: 40, most: 170},
];
const CHOICES = ["rain boot", "snail", "frog", "umbrella", "kettle", "teapot"];
const run2 = JSON.parse(fs.readFileSync(path.join(OUT, "spike2.json"), "utf8"));

const MAPPER = `You are a low-poly artist turning a drawing into the map of a puzzle board. The drawing is a low-poly illustration of one thing on a plain magenta or cyan background, with a numbered grid laid over it: the grid lines are numbered 0..N along the top and left (and again along the bottom and right). A point's x is its position along the top numbers and y its position along the left numbers, as decimals (x 7.5 is halfway between lines 7 and 8).

Write the map as pins and panels. A pin is a corner, with an integer id. A panel is one flat facet of the drawing: a list of 3 to 7 pin ids in order round its outline, and its colour as #rrggbb read off the drawing. Rules: the panels tile the THING exactly and nothing of the background: every facet of the drawing is a panel (merge only facets that are the same colour and together make a convex 3-7 sided shape); neighbouring panels share their pins and their whole side (never a corner of one panel lying in the middle of another's side, never two panels overlapping, never a gap); every panel is convex; the thing's outline is traced faithfully, every part of it (a snail's eye stalks, a kettle's spout and knob). Place every pin where the drawing's corners really are, as precisely as the grid allows. Answer with JSON only.`;
const SCHEMA = {type: "object", additionalProperties: false, required: ["pins", "panels"], properties: {
  pins: {type: "array", items: {type: "object", additionalProperties: false, required: ["id", "x", "y"], properties: {id: {type: "integer"}, x: {type: "number"}, y: {type: "number"}}}},
  panels: {type: "array", items: {type: "object", additionalProperties: false, required: ["pins", "colour"], properties: {pins: {type: "array", items: {type: "integer"}}, colour: {type: "string"}}}},
}};
const EYE = `You review pictures for a children's puzzle game. You are shown the picture the player will see (a mesh of flat coloured panels) and, after it, the drawing it was made from. Judge the FIRST picture, strictly and honestly, as a polished product would be judged. Answer one JSON object: "pick" is which thing the first picture shows, exactly one of the choices given or "none"; "score" is 0 to 10 (10 is elegant, complete and polished, 7 is good enough to ship, under 5 is not); "wrong" is an empty string unless something does not belong in a game for children; "notes" is one sentence naming what would most improve it.`;
const RUBRIC = "A low-poly picture of the thing: the WHOLE thing is present with every part a child expects, in its true colours; the facets read as soft light and shade; nothing but the thing; it looks elegant and polished and faithful to the drawing.";
const EYE_SCHEMA = {type: "object", additionalProperties: false, required: ["pick", "score", "wrong", "notes"],
  properties: {pick: {type: "string"}, score: {type: "number"}, wrong: {type: "string"}, notes: {type: "string"}}};

const dataUrl = (mime, bytes) => `data:${mime};base64,${bytes.toString("base64")}`;
function pngOf(w, h, paint) { const png = new PNG({width: w, height: h}); paint(png.data, w, h); return PNG.sync.write(png); }
function fill(data, i, r, g, b) { data[i * 4] = r; data[i * 4 + 1] = g; data[i * 4 + 2] = b; data[i * 4 + 3] = 255; }
function scan(poly, w, k, cb) {
  const pts = poly.map(([x, y]) => [x * k, y * k]);
  for (let y = 0; y < w; y++) {
    const xs = [];
    for (let i = 0; i < pts.length; i++) {
      const a = pts[i], b = pts[(i + 1) % pts.length];
      if ((a[1] <= y + 0.5) !== (b[1] <= y + 0.5)) xs.push(a[0] + (y + 0.5 - a[1]) * (b[0] - a[0]) / (b[1] - a[1]));
    }
    xs.sort((p, q) => p - q);
    for (let i = 0; i + 1 < xs.length; i += 2) for (let x = Math.max(0, Math.round(xs[i])); x < Math.min(w, Math.round(xs[i + 1])); x++) cb(x, y);
  }
}
const area = (p) => { let a = 0; for (let i = 0; i < p.length; i++) { const q = p[(i + 1) % p.length]; a += p[i][0] * q[1] - q[0] * p[i][1]; } return a / 2; };
function inside(pt, poly, margin) {
  // strictly inside: every edge's signed distance beyond margin, poly made ccw
  const p = area(poly) < 0 ? poly.slice().reverse() : poly;
  for (let i = 0; i < p.length; i++) {
    const a = p[i], b = p[(i + 1) % p.length];
    const len = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
    const d = ((b[0] - a[0]) * (pt[1] - a[1]) - (b[1] - a[1]) * (pt[0] - a[0])) / len;
    if (d <= margin) return false;
  }
  return true;
}
function onSide(pt, a, b, tol) {
  const len = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
  const t = ((pt[0] - a[0]) * (b[0] - a[0]) + (pt[1] - a[1]) * (b[1] - a[1])) / (len * len);
  if (t <= 0.02 || t >= 0.98) return false;
  const d = Math.abs((b[0] - a[0]) * (pt[1] - a[1]) - (b[1] - a[1]) * (pt[0] - a[0])) / len;
  return d < tol;
}

function mesh(got, N) {
  // grid units -> square of 100; pins snapped within SNAP of one another
  const SNAP = 100 / N * 0.35;
  const by = new Map();
  const pins = [];
  for (const p of got.pins) {
    const x = Number(p.x) / N * 100, y = Number(p.y) / N * 100;
    let k = pins.findIndex((q) => Math.hypot(q[0] - x, q[1] - y) < SNAP);
    if (k < 0) { k = pins.length; pins.push([x, y]); }
    by.set(Number(p.id), k);
  }
  const stats = {asked: got.panels.length, unknown: 0, under3: 0, over7: 0, snapped: got.pins.length - pins.length};
  const panels = [];
  for (const pa of got.panels) {
    const ids = [];
    for (const id of pa.pins) {
      const k = by.get(Number(id));
      if (k === undefined) { stats.unknown++; continue; }
      if (ids.length === 0 || ids[ids.length - 1] !== k) ids.push(k);
    }
    if (ids.length > 1 && ids[0] === ids[ids.length - 1]) ids.pop();
    if (ids.length < 3) { stats.under3++; continue; }
    if (ids.length > 7) stats.over7++;
    panels.push({k: ids, c: String(pa.colour)});
  }
  // the pins used, renumbered
  const used = new Map();
  const kept = [];
  for (const pa of panels) pa.k = pa.k.map((k) => { if (!used.has(k)) { used.set(k, kept.length); kept.push(pins[k]); } return used.get(k); });
  // checks the phone and the night make
  let overlaps = 0, tees = 0, triple = 0, concave = 0;
  const sides = new Map();
  for (const pa of panels) {
    const poly = pa.k.map((k) => kept[k]);
    if (!convex(poly)) concave++;
    for (let i = 0; i < pa.k.length; i++) {
      const a = pa.k[i], b = pa.k[(i + 1) % pa.k.length];
      const key = a < b ? `${a}-${b}` : `${b}-${a}`;
      sides.set(key, (sides.get(key) ?? 0) + 1);
    }
  }
  for (const n of sides.values()) if (n > 2) triple++;
  for (let k = 0; k < kept.length; k++) {
    for (const pa of panels) {
      if (pa.k.includes(k)) continue;
      const poly = pa.k.map((j) => kept[j]);
      if (inside(kept[k], poly, 0.3)) { overlaps++; break; }
      let tee = false;
      for (let i = 0; i < poly.length; i++) if (onSide(kept[k], poly[i], poly[(i + 1) % poly.length], 0.3)) { tee = true; break; }
      if (tee) { tees++; break; }
    }
  }
  return {pins: kept, panels, stats: {...stats, panels: panels.length, pins: kept.length, overlaps, tees, triple, concave}};
}
function convex(p) {
  let sign = 0;
  for (let i = 0; i < p.length; i++) {
    const a = p[i], b = p[(i + 1) % p.length], c = p[(i + 2) % p.length];
    const z = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]);
    if (Math.abs(z) < 1e-6) continue;
    if (sign === 0) sign = Math.sign(z); else if (Math.sign(z) !== sign) return false;
  }
  return true;
}
function colourOff(r, m) {
  // each panel's colour: the drawing's mean over the panel
  for (const pa of m.panels) {
    const poly = pa.k.map((k) => m.pins[k]);
    let n = 0, s = [0, 0, 0];
    scan(poly, r.n, r.n / 100, (x, y) => { const i = y * r.n + x; n++; s[0] += r.rgb[i * 3]; s[1] += r.rgb[i * 3 + 1]; s[2] += r.rgb[i * 3 + 2]; });
    if (n > 0) pa.c = "#" + s.map((v) => Math.round(v / n).toString(16).padStart(2, "0")).join("");
  }
}
function renderPng(m) {
  const W = 600;
  const bytes = pngOf(W, W, (data, w) => {
    for (let i = 0; i < w * w; i++) fill(data, i, 0xef, 0xe2, 0xc6);
    for (const pa of m.panels) {
      const c = [1, 3, 5].map((i) => parseInt(pa.c.slice(i, i + 2), 16));
      scan(pa.k.map((k) => m.pins[k]), w, w / 100, (x, y) => fill(data, y * w + x, c[0], c[1], c[2]));
    }
  });
  return bytes;
}
function svg(m, pinsToo) {
  let out = `<svg viewBox="-2 -2 104 104" width="300" height="300" style="background:#efe2c6;border-radius:8px">`;
  for (const pa of m.panels) {
    const pts = pa.k.map((k) => m.pins[k].map((v) => v.toFixed(2)).join(",")).join(" ");
    out += `<polygon points="${pts}" fill="${pa.c}" stroke="rgba(90,50,30,0.5)" stroke-width="0.5" stroke-linejoin="round"/>`;
  }
  if (pinsToo) for (const p of m.pins) out += `<circle cx="${p[0].toFixed(2)}" cy="${p[1].toFixed(2)}" r="0.9" fill="#6b4ea0"/>`;
  return out + `</svg>`;
}

const results = [];
const t0 = Date.now();
const log = (s) => console.log(`[${((Date.now() - t0) / 1000).toFixed(0)}s] ${s}`);
async function one(card) {
  const r = {...card};
  results.push(r);
  try {
    const grid = fs.readFileSync(path.join(OUT, card.name + "_grid.png"));
    const srcFile = fs.readdirSync(OUT).find((f) => f.startsWith(card.name + "_source2."));
    const src = fs.readFileSync(path.join(OUT, srcFile));
    const srcMime = srcFile.endsWith(".png") ? "image/png" : "image/jpeg";
    const before = cost();
    const t1 = Date.now();
    const got = await ask({system: MAPPER, role: "review", schema: SCHEMA, images: [dataUrl("image/png", grid)],
      prompt: `The drawing is of a ${card.thing}; the grid is ${card.N} by ${card.N}. The board wants at most ${card.most} panels (${BAND_NAMES[card.band]}); fewer is fine, but every facet of the drawing must be covered. Write the map.`});
    r.seconds = Math.round((Date.now() - t1) / 1000);
    r.dollars = Math.round((cost() - before) * 100) / 100;
    fs.writeFileSync(path.join(OUT, card.name + "_map.json"), JSON.stringify(got));
    const m = mesh(got, card.N);
    r.stats = m.stats;
    const raster = fx.raster({mime: srcMime, bytes: src});
    colourOff(raster, m);
    r.svgMap = svg(m, true);
    r.svgMapPlain = svg(m, false);
    const png = renderPng(m);
    fs.writeFileSync(path.join(OUT, card.name + "_map.png"), png);
    const eye = await ask({system: EYE, role: "review", schema: EYE_SCHEMA, images: [dataUrl("image/png", png), dataUrl(srcMime, src)],
      prompt: `Rubric: ${RUBRIC}\nChoices: ${CHOICES.join(", ")}.`});
    r.eye = {pick: String(eye.pick ?? "").toLowerCase(), score: Number(eye.score ?? 0), wrong: String(eye.wrong ?? ""), notes: String(eye.notes ?? "")};
    const prev = run2.hoop.find((c) => c.id === card.id && card.name.endsWith(c.variant));
    r.prev = prev ? {score: prev.eye.score, notes: prev.eye.notes, panels: prev.panels, pins: prev.pins, svg: prev.svgPanels, fine: prev.svgFine} : null;
    log(`${card.name}: model ${m.stats.asked} panels in ${r.seconds}s ($${r.dollars}); kept ${m.stats.panels} panels, ${m.stats.pins} pins; overlaps ${m.stats.overlaps}, tees ${m.stats.tees}, triple sides ${m.stats.triple}, concave ${m.stats.concave}, over 7 ${m.stats.over7}; eye ${r.eye.pick} ${r.eye.score} (reader was ${r.prev?.score}): ${r.eye.notes}`);
  } catch (e) {
    r.error = String(e).slice(0, 300);
    log(`${card.name} FAILED ${r.error}`);
  }
  fs.writeFileSync(path.join(OUT, "spike3.json"), JSON.stringify(results, null, 1));
  page();
}
function page() {
  const esc = (s) => String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;");
  let h = `<!doctype html><meta charset="utf-8"><title>Yarn Hoop map by a model</title><style>
  body{font-family:-apple-system,Helvetica,sans-serif;background:#f6f1e8;color:#2a2420;margin:24px} h1{font-size:22px}
  .card{background:#fff;border-radius:12px;padding:14px;margin:14px 0;display:flex;gap:14px;flex-wrap:wrap;align-items:flex-start}
  .col{display:flex;flex-direction:column;align-items:center;gap:6px;font-size:12px;color:#6b5f55} .col img{width:300px;height:300px;object-fit:contain;border-radius:8px;background:#fff}
  .col svg{width:300px;height:300px} .meta{width:100%;font-size:14px} .good{color:#2c6e2f} .bad{color:#a33} .note{font-size:13px;color:#6b5f55;max-width:960px} i{color:#555}
  </style><h1>Yarn Hoop map written by a model · ${new Date().toISOString().slice(0, 16)}</h1>
  <p class="note">Throwaway. The run-2 drawing with a numbered grid over it goes to the reviewer model (Opus), which writes pins and panels in grid coordinates. The mesh is snapped, checked the way the phone checks a map, coloured by the drawing's mean over each panel, and scored by the same eye as before. "Reader" is run 2's pixel reader on the same drawing, for comparison.</p>`;
  for (const r of results) {
    h += `<div class="card"><div class="meta"><b>${esc(r.thing)}</b> · ${BAND_NAMES[r.band]} · grid ${r.N} · at most ${r.most} panels` +
      (r.stats ? ` · model wrote ${r.stats.asked} panels in ${r.seconds}s for $${r.dollars} · kept ${r.stats.panels} panels, ${r.stats.pins} pins (${r.stats.snapped} snapped) · <span class="${r.stats.overlaps + r.stats.tees + r.stats.triple ? "bad" : "good"}">overlaps ${r.stats.overlaps}, T-junctions ${r.stats.tees}, sides shared by 3 ${r.stats.triple}, concave ${r.stats.concave}, over 7 corners ${r.stats.over7}</span>` : "") + `</div>`;
    if (r.error) { h += `<p class="bad">failed: ${esc(r.error)}</p></div>`; continue; }
    h += `<div class="col"><img src="${r.name}_grid.png"><span>the mapping field</span></div>` +
      `<div class="col">${r.svgMap}<span>the model's map (pins shown)</span></div>` +
      `<div class="col">${r.svgMapPlain}<span>the model's map, as knitted</span></div>` +
      (r.prev ? `<div class="col">${r.prev.svg}<span>reader's cut (run 2): ${r.prev.panels} panels, ${r.prev.pins} pins</span></div>` : "") +
      `<div class="meta"><p class="${r.eye.score >= 7 && r.eye.pick === r.thing ? "good" : "bad"}">eye on the model's map: <b>${esc(r.eye.pick)}</b> · score <b>${r.eye.score}</b> · <i>${esc(r.eye.notes)}</i></p>` +
      (r.prev ? `<p>eye on the reader's cut (run 2): score <b>${r.prev.score}</b> · <i>${esc(r.prev.notes)}</i></p>` : "") + `</div></div>`;
  }
  fs.writeFileSync(path.join(OUT, "spike3.html"), h);
}
(async () => {
  for (const c of CARDS) await one(c);
  log(`done: ${path.join(OUT, "spike3.html")} · $${cost().toFixed(2)}`);
})();
