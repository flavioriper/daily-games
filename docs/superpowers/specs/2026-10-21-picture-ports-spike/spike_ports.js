// SPIKE (throwaway): the picture ports' outcome on today's five things.
// Draws on flash through OpenRouter (no Vertex quota), reads each drawing
// with the night's own readers, renders what the player would see, has the
// reviewer judge it, and writes one HTML page of it all.
//   zsh -ilc 'node spike_ports.js <outdir>'
const fs = require("node:fs");
const path = require("node:path");
const F = "/Users/flavioriper/dev/daily/server/functions";
const {draw, ask} = require(F + "/lib/generate.js");
const fx = require(F + "/lib/facets.js");
const {readHoop, BANDS} = require(F + "/lib/hoop.js");
const {readJelly, RULES} = require(F + "/lib/jelly.js");
const {shrunk} = require(F + "/lib/vistas.js");
const {PNG} = require(F + "/node_modules/pngjs");

const OUT = process.argv[2];
const TAG = process.env.SPIKE_TAG || "";
const IMAGE_MODEL = process.env.SPIKE_IMAGE_MODEL || "google/gemini-2.5-flash-image";
const ONLY = (process.env.SPIKE_ONLY || "hoop,jelly").split(",");
const BAND_NAMES = ["Easy", "Medium", "Hard", "Insane"];

const THINGS = {
  boot: {name: "rain boot", draw: "a red rubber rain boot with a yellow cuff and a dark sole", creature: false, key: "cyan"},
  snail: {name: "snail", draw: "a garden snail with a brown spiral shell and a cream body with two eye stalks", creature: true, key: "magenta"},
  frog: {name: "frog", draw: "a green frog sitting up, with a pale yellow belly and big round eyes", creature: true, key: "magenta"},
  umbrella: {name: "umbrella", draw: "an open umbrella with yellow and red panels and a curved wooden handle", creature: false, key: "cyan"},
  kettle: {name: "kettle", draw: "a teal stovetop kettle with a cream arched handle and a red knob", creature: false, key: "magenta"},
};
const CHOICES = ["rain boot", "snail", "frog", "umbrella", "kettle", "teapot"];
const KEYS = {green: "pure green-screen chroma key (#00FF00)", magenta: "pure magenta chroma key (#FF00FF)", cyan: "pure cyan chroma key (#00FFFF)"};
// the jelly's key: never a colour near one of the six inks (lime ate the frog, green was lime)
const JELLY_KEY = {boot: "cyan", snail: "cyan", frog: "magenta", umbrella: "cyan", kettle: "cyan"};

// --- prompts (the spike's; the port's would be these, tuned) ---
const HOOP = (t, withRef) => `A low-poly illustration of ${t.draw}, built from at least 150 and about 200 small flat polygon facets (mostly triangles), the big surfaces broken into many small facets too${withRef ? ", in exactly the style of the reference picture" : ""}: a soft, muted, harmonious palette of gentle earthy pastels; each facet is ONE flat solid colour; neighbouring facets shift subtly in tone as if lit softly from the top left (a light, a mid and a shadow tone of each colour); crisp straight edges; no outlines, no lines between facets, no gradient inside a facet, no texture. ${t.creature ? "" : "It is an object: no face, no eyes, no mouth. "}One thing only, centred and large, filling most of the picture, on a plain flat solid ${KEYS[t.key]} background filling the whole picture edge to edge; no cast shadow, no ground, nothing else, no text. A square picture.`;

const INK_NAMES = ["cherry red #e2495a", "orange #f39237", "lemon yellow #f4d44a", "lime green #79c94f", "blueberry blue #4a86df", "grape purple #9a62d2"];
const INKS = ["#e2495a", "#f39237", "#f4d44a", "#79c94f", "#4a86df", "#9a62d2"];
const DRAWN = [{colours: "exactly 2", shapes: "2 to 4 big"}, {colours: "exactly 3", shapes: "3 to 6 big"}, {colours: "3 or 4", shapes: "4 to 8"}, {colours: "4 to 6", shapes: "6 to 12"}];
const KEYBG = (k) => `a plain flat solid ${KEYS[k]} background filling the whole picture edge to edge`;
const JELLY = (t, band) => {
  const rule = RULES[band];
  const mixed = rule.mixed === 0 ? "" : ` At least ${rule.mixed} of the colours you use must be orange, lime green or grape purple.`;
  return `A cute ${t.draw} drawn as a flat children's sticker of ${DRAWN[band].shapes} smooth rounded shapes, using ${DRAWN[band].colours} of these six exact flat colours and no others: ${INK_NAMES.join(", ")}.${mixed} Each shape one solid colour, shapes touching edge to edge with no gaps. No outlines at all, no dark edge lines, no black, and no white, cream or grey anywhere in it (every part of the thing, body included, is one of the six colours), no shading, no gradients, no highlights, no texture, no thin lines or small dots. The shapes are clean and well proportioned: a sharp, true silhouette of the thing that a child names at once, drawn with care. Any spots or small details in one of the six colours too. One thing only, centred and large, filling most of the picture, on ${KEYBG(JELLY_KEY[t.id] || "cyan")}, nothing else, no white sticker border round it, no shadow, no text. A square picture.`;
};

