shader_type canvas_item;
render_mode blend_disabled, unshaded;

// One Jacobi sweep of the pressure: each texel the mean of its four
// neighbours less the divergence. A wall beside a texel is taken as the
// texel's own pressure, so nothing is pressed through it. The first sweep
// of a frame starts from the last of the frame before.

#include "res://shaders/gumdrop/fluid.gdshaderinc"

uniform sampler2D pres : filter_nearest, repeat_disable;
uniform sampler2D divg : filter_nearest, repeat_disable;
uniform sampler2D mask : filter_nearest, repeat_disable;
uniform ivec2 n = ivec2(128, 128);
uniform float clearing = 0.0;

float p_at(ivec2 p, float own) {
	return wall_at(mask, p, n) ? own : fetch1(pres, p, n, PMAX);
}

void fragment() {
	if (clearing > 0.5) {
		COLOR = vec4(pk(0.0, PMAX), 0.0, 1.0);
	} else {
		ivec2 p = ivec2(UV * vec2(n));
		float own = fetch1(pres, p, n, PMAX);
		float d = fetch1(divg, p, n, DMAX);
		float v = (p_at(p + ivec2(-1, 0), own) + p_at(p + ivec2(1, 0), own) + p_at(p + ivec2(0, -1), own) + p_at(p + ivec2(0, 1), own) - d) * 0.25;
		COLOR = vec4(pk(v, PMAX), 0.0, 1.0);
	}
}
