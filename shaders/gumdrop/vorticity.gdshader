shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Vorticity confinement: the curls the grid would smooth away are pushed
// back toward their middles, so the colour winds into marbling and not a
// soft blur. `eps` is nothing under reduce motion.

#include "res://shaders/gumdrop/fluid.gdshaderinc"

uniform sampler2D vel : filter_nearest, repeat_disable;
uniform sampler2D curl : filter_nearest, repeat_disable;
uniform ivec2 n = ivec2(128, 128);
uniform float dt = 0.016;
uniform float eps = 18.0;

void fragment() {
	ivec2 p = ivec2(UV * vec2(n));
	vec2 v = vel_fetch(vel, p, n);
	float l = abs(fetch1(curl, p + ivec2(-1, 0), n, CMAX));
	float r = abs(fetch1(curl, p + ivec2(1, 0), n, CMAX));
	float t = abs(fetch1(curl, p + ivec2(0, -1), n, CMAX));
	float b = abs(fetch1(curl, p + ivec2(0, 1), n, CMAX));
	float c = fetch1(curl, p, n, CMAX);
	vec2 grad = 0.5 * vec2(r - l, b - t);
	vec2 nrm = grad / (length(grad) + 0.0001);
	// the force stands across the gradient, turning with the curl's sign
	vec2 force = eps * c * vec2(nrm.y, -nrm.x);
	COLOR = pack_vel(v + force * dt);
}