// --- the eye ---
const EYE = `You review pictures for a children's puzzle game. You are shown the picture the player will see (the game's own reading of a drawing) and, after it, the drawing it was read from. Judge the FIRST picture, strictly and honestly, as a polished product would be judged. Answer one JSON object: "pick" is which thing the first picture shows, exactly one of the choices given or "none"; "score" is 0 to 10 on the rubric given (10 is elegant, complete and polished, 7 is good enough to ship, under 5 is not); "wrong" is an empty string unless something does not belong in a game for children; "notes" is one sentence naming what would most improve it (or "nothing").`;
const RUBRIC = {
  hoop: "A low-poly picture of the thing: the WHOLE thing is present with every part a child expects (a frog has its green body, a kettle its spout and handle), in its true colours; the facets read as soft light and shade, the palette is soft and harmonious; an object has no face; nothing but the thing; it looks elegant and polished.",
  jelly: "A flat jelly sticker of the thing in a few candy colours: the silhouette is sharp, clean and true to the thing so a child names it at once; the parts are big and well proportioned; no stray blobs, slivers or ragged edges; it looks elegant and polished.",
};
const SCHEMA = {type: "object", additionalProperties: false, required: ["pick", "score", "wrong", "notes"],
  properties: {pick: {type: "string"}, score: {type: "number"}, wrong: {type: "string"}, notes: {type: "string"}}};
async function eye(game, renderUrl, sourceUrl, thing) {
  const got = await ask({system: EYE, role: "review", schema: SCHEMA, images: [renderUrl, sourceUrl],
    prompt: `Rubric: ${RUBRIC[game]}\nChoices: ${CHOICES.join(", ")}.`});
  const pick = String(got.pick ?? "").trim().toLowerCase();
  return {pick, score: Number(got.score ?? 0), wrong: String(got.wrong ?? ""), notes: String(got.notes ?? ""), ok: pick === thing.name && String(got.wrong ?? "") === ""};
}

// --- helpers ---
const dataUrl = (d) => `data:${d.mime};base64,${d.bytes.toString("base64")}`;
const hex = (c) => "#" + c.map((v) => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, "0")).join("");
function pngOf(w, h, paint) {
  const png = new PNG({width: w, height: h});
  paint(png.data, w, h);
  return {mime: "image/png", bytes: PNG.sync.write(png)};
}
function fill(data, w, i, r, g, b) { data[i * 4] = r; data[i * 4 + 1] = g; data[i * 4 + 2] = b; data[i * 4 + 3] = 255; }
const LINEN = [0xef, 0xe2, 0xc6];
function loadRef(file) { return {mime: "image/png", bytes: fs.readFileSync(file)}; }
function keep(name, d) { fs.writeFileSync(path.join(OUT, name + TAG + (d.mime === "image/png" ? ".png" : ".jpg")), d.bytes); }

