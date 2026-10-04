shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Lucky Thirteen's pebble, as a lit stone rather than flat fills. It is never
// on screen: arcade/thirteen_art.gd draws one rect per number into a
// SubViewport once, keeps the picture as an atlas, and the board draws
// textured quads from it. So the cost here is paid once, not per frame, and
// the board's draw calls stay what they were.
//
// The stone is a height field (a flattened dome inside the number's own
// outline, with a little grit on it); the normal comes off that, and one
// light from the upper left -- the same for every pebble and for the sand
// (shaders/sand_bake_2d.gdshader) -- gives the lit crown, the cool shade, the
// warm bounce off the sand, the wet highlight and the shadow on the ground.
// The paint, speckles, bands, gold flecks and 13's clover are drawn into the
// albedo and lit with the rest.
//
// The rect covers -SPAN..SPAN, the stone has radius 1. Blending is off: the
// picture is written with straight alpha, so the atlas has no dark fringe.

uniform float value = 1.0;
uniform vec4 base : source_color = vec4(0.93, 0.5, 0.55, 1.0);
uniform float px = 0.008; // one pixel, in stone radii

const float SPAN = 1.3;
const vec3 SUN = vec3(-0.50, -0.62, 0.60);
const vec3 GOLD = vec3(0.95, 0.71, 0.20);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * noise(p);
		p = p * 2.03 + 17.0;
		a *= 0.5;
	}
	return s;
}

// 0 at the middle, 1 on the outline: a circle pressed a little out of round,
// each number its own way (thirteen_art.gd's _outline).
float rho(vec2 p) {
	float a = atan(p.y, p.x);
	float ph = value * 1.7;
	float k = 1.0 + 0.035 * sin(a * 2.0 + ph) + 0.02 * sin(a * 3.0 + ph * 1.3);
	return length(p / vec2(1.03, 0.97)) / k;
}

float height(vec2 p) {
	float r = min(rho(p), 1.0);
	float dome = pow(1.0 - pow(r, 2.8), 0.62);
	return 0.46 * dome + 0.006 * fbm(p * 7.0 + value * 7.3) + 0.002 * noise(p * 26.0 + value);
}

// A four-leaf clover's signed distance, `s` across.
float clover(vec2 p, float s, float turn) {
	float c = cos(turn);
	float sn = sin(turn);
	p = vec2(c * p.x + sn * p.y, -sn * p.x + c * p.y) / s;
	p = abs(p);
	if (p.y > p.x) {
		p = p.yx;
	}
	// one leaf along +x: a heart of two discs
	float d = min(length(p - vec2(0.54, 0.15)), length(p - vec2(0.54, -0.15))) - 0.23;
	d = min(d, length(p - vec2(0.27, 0.0)) - 0.2);
	return d * s;
}

