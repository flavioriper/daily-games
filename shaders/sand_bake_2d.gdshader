shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Lucky Thirteen's tray of raked sand, lit by the pebbles' light
// (shaders/pebble_bake_2d.gdshader). Like the pebbles it is drawn once into a
// SubViewport and kept as a picture (arcade/thirteen_screen.gd, _bake_bed),
// so none of this runs while the game is played.
//
// The sand is a height field in pixels: the rake's ridges, a slow roll, a
// dish under every pebble, moss heaped in the corners and a little grit. The
// normal comes off it, so a ridge has a lit side and a shaded one and a dish
// has a dark near wall and a bright far one.

uniform vec2 size = vec2(1000.0, 1200.0);
uniform vec2 origin = vec2(0.0);
uniform float unit = 190.0;
uniform vec2 cells = vec2(5.0, 6.0);
uniform float first_row = 0.0;

const vec3 SUN = vec3(-0.50, -0.62, 0.60);
const vec3 SAND = vec3(0.945, 0.890, 0.770);
const vec3 SAND_DEEP = vec3(0.845, 0.765, 0.600);
const vec3 MOSS = vec3(0.50, 0.70, 0.32);
const vec3 MOSS_DEEP = vec3(0.34, 0.54, 0.25);

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

// How deep into a pebble's dish this point is: 0 on the sand, 1 on its floor.
float dish(vec2 p) {
	vec2 c = (p - origin) / unit;
	vec2 cell = floor(c);
	if (cell.x < 0.0 || cell.x >= cells.x || cell.y < first_row || cell.y >= cells.y) {
		return 0.0;
	}
	return smoothstep(0.495, 0.37, length(fract(c) - 0.5));
}

// How much moss lies here: heaped in the four corners, ragged at its edge.
float moss(vec2 p) {
	vec2 c = min(p, size - p);
	float d = length(c) / unit;
	return smoothstep(0.62, 0.36, d + (fbm(p * 0.035) - 0.5) * 0.55);
}

// A pebble of grit here, if any: x its height (0..1), y a random for its tone.
vec2 grit(vec2 p) {
	vec2 g = p / 46.0;
	vec2 gi = floor(g);
	if (hash(gi + 1.7) > 0.3) {
		return vec2(0.0);
	}
	vec2 c = gi + 0.2 + 0.6 * vec2(hash(gi + 4.1), hash(gi + 8.3));
	float rad = mix(0.05, 0.12, hash(gi + 2.9));
	float d = length(g - c) / rad;
	return vec2(sqrt(max(0.0, 1.0 - d * d)), hash(gi + 6.6));
}

float height(vec2 p) {
	float y = p.y + sin(p.x / size.x * 9.42 + p.y * 0.02) * 6.0;
	float h = (0.5 + 0.5 * cos(y / 26.0 * 6.2832)) * 2.6;
	h += fbm(p * 0.02) * 5.0 + noise(p * 0.55) * 0.35;
	float d = dish(p);
	h = mix(h, -9.0 + noise(p * 0.3) * 0.5, d);
	float m = moss(p);
	h += m * (7.0 + 5.0 * noise(p * 0.11) + 2.0 * noise(p * 0.4));
	h += grit(p).x * 4.0 * (1.0 - d) * (1.0 - m);
	return h;
}

void fragment() {
	vec2 p = UV * size;
	float hx = height(p + vec2(1.0, 0.0)) - height(p - vec2(1.0, 0.0));
	float hy = height(p + vec2(0.0, 1.0)) - height(p - vec2(0.0, 1.0));
	vec3 n = normalize(vec3(-hx, -hy, 2.6));
	vec3 l = normalize(SUN);
	float d = dish(p);
	float m = moss(p);
	vec2 gr = grit(p);

	// the sand: paler and deeper in slow patches, grains, the dishes damp
	vec3 alb = mix(SAND_DEEP, SAND, 0.55 + 0.6 * (fbm(p * 0.012 + 5.0) - 0.4));
	alb *= 0.965 + 0.07 * hash(floor(p));
	alb = mix(alb, SAND_DEEP * 0.80, step(0.985, hash(floor(p * 0.5) + 7.0)) * 0.5);
	alb = mix(alb, SAND_DEEP * 0.90, 0.75 * d);
	float stone = step(0.001, gr.x) * (1.0 - d) * (1.0 - m);
	alb = mix(alb, mix(vec3(0.62, 0.55, 0.47), vec3(0.93, 0.84, 0.76), gr.y), stone);
	alb = mix(alb, mix(MOSS_DEEP, MOSS, noise(p * 0.09) * 0.7 + 0.3 * noise(p * 0.5)), smoothstep(0.15, 0.5, m));

	float lit = smoothstep(-0.25, 0.95, dot(n, l));
	vec3 col = alb * mix(vec3(0.60, 0.52, 0.58), vec3(1.10, 1.06, 0.98), lit);
	// the day's light pooling from the upper left, and leaves' shade across it
	col *= 1.06 - 0.16 * (UV.x * 0.45 + UV.y * 0.55);
	float leaf = smoothstep(0.50, 0.62, fbm(p * 0.0052 + 31.0));
	col *= mix(vec3(1.0), vec3(0.86, 0.87, 0.93), 0.55 * leaf);
	// the tray's own wall shading the sand along the top and the left
	float wall = max(smoothstep(26.0, 0.0, p.y), smoothstep(22.0, 0.0, p.x));
	col *= 1.0 - 0.30 * wall;
	COLOR = vec4(col, 1.0);
}
