shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Lucky Thirteen's piece, in Binairo's paper look: a rounded-square tile of
// one flat pastel with a thin lip of the same colour deepened under it, no
// line, no gloss, no bevel. It is never on screen: arcade/thirteen_art.gd
// draws one rect per number into a SubViewport once, letters the number over
// it, keeps the picture as an atlas, and the board draws textured quads from
// it.
//
// The rect covers -SPAN..SPAN and the tile is HALF to a side. Blending is
// off: the picture is written with straight alpha, so the atlas has no dark
// fringe.

uniform float value = 1.0;
uniform vec4 base : source_color = vec4(0.95, 0.65, 0.67, 1.0);
uniform float px = 0.008; // one pixel, in tile halves

const float SPAN = 1.3;
const float HALF = 0.97;
const float ROUND = 0.36;
const float LIP = 0.11;

// The tile's own colour, deepened: the lip. thirteen_art.gd's line_colour().
vec3 deepen(vec3 c, float k) {
	return mix(c, c * c * vec3(0.86, 0.80, 0.90), k);
}

vec3 lighten(vec3 c, float k) {
	return mix(c, vec3(1.0, 0.98, 0.94), k);
}

float box(vec2 p, vec2 half, float r) {
	vec2 d = abs(p) - (half - r);
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
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
	// the whole tile, and its face: the same tile less the lip at its foot
	float d_body = box(p, vec2(HALF), ROUND);
	vec2 q = p + vec2(0.0, LIP * 0.5);
	float d_face = box(q, vec2(HALF, HALF - LIP * 0.5), ROUND);

	bool gilt = value > 12.5 && value < 13.5;
	vec3 paint = base.rgb;
	vec3 col = paint;
	// a tile dresses up as it grows: a paler stitch inside its edge from 10,
	// a gold one past 13
	if (value > 9.5) {
		vec3 stitch = value > 13.5 ? vec3(0.96, 0.80, 0.42) : lighten(paint, 0.55);
		col = mix(col, stitch, 0.85 * smoothstep(0.02 + aa, 0.02 - aa, abs(d_face + 0.15)));
	}
	if (gilt) {
		float cd = clover(q - vec2(0.50, 0.50), 0.27, 0.4);
		col = mix(col, vec3(0.36, 0.60, 0.36), smoothstep(0.03, 0.02, cd));
		col = mix(col, vec3(0.56, 0.80, 0.50), smoothstep(0.004, -0.006, cd));
	}

	// a soft ground shadow, the lip, the face: straight alpha out
	float a_shadow = 0.13 * smoothstep(0.14, -0.08, box(p - vec2(0.0, 0.07), vec2(HALF), ROUND));
	float a_body = smoothstep(aa, -aa, d_body);
	float a_face = smoothstep(aa, -aa, d_face);
	vec3 lip = deepen(paint, 0.6);
	vec3 rgb = vec3(0.36, 0.24, 0.14) * a_shadow;
	float a = a_shadow;
	rgb = mix(rgb, lip, a_body);
	a = mix(a, 1.0, a_body);
	rgb = mix(rgb, col, a_face);
	COLOR = vec4(a > 0.001 ? rgb / a : lip, a);
}
