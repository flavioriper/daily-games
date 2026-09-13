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

void vertex() {
	float view_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	VERTEX += normalize(NORMAL) * width * (1.0 + distance_scale * view_dist);
}

void fragment() {
	ALBEDO = color.rgb;
}
