shader_type canvas_item;

// Nightlight's star (arcade/nightlight_sky.gd), as a Sun is seen from space
// (the user's picture, 2026-10-06: "give it a more space view sun"): a
// surface that boils in small grains, brighter patches drifting over it, an
// edge darker than the middle, and past the edge a thin ragged glow with a
// few slow arcs standing off it. One square of Art.WIDE radii, drawn once;
// `col` is the star's temperature as a colour, `lit` 0 for a star with
// nothing left to burn, `clock` the sky's own seconds (it stands still under
// reduce motion and while a card is up). No texture: everything is worked
// out from where the fragment is.

uniform vec3 col = vec3(1.0, 0.67, 0.28);
uniform float lit = 1.0;
uniform float clock = 0.0;
// How much of the star is there: an end thins it away.
uniform float fade = 1.0;
// Grains across the star's radius.
uniform float grains = 15.0;
// The radius the square's mesh is built for.
uniform float built = 64.0;

varying vec2 p;

void vertex() {
	p = VERTEX / built;
}

float hash(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 q) {
	return fract(sin(vec2(dot(q, vec2(127.1, 311.7)), dot(q, vec2(269.5, 183.3)))) * 43758.5453);
}

float noise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 q) {
	return noise(q) * 0.55 + noise(q * 2.1 + 11.0) * 0.3 + noise(q * 4.3 + 23.0) * 0.15;
}

// How far `q` is from the middle of the nearest grain, each middle
// wandering in its own cell: 0 on a grain's heart, high in the dark lanes
// between.
float cells(vec2 q, float t) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	float d = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = 0.5 + 0.38 * sin(t + 6.2831 * hash2(i + g));
			d = min(d, length(g + o - f));
		}
	}
	return d;
}

void fragment() {
	float r = length(p);
	vec2 dir = p / max(r, 0.0001);
	// the surface as a ball: grains crowd toward the edge
	float z = sqrt(max(0.0, 1.0 - r * r));
	vec2 s = p * (1.0 + 0.55 * (1.0 - z));
	float t = clock;
	// pushed about by a slow noise, or the grains sit in rows
	vec2 w = s + 0.09 * vec2(fbm(s * 3.1 + vec2(4.0, t * 0.02)), fbm(s * 3.1 + vec2(19.0, -t * 0.02))) - 0.045;
	vec2 turned = vec2(w.x * 0.8 - w.y * 0.6, w.x * 0.6 + w.y * 0.8);
	float fine = cells(w * grains + vec2(t * 0.03, 0.0), t * 0.5);
	float wide = cells(turned * grains * 0.47 + 31.0, t * 0.21);
	float patch_k = fbm(s * 2.3 + vec2(t * 0.012, -t * 0.008));
	float uneven = fbm(s * 6.0 + 40.0);
	// a grain is bright across most of itself, and the lanes between are thin
	float boil = (1.0 - smoothstep(0.28, 0.66, fine)) * (0.4 + 0.7 * uneven) + (1.0 - smoothstep(0.1, 0.75, wide)) * 0.25;
	boil = clamp(boil, 0.0, 1.0);
	boil = mix(boil * 0.55, boil, lit);
	// the lanes are the star's own colour, deeper: redder on a cool star,
	// a dusk blue on a hot one
	float blue = smoothstep(0.45, 0.95, col.b / max(col.r, 0.001));
	vec3 lane = col * mix(vec3(0.7, 0.36, 0.22), vec3(0.5, 0.56, 0.78), blue);
	vec3 hot = mix(col, vec3(1.0, 0.98, 0.9), 0.8);
	vec3 face = mix(lane, mix(col, hot, 0.2), boil);
	// bright patches where the slow noise is high, darker country where it is low
	face = mix(face, hot, smoothstep(0.58, 0.8, patch_k) * (0.3 + 0.7 * boil) * lit);
	face = mix(face, lane * 0.75, smoothstep(0.36, 0.16, patch_k) * 0.55);
	// darker toward the edge
	face *= mix(0.48, 1.06, pow(z, 0.6));
	face *= mix(0.55, 1.0, lit);
	float disc = 1.0 - smoothstep(0.975, 1.0, r);
	// past the edge: a low ragged glow, and where the slow noise is high an
	// arc standing off it
	// low and round, never a spike: the arcs are wide mounds of light
	float rise = fbm(dir * 1.7 + vec2(t * 0.02, t * 0.013));
	float fringe = fbm(dir * 5.0 + vec2(r * 3.0 - t * 0.1, t * 0.05));
	float tall = 0.05 + 0.03 * fringe + 0.2 * smoothstep(0.42, 0.78, rise) * (0.6 + 0.4 * fringe);
	tall *= mix(0.4, 1.0, lit);
	float off = max(0.0, r - 0.985);
	float air = (1.0 - smoothstep(0.0, tall, off)) * step(0.975, r);
	vec3 air_col = mix(col * mix(vec3(1.0, 0.5, 0.28), vec3(0.7, 0.8, 1.0), blue), hot, 0.3 * air);
	vec3 c = mix(air_col, face, disc);
	float a = max(disc, air * air * air * 0.9);
	COLOR = vec4(c, a * fade);
}
