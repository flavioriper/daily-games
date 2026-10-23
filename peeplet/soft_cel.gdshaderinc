// Daily's look for the peeplet coat (2026-10-23, the cartoon pass, the
// user on it beside Duolingo's owl: "omg i loved it so much"): a flat fill in
// two hard tones, the way a drawn mascot is coloured. One clean band where
// the sun stops, no painted gradient, no cheeks, and the trait colour as it
// is: the house mute (soft_paint.gdshaderinc) is skipped here on purpose,
// a cartoon coat is a saturated coat. Both coat shaders include it after
// their value_noise(), so the base coat and every fur shell take the same
// light (the shells are no longer drawn: peeplet_walker._attach_fur_decoration).

#include "res://peeplet/soft_paint.gdshaderinc"

// The side turned away: the coat deeper and a little cooler, one flat tone.
const vec3 SOFT_SHADOW = vec3(0.78, 0.66, 0.70);
// Where the band falls on the coat, in n.l; the wobble keeps a hair of
// hand-drawn waver on the line.
const float SOFT_CUT = 0.10;

vec3 soft_cel(vec3 world_normal, vec3 sun_toward, float wobble, float facing) {
	float ndotl = dot(world_normal, normalize(sun_toward)) + wobble * 0.02;
	float lit = step(SOFT_CUT, ndotl);
	return mix(SOFT_SHADOW, vec3(1.0), lit);
}

// The trait colour as the cartoon paints it: unchanged.
vec3 soft_coat(vec3 coat, vec3 p) {
	return coat;
}
