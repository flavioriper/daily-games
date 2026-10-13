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
  var PALETTE = { r: "e0503a", o: "f08a2c", y: "f4c640", c: "f3e6c8", w: "fbf7ee", p: "f4a3b4", s: "d9607a", l: "b99ad8",
    u: "7e5aa6", k: "8cc4e8", b: "4a7fc1", t: "4fae9c", i: "a8cf5a", g: "5fa845", f: "2f7a3f", n: "d4a56a", m: "8a5a36",
    d: "4a3226", e: "a9a39a" };
  // Button Box's Hard (16) has no written rule: it is held to what its
  // thirty pictures are, and `loose` says so.
  var RULES = { 10: { colours: [3, 4], fill: [.3, .7], small: true }, 12: { colours: [4, 5], fill: [.3, .7], small: true },
    16: { colours: [6, 7], fill: [.34, .66], loose: true },
    24: { colours: [7, 10], fill: [.85, 1], cut: 5 }, 32: { colours: [8, 12], fill: [.85, 1], cut: 6 } };
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
    var lo = cut ? rule.cut : rule.colours[0], hi = rule.colours[1];
    out.push({ ok: used.length >= lo && used.length <= hi, text: used.length + " colours, wants " + lo + "–" + hi });
    out.push({ ok: cut || (filled >= rule.fill[0] && filled <= rule.fill[1]),
      text: pct(filled) + " filled, wants " + pct(rule.fill[0]) + "–" + pct(rule.fill[1]) + (rule.cut ? (cut ? " (a cut-out)" : " or a cut-out at 30%–70%") : "") });
    if (rule.cut) {
      var share = used.reduce(function (m, c) { return Math.max(m, flat.split(c).length - 1); }, 0) / flat.length;
      out.push({ ok: share < MOST, text: "largest colour " + pct(share) + " of it, wants under " + pct(MOST) });
    }
    if (rule.small) {
      var all = [rows[0], rows[n - 1], rows.map(function (r) { return r[0]; }).join(""), rows.map(function (r) { return r[n - 1]; }).join("")]
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
  return { PALETTE: PALETTE, RULES: RULES, SIZES: [10, 12, 16, 24, 32], rulesOf: rulesOf, optionsFor: optionsFor, fillOf: fillOf,
    check: check, convert: convert };
})();
if (typeof module !== "undefined") module.exports = Beads;
