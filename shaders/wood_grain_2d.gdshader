shader_type canvas_item;

// The HUD's wood, as a plank. Set as a Control's `material` so it modulates
// the StyleBoxFlat the panel already draws: the rounded corners, the deep rim
// and the antialiasing all come for free, and the rim grains along with the
// face because every tone is a multiply on whatever colour was drawn rather
// than a colour of its own. The figure is a sawn board seen face on: fine
// straight grain running along the panel with a slight wander, a few dark
// splits that taper to a point at both ends and catch the light on their
// lower lip, all with soft brush edges, over a slow warm-to-cool wash. It is
// measured in the panel's pixels. `grain_seed` picks the board:
// CozyTheme.wood_grain(seed) caches one material per seed so the plaque, the
// day card and the trays do not share their splits. The 3D wood
// (shaders/toon_lit.gdshaderinc) keeps its log figure of rings and knots;
// docs/art/shading-direction.md records the split.
//
// A panel that hands over its size (`plank_size`) also has its silhouette
// carved here: a hewn board rather than a rounded card. The stylebox then only
// supplies the face colour over the whole rect. It is a plain uniform, so such
// a panel carries a material of its own (CozyTheme.plank) rather than the
// shared cached one: an `instance uniform` would be read out of Godot's global
// shader buffer, which the gl_compatibility shaders declare as 256 items --
// sixteen instances -- and a mobile driver hands back garbage for anything
// past that.

varying vec2 grain_pos;
uniform float grain_seed = 0.0;
// Fine grain: pixels between lines, how far a line wanders in pixels, its
// half-width in pixels, how much of its length shows, and its tint.
uniform float grain_period = 9.0;
uniform float grain_wobble = 1.6;
uniform float grain_width = 0.7;
uniform float grain_cover : hint_range(0.0, 1.0) = 0.45;
uniform vec3 grain_streak_tint = vec3(0.90, 0.86, 0.85);
// Brush edge, in pixels.
uniform float grain_soft = 1.4;
// Splits. Each cell of the lattice (pixels, along x by across) may hold one,
// `crack_chance` of the time, starting anywhere in the cell and running up to
// `crack_length` of a cell's width, `crack_width` pixels wide at its middle.
uniform vec2 crack_cell = vec2(300.0, 34.0);
uniform float crack_chance : hint_range(0.0, 1.0) = 0.5;
uniform float crack_length : hint_range(0.0, 1.0) = 0.8;
uniform float crack_width = 2.6;
uniform float crack_wobble = 1.5;
uniform vec3 crack_tint = vec3(0.55, 0.47, 0.42);
// The lit lower lip of a split: how far below, and how much lighter.
uniform float crack_lip = 1.5;
uniform vec3 crack_lip_tint = vec3(1.08, 1.06, 1.03);
// The wash between a warmer and a cooler brown, how much of it shows, and
// the size of its patches in pixels.
uniform float grain_wash : hint_range(0.0, 1.0) = 1.0;
uniform float wash_scale = 140.0;
uniform vec3 grain_warm = vec3(1.05, 0.99, 0.92);
uniform vec3 grain_cool = vec3(0.95, 0.97, 1.05);
// The cut. Zero (the default) leaves the stylebox's shape as drawn, which is
// what the trays want. A panel that sets it to its size in pixels
// (CozyTheme.plank() does, on every resize) gets a board instead: a box
// resting `edge_inset` pixels inside the rect, its edge wandering in slow
// lobes and fine nicks, a chamfer of seeded size knocked off each corner.
// No line is drawn round it: the painted grain carries the edge, with a lit
// lip where the edge faces up and a soft shade where it faces down for the
// board's thickness (docs/art/shading-direction.md: depth through colour, no
// outlines). A dark rim following the cut is still available through `rim`
// and `rim_foot` (extra where the edge faces down) and is off at zero. Every
// one of these is a multiply like the grain: `rim_tint` is the rim colour
// over the face colour, so the face the stylebox drew stays the only colour
// chosen outright.
uniform vec2 plank_size = vec2(0.0);
uniform float edge_inset = 8.0;
uniform float edge_radius = 8.0;
uniform float bump_len = 120.0;
uniform float bump_amp = 5.2;
uniform float chip_len = 18.0;
uniform float chip_amp = 0.9;
uniform float bite = 16.0;
uniform float rim = 0.0;
uniform float rim_foot = 0.0;
uniform vec3 rim_tint = vec3(0.64, 0.59, 0.54);
uniform float bevel = 3.5;
uniform vec3 bevel_tint = vec3(1.12, 1.10, 1.06);
// The underside shade: how far in it reaches, in pixels, and its tint.
uniform float shade = 10.0;
uniform vec3 shade_tint = vec3(0.90, 0.89, 0.90);

void vertex() {
	grain_pos = VERTEX;
}

