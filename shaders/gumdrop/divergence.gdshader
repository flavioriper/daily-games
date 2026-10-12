shader_type canvas_item;
render_mode blend_disabled, unshaded;

// How much more leaves each texel than comes in. A wall beside it stands
// still, and so does another chunk.

#include "res://shaders/gumdrop/fluid.gdshaderinc"

uniform sampler2D vel : filter_nearest, repeat_disable;
uniform sampler2D mask : filter_nearest, repeat_disable;
uniform ivec2 n = ivec2(128, 128);

float side_x(ivec2 p, int cell) {
	return shut_at(mask, p, n, cell) ? 0.0 : vel_fetch(vel, p, n).x;
}

float side_y(ivec2 p, int cell) {
	return shut_at(mask, p, n, cell) ? 0.0 : vel_fetch(vel, p, n).y;
}

void fragment() {
	ivec2 p = ivec2(UV * vec2(n));
	int cell = cell_id(mask, p, n);
	float d = 0.5 * (side_x(p + ivec2(1, 0), cell) - side_x(p + ivec2(-1, 0), cell) + side_y(p + ivec2(0, 1), cell) - side_y(p + ivec2(0, -1), cell));
	COLOR = vec4(pk(d, DMAX), 0.0, 1.0);
}
