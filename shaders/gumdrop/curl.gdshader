shader_type canvas_item;
render_mode blend_disabled, unshaded;

// The curl of the velocity at each texel.

#include "res://shaders/gumdrop/fluid.gdshaderinc"

uniform sampler2D vel : filter_nearest, repeat_disable;
uniform ivec2 n = ivec2(128, 128);

void fragment() {
	ivec2 p = ivec2(UV * vec2(n));
	float l = vel_fetch(vel, p + ivec2(-1, 0), n).y;
	float r = vel_fetch(vel, p + ivec2(1, 0), n).y;
	float t = vel_fetch(vel, p + ivec2(0, -1), n).x;
	float b = vel_fetch(vel, p + ivec2(0, 1), n).x;
	float c = 0.5 * ((r - l) - (b - t));
	COLOR = vec4(pk(c, CMAX), 0.0, 1.0);
}