// --- Yarn Hoop: the fine picture (the night's regions before they are joined to the band's count) and today's coarse cut ---
function fineHoop(drawing, band) {
  const r = fx.raster(drawing);
  const bg = fx.board(r);
  const rule = BANDS[band];
  let reg = fx.unshadow(fx.grow(r, bg, 16), r);
  reg = fx.dissolve(reg, r, Math.max(8, rule.least * rule.least * 0.2), 1);
  reg = fx.unring(reg, r);
  const n = r.n;
  let x0 = n, y0 = n, x1 = 0, y1 = 0, count = 0;
  for (let i = 0; i < n * n; i++) if (reg.label[i] >= 0) { const x = i % n, y = (i - x) / n; x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x + 1); y1 = Math.max(y1, y + 1); }
  count = reg.size.filter((s) => s > 0).length;
  const up = 2;
  const fine = pngOf(n * up, n * up, (data, w) => {
    for (let y = 0; y < w; y++) for (let x = 0; x < w; x++) {
      const l = reg.label[Math.floor(y / up) * n + Math.floor(x / up)];
      const c = l >= 0 ? reg.colour[l] : LINEN;
      fill(data, w, y * w + x, c[0], c[1], c[2]);
    }
  });
  const coarse = readHoop(r, band);
  return {fine, count, bbox: [x0, y0, x1, y1], n, coarse};
}
function hoopSvg(h, showFine, showPanels) {
  const [bx0, by0, bx1, by1] = h.bbox;
  const s = 100 / Math.max(bx1 - bx0, by1 - by0);
  const ox = (100 - (bx1 - bx0) * s) / 2, oy = (100 - (by1 - by0) * s) / 2;
  let out = `<svg viewBox="-2 -2 104 104" width="260" height="260" style="background:#efe2c6;border-radius:8px">`;
  if (showFine) out += `<image href="${dataUrl(h.fine)}" x="${-bx0 * s + ox}" y="${-by0 * s + oy}" width="${h.n * s}" height="${h.n * s}" style="image-rendering:auto"/>`;
  const p = h.coarse.pins;
  for (const panel of h.coarse.panels) {
    const pts = panel.k.map((k) => `${p[2 * k]},${p[2 * k + 1]}`).join(" ");
    out += showPanels === "fill" ? `<polygon points="${pts}" fill="${panel.c}" stroke="${panel.c}" stroke-width="0.6"/>` :
      `<polygon points="${pts}" fill="none" stroke="rgba(120,60,40,0.55)" stroke-width="0.7" stroke-linejoin="round"/>`;
  }
  return out + `</svg>`;
}

// --- Gumdrop: the parts as the viewer and the card draw them ---
function outline(s) {
  let p = [];
  for (let i = 0; i + 1 < s.n.length; i += 2) p.push([s.n[i], s.n[i + 1]]);
  for (let t = 0; t < (s.kind === "soft" ? 2 : 1); t++) {
    const q = [];
    for (let i = 0; i < p.length; i++) {
      const a = p[i], b = p[(i + 1) % p.length];
      q.push([a[0] + (b[0] - a[0]) * 0.25, a[1] + (b[1] - a[1]) * 0.25]);
      q.push([a[0] + (b[0] - a[0]) * 0.75, a[1] + (b[1] - a[1]) * 0.75]);
    }
    p = q;
  }
  return p;
}
const FLAV = {cherry: 0, orange: 1, lemon: 2, lime: 3, blueberry: 4, grape: 5};
function scanFill(data, w, poly, rgb) {
  // poly in 0..100, the png w wide
  const k = w / 100;
  const pts = poly.map(([x, y]) => [x * k, y * k]);
  for (let y = 0; y < w; y++) {
    const xs = [];
    for (let i = 0; i < pts.length; i++) {
      const a = pts[i], b = pts[(i + 1) % pts.length];
      if ((a[1] <= y + 0.5) !== (b[1] <= y + 0.5)) xs.push(a[0] + (y + 0.5 - a[1]) * (b[0] - a[0]) / (b[1] - a[1]));
    }
    xs.sort((p, q) => p - q);
    for (let i = 0; i + 1 < xs.length; i += 2) {
      for (let x = Math.max(0, Math.round(xs[i])); x < Math.min(w, Math.round(xs[i + 1])); x++) fill(data, w, y * w + x, rgb[0], rgb[1], rgb[2]);
    }
  }
}
function jellyPng(parts) {
  return pngOf(480, 480, (data, w) => {
    for (let i = 0; i < w * w; i++) fill(data, w, i, 0xf3, 0xea, 0xd8);
    for (const part of parts) {
      const c = INKS[FLAV[part.flavour]];
      const rgb = [parseInt(c.slice(1, 3), 16), parseInt(c.slice(3, 5), 16), parseInt(c.slice(5, 7), 16)];
      for (const s of part.shapes) scanFill(data, w, outline(s), rgb);
    }
  });
}
function jellySvg(parts, glossy) {
  let out = `<svg viewBox="0 0 100 100" width="260" height="260" style="background:#f3ead8;border-radius:8px">`;
  if (glossy) out += `<defs><filter id="gum" x="-20%" y="-20%" width="140%" height="140%" primitiveUnits="userSpaceOnUse">
  <feGaussianBlur in="SourceAlpha" stdDeviation="2.2" result="bump"/>
  <feSpecularLighting in="bump" surfaceScale="7" specularConstant="0.85" specularExponent="18" lighting-color="#ffffff" result="spec"><fePointLight x="20" y="-10" z="120"/></feSpecularLighting>
  <feComposite in="spec" in2="SourceAlpha" operator="in" result="specIn"/>
  <feGaussianBlur in="SourceAlpha" stdDeviation="3.5" result="soft"/>
  <feComposite in="soft" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="innerA"/>
  <feFlood flood-color="#3a1a30" flood-opacity="0.35" result="dark"/>
  <feComposite in="dark" in2="innerA" operator="in" result="rim"/>
  <feGaussianBlur in="SourceAlpha" stdDeviation="2" result="sh"/><feOffset in="sh" dx="1.5" dy="2.5" result="shOff"/>
  <feFlood flood-color="#5a3a2a" flood-opacity="0.25"/><feComposite in2="shOff" operator="in" result="shadow"/>
  <feMerge><feMergeNode in="shadow"/><feMergeNode in="SourceGraphic"/><feMergeNode in="rim"/><feMergeNode in="specIn"/></feMerge>
  </filter></defs>`;
  out += glossy ? `<g filter="url(#gum)">` : `<g>`;
  for (const part of parts) {
    const c = INKS[FLAV[part.flavour]];
    for (const s of part.shapes) out += `<polygon points="${outline(s).map((v) => v.map((x) => x.toFixed(2)).join(",")).join(" ")}" fill="${c}" stroke="${c}" stroke-width="0.4" stroke-linejoin="round"/>`;
  }
  return out + `</g></svg>`;
}

