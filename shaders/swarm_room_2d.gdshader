shader_type canvas_item;
render_mode unshaded;

// The room the swarm lives in (ui/menu/swarm_tab.gd), on one full-rect
// ColorRect: green-black, deepest at the corners; a faint hexagonal floor
// that the face lights and that fades with distance from it; the face's light
// pooled on the floor below it, swelling with the voice; and a grain of
// dither under one level, so the dark falls never band. `size` is the
// control's in pixels; `centre` and `radius` the face's. No instance uniform.

uniform vec2 size = vec2(810.0, 1440.0);
uniform vec2 centre = vec2(405.0, 600.0);
uniform float radius = 137.0;
uniform float level : hint_range(0.0, 1.0) = 0.0;
uniform float lit : hint_range(0.0, 1.0) = 1.0;
uniform vec4 room : source_color = vec4(0.043, 0.082, 0.063, 1.0);
uniform vec4 deep : source_color = vec4(0.016, 0.031, 0.024, 1.0);
uniform vec4 tint : source_color = vec4(0.54, 0.84, 0.65, 1.0);

// Distance to the nearest edge of a hex grid, in cells (an edge is at 0.5).
float hex_edge(vec2 p) {
	vec2 a = vec2(1.0, 1.7320508);
	vec2 h = a * 0.5;
	vec2 c1 = mod(p, a) - h;
	vec2 c2 = mod(p + h, a) - h;
	vec2 c = dot(c1, c1) < dot(c2, c2) ? c1 : c2;
	c = abs(c);
	return max(c.x, dot(c, vec2(0.5, 0.8660254)));
}

void fragment() {
	vec2 p = UV * size;
	vec2 n = (UV - 0.5) * vec2(1.0, size.y / size.x) * 2.0;
	float vig = smoothstep(0.35, 1.35, length(n));
	vec3 colour = mix(room.rgb, deep.rgb, vig);

	// The floor: a hex grid lit from the face, gone past three radii.
	float cell = radius * 0.42;
	float e = hex_edge(p / cell);
	float px = 0.75 / cell;
	float grid = 1.0 - smoothstep(0.0, px * 1.6, abs(e - 0.5));
	float reach = 1.0 - smoothstep(radius * 1.2, radius * 3.4, distance(p, centre));
	colour += tint.rgb * grid * reach * (0.035 + 0.03 * level) * lit;

	// The light pooled on the floor beneath the face.
	vec2 pool_at = centre + vec2(0.0, radius * 1.95);
	vec2 d = (p - pool_at) / vec2(radius * 1.7, radius * 0.5);
	float pool = exp(-dot(d, d) * 1.4);
	colour += tint.rgb * pool * (0.07 + 0.07 * level) * lit;

	float grain = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	COLOR = vec4(colour + (grain - 0.5) / 255.0, 1.0);
}
