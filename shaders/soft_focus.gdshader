shader_type spatial;
// Drawn in the transparent pass (blend_mix) because that is when the
// Compatibility renderer has taken its copies of the screen and the depth;
// an opaque quad reads the previous frame's screen and no depth at all
// (probed 2026-09-17). render_priority on the material puts it first among
// the transparents, so the water and the pollen draw over it rather than
// vanishing under the copy.
render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled, depth_draw_never, fog_disabled;

// The campsite's soft focus: the painted frame's depth of field, which
// gl_compatibility has no CameraAttributes for. Everything past focus_start
// (a view distance, set by world/stage.gd to just behind the thing being
// framed) blurs in over focus_range by sampling the screen texture's own mip
// levels -- a blur the GPU has already computed -- and lightens a hair
// toward the haze, the shading direction's "depth through colour". What
// stands nearer than near_start blurs in the same way toward near_end and
// *darkens* rather than lightens: the trunks and crowns that frame the
// first screen at its edges read as the painting's shaded foreground. Over
// both, a soft vignette toward a deep foliage colour, so the frame is dark
// at every edge and bright only where the camp is. The HUD is drawn over
// this pass, so none of it reaches the cards.
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float focus_start = 8.0;
uniform float focus_range = 9.0;
uniform float max_lod = 3.0;
uniform vec4 haze_color : source_color = vec4(0.91, 0.95, 0.97, 1.0);
uniform float haze : hint_range(0.0, 1.0) = 0.16;
// Sharp from near_start on; fully soft at near_end and nearer.
uniform float near_start = 3.0;
uniform float near_end = 1.5;
uniform float near_max_lod = 2.5;
uniform float near_darken : hint_range(0.0, 1.0) = 0.35;
// The near band is for the trees framing the top of the frame; the fence
// diorama standing along its bottom edge is as near and must stay sharp.
// Only the top near_gate of the frame's height takes the band, eased over
// near_gate_soft below that line. 1.0 opens it to the whole frame.
uniform float near_gate : hint_range(0.0, 1.0) = 1.0;
uniform float near_gate_soft = 0.08;
// The vignette: from vignette_start (in units of half the frame's shorter
// side from its centre; the corners of a 9:16 frame sit near 2.0) it eases
// toward vignette_color, reaching vignette_amount of the way at the corners.
uniform vec4 vignette_color : source_color = vec4(0.13, 0.18, 0.11, 1.0);
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.34;
uniform float vignette_start = 0.95;
uniform float vignette_end = 2.2;

void vertex() {
	// A QuadMesh spans -0.5..0.5; this pins it to the whole frame whatever
	// the camera does, so the node's transform never matters.
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

void fragment() {
	// OpenGL depth: the NDC z is depth * 2 - 1. The inverse projection is the
	// camera's real one, frustum offset included, so this holds under the
	// menu's shift lens.
	float d = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0);
	vec4 v = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float dist = -v.z / v.w;
	float k_far = smoothstep(focus_start, focus_start + focus_range, dist);
	// SCREEN_UV.y runs top-down here (probed 2026-09-17 on gl_compatibility:
	// a band keyed the other way darkened the footer and left the canopy
	// alone), so the top near_gate of the frame is SCREEN_UV.y < near_gate.
	float gate = smoothstep(near_gate + near_gate_soft, near_gate, SCREEN_UV.y);
	float k_near = (1.0 - smoothstep(near_end, near_start, dist)) * gate;
	float lod = max(k_far * max_lod, k_near * near_max_lod);
	vec3 col = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	col = mix(col, haze_color.rgb, k_far * haze);
	col *= 1.0 - k_near * near_darken;
	// The vignette is measured in the frame's own shape: the shorter side's
	// half is one unit, so on a portrait phone the top and bottom edges are
	// farther out than the sides and darken more, the way a canopy overhead
	// and the ground underfoot would.
	vec2 off = (SCREEN_UV - 0.5) * 2.0 * VIEWPORT_SIZE / min(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y);
	float k_v = smoothstep(vignette_start, vignette_end, length(off)) * vignette_amount;
	ALBEDO = mix(col, vignette_color.rgb, k_v);
	ALPHA = 1.0;
}
