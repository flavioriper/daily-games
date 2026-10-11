// Gumdrop's fluid, shared by its passes (puzzles/gumdrop_fluid.gd). The
// render targets are eight bits a channel on the phone's driver (no HDR
// 2D on gl_compatibility), so a signed value is packed across two bytes:
// the velocity's x in RG and y in BA, the pressure, the divergence and
// the curl in RG. A packed texture is never read through the sampler's
// filter (the halves would blend apart): it is fetched by texel and, for
// the velocity, blended by hand.
//
// The colour maths is puzzles/gumdrop_sim.gd's `hue`, `strength`, `deep`,
// `colour` and `nearness` word for word, so the judge here and the probe
// there agree.

// The bounds each packed value is kept within.
const float VMAX = 600.0;
const float PMAX = 12000.0;
const float DMAX = 1200.0;
const float CMAX = 1200.0;
// Concentration: at C0 a texel is 63% of the way to the card's shade, at
// C_FULL it is the card's shade, at 2 x C_FULL it is DEEP darker. The dye
// texture holds a pigment's amount over AMOUNT_TOP.
const float C0 = 0.5;
const float C_FULL = 1.25;
const float DEEP = 0.3;
const float AMOUNT_TOP = 2.5;

vec2 pk(float v, float m) {
	float u = clamp(v / m * 0.5 + 0.5, 0.0, 1.0) * 255.0;
	float hi = floor(u);
	return vec2(hi / 255.0, u - hi);
}

float up(vec2 t, float m) {
	return ((t.x * 255.0 + t.y) / 255.0 - 0.5) * 2.0 * m;
}

// Whether a texel of the sim grid is a wall or off the grid: the mask is
// the cell's number plus one in red, zero over a wall or the tray.
bool wall_at(sampler2D mask, ivec2 p, ivec2 n) {
	if (p.x < 0 || p.y < 0 || p.x >= n.x || p.y >= n.y) {
		return true;
	}
	return texture(mask, (vec2(p) + 0.5) / vec2(n)).r < 0.001;
}

int cell_of(sampler2D mask, vec2 uv) {
	return int(round(texture(mask, uv).r * 255.0)) - 1;
}

vec2 vel_fetch(sampler2D vel, ivec2 p, ivec2 n) {
	p = clamp(p, ivec2(0), n - 1);
	vec4 c = texelFetch(vel, p, 0);
	return vec2(up(c.rg, VMAX), up(c.ba, VMAX));
}

// The velocity at a point of the grid, in texels (the centre of texel i
// is i + 0.5), blended from the four texels about it.
vec2 vel_at(sampler2D vel, vec2 pos, ivec2 n) {
	vec2 f = pos - 0.5;
	vec2 fl = floor(f);
	ivec2 i = ivec2(fl);
	vec2 w = f - fl;
	vec2 a = vel_fetch(vel, i, n);
	vec2 b = vel_fetch(vel, i + ivec2(1, 0), n);
	vec2 c = vel_fetch(vel, i + ivec2(0, 1), n);
	vec2 d = vel_fetch(vel, i + ivec2(1, 1), n);
	return mix(mix(a, b, w.x), mix(c, d, w.x), w.y);
}

vec4 pack_vel(vec2 v) {
	return vec4(pk(v.x, VMAX), pk(v.y, VMAX));
}

float fetch1(sampler2D t, ivec2 p, ivec2 n, float m) {
	p = clamp(p, ivec2(0), n - 1);
	return up(texelFetch(t, p, 0).rg, m);
}

// --- the colour ---

const vec3 CHERRY = vec3(0.886, 0.286, 0.353);
const vec3 ORANGE = vec3(0.953, 0.573, 0.216);
const vec3 LEMON = vec3(0.957, 0.831, 0.290);
const vec3 LIME = vec3(0.475, 0.788, 0.310);
const vec3 BLUEBERRY = vec3(0.290, 0.525, 0.875);
const vec3 GRAPE = vec3(0.604, 0.384, 0.824);
const vec3 MUD = vec3(0.478, 0.353, 0.282);

vec3 hue_of(float r, float y, float b) {
	float top = max(r, max(y, b));
	if (top <= 0.0) {
		return vec3(1.0);
	}
	r /= top;
	y /= top;
	b /= top;
	vec3 c00 = mix(vec3(1.0), CHERRY, r);
	vec3 c10 = mix(LEMON, ORANGE, r);
	vec3 c01 = mix(BLUEBERRY, GRAPE, r);
	vec3 c11 = mix(LIME, MUD, r);
	return mix(mix(c00, c10, y), mix(c01, c11, y), b);
}

float strength_of(float c) {
	return min(1.0, (1.0 - exp(-c / C0)) / (1.0 - exp(-C_FULL / C0)));
}

float deep_of(float c) {
	return clamp((c - C_FULL) / C_FULL, 0.0, 1.0) * DEEP;
}

// The colour a bit of jelly shows with these pigment amounts in it, the
// strength in alpha.
vec4 colour_of(vec3 pig) {
	float c = pig.r + pig.g + pig.b;
	if (c <= 0.0) {
		return vec4(1.0, 1.0, 1.0, 0.0);
	}
	vec3 h = hue_of(pig.r, pig.g, pig.b);
	float d = deep_of(c);
	if (d > 0.0) {
		h = mix(h, h * h, d);
	}
	return vec4(h, strength_of(c));
}

// NEAR_FREE of the way off is still a full match (the eye calls it the
// same colour); at NEAR_GONE of the way off the match is nothing.
const float NEAR_FREE = 0.1;
const float NEAR_GONE = 0.8;

float nearness_of(vec4 col, vec3 want) {
	vec3 shown = mix(vec3(1.0), col.rgb, col.a);
	float way = length(vec3(1.0) - want);
	float off = length(shown - want);
	return 1.0 - clamp((off / way - NEAR_FREE) / (NEAR_GONE - NEAR_FREE), 0.0, 1.0);
}
