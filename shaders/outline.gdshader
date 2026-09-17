shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

// Inverted hull: the mesh drawn again with front faces culled and every
// vertex pushed out along its normal, so only a rim of back faces shows
// around the silhouette. Lives on a child MeshInstance3D with shadow casting
// off (core/toon.gd add_outline). Never material_overlay or next_pass: both
// would draw the hull into the shadow map too.

uniform vec4 color : source_color = vec4(0.23, 0.18, 0.16, 1.0);
// World units at distance_scale 0. Raise distance_scale so far pieces keep a
// visible line.
uniform float width : hint_range(0.0, 0.2) = 0.02;
uniform float distance_scale : hint_range(0.0, 0.2) = 0.0;

// The same lean as toon_wind.gdshader, for a hull ringing a layer that sways.
// A shell is a second instance of the layer's own mesh, so a line that stays
// put while its layer leans peels off it. sway_amount is 0 by default, which
// is every other line in the game: no lean, and the branch costs a multiply.
// The gust rides over it out of the same include, so a line never lags the
// blade it rings; at sway_amount 0 it too comes to nothing.
#include "res://shaders/wind.gdshaderinc"

global uniform float motion_scale;
uniform float sway_base = 0.03;
uniform float sway_height = 0.07;
uniform float sway_amount = 0.0;
uniform float sway_speed = 1.6;

void vertex() {
	// Read the lean off the mesh's own vertex, before the hull pushes it out,
	// so shell and layer lean by exactly the same amount.
	float h = clamp((VERTEX.y - sway_base) / sway_height, 0.0, 1.0);
	h *= h;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = TIME * sway_speed + wp.x * 0.9 + wp.z * 0.7;
	float flip = sign(determinant(mat3(MODEL_MATRIX)));
	float view_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	VERTEX += normalize(NORMAL) * width * (1.0 + distance_scale * view_dist);
	VERTEX.x += flip * sin(ph) * sway_amount * h * motion_scale;
	VERTEX.z += cos(ph * 0.8) * sway_amount * 0.6 * h * motion_scale;
	VERTEX += gust_lean(MODEL_MATRIX, wp, TIME, sway_amount) * h * motion_scale;
}

void fragment() {
	ALBEDO = color.rgb;
}
