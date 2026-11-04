shader_type canvas_item;
render_mode blend_add, unshaded;

// The instrument rings round the swarm's face (ui/menu/swarm_tab.gd), on a
// unit quad scaled to 3.8 face radii: three broken arcs turning one way, a
// ring of ticks turning the other, a thin inner ring that swells with the
// voice, and a slow radar sweep between them, all on a plane tipped a
// little back from the screen (it clears the face; the lower half, nearer,
// is the brighter), round the face rather than through it. `px` is one
// screen pixel in face radii (1 / R); `open` fades them in once the face has
// formed. No instance uniform.

uniform float t = 0.0;
uniform float level : hint_range(0.0, 1.0) = 0.0;
uniform float open : hint_range(0.0, 1.0) = 1.0;
uniform float px = 0.0073;
uniform vec4 tint : source_color = vec4(0.54, 0.84, 0.65, 1.0);
uniform vec4 hot : source_color = vec4(0.84, 0.96, 0.87, 1.0);

const float SQ = 0.84;

// How far a point is from a ring of radius r0 on the squashed plane, in
// screen pixels' terms: the squash thins the ring top and bottom, and this
// undoes it so the line stays one width round.
float ring_d(float r, float ang, float r0) {
	float c = cos(ang);
	float s = sin(ang);
	return abs(r - r0) * sqrt(c * c + SQ * SQ * s * s);
}

float line(float d, float w) {
	return 1.0 - smoothstep(w, w + px * 1.6, d);
}

void fragment() {
	vec2 p = (UV - 0.5) * 3.8;
	vec2 q = vec2(p.x, p.y / SQ);
	float r = length(q);
	float ang = atan(q.y, q.x);
	float front = smoothstep(-0.3, 0.3, sin(ang));
	float depth = mix(0.45, 1.0, front);
	vec3 col = tint.rgb;
	float a = 0.0;

	// Three arcs, turning.
	float a1 = ang + t * 0.16;
	float gap = step(0.16, fract(a1 * 3.0 / TAU));
	a += line(ring_d(r, ang, 1.42), px * 0.9) * gap * 0.55;

	// Ticks, turning the other way, every fourth one long.
	float a2 = ang - t * 0.09;
	float u = a2 * 56.0 / TAU;
	float idx = floor(u);
	float tick = step(abs(fract(u) - 0.5), 0.1);
	float len = mix(0.022, 0.06, step(0.74, fract(idx / 4.0)));
	float band = 1.0 - smoothstep(len, len + px * 1.6, ring_d(r, ang, 1.78));
	a += tick * band * 0.5;

	// The inner ring swells and brightens with the voice.
	a += line(ring_d(r, ang, 1.24 + 0.06 * level), px * 0.7) * (0.28 + 0.6 * level);

	// A slow sweep between the rings.
	float sw = fract((ang - t * 0.35) / TAU);
	float wedge = pow(1.0 - sw, 6.0) * step(1.26, r) * (1.0 - step(1.78, r));
	a += wedge * 0.1;

	col = mix(col, hot.rgb, 0.5 * level);
	COLOR = vec4(col * a * depth * open, 1.0);
}
