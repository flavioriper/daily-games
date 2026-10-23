// Daily's look for the peeplet coat, which ~/dev/peeplet cuts into a hard
// two-band toon: the house's drawn characters (the menu's sun and moon,
// ui/faces/) in three dimensions. A clean flat fill, a light crescent where
// the sun hits, a gently deeper band turned away from it, pink cheeks. Both
// coat shaders include it after their value_noise(), so the base coat and
// every fur shell take the same light.

#include "res://peeplet/soft_paint.gdshaderinc"

// The side turned away: the coat a little deeper and warmer, never grey.
const vec3 SOFT_SHADOW = vec3(0.86, 0.76, 0.76);
// The crescent where the sun lands square, a breath of cream.
const vec3 SOFT_GLOW = vec3(1.12, 1.09, 1.04);
const vec3 CHEEK = vec3(0.98, 0.60, 0.62);
// Cheek centres, mirrored, in glb object space: under and outside the eyes
// (eyes at x 0.245, y 0.325).
const vec3 CHEEK_AT = vec3(0.37, 0.19, 0.46);

vec3 soft_cel(vec3 world_normal, vec3 sun_toward, float wobble, float facing) {
	float ndotl = dot(world_normal, normalize(sun_toward)) + wobble * 0.04;
	float lit = smoothstep(0.08, 0.30, ndotl);
	float glow = smoothstep(0.80, 0.86, ndotl);
	vec3 light = mix(SOFT_SHADOW, vec3(1.0), lit);
	return mix(light, SOFT_GLOW, glow);
}

// The trait colour as the house paints it: muted, a breath toward cream
// (soft_paint.gdshaderinc), and the two pink cheeks.
vec3 soft_coat(vec3 coat, vec3 p) {
	// house_mute brings the hot coats (coral, ocean's deep water, candy)
	// down to the house's pastels and leaves the soft ones nearly as they are.
	coat = house_mute(coat);
	float cheek = 1.0 - smoothstep(0.06, 0.095, distance(vec3(abs(p.x), p.y, p.z), CHEEK_AT));
	return mix(coat, CHEEK, cheek * 0.75);
}
