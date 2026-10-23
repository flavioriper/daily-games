shader_type spatial;
render_mode unshaded, cull_front;

// Ink rim for farm props, worn as material_overlay: the same mesh drawn
// again with front faces culled and every vertex pushed out along its
// smooth normal, so only a thin dark silhouette shell survives around the
// base pass. Needs smooth vertex normals or the shell cracks at hard edges,
// which is why the crop GLBs export shaded smooth.

#include "res://world/toon_tentacle_sway.gdshaderinc"

uniform vec4 outline_color : source_color = vec4(0.07, 0.055, 0.045, 1.0);
// World metres of ink. Crop props stand around 0.3 m.
uniform float outline_width = 0.008;

void vertex() {
	// Sway first (a no-op at the default zero amplitude), then the hull push,
	// so the ink tracks the deformed flesh instead of the rest pose.
	VERTEX = tentacle_sway(VERTEX, COLOR, TIME);
	vec3 world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vec3 world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz
		+ world_normal * outline_width;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_vertex, 1.0)).xyz;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
