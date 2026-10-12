shader_type canvas_item;
render_mode blend_disabled, unshaded;

// The last velocity pass: the pressure's gradient taken off, so the flow
// neither piles up nor thins out, and nothing runs into a wall or out of its chunk.

#include "res://shaders/gumdrop/fluid.gdshaderinc"

uniform sampler2D vel : filter_nearest, repeat_disable;
uniform sampler2D pres : filter_nearest, repeat_disable;
uniform sampler2D mask : filter_nearest, repeat_disable;
uniform ivec2 n = ivec2(128, 128);

float p_at(ivec2 p, float own, int cell) {
	return shut_at(mask, p, n, cell) ? own : fetch1(pres, p, n, PMAX);
}

void fragment() {
	ivec2 p = ivec2(UV * vec2(n));
	int cell = cell_id(mask, p, n);
	if (cell < 0) {
		COLOR = pack_vel(vec2(0.0));
	} else {
		float own = fetch1(pres, p, n, PMAX);
		vec2 v = vel_fetch(vel, p, n);
		v -= 0.5 * vec2(p_at(p + ivec2(1, 0), own, cell) - p_at(p + ivec2(-1, 0), own, cell), p_at(p + ivec2(0, 1), own, cell) - p_at(p + ivec2(0, -1), own, cell));
		// nothing toward a wall or into another chunk
		if (v.x > 0.0 && shut_at(mask, p + ivec2(1, 0), n, cell)) { v.x = 0.0; }
		if (v.x < 0.0 && shut_at(mask, p + ivec2(-1, 0), n, cell)) { v.x = 0.0; }
		if (v.y > 0.0 && shut_at(mask, p + ivec2(0, 1), n, cell)) { v.y = 0.0; }
		if (v.y < 0.0 && shut_at(mask, p + ivec2(0, -1), n, cell)) { v.y = 0.0; }
		COLOR = pack_vel(v);
	}
}
