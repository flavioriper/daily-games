shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, unshaded, specular_disabled,
	blend_mix;

// The painted cloud cards, drifting. The card's own texture carries the
// painting's light, so this is unshaded like every other landscape layer; the
// drift is a world-space offset in vertex() rather than a UV scroll, because
// scrolling a card's UV slides the painting across its own alpha and the cloud
// comes apart at the edge.
//
// Billboarding is left to the StandardMaterial3D path in world/backdrop.gd for
// the other cards; a cloud sits far enough away and near enough the frame's
// top that it reads without it, and a billboard would fight the drift.

global uniform float motion_scale;

uniform sampler2D albedo : source_color, filter_linear_mipmap, hint_default_white;
// drift_speed is a rate in radians per second and drift_span the full
// peak-to-peak range the card swings across. A plain mod() sawtooth resets to
// -span/2 every drift_span seconds, which pops visibly at the wrap; sin()
// reverses smoothly at each end instead, with no snap. A card still holds
// still at motion_scale = 0, same as a mod() drift would.
uniform float drift_speed = 0.06;
uniform float drift_span = 40.0;

void vertex() {
	float d = sin(TIME * drift_speed * motion_scale) * drift_span * 0.5;
	VERTEX.x += d;
}

void fragment() {
	vec4 c = texture(albedo, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	// Cut rather than blended, so the card draws in the opaque pass and the
	// campsite's soft focus (shaders/soft_focus.gdshader) reaches it: a
	// blended card draws after the screen copy that pass reads and would stay
	// sharp against blurred hills. The soft focus gives the edge back its
	// softness; clouds are only ever seen at that distance.
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
