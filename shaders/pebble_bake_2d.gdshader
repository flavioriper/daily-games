shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Lucky Thirteen's stone, in the soft cel look (docs/art/shading-direction.md):
// a chunky token with a thick side under its face, a line of its own colour
// deepened, a bevelled rim, and a face in three eased bands of its paint --
// no gloss, no grit. It is never on screen: arcade/thirteen_art.gd draws one
// rect per number into a SubViewport once, letters the number over it, keeps
// the picture as an atlas, and the board draws textured quads from it.
//
// The rect covers -SPAN..SPAN and the stone has radius 1. Blending is off:
// the picture is written with straight alpha, so the atlas has no dark fringe.

uniform float value = 1.0;
uniform vec4 base : source_color = vec4(0.93, 0.5, 0.55, 1.0);
uniform float px = 0.008; // one pixel, in stone radii

const float SPAN = 1.3;
const vec3 SUN = vec3(-0.50, -0.62, 0.60);
const vec2 FACE = vec2(0.0, -0.09);  // the face's centre; the side hangs below
const float RADIUS = 0.90;
const float SIDE = 0.17;
const float LINE = 0.05;
const float RIM = 0.80;              // where the bevel starts, in face radii

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

// The layer's own colour, deepened and cooled: the line and the shade.
vec3 deepen(vec3 c, float k) {
	return mix(c, c * c * vec3(0.72, 0.66, 0.86), k);
}

vec3 lighten(vec3 c, float k) {
	return mix(c, vec3(1.0, 0.98, 0.93), k);
}

// A four-leaf clover's signed distance, `s` across.
float clover(vec2 p, float s, float turn) {
	float c = cos(turn);
	float sn = sin(turn);
	p = abs(vec2(c * p.x + sn * p.y, -sn * p.x + c * p.y) / s);
	if (p.y > p.x) {
		p = p.yx;
	}
	float d = min(length(p - vec2(0.54, 0.15)), length(p - vec2(0.54, -0.15))) - 0.23;
	return min(d, length(p - vec2(0.27, 0.0)) - 0.2) * s;
}

void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * SPAN;
	float aa = 1.5 * px;
	vec2 q = (p - FACE) / RADIUS;
	float rq = length(q);
	// the body: the face and the side under it, one capsule
	float d_face = (rq - 1.0) * RADIUS;
	float d_body = length(p - FACE - vec2(0.0, clamp(p.y - FACE.y, 0.0, SIDE))) - RADIUS;

	bool gilt = value > 12.5 && value < 13.5;
	vec3 paint = base.rgb;
	vec3 line = deepen(paint, 0.92);
	vec3 side = deepen(paint, 0.5);
	vec3 l = normalize(SUN);
	vec2 dir = q / max(rq, 1e-4);
	float toward = dot(dir, normalize(l.xy));

	// the face: three eased bands over a shallow dome, and a slow wash
	vec3 n = normalize(vec3(q * 0.9, sqrt(max(0.0, 1.0 - rq * rq * 0.8))));
	float d = dot(n, l);
	vec3 col = paint;
	col = mix(col, lighten(paint, 0.2), smoothstep(0.80, 0.88, d));
	col = mix(col, deepen(paint, 0.22), smoothstep(0.42, 0.33, d));
	// the bevel round it: lit where it faces the light, deep where it turns away
	vec3 bevel = mix(deepen(paint, 0.42), lighten(paint, 0.34), smoothstep(-0.55, 0.75, toward));
	col = mix(col, bevel, smoothstep(RIM - 0.012, RIM + 0.012, rq));
	col = mix(col, lighten(paint, 0.5), 0.55 * smoothstep(0.022, 0.008, abs(rq - RIM)) * smoothstep(0.0, 0.8, toward));
	// a stone dresses up as it grows: an inlaid ring from 5, a second from 9,
	// gold studs on the rim from 10, a gold rim past 13
	vec3 gold = vec3(0.98, 0.76, 0.26);
	if (value > 4.5 && value < 12.5) {
		col = mix(col, lighten(paint, 0.42), 0.7 * smoothstep(0.024, 0.012, abs(rq - 0.68)));
		if (value > 8.5) {
			col = mix(col, deepen(paint, 0.4), 0.7 * smoothstep(0.014, 0.006, abs(rq - 0.61)));
		}
		if (value > 9.5) {
			for (int i = 0; i < 6; i++) {
				float a = 6.2832 * (float(i) + 0.5) / 6.0;
				vec2 at = 0.9 * vec2(cos(a), sin(a));
				float f = length(q - at);
				col = mix(col, deepen(gold, 0.7), smoothstep(0.075, 0.065, f));
				col = mix(col, gold, smoothstep(0.052, 0.042, f));
			}
		}
	} else if (value > 13.5) {
		col = mix(col, gold, smoothstep(0.03, 0.02, abs(rq - 0.895)));
	}
	if (gilt) {
		float cd = clover(q - vec2(0.50, 0.50), 0.27, 0.4);
		col = mix(col, vec3(0.16, 0.36, 0.2), smoothstep(0.035, 0.025, cd));
		col = mix(col, mix(vec3(0.33, 0.62, 0.32), vec3(0.50, 0.78, 0.40), smoothstep(-0.02, -0.07, cd)), smoothstep(0.004, -0.006, cd));
	}
	// the one soft glint, up where the light comes from
	vec2 g = q - vec2(-0.40, -0.50);
	g = vec2(0.77 * g.x - 0.64 * g.y, 0.64 * g.x + 0.77 * g.y);
	col = mix(col, vec3(1.0), 0.5 * smoothstep(1.0, 0.7, length(g / vec2(0.2, 0.075))));
	col *= 0.975 + 0.05 * noise(p * 1.6 + value * 3.7);

	// the side under the face: darker toward its foot
	vec3 wall = mix(side, deepen(side, 0.3), smoothstep(-0.2, 0.9, p.y - FACE.y));
	wall = mix(wall, lighten(side, 0.25), 0.5 * smoothstep(0.5, 1.0, -dir.x) * smoothstep(0.3, 0.0, abs(p.y - FACE.y - SIDE * 0.5)));

	// ground shadow, line, side, face: straight alpha out
	float a_shadow = 0.24 * smoothstep(0.16, -0.10, length(p - FACE - vec2(0.03, SIDE + 0.07)) - RADIUS);
	float a_line = smoothstep(LINE + aa, LINE - aa, d_body);
	float a_body = smoothstep(aa, -aa, d_body);
	float a_face = smoothstep(aa, -aa, d_face);
	vec3 rgb = vec3(0.36, 0.22, 0.20) * a_shadow;
	float a = a_shadow;
	rgb = mix(rgb, line, a_line);
	a = mix(a, 1.0, a_line);
	rgb = mix(rgb, wall, a_body);
	// the line between the face and its side
	rgb = mix(rgb, line, 0.55 * a_body * smoothstep(0.03 + aa, 0.03 - aa, abs(d_face)));
	rgb = mix(rgb, col, a_face);
	COLOR = vec4(a > 0.001 ? rgb / a : line, a);
}
