shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_disabled;

// daily: toon_prop for the see-through lenses (glasses, 3D glasses, the
// tech visor, the star and heart lenses, the monocle), which ~/dev/peeplet
// left on their import material: a glossy lit pane with a specular spot.
// Here a lens is a wash of painted colour over the eye, in the same soft
// cel and the same house paint as the frame round it. COLOR carries the
// lens's fill once its pieces are welded (peeplet/peeplet_batch.gd).

#include "res://world/toon_cel.gdshaderinc"
#include "res://peeplet/soft_paint.gdshaderinc"

uniform vec4 albedo_tint : source_color = vec4(1.0);

void fragment() {
	ALBEDO = (albedo_tint.rgb * COLOR.rgb);
	ALPHA = albedo_tint.a * COLOR.a;
	ROUGHNESS = 1.0;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = cel_band(NORMAL, INV_VIEW_MATRIX, 0.05, 0.01, 0.0);
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(vec3(0.78, 0.66, 0.70), vec3(1.0), lit);
	}
}