// --- the run ---
const results = {hoop: [], jelly: []};
function save() { fs.writeFileSync(path.join(OUT, `spike${TAG}.json`), JSON.stringify(results, null, 1)); }
const t0 = Date.now();
const log = (s) => console.log(`[${((Date.now() - t0) / 1000).toFixed(0)}s] ${s}`);

async function hoopRun(band, id, variant) {
  const t = THINGS[id];
  const card = {band, id, variant, name: t.name};
  results.hoop.push(card);
  try {
    const ref = loadRef(path.join(OUT, "ref_hoop_snail.png"));
    const o = variant === "ref" ? {images: [ref]} : {};
    const drawing = await draw(HOOP(t, variant === "ref"), IMAGE_MODEL, o);
    keep(`hoop${band}_${id}_${variant}_source`, drawing);
    const small = shrunk(drawing);
    card.source = dataUrl(small);
    const h = fineHoop(drawing, band);
    keep(`hoop${band}_${id}_${variant}_fine`, h.fine);
    card.fineCount = h.count;
    card.panels = h.coarse.panels.length;
    card.pins = h.coarse.pins.length / 2;
    card.why = h.coarse.why;
    card.svgFine = hoopSvg(h, true, "none");
    card.svgPanels = hoopSvg(h, false, "fill");
    card.svgBoth = hoopSvg(h, true, "lines");
    card.eye = await eye("hoop", dataUrl(h.fine), dataUrl(small), t);
    log(`hoop ${BAND_NAMES[band]} ${id} ${variant}: ${h.count} fine, ${card.panels} panels, ${card.pins} pins${card.why ? " (" + card.why + ")" : ""}; eye ${card.eye.pick} ${card.eye.score}: ${card.eye.notes}`);
  } catch (e) {
    card.error = String(e).slice(0, 300);
    log(`hoop ${BAND_NAMES[band]} ${id} ${variant} FAILED ${card.error}`);
  }
  save();
}
async function jellyRun(band, id) {
  const t = THINGS[id];
  const card = {band, id, name: t.name};
  results.jelly.push(card);
  try {
    const drawing = await draw(JELLY(t, band), IMAGE_MODEL);
    keep(`jelly${band}_${id}_source`, drawing);
    const small = shrunk(drawing);
    card.source = dataUrl(small);
    const got = readJelly(drawing, band);
    card.why = got.why;
    card.parts = got.parts.length;
    card.flavours = [...new Set(got.parts.map((p) => p.flavour))].join(", ");
    const render = jellyPng(got.parts);
    keep(`jelly${band}_${id}_render`, render);
    card.svgFlat = jellySvg(got.parts, false);
    card.svgGlossy = jellySvg(got.parts, true);
    card.eye = await eye("jelly", dataUrl(render), dataUrl(small), t);
    log(`jelly ${BAND_NAMES[band]} ${id}: ${card.parts} parts (${card.flavours})${card.why ? " refused: " + card.why : ""}; eye ${card.eye.pick} ${card.eye.score}: ${card.eye.notes}`);
  } catch (e) {
    card.error = String(e).slice(0, 300);
    log(`jelly ${BAND_NAMES[band]} ${id} FAILED ${card.error}`);
  }
  save();
}