float wood_hash(vec2 p) {
	p = mod(p, 289.0);
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float wood_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(wood_hash(i), wood_hash(i + vec2(1.0, 0.0)), f.x),
		mix(wood_hash(i + vec2(0.0, 1.0)), wood_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Coverage of the band |x| < hw by a pixel of width w centred at x = d >= 0.
float wood_band(float d, float hw, float w) {
	return clamp(min(hw, d + 0.5 * w) - max(-hw, d - 0.5 * w), 0.0, w) / w;
}

// Coverage at p of the split that lives in lattice `cell`, if it has one:
// a spindle, widest in the middle and pointed at both ends, wandering a
// little up and down along its run. `w` is the brush width.
float crack_at(vec2 p, vec2 cell, float w) {
	float has = step(wood_hash(cell + vec2(11.0, 3.0)), crack_chance);
	float len = crack_cell.x * crack_length * mix(0.35, 1.0, wood_hash(cell + 17.0));
	float x0 = (cell.x + wood_hash(cell + 23.0)) * crack_cell.x;
	float y0 = (cell.y + mix(0.2, 0.8, wood_hash(cell + 29.0))) * crack_cell.y;
	float v = 2.0 * (p.x - x0) / len - 1.0;
	float hw = has * crack_width * mix(0.6, 1.0, wood_hash(cell + 31.0)) * max(1.0 - v * v, 0.0);
	float y = y0 + (wood_noise(vec2(p.x / 40.0, cell.y * 7.0 + 5.0)) - 0.5) * 2.0 * crack_wobble;
	return wood_band(abs(p.y - y), hw, w);
}

// The splits at p: its own cell's and the one from the cell to the left,
// which may run this far.
float cracks_at(vec2 p, float w) {
	vec2 cell = floor(p / crack_cell);
	return max(crack_at(p, cell, w), crack_at(p, cell - vec2(1.0, 0.0), w));
}

// Signed distance from q, measured from the box's centre, to a box of
// half-size b with corners of radius r (Inigo Quilez's exact form).
float box_sd(vec2 q, vec2 b, float r) {
	vec2 e = abs(q) - b + r;
	return min(max(e.x, e.y), 0.0) + length(max(e, 0.0)) - r;
}

// Signed distance to the hewn board at p (pixels from the panel's corner;
// `s` is the seeded copy the noise reads): the box with a chamfer cut off
// the corner this quadrant belongs to, then the whole edge pushed about by
// two scales of noise so the chamfers are as uneven as the sides.
float plank_sd(vec2 p, vec2 s) {
	vec2 half_size = plank_size * 0.5 - edge_inset;
	vec2 q = p - plank_size * 0.5;
	float d = box_sd(q, half_size, edge_radius);
	vec2 corner = step(0.0, q) * 2.0 - 1.0;
	float cut = bite * mix(0.3, 1.0, wood_hash(corner * 7.0 + grain_seed));
	float chamfer = (dot(q, corner) - (half_size.x + half_size.y - cut)) * 0.7071;
	d = max(d, chamfer);
	d += (wood_noise(s / bump_len) - 0.5) * 2.0 * bump_amp;
	d += (wood_noise(s / chip_len + 31.0) - 0.5) * 2.0 * chip_amp;
	return d;
}

void fragment() {
	vec2 p = grain_pos + vec2(grain_seed * 137.0, grain_seed * 71.0);
	float w = max(fwidth(grain_pos.y), 0.5) * grain_soft;

	// Fine grain: lines along the board, wandering, present in stretches.
	float r = p.y / grain_period
		+ (wood_noise(vec2(p.x / 60.0, p.y / grain_period * 0.5)) - 0.5) * 2.0 * grain_wobble / grain_period;
	float d = abs(fract(r) - 0.5) * grain_period;
	float presence = wood_noise(vec2(p.x / 90.0, floor(r) * 0.73 + 17.0));
	float hw = grain_width * smoothstep(1.0 - grain_cover, 1.0 - grain_cover + 0.3, presence);
	float streak = wood_band(d, hw, w);

	// Splits, and the lit lip just below each.
	float crack = cracks_at(p, w);
	float lip = cracks_at(p - vec2(0.0, crack_lip), w) * (1.0 - crack);

	// The wash: broad patches stretched along the grain, and a finer drift
	// in value.
	vec2 q = p / wash_scale;
	float n_broad = wood_noise(q * vec2(0.5, 1.4) + 77.0);
	float n_fine = wood_noise(q * vec2(1.6, 4.0) + 53.0);
	float warmth = clamp(0.5 + (n_broad - 0.5) * 1.4 + (n_fine - 0.5) * 0.8, 0.0, 1.0);
	vec3 tone = mix(vec3(1.0), mix(grain_cool, grain_warm, warmth), grain_wash);
	tone *= 1.0 + (n_fine - 0.5) * 0.08 * grain_wash;

	tone *= mix(vec3(1.0), grain_streak_tint, streak);
	tone *= mix(vec3(1.0), crack_lip_tint, lip);
	tone *= mix(vec3(1.0), crack_tint, crack);

	// The cut, for a panel that asked for one. `plank_size` is uniform over
	// the draw, so the derivatives inside the branch are well defined. The
	// noise leaves d an approximate distance, so the edge's facing comes
	// from d's own screen-space gradient rather than the box's geometry.
	if (plank_size.x > 0.0) {
		float d = plank_sd(grain_pos, p);
		vec2 g = vec2(dFdx(d), dFdy(d));
		g /= max(length(g), 1e-4);
		float up = clamp(-g.y, 0.0, 1.0);
		float down = clamp(g.y, 0.0, 1.0);
		float rim_w = rim + rim_foot * down;
		float rim_mask = rim_w > 0.0 ? smoothstep(-rim_w - w, -rim_w + w, d) : 0.0;
		float bevel_mask = smoothstep(-rim_w - bevel - w, -rim_w - bevel + w, d)
			* (1.0 - rim_mask) * up;
		float shade_mask = smoothstep(-rim_w - shade, -rim_w, d) * (1.0 - rim_mask) * down;
		tone *= mix(vec3(1.0), rim_tint, rim_mask);
		tone *= mix(vec3(1.0), bevel_tint, bevel_mask);
		tone *= mix(vec3(1.0), shade_tint, shade_mask);
		float aa = max(fwidth(d), 0.5);
		COLOR.a *= 1.0 - smoothstep(-aa, aa, d);
	}
	COLOR.rgb *= tone;
}
