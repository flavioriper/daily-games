shader_type canvas_item;

// The HUD's wood, grained. Set as a Control's `material` so it modulates the
// StyleBoxFlat the panel already draws: the rounded corners, the thick bottom
// edge and the antialiasing all come for free, and the darker edge grains
// along with the face because the darkening is a multiply on whatever colour
// was drawn rather than a colour of its own. The same figure as the 3D wood
// (shaders/toon_lit.gdshaderinc) -- broken streaks, tonal zones, a knot --
// measured in the panel's pixels instead of world units. `grain_seed` picks
// the log: CozyTheme.wood_grain(seed) caches one material per seed so the
// plaque, the day card and the trays do not share one corner figure.

varying vec2 grain_pos;
uniform float grain_seed = 0.0;
// The heart of the log, in pixels from the panel's top-left corner. Far
// below the card, so its rings cross the face as long shallow arcs.
uniform vec2 grain_heart = vec2(60.0, 520.0);
uniform float grain_period = 11.0;   // pixels between rings
uniform float grain_width : hint_range(0.0, 0.5) = 0.09;   // streak half-width, in rings
uniform float grain_cover : hint_range(0.0, 1.0) = 0.6;
uniform float grain_wobble = 0.4;    // rings a line wanders
uniform float grain_darken : hint_range(0.0, 1.0) = 0.8;
uniform float grain_zone_darken : hint_range(0.0, 1.0) = 0.95;
uniform vec2 grain_knot_cell = vec2(220.0, 70.0);   // pixels, along x across
uniform float grain_knot_chance : hint_range(0.0, 1.0) = 0.4;
uniform float grain_knot_size = 5.0;               // core half-length, pixels
uniform float grain_knot_darken : hint_range(0.0, 1.0) = 0.7;

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

void fragment() {
	vec2 heart = grain_heart
		+ (vec2(wood_hash(vec2(grain_seed, 3.1)), wood_hash(vec2(grain_seed, 7.3))) - 0.5) * 120.0;
	vec2 p = grain_pos + vec2(grain_seed * 137.0, 0.0);
	float radius = length(grain_pos - heart);

	// Ring coordinate, wandering along the grain in two octaves.
	float r = radius / grain_period;
	vec2 np = vec2(p.x, radius) / grain_period;
	r += (wood_noise(np * vec2(0.09, 0.3)) - 0.5) * 2.0 * grain_wobble;
	r += (wood_noise(np * vec2(0.27, 0.7) + 31.0) - 0.5) * 0.7 * grain_wobble;

	// Knots on a jittered lattice; the bulge folds the rings around the core.
	vec2 kp = p / grain_knot_cell;
	vec2 kc = floor(kp);
	float has_knot = step(wood_hash(kc + 41.0), grain_knot_chance);
	vec2 jitter = (vec2(wood_hash(kc + 5.0), wood_hash(kc + 9.0)) - 0.5) * 0.5;
	vec2 to_knot = (kp - kc - 0.5 - jitter) * grain_knot_cell;
	float e = length(to_knot / (grain_knot_size * vec2(2.0, 1.0)));
	float bulge = 1.0 - clamp(e / 3.5, 0.0, 1.0);
	r += has_knot * bulge * bulge * (3.0 - 2.0 * bulge) * 2.6;
	float knot_core = has_knot * wood_band(e, 1.0, max(fwidth(e), 0.001));

	// Streaks, tapering where the noise along the ring fades.
	float d = abs(fract(r) - 0.5);
	float ring = floor(r);
	float presence = wood_noise(vec2(p.x / grain_period * 0.13, ring * 0.71 + 17.0));
	float hw = grain_width * smoothstep(1.0 - grain_cover, 1.0 - grain_cover + 0.3, presence);
	float w = max(fwidth(r), 0.0008);
	float streak = wood_band(d, hw, w);

	// Zones bounded by the streak lines, blended across the boundary.
	float zr = r + 0.5;
	float zid = floor(zr);
	float zf = fract(zr);
	float z0 = step(0.5, wood_hash(vec2(zid, 23.0)));
	float zm = step(0.5, wood_hash(vec2(zid - 1.0, 23.0)));
	float zp = step(0.5, wood_hash(vec2(zid + 1.0, 23.0)));
	float zone = mix(mix(zm, z0, clamp(zf / w + 0.5, 0.0, 1.0)), zp, clamp((zf - 1.0) / w + 0.5, 0.0, 1.0));

	float tone = mix(1.0, grain_zone_darken, zone);
	tone *= mix(1.0, grain_darken, streak);
	COLOR.rgb *= mix(tone, grain_knot_darken, knot_core);
}