function page() {
  const esc = (s) => String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;");
  const verdict = (c) => c.error ? `<p class="bad">failed: ${esc(c.error)}</p>` : `<p class="eye ${c.eye.ok && c.eye.score >= 7 ? "good" : "bad"}">eye: <b>${esc(c.eye.pick)}</b> · score <b>${c.eye.score}</b>${c.eye.wrong ? " · wrong: " + esc(c.eye.wrong) : ""}<br><i>${esc(c.eye.notes)}</i></p>`;
  let h = `<!doctype html><meta charset="utf-8"><title>Picture ports spike</title><style>
  body{font-family:-apple-system,Helvetica,sans-serif;background:#f6f1e8;color:#2a2420;margin:24px}
  h1{font-size:22px} h2{margin-top:36px} .card{background:#fff;border-radius:12px;padding:14px;margin:14px 0;display:flex;gap:14px;flex-wrap:wrap;align-items:flex-start}
  .col{display:flex;flex-direction:column;align-items:center;gap:6px;font-size:12px;color:#6b5f55} .col img{width:260px;height:260px;object-fit:contain;border-radius:8px;background:#fff}
  .meta{width:100%;font-size:14px} .eye{font-size:14px} .good{color:#2c6e2f} .bad{color:#a33} .note{font-size:13px;color:#6b5f55;max-width:900px}
  </style><h1>Picture ports spike${TAG ? " · run " + TAG : ""} · ${new Date().toISOString().slice(0, 16)} · drawings on ${esc(IMAGE_MODEL)}</h1>
  <p class="note">Throwaway. Each card: the model's drawing (what the port asked for), then what the player would see. The eye is the reviewer model shown the player's picture and the drawing, asked to name the thing and score it 0-10 on the game's rubric. Hoop: "fine" is the night's regions before they are joined down to the band's panel count (the picture a panel would knit in as); "today" is the cut as it ships now; "both" lays today's panel outlines over the fine picture. Gumdrop: the parts as read, flat as today and with a gummy finish (drawing only, no data change).</p>`;
  h += `<h2>Yarn Hoop</h2>`;
  for (const c of results.hoop) {
    h += `<div class="card"><div class="meta"><b>${esc(c.name)}</b> · ${BAND_NAMES[c.band]} · ${c.variant === "ref" ? "with the style reference" : "words only"} · key ${THINGS[c.id].key}${c.panels !== undefined ? ` · fine regions ${c.fineCount} · today's cut ${c.panels} panels, ${c.pins} pins` : ""}${c.why ? ` · <span class="bad">${esc(c.why)}</span>` : ""}</div>`;
    if (!c.error) h += `<div class="col"><img src="${c.source}"><span>drawing</span></div><div class="col">${c.svgFine}<span>fine (player's picture)</span></div><div class="col">${c.svgPanels}<span>today's panels</span></div><div class="col">${c.svgBoth}<span>both</span></div>`;
    h += `<div class="meta">${verdict(c)}</div></div>`;
  }
  h += `<h2>Gumdrop jellies</h2>`;
  for (const c of results.jelly) {
    h += `<div class="card"><div class="meta"><b>${esc(c.name)}</b> · ${BAND_NAMES[c.band]} · key ${JELLY_KEY[c.id]}${c.parts !== undefined ? ` · ${c.parts} parts · ${esc(c.flavours)}` : ""}${c.why ? ` · <span class="bad">refused: ${esc(c.why)}</span>` : ""}</div>`;
    if (!c.error) h += `<div class="col"><img src="${c.source}"><span>drawing</span></div><div class="col">${c.svgFlat}<span>flat (today)</span></div><div class="col">${c.svgGlossy}<span>gummy finish</span></div>`;
    h += `<div class="meta">${verdict(c)}</div></div>`;
  }
  fs.writeFileSync(path.join(OUT, `spike${TAG}.html`), h);
}

(async () => {
  const hoops = [[0, "snail"], [1, "frog"], [2, "umbrella"], [3, "kettle"]];
  const jellies = [[0, "boot"], [1, "snail"], [2, "frog"], [3, "kettle"]];
  if (ONLY.includes("hoop")) for (const [b, id] of hoops) { await hoopRun(b, id, "ref"); page(); await hoopRun(b, id, "words"); page(); }
  if (ONLY.includes("jelly")) for (const [b, id] of jellies) { await jellyRun(b, id); page(); }
  page();
  log(`done: ${path.join(OUT, `spike${TAG}.html`)}`);
})();