void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * SPAN;
	float seed = value * 13.7;
	float r = rho(p);
	float e = 0.012;
	float hx = height(p + vec2(e, 0.0)) - height(p - vec2(e, 0.0));
	float hy = height(p + vec2(0.0, e)) - height(p - vec2(0.0, e));
	vec3 n = normalize(vec3(-hx, -hy, 2.0 * e));
	vec3 l = normalize(SUN);

	bool gilt = value > 12.5 && value < 13.5;
	vec3 deep = base.rgb * 0.62;
	vec3 pale = mix(base.rgb, vec3(1.0), 0.42);
	// the paint: brushed unevenly, a darker mottle in patches
	vec3 alb = base.rgb * (0.93 + 0.14 * fbm(p * 2.3 + seed));
	alb = mix(alb, deep, 0.28 * smoothstep(0.52, 0.72, fbm(p * 3.1 - seed)));
	// speckles, a few to a stone
	vec2 g = p * 6.5 + seed;
	vec2 gi = floor(g);
	float pick = hash(gi + 3.1);
	vec2 gc = gi + 0.25 + 0.5 * vec2(hash(gi), hash(gi + 9.7));
	float dot_r = mix(0.08, 0.2, hash(gi + 5.3));
	float speck = smoothstep(dot_r, dot_r * 0.55, length(g - gc)) * step(pick, 0.34);
	alb = mix(alb, pick < 0.17 ? deep : pale, 0.55 * speck);
	// a stone dresses up as it grows: a painted band from 5, a second from 9,
	// gold flecks from 10, a gold line past 13
	float metal = gilt ? 1.0 : 0.0;
	vec2 q = p + vec2(0.025, 0.05);
	float rq = rho(q);
	if (value > 4.5 && value < 12.5) {
		float w = 0.035 + 0.012 * noise(q * 5.0 + seed);
		alb = mix(alb, pale, 0.62 * smoothstep(w, w * 0.45, abs(rq - 0.76)));
		if (value > 8.5) {
			alb = mix(alb, deep, 0.5 * smoothstep(0.016, 0.006, abs(rq - 0.655)));
		}
		if (value > 9.5) {
			for (int i = 0; i < 5; i++) {
				vec2 at = 0.76 * vec2(cos(6.2832 * (float(i) + 0.3) / 5.0 + value), sin(6.2832 * (float(i) + 0.3) / 5.0 + value));
				float f = smoothstep(0.055, 0.035, length(q - at));
				alb = mix(alb, GOLD, f);
				metal = max(metal, f);
			}
		}
	} else if (value > 13.5) {
		float f = smoothstep(0.024, 0.01, abs(rq - 0.84));
		alb = mix(alb, GOLD, f);
		metal = max(metal, f);
	}
	if (gilt) {
		alb = mix(vec3(0.93, 0.66, 0.16), vec3(1.0, 0.80, 0.30), fbm(p * 2.0 + 3.0));
		alb = mix(alb, vec3(1.0, 0.93, 0.66), 0.7 * smoothstep(0.02, 0.008, abs(rq - 0.86)));
		float cd = clover(p - vec2(0.5, 0.46), 0.30, 0.4);
		vec3 leaf = mix(vec3(0.20, 0.46, 0.24), vec3(0.45, 0.75, 0.38), smoothstep(0.0, -0.05, cd));
		float on = smoothstep(0.012, -0.004, cd);
		alb = mix(alb, leaf, on);
		metal *= 1.0 - on;
	}

	// the light: a wrapped diffuse from warm lit to cool shade, the sand's
	// warm bounce on the lower right, sky on the upper rim, a wet highlight
	float d = dot(n, l);
	float lit = smoothstep(-0.45, 0.85, d);
	vec3 shade = mix(vec3(0.50, 0.43, 0.60), vec3(0.50, 0.33, 0.20), metal);
	vec3 col = alb * mix(shade, vec3(1.12, 1.07, 0.98), lit);
	float bounce = smoothstep(0.25, 0.95, dot(n, normalize(vec3(0.45, 0.75, 0.15))));
	col += alb * vec3(1.0, 0.78, 0.5) * 0.22 * bounce;
	col *= 1.0 - 0.22 * pow(r, 7.0) * smoothstep(-0.3, 0.6, -d);
	vec3 h = normalize(l + vec3(0.0, 0.0, 1.0));
	float nh = max(dot(n, h), 0.0);
	float gloss = pow(nh, 70.0) * 0.6 + pow(nh, 14.0) * 0.14;
	col += mix(vec3(1.0), vec3(1.0, 0.9, 0.62), metal) * gloss * (1.0 + 0.9 * metal);
	float rim = pow(1.0 - n.z, 2.5) * smoothstep(0.0, 0.9, dot(normalize(n.xy + 1e-5), normalize(l.xy)));
	col += vec3(1.0, 0.98, 0.92) * 0.28 * rim;

	// the stone over its shadow on the sand, written with straight alpha
	float body = smoothstep(1.0, 1.0 - 2.0 * px, r);
	float cast = 0.40 * smoothstep(1.17, 0.78, rho(p - vec2(0.075, 0.14)));
	cast = max(cast, 0.34 * smoothstep(1.07, 0.97, rho(p - vec2(0.02, 0.045))));
	float a = body + (1.0 - body) * cast;
	vec3 ground = vec3(0.27, 0.16, 0.08);
	COLOR = vec4(a > 0.001 ? (col * body + ground * cast * (1.0 - body)) / a : col, a);
}
