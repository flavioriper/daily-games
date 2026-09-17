shader_type canvas_item;

// The HUD's paper, painted. Set as a Control's `material` so it modulates
// whatever the StyleBoxFlat already drew: every tone here is a multiply on the
// drawn colour, so the rounded corners, the deep rim, the antialiasing and
// the face colour the theme chose all stay exactly what they were, and a
// slate card, a sun button and a cream sheet each take the wash in their own
// colour. The same painterly wash the 3D pieces wear
// (shaders/toon_lit.gdshaderinc, paint_wash): a slow drift between a warmer
// and a cooler tint of the surface, a finer drift in value under it, and a
// fine paper tooth on top, a few percent at most. Docs:
// docs/art/shading-direction.md, hand-painted feel.
//
// Measured in screen space, normalised to the screen's height, so one shared
// material (CozyTheme.paper) serves every panel and button, each showing the
// patch of paper it happens to sit over -- no seeds, no material per panel,
// no instance parameter (those are unusable on gl_compatibility past sixteen
// instances; see CLAUDE.md). A sheet that slides in has the wash slide over
// it for the moment it moves; at these amounts the eye does not pick it up.
// The wood panels (shaders/wood_grain_2d.gdshader) carry a wash of their own.

uniform float wash : hint_range(0.0, 1.0) = 1.0;
// Cycles per screen height: the broad patches, the finer drift, the tooth.
uniform float wash_scale = 9.0;
uniform float fine_scale = 30.0;
uniform float tooth_scale = 220.0;
uniform vec3 wash_warm = vec3(1.04, 1.0, 0.955);
uniform vec3 wash_cool = vec3(0.96, 0.99, 1.04);
// The fine drift's and the tooth's value swing, peak to peak.
uniform float wash_value : hint_range(0.0, 0.3) = 0.06;
uniform float tooth_value : hint_range(0.0, 0.2) = 0.03;

float paper_hash(vec2 p) {
	p = mod(p, 289.0);
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float paper_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(paper_hash(i), paper_hash(i + vec2(1.0, 0.0)), f.x),
		mix(paper_hash(i + vec2(0.0, 1.0)), paper_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// Screen position in units of the screen's height, so the paper's patches
	// are the same size on the screen at 540 or 1080 across.
	vec2 p = vec2(SCREEN_UV.x * SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, SCREEN_UV.y);
	float broad = paper_noise(p * wash_scale + 19.0);
	float fine = paper_noise(p * fine_scale + 57.0);
	float tooth = paper_noise(p * tooth_scale + 91.0);
	float warmth = clamp(0.5 + (broad - 0.5) * 1.4 + (fine - 0.5) * 0.8, 0.0, 1.0);
	vec3 tone = mix(wash_cool, wash_warm, warmth);
	tone *= 1.0 + (fine - 0.5) * wash_value;
	tone *= 1.0 + (tooth - 0.5) * tooth_value;
	COLOR.rgb *= mix(vec3(1.0), tone, wash);
}
