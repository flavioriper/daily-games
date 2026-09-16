shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, unshaded, specular_disabled,
	blend_mix;

// The far cloud bank the hills stand against, ported from the source scene's
// backdrop material (art/landscape.blend, Material.003): two noise fields,
// one through a soft ramp from white to the source's own pale blue for the
// colour, one through a hard ramp for the alpha, so the bank has a cut edge
// rather than fading out. One wide card, built as a QuadMesh in
// world/backdrop.gd because it is a rectangle and does not need exporting.
//
// Drifts on the motion_scale global, so reduce-motion stills it along with
// the grass and the lake. Unshaded: the landscape's light is painted into it.

global uniform float motion_scale;

uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// The source's own pale blue, within a hair of Pal.SKY_TOP.
uniform vec4 bank_color : source_color = vec4(0.765, 0.863, 0.925, 1.0);
uniform float drift = 0.004;
uniform float bank_scale = 2.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise2(p) * 0.6 + noise2(p * 2.1) * 0.3 + noise2(p * 4.3) * 0.1;
}

void fragment() {
	vec2 uv = UV * bank_scale + vec2(TIME * drift * motion_scale, 0.0);
	float body = fbm(uv);
	// The alpha ramp is a hard cut in the source, at 0.541 to 0.564.
	float a = smoothstep(0.541, 0.564, fbm(uv * 1.7 + vec2(3.1, 1.7)));
	// Higher up the card is more sky, less bank.
	a *= smoothstep(0.0, 0.45, UV.y);
	ALBEDO = mix(bank_color.rgb, cloud_color.rgb, smoothstep(0.495, 0.623, body));
	ALPHA = a;
}
