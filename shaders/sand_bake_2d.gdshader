shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Lucky Thirteen's tray, in the soft cel look: flat warm sand with the
// rake's lines as two quiet tones, and a seat pressed in under every stone --
// a deeper floor, an eased shade under its upper lip, a lit lip below. No
// grit, no noise but a slow wash. Drawn once into a SubViewport and kept as a
// picture (arcade/thirteen_screen.gd, _bake_bed).

uniform vec2 size = vec2(1000.0, 1200.0);
uniform vec2 origin = vec2(0.0);
uniform float unit = 190.0;
uniform vec2 cells = vec2(5.0, 6.0);
uniform float first_row = 0.0;

const vec3 SAND = vec3(0.953, 0.898, 0.776);
const vec3 SAND_LINE = vec3(0.925, 0.860, 0.722);
const vec3 SEAT = vec3(0.882, 0.800, 0.640);
const vec3 SEAT_SHADE = vec3(0.790, 0.690, 0.535);
const vec3 LIP = vec3(1.0, 0.972, 0.900);

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

void fragment() {
	vec2 p = UV * size;
	// the rake: wide waved bands, two tones of the sand
	float y = p.y + sin(p.x / size.x * 6.2832 + p.y * 0.012) * unit * 0.07;
	float band = 0.5 + 0.5 * cos(y / (unit * 0.2) * 6.2832);
	vec3 col = mix(SAND, SAND_LINE, smoothstep(0.62, 0.78, band));

	vec2 c = (p - origin) / unit;
	vec2 cell = floor(c);
	if (cell.x >= 0.0 && cell.x < cells.x && cell.y >= first_row && cell.y < cells.y) {
		vec2 q = (fract(c) - 0.5) * unit;
		float r = unit * 0.445;
		float d = length(q) - r;
		// the lit lip below the seat, the seat, the shade under its upper lip
		float under = smoothstep(-0.2, 0.9, q.y / r);
		col = mix(col, LIP, 0.9 * under * smoothstep(unit * 0.035 + 1.0, unit * 0.035 - 1.0, d));
		float seat = smoothstep(1.0, -1.0, d);
		col = mix(col, SEAT, seat);
		float shade = smoothstep(-unit * 0.012, unit * 0.012, length(q - vec2(unit * 0.012, unit * 0.06)) - r);
		col = mix(col, SEAT_SHADE, seat * shade);
	}
	// the tray's wall shading the sand along the top and the left, and a wash
	float wall = max(smoothstep(unit * 0.11, 0.0, p.y), 0.7 * smoothstep(unit * 0.08, 0.0, p.x));
	col = mix(col, col * vec3(0.80, 0.74, 0.72), 0.55 * wall);
	col *= 0.98 + 0.04 * noise(p / unit * 1.3 + 9.0);
	COLOR = vec4(col, 1.0);
}
