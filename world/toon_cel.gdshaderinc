// Shared cel-lighting contract for every lit valley surface (ground, grass,
// pines, broadleaves, props). Three things live here so they cannot drift
// apart between shaders:
//
//   light_direction  the stylized band sun. NOT the DirectionalLight's own
//                    vector — adventure.gd pushes the energy-weighted
//                    sun/moon direction into every material that declares
//                    this uniform (see refresh_chain_cache / apply_sun_band),
//                    so one edit swings the band on all of them at once.
//   cel_band()       NdotL -> lit factor, either an analytic smoothstep cut
//                    or an artist-authored ramp lookup.
//   cel_shadow()     ATTENUATION -> lit factor. The valley's real value
//                    separation is the sun's CAST shadows, not surface
//                    curvature: the ground is near flat and the grass forces
//                    an upward normal, so both would band into a single tone
//                    without this. Banding attenuation turns tree blobs into
//                    hard painted shapes instead of soft gradients.
//
// shade_tone is deliberately NOT here. Each surface keeps its own tuned
// shadow colour (needles sit deeper than props, ground sits bluer) and passes
// it to the mix at the call site. What they share is the rule: shadow is a
// hue shift toward cool, never a multiply toward black. A shaded pixel is
// ALBEDO * shade_tone, and every shade_tone lifts blue relative to red, so
// shadows read as cool daylight bounce the way storybook art paints them.

uniform vec3 light_direction = vec3(-0.55, 0.60, 0.55);
// Optional artist ramp: a GradientTexture1D sampled across the -1..1 NdotL
// range, red channel = lit factor. Lets a two-band cut become three bands, or
// a soft-shouldered terminator, without touching shader code. Off by default
// so the analytic cut below stays the tuned look.
// Gotcha: an unsaved GradientTexture1D does not survive an engine restart —
// save the gradient to a .tres before assigning it.
uniform sampler2D cel_ramp : filter_linear, repeat_disable, hint_default_white;
uniform bool use_cel_ramp = false;

// view_normal is NORMAL as handed to fragment()/light() (view space); inv_view
// is INV_VIEW_MATRIX. offset shoves the terminator per-pixel (noise scallop).
float cel_band(vec3 view_normal, mat4 inv_view, float cut, float soft, float offset) {
	vec3 world_normal = normalize((inv_view * vec4(view_normal, 0.0)).xyz);
	float ndotl = dot(world_normal, normalize(light_direction)) + offset;
	if (use_cel_ramp) {
		return texture(cel_ramp, vec2(clamp(ndotl * 0.5 + 0.5, 0.0, 1.0), 0.5)).r;
	}
	return smoothstep(cut - soft, cut + soft, ndotl);
}

// Cast-shadow band. ATTENUATION arrives 0 (fully shadowed) to 1 (open sun)
// with the shadow map's own blur already in it; the cut re-hardens that blur
// into a painted edge while `soft` keeps a pixel of antialiasing.
float cel_shadow(float attenuation, float cut, float soft) {
	return smoothstep(cut - soft, cut + soft, attenuation);
}

// RENDERER GOTCHA, measured on 4.7 gl_compatibility (this project's renderer):
// whatever a light() function writes to DIFFUSE_LIGHT is multiplied by ALBEDO
// again downstream. So the light term must be written WITHOUT ALBEDO —
//
//     DIFFUSE_LIGHT += LIGHT_COLOR * cel * gain;     // correct here
//     DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * cel;   // squares the albedo
//
// The squared form is not merely dark, it shifts hue: the smallest channel is
// attenuated hardest, so meadow green goes bottle-green. Verified by writing
// DIFFUSE_LIGHT = vec3(ATTENUATION) with ALBEDO forced to 0 (whole frame black)
// and then to 1 (correct shadow map), which isolates the extra multiply.
//
// gain replaces the normalisation the built-in models apply for you. Godot's
// diffuse_toon is smoothstep(-roughness, roughness, NdotL) / PI, which for a
// level surface under this sun lands near 0.29 — hence CEL_SUN_GAIN. Surfaces
// that were authored against their own energy (the pines, the props) keep the
// ALBEDO-multiplied form on purpose: it is baked into their approved tone, and
// rewriting it would relight every tree in the valley.
const float CEL_SUN_GAIN = 0.29;

// Painted pool for positional lights (the campfire, a window lamp): three
// concentric cel rings instead of one hard cut, so the glow grades hot core
// -> warm ring -> faint rim the way an inverse-square light reads, while
// staying banded. Thresholds are on ATTENUATION and tuned for
// omni_attenuation = 2.0 (see campfire_fire.gd); the sum tops out at 1.0.
// Ring radii ~4.1 / ~3.1 / ~1.8 m of the 6 m range: the old 0.02 outer
// threshold lit all the way to ~5 m, and from the top-down camera the three
// perfect circles read as a screen-filling bullseye instead of a hearth.
// Outer rim de-weighted, hot core boosted — the glow hugs the fire.
float cel_point_pool(float attenuation) {
	return 0.18 * smoothstep(0.07, 0.12, attenuation)
		+ 0.35 * smoothstep(0.20, 0.28, attenuation)
		+ 0.47 * smoothstep(0.45, 0.55, attenuation);
}

// Toon specular blob: one rounded highlight whose size follows roughness,
// hard-edged like the diffuse band. Only worth wiring on wet or glassy
// surfaces — on matte ground and foliage it reads as plastic.
float cel_specular(vec3 view_normal, vec3 view_dir, vec3 light_dir, float roughness, float edge) {
	vec3 half_vector = normalize(view_dir + light_dir);
	float blob = pow(max(dot(view_normal, half_vector), 0.0), mix(4.0, 180.0, 1.0 - roughness));
	return smoothstep(edge, edge + 0.06, blob);
}
