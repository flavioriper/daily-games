// An image as a bead picture, and the bank's rules for one. One file for the
// two that make pictures: tools/build_dashboard.py inlines it into the page's
// Picture maker, and server/functions copies it into src/ (`npm run build`)
// for the night's pictures, so the page tries exactly what the night runs.
// Pure functions on bytes: each side brings its own (a canvas, a decoder).
// No module syntax; the tail exports where there is a `module`.
//
// The image is cut to a square, laid on the band's grid, and each square
// takes the nearest of the game's beads in OKLab, where near means near to
// the eye; the band's colour count is kept by dropping the bead that costs
// the picture least, one at a time. The rules are
// tools/check_pixel_garden.py's check(), which stays the judge.
var Beads = (function () {
  "use strict";
  // content/pixel_garden.json's letters in core/palette.gd's PG_BEADS.
  // The bank's beads (content/pixel_garden.json, core/palette.gd PG_BEADS,
  // tools/check_pixel_garden.py BEADS: the four stay the same). The six
  // added on 2026-10-14 (a maroon, h coral, j butter, q rust, v navy, x
  // silver) are the shadow and light tones shaded pixel art needs: without
  // them a mushroom's maroon shadow read as brown and its grey spots as sky.
  var PALETTE = { a: "a83a30", r: "e0503a", h: "f28c78", q: "c66a24", o: "f08a2c", y: "f4c640", j: "fbe28e", c: "f3e6c8",
    w: "fbf7ee", p: "f4a3b4", s: "d9607a", l: "b99ad8", u: "7e5aa6", k: "8cc4e8", b: "4a7fc1", v: "2e4f80", t: "4fae9c",
    i: "a8cf5a", g: "5fa845", f: "2f7a3f", n: "d4a56a", m: "8a5a36", d: "4a3226", x: "d5d1c9", e: "a9a39a" };
  // Button Box's Hard (16) has no written rule: it is held to what its
  // thirty pictures are, and `loose` says so.
  // `lead` is not the bank's rule but Button Box's (buttons_state.gd): its
  // buttons open as whole colours traded along, and a picture over half one
  // colour opens with that colour's surplus already sewn; past a quarter of
  // the cloth sewn it will not deal the picture. A made picture is for all
  // three boards, so its biggest colour stays under LEAD of its beads.
  var LEAD = .6;
  // A themed picture (2026-10-14, after the user set real bead art beside
  // ours: "this is what I wanted, something really amazing"): one shaded
  // subject on a bare board at every band, a square of any side within the
  // band's range, so a drawing is kept at the squares it was drawn at and
  // never redrawn to the band's. `side` is the range, the key the band's
  // own side (what the boards ask for); fill is of the picture's own
  // square, and every band leaves an edge bare. core/themed_pictures.gd
  // holds the same rules for the phone: the two change together.
  var RULES = { 10: { side: [10, 18], colours: [3, 7], fill: [.25, .8], small: true, lead: LEAD },
    12: { side: [12, 22], colours: [4, 7], fill: [.25, .8], small: true, lead: LEAD },
    24: { side: [24, 34], colours: [6, 12], fill: [.25, .8], small: true, lead: LEAD },
    32: { side: [32, 40], colours: [8, 14], fill: [.25, .8], small: true, lead: LEAD },
    // Button Box's Insane alone (the user, 2026-10-14: "insane should be a
    // really big and detailed image"): asked 40, the model drew a cottage
    // at 64 × 61 that read clean.
    48: { side: [44, 64], colours: [10, 16], fill: [.25, .8], small: true, lead: LEAD } };
  var CUT_FILL = [.3, .7], MOST = .45, WORK = 240;
  var DEFAULTS = { size: 10, frame: "subject", bg: "auto", tol: .1, margin: 1, colours: 4, zoom: 1, px: 0, py: 0, vivid: 1 };

  function lin(v) { v /= 255; return v <= .04045 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4); }
  function oklab(r, g, b) {
    var l = Math.cbrt(.4122214708 * r + .5363325363 * g + .0514459929 * b), m = Math.cbrt(.2119034982 * r + .6806995451 * g + .1073969566 * b),
      s = Math.cbrt(.0883024619 * r + .2817188376 * g + .6299787005 * b);
    return [.2104542553 * l + .793617785 * m - .0040720468 * s, 1.9779984951 * l - 2.428592205 * m + .4505937099 * s,
      .0259040371 * l + .7827717662 * m - .808675766 * s];
  }
  var LETTERS = Object.keys(PALETTE);
  var LAB = LETTERS.map(function (ch) { var h = PALETTE[ch];
    return oklab(lin(parseInt(h.slice(0, 2), 16)), lin(parseInt(h.slice(2, 4), 16)), lin(parseInt(h.slice(4, 6), 16))); });

  function rulesOf(n) { return RULES[n] || { colours: [1, LETTERS.length], fill: [0, 1], loose: true }; }
  function fillOf(rows) { var flat = rows.join(""); return flat.replace(/\./g, "").length / flat.length; }
  // The defaults a size is made with: a cut-out where its pictures are
  // cut-outs, a square of the image where they are scenes.
  function optionsFor(n) {
    var rule = rulesOf(n), cut = rule.fill[1] < .85, o = {};
    for (var k in DEFAULTS) o[k] = DEFAULTS[k];
    o.size = n; o.colours = rule.colours[1]; o.frame = cut ? "subject" : "crop"; o.bg = cut ? "auto" : "alpha";
    return o;
  }
  // check_pixel_garden.py's check(), for one picture: [{ok, text}].
  function check(rows, n) {
    var rule = rulesOf(n), flat = rows.join(""), out = [], pct = function (v) { return Math.round(v * 100) + "%"; };
    var used = flat.replace(/\./g, "").split("").filter(function (c, i, a) { return a.indexOf(c) === i; }), filled = fillOf(rows);
    var cut = !!rule.cut && filled >= CUT_FILL[0] && filled <= CUT_FILL[1];
    var lo = cut ? rule.cut : rule.colours[0], hi = rule.colours[1], side = rows.length;
    var square = rows.every(function (r) { return r.length === side; });
    if (rule.side) out.push({ ok: square && side >= rule.side[0] && side <= rule.side[1],
      text: (square ? side + " a side" : "not square") + ", wants " + rule.side[0] + "–" + rule.side[1] });
    else out.push({ ok: square && side === n, text: (square ? side + " a side" : "not square") + ", wants " + n });
    out.push({ ok: used.length >= lo && used.length <= hi, text: used.length + " colours, wants " + lo + "–" + hi });
    out.push({ ok: cut || (filled >= rule.fill[0] && filled <= rule.fill[1]),
      text: pct(filled) + " filled, wants " + pct(rule.fill[0]) + "–" + pct(rule.fill[1]) + (rule.cut ? (cut ? " (a cut-out)" : " or a cut-out at 30%–70%") : "") });
    if (rule.cut) {
      var share = used.reduce(function (m, c) { return Math.max(m, flat.split(c).length - 1); }, 0) / flat.length;
      out.push({ ok: share < MOST, text: "largest colour " + pct(share) + " of it, wants under " + pct(MOST) });
    }
    if (rule.lead) {
      var lead = used.reduce(function (m, c) { return Math.max(m, flat.split(c).length - 1); }, 0) / Math.max(1, flat.replace(/\./g, "").length);
      out.push({ ok: lead < rule.lead, text: "largest colour " + pct(lead) + " of its beads, Button Box wants under " + pct(rule.lead) });
    }
    if (rule.small) {
      var all = [rows[0], rows[side - 1], rows.map(function (r) { return r[0]; }).join(""), rows.map(function (r) { return r[side - 1]; }).join("")]
        .every(function (e) { return /[^.]/.test(e); });
      out.push({ ok: !all, text: all ? "touches all four edges" : "leaves an edge bare" });
    }
    return out;
  }
  // The source no more than WORK a side, each pixel the mean of what it covers.
  function shrink(rgba, w, h) {
    var s = Math.min(1, WORK / Math.max(w, h)), w2 = Math.max(1, Math.round(w * s)), h2 = Math.max(1, Math.round(h * s));
    if (w2 === w && h2 === h) return { px: rgba, w: w, h: h };
    var px = new Uint8ClampedArray(w2 * h2 * 4);
    for (var y = 0; y < h2; y++) {
      var y0 = Math.floor(y * h / h2), y1 = Math.max(y0 + 1, Math.floor((y + 1) * h / h2));
      for (var x = 0; x < w2; x++) {
        var x0 = Math.floor(x * w / w2), x1 = Math.max(x0 + 1, Math.floor((x + 1) * w / w2)), t = [0, 0, 0, 0], n = 0;
        for (var v = y0; v < y1; v++) for (var u = x0; u < x1; u++) { var i = 4 * (v * w + u); t[0] += rgba[i]; t[1] += rgba[i + 1]; t[2] += rgba[i + 2]; t[3] += rgba[i + 3]; n++; }
        var o = 4 * (y * w2 + x); px[o] = t[0] / n; px[o + 1] = t[1] / n; px[o + 2] = t[2] / n; px[o + 3] = t[3] / n;
      }
    }
    return { px: px, w: w2, h: h2 };
  }
  // The source at working size, with what of it is background: what is
  // transparent and, unless "alpha", what is the border's colour: joined to
  // the border ("auto") or anywhere ("all").
  function work(rgba, sw, sh, opt) {
    var small = shrink(rgba, sw, sh), px = small.px, w = small.w, h = small.h, n = w * h, i;
    var rgb = new Float32Array(n * 3), lab = new Float32Array(n * 3), bg = new Uint8Array(n);
    for (i = 0; i < n; i++) {
      var r = lin(px[4 * i]), g = lin(px[4 * i + 1]), b = lin(px[4 * i + 2]);
      rgb.set([r, g, b], 3 * i); lab.set(oklab(r, g, b), 3 * i);
      if (px[4 * i + 3] < 128) bg[i] = 1;
    }
    if (opt.bg !== "alpha") {
      var border = [], x, y;
      for (x = 0; x < w; x++) border.push(x, n - w + x);
      for (y = 1; y < h - 1; y++) border.push(y * w, y * w + w - 1);
      var buckets = {}, most = null;
      border.forEach(function (j) { if (bg[j]) return;
        var k = (px[4 * j] >> 4) << 8 | (px[4 * j + 1] >> 4) << 4 | px[4 * j + 2] >> 4;
        (buckets[k] = buckets[k] || []).push(j); if (!most || buckets[k].length > most.length) most = buckets[k]; });
      if (most) {
        var ref = [0, 1, 2].map(function (c) { return most.reduce(function (t, j) { return t + lab[3 * j + c]; }, 0) / most.length; }), t2 = opt.tol * opt.tol;
        var near = function (j) { return Math.pow(lab[3 * j] - ref[0], 2) + Math.pow(lab[3 * j + 1] - ref[1], 2) + Math.pow(lab[3 * j + 2] - ref[2], 2) < t2; };
        var seen = new Uint8Array(n), stack = [];
        var push = function (j) { if (!seen[j] && (bg[j] || near(j))) { seen[j] = 1; bg[j] = 1; stack.push(j); } };
        // "all" leaves bare what is the edge colour anywhere, a hole in the subject too.
        if (opt.bg === "all") { for (i = 0; i < n; i++) if (near(i)) bg[i] = 1; }
        else border.forEach(push);
        while (stack.length) { var j = stack.pop(), jx = j % w;
          if (jx) push(j - 1); if (jx < w - 1) push(j + 1); if (j >= w) push(j - w); if (j < n - w) push(j + w); }
      }
    }
    return { w: w, h: h, rgb: rgb, bg: bg };
  }
  // The square of the source the picture is cut from: its corner and a cell's side.
  function frame(wk, opt) {
    var N = opt.size, w = wk.w, h = wk.h;
    if (opt.frame === "subject") {
      var x0 = w, y0 = h, x1 = -1, y1 = -1;
      for (var i = 0; i < w * h; i++) if (!wk.bg[i]) { var x = i % w, y = (i - x) / w;
        if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
      if (x1 < 0) { x0 = 0; y0 = 0; x1 = w - 1; y1 = h - 1; }
      var bw = x1 - x0 + 1, bh = y1 - y0 + 1, cs = Math.max(bw, bh) / Math.max(1, N - 2 * opt.margin);
      return [x0 + bw / 2 - N * cs / 2, y0 + bh / 2 - N * cs / 2, cs];
    }
    var side = (opt.frame === "crop" ? Math.min(w, h) : Math.max(w, h)) / opt.zoom;
    return [w / 2 + opt.px * Math.abs(w - side) / 2 - side / 2, h / 2 + opt.py * Math.abs(h - side) / 2 - side / 2, side / N];
  }
  // A cell's colour: the mean of what it covers that is not background, in
  // OKLab; null where over half of it is background.
  function cells(wk, fr, opt) {
    var N = opt.size, w = wk.w, h = wk.h, out = [];
    var span = function (a, b) { var i0 = Math.ceil(a - .5), i1 = Math.ceil(b - .5) - 1; if (i1 < i0) i0 = i1 = Math.floor((a + b) / 2); return [i0, i1]; };
    for (var cy = 0; cy < N; cy++) for (var cx = 0; cx < N; cx++) {
      var X = span(fr[0] + cx * fr[2], fr[0] + (cx + 1) * fr[2]), Y = span(fr[1] + cy * fr[2], fr[1] + (cy + 1) * fr[2]);
      var tot = 0, fg = 0, r = 0, g = 0, b = 0;
      for (var y = Y[0]; y <= Y[1]; y++) for (var x = X[0]; x <= X[1]; x++) {
        tot++;
        if (x < 0 || y < 0 || x >= w || y >= h || wk.bg[y * w + x]) continue;
        var i = 3 * (y * w + x); fg++; r += wk.rgb[i]; g += wk.rgb[i + 1]; b += wk.rgb[i + 2];
      }
      if (!fg || fg * 2 < tot) { out.push(null); continue; }
      var L = oklab(r / fg, g / fg, b / fg);
      out.push([L[0], L[1] * opt.vivid, L[2] * opt.vivid]);
    }
    return out;
  }
  // Each cell's bead (an index into LETTERS, -1 bare), in no more than k colours.
  function pick(cs, k) {
    var d = cs.map(function (c) { return c && LAB.map(function (b) { return Math.pow(c[0] - b[0], 2) + Math.pow(c[1] - b[1], 2) + Math.pow(c[2] - b[2], 2); }); });
    var kept = LETTERS.map(function (_, i) { return i; });
    var assign = function () { return d.map(function (row) { return row ? kept.reduce(function (a, i) { return row[i] < row[a] ? i : a; }, kept[0]) : -1; }); };
    var at = assign();
    kept = kept.filter(function (i) { return at.indexOf(i) >= 0; });
    while (kept.length > k) {
      var drop = -1, least = Infinity;
      kept.forEach(function (out) {
        var rest = kept.filter(function (i) { return i !== out; }), cost = 0;
        at.forEach(function (a, j) { if (a === out) cost += Math.min.apply(null, rest.map(function (i) { return d[j][i]; })) - d[j][out]; });
        if (cost < least) { least = cost; drop = out; }
      });
      kept = kept.filter(function (i) { return i !== drop; }); at = assign();
    }
    return at;
  }
  // RGBA bytes as a picture's rows; `work` and `frame` are handed back for a
  // page that shows what was taken for background and where the square fell.
  function convert(rgba, w, h, opt) {
    var wk = work(rgba, w, h, opt), fr = frame(wk, opt), at = pick(cells(wk, fr, opt), opt.colours), N = opt.size, rows = [];
    for (var y = 0; y < N; y++) rows.push(at.slice(y * N, y * N + N).map(function (a) { return a < 0 ? "." : LETTERS[a]; }).join(""));
    return { rows: rows, work: wk, frame: fr };
  }

  // Pixel art read as drawn, never averaged down: an image model asked for
  // pixel art answers a big picture of squares, of a side it chose and laid
  // a little unevenly. The squares' lines are found from where the colour
  // changes, each square takes the colour at its middle, and the picture is
  // kept only at its own size: padded into the band's square when smaller,
  // turned down when bigger or when the squares do not hold one colour each.
  var EDGE = .06, SNAP_TOL = .12, MIXED = .05;
  function dist2(a, i, b, j) { var x = a[i] - b[j], y = a[i + 1] - b[j + 1], z = a[i + 2] - b[j + 2]; return x * x + y * y + z * z; }
  // Each column's (or row's) count of colour changes from the one before.
  function profiles(lab, w, h) {
    var col = new Float32Array(w), row = new Float32Array(h), e2 = EDGE * EDGE;
    for (var y = 0; y < h; y++) for (var x = 0; x < w; x++) { var i = 3 * (y * w + x);
      if (x && dist2(lab, i, lab, i - 3) > e2) col[x]++;
      if (y && dist2(lab, i, lab, i - 3 * w) > e2) row[y]++; }
    return [col, row];
  }
  // The pitch and phase whose lines the most changes fall on, past what a
  // line's width would catch by chance (so half the pitch, which catches
  // every line too, scores less).
  // One axis at one pitch: its best phase and score.
  function phaseOf(prof, total, p) {
    var tol = Math.min(2.5, p * .12), best = { p: p, phase: 0, score: -1 };
    for (var ph = 0; ph < p; ph += .5) {
      var on = 0;
      for (var x = 0; x < prof.length; x++) if (prof[x]) { var d = (x - ph) % p; if (d < 0) d += p; if (Math.min(d, p - d) <= tol) on += prof[x]; }
      var score = on / total - (2 * tol + 1) / p;
      if (score > best.score) best = { p: p, phase: ph, score: score };
    }
    return best;
  }
  // Pixel art's squares are square: one pitch for both axes, each its phase.
  function pitchOf(col, row, lo, hi) {
    var tc = 0, tr = 0, x, all = [];
    for (x = 0; x < col.length; x++) tc += col[x];
    for (x = 0; x < row.length; x++) tr += row[x];
    if (!tc || !tr) return [];
    for (var p = lo; p <= hi; p += .25) {
      var gx = phaseOf(col, tc, p), gy = phaseOf(row, tr, p);
      all.push({ g: [gx, gy], score: gx.score + gy.score });
    }
    // The best few pitches, none within a sixth of a better one.
    all.sort(function (a, b) { return b.score - a.score; });
    var out = [];
    all.forEach(function (c) { if (out.length < 3 && c.score >= all[0].score * .75 &&
      out.every(function (o) { return Math.abs(o.g[0].p - c.g[0].p) > o.g[0].p / 6; })) out.push(c); });
    return out;
  }
  // The lines at that pitch, laid where the most changes are with each
  // square between three quarters and five quarters of it, so a grid that
  // drifts across the picture is followed rather than averaged.
  function lines(prof, g) {
    var n = prof.length, lo = Math.max(2, Math.round(g.p * .75)), hi = Math.round(g.p * 1.25);
    var score = new Float64Array(n + 1), from = new Int32Array(n + 1), x, s2;
    // A line may start anywhere in the first square and end in the last.
    for (x = 0; x <= n; x++) {
      score[x] = -1; from[x] = -1;
      if (x < hi) score[x] = prof[x] || 0;
      for (s2 = lo; s2 <= hi && s2 <= x; s2++) if (score[x - s2] >= 0 && score[x - s2] + (prof[x] || 0) > score[x]) { score[x] = score[x - s2] + (prof[x] || 0); from[x] = x - s2; }
    }
    var end = n;
    for (x = Math.max(0, n - hi); x <= n; x++) if (score[x] > score[end]) end = x;
    var out = [];
    for (x = end; x >= 0; x = from[x]) out.unshift(x);
    // The part squares at the edges are kept as whole ones.
    if (out[0] >= lo) out.unshift(Math.max(0, out[0] - Math.round(g.p)));
    if (n - out[out.length - 1] >= lo) out.push(Math.min(n, out[out.length - 1] + Math.round(g.p)));
    return out;
  }
  // The image as squares: their lines, each square's colour (OKLab, the
  // middle half's most common shade) and how well the squares hold one
  // colour each: `fit`, the share of their pixels near their own colour,
  // and `mixed`, the squares whose middle is not mostly one colour.
  function snap(rgba, w, h) {
    var n = w * h, lab = new Float32Array(n * 3), i;
    for (i = 0; i < n; i++) lab.set(oklab(lin(rgba[4 * i]), lin(rgba[4 * i + 1]), lin(rgba[4 * i + 2])), 3 * i);
    var pr = profiles(lab, w, h), side = Math.max(w, h), lo = Math.max(4, side / 96), hi = side / 6;
    // The changes can fall as well on a finer pitch, its lines laid unevenly,
    // as on the drawing's own, and the other way about where the drawing
    // is finer in places. So the best few pitches and the best one's
    // multiples are each read, and the coarsest whose squares hold one colour
    // about as well as the best's is the drawing's.
    var found = pitchOf(pr[0], pr[1], lo, hi), cands = found.map(function (c) { return c.g; }), tc = 0, tr = 0, x;
    if (!found.length) return null;
    for (x = 0; x < w; x++) tc += pr[0][x];
    for (x = 0; x < h; x++) tr += pr[1][x];
    [1.5, 2, 3].forEach(function (m) { var p = found[0].g[0].p * m;
      if (p <= hi) cands.push([phaseOf(pr[0], tc, p), phaseOf(pr[1], tr, p)]); });
    var reads = cands.map(function (g) { var r = readAt(lab, w, h, pr, g[0], g[1]); r.share = r.mixed / r.cells.length; return r; });
    var least = Math.min.apply(null, reads.map(function (r) { return r.share; }));
    return reads.filter(function (r) { return r.share <= least + .01; })
      .reduce(function (a, b) { return b.pitch[0] > a.pitch[0] ? b : a; });
  }
  function readAt(lab, w, h, pr, gx, gy) {
    var xs = lines(pr[0], gx), ys = lines(pr[1], gy), x, y, cols = xs.length - 1, rws = ys.length - 1, out = [], flags = [], mixed = 0, near = 0, all = 0, t2 = SNAP_TOL * SNAP_TOL;
    for (var cy = 0; cy < rws; cy++) for (var cx = 0; cx < cols; cx++) {
      var x0 = xs[cx], x1 = xs[cx + 1], y0 = ys[cy], y1 = ys[cy + 1], mx = (x1 - x0) / 4, my = (y1 - y0) / 4, seen = {}, top = null;
      for (var y = Math.floor(y0 + my); y < Math.ceil(y1 - my); y++) for (var x = Math.floor(x0 + mx); x < Math.ceil(x1 - mx); x++) {
        var j = 3 * (y * w + x), k = Math.round(lab[j] * 40) + "," + Math.round(lab[j + 1] * 40) + "," + Math.round(lab[j + 2] * 40);
        var s = seen[k] = seen[k] || { n: 0, l: 0, a: 0, b: 0 }; s.n++; s.l += lab[j]; s.a += lab[j + 1]; s.b += lab[j + 2];
        if (!top || s.n > top.n) top = s;
      }
      var c = top ? [top.l / top.n, top.a / top.n, top.b / top.n] : [1, 0, 0], inner = 0, same = 0;
      for (y = Math.floor(y0 + my); y < Math.ceil(y1 - my); y++) for (x = Math.floor(x0 + mx); x < Math.ceil(x1 - mx); x++) {
        inner++; if (dist2(lab, 3 * (y * w + x), c, 0) < t2) same++; }
      // A square whose middle is not mostly one colour holds a finer drawing.
      var mx = same < inner * .7; if (mx) mixed++; flags.push(mx);
      out.push(c);
      for (y = y0; y < y1; y++) for (x = x0; x < x1; x++) { all++; if (dist2(lab, 3 * (y * w + x), c, 0) < t2) near++; }
    }
    return { cols: cols, rows: rws, pitch: [gx.p, gy.p], xs: xs, ys: ys, cells: out, mixed: mixed, flags: flags, fit: all ? near / all : 0 };
  }
  // A snapped picture as the band's rows: what is the border's colour and
  // joined to the border is bare, the rest takes the nearest bead in no more
  // than `colours`, and the drawing is cut to what is drawn and centred in N
  // squares. `why` says why there are no rows: over MIXED of its squares
  // are not one colour (the grid was misread, or the model drew finer in
  // places), it is bigger than N, or (a scene, which must fill) off N by
  // more than `slack`, a little over being cut evenly off its sides. Read
  // smaller by taking each bead's most common colour, a scene of 64 squares
  // lost its basket and mug at 24 (2026-10-14): it is redrawn instead.
  function fromSnap(sn, N, colours, scene, slack) {
    var W = sn.cols, H = sn.rows, cells2 = sn.cells, flags = sn.flags, x, y, i;
    var bg = new Uint8Array(W * H);
    if (!scene) {
      var border = [];
      for (x = 0; x < W; x++) border.push(x, (H - 1) * W + x);
      for (y = 1; y < H - 1; y++) border.push(y * W, y * W + W - 1);
      var votes = {}, most = null;
      border.forEach(function (j) { var c = cells2[j], k = Math.round(c[0] * 20) + "," + Math.round(c[1] * 20) + "," + Math.round(c[2] * 20);
        (votes[k] = votes[k] || []).push(j); if (!most || votes[k].length > most.length) most = votes[k]; });
      var ref = cells2[most[0]], t2 = .08 * .08, stack = [];
      var push = function (j) { if (!bg[j] && dist2(cells2[j], 0, ref, 0) < t2) { bg[j] = 1; stack.push(j); } };
      border.forEach(push);
      while (stack.length) { var j = stack.pop(), jx = j % W;
        if (jx) push(j - 1); if (jx < W - 1) push(j + 1); if (j >= W) push(j - W); if (j < W * H - W) push(j + W); }
    }
    var x0 = W, y0 = H, x1 = -1, y1 = -1;
    for (i = 0; i < W * H; i++) if (!bg[i]) { x = i % W; y = (i - x) / W; x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
    if (x1 < 0) return { why: "nothing drawn" };
    var bw = x1 - x0 + 1, bh = y1 - y0 + 1, drawn = 0, mixed = 0;
    for (i = 0; i < W * H; i++) if (!bg[i]) { drawn++; if (flags[i]) mixed++; }
    if (mixed > drawn * MIXED) return { why: Math.round(100 * mixed / drawn) + "% of its squares hold a finer drawing", w: bw, h: bh };
    if (scene) {
      // A scene fills its square: a little over is cut evenly off its sides.
      if (bw < N - slack || bh < N - slack || bw > N + slack || bh > N + slack)
        return { why: "drawn " + bw + "×" + bh + ", wants " + N + "×" + N, w: bw, h: bh };
    } else if (bw > N || bh > N) return { why: "drawn " + bw + "×" + bh + ", over " + N + "×" + N, w: bw, h: bh };
    var ox = x0 + Math.floor((bw - N) / 2), oy = y0 + Math.floor((bh - N) / 2), list = [];
    for (y = 0; y < N; y++) for (x = 0; x < N; x++) {
      var sx = ox + x, sy = oy + y, k2 = sy * W + sx;
      var inside = sx >= x0 && sx <= x1 && sy >= y0 && sy <= y1 && !bg[k2];
      list.push(inside ? cells2[k2] : null);
    }
    var at = pick(list, colours), rows = [];
    for (y = 0; y < N; y++) rows.push(at.slice(y * N, y * N + N).map(function (a) { return a < 0 ? "." : LETTERS[a]; }).join(""));
    return { rows: rows, w: bw, h: bh };
  }
  // A snapped drawing of one thing kept at the squares it was drawn at: the
  // background (the border's colour, joined to the border) bare, the thing
  // cut to what is drawn, in no more than `colours` beads, and centred in a
  // square of its longer side plus `margin` bare squares each way, never
  // under `least` a side. `why` says why there are no rows: over MIXED of
  // its squares are not one colour (the grid was misread, or the model drew
  // finer in places), or nothing is drawn. What the caller makes of the
  // side it came out at (the band's range) is the caller's.
  function cutOut(sn, colours, margin, least) {
    var W = sn.cols, H = sn.rows, cells2 = sn.cells, flags = sn.flags, x, y, i;
    var bg = new Uint8Array(W * H), border = [];
    for (x = 0; x < W; x++) border.push(x, (H - 1) * W + x);
    for (y = 1; y < H - 1; y++) border.push(y * W, y * W + W - 1);
    var votes = {}, most = null;
    border.forEach(function (j) { var c = cells2[j], k = Math.round(c[0] * 20) + "," + Math.round(c[1] * 20) + "," + Math.round(c[2] * 20);
      (votes[k] = votes[k] || []).push(j); if (!most || votes[k].length > most.length) most = votes[k]; });
    var ref = cells2[most[0]], t2 = .08 * .08, stack = [];
    var push = function (j) { if (!bg[j] && dist2(cells2[j], 0, ref, 0) < t2) { bg[j] = 1; stack.push(j); } };
    border.forEach(push);
    while (stack.length) { var j = stack.pop(), jx = j % W;
      if (jx) push(j - 1); if (jx < W - 1) push(j + 1); if (j >= W) push(j - W); if (j < W * H - W) push(j + W); }
    var x0 = W, y0 = H, x1 = -1, y1 = -1, drawn = 0, mixed = 0;
    for (i = 0; i < W * H; i++) if (!bg[i]) { x = i % W; y = (i - x) / W; x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); drawn++; if (flags[i]) mixed++; }
    if (x1 < 0) return { why: "nothing drawn" };
    var bw = x1 - x0 + 1, bh = y1 - y0 + 1;
    if (mixed > drawn * MIXED) return { why: Math.round(100 * mixed / drawn) + "% of its squares hold a finer drawing", w: bw, h: bh };
    var N = Math.max(least || 0, Math.max(bw, bh) + 2 * (margin || 0)), ox = x0 - Math.floor((N - bw) / 2), oy = y0 - Math.floor((N - bh) / 2), list = [];
    for (y = 0; y < N; y++) for (x = 0; x < N; x++) {
      var sx = ox + x, sy = oy + y, k2 = sy * W + sx;
      var inside = sx >= x0 && sx <= x1 && sy >= y0 && sy <= y1 && !bg[k2];
      list.push(inside ? cells2[k2] : null);
    }
    var at = pick(list, colours), rows = [];
    for (y = 0; y < N; y++) rows.push(at.slice(y * N, y * N + N).map(function (a) { return a < 0 ? "." : LETTERS[a]; }).join(""));
    return { rows: rows, w: bw, h: bh, side: N };
  }
  return { PALETTE: PALETTE, cutOut: cutOut, SIZES: [10, 12, 24, 32, 48], RULES: RULES, rulesOf: rulesOf, optionsFor: optionsFor, fillOf: fillOf,
    check: check, convert: convert, snap: snap, fromSnap: fromSnap };
})();
if (typeof module !== "undefined") module.exports = Beads;
