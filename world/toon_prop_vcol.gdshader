shader_type spatial;
render_mode specular_disabled;

// toon_prop variant for vertex-painted props (rainbow eyewear lenses):
// identical band contract, but the flat fill multiplies in COLOR so the
// painted gradient survives the cel conversion.

#include "res://world/toon_cel.gdshaderinc"
#include "res://peeplet/soft_paint.gdshaderinc"

uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float band_cut : hint_range(-1.0, 1.0) = 0.1;
uniform float band_soft : hint_range(0.0, 0.3) = 0.04;
uniform vec3 shade_tone : source_color = vec3(0.30, 0.38, 0.36);
uniform float shadow_cut : hint_range(0.0, 1.0) = 0.46;
uniform float shadow_soft : hint_range(0.0, 0.5) = 0.13;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// daily: the house's paint (peeplet/soft_paint.gdshaderinc).
	vec3 fill = paint_wash(house_mute(albedo_tint.rgb * COLOR.rgb), (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	fill *= mix(vec3(1.0), vec3(0.55, 0.65, 0.60), wetness);
	ALBEDO = fill;
	ROUGHNESS = 1.0;
}

void light() {
	float open = cel_shadow(ATTENUATION, shadow_cut, shadow_soft);
	if (!LIGHT_IS_DIRECTIONAL) {
		// Positional light (the campfire): the sun band points the wrong way
		// for a fire and the shade_tone floor is free light past the range —
		// grade on the three-ring pool instead (see toon_cel.gdshaderinc).
		DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * cel_point_pool(ATTENUATION);
	} else {
		// daily: the house's soft cel (peeplet/soft_cel.gdshaderinc), so a
		// worn hat sits in the same light as the coat under it: a soft
		// terminator, a warm shade rather than ~/dev/peeplet's cool floor,
		// and the light written without ALBEDO (toon_cel.gdshaderinc's
		// gotcha), so the trait colour lands as painted. ui/peeplet_view.gd
		// lights it with one white sun of energy 1, and LIGHT_COLOR carries
		// that energy times PI: undivided, every hat came out three times
		// over and a teal beanie read neon cyan.
		float lit = cel_band(NORMAL, INV_VIEW_MATRIX, -0.05, 0.22, 0.0);
		vec3 cel = mix(vec3(0.86, 0.76, 0.76), vec3(1.0), min(lit, open));
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * cel;
	}
}
