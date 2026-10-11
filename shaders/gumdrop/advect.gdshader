shader_type canvas_item;
render_mode blend_disabled, unshaded;

// The first pass of a frame: the velocity carried along itself (traced
// back a step and read there), slowed by the jelly, and given the
// dropper's push while it is squeezed: a jet the way the dropper points
// (`jet`, turned slowly by the screen: a push straight out from the tip
// is all divergence and the pressure takes it back), a swirl across it,
// and the way the tip is being drawn. Over a wall the velocity is
// nothing.

#include "res://shaders/gumdrop/fluid.gdshaderinc"

uniform sampler2D vel : filter_nearest, repeat_disable;
uniform sampler2D mask : filter_nearest, repeat_disable;
uniform ivec2 n = ivec2(128, 128);
uniform float dt = 0.016;
// e^(-viscosity * dt): what of the velocity a step keeps.
uniform float keep = 0.97;
uniform vec2 tip = vec2(0.5, 0.5);
uniform float squeezing = 0.0;
uniform float radius = 0.06;
uniform float push = 900.0;
uniform float swirl = 300.0;
uniform vec2 drag = vec2(0.0);
uniform vec2 jet = vec2(-0.5, 0.85);
uniform float time = 0.0;
uniform float clearing = 0.0;

void fragment() {
	if (clearing > 0.5 || wall_at(mask, ivec2(UV * vec2(n)), n)) {
		COLOR = pack_vel(vec2(0.0));
	} else {
		vec2 pos = UV * vec2(n);
		vec2 v = vel_at(vel, pos, n);
		vec2 back = pos - v * dt;
		vec2 v2 = vel_at(vel, back, n) * keep;
		if (squeezing > 0.5) {
			vec2 d = UV - tip;
			float g = exp(-dot(d, d) / (radius * radius));
			vec2 side = vec2(-jet.y, jet.x);
			float turn = sin(time * 1.7) * 0.6 + sin(time * 4.3) * 0.4;
			v2 += (jet * push + side * swirl * turn + drag) * g * dt;
		}
		COLOR = pack_vel(v2);
	}
}
