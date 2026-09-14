shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// Toon shading plus wind: vertices above sway_base lean sideways by a slow
// sine of world position and time, more the higher they are, so tufts wave
// and roots stay planted. Materials named with `_sway` get this (core/toon.gd).
// motion_scale is the project-wide global that reduce-motion sets to 0.
// Spec: docs/superpowers/specs/2026-09-13-binairo-polish-design.md, section 4.
#include "res://shaders/toon_lit.gdshaderinc"

global uniform float motion_scale;
uniform float sway_base = 0.03;    // local y of the moss top; below it nothing moves
uniform float sway_height = 0.07;  // local y span over which sway reaches full
uniform float sway_amount = 0.02;  // world units at the tip
uniform float sway_speed = 1.6;

void vertex() {
	float h = clamp((VERTEX.y - sway_base) / sway_height, 0.0, 1.0);
	h *= h;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = TIME * sway_speed + wp.x * 0.9 + wp.z * 0.7;
	// A piece mirrored with scale.x = -1 (every other rim edge) would lean the
	// other way in world space; flip undoes the mirror so neighbours lean together.
	float flip = sign(determinant(mat3(MODEL_MATRIX)));
	VERTEX.x += flip * sin(ph) * sway_amount * h * motion_scale;
	VERTEX.z += cos(ph * 0.8) * sway_amount * 0.6 * h * motion_scale;
}
